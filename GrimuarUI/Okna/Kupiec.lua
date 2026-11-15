-- Grimuar UI: Kupiec w stylu huba (15.11, plan R29 etap 2, makieta „Okna Grimuara”: Kupiec). Zamiast okna kupca
-- ForeverSkin (ForeverSkinMerchantFrame) albo gry (MerchantFrame), przyczepione i wieksze, wiec je przykrywa (Okna/Wspolne.lua).
-- * lewo: towar w zakladkach „Dla buildu” (potrzebne do poradnika profesji Polestara, jedzenie i picie, reagenty, amunicja,
--   wieksze torby; z powodem i „masz N”), „Wszystko” i „Odkup”; klik = kup 1, Shift+klik = caly stos, Ctrl+klik = przymierz;
--   towar za waluty zostaje w klasycznym oknie (gra pyta tam o potwierdzenie);
-- * prawo: plecak (prawy klik = sprzedaj), smieci sprzedaja sie same po otwarciu (GrimuarSetup PlecakPlus.lua,
--   wybor gracza 15.11), naprawa wszystkiego z kosztem.
-- Wszystko zwyklymi funkcjami gry (BuyMerchantItem, BuybackItem, RepairAllItems, C_Container.UseContainerItem).
local ADDON, U = ...
local C = U.C
local G = U.G or {}

local W, H, R_W = 1060, 620, 440
local S = { tab = "build" }
local F

local function money(c) return U.money and U.money(c) or tostring(c) end
local function count(id) return U.num(U.call(C_Item and C_Item.GetItemCount or GetItemCount, id, false)) or 0 end
local function info(i)
  if C_MerchantFrame and C_MerchantFrame.GetItemInfo then
    local ok, t = pcall(C_MerchantFrame.GetItemInfo, i)
    if ok and type(t) == "table" then return t end
  end
  local ok, name, tex, price, qty, avail, purch, usable, ext = pcall(GetMerchantItemInfo, i)
  if not (ok and name) then return nil end
  return { name = name, texture = tex, price = price, stackCount = qty, numAvailable = avail, isPurchasable = purch,
    isUsable = usable, hasExtendedCost = ext }
end
local function minBagSize()
  local m
  for bag = 1, (NUM_BAG_SLOTS or 4) do
    local n = U.num(U.call(C_Container.GetContainerNumSlots, bag)) or 0
    if not m or n < m then m = n end
  end
  return m or 0
end
-- liczba miejsc torby z dymku przedmiotu („16 Slot Bag”)
local function bagSlotsOf(id)
  if not (C_TooltipInfo and C_TooltipInfo.GetItemByID) then return nil end
  local ok, data = pcall(C_TooltipInfo.GetItemByID, id)
  if not ok or type(data) ~= "table" then return nil end
  for _, l in ipairs(data.lines or {}) do
    local n = tostring(l.leftText or ""):match("(%d+) Slot")
    if n then return tonumber(n) end
  end
  return nil
end
-- powod „dla buildu” albo nil
local function why(id, it, cls)
  local need = G.itemNeed and G.itemNeed(id)
  if need then return "◆ " .. need end
  local okI, _, _, _, _, _, classID, sub = pcall(C_Item.GetItemInfoInstant, id)
  if not okI then classID, sub = nil, nil end
  local have = count(id)
  if classID == 0 and sub == 5 and it.isUsable ~= false then return "jedzenie / picie · masz " .. have end
  if classID == 5 then return "reagent · masz " .. have end
  if classID == 6 and cls == "HUNTER" then return "amunicja · masz " .. have end
  if classID == 1 then
    local slots = bagSlotsOf(id)
    if slots and slots > minBagSize() then return "większa torba (" .. slots .. " miejsc)" end
  end
  return nil
end

