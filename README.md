# Grimuar

UI for **World of Warcraft: Forever** (client 1.60.1, Interface 16001): a Witcher-style hub, a HUD and step-by-step
guidance, built around **builds** you can create, edit and share. Language: Polish or English (pick it in the
first-run wizard or with `/gr jezyk en`).

Dwa addony / two addons:

| Folder | What it does |
|---|---|
| `GrimuarSetup` | game settings (only with your consent), action bars and macros from your build, trainer helper, reminders, guidance bar, Grimuar window (`/gr`, Shift+G) |
| `GrimuarUI` | full-screen hub (`` ` `` key or `/hub`): Character, **Builds**, Spells, Journal, Map, Codex, Crafting, Social, Expeditions, Achievements, Chronicle, Grimuar; compass and target HUD |

## Install
1. Copy `GrimuarSetup` and `GrimuarUI` into `World of Warcraft\_forever_\Interface\AddOns\`.
2. Recommended: Polestar (guides, talent plans for all 9 classes), Questie, Pawn, Baganator, Masque, WeakAuras.
3. Log in: the wizard asks for language, build and what Grimuar may change. Nothing is changed without a tick.

## Builds
- Built-in: Frost Mage (leveling and PvP). Every class gets **drafts from Polestar's talent plans**.
- Hub > **Builds**: set active, **duplicate to edit** (works for Polestar drafts too), edit the talent order,
  "Save my talents", "Record" (each talent point you spend is appended), export and import a **build code**.
- A build code looks like `!GRB1!<checksum>!<base64>`. It is data only: no code is ever run, macros with
  `/run` or `/script` are refused. Format: `docs/BUILD_FORMAT.md`.

## Commands
`/gr` window · `/gr build` list and pick a build · `/gr kreator` wizard · `/gr jezyk pl|en|brak` · `/gr test` self-test ·
`/hub` hub · `/hub kolo` utility wheel · `/hub dziel` share quests with the group · `/hub bledy` error log.

## License
GPL-3.0 (see `GrimuarSetup/LICENSE`). Alegreya fonts: SIL Open Font License 1.1 (`GrimuarSetup/Media/OFL-Alegreya.txt`).
Grimuar is a fan addon, not affiliated with Blizzard Entertainment. It is free and must stay free (Blizzard UI add-on policy).

---

## Po polsku
Grimuar to UI dla WoW Forever: hub jak w Wiedźminie, HUD i prowadzenie krok po kroku, oparte na **buildach**.
Każdy gracz dodaje swój build: wbudowany mag Frost, szkice z planów talentów Polestara dla każdej klasy, edycja
(także kopii buildów Polestara), kod buildu do wysłania znajomym. Przy pierwszym uruchomieniu kreator pyta o język,
build i zgody na zmiany w grze. Komendy jak wyżej, licencja GPL-3.0.
