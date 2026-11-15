-- Grimuar UI: pas podreczny (15.11, research R28 P11, makieta „Ekwipunek Grimuara” wariant D). Nad paskami akcji:
-- picie, jedzenie, bandaz, mikstura leczenia i Hearthstone z liczba w torbach i odnowieniem. Najlepsze picie i jedzenie
-- wybiera Grimuar (G.scanDrinks, G.scanFood z GrimuarSetup Core.lua), bandaz i mikstura po nazwie.
-- Przyciski bezpieczne (SecureActionButtonTemplate, typ „item”): przedmiot ustawiany tylko poza walka; w walce zmieniaja
-- sie tylko liczby. Nad pasem: „starczy na ok. N walk” z Twojego zuzycia w tej sesji (picie i jedzenie na walke).
-- Zawsze widoczny (nic nie znika): przygaszony poza walka, pelny w walce, pod mysza i gdy czegos brakuje.
-- /hub pas wlacza i wylacza (wylaczony: przezroczysty i bez klikniec po wyjsciu z walki).
local ADDON, U = ...
local C = U.C
local G = U.G or {}

local HEARTH = 6948
local SLOTS = { "drink", "food", "band", "pot", "hearth" }
local LABEL = { drink = "picie", food = "jedzenie", band = "bandaż", pot = "mikstura", hearth = "dom" }
local P
local K = { fights = 0, usedD = 0, usedF = 0, lastD = nil, lastF = nil, combat = false, low = false }

local function db() return U.db() end
local function on() return db().pasTryb ~= false end
local function count(id) return U.num(U.call(C_Item and C_Item.GetItemCount or GetItemCount, id, false)) or 0 end

-- najlepszy przedmiot w torbach dla slotu: { id, n } albo nil
local function bagScanByName(pattern)
  local best
  for bag = 0, (NUM_BAG_SLOTS or 4) do
    for slot = 1, U.num(U.call(C_Container.GetContainerNumSlots, bag)) or 0 do
      local info = U.call(C_Container.GetContainerItemInfo, bag, slot)
      if type(info) == "table" and info.itemID then
        local nm = U.call(C_Item.GetItemNameByID, info.itemID) or ""
        if nm:find(pattern) and (not best or info.itemID > best.id) then best = { id = info.itemID, name = nm } end
      end
    end
  end
  return best
end
local function pick(kind)
  if kind == "drink" or kind == "food" then
    local scan = kind == "drink" and G.scanDrinks or G.scanFood
    local best
    for _, d in ipairs(scan and U.call(scan) or {}) do
      if not best or (d.score or 0) > (best.score or 0) then best = d end
    end
    return best and { id = best.id, name = best.name } or nil
  elseif kind == "band" then return bagScanByName("Bandage")
  elseif kind == "pot" then return bagScanByName("Healing Potion")
  elseif kind == "hearth" then return count(HEARTH) > 0 and { id = HEARTH, name = "Hearthstone" } or nil end
end

-- ---------- budowa ----------
local function build()
  if P then return end
  P = CreateFrame("Frame", "GrimuarPas", UIParent)
  P:SetSize(5 * 44 + 4 * 6, 66)
  P:SetPoint("BOTTOM", UIParent, "BOTTOM", 0, 166)
  P:SetFrameStrata("MEDIUM")
  P.info = U.Text(P, 12, "body", C.text, "OUTLINE")
  P.info:SetPoint("TOP", P, "TOP", 0, 0)
  P.info:SetJustifyH("CENTER")
  P.btn = {}
  for i, kind in ipairs(SLOTS) do
    local b = CreateFrame("Button", "GrimuarPas" .. kind, P, "SecureActionButtonTemplate")
    b:SetSize(44, 44)
    b:SetPoint("BOTTOMLEFT", P, "BOTTOMLEFT", (i - 1) * 50, 0)
    b:RegisterForClicks("AnyUp", "AnyDown")
    b.bg = U.Rect(b, C.slot, 0.95) b.bg:SetAllPoints()
    b.icon = b:CreateTexture(nil, "ARTWORK")
    b.icon:SetPoint("TOPLEFT", 2, -2) b.icon:SetPoint("BOTTOMRIGHT", -2, 2)
    b.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    U.Border(b, C.edge)
    b.cd = CreateFrame("Cooldown", nil, b, "CooldownFrameTemplate")
    b.cd:SetAllPoints(b.icon)
    b.n = U.Text(b, 12, "body", C.text, "OUTLINE")
    b.n:SetPoint("BOTTOMRIGHT", -3, 3) b.n:SetJustifyH("RIGHT")
    b.lab = U.Text(b, 9, "body", C.faint)
    b.lab:SetPoint("TOP", b, "BOTTOM", 0, -1) b.lab:SetJustifyH("CENTER")
    b.lab:SetText(LABEL[kind])
    local hl = b:CreateTexture(nil, "HIGHLIGHT") hl:SetAllPoints(b.icon) hl:SetColorTexture(1, 1, 1, 0.12)
    b:SetScript("OnEnter", function(self)
      if not self.itemID then return end
      GameTooltip:SetOwner(self, "ANCHOR_TOP")
      pcall(GameTooltip.SetItemByID, GameTooltip, self.itemID)
      GameTooltip:Show()
    end)
    b:SetScript("OnLeave", function() GameTooltip:Hide() end)
    b.kind = kind
    P.btn[kind] = b
  end
  P:EnableMouse(false)
