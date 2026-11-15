-- Grimuar: modul Kontrola. Sprawdza, czego brakuje w ustawieniach gry i addonach (prosba gracza 12.11):
-- addony (brak / wylaczony / nieaktualny), ustawienia gry (CVary z Core i Addony), klawisze, makra, focus, pasek 2,
-- uklad Edit Mode, opcje w addonach (Leatrix, Polestar, BBP, Shot Window, Forever Cast, Forever DR), Pawn, styl Runy,
-- timer rozdzki, aury Musca. „Ustaw wszystko” (/ustaw) robi naraz kazda poprawke, ktora da sie zrobic automatycznie.
-- Pierwszy problem trafia na pasek Grimuara z przyciskiem Napraw (gdy da sie automatycznie) albo Zostaw
-- (swiadomie inaczej, wiecej nie pyta). /sprawdz wypisuje caly raport. Wynik w GrimuarSetupDB.audit (do synchronizacji).
local ADDON_NAME, G = ...
local say = G.say

-- { folder, opis, czy wazny (true = ostrzegaj; false = tylko w raporcie) }
local ADDONS = {
  { "Questie", "questy na mapie", true }, { "Polestar", "przewodnik ze strzałką", true },
  { "Leatrix_Plus", "sprzedaż śmieci i naprawa", true }, { "Pawn", "porównanie przedmiotów", true },
  { "BetterBlizzPlates", "plakietki mobów", true }, { "ThreatClassic2", "pasek zagrożenia", true },
  { "GatherMate2", "mapa ziół i rudy", true }, { "Spy", "wrogowie w pobliżu (PvP)", true },
  { "ShotWindow", "strefa „stój” przy różdżce", true, "wand" }, { "ForeverCast", "pasek rzucania z opóźnieniem", true, "caster" },
  { "ForeverDR", "skracanie kontroli w PvP", false }, { "WeakAuras", "Musca Auras: znaczniki procków", true, "personal" },
  { "BugSack", "zbieranie błędów addonów", true }, { "!BugGrabber", "zbieranie błędów addonów", true },
  { "Auctionator", "dom aukcyjny", false }, { "Baganator", "torby w jednym oknie", false },
  { "Leatrix_Maps", "lepsza mapa", false }, { "DBM-Core", "ostrzeżenia w lochach", false },
  { "AtlasLootClassic", "łupy z lochów", false }, { "FrugNearby", "gracze w pobliżu", false },
}

local cache = { t = 0, issues = {}, okN = 0 }
local needReload = false

local function addonState(name)
  local loaded, reason, exists = false, nil, true
  pcall(function()
    local isLoaded = (C_AddOns and C_AddOns.IsAddOnLoaded) or IsAddOnLoaded
    loaded = isLoaded(name) and true or false
    local info = (C_AddOns and C_AddOns.GetAddOnInfo) or GetAddOnInfo
    local _, _, _, _, r = info(name)
    reason = r
  end)
  if reason == "MISSING" then exists = false end
  return loaded, reason, exists
end

local function enableAddon(name)
  pcall(function()
    if C_AddOns and C_AddOns.EnableAddOn then C_AddOns.EnableAddOn(name) else EnableAddOn(name) end
  end)
  needReload = true
end

local function getCVar(n)
  local v
  pcall(function() v = (C_CVar and C_CVar.GetCVar or GetCVar)(n) end)
  return v
end

local function same(a, b)
  if a == nil then return true end -- nieznane ustawienie w tym kliencie: nie zglaszamy
  if tonumber(a) and tonumber(b) then return tonumber(a) == tonumber(b) end
  return tostring(a) == tostring(b)
end

