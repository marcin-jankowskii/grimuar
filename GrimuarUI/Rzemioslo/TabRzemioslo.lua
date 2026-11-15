-- Grimuar UI: zakladka Rzemioslo (makieta 14.11 „Hub · Rzemioslo”, krok C).
-- Lewo: profesje z gry z limitem i ranga u trenera (plan R13 z Profesje.lua) oraz te, ktorych jeszcze nie masz.
-- Srodek: przepisy z ostatniego otwarcia okna profesji (zapis GrimuarUIDB.przepisy), kolor trudnosci i ile zrobisz
-- z tego, co masz w torbach. Prawo: skladniki i „Utworz”. Gra tworzy tylko przy otwartym oknie tej profesji, wiec
-- „Otworz okno profesji” zamyka hub (ksiega profesji), a po kliknieciu profesji hub wraca sam na te zakladke.
-- 15.11: przelacznik „Poradnik Polestara” nad lista: kroki poradnika profesji Polestara dla Twojego poziomu
-- (RzemiosloPolestar.lua, panel z blokami Hub\Bloki.lua).
local ADDON, U = ...
local G, C = U.G, U.C
local say = U.say

local R = { rows = {}, heads = {}, profRows = {}, reag = {}, todo = {}, count = 1, filter = "all", sel = {} }
local PL = { Herbalism = "Zielarstwo", Mining = "Górnictwo", Smelting = "Wytapianie", ["First Aid"] = "Pierwsza pomoc",
  Cooking = "Gotowanie", Fishing = "Wędkarstwo", Tailoring = "Krawiectwo", Skinning = "Skórowanie", Alchemy = "Alchemia",
  Blacksmithing = "Kowalstwo", Enchanting = "Zaklinanie", Engineering = "Inżynieria", Leatherworking = "Kaletnictwo",
  Jewelcrafting = "Jubilerstwo" }
local RANK_PL = { Journeyman = "Czeladnik", Expert = "Ekspert", Artisan = "Mistrz" }
local DCOL = { [0] = { 0.925, 0.541, 0.333 }, [1] = { 0.91, 0.761, 0.353 }, [2] = { 0.498, 0.792, 0.353 }, [3] = { 0.353, 0.337, 0.302 },
  [4] = { 0.8, 0.25, 0.2 }, [5] = { 0.56, 0.75, 0.91 } }
local DTXT = { [0] = "pewny punkt", [1] = "zwykle punkt", [2] = "rzadko punkt", [3] = "bez punktu", [4] = "jeszcze nie zbierzesz" }
local DIFF = { optimal = 0, difficult = 0, medium = 1, easy = 2, trivial = 3 }
local GATHER = { Herbalism = true, Mining = true, Fishing = true, Skinning = true }
local EXTRA = { "Alchemy", "Blacksmithing", "Enchanting", "Engineering", "Leatherworking", "Skinning", "Jewelcrafting" }
local TODO_NOTE = { Mining = "w planie", Fishing = "do 20", Cooking = "opcja", Tailoring = "od 40–42", Herbalism = "w planie",
  ["First Aid"] = "w planie" }
local NOTE = { ["First Aid"] = "W Forever robi też mikstury leczenia z ziół.",
  Herbalism = "Incense Candle pomiń: buff nie łączy się z Arcane Intellect. Zioła sprzedaj albo na mikstury." }
local L_W, R_W = 330, 360

PL["_cele"] = "Zadania profesji"
NOTE["_cele"] = "zbierz, zrób, do trenera, sprzedaj: liczą się same z umiejętności i toreb. Te same są w Dzienniku (J) z przyciskiem Prowadź."
local function pl(name) return PL[name] or name end
local function cacheKey(prof) return prof == "Mining" and "Smelting" or prof end

-- ---------- przepisy: zapis z okna profesji ----------
local function store()
  local db = U.db()
  db.przepisy = db.przepisy or {}
  local k = (G.charKey and G.charKey()) or (UnitName("player") or "?")
  db.przepisy[k] = db.przepisy[k] or {}
  return db.przepisy[k]
end
local function itemId(link) return link and tonumber(tostring(link):match("item:(%d+)")) end

