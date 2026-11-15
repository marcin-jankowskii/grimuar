-- Grimuar UI: zakladka Osiagniecia (makieta 14.11 „Hub · Osiagniecia”, krok D).
-- Lewo: kategorie z postepem (podkategorie pod wybrana). Srodek: osiagniecia kategorii z paskiem i punktami, filtr
-- Niezdobyte / Wszystkie. Prawo: punkty, szczegoly wybranego (czego brakuje), ostatnio zdobyte i te, ktorym brakuje niewiele.
-- Forever ma osiagniecia pod spodem (Legacy Challenges, Polestar Compat.GetAchievement): GetAchievementInfo i kryteria.
-- Gdy gra nie poda kategorii, zakladka mowi to spokojnie i daje przycisk okna gry. Shift+LPM: sledzenie.
local ADDON, U = ...
local G, C = U.G, U.C
local say = U.say

local A = { filter = "todo", catRows = {}, rows = {}, recRows = {}, nearRows = {}, open = {} }
local L_W, R_W, ROW_H = 300, 330, 60
local CAT_PL = { General = "Ogólne", Quests = "Zadania", Exploration = "Odkrywanie", ["Player vs. Player"] = "PvP",
  ["Dungeons & Raids"] = "Lochy i rajdy", Professions = "Profesje", Reputation = "Reputacje", ["World Events"] = "Wydarzenia",
  ["Feats of Strength"] = "Wyczyny", Legacy = "Dziedzictwo", Character = "Postać", Collections = "Kolekcje" }

local function str(v)
  if type(v) ~= "string" or v == "" then return nil end
  if issecretvalue and issecretvalue(v) then return nil end
  return v
end
local function hasApi()
  return GetCategoryList and GetCategoryInfo and GetCategoryNumAchievements and GetAchievementInfo and true or false
end

-- ---------- dane ----------
local function achInfo(id)
  local ok, aid, name, points, completed, month, day, year, desc, _, icon, reward, isGuild, mine = pcall(GetAchievementInfo, id)
  if not ok or not aid or not str(name) then return nil end
  if mine ~= nil then completed = completed and mine end
  return { id = aid, name = name, points = U.num(points) or 0, done = completed and true or false, m = U.num(month),
    d = U.num(day), y = U.num(year), desc = str(desc), icon = icon, reward = str(reward), guild = isGuild and true or false }
end

