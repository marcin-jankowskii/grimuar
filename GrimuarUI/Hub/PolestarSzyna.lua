-- Grimuar UI: szyna zdarzen Polestara (15.11, R30 P01; gracz: „wstepnie wszystko jak rekomendujesz”). Zamiast pytac
-- Polestara co 2-3 s Grimuar slucha jego komunikatow (Polestar.On, Core\Init.lua) i odswieza to, co ich dotyczy:
-- kompas (cel i krok), Dziennik (krok, poradniki), pasek Grimuara. Handler Polestara dziala w srodku jego petli,
-- wiec tu tylko zaznaczamy „brudne” i odswiezamy raz w nastepnej klatce, kazde wywolanie przez pcall (blad Grimuara
-- nie trafia do raportu bledow Polestara). Grimuar nigdy nie wola Polestar.Fire.
-- NAV_ARRIVED: gdy strzalka prowadzila do celu z „Prowadz” Grimuara (Polestar.Nav.API, owner „Grimuar”), Grimuar
-- puszcza swoj cel (API.Cancel) i strzalka wraca na krok przewodnika: prowadzenie konczy sie samo po dojsciu (P17).
-- Inne moduly dopisuja sie przez U.onPolestar({ "STEP_CHANGED", ... }, fn) i dostaja (msg, ...) po klatce.
local ADDON, U = ...
local G = U.G or {}

local MSGS = { "STEP_CHANGED", "STEP_UPDATED", "WAYPOINT_CHANGED", "NAV_ARRIVED", "NAV_TRIP", "GUIDE_CHANGED", "TABS_CHANGED",
  "GUIDE_COMPLETED", "WHILE_HERE_CHANGED", "ROUTE_CHANGED", "ROUTE_ADVANCED", "TRAIN_DUE", "CLASS_TRAINED", "LEVELUP_SPELLS",
  "QUESTDB_LOADED", "CODEX_LOADED", "ITEMDB_LOADED", "GEAR_UPDATED", "PINS_CHANGED", "QOL_XP_UPDATED", "RIDING_DUE",
  "CLASS_QUEST_READY",
  -- 15.11 (R30 etap 3): nowe lub odswiezone przewodniki (questy klasowe P11)
  "GUIDES_REGISTERED",
  -- 15.11 (R30 P32/P33): rzadkie (alarm Hud\AlarmRzadki.lua, Ksiega\KsiegaRzadkie.lua)
  "RARE_SPOTTED", "RARES_HISTORY" }

local S = { subs = {}, dirty = {}, args = {}, queued = false, handles = {}, n = 0 }

-- moduly Grimuara: fn(msg, ...) po klatce, raz na komunikat
function U.onPolestar(msgs, fn)
  for _, m in ipairs(msgs) do
    S.subs[m] = S.subs[m] or {}
    table.insert(S.subs[m], fn)
  end
end

local KOMPAS = { STEP_CHANGED = true, STEP_UPDATED = true, WAYPOINT_CHANGED = true, NAV_ARRIVED = true, NAV_TRIP = true,
  WHILE_HERE_CHANGED = true, ROUTE_CHANGED = true, ROUTE_ADVANCED = true }
local DZIENNIK = { STEP_CHANGED = true, STEP_UPDATED = true, GUIDE_CHANGED = true, TABS_CHANGED = true, GUIDE_COMPLETED = true,
  WHILE_HERE_CHANGED = true, QUESTDB_LOADED = true, PINS_CHANGED = true }
local PASEK = { STEP_CHANGED = true, GUIDE_CHANGED = true, TRAIN_DUE = true, CLASS_TRAINED = true, GUIDE_COMPLETED = true }

local function arrived()
  local A = Polestar and Polestar.Nav and Polestar.Nav.API
  if not (A and A.Active and A.Cancel) then return end
  local ok, active, owner = pcall(A.Active)
  if ok and active and owner == "Grimuar" then
    local okC, res = pcall(A.Cancel, "Grimuar")
    if okC and res then U.say("jesteś na miejscu: strzałka wraca do przewodnika Polestar.") end
  end
