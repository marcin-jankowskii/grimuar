-- Grimuar UI: wyszukiwarka wszystkiego z Polestara (15.11, R30 P29; gracz: „wyszukiwarka NPC i przedmiotow”).
-- Pole „Szukaj” na mapie huba (MapaSzukaj.lua) i /npc pytaja najpierw Polestar.Search.Query(text, { kinds, limit,
-- perKind }) (Polestar Core\Search.lua: gotowy indeks nazw Codexu, kazde wcisniecie klawisza to kilka string.find):
-- postacie, rzadkie, questy, przedmioty, receptury, wierzchowce, lochy, strefy, skarby. Wynik: jedna lista kart
-- pogrupowanych wg rodzaju (ikona rodzaju albo przedmiotu, nazwa w kolorze jakosci, podtytul Polestara po polsku:
-- „Ironforge · poziom 30”). Klik: postac, rzadki, skarb -> Prowadz (mapa huba i strzalka; miejsce z
-- Lookup.Sources(kind, id, true): najblizszy spawn w linii prostej, bez planera); przedmiot -> „Skad zdobyc” w tej samej
-- liscie (U.psSources z Ekwipunek\EkwipunekPolestar.lua, P28) i „Prowadz po to”; quest -> Dziennik (gdy jest
-- w dzienniku) albo Prowadz do zleceniodawcy; loch -> Wyprawy, PPM: Prowadz do wejscia; strefa -> mapa strefy.
-- Codex Polestara (7,7 MB) laduje sie dopiero przy pierwszym szukaniu i nigdy w walce (Data.Pack zwraca „combat”):
-- wtedy napis „W walce baza sie nie laduje” i zapas: indeks QuestieDB jak dotad. Bez Polestara: tylko Questie.
local ADDON, U = ...
local C = U.C
local G = U.G or {}

local KINDS = { npc = true, rare = true, quest = true, item = true, recipe = true, mount = true, instance = true, zone = true, treasure = true }
local ORDER = { "npc", "rare", "quest", "item", "recipe", "mount", "instance", "zone", "treasure" }
local HEAD = { npc = "Postacie", rare = "Rzadkie stwory", quest = "Questy", item = "Przedmioty", recipe = "Receptury",
  mount = "Wierzchowce", instance = "Lochy i rajdy", zone = "Strefy", treasure = "Skarby" }
local ICON = { npc = "Interface\\GossipFrame\\GossipGossipIcon", rare = "Interface\\Icons\\Ability_Hunter_SniperShot",
  quest = "Interface\\GossipFrame\\AvailableQuestIcon", instance = "Interface\\Icons\\INV_Misc_Bone_HumanSkull_01",
  zone = "Interface\\Icons\\INV_Misc_Map_01", treasure = "Interface\\Icons\\INV_Misc_Key_03" }
local ITEMISH = { item = true, recipe = true, mount = true }
local UNKNOWN_ICON = "Interface\\Icons\\INV_Misc_QuestionMark"
local PER_KIND, LIMIT = 6, 60
-- podtytul Polestara po polsku (klient angielski: zostaje angielski)
local SUB_PL = { { "Quest reward", "nagroda za quest" }, { "Given by an NPC", "od NPC" }, { "World drop", "łup ze świata" },
  { "Level", "poziom" }, { "Dungeon", "loch" }, { "Raid", "rajd" }, { "Vendor", "kupiec" }, { "Drop", "łup" },
  { "Crafted", "rzemiosło" }, { "Reputation", "reputacja" }, { "Container", "pojemnik" }, { "Treasure", "skarb" }, { "Object", "obiekt" } }

local K = { loadFailed = false }

local function PS() return _G.Polestar end
local function en() return GrimuarSetupDB and GrimuarSetupDB.lang == "en" end

