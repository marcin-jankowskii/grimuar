-- Grimuar: angielskie napisy zmian po 5.9.0 (15.11, gracz: „angielskie napisy tez trzeba zrobic”). Klucz = caly napis
-- polski z kodu; napisy skladane z liczb i nazw: wzorce G.TRP. Dymki (G.TT) nie przechodza przez G.tr, wiec ich tu nie ma.
local ADDON_NAME, G = ...
local T = G.TR
local P = G.TRP

for pl, en in pairs({
  -- buildy: Dampen Magic i rady PvP
  ["kup: na Hordę rzucającą czary (czarnoksiężnik, kapłan, mag), Shift+T; nie trzymaj przy bandażu (osłabia leczenie)"] =
    "buy: against Horde casters (warlock, priest, mage), Shift+T; don't keep it up while bandaging (weakens healing)",
  ["bezużyteczne przy levelowaniu"] = "useless while leveling",
  ["Kapłan: Dampen Magic (Shift+T) przed walką, Counterspell (F) na leczenie, Blink (E) trzymaj na Psychic Scream."] =
    "Priest: Dampen Magic (Shift+T) before the fight, Counterspell (F) on heals, save Blink (E) for Psychic Scream.",
  ["Czarnoksiężnik to najtrudniejszy rywal: Dampen Magic (Shift+T) osłabia każdy tik jego klątw; Counterspell (F) na Fear albo Shadow Bolt i zabij zwierzaka. Często lepiej odejść."] =
    "The warlock is the toughest rival: Dampen Magic (Shift+T) weakens every tick of his curses; Counterspell (F) Fear or Shadow Bolt and kill the pet. Often it's better to walk away.",
  ["Czarnoksiężnik: Dampen Magic (Shift+T) na jego DoT-y, Counterspell (F) na Fear albo Shadow Bolt. Felhunter zjada buffy, długą walkę przegrasz: odpuść albo zabij szybko."] =
    "Warlock: Dampen Magic (Shift+T) against his DoTs, Counterspell (F) Fear or Shadow Bolt. The Felhunter eats buffs and you'll lose a long fight: leave or kill fast.",
  ["Kapłan: Dampen Magic (Shift+T) na Shadow Word: Pain, Counterspell (F) na leczenie, trzymaj się dalej niż 8 m (Psychic Scream). Shadow: szybki burst z Shatter."] =
    "Priest: Dampen Magic (Shift+T) against Shadow Word: Pain, Counterspell (F) on heals, stay further than 8 m (Psychic Scream). Shadow: fast burst with Shatter.",
  -- dok, zwijanie, kompas
  ["Grimuar: tempo i sesja"] = "Grimuar: pace and session",
  ["Rozwiń"] = "Expand", ["Zwiń"] = "Collapse",
  ["zioło"] = "herb", ["Zadanie do oddania"] = "Quest to turn in", ["Cel prowadzenia"] = "Guide target",
  ["Cel zadania"] = "Quest objective", ["Zbieranie"] = "Gathering", ["Przy okazji"] = "While you're here",
  -- aktualizacje addonow
  ["Addony po aktualizacji działają z Grimuarem."] = "Addons work with Grimuar after the update.",
  -- porzadki
  ["wystaw na aukcji"] = "list on the auction house", ["użyj albo załóż"] = "use or equip", ["do banku"] = "to the bank",
  ["wyrzuć"] = "destroy", ["śmieć"] = "junk", ["Wystaw na aukcji"] = "List on the auction house", ["Użyj albo załóż"] = "Use or equip",
  ["Wyrzuć"] = "Destroy", ["ulepszenie wg Pawna: załóż"] = "upgrade according to Pawn: equip", ["nie jest ulepszeniem"] = "not an upgrade",
  ["nie dla maga"] = "not for a mage", ["jedzenie z bonusem"] = "food with a buff",
  ["jedzenie i picie tworzysz sam (Conjure Food, Conjure Water)"] = "you conjure food and drink yourself (Conjure Food, Conjure Water)",
  ["zwój przydatny magowi: użyj przed walką"] = "scroll useful for a mage: use before a fight",
  ["zwój nieprzydatny magowi"] = "scroll not useful for a mage", ["do walki"] = "for combat",
  ["torba nie większa od Twoich"] = "bag not bigger than yours", ["receptura Twojej profesji: naucz się"] = "recipe for your profession: learn it",
  ["receptura już znana"] = "recipe already known", ["receptura profesji, której nie masz"] = "recipe for a profession you don't have",
  ["tkanina: Krawiectwo w planie od ok. 40"] = "cloth: Tailoring is planned from about 40",
  ["ruda: sprzedawaj od razu (ceny spadają)"] = "ore: sell right away (prices are falling)",
  ["zioła: sprzedawaj od razu (ceny spadają)"] = "herbs: sell right away (prices are falling)",
  ["materiał bez użycia w Twoich poradnikach"] = "material not used in your guides", ["nie wiem: zostawiam"] = "not sure: keeping it",
  ["narzędzie profesji"] = "profession tool", ["Profesje"] = "Professions", ["PROFESJE"] = "PROFESSIONS",
  ["u kupca jeden klik sprzedaje całą grupę"] = "at a vendor one click sells the whole group",
  ["klik w ikonę: użyj albo załóż"] = "click the icon: use or equip", ["w banku jeden klik odkłada całą grupę"] = "at the bank one click stores the whole group",
  ["klik w ikonę dwa razy: wyrzuć"] = "click the icon twice: destroy", ["sprzedają się same u kupca"] = "they sell themselves at a vendor",
  ["Grimuar ich nie ruszy"] = "Grimuar won't touch them", ["klik: użyj albo załóż"] = "click: use or equip",
  ["PPM: ★ ulubione (Grimuar go nie ruszy) · Shift+klik: link"] = "Right-click: ★ favorite (Grimuar won't touch it) · Shift+click: link",
  ["Odłóż wszystko"] = "Store everything", ["Porządki w torbach"] = "Bag cleanup", ["porządki"] = "cleanup",
  ["porządki po walce."] = "cleanup after combat.", ["Porządki"] = "Cleanup",
  -- edytor buildow, mapa
  ["Klik: wybierz czar albo makro. Prawy klik: wyczyść."] = "Click: pick a spell or macro. Right-click: clear.",
  ["Ikony jak na minimapie, w złotym pierścieniu · nazwy ważnych zawsze, kupców od przybliżenia x2"] =
    "Icons as on the minimap, in a gold ring · important names always, vendors from zoom x2",
  -- teleporty, strefy, rangi
  ["znasz teleport, ale nie masz Rune of Teleportation. Kup kilka u sprzedawcy reagentów (koło maga › „Reagenty”)."] =
    "you know a teleport but have no Rune of Teleportation. Buy a few from a reagent vendor (mage wheel › “Reagents”).",
  ["Brak run do teleportu: kup Rune of Teleportation u sprzedawcy reagentów."] = "No teleport runes: buy Rune of Teleportation from a reagent vendor.",
  ["Reagenty"] = "Reagents", ["groźna"] = "dangerous", ["łatwa"] = "easy", ["za wysoka"] = "too high", ["za niska"] = "too low",
  ["sporna"] = "contested", ["wroga"] = "hostile", ["bezpieczna"] = "sanctuary", [" (wg zadań)"] = " (by quests)",
  ["Podmień"] = "Replace", ["podmienię rangi po walce."] = "I'll replace the ranks after combat.",
}) do T[pl] = en end

