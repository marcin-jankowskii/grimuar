-- Grimuar UI: tryby mapy huba z legenda (14.11, zrzut gracza: „tryb questowy dziala super. To powinien byc jeden z trybow
-- wyswietlania, taki z legenda powiazany”). Tryby: Zadania (cele w kolorach zadan, „?” oddaj), Miasto (wazne postacie),
-- Zbieranie (ziola i ruda z bazy GatherMate2, kolor = szansa na punkt) i Wszystko. Panel pod zakladkami trybow to legenda
-- tego, co widac: kazdy wiersz podswietla swoje znaczniki (najazd) i prowadzi do najblizszego (LPM).
-- Krok planu Grimuara, Twoj znacznik i Ty sa zawsze. TabMapa.lua daje U.MAP (stan mapy) i rysuje zadania oraz postacie.
local ADDON, U = ...
local C = U.C

local SIDE = 340
local L = { rows = {}, gp = {}, tabs = {} }
local MODES = { { "zadania", "Zadania" }, { "miasto", "Miasto" }, { "zbieranie", "Zbieranie" }, { "wszystko", "Wszystko" } }
local HEAD = { zadania = "Zadania tutaj", miasto = "Ważne postacie tutaj", zbieranie = "Zioła i ruda tutaj", wszystko = "Zadania tutaj" }

function U.mapMode()
  local d = U.db()
  d.mapLayers = d.mapLayers or {}
  return d.mapLayers.mode or "zadania"
end
function U.mapShows(what)
  local m = U.mapMode()
  if m == "wszystko" then return true end
  return (what == "quest" and m == "zadania") or (what == "svc" and m == "miasto") or (what == "gather" and m == "zbieranie")
end

-- ---------- zbieractwo z GatherMate2 ----------
local PROF_PL = { Herbalism = "Zielarstwo", Mining = "Górnictwo" }
local DCOL = { [0] = { 0.925, 0.541, 0.333 }, [1] = { 0.91, 0.761, 0.353 }, [2] = { 0.498, 0.792, 0.353 }, [3] = { 0.55, 0.53, 0.48 },
  [4] = { 0.8, 0.25, 0.2 } }
local DTXT = { [0] = "pewny punkt", [1] = "zwykle punkt", [2] = "rzadko punkt", [3] = "bez punktu", [4] = "za wysoko" }
local function gm()
  local AA = LibStub and LibStub("AceAddon-3.0", true)
  return AA and AA:GetAddon("GatherMate2", true)
end
local gcache = {}
local function gatherNodes(uiMapID)
  if gcache.map == uiMapID and gcache.list and GetTime() - gcache.at < 30 then return gcache.list end
  local GM = gm()
  if not (GM and type(GM.gmdbs) == "table") then return nil end
  local profs = U.call(U.G.readProfs) or {}
  local out = {}
  for _, t in ipairs({ { "Herb Gathering", "Herbalism" }, { "Mining", "Mining" } }) do
    local db = GM.gmdbs[t[1]] and GM.gmdbs[t[1]][uiMapID]
    if type(db) == "table" then
      local skill = profs[t[2]] and profs[t[2]].rank
      local texs = GM.nodeTextures and GM.nodeTextures[t[1]] or {}
      for coord, nodeID in pairs(db) do
        local ok, x, y = pcall(GM.DecodeLoc, GM, coord)
        if ok and x and y then
          local name = U.call(GM.GetNameForNode, GM, t[1], nodeID) or "?"
          local req = U.gatherReq and U.gatherReq(name)
          out[#out + 1] = { x = x, y = y, name = name, prof = t[2], icon = texs[nodeID], skill = skill, req = req,
            d = (req and skill) and U.gatherD(req, skill) or nil }
        end
      end
    end
  end
  gcache = { map = uiMapID, at = GetTime(), list = out }
  return out
end
U.gatherNodes = gatherNodes -- kompas u gory ekranu (Kompas.lua)

