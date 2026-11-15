-- Grimuar UI: alarm rzadkiego stwora w poblizu (15.11, R30 P33; gracz: „rzadkie potwory w strefie i alarm”).
-- Wpis w lewym kanale powiadomien (Hud\HudEkran.lua U.toast): „RZADKI / Mangeclaw (11, elita) · 120 yd · 3 lupy ·
-- klik: Prowadz”; klik = Prowadz (strzalka Polestar, G.wayTo). Raz na rzadkiego na 10 minut. Przelacznik
-- w Ustawieniach > Grimuar (GrimuarUIDB.rareAlarm, domyslnie wlaczony).
-- Zrodla (Polestar Rares\Rares.lua, sprawdzone w kodzie 0.3.7.2):
-- * RARES_HISTORY(key): Polestar zapisuje kazde wykrycie (vignette, tabliczka, cel, myszka; Rares\Detect.lua)
--   w historii (Rares.Record) i wysyla ten komunikat zawsze, takze przy schowanym oknie przewodnika. To nasz glowny
--   i tani zapas: RARE_SPOTTED idzie tylko przy pokazanym oknie przewodnika (fire(): ns.GuideShown()).
-- * RARE_SPOTTED(alert): wtedy Polestar sam pokazuje swoja karte (Rares\Toast.lua, PolestarRareToast).
-- Bez dubli: karte Polestara chowa tylko jego opcja rares.alerts („Alert for rares” w opcjach Rares), ktora gasi tez
-- RARE_SPOTTED, dzwiek i przycisk „Target” (bezpieczny /targetexact). Ustawien Polestara nie zmieniamy, wiec gdy
-- przyszedl RARE_SPOTTED albo karta Polestara jest widoczna (Rares.Toast.Current() i jej ramka pokazana), nasz alarm
-- milczy (rzadki liczy sie jako pokazany). Gdy gracz schowa okno przewodnika albo sam wylaczy alerty Polestara,
-- alarm daje Grimuar. Polestar pomija tez rzadkich ignorowanych i w instancjach (Rares.Decide) - my tak samo.
-- * Bez Polestara (albo z wylaczonym modulem rzadkich, rares.enabled): NAME_PLATE_UNIT_ADDED i UnitClassification
--   „rare”/„rareelite” (tylko odczyt tabliczki, bez miejsca, wiec bez Prowadz).
-- W walce alarm czeka do konca walki (najwyzej 60 s), jak alert Polestara.
local ADDON, U = ...
local C = U.C
local G = U.G or {}

local A = { shown = {}, held = nil, timer = false, n = 0 }
local COOLDOWN, FRESH, HOLD = 600, 6, 60
local SIGHT = { nameplate = true, target = true, mouseover = true }

local function PS() return _G.Polestar end
local function tr(s) return (G.tr and type(s) == "string") and G.tr(s) or s end
local function secret(v) return issecretvalue and issecretvalue(v) end
local function on() return not (GrimuarUIDB and GrimuarUIDB.rareAlarm == false) end
local function rares()
  local P = PS()
  local Rs = type(P) == "table" and P.Rares
  if Rs and type(Rs.History) == "function" then return Rs end
end
-- modul rzadkich Polestara dziala (rares.enabled, odczyt Polestar.Get): wtedy zrodlem jest jego historia
local function polestarRares()
  local Rs = rares()
  if not Rs then return nil end
  local P = PS()
  local ok, enabled = false, nil
  if type(P.Get) == "function" then ok, enabled = pcall(P.Get, "rares.enabled") end
  if ok and enabled == false then return nil end
  return Rs
end
local function now() return (GetServerTime and GetServerTime()) or time() end
local function recent(key) local t = A.shown[key] return t ~= nil and GetTime() - t < COOLDOWN end

-- karta rzadkiego Polestara na ekranie -> klucz jej rzadkiego (albo true), inaczej nil
local function polestarCard()
  local Rs = rares()
  local T = Rs and Rs.Toast
  if not (T and type(T.Current) == "function") then return nil end
  local ok, cur = pcall(T.Current)
  if not (ok and type(cur) == "table") then return nil end
  local f = T.frame
  if f and f.IsShown and not f:IsShown() then return nil end
  return cur.key or true
end

local function lootText(n)
  if not n or n <= 0 then return nil end
  if n == 1 then return "1 łup" end
  local d, h = n % 10, n % 100
  if d >= 2 and d <= 4 and (h < 12 or h > 14) then return n .. " łupy" end
  return n .. " łupów"
end

local function guide(d)
  local m, x, y = d.map, d.x, d.y
  if U.psLive then m, x, y = U.psLive(d) end
  x, y = U.num(x), U.num(y)
  if m and x and y and G.wayTo then pcall(G.wayTo, m, x, y, tr("Rzadki") .. ": " .. tostring(d.name)) end
end

