-- Grimuar UI: zakladka Umiejetnosci (makieta 14.11 „Hub · Umiejetnosci”, krok C).
-- Lewo: ksiega czarow wedlug szkol (Mroz, Ogien, Arkana, Ogolne) z ranga, mana i klawiszem z paska. LPM bierze czar
-- na kursor i chowa hub (paski akcji sa pod hubem), Shift+LPM daje link do czatu. Pod lista: co czeka u trenera.
-- Srodek: drzewko talentow (GetTalentInfo, jak WeakAuras na Forever). Prawo: plan Frosta z Grimuara (Core.lua TAL_PLAN):
-- nastepny punkt na zloto, „Wydaj punkt” z potwierdzeniem (LearnTalent; gdy gra nie pozwoli, okno talentow gry).
local ADDON, U = ...
local G, C = U.G, U.C
local say = U.say

U.UM = U.UM or {} -- wspolny stan z Umiejetnosci\Talenty.lua (wczytany wczesniej)
local M = U.UM
local S = M.S
local SCHOOL = { Frost = "Mróz", Fire = "Ogień", Arcane = "Arkana", General = "Ogólne" }
local ORDER = { Frost = 1, Fire = 2, Arcane = 3 }
local TREE_EN, TREE_PL = M.TREE_EN, M.TREE_PL
local CELL_W, CELL_H, L_W, R_W = 204, 46, 452, 310

local function plural(n, one, few, many)
  if n == 1 then return one end
  local d, h = n % 10, n % 100
  if d >= 2 and d <= 4 and (h < 12 or h > 14) then return few end
  return many
end

-- ---------- czary ----------
local function spellName(id)
  if C_Spell and C_Spell.GetSpellName then return (U.call(C_Spell.GetSpellName, id)) end
  return (U.call(GetSpellInfo, id))
end
local function spellIcon(id)
  if C_Spell and C_Spell.GetSpellTexture then return (U.call(C_Spell.GetSpellTexture, id)) end
  return (U.call(GetSpellTexture, id))
end
local function castMs(id)
  if C_Spell and C_Spell.GetSpellInfo then
    local i = U.call(C_Spell.GetSpellInfo, id)
    return type(i) == "table" and U.num(i.castTime) or nil
  end
  local _, _, _, ct = U.call(GetSpellInfo, id)
  return U.num(ct)
end
local function manaCost(id)
  local t = U.call((C_Spell and C_Spell.GetSpellPowerCost) or GetSpellPowerCost, id)
  if type(t) ~= "table" then return nil end
  for _, c in ipairs(t) do
    local v = U.num(c.cost)
    if v and v > 0 and (c.type == 0 or c.name == "MANA") then return v end
  end
end

