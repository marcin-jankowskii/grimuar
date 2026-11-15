-- Grimuar UI: zakladka Ekwipunek (15.11, research R28 P8–P10, makieta „Ekwipunek Grimuara” warianty B i C, wybor gracza
-- „wszystko po kolei”). Trzy kolumny jak Postac:
-- * lewo: lalka (sloty z ikona i ramka jakosci) i statystyki „teraz” oraz „po”, gdy wybrany przedmiot da sie zalozyc;
-- * srodek: plecak jako siatka (filtry jak grupy plecaka Grimuara na Baganatorze, PlecakRuny.lua: Do walki, Questy,
--   Sprzet, Gotowanie, Tkaniny, Ziola i ruda, Receptury, Materialy, Inne, Smieci; puste sie chowaja) albo lista (C: kolumny
--   Przedmiot, Typ, Ile, Gdzie, Kupiec, AH, Status; sortowanie kliknieciem; torby, bank i inne postacie z Syndicatora);
-- * prawo: karta przedmiotu: nazwa, typ, wartosc, do czego potrzebny (◆ poradnik Polestara), znak gracza (★ / smiec),
--   porownanie z zalozonym (roznica statystyk, Pawn), gdzie jeszcze (Syndicator), akcje: Zaloz (poza walka), Ulubione,
--   Smiec, Link na czat.
-- Tylko odczyt i zwykle funkcje gry; w walce zakladka jest do ogladania (Zaloz czeka). Dane: torby z C_Container,
-- znaki i „potrzebne” z GrimuarSetup PlecakPlus.lua (G.itemMark, G.itemNeed, G.itemIsJunk).
local ADDON, U = ...
local C = U.C
local G = U.G or {}

local S = { filter = "all", view = "grid", sel = nil, sortKey = "v", dir = -1, slots = {}, eq = {}, rows = {}, chips = {} }
local L_W, R_W = 300, 350
local SLOT_PL = { [1] = "Głowa", [2] = "Szyja", [3] = "Barki", [15] = "Plecy", [5] = "Pierś", [4] = "Koszula", [19] = "Tabard",
  [9] = "Nadgarstki", [10] = "Dłonie", [6] = "Pas", [7] = "Nogi", [8] = "Stopy", [11] = "Pierścień", [12] = "Pierścień",
  [13] = "Talizman", [14] = "Talizman", [16] = "Prawa ręka", [17] = "Lewa ręka", [18] = "Dystans" }
local EQ_L, EQ_R, EQ_W = { 1, 2, 3, 15, 5, 4, 19, 9 }, { 10, 6, 7, 8, 11, 12, 13, 14 }, { 16, 17, 18 }
local LOC = { INVTYPE_HEAD = { 1 }, INVTYPE_NECK = { 2 }, INVTYPE_SHOULDER = { 3 }, INVTYPE_CLOAK = { 15 }, INVTYPE_CHEST = { 5 },
  INVTYPE_ROBE = { 5 }, INVTYPE_BODY = { 4 }, INVTYPE_TABARD = { 19 }, INVTYPE_WRIST = { 9 }, INVTYPE_HAND = { 10 },
  INVTYPE_WAIST = { 6 }, INVTYPE_LEGS = { 7 }, INVTYPE_FEET = { 8 }, INVTYPE_FINGER = { 11, 12 }, INVTYPE_TRINKET = { 13, 14 },
  INVTYPE_WEAPON = { 16, 17 }, INVTYPE_2HWEAPON = { 16 }, INVTYPE_WEAPONMAINHAND = { 16 }, INVTYPE_WEAPONOFFHAND = { 17 },
  INVTYPE_HOLDABLE = { 17 }, INVTYPE_SHIELD = { 17 }, INVTYPE_RANGED = { 18 }, INVTYPE_RANGEDRIGHT = { 18 },
  INVTYPE_THROWN = { 18 }, INVTYPE_RELIC = { 18 } }
local STATS = { { "ITEM_MOD_INTELLECT_SHORT", "Intelekt" }, { "ITEM_MOD_STAMINA_SHORT", "Wytrzymałość" },
  { "ITEM_MOD_SPIRIT_SHORT", "Duch" }, { "ITEM_MOD_AGILITY_SHORT", "Zręczność" }, { "ITEM_MOD_STRENGTH_SHORT", "Siła" },
  { "RESISTANCE0_NAME", "Pancerz" }, { "ITEM_MOD_SPELL_POWER_SHORT", "Moc czarów" } }
-- 15.11 (gracz: „w ekwipunku powinny byc co najmniej takie same kategorie jak przy postaci”): te same grupy i ta sama
-- kolejnosc co w plecaku (GrimuarSetup Wyglad\PlecakRuny.lua, kategorie v4)
local FILTERS = { { "all", "Wszystko" }, { "walka", "Do walki" }, { "quest", "Questy" }, { "profesje", "Profesje" }, { "sprzet", "Sprzęt" },
  { "gotowanie", "Gotowanie" }, { "tkaniny", "Tkaniny" }, { "ziola", "Zioła i ruda" }, { "receptury", "Receptury" },
  { "materialy", "Materiały" }, { "inne", "Inne" }, { "smieci", "Śmieci" } }
