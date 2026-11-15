-- Grimuar UI: „Gdzie kupic” - dane (15.11, gracz: „Powinnismy dodac cos do naszej mapy, zeby latwo mozna bylo szukac,
-- co gdzie kupic”; sprzedal Mining Pick i nie mogl znalezc nowego). Kupcy przedmiotu z dwoch zrodel naraz:
-- * Polestar: Lookup.Sources("item", id, true) (Lookup\Sources.lua, builders.vendor: wiersz { type = "vendor",
--   src = { npc, cost, limited }, label, map, x, y, f, available, why }), rola NPC z Codex.Npc(npc).subName, wszystkie
--   miejsca z Codex.Npc(npc).spawns (ramka Era przez U.psLive). Codex trzyma najwyzej 10 zrodel na przedmiot (sprawdzone
--   15.11: Mining Pick ma tam 10 kupcow, bez Thelsamar Drac Roughcut, Kharanos i Ironforge), wiec
-- * Questie dopelnia: QuestieDB.QueryItemSingle(id, "vendors") -> NPC, QueryNPCSingle(npc, "name"|"subName"|"spawns"|
--   "friendlyToFaction"), strefa przez ZoneDB:GetUiMapIdByAreaId. Ten sam NPC tylko raz; kupcy wrogiej frakcji pomijani.
-- Odleglosc: zawsze ID mapy + wspolrzedne, swiat przez C_Map.GetWorldPosFromMapPos (jardy w linii prostej); ten sam
-- kontynent najpierw, inne na koncu. Zadnych wspolrzednych bez mapy (dawny /way 46.7 53.5 bez strefy wskazal jezioro).
-- Wyszukiwanie przedmiotow: Polestar.Search (item, recipe), bez Polestara indeks nazw przedmiotow z Questie.
local ADDON, U = ...

local K = { vend = {}, items = nil, building = false, waiters = {} }

local function PS() return _G.Polestar end
local function mod(name)
  local L = QuestieLoader
  if not (L and L.ImportModule) then return nil end
  local ok, m = pcall(L.ImportModule, L, name)
  return ok and type(m) == "table" and m or nil
end
local function codexReady()
  local X = PS() and PS().Codex
  return X and type(X.IsLoaded) == "function" and U.call(X.IsLoaded) and X or nil
end
U.buyCodex = codexReady

-- ---------- swiat: jardy ----------
-- mapa (uiMapID), x, y (0-100) -> kontynent, x, y w jardach swiata
local function world(map, x, y)
  if not (map and x and y and C_Map and C_Map.GetWorldPosFromMapPos and CreateVector2D) then return nil end
  local ok, c, pos = pcall(C_Map.GetWorldPosFromMapPos, map, CreateVector2D(x / 100, y / 100))
  if not (ok and c and pos and pos.GetXY) then return nil end
  local wx, wy = pos:GetXY()
  wx, wy = U.num(wx), U.num(wy)
  if not (wx and wy) then return nil end
  return c, wx, wy
end
U.buyWorld = world
local function playerWorld()
  local m = U.call(C_Map.GetBestMapForUnit, "player")
  local p = m and U.call(C_Map.GetPlayerMapPosition, m, "player")
  if not (p and p.GetXY) then return nil end
  local x, y = p:GetXY()
  x, y = U.num(x), U.num(y)
  if not (x and y) or (x == 0 and y == 0) then return nil end
  return world(m, x * 100, y * 100)
end
local function zoneName(map)
  local info = map and U.call(C_Map.GetMapInfo, map)
  return info and info.name or nil
end

