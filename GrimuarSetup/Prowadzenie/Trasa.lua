-- Grimuar: modul Trasa (gracz 14.11: „jak ustawic questy i dropienie przedmiotow, zeby jak najefektywniej (nie
-- najszybciej) wbic 60, zbierajac wszystko, co potrzeba; przerobisz guide'a z questami i bede sie go trzymac do konca”).
-- Research: gaming-warsztat/wow/research/R22-zarabianie-i-trasa-2611.md (14.11), do tego R8 (zloto), R10, R13.
-- Polestar zostaje kregoslupem: jego trasa stref Przymierza 1-60, strzalka i odhaczanie. Grimuar dokłada:
--  1) wlasny pakiet przewodnikow Polestara „grimuar” (Polestar.RegisterPack/RegisterGuide, format 8, jak oficjalny
--     Polestar_Guides) z questami, ktorych trasa Polestara nie ma: Hall of Thanes (Deepblaze, Dwarven Tome),
--     Vyrin's Revenge (torba 10), Baron Marinous (Mathystra Channeling Orb); dane z Polestar_QuestDB i ItemDB (Forever);
--  2) TRASA: odcinki poziomow -> przewodnik Polestara, poboczne (klasowe Polestara i nasze), co zbierac, co sprzedac,
--     co zatrzymac, cel zlota na koniec odcinka (szacunek z R8/R22);
--  3) poboczny przewodnik otwiera sie sam jako karta w Polestarze (bez przelaczania trasy), raz, gdy poziom pasuje;
--  4) krok „Trasa” w planie (gdy Polestar prowadzi poza odcinkiem albo czeka poboczny) i /trasa w czacie.
local ADDON_NAME, G = ...
local say = G.say

local PACK = "grimuar"
local IF, DM, LM, DS = 1455, 1426, 1432, 1439 -- Ironforge, Dun Morogh, Loch Modan, Darkshore

-- ---------- przewodniki Grimuara dla Polestara ----------
local function npc(id, name, map, x, y) return { npc = id, npcName = name, map = map, x = x, y = y } end
local function goal(t, quest, title, at, extra)
  local g = { t = t, quest = quest, title = title }
  for k, v in pairs(at or {}) do g[k] = v end
  for k, v in pairs(extra or {}) do g[k] = v end
  return g
end
local FARSEN = npc(264936, "Earthseer Farsen", DM, 64.9, 58.5)
local MAGNI = npc(2784, "King Magni Bronzebeard", IF, 39.1, 56.2)
local THOM = npc(265003, "Thom Filch", IF, 32.2, 44.5)
local AFADRA = npc(264943, "Afadra Dunwall", IF, 33.2, 47.9)
local VYRIN = npc(1156, "Vyrin Swiftwind", LM, 81.7, 64.1)
local DARYL = npc(1187, "Daryl the Youngling", LM, 83.5, 65.5)
local ONU = npc(3616, "Onu", DS, 43.6, 76.3)

