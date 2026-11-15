-- Grimuar UI: Umiejetnosci, czesc talentow (podzial pliku ponad 1000 linii, 14.11): odczyt talentow, plan, wydawanie
-- punktu, drzewko i lista planu. Funkcje przeniesione 1:1 z TabUmiejetnosci.lua bez zmian. Wspolny stan i pomocnicze
-- przez wewnetrzna tabele modulu U.UM (S, TREE_EN, TREE_PL tutaj; plural, spellIcon, spellName, refresh z pliku glownego).
local ADDON, U = ...
local G, C = U.G, U.C
local say = U.say
U.UM = U.UM or {}
local M = U.UM
M.S = M.S or { filter = "all", cells = {}, heads = {}, nodes = {}, tiers = {}, treeBtns = {}, planRows = {}, next5 = {} }
local S = M.S
local TREE_EN = { Arcane = "Arkana", Fire = "Ogień", Frost = "Mróz" }
local TREE_PL = { "Arkana", "Ogień", "Mróz" } -- mag: kolejnosc drzewek w grze
M.TREE_EN, M.TREE_PL = TREE_EN, TREE_PL
-- pomocnicze z pliku glownego (wywolywane dopiero w trakcie gry, gdy oba pliki sa wczytane)
local function plural(...) return M.plural(...) end
local function refresh(...) return M.refresh(...) end
local function spellIcon(...) return M.spellIcon(...) end
local function spellName(...) return M.spellName(...) end

-- ---------- talenty ----------
local function talInfo(t, i)
  local CS = C_SpecializationInfo
  if CS and CS.GetTalentInfo then
    local ok, r = pcall(CS.GetTalentInfo, { specializationIndex = t, talentIndex = i })
    if ok and type(r) == "table" and type(r.name) == "string" then
      return { name = r.name, icon = r.icon, tier = U.num(r.tier) or 1, col = U.num(r.column) or 1, rank = U.num(r.rank) or 0,
        max = U.num(r.maxRank) or 1, meets = r.meetsPrereq ~= false }
    end
  end
  if GetTalentInfo then
    -- klasyczna kolejnosc: nazwa, ikona, rzad, kolumna, ranga, maks; inna sygnatura (liczba na poczatku) = pomijamy
    local ok, name, icon, tier, col, rank, max, _, meets = pcall(GetTalentInfo, t, i)
    if ok and type(name) == "string" and U.num(tier) and U.num(col) then
      return { name = name, icon = icon, tier = U.num(tier) or 1, col = U.num(col) or 1, rank = U.num(rank) or 0,
        max = U.num(max) or 1, meets = meets ~= false }
    end
  end
end
local function tabName(t)
  local a, b = U.call(GetTalentTabInfo, t)
  local nm = (type(a) == "string" and a) or (type(b) == "string" and b) or nil
  return (nm and (TREE_EN[nm] or nm)) or TREE_PL[t] or ("Drzewo " .. t)