local function scanNew()
  local T = C_TradeSkillUI
  if not (T and T.GetAllRecipeIDs and T.GetRecipeInfo) then return nil end
  local list = {}
  for _, id in ipairs(U.call(T.GetAllRecipeIDs) or {}) do
    local r = U.call(T.GetRecipeInfo, id)
    if type(r) == "table" and r.learned and r.name then
      local d = r.relativeDifficulty
      if type(d) ~= "number" then d = DIFF[r.difficulty or ""] end
      local cat = r.categoryID and U.call(T.GetCategoryInfo, r.categoryID)
      local e = { name = r.name, d = d or 2, n = U.num(r.numAvailable) or 0, id = id, icon = r.icon, reagents = {},
        group = type(cat) == "table" and cat.name or nil, link = U.call(T.GetRecipeItemLink, id) or r.hyperlink }
      local s = U.call(T.GetRecipeSchematic, id, false)
      for _, slot in ipairs(type(s) == "table" and s.reagentSlotSchematics or {}) do
        local rg = slot.reagents and slot.reagents[1]
        if rg and rg.itemID and slot.required ~= false then
          e.reagents[#e.reagents + 1] = { id = rg.itemID, need = slot.quantityRequired or 1 }
        end
      end
      list[#list + 1] = e
    end
  end
  return list
end
local function scanOld()
  local list, group = {}, nil
  for i = 1, U.call(GetNumTradeSkills) or 0 do
    local name, kind, n = U.call(GetTradeSkillInfo, i)
    if kind == "header" then
      group = name
    elseif name and DIFF[kind or ""] then
      local r = { name = name, d = DIFF[kind], n = U.num(n) or 0, group = group, idx = i, reagents = {},
        icon = U.call(GetTradeSkillIcon, i), link = U.call(GetTradeSkillItemLink, i), tool = (U.call(GetTradeSkillTools, i)) }
      for j = 1, U.call(GetTradeSkillNumReagents, i) or 0 do
        local rn, ri, need = U.call(GetTradeSkillReagentInfo, i, j)
        local id = itemId(U.call(GetTradeSkillReagentItemLink, i, j))
        if rn or id then r.reagents[#r.reagents + 1] = { name = rn, icon = ri, need = U.num(need) or 1, id = id } end
      end
      list[#list + 1] = r
    end
  end
  return list
end
local function scan()
  local prof, rank, max = U.call(G.tradeLine)
  if not prof then return end
  local list = scanNew()
  if not list or #list == 0 then list = scanOld() end
  if #list == 0 then return end
  local st, seen = store(), {}
  for _, r in ipairs(list) do seen[r.name] = true end
  -- filtr w oknie gry (np. „mam materialy”) chowa czesc przepisow: stare zostaja
  for _, r in ipairs(st[prof] and st[prof].list or {}) do
    if not seen[r.name] then r.idx = nil list[#list + 1] = r end
  end
  st[prof] = { at = time(), rank = U.num(rank), max = U.num(max), list = list }
  R.live = prof
  if R.page and R.page:IsVisible() then R.refresh() end
end

-- ---------- liczenie z torby ----------
local function have(id)
  if not id then return 0 end
  return U.num(U.call((C_Item and C_Item.GetItemCount) or GetItemCount, id)) or 0
end
local function canMake(r)
  if #r.reagents == 0 then return r.n or 0 end
  local m
  for _, g in ipairs(r.reagents) do
    if not g.id then return r.n or 0 end
    local k = math.floor(have(g.id) / math.max(1, g.need or 1))
    m = m and math.min(m, k) or k
  end
  return m or 0
end
local function itemName(g)
  return g.name or (g.id and U.call(C_Item and C_Item.GetItemNameByID, g.id)) or (g.id and ("#" .. g.id)) or "?"
end
local function itemIcon(g)
  return g.icon or (g.id and U.call(C_Item and C_Item.GetItemIconByID, g.id)) or 134400
end
local function isLive() return R.live ~= nil and R.live == R.ck end

-- ---------- akcje ----------
-- 14.11 (zrzut gracza: „tu dalej craftowania nie ma”): okno profesji otwiera tylko czar profesji, a ten rzuca jedynie
-- bezpieczny przycisk gry. Dlatego nad naszym przyciskiem „Otworz przepisy” lezy niewidoczny SecureActionButton
-- (rodzic UIParent, nie hub: hub musi sie dac schowac w walce). W walce chowa go sam sterownik stanu.
local SPELL = { Mining = "Smelting" }
local sec
local function secure()
  if sec or InCombatLockdown() then return sec end
  local ok = pcall(function()
    sec = CreateFrame("Button", "GrimuarHubProfButton", UIParent, "SecureActionButtonTemplate, SecureHandlerStateTemplate")
    sec:SetFrameStrata("DIALOG")
    sec:Hide()
    sec:SetAttribute("type", "spell")
    sec:RegisterForClicks("AnyUp", "AnyDown")
    sec:SetAttribute("_onstate-walka", [[ if newstate == "1" then self:Hide() end ]])
    RegisterStateDriver(sec, "walka", "[combat] 1; 0")
    sec:HookScript("OnEnter", function(self) local v = self.vis if v and v:GetScript("OnEnter") then v:GetScript("OnEnter")(v) end end)
    sec:HookScript("OnLeave", function(self) local v = self.vis if v and v:GetScript("OnLeave") then v:GetScript("OnLeave")(v) end end)
  end)
  if not ok then sec = nil end
  return sec
end
-- chowanie: takze odczepienie od huba. Chroniony przycisk przyczepiony do ramki huba czyni chronionym caly lancuch
-- kotwic az do huba, a wtedy gra nie pozwala go pokazac ani schowac w walce (hub dziala w walce od 14.11).
local function hideSecure()
  if sec and not InCombatLockdown() then
    sec:Hide()
    sec:ClearAllPoints()
    sec:SetPoint("TOPLEFT", UIParent, "TOPLEFT", -400, 400)
    sec.vis = nil
  end
end
local function placeSecure(vis, prof)
  if InCombatLockdown() then return end
  local s = secure()
  if not s then return end
  if not (vis and prof and vis:IsVisible()) then hideSecure() return end
  s:SetAttribute("spell", SPELL[prof] or prof)
  -- 14.11 (blad z gry: „Cannot anchor protected frames to regions”): chronionego przycisku nie wolno kotwiczyc do
  -- ramek huba, wiec stawiamy go w tym samym miejscu ekranu wzgledem UIParent (wspolrzedne przeliczone przez skale)
  local l, b, w, h = vis:GetLeft(), vis:GetBottom(), vis:GetWidth(), vis:GetHeight()
  if not (l and b and w and h and w > 0) then hideSecure() return end
  local k = (vis:GetEffectiveScale() or 1) / (UIParent:GetEffectiveScale() or 1)
  s:ClearAllPoints()
  s:SetPoint("BOTTOMLEFT", UIParent, "BOTTOMLEFT", l * k, b * k)
  s:SetSize(w * k, h * k)
  s.vis = vis
  s:Show()
end

local function openProf()
  if InCombatLockdown() then return end
  R.reopenUntil = GetTime() + 40
  U.OpenGame(function()
    if ToggleProfessionsBook then ToggleProfessionsBook()
    elseif BOOKTYPE_PROFESSION and ToggleSpellBook then ToggleSpellBook(BOOKTYPE_PROFESSION)
    elseif G.openSpellbook then G.openSpellbook()
    elseif ToggleSpellBook then ToggleSpellBook(BOOKTYPE_SPELL or "spell") end
  end)
  say("kliknij profesję w księdze: hub wróci sam na Rzemiosło.")
end
local function craft(r, n)
  if not r or InCombatLockdown() then return end
  if not isLive() then openProf() return end
  n = math.max(1, n or 1)
  local ok
  if r.id and C_TradeSkillUI and C_TradeSkillUI.CraftRecipe then
    ok = pcall(C_TradeSkillUI.CraftRecipe, r.id, n)
  elseif DoTradeSkill then
    local idx
    for i = 1, U.call(GetNumTradeSkills) or 0 do
      if (U.call(GetTradeSkillInfo, i)) == r.name then idx = i break end
    end
    if idx then ok = pcall(DoTradeSkill, idx, n) end
  end
  if ok then R.queue = { name = r.name, left = n, total = n }
  else say("gra nie pozwoliła utworzyć z huba: użyj okna profesji (Esc zamyka hub).") end
end

-- ---------- lewa kolumna: profesje ----------
local function profList()
  local known = U.call(G.readProfs) or {}
  local mine, todo = {}, {}
  for _, pr in ipairs(G.PROFS or {}) do
    local s = known[pr.name]
    if s then mine[#mine + 1] = { pr = pr, s = s } else todo[#todo + 1] = pr end
  end
  for _, name in ipairs(EXTRA) do
    local dup = false
    for _, m in ipairs(mine) do if m.pr.name == name then dup = true end end
    if known[name] and not dup then mine[#mine + 1] = { pr = { name = name }, s = known[name] } end
  end
  table.insert(mine, 1, { pr = { name = "_cele" }, s = { rank = 0, max = 0 }, special = true })
  return mine, todo
end
-- 14.11 (gracz: „pierwsza pomoc mam na 29 i nic sie nie zmienilo, nie dalo mi znac po 20”): opis liczony z biezacej
-- wartosci (G.profGoal w GrimuarSetup/Profesje.lua): zadanie „Camping 101”, ranga u trenera, przedzial i nastepny prog.
local function status(pr, s)
  local l = UnitLevel("player") or 1
  local nxt = pr.key and G.PROF_RANKS and G.PROF_RANKS[pr.key] and G.PROF_RANKS[pr.key][s.max]
  local g = G.profGoal and U.call(G.profGoal, pr.name)
  if g and g.quest then
    if g.quest.done then return "Zadanie „" .. g.quest.title .. "” gotowe: oddaj je", C.ok, nxt end
    if g.quest.target then return "Zadanie „" .. g.quest.title .. "”: do " .. g.quest.target .. " (masz " .. s.rank .. ")", C.gold, nxt end
  end
  if nxt then
    local rk = RANK_PL[nxt[1]] or nxt[1]
    if s.rank >= nxt[2] and l >= nxt[3] then return rk .. " dostępny — idź do trenera", C.ok, nxt end
    if s.rank >= nxt[2] then return rk .. ": umiejętność jest, brakuje poziomu " .. nxt[3], C.gold, nxt end
    if s.rank >= nxt[2] - 15 then return rk .. " od " .. nxt[2] .. " (jeszcze " .. (nxt[2] - s.rank) .. ")", C.muted, nxt end
  end
  if (s.max or 0) > 0 and s.rank >= s.max then return "Limit " .. s.max .. " — dalej tylko u trenera", C.danger, nxt end
  if g and g.now then
    return g.now .. ((g.next and g.next.at <= 300) and ("  ·  następny próg: " .. g.next.at) or ""), C.muted, nxt
  end
  local b = pr.key and U.call(G.profBand, pr.key, s.rank)
  if b then return b[4], C.muted, nxt end
  return "", C.muted, nxt
end
local function profRow(i)
  local r = R.profRows[i]
  if r then return r end
  r = CreateFrame("Button", nil, R.left)
  r:SetSize(L_W - 28, 66)
  r.sel = U.Rect(r, C.gold, 0.08)
  r.sel:SetAllPoints()
  U.Border(r, C.line)
  local hl = r:CreateTexture(nil, "HIGHLIGHT")
  hl:SetAllPoints()
  hl:SetColorTexture(1, 1, 1, 0.04)
  r.name = U.Text(r, 15, "title", C.text)
  r.name:SetPoint("TOPLEFT", 12, -10)
  r.val = U.Text(r, 13, "body", C.muted)
  r.val:SetPoint("TOPRIGHT", -12, -11)
  r.val:SetJustifyH("RIGHT")
  r.bar = U.Bar(r, 6, C.goldDim)
  r.bar:SetPoint("TOPLEFT", 12, -32)
  r.bar:SetPoint("TOPRIGHT", -12, -32)
  r.mark = r.bar:CreateTexture(nil, "OVERLAY", nil, 2)
  r.mark:SetColorTexture(C.gold[1], C.gold[2], C.gold[3], 1)
  r.mark:SetSize(2, 10)
  r.st = U.Text(r, 12, "body", C.muted)
  r.st:SetPoint("TOPLEFT", r.bar, "BOTTOMLEFT", 0, -7)
  r.st:SetWidth(L_W - 52)
  r:SetScript("OnClick", function(self)
    R.prof = self.prof
    R.count = 1
    R.refresh()
  end)
  r:SetScript("OnEnter", function(self)
    if not self.pr or self.pr.name == "_cele" then return end
    U.TT:SetOwner(self, "ANCHOR_RIGHT")
    U.TT:SetText(pl(self.pr.name) .. " " .. self.s.rank .. " / " .. self.s.max, C.gold[1], C.gold[2], C.gold[3])
    local b = self.pr.key and U.call(G.profBand, self.pr.key, self.s.rank)
    if b then
      U.TT:AddLine("Teraz: " .. b[4], 1, 1, 1, true)
      U.TT:AddLine("Gdzie: " .. b[5] .. " (poziom postaci " .. b[3] .. ")", 0.75, 0.75, 0.75, true)
    end
    if self.nxt then U.TT:AddLine("Trener: " .. self.nxt[4], 0.62, 0.73, 0.45, true) end
    if NOTE[self.pr.name] then U.TT:AddLine(NOTE[self.pr.name], 0.64, 0.61, 0.55, true) end
    U.TT:Show()
  end)
  r:SetScript("OnLeave", function() U.TT:Hide() end)
  R.profRows[i] = r
  return r
end

local function drawLeft(mine, todo)
  local prev
  for i, m in ipairs(mine) do
    local r = profRow(i)
    r.prof, r.pr, r.s = m.pr.name, m.pr, m.s
    r:ClearAllPoints()
    if prev then r:SetPoint("TOPLEFT", prev, "BOTTOMLEFT", 0, -8) else r:SetPoint("TOPLEFT", R.leftH, "BOTTOMLEFT", -4, -12) end
    r.name:SetText(pl(m.pr.name))
    r.val:SetText(m.special and "" or (m.s.rank .. " / " .. m.s.max))
    r.bar:SetShown(not m.special)
    r.bar:SetValue(m.s.max > 0 and m.s.rank / m.s.max or 0)
    local txt, col, nxt
    if m.special then
      local n = #(U.profTasks and U.profTasks() or {})
      txt, col = n > 0 and (n .. " " .. (n == 1 and "zadanie" or ((n % 10 >= 2 and n % 10 <= 4 and (n % 100 < 12 or n % 100 > 14)) and "zadania" or "zadań")) .. ": zbierz, zrób, sprzedaj") or "brak zadań", n > 0 and C.gold or C.muted
    else txt, col, nxt = status(m.pr, m.s) end
    r.nxt = nxt
    r.st:SetText(txt)
    U.Color(r.st, col)
    r.mark:ClearAllPoints()
    if nxt and m.s.max > 0 and nxt[2] < m.s.max then
      r.mark:SetPoint("CENTER", r.bar, "LEFT", (r.bar:GetWidth() or 0) * nxt[2] / m.s.max, 0)
      r.mark:Show()
    else
      r.mark:Hide()
    end
    local on = R.prof == m.pr.name
    r.sel:SetShown(on)
    U.BorderColor(r, on and C.goldDim or C.line)
    r:Show()
    prev = r
  end
  for i = #mine + 1, #R.profRows do R.profRows[i]:Hide() end
  R.todoL:ClearAllPoints()
  if prev then R.todoL:SetPoint("TOPLEFT", prev, "BOTTOMLEFT", 4, -20) else R.todoL:SetPoint("TOPLEFT", R.leftH, "BOTTOMLEFT", 0, -16) end
  R.todoL:SetShown(#todo > 0)
  local a = R.todoL
  for i = 1, math.max(#todo, #R.todo) do
    local t = R.todo[i]
    if not t then
      t = { name = U.Text(R.left, 13, "body", C.text), tag = U.Tag(R.left, "") }
      R.todo[i] = t
    end
    local pr = todo[i]
    t.name:SetShown(pr ~= nil)
    t.tag:SetShown(pr ~= nil)
    if pr then
      t.name:ClearAllPoints()
      t.name:SetPoint("TOPLEFT", a, "BOTTOMLEFT", 0, -8)
      t.name:SetText(pl(pr.name))
      t.tag:ClearAllPoints()
      t.tag:SetPoint("LEFT", t.name, "LEFT", 170, 0)
      t.tag:SetTag(TODO_NOTE[pr.name] or "opcja")
      a = t.name
    end
  end
end

-- ---------- srodek: przepisy ----------
local function head(i)
  local h = R.heads[i]
  if h then return h end
  h = CreateFrame("Frame", nil, R.list)
  h:SetHeight(24)
  h.text = U.Text(h, 12, "title", C.goldDim)
  h.text:SetPoint("LEFT", 0, 0)
  h.text:SetJustifyV("MIDDLE")
  h.line = U.Line(h, C.line)
  h.line:SetPoint("LEFT", h.text, "RIGHT", 10, 0)
  h.line:SetPoint("RIGHT", 0, 0)
  R.heads[i] = h
  return h
end
local function row(i)
  local r = R.rows[i]
  if r then return r end
  r = CreateFrame("Button", nil, R.list)
  r:SetHeight(28)
  r.sel = U.Rect(r, C.gold, 0.1)
  r.sel:SetAllPoints()
  local hl = r:CreateTexture(nil, "HIGHLIGHT")
  hl:SetAllPoints()
  hl:SetColorTexture(1, 1, 1, 0.04)
  r.dot = U.Diamond(r, 14, DCOL[0], true)
  r.dot:SetPoint("LEFT", 6, 0)
  r.name = U.Text(r, 14, "body", C.text)
  r.name:SetPoint("LEFT", 28, 0)
  r.name:SetPoint("RIGHT", -80, 0)
  r.name:SetJustifyV("MIDDLE")
  r.n = U.Text(r, 13, "body", C.text)
  r.n:SetPoint("RIGHT", -8, 0)
  r.n:SetJustifyH("RIGHT")
  r.n:SetJustifyV("MIDDLE")
  r:SetScript("OnClick", function(self)
    if not self.r then return end
    if IsModifiedClick and IsModifiedClick("CHATLINK") and self.r.link then U.call(ChatEdit_InsertLink, self.r.link) return end
    R.sel[R.ck] = self.r.name
    R.count = 1
    R.refresh()
  end)
  R.rows[i] = r
  return r
end

local function drawList(rec, again)
  local list = rec and rec.list or {}
  local groups, order = {}, {}
  for _, r in ipairs(list) do
    r.can = canMake(r)
    if R.filter == "all" or r.goal or r.mat or (r.gather and r.d <= 2) or (not r.gather and r.can > 0) then
      local g = r.group or "Przepisy"
      if not groups[g] then groups[g] = {} order[#order + 1] = g end
      table.insert(groups[g], r)
    end
  end
  local w = R.view:GetWidth() or 400
  R.list:SetWidth(w)
  local y, ri, hi, selR = 0, 0, 0, nil
  for _, g in ipairs(order) do
    if #order > 1 or g ~= "Przepisy" then
      hi = hi + 1
      local h = head(hi)
      h:ClearAllPoints()
      h:SetPoint("TOPLEFT", R.list, "TOPLEFT", 0, -y)
      h:SetPoint("TOPRIGHT", R.list, "TOPRIGHT", 0, -y)
      h.text:SetText(g)
      h:Show()
      y = y + 28
    end
    for _, r in ipairs(groups[g]) do
      ri = ri + 1
      local b = row(ri)
      b.r = r
      b:ClearAllPoints()
      b:SetPoint("TOPLEFT", R.list, "TOPLEFT", 0, -y)
      b:SetPoint("TOPRIGHT", R.list, "TOPRIGHT", 0, -y)
      b.dot:Set(DCOL[r.d] or DCOL[3], true)
      b.name:SetText(r.name)
      U.Color(b.name, r.can > 0 and C.text or C.muted)
      if r.goal then b.n:SetText(r.tag or "")
      elseif r.mat then b.n:SetText(r.label .. "  × " .. (r.count or 0))
      else b.n:SetText(r.gather and ("masz " .. r.can) or (r.can > 0 and ("× " .. r.can) or "brak")) end
      U.Color(b.n, r.can > 0 and C.text or C.faint)
      local on = R.sel[R.ck] == r.name
      if on then selR = r end
      b.sel:SetShown(on)
      b:Show()
      y = y + 30
    end
  end
  for i = ri + 1, #R.rows do R.rows[i]:Hide() end
  for i = hi + 1, #R.heads do R.heads[i]:Hide() end
  R.list:SetHeight(math.max(10, y))
  if not selR and list[1] and not again then
    -- domyslnie: najlepszy przepis z punktem, na ktory masz materialy
    for _, r in ipairs(list) do
      if r.can > 0 and r.d <= 1 and (not selR or r.d < selR.d) then selR = r end
    end
    selR = selR or list[1]
    R.sel[R.ck] = selR.name
    return drawList(rec, true)
  end
  return selR
end

-- ---------- prawo: szczegoly ----------
local function reagRow(i)
  local g = R.reag[i]
  if g then return g end
  g = CreateFrame("Frame", nil, R.right)
  g:SetSize(R_W - 36, 34)
  g.slot = U.Slot(g, 32)
  g.slot:SetPoint("LEFT", 0, 0)
  g.name = U.Text(g, 13, "body", C.text)
  g.name:SetPoint("LEFT", g.slot, "RIGHT", 10, 0)
  g.name:SetPoint("RIGHT", g, "RIGHT", -96, 0)
  g.name:SetJustifyV("MIDDLE")
  g.n = U.Text(g, 13, "body", C.text)
  g.n:SetPoint("RIGHT", 0, 0)
  g.n:SetJustifyH("RIGHT")
  g.n:SetJustifyV("MIDDLE")
  g.slot:SetScript("OnEnter", function(self)
    if not self.id then return end
    U.TT:SetOwner(self, "ANCHOR_LEFT")
    if not pcall(U.TT.SetItemByID, U.TT, self.id) then U.TT:SetText(self.nm or "") end
    U.TT:Show()
  end)
  g.slot:SetScript("OnLeave", function() U.TT:Hide() end)
  R.reag[i] = g
  return g
end

local function drawDetail(r)
  R.detail:SetShown(r ~= nil)
  R.empty:SetShown(r == nil)
  if not r then return end
  R.icon.icon:SetTexture(r.icon or 134400)
  R.icon.link = r.link
  R.dName:SetText(r.name)
  local dc = DCOL[r.d] or DCOL[3]
  R.dSub:SetText(U.hex(dc) .. (DTXT[r.d] or "") .. "|r" .. (r.tool and (" · potrzebne: " .. r.tool) or "") ..
    (r.gather and (" · od " .. r.req) or ""))
  local craftOnly = { R.ileL, R.minus, R.box, R.plus, R.maxB, R.maxT, R.make, R.makeOne, R.openBtn }
  if r.goal or r.mat then
    R.dSub:SetText(r.mat and (U.hex(dc) .. (r.label or "") .. "|r · masz " .. (r.count or 0)) or (r.sub or ""))
    R.reagL:SetText(r.goal and "Cele zadania" or "Co z tym zrobić")
    for _, g in ipairs(R.reag) do g:Hide() end
    for _, w in ipairs(craftOnly) do w:Hide() end
    R.gWhere:SetText(r.text or "")
    R.gWhere:Show()
    R.liveNote:ClearAllPoints()
    R.liveNote:SetPoint("TOPLEFT", R.gWhere, "BOTTOMLEFT", 0, -16)
    R.liveNote:SetText(r.mat and "Dom aukcyjny: Ironforge, The Commons. Kupca najszybciej znajdziesz przyciskiem „Do kupca” na pasku Grimuara."
      or "To samo zadanie jest w Dzienniku (J), z przyciskiem Prowadź do aukcjonera, kupca albo trenera.")
    return
  end
  if r.gather then
    R.reagL:SetText("Gdzie")
    for _, g in ipairs(R.reag) do g:Hide() end
    for _, w in ipairs(craftOnly) do w:Hide() end
    R.gWhere:SetText((r.zones or "") .. (r.potion and ("\n\nMikstura: " .. r.potion) or "") .. "\n\nMasz w torbach: " .. (r.can or 0))
    R.gWhere:Show()
    R.liveNote:ClearAllPoints()
    R.liveNote:SetPoint("TOPLEFT", R.gWhere, "BOTTOMLEFT", 0, -16)
    R.liveNote:SetText("Zbierasz prawym klikiem. Miejsca pokazuje GatherMate2 na mapie gry, a kropki na minimapie włącza przycisk śledzenia pod listą.")
    return
  end
  R.reagL:SetText("Składniki")
  R.gWhere:Hide()
  for _, w in ipairs({ R.ileL, R.minus, R.box, R.plus, R.maxB, R.maxT }) do w:Show() end
  R.liveNote:ClearAllPoints()
  R.liveNote:SetPoint("TOPLEFT", R.make, "BOTTOMLEFT", 0, -12)
  local prev = R.reagL
  for i, g in ipairs(r.reagents) do
    local row2 = reagRow(i)
    row2:ClearAllPoints()
    row2:SetPoint("TOPLEFT", prev, "BOTTOMLEFT", 0, i == 1 and -8 or -6)
    local nm, n = itemName(g), have(g.id)
    row2.slot.icon:SetTexture(itemIcon(g))
    row2.slot.id, row2.slot.nm = g.id, nm
    row2.name:SetText(nm)
    row2.n:SetText((g.need or 1) .. " / masz " .. (g.id and n or "?"))
    U.Color(row2.n, (g.id and n < (g.need or 1)) and C.danger or C.text)
    row2:Show()
    prev = row2
  end
  for i = #r.reagents + 1, #R.reag do R.reag[i]:Hide() end
  R.ileL:ClearAllPoints()
  R.ileL:SetPoint("TOPLEFT", prev, "BOTTOMLEFT", 0, -18)
  local max = r.can or 0
  if R.count > math.max(1, max) then R.count = math.max(1, max) end
  R.cnt:SetText(tostring(R.count))
  R.maxT:SetText(max > 0 and ("maks. " .. max .. " z tego, co masz") or "brak materiałów")
  local live = isLive()
  R.make:SetShown(live)
  R.makeOne:SetShown(live)
  R.openBtn:SetShown(not live)
  R.make:SetLabel("Utwórz " .. R.count)
  R.make:SetAlpha(max > 0 and 1 or 0.5)
  R.makeOne:SetAlpha(max > 0 and 1 or 0.5)
  R.liveNote:SetText(live and "Postęp pokazuje pasek poniżej. Ruch przerywa tworzenie."
    or "Gra tworzy tylko przy otwartym oknie tej profesji. Przycisk je otworzy (okno zostaje pod hubem), potem Utwórz.")
end

local function refresh()
  if not R.page then return end
  local mine, todo = profList()
  if not R.prof then
    R.prof = (R.live and (R.live == "Smelting" and "Mining" or R.live)) or nil
    if not R.prof then
      for _, m in ipairs(mine) do if store()[cacheKey(m.pr.name)] and not R.prof then R.prof = m.pr.name end end
    end
    if not R.prof then
      for _, m in ipairs(mine) do if not m.special and not GATHER[m.pr.name] and not R.prof then R.prof = m.pr.name end end
    end
    R.prof = R.prof or (mine[2] and mine[2].pr.name) or "_cele"
  end
  drawLeft(mine, todo)
  R.ck = R.prof and cacheKey(R.prof)
  local rec = R.ck and (store()[R.ck] or store()[R.prof])
  if rec and not store()[R.ck] then R.ck = R.prof end
  if R.prof == "_cele" then
    rec, R.ck = { list = {}, cele = true, at = time() }, "_cele"
    -- 14.11 (gracz: „profesje jak aktywne questy: zbierz tyle, scraftuj tyle, sprzedaj tu i tam”): RzemiosloZadania.lua
    local DC = { craft = 0, smelt = 0, gather = 1, trainer = 5, sell = 2 }
    for _, tk in ipairs(U.profTasks and U.profTasks() or {}) do
      rec.list[#rec.list + 1] = { name = tk.title, goal = true, task = tk, group = tk.group, d = DC[tk.kind] or 3, n = 1,
        reagents = {}, tag = tk.tag, sub = (tk.profPl or "") .. (tk.tag and (" · " .. tk.tag) or ""), text = U.profTaskText(tk) }
    end
    for _, it in ipairs(U.bagMaterials and U.bagMaterials() or {}) do
      local v = U.MAT_VERDICT[it.verdict] or { it.verdict, 3 }
      rec.list[#rec.list + 1] = { name = it.name, mat = true, group = "Surowce w torbach: ocena", d = v[2], label = v[1], n = it.count,
        reagents = {}, icon = it.icon, link = "item:" .. it.id, text = it.text, count = it.count }
    end
  end
  if not rec and R.prof and U.gatherRec and U.GATHER_DATA and U.GATHER_DATA[R.prof] then
    local sk = (U.call(G.readProfs) or {})[R.prof]
    rec = U.gatherRec(R.prof, sk and sk.rank or 0)
    R.ck = "zb:" .. R.prof
  end
  R.mTitle:SetText(R.prof and pl(R.prof) or "Rzemiosło")
  local s = R.prof and (U.call(G.readProfs) or {})[R.prof]
  R.mRank:SetText(s and (s.rank .. " / " .. s.max) or "")
  local live = isLive()
  if rec and rec.cele then
    R.mState:SetText("Zadania jak questy: postęp liczy się sam; niżej ocena każdego surowca w torbach")
  elseif rec and rec.gather then
    R.mState:SetText("Zbieractwo: kolor mówi, czy dostaniesz punkt; „masz” = w torbach")
  elseif rec then
    R.mState:SetText(live and (U.hex(C.ok) .. "Okno profesji otwarte: tworzysz stąd|r")
      or ("Przepisy z " .. date("%d.%m, %H:%M", rec.at or time()) .. " · świeże po otwarciu okna profesji"))
  else
    R.mState:SetText("")
  end
  local sel
  if rec and #rec.list > 0 then
    R.view:Show()
    R.mEmpty:Hide()
    R.mOpen:Hide()
    sel = drawList(rec)
  else
    R.view:Hide()
    R.mEmpty:Show()
    local gather = R.prof and GATHER[R.prof]
    local key
    for _, pr in ipairs(G.PROFS or {}) do if pr.name == R.prof then key = pr.key end end
    local b = key and s and U.call(G.profBand, key, s.rank)
    if not R.prof then
      R.mEmpty:SetText("Nie masz jeszcze profesji. Plan Grimuara: Zielarstwo i Pierwsza pomoc od startu, Górnictwo w planie.")
    elseif gather and R.prof ~= "Mining" then
      R.mEmpty:SetText("Zbieractwo: punkty dostajesz za zbieranie po drodze." .. (b and ("\n\nTeraz: " .. b[4] .. "\nGdzie: " .. b[5]) or ""))
    else
      R.mEmpty:SetText("Kliknij „Otwórz przepisy”: gra otworzy okno tej profesji pod hubem, a przepisy pokażą się tutaj." .. (b and ("\n\nTeraz: " .. b[4]) or ""))
    end
    R.mOpen:SetShown(R.prof ~= nil and not (gather and R.prof ~= "Mining"))
  end
  -- 15.11: poradnik profesji z Polestara zamiast listy przepisow
  if R.filter == "ps" and R.psP and U.psProfDraw then
    R.view:Hide() R.mEmpty:Hide() R.mOpen:Hide()
    R.psP:Show()
    R.mState:SetText("Poradnik Polestara dla Twojego poziomu: klik w kartę z trenerem albo miejscem prowadzi")
    local ok, err = pcall(U.psProfDraw, R.psP, R.prof)
    if not ok then R.psP:Hide() R.mEmpty:Show() R.mEmpty:SetText("Poradnik Polestara: błąd " .. tostring(err)) end
  elseif R.psP then
    R.psP:Hide()
  end
  local hint = R.prof and (U.call(G.kraftShort, R.prof) or (R.prof == "Mining" and U.call(G.kraftShort, "Smelting")))
  R.hint:SetText("Grimuar: " .. (hint or NOTE[R.prof or ""] or "kolor przepisu mówi, czy da punkt umiejętności."))
  local gb = R.prof ~= nil and GATHER[R.prof] == true and G.toggleGather ~= nil
  R.gatherBtn:SetShown(gb)
  R.view:SetPoint("BOTTOMRIGHT", R.mid, "BOTTOMRIGHT", -16, gb and 108 or 64)
  R.empty:SetText(rec and "Wybierz przepis z listy." or "Tu pokażą się składniki i tworzenie, gdy wybierzesz przepis.")
  drawDetail(sel)
  local label = "Otwórz przepisy: " .. pl(R.prof or "")
  R.mOpen:SetLabel(label)
  R.openBtn:SetLabel(label)
  if R.mOpen:IsShown() then placeSecure(R.mOpen, R.prof)
  elseif R.openBtn:IsShown() and R.detail:IsShown() then placeSecure(R.openBtn, R.prof)
  else hideSecure() end
end
R.refresh = refresh

-- ---------- uklad ----------
local function toggle(parent, text, w)
  local b = CreateFrame("Button", nil, parent)
  b:SetSize(w, 22)
  b.t = U.Text(b, 12, "title", C.muted)
  b.t:SetPoint("CENTER", 0, 1)
  b.t:SetJustifyH("CENTER")
  b.t:SetText(text)
  b.u = U.Line(b, C.gold)
  b.u:SetPoint("BOTTOMLEFT", 8, 0) b.u:SetPoint("BOTTOMRIGHT", -8, 0)
  return b
end

local function build(page)
  R.page = page
  -- lewo
  local L = U.Panel(page, 0.86, true)
  L:SetPoint("TOPLEFT") L:SetPoint("BOTTOMLEFT") L:SetWidth(L_W)
  R.left = L
  R.leftH = U.H2(L, "Profesje")
  R.leftH:SetPoint("TOPLEFT", 18, -16)
  R.todoL = U.Label(L, "Do nauki")
  local legend = CreateFrame("Frame", nil, L)
  legend:SetPoint("BOTTOMLEFT", 18, 14)
  legend:SetSize(L_W - 36, 40)
  for d = 0, 3 do
    local dm = U.Diamond(legend, 12, DCOL[d], true)
    dm:SetPoint("TOPLEFT", (d % 2) * 150, -math.floor(d / 2) * 20)
    local t = U.Text(legend, 11, "body", C.faint)
    t:SetPoint("LEFT", dm, "RIGHT", 6, 0)
    t:SetText(d == 3 and "bez punktu albo za wcześnie" or DTXT[d])
  end

  -- prawo
  local P = U.Panel(page, 0.86, true)
  P:SetPoint("TOPRIGHT") P:SetPoint("BOTTOMRIGHT") P:SetWidth(R_W)
  R.right = P
  local w = R_W - 36
  R.empty = U.Para(P, 13, w, C.muted)
  R.empty:SetPoint("TOPLEFT", 18, -20)
  R.empty:SetText("Wybierz przepis z listy.")
  R.detail = CreateFrame("Frame", nil, P)
  R.detail:SetAllPoints()
  R.icon = U.Slot(P, 52)
  R.icon:SetPoint("TOPLEFT", 18, -20)
  R.icon:SetScript("OnEnter", function(self)
    if not self.link then return end
    U.TT:SetOwner(self, "ANCHOR_LEFT")
    if pcall(U.TT.SetHyperlink, U.TT, self.link) then U.TT:Show() end
  end)
  R.icon:SetScript("OnLeave", function() U.TT:Hide() end)
  R.icon:SetParent(R.detail)
  R.dName = U.Para(R.detail, 18, w - 66, C.gold, "title")
  R.dName:SetPoint("TOPLEFT", R.icon, "TOPRIGHT", 12, -2)
  R.dSub = U.Text(R.detail, 12, "body", C.muted)
  R.dSub:SetPoint("TOPLEFT", R.dName, "BOTTOMLEFT", 0, -6)
  R.dSub:SetWidth(w - 66)
  R.reagL = U.Label(R.detail, "Składniki")
  R.reagL:SetPoint("TOPLEFT", R.icon, "BOTTOMLEFT", 0, -22)
  R.right = R.detail
  R.ileL = U.Label(R.detail, "Ile")
  R.gWhere = U.Para(R.detail, 13, R_W - 36, C.text)
  R.gWhere:SetPoint("TOPLEFT", R.reagL, "BOTTOMLEFT", 0, -8)
  R.gWhere:Hide()
  local minus = U.Button(R.detail, "-", 34, 30)
  R.minus = minus
  minus:SetPoint("TOPLEFT", R.ileL, "BOTTOMLEFT", 0, -8)
  local box = U.Panel(R.detail, 0.9, false, C.edge)
  R.box = box
  box:SetSize(56, 30)
  box:SetPoint("LEFT", minus, "RIGHT", -1, 0)
  R.cnt = U.Text(box, 16, "body", C.text)
  R.cnt:SetPoint("CENTER", 0, 0)
  R.cnt:SetJustifyH("CENTER")
  local plus = U.Button(R.detail, "+", 34, 30)
  R.plus = plus
  plus:SetPoint("LEFT", box, "RIGHT", -1, 0)
  -- 14.11 (gracz: „tu powinien byc przycisk max”)
  local maxB = U.Button(R.detail, "Max", 54, 30)
  maxB:SetPoint("LEFT", plus, "RIGHT", 6, 0)
  R.maxB = maxB
  R.maxT = U.Text(R.detail, 12, "body", C.muted)
  R.maxT:SetPoint("LEFT", maxB, "RIGHT", 10, 0)
  local function step(d)
    local r
    for _, b in ipairs(R.rows) do if b:IsShown() and b.r and R.sel[R.ck] == b.r.name then r = b.r end end
    local max = math.max(1, r and r.can or 1)
    R.count = math.max(1, math.min(max, R.count + d))
    R.refresh()
  end
  minus:SetScript("OnClick", function() step(IsShiftKeyDown() and -5 or -1) end)
  maxB:SetScript("OnClick", function() step(9999) end)
  plus:SetScript("OnClick", function() step(IsShiftKeyDown() and 5 or 1) end)
  local function selected()
    for _, b in ipairs(R.rows) do if b:IsShown() and b.r and R.sel[R.ck] == b.r.name then return b.r end end
  end
  R.selected = selected
  R.make = U.Button(R.detail, "Utwórz", nil, 32, true)
  R.make:SetPoint("TOPLEFT", minus, "BOTTOMLEFT", 0, -18)
  R.make:SetScript("OnClick", function() craft(selected(), R.count) end)
  R.makeOne = U.Button(R.detail, "Utwórz jeden", nil, 32)
  R.makeOne:SetPoint("LEFT", R.make, "RIGHT", 10, 0)
  R.makeOne:SetScript("OnClick", function() craft(selected(), 1) end)
  R.openBtn = U.Button(R.detail, "Otwórz okno profesji", nil, 32, true)
  R.openBtn:SetPoint("TOPLEFT", minus, "BOTTOMLEFT", 0, -18)
  R.openBtn:SetScript("OnClick", openProf)
  R.liveNote = U.Para(R.detail, 12, w, C.faint)
  R.liveNote:SetPoint("TOPLEFT", R.make, "BOTTOMLEFT", 0, -12)
  R.castBar = U.Bar(R.detail, 8, C.gold)
  R.castBar:SetPoint("BOTTOMLEFT", P, "BOTTOMLEFT", 18, 40)
  R.castBar:SetWidth(w)
  R.castBar:Hide()
  R.castText = U.Text(R.detail, 12, "body", C.text)
  R.castText:SetPoint("BOTTOMLEFT", R.castBar, "TOPLEFT", 0, 6)
  R.castBar:SetScript("OnUpdate", function(self)
    local ok, _, _, _, st, en = pcall(UnitCastingInfo, "player")
    if not ok then return end
    st, en = U.num(st), U.num(en)
    if st and en and en > st then self:SetValue((GetTime() * 1000 - st) / (en - st)) end
  end)

  -- srodek
  local M = U.Panel(page, 0.86, true)
  M:SetPoint("TOPLEFT", L, "TOPRIGHT", 20, 0)
  M:SetPoint("BOTTOMRIGHT", P, "BOTTOMLEFT", -20, 0)
  R.mTitle = U.H2(M, "Rzemiosło")
  R.mTitle:SetPoint("TOPLEFT", 18, -16)
  R.mRank = U.Text(M, 13, "body", C.muted)
  R.mRank:SetPoint("LEFT", R.mTitle, "RIGHT", 10, 0)
  local fAll = toggle(M, "Wszystkie", 84)
  fAll:SetPoint("TOPRIGHT", M, "TOPRIGHT", -14, -13)
  local fCan = toggle(M, "Mogę zrobić", 96)
  fCan:SetPoint("RIGHT", fAll, "LEFT", -2, 0)
  local fPs = toggle(M, "Poradnik Polestara", 140)
  fPs:SetPoint("RIGHT", fCan, "LEFT", -2, 0)
  local function paintF()
    U.Color(fAll.t, R.filter == "all" and C.gold or C.muted) fAll.u:SetShown(R.filter == "all")
    U.Color(fCan.t, R.filter == "can" and C.gold or C.muted) fCan.u:SetShown(R.filter == "can")
    U.Color(fPs.t, R.filter == "ps" and C.gold or C.muted) fPs.u:SetShown(R.filter == "ps")
  end
  fPs:SetScript("OnClick", function() R.filter = "ps" paintF() R.refresh() end)
  fAll:SetScript("OnClick", function() R.filter = "all" paintF() R.view:SetVerticalScroll(0) R.refresh() end)
  fCan:SetScript("OnClick", function() R.filter = "can" paintF() R.view:SetVerticalScroll(0) R.refresh() end)
  paintF()
  R.mState = U.Text(M, 12, "body", C.faint)
  R.mState:SetPoint("TOPLEFT", R.mTitle, "BOTTOMLEFT", 0, -6)
  R.hint = U.Para(M, 13, 400, C.muted)
  R.hint:SetPoint("BOTTOMLEFT", M, "BOTTOMLEFT", 18, 16)
  R.hint:SetPoint("BOTTOMRIGHT", M, "BOTTOMRIGHT", -18, 16)
  R.gatherBtn = U.Button(M, "Śledzenie ziół i rudy", nil, 30)
  R.gatherBtn:SetPoint("BOTTOMLEFT", R.hint, "TOPLEFT", 0, 12)
  R.gatherBtn:SetScript("OnClick", function() U.call(G.toggleGather) end)
  local view = CreateFrame("ScrollFrame", nil, M)
  view:SetPoint("TOPLEFT", R.mState, "BOTTOMLEFT", 0, -14)
  view:SetPoint("BOTTOMRIGHT", M, "BOTTOMRIGHT", -16, 64)
  local list = CreateFrame("Frame", nil, view)
  list:SetSize(400, 10)
  view:SetScrollChild(list)
  view:EnableMouseWheel(true)
  view:SetScript("OnMouseWheel", function(self, d)
    local max = math.max(0, list:GetHeight() - self:GetHeight())
    self:SetVerticalScroll(math.max(0, math.min(max, self:GetVerticalScroll() - d * 60)))
  end)
  R.view, R.list, R.mid = view, list, M
  R.psP = U.Blocks(M)
  R.psP:SetPoint("TOPLEFT", view, "TOPLEFT", -18, 6)
  R.psP:SetPoint("BOTTOMRIGHT", view, "BOTTOMRIGHT", 14, -6)
  R.psP.bg:Hide()
  R.psP:Hide()
  R.mEmpty = U.Para(M, 14, 420, C.muted)
  R.mEmpty:SetPoint("TOPLEFT", R.mState, "BOTTOMLEFT", 0, -20)
  R.mOpen = U.Button(M, "Otwórz okno profesji", nil, 30, true)
  R.mOpen:SetPoint("TOPLEFT", R.mEmpty, "BOTTOMLEFT", 0, -16)
  R.mOpen:SetScript("OnClick", openProf)
end

-- ---------- zdarzenia ----------
-- zawsze: zapis przepisow z okna profesji i powrot huba po otwarciu profesji z huba
local scanEv = CreateFrame("Frame")
for _, e in ipairs({ "TRADE_SKILL_SHOW", "TRADE_SKILL_LIST_UPDATE", "TRADE_SKILL_UPDATE", "TRADE_SKILL_DATA_SOURCE_CHANGED",
  "TRADE_SKILL_CLOSE" }) do pcall(scanEv.RegisterEvent, scanEv, e) end
scanEv:SetScript("OnEvent", function(_, event)
  if event == "TRADE_SKILL_CLOSE" then
    R.live = nil
    if R.page and R.page:IsVisible() then R.refresh() end
    return
  end
  if event == "TRADE_SKILL_SHOW" and R.reopenUntil and GetTime() < R.reopenUntil then
    R.reopenUntil = nil
    C_Timer.After(0.7, function() if not InCombatLockdown() then U.Open("rzemioslo") end end)
  end
  if R.scanPending then return end
  R.scanPending = true
  C_Timer.After(0.5, function() R.scanPending = false pcall(scan) end)
end)

-- tylko przy otwartej zakladce: torba, poziomy, pasek tworzenia
local ev = CreateFrame("Frame")
local EVENTS = { "BAG_UPDATE_DELAYED", "SKILL_LINES_CHANGED", "UNIT_SPELLCAST_START", "UNIT_SPELLCAST_STOP",
  "UNIT_SPELLCAST_SUCCEEDED", "UNIT_SPELLCAST_INTERRUPTED", "UNIT_SPELLCAST_FAILED" }
ev:SetScript("OnEvent", function(_, event, unit)
  if event:find("^UNIT_SPELLCAST") then
    if unit ~= "player" or not R.queue then return end
    if event == "UNIT_SPELLCAST_START" then
      R.castBar:Show()
      R.castText:SetText("Tworzę: " .. R.queue.name .. " (" .. (R.queue.total - R.queue.left + 1) .. " z " .. R.queue.total .. ")")
      R.castText:Show()
      return
    elseif event == "UNIT_SPELLCAST_STOP" then
      return -- STOP po kazdym rzuceniu, takze udanym: kolejke konczy SUCCEEDED (ostatnia sztuka) albo przerwanie
    elseif event == "UNIT_SPELLCAST_SUCCEEDED" then
      R.queue.left = R.queue.left - 1
      if R.queue.left > 0 then return end
    end
    R.queue = nil
    R.castBar:Hide()
    R.castText:Hide()
    return
  end
  if R.pending then return end
  R.pending = true
  C_Timer.After(0.3, function()
    R.pending = false
    if R.page and R.page:IsVisible() then pcall(refresh) end
  end)
end)

U.RegisterTab({
  id = "rzemioslo", order = 5, title = "Rzemiosło", keys = "K",
  hints = { { { "Enter" }, "Utwórz" }, { { "Shift", "LPM" }, "Przepis do czatu" } },
  note = "Tworzenie działa przy otwartym oknie profesji",
  build = build,
  refresh = function()
    for _, e in ipairs(EVENTS) do pcall(ev.RegisterEvent, ev, e) end
    refresh()
    C_Timer.After(0, function() if R.page and R.page:IsVisible() then pcall(refresh) end end)
  end,
  leave = function()
    ev:UnregisterAllEvents()
    hideSecure()
    R.queue = nil
    if R.castBar then R.castBar:Hide() R.castText:Hide() end
  end,
  combat = function(on) if on then hideSecure() else pcall(refresh) end end,
  onKey = function(key)
    if (key == "ENTER" or key == "NUMPADENTER") and isLive() and R.selected then
      local r = R.selected()
      if r and (r.can or 0) > 0 then craft(r, R.count) return true end
    end
  end,
})

-- z Dziennika: Rzemioslo na „Zadaniach profesji”, z zaznaczonym zadaniem
function U.profTasksShow(title)
  R.prof = "_cele"
  R.sel["_cele"] = title
  U.Select("rzemioslo")
end
