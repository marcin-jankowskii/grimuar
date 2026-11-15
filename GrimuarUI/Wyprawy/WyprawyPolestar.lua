-- Grimuar UI: Wyprawy z danymi Polestara, etap 2 (15.11, R30 P47 i P27; gracz: „wstepnie wszystko jak rekomendujesz”).
-- * P47: ile poziomu daja questy lochu: Polestar.Dungeons.QuestXP(key) (Dungeons\XP.lua:20 -> podsumowanie
--   Levels.Run: levels, quests, xp, below, done, other, unknown), karta lochu: „+1,4 poziomu z questów lochu”;
-- * P27: limit wejsc do instancji: Polestar.Maps.GetInstanceStatus() (Maps\Instances.lua:252 -> inHour, inDay, perHour,
--   perDay, wait, clears; sekundy), „Wejścia: 3/5 w tej godzinie · kolejne za 12 min”; bez Polestara zostaje licznik
--   Grimuara (WyprawyDane.lua U.instanceEntries);
-- * czas dojscia do wejscia na przycisku „Prowadź do wejścia” (G.etaText, wejscie z ramki Era przez U.psLive).
-- Liczone przy odswiezeniu zakladki (klik), QuestXP z pamiecia na loch do zmiany poziomu albo 60 s.
local ADDON, U = ...
local G, C = U.G or {}, U.C

local K = { xp = {} }
local MUTED, GOLD = U.hex(C.muted), U.hex(C.gold)

local function PS() return _G.Polestar end
local function plural(n, one, few, many)
  if n == 1 then return one end
  local d, h = n % 10, n % 100
  if d >= 2 and d <= 4 and (h < 12 or h > 14) then return few end
  return many
end
local function mins(s)
  s = math.max(0, math.ceil((U.num(s) or 0) / 60))
  if s < 60 then return s .. " min" end
  return math.floor(s / 60) .. " h " .. (s % 60) .. " min"
end

-- ---------- P47: XP z questow lochu ----------
function U.dungeonQuestXP(key)
  local D = PS() and PS().Dungeons
  if not (D and type(D.QuestXP) == "function") or not key or key:sub(1, 1) == "_" then return nil end
  local lvl = UnitLevel("player") or 1
  local c = K.xp[key]
  if c and c.lvl == lvl and GetTime() - c.at < 60 then return c.s end
  local ok, s = pcall(D.QuestXP, key)
  s = ok and type(s) == "table" and s or nil
  K.xp[key] = { s = s, lvl = lvl, at = GetTime() }
  return s
end

