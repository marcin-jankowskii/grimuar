-- Grimuar: modul Addony. Jednorazowe ustawienia innych addonow pod maga Frost (raz na postac).
local ADDON_NAME, G = ...
local say = G.say
local charKey = G.charKey

local function visible(name)
  local ok, v = pcall(PawnIsScaleVisible, name)
  return ok and v and true or false
end

-- Pawn: tylko skala Mage: Frost w podpowiedziach, zeby strzalka ulepszenia liczyla sie pod jedna specjalizacje.
-- Dziala wprost na PawnCommon.Scales (bez PawnGetAllScalesEx) i sprawdza wynik, zanim zapisze flage.
local function pawnFrostOnly()
  GrimuarSetupDB.pawnV = GrimuarSetupDB.pawnV or {}
  local key = charKey()
  if GrimuarSetupDB.pawnV[key] then return "done" end
  if type(PawnCommon) ~= "table" or type(PawnCommon.Scales) ~= "table" or not PawnSetScaleVisible or not PawnIsScaleVisible then
    return "nopawn"
  end
  local frost
  for name, sc in pairs(PawnCommon.Scales) do
    if (sc.LocalizedName or name) == "Mage: Frost" then frost = name end
  end
  if not frost then return "nofrost" end
  local hidden = 0
  for name, sc in pairs(PawnCommon.Scales) do
    if (sc.LocalizedName or name):find("^Mage:") then
      local want = (name == frost)
      if visible(name) ~= want then
        PawnSetScaleVisible(name, want)
        if not want then hidden = hidden + 1 end
      end
    end
  end
  for name, sc in pairs(PawnCommon.Scales) do
    if (sc.LocalizedName or name):find("^Mage:") and visible(name) ~= (name == frost) then return "fail" end
  end
  GrimuarSetupDB.pawnV[key] = true
  if PawnUIFrame_ScaleSelector_Refresh and PawnUIFrame and PawnUIFrame:IsShown() then pcall(PawnUIFrame_ScaleSelector_Refresh) end
  if hidden > 0 then
    say("Pawn: zostawiłem tylko skalę Mage: Frost. Zielona strzałka przy przedmiocie znaczy: lepsze dla Twojego Frosta.")
  end
  return "ok"
end

-- Ustawienia klienta z researchu 11.11 (Method, PlayHub): liczby na odnowieniach, liczby na paskach,
-- plakietki zawsze, klik w ziemie nie gubi celu. Raz na konto; nieznane CVar sa pomijane.
local CLIENT = {
  { "countdownForCooldowns", "1", "liczby na odnowieniach" },
  { "statusTextDisplay", "BOTH", "liczby i procenty na paskach życia i many" },
  { "nameplateShowAll", "1", "plakietki zawsze widoczne" },
  { "deselectOnClick", "0", "klik w ziemię nie gubi celu" },
  -- v2: research R1 (11.11 noc), gaming-warsztat/wow/research/R1-ustawienia-pro-i-hud-2611.md
  { "showTargetOfTarget", "1", "cel Twojego celu przy ramce celu" },
  { "nameplatePersonalShowAlways", "0", "pasek pod postacią tylko w walce albo z celem" },
  { "nameplatePersonalShowInCombat", "1", nil },
  { "nameplatePersonalShowWithTarget", "1", nil },
  { "Sound_EnableErrorSpeech", "0", "bez głosu „Not enough mana” (czerwony napis zostaje)" },
  { "Sound_EnableSoundWhenGameIsInBG", "1", "dźwięk gry także, gdy jesteś w innym oknie" },
  { "projectedTextures", "1", "kręgi czarów obszarowych widoczne na ziemi" },
  { "lossOfControl", "1", "alert na środku, gdy coś Cię ogłuszy albo uciszy" },
}

