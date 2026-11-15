-- Grimuar: modul Ekran. GUI calej gry w stylu Runy (makieta „Pelny ekran”, decyzje gracza 13.11: mala ramka gracza
-- przy paskach, czat przygasa, wlasne zlote obramowania przyciskow). Osobny uklad Edit Mode „Grimuar Runy”:
-- stary „Grimuar” zostaje, /ekran stary wraca do niego. Pasek pomocniczy (3) przygasa poza walka.
-- Komendy: /ekran (wlacz uklad Runy), /ekran stary (wroc). Wlaczenie tez przez Ustaw wszystko i Przelaczniki.
local ADDON_NAME, G = ...
local say = G.say

local NAME = "Grimuar Runy"
local PLAYER_SCALE = 0.85
local BAR3_DIM = 0.3

local function deepCopy(t)
  if type(t) ~= "table" then return t end
  local r = {}
  for k, v in pairs(t) do r[k] = deepCopy(v) end
  return r
end

-- Pozycja wzgledem srodka ekranu, w ulamkach szerokosci i wysokosci (jak w UkladPro.lua)
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
    if s.setting == settingEnum then s.value = value return end
  end
  table.insert(sys.settings, { setting = settingEnum, value = value })
end

local function presetsCount()
  local n = 0
  pcall(function()
    if EditModePresetLayoutManager and EditModePresetLayoutManager.GetCopyOfPresetLayouts then
      n = #(EditModePresetLayoutManager:GetCopyOfPresetLayouts() or {})
    end
  end)
  return n
end

