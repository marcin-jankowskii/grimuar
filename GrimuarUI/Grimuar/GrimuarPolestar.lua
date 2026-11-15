-- Grimuar UI: zakladka Grimuar z Polestarem, etap 3 (15.11, R30 P03 i P11; gracz zaakceptowal pomysly).
-- * P03 karta „Teraz wg Polestara”: biezacy krok z Polestar.Engine.GetStepView(GetStepIndex()) (Core\Engine.lua:9074 ->
--   { index, title, note, goals = { { index, t, status, verb, subject, text, progress = { cur, max }, item, npcName,
--   party, escort, limit, useItem } }, current, live, why }). Kazdy cel to karta (Hub\Bloki.lua U.Card) z ikona czasownika
--   (miecz: zabij, worek: zbierz, „!”: wez, „?”: oddaj), paskiem postepu i znaczkami (elita: wez grupe, eskorta, na czas).
--   Klik: Engine.AimGoal(krok, cel) (Engine.lua:11982, strzalka na ten cel; tylko biezacy krok). Odswiezanie na
--   komunikaty Polestara (U.onPolestar: STEP_CHANGED, STEP_UPDATED, WAYPOINT_CHANGED...), nie co 3 s.
-- * P11 questy klasowe maga: Polestar.Guides.List() (Core\Guides.lua:1392) z category == "Class" i GuideMatches (klasa,
--   rasa, frakcja), lancuch questow z Guides.Get(id).steps, dlugosc i elity z QoL.ClassQuests.Heads (QoL\ClassQuests.lua:96),
--   „gotowy teraz” z ClassQuests.Ready() (175), nagroda z Polestar.ClassRewards (UI\ClassRewards.lua:6, tylko odczyt).
--   Liczone przy rysowaniu zakladki, w pamieci do CLASS_QUEST_READY, GUIDE_COMPLETED, GUIDES_REGISTERED, awansu albo
--   zmiany w dzienniku. Klik: przewodnik w Polestarze (U.psOpenGuide, nowa karta; juz otwarty: Engine.SelectTab).
local ADDON, U = ...
local G, C = U.G or {}, U.C

local K = { cq = nil, cqDirty = true }

local function PS() return _G.Polestar end
local function text(s) return (U.polestarText and U.polestarText(s)) or s end
local function tr(s) return (G.tr and type(s) == "string") and G.tr(s) or s end -- tlumaczenie kawalkow (jezyk huba)
local function plural(n, one, few, many)
  if n == 1 then return one end
  local d, h = n % 10, n % 100
  if d >= 2 and d <= 4 and (h < 12 or h > 14) then return few end
  return many
end

-- ---------- P03: krok teraz ----------
local VERB = { accept = "Weź", turnin = "Oddaj", complete = "Wykonaj", kill = "Zabij", collect = "Zbierz", ["goto"] = "Idź do",
  fly = "Leć do", talk = "Porozmawiaj:", train = "Trenuj u", vendor = "Kupiec:", buy = "Kup", sethome = "Ustaw dom:",
  getfp = "Odkryj lot:", hearth = "Kamień powrotu:", use = "Użyj", interact = "Użyj", learn = "Naucz się", destroy = "Zniszcz",
  abandon = "Porzuć", wait = "Czekaj:" }
local ICON = { accept = "Interface\\GossipFrame\\AvailableQuestIcon", turnin = "Interface\\GossipFrame\\ActiveQuestIcon",
  complete = "Interface\\Icons\\INV_Scroll_03", kill = "Interface\\Icons\\INV_Sword_04", collect = "Interface\\Icons\\INV_Misc_Bag_08",
  ["goto"] = "Interface\\Icons\\INV_Misc_Map_01", fly = "Interface\\Minimap\\tracking\\flightmaster",
  getfp = "Interface\\Minimap\\tracking\\flightmaster", talk = "Interface\\Icons\\INV_Misc_Note_01",
  train = "Interface\\Icons\\INV_Misc_Book_11", learn = "Interface\\Icons\\INV_Misc_Book_09", vendor = "Interface\\Icons\\INV_Misc_Coin_01",
  buy = "Interface\\Icons\\INV_Misc_Coin_01", sethome = "Interface\\Minimap\\tracking\\innkeeper", hearth = "Interface\\Icons\\INV_Misc_Rune_01",
  use = "Interface\\Icons\\INV_Misc_Key_03", interact = "Interface\\Icons\\INV_Misc_Key_03", level = "Interface\\Icons\\Spell_ChargePositive",
  wait = "Interface\\Icons\\INV_Misc_PocketWatch_01", destroy = "Interface\\Icons\\INV_Misc_Bone_HumanSkull_01" }