local function clientSettings()
  if (GrimuarSetupDB.clientV or 0) >= 2 then return end
  local done = {}
  for _, c in ipairs(CLIENT) do
    local cur
    pcall(function() cur = C_CVar and C_CVar.GetCVar(c[1]) or GetCVar(c[1]) end)
    if cur ~= nil and tostring(cur) ~= c[2] then
      local ok = pcall(function() if C_CVar and C_CVar.SetCVar then C_CVar.SetCVar(c[1], c[2]) else SetCVar(c[1], c[2]) end end)
      if ok and c[3] then table.insert(done, c[3]) end
    end
  end
  GrimuarSetupDB.clientV = 2
  if #done > 0 then say("ustawienia gry: " .. table.concat(done, ", ") .. ".") end
end

-- Nowy klawisz Shift+X (Evocation na pasku 3) dla kont ustawionych przed v2.8; tylko gdy Shift+X jest wolny.
local function bindShiftX()
  if GrimuarSetupDB.bindV == 2 or InCombatLockdown() then return end
  local cur = GetBindingAction("SHIFT-X")
  if cur == nil or cur == "" or cur == "MULTIACTIONBAR2BUTTON10" then
    if pcall(SetBinding, "SHIFT-X", "MULTIACTIONBAR2BUTTON10") then
      pcall(function() SaveBindings(GetCurrentBindingSet()) end)
      say("klawisze: X to teraz jedzenie (najlepsze z torby), a Evocation od 20 poziomu będzie pod Shift+X na pasku 3.")
    end
  else
    say("klawisz Shift+X jest zajęty (" .. tostring(cur) .. "), Evocation zostanie na pasku 3 bez klawisza.")
  end
  GrimuarSetupDB.bindV = 2
end

-- BetterBlizzPlates (zgoda gracza 11.11): liczby zycia na plakietkach, znacznik celu, czas rzucania,
-- ikony klas tylko wrogich graczy, troche wieksze nazwy. Raz na konto, po pierwszym starcie BBP.
local BBP_SET = {
  healthNumbers = true,
  targetIndicator = true,
  showNameplateCastbarTimer = true,
  classIndicator = true,
  classIndicatorFriendly = false,
  enemyNameScale = 1.15,
  -- R21 (13.11): tylko moje debuffy, kolor paska rzucania wg gotowosci Counterspella, znaczniki, focus wyrozniony
  otherNpdeBuffFilterOnlyMe = true,
  enableCastbarCustomization = true,
  castBarRecolor = true,
  castBarRecolorInterrupt = true,
  focusTargetIndicatorColorNameplate = true,
  raidmarkIndicator = true,
  petIndicator = true,
  ccIconScale = 1.6,
}
local BBP_VER = 2

local function bbpSetup()
  if (GrimuarSetupDB.bbpV or 0) >= BBP_VER or InCombatLockdown() then return end
  local loaded = C_AddOns and C_AddOns.IsAddOnLoaded and C_AddOns.IsAddOnLoaded("BetterBlizzPlates")
  local db = BetterBlizzPlatesDB
  if not loaded or type(db) ~= "table" or not db.hasSaved then return end
  for k, v in pairs(BBP_SET) do db[k] = v end
  -- R21: nakladanie plakietek wrogow i totemy/pety wroga w zestawach PvE i PvP (BBP nadpisuje CVary przy zmianie strefy)
  for _, key in ipairs({ "nameplateToggles_pve", "nameplateToggles_pvp" }) do
    local s = db[key]
    if type(s) == "table" then s.stackingEnemy = true s.nameplateShowEnemyTotems = true s.nameplateShowEnemyPets = true end
  end
  db.focusTargetIndicatorColorNameplateRGB = { 0.54, 0.31, 0.82 }
  db.raidmarkIndicatorScale = 1.4
  -- moje czary mrozu wieksze na plakietkach (ID z Classic; w Forever niepewne, zle ID nic nie psuja)
  local W = db.auraWhitelist
  local function wl(ids, name, big)
    if type(W) ~= "table" then return end
    for _, id in ipairs(ids) do if W[id] == nil then W[id] = { id = id, name = name, onlyMine = true, enlarged = big or nil } end end
  end
  wl({ 122, 865, 6131, 10230 }, "Frost Nova", true)
  wl({ 120, 8492, 10159, 10160, 10161 }, "Cone of Cold")
  wl({ 116, 205, 837, 7322, 8406, 8407, 8408, 10179, 10180, 10181, 25304 }, "Frostbolt")
  pcall(function() if BBP then BBP.auraListNeedsUpdate = true end end)
  GrimuarSetupDB.bbpV = BBP_VER
  say("BetterBlizzPlates ustawiony: plakietki wrogów jedna nad drugą, tylko Twoje debuffy (Nova większa), pasek rzucania w kolorze gotowości Counterspella, focus na fioletowo, znaczniki rajdowe. Wpisz /reload. Więcej opcji: /bbp.")
