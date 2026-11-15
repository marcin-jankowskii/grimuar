-- Grimuar: modul Rynek (gracz 14.11: „tak bedzie super”, makieta (makieta Grimuara)).
-- Dom aukcyjny ulozony jak Central Market w Black Desert, w palecie Forever Skin: kategorie po lewej, lista z cenami
-- w srodku, wybrany przedmiot z ofertami, historia ceny i kupnem po prawej. Etap 1: zakladka Kupuj.
-- Dane: C_AuctionHouse (jak Auctionator: SendBrowseQuery, SendSearchQuery, StartCommoditiesPurchase + Confirm, PlaceBid);
-- srednia z 7 dni i wykres z historii cen Auctionatora (Auctionator.Database:GetPriceHistory).
-- 15.11 (propozycja 4): kategoria „◆ Do poradnika” (czego brakuje do konca przedzialu poradnikow profesji Polestara,
-- G.psNeededCounts; ilosc do kupienia od razu ustawiona) i zakladka „Sprzedaj” (materialy z toreb bez potrzebnych
-- do poradnika i bez ulubionych; wystawienie towaru po najtanszej ofercie minus 1 miedziak, 24 h, dwa klikniecia).
-- Kupno zawsze Twoimi kliknieciami: pierwsze pokazuje dokladna cene, drugie kupuje. Okno gry zostaje pod spodem
-- (przycisk „Zwykly dom aukcyjny”), Auctionator dziala dalej. /rynek wlacza i wylacza otwieranie Rynku.
local ADDON_NAME, G = ...
local say = G.say

local W, H = 1080, 540
local LEFT_W, RIGHT_W = 190, 300
local ROWS, ROW_H = 11, 38
local MID_W = W - LEFT_W - RIGHT_W
-- prawe krawedzie kolumn (od lewej krawedzi listy); ceny z ikonami monet maja ok. 90 px
local X_PRICE, X_QTY, X_AVG, X_TREND = MID_W - 260, MID_W - 200, MID_W - 90, MID_W - 12
local NAME_W = X_PRICE - 110 - 48

local function fss()
  local ok, loaded = pcall(C_AddOns.IsAddOnLoaded, "ForeverSkin")
  -- 15.11: z lata ForeverSkin w kolorach Grimuara (GRIMUAR_FSS_LATKA) zostaje paleta Grimuara
  return ok and loaded and not GRIMUAR_FSS_LATKA
end
local P = {}
local function palette()
  if fss() then
    P = { panel = { 0.075, 0.08, 0.09, 1 }, inner = { 0.05, 0.05, 0.06, 0.92 }, row = { 0.086, 0.094, 0.106, 1 },
      rowAlt = { 0.075, 0.078, 0.086, 1 }, edge = { 0, 0, 0, 1 }, accent = { 0.95, 0.76, 0.35 }, text = { 0.92, 0.9, 0.86 },
      muted = { 0.61, 0.59, 0.55 } }
  else
    P = { panel = { 0.098, 0.082, 0.059, 1 }, inner = { 0.067, 0.059, 0.047, 0.92 }, row = { 0.11, 0.094, 0.066, 1 },
      rowAlt = { 0.098, 0.082, 0.059, 1 }, edge = { 0.42, 0.35, 0.18, 1 }, accent = { 0.85, 0.71, 0.36 }, text = { 0.93, 0.91, 0.86 },
      muted = { 0.62, 0.6, 0.55 } }
  end
end

-- ---------- kategorie (klasy przedmiotow; podklasy jak w Classic) ----------
local E = Enum.ItemClass
local WAND = (Enum.ItemWeaponSubclass and Enum.ItemWeaponSubclass.Wand) or 19
local CATS = {
  { "◆ Do poradnika", {}, false, special = true },
  { "Torby", { { classID = E.Container } } },
  { "Broń", { { classID = E.Weapon } } },
  { "Różdżki", { { classID = E.Weapon, subClassID = WAND } }, true },
  { "Zbroja", { { classID = E.Armor } } },
  { "Mikstury i bandaże", { { classID = E.Consumable, subClassID = 1 }, { classID = E.Consumable, subClassID = 7 } } },
  { "Jedzenie i picie", { { classID = E.Consumable, subClassID = 5 } } },
  { "Materiały", { { classID = E.Tradegoods } } },
  { "Zioła", { { classID = E.Tradegoods, subClassID = 9 } }, true },
  { "Tkanina", { { classID = E.Tradegoods, subClassID = 5 } }, true },
  { "Ruda i kamień", { { classID = E.Tradegoods, subClassID = 7 } }, true },
  { "Przepisy", { { classID = E.Recipe } } },
  { "Wszystko", {} },
}

-- ---------- stan ----------
local frame
local S = { cat = 2, text = "", results = {}, sel = nil, offset = 0, offers = {}, qty = 1, confirm = nil, waiting = false, mode = "buy" }

local function money(c)
  c = math.floor(tonumber(c) or 0)
  local f = GetCoinTextureString or (C_CurrencyInfo and C_CurrencyInfo.GetCoinTextureString)
  if f then return f(c) end
  return GetMoneyString and GetMoneyString(c, true) or tostring(c)
end

local function tex(parent, layer, c, sub)
  local t = parent:CreateTexture(nil, layer or "BACKGROUND", nil, sub or 0)
  t:SetColorTexture(c[1], c[2], c[3], c[4] or 1)
  return t
end
local function edge(f, c)
  for _, s in ipairs({ { "TOPLEFT", "TOPRIGHT", nil, 1 }, { "BOTTOMLEFT", "BOTTOMRIGHT", nil, 1 }, { "TOPLEFT", "BOTTOMLEFT", 1 }, { "TOPRIGHT", "BOTTOMRIGHT", 1 } }) do
    local t = tex(f, "BORDER", c, 7)
    t:SetPoint(s[1]) t:SetPoint(s[2])
    if s[3] then t:SetWidth(s[3]) else t:SetHeight(s[4]) end
  end
