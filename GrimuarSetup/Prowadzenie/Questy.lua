-- Grimuar: modul Questy (pytanie gracza 13.11: czy questy sa sprawdzane na postaci). Stan questow z listy Grimuara
-- (QUESTS w Core.lua i zadania etapow z nazwa w „…”) czytany z postaci:
-- * zrobione: Questie (Questie.db.char.complete, ID z bazy Questie po nazwie questa),
-- * w dzienniku: dziennik questow gry (po tytule),
-- * reszta: do wziecia.
-- Indeks nazwa -> ID budowany raz po wejsciu, po kawalku (bez przyciecia gry). Bez Questie: tylko stan „w dzienniku”.
local ADDON_NAME, G = ...

local wanted = {}     -- nazwa questa -> true
local ids = {}        -- nazwa -> { id, id, ... }
local indexReady = false

-- „Nazwa” z tekstu (polskie cudzyslowy z listy Grimuara)
local function questName(text)
  return text and text:match("„([^”]+)”")
end

local function collectWanted()
  for _, q in ipairs(G.QUESTS or {}) do
    local n = questName(q[2])
    if n then wanted[n] = true end
  end
  for _, st in ipairs(G.STAGES or {}) do
    for _, t in ipairs(st.todo or {}) do
      local n = questName(t)
      if n then wanted[n] = true end
    end
  end
end

