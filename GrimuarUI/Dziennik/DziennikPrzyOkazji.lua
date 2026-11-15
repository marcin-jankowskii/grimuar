-- Grimuar UI: „Przy okazji” i „Za Toba” z Polestara (15.11, R30 P04; gracz: „wstepnie wszystko jak rekomendujesz”).
-- * Przy okazji: Engine.GetWhileHereList (Core\Engine.lua:10875): cele z dalszych krokow trasy, ktore sa blisko
--   (zrob, oddaj, wez, odkryj lot), z odlegloscia w jardach i krokiem;
-- * Za Toba: Engine.GetBehind (Core\Engine.lua:6286): questy w dzienniku, ktorych robote trasa juz minela.
-- W Dzienniku: wiersz „Przy okazji i za Toba” na liscie, po kliknieciu karty (Hub\Bloki.lua) zamiast pergaminu;
-- klik w karte prowadzi przez G.wayTo (wspolrzedne Era przeliczone U.psLive). Kompas (Hud\Kompas.lua) bierze
-- U.psHereSpots(): niebieskie romby z odlegloscia. Tylko odczyt: pomijanie zostaje w oknie Polestara; strzalke
-- Polestara wprost (AimWhileHere, AimBehind) ustawiamy tylko na klik gracza i tylko, gdy brak wspolrzednych.
local ADDON, U = ...
local G, C = U.G or {}, U.C

local K = { at = -100, d = nil, panel = nil }
local TTL = 3 -- s: odleglosci zmieniaja sie, gdy idziesz
local KIND = {
  work = { "zrób przy okazji", "Interface\\Icons\\INV_Sword_04" },
  turnin = { "oddaj przy okazji", "Interface\\Icons\\INV_Misc_Note_01" },
  take = { "weź przy okazji", "Interface\\Icons\\INV_Misc_Note_02" },
  flight = { "odkryj lot", "Interface\\Icons\\INV_Misc_Map_01" },
}
local BEHIND_ICON = "Interface\\Icons\\INV_Misc_Book_09"

local function PS() return _G.Polestar end
local function engine()
  local P = PS()
  return type(P) == "table" and P.Engine or nil
end
local function plural(n, one, few, many)
  if n == 1 then return one end
  local d, h = n % 10, n % 100
  if d >= 2 and d <= 4 and (h < 12 or h > 14) then return few end
  return many
end
local function stepNo(s)
  local E = engine()
  if E and type(E.StepNumber) == "function" and type(s) == "number" then
    local ok, n = pcall(E.StepNumber, s)
    if ok and type(n) == "number" then return n end
  end
  return s
end
local function plain(s)
  if type(s) ~= "string" then return nil end
  return U.polestarText and U.polestarText(s) or s
end
local function live(p)
  if type(p) ~= "table" or not (p.map and p.x and p.y) then return nil end
  if U.psLive then return U.psLive(p) end
  return p.map, p.x, p.y
end
local function dist(yards)
  yards = U.num(yards)
  if not yards then return "" end
  return U.fmtDistance and U.fmtDistance(yards * 0.9144) or (math.floor(yards + 0.5) .. " yd")
end

-- ---------- dane ----------
local function hereList()
  local E = engine()
  if not (E and type(E.GetWhileHereList) == "function") then return nil end
  local ok, list = pcall(E.GetWhileHereList)
  if not ok or type(list) ~= "table" then return nil end
  local out = {}
  for i, v in ipairs(list) do
    if type(v) == "table" then
      local m, x, y = live(v)
      out[#out + 1] = { i = i, text = plain(v.hereText or v.text) or "?", kind = v.here, yards = U.num(v.yards),
        step = stepNo(v.firstStep or v.step), map = m, x = U.num(x), y = U.num(y), quest = v.quest, later = v.later and true or false }
    end
  end
  return out
end

local function behindList()
  local E = engine()
  if not (E and type(E.GetBehind) == "function") then return nil end
  local ok, list = pcall(E.GetBehind)
  if not ok or type(list) ~= "table" then return nil end
  local g = type(E.GetGuide) == "function" and U.call(E.GetGuide)
  local steps = type(g) == "table" and type(g.steps) == "table" and g.steps or nil
  local out = {}
  for _, b in ipairs(list) do
    if type(b) == "table" and b.quest then
      local st = steps and steps[b.step]
      local goal = type(st) == "table" and type(st.goals) == "table" and st.goals[b.goal] or nil
      local m, x, y = live(goal)
      out[#out + 1] = { quest = b.quest, title = plain(b.title) or ("#" .. b.quest), step = stepNo(b.step), zone = b.zone,
        yards = U.num(b.yards), map = m, x = U.num(x), y = U.num(y) }
    end
  end
  return out