-- d = { name, level, levelMax, elite, loot (liczba), inSight, yards, map, x, y, f }
local function show(key, d)
  A.shown[key] = GetTime()
  A.n = A.n + 1
  local lv = (U.rareLevelText and U.rareLevelText(d.level, d.levelMax)) or (d.level and tostring(d.level)) or nil
  local inside = {}
  if lv then inside[#inside + 1] = lv end
  if d.elite then inside[#inside + 1] = tr("elita") end
  local text = tostring(d.name or "?") .. (#inside > 0 and (" (" .. table.concat(inside, ", ") .. ")") or "")
  if d.inSight then text = text .. " · " .. tr("w zasięgu wzroku")
  elseif d.yards then text = text .. " · " .. (math.floor(d.yards / 5 + 0.5) * 5) .. " yd" end
  local lt = lootText(d.loot)
  if lt then text = text .. " · " .. tr(lt) end
  local go = (d.map and d.x and d.y) and function() guide(d) end or nil
  if go then text = text .. " · " .. tr("klik: Prowadź") end
  local db = U.db and U.db() or {}
  if db.toastsTop or type(U.toast) ~= "function" then
    -- gracz woli wstege u gory (/hub komunikaty): bez klikniecia
    if G.showToast then pcall(G.showToast, tr("Rzadki") .. ": " .. text, "rare", false) else U.say(tr("Rzadki") .. ": " .. text) end
    return
  end
  U.toast("Rzadki", text, d.elite and C.gold or C.frost, 10, d.elite and true or false, go)
  pcall(PlaySound, (SOUNDKIT and SOUNDKIT.RAID_WARNING) or 8959, "Master")
end

-- tabliczka albo cel o tej nazwie: klasyfikacja i poziom (gdy Codex niewczytany)
local function unitOf(name)
  local units = { "target", "mouseover" }
  for i = 1, 40 do units[#units + 1] = "nameplate" .. i end
  for _, u in ipairs(units) do
    local okE, ex = pcall(UnitExists, u)
    if okE and ex and not secret(ex) then
      local okN, n = pcall(UnitName, u)
      if okN and type(n) == "string" and not secret(n) and n == name then
        local okC, cls = pcall(UnitClassification, u)
        return (okC and not secret(cls)) and cls or nil, U.num(U.call(UnitLevel, u))
      end
    end
  end
end

-- wpis historii Polestara -> d dla show(); Rares.Info czyta Codex tylko, gdy juz wczytany (nie laduje go)
local function fromHistory(e)
  local Rs = rares()
  local d = { name = e.name, level = U.num(e.level), inSight = SIGHT[e.src or ""] == true }
  if e.id and type(Rs.Info) == "function" then
    local ok, info = pcall(Rs.Info, "rare", e.id)
    if ok and type(info) == "table" then
      d.elite = info.elite and true or false
      if not d.level then d.level, d.levelMax = U.num(info.level), U.num(info.levelMax) end
      d.loot = type(info.loot) == "table" and #info.loot or nil
      d.name = d.name or info.name
    end
  end
  if d.inSight and d.elite == nil and d.name then
    local cls, lvl = unitOf(d.name)
    if cls then d.elite = cls == "rareelite" end
    d.level = d.level or lvl
  end
  if e.map and U.num(e.x) and U.num(e.y) then
    d.map, d.x, d.y = e.map, e.x, e.y
    local P = PS()
    if not d.inSight and type(P.PlayerPoint) == "function" and type(Rs.Yards) == "function" then
      local okP, me = pcall(P.PlayerPoint)
      if okP and me then
        local okY, yd = pcall(Rs.Yards, me, { map = d.map, x = d.x, y = d.y })
        if okY then d.yards = U.num(yd) end
      end
    end
  end
  return d
end

local function consider(key, e)
  local card = polestarCard()
  if card then
    -- Polestar pokazuje swoja karte: nasz alarm milczy (ten sam rzadki = pokazany, inny = sprobujemy przy kolejnym wykryciu)
    if card == key then A.shown[key] = GetTime() end
    return
  end
  if InCombatLockdown() or UnitAffectingCombat("player") then
    A.held = { key = key, at = GetTime() }
    return
  end
  show(key, fromHistory(e))
end

local function check(onlyKey, maxAge)
  if not on() then return end
  local Rs = polestarRares()
  if not Rs then return end
  local ok, h = pcall(Rs.History)
  if not (ok and type(h) == "table") then return end
  local t = now()
  for key, e in pairs(h) do
    if (not onlyKey or key == onlyKey) and type(e) == "table" and e.kind == "rare" and U.num(e.t) and t - e.t <= (maxAge or FRESH)
      and not (U.num(e.dead) and e.dead >= e.t) and not recent(key) then
      consider(key, e)
    end
  end
end

if U.onPolestar then
  -- Polestar pokazal swoja karte (okno przewodnika pokazane): ten rzadki jest juz zgloszony
  U.onPolestar({ "RARE_SPOTTED" }, function(_, a)
    if type(a) == "table" and a.key and a.source ~= "sample" then A.shown[a.key] = GetTime() end
  end)
  -- kazde wykrycie: sprawdzamy po chwili (RARE_SPOTTED z tego samego wykrycia i karta Polestara sa juz wtedy znane)
  U.onPolestar({ "RARES_HISTORY" }, function()
    if A.timer then return end
    A.timer = true
    C_Timer.After(0.3, function()
      A.timer = false
      local ok, err = pcall(check)
      if not ok and U.logError then U.logError("alarm rzadkiego", err) end
    end)
  end)
end

-- zapas bez Polestara: tabliczka rzadkiego
local function onPlate(unit)
  if not on() or polestarRares() or InCombatLockdown() then return end
  local okC, cls = pcall(UnitClassification, unit)
  if not okC or secret(cls) or (cls ~= "rare" and cls ~= "rareelite") then return end
  local okP, pl = pcall(UnitIsPlayer, unit)
  if not okP or secret(pl) or pl then return end
  local okD, dead = pcall(UnitIsDead, unit)
  if okD and not secret(dead) and dead then return end
  local okN, name = pcall(UnitName, unit)
  if not okN or type(name) ~= "string" or secret(name) or name == "" then return end
  local key = "name:" .. name
  if recent(key) then return end
  show(key, { name = name, level = U.num(U.call(UnitLevel, unit)), elite = cls == "rareelite", inSight = true })
end

local ev = CreateFrame("Frame")
ev:RegisterEvent("PLAYER_REGEN_ENABLED")
pcall(ev.RegisterEvent, ev, "NAME_PLATE_UNIT_ADDED")
ev:SetScript("OnEvent", function(_, event, unit)
  if event == "NAME_PLATE_UNIT_ADDED" then
    pcall(onPlate, unit)
  elseif A.held then
    local hd = A.held
    A.held = nil
    if GetTime() - hd.at > HOLD then return end
    -- po walce Polestar sam wypuszcza wstrzymany alert (Rares.Release): sprawdzamy chwile pozniej
    C_Timer.After(0.6, function() pcall(check, hd.key, HOLD) end)
  end
end)

-- ---------- przelacznik (GrimuarSetup Okno\Strony.lua G.TOGGLES, tez Ustawienia huba > Grimuar) ----------
if type(G.TOGGLES) == "table" then
  local entry = { "Alarm rzadkiego stwora w pobliżu (hub)", on, function()
    local d = U.db()
    d.rareAlarm = d.rareAlarm == false
    U.say(d.rareAlarm ~= false and "alarm rzadkich stworów włączony." or "alarm rzadkich stworów wyłączony.")
  end }
  local at = #G.TOGGLES + 1
  for i, t in ipairs(G.TOGGLES) do
    if type(t) == "table" and type(t[1]) == "string" and t[1]:find("^Komunikaty po lewej") then at = i + 1 end
  end
  table.insert(G.TOGGLES, at, entry)
end

-- ---------- /gr test ----------
U.testChecksExtra = U.testChecksExtra or {}
table.insert(U.testChecksExtra, { "Alarm rzadkiego (RARES_HISTORY, RARE_SPOTTED, Toast.Current)", function()
  if type(U.toast) ~= "function" then error("brak kanału powiadomień (Hud\\HudEkran.lua U.toast)") end
  local state = on() and "włączony" or "wyłączony (Ustawienia > Grimuar)"
  local P = PS()
  if type(P) ~= "table" then return state .. "; brak Polestara: zapas z tabliczek (bez Prowadź)" end
  local Rs = P.Rares
  if not (Rs and type(Rs.History) == "function") then error("brak Polestar.Rares.History (Rares\\Rares.lua:143)") end
  if not (Rs.Toast and type(Rs.Toast.Current) == "function") then error("brak Polestar.Rares.Toast.Current (Rares\\Toast.lua:429)") end
  for _, fn in ipairs({ "Yards", "Info" }) do
    if type(Rs[fn]) ~= "function" then error("brak Polestar.Rares." .. fn .. " (Rares\\Rares.lua)") end
  end
  if type(P.PlayerPoint) ~= "function" then error("brak Polestar.PlayerPoint (Core\\Guides.lua:140)") end
  local ok, cur = pcall(Rs.Toast.Current)
  if not ok then error("Toast.Current: " .. tostring(cur)) end
  local okG, shown = false, nil
  if type(P.GuideShown) == "function" then okG, shown = pcall(P.GuideShown) end
  return state .. "; źródło: " .. (polestarRares() and "historia Polestara (RARES_HISTORY)" or "tabliczki (rzadkie w Polestarze wyłączone)") ..
    "; okno przewodnika Polestara: " .. (okG and (shown and "pokazane (jego karta ma pierwszeństwo)" or "schowane (alarm daje Grimuar)") or "?") ..
    "; karta Polestara teraz: " .. (cur and "widoczna" or "brak") .. "; alarmów w tej sesji: " .. A.n
end })
