-- Grimuar UI: Ksiega krain (14.11, R24 P7, wzor: Adventurer's Tome z Lost Ark). Na strefe: zadania Przymierza dla maga
-- z bazy Questie (zoneOrSort, rasy, klasy) i ile z nich masz zrobione (Questie.db.char.complete / gra), poziomy zadan,
-- rzadkie i elitarne stwory z Bestiariusza. Liczone raz na otwarcie strony (pare tysiecy zadan), wynik w pamieci 10 min.
local ADDON, U = ...

local ALLIANCE = 1 + 4 + 8 + 64 -- Human, Dwarf, Night Elf, Gnome (maska ras klasyczna)
-- 14.11 (R27 E2): maska Twojej klasy (2^(classID-1)), dawniej tylko mag
local function classMask() local _, _, id = UnitClass("player") return 2 ^ ((tonumber(id) or 8) - 1) end
local K = {}

local function mod(name)
  local L = QuestieLoader
  if not (L and L.ImportModule) then return nil end
  local ok, m = pcall(L.ImportModule, L, name)
  return ok and type(m) == "table" and m or nil
end
local function band(a, b) return (bit and bit.band and bit.band(a, b)) or (a % (b * 2) >= b and b or 0) end

local function done(qid)
  local Q = _G.Questie
  local c = Q and Q.db and Q.db.char and Q.db.char.complete
  if type(c) == "table" and c[qid] then return true end
  return U.call(C_QuestLog.IsQuestFlaggedCompleted, qid) and true or false
end

local function zoneName(area, Z)
  local ui = Z and Z.GetUiMapIdByAreaId and U.call(Z.GetUiMapIdByAreaId, Z, area)
  local info = ui and U.call(C_Map.GetMapInfo, ui)
  if info and info.name then return info.name, ui end
  local a = C_Map.GetAreaInfo and U.call(C_Map.GetAreaInfo, area)
  return a or ("strefa " .. area), ui
end

-- { { name, ui, total, done, lmin, lmax, rares = n } } od najnizszych poziomow
function U.realmsBook()
  if K.list and GetTime() - K.at < 600 then return K.list end
  local DB, Z = mod("QuestieDB"), mod("ZoneDB")
  local ptr = DB and DB.QuestPointers
  if type(ptr) ~= "table" or not DB.QueryQuestSingle then return nil end
  local by = {}
  for qid in pairs(ptr) do
    if type(qid) == "number" then
      local zone = U.call(DB.QueryQuestSingle, qid, "zoneOrSort")
      if type(zone) == "number" and zone > 0 then
        local rr = U.call(DB.QueryQuestSingle, qid, "requiredRaces") or 0
        local rc = U.call(DB.QueryQuestSingle, qid, "requiredClasses") or 0
        if (rr == 0 or band(rr, UnitFactionGroup("player") == "Horde" and (2 + 16 + 32 + 128) or ALLIANCE) ~= 0) and (rc == 0 or band(rc, classMask()) ~= 0) then
          local z = by[zone]
          if not z then z = { area = zone, total = 0, done = 0 } by[zone] = z end
          z.total = z.total + 1
          if done(qid) then z.done = z.done + 1 end
          local lv = U.num(U.call(DB.QueryQuestSingle, qid, "questLevel"))
          if lv and lv > 0 then
            z.lmin = math.min(z.lmin or lv, lv)
            z.lmax = math.max(z.lmax or lv, lv)
          end
        end
      end
    end
  end
  -- rzadkie i elitarne z Bestiariusza, po nazwie strefy
  local rares = {}
  for _, e in ipairs(U.bestiaryList and U.bestiaryList() or {}) do
    if e.cls and e.cls ~= "elite" then
      for z in pairs(e.zones or {}) do rares[z] = (rares[z] or 0) + 1 end
    end
  end
  local list = {}
  for area, z in pairs(by) do
    if z.total >= 5 then
      z.name, z.ui = zoneName(area, Z)
      z.rares = rares[z.name] or 0
      list[#list + 1] = z
    end
  end
  table.sort(list, function(a, b)
    if (a.lmin or 99) ~= (b.lmin or 99) then return (a.lmin or 99) < (b.lmin or 99) end
    return a.name < b.name
  end)
  K.list, K.at = list, GetTime()
  return list
end
function U.realmsReset() K.list = nil end
