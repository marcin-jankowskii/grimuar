-- Grimuar UI: podglad buildu w kartach (15.11, gracz: „tutaj jakos in game powinna byc mozliwosc przerabiania
-- i edytowania buildow”; wczesniej podglad byl jednym tekstem). Sekcje: talenty (ikony z Polestara), trener (zetony
-- kupuj / AoE / pomin), paski akcji (12 slotow z ikona i klawiszem), combo i ratunek, PvP, stwory, kolo, makra,
-- statystyki. Kazda sekcja ma „Edytuj” (U.buildEditorOpen(id, sekcja)); wbudowany build i szkic Polestara: „Edytuj kopie”
-- (najpierw kopia w „Moje”, TabBuildy.lua). Wspolne pomocnicze dla edytora: U.bIcon, U.bKey, U.bBindFor, U.CLASS_PL.
local ADDON, U = ...
local C = U.C
local G = U.G or {}

U.CLASS_PL = { WARRIOR = "Wojownik", PALADIN = "Paladyn", HUNTER = "Łowca", ROGUE = "Łotrzyk", PRIEST = "Kapłan",
  SHAMAN = "Szaman", MAGE = "Mag", WARLOCK = "Czarnoksiężnik", DRUID = "Druid" }
U.CREATURE_PL = { Humanoid = "Humanoidy", Beast = "Bestie", Undead = "Nieumarli", Elemental = "Żywiołaki", Demon = "Demony",
  Dragonkin = "Smoki", Giant = "Olbrzymy", Mechanical = "Mechaniczne", Critter = "Zwierzątka" }
local ROLE_PL = { DAMAGER = "obrażenia", TANK = "tank", HEALER = "leczenie" }
-- paski: zakres slotow i komenda klawisza (Core.lua uklada: 1–12, 61–72, 49–60)
U.BAR_DEF = {
  { key = "main", title = "Pasek 1", from = 1, bind = "ACTIONBUTTON" },
  { key = "bar2", title = "Pasek 2 (dolny lewy)", from = 61, bind = "MULTIACTIONBAR1BUTTON" },
  { key = "bar3", title = "Pasek 3 (dolny prawy)", from = 49, bind = "MULTIACTIONBAR2BUTTON" },
}

local function bt(v) return G.BT and G.BT(v) or (type(v) == "table" and (v.pl or v.en) or v) end
U.bt = bt

-- ikona czaru po nazwie albo „macro:Nazwa” (makro z gry, gdy istnieje)
function U.bIcon(name)
  if type(name) == "table" then name = name[1] end
  if type(name) ~= "string" then return nil end
  local m = name:match("^macro:(.+)$")
  if m then
    local idx = U.call(GetMacroIndexByName, m)
    if idx and idx > 0 then
      local _, icon = U.call(GetMacroInfo, idx)
      if icon then return icon end
    end
    return "Interface\\Icons\\INV_Misc_Note_01"
  end
  local t = C_Spell and C_Spell.GetSpellTexture and U.call(C_Spell.GetSpellTexture, name)
  if t then return t end
  return U.call(GetSpellTexture, name)
end
local function spellId(name)
  if type(name) ~= "string" or name:find("^macro:") then return nil end
  if C_Spell and C_Spell.GetSpellInfo then
    local i = U.call(C_Spell.GetSpellInfo, name)
    return type(i) == "table" and U.num(i.spellID) or nil
  end
  return nil
end
U.bSpellId = spellId
-- klawisz komendy (np. MULTIACTIONBAR1BUTTON2 -> „Shift+Q”)
function U.bKey(bind)
  if type(bind) ~= "string" then return nil end
  local k = U.call(GetBindingKey, bind)
  if type(k) ~= "string" or k == "" then return nil end
  return (k:gsub("SHIFT%-", "Shift+"):gsub("CTRL%-", "Ctrl+"):gsub("ALT%-", "Alt+"))
end
-- komenda klawisza dla czaru z paskow buildu (combo bierze klawisz z paska)
function U.bBindFor(b, name)
  for _, d in ipairs(U.BAR_DEF) do
    for slot, alts in pairs((b.bars or {})[d.key] or {}) do
      for _, a in ipairs(type(alts) == "table" and alts or { alts }) do
        if a == name or a == ("macro:" .. tostring(name)) then return d.bind .. (slot - d.from + 1) end
      end
    end
  end
  return nil
