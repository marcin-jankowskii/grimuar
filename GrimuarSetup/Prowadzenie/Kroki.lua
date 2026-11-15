-- Grimuar: modul Engine (wspolne funkcje przez tabele G z innych modulow).
local ADDON_NAME, G = ...
local C_FROST = G.C_FROST
local C_GOLD = G.C_GOLD
local C_MUTED = G.C_MUTED
local C_OK = G.C_OK
local DUNGEONS = G.DUNGEONS
local FONT = G.FONT
local STAGES = G.STAGES
local TALENT_AT = G.TALENT_AT
local charKey = G.charKey
local knownSpellId = G.knownSpellId
local say = G.say

-- Czesc wydzielona z Engine.lua (podzial plikow >1000 linii, 12.11).
local S = G.S
local enableGatherTracking = G.enableGatherTracking
local findMapId = G.findMapId
local freeBagSlots = G.freeBagSlots
local gatherState = G.gatherState
local guideTo = G.guideTo
local guideTrainer = G.guideTrainer
local hasAura = G.hasAura
local hearthInfo = G.hearthInfo
local markBook = G.markBook
local minDurability = G.minDurability
local missingTraining = G.missingTraining
local nearestGuide = G.nearestGuide
local nearestTrainer = G.nearestTrainer
local openMap = G.openMap
local openTalents = G.openTalents
local polestarLoaded = G.polestarLoaded
local questStats = G.questStats
local setCheck = G.setCheck
local skipped = G.skipped
local talentPoints = G.talentPoints
local unmarkBook = G.unmarkBook
local unsetCheck = G.unsetCheck
local waterCount = G.waterCount
local wayTo = G.wayTo

-- ---------- jak zrobic zadanie etapu: opis, miejsce i automatyczne odhaczenie ----------
local function haveSpell(n) return knownSpellId(n) ~= nil end

local function itemAnywhere(n)
  local ok, c = pcall(function()
    if C_Item and C_Item.GetItemCount then return C_Item.GetItemCount(n, true) end
    return GetItemCount(n, true)
  end)
  return ok and type(c) == "number" and c > 0
end

local function hasExtraBag()
  for bag = 1, 4 do
    local ok, n = pcall(function()
      if C_Container and C_Container.GetContainerNumSlots then return C_Container.GetContainerNumSlots(bag) end
      return GetContainerNumSlots(bag)
    end)
    if ok and type(n) == "number" and n > 0 then return true end
  end
  return false
end

-- Czy gracz jest blisko miejsca (ta sama mapa, odleglosc w ulamku mapy).
local function nearLoc(loc, maxD)
  local near = false
  pcall(function()
    local here = C_Map.GetBestMapForUnit("player")
    if here ~= loc[1] then return end
    local pos = C_Map.GetPlayerMapPosition(here, "player")
    if not pos then return end
    local px, py = pos:GetXY()
    near = ((loc[2] / 100 - px) ^ 2 + (loc[3] / 100 - py) ^ 2) <= (maxD or 0.04) ^ 2
  end)
  return near
end

