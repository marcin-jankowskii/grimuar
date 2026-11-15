# Changelog

## GrimuarSetup 5.7.0 · GrimuarUI 0.16.0 (2026-11-15)
- **Game windows in the hub style** (plan R29): Merchant (goods "for your build" with reasons and "you have N",
  buyback, repair all, bag with right-click sell; junk sells itself when the merchant opens, with one chat line),
  Trainer (buy by build with total, skipped spells with the build's reason, later by level), Mailbox (inbox with
  open / take / take all / delete, send with money and attachments from the bag), Bank (bank and bag side by side,
  right-click moves, deposit materials, sort). Shared shell `Okna/Wspolne.lua`: our window covers the game's or
  ForeverSkin's window, which keeps only alpha 0; "classic window" for one visit, `/hub okna <name>` to switch off.
- **Settings as a full-screen hub tab** (Esc > Settings, Key Bindings and Macros open it): Polish pages Controls, Camera,
  Combat, Interface, Graphics, Sound (CVars, out of combat), Grimuar (all Grimuar toggles), Key Bindings (two keys per
  command, change by pressing a key incl. mouse buttons and wheel, clear), Macros (edit, new account / character macro,
  delete, put on bar); search across all pages; "Full game settings" and Edit Mode buttons. "Grimuar" badge on options
  Grimuar sets.
- Hub tab bar scales down a little when 15 tabs do not fit.

## GrimuarSetup 5.6.0 · GrimuarUI 0.15.0 (2026-11-15)
- **Polestar integration** (read-only): Crafting gets a "Polestar guide" view (profession guide steps for your skill,
  reagents with bag counts, click a trainer, vendor or spot to get the arrow, "Open in Polestar" in a new tab);
  the Professions box falls back to the guide's next step. Expeditions show the dungeon's loading-screen art,
  "best at" level, Forever tag and an "Open in Polestar" button.
- **Block panel** (`Hub\Bloki.lua`): headers, cards with progress bars, stat tiles, item icon grid with tooltips,
  calendar events. Used by Expeditions > Loot (icons, Pawn upgrade arrow), Chronicle > Week and Calendar.
- Money with coin icons and without zero parts; contract texts recomputed live.
- Defaults changed after play-testing: Runy health/mana arcs back (bars only via `/hub paski`), minimap always visible
  (`/hub minimapa-tryb` to fade it), compass stays in combat and dungeons, Professions box stays in a party;
  `/profesje` opens the professions page (`/profesje ukryj` hides the box) and the box comes back once.
- Fix: full-screen Esc menu never showed (SetText before SetFont, "Font not set"); errors now go to chat once.
- **In-game build editing for every section**: the Builds page is a card view (talent icons, trainer chips, action bar
  slots with keys, combo, PvP and creature tips, wheel, macros) with "Edit" per section. "Edit" works on any build:
  built-in and Polestar drafts are copied to "My builds" first. Editor tabs: Talents, Trainer (buy / AoE only / skip
  per spell, buy all, AoE), Bars (click a slot, any spell or macro, also not yet learned; "Take bars from the game"),
  Combo and Rescue (keys come from the bars), Wheel, Macros (no /run etc.), Tips (PvP below/above 40, creatures).
  Edits happen on a working copy; nothing changes until Save.
- **NPC dialogue window** in the hub style (quests and gossip): parchment text, choices 1–9, quest rewards as cards with
  the best one marked (Pawn upgrade for the build, else highest vendor price), quest level, Polestar step; the game's
  window stays underneath at alpha 0 and fully covered; "classic window", `/hub rozmowa`.
- **Inventory** (research R28): Bag+ on Baganator's API (groups v4: Combat, Quests, Upgrades, Gear, Cooking, Cloth,
  Herbs & ore, Recipes, Materials, Junk; ◆ needed by the Polestar profession guide, ★ favourite, Grimuar junk plugin,
  bottom bar Sell junk / Deposit materials / Compact / In hub, Alt+right-click marks, Polish "Other"/"Empty"),
  quick belt in the HUD (drink, food, bandage, potion, hearthstone, "enough for about N fights", `/hub pas`) and a new hub
  tab **Ekwipunek** (paper doll with stat deltas, grid with filters or a sortable list across bags, bank and other
  characters via Syndicator, item card with comparison, where else, Equip / Favourite / Junk / Link).
- Private only: ForeverSkin palette patch support (window colours and titles in Grimuar style; reminder when an update
  removes the patch).

## GrimuarSetup 5.5.0 · GrimuarUI 0.14.0 (2026-11-14)
- **News tab** (hub > News): Grimuar changes by version and WoW Forever patch notes with dates and sources;
  filter **For my build** (class, role, level, active build's spells and talents; "Later" section).
- Content for every class and race: old window pages from the active build, neutral plan stages, tutorial without mage-only steps.
- English: about 1,750 strings (interface and the longer texts: tutorial, tips, plan). `/gr jezyk en` + `/reload`.
- Short commands also as `/gr <name>`; not registered in the public version (no clashes with other add-ons).
- Files sorted into feature folders (load order unchanged).

## GrimuarSetup 5.4.0 · GrimuarUI 0.13.0 (2026-11-14)
- **Builds for everyone** (R27 E1–E6): Frost Mage build in one data file; build API with per-character active build;
  drafts from Polestar's talent plans for all classes; hub page Builds with preview, duplicate-to-edit (Polestar
  drafts too), talent order editor, "Save my talents", recording, export and import (`!GRB1!` codes, data only).
- First-run wizard with language, build and separate consents instead of changing settings silently.
- Modules no longer assume a mage: trainer button follows the build, combo title, buff reminders, wheel,
  class and faction masks, role texts.
- Public version vs private add-on `Grimuar_Osobiste`; anonymized comments; GPL-3.0 license.
- Translation layer and English dictionary for the most visible texts (`/gr jezyk en`).
- Earlier the same day: Expeditions tab (dungeons, evening planner, party sync between Grimuar users), Chronicle,
  Codex, compass, combat target HUD, left notification column, horizontal health and mana bars.
