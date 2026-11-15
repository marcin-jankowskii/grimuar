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

-- 15.11 (R30 P25, gracz: „strefy i groznosc”): poziom strefy z Polestara (Maps.GetZoneLevels), kolor trudnosci jak
-- w Polestarze (Maps.LevelColor) i mnoznik groznosci jego trasy (Nav.danger.Mult: 3 = grozna, 20 = za wysoka).
-- Bez Polestara: poziomy zadan z Questie (fallback). Strefa sporna tylko dla strefy, w ktorej jestes (C_PvP).
local ZCOL = { danger = { 0.95, 0.38, 0.32 }, warning = { 0.95, 0.62, 0.28 }, quest = { 0.85, 0.71, 0.36 },
  success = { 0.48, 0.80, 0.45 }, textMuted = { 0.55, 0.52, 0.48 }, textDim = { 0.55, 0.52, 0.48 } }
local function levelColor(lo, hi, lvl)
  if not (lo and hi and lvl) then return "textDim" end
  if lvl < lo - 2 then return "danger" end
  if lvl < lo then return "warning" end
  if lvl <= hi then return "quest" end
  if lvl <= hi + 5 then return "success" end
  return "textMuted"
end
function U.zoneInfo(ui, fbMin, fbMax)
  local P = _G.Polestar
  local lvl = UnitLevel("player") or 1
  local lo, hi, src
  if ui and P and P.Maps and P.Maps.GetZoneLevels then
    local ok, a, b = pcall(P.Maps.GetZoneLevels, ui)
    if ok and type(a) == "number" then lo, hi, src = a, b, "polestar" end
  end
  if not lo and fbMin then lo, hi, src = fbMin, fbMax or fbMin, "questy" end
  local key = "textDim"
  if lo and hi then
    local ok, k = false, nil
    if P and P.Maps and P.Maps.LevelColor then ok, k = pcall(P.Maps.LevelColor, lo, hi, lvl) end
    key = (ok and ZCOL[k] and k) or levelColor(lo, hi, lvl)
  end
  local mult = 1
  local D = P and P.Nav and P.Nav.danger
  if ui and D and D.Mult then
    local ok, m = pcall(D.Mult, lvl, ui)
    if ok and type(m) == "number" then mult = m end
  elseif lo and lo >= lvl + 3 then
    mult = 3
  end
  local word = mult >= 20 and "za wysoka" or (mult >= 3 and "groźna" or nil)
  if not word and key == "success" then word = "łatwa" elseif not word and key == "textMuted" then word = "za niska" end
  local pvp
  if ui and ui == U.call(C_Map.GetBestMapForUnit, "player") then
    local pt = (C_PvP and C_PvP.GetZonePVPInfo and U.call(C_PvP.GetZonePVPInfo)) or U.call(GetZonePVPInfo)
    pvp = (pt == "contested" and "sporna") or (pt == "hostile" and "wroga") or (pt == "sanctuary" and "bezpieczna") or nil
  end
  -- slowa po angielsku przy jezyku huba en (G.tr bez zmian przy polskim)
  local tr = U.G and U.G.tr
  if tr then word = word and tr(word) pvp = pvp and tr(pvp) end
  return { min = lo, max = hi, src = src, key = key, col = ZCOL[key], mult = mult, word = word, pvp = pvp,
    text = lo and ((lo == hi and tostring(lo) or (lo .. "–" .. hi)) .. (word and (" · " .. word) or "") .. (pvp and (" · " .. pvp) or "")) or nil }
end
U.testChecksExtra = U.testChecksExtra or {}
table.insert(U.testChecksExtra, { "Strefy: poziom i groźność (P25, Maps.GetZoneLevels, Nav.danger.Mult)", function()
  local ui = U.call(C_Map.GetBestMapForUnit, "player")
  local z = U.zoneInfo(ui)
  if not z.min then
    if _G.Polestar and _G.Polestar.Maps and _G.Polestar.Maps.GetZoneLevels then return "brak poziomów dla tej strefy (miasto?)" end
    error("Polestar.Maps.GetZoneLevels niedostępne")
  end
  return (z.text or "?") .. " (" .. z.src .. ", ×" .. z.mult .. ")"
end })
