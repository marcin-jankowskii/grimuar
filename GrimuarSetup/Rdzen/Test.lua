-- Grimuar: modul Test. Autotest wszystkich modulow (prosba gracza 13.11): /gr test sprawdza funkcje, rysuje kazda strone
-- okna, pokazuje wstege i liczy bledy Grimuara w BugSacku. Wynik w czacie i w GrimuarSetupDB.selfTest (Claude czyta przy sync).
-- Po kazdej nowej wersji test lekki (bez okna) uruchamia sie sam 30 s po wejsciu.
local ADDON_NAME, G = ...
local say = G.say

local NEEDED = {
  "buildSteps", "updateDock", "showToast", "showBanner", "remind", "sessionSteps", "planPending", "startEnding",
  "setupSteps", "audit", "auditOpen", "fixAll", "groupSteps", "bestDungeon", "matsCount", "goldTarget", "upgradeRanks",
  "prePull", "runyEnable", "addRuneCorners", "guideInn", "guideVendor", "findNearestVendor", "stepCategory",
  "pageDzisExtra", "pageKontrola", "pageToggles", "getPanel", "renderPanel", "selectTab", "SECTIONS", "PT",
  "applyBinds", "ensureMacros", "layoutBars", "knownSpellId", "missingTraining", "talentPoints", "freeBagSlots",
  "refreshAll", "deathTip", "sessionSummary", "profSteps", "pageMojeProfesje", "ekranApply", "showSessionEnd", "skinFrame", "barwyApply", "pageKlawisze",
  "partySteps", "pageGrupa", "groupCVars", "soundPage", "playCue", "skinMinimap", "BARWY_VER",
  "socialSteps", "lfgText", "showPage", "pageGrafika", "gfxApply", "calmToggle", "caaToggle",
}

local function version()
  local v
  pcall(function() v = (C_AddOns and C_AddOns.GetAddOnMetadata or GetAddOnMetadata)(ADDON_NAME, "Version") end)
  return v or "?"
end

local function grimuarErrors()
  local n, first = 0, nil
  pcall(function()
    local db, sid = BugGrabber:GetDB(), BugGrabber:GetSessionId()
    for _, e in ipairs(db or {}) do
      if e.session == sid and tostring(e.message):find("GrimuarSetup") then
        n = n + 1
        first = first or tostring(e.message):sub(1, 160)
      end
    end
  end)
  return n, first
end

