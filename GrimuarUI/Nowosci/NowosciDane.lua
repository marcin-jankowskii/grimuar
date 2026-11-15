-- Grimuar UI: dane zakladki Nowosci (14.11; gracz: „zakladke z patch notesami dodaj, jak reszte skonczysz”).
-- GRIMUAR: zmiany Grimuara wedlug wersji (najnowsze na gorze). FOREVER: lacznie WoW Forever z datami i zrodlami,
-- uzupelniane przy synchronizacji z cotygodniowego przegladu nowosci (routine w chmurze, czwartki) i researchu.
-- Teksty: { pl = ..., en = ... } albo sam polski. Nowa wersja w GRIMUAR[1] = komunikat po wejsciu do gry.
-- Tagi wpisu (filtr „Dla mojego buildu”, TabNowosci.lua): who = "all" | "caster" | "healer" | "tank" | { "MAGE", ... },
-- lvl = { od, do } (poziomy, ktorych dotyczy), topic = { "lochy", "rajd", "ah", "grupa", "pvp", "profesje", "event", "sprzet" },
-- ends = "RRRR-MM-DD" (po tej dacie wpis nieaktualny), spells = { "Ice Lance", ... } (czary i talenty, ktorych dotyczy).
-- Nazwy czarow i talentow z aktywnego buildu filtr wylapuje tez sam w tresci wpisu.
local ADDON, U = ...

