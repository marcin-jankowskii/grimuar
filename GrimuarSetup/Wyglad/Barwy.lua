-- Grimuar: modul Barwy. Addony w palecie Pustynia i Runy (makieta 6, klucze z R15: gaming-warsztat/wow/research/
-- R15-skorki-addonow-2611.md). Zasady z R15: tylko pojedyncze klucze (nigdy cale podtabele), profil AceDB z profileKeys,
-- ForeverCast tylko poprawne wartosci (walidacja wylacza addon). Wszystko w pcall; czesc dziala od razu, reszta po /reload.
-- Uruchamiane z kontroli ustawien (Napraw / Ustaw wszystko) i z Przelacznikow.
local ADDON_NAME, G = ...
local say = G.say

local BG, PANEL = { 0.067, 0.059, 0.047 }, { 0.098, 0.082, 0.059 }
local GOLD, EDGE = { 0.85, 0.71, 0.36 }, { 0.48, 0.39, 0.2 }
local TXT, MUTED = { 0.93, 0.91, 0.86 }, { 0.6, 0.59, 0.55 }
local XP, DANGER, MANA = { 0.54, 0.31, 0.82 }, { 0.79, 0.4, 0.23 }, { 0.24, 0.52, 0.96 }

-- Wersja barw: przy nowej (np. plakietki 13.11) kontrola zglasza „Napraw” jeszcze raz
local BARWY_VER = 3

-- Czcionki Grimuara w LibSharedMedia (z BetterBlizzPlates/DBM), zeby addony mogly ich uzyc (R15, punkt 6)
local LSM = LibStub and LibStub("LibSharedMedia-3.0", true)
local LSM_FONT
if LSM and G.customFonts then
  if pcall(LSM.Register, LSM, "font", "Alegreya Sans (Grimuar)", G.BF()) then LSM_FONT = "Alegreya Sans (Grimuar)" end
  pcall(LSM.Register, LSM, "font", "Alegreya SC (Grimuar)", G.TF())
end

local function rgba(c, a) return { r = c[1], g = c[2], b = c[3], a = a or 1 } end
local function rgb(c) return { r = c[1], g = c[2], b = c[3] } end
local function arr(c, a) return { c[1], c[2], c[3], a or 1 } end
local function arr3(c) return { c[1], c[2], c[3] } end

local function aceProfile(sv)
  if type(sv) ~= "table" or type(sv.profiles) ~= "table" then return nil end
  local key = "Default"
  if type(sv.profileKeys) == "table" then
    local me = UnitName("player")
    for k, v in pairs(sv.profileKeys) do
      if type(k) == "string" and me and k:find(me, 1, true) then key = v break end
      key = v
    end
  end
  return sv.profiles[key]
end

