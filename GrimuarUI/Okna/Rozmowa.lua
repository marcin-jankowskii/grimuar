-- Grimuar UI: Rozmowa z NPC i questy w stylu huba (15.11, plan R29 etap 2, wybor gracza „Rozmowa z NPC” jako pierwsze
-- okno; makieta „Okna Grimuara”). Zamiast GossipFrame i QuestFrame (Blizzard, splaszczone przez ForeverSkin):
-- * lewa kolumna: portret i imie NPC, tekst na pergaminie (powitanie, tresc zadania, postep, zakonczenie), cele, wybory
--   z numerami 1–9 (opcje rozmowy, questy do wziecia i oddania), przyciski Przyjmij / Odrzuc / Oddaj / Dalej;
-- * prawa kolumna: nagrody jako karty (ikona, nazwa w kolorze jakosci, dymek gry); przy wyborze nagrody Grimuar zaznacza
--   najlepsza: ulepszenie wg Pawna (skala buildu), inaczej najdrozsza u kupca; XP i zloto; kontekst (poziom zadania,
--   krok Polestara).
-- Okno Blizzarda zostaje pod spodem z przezroczystoscia 0 (jak menu Esc, MenuPelne.lua); nasze jest do niego
-- przyczepione i wieksze, wiec przykrywa je calkiem i lapie kazde klikniecie. Akcje przez zwykle funkcje gry
-- (AcceptQuest, DeclineQuest, CompleteQuest, GetQuestReward, SelectAvailableQuest, C_GossipInfo.*), nic chronionego.
-- „Klasyczne okno” pokazuje okno gry do konca tej rozmowy; /hub rozmowa wylacza na stale. Klawisze 1–9 i Spacja
-- tylko poza walka (w walce klawiatura zostaje grze).
local ADDON, U = ...
local C = U.C
local G = U.G or {}

local R = { mode = nil, sel = nil, classic = false, rows = {}, rew = {} }
local W, H, RW = 1080, 600, 350
local PARCH, INK, INK2 = { 0.91, 0.86, 0.75 }, { 0.23, 0.17, 0.09 }, { 0.38, 0.29, 0.16 }

local function db() return U.db() end
local function on() return db().rozmowaTryb ~= false end
local function blizz() return _G.QuestFrame, _G.GossipFrame end
local function showBlizz(alpha)
  local q, g = blizz()
  if q then pcall(q.SetAlpha, q, alpha) end
  if g then pcall(g.SetAlpha, g, alpha) end
end
local function call(fn, ...) return U.call(fn, ...) end
-- 15.11 (gracz: „samo mi przyjelo questa i jak klikam Przyjmij, to nie znika okno”): Polestar sam przyjmuje questy
-- z trasy (Core\Automation.lua, AcceptQuest w srodku QUEST_DETAIL), wiec QUEST_FINISHED przychodzi PRZED naszym
-- QUEST_DETAIL i Grimuar otwieral juz puste okno. Rozmowa „zyje” tylko, gdy okno gry jest otwarte i ma dane.
local function live(mode)
  local q, g = blizz()
  if mode == "gossip" then return (g and g:IsShown()) and true or false end
  if not (q and q:IsShown()) then return false end
  if mode == "greeting" then return true end
  local title = call(GetTitleText)
  return type(title) == "string" and title ~= ""
end

-- ---------- budowa ----------
local F
local function choiceRow(i)
  local r = R.rows[i]
  if r then return r end
  r = CreateFrame("Button", nil, F.left)
  r:SetHeight(26)
  local hl = r:CreateTexture(nil, "HIGHLIGHT")
  hl:SetAllPoints()
  hl:SetColorTexture(C.gold[1], C.gold[2], C.gold[3], 0.10)
  r.key = U.Text(r, 11, "body", C.gold)
  r.key:SetPoint("LEFT", 4, 0) r.key:SetWidth(18) r.key:SetJustifyH("CENTER") r.key:SetJustifyV("MIDDLE")
  r.ic = r:CreateTexture(nil, "ARTWORK")
  r.ic:SetSize(16, 16) r.ic:SetPoint("LEFT", 28, 0)
  r.t = U.Text(r, 14, "body", C.text)
  r.t:SetPoint("LEFT", 52, 0) r.t:SetPoint("RIGHT", -110, 0) r.t:SetJustifyV("MIDDLE")
  r.note = U.Text(r, 11, "body", C.faint)
  r.note:SetPoint("RIGHT", -6, 0) r.note:SetJustifyH("RIGHT") r.note:SetJustifyV("MIDDLE")
  r:SetScript("OnClick", function(self) if self.act then pcall(self.act) end end)
  R.rows[i] = r
  return r