local ORDER = {}
for i, f in ipairs(FILTERS) do ORDER[f[1]] = i end

local function money(c) return U.money and U.money(c) or tostring(c) end
local function sellPrice(id)
  local ok, v = pcall(function() return select(11, C_Item.GetItemInfo(id)) end)
  return (ok and U.num(v)) or 0
end
-- klasy i podklasy przedmiotow jak slowa kluczowe Baganatora w PlecakRuny.lua: materialy (7): 8 mieso = Gotowanie,
-- 5 tkanina = Tkaniny, 7 metal i kamien albo 9 ziolo = Ziola i ruda; 9 = Receptury; 5 = odczynniki (Materialy);
-- Hearthstone (6948) do walki jak w plecaku
local function groupOf(it)
  if G.itemIsJunk and G.itemIsJunk(it.id, it.q) then return "smieci" end
  local c, s = it.cls, it.sub
  if c == 12 then return "quest" end
  -- 15.11: narzedzia profesji (Mining Pick to bron) w osobnej grupie, jak w plecaku
  if U.G and U.G.isProfTool and U.G.isProfTool(it.id) then return "profesje" end
  if c == 2 or c == 4 then return "sprzet" end
  if c == 0 or it.id == 6948 then return "walka" end
  if c == 7 then
    if s == 8 then return "gotowanie" end
    if s == 5 then return "tkaniny" end
    if s == 7 or s == 9 then return "ziola" end
    return "materialy"
  end
  if c == 9 then return "receptury" end
  if c == 5 then return "materialy" end
  return "inne"
end

-- ---------- dane ----------
local function instant(id)
  local ok, _, _, _, loc, icon, cls, sub = pcall(C_Item.GetItemInfoInstant, id)
  if ok then return loc, icon, cls, sub end
