-- Grimuar: modul Runy. Styl „Pustynia i Runy” (Black Desert + typografia Path of Exile), wybor gracza 12.11.
-- Cienkie luki zycia (lewy) i many (prawy) wokol postaci, wieksze przyciski paskow 1 i 2, stala sciaga combo
-- Frosta po lewej i zlote narozniki okien. Pasek Grimuara zostaje pod Polestarem (wymog gracza 12.11).
-- DOMYSLNIE WYLACZONY: /runy wlacza i wylacza; /runy wyzej, /runy nizej przesuwaja luki; /runy combo chowa sciage.
-- Wartosci w walce moga byc ukryte (sekrety Midnight): przekazujemy je tylko do StatusBar:SetValue
-- i FontString:SetText, niczego nie porownujemy. Porownania tylko poza walka i w pcall.
local ADDON_NAME, G = ...
local say = G.say

local MEDIA = "Interface\\AddOns\\GrimuarSetup\\Media\\"
local WHITE = "Interface\\Buttons\\WHITE8X8"
local RUNE_FONT = G.TF()
local FONT = G.FONT or "Fonts\\ARIALN.TTF"
local GOLD = { 0.85, 0.71, 0.36 }
local MUTED = { 0.62, 0.64, 0.7 }
local BAR_SCALE = 1.12
local ARC_LO, ARC_HI = 28 / 256, 228 / 256 -- pionowy zasieg luku w teksturze 256 px (gen_runy_tga.py)
local CALM_ALPHA = 0.18

local active = false
local ring, combo
local corners = {}
local scaled = {}
local pending = false

local function db() return GrimuarSetupDB end

-- ---------- luki zycia i many ----------
local function smooth()
  return Enum and Enum.StatusBarInterpolation and Enum.StatusBarInterpolation.ExponentialEaseOut
end

