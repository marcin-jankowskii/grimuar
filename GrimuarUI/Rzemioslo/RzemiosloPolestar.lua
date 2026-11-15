-- Grimuar UI: poradniki profesji z Polestara w Rzemiosle (15.11, gracz: „Polestar ma tez poradniki do profesji”, „warto
-- zebys to jakos lepiej zintegrowal”). Tylko odczyt: Polestar.Guides.Get("forever/professions/<nazwa>") daje sections
-- { skill, skillLine, from, to } i steps (section, goals: train / learn / craft / collect / buy / goto / skill).
-- Pokazujemy przedzial, w ktorym jestes (poziom profesji z gry), kroki tego przedzialu jako karty (klik: Prowadz do
-- trenera, sprzedawcy albo miejsca), skladniki z liczba w torbach i dalsze przedzialy. „Otworz w Polestarze” robi to samo
-- co klik w liscie Polestara (UI.Picker.Load w nowej karcie, Twoj aktualny poradnik zostaje), tylko na Twoj klik.
-- Tez dla okienka Profesje (GrimuarSetup OknoProfesji.lua): G.psProfHint(prof, rank) -> krotka wskazowka z poradnika.
local ADDON, U = ...
local G, C = U.G, U.C

local IDS = { ["First Aid"] = "first-aid", Herbalism = "herbalism", Mining = "mining", Smelting = "mining", Skinning = "skinning",
  Alchemy = "alchemy", Blacksmithing = "blacksmithing", Cooking = "cooking", Enchanting = "enchanting",
  Engineering = "engineering", Fishing = "fishing", Leatherworking = "leatherworking", Tailoring = "tailoring" }

local function PS() return _G.Polestar end
local function have(id)
  local n = U.call(C_Item and C_Item.GetItemCount or GetItemCount, id, false)
  return U.num(n) or 0
end
local function itemIcon(id) return id and U.call(C_Item and C_Item.GetItemIconByID, id) or nil end
local function mapName(map)
  local i = map and U.call(C_Map.GetMapInfo, map)
  return type(i) == "table" and i.name or nil
end
local function myFaction() return (UnitFactionGroup("player") == "Horde") and "H" or "A" end

function U.psProfGuide(prof)
  local P = PS()
  local id = prof and IDS[prof] and ("forever/professions/" .. IDS[prof])
  if not (id and P and P.Guides and P.Guides.Get) then return nil end
  local ok, g = pcall(P.Guides.Get, id)
  if ok and type(g) == "table" and type(g.steps) == "table" then return g, id end
  return nil
end

local function sectionFor(g, rank)
  local secs = type(g.sections) == "table" and g.sections or {}
  for i, s in ipairs(secs) do
    if rank < (U.num(s.to) or 0) then return i, s end
  end
  return #secs, secs[#secs]
end

-- najblizszy kandydat (trener, sprzedawca) z Twojej frakcji
local function candidate(goal)
  for _, c in ipairs(type(goal.candidates) == "table" and goal.candidates or {}) do
    if not c.faction or c.faction == myFaction() then return c end
  end
  return nil
end

