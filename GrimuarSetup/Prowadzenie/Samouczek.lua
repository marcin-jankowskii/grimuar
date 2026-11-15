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
local createPanel = G.createPanel
local selectTab = G.selectTab

-- ---------- samouczek krok po kroku (kurs dla nowego gracza) ----------
local function ensurePanel(tab)
  if not G.getPanel() then createPanel() end
  if not G.getPanel():IsShown() then G.getPanel():Show() end
  if tab then selectTab(tab) end
end

local function typeCommand(cmd)
  pcall(function() ChatFrame_OpenChat(cmd .. " ") end)
end

local function openSpellbook()
  local ok = pcall(function()
    if ToggleSpellBook then ToggleSpellBook(BOOKTYPE_SPELL or "spell") return end
    if PlayerSpellsUtil and PlayerSpellsUtil.ToggleSpellBookFrame then PlayerSpellsUtil.ToggleSpellBookFrame() return end
    error("brak")
  end)
  if not ok then say("wciśnij P, żeby otworzyć księgę czarów.") end
end


-- { rozdzial, tytul, tekst, ramki do podswietlenia (pierwsza widoczna), { przycisk, funkcja } }
local TUTORIAL = {
  -- 1. Start i ekran
  { "Start i ekran", "Witaj w kursie", "Przeprowadzę Cię przez całą grę jak nowego gracza: ekran, questy, walkę, miasto, rozwój postaci, grupę i wszystkie addony. Dalej i Wstecz przechodzą między krokami, strzałki « » skaczą między rozdziałami. Ramka na ekranie pokazuje, o czym mowa. Spis rozdziałów jest w oknie Grimuara (Shift+G), zakładka Samouczek." },
  { "Start i ekran", "Ruch i kamera", "W i S idą do przodu i do tyłu, A i D robią krok w bok. Skręcasz, trzymając prawy przycisk myszy i ruszając nią. Spacja to skok, kółko myszy przybliża i oddala kamerę. Num Lock włącza automatyczny bieg." },
  { "Start i ekran", "Twoja postać i cel", "Twoja ramka: zielony pasek to życie, niebieski to mana. Gdy zaznaczysz moba albo NPC (lewy klik albo Tab), pojawi się jego ramka. Kolor imienia: czerwony to wróg, żółty to neutralny (sam nie atakuje), zielony to przyjazny.", { "PlayerFrame" } },
  { "Start i ekran", "Pasek doświadczenia", "Pasek na dole ekranu to doświadczenie (XP). Niebieska część to rested, czyli bonus za odpoczynek w karczmie: moby dają wtedy podwójne XP. Pełny pasek to nowy poziom.", { "MainStatusTrackingBarContainer", "StatusTrackingBarManager", "MainMenuExpBar" } },
  { "Start i ekran", "Minimapa", "Minimapa pokazuje okolicę z góry, strzałka to Ty. Żółty ! to quest do wzięcia, żółty ? to quest do oddania. Kółko myszy i przyciski + i - przybliżają. Nad minimapą jest nazwa strefy. Shift + przeciągnij przesuwa minimapę.", { "Minimap" } },
  { "Start i ekran", "Czat", "Enter otwiera czat. Zwykły tekst słyszą gracze obok. /p pisze do grupy, /g do gildii, a /w Nick wiadomość to szept do jednej osoby. Komendy addonów też wpisujesz tutaj, np. /grimuar.", { "ChatFrame1" } },
  { "Start i ekran", "Najważniejsze klawisze", "C: postać i sprzęt. B: torby. P: księga czarów. N: talenty. L: dziennik questów. M: mapa. K: profesje. O: znajomi i gildia. Esc: menu gry, opcje i Edit Mode." },

  { "Start i ekran", "Główny pasek: klawisze 1 do =", "1 Frostbolt (do 4 poziomu Fireball), 2 Fire Blast, 3 Ice Lance, 4 Cone of Cold, 5 Arcane Explosion, 6 Blizzard, 7 Mage Armor, 8 Frost Armor, 9 Arcane Intellect, 0 tworzenie wody, - tworzenie chleba, = zdejmowanie klątw. Puste sloty wypełnią się same, gdy kupisz czar u trenera.", { "MainActionBar", "MainMenuBar", "ActionButton1" } },
  { "Start i ekran", "Pasek 2: klawisze wokół WSAD", "Q Frost Nova, E Blink, R owca (Polymorph: najpierw focus, potem mob pod kursorem, potem cel), Alt+R focus (mysz na drugim mobie), F przerwanie czaru wroga, G różdżka, T Escape Artist, Z picie i X jedzenie (Grimuar kładzie tam najlepszą wodę i najlepsze jedzenie z torby), Shift+Q Ice Barrier, Shift+E Ice Block, Shift+R Mana Shield (od 39 Cold Snap), Shift+X Evocation (od 20), Shift+F Eureka! (rasowa gnoma: przez 8 s czary bez efektu okresowego kosztują 10% mniej many i biją 10% mocniej, co 2 min; włącz na początek trudnej walki). Pasek 3 nad nimi: czary pomocnicze klikane myszą (Slow Fall, teleporty, osłony, portale).", { "MultiBarBottomLeft" } },

  -- 2. Questy
  { "Questy", "Jak wziąć quest", "Podejdź do NPC z żółtym ! nad głową i kliknij go prawym przyciskiem. Przeczytaj, co trzeba zrobić, i kliknij Accept. Szare ! to quest za niski albo za wysoki poziom." },
  { "Questy", "Cele questa", "Lista questów z postępem jest po prawej stronie, np. 3/8 Tough Wolf Meat. Na mapie (M) Questie pokazuje, gdzie są potrzebne moby i przedmioty. Przedmioty z mobów zbierasz z ich ciał.", { "Questie_BaseFrame", "ObjectiveTrackerFrame", "QuestWatchFrame" }, { "Otwórz mapę", function() pcall(ToggleWorldMap) end } },
  { "Questy", "Oddanie i nagroda", "Gdy cel jest zrobiony, nad NPC pojawi się żółty ?. Prawy klik i Complete Quest. Jeśli możesz wybrać nagrodę, bierz tę z zieloną strzałką Pawn: to ulepszenie dla Ciebie." },
  { "Questy", "Polestar prowadzi", "Okno Polestar pokazuje bieżący krok: weź quest, zabij, zbierz, oddaj, leć. Strzałka na ekranie prowadzi do celu prawdziwymi ścieżkami, a kroki odhaczają się same. Za pierwszym razem wybierz trasę dla Gnoma.", { "PolestarGuideFrame" }, { "Wybierz trasę", function() pcall(function() SlashCmdList["POLESTAR"]("guides") end) end } },
  { "Questy", "Dziennik questów", "L otwiera dziennik. Jest tam opis każdego questa i nagrody. Quest za trudny albo masz pełny dziennik? Zaznacz go i kliknij Abandon. Questy oznaczone Group rób z ekipą.", nil, { "Otwórz dziennik", function() pcall(ToggleQuestLog) end } },
  { "Questy", "Jak oszczędzać czas", "Bierz wszystkie questy w osadzie naraz, rób je w jednej pętli i oddawaj hurtem. Polestar układa to za Ciebie. Kończ sesję w karczmie, żeby jutro dostać rested XP." },

  -- 3. Walka i mana
  { "Walka i mana", "Jak zacząć walkę", "Zaznacz moba lewym klikiem albo Tab. Stój w miejscu i rzucaj czary z dystansu, bo ruch przerywa rzucanie. Do 3 poziomu masz Fireball (klawisz 1), od 4 Frostbolt (też 1).", { "MainActionBar", "MainMenuBar", "ActionButton1" } },
  { "Walka i mana", "Prosta rotacja maga", "Frostbolt (1) zadaje obrażenia i spowalnia moba. Gdy podejdzie blisko, Frost Nova (Q, od 10) go zamrozi, a Ty odejdź kilka kroków i rzucaj dalej. Dobijaj Fire Blastem (2) albo różdżką (G), żeby oszczędzać manę.", { "MultiBarBottomLeft" } },
  { "Walka i mana", "Łup", "Prawy klik na ciało moba otwiera łup, a Auto Loot zabiera wszystko sam. Błyszczące ciało ma coś do zabrania. Szare przedmioty to śmieci, które Leatrix sprzeda u kupca." },
  { "Walka i mana", "Kiedy pić i jeść", "Patrz na swoją ramkę: zielony pasek to życie, niebieski to mana. Mana poniżej około 40%: pij. Życie poniżej 50%: jedz. Rób to po walce, zanim zaczniesz następną, bo w walce nie da się pić. Grimuar po każdej walce sam sprawdzi paski i pokaże komunikat, gdy trzeba odpocząć.", { "PlayerFrame" } },
  { "Walka i mana", "Picie i jedzenie", "Po walce wciśnij Z (picie: Grimuar kładzie tam najlepszą wodę z torby) i X (jedzenie, też najlepsze z torby). Postać usiądzie i odnowi manę, a jedzenie odnawia życie. Pij i jedz naraz. Ruch i walka przerywają odpoczynek. Klawisz 0 tylko tworzy wodę czarem (od 4 poziomu), a klawisz - chleb (od 6), nie piją ani nie jedzą." },
  { "Walka i mana", "Kiedy uciekać", "Dwa albo trzy moby naraz to na niskim poziomie duże ryzyko. Mało życia? Frost Nova, odejdź i wróć po odpoczynku. Omijaj moby z czaszką zamiast poziomu i moby z czerwonym poziomem." },
  { "Walka i mana", "Śmierć", "Po śmierci kliknij Release Spirit. Jako duch biegnij do swojego ciała (strzałka na minimapie) i kliknij Resurrect. Spirit Healer wskrzesi od razu, ale zepsuje sprzęt i osłabi Cię na kilka minut." },

  -- 4. Miasto i NPC
  { "Miasto i NPC", "Trener maga", "Co 2 poziomy odwiedź trenera maga: prawy klik, wybierz czar, Train. Po awansie Polestar pokaże kartę z czarami do kupienia i przycisk Train All. Nowe czary Grimuar sam położy na paski." },
  { "Miasto i NPC", "Kupiec i naprawa", "Prawy klik na kupca otwiera sklep. Sprzedajesz prawym klikiem na przedmiot w torbie. Leatrix sam sprzeda szare śmieci i naprawi sprzęt u kupca z kowadłem. Sprzedałeś coś przez pomyłkę? Zakładka Buyback." },
  { "Miasto i NPC", "Karczma i Hearthstone", "U karczmarza (Innkeeper) wybierz Make this inn your home. Hearthstone z torby raz na godzinę przenosi Cię do tej karczmy. W karczmie i w mieście naliczasz rested XP." },
  { "Miasto i NPC", "Loty", "Flight master (ikona skrzydeł nad głową) zabiera Cię do odkrytych punktów lotu. Przy każdym nowym porozmawiaj z nim, żeby go odblokować. Lot kosztuje kilka monet i oszczędza dużo biegania." },
  { "Miasto i NPC", "Bank i poczta", "Bank jest w Ironforge (The Vault) i w Stormwind. Zostawiasz tam rzeczy, które nie mieszczą się w torbach. Skrzynka pocztowa jest w każdym mieście: tam przychodzą pieniądze ze sprzedaży na aukcji." },
  { "Miasto i NPC", "Dom aukcyjny", "Aukcjoner w Ironforge. Zakładka Auctionator: najpierw Full Scan, potem Selling. Kliknij przedmiot w torbie, addon podpowie cenę, kliknij Post. Tu sprzedasz zioła i rudę z profesji." },

  -- 5. Rozwój postaci
  { "Rozwój postaci", "Talenty", "Od 10 poziomu dostajesz punkt talentu na każdy poziom. N otwiera talenty: kliknij talent i zatwierdź. Kolejność jest w zakładce Talenty Grimuara, a bieżący talent podpowiada Teraz zrób.", nil, { "Otwórz talenty", function() openTalents() end } },
  { "Rozwój postaci", "Księga czarów", "P otwiera listę Twoich czarów. Każdy możesz przeciągnąć na pasek. Najważniejsze Grimuar kładzie sam, resztę (np. Slow Fall) przeciągnij, gdy będziesz potrzebować.", nil, { "Otwórz księgę", function() openSpellbook() end } },
  { "Rozwój postaci", "Sprzęt i Pawn", "C otwiera postać i sprzęt. Mag nosi tylko tkaninę (cloth), laski, sztylety, miecze 1H, różdżki i off-handy. Zielona strzałka Pawn znaczy, że przedmiot jest lepszy. Zakładasz go prawym klikiem w torbie.", nil, { "Otwórz postać", function() pcall(ToggleCharacter, "PaperDollFrame") end } },
  { "Rozwój postaci", "Profesje: zbieranie", "K otwiera profesje. Najpierw naucz się Herbalism i Mining u trenerów profesji (zapytaj strażnika o Profession Trainer). Potem włącz śledzenie: przycisk obok albo lupa przy nazwie strefy nad minimapą i Find Herbs lub Find Minerals. Zioła i ruda pojawią się na minimapie jako kropki. Zbierasz je prawym klikiem.", { "Minimap" }, { "Włącz śledzenie", function() enableGatherTracking() end } },
  { "Rozwój postaci", "First Aid", "First Aid robi bandaże z tkaniny, która wypada z humanoidów, i mikstury leczenia. Trener First Aid jest w miastach. Bandaż używaj poza walką albo gdy mob jest zamrożony Novą." },
  { "Rozwój postaci", "AtlasLoot i BiS", "/al albo przycisk przy minimapie pokazuje łupy z każdego bossa. W opisie przedmiotu AtlasBIStooltips dopisze, czy to najlepszy przedmiot dla maga (BiS).", nil, { "Wpisz /al", function() typeCommand("/al") end } },

  -- 6. Grupa i PvP
  { "Grupa i PvP", "Grupa", "Zaproszenie: prawy klik na portret gracza i Invite. Dungeon to 5 osób: tank, healer i trzech DPS. Grupę zbierasz na tablicy Looking For Group albo z ekipą, bo w Forever nie ma automatycznego wyszukiwania." },
  { "Grupa i PvP", "Łupy w grupie", "Need klikaj tylko na rzecz, którą założysz od razu (tkanina, laska, różdżka). Greed na resztę, jeśli chcesz ją sprzedać. Need bez potrzeby to ninja i koniec zaproszeń." },
  { "Grupa i PvP", "Boss i DBM", "W dungeonie DBM sam odlicza ataki bossa paskami i głosem. Słyszysz ostrzeżenie: zrób, co mówi, np. wyjdź z ognia. Nie bij, zanim tank nie zbierze aggro." },
  { "Grupa i PvP", "Threat", "Okno Threat w grupie: gdy Twój pasek zbliża się do 100%, zaraz zabierzesz moba tankowi. Przestań na chwilę bić albo dobijaj różdżką. Grając solo możesz okno zwinąć." },
  { "Grupa i PvP", "Spy i Horda", "Na serwerze PvP gracze Hordy mogą Cię zaatakować w strefach spornych. Spy (okno Nearby pod Damage Done) ostrzega o nich, a Grimuar przy wejściu w strefę sporną. Wyższy poziom albo kilku naraz? Frost Nova, Blink i ucieczka.", { "Spy_MainWindow" } },

  -- 7. Addony i Grimuar
  { "Addony i Grimuar", "Baganator: torby", "B otwiera torby w jednym oknie, pogrupowane na jedzenie, questy, sprzęt i śmieci. Na górze jest wyszukiwarka. Nową torbę przeciągasz na pusty slot obok plecaka (w Forever prawy klik jej nie założy), a przy bankierze otwiera się też bank.", { "Baganator_CategoryViewBackpackViewFrame", "Baganator_SingleViewBackpackViewFrame" }, { "Otwórz torby", function() pcall(ToggleAllBags) end } },
  { "Addony i Grimuar", "Leatrix Plus", "/ltp otwiera ustawienia. Sprzedaż śmieci i naprawę masz włączone. Każda opcja ma opis po najechaniu, a zmiany zatwierdza Reload. /rl przeładowuje grę.", nil, { "Wpisz /ltp", function() typeCommand("/ltp") end } },
  { "Addony i Grimuar", "Leatrix Maps i współrzędne", "Mapa (M) jest odkryta w całości, a na dole widać współrzędne kursora i Twoje. Grimuar podaje współrzędne książek i miejsc, np. Stormwind 38, 81." },
  { "Addony i Grimuar", "Obrażenia, odnowienia, Edit Mode", "Damage Done pokazuje Twoje obrażenia. Cooldown Manager pokazuje odnowienie Novy i Blinka. Ustawisz go w Edit Mode: Esc, Edit Mode, przeciągnij nad paski, Save. Tam też przesuwasz każdą ramkę gry." },
  { "Addony i Grimuar", "Przyciski przy minimapie", "Wokół minimapy są przyciski addonów: Grimuar (Frostbolt), Questie, DBM, AtlasLoot, Leatrix. Kliknięcie otwiera addon, przytrzymanie i przeciągnięcie przesuwa przycisk.", { "Minimap" } },
  { "Addony i Grimuar", "Pasek Grimuara", "Na górze ekranu: XP na godzinę, czas do poziomu, rested i czas sesji. Druga linia to bieżący krok. Kliknięcie otwiera okno Grimuara, przeciągnięcie przesuwa pasek. /grimuar krok chowa drugą linię.", { "GrimuarHUD" } },
  { "Addony i Grimuar", "Grimuar pod Polestarem", "Pod oknem Polestar jest pasek Grimuara z jednym krokiem spoza questów: talent, trener, pancerz, woda, książka, zadanie etapu. Ma przyciski Prowadź, Zrobione, Mam, Pomiń i Cofnij, a Więcej otwiera pełne okno. Gdy nie ma nic do zrobienia, znika. Wyłączysz go komendą /grimuar dock.", { "GrimuarDock", "PolestarGuideFrame" } },
  { "Addony i Grimuar", "Jedna strzałka do wszystkiego", "Strzałka Polestar prowadzi po questach, a gdy w strefie jest coś od Grimuara (trener z nowymi czarami, książka z biblioteki), sama przełącza się tam i ogłasza to na środku ekranu. Po zakupie czarów albo kliknięciu Mam wraca do questów. Pomiń przy kroku od razu oddaje strzałkę questom, /grimuar auto wyłącza przełączanie." },
  { "Addony i Grimuar", "Okno Grimuara", "Shift+G albo przycisk z Frostboltem. Zakładki: Teraz (co robić), Plan, Mapa, Talenty, Czary, Walka, Dungeony, PvP, Sprzęt, Profesje, Addony, Podstawy, Słownik i Samouczek.", { "GrimuarPanel", "GrimuarMinimapButton" }, { "Otwórz okno", function() ensurePanel("teraz") end } },
  { "Addony i Grimuar", "Teraz zrób", "Zielony krok to najważniejsza rzecz w tej chwili, pod nim jest wyjaśnienie. Prowadź stawia strzałkę, Zrobione i Mam odhaczają, Pomiń chowa krok, Cofnij odwraca pomyłkę. Krok zmienia się sam, gdy coś zrobisz.", { "GrimuarPanel" }, { "Pokaż Teraz", function() ensurePanel("teraz") end } },
  { "Addony i Grimuar", "Mapa i książki", "Zakładka Mapa: Prowadź stawia znacznik i strzałkę do każdej książki z bibliotek. Za 20 książek dostaniesz pierścień do BiS. Po podniesieniu książki kliknij Mam.", { "GrimuarPanel" }, { "Pokaż Mapę", function() ensurePanel("mapa") end } },
  { "Addony i Grimuar", "Minutnik sesji", "Ustaw, ile masz dziś czasu. 10 minut przed końcem Grimuar przypomni o karczmie. Przyciski są w zakładce Teraz, komenda: /grimuar sesja 60.", { "GrimuarHUD" }, { "Ustaw 60 min", function() setBudget(60); if G.refreshAll then G.refreshAll() end end } },
  { "Addony i Grimuar", "Przypominajki", "Przypomnienia pojawiają się jako złota wstęga u góry ekranu, jak w Wiedźminie, z cichym dźwiękiem: pancerz, Arcane Intellect, woda, trener, talent, naprawa, pełne torby. Z czerwoną wstęgą i głośnym dźwiękiem: wylogowanie poza karczmą, strefa sporna i koniec sesji. Nowy krok pod Polestarem miga złotą ramką. /grimuar komunikaty wyłącza je, a /wstegi przywraca dawne okienko na środku.", nil, { "Pokaż przykład", function() pcall(showToast, "brak Arcane Intellect: klawisz 9.", "ai", false) end } },
  { "Addony i Grimuar", "Aktualizacje addonów", "W CurseForge nie klikaj Update dla Forever, bo podmieniłby addony na wersje Retail, które tu nie działają. Aktualizacje zrobi Claude: wystarczy napisać w czacie z Claude." },
  { "Układ pro", "Ekran jak u doświadczonych graczy", "Zasada: wszystko, na co patrzysz w walce, blisko postaci, a reszta w rogach. Kliknij Ustaw automatycznie: Grimuar sam przesunie Twoją ramkę, ramkę celu, pasek rzucania, odnowienia i Damage Done, schowa gryfy i włączy pasek życia i many pod postacią. Potem /reload. Niebieskie ramki pokazują, gdzie co trafi. Jeśli automat nie zadziała, kolejne kroki pokażą, jak to zrobić ręcznie w Edit Mode.", { "GrimuarGhostCast" }, { "Ustaw automatycznie", function() G.applyProLayout() end } },
  { "Układ pro", "Twoja ramka", "W Edit Mode kliknij swoją ramkę (portret z paskami życia i many) i przeciągnij ją na niebieską ramkę Twoja postać, na lewo od środka. Masz wtedy życie i manę blisko oczu.", { "GrimuarGhostPlayer" } },
  { "Układ pro", "Ramka celu", "Przeciągnij ramkę celu na ramkę Cel, na prawo od środka. W jej ustawieniach w Edit Mode zaznacz Target of Target: zobaczysz, kogo bije Twój cel.", { "GrimuarGhostTarget" } },
  { "Układ pro", "Pasek rzucania", "Kliknij Cast Bar (pasek rzucania) i przeciągnij go pod postać, na ramkę Pasek rzucania. Jeśli ma opcję przypięcia do ramki postaci, odznacz ją.", { "GrimuarGhostCast" } },
  { "Układ pro", "Odnowienia", "Cooldown Manager przeciągnij nad paski akcji, na ramkę Odnowienia. Dodaj do niego Frost Nova, Blink, Counterspell, Evocation, a później Ice Block i Cold Snap. Widzisz wtedy odnowienia bez patrzenia na paski.", { "GrimuarGhostCooldowns" } },
  { "Układ pro", "Paski akcji", "Kliknij Action Bar 1 i zaznacz Hide Bar Art: znikną ozdobne gryfy. Paski 1 i 2 zostaw na dole na środku.", { "MainActionBar", "MainMenuBar", "MultiBarBottomLeft" } },
  { "Układ pro", "Obrażenia i aggro", "Damage Done i okno Threat przeciągnij w lewy górny róg, na ramkę Damage Done i Threat. Pod Polestarem zostaje miejsce na pasek Grimuara.", { "GrimuarGhostMeters" } },
  { "Układ pro", "Pasek pod postacią", "Doświadczeni gracze włączają pasek życia i many tuż pod postacią (Personal Resource Display). Manę masz wtedy zawsze przed oczami. Przycisk obok go włącza, a wyłączysz w Opcjach w sekcji tabliczek (Nameplates).", nil, { "Włącz pasek", function() G.setCVarSafe("nameplateShowSelf", "1"); showToast("pasek życia i many pod postacią włączony.", "", false) end } },
  { "Układ pro", "Liczby obrażeń", "Liczby nad celem i postacią pokazują, ile zadajesz i otrzymujesz obrażeń. Przycisk obok je włącza. Pomaga to szybko zauważyć, że ktoś Cię bije.", nil, { "Włącz liczby", function() G.setCVarSafe("enableFloatingCombatText", "1"); G.setCVarSafe("floatingCombatTextCombatDamage", "1"); showToast("liczby obrażeń włączone.", "", false) end } },
  { "Układ pro", "Zapisz układ", "W Edit Mode kliknij Save. Gotowe: niebieskie ramki znikną po zamknięciu kursu. Do tego rozdziału wrócisz komendą /grimuar pro." },
}
-- krok sync zostaje na koncu rozdzialu Addony i Grimuar, przed Ukladem pro
do
  local syncStep = G.personal() and { "Addony i Grimuar", "Po grze: sync", "Wyloguj się albo wpisz /reload, a potem napisz Claude „sync”. Zapiszę Twoje sesje na stronie Grimuar maga i dopasuję plan. Powodzenia!" }
    or { "Addony i Grimuar", "Po grze", "Wyloguj się w karczmie albo w mieście: odpoczynek da podwójne XP w następnej sesji. Podsumowanie sesji masz w hubie (Kronika)." }
  local firstPro
  for i, st in ipairs(TUTORIAL) do
    if st[1] == "Układ pro" then firstPro = i break end
  end
  table.insert(TUTORIAL, firstPro or (#TUTORIAL + 1), syncStep)
end

-- Ramki-podpowiedzi: { nazwa, podpis, x i y jako ulamek ekranu od srodka, szerokosc, wysokosc }
local GHOSTS = {
  { "GrimuarGhostPlayer", "Twoja postać", -0.17, -0.25, 230, 70 },
  { "GrimuarGhostTarget", "Cel (z celem celu)", 0.17, -0.25, 230, 70 },
  { "GrimuarGhostCast", "Pasek rzucania", 0, -0.12, 230, 24 },
  { "GrimuarGhostCooldowns", "Odnowienia (Cooldown Manager)", 0, -0.34, 270, 40 },
  { "GrimuarGhostMeters", "Damage Done i Threat", -0.40, 0.39, 230, 130 },
}
local ghostFrames = {}

local function showGhosts()
  local w, h = UIParent:GetWidth(), UIParent:GetHeight()
  for _, gd in ipairs(GHOSTS) do
    local g = ghostFrames[gd[1]]
    if not g then
      g = CreateFrame("Frame", gd[1], UIParent, "BackdropTemplate")
      g:SetFrameStrata("BACKGROUND")
      g:EnableMouse(false)
      setBackdrop(g, STYLE.accentSoft, STYLE.accent)
      g.label = g:CreateFontString(nil, "OVERLAY")
      g.label:SetFont(FONT, 13, "OUTLINE")
      g.label:SetTextColor(unpack(STYLE.accent))
      g.label:SetPoint("CENTER", g, "CENTER", 0, 0)
      ghostFrames[gd[1]] = g
    end
    g:SetSize(gd[5], gd[6])
    g:ClearAllPoints()
    g:SetPoint("CENTER", UIParent, "CENTER", gd[3] * w, gd[4] * h)
    g.label:SetText(gd[2])
    g:Show()
  end
end

local function hideGhosts()
  for _, g in pairs(ghostFrames) do g:Hide() end
end

local function setCVarSafe(name, value)
  pcall(function()
    if C_CVar and C_CVar.SetCVar then C_CVar.SetCVar(name, value) else SetCVar(name, value) end
  end)
end

-- eksport do pozostalych modulow
G.ensurePanel = ensurePanel
G.typeCommand = typeCommand
G.openSpellbook = openSpellbook
G.TUTORIAL = TUTORIAL
G.showGhosts = showGhosts
G.hideGhosts = hideGhosts
G.setCVarSafe = setCVarSafe