local GUIDES = {
  {
    id = "grimuar/hall-of-thanes", title = "Hall of Thanes: Deepblaze i Dwarven Tome", minLevel = 9, maxLevel = 18,
    why = "Deepblaze (niebieska różdżka 22–41, ok. 18 DPS, od 1 poziomu) to najlepsza różdżka na start. Loch pod Ironforge na 5 osób.",
    reward = { { item = 279896, itemName = "Deepblaze" }, { item = 279898, itemName = "Dwarven Tome", choice = true }, { item = 280096, itemName = "Tomb Robber's Gloves", choice = true } },
    steps = {
      { title = "Earthseer Farsen", note = "Mapę (Dark Iron Map, quest Underground Map) upuszcza jeden z Dark Iron Spy przy Ironbeard's Compound. Nie wyrzucaj jej. Trasa Polestara w Dun Morogh prowadzi przez te questy.",
        goals = { { t = "level", level = 9 }, goal("turnin", 96391, "Underground Map", FARSEN), goal("accept", 96393, "Old Ironforge Incursion", FARSEN) } },
      { title = "Ironforge: questy do lochu", note = "Weź oba przed wejściem. Za Important Heirlooms wybierzesz Dwarven Tome (off-hand, moc zaklęć) albo Tomb Robber's Gloves (Intelekt).",
        goals = { goal("accept", 96403, "Important Heirlooms", THOM), goal("accept", 96394, "The Restless Dead", AFADRA) } },
      { title = "Hall of Thanes z grupą", note = "Loch 13–18 pod Ironforge, na 5 osób: ekipa albo kanał LookingForGroup. W środku Ghostly Attendant daje An Ancient Grudge. Jeśli wypadnie przedmiot z questem The Treaty of Understanding, weź go (oddajesz Magniemu). Głowa ostatniego bossa kończy Old Ironforge Incursion.",
        goals = { goal("complete", 96393, "Old Ironforge Incursion"), goal("complete", 96403, "Important Heirlooms"), goal("complete", 96394, "The Restless Dead") } },
      { title = "Oddaj w Ironforge", note = "Magni: Deepblaze do slotu różdżki (strzał pod G). Thom Filch: Dwarven Tome albo rękawice.",
        goals = { goal("turnin", 96393, "Old Ironforge Incursion", MAGNI, { rewards = { choices = { { item = 279896, itemName = "Deepblaze" } } } }),
          goal("turnin", 96403, "Important Heirlooms", THOM, { rewards = { choices = { { item = 279898, itemName = "Dwarven Tome" }, { item = 280096, itemName = "Tomb Robber's Gloves" } } } }),
          goal("turnin", 96394, "The Restless Dead", AFADRA) } },
      { title = "The Treaty of Understanding", when = { { k = "onquest", q = { 98423 } } },
        goals = { goal("turnin", 98423, "The Treaty of Understanding", MAGNI) } },
    },
  },
  {
    id = "grimuar/vyrins-revenge", title = "Vyrin's Revenge: torba na 10 miejsc", minLevel = 15, maxLevel = 21,
    why = "Darmowa torba na 10 miejsc w Loch Modan. Trasa Polestara robi questy Daryla, ale tego pomija.",
    steps = {
      { title = "Vyrin Swiftwind", note = "Wymaga ukończonego A Hunter's Challenge (Daryl the Youngling, trasa Polestara w Loch Modan).",
        goals = { { t = "level", level = 15 }, goal("accept", 271, "Vyrin's Revenge", VYRIN) } },
      { title = "Cel questu", note = "Cel pokaże dziennik questów, a Questie zaznaczy miejsce na mapie.",
        goals = { goal("complete", 271, "Vyrin's Revenge") } },
      { title = "Daryl i z powrotem do Vyrina",
        goals = { goal("turnin", 271, "Vyrin's Revenge", DARYL), goal("accept", 531, "Vyrin's Revenge", DARYL), goal("turnin", 531, "Vyrin's Revenge", VYRIN) } },
    },
  },
  {
    id = "grimuar/baron-marinous", title = "Baron Marinous: Mathystra Channeling Orb", minLevel = 19, maxLevel = 24,
    why = "Off-hand +5 Int i +3 Sta z nowego questu Forever w Darkshore. Trasa Polestara go pomija.",
    reward = { { item = 281291, itemName = "Mathystra Channeling Orb", choice = true }, { item = 281292, itemName = "Onu's Patience", choice = true } },
    steps = {
      { title = "Baron Marinous", note = "Baron Marinous (ok. 21 poziom) stoi przy ruinach Mathystry na północy Darkshore. Upuszcza przedmiot, który zaczyna quest: kliknij go prawym w torbie. Weź grupę albo poczekaj na 21–22.",
        goals = { { t = "level", level = 19 }, { t = "kill", target = "Baron Marinous", map = DS, x = 59.2, y = 22.5 }, goal("accept", 98028, "Baron Marinous") } },
      { title = "Onu", goals = { goal("turnin", 98028, "Baron Marinous", ONU, { rewards = { choices = { { item = 281291, itemName = "Mathystra Channeling Orb" }, { item = 281292, itemName = "Onu's Patience" } } } }) } },
    },
  },
}

local registered, regProblem = false, nil
local function register()
  if registered then return true end
  if not (Polestar and Polestar.RegisterPack and Polestar.RegisterGuide) then return false end
  registered = true
  local ok, err = Polestar.RegisterPack({ addon = ADDON_NAME, id = PACK, format = 8, title = "Grimuar", author = "Grimuar",
    version = "1.0", license = "GPL-3.0-only", notes = "Questy po drodze dla maga, których trasa Polestara nie ma: różdżka, torby, off-hand." })
  if not ok then regProblem = "pakiet: " .. tostring(err) return false end
  for _, g in ipairs(GUIDES) do
    g.pack, g.faction, g.category, g.folder, g.classes, g.author, g.version = PACK, "Alliance", "Class", "Grimuar", { "MAGE" }, "Grimuar", 1
    local gok, gerr = Polestar.RegisterGuide(g)
    if not gok then regProblem = (regProblem and regProblem .. "; " or "") .. g.id .. ": " .. tostring(gerr) end
  end
  return true