-- ksiega: grupy wedlug linii (szkoly), w kazdej najwyzsza ranga kazdego czaru, bez pasywnych
local function readBook()
  local groups, byName = {}, {}
  local function add(line, id, sub, passive)
    if not id or passive then return end
    local name = spellName(id)
    if not name then return end
    local rank = tonumber(tostring(sub or ""):match("(%d+)"))
    line = line or "General"
    local g = groups[line]
    if not g then
      g = { key = line, title = SCHOOL[line] or line, order = ORDER[line] or 9, list = {} }
      groups[line] = g
    end
    local have = byName[name]
    if have then
      if (rank or 0) > (have.rank or 0) then have.id, have.rank = id, rank end
      return
    end
    local s = { id = id, name = name, rank = rank }
    byName[name] = s
    g.list[#g.list + 1] = s
  end
  local SB = C_SpellBook
  if SB and SB.GetNumSpellBookSkillLines and SB.GetSpellBookSkillLineInfo and SB.GetSpellBookItemInfo then
    local bank = Enum and Enum.SpellBookSpellBank and Enum.SpellBookSpellBank.Player or 0
    local spellType = Enum and Enum.SpellBookItemType and Enum.SpellBookItemType.Spell or 1
    for i = 1, U.call(SB.GetNumSpellBookSkillLines) or 0 do
      local line = U.call(SB.GetSpellBookSkillLineInfo, i)
      if type(line) == "table" and not line.shouldHide then
        local off = line.itemIndexOffset or 0
        for k = off + 1, off + (line.numSpellBookItems or 0) do
          local info = U.call(SB.GetSpellBookItemInfo, k, bank)
          if type(info) == "table" and info.spellID and info.itemType == spellType then
            add(line.name, info.spellID, info.subName, info.isPassive)
          end
        end
      end
    end
  elseif GetNumSpellTabs and GetSpellTabInfo and GetSpellBookItemInfo then
    for i = 1, U.call(GetNumSpellTabs) or 0 do
      local tabName, _, off, n = U.call(GetSpellTabInfo, i)
      for k = (off or 0) + 1, (off or 0) + (n or 0) do
        local kind, id = U.call(GetSpellBookItemInfo, k, "spell")
        if kind == "SPELL" and id then
          local _, sub = U.call(GetSpellBookItemName, k, "spell")
          add(tabName, id, sub, U.call(IsPassiveSpell, k, "spell"))
        end
      end
    end
  end
  local out = {}
  for _, g in pairs(groups) do if #g.list > 0 then out[#out + 1] = g end end
  table.sort(out, function(a, b)
    if a.order ~= b.order then return a.order < b.order end
    return a.title < b.title
  end)
  return out, byName
end
U.readSpellBook = readBook -- 15.11: tez dla edytora buildow (Buildy\EdytorSekcje.lua, lista czarow)

-- klawisz czaru z paskow akcji (takze makro z tym czarem, np. „Owca”)
local BARS = { { 1, "ACTIONBUTTON" }, { 61, "MULTIACTIONBAR1BUTTON" }, { 49, "MULTIACTIONBAR2BUTTON" },
  { 25, "MULTIACTIONBAR3BUTTON" }, { 37, "MULTIACTIONBAR4BUTTON" }, { 145, "MULTIACTIONBAR5BUTTON" },
  { 157, "MULTIACTIONBAR6BUTTON" }, { 169, "MULTIACTIONBAR7BUTTON" } }
local function shortKey(k)
  if G.shortKey then
    local ok, s = pcall(G.shortKey, k)
    if ok and s then return s end
  end
  return k
end
local function keyMap()
  local map = {}
  for _, b in ipairs(BARS) do
    for i = 1, 12 do
      local kind, id = U.call(GetActionInfo, b[1] + i - 1)
      local name, macro
      if kind == "spell" and id then
        name = spellName(id)
      elseif kind == "macro" and id then
        local sid = U.call(GetMacroSpell, id)
        if sid then name, macro = spellName(sid), (U.call(GetMacroInfo, id)) end
      end
      if name and not map[name] then
        local key = U.call(GetBindingKey, b[2] .. i)
        if key then map[name] = { key = shortKey(key), macro = macro } end
      end
    end
  end
  return map
end

-- nowe czary: ktorych ta postac jeszcze nie widziala w hubie
local function seenStore()
  local db = U.db()
  db.spellsSeen = db.spellsSeen or {}
  local k = (G.charKey and G.charKey()) or (UnitName("player") or "?")
  return db.spellsSeen, k
end
local function markNew(byName)
  local all, k = seenStore()
  S.new = {}
  if not all[k] then
    all[k] = {}
    for n in pairs(byName) do all[k][n] = true end
    return
  end
  for n in pairs(byName) do if not all[k][n] then S.new[n] = true end end
end
local function markSeen()
  local all, k = seenStore()
  all[k] = all[k] or {}
  for n in pairs(S.byName or {}) do all[k][n] = true end
end

-- trener (14.11, zrzut trenera: „tu brakuje kosztow”): co czeka teraz i na kolejnych poziomach, z kosztem.
-- Dane trenera Forever z Polestara (QoL/Spells: poziom, czar, ranga, koszt w miedziakach, rasy); plan Frosta z
-- Grimuara (Trener.lua G.trainWanted) dzieli na „kup” i „opcjonalnie”. Bez Polestara: lista Grimuara bez kosztow.
local function known(id)
  if C_SpellBook and C_SpellBook.IsSpellKnown and U.call(C_SpellBook.IsSpellKnown, id) then return true end
  if IsPlayerSpell and U.call(IsPlayerSpell, id) then return true end
  return U.call(IsSpellKnown, id) and true or false
end
local function coins(c)
  c = math.floor(c or 0)
  local g, s, k = math.floor(c / 10000), math.floor((c % 10000) / 100), c % 100
  local out = {}
  if g > 0 then out[#out + 1] = g .. "g" end
  if s > 0 then out[#out + 1] = s .. "s" end
  if k > 0 or #out == 0 then out[#out + 1] = k .. "c" end
  return table.concat(out, " ")
end
S.coins = coins
local function training()
  local l = UnitLevel("player") or 1
  local res = { now = {}, opt = {}, nowCost = 0, optCost = 0, next = {} }
  local Sp = Polestar and Polestar.QoL and Polestar.QoL.Spells
  local _, class = UnitClass("player")
  local d = Sp and Sp.Data and U.call(Sp.Data, class)
  if type(d) == "table" and type(d.byLevel) == "table" then
    local rid = tonumber((select(3, UnitRace("player"))))
    local levels, seen = {}, {}
    for lvl in pairs(d.byLevel) do levels[#levels + 1] = lvl end
    table.sort(levels)
    for _, lvl in ipairs(levels) do
      for _, e in ipairs(d.byLevel[lvl]) do
        local races = e.races or 0
        local raceOk = races == 0 or not rid or math.floor(races / 2 ^ (rid - 1)) % 2 == 1
        local nm = raceOk and spellName(e.id)
        if nm then
          local r = e.rank or 0
          local label = r > 1 and (nm .. " " .. r) or nm
          local want = not G.trainWanted or U.call(G.trainWanted, nm, r > 0 and ("Rank " .. r) or "")
          local cost = e.cost or 0
          if lvl <= l then
            if not seen[label] and not known(e.id) then
              seen[label] = true
              if want then res.now[#res.now + 1] = label res.nowCost = res.nowCost + cost
              else res.opt[#res.opt + 1] = label res.optCost = res.optCost + cost end
            end
          else
            local nx = res.next[#res.next]
            if not nx or nx.lvl ~= lvl then
              if #res.next >= 2 then break end
              nx = { lvl = lvl, list = {}, cost = 0, optCost = 0 }
              res.next[#res.next + 1] = nx
            end
            nx.list[#nx.list + 1] = want and label or (U.hex(C.faint) .. label .. "|r")
            if want then nx.cost = nx.cost + cost else nx.optCost = nx.optCost + cost end
          end
        end
      end
      if #res.next >= 2 and res.next[2].lvl ~= lvl and lvl > l then break end
    end
    res.costs = true
  else
    res.now = U.call(G.missingTraining) or {}
    res.opt = U.call(G.optionalTraining) or {}
    if type(G.SPELLS) == "table" then
      local nextL
      for _, s in ipairs(G.SPELLS) do if s[1] > l and (not nextL or s[1] < nextL) then nextL = s[1] end end
      local nx = { lvl = nextL, list = {} }
      for _, s in ipairs(G.SPELLS) do if s[1] == nextL then nx.list[#nx.list + 1] = s[2] end end
      if nextL then res.next[1] = nx end
    end
  end
  return res
end

-- ---------- talenty: Umiejetnosci\Talenty.lua (podzial 14.11) ----------
local function computePreview(...) return M.computePreview(...) end
local function drawPlan(...) return M.drawPlan(...) end
local function drawTree(...) return M.drawTree(...) end
local function findTal(...) return M.findTal(...) end
local function planSeq(...) return M.planSeq(...) end
local function readTalents(...) return M.readTalents(...) end
local function spend(...) return M.spend(...) end
local function tabName(...) return M.tabName(...) end

-- ---------- widzety ----------
local function pickup(id)
  if InCombatLockdown() then return end
  if C_Spell and C_Spell.PickupSpell then pcall(C_Spell.PickupSpell, id) elseif PickupSpell then pcall(PickupSpell, id) end
  if GetCursorInfo and GetCursorInfo() then
    U.Close()
    say("połóż czar na pasku akcji.")
  end
end
local function chatLink(id)
  local l = U.call((C_Spell and C_Spell.GetSpellLink) or GetSpellLink, id)
  if l then U.call(ChatEdit_InsertLink, l) end
end

local function cell(i)
  local c = S.cells[i]
  if c then return c end
  c = CreateFrame("Button", nil, S.list)
  c:SetSize(CELL_W, CELL_H - 6)
  local hl = c:CreateTexture(nil, "HIGHLIGHT")
  hl:SetAllPoints()
  hl:SetColorTexture(1, 1, 1, 0.05)
  c.slot = U.Slot(c, 38)
  c.slot:SetPoint("LEFT", 0, 0)
  c.slot:EnableMouse(false)
  c.key = U.Key(c, "")
  c.key:SetPoint("RIGHT", -2, 0)
  c.name = U.Text(c, 14, "body", C.text)
  c.name:SetPoint("TOPLEFT", c.slot, "TOPRIGHT", 9, -2)
  c.name:SetWidth(CELL_W - 89)
  c.sub = U.Text(c, 11, "body", C.muted)
  c.sub:SetPoint("TOPLEFT", c.name, "BOTTOMLEFT", 0, -4)
  c.sub:SetWidth(CELL_W - 89)
  c:RegisterForClicks("LeftButtonUp")
  c:RegisterForDrag("LeftButton")
  c:SetScript("OnClick", function(self)
    if not self.s then return end
    if IsModifiedClick and IsModifiedClick("CHATLINK") then chatLink(self.s.id) else pickup(self.s.id) end
  end)
  c:SetScript("OnDragStart", function(self) if self.s then pickup(self.s.id) end end)
  c:SetScript("OnEnter", function(self)
    if not self.s then return end
    U.TT:SetOwner(self, "ANCHOR_RIGHT")
    if not pcall(U.TT.SetSpellByID, U.TT, self.s.id) then U.TT:SetText(self.s.name) end
    U.TT:Show()
  end)
  c:SetScript("OnLeave", function() U.TT:Hide() end)
  S.cells[i] = c
  return c
end
local function head(i)
  local h = S.heads[i]
  if h then return h end
  h = CreateFrame("Frame", nil, S.list)
  h:SetSize(CELL_W * 2 + 12, 22)
  h.text = U.Text(h, 12, "title", C.goldDim)
  h.text:SetPoint("LEFT", 0, 0)
  h.text:SetJustifyV("MIDDLE")
  h.line = U.Line(h, C.line)
  h.line:SetPoint("LEFT", h.text, "RIGHT", 10, 0)
  h.line:SetPoint("RIGHT", h, "RIGHT", 0, 0)
  S.heads[i] = h
  return h
end
local function fill(c, s, k)
  c.s = s
  c.slot.icon:SetTexture(spellIcon(s.id) or 134400)
  local new = S.new and S.new[s.name]
  c.name:SetText(s.name)
  U.Color(c.name, new and C.frost or C.text)
  local parts = {}
  if new then parts[#parts + 1] = "nowy" end
  if s.rank then parts[#parts + 1] = "Ranga " .. s.rank end
  local mana = U.call(manaCost, s.id)
  if mana then parts[#parts + 1] = mana .. " many" end
  local ct = castMs(s.id)
  if ct then parts[#parts + 1] = ct == 0 and "natychmiast" or (string.format("%.1f s", ct / 1000):gsub("%.", ",")) end
  if k and k.macro then parts[#parts + 1] = "makro „" .. k.macro .. "”" end
  c.sub:SetText(table.concat(parts, " · "))
  if k then c.key:SetKey(k.key) c.key:Show() else c.key:Hide() end
  U.BorderColor(c.slot, new and C.frost or C.line)
end

local function drawBook()
  local y, ci, hi = 0, 0, 0
  for _, g in ipairs(S.groups or {}) do
    if S.filter == "all" or S.filter == g.key then
      hi = hi + 1
      local h = head(hi)
      h:ClearAllPoints()
      h:SetPoint("TOPLEFT", S.list, "TOPLEFT", 0, -y)
      h.text:SetText(g.title)
      h:Show()
      y = y + 28
      for k, s in ipairs(g.list) do
        ci = ci + 1
        local c = cell(ci)
        c:ClearAllPoints()
        c:SetPoint("TOPLEFT", S.list, "TOPLEFT", ((k - 1) % 2) * (CELL_W + 12), -(y + math.floor((k - 1) / 2) * CELL_H))
        fill(c, s, S.keys and S.keys[s.name])
        c:Show()
      end
      y = y + math.ceil(#g.list / 2) * CELL_H + 6
    end
  end
  for i = ci + 1, #S.cells do S.cells[i]:Hide() end
  for i = hi + 1, #S.heads do S.heads[i]:Hide() end
  S.list:SetHeight(math.max(10, y))
  local max = math.max(0, y - S.view:GetHeight())
  if S.view:GetVerticalScroll() > max then S.view:SetVerticalScroll(max) end
end

local function refresh()
  if not S.page then return end
  S.groups, S.byName = readBook()
  S.keys = keyMap()
  if not S.new then markNew(S.byName) end
  drawBook()
  local tr = training()
  local parts = {}
  local function cost(c) return (tr.costs and c and c > 0) and (" · " .. coins(c)) or "" end
  if #tr.now > 0 then parts[#parts + 1] = U.hex(C.gold) .. "Teraz u trenera:|r " .. table.concat(tr.now, ", ") .. cost(tr.nowCost) end
  if #tr.opt > 0 then parts[#parts + 1] = U.hex(C.muted) .. "Opcjonalnie: " .. table.concat(tr.opt, ", ") .. cost(tr.optCost) .. "|r" end
  for _, nx in ipairs(tr.next) do
    if #nx.list > 0 then parts[#parts + 1] = "Na " .. nx.lvl .. ": " .. table.concat(nx.list, ", ") .. cost(nx.cost) end
  end
  if #parts == 0 then parts[1] = "U trenera nic na Ciebie nie czeka." end
  if tr.costs then
    local money = U.num(GetMoney and GetMoney()) or 0
    local need = tr.nowCost + ((tr.next[1] and tr.next[1].cost) or 0)
    parts[#parts + 1] = "Masz " .. coins(money) .. (need > 0 and (money >= need and (U.hex(C.ok) .. " · starczy na teraz i następny poziom|r")
      or (U.hex(C.danger) .. " · na teraz i następny poziom trzeba " .. coins(need) .. "|r")) or "")
  end
  S.train:SetText(table.concat(parts, "\n"))
  if S.psRow then
    local okR, h = pcall(S.psRow.Draw, S.psRow, L_W - 36)
    h = okR and h or 0
    S.view:SetPoint("BOTTOMRIGHT", S.L, "BOTTOMRIGHT", -14, h > 0 and (162 + h) or 146)
  end

  S.trees, S.talByName = readTalents()
  S.seq = planSeq()
  if S.slider and not S.previewLv then
    local l = math.max(10, math.min(60, UnitLevel("player") or 10))
    S.sliderSilent = true
    S.slider:SetValue(l)
    S.sliderSilent = false
    S.slT:SetText("poziom " .. l .. " (teraz)")
  end
  computePreview()
  S.planLevels = {}
  for _, tp in ipairs(G.TAL_PLAN or {}) do
    local r = tp[2] == tp[3] and tostring(tp[2]) or (tp[2] .. "–" .. tp[3])
    S.planLevels[tp[1]] = S.planLevels[tp[1]] and (S.planLevels[tp[1]] .. ", " .. r) or r
  end
  S.nextIdx, S.nextInfo, S.nextE = nil, nil, nil
  for i, e in ipairs(S.seq) do
    local info = findTal(S.talByName, e.name)
    if info and info.rank < e.rank then S.nextIdx, S.nextInfo, S.nextE = i, info, e break end
  end
  local planned = {}
  for _, e in ipairs(S.seq) do planned[e.name] = e.rank end
  for name, cnt in pairs(planned) do
    local info = findTal(S.talByName, name)
    if info and S.trees[info.tab] then S.trees[info.tab].plan = S.trees[info.tab].plan + cnt end
    if info then info.target, info.planName = cnt, name end
  end
  if not S.tree or not S.trees[S.tree] then
    S.tree = (S.nextInfo and S.nextInfo.tab) or (S.trees[3] and 3) or 1
  end
  drawTree()
  drawPlan()
end
S.refresh = refresh

-- ---------- uklad ----------
local FILTERS = { { "all", "Wszystkie" }, { "Frost", "Mróz" }, { "Fire", "Ogień" }, { "Arcane", "Arkana" } }

local function build(page)
  S.page = page
  -- lewo: ksiega
  local L = U.Panel(page, 0.86, true)
  L:SetPoint("TOPLEFT") L:SetPoint("BOTTOMLEFT") L:SetWidth(L_W)
  local h = U.H2(L, "Księga czarów")
  h:SetPoint("TOPLEFT", 18, -16)
  local prev
  S.filterBtns = {}
  for i = #FILTERS, 1, -1 do
    local f = FILTERS[i]
    local b = CreateFrame("Button", nil, L)
    b:SetSize(i == 1 and 82 or 62, 22)
    if prev then b:SetPoint("RIGHT", prev, "LEFT", -2, 0) else b:SetPoint("TOPRIGHT", L, "TOPRIGHT", -14, -13) end
    b.t = U.Text(b, 12, "title", C.muted)
    b.t:SetPoint("CENTER", 0, 1)
    b.t:SetJustifyH("CENTER")
    b.t:SetText(f[2])
    b.u = U.Line(b, C.gold)
    b.u:SetPoint("BOTTOMLEFT", 8, 0) b.u:SetPoint("BOTTOMRIGHT", -8, 0)
    b.key = f[1]
    b:SetScript("OnClick", function(self)
      S.filter = self.key
      for _, o in ipairs(S.filterBtns) do U.Color(o.t, o.key == S.filter and C.gold or C.muted) o.u:SetShown(o.key == S.filter) end
      S.view:SetVerticalScroll(0)
      drawBook()
    end)
    U.Color(b.t, f[1] == S.filter and C.gold or C.muted)
    b.u:SetShown(f[1] == S.filter)
    S.filterBtns[#S.filterBtns + 1] = b
    prev = b
  end
  local trainL = U.Label(L, "Trener")
  trainL:SetPoint("BOTTOMLEFT", L, "BOTTOMLEFT", 18, 118)
  S.train = U.Para(L, 13, L_W - 36, C.text)
  S.train:SetPoint("TOPLEFT", trainL, "BOTTOMLEFT", 0, -6)
  pcall(S.train.SetMaxLines, S.train, 7)
  local sep = U.Line(L, C.line)
  sep:SetPoint("BOTTOMLEFT", trainL, "TOPLEFT", 0, 10)
  sep:SetWidth(L_W - 36)
  local view = CreateFrame("ScrollFrame", nil, L)
  view:SetPoint("TOPLEFT", h, "BOTTOMLEFT", 0, -14)
  view:SetPoint("BOTTOMRIGHT", L, "BOTTOMRIGHT", -14, 146)
  -- 15.11 (R30 P09): karty Polestara nad „Trener”: czary na nastepny poziom z kosztem i gdzie trenowac
  -- (UmiejetnosciPolestar.lua); gdy sa, lista czarow konczy sie wyzej
  S.L = L
  if U.psTrainRow then
    S.psRow = U.psTrainRow(L)
    S.psRow:SetPoint("BOTTOMLEFT", L, "BOTTOMLEFT", 18, 152)
    S.psRow:Hide()
  end
  local list = CreateFrame("Frame", nil, view)
  list:SetSize(CELL_W * 2 + 12, 10)
  view:SetScrollChild(list)
  view:EnableMouseWheel(true)
  view:SetScript("OnMouseWheel", function(self, d)
    local max = math.max(0, list:GetHeight() - self:GetHeight())
    self:SetVerticalScroll(math.max(0, math.min(max, self:GetVerticalScroll() - d * CELL_H * 2)))
  end)
  S.view, S.list = view, list

  -- prawo: punkty i plan
  local R = U.Panel(page, 0.86, true)
  R:SetPoint("TOPRIGHT") R:SetPoint("BOTTOMRIGHT") R:SetWidth(R_W)
  local w = R_W - 36
  local dl = U.Label(R, "Do wydania")
  dl:SetPoint("TOPLEFT", 18, -18)
  S.pts = U.Text(R, 44, "title", C.gold)
  S.pts:SetPoint("TOPLEFT", dl, "BOTTOMLEFT", 0, -4)
  S.ptsNote = U.Para(R, 13, w - 60, C.muted)
  S.ptsNote:SetPoint("LEFT", S.pts, "RIGHT", 14, -4)
  local s1 = U.Line(R, C.line)
  s1:SetPoint("TOPLEFT", S.pts, "BOTTOMLEFT", 0, -12)
  s1:SetWidth(w)
  local pl = U.Label(R, "Plan Grimuara")
  pl:SetPoint("TOPLEFT", s1, "BOTTOMLEFT", 0, -14)
  local anchor = pl
  for i = 1, 3 do
    local kv = U.KV(R, w, 13)
    kv:SetPoint("TOPLEFT", anchor, "BOTTOMLEFT", 0, i == 1 and -8 or -6)
    local bar = U.Bar(R, 5, C.goldDim)
    bar:SetPoint("TOPLEFT", kv, "BOTTOMLEFT", 0, -2)
    bar:SetWidth(w)
    S.planRows[i] = { kv = kv, bar = bar }
    anchor = bar
  end
  S.planSum = U.Para(R, 12, w, C.faint)
  S.planSum:SetPoint("TOPLEFT", anchor, "BOTTOMLEFT", 0, -10)
  local s2 = U.Line(R, C.line)
  s2:SetPoint("TOPLEFT", S.planSum, "BOTTOMLEFT", 0, -14)
  s2:SetWidth(w)
  local nl = U.Label(R, "Następny według planu")
  nl:SetPoint("TOPLEFT", s2, "BOTTOMLEFT", 0, -14)
  S.nxName = U.Text(R, 20, "title", C.gold)
  S.nxName:SetPoint("TOPLEFT", nl, "BOTTOMLEFT", 0, -6)
  S.nxName:SetWidth(w)
  S.nxSub = U.Text(R, 12, "body", C.muted)
  S.nxSub:SetPoint("TOPLEFT", S.nxName, "BOTTOMLEFT", 0, -5)
  S.nxSub:SetWidth(w)
  S.nxNote = U.Para(R, 13, w, C.text)
  S.nxNote:SetPoint("TOPLEFT", S.nxSub, "BOTTOMLEFT", 0, -8)
  S.spendBtn = U.Button(R, "Wydaj punkt", nil, 30, true)
  S.spendBtn:SetPoint("TOPLEFT", S.nxNote, "BOTTOMLEFT", 0, -14)
  S.spendBtn:SetScript("OnClick", function() spend(S.nextInfo) end)
  local win = U.Button(R, "Okno talentów gry", nil, 30)
  win:SetPoint("TOPLEFT", S.spendBtn, "BOTTOMLEFT", 0, -8)
  win:SetScript("OnClick", function()
    U.OpenGame(function() if G.openTalents then G.openTalents() elseif ToggleTalentFrame then ToggleTalentFrame() end end)
  end)
  S.dalej = U.Label(R, "Dalej w planie")
  S.dalej:SetPoint("TOPLEFT", win, "BOTTOMLEFT", 0, -18)
  local a2 = S.dalej
  for k = 1, 5 do
    local t = U.Text(R, 12, "body", C.muted)
    t:SetPoint("TOPLEFT", a2, "BOTTOMLEFT", 0, k == 1 and -6 or -3)
    t:SetWidth(w)
    S.next5[k] = t
    a2 = t
  end
  local foot = U.Para(R, 11, w, C.faint)
  foot:SetPoint("BOTTOMLEFT", R, "BOTTOMLEFT", 18, 14)
  foot:SetText("Talenty zmieniasz poza walką. Reset kosztuje złoto u trenera.")

  -- srodek: drzewko
  local M = U.Panel(page, 0.86, true)
  M:SetPoint("TOPLEFT", L, "TOPRIGHT", 20, 0)
  M:SetPoint("BOTTOMRIGHT", R, "BOTTOMLEFT", -20, 0)
  local th = U.H2(M, "Talenty")
  th:SetPoint("TOPLEFT", 18, -16)
  local p2
  for i = 1, 3 do
    local b = CreateFrame("Button", nil, M)
    b:SetSize(90, 22)
    if p2 then b:SetPoint("LEFT", p2, "RIGHT", 2, 0) else b:SetPoint("LEFT", th, "RIGHT", 18, 0) end
    b.t = U.Text(b, 12, "title", C.muted)
    b.t:SetPoint("CENTER", 0, 1)
    b.t:SetJustifyH("CENTER")
    b.u = U.Line(b, C.gold)
    b.u:SetPoint("BOTTOMLEFT", 8, -2) b.u:SetPoint("BOTTOMRIGHT", -8, -2)
    b:SetScript("OnClick", function() S.tree = i drawTree() end)
    S.treeBtns[i] = b
    p2 = b
  end
  local key = U.Text(M, 11, "body", C.faint)
  key:SetPoint("TOPRIGHT", M, "TOPRIGHT", -18, -20)
  key:SetJustifyH("RIGHT")
  key:SetText(U.hex(C.ok) .. "zielone: wydane|r · " .. U.hex(C.gold) .. "złote: plan Grimuara (ranga/cel)|r · pełne złote: następny punkt")
  S.area = CreateFrame("Frame", nil, M)
  S.area:SetPoint("TOPLEFT", th, "BOTTOMLEFT", 0, -16)
  S.area:SetPoint("BOTTOMRIGHT", M, "BOTTOMRIGHT", -18, 58)
  local sl = CreateFrame("Slider", nil, M)
  sl:SetOrientation("HORIZONTAL")
  sl:SetSize(360, 12)
  sl:SetPoint("BOTTOMLEFT", M, "BOTTOMLEFT", 186, 24)
  local track = U.Rect(sl, C.bg, 0.95)
  track:SetAllPoints()
  U.Border(sl, C.edge)
  local thumb = sl:CreateTexture(nil, "OVERLAY")
  thumb:SetColorTexture(C.gold[1], C.gold[2], C.gold[3], 1)
  thumb:SetSize(12, 22)
  sl:SetThumbTexture(thumb)
  sl:SetMinMaxValues(10, 60)
  sl:SetValueStep(1)
  pcall(sl.SetObeyStepOnDrag, sl, true)
  -- 14.11 (gracz: „przycisk plus i minus, zeby pojedynczo dalo sie klikac”)
  local slMinus = U.Button(M, "-", 28, 24)
  slMinus:SetPoint("RIGHT", sl, "LEFT", -8, 0)
  slMinus:SetScript("OnClick", function() sl:SetValue(math.max(10, (sl:GetValue() or 10) - 1)) end)
  local slPlus = U.Button(M, "+", 28, 24)
  slPlus:SetPoint("LEFT", sl, "RIGHT", 8, 0)
  slPlus:SetScript("OnClick", function() sl:SetValue(math.min(60, (sl:GetValue() or 10) + 1)) end)
  local slL = U.Label(M, "Podgląd planu")
  slL:SetPoint("RIGHT", slMinus, "LEFT", -12, 1)
  S.slT = U.Text(M, 13, "body", C.text)
  S.slT:SetPoint("LEFT", slPlus, "RIGHT", 12, 0)
  S.slT:SetJustifyV("MIDDLE")
  local now = U.Button(M, "Teraz", nil, 26)
  now:SetPoint("LEFT", S.slT, "RIGHT", 14, 0)
  S.slider = sl
  sl:SetScript("OnValueChanged", function(self, v)
    if S.sliderSilent then return end
    v = math.floor((v or 10) + 0.5)
    S.previewLv = v
    computePreview()
    local l = UnitLevel("player") or 1
    S.slT:SetText("poziom " .. v .. (v == l and " (teraz)" or (v > l and ("  ·  za " .. (v - l) .. " poz.") or "")))
    drawTree()
  end)
  sl:EnableMouseWheel(true)
  sl:SetScript("OnMouseWheel", function(self, d) self:SetValue(math.max(10, math.min(60, (self:GetValue() or 10) + d))) end)
  now:SetScript("OnClick", function() sl:SetValue(math.max(10, UnitLevel("player") or 10)) end)
  S.treeEmpty = U.Para(S.area, 14, 360, C.muted)
  S.treeEmpty:SetPoint("CENTER")
  S.treeEmpty:SetJustifyH("CENTER")
  S.treeEmpty:Hide()
  U.fontChanged[#U.fontChanged + 1] = function() if page:IsVisible() then drawTree() end end
end

M.plural, M.spellIcon, M.spellName, M.refresh = plural, spellIcon, spellName, refresh

-- ---------- zdarzenia (tylko gdy zakladka jest otwarta) ----------
local ev = CreateFrame("Frame")
local EVENTS = { "TRAIT_CONFIG_UPDATED", "TRAIT_NODE_CHANGED", "SPELLS_CHANGED", "LEARNED_SPELL_IN_TAB", "CHARACTER_POINTS_CHANGED", "PLAYER_TALENT_UPDATE", "PLAYER_LEVEL_UP",
  "ACTIONBAR_SLOT_CHANGED", "UPDATE_BINDINGS" }
ev:SetScript("OnEvent", function()
  if S.pending then return end
  S.pending = true
  C_Timer.After(0.25, function()
    S.pending = false
    if S.page and S.page:IsVisible() then pcall(refresh) end
  end)
end)

U.RegisterTab({
  id = "umiejetnosci", order = 2, title = "Umiejętności", keys = "P · N",
  hints = { { { "LPM" }, "Czar na pasek" }, { { "Shift", "LPM" }, "Link do czatu" }, { { "PPM" }, "Wydaj punkt" } },
  note = "Złoty talent to następny punkt według planu Grimuara",
  build = build,
  refresh = function()
    for _, e in ipairs(EVENTS) do pcall(ev.RegisterEvent, ev, e) end
    refresh()
    C_Timer.After(0, function() if S.page and S.page:IsVisible() then pcall(drawTree) end end)
  end,
  leave = function()
    ev:UnregisterAllEvents()
    S.confirm = nil
    if not U.testing then markSeen() end -- autotest huba nie odhacza „nowych” czarow
    S.new = nil
  end,
})
