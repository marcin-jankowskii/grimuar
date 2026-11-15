-- Grimuar UI: HUD „Walka” i „Eksploracja” (makiety 14.11, zaakceptowane razem z hubem; gracz 14.11: „dorobic, wszystko rob”).
-- 1) Cel u gory ekranu zamiast kompasu, gdy masz wrogi cel albo walczysz: poziom w ramce, imie w kolorze reakcji,
--    typ i ranga (elita, rzadki), kogo bije (cel celu), pasek zycia z %, pasek rzucania z nazwa czaru, Twoje oslabienia
--    na celu z czasem. Ramka celu gry (TargetFrame) dostaje wtedy tylko przezroczystosc 0 (zasada: na ramkach Blizzarda
--    wylacznie SetAlpha), /hub cel ramka ja zostawia.
-- 2) Minimapa tylko wtedy, gdy jest potrzebna (makieta „Eksploracja”: kompas zamiast minimapy): w walce, w lochu, przy
--    wrogim celu, pod myszka i z wcisnietym Altem. Poza tym przezroczysta (MinimapCluster:SetAlpha), /hub minimapa-tryb wylacza.
--    15.11 gracz: „moja minimapa prostokatna zniknela”: domyslnie minimapa zawsze widoczna, chowanie tylko po /hub minimapa-tryb.
-- Midnight: w walce zycie, czary i aury celu bywaja ukryte (sekrety) — trafiaja tylko do StatusBar:SetValue,
-- FontString:SetText i Texture:SetTexture; niczego nie porownujemy (issecretvalue), wszystko w pcall.
local ADDON, U = ...
local C = U.C

local HOSTILE, NEUTRAL, FRIEND = { 0.94, 0.70, 0.65 }, { 0.95, 0.82, 0.45 }, { 0.62, 0.80, 0.50 }
local BADGE = { 0.54, 0.29, 0.16 }
local NDEB = 8
local CLASSIF = { elite = "elita", worldboss = "boss", rareelite = "rzadka elita", rare = "rzadki" }

local K = { combat = false, active = false }
local T  -- ramka celu

local function db() return U.db() end
local function secret(v) return issecretvalue and issecretvalue(v) end
local function present(v) return secret(v) or v ~= nil end
local function logErr(w, e) if U.logError then U.logError(w, e) end end

-- ---------- czy pokazac cel u gory ----------
local function hostileTarget()
  local ok, yes = pcall(function()
    return UnitExists("target") and not UnitIsDead("target") and UnitCanAttack("player", "target")
  end)
  return ok and yes and true or false
end
local function wantTarget()
  if db().hudCel == false then return false end
  local exists = U.call(UnitExists, "target")
  if not exists then return false end
  return hostileTarget() or K.combat
end
function U.hudTargetActive() return K.active end

-- ---------- budowa ----------
local function bar(parent, h, col1, col2)
  local b = CreateFrame("StatusBar", nil, parent)
  b:SetHeight(h)
  b:SetStatusBarTexture(U.WHITE)
  pcall(function()
    b:GetStatusBarTexture():SetGradient("VERTICAL", CreateColor(col2[1], col2[2], col2[3], 1), CreateColor(col1[1], col1[2], col1[3], 1))
  end)
  b:SetMinMaxValues(0, 1)
  b:SetValue(1)
  b.bg = b:CreateTexture(nil, "BACKGROUND")
  b.bg:SetAllPoints()
  b.bg:SetColorTexture(0.035, 0.031, 0.024, 0.85)
  U.Border(b, { 0, 0, 0 }, 1)
  return b
end

