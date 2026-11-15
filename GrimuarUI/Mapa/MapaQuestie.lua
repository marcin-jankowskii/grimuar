-- Grimuar UI: dane zadan z Questie dla zakladki Mapa (14.11, zrzut gracza: „ta mape chcialbym zebys jakos lepiej zrobil”).
-- Questie trzyma w ActiveQuests zadania z dziennika: cele (Objectives / SpecialObjectives, spawnList[..].Spawns[strefa]
-- = {{x, y}}) i oddajacych (Finisher.NPC / GameObject). Strefy Questie to AreaId; ZoneDB zamienia je na uiMapID mapy.
-- Tylko odczyt: w tabelach Questie nic nie zapisujemy. Bez Questie mapa dziala dalej, tylko bez tych znacznikow.
local ADDON, U = ...
local C = U.C

-- kolory zadan: ciemne i nasycone, zeby bylo je widac na jasnym pergaminie mapy
local PALETTE = { { 0.78, 0.16, 0.12 }, { 0.12, 0.38, 0.78 }, { 0.16, 0.55, 0.2 }, { 0.55, 0.2, 0.7 }, { 0.05, 0.55, 0.55 },
  { 0.75, 0.38, 0.05 }, { 0.75, 0.12, 0.45 }, { 0.2, 0.25, 0.45 } }
U.QUEST_COLORS = PALETTE
local DONE = "Interface\\AddOns\\Questie\\Icons\\complete.blp"

local function mod(name)
  local L = QuestieLoader
  if not (L and L.ImportModule) then return nil end
  local ok, m = pcall(L.ImportModule, L, name)
  return ok and type(m) == "table" and m or nil
end

local function areaOf(uiMapID)
  local Z = mod("ZoneDB")
  if not (Z and Z.GetAreaIdByUiMapId) then return nil end
  local ok, a = pcall(Z.GetAreaIdByUiMapId, Z, uiMapID)
  return ok and a or nil
end

