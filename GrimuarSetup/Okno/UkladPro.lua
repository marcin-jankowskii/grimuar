-- Grimuar: modul Panel (wspolne funkcje przez tabele G z innych modulow).
local ADDON_NAME, G = ...
local C_FROST = G.C_FROST
local C_GOLD = G.C_GOLD
local C_MUTED = G.C_MUTED
local C_OK = G.C_OK
local C_WARN = G.C_WARN
local DUNGEONS = G.DUNGEONS
local FONT = G.FONT
local GLOSSARY = G.GLOSSARY
local GUIDE = G.GUIDE
local QUESTS = G.QUESTS
local S = G.S
local SPELLS = G.SPELLS
local STAGES = G.STAGES
local TALENT_AT = G.TALENT_AT
local TALENT_NOTE_AT = G.TALENT_NOTE_AT
local W = 430 -- szerokosc tresci w nowym oknie z bocznym menu
local FlatButton, FitButton, StyledWindow, Divider = G.FlatButton, G.FitButton, G.StyledWindow, G.Divider
local STYLE, setBackdrop = G.STYLE, G.setBackdrop
local bookDone = G.bookDone
local buildSteps = G.buildSteps
local charKey = G.charKey
local clearGuide = G.clearGuide
local enableGatherTracking = G.enableGatherTracking
local guideTo = G.guideTo
local openTalents = G.openTalents
local say = G.say
local setBudget = G.setBudget
local showToast = G.showToast
local skipped = G.skipped
local tempoLine = G.tempoLine
local updateHUD = G.updateHUD

-- Czesc wydzielona z Panel.lua (podzial plikow >1000 linii, 12.11).
local TUTORIAL = G.TUTORIAL
local TUT_REF = G.TUT_REF
local hideGhosts = G.hideGhosts
local setCVarSafe = G.setCVarSafe
local showGhosts = G.showGhosts

-- ---------- uklad pro ustawiany automatycznie przez Edit Mode (kopia ukladu pod nazwa Grimuar) ----------
local function deepCopy(t)
  if type(t) ~= "table" then return t end
  local r = {}
  for k, v in pairs(t) do r[k] = deepCopy(v) end
  return r
end

local function anchorTo(sys, fx, fy)
  local w, h = UIParent:GetWidth(), UIParent:GetHeight()
  sys.anchorInfo = { point = "CENTER", relativeTo = "UIParent", relativePoint = "CENTER",
    offsetX = math.floor(fx * w + 0.5), offsetY = math.floor(fy * h + 0.5) }
  sys.anchorInfo2 = nil
  sys.isInDefaultPosition = false
end

local function setSetting(sys, settingEnum, value)
  if settingEnum == nil or type(sys.settings) ~= "table" then return end
  for _, s in ipairs(sys.settings) do
    if s.setting == settingEnum then
      s.value = value
      return
    end
  end
  table.insert(sys.settings, { setting = settingEnum, value = value })
end

