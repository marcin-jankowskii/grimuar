-- Grimuar UI: zadania profesji jak questy (14.11, gracz: „chcialbym, zeby te profesje to takie aktywne questy troche
-- byly: zbierz tyle tego, scraftuj tyle tego, to sprzedaj tu, tamto tu”).
-- Zadania licza sie same z umiejetnosci (G.readProfs) i toreb, w grupach Zbierz / Zrob / Do trenera / Sprzedaj.
-- Wiedza: plan profesji Grimuara (GrimuarSetup/Profesje.lua: przedzialy, rangi, tkaniny na bandaze, ziola na mikstury)
-- i ocena surowcow (RzemiosloSurowce.lua). Widac je w Dzienniku (J, sekcja „Profesje”) i w Rzemiosle („Zadania profesji”).
-- Ukonczenie i nowe zadanie: czat i wstega (raz). Postep sprzedazy i przetopu liczony od zapamietanego stanu
-- poczatkowego (GrimuarUIDB.profTasks[postac].snap).
local ADDON, U = ...
local G, C = U.G, U.C

local PL = { ["First Aid"] = "Pierwsza pomoc", Herbalism = "Zielarstwo", Mining = "Górnictwo", Cooking = "Gotowanie",
  Fishing = "Wędkarstwo", Tailoring = "Krawiectwo" }
local RANK_PL = { Journeyman = "Czeladnik", Expert = "Ekspert", Artisan = "Mistrz" }
-- { klucz planu, nazwa w grze, linia umiejetnosci (trenerzy w Questie) }
local PROFS = { { "firstaid", "First Aid", 129 }, { "herbalism", "Herbalism", 182 }, { "mining", "Mining", 186 },
  { "cooking", "Cooking", 185 }, { "fishing", "Fishing", 356 }, { "tailoring", "Tailoring", 197 } }
local RANK_AH = { firstaid150 = true, cooking150 = true } -- ranga z ksiazki z domu aukcyjnego
local RANK_FAR = { firstaid225 = true } -- quest Triage w Theramore: bez prowadzenia
local WOOD, FLINT = 4470, 4471
local KEEP = 10 -- „zostaw ok. 10” przy ziolach na mikstury
local NAMES = { [2589] = "Linen Cloth", [2592] = "Wool Cloth", [4306] = "Silk Cloth", [4338] = "Mageweave Cloth",
  [14047] = "Runecloth", [2447] = "Peacebloom", [2450] = "Briarthorn", [2453] = "Bruiseweed", [3357] = "Liferoot",
  [WOOD] = "Simple Wood", [FLINT] = "Flint and Tinder" }
-- przetop od tylu punktow Gornictwa (wczesniej ruda idzie na dom aukcyjny)
local SMELT = { [2770] = 1, [2771] = 65, [2775] = 75, [2772] = 125, [2776] = 155, [3858] = 175 }
local GROUPS = { "Zbierz", "Zrób", "Do trenera", "Sprzedaj" }
local GORD = { ["Zbierz"] = 1, ["Zrób"] = 2, ["Do trenera"] = 3, ["Sprzedaj"] = 4 }
U.PROF_TASK_GROUPS = GROUPS

local function bag(id)
  return U.num(U.call((C_Item and C_Item.GetItemCount) or GetItemCount, id, false)) or 0
end
local function iname(id)
  return U.call(C_Item and C_Item.GetItemNameByID, id) or NAMES[id] or ("#" .. id)
end
local function mem()
  local db = U.db()
  db.profTasks = db.profTasks or {}
  local k = U.call(G.charKey) or "?"
  db.profTasks[k] = db.profTasks[k] or {}
  local m = db.profTasks[k]
  m.snap = m.snap or {}
  return m
end
local function obj(text, done) return { text = text, done = done and true or false } end

-- postep „ile ubylo” od pierwszego zobaczenia; dolozone sztuki podnosza start
local function snapCount(m, key, now, touched)
  touched[key] = true
  local s = m.snap[key]
  if type(s) ~= "table" or not s.start then s = { start = now, last = now } m.snap[key] = s end
  if now > s.last then s.start = s.start + (now - s.last) end
  s.last = now
  return s.start - now, s.start