end

local function rewardCard(i)
  local c = R.rew[i]
  if c then return c end
  c = CreateFrame("Button", nil, F.right)
  c:SetSize(RW - 36, 46)
  c.bg = U.Rect(c, C.panel2, 0.8) c.bg:SetAllPoints()
  U.Border(c, C.line)
  c.slot = U.Slot(c, 38)
  c.slot:SetPoint("LEFT", 4, 0)
  c.slot:EnableMouse(false)
  c.t = U.Text(c, 13, "body", C.text)
  c.t:SetPoint("TOPLEFT", c.slot, "TOPRIGHT", 8, -2) c.t:SetPoint("RIGHT", -70, 0)
  c.s = U.Text(c, 11, "body", C.faint)
  c.s:SetPoint("TOPLEFT", c.t, "BOTTOMLEFT", 0, -3) c.s:SetPoint("RIGHT", -70, 0)
  c.r = U.Text(c, 11, "body", C.ok)
  c.r:SetPoint("RIGHT", -8, 0) c.r:SetJustifyH("RIGHT") c.r:SetJustifyV("MIDDLE")
  c:SetScript("OnEnter", function(self)
    if not self.kind then return end
    U.TT:SetOwner(self, "ANCHOR_RIGHT")
    pcall(U.TT.SetQuestItem, U.TT, self.kind, self.idx)
    U.TT:Show()
  end)
  c:SetScript("OnLeave", function() U.TT:Hide() end)
  c:SetScript("OnClick", function(self)
    if self.kind == "choice" then R.sel = self.idx U.rozmowaDraw() end
  end)
  R.rew[i] = c
  return c
end