end

-- Nowe i poprawione makra (v3.0) dla kont ustawionych wczesniej; potem uklad paskow.
local function macrosUpdate()
  if GrimuarSetupDB.macrosV == 3 or InCombatLockdown() then return end
  if G.ensureMacros then pcall(G.ensureMacros) end
  GrimuarSetupDB.macrosV = 3
  if G.layoutBars then pcall(G.layoutBars, true) end
end

-- Klawisz focusa (propozycja 4, zgoda 12.11): pierwszy wolny z listy, raz na konto.
local FOCUS_KEYS = { "ALT-R", "ALT-F", "ALT-T" }
local function bindFocus()
  if GrimuarSetupDB.focusV == 1 or InCombatLockdown() then return end
  if GetMacroIndexByName("Focus") == 0 then return end
  for _, k in ipairs(FOCUS_KEYS) do
    local cur = GetBindingAction(k)
    if cur == nil or cur == "" or cur == "MACRO Focus" then
      if pcall(SetBinding, k, "MACRO Focus") then
        pcall(function() SaveBindings(GetCurrentBindingSet()) end)
        GrimuarSetupDB.focusKey = k
        GrimuarSetupDB.focusV = 1
        local nice = k:gsub("ALT%-", "Alt+")
        say("focus: najedź myszką na drugiego moba i wciśnij " .. nice .. ". Potem R zamienia w owcę właśnie jego, a F przerywa jego czary.")
        return
      end
    end
  end
  GrimuarSetupDB.focusV = 1
  say("klawisze Alt+R, Alt+F i Alt+T są zajęte, więc focus jest bez klawisza. Ustaw go sam: Opcje > Skróty klawiszowe.")
end

local reported = false
local function run(final)
  local ok, res = pcall(pawnFrostOnly)
  if reported then return end
  if not ok then
    reported = true
    say("Pawn: nie udało się przestawić skal (" .. tostring(res) .. "). " .. G.helpHint() .. "")
  elseif final and res ~= "ok" and res ~= "done" then
    reported = true
    say("Pawn: skale bez zmian (" .. tostring(res) .. "). " .. G.helpHint() .. "")
  end
end

local ev = CreateFrame("Frame")
ev:RegisterEvent("PLAYER_LOGIN")
ev:SetScript("OnEvent", function()
  C_Timer.After(9, function() run(false) end)
  C_Timer.After(11, function() if not InCombatLockdown() then pcall(clientSettings) end end)
  C_Timer.After(12, function() pcall(bindShiftX) end)
  C_Timer.After(13, function() pcall(macrosUpdate) end)
  C_Timer.After(13.5, function() pcall(bindFocus) end)
  C_Timer.After(14, function() pcall(bbpSetup) end)
  C_Timer.After(40, function() pcall(bbpSetup) end)
  C_Timer.After(25, function() run(true) end)
  if PawnUIFrame and PawnUIFrame.HookScript then
    PawnUIFrame:HookScript("OnShow", function() run(false) end)
  end
end)

G.pawnFrostOnly = pawnFrostOnly
G.clientSettings = clientSettings
G.CLIENT_CVARS = CLIENT
G.BBP_SET = BBP_SET
G.bindFocus = bindFocus
G.bbpSetup = bbpSetup
