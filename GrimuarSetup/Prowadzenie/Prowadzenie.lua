-- Grimuar: modul Engine (wspolne funkcje przez tabele G z innych modulow).
local ADDON_NAME, G = ...
local C_FROST = G.C_FROST
local C_GOLD = G.C_GOLD
local C_MUTED = G.C_MUTED
local C_OK = G.C_OK
local DUNGEONS = G.DUNGEONS
local FONT = G.FONT
local STAGES = G.STAGES
local TALENT_AT = G.TALENT_AT
local charKey = G.charKey
local knownSpellId = G.knownSpellId
local say = G.say

-- Czesc wydzielona z Engine.lua (podzial plikow >1000 linii, 12.11).
local S = G.S
local safeStr = G.safeStr
local sessionStart = G.sessionStart
local showToast = G.showToast
local xpUpdate = G.xpUpdate

-- ---------- znaczniki "Prowadz mnie" ----------
-- { opis, strefa, x, y, od poziomu, czy to oddanie }  wspolrzedne: allthings.how (07.10, beta), Warcraft Tavern
local GUIDE = {
  { "Książka: Tower of Azora", "Elwynn Forest", 65, 70, 10 },
  { "Książka: Hall of Explorers", "Ironforge", 76, 10, 10 },
  { "Książka: Thelsamar", "Loch Modan", 36, 49, 12 },
  { "Książka: Moonbrook", "Westfall", 45, 70, 15 },
  { "Książka: Sentinel Hill Inn", "Westfall", 53, 54, 15 },
  { "Książka: Mo'grosh (elity)", "Loch Modan", 77, 14, 18 },
  { "Książka: Mathystra", "Darkshore", 60, 22, 18 },
  { "Książka: Whelgar's", "Wetlands", 34, 48, 24 },
  { "Książka: Raven Hill Crypt", "Duskwood", 17, 29, 24 },
  { "Oddanie książek: Garion Wendell", "Stormwind City", 38, 81, 10, true },
}

local mapIds
local function findMapId(name)
  if not (C_Map and C_Map.GetMapInfo) then return nil end
  if not mapIds then
    mapIds = {}
    for id = 1, 3000 do
      local ok, info = pcall(C_Map.GetMapInfo, id)
      if ok and info and info.name then
        mapIds[info.name] = mapIds[info.name] or {}
        table.insert(mapIds[info.name], id)
      end
    end
  end
  local list = mapIds[name]
  if not list then return nil end
  local here = (C_Map.GetBestMapForUnit and C_Map.GetBestMapForUnit("player")) or 0
  local best, bestD
  for _, id in ipairs(list) do
    local dd = math.abs(id - here)
    if not bestD or dd < bestD then best, bestD = id, dd end
  end
  return best
end

-- 13.11 gracz (zrzut „Ksi□□ka: Hall of Explorers”): czcionka strzalki Polestara nie ma polskich liter, wiec podpis
-- dla strzalki (i TomTom) idzie bez ogonkow i z prostymi cudzyslowami; czat dostaje pelny polski tekst.
local PL = {
  ["\196\133"] = "a", ["\196\135"] = "c", ["\196\153"] = "e", ["\197\130"] = "l", ["\197\132"] = "n", ["\195\179"] = "o",
  ["\197\155"] = "s", ["\197\186"] = "z", ["\197\188"] = "z",
  ["\196\132"] = "A", ["\196\134"] = "C", ["\196\152"] = "E", ["\197\129"] = "L", ["\197\131"] = "N", ["\195\147"] = "O",
  ["\197\154"] = "S", ["\197\185"] = "Z", ["\197\187"] = "Z",
  ["\226\128\158"] = "\"", ["\226\128\157"] = "\"", ["\226\128\147"] = "-", ["\226\128\148"] = "-", ["\226\128\166"] = "...",
}
local function arrowText(s)
  s = tostring(s or ""):gsub("[\195-\197][\128-\191]", PL)
  return (s:gsub("\226\128[\128-\191]", PL))
end

