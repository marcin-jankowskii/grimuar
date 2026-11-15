-- Grimuar UI: dol ekranu wg makiet „HUD · Walka” i „Eksploracja” (14.11, gracz: „Tak”, takze paski zamiast lukow).
-- 1) Zycie i mana jako poziome paski nad paskami akcji (makieta „Walka”): zycie z lewej (czerwone), mana z prawej
--    (niebieska, fioletowa przy malej), liczby „231 / 286”, Twoje wzmocnienia z czasem nad zyciem, nad mana regula
--    5 sekund („5 s bez rzucania: regeneracja”). Poza walka, bez celu i przy pelnym zyciu i manie paski znikaja.
--    15.11 gracz: „redundantne”: domyslnie zostaja luki Runy, poziome paski tylko po /hub paski (paskiTryb = true).
-- 2) Paski akcji 1 i 2 przygaszone poza walka (makieta „Eksploracja”: 14%): pelne w walce, przy wrogim celu, pod
--    myszka, przy rzucaniu i po wcisnieciu klawisza z paska (4 s). Na ramkach Blizzarda tylko SetAlpha.
--    /hub paski-akcji wylacza. Gdy wlaczone jest przygaszanie z Globow (/globy zanikanie), to ono ma pierwszenstwo.
-- Midnight: zycie i mana w walce bywaja ukryte: tylko StatusBar:SetValue i FontString:SetText.
local ADDON, U = ...
local C = U.C
local G = U.G or {}

local BARS = { "MainActionBar", "MainMenuBar", "MultiBarBottomLeft" }
local MANA_OK, MANA_LOW = { 0.24, 0.52, 0.96 }, { 0.62, 0.38, 0.95 }
local NBUFF = 8
local K = { combat = false, lastAct = 0, lastCast = 0, barA = 1, pA = 1 }
local P

local function db() return U.db() end
local function sdb() return GrimuarSetupDB or {} end
local function secret(v) return issecretvalue and issecretvalue(v) end
local function kf() return math.max(0.6, (UIParent:GetHeight() or 900) / 900) end

-- ---------- 1) paski zycia i many ----------
local function bar(parent, h, c1, c2)
  local b = CreateFrame("StatusBar", nil, parent)
  b:SetHeight(h)
  b:SetStatusBarTexture(U.WHITE)
  b.c1, b.c2 = c1, c2
  function b:Paint(a1, a2)
    pcall(function()
      self:GetStatusBarTexture():SetGradient("VERTICAL", CreateColor(a2[1], a2[2], a2[3], 1), CreateColor(a1[1], a1[2], a1[3], 1))
    end)
  end
  b:Paint(c1, c2)
  b:SetMinMaxValues(0, 1) b:SetValue(1)
  b.bg = b:CreateTexture(nil, "BACKGROUND") b.bg:SetAllPoints() b.bg:SetColorTexture(0.035, 0.031, 0.024, 0.85)
  U.Border(b, { 0, 0, 0 }, 1)
  b.t = U.Text(b, math.floor(12 * kf() + 0.5), "body", C.text)
  b.t:SetPoint("CENTER") b.t:SetJustifyH("CENTER")
  U.Shadow(b.t)
  return b
end

local function anchorP()
  P:ClearAllPoints()
  for _, n in ipairs({ "MultiBarBottomRight", "MultiBarBottomLeft", "MainActionBar", "MainMenuBar" }) do
    local f = _G[n]
    if f and f:IsShown() then P:SetPoint("BOTTOM", f, "TOP", 0, 10 * kf()) return end
  end
  P:SetPoint("BOTTOM", UIParent, "BOTTOM", 0, 200)
end

local function build()
  if P then return end
  local k = kf()
  P = CreateFrame("Frame", "GrimuarPaskiGracza", UIParent)
  P:SetFrameStrata("LOW")
  P:SetSize(600 * k, 54 * k)
  P:EnableMouse(false)
  local half = (600 * k - 10 * k) / 2
  P.hp = bar(P, 16 * k, { 0.82, 0.23, 0.18 }, { 0.56, 0.11, 0.09 })
  P.hp:SetPoint("BOTTOMLEFT") P.hp:SetWidth(half)
  P.mp = bar(P, 16 * k, MANA_OK, { 0.16, 0.37, 0.77 })
  P.mp:SetPoint("BOTTOMRIGHT") P.mp:SetWidth(half)
  P.five = U.Text(P, math.floor(12 * k + 0.5), "body", C.frost)
  P.five:SetPoint("BOTTOMRIGHT", P.mp, "TOPRIGHT", 0, 5 * k)
  P.five:SetJustifyH("RIGHT")
  U.Shadow(P.five)
  P.buffs = {}
  for i = 1, NBUFF do
    local d = CreateFrame("Frame", nil, P)
    d:SetSize(24 * k, 24 * k)
    d:SetPoint("BOTTOMLEFT", P.hp, "TOPLEFT", (i - 1) * 28 * k, 5 * k)
    d.icon = d:CreateTexture(nil, "ARTWORK") d.icon:SetAllPoints() d.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    U.Border(d, C.edge, 1)
    d.n = U.Text(d, math.floor(10 * k + 0.5), "body", C.text)
    d.n:SetPoint("TOP", d, "BOTTOM", 0, -1) d.n:SetJustifyH("CENTER")
    U.Shadow(d.n)
    d:Hide()
    P.buffs[i] = d
  end
  anchorP()
