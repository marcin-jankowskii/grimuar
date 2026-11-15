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

-- ---------- zakladki ----------
local function buildTeraz(l)
  local st = G.stageFor(l)
  G.T(C_FROST .. "Poziom " .. l .. "|r   " .. st.title, 18, 2)
  G.T(C_MUTED .. st.zones .. "|r", 13, 2)
  local okT, tl = pcall(tempoLine)
  if okT then G.T(C_FROST .. tl .. "|r", 12, 4) end

  if not GrimuarSetupDB.tutorialDone then
    G.BTNROW({ { "Samouczek dla nowego gracza", function() if G.TUT_REF.start then G.TUT_REF.start(GrimuarSetupDB.tutorialStep or 1) end end } })
  end
  local okS, steps = pcall(buildSteps)
  if not okS or type(steps) ~= "table" then steps = {} end
  G.H("Teraz zrób")
  local s1 = steps[1]
  if s1 then
    G.T(C_OK .. "» " .. s1.text .. "|r", 15, 2)
    if s1.why then G.M(s1.why) end
    local row = {}
    for _, b in ipairs(s1.btns) do table.insert(row, b) end
    if G.withGuide then pcall(G.withGuide, row, s1.text) end -- Prowadz przy kazdym kroku z questem (13.11)
    if s1.key ~= "fight" and s1.key ~= "dead" and s1.key ~= "quest" then
      table.insert(row, { "Pomiń", function() skipped[s1.key] = true; G.refreshAll() end })
    end
    G.BTNROW(row)
  end
  if S.undo then
    G.M("Ostatnio oznaczone jako zrobione: " .. S.undo[1] .. ". Pomyłka?")
    G.BTNROW({ { "Cofnij", function()
      local u = S.undo
      S.undo = nil
      if u then u[2]() end
      say("cofnięte: " .. (u and u[1] or "") .. ".")
      G.refreshAll()
    end } })
  end
  if steps[2] then
    G.H("Potem")
    for i = 2, math.min(4, #steps) do
      local s = steps[i]
      G.T("• " .. s.text)
      if #s.btns > 0 then G.BTNROW(s.btns) end
    end
  end
  G.M("Kroki odświeżają się same. Bieżący krok widać też na pasku Grimuara na górze ekranu.")

  G.H("Sesja")
  if S.budgetEnd then
    local left = math.max(0, math.floor((S.budgetEnd - time()) / 60))
    G.T("Minutnik: zostało " .. left .. " min. 10 min przed końcem przypomnę o karczmie.")
    G.BTNROW({ { "+15 min", function() setBudget(left + 15); G.refreshAll() end }, { "Wyłącz", function() setBudget(0); G.refreshAll() end } })
  else
    G.T("Ile masz dziś czasu? Włącz minutnik, a 10 min przed końcem przypomnę o karczmie.")
    G.BTNROW({ { "30 min", function() setBudget(30); G.refreshAll() end }, { "60 min", function() setBudget(60); G.refreshAll() end },
             { "90 min", function() setBudget(90); G.refreshAll() end }, { "2 h", function() setBudget(120); G.refreshAll() end } })
  end

  G.H("Na czym się skupić")
  G.B(st.focus)
  G.H("Talent")
  local pts
  pcall(function() if UnitCharacterPoints then pts = UnitCharacterPoints("player") end end)
  if type(pts) == "number" and pts > 0 then G.T(C_OK .. "Masz wolne punkty talentów: " .. pts .. " (klawisz N).|r") end
  if l < 10 then
    G.T("Pierwszy punkt na 10: Wand Specialization 1/2.")
  else
    for lv = l, math.min(60, l + 3) do
      if TALENT_AT[lv] then G.T(G.lvCol(lv, l) .. lv .. "|r   " .. TALENT_AT[lv]) end
    end
  end
  G.H("Trener maga")
  local any = false
  for _, s in ipairs(SPELLS) do
    if s[1] >= l - 1 and s[1] <= l + 4 then
      any = true
      G.T((s[1] <= l and C_OK or C_FROST) .. s[1] .. "|r   " .. s[2] .. C_MUTED .. "  " .. s[3] .. "|r")
    end
  end
  if not any then G.M("Nic nowego w najbliższych poziomach.") end
  G.M("Trener co 2 poziomy. Nowe czary addon sam kładzie na paski.")
  G.H("Dungeony")
  any = false
  for _, d in ipairs(DUNGEONS) do
    if d[1] <= l + 2 and d[2] >= l then
      any = true
      G.T(C_FROST .. d[1] .. "–" .. d[2] .. "|r   " .. d[3] .. C_MUTED .. "  " .. d[4] .. "|r")
    end
  end
  if not any then G.M("Pierwszy dungeon (Hall of Thanes) od 13 poziomu.") end
  G.H("Questy i książki")
  any = false
  for _, q in ipairs(QUESTS) do
    if q[1] >= l - 3 and q[1] <= l + 6 then
      any = true
      G.T(C_FROST .. q[1] .. "|r   " .. (G.questLabel and G.questLabel(q[2]) or q[2]) .. C_MUTED .. "  " .. q[3] .. "|r")
    end
  end
  if not any then G.M("Nic w pobliżu Twojego poziomu.") end
  G.H("Zadania etapu")
  for i, t in ipairs(st.todo) do G.CHK(st.id .. "-" .. i, t) end
end

local function buildPlan(l)
  G.M("Trasa dla Gnoma. Poziomy 31–60 nie były w becie, część zakresów jest ze starej trasy.")
  for _, st in ipairs(STAGES) do
    local here = l >= st.from and l <= st.to
    G.H((here and (C_OK .. "» ") or "") .. st.from .. "–" .. st.to .. "   " .. st.title)
    G.T(C_MUTED .. st.zones .. "|r")
    G.B(st.focus)
    local sp, dg = {}, {}
    for _, s in ipairs(SPELLS) do
      if s[1] >= st.from and s[1] <= st.to and s[3] ~= "pomiń przy levelowaniu" then table.insert(sp, s[2] .. " (" .. s[1] .. ")") end
    end
    for _, d in ipairs(DUNGEONS) do
      if d[1] >= st.from - 2 and d[1] <= st.to then table.insert(dg, d[3] .. " (" .. d[1] .. "–" .. d[2] .. ")") end
    end
    if #sp > 0 then G.T(C_FROST .. "Czary:|r " .. table.concat(sp, ", ")) end
    if #dg > 0 then G.T(C_FROST .. "Dungeony:|r " .. table.concat(dg, ", ")) end
  end
  G.H("Tempo")
  G.T("Samo questowanie do 60 to ok. 150 h. Przy 5–10 h w tygodniu daje to 15–30 tygodni. Ekipa będzie szybciej, więc nie ścigaj się. Dołączaj do niej na dungeony na Twój poziom.")
end

local function buildTalenty(l)
  G.T("Build Frost 7/0/44 (Wowhead 11.11). Punkt na poziom od 10, razem 51. Talenty otwiera klawisz N, reset u trenera w stolicy.")
  G.M("Progi w drzewku: 11, 16, 21 i 31 punktów (16 jest nowe w Forever).")
  G.H("Poziom po poziomie")
  for lv = 10, 60 do
    local note = TALENT_NOTE_AT[lv]
    G.T(G.lvCol(lv, l) .. lv .. "|r   " .. TALENT_AT[lv] .. (note and (C_MUTED .. "  " .. note .. "|r") or ""), 13, 2)
  end
  G.H("Nowe i zmienione w Forever")
  G.B({ "Ice Lance (11 pkt): +300% w zamrożony cel, 8 s odnowienia wspólnego z Fire Blast.",
      "Fingers of Frost: cel liczy się jako zamrożony przez 2 kolejne czary.",
      "Ice Block to talent (16 pkt). Cold Snap (21 pkt) ma 10 min odnowienia.",
      "Ice Barrier: +15% obrażeń Frost na minutę i +5%, dopóki tarcza trzyma.",
      "Winter's Chill działa tylko dla Ciebie: crit dla Frostbolt i Ice Lance, +20% obrażeń CoC na stack.",
      "Wand Specialization za 2 pkt. Usunięto Piercing Ice, Arcane Focus i Frost Blast." })
  G.H("Dual Spec od 40")
  G.B({ "Spec 1: Frost do levelowania i PvP (tabela wyżej).", "Spec 2: dungeony i raidy 18/0/33.", "Najlepszego speca na raidy nikt jeszcze nie zna. Zdecydujemy po pierwszych logach." })
  G.H("Raid i dungeony na 60 (18/0/33)")
  G.T(C_FROST .. "Arcane:|r Arcane Resilience 3, Arcane Meditation 3, Arcane Impact 3, Arcane Concentration 5, Arcane Subtlety 2, Wand Spec 2.")
  G.T(C_FROST .. "Frost:|r Improved Frostbolt 5, Precision 3, Ice Shards 5, Frost Channeling 3, Improved Blizzard 1, Shatter 3, Ice Lance, Cold Snap, Improved Cone of Cold 3, Fingers of Frost 2, Winter's Chill 5, Ice Barrier.")
  G.H("PvP (12/0/39)")
  G.T(C_FROST .. "Arcane:|r Arcane Resilience 3, Arcane Blast, Missile Barrage 2, Magic Absorption 2, Arcane Subtlety 2, Wand Spec 2.")
  G.T(C_FROST .. "Frost:|r jak w raidzie plus Ice Block, Frostbite 3, Permafrost 3, Improved Frost Nova 2, bez Frost Channeling.")
  G.H("Legacy (punkty na całe konto)")
  G.B({ "Pierwsze punkty od ok. 25 poziomu, potem 45 i 60, profesje 150/225/300, osiągnięcia z dungeonów.",
      "Pierwsza postać zbierze przed 60 ok. 4–8 punktów: wydaj je w Thrill of Adventure.",
      "Talented (talenty wcześniej) wymaga 10 punktów, na pierwszej postaci poza zasięgiem." })
end

local function buildCzary(l)
  G.T("Wszystko od trenera maga z poziomami z Forever (Seemeta 10.11). Nauka wszystkiego 1–60 kosztuje ok. 206 g.")
  G.H("Czary")
  for _, s in ipairs(SPELLS) do
    G.T(G.lvCol(s[1], l) .. s[1] .. "|r   " .. s[2] .. (s[3] ~= "" and (C_MUTED .. "  " .. s[3] .. "|r") or ""), 13, 2)
  end
  G.H("Ważne")
  G.B({ "Pierwszą rangę Frostbolta zostaw pod ręką: tania, do ściągania moba.",
      "Główne czary trzymaj w najnowszej randze, bo procy rzadziej odpalają ze starej.",
      "Teleporty i portale zużywają runy od sprzedawcy reagentów.",
      "Po każdym treningu nowe czary addon sam kładzie na paski." })
end

local function buildWalka()
  G.H("Jeden mob, poziomy 1–19")
  G.N({ "Frostbolt z maksymalnego zasięgu.", "Drugi Frostbolt, póki mob idzie spowolniony.", "Fire Blast na dobicie.",
      "Mob doszedł? Frost Nova (Q), odejdź kilka kroków, dokończ Frostboltem.", "Brak many? Dobij różdżką (G)." })
  G.H("Od 20: Ice Lance i zamrożenie")
  G.N({ "Frostbolt, a na zamrożony cel (Nova, Frostbite) albo przy procu Fingers of Frost Ice Lance (3).",
      "Przy procu Frostbite rzuć Frostbolt i od razu wpisz Ice Lance w kolejkę.",
      "Od 26: Cone of Cold (4) na zamrożony cel albo przy 3+ stackach Winter's Chill.",
      "Nie rozbijaj zamrożenia, zanim nie rzucisz Ice Lance." })
  G.H("AoE, kilka mobów naraz")
  G.T("Forever osłabiło AoE: Blizzard spowalnia o 40%, a nie 65%. Opłaca się przy 3–4 mobach, mniej więcej od 30 poziomu.")
  G.N({ "Ice Barrier albo Mana Shield.", "Zbierz 3–4 moby.", "Cone of Cold, potem Frost Nova.", "Blink (E) od grupy i Blizzard (6) na nią.",
      "Cone of Cold na dobicie, Arcane Explosion w ruchu. Cold Snap daje drugą Novę." })
  G.H("Mana")
  G.B({ "Woda i jedzenie zawsze z czaru, nigdy nie kupuj.", "Pij po walce, gdy i tak czekasz.", "Evocation (Shift+X) odnawia większość many w 8 s.",
      "Kamienie many od 28: tworzysz je na pasku 3, używasz w walce.", "Mage Armor (34) zostawia 50% regeneracji podczas rzucania.",
      "Zawsze zostaw manę na Novę i Blink.", "Jedzenie z buffem daje +5% XP z mobów." })
  G.H("Typowe błędy")
  G.B({ C_WARN .. "Drogi Frostbolt na moba z 5% życia zamiast Fire Blast albo różdżki.|r",
      C_WARN .. "Brak many na Novę i Blink, gdy przychodzi drugi mob.|r",
      C_WARN .. "AoE na 2 moby: pojedynczo jest szybciej.|r",
      C_WARN .. "Brak Arcane Intellect i pancerza.|r",
      C_WARN .. "Ciągnięcie walki, gdy Nova nie złapała: lepiej uciec i zacząć od nowa.|r" })
end

local function buildDungeony(l)
  G.T("5 osób: tank, healer i trzech DPS. Nie ma Dungeon Findera: grupę zbierasz na tablicy Looking For Group albo z ekipą.")
  G.H("Dungeony i poziomy")
  for _, d in ipairs(DUNGEONS) do
    local hit = d[1] <= l + 2 and d[2] >= l
    local col = hit and C_OK or (d[2] < l and C_MUTED or C_FROST)
    G.T(col .. d[1] .. "–" .. d[2] .. "|r   " .. d[3] .. C_MUTED .. "  " .. d[4] .. "|r", 13, 2)
  end
  G.H("Co robi mag w grupie")
  G.B({ "Polymorph (R) na cel z księżycem. Nie bij owcy.", "Counterspell (F) na leczących i rzucających.", "Remove Lesser Curse (=) na klątwy.",
      "Arcane Intellect na wszystkich z maną.", "Woda i jedzenie dla grupy na start.", "Portale od 40 po skończonym dungeonie." })
  G.H("Jak nie zginąć")
  G.B({ "Nie bij, zanim tank nie zbierze aggro. Policz do 2.", "Patrz na ThreatClassic2: pasek blisko tanka, przerwij na chwilę.",
      "AoE dopiero, gdy wszystkie moby biją tanka.", "Mob idzie na Ciebie? Frost Nova i podejdź do tanka.", "Ice Block (43) daje 10 s nietykalności." })
  G.H("Łupy")
  G.B({ "Need tylko na rzecz, którą założysz od razu: tkanina (cloth), laski, sztylety, miecze 1H, różdżki, off-handy.",
      "Greed na resztę, jeśli chcesz sprzedać.", "Need bez potrzeby to „ninja” i koniec zaproszeń." })
  G.H("Raidy od 09.12")
  G.B({ "Barrow Deeps: 10 osób, 8 bossów.", "Hyjal Summit: 20 osób, 13 bossów.",
      "Onyxia's Lair: 40 osób, wymaga Drakefire Amulet („Dragonkin Menace”, Burning Steppes, koniec w UBRS)." })
end

local function buildPvP()
  G.T("Serwer PvP: w strefach spornych flaga włącza się sama i każdy gracz Hordy może Cię zaatakować. Do ok. 15 poziomu jesteś praktycznie bezpieczny, od ok. 30 sporne jest prawie wszystko.")
  G.H("Przetrwanie przy levelowaniu")
  G.B({ "Najgorsze miejsca: Redridge 15–25, Duskwood, Wetlands i Ashenvale 18–30, Hillsbrad 20–35, Stranglethorn 30–45, wejście do Hall of Thanes.",
      "Tabliczki wrogów są zawsze włączone, Spy pokazuje graczy w pobliżu.",
      "Dwóch na jednego albo wyższy poziom: Frost Nova (Q), Blink (E), uciekaj.",
      "Ktoś Cię ciągle zabija: zmień strefę albo wróć Hearthstonem. Zaproszenie do grupy przenosi na inną warstwę świata.",
      "Nie walcz na granicy stref: tam łatwo przeskoczyć na inną warstwę w środku walki." })
  G.H("Plan walki Frosta")
  G.B({ "Zacznij z maksymalnego zasięgu: dwa Frostbolty (1). Przed burstem Eureka! (Shift+F).",
      "Podchodzi: Frost Nova (Q), Blink (E) albo odejdź, Frostbolt i od razu Ice Lance (3) w zamrożony cel.",
      "Dwóch wrogów: mysz na drugim i Alt+R (focus), potem R owca na niego. Zabij pierwszego. Owcę łamie każde obrażenie.",
      "Counterspell (F) na leczenie albo Fear. Z ustawionym focusem (Alt+R) przerywa focus, np. leczącego.",
      "Ice Block (Shift+E) na burst albo ogłuszenie, Cold Snap odnawia Block i Novę.",
      "Escape Artist (T) zdejmuje spowolnienie i unieruchomienie, ale nie ogłuszenie. Na ogłuszenie i root działa Blink." })
  G.H("Z kim walczyć (1v1 z bety, poziom 30)")
  G.KV({ { "Wojownik 67%", "Spowalniaj i zamrażaj, Blink po Charge, Escape Artist na Hamstring." },
       { "Łotrzyk 65%", "Ice Barrier przed walką, przetrwaj otwarcie, potem Nova, Blink, Ice Lance. Ice Block na Kidney Shot." },
       { "Paladyn 56%", "Blessing of Freedom łamie spowolnienia. Kituj, Counterspell na leczenie." },
       { "Łowca 47%", "Nova nie zatrzymuje strzałów. Za przeszkodę albo blisko niego, owca na peta." },
       { "Szaman 47%", "Counterspell na Lava Burst albo leczenie, Escape Artist na Earthbind." },
       { "Druid 43%", "Zmiana formy zdejmuje rooty. Counterspell na leczenie, nie marnuj Novy." },
       { "Kapłan 40%", "Counterspell na leczenie, trzymaj Blink na Psychic Scream." },
       { "Czarnoksiężnik 26%", "Najtrudniejszy. Counterspell na Fear albo Shadow Bolt, zdejmuj klątwy, zabij peta (demona nie owcujesz)." } })
  G.H("Battlegroundy")
  G.B({ "Warsong Gulch (od 10, 10 na 10): zanieś flagę wroga do bazy. Mag spowalnia nosiciela wroga (1, Q, 4), a swojego chroni: Q na goniących, R na healera.",
      "Arathi Basin (od 20, 15 na 15): 5 baz. Broń bazy: Q na wchodzących, F na healera, R na drugiego. Każde trafienie przerywa przejmowanie flagi.",
      "Darkspear Islands (od 30, 15 na 15, portal w Northwatch): 4 punkty i flaga w centrum. Na mostach Nova, wpadnięcie do wody zabija.",
      "Alterac Valley (51–60, 40 na 40): długa bitwa o bunkry i wieże. Blizzard (6) na zbitych w przejściach, F na healerów.",
      "Kolejka u battlemastera w Stormwind Keep. Areny w Forever nie ma." })
  G.H("Rangi PvP")
  G.B({ "Rangi tylko z battlegroundów i questów PvP, resetują się co sezon. R14 to ok. 24 750 punktów (dane z bety).",
      "Przy 5–10 h tygodniowo realny cel: R2 (trinket PvP) do R5 (mikstury bojowe).",
      "Free Action Potion (od 20): 30 s odporności na ogłuszenie i spowolnienie. Najważniejsza mikstura PvP." })
  G.H("Zasady PvP 30–60")
  G.B({ "W strefie spornej tarcza zawsze (Shift+Q od 40). Pij tylko w bezpiecznym miejscu.",
      "Novę, Blink, Ice Block i Cold Snap trzymaj na graczy. Przy Hordzie nie zaczynaj dużych pulli.",
      "Najpierw kontrola: F na leczenie albo Fear, R owca na drugiego (focus). Owcy nie bij.",
      "Bij się, gdy masz przewagę (wojownik, łotrzyk na Twoim poziomie). Czarnoksiężnika, kapłana, druida i wyższe poziomy odpuść: Q, E, za przeszkodę.",
      "Ktoś Cię ciągle zabija: nie wracaj w to samo miejsce. Hearthstone, inna strefa albo zaproszenie do grupy." })
  G.H("Mikstury i sprzęt")
  G.B({ "Free Action Potion (od 20): 30 s odporności na ogłuszenie i spowolnienie. Najważniejsza mikstura PvP.",
      "Od 55 Lieutenant Commander's Regalia za Honor: z 4 częściami Blink odnawia się 1,5 s szybciej.",
      "Do PvP część mocy czarów zamieniaj na Staminę, ale trzymaj trafienie (hit)." })
  G.H("Addony do rozważenia")
  G.B({ "Spy (wersja Forever, 11.11): ostrzega o graczach Hordy w pobliżu po tabliczkach. Instaluję tylko za Twoją zgodą.",
      "Trackerów odporności (DR) i trinketów w Forever nie ma, bo gra ukrywa przed addonami dziennik walki." })
end

local function buildSprzet()
  G.H("Statystyki przy levelowaniu")
  G.N({ "Spell Power: w Forever liczy się bardziej niż w Classicu.", "Intellect: więcej many (1 Int = 15 many).", "Stamina: życie, ważne na PvP.", "Spirit: regeneracja many poza walką." })
  G.M("Pawn pokazuje zieloną strzałkę na lepszym przedmiocie. Wizard Oil i eliksiry z mocą zaklęć to tani zysk.")
  G.H("Na 60 (wstępnie)")
  G.N({ "Hit: w Forever wspólny dla wszystkich ataków; Precision daje 2/4/6%.", "Crit.", "Spell Power.", "Intellect, potem Spirit i Stamina." })
  G.H("Raidy od 9 grudnia")
  G.KV({ { "Barrow Deeps", "10 osób, 8 bossów, w Mount Hyjal" }, { "Hyjal Summit", "20 osób, 13 bossów" },
       { "Onyxia's Lair", "40 osób; Drakefire Amulet w torbie i trochę odporności na ogień" } })
  G.M("Reset co tydzień. Set maga z raidów: Manaflare Regalia (dane sprzed premiery). Molten Core nie wchodzi na start.")
  G.H("Broń w trakcie levelowania")
  G.KV({ { "5", "Apprentice's Spellstaff (quest „Rare Books”)" }, { "9", "Deepblaze, różdżka (quest „Old Ironforge Incursion”, Hall of Thanes)" }, { "10", "Arcane Orb albo Arcane Staff (quest klasowy Gizmonitor)" }, { "21", "Mathystra Channeling Orb (quest „Baron Marinous”)" },
       { "15", "Fang of Magmatus (Hall of Thanes)" }, { "20", "Emberstone Staff (Deadmines)" }, { "25", "Rod of the Sleepwalker (Blackfathom Deeps)" },
       { "30", "różdżka z questu „Mage's Wand”" }, { "35", "Hypnotic Blade (Scarlet Monastery)" } })
  G.H("Pre-raid BiS (wstępnie)")
  G.B({ "Dreadmist Mask i Mantle (Scholomance).", "Robe i Belt of the Archmage, Netherfroth Cuffs (Tailoring).", "Devout Gloves, Magister's Leggings, Dreadmist Sandals (Stratholme).",
      "Philanthropist's Ring (20 książek), Ring of Power Regulation (Excavation Site).", "Sageblade (Blacksmithing) z Torch of Light (Enchanting).",
      "Mantle of the Timbermaw (Tailoring). Od 09.12 craftowany tier z Tailoringu 300.", "Sprawdzonej listy dla Forever jeszcze nie ma: potwierdzimy po pierwszych raidach." })
  G.M("Blizzard ukrywa przed raidami ok. 80% przedmiotów. AtlasLoot w grze pokazuje aktualne łupy.")
  G.H("Książki z bibliotek")
  G.T("Zbiera je każdy, oddajesz Garionowi Wendellowi w Mage Quarter w Stormwind (38, 81).")
  G.KV({ { "10", "naszyjnik" }, { "20", "Philanthropist's Ring (+6 Int, +10 SP), w pre-raid BiS" }, { "25", "Truthseeker's Bow, Crest of Elucidation albo Researcher's Night Light" } })
end

local function buildProfesje()
  G.T("Dwie profesje główne plus Cooking, First Aid i Fishing. Limit 300. Wyższe progi u trenera: Journeyman od 10 poziomu (skill 50), Expert od 20, Artisan od 35. Profesje otwiera klawisz K.")
  G.H("Plan")
  G.B({ "1–50: Herbalism + Mining. Zbierasz po drodze i sprzedajesz przez Auctionator.", "First Aid od razu: bandaże i mikstury leczenia.",
      "Ok. 40–50: Mining zamień na Tailoring. Daje 3 punkty Legacy (150/225/300), Robe of the Archmage i craftowany tier. Od 40 odkładaj tkaninę do banku.",
      "Enchanting zamiast Herbalism tylko wtedy, gdy Twoja gildia nie ma nikogo do rozkładania przedmiotów.",
      "Cooking na ognisko: jedzenie daje +5% XP z mobów. Obiekt Herbalism na ognisku (świeca +Int) nie łączy się z Arcane Intellect, więc magowi prawie nic nie daje.",
      "Na rajdy zbieraj: Dreamfoil, Mountain Silversage, Plaguebloom, Icecap i Black Lotus (eliksiry i flaski maga)." })
  G.H("Budżet złota")
  G.KV({ { "~206 g", "wszystkie czary 1–60 (Kup wg buildu oszczędza część)" }, { "100 g", "na 40: jazda z wierzchowcem (90 g przy Honored); Dual Spec 50 g można później" },
       { "1200 g", "na 60: Journeyman Riding (1000 g) i epicki wierzchowiec (200 g); na 60 questy nie dają złota" } })
  G.M("Cele złota na każdy poziom i tygodniowy plan: /zloto. W dymku przedmiotu Grimuar pisze, czy zatrzymać, czy sprzedać.")
  G.M("Honored z frakcją daje 10% zniżki. Od 48 questy dają dodatkowo złoto.")
  G.H("Dom aukcyjny")
  G.B({ "Zioła i rudę ze średnich poziomów sprzedawaj od razu: w pierwszym tygodniu ceny spadły o połowę i więcej.",
      "Wystawiaj pełne stacki (20). Depozyt przepada, gdy nikt nie kupi (od konserwacji 18.11 ma być symboliczny).",
      "Masowe bicie mobów i boostowanie lochów Blizzard osłabił, więc złoto robisz głównie zbieractwem i questami." })
  G.H("Uwaga")
  G.T(C_WARN .. "Nie kupuj złota. Nie ma WoW Tokena, a Blizzard blokuje za to dom aukcyjny, pocztę i handel.|r")
end

-- Kazdy addon: po co, kiedy i jak go uzywac (komendy sprawdzone w plikach addonow 11.11).
local function addonBlock(name, why, when, how)
  G.H(name)
  G.T(C_FROST .. "Po co:|r " .. why)
  if when then G.T(C_FROST .. "Kiedy:|r " .. when) end
  G.B(how)
end

local function buildAddony()
  G.T("Wszystkie addony są w wersji dla Forever. Poniżej: po co każdy jest, kiedy go użyjesz i jak. Komendy wpisujesz w czacie (Enter, komenda, Enter).")
  addonBlock("Polestar Guides",
    "przewodnik po levelowaniu: mówi, które questy brać i w jakiej kolejności, a strzałka prowadzi tam, gdzie iść.",
    "cały czas przy levelowaniu. Najważniejszy addon dla początkującego.",
    { "Pierwszy raz: wpisz /polestar guides i wybierz trasę dla Gnoma.",
      "Okno przewodnika pokazuje bieżący krok i sam go odhacza, gdy zrobisz cel.",
      "Strzałka na ekranie prowadzi prawdziwymi ścieżkami, także do lotów.",
      "Po awansie karta pokazuje, co kupić u trenera. Train All uczy wszystkiego jednym kliknięciem.",
      "Grimuar w Teraz zrób odsyła do Polestara przy questach, a sam pilnuje reszty (talenty, pancerz, woda, książki)." })
  addonBlock("Questie",
    "pokazuje, gdzie wziąć questy i gdzie je zrobić.",
    "cały czas przy levelowaniu.",
    { "Żółty ! na mapie i minimapie: quest do wzięcia. Szary !: quest za niski albo za wysoki poziom.",
      "Po wzięciu questa mapa (M) pokazuje ikony mobów i przedmiotów, które musisz zdobyć.",
      "Lista po prawej (Questie Tracker) pokazuje postęp. Klik na nazwę otwiera opis questa.",
      "Ustawienia: /questie. Styl celów zmienisz tam, jeśli ikony zasłaniają mapę." })
  addonBlock("Leatrix Plus",
    "dziesiątki drobnych wygód, które oszczędzają klikanie.",
    "działa samo w tle.",
    { "U kupca sam sprzeda szare śmieci i naprawi sprzęt (jeśli zaznaczyłeś to w /ltp).",
      "/ltp otwiera ustawienia. Po lewej kategorie, po najechaniu na opcję widzisz opis.",
      "Większość zmian wymaga przeładowania: przycisk Reload w oknie albo komenda /rl.",
      "Warto przejrzeć zakładki Interface i Chat." })
  addonBlock("Leatrix Maps",
    "odkrywa całą mapę świata i pokazuje współrzędne.",
    "gdy szukasz książek, questów albo trenera po współrzędnych (np. 38, 81).",
    { "Działa sam na mapie (M). Współrzędne kursora i Twoje są na dole mapy.",
      "Ustawienia: /ltm." })
  addonBlock("Baganator (z Syndicator)",
    "wszystkie torby w jednym oknie, posegregowane na kategorie.",
    "za każdym razem, gdy otwierasz torby (B).",
    { "B otwiera torby. Kategorie: jedzenie i picie, questy, sprzęt, surowce, śmieci.",
      "Pole wyszukiwania na górze: wpisz nazwę albo np. „junk” albo „quest”.",
      "Prawy klik na przedmiot: użyj albo załóż.",
      "Przy bankierze otwiera się też bank. Syndicator pamięta, co masz w banku i na innych postaciach.",
      "Zębatka w oknie: ustawienia (/bgr)." })
  addonBlock("Auctionator",
    "sprzedaż i kupno w domu aukcyjnym bez liczenia cen.",
    "w Ironforge u aukcjonera, gdy sprzedajesz zioła i rudę.",
    { "Porozmawiaj z aukcjonerem i wybierz zakładkę Auctionator.",
      "Raz na wizytę kliknij Full Scan: addon pobierze aktualne ceny.",
      "Zakładka Selling: kliknij przedmiot w torbie, addon podpowie cenę tuż poniżej najtańszej. Post wystawia.",
      "Zakładka Shopping: lista rzeczy do kupienia jednym kliknięciem.",
      "W opisie przedmiotu w torbie zobaczysz jego cenę na aukcji." })
  addonBlock("Pawn",
    "mówi, czy przedmiot jest lepszy od tego, który nosisz.",
    "przy nagrodach za questy i łupach.",
    { "Zielona strzałka na ikonie przedmiotu: to ulepszenie.",
      "W opisie widzisz, o ile procent jest lepszy.",
      "Przy wyborze nagrody za quest bierz tę ze strzałką.",
      "Ustawienia: /pawn." })
  -- 13.11: ForeverConsumables i FrugNearby wylaczone (decyzja gracza): wode i jedzenie daja klawisze Z, X, 0 i -, wrogow pokazuje Spy
  addonBlock("Spy",
    "ostrzega, że w pobliżu jest gracz Hordy.",
    "na serwerze PvP, zwłaszcza w strefach spornych od 20 poziomu.",
    { "Okno Spy (Nearby, pod Damage Done) pokazuje wrogów w pobliżu z poziomem i klasą, do tego krótki dźwięk.",
      "Widzi tylko graczy z tabliczkami nad głową, więc trzymaj włączone tabliczki wrogów (V).",
      "Gankera możesz dodać do listy wrogów (kill on sight) i addon ostrzeże, gdy wróci.",
      "Ustawienia: /spy." })
  addonBlock("Deadly Boss Mods (DBM)",
    "odlicza ataki bossów i ostrzega przed nimi.",
    "w dungeonach i raidach, sam się włącza przy bossie.",
    { "Paski z odliczaniem pokazują, kiedy przyjdzie atak bossa.",
      "Duży napis i głos mówią, co zrobić (np. uciec z ognia).",
      "Ustawienia: /dbm. Tam możesz przesunąć paski i zrobić test.",
      "/break 5 włącza grupie odliczanie przerwy na 5 minut." })
  addonBlock("ThreatClassic2",
    "pokazuje, jak blisko jesteś przejęcia aggro od tanka.",
    "w grupie. Grając solo możesz go ukryć.",
    { "Okno Threat: lista graczy i ich zagrożenie na Twoim celu.",
      "Tank powinien mieć najwięcej. Gdy Twój pasek zbliża się do 100%, przestań bić albo dobijaj różdżką.",
      "Ustawienia: /tc2 (rozmiar, ukrywanie solo)." })
  addonBlock("AtlasLoot",
    "co wypada z każdego bossa i co jest BiS.",
    "przed dungeonem i przy planowaniu sprzętu.",
    { "/al albo przycisk przy minimapie otwiera okno.",
      "Wybierz dungeon, potem bossa: zobaczysz łupy.",
      "AtlasBIStooltips dopisuje w opisie przedmiotu, czy to BiS dla Twojej klasy.",
      "Shift+klik na przedmiot wkleja go do czatu." })
  G.H("Wbudowane w grę")
  G.B({ "Cooldown Manager: pokazuje odnowienie Novy, Blinka i innych. Włączony przez Grimuar. Ustaw go w Edit Mode tuż nad paskami.",
      "Miernik obrażeń (Damage Done): ile zadajesz obrażeń. Ustaw zerowanie po wejściu do instancji.",
      "Edit Mode: Esc, Edit Mode, przesuń ramki, Save." })
  G.H("Grimuar")
  G.KV({ { "Shift+G", "to okno" }, { "/grimuar setup", "powtarza ustawienia" }, { "/grimuar reset", "układa główny pasek od nowa" },
       { "/grimuar ikony", "rozkłada przyciski przy minimapie" } })
  G.H("Uwaga")
  G.T(C_WARN .. "W CurseForge nie klikaj Update dla Forever. Widzi tę grę jako Retail i podmieniłby addony na niedziałające wersje. Aktualizacje zrobi Claude.|r")
end

local function buildPodstawy()
  G.H("Questy")
  G.B({ "! nad postacią: quest do wzięcia. ?: quest do oddania.", "Kolory: szary bez XP, zielony łatwy, żółty równy, pomarańczowy trudny, czerwony unikaj.",
      "Elita (złoty smok przy portrecie) to mob na grupę.", "Dziennik L, mapa M. Pełny dziennik? Porzuć szare questy." })
  G.H("Podróże")
  G.B({ "Hearthstone przenosi do karczmy, w której go przypisałeś. Odnowienie ok. godziny.", "Od 20 masz teleport do stolic, więc Hearthstone trzymaj w strefie questów.",
      "Rozmawiaj z każdym flight masterem (ikona skrzydeł).", "Z Ironforge do Stormwind jeździ pociąg Deeprun Tram." })
  G.H("Rested XP")
  G.T("Wylogowanie w karczmie, mieście albo przy ognisku nalicza odpoczynek. Potem moby dają podwójne XP. Zawsze kończ sesję w karczmie.")
  G.H("Śmierć")
  G.B({ "Jako duch biegniesz do ciała i klikasz Resurrect.", "Spirit Healer psuje sprzęt i daje Resurrection Sickness: unikaj.", "Naprawa u kupca z kowadłem (Leatrix robi to sam)." })
  G.H("Torby i miasto")
  G.B({ "4 sloty na torby (plus piąty na odczynniki): pierwsze zdobądź jak najszybciej. Nową torbę przeciągnij na pusty slot obok plecaka. Canvas Latchbag daje quest „Grund and Gozwin”, Small Brown Pouch (6 miejsc) jest u kupców z towarami.", "Bank i dom aukcyjny w Ironforge i Stormwind. Poczta w skrzynkach.",
      "Sprzedałeś coś przez pomyłkę? Kupiec ma zakładkę Buyback." })
  G.H("Trenerzy")
  G.B({ "Trener maga co 2 poziomy. W Ironforge w Mystic Ward.", "Weapon Master w Ironforge uczy sztyletów i mieczy 1H.", "Nie wiesz, gdzie ktoś stoi? Zapytaj strażnika." })
  G.H("Grupa")
  G.B({ "Zaproszenie: prawy klik na portret, Invite.", "Grać razem możesz tylko z tym samym rulesetem i frakcją.", "Okno „refresh world” przenosi Cię na ten sam layer co grupa." })
  G.H("Specjalnie w Forever")
  G.B({ "Ognisko z Cooking daje buffy po minucie siedzenia i odpoczynek.", "Legacy: punkty z wyzwań od ok. 25 poziomu.",
      "Książki z bibliotek: za 20 jest pierścień do pre-raid BiS.", "Najczęstsza śmierć w becie to upadek: Slow Fall od 12 poziomu." })
end

local function buildSlownik()
  G.T("Słowa, które usłyszysz od ekipy i na czacie.")
  G.H("Słowniczek")
  G.KV(GLOSSARY)
end

local function buildMapa()
  G.T("Kliknij Prowadź: na mapie pojawi się znacznik, a na ekranie strzałka z odległością. Współrzędne pochodzą z poradników z bety, więc mogą być przybliżone.")
  local zone = GetZoneText()
  G.H("Książki z bibliotek")
  G.M("Na zielono: książki w strefie, w której jesteś.")
  for _, g in ipairs(GUIDE) do
    if not g[6] then
      local got = bookDone(g[1])
      local col = got and C_MUTED or ((g[2] == zone) and C_OK or C_FROST)
      G.GO(col .. g[1] .. (got and " (zebrana)" or "") .. "|r" .. C_MUTED .. "  " .. g[2] .. " " .. g[3] .. ", " .. g[4] .. ", od ok. " .. g[5] .. " poz.|r", function() guideTo(g) end)
    end
  end
  G.H("Oddanie książek")
  for _, g in ipairs(GUIDE) do
    if g[6] then G.GO(C_FROST .. g[1] .. "|r" .. C_MUTED .. "  " .. g[2] .. " " .. g[3] .. ", " .. g[4] .. "|r", function() guideTo(g) end) end
  end
  G.H("Znacznik")
  G.GO("Usuń znacznik z mapy", clearGuide, "Usuń")
  G.M("Skróty: /grimuar prowadz stawia znacznik do najbliższej książki w Twojej strefie, /grimuar usun go zdejmuje.")
  G.H("Sesja i przypominajki")
  G.B({ "Pasek Grimuara na górze ekranu: XP na godzinę, czas do poziomu, rested i czas sesji. Klik otwiera to okno, przeciągnięcie przesuwa pasek.",
      "/grimuar sesja 60 włącza minutnik na 60 min. 10 min przed końcem przypomni o karczmie. /grimuar sesja 0 wyłącza.",
      "Przypomnienia w czacie (poza walką): brak pancerza lub Arcane Intellect, mało wody przy wyjściu z miasta, czary u trenera i wolny talent po wejściu do miasta, zużyty sprzęt, pełne torby.",
      "Głośne ostrzeżenie na środku ekranu: wylogowanie poza karczmą, strefa sporna PvP, koniec sesji.",
      G.personal() and "Sync z Claude: po grze napisz w czacie z Claude „sync”. Dziennik zapisuje się przy wylogowaniu albo /reload."
        or "Dziennik sesji zapisuje się przy wylogowaniu albo /reload (Kronika w hubie)." })
end

local function buildSamouczek()
  G.T("Kurs dla nowego gracza: krok po kroku, z ramką na ekranie, która pokazuje, o czym mowa. Wybierz rozdział albo zacznij od początku.")
  G.BTNROW({ { "Zacznij od początku", function() if G.TUT_REF.start then G.TUT_REF.start(1) end end },
           { "Wznów", function() if G.TUT_REF.start then G.TUT_REF.start(GrimuarSetupDB.tutorialStep or 1) end end } })
  if G.TUT_REF.chapters then
    G.H("Rozdziały")
    for i, c in ipairs(G.TUT_REF.chapters) do
      G.GO(i .. ". " .. c.name .. C_MUTED .. "  (" .. c.count .. " kroków)|r", function() if G.TUT_REF.start then G.TUT_REF.start(c.first) end end, "Zacznij")
    end
  end
  G.M("Komenda: /grimuar samouczek. W okienku kursu « i » skaczą między rozdziałami.")
end

-- eksport do pozostalych modulow
G.buildTeraz = buildTeraz
G.buildPlan = buildPlan
G.buildTalenty = buildTalenty
G.buildCzary = buildCzary
G.buildWalka = buildWalka
G.buildDungeony = buildDungeony
G.buildPvP = buildPvP
G.buildSprzet = buildSprzet
G.buildProfesje = buildProfesje
G.addonBlock = addonBlock
G.buildAddony = buildAddony
G.buildPodstawy = buildPodstawy
G.buildSlownik = buildSlownik
G.buildMapa = buildMapa
G.buildSamouczek = buildSamouczek