for _, p in ipairs({
  { "^cofnięte: (.+)%.$", "undone: %1." },
  { "^strzałka prowadzi teraz do: (.+)%. Potem sama wróci do questów%.$", "the arrow now leads to: %1. Then it returns to the quests by itself." },
  { "^klawisz (.+) jest zajęty %((.+)%), więc go nie ruszam%. Kontrola > Napraw albo hub > Ustawienia > Klawisze przypnie go do paska buildu%.$",
    "key %1 is taken (%2), so I'm leaving it. Check > Fix or hub > Settings > Keys will bind it to the build bar." },
  { "^nowe klawisze z buildu podpięte: (%d+) %(tylko wolne klawisze%)%.$", "new build keys bound: %1 (free keys only)." },
  { "^(.+): jego miejsce na pasku %(slot (%d+)%) zajmuje (.+)%. Przeciągnij tamto gdzie indziej, a Grimuar położy czar sam%.$",
    "%1: its bar slot (%2) holds %3. Drag that elsewhere and Grimuar will place the spell by itself." },
  { "^(%d+) addon ma nowszą wersję: (.+)%. Napisz Claude'owi „aktualizuj addony”%.$", "%1 addon has a newer version: %2. Tell Claude “update addons”." },
  { "^(%d+) addony mają nowszą wersję: (.+)%. Napisz Claude'owi „aktualizuj addony”%.$", "%1 addons have a newer version: %2. Tell Claude “update addons”." },
  { "^(%d+) addonów ma nowszą wersję: (.+)%. Napisz Claude'owi „aktualizuj addony”%.$", "%1 addons have a newer version: %2. Tell Claude “update addons”." },
  { "^zaktualizowane addony: (.+)%. Sprawdzam, czy Grimuar dalej z nimi działa…$", "updated addons: %1. Checking whether Grimuar still works with them…" },
  { "^Po aktualizacji addonów: (.+) problem%(y%) z Grimuarem%. Szczegóły na czacie %(/gr test%)%.$", "After the addon update: %1 problem(s) with Grimuar. Details in chat (/gr test)." },
  { "^Porządki %((%d+)%)$", "Cleanup (%1)" },
  { "^(.+); na aukcji ok%. (.+)$", "%1; about %2 on the auction house" },
  { "^na poziom (%d+): do banku$", "for level %1: to the bank" },
  { "^większa torba %((%d+) miejsc%): załóż$", "bigger bag (%1 slots): equip" },
  { "^(.+); bez ceny u kupca$", "%1; no vendor price" },
  { "^(.+); bez ceny, zostawiam$", "%1; no price, keeping it" },
  { "^◆ potrzebne: (.+)$", "◆ needed: %1" },
  { "^(.+): ★ ulubione, Grimuar go nie ruszy%.$", "%1: ★ favorite, Grimuar won't touch it." },
  { "^kliknij jeszcze raz w ciągu 3 s, żeby wyrzucić: (.+)%.$", "click again within 3 s to destroy: %1." },
  { "^odłożone do banku: (%d+)(.*)%.$", "stored in the bank: %1%2." },
  { "^sprzedane: (%d+)(.*)%.$", "sold: %1%2." },
  { "^(%d+) rzecz do zrobienia · wolne miejsca: (%d+)$", "%1 thing to do · free slots: %2" },
  { "^(%d+) rzeczy do zrobienia · wolne miejsca: (%d+)$", "%1 things to do · free slots: %2" },
  { "^porządki: (.+)$", "cleanup: %1" },
  { "^hub: zioła i ruda Grimuara na minimapie włączone%.$", "hub: Grimuar herbs and ore on the minimap on." },
  { "^hub: zioła i ruda Grimuara na minimapie wyłączone%.$", "hub: Grimuar herbs and ore on the minimap off." },
  { "^Poziomy (.+)$", "Levels %1" },
  { "^strefa (.+) · zadania (%d+)/(%d+)$", "zone %1 · quests %2/%3" },
  { "^Poziom strefy: (.+)$", "Zone level: %1" },
  { "^Stare rangi na paskach: (%d+)$", "Old ranks on bars: %1" },
  { "^podmienione przyciski: (%d+)%.$", "buttons replaced: %1." },
  { "^nie udało się podmienić rang: (.+)$", "couldn't replace the ranks: %1" },
}) do P[#P + 1] = p end