-- Indeks po kawalku: 400 questow na klatke
local function buildIndex()
  local QDB = QuestieLoader and QuestieLoader:ImportModule("QuestieDB")
  local ptrs = QDB and QDB.QuestPointers
  if not (QDB and QDB.QueryQuestSingle and type(ptrs) == "table") then indexReady = true return end
  local list = {}
  for k, v in pairs(ptrs) do
    local id = (type(k) == "number" and k) or (type(v) == "number" and v) or nil
    if id then list[#list + 1] = id end
  end
  local i = 0
  local ticker
  ticker = C_Timer.NewTicker(0.05, function()
    for _ = 1, 400 do
      i = i + 1
      local id = list[i]
      if not id then
        indexReady = true
        ticker:Cancel()
        if G.refreshAll then pcall(G.refreshAll) end
        return
      end
      local ok, name = pcall(QDB.QueryQuestSingle, id, "name")
      if ok and name and wanted[name] then
        ids[name] = ids[name] or {}
        table.insert(ids[name], id)
      end
    end
  end)
end

local function inLog(name)
  local found = false
  pcall(function()
    local n = C_QuestLog.GetNumQuestLogEntries()
    for i = 1, n do
      local info = C_QuestLog.GetInfo(i)
      if info and not info.isHeader and info.title == name then found = true return end
    end
  end)
  return found
end

local function completed(name)
  local list = ids[name]
  if not list then return false end
  local done = false
  pcall(function()
    local comp = Questie and Questie.db and Questie.db.char and Questie.db.char.complete
    for _, id in ipairs(list) do
      if (comp and comp[id]) or (C_QuestLog.IsQuestFlaggedCompleted and C_QuestLog.IsQuestFlaggedCompleted(id)) then done = true return end
    end
  end)
  return done
end

-- "done" | "log" | "todo" | nil (nazwa nieznana albo indeks jeszcze sie buduje)
local function status(name)
  if not name then return nil end
  if completed(name) then return "done" end
  if inLog(name) then return "log" end
  -- bez ID z Questie (nazwa nieznana bazie) nie zgadujemy: brak znacznika zamiast falszywego „do wziecia”
  if not indexReady or not ids[name] then return nil end
  return "todo"
end

local TAG = { done = "|cff7cc68b[zrobiony]|r ", log = "|cffd8b25a[w dzienniku]|r ", todo = "|cff9a958b[do wzięcia]|r " }

-- Etykieta do okna: tekst questu z lista z przodu stanem
local function questLabel(text)
  local st = status(questName(text))
  return (st and TAG[st] or "") .. text
end

-- Zadanie etapu odhacza sie samo, gdy quest z jego nazwy jest zrobiony
local function todoQuestDone(text)
  return status(questName(text)) == "done"
end

-- Krok na pasku (Etap): najblizszy quest z listy Grimuara na Twoj poziom, ktorego nie zrobiles
local function questSteps(add)
  local l = UnitLevel("player") or 1
  for _, q in ipairs(G.QUESTS or {}) do
    if q[1] <= l and l <= q[1] + 6 then
      local n = questName(q[2])
      local st = status(n)
      if st == "log" then
        add("questmag-" .. n, "Dokończ quest „" .. n .. "”.", q[3], nil)
        return
      elseif st == "todo" then
        add("questmag-" .. n, "Do wzięcia: " .. q[2] .. ".", q[3], nil)
        return
      end
    end
  end
end

local ev = CreateFrame("Frame")
ev:RegisterEvent("PLAYER_LOGIN")
ev:RegisterEvent("QUEST_TURNED_IN")
ev:RegisterEvent("QUEST_ACCEPTED")
ev:SetScript("OnEvent", function(_, event)
  if event == "PLAYER_LOGIN" then
    pcall(collectWanted)
    C_Timer.After(25, function() pcall(buildIndex) end) -- po wczytaniu bazy Questie
  else
    C_Timer.After(1, function() if G.refreshAll then pcall(G.refreshAll) end end)
  end
end)

G.questStatus = status
G.questLabel = questLabel
G.todoQuestDone = todoQuestDone
G.questSteps = questSteps
G.questIndexReady = function() return indexReady end
G.questIds = function(name) return ids[name] end -- ID z bazy Questie dla questow z listy Grimuara (Vendor.lua guideQuest)

-- ---------- 14.11 (gracz: „fajnie jakby Grimuar sprawdzal moje aktywne questy. Czy mam cos bezuzytecznego i mowil,
-- zeby to abandonowac”). Ocena kazdego zadania z dziennika:
-- * oddaj: gotowe;
-- * porzuc: szare (gra daje za nie ulamek doswiadczenia), grupowe spoza trasy, zadania ze strefy, ktorej nie ma na trasie;
-- * grupa: loch albo elita z trasy (zostaw, gdy idziesz z grupa); pozniej: za trudne teraz.
-- Trasa = zadania z przewodnikow Polestara dla etapow Grimuara (Trasa.lua TRASA: biezacy i nastepne, z pobocznymi).
local routeCache = {}
local function routeQuests()
  local l = UnitLevel("player") or 1
  if routeCache.l == l and GetTime() - (routeCache.at or 0) < 300 then return routeCache.ids, routeCache.zones end
  local ids, zones, any = {}, {}, false
  local PG = Polestar and Polestar.Guides
  for _, leg in ipairs(G.TRASA or {}) do
    if leg[2] >= l - 1 and leg[1] <= l + 6 then
      for z in tostring(leg[3] or ""):gmatch("[^,]+") do zones[(z:gsub("^%s+", ""):gsub("%s+$", ""))] = true end
      local list = { leg[4] }
      for _, s in ipairs(leg.side or {}) do list[#list + 1] = s[2] end
      for _, gid in ipairs(list) do
        local ok, steps = pcall(function() local g = PG and PG.Get and PG.Get(gid) return g and g.steps end)
        if ok and type(steps) == "table" then
          any = true
          for _, st in ipairs(steps) do
            for _, goal in ipairs(type(st.goals) == "table" and st.goals or {}) do
              if type(goal) == "table" and goal.quest then ids[goal.quest] = true end
            end
          end
        end
      end
    end
  end
  -- stolice Przymierza: zadania stamtad zwykle prowadza dalej, nie oceniamy ich po strefie
  zones["Ironforge"], zones["Stormwind City"], zones["Darnassus"], zones["Stormwind"] = true, true, true, true
  routeCache = { l = l, at = GetTime(), ids = any and ids or nil, zones = zones }
  return routeCache.ids, zones
end

local function isGray(qlvl, l)
  local ok, c = pcall(GetQuestDifficultyColor, qlvl)
  if ok and type(c) == "table" and type(QuestDifficultyColors) == "table" and QuestDifficultyColors.trivial then
    return c == QuestDifficultyColors.trivial
  end
  local r
  pcall(function() r = UnitQuestTrivialLevelRange and UnitQuestTrivialLevelRange("player") end)
  if type(r) ~= "number" then pcall(function() r = GetQuestGreenRange and GetQuestGreenRange() end) end
  if type(r) ~= "number" then r = l <= 5 and 99 or (l < 40 and 5 + math.floor(l / 10) or 1 + math.floor(l / 5)) end
  return qlvl - l < -r
end

-- { id, title, level, zone, verdict = "oddaj"|"porzuc"|"grupa"|"pozniej"|nil, why }, liczba w dzienniku, limit
local function advice()
  local out, n = {}, 0
  local l = UnitLevel("player") or 1
  local route, zones = routeQuests()
  pcall(function()
    local header
    for i = 1, C_QuestLog.GetNumQuestLogEntries() do
      local info = C_QuestLog.GetInfo(i)
      if info and info.isHeader then
        header = info.title
      elseif info and not info.isHidden and info.questID then
        n = n + 1
        local id, lvl, grp = info.questID, info.level or l, info.suggestedGroup or 0
        local a = { id = id, title = info.title or "?", level = lvl, zone = header }
        local keep = wanted[a.title] or (route and route[id])
        local isZone = header and G.findMapId and G.findMapId(header) ~= nil
        if C_QuestLog.IsComplete(id) then
          a.verdict = "oddaj"
        elseif isGray(lvl, l) and not keep then
          a.verdict, a.why = "porzuc", "szary (poziom " .. lvl .. "): gra daje za niego ułamek doświadczenia"
        elseif grp > 1 and not keep then
          a.verdict, a.why = "porzuc", "dla grupy (" .. grp .. " os.), a Grimuar go nie planuje"
        elseif route and not keep and isZone and not zones[header] then
          a.verdict, a.why = "porzuc", "strefa " .. header .. " nie jest na Twojej trasie"
        elseif grp > 1 then
          a.verdict, a.why = "grupa", "dla grupy (" .. grp .. " os.): zostaw na wyjście z grupą"
        elseif lvl >= l + 4 then
          a.verdict, a.why = "pozniej", "za trudny teraz (poziom " .. lvl .. ")"
        end
        out[#out + 1] = a
      end
    end
  end)
  local max = 20
  pcall(function() max = (C_QuestLog.GetMaxNumQuestsCanAccept and C_QuestLog.GetMaxNumQuestsCanAccept()) or MAX_QUESTS or 20 end)
  return out, n, max
end

local function abandon(id, title)
  if InCombatLockdown() then return end
  pcall(C_QuestLog.SetSelectedQuest, id)
  pcall(C_QuestLog.SetAbandonQuest)
  pcall(StaticPopup_Show, "ABANDON_QUEST", title)
end

-- krok na pasku Grimuara (Kroki.lua): co porzucic; przycisk otwiera okno potwierdzenia gry
local function abandonSteps(add)
  local list, n, max = advice()
  local bad = {}
  for _, a in ipairs(list) do if a.verdict == "porzuc" then bad[#bad + 1] = a end end
  if #bad == 0 then return end
  local names, whys = {}, {}
  for i, a in ipairs(bad) do
    if i <= 3 then names[#names + 1] = "„" .. a.title .. "”" end
    whys[#whys + 1] = a.title .. ": " .. a.why
  end
  local first = bad[1]
  local btns = { { "Porzuć pierwszy", function() abandon(first.id, first.title) end } }
  if GrimuarHubOpen then btns[2] = { "Dziennik", function() pcall(GrimuarHubOpen, "dziennik") end } end
  add("porzuc", "Porzuć " .. (#bad == 1 and "zadanie bez wartości: " or (#bad .. " zadań bez wartości: ")) .. table.concat(names, ", ") ..
    (#bad > 3 and " i inne" or "") .. ".", table.concat(whys, ". ") .. ". Dziennik: " .. n .. " z " .. max .. ". Gra pyta o potwierdzenie.", btns)
end

G.questAdvice = advice
G.questAbandon = abandon
G.questAbandonSteps = abandonSteps
