-- Grimuar UI: Poczta w stylu huba (15.11, plan R29 etap 3). Zamiast okna poczty ForeverSkin (ForeverSkinMailFrame)
-- albo gry (MailFrame), przyczepione i wieksze (Okna/Wspolne.lua). Dwie zakladki:
-- * Skrzynka: listy (nadawca, temat, pieniadze, przedmioty, ile dni zostalo); klik = otworz (tresc i zalaczniki),
--   „Odbierz” (pieniadze i przedmioty z tego listu), „Odbierz wszystko” (po kolei co 0,4 s, bez listow za pobraniem),
--   „Usun” (pusty list);
-- * Wyslij: do kogo, temat, tresc, pieniadze (zl / sr / md), zalaczniki z plecaka (klik w przedmiot = dodaj), „Wyslij”.
-- Zwykle funkcje gry (TakeInboxMoney, AutoLootMailItem, TakeInboxItem, DeleteInboxItem, SendMail, SetSendMailMoney,
-- ClickSendMailItemButton). Listy za pobraniem (COD) i reszta rzadkich rzeczy: klasyczne okno.
local ADDON, U = ...
local C = U.C

local W, H = 1000, 620
local S = { tab = "in", sel = nil }
local F

local function money(c) return U.money and U.money(c) or tostring(c) end
local function header(i)
  local ok, _, _, sender, subject, cash, cod, days, hasItem, wasRead = pcall(GetInboxHeaderInfo, i)
  if not ok then sender = nil end
  return { i = i, sender = sender or "?", subject = subject or "", money = U.num(cash) or 0, cod = U.num(cod) or 0,
    days = U.num(days), items = U.num(hasItem) or 0, read = wasRead }
end

-- ---------- skrzynka ----------
local function takeAll()
  local i = U.num(select(1, U.call(GetInboxNumItems))) or 0
  local n = 0
  local function step()
    if not (F and F:IsShown()) or i < 1 then
      U.say(n > 0 and ("odebrane z poczty: " .. n .. ".") or "nic do odebrania.")
      U.pocztaDraw()
      return
    end
    local h = header(i)
    if h.cod == 0 and (h.money > 0 or h.items > 0) then
      if h.money > 0 then pcall(TakeInboxMoney, i) end
      if h.items > 0 then pcall(AutoLootMailItem, i) end
      n = n + 1
    end
    i = i - 1
    C_Timer.After(0.4, step)
  end
  step()
end