-- Klucz = tekst zadania z STAGES. 15.11 (R30 P30, decyzja Q6): bez przepisanych wspolrzednych; loc to { npc = id } albo
-- { trainer = linia profesji } z opisem, a miejsce daje w locie Polestar (Codex, Nav.nearby), bez niego Questie
-- (Miejsca.lua G.resolveLoc). Codex Polestara wczytuje dopiero klik w Prowadz.
local TODO_HELP = {
  -- R13 (13.11): Fishing tylko do 20, dla obiektu Fish Bowl przy ognisku
  ["Fishing do 20: Fish Bowl przy ognisku (+8% statystyk)"] = {
    how = "Trener Paxton Ganter nad Iceflow Lake w Dun Morogh, wędka u sprzedawcy obok. Łów, aż Fishing dojdzie do 20, potem możesz przestać. Fish Bowl stawiasz przy ognisku (1 obiekt na gracza, 1 h odnowienia).",
    loc = { trainer = 356, label = "Fishing" } },
  -- R10 (13.11): jazda na 40
  ["Apprentice Riding i mechanostrider"] = {
    how = "Steelgrill's Depot w Dun Morogh: trener jazdy i sprzedawca mechanostriderów. 100 g, przy Honored z Gnomeregan 90 g. Wierzchowca daje quest u sprzedawcy.",
    loc = { npc = 7954, label = "Steelgrill's Depot: jazda" } }, -- Binjy Featherwhistle
  ["Hearthstone przypisany w Kharanos"] = {
    how = "Porozmawiaj z karczmarzem Innkeeper Belm w karczmie Thunderbrew w Kharanos i wybierz Make this inn your home. Hearthstone z torby przeniesie Cię tu raz na godzinę.",
    loc = { npc = 1247, label = "Innkeeper Belm, Kharanos" },
    done = function()
      local b = (GetBindLocation and GetBindLocation()) or ""
      return b == "Kharanos" or b == "Thunderbrew Distillery"
    end },
  ["First Aid, Herbalism i Mining u trenerów"] = {
    how = "Porozmawiaj z trenerem profesji i kliknij Train. First Aid: Thamner Pol w karczmie w Kharanos. Mining: Yarr Hammerstone w Kharanos. Herbalism: Reyna Stonebranch w Ironforge. Prowadź wskaże najbliższego, którego jeszcze nie masz.",
    loc = function()
      if not haveSpell("First Aid") then return { trainer = 129, label = "trener First Aid" } end
      if not haveSpell("Find Minerals") then return { trainer = 186, label = "trener Mining" } end
      if not haveSpell("Find Herbs") then return { trainer = 182, label = "trener Herbalism" } end
      return nil
    end,
    done = function() return haveSpell("First Aid") and haveSpell("Find Minerals") and haveSpell("Find Herbs") end },
  ["Pierwsza torba założona (przeciągnij do slotu)"] = {
    how = "Torbę dostaniesz z questu albo kupisz u kupca (np. Small Brown Pouch) lub w domu aukcyjnym. Canvas Latchbag daje quest „Grund and Gozwin”. Otwórz torby (B) i przeciągnij nową torbę na pusty slot obok plecaka na dole ekranu (w Forever prawy klik jej nie założy).",
    done = hasExtraBag },
  ["Frost Armor i Arcane Intellect zawsze włączone"] = {
    how = "Frost Armor masz pod klawiszem 8. Arcane Intellect kup u trenera maga, potem klawisz 9. Rzucaj oba po każdej śmierci i gdy znikną.",
    done = function() return haveSpell("Frost Armor") and haveSpell("Arcane Intellect") end },
  ["Quest „Rare Books”: Apprentice's Spellstaff"] = {
    how = "Polestar poprowadzi Cię do tego questu na trasie. Nagroda to laska Apprentice's Spellstaff: załóż ją prawym klikiem w torbie.",
    done = function() return itemAnywhere("Apprentice's Spellstaff") end },
  -- 14.11 R22: Gizmonitor daje Arcane Orb/Staff (Ley Orb/Staff to Mirror Lake; lancuchy sie wykluczaja)
  ["Quest „Mage-tastic Gizmonitor” (Arcane Orb albo Arcane Staff)"] = {
    how = "Na 10 poziomie Magis Sparkmantle (trener maga w Kharanos) wysyła do Binka w Ironforge (Mystic Ward), potem skrzynka na północ od Gnomeregan. Nagroda: Arcane Orb albo Arcane Staff. Przewodnik klasowy Polestara otworzy się sam.",
    loc = { npc = 5144, label = "Bink, Ironforge" },
    done = function() return itemAnywhere("Arcane Orb") or itemAnywhere("Arcane Staff") or itemAnywhere("Ley Orb") or itemAnywhere("Ley Staff") end },
  ["Quest „Old Ironforge Incursion” (Deepblaze)"] = {
    how = "Mapę (Dark Iron Map) upuszcza Dark Iron Spy w Ironbeard's Compound. Oddaj ją Earthseerowi Farsenowi, weź Old Ironforge Incursion, a w Ironforge Important Heirlooms i The Restless Dead. Potem Hall of Thanes z grupą i oddanie u Magniego. Karta Grimuara „Hall of Thanes” w Polestarze prowadzi krok po kroku.",
    loc = { npc = 264936, label = "Earthseer Farsen" },
    done = function() return itemAnywhere("Deepblaze") or C_QuestLog.IsQuestFlaggedCompleted(96393) end },
  ["Quest „Vyrin's Revenge” (torba 10)"] = {
    how = "Loch Modan, od 15: Vyrin Swiftwind na wschodzie (po A Hunter's Challenge u Daryla). Darmowa torba na 10 miejsc. Karta Grimuara w Polestarze otworzy się sama.",
    loc = { npc = 1156, label = "Vyrin Swiftwind" },
    done = function() return C_QuestLog.IsQuestFlaggedCompleted(531) end },
  ["Różdżka w slocie"] = {
    how = "Najlepsza na start: Deepblaze (quest od 9 poziomu). Zdobądź Dark Iron Map z Dark Iron Spy w Ironbeard's Compound (Dun Morogh), oddaj ją Earthseerowi Farsenowi i zabij ostatniego bossa Hall of Thanes. Szybciej: Lesser Magic Wand z domu aukcyjnego. Załóż prawym klikiem, strzelasz klawiszem G.",
    done = function() return GetInventoryItemID and GetInventoryItemID("player", 18) ~= nil end },
  ["Pierwsze 10 książek z bibliotek"] = {
    how = "Zakładka Mapa w oknie Grimuara (Shift+G) prowadzi strzałką do każdej książki. Po podniesieniu kliknij Mam." },
  ["Hall of Thanes albo Deadmines z ekipą"] = {
    how = "Zapytaj ekipę na czacie gildii (/g), czy idą do dungeonu na Twój poziom. Wcześniej weź wszystkie questy do tego dungeonu." },
  ["Wszystkie flight pathy w odwiedzonych strefach"] = {
    how = "Porozmawiaj z każdym flight masterem (ikona skrzydeł nad głową), np. w Ironforge i w Thelsamar. Tak odblokujesz szybkie loty." },
}