local function applyProLayout()
  if InCombatLockdown() then
    say("ustawię układ po walce.")
    return false
  end
  local ok, res = pcall(function()
    local ES = Enum and Enum.EditModeSystem
    assert(C_EditMode and C_EditMode.GetLayouts and C_EditMode.SaveLayouts and ES, "gra nie udostępnia Edit Mode dla addonów")
    local info = C_EditMode.GetLayouts()
    assert(type(info) == "table" and type(info.layouts) == "table", "brak listy układów")
    local presets = {}
    if EditModePresetLayoutManager and EditModePresetLayoutManager.GetCopyOfPresetLayouts then
      presets = EditModePresetLayoutManager:GetCopyOfPresetLayouts() or {}
    end
    local nPre = #presets
    local active = info.activeLayout or 1
    local src
    if active <= nPre then src = presets[active] else src = info.layouts[active - nPre] end
    assert(src and type(src.systems) == "table", "nie znam aktywnego układu")
    if src.layoutName ~= "Grimuar" then GrimuarSetupDB.prevLayout = active end
    local lay = { layoutName = "Grimuar", layoutType = (Enum.EditModeLayoutType and Enum.EditModeLayoutType.Account) or 1,
      systems = deepCopy(src.systems) }
    local changed = {}
    local UF = Enum.EditModeUnitFrameSystemIndices
    local AB = Enum.EditModeActionBarSystemIndices
    local CV = Enum.EditModeCooldownViewerSystemIndices
    for _, sys in ipairs(lay.systems) do
      if sys.system == ES.UnitFrame and UF and sys.systemIndex == UF.Player then
        anchorTo(sys, -0.17, -0.25)
        table.insert(changed, "Twoja ramka")
      elseif sys.system == ES.UnitFrame and UF and sys.systemIndex == UF.Target then
        anchorTo(sys, 0.17, -0.25)
        table.insert(changed, "ramka celu")
      elseif sys.system == ES.CastBar then
        anchorTo(sys, 0, -0.12)
        setSetting(sys, Enum.EditModeCastBarSetting and Enum.EditModeCastBarSetting.LockToPlayerFrame, 0)
        table.insert(changed, "pasek rzucania pod postacią")
      elseif sys.system == ES.ActionBar and AB and sys.systemIndex == AB.MainBar then
        setSetting(sys, Enum.EditModeActionBarSetting and Enum.EditModeActionBarSetting.HideBarArt, 1)
        table.insert(changed, "pasek bez gryfów")
      elseif ES.CooldownViewer and CV and sys.system == ES.CooldownViewer and sys.systemIndex == CV.Essential then
        anchorTo(sys, 0, -0.34)
        table.insert(changed, "odnowienia nad paskami")
      elseif ES.DamageMeter and sys.system == ES.DamageMeter then
        sys.anchorInfo = (G.meterAnchorInfo and G.meterAnchorInfo()) or
          { point = "TOPLEFT", relativeTo = "UIParent", relativePoint = "TOPLEFT", offsetX = 16, offsetY = -16 }
        sys.anchorInfo2 = nil
        sys.isInDefaultPosition = false
        table.insert(changed, "Damage Done w lewym górnym rogu")
      elseif ES.PersonalResourceDisplay and sys.system == ES.PersonalResourceDisplay then
        anchorTo(sys, 0, -0.18)
        table.insert(changed, "pasek życia i many pod postacią")
      end
    end
    assert(#changed > 0, "nie znalazłem ramek do przesunięcia")
    local idx
    for i, l in ipairs(info.layouts) do
      if l.layoutName == "Grimuar" then idx = i end
    end
    if idx then info.layouts[idx] = lay else
      table.insert(info.layouts, lay)
      idx = #info.layouts
    end
    info.activeLayout = nPre + idx
    C_EditMode.SaveLayouts(info)
    if C_EditMode.SetActiveLayout then pcall(C_EditMode.SetActiveLayout, nPre + idx) end
    return changed
  end)
  local extra = (G.tidyAddonFrames and G.tidyAddonFrames()) or {}
  if ok then
    setCVarSafe("nameplateShowSelf", "1")
    say("układ pro zapisany jako Grimuar: " .. table.concat(res, ", ") .. ", " .. table.concat(extra, ", ") .. ". Wpisz /reload, żeby zobaczyć zmiany. Powrót do starego: /grimuar pro cofnij.")
    showToast("układ pro gotowy. Wpisz /reload, żeby zobaczyć zmiany.", "", false)
    return true
  end
  say("nie udało się ustawić układu automatycznie (" .. tostring(res) .. "). Pokażę, gdzie przeciągnąć ramki ręcznie.")
  return false
end

-- Gryfy przy glownym pasku: ozdoba bez znaczenia w grze; chowane przy kazdym logowaniu, gdy wlaczone.
local function hideBarArt()
  local hid = false
  pcall(function()
    for _, bar in ipairs({ _G.MainActionBar, _G.MainMenuBar }) do
      if bar and bar.EndCaps then
        bar.EndCaps:Hide()
        hid = true
      end
    end
    local art = _G.MainMenuBarArtFrame
    if art and art.LeftEndCap then
      art.LeftEndCap:Hide()
      if art.RightEndCap then art.RightEndCap:Hide() end
      hid = true
    end
    if _G.MainMenuBarLeftEndCap then
      _G.MainMenuBarLeftEndCap:Hide()
      if _G.MainMenuBarRightEndCap then _G.MainMenuBarRightEndCap:Hide() end
      hid = true
    end
  end)
  return hid
end

-- Okna innych addonow: Nearby pod buffami obok minimapy, Threat pod Damage Done (lewy gorny rog) i ukryty solo.
local function tidyAddonFrames()
  local w, h = UIParent:GetWidth(), UIParent:GetHeight()
  local done = {}
  if type(FrugNearbyDB) == "table" then
    FrugNearbyDB.growUp = false
    FrugNearbyDB.x = math.floor(0.8 * w)
    FrugNearbyDB.y = math.floor(0.945 * h)
    table.insert(done, "Nearby pod buffami obok minimapy")
  end
  local tdb = ThreatClassic2DB
  if type(tdb) == "table" and type(tdb.profiles) == "table" then
    local key = "Default"
    if type(tdb.profileKeys) == "table" then
      for _, v in pairs(tdb.profileKeys) do key = v break end
    end
    local prof = tdb.profiles[key]
    if type(prof) == "table" then
      prof.general = prof.general or {}
      prof.general.hideSolo = true
      prof.frame = prof.frame or {}
      prof.frame.position = (G.threatPosition and G.threatPosition()) or { "TOPLEFT", "UIParent", "TOPLEFT", 16, -math.floor(0.14 * h) }
      local f = _G.ThreatClassic2BarFrame
      if f then
        pcall(function()
          f:ClearAllPoints()
          f:SetPoint(unpack(prof.frame.position))
        end)
      end
      table.insert(done, "Threat pod Damage Done, ukryty, gdy grasz solo")
    end
  end
  if hideBarArt() then
    GrimuarSetupDB.hideGryphons = true
    table.insert(done, "bez gryfów przy pasku")
  end
  return done
end

local function undoProLayout()
  local prev = GrimuarSetupDB.prevLayout
  local ok = prev and C_EditMode and C_EditMode.SetActiveLayout and pcall(C_EditMode.SetActiveLayout, prev)
  if ok then
    say("wróciłem do poprzedniego układu. Wpisz /reload. Układ Grimuar zostaje do wyboru w Edit Mode.")
  else
    say("nie mam zapisanego poprzedniego układu. Wybierz go ręcznie: Esc, Edit Mode, lista układów na górze.")
  end
end

local CHAPTERS = {}
do
  local seen = {}
  for i, st in ipairs(TUTORIAL) do
    if not seen[st[1]] then
      seen[st[1]] = true
      table.insert(CHAPTERS, { name = st[1], first = i, count = 0 })
    end
    CHAPTERS[#CHAPTERS].count = CHAPTERS[#CHAPTERS].count + 1
  end
end

local function chapterIndex(step)
  local idx = 1
  for i, c in ipairs(CHAPTERS) do
    if step >= c.first then idx = i end
  end
  return idx
end

local tut, tutGlow
local tutStep = 1

local function tutTarget(names)
  for _, n in ipairs(names or {}) do
    local f = _G[n]
    if f and f.IsShown and f:IsShown() then return f end
  end
  return nil
end

local function tutShow()
  local st = TUTORIAL[tutStep]
  local ci = chapterIndex(tutStep)
  tut.chapter:SetText("Rozdział " .. ci .. "/" .. #CHAPTERS .. ": " .. st[1])
  tut.title:SetText(C_GOLD .. st[2] .. "|r")
  tut.body:SetText(st[3])
  tut.count:SetText("krok " .. tutStep .. " / " .. #TUTORIAL)
  if st[5] then
    tut.act:SetText(st[5][1])
    FitButton(tut.act, 90)
    tut.act:Show()
  else
    tut.act:Hide()
  end
  if tutStep > 1 then tut.prev:Enable() else tut.prev:Disable() end
  tut.next:SetText(tutStep == #TUTORIAL and "Zakończ" or "Dalej")
  tut:SetHeight(tut.body:GetStringHeight() + 140)
  if st[1] == "Układ pro" then showGhosts() else hideGhosts() end
  local target = tutTarget(st[4])
  if target then
    tutGlow:ClearAllPoints()
    tutGlow:SetPoint("TOPLEFT", target, "TOPLEFT", -8, 8)
    tutGlow:SetPoint("BOTTOMRIGHT", target, "BOTTOMRIGHT", 8, -8)
    tutGlow:Show()
  else
    tutGlow:Hide()
  end
end

local function tutClose()
  hideGhosts()
  if tut then tut:Hide() end
  if tutGlow then tutGlow:Hide() end
  GrimuarSetupDB.tutorialDone = true
  GrimuarSetupDB.tutorialStep = tutStep
end

local function createTutorial()
  local f = StyledWindow("GrimuarTutorial", 520, 230, "Kurs dla nowego gracza", "DIALOG")
  f:SetPoint("CENTER", UIParent, "CENTER", 0, 170)
  f.OnClosed = function() tutClose() end
  f.chapter = f:CreateFontString(nil, "OVERLAY")
  f.chapter:SetFont(FONT, 12, "")
  f.chapter:SetTextColor(unpack(STYLE.accent))
  f.chapter:SetPoint("TOPLEFT", f, "TOPLEFT", 18, -44)
  f.count = f:CreateFontString(nil, "OVERLAY")
  f.count:SetFont(FONT, 12, "")
  f.count:SetTextColor(unpack(STYLE.muted))
  f.count:SetPoint("TOPRIGHT", f, "TOPRIGHT", -18, -44)
  f.title = f:CreateFontString(nil, "OVERLAY")
  f.title:SetFont(FONT, 18, "")
  f.title:SetPoint("TOPLEFT", f, "TOPLEFT", 18, -62)
  f.body = f:CreateFontString(nil, "OVERLAY")
  f.body:SetFont(FONT, 14, "")
  f.body:SetTextColor(unpack(STYLE.text))
  f.body:SetJustifyH("LEFT")
  f.body:SetJustifyV("TOP")
  f.body:SetWidth(484)
  f.body:SetPoint("TOPLEFT", f, "TOPLEFT", 18, -88)
  f.next = FlatButton(f, 88, 24, "Dalej", true)
  f.next:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -14, 12)
  f.prev = FlatButton(f, 88, 24, "Wstecz")
  f.prev:SetPoint("RIGHT", f.next, "LEFT", -6, 0)
  f.chNext = FlatButton(f, 30, 24, "»")
  f.chNext:SetPoint("RIGHT", f.prev, "LEFT", -12, 0)
  f.chPrev = FlatButton(f, 30, 24, "«")
  f.chPrev:SetPoint("RIGHT", f.chNext, "LEFT", -4, 0)
  f.act = FlatButton(f, 110, 24, "Pokaż", true)
  f.act:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT", 14, 12)
  f.next:SetScript("OnClick", function()
    if tutStep >= #TUTORIAL then tutClose() return end
    tutStep = tutStep + 1
    tutShow()
  end)
  f.prev:SetScript("OnClick", function()
    if tutStep > 1 then tutStep = tutStep - 1; tutShow() end
  end)
  f.chNext:SetScript("OnClick", function()
    local ci = chapterIndex(tutStep)
    if CHAPTERS[ci + 1] then tutStep = CHAPTERS[ci + 1].first; tutShow() end
  end)
  f.chPrev:SetScript("OnClick", function()
    local ci = chapterIndex(tutStep)
    if tutStep > CHAPTERS[ci].first then tutStep = CHAPTERS[ci].first
    elseif CHAPTERS[ci - 1] then tutStep = CHAPTERS[ci - 1].first end
    tutShow()
  end)
  f.act:SetScript("OnClick", function()
    local st = TUTORIAL[tutStep]
    if st[5] then pcall(st[5][2]) end
    C_Timer.After(0.3, function() if tut:IsShown() then tutShow() end end)
  end)
  tut = f

  local g = CreateFrame("Frame", "GrimuarTutorialGlow", UIParent, "BackdropTemplate")
  g:SetFrameStrata("FULLSCREEN_DIALOG")
  pcall(function()
    g:SetBackdrop({ edgeFile = "Interface\\Buttons\\WHITE8X8", edgeSize = 3 })
    g:SetBackdropBorderColor(0.37, 0.8, 0.94, 1)
  end)
  g:EnableMouse(false)
  local ag = g:CreateAnimationGroup()
  local a = ag:CreateAnimation("Alpha")
  a:SetFromAlpha(1)
  a:SetToAlpha(0.3)
  a:SetDuration(0.7)
  ag:SetLooping("BOUNCE")
  g:SetScript("OnShow", function() ag:Play() end)
  g:SetScript("OnHide", function() ag:Stop() end)
  g:Hide()
  tutGlow = g
end

local function startTutorial(at)
  if not tut then createTutorial() end
  tutStep = math.max(1, math.min(#TUTORIAL, tonumber(at) or 1))
  tut:Show()
  tutShow()
end
TUT_REF.chapters = CHAPTERS
TUT_REF.start = startTutorial

-- eksport do pozostalych modulow
G.applyProLayout = applyProLayout
G.hideBarArt = hideBarArt
G.tidyAddonFrames = tidyAddonFrames
G.undoProLayout = undoProLayout
G.CHAPTERS = CHAPTERS
G.chapterIndex = chapterIndex
G.tut = tut
G.tutGlow = tutGlow
G.tutStep = tutStep
G.tutTarget = tutTarget
G.tutShow = tutShow
G.tutClose = tutClose
G.createTutorial = createTutorial
G.startTutorial = startTutorial
