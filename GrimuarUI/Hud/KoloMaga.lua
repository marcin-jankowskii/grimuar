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
      if info then out[#out + 1] = { kind = "spell", value = n, icon = info.iconID, label = s[2] } break end
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
    b:Show()
  end
  for i = #list + 1, #K.btns do K.btns[i]:Hide() end
  F:Show()
end
function GrimuarKoloToggle() U.koloToggle() end

local ev = CreateFrame("Frame")
ev:RegisterEvent("PLAYER_REGEN_DISABLED")
ev:SetScript("OnEvent", function()
  -- tuz przed blokada walki: jeszcze wolno schowac
  if F and F:IsShown() then pcall(F.Hide, F) end
end)
