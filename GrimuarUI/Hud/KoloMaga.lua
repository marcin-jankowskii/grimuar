-- Grimuar UI: kolo maga (14.11, R24 P10; wzor: kolo w Crimson Desert i Ring Menu w Black Desert). Klawisz z Skrotow
-- (AddOny > „Koło maga”) albo /hub kolo pokazuje na srodku ekranu kolo z czarami uzytkowymi, ktore znasz: teleporty
-- i portale, woda, jedzenie, kamien many, Arcane Intellect/Brilliance, pancerz, Evocation, Slow Fall i Hearthstone.
-- Klik rzuca czar i zamyka kolo. Przyciski sa bezpieczne (SecureActionButtonTemplate, atrybuty ustawiane poza walka),
-- wiec kolo dziala tylko poza walka; walka je zamyka. Esc albo PPM tez zamyka.
local ADDON, U = ...
local C = U.C

BINDING_NAME_GRIMUAR_KOLO = "Koło maga (teleporty, woda, jedzenie)"

-- nazwy czarow z gry (angielski klient Forever); rzucanie po nazwie bierze najwyzsza range
local SPELLS = (U.G and U.G.BD and U.G.BD.wheel) or {} -- kolo z aktywnego buildu (GrimuarSetup Build/Api.lua)
local HEARTH = 6948
local W, R = 60, 150
local K = { btns = {} }
local F
-- 15.11 (R30 P21): skroty pod kolem: { rodzaj Polestara, napis, zapas bez Polestara (funkcja GrimuarSetup), jej argument }
local NEAR = { { "innkeeper", "Karczma", "guideInn" }, { "class", "Trener", "guideTrainer" }, { "repair", "Naprawa", "guideVendor", true },
  { "reagents", "Reagenty" } }
-- 15.11 (R30 P23, gracz: „teleporty maga”): runy do teleportow i portali; na kole liczba run, odnowienie i ostrzezenie
local RUNE_TELE, RUNE_PORTAL = 17031, 17032 -- Rune of Teleportation, Rune of Portals (sprzedawca reagentow)
local function runeFor(name)
  if type(name) ~= "string" then return nil end
  if name:find("^Teleport:") then return RUNE_TELE end
  if name:find("^Portal:") then return RUNE_PORTAL end
  return nil
end
local function itemCount(id)
  return U.num(U.call(C_Item and C_Item.GetItemCount or GetItemCount, id)) or 0
end

local function known(name)
  local info = U.call(C_Spell and C_Spell.GetSpellInfo, name)
  if type(info) == "table" and info.spellID then
    local id = info.spellID
    if U.call(IsPlayerSpell, id) or U.call(IsSpellKnown, id) then return info end
  end
  return nil
end

