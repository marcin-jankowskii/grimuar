-- Grimuar: modul Profesje (prosba gracza 13.11, dane z researchu R13: gaming-warsztat/wow/research/R13-profesje-2611.md).
-- Czyta poziomy profesji z gry i przypomina: trener przed limitem, bandaze z tkanin w torbie, mikstury z ziol (w Forever
-- robi je First Aid), zbieranie gdy profesja zostaje w tyle, na 40-42 Mining -> Tailoring. Wstega przy limicie.
-- Okno: Postac > Moje profesje. Dane z bety lub sprzeczne zrodla oznaczone (?).
local ADDON_NAME, G = ...
local say = G.say

-- Nazwy linii umiejetnosci w kliencie (angielski)
local PROFS = {
  { key = "herbalism", name = "Herbalism", pl = "Herbalism (zielarstwo)" },
  { key = "mining", name = "Mining", pl = "Mining (górnictwo)" },
  { key = "firstaid", name = "First Aid", pl = "First Aid (bandaże i mikstury)" },
  { key = "cooking", name = "Cooking", pl = "Cooking (ognisko i jedzenie)" },
  { key = "fishing", name = "Fishing", pl = "Fishing (do 20 dla Fish Bowl)" },
  { key = "tailoring", name = "Tailoring", pl = "Tailoring (od 40–42)" },
}

-- { od, do, poziom postaci, co robic, gdzie }
local BANDS = {
  firstaid = {
    { 1, 20, "7–10", "Linen Bandage (1 Linen) do 20", "Dun Morogh, Loch Modan (humanoidy dają tkaninę)" },
    { 20, 40, "8–12", "Linen Bandage dalej, do 40 (wtedy Heavy Linen); First Aid Kit do ogniska już możesz robić, nie musisz", "Dun Morogh, Loch Modan (humanoidy dają tkaninę)" },
    { 40, 80, "10–16", "Heavy Linen Bandage (2 Linen); na 50 Journeyman: Thamner Pol w Kharanos", "Loch Modan, Westfall, Redridge" },
    { 80, 115, "16–22", "Wool Bandage (1 Wool); z ziół Lesser Healing Potion od 85 (Briarthorn)", "Wetlands, Redridge, Duskwood" },
    { 115, 150, "20–28", "Heavy Wool Bandage (2 Wool); na 125 kup na AH książkę Expert First Aid - Under Wraps; Healing Potion od 135", "Wetlands, Hillsbrad" },
    { 150, 210, "28–40", "Silk Bandage (trener, 150), potem Heavy Silk (manual, 180); Greater Healing Potion od 155", "Arathi, Stranglethorn, Hillsbrad, Desolace" },
    { 210, 240, "40–45", "Mageweave Bandage; na 225 i 35 poziomie quest Triage w Theramore", "Riverglades, Dustwallow, Badlands" },
    { 240, 300, "45–60", "Heavy Mageweave, Runecloth (260), Heavy Runecloth (290); Major Healing Potion od 275", "Tanaris, Feralas, Plaguelands, Winterspring" },
  },
  herbalism = {
    { 1, 50, "7–12", "Peacebloom, Silverleaf, Earthroot", "Dun Morogh, Loch Modan" },
    { 50, 100, "12–20", "Mageroyal (50), Briarthorn (70), Stranglekelp (85)", "Loch Modan, Westfall, Redridge, Duskwood" },
    { 100, 150, "18–28", "Bruiseweed, Wild Steelbloom, Grave Moss, Kingsblood (125)", "Wetlands, Duskwood, Hillsbrad" },
    { 150, 205, "28–38", "Liferoot, Fadeleaf, Goldthorn, Khadgar's Whisker, Wintersbite", "Arathi, Stranglethorn, Alterac, Swamp of Sorrows" },
    { 205, 250, "38–48", "Firebloom, Purple Lotus, Sungrass, Ghost Mushroom", "Badlands, Tanaris, Hinterlands, Feralas" },
    { 250, 300, "48–60", "Gromsblood, Golden Sansam, Dreamfoil, Mountain Silversage, Plaguebloom, Icecap: trzymaj na raidy", "Felwood, Un'Goro, Plaguelands, Winterspring" },
  },
  mining = {
    { 1, 65, "7–14", "Copper; przetapiaj Copper w Kharanos (skill za przetapianie)", "Dun Morogh, Loch Modan" },
    { 65, 125, "14–25", "Tin i Silver; przetapiaj Tin i Bronze do ok. 105", "Wetlands, Loch Modan, Redridge, Duskwood" },
    { 125, 175, "25–35", "Iron i Gold; przetapiaj Iron do ok. 135", "Arathi, Hillsbrad, Alterac, Stranglethorn" },
    { 175, 230, "35–42", "Mithril; na 40–42 rzuć Mining i weź Tailoring", "Badlands, Stranglethorn, Alterac" },
  },
  cooking = {
    { 1, 50, "7–14", "Spiced lub Charred Wolf Meat, Roasted Boar Meat, Peace Tea; ognisko: Simple Wood i Flint and Tinder", "Dun Morogh, Loch Modan" },
    { 50, 100, "12–20", "Smoked Bear Meat, Loch Frenzy Delight, Coyote Steak, Crocolisk Steak", "Loch Modan, Wetlands, Redridge" },
    { 100, 150, "20–30", "opcjonalnie: Redridge Goulash, Seasoned Wolf Kabob, Crocolisk Gumbo; tu skończ", "Redridge, Wetlands, Duskwood" },
  },
  fishing = {
    { 1, 20, "teraz", "łów do 20: obiekt Fish Bowl przy ognisku daje +8% wszystkich statystyk", "Iceflow Lake w Dun Morogh (trener Paxton Ganter)" },
    { 20, 301, "—", "cel osiągnięty: Fish Bowl przy ognisku działa, dalej łowić nie musisz", "—" },
  },
  tailoring = {
    { 1, 150, "40–42", "z Linen i Wool z banku (Legacy za 150); na 125 Expert u Georgio Bolero (Stormwind)", "Ironforge (Uthrar Threx), Stormwind" },
    { 150, 205, "40–45", "Silk i Mageweave; na 200 Artisan u Timothy Worthingtona w Theramore; ACA Friendly: Netherfroth", "Theramore, Three Corners" },
    { 205, 300, "45–60", "Runecloth (od 50); 295 Robe of the Archmage (wzór z LBRS); Legacy za 225 i 300", "okno: Postać > Do 60 i raidy" },
  },
}