local function build()
  if F then return end
  F = CreateFrame("Frame", "GrimuarRozmowa", UIParent)
  F:SetSize(W, H)
  F:SetFrameStrata("DIALOG")
  F:SetToplevel(true)
  F:EnableMouse(true)
  F:Hide()
  F.bg = U.Rect(F, C.bg, 0.97) F.bg:SetAllPoints()
  U.Border(F, C.edge, 0.7)
  U.Corners(F, C.gold, 16, 2)
  -- lewo
  F.left = CreateFrame("Frame", nil, F)
  F.left:SetPoint("TOPLEFT", 22, -18)
  F.left:SetPoint("BOTTOMRIGHT", F, "BOTTOMRIGHT", -RW - 22, 18)
  F.por = F.left:CreateTexture(nil, "ARTWORK")
  F.por:SetSize(60, 60) F.por:SetPoint("TOPLEFT", 0, 0)
  F.porEdge = CreateFrame("Frame", nil, F.left)
  F.porEdge:SetAllPoints(F.por)
  U.Border(F.porEdge, C.edge)
  F.name = U.Text(F.left, 22, "title", C.gold)
  F.name:SetPoint("TOPLEFT", F.por, "TOPRIGHT", 14, -6)
  F.sub = U.Text(F.left, 12, "body", C.muted)
  F.sub:SetPoint("TOPLEFT", F.name, "BOTTOMLEFT", 0, -6)
  F.close = U.Button(F, "×", 26, 24)
  F.close:SetPoint("TOPRIGHT", -10, -10)
  F.close:SetScript("OnClick", function() U.rozmowaClose() end)
  -- pergamin
  F.parch = CreateFrame("Frame", nil, F.left)
  F.parch:SetPoint("TOPLEFT", F.por, "BOTTOMLEFT", 0, -14)
  F.parch:SetPoint("RIGHT", F.left, "RIGHT", 0, 0)
  F.parch:SetHeight(250)
  F.parch.bg = U.Rect(F.parch, PARCH, 1) F.parch.bg:SetAllPoints()
  F.parch.shade = F.parch:CreateTexture(nil, "BORDER")
  F.parch.shade:SetAllPoints()
  F.parch.shade:SetColorTexture(1, 1, 1, 1)
  pcall(F.parch.shade.SetGradient, F.parch.shade, "VERTICAL", CreateColor(0.72, 0.6, 0.4, 0.35), CreateColor(1, 1, 1, 0))
  U.Border(F.parch, C.goldDim, 0.9)
  local view = CreateFrame("ScrollFrame", nil, F.parch)
  view:SetPoint("TOPLEFT", 18, -14) view:SetPoint("BOTTOMRIGHT", -14, 12)
  F.pchild = CreateFrame("Frame", nil, view)
  F.pchild:SetSize(500, 10)
  view:SetScrollChild(F.pchild)
  view:EnableMouseWheel(true)
  view:SetScript("OnMouseWheel", function(self, d)
    local max = math.max(0, F.pchild:GetHeight() - self:GetHeight())
    self:SetVerticalScroll(math.max(0, math.min(max, self:GetVerticalScroll() - d * 50)))
  end)
  F.pview = view
  F.ptitle = U.Text(F.pchild, 18, "title", { 0.35, 0.24, 0.08 })
  F.ptitle:SetPoint("TOPLEFT", 0, 0)
  F.ptext = U.Para(F.pchild, 15, 500, INK)
  F.ptext:SetPoint("TOPLEFT", F.ptitle, "BOTTOMLEFT", 0, -8)
  F.ptext:SetSpacing(4)
  F.pobjH = U.Text(F.pchild, 13, "title", { 0.35, 0.24, 0.08 })
  F.pobj = U.Para(F.pchild, 14, 500, INK2)
  F.pobj:SetSpacing(3)
  -- wybory i przyciski
  F.choices = CreateFrame("Frame", nil, F.left)
  F.choices:SetPoint("TOPLEFT", F.parch, "BOTTOMLEFT", 0, -10)
  F.choices:SetPoint("RIGHT", F.left, "RIGHT", 0, 0)
  F.choices:SetHeight(10)
  F.acts = {}
  local prev
  for i, k in ipairs({ "main", "second", "third" }) do
    local b = U.Button(F.left, "", nil, 30, i == 1)
    if prev then b:SetPoint("LEFT", prev, "RIGHT", 8, 0) else b:SetPoint("BOTTOMLEFT", F.left, "BOTTOMLEFT", 0, 0) end
    b:SetScript("OnClick", function(self)
      if self.act then pcall(self.act) end
      -- 15.11: gdy rozmowa juz sie skonczyla (np. Polestar przyjal quest sam), przycisk zamyka puste okno
      C_Timer.After(0.3, function() if F:IsShown() and not live(R.mode) then F:Hide() R.mode, R.sel = nil, nil showBlizz(1) end end)
    end)
    F.acts[k] = b
    prev = b
  end
  F.classic = U.Button(F.left, "klasyczne okno", nil, 26)
  F.classic:SetPoint("BOTTOMRIGHT", F.left, "BOTTOMRIGHT", 0, 2)
  F.classic:SetScript("OnClick", function()
    R.classic = true
    F:Hide()
    showBlizz(1)
  end)
  -- prawo
  F.right = CreateFrame("Frame", nil, F)
  F.right:SetPoint("TOPRIGHT", -12, -46)
  F.right:SetPoint("BOTTOMRIGHT", -12, 18)
  F.right:SetWidth(RW)
  F.sep = F:CreateTexture(nil, "ARTWORK")
  F.sep:SetColorTexture(C.gold[1], C.gold[2], C.gold[3], 0.22)
  F.sep:SetWidth(1)
  F.sep:SetPoint("TOPRIGHT", F.right, "TOPLEFT", -10, 30)
  F.sep:SetPoint("BOTTOMRIGHT", F.right, "BOTTOMLEFT", -10, 0)
  F.rH = U.H2(F.right, "Nagrody")
  F.rH:SetPoint("TOPLEFT", 10, 0)
  F.rNote = U.Para(F.right, 12, RW - 30, C.muted)
  F.money = U.Text(F.right, 13, "body", C.text)
  F.ctxH = U.H2(F.right, "Grimuar")
  F.ctx = U.Para(F.right, 12, RW - 30, C.muted)
  F.ctx:SetSpacing(3)
  -- klawisze 1–9 i Spacja poza walka
  -- klawisz obsluzony: tylko ten jeden nie idzie dalej, zaraz potem klawiatura znowu przechodzi do gry
  pcall(F.EnableKeyboard, F, true)
  pcall(F.SetPropagateKeyboardInput, F, true)
  F:SetScript("OnKeyDown", function(self, key)
    if InCombatLockdown() then return end
    local handled = false
    local n = tonumber(key)
    if n and R.rows[n] and R.rows[n]:IsShown() and R.rows[n].act then pcall(R.rows[n].act) handled = true
    elseif key == "SPACE" and F.acts.main:IsShown() and F.acts.main.act then pcall(F.acts.main.act) handled = true end
    if handled then
      pcall(self.SetPropagateKeyboardInput, self, false)
      C_Timer.After(0, function() if not InCombatLockdown() then pcall(self.SetPropagateKeyboardInput, self, true) end end)
    end
  end)
