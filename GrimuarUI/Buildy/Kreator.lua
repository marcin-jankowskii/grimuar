-- Grimuar UI: kreator przy pierwszym uruchomieniu (R27 4a, E3; 14.11). Zamiast zmieniania ustawien bez pytania
-- (GrimuarSetup fullSetup): jezyk huba, wykryta postac i brakujace addony, wybor buildu (wbudowany, szkic Polestara,
-- albo pozniej import w hubie), zgody osobno: ustawienia gry, makra, klawisze, pasek 2. Domyslnie nic nie zaznaczone.
-- Zmiany tylko po „Zastosuj”, nigdy w walce. /gr kreator (GrimuarSetup) albo /hub kreator uruchamia ponownie.
local ADDON, U = ...
local C = U.C
local G = U.G or {}

local W
local CLASS_PL = { WARRIOR = "wojownik", PALADIN = "paladyn", HUNTER = "łowca", ROGUE = "łotrzyk", PRIEST = "kapłan",
  SHAMAN = "szaman", MAGE = "mag", WARLOCK = "czarnoksiężnik", DRUID = "druid" }
local CONSENTS = {
  { "cvars", "Ustawienia gry (kamera, łupy, czytelność walki)", function() return G.applyCVars and G.applyCVars() end },
  { "macros", "Makra z buildu (np. owca na focus, przerwanie)", function() return G.ensureMacros and G.ensureMacros() end },
  { "binds", "Klawisze z buildu (wokół WSAD; A i D jako krok w bok)", function() return G.applyBinds and G.applyBinds() end },
  { "bar2", "Włącz pasek akcji 2 (klawisze Q, E, R, F…)", function() return G.showBar2 and G.showBar2() end },
  { "bars", "Czary z buildu na paskach (po treningu same dochodzą)", function()
      GrimuarSetupDB.barsConsent = true
      if G.layoutBars then return G.layoutBars(false) end
    end },
}

