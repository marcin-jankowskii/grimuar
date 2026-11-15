-- Grimuar UI: Lup jako karty (15.11, propozycja 3; gracz: „te wszystkie mozesz zrobic”, rzuty: „podpowiedz + przyciski”).
-- 1) Okno lupu (LOOT_OPENED bez automatycznego lupu) w stylu huba zamiast okna gry (LootFrame, przezroczystosc 0,
--    Okna/Wspolne.lua): wiersz = ikona w kolorze jakosci, nazwa, liczba i powod: ◆ potrzebne do poradnika, ulepszenie
--    wg Pawna (+N%), do zadania, smiec (sprzeda sie sam u kupca). Klik zabiera, „Zabierz wszystko”.
-- 2) Rzuty w grupie (START_LOOT_ROLL): karta przedmiotu z podpowiedzia wg buildu i przyciskami Potrzeba / Chciwosc /
--    Rozczaruj / Odpusc; podpowiedziany przycisk jest zloty. Nic nie rzuca samo: klikasz Ty (RollOnLoot, zwykla funkcja gry).
--    Karta przykrywa ramke rzutu gry (GroupLootFrameN, tylko przezroczystosc 0), a bez niej stoi nad paskami.
-- Wylaczenie: /hub okna lup (okno lupu) i /hub okna rzuty (karty rzutow).
local ADDON, U = ...
local C = U.C
local G = U.G or {}

local function itemID(link) return link and tonumber(tostring(link):match("item:(%d+)")) or nil end
local function money(c) return U.money and U.money(c) or tostring(c) end

-- Pawn: strzalka ulepszenia i procent (pierwsza skala)
local function pawn(link)
  if not link then return false end
  local up = false
  local f = _G.PawnShouldItemLinkHaveUpgradeArrow
  if type(f) == "function" then
    local ok, r = pcall(f, link, true)
    up = ok and r and true or false
  end
  local pct
  if up and type(_G.PawnGetItemData) == "function" and type(_G.PawnIsItemAnUpgrade) == "function" then
    pcall(function()
      local d = PawnGetItemData(link)
      local info = d and PawnIsItemAnUpgrade(d)
      local p = type(info) == "table" and info[1] and U.num(info[1].PercentUpgrade)
      if p and p > 0 then pct = math.floor(p * 100 + 0.5) end
    end)
  end
  return up, pct
end

-- ---------- 1) okno lupu ----------
local F
local items = {}