end
-- 14.11 (zrzut: hub „Gra nie podala drzewek talentow”, okno gry je ma): Forever trzyma talenty w C_Traits
-- (konfiguracja, jedno drzewo klasy, grupy = Arkana/Ogien/Mroz, wezly z posX/posY). Odczyt jak ForeverSkin
-- (Windows/Talents.lua Data.Read): GetCombatConfigIDForSpecGroup, GetConfigInfo.treeIDs[1], GetGroupDisplayInfoByTreeID,
-- GetGroupCurrencyInfo (wydane), GetTreeCurrencyInfo (do wydania), GetTreeNodes / GetNodeInfo / GetEntryInfo / GetDefinitionInfo.
local function slots(values)
  local u, seen = {}, {}
  for _, v in ipairs(values) do if not seen[v] then seen[v] = true u[#u + 1] = v end end
  table.sort(u)
  local gaps, maxGap = {}, 0
  for k = 2, #u do
    local g = u[k] - u[k - 1]
    gaps[#gaps + 1] = g
    if g > maxGap then maxGap = g end
  end
  local step
  for _, g in ipairs(gaps) do if g >= maxGap * 0.25 and (not step or g < step) then step = g end end
  local out = {}
  for _, v in ipairs(u) do out[v] = step and math.floor((v - u[1]) / step + 0.5) or 0 end
  return out
end
local function readTraits()
  local T, CS, CT = C_Traits, C_SpecializationInfo, C_ClassTalents
  if not (T and T.GetConfigInfo and T.GetTreeNodes and T.GetNodeInfo and T.GetGroupDisplayInfoByTreeID) then return nil end
  local group = (CS and CS.GetActiveSpecGroup and U.num(U.call(CS.GetActiveSpecGroup))) or 1
  local configID = CS and CS.GetCombatConfigIDForSpecGroup and U.num(U.call(CS.GetCombatConfigIDForSpecGroup, group))
  if not configID and CT and CT.GetActiveConfigID then configID = U.num(U.call(CT.GetActiveConfigID)) end
  if not configID then return nil end
  local cfg = U.call(T.GetConfigInfo, configID)
  local treeID = type(cfg) == "table" and type(cfg.treeIDs) == "table" and U.num(cfg.treeIDs[1])
  if not treeID then return nil end
  local trees, byGroup = {}, {}
  for _, d in ipairs(U.call(T.GetGroupDisplayInfoByTreeID, treeID) or {}) do
    local gid = type(d) == "table" and U.num(d.groupID)
    if gid and not byGroup[gid] then
      local nm = type(d.displayName) == "string" and d.displayName or ""
      local tr = { groupID = gid, order = U.num(d.orderIndex) or 0, name = TREE_EN[nm] or nm, spent = 0, plan = 0, nodes = {} }
      byGroup[gid] = tr
      trees[#trees + 1] = tr
    end
  end
  if #trees == 0 then return nil end
  table.sort(trees, function(a, b) if a.order ~= b.order then return a.order < b.order end return a.groupID < b.groupID end)
  local gids = {}
  for i, tr in ipairs(trees) do tr.idx = i gids[i] = tr.groupID end
  for _, info in ipairs(U.call(T.GetGroupCurrencyInfo, configID, gids) or {}) do
    local tr = type(info) == "table" and byGroup[U.num(info.traitNodeGroupID) or -1]
    local ci = tr and type(info.currencyInfos) == "table" and info.currencyInfos[1]
    if tr and type(ci) == "table" then tr.spent = U.num(ci.spent) or 0 end
  end
  local cur = U.call(T.GetTreeCurrencyInfo, configID, treeID, false)
  local points = type(cur) == "table" and type(cur[1]) == "table" and U.num(cur[1].quantity) or 0
  local byName, ys = {}, {}
  for _, nodeID in ipairs(U.call(T.GetTreeNodes, treeID) or {}) do
    local info = U.call(T.GetNodeInfo, configID, nodeID)
    if type(info) == "table" and info.isVisible and U.num(info.ID) then
      local tr
      for _, g in ipairs(type(info.groupIDs) == "table" and info.groupIDs or {}) do tr = tr or byGroup[g] end
      if tr then
        local ae = type(info.activeEntry) == "table" and info.activeEntry.entryID
        local entryID = ae or (type(info.entryIDs) == "table" and info.entryIDs[1])
        local e = entryID and U.call(T.GetEntryInfo, configID, entryID)
        local def = type(e) == "table" and e.definitionID and U.call(T.GetDefinitionInfo, e.definitionID)
        local spellID = type(def) == "table" and U.num(def.spellID) or nil
        local nm = type(def) == "table" and type(def.overrideName) == "string" and def.overrideName ~= "" and def.overrideName
          or (spellID and spellName(spellID)) or "?"
        local icon = type(def) == "table" and def.overrideIcon or (spellID and spellIcon(spellID)) or nil
        local node = { nodeID = U.num(info.ID), tab = tr.idx, name = nm, icon = icon, spellID = spellID,
          rank = U.num(info.ranksPurchased) or 0, max = U.num(info.maxRanks) or 1,
          posX = U.num(info.posX) or 0, posY = U.num(info.posY) or 0, canBuy = info.canPurchaseRank == true,
          meets = info.meetsEdgeRequirements ~= false, traits = true }
        tr.nodes[#tr.nodes + 1] = node
        byName[nm] = node
        ys[#ys + 1] = node.posY
      end
    end
  end
  local rowOf = slots(ys)
  for _, tr in ipairs(trees) do
    local xs = {}
    for _, n in ipairs(tr.nodes) do xs[#xs + 1] = n.posX end
    local colOf = slots(xs)
    for _, n in ipairs(tr.nodes) do n.tier, n.col = (rowOf[n.posY] or 0) + 1, (colOf[n.posX] or 0) + 1 end
  end
  S.tal = { configID = configID, treeID = treeID, points = points }
  return trees, byName
end

local function readTalents()
  local tt, tb = readTraits()
  if tt then return tt, tb end
  S.tal = nil
  local trees, byName = {}, {}
  local nt = U.call(GetNumTalentTabs) or 3
  for t = 1, nt do
    local tree = { idx = t, name = tabName(t), spent = 0, plan = 0, nodes = {} }
    local n = U.call(GetNumTalents, t) or 40
    for i = 1, n do
      local info = talInfo(t, i)
      if not info then break end
      info.tab, info.i = t, i
      tree.nodes[#tree.nodes + 1] = info
      tree.spent = tree.spent + info.rank
      byName[info.name] = info
    end
    trees[t] = tree
  end
  return trees, byName
end
-- nazwa z planu („Precision”) moze byc koncowka nazwy w grze („Elemental Precision”)
local function findTal(byName, name)
  if byName[name] then return byName[name] end
  for n, info in pairs(byName) do if n:sub(-#name - 1) == " " .. name then return info end end
end
-- plan rozpisany na punkty: { poziom, talent, ranga po tym punkcie, rang razem }
local function planSeq()
  local seq, cnt = {}, {}
  for _, t in ipairs(G.TAL_PLAN or {}) do
    for lv = t[2], t[3] do
      cnt[t[1]] = (cnt[t[1]] or 0) + 1
      seq[#seq + 1] = { lv = lv, name = t[1], rank = cnt[t[1]], max = t[4] }
    end
  end
  return seq
end
local function unlocked(tree, info)
  if info.traits then return info.canBuy or info.rank > 0 or (tree and info.meets and tree.spent >= ((info.tier or 1) - 1) * 5) end
  return tree and tree.spent >= ((info.tier or 1) - 1) * 5 and info.meets
end

local function freePoints()
  if S.tal then return S.tal.points or 0 end
  return U.call(G.talentPoints) or 0
end
local function spend(info)
  if not info then return end
  if InCombatLockdown() then say("talenty zmieniasz poza walką.") return end
  local pts = freePoints()
  if pts <= 0 then say("nie masz wolnego punktu talentu.") return end
  if info.rank >= info.max then say(info.name .. " ma już wszystkie rangi.") return end
  local key = info.tab .. ":" .. tostring(info.i or info.nodeID)
  if S.confirm ~= key or GetTime() - (S.confirmAt or 0) > 4 then
    S.confirm, S.confirmAt = key, GetTime()
    S.spendBtn:SetLabel("Na pewno: " .. info.name .. " " .. (info.rank + 1) .. "/" .. info.max .. "?")
    C_Timer.After(4.2, function()
      if S.confirm == key then S.confirm = nil if S.page and S.page:IsVisible() then S.refresh() end end
    end)
    return
  end
  S.confirm = nil
  local ok
  if info.traits and S.tal and C_Traits and C_Traits.PurchaseRank then
    -- jak przycisk talentu gry: ranga, potem zatwierdzenie (Apply)
    local okP, bought = pcall(C_Traits.PurchaseRank, S.tal.configID, info.nodeID)
    if okP and bought then
      local CT = C_ClassTalents
      local okC, done = pcall(CT and CT.CommitConfig, nil)
      ok = okC and done ~= false
      if not ok and C_Traits.RollbackConfig then pcall(C_Traits.RollbackConfig, S.tal.configID) end
    end
  else
    ok = LearnTalent and pcall(LearnTalent, info.tab, info.i)
  end
  if not ok then
    say("gra nie dała wydać punktu z huba, otwieram okno talentów.")
    U.OpenGame(function()
      if G.openTalents then G.openTalents() elseif ToggleTalentFrame then ToggleTalentFrame() end
    end)
    return
  end
  C_Timer.After(0.4, function() if S.page and S.page:IsVisible() then S.refresh() end end)
end


local function node(i)
  local n = S.nodes[i]
  if n then return n end
  n = CreateFrame("Button", nil, S.area)
  n:SetSize(100, 60)
  n.slot = U.Slot(n, 40)
  n.slot:SetPoint("TOP", 0, 0)
  n.slot:EnableMouse(false)
  n.badge = CreateFrame("Frame", nil, n)
  n.badge:SetSize(30, 16)
  n.badge:SetPoint("CENTER", n.slot, "BOTTOMRIGHT", -1, 2)
  n.badge:SetFrameLevel(n.slot:GetFrameLevel() + 3)
  n.badge.bg = U.Rect(n.badge, C.bg, 1)
  n.badge.bg:SetAllPoints()
  U.Border(n.badge, C.edge)
  n.badge.t = U.Text(n.badge, 11, "body", C.muted)
  n.badge.t:SetPoint("CENTER", 0, 0)
  n.badge.t:SetJustifyH("CENTER")
  n.badge.t:SetJustifyV("MIDDLE")
  n.name = U.Text(n, 11, "body", C.muted)
  n.name:SetPoint("TOP", n.slot, "BOTTOM", 0, -5)
  n.name:SetWidth(98)
  -- 14.11 (gracz: „dalej nie pokazuje, jak to rozdawac dalej”): poziomy z planu Grimuara pod nazwa
  n.lv = U.Text(n, 10, "body", C.goldDim)
  n.lv:SetPoint("TOP", n.name, "BOTTOM", 0, -1)
  n.lv:SetWidth(110)
  n.lv:SetJustifyH("CENTER")
  n.name:SetJustifyH("CENTER")
  n:RegisterForClicks("LeftButtonUp", "RightButtonUp")
  n:SetScript("OnClick", function(self, btn)
    if not self.info then return end
    if btn == "RightButton" then spend(self.info)
    elseif IsModifiedClick and IsModifiedClick("CHATLINK") then
      local l = self.info.spellID and U.call((C_Spell and C_Spell.GetSpellLink) or GetSpellLink, self.info.spellID)
        or U.call(GetTalentLink, self.info.tab, self.info.i)
      if l then U.call(ChatEdit_InsertLink, l) end
    end
  end)
  n:SetScript("OnEnter", function(self)
    if not self.info then return end
    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
    local shown = self.info.spellID and pcall(GameTooltip.SetSpellByID, GameTooltip, self.info.spellID)
    if not shown and not pcall(GameTooltip.SetTalent, GameTooltip, self.info.tab, self.info.i) then
      GameTooltip:SetText(self.info.name)
      GameTooltip:AddLine("Ranga " .. self.info.rank .. " / " .. self.info.max, 1, 1, 1)
    end
    if self.plan then GameTooltip:AddLine("Grimuar: następny punkt według planu", C.gold[1], C.gold[2], C.gold[3]) end
    GameTooltip:Show()
  end)
  n:SetScript("OnLeave", function() GameTooltip:Hide() end)
  S.nodes[i] = n
  return n
end
local function tierLabel(i)
  local t = S.tiers[i]
  if t then return t end
  t = { text = U.Text(S.area, 11, "title", C.faint), line = U.Line(S.area, C.line, 0.6) }
  t.text:SetJustifyV("MIDDLE")
  S.tiers[i] = t
  return t
end

-- 14.11 (gracz: „chcialbym to widziec interaktywnie suwakiem, jak sie wypelnia”): suwak poziomu pod drzewkiem.
-- S.previewLv = poziom podgladu (nil = teraz); S.planAt[nazwa z planu] = ile punktow plan daje do tego poziomu.
local function previewOn()
  return S.previewLv ~= nil and S.previewLv ~= (UnitLevel("player") or 1)
end
local function computePreview()
  S.planAt = {}
  local lvl = S.previewLv or (UnitLevel("player") or 1)
  for _, e in ipairs(S.seq or {}) do
    if e.lv <= lvl then S.planAt[e.name] = e.rank end
  end
end
local function previewRank(info)
  local at = info.planName and S.planAt and S.planAt[info.planName] or 0
  return math.max(info.rank, at), at
end

local function drawTree()
  local tree = S.trees and S.trees[S.tree]
  local pv = previewOn()
  for i, b in ipairs(S.treeBtns) do
    local t = S.trees and S.trees[i]
    b:SetShown(t ~= nil)
    if t then
      local pts = 0
      for _, nd in ipairs(t.nodes) do pts = pts + (previewRank(nd)) end
      if not pv then pts = math.max(pts, t.spent) end
      b.t:SetText(t.name .. " " .. pts)
      U.Color(b.t, i == S.tree and C.gold or C.muted)
      b.u:SetShown(i == S.tree)
      b:SetWidth(math.floor(b.t:GetStringWidth() + 18))
    end
  end
  if not tree or #tree.nodes == 0 then
    for _, n in ipairs(S.nodes) do n:Hide() end
    for _, t in ipairs(S.tiers) do t.text:Hide() t.line:Hide() end
    S.treeEmpty:SetText((UnitLevel("player") or 1) < 10 and "Talenty od 10 poziomu." or "Gra nie podała drzewek talentów. Okno talentów: N.")
    S.treeEmpty:Show()
    return
  end
  S.treeEmpty:Hide()
  local maxTier = 1
  for _, info in ipairs(tree.nodes) do if info.tier > maxTier then maxTier = info.tier end end
  local aw, ah = S.area:GetWidth() or 500, S.area:GetHeight() or 480
  local cw = math.max(84, math.min(112, (aw - 64) / 4))
  local rh = math.max(58, math.min(76, ah / maxTier))
  local x0 = 64 + math.max(0, (aw - 64 - cw * 4) / 2)
  for t = 1, maxTier do
    local lab = tierLabel(t)
    local need = (t - 1) * 5
    lab.text:ClearAllPoints()
    lab.text:SetPoint("TOPLEFT", S.area, "TOPLEFT", 0, -((t - 1) * rh + 12))
    lab.text:SetText(t == 1 and "start" or ("od " .. need))
    U.Color(lab.text, tree.spent >= need and C.goldDim or C.faint)
    lab.line:ClearAllPoints()
    lab.line:SetPoint("TOPLEFT", S.area, "TOPLEFT", 0, -((t - 1) * rh) + 4)
    lab.line:SetPoint("TOPRIGHT", S.area, "TOPRIGHT", 0, -((t - 1) * rh) + 4)
    lab.line:SetShown(t > 1)
    lab.text:Show()
  end
  for t = maxTier + 1, #S.tiers do S.tiers[t].text:Hide() S.tiers[t].line:Hide() end
  local nx = S.nextInfo
  for i, info in ipairs(tree.nodes) do
    local n = node(i)
    n.info, n.plan = info, (nx == info)
    n:ClearAllPoints()
    n:SetPoint("TOP", S.area, "TOPLEFT", x0 + (info.col - 0.5) * cw, -((info.tier - 1) * rh + 4))
    n.slot.icon:SetTexture(info.icon or 134400)
    n.name:SetText(info.name)
    local lv = info.planName and S.planLevels and S.planLevels[info.planName]
    n.lv:SetText(lv and ("poz. " .. lv) or "")
    -- 14.11 (gracz: „dwa kolory: wydane i do wydania”, potem „reszta wyszarzona, widze tylko, co mam”, „suwakiem, jak
    -- sie wypelnia”): jasne jest tylko to, co masz (zielone) i co plan daje do poziomu z suwaka (zlote; domyslnie Twoj
    -- poziom), plus nastepny punkt (pelny zloty znaczek). Reszta szara.
    local shown, at = previewRank(info)
    local toDo = at > info.rank
    local bright = shown > 0 or n.plan
    n.badge.t:SetText(shown .. "/" .. info.max)
    n.slot.icon:SetDesaturated(not bright)
    n:SetAlpha(bright and 1 or 0.35)
    U.Color(n.lv, not bright and C.faint or ((info.target and info.rank >= info.target) and C.ok or C.gold))
    if n.plan then
      n.badge.bg:SetColorTexture(C.gold[1], C.gold[2], C.gold[3], 1)
      U.BorderColor(n.badge, C.gold)
      U.Color(n.badge.t, C.bg)
      U.BorderColor(n.slot, C.gold)
      U.Color(n.name, C.gold)
    elseif info.rank > 0 then
      n.badge.bg:SetColorTexture(C.bg[1], C.bg[2], C.bg[3], 1)
      U.BorderColor(n.badge, C.ok)
      U.Color(n.badge.t, toDo and C.gold or C.ok)
      U.BorderColor(n.slot, C.ok)
      U.Color(n.name, C.ok)
    elseif toDo then
      n.badge.bg:SetColorTexture(C.bg[1], C.bg[2], C.bg[3], 1)
      U.BorderColor(n.badge, C.goldDim)
      U.Color(n.badge.t, C.gold)
      U.BorderColor(n.slot, C.goldDim)
      U.Color(n.name, C.goldDim)
    else
      n.badge.bg:SetColorTexture(C.bg[1], C.bg[2], C.bg[3], 1)
      U.BorderColor(n.badge, C.edge)
      U.Color(n.badge.t, C.faint)
      U.BorderColor(n.slot, C.line)
      U.Color(n.name, C.faint)
    end
    n:Show()
  end
  for i = #tree.nodes + 1, #S.nodes do S.nodes[i]:Hide() end
end

local function drawPlan()
  local pts = (UnitLevel("player") or 1) >= 10 and freePoints() or 0
  S.pts:SetText(tostring(pts))
  U.Color(S.pts, pts > 0 and C.gold or C.faint)
  local l = UnitLevel("player") or 1
  if l < 10 then
    S.ptsNote:SetText("talenty od 10 poziomu, potem punkt co poziom")
  else
    S.ptsNote:SetText(plural(pts, "punkt talentu", "punkty talentów", "punktów talentów") .. (l < 60 and " · kolejny co poziom" or ""))
  end
  for i, row in ipairs(S.planRows) do
    local t = S.trees and S.trees[i]
    row.kv:SetShown(t ~= nil)
    row.bar:SetShown(t ~= nil)
    if t then
      row.kv:Set(t.name, t.spent .. " / " .. t.plan, t.spent >= t.plan and t.plan > 0 and C.ok or C.text)
      row.bar:SetValue(t.plan > 0 and t.spent / t.plan or 0)
    end
  end
  local tot = {}
  for i = 1, 3 do tot[i] = S.trees and S.trees[i] and S.trees[i].plan or 0 end
  S.planSum:SetText("Plan na 60: " .. table.concat(tot, " / ") .. " · " .. ((G.BD_META and G.BD_META.name) or "build"))
  local e, info = S.nextE, S.nextInfo
  if e and info then
    S.nxName:SetText(info.name)
    S.nxSub:SetText("Ranga " .. info.rank .. " / " .. info.max .. " · w planie na poziomie " .. e.lv)
    S.nxNote:SetText((G.TAL_NOTE and G.TAL_NOTE[e.name]) or "")
  elseif #(G.TAL_PLAN or {}) == 0 then
    S.nxName:SetText("Brak planu")
    S.nxSub:SetText("Grimuar nie podał planu talentów.")
    S.nxNote:SetText("")
  else
    S.nxName:SetText("Plan wykonany")
    S.nxSub:SetText("Wszystkie punkty stoją według planu Grimuara.")
    S.nxNote:SetText("")
  end
  if not S.confirm then S.spendBtn:SetLabel(pts > 0 and "Wydaj punkt" or "Brak punktów") end
  S.spendBtn:SetAlpha((pts > 0 and info and unlocked(S.trees[info.tab], info)) and 1 or 0.5)
  local idx, shown = S.nextIdx, 0
  for k = 1, #S.next5 do
    local e2 = idx and S.seq[idx + k]
    S.next5[k]:SetText(e2 and (e2.lv .. "   " .. e2.name .. (e2.max > 1 and (" " .. e2.rank .. "/" .. e2.max) or "")) or "")
    if e2 then shown = shown + 1 end
  end
  S.dalej:SetShown(shown > 0)
end


-- dla pliku glownego
M.computePreview = computePreview
M.drawPlan = drawPlan
M.drawTree = drawTree
M.findTal = findTal
M.planSeq = planSeq
M.readTalents = readTalents
M.spend = spend
M.tabName = tabName