U.NOWOSCI_GRIMUAR = {
  { ver = "0.18 / 5.9", date = "15.11.2026", title = { pl = "Polestar w Grimuarze", en = "Polestar in Grimuar" }, items = {
    { pl = "„Prowadź” przez strzałkę Polestara, z czasem dojścia; po dojściu strzałka sama wraca do przewodnika.", en = "Guide buttons use Polestar's arrow with travel time; the arrow returns to the guide on arrival." },
    { pl = "Poprawka: „Prowadź” z poradników trafia w punkt także na przebudowanych mapach Forever.", en = "Fix: guide targets land on the spot on rebuilt Forever maps too." },
    { pl = "Tempo trasy na pasku, „Przy okazji” i „Za Tobą”, ◆ „krok N” w torbach (nie sprzeda się jako śmieć).", en = "Route pace on the bar, While you're here / Behind you, ◆ step N in bags (never sold as junk)." },
    { pl = "Czary na poziom z kosztem i najbliższy trener, dokładny koszt jazdy, XP z questów lochu i limit wejść.", en = "Spells per level with cost and the nearest trainer, exact riding cost, dungeon quest XP and lockouts." },
    { pl = "Karty: ulepszenia przed Tobą, lochy (zbierz i oddaj questy), „Skąd zdobyć”, questy klasowe, usługi w pobliżu, „Teraz wg Polestara”.", en = "Cards: upgrades ahead, dungeon quests, where to get it, class quests, nearby services, Now (Polestar)." },
    { pl = "Poprawki z gry: kompas nie znika, okno rozmowy nie zostaje puste, „!” znika po przyjęciu questa, pas wyżej, kategorie ekwipunku jak w plecaku.", en = "Play-test fixes: compass stays, dialogue window no longer empty, ! disappears after accepting, belt higher, equipment categories like the bags." },
  } },
  { ver = "0.17 / 5.8", date = "15.11.2026", title = { pl = "Poradnik przy profesji, łup jako karty, PvP", en = "Guide by the profession window, loot cards, PvP" }, items = {
    { pl = "Przy oknie profesji panel poradnika Polestara: pasek do progu, „Zrób N”, składniki z bankiem, ceną z aukcji i sprzedawcą.", en = "Polestar guide panel by the profession window: skill bar, Make N, reagents with bank, auction price and vendor." },
    { pl = "Łup jako karty z powodem (◆ do poradnika, ulepszenie wg Pawna); rzuty w grupie z podpowiedzią i przyciskami, nic nie rzuca samo.", en = "Loot as cards with a reason; group rolls with advice and buttons, nothing rolls by itself." },
    { pl = "Rynek: kategoria „◆ Do poradnika” i zakładka Sprzedaj (wystawienie nadwyżek materiałów dwoma kliknięciami).", en = "Market: For guides category and a Sell tab (post surplus materials in two clicks)." },
    { pl = "Zakładka PvP: zabójstwa, honor, kolejka, pola bitew, ostatnie mecze, rada na każdą klasę z bilansem ze Spy.", en = "PvP tab: kills, honor, queue, battlegrounds, recent matches, advice per class with your Spy score." },
    { pl = "Karta „Ile masz czasu?” na start sesji: plan jako karty i to, co da najwięcej w tym czasie.", en = "How much time do you have? card at session start: the plan as cards and the best value for that time." },
    { pl = "/gr test sprawdza też nowe okna; angielskie napisy nowych okien.", en = "/gr test also checks the new windows; English strings for the new windows." },
  } },
  { ver = "0.16 / 5.7", date = "15.11.2026", title = { pl = "Okna gry w stylu Grimuara", en = "Game windows in Grimuar style" }, items = {
    { pl = "Kupiec: towar „dla buildu” z powodem i „masz N”, odkup, naprawa; śmieci sprzedają się same po otwarciu kupca.", en = "Merchant: goods for your build with reasons, buyback, repair; junk sells itself when the merchant opens." },
    { pl = "Trener: „Kup wg buildu” z sumą, pominięte czary z powodem, „Później” wg poziomu.", en = "Trainer: buy by build with total, skipped spells with reasons, later by level." },
    { pl = "Poczta (odbierz wszystko, wysyłanie z załącznikami) i Bank (prawy klik przenosi, odłóż materiały, sortowanie).", en = "Mailbox (take all, send with attachments) and Bank (right-click moves, deposit materials, sort)." },
    { pl = "Ustawienia na cały ekran w hubie: Sterowanie, Kamera, Walka, Interfejs, Grafika, Dźwięk, Grimuar, Klawisze i Makra, z wyszukiwarką.", en = "Full-screen Settings tab: controls, camera, combat, interface, graphics, sound, Grimuar, key bindings and macros, with search." },
  } },
  { ver = "0.15 / 5.6", date = "15.11.2026", title = { pl = "Polestar w hubie, mniej chowania", en = "Polestar in the hub, less hiding" }, items = {
    { pl = "Rzemiosło: „Poradnik Polestara” z krokami dla Twojego poziomu profesji, składnikami z torby i prowadzeniem do trenera.", en = "Crafting: Polestar guide with steps for your profession level, reagents from your bags and guidance to the trainer." },
    { pl = "Wyprawy: obraz lochu z Polestara, „najlepiej na”, znak Forever, przycisk „W Polestarze”; Łupy jako ikony z dymkiem i oceną Pawna.", en = "Expeditions: dungeon art from Polestar, best level, Forever tag, Open in Polestar; loot as icons with tooltip and Pawn rating." },
    { pl = "Kronika: kontrakty, ranga, 7 dni i kalendarz jako karty z paskami zamiast tekstu.", en = "Chronicle: contracts, rank, last 7 days and calendar as cards with bars instead of text." },
    { pl = "Kwoty monetami jak w grze (złoto, srebro, miedź) zamiast „g s m”.", en = "Money shown with coin icons instead of g s m." },
    { pl = "Wracają łuki życia i many, minimapa jest zawsze widoczna, kompas zostaje w walce i w lochu, okienko Profesje zostaje w drużynie.", en = "Health and mana arcs are back, minimap always visible, compass stays in combat and dungeons, Professions box stays in a party." },
    { pl = "Menu Esc na cały ekran naprawione (nie wstawało przez błąd czcionki).", en = "Full-screen Esc menu fixed (it failed on a font error)." },
    { pl = "Rozmowa z NPC i questy w oknie Grimuara: pergamin, wybory 1–9, nagrody jako karty z najlepszą dla buildu. /hub rozmowa przełącza.", en = "NPC dialogue and quests in a Grimuar window: parchment, choices 1–9, rewards as cards with the best for your build. /hub rozmowa toggles." },
    { pl = "Ekwipunek: Plecak+ (nowe grupy, ◆ potrzebne, ★ ulubione, sprzedaż śmieci, odkładanie materiałów), pas podręczny w HUD (/hub pas) i zakładka huba Ekwipunek z porównaniem i listą.", en = "Inventory: Bag+ (new groups, needed and favourite marks, sell junk, deposit materials), quick belt in the HUD (/hub pas) and a hub tab with comparison and list view." },
    { pl = "Buildy: podgląd w kartach i edycja w grze każdej sekcji: talenty, trener, paski (też „Weź paski z gry”), combo, koło, makra, porady. „Edytuj” przy wbudowanym buildzie robi kopię.", en = "Builds: card view and in-game editing of every section: talents, trainer, bars (also take bars from the game), combo, wheel, macros, tips. Edit on a built-in build makes a copy." },
  } },
  { ver = "0.14 / 5.5", date = "14.11.2026", title = { pl = "Buildy dla każdego", en = "Builds for everyone" }, items = {
    { pl = "Nowa zakładka Buildy: wbudowany mag Frost, szkice z planów talentów Polestara dla każdej klasy, własne i importowane buildy.", en = "New Builds tab: built-in Frost Mage, drafts from Polestar talent plans for every class, own and imported builds." },
    { pl = "Edycja buildów, także kopii buildów Polestara: kolejność talentów, „Zapisz moje talenty”, nagrywanie punktów, AoE u trenera.", en = "Build editing, including copies of Polestar builds: talent order, Save my talents, point recording, AoE at the trainer." },
    { pl = "Kod buildu do wysłania znajomym (!GRB1!…). Import przyjmuje tylko dane, makra z /run są odrzucane.", en = "Build code to share (!GRB1!…). Import takes data only; macros with /run are refused." },
    { pl = "Kreator przy pierwszym uruchomieniu: język, build i osobne zgody na zmiany w grze.", en = "First-run wizard: language, build and separate consents for game changes." },
    { pl = "Moduły bez założenia, że grasz magiem: trener „Kup wg buildu”, combo, buffy, koło, rola, stare okno i plan dla innych klas i ras.", en = "Modules no longer assume a mage: trainer by build, combo, buffs, wheel, role, old window and plan for other classes and races." },
    { pl = "Angielski: /gr jezyk en. Krótkie komendy działają jako /gr <nazwa>.", en = "English: /gr jezyk en. Short commands also work as /gr <name>." },
    { pl = "Ta zakładka: Nowości Grimuara i łatki WoW Forever.", en = "This tab: Grimuar news and WoW Forever patch notes." },
  } },
  { ver = "0.12", date = "14.11.2026", title = { pl = "Wyprawy", en = "Expeditions" }, items = {
    { pl = "Zakładka Wyprawy: lochy i rajdy z oceną dla drużyny (od 13.11 szary mob = 0 XP dla wszystkich), bossowie i questy lochu, prowadzenie do wejścia.", en = "Expeditions tab: dungeons and raids rated for your party (since 13.11 a gray mob gives 0 XP to all), bosses and dungeon quests, guide to entrance." },
    { pl = "Wieczór ze znajomymi: termin, tekst na Discord, szept, zaproszenie z odpowiedzią Będę / Może / Nie.", en = "Evenings with friends: date, Discord text, whisper, invite with I'm in / Maybe / No." },
    { pl = "Drużyna z Grimuarem: poziom, woda, sprzęt i torby znajomych; skład rajdu; wejścia do lochów w godzinie i blokady.", en = "Party with Grimuar: friends' level, water, gear and bags; raid composition; dungeon entries per hour and lockouts." },
  } },
  { ver = "0.11", date = "14.11.2026", title = { pl = "HUD według makiet", en = "HUD from the mockups" }, items = {
    { pl = "Duża nazwa miejsca, komunikaty po lewej (Odkryto, Zebrano, Postęp zadania), poziome paski życia i many, paski akcji przygaszone poza walką.", en = "Big place name, notifications on the left (Discovered, Gathered, Quest progress), horizontal health and mana bars, action bars dimmed out of combat." },
  } },
  { ver = "0.10", date = "14.11.2026", title = { pl = "Kronika, Księga, grupa", en = "Chronicle, Codex, group" }, items = {
    { pl = "Udostępnianie wszystkich zadań, zadania od grupy przyjmowane same, gotowość, księżyc na owcę, daj wodę.", en = "Share all quests, auto-accept quests from the group, ready check, moon marker, give water." },
    { pl = "Cel u góry w walce, minimapa tylko gdy potrzebna. Kronika: sesje, łupy, rachunki, kontrakty, kalendarz, „Poprzednio…”.", en = "Target at the top in combat, minimap only when needed. Chronicle: sessions, loot, ledger, contracts, calendar, Previously…" },
    { pl = "Księga: bestiariusz, rywale ze Spy, krainy. Koło czarów, zestawy sprzętu, trasa w rozdziałach.", en = "Codex: bestiary, rivals from Spy, lands. Utility wheel, equipment sets, route in chapters." },
  } },
  { ver = "0.9.8", date = "14.11.2026", title = { pl = "Kompas", en = "Compass" }, items = {
    { pl = "Kompas u góry ekranu: kierunki, cel Polestara, cele zadań w kolorach, zioła i ruda.", en = "Compass at the top: directions, Polestar target, quest objectives in colors, herbs and ore." },
  } },
  { ver = "0.9.7", date = "14.11.2026", title = { pl = "Zadania profesji", en = "Profession tasks" }, items = {
    { pl = "Profesje jak questy: zbierz, zrób, do trenera, sprzedaj; w Dzienniku i w Rzemiośle.", en = "Professions as quests: gather, craft, to trainer, sell; in the Journal and Crafting." },
  } },
  { ver = "0.1–0.9", date = "14.11.2026", title = { pl = "Hub jak w Wiedźminie", en = "Witcher-style hub" }, items = {
    { pl = "Pełnoekranowy hub z zakładkami Q/E według makiet: Postać, Umiejętności, Dziennik, Mapa, Rzemiosło, Społeczność, Osiągnięcia, Grimuar.", en = "Full-screen hub with Q/E tabs from the mockups: Character, Spells, Journal, Map, Crafting, Social, Achievements, Grimuar." },
  } },
}