-- Prowadzenie: najpierw strzalka Polestar (/way, prawdziwe sciezki), inaczej znacznik gry.
local function wayTo(mapID, x, y, label)
  if mapID and SlashCmdList and SlashCmdList.POLESTARWAY then
    local okW = pcall(SlashCmdList.POLESTARWAY, string.format("#%d %.2f %.2f %s", mapID, x, y, arrowText(label)))
    if okW then
      say("prowadzę: " .. label .. " (" .. x .. ", " .. y .. "). Idź za strzałką Polestar.")
      return true
    end
  end
  if mapID and TomTom and TomTom.AddWaypoint then
    local okT = pcall(function() TomTom:AddWaypoint(mapID, x / 100, y / 100, { title = arrowText(label) }) end)
    if okT then
      say("prowadzę: " .. label .. " (" .. x .. ", " .. y .. "). Idź za strzałką Polestar.")
      return true
    end
  end
  local ok = false
  if mapID and UiMapPoint and C_Map and C_Map.SetUserWaypoint then
    ok = pcall(function()
      if C_Map.CanSetUserWaypointOnMap and not C_Map.CanSetUserWaypointOnMap(mapID) then error("mapa") end
      C_Map.SetUserWaypoint(UiMapPoint.CreateFromCoordinates(mapID, x / 100, y / 100))
      if C_SuperTrack and C_SuperTrack.SetSuperTrackedUserWaypoint then C_SuperTrack.SetSuperTrackedUserWaypoint(true) end
    end)
  end
  if ok then
    say("znacznik: " .. label .. " (" .. x .. ", " .. y .. "). Strzałka na ekranie prowadzi, mapa M pokazuje punkt.")
  else
    say("nie udało się postawić znacznika. Cel: " .. label .. " (" .. x .. ", " .. y .. "), współrzędne są na dole mapy M.")
  end
  return ok
end

local function enablePolestarWaypoints()
  if GrimuarSetupDB.polestarWayV == 1 then return end
  local db = PolestarDB
  if type(db) ~= "table" then return end
  if type(db.settings) ~= "table" then db.settings = {} end
  if type(db.settings.nav) ~= "table" then db.settings.nav = {} end
  GrimuarSetupDB.polestarWayV = 1
  if db.settings.nav.answerTomTom ~= true then
    db.settings.nav.answerTomTom = true
    say("włączyłem w Polestar opcję Let other addons set waypoints. Wpisz /reload jeszcze raz, a Prowadź poprowadzi strzałką Polestar.")
    pcall(showToast, "wpisz /reload jeszcze raz: wtedy Prowadź (trener, książki) użyje strzałki Polestar.", "", false)
  end
end

local function guideTo(g)
  wayTo(findMapId(g[2]), g[3], g[4], g[1] .. ", " .. g[2])
end

-- 13.11: „/way reset” to w Polestarze Nav.ClearTarget, ktory chowa tez strzalke przewodnika do zmiany kroku,
-- a klik w quest w przewodniku jej nie przywraca (ten sam punkt). Oddajemy wiec tylko nasz punkt: ReleaseTarget.
local function releaseArrow()
  local ok = pcall(function()
    local nav = Polestar.Nav
    if nav.Trip and nav.Trip() and nav.EndTrip then nav.EndTrip() else nav.ReleaseTarget() end
  end)
  if not ok then pcall(function() if SlashCmdList and SlashCmdList.POLESTARWAY then SlashCmdList.POLESTARWAY("reset") end end) end
  pcall(function() C_Map.ClearUserWaypoint() end)
end

local function clearGuide()
  releaseArrow()
  say("znacznik usunięty.")
end

-- Trenerzy maga Przymierza: pozycje z danych Polestar (Core/ClassTrainers.lua), uiMapID jak w grze.
local MAGE_TRAINERS = {
  { "Marryk Nurribit", 1426, 28.71, 66.37, "Anvilmar, Coldridge Valley" },
  { "Magis Sparkmantle", 1426, 47.5, 52.08, "Kharanos, browar Thunderbrew" },
  { "Bink", 1455, 27.25, 8.3, "Ironforge, Mystic Ward" },
  { "Khelden Bremen", 1429, 49.66, 39.4, "Northshire Abbey" },
  { "Zaldimar Wefhellt", 1429, 43.25, 66.19, "Goldshire, karczma" },
  { "Jennea Cannon", 1453, 49.56, 85.8, "Stormwind, Mage Quarter" },
}
local NEAR_SW = { [1429] = true, [1436] = true, [1433] = true, [1431] = true, [1453] = true }

