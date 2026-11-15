-- Grimuar UI: okno Porzadki w torbach (15.11, gracz: „zeby inventory podpowiadalo albo cos robilo, zeby latwo czyscic”;
-- wybor: „jeden klik na grupe”). Werdykty liczy GrimuarSetup Wyglad\Porzadki.lua (G.porzadki). Grupy jako sekcje
-- z ikonami (dymek: przedmiot gry + powod Grimuara) i jednym przyciskiem na grupe:
--   Sprzedaj u kupca  klik sprzedaje cala grupe (po 12 na klik, jak smieci), tylko przy otwartym kupcu;
--   Wystaw na aukcji  otwiera Rynek > Sprzedaj przy aukcjonerze;
--   Uzyj albo zaloz   ikony to bezpieczne przyciski gry (typ „item”): klik uzywa albo zaklada; poza walka;
--   Do banku          klik odklada cala grupe przy otwartym banku;
--   Wyrzuc            klik w ikone dwa razy (w 3 s) wyrzuca ten jeden przedmiot.
-- Prawy klik na ikonie: ★ ulubione (Grimuar go nie ruszy). Shift+klik: link do czatu. /hub porzadki, przycisk na dole
-- plecaka „Porzadki (N)”.
local ADDON, U = ...
local C = U.C
local G = U.G or {}

local W, H = 720, 620
local F
local S = { secs = {}, slots = {}, secure = {}, armed = nil }
local TITLE = { sprzedaj = "Sprzedaj u kupca", aukcja = "Wystaw na aukcji", uzyj = "Użyj albo załóż", bank = "Do banku",
  wyrzuc = "Wyrzuć", smieci = "Śmieci", zostaw = "Zostaw" }
local HINT = { sprzedaj = "u kupca jeden klik sprzedaje całą grupę", aukcja = "u aukcjonera: Rynek > Sprzedaj",
  uzyj = "klik w ikonę: użyj albo załóż", bank = "w banku jeden klik odkłada całą grupę", wyrzuc = "klik w ikonę dwa razy: wyrzuć",
  smieci = "sprzedają się same u kupca", zostaw = "Grimuar ich nie ruszy" }
local SIZE, GAP = 38, 6

local function money(c) return U.money and U.money(c) or tostring(c) end
local function shown(name) local f = _G[name] return f and f:IsShown() end
local function atMerchant() return shown("MerchantFrame") or shown("ForeverSkinMerchantFrame") or shown("GrimuarKupiec") end
local function atBank() return shown("BankFrame") or shown("ForeverSkinBankFrame") or shown("GrimuarBank") end
local function atAH() return shown("AuctionHouseFrame") or shown("GrimuarRynekFrame") end

local function tip(self)
  local it = self.it
  if not it then return end
  U.TT:SetOwner(self, "ANCHOR_RIGHT")
  if not pcall(U.TT.SetBagItem, U.TT, it.bag, it.slot) then U.TT:SetText(it.link or "?") end
  U.TT:AddLine("Grimuar: " .. (TITLE[self.kind] or "") .. " · " .. (it.reason or ""), 0.85, 0.71, 0.36, true)
  if (it.value or 0) > 0 then U.TT:AddLine("wartość: " .. money(it.value), 0.8, 0.8, 0.8) end
  U.TT:AddLine(self.kind == "uzyj" and "klik: użyj albo załóż" or "PPM: ★ ulubione (Grimuar go nie ruszy) · Shift+klik: link", 0.6, 0.6, 0.6, true)
  U.TT:Show()
end

local function slot(i)
  local s = S.slots[i]
  if s then return s end
  s = U.Slot(F.child, SIZE)
  s:RegisterForClicks("LeftButtonUp", "RightButtonUp")
  s:SetScript("OnEnter", tip)
  s:SetScript("OnLeave", function() U.TT:Hide() end)
  s:SetScript("OnClick", function(self, button)
    local it = self.it
    if not it then return end
    if IsModifiedClick("CHATLINK") and it.link then pcall(ChatEdit_InsertLink, it.link) return end
    if button == "RightButton" then
      if G.itemMarkSet then G.itemMarkSet(it.id, "fav") end
      U.say((it.link or "przedmiot") .. ": ★ ulubione, Grimuar go nie ruszy.")
      C_Timer.After(0.2, U.porzadkiDraw)
      return
    end
    if self.kind == "wyrzuc" then
      if S.armed and S.armed.bag == it.bag and S.armed.slot == it.slot and GetTime() - S.armed.at < 3 then
        S.armed = nil
        if InCombatLockdown() then return end
        pcall(function()
          ClearCursor()
          C_Container.PickupContainerItem(it.bag, it.slot)
          DeleteCursorItem()
        end)
        C_Timer.After(0.3, U.porzadkiDraw)
      else
        S.armed = { bag = it.bag, slot = it.slot, at = GetTime() }
        U.say("kliknij jeszcze raz w ciągu 3 s, żeby wyrzucić: " .. (it.link or "przedmiot") .. ".")
      end
    end
  end)
  S.slots[i] = s
  return s