-- ---------- rysowanie ----------
local function goods()
  local out = {}
  local _, cls = UnitClass("player")
  for i = 1, U.num(U.call(GetMerchantNumItems)) or 0 do
    local it = info(i)
    if it then
      local id = U.call(GetMerchantItemID, i)
      out[#out + 1] = { i = i, id = id, it = it, why = id and why(id, it, cls) or nil, link = U.call(GetMerchantItemLink, i) }
    end
  end
  return out
end
local function drawGoods()
  local list = {}
  if S.tab == "buyback" then
    for i = 1, U.num(U.call(GetNumBuybackItems)) or 0 do
      local name, tex, price, qty = U.call(GetBuybackItemInfo, i)
      if name then list[#list + 1] = { buyback = i, it = { name = name, texture = tex, price = price, stackCount = qty } } end
    end
  else
    for _, g in ipairs(goods()) do
      if S.tab == "all" or g.why then list[#list + 1] = g end
    end
  end
  F.goods:Fill(#list, function(r, n)
    local g = list[n]
    local it = g.it
    r.slot.icon:SetTexture(it.texture or 134400)
    local q = g.id and U.num(U.call(C_Item.GetItemQualityByID, g.id))
    r.slot:SetQuality(q)
    r.slot.count:SetText((U.num(it.stackCount) or 1) > 1 and it.stackCount or "")
    r.t:SetText(it.name or "?")
    U.Color(r.t, it.isUsable == false and C.danger or (U.QUALITY[q or 1] or C.text))
    local sub = {}
    if g.id then sub[#sub + 1] = "masz " .. count(g.id) end
    if (U.num(it.numAvailable) or -1) >= 0 then sub[#sub + 1] = "zostało " .. it.numAvailable end
    if it.hasExtendedCost then sub[#sub + 1] = "za walutę: klasyczne okno" end
    r.s:SetText(table.concat(sub, " · "))
    r.why:SetText(g.why or "")
    r.r:SetText((U.num(it.price) or 0) > 0 and money(it.price) or "")
    r.onClick = function(button)
      if g.buyback then pcall(BuybackItem, g.buyback) C_Timer.After(0.3, U.kupiecDraw) return end
      if IsModifiedClick("DRESSUP") and g.link then pcall(DressUpItemLink, g.link) return end
      -- Shift+klik przy otwartym czacie: link, inaczej caly stos
      if IsShiftKeyDown() and g.link and ChatEdit_GetActiveWindow and ChatEdit_GetActiveWindow() then pcall(ChatEdit_InsertLink, g.link) return end
      local _ = button
      if it.hasExtendedCost then U.say("ten towar kupisz w klasycznym oknie (gra pyta o walutę).") return end
      local qty = IsShiftKeyDown() and math.max(1, U.num(U.call(GetMerchantItemMaxStack, g.i)) or 1) or 1
      pcall(BuyMerchantItem, g.i, qty)
      C_Timer.After(0.3, U.kupiecDraw)
    end
    r.tip = function(tt)
      if g.buyback then pcall(tt.SetBuybackItem, tt, g.buyback) else pcall(tt.SetMerchantItem, tt, g.i) end
    end
  end)
  for k, b in pairs(F.tabs) do
    U.Color(b.label, k == S.tab and C.gold or C.muted)
    U.BorderColor(b, k == S.tab and C.gold or C.edge)
  end
end

local function bagSlot(i)
  local s = F.bag.slots[i]
  if s then return s end
  s = U.Slot(F.bag, 36)
  s:RegisterForClicks("LeftButtonUp", "RightButtonUp")
  s:SetScript("OnClick", function(self, button)
    if not self.bagID then return end
    if button == "RightButton" then
      pcall(C_Container.UseContainerItem, self.bagID, self.slotID)
      C_Timer.After(0.3, U.kupiecDraw)
    elseif IsModifiedClick("CHATLINK") and self.link then pcall(ChatEdit_InsertLink, self.link) end
  end)
  s:SetScript("OnEnter", function(self)
    if not self.bagID then return end
    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
    pcall(GameTooltip.SetBagItem, GameTooltip, self.bagID, self.slotID)
    GameTooltip:Show()
  end)
  s:SetScript("OnLeave", function() GameTooltip:Hide() end)
  F.bag.slots[i] = s
  return s
end
local function drawBag()
  local per = math.max(6, math.floor(((F.bag:GetWidth() or 400) + 4) / 40))
  local n = 0
  for bag = 0, (NUM_BAG_SLOTS or 4) do
    for slot = 1, U.num(U.call(C_Container.GetContainerNumSlots, bag)) or 0 do
      n = n + 1
      local s = bagSlot(n)
      s:ClearAllPoints()
      s:SetPoint("TOPLEFT", F.bag, "TOPLEFT", ((n - 1) % per) * 40, -math.floor((n - 1) / per) * 40)
      local it = U.call(C_Container.GetContainerItemInfo, bag, slot)
      if type(it) == "table" and it.itemID then
        s.bagID, s.slotID, s.link = bag, slot, it.hyperlink
        s.icon:SetShown(true)
        s.icon:SetTexture(it.iconFileID or 134400)
        s:SetQuality(it.quality)
        s.count:SetText((it.stackCount or 1) > 1 and it.stackCount or "")
        s.icon:SetDesaturated(G.itemIsJunk and G.itemIsJunk(it.itemID, it.quality) or false)
      else
        s.bagID, s.slotID, s.link = nil, nil, nil
        s.icon:SetShown(false) s:SetQuality(nil) s.count:SetText("")
      end
      s:Show()
    end
  end
  for i = n + 1, #F.bag.slots do F.bag.slots[i]:Hide() end
  F.bag:SetHeight(math.max(10, math.ceil(n / per) * 40))
end

function U.kupiecDraw()
  if not (F and F:IsShown()) then return end
  local ok, err = pcall(function()
    F.title:SetText(U.call(UnitName, "npc") or "Kupiec")
    local zone = U.call(GetSubZoneText)
    F.sub:SetText((zone and zone ~= "" and zone or (U.call(GetZoneText) or "")))
    drawGoods()
    drawBag()
    -- naprawa i smieci
    local canRepair = U.call(CanMerchantRepair)
    local cost = canRepair and U.num((U.call(GetRepairAllCost))) or 0
    F.repair:SetShown(canRepair and cost > 0)
    if canRepair and cost > 0 then F.repair:SetLabel("Napraw wszystko (" .. money(cost) .. ")") end
    local list, value = {}, 0
    if G.junkList then list, value = G.junkList() end
    F.junk:SetText(#list > 0 and ("Śmieci: " .. #list .. " za " .. money(value) .. " (sprzedają się same po otwarciu)") or "Śmieci sprzedane.")
    F.money:SetText(money(U.num(U.call(GetMoney)) or 0))
  end)
  if not ok then F:Fail(err) end
end

local function build()
  if F then return end
  F = U.Okno({ name = "GrimuarKupiec", width = W, height = H, title = "Kupiec", key = "kupiec",
    hosts = { "ForeverSkinMerchantFrame", "MerchantFrame" }, onClose = function() U.call(CloseMerchant) end })
  -- lewo
  local left = CreateFrame("Frame", nil, F)
  left:SetPoint("TOPLEFT", 22, -54) left:SetPoint("BOTTOMRIGHT", F, "BOTTOMRIGHT", -R_W - 34, 18)
  F.tabs = {}
  local prev
  for _, t in ipairs({ { "build", "Dla buildu" }, { "all", "Wszystko" }, { "buyback", "Odkup" } }) do
    local b = U.Button(left, t[2], nil, 24)
    if prev then b:SetPoint("LEFT", prev, "RIGHT", 6, 0) else b:SetPoint("TOPLEFT", 0, 0) end
    b:SetScript("OnClick", function() S.tab = t[1] U.kupiecDraw() end)
    F.tabs[t[1]] = b
    prev = b
  end
  local hint = U.Text(left, 11, "body", C.faint)
  hint:SetPoint("LEFT", prev, "RIGHT", 14, 0)
  hint:SetText("klik: kup 1 · Shift+klik: stos · Ctrl+klik: przymierz")
  F.goods = U.OknoList(left, 40, function(p) return U.OknoRow(p, 40) end)
  F.goods:SetPoint("TOPLEFT", 0, -34) F.goods:SetPoint("BOTTOMRIGHT", 0, 0)
  -- prawo
  local right = CreateFrame("Frame", nil, F)
  right:SetPoint("TOPRIGHT", -22, -54) right:SetPoint("BOTTOMRIGHT", -22, 18) right:SetWidth(R_W)
  local sep = F:CreateTexture(nil, "ARTWORK")
  sep:SetColorTexture(C.gold[1], C.gold[2], C.gold[3], 0.22)
  sep:SetWidth(1) sep:SetPoint("TOPRIGHT", right, "TOPLEFT", -12, 0) sep:SetPoint("BOTTOMRIGHT", right, "BOTTOMLEFT", -12, 0)
  local rh = U.H2(right, "Plecak")
  rh:SetPoint("TOPLEFT", 0, -2)
  F.money = U.Text(right, 13, "body", C.text)
  F.money:SetPoint("TOPRIGHT", 0, -2) F.money:SetJustifyH("RIGHT")
  F.repair = U.Button(right, "Napraw wszystko", nil, 26, true)
  F.repair:SetPoint("TOPLEFT", rh, "BOTTOMLEFT", 0, -10)
  F.repair:SetScript("OnClick", function() pcall(RepairAllItems) C_Timer.After(0.4, U.kupiecDraw) end)
  F.junk = U.Para(right, 12, R_W, C.muted)
  F.junk:SetPoint("TOPLEFT", F.repair, "BOTTOMLEFT", 0, -8)
  local bv = CreateFrame("ScrollFrame", nil, right)
  bv:SetPoint("TOPLEFT", F.junk, "BOTTOMLEFT", 0, -10) bv:SetPoint("BOTTOMRIGHT", 0, 22)
  F.bag = CreateFrame("Frame", nil, bv)
  F.bag:SetSize(R_W, 10)
  bv:SetScrollChild(F.bag)
  bv:EnableMouseWheel(true)
  bv:SetScript("OnMouseWheel", function(self, d)
    local max = math.max(0, F.bag:GetHeight() - self:GetHeight())
    self:SetVerticalScroll(math.max(0, math.min(max, self:GetVerticalScroll() - d * 80)))
  end)
  F.bag.slots = {}
  local bh = U.Text(right, 11, "body", C.faint)
  bh:SetPoint("BOTTOMLEFT", 0, 2)
  bh:SetText("prawy klik: sprzedaj · szare = śmieć Grimuara")
end

local ev = CreateFrame("Frame")
for _, e in ipairs({ "MERCHANT_SHOW", "MERCHANT_CLOSED", "MERCHANT_UPDATE", "BAG_UPDATE_DELAYED", "PLAYER_MONEY",
  "UPDATE_INVENTORY_DURABILITY", "GET_ITEM_INFO_RECEIVED" }) do pcall(ev.RegisterEvent, ev, e) end
ev:SetScript("OnEvent", function(_, e)
  if e == "MERCHANT_SHOW" then
    C_Timer.After(0, function()
      build()
      S.tab = "build"
      if F:Open() then
        U.kupiecDraw()
        -- pusta zakladka „Dla buildu”: od razu „Wszystko”
        if #F.goods.rows == 0 or not F.goods.rows[1]:IsShown() then S.tab = "all" U.kupiecDraw() end
      end
    end)
  elseif e == "MERCHANT_CLOSED" then
    if F then F:Finish() end
  elseif F and F:IsShown() then
    if S.q then return end
    S.q = true
    C_Timer.After(0.25, function() S.q = nil U.kupiecDraw() end)
  end
end)