-- Nastepna ranga wg obecnego limitu: { ranga, minimalny skill, minimalny poziom postaci, trener }
local RANKS = {
  herbalism = { [75] = { "Journeyman", 50, 1, "Reyna Stonebranch (Ironforge 55.6, 58.0) albo Kali Healtouch (Thelsamar), 5 s" },
                [150] = { "Expert", 125, 10, "ci sami trenerzy, 50 s (poziom 10 albo 20, źródła się różnią)" },
                [225] = { "Artisan", 200, 25, "ci sami albo Brant Jasperbloom (Theramore), 5 g (poziom 25 albo 35)" } },
  mining = { [75] = { "Journeyman", 50, 1, "Yarr Hammerstone (Dun Morogh 50.0, 50.4) albo Geofram Bouldertoe (Ironforge), 5 s" },
             [150] = { "Expert", 125, 10, "ci sami trenerzy, 50 s" },
             [225] = { "Artisan", 200, 25, "ci sami trenerzy, 5 g" } },
  firstaid = { [75] = { "Journeyman", 50, 10, "Thamner Pol (Kharanos 47.2, 52.6) albo Nissa Firestone (Ironforge)" },
               [150] = { "Expert", 125, 20, "książka Expert First Aid - Under Wraps: dom aukcyjny albo Deneb Walker (Arathi), ok. 1 g" },
               [225] = { "Artisan", 225, 35, "quest Triage: Doctor Gustaf VanHowzen (Theramore 67.5, 48.8)" } },
  cooking = { [75] = { "Journeyman", 50, 1, "Gremlock Pilsnor (Kharanos) albo Daryl Riknussun (Ironforge)" },
              [150] = { "Expert", 125, 20, "Expert Cookbook z domu aukcyjnego" } },
  fishing = { [75] = { "Journeyman", 50, 1, "Paxton Ganter (Iceflow Lake) albo Grimnur Stonebrand (Ironforge)" } },
  tailoring = { [75] = { "Journeyman", 50, 10, "Uthrar Threx (Ironforge)" }, [150] = { "Expert", 125, 20, "Georgio Bolero (Stormwind)" },
                [225] = { "Artisan", 200, 35, "Timothy Worthington (Theramore)" } },
}