-- -> "ok" | "load" (Codex do wczytania, poza walka) | "combat" | nil (zapas Questie), powod
function U.psSearchState()
  local P = PS()
  local Sr = type(P) == "table" and P.Search
  if not (Sr and type(Sr.Query) == "function" and type(Sr.Status) == "function") then return nil, "nopolestar" end
  local ok, loaded, why = pcall(Sr.Status)
  if not ok then return nil, "error" end
  if loaded then return "ok" end
  if why == "notloaded" or why == "loading" or why == "combat" then
    if InCombatLockdown() then return "combat", why end
    if K.loadFailed then return nil, "nocodex" end
    return "load", why
  end
  return nil, why -- "off" (Lookup wylaczony w Polestarze), "missing", "disabled", ...
end

local function subText(r)
  local s = r.subtitle
  if type(s) ~= "string" or s == "" then s = nil end
  if s and not en() then
    for _, p in ipairs(SUB_PL) do s = s:gsub("%f[%a]" .. p[1] .. "%f[%A]", p[2]) end
  end
  if r.status == "retired" then s = (s and (s .. " · ") or "") .. "już niedostępne"
  elseif r.status == "nosource" then s = (s and (s .. " · ") or "") .. "źródło nieznane" end
  return s
end

local function inLog(q)
  local fn = (C_QuestLog and C_QuestLog.GetLogIndexForQuestID) or _G.GetQuestLogIndexByID
  local i = U.call(fn, q)
  return U.num(i) ~= nil and i > 0
end

-- miejsca z Polestara (w linii prostej, bez planera trasy): wiersze { type, label, map, x, y, f, zone }
local function places(kind, id)
  local Lk = PS() and PS().Lookup
  if not (Lk and type(Lk.Sources) == "function") then return {} end
  local ok, list = pcall(Lk.Sources, kind, id, true)
  return ok and type(list) == "table" and list or {}
end
local function firstPlace(list, typ)
  for _, r in ipairs(list) do if type(r) == "table" and r.map and (not typ or r.type == typ) then return r end end
  for _, r in ipairs(list) do if type(r) == "table" and r.map then return r end end
end
local function guideTo(row, label, ctx)
  local m, x, y
  if row then
    m, x, y = row.map, row.x, row.y
    if U.psLive then m, x, y = U.psLive(row) end
  end
  x, y = U.num(x), U.num(y)
  if not (m and x and y) then U.say("Polestar nie zna miejsca: " .. tostring(label) .. ".") return end
  ctx.close()
  if U.mapGuide then U.mapGuide(m, x / 100, y / 100, label)
  elseif G.wayTo then pcall(G.wayTo, m, x, y, label) end
end

