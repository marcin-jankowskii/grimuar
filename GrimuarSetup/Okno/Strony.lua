-- Grimuar: modul Strony. Strony okna Grimuara dodane przy przebudowie UX (12.11, decyzja gracza „Całość”):
-- Dziś (najblizsze cele i ostatnie komunikaty), Ustawienia > Kontrola (Ustaw wszystko) i Ustawienia > Przelaczniki
-- (wszystko, co dotad bylo tylko komenda). Rysuje pomocnikami z Panel.lua (G.PT: T, H, M, B, KV, BTNROW).
local ADDON_NAME, G = ...

local C_MUTED = G.C_MUTED or "|cff9aa4b1"
local C_GOLD = G.C_GOLD or "|cffd8b25a"

local function rerender()
  C_Timer.After(0.15, function() if G.renderPanel then pcall(G.renderPanel) end end)
end

-- ---------- Dzis: najblizsze cele i ostatnie komunikaty ----------
local function pageDzisRest(P, l)
  pcall(function()
    local CL = { WARRIOR = "wojownik", ROGUE = "łotrzyk", PALADIN = "paladyn", HUNTER = "łowca", SHAMAN = "szaman",
      DRUID = "druid", PRIEST = "kapłan", WARLOCK = "czarnoksiężnik", MAGE = "mag" }
    local n, top, topN = G.deathSummary()
    if n > 0 or (top and topN >= 2) then
      P.H("Zgony")
      local lines = { "dziś: " .. n }
      if top and topN >= 2 then lines[#lines + 1] = "najczęściej ginąłeś od: " .. (CL[top] or top) .. " (" .. topN .. " razy w ostatnich sesjach)" end
      if G.lastDeathTip then lines[#lines + 1] = "ostatnia rada: " .. G.lastDeathTip end
      P.B(lines)
    end
  end)
  local rec = G.recent or {}
  if #rec > 0 then
    P.H("Ostatnie komunikaty")
    for i = 1, math.min(5, #rec) do
      local r = rec[i]
      P.T(C_MUTED .. r[1] .. "|r  " .. C_GOLD .. r[2] .. ":|r " .. r[3], 12, 2)
    end
  end
end

local function pageDzisVisual(P, l)
  local xp, mx = UnitXP("player") or 0, UnitXPMax("player") or 0
  if l < 60 and mx > 0 then
    local rest = (GetXPExhaustion and GetXPExhaustion()) or 0
    local mins = G.minutesToLevel and G.minutesToLevel()
    P.H("Postęp")
    P.BAR("Poziom " .. l .. (mins and (" · do " .. (l + 1) .. " za ok. " .. math.floor(mins + 0.5) .. " min") or "") ..
      ((rest > 0) and "  ·  złota kreska: zapas odpoczynku" or ""), math.floor(xp / mx * 100) .. "%", xp, mx, { 0.54, 0.31, 0.82 }, math.min(mx, xp + rest))
  end
  local tiles = {}
  if l < 60 then tiles[#tiles + 1] = { tostring((l % 2 == 0) and (l + 2) or (l + 1)), "trener: nowe czary" } end
  local pts = 0
  pcall(function() pts = G.talentPoints() end)
  if l < 10 then tiles[#tiles + 1] = { "10", "pierwszy talent: Precision" }
  elseif pts > 0 then tiles[#tiles + 1] = { tostring(pts), "wolne punkty talentów (N)" } end
  pcall(function()
    local t = G.goldTarget and G.goldTarget()
    if t then tiles[#tiles + 1] = { (string.format("%.1f g", G.goldNow()):gsub("%.", ",")), "z " .. t[3] .. " g na " .. t[1] .. " poziom" } end
  end)
  P.TILES(tiles)
  local items, idx, mins = nil, nil, nil
  if G.planView then items, idx, mins = G.planView() end
  if items then
    P.H("Plan na dziś · " .. ((mins and mins >= 60) and ((mins / 60) .. " h") or ((mins or 0) .. " min")))
    for i, it in ipairs(items) do
      P.PLAN(it.text, it.done and "done" or ((i == idx) and "now" or nil), (it.mins or 0) .. " min")
    end
  end
end

local function pageDzisExtra(P, l)
  if P.BAR and P.TILES and P.PLAN then
    pcall(pageDzisVisual, P, l)
    return pageDzisRest(P, l)
  end
  P.H("Najbliższe cele")
  local items = {}
  if l < 60 then
    local nextTrainer = (l % 2 == 0) and (l + 2) or (l + 1)
    items[#items + 1] = "trener maga: nowe czary na " .. nextTrainer .. " poziomie"
  end
  if l < 10 then
    items[#items + 1] = "pierwszy talent na 10 poziomie: Precision"
  else
    pcall(function() if G.talentPoints() > 0 then items[#items + 1] = "masz wolny punkt talentu (N)" end end)
  end
  pcall(function()
    local t = G.goldTarget and G.goldTarget()
    if t then
      local g = G.goldNow and G.goldNow() or 0
      items[#items + 1] = string.format((G.tr and G.tr("złoto: masz %.1f g, cel na %d poziom: %d g (%s)")) or "złoto: masz %.1f g, cel na %d poziom: %d g (%s)", g, t[1], t[3], t[4]):gsub("%.(%d) g", ",%1 g")
    end
  end)
  pcall(function()
    local dg = (l >= 11) and G.bestDungeon and G.bestDungeon(math.max(13, l))
    if dg then items[#items + 1] = "loch: " .. dg[3] .. " od " .. dg[1] .. " poziomu" end
  end)
  P.B(items)
  return pageDzisRest(P, l)
end

-- ---------- Ustawienia > Kontrola ----------
local function pageKontrola(P)
  local c = G.audit and G.audit() or { okN = 0 }
  local list = G.auditOpen and G.auditOpen() or {}
  P.T("W porządku: " .. (c.okN or 0) .. ".  Do poprawy: " .. #list .. ".", 14, 4)
  local nFix = 0
  for _, it in ipairs(list) do if it.fix then nFix = nFix + 1 end end
  local row = {}
  if nFix > 0 then row[#row + 1] = { "Ustaw wszystko (" .. nFix .. ")", function() if G.fixAll then G.fixAll() end rerender() end } end
  row[#row + 1] = { "Sprawdź od nowa", function() if G.audit then G.audit() end rerender() end }
  if G.auditNeedsReload and G.auditNeedsReload() then row[#row + 1] = { "Przeładuj", function() pcall(ReloadUI) end } end
  P.BTNROW(row)
  for i, it in ipairs(list) do
    P.T(i .. ". " .. it.text, 13, 1)
    if it.why then P.M(it.why) end
  end
  local ack = {}
  for id in pairs(GrimuarSetupDB.auditAck or {}) do ack[#ack + 1] = id end
  if #ack > 0 then
    P.H("Świadomie zostawione")
    P.M(table.concat(ack, ", "))
    P.BTNROW({ { "Pytaj znowu o wszystko", function() GrimuarSetupDB.auditAck = {} if G.audit then G.audit() end rerender() end } })
  end
  P.M("Kontrola sprawdza addony, opcje w addonach, ustawienia gry, klawisze, makra, paski i układ ekranu. Działa sama przy każdym wejściu do gry.")
end

-- ---------- Ustawienia > Przelaczniki ----------
local function slash(name, arg) return function() if SlashCmdList[name] then SlashCmdList[name](arg or "") end end end
local function flip(key) return function() GrimuarSetupDB[key] = not GrimuarSetupDB[key] end end

local TOGGLES = {
  { "Styl Pustynia i Runy", function() return GrimuarSetupDB.runy end, slash("GRIMUARRUNY") },
  { "Układ ekranu Runy (paski, ramki, czat)", function() return GrimuarSetupDB.ekranRuny end,
    function() if GrimuarSetupDB.ekranRuny then G.ekranRevert() else G.ekranApply() end end },
  { "Ściąga combo (styl Runy)", function() return not GrimuarSetupDB.runyComboOff end, slash("GRIMUARRUNY", "combo") },
  { "Wstęgi zamiast okienka", function() return not GrimuarSetupDB.noBanner end, slash("GRIMUARWSTEGI") },
  { "Komunikaty Grimuara", function() return not GrimuarSetupDB.noToast end, slash("GRIMUAR", "komunikaty") },
  { "Pasek Grimuara pod Polestarem", function() return not GrimuarSetupDB.noDock end, slash("GRIMUAR", "dock") },
  { "Pytanie o plan przy wejściu", function() return not GrimuarSetupDB.noPlanAsk end, flip("noPlanAsk") },
  { "Większa ramka focusa", function() return not GrimuarSetupDB.focusSmall end, slash("GRIMUARFOCUSRAMKA") },
  { "Czary AoE u trenera (Kup wg buildu)", function() return GrimuarSetupDB.trainAoE end, slash("GRIMUAR", "aoe") },
  { "Globy (stary prototyp)", function() return GrimuarSetupDB.orbs end, slash("GRIMUARGLOBY") },
  { "Skórki Blizzarda: dymki i okna (po przeładowaniu)", function() return not GrimuarSetupDB.noSkins end, flip("noSkins") },
  { "Czcionki motywu w całej grze (po przeładowaniu)", function() return not GrimuarSetupDB.noGameFonts end, flip("noGameFonts") },
  { "Przyciski Grimuara w menu Esc", function() return not GrimuarSetupDB.noEscMenu end, flip("noEscMenu") },
  { "Menu Esc Grimuara na cały ekran (inaczej menu Blizzarda)", function() return not GrimuarSetupDB.escClassic end, flip("escClassic") },
  -- kompas z GrimuarUI (Kompas.lua, zapis w GrimuarUIDB): przelacza przez G.kompasCmd
  { "Kompas u góry ekranu (hub; /hub kompas walka chowa go w walce)", function() return not (GrimuarUIDB and GrimuarUIDB.kompas == false) end,
    function() if G.kompasCmd then G.kompasCmd() end end },
  { "Cel u góry ekranu przy wrogim celu i w walce (hub)", function() return not (GrimuarUIDB and GrimuarUIDB.hudCel == false) end,
    function() if G.hudCmd then G.hudCmd("cel") end end },
  { "Minimapa tylko w walce, w lochu, pod myszką i z Altem (hub)", function() return GrimuarUIDB and GrimuarUIDB.minimapTryb == true end,
    function() if G.hudCmd then G.hudCmd("minimapa") end end },
  { "Duża nazwa miejsca po wejściu do strefy (hub)", function() return not (GrimuarUIDB and GrimuarUIDB.noStrefa) end,
    function() if G.hudEkranCmd then G.hudEkranCmd("strefa") end end },
  { "Komunikaty po lewej (inaczej wstęga u góry)", function() return not (GrimuarUIDB and GrimuarUIDB.toastsTop) end,
    function() if G.hudEkranCmd then G.hudEkranCmd("komunikaty") end end },
  { "Życie i mana jako paski nad paskami akcji (inaczej łuki)", function() return GrimuarUIDB and GrimuarUIDB.paskiTryb == true end,
    function() if G.paskiCmd then G.paskiCmd() end end },
  { "Paski akcji 1 i 2 przygaszone poza walką", function() return not (GrimuarUIDB and GrimuarUIDB.paskiAkcjiTryb == false) end,
    function() if G.paskiCmd then G.paskiCmd("akcji") end end },
  { "Pas podręczny nad paskami akcji (picie, jedzenie, bandaż, mikstura, dom)", function() return not (GrimuarUIDB and GrimuarUIDB.pasTryb == false) end,
    function() if G.pasCmd then G.pasCmd() end end },
  { "Rozmowy z NPC i questy w oknie Grimuara (inaczej okno gry)", function() return not (GrimuarUIDB and GrimuarUIDB.rozmowaTryb == false) end,
    function() if G.rozmowaCmd then G.rozmowaCmd() end end },
  { "Torby otwierają też okno postaci", function() return not GrimuarSetupDB.noBagsWithChar end, flip("noBagsWithChar") },
  { "Pomoc w grupie: klątwy, Intellect, kanał grup, gildia", function() return not GrimuarSetupDB.noGroupHelp end, flip("noGroupHelp") },
  { "Spokojny ekran (bez poświaty i szarości po śmierci)", function() return GrimuarSetupDB.calmScreen end, function() G.calmToggle() end },
  { "Barwy Runy w addonach (ustaw jeszcze raz)", function() return (GrimuarSetupDB.barwyV or 0) >= (G.BARWY_VER or 1) end, function() G.barwyApply() end },
}
G.TOGGLES = TOGGLES -- 15.11: tez strona Grimuar w Ustawieniach huba (GrimuarUI Ustawienia\TabUstawienia.lua)

local function pageToggles(P)
  P.M("Kliknij, żeby włączyć albo wyłączyć. Zmiana działa od razu.")
  for _, t in ipairs(TOGGLES) do
    local on = false
    pcall(function() on = t[2]() and true or false end)
    P.BTNROW({ { t[1] .. ":  " .. (on and "|cff7cc68bwł.|r" or "|cff9aa4b1wył.|r"), function()
      if InCombatLockdown() then if G.say then G.say("przełączę po walce.") end return end
      pcall(t[3])
      rerender()
      if G.refreshAll then pcall(G.refreshAll) end
    end } })
  end
  if G.soundPage then pcall(G.soundPage, P, rerender) end
  -- 14.11 (R27 E5): kopia zapasowa to ustawienie prywatne (Grimuar_Osobiste)
  if G.personal and G.personal() then
    P.H("Kopia zapasowa")
    P.M("Windows sam kopiuje ustawienia gry (folder WTF), Grimuara, listę addonów i zrzuty ekranu, tylko gdy coś się zmieniło. " ..
      "Zostaje 14 ostatnich i po jednej z 12 tygodni w gaming-warsztat" .. "\\" .. "wow" .. "\\" .. "kopie (bez gry w tle; co godzinę sprawdza zmiany). Przywracanie przy zamkniętej grze: przywroc_wtf.ps1.")
    P.M("Klawisze, makra i ustawienia gry Blizzard trzyma też na serwerze. Ustawień addonów i kodu Grimuara nie: one są tylko w kopii. Zmieniasz coś w addonach? Przeładuj UI przed wyjściem z gry.")
  end
  P.H("Skróty w czacie")
  P.M("/gr otwiera to okno, /gr pomoc wypisuje wszystkie komendy. /plan, /koniec, /loch i /zloto działają jak przyciski w oknie.")
end

-- ---------- Postac > Do 60 i raidy (R12, 13.11) ----------
local function pageDo60(P, l)
  P.M("Wiedza z researchu R12 (13.11.2026). Raidy ruszają 09.12.2026. Na 60 będziesz pewnie wiosną 2027, więc przed etapem 60 dane odświeży cotygodniowy przegląd.")
  P.H("Legacy: punkty, które realnie zdobędziesz (8–10 do raidu)")
  P.KV({ { "Mage 25/45/60", "3 pkt, wpadną same za poziomy" }, { "Tailoring 150/225/300", "3 pkt, profesja w planie" },
    { "Spelunker (Novice, Experienced, Master)", "po 1 pkt za komplety lochów; lochy na terenie Hordy tylko z grupą" },
    { "Honor Rank 3", "1 pkt, ok. 2700 punktów z battlegroundów" }, { "Field of Honor 4/7/10 tygodni", "1–3 pkt, jeśli i tak grasz battlegroundy" },
    { "Conqueror: Barrow Deeps, Hyjal, Onyxia", "po 1 pkt za pełny raid" } })
  P.M("Na 60 przebuduj Legacy pod raid: Reagent Economy, The Quick and the Dead, Gourmand, Reinforce. Talented wymaga 5 pkt w Well Rested.")
  P.H("Reputacje")
  P.KV({ { "Gnomeregan", "Honored: –10% na jazdę (90 g na 40, 900 g na 60)" },
    { "Azeroth Commerce Authority", "Friendly: Netherfroth Cuffs i Shoulders, torby na reagenty. Skrzynki z ziół i rud, writy w Three Corners" },
    { "Timbermaw Hold", "Mantle of the Timbermaw. Questy, pióra i paciorki; nie bij Timbermaw" },
    { "Guardians of Hyjal", "od 60 najważniejsza: wzór Manaflare Pants, Rousing Seed Pod (craftowany tier)" },
    { "Argent Dawn", "klucz do Scholomance (dane z klasycznego WoW)" } })
  P.H("Tailoring krok po kroku")
  P.B({ "1–150: z odłożonych Linen i Wool w Ironforge. Na 125 Expert u Georgio Bolero (Stormwind).",
    "150–200: Silk i Mageweave z questów 35–45. Na 200 (i poziom 35) Artisan u Timothy Worthingtona w Theramore. Dustwallow to ganki, załatw to szybko.",
    "195–205: ACA Friendly, Netherfroth Shoulders i Cuffs. 205–265: Runecloth (od 50), Runecloth Belt i Gloves.",
    "265–300: wzory z łupów i Mooncloth (Winterspring). 295: Robe of the Archmage (wzór z LBRS). Na 300: krosno przy ognisku i craftowany tier po raidach." })
  P.H("Przed każdym raidem")
  P.B({ "Naprawa 100% i zapas złota na naprawy. Na Onyxię Drakefire Amulet w torbie i odporność na ogień.",
    "Eliksiry: Greater Arcane Elixir i Mageblood albo flask. Jedzenie +SP, Brilliant Wizard Oil, 5 Major Mana Potion.",
    "Arcane Powder do Arcane Brilliance (chyba że masz Reagent Economy). Kamienie many przed pullem, drugi spec aktywny.",
    "DBM zaktualizowany i /combatlog włączony (logi na foreverlogs.gg)." })
  P.M("Gdy dołączysz do grupy rajdowej, pasek Grimuara sam pokaże, czego brakuje.")
end

G.pageDo60 = pageDo60
G.pageDzisExtra = pageDzisExtra
G.pageKontrola = pageKontrola
G.pageToggles = pageToggles