-- Tkaniny na bandaze: { od skilla, do skilla, ID tkaniny, ile na bandaz, nazwa bandaza }
local CLOTH = {
  { 1, 40, 2589, 1, "Linen Bandage" }, { 40, 80, 2589, 2, "Heavy Linen Bandage" },
  { 80, 115, 2592, 1, "Wool Bandage" }, { 115, 150, 2592, 2, "Heavy Wool Bandage" },
  { 150, 210, 4306, 1, "Silk Bandage" }, { 210, 240, 4338, 1, "Mageweave Bandage" }, { 240, 300, 14047, 2, "Runecloth Bandage" },
}
-- Ziola na mikstury leczenia (First Aid w Forever): { ID, od skilla First Aid, mikstura }
local POTION_HERBS = {
  [2447] = { 55, "Minor Healing Potion" }, [2450] = { 85, "Lesser Healing Potion" },
  [2453] = { 135, "Healing Potion" }, [3357] = { 155, "Greater Healing Potion" },
}

local function readProfs()
  local out = {}
  pcall(function()
    local n = GetNumSkillLines and GetNumSkillLines() or 0
    for i = 1, n do
      local name, isHeader, _, rank, _, _, max = GetSkillLineInfo(i)
      if name and not isHeader and rank then out[name] = { rank = rank, max = max or 0 } end
    end
  end)
  if next(out) == nil then
    pcall(function()
      local t = { GetProfessions() }
      for i = 1, 6 do
        local idx = t[i]
        if idx then
          local name, _, rank, max = GetProfessionInfo(idx)
          if name then out[name] = { rank = rank, max = max or 0 } end
        end
      end
    end)
  end
  return out
end