end

-- ---------- dane ----------
local function npcName() return (call(UnitName, "npc")) or "?" end
local function zone() return (call(GetSubZoneText) ~= "" and call(GetSubZoneText)) or call(GetZoneText) or "" end
local function money(c)
  if U.money then return U.money(c) end
  return tostring(c)
end

-- najlepsza nagroda do wyboru: ulepszenie wg Pawna (skala buildu), inaczej najdrozsza u kupca
local function bestChoice(n)
  local best, bestV, upgrade = nil, -1, false
  for i = 1, n do
    local link = call(GetQuestItemLink, "choice", i)
    local up = false
    if link and type(_G.PawnShouldItemLinkHaveUpgradeArrow) == "function" then
      local ok, r = pcall(_G.PawnShouldItemLinkHaveUpgradeArrow, link, true)
      up = ok and r and true or false
    end
    local price = 0
    if link and C_Item and C_Item.GetItemInfo then
      local ok, v = pcall(function() return select(11, C_Item.GetItemInfo(link)) end)
      price = (ok and U.num(v)) or 0
    end
    if (up and not upgrade) or (up == upgrade and price > bestV) then best, bestV, upgrade = i, price, up end
  end
  return best, upgrade
end

local function polestarStep()
  local E = _G.Polestar and _G.Polestar.Engine
  if not (E and E.GetStepIndex and E.GetStepCount) then return nil end
  local ok, i = pcall(E.GetStepIndex)
  local ok2, n = pcall(E.GetStepCount)
  if ok and ok2 and U.num(i) and U.num(n) then return "Polestar: krok " .. i .. " z " .. n end
  return nil
end
local function questLevel(id)
  local DB = _G.QuestieDB
  if not (id and DB and DB.QueryQuestSingle) then return nil end
  local ok, lv = pcall(DB.QueryQuestSingle, id, "questLevel")
  return ok and U.num(lv) or nil
end

-- ---------- rysowanie ----------
local function setChoices(list)
  local y = 0
  for i, it in ipairs(list) do
    local r = choiceRow(i)
    r:ClearAllPoints()
    r:SetPoint("TOPLEFT", F.choices, "TOPLEFT", 0, -y)
    r:SetPoint("RIGHT", F.choices, "RIGHT", 0, 0)
    r.key:SetText(i <= 9 and tostring(i) or "")
    r.ic:SetShown(it.icon ~= nil)
    if it.icon then r.ic:SetTexture(it.icon) end
    r.t:SetText(it.text or "?")
    U.Color(r.t, it.col or C.text)
    r.note:SetText(it.note or "")
    r.act = it.act
    r:Show()
    y = y + 27
  end
  for i = #list + 1, #R.rows do R.rows[i]:Hide() end
  F.choices:SetHeight(math.max(1, y))
end
local function setActs(list)
  for i, k in ipairs({ "main", "second", "third" }) do
    local b, a = F.acts[k], list[i]
    b:SetShown(a ~= nil)
    if a then b:SetLabel(a[1]) b.act = a[2] end
  end
end
local function setParch(title, text, objH, obj)
  local w = math.max(300, (F.pview:GetWidth() or 500) - 6)
  F.pchild:SetWidth(w)
  F.ptext:SetWidth(w)
  F.pobj:SetWidth(w)
  F.ptitle:SetText(title or "")
  F.ptext:SetText(text or "")
  F.pobjH:ClearAllPoints()
  F.pobjH:SetPoint("TOPLEFT", F.ptext, "BOTTOMLEFT", 0, -12)
  F.pobjH:SetText(objH or "")
  F.pobjH:SetShown(objH ~= nil)
  F.pobj:ClearAllPoints()
  F.pobj:SetPoint("TOPLEFT", F.pobjH, "BOTTOMLEFT", 0, -4)
  F.pobj:SetText(obj or "")
  F.pobj:SetShown(obj ~= nil)
  local h = (F.ptitle:GetStringHeight() or 18) + 8 + (F.ptext:GetStringHeight() or 0) +
    (objH and (16 + (F.pobjH:GetStringHeight() or 14) + 4 + (F.pobj:GetStringHeight() or 0)) or 0) + 10
  F.pchild:SetHeight(h)
  F.pview:SetVerticalScroll(0)
