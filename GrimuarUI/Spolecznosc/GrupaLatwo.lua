-- Grimuar UI: gra w grupie bez klikania po oknach (14.11, gracz: „share questow i inne tego typu rzeczy, zeby byly latwe”).
-- * Udostepnij wszystkie zadania grupie: jeden klik (Spolecznosc, okienko po dolaczeniu do grupy) albo klawisz
--   (Skroty > AddOny > „Udostepnij zadania grupie”), /hub dziel. Pomija zadania, ktore wedlug Questie maja juz wszyscy.
-- * Okienko po dolaczeniu nowej osoby (poza walka): ile zadan udostepnisz, co oni maja, a Ty nie.
-- * Zadanie udostepnione przez kogos z grupy przyjmuje sie samo, eskorte tez (/hub grupa auto wylacza).
-- * Kto ma ktore zadanie: Questie wymienia dzienniki w grupie (QuestieComms.remoteQuestLogs, tylko odczyt).
--   W Dzienniku przy zadaniu „W grupie: Ania 3/5 · Tomek nie ma”, w Spolecznosci w dymku osoby.
-- * Przyciski w Spolecznosci: Gotowosc, Ksiezyc na cel (owca), Daj wode (handel z celem i woda w okienku), Zapros cel,
--   Opusc grupe (drugie klikniecie potwierdza); PPM na osobie z grupy = Prowadz do niej (strzalka Polestara).
local ADDON, U = ...
local C = U.C
local G = U.G or {}

BINDING_NAME_GRIMUAR_SHARE = "Udostępnij zadania grupie"

local K = { seen = {} }
local WATER = (U.G and U.G.BD and U.G.BD.give) or {} -- co rozdajesz grupie (aktywny build) -- Crystal, Sparkling, Mineral, Spring, Purified, Fresh, Conjured Water

local function db() return U.db() end
local function short(name) return name and (tostring(name):match("^[^-]+")) or name end
local function inGroup() return U.call(IsInGroup) and true or false end

local function mod(name)
  local L = QuestieLoader
  if not (L and L.ImportModule) then return nil end
  local ok, m = pcall(L.ImportModule, L, name)
  return ok and type(m) == "table" and m or nil
end