-- krok poradnika -> karta (Hub\Bloki.lua)
local function stepCard(st, rank, sec)
  local card = { title = st.title or "?" }
  local subs = {}
  for _, g in ipairs(type(st.goals) == "table" and st.goals or {}) do
    local t = g.t
    if t == "craft" then
      card.icon = card.icon or itemIcon(g.item)
      local untilS = U.num(g.untilSkill)
      if untilS then
        card.right = "do " .. untilS
        local from = U.num(sec and sec.from) or 0
        card.frac = math.max(0, math.min(1, (rank - from) / math.max(1, untilS - from)))
        card.done = rank >= untilS
      end
      local rs = {}
      for _, r in ipairs(type(g.reagents) == "table" and g.reagents or {}) do
        rs[#rs + 1] = (r.count or 1) .. "× " .. (r.itemName or ("przedmiot " .. tostring(r.item))) .. " (masz " .. have(r.item) .. ")"
      end
      if #rs > 0 then subs[#subs + 1] = table.concat(rs, ", ") end
      if g.yellow and g.grey then subs[#subs + 1] = "żółte do " .. g.yellow .. ", szare od " .. g.grey end
    elseif t == "collect" then
      card.icon = card.icon or itemIcon(g.item)
      local n, need = have(g.item), U.num(g.count) or 1
      card.right = card.right or (n .. " / " .. need)
      card.frac = card.frac or math.min(1, n / need)
      if n >= need then card.done = true end
    elseif t == "train" or t == "learn" or t == "buy" then
      local c = candidate(g)
      if c then
        subs[#subs + 1] = (t == "buy" and "sprzedawca: " or "trener: ") .. (c.npcName or "?") .. (mapName(c.map) and (", " .. mapName(c.map)) or "") .. " · klik: prowadź"
        card.go = card.go or { c.map, c.x, c.y, c.npcName or st.title }
      end
      if t == "train" and U.num(g.rankMax) and rank > 0 then
        local s = (U.call(G.readProfs) or {})[g.skill or ""]
        if s and U.num(s.max) and s.max >= g.rankMax then card.done = true end
      end
    elseif t == "goto" then
      if g.map and g.x then
        card.go = card.go or { g.map, g.x, g.y, g.text or st.title }
        subs[#subs + 1] = (g.text or mapName(g.map) or "miejsce") .. " · klik: prowadź"
      end
    elseif t == "skill" then
      local lv = U.num(g.level)
      if lv then card.right = card.right or (rank .. " / " .. lv) card.frac = card.frac or math.min(1, rank / lv) card.done = rank >= lv end
    end
  end
  if #subs > 0 then card.sub = table.concat(subs, " · ") end
  if st.note and not card.sub then card.sub = st.note end
  card.tip = st.note
  if card.go then
    local go = card.go
    card.onClick = function() if G.wayTo then G.wayTo(go[1], go[2], go[3], go[4]) end end
  end
  return card
end

function U.psOpenGuide(id)
  local P = PS()
  local Pk = P and P.UI and P.UI.Picker
  if Pk and Pk.Load then
    local ok = pcall(Pk.Load, id, true)
    if ok then return true end
  end
  U.say("nie udało się otworzyć poradnika w Polestarze.")
  return false
end

function U.psProfDraw(p, prof)
  p:Begin(p.psProf == prof)
  p.psProf = prof
  local g, id = U.psProfGuide(prof)
  if not g then
    p:Para(PS() and "Polestar nie ma poradnika tej profesji." or "Poradniki profesji są w Polestarze: włącz Polestar na liście addonów.", C.muted)
    p:End()
    return
  end
  local s = (U.call(G.readProfs) or {})[prof == "Smelting" and "Mining" or prof]
  local rank = s and U.num(s.rank) or 0
  local si, sec = sectionFor(g, rank)
  local from, to = sec and U.num(sec.from) or 0, sec and U.num(sec.to) or 0
  p:Head(rank == 0 and "Na start" or ("Teraz: " .. from .. "–" .. to), "Polestar · " .. (g.title or prof) .. " · umiejętność " .. rank)
  local cards = {}
  for _, st in ipairs(g.steps) do
    if st.section == si then cards[#cards + 1] = stepCard(st, rank, sec) end
  end
  if #cards == 0 then p:Para("Ten przedział nie ma kroków w poradniku.", C.muted, 12) end
  p:Cards(cards, { minW = 380 })
  -- dalej: kolejne przedzialy i co sie w nich robi
  local nxt = {}
  for i, sc in ipairs(type(g.sections) == "table" and g.sections or {}) do
    if i > si and #nxt < 4 then
      local what
      for _, st in ipairs(g.steps) do if st.section == i and not what then what = st.title end end
      nxt[#nxt + 1] = { title = (sc.from or "?") .. "–" .. (sc.to or "?"), sub = what, right = sc.skill }
    end
  end
  if #nxt > 0 then
    p:Head("Dalej")
    p:Cards(nxt, { minW = 260 })
  end
  p:Gap(4)
  p:Button("Otwórz w Polestarze", function() U.psOpenGuide(id) end, true)
  p:Para("Klik w kartę z trenerem, sprzedawcą albo miejscem: strzałka Polestara prowadzi. Najedź: notatka z poradnika.", C.faint, 11)
  p:End()
end

-- 15.11 (R28 P2): przedmioty potrzebne do biezacego przedzialu poradnika kazdej Twojej profesji (skladniki krokow craft
-- i przedmioty krokow collect) -> { [itemID] = "Pierwsza pomoc 40–50: Heavy Linen Bandage (potrzeba 41)" } dla plecaka
-- (GrimuarSetup PlecakPlus.lua: znaczek ◆, bez smieci i bez odkladania do banku)
local function neededItems()
  local out = {}
  local profs = U.call(G.readProfs) or {}
  for prof in pairs(IDS) do
    local s = profs[prof]
    local g = s and U.psProfGuide(prof)
    if g then
      local rank = U.num(s.rank) or 0
      local si, sec = sectionFor(g, rank)
      local range = sec and ((sec.from or "?") .. "–" .. (sec.to or "?")) or ""
      for _, st in ipairs(g.steps) do
        if st.section == si then
          for _, goal in ipairs(type(st.goals) == "table" and st.goals or {}) do
            if goal.t == "craft" and not (U.num(goal.untilSkill) and rank >= goal.untilSkill) then
              for _, r in ipairs(type(goal.reagents) == "table" and goal.reagents or {}) do
                if r.item and not out[r.item] then out[r.item] = prof .. " " .. range .. ": " .. (st.title or "?") end
              end
            elseif goal.t == "collect" and goal.item and not out[goal.item] then
              out[goal.item] = prof .. " " .. range .. ": zbierz " .. (U.num(goal.count) or 1)
            end
          end
        end
      end
    end
  end
  return out
end

-- krotka wskazowka do okienka Profesje (GrimuarSetup): pierwszy niezrobiony krok przedzialu
if G then
  G.psNeededItems = neededItems
  G.psProfHint = function(prof, rank)
    local g = U.psProfGuide(prof)
    if not g then return nil end
    rank = U.num(rank) or 0
    local si, sec = sectionFor(g, rank)
    for _, st in ipairs(g.steps) do
      if st.section == si then
        local c = stepCard(st, rank, sec)
        if not c.done then return "Polestar: " .. (c.title or "?") .. (c.right and (" (" .. c.right .. ")") or "") end
      end
    end
    return nil
  end
end