end

local function setBar(b, cur, max)
  pcall(function() b:SetMinMaxValues(0, max) end)
  local ok = pcall(function() b:SetValue(cur, Enum and Enum.StatusBarInterpolation and Enum.StatusBarInterpolation.ExponentialEaseOut) end)
  if not ok then pcall(function() b:SetValue(cur) end) end
  pcall(function()
    if AbbreviateNumbers then b.t:SetText(AbbreviateNumbers(cur) .. " / " .. AbbreviateNumbers(max))
    else b.t:SetText(cur .. " / " .. max) end
  end)
end

local function updateBars()
  if not P then return end
  setBar(P.hp, UnitHealth("player"), UnitHealthMax("player"))
  setBar(P.mp, UnitPower("player", 0), UnitPowerMax("player", 0))
  pcall(function()
    local m, x = UnitPower("player", 0), UnitPowerMax("player", 0)
    if not secret(m) and not secret(x) and x > 0 then
      local low = m / x < 0.3
      if low ~= K.low then K.low = low P.mp:Paint(low and MANA_LOW or MANA_OK, low and { 0.42, 0.22, 0.70 } or { 0.16, 0.37, 0.77 }) end
    end
  end)
end

local function fmtLeft(s)
  if s >= 3600 then return math.floor(s / 3600) .. "h" elseif s >= 60 then return math.floor(s / 60) .. "m" end
  return math.floor(s) .. "s"
end
local function updateBuffs()
  if not P then return end
  local n = 0
  if C_UnitAuras and C_UnitAuras.GetAuraDataByIndex then
    for i = 1, 40 do
      local ok, a = pcall(C_UnitAuras.GetAuraDataByIndex, "player", i, "HELPFUL|PLAYER")
      if not ok or type(a) ~= "table" then break end
      if n >= NBUFF then break end
      n = n + 1
      local d = P.buffs[n]
      d.exp = (not secret(a.expirationTime)) and a.expirationTime or nil
      local shown = pcall(function() d.icon:SetTexture(a.icon) end)
      d:SetShown(shown)
    end
  end
  for i = n + 1, NBUFF do P.buffs[i]:Hide() end
end

-- czy pokazac paski: walka, wrogi cel albo niepelne zycie lub mana
local function wantP()
  if K.combat or (U.hudTargetActive and U.hudTargetActive()) then return true end
  local full = true
  pcall(function()
    local h, hm, m, mm = UnitHealth("player"), UnitHealthMax("player"), UnitPower("player", 0), UnitPowerMax("player", 0)
    if secret(h) or secret(m) then full = false return end
    full = h >= hm and m >= mm
  end)
  return not full
end

local function tickP(el)
  if not P then return end
  local on = db().paskiTryb == true
  if not on then if P:IsShown() then P:Hide() end return end
  if not P:IsShown() then P:Show() anchorP() updateBars() updateBuffs() end
  local goal = wantP() and 1 or 0
  if K.pA ~= goal then
    local step = el / 0.3
    K.pA = goal > K.pA and math.min(goal, K.pA + step) or math.max(goal, K.pA - step)
    P:SetAlpha(K.pA)
  end
  -- regula 5 sekund i czasy wzmocnien
  local since = GetTime() - K.lastCast
  local txt = ""
  pcall(function()
    local m, x = UnitPower("player", 0), UnitPowerMax("player", 0)
    if secret(m) or m < x then
      txt = since < 5 and ("5 s bez rzucania: " .. math.ceil(5 - since) .. " s") or "5 s bez rzucania: regeneracja"
    end
  end)
  P.five:SetText(txt)
  local now = GetTime()
  for _, d in ipairs(P.buffs) do
    if d:IsShown() then d.n:SetText(d.exp and d.exp > 0 and fmtLeft(math.max(0, d.exp - now)) or "") end
  end