end

-- ---------- zadania z umiejetnosci ----------
local function skillTasks(add, profs, lvl, mats, m, touched)
  for _, p in ipairs(PROFS) do
    local key, name, line = p[1], p[2], p[3]
    local s = profs[name]
    if s and (s.rank or 0) > 0 then
      local rank, max, pl = s.rank, s.max or 0, PL[name] or name
      local base = { prof = name, profPl = pl }
      local function task(t) for k, v in pairs(base) do t[k] = t[k] or v end add(t) return t end
      local b = U.call(G.profBand, key, rank)
      local capped = max > 0 and max < 300 and rank >= max
      local nxt = G.PROF_RANKS and G.PROF_RANKS[key] and G.PROF_RANKS[key][max]
      -- ranga: gdy blisko progu rangi albo limitu
      if nxt and (rank >= nxt[2] - 10 or rank >= max - 10) then
        local rk = RANK_PL[nxt[1]] or nxt[1]
        local okS, okL = rank >= nxt[2], lvl >= nxt[3]
        local book = RANK_AH[key .. max]
        task({ key = "rank-" .. key .. max, group = "Do trenera", kind = "trainer", announce = true,
          title = "Ranga " .. rk .. ": " .. pl, tag = (okS and okL) and "teraz" or (rank .. " / " .. nxt[2]),
          objs = { obj("Umiejętność: " .. rank .. " / " .. nxt[2], okS), obj("Poziom postaci: " .. lvl .. " / " .. nxt[3], okL),
            obj(book and "Kup książkę na domu aukcyjnym i użyj jej" or "Naucz się rangi u trenera", false) },
          where = (book and "Gdzie: " or "Trener: ") .. nxt[4] .. ".",
          why = "Bez rangi " .. pl .. " stoi na " .. max .. ", a każdy kolejny craft albo zbiór przepada.",
          nav = (not RANK_FAR[key .. max]) and (book and "Auctioneer" or ("prof" .. line)) or nil,
          navLabel = book and "dom aukcyjny" or "trener" })
      end
      if b and not capped and not (key == "fishing" and rank >= 20) then
        local target = math.min(b[2], 300)
        if max > 0 and max < target then target = max end
        local left = math.max(0, target - rank)
        local skillObj = obj(pl .. ": " .. rank .. " / " .. target, rank >= target)
        local tag = rank .. " / " .. target
        if left <= 0 then
          -- nic
        elseif key == "firstaid" then
          local cl
          for _, c in ipairs(G.PROF_CLOTH or {}) do if rank >= c[1] and rank < c[2] then cl = c break end end
          if cl then
            local reserve = (cl[3] == 2589 and lvl <= 15) and 10 or 0
            local have = math.max(0, bag(cl[3]) - reserve)
            local need = left * cl[4]
            local cloth = iname(cl[3])
            task({ key = "craft-firstaid-" .. target, group = "Zrób", kind = "craft", announce = true, tag = tag,
              title = "Zrób ok. " .. left .. "× " .. cl[5],
              objs = { skillObj, obj(cloth .. " w torbach: " .. math.min(have, need) .. " / " .. need ..
                (reserve > 0 and " (10 zostaw na Manaweave Robe)" or ""), have >= need) },
              where = "Okno Pierwszej pomocy: hub › Rzemiosło albo klawisz K. " .. cl[5] .. " to " .. cl[4] .. "× " .. cloth ..
                "; zwykle punkt za sztukę, póki przepis jest pomarańczowy albo żółty.",
              why = "Plan: " .. b[4] .. "." })
            if have < need then
              task({ key = "gather-cloth-" .. cl[3], group = "Zbierz", kind = "gather", tag = have .. " / " .. need,
                title = "Zbierz jeszcze " .. (need - have) .. "× " .. cloth,
                objs = { obj(cloth .. ": " .. have .. " / " .. need, false) },
                where = "Tkanina wypada z humanoidów (bandyci, trogi, koboldy). Gdzie: " .. b[5] .. ".",
                why = "Na bandaże do " .. target .. " Pierwszej pomocy." })
            end
          end
        elseif key == "cooking" then
          local meat = 0
          for _, it in ipairs(mats) do if it.verdict == "gotuj" then meat = meat + (it.count or 0) end end
          local wood, flint = bag(WOOD), bag(FLINT)
          task({ key = "craft-cooking-" .. target, group = "Zrób", kind = "craft", announce = true, tag = tag,
            title = "Ugotuj ok. " .. left .. " dań przy ognisku",
            objs = { skillObj, obj("Mięso w torbach: " .. math.min(meat, left) .. " / " .. left, meat >= left),
              obj(iname(WOOD) .. " (na ognisko): " .. wood, wood > 0), obj(iname(FLINT) .. ": " .. (flint > 0 and "masz" or "brak"), flint > 0) },
            where = "Basic Campfire z księgi Gotowania, potem okno Gotowania przy ognisku. Simple Wood i Flint and Tinder sprzedaje kupiec z towarami (np. Kreg Bilmn w Kharanos).",
            why = "Plan: " .. b[4] .. "." })
          if meat < left then
            task({ key = "gather-meat", group = "Zbierz", kind = "gather", tag = meat .. " / " .. left,
              title = "Zbierz ok. " .. (left - meat) .. " mięsa",
              objs = { obj("Mięso: " .. meat .. " / " .. left, false) },
              where = "Dziki, wilki, niedźwiedzie. Gdzie: " .. b[5] .. ".",
              why = "Na Gotowanie do " .. target .. "." })
          end
        elseif key == "herbalism" or key == "mining" then
          task({ key = "gather-" .. key .. "-" .. target, group = "Zbierz", kind = "gather", announce = true, tag = tag,
            title = (key == "herbalism" and ("Zbierz ok. " .. left .. " ziół") or ("Wykop ok. " .. left .. " złóż rudy")),
            objs = { skillObj },
            where = "Gdzie: " .. b[5] .. ". Miejsca pokazuje GatherMate2 (hub › Mapa › Zbieranie).",
            why = "Co: " .. b[4] .. ". Zwykle punkt za zbiór; szare złoża i zioła nic nie dają." })
        elseif key == "fishing" then
          task({ key = "fish-20", group = "Zbierz", kind = "gather", announce = true, tag = tag,
            title = "Łów ryby do 20", objs = { skillObj },
            where = "Gdzie: " .. b[5] .. ".", why = b[4] .. "." })
        else
          task({ key = "craft-" .. key .. "-" .. target, group = "Zrób", kind = "craft", announce = true, tag = tag,
            title = pl .. " do " .. target, objs = { skillObj }, where = "Gdzie: " .. b[5] .. ".", why = "Plan: " .. b[4] .. "." })
        end
      end
      -- First Aid w Forever robi mikstury z ziol
      if key == "firstaid" then
        for id, h in pairs(G.PROF_POTIONS or {}) do
          local n = bag(id)
          if rank >= h[1] and n > 0 then
            task({ key = "potion-" .. id, group = "Zrób", kind = "craft", tag = "masz " .. n,
              title = "Zrób " .. h[2] .. " z " .. iname(id),
              objs = { obj(iname(id) .. " w torbach: " .. n, true) },
              where = "Okno Pierwszej pomocy (w Forever robi też mikstury). Przepis u trenera albo z manuala.",
              why = "Mikstura działa od razu, także w walce; zioła na domu aukcyjnym tanieją." })
          end
        end
      end
      -- Gornictwo: ruda do przetopu (punkty za wytapianie)
      if key == "mining" then
        for _, it in ipairs(mats) do
          local req = SMELT[it.id]
          if it.verdict == "przetop" and req and rank >= req and (it.count or 0) > 0 then
            local done, start = snapCount(m, "smelt-" .. it.id, it.count, touched)
            task({ key = "smelt-" .. it.id, group = "Zrób", kind = "smelt", tag = done .. " / " .. start,
              title = "Przetop " .. it.count .. "× " .. it.name,
              objs = { obj("Przetopione: " .. done .. " / " .. start, false) },
              where = "Kuźnia: Kharanos (przy karczmie) albo Wielka Kuźnia w Ironforge. Wytapianie: hub › Rzemiosło › Górnictwo.",
              why = it.text })
          end
        end
      end
    end
  end