end
local function bagItems()
  local by, list = {}, {}
  for bag = 0, (NUM_BAG_SLOTS or 4) do
    for slot = 1, U.num(U.call(C_Container.GetContainerNumSlots, bag)) or 0 do
      local info = U.call(C_Container.GetContainerItemInfo, bag, slot)
      if type(info) == "table" and info.itemID then
        local it = by[info.itemID]
        if not it then
          local loc, icon, cls, sub = instant(info.itemID)
          it = { id = info.itemID, link = info.hyperlink, n = 0, q = info.quality, icon = info.iconFileID or icon, cls = cls, sub = sub, loc = loc,
            bag = bag, slot = slot, where = "torby" }
          by[info.itemID] = it
          list[#list + 1] = it
        end
        it.n = it.n + (info.stackCount or 1)
      end
    end
  end
  return list
end
local function slotsFree()
  local free, all = 0, 0
  for bag = 0, (NUM_BAG_SLOTS or 4) do
    local n = U.num(U.call(C_Container.GetContainerNumSlots, bag)) or 0
    all = all + n
    free = free + (U.num(U.call(C_Container.GetContainerNumFreeSlots, bag)) or 0)
  end
  return free, all
end
-- lista (C): torby, bank i inne postacie z Syndicatora
local function allItems()
  local rows = {}
  for _, it in ipairs(bagItems()) do rows[#rows + 1] = it end
  local SA = Syndicator and Syndicator.API
  if not SA then return rows end
  local cur = U.call(SA.GetCurrentCharacter)
  local function addFrom(container, whereLabel)
    local by = {}
    for _, bag in ipairs(type(container) == "table" and container or {}) do
      for _, s in ipairs(type(bag) == "table" and bag or {}) do
        if type(s) == "table" and s.itemID then
          local it = by[s.itemID]
          if not it then
            local loc, icon, cls, sub = instant(s.itemID)
            it = { id = s.itemID, link = s.itemLink, n = 0, q = s.quality, icon = icon, cls = cls, sub = sub, loc = loc, where = whereLabel }
            by[s.itemID] = it
            rows[#rows + 1] = it
          end
          it.n = it.n + (s.itemCount or 1)
        end
      end
    end
  end
  pcall(function()
    local me = cur and SA.GetByCharacterFullName(cur)
    if me then addFrom(me.bank, "bank") end
    for _, name in ipairs(SA.GetAllCharacters() or {}) do
      if name ~= cur then
        local ch = SA.GetByCharacterFullName(name)
        if ch then
          local short = tostring(name):match("^[^-]+") or name
          addFrom(ch.bags, short)
          addFrom(ch.bank, short .. " (bank)")
        end
      end
    end
  end)
  return rows
end

local function statsOf(link)
  if not link then return {} end
  local fn = C_Item and C_Item.GetItemStats or GetItemStats
  local ok, t = pcall(fn, link)
  return (ok and type(t) == "table") and t or {}
end
local function equippedFor(it)
  local slots = it and it.loc and LOC[it.loc]
  if not slots then return nil end
  local slot = slots[1]
  -- pierscienie i talizmany: porownaj ze slabszym (pustym albo nizszej jakosci)
  if #slots == 2 then
    local a, b = U.call(GetInventoryItemLink, "player", slots[1]), U.call(GetInventoryItemLink, "player", slots[2])
    if not a then slot = slots[1] elseif not b then slot = slots[2] end
  end
  return slot, U.call(GetInventoryItemLink, "player", slot)
end
local function pawnUp(link)
  local fn = _G.PawnShouldItemLinkHaveUpgradeArrow
  if type(fn) ~= "function" or not link then return nil end
  local ok, r = pcall(fn, link, true)
  return ok and r and true or false
end

-- ---------- lewa kolumna: lalka i statystyki ----------
local function eqSlot(parent, inv)
  local s = U.Slot(parent, 36)
  s.inv = inv
  s:SetScript("OnEnter", function(self)
    U.TT:SetOwner(self, "ANCHOR_RIGHT")
    if not pcall(U.TT.SetInventoryItem, U.TT, "player", self.inv) or not GetInventoryItemID("player", self.inv) then
      U.TT:SetText(SLOT_PL[self.inv] or "")
    end
    U.TT:Show()
  end)
  s:SetScript("OnLeave", function() U.TT:Hide() end)
  S.eq[inv] = s
  return s
end
local function drawDoll()
  for inv, s in pairs(S.eq) do
    local tex = U.call(GetInventoryItemTexture, "player", inv)
    s.icon:SetShown(tex ~= nil)
    if tex then s.icon:SetTexture(tex) end
    s:SetQuality(U.num(U.call(GetInventoryItemQuality, "player", inv)))
    s.count:SetText("")
  end
  -- statystyki: teraz i po (wybrany przedmiot w miejsce zalozonego)
  local it = S.selItem
  local slot, cur = equippedFor(it)
  local newS, oldS = it and slot and statsOf(it.link) or {}, statsOf(cur)
  local lines = {}
  local base = {
    { "Zdrowie", U.num(U.call(UnitHealthMax, "player")) }, { "Mana", U.num(U.call(UnitPowerMax, "player", 0)) },
    { "Pancerz", U.num(select(2, U.call(UnitArmor, "player"))) },
  }
  for _, st in ipairs({ { 4, "Intelekt" }, { 3, "Wytrzymałość" }, { 5, "Duch" }, { 2, "Zręczność" }, { 1, "Siła" } }) do
    local _, eff = U.call(UnitStat, "player", st[1])
    base[#base + 1] = { st[2], U.num(eff) }
  end
  for _, b in ipairs(base) do
    local d
    if it and slot then
      for _, key in ipairs(STATS) do
        if key[2] == b[1] then d = (U.num(newS[key[1]]) or 0) - (U.num(oldS[key[1]]) or 0) end
      end
      if b[1] == "Zdrowie" then d = ((U.num(newS.ITEM_MOD_STAMINA_SHORT) or 0) - (U.num(oldS.ITEM_MOD_STAMINA_SHORT) or 0)) * 10 end
      if b[1] == "Mana" then d = ((U.num(newS.ITEM_MOD_INTELLECT_SHORT) or 0) - (U.num(oldS.ITEM_MOD_INTELLECT_SHORT) or 0)) * 15 end
    end
    local dTxt = (d and d ~= 0) and ((d > 0 and U.hex(C.ok) .. "+" or U.hex(C.danger)) .. d .. "|r") or ""
    lines[#lines + 1] = { b[1], b[2] and U.thousands(b[2]) or "—", dTxt }
  end
  for i, l in ipairs(lines) do
    local r = S.statRows[i]
    r.k:SetText(l[1]) r.v:SetText(l[2]) r.d:SetText(l[3])
  end
  S.statHead:SetText(it and slot and ("teraz · po zmianie: " .. (SLOT_PL[slot] or "")) or "statystyki")
end

-- ---------- srodek: siatka i lista ----------
local function gridSlot(i)
  local s = S.slots[i]
  if s then return s end
  s = U.Slot(S.grid, 38)
  s.need = s:CreateTexture(nil, "OVERLAY", nil, 3)
  s.need:SetSize(7, 7) s.need:SetPoint("BOTTOMLEFT", 4, 4)
  s.need:SetColorTexture(0.49, 0.88, 0.49, 1)
  pcall(s.need.SetRotation, s.need, math.rad(45))
  s.fav = s:CreateTexture(nil, "OVERLAY", nil, 3)
  s.fav:SetSize(12, 12) s.fav:SetPoint("TOPRIGHT", -1, -1)
  if not pcall(s.fav.SetAtlas, s.fav, "PetJournal-FavoritesIcon") then s.fav:SetColorTexture(C.gold[1], C.gold[2], C.gold[3], 1) end
  s.up = s:CreateTexture(nil, "OVERLAY", nil, 3)
  s.up:SetSize(14, 14) s.up:SetPoint("TOPLEFT", 1, -1)
  pcall(s.up.SetAtlas, s.up, "bags-greenarrow")
  s.selT = s:CreateTexture(nil, "OVERLAY", nil, 4)
  s.selT:SetPoint("TOPLEFT", -2, 2) s.selT:SetPoint("BOTTOMRIGHT", 2, -2)
  s.selT:SetColorTexture(C.gold[1], C.gold[2], C.gold[3], 0.25)
  s:SetScript("OnClick", function(self)
    if not self.it then return end
    if IsModifiedClick("CHATLINK") and self.it.link then pcall(ChatEdit_InsertLink, self.it.link) return end
    S.sel = self.it.id
    U.ekwipunekRefresh()
  end)
  s:SetScript("OnEnter", function(self)
    if not self.it then return end
    U.TT:SetOwner(self, "ANCHOR_RIGHT")
    if not (self.it.link and pcall(U.TT.SetHyperlink, U.TT, self.it.link)) then pcall(U.TT.SetItemByID, U.TT, self.it.id) end
    U.TT:Show()
  end)
  s:SetScript("OnLeave", function() U.TT:Hide() end)
  S.slots[i] = s
  return s
end
local function drawGrid(items)
  local per = math.max(4, math.floor(((S.gridView:GetWidth() or 400) + 4) / 42))
  local n = 0
  for _, it in ipairs(items) do
    n = n + 1
    local s = gridSlot(n)
    s.it = it
    s:ClearAllPoints()
    s:SetPoint("TOPLEFT", S.grid, "TOPLEFT", ((n - 1) % per) * 42, -math.floor((n - 1) / per) * 42)
    s.icon:SetShown(true)
    s.icon:SetTexture(it.icon or 134400)
    s:SetQuality(it.q)
    s.count:SetText(it.n > 1 and it.n or "")
    local junk = G.itemIsJunk and G.itemIsJunk(it.id, it.q)
    s.icon:SetDesaturated(junk and true or false)
    s.need:SetShown(G.itemNeed and G.itemNeed(it.id) ~= nil or false)
    s.fav:SetShown(G.itemMark and G.itemMark(it.id) == "fav" or false)
    s.up:SetShown((it.cls == 2 or it.cls == 4) and pawnUp(it.link) or false)
    s.selT:SetShown(it.id == S.sel)
    s:Show()
  end
  local free = select(1, slotsFree())
  if S.filter == "all" then
    for _ = 1, free do
      n = n + 1
      local s = gridSlot(n)
      s.it = nil
      s:ClearAllPoints()
      s:SetPoint("TOPLEFT", S.grid, "TOPLEFT", ((n - 1) % per) * 42, -math.floor((n - 1) / per) * 42)
      s.icon:SetShown(false) s.count:SetText("") s:SetQuality(nil)
      s.need:Hide() s.fav:Hide() s.up:Hide() s.selT:Hide()
      s:Show()
    end
  end
  for i = n + 1, #S.slots do S.slots[i]:Hide() end
  S.grid:SetHeight(math.max(10, math.ceil(n / per) * 42))
end

local COLS = { { "nm", "Przedmiot", 230 }, { "tp", "Typ", 110 }, { "n", "Ile", 44, true }, { "wh", "Gdzie", 110 },
  { "v", "Kupiec", 80, true }, { "ah", "AH", 80, true }, { "st", "Status", 130 } }
local function listRow(i)
  local r = S.rows[i]
  if r then return r end
  r = CreateFrame("Button", nil, S.list)
  r:SetHeight(24)
  local hl = r:CreateTexture(nil, "HIGHLIGHT") hl:SetAllPoints() hl:SetColorTexture(1, 1, 1, 0.05)
  r.ic = r:CreateTexture(nil, "ARTWORK") r.ic:SetSize(20, 20) r.ic:SetPoint("LEFT", 2, 0) r.ic:SetTexCoord(0.08, 0.92, 0.08, 0.92)
  r.c = {}
  local x = 28
  for _, col in ipairs(COLS) do
    local fs = U.Text(r, 12, "body", C.text)
    fs:SetPoint("LEFT", x, 0)
    fs:SetWidth(col[3] - 8)
    fs:SetJustifyH(col[4] and "RIGHT" or "LEFT")
    fs:SetJustifyV("MIDDLE")
    r.c[col[1]] = fs
    x = x + col[3]
  end
  r:SetScript("OnClick", function(self) if self.it then S.sel = self.it.id U.ekwipunekRefresh() end end)
  r:SetScript("OnEnter", function(self)
    if not self.it then return end
    U.TT:SetOwner(self, "ANCHOR_RIGHT")
    if not (self.it.link and pcall(U.TT.SetHyperlink, U.TT, self.it.link)) then pcall(U.TT.SetItemByID, U.TT, self.it.id) end
    U.TT:Show()
  end)
  r:SetScript("OnLeave", function() U.TT:Hide() end)
  S.rows[i] = r
  return r
end
local function status(it)
  local t = {}
  if G.itemNeed and G.itemNeed(it.id) then t[#t + 1] = U.hex({ 0.49, 0.88, 0.49 }) .. "◆ potrzebne|r" end
  if it.cls == 12 then t[#t + 1] = U.hex({ 1, 0.85, 0.29 }) .. "quest|r" end
  local m = G.itemMark and G.itemMark(it.id)
  if m == "fav" then t[#t + 1] = U.hex(C.gold) .. "★|r" end
  if G.itemIsJunk and G.itemIsJunk(it.id, it.q) then t[#t + 1] = U.hex(C.faint) .. "śmieć|r" end
  return table.concat(t, " ")
end
local function drawList(items)
  for _, it in ipairs(items) do
    it.nm = it.nm or U.call(C_Item.GetItemNameByID, it.id) or ("przedmiot " .. it.id)
    it.v = sellPrice(it.id) * it.n
    it.ah = (U.itemValue and U.itemValue(it.id) or 0) * it.n
    it.tp = it.tp or select(2, U.call(C_Item.GetItemInfoInstant, it.id)) or ""
  end
  local k, dir = S.sortKey, S.dir
  table.sort(items, function(a, b)
    local x, y = a[k], b[k]
    if type(x) == "number" or type(y) == "number" then
      local d = (U.num(x) or 0) - (U.num(y) or 0)
      if d == 0 then return a.id < b.id end
      return d * dir < 0
    end
    local sx, sy = tostring(x or ""), tostring(y or "")
    if sx == sy then return a.id < b.id end
    return (sx < sy) == (dir > 0)
  end)
  for i, it in ipairs(items) do
    local r = listRow(i)
    r.it = it
    r:ClearAllPoints() r:SetPoint("TOPLEFT", S.list, "TOPLEFT", 0, -(i - 1) * 25)
    r:SetWidth(S.list:GetWidth())
    r.ic:SetTexture(it.icon or 134400)
    r.c.nm:SetText(it.nm) U.Color(r.c.nm, U.QUALITY[it.q or 1] or C.text)
    r.c.tp:SetText(it.tp) r.c.n:SetText(it.n) r.c.wh:SetText(it.where)
    r.c.v:SetText(it.v > 0 and money(it.v) or "—")
    r.c.ah:SetText(it.ah > 0 and money(it.ah) or "—")
    r.c.st:SetText(status(it))
    r:Show()
  end
  for i = #items + 1, #S.rows do S.rows[i]:Hide() end
  S.list:SetHeight(math.max(10, #items * 25))
  for _, h in ipairs(S.heads) do
    h.label:SetText(h.title .. (h.key == S.sortKey and (S.dir > 0 and " ▲" or " ▼") or ""))
  end
end

-- ---------- prawo: karta przedmiotu ----------
local function drawCard(it)
  local P = S.card
  P:Begin(P.cardId == (it and it.id))
  P.cardId = it and it.id
  -- 15.11 (R30 P34): ulepszenia przed Toba na trasie Polestara (EkwipunekPolestar.lua)
  local function ahead(limit)
    local up = U.psUpgradeCards and U.call(U.psUpgradeCards, limit) or {}
    if #up > 0 then
      P:Head("Przed Tobą na trasie", "nagrody z questów lepsze od założonych")
      P:Cards(up, { cols = 1 })
    end
  end
  if not it then
    P:Para("Kliknij przedmiot w siatce albo na liście.", C.muted)
    ahead(5)
    P:End()
    return
  end
  local name = U.call(C_Item.GetItemNameByID, it.id) or it.nm or ("przedmiot " .. it.id)
  local _, itemType, itemSub = U.call(C_Item.GetItemInfoInstant, it.id)
  P:Title(U.hex(U.QUALITY[it.q or 1] or C.text) .. name .. "|r", (itemSub or itemType or "") .. (it.n > 1 and (" · " .. it.n .. " szt.") or "") ..
    " · u kupca " .. money(sellPrice(it.id) * it.n))
  local need = G.itemNeed and G.itemNeed(it.id)
  if need then P:Cards({ { title = "Potrzebne", sub = need, col = { 0.49, 0.88, 0.49 }, tip = "Grimuar nie odda tego do śmieci ani do banku." } }, { cols = 1 }) end
  if it.cls == 12 then P:Cards({ { title = "Przedmiot do questu", sub = "Dziennik (J) pokaże, do którego zadania.", col = { 1, 0.85, 0.29 } } }, { cols = 1 }) end
  -- porownanie
  local slot, cur = equippedFor(it)
  if slot then
    local a, b = statsOf(it.link), statsOf(cur)
    local cards = {}
    for _, st in ipairs(STATS) do
      local d = (U.num(a[st[1]]) or 0) - (U.num(b[st[1]]) or 0)
      if d ~= 0 then cards[#cards + 1] = { title = st[2], right = (d > 0 and "+" or "") .. d, rightCol = d > 0 and C.ok or C.danger } end
    end
    local up = pawnUp(it.link)
    P:Head("Zamiast: " .. (cur and (U.call(C_Item.GetItemNameByID, U.call(GetInventoryItemID, "player", slot)) or SLOT_PL[slot]) or (SLOT_PL[slot] .. " (pusty)")),
      up == nil and "" or (up and "Pawn: ulepszenie dla buildu" or "Pawn: nie jest lepszy"))
    if #cards > 0 then P:Cards(cards, { minW = 150 }) else P:Para("Bez różnicy w statystykach.", C.muted, 12) end
  end
  -- gdzie jeszcze
  local SA = Syndicator and Syndicator.API
  if SA and SA.GetInventoryInfoByItemID then
    local ok, info = pcall(SA.GetInventoryInfoByItemID, it.id, true, true)
    if ok and type(info) == "table" then
      local chips = {}
      for _, ch in ipairs(info.characters or {}) do
        local parts = {}
        for _, k in ipairs({ { "bags", "torby" }, { "bank", "bank" }, { "mail", "poczta" }, { "equipped", "założone" } }) do
          if (ch[k[1]] or 0) > 0 then parts[#parts + 1] = k[2] .. " " .. ch[k[1]] end
        end
        if #parts > 0 then chips[#chips + 1] = { text = (ch.character or "?") .. ": " .. table.concat(parts, ", ") } end
      end
      if #chips > 0 then P:Head("Gdzie jeszcze") P:Chips(chips) end
    end
  end
  -- 15.11 (R30 P28): skad zdobyc i „Prowadź po to” z Polestara (liczone po wybraniu przedmiotu, EkwipunekPolestar.lua)
  if U.psSourceBlocks then pcall(U.psSourceBlocks, P, it.id, name) end
  -- akcje
  P:Head("Akcje")
  local m = G.itemMark and G.itemMark(it.id)
  if slot and not InCombatLockdown() then
    P:Button("Załóż", function()
      if InCombatLockdown() then U.say("zakładam po walce.") return end
      if it.link then pcall(C_Item.EquipItemByName, it.link) end
      C_Timer.After(0.5, function() pcall(U.ekwipunekRefresh) end)
    end, true)
  end
  P:Button(m == "fav" and "★ Usuń z ulubionych" or "★ Ulubione (nigdy do śmieci)", function() if G.itemMarkSet then G.itemMarkSet(it.id, m ~= "fav" and "fav" or nil) end end)
  P:Button(m == "junk" and "To nie śmieć" or "Oznacz jako śmieć", function() if G.itemMarkSet then G.itemMarkSet(it.id, m ~= "junk" and "junk" or nil) end end)
  if it.link then P:Button("Link na czat", function() pcall(ChatEdit_InsertLink, it.link) end) end
  ahead(3)
  P:End()
end

-- ---------- odswiezanie ----------
function U.ekwipunekRefresh()
  if not (S.page and S.page:IsVisible()) then return end
  local items = S.view == "list" and allItems() or bagItems()
  local shown, counts = {}, { all = #items }
  for _, it in ipairs(items) do
    local g = groupOf(it)
    counts[g] = (counts[g] or 0) + 1
    if S.filter == "all" or S.filter == g then shown[#shown + 1] = it end
  end
  -- kolejnosc w siatce jak w plecaku (ORDER z FILTERS)
  if S.view ~= "list" then
    table.sort(shown, function(a, b)
      local ga, gb = ORDER[groupOf(a)] or 9, ORDER[groupOf(b)] or 9
      if ga ~= gb then return ga < gb end
      if (a.q or 0) ~= (b.q or 0) then return (a.q or 0) > (b.q or 0) end
      return a.id < b.id
    end)
  end
  -- filtry: puste grupy sie chowaja (jak w plecaku), poza „Wszystko” i wybranym; zawijanie do drugiego rzedu
  if S.filter ~= "all" and (counts[S.filter] or 0) == 0 then S.filter = "all" return U.ekwipunekRefresh() end
  local maxW = math.max(200, (S.chipBar:GetWidth() or 600))
  local x, row = 0, 0
  for _, f in ipairs(FILTERS) do
    local k, b = f[1], S.chips[f[1]]
    local show = k == "all" or k == S.filter or (counts[k] or 0) > 0
    b:SetShown(show)
    if show then
      b:SetLabel(b.title .. "  " .. (counts[k] or 0))
      U.Color(b.label, k == S.filter and C.gold or C.muted)
      U.BorderColor(b, k == S.filter and C.gold or C.edge)
      local w = b:GetWidth() or 80
      if x > 0 and x + w > maxW then x, row = 0, row + 1 end
      b:ClearAllPoints()
      b:SetPoint("TOPLEFT", S.chipBar, "TOPLEFT", x, -row * 30)
      x = x + w + 6
    end
  end
  S.chipBar:SetHeight((row + 1) * 30 - 6)
  S.vGrid:SetLabel((S.view == "grid" and "◆ " or "") .. "Siatka")
  S.vList:SetLabel((S.view == "list" and "◆ " or "") .. "Lista")
  S.gridView:SetShown(S.view == "grid")
  S.listView:SetShown(S.view == "list")
  if S.view == "list" then pcall(drawList, shown) else pcall(drawGrid, shown) end
  local free, all = slotsFree()
  local junkList, junkV = {}, 0
  if G.junkList then junkList, junkV = G.junkList() end
  S.sum:SetText((all - free) .. " / " .. all .. " zajęte · " .. U.money(U.num(U.call(GetMoney)) or 0) ..
    (#junkList > 0 and ("   ·   śmieci: " .. #junkList .. " za " .. money(junkV)) or ""))
  local sel
  for _, it in ipairs(items) do if it.id == S.sel then sel = it end end
  S.selItem = sel
  pcall(drawDoll)
  local ok, err = pcall(drawCard, sel)
  if not ok then S.card:Begin() S.card:Para("Karta: " .. tostring(err), C.danger) S.card:End() end
end
G.ekwipunekRefresh = U.ekwipunekRefresh

-- ---------- budowa ----------
local function build(page)
  S.page = page
  -- lewo: lalka
  local left = U.Panel(page, 0.86, true)
  left:SetPoint("TOPLEFT") left:SetPoint("BOTTOMLEFT") left:SetWidth(L_W)
  local h = U.H2(left, UnitName("player") or "Postać")
  h:SetPoint("TOPLEFT", 16, -14)
  local colL, colR = CreateFrame("Frame", nil, left), CreateFrame("Frame", nil, left)
  colL:SetSize(36, 8 * 40) colL:SetPoint("TOPLEFT", 16, -44)
  colR:SetSize(36, 8 * 40) colR:SetPoint("TOPRIGHT", -16, -44)
  for i, inv in ipairs(EQ_L) do eqSlot(colL, inv):SetPoint("TOPLEFT", 0, -(i - 1) * 40) end
  for i, inv in ipairs(EQ_R) do eqSlot(colR, inv):SetPoint("TOPLEFT", 0, -(i - 1) * 40) end
  local model = CreateFrame("PlayerModel", nil, left)
  model:SetPoint("TOPLEFT", colL, "TOPRIGHT", 6, 0)
  model:SetPoint("BOTTOMRIGHT", colR, "BOTTOMLEFT", -6, 0)
  pcall(model.SetUnit, model, "player")
  S.model = model
  for i, inv in ipairs(EQ_W) do
    local s = eqSlot(left, inv)
    s:SetPoint("TOP", left, "TOP", (i - 2) * 42, -44 - 8 * 40 - 6)
  end
  S.statHead = U.Label(left, "statystyki")
  S.statHead:SetPoint("TOPLEFT", 16, -44 - 8 * 40 - 56)
  S.statRows = {}
  for i = 1, 8 do
    local r = {}
    r.k = U.Text(left, 12, "body", C.muted) r.k:SetPoint("TOPLEFT", S.statHead, "BOTTOMLEFT", 0, -6 - (i - 1) * 17)
    r.v = U.Text(left, 12, "body", C.text) r.v:SetJustifyH("RIGHT")
    r.v:SetPoint("TOP", r.k, "TOP", 0, 0) r.v:SetPoint("RIGHT", left, "LEFT", L_W - 64, 0)
    r.d = U.Text(left, 12, "body", C.text) r.d:SetPoint("TOP", r.k, "TOP", 0, 0) r.d:SetPoint("RIGHT", left, "RIGHT", -16, 0) r.d:SetJustifyH("RIGHT")
    S.statRows[i] = r
  end
  -- prawo: karta
  S.card = U.Blocks(page)
  S.card:SetPoint("TOPRIGHT") S.card:SetPoint("BOTTOMRIGHT") S.card:SetWidth(R_W)
  -- srodek
  local mid = U.Panel(page, 0.86, true)
  mid:SetPoint("TOPLEFT", left, "TOPRIGHT", 20, 0)
  mid:SetPoint("BOTTOMRIGHT", S.card, "BOTTOMLEFT", -20, 0)
  local mh = U.H2(mid, "Plecak")
  mh:SetPoint("TOPLEFT", 18, -14)
  S.vList = U.Button(mid, "Lista", nil, 24)
  S.vList:SetPoint("TOPRIGHT", -14, -10)
  S.vList:SetScript("OnClick", function() S.view = "list" U.ekwipunekRefresh() end)
  S.vGrid = U.Button(mid, "Siatka", nil, 24)
  S.vGrid:SetPoint("RIGHT", S.vList, "LEFT", -6, 0)
  S.vGrid:SetScript("OnClick", function() S.view = "grid" U.ekwipunekRefresh() end)
  S.chipBar = CreateFrame("Frame", nil, mid)
  S.chipBar:SetPoint("TOPLEFT", mh, "BOTTOMLEFT", 0, -10)
  S.chipBar:SetPoint("RIGHT", mid, "RIGHT", -16, 0)
  S.chipBar:SetHeight(24)
  for _, f in ipairs(FILTERS) do
    local b = U.Button(S.chipBar, f[2], nil, 24)
    b.title = f[2]
    b:SetScript("OnClick", function() S.filter = f[1] U.ekwipunekRefresh() end)
    S.chips[f[1]] = b
  end
  S.sum = U.Text(mid, 12, "body", C.muted)
  S.sum:SetPoint("BOTTOMLEFT", 18, 14)
  -- siatka
  local gv = CreateFrame("ScrollFrame", nil, mid)
  gv:SetPoint("TOPLEFT", S.chipBar, "BOTTOMLEFT", 0, -12)
  gv:SetPoint("BOTTOMRIGHT", -16, 40)
  S.grid = CreateFrame("Frame", nil, gv)
  S.grid:SetSize(400, 10)
  gv:SetScrollChild(S.grid)
  gv:EnableMouseWheel(true)
  gv:SetScript("OnMouseWheel", function(self, d)
    local max = math.max(0, S.grid:GetHeight() - self:GetHeight())
    self:SetVerticalScroll(math.max(0, math.min(max, self:GetVerticalScroll() - d * 84)))
  end)
  S.gridView = gv
  -- lista
  local lv = CreateFrame("Frame", nil, mid)
  lv:SetPoint("TOPLEFT", S.chipBar, "BOTTOMLEFT", 0, -12)
  lv:SetPoint("BOTTOMRIGHT", -16, 40)
  S.listView = lv
  S.heads = {}
  local x = 28
  for _, col in ipairs(COLS) do
    local hb = CreateFrame("Button", nil, lv)
    hb:SetSize(col[3], 20)
    hb:SetPoint("TOPLEFT", x, 0)
    hb.label = U.Text(hb, 11, "title", C.gold)
    hb.label:SetPoint(col[4] and "RIGHT" or "LEFT", col[4] and -8 or 0, 0)
    hb.title, hb.key = col[2], col[1]
    hb:SetScript("OnClick", function()
      if S.sortKey == col[1] then S.dir = -S.dir else S.sortKey = col[1] S.dir = col[4] and -1 or 1 end
      U.ekwipunekRefresh()
    end)
    S.heads[#S.heads + 1] = hb
    x = x + col[3]
  end
  local line = U.Line(lv, C.gold, 0.25)
  line:SetPoint("TOPLEFT", 0, -22) line:SetPoint("TOPRIGHT", 0, -22)
  local sv = CreateFrame("ScrollFrame", nil, lv)
  sv:SetPoint("TOPLEFT", 0, -26) sv:SetPoint("BOTTOMRIGHT")
  S.list = CreateFrame("Frame", nil, sv)
  S.list:SetSize(x, 10)
  sv:SetScrollChild(S.list)
  sv:EnableMouseWheel(true)
  sv:SetScript("OnMouseWheel", function(self, d)
    local max = math.max(0, S.list:GetHeight() - self:GetHeight())
    self:SetVerticalScroll(math.max(0, math.min(max, self:GetVerticalScroll() - d * 100)))
  end)
  lv:Hide()
end

local ev = CreateFrame("Frame")
for _, e in ipairs({ "BAG_UPDATE_DELAYED", "PLAYER_EQUIPMENT_CHANGED", "PLAYER_MONEY", "GET_ITEM_INFO_RECEIVED" }) do pcall(ev.RegisterEvent, ev, e) end
ev:SetScript("OnEvent", function()
  if not (S.page and S.page:IsVisible()) or S.q then return end
  S.q = true
  C_Timer.After(0.4, function() S.q = nil pcall(U.ekwipunekRefresh) end)
end)

U.RegisterTab({
  id = "ekwipunek", order = 1.5, title = "Ekwipunek", keys = "",
  hints = { { { "LPM" }, "Wybierz przedmiot" }, { { "Shift", "LPM" }, "Link na czat" } },
  heavy = true,
  note = "Plecak, porównanie z założonym, gdzie co leży i co sprzedać",
  build = build,
  refresh = function() C_Timer.After(0, function() pcall(function() if S.model then S.model:SetUnit("player") end end) pcall(U.ekwipunekRefresh) end) end,
})