local function gpin(i)
  local p = L.gp[i]
  if p then return p end
  local M = U.MAP
  p = CreateFrame("Button", nil, M.pins)
  p:SetSize(14, 14)
  p:SetFrameLevel(M.pins:GetFrameLevel() + 1)
  p.i = p:CreateTexture(nil, "ARTWORK")
  p.i:SetAllPoints()
  p:RegisterForClicks("LeftButtonUp")
  p:SetScript("OnEnter", function(self)
    local d = self.d
    if not d then return end
    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
    GameTooltip:SetText(d.name, C.gold[1], C.gold[2], C.gold[3])
    local col = DCOL[d.d or 3]
    if d.skill then
      GameTooltip:AddLine((PROF_PL[d.prof] or d.prof) .. " " .. d.skill .. ": " .. (DTXT[d.d or 3] or "") .. (d.req and (" (od " .. d.req .. ")") or ""), col[1], col[2], col[3])
    else
      GameTooltip:AddLine("Nie masz profesji " .. (PROF_PL[d.prof] or d.prof) .. (d.req and (", od " .. d.req) or ""), C.muted[1], C.muted[2], C.muted[3])
    end
    GameTooltip:AddLine("Miejsce z bazy GatherMate2 · LPM: prowadź", C.faint[1], C.faint[2], C.faint[3])
    GameTooltip:Show()
  end)
  p:SetScript("OnLeave", function() GameTooltip:Hide() end)
  p:SetScript("OnClick", function(self) if self.d then U.MAP.guide(self.d.x, self.d.y, self.d.name) end end)
  L.gp[i] = p
  return p
end
local function hideGather() for _, p in ipairs(L.gp) do p:Hide() end end
function U.MAP_placeGather()
  hideGather()
  local M = U.MAP
  if not (M and M.art and U.mapShows("gather")) then return end
  local list = gatherNodes(M.mapID) or {}
  local W, H = M.art:GetWidth(), M.art:GetHeight()
  local n = 0
  for _, d in ipairs(list) do
    if n >= 700 then break end
    n = n + 1
    local p = gpin(n)
    p.d = d
    p.i:SetTexture(d.icon or "Interface\\Icons\\INV_Misc_Herb_07")
    p:SetAlpha((d.d == 4 or not d.skill) and 0.45 or 1)
    p:ClearAllPoints()
    p:SetPoint("CENTER", M.art, "TOPLEFT", d.x * W, -d.y * H)
    p:Show()
  end
end

-- ---------- wiersze legendy ----------
local function row(i)
  local r = L.rows[i]
  if r then return r end
  r = CreateFrame("Button", nil, L.parent)
  r:SetSize(SIDE, 36)
  local hl = r:CreateTexture(nil, "HIGHLIGHT")
  hl:SetAllPoints()
  hl:SetColorTexture(1, 1, 1, 0.05)
  r.d = U.Diamond(r, 13, C.gold, true)
  r.d:SetPoint("TOPLEFT", 1, -5)
  r.ic = r:CreateTexture(nil, "ARTWORK")
  r.ic:SetSize(18, 18)
  r.ic:SetPoint("TOPLEFT", -1, -2)
  r.t = U.Text(r, 14, "body", C.text)
  r.t:SetPoint("TOPLEFT", 22, -3)
  r.t:SetWidth(SIDE - 24)
  r.s = U.Text(r, 12, "body", C.muted)
  r.s:SetPoint("TOPLEFT", r.t, "BOTTOMLEFT", 0, -3)
  r.s:SetWidth(SIDE - 24)
  r:RegisterForClicks("LeftButtonUp", "RightButtonUp")
  r:SetScript("OnClick", function(self, btn) if self.onClick then self.onClick(btn) end end)
  r:SetScript("OnEnter", function(self) if self.onEnter then self.onEnter() end end)
  r:SetScript("OnLeave", function(self) if self.onLeave then self.onLeave() end end)
  L.rows[i] = r
  return r
end
local function maxRows()
  local M = U.MAP
  local top, bottom = L.head:GetBottom(), M.box and M.box:GetTop()
  if top and bottom then return math.max(2, math.floor((top - bottom - 34) / 38)) end
  return 7
end
local function put(n, e)
  local r = row(n)
  r.t:SetText(e.title or "")
  U.Color(r.t, e.titleCol or C.text)
  r.s:SetText(e.sub or "")
  r.d:SetShown(e.col ~= nil and not e.icon)
  if e.col and not e.icon then r.d:Set(e.col, e.filled ~= false) end
  r.ic:SetShown(e.icon ~= nil)
  if e.icon then r.ic:SetTexture(e.icon) end
  r.onClick, r.onEnter, r.onLeave = e.onClick, e.onEnter, e.onLeave
  r:ClearAllPoints()
  r:SetPoint("TOPLEFT", L.head, "BOTTOMLEFT", 0, -8 - (n - 1) * 38)
  r:Show()
