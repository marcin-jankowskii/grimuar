-- Grimuar: Porzadki w torbach (15.11, gracz: „sporo itemow, z ktorymi nie wiem co zrobic; zeby inventory podpowiadalo albo
-- cos robilo, zeby latwo tu czyscic”; wybory: „jeden klik na grupe”, jedzenie „sprzedaj poza bufowym”).
-- Dla kazdego przedmiotu w torbach werdykt i powod:
--   zostaw   ★ ulubione, ◆ potrzebne (poradnik profesji, trasa Polestara), quest, Hearthstone, jedzenie z bonusem,
--            stworzone (Conjured), mikstury i bandaze, ulepszenie juz zalozone gdzie indziej;
--   uzyj     ulepszenie wg Pawna (zaloz), zwoj Intelektu/Ducha/Wytrzymalosci/Ochrony, receptura znanej profesji,
--            ktorej jeszcze nie znasz, wieksza torba;
--   aukcja   cena z Auctionatora co najmniej 2× u kupca i lacznie od 50 s (ziola, ruda, receptury, zielony sprzet BoE);
--   bank     sprzet na wyzszy poziom (dla maga), tkanina od 30 poziomu (Krawiectwo w planie);
--   sprzedaj reszta z cena u kupca, w tym zwykle jedzenie i picie (mag tworzy je sam: Conjure Food/Water);
--   smieci   szare i oznaczone (sprzedaja sie same u kupca, PlecakPlus.lua);
--   wyrzuc   bez ceny u kupca i bez wartosci (szare albo zwykle), nie quest.
-- G.porzadki() -> grupy z listami { bag, slot, id, link, count, icon, quality, value, reason }; okno w GrimuarUI
-- (Okna\Porzadki.lua), przycisk „Porzadki” na dole plecaka, linia w dymku przedmiotu.
local ADDON_NAME, G = ...

local E = Enum and Enum.ItemClass or {}
local CONSUMABLE, CONTAINER, WEAPON, ARMOR, REAGENT, TRADE, RECIPE, QUEST, MISC = E.Consumable or 0, E.Container or 1,
  E.Weapon or 2, E.Armor or 4, E.Reagent or 5, E.Tradegoods or 7, E.Recipe or 9, E.Questitem or 12, E.Miscellaneous or 15
local RECIPE_PROF = { [1] = "Leatherworking", [2] = "Tailoring", [3] = "Engineering", [4] = "Blacksmithing", [5] = "Cooking",
  [6] = "Alchemy", [7] = "First Aid", [8] = "Enchanting", [9] = "Fishing", [10] = "Jewelcrafting" }
-- bron i zbroja, ktore mag moze nosic (cloth 1, rozne 0; kostur 10, sztylet 15, miecz 1h 7, rozdzka 19)
local MAGE_ARMOR = { [0] = true, [1] = true }
local MAGE_WEAPON = { [10] = true, [15] = true, [7] = true, [19] = true }
local GOOD_SCROLL = { "intellect", "spirit", "stamina", "protection" }
local HEARTH = { [6948] = true }
-- 15.11 (gracz: „rzeczy potrzebne do profesji powinny miec tez kategorie, zebym wiecej nie sprzedal przez przypadek
-- pickaxe”): narzedzia profesji nigdy do sprzedazy, aukcji, banku ani wyrzucenia. Mining Pick to w grze bron (topor),
-- wiec wczesniej wpadal w „nie dla maga” i szedl do sprzedazy. Lista ID + nazwy (zapas na przedmioty Forever).
local PROF_TOOLS = {
  [2901] = "Mining", [7005] = "Skinning", [5956] = "Blacksmithing", [6219] = "Engineering", [10498] = "Engineering",
  [6256] = "Fishing", [6365] = "Fishing", [6366] = "Fishing", [6367] = "Fishing", [12225] = "Fishing",
  [4471] = "Cooking", [4470] = "Cooking", [6218] = "Enchanting", [6339] = "Enchanting", [11130] = "Enchanting",
  [11145] = "Enchanting", [16207] = "Enchanting", [9149] = "Alchemy",
}
local TOOL_NAMES = { "mining pick", "skinning knife", "blacksmith hammer", "arclight spanner", "fishing pole",
  "flint and tinder", "runed copper rod", "runed silver rod", "runed golden rod", "runed truesilver rod",
  "runed arcanite rod", "philosopher's stone", "micro-adjustor" }