end

-- bezpieczny przycisk „uzyj” (typ item: torba i miejsce); tworzony i ustawiany tylko poza walka
local function secureSlot(i)
  local b = S.secure[i]
  if b then return b end
  b = CreateFrame("Button", "GrimuarPorzadkiUzyj" .. i, F.child, "SecureActionButtonTemplate")
  b:SetSize(SIZE, SIZE)
  b:RegisterForClicks("AnyUp", "AnyDown")
  b.bg = U.Rect(b, C.slot, 1) b.bg:SetAllPoints()
  U.Border(b, C.gold, 0.8)
  b.icon = b:CreateTexture(nil, "ARTWORK")
  b.icon:SetPoint("TOPLEFT", 2, -2) b.icon:SetPoint("BOTTOMRIGHT", -2, 2)
  b.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
  b.count = U.Text(b, 11, "body", C.text, "OUTLINE")
  b.count:SetPoint("BOTTOMRIGHT", -3, 3)
  b.kind = "uzyj"
  b:SetScript("OnEnter", tip)
  b:SetScript("OnLeave", function() U.TT:Hide() end)
  b:HookScript("OnClick", function() C_Timer.After(0.4, U.porzadkiDraw) end)
  S.secure[i] = b
  return b
end

local function section(i)
  local s = S.secs[i]
  if s then return s end
  s = CreateFrame("Frame", nil, F.child)
  s:SetHeight(30)
  s.d = U.Diamond(s, 10, C.gold, true) s.d:SetPoint("LEFT", 0, 0)
  s.t = U.Text(s, 15, "title", C.gold) s.t:SetPoint("LEFT", s.d, "RIGHT", 8, 0)
  s.n = U.Text(s, 12, "body", C.muted) s.n:SetPoint("LEFT", s.t, "RIGHT", 10, 0)
  s.btn = U.Button(s, "", nil, 24, true)
  s.btn:SetPoint("RIGHT", 0, 0)
  s.h = U.Text(s, 11, "body", C.faint) s.h:SetPoint("RIGHT", s.btn, "LEFT", -10, 0)
  S.secs[i] = s
  return s
end