end

local function flush()
  S.queued = false
  local dirty, args = S.dirty, S.args
  S.dirty, S.args = {}, {}
  local kompas, dziennik, pasek = false, false, false
  for msg in pairs(dirty) do
    if KOMPAS[msg] then kompas = true end
    if DZIENNIK[msg] then dziennik = true end
    if PASEK[msg] then pasek = true end
    if msg == "NAV_ARRIVED" then pcall(arrived) end
    for _, fn in ipairs(S.subs[msg] or {}) do
      local ok, err = pcall(fn, msg, unpack(args[msg] or {}))
      if not ok and U.logError then U.logError("polestar " .. msg, err) end
    end
  end
  if kompas and U.kompasSoon then pcall(U.kompasSoon, 0) end
  if dziennik then
    if U.polestarReset then pcall(U.polestarReset) end
    if U.IsOpen and U.IsOpen() and U.Current and U.Current() == "dziennik" and U.dziennikSoft then pcall(U.dziennikSoft) end
  end
  if pasek and G.refreshAll then pcall(G.refreshAll) end
end

local function on(msg, ...)
  S.n = S.n + 1
  S.dirty[msg] = true
  S.args[msg] = { ... }
  if S.queued then return end
  S.queued = true
  C_Timer.After(0, function()
    local ok, err = pcall(flush)
    if not ok and U.logError then U.logError("polestar szyna", err) end
  end)
end