local function build()
  if T then return end
  local k = math.max(0.6, (UIParent:GetHeight() or 900) / 900)
  K.k = k
  T = CreateFrame("Frame", "GrimuarCelHud", UIParent)
  T:SetFrameStrata("LOW")
  T:SetSize(520 * k, 90 * k)
  T:SetPoint("TOP", UIParent, "TOP", 0, -10 * k) -- nad strzalka Polestara (TOP -140)
  T:EnableMouse(false)
  T:Hide()
  -- wiersz 1: poziom, imie, typ
  T.lv = CreateFrame("Frame", nil, T)
  T.lv:SetSize(26 * k, 24 * k)
  T.lv:SetPoint("TOPLEFT", 0, 0)
  T.lv.bg = U.Rect(T.lv, { 0.07, 0.06, 0.045 }, 0.9)
  T.lv.bg:SetAllPoints()
  U.Border(T.lv, BADGE, 1)
  T.lv.t = U.Text(T.lv, math.floor(12 * k + 0.5), "body", HOSTILE)
  T.lv.t:SetPoint("CENTER")
  T.lv.t:SetJustifyH("CENTER")
  T.name = U.Text(T, math.floor(19 * k + 0.5), "title", HOSTILE)
  T.name:SetPoint("LEFT", T.lv, "RIGHT", 10 * k, 0)
  T.name:SetWidth(300 * k)
  U.Shadow(T.name)
  T.kind = U.Text(T, math.floor(12 * k + 0.5), "body", C.muted)
  T.kind:SetPoint("RIGHT", T, "TOPRIGHT", 0, -12 * k)
  T.kind:SetJustifyH("RIGHT")
  U.Shadow(T.kind)
  -- wiersz 2: zycie
  T.hp = bar(T, 18 * k, { 0.82, 0.23, 0.18 }, { 0.56, 0.11, 0.09 })
  T.hp:SetPoint("TOPLEFT", T.lv, "BOTTOMLEFT", 0, -6 * k)
  T.hp:SetPoint("RIGHT", T, "RIGHT", 0, 0)
  T.hpT = U.Text(T.hp, math.floor(12 * k + 0.5), "body", C.text)
  T.hpT:SetPoint("CENTER")
  T.hpT:SetJustifyH("CENTER")
  U.Shadow(T.hpT)
  -- wiersz 3: rzucanie
  T.cast = bar(T, 10 * k, { 0.79, 0.64, 0.29 }, { 0.60, 0.46, 0.18 })
  T.cast:SetPoint("TOPLEFT", T.hp, "BOTTOMLEFT", 0, -6 * k)
  T.cast:SetWidth(400 * k)
  T.castT = U.Text(T, math.floor(11 * k + 0.5), "body", C.text)
  T.castT:SetPoint("LEFT", T.cast, "RIGHT", 8 * k, 0)
  T.castT:SetWidth(110 * k)
  U.Shadow(T.castT)
  T.cast:Hide() T.castT:Hide()
  -- wiersz 4: Twoje oslabienia na celu
  T.deb = {}
  for i = 1, NDEB do
    local d = CreateFrame("Frame", nil, T)
    d:SetSize(24 * k, 24 * k)
    d:SetPoint("TOPLEFT", T.cast, "BOTTOMLEFT", (i - 1) * 28 * k, -6 * k)
    d.icon = d:CreateTexture(nil, "ARTWORK")
    d.icon:SetAllPoints()
    d.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    U.Border(d, C.edge, 1)
    d.cd = CreateFrame("Cooldown", nil, d, "CooldownFrameTemplate")
    d.cd:SetAllPoints()
    pcall(d.cd.SetDrawEdge, d.cd, false)
    pcall(d.cd.SetHideCountdownNumbers, d.cd, false)
    d.n = U.Text(d, math.floor(11 * k + 0.5), "body", C.text)
    d.n:SetPoint("BOTTOMRIGHT", 2, -1)
    U.Shadow(d.n)
    d:Hide()
    T.deb[i] = d
  end
end

-- ---------- odswiezanie ----------
local function reactionColor()
  local ok, r = pcall(UnitReaction, "target", "player")
  if ok and r and not secret(r) then
    if r <= 3 then return HOSTILE elseif r == 4 then return NEUTRAL end
    return FRIEND
  end
  return hostileTarget() and HOSTILE or FRIEND
end