end
local function setRewards(showChoose)
  local n = 0
  local y = 30
  local nc = U.num(call(GetNumQuestChoices)) or 0
  local nr = U.num(call(GetNumQuestRewards)) or 0
  local best, up = nil, false
  if nc > 1 then best, up = bestChoice(nc) end
  if showChoose and nc > 1 and not R.sel then R.sel = best end
  local function card(kind, i, label)
    local name, tex, count, quality = call(GetQuestItemInfo, kind, i)
    n = n + 1
    local c = rewardCard(n)
    c.kind, c.idx = kind, i
    c:ClearAllPoints() c:SetPoint("TOPLEFT", F.right, "TOPLEFT", 10, -y)
    c.slot.icon:SetTexture(tex or 134400)
    c.slot:SetQuality(U.num(quality))
    c.slot.count:SetText((U.num(count) or 1) > 1 and count or "")
    c.t:SetText(name or "…")
    local qc = U.QUALITY[U.num(quality) or 1] or C.text
    U.Color(c.t, qc)
    c.s:SetText(label or "")
    local isBest = kind == "choice" and i == best
    local isSel = kind == "choice" and i == R.sel
    c.r:SetText(isBest and (up and "▲ dla buildu" or "najdroższa") or "")
    U.BorderColor(c, isSel and C.gold or C.line)
    c:Show()
    y = y + 50
  end
  for i = 1, nc do card("choice", i, nc > 1 and (showChoose and "kliknij, żeby wybrać" or "jedna do wyboru") or "nagroda") end
  for i = 1, nr do card("reward", i, "dostaniesz też") end
  for i = n + 1, #R.rew do R.rew[i]:Hide() end
  local xp, gold = U.num(call(GetRewardXP)) or 0, U.num(call(GetRewardMoney)) or 0
  F.rNote:ClearAllPoints()
  F.rNote:SetPoint("TOPLEFT", F.right, "TOPLEFT", 10, -y - 2)
  F.rNote:SetText(n == 0 and "Bez przedmiotów." or (nc > 1 and (best and ("Grimuar zaznacza: " .. (up and "ulepszenie wg Pawna (skala buildu)." or "najdroższą u kupca (żadna nie jest ulepszeniem).")) or "") or ""))
  y = y + (F.rNote:GetStringHeight() or 0) + 10
  F.money:ClearAllPoints()
  F.money:SetPoint("TOPLEFT", F.right, "TOPLEFT", 10, -y)
  F.money:SetText((xp > 0 and ("Doświadczenie: +" .. U.thousands(xp) .. "   ") or "") .. (gold > 0 and ("Złoto: " .. money(gold)) or ""))
  return y + 24