-- Po walce: czy trzeba odpoczac (mana < 40% albo zycie < 50%), chyba ze juz pijesz albo jesz.
local function restNeed()
  local ok, res = pcall(function()
    if hasAura("Drink") or hasAura("Food") or hasAura("Food & Drink") or hasAura("Refreshment") then return nil end
    local hp, hpMax = UnitHealth("player"), UnitHealthMax("player")
    local mp, mpMax = UnitPower("player", 0), UnitPowerMax("player", 0)
    local hpP = (hpMax and hpMax > 0) and (hp / hpMax * 100) or 100
    local mpP = (mpMax and mpMax > 0) and (mp / mpMax * 100) or 100
    local parts = {}
    if mpP < 40 then table.insert(parts, "wypij wodę: Z (mana " .. math.floor(mpP) .. "%)") end
    if hpP < 50 then table.insert(parts, "zjedz: X (życie " .. math.floor(hpP) .. "%)") end
    if #parts == 0 then return nil end
    return { text = "Odpocznij przed następną walką: " .. table.concat(parts, ", ") .. ".",
      why = "Na siedząco odzyskasz wszystko w kilkanaście sekund. Pić i jeść możesz naraz. Ruch przerywa odpoczynek." }
  end)
  if ok then return res end
  return nil
end