local function lootItems()
  wipe(items)
  for slot = 1, U.num(U.call(GetNumLootItems)) or 0 do
    local ok, tex, name, qty, _, quality, _, isQuest = pcall(GetLootSlotInfo, slot)
    if ok and tex then
      local kind = U.call(GetLootSlotType, slot)
      local link = U.call(GetLootSlotLink, slot)
      local id = itemID(link)
      local why, col = "", C.faint
      if kind == 2 or (Enum and Enum.LootSlotType and kind == Enum.LootSlotType.Money) then
        why, col = "pieniądze", C.gold
      elseif isQuest then
        why, col = "do zadania", C.gold
      elseif id then
        local need = G.itemNeed and G.itemNeed(id)
        local up, pct = pawn(link)
        if up then why, col = "ulepszenie dla buildu" .. (pct and (" +" .. pct .. "%") or "") .. " (Pawn)", C.ok
        elseif need then why, col = "◆ " .. tostring(need), C.ok
        elseif G.itemIsJunk and G.itemIsJunk(id, quality) then why, col = "śmieć: sprzeda się sam u kupca", C.faint end
      end
      items[#items + 1] = { slot = slot, tex = tex, name = name, qty = U.num(qty) or 1, quality = quality, link = link, why = why, col = col }
    end
  end
  return items
end

function U.lupDraw()
  if not (F and F:IsShown()) then return end
  local ok, err = pcall(function()
    local list = lootItems()
    F.sub:SetText(#list .. (#list == 1 and " rzecz" or " rzeczy"))
    F.list:Fill(#list, function(r, n)
      local it = list[n]
      r.slot.icon:SetTexture(it.tex or 134400)
      r.slot.icon:SetDesaturated(false)
      r.slot:SetQuality(it.quality)
      r.slot.count:SetText(it.qty > 1 and it.qty or "")
      r.t:SetText(it.name or "?")
      local qc = U.QUALITY[it.quality or 1] or C.text
      U.Color(r.t, qc)
      r.s:SetText("")
      r.why:SetText(it.why or "") U.Color(r.why, it.col or C.faint)
      r.r:SetText("")
      r.onClick = function(button)
        if IsModifiedClick("CHATLINK") and it.link then pcall(ChatEdit_InsertLink, it.link) return end
        pcall(LootSlot, it.slot)
      end
      r.tip = function(tt) pcall(tt.SetLootItem, tt, it.slot) end
    end)
  end)
  if not ok then F:Fail(err) end
end

local function buildLoot()
  if F then return end
  F = U.Okno({ name = "GrimuarLup", width = 440, height = 420, title = "Łup", key = "lup",
    hosts = { "LootFrame" }, onClose = function() U.call(CloseLoot) end })
  F.all = U.Button(F, "Zabierz wszystko", nil, 26, true)
  F.all:SetPoint("TOPLEFT", 22, -56)
  F.all:SetScript("OnClick", function()
    for slot = U.num(U.call(GetNumLootItems)) or 0, 1, -1 do pcall(LootSlot, slot) end
  end)
  local hint = U.Text(F, 11, "body", C.faint)
  hint:SetPoint("LEFT", F.all, "RIGHT", 12, 0)
  hint:SetText("klik: zabierz · Shift: do czatu")
  F.list = U.OknoList(F, 44, function(p) return U.OknoRow(p, 44) end)
  F.list:SetPoint("TOPLEFT", 22, -94) F.list:SetPoint("BOTTOMRIGHT", -22, 18)
end

local lev = CreateFrame("Frame")
for _, e in ipairs({ "LOOT_OPENED", "LOOT_SLOT_CLEARED", "LOOT_SLOT_CHANGED", "LOOT_CLOSED" }) do pcall(lev.RegisterEvent, lev, e) end
lev:SetScript("OnEvent", function(_, e, autoLoot)
  if e == "LOOT_OPENED" then
    if autoLoot then return end
    C_Timer.After(0, function()
      buildLoot()
      pcall(function() U.diag("lup", { n = U.num(U.call(GetNumLootItems)), first = U.raw(GetLootSlotInfo, 1) }) end)
      if F:Open() then U.lupDraw() end
    end)
  elseif e == "LOOT_CLOSED" then
    if F then F:Finish() end
  elseif F and F:IsShown() then
    if F.q then return end
    F.q = true
    C_Timer.After(0.1, function() F.q = nil U.lupDraw() end)
  end
end)

-- ---------- 2) rzuty w grupie ----------
local cards, pool = {}, {}

local function hasEnchanting()
  local p = U.call(G.readProfs) or {}
  return p.Enchanting ~= nil
end

-- podpowiedz: "need" | "greed" | "de" | "pass", powod
local function advise(r)
  local up, pct = pawn(r.link)
  local need = r.id and G.itemNeed and G.itemNeed(r.id)
  if up and r.canNeed then return "need", "ulepszenie dla buildu" .. (pct and (" +" .. pct .. "%") or "") .. " (Pawn)" end
  if need and r.canGreed then return "greed", "◆ " .. tostring(need) end
  if r.canDE and hasEnchanting() then return "de", "rozczaruj: materiały do Zaklinania" end
  if r.canGreed then
    local sell = r.id and select(11, U.call(C_Item and C_Item.GetItemInfo or GetItemInfo, r.id))
    return "greed", "nie dla Twojego buildu" .. ((U.num(sell) or 0) > 0 and (": sprzedasz za " .. money(sell)) or "")
  end
  return "pass", "nie możesz rzucić na potrzebę ani chciwość"
end

local function blizzFrame(rollID)
  for i = 1, 4 do
    local f = _G["GroupLootFrame" .. i]
    if f and f:IsShown() and f.rollID == rollID then return f end
  end
end

local BTN = { { "need", "Potrzeba", 1 }, { "greed", "Chciwość", 2 }, { "de", "Rozczaruj", 3 }, { "pass", "Odpuść", 0 } }

local function makeCard()
  local f = CreateFrame("Frame", nil, UIParent)
  f:SetSize(480, 92)
  f:SetFrameStrata("DIALOG")
  f:EnableMouse(true)
  f:SetClampedToScreen(true)
  f.bg = U.Rect(f, C.bg, 0.96) f.bg:SetAllPoints()
  U.Border(f, C.edge, 0.8)
  U.Corners(f, C.gold, 10, 2)
  f.slot = U.Slot(f, 44)
  f.slot:SetPoint("TOPLEFT", 12, -12)
  f.slot:SetScript("OnEnter", function(self)
    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
    pcall(GameTooltip.SetLootRollItem, GameTooltip, f.rollID)
    GameTooltip:Show()
  end)
  f.slot:SetScript("OnLeave", function() GameTooltip:Hide() end)
  f.slot:SetScript("OnClick", function()
    if IsModifiedClick("CHATLINK") and f.link then pcall(ChatEdit_InsertLink, f.link)
    elseif IsModifiedClick("DRESSUP") and f.link then pcall(DressUpItemLink, f.link) end
  end)
  f.name = U.Text(f, 14, "body", C.text)
  f.name:SetPoint("TOPLEFT", f.slot, "TOPRIGHT", 10, -1)
  f.name:SetPoint("RIGHT", -12, 0)
  f.name:SetJustifyH("LEFT")
  f.why = U.Text(f, 11, "body", C.muted)
  f.why:SetPoint("TOPLEFT", f.name, "BOTTOMLEFT", 0, -3)
  f.why:SetPoint("RIGHT", -12, 0)
  f.why:SetJustifyH("LEFT")
  f.btns = {}
  local prev
  for _, d in ipairs(BTN) do
    local b = U.Button(f, d[2], 92, 22)
    local bp = U.Button(f, d[2], 92, 22, true)
    for _, x in ipairs({ b, bp }) do
      if prev then x:SetPoint("LEFT", prev, "RIGHT", 6, 0) else x:SetPoint("TOPLEFT", f.slot, "BOTTOMRIGHT", 10, 18) end
      x:SetScript("OnClick", function()
        pcall(RollOnLoot, f.rollID, d[3])
        U.rollDone(f.rollID)
      end)
    end
    f.btns[d[1]] = { b, bp }
    prev = b
  end
  f.bar = U.Bar(f, 4, C.gold)
  f.bar:SetPoint("BOTTOMLEFT", 12, 8) f.bar:SetPoint("BOTTOMRIGHT", -12, 8)
  f:SetScript("OnUpdate", function(self, el)
    self.t = (self.t or 0) + el
    if self.t < 0.2 then return end
    self.t = 0
    local left = U.num(U.call(GetLootRollTimeLeft, self.rollID)) or 0
    self.bar:SetValue(self.total and self.total > 0 and left / self.total or 0)
    if left <= 0 and (self.shownAt or 0) + 2 < GetTime() then U.rollDone(self.rollID) end
  end)
  return f
end

local function layout()
  local y = 230
  for _, f in ipairs(cards) do
    f:ClearAllPoints()
    if f.host then f:SetPoint("CENTER", f.host, "CENTER", 0, 0)
    else
      f:SetPoint("BOTTOM", UIParent, "BOTTOM", 0, y)
      y = y + 100
    end
  end
end

function U.rollDone(rollID)
  for i = #cards, 1, -1 do
    local f = cards[i]
    if f.rollID == rollID then
      if f.host then pcall(f.host.SetAlpha, f.host, 1) end
      f.host = nil
      f:Hide()
      table.remove(cards, i)
      pool[#pool + 1] = f
    end
  end
  layout()
end

local function showRoll(rollID, rollTime)
  if not U.oknoOn("rzuty") then return end
  local ok, tex, name, cnt, quality, bop, canNeed, canGreed, canDE = pcall(GetLootRollItemInfo, rollID)
  if not ok or not name then return end
  local link = U.call(GetLootRollItemLink, rollID)
  local r = { link = link, id = itemID(link), canNeed = canNeed, canGreed = canGreed, canDE = canDE }
  local rec, why = advise(r)
  local f = table.remove(pool) or makeCard()
  f.rollID, f.link, f.total, f.shownAt = rollID, link, U.num(rollTime) or 60000, GetTime()
  f.slot.icon:SetTexture(tex or 134400)
  f.slot:SetQuality(quality)
  f.slot.count:SetText((U.num(cnt) or 1) > 1 and cnt or "")
  f.name:SetText((name or "?") .. (bop and "  |cff8a8374(przypisany po podniesieniu)|r" or ""))
  U.Color(f.name, U.QUALITY[quality or 1] or C.text)
  f.why:SetText("Podpowiedź: " .. (rec == "need" and "Potrzeba" or rec == "greed" and "Chciwość" or rec == "de" and "Rozczaruj" or "Odpuść") .. " · " .. why)
  local can = { need = canNeed, greed = canGreed, de = canDE, pass = true }
  local prev
  for _, d in ipairs(BTN) do
    local b, bp = f.btns[d[1]][1], f.btns[d[1]][2]
    local use = (d[1] == rec) and bp or b
    b:Hide() bp:Hide()
    if can[d[1]] then
      use:ClearAllPoints()
      if prev then use:SetPoint("LEFT", prev, "RIGHT", 6, 0) else use:SetPoint("TOPLEFT", f.slot, "BOTTOMRIGHT", 10, 18) end
      use:Show()
      prev = use
    end
  end
  f.host = blizzFrame(rollID)
  if f.host then pcall(f.host.SetAlpha, f.host, 0) end
  f:Show()
  cards[#cards + 1] = f
  layout()
  pcall(function() U.diag("rzuty", { first = U.raw(GetLootRollItemInfo, rollID), host = f.host and (f.host:GetName() or "?") or "brak" }) end)
end

local rev = CreateFrame("Frame")
for _, e in ipairs({ "START_LOOT_ROLL", "CANCEL_LOOT_ROLL", "CANCEL_ALL_LOOT_ROLLS" }) do pcall(rev.RegisterEvent, rev, e) end
rev:SetScript("OnEvent", function(_, e, rollID, rollTime)
  if e == "START_LOOT_ROLL" then
    -- ramka gry dostaje rollID w tym samym zdarzeniu: chwila na jej pokazanie
    C_Timer.After(0.05, function() pcall(showRoll, rollID, rollTime) end)
  elseif e == "CANCEL_LOOT_ROLL" then
    U.rollDone(rollID)
  else
    for i = #cards, 1, -1 do U.rollDone(cards[i].rollID) end
  end
end)

U.testChecksExtra = U.testChecksExtra or {}
table.insert(U.testChecksExtra, { "łup i rzuty", function()
  local d = U.db().diag or {}
  local parts = {}
  if d.lup then
    local q = select(5, strsplit("|", ((d.lup.first or ""):gsub(" | ", "|"))))
    if d.lup.first and not d.lup.first:find("^brak") and (U.num(d.lup.n) or 0) > 0 and not tonumber(q or "") then
      error("okno łupu: jakość nie jest 5. wartością: " .. tostring(d.lup.first))
    end
    parts[#parts + 1] = "łup: dane z " .. d.lup.at
  else parts[#parts + 1] = "łup: jeszcze nie otwierany ręcznie" end
  if d.rzuty then parts[#parts + 1] = "rzuty: dane z " .. d.rzuty.at .. ", ramka gry " .. tostring(d.rzuty.host)
  else parts[#parts + 1] = "rzuty: jeszcze żadnego w grupie" end
  return table.concat(parts, "; ")
end })