-- ---------- „Skad zdobyc” w liscie wynikow ----------
local function sourcesView(id, name, ctx, prev)
  local items = { { head = "Skąd zdobyć: " .. name } }
  if prev then
    items[#items + 1] = { title = "Wróć do wyników", sub = "lista wyszukiwania", icon = "Interface\\Icons\\INV_Misc_Map_01",
      r = { act = function() ctx.render(prev) end } }
  end
  -- 15.11 (gracz: „co gdzie kupic”): u kupca? wiersz „Gdzie kupic” (kupcy Polestara i Questie, MapaKupWidok.lua)
  local buy = U.buyEntry and U.buyEntry(id, name, prev)
  if buy then items[#items + 1] = buy end
  local rows, why = nil, "nopolestar"
  if U.psSources then rows, why = U.psSources(id) end
  local note
  if rows == nil then
    note = (why == "combat" and "Po walce: Polestar nie wczytuje swojej bazy w walce.") or "Polestar nie zna źródła tego przedmiotu."
  elseif #rows == 0 then
    note = "Polestar nie zna źródła tego przedmiotu."
  else
    for i = 1, math.min(6, #rows) do
      local c = U.psSourceCard and U.psSourceCard(rows[i])
      if c then
        items[#items + 1] = { title = c.title, sub = (c.sub or "") .. (c.right and ((c.sub and " · " or "") .. c.right) or ""),
          icon = c.icon, col = rows[i].available and C.gold or C.faint, tip = c.tip,
          r = { act = function() if c.onClick then ctx.close() c.onClick() else U.say("Polestar nie zna miejsca.") end end } }
      end
    end
  end
  items[#items + 1] = { title = "Prowadź po to", sub = "nowa karta przewodnika w Polestarze", icon = "Interface\\Icons\\INV_Misc_Book_09",
    tip = "Polestar buduje przewodnik po ten przedmiot i otwiera go w nowej karcie (najwyżej 6 kart).",
    r = { act = function() ctx.close() if U.psItemGuide then U.psItemGuide(id, name) end end } }
  ctx.render(items, note)
end
U.psSourcesView = sourcesView -- 15.11: „Gdzie kupic”, gdy nikt nie sprzedaje (MapaKupWidok.lua)

-- ---------- klik w karte ----------
local function act(kind, id, title, btn, ctx, prev)
  local right = btn == "RightButton"
  if ITEMISH[kind] then
    if IsShiftKeyDown() then
      local _, link = U.call(C_Item and C_Item.GetItemInfo, id)
      if link and HandleModifiedItemClick then pcall(HandleModifiedItemClick, link) end
      return
    end
    return sourcesView(id, title, ctx, prev)
  elseif kind == "quest" then
    local log = inLog(id)
    if log and not right and U.questShow then ctx.close() return U.questShow(id) end
    return guideTo(firstPlace(places("quest", id), log and "end" or "start"), (log and "Oddaj: " or "Weź: ") .. title, ctx)
  elseif kind == "instance" then
    if not right and U.wyprawyShow and U.dungeonGet and U.dungeonGet(id) then ctx.close() return U.wyprawyShow(id) end
    return guideTo(firstPlace(places("instance", id)), title .. ": wejście", ctx)
  elseif kind == "zone" then
    ctx.close()
    if U.mapShow then U.mapShow(id) end
    return
  end
  guideTo(firstPlace(places(kind, id)), title, ctx)
end

local TIP = { npc = "Klik: Prowadź (mapa i strzałka Polestar).", rare = "Klik: Prowadź do najbliższego miejsca, gdzie się pojawia.",
  treasure = "Klik: Prowadź do najbliższego miejsca.", zone = "Klik: pokaż strefę na mapie.",
  instance = "Klik: Wyprawy · PPM: Prowadź do wejścia.", item = "Klik: skąd zdobyć · Shift+klik: link na czat" }

local function card(r, ctx, prev)
  local kind, id = r.kind, r.id
  local it = { kind = kind, title = tostring(r.title or "?"), sub = subText(r), icon = ICON[kind], col = C.gold, tip = TIP[kind] }
  if ITEMISH[kind] then
    it.icon = U.call(C_Item and C_Item.GetItemIconByID, id) or UNKNOWN_ICON
    it.col = (r.quality and U.QUALITY[r.quality]) or C.text
    it.item, it.tip = id, TIP.item
  elseif kind == "quest" then
    if inLog(id) then
      it.sub = "w dzienniku" .. (it.sub and (" · " .. it.sub) or "")
      it.icon, it.col = "Interface\\GossipFrame\\ActiveQuestIcon", C.ok
      it.tip = "Klik: Dziennik · PPM: Prowadź do oddania."
    else
      it.tip = "Klik: Prowadź do zleceniodawcy."
    end
  elseif kind == "rare" then
    it.col = C.frost
  end
  it.r = { name = it.title, kind = kind, act = function(btn) act(kind, id, it.title, btn, ctx, prev) end }
  return it
end

local function query(q)
  local Sr = PS().Search
  local ok, res, counts, more = pcall(Sr.Query, q, { kinds = KINDS, limit = LIMIT, perKind = PER_KIND })
  if not ok or type(res) ~= "table" then return nil end
  return res, type(counts) == "table" and counts or {}, type(more) == "table" and more or {}
end

-- MapaSzukaj.lua run(): items = katalog miast juz przefiltrowany; ctx = { render, pick, first, auto, still, close, rerun }
-- -> true (Polestar obsluzyl) albo false, napis do zapasu Questie
function U.psSearchRun(q, items, ctx)
  local st = U.psSearchState()
  if not st then return false end
  if st == "combat" then return false, "W walce baza Polestara się nie ładuje: szukam tylko postaci (Questie)." end
  if st == "load" then
    ctx.render(items, "Ładuję bazę Polestara…")
    C_Timer.After(0.05, function()
      if not ctx.still() then return end
      if InCombatLockdown() then return ctx.rerun() end
      local X = PS() and PS().Codex
      local ok, loaded = false, false
      if X and type(X.Load) == "function" then ok, loaded = pcall(X.Load) end
      if not (ok and loaded) and not InCombatLockdown() then K.loadFailed = true end
      ctx.rerun()
    end)
    return true
  end
  local res, counts, more = query(q)
  if not res then return false, "Polestar nie odpowiedział: szukam tylko postaci (Questie)." end
  local all, seen, by = {}, {}, {}
  for _, it in ipairs(items) do
    all[#all + 1] = it
    if it.r and it.r.name then seen[it.r.name] = true end
  end
  for _, r in ipairs(res) do
    if type(r) == "table" and KINDS[r.kind] and not ((r.kind == "npc" or r.kind == "rare") and seen[r.title]) then
      by[r.kind] = by[r.kind] or {}
      table.insert(by[r.kind], r)
    end
  end
  local firstNpc
  for _, kind in ipairs(ORDER) do
    local list = by[kind]
    if list then
      local n = U.num(counts[kind]) or #list
      all[#all + 1] = { head = HEAD[kind] .. " (" .. n .. (more[kind] and "+" or "") .. ")" }
      for i, r in ipairs(list) do
        if i > PER_KIND then break end
        local it = card(r, ctx, all)
        all[#all + 1] = it
        if not firstNpc and (kind == "npc" or kind == "rare") then firstNpc = it end
      end
    end
  end
  ctx.render(all, #all == 0 and "Nic nie znalazłem (baza Polestara)." or nil)
  if ctx.auto then
    if ctx.first then ctx.pick(ctx.first)
    elseif firstNpc then firstNpc.r.act("LeftButton")
    elseif #all > 0 then U.say("nie znalazłem postaci „" .. q .. "”: zobacz listę na mapie.") end
  end
  return true
end

-- ---------- /gr test ----------
U.testChecksExtra = U.testChecksExtra or {}
table.insert(U.testChecksExtra, { "Polestar: wyszukiwarka (Search.Query, Search.Status)", function()
  local P = PS()
  if type(P) ~= "table" then return "brak Polestara (szukanie postaci w Questie)" end
  local Sr = P.Search
  if not (Sr and type(Sr.Query) == "function") then error("brak Polestar.Search.Query (Core\\Search.lua:387)") end
  if type(Sr.Status) ~= "function" then error("brak Polestar.Search.Status (Core\\Search.lua:484)") end
  local Lk = P.Lookup
  if not (Lk and type(Lk.Sources) == "function") then error("brak Polestar.Lookup.Sources (miejsca dla Prowadź)") end
  local ok, loaded, why = pcall(Sr.Status)
  if not ok then error("Search.Status: " .. tostring(loaded)) end
  local st = U.psSearchState()
  if not loaded then
    return "API jest; baza Codex jeszcze niewczytana (" .. tostring(why) .. "), wyszukiwarka: " ..
      (st == "load" and "wczyta ją przy pierwszym szukaniu" or (st == "combat" and "po walce" or "zapas Questie"))
  end
  local okQ, res = pcall(Sr.Query, "Hogger", { kinds = { npc = true }, limit = 3, subtitles = false })
  if not okQ then error("Search.Query: " .. tostring(res)) end
  if type(res) ~= "table" then error("Search.Query zwraca " .. type(res)) end
  local r = res[1]
  return "Codex wczytany; „Hogger”: " .. #res .. " wyników" .. (type(r) == "table" and (", pierwszy: " .. tostring(r.title) .. " (npc " .. tostring(r.id) .. ")") or "")
end })