local function sellGroup(items, bank)
  local n = 0
  for _, it in ipairs(items) do
    if n >= 12 then break end
    pcall(C_Container.UseContainerItem, it.bag, it.slot)
    n = n + 1
  end
  U.say((bank and "odłożone do banku: " or "sprzedane: ") .. n .. (n < #items and (" (zostało " .. (#items - n) .. ", kliknij jeszcze raz)") or "") .. ".")
  C_Timer.After(0.6, U.porzadkiDraw)
end

function U.porzadkiDraw()
  if not (F and F:IsShown()) or InCombatLockdown() then return end
  local ok, err = pcall(function()
    local groups = G.porzadki and G.porzadki() or {}
    local y, si, ni, ui = 0, 0, 0, 0
    local w = (F.view:GetWidth() or 640) - 8
    local per = math.max(4, math.floor((w + GAP) / (SIZE + GAP)))
    local todo, freeSlots = 0, 0
    for b = 0, (NUM_BAG_SLOTS or 4) do freeSlots = freeSlots + (C_Container.GetContainerNumFreeSlots(b) or 0) end
    for _, k in ipairs(G.PORZADKI_ORDER or {}) do
      local g = groups[k]
      if g and #g.items > 0 then
        if k ~= "zostaw" and k ~= "smieci" then todo = todo + #g.items end
        si = si + 1
        local s = section(si)
        s:ClearAllPoints()
        s:SetPoint("TOPLEFT", F.child, "TOPLEFT", 0, -y)
        s:SetWidth(w)
        s.t:SetText(TITLE[k])
        s.n:SetText(#g.items .. ((g.value or 0) > 0 and (" · " .. money(g.value)) or ""))
        s.h:SetText(HINT[k])
        local act, label, enabled
        if k == "sprzedaj" then label, enabled, act = "Sprzedaj wszystko", atMerchant(), function() sellGroup(g.items) end
        elseif k == "bank" then label, enabled, act = "Odłóż wszystko", atBank(), function() sellGroup(g.items, true) end
        elseif k == "aukcja" then label, enabled, act = "Rynek > Sprzedaj", atAH(), function() if G.rynekOpenSell then G.rynekOpenSell() end end end
        s.btn:SetShown(label ~= nil)
        if label then
          s.btn:SetLabel(label)
          s.btn:SetEnabled(enabled and true or false)
          s.btn:SetAlpha(enabled and 1 or 0.45)
          s.btn:SetScript("OnClick", function() if enabled then pcall(act) end end)
        end
        s:Show()
        y = y + 34
        for i, it in ipairs(g.items) do
          local b
          if k == "uzyj" then
            ui = ui + 1
            b = secureSlot(ui)
            b:SetAttribute("type", "item")
            b:SetAttribute("item", it.bag .. " " .. it.slot)
          else
            ni = ni + 1
            b = slot(ni)
            b:SetQuality(it.quality)
            b.icon:SetDesaturated(k == "smieci")
          end
          b.it, b.kind = it, k
          b.icon:SetTexture(it.icon or 134400)
          b.count:SetText(it.count > 1 and it.count or "")
          b:ClearAllPoints()
          b:SetPoint("TOPLEFT", F.child, "TOPLEFT", ((i - 1) % per) * (SIZE + GAP), -(y + math.floor((i - 1) / per) * (SIZE + GAP)))
          b:SetAlpha(k == "zostaw" and 0.6 or 1)
          b:Show()
        end
        y = y + math.ceil(#g.items / per) * (SIZE + GAP) + 14
      end
    end
    for i = si + 1, #S.secs do S.secs[i]:Hide() end
    for i = ni + 1, #S.slots do S.slots[i]:Hide() end
    for i = ui + 1, #S.secure do S.secure[i]:Hide() S.secure[i]:SetAttribute("type", nil) end
    F.child:SetHeight(math.max(10, y))
    F.sub:SetText(todo .. (todo == 1 and " rzecz do zrobienia" or " rzeczy do zrobienia") .. " · wolne miejsca: " .. freeSlots)
  end)
  if not ok then U.say("porządki: " .. tostring(err)) if U.logError then U.logError("porzadki", err) end end
end

local function build()
  if F then return end
  F = U.Panel(UIParent, 0.97, true, C.edge)
  _G.GrimuarPorzadki = F
  tinsert(UISpecialFrames, "GrimuarPorzadki")
  F:SetSize(W, H)
  F:SetPoint("CENTER", UIParent, "CENTER", -120, 20)
  F:SetFrameStrata("DIALOG")
  F:SetToplevel(true)
  F:EnableMouse(true)
  F:SetMovable(true)
  F:RegisterForDrag("LeftButton")
  F:SetScript("OnDragStart", F.StartMoving)
  F:SetScript("OnDragStop", F.StopMovingOrSizing)
  F:SetClampedToScreen(true)
  F:Hide()
  F.title = U.Text(F, 22, "title", C.gold)
  F.title:SetPoint("TOPLEFT", 22, -16)
  F.title:SetText("Porządki w torbach")
  F.sub = U.Text(F, 12, "body", C.muted)
  F.sub:SetPoint("TOPLEFT", F.title, "BOTTOMLEFT", 0, -6)
  F.close = U.Button(F, "×", 26, 24)
  F.close:SetPoint("TOPRIGHT", -10, -10)
  F.close:SetScript("OnClick", function() F:Hide() end)
  F.view = CreateFrame("ScrollFrame", nil, F)
  F.view:SetPoint("TOPLEFT", 22, -74)
  F.view:SetPoint("BOTTOMRIGHT", -18, 18)
  F.child = CreateFrame("Frame", nil, F.view)
  F.child:SetSize(W - 40, 10)
  F.view:SetScrollChild(F.child)
  F.view:EnableMouseWheel(true)
  F.view:SetScript("OnMouseWheel", function(self, d)
    local max = math.max(0, F.child:GetHeight() - self:GetHeight())
    self:SetVerticalScroll(math.max(0, math.min(max, self:GetVerticalScroll() - d * 80)))
  end)
  F:SetScript("OnShow", function() C_Timer.After(0, U.porzadkiDraw) end)
end

function U.porzadkiToggle()
  if InCombatLockdown() then U.say("porządki po walce.") return end
  build()
  F:SetShown(not F:IsShown())
end
if G then G.porzadkiToggle = U.porzadkiToggle end

local ev = CreateFrame("Frame")
for _, e in ipairs({ "BAG_UPDATE_DELAYED", "MERCHANT_SHOW", "MERCHANT_CLOSED", "BANKFRAME_OPENED", "BANKFRAME_CLOSED",
  "AUCTION_HOUSE_SHOW", "AUCTION_HOUSE_CLOSED", "PLAYER_REGEN_ENABLED" }) do pcall(ev.RegisterEvent, ev, e) end
ev:SetScript("OnEvent", function()
  if not (F and F:IsShown()) or S.q then return end
  S.q = true
  C_Timer.After(0.4, function() S.q = nil U.porzadkiDraw() end)
end)