local function nearestTrainer()
  local here
  pcall(function() here = C_Map.GetBestMapForUnit("player") end)
  local best, bestD
  if here then
    local px, py
    pcall(function()
      local pos = C_Map.GetPlayerMapPosition(here, "player")
      if pos then px, py = pos:GetXY() end
    end)
    for _, t in ipairs(MAGE_TRAINERS) do
      if t[2] == here then
        local d = 0
        if px and py then d = (t[3] / 100 - px) ^ 2 + (t[4] / 100 - py) ^ 2 end
        if not bestD or d < bestD then best, bestD = t, d end
      end
    end
  end
  if best then return best end
  if here and NEAR_SW[here] then return MAGE_TRAINERS[6] end
  return MAGE_TRAINERS[3]
end

local function guideTrainer()
  local t = nearestTrainer()
  wayTo(t[2], t[3], t[4], t[1] .. ", trener maga")
end

local function bookDone(label)
  local b = GrimuarSetupDB.books and GrimuarSetupDB.books[charKey()]
  return b and b[label] or false
end

local function markBook(label)
  GrimuarSetupDB.books = GrimuarSetupDB.books or {}
  GrimuarSetupDB.books[charKey()] = GrimuarSetupDB.books[charKey()] or {}
  GrimuarSetupDB.books[charKey()][label] = true
  say("zapisane: " .. label .. ".")
end

local function nearestGuide()
  local zone = GetZoneText()
  for _, g in ipairs(GUIDE) do
    if g[2] == zone and not g[6] and not bookDone(g[1]) then return g end
  end
  return nil
end

-- ---------- dziennik sesji (czyta go Claude przy "sync") ----------
local function saveCurrent()
  pcall(xpUpdate)
  GrimuarSetupDB.cur = {
    char = charKey(), lastSeen = time(), startEpoch = S.startEpoch, xpGained = S.xpGained, level0 = S.level0,
    money0 = S.money0, deaths = S.deaths, zones = S.zones, budgetEnd = S.budgetEnd, budgetMins = S.budgetMins,
    xpEvents = S.xpEvents,
  }
  local lvl, xmax = UnitLevel("player") or 0, UnitXPMax("player") or 0
  local valid = type(lvl) == "number" and lvl > 0 and type(xmax) == "number" and xmax > 0
  if valid then
    GrimuarSetupDB.snapshot = {
      char = charKey(), time = date("%Y-%m-%d %H:%M"), level = lvl, xp = UnitXP("player"),
      xpMax = xmax, rested = (GetXPExhaustion and GetXPExhaustion()) or 0, money = GetMoney(),
      zone = GetZoneText(), checks = (GrimuarSetupDB.checks and GrimuarSetupDB.checks[charKey()]) or {},
    }
  elseif GrimuarSetupDB.snapshot then
    GrimuarSetupDB.snapshot.checks = (GrimuarSetupDB.checks and GrimuarSetupDB.checks[charKey()]) or GrimuarSetupDB.snapshot.checks
  end
end

local function commitSession(cur)
  if not cur or not cur.startEpoch then return end
  local mins = math.floor(((cur.lastSeen or time()) - cur.startEpoch) / 60 + 0.5)
  if mins < 1 then return end
  local snap = GrimuarSetupDB.snapshot
  local sameChar = snap and snap.char == cur.char
  GrimuarSetupDB.log = GrimuarSetupDB.log or {}
  GrimuarSetupDB.log[cur.char] = GrimuarSetupDB.log[cur.char] or {}
  local L = GrimuarSetupDB.log[cur.char]
  table.insert(L, {
    start = date("%Y-%m-%d %H:%M", cur.startEpoch), minutes = mins, levelFrom = cur.level0,
    levelTo = (sameChar and snap.level) or cur.level0, xp = cur.xpGained or 0,
    money = (sameChar and snap.money or 0) - (cur.money0 or 0), deaths = cur.deaths or {}, zones = cur.zones or {},
  })
  while #L > 80 do table.remove(L, 1) end
end

local function sessionLogin()
  local cur = GrimuarSetupDB.cur
  if cur and cur.char == charKey() and cur.lastSeen and time() - cur.lastSeen < 900 then
    sessionStart(cur)
    S.budgetEnd, S.budgetMins = cur.budgetEnd, cur.budgetMins
    if S.budgetEnd then
      S.warned10 = (S.budgetEnd - time()) / 60 <= 10
      S.warnedEnd = time() >= S.budgetEnd
    end
  else
    if cur then commitSession(cur) end
    sessionStart(nil)
  end
  GrimuarSetupDB.cur = nil
