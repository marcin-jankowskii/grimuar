-- Grimuar: modul Globy. Prototyp stylu „Globy Wraeclastu” (Path of Exile): glob zycia z lewej i many z prawej
-- przy koncach paskow akcji, plus przygaszanie paskow poza walka. DOMYSLNIE WYLACZONY: /globy wlacza i wylacza,
-- /globy zanikanie wlacza i wylacza przygaszanie. Wartosci w walce moga byc ukryte (sekrety Midnight):
-- przekazujemy je tylko do StatusBar:SetValue i FontString:SetText, niczego nie porownujemy.
local ADDON_NAME, G = ...
local say = G.say

local SIZE = 132
local MASK = "Interface\\CharacterFrame\\TempPortraitAlphaMask"
local WHITE = "Interface\\Buttons\\WHITE8X8"
local orbs = {}
local active = false

local function circle(parent, layer, inset, r, g, b, a, sub)
  local t = parent:CreateTexture(nil, layer, nil, sub or 0)
  t:SetPoint("TOPLEFT", parent, "TOPLEFT", inset, -inset)
  t:SetPoint("BOTTOMRIGHT", parent, "BOTTOMRIGHT", -inset, inset)
  t:SetColorTexture(r, g, b, a)
  local m = parent:CreateMaskTexture()
  m:SetAllPoints(t)
  m:SetTexture(MASK, "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
  t:AddMaskTexture(m)
  return t
end

local function makeOrb(name, r, g, b)
  local f = CreateFrame("Frame", name, UIParent)
  f:SetSize(SIZE, SIZE)
  f:SetFrameStrata("LOW")
  circle(f, "BACKGROUND", 0, 0.42, 0.35, 0.20, 1)      -- zlota obwodka
  circle(f, "BACKGROUND", 5, 0.02, 0.03, 0.05, 1, 1)   -- ciemne wnetrze
  local sb = CreateFrame("StatusBar", nil, f)
  sb:SetPoint("TOPLEFT", f, "TOPLEFT", 6, -6)
  sb:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -6, 6)
  sb:SetOrientation("VERTICAL")
  sb:SetStatusBarTexture(WHITE)
  sb:SetStatusBarColor(r, g, b, 1)
  sb:SetMinMaxValues(0, 1)
  sb:SetValue(1)
  local m = sb:CreateMaskTexture()
  m:SetAllPoints(sb)
  m:SetTexture(MASK, "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
  sb:GetStatusBarTexture():AddMaskTexture(m)
  local over = CreateFrame("Frame", nil, f)
  over:SetAllPoints(f)
  over:SetFrameLevel(sb:GetFrameLevel() + 2)
  local gloss = circle(over, "ARTWORK", 8, 1, 1, 1, 1)
  pcall(function() gloss:SetGradient("VERTICAL", CreateColor(1, 1, 1, 0), CreateColor(1, 1, 1, 0.16)) end)
  local txt = over:CreateFontString(nil, "OVERLAY")
  txt:SetFont(G.FONT or "Fonts\\ARIALN.TTF", 15, "OUTLINE")
  txt:SetPoint("CENTER", over, "CENTER", 0, 0)
  f.bar, f.text = sb, txt
  f:Hide()
  return f
end

local function smooth()
  return Enum and Enum.StatusBarInterpolation and Enum.StatusBarInterpolation.ExponentialEaseOut
end

local function setBar(o, cur, max)
  pcall(function() o.bar:SetMinMaxValues(0, max) end)
  local ok = pcall(function() o.bar:SetValue(cur, smooth()) end)
  if not ok then pcall(function() o.bar:SetValue(cur) end) end
  pcall(function()
    if AbbreviateNumbers then o.text:SetText(AbbreviateNumbers(cur)) else o.text:SetText(cur) end
  end)
end

local function update()
  if not active then return end
  setBar(orbs.hp, UnitHealth("player"), UnitHealthMax("player"))
  setBar(orbs.mp, UnitPower("player", 0), UnitPowerMax("player", 0))
end

local function place()
  local bar = _G.MultiBarBottomLeft or _G.MainActionBar or _G.MainMenuBar
  local half = (bar and bar.GetWidth and bar:GetWidth() or 500) / 2
  local s = bar and bar.GetEffectiveScale and (bar:GetEffectiveScale() / UIParent:GetEffectiveScale()) or 1
  local x = half * s + SIZE * 0.55
  orbs.hp:ClearAllPoints()
  orbs.hp:SetPoint("BOTTOM", UIParent, "BOTTOM", -x, 10)
  orbs.mp:ClearAllPoints()
  orbs.mp:SetPoint("BOTTOM", UIParent, "BOTTOM", x, 10)
end

-- ---------- przygaszanie poza walka (wartosci poza walka nie sa ukryte, wiec mozna je porownac) ----------
local FADE = { "MainActionBar", "MainMenuBar", "MultiBarBottomLeft", "MultiBarBottomRight", "PolestarGuideFrame", "GrimuarDock" }
local DIM = 0.25

local function setFade(alpha)
  for _, n in ipairs(FADE) do
    local f = _G[n]
    if f and f.SetAlpha then pcall(f.SetAlpha, f, alpha) end
  end
  local dm = G.damageMeterFrame and G.damageMeterFrame()
  if dm then pcall(dm.SetAlpha, dm, alpha) end
end

local function calmCheck()
  if not active or not GrimuarSetupDB.orbsFade then setFade(1) return end
  if InCombatLockdown() or UnitExists("target") then setFade(1) return end
  local full = false
  pcall(function()
    full = UnitHealth("player") >= UnitHealthMax("player") and UnitPower("player", 0) >= UnitPowerMax("player", 0)
  end)
  setFade(full and DIM or 1)
end

local function enable()
  if not orbs.hp then
    orbs.hp = makeOrb("GrimuarOrbHP", 0.78, 0.16, 0.16)
    orbs.mp = makeOrb("GrimuarOrbMP", 0.2, 0.45, 0.9)
  end
  active = true
  place()
  orbs.hp:Show()
  orbs.mp:Show()
  update()
  calmCheck()
end

local function disable()
  active = false
  if orbs.hp then orbs.hp:Hide() orbs.mp:Hide() end
  setFade(1)
end

local ev = CreateFrame("Frame")
ev:RegisterEvent("PLAYER_LOGIN")
ev:SetScript("OnEvent", function(_, event, unit)
  if event == "PLAYER_LOGIN" then
    ev:RegisterUnitEvent("UNIT_HEALTH", "player")
    ev:RegisterUnitEvent("UNIT_MAXHEALTH", "player")
    ev:RegisterUnitEvent("UNIT_POWER_UPDATE", "player")
    ev:RegisterUnitEvent("UNIT_MAXPOWER", "player")
    ev:RegisterEvent("PLAYER_REGEN_DISABLED")
    ev:RegisterEvent("PLAYER_REGEN_ENABLED")
    ev:RegisterEvent("PLAYER_TARGET_CHANGED")
    C_Timer.After(5, function() if GrimuarSetupDB.orbs then pcall(enable) end end)
    return
  end
  if not active then return end
  if event == "PLAYER_REGEN_DISABLED" then
    setFade(1)
  elseif event == "PLAYER_REGEN_ENABLED" or event == "PLAYER_TARGET_CHANGED" then
    pcall(calmCheck)
  else
    pcall(update)
    if not InCombatLockdown() then pcall(calmCheck) end
  end
end)

SLASH_GRIMUARGLOBY1 = "/globy"
SlashCmdList["GRIMUARGLOBY"] = function(msg)
  msg = (msg or ""):lower()
  if msg:find("zanik") then
    GrimuarSetupDB.orbsFade = not GrimuarSetupDB.orbsFade
    pcall(calmCheck)
    say("przygaszanie pasków poza walką: " .. (GrimuarSetupDB.orbsFade and "włączone" or "wyłączone") .. ".")
    return
  end
  GrimuarSetupDB.orbs = not GrimuarSetupDB.orbs
  if GrimuarSetupDB.orbs then
    local ok, err = pcall(enable)
    say(ok and "globy włączone (prototyp). Wyłączysz je tym samym: /globy. Przygaszanie pasków poza walką: /globy zanikanie."
      or ("globy nie ruszyły: " .. tostring(err) .. ". " .. G.helpHint() .. ""))
  else
    disable()
    say("globy wyłączone.")
  end
end

G.orbsEnable = enable
G.orbsDisable = disable