end

-- { ok, here = {...}, behind = {...}, n, near (jardy najblizszego) }; pamiec 3 s albo do zdarzenia Polestara
function U.psNearData(force)
  if not force and K.d and GetTime() - K.at < TTL then return K.d end
  local d = { ok = false, here = {}, behind = {}, n = 0 }
  local h, b = hereList(), behindList()
  if h or b then d.ok = true end
  d.here, d.behind = h or {}, b or {}
  d.n = #d.here + #d.behind
  for _, e in ipairs(d.here) do if e.yards and (not d.near or e.yards < d.near) then d.near = e.yards end end
  K.d, K.at = d, GetTime()
  return d
end

-- kompas: punkty „Przy okazji” { map, x, y } (procenty, mapa zywa), najblizsze pierwsze
function U.psHereSpots()
  local out = {}
  for _, e in ipairs(hereList() or {}) do
    if e.map and e.x and e.y then out[#out + 1] = { map = e.map, x = e.x, y = e.y, yards = e.yards, text = e.text } end
  end
  return out
end

-- ---------- prowadzenie ----------
local function go(e, label, aim)
  if e.map and e.x and e.y and G.wayTo then
    local ok, res = pcall(G.wayTo, e.map, tonumber(string.format("%.2f", e.x)), tonumber(string.format("%.2f", e.y)), label)
    if ok and res then
      if U.IsOpen and U.IsOpen() then U.Close() end
      return
    end
  end
  -- zapas bez wspolrzednych: strzalka Polestara wprost, tylko na ten klik gracza
  local E = engine()
  if aim and E and type(E[aim[1]]) == "function" then
    local ok, res = pcall(E[aim[1]], aim[2])
    if ok and res then
      U.say("prowadzę: " .. label .. ". Idź za strzałką Polestar.")
      if U.IsOpen and U.IsOpen() then U.Close() end
      return
    end
  end
  U.say("Polestar nie podał miejsca: " .. label .. ".")
end

-- ---------- karty w Dzienniku ----------
local function hereCard(e)
  local k = KIND[e.kind] or { "przy okazji", "Interface\\Icons\\INV_Misc_Note_02" }
  local eta = (e.map and e.x and G.etaText) and U.call(G.etaText, e.map, e.x, e.y) or ""
  return {
    title = e.text, right = dist(e.yards) .. (eta or ""), sub = "krok " .. tostring(e.step or "?") .. " · " .. k[1],
    icon = k[2], col = C.frost, rightCol = C.frost,
    tip = e.text .. "\n\nPolestar: to cel z kroku " .. tostring(e.step or "?") .. " trasy" .. (e.later and " (dalej w tym przewodniku)" or "") ..
      ", a jesteś obok. Zrobione teraz, oszczędza powrót.\nKlik: Prowadź (strzałka Polestar).",
    onClick = function() go(e, e.text, { "AimWhileHere", e.i }) end,
  }
end
local function behindCard(e)
  local eta = (e.map and e.x and G.etaText) and U.call(G.etaText, e.map, e.x, e.y) or ""
  return {
    title = e.title, right = (e.yards and dist(e.yards) or "") .. (eta or ""), sub = "krok " .. tostring(e.step or "?") .. (e.zone and (" · " .. e.zone) or ""),
    icon = BEHIND_ICON, col = C.danger,
    tip = e.title .. "\n\nPolestar: quest w dzienniku, którego robotę trasa już minęła (krok " .. tostring(e.step or "?") .. ").\n" ..
      "Zrób go po drodze albo pomiń w oknie Polestara.\nKlik: Prowadź (strzałka Polestar).",
    onClick = function() go(e, e.title, { "AimBehind", e.quest }) end,
  }
end

local function draw()
  local p = K.panel
  local d = U.psNearData(true)
  p:Begin(true)
  p:Title("Przy okazji i za Tobą", "Według Polestara: cele z dalszych kroków trasy, które masz pod ręką, i questy, które trasa zostawiła za Tobą.")
  if #d.here > 0 then
    p:Head("Przy okazji", #d.here .. " " .. plural(#d.here, "cel", "cele", "celów") .. (d.near and (" · najbliżej " .. dist(d.near)) or ""))
    local cards = {}
    for _, e in ipairs(d.here) do cards[#cards + 1] = hereCard(e) end
    p:Cards(cards, { minW = 300 })
  end
  if #d.behind > 0 then
    p:Head("Za Tobą", #d.behind .. " " .. plural(#d.behind, "quest", "questy", "questów"))
    local cards = {}
    for _, e in ipairs(d.behind) do cards[#cards + 1] = behindCard(e) end
    p:Cards(cards, { minW = 300 })
  end
  if d.n == 0 then
    p:Para(d.ok and "Nic w pobliżu: Polestar nie ma teraz celów przy okazji ani zaległych questów." or
      "Polestar wyłączony albo bez przewodnika: tej listy nie ma.", C.muted)
  end
  p:Gap(6)
  p:Para("Klik w kartę: Prowadź (strzałka Polestar), hub się zamknie. Pominąć cel albo quest możesz w oknie Polestara.", C.faint, 12)
  p:End()
end

-- Dziennik (TabDziennik.lua): on = pokaz karty zamiast pergaminu, nil = pergamin
function U.psNearShow(D, on)
  if not (D and D.pa) then return end
  if not on then
    if K.panel then K.panel:Hide() end
    D.pa:Show()
    return
  end
  if not K.panel then
    K.panel = U.Blocks(D.pa:GetParent())
    K.panel:SetPoint("TOPLEFT", D.pa, "TOPLEFT")
    K.panel:SetPoint("BOTTOMRIGHT", D.pa, "BOTTOMRIGHT")
  end
  D.pa:Hide()
  K.panel:Show()
  local ok, err = pcall(draw)
  if not ok and U.logError then U.logError("dziennik/przy okazji", err) end
end

-- wiersz na liscie Dziennika: { title, tag } albo nil, gdy nic nie ma
function U.psNearRow()
  local d = U.psNearData()
  if d.n == 0 then return nil end
  local parts = {}
  if #d.here > 0 then parts[#parts + 1] = "przy okazji " .. #d.here end
  if #d.behind > 0 then parts[#parts + 1] = "za Tobą " .. #d.behind end
  return { title = "Polestar: " .. table.concat(parts, " · "), tag = d.near and dist(d.near) or (#d.behind .. " zaległe") }
end

if U.onPolestar then
  U.onPolestar({ "WHILE_HERE_CHANGED", "STEP_CHANGED", "GUIDE_CHANGED", "TABS_CHANGED", "PINS_CHANGED" }, function()
    K.at = -100
  end)
end

-- ---------- /gr test ----------
U.testChecksExtra = U.testChecksExtra or {}
table.insert(U.testChecksExtra, { "Polestar: przy okazji (GetWhileHereList)", function()
  local P = PS()
  if type(P) ~= "table" then return "brak Polestara (Dziennik i kompas bez „Przy okazji”)" end
  local E = P.Engine
  if not (E and type(E.GetWhileHereList) == "function") then error("brak Polestar.Engine.GetWhileHereList (Core\\Engine.lua:10875)") end
  local ok, list = pcall(E.GetWhileHereList)
  if not ok then error("GetWhileHereList: " .. tostring(list)) end
  if type(list) ~= "table" then error("GetWhileHereList zwraca " .. type(list) .. " zamiast tabeli") end
  local v = list[1]
  if not v then return "działa: teraz 0 celów w pobliżu" end
  return "działa: " .. #list .. " celów, pierwszy: " .. tostring(v.here) .. ", " .. tostring(v.yards) .. " yd, krok " .. tostring(stepNo(v.firstStep or v.step)) ..
    ", mapa " .. tostring(v.map) .. (v.f and " (ramka Era)" or "")
end })
table.insert(U.testChecksExtra, { "Polestar: za Tobą (GetBehind)", function()
  local P = PS()
  if type(P) ~= "table" then return "brak Polestara (Dziennik bez „Za Tobą”)" end
  local E = P.Engine
  if not (E and type(E.GetBehind) == "function") then error("brak Polestar.Engine.GetBehind (Core\\Engine.lua:6286)") end
  local ok, list = pcall(E.GetBehind)
  if not ok then error("GetBehind: " .. tostring(list)) end
  if type(list) ~= "table" then error("GetBehind zwraca " .. type(list) .. " zamiast tabeli") end
  local b = list[1]
  if not b then return "działa: brak zaległych questów" end
  local ex = behindList() or {}
  return "działa: " .. #list .. " questów, pierwszy: " .. tostring(b.title) .. " (krok " .. tostring(stepNo(b.step)) .. ", " .. tostring(b.yards) .. " yd)" ..
    ((ex[1] and ex[1].map) and ", miejsce znane" or ", bez współrzędnych (klik: strzałka Polestara)")
end })