end
pcall(register) -- Polestar w OptionalDeps: zwykle laduje sie przed nami

-- ---------- trasa: odcinki ----------
-- side: { od poziomu, id przewodnika Polestara, opis, quest, ktory konczy sprawe (albo nil) }
local S = 100
local TRASA = {
  { 1, 14, "Dun Morogh", "forever/alliance/gnome/01-dun-morogh",
    side = { { 9, "grimuar/hall-of-thanes", "Deepblaze i Dwarven Tome (loch z grupą)", 96393 },
      { 10, "forever/class/mage/staff-or-orb-alliance", "quest klasowy: Arcane Orb albo Arcane Staff", 1880 } },
    gather = "Peacebloom, Silverleaf, Earthroot (drożeją), Copper Ore, gdy weźmiesz Mining",
    sell = "szare u kupca; zioła na AH tylko całymi stackami, dopóki depozyt to 1 s (zmiana na 1 c w konserwacji 18.11)",
    keep = "Linen Cloth (First Aid), Dark Iron Map", gold = 1 * S * S },
  { 11, 17, "Westfall", "forever/alliance/02-westfall",
    side = { { 15, "forever/class/mage/manaweave-robe", "Manaweave Robe (zacznij u Dinka w Ironforge, 10 Linen)", 1919 } },
    extra = "Old Blanchy's Feed Pouch (torba 8, Polestar prowadzi); Deadmines z grupą od 17: Cookie's Stirring Rod",
    gather = "Mageroyal, Briarthorn, Copper i Tin",
    sell = "zielone BoE na AH, gdy cena ≥ 2× u kupca; reszta u kupca", keep = "Linen (First Aid), Red Leather Bandana na quest", gold = 2 * S * S },
  { 15, 19, "Darkshore", "forever/alliance/03-darkshore",
    extra = "Manaweave Robe przed wypłynięciem; Wizbang's Gunnysack (torba 8, łańcuch Buzzbox)",
    gather = "Briarthorn, Stranglekelp, Tin", sell = "Silk sprzedawaj nadwyżkę ponad ok. 140 na First Aid",
    keep = "Wool Cloth (First Aid)", gold = 3 * S * S },
  { 17, 21, "Loch Modan", "forever/alliance/03-loch-modan",
    side = { { 15, "grimuar/vyrins-revenge", "Vyrin's Revenge: torba na 10", 531 },
      { 20, "forever/class/mage/teleports-alliance", "teleport do miasta (od 20)", nil } },
    extra = "Silver of the Waves (20): Repurposed Hair Band; Minor Channeling Ring",
    gather = "Copper, Tin, Silverleaf, Earthroot", sell = "rudy całymi stackami", keep = "Wool", gold = 5 * S * S },
  { 21, 23, "Darkshore, powrót", "forever/alliance/03-darkshore-return",
    side = { { 19, "grimuar/baron-marinous", "Mathystra Channeling Orb (+5 Int)", 98028 } },
    gather = "Briarthorn, Bruiseweed, Tin", keep = "Wool, Silk", gold = 7 * S * S },
  { 22, 25, "Ashenvale", "forever/alliance/06-ashenvale",
    extra = "Old Toolbox (torba 12) w Stonetalon, jeśli Polestar tam zajdzie; BFD z grupą: Gravestone Scepter (quest Blackfathom Villainy)",
    gather = "Bruiseweed, Stranglekelp, Tin, Silver", gold = 10 * S * S },
  { 25, 27, "Redridge", "forever/alliance/04-redridge-mountains",
    side = { { 26, "forever/class/mage/astral-knot-garment", "Astral Knot Garment (można pominąć)", nil } },
    extra = "WANTED: Incinerator Gar'im: Incinerator's Boots (+6 Int), Polestar prowadzi",
    gather = "Briarthorn, Bruiseweed, Tin, Silver", gold = 14 * S * S },
  { 27, 28, "Duskwood", "forever/alliance/05-duskwood", gather = "Grave Moss, Silver, Iron", gold = 17 * S * S },
  { 27, 30, "Wetlands", "forever/alliance/06-wetlands",
    extra = "Bloom of the Heavens (29, off-hand); Excavation Site z grupą (questy od 24 w Lakeshire i Menethil)",
    gather = "najlepsze miejsce na Tin i Silver; Bruiseweed, Kingsblood", gold = 22 * S * S },
  { 29, 31, "Thousand Needles", "forever/alliance/07-thousand-needles", gold = 25 * S * S },
  { 30, 40, "Hillsbrad, Desolace, Stranglethorn, Arathi, Badlands", "forever/alliance/30-40/01-hillsbrad-foothills",
    extra = "na 30 u trenera Journey to the Marsh (łańcuch Mage's Wand, finał ok. 40); Gnomeregan, SM z grupą; Riverglades (36–44) nie ma w trasie Polestara",
    gather = "Liferoot, Iron, Gold, potem Goldthorn, Fadeleaf, Mithril (tanieją: sprzedawaj od razu)",
    sell = "Mageweave ponad ok. 95 na First Aid", keep = "100 g na jazdę na 40", gold = 110 * S * S },
  { 40, 50, "Stranglethorn, Badlands, Feralas, Tanaris, Hinterlands, Searing Gorge, Un'Goro", "forever/alliance/40-50/01-stranglethorn-vale",
    extra = "najpierw jazda (Steelgrill's Depot, 100 g); Celestial Power i Uldaman; od 48 questy dają dodatkowe złoto; Mining na Tailoring na 40–42",
    gold = 200 * S * S },
  { 50, 60, "Burning Steppes, Felwood, Winterspring, Plaguelands, Silithus", "forever/alliance/50-60/01-burning-steppes",
    extra = "Destroy Morphaz (52), łańcuch Onyxii (od 48), Runecloth na Tailoring", gold = 400 * S * S },
}