-- ---------- dane ----------
local function members()
  local out = {}
  local n = U.num(U.call(GetNumGroupMembers)) or 0
  if n == 0 then return out end
  local raid = U.call(IsInRaid)
  for i = 1, raid and n or (n - 1) do
    local u = raid and ("raid" .. i) or ("party" .. i)
    pcall(function()
      if UnitIsUnit(u, "player") then return end
      local name = UnitName(u)
      if type(name) == "string" and name ~= "" then out[#out + 1] = { unit = u, name = name, short = short(name) } end
    end)
  end
  return out
end

-- skrocone imie -> { [questID] = cele } z Questie (dane osob, ktore tez maja Questie)
local function remoteByMember()
  local QC = mod("QuestieComms")
  local R = QC and QC.remoteQuestLogs
  local by = {}
  if type(R) ~= "table" then return by end
  for qid, players in pairs(R) do
    if type(players) == "table" then
      for pname, objs in pairs(players) do
        local s = short(pname)
        if s then
          by[s] = by[s] or {}
          by[s][qid] = objs
        end
      end
    end
  end
  return by
end

local function progressText(objs)
  if type(objs) ~= "table" then return "ma" end
  local n, done, first = 0, 0, nil
  for _, o in pairs(objs) do
    if type(o) == "table" then
      n = n + 1
      if o.finished then done = done + 1
      elseif not first and U.num(o.required) then first = (U.num(o.fulfilled) or 0) .. "/" .. o.required end
    end
  end
  if n == 0 then return "ma" end
  if done == n then return "gotowe" end
  if n == 1 and first then return first end
  return done .. "/" .. n .. " celów"
end

local function myQuests()
  local out = {}
  local n = U.num(U.call(C_QuestLog.GetNumQuestLogEntries)) or 0
  for i = 1, n do
    local info = U.call(C_QuestLog.GetInfo, i)
    if type(info) == "table" and not info.isHeader and not info.isHidden and info.questID then
      out[#out + 1] = { id = info.questID, title = info.title or ("#" .. info.questID),
        push = U.call(C_QuestLog.IsPushableQuest, info.questID) and true or false }
    end
  end
  return out
end

local function questTitle(qid)
  local DB = mod("QuestieDB")
  return (DB and U.call(DB.QueryQuestSingle, qid, "name")) or ("#" .. tostring(qid))
end

-- { members, known (ile osob ma Questie), share = { zadania do udostepnienia }, common, theirs = { {id, title, who} } }
function U.groupQuestSummary()
  local mem = members()
  if #mem == 0 then return nil end
  local by = remoteByMember()
  local known = 0
  for _, m in ipairs(mem) do
    m.quests = by[m.short]
    if m.quests then known = known + 1 end
  end
  local mine, mineSet, share, common = myQuests(), {}, {}, 0
  for _, q in ipairs(mine) do
    mineSet[q.id] = true
    local haveAll, someone = true, false
    for _, m in ipairs(mem) do
      if m.quests and m.quests[q.id] then someone = true else haveAll = false end
    end
    if someone then common = common + 1 end
    if q.push and not haveAll then share[#share + 1] = q end
  end
  local tmap, theirs = {}, {}
  for _, m in ipairs(mem) do
    for qid in pairs(m.quests or {}) do
      if not mineSet[qid] then
        if not tmap[qid] then
          tmap[qid] = { id = qid, title = questTitle(qid), who = {} }
          theirs[#theirs + 1] = tmap[qid]
        end
        table.insert(tmap[qid].who, m.short)
      end
    end
  end
  return { members = mem, known = known, share = share, common = common, theirs = theirs }
end

-- linia do Dziennika: „W grupie: Ania 3/5 · Tomek nie ma”
function U.groupQuestLine(qid)
  local mem = members()
  if #mem == 0 then return nil end
  local by = remoteByMember()
  local parts = {}
  for _, m in ipairs(mem) do
    local mq = by[m.short]
    if mq then parts[#parts + 1] = m.short .. " " .. (mq[qid] and progressText(mq[qid]) or "nie ma")
    else parts[#parts + 1] = m.short .. " ?" end
  end
  return "W grupie: " .. table.concat(parts, " · ")
end

-- dymek osoby z grupy w Spolecznosci
function U.groupMemberTip(tt, name)
  local by = remoteByMember()
  local mq = by[short(name)]
  if not mq then
    tt:AddLine("Zadań tej osoby nie znam (bez Questie albo jeszcze nie przysłał).", C.faint[1], C.faint[2], C.faint[3], true)
    return
  end
  local mine = {}
  for _, q in ipairs(myQuests()) do mine[q.id] = true end
  local n = 0
  for qid, objs in pairs(mq) do
    n = n + 1
    if n > 12 then tt:AddLine("…", 0.7, 0.7, 0.7) break end
    local c = mine[qid] and C.text or C.gold
    tt:AddDoubleLine(questTitle(qid) .. (mine[qid] and "" or "  (Ty nie masz)"), progressText(objs), c[1], c[2], c[3], 0.8, 0.8, 0.8)
  end
end

-- ---------- udostepnianie ----------
function U.shareAllQuests()
  if not inGroup() then U.say("nie jesteś w grupie.") return end
  if K.pushing then return end
  if InCombatLockdown() then U.say("udostępnię po walce.") return end
  local s = U.groupQuestSummary()
  local list = s and s.share or {}
  if #list == 0 then U.say("nie masz zadań do udostępnienia (albo grupa ma je wszystkie).") return end
  K.pushing = true
  local prev = U.call(C_QuestLog.GetSelectedQuest)
  U.say("udostępniam grupie " .. #list .. " " .. (#list == 1 and "zadanie" or (#list < 5 and "zadania" or "zadań")) .. "…")
  local i = 0
  local function step()
    i = i + 1
    local q = list[i]
    if not q or InCombatLockdown() or not inGroup() then
      K.pushing = false
      if prev then pcall(C_QuestLog.SetSelectedQuest, prev) end
      if U.groupPopupRefresh then pcall(U.groupPopupRefresh) end
      return
    end
    pcall(C_QuestLog.SetSelectedQuest, q.id)
    pcall(QuestLogPushQuest)
    C_Timer.After(1.2, step)
  end
  step()
end
function GrimuarShareQuests() U.shareAllQuests() end

-- ---------- akcje w grupie ----------
local function targetPlayer()
  local ok, yes = pcall(function()
    return UnitExists("target") and UnitIsPlayer("target") and UnitIsFriend("player", "target") and not UnitIsUnit("target", "player")
  end)
  return ok and yes
end

function U.groupReady()
  if not inGroup() then U.say("nie jesteś w grupie.") return end
  if not U.call(UnitIsGroupLeader, "player") then U.say("gotowość sprawdza lider grupy.") return end
  if not pcall(DoReadyCheck) then U.say("gra nie pozwoliła sprawdzić gotowości.") end
end

function U.groupMoon()
  if not U.call(UnitExists, "target") then U.say("zaznacz potwora, którego zamienisz w owcę.") return end
  local cur = U.num(U.call(GetRaidTargetIndex, "target"))
  if pcall(SetRaidTarget, "target", cur == 5 and 0 or 5) then
    U.say(cur == 5 and "zdjąłem księżyc z celu." or "księżyc na celu: grupa wie, że to Twoja owca (Polymorph).")
  else U.say("gra nie pozwoliła oznaczyć celu.") end
end

function U.groupInviteTarget()
  if not targetPlayer() then U.say("zaznacz gracza, którego chcesz zaprosić.") return end
  if U.call(UnitInParty, "target") or U.call(UnitInRaid, "target") then U.say("ta osoba już jest w grupie.") return end
  local name = U.call(GetUnitName, "target", true) or U.call(UnitName, "target")
  local ok = false
  if C_PartyInfo and C_PartyInfo.InviteUnit then ok = pcall(C_PartyInfo.InviteUnit, name) end
  if not ok and InviteUnit then ok = pcall(InviteUnit, name) end
  U.say(ok and ("zaproszenie do grupy: " .. short(name) .. ".") or "gra nie pozwoliła zaprosić.")
end

function U.groupLeave(btn)
  if not inGroup() then U.say("nie jesteś w grupie.") return end
  if not K.leaveAt or GetTime() - K.leaveAt > 3 then
    K.leaveAt = GetTime()
    if btn and btn.SetLabel then btn:SetLabel("Na pewno? Kliknij") C_Timer.After(3, function() btn:SetLabel("Opuść grupę") end) end
    U.say("kliknij jeszcze raz w ciągu 3 s, żeby opuścić grupę.")
    return
  end
  K.leaveAt = nil
  local ok = false
  if C_PartyInfo and C_PartyInfo.LeaveParty then ok = pcall(C_PartyInfo.LeaveParty) end
  if not ok and LeaveParty then ok = pcall(LeaveParty) end
  if not ok then U.say("gra nie pozwoliła opuścić grupy.") end
end

local function findWater()
  for _, id in ipairs(WATER) do
    for bag = 0, 4 do
      local n = U.num(U.call(C_Container.GetContainerNumSlots, bag)) or 0
      for slot = 1, n do
        if U.call(C_Container.GetContainerItemID, bag, slot) == id then return bag, slot end
      end
    end
  end
end
function U.groupGiveWater()
  if InCombatLockdown() then U.say("w walce nie da się handlować.") return end
  if not targetPlayer() then U.say("zaznacz gracza, któremu chcesz dać wodę.") return end
  if not findWater() then U.say("nie masz przywołanej wody: najpierw Conjure Water.") return end
  K.water = GetTime()
  if U.IsOpen and U.IsOpen() then U.Close() end
  if not pcall(InitiateTrade, "target") then K.water = nil U.say("gra nie pozwoliła otworzyć handlu (podejdź bliżej).") end
end

-- PPM na osobie z grupy: strzalka Polestara do niej
function U.groupGuide(name)
  for _, m in ipairs(members()) do
    if m.short == short(name) then
      local map = U.call(C_Map.GetBestMapForUnit, m.unit)
      local p = map and U.call(C_Map.GetPlayerMapPosition, map, m.unit)
      local x, y
      if p and p.GetXY then x, y = p:GetXY() x, y = U.num(x), U.num(y) end
      if x and y and (x > 0 or y > 0) and G.wayTo then
        pcall(G.wayTo, map, tonumber(string.format("%.2f", x * 100)), tonumber(string.format("%.2f", y * 100)), m.short)
        U.say("prowadzę do: " .. m.short .. ".")
        if U.IsOpen and U.IsOpen() then U.Close() end
      else
        U.say("gra nie podaje, gdzie jest " .. m.short .. " (inna strefa albo loch).")
      end
      return
    end
  end
end

-- rzad przyciskow do zakladki Spolecznosc
function U.groupActionsBuild(parent)
  local row = CreateFrame("Frame", nil, parent)
  row:SetHeight(28)
  local defs = {
    { "Udostępnij zadania", U.shareAllQuests, "Wszystkie zadania, które da się udostępnić, po kolei (co 1,2 s). Pomija te, które według Questie ma już cała grupa. Klawisz: Skróty > AddOny.", true },
    { "Gotowość", U.groupReady, "Sprawdzenie gotowości (tylko lider)." },
    { "Księżyc na cel", U.groupMoon, "Znak księżyca na celu: grupa wie, że to Twoja owca (Polymorph). Drugie kliknięcie zdejmuje." },
    { "Daj wodę", U.groupGiveWater, "Zaznacz gracza: otworzę handel i włożę Twoją najlepszą przywołaną wodę. Ty klikasz Trade." },
    { "Zaproś cel", U.groupInviteTarget, "Zaproszenie do grupy gracza, którego masz w celu." },
    { "Opuść grupę", U.groupLeave, "Drugie kliknięcie w ciągu 3 s potwierdza." },
  }
  local prev
  row.buttons = {}
  for _, d in ipairs(defs) do
    local b = U.Button(row, d[1], nil, 28, d[4])
    if prev then b:SetPoint("LEFT", prev, "RIGHT", 8, 0) else b:SetPoint("LEFT", row, "LEFT", 0, 0) end
    b:SetScript("OnClick", function(self) local ok, e = pcall(d[2], self) if not ok and U.logError then U.logError("grupa/" .. d[1], e) end end)
    b:HookScript("OnEnter", function(self)
      GameTooltip:SetOwner(self, "ANCHOR_BOTTOM")
      GameTooltip:SetText(d[1], C.gold[1], C.gold[2], C.gold[3])
      GameTooltip:AddLine(d[3], 1, 1, 1, true)
      GameTooltip:Show()
    end)
    b:HookScript("OnLeave", function() GameTooltip:Hide() end)
    row.buttons[#row.buttons + 1] = b
    prev = b
  end
  row:SetWidth(600)
  -- licznik na pierwszym przycisku
  function row:Refresh()
    local s = U.groupQuestSummary()
    local n = s and #s.share or 0
    self.buttons[1]:SetLabel(n > 0 and ("Udostępnij zadania (" .. n .. ")") or "Udostępnij zadania")
  end
  return row
end

-- ---------- okienko po dolaczeniu do grupy ----------
local P
local function popupBuild()
  if P then return P end
  P = U.Panel(UIParent, 0.94, true, C.edge)
  P:SetFrameStrata("MEDIUM")
  P:SetSize(400, 150)
  P:SetPoint("TOP", UIParent, "TOP", 0, -230)
  P:EnableMouse(true)
  P:Hide()
  P.h = U.H2(P, "Grupa")
  P.h:SetPoint("TOPLEFT", 16, -14)
  P.text = U.Para(P, 13, 368, C.text)
  P.text:SetPoint("TOPLEFT", P.h, "BOTTOMLEFT", 0, -8)
  P.share = U.Button(P, "Udostępnij", nil, 28, true)
  P.share:SetPoint("BOTTOMLEFT", 16, 14)
  P.share:SetScript("OnClick", function() U.shareAllQuests() end)
  P.close = U.Button(P, "Zamknij", nil, 28)
  P.close:SetPoint("LEFT", P.share, "RIGHT", 8, 0)
  P.close:SetScript("OnClick", function() P:Hide() end)
  return P
end

function U.groupPopupRefresh()
  if not (P and P:IsShown()) then return end
  local s = U.groupQuestSummary()
  if not s then P:Hide() return end
  local names = {}
  for _, m in ipairs(s.members) do names[#names + 1] = m.short end
  local lines = { "Grasz z: " .. table.concat(names, ", ") .. "." }
  if #s.share > 0 then
    lines[#lines + 1] = "Do udostępnienia: " .. #s.share .. (s.known < #s.members and " (nie wiem, co mają osoby bez Questie)." or ".")
  else
    lines[#lines + 1] = "Nie masz nic do udostępnienia."
  end
  if #s.theirs > 0 then
    local t = {}
    for i = 1, math.min(3, #s.theirs) do t[#t + 1] = s.theirs[i].title .. " (" .. table.concat(s.theirs[i].who, ", ") .. ")" end
    lines[#lines + 1] = "Oni mają, Ty nie: " .. table.concat(t, "; ") .. (#s.theirs > 3 and "…" or "") .. ". Poproś o udostępnienie."
  end
  P.text:SetText(table.concat(lines, "\n"))
  P.share:SetLabel(#s.share > 0 and ("Udostępnij (" .. #s.share .. ")") or "Udostępnij")
  P.share:SetShown(#s.share > 0)
  if not P.share:IsShown() then P.close:ClearAllPoints() P.close:SetPoint("BOTTOMLEFT", 16, 14)
  else P.close:ClearAllPoints() P.close:SetPoint("LEFT", P.share, "RIGHT", 8, 0) end
  P:SetHeight(math.max(130, 76 + P.text:GetStringHeight()))
end

local function popupShow()
  if db().noGroupPopup or InCombatLockdown() or not inGroup() then return end
  local s = U.groupQuestSummary()
  if not s or (#s.share == 0 and #s.theirs == 0) then return end
  popupBuild():Show()
  U.groupPopupRefresh()
  K.popupAt = GetTime()
  local at = K.popupAt
  C_Timer.After(45, function() if P and K.popupAt == at then P:Hide() end end)
end

-- ---------- zdarzenia ----------
local ev = CreateFrame("Frame")
for _, e in ipairs({ "GROUP_ROSTER_UPDATE", "QUEST_DETAIL", "QUEST_ACCEPT_CONFIRM", "TRADE_SHOW", "TRADE_CLOSED",
  "PLAYER_REGEN_DISABLED", "QUEST_LOG_UPDATE" }) do
  pcall(ev.RegisterEvent, ev, e)
end
ev:SetScript("OnEvent", function(_, event, a1, a2)
  if event == "GROUP_ROSTER_UPDATE" then
    local now, fresh = {}, false
    for _, m in ipairs(members()) do
      now[m.short] = true
      if not K.seen[m.short] then fresh = true end
    end
    K.seen = now
    if not inGroup() then if P then P:Hide() end return end
    -- Questie wymienia dzienniki po dolaczeniu: chwila na dane
    if fresh then C_Timer.After(5, function() pcall(popupShow) end) end
  elseif event == "QUEST_DETAIL" then
    if db().noAutoShared then return end
    local ok, shared = pcall(function()
      return UnitExists("questnpc") and UnitIsPlayer("questnpc") and (UnitInParty("questnpc") or UnitInRaid("questnpc"))
    end)
    if ok and shared then
      local who = U.call(UnitName, "questnpc") or "grupa"
      local title = U.call(GetTitleText) or "zadanie"
      C_Timer.After(0.2, function()
        if pcall(AcceptQuest) then U.say("przyjąłem zadanie od " .. tostring(who) .. ": " .. tostring(title) .. ". (/hub grupa auto wyłącza)") end
      end)
    end
  elseif event == "QUEST_ACCEPT_CONFIRM" then
    -- eskorta albo zadanie zaczete przez kogos z grupy
    if db().noAutoShared then return end
    if pcall(ConfirmAcceptQuest) then
      pcall(StaticPopup_Hide, "QUEST_ACCEPT")
      U.say("dołączyłem do zadania " .. tostring(a2 or "") .. " (" .. tostring(a1 or "grupa") .. ").")
    end
  elseif event == "TRADE_SHOW" then
    if K.water and GetTime() - K.water < 10 then
      K.water = nil
      C_Timer.After(0.3, function()
        local bag, slot = findWater()
        if not bag then return end
        pcall(ClearCursor)
        local ok = pcall(C_Container.PickupContainerItem, bag, slot) and pcall(ClickTradeButton, 1)
        if not ok then pcall(ClearCursor) U.say("przeciągnij wodę do okna handlu.")
        else U.say("woda jest w oknie handlu: kliknij Trade.") end
      end)
    end
  elseif event == "TRADE_CLOSED" then
    K.water = nil
  elseif event == "PLAYER_REGEN_DISABLED" then
    if P then P:Hide() end
  elseif event == "QUEST_LOG_UPDATE" then
    if P and P:IsShown() and not K.pending then
      K.pending = true
      C_Timer.After(1, function() K.pending = false pcall(U.groupPopupRefresh) end)
    end
  end
end)

function U.groupCmd(arg)
  local d = db()
  if arg == "auto" then
    d.noAutoShared = not d.noAutoShared
    U.say("zadania od grupy: " .. (d.noAutoShared and "pytam jak gra" or "przyjmuję same") .. ".")
  elseif arg == "okno" then
    d.noGroupPopup = not d.noGroupPopup
    U.say("okienko po dołączeniu do grupy: " .. (d.noGroupPopup and "wyłączone" or "włączone") .. ".")
  else
    U.say("/hub dziel: udostępnij zadania · /hub grupa auto: zadania od grupy same · /hub grupa okno: okienko po dołączeniu")
  end
end