-- postep: jedno kryterium z liczba (np. 23 / 50) albo ile kryteriow spelnionych; lista brakujacych nazw
local function progress(a)
  if a.prog then return a.prog end
  local n = U.num(U.call(GetAchievementNumCriteria, a.id)) or 0
  local cur, max, missing = 0, 0, {}
  if n == 1 then
    local ok, text, _, comp, q, req = pcall(GetAchievementCriteriaInfo, a.id, 1)
    q, req = ok and U.num(q) or nil, ok and U.num(req) or nil
    if req and req > 1 then cur, max = math.min(q or 0, req), req
    else
      cur, max = (ok and comp) and 1 or 0, 1
      if not (ok and comp) and str(text) then missing[1] = text end
    end
  elseif n > 1 then
    for i = 1, n do
      local ok, text, _, comp = pcall(GetAchievementCriteriaInfo, a.id, i)
      if ok and comp then cur = cur + 1 elseif ok and str(text) then missing[#missing + 1] = text end
    end
    max = n
  end
  if a.done then cur, max, missing = math.max(max, 1), math.max(max, 1), {} end
  a.cur, a.max, a.missing = cur, max, missing
  a.prog = max > 0 and cur / max or (a.done and 1 or 0)
  return a.prog
end

local function catAchievements(cat)
  local out = {}
  local ok, n = pcall(GetCategoryNumAchievements, cat, true)
  n = ok and U.num(n) or 0
  for i = 1, n do
    local ok2, aid = pcall(GetAchievementInfo, cat, i)
    local a = ok2 and aid and achInfo(aid)
    if a and not a.guild then
      a.cat = cat
      out[#out + 1] = a
    end
  end
  return out
end
local function catCount(cat)
  local ok, total, done = pcall(GetCategoryNumAchievements, cat, true)
  return ok and U.num(total) or 0, ok and U.num(done) or 0
end

-- drzewo kategorii: gorne (rodzic -1) i ich podkategorie, z licznikami
local function readCats()
  local list = U.call(GetCategoryList)
  if type(list) ~= "table" or #list == 0 then return nil end
  local byId, tops, kids, skip = {}, {}, {}, {}
  for _, id in ipairs(list) do
    local ok, title, parent = pcall(GetCategoryInfo, id)
    -- wewnetrzne kategorie gry („Do Not Display” itp.) pomijamy
    local hidden = ok and str(title) and title:lower():find("not display", 1, true)
    if hidden then skip[id] = true end
    if ok and str(title) and not hidden then
      local total, done = catCount(id)
      local c = { id = id, title = CAT_PL[title] or title, parent = U.num(parent) or -1, kids = {}, total = total, done = done,
        own = total, ownDone = done }
      byId[id] = c
      if c.parent <= 0 then tops[#tops + 1] = c else kids[#kids + 1] = c end
    end
  end
  for _, k in ipairs(kids) do
    local p = byId[k.parent]
    if p then
      p.kids[#p.kids + 1] = k
      p.total, p.done = p.total + k.total, p.done + k.done
    elseif not skip[k.parent] then
      tops[#tops + 1] = k
    end
  end
  return tops, byId
end

-- wszystkie osiagniecia (do „Blisko” i „zdobyte z”), co najwyzej raz na minute
local function scanAll()
  if A.all and GetTime() - (A.allAt or 0) < 60 then return A.all end
  local all = {}
  for _, id in ipairs(U.call(GetCategoryList) or {}) do
    for _, a in ipairs(catAchievements(id)) do all[#all + 1] = a end
    if #all >= 3000 then break end -- bezpiecznik: przy ogromnej bazie bez zaciecia gry
  end
  A.all, A.allAt = all, GetTime()
  return all
end

local function isTracked(id)
  local CT = C_ContentTracking
  if CT and CT.IsTracking and Enum and Enum.ContentTrackingType then
    return U.call(CT.IsTracking, Enum.ContentTrackingType.Achievement, id) and true or false
  end
  if GetTrackedAchievements then
    local res = { pcall(GetTrackedAchievements) }
    if res[1] then for k = 2, #res do if res[k] == id then return true end end end
  end
  return false
end
local function toggleTrack(a)
  if not a or a.done then return end
  local CT, on = C_ContentTracking, isTracked(a.id)
  local ok = false
  if CT and Enum and Enum.ContentTrackingType then
    if on then
      ok = pcall(CT.StopTracking, Enum.ContentTrackingType.Achievement, a.id,
        Enum.ContentTrackingStopType and Enum.ContentTrackingStopType.Manual or 0)
    else
      ok = pcall(CT.StartTracking, Enum.ContentTrackingType.Achievement, a.id)
    end
  end
  if not ok then
    if on and RemoveTrackedAchievement then ok = pcall(RemoveTrackedAchievement, a.id)
    elseif not on and AddTrackedAchievement then ok = pcall(AddTrackedAchievement, a.id) end
  end
  say(ok and ((on and "nie śledzę: " or "śledzę: ") .. a.name .. ".") or "gra nie pozwoliła śledzić tego osiągnięcia.")
end

local function fmtDate(a)
  if not (a.d and a.m) then return "" end
  return string.format("%d.%02d", a.d, a.m) .. (a.y and string.format(".%02d", a.y % 100) or "")
end

-- ---------- wiersze ----------
local function catRow(i)
  local r = A.catRows[i]
  if r then return r end
  r = CreateFrame("Button", nil, A.catList)
  r:SetHeight(34)
  r.sel = U.Rect(r, C.gold, 0.1)
  r.sel:SetAllPoints()
  local hl = r:CreateTexture(nil, "HIGHLIGHT")
  hl:SetAllPoints()
  hl:SetColorTexture(1, 1, 1, 0.04)
  r.t = U.Text(r, 14, "body", C.text)
  r.t:SetPoint("TOPLEFT", 8, -5)
  r.n = U.Text(r, 12, "body", C.muted)
  r.n:SetPoint("TOPRIGHT", -8, -6)
  r.n:SetJustifyH("RIGHT")
  r.bar = U.Bar(r, 4, C.goldDim)
  r.bar:SetPoint("BOTTOMLEFT", 8, 4)
  r.bar:SetPoint("BOTTOMRIGHT", -8, 4)
  r:SetScript("OnClick", function(self)
    if not self.c then return end
    local was = A.cat == self.c.id
    A.cat = self.c.id
    if #self.c.kids > 0 then A.open[self.c.id] = not (was and A.open[self.c.id]) end
    A.sel = nil
    A.view:SetVerticalScroll(0)
    A.refresh()
  end)
  A.catRows[i] = r
  return r
end

local function achRow(i)
  local r = A.rows[i]
  if r then return r end
  r = CreateFrame("Button", nil, A.list)
  r:SetHeight(ROW_H - 4)
  r.sel = U.Rect(r, C.gold, 0.08)
  r.sel:SetAllPoints()
  local hl = r:CreateTexture(nil, "HIGHLIGHT")
  hl:SetAllPoints()
  hl:SetColorTexture(1, 1, 1, 0.04)
  r.slot = U.Slot(r, 40)
  r.slot:SetPoint("LEFT", 4, 0)
  r.slot:EnableMouse(false)
  r.pts = U.Tag(r, "")
  r.pts:SetPoint("TOPRIGHT", -6, -6)
  r.name = U.Text(r, 14, "body", C.text)
  r.name:SetPoint("TOPLEFT", r.slot, "TOPRIGHT", 10, 0)
  r.desc = U.Text(r, 11, "body", C.muted)
  r.desc:SetPoint("TOPLEFT", r.name, "BOTTOMLEFT", 0, -3)
  r.bar = U.Bar(r, 5, C.goldDim)
  r.bar:SetPoint("TOPLEFT", r.desc, "BOTTOMLEFT", 0, -6)
  r.val = U.Text(r, 11, "body", C.text)
  r.val:SetPoint("LEFT", r.bar, "RIGHT", 8, 0)
  r.val:SetJustifyV("MIDDLE")
  r:SetScript("OnClick", function(self)
    if not self.a then return end
    if IsShiftKeyDown() then toggleTrack(self.a) end
    A.sel = self.a.id
    A.refresh()
  end)
  r:SetScript("OnEnter", function(self)
    if not self.a then return end
    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
    local link = U.call(GetAchievementLink, self.a.id)
    if not (link and pcall(GameTooltip.SetHyperlink, GameTooltip, link)) then
      GameTooltip:SetText(self.a.name, C.gold[1], C.gold[2], C.gold[3])
      if self.a.desc then GameTooltip:AddLine(self.a.desc, 1, 1, 1, true) end
    end
    GameTooltip:AddLine("LPM: szczegóły · Shift+LPM: śledź", C.faint[1], C.faint[2], C.faint[3])
    GameTooltip:Show()
  end)
  r:SetScript("OnLeave", function() GameTooltip:Hide() end)
  A.rows[i] = r
  return r
end

local function smallRow(pool, i, parent)
  local r = pool[i]
  if r then return r end
  r = CreateFrame("Button", nil, parent)
  r:SetSize(R_W - 36, 22)
  r.t = U.Text(r, 13, "body", C.text)
  r.t:SetPoint("LEFT", 0, 0)
  r.t:SetWidth(R_W - 120)
  r.t:SetJustifyV("MIDDLE")
  r.v = U.Text(r, 12, "body", C.muted)
  r.v:SetPoint("RIGHT", 0, 0)
  r.v:SetJustifyH("RIGHT")
  r.v:SetJustifyV("MIDDLE")
  r:SetScript("OnClick", function(self)
    if self.a then A.sel = self.a.id A.cat = self.a.cat or A.cat A.refresh() end
  end)
  pool[i] = r
  return r
end

-- ---------- rysowanie ----------
local function drawCats()
  local y, n = 0, 0
  local w = math.max(200, A.catView:GetWidth() or (L_W - 32))
  A.catList:SetWidth(w)
  local function put(c, indent)
    n = n + 1
    local r = catRow(n)
    r.c = c
    r:SetWidth(w - indent)
    r:ClearAllPoints()
    r:SetPoint("TOPLEFT", A.catList, "TOPLEFT", indent, -y)
    r.t:SetText(c.title)
    r.t:SetWidth(w - indent - 90)
    U.Color(r.t, A.cat == c.id and C.gold or (indent > 0 and C.muted or C.text))
    r.n:SetText(c.total > 0 and (c.done .. " / " .. c.total) or "—")
    r.bar:SetValue(c.total > 0 and c.done / c.total or 0)
    r.sel:SetShown(A.cat == c.id)
    r:Show()
    y = y + 38
  end
  for _, c in ipairs(A.tops or {}) do
    put(c, 0)
    if A.open[c.id] or (A.byId[A.cat] and A.byId[A.cat].parent == c.id) then
      for _, k in ipairs(c.kids) do put(k, 16) end
    end
  end
  for i = n + 1, #A.catRows do A.catRows[i]:Hide() end
  A.catList:SetHeight(math.max(10, y))
end

local function drawList()
  local c = A.byId and A.byId[A.cat]
  A.mTitle:SetText(c and c.title or "Osiągnięcia")
  -- 14.11 (zrzut: „W tej kategorii nie ma osiagniec” przy Classes 0/27): gorna kategoria czesto nie ma wlasnych
  -- osiagniec, tylko podkategorie; wtedy lista z wszystkich podkategorii
  local list = c and catAchievements(c.id) or {}
  if c and #list == 0 then
    for _, k in ipairs(c.kids or {}) do
      for _, a in ipairs(catAchievements(k.id)) do list[#list + 1] = a end
    end
  end
  local w = math.max(240, A.view:GetWidth() or 400)
  A.list:SetWidth(w)
  local y, n, selA = 0, 0, nil
  for _, a in ipairs(list) do
    if A.filter == "all" or not a.done then
      n = n + 1
      progress(a)
      a.cat = A.cat
      local r = achRow(n)
      r.a = a
      r:SetWidth(w)
      r:ClearAllPoints()
      r:SetPoint("TOPLEFT", A.list, "TOPLEFT", 0, -y)
      r.slot.icon:SetTexture(a.icon or 134400)
      r.slot.icon:SetDesaturated(not a.done)
      U.BorderColor(r.slot, a.done and C.gold or C.line)
      r.name:SetText(a.name .. (isTracked(a.id) and "  (śledzone)" or ""))
      r.name:SetWidth(w - 130)
      U.Color(r.name, a.done and C.gold or C.text)
      r.desc:SetText(a.done and ("Zdobyte " .. fmtDate(a)) or (a.desc or ""))
      r.desc:SetWidth(w - 130)
      r.bar:SetWidth(math.max(60, w - 200))
      r.bar:SetValue(a.prog or 0)
      r.bar:SetFillColor(a.done and C.gold or C.goldDim)
      r.val:SetText((a.max or 0) > 1 and (a.cur .. " / " .. a.max) or "")
      r.pts:SetShown(a.points > 0)
      r.pts:SetTag(tostring(a.points), a.done and C.gold or C.goldDim)
      r.sel:SetShown(A.sel == a.id)
      if A.sel == a.id then selA = a end
      r:Show()
      y = y + ROW_H
    end
  end
  for i = n + 1, #A.rows do A.rows[i]:Hide() end
  A.list:SetHeight(math.max(10, y))
  local max = math.max(0, y - A.view:GetHeight())
  if A.view:GetVerticalScroll() > max then A.view:SetVerticalScroll(max) end
  A.mEmpty:SetShown(n == 0)
  A.mEmpty:SetText(#list == 0 and "W tej kategorii nie ma osiągnięć." or "Wszystko zdobyte. Pokaż: Wszystkie.")
  return selA
end

local function drawRight(selA)
  local pts = U.num(U.call(GetTotalAchievementPoints))
  A.pts:SetText(pts and tostring(pts) or "—")
  local all = scanAll()
  local done = 0
  for _, a in ipairs(all) do if a.done then done = done + 1 end end
  A.ptsSub:SetText(done .. " zdobyte z " .. #all)
  -- szczegoly wybranego
  if selA then
    A.dName:SetText(selA.name)
    local parts = {}
    if selA.desc then parts[#parts + 1] = selA.desc end
    if not selA.done and (selA.max or 0) > 1 then parts[#parts + 1] = "Postęp: " .. selA.cur .. " / " .. selA.max end
    if selA.missing and #selA.missing > 0 then
      local miss = {}
      for i = 1, math.min(6, #selA.missing) do miss[i] = selA.missing[i] end
      parts[#parts + 1] = U.hex(C.gold) .. "Brakuje:|r " .. table.concat(miss, ", ") .. (#selA.missing > 6 and " …" or "")
    end
    if selA.reward then parts[#parts + 1] = "Nagroda: " .. selA.reward end
    if selA.done then parts[#parts + 1] = "Zdobyte " .. fmtDate(selA) end
    A.dText:SetText(table.concat(parts, "\n"))
    A.track:SetShown(not selA.done)
    A.track:SetLabel(isTracked(selA.id) and "Nie śledź" or "Śledź")
  else
    A.dName:SetText("Wybierz osiągnięcie")
    A.dText:SetText("Kliknij osiągnięcie na liście: zobaczysz, czego jeszcze brakuje.")
    A.track:Hide()
  end
  -- ostatnio zdobyte
  local rec = { U.call(GetLatestCompletedAchievements) }
  local n = 0
  for _, id in ipairs(rec) do
    local a = type(id) == "number" and achInfo(id)
    if a and n < 3 then
      n = n + 1
      local r = smallRow(A.recRows, n, A.right)
      r.a = a
      r:ClearAllPoints()
      r:SetPoint("TOPLEFT", A.recL, "BOTTOMLEFT", 0, -6 - (n - 1) * 24)
      r.t:SetText(a.name)
      r.v:SetText(fmtDate(a) .. " · " .. a.points .. " pkt")
      r:Show()
    end
  end
  for i = n + 1, #A.recRows do A.recRows[i]:Hide() end
  A.recNone:SetShown(n == 0)
  A.nearL:ClearAllPoints()
  A.nearL:SetPoint("TOPLEFT", A.recL, "BOTTOMLEFT", 0, -16 - math.max(1, n) * 24)
  -- blisko: niezdobyte z najwiekszym postepem
  local near = {}
  for _, a in ipairs(all) do
    if not a.done then
      progress(a)
      if (a.max or 0) > 1 and a.prog >= 0.4 then near[#near + 1] = a end
    end
  end
  table.sort(near, function(a, b) return a.prog > b.prog end)
  local m = 0
  for _, a in ipairs(near) do
    if m >= 4 then break end
    m = m + 1
    local r = smallRow(A.nearRows, m, A.right)
    r.a = a
    r:ClearAllPoints()
    r:SetPoint("TOPLEFT", A.nearL, "BOTTOMLEFT", 0, -6 - (m - 1) * 24)
    r.t:SetText(a.name)
    r.v:SetText(a.cur .. " / " .. a.max)
    r:Show()
  end
  for i = m + 1, #A.nearRows do A.nearRows[i]:Hide() end
  A.nearNone:SetShown(m == 0)
end

local function refresh()
  if not A.page then return end
  local ok = hasApi()
  local tops, byId
  if ok then tops, byId = readCats() end
  ok = ok and tops ~= nil
  A.body:SetShown(ok)
  A.none:SetShown(not ok)
  if not ok then return end
  A.tops, A.byId = tops, byId
  if not A.cat or not byId[A.cat] then A.cat = tops[1] and tops[1].id end
  drawCats()
  local selA = drawList()
  pcall(drawRight, selA)
end
A.refresh = refresh

-- ---------- uklad ----------
local function toggle(parent, text, w, key)
  local b = CreateFrame("Button", nil, parent)
  b:SetSize(w, 22)
  b.t = U.Text(b, 12, "title", C.muted)
  b.t:SetPoint("CENTER", 0, 1)
  b.t:SetJustifyH("CENTER")
  b.t:SetText(text)
  b.u = U.Line(b, C.gold)
  b.u:SetPoint("BOTTOMLEFT", 8, 0) b.u:SetPoint("BOTTOMRIGHT", -8, 0)
  b.key = key
  return b
end
local function scroll(parent, step)
  local view = CreateFrame("ScrollFrame", nil, parent)
  local list = CreateFrame("Frame", nil, view)
  list:SetSize(300, 10)
  view:SetScrollChild(list)
  view:EnableMouseWheel(true)
  view:SetScript("OnMouseWheel", function(self, d)
    local max = math.max(0, list:GetHeight() - self:GetHeight())
    self:SetVerticalScroll(math.max(0, math.min(max, self:GetVerticalScroll() - d * step)))
  end)
  return view, list
end

local function build(page)
  A.page = page
  -- bez danych z gry: spokojny komunikat i okno gry
  local none = U.Panel(page, 0.86, true)
  none:SetSize(620, 240)
  none:SetPoint("CENTER", page, "CENTER", 0, 30)
  local nt = U.Text(none, 26, "title", C.gold)
  nt:SetPoint("TOPLEFT", 30, -28)
  nt:SetText("Osiągnięcia")
  local np = U.Para(none, 14, 560, C.text)
  np:SetPoint("TOPLEFT", nt, "BOTTOMLEFT", 0, -12)
  np:SetText("Gra nie podała listy osiągnięć dodatkom. Możliwe, że Forever pokazuje je tylko we własnym oknie.")
  local nb = U.Button(none, "Okno osiągnięć (gra)", nil, 32, true)
  nb:SetPoint("BOTTOMLEFT", none, "BOTTOMLEFT", 30, 28)
  nb:SetScript("OnClick", function() U.OpenGame(function() ToggleAchievementFrame() end) end)
  nb:SetShown(ToggleAchievementFrame ~= nil)
  none:Hide()
  A.none = none

  local body = CreateFrame("Frame", nil, page)
  body:SetAllPoints()
  A.body = body
  -- lewo: kategorie
  local L = U.Panel(body, 0.86, true)
  L:SetPoint("TOPLEFT") L:SetPoint("BOTTOMLEFT") L:SetWidth(L_W)
  local lh = U.H2(L, "Kategorie")
  lh:SetPoint("TOPLEFT", 18, -16)
  A.catView, A.catList = scroll(L, 76)
  A.catView:SetPoint("TOPLEFT", lh, "BOTTOMLEFT", -8, -12)
  A.catView:SetPoint("BOTTOMRIGHT", L, "BOTTOMRIGHT", -12, 14)

  -- prawo: punkty, szczegoly, ostatnio, blisko
  local R = U.Panel(body, 0.86, true)
  R:SetPoint("TOPRIGHT") R:SetPoint("BOTTOMRIGHT") R:SetWidth(R_W)
  A.right = R
  local w = R_W - 36
  local pl = U.Label(R, "Punkty osiągnięć")
  pl:SetPoint("TOPLEFT", 18, -18)
  A.pts = U.Text(R, 36, "title", C.gold)
  A.pts:SetPoint("TOPLEFT", pl, "BOTTOMLEFT", 0, -4)
  A.ptsSub = U.Text(R, 12, "body", C.muted)
  A.ptsSub:SetPoint("LEFT", A.pts, "RIGHT", 12, -4)
  local s1 = U.Line(R, C.line)
  s1:SetPoint("TOPLEFT", A.pts, "BOTTOMLEFT", 0, -10)
  s1:SetWidth(w)
  A.dName = U.Para(R, 17, w, C.gold, "title")
  A.dName:SetPoint("TOPLEFT", s1, "BOTTOMLEFT", 0, -12)
  A.dText = U.Para(R, 12, w, C.text)
  A.dText:SetPoint("TOPLEFT", A.dName, "BOTTOMLEFT", 0, -6)
  pcall(A.dText.SetMaxLines, A.dText, 9)
  A.track = U.Button(R, "Śledź", nil, 28)
  A.track:SetPoint("TOPLEFT", A.dText, "BOTTOMLEFT", 0, -10)
  A.track:SetScript("OnClick", function()
    local all = scanAll()
    for _, a in ipairs(all) do if a.id == A.sel then toggleTrack(a) break end end
    A.refresh()
  end)
  A.recL = U.Label(R, "Ostatnio")
  A.recL:SetPoint("TOPLEFT", A.track, "BOTTOMLEFT", 0, -20)
  A.recNone = U.Text(R, 12, "body", C.faint)
  A.recNone:SetPoint("TOPLEFT", A.recL, "BOTTOMLEFT", 0, -8)
  A.recNone:SetText("Jeszcze nic.")
  A.nearL = U.Label(R, "Blisko")
  A.nearNone = U.Text(R, 12, "body", C.faint)
  A.nearNone:SetPoint("TOPLEFT", A.nearL, "BOTTOMLEFT", 0, -8)
  A.nearNone:SetText("Nic nie jest blisko końca.")
  local foot = U.Para(R, 11, w, C.faint)
  foot:SetPoint("BOTTOMLEFT", R, "BOTTOMLEFT", 18, 14)
  foot:SetText("Shift+LPM na osiągnięciu: śledzenie. Złota ramka: zdobyte.")

  -- srodek: lista
  local M = U.Panel(body, 0.86, true)
  M:SetPoint("TOPLEFT", L, "TOPRIGHT", 20, 0)
  M:SetPoint("BOTTOMRIGHT", R, "BOTTOMLEFT", -20, 0)
  A.mTitle = U.H2(M, "Osiągnięcia")
  A.mTitle:SetPoint("TOPLEFT", 18, -16)
  local fAll = toggle(M, "Wszystkie", 84, "all")
  fAll:SetPoint("TOPRIGHT", M, "TOPRIGHT", -14, -13)
  local fTodo = toggle(M, "Niezdobyte", 92, "todo")
  fTodo:SetPoint("RIGHT", fAll, "LEFT", -2, 0)
  local function paint()
    for _, b in ipairs({ fAll, fTodo }) do
      U.Color(b.t, A.filter == b.key and C.gold or C.muted)
      b.u:SetShown(A.filter == b.key)
    end
  end
  for _, b in ipairs({ fAll, fTodo }) do
    b:SetScript("OnClick", function(self) A.filter = self.key paint() A.view:SetVerticalScroll(0) A.refresh() end)
  end
  paint()
  A.view, A.list = scroll(M, ROW_H * 2)
  A.view:SetPoint("TOPLEFT", A.mTitle, "BOTTOMLEFT", 0, -14)
  A.view:SetPoint("BOTTOMRIGHT", M, "BOTTOMRIGHT", -14, 14)
  A.mEmpty = U.Para(M, 13, 400, C.faint)
  A.mEmpty:SetPoint("TOPLEFT", A.mTitle, "BOTTOMLEFT", 0, -16)
end

-- ---------- zdarzenia (tylko przy otwartej zakladce) ----------
local ev = CreateFrame("Frame")
ev:SetScript("OnEvent", function(_, event)
  if event == "ACHIEVEMENT_EARNED" then A.all = nil end
  if A.pending then return end
  A.pending = true
  C_Timer.After(1, function()
    A.pending = false
    if A.page and A.page:IsVisible() then pcall(refresh) end
  end)
end)

U.RegisterTab({
  id = "osiagniecia", order = 7, title = "Osiągnięcia", keys = "", heavy = true,
  hints = { { { "LPM" }, "Szczegóły" }, { { "Shift", "LPM" }, "Śledź" } },
  note = "Złota ramka: zdobyte",
  build = build,
  refresh = function()
    for _, e in ipairs({ "ACHIEVEMENT_EARNED", "CRITERIA_UPDATE", "RECEIVED_ACHIEVEMENT_LIST", "TRACKED_ACHIEVEMENT_LIST_CHANGED" }) do
      pcall(ev.RegisterEvent, ev, e)
    end
    pcall(refresh)
    C_Timer.After(0, function() if A.page and A.page:IsVisible() then pcall(refresh) end end)
  end,
  leave = function() ev:UnregisterAllEvents() end,
})