local function subscribe()
  local P = _G.Polestar
  if type(P) ~= "table" or type(P.On) ~= "function" or #S.handles > 0 then return false end
  for _, msg in ipairs(MSGS) do
    local ok, h = pcall(P.On, msg, function(...) on(msg, ...) end)
    if ok and h then S.handles[#S.handles + 1] = h end
  end
  return #S.handles > 0
end
-- 15.11 (R30 etap 3, ryzyko 8): wynik akcji, ktora otwiera karte przewodnika w Polestarze (Lookup.Guide,
-- Dungeons.PickUp/HandIn/Attune, OpenTab) -> jedna linia na czacie po polsku. Limit 6 kart: funkcje zwracaja nil, "tabs".
local WHY = {
  tabs = "Polestar ma już 6 kart przewodników (więcej się nie da). Zamknij jedną w jego oknie i kliknij jeszcze raz.",
  combat = "po walce: Polestar nie wczytuje swojej bazy w walce.",
  disabled = "ta część Polestara jest wyłączona w jego opcjach.",
  off = "lochy są wyłączone w opcjach Polestara (Discovery > Dungeons).",
  mount = "to wierzchowiec: Polestar nie buduje do niego trasy (otwórz go w Polestarze Alt+klikiem).",
  nothing = "Polestar nie ma tu nic do zrobienia (wszystko wzięte albo zrobione).",
  done = "to już zrobione.",
  login = "Polestar jeszcze się wczytuje. Spróbuj za chwilę.",
}
function U.psTabsSay(gid, why, what)
  if gid then
    U.say("Polestar otworzył nową kartę przewodnika: " .. tostring(what or gid) .. ". Strzałka prowadzi, okno Polestara pokaże kroki.")
    return true
  end
  local msg = WHY[why or ""] or ("Polestar nie umie tu poprowadzić (" .. tostring(why or "?") .. ").")
  U.say(tostring(what or "Polestar") .. ": " .. ((G.tr and G.tr(msg)) or msg))
  return false
end

-- dla autotestu: ile komunikatow sluchamy i ile przyszlo
function U.polestarBus() return #S.handles, S.n end

local ev = CreateFrame("Frame")
ev:RegisterEvent("PLAYER_LOGIN")
ev:SetScript("OnEvent", function()
  if not pcall(subscribe) then return end
  -- Polestar wczytany pozniej (LoadOnDemand albo kolejnosc): jeszcze raz po chwili
  if #S.handles == 0 then C_Timer.After(5, function() pcall(subscribe) end) end
end)

U.testChecksExtra = U.testChecksExtra or {}
table.insert(U.testChecksExtra, { "Polestar", function()
  local P = _G.Polestar
  if type(P) ~= "table" then return "brak Polestara (Grimuar działa bez niego)" end
  local api = P.Nav and P.Nav.API
  local parts = { "wersja " .. tostring(P.version) }
  parts[#parts + 1] = (api and api.version == 1) and "API strzałki v1" or ("API strzałki: " .. tostring(api and api.version or "brak"))
  parts[#parts + 1] = "zdarzenia: " .. #S.handles .. " słuchanych, " .. S.n .. " przyszło"
  if #S.handles == 0 then error(table.concat(parts, ", ") .. " (Polestar.On nie działa)") end
  if tostring(P.version) ~= "0.3.7" then parts[#parts + 1] = "INNA WERSJA niż 0.3.7: sprawdź poradnik profesji i Prowadź" end
  return table.concat(parts, ", ")
end })

-- 15.11 (R30 P08, P42): funkcje Polestara uzywane w GrimuarSetup (PlecakPlus.lua, Zloto.lua): czy sa i co zwracaja
table.insert(U.testChecksExtra, { "Polestar: przedmioty trasy (KeptItems, QoL.Kept)", function()
  local P = _G.Polestar
  if type(P) ~= "table" then return "brak Polestara (◆ tylko dla poradników profesji)" end
  local E, Q = P.Engine, P.QoL
  if not (E and type(E.KeptItems) == "function") then error("brak Polestar.Engine.KeptItems (Core\\Engine.lua:11484)") end
  if not (Q and type(Q.Kept) == "function") then error("brak Polestar.QoL.Kept (QoL\\Keep.lua:23)") end
  local ok, items = pcall(E.KeptItems)
  if not ok then error("KeptItems: " .. tostring(items)) end
  if type(items) ~= "table" then error("KeptItems zwraca " .. type(items) .. " zamiast tabeli") end
  local n, firstId, firstStep = 0, nil, nil
  for id, s in pairs(items) do
    n = n + 1
    if not firstId then firstId, firstStep = id, s end
  end
  if n == 0 then return "działa: trasa nie trzyma teraz żadnych przedmiotów" end
  local okK, k = pcall(Q.Kept, firstId)
  if not okK then error("QoL.Kept: " .. tostring(k)) end
  local g = G.itemRouteStep and G.itemRouteStep(firstId)
  return "działa: " .. n .. " przedmiotów, np. " .. tostring(firstId) .. " krok " .. tostring(firstStep) .. " (QoL.Kept: " .. tostring(k) ..
    ", Grimuar widzi: " .. (g and ("krok " .. g) or "nic") .. ")"
end })
table.insert(U.testChecksExtra, { "Polestar: koszt jazdy (Riding.EffectiveCost)", function()
  local P = _G.Polestar
  if type(P) ~= "table" then return "brak Polestara (cel złota ze stałą kwotą jazdy)" end
  local R = P.QoL and P.QoL.Riding
  if not (R and type(R.EffectiveCost) == "function") then error("brak Polestar.QoL.Riding.EffectiveCost (QoL\\Riding.lua:129)") end
  local ok, c = pcall(R.EffectiveCost, 1, 54)
  if not ok then error("EffectiveCost: " .. tostring(c)) end
  if type(c) ~= "number" then error("EffectiveCost zwraca " .. type(c) .. " zamiast miedziaków") end
  local okH, has = false, nil
  if type(R.HasRiding) == "function" then okH, has = pcall(R.HasRiding, 1) end
  local t = G.goldTarget and U.call(G.goldTarget)
  return "jazda 40 z Gnomeregan: " .. math.floor(c / 10000 + 0.5) .. " g, HasRiding(1): " .. (okH and tostring(has) or "brak") ..
    (type(t) == "table" and ("; cel złota na " .. tostring(t[1]) .. ": " .. tostring(t[2]) .. "–" .. tostring(t[3]) .. " g") or "")
end })