end
local function finish(n, total, empty)
  for i = n + 1, #L.rows do L.rows[i]:Hide() end
  L.none:SetShown(n == 0)
  L.none:SetText(empty or "")
  L.more:SetShown(total > n)
  L.more:SetText("+ " .. (total - n) .. " dalej")
  L.more:ClearAllPoints()
  L.more:SetPoint("TOPLEFT", L.head, "BOTTOMLEFT", 0, -12 - n * 38)
end
local function dist(px, py, x, y)
  local M = U.MAP
  local m, dir = U.mapDistance(M.mapID, px, py, x, y)
  return m and (U.fmtDistance(m) .. " na " .. dir) or nil
end

-- tryb Zadania (i Wszystko): zadania z celami na tej mapie, od najblizszego
local function legendQuests()
  local M = U.MAP
  local id, info = M.mapID, M.mapInfo(M.mapID)
  local px, py = M.playerPos(id)
  local _, quests, ok = U.questPins(id)
  local rows, seen = {}, {}
  for _, q in ipairs(quests or {}) do
    seen[q.qid] = true
    local best, bx, by
    for _, p in ipairs(q.pins) do
      local d2 = px and ((p.x - px) ^ 2 + (p.y - py) ^ 2) or 0
      if not best or d2 < best then best, bx, by = d2, p.x, p.y end
    end
    rows[#rows + 1] = { qid = q.qid, title = q.title, complete = q.complete, col = q.col, x = bx, y = by, d2 = px and best or nil }
  end
  for _, q in ipairs(U.questList and U.questList() or {}) do
    if not q.header and info and q.zone == info.name and not seen[q.id] then
      rows[#rows + 1] = { qid = q.id, title = q.title, complete = q.complete }
    end
  end
  table.sort(rows, function(a, b)
    if (a.x ~= nil) ~= (b.x ~= nil) then return a.x ~= nil end
    if a.d2 and b.d2 and a.d2 ~= b.d2 then return a.d2 < b.d2 end
    return (a.title or "") < (b.title or "")
  end)
  local max, n = maxRows(), 0
  for _, r in ipairs(rows) do
    if n >= max then break end
    n = n + 1
    local parts = {}
    if r.complete then
      parts[1] = U.hex(C.ok) .. "gotowe, oddaj|r"
    else
      local a, b = 0, 0
      for _, o in ipairs(U.call(C_QuestLog.GetQuestObjectives, r.qid) or {}) do
        a, b = a + (U.num(o.numFulfilled) or 0), b + (U.num(o.numRequired) or 0)
      end
      if b > 0 then parts[1] = a .. " / " .. b end
    end
    if r.x and px then parts[#parts + 1] = dist(px, py, r.x, r.y)
    elseif not r.x then parts[#parts + 1] = "bez miejsca na tej mapie" end
    put(n, { title = r.title, sub = table.concat(parts, " · "), col = r.complete and nil or (r.col or C.faint),
      icon = r.complete and U.QUEST_DONE_ICON or nil,
      onClick = function(btn)
        if btn == "RightButton" or not r.x then if U.questShow then U.questShow(r.qid) end
        else M.guide(r.x, r.y, r.complete and ("Oddaj: " .. r.title) or r.title) end
      end,
      onEnter = function() M.highlight(r.qid) end, onLeave = function() M.highlight(nil) end })
  end
  finish(n, #rows, (ok or not M.isZone(info)) and (M.isZone(info) and "Brak zadań z celami w tej strefie." or "Wejdź do strefy (LPM), żeby zobaczyć zadania.")
    or "Questie nie podał zadań: jest wyłączony albo jeszcze się wczytuje.")
  L.note:SetText("Romb w kolorze zadania = cel · |T" .. U.QUEST_DONE_ICON .. ":14|t oddaj · |T" .. U.QUEST_AVAIL_ICON .. ":14|t do wzięcia (szary: spoza trasy Polestara) · PPM na wierszu: Dziennik")
end

local function hlService(key)
  for _, p in ipairs(U.MAP.sp or {}) do
    if p:IsShown() and p.d then p:SetAlpha((not key or p.d.kind.key == key) and 1 or 0.2) end
  end
end
-- 15.11 (R30 P21): po kazdej policzonej usludze Polestara odswiez legende (jedna funkcja, bez mnozenia odswiezen)
function L.psRefresh()
  if U.mapMode() == "miasto" and L.head and L.head:IsVisible() then pcall(U.mapLegendRefresh) end
end
-- tryb Miasto: rodzaje postaci na tej mapie, z najblizsza
local function legendService()
  local M = U.MAP
  local id = M.mapID
  L.note:SetText("Ikony jak na minimapie · nazwy ważnych zawsze, kupców od przybliżenia x2")
  if not U.servicePins then return finish(0, 0, "Brak danych postaci.") end
  U.servicePins(id, function(pins)
    if id ~= M.mapID or U.mapMode() ~= "miasto" then return end
    local px, py = M.playerPos(id)
    local kinds, order = {}, {}
    for _, p in ipairs(pins) do
      local k = p.kind.key
      local g = kinds[k]
      if not g then g = { kind = p.kind, n = 0 } kinds[k] = g order[#order + 1] = g end
      g.n = g.n + 1
      local d2 = px and ((p.x - px) ^ 2 + (p.y - py) ^ 2) or g.n
      if not g.best or d2 < g.d2 then g.best, g.d2 = p, d2 end
    end
    table.sort(order, function(a, b) return (a.d2 or 0) < (b.d2 or 0) end)
    local max, n = maxRows(), 0
    -- 15.11 (R30 P21, Q6): na mapie, na ktorej stoisz, najpierw najblizsze uslugi wg Polestara z czasem dojscia
    -- (MapaUslugi.lua U.psNearby; klik: Polestar prowadzi), potem z Questie te rodzaje, ktorych Polestar nie podal
    local covered, psTotal = {}, 0
    if px and U.psNearbyHas and U.psNearbyHas() then
      U.psNearbyQueue(U.NEARBY_KINDS, L.psRefresh)
      local ps = {}
      for _, k in ipairs(U.NEARBY_KINDS) do
        local e = U.psNearby(k.key)
        if e then ps[#ps + 1] = { k = k, e = e } end
      end
      table.sort(ps, function(a, b) return (a.e.s or 1e9) < (b.e.s or 1e9) end)
      psTotal = #ps
      for _, x in ipairs(ps) do
        if x.k.questie then covered[x.k.questie] = true end
        if n < math.max(3, max - 2) then
          n = n + 1
          local k, e = x.k, x.e
          put(n, { title = U.psNearbyLabel(k.key) or k.pl, sub = (e.zone or "") .. ((e.sub and e.sub ~= "") and (" · " .. e.sub) or "") .. " · " .. (U.G and U.G.tr and U.G.tr("najbliżej wg Polestara") or "najbliżej wg Polestara"),
            icon = k.icon,
            onClick = function()
              if not U.psNearbyGo(k.key) and e.map and e.x then
                if U.G and U.G.wayTo then pcall(U.G.wayTo, e.map, tonumber(string.format("%.2f", e.x)), tonumber(string.format("%.2f", e.y)), e.name) end
              end
            end,
            onEnter = function() if k.questie then hlService(k.questie) end end, onLeave = function() hlService(nil) end })
        end
      end
      if psTotal > 0 then L.note:SetText("Najpierw najbliższe wg Polestara (czas dojścia, klik prowadzi) · niżej ważne postacie z tej mapy (Questie)") end
    end
    local rest = {}
    for _, g in ipairs(order) do
      if not covered[g.kind.key] then rest[#rest + 1] = g end
    end
    order = rest
    for _, g in ipairs(order) do
      if n >= max then break end
      n = n + 1
      local b = g.best
      local sub = (b.name or "") .. ((px and dist(px, py, b.x, b.y)) and (" · " .. dist(px, py, b.x, b.y)) or "")
      put(n, { title = g.kind.pl .. (g.n > 1 and (" (" .. g.n .. ")") or ""), sub = sub, icon = g.kind.icon,
        onClick = function() M.guide(b.x, b.y, b.name or g.kind.pl) end,
        onEnter = function() hlService(g.kind.key) end, onLeave = function() hlService(nil) end })
    end
    finish(n, psTotal + #order, U.servicesReady and not U.servicesReady() and "Wczytuję postacie z Questie…" or "Brak ważnych postaci na tej mapie.")
  end)
end

local function hlGather(name)
  for _, p in ipairs(L.gp) do
    if p:IsShown() and p.d then p:SetAlpha((not name or p.d.name == name) and 1 or 0.15) end
  end
end
-- tryb Zbieranie: rodzaje ziol i rud z liczba miejsc i szansa na punkt
local function legendGather()
  local M = U.MAP
  local id = M.mapID
  local list = gatherNodes(id)
  local profs = U.call(U.G.readProfs) or {}
  local h, m = profs.Herbalism, profs.Mining
  L.note:SetText("Zielarstwo " .. (h and h.rank or "—") .. " · Górnictwo " .. (m and m.rank or "—") ..
    " · kolor: pomarańczowy pewny punkt, żółty zwykle, zielony rzadko, szary bez")
  if not list then return finish(0, 0, "GatherMate2 jest wyłączony: bez niego nie ma mapy ziół i rud.") end
  local px, py = M.playerPos(id)
  local kinds, order = {}, {}
  for _, p in ipairs(list) do
    local g = kinds[p.name]
    if not g then g = { name = p.name, n = 0, d = p.d, req = p.req, icon = p.icon, skill = p.skill, prof = p.prof } kinds[p.name] = g order[#order + 1] = g end
    g.n = g.n + 1
    local d2 = px and ((p.x - px) ^ 2 + (p.y - py) ^ 2) or g.n
    if not g.best or d2 < g.d2 then g.best, g.d2 = p, d2 end
  end
  table.sort(order, function(a, b)
    local da, db = a.d or 9, b.d or 9
    if da ~= db then return da < db end
    return a.name < b.name
  end)
  local max, n = maxRows(), 0
  for _, g in ipairs(order) do
    if n >= max then break end
    n = n + 1
    local col = DCOL[g.d or 3]
    local how = g.skill and (U.hex(col) .. (DTXT[g.d or 3] or "") .. "|r" .. ((g.d == 4 and g.req) and (" (od " .. g.req .. ")") or ""))
      or ("brak profesji " .. (PROF_PL[g.prof] or g.prof))
    local near = (px and g.best) and dist(px, py, g.best.x, g.best.y) or nil
    put(n, { title = g.name, sub = g.n .. " miejsc · " .. how .. (near and (" · " .. near) or ""), icon = g.icon,
      onClick = function() if g.best then M.guide(g.best.x, g.best.y, g.name) end end,
      onEnter = function() hlGather(g.name) end, onLeave = function() hlGather(nil) end })
  end
  finish(n, #order, "Baza GatherMate2 nie ma tu ziół ani rud.")
end

function U.mapLegendRefresh()
  if not (L.head and U.MAP and U.MAP.mapID) then return end
  local mode = U.mapMode()
  L.head:SetText(HEAD[mode] or "Na mapie")
  for _, b in ipairs(L.tabs) do
    U.Color(b.t, b.mode == mode and C.gold or C.muted)
    b.u:SetShown(b.mode == mode)
  end
  if mode == "miasto" then legendService()
  elseif mode == "zbieranie" then legendGather()
  else legendQuests() end
end

-- zakladki trybow i miejsce na legende (TabMapa.lua wola przy budowie panelu)
function U.mapLegendBuild(parent, anchor)
  L.parent = parent
  local prev
  for i, m in ipairs(MODES) do
    local b = CreateFrame("Button", nil, parent)
    b:SetSize(SIDE / #MODES, 26)
    if prev then b:SetPoint("LEFT", prev, "RIGHT", 0, 0) else b:SetPoint("TOPLEFT", anchor, "BOTTOMLEFT", 0, -14) end
    b.t = U.Text(b, 13, "title", C.muted)
    b.t:SetPoint("CENTER", 0, 1)
    b.t:SetJustifyH("CENTER")
    b.t:SetText(m[2])
    b.u = U.Line(b, C.gold)
    b.u:SetPoint("BOTTOMLEFT", 6, 0) b.u:SetPoint("BOTTOMRIGHT", -6, 0)
    b.mode = m[1]
    b:SetScript("OnClick", function(self)
      U.db().mapLayers = U.db().mapLayers or {}
      U.db().mapLayers.mode = self.mode
      if U.MAP and U.MAP.placeAll then U.MAP.placeAll() end
      U.mapLegendRefresh()
    end)
    L.tabs[i] = b
    prev = b
  end
  local line = U.Line(parent, C.line)
  line:SetPoint("TOPLEFT", L.tabs[1], "BOTTOMLEFT", 0, -1)
  line:SetWidth(SIDE)
  L.note = U.Para(parent, 12, SIDE, C.faint)
  L.note:SetPoint("TOPLEFT", L.tabs[1], "BOTTOMLEFT", 0, -10)
  L.head = U.H2(parent, "Zadania tutaj")
  L.head:SetPoint("TOPLEFT", L.note, "BOTTOMLEFT", 0, -12)
  L.none = U.Para(parent, 13, SIDE, C.faint)
  L.none:SetPoint("TOPLEFT", L.head, "BOTTOMLEFT", 0, -8)
  L.more = U.Text(parent, 12, "body", C.faint)
end
