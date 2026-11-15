-- Grimuar: modul Events (wspolne funkcje przez tabele G z innych modulow).
local ADDON_NAME, G = ...
local announceLevel = G.announceLevel
local arrangeMinimapIcons = G.arrangeMinimapIcons
local charKey = G.charKey
local checkZone = G.checkZone
local clearGuide = G.clearGuide
local clearMainBar = G.clearMainBar
local createDock = G.createDock
local createHUD = G.createHUD
local createMinimapButton = G.createMinimapButton
local enablePolestarWaypoints = G.enablePolestarWaypoints
local fullSetup = G.fullSetup
local guideTo = G.guideTo
local layoutBars = G.layoutBars
local nearestGuide = G.nearestGuide
local onDeath = G.onDeath
local placeConsumables = G.placeConsumables
local remind = G.remind
local restNeed = G.restNeed
local runReminders = G.runReminders
local saveCurrent = G.saveCurrent
local say = G.say
local sessionLogin = G.sessionLogin
local setBudget = G.setBudget
local showToast = G.showToast
local startTutorial = G.startTutorial
local tick = G.tick
local togglePanel = G.togglePanel
local updateHUD = G.updateHUD
local xpUpdate = G.xpUpdate

-- ============================================================
-- ZDARZENIA
-- ============================================================
local frame = CreateFrame("Frame")
local layoutQueued = false
local function queueLayout()
  if layoutQueued then return end
  layoutQueued = true
  C_Timer.After(1.5, function() layoutQueued = false; layoutBars(true) end)
end

frame:RegisterEvent("ADDON_LOADED")
frame:RegisterEvent("PLAYER_LOGIN")
frame:RegisterEvent("SPELLS_CHANGED")
frame:RegisterEvent("PLAYER_REGEN_ENABLED")
frame:RegisterEvent("PLAYER_LEVEL_UP")
frame:RegisterEvent("BAG_UPDATE")
frame:RegisterEvent("PLAYER_XP_UPDATE")
frame:RegisterEvent("PLAYER_UPDATE_RESTING")
frame:RegisterEvent("PLAYER_CAMPING")
frame:RegisterEvent("ZONE_CHANGED_NEW_AREA")
frame:RegisterEvent("PLAYER_DEAD")
frame:RegisterEvent("PLAYER_LOGOUT")
frame:RegisterEvent("QUEST_LOG_UPDATE")
frame:RegisterEvent("UNIT_AURA")
frame:RegisterEvent("BAG_UPDATE_DELAYED")
frame:RegisterEvent("PLAYER_REGEN_DISABLED")
frame:RegisterEvent("PLAYER_ALIVE")
frame:RegisterEvent("PLAYER_UNGHOST")

local refreshQueued = false
local function queueRefresh()
  if refreshQueued then return end
  refreshQueued = true
  C_Timer.After(0.6, function()
    refreshQueued = false
    if G.refreshAll then pcall(G.refreshAll) end
  end)
end

local REFRESH_EVENTS = {
  QUEST_LOG_UPDATE = true, BAG_UPDATE_DELAYED = true, PLAYER_REGEN_DISABLED = true, PLAYER_REGEN_ENABLED = true,
  PLAYER_ALIVE = true, PLAYER_UNGHOST = true, PLAYER_DEAD = true, PLAYER_UPDATE_RESTING = true, ZONE_CHANGED_NEW_AREA = true,
  PLAYER_XP_UPDATE = true, PLAYER_LEVEL_UP = true,
}

