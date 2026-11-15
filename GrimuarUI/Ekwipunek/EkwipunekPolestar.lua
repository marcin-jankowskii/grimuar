-- Grimuar UI: Ekwipunek z Polestarem, etap 3 (15.11, R30 P34 i P28; gracz zaakceptowal pomysly).
-- * P34 „Przed Tobą na trasie”: oddania questow (cele turnin) w krokach od zywego do konca aktywnego przewodnika
--   (Engine.GetGuide, GetLiveStep, StepNumber), dla kazdego Polestar.Gear.QuestPick(quest) (Gear\Picks.lua:25 ->
--   { quest, choices, pick, upgrade, entry = { id, link, pct, delta } }). Karta: „Thornroot Club +12% · za 6 kroków ·
--   quest X”, klik prowadzi do oddania. Liczone dopiero przy rysowaniu (Ekwipunek, zakladka Grimuar), w pamieci do
--   STEP_CHANGED, GEAR_UPDATED, GUIDE_CHANGED, TABS_CHANGED albo ITEMDB_LOADED. W walce bez wczytanego ItemDB nic nie
--   liczymy (ItemDB.Load w walce nie dziala, a pusta odpowiedz zostalaby w pamieci Polestara).
-- * P28 „Skąd zdobyć” i „Prowadź po to”: Polestar.Lookup.Sources("item", id) (Lookup\Sources.lua:772: wiersze { type,
--   label, detail, zone, map, x, y, f, travel, available, why, whyText, chance, price }), 3 najlepsze jako karty z ikona
--   rodzaju (kupiec, lup, quest, rzemioslo), klik prowadzi do miejsca; przycisk „Prowadź po to” = Lookup.Guide("item", id)
--   (Lookup\Guide.lua:923: nowa karta przewodnika w Polestarze, tylko na klik, limit 6 kart). Sources wczytuje Codex
--   i pyta planer o czas dla kazdego wiersza, wiec liczymy dopiero po wybraniu przedmiotu, w pamieci 60 s na przedmiot.
local ADDON, U = ...
local G, C = U.G or {}, U.C

local K = { up = nil, upDirty = true, src = {} }
local SCAN = 250       -- ile krokow trasy w przod przegladac
local SRC_TTL = 60     -- s: pamiec „Skąd zdobyć” na przedmiot

local function PS() return _G.Polestar end
local function plural(n, one, few, many)
  if n == 1 then return one end
  local d, h = n % 10, n % 100
  if d >= 2 and d <= 4 and (h < 12 or h > 14) then return few end
  return many
end
local function money(c) return U.money and U.money(c) or tostring(c) end
local function itemName(id)
  local n = U.call(C_Item and C_Item.GetItemNameByID, id)
  if not n then
    local D = PS() and PS().ItemDB
    if D and type(D.ItemName) == "function" then n = U.call(D.ItemName, id) end
  end
  return n or ("przedmiot " .. tostring(id))
end
local function itemIcon(id) return id and U.call(C_Item and C_Item.GetItemIconByID, id) or nil end
local function text(s) return (U.polestarText and U.polestarText(s)) or s end
local function tr(s) return (G.tr and type(s) == "string") and G.tr(s) or s end -- tlumaczenie kawalkow (jezyk huba)
local function stepsText(n)
  if type(n) ~= "number" or n <= 0 then return "w tym kroku" end
  return "za " .. n .. " " .. plural(n, "krok", "kroki", "kroków")
end
local function gainText(pct)
  pct = U.num(pct)
  if not pct then return "lepsze" end
  if pct >= 100 then return "duże ulepszenie" end
  local n = math.floor(pct + 0.5)
  return n < 1 and "+<1%" or ("+" .. n .. "%")
end
local function guide(m, x, y, label)
  if not (m and x and y and G.wayTo) then U.say("Polestar nie podał miejsca: " .. tostring(label) .. ".") return end
  pcall(G.wayTo, m, tonumber(string.format("%.2f", x)), tonumber(string.format("%.2f", y)), label)
  if U.IsOpen and U.IsOpen() then U.Close() end