local function bandOf(key, rank)
  for _, b in ipairs(BANDS[key] or {}) do
    if rank >= b[1] and rank < b[2] then return b end
  end
  local list = BANDS[key] or {}
  return list[#list]
end

local function count(id)
  local n = 0
  pcall(function() n = (C_Item and C_Item.GetItemCount or GetItemCount)(id, false) or 0 end)
  return n
end

local function itemName(id)
  local nm
  pcall(function() nm = C_Item.GetItemNameByID(id) end)
  return nm
end

-- Lista przypomnien: { key, text, why, prio } (prio 1 = najpilniejsze)
local function reminders()
  local l = UnitLevel("player") or 1
  local p = readProfs()
  local out = {}
  local function add(key, text, why, prio, btn) out[#out + 1] = { key = key, text = text, why = why, prio = prio, btn = btn } end
  -- co kraftowac z okna profesji (Kraft.lua, 13.11)
  if G.kraftItems then for _, it in ipairs(G.kraftItems()) do add(it.key, it.text, it.why, it.prio) end end
  for _, pr in ipairs(PROFS) do
    local s = p[pr.name]
    if s and s.max and s.max > 0 and s.max < 300 then
      local nxt = RANKS[pr.key] and RANKS[pr.key][s.max]
      if nxt then
        if s.rank >= nxt[2] and l >= nxt[3] then
          add("prof-tr-" .. pr.key, pr.name .. " " .. s.rank .. "/" .. s.max .. ": idź po rangę " .. nxt[1] .. ", zanim dobijesz limitu.",
            "Gdzie: " .. nxt[4] .. ". Po limicie każde zebranie albo craft przepada.", (s.rank >= s.max - 5) and 1 or 2)
        elseif s.rank >= s.max and l < nxt[3] then
          add("prof-wait-" .. pr.key, pr.name .. " stoi na limicie " .. s.max .. ".", "Ranga " .. nxt[1] .. " od " .. nxt[3] .. " poziomu postaci: " .. nxt[4] .. ".", 3)
        end
      end
    end
  end
  -- bandaze z tkanin w torbie
  local fa = p["First Aid"]
  if fa and fa.rank < 300 and not (G.kraftHas and G.kraftHas("First Aid")) then
    for _, c in ipairs(CLOTH) do
      if fa.rank >= c[1] and fa.rank < c[2] then
        local have = count(c[3])
        if c[3] == 2589 and l <= 15 then have = have - 10 end -- 10 Linen na quest Manaweave Robe (15)
        local crafts = math.floor(math.max(0, have) / c[4])
        if crafts >= 3 then
          add("prof-fa", "First Aid " .. fa.rank .. "/" .. fa.max .. ": zrób " .. c[5] .. " z tkaniny w torbie (starczy na " .. crafts .. ").",
            "Bandaż leczy między walkami bez picia. Okno profesji: klawisz K." .. ((c[3] == 2589 and l <= 15) and " 10 Linen zostaw na quest Manaweave Robe." or ""), 2)
        end
        break
      end
    end
    -- mikstury z ziol
    for id, h in pairs(POTION_HERBS) do
      if fa.rank >= h[1] and count(id) >= 3 then
        add("prof-pot", "Zrób " .. h[2] .. " z ziół w torbie, zamiast je sprzedawać.",
          "W Forever mikstury leczenia robi First Aid. Działają od razu, także w walce. Przepis u trenera albo z manuala.", 3)
        break
      end
    end
  end
  -- zbieractwo w tyle
  local expected = math.min(300, math.max(0, (l - 5) * 5))
  for _, key in ipairs({ "herbalism", "mining" }) do
    local nm = (key == "herbalism") and "Herbalism" or "Mining"
    local s = p[nm]
    if s and s.rank < expected - 30 and not (key == "mining" and l >= 40) then
      local b = bandOf(key, s.rank)
      add("prof-gather-" .. key, nm .. " zostaje w tyle (" .. s.rank .. ", na Twój poziom ok. " .. expected .. "): zbieraj po drodze.",
        "Teraz: " .. b[4] .. ". Gdzie: " .. b[5] .. ".", 4)
    end
  end
  -- Mining -> Tailoring na 40-42
  if p["Mining"] and (l >= 41 or (l >= 40 and G.knownSpellId and G.knownSpellId("Apprentice Riding"))) then
    add("prof-swap", "Czas zamienić Mining na Tailoring.", "Mining porzucisz w oknie profesji (K). Tailoring: Uthrar Threx w Ironforge; 1–150 z Linen i Wool z banku (punkt Legacy za 150). 225–300 to dużo Runecloth, dlatego teraz.", 2)
  end
  table.sort(out, function(a, b) return a.prio < b.prio end)
  return out
end

local function profSteps(add)
  local ok, list = pcall(reminders)
  if not ok or #list == 0 then return end
  local it = list[1]
  add(it.key, it.text, it.why, it.btn and { it.btn } or nil, nil, (#list > 1) and ("1 z " .. #list) or nil)
end

-- Krok do planu sesji (Sesja.lua): krotki opis, gdy z profesjami jest cos pilnego
local function profPlanItem()
  local ok, list = pcall(reminders)
  if not ok or not list[1] or list[1].prio > 2 then return nil end
  return "Profesje: " .. list[1].text:gsub("%.$", "")
end

-- Wstega, gdy profesja dojdzie do limitu rangi (raz na limit)
local seen = {}
local function capCheck()
  local p = readProfs()
  GrimuarSetupDB.profCapSaid = GrimuarSetupDB.profCapSaid or {}
  for _, pr in ipairs(PROFS) do
    local s = p[pr.name]
    if s and s.max and s.max > 0 and s.max < 300 and s.rank >= s.max then
      local k = pr.key .. s.max
      if not GrimuarSetupDB.profCapSaid[k] and not seen[k] then
        seen[k] = true
        GrimuarSetupDB.profCapSaid[k] = true
        local nxt = RANKS[pr.key] and RANKS[pr.key][s.max]
        pcall(G.showToast, pr.name .. " " .. s.rank .. "/" .. s.max .. ": limit. " ..
          (nxt and ("Ranga " .. nxt[1] .. (nxt[3] > (UnitLevel("player") or 1) and (" od " .. nxt[3] .. " poziomu") or "") .. ": " .. nxt[4] .. ".") or ""), "prof", false)
      end
    end
  end
end

-- ---------- 14.11 (gracz: „pierwsza pomoc juz mam na 29 i nic sie nie zmienilo, nie dalo mi znac po 20, ze juz nie
-- musze; tracking profesji dalej zle zrobiony”): cel zywy zamiast stalego opisu przedzialu.
--   * zadanie „Camping 101: <profesja>” z dziennika: cel z tekstu (np. 20) i czy spelniony,
--   * nastepny prog z planu (poczatek kolejnego przedzialu BANDS) i ranga u trenera (RANKS),
--   * komunikat w chwili przekroczenia progu (czat i wstega), raz na prog.
local BY_NAME = {}
for _, pr in ipairs(PROFS) do BY_NAME[pr.name] = pr end
local PL_NAME = { Herbalism = "Zielarstwo", Mining = "Górnictwo", ["First Aid"] = "Pierwsza pomoc", Cooking = "Gotowanie",
  Fishing = "Wędkarstwo", Tailoring = "Krawiectwo" }

local function campQuest(name)
  local out
  pcall(function()
    for i = 1, C_QuestLog.GetNumQuestLogEntries() do
      local info = C_QuestLog.GetInfo(i)
      if info and not info.isHeader and info.title == ("Camping 101: " .. name) then
        local target
        -- prog umiejetnosci tylko z celu, ktory nazywa profesje (cel „porozmawiaj z trenerem 0/1” to nie prog)
        for _, o in ipairs(C_QuestLog.GetQuestObjectives(info.questID) or {}) do
          local txt = tostring(o.text or "")
          if txt:find(name, 1, true) then
            local _, need = txt:match("(%d+)%s*/%s*(%d+)")
            local n = tonumber(need) or tonumber(txt:match("(%d+)"))
            if n and n >= 5 then target = target or n end
          end
        end
        out = { id = info.questID, title = info.title, target = target, complete = C_QuestLog.IsComplete(info.questID) and true or false }
        return
      end
    end
  end)
  return out
end

-- { rank, max, quest = { title, target, done }, now, where, next = { at, text }, rankUp = { name, skill, level, who } }
local function profGoal(name)
  local pr, s = BY_NAME[name], readProfs()[name]
  if not (pr and s) then return nil end
  local g = { rank = s.rank, max = s.max }
  local q = campQuest(name)
  if q then
    q.done = q.complete or (q.target ~= nil and s.rank >= q.target)
    g.quest = q
  end
  local b = bandOf(pr.key, s.rank)
  if b then g.now, g.where, g.lvl = b[4], b[5], b[3] end
  for _, bb in ipairs(BANDS[pr.key] or {}) do
    if bb[1] > s.rank then g.next = { at = bb[1], text = bb[4] } break end
  end
  local nxt = RANKS[pr.key] and RANKS[pr.key][s.max]
  if nxt then g.rankUp = { name = nxt[1], skill = nxt[2], level = nxt[3], who = nxt[4] } end
  return g
end

-- progi przekroczone od ostatniego sprawdzenia: komunikat raz na prog
local function milestoneCheck()
  local p = readProfs()
  GrimuarSetupDB.profPrev = GrimuarSetupDB.profPrev or {}
  local key = G.charKey and G.charKey() or "?"
  local prev = GrimuarSetupDB.profPrev[key] or {}
  GrimuarSetupDB.profPrev[key] = prev
  for _, pr in ipairs(PROFS) do
    local s = p[pr.name]
    local was = prev[pr.name]
    -- z GrimuarUI (zadania profesji) komunikaty daja zadania: tu tylko zapis stanu
    if s and was and s.rank > was and not G.profTasksActive then
      local g = profGoal(pr.name) or {}
      local pl = PL_NAME[pr.name] or pr.name
      local msgs = {}
      if g.quest and g.quest.target and was < g.quest.target and s.rank >= g.quest.target then
        msgs[#msgs + 1] = "cel zadania „" .. g.quest.title .. "” spełniony (" .. g.quest.target .. "): oddaj je (hub, Dziennik: Prowadź do oddania)"
      end
      for _, bb in ipairs(BANDS[pr.key] or {}) do
        if was < bb[1] and s.rank >= bb[1] then msgs[#msgs + 1] = "od " .. bb[1] .. ": " .. bb[4] end
      end
      if g.rankUp and was < g.rankUp.skill and s.rank >= g.rankUp.skill then
        msgs[#msgs + 1] = "ranga " .. g.rankUp.name .. " u trenera" .. (g.rankUp.level > (UnitLevel("player") or 1) and (" od " .. g.rankUp.level .. " poziomu") or "") .. ": " .. g.rankUp.who
      end
      if #msgs > 0 then
        local text = pl .. " " .. s.rank .. ": " .. table.concat(msgs, ". ") .. "."
        say(text)
        if G.showToast then pcall(G.showToast, text, "prof", false) end
      end
    end
    if s then prev[pr.name] = s.rank end
  end
end

-- Strona okna: Postac > Moje profesje
local function pageProfesje(P, l)
  local p = readProfs()
  P.M("Poziomy z gry, plan wg researchu R13 (13.11.2026). Przypomnienia pokazuje pasek Grimuara.")
  if G.kraftPage then pcall(G.kraftPage, P) end
  for _, pr in ipairs(PROFS) do
    local s = p[pr.name]
    P.H(pr.pl)
    if P.BAR then
      local nxt0 = s and RANKS[pr.key] and RANKS[pr.key][s.max]
      local col = ({ herbalism = { 0.49, 0.78, 0.55 }, mining = { 0.72, 0.62, 0.45 }, firstaid = { 0.79, 0.42, 0.35 },
        cooking = { 0.85, 0.6, 0.3 }, fishing = { 0.3, 0.55, 0.85 }, tailoring = { 0.7, 0.5, 0.85 } })[pr.key]
      if s then
        P.BAR("Umiejętność" .. (nxt0 and ("  ·  złota kreska: od tu ranga " .. nxt0[1]) or ""), s.rank .. " / " .. s.max, s.rank, s.max, col, nxt0 and nxt0[2] or nil)
      else
        P.BAR("nieuczona", "—", 0, 1, col)
      end
    end
    if s or pr.key == "mining" or pr.key == "fishing" or (pr.key == "tailoring" and l >= 35) then
      local b = bandOf(pr.key, s and s.rank or 1)
      if b then
        P.T("Teraz: " .. b[4], 13, 1)
        P.M("Gdzie: " .. b[5] .. " (poziom postaci " .. b[3] .. ")")
      end
      local nxt = s and RANKS[pr.key] and RANKS[pr.key][s.max]
      if nxt then P.M("Następna ranga " .. nxt[1] .. ": od skilla " .. nxt[2] .. " i " .. nxt[3] .. " poziomu. " .. nxt[4] .. ".") end
    else
      P.M(pr.key == "tailoring" and "Weźmiesz na 40–42 poziomie zamiast Mining." or "Nie musisz jej mieć.")
    end
  end
  P.H("Zasady")
  P.B({ "Zbieraj zawsze po drodze questów. Zioła i rudę sprzedawaj na AH od razu, chyba że idą na mikstury albo na raidy.",
    "Mikstury leczenia robi w Forever First Aid: Minor od 55 (Peacebloom), Lesser 85, Healing 135, Greater 155, Superior 215, Major 275.",
    "Ognisko: każdy stawia 1 obiekt (wspólne 1 h odnowienia). Dla maga najlepszy Fish Bowl z Fishing 20 (+8% statystyk). Świeca z Herbalism nie łączy się z Arcane Intellect.",
    "Punkty Legacy dają tylko profesje rzemieślnicze, czyli u Ciebie Tailoring (150, 225, 300).",
    "Śledzenie ziół i rudy może dzielić jeden slot: przełączaj zależnie od strefy (do sprawdzenia w grze)." })
end

-- 13.11 gracz: „z herbalismu nie pokazuja mi sie rzeczy”: Herbalism 14, ale Find Herbs wylaczone. Grimuar wlacza
-- sledzenie zbieractwa sam, raz na postac (gdy pozniej je wylaczysz, zostaje wylaczone); takze zaraz po nauce.
local function autoTrack()
  if InCombatLockdown() or not (G.gatherState and G.enableGatherTracking) then return end
  GrimuarSetupDB.trackAuto = GrimuarSetupDB.trackAuto or {}
  local key = G.charKey and G.charKey() or "?"
  if GrimuarSetupDB.trackAuto[key] then return end
  local has, on = G.gatherState()
  if not has then return end
  GrimuarSetupDB.trackAuto[key] = true
  if not on then pcall(G.enableGatherTracking) end
end

-- 13.11 gracz („pobierz”): baza ziol, rud i skrzyn z Wowhead dla GatherMate2 (AddOns/GatherMate2_Data, wersja Forever,
-- CurseForge „GatherMate2 Data Wowhead Classic”). Import raz, jak przycisk Import w ustawieniach GatherMate2: tryb Merge
-- (Twoje zebrane punkty zostaja), potem Auto Import przy nowej wersji danych robi juz sam GatherMate2.
local function gmImport()
  if (GrimuarSetupDB.gmImportV or 0) >= 1 or InCombatLockdown() then return end
  local AA = LibStub and LibStub("AceAddon-3.0", true)
  local GM = AA and AA:GetAddon("GatherMate2", true)
  local prof = GM and GM.db and GM.db.profile
  if not (prof and prof.importers and C_AddOns and C_AddOns.GetAddOnInfo) then return end
  local _, _, _, _, reason = C_AddOns.GetAddOnInfo("GatherMate2_Data")
  if reason == "MISSING" then return end
  local loaded = C_AddOns.LoadAddOn("GatherMate2_Data")
  local D = loaded and AA:GetAddon("GatherMate2_Data", true)
  if not (D and D.PerformMerge) then return end
  local imp = prof.importers["GatherMate2_Data"]
  imp.Databases = { Herbs = true, Mines = true, Treasure = true }
  imp.Style = "Merge"
  imp.autoImport = true
  GrimuarSetupDB.gmImportV = 1
  local ok = pcall(D.PerformMerge, D, imp.Databases, "Merge", nil)
  pcall(D.CleanupImportData, D)
  if not ok then say("GatherMate2: import bazy się nie udał. " .. G.helpHint() .. "") return end
  imp.lastImport = tonumber(tostring(D.generatedVersion or "0"):match("%d+")) or 0
  pcall(GM.RemoveDepracatedNodes, GM)
  pcall(GM.SendMessage, GM, "GatherMate2ConfigChanged")
  say("GatherMate2: wczytałem bazę ziół, rud i skrzyń z całego świata. Mapa (M) i minimapa pokażą też miejsca, w których jeszcze nie byłeś.")
end

local ev = CreateFrame("Frame")
ev:RegisterEvent("PLAYER_LOGIN")
ev:SetScript("OnEvent", function(_, event)
  if event == "PLAYER_LOGIN" then
    ev:RegisterEvent("SKILL_LINES_CHANGED")
    ev:RegisterEvent("CHAT_MSG_SKILL")
    pcall(ev.RegisterEvent, ev, "LEARNED_SPELL_IN_TAB")
    pcall(ev.RegisterEvent, ev, "LEARNED_SPELL_IN_SKILL_LINE")
    C_Timer.After(20, function() pcall(capCheck) end)
    C_Timer.After(8, function() pcall(milestoneCheck) end) -- zapamietaj stan po wejsciu (progi miedzy sesjami)
    C_Timer.After(10, function() pcall(autoTrack) end)
    C_Timer.After(25, function() pcall(gmImport) end)
  elseif event == "LEARNED_SPELL_IN_TAB" or event == "LEARNED_SPELL_IN_SKILL_LINE" then
    C_Timer.After(1, function() pcall(autoTrack) end)
  else
    C_Timer.After(0.5, function() pcall(capCheck) pcall(milestoneCheck) end)
  end
end)

-- Wiersze okienka „Profesje” pod Combo Frosta (OknoProfesji.lua, gracz 13.11): poziom i jedna wskazowka na profesje.
-- Kraft z ostatniego otwarcia okna profesji (Kraft.lua), inaczej plan z BANDS; blisko limitu: trener.
local function panelRows()
  local p = readProfs()
  local rows = {}
  for _, pr in ipairs(PROFS) do
    local s = p[pr.name]
    if s then
      local b = bandOf(pr.key, s.rank)
      local kt, kr
      if G.kraftShort then
        kt, kr = G.kraftShort(pr.name)
        if not kt and pr.key == "mining" then kt, kr = G.kraftShort("Smelting") end
      end
      local hint
      if pr.key == "herbalism" or pr.key == "mining" then
        -- zbieractwo rosnie od zbierania; kraft tylko, gdy masz przepis z punktem i materialy (13.11)
        hint = b and ("zbieraj: " .. b[4] .. " (" .. b[5] .. ")") or nil
        if kr and kr.now then hint = (hint and (hint .. ". ") or "") .. "Z zebranych: " .. kt end
        if pr.key == "herbalism" and not (kr and (kr.now or kr.need)) then
          -- 14.11 (R13): Incense Candle to obiekt obozowy (buff Int), ktory nie laczy sie z Arcane Intellect: magowi nic nie daje
          hint = (hint and (hint .. ". ") or "") .. "Incense Candle pomiń: buff Int nie łączy się z Arcane Intellect."
        end
      else
        -- 15.11: bez przepisu z okna profesji najpierw krok z poradnika Polestara (GrimuarUI RzemiosloPolestar.lua)
        local okH, ph = pcall(function() return G.psProfHint and G.psProfHint(pr.name, s.rank) end)
        hint = kt or (okH and ph) or (b and b[4]) or nil
      end
      local nxt = RANKS[pr.key] and RANKS[pr.key][s.max]
      if nxt and s.rank >= nxt[2] - 5 then
        hint = "trener: ranga " .. nxt[1] .. " od " .. nxt[2] .. ". " .. (hint or "")
      end
      rows[#rows + 1] = { key = pr.key, name = pr.name, rank = s.rank, max = s.max, hint = hint }
    end
  end
  return rows
end

G.profPanelRows = panelRows
G.profSteps = profSteps
G.profPlanItem = profPlanItem
G.pageMojeProfesje = pageProfesje
G.profRank = function(name) local s = readProfs()[name] return s and s.rank or 0 end
G.POTION_HERBS = POTION_HERBS
-- 14.11: zakladka Rzemioslo w hubie (GrimuarUI) czyta plan i poziomy stad
G.PROFS = PROFS
G.PROF_BANDS = BANDS
G.PROF_RANKS = RANKS
G.PROF_CLOTH = CLOTH
G.PROF_POTIONS = POTION_HERBS
G.readProfs = readProfs
G.profBand = bandOf
G.profGoal = profGoal
G.profMilestoneCheck = milestoneCheck