local function missing()
  local out = {}
  for _, a in ipairs({ { "Polestar", "przewodniki i talenty" }, { "Questie", "zadania na mapie" }, { "Pawn", "ocena sprzętu" }, { "Baganator", "torby" } }) do
    local loaded = (C_AddOns and C_AddOns.IsAddOnLoaded and C_AddOns.IsAddOnLoaded(a[1])) or (IsAddOnLoaded and IsAddOnLoaded(a[1]))
    if not loaded then out[#out + 1] = a[1] .. " (" .. a[2] .. ")" end
  end
  return out
end

local function build()
  W = U.Panel(UIParent, 0.97, true, C.gold)
  W:SetFrameStrata("DIALOG")
  W:SetSize(620, 520)
  W:SetPoint("CENTER", UIParent, "CENTER", 0, 40)
  W:EnableMouse(true)
  W:Hide()
  W.h = U.H2(W, "Witaj w Grimuarze")
  W.h:SetPoint("TOPLEFT", 22, -18)
  W.who = U.Para(W, 14, 576, C.text)
  W.who:SetPoint("TOPLEFT", W.h, "BOTTOMLEFT", 0, -10)
  -- jezyk
  local ll = U.Label(W, "Język huba")
  ll:SetPoint("TOPLEFT", W.who, "BOTTOMLEFT", 0, -16)
  W.pl = U.Button(W, "Polski", 100, 26)
  W.pl:SetPoint("TOPLEFT", ll, "BOTTOMLEFT", 0, -6)
  W.en = U.Button(W, "English", 100, 26)
  W.en:SetPoint("LEFT", W.pl, "RIGHT", 8, 0)
  local function lang(l) GrimuarSetupDB.lang = l U.Color(W.pl.label, l == "pl" and C.gold or C.muted) U.Color(W.en.label, l == "en" and C.gold or C.muted) end
  W.pl:SetScript("OnClick", function() lang("pl") end)
  W.en:SetScript("OnClick", function() lang("en") end)
  W.lang = lang
  -- build
  local bl = U.Label(W, "Build (możesz zmienić później: hub > Buildy)")
  bl:SetPoint("TOPLEFT", W.pl, "BOTTOMLEFT", 0, -18)
  W.build = U.Button(W, "", 470, 28)
  W.build:SetPoint("TOPLEFT", bl, "BOTTOMLEFT", 0, -6)
  W.next = U.Button(W, "Następny", 90, 28)
  W.next:SetPoint("LEFT", W.build, "RIGHT", 8, 0)
  W.next:SetScript("OnClick", function()
    W.i = (W.i % math.max(1, #W.list)) + 1
    local b = W.list[W.i]
    W.build:SetLabel(b and b.name or "brak buildu dla tej klasy")
  end)
  -- zgody
  local zl = U.Label(W, "Co Grimuar może zmienić w grze (nic nie jest zaznaczone)")
  zl:SetPoint("TOPLEFT", W.build, "BOTTOMLEFT", 0, -18)
  W.checks = {}
  local prev = zl
  for i, c in ipairs(CONSENTS) do
    local b = U.Button(W, "", 576, 26)
    b:SetPoint("TOPLEFT", prev, "BOTTOMLEFT", 0, i == 1 and -6 or -4)
    b.key, b.on = c[1], false
    local function paint() b:SetLabel((b.on and "■  " or "□  ") .. c[2]) U.Color(b.label, b.on and C.gold or C.text) end
    b:SetScript("OnClick", function() b.on = not b.on paint() end)
    b.paint = paint
    paint()
    W.checks[i] = b
    prev = b
  end
  W.note = U.Para(W, 12, 576, C.faint)
  W.note:SetPoint("TOPLEFT", prev, "BOTTOMLEFT", 0, -12)
  W.note:SetText("Zmiany robię tylko poza walką i tylko te, które zaznaczysz. Ustawienia i makra możesz później włączyć w oknie Grimuara (Ustawienia > Kontrola).")
  local go = U.Button(W, "Zastosuj", 160, 32, true)
  go:SetPoint("BOTTOMLEFT", 22, 18)
  go:SetScript("OnClick", function()
    if InCombatLockdown() then U.say("kreator dokończę po walce.") return end
    local b = W.list[W.i]
    if b and G.SetActiveBuild then G.SetActiveBuild(b.id, true) end
    local done = {}
    for i, ch in ipairs(W.checks) do
      if ch.on then
        local ok = pcall(CONSENTS[i][3])
        done[#done + 1] = CONSENTS[i][2]:match("^[^(]+"):gsub("%s+$", "") .. (ok and "" or " (błąd)")
      end
    end
    GrimuarSetupDB.account = true
    GrimuarSetupDB.wizardDone = time()
    W:Hide()
    U.say("gotowe. Build: " .. (b and b.name or "brak") .. (#done > 0 and (". Zmienione: " .. table.concat(done, ", ")) or ". Ustawień gry nie zmieniałem") .. ". Hub: klawisz ` albo /hub.")
  end)
  local skip = U.Button(W, "Pomiń (nic nie zmieniaj)", nil, 32)
  skip:SetPoint("LEFT", go, "RIGHT", 10, 0)
  skip:SetScript("OnClick", function()
    GrimuarSetupDB.account = true
    GrimuarSetupDB.wizardDone = time()
    W:Hide()
    U.say("kreator pominięty. Wrócisz do niego: /gr kreator.")
  end)
end

function U.wizard()
  if InCombatLockdown() then U.say("kreator otworzę po walce.") return end
  if not W then build() end
  local _, cls = UnitClass("player")
  local race = UnitRace("player") or ""
  local faction = UnitFactionGroup("player") or ""
  local miss = missing()
  W.who:SetText((UnitName("player") or "") .. ": " .. race .. ", " .. (CLASS_PL[cls or ""] or cls or "?") .. ", poziom " .. (UnitLevel("player") or 1) ..
    " (" .. (faction == "Alliance" and "Przymierze" or (faction == "Horde" and "Horda" or faction)) .. ")" ..
    (#miss > 0 and ("\nBrakuje (zalecane): " .. table.concat(miss, ", ")) or "\nWszystkie zalecane addony są włączone."))
  W.list = G.BuildList and G.BuildList(cls) or {}
  W.i = 1
  local def = G.DefaultBuildId and G.DefaultBuildId(cls)
  for i, b in ipairs(W.list) do if b.id == def then W.i = i end end
  local b = W.list[W.i]
  W.build:SetLabel(b and b.name or "brak buildu dla tej klasy")
  W.lang(GrimuarSetupDB.lang or "pl")
  W:Show()
end
if U.G then U.G.showWizard = U.wizard end