G.PROF_TOOL_NAMES = TOOL_NAMES
function G.isProfTool(id, name)
  if id and PROF_TOOLS[id] then return PROF_TOOLS[id] end
  if not name and id then
    local ok, n = pcall(C_Item.GetItemInfo, id)
    name = ok and n or nil
  end
  if type(name) ~= "string" then return nil end
  local l = name:lower()
  for _, n in ipairs(TOOL_NAMES) do if l:find(n, 1, true) then return "tool" end end
  return nil
end

local function tipLines(bag, slot)
  local out = {}
  pcall(function()
    local d = C_TooltipInfo and C_TooltipInfo.GetBagItem and C_TooltipInfo.GetBagItem(bag, slot)
    for _, l in ipairs(d and d.lines or {}) do
      if l.leftText then out[#out + 1] = l.leftText:lower() end
    end
  end)
  return out
end
local function tipHas(lines, needle)
  for _, l in ipairs(lines) do if l:find(needle, 1, true) then return true end end
  return false
end
local function ahPrice(id)
  local v
  pcall(function()
    local A = Auctionator and Auctionator.API and Auctionator.API.v1
    if A and A.GetAuctionPriceByItemID then v = A.GetAuctionPriceByItemID("Grimuar", id) end
  end)
  return (type(v) == "number" and v > 0) and v or nil
end
local function money(c) return G.moneyIcons and G.moneyIcons(c) or (math.floor((c or 0) / 100) .. " s") end
local function pawnUp(link)
  local f = _G.PawnShouldItemLinkHaveUpgradeArrow
  if type(f) ~= "function" or not link then return false end
  local ok, r = pcall(f, link, true)
  return ok and r and true or false
end
local function myProfs()
  local p = G.readProfs and select(2, pcall(G.readProfs)) or nil
  return type(p) == "table" and p or {}
end

-- werdykt jednego przedmiotu: verdict, powod, wartosc (miedziaki: u kupca albo na aukcji, za caly stos)
function G.itemVerdict(bag, slot, info)
  local id = info.itemID
  local count = info.stackCount or 1
  local name, link, q, _, minLevel, _, _, _, _, _, vendor, cls, sub = C_Item.GetItemInfo(info.hyperlink or id)
  q = info.quality or q or 1
  vendor = (tonumber(vendor) or 0) * count
  local ah = ahPrice(id)
  ah = ah and ah * count or nil
  local lvl = UnitLevel("player") or 1
  local lname = (name or ""):lower()
  local mark = G.itemMark and G.itemMark(id)
  if mark == "fav" then return "zostaw", "★ ulubione", vendor end
  local need = G.itemNeed and G.itemNeed(id)
  if need then return "zostaw", "◆ potrzebne: " .. tostring(need), vendor end
  if cls == QUEST then return "zostaw", "do zadania", 0 end
  if HEARTH[id] then return "zostaw", "Hearthstone", 0 end
  if G.isProfTool(id, name) then return "zostaw", "narzędzie profesji", 0 end
  if G.itemIsJunk and G.itemIsJunk(id, q) then return "smieci", "śmieć: sprzeda się sam u kupca", vendor end
  local function sellOrAh(reason)
    if ah and ah >= vendor * 2 and ah >= 5000 then return "aukcja", reason .. "; na aukcji ok. " .. money(ah), ah end
    if vendor > 0 then return "sprzedaj", reason, vendor end
    if q <= 1 then return "wyrzuc", reason .. "; bez ceny u kupca", 0 end
    return "zostaw", reason .. "; bez ceny, zostawiam", 0
  end
  if cls == WEAPON or cls == ARMOR then
    if pawnUp(info.hyperlink or link) then return "uzyj", "ulepszenie wg Pawna: załóż", vendor end
    local mine = (cls == ARMOR and MAGE_ARMOR[sub or -1]) or (cls == WEAPON and MAGE_WEAPON[sub or -1])
    if mine and (minLevel or 0) > lvl then return "bank", "na poziom " .. minLevel .. ": do banku", vendor end
    if not info.isBound and q >= 2 then return sellOrAh("nie jest ulepszeniem") end
    return sellOrAh(mine and "nie jest ulepszeniem" or "nie dla maga")
  end
  if cls == CONSUMABLE then
    if lname:find("conjured", 1, true) then return "zostaw", "stworzone przez Ciebie", 0 end
    if sub == 5 then
      local lines = tipLines(bag, slot)
      if tipHas(lines, "well fed") then return "zostaw", "jedzenie z bonusem", vendor end
      return sellOrAh("jedzenie i picie tworzysz sam (Conjure Food, Conjure Water)")
    end
    if lname:find("scroll of", 1, true) then
      for _, s in ipairs(GOOD_SCROLL) do
        if lname:find(s, 1, true) then return "uzyj", "zwój przydatny magowi: użyj przed walką", vendor end
      end
      return sellOrAh("zwój nieprzydatny magowi")
    end
    return "zostaw", "do walki", vendor
  end
  if cls == CONTAINER then
    local lines = tipLines(bag, slot)
    local slots
    for _, l in ipairs(lines) do local n = l:match("(%d+)%s+slot") if n then slots = tonumber(n) break end end
    local smallest, empty = 99, false
    for b = 1, (NUM_BAG_SLOTS or 4) do
      local n = C_Container.GetContainerNumSlots(b) or 0
      if n == 0 then empty = true elseif n < smallest then smallest = n end
    end
    if slots and (empty or slots > smallest) then return "uzyj", "większa torba (" .. slots .. " miejsc): załóż", vendor end
    return sellOrAh("torba nie większa od Twoich")
  end
  if cls == RECIPE then
    local prof = RECIPE_PROF[sub or -1]
    if prof and myProfs()[prof] then
      local known = ITEM_SPELL_KNOWN and tipHas(tipLines(bag, slot), ITEM_SPELL_KNOWN:lower())
      if not known then return "uzyj", "receptura Twojej profesji: naucz się", vendor end
      return sellOrAh("receptura już znana")
    end
    return sellOrAh("receptura profesji, której nie masz")
  end
  if cls == TRADE then
    if sub == 5 and lvl >= 30 then return "bank", "tkanina: Krawiectwo w planie od ok. 40", vendor end
    return sellOrAh(sub == 7 and "ruda: sprzedawaj od razu (ceny spadają)" or (sub == 9 and "zioła: sprzedawaj od razu (ceny spadają)" or "materiał bez użycia w Twoich poradnikach"))
  end
  if cls == REAGENT then return "zostaw", "reagent", vendor end
  if cls == MISC then
    if q >= 2 then return "zostaw", "rzadki przedmiot", vendor end
    return sellOrAh("przedmiot bez zastosowania")
  end
  return "zostaw", "nie wiem: zostawiam", vendor
end

local ORDER = { "sprzedaj", "aukcja", "uzyj", "bank", "wyrzuc", "smieci", "zostaw" }
G.PORZADKI_ORDER = ORDER

-- wszystkie przedmioty z toreb w grupach
function G.porzadki()
  local groups = {}
  for _, k in ipairs(ORDER) do groups[k] = { items = {}, value = 0 } end
  for bag = 0, (NUM_BAG_SLOTS or 4) do
    for slot = 1, (C_Container.GetContainerNumSlots(bag) or 0) do
      local info = C_Container.GetContainerItemInfo(bag, slot)
      if type(info) == "table" and info.itemID then
        local ok, v, why, val = pcall(G.itemVerdict, bag, slot, info)
        if not ok then v, why, val = "zostaw", "nie wiem: zostawiam", 0 end
        local g = groups[v] or groups.zostaw
        g.items[#g.items + 1] = { bag = bag, slot = slot, id = info.itemID, link = info.hyperlink, count = info.stackCount or 1,
          icon = info.iconFileID, quality = info.quality, value = val or 0, reason = why }
        g.value = g.value + (val or 0)
      end
    end
  end
  return groups
end

-- ile rzeczy czeka na decyzje (do przycisku na dole plecaka)
local countCache, countAt = 0, -100
function G.porzadkiCount()
  if GetTime() - countAt < 3 then return countCache end
  local ok, g = pcall(G.porzadki)
  if not ok then return 0 end
  countAt = GetTime()
  local n = 0
  for _, k in ipairs({ "sprzedaj", "aukcja", "uzyj", "bank", "wyrzuc" }) do n = n + #g[k].items end
  countCache = n
  return n
end