local PARTY = { elite = "elita: weź grupę", dungeon = "loch: z grupą", raid = "rajd", group = "dla grupy" }
local ORDER = { active = 1, pending = 2, skipped = 3, done = 4 }

-- { index, no, total, guide, title, note, why, live, goals = { ... } } albo nil (bez Polestara) / { none = true }
function U.psNowStep()
  local P = PS()
  local E = type(P) == "table" and P.Engine
  if not (E and type(E.GetStepView) == "function" and type(E.GetStepIndex) == "function") then return nil end
  local i = U.num(U.call(E.GetStepIndex))
  if not i then return { none = true } end
  local ok, v = pcall(E.GetStepView, i)
  if not ok or type(v) ~= "table" then return { none = true } end
  local g = U.call(E.GetGuide)
  local d = { index = i, no = U.num(U.call(E.StepNumber, i)) or i, total = U.num(U.call(E.StepTotal)),
    guide = type(g) == "table" and text(g.title) or nil, title = text(v.title), note = text(v.note), why = v.why,
    live = U.num(v.live), goals = {}, notes = {} }
  for _, gv in ipairs(type(v.goals) == "table" and v.goals or {}) do
    if type(gv) == "table" and gv.status ~= "na" and not gv.folded and not gv.header then
      if gv.t == "note" then
        if gv.text then d.notes[#d.notes + 1] = text(gv.text) end
      else
        local pr = type(gv.progress) == "table" and gv.progress or nil
        d.goals[#d.goals + 1] = { index = gv.index, t = gv.t, status = gv.status, subject = text(gv.subject), text = text(gv.text),
          cur = pr and U.num(pr.cur), max = pr and U.num(pr.max), item = gv.item, npc = text(gv.npcName), note = text(gv.note),
          party = type(gv.party) == "table" and gv.party.kind or nil, escort = gv.escort, limit = U.num(gv.limit),
          useItem = text(gv.useItem), optional = gv.optional, current = gv.index == v.current, located = gv.map ~= nil }
      end
    end
  end
  table.sort(d.goals, function(a, b)
    if a.current ~= b.current then return a.current end
    local oa, ob = ORDER[a.status] or 2, ORDER[b.status] or 2
    if oa ~= ob then return oa < ob end
    return (a.index or 0) < (b.index or 0)
  end)
  return d
end

local function aim(stepIndex, goalIndex, label)
  local E = PS() and PS().Engine
  if not (E and type(E.AimGoal) == "function") then return end
  local ok, res, kind, title = pcall(E.AimGoal, stepIndex, goalIndex)
  if ok and res then
    U.say("strzałka Polestar: " .. tostring(label) .. ".")
  elseif ok and kind == "accept" then
    U.say("najpierw weź quest „" .. tostring(text(title)) .. "”: strzałka Polestar prowadzi do niego.")
  else
    U.say("Polestar nie ma miejsca dla tego celu albo to nie jest bieżący krok.")
    return
  end
  if U.IsOpen and U.IsOpen() then U.Close() end
end

-- karty celow (U.Card / p:Cards)
function U.psNowCards(d, limit)
  local out = {}
  if type(d) ~= "table" or d.none then return out end
  for n, x in ipairs(d.goals) do
    if limit and n > limit then break end
    local verb = VERB[x.t]
    local title = (verb and x.subject) and (tr(verb) .. " " .. x.subject) or x.text or x.subject or "?"
    local sub = {}
    if x.npc and (x.t == "accept" or x.t == "turnin" or x.t == "talk" or x.t == "train") then sub[#sub + 1] = tr("u:") .. " " .. x.npc end
    if x.party then sub[#sub + 1] = PARTY[x.party] and tr(PARTY[x.party]) or (tr("grupa:") .. " " .. x.party) end
    if x.escort then sub[#sub + 1] = tr("eskorta") end
    if x.limit then sub[#sub + 1] = tr("na czas " .. math.max(1, math.floor(x.limit / 60 + 0.5)) .. " min") end
    if x.useItem then sub[#sub + 1] = tr("użyj:") .. " " .. x.useItem end
    if x.optional then sub[#sub + 1] = tr("opcjonalne") end
    local right
    if x.status == "done" then right = "zrobione"
    elseif x.status == "skipped" then right = "pominięte"
    elseif x.max and x.max > 1 then right = (x.cur or 0) .. "/" .. x.max end
    local icon = ((x.t == "collect" or x.t == "use") and x.item and U.call(C_Item and C_Item.GetItemIconByID, x.item)) or ICON[x.t]
    local tip = { x.text or title }
    if x.note then tip[#tip + 1] = x.note end
    if d.note and n == 1 then tip[#tip + 1] = "\n" .. d.note end
    tip[#tip + 1] = (x.status == "done" or x.status == "skipped") and "" or "Klik: strzałka Polestar na ten cel."
    local idx, stepIdx = x.index, d.index
    out[#out + 1] = {
      title = title, right = right, rightCol = C.muted, sub = #sub > 0 and table.concat(sub, " · ") or nil, icon = icon,
      frac = (x.max and x.max > 1) and math.min(1, (x.cur or 0) / x.max) or nil, done = x.status == "done",
      col = x.current and C.gold or (x.status == "skipped" and C.faint or C.goldDim), tip = table.concat(tip, "\n"),
      onClick = (x.status ~= "done" and x.status ~= "skipped") and function() aim(stepIdx, idx, title) end or nil,
    }
  end
  return out
end

-- karta „Teraz wg Polestara” do kolumny zakladki Grimuar: f:Draw(limit) -> wysokosc (0: schowana)
function U.psNowWidget(parent, w)
  local f = CreateFrame("Frame", nil, parent)
  f:SetSize(w, 10)
  f.head = U.Label(f, "Polestar")
  f.head:SetPoint("TOPLEFT", 0, 0)
  f.head:SetWidth(w)
  f.title = U.Para(f, 15, w, C.text, "title")
  f.title:SetPoint("TOPLEFT", f.head, "BOTTOMLEFT", 0, -5)
  f.more = U.Text(f, 11, "body", C.faint)
  f.cards = {}
  function f:Draw(limit)
    local ok, d = pcall(U.psNowStep)
    if not ok or type(d) ~= "table" or d.none then
      if not ok and U.logError then U.logError("grimuar/teraz", d) end
      self:Hide()
      return 0
    end
    local look = d.live and d.index ~= d.live
    self.head:SetText(tr("Teraz wg Polestara") .. " · " .. tr("krok") .. " " .. d.no .. (d.total and (" / " .. d.total) or "") ..
      (look and (" · " .. tr("podgląd")) or "") .. (d.guide and (" · " .. d.guide) or ""))
    local why = (#d.goals == 0 and d.why) and ("\n" .. U.hex(C.muted) .. tostring(d.why) .. "|r") or ""
    self.title:SetText((d.title or "") .. why)
    local y = (self.head:GetStringHeight() or 12) + 5 + (self.title:GetStringHeight() or 16) + 8
    local list = U.psNowCards(d, limit or 3)
    for i = 1, math.max(#list, #self.cards) do
      local c = self.cards[i]
      if list[i] then
        if not c then c = U.Card(self) self.cards[i] = c end
        c:ClearAllPoints()
        c:SetPoint("TOPLEFT", self, "TOPLEFT", 0, -y)
        y = y + c:Fill(list[i], w) + 6
        c:Show()
      elseif c then c:Hide() end
    end
    local rest = #d.goals - #list
    self.more:ClearAllPoints()
    self.more:SetPoint("TOPLEFT", self, "TOPLEFT", 0, -y)
    self.more:SetText(rest > 0 and ("+ " .. rest .. " " .. plural(rest, "cel", "cele", "celów") .. " w oknie Polestara (Shift+J)") or "")
    if rest > 0 then y = y + 16 end
    self:SetHeight(y)
    self:Show()
    return y
  end
  return f
end

-- ---------- P11: questy klasowe ----------
-- { ok, done, list = { { id, title, state = "new"|"started"|"done", done, total, minLevel, ready, icon, reward, heads } } }
function U.psClassQuests()
  if K.cq and not K.cqDirty then return K.cq end
  local out = { ok = false, list = {}, done = 0 }
  local P = PS()
  local Gd, E, Cp = type(P) == "table" and P.Guides, type(P) == "table" and P.Engine, type(P) == "table" and P.Compat
  if not (Gd and type(Gd.List) == "function" and type(Gd.Get) == "function" and E and Cp and type(Cp.GetPlayerInfo) == "function") then
    K.cq, K.cqDirty = out, false
    return out
  end
  local okP, pl = pcall(Cp.GetPlayerInfo)
  if not (okP and type(pl) == "table") then return out end
  out.ok = true
  local CQ = P.QoL and P.QoL.ClassQuests
  local ready = {}
  if CQ and type(CQ.Ready) == "function" then
    local okR, list = pcall(CQ.Ready)
    for _, g in ipairs(okR and type(list) == "table" and list or {}) do if type(g) == "table" and g.id then ready[g.id] = true end end
  end
  local CR = P.ClassRewards
  local function applies(only)
    if type(only) ~= "table" or type(Gd.Matches) ~= "function" then return true end
    local ok, yes = pcall(Gd.Matches, only, pl)
    return not ok or yes
  end
  local okL, heads = pcall(Gd.List)
  for _, h in ipairs(okL and type(heads) == "table" and heads or {}) do
    local mine = h.category == "Class"
    if mine and type(Gd.GuideMatches) == "function" then
      local okM, yes = pcall(Gd.GuideMatches, h, pl)
      mine = okM and yes
    end
    if mine then
      local okG, g = pcall(Gd.Get, h.id)
      local steps = okG and type(g) == "table" and type(g.steps) == "table" and g.steps or {}
      local qids, seen = {}, {}
      for _, st in ipairs(steps) do
        if type(st) == "table" and applies(st.only) then
          for _, goal in ipairs(type(st.goals) == "table" and st.goals or {}) do
            local q = type(goal) == "table" and goal.t == "accept" and not goal.optional and tonumber(goal.quest)
            if q and not seen[q] and applies(goal.only) then seen[q] = true qids[#qids + 1] = q end
          end
        end
      end
      local done, inlog = 0, 0
      for _, q in ipairs(qids) do
        if U.call(C_QuestLog.IsQuestFlaggedCompleted, q) then done = done + 1
        else
          local li = U.call(C_QuestLog.GetLogIndexForQuestID, q)
          if li and li ~= 0 then inlog = inlog + 1 end
        end
      end
      local okS, gs = pcall(E.GetGuideState, h.id)
      local state = (#qids > 0 and done >= #qids) and "done" or (((done + inlog) > 0 or (okS and gs == "started")) and "started" or "new")
      local reward
      if type(CR) == "table" and type(CR.quests) == "table" and type(CR.rewards) == "table" then
        for _, q in ipairs(qids) do
          local e = CR.quests[q]
          if type(e) == "table" and (e[3] or 0) > 0 then reward = CR.rewards[e[3]] break end
        end
      end
      local hd
      if CQ and type(CQ.Heads) == "function" and okG and type(g) == "table" then
        local okH, r = pcall(CQ.Heads, g, pl)
        if okH and type(r) == "table" then hd = r end
      end
      if state == "done" then out.done = out.done + 1 end
      out.list[#out.list + 1] = { id = h.id, title = text(h.title) or h.id, state = state, done = done, total = #qids,
        minLevel = (hd and U.num(hd.firstLevel)) or U.num(h.minLevel), ready = ready[h.id] == true,
        icon = type(reward) == "table" and reward.icon or nil,
        reward = type(reward) == "table" and (reward.spellName or (type(reward.itemNames) == "table" and table.concat(reward.itemNames, " / "))) or nil,
        heads = hd }
    end
  end
  local RANK = { started = 1, new = 2, done = 3 }
  table.sort(out.list, function(a, b)
    if a.state ~= b.state then return RANK[a.state] < RANK[b.state] end
    if a.ready ~= b.ready then return a.ready end
    return (a.minLevel or 0) < (b.minLevel or 0)
  end)
  K.cq, K.cqDirty = out, false
  return out
end

local function openGuide(id, title)
  local E = PS() and PS().Engine
  if not E then return end
  local okT, tabs = pcall(E.GetTabs)
  for i, t in ipairs(okT and type(tabs) == "table" and tabs or {}) do
    if type(t) == "table" and t.guideId == id then
      pcall(E.SelectTab, i)
      U.say("Polestar: przewodnik „" .. tostring(title) .. "” był już otwarty, przełączyłem kartę.")
      if U.IsOpen and U.IsOpen() then U.Close() end
      return
    end
  end
  if okT and type(tabs) == "table" and #tabs >= (U.num(E.MAX_TABS) or 6) then
    if U.psTabsSay then U.psTabsSay(nil, "tabs", title) end
    return
  end
  if U.psOpenGuide and U.psOpenGuide(id) then
    U.say("Polestar otworzył przewodnik „" .. tostring(title) .. "” w nowej karcie.")
    if U.IsOpen and U.IsOpen() then U.Close() end
  end
end

-- karty questow klasowych (bez zrobionych); limit: najwyzej tyle
function U.psClassCards(limit)
  local ok, d = pcall(U.psClassQuests)
  if not ok or type(d) ~= "table" then return {}, 0 end
  local lvl = UnitLevel("player") or 1
  local out = {}
  for _, q in ipairs(d.list) do
    if q.state ~= "done" and (not limit or #out < limit) then
      local right, rc
      if q.state == "started" then right, rc = q.done .. "/" .. q.total, C.gold
      elseif q.ready or (q.minLevel and q.minLevel <= lvl) then right, rc = "gotowy", C.ok
      elseif q.minLevel then right, rc = tr("od") .. " " .. q.minLevel, C.muted end
      local sub = {}
      if q.reward then sub[#sub + 1] = q.reward end
      local h = q.heads
      if h then
        if (h.quests or 0) > 0 then sub[#sub + 1] = tr("łańcuch: " .. h.quests .. " " .. plural(h.quests, "quest", "questy", "questów")) end
        if (h.zones or 0) > 1 then sub[#sub + 1] = tr(h.zones .. " " .. plural(h.zones, "strefa", "strefy", "stref")) end
        if h.eliteMax then sub[#sub + 1] = tr("elity " .. ((h.eliteMin and h.eliteMin < h.eliteMax) and (h.eliteMin .. "–") or "") .. h.eliteMax .. ": weź grupę") end
        if h.escort then sub[#sub + 1] = tr("eskorta") end
      end
      local id, title = q.id, q.title
      out[#out + 1] = {
        title = title, right = right, rightCol = rc, sub = #sub > 0 and table.concat(sub, " · ") or nil,
        icon = q.icon or "Interface\\Icons\\INV_Misc_Book_11", col = q.state == "started" and C.gold or C.frost,
        frac = (q.state == "started" and q.total > 0) and (q.done / q.total) or nil,
        tip = "Quest klasowy maga: " .. title .. (q.reward and ("\nNagroda: " .. q.reward) or "") ..
          (q.minLevel and ("\nOd poziomu " .. q.minLevel) or "") .. "\nKlik: otwórz przewodnik w Polestarze (nowa karta, limit 6).",
        onClick = function() openGuide(id, title) end,
      }
    end
  end
  return out, d.done or 0
end

-- ---------- odswiezanie ----------
if U.onPolestar then
  U.onPolestar({ "CLASS_QUEST_READY", "GUIDE_COMPLETED", "GUIDES_REGISTERED" }, function() K.cqDirty = true end)
end
local ev = CreateFrame("Frame")
for _, e in ipairs({ "PLAYER_LEVEL_UP", "QUEST_TURNED_IN", "QUEST_ACCEPTED", "QUEST_REMOVED" }) do pcall(ev.RegisterEvent, ev, e) end
ev:SetScript("OnEvent", function() K.cqDirty = true end)

-- ---------- /gr test ----------
U.testChecksExtra = U.testChecksExtra or {}
table.insert(U.testChecksExtra, { "Polestar: krok teraz (Engine.GetStepView, AimGoal)", function()
  local P = PS()
  if type(P) ~= "table" then return "brak Polestara (zakładka Grimuar bez karty „Teraz wg Polestara”)" end
  local E = P.Engine
  for _, n in ipairs({ { "GetStepView", 9074 }, { "GetStepIndex", 8617 }, { "AimGoal", 11982 }, { "StepNumber", 9021 }, { "GetGuide", 8216 } }) do
    if not (E and type(E[n[1]]) == "function") then error("brak Polestar.Engine." .. n[1] .. " (Core\\Engine.lua:" .. n[2] .. ")") end
  end
  local ok, d = pcall(U.psNowStep)
  if not ok then error("krok: " .. tostring(d)) end
  if type(d) ~= "table" or d.none then return "działa, ale brak bieżącego kroku (bez przewodnika?)" end
  local c = U.psNowCards(d)
  return "krok " .. d.no .. (d.total and ("/" .. d.total) or "") .. ": " .. tostring(d.title) .. ", celów " .. #d.goals ..
    (c[1] and (", pierwszy: " .. tostring(c[1].title) .. (c[1].right and (" " .. c[1].right) or "")) or "")
end })
table.insert(U.testChecksExtra, { "Polestar: questy klasowe (Guides.List, ClassQuests.Ready, Heads)", function()
  local P = PS()
  if type(P) ~= "table" then return "brak Polestara (bez kart questów klasowych)" end
  local Gd, CQ = P.Guides, P.QoL and P.QoL.ClassQuests
  if not (Gd and type(Gd.List) == "function" and type(Gd.Get) == "function") then error("brak Polestar.Guides.List/Get (Core\\Guides.lua:1392)") end
  if not (CQ and type(CQ.Ready) == "function" and type(CQ.Heads) == "function") then error("brak Polestar.QoL.ClassQuests.Ready/Heads (QoL\\ClassQuests.lua:175/96)") end
  if type(P.ClassRewards) ~= "table" then return "działa bez ikon nagród (brak Polestar.ClassRewards)" end
  K.cqDirty = true
  local ok, d = pcall(U.psClassQuests)
  if not ok then error("questy klasowe: " .. tostring(d)) end
  local parts = {}
  for i, q in ipairs(d.list) do
    if i > 4 then break end
    parts[#parts + 1] = q.title .. " (" .. q.state .. (q.ready and ", gotowy" or "") .. ")"
  end
  return #d.list .. " przewodników klasowych, zrobione " .. d.done .. (#parts > 0 and (": " .. table.concat(parts, "; ")) or "")
end })
table.insert(U.testChecksExtra, { "Polestar: trener i NPC w locie (NearestClassTrainer, Codex.Npc; zapas Questie)", function()
  local P = PS()
  local parts = {}
  if type(P) == "table" then
    if not (P.Engine and type(P.Engine.NearestClassTrainer) == "function") then error("brak Polestar.Engine.NearestClassTrainer (Core\\Engine.lua:7288)") end
    if not (P.Codex and type(P.Codex.Npc) == "function") then error("brak Polestar.Codex.Npc (Lookup\\Codex.lua:564)") end
  else
    parts[#parts + 1] = "bez Polestara: Questie"
  end
  local t = G.classTrainerSpot and U.call(G.classTrainerSpot)
  parts[#parts + 1] = "trener maga: " .. (type(t) == "table" and (tostring(t[1]) .. ", " .. tostring(t[5]) .. " (" .. tostring(t.src) .. ")") or "brak (zostaje minimalna lista)")
  local b = G.resolveLoc and U.call(G.resolveLoc, { npc = 5144, label = "Bink" }, false)
  parts[#parts + 1] = "Bink: " .. (type(b) == "table" and ("mapa " .. tostring(b[1]) .. " " .. tostring(b[2]) .. ", " .. tostring(b[3])) or "nieznany bez Codexu i Questie")
  local ok, hs = pcall(function() return P and P.Get and P.Get("dungeons.headsUp") end)
  parts[#parts + 1] = "karta lochów Polestara (Q7): " .. ((ok and hs == false) and "wyłączona" or "włączona (Kontrola: Napraw)")
  return table.concat(parts, "; ")
end })