end

-- przedmioty na przyciskach: tylko poza walka
local function setItems()
  if not P or InCombatLockdown() then return end
  for _, kind in ipairs(SLOTS) do
    local b = P.btn[kind]
    local it = on() and pick(kind) or nil
    b.itemID = it and it.id or nil
    b:SetAttribute("type", it and "item" or nil)
    b:SetAttribute("item", it and ("item:" .. it.id) or nil)
    b:EnableMouse(on())
  end
end

local function update()
  if not P then return end
  local lowAny = false
  for _, kind in ipairs(SLOTS) do
    local b = P.btn[kind]
    local id = b.itemID
    if id then
      b.icon:SetTexture(U.call(C_Item.GetItemIconByID, id) or 134400)
      b.icon:SetDesaturated(false)
      local n = count(id)
      if kind == "drink" or kind == "food" then
        local all = 0
        local scan = kind == "drink" and G.scanDrinks or G.scanFood
        for _, d in ipairs(scan and U.call(scan) or {}) do all = all + (d.count or 1) end
        n = all
      end
      b.n:SetText(kind == "hearth" and "" or tostring(n))
      if kind ~= "hearth" and n < 4 then lowAny = true end
      U.Color(b.n, (kind ~= "hearth" and n < 4) and C.danger or C.text)
      pcall(function()
        local st, dur, en = C_Container.GetItemCooldown(id)
        if en and dur and dur > 1.5 then b.cd:SetCooldown(st, dur) else b.cd:Clear() end
      end)
    else
      b.icon:SetTexture(134400)
      b.icon:SetDesaturated(true)
      b.n:SetText("")
      if kind == "drink" or kind == "food" then lowAny = true end
    end
  end
  K.low = lowAny
  -- starczy na ok. N walk (sesja: picie i jedzenie na walke)
  local d, f = 0, 0
  for _, x in ipairs(G.scanDrinks and U.call(G.scanDrinks) or {}) do d = d + (x.count or 1) end
  for _, x in ipairs(G.scanFood and U.call(G.scanFood) or {}) do f = f + (x.count or 1) end
  local txt = ""
  if K.fights >= 3 and (K.usedD + K.usedF) > 0 then
    local perD, perF = K.usedD / K.fights, K.usedF / K.fights
    local nD = perD > 0 and math.floor(d / perD) or 999
    local nF = perF > 0 and math.floor(f / perF) or 999
    local nMin = math.min(nD, nF)
    if nMin < 999 then
      txt = "starczy na ok. " .. nMin .. " walk"
      if nMin < 3 then txt = U.hex(C.gold) .. txt .. ((nD <= nF) and " · picie: Conjure Water" or " · jedzenie: Conjure Food") .. "|r" end
    end
  elseif d + f == 0 then
    txt = U.hex(C.gold) .. "brak picia i jedzenia|r"
  end
  P.info:SetText(txt)
end

local function fade()
  if not P then return end
  local want
  if not on() then want = 0
  elseif K.combat or K.low or P:IsMouseOver() then want = 1
  else want = 0.4 end
  if P.a ~= want then P.a = want pcall(P.SetAlpha, P, want) end
end

-- zuzycie: spadek liczby picia i jedzenia (wzrost = Conjure albo zakup, nie liczymy)
local function track()
  local d, f = 0, 0
  for _, x in ipairs(G.scanDrinks and U.call(G.scanDrinks) or {}) do d = d + (x.count or 1) end
  for _, x in ipairs(G.scanFood and U.call(G.scanFood) or {}) do f = f + (x.count or 1) end
  if K.lastD and d < K.lastD then K.usedD = K.usedD + (K.lastD - d) end
  if K.lastF and f < K.lastF then K.usedF = K.usedF + (K.lastF - f) end
  K.lastD, K.lastF = d, f
end

local ev = CreateFrame("Frame")
for _, e in ipairs({ "PLAYER_LOGIN", "BAG_UPDATE_DELAYED", "PLAYER_REGEN_DISABLED", "PLAYER_REGEN_ENABLED", "BAG_UPDATE_COOLDOWN" }) do
  pcall(ev.RegisterEvent, ev, e)
end
ev:SetScript("OnEvent", function(_, e)
  if e == "PLAYER_LOGIN" then
    C_Timer.After(8, function()
      pcall(build)
      pcall(setItems)
      pcall(track)
      pcall(update)
      C_Timer.NewTicker(0.25, function() pcall(fade) end)
    end)
    return
  end
  if not P then return end
  if e == "PLAYER_REGEN_DISABLED" then K.combat = true
  elseif e == "PLAYER_REGEN_ENABLED" then
    K.combat = false
    K.fights = K.fights + 1
    pcall(setItems)
  elseif e == "BAG_UPDATE_DELAYED" then
    pcall(track)
    pcall(setItems)
  end
  pcall(update)
end)

function U.pasCmd()
  local d = db()
  d.pasTryb = d.pasTryb == false
  pcall(setItems)
  pcall(update)
  U.say(d.pasTryb ~= false and "pas podręczny (picie, jedzenie, bandaż, mikstura, dom) nad paskami akcji." or "pas podręczny wyłączony (zniknie po wyjściu z walki).")
end
if U.G then U.G.pasCmd = U.pasCmd end