end

local function onDeath()
  local by, pvp
  pcall(function()
    if UnitExists("target") then
      by = safeStr(UnitName("target"))
      local okp, isP = pcall(function() return UnitIsPlayer("target") and true or false end)
      if okp then pvp = isP end
    end
  end)
  table.insert(S.deaths, { t = date("%H:%M"), zone = GetZoneText(), sub = GetSubZoneText(), level = UnitLevel("player"), by = by, pvp = pvp })
end

-- ---------- prowadzenie krok po kroku ("Teraz zrob") ----------
local skipped = {}


local function openTalents()
  local ok = pcall(function()
    if ToggleTalentFrame then ToggleTalentFrame() return end
    if PlayerSpellsUtil and PlayerSpellsUtil.ToggleClassTalentFrame then PlayerSpellsUtil.ToggleClassTalentFrame() return end
    error("brak")
  end)
  if not ok then say("wciśnij N, żeby otworzyć talenty.") end
end

local function openMap()
  if not pcall(ToggleWorldMap) then say("wciśnij M, żeby otworzyć mapę.") end
end

local function questStats()
  local total, done = 0, 0
  pcall(function()
    if C_QuestLog and C_QuestLog.GetNumQuestLogEntries and C_QuestLog.GetInfo then
      local n = C_QuestLog.GetNumQuestLogEntries()
      for i = 1, n do
        local info = C_QuestLog.GetInfo(i)
        if info and not info.isHeader and not info.isHidden then
          total = total + 1
          if info.questID and C_QuestLog.IsComplete and C_QuestLog.IsComplete(info.questID) then done = done + 1 end
        end
      end
    elseif GetNumQuestLogEntries then
      local n = GetNumQuestLogEntries()
      for i = 1, n do
        local _, _, _, isHeader, _, isComplete = GetQuestLogTitle(i)
        if not isHeader then
          total = total + 1
          if isComplete == 1 then done = done + 1 end
        end
      end
    end
  end)
  return total, done
end

local function stageOf(l)
  for _, s in ipairs(STAGES) do
    if l >= s.from and l <= s.to then return s end
  end
  return STAGES[#STAGES]
end

local function setCheck(k)
  GrimuarSetupDB.checks = GrimuarSetupDB.checks or {}
  GrimuarSetupDB.checks[charKey()] = GrimuarSetupDB.checks[charKey()] or {}
  GrimuarSetupDB.checks[charKey()][k] = true
end

local function unsetCheck(k)
  local c = GrimuarSetupDB.checks and GrimuarSetupDB.checks[charKey()]
  if c then c[k] = nil end
end

local function unmarkBook(label)
  local b = GrimuarSetupDB.books and GrimuarSetupDB.books[charKey()]
  if b then b[label] = nil end
end

local function polestarLoaded()
  local loaded = false
  pcall(function()
    if C_AddOns and C_AddOns.IsAddOnLoaded then loaded = C_AddOns.IsAddOnLoaded("Polestar") and true or false
    elseif IsAddOnLoaded then loaded = IsAddOnLoaded("Polestar") and true or false end
  end)
  return loaded
end

-- eksport do pozostalych modulow
G.GUIDE = GUIDE
G.mapIds = mapIds
G.findMapId = findMapId
G.wayTo = wayTo
G.enablePolestarWaypoints = enablePolestarWaypoints
G.guideTo = guideTo
G.clearGuide = clearGuide
G.releaseArrow = releaseArrow
G.MAGE_TRAINERS = MAGE_TRAINERS
G.NEAR_SW = NEAR_SW
G.nearestTrainer = nearestTrainer
G.guideTrainer = guideTrainer
G.bookDone = bookDone
G.markBook = markBook
G.nearestGuide = nearestGuide
G.saveCurrent = saveCurrent
G.commitSession = commitSession
G.sessionLogin = sessionLogin
G.onDeath = onDeath
G.skipped = skipped
G.openTalents = openTalents
G.openMap = openMap
G.questStats = questStats
G.stageOf = stageOf
G.setCheck = setCheck
G.unsetCheck = unsetCheck
G.unmarkBook = unmarkBook
G.polestarLoaded = polestarLoaded
