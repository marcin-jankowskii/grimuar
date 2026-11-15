# Grimuar build format (schema 1)

A build is a Lua table of **data**. Built-in builds call `G.RegisterBuild{...}` in `GrimuarSetup/Buildy/*.lua`;
imported and own builds live in `GrimuarSetupDB.builds`. Every import goes through `G.CleanBuild`
(`GrimuarSetup/Build/Walidacja.lua`): whitelisted keys only, size limits, texts with `|` doubled, macros without
`/run`, `/script`, `/console`, `/dump`. Nothing from a build is ever executed.

## Code
```
!GRB1!<Adler-32 of JSON, 8 hex>!<base64 of zlib(JSON)>     -- C_EncodingUtil
!GRB0!<JSON>                                              -- fallback, plain JSON
```
Sparse numeric keys are written as `"#61"`. Limits: code 64 000 chars, JSON 128 KB, depth 8, 400 items per list.

## Fields (all optional except the metadata)
| Field | Content |
|---|---|
| `schema`, `id`, `version`, `updated` | format version (1), `author/name` id, author's version, date |
| `name`, `desc`, `author`, `license`, `sources` | text or `{ pl = "...", en = "..." }` |
| `class`, `spec`, `role`, `levels` | `"MAGE"`… (required), tree 1–3, `DAMAGER`/`TANK`/`HEALER`, `{ from, to }` |
| `talents` | `plan = { { "Talent", fromLevel, toLevel, maxRank } }`, `notes = { ["Talent"] = text }`, or `picks = { { nodeID, rank } }` (Polestar style), `from = "polestar:<key>"` |
| `trainer` | `list = { { level, "Spell", note } }`, `keep` (list or map of spell names), `aoe`, `skip = { ["Spell"] = reason }`, `all = true`, `aoeOn` |
| `bars` | `main = { [1] = { "Spell", "fallback" } }`, `bar2 = { [61] = { "macro:Name" } }`, `bar3 = { [49] = ... }` |
| `macros`, `macroNeeds` | `{ { "Name", "body" } }`, `{ Name = "Spell it needs" }` |
| `keys` | `{ { "Q", "MULTIACTIONBAR1BUTTON1" } }` (applied only with consent) |
| `combo` | `steps` and `rescue`: `{ spell = "...", bind = "ACTIONBUTTON1", hint = text, need = "Spell" }` or `{ text = ... }` |
| `pvp` | `[1] = { WARRIOR = text, ... }`, `[40] = { ... }` (advice by enemy class and level band) |
| `creatures` | `{ Humanoid = text, Beast = text, ... }` |
| `wheel` | `{ { "Spell" or { "Rank 3 name", "Rank 2 name" }, "label" } }` |
| `group` | `give = { itemID, ... }`, `buffs`, `dispel`, `cc` |
| `buffs`, `consumables`, `stats`, `route`, `professions` | reminders `{ any = { "Spell" }, key, msg }`, conjure/food, Pawn scale, side quests, profession plan |

Example: `GrimuarSetup/Buildy/Mag_Frost.lua` (full Frost Mage build).