local function run(full)
  local ok, fail = {}, {}
  local function check(name, fn)
    local good, res = pcall(fn)
    if good and res ~= false then ok[#ok + 1] = name .. (type(res) == "string" and (": " .. res) or "")
    else fail[#fail + 1] = name .. ": " .. tostring(res) end
  end
  local missing = {}
  for _, n in ipairs(NEEDED) do if G[n] == nil then missing[#missing + 1] = n end end
  check("moduły", function() return #missing == 0 and "wszystkie" or error("brak " .. table.concat(missing, ", ")) end)
  check("kroki paska", function()
    local s = G.buildSteps()
    return #s .. " kroków" .. (s[1] and (", pierwszy: " .. s[1].key .. " (" .. (G.stepCategory(s[1].key)) .. ")") or "")
  end)
  check("kontrola", function() local c = G.audit() return "w porządku " .. (c.okN or 0) .. ", do poprawy " .. #G.auditOpen() end)
  check("lochy", function() return G.bestDungeon(15)[3] end)
  check("karczma", function()
    local v, why = G.findNearestVendor("inn")
    if v then return (v.name or "?") .. ", " .. math.floor((v.dist or 0) * 0.9144) .. " m" end
    return why == "far" and "inny kontynent" or error(tostring(why))
  end)
  check("złoto", function() return "zioła i ruda w torbach: " .. G.matsCount() end)
  check("profesje", function()
    local parts = {}
    for _, n in ipairs({ "Herbalism", "Mining", "First Aid", "Cooking", "Fishing" }) do
      local r = G.profRank(n)
      if r > 0 then parts[#parts + 1] = n .. " " .. r end
    end
    return #parts > 0 and table.concat(parts, ", ") or error("nie odczytano żadnej profesji")
  end)
  check("dymki przedmiotów", function() return G.tooltipHooked and "podpięte" or error("niepodpięte") end)
  check("klawisz focusa", function() return GetBindingKey("MACRO Focus") or error("brak") end)
  check("makra", function()
    local miss = {}
    for _, m in ipairs(G.MACROS or {}) do if GetMacroIndexByName(m[1]) == 0 then miss[#miss + 1] = m[1] end end
    return #miss == 0 and "komplet" or error("brak: " .. table.concat(miss, ", "))
  end)
  check("styl Runy", function()
    if not GrimuarSetupDB.runy then return "wyłączony" end
    return (_G.GrimuarRunyRing and GrimuarRunyRing:IsShown()) and "łuki widoczne" or error("włączony, ale łuków nie ma")
  end)
  check("układ ekranu", function()
    local ln
    pcall(function()
      local info = C_EditMode.GetLayouts()
      local nPre = EditModePresetLayoutManager and #(EditModePresetLayoutManager:GetCopyOfPresetLayouts() or {}) or 0
      local a = info.activeLayout
      ln = (a and a > nPre) and info.layouts[a - nPre].layoutName or "wbudowany"
    end)
    return "aktywny: " .. tostring(ln) .. (GrimuarSetupDB.ekranRuny and " (Runy włączone)" or "")
  end)
  check("czcionki motywu", function()
    -- 14.11: poprawiony test (przypiety napis, proby co 0,5 s; Core.lua G.uiFont). Wynik dla huba GrimuarUI.
    if G.uiFontsReady then
      if G.uiFontsReady() then return "Alegreya rysuje (hub); stare okna zostają na ARIALN" end
      if G.retryUiFonts then G.retryUiFonts() end
      GrimuarSetupDB.fontDiag = { load = table.concat(G.fontDiag or {}, "; "), at = date("%Y-%m-%d %H:%M") }
      error("Alegreya jeszcze nie rysuje (" .. table.concat(G.fontDiag or {}, "; ") ..
        "). Sprawdź ponownie za 5 s; jeśli dalej nie: pełny restart gry (nie /reload).")
    end
    if G.customFonts then return "Alegreya wczytana" end
    -- 13.11: przy wczytaniu addonu gra odrzucila Alegreye (SetFont=false). Proba teraz, w trakcie gry, i porownanie
    -- z czcionkami innych addonow: wynik mowi, czy to pora wczytania, nasz plik, czy kazda czcionka z addonu.
    local function try(path)
      local r, got
      pcall(function()
        local fs = UIParent:CreateFontString(nil, "OVERLAY")
        r = fs:SetFont(path, 12, "")
        got = fs:GetFont()
        fs:Hide()
      end)
      return tostring(r) .. (got and "" or " (brak)")
    end
    local now = "Alegreya " .. try("Interface\\AddOns\\GrimuarSetup\\Media\\AlegreyaSans-Medium.ttf") ..
      ", Fira z Polestara " .. try("Interface\\AddOns\\Polestar\\Media\\Fonts\\FiraSans-Medium.ttf") ..
      ", BBP " .. try("Interface\\AddOns\\BetterBlizzPlates\\media\\Expressway_Free.ttf")
    GrimuarSetupDB.fontDiag = { load = table.concat(G.fontDiag or {}, "; "), now = now, at = date("%Y-%m-%d %H:%M") }
    -- 13.11 wynik z gry: false dla Alegreyi, Firy z Polestara i czcionki BBP, wiec Forever nie wczytuje zadnej czcionki
    -- z folderu addonow. To granica klienta, nie blad: Grimuar pisze ARIALN (polskie litery). Blad tylko, gdy inne addony moga.
    if not now:find("true") then return "Forever nie wczytuje czcionek z addonów (też Polestar i BBP): ARIALN z polskimi literami" end
    error("zapas ARIALN, a czcionki innych addonów działają. Teraz: " .. now)
  end)
  check("trasy Polestara", function()
    if type(Polestar) ~= "table" or not Polestar.Get then return "brak Polestara" end
    if not Polestar.Get("nav.navRouting") then error("wyłączone: Polestar > Walk real paths") end
    local eng = (type(Polestar.Nav) == "table" and Polestar.Nav.Path) or _G.Polestar_NavEngine
    return eng and "prawdziwe ścieżki (jaskinie, mosty, windy)" or "włączone, silnik tras wczyta się przy pierwszej trasie"
  end)
  check("Masque", function() return (G.masqueActive and G.masqueActive()) and ("skórka " .. (G.masqueSkin or "?")) or "brak Masque (cienkie ramki z Grimuara)" end)
  check("questy z postaci", function()
    if not G.questIndexReady or not G.questIndexReady() then return "indeks Questie jeszcze się buduje (ok. 30 s po wejściu)" end
    local done, all = 0, 0
    for _, q in ipairs(G.QUESTS or {}) do
      local n = q[2]:match("„([^”]+)”")
      if n then all = all + 1 if G.questStatus(n) == "done" then done = done + 1 end end
    end
    return "zrobione " .. done .. " z " .. all .. " questów z listy Grimuara"
  end)
  check("klawisze okien", function()
    local i, h, m = GetBindingAction("I"), GetBindingAction("H"), GetBindingAction("M")
    return ((i == "GRIMUAR_HUB_POSTAC") and "I: hub, Postać" or (i == "TOGGLECHARACTER0" or i == "GRIMUAR_EKWIPUNEK") and "I: ekwipunek" or ("I: " .. tostring(i))) .. ", " ..
      (m == "GRIMUAR_HUB_MAPA" and "M: hub, Mapa" or ("M: " .. tostring(m))) .. ", " .. (h == "MACRO Kamien" and "H: Hearthstone" or ("H: " .. tostring(h)))
  end)
  check("apteczka", function()
    if GetMacroIndexByName("Bandaz") == 0 or GetMacroIndexByName("Mikstura") == 0 then error("brak makr Bandaz/Mikstura") end
    local c, v = GetBindingAction("C"), GetBindingAction("V")
    return "C: " .. (c == "MACRO Bandaz" and "bandaż" or tostring(c)) .. ", V: " .. (v == "MACRO Mikstura" and "mikstura" or tostring(v))
  end)
  check("minimapa", function()
    if GrimuarSetupDB.minimapRect == false then return "okrągła (wybór /minimapa)" end
    if (G.minimapLeatrixLive and G.minimapLeatrixLive()) or (type(LeaPlusDB) == "table" and LeaPlusDB.MinimapModder == "On") then
      return "w tej sesji kwadrat Leatrixa, prostokąt po następnym /reload"
    end
    local w, h = Minimap:GetSize()
    return (GetMinimapShape and GetMinimapShape() == "SQUARE" and w and w > 220) and ("prostokąt (" .. math.floor(w) .. " px)") or error("nie prostokątna, rozmiar " .. tostring(w))
  end)
  check("makra grupy", function()
    local a, b = GetMacroIndexByName("Intelekt"), GetMacroIndexByName("Klatwa")
    if a == 0 or b == 0 then error("brak makr Intelekt/Klatwa") end
    return "Intelekt i Klatwa są"
  end)
  check("limit FPS", function()
    local u, m = C_CVar.GetCVar("useMaxFPS"), C_CVar.GetCVar("maxFPS")
    if u ~= "1" then error("useMaxFPS=" .. tostring(u) .. ", maxFPS=" .. tostring(m)) end
    return "włączony, " .. tostring(m) .. " FPS"
  end)
  check("menu Esc", function() return G.escHooked and "przyciski Grimuara podpięte" or error("niepodpięte") end)
  check("wstęga", function()
    G.showBanner("autotest: tak wyglądają wstęgi Grimuara.", "plan", false)
    return (_G.GrimuarBanner and GrimuarBanner:IsShown()) and "widoczna" or error("nie pokazała się")
  end)
  if full then
    local cur = GrimuarSetupDB.tab or "teraz"
    for _, s in ipairs(G.SECTIONS or {}) do
      for _, key in ipairs(s[3]) do
        check("okno: " .. s[2] .. " > " .. key, function()
          if not G.getPanel() or not G.getPanel():IsShown() then SlashCmdList.GRIMUAR("") end
          G.selectTab(key)
          return true
        end)
      end
    end
    pcall(G.selectTab, cur)
  end
  local nErr, firstErr = grimuarErrors()
  check("BugSack", function() return nErr == 0 and "bez błędów Grimuara" or error(nErr .. " błędów, pierwszy: " .. (firstErr or "?")) end)
  GrimuarSetupDB.selfTest = { at = date("%Y-%m-%d %H:%M"), version = version(), full = full and true or false, ok = ok, fail = fail }
  say("autotest Grimuara " .. version() .. ": " .. #ok .. " z " .. (#ok + #fail) .. " w porządku.")
  for _, f in ipairs(fail) do say("  BŁĄD: " .. f) end
  if full and #fail == 0 then say("  wszystko działa.") elseif #fail > 0 then say("  " .. G.helpHint()) end
  return #fail
end

local ev = CreateFrame("Frame")
ev:RegisterEvent("PLAYER_LOGIN")
ev:SetScript("OnEvent", function()
  C_Timer.After(30, function()
    if GrimuarSetupDB.testedVersion == version() or InCombatLockdown() then return end
    GrimuarSetupDB.testedVersion = version()
    pcall(run, false)
  end)
end)

G.selfTest = run