local done = {}
local function step(name, fn)
  if pcall(fn) then done[#done + 1] = name end
end

-- ---------- poszczegolne addony ----------
local function spy()
  local p = Spy and Spy.db and Spy.db.profile
  assert(type(p) == "table" and type(p.Colors) == "table")
  local C = p.Colors
  if C.Window then C.Window["Title Text"] = rgba(GOLD) end
  if C.Bar then C.Bar["Bar Text"] = rgb(TXT) end
  if C.Alert then
    C.Alert.Background = rgba(BG, 0.9)
    C.Alert["KOS Border"] = rgba(DANGER, 0.8)
    C.Alert["KOS Guild Border"] = rgba(GOLD, 0.8)
    C.Alert["Stealth Border"] = rgba(XP, 0.8)
  end
  if C.Tooltip then C.Tooltip["Title Text"] = rgb(GOLD) end
  p.BarTexture = "Solid"
  p.WindowBorder = "none"
  pcall(function() Spy:SetBarTextures("Solid") end)
  pcall(function() Spy:ApplyBorderStyle() end)
end

-- Tlo okna Spy jest na sztywno (tekstura): malujemy je przy kazdym wejsciu
local function spyPaint()
  local w = _G.Spy_MainWindow
  if not w then return end
  pcall(function() if w.Background then w.Background:SetColorTexture(BG[1], BG[2], BG[3], 0.9) end end)
  pcall(function()
    local t = _G.SpyTitleBarFrame
    if t and t.SetBackdropColor then
      t:SetBackdropColor(PANEL[1], PANEL[2], PANEL[3], 1)
      t:SetBackdropBorderColor(EDGE[1], EDGE[2], EDGE[3], 1)
    end
  end)
  if G.addRuneCorners then pcall(G.addRuneCorners, w, 16) end
end

local function threat()
  local p = aceProfile(ThreatClassic2DB)
  assert(type(p) == "table")
  p.frame = p.frame or {}
  p.frame.color = arr(BG, 0.9)
  p.frame.headerColor = arr(PANEL, 1)
  p.backdrop = p.backdrop or {}
  p.backdrop.color = arr(PANEL, 0.9)
  p.backdrop.edgeColor = arr(EDGE, 1)
  p.customBarColors = p.customBarColors or {}
  local c = p.customBarColors
  c.playerEnabled, c.activeTankEnabled, c.otherUnitEnabled = true, true, true
  c.playerColor, c.activeTankColor, c.otherUnitColor, c.offTankColor = arr(GOLD), arr(DANGER), arr(MUTED), arr(EDGE)
  p.bar = p.bar or {}
  p.bar.pullAggroBarColor = arr(DANGER)
  p.font = p.font or {}
  p.font.color = arr(TXT)
end

local function dbm()
  assert(DBT and DBT.SetOption)
  local function set(k, v) pcall(DBT.SetOption, DBT, k, v) end
  set("Texture", "Interface\\Buttons\\WHITE8X8")
  set("TextColorR", TXT[1]) set("TextColorG", TXT[2]) set("TextColorB", TXT[3])
  for _, pre in ipairs({ "", "Huge" }) do
    set(pre .. "BackgroundColorR", BG[1]) set(pre .. "BackgroundColorG", BG[2]) set(pre .. "BackgroundColorB", BG[3])
    set(pre .. "BackgroundAlpha", 0.9)
    set(pre .. "BorderEnabled", true) set(pre .. "BorderSize", 1)
    set(pre .. "BorderColorR", EDGE[1]) set(pre .. "BorderColorG", EDGE[2]) set(pre .. "BorderColorB", EDGE[3])
    set(pre .. "BorderAlpha", 1)
  end
  set("StartColorR", GOLD[1]) set("StartColorG", GOLD[2]) set("StartColorB", GOLD[3])
  set("EndColorR", DANGER[1]) set("EndColorG", DANGER[2]) set("EndColorB", DANGER[3])
  pcall(function()
    local w = DBM.Options.WarningColors
    if type(w) == "table" then w[1], w[2], w[3] = rgb(MANA), rgb(GOLD), rgb(DANGER) end
  end)
end

local function baganator()
  local all = BAGANATOR_CONFIG and BAGANATOR_CONFIG.Profiles
  assert(type(all) == "table")
  local p = all[BAGANATOR_CURRENT_PROFILE or "DEFAULT"] or all.DEFAULT
  assert(type(p) == "table")
  p.current_skin = "dark"
  p.skins = p.skins or {}
  p.skins.dark = p.skins.dark or {}
  p.skins.dark.view_transparency = 0.1
  p.skins.dark.no_frame_borders = true
  p.skins.dark.square_icons = true
end

-- Skorka dark Baganatora ma kolor na sztywno: przemalowanie na braz przez publiczne API (R15)
local function baganatorPaint()
  local api = Baganator and Baganator.API and Baganator.API.Skins
  if not (api and api.RegisterListener) or G.bagListener then return end
  G.bagListener = true
  api.RegisterListener(function(details)
    pcall(function()
      local f = details and (details.region or details.frame)
      if f and details.regionType == "ButtonFrame" then
        if f.SetBackdropColor then f:SetBackdropColor(BG[1], BG[2], BG[3], 0.95) end
        if G.addRuneCorners then G.addRuneCorners(f, 18) end
      end
    end)
  end)
end

local function shotWindow()
  local p = ShotWindowDB
  assert(type(p) == "table")
  p.style, p.darkAlpha = "dark", 0.9
  p.color, p.lineColor, p.fillColor, p.edgeColor = arr3(DANGER), arr3(GOLD), arr3(DANGER), arr3(DANGER)
  p.clipColor, p.moveColor, p.moveAccent = arr3(XP), arr3(MANA), false
end

local function foreverCast()
  local s = ForeverCastDB
  assert(type(s) == "table" and type(s.profiles) == "table")
  local key = "Default"
  pcall(function()
    local c = s.characters and s.characters[UnitGUID("player")]
    if type(c) == "table" and type(c.profile) == "string" then key = c.profile end
  end)
  local p = s.profiles[key]
  assert(type(p) == "table")
  p.texture = "flat" -- jedyna wartosc koloru, ktora addon przyjmuje (R15); reszta jest na sztywno
end

local function polestar()
  local function set(path, v)
    if Polestar and Polestar.Set then return Polestar.Set(path, v) end
    local d = PolestarDB and PolestarDB.settings
    local a, b = path:match("^(%w+)%.(%w+)$")
    if d and a then d[a] = d[a] or {} d[a][b] = v end
  end
  set("ui.skin", "polestar")
  set("ui.bgColor", arr3(BG)) set("ui.bgOpacity", 0.9)
  set("ui.accent", arr3(GOLD))
  set("ui.border", true) set("ui.borderColor", arr3(EDGE)) set("ui.borderSize", 1)
  set("ui.band", false)
  set("nav.arrowColor", arr3(GOLD)) set("nav.arrowNearColor", arr3(MANA))
end

local function gatherMate()
  local p = aceProfile(GatherMate2DB) or (GatherMate2DB and GatherMate2DB.profiles and GatherMate2DB.profiles.Default)
  assert(type(p) == "table")
  p.trackColors = p.trackColors or {}
  p.trackColors.Mining = { Red = DANGER[1], Green = DANGER[2], Blue = DANGER[3], Alpha = 1 }
  p.trackColors.Treasure = { Red = GOLD[1], Green = GOLD[2], Blue = GOLD[3], Alpha = 1 }
  p.trackColors.Fishing = { Red = MANA[1], Green = MANA[2], Blue = MANA[3], Alpha = 1 }
end

-- Plakietki (BetterBlizzPlates, punkt 6): zloty znacznik celu, focus oznaczony, paski rzucania w palecie, czcionka motywu.
-- Kolory wrogow zostaja (czerwony wrogi, zolty neutralny): to informacja, nie ozdoba.
local function plates()
  local db = BetterBlizzPlatesDB
  assert(type(db) == "table" and db.hasSaved)
  db.targetIndicatorRGB = arr3(GOLD)
  db.focusTargetIndicator = true
  db.castBarCastColor = { 0.95, 0.78, 0.35 }
  db.castBarChanneledColor = arr3(MANA)
  db.enableCastbarCustomization = true -- R21: bez tych dwoch kolory paska nie dzialaja
  db.castBarRecolor = true
  if LSM_FONT then db.useCustomFont = true db.customFont = LSM_FONT end
end

local function apply()
  if InCombatLockdown() then say("przemaluję addony po walce.") return false end
  done = {}
  step("Spy", spy)
  step("Threat", threat)
  step("DBM", dbm)
  step("Baganator", baganator)
  step("Shot Window", shotWindow)
  step("Forever Cast", foreverCast)
  step("Polestar", polestar)
  step("GatherMate2", gatherMate)
  step("plakietki", plates)
  pcall(G.skinMinimap)
  pcall(spyPaint)
  pcall(baganatorPaint)
  GrimuarSetupDB.barwyV = BARWY_VER
  say("barwy Runy: " .. (#done > 0 and table.concat(done, ", ") or "żaden addon jeszcze nie gotowy") .. ". Pełny efekt po przeładowaniu UI.")
  return true
end

local ev = CreateFrame("Frame")
ev:RegisterEvent("PLAYER_LOGIN")
ev:SetScript("OnEvent", function()
  C_Timer.After(6, function()
    if (GrimuarSetupDB.barwyV or 0) >= 1 then
      pcall(spyPaint)
      pcall(baganatorPaint)
      if G.addRuneCorners and _G.ThreatClassic2BarFrame then pcall(G.addRuneCorners, ThreatClassic2BarFrame, 14) end
    end
  end)
end)

G.barwyApply = apply
G.BARWY_VER = BARWY_VER
