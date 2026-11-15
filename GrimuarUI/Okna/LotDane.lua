-- Grimuar UI: dane mapy lotow dla okna Mistrza lotow (Okna\Lot.lua) i paska lotu (Hud\Lot.lua) (15.11; gracz: „okna gry,
-- ktore jeszcze nie sa w stylu Grimuara: Mistrz lotow i Handel”). Tylko odczyt, kazde cudze API przez pcall:
-- * wezly: NumTaxiNodes, TaxiNodeName („Miejsce, Strefa”), TaxiNodeGetType, TaxiNodeCost, GetNumRoutes, pozycja
--   z C_TaxiMap.GetAllTaxiNodes(GetTaxiMapID()) (id wezla jak u Polestara), inaczej TaxiNodePosition;
-- * cel prowadzenia: znacznik Polestara na mapie lotow (QoL.Flight: node, Destination, SlotOf, FindNode), inaczej gdy
--   strzalka prowadzi (Nav.API.Active): wezel najblizej jej celu (Nav.GetTargetWorld) albo w strefie celu;
-- * czas lotu: Polestar.Maps.FlightSeconds (zapamietany albo szacunek), inaczej czas zapamietany przez Grimuara
--   (GrimuarUIDB.lotyCzas, Hud\Lot.lua po wyladowaniu). Szacunek liczony raz na wizyte (K.sec, U.lot.reset przy otwarciu).
-- U.lot = { nodes, dist, guide, seconds, reset }, U.lotInfo(slot), U.lotTime(sekundy).
local ADDON, U = ...

local K = { sec = {} }

local function str(v)
  if type(v) ~= "string" or (issecretvalue and issecretvalue(v)) then return nil end
  return v
end

-- czas lotu jako m:ss (okno lotow i pasek lotu)
function U.lotTime(sec)
  sec = math.max(0, math.floor((U.num(sec) or 0) + 0.5))
  return string.format("%d:%02d", math.floor(sec / 60), sec % 60)
end

-- ---------- dane mapy lotow ----------
-- slot -> { id, x, y } z C_TaxiMap: id wezla jak u Polestara, pozycja na mapie lotow (GetTaxiMapID)
local function mapNodes()
  local out = {}
  local map = U.num(U.call(GetTaxiMapID))
  if not (map and C_TaxiMap and C_TaxiMap.GetAllTaxiNodes) then return out, map end
  local ok, list = pcall(C_TaxiMap.GetAllTaxiNodes, map)
  if not (ok and type(list) == "table") then return out, map end
  for _, n in ipairs(list) do
    local slot = type(n) == "table" and U.num(n.slotIndex)
    if slot then
      local x, y
      if type(n.position) == "table" and n.position.GetXY then
        local okP, a, b = pcall(n.position.GetXY, n.position)
        if okP then x, y = U.num(a), U.num(b) end
      end
      out[slot] = { id = U.num(n.nodeID), x = x, y = y }
    end
  end
  return out, map
end

-- pozycja w swiecie (jak Polestar Compat.MapToWorld): kontynent, x, y w jardach
local function world(map, x, y)
  if not (map and x and y and C_Map and C_Map.GetWorldPosFromMapPos and CreateVector2D) then return nil end
  local ok, c, pos = pcall(C_Map.GetWorldPosFromMapPos, map, CreateVector2D(x, y))
  if not (ok and U.num(c) and type(pos) == "table" and pos.GetXY) then return nil end
  local okXY, wx, wy = pcall(pos.GetXY, pos)
  wx, wy = okXY and U.num(wx), okXY and U.num(wy)
  if not (wx and wy) then return nil end
  return c, wx, wy
end