-- dopisuje do out punkty z tabeli Questie { [AreaId] = { {x, y}, ... } } (wspolrzedne 0-100; -1 = wnetrze lochu)
local function spawnsIn(spawns, area, out, base)
  local list = type(spawns) == "table" and spawns[area]
  if type(list) ~= "table" then return end
  for _, c in ipairs(list) do
    local x, y = type(c) == "table" and tonumber(c[1]), type(c) == "table" and tonumber(c[2])
    if x and y and x >= 0 and y >= 0 and x <= 100 and y <= 100 then
      local p = { x = x / 100, y = y / 100 }
      for k, v in pairs(base) do p[k] = v end
      out[#out + 1] = p
    end
  end
end

local cache = {}
function U.questPinsReset() cache = {} end

-- pins: { x, y (0-1), kind = "obj" | "done", qid, title, text, name, col }
-- quests: { qid, title, complete, col, pins = { ... } } dla zadan, ktore maja punkty na tej mapie
-- ok = false, gdy Questie nie podal danych (brak addonu albo jeszcze sie wczytuje)
function U.questPins(uiMapID)
  if cache.map == uiMapID and cache.pins and GetTime() - (cache.at or 0) < 4 then return cache.pins, cache.quests, cache.ok end
  local pins, quests = {}, {}
  local AQ, DB = mod("ActiveQuests"), mod("QuestieDB")
  local area = uiMapID and areaOf(uiMapID)
  local ok = AQ ~= nil and type(AQ.Get) == "function" and DB ~= nil and area ~= nil
  if ok then
    for _, q in ipairs(U.questList and U.questList() or {}) do
      local acc = (not q.header) and U.call(AQ.Get, q.id)
      local quest = type(acc) == "table" and acc.quest
      if type(quest) == "table" then
        local mine = {}
        if q.complete then
          local fin = type(quest.Finisher) == "table" and quest.Finisher or {}
          for _, id in ipairs(type(fin.NPC) == "table" and fin.NPC or {}) do
            spawnsIn(U.call(DB.QueryNPCSingle, id, "spawns"), area, mine,
              { kind = "done", name = U.call(DB.QueryNPCSingle, id, "name") })
          end
          for _, id in ipairs(type(fin.GameObject) == "table" and fin.GameObject or {}) do
            spawnsIn(U.call(DB.QueryObjectSingle, id, "spawns"), area, mine,
              { kind = "done", name = U.call(DB.QueryObjectSingle, id, "name") })
          end
        else
          local function objs(list)
            for _, o in pairs(type(list) == "table" and list or {}) do
              if type(o) == "table" and o.Completed ~= true then
                local before = #mine
                for _, sl in pairs(type(o.spawnList) == "table" and o.spawnList or {}) do
                  if type(sl) == "table" then
                    spawnsIn(sl.Spawns, area, mine, { kind = "obj", text = o.Description, name = sl.Name, otype = o.Type })
                  end
                end
                if #mine == before then spawnsIn(o.Coordinates, area, mine, { kind = "obj", text = o.Description, otype = o.Type }) end
              end
            end
          end
          objs(quest.Objectives)
          objs(quest.SpecialObjectives)
        end
        if #mine > 0 then
          local col = q.complete and C.gold or PALETTE[(#quests % #PALETTE) + 1]
          for _, p in ipairs(mine) do
            p.qid, p.title, p.col = q.id, q.title, col
            pins[#pins + 1] = p
          end
          quests[#quests + 1] = { qid = q.id, title = q.title, complete = q.complete, col = col, pins = mine }
        end
      end
    end
  end
  cache = { map = uiMapID, at = GetTime(), pins = pins, quests = quests, ok = ok }
  return pins, quests, ok
end
U.QUEST_DONE_ICON = DONE

-- 14.11 (zrzut Dziennika: „tu brakuje czegos takiego jak prowadz, zebym lecial z questem”): wszystkie miejsca zadania
-- we wszystkich strefach (cele albo oddajacy, gdy gotowe) i najlepsze z nich: najblizsze na mapie, na ktorej jestes,
-- potem ten sam kontynent. { map, x, y (0-1), kind, name, text }
local contCache = {}
local function continentOf(ui)
  if contCache[ui] ~= nil then return contCache[ui] end
  local id, guard, cont = ui, 0, false
  while id and guard < 8 do
    local info = U.call(C_Map.GetMapInfo, id)
    if not info then break end
    if info.mapType and info.mapType <= ((Enum and Enum.UIMapType and Enum.UIMapType.Continent) or 2) then cont = id break end
    id, guard = info.parentMapID, guard + 1
  end
  contCache[ui] = cont
  return cont
end
function U.questTargets(qid)
  local AQ, DB, Z = mod("ActiveQuests"), mod("QuestieDB"), mod("ZoneDB")
  if not (AQ and DB and Z and Z.GetUiMapIdByAreaId) then return {} end
  local acc = U.call(AQ.Get, qid)
  local quest = type(acc) == "table" and acc.quest
  if type(quest) ~= "table" then return {} end
  local out = {}
  local function add(spawns, kind, name, text)
    for area, list in pairs(type(spawns) == "table" and spawns or {}) do
      local ok, ui = pcall(Z.GetUiMapIdByAreaId, Z, area)
      if ok and ui then
        for _, c in ipairs(type(list) == "table" and list or {}) do
          local x, y = type(c) == "table" and tonumber(c[1]), type(c) == "table" and tonumber(c[2])
          if x and y and x >= 0 and y >= 0 and x <= 100 and y <= 100 then
            out[#out + 1] = { map = ui, x = x / 100, y = y / 100, kind = kind, name = name, text = text }
          end
        end
      end
    end
  end
  if U.call(C_QuestLog.IsComplete, qid) then
    local fin = type(quest.Finisher) == "table" and quest.Finisher or {}
    for _, id in ipairs(type(fin.NPC) == "table" and fin.NPC or {}) do
      add(U.call(DB.QueryNPCSingle, id, "spawns"), "done", U.call(DB.QueryNPCSingle, id, "name"))
    end
    for _, id in ipairs(type(fin.GameObject) == "table" and fin.GameObject or {}) do
      add(U.call(DB.QueryObjectSingle, id, "spawns"), "done", U.call(DB.QueryObjectSingle, id, "name"))
    end
  else
    for _, list in ipairs({ quest.Objectives, quest.SpecialObjectives }) do
      for _, o in pairs(type(list) == "table" and list or {}) do
        if type(o) == "table" and o.Completed ~= true then
          local before = #out
          for _, sl in pairs(type(o.spawnList) == "table" and o.spawnList or {}) do
            if type(sl) == "table" then add(sl.Spawns, "obj", sl.Name, o.Description) end
          end
          if #out == before then add(o.Coordinates, "obj", nil, o.Description) end
        end
      end
    end
  end
  return out
end
function U.questBest(qid)
  local list = U.questTargets(qid)
  if #list == 0 then return nil end
  local here = U.call(C_Map.GetBestMapForUnit, "player")
  local px, py
  if here then
    local p = U.call(C_Map.GetPlayerMapPosition, here, "player")
    if p and p.GetXY then px, py = p:GetXY() px, py = U.num(px), U.num(py) end
  end
  local myCont = here and continentOf(here)
  local best, bestScore
  for _, t in ipairs(list) do
    local score
    if t.map == here and px then score = (t.x - px) ^ 2 + (t.y - py) ^ 2
    elseif myCont and continentOf(t.map) == myCont then score = 10
    else score = 20 end
    if not bestScore or score < bestScore then best, bestScore = t, score end
  end
  return best
end

-- odleglosc w metrach i kierunek z (x1, y1) do (x2, y2) na mapie strefy
local DIRS = { "pn.", "pn.-wsch.", "wsch.", "pd.-wsch.", "pd.", "pd.-zach.", "zach.", "pn.-zach." }
function U.mapDistance(mapID, x1, y1, x2, y2)
  local w, h = U.call(C_Map.GetMapWorldSize, mapID)
  w, h = U.num(w), U.num(h)
  if not (w and h and w > 0 and h > 0) then return nil end
  local dx, dy = (x2 - x1) * w, (y2 - y1) * h
  local yards = math.sqrt(dx * dx + dy * dy)
  local deg = math.deg(math.atan2(dx, -dy))
  local dir = DIRS[math.floor(((deg + 360 + 22.5) % 360) / 45) + 1]
  return yards * 0.9144, dir
end
function U.fmtDistance(m)
  if not m then return "" end
  if m < 1000 then return (math.floor(m / 10 + 0.5) * 10) .. " m" end
  return (string.format("%.1f km", m / 1000):gsub("%.", ","))
end

-- 14.11 (hub do konca): kto ma dla Ciebie nowe zadanie („!”) na tej mapie. Questie liczy dostepne zadania
-- (AvailableQuests.__availableQuestsByNpc: postac -> zadania); zadania z trasy Polestara oznaczone route = true.
-- { x, y, name, quests = { { id, title, level, route } }, route }
local acache = {}
U.QUEST_AVAIL_ICON = (DONE:gsub("complete%.blp$", "available.blp"))
U.QUEST_AVAIL_GRAY = (DONE:gsub("complete%.blp$", "available_gray.blp"))
-- 15.11 (gracz: „przyjalem questa, a na minimapie dalej jest wykrzyknik”): Questie przelicza swoja liste z opoznieniem,
-- wiec quest w dzienniku albo juz oddany nie jest „dostepny”, a NPC bez zadnego dostepnego questa nie dostaje „!”
local function stillAvailable(qid)
  if U.call(C_QuestLog and C_QuestLog.IsOnQuest, qid) then return false end
  if U.call(C_QuestLog and C_QuestLog.IsQuestFlaggedCompleted, qid) then return false end
  return true
end
function U.availableReset() acache = {} end
function U.availablePins(uiMapID)
  if acache.map == uiMapID and acache.list and GetTime() - acache.at < 8 then return acache.list end
  local AV, DB = mod("AvailableQuests"), mod("QuestieDB")
  local area = uiMapID and areaOf(uiMapID)
  local out = {}
  local byNpc = AV and AV.__availableQuestsByNpc
  if type(byNpc) == "table" and DB and area then
    local route = (U.polestarQuests and U.polestarQuests().inGuide) or {}
    for npcId, qs in pairs(byNpc) do
      if type(npcId) == "number" and type(qs) == "table" and next(qs) then
        local spawns = U.call(DB.QueryNPCSingle, npcId, "spawns")
        local list = type(spawns) == "table" and spawns[area]
        if type(list) == "table" then
          local quests, onRoute = {}, false
          for qid in pairs(qs) do
            if stillAvailable(qid) then
            local title = U.call(DB.QueryQuestSingle, qid, "name") or ("#" .. tostring(qid))
            local lvl = U.num(U.call(DB.QueryQuestSingle, qid, "questLevel"))
            quests[#quests + 1] = { id = qid, title = title, level = lvl, route = route[qid] == true }
            if route[qid] then onRoute = true end
            end
          end
          table.sort(quests, function(a, b) return (a.level or 0) < (b.level or 0) end)
          local name = U.call(DB.QueryNPCSingle, npcId, "name")
          for _, c in ipairs(#quests > 0 and list or {}) do
            local x, y = type(c) == "table" and tonumber(c[1]), type(c) == "table" and tonumber(c[2])
            if x and y and x >= 0 and y >= 0 and x <= 100 and y <= 100 then
              out[#out + 1] = { x = x / 100, y = y / 100, name = name, quests = quests, route = onRoute }
            end
          end
        end
      end
    end
  end
  acache = { map = uiMapID, at = GetTime(), list = out }
  return out
end