end
local function setContext(y, lines)
  F.ctxH:ClearAllPoints()
  F.ctxH:SetPoint("TOPLEFT", F.right, "TOPLEFT", 10, -y - 10)
  F.ctx:ClearAllPoints()
  F.ctx:SetPoint("TOPLEFT", F.ctxH, "BOTTOMLEFT", 0, -6)
  local L = {}
  for _, l in ipairs(lines) do if l then L[#L + 1] = l end end
  F.ctx:SetText(table.concat(L, "\n"))
  F.ctxH:SetShown(#L > 0)
end
local function lvlLine(qid)
  local lv = questLevel(qid)
  if not lv then return nil end
  local me = UnitLevel("player") or 1
  local d = lv - me
  local col = d >= 3 and C.danger or (d <= -6 and C.faint or (d <= -3 and C.ok or C.gold))
  return U.hex(col) .. "Poziom zadania " .. lv .. "|r" .. (d <= -6 and " (szare: mało XP)" or (d >= 3 and " (trudne)" or ""))
end

function U.rozmowaDraw()
  if not (F and F:IsShown()) then return end
  local m = R.mode
  F.por:SetTexture(nil)
  pcall(SetPortraitTexture, F.por, "npc")
  F.name:SetText(npcName())
  F.sub:SetText(zone())
  if m == "gossip" then
    local GI = C_GossipInfo
    setParch(nil, call(GI.GetText) or "", nil, nil)
    local list = {}
    for _, q in ipairs(call(GI.GetActiveQuests) or {}) do
      list[#list + 1] = { text = q.title, icon = "Interface\\GossipFrame\\ActiveQuestIcon", note = q.isComplete and "do oddania" or "w toku",
        col = q.isComplete and C.gold or C.muted, act = function() GI.SelectActiveQuest(q.questID) end }
    end
    for _, q in ipairs(call(GI.GetAvailableQuests) or {}) do
      list[#list + 1] = { text = q.title, icon = "Interface\\GossipFrame\\AvailableQuestIcon", note = q.isTrivial and "szare" or "nowe zadanie",
        col = q.isTrivial and C.faint or C.text, act = function() GI.SelectAvailableQuest(q.questID) end }
    end
    local opts = call(GI.GetOptions) or {}
    table.sort(opts, function(a, b) return (a.orderIndex or 0) < (b.orderIndex or 0) end)
    for _, o in ipairs(opts) do
      list[#list + 1] = { text = o.name, icon = o.icon, act = function() GI.SelectOption(o.gossipOptionID) end }
    end
    setChoices(list)
    setActs({ { "Do widzenia", function() call(GI.CloseGossip) end } })
    for _, c in ipairs(R.rew) do c:Hide() end
    F.rNote:SetText("") F.money:SetText("")
    F.rH:SetText("Rozmowa")
    setContext(20, { #list > 0 and ("Wybierz numerem 1–" .. math.min(9, #list) .. " albo kliknij.") or nil, polestarStep() })
  elseif m == "greeting" then
    setParch(nil, call(GetGreetingText) or "", nil, nil)
    local list = {}
    for i = 1, U.num(call(GetNumActiveQuests)) or 0 do
      list[#list + 1] = { text = call(GetActiveTitle, i), icon = "Interface\\GossipFrame\\ActiveQuestIcon", note = "do oddania", col = C.gold, act = function() SelectActiveQuest(i) end }
    end
    for i = 1, U.num(call(GetNumAvailableQuests)) or 0 do
      list[#list + 1] = { text = call(GetAvailableTitle, i), icon = "Interface\\GossipFrame\\AvailableQuestIcon", note = "nowe zadanie", act = function() SelectAvailableQuest(i) end }
    end
    setChoices(list)
    setActs({ { "Do widzenia", function() call(CloseQuest) end } })
    for _, c in ipairs(R.rew) do c:Hide() end
    F.rNote:SetText("") F.money:SetText("")
    F.rH:SetText("Zadania")
    setContext(20, { polestarStep() })
  elseif m == "detail" then
    local qid = call(GetQuestID)
    setParch(call(GetTitleText), call(GetQuestText), "Cel", call(GetObjectiveText))
    setChoices({})
    setActs({ { "Przyjmij  (Spacja)", function() call(AcceptQuest) end }, { "Odrzuć", function() call(DeclineQuest) end } })
    F.rH:SetText("Nagrody")
    local y = setRewards(false)
    setContext(y, { lvlLine(qid), polestarStep() })
  elseif m == "progress" then
    local qid = call(GetQuestID)
    local can = call(IsQuestCompletable)
    local need = {}
    for i = 1, U.num(call(GetNumQuestItems)) or 0 do
      local name, _, count = call(GetQuestItemInfo, "required", i)
      if name then need[#need + 1] = (U.num(count) or 1) .. "× " .. name end
    end
    setParch(call(GetTitleText), call(GetProgressText), #need > 0 and "Do oddania" or nil, #need > 0 and table.concat(need, "\n") or nil)
    setChoices({})
    setActs({ can and { "Dalej  (Spacja)", function() call(CompleteQuest) end } or { "Jeszcze nie", function() call(CloseQuest) end },
      can and { "Później", function() call(CloseQuest) end } or nil })
    for _, c in ipairs(R.rew) do c:Hide() end
    F.rH:SetText("Postęp")
    F.rNote:ClearAllPoints() F.rNote:SetPoint("TOPLEFT", F.right, "TOPLEFT", 10, -30)
    F.rNote:SetText(can and "Masz wszystko: „Dalej” pokaże nagrody." or "Brakuje jeszcze celów.")
    F.money:SetText("")
    setContext(70, { lvlLine(qid), polestarStep() })
  elseif m == "complete" then
    local qid = call(GetQuestID)
    setParch(call(GetTitleText), call(GetRewardText), nil, nil)
    setChoices({})
    local nc = U.num(call(GetNumQuestChoices)) or 0
    F.rH:SetText(nc > 1 and "Wybierz nagrodę" or "Nagrody")
    local y = setRewards(true)
    setActs({ { "Oddaj  (Spacja)", function()
      local ch = nc > 1 and R.sel or (nc == 1 and 1 or 0)
      if nc > 1 and not ch then U.say("wybierz nagrodę.") return end
      call(GetQuestReward, ch)
    end } })
    setContext(y, { lvlLine(qid), polestarStep() })
  end
end

-- ---------- pokazanie ----------
local function place()
  local q, g = blizz()
  local host = (R.mode == "gossip" and g) or q
  F:ClearAllPoints()
  -- przyczepione do okna gry i wieksze od niego: przykrywa je calkiem (niewidoczne przyciski nie lapia klikniec)
  if host and host:GetLeft() then F:SetPoint("TOPLEFT", host, "TOPLEFT", -10, 30)
  else F:SetPoint("TOPLEFT", UIParent, "TOPLEFT", 8, -86) end
  local maxW = (UIParent:GetWidth() or 1400) - 16
  F:SetWidth(math.min(W, maxW))
end
local function open(mode)
  if not on() or R.classic then return end
  build()
  if R.mode ~= mode then R.sel = nil end
  R.mode = mode
  place()
  showBlizz(0)
  F:Show()
  F:Raise()
  local ok, err = pcall(U.rozmowaDraw)
  if not ok then
    -- blad: wraca okno gry, Grimuar mowi raz
    F:Hide()
    showBlizz(1)
    if not R.errSaid then R.errSaid = true U.say("okno rozmowy Grimuara: " .. tostring(err) .. " (zostaje okno gry).") end
  end
end
function U.rozmowaClose()
  if R.mode == "gossip" then call(C_GossipInfo.CloseGossip) else call(CloseQuest) end
  if F then F:Hide() end
  showBlizz(1)
end

local ev = CreateFrame("Frame")
for _, e in ipairs({ "GOSSIP_SHOW", "GOSSIP_CLOSED", "QUEST_GREETING", "QUEST_DETAIL", "QUEST_PROGRESS", "QUEST_COMPLETE",
  "QUEST_FINISHED", "QUEST_ACCEPTED", "QUEST_ITEM_UPDATE", "GET_ITEM_INFO_RECEIVED" }) do pcall(ev.RegisterEvent, ev, e) end
local MODE = { GOSSIP_SHOW = "gossip", QUEST_GREETING = "greeting", QUEST_DETAIL = "detail", QUEST_PROGRESS = "progress", QUEST_COMPLETE = "complete" }
ev:SetScript("OnEvent", function(_, e)
  if MODE[e] then
    -- nastepna strona tej samej rozmowy: po klatce, gdy gra juz podmienila dane; nic, gdy rozmowa juz sie skonczyla
    C_Timer.After(0, function()
      if live(MODE[e]) then open(MODE[e])
      elseif F and F:IsShown() and not live(R.mode) then F:Hide() R.mode, R.sel = nil, nil showBlizz(1) end
    end)
  elseif e == "GOSSIP_CLOSED" or e == "QUEST_FINISHED" or e == "QUEST_ACCEPTED" then
    C_Timer.After(0, function()
      local q, g = blizz()
      local still = (q and q:IsShown()) or (g and g:IsShown())
      if not still then
        if F then F:Hide() end
        R.mode, R.sel, R.classic = nil, nil, false
        showBlizz(1)
      end
    end)
  elseif (e == "QUEST_ITEM_UPDATE" or e == "GET_ITEM_INFO_RECEIVED") and F and F:IsShown() then
    if R.q then return end
    R.q = true
    C_Timer.After(0.3, function() R.q = nil pcall(U.rozmowaDraw) end)
  end
end)

-- /hub rozmowa: wlacza i wylacza
function U.rozmowaCmd()
  local d = db()
  d.rozmowaTryb = d.rozmowaTryb == false
  U.say(d.rozmowaTryb ~= false and "rozmowy z NPC w oknie Grimuara." or "rozmowy z NPC w oknie gry.")
end
if U.G then U.G.rozmowaCmd = U.rozmowaCmd end