-- jedna linia do karty lochu albo nil
function U.dungeonQuestXPLine(key)
  local s = U.dungeonQuestXP(key)
  if not s then return nil end
  local n, lv = U.num(s.quests) or 0, U.num(s.levels) or 0
  if n == 0 then
    if (U.num(s.done) or 0) > 0 then return MUTED .. "Questy lochu: wszystkie dla Ciebie już zrobione.|r" end
    return nil
  end
  local lvTxt = (string.format("%.1f", lv):gsub("%.", ","))
  local extra = { n .. " " .. plural(n, "quest", "questy", "questów"), U.thousands(s.xp) .. " XP" }
  if U.num(s.below) then extra[#extra + 1] = "licząc od poziomu " .. s.below end
  if (U.num(s.unknown) or 0) > 0 then extra[#extra + 1] = s.unknown .. " bez danych XP" end
  return GOLD .. "+" .. lvTxt .. " poziomu z questów lochu|r" .. MUTED .. " (" .. table.concat(extra, " · ") .. ")|r"
end

-- ---------- P27: limit wejsc ----------
function U.instanceStatus()
  local M = PS() and PS().Maps
  if not (M and type(M.GetInstanceStatus) == "function") then return nil end
  local ok, st = pcall(M.GetInstanceStatus)
  if not ok or type(st) ~= "table" or not U.num(st.inHour) then return nil end
  return st
end

-- linia „Wejścia: 3/5 w tej godzinie · kolejne za 12 min” (z kolorem) albo nil bez Polestara
function U.instanceStatusLine()
  local st = U.instanceStatus()
  if not st then return nil end
  local per, n = U.num(st.perHour) or 5, U.num(st.inHour) or 0
  local wait, clears = U.num(st.wait) or 0, U.num(st.clears)
  local line = "Wejścia: " .. n .. "/" .. per .. " w tej godzinie"
  if wait > 0 then
    line = line .. " · " .. U.hex(C.danger) .. "kolejne za " .. mins(wait) .. "|r"
  else
    line = line .. " · " .. U.hex(C.ok) .. "możesz wejść|r"
    if n > 0 and clears and clears > 0 then line = line .. MUTED .. " · miejsce zwolni się za " .. mins(clears) .. "|r" end
  end
  local perDay = U.num(st.perDay) or 0
  if perDay > 0 then line = line .. MUTED .. " · doba " .. (U.num(st.inDay) or 0) .. "/" .. perDay .. "|r" end
  return line
end

-- ---------- czas dojscia do wejscia ----------
function U.dungeonEntranceEta(d)
  local e = type(d) == "table" and d.entrance
  if type(e) ~= "table" or not (e.map and e.x and e.y) or not G.etaText then return "" end
  local m, x, y = e.map, e.x, e.y
  if U.psLive then m, x, y = U.psLive(e) end
  x, y = U.num(x), U.num(y)
  if not (m and x and y) then return "" end
  if x <= 1 and y <= 1 then x, y = x * 100, y * 100 end -- wejscie w ulamkach zamiast procentow
  return U.call(G.etaText, m, x, y) or ""
end

-- ---------- 15.11 (R30 P46): zbierz questy, oddaj po lochu, zestrojenia ----------
-- * Dungeons.PickupPlan(key) (Dungeons\Pickup.lua:627 -> { take = { { quest, giver, pre } }, carried, done, later,
--   waiting }) i na klik Dungeons.PickUp(key) (Pickup.lua:1197: przewodnik „lookup/pickup/<key>” w nowej karcie);
-- * Dungeons.HandinPlan(key) (Dungeons\Handin.lua:102 -> { hand = { { quest, ender } }, unfinished, inside, unplaced })
--   i na klik Dungeons.HandIn(key) (Handin.lua:323);
-- * Dungeons.Attunements(key, "A") (Dungeons\Dungeons.lua:481) i AttunementState(a) (Dungeons\Attune.lua:116 -> { done,
--   steps = { { step, state } }, next, left }), na klik Dungeons.Attune(key, id) (Attune.lua:380).
-- Plany licza trase planerem, wiec tylko przy otwarciu strony Questy wybranego lochu, w pamieci 30 s albo do zmiany
-- w dzienniku questow; nigdy w walce. Akcje otwierajace karte przewodnika tylko na klik, limit 6 kart mowi U.psTabsSay.
local PLAN_TTL = 30
local QUEST_ICON, TURNIN_ICON = "Interface\\GossipFrame\\AvailableQuestIcon", "Interface\\GossipFrame\\ActiveQuestIcon"
local ATT_ICON = "Interface\\Icons\\INV_Misc_Key_03"
K.plan = {}

local function tr(s) return (G.tr and type(s) == "string") and G.tr(s) or s end -- tlumaczenie kawalkow (jezyk huba)
local function mapName(map)
  local i = map and U.call(C_Map.GetMapInfo, map)
  return type(i) == "table" and i.name or nil
end
-- punkt Polestara { map, x, y, f } -> map, x, y (procenty) albo nil
local function point(p)
  if type(p) ~= "table" then return nil end
  local m, x, y = p.map, p.x, p.y
  if U.psLive then m, x, y = U.psLive(p) end
  x, y = U.num(x), U.num(y)
  if not (m and x and y) then return nil end
  if x <= 1 and y <= 1 then x, y = x * 100, y * 100 end
  return m, x, y
end
local function guide(p, label)
  local m, x, y = point(p)
  if not (m and G.wayTo) then U.say("Polestar nie podał miejsca: " .. tostring(label) .. ".") return end
  pcall(G.wayTo, m, tonumber(string.format("%.2f", x)), tonumber(string.format("%.2f", y)), label)
  if U.IsOpen and U.IsOpen() then U.Close() end
end
local function eta(p)
  local m, x, y = point(p)
  if not (m and G.etaText) then return "" end
  return U.call(G.etaText, m, x, y) or ""
end

-- { ok, why, take = { { id, title, level, giver = { name, map, x, y, f }, pre } }, later, waiting = { { title, level } },
--   carried, hand = { { id, title, ender } }, unfinished, inside, unplaced, att = { { id, name, done, left, steps } } }
function U.dungeonPlans(key)
  if not key or key:sub(1, 1) == "_" then return nil end
  local c = K.plan[key]
  if c and GetTime() - c.at < PLAN_TTL then return c.d end
  local D = PS() and PS().Dungeons
  if not (D and type(D.PickupPlan) == "function" and type(D.HandinPlan) == "function") then return nil end
  if InCombatLockdown() then return { ok = false, why = "combat" } end
  local d = { ok = true, take = {}, waiting = {}, hand = {}, att = {}, later = 0, carried = 0, unfinished = 0, inside = 0, unplaced = 0 }
  local okP, plan, why = pcall(D.PickupPlan, key)
  if okP and type(plan) == "table" then
    for _, t in ipairs(type(plan.take) == "table" and plan.take or {}) do
      local q = type(t.quest) == "table" and t.quest or {}
      local g = type(t.giver) == "table" and t.giver or nil
      d.take[#d.take + 1] = { id = q.id, title = q.title or ("quest " .. tostring(q.id)), level = q.level or q.minLevel,
        giver = g and { name = g.name, map = g.map, x = g.x, y = g.y, f = g.f } or nil, pre = type(t.pre) == "table" and #t.pre or 0 }
    end
    for _, w in ipairs(type(plan.waiting) == "table" and plan.waiting or {}) do
      d.waiting[#d.waiting + 1] = { title = type(w.quest) == "table" and w.quest.title or "?", level = U.num(w.level) }
    end
    d.later = U.num(plan.later) or #d.waiting
    d.carried = type(plan.carried) == "table" and #plan.carried or 0
  else
    d.pickWhy = okP and why or "error"
  end
  local okH, hp = pcall(D.HandinPlan, key)
  if okH and type(hp) == "table" then
    for _, h in ipairs(type(hp.hand) == "table" and hp.hand or {}) do
      local q = type(h.quest) == "table" and h.quest or {}
      local e = type(h.ender) == "table" and h.ender or nil
      d.hand[#d.hand + 1] = { id = q.id, title = q.title or ("quest " .. tostring(q.id)),
        ender = e and { name = e.name, map = e.map, x = e.x, y = e.y, f = e.f } or nil }
    end
    for _, k in ipairs({ "unfinished", "inside", "unplaced" }) do d[k] = type(hp[k]) == "table" and #hp[k] or 0 end
  end
  if type(D.Attunements) == "function" and type(D.AttunementState) == "function" then
    local side = (UnitFactionGroup("player") == "Horde") and "H" or "A"
    local okA, list = pcall(D.Attunements, key, side)
    for _, a in ipairs(okA and type(list) == "table" and list or {}) do
      local okS, st = pcall(D.AttunementState, a)
      if okS and type(st) == "table" then
        local steps = {}
        for _, s in ipairs(type(st.steps) == "table" and st.steps or {}) do
          local x = type(s.step) == "table" and s.step or {}
          local item = type(x.item) == "table" and x.item or nil
          local title = x.title
          if x.kind == "drop" then title = tr("Łup:") .. " " .. tostring(item and item.name or "?") .. (type(x.npc) == "table" and x.npc.name and (" (" .. x.npc.name .. ")") or "")
          elseif x.kind == "object" then title = tr("Skrzynia:") .. " " .. tostring(item and item.name or "?")
          elseif x.kind == "gift" then title = tr("Od NPC:") .. " " .. tostring(item and item.name or "?")
          elseif x.kind == "rep" then title = tr("Reputacja:") .. " " .. tostring(x.name or "?") end
          steps[#steps + 1] = { title = title or "?", state = s.state, level = U.num(x.minLevel), kind = x.kind }
        end
        d.att[#d.att + 1] = { id = a.id, name = a.name or "?", kind = a.kind, done = st.done == true, left = U.num(st.left) or 0,
          next = U.num(st.next), steps = steps, item = type(a.item) == "table" and a.item.id or nil }
      end
    end
  end
  K.plan[key] = { at = GetTime(), d = d }
  return d
end

local STATE = { done = { "zrobione", C.ok }, ready = { "gotowe do oddania", C.gold }, log = { "w dzienniku", C.gold },
  open = { "do wzięcia", C.text }, locked = { "czeka na wcześniejszy", C.faint }, level = { "za niski poziom", C.danger },
  rep = { "za mała reputacja", C.danger }, na = { "nie dla Ciebie", C.faint }, skip = { "pominięte", C.faint } }

local function act(fn, label, ...)
  local D = PS() and PS().Dungeons
  if not (D and type(D[fn]) == "function") then U.say("ta akcja wymaga Polestara (moduł lochów).") return end
  if InCombatLockdown() then U.say("po walce: Polestar nie buduje przewodnika w walce.") return end
  local ok, gid, why = pcall(D[fn], ...)
  if not ok then U.say("Polestar: " .. tostring(gid)) return end
  if U.psTabsSay then U.psTabsSay(gid, why, label) end
  for k in pairs(K.plan) do K.plan[k] = nil end
  if gid and U.IsOpen and U.IsOpen() then U.Close() end
end

-- bloki P46 na stronie Questy karty lochu (TabWyprawy.lua): p = panel z blokami, d = loch z U.dungeonList
function U.dungeonPlanBlocks(p, dg)
  local key = dg and dg.key
  local d = U.dungeonPlans(key)
  if not d then return end
  if not d.ok then
    p:Head("Zbierz i oddaj", "Polestar")
    p:Para(d.why == "combat" and "Po walce: Polestar liczy trasę zbierania questów poza walką." or "Polestar nie policzył planu.", C.muted, 12)
    return
  end
  -- zbierz
  local zones, zorder = {}, {}
  for _, t in ipairs(d.take) do
    local z = t.giver and mapName(point(t.giver)) or "?"
    if not zones[z] then zones[z] = 0 zorder[#zorder + 1] = z end
    zones[z] = zones[z] + 1
  end
  local zl = {}
  for _, z in ipairs(zorder) do zl[#zl + 1] = z .. " " .. zones[z] end
  local right = #d.take .. " do wzięcia" .. (#zl > 0 and (" (" .. table.concat(zl, ", ") .. ")") or "")
  if #d.waiting > 0 then
    local lo
    for _, w in ipairs(d.waiting) do if w.level and (not lo or w.level < lo) then lo = w.level end end
    right = right .. " · " .. #d.waiting .. (lo and (" od poziomu " .. lo) or " później")
  end
  p:Head("Zbierz questy (" .. #d.take .. ")", right)
  if #d.take > 0 then
    local cards = {}
    for i, t in ipairs(d.take) do
      if i > 8 then break end
      local g = t.giver
      local where = g and (tostring(g.name or "?") .. (mapName(point(g)) and (", " .. mapName(point(g))) or "") .. eta(g)) or "start z przedmiotu"
      cards[#cards + 1] = {
        title = t.title, right = t.level and ("[" .. t.level .. "]") or nil, icon = QUEST_ICON, col = C.gold,
        sub = tr("od:") .. " " .. (g and where or tr(where)) .. (t.pre > 0 and (" · " .. tr("najpierw " .. t.pre .. " " .. plural(t.pre, "quest", "questy", "questów"))) or ""),
        tip = "Weź przed lochem: " .. t.title .. (g and ("\nDaje: " .. tostring(g.name)) or "") ..
          (t.pre > 0 and ("\nNajpierw " .. t.pre .. " " .. plural(t.pre, "quest wcześniej", "questy wcześniej", "questów wcześniej") .. " (trasa Polestara je uwzględnia).") or "") ..
          "\nKlik: Prowadź do pierwszego kroku (strzałka Polestar).",
        onClick = function()
          local D = PS() and PS().Dungeons
          local pt, label
          if D and type(D.GiverTarget) == "function" and t.id then
            local ok, a, b = pcall(D.GiverTarget, key, t.id)
            if ok and type(a) == "table" then pt, label = a, b end
          end
          guide(pt or g, "Weź: " .. t.title .. ((label or (g and g.name)) and (" (" .. tostring(label or g.name) .. ")") or ""))
        end,
      }
    end
    p:Cards(cards, { minW = 320 })
    if #d.take > 8 then p:Para("I jeszcze " .. (#d.take - 8) .. " (całą trasę pokaże Polestar).", C.faint, 11) end
    p:Button("Zbierz questy w Polestarze (nowa karta przewodnika)", function() act("PickUp", "Zbierz questy: " .. (dg.name or key), key) end, true)
  else
    p:Para((d.carried > 0 and ("Questy tego lochu masz w dzienniku (" .. d.carried .. ").") or "Nie ma tu nic do wzięcia przed lochem.") ..
      (#d.waiting > 0 and (" Później: " .. #d.waiting .. ".") or ""), C.muted, 12)
  end
  -- oddaj
  p:Head("Oddaj po lochu (" .. #d.hand .. ")", (d.unfinished > 0 and (d.unfinished .. " niedokończone") or "") ..
    (d.inside > 0 and ((d.unfinished > 0 and " · " or "") .. d.inside .. " oddajesz w lochu") or ""))
  if #d.hand > 0 then
    local cards = {}
    for i, h in ipairs(d.hand) do
      if i > 6 then break end
      local e = h.ender
      cards[#cards + 1] = {
        title = h.title, icon = TURNIN_ICON, col = C.ok,
        sub = e and (tr("oddaj:") .. " " .. tostring(e.name or "?") .. (mapName(point(e)) and (", " .. mapName(point(e))) or "") .. eta(e)) or "miejsce nieznane",
        tip = "Gotowe do oddania: " .. h.title .. "\nKlik: Prowadź do oddania (strzałka Polestar).",
        onClick = e and function() guide(e, "Oddaj: " .. h.title) end or nil,
      }
    end
    p:Cards(cards, { minW = 320 })
    p:Button("Oddaj po lochu w Polestarze (nowa karta przewodnika)", function() act("HandIn", "Oddaj po lochu: " .. (dg.name or key), key) end, true)
  else
    p:Para(d.unfinished > 0 and "Questy tego lochu w dzienniku nie są jeszcze skończone." or "Żaden skończony quest tego lochu nie czeka na oddanie.", C.muted, 12)
  end
  -- zestrojenia i klucze
  for _, a in ipairs(d.att) do
    local total = #a.steps
    local doneN = 0
    for _, s in ipairs(a.steps) do if s.state == "done" or s.state == "skip" then doneN = doneN + 1 end end
    p:Head(tr(a.kind == "key" and "Klucz:" or "Zestrojenie:") .. " " .. a.name, a.done and "gotowe" or (doneN .. " / " .. total))
    if not a.done then
      local cards, shown = {}, 0
      local from = math.max(1, (a.next or 1) - 1)
      for i = from, total do
        local s = a.steps[i]
        if shown >= 6 then break end
        shown = shown + 1
        local st = STATE[s.state or ""] or { tostring(s.state or "?"), C.muted }
        cards[#cards + 1] = { title = s.title, right = (s.state == "level" and s.level) and (tr("od") .. " " .. s.level) or st[1], rightCol = st[2],
          col = st[2], done = s.state == "done", icon = s.kind == "drop" and "Interface\\Icons\\INV_Misc_Bone_HumanSkull_01" or nil }
      end
      p:Cards(cards, { minW = 320 })
      if total - from + 1 > shown then p:Para("I jeszcze " .. (total - from + 1 - shown) .. " kroków dalej.", C.faint, 11) end
      p:Button("Prowadź przez zestrojenie (nowa karta w Polestarze)", function() act("Attune", a.name, key, a.id) end)
    else
      p:Cards({ { title = a.name, sub = "masz już dostęp", icon = ATT_ICON, done = true } }, { cols = 1 })
    end
  end
end

local ev = CreateFrame("Frame")
for _, e in ipairs({ "PLAYER_LEVEL_UP", "QUEST_TURNED_IN", "QUEST_ACCEPTED", "QUEST_REMOVED" }) do pcall(ev.RegisterEvent, ev, e) end
ev:SetScript("OnEvent", function(_, e)
  if e ~= "QUEST_ACCEPTED" and e ~= "QUEST_REMOVED" then K.xp = {} end
  K.plan = {}
end)

-- ---------- /gr test ----------
U.testChecksExtra = U.testChecksExtra or {}
table.insert(U.testChecksExtra, { "Polestar: XP z questów lochu (Dungeons.QuestXP)", function()
  local P = PS()
  if type(P) ~= "table" then return "brak Polestara (karta lochu bez XP z questów)" end
  local D = P.Dungeons
  if not (D and type(D.QuestXP) == "function") then error("brak Polestar.Dungeons.QuestXP (Dungeons\\XP.lua:20)") end
  -- loch na Twoj poziom z listy Polestara (albo pierwszy z listy)
  local key
  if type(D.List) == "function" then
    local okL, list = pcall(D.List)
    local l = UnitLevel("player") or 1
    if okL and type(list) == "table" then
      for _, d in ipairs(list) do
        if d.kind ~= "raid" and (d.minLevel or 99) <= l + 3 and (d.maxLevel or 0) >= l then key = d.key break end
      end
      key = key or (list[1] and list[1].key)
    end
  end
  if not key then return "QuestXP jest, ale lista lochów Polestara pusta (dane niewczytane)" end
  local ok, s = pcall(D.QuestXP, key)
  if not ok then error("QuestXP(" .. key .. "): " .. tostring(s)) end
  if type(s) ~= "table" then return "QuestXP(" .. key .. ") zwraca nil (Polestar nie zna lochu albo dane niewczytane)" end
  return "QuestXP(" .. key .. "): +" .. string.format("%.2f", U.num(s.levels) or 0) .. " poziomu, " .. tostring(s.quests) .. " questów, " ..
    tostring(s.xp) .. " XP" .. (s.below and (", od poziomu " .. tostring(s.below)) or "")
end })
table.insert(U.testChecksExtra, { "Polestar: limit wejść (Maps.GetInstanceStatus)", function()
  local P = PS()
  if type(P) ~= "table" then return "brak Polestara (Wyprawy liczą wejścia same)" end
  local M = P.Maps
  if not (M and type(M.GetInstanceStatus) == "function") then error("brak Polestar.Maps.GetInstanceStatus (Maps\\Instances.lua:252)") end
  local ok, st = pcall(M.GetInstanceStatus)
  if not ok then error("GetInstanceStatus: " .. tostring(st)) end
  if type(st) ~= "table" then error("GetInstanceStatus zwraca " .. type(st) .. " zamiast tabeli") end
  return "w godzinie " .. tostring(st.inHour) .. "/" .. tostring(st.perHour) .. ", doba " .. tostring(st.inDay) .. "/" .. tostring(st.perDay) ..
    ", czekaj " .. tostring(st.wait) .. " s, zwolni się za " .. tostring(st.clears) .. " s"
end })
-- 15.11 (R30 P46)
table.insert(U.testChecksExtra, { "Polestar: zbierz, oddaj, zestrojenia (Dungeons.PickupPlan, HandinPlan, AttunementState)", function()
  local P = PS()
  if type(P) ~= "table" then return "brak Polestara (Wyprawy bez planu questów lochu)" end
  local D = P.Dungeons
  local need = { { "PickupPlan", "Pickup.lua:627" }, { "PickUp", "Pickup.lua:1197" }, { "HandinPlan", "Handin.lua:102" },
    { "HandIn", "Handin.lua:323" }, { "Attunements", "Dungeons.lua:481" }, { "AttunementState", "Attune.lua:116" },
    { "Attune", "Attune.lua:380" }, { "GiverTarget", "Pickup.lua:1302" } }
  for _, n in ipairs(need) do
    if not (D and type(D[n[1]]) == "function") then error("brak Polestar.Dungeons." .. n[1] .. " (Dungeons\\" .. n[2] .. ")") end
  end
  if not (P.Codex and U.call(P.Codex.IsLoaded)) then return "funkcje są; dane lochów w Codexie Polestara jeszcze niewczytane (wczyta je zakładka Wyprawy)" end
  if InCombatLockdown() then return "funkcje są; plan liczy się poza walką" end
  local key
  local l = UnitLevel("player") or 1
  local okL, list = pcall(D.List)
  for _, d in ipairs(okL and type(list) == "table" and list or {}) do
    if d.kind ~= "raid" and (d.minLevel or 99) <= l + 3 and (d.maxLevel or 0) >= l then key = d.key break end
  end
  if not key then return "funkcje są; brak lochu na Twój poziom do próby" end
  K.plan[key] = nil
  local d = U.dungeonPlans(key)
  if not (d and d.ok) then error("plan " .. key .. ": " .. tostring(d and (d.why or d.pickWhy) or "nil")) end
  return key .. ": do wzięcia " .. #d.take .. ", później " .. #d.waiting .. ", do oddania " .. #d.hand .. ", zestrojeń " .. #d.att ..
    (d.pickWhy and (" (PickupPlan: " .. tostring(d.pickWhy) .. ")") or "")
end })
