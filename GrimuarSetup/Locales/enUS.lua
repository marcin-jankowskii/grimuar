-- Grimuar: slownik angielski (R27 E6, 14.11). Klucz = napis polski z kodu, wartosc = angielski. Najpierw to, co
-- widac najczesciej: zakladki huba, przyciski, naglowki, kreator, buildy, wyprawy, kronika, ksiega, grupa.
-- Brakujace napisy: /gr jezyk brak (zbiera je Locales\Tlumacz.lua).
local ADDON_NAME, G = ...
local T = G.TR

for pl, en in pairs({
  -- zakladki i dol huba
  ["Postać"] = "Character", ["Buildy"] = "Builds", ["Umiejętności"] = "Spells", ["Dziennik"] = "Journal", ["Mapa"] = "Map",
  ["Księga"] = "Codex", ["Rzemiosło"] = "Crafting", ["Społeczność"] = "Social", ["Wyprawy"] = "Expeditions",
  ["Osiągnięcia"] = "Achievements", ["Kronika"] = "Chronicle", ["Grimuar"] = "Grimuar",
  ["Zamknij"] = "Close", ["Zakładka"] = "Tab", ["W walce hub działa myszą; zamyka go ten sam klawisz"] = "In combat the hub works with the mouse; the same key closes it",
  -- kreator
  ["Witaj w Grimuarze"] = "Welcome to Grimuar", ["Język huba"] = "Hub language", ["Polski"] = "Polski", ["English"] = "English",
  ["Build (możesz zmienić później: hub > Buildy)"] = "Build (change it later: hub > Builds)", ["Następny"] = "Next",
  ["Co Grimuar może zmienić w grze (nic nie jest zaznaczone)"] = "What Grimuar may change in the game (nothing is ticked)",
  ["Zastosuj"] = "Apply", ["Pomiń (nic nie zmieniaj)"] = "Skip (change nothing)",
  -- buildy
  ["Wszystkie klasy"] = "All classes", ["Tylko moja klasa"] = "My class only", ["Ustaw jako aktywny"] = "Set as active",
  ["Duplikuj do edycji"] = "Duplicate to edit", ["Edytuj"] = "Edit", ["Usuń (tylko moje i importowane)"] = "Delete (own and imported only)",
  ["Ustaw też w Polestarze"] = "Also set in Polestar", ["Eksportuj (kod do skopiowania)"] = "Export (code to copy)",
  ["Importuj: wklej kod niżej, potem kliknij"] = "Import: paste the code below, then click", ["Kod buildu (wklej tutaj przy imporcie):"] = "Build code (paste here to import):",
  ["Wybierz build"] = "Pick a build", ["Edycja buildu"] = "Edit build", ["Zapisz"] = "Save", ["Zapisz moje talenty"] = "Save my talents",
  ["Nagrywaj"] = "Record", ["Zatrzymaj nagrywanie"] = "Stop recording", ["+ talent"] = "+ talent", ["Wyżej"] = "Up", ["Niżej"] = "Down",
  ["Wybierz talent"] = "Pick a talent", ["Build to dane: talenty, trener, paski, combo i porady. Kod udostępniasz znajomym"] = "A build is data: talents, trainer, bars, combo and tips. Share the code with friends",
  ["GRIMUAR"] = "GRIMUAR", ["MOJE"] = "MINE", ["IMPORTOWANE"] = "IMPORTED", ["POLESTAR (SZKICE)"] = "POLESTAR (DRAFTS)", ["aktywny"] = "active",
  -- wyprawy
  ["Lochy i rajdy"] = "Dungeons and raids", ["Kto idzie (znajomi online)"] = "Who is coming (friends online)", ["Prowadź do wejścia"] = "Guide to entrance",
  ["Wieczór z tym lochem"] = "Evening with this dungeon", ["Wieczór"] = "Evening", ["Drużyna"] = "Party", ["Przed lochem"] = "Before the dungeon",
  ["Zapisz wieczór"] = "Save evening", ["Prowadź na zbiórkę"] = "Guide to meeting point", ["Szepnij zaznaczonym"] = "Whisper selected",
  ["Na czat drużyny"] = "To party chat", ["PL / EN"] = "PL / EN", ["Lochy, rajdy i wieczory ze znajomymi"] = "Dungeons, raids and evenings with friends",
  ["Wybierz loch"] = "Pick a dungeon", ["Po lochu"] = "After the dungeon", ["GG na czat drużyny"] = "GG to party chat", ["Wysłane"] = "Sent",
  ["Zaproszenie na wyprawę"] = "Expedition invite", ["Będę"] = "I'm in", ["Może"] = "Maybe", ["Nie"] = "No",
  ["pasuje"] = "fits", ["część szara"] = "partly gray", ["0 XP"] = "0 XP", ["za trudny"] = "too hard",
  -- spolecznosc i grupa
  ["Znajomi"] = "Friends", ["Grupa"] = "Group", ["Gildia"] = "Guild", ["Szukaj grupy"] = "Find a group", ["Szukaj grupy (gra)"] = "Find a group (game)",
  ["Znajomi i gildia (gra)"] = "Friends and guild (game)", ["Lochy na Twój poziom"] = "Dungeons for your level", ["Dodaj znajomego"] = "Add friend",
  ["Szepnij"] = "Whisper", ["Zaproś / prowadź do osoby z grupy"] = "Invite / guide to group member", ["Szept zamyka hub i otwiera czat"] = "Whisper closes the hub and opens chat",
  ["Udostępnij zadania"] = "Share quests", ["Gotowość"] = "Ready check", ["Księżyc na cel"] = "Moon on target", ["Daj wodę"] = "Give water",
  ["Zaproś cel"] = "Invite target", ["Opuść grupę"] = "Leave group", ["Na pewno? Kliknij"] = "Sure? Click", ["Udostępnij"] = "Share",
  -- kronika i ksiega
  ["Sesje"] = "Sessions", ["Tydzień i kontrakty"] = "Week and contracts", ["Kalendarz"] = "Calendar", ["Ta sesja"] = "This session",
  ["Wybierz sesję"] = "Pick a session", ["Łupy, rachunki, kontrakty i kalendarz liczą się same"] = "Loot, ledger, contracts and calendar track themselves",
  ["Poprzednio w Grimuarze"] = "Previously in Grimuar", ["Graj"] = "Play", ["Bestiariusz"] = "Bestiary", ["Rywale"] = "Rivals", ["Krainy"] = "Lands",
  ["Wybierz wpis"] = "Pick an entry", ["Zapisz notatkę"] = "Save note", ["Bestiariusz i rywale zapisują się sami z walk"] = "Bestiary and rivals fill themselves from fights",
  ["Kontrakty Grimuara — dzień i tydzień"] = "Grimuar contracts — day and week", ["Kontrakty dnia"] = "Daily contracts", ["Kontrakty tygodnia"] = "Weekly contracts",
  -- postac, umiejetnosci, dziennik, mapa, rzemioslo, osiagniecia, grimuar
  ["Atrybuty"] = "Attributes", ["Magia i obrona"] = "Magic and defense", ["Reputacje, waluty, honor"] = "Reputation, currency, honor", ["Torba"] = "Bag",
  ["Zestawy sprzętu"] = "Equipment sets", ["Załóż"] = "Equip", ["Zapisz obecny"] = "Save current", ["Księga czarów"] = "Spellbook", ["Talenty"] = "Talents",
  ["Do nauki"] = "To learn", ["Do wydania"] = "To spend", ["Wydaj punkt"] = "Spend point", ["Okno talentów gry"] = "Game talent window", ["Podgląd planu"] = "Plan preview",
  ["Złoty talent to następny punkt według planu Grimuara"] = "The gold talent is the next point of the Grimuar plan", ["Czar na pasek"] = "Spell to bar",
  ["Zadania"] = "Quests", ["Szczegóły"] = "Details", ["Prowadź"] = "Guide", ["Prowadź do zleceniodawcy"] = "Guide to quest giver", ["Śledź"] = "Track",
  ["Zadania tutaj"] = "Quests here", ["Teraz wg Polestara"] = "Now according to Polestar", ["Do wzięcia wg Polestara"] = "To pick up according to Polestar",
  ["Niepotrzebne — Grimuar: porzuć"] = "Not needed — Grimuar: abandon", ["Profesje — zadania Grimuara"] = "Professions — Grimuar tasks",
  ["Pergamin tylko w dzienniku, książkach i poczcie"] = "Parchment only in the journal, books and mail",
  ["Moja strefa"] = "My zone", ["Mapa wyżej"] = "Map up", ["Przybliż"] = "Zoom", ["Przesuń"] = "Pan", ["Mapa gry z Questie"] = "Game map with Questie",
  ["Usuń mój znacznik"] = "Remove my marker", ["Znacznik / strefa"] = "Marker / zone", ["Śledzenie ziół i rudy"] = "Herb and ore tracking",
  ["Profesje"] = "Professions", ["Składniki"] = "Reagents", ["Utwórz"] = "Create", ["Utwórz jeden"] = "Create one", ["Otwórz okno profesji"] = "Open profession window",
  ["Tworzenie działa przy otwartym oknie profesji"] = "Crafting works while the profession window is open", ["Sprzedaj kupcowi"] = "Sell to vendor",
  ["Sprzedaj na domu aukcyjnym"] = "Sell on the auction house", ["Kategorie"] = "Categories", ["Punkty osiągnięć"] = "Achievement points",
  ["Ostatnio"] = "Recent", ["Blisko"] = "Almost there", ["Okno osiągnięć (gra)"] = "Achievement window (game)", ["Złota ramka: zdobyte"] = "Gold frame: earned",
  ["Teraz"] = "Now", ["Rozwój"] = "Growth", ["Trasa Grimuara"] = "Grimuar route", ["Postęp"] = "Progress", ["Krok planu"] = "Plan step",
  ["Wykonaj krok (zamyka hub)"] = "Do the step (closes the hub)", ["Pełne okno Grimuara (Shift+G)"] = "Full Grimuar window (Shift+G)",
  ["Okno Polestara (Shift+J)"] = "Polestar window (Shift+J)", ["Plan Grimuara"] = "Grimuar plan", ["Ten odcinek"] = "This leg", ["Dalej"] = "Next",
  ["Dalej w planie"] = "Further in the plan", ["Następny według planu"] = "Next by plan", ["Odpoczynek"] = "Rest", ["Wierzchowiec"] = "Mount",
  ["Doświadczenie"] = "Experience", ["Rozwój przypomina też na wstędze co 10 minut"] = "Growth also reminds you on the banner every 10 minutes",
  ["Kończę grę — podsumuj"] = "I'm done — summarize", ["Kamień powrotu"] = "Hearthstone", ["Weź / załóż"] = "Take / equip",
  -- komunikaty czeste
  ["Grimuar"] = "Grimuar", ["Nowy talent"] = "New talent", ["Trener czeka"] = "Trainer waiting", ["Torby"] = "Bags", ["Brak pancerza"] = "No armor",
  ["Sprzęt zużyty"] = "Gear worn", ["Mało wody"] = "Low water", ["Strefa sporna"] = "Contested zone", ["Koniec sesji"] = "Session end",
  ["Karczma"] = "Inn", ["Plan na dziś"] = "Today's plan", ["Questy"] = "Quests", ["Loch"] = "Dungeon", ["Przed walką"] = "Before combat",
  ["Po śmierci"] = "After death",
  ["Nowości"] = "News", ["Zmiany w Grimuarze i łatki WoW Forever"] = "Grimuar changes and WoW Forever patch notes", ["WoW Forever"] = "WoW Forever", ["Dla mojego buildu"] = "For my build", ["◆ Dla mojego buildu"] = "◆ For my build", ["Odkryto"] = "Discovered", ["Zebrano"] = "Gathered", ["Postęp zadania"] = "Quest progress",
}) do T[pl] = en end

-- wzorce dla napisow z liczbami
local P = G.TRP
P[#P + 1] = { "^poziom (%d+)$", "level %1" }
P[#P + 1] = { "^Poziom (%d+)$", "Level %1" }
P[#P + 1] = { "^Udostępnij zadania %((%d+)%)$", "Share quests (%1)" }
P[#P + 1] = { "^Udostępnij %((%d+)%)$", "Share (%1)" }
P[#P + 1] = { "^Plan na 60: (.+) · (.+)$", "Plan for 60: %1 · %2" }
P[#P + 1] = { "^Punkty: (%d+) / 51", "Points: %1 / 51" }
P[#P + 1] = { "^(%d+) w grze · (%d+) razem$", "%1 online · %2 total" }
