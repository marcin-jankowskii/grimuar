-- Grimuar UI: wazne postacie na mapie huba (14.11, zrzut Ironforge: „na mapie nie ma nazw, ikon npcow waznych itp.,
-- mozna by to bardziej pelne zrobic”). Listy z Questie (modul Townsfolk, to samo co jego menu „Townsfolk” na mapie gry):
-- mistrz lotow, karczmarz, bank, dom aukcyjny, naprawa, poczta, trener klasy i portali, trenerzy Twoich profesji
-- i odczynniki. Indeks strefa -> postacie budowany raz, po kawalku; potem kazda mapa jest od razu.
-- Tylko odczyt z Questie. Ikony: sledzenie minimapy gry (Interface\Minimap\tracking), jak w Questie.
local ADDON, U = ...

local T = "Interface\\Minimap\\tracking\\"
-- { klucz Questie, nazwa po polsku, ikona, zrodlo: town | char | vendor | prof, obiekt? }
local KINDS = {
  { "Flight Master", "Mistrz lotów", T .. "flightmaster", "town" },
  { "Innkeeper", "Karczmarz (kamień powrotu)", T .. "innkeeper", "town" },
  { "Banker", "Bank", T .. "banker", "town" },
  { "Auctioneer", "Dom aukcyjny", T .. "auctioneer", "town" },
  { "Repair", "Naprawa i kupiec", T .. "repair", "town" },
  { "Class Trainer", "Trener klasy", T .. "class", "char" },
  { "Portal Trainer", "Trener portali", T .. "class", "char" },
  { "Mailbox", "Poczta", T .. "mailbox", "char", true },
  { "Reagents", "Odczynniki (proszek, runy)", T .. "reagents", "vendor" },
  { "Bags", "Torby", 133634, "vendor" }, -- 14.11 (gracz: brak miejsca w torbach): gdzie kupic torbe
}
-- trenerzy profesji: { nazwa umiejetnosci w grze, klucz Questie (ID linii), ikona }
local PROFS = {
  { "First Aid", 129, "Interface\\Icons\\spell_holy_sealofsacrifice" }, { "Herbalism", 182, "Interface\\Icons\\trade_herbalism" },
  { "Mining", 186, "Interface\\Icons\\trade_mining" }, { "Cooking", 185, "Interface\\Icons\\inv_misc_food_15" },
  { "Fishing", 356, "Interface\\Icons\\trade_fishing" }, { "Tailoring", 197, "Interface\\Icons\\trade_tailoring" },
  { "Alchemy", 171, "Interface\\Icons\\trade_alchemy" }, { "Skinning", 393, "Interface\\Icons\\inv_misc_pelt_wolf_01" },
  { "Enchanting", 333, "Interface\\Icons\\trade_engraving" }, { "Engineering", 202, "Interface\\Icons\\trade_engineering" },
  { "Blacksmithing", 164, "Interface\\Icons\\trade_blacksmithing" }, { "Leatherworking", 165, "Interface\\Icons\\trade_leatherworking" },
}
local PL = { ["First Aid"] = "Pierwsza pomoc", Herbalism = "Zielarstwo", Mining = "Górnictwo", Cooking = "Gotowanie",
  Fishing = "Wędkarstwo", Tailoring = "Krawiectwo", Alchemy = "Alchemia", Skinning = "Skórowanie", Enchanting = "Zaklinanie",
  Engineering = "Inżynieria", Blacksmithing = "Kowalstwo", Leatherworking = "Kaletnictwo" }

local IDX = { waiters = {} }
local function mod(name)
  local L = QuestieLoader
  if not (L and L.ImportModule) then return nil end
  local ok, m = pcall(L.ImportModule, L, name)
  return ok and type(m) == "table" and m or nil
end
local function flush()
  local w = IDX.waiters
  IDX.waiters = {}
  for _, fn in ipairs(w) do pcall(fn) end