end

-- luki Runy: wylaczone tylko, gdy wlaczono poziome paski (/hub paski)
local function arcs()
  local want = db().paskiTryb ~= true
  if G.runyArcs then pcall(G.runyArcs, want) end
end

-- ---------- 2) paski akcji 1 i 2 przygaszone poza walka ----------
local function barsWant()
  if K.combat or (U.hudTargetActive and U.hudTargetActive()) then return true end
  if GetTime() - K.lastAct < 4 then return true end
  if U.call(UnitCastingInfo, "player") or U.call(UnitChannelInfo, "player") then return true end
  for _, n in ipairs(BARS) do
    local f = _G[n]
    if f and f:IsShown() and U.call(f.IsMouseOver, f) then return true end
  end
  if GetCursorInfo and GetCursorInfo() then return true end
  return false
end
local function tickBars(el)
  if db().paskiAkcjiTryb == false or sdb().orbsFade then
    if K.barA ~= 1 then
      K.barA = 1
      for _, n in ipairs(BARS) do local f = _G[n] if f then pcall(f.SetAlpha, f, 1) end end
    end
    return
  end
  local goal = barsWant() and 1 or 0.14
  if math.abs(K.barA - goal) < 0.005 then return end
  local step = el / 0.25
  K.barA = goal > K.barA and math.min(goal, K.barA + step) or math.max(goal, K.barA - step)
  for _, n in ipairs(BARS) do local f = _G[n] if f then pcall(f.SetAlpha, f, K.barA) end end
end

-- ---------- zdarzenia ----------
local tick = CreateFrame("Frame")
tick:SetScript("OnUpdate", function(_, el)
  K.acc = (K.acc or 0) + el
  if K.acc < 0.05 then return end
  local dt = K.acc
  K.acc = 0
  pcall(tickBars, dt)
  pcall(tickP, dt)
end)

local function act() K.lastAct = GetTime() end
local ev = CreateFrame("Frame")
for _, e in ipairs({ "PLAYER_LOGIN", "PLAYER_REGEN_DISABLED", "PLAYER_REGEN_ENABLED", "EDIT_MODE_LAYOUTS_UPDATED", "UI_SCALE_CHANGED" }) do
  pcall(ev.RegisterEvent, ev, e)
end
for _, e in ipairs({ "UNIT_HEALTH", "UNIT_MAXHEALTH", "UNIT_POWER_FREQUENT", "UNIT_MAXPOWER", "UNIT_AURA", "UNIT_SPELLCAST_SUCCEEDED",
  "UNIT_SPELLCAST_START" }) do
  pcall(ev.RegisterUnitEvent, ev, e, "player")
end
ev:SetScript("OnEvent", function(_, event)
  if event == "PLAYER_LOGIN" then
    K.combat = InCombatLockdown() and true or false
    local ok, e = pcall(build)
    if not ok and U.logError then U.logError("paski/build", e) end
    -- klawisze z paskow (gra wola te funkcje przy wcisnieciu): pasek akcji pokazuje sie na 4 s
    for _, fn in ipairs({ "ActionButtonDown", "MultiActionButtonDown" }) do
      if type(_G[fn]) == "function" then pcall(hooksecurefunc, fn, act) end
    end
    C_Timer.After(6, function() pcall(arcs) pcall(anchorP) end)
  elseif event == "PLAYER_REGEN_DISABLED" then K.combat = true
  elseif event == "PLAYER_REGEN_ENABLED" then K.combat = false
  elseif event == "EDIT_MODE_LAYOUTS_UPDATED" or event == "UI_SCALE_CHANGED" then
    if P then C_Timer.After(1, function() pcall(anchorP) end) end
  elseif event == "UNIT_AURA" then pcall(updateBuffs)
  elseif event == "UNIT_SPELLCAST_SUCCEEDED" then K.lastCast = GetTime() act()
  elseif event == "UNIT_SPELLCAST_START" then act()
  else pcall(updateBars) end
end)

function U.paskiCmd(what)
  local d = db()
  if what == "akcji" then
    d.paskiAkcjiTryb = d.paskiAkcjiTryb == false
    U.say("paski akcji 1 i 2 " .. (d.paskiAkcjiTryb ~= false and "przygasają poza walką" or "zawsze pełne") .. ".")
  else
    d.paskiTryb = d.paskiTryb ~= true
    pcall(arcs)
    U.say(d.paskiTryb == true and "życie i mana jako paski nad paskami akcji (łuki wyłączone)." or "wracają łuki życia i many (Runy).")
  end
end
if U.G then U.G.paskiCmd = U.paskiCmd end