local function nodes()
  local list, cur = {}, nil
  local extra, map = mapNodes()
  for i = 1, U.num(U.call(NumTaxiNodes)) or 0 do
    local name = str(U.call(TaxiNodeName, i))
    if name then
      local e = extra[i] or {}
      local x, y = e.x, e.y
      if not x then
        local okP, a, b = pcall(TaxiNodePosition, i)
        if okP then x, y = U.num(a), U.num(b) end
      end
      local n = { i = i, name = name, id = e.id, x = x, y = y, kind = str(U.call(TaxiNodeGetType, i)) or "NONE",
        cost = U.num(U.call(TaxiNodeCost, i)) or 0, legs = U.num(U.call(GetNumRoutes, i)) }
      n.place = name:match("^([^,]+),") or name
      n.zone = name:match(",%s*(.+)$")
      -- swiat tylko z pozycji C_TaxiMap (ta sama mapa, ktora podaje GetTaxiMapID)
      if e.x then n.c, n.wx, n.wy = world(map, e.x, e.y) end
      if n.kind == "CURRENT" then cur = n end
      list[#list + 1] = n
    end
  end
  return list, cur
end

-- odleglosc od wezla a do b: jardy w swiecie albo mapa kontynentu (ok. 3:2) w przyblizeniu
local function dist(a, b)
  if not (a and b) then return nil end
  if a.wx and b.wx and a.c == b.c then
    local dx, dy = a.wx - b.wx, a.wy - b.wy
    return math.sqrt(dx * dx + dy * dy)
  end
  if a.x and b.x then
    local dx, dy = (a.x - b.x) * 1.5, a.y - b.y
    return math.sqrt(dx * dx + dy * dy) * 10000
  end
  return nil
end

-- cel prowadzenia: slot i powod (albo nil)
local function guideSlot(list, cur)
  local P = _G.Polestar
  if type(P) ~= "table" then return nil end
  -- 1) znacznik Polestara na mapie lotow (lot z trasy albo cel „fly” biezacego kroku), QoL\Flight.lua
  local Fl = type(P.QoL) == "table" and P.QoL.Flight
  if type(Fl) == "table" then
    local slot = Fl.open and U.num(Fl.node)
    if slot then return slot, "trasa Polestara leci tutaj" end
    if type(Fl.Destination) == "function" then
      local ok, dest, nodeID = pcall(Fl.Destination)
      local s
      if ok and U.num(nodeID) and type(Fl.SlotOf) == "function" then
        local okS, v = pcall(Fl.SlotOf, nodeID)
        s = okS and U.num(v) or nil
      end
      if ok and not s and str(dest) and type(Fl.FindNode) == "function" then
        local okF, v = pcall(Fl.FindNode, dest)
        s = okF and U.num(v) or nil
      end
      if s then return s, "trasa Polestara leci tutaj" end
    end
  end
  -- 2) strzalka prowadzi (krok Polestara albo „Prowadz” Grimuara): wezel najblizej jej celu
  local N = type(P.Nav) == "table" and P.Nav
  local A = N and N.API
  if not (A and type(A.Active) == "function") then return nil end
  local okA, active = pcall(A.Active)
  if not (okA and active) then return nil end
  if type(N.GetTargetWorld) == "function" then
    local okW, tc, tx, ty = pcall(N.GetTargetWorld)
    tx, ty = okW and U.num(tx), okW and U.num(ty)
    if tx and ty then
      local best, bd
      for _, n in ipairs(list) do
        if n.wx and n.c == tc and n.kind == "REACHABLE" then
          local dx, dy = n.wx - tx, n.wy - ty
          local d = dx * dx + dy * dy
          if not bd or d < bd then best, bd = n, d end
        end
      end
      -- lot ma sens tylko, gdy wezel jest wyraznie blizej celu niz miejsce, w ktorym stoisz
      if best and cur and cur.wx and cur.c == tc then
        local cx, cy = cur.wx - tx, cur.wy - ty
        if bd < (cx * cx + cy * cy) * 0.36 then return best.i, "najbliżej celu strzałki" end
        return nil
      elseif best then
        return best.i, "najbliżej celu strzałki"
      end
    end
  end
  -- 3) ta sama strefa co cel strzalki
  if type(N.GetTargetZoneName) == "function" then
    local okZ, zone = pcall(N.GetTargetZoneName)
    zone = okZ and str(zone)
    if zone then
      local z = zone:lower()
      for _, n in ipairs(list) do
        if n.kind == "REACHABLE" and ((n.zone and n.zone:lower() == z) or n.place:lower() == z) then return n.i, "w strefie celu strzałki" end
      end
    end
  end
  return nil
end

-- czas lotu: sekundy i czy to szacunek (szacunek Polestara liczy trase po wezlach: raz na wizyte, K.sec)
local function secondsRaw(cur, n)
  local M = _G.Polestar and _G.Polestar.Maps
  if type(M) == "table" and type(M.FlightSeconds) == "function" then
    local from, to = cur and cur.id, n.id
    if type(M.TaxiNodeByName) == "function" then
      if cur and not from then
        local ok, v = pcall(M.TaxiNodeByName, cur.name)
        from = ok and U.num(v) or nil
      end
      if not to then
        local ok, v = pcall(M.TaxiNodeByName, n.name)
        to = ok and U.num(v) or nil
      end
    end
    if from and to then
      local ok, s, src = pcall(M.FlightSeconds, from, to)
      if ok and U.num(s) then return s, src ~= "learned" end
    end
  end
  local d = U.db().lotyCzas
  local s = cur and type(d) == "table" and U.num(d[cur.name .. ">" .. n.name])
  if s then return s, false end
  return nil
end
local function seconds(cur, n)
  local key = (cur and cur.name or "?") .. ">" .. n.name
  local v = K.sec[key]
  if not v then
    local s, est = secondsRaw(cur, n)
    v = { s, est }
    K.sec[key] = v
  end
  return v[1], v[2]
end

-- dla paska lotu (hook TakeTaxiNode): dokad, skad, czas
function U.lotInfo(slot)
  local list, cur = nodes()
  for _, n in ipairs(list) do
    if n.i == slot then
      local s, est = seconds(cur, n)
      return { to = n.name, place = n.place, zone = n.zone, from = cur and cur.name, sec = s, est = est, cost = n.cost }
    end
  end
  return nil
end

U.lot = { nodes = nodes, dist = dist, guide = guideSlot, seconds = seconds, reset = function() K.sec = {} end }
