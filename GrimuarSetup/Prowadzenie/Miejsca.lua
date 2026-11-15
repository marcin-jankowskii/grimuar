-- Grimuar: miejsca NPC i trenerow w locie (15.11, R30 P30 i decyzja gracza Q6: „Polestar, a bez niego Questie”).
-- Zamiast przepisanych list (trenerzy maga w Prowadzenie.lua, pozycje NPC w Kroki.lua) Grimuar pyta w chwili potrzeby:
-- * trener klasy: Polestar.Engine.NearestClassTrainer (Core\Engine.lua:7288; dane Polestara Core\ClassTrainers.lua, bez
--   Codexu, wiec tanio), bez Polestara Questie (Townsfolk „Class Trainer”, jak kupcy w Vendor.lua);
-- * NPC po id: Polestar.Codex.Npc(id).spawns (Lookup\Codex.lua:564), bez Polestara albo gdy go nie zna: QuestieDB;
-- * trener profesji: Polestar.Nav.nearby.Find("trainer", linia) (Nav\Nearby.lua:433: najblizszy z czasem dojscia),
--   bez Polestara Questie (Townsfolk professionTrainers).
-- Codex Polestara (7,7 MB) i jego indeks uslug wczytujemy tylko na klik gracza (allowLoad) i nigdy w walce; przy zwyklym
-- odswiezaniu planu tylko z pamieci, Polestara bez Codexu albo Questie. Wspolrzedne z ramki Era (pole f) przeliczane
-- przez Polestar.Nav.LiveCoords. Wynik: { uiMapID, x, y, opis } (x, y w procentach, jak G.wayTo i loc w Kroki.lua).
local ADDON_NAME, G = ...

local NPC_TTL, TRAINER_TTL = 600, 60 -- s: NPC stoja w miejscu, najblizszy trener zalezy od tego, gdzie jestes
local K = { npc = {}, trainer = {}, classAt = -100, class = nil }

local function PS() return _G.Polestar end

local function round2(v) return math.floor(v * 100 + 0.5) / 100 end

-- punkt Polestara { map, x, y, f } -> map, x, y w procentach na zywej mapie
local function live(p)
  if type(p) ~= "table" then return nil end
  local m, x, y = p.map, tonumber(p.x), tonumber(p.y)
  if p.f then
    local N = PS() and PS().Nav
    if N and type(N.LiveCoords) == "function" then
      local ok, lm, lx, ly = pcall(N.LiveCoords, p)
      if ok and lm and lx then m, x, y = lm, lx, ly end
    end
  end
  if not (m and x and y) then return nil end
  if x <= 1 and y <= 1 then x, y = x * 100, y * 100 end
  return m, round2(x), round2(y)
end

local function mapName(map)
  local ok, i = pcall(C_Map.GetMapInfo, map)
  return ok and type(i) == "table" and i.name or nil
end

-- Codex Polestara gotowy: juz wczytany albo (na klik, poza walka) wczytany teraz
local function codexReady(allowLoad)
  local X = PS() and PS().Codex
  if not (X and type(X.IsLoaded) == "function") then return false end
  local okL, loaded = pcall(X.IsLoaded)
  if okL and loaded then return true end
  if not allowLoad or InCombatLockdown() or type(X.Load) ~= "function" then return false end
  local ok, res = pcall(X.Load)
  return ok and res and true or false
end

-- ---------- Questie (zapas, jak w Vendor.lua) ----------
local function questie()
  if not QuestieLoader then return nil end
  local ok, QDB, DU, ZDB = pcall(function()
    return QuestieLoader:ImportModule("QuestieDB"), QuestieLoader:ImportModule("DistanceUtils"), QuestieLoader:ImportModule("ZoneDB")
  end)
  if ok and QDB and DU and ZDB and QDB.QueryNPCSingle and DU.GetNearestSpawn and ZDB.GetUiMapIdByAreaId then return QDB, DU, ZDB end
  return nil
end

-- najblizszy z listy id NPC wg Questie -> { map, x, y, name }
local function questieNearest(ids)
  local QDB, DU, ZDB = questie()
  if not QDB or type(ids) ~= "table" then return nil end
  local fac = UnitFactionGroup("player") == "Horde" and "H" or "A"
  local best
  for k, v in pairs(ids) do
    local id = (type(v) == "number" and v) or (type(k) == "number" and k) or nil
    if id then
      pcall(function()
        local f = QDB.QueryNPCSingle(id, "friendlyToFaction")
        if f and f ~= "AH" and f ~= fac then return end
        local spawns = QDB.QueryNPCSingle(id, "spawns")
        if type(spawns) ~= "table" then return end
        local sp, zone, dist = DU.GetNearestSpawn(spawns)
        if sp and zone and dist and sp[1] and sp[1] >= 0 and (not best or dist < best.dist) then
          best = { id = id, x = sp[1], y = sp[2], zone = zone, dist = dist }
        end
      end)
    end
  end
  if not best then return nil end
  local out
  pcall(function()
    local map = ZDB:GetUiMapIdByAreaId(best.zone)
    if map then out = { map = map, x = round2(best.x), y = round2(best.y), name = QDB.QueryNPCSingle(best.id, "name") } end
  end)
  return out
end

-- lista Townsfolk z Questie; trener klasy z listy postaci (tylko Twoja klasa), reszta z modulu Townsfolk
local function townsfolk(key, charFirst)
  local char = Questie and Questie.db and Questie.db.char
  local mine = type(char) == "table" and type(char.townsfolk) == "table" and char.townsfolk[key] or nil
  if charFirst and mine then return mine end
  local list
  pcall(function()
    local town = QuestieLoader:ImportModule("Townsfolk")
    list = town and town.townsfolk and town.townsfolk[key]
  end)
  return list or mine