local function makeArc(parent, side, r, g, b)
  local file = MEDIA .. "luk_" .. side
  local track = parent:CreateTexture(nil, "BACKGROUND")
  track:SetAllPoints(parent)
  track:SetTexture(file)
  track:SetVertexColor(0.03, 0.03, 0.06, 0.55)

  local sb = CreateFrame("StatusBar", nil, parent)
  sb:SetOrientation("VERTICAL")
  sb:SetStatusBarTexture(WHITE)
  sb:SetStatusBarColor(r, g, b, 1)
  sb:SetMinMaxValues(0, 1)
  sb:SetValue(1)
  local m = sb:CreateMaskTexture()
  m:SetAllPoints(parent)
  m:SetTexture(file, "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
  sb:GetStatusBarTexture():AddMaskTexture(m)

  local over = CreateFrame("Frame", nil, parent)
  over:SetAllPoints(parent)
  over:SetFrameLevel(sb:GetFrameLevel() + 2)
  local rama = over:CreateTexture(nil, "ARTWORK")
  rama:SetAllPoints(parent)
  rama:SetTexture(file .. "_rama")

  local txt = over:CreateFontString(nil, "OVERLAY")
  txt:SetFont(FONT, 12, "OUTLINE")
  txt:SetTextColor(0.95, 0.93, 0.88)
  return { bar = sb, text = txt, side = side }
end

local function layoutRing()
  local S = math.max(200, math.min(300, math.floor((UIParent:GetWidth() or 1500) * 0.15)))
  ring:SetSize(S, S)
  ring:ClearAllPoints()
  ring:SetPoint("CENTER", UIParent, "CENTER", 0, db().runyY or -20)
  for _, a in ipairs({ ring.hp, ring.mp }) do
    a.bar:ClearAllPoints()
    a.bar:SetPoint("BOTTOMLEFT", ring, "BOTTOMLEFT", 0, S * ARC_LO)
    a.bar:SetPoint("TOPRIGHT", ring, "TOPRIGHT", 0, -S * (1 - ARC_HI))
    -- liczba pod dolnym koncem luku
    local x = (a.side == "l") and (61 / 256 * S) or (195 / 256 * S)
    a.text:ClearAllPoints()
    a.text:SetPoint("CENTER", ring, "TOPLEFT", x, -(238 / 256 * S))
  end
end

local function makeRing()
  ring = CreateFrame("Frame", "GrimuarRunyRing", UIParent)
  ring:SetFrameStrata("LOW")
  ring:SetSize(240, 240)
  ring.hp = makeArc(ring, "l", 0.82, 0.18, 0.15)
  ring.mp = makeArc(ring, "p", 0.24, 0.52, 0.96)
  ring:Hide()
end

-- Kolor many: ponizej 30% robi sie fioletowy. Poza walka liczymy wprost; w walce (wartosci ukryte) krzywa kolorow gry
-- (ColorCurve przez UnitPowerPercent), a gdy jej nie ma, kolor zostaje bez zmian.
-- gracz 13.11: czerwony luk many mylil sie z zyciem, wiec przy malej manie fiolet zamiast czerwieni
local MANA_OK, MANA_LOW = { 0.24, 0.52, 0.96 }, { 0.62, 0.38, 0.95 }
local manaCurve
local function getCurve()
  if manaCurve ~= nil then return manaCurve end
  manaCurve = false
  pcall(function()
    local c = C_CurveUtil.CreateColorCurve()
    c:SetType(Enum.LuaCurveType.Step)
    c:AddPoint(0, CreateColor(MANA_LOW[1], MANA_LOW[2], MANA_LOW[3], 1))
    c:AddPoint(0.3, CreateColor(MANA_OK[1], MANA_OK[2], MANA_OK[3], 1))
    manaCurve = c
  end)
  return manaCurve
end

local function manaColor(a)
  if not InCombatLockdown() then
    pcall(function()
      local mp, mx = UnitPower("player", 0), UnitPowerMax("player", 0)
      local col = (mx and mx > 0 and mp / mx < 0.3) and MANA_LOW or MANA_OK
      a.bar:SetStatusBarColor(col[1], col[2], col[3], 1)
    end)
    return
  end
  local curve = getCurve()
  if not curve then return end
  pcall(function()
    local col = UnitPowerPercent("player", 0, false, curve)
    a.bar:GetStatusBarTexture():SetVertexColor(col:GetRGBA())
  end)
end

local function setArc(a, cur, max)
  pcall(function() a.bar:SetMinMaxValues(0, max) end)
  local ok = pcall(function() a.bar:SetValue(cur, smooth()) end)
  if not ok then pcall(function() a.bar:SetValue(cur) end) end
  pcall(function()
    if AbbreviateNumbers then a.text:SetText(AbbreviateNumbers(cur)) else a.text:SetText(cur) end
  end)
end

local function updateRing()
  if not (active and ring) then return end
  setArc(ring.hp, UnitHealth("player"), UnitHealthMax("player"))
  setArc(ring.mp, UnitPower("player", 0), UnitPowerMax("player", 0))
  manaColor(ring.mp)
end

-- Poza walka, bez celu i przy pelnym zyciu i manie luki prawie znikaja, zeby srodek ekranu byl czysty.
local function calmCheck()
  if not (active and ring) then return end
  if InCombatLockdown() or UnitExists("target") then ring:SetAlpha(1) return end
  local full = false
  pcall(function()
    full = UnitHealth("player") >= UnitHealthMax("player") and UnitPower("player", 0) >= UnitPowerMax("player", 0)
  end)
  ring:SetAlpha(full and CALM_ALPHA or 1)
  if combo then combo:SetAlpha(0.8) end
end

-- ---------- zlote narozniki ----------
local CORNER_SPEC = {
  { "TOPLEFT", 0, 1, 0, 1, -3, 3 },
  { "TOPRIGHT", 1, 0, 0, 1, 3, 3 },
  { "BOTTOMLEFT", 0, 1, 1, 0, -3, -3 },
  { "BOTTOMRIGHT", 1, 0, 1, 0, 3, -3 },
}

local function addCorners(f, size)
  if not f then return end
  if corners[f] then corners[f]:Show() return end
  local o = CreateFrame("Frame", nil, f)
  o:SetAllPoints(f)
  o:SetFrameLevel((f:GetFrameLevel() or 1) + 8)
  for _, s in ipairs(CORNER_SPEC) do
    local t = o:CreateTexture(nil, "OVERLAY")
    t:SetTexture(MEDIA .. "rog")
    t:SetSize(size or 20, size or 20)
    t:SetPoint(s[1], o, s[1], s[6], s[7])
    t:SetTexCoord(s[2], s[3], s[4], s[5])
  end
  corners[f] = o
end

-- Zlote obramowania przyciskow paskow 1 i 2 (13.11)
local skins = {}
local function skinButtons(on)
  if on and G.masqueActive and G.masqueActive() then on = false end -- Masque ma wlasna skorke (Maska.lua)
  for _, prefix in ipairs({ "ActionButton", "MultiBarBottomLeftButton" }) do
    for i = 1, 12 do
      local b = _G[prefix .. i]
      if b then
        local o = skins[b]
        if on and not o and not InCombatLockdown() then
          o = CreateFrame("Frame", nil, b, "BackdropTemplate")
          o:SetPoint("TOPLEFT", b, "TOPLEFT", -1, 1)
          o:SetPoint("BOTTOMRIGHT", b, "BOTTOMRIGHT", 1, -1)
          o:SetFrameLevel((b:GetFrameLevel() or 1) + 3)
          pcall(function()
            o:SetBackdrop({ edgeFile = WHITE, edgeSize = 1 })
            o:SetBackdropBorderColor(0.85, 0.71, 0.36, 0.7)
          end)
          skins[b] = o
        end
        if o then if on then o:Show() else o:Hide() end end
      end
    end
  end
end

local CORNER_FRAMES = { "GrimuarDock", "PolestarGuideFrame", "TargetFrame", "MainActionBar", "MainMenuBar" }

local function cornersOn()
  local seen = {}
  for _, n in ipairs(CORNER_FRAMES) do
    local f = _G[n]
    if f and not seen[f] then seen[f] = true pcall(addCorners, f) end
  end
  local dm = G.damageMeterFrame and G.damageMeterFrame()
  if dm then pcall(addCorners, dm) end
  if combo then pcall(addCorners, combo, 18) end
  pcall(skinButtons, true)
end

local permanent = {}
local function cornersOff()
  for f, o in pairs(corners) do if not permanent[f] then o:Hide() end end
  pcall(skinButtons, false)
end
-- UX 12.11: runy takze na pasku i w oknie Grimuara, niezaleznie od stylu
local function runeCorners(f, size)
  if not f then return end
  permanent[f] = true
  pcall(addCorners, f, size)
end

-- ---------- wieksze przyciski paskow 1 i 2 (tylko poza walka) ----------
local SCALE_FRAMES = { "MainActionBar", "MainMenuBar", "MultiBarBottomLeft" }

local function applyScale(on)
  local seen = {}
  for _, n in ipairs(SCALE_FRAMES) do
    local f = _G[n]
    if f and f.SetScale and not seen[f] then
      seen[f] = true
      if on then
        if not scaled[f] then scaled[f] = f:GetScale() or 1 end
        pcall(f.SetScale, f, scaled[f] * BAR_SCALE)
      elseif scaled[f] then
        pcall(f.SetScale, f, scaled[f])
        scaled[f] = nil
      end
    end
  end
end

-- ---------- sciaga combo Frosta ----------
-- Kroki pokazuja sie dopiero, gdy znasz czar. Klawisze czytane z Twoich ustawien.
-- Kolejnosc wg researchu R6 (12.11): Frostbolt z max zasiegu, Nova i bieg przodem (nie tylem), Ice Lance w locie
-- Frostbolta na zamrozony cel, Fire Blast dzieli 8 s odnowienia z Ice Lance, koncowka rozdzka (zero many).
local STEPS = G.BD.steps -- combo z aktywnego buildu (Build/Api.lua)
local RESCUE = G.BD.rescue

local function keyText(cmd)
  local k
  pcall(function() k = GetBindingKey(cmd) end)
  if not k then return "" end
  k = k:gsub("SHIFT%-", "Shift+"):gsub("CTRL%-", "Ctrl+"):gsub("ALT%-", "Alt+")
  return k
end

local function spellIcon(name)
  local icon
  pcall(function()
    if C_Spell and C_Spell.GetSpellTexture then icon = C_Spell.GetSpellTexture(name)
    elseif GetSpellTexture then icon = GetSpellTexture(name) end
  end)
  return icon
end

local function known(name)
  return name == nil or (G.knownSpellId and G.knownSpellId(name) ~= nil)
end

local ROW_H = 24

local function getRow(i)
  combo.rows = combo.rows or {}
  local r = combo.rows[i]
  if r then return r end
  r = CreateFrame("Frame", nil, combo)
  r:SetSize(320, ROW_H)
  r.key = r:CreateFontString(nil, "OVERLAY")
  r.key:SetFont(FONT, 11, "OUTLINE")
  r.key:SetTextColor(unpack(GOLD))
  r.key:SetWidth(44)
  r.key:SetJustifyH("RIGHT")
  r.key:SetPoint("LEFT", r, "LEFT", 0, 0)
  r.icon = r:CreateTexture(nil, "ARTWORK")
  r.icon:SetSize(20, 20)
  r.icon:SetPoint("LEFT", r, "LEFT", 50, 0)
  r.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
  r.txt = r:CreateFontString(nil, "OVERLAY")
  r.txt:SetFont(FONT, 12, "")
  r.txt:SetPoint("LEFT", r.icon, "RIGHT", 6, 0)
  r.txt:SetJustifyH("LEFT")
  combo.rows[i] = r
  return r
end

local function fillRow(r, step)
  if step.spell then
    r.key:SetText(keyText(step.bind))
    local ic = spellIcon(step.spell)
    if ic then r.icon:SetTexture(ic) r.icon:Show() else r.icon:Hide() end
    local hint = (step.hintLance and known("Ice Lance")) and step.hintLance or step.hint
    if step.hintAt and (UnitLevel("player") or 1) >= step.hintAt[1] then hint = step.hintAt[2] end
    r.txt:SetText(step.spell .. (hint and ("  |cff9ea3b3" .. hint .. "|r") or ""))
    r.txt:SetTextColor(0.95, 0.93, 0.88)
  else
    r.key:SetText(step.bind and keyText(step.bind) or "")
    r.icon:Hide()
    r.txt:SetText(step.text)
    r.txt:SetTextColor(unpack(MUTED))
  end
end

local function header(fs, text, y)
  fs:ClearAllPoints()
  fs:SetPoint("TOPLEFT", combo, "TOPLEFT", 12, y)
  fs:SetText(text)
  fs:Show()
end

local function buildCombo()
  if not combo then return end
  for _, r in ipairs(combo.rows or {}) do r:Hide() end
  local y = -10
  header(combo.title, "Combo: " .. ((G.BD_META and G.BD_META.name) or "build"):gsub("^Mag ", ""):gsub(":.*$", ""), y)
  -- 15.11: zwiniete combo to sam naglowek
  if combo.fold then combo.fold.Paint() end
  if GrimuarSetupDB.runyComboFolded then
    combo.title2:Hide()
    combo:SetHeight(36)
    return
  end
  y = y - 24
  local i = 0
  for _, s in ipairs(STEPS) do
    if known(s.spell) and known(s.need) then
      i = i + 1
      local r = getRow(i)
      fillRow(r, s)
      r:ClearAllPoints()
      r:SetPoint("TOPLEFT", combo, "TOPLEFT", 4, y)
      r:Show()
      y = y - ROW_H
    end
  end
  local rescue = {}
  for _, s in ipairs(RESCUE) do
    if known(s.spell) and known(s.need) and (not s.needBind or keyText(s.bind) ~= "") then rescue[#rescue + 1] = s end
  end
  if #rescue > 0 then
    y = y - 6
    header(combo.title2, "Ratunek", y)
    y = y - 22
    for _, s in ipairs(rescue) do
      i = i + 1
      local r = getRow(i)
      fillRow(r, s)
      r:ClearAllPoints()
      r:SetPoint("TOPLEFT", combo, "TOPLEFT", 4, y)
      r:Show()
      y = y - ROW_H
    end
  else
    combo.title2:Hide()
  end
  combo:SetHeight(-y + 8)
end

local function placeCombo()
  combo:ClearAllPoints()
  local p = db().runyComboPos
  -- 13.11: zapisana stara domyslna pozycja (LEFT 16 40) zaslaniala ramki druzyny: przechodzi na nowa
  if type(p) == "table" and p[1] == "LEFT" and p[2] == 16 and p[3] == 40 then
    db().runyComboPos = nil
    p = nil
  end
  if type(p) == "table" and p[1] then
    combo:SetPoint(p[1], UIParent, p[1], p[2] or 0, p[3] or 0)
  else
    -- 13.11: wyzej niz ramki druzyny (zaslanialy sciage), nizej niz okno Threat
    combo:SetPoint("LEFT", UIParent, "LEFT", 16, 120)
  end
end

local function makeCombo()
  combo = CreateFrame("Frame", "GrimuarRunyCombo", UIParent, "BackdropTemplate")
  combo:SetSize(330, 200)
  combo:SetFrameStrata("LOW")
  if G.setBackdrop then
    G.setBackdrop(combo, { 0.04, 0.045, 0.065, 0.82 }, { 0.42, 0.35, 0.18, 0.9 })
  end
  combo.title = combo:CreateFontString(nil, "OVERLAY")
  combo.title:SetFont(RUNE_FONT, 16, "")
  combo.title:SetTextColor(unpack(GOLD))
  combo.title2 = combo:CreateFontString(nil, "OVERLAY")
  combo.title2:SetFont(RUNE_FONT, 14, "")
  combo.title2:SetTextColor(unpack(GOLD))
  if G.FoldButton then combo.fold = G.FoldButton(combo, "runyComboFolded", function() if not InCombatLockdown() then buildCombo() end end) end
  -- Shift + przeciagnij przesuwa sciage
  combo:SetMovable(true)
  combo:EnableMouse(true)
  combo:RegisterForDrag("LeftButton")
  combo:SetScript("OnDragStart", function(self) if IsShiftKeyDown() then self.moving = true self:StartMoving() end end)
  combo:SetScript("OnDragStop", function(self)
    -- zapis tylko po prawdziwym przesunieciu z Shiftem (zwykle przeciagniecie zapisywalo pozycje domyslna)
    if not self.moving then return end
    self.moving = false
    self:StopMovingOrSizing()
    local point, _, _, x, y = self:GetPoint()
    db().runyComboPos = { point, x, y }
  end)
  combo:Hide()
end

-- ---------- tabliczka nad postacia (Personal Resource Display) dubluje luki ----------
local function selfPlate(on)
  local cur
  pcall(function() cur = (C_CVar and C_CVar.GetCVar or GetCVar)("nameplateShowSelf") end)
  if cur == nil then return end
  if on then
    if db().runySelfPrev == nil then db().runySelfPrev = cur end
    pcall(G.setCVarSafe, "nameplateShowSelf", "0")
  elseif db().runySelfPrev ~= nil then
    pcall(G.setCVarSafe, "nameplateShowSelf", db().runySelfPrev)
    db().runySelfPrev = nil
  end
end

-- ---------- wlacz / wylacz ----------
local function enable()
  if InCombatLockdown() then pending = true return "walka" end
  pending = false
  if db().orbs and G.orbsDisable then
    db().orbs = false
    pcall(G.orbsDisable)
  end
  if not ring then makeRing() end
  if not combo then makeCombo() end
  active = true
  layoutRing()
  -- 14.11: zycie i mana jako paski (GrimuarUI HudPaski.lua) zamiast lukow, zgoda gracza
  if db().noArcs then ring:Hide() else ring:Show() end
  updateRing()
  buildCombo()
  placeCombo()
  if db().runyComboOff then combo:Hide() else combo:Show() end
  applyScale(true)
  cornersOn()
  selfPlate(true)
  calmCheck()
  -- drugie podejscie do naroznikow: pasek Grimuara i okno Polestar moga powstac pozniej
  C_Timer.After(8, function() if active and not InCombatLockdown() then pcall(cornersOn) end end)
  return "ok"
end

local function disable()
  active = false
  pending = false
  if ring then ring:Hide() end
  if combo then combo:Hide() end
  cornersOff()
  if InCombatLockdown() then
    pending = "off"
  else
    applyScale(false)
    selfPlate(false)
  end
end

local ev = CreateFrame("Frame")
ev:RegisterEvent("PLAYER_LOGIN")
ev:SetScript("OnEvent", function(_, event)
  if event == "PLAYER_LOGIN" then
    ev:RegisterUnitEvent("UNIT_HEALTH", "player")
    ev:RegisterUnitEvent("UNIT_MAXHEALTH", "player")
    ev:RegisterUnitEvent("UNIT_POWER_UPDATE", "player")
    ev:RegisterUnitEvent("UNIT_MAXPOWER", "player")
    ev:RegisterEvent("PLAYER_REGEN_DISABLED")
    ev:RegisterEvent("PLAYER_REGEN_ENABLED")
    ev:RegisterEvent("PLAYER_TARGET_CHANGED")
    ev:RegisterEvent("SPELLS_CHANGED")
    ev:RegisterEvent("UPDATE_BINDINGS")
    ev:RegisterEvent("EDIT_MODE_LAYOUTS_UPDATED")
    C_Timer.After(6, function() if db().runy then pcall(enable) end end)
    for _, t in ipairs({ 6, 15 }) do
      C_Timer.After(t, function() if _G.GrimuarDock then runeCorners(_G.GrimuarDock) end end)
    end
    return
  end
  if event == "PLAYER_REGEN_ENABLED" then
    if pending == "off" then pending = false pcall(applyScale, false) pcall(selfPlate, false)
    elseif pending and db().runy then pcall(enable) end
  end
  if not active then return end
  if event == "PLAYER_REGEN_DISABLED" then
    ring:SetAlpha(1)
    if combo then combo:SetAlpha(1) end
  elseif event == "PLAYER_REGEN_ENABLED" or event == "PLAYER_TARGET_CHANGED" then
    pcall(calmCheck)
  elseif event == "SPELLS_CHANGED" or event == "UPDATE_BINDINGS" then
    pcall(buildCombo)
  elseif event == "EDIT_MODE_LAYOUTS_UPDATED" then
    C_Timer.After(0.5, function() if active and not InCombatLockdown() then pcall(applyScale, true) end end)
  else
    pcall(updateRing)
    if not InCombatLockdown() then pcall(calmCheck) end
  end
end)

SLASH_GRIMUARRUNY1 = "/runy"
SlashCmdList["GRIMUARRUNY"] = function(msg)
  msg = (msg or ""):lower()
  if msg:find("^wy") or msg:find("^ni") then
    local d = msg:find("^wy") and 15 or -15
    db().runyY = (db().runyY or -20) + d
    if active then pcall(layoutRing) end
    say("łuki przesunięte (" .. db().runyY .. ").")
    return
  end
  if msg:find("combo") then
    db().runyComboOff = not db().runyComboOff
    if active and combo then
      if db().runyComboOff then combo:Hide() else combo:Show() end
    end
    say("ściąga combo: " .. (db().runyComboOff and "schowana" or "widoczna") .. ".")
    return
  end
  db().runy = not db().runy
  if db().runy then
    local ok, res = pcall(enable)
    if not ok then
      say("Runy nie ruszyły: " .. tostring(res) .. ". " .. G.helpHint() .. "")
    elseif res == "walka" then
      say("Runy włączą się po walce.")
    else
      say("styl Pustynia i Runy włączony (prototyp). Wyłączysz go tym samym: /runy. Łuki wyżej lub niżej: /runy wyzej, /runy nizej. Ściągę combo przesuniesz z Shiftem.")
    end
  else
    disable()
    say("styl Pustynia i Runy wyłączony.")
  end
end

-- 14.11: luki wlacz / wylacz (GrimuarUI HudPaski.lua, /hub paski)
G.runyArcs = function(on)
  db().noArcs = not on
  if not ring then return end
  if active and on then ring:Show() pcall(updateRing) pcall(calmCheck) else ring:Hide() end
end
G.runyEnable = enable
G.addRuneCorners = runeCorners
G.runyDisable = disable
-- 14.11 (R27 E1): nowy build = nowa sciaga combo
if G.OnBuildChanged then G.OnBuildChanged(function() if combo and not InCombatLockdown() then pcall(buildCombo) pcall(placeCombo) end end) end