end

-- ---------- sprzedaz ----------
local function sellTasks(add, profs, mats, m, touched)
  local mining = profs.Mining and profs.Mining.rank or 0
  local cur = { ah = {}, kupiec = {} }
  for _, it in ipairs(mats) do
    local v, n = it.verdict, it.count or 0
    if v == "zostaw" and n > KEEP then v, n = "ah", n - KEEP end
    if v == "przetop" and (not SMELT[it.id] or mining < SMELT[it.id]) then v = "ah" end
    if v == "kupiec" and (it.quality or 1) == 0 then v = nil end -- szare sprzedaje Leatrix sam
    if cur[v] and n > 0 then cur[v][it.id] = { n = n, name = it.name, text = it.text } end
  end
  local SPEC = {
    ah = { title = "Sprzedaj na domu aukcyjnym", nav = "Auctioneer", navLabel = "dom aukcyjny",
      where = "Dom aukcyjny: Ironforge, The Commons. Zioła i rudę wystawiaj całymi stackami po 20; cenę podpowie Rynek Grimuara." },
    kupiec = { title = "Sprzedaj kupcowi", nav = "Repair", navLabel = "kupiec",
      where = "Dowolny kupiec. Szare rzeczy Leatrix sprzedaje sam przy otwarciu okna kupca." },
  }
  for _, v in ipairs({ "ah", "kupiec" }) do
    local sk = "sell-" .. v
    local snap = type(m.snap[sk]) == "table" and m.snap[sk] or {}
    for id, e in pairs(cur[v]) do
      local s = snap[id]
      if not s or e.n > s.n then snap[id] = { n = e.n, name = e.name, text = e.text } end
    end
    local rows, left, total = {}, 0, 0
    for id, s in pairs(snap) do
      local now = cur[v][id] and cur[v][id].n or 0
      total = total + 1
      if now > 0 then left = left + 1 end
      rows[#rows + 1] = { name = s.name or iname(id), now = now, text = s.text }
    end
    if left == 0 then
      m.snap[sk] = nil
    else
      m.snap[sk] = snap
      touched[sk] = true
      table.sort(rows, function(a, b) return a.name < b.name end)
      local objs, why = {}, {}
      for _, r in ipairs(rows) do
        objs[#objs + 1] = obj(r.name .. (r.now > 0 and ("  × " .. r.now) or ": sprzedane"), r.now == 0)
        if r.now > 0 and r.text then why[#why + 1] = r.name .. ": " .. r.text end
      end
      local S = SPEC[v]
      add({ key = sk, group = "Sprzedaj", kind = "sell", tag = (total - left) .. " / " .. total, title = S.title,
        objs = objs, where = S.where, why = table.concat(why, "\n"), nav = S.nav, navLabel = S.navLabel, profPl = "surowce z toreb" })
    end
  end
end

-- ---------- lista ----------
local cache, cacheAt
function U.profTasks()
  if cache and cacheAt and GetTime() - cacheAt < 1 then return cache end
  local list = {}
  local function add(t) list[#list + 1] = t end
  local profs = U.call(G.readProfs) or {}
  local lvl = UnitLevel("player") or 1
  local mats = U.bagMaterials and U.bagMaterials() or {}
  local m = mem()
  local touched = {}
  local ok1, e1 = pcall(skillTasks, add, profs, lvl, mats, m, touched)
  if not ok1 and U.logError then U.logError("profTasks/skill", e1) end
  local ok2, e2 = pcall(sellTasks, add, profs, mats, m, touched)
  if not ok2 and U.logError then U.logError("profTasks/sell", e2) end
  for k in pairs(m.snap) do if not touched[k] then m.snap[k] = nil end end
  for i, t in ipairs(list) do t.ord = i end
  table.sort(list, function(a, b)
    if a.group ~= b.group then return (GORD[a.group] or 9) < (GORD[b.group] or 9) end
    return a.ord < b.ord
  end)
  cache, cacheAt = list, GetTime()
  return list
end

-- tekst celow do pola opisu (Rzemioslo)
function U.profTaskText(t)
  local lines = {}
  for _, o in ipairs(t.objs or {}) do
    lines[#lines + 1] = (o.done and (U.hex(C.ok) .. "◆ ") or (U.hex(C.text) .. "◇ ")) .. o.text .. "|r"
  end
  return table.concat(lines, "\n") .. "\n\n" .. (t.where or "") .. ((t.why and t.why ~= "") and ("\n\n" .. U.hex(C.muted) .. t.why .. "|r") or "")
end

-- Prowadz: najblizszy aukcjoner / kupiec / trener (katalog postaci z Questie, MapaUslugi.lua)
function U.profTaskGuide(t)
  if not (t and t.nav and U.serviceDirectory) then return false end
  U.serviceDirectory(function(groups)
    local px, py
    local here = U.call(C_Map.GetBestMapForUnit, "player")
    local pos = here and U.call(C_Map.GetPlayerMapPosition, here, "player")
    if pos then pcall(function() px, py = pos:GetXY() end) end
    local best, bd
    for gi, g in ipairs(groups or {}) do
      for _, e in ipairs(g.entries or {}) do
        if e.keys and e.keys[t.nav] then
          local d = (g.here and px) and ((e.x - px) ^ 2 + (e.y - py) ^ 2) or (100 + gi)
          if not bd or d < bd then best, bd = e, d end
        end
      end
    end
    if not best then U.say("nie znam miejsca: " .. (t.navLabel or "?") .. ". Zobacz opis zadania.") return end
    local label = t.title .. ": " .. best.name
    if G.wayTo then pcall(G.wayTo, best.map, tonumber(string.format("%.2f", best.x * 100)), tonumber(string.format("%.2f", best.y * 100)), label) end
    local info = U.call(C_Map.GetMapInfo, best.map)
    U.say("prowadzę: " .. label .. " (" .. (info and info.name or "?") .. ").")
  end)
  return true
end

-- ---------- ukonczone i nowe: czat i wstega ----------
G.profTasksActive = true -- komunikaty progow z Profesje.lua zastepuja te zadania
local function check()
  cache = nil
  local ok, list = pcall(U.profTasks)
  if not ok or type(list) ~= "table" then return end
  local m = mem()
  local cur = {}
  for _, t in ipairs(list) do cur[t.key] = t end
  if m.active then
    local done, new = {}, {}
    for k, title in pairs(m.active) do
      if not cur[k] then done[#done + 1] = title end
    end
    for k, t in pairs(cur) do
      if not m.active[k] and t.announce then new[#new + 1] = t.title end
    end
    if #done > 0 or #new > 0 then
      local txt = ((#done > 0) and ("Zadanie profesji ukończone: " .. table.concat(done, "; ") .. ".") or "") ..
        ((#new > 0) and (((#done > 0) and " " or "") .. "Nowe: " .. table.concat(new, "; ") .. ".") or "")
      U.say(txt .. " (Dziennik: J)")
      if G.showToast then pcall(G.showToast, txt, "prof", false) end
    end
  end
  m.active = {}
  for k, t in pairs(cur) do m.active[k] = t.title end
end

local pending = false
local function later(sec)
  if pending then return end
  pending = true
  C_Timer.After(sec or 1.5, function() pending = false pcall(check) end)
end
local ev = CreateFrame("Frame")
for _, e in ipairs({ "PLAYER_LOGIN", "SKILL_LINES_CHANGED", "CHAT_MSG_SKILL", "BAG_UPDATE_DELAYED", "PLAYER_LEVEL_UP" }) do
  pcall(ev.RegisterEvent, ev, e)
end
local ready = false
ev:SetScript("OnEvent", function(_, e)
  if e == "PLAYER_LOGIN" then
    C_Timer.After(10, function() ready = true pcall(check) end) -- torby i nazwy przedmiotow sa juz wczytane
  elseif ready then
    later(e == "BAG_UPDATE_DELAYED" and 2 or 1)
  end
end)