local function bindingsOff()
  local off = {}
  for _, b in ipairs(G.BINDS or {}) do
    local cur
    pcall(function() cur = GetBindingAction(b[1]) end)
    if cur ~= b[2] then off[#off + 1] = b[1]:gsub("SHIFT%-", "Shift+") end
  end
  return off
end

local function layoutName()
  local name
  pcall(function()
    local info = C_EditMode.GetLayouts()
    local nPre = 0
    if EditModePresetLayoutManager and EditModePresetLayoutManager.GetCopyOfPresetLayouts then
      nPre = #(EditModePresetLayoutManager:GetCopyOfPresetLayouts() or {})
    end
    local a = info.activeLayout
    if a and a > nPre then name = info.layouts[a - nPre].layoutName else name = "(wbudowany Blizzarda)" end
  end)
  return name
end

-- ---------- opcje wewnatrz addonow (profil Grimuara) ----------
-- { folder, tabela z ustawieniami (funkcja; nil = addon jeszcze nie utworzyl zapisu, wtedy nie sprawdzamy), klucz, wartosc, opis }
local function fcProfile()
  local s = ForeverCastDB
  if type(s) ~= "table" or type(s.profiles) ~= "table" then return nil end
  if type(s.profiles.Default) == "table" then return s.profiles.Default end
  for _, p in pairs(s.profiles) do if type(p) == "table" then return p end end
end
local function fcBar(which)
  local p = fcProfile()
  return p and type(p.bars) == "table" and type(p.bars[which]) == "table" and p.bars[which] or nil
end
local function bbpDB()
  local d = BetterBlizzPlatesDB
  return (type(d) == "table" and d.hasSaved) and d or nil
end
local function polestar(part)
  local d = PolestarDB
  if type(d) ~= "table" or type(d.settings) ~= "table" then return nil end
  if d.settings[part] == nil then d.settings[part] = {} end
  return type(d.settings[part]) == "table" and d.settings[part] or nil
end
-- ThreatClassic2 (AceDB): profil wg profileKeys, jak w Uklad.lua
local function tc2Warnings()
  local d = ThreatClassic2DB
  if type(d) ~= "table" or type(d.profiles) ~= "table" then return nil end
  local key = "Default"
  if type(d.profileKeys) == "table" then for _, v in pairs(d.profileKeys) do key = v break end end
  local p = d.profiles[key]
  return type(p) == "table" and type(p.warnings) == "table" and p.warnings or nil
end
local function spyProfile()
  return type(Spy) == "table" and type(Spy.db) == "table" and type(Spy.db.profile) == "table" and Spy.db.profile or nil
end
local function dbmOptions()
  if type(DBM) == "table" and type(DBM.Options) == "table" then return DBM.Options end
  local d = DBM_AllSavedOptions
  return type(d) == "table" and type(d.Default) == "table" and d.Default or nil
end
local function baganator()
  local d = BAGANATOR_CONFIG
  return type(d) == "table" and type(d.Profiles) == "table" and type(d.Profiles.DEFAULT) == "table" and d.Profiles.DEFAULT or nil
end
-- Leatrix przy wylogowaniu i /reload nadpisuje LeaPlusDB swoja kopia (Leatrix_Plus.lua, PLAYER_LOGOUT);
-- „nosave” wylacza to jednorazowo, wiec nasza zmiana przetrwa przeladowanie (R9, 12.11).
local function leatrixNoSave()
  if SlashCmdList and SlashCmdList.Leatrix_Plus then pcall(SlashCmdList.Leatrix_Plus, "nosave") end
end

-- R9 (12.11, gaming-warsztat/wow/research/R9-addony-pro-2611.md): klucze sprawdzone w kodzie addonow.
local function lea() return LeaPlusDB end
local OPTS = {
  { "Leatrix_Plus", lea, "AutoSellJunk", "On", "sprzedaż śmieci u kupca", leatrixNoSave },
  { "Leatrix_Plus", lea, "AutoRepairGear", "On", "naprawa u kupca", leatrixNoSave },
  { "Leatrix_Plus", lea, "NoDuelRequests", "On", "bez zaproszeń do pojedynków", leatrixNoSave },
  { "Leatrix_Plus", lea, "AutoReleasePvP", "On", "szybkie odrodzenie na battlegroundach", leatrixNoSave },
  -- 13.11 prosby gracza: prostokatna minimapa robi Grimuar (Prostokat.lua), kwadrat Leatrixa by ja nadpisal;
  -- ladniejszy czat (Czat.lua): boczne przyciski, Combat Log i spam z pojedynkow chowa Leatrix
  { "Leatrix_Plus", lea, "MinimapModder", "Off", "minimapę rysuje Grimuar (prostokąt)", leatrixNoSave },
  { "Leatrix_Plus", lea, "NoChatButtons", "On", "czat bez bocznych przycisków", leatrixNoSave },
  { "Leatrix_Plus", lea, "NoCombatLogTab", "On", "czat bez zakładki Combat Log", leatrixNoSave },
  -- 13.11: FilterChatMessages i BlockDuelSpam wypadly: Leatrix w Forever sam je wylacza przy kazdym starcie
  -- (LockDF: „breaks chat at the moment due to game bug”), wiec Napraw krecil sie w kolko (gracz: „3 razy i nie znika”)
  { "Leatrix_Plus", lea, "RestoreChatMessages", "On", "czat zostaje po /reload", leatrixNoSave },
  -- 15.11 (R30 P02): ps = sekcja ustawien Polestara; odczyt Polestar.Get, zapis Polestar.Set (dziala bez /reload)
  { "Polestar", function() return polestar("qol") end, "deathHelper", false, "duch: strzałka do ciała z Grimuara, nie do Spirit Healera", ps = "qol" },
  -- 15.11: Polestar 0.3.7.1 usunal przycisk Train All i nauke u trenera (opcja qol.trainAllButton juz nie istnieje)
  { "Polestar", function() return polestar("qol") end, "questTooltips", false, "dymki questów tylko z Questie (bez dubli)", ps = "qol" },
  { "Polestar", function() return polestar("qol") end, "sellJunk", false, "śmieci sprzedaje Leatrix (bez dubla)", ps = "qol" },
  { "Polestar", function() return polestar("qol") end, "autoRepair", false, "naprawia Leatrix (bez dubla)", ps = "qol" },
  { "Polestar", function() return polestar("qol") end, "fastLoot", false, "szybkie łupy bez dubla", ps = "qol" },
  { "Polestar", function() return polestar("qol") end, "skipGossip", false, "rozmowy z NPC bez dubla", ps = "qol" },
  -- 15.11 (gracz: lista celow przeswituje spod okna Polestara): lista celow gry schowana (Polestar QoL\Toggles.lua)
  { "Polestar", function() return polestar("qol") end, "hideQuestTracker", true, "lista celów gry schowana (questy w oknie Polestara i w Dzienniku)", ps = "qol" },
  -- 15.11 (R30 etap 3, decyzja Q7 „Grimuar pokazuje, w Polestarze wylaczam”): karta „loch otwarty, zbierz questy”
  -- (UI\DungeonToast.lua) dubluje Wyprawy Grimuara (P46). Opcja wylacza tylko te karte: dane lochow, PickupPlan i PickUp
  -- dzialaja dalej (Dungeons.IsEnabled to dungeons.enabled). Czarow na poziom (qol.levelUpSpells -> LEVELUP_SPELLS),
  -- „Przy okazji” (behavior.whileHere -> dane GetWhileHereList) i questow klasowych (behavior.offerClassQuests ->
  -- CLASS_QUEST_READY) nie wylaczamy: od tych opcji zaleza komunikaty i dane, z ktorych korzysta Grimuar.
  { "Polestar", function() return polestar("dungeons") end, "headsUp", false, "lochy: zbieranie questów pokazują Wyprawy Grimuara (bez karty Polestara)", ps = "dungeons" },
  { "Spy", spyProfile, "DisableWhenPVPUnflagged", true, "cisza, gdy nie masz flagi PvP" },
  { "Spy", spyProfile, "ResizeSpyLimit", 8, "okno na najwyżej 8 graczy" },
  { "ThreatClassic2", tc2Warnings, "sound", true, "dźwięk, gdy przejmujesz aggro" },
  { "ThreatClassic2", tc2Warnings, "flash", true, "błysk ekranu, gdy przejmujesz aggro" },
  { "DBM-Core", dbmOptions, "AFKHealthWarning2", true, "ostrzeżenie, gdy ktoś Cię bije, a Ty jesteś AFK" },
  { "Baganator", baganator, "icon_grey_junk", true, "znacznik śmieci w torbach" },
  { "Baganator", baganator, "icon_mark_unusable", true, "znacznik rzeczy, których nie założysz" },
  { "Auctionator", function() return AUCTIONATOR_CONFIG end, "auction_duration", 48, "najdłuższe aukcje (mniej wystawiania)" },
  { "ForeverCast", function() return fcBar("target") end, "bigShield", true, "duża tarcza przy czarze nie do przerwania" },
  -- decyzja gracza 12.11: FrugNearby bez dzwieku, alarm daje Spy (bez dwoch alarmow na jednego wroga)
  { "FrugNearby", function() return FrugNearbyDB end, "soundAlert", false, "bez dźwięku (alarm daje Spy)" },
  -- gracz 13.11: questy prowadzi Polestar; Questie zostaje jako baza danych Grimuara (kupcy, karczmy, zrobione questy)
  { "Questie", function() return Questie and Questie.db and Questie.db.profile end, "trackerEnabled", false, "lista questów na ekranie tylko z Polestara" },
  { "ShotWindow", function() return ShotWindowDB end, "sound", true, "dźwięk, gdy trzeba stanąć przy różdżce" },
  { "ForeverCast", function() return fcBar("target") end, "cantInterruptText", true, "napis „nie da się przerwać” na celu" },
  { "ForeverCast", function() return fcBar("focus") end, "cantInterruptText", true, "napis „nie da się przerwać” na focusie" },
  { "ForeverCast", function() local p = fcProfile() return p and type(p.nameplates) == "table" and p.nameplates or nil end,
    "enabled", false, "plakietki zostają dla BetterBlizzPlates" },
  { "ForeverCast", fcProfile, "hideBlizzardNameplates", false, "pasek rzucania na plakietkach z BetterBlizzPlates" },
  { "ForeverDR", function() return ForeverDRDB end, "focus", true, "kontrola (DR) także na focusie" },
}
for k, v in pairs(G.BBP_SET or {}) do OPTS[#OPTS + 1] = { "BetterBlizzPlates", bbpDB, k, v, "plakietki: " .. k } end
OPTS[#OPTS + 1] = { "BetterBlizzPlates", bbpDB, "totemIndicator", true, "plakietki: znacznik totemów" }
-- R21: zestawy plakietek PvE i PvP (BBP ustawia z nich CVary przy kazdej zmianie strefy)
local function bbpSet(k) local d = bbpDB() return d and type(d[k]) == "table" and d[k] or nil end
for _, set in ipairs({ { "nameplateToggles_pve", "PvE" }, { "nameplateToggles_pvp", "PvP" } }) do
  OPTS[#OPTS + 1] = { "BetterBlizzPlates", function() return bbpSet(set[1]) end, "stackingEnemy", true, "plakietki wrogów jedna nad drugą (" .. set[2] .. ")" }
  OPTS[#OPTS + 1] = { "BetterBlizzPlates", function() return bbpSet(set[1]) end, "nameplateShowEnemyTotems", true, "plakietki totemów wroga (" .. set[2] .. ")" }
end
OPTS[#OPTS + 1] = { "BetterBlizzPlates", bbpDB, "absorbIndicator", true, "plakietki: tarcze pochłaniające" }

local function optEqual(a, b)
  if type(a) == "number" and type(b) == "number" then return math.abs(a - b) < 0.001 end
  return a == b
end

local function addonOptions(bad, good)
  local by, order = {}, {}
  for _, o in ipairs(OPTS) do
    if addonState(o[1]) then
      local okT, t = pcall(o[2])
      -- 15.11 (R30 P02): opcje Polestara czytane przez Polestar.Get (wartosc domyslna nie lezy w zapisie)
      -- 15.11 (gracz: „i to nie znika”): bez „a and b or nil”, bo wartosc false dawala nil i opcje „wylaczone”
      -- (Questie trackerEnabled, ForeverCast, BBP) zawsze wychodzily jako inne niz w Grimuarze
      local cur
      if okT and type(t) == "table" then cur = t[o[3]] end
      if o.ps and Polestar and Polestar.Get then
        local okG, v = pcall(Polestar.Get, o.ps .. "." .. o[3])
        if okG then cur, okT, t = v, true, t or {} end
      end
      if okT and type(t) == "table" then
        if optEqual(cur, o[4]) then
          good()
        else
          if not by[o[1]] then by[o[1]] = {} order[#order + 1] = o[1] end
          table.insert(by[o[1]], o)
        end
      end
    end
  end
  for _, name in ipairs(order) do
    local list = by[name]
    local names = {}
    for i = 1, math.min(2, #list) do names[#names + 1] = list[i][5] end
    bad("opt-" .. name, name .. ": " .. #list .. (#list == 1 and " opcja inna" or " opcje inne") .. " niż w Grimuarze (" ..
      table.concat(names, ", ") .. (#list > 2 and ", …" or "") .. ").",
      "Napraw ustawi je jak w Grimuarze, potem przeładowanie UI.",
      function()
        local after, reload = {}, false
        for _, o in ipairs(list) do
          if o.ps and Polestar and Polestar.Set and pcall(Polestar.Set, o.ps .. "." .. o[3], o[4]) then
            -- Polestar przyjal zmiane od razu (SETTING_CHANGED), bez /reload
          else
            pcall(function() local t = o[2]() if type(t) == "table" then t[o[3]] = o[4] end end)
            reload = true
          end
          if o[6] then after[o[6]] = true end
        end
        for fn in pairs(after) do pcall(fn) end
        if reload then needReload = true end
      end)
  end
end

-- Lista problemow: { id, text, why, fix = funkcja albo nil }
local function audit()
  local issues, okN = {}, 0
  local function bad(id, text, why, fix) issues[#issues + 1] = { id = id, text = text, why = why, fix = fix } end
  local function good() okN = okN + 1 end

  -- addony; 14.11 (R27 1, wiersz 33): „wazny” zalezy od klasy (rozdzka, czary), trybu prywatnego i pola addons buildu
  local _, cls = UnitClass("player")
  local function needed(a)
    if not a[3] then
      for _, n in ipairs((G.Build and G.Build() or {}).addons or {}) do if n == a[1] then return true end end
      return false
    end
    if a[4] == "wand" then return cls == "MAGE" or cls == "PRIEST" or cls == "WARLOCK" end
    if a[4] == "caster" then return cls == "MAGE" or cls == "PRIEST" or cls == "WARLOCK" or cls == "SHAMAN" or cls == "DRUID" end
    if a[4] == "personal" then return G.personal and G.personal() end
    return true
  end
  for _, a in ipairs(ADDONS) do
    local loaded, reason, exists = addonState(a[1])
    if loaded then
      good()
    elseif needed(a) then
      if not exists then
        bad("addon-" .. a[1], "Brak addonu " .. a[1] .. " (" .. a[2] .. ").", (G.personal() and "Napisz Claude'owi: pobierze go za Twoją zgodą." or "Zainstaluj go: CurseForge, wersja dla WoW Forever."))
      elseif reason == "INTERFACE_VERSION" then
        bad("addon-" .. a[1], "Addon " .. a[1] .. " jest oznaczony jako nieaktualny.",
          "Esc > AddOns > zaznacz „Load out of date AddOns”, albo poszukaj nowszej wersji.")
      elseif reason == "DEMAND_LOADED" then
        good()
      else
        bad("addon-" .. a[1], "Addon " .. a[1] .. " jest wyłączony (" .. a[2] .. ").", "Napraw włączy go, potem przeładowanie UI.",
          function() enableAddon(a[1]) end)
      end
    end
  end

  -- ustawienia gry
  local cv = {}
  for _, c in ipairs(G.CVARS or {}) do cv[#cv + 1] = c end
  for _, c in ipairs(G.CLIENT_CVARS or {}) do cv[#cv + 1] = c end
  for _, c in ipairs(G.GROUP_CVARS or {}) do cv[#cv + 1] = c end
  for _, c in ipairs(G.GFX_CVARS or {}) do cv[#cv + 1] = c end
  local wrong = {}
  for _, c in ipairs(cv) do
    local cur = getCVar(c[1])
    if cur == nil or same(cur, c[2]) then good() else wrong[#wrong + 1] = c end -- nil: tej opcji w grze nie ma
  end
  if #wrong > 0 then
    local names = {}
    for i = 1, math.min(3, #wrong) do names[#names + 1] = wrong[i][3] or wrong[i][1] end
    bad("cvars", "Ustawienia gry inne niż w Grimuarze: " .. #wrong .. " (" .. table.concat(names, ", ") .. (#wrong > 3 and ", …" or "") .. ").",
      "Napraw przywróci ustawienia z Grimuara. Zostaw, jeśli zmieniłeś je celowo.",
      function() for _, c in ipairs(wrong) do pcall(G.setCVarSafe, c[1], c[2]) end end)
  end

  -- klawisze, makra, focus, pasek 2
  local off = bindingsOff()
  if #off == 0 then good() else
    bad("binds", "Klawisze inne niż w Grimuarze: " .. table.concat(off, ", ", 1, math.min(5, #off)) .. ".",
      "Napraw ustawi je jak na dashboardzie. Zostaw, jeśli przestawiłeś je celowo.", function() pcall(G.applyBinds) end)
  end
  local missingM = {}
  for _, m in ipairs(G.MACROS or {}) do
    local idx = 0
    pcall(function() idx = GetMacroIndexByName(m[1]) end)
    if idx == 0 then missingM[#missingM + 1] = m[1] end
  end
  if #missingM == 0 then good() else
    bad("macros", "Brak makr: " .. table.concat(missingM, ", ") .. ".", "Napraw je utworzy.",
      function() pcall(G.ensureMacros) if G.layoutBars then pcall(G.layoutBars, true) end end)
  end
  local fk
  pcall(function() fk = GetBindingKey("MACRO Focus") end)
  if fk or GetMacroIndexByName("Focus") == 0 then good() else
    bad("focus", "Focus nie ma klawisza.", "Napraw przypisze Alt+R (albo inny wolny).",
      function() GrimuarSetupDB.focusV = nil if G.bindFocus then pcall(G.bindFocus) end end)
  end
  if _G.MultiBarBottomLeft and not MultiBarBottomLeft:IsShown() then
    bad("bar2", "Pasek 2 (Q, E, R, F…) jest ukryty.", "Napraw go pokaże.", function() pcall(G.showBar2) end)
  else
    good()
  end

  -- uklad Edit Mode
  local ln = layoutName()
  if ln == nil or ln == "Grimuar" or ln == "Grimuar Runy" then good() else
    bad("layout", "Aktywny układ ekranu to „" .. ln .. "”, a nie Grimuar.", "Napraw przełączy na układ Grimuar (potem przeładowanie).",
      function() pcall(G.applyProLayout) needReload = true end)
  end

  -- opcje w addonach: Leatrix, Polestar, Shot Window, Forever Cast, Forever DR, BetterBlizzPlates
  addonOptions(bad, good)

  -- Spy: okno z domyslnego miejsca (nachodzi na Damage Done i Threat) pod liczniki w lewym gornym rogu
  local sp = spyProfile()
  if sp and type(sp.MainWindow) == "table" and type(sp.MainWindow.Position) == "table" then
    local pos = sp.MainWindow.Position
    if pos.x == 4 and pos.y == 740 then
      bad("spy-pos", "Okno Spy stoi na liczniku Damage Done.", "Napraw przesunie je pod Damage Done i Threat.", function()
        local below
        pcall(function()
          local t = _G.ThreatClassic2BarFrame
          local dm = G.damageMeterFrame and G.damageMeterFrame()
          below = (t and t:IsShown() and t:GetBottom()) or (dm and dm:GetBottom())
        end)
        local y = math.floor((below or (UIParent:GetHeight() * 0.72)) - 10)
        pos.x, pos.y = 16, y
        pcall(function() Spy:RestoreMainWindowPosition(pos.x, pos.y, pos.w or 160, 34) end)
      end)
    else
      good()
    end
  end

  -- Pawn (jednorazowe ustawienie Grimuara)
  if addonState("Pawn") then
    local pv = GrimuarSetupDB.pawnV
    if type(pv) == "table" and pv[G.charKey()] then good() else
      bad("pawn", "Pawn nie jest jeszcze ustawiony tylko na Frosta.", "Napraw ukryje inne skale.", function() pcall(G.pawnFrostOnly) end)
    end
  end

  -- barwy Runy w addonach (13.11, R15)
  if (GrimuarSetupDB.barwyV or 0) >= (G.BARWY_VER or 1) or not G.barwyApply then good() else
    bad("barwy", "Addony nie mają jeszcze barw Grimuara.", "Napraw przemaluje Spy, pasek zagrożenia, DBM, Baganatora, Shot Window, Forever Cast, Polestar, GatherMate2, plakietki i minimapę. Pełny efekt po przeładowaniu.",
      function() if G.barwyApply() then needReload = true end end)
  end

  -- uklad ekranu Runy w Edit Mode (13.11)
  if GrimuarSetupDB.ekranRuny or not G.ekranApply then good() else
    bad("ekran", "Układ ekranu Runy nie jest jeszcze włączony.", "Napraw ustawi paski, ramki, odnowienia i czat jak na makiecie. Stary układ Grimuar zostaje (/ekran stary).",
      function() if G.ekranApply() then needReload = true end end)
  end

  -- styl Runy (wybrany 12.11)
  if GrimuarSetupDB.runy then good() else
    bad("runy", "Styl Pustynia i Runy jest wyłączony.", "Napraw go włączy (to samo co /runy).",
      function() if SlashCmdList.GRIMUARRUNY then SlashCmdList.GRIMUARRUNY("") end end)
  end

  -- timer rozdzki (Shot Window rysuje na wbudowanym timerze)
  if addonState("ShotWindow") then
    local on = _G.SwingTimerRangedFrame ~= nil
    for _, s in ipairs(GrimuarSetupDB.swingCVars or {}) do
      local n, v = s:match("^(.-)=(.*)$")
      if n and n:lower():find("swingtimer") and (v == "1" or v == "true") then on = true end
    end
    if on then good() else
      bad("swing", "Wbudowany timer różdżki jest chyba wyłączony.",
        "Esc > Opcje > Zaawansowane > Swing Timer, potem Edit Mode > Ranged Swing Timer. Kliknij Mam, gdy włączysz.")
    end
  end

  -- aury Musca od 10 poziomu
  if addonState("WeakAuras") and (UnitLevel("player") or 1) >= 10 then
    local n = 0
    if type(WeakAurasSaved) == "table" and type(WeakAurasSaved.displays) == "table" then
      for _ in pairs(WeakAurasSaved.displays) do n = n + 1 end
    end
    if n > 0 then good() else
      bad("musca", "Brak aur maga w Musca Auras (procki, zamrożony cel, pancerz).",
        "Napraw otworzy gotowy pakiet aur maga z Musca: kliknij w nim Import.",
        (type(WeakAuras) == "table" and WeakAuras.ImportClassPack) and function() WeakAuras.ImportClassPack() end or nil)
    end
  end

  return issues, okN
end

local function acked(id)
  return GrimuarSetupDB.auditAck and GrimuarSetupDB.auditAck[id]
end

local function refreshAudit(force)
  if not force and time() - cache.t < 20 then return cache end
  local ok, issues, okN = pcall(audit)
  if not ok then return cache end
  cache.t, cache.issues, cache.okN = time(), issues, okN
  local list = {}
  for _, it in ipairs(issues) do list[#list + 1] = it.id .. ": " .. it.text .. (acked(it.id) and " [zostaw]" or "") end
  GrimuarSetupDB.audit = { at = date("%Y-%m-%d %H:%M"), ok = okN, issues = list }
  return cache
end

local function open()
  local out = {}
  for _, it in ipairs(refreshAudit(false).issues) do
    if not acked(it.id) then out[#out + 1] = it end
  end
  return out
end

local function setupSteps(add)
  if needReload then
    add("setup-reload", "Ustawienia poprawione: przeładuj UI, żeby weszły.", "To samo co /reload, trwa kilka sekund.",
      { { "Przeładuj", function() pcall(ReloadUI) end } })
    return
  end
  local list = open()
  local it = list[1]
  if not it then return end
  local btns = {}
  local nFix = 0
  for _, x in ipairs(list) do if x.fix then nFix = nFix + 1 end end
  if nFix > 1 then btns[#btns + 1] = { "Ustaw wszystko (" .. nFix .. ")", function() G.fixAll() end } end
  if it.fix then
    btns[#btns + 1] = { "Napraw", function()
      if InCombatLockdown() then say("naprawię po walce.") return end
      pcall(it.fix)
      refreshAudit(true)
      if G.refreshAll then pcall(G.refreshAll) end
    end }
  else
    btns[#btns + 1] = { "Mam", function()
      GrimuarSetupDB.auditAck = GrimuarSetupDB.auditAck or {}
      GrimuarSetupDB.auditAck[it.id] = true
      if G.refreshAll then pcall(G.refreshAll) end
    end }
  end
  if it.fix then
    btns[#btns + 1] = { "Zostaw", function()
      GrimuarSetupDB.auditAck = GrimuarSetupDB.auditAck or {}
      GrimuarSetupDB.auditAck[it.id] = true
      if G.refreshAll then pcall(G.refreshAll) end
    end }
  end
  add("setup", it.text, it.why, btns, nil, (#list > 1) and ("1 z " .. #list) or nil)
end

-- „Ustaw wszystko”: kazda poprawka, ktora da sie zrobic automatycznie (bez rzeczy oznaczonych Zostaw).
local function fixAll()
  if InCombatLockdown() then say("ustawię wszystko po walce.") return end
  local n = 0
  for _, it in ipairs(open()) do
    if it.fix and pcall(it.fix) then n = n + 1 end
  end
  refreshAudit(true)
  local left = #open()
  say("ustawione: " .. n .. ((left > 0) and (". Zostało do zrobienia ręcznie: " .. left .. " (pasek Grimuara, /sprawdz).") or ".") ..
    (needReload and " Teraz przeładuj UI (przycisk na pasku albo /reload)." or ""))
  if G.refreshAll then pcall(G.refreshAll) end
end

local function report()
  local c = refreshAudit(true)
  local list = open()
  if #list == 0 then
    say("kontrola: wszystko ustawione (" .. c.okN .. " rzeczy w porządku).")
  else
    say("kontrola: " .. c.okN .. " w porządku, do poprawy " .. #list .. ":")
    for i, it in ipairs(list) do say("  " .. i .. ". " .. it.text) end
    say("pierwsza rzecz czeka na pasku Grimuara z przyciskiem Napraw albo Mam.")
  end
  local ack = {}
  for id in pairs(GrimuarSetupDB.auditAck or {}) do ack[#ack + 1] = id end
  if #ack > 0 then say("świadomie zostawione: " .. table.concat(ack, ", ") .. ". Wpisz /sprawdz od nowa, żeby znów o nie pytać.") end
end

local ev = CreateFrame("Frame")
ev:RegisterEvent("PLAYER_LOGIN")
ev:SetScript("OnEvent", function()
  -- UX 12.11: jedno podsumowanie przy logowaniu (wstega + jedna linia w czacie) zamiast serii komunikatow
  C_Timer.After(18, function()
    refreshAudit(true)
    local parts = {}
    if G.planPending and G.planPending() then parts[#parts + 1] = "plan na dziś czeka na pasku" end
    local n = #open()
    if n > 0 then
      local word = (n == 1) and "ustawienie" or ((n % 10 >= 2 and n % 10 <= 4 and (n % 100 < 12 or n % 100 > 14)) and "ustawienia" or "ustawień")
      parts[#parts + 1] = n .. " " .. word .. " do poprawy"
    end
    pcall(function() if (UnitLevel("player") or 1) >= 10 and G.talentPoints() > 0 then parts[#parts + 1] = "wolny punkt talentu" end end)
    pcall(function() local m = G.missingTraining() if #m > 0 then parts[#parts + 1] = "u trenera nowe czary: " .. #m end end)
    if #parts > 0 then
      local msg = table.concat(parts, " · ") .. ". Szczegóły: pasek Grimuara i okno (Shift+G)."
      say(msg)
      if not GrimuarSetupDB.noToast then pcall(G.showToast, msg, "plan", false) end
    end
    if G.refreshAll then pcall(G.refreshAll) end
  end)
end)

SLASH_GRIMUARSPRAWDZ1 = "/sprawdz"
SlashCmdList["GRIMUARSPRAWDZ"] = function(msg)
  if (msg or ""):lower():find("od nowa") then GrimuarSetupDB.auditAck = {} end
  report()
  if G.refreshAll then pcall(G.refreshAll) end
end

SLASH_GRIMUARUSTAW1 = "/ustaw"
SlashCmdList["GRIMUARUSTAW"] = function() fixAll() end

G.fixAll = fixAll
G.auditOpen = open
G.auditNeedsReload = function() return needReload end
G.setupSteps = setupSteps
G.audit = function() return refreshAudit(true) end

-- 15.11 (gracz: lista questow Questie przeswituje spod okna przewodnika Polestara; wybor „schowaj liste Questie”):
-- raz i od razu, bez /reload (QuestieTracker:Toggle chowa liste w biezacej sesji). Questie zostaje do znacznikow
-- na mapie i dymkow; questy sa w oknie Polestara i w Dzienniku huba (J). Wlaczenie z powrotem: opcje Questie > Tracker,
-- Grimuar drugi raz jej nie przestawia (GrimuarSetupDB.questieTrackerV).
local qtEv = CreateFrame("Frame")
qtEv:RegisterEvent("PLAYER_LOGIN")
qtEv:SetScript("OnEvent", function()
  C_Timer.After(8, function()
    if InCombatLockdown() then return end
    -- lista celow samej gry („All Objectives”, „Quests”) widoczna, gdy Questie nie ma swojej: chowa ja opcja Polestara
    -- qol.hideQuestTracker (QoL\Toggles.lua, dziala od razu przez Polestar.Set); raz, potem decyduje Kontrola
    if GrimuarSetupDB.gameTrackerV ~= 1 and Polestar and Polestar.Get and Polestar.Set then
      GrimuarSetupDB.gameTrackerV = 1
      local okG, v = pcall(Polestar.Get, "qol.hideQuestTracker")
      if okG and v ~= true and pcall(Polestar.Set, "qol.hideQuestTracker", true) then
        G.say("lista celów gry schowana (opcja Polestara): questy masz w oknie Polestara i w Dzienniku (J).")
      end
    end
    -- 15.11 (gracz: „wylacz kolka GatherMate2”): kolka GatherMate2 na minimapie wylaczone raz, od razu (jego opcja
    -- „Show Minimap Icons” + komunikat GatherMate2ConfigChanged, jak jego przycisk); zamiast nich ziola i ruda Grimuara
    -- (GrimuarUI Mapa\MinimapaZadania.lua). Mapa swiata GatherMate2 bez zmian; wlaczenie z powrotem w GatherMate2.
    if GrimuarSetupDB.gm2MinimapV ~= 1 and GatherMate2 and GatherMate2.db and GatherMate2.db.profile then
      GrimuarSetupDB.gm2MinimapV = 1
      if GatherMate2.db.profile.showMinimap ~= false then
        GatherMate2.db.profile.showMinimap = false
        pcall(GatherMate2.SendMessage, GatherMate2, "GatherMate2ConfigChanged")
        G.say("kółka GatherMate2 na minimapie wyłączone: zioła i ruda pokazuje teraz Grimuar. Mapa świata bez zmian.")
      end
    end
    if GrimuarSetupDB.questieTrackerV == 1 then return end
    pcall(function()
      if not (Questie and Questie.db and Questie.db.profile) then return end
      GrimuarSetupDB.questieTrackerV = 1
      if not Questie.db.profile.trackerEnabled then return end
      local T = QuestieLoader and QuestieLoader.ImportModule and QuestieLoader:ImportModule("QuestieTracker")
      if T and T.Toggle then T:Toggle() else Questie.db.profile.trackerEnabled = false end
      G.say("lista questów Questie schowana: questy masz w oknie Polestara i w Dzienniku (J). Znaczniki Questie zostają.")
    end)
  end)
end)