end

-- zadania do zrobienia: { id, obiekt?, rodzaj } (rodzaj = { pl, ikona })
local function jobs()
  local TF = mod("Townsfolk")
  local char = Questie and Questie.db and Questie.db.char or {}
  local list = {}
  local function addIds(ids, kind, object)
    for k, v in pairs(type(ids) == "table" and ids or {}) do
      local id = (type(v) == "number" and v) or (type(k) == "number" and v == true and k) or nil
      if id then list[#list + 1] = { id = id, object = object, kind = kind } end
    end
  end
  for _, k in ipairs(KINDS) do
    local ids
    if k[4] == "town" then ids = TF and TF.townsfolk and TF.townsfolk[k[1]]
    elseif k[4] == "char" then ids = (type(char.townsfolk) == "table" and char.townsfolk[k[1]]) or (TF and TF.townsfolk and TF.townsfolk[k[1]])
    elseif k[4] == "vendor" then ids = type(char.vendorList) == "table" and char.vendorList[k[1]] end
    addIds(ids, { pl = k[2], icon = k[3], key = k[1] }, k[5])
  end
  local known = U.call(U.G and U.G.readProfs) or {}
  for _, p in ipairs(PROFS) do
    local wantIt = known[p[1]] or p[1] == "Mining" or p[1] == "Fishing" or p[1] == "Tailoring"
    if wantIt and TF and type(TF.professionTrainers) == "table" then
      addIds(TF.professionTrainers[p[2]], { pl = "Trener: " .. (PL[p[1]] or p[1]), icon = p[3], key = "prof" .. p[2] })
    end
  end
  return list
end

local function build(done)
  if IDX.byArea then return done() end
  IDX.waiters[#IDX.waiters + 1] = done
  if IDX.building then return end
  local DB = mod("QuestieDB")
  if not (DB and DB.QueryNPCSingle) then IDX.byArea, IDX.fail = {}, true return flush() end
  IDX.building = true
  local todo, i, byArea, seen = jobs(), 0, {}, {}
  if #todo == 0 then IDX.building = false IDX.fail = true IDX.byArea = {} return flush() end
  local ticker
  ticker = C_Timer.NewTicker(0.02, function()
    for _ = 1, 500 do
      i = i + 1
      local j = todo[i]
      if not j then
        ticker:Cancel()
        IDX.byArea, IDX.building = byArea, false
        return flush()
      end
      local key = (j.object and "o" or "n") .. j.id .. j.kind.key
      if not seen[key] then
        seen[key] = true
        local q = j.object and DB.QueryObjectSingle or DB.QueryNPCSingle
        local ok, spawns = pcall(q, j.id, "spawns")
        if ok and type(spawns) == "table" then
          local _, name = pcall(q, j.id, "name")
          local sub
          if not j.object then local ok2, s = pcall(q, j.id, "subName") sub = ok2 and s or nil end
          local fr
          if not j.object then local ok3, f = pcall(q, j.id, "friendlyToFaction") fr = ok3 and f or nil end
          for area, list in pairs(spawns) do
            for _, c in ipairs(type(list) == "table" and list or {}) do
              local x, y = type(c) == "table" and tonumber(c[1]), type(c) == "table" and tonumber(c[2])
              if x and y and x >= 0 and y >= 0 and x <= 100 and y <= 100 then
                byArea[area] = byArea[area] or {}
                table.insert(byArea[area], { x = x / 100, y = y / 100, name = name, sub = sub, kind = j.kind, enemy = fr, object = j.object })
              end
            end
          end
        end
      end
    end
  end)
end

-- fn(pins) dla mapy: { x, y, name, sub, kind = { pl, icon }, enemy } (od razu albo po zbudowaniu indeksu)
function U.servicePins(uiMapID, fn)
  local Z = mod("ZoneDB")
  local ok, area = false, nil
  if Z and Z.GetAreaIdByUiMapId then ok, area = pcall(Z.GetAreaIdByUiMapId, Z, uiMapID) end
  if not (ok and area) then return fn({}) end
  build(function()
    local faction = (UnitFactionGroup("player") == "Horde") and "H" or "A"
    local out = {}
    for _, p in ipairs(IDX.byArea and IDX.byArea[area] or {}) do
      local enemy = type(p.enemy) == "string" and p.enemy ~= "" and not p.enemy:find(faction, 1, true)
      if not enemy then out[#out + 1] = p end
    end
    fn(out)
  end)
end
function U.servicesReady() return IDX.byArea ~= nil end

-- 14.11 (gracz: „npc chcialbym miec jaka taka liste wyszukiwarke: na poczatku widze npcy wg miast, a pozniej jak
-- wpisze, to mi filtruje”): katalog do wyszukiwarki na mapie huba. Grupy: Twoja strefa i stolice Przymierza,
-- w kazdej wazne postacie (bez poczty), ta sama postac z kilkoma rolami raz, role po przecinku.
local CITIES = { 1455, 1453, 1457 } -- Ironforge, Stormwind City, Darnassus
local KORDER = { ["Flight Master"] = 1, Innkeeper = 2, ["Class Trainer"] = 3, ["Portal Trainer"] = 4, Banker = 6,
  Auctioneer = 7, Bags = 8, Reagents = 9, Repair = 10 }
function U.serviceDirectory(fn)
  local Z = mod("ZoneDB")
  if not (Z and Z.GetAreaIdByUiMapId) then return fn({}) end
  build(function()
    local faction = (UnitFactionGroup("player") == "Horde") and "H" or "A"
    local here = U.call(C_Map.GetBestMapForUnit, "player")
    local maps = {}
    if here then maps[#maps + 1] = here end
    for _, c in ipairs(CITIES) do if c ~= here then maps[#maps + 1] = c end end
    local groups = {}
    for _, ui in ipairs(maps) do
      local ok, area = pcall(Z.GetAreaIdByUiMapId, Z, ui)
      local byKey, entries = {}, {}
      for _, p in ipairs(ok and area and IDX.byArea and IDX.byArea[area] or {}) do
        local enemy = type(p.enemy) == "string" and p.enemy ~= "" and not p.enemy:find(faction, 1, true)
        if not enemy and not p.object and p.name then
          local key = p.name .. string.format("%.3f%.3f", p.x, p.y)
          local e = byKey[key]
          if not e then
            e = { name = p.name, sub = p.sub, x = p.x, y = p.y, map = ui, roles = {}, keys = {}, icon = p.kind.icon,
              ord = KORDER[p.kind.key] or ((p.kind.key or ""):find("^prof") and 5 or 11) }
            byKey[key] = e
            entries[#entries + 1] = e
          end
          e.roles[#e.roles + 1] = p.kind.pl
          e.keys[p.kind.key or "?"] = true
          local o = KORDER[p.kind.key] or ((p.kind.key or ""):find("^prof") and 5 or 11)
          if o < e.ord then e.ord, e.icon = o, p.kind.icon end
        end
      end
      table.sort(entries, function(a, b)
        if a.ord ~= b.ord then return a.ord < b.ord end
        return a.name < b.name
      end)
      for _, e in ipairs(entries) do e.role = table.concat(e.roles, ", ") end
      local info = U.call(C_Map.GetMapInfo, ui)
      if #entries > 0 then groups[#groups + 1] = { title = info and info.name or "?", map = ui, entries = entries, here = ui == here } end
    end
    fn(groups)
  end)
end

-- ---------- 15.11 (R30 P21, decyzja Q6): najblizsze uslugi z czasem dojscia z Polestara ----------
-- Polestar.Nav.nearby.Find(rodzaj) (Nav\\Nearby.lua:433 -> place { id, name, sub, map, x, y, f }, sekundy dojscia z planera)
-- i na klik Nav.nearby.Go(rodzaj) (Nearby.lua:462: strzalka i „wycieczka” Polestara, ktora konczy sie sama po dojsciu).
-- Find wczytuje Codex Polestara (tylko poza walka) i pyta planer o czas kilku kandydatow, wiec liczymy dopiero po otwarciu
-- trybu Miasto na mapie huba, Kola maga albo przy braku picia w Pasie, po jednym rodzaju na raz (co 0,1 s), w pamieci
-- 60 s. Bez Polestara albo gdy nie zna: Questie (wiersze z mapy jak dotad, w Kole i Pasie G.guideInn / G.guideVendor).
local G = U.G or {}
local function tr(s) return (G.tr and type(s) == "string") and G.tr(s) or s end -- tlumaczenie kawalkow (jezyk huba)
local NEAR = { cache = {}, queue = {}, cbs = {}, busy = false }
local NEAR_TTL = 60
U.NEARBY_KINDS = {
  { key = "repair", pl = "Naprawa", icon = T .. "repair", questie = "Repair" },
  { key = "innkeeper", pl = "Karczma", icon = T .. "innkeeper", questie = "Innkeeper" },
  { key = "class", pl = "Trener klasy", icon = T .. "class", questie = "Class Trainer" },
  { key = "flight", pl = "Mistrz lotów", icon = T .. "flightmaster", questie = "Flight Master" },
  { key = "mailbox", pl = "Poczta", icon = T .. "mailbox", questie = "Mailbox" },
  { key = "bank", pl = "Bank", icon = T .. "banker", questie = "Banker" },
  { key = "auction", pl = "Dom aukcyjny", icon = T .. "auctioneer", questie = "Auctioneer" },
  { key = "reagents", pl = "Odczynniki", icon = T .. "reagents", questie = "Reagents" },
  { key = "food", pl = "Jedzenie i picie", icon = "Interface\\Icons\\INV_Drink_07" },
}
local NEAR_BY = {}
for _, k in ipairs(U.NEARBY_KINDS) do NEAR_BY[k.key] = k end
local function nearbyApi()
  local N = _G.Polestar and _G.Polestar.Nav and _G.Polestar.Nav.nearby
  return (N and type(N.Find) == "function") and N or nil
end
local function zoneOf(map)
  local i = map and U.call(C_Map.GetMapInfo, map)
  return type(i) == "table" and i.name or nil
end
function U.psNearbyKind(key) return NEAR_BY[key] end
function U.psNearbyHas() return nearbyApi() ~= nil end

local function nearCompute(key)
  local N = nearbyApi()
  if not N then return nil, "nopolestar" end
  local ok, place, s = pcall(N.Find, key)
  if not ok then return nil, "error" end
  if type(place) ~= "table" then return nil, s end
  local m, x, y = place.map, place.x, place.y
  if U.psLive then m, x, y = U.psLive(place) end
  return { name = place.name or "?", sub = place.sub, map = m, x = U.num(x), y = U.num(y), s = U.num(s), zone = zoneOf(place.map) }
end

-- z pamieci (bez liczenia): { name, sub, map, x, y, s, zone } albo nil
function U.psNearby(key)
  local c = NEAR.cache[key]
  if c and GetTime() - c.at < NEAR_TTL then return c.d end
  return nil
end
-- „Naprawa: Bixi · ~1 min” albo nil
function U.psNearbyLabel(key, short)
  local e, k = U.psNearby(key), NEAR_BY[key]
  if not (e and k) then return nil end
  local eta = e.s and G.etaShort and U.call(G.etaShort, e.s)
  return (short and tr(k.pl) or (tr(k.pl) .. ": " .. e.name)) .. (eta and (" · " .. eta) or "")
end

-- liczy brakujace i stare rodzaje po kolei; cb() po kazdym policzonym
function U.psNearbyQueue(keys, cb)
  -- w walce Codex Polestara sie nie wczyta (Find: „combat”): nic nie liczymy, inaczej odswiezanie krecilo by sie w kolko
  if not nearbyApi() or InCombatLockdown() then return end
  if cb then NEAR.cbs[cb] = true end
  for _, k in ipairs(keys) do
    local key = type(k) == "table" and k.key or k
    local c = NEAR.cache[key]
    if not (c and GetTime() - c.at < NEAR_TTL) and not NEAR.queue[key] then
      NEAR.queue[key] = true
      NEAR.queue[#NEAR.queue + 1] = key
    end
  end
  if NEAR.busy or #NEAR.queue == 0 then return end
  NEAR.busy = true
  local function step()
    local key = table.remove(NEAR.queue, 1)
    if not key then
      NEAR.busy = false
      NEAR.cbs = {}
      return
    end
    NEAR.queue[key] = nil
    local d, why = nearCompute(key)
    -- „combat”: Codex Polestara w walce sie nie wczyta, sprobujemy przy nastepnym otwarciu
    if why ~= "combat" then NEAR.cache[key] = { at = GetTime(), d = d, why = why } end
    for fn in pairs(NEAR.cbs) do pcall(fn, key) end
    C_Timer.After(0.1, step)
  end
  C_Timer.After(0, step)
end

-- klik: Polestar prowadzi (strzalka i wycieczka); false, gdy Polestara nie ma albo nie zna
function U.psNearbyGo(key)
  local N = nearbyApi()
  if not (N and type(N.Go) == "function") then return false end
  local ok, res = pcall(N.Go, key)
  if ok and res then
    if U.IsOpen and U.IsOpen() then U.Close() end
    return true
  end
  return false
end

local nearEv = CreateFrame("Frame")
pcall(nearEv.RegisterEvent, nearEv, "ZONE_CHANGED_NEW_AREA")
pcall(nearEv.RegisterEvent, nearEv, "PLAYER_LOGIN")
nearEv:SetScript("OnEvent", function(_, e)
  -- szyna Polestara (Hub\PolestarSzyna.lua) laduje sie pozniej w TOC: zapis po wczytaniu wszystkiego
  if e == "PLAYER_LOGIN" then
    if U.onPolestar then U.onPolestar({ "CODEX_LOADED" }, function() NEAR.cache = {} end) end
    return
  end
  NEAR.cache = {}
end)

U.testChecksExtra = U.testChecksExtra or {}
table.insert(U.testChecksExtra, { "Polestar: najbliższe usługi (Nav.nearby.Find, Go)", function()
  local N = nearbyApi()
  if not _G.Polestar then return "brak Polestara (usługi z Questie jak dotąd)" end
  if not N then error("brak Polestar.Nav.nearby.Find (Nav\\Nearby.lua:433)") end
  if type(N.Go) ~= "function" then error("brak Polestar.Nav.nearby.Go (Nav\\Nearby.lua:462)") end
  local ok, place, s = pcall(N.Find, "class")
  if not ok then error("Find(class): " .. tostring(place)) end
  local parts = { "trener klasy: " .. (type(place) == "table" and (tostring(place.name) .. (U.num(s) and (", " .. math.floor(s) .. " s") or "")) or ("brak (" .. tostring(s) .. ")")) }
  local X = _G.Polestar.Codex
  if X and U.call(X.IsLoaded) then
    local okR, pr, sr = pcall(N.Find, "repair")
    parts[#parts + 1] = "naprawa: " .. ((okR and type(pr) == "table") and (tostring(pr.name) .. (U.num(sr) and (", " .. math.floor(sr) .. " s") or "")) or ("brak (" .. tostring(sr) .. ")"))
  else
    parts[#parts + 1] = "reszta usług po wczytaniu Codexu (tryb Miasto, Koło maga)"
  end
  return table.concat(parts, "; ")
end })