end

-- ---------- NPC po id ----------
-- -> { uiMapID, x, y, opis } albo nil; allowLoad: wolno wczytac Codex Polestara (klik gracza)
local function npcSpot(id, label, allowLoad)
  id = tonumber(id)
  if not id then return nil end
  local c = K.npc[id]
  -- z pamieci; na klik wynik z Questie liczymy jeszcze raz, gdy Polestar moze odpowiedziec (Q6: najpierw Polestar)
  if c and GetTime() - c.at < NPC_TTL and not (allowLoad and c.src ~= "Polestar" and PS() and PS().Codex) then
    return c.spot and { c.spot[1], c.spot[2], c.spot[3], label or c.spot[4] } or nil
  end
  local spot, src
  if codexReady(allowLoad) then
    src = "Polestar"
    local X = PS().Codex
    local ok, npc = pcall(X.Npc, id)
    if ok and type(npc) == "table" and type(npc.spawns) == "table" then
      local here = select(2, pcall(C_Map.GetBestMapForUnit, "player"))
      local pick
      for _, s in ipairs(npc.spawns) do
        if s.map == here then pick = s break end
      end
      pick = pick or npc.spawns[1]
      local m, x, y = live(pick)
      if m then spot = { m, x, y, label or npc.name or ("NPC " .. id) } end
    end
  end
  if not spot then
    local q = questieNearest({ id })
    if q then spot, src = { q.map, q.x, q.y, label or q.name or ("NPC " .. id) }, "Questie" end
  end
  -- bez Codexu (nie wolno go teraz wczytac) i bez Questie: nie zapamietujemy, klik sprobuje jeszcze raz
  if src then K.npc[id] = { at = GetTime(), spot = spot, src = src } end
  return spot
end

-- ---------- trener profesji (linia umiejetnosci: 129 First Aid, 182 Herbalism, 186 Mining, 356 Fishing...) ----------
local function trainerSpot(line, label, allowLoad)
  line = tonumber(line)
  if not line then return nil end
  local c = K.trainer[line]
  local N = PS() and PS().Nav and PS().Nav.nearby
  if c and GetTime() - c.at < TRAINER_TTL and not (allowLoad and c.src ~= "Polestar" and N) then return c.spot end
  local spot, src
  if N and type(N.Find) == "function" and codexReady(allowLoad) then
    src = "Polestar"
    local ok, place = pcall(N.Find, "trainer", line)
    if ok and type(place) == "table" then
      local m, x, y = live(place)
      if m then spot = { m, x, y, (place.name or "trener") .. (label and (", " .. label) or "") } end
    end
  end
  if not spot then
    local list
    pcall(function()
      local town = QuestieLoader:ImportModule("Townsfolk")
      list = town and type(town.professionTrainers) == "table" and town.professionTrainers[line]
    end)
    local q = list and questieNearest(list)
    if q then spot, src = { q.map, q.x, q.y, (q.name or "trener") .. (label and (", " .. label) or "") }, "Questie" end
  end
  if src then K.trainer[line] = { at = GetTime(), spot = spot, src = src } end
  return spot
end

-- spec z Kroki.lua: { npc = id, label } | { trainer = linia, label } | { uiMapID, x, y, opis } -> { uiMapID, x, y, opis }
local function resolveLoc(spec, allowLoad)
  if type(spec) ~= "table" then return nil end
  if spec.npc then return npcSpot(spec.npc, spec.label, allowLoad) end
  if spec.trainer then return trainerSpot(spec.trainer, spec.label, allowLoad) end
  if spec[1] and spec[2] and spec[3] then return spec end
  return nil
end

-- ---------- trener klasy ----------
-- -> { imie, uiMapID, x, y, opis } (format dawnej listy MAGE_TRAINERS) albo nil
local function classTrainerSpot()
  if K.class and GetTime() - K.classAt < 20 then return K.class end
  local out
  local E = PS() and PS().Engine
  if E and type(E.NearestClassTrainer) == "function" then
    local ok, t = pcall(E.NearestClassTrainer)
    if ok and type(t) == "table" then
      local m, x, y = live(t)
      if m then
        local zone = mapName(m)
        out = { t.npcName or t.npcEnglish or "trener", m, x, y, zone or ("mapa " .. m), src = "Polestar" }
      end
    end
  end
  if not out then
    local q = questieNearest(townsfolk("Class Trainer", true))
    if q then out = { q.name or "trener", q.map, q.x, q.y, mapName(q.map) or ("mapa " .. q.map), src = "Questie" } end
  end
  K.class, K.classAt = out, GetTime()
  return out
end

local ev = CreateFrame("Frame")
for _, e in ipairs({ "ZONE_CHANGED_NEW_AREA", "PLAYER_LEVEL_UP" }) do pcall(ev.RegisterEvent, ev, e) end
ev:SetScript("OnEvent", function() K.trainer, K.classAt = {}, -100 end)

-- eksport do pozostalych modulow (Prowadzenie.lua, Kroki.lua; GrimuarUI przez GrimuarAPI)
G.psCodexReady = codexReady
G.questieNearestNpc = questieNearest
G.npcSpot = npcSpot
G.trainerSpot = trainerSpot
G.resolveLoc = resolveLoc
G.classTrainerSpot = classTrainerSpot