-- ---------- kupcy z Polestara ----------
local function psVendors(id, out, seen)
  local P, X = PS(), codexReady()
  local Lk = P and P.Lookup
  if not (X and Lk and type(Lk.Sources) == "function") then return false end
  local ok, list = pcall(Lk.Sources, "item", id, true)
  if not (ok and type(list) == "table") then return false end
  for _, r in ipairs(list) do
    local src = type(r) == "table" and r.type == "vendor" and type(r.src) == "table" and r.src or nil
    local npc = src and tonumber(src.npc)
    local fresh = npc and not seen[npc]
    if npc then seen[npc] = true end
    if fresh and r.why ~= "faction" then
      local okN, rec = pcall(X.Npc, npc)
      rec = okN and type(rec) == "table" and rec or nil
      local spawns = {}
      local function add(s)
        local m, x, y = s.map, s.x, s.y
        if U.psLive then m, x, y = U.psLive(s) end
        x, y = U.num(x), U.num(y)
        if m and x and y then spawns[#spawns + 1] = { map = m, x = x, y = y } end
      end
      for _, s in ipairs(rec and type(rec.spawns) == "table" and rec.spawns or {}) do if type(s) == "table" then add(s) end end
      if #spawns == 0 then add(r) end
      out[#out + 1] ={ npc = npc, name = r.label or (rec and rec.name) or ("NPC " .. npc), role = rec and rec.subName,
        spawns = spawns, price = U.num(r.price), limited = src.limited and true or nil,
        why = (r.available == false) and r.why or nil, src = "Polestar" }
    end
  end
  return true
end

-- ---------- kupcy z Questie ----------
local function qVendors(id, out, seen)
  local DB, Z = mod("QuestieDB"), mod("ZoneDB")
  if not (DB and type(DB.QueryItemSingle) == "function" and type(DB.QueryNPCSingle) == "function" and Z) then return false end
  local ok, vs = pcall(DB.QueryItemSingle, id, "vendors")
  if not ok then return false end
  local faction = (UnitFactionGroup("player") == "Horde") and "H" or "A"
  for _, npc in pairs(type(vs) == "table" and vs or {}) do
    npc = tonumber(npc)
    local known = npc and seen[npc]
    if npc and not known then
      seen[npc] = true
      local fr = U.call(DB.QueryNPCSingle, npc, "friendlyToFaction")
      if not (type(fr) == "string" and fr ~= "" and not fr:find(faction, 1, true)) then
        local spawns = {}
        local sp = U.call(DB.QueryNPCSingle, npc, "spawns")
        for area, list in pairs(type(sp) == "table" and sp or {}) do
          local okZ, ui = pcall(Z.GetUiMapIdByAreaId, Z, area)
          for _, c in ipairs(type(list) == "table" and list or {}) do
            local x = type(c) == "table" and tonumber(c[1]) or nil
            local y = type(c) == "table" and tonumber(c[2]) or nil
            if okZ and ui and x and y and x >= 0 and y >= 0 and x <= 100 and y <= 100 then spawns[#spawns + 1] = { map = ui, x = x, y = y } end
          end
        end
        if #spawns > 0 then
          out[#out + 1] = { npc = npc, name = U.call(DB.QueryNPCSingle, npc, "name") or ("NPC " .. npc),
            role = U.call(DB.QueryNPCSingle, npc, "subName"), spawns = spawns, src = "Questie" }
        end
      end
    elseif known then
      -- ten sam NPC z Polestara: Questie dopisuje tylko role, gdy Codex jej nie ma
      for _, v in ipairs(out) do
        if v.npc == npc and not v.role then v.role = U.call(DB.QueryNPCSingle, npc, "subName") end
      end
    end
  end
  return true
end

-- kupcy przedmiotu, od najblizszego: { npc, name, role, map, x, y, zone, yards (ten kontynent), spawns, price, limited, src }
-- i stan { ps = Polestar podal, qs = Questie podal }
function U.buyVendors(id)
  id = tonumber(id)
  if not id then return {}, {} end
  local raw = K.vend[id]
  if not raw or (not raw.ps and codexReady()) then
    raw = { list = {} }
    local seen = {}
    raw.ps = psVendors(id, raw.list, seen)
    raw.qs = qVendors(id, raw.list, seen)
    K.vend[id] = raw
  end
  local pc, px, py = playerWorld()
  raw.here = pc ~= nil -- false: gracz w instancji albo w ladowaniu (odleglosci nieznane)
  for _, v in ipairs(raw.list) do
    local best, bd = nil, nil
    for _, s in ipairs(v.spawns) do
      local c, wx, wy = world(s.map, s.x, s.y)
      if c and pc and c == pc then
        local d = ((wx - px) ^ 2 + (wy - py) ^ 2) ^ 0.5
        if not bd or d < bd then best, bd = s, d end
      end
    end
    best = best or v.spawns[1]
    v.map, v.x, v.y, v.yards = best and best.map, best and best.x, best and best.y, bd
    v.zone = zoneName(v.map)
  end
  table.sort(raw.list, function(a, b)
    if (a.yards ~= nil) ~= (b.yards ~= nil) then return a.yards ~= nil end
    if a.yards and b.yards and a.yards ~= b.yards then return a.yards < b.yards end
    if (a.zone or "") ~= (b.zone or "") then return (a.zone or "") < (b.zone or "") end
    return tostring(a.name) < tostring(b.name)
  end)
  return raw.list, raw
end

-- ile kupcow (bez liczenia odleglosci): Codex (do 10) + Questie, ten sam NPC raz
function U.buyCount(id)
  local set, n = {}, 0
  local X = codexReady()
  if X then
    local ok, rec = pcall(X.Item, id)
    for _, s in ipairs(ok and type(rec) == "table" and type(rec.sources) == "table" and rec.sources or {}) do
      local npc = s.type == "vendor" and tonumber(s.npc)
      if npc and not set[npc] then set[npc], n = true, n + 1 end
    end
  end
  local DB = mod("QuestieDB")
  if DB and type(DB.QueryItemSingle) == "function" then
    local ok, vs = pcall(DB.QueryItemSingle, id, "vendors")
    for _, npc in pairs(ok and type(vs) == "table" and vs or {}) do
      npc = tonumber(npc)
      if npc and not set[npc] then set[npc], n = true, n + 1 end
    end
  end
  return n
end

-- ---------- wyszukiwanie przedmiotow ----------
-- Polestar.Search: { { id, name, quality } } albo nil (brak Codexu)
function U.buyItemsPolestar(q)
  local P = PS()
  local Sr = P and P.Search
  if not (codexReady() and Sr and type(Sr.Query) == "function") then return nil end
  local ok, res = pcall(Sr.Query, q, { kinds = { item = true, recipe = true }, limit = 30, perKind = 30, subtitles = false })
  if not (ok and type(res) == "table") then return nil end
  local out = {}
  for _, r in ipairs(res) do
    if type(r) == "table" and tonumber(r.id) then out[#out + 1] = { id = tonumber(r.id), name = tostring(r.title or r.id), quality = U.num(r.quality) } end
  end
  return out
end

-- zapas bez Polestara: indeks nazw przedmiotow Questie (raz, po kawalku), potem fn(lista) albo fn(nil, "brak")
function U.buyItemsQuestie(q, fn)
  q = (q or ""):lower()
  local function find()
    if not K.items then return fn(nil, "noquestie") end
    local out = {}
    for _, e in ipairs(K.items) do
      if e.l:find(q, 1, true) then
        out[#out + 1] = { id = e.id, name = e.n, quality = U.num(U.call(C_Item and C_Item.GetItemQualityByID, e.id)) }
        if #out >= 40 then break end
      end
    end
    fn(out)
  end
  if K.items or K.fail then return find() end
  K.waiters[#K.waiters + 1] = find
  if K.building then return end
  local DB = mod("QuestieDB")
  local ptrs = DB and DB.ItemPointers
  local function flush()
    local w = K.waiters
    K.waiters = {}
    for _, f in ipairs(w) do pcall(f) end
  end
  if not (DB and type(DB.QueryItemSingle) == "function" and type(ptrs) == "table") then
    K.fail = true
    return flush()
  end
  K.building = true
  local ids = {}
  for k, v in pairs(ptrs) do
    local id = (type(k) == "number" and k) or (type(v) == "number" and v) or nil
    if id then ids[#ids + 1] = id end
  end
  local names, i, ticker = {}, 0, nil
  ticker = C_Timer.NewTicker(0.02, function()
    for _ = 1, 1200 do
      i = i + 1
      local id = ids[i]
      if not id then
        ticker:Cancel()
        K.items, K.building = names, false
        return flush()
      end
      local ok, nm = pcall(DB.QueryItemSingle, id, "name")
      if ok and type(nm) == "string" and nm ~= "" then names[#names + 1] = { id = id, n = nm, l = nm:lower() } end
    end
  end)
end

-- ---------- /gr test ----------
U.testChecksExtra = U.testChecksExtra or {}
table.insert(U.testChecksExtra, { "Gdzie kupić (Lookup.Sources vendor, Questie vendors)", function()
  if not (C_Map and C_Map.GetWorldPosFromMapPos and CreateVector2D) then error("brak C_Map.GetWorldPosFromMapPos: bez odległości do kupców") end
  local P = PS()
  local ps = type(P) == "table" and P.Lookup and type(P.Lookup.Sources) == "function"
  local DB = mod("QuestieDB")
  local qs = DB and type(DB.QueryItemSingle) == "function"
  if not (ps or qs) then return "brak Polestara i Questie: „Gdzie kupić” nie ma danych" end
  local list, raw = U.buyVendors(2901) -- Mining Pick
  local v = list[1]
  return "Mining Pick: " .. #list .. " kupców (Polestar: " .. (raw.ps and "tak" or (codexReady() and "nie" or "baza niewczytana")) ..
    ", Questie: " .. (raw.qs and "tak" or "nie") .. ")" .. (v and (", najbliżej: " .. tostring(v.name) .. " (" .. tostring(v.zone) ..
    (v.yards and (", " .. math.floor(v.yards + 0.5) .. " yd") or ", inny kontynent") .. ")") or "")
end })