-- Kroki od najwazniejszego. Kazdy: key, text, why, btns = { { "Etykieta", funkcja }, ... }
local function buildSteps()
  local steps = {}
  local function add(key, text, why, btns, loc, count)
    if not skipped[key] then table.insert(steps, { key = key, text = text, why = why, btns = btns or {}, loc = loc, count = count }) end
  end
  local l = UnitLevel("player") or 1
  local zone = GetZoneText() or ""
  if UnitIsDeadOrGhost("player") then
    add("dead", "Biegnij jako duch do swojego ciała i kliknij Resurrect.",
      "Po Release Spirit Grimuar sam ustawia strzałkę Polestar do ciała (przycisk ustawia ją jeszcze raz). Spirit Healer psuje sprzęt i osłabia na kilka minut.",
      { { "Prowadź do ciała", function() if G.guideCorpse then pcall(G.guideCorpse, false) end end } })
    return steps
  end
  if InCombatLockdown() then
    if l < 4 then
      add("fight", "Walka: Fireball (1) z dystansu. Mało życia? Odejdź i wróć po odpoczynku.", "Od 4 poziomu Frostbolt będzie spowalniał moby.")
    elseif l < 10 then
      add("fight", "Walka: Frostbolt (1) z maksymalnej odległości, kończ Fire Blastem (2) albo różdżką (G).", "Frostbolt spowalnia, więc zdążysz rzucić drugi. Mob już przy Tobie: od razu Fire Blast. Drugi mob: Alt+R na nim, R owca. Trudny mob: Eureka! (Shift+F) przed czarem.")
    elseif l < 20 then
      add("fight", "Walka: mob dobiegł? Nova (Q), odbiegnij przodem 2–3 s, obróć się, Frostbolt (1).", "Nova trzyma do 8 s i odnawia się 25 s. Bieg tyłem (S) jest wolniejszy. Końcówka: Fire Blast (2) albo różdżka (G), która nie kosztuje many. Dwa moby: owca (R) i walcz z dala od niej, bo Nova ją zrywa.")
    elseif l < 30 then
      add("fight", "Walka: zamrożony cel → Ice Lance (3), niezamrożony → Fire Blast (2). Nova (Q), obrót, Blink (E), Frostbolt (1) i Ice Lance w locie.", "Ice Lance i Fire Blast mają wspólne 8 s odnowienia: Fire Blast tylko, gdy przez 8 s nie planujesz Novy. Mob blisko, a Nova się odnawia: Cone of Cold (4) i odejdź. Końcówka różdżką (G).")
    elseif l < 40 then
      add("fight", "Walka: Fingers of Frost → Frostbolt (1), a w locie Ice Lance (3). Mob blisko: Nova (Q), Blink (E), Frostbolt i Ice Lance.", "Fingers of Frost to 2 czary jak w zamrożony cel. Ice Lance ma 8 s odnowienia, więc drugi ładunek bierze Frostbolt. Nova się odnawia: Cone of Cold (4) i odejdź, końcówka różdżką (G).")
    elseif l < 50 then
      add("fight", "Walka: Ice Barrier (Shift+Q) przed każdym pullem, Frostbolt (1) z daleka. Mob blisko: Nova (Q), od razu Cone of Cold (4), potem Ice Lance (3).", "Tarcza trwa minutę i odnawia się 30 s: +15% obrażeń mrozu, ciosy nie wydłużają rzucania. Od 45 Frostbolty zbierają ładunki Winter's Chill, więc Cone of Cold w zamrożony cel to duży krytyk.")
    else
      add("fight", "Walka: tarcza (Shift+Q) i Eureka (Shift+F), 2 razy Frostbolt (1), potem Nova (Q), Cone of Cold (4) i Ice Lance (3).", "Manę ratuj w walce: kamień many przy połowie, Evocation (Shift+X) zamiast picia. Drugi mob: Alt+R i owca (R). Awaria: Cold Snap (Shift+R) odnawia Novę, na koniec Ice Block (Shift+E).")
    end
    return steps
  end
  local rn = restNeed()
  if rn then add("rest", rn.text, rn.why) end
  if G.partySteps then pcall(G.partySteps, add, "pilne") end -- klatwa na kims z grupy (Grupa.lua), kategoria Teraz
  if G.sessionSteps then pcall(G.sessionSteps, add) end -- plan sesji i „Kończę grę” (Sesja.lua)
  if S.budgetEnd and not (G.planActive and G.planActive()) then
    local left = math.floor((S.budgetEnd - time()) / 60)
    if left <= 10 then
      add("budget", left > 0 and ("Za " .. left .. " min koniec sesji: skończ quest i idź do karczmy.") or "Koniec sesji: wyloguj się w karczmie.",
        hearthInfo() .. ". W karczmie albo w mieście naliczy się rested XP. Prowadź: strzałka do najbliższej karczmy.",
        { { "Prowadź", function() pcall(G.guideInn) end } })
    end
  end
  if l >= 10 and talentPoints() > 0 then
    add("talent", "Wydaj punkt talentu: " .. (TALENT_AT[l] or "zobacz zakładkę Talenty") .. ".", "Talenty to darmowa moc. Klawisz N.", { { "Talenty", openTalents } })
  end
  local miss = missingTraining()
  local opt = G.optionalTraining and G.optionalTraining() or {}
  if #miss > 0 or #opt > 0 then
    local tr = nearestTrainer()
    local here
    pcall(function() here = C_Map.GetBestMapForUnit("player") end)
    local text = (#miss > 0) and ("Idź do trenera maga i kup: " .. table.concat(miss, ", ") ..
      ((#opt > 0) and ("; opcjonalnie: " .. table.concat(opt, ", ")) or "") .. ".")
      or ("U trenera maga czeka (opcjonalnie): " .. table.concat(opt, ", ") .. ".")
    add("train" .. l, text,
      "Najbliżej: " .. tr[1] .. ", " .. tr[5] .. ". Prowadź pokaże drogę. " ..
      ((#miss > 0) and "Nowe czary to największy skok mocy. " or "") ..
      ((#opt > 0) and "Opcjonalnych Frost nie potrzebuje (np. Arcane Missiles: Frostbolt robi więcej i spowalnia); kup, jeśli chcesz." or ""),
      { { "Prowadź", guideTrainer } },
      -- 14.11: strzalka sama do trenera tylko po czary z planu Frosta; same opcjonalne (Fireball 2, Arcane Missiles)
      -- zostaja krokiem z Prowadz, bez zabierania strzalki (gracz: „strzalka prowadzi teraz do Jennea Cannon”)
      (#miss > 0 and here == tr[2]) and { tr[2], tr[3], tr[4], tr[1] .. ", trener maga" } or nil)
  end
  local auraApi = (C_UnitAuras and C_UnitAuras.GetAuraDataBySpellName) or (AuraUtil and AuraUtil.FindAuraByName)
  if auraApi and not IsMounted() then
    local armorSpell = knownSpellId("Frost Armor") or knownSpellId("Ice Armor") or knownSpellId("Mage Armor")
    if armorSpell and not (hasAura("Frost Armor") or hasAura("Ice Armor") or hasAura("Mage Armor")) then
      add("armor", "Rzuć pancerz: klawisz 8.", "Pancerz daje obronę i spowalnia moby, które Cię biją.")
    end
    if knownSpellId("Arcane Intellect") and not (hasAura("Arcane Intellect") or hasAura("Arcane Brilliance")) then
      add("ai", "Rzuć Arcane Intellect: klawisz 9.", "Więcej many, czyli więcej czarów między piciem.")
    end
  end
  local hasTrack, trackOn = gatherState()
  if hasTrack and not trackOn then
    add("track", "Włącz śledzenie ziół i rudy na minimapie.", "Zioła i ruda pokażą się jako kropki i zbierzesz je po drodze na złoto. Ręcznie: lupa obok nazwy strefy nad minimapą.",
      { { "Włącz", enableGatherTracking } })
  end
  if l >= 4 and knownSpellId("Conjure Water") then
    local w = waterCount()
    if w < 10 then add("water", "Stwórz wodę: lewy klik na ikonie W (masz " .. w .. ").", "Woda z czaru jest darmowa. Zrób zapas przed wyjściem w teren.") end
  end
  local d = minDurability()
  if d and d < 25 then add("repair", "Napraw sprzęt u kupca z kowadłem (zużycie " .. math.floor(100 - d) .. "%).", "Leatrix naprawi sam, gdy otworzysz okno kupca.", { { "Do naprawy", function() pcall(G.guideVendor, true) end } }) end
  local free = freeBagSlots()
  -- 14.11: puste miejsca na torby (Vendor.lua emptyBagSlots), zawsze z prowadzeniem do kupca z torbami
  local emptyBags = G.emptyBagSlots and G.emptyBagSlots() or 0
  if emptyBags > 0 then
    add("bagslots", "Kup torby: " .. emptyBags .. " z 4 miejsc na torby " .. (emptyBags == 1 and "jest puste." or "są puste."),
      "Każda torba to więcej miejsca na łupy i zioła, czyli rzadziej do kupca. Najtańsza: Small Brown Pouch (6 miejsc) u kupca z torbami; większe (Linen Bag) w domu aukcyjnym. Załóż ją, przeciągając na wolne miejsce obok plecaka.",
      { { "Prowadź", function() pcall(G.guideBags) end } })
  end
  if G.rozwojSteps then pcall(G.rozwojSteps, add) end -- bron, rozdzka, lepszy sprzet w torbie (Rozwoj.lua)
  if G.trasaSteps then pcall(G.trasaSteps, add) end -- trasa Grimuara w Polestarze, poboczne (Trasa.lua)
  if free <= 2 then add("bags", "Zrób miejsce w torbach (wolne: " .. free .. ").", "Kliknij Do kupca: strzałka prowadzi do najbliższego, a tam Leatrix sam sprzeda szare śmieci. Większe torby kupisz w domu aukcyjnym.", { { "Do kupca", function() pcall(G.guideVendor, false) end } }) end
  if G.partySteps then pcall(G.partySteps, add, "reszta") end -- Arcane Intellect dla grupy (Grupa.lua)
  if G.groupSteps then pcall(G.groupSteps, add) end
  if G.socialSteps then pcall(G.socialSteps, add) end -- kanal grup i gildia (Grupa.lua, R16) -- przed lochem w grupie (Lochy.lua), kategoria Postać
  if G.profSteps then pcall(G.profSteps, add) end -- profesje: trener, bandaże, mikstury, zbieranie (Profesje.lua)
  if G.questAbandonSteps then pcall(G.questAbandonSteps, add) end -- bezuzyteczne zadania w dzienniku (Questy.lua, 14.11)
  local total, done = questStats()
  local guide = polestarLoaded()
  if guide then
    add("polestar", "Idź za strzałką Polestar i rób kroki z jego okna.",
      "Polestar prowadzi po questach w najlepszej kolejności dla Gnoma. Okno przewodnika: /polestar.", { { "Przewodnik", function() pcall(function() SlashCmdList["POLESTAR"]("") end) end } })
  elseif done > 0 then
    add("turnin", "Oddaj gotowe questy: " .. done .. ".", "Prowadź ustawia strzałkę do najbliższego NPC, u którego oddajesz quest. Żółty ? na mapie też to pokazuje.", { { "Prowadź", function() pcall(G.guideTurnin) end }, { "Mapa", openMap } })
  end
  local g = nearestGuide()
  if g then
    add("book" .. g[1], "W tej strefie jest książka z biblioteki: " .. g[1] .. ".",
      "Za 20 książek dostaniesz pierścień do pre-raid BiS. Kliknij Mam, gdy ją podniesiesz.",
      { { "Prowadź", function() guideTo(g) end },
        { "Mam", function() markBook(g[1]); S.undo = { g[1], function() unmarkBook(g[1]) end }; G.refreshAll() end } },
      { findMapId(g[2]), g[3], g[4], g[1] })
  end
  if not guide and total < 3 then add("pickup", "Weź nowe questy: żółte ! na minimapie i mapie.", "Bierz wszystkie w okolicy naraz i rób je w jednej pętli.", { { "Mapa", openMap } }) end
  -- Zadania etapow: najpierw zalegle z wczesniejszych etapow, potem biezacy.
  local checks = (GrimuarSetupDB.checks and GrimuarSetupDB.checks[charKey()]) or {}
  local foundTodo = false
  for _, stg in ipairs(STAGES) do
    if stg.from > l then break end
    local old = l > stg.to
    for i, t in ipairs(stg.todo) do
      local k = stg.id .. "-" .. i
      if not checks[k] then
        local hp = TODO_HELP[t]
        local auto = false
        if hp and hp.done then
          local okd, res = pcall(hp.done)
          auto = okd and res and true or false
        end
        -- quest z nazwy zadania zrobiony na postaci (Questie): odhacz sam (Questy.lua, 13.11)
        if not auto and G.todoQuestDone then
          local okq, rq = pcall(G.todoQuestDone, t)
          auto = okq and rq and true or false
        end
        if auto then
          setCheck(k)
          say("odhaczone samo: " .. t .. ".")
        else
          local function mark()
            setCheck(k)
            S.undo = { t, function() unsetCheck(k) end }
            G.refreshAll()
          end
          local loc
          if hp and hp.loc then
            if type(hp.loc) == "function" then
              local okl, r = pcall(hp.loc)
              if okl then loc = r end
            else
              loc = hp.loc
            end
          end
          -- 15.11 (R30 P30): miejsce z Polestara albo Questie; przy odswiezaniu bez wczytywania Codexu, na klik z nim
          local spec = loc
          loc = spec and G.resolveLoc and G.resolveLoc(spec, false) or nil
          local btns = {}
          if spec then
            table.insert(btns, { "Prowadź", function()
              local spot = G.resolveLoc and G.resolveLoc(spec, true)
              if spot then wayTo(spot[1], spot[2], spot[3], spot[4])
              else say("nie znam miejsca: " .. tostring(spec.label or t) .. ". Ani Polestar, ani Questie go nie podały.") end
            end })
          end
          table.insert(btns, { "Zrobione", mark })
          if old then table.insert(btns, { "Nie dotyczy", mark }) end
          local how = (hp and hp.how) or (old and "Zrób przy okazji albo kliknij Nie dotyczy, jeśli to już nieaktualne." or "Kliknij Zrobione, gdy skończysz.")
          add("todo" .. k,
            (old and "Zaległe z poprzedniego etapu: " or "Zadanie etapu: ") .. t .. ".",
            how, btns, (loc and nearLoc(loc, 0.04)) and loc or nil)
          foundTodo = true
          break
        end
      end
    end
    if foundTodo then break end
  end
  if G.questSteps then pcall(G.questSteps, add) end -- quest z listy Grimuara na Twoj poziom (Questy.lua)
  if l >= 13 and G.bestDungeon then
    local dg = G.bestDungeon(l)
    if dg then
      add("dng" .. dg[3], "Loch na Twój poziom: " .. dg[3] .. ". Zapytaj ekipę, czy idą.",
        "Raz ze wszystkimi questami: najwięcej XP i sprzętu. " .. dg[4] .. ". Przed wejściem: /loch.")
    end
  end
  if not guide then
    add("quest", "Rób questy w strefie: " .. zone .. ".", "Questie pokazuje cele na mapie (M). Kończ sesję w karczmie.", { { "Mapa", openMap } })
  end
  -- Porzadki na koncu drabiny (UX 12.11): kontrola ustawien i addonow, zbiorczo przez Ustaw wszystko
  if G.setupSteps then pcall(G.setupSteps, add) end
  return steps
end

-- eksport do pozostalych modulow
G.restNeed = restNeed
G.buildSteps = buildSteps