end

-- ---------- P34: ulepszenia przed Toba ----------
-- { ok, list = { { item, pct, delta, quest, title, npc, steps, map, x, y, choices } } } od najblizszego
function U.psUpgradesAhead()
  if K.up and not K.upDirty then return K.up end
  local P = PS()
  local E, Gr, D = type(P) == "table" and P.Engine, type(P) == "table" and P.Gear, type(P) == "table" and P.ItemDB
  local out = { ok = false, list = {} }
  if not (E and Gr and type(Gr.QuestPick) == "function" and type(E.GetGuide) == "function") then
    K.up, K.upDirty = out, false
    return out
  end
  if InCombatLockdown() and not (D and type(D.IsLoaded) == "function" and U.call(D.IsLoaded)) then return K.up or out end
  local okG, g = pcall(E.GetGuide)
  local live = U.num(U.call(E.GetLiveStep)) or U.num(U.call(E.GetStepIndex))
  if not (okG and type(g) == "table" and type(g.steps) == "table" and live) then
    K.up, K.upDirty = out, false
    return out
  end
  out.ok = true
  local Gd, Cp = P.Guides, P.Compat
  local okP, pl = false, nil
  if Cp and type(Cp.GetPlayerInfo) == "function" then okP, pl = pcall(Cp.GetPlayerInfo) end
  local function applies(only)
    if type(only) ~= "table" or not (okP and type(pl) == "table" and Gd and type(Gd.Matches) == "function") then return true end
    local ok, yes = pcall(Gd.Matches, only, pl)
    return not ok or yes
  end
  local liveNo = U.num(U.call(E.StepNumber, live)) or live
  local seen = {}
  for i = live, math.min(#g.steps, live + SCAN) do
    local st = g.steps[i]
    if type(st) == "table" and type(st.goals) == "table" and applies(st.only) then
      for _, goal in ipairs(st.goals) do
        local q = type(goal) == "table" and goal.t == "turnin" and tonumber(goal.quest)
        if q and not seen[q] and applies(goal.only) and not U.call(C_QuestLog.IsQuestFlaggedCompleted, q) then
          seen[q] = true
          local ok, pick = pcall(Gr.QuestPick, q)
          local e = ok and type(pick) == "table" and pick.upgrade and type(pick.entry) == "table" and pick.entry or nil
          if e and e.id then
            local m, x, y = goal.map, goal.x, goal.y
            if U.psLive then m, x, y = U.psLive(goal) end
            out.list[#out.list + 1] = {
              item = e.id, pct = U.num(e.pct), delta = U.num(e.delta), quest = q, title = text(goal.title) or ("quest " .. q),
              npc = text(goal.npcName), steps = (U.num(U.call(E.StepNumber, i)) or i) - liveNo, map = m, x = U.num(x), y = U.num(y),
              choices = type(pick.choices) == "table" and #pick.choices or 1,
            }
          end
        end
      end
    end
  end
  table.sort(out.list, function(a, b)
    if a.steps ~= b.steps then return a.steps < b.steps end
    return (a.pct or 0) > (b.pct or 0)
  end)
  K.up, K.upDirty = out, false
  return out
end

-- karty p:Cards / U.Card: { title, right, sub, icon, tip, onClick }
function U.psUpgradeCards(limit)
  local ok, d = pcall(U.psUpgradesAhead)
  if not ok or type(d) ~= "table" then return {} end
  local cards = {}
  for i, u in ipairs(d.list) do
    if limit and i > limit then break end
    local name = itemName(u.item)
    local gain = gainText(u.pct)
    local tip = { name .. ": " .. gain .. " wg wag Polestara dla Twojego buildu." }
    tip[#tip + 1] = "Nagroda za quest „" .. u.title .. "”" .. (u.npc and (", oddajesz u " .. u.npc) or "") .. ", " .. stepsText(u.steps) .. " trasy."
    if u.choices > 1 then tip[#tip + 1] = "Polestar wybiera ją z " .. u.choices .. " nagród do wyboru." end
    tip[#tip + 1] = "Klik: Prowadź do oddania (strzałka Polestar)."
    cards[#cards + 1] = {
      title = name, right = gain, rightCol = C.ok, sub = tr(stepsText(u.steps)) .. " · " .. u.title,
      icon = itemIcon(u.item), col = C.ok, tip = table.concat(tip, "\n"),
      onClick = function() guide(u.map, u.x, u.y, "Oddaj: " .. u.title) end,
    }
  end
  return cards
end

-- ---------- P28: skad zdobyc ----------
local TYPE_PL = { vendor = "Kupiec", drop = "Łup", object = "Skrzynia", quest = "Quest", gift = "Od NPC", craft = "Rzemiosło",
  rep = "Reputacja", pvp = "PvP", container = "Pojemnik", world = "Łup ze świata", spawn = "Miejsce", entrance = "Wejście" }
local TYPE_ICON = { vendor = "Interface\\Icons\\INV_Misc_Coin_01", drop = "Interface\\Icons\\INV_Misc_Bone_HumanSkull_01",
  object = "Interface\\Icons\\INV_Misc_Key_03", quest = "Interface\\GossipFrame\\AvailableQuestIcon",
  gift = "Interface\\Icons\\INV_Misc_Note_01", craft = "Interface\\Icons\\Trade_BlackSmithing",
  rep = "Interface\\Icons\\INV_Shirt_GuildTabard_01", pvp = "Interface\\Icons\\INV_BannerPVP_02",
  container = "Interface\\Icons\\INV_Misc_Bag_08", world = "Interface\\Icons\\INV_Misc_Map_01" }
local WHY_PL = { level = "za niski poziom", profession = "wymaga profesji", reputation = "wymaga reputacji", class = "inna klasa",
  faction = "druga frakcja", race = "inna rasa", retired = "już niedostępne" }

-- -> wiersze (kopie, max 12) albo nil, powod ("nopolestar" | "combat" | "nocodex" | "error")
function U.psSources(id)
  id = tonumber(id)
  if not id then return nil, "error" end
  local c = K.src[id]
  if c and GetTime() - c.at < SRC_TTL then return c.rows, c.why end
  local P = PS()
  local Lk, X = type(P) == "table" and P.Lookup, type(P) == "table" and P.Codex
  if not (Lk and type(Lk.Sources) == "function") then return nil, "nopolestar" end
  local loaded = X and type(X.IsLoaded) == "function" and U.call(X.IsLoaded)
  if not loaded and InCombatLockdown() then return nil, "combat" end
  local ok, list = pcall(Lk.Sources, "item", id)
  if not ok or type(list) ~= "table" then return nil, "error" end
  if not (X and U.call(X.IsLoaded)) then
    -- Codex sie nie wczytal (brak addonu Polestar_Codex albo wylaczony): nie pytamy co odswiezenie
    K.src[id] = { at = GetTime(), rows = nil, why = "nocodex" }
    return nil, "nocodex"
  end
  local rows = {}
  for i, r in ipairs(list) do
    if i > 12 then break end
    if type(r) == "table" then
      rows[#rows + 1] = { type = r.type, label = r.label, detail = r.detail, zone = r.zone, map = r.map, x = r.x, y = r.y, f = r.f,
        travel = U.num(r.travel), available = r.available ~= false, why = r.why, whyText = r.whyText, chance = U.num(r.chance),
        price = U.num(r.price), guideable = r.guideable }
    end
  end
  K.src[id] = { at = GetTime(), rows = rows }
  return rows
end

local function sourceCard(r)
  local kind = TYPE_PL[r.type] or r.type or "?"
  local parts = {}
  local zone = r.zone
  if not zone and type(r.detail) == "string" then zone = r.detail:match(" · (.+)$") end
  if zone then parts[#parts + 1] = zone end
  if r.chance and r.chance > 0 then parts[#parts + 1] = tr((r.chance >= 10 and math.floor(r.chance + 0.5) or string.format("%.1f", r.chance):gsub("%.", ",")) .. "% szansy") end
  if r.price and r.price > 0 then parts[#parts + 1] = money(r.price) end
  local right = (r.travel and G.etaShort) and U.call(G.etaShort, r.travel) or nil
  if not r.available then
    local lv = r.why == "level" and type(r.whyText) == "string" and r.whyText:match("(%d+)")
    right = lv and ("od poziomu " .. lv) or (WHY_PL[r.why or ""] or "niedostępne")
  end
  local tip = { kind .. ": " .. tostring(r.label or "?") }
  if r.detail then tip[#tip + 1] = r.detail end
  if not r.available and r.whyText then tip[#tip + 1] = "Polestar: " .. r.whyText end
  local located = r.map and r.x and r.y
  tip[#tip + 1] = located and "Klik: Prowadź (strzałka Polestar)." or "Polestar nie zna miejsca."
  return {
    title = tr(kind) .. ": " .. tostring(r.label or "?"), right = right, rightCol = r.available and C.frost or C.danger,
    sub = #parts > 0 and table.concat(parts, " · ") or nil, icon = TYPE_ICON[r.type] or "Interface\\Icons\\INV_Misc_Map_01",
    col = r.available and C.gold or C.faint, tip = table.concat(tip, "\n"),
    onClick = located and function()
      local m, x, y = r.map, r.x, r.y
      if U.psLive then m, x, y = U.psLive(r) end
      guide(m, U.num(x), U.num(y), tostring(r.label or kind))
    end or nil,
  }
end
U.psSourceCard = sourceCard -- 15.11 (R30 P29): tez „Skad zdobyc” w wyszukiwarce Mapy (Mapa\MapaSzukajPolestar.lua)

-- „Prowadź po to”: przewodnik Polestara po przedmiot w nowej karcie (tylko na klik gracza)
function U.psItemGuide(id, name)
  local Lk = PS() and PS().Lookup
  if not (Lk and type(Lk.Guide) == "function") then U.say("„Prowadź po to” wymaga Polestara.") return false end
  if InCombatLockdown() then U.say("po walce: Polestar nie buduje przewodnika w walce.") return false end
  local ok, gid, why = pcall(Lk.Guide, "item", tonumber(id))
  if not ok then U.say("Polestar nie zbudował przewodnika: " .. tostring(gid)) return false end
  local res = U.psTabsSay and U.psTabsSay(gid, why, name or itemName(id))
  if gid and U.IsOpen and U.IsOpen() then U.Close() end
  return res
end

-- blok „Skąd zdobyć” do panelu z blokami (karta przedmiotu w Ekwipunku, lupy w Wyprawach)
function U.psSourceBlocks(p, id, name)
  if not (p and id) then return end
  local rows, why = U.psSources(id)
  name = name or itemName(id)
  if rows == nil then
    if why == "combat" then
      p:Head("Skąd zdobyć", "Polestar")
      p:Para("Po walce: Polestar nie wczytuje swojej bazy w walce.", C.muted, 12)
    elseif why == "nocodex" then
      p:Head("Skąd zdobyć", "Polestar")
      p:Para("Polestar nie wczytał swojej bazy przedmiotów (addon Polestar_Codex).", C.muted, 12)
    end
    return
  end
  p:Head("Skąd zdobyć", #rows > 0 and (#rows .. " " .. plural(#rows, "źródło", "źródła", "źródeł") .. " · Polestar") or "Polestar")
  if #rows == 0 then
    p:Para("Polestar nie zna źródła tego przedmiotu.", C.muted, 12)
    return
  end
  local cards = {}
  for i = 1, math.min(3, #rows) do cards[#cards + 1] = sourceCard(rows[i]) end
  p:Cards(cards, { cols = 1 })
  if #rows > 3 then p:Para("I jeszcze " .. (#rows - 3) .. " w Polestarze (Alt+klik na przedmiocie w torbie).", C.faint, 11) end
  p:Button("Prowadź po to (nowa karta w Polestarze)", function() U.psItemGuide(id, name) end)
end

-- ---------- odswiezanie ----------
if U.onPolestar then
  U.onPolestar({ "STEP_CHANGED", "GEAR_UPDATED", "GUIDE_CHANGED", "TABS_CHANGED", "ITEMDB_LOADED", "GUIDE_COMPLETED" }, function(msg, what)
    -- GEAR_UPDATED("bags") przychodzi przy kazdym lupie; ulepszenia z questow licza sie wzgledem zalozonego
    if msg == "GEAR_UPDATED" and what == "bags" then return end
    K.upDirty = true
  end)
  U.onPolestar({ "CODEX_LOADED" }, function() K.src = {} end)
end
local ev = CreateFrame("Frame")
for _, e in ipairs({ "QUEST_TURNED_IN", "ZONE_CHANGED_NEW_AREA", "PLAYER_LEVEL_UP", "SKILL_LINES_CHANGED" }) do pcall(ev.RegisterEvent, ev, e) end
ev:SetScript("OnEvent", function(_, e)
  K.src = {}
  if e ~= "ZONE_CHANGED_NEW_AREA" then K.upDirty = true end
end)

-- ---------- /gr test ----------
U.testChecksExtra = U.testChecksExtra or {}
table.insert(U.testChecksExtra, { "Polestar: ulepszenia na trasie (Gear.QuestPick)", function()
  local P = PS()
  if type(P) ~= "table" then return "brak Polestara (bez kart „Przed Tobą”)" end
  local Gr, E = P.Gear, P.Engine
  if not (Gr and type(Gr.QuestPick) == "function") then error("brak Polestar.Gear.QuestPick (Gear\\Picks.lua:25)") end
  for _, fn in ipairs({ "GetGuide", "GetLiveStep", "StepNumber" }) do
    if not (E and type(E[fn]) == "function") then error("brak Polestar.Engine." .. fn .. " (Core\\Engine.lua)") end
  end
  K.upDirty = true
  local ok, d = pcall(U.psUpgradesAhead)
  if not ok then error("ulepszenia: " .. tostring(d)) end
  if not d.ok then return "działa, ale brak aktywnego przewodnika (albo walka bez wczytanego ItemDB)" end
  local u = d.list[1]
  return #d.list .. " ulepszeń przed Tobą" .. (u and (", najbliższe: " .. itemName(u.item) .. " " .. gainText(u.pct) .. " " .. stepsText(u.steps)) or "")
end })
table.insert(U.testChecksExtra, { "Polestar: skąd zdobyć (Lookup.Sources, Lookup.Guide)", function()
  local P = PS()
  if type(P) ~= "table" then return "brak Polestara (karta przedmiotu bez „Skąd zdobyć”)" end
  local Lk, X = P.Lookup, P.Codex
  if not (Lk and type(Lk.Sources) == "function") then error("brak Polestar.Lookup.Sources (Lookup\\Sources.lua:772)") end
  if type(Lk.Guide) ~= "function" then error("brak Polestar.Lookup.Guide (Lookup\\Guide.lua:923)") end
  if not (X and U.call(X.IsLoaded)) then return "funkcje są; Codex Polestara jeszcze niewczytany (wczyta go pierwszy wybór przedmiotu)" end
  local id = 2589 -- Linen Cloth: zawsze ma zrodla
  local ok, list = pcall(Lk.Sources, "item", id)
  if not ok then error("Sources: " .. tostring(list)) end
  if type(list) ~= "table" then error("Sources zwraca " .. type(list)) end
  local r = list[1]
  return "Linen Cloth: " .. #list .. " źródeł" .. (type(r) == "table" and (", pierwsze: " .. tostring(r.type) .. " " .. tostring(r.label) ..
    (r.travel and (", " .. math.floor(r.travel) .. " s") or "")) or "")
end })