local function entries()
  local out = {}
  for _, s in ipairs(SPELLS) do
    local names = type(s[1]) == "table" and s[1] or { s[1] }
    for _, n in ipairs(names) do
      local info = known(n)
      if info then
        out[#out + 1] = { kind = "spell", value = n, icon = info.iconID, label = s[2], spellID = info.spellID, rune = runeFor(n) }
        break
      end
    end
  end
  local hc = U.num(U.call(C_Item and C_Item.GetItemCount or GetItemCount, HEARTH)) or 0
  if hc > 0 then
    out[#out + 1] = { kind = "item", value = "item:" .. HEARTH, icon = U.call(C_Item and C_Item.GetItemIconByID, HEARTH) or 134414,
      label = "Kamień powrotu" }
  end
  return out
end

local function button(i)
  local b = K.btns[i]
  if b then return b end
  b = CreateFrame("Button", "GrimuarKolo" .. i, F, "SecureActionButtonTemplate")
  b:SetSize(W, W)
  b:RegisterForClicks("AnyUp", "AnyDown")
  b.icon = b:CreateTexture(nil, "ARTWORK")
  b.icon:SetAllPoints()
  b.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
  U.Border(b, C.goldDim, 2)
  local hl = b:CreateTexture(nil, "HIGHLIGHT")
  hl:SetAllPoints() hl:SetColorTexture(1, 0.9, 0.6, 0.18)
  b.label = U.Text(b, 12, "body", C.text)
  b.label:SetPoint("TOP", b, "BOTTOM", 0, -4)
  b.label:SetJustifyH("CENTER")
  U.Shadow(b.label)
  b:SetScript("PostClick", function() if not InCombatLockdown() then F:Hide() end end)
  -- 15.11 (R30 P23): odnowienie i liczba run na przycisku, dymek z opisem
  b.cd = CreateFrame("Cooldown", nil, b, "CooldownFrameTemplate")
  b.cd:SetAllPoints(b.icon)
  b.cnt = U.Text(b, 13, "body", C.text, "OUTLINE")
  b.cnt:SetPoint("BOTTOMRIGHT", -3, 3) b.cnt:SetJustifyH("RIGHT")
  b:HookScript("OnEnter", function(self)
    local e = self.entry
    if not e then return end
    local TT = U.TT
    TT:SetOwner(self, "ANCHOR_RIGHT")
    if e.spellID then pcall(TT.SetSpellByID, TT, e.spellID) else pcall(TT.SetItemByID, TT, HEARTH) end
    if e.rune then
      local n = itemCount(e.rune)
      local rn = e.rune == RUNE_TELE and "Rune of Teleportation" or "Rune of Portals"
      TT:AddLine(" ")
      if n > 0 then
        TT:AddLine(rn .. ": " .. n .. " w torbach", 0.6, 0.85, 0.6)
      else
        TT:AddLine("Brak " .. rn .. ". Kup u sprzedawcy reagentów (przycisk „Reagenty” pod kołem).", 1, 0.45, 0.35, true)
      end
    end
    TT:Show()
  end)
  b:HookScript("OnLeave", function() U.TT:Hide() end)
  K.btns[i] = b
  return b
end

local function build()
  if F then return end
  F = CreateFrame("Frame", "GrimuarKoloFrame", UIParent)
  F:SetFrameStrata("DIALOG")
  F:SetSize(2 * R + W + 40, 2 * R + W + 60)
  F:SetPoint("CENTER", UIParent, "CENTER", 0, 20)
  F:EnableMouse(true)
  F:Hide()
  local bg = F:CreateTexture(nil, "BACKGROUND")
  bg:SetSize(2 * R + W + 30, 2 * R + W + 30)
  bg:SetPoint("CENTER")
  bg:SetColorTexture(C.bg[1], C.bg[2], C.bg[3], 0.72)
  pcall(function()
    local m = F:CreateMaskTexture()
    m:SetTexture("Interface\\CHARACTERFRAME\\TempPortraitAlphaMask", "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
    m:SetAllPoints(bg)
    bg:AddMaskTexture(m)
  end)
  local mid = U.Diamond(F, 26, C.gold, true)
  mid:SetPoint("CENTER")
  F.title = U.Text(F, 13, "title", C.goldDim)
  F.title:SetPoint("CENTER", 0, -24)
  F.title:SetJustifyH("CENTER")
  F.title:SetText("KOŁO")
  F:SetScript("OnMouseUp", function(self, btn) if btn == "RightButton" and not InCombatLockdown() then self:Hide() end end)
  F:EnableKeyboard(false)
  F:SetScript("OnKeyDown", function(self, key)
    if key == "ESCAPE" and not InCombatLockdown() then
      self:Hide()
      pcall(self.SetPropagateKeyboardInput, self, false)
    else
      pcall(self.SetPropagateKeyboardInput, self, true)
    end
  end)
  F:SetScript("OnShow", function(self) if not InCombatLockdown() then self:EnableKeyboard(true) pcall(self.SetPropagateKeyboardInput, self, true) end end)
  F:SetScript("OnHide", function(self) if not InCombatLockdown() then self:EnableKeyboard(false) end end)
  -- 15.11 (R30 P21, Q6): skroty do najblizszych uslug pod kolem. Zwykle przyciski (nie SecureActionButton), wiec nie
  -- ruszaja bezpiecznych przyciskow czarow; klik: Polestar prowadzi (Nav.nearby.Go), bez niego Questie (G.guideInn...).
  F.near = {}
  local prev
  for i, k in ipairs(NEAR) do
    local b = U.Button(F, k[2], nil, 26)
    if prev then b:SetPoint("LEFT", prev, "RIGHT", 6, 0) else b:SetPoint("TOP", F, "BOTTOM", 0, -4) end
    b.key, b.pl = k[1], k[2]
    b:SetScript("OnClick", function(self)
      if InCombatLockdown() then return end
      local ok = U.psNearbyGo and U.psNearbyGo(self.key)
      if not ok then
        local fn = k[3] and U.G and U.G[k[3]]
        if fn then pcall(fn, k[4]) else U.say("nie znam drogi: " .. self.pl .. ".") end
      end
      F:Hide()
    end)
    F.near[i] = b
    prev = b
  end
end

-- napisy skrotow: „Karczma · ~2 min” z pamieci Polestara; rzad wysrodkowany pod kolem
local function nearLabels()
  if not (F and F.near) then return end
  local w = 0
  for _, b in ipairs(F.near) do
    b:SetLabel((U.psNearbyLabel and U.psNearbyLabel(b.key, true)) or b.pl)
    w = w + b:GetWidth() + 6
  end
  F.near[1]:ClearAllPoints()
  F.near[1]:SetPoint("TOPLEFT", F, "BOTTOM", -math.floor((w - 6) / 2), -4)
end

function U.koloToggle()
  if InCombatLockdown() then U.say("koło maga działa poza walką.") return end
  local ok, e = pcall(build)
  if not ok then if U.logError then U.logError("kolo/build", e) end return end
  if F:IsShown() then F:Hide() return end
  local list = entries()
  if #list == 0 then U.say("nie znam jeszcze czarów do koła (teleporty, woda, jedzenie).") return end
  for i, e2 in ipairs(list) do
    local b = button(i)
    local a = math.pi / 2 - (i - 1) * (2 * math.pi / #list)
    b:ClearAllPoints()
    b:SetPoint("CENTER", F, "CENTER", math.cos(a) * R, math.sin(a) * R)
    b:SetAttribute("type", e2.kind)
    b:SetAttribute(e2.kind, e2.value)
    b.icon:SetTexture(e2.icon)
    b.label:SetText(e2.label)
    b.entry = e2
    -- 15.11 (R30 P23): runy i odnowienie
    local n = e2.rune and itemCount(e2.rune)
    b.cnt:SetText(n and tostring(n) or "")
    if n then b.cnt:SetTextColor(n > 0 and C.text[1] or 1, n > 0 and C.text[2] or 0.4, n > 0 and C.text[3] or 0.35) end
    b.icon:SetDesaturated(n == 0)
    b.cd:Clear()
    pcall(function()
      if e2.spellID and C_Spell and C_Spell.GetSpellCooldown then
        local cd = C_Spell.GetSpellCooldown(e2.spellID)
        if cd and cd.duration and cd.duration > 1.5 then b.cd:SetCooldown(cd.startTime, cd.duration) end
      elseif e2.kind == "item" and C_Container and C_Container.GetItemCooldown then
        local st, dur, en = C_Container.GetItemCooldown(HEARTH)
        if en and dur and dur > 1.5 then b.cd:SetCooldown(st, dur) end
      end
    end)
    b:Show()
  end
  for i = #list + 1, #K.btns do K.btns[i]:Hide() end
  F:Show()
  pcall(nearLabels)
  if U.psNearbyQueue then
    U.psNearbyQueue({ "innkeeper", "class", "repair" }, function() if F:IsShown() then pcall(nearLabels) end end)
  end
end
function GrimuarKoloToggle() U.koloToggle() end

-- 15.11 (R30 P23): znasz teleport, a w torbach nie ma run -> raz na sesje przypomnienie (w miescie najlatwiej kupic)
local runeSaid
local function runeCheck()
  if runeSaid then return end
  local knowsTele = false
  for _, n in ipairs({ "Teleport: Ironforge", "Teleport: Stormwind", "Teleport: Darnassus" }) do
    if known(n) then knowsTele = true break end
  end
  if not knowsTele or itemCount(RUNE_TELE) > 0 then return end
  runeSaid = true
  local msg = "znasz teleport, ale nie masz Rune of Teleportation. Kup kilka u sprzedawcy reagentów (koło maga › „Reagenty”)."
  U.say(msg)
  if U.G and U.G.showToast then pcall(U.G.showToast, "Brak run do teleportu: kup Rune of Teleportation u sprzedawcy reagentów.", "book", false) end
end
U.koloRuneCheck = runeCheck

local ev = CreateFrame("Frame")
ev:RegisterEvent("PLAYER_REGEN_DISABLED")
ev:RegisterEvent("PLAYER_LOGIN")
ev:RegisterEvent("BAG_UPDATE_DELAYED")
ev:RegisterEvent("LEARNED_SPELL_IN_TAB")
local pending
ev:SetScript("OnEvent", function(_, e)
  if e == "PLAYER_REGEN_DISABLED" then
    -- tuz przed blokada walki: jeszcze wolno schowac
    if F and F:IsShown() then pcall(F.Hide, F) end
    return
  end
  if pending then return end
  pending = true
  C_Timer.After(e == "PLAYER_LOGIN" and 20 or 3, function() pending = nil pcall(runeCheck) end)
end)

U.testChecksExtra = U.testChecksExtra or {}
table.insert(U.testChecksExtra, { "Koło maga: teleporty i runy (P23)", function()
  local list = entries()
  local tele, runes = 0, itemCount(RUNE_TELE)
  for _, e in ipairs(list) do if e.rune then tele = tele + 1 end end
  return #list .. " na kole, teleporty/portale: " .. tele .. ", runy teleportu: " .. runes
end })