end
local function text(parent, size, c, justify)
  local fs = parent:CreateFontString(nil, "OVERLAY")
  fs:SetFont(G.BF(), size or 12, "")
  fs:SetTextColor((c or P.text)[1], (c or P.text)[2], (c or P.text)[3])
  fs:SetJustifyH(justify or "LEFT")
  fs:SetShadowOffset(1, -1)
  return fs
end
local function qualityColor(q)
  local c = ITEM_QUALITY_COLORS and ITEM_QUALITY_COLORS[q or 1]
  if c then return { c.r, c.g, c.b } end
  return P.text
end

-- ---------- historia cen (Auctionator) ----------
-- klucz Auctionatora: towary po itemID, sprzet po „g:itemID:poziom przedmiotu”
local function history(key)
  local out = {}
  pcall(function()
    local list = Auctionator.Database:GetPriceHistory(tostring(key.itemID))
    if (not list or #list == 0) and (key.itemLevel or 0) > 0 then
      list = Auctionator.Database:GetPriceHistory("g:" .. key.itemID .. ":" .. key.itemLevel)
    end
    for i = 1, math.min(7, #(list or {})) do out[#out + 1] = list[i].minSeen end -- od najnowszego
  end)
  return out
end
local function avgOf(h)
  if #h == 0 then return nil end
  local s = 0
  for _, v in ipairs(h) do s = s + v end
  return math.floor(s / #h)
end

-- ---------- listy bez zapytania: do poradnika i na sprzedaz ----------
local function itemRow(id, extra)
  local name, _, quality, _, _, _, _, _, _, icon = C_Item.GetItemInfo(id)
  local key = (C_AuctionHouse.MakeItemKey and C_AuctionHouse.MakeItemKey(id)) or { itemID = id, itemLevel = 0, itemSuffix = 0 }
  local h = history(key)
  local r = { key = key, itemID = id, name = name or C_Item.GetItemNameByID(id), quality = quality, icon = icon or C_Item.GetItemIconByID(id),
    commodity = true, avg = avgOf(h), hist = h, price = h[1] }
  for k, v in pairs(extra or {}) do r[k] = v end
  return r
end
local function guideList()
  local out = {}
  local ok, list = pcall(function() return G.psNeededCounts and G.psNeededCounts() or {} end)
  for _, n in ipairs(ok and list or {}) do
    local miss = n.need - (C_Item.GetItemCount(n.id, true) or 0)
    if miss > 0 then out[#out + 1] = itemRow(n.id, { qty = miss, miss = miss, why = n.why }) end
  end
  table.sort(out, function(a, b) return (a.name or "") < (b.name or "") end)
  return out
end
local function sellList()
  local by, out = {}, {}
  for bag = 0, NUM_BAG_SLOTS or 4 do
    for slot = 1, C_Container.GetContainerNumSlots(bag) or 0 do
      local it = C_Container.GetContainerItemInfo(bag, slot)
      if it and it.itemID and not it.isBound then
        local _, _, _, _, _, classID = C_Item.GetItemInfoInstant(it.itemID)
        if classID == E.Tradegoods and not (G.itemNeed and G.itemNeed(it.itemID)) and not (G.itemMark and G.itemMark(it.itemID) == "fav") then
          local r = by[it.itemID]
          if not r then r = itemRow(it.itemID, { qty = 0, bag = bag, slot = slot }) by[it.itemID] = r out[#out + 1] = r end
          r.qty = r.qty + (it.stackCount or 1)
        end
      end
    end
  end
  table.sort(out, function(a, b) return (a.price or 0) * a.qty > (b.price or 0) * b.qty end)
  return out
end

-- ---------- zapytania (z kolejka przy zdlawieniu) ----------
local queued
local function send(fn)
  if C_AuctionHouse.IsThrottledMessageSystemReady and not C_AuctionHouse.IsThrottledMessageSystemReady() then
    queued = fn
    return
  end
  queued = nil
  pcall(fn)
end

local SORT = { { sortOrder = (Enum.AuctionHouseSortOrder and Enum.AuctionHouseSortOrder.Price) or 0, reverseSort = false } }
local refresh, showReopen -- forward
local function browse()
  S.results, S.sel, S.offset, S.offers, S.confirm = {}, nil, 0, {}, nil
  if S.mode == "sell" or CATS[S.cat].special then
    S.waiting = false
    local ok, list = pcall(S.mode == "sell" and sellList or guideList)
    S.results = ok and list or {}
    refresh()
    return
  end
  S.waiting = true
  send(function()
    C_AuctionHouse.SendBrowseQuery({ searchString = S.text or "", sorts = SORT, filters = {}, itemClassFilters = CATS[S.cat][2] })
  end)
  refresh()
end

local function readBrowse()
  local list = {}
  for _, r in ipairs(C_AuctionHouse.GetBrowseResults() or {}) do
    local info = C_AuctionHouse.GetItemKeyInfo(r.itemKey)
    local h = history(r.itemKey)
    local avg = avgOf(h)
    list[#list + 1] = { key = r.itemKey, itemID = r.itemKey.itemID, price = r.minPrice, qty = r.totalQuantity,
      name = info and info.itemName, quality = info and info.quality, icon = info and info.iconFileID,
      commodity = info and info.isCommodity, avg = avg, hist = h }
  end
  table.sort(list, function(a, b) return (a.price or 0) < (b.price or 0) end)
  S.results = list
  S.waiting = false
end

local function search(r)
  S.offers, S.confirm, S.qty = {}, nil, 1
  pcall(C_AuctionHouse.CancelCommoditiesPurchase)
  send(function() C_AuctionHouse.SendSearchQuery(r.key, SORT, false) end)
end

local function readCommodity(itemID)
  local r = S.sel and S.results[S.sel]
  if not r or r.itemID ~= itemID then return end
  local out = {} -- do 100 ofert: koszt wiekszej ilosci; na ekranie 6 pierwszych
  for i = 1, math.min(100, C_AuctionHouse.GetNumCommoditySearchResults(itemID) or 0) do
    local o = C_AuctionHouse.GetCommoditySearchResultInfo(itemID, i)
    if o then out[#out + 1] = { unit = o.unitPrice, qty = o.quantity, own = o.containsOwnerItem } end
  end
  S.offers = out
  r.commodity = true
  if S.mode ~= "sell" then S.max = C_AuctionHouse.GetCommoditySearchResultsQuantity and C_AuctionHouse.GetCommoditySearchResultsQuantity(itemID) or 1 end
end

local function readItems(itemKey)
  local r = S.sel and S.results[S.sel]
  if not r then return end
  local out = {}
  for i = 1, math.min(6, C_AuctionHouse.GetNumItemSearchResults(r.key) or 0) do
    local o = C_AuctionHouse.GetItemSearchResultInfo(r.key, i)
    if o and o.buyoutAmount then out[#out + 1] = { unit = o.buyoutAmount, qty = o.quantity or 1, auctionID = o.auctionID, own = o.containsOwnerItem } end
  end
  table.sort(out, function(a, b) return a.unit < b.unit end)
  S.offers = out
  r.commodity = false
end

-- koszt kupna qty sztuk towaru z najtanszych ofert
local function commodityCost(qty)
  local left, total = qty, 0
  for _, o in ipairs(S.offers) do
    local take = math.min(left, o.qty)
    total, left = total + take * o.unit, left - take
    if left <= 0 then break end
  end
  return left <= 0 and total or nil
end

-- ---------- kupno: pierwsze klikniecie pokazuje cene, drugie kupuje ----------
local function buyClick()
  local r = S.sel and S.results[S.sel]
  if not r or not S.offers[1] then return end
  if r.commodity then
    if S.confirm and S.confirm.ready then
      pcall(C_AuctionHouse.ConfirmCommoditiesPurchase, r.itemID, S.qty)
      S.confirm = nil
    else
      local c = { ready = false }
      S.confirm = c
      pcall(C_AuctionHouse.StartCommoditiesPurchase, r.itemID, S.qty)
      -- bez odpowiedzi serwera przycisk nie moze utknac na „sprawdzam cene”
      C_Timer.After(5, function()
        if S.confirm == c and not c.ready then
          S.confirm = nil
          pcall(C_AuctionHouse.CancelCommoditiesPurchase)
          if refresh then pcall(refresh) end
        end
      end)
    end
  else
    local o = S.offers[1]
    if S.confirm and S.confirm.ready then
      pcall(C_AuctionHouse.PlaceBid, o.auctionID, o.unit)
      S.confirm = nil
      C_Timer.After(1, function() if frame and frame:IsShown() and S.sel then search(S.results[S.sel]) refresh() end end)
    else
      S.confirm = { ready = true, total = o.unit }
    end
  end
  refresh()
end

-- ---------- wystawianie (zakladka Sprzedaj): pierwsze klikniecie pokazuje wadium, drugie wystawia ----------
local function postPrice(it)
  local o = S.offers[1]
  if o then return o.own and o.unit or math.max(1, o.unit - 1) end
  return it and it.price
end
local function postClick()
  local it = S.sel and S.results[S.sel]
  if not (it and it.bag) then return end
  if it.commodity == false then say("Rynek: ten przedmiot wystaw w Auctionatorze (nie jest towarem).") return end
  local unit = postPrice(it)
  if not unit then return end
  if S.confirm and S.confirm.post then
    local loc = ItemLocation:CreateFromBagAndSlot(it.bag, it.slot)
    local ok, needs = pcall(C_AuctionHouse.PostCommodity, loc, 2, S.qty, S.confirm.unit)
    if ok and needs and C_AuctionHouse.ConfirmPostCommodity then pcall(C_AuctionHouse.ConfirmPostCommodity, loc, 2, S.qty, S.confirm.unit) end
    if not ok then say("Rynek: gra nie przyjęła wystawienia.") end
    S.confirm = nil
  else
    local dep
    pcall(function() dep = C_AuctionHouse.CalculateCommodityDeposit(it.itemID, 2, S.qty) end)
    S.confirm = { post = true, unit = unit, dep = dep }
  end
  refresh()
end

-- ---------- budowa okna ----------
local catButtons, rowFrames = {}, {}
local D = {} -- elementy panelu szczegolow

local function build()
  palette()
  frame = CreateFrame("Frame", "GrimuarRynekFrame", UIParent)
  frame:SetSize(W, H)
  frame:SetFrameStrata("HIGH")
  frame:SetToplevel(true)
  frame:EnableMouse(true)
  frame:SetMovable(true)
  frame:SetClampedToScreen(true)
  tex(frame, "BACKGROUND", P.panel, -8):SetAllPoints()
  edge(frame, P.edge)
  tinsert(UISpecialFrames, "GrimuarRynekFrame")
  -- Esc, „Zwykly dom aukcyjny” albo x: nad oknem gry zostaje przycisk „Rynek”
  frame:SetScript("OnHide", function()
    if _G.AuctionHouseFrame then pcall(AuctionHouseFrame.SetAlpha, AuctionHouseFrame, 1) end
    if showReopen and _G.AuctionHouseFrame and AuctionHouseFrame:IsShown() then pcall(showReopen, true) end
  end)

  -- pasek tytulu
  local bar = CreateFrame("Frame", nil, frame)
  bar:SetPoint("TOPLEFT") bar:SetPoint("TOPRIGHT") bar:SetHeight(32)
  tex(bar, "BACKGROUND", { 0, 0, 0, 0.25 }, -7):SetAllPoints()
  local line = tex(bar, "BORDER", P.edge, 6) line:SetPoint("BOTTOMLEFT") line:SetPoint("BOTTOMRIGHT") line:SetHeight(1)
  bar:EnableMouse(true)
  bar:RegisterForDrag("LeftButton")
  bar:SetScript("OnDragStart", function() frame:StartMoving() end)
  bar:SetScript("OnDragStop", function() frame:StopMovingOrSizing() end)
  local title = text(bar, 15, P.accent)
  title:SetFont(G.TF(), 15, "")
  title:SetPoint("LEFT", 12, 0)
  title:SetText("Rynek")
  local function tabBtn(label, x, on, fn)
    local b = CreateFrame("Button", nil, bar)
    b:SetSize(90, 22)
    b:SetPoint("LEFT", x, 0)
    tex(b, "BACKGROUND", on and { P.accent[1], P.accent[2], P.accent[3], 0.14 } or P.row, -6):SetAllPoints()
    edge(b, P.edge)
    local t = text(b, 12, on and P.accent or P.muted, "CENTER")
    t:SetAllPoints()
    t:SetText(label)
    b.t = t
    if fn then b:SetScript("OnClick", fn) end
    return b
  end
  D.tabBuy = tabBtn("Kupuj", 80, true, function() S.mode = "buy" browse() end)
  D.tabSell = tabBtn("Sprzedaj", 174, false, function() S.mode = "sell" browse() end)
  tabBtn("Zwykły dom aukcyjny", 268, false, function() frame:Hide() end):SetWidth(150)
  D.wallet = text(bar, 12, P.muted, "RIGHT")
  D.wallet:SetPoint("RIGHT", -36, 0)
  local close = CreateFrame("Button", nil, bar)
  close:SetSize(22, 22)
  close:SetPoint("RIGHT", -6, 0)
  local cx = text(close, 14, P.muted, "CENTER") cx:SetAllPoints() cx:SetText("x")
  -- zamyka caly dom aukcyjny (gra sama chowa swoje okno po AUCTION_HOUSE_CLOSED)
  close:SetScript("OnClick", function() frame:Hide() pcall(C_AuctionHouse.CloseAuctionHouse) end)

  -- lewa kolumna: szukanie i kategorie
  local left = CreateFrame("Frame", nil, frame)
  left:SetPoint("TOPLEFT", 0, -32) left:SetPoint("BOTTOMLEFT") left:SetWidth(LEFT_W)
  local lsep = tex(left, "BORDER", P.edge, 6) lsep:SetPoint("TOPRIGHT") lsep:SetPoint("BOTTOMRIGHT") lsep:SetWidth(1)
  local box = CreateFrame("EditBox", nil, left)
  box:SetSize(LEFT_W - 16, 24)
  box:SetPoint("TOPLEFT", 8, -8)
  box:SetAutoFocus(false)
  box:SetFont(G.BF(), 12, "")
  box:SetTextInsets(6, 6, 0, 0)
  tex(box, "BACKGROUND", P.inner, -6):SetAllPoints()
  edge(box, P.edge)
  local hint = text(box, 12, P.muted) hint:SetPoint("LEFT", 6, 0) hint:SetText("szukaj na rynku...")
  box:SetScript("OnTextChanged", function(self) hint:SetShown(self:GetText() == "") end)
  box:SetScript("OnEnterPressed", function(self) S.text = self:GetText() self:ClearFocus() browse() end)
  box:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
  for i, c in ipairs(CATS) do
    local b = CreateFrame("Button", nil, left)
    b:SetSize(LEFT_W - 16, 22)
    b:SetPoint("TOPLEFT", 8, -40 - (i - 1) * 24)
    b.bg = tex(b, "BACKGROUND", { 0, 0, 0, 0 }, -6) b.bg:SetAllPoints()
    b.t = text(b, 12, c[3] and P.muted or P.text)
    b.t:SetPoint("LEFT", c[3] and 22 or 8, 0)
    b.t:SetText(c[1])
    b:SetScript("OnClick", function() S.cat = i S.mode = "buy" browse() end)
    catButtons[i] = b
  end

  -- srodek: lista
  local mid = CreateFrame("Frame", nil, frame)
  mid:SetPoint("TOPLEFT", LEFT_W, -32) mid:SetPoint("BOTTOMRIGHT", -RIGHT_W, 0)
  local rsep = tex(mid, "BORDER", P.edge, 6) rsep:SetPoint("TOPRIGHT") rsep:SetPoint("BOTTOMRIGHT") rsep:SetWidth(1)
  local head = CreateFrame("Frame", nil, mid)
  head:SetPoint("TOPLEFT") head:SetPoint("TOPRIGHT") head:SetHeight(28)
  local hl = tex(head, "BORDER", P.edge, 6) hl:SetPoint("BOTTOMLEFT") hl:SetPoint("BOTTOMRIGHT") hl:SetHeight(1)
  local COLS = { { "Przedmiot", 48, "LEFT" }, { "Najtaniej", X_PRICE, "RIGHT" }, { "Sztuk", X_QTY, "RIGHT" },
    { "Średnio 7 dni", X_AVG, "RIGHT" }, { "Trend", X_TREND, "RIGHT" } }
  for _, c in ipairs(COLS) do
    local t = text(head, 11, c[1] == "Najtaniej" and P.accent or P.muted, c[3]) -- zloty naglowek: lista od najtanszych
    if c[3] == "LEFT" then t:SetPoint("LEFT", c[2], 0) else t:SetPoint("RIGHT", head, "LEFT", c[2], 0) end
    t:SetText(c[1])
  end
  for i = 1, ROWS do
    local r = CreateFrame("Button", nil, mid)
    r:SetPoint("TOPLEFT", 0, -28 - (i - 1) * ROW_H) r:SetPoint("TOPRIGHT", 0, -28 - (i - 1) * ROW_H) r:SetHeight(ROW_H)
    r.bg = tex(r, "BACKGROUND", (i % 2 == 0) and P.rowAlt or P.row, -6) r.bg:SetAllPoints()
    r.selbg = tex(r, "BACKGROUND", { P.accent[1], P.accent[2], P.accent[3], 0.14 }, -5) r.selbg:SetAllPoints() r.selbg:Hide()
    r.selbar = tex(r, "BORDER", P.accent, 5) r.selbar:SetPoint("TOPLEFT") r.selbar:SetPoint("BOTTOMLEFT") r.selbar:SetWidth(2) r.selbar:Hide()
    local hlt = r:CreateTexture(nil, "HIGHLIGHT") hlt:SetAllPoints() hlt:SetColorTexture(1, 1, 1, 0.04)
    r.icon = r:CreateTexture(nil, "ARTWORK") r.icon:SetSize(30, 30) r.icon:SetPoint("LEFT", 10, 0) r.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    r.name = text(r, 13) r.name:SetPoint("LEFT", 48, 0) r.name:SetWidth(NAME_W) r.name:SetWordWrap(false)
    r.price = text(r, 12, nil, "RIGHT") r.price:SetPoint("RIGHT", r, "LEFT", X_PRICE, 0)
    r.qty = text(r, 12, P.muted, "RIGHT") r.qty:SetPoint("RIGHT", r, "LEFT", X_QTY, 0)
    r.avg = text(r, 12, P.muted, "RIGHT") r.avg:SetPoint("RIGHT", r, "LEFT", X_AVG, 0)
    r.trend = text(r, 12, P.muted, "RIGHT") r.trend:SetPoint("RIGHT", r, "LEFT", X_TREND, 0)
    r:SetScript("OnClick", function(self)
      if not self.index then return end
      S.sel = self.index
      local it = S.results[S.sel]
      search(it)
      -- do poradnika: od razu brakujaca ilosc; sprzedaz: wszystko z toreb
      if it.miss then S.qty = it.miss end
      if S.mode == "sell" then S.qty, S.max = it.qty, it.qty end
      refresh()
    end)
    r:SetScript("OnEnter", function(self)
      local it = self.index and S.results[self.index]
      if not it then return end
      GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
      if GameTooltip.SetItemKey then pcall(GameTooltip.SetItemKey, GameTooltip, it.key.itemID, it.key.itemLevel or 0, it.key.itemSuffix or 0)
      else GameTooltip:SetItemByID(it.itemID) end
      GameTooltip:Show()
    end)
    r:SetScript("OnLeave", function() GameTooltip:Hide() end)
    rowFrames[i] = r
  end
  mid:EnableMouseWheel(true)
  mid:SetScript("OnMouseWheel", function(_, delta)
    S.offset = math.max(0, math.min(#S.results - ROWS, S.offset - delta * 3))
    refresh()
  end)
  D.status = text(mid, 11, P.muted)
  D.status:SetPoint("BOTTOMLEFT", 10, 8)
  D.source = text(mid, 11, P.muted, "RIGHT")
  D.source:SetPoint("BOTTOMRIGHT", -10, 8)
  D.source:SetText("średnia i trend z historii Auctionatora")

  -- prawa: szczegoly
  local right = CreateFrame("Frame", nil, frame)
  right:SetPoint("TOPRIGHT", 0, -32) right:SetPoint("BOTTOMRIGHT") right:SetWidth(RIGHT_W)
  D.icon = right:CreateTexture(nil, "ARTWORK") D.icon:SetSize(46, 46) D.icon:SetPoint("TOPLEFT", 12, -12) D.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
  D.name = text(right, 15) D.name:SetPoint("TOPLEFT", 66, -14) D.name:SetWidth(RIGHT_W - 78) D.name:SetWordWrap(false)
  D.sub = text(right, 11, P.muted) D.sub:SetPoint("TOPLEFT", 66, -36) D.sub:SetWidth(RIGHT_W - 78)
  local function boxAt(y, h, label)
    local b = CreateFrame("Frame", nil, right)
    b:SetPoint("TOPLEFT", 12, y) b:SetPoint("TOPRIGHT", -12, y) b:SetHeight(h)
    tex(b, "BACKGROUND", P.inner, -6):SetAllPoints()
    edge(b, P.edge)
    local t = text(b, 10, P.accent) t:SetPoint("TOPLEFT", 8, -6) t:SetText(label)
    return b
  end
  local offersBox = boxAt(-70, 132, "NAJTAŃSZE OFERTY")
  D.offerLines = {}
  for i = 1, 6 do
    local l = text(offersBox, 12) l:SetPoint("TOPLEFT", 8, -22 - (i - 1) * 17) l:SetWidth(RIGHT_W - 40)
    local rr = text(offersBox, 12, nil, "RIGHT") rr:SetPoint("TOPRIGHT", -8, -22 - (i - 1) * 17)
    D.offerLines[i] = { l, rr }
  end
  local histBox = boxAt(-210, 110, "CENA Z 7 DNI")
  D.bars = {}
  for i = 1, 7 do
    local b = tex(histBox, "ARTWORK", P.accent, 1)
    b:SetWidth(24)
    b:SetPoint("BOTTOMLEFT", 12 + (i - 1) * 36, 24)
    D.bars[i] = b
  end
  D.avgLine = text(histBox, 11, P.muted) D.avgLine:SetPoint("BOTTOMLEFT", 8, 6)
  -- ilosc i kupno
  local qtyFrame = CreateFrame("Frame", nil, right)
  qtyFrame:SetPoint("TOPLEFT", 12, -332) qtyFrame:SetSize(96, 28)
  tex(qtyFrame, "BACKGROUND", P.inner, -6):SetAllPoints() edge(qtyFrame, P.edge)
  local function qbtn(label, x, d)
    local b = CreateFrame("Button", nil, qtyFrame) b:SetSize(28, 28) b:SetPoint("LEFT", x, 0)
    local t = text(b, 14, P.text, "CENTER") t:SetAllPoints() t:SetText(label)
    b:SetScript("OnClick", function()
      S.qty = math.max(1, math.min(S.max or 1, S.qty + d))
      S.confirm = nil
      pcall(C_AuctionHouse.CancelCommoditiesPurchase)
      refresh()
    end)
  end
  qbtn("-", 0, -1) qbtn("+", 68, 1)
  D.qty = text(qtyFrame, 13, P.text, "CENTER") D.qty:SetPoint("CENTER")
  D.qtyFrame = qtyFrame
  local buy = CreateFrame("Button", nil, right)
  buy:SetPoint("TOPLEFT", 116, -332) buy:SetPoint("TOPRIGHT", -12, -332) buy:SetHeight(28)
  buy.bg = tex(buy, "BACKGROUND", P.accent, -6) buy.bg:SetAllPoints() edge(buy, P.edge)
  buy.t = text(buy, 13, { 0.1, 0.08, 0.03 }, "CENTER") buy.t:SetAllPoints()
  buy:SetScript("OnClick", function() if S.mode == "sell" then postClick() else buyClick() end end)
  D.buy = buy
  D.note = text(right, 11, P.muted) D.note:SetPoint("TOPLEFT", 12, -368) D.note:SetWidth(RIGHT_W - 24)
  frame:Hide()
end

-- ---------- odswiezanie ----------
refresh = function()
  if not frame then return end
  D.wallet:SetText("masz " .. money(GetMoney()) .. "   torby wolne: " .. (G.freeBagSlots and G.freeBagSlots() or "?"))
  for _, tb in ipairs({ { D.tabBuy, S.mode ~= "sell" }, { D.tabSell, S.mode == "sell" } }) do
    local c = tb[2] and P.accent or P.muted
    if tb[1] and tb[1].t then tb[1].t:SetTextColor(c[1], c[2], c[3]) end
  end
  for i, b in ipairs(catButtons) do
    local on = i == S.cat and S.mode ~= "sell"
    b.bg:SetColorTexture(P.accent[1], P.accent[2], P.accent[3], on and 0.14 or 0)
    b.t:SetTextColor((on and P.accent or (CATS[i][3] and P.muted or P.text))[1], (on and P.accent or (CATS[i][3] and P.muted or P.text))[2], (on and P.accent or (CATS[i][3] and P.muted or P.text))[3])
  end
  for i, r in ipairs(rowFrames) do
    local idx = S.offset + i
    local it = S.results[idx]
    r.index = it and idx or nil
    if it then
      r.icon:SetTexture(it.icon) r.icon:Show()
      local q = qualityColor(it.quality)
      r.name:SetText(it.name or ("#" .. it.itemID)) r.name:SetTextColor(q[1], q[2], q[3])
      r.price:SetText(it.price and money(it.price) or "–")
      r.qty:SetText(it.qty or "")
      r.avg:SetText(it.avg and money(it.avg) or "-")
      if it.avg and it.avg > 0 and it.price and #(it.hist or {}) >= 2 then -- z 1 dnia srednia = dzisiejsza cena
        local pct = math.floor((it.price - it.avg) / it.avg * 100 + 0.5)
        r.trend:SetText((pct > 0 and "+" or "") .. pct .. "%")
        if pct > 2 then r.trend:SetTextColor(0.91, 0.48, 0.4) elseif pct < -2 then r.trend:SetTextColor(0.44, 0.82, 0.49) else r.trend:SetTextColor(P.muted[1], P.muted[2], P.muted[3]) end
      else
        r.trend:SetText("")
      end
      r.selbg:SetShown(idx == S.sel) r.selbar:SetShown(idx == S.sel)
      r:Show()
    else
      r:Hide()
    end
  end
  if S.mode == "sell" then
    D.status:SetText(#S.results .. " materiałów na sprzedaż (bez ◆ potrzebnych i ulubionych)")
    D.source:SetText("cena: ostatni skan Auctionatora · liczba: w torbach")
  elseif CATS[S.cat].special then
    D.status:SetText(#S.results == 0 and "masz wszystko do poradników profesji" or (#S.results .. " brakuje do poradników profesji"))
    D.source:SetText("cena: ostatni skan Auctionatora · liczba: ile brakuje")
  else
    D.status:SetText(S.waiting and "szukam..." or (#S.results .. " przedmiotów"))
    D.source:SetText("średnia i trend z historii Auctionatora")
  end
  -- szczegoly
  local it = S.sel and S.results[S.sel]
  D.icon:SetShown(it ~= nil)
  if not it then
    D.name:SetText("Wybierz przedmiot z listy") D.name:SetTextColor(P.muted[1], P.muted[2], P.muted[3])
    D.sub:SetText("")
    for _, l in ipairs(D.offerLines) do l[1]:SetText("") l[2]:SetText("") end
    for _, b in ipairs(D.bars) do b:Hide() end
    D.avgLine:SetText("") D.buy:Hide() D.qtyFrame:Hide() D.note:SetText("")
    return
  end
  D.icon:SetTexture(it.icon)
  local q = qualityColor(it.quality)
  D.name:SetText(it.name or "?") D.name:SetTextColor(q[1], q[2], q[3])
  local _, _, _, _, minLevel, itype, isub = C_Item.GetItemInfo(it.itemID)
  D.sub:SetText((isub or itype or "") .. ((minLevel and minLevel > 1) and (" · od " .. minLevel .. " poziomu") or ""))
  for i, l in ipairs(D.offerLines) do
    local o = S.offers[i]
    if o then
      l[1]:SetText((i == 1 and "najtaniej" or ("oferta " .. i)) .. (it.commodity and ("  ·  " .. o.qty .. " szt.") or "") .. (o.own and "  (Twoja)" or ""))
      l[2]:SetText(money(o.unit))
      local c = i == 1 and P.accent or P.text
      l[1]:SetTextColor(c[1], c[2], c[3])
    else
      l[1]:SetText(i == 1 and "czekam na oferty..." or "") l[2]:SetText("")
      l[1]:SetTextColor(P.muted[1], P.muted[2], P.muted[3])
    end
  end
  local h = it.hist or {}
  local maxv = 1
  for _, v in ipairs(h) do maxv = math.max(maxv, v) end
  for i, b in ipairs(D.bars) do
    local v = h[#h - i + 1] -- od najstarszego do najnowszego
    if v then b:SetHeight(math.max(2, 60 * v / maxv)) b:Show() else b:Hide() end
  end
  D.avgLine:SetText(#h > 0 and ("średnio " .. money(it.avg or 0) .. "  (" .. #h .. (#h == 1 and " dzień, trend od 2 dni)" or " dni)")) or "brak historii: zrób skan w Auctionatorze")
  if S.mode == "sell" then
    D.qtyFrame:Show()
    D.qty:SetText(S.qty)
    D.buy:Show()
    local unit = postPrice(it)
    if S.confirm and S.confirm.post then
      D.buy.t:SetText("Potwierdź: " .. S.qty .. " × " .. money(S.confirm.unit)) D.buy:Enable()
    elseif unit then
      D.buy.t:SetText("Wystaw " .. S.qty .. " × " .. money(unit)) D.buy:Enable()
    else
      D.buy.t:SetText("brak ceny: zrób skan w Auctionatorze") D.buy:Disable()
    end
    D.buy.bg:SetAlpha(D.buy:IsEnabled() and 1 or 0.35)
    D.note:SetText((S.confirm and S.confirm.post) and ("Wadium " .. money(S.confirm.dep or 0) .. ", aukcja na 24 h. Drugie kliknięcie wystawia.")
      or "Cena: najtańsza oferta minus 1 miedziak (Twoja najtańsza: ta sama). Pierwsze kliknięcie pokazuje wadium.")
    return
  end
  if it.why then D.sub:SetText("◆ " .. it.why) end
  -- kupno
  D.qtyFrame:SetShown(it.commodity == true)
  D.qty:SetText(S.qty)
  local cost = it.commodity and commodityCost(S.qty) or (S.offers[1] and S.offers[1].unit)
  if S.confirm and S.confirm.ready then cost = S.confirm.total or cost end
  D.buy:Show()
  local canPay = cost and GetMoney() >= cost
  if not S.offers[1] then
    D.buy.t:SetText("czekam na oferty") D.buy:Disable()
  elseif S.confirm and not S.confirm.ready then
    D.buy.t:SetText("sprawdzam cenę...") D.buy:Disable()
  elseif S.confirm and S.confirm.ready then
    D.buy.t:SetText("Potwierdź: " .. money(cost)) D.buy:SetEnabled(canPay)
  else
    D.buy.t:SetText("Kup za " .. (cost and money(cost) or "?")) D.buy:SetEnabled(canPay and true or false)
  end
  D.buy.bg:SetAlpha(D.buy:IsEnabled() and 1 or 0.35)
  D.note:SetText(not canPay and cost and ("Za mało pieniędzy: masz " .. money(GetMoney()) .. ".") or
    "Pierwsze kliknięcie pokazuje dokładną cenę, drugie kupuje.")
end

-- ---------- zdarzenia ----------
local ev = CreateFrame("Frame")
for _, e in ipairs({ "AUCTION_HOUSE_SHOW", "AUCTION_HOUSE_CLOSED", "AUCTION_HOUSE_BROWSE_RESULTS_UPDATED",
  "AUCTION_HOUSE_BROWSE_RESULTS_ADDED", "ITEM_KEY_ITEM_INFO_RECEIVED", "COMMODITY_SEARCH_RESULTS_UPDATED",
  "ITEM_SEARCH_RESULTS_UPDATED", "COMMODITY_PRICE_UPDATED", "COMMODITY_PRICE_UNAVAILABLE", "COMMODITY_PURCHASE_SUCCEEDED",
  "COMMODITY_PURCHASE_FAILED", "AUCTION_HOUSE_THROTTLED_SYSTEM_READY", "PLAYER_MONEY", "BAG_UPDATE_DELAYED",
  "AUCTION_HOUSE_AUCTION_CREATED" }) do
  pcall(ev.RegisterEvent, ev, e)
end
-- maly przycisk „Rynek” nad zwyklym domem aukcyjnym (powrot po „Zwykly dom aukcyjny”); dziecko UIParent, wiec
-- Plaskie.lua go nie wygladza, a my nie ruszamy okna Blizzarda
local reopen
showReopen = function(on)
  if not reopen then
    reopen = CreateFrame("Button", nil, UIParent)
    reopen:SetSize(80, 22)
    reopen:SetFrameStrata("HIGH")
    local c = fss() and { 0.95, 0.76, 0.35 } or { 0.85, 0.71, 0.36 }
    local bg = reopen:CreateTexture(nil, "BACKGROUND") bg:SetAllPoints() bg:SetColorTexture(c[1], c[2], c[3], 1)
    local t = reopen:CreateFontString(nil, "OVERLAY") t:SetFont(G.BF(), 12, "") t:SetTextColor(0.1, 0.08, 0.03) t:SetAllPoints() t:SetText("Rynek")
    reopen:SetScript("OnClick", function() if frame then frame:Show() reopen:Hide() browse() end end)
  end
  reopen:ClearAllPoints()
  if _G.AuctionHouseFrame then reopen:SetPoint("BOTTOMRIGHT", AuctionHouseFrame, "TOPRIGHT", 0, 2) else reopen:SetPoint("TOP", 0, -80) end
  reopen:SetShown(on)
end

local function openMarket()
  if not frame then
    local ok, err = pcall(build)
    if not ok then
      say("Rynek: nie udało się zbudować okna (" .. tostring(err) .. "). Działa zwykły dom aukcyjny.")
      if frame then frame:Hide() end
      frame = nil
      return
    end
  end
  frame:ClearAllPoints()
  if _G.AuctionHouseFrame then frame:SetPoint("TOPLEFT", AuctionHouseFrame, "TOPLEFT", 0, 0) else frame:SetPoint("CENTER") end
  frame:Show()
  -- 14.11 (zrzut gracza): napisy okna gry przeswitywaly spod Rynku → okno gry niewidoczne, dopoki Rynek jest otwarty
  -- (sama przezroczystosc: okno dalej dziala, Auctionator tez; po zamknieciu Rynku wraca alfa 1)
  if _G.AuctionHouseFrame then pcall(AuctionHouseFrame.SetAlpha, AuctionHouseFrame, 0) end
  showReopen(false)
  S.mode = "buy"
  local okG, need = pcall(guideList)
  S.cat = (okG and #need > 0) and 1 or 2
  browse()
end

ev:SetScript("OnEvent", function(_, e, a1, a2)
  if e == "AUCTION_HOUSE_SHOW" then
    if GrimuarSetupDB.rynekOff then return end
    -- chwila zwloki: okno gry laduje sie na zadanie i wysyla wlasne pierwsze wyszukiwanie; nasze ma byc po nim
    C_Timer.After(0.3, function() if _G.AuctionHouseFrame and AuctionHouseFrame:IsShown() then pcall(openMarket) end end)
    return
  end
  if not frame then return end
  if e == "AUCTION_HOUSE_CLOSED" then
    pcall(C_AuctionHouse.CancelCommoditiesPurchase)
    frame:Hide()
    showReopen(false)
  elseif e == "AUCTION_HOUSE_THROTTLED_SYSTEM_READY" then
    if queued then local fn = queued queued = nil pcall(fn) end
  elseif (e == "AUCTION_HOUSE_BROWSE_RESULTS_UPDATED" or e == "AUCTION_HOUSE_BROWSE_RESULTS_ADDED" or e == "ITEM_KEY_ITEM_INFO_RECEIVED")
    and (S.mode == "sell" or CATS[S.cat].special) then
    -- nasze listy nie czekaja na przegladanie (wyniki zapytan okna gry pomijamy)
  elseif e == "AUCTION_HOUSE_AUCTION_CREATED" then
    say("Rynek: wystawione.")
    if S.mode == "sell" then browse() end
  elseif e == "BAG_UPDATE_DELAYED" and S.mode == "sell" and not S.confirm then
    local keepID = S.sel and S.results[S.sel] and S.results[S.sel].itemID
    local ok, list = pcall(sellList)
    if ok then
      S.results = list
      S.sel = nil
      for i, r in ipairs(list) do if r.itemID == keepID then S.sel = i S.qty, S.max = math.min(S.qty, r.qty), r.qty end end
    end
  elseif e == "AUCTION_HOUSE_BROWSE_RESULTS_UPDATED" or e == "AUCTION_HOUSE_BROWSE_RESULTS_ADDED" or e == "ITEM_KEY_ITEM_INFO_RECEIVED" then
    local keep = S.sel and S.results[S.sel] and S.results[S.sel].itemID
    pcall(readBrowse)
    S.sel = nil
    if keep then for i, r in ipairs(S.results) do if r.itemID == keep then S.sel = i end end end
  elseif e == "COMMODITY_SEARCH_RESULTS_UPDATED" then
    pcall(readCommodity, a1)
  elseif e == "ITEM_SEARCH_RESULTS_UPDATED" then
    pcall(readItems, a1)
  elseif e == "COMMODITY_PRICE_UPDATED" then
    if S.confirm then S.confirm.ready, S.confirm.total = true, a2 or (a1 and a1 * S.qty) end
  elseif e == "COMMODITY_PRICE_UNAVAILABLE" then
    S.confirm = nil
    say("Rynek: cena się zmieniła, odświeżam oferty.")
    if S.sel then search(S.results[S.sel]) end
  elseif e == "COMMODITY_PURCHASE_SUCCEEDED" then
    say("Rynek: kupione.")
    if S.sel then search(S.results[S.sel]) end
  elseif e == "COMMODITY_PURCHASE_FAILED" then
    S.confirm = nil
    say("Rynek: zakup się nie udał (ktoś był szybszy albo zabrakło pieniędzy).")
  end
  if frame:IsShown() then pcall(refresh) end
end)

SLASH_GRIMUARRYNEK1 = "/rynek"
SlashCmdList["GRIMUARRYNEK"] = function()
  GrimuarSetupDB.rynekOff = not GrimuarSetupDB.rynekOff
  say(GrimuarSetupDB.rynekOff and "Rynek wyłączony: dom aukcyjny otwiera się po staremu. /rynek włącza." or "Rynek włączony: otworzy się przy aukcjonerze.")
  if not GrimuarSetupDB.rynekOff and _G.AuctionHouseFrame and AuctionHouseFrame:IsShown() then pcall(openMarket) end
  if GrimuarSetupDB.rynekOff then
    if frame then frame:Hide() end
    if reopen then reopen:Hide() end
  end
end

G.rynekRefresh = function() if frame and frame:IsShown() then pcall(refresh) end end