-- Uklad z makiety: pion walki pod postacia, ramki po bokach paskow, odnowienia i rzucanie nad paskami
local function buildLayout()
  local ES = Enum and Enum.EditModeSystem
  assert(C_EditMode and C_EditMode.GetLayouts and C_EditMode.SaveLayouts and ES, "gra nie udostępnia Edit Mode dla addonów")
  local info = C_EditMode.GetLayouts()
  assert(type(info) == "table" and type(info.layouts) == "table", "brak listy układów")
  local nPre = presetsCount()
  local src
  for _, l in ipairs(info.layouts) do if l.layoutName == "Grimuar" then src = l end end
  if not src then
    local a = info.activeLayout or 1
    if a > nPre then src = info.layouts[a - nPre] end
  end
  if not src and EditModePresetLayoutManager then
    local pres = EditModePresetLayoutManager:GetCopyOfPresetLayouts() or {}
    src = pres[1]
  end
  assert(src and type(src.systems) == "table", "nie znam układu do skopiowania")
  local lay = { layoutName = NAME, layoutType = (Enum.EditModeLayoutType and Enum.EditModeLayoutType.Account) or 1,
    systems = deepCopy(src.systems) }
  local UF, AB = Enum.EditModeUnitFrameSystemIndices, Enum.EditModeActionBarSystemIndices
  local CV = Enum.EditModeCooldownViewerSystemIndices
  local changed = {}
  -- styl Runy powieksza paski 1 i 2 (x1,12): przesuniecia tych paskow sa w ich skali, wiec dzielimy przez k
  local k = GrimuarSetupDB.runy and 1.12 or 1
  -- gracz 13.11 (ekranV 5): „expa na sam dol, action bary tez nizej, czat w lewy dolny rog”: stos od dolu ekranu,
  -- kazda warstwa przyczepiona do poprzedniej (pasek doswiadczenia, 1, 2, 3, odnowienia, rzucanie), ramki przy pasku 1
  local BAR1 = (_G.MainActionBar and "MainActionBar") or (_G.MainMenuBar and "MainMenuBar") or nil
  local function pin(sys, point, rel, relPoint, x, y)
    if not rel or not (rel == "UIParent" or _G[rel]) then return false end
    sys.anchorInfo = { point = point, relativeTo = rel, relativePoint = relPoint, offsetX = x, offsetY = y }
    sys.anchorInfo2 = nil
    sys.isInDefaultPosition = false
    return true
  end
  -- v11 (gracz 14.11: „target ma byc lustrzanym odbiciem moich paskow, tej samej wielkosci, po prawo”): Twoja ramka
  -- moze stac tam, gdzie ja przeciagnales (Forever Skin pozwala przesuwac ramki); wtedy zostaje, a cel dostaje jej
  -- odbicie wzgledem srodka ekranu (lewo <-> prawo, x z przeciwnym znakiem, ta sama wysokosc).
  local MIRROR = { LEFT = "RIGHT", RIGHT = "LEFT", TOPLEFT = "TOPRIGHT", TOPRIGHT = "TOPLEFT", BOTTOMLEFT = "BOTTOMRIGHT", BOTTOMRIGHT = "BOTTOMLEFT" }
  local playerNow
  for _, l in ipairs(info.layouts) do
    if l.layoutName == NAME and type(l.systems) == "table" then
      for _, sy in ipairs(l.systems) do
        if sy.system == ES.UnitFrame and UF and sy.systemIndex == UF.Player and sy.anchorInfo and sy.anchorInfo.relativeTo == "UIParent" then
          playerNow = sy.anchorInfo
        end
      end
    end
  end
  for _, sys in ipairs(lay.systems) do
    if sys.system == ES.ActionBar and AB then
      if sys.systemIndex == AB.MainBar then
        -- 13.11 v7 gracz: „troszke wyzej”: 30 px przerwy nad paskiem doswiadczenia
        if not pin(sys, "BOTTOM", "UIParent", "BOTTOM", 0, 44 / k) then anchorTo(sys, 0, -0.42 / k) end
        setSetting(sys, Enum.EditModeActionBarSetting and Enum.EditModeActionBarSetting.HideBarArt, 1)
        changed[#changed + 1] = "pasek 1"
      elseif sys.systemIndex == AB.Bar2 then
        if not pin(sys, "BOTTOM", BAR1, "TOP", 0, 4) then anchorTo(sys, 0, -0.37 / k) end
        changed[#changed + 1] = "pasek 2"
      elseif sys.systemIndex == AB.Bar3 then
        if not pin(sys, "BOTTOM", "MultiBarBottomLeft", "TOP", 0, 4) then anchorTo(sys, 0, -0.3) end
        changed[#changed + 1] = "pasek 3"
      end
    elseif sys.system == ES.UnitFrame and UF then
      if sys.systemIndex == UF.Player then
        if playerNow then
          pin(sys, playerNow.point, "UIParent", playerNow.relativePoint, playerNow.offsetX or 0, playerNow.offsetY or 0)
        -- v10 (gracz 13.11: „moje paski i targetu troche wyzej i wieksze”): 60 px nad dolem paska 1
        elseif not pin(sys, "BOTTOMRIGHT", BAR1, "BOTTOMLEFT", -40, 60) then anchorTo(sys, -0.25, -0.36) end
        changed[#changed + 1] = "Ty"
      elseif sys.systemIndex == UF.Target then
        if playerNow then
          pin(sys, MIRROR[playerNow.point] or playerNow.point, "UIParent", MIRROR[playerNow.relativePoint] or playerNow.relativePoint,
            -(playerNow.offsetX or 0), playerNow.offsetY or 0)
        elseif not pin(sys, "BOTTOMLEFT", BAR1, "BOTTOMRIGHT", 40, 60) then anchorTo(sys, 0.25, -0.36) end
        changed[#changed + 1] = "cel (odbicie Twojej ramki)"
      elseif sys.systemIndex == UF.Focus then
        if not pin(sys, "BOTTOM", "TargetFrame", "TOP", 0, 24) then anchorTo(sys, 0.25, -0.3) end
        changed[#changed + 1] = "focus"
      elseif UF.Party and sys.systemIndex == UF.Party then
        -- Grupa.lua (13.11): druzyna w stylu rajdowym po lewej, miedzy Spy a czatem (kolory klas, klatwy, mana healera)
        anchorTo(sys, -0.38, -0.04)
        setSetting(sys, Enum.EditModeUnitFrameSetting and Enum.EditModeUnitFrameSetting.UseRaidStylePartyFrames, 1)
        changed[#changed + 1] = "drużyna"
      elseif UF.Raid and sys.systemIndex == UF.Raid then
        -- R19: raid przy lewej krawedzi (w raidzie druzyna sie chowa), grupy w rzedach po 5, sortowanie wg grup, obramowanie
        sys.anchorInfo = { point = "LEFT", relativeTo = "UIParent", relativePoint = "LEFT", offsetX = 16, offsetY = 0 }
        sys.anchorInfo2 = nil
        sys.isInDefaultPosition = false
        local S = Enum.EditModeUnitFrameSetting
        if S then
          setSetting(sys, S.RaidGroupDisplayType, 1)
          setSetting(sys, S.SortPlayersBy, 1)
          setSetting(sys, S.DisplayBorder, 1)
        end
        changed[#changed + 1] = "raid"
      end
    elseif sys.system == ES.CastBar then
      if not (pin(sys, "BOTTOM", "EssentialCooldownViewer", "TOP", 0, 8) or pin(sys, "BOTTOM", "MultiBarBottomRight", "TOP", 0, 48)) then
        anchorTo(sys, 0, -0.2)
      end
      setSetting(sys, Enum.EditModeCastBarSetting and Enum.EditModeCastBarSetting.LockToPlayerFrame, 0)
      changed[#changed + 1] = "rzucanie"
    elseif ES.CooldownViewer and CV and sys.system == ES.CooldownViewer and sys.systemIndex == CV.Essential then
      if not pin(sys, "BOTTOM", "MultiBarBottomRight", "TOP", 0, 8) then anchorTo(sys, 0, -0.25) end
      changed[#changed + 1] = "odnowienia"
    elseif ES.CooldownViewer and CV and sys.system == ES.CooldownViewer and CV.Utility and sys.systemIndex == CV.Utility then
      -- v9 (gracz: „tu zostal jakis znaczek”: Eureka! z drugiego rzedu odnowien stala na domyslnym miejscu, na paskach):
      -- czary pomocnicze w tym samym rzedzie, z prawej strony glownych odnowien
      if not pin(sys, "LEFT", "EssentialCooldownViewer", "RIGHT", 8, 0) then pin(sys, "BOTTOM", "MultiBarBottomRight", "TOP", 160, 8) end
      changed[#changed + 1] = "odnowienia pomocnicze"
    elseif ES.CooldownViewer and CV and sys.system == ES.CooldownViewer and CV.BuffIcon and sys.systemIndex == CV.BuffIcon then
      if not pin(sys, "BOTTOM", "PlayerCastingBarFrame", "TOP", 0, 8) then pin(sys, "BOTTOM", "MultiBarBottomRight", "TOP", 0, 90) end
      changed[#changed + 1] = "ikony buffów"
    elseif ES.StatusTrackingBar and sys.system == ES.StatusTrackingBar then
      -- pasek doswiadczenia na samym dole ekranu; drugi (np. reputacja) tuz nad nim
      if sys.systemIndex == 2 then
        if not pin(sys, "BOTTOM", "MainStatusTrackingBarContainer", "TOP", 0, 1) then pin(sys, "BOTTOM", "UIParent", "BOTTOM", 0, 12) end
      else
        pin(sys, "BOTTOM", "UIParent", "BOTTOM", 0, 0)
      end
      changed[#changed + 1] = "pasek doświadczenia"
    elseif ES.ChatFrame and sys.system == ES.ChatFrame then
      -- czat w samym lewym dolnym rogu (v6); pod nim miejsce na pole pisania
      pin(sys, "BOTTOMLEFT", "UIParent", "BOTTOMLEFT", 6, 34)
      changed[#changed + 1] = "czat"
    elseif ES.MicroMenu and sys.system == ES.MicroMenu then
      -- gracz 13.11 (v6): czat w lewym dolnym rogu, „a z prawej to”: menu w prawym dolnym rogu, torby nad nim
      -- (w jednym rzedzie weszlyby na pasek doswiadczenia, ktory biegnie srodkiem samego dolu)
      sys.anchorInfo = { point = "BOTTOMRIGHT", relativeTo = "UIParent", relativePoint = "BOTTOMRIGHT", offsetX = -6, offsetY = 4 }
      sys.anchorInfo2 = nil
      sys.isInDefaultPosition = false
      changed[#changed + 1] = "menu"
    elseif ES.Bags and sys.system == ES.Bags then
      if _G.MicroMenuContainer then
        sys.anchorInfo = { point = "BOTTOMRIGHT", relativeTo = "MicroMenuContainer", relativePoint = "TOPRIGHT", offsetX = 0, offsetY = 4 }
      else
        sys.anchorInfo = { point = "BOTTOMRIGHT", relativeTo = "UIParent", relativePoint = "BOTTOMRIGHT", offsetX = -6, offsetY = 52 }
      end
      sys.anchorInfo2 = nil
      sys.isInDefaultPosition = false
      changed[#changed + 1] = "torby"
    elseif ES.AuraFrame and sys.system == ES.AuraFrame then
      -- v8: wieksza minimapa (Prostokat.lua) z kolumnami przyciskow weszla na buffy: buffy na lewo od nich, debuffy pod buffami
      local AI = Enum.EditModeAuraFrameSystemIndices
      if AI and sys.systemIndex == AI.BuffFrame then
        pin(sys, "TOPRIGHT", "UIParent", "TOPRIGHT", -395, -6)
        changed[#changed + 1] = "buffy"
      elseif AI and sys.systemIndex == AI.DebuffFrame then
        if not pin(sys, "TOPRIGHT", "BuffFrame", "BOTTOMRIGHT", 0, -10) then pin(sys, "TOPRIGHT", "UIParent", "TOPRIGHT", -395, -70) end
        changed[#changed + 1] = "debuffy"
      end
    elseif ES.DamageMeter and sys.system == ES.DamageMeter then
      sys.anchorInfo = (G.meterAnchorInfo and G.meterAnchorInfo()) or
        { point = "TOPLEFT", relativeTo = "UIParent", relativePoint = "TOPLEFT", offsetX = 16, offsetY = -16 }
      sys.anchorInfo2 = nil
      sys.isInDefaultPosition = false
    end
  end
  assert(#changed > 0, "nie znalazłem pasków ani ramek w układzie")
  local idx
  for i, l in ipairs(info.layouts) do if l.layoutName == NAME then idx = i end end
  if idx then info.layouts[idx] = lay else
    table.insert(info.layouts, lay)
    idx = #info.layouts
  end
  info.activeLayout = nPre + idx
  C_EditMode.SaveLayouts(info)
  if C_EditMode.SetActiveLayout then pcall(C_EditMode.SetActiveLayout, nPre + idx) end
  return changed
end

local function switchTo(name)
  local info = C_EditMode.GetLayouts()
  local nPre = presetsCount()
  for i, l in ipairs(info.layouts) do
    if l.layoutName == name then
      info.activeLayout = nPre + i
      C_EditMode.SaveLayouts(info)
      if C_EditMode.SetActiveLayout then pcall(C_EditMode.SetActiveLayout, nPre + i) end
      return true
    end
  end
  return false
end

-- ---------- czat: przygasa (tekst znika po 25 s, tlo tylko pod myszka) ----------
local function chatFade(on)
  for i = 1, (NUM_CHAT_WINDOWS or 10) do
    local cf = _G["ChatFrame" .. i]
    if cf then
      pcall(function()
        cf:SetFading(true)
        cf:SetTimeVisible(on and 25 or 120)
        if cf.SetFadeDuration then cf:SetFadeDuration(3) end
        if FCF_SetWindowAlpha then FCF_SetWindowAlpha(cf, on and 0 or (DEFAULT_CHATFRAME_ALPHA or 0.25)) end
      end)
    end
  end
end

-- ---------- mniejsza ramka gracza ----------
local playerBase, playerLast
local function playerScale()
  if InCombatLockdown() then return end
  local f = _G.PlayerFrame
  if not (f and f.SetScale) then return end
  local cur = f:GetScale() or 1
  if not playerBase or (playerLast and math.abs(cur - playerLast) > 0.001) then playerBase = cur end
  -- ramki rysuje Forever Skin (13.11): bez zmniejszania do 85%, rozmiar daje jego ustawienie dlugosci i wysokosci paskow
  local fssUnits = false
  pcall(function() fssUnits = C_AddOns.IsAddOnLoaded("ForeverSkin") and type(ForeverSkinDB) == "table" and ForeverSkinDB.unitFrames ~= false end)
  local want = (GrimuarSetupDB.ekranRuny and not fssUnits) and playerBase * PLAYER_SCALE or playerBase
  if pcall(f.SetScale, f, want) then playerLast = want end
end

-- ---------- pasek 3 przygasa poza walka (pelny pod myszka i z wrogim celem) ----------
local function bar3Fade()
  local f = _G.MultiBarBottomRight
  if not f then return end
  local full = not GrimuarSetupDB.ekranRuny or InCombatLockdown()
  if not full then
    pcall(function()
      full = (UnitExists("target") and UnitCanAttack("player", "target")) or f:IsMouseOver()
    end)
  end
  pcall(f.SetAlpha, f, full and 1 or BAR3_DIM)
end

local function apply()
  if InCombatLockdown() then say("ustawię ekran po walce.") return false end
  local ok, res = pcall(buildLayout)
  if not ok then
    say("nie udało się ustawić układu ekranu (" .. tostring(res) .. "). " .. G.helpHint() .. "")
    return false
  end
  GrimuarSetupDB.ekranRuny = true
  chatFade(true)
  playerScale()
  bar3Fade()
  say("układ ekranu Runy zapisany (" .. table.concat(res, ", ") .. "). Przeładuj UI, żeby wszystko wskoczyło na miejsce. Powrót: /ekran stary.")
  return true
end

local function revert()
  if InCombatLockdown() then say("wrócę po walce.") return false end
  GrimuarSetupDB.ekranRuny = false
  local ok, found = pcall(switchTo, "Grimuar")
  chatFade(false)
  playerScale()
  bar3Fade()
  say((ok and found) and "wróciłem do układu Grimuar. Przeładuj UI." or "nie znalazłem układu Grimuar: wybierz układ w Esc > Edit Mode.")
  return true
end

-- ---------- tracker Questie (13.11 gracz: „te questie tez przesun gdzies”) ----------
-- Stal pod oknem przewodnika Polestara. Raz: na lewo od minimapy, pod ikonami buffow, rosnie w dol. Potem Questie
-- pamieta go sam (TrackerLocation), a Ty mozesz go przeciagnac za naglowek.
local function questieTracker()
  if (GrimuarSetupDB.questieTrackV or 0) >= 2 or InCombatLockdown() then return end
  local Q, f = _G.Questie, _G.Questie_BaseFrame
  local db = Q and Q.db and Q.db.profile
  if not (db and f) then return end
  -- minimapa 290 px (Prostokat.lua) + przesuniecie, margines i przyciski addonow: ok. 360 px od prawej krawedzi
  local x, y = -400, -150 -- v2: pod buffami i debuffami (Ekran v8)
  local ok = pcall(function()
    f:ClearAllPoints()
    f:SetPoint("TOPRIGHT", UIParent, "TOPRIGHT", x, y)
  end)
  if not ok then return end
  db.TrackerLocation = { "TOPRIGHT", "UIParent", "TOPRIGHT", x, y }
  db.trackerSetpoint = "TOPRIGHT"
  GrimuarSetupDB.questieTrackV = 2
  say("tracker Questie stoi teraz na lewo od minimapy. Przesuniesz go, przeciągając za nagłówek.")
end

local ev = CreateFrame("Frame")
ev:RegisterEvent("PLAYER_LOGIN")
ev:SetScript("OnEvent", function(_, event)
  if event == "PLAYER_LOGIN" then
    ev:RegisterEvent("PLAYER_REGEN_DISABLED")
    ev:RegisterEvent("PLAYER_REGEN_ENABLED")
    ev:RegisterEvent("PLAYER_TARGET_CHANGED")
    ev:RegisterEvent("EDIT_MODE_LAYOUTS_UPDATED")
    C_Timer.After(8, function() pcall(playerScale) pcall(bar3Fade) end)
    -- 14.11: gracz ustawil ramki recznie (Edit Mode): ponad v10 uklad NIE zapisuje sie sam, tylko przez /ekran
    -- (v11: cel jako odbicie Twojej ramki). Wczesniej: jednorazowo zapisz uklad jeszcze raz (v3: pasek doswiadczenia pod paskiem 1; v4: wszystko nizej, menu i torby w prawo; v5: stos od dolu; v6: czat w lewym dolnym rogu, menu i torby w prawym)
    C_Timer.After(12, function()
      if GrimuarSetupDB.ekranRuny and (GrimuarSetupDB.ekranV or 0) < 10 and not InCombatLockdown() then
        if apply() then GrimuarSetupDB.ekranV = 10 end
      end
    end)
    C_Timer.NewTicker(0.25, function() if GrimuarSetupDB.ekranRuny and not InCombatLockdown() then pcall(bar3Fade) end end)
    C_Timer.After(15, function() pcall(questieTracker) end)
  elseif event == "EDIT_MODE_LAYOUTS_UPDATED" then
    C_Timer.After(0.5, function() pcall(playerScale) end)
  elseif event == "PLAYER_REGEN_ENABLED" then
    pcall(playerScale)
    pcall(bar3Fade)
    if (GrimuarSetupDB.questieTrackV or 0) < 2 then C_Timer.After(2, function() pcall(questieTracker) end) end
    -- zapis ukladu wypadl w walce (13.11: gracz walczyl z dzikami 12 s po /reload): po walce jeszcze raz
    if GrimuarSetupDB.ekranRuny and (GrimuarSetupDB.ekranV or 0) < 10 then
      C_Timer.After(1, function()
        if not InCombatLockdown() and (GrimuarSetupDB.ekranV or 0) < 10 and apply() then GrimuarSetupDB.ekranV = 10 end
      end)
    end
  else
    pcall(bar3Fade)
  end
end)

SLASH_GRIMUAREKRAN1 = "/ekran"
SlashCmdList["GRIMUAREKRAN"] = function(msg)
  msg = (msg or ""):lower()
  if msg:find("stary") then revert() else apply() end
end

G.ekranApply = apply
G.ekranRevert = revert
