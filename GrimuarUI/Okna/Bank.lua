-- Grimuar UI: Bank w stylu huba (15.11, plan R29 etap 3). Zamiast okna banku ForeverSkin (ForeverSkinBankFrame) albo gry
-- (BankFrame), przyczepione i wieksze (Okna/Wspolne.lua). Lewo: bank (zakladki banku postaci z Midnight albo stary bank
-- i torby bankowe), prawo: plecak. Prawy klik przenosi przedmiot na druga strone (C_Container.UseContainerItem przy
-- otwartym banku). Przyciski: „Odloz materialy” (GrimuarSetup PlecakPlus.lua: materialy bez potrzebnych do poradnika
-- i bez ulubionych), „Sortuj bank”, „Sortuj plecak”. Znaczki jak w plecaku: ◆ potrzebne, szare = smiec.
local ADDON, U = ...
local C = U.C
local G = U.G or {}

local W, H = 1120, 640
local F

local function bankBags()
  local out = {}
  local E = Enum and Enum.BagIndex
  if E and E.CharacterBankTab_1 then
    for i = 1, 6 do
      local id = E["CharacterBankTab_" .. i]
      if id and (U.num(U.call(C_Container.GetContainerNumSlots, id)) or 0) > 0 then out[#out + 1] = id end
    end
  end
  if #out == 0 then
    local bc = BANK_CONTAINER or -1
    if (U.num(U.call(C_Container.GetContainerNumSlots, bc)) or 0) > 0 then out[#out + 1] = bc end
    local first = (NUM_TOTAL_EQUIPPED_BAG_SLOTS or NUM_BAG_SLOTS or 4) + 1
    for id = first, first + (NUM_BANKBAGSLOTS or 7) - 1 do
      if (U.num(U.call(C_Container.GetContainerNumSlots, id)) or 0) > 0 then out[#out + 1] = id end
    end
  end
  return out
end
local function playerBags()
  local out = {}
  for bag = 0, (NUM_BAG_SLOTS or 4) do out[#out + 1] = bag end
  return out
end

local function slot(grid, i)
  local s = grid.slots[i]
  if s then return s end
  s = U.Slot(grid, 36)
  s:RegisterForClicks("LeftButtonUp", "RightButtonUp")
  s.need = s:CreateTexture(nil, "OVERLAY", nil, 3)
  s.need:SetSize(7, 7) s.need:SetPoint("BOTTOMLEFT", 4, 4)
  s.need:SetColorTexture(0.49, 0.88, 0.49, 1)
  pcall(s.need.SetRotation, s.need, math.rad(45))
  s:SetScript("OnClick", function(self, button)
    if not self.bagID then return end
    if button == "RightButton" then
      pcall(C_Container.UseContainerItem, self.bagID, self.slotID)
      C_Timer.After(0.3, U.bankDraw)
    elseif IsModifiedClick("CHATLINK") and self.link then pcall(ChatEdit_InsertLink, self.link) end
  end)
  s:SetScript("OnEnter", function(self)
    if not self.bagID then return end
    U.TT:SetOwner(self, "ANCHOR_RIGHT")
    pcall(U.TT.SetBagItem, U.TT, self.bagID, self.slotID)
    U.TT:Show()
  end)
  s:SetScript("OnLeave", function() U.TT:Hide() end)
  grid.slots[i] = s
  return s
end
local function drawGrid(grid, bags)
  local per = math.max(6, math.floor(((grid:GetWidth() or 400) + 4) / 40))
  local n, used = 0, 0
  for _, bag in ipairs(bags) do
    for sl = 1, U.num(U.call(C_Container.GetContainerNumSlots, bag)) or 0 do
      n = n + 1
      local s = slot(grid, n)
      s:ClearAllPoints()
      s:SetPoint("TOPLEFT", grid, "TOPLEFT", ((n - 1) % per) * 40, -math.floor((n - 1) / per) * 40)
      local it = U.call(C_Container.GetContainerItemInfo, bag, sl)
      if type(it) == "table" and it.itemID then
        used = used + 1
        s.bagID, s.slotID, s.link = bag, sl, it.hyperlink
        s.icon:Show() s.icon:SetTexture(it.iconFileID or 134400)
        s:SetQuality(it.quality)
        s.count:SetText((it.stackCount or 1) > 1 and it.stackCount or "")
        s.icon:SetDesaturated(G.itemIsJunk and G.itemIsJunk(it.itemID, it.quality) or false)
        s.need:SetShown(G.itemNeed and G.itemNeed(it.itemID) ~= nil or false)
      else
        s.bagID, s.slotID, s.link = nil, nil, nil
        s.icon:Hide() s:SetQuality(nil) s.count:SetText("") s.need:Hide()
      end
      s:Show()
    end
  end
  for i = n + 1, #grid.slots do grid.slots[i]:Hide() end
  grid:SetHeight(math.max(10, math.ceil(n / per) * 40))
  return used, n
end

function U.bankDraw()
  if not (F and F:IsShown()) then return end
  local ok, err = pcall(function()
    local bu, bn = drawGrid(F.bankGrid, bankBags())
    local pu, pn = drawGrid(F.bagGrid, playerBags())
    F.bankH:SetText("Bank   " .. U.hex(C.faint) .. bu .. " / " .. bn .. "|r")
    F.bagH:SetText("Plecak   " .. U.hex(C.faint) .. pu .. " / " .. pn .. "|r")
    F.sub:SetText(U.money and U.money(U.num(U.call(GetMoney)) or 0) or "")
  end)
  if not ok then F:Fail(err) end
end

local function scroller(parent)
  local v = CreateFrame("ScrollFrame", nil, parent)
  local g = CreateFrame("Frame", nil, v)
  g:SetSize(400, 10)
  v:SetScrollChild(g)
  v:EnableMouseWheel(true)
  v:SetScript("OnMouseWheel", function(self, d)
    local max = math.max(0, g:GetHeight() - self:GetHeight())
    self:SetVerticalScroll(math.max(0, math.min(max, self:GetVerticalScroll() - d * 80)))
  end)
  v:SetScript("OnSizeChanged", function(_, w) g:SetWidth(w) end)
  g.slots = {}
  return v, g
end

local function build()
  if F then return end
  F = U.Okno({ name = "GrimuarBank", width = W, height = H, title = "Bank", key = "bank",
    hosts = { "ForeverSkinBankFrame", "BankFrame" }, onClose = function() U.call(CloseBankFrame) end })
  local prev
  local function btn(text, fn, primary)
    local b = U.Button(F, text, nil, 26, primary)
    if prev then b:SetPoint("LEFT", prev, "RIGHT", 8, 0) else b:SetPoint("TOPLEFT", 22, -56) end
    b:SetScript("OnClick", function() pcall(fn) C_Timer.After(0.6, U.bankDraw) end)
    prev = b
  end
  btn("Odłóż materiały", function() if G.depositMaterials then G.depositMaterials() end end, true)
  btn("Sortuj bank", function() if C_Container.SortBankBags then C_Container.SortBankBags() end end)
  btn("Sortuj plecak", function() if C_Container.SortBags then C_Container.SortBags() end end)
  local hint = U.Text(F, 11, "body", C.faint)
  hint:SetPoint("LEFT", prev, "RIGHT", 14, 0)
  hint:SetText("prawy klik: przenieś na drugą stronę · ◆ potrzebne do poradnika zostają w plecaku")
  local half = math.floor((W - 44 - 24) / 2)
  F.bankH = U.H2(F, "Bank") F.bankH:SetPoint("TOPLEFT", 22, -96)
  local bv, bg = scroller(F)
  bv:SetPoint("TOPLEFT", F.bankH, "BOTTOMLEFT", 0, -10) bv:SetPoint("BOTTOMLEFT", 22, 18) bv:SetWidth(half)
  F.bankGrid = bg
  F.bagH = U.H2(F, "Plecak") F.bagH:SetPoint("TOPLEFT", 22 + half + 24, -96)
  local pv, pg = scroller(F)
  pv:SetPoint("TOPLEFT", F.bagH, "BOTTOMLEFT", 0, -10) pv:SetPoint("BOTTOMRIGHT", -22, 18)
  F.bagGrid = pg
end

local ev = CreateFrame("Frame")
for _, e in ipairs({ "BANKFRAME_OPENED", "BANKFRAME_CLOSED", "PLAYERBANKSLOTS_CHANGED", "BAG_UPDATE_DELAYED", "PLAYER_MONEY" }) do
  pcall(ev.RegisterEvent, ev, e)
end
ev:SetScript("OnEvent", function(_, e)
  if e == "BANKFRAME_OPENED" then
    C_Timer.After(0.1, function()
      build()
      pcall(function()
        local ids, slots = {}, 0
        for _, b in ipairs(bankBags()) do
          ids[#ids + 1] = b
          slots = slots + (U.num(U.call(C_Container.GetContainerNumSlots, b)) or 0)
        end
        U.diag("bank", { bags = table.concat(ids, ","), slots = slots,
          tabs = (Enum and Enum.BagIndex and Enum.BagIndex.CharacterBankTab_1) and "zakładki postaci" or "stary bank" })
      end)
      if F:Open() then U.bankDraw() end
    end)
  elseif e == "BANKFRAME_CLOSED" then
    if F then F:Finish() end
  elseif F and F:IsShown() then
    if F.q then return end
    F.q = true
    C_Timer.After(0.25, function() F.q = nil U.bankDraw() end)
  end
end)