local function money(c)
  c = math.floor(c or 0)
  if c >= S * S then return math.floor(c / (S * S)) .. " g" end
  if c >= S then return math.floor(c / S) .. " s" end
  return c .. " c"
end

local function legFor(l)
  local best
  for _, leg in ipairs(TRASA) do
    if l >= leg[1] and l <= leg[2] then best = leg if l < leg[2] then break end end
  end
  return best or TRASA[#TRASA]
end

local function questDone(q)
  if not q then return false end
  local ok, done = pcall(C_QuestLog.IsQuestFlaggedCompleted, q)
  return ok and done
end

local function engine() return Polestar and Polestar.Engine end
local function guideExists(id)
  local ok, g = pcall(function() return Polestar.Guides.Get(id) end)
  return ok and g ~= nil
end
local function tabOpen(id)
  local ok, ids = pcall(function() return engine().TabIds() end)
  return ok and type(ids) == "table" and ids[id] ~= nil
end
local function activeGuideId()
  local ok, g = pcall(function() return engine().GetGuide() end)
  return ok and g and g.id or nil
end

local function charDB()
  GrimuarSetupDB.trasa = GrimuarSetupDB.trasa or {}
  local k = G.charKey and G.charKey() or "?"
  GrimuarSetupDB.trasa[k] = GrimuarSetupDB.trasa[k] or { opened = {} }
  return GrimuarSetupDB.trasa[k]
end

-- poboczne, ktore czekaja: poziom osiagniety, quest konczacy niezrobiony
local function pendingSides(l)
  local out = {}
  for _, leg in ipairs(TRASA) do
    if leg[1] <= l + 1 then
      for _, s in ipairs(leg.side or {}) do
        if l >= s[1] and not questDone(s[4]) and guideExists(s[2]) and not (s[4] == nil and charDB().opened[s[2]]) then
          out[#out + 1] = s
        end
      end
    end
  end
  return out
end

local function openSide(id, activate)
  local E = engine()
  if not (E and E.OpenTab) then return false end
  local ok, idx = pcall(E.OpenTab, id, activate)
  return ok and idx ~= nil
end

-- raz na postac: poboczny przewodnik jako karta w Polestarze, bez przelaczania biezacej trasy
local function autoOpen()
  if InCombatLockdown() or not engine() then return end
  local l = UnitLevel("player") or 1
  local db = charDB()
  for _, s in ipairs(pendingSides(l)) do
    if not db.opened[s[2]] and not tabOpen(s[2]) then
      if openSide(s[2], false) then
        db.opened[s[2]] = true
        local msg = "Trasa Grimuara: w Polestarze nowa karta „" .. s[3] .. "”. Zrób, gdy będziesz w pobliżu."
        say(msg)
        pcall(G.showBanner, msg, "plan", false)
      end
    end
  end
end

local function legText(leg)
  local parts = { "Trasa: " .. leg[3] .. " (" .. leg[1] .. "–" .. leg[2] .. ")" }
  if leg.extra then parts[#parts + 1] = "po drodze: " .. leg.extra end
  if leg.gather then parts[#parts + 1] = "zbieraj: " .. leg.gather end
  if leg.sell then parts[#parts + 1] = "sprzedawaj: " .. leg.sell end
  if leg.keep then parts[#parts + 1] = "zatrzymaj: " .. leg.keep end
  if leg.gold then parts[#parts + 1] = "cel złota na koniec odcinka: ok. " .. money(leg.gold) .. " (masz " .. money(GetMoney()) .. ")" end
  return parts
end

-- krok w planie (Kroki.lua): Polestar prowadzi poza odcinkiem albo czekaja poboczne
local function steps(add)
  if not engine() then return end
  local l = UnitLevel("player") or 1
  local leg = legFor(l)
  local active = activeGuideId()
  local onRoute = false
  if active then
    if active:find("^forever/class/") or active:find("^grimuar/") then onRoute = true end
    for _, other in ipairs(TRASA) do
      if other[4] == active and l >= other[1] - 2 and l <= other[2] + 2 then onRoute = true end
    end
  end
  if not onRoute and guideExists(leg[4]) then
    add("trasa-main", "Trasa Grimuara: teraz " .. leg[3] .. " (" .. leg[1] .. "–" .. leg[2] .. "). Ustaw ją w Polestarze.",
      "Polestar prowadzi " .. (active and "inną trasą" or "bez trasy") .. ". Trasa Grimuara idzie za kolejnością Polestara i dokłada questy po drodze: różdżki, torby, off-handy.",
      { { "Ustaw", function() pcall(function() engine().SetGuide(leg[4]) end) end } })
  end
  for _, s in ipairs(pendingSides(l)) do
    if not tabOpen(s[2]) and charDB().opened[s[2]] then
      add("trasa-" .. s[2], "Poboczne z trasy: " .. s[3] .. ".", "Karta była otwarta w Polestarze i zamknięta przed końcem questu. Otwórz ją ponownie, gdy będziesz w pobliżu.",
        { { "Otwórz", function() openSide(s[2], true) end } })
    end
  end
end

local function report()
  local l = UnitLevel("player") or 1
  local leg = legFor(l)
  for _, line in ipairs(legText(leg)) do say(line) end
  local pend = pendingSides(l)
  if #pend > 0 then
    local names = {}
    for _, s in ipairs(pend) do names[#names + 1] = s[3] end
    say("Poboczne teraz: " .. table.concat(names, "; ") .. ".")
  end
  for i, other in ipairs(TRASA) do
    if other == leg and TRASA[i + 1] then say("Następny odcinek: " .. TRASA[i + 1][3] .. " od " .. TRASA[i + 1][1] .. ".") end
  end
  if not engine() then say("Polestar nie jest załadowany: trasa działa tylko z nim.")
  elseif regProblem then say("Przewodniki Grimuara w Polestarze: problem (" .. regProblem .. ").") end
end

local ev = CreateFrame("Frame")
ev:RegisterEvent("ADDON_LOADED")
ev:RegisterEvent("PLAYER_LOGIN")
ev:RegisterEvent("PLAYER_LEVEL_UP")
ev:RegisterEvent("QUEST_TURNED_IN")
ev:SetScript("OnEvent", function(_, e, a1)
  if e == "ADDON_LOADED" then
    if a1 == "Polestar" then pcall(register) end
    return
  end
  pcall(register)
  if e == "PLAYER_LOGIN" then
    -- 14.11 (R27 E5): trasa jest dla gnoma i krasnoluda Przymierza (start Dun Morogh); inne rasy i Horda: bez trasy Grimuara
    local _, race = UnitRace("player")
    if not ((race == "Gnome" or race == "Dwarf") and UnitFactionGroup("player") == "Alliance") then wipe(TRASA) G.trasaNone = true end
    C_Timer.After(12, function() pcall(autoOpen) end)
  elseif e == "PLAYER_LEVEL_UP" then
    C_Timer.After(6, function() pcall(autoOpen) end)
  end
end)

SLASH_GRIMUARTRASA1 = "/trasa"
SlashCmdList["GRIMUARTRASA"] = function() pcall(report) end

G.TRASA = TRASA
G.trasaSteps = steps
G.trasaLeg = legFor
G.trasaText = legText