end

-- talent -> ikona (Polestar: nodes[id] = { entry, maxRank, spell, tree, row, col, name })
local function talentIcons(cls)
  local T = _G.Polestar and _G.Polestar.Talents
  local out = {}
  if not (T and T.Data) then return out end
  local ok, d = pcall(T.Data, cls)
  if not ok or type(d) ~= "table" then return out end
  for _, n in pairs(d.nodes or {}) do
    if n[7] and n[3] then out[n[7]] = { icon = U.call(C_Spell.GetSpellTexture, n[3]), id = n[3] } end
  end
  return out
end

function U.buildPlanOf(b)
  if b.talents and b.talents.plan and #b.talents.plan > 0 then return b.talents.plan end
  if G.picksToPlan and b.talents and b.talents.picks then return G.picksToPlan(b.class, b.talents.picks) or {} end
  return {}
end

function U.buildPreviewDraw(p, b, onEdit)
  p:Begin(p.prevId == (b and b.id))
  p.prevId = b and b.id
  if not b then p:Para("Wybierz build z listy.", C.muted) p:End() return end
  local own = b.src == "moje" or b.src == "import"
  local lbl = own and "Edytuj" or "Edytuj kopię"
  local function edit(sec) return function() if onEdit then onEdit(b.id, sec) end end end
  p:Title(bt(b.name) or b.id, (U.CLASS_PL[b.class or ""] or b.class or "?") .. (b.role and (" · " .. (ROLE_PL[b.role] or b.role)) or "") ..
    " · autor: " .. (bt(b.author) or "anonim") .. " · wersja " .. tostring(b.version or 1) .. (b.license and (" · " .. b.license) or ""))
  if b.desc then p:Para(bt(b.desc), C.text, 13) end
  if b.sources then p:Para("Źródła: " .. table.concat(b.sources, ", "), C.faint, 11) end
  if not own then p:Para("To build " .. (b.src == "polestar" and "z Polestara" or "wbudowany") .. ": „Edytuj kopię” robi Twoją kopię w „Moje” i otwiera ją w edytorze.", C.faint, 11) end

  -- talenty
  local plan = U.buildPlanOf(b)
  local pts = 0
  for _, x in ipairs(plan) do pts = pts + (x[3] - x[2] + 1) end
  p:Head("Talenty", #plan > 0 and (pts .. " pkt · " .. #plan .. " kroków") or "brak planu", lbl, edit("talenty"))
  local icons = talentIcons(b.class)
  local cards = {}
  for _, x in ipairs(plan) do
    local ic = icons[x[1]]
    cards[#cards + 1] = { title = x[1], right = (x[2] == x[3]) and ("poz. " .. x[2]) or ("poz. " .. x[2] .. "–" .. x[3]), icon = ic and ic.icon }
  end
  p:Cards(cards, { minW = 230 })

  -- trener
  local tr = b.trainer or {}
  local chips, nk, ns = {}, 0, 0
  local function names(t)
    local out = {}
    for k, v in pairs(t or {}) do out[#out + 1] = type(k) == "number" and tostring(v) or k end
    table.sort(out)
    return out
  end
  for _, n in ipairs(names(tr.keep)) do chips[#chips + 1] = { text = n, col = C.ok, tip = "kupuje" } nk = nk + 1 end
  for _, n in ipairs(names(tr.aoe)) do chips[#chips + 1] = { text = n, col = C.frost, tip = "tylko z włączonym AoE" } end
  for _, n in ipairs(names(tr.skip)) do chips[#chips + 1] = { text = n, col = C.faint, tip = "pomija: " .. tostring(bt(tr.skip[n]) or "") } ns = ns + 1 end
  p:Head("Trener", tr.all and "kupuje wszystko" or (nk .. " kupuje · " .. ns .. " pomija · AoE " .. (tr.aoeOn and "tak" or "nie")), lbl, edit("trener"))
  if tr.all then p:Para("Kupuje wszystko, co trener ma (jak „Train All”).", C.muted, 12) end
  p:Chips(chips)

  -- paski
  local bars = b.bars or {}
  local any = false
  for _, d in ipairs(U.BAR_DEF) do if next(bars[d.key] or {}) then any = true end end
  p:Head("Paski akcji", any and "klawisz pod ikoną, najedź: zamienniki" or "brak", lbl, edit("paski"))
  for _, d in ipairs(U.BAR_DEF) do
    local bar = bars[d.key]
    if bar and next(bar) then
      p:Para(d.title, C.faint, 11)
      local slots = {}
      for i = 1, 12 do
        local alts = bar[d.from + i - 1]
        local first = type(alts) == "table" and alts[1] or alts
        local key = U.bKey(d.bind .. i) or tostring(i)
        if first then
          local tip = table.concat(type(alts) == "table" and alts or { alts }, " albo ")
          slots[#slots + 1] = { icon = U.bIcon(first), label = key, tip = tip, spellId = spellId(first) }
        else
          slots[#slots + 1] = { empty = true, label = key }
        end
      end
      p:Slots(slots, { size = 40 })
    end
  end

  -- combo i ratunek
  local co = b.combo or {}
  local function stepCards(list)
    local out = {}
    for i, s in ipairs(list or {}) do
      out[#out + 1] = { title = i .. ". " .. (s.spell or bt(s.text) or "?"), sub = bt(s.hint), right = U.bKey(s.bind) or (s.bind and "bez klawisza") or nil,
        icon = s.spell and U.bIcon(s.spell) or nil, tip = s.need and ("gdy masz: " .. s.need) or nil }
    end
    return out
  end
  p:Head("Combo", #(co.steps or {}) .. " kroków", lbl, edit("combo"))
  p:Cards(stepCards(co.steps), { minW = 340 })
  if co.rescue and #co.rescue > 0 then
    p:Head("Ratunek", #co.rescue .. " kroków")
    p:Cards(stepCards(co.rescue), { minW = 340 })
  end

  -- PvP (pasmo wg poziomu) i stwory
  local lvl = UnitLevel("player") or 1
  local pv = b.pvp or {}
  local band = (lvl >= 40 and pv[40]) or pv[1] or {}
  local pc = {}
  for _, cls in ipairs({ "WARRIOR", "ROGUE", "HUNTER", "MAGE", "WARLOCK", "PRIEST", "DRUID", "PALADIN", "SHAMAN" }) do
    if band[cls] then pc[#pc + 1] = { title = U.CLASS_PL[cls], sub = bt(band[cls]), tip = bt(band[cls]) } end
  end
  p:Head("PvP: porady na klasy", #pc > 0 and ((lvl >= 40 and pv[40]) and "od 40 poziomu" or "do 39 poziomu") or "brak", lbl, edit("porady"))
  p:Cards(pc, { minW = 360 })
  local cr = {}
  for k, v in pairs(b.creatures or {}) do cr[#cr + 1] = { title = U.CREATURE_PL[k] or k, sub = bt(v), tip = bt(v) } end
  table.sort(cr, function(a, c) return a.title < c.title end)
  if #cr > 0 then
    p:Head("Stwory", #cr .. " typów")
    p:Cards(cr, { minW = 360 })
  end

  -- kolo
  local wl = {}
  for _, w in ipairs(b.wheel or {}) do
    local first = type(w[1]) == "table" and w[1][1] or w[1]
    wl[#wl + 1] = { icon = U.bIcon(first), label = w[2] or first, tip = type(w[1]) == "table" and table.concat(w[1], " albo ") or first, spellId = spellId(first) }
  end
  p:Head("Koło szybkiego wyboru", #wl > 0 and (#wl .. " pozycji") or "brak", lbl, edit("kolo"))
  p:Slots(wl, { size = 40 })

  -- makra
  local mc = {}
  for _, m in ipairs(b.macros or {}) do
    local body = type(m[2]) == "table" and table.concat(m[2], "\n") or tostring(m[2] or "")
    mc[#mc + 1] = { title = m[1], sub = (body:gsub("\n", "  ·  ")), tip = body, icon = U.bIcon("macro:" .. tostring(m[1])) }
  end
  p:Head("Makra", #mc > 0 and (#mc .. " makr") or "brak", lbl, edit("makra"))
  p:Cards(mc, { minW = 360 })

  if b.stats then
    p:Head("Statystyki")
    p:Para("Pawn: " .. tostring(b.stats.pawn or b.stats.from or "?") .. ". Przycisk „Skala Pawn z buildu” po prawej ustawia ją w Pawnie.", C.text, 12)
  end
  p:End()
end