frame:SetScript("OnEvent", function(_, event, arg1)
  if REFRESH_EVENTS[event] or (event == "UNIT_AURA" and arg1 == "player") then queueRefresh() end
  if event == "ADDON_LOADED" and arg1 == ADDON_NAME then
    GrimuarSetupDB = GrimuarSetupDB or {}
    GrimuarSetupDB.chars = GrimuarSetupDB.chars or {}
    -- 14.11 (gracz: „dalej GCD jest na cooldownach”): pasek rzucania to ForeverCast (y -200 od srodka ekranu), lezal
    -- na ikonach WeakAuras Musca. Raz nizej, w wolne miejsce miedzy ikony a „5 sec rule” (zrzut: 1 jednostka = 1,2 px,
    -- ikony do -240, 5 sec rule od -340). ForeverCast czyta polozenie przy PLAYER_LOGIN, a my ladujemy sie wczesniej.
    if (GrimuarSetupDB.fcastV or 0) < 1 and type(ForeverCastDB) == "table" and type(ForeverCastDB.profiles) == "table" then
      GrimuarSetupDB.fcastV = 1
      for _, prof in pairs(ForeverCastDB.profiles) do
        local p = type(prof) == "table" and type(prof.bars) == "table" and prof.bars.player
        if type(p) == "table" and (p.y == nil or p.y == -200) and (p.x or 0) == 0 then p.y = -290 end
      end
    end
  elseif event == "PLAYER_LOGIN" then
    pcall(sessionLogin)
    -- 14.11 (gracz: „pasek GCD zaslania ikonki cooldownow, zrob tak, zeby nic na sobie nie lezalo”): raz przesun grupe
    -- WeakAuras Musca „Mage - Bars” (pasek rzucania z GCD i 5 sec rule) pod ikony, w miejsce po Cooldown Managerze.
    -- Przez API WeakAuras (GetData + Add), wiec WeakAuras samo zapisze zmiane; tylko gdy grupa stoi tam, gdzie ja dal pakiet.
    -- 15.11 (Musca 1.18: „The class pack changed… Update Mage HUD”): po aktualizacji pakietu klasy sprawdz raz jeszcze
    -- (raz na wersje Musca), czy grupa nie wrocila na stare miejsce (-6); gdy tak, przesun ja znowu.
    -- 15.11 (gracz: „znowu mana jest podwojnie”): ponowny import pakietu (/run WeakAuras.ImportClassPack) robi kopie
    -- grupy z dopiskiem „ 2” i wlaczonym „Mage - Mana” (pasek many pod lukami; mane pokazuja luki Grimuara, 14.11
    -- wylaczony przez load.use_never). Dlatego obie poprawki dzialaja na kazdej kopii („Mage - Bars”, „Mage - Bars 2”…),
    -- raz na kopie i wersje Musca (gracz moze potem wlaczyc z powrotem). Pasek many tylko w trybie prywatnym.
    C_Timer.After(7, function()
      if InCombatLockdown() then return end
      local WA = WeakAuras
      local D = type(WeakAurasSaved) == "table" and WeakAurasSaved.displays
      if not (WA and WA.GetData and type(WA.Add) == "function" and type(D) == "table") then return end
      local okV, waVer = pcall(C_AddOns.GetAddOnMetadata, "WeakAuras", "Version")
      waVer = okV and waVer or "?"
      GrimuarSetupDB.waFix = GrimuarSetupDB.waFix or {}
      local done = GrimuarSetupDB.waFix
      local function copies(base)
        local out, pat = {}, "^" .. base:gsub("%-", "%%-") .. " %d+$"
        for id in pairs(D) do
          if type(id) == "string" and (id == base or id:match(pat)) then out[#out + 1] = id end
        end
        return out
      end
      -- stary znacznik 14.11 (waLayoutV) liczy sie jako zrobione dla grupy „Mage - Bars” w tej wersji
      if (GrimuarSetupDB.waLayoutV or 0) >= 1 and GrimuarSetupDB.waLayoutVer == waVer then done["bars:Mage - Bars:" .. waVer] = true end
      local moved, hidden = 0, 0
      for _, id in ipairs(copies("Mage - Bars")) do
        local key = "bars:" .. id .. ":" .. waVer
        local d = WA.GetData(id)
        if not done[key] and type(d) == "table" then
          done[key] = true
          if d.yOffset == -6 then
            d.yOffset = -100
            if pcall(WA.Add, d) then moved = moved + 1 else d.yOffset = -6 end
          end
        end
      end
      if G.personal() then
        for _, id in ipairs(copies("Mage - Mana")) do
          local key = "mana:" .. id .. ":" .. waVer
          local d = WA.GetData(id)
          if not done[key] and type(d) == "table" and type(d.load) == "table" then
            done[key] = true
            if not d.load.use_never then
              d.load.use_never = true
              if pcall(WA.Add, d) then hidden = hidden + 1 else d.load.use_never = nil end
            end
          end
        end
      end
      if moved > 0 then
        say("WeakAuras: pasek rzucania (GCD) i „5 sec rule” zjechały pod ikony czasów odnowienia, nic na sobie nie leży. Cofnięcie: /wa > Mage - Bars > Y Offset -6.")
      end
      if hidden > 0 then
        say("WeakAuras: pasek many Musca wyłączony (manę pokazują łuki Grimuara). Włączenie: /wa > Mage - Mana > Load > odznacz Never.")
      end
    end)
    -- 14.11: raz wylacz wbudowany Cooldown Manager (dubluje ikony WeakAuras Musca); potem decyduje gracz w opcjach gry
    C_Timer.After(5, function()
      if (GrimuarSetupDB.cdmOffV or 0) < 1 and not InCombatLockdown() and G.personal() then
        GrimuarSetupDB.cdmOffV = 1
        if pcall(SetCVar, "cooldownViewerEnabled", "0") then
          say("wyłączyłem wbudowany Cooldown Manager: te same czasy odnowienia pokazują ikony WeakAuras przy łukach życia i many.")
        end
      end
    end)
    C_Timer.After(3, function()
      local key = charKey()
      pcall(createMinimapButton)
      pcall(enablePolestarWaypoints)
      pcall(createHUD)
      pcall(createDock)
      C_Timer.NewTicker(5, tick)
      C_Timer.After(2, function() pcall(checkZone) end)
      if not GrimuarSetupDB.toggleKey and _G.GrimuarMinimapButton then
        local ok = pcall(SetBindingClick, "SHIFT-G", "GrimuarMinimapButton", "LeftButton")
        if ok then
          pcall(function() SaveBindings(GetCurrentBindingSet()) end)
          GrimuarSetupDB.toggleKey = true
          say("Shift+G otwiera i zamyka okno Grimuara.")
        end
      end
      -- 14.11 (R27 E3): pierwsze uruchomienie = kreator ze zgodami (GrimuarUI Kreator.lua); bez huba stare ustawianie
      if not GrimuarSetupDB.account then
        if G.showWizard then pcall(G.showWizard) else fullSetup() end
      end
      if not GrimuarSetupDB.chars[key] then
        if (UnitLevel("player") or 1) <= 5 then clearMainBar() end
        GrimuarSetupDB.chars[key] = true
        layoutBars(false)
        if G.barsAllowed and G.barsAllowed() then say("gotowe. Nowe czary same trafią na paski po treningu.") end
      else
        layoutBars(true)
      end
    end)
    C_Timer.After(7, function() pcall(arrangeMinimapIcons, false) end)
    C_Timer.After(8, function() pcall(placeConsumables, false) end)
    C_Timer.After(6, function()
      if not GrimuarSetupDB.tidyV then
        GrimuarSetupDB.tidyV = 1
        local okT, res = pcall(G.tidyAddonFrames)
        if okT and res and #res > 0 then say("uporządkowane: " .. table.concat(res, ", ") .. ".") end
      elseif GrimuarSetupDB.hideGryphons then
        pcall(G.hideBarArt)
      end
    end)
    C_Timer.After(10, function()
      if not GrimuarSetupDB.tutorialDone and not GrimuarSetupDB.tutorialOffered and not InCombatLockdown() then
        GrimuarSetupDB.tutorialOffered = true
        pcall(startTutorial, 1)
      end
    end)
  elseif event == "BAG_UPDATE" then
    if GrimuarSetupDB and GrimuarSetupDB.chars and GrimuarSetupDB.chars[charKey()] then queueLayout() end
  elseif event == "SPELLS_CHANGED" then
    if GrimuarSetupDB and GrimuarSetupDB.chars and GrimuarSetupDB.chars[charKey()] then queueLayout() end
  elseif event == "PLAYER_REGEN_ENABLED" then
    if GrimuarSetupDB and GrimuarSetupDB.pending then queueLayout() end
    -- 13.11 (zrzut): gryfy wrocily po /reload w walce i smierci; chowamy je znow po kazdej walce
    if GrimuarSetupDB and GrimuarSetupDB.hideGryphons and G.hideBarArt then pcall(G.hideBarArt) end
    C_Timer.After(1, function()
      local rn = restNeed()
      if rn then remind("rest", rn.text, false, 40) end
    end)
  elseif event == "PLAYER_LEVEL_UP" then
    local newLevel = tonumber(arg1) or ((UnitLevel("player") or 1) + 1)
    C_Timer.After(1, function() announceLevel(newLevel) end)
  elseif event == "PLAYER_XP_UPDATE" then
    pcall(xpUpdate)
    pcall(updateHUD)
  elseif event == "PLAYER_UPDATE_RESTING" then
    C_Timer.After(2, function()
      if IsResting() then pcall(runReminders, "rest") else pcall(runReminders, "leave") end
    end)
  elseif event == "PLAYER_CAMPING" then
    if not IsResting() then
      remind("camp", "wylogowujesz się poza karczmą: nie dostaniesz rested XP. Ruch anuluje wylogowanie. Idź do karczmy albo użyj Hearthstone.", true, 20)
    end
  elseif event == "ZONE_CHANGED_NEW_AREA" then
    C_Timer.After(2, function() pcall(checkZone) end)
  elseif event == "PLAYER_DEAD" then
    pcall(onDeath)
  elseif event == "PLAYER_LOGOUT" then
    pcall(saveCurrent)
  end
end)

SLASH_GRIMUAR1 = "/grimuar"
SLASH_GRIMUAR2 = "/gr" -- UX 12.11: krotka komenda (/g zajete przez czat gildii)
SlashCmdList["GRIMUAR"] = function(msg)
  msg = (msg or ""):lower()
  if msg == "test" then
    if G.selfTest then G.selfTest(true) end
    return
  end
  if msg == "pomoc" or msg == "help" then
    for _, line in ipairs({ "/gr: okno Grimuara (to samo co Shift+G).  /gr test: autotest wszystkich modułów.", "/plan: plan sesji od nowa.  /koniec: prowadź do karczmy.",
      "/sprawdz i /ustaw: kontrola ustawień i Ustaw wszystko.  /loch: przygotowanie do lochu.  /zloto: cele złota.  /rangi: nowe rangi na paskach.",
      "/runy, /wstegi, /focusramka, /globy: wygląd. Wszystko to masz też w oknie: Ustawienia > Przełączniki." }) do say(line) end
    return
  end
  -- 14.11 (R27 E1): buildy. /gr build: lista; /gr build <nr>: ustaw aktywny; pelna obsluga (eksport, import,
  -- edycja, takze szkicow Polestara) w hubie: Umiejetnosci > Buildy (GrimuarUI)
  -- 14.11 (R27 E5): krotkie komendy (/plan, /loch, /npc…) moga kolidowac z innymi addonami. Kazda dziala tez jako
  -- /gr <nazwa> [argumenty]; w wersji publicznej (bez Grimuar_Osobiste) krotkich nie rejestrujemy (Ogolne.lua).
  local word, rest = msg:match("^(%S+)%s*(.*)$")
  local skey = word and G.SLASH_SHORT and G.SLASH_SHORT[word]
  if skey and SlashCmdList[skey] then SlashCmdList[skey](rest or "") return end
  if msg:find("^jezyk") or msg:find("^język") then
    local a = msg:match("^%S+%s+(%S+)$")
    if a == "brak" then
      local n = 0
      for s in pairs(GrimuarSetupDB.trMissing or {}) do n = n + 1 if n <= 20 then say("  " .. s) end end
      say("bez tłumaczenia: " .. n .. " napisów (pierwsze 20 wyżej).")
    elseif a == "en" or a == "pl" then
      G.setLang(a)
      say(a == "en" and "language: English. /reload refreshes all windows." or "język: polski. /reload odświeży wszystkie okna.")
    else say("/gr jezyk pl | en | brak") end
    return
  end
  if msg == "kreator" then
    if G.showWizard then G.showWizard() else say("kreator jest w hubie (addon GrimuarUI).") end
    return
  end
  if msg == "build" or msg:find("^build ") then
    local arg = msg:match("^build%s+(.+)$")
    local list = G.BuildList and G.BuildList(G.playerClassToken and G.playerClassToken()) or {}
    if arg and tonumber(arg) and list[tonumber(arg)] then
      G.SetActiveBuild(list[tonumber(arg)].id)
    elseif arg == "hub" or arg == "eksport" or arg == "import" then
      if GrimuarHubOpen then GrimuarHubOpen("buildy") else say("strona Buildy jest w hubie (addon GrimuarUI).") end
    else
      local act = G.ActiveBuildId and G.ActiveBuildId()
      say("buildy dla Twojej klasy (/gr build <nr> ustawia, hub > Buildy: eksport, import, edycja):")
      for i, b in ipairs(list) do say("  " .. i .. ". " .. b.name .. (b.id == act and "  ← aktywny" or "") .. "  [" .. b.src .. "]") end
    end
    return
  end
  if msg == "aoe" then
    GrimuarSetupDB.trainAoE = not GrimuarSetupDB.trainAoE
    say("czary pod AoE u trenera (Blizzard, Arcane Explosion, Flamestrike, Mana Shield): " .. (GrimuarSetupDB.trainAoE and "kupuję" or "pomijam") .. ".")
    return
  end
  if msg == "ikony" then
    arrangeMinimapIcons(true)
    return
  end
  if msg == "uklad" then
    if InCombatLockdown() then say("poczekaj na koniec walki.") return end
    placeConsumables(true)
    return
  end
  local mins = msg:match("^sesja%s*(%d*)")
  if mins then
    setBudget(tonumber(mins) or 0)
    pcall(updateHUD)
    return
  end
  if msg == "prowadz" or msg == "prowadź" then
    local g = nearestGuide()
    if g then guideTo(g) else say("w tej strefie nie mam celów. Zobacz zakładkę Mapa (Shift+G).") end
    return
  end
  if msg == "usun" or msg == "usuń" then
    clearGuide()
    return
  end
  local tutArg = msg:match("^samouczek%s*(%d*)") or msg:match("^tutorial%s*(%d*)")
  if tutArg then
    startTutorial(tonumber(tutArg) or 1)
    return
  end
  if msg == "dock" then
    GrimuarSetupDB.noDock = not GrimuarSetupDB.noDock
    say(GrimuarSetupDB.noDock and "pasek pod Polestarem wyłączony." or "pasek pod Polestarem włączony.")
    pcall(updateHUD)
    return
  end
  if msg == "komunikaty" then
    GrimuarSetupDB.noToast = not GrimuarSetupDB.noToast
    say(GrimuarSetupDB.noToast and "komunikaty na środku ekranu wyłączone (zostaje czat)." or "komunikaty na środku ekranu włączone.")
    if not GrimuarSetupDB.noToast then pcall(showToast, "tak wyglądają komunikaty Grimuara.", "", false) end
    return
  end
  if msg == "auto" then
    GrimuarSetupDB.noAutoGuide = not GrimuarSetupDB.noAutoGuide
    say(GrimuarSetupDB.noAutoGuide and "automatyczne przełączanie strzałki wyłączone." or "strzałka znów sama przełącza się między questami a trenerem i książkami.")
    return
  end
  if msg == "pro cofnij" then
    G.undoProLayout()
    return
  end
  if msg == "pro" then
    if G.applyProLayout() then return end
    local at = 1
    if G.TUT_REF and G.TUT_REF.chapters then
      for _, c in ipairs(G.TUT_REF.chapters) do
        if c.name == "Układ pro" then at = c.first end
      end
    end
    startTutorial(at)
    return
  end
  if msg == "krok" then
    GrimuarSetupDB.hideStep = not GrimuarSetupDB.hideStep
    say(GrimuarSetupDB.hideStep and "krok na pasku ukryty." or "krok na pasku widoczny.")
    pcall(updateHUD)
    return
  end
  if msg == "setup" or msg == "reset" then
    if InCombatLockdown() then say("poczekaj na koniec walki.") return end
    if msg == "reset" then
      clearMainBar()
      layoutBars(false)
    else
      fullSetup()
      layoutBars(false)
    end
    return
  end
  togglePanel()
end

-- eksport do pozostalych modulow
G.frame = frame
G.layoutQueued = layoutQueued
G.queueLayout = queueLayout
G.refreshQueued = refreshQueued
G.queueRefresh = queueRefresh
G.REFRESH_EVENTS = REFRESH_EVENTS