local function drawInbox()
  local num = U.num(select(1, U.call(GetInboxNumItems))) or 0
  local list = {}
  for i = 1, num do list[#list + 1] = header(i) end
  F.mail:Fill(#list, function(r, n)
    local h = list[n]
    local _, icon = U.call(GetInboxHeaderInfo, h.i)
    r.slot.icon:SetTexture(icon or 133468)
    r.slot:SetQuality(nil) r.slot.count:SetText("")
    r.t:SetText(h.subject ~= "" and h.subject or "(bez tematu)")
    U.Color(r.t, h.read and C.muted or C.text)
    r.s:SetText("od: " .. h.sender .. (h.days and (" · zostało " .. math.floor(h.days) .. " dni") or ""))
    local parts = {}
    if h.items > 0 then parts[#parts + 1] = h.items .. " przedm." end
    if h.cod > 0 then parts[#parts + 1] = "za pobraniem" end
    r.why:SetText(table.concat(parts, " · "))
    r.r:SetText(h.money > 0 and money(h.money) or "")
    r.bg:SetColorTexture(C.panel2[1], C.panel2[2], C.panel2[3], h.i == S.sel and 0.95 or 0.55)
    r.onClick = function() S.sel = h.i U.pocztaDraw() end
    r.tip = nil
  end)
  -- podglad listu
  local P = F.read
  P:Begin(P.mid == S.sel)
  P.mid = S.sel
  if not S.sel or S.sel > num then
    P:Para(num == 0 and "Skrzynka jest pusta." or "Kliknij list po lewej.", C.muted)
    P:End()
    return
  end
  local h = header(S.sel)
  P:Title(h.subject ~= "" and h.subject or "(bez tematu)", "od: " .. h.sender .. (h.days and (" · zostało " .. math.floor(h.days) .. " dni") or ""))
  local body = U.call(GetInboxText, S.sel)
  if body and body ~= "" then P:Para(body, C.text, 14) end
  local items = {}
  for a = 1, (ATTACHMENTS_MAX_RECEIVE or 16) do
    local okI, name, itemID, tex, _, quality = pcall(GetInboxItem, S.sel, a)
    if okI and name then items[#items + 1] = { id = itemID, name = name, icon = tex, quality = quality } end
  end
  if #items > 0 then P:Head("Załączniki", #items .. " przedm.") P:Icons(items) end
  if h.money > 0 then P:Head("Pieniądze") P:Para(money(h.money), C.text, 14) end
  if h.cod > 0 then P:Para("List za pobraniem (" .. money(h.cod) .. "): odbierz w klasycznym oknie, gra zapyta o zapłatę.", C.danger, 12) end
  P:Gap(4)
  if h.cod == 0 and (h.money > 0 or #items > 0) then
    P:Button("Odbierz", function()
      if h.money > 0 then pcall(TakeInboxMoney, h.i) end
      if #items > 0 then pcall(AutoLootMailItem, h.i) end
      C_Timer.After(0.5, U.pocztaDraw)
    end, true)
  end
  if h.money == 0 and #items == 0 then
    P:Button("Usuń list", function() pcall(DeleteInboxItem, h.i) S.sel = nil C_Timer.After(0.4, U.pocztaDraw) end)
  end
  P:End()
end

-- ---------- wysylanie ----------
local function bagSlot(i)
  local s = F.bag.slots[i]
  if s then return s end
  s = U.Slot(F.bag, 34)
  s:SetScript("OnClick", function(self)
    if not self.bagID then return end
    -- przedmiot na kursor i do pierwszego wolnego miejsca na zalacznik
    pcall(C_Container.PickupContainerItem, self.bagID, self.slotID)
    for a = 1, (ATTACHMENTS_MAX_SEND or 12) do
      if not U.call(GetSendMailItem, a) then pcall(ClickSendMailItemButton, a) break end
    end
    ClearCursor()
    C_Timer.After(0.2, U.pocztaDraw)
  end)
  s:SetScript("OnEnter", function(self)
    if not self.bagID then return end
    GameTooltip:SetOwner(self, "ANCHOR_RIGHT") pcall(GameTooltip.SetBagItem, GameTooltip, self.bagID, self.slotID) GameTooltip:Show()
  end)
  s:SetScript("OnLeave", function() GameTooltip:Hide() end)
  F.bag.slots[i] = s
  return s
end
local function drawSend()
  local per = math.max(6, math.floor(((F.bag:GetWidth() or 360) + 4) / 38))
  local n = 0
  for bag = 0, (NUM_BAG_SLOTS or 4) do
    for slot = 1, U.num(U.call(C_Container.GetContainerNumSlots, bag)) or 0 do
      local it = U.call(C_Container.GetContainerItemInfo, bag, slot)
      if type(it) == "table" and it.itemID and not it.isBound then
        n = n + 1
        local s = bagSlot(n)
        s:ClearAllPoints()
        s:SetPoint("TOPLEFT", F.bag, "TOPLEFT", ((n - 1) % per) * 38, -math.floor((n - 1) / per) * 38)
        s.bagID, s.slotID = bag, slot
        s.icon:SetTexture(it.iconFileID or 134400) s.icon:Show()
        s:SetQuality(it.quality)
        s.count:SetText((it.stackCount or 1) > 1 and it.stackCount or "")
        s:Show()
      end
    end
  end
  for i = n + 1, #F.bag.slots do F.bag.slots[i]:Hide() end
  F.bag:SetHeight(math.max(10, math.ceil(n / per) * 38))
  -- zalaczniki
  local att = {}
  for a = 1, (ATTACHMENTS_MAX_SEND or 12) do
    local name, _, _, count = U.call(GetSendMailItem, a)
    if name then att[#att + 1] = name .. ((U.num(count) or 1) > 1 and (" ×" .. count) or "") end
  end
  F.att:SetText(#att > 0 and ("Załączniki: " .. table.concat(att, ", ")) or "Załączniki: kliknij przedmiot z plecaka (bez przedmiotów związanych z postacią).")
  F.cost:SetText("Koszt wysłania: " .. money(U.num(U.call(GetSendMailPrice)) or 30))
end

local function send()
  local to = (F.to:GetText() or ""):gsub("^%s+", ""):gsub("%s+$", "")
  if to == "" then U.say("wpisz, do kogo.") return end
  local g, s, c = tonumber(F.g:GetText()) or 0, tonumber(F.s:GetText()) or 0, tonumber(F.c:GetText()) or 0
  local copper = math.floor(g * 10000 + s * 100 + c)
  if copper > 0 then pcall(SetSendMailMoney, copper) end
  local subject = F.subj:GetText() or ""
  if subject == "" then
    local first = U.call(GetSendMailItem, 1)
    subject = first or (copper > 0 and "Pieniądze" or "List")
  end
  local ok = pcall(SendMail, to, subject, F.body:GetText() or "")
  if ok then
    U.say("wysłane do " .. to .. ".")
    for _, e in ipairs({ F.subj, F.body, F.g, F.s, F.c }) do e:SetText("") end
  end
  C_Timer.After(0.5, U.pocztaDraw)
end

function U.pocztaDraw()
  if not (F and F:IsShown()) then return end
  local ok, err = pcall(function()
    F.inbox:SetShown(S.tab == "in")
    F.sendF:SetShown(S.tab == "out")
    for k, b in pairs(F.tabs) do
      U.Color(b.label, k == S.tab and C.gold or C.muted)
      U.BorderColor(b, k == S.tab and C.gold or C.edge)
    end
    local num, total = U.call(GetInboxNumItems)
    F.sub:SetText((U.num(num) or 0) .. " listów" .. ((U.num(total) or 0) > (U.num(num) or 0) and (" (na serwerze " .. total .. ")") or ""))
    if S.tab == "in" then drawInbox() else drawSend() end
  end)
  if not ok then F:Fail(err) end
end

local function input(parent, w, h, multi)
  local e
  if multi then
    e = CreateFrame("EditBox", nil, parent)
    e:SetMultiLine(true) e:SetFontObject(ChatFontNormal) e:SetTextInsets(8, 8, 6, 6)
    e.bg = U.Rect(e, C.slot, 0.95) e.bg:SetAllPoints()
    U.Border(e, C.edge)
  else
    e = CreateFrame("EditBox", nil, parent, "InputBoxTemplate")
  end
  e:SetSize(w, h or 24)
  e:SetAutoFocus(false)
  e:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
  if not multi then e:SetScript("OnEnterPressed", function(self) self:ClearFocus() end) end
  return e
end

local function build()
  if F then return end
  F = U.Okno({ name = "GrimuarPoczta", width = W, height = H, title = "Poczta", key = "poczta",
    hosts = { "ForeverSkinMailFrame", "MailFrame" }, onClose = function() U.call(CloseMail) end })
  F.tabs = {}
  local prev
  for _, t in ipairs({ { "in", "Skrzynka" }, { "out", "Wyślij" } }) do
    local b = U.Button(F, t[2], nil, 26)
    if prev then b:SetPoint("LEFT", prev, "RIGHT", 6, 0) else b:SetPoint("TOPLEFT", 22, -56) end
    b:SetScript("OnClick", function() S.tab = t[1] U.pocztaDraw() end)
    F.tabs[t[1]] = b
    prev = b
  end
  local all = U.Button(F, "Odbierz wszystko", nil, 26, true)
  all:SetPoint("LEFT", prev, "RIGHT", 20, 0)
  all:SetScript("OnClick", takeAll)
  -- skrzynka
  F.inbox = CreateFrame("Frame", nil, F)
  F.inbox:SetPoint("TOPLEFT", 22, -94) F.inbox:SetPoint("BOTTOMRIGHT", -22, 18)
  F.mail = U.OknoList(F.inbox, 40, function(p) return U.OknoRow(p, 40) end)
  F.mail:SetPoint("TOPLEFT") F.mail:SetPoint("BOTTOMLEFT") F.mail:SetWidth(520)
  F.read = U.Blocks(F.inbox)
  F.read:SetPoint("TOPLEFT", F.mail, "TOPRIGHT", 16, 0) F.read:SetPoint("BOTTOMRIGHT")
  F.read.bg:Hide()
  -- wysylanie
  local sf = CreateFrame("Frame", nil, F)
  sf:SetPoint("TOPLEFT", 22, -94) sf:SetPoint("BOTTOMRIGHT", -22, 18)
  F.sendF = sf
  local function lab(text, anchor, dy)
    local l = U.Label(sf, text)
    if anchor then l:SetPoint("TOPLEFT", anchor, "BOTTOMLEFT", anchor.isEdit and -6 or 0, dy or -12) else l:SetPoint("TOPLEFT", 0, 0) end
    return l
  end
  local l1 = lab("DO KOGO")
  F.to = input(sf, 300) F.to:SetPoint("TOPLEFT", l1, "BOTTOMLEFT", 6, -4) F.to.isEdit = true
  local l2 = lab("TEMAT", F.to)
  F.subj = input(sf, 440) F.subj:SetPoint("TOPLEFT", l2, "BOTTOMLEFT", 6, -4) F.subj:SetMaxLetters(64) F.subj.isEdit = true
  local l3 = lab("TREŚĆ", F.subj)
  F.body = input(sf, 446, 150, true) F.body:SetPoint("TOPLEFT", l3, "BOTTOMLEFT", 0, -4)
  local l4 = lab("PIENIĄDZE (złoto, srebro, miedź)", F.body, -14)
  F.g = input(sf, 60) F.g:SetPoint("TOPLEFT", l4, "BOTTOMLEFT", 6, -4) F.g:SetNumeric(true)
  F.s = input(sf, 50) F.s:SetPoint("LEFT", F.g, "RIGHT", 12, 0) F.s:SetNumeric(true) F.s:SetMaxLetters(2)
  F.c = input(sf, 50) F.c:SetPoint("LEFT", F.s, "RIGHT", 12, 0) F.c:SetNumeric(true) F.c:SetMaxLetters(2)
  F.att = U.Para(sf, 12, 446, C.muted)
  F.att:SetPoint("TOPLEFT", F.g, "BOTTOMLEFT", -6, -14)
  F.cost = U.Text(sf, 12, "body", C.faint)
  F.cost:SetPoint("TOPLEFT", F.att, "BOTTOMLEFT", 0, -10)
  local sb = U.Button(sf, "Wyślij", nil, 30, true)
  sb:SetPoint("TOPLEFT", F.cost, "BOTTOMLEFT", 0, -12)
  sb:SetScript("OnClick", send)
  local bh = U.H2(sf, "Plecak")
  bh:SetPoint("TOPLEFT", 480, 0)
  local bv = CreateFrame("ScrollFrame", nil, sf)
  bv:SetPoint("TOPLEFT", bh, "BOTTOMLEFT", 0, -10) bv:SetPoint("BOTTOMRIGHT")
  F.bag = CreateFrame("Frame", nil, bv) F.bag:SetSize(440, 10)
  bv:SetScrollChild(F.bag)
  bv:EnableMouseWheel(true)
  bv:SetScript("OnMouseWheel", function(self, d)
    local max = math.max(0, F.bag:GetHeight() - self:GetHeight())
    self:SetVerticalScroll(math.max(0, math.min(max, self:GetVerticalScroll() - d * 76)))
  end)
  F.bag.slots = {}
  sf:Hide()
end

local ev = CreateFrame("Frame")
for _, e in ipairs({ "MAIL_SHOW", "MAIL_CLOSED", "MAIL_INBOX_UPDATE", "MAIL_SEND_INFO_UPDATE", "MAIL_SEND_SUCCESS",
  "BAG_UPDATE_DELAYED", "PLAYER_MONEY" }) do pcall(ev.RegisterEvent, ev, e) end
ev:SetScript("OnEvent", function(_, e)
  if e == "MAIL_SHOW" then
    C_Timer.After(0.05, function()
      build()
      pcall(function()
        U.diag("poczta", { n = U.raw(GetInboxNumItems), first = U.raw(GetInboxHeaderInfo, 1) })
      end)
      S.tab, S.sel = "in", nil
      if F:Open() then U.pocztaDraw() end
    end)
  elseif e == "MAIL_CLOSED" then
    if F then F:Finish() end
  elseif F and F:IsShown() then
    if F.q then return end
    F.q = true
    C_Timer.After(0.25, function() F.q = nil U.pocztaDraw() end)
  end
end)