local function updateHeader()
  local col = reactionColor()
  pcall(function() T.name:SetText(UnitName("target")) end)
  U.Color(T.name, col)
  local lv = U.call(UnitLevel, "target")
  if secret(lv) then pcall(T.lv.t.SetText, T.lv.t, lv)
  else T.lv.t:SetText((lv and lv > 0) and tostring(lv) or "??") end
  U.Color(T.lv.t, col)
  local parts = {}
  pcall(function()
    if UnitIsPlayer("target") then
      local race, cls = UnitRace("target"), UnitClass("target")
      if race and not secret(race) then parts[#parts + 1] = race end
      if cls and not secret(cls) then parts[#parts + 1] = cls end
    else
      local cl = UnitClassification("target")
      if cl and not secret(cl) and CLASSIF[cl] then parts[#parts + 1] = CLASSIF[cl] end
      local ty = UnitCreatureType("target")
      if ty and not secret(ty) then parts[#parts + 1] = ty end
    end
  end)
  local txt = table.concat(parts, " · ")
  -- cel celu (kogo bije)
  local okT, tt = pcall(function()
    if not UnitExists("targettarget") then return nil end
    if UnitIsUnit("targettarget", "player") then return "Ty" end
    return UnitName("targettarget")
  end)
  if okT and present(tt) then
    if secret(tt) then
      pcall(T.kind.SetText, T.kind, tt)
      return
    end
    txt = txt .. (txt ~= "" and " · " or "") .. "bije: " .. tt
  end
  T.kind:SetText(txt)
end

local function updateHealth()
  pcall(function() T.hp:SetMinMaxValues(0, UnitHealthMax("target")) end)
  local ok = pcall(function() T.hp:SetValue(UnitHealth("target"), Enum and Enum.StatusBarInterpolation and Enum.StatusBarInterpolation.ExponentialEaseOut) end)
  if not ok then pcall(function() T.hp:SetValue(UnitHealth("target")) end) end
  if U.call(UnitIsDead, "target") then T.hpT:SetText("martwy") return end
  local done = pcall(function()
    local curve = CurveConstants and CurveConstants.ScaleTo100
    local p = UnitHealthPercent("target", false, curve)
    if not curve and not secret(p) then p = p * 100 end
    T.hpT:SetText(string.format("%.0f%%", p))
  end)
  if not done then
    pcall(function()
      local h, m = UnitHealth("target"), UnitHealthMax("target")
      if secret(h) or secret(m) then T.hpT:SetText(AbbreviateNumbers and AbbreviateNumbers(h) or h)
      elseif m and m > 0 then T.hpT:SetText(math.floor(h / m * 100 + 0.5) .. "%") end
    end)
  end
end

local function updateCast()
  local name, tex, st, en
  local okC = pcall(function()
    local n, _, t, s, e = UnitCastingInfo("target")
    if not present(n) then n, _, t, s, e = UnitChannelInfo("target") end
    name, tex, st, en = n, t, s, e
  end)
  if not okC or not present(name) then
    T.cast:Hide() T.castT:Hide() K.casting = false
    return
  end
  pcall(T.castT.SetText, T.castT, name)
  K.casting = true
  -- Midnight: czas rzucania jako obiekt czasu (gdy jest), inaczej min/max w ms i biezacy czas
  local timed = false
  if UnitCastingDuration and T.cast.SetTimerDuration then
    timed = pcall(function()
      local d = UnitCastingDuration("target")
      if not d then d = UnitChannelDuration and UnitChannelDuration("target") end
      if not d then error("brak") end
      T.cast:SetTimerDuration(d)
    end)
  end
  if not timed then
    pcall(function() T.cast:SetMinMaxValues(st, en) end)
    K.castTimer = true
  else
    K.castTimer = false
  end
  T.cast:Show() T.castT:Show()
end

local function updateDebuffs()
  local n = 0
  if C_UnitAuras and C_UnitAuras.GetAuraDataByIndex then
    for i = 1, 16 do
      local ok, a = pcall(C_UnitAuras.GetAuraDataByIndex, "target", i, "HARMFUL|PLAYER")
      if not ok or type(a) ~= "table" then break end
      if n >= NDEB then break end
      n = n + 1
      local d = T.deb[n]
      local shown = pcall(function()
        d.icon:SetTexture(a.icon)
        local c = a.applications
        if secret(c) then d.n:SetText(c) else d.n:SetText((c and c > 1) and c or "") end
        local okD = false
        if C_UnitAuras.GetAuraDuration and d.cd.SetCooldownFromDurationObject and a.auraInstanceID then
          okD = pcall(function() d.cd:SetCooldownFromDurationObject(C_UnitAuras.GetAuraDuration("target", a.auraInstanceID)) end)
        end
        if not okD then
          local dur, exp = a.duration, a.expirationTime
          if not secret(dur) and not secret(exp) and dur and dur > 0 then d.cd:SetCooldown(exp - dur, dur) else d.cd:Clear() end
        end
      end)
      d:SetShown(shown)
    end
  end
  for i = n + 1, NDEB do T.deb[i]:Hide() end
end

local function refreshAll()
  if not (T and T:IsShown()) then return end
  pcall(updateHeader)
  pcall(updateHealth)
  pcall(updateCast)
  pcall(updateDebuffs)
end

-- ramka celu gry: tylko przezroczystosc
local function blizzTarget(hide)
  local f = _G.TargetFrame
  if not f then return end
  if hide and db().hudCelRamka ~= true then
    pcall(f.SetAlpha, f, 0)
    K.blizzHidden = true
  elseif K.blizzHidden then
    pcall(f.SetAlpha, f, 1)
    K.blizzHidden = false
  end
end

local function applyTarget()
  if not T then return end
  local want = wantTarget()
  if want ~= K.active then
    K.active = want
    T:SetShown(want)
    if U.kompasApply then pcall(U.kompasApply) end
  end
  blizzTarget(want)
  -- pasek tempa Grimuara (GrimuarSetup Dock.lua) stoi w tym samym miejscu: przygasa, gdy u gory jest cel
  local hud = _G.GrimuarHUD
  if hud then pcall(hud.SetAlpha, hud, want and 0 or 1) end
  if want then refreshAll() end
end
U.hudTargetApply = applyTarget

-- ---------- minimapa (Eksploracja) ----------
local mm = { a = 1 }
local function minimapWant()
  local d = db()
  if d.minimapTryb ~= true then return true end
  if K.combat or K.active then return true end
  if U.call(IsInInstance) then return true end
  if IsAltKeyDown and IsAltKeyDown() then return true end
  local cl = _G.MinimapCluster
  if cl and U.call(cl.IsMouseOver, cl, 20, -20, -20, 20) then return true end
  if Minimap and U.call(Minimap.IsMouseOver, Minimap, 20, -20, -20, 20) then return true end
  return false
end
local function minimapTick(el)
  local cl = _G.MinimapCluster
  if not cl then return end
  local goal = minimapWant() and 1 or 0
  if math.abs(mm.a - goal) < 0.01 then
    if mm.a ~= goal then mm.a = goal pcall(cl.SetAlpha, cl, goal) end
    return
  end
  local step = el / 0.25
  if goal > mm.a then mm.a = math.min(goal, mm.a + step) else mm.a = math.max(goal, mm.a - step) end
  pcall(cl.SetAlpha, cl, mm.a)
end

-- ---------- zdarzenia ----------
local tick = CreateFrame("Frame")
tick:SetScript("OnUpdate", function(_, el)
  K.acc = (K.acc or 0) + el
  if K.acc < 0.05 then return end
  local dt = K.acc
  K.acc = 0
  pcall(minimapTick, dt)
  if T and T:IsShown() and K.casting and K.castTimer then
    pcall(function() T.cast:SetValue(GetTime() * 1000) end)
  end
end)

local ev = CreateFrame("Frame")
for _, e in ipairs({ "PLAYER_LOGIN", "PLAYER_TARGET_CHANGED", "PLAYER_REGEN_DISABLED", "PLAYER_REGEN_ENABLED",
  "UNIT_FACTION", "PLAYER_ENTERING_WORLD" }) do
  pcall(ev.RegisterEvent, ev, e)
end
local UEV = { "UNIT_HEALTH", "UNIT_MAXHEALTH", "UNIT_AURA", "UNIT_NAME_UPDATE", "UNIT_LEVEL", "UNIT_TARGET",
  "UNIT_SPELLCAST_START", "UNIT_SPELLCAST_STOP", "UNIT_SPELLCAST_FAILED", "UNIT_SPELLCAST_INTERRUPTED",
  "UNIT_SPELLCAST_DELAYED", "UNIT_SPELLCAST_CHANNEL_START", "UNIT_SPELLCAST_CHANNEL_UPDATE", "UNIT_SPELLCAST_CHANNEL_STOP" }
for _, e in ipairs(UEV) do pcall(ev.RegisterUnitEvent, ev, e, "target") end
ev:SetScript("OnEvent", function(_, event)
  if event == "PLAYER_LOGIN" then
    K.combat = InCombatLockdown() and true or false
    local ok, e = pcall(build)
    if not ok then logErr("hud/build", e) return end
    applyTarget()
    return
  end
  if not T then return end
  if event == "PLAYER_REGEN_DISABLED" then K.combat = true applyTarget()
  elseif event == "PLAYER_REGEN_ENABLED" then K.combat = false applyTarget()
  elseif event == "PLAYER_TARGET_CHANGED" or event == "UNIT_FACTION" or event == "PLAYER_ENTERING_WORLD" then applyTarget()
  elseif not K.active then return
  elseif event == "UNIT_HEALTH" or event == "UNIT_MAXHEALTH" then
    pcall(updateHealth)
    if U.call(UnitIsDead, "target") then applyTarget() end
  elseif event == "UNIT_AURA" then pcall(updateDebuffs)
  elseif event == "UNIT_NAME_UPDATE" or event == "UNIT_LEVEL" or event == "UNIT_TARGET" then pcall(updateHeader)
  else pcall(updateCast) end
end)

-- przelaczniki w oknie Grimuara (GrimuarSetup Strony.lua) przez wspolne G
function U.hudCmd(what)
  local d = db()
  if what == "cel" then
    d.hudCel = d.hudCel == false
    U.say("cel u góry ekranu " .. (d.hudCel ~= false and "włączony" or "wyłączony") .. ".")
    applyTarget()
  elseif what == "ramka" then
    d.hudCelRamka = not d.hudCelRamka
    U.say("ramka celu gry " .. (d.hudCelRamka and "zostaje obok celu u góry" or "chowa się, gdy cel jest u góry") .. ".")
    applyTarget()
  elseif what == "minimapa" then
    d.minimapTryb = d.minimapTryb ~= true
    U.say(d.minimapTryb == true and "minimapa tylko w walce, w lochu, pod myszką i z Altem." or "minimapa zawsze widoczna.")
  end
end
if U.G then U.G.hudCmd = U.hudCmd end