U.NOWOSCI_FOREVER = {
  { date = "9.12.2026", title = { pl = "Rajdy (zapowiedź)", en = "Raids (announced)" }, src = "Blizzard (zapowiedź rajdów)", items = {
    { who = "all", lvl = { 60, 60 }, topic = { "rajd" }, pl = "Barrow Deeps (10 osób, 8 bossów), Hyjal Summit (20 osób, 13 bossów), Onyxia's Lair (40 osób, Drakefire Amulet). Reset co tydzień; zasad łupów jeszcze nie ogłoszono.", en = "Barrow Deeps (10 players, 8 bosses), Hyjal Summit (20, 13 bosses), Onyxia's Lair (40, Drakefire Amulet). Weekly reset; loot rules not announced yet." },
  } },
  { date = "18.11.2026", title = { pl = "Dom aukcyjny (konserwacja EU)", en = "Auction house (EU maintenance)" }, src = "Blizzard, Kaivax 12.11", items = {
    { who = "all", topic = { "ah" }, pl = "Depozyt za wystawienie spada do 1 c; poprawka nadawcy poczty z domu aukcyjnego. Od tego dnia opłaca się wystawiać pojedyncze sztuki.", en = "Listing deposit drops to 1 copper; fix for the auction house mail sender. From then on single items are worth listing." },
  } },
  { date = "13.11.2026", title = { pl = "Poprawki (hotfix)", en = "Hotfixes" }, src = "forum Blizzarda, hotfixy 5–13.11", items = {
    { who = "all", lvl = { 1, 59 }, topic = { "lochy", "grupa" }, pl = "W lochu mob szary dla choćby jednej osoby daje 0 XP całej drużynie: przeciąganie niższego znajomego nic mu nie daje.", en = "In dungeons a mob that is gray for anyone gives 0 XP to the whole party: carrying a lower friend gives them nothing." },
    { who = "all", topic = { "lochy" }, pl = "Cotygodniowe questy lochowe u Pix Xizzix (znikają przy resecie tygodniowym).", en = "Weekly dungeon quests from Pix Xizzix (they disappear at the weekly reset)." },
    { who = "caster", topic = { "sprzet" }, ends = "2026-12-09", pl = "Channeler's Ring dostał Spell Power; Blessed Band of Light wymienisz na niego u Pix Xizzix do otwarcia rajdów (bez cofnięcia).", en = "Channeler's Ring gained Spell Power; trade Blessed Band of Light for it at Pix Xizzix until raids open (no undo)." },
  } },
  { date = "11.11.2026", title = { pl = "Invite-a-Friend", en = "Invite-a-Friend" }, src = "Gfinity, 11.11", items = {
    { who = "all", topic = { "grupa" }, pl = "Akcja z kodami zaproszeń z pakietów zakończona. Recruit-a-Friend dla Forever nie ogłoszono.", en = "The invite code promotion has ended. Recruit-a-Friend has not been announced for Forever." },
  } },
  { date = "6–10.11.2026", title = { pl = "Poprawki (hotfix)", en = "Hotfixes" }, src = "forum Blizzarda", items = {
    { who = "all", lvl = { 1, 59 }, topic = { "grupa" }, pl = "Przedmioty do zadań wypadają całej drużynie (kilka poprawek 6, 9, 10 i 13.11).", en = "Quest items drop for the whole party (several fixes on 6, 9, 10 and 13.11)." },
  } },
  { date = "9.11.2026", title = { pl = "Lochy i Jarmark", en = "Dungeons and the Faire" }, src = "Blizzard; kami-labs (daty z klienta)", items = {
    { who = "all", lvl = { 1, 59 }, topic = { "lochy" }, pl = "Moby w lochach dają o 50% więcej XP.", en = "Dungeon mobs give 50% more XP." },
    { who = "all", topic = { "event" }, ends = "2026-11-16", pl = "Jarmark Darkmoon w Elwynn Forest 9–16.11 (Sayge: buff na 2 h, w rajdach nie działa).", en = "Darkmoon Faire in Elwynn Forest 9–16.11 (Sayge: 2 h buff, no effect in raids)." },
  } },
}
U.NOWOSCI_FOREVER_NOTE = { pl = "Źródła: forum Blizzarda, zapowiedzi, cotygodniowy przegląd nowości (czwartki). Uzupełniane przy aktualizacji Grimuara.",
  en = "Sources: Blizzard forums and announcements, weekly news review (Thursdays). Updated with Grimuar releases." }
