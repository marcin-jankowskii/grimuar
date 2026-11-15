-- Grimuar UI: wyszukiwarka postaci (NPC) na mapie huba (14.11, gracz: „brakuje mi wyszukiwarki npcow: wpisuje nazwe
-- i mnie do niego prowadzi”; Polestar nie prowadzil do Binka w Ironforge). Potem (14.11): „npc chcialbym miec jaka taka
-- liste wyszukiwarke: na poczatku widze npcy wg miast, a pozniej jak wpisze, to mi filtruje”.
-- Pole w lewym gornym rogu mapy: puste = katalog waznych postaci wg miejsc (Twoja strefa, Ironforge, Stormwind,
-- Darnassus; MapaUslugi.lua), wpisany tekst = filtr po nazwie, roli i tytule, a pod spodem pasujace postacie
-- z calego swiata (QuestieDB, indeks nazw budowany raz, po kawalku). Klik albo Enter: mapa strefy, znacznik i strzalka.
-- Komenda: /npc nazwa (od razu prowadzi do najlepszego wyniku). Tylko odczyt z Questie.
-- 15.11 (R30 P29, gracz: „wyszukiwarka NPC i przedmiotow”): wpisany tekst idzie najpierw do Polestar.Search
-- (MapaSzukajPolestar.lua, karty wg rodzaju); indeks Questie zostaje zapasem (bez Polestara, w walce przed baza).
local ADDON, U = ...
local C = U.C

local S = { rows = {} }
local IDX = { waiters = {} }
local ROW_H, HEAD_H = 40, 26

local function mod(name)
  local L = QuestieLoader
  if not (L and L.ImportModule) then return nil end
  local ok, m = pcall(L.ImportModule, L, name)
  return ok and type(m) == "table" and m or nil
end

-- ---------- indeks nazw wszystkich postaci (Questie) ----------
local function flush()
  local w = IDX.waiters
  IDX.waiters = {}
  for _, fn in ipairs(w) do pcall(fn) end
end
local function withIndex(fn)
  if IDX.names then return fn() end
  IDX.waiters[#IDX.waiters + 1] = fn
  if IDX.building then return end
  local DB = mod("QuestieDB")
  local ptrs = DB and DB.NPCPointers
  if not (DB and DB.QueryNPCSingle and type(ptrs) == "table") then
    IDX.names, IDX.fail = {}, true
    return flush()
  end
  IDX.building = true
  local ids = {}
  for k, v in pairs(ptrs) do
    local id = (type(k) == "number" and k) or (type(v) == "number" and v) or nil
    if id then ids[#ids + 1] = id end
  end
  local names, i, ticker = {}, 0, nil
  ticker = C_Timer.NewTicker(0.02, function()
    for _ = 1, 1200 do
      i = i + 1
      local id = ids[i]
      if not id then
        ticker:Cancel()
        IDX.names, IDX.building = names, false
        return flush()
      end
      local ok, nm = pcall(DB.QueryNPCSingle, id, "name")
      if ok and type(nm) == "string" and nm ~= "" then names[#names + 1] = { id = id, n = nm, l = nm:lower() } end
    end
  end)
end

local contCache = {}
local function continentOf(ui)
  if contCache[ui] ~= nil then return contCache[ui] end
  local id, guard, cont = ui, 0, false
  while id and guard < 8 do
    local info = U.call(C_Map.GetMapInfo, id)
    if not info then break end
    if info.mapType and info.mapType <= ((Enum and Enum.UIMapType and Enum.UIMapType.Continent) or 2) then cont = id break end
    id, guard = info.parentMapID, guard + 1
  end
  contCache[ui] = cont
  return cont
end

-- cale swiato: { name, sub, map, x, y (0-1), zone, score, enemy }
local function search(q)
  q = (q or ""):lower():gsub("^%s+", ""):gsub("%s+$", "")
  if #q < 2 or not IDX.names then return {} end
  local DB, Z = mod("QuestieDB"), mod("ZoneDB")
  if not (DB and Z) then return {} end
  local here = U.call(C_Map.GetBestMapForUnit, "player")
  local myCont = here and continentOf(here)
  local faction = (UnitFactionGroup("player") == "Horde") and "H" or "A"
  local out, n = {}, 0
  for _, e in ipairs(IDX.names) do
    if e.l:find(q, 1, true) then
      n = n + 1
      if n > 150 then break end
      local spawns = U.call(DB.QueryNPCSingle, e.id, "spawns")
      local best
      for area, list in pairs(type(spawns) == "table" and spawns or {}) do
        local ok, ui = pcall(Z.GetUiMapIdByAreaId, Z, area)
        local c = type(list) == "table" and list[1]
        local x, y = type(c) == "table" and tonumber(c[1]), type(c) == "table" and tonumber(c[2])
        if ok and ui and x and y and x >= 0 and y >= 0 and x <= 100 and y <= 100 then
          local score = (ui == here) and 0 or ((myCont and continentOf(ui) == myCont) and 1 or 2)
          if not best or score < best.score then best = { ui = ui, x = x / 100, y = y / 100, score = score } end
        end
      end
      if best then
        local fr = U.call(DB.QueryNPCSingle, e.id, "friendlyToFaction")
        local enemy = type(fr) == "string" and fr ~= "" and not fr:find(faction, 1, true)
        local info = U.call(C_Map.GetMapInfo, best.ui)
        out[#out + 1] = { name = e.n, sub = U.call(DB.QueryNPCSingle, e.id, "subName"), map = best.ui,
          x = best.x, y = best.y, zone = info and info.name or "?", enemy = enemy,
          score = best.score + (e.l == q and -2 or 0) + (enemy and 3 or 0) }
      end
    end
  end
  table.sort(out, function(a, b)
    if a.score ~= b.score then return a.score < b.score end
    return a.name < b.name
  end)
  return out
end

-- ---------- lista: naglowki grup i postacie ----------
local function fmt(v) return (string.format("%.1f", v * 100):gsub("%.", ",")) end
local function hideList()
  if S.list then S.list:Hide() end
end
local function pick(r)
  if not r then return end
  S.box:ClearFocus()
  hideList()
  if U.mapGuide then U.mapGuide(r.map, r.x, r.y, r.name) end
  local info = U.call(C_Map.GetMapInfo, r.map)
  U.say("prowadzę do: " .. r.name .. (r.sub and r.sub ~= "" and (" <" .. r.sub .. ">") or "") .. ", " ..
    (r.zone or (info and info.name) or "?") .. " " .. fmt(r.x) .. " · " .. fmt(r.y) .. ".")
end

local function row(i)
  local r = S.rows[i]
  if r then return r end
  r = CreateFrame("Button", nil, S.child)
  r:SetHeight(ROW_H)
  -- 15.11 (R30 P29): wiersz jako karta (tlo, ramka, ikona 26), prawy klik i dymek (wyniki z MapaSzukajPolestar.lua)
  r.bg = U.Rect(r, C.panel2, 0.75) r.bg:SetAllPoints()
  U.Border(r, C.line)
  r:RegisterForClicks("LeftButtonUp", "RightButtonUp")
  r.hl = r:CreateTexture(nil, "HIGHLIGHT")
  r.hl:SetAllPoints()
  r.hl:SetColorTexture(1, 1, 1, 0.06)
  r.ic = r:CreateTexture(nil, "ARTWORK")
  r.ic:SetSize(26, 26)
  r.ic:SetPoint("TOPLEFT", 7, -7)
  r.ic:SetTexCoord(0.08, 0.92, 0.08, 0.92)
  r.n = U.Text(r, 14, "body", C.gold)
  r.n:SetPoint("TOPLEFT", 40, -4)
  r.n:SetWidth(330)
  r.s = U.Text(r, 12, "body", C.muted)
  r.s:SetPoint("TOPLEFT", r.n, "BOTTOMLEFT", 0, -3)
  r.s:SetWidth(330)
  r.h = U.Text(r, 12, "title", C.goldDim)
  r.h:SetPoint("BOTTOMLEFT", 6, 5)
  r.line = U.Line(r, C.line)
  r.line:SetPoint("BOTTOMLEFT", 0, 0) r.line:SetPoint("BOTTOMRIGHT", 0, 0)
  r:SetScript("OnClick", function(self, btn)
    if not self.r then return end
    if self.r.act then pcall(self.r.act, btn) else pick(self.r) end
  end)
  r:SetScript("OnEnter", function(self)
    if not (self.tip or self.item) then return end
    U.TT:SetOwner(self, "ANCHOR_RIGHT")
    if not (self.item and pcall(U.TT.SetItemByID, U.TT, self.item)) then U.TT:SetText(self.tip or "", 1, 1, 1, 1, true)
    elseif self.tip then U.TT:AddLine(self.tip, 0.8, 0.8, 0.8, true) end
    U.TT:Show()
  end)
  r:SetScript("OnLeave", function() U.TT:Hide() end)
  S.rows[i] = r
  return r
end

local function playerDist(r)
  if r.map ~= U.call(C_Map.GetBestMapForUnit, "player") or not U.mapDistance then return "" end
  local p = U.call(C_Map.GetPlayerMapPosition, r.map, "player")
  if not (p and p.GetXY) then return "" end
  local px, py = p:GetXY()
  px, py = U.num(px), U.num(py)
  if not (px and py) then return "" end
  local m, dir = U.mapDistance(r.map, px, py, r.x, r.y)
  return m and (" · " .. U.fmtDistance(m) .. " na " .. dir) or ""
end

-- items: { head = "tytul" } albo { r = wynik, title, sub, icon }
local function render(items, note)
  S.items = items
  local y, n = 4, 0
  for _, it in ipairs(items) do
    n = n + 1
    local b = row(n)
    b:ClearAllPoints()
    b:SetPoint("TOPLEFT", S.child, "TOPLEFT", 0, -y)
    b:SetPoint("TOPRIGHT", S.child, "TOPRIGHT", 0, -y)
    b.bg:SetShown(not it.head)
    U.BorderColor(b, C.line, it.head and 0 or 1)
    b.tip, b.item = it.tip, it.item
    if it.head then
      b:SetHeight(HEAD_H)
      b.r = nil
      b.h:SetText(it.head)
      b.h:Show() b.line:Show()
      b.n:Hide() b.s:Hide() b.ic:Hide()
      b:EnableMouse(false)
      y = y + HEAD_H + 2
    else
      b:SetHeight(ROW_H)
      b.r = it.r
      b.n:SetText(it.title)
      U.Color(b.n, it.col or (it.r.enemy and C.danger or C.gold))
      b.s:SetText(it.sub or "")
      b.ic:SetShown(it.icon ~= nil)
      if it.icon then b.ic:SetTexture(it.icon) end
      b.h:Hide() b.line:Hide()
      b.n:Show() b.s:Show()
      b:EnableMouse(true)
      y = y + ROW_H + 4
    end
    b:Show()
  end
  for i = n + 1, #S.rows do S.rows[i]:Hide() end
  S.note:SetText(note or (n == 0 and "Nic nie znalazłem." or ""))
  S.child:SetHeight(math.max(10, y))
  local maxH = math.max(160, (S.parent:GetHeight() or 600) - 80)
  S.list:SetHeight(math.min(maxH, y + 30))
  S.scroll:SetVerticalScroll(0)
  S.list:Show()
end

local function dirItem(e, gtitle)
  local sub = e.role .. ((e.sub and e.sub ~= "") and (" · <" .. e.sub .. ">") or "")
  return { r = { name = e.name, sub = e.sub, map = e.map, x = e.x, y = e.y, zone = gtitle }, title = e.name,
    sub = sub .. playerDist(e), icon = e.icon }
end

-- puste pole: katalog wg miejsc; tekst: filtr katalogu + cale swiato
local function run(q, auto)
  q = q or S.box:GetText() or ""
  -- 15.11 (gracz: „co gdzie kupic”): tryb Kup (MapaKupWidok.lua): tylko przedmioty i ich kupcy; /npc zawsze zwykle
  if not auto and U.buyOn and U.buyOn() and U.buyRun then return U.buyRun(q) end
  local ql = q:lower():gsub("^%s+", ""):gsub("%s+$", "")
  if not U.serviceDirectory then return end
  U.serviceDirectory(function(groups)
    if (S.box:GetText() or "") ~= q and not auto then return end
    local items, firstR = {}, nil
    for _, g in ipairs(groups) do
      local part = {}
      for _, e in ipairs(g.entries) do
        local hay = (e.name .. " " .. (e.sub or "") .. " " .. (e.role or "")):lower()
        if ql == "" or hay:find(ql, 1, true) then part[#part + 1] = dirItem(e, g.title) end
      end
      if #part > 0 then
        items[#items + 1] = { head = g.title .. (g.here and " · tu jesteś" or "") .. " (" .. #part .. ")" }
        for _, it in ipairs(part) do
          items[#items + 1] = it
          firstR = firstR or it.r
        end
      end
    end
    if #ql < 2 then
      render(items, #items == 0 and "Wczytuję postacie z Questie…" or nil)
      return
    end
    -- 15.11 (R30 P29): najpierw Polestar.Search (MapaSzukajPolestar.lua: postacie, rzadkie, questy, przedmioty, lochy
    -- jako karty); bez Polestara, bez jego bazy albo w walce przed jej wczytaniem: Questie jak dotad
    local psNote
    if U.psSearchRun then
      local ok, done, note = pcall(U.psSearchRun, q, items, { render = render, pick = pick, first = firstR, auto = auto,
        still = function() return auto or (S.box:GetText() or "") == q end,
        close = function() S.box:ClearFocus() hideList() end, rerun = function() run(q, auto) end })
      if ok and done then return end
      psNote = ok and note or nil
    end
    render(items, IDX.names and psNote or "Szukam w całym świecie…")
    withIndex(function()
      if IDX.fail then render(items, "Questie nie podał bazy postaci (wyłączony albo jeszcze się wczytuje).") return end
      if (S.box:GetText() or "") ~= q and not auto then return end
      local seen = {}
      for _, it in ipairs(items) do if it.r then seen[it.r.name] = true end end
      local world = search(q)
      local all = {}
      for _, it in ipairs(items) do all[#all + 1] = it end
      local added = 0
      for _, r in ipairs(world) do
        if not seen[r.name] and added < 40 then
          if added == 0 then all[#all + 1] = { head = "Cały świat" } end
          added = added + 1
          all[#all + 1] = { r = r, title = r.name .. ((r.sub and r.sub ~= "") and ("  <" .. r.sub .. ">") or ""),
            sub = r.zone .. " " .. fmt(r.x) .. " · " .. fmt(r.y) .. playerDist(r) .. (r.enemy and " · wrogi" or "") }
          firstR = firstR or r
        end
      end
      render(all, psNote)
      if auto and firstR then pick(firstR) end
    end)
  end)
end

-- pole szukania w lewym gornym rogu mapy huba (wola TabMapa.lua przy budowie)
function U.mapSearchBuild(parent)
  S.parent = parent
  local box = CreateFrame("EditBox", nil, parent)
  box:SetSize(320, 32)
  box:SetPoint("TOPLEFT", parent, "TOPLEFT", 14, -14)
  box:SetAutoFocus(false)
  box:SetMaxLetters(40)
  box.bg = U.Rect(box, C.bg, 0.9)
  box.bg:SetAllPoints()
  U.Border(box, C.edge)
  box:SetTextInsets(10, 10, 0, 0)
  local font = (U.G.uiFont and U.G.uiFont("body")) or "Fonts\\ARIALN.TTF"
  if not pcall(box.SetFont, box, font, 14, "") then pcall(box.SetFont, box, "Fonts\\ARIALN.TTF", 14, "") end
  box:SetTextColor(C.text[1], C.text[2], C.text[3])
  local ph = U.Text(box, 13, "body", C.faint)
  ph:SetPoint("LEFT", 10, 0)
  ph:SetJustifyV("MIDDLE")
  ph:SetText("Szukaj: postać, przedmiot, quest, loch")
  S.box = box

  local list = CreateFrame("Frame", nil, parent)
  list:SetPoint("TOPLEFT", box, "BOTTOMLEFT", 0, -4)
  list:SetSize(390, 300)
  list.bg = U.Rect(list, C.panel, 0.97)
  list.bg:SetAllPoints()
  U.Border(list, C.edge)
  list:SetFrameLevel(box:GetFrameLevel() + 5)
  list:EnableMouse(true)
  list:Hide()
  S.list = list
  local close = CreateFrame("Button", nil, list)
  close:SetSize(26, 22)
  close:SetPoint("BOTTOMRIGHT", -6, 4)
  local cx = U.Text(close, 13, "title", C.muted)
  cx:SetPoint("CENTER")
  cx:SetText("zamknij")
  close:SetWidth(60)
  close:SetScript("OnClick", function() box:ClearFocus() hideList() end)
  S.note = U.Text(list, 12, "body", C.faint)
  S.note:SetPoint("BOTTOMLEFT", 10, 8)
  local scroll = CreateFrame("ScrollFrame", nil, list)
  scroll:SetPoint("TOPLEFT", 4, -4)
  scroll:SetPoint("BOTTOMRIGHT", -4, 28)
  local child = CreateFrame("Frame", nil, scroll)
  child:SetSize(380, 10)
  scroll:SetScrollChild(child)
  scroll:EnableMouseWheel(true)
  scroll:SetScript("OnMouseWheel", function(self, d)
    local max = math.max(0, child:GetHeight() - self:GetHeight())
    self:SetVerticalScroll(math.max(0, math.min(max, self:GetVerticalScroll() - d * (ROW_H * 2))))
  end)
  S.scroll, S.child = scroll, child

  local pending
  box:SetScript("OnTextChanged", function(self, user)
    ph:SetShown(self:GetText() == "")
    if not user then return end
    pending = (pending or 0) + 1
    local my = pending
    C_Timer.After(0.3, function() if my == pending then run() end end)
  end)
  box:SetScript("OnEnterPressed", function()
    local first
    for _, it in ipairs(S.items or {}) do if it.r then first = it.r break end end
    if first and S.list:IsShown() then
      if first.act then pcall(first.act, "LeftButton") else pick(first) end -- 15.11 (R30 P29): karta z Polestara
    else run() end
  end)
  box:SetScript("OnEscapePressed", function(self)
    self:ClearFocus()
    hideList()
  end)
  box:SetScript("OnEditFocusGained", function() run() end)
  box:SetScript("OnMouseDown", function(self) if not self:HasFocus() then self:SetFocus() end end)
  local api = { render = render, run = function() run() end, close = function() box:ClearFocus() hideList() end }
  if U.mapBuyBuild then pcall(U.mapBuyBuild, box, ph, api) end -- 15.11: przelacznik „Kup” i skroty (MapaKupWidok.lua)
  return box
end

-- /npc nazwa: hub na Mapie i od razu strzalka do najlepszego wyniku
SLASH_GRIMUARNPC1 = "/npc"
SlashCmdList.GRIMUARNPC = function(msg)
  msg = (msg or ""):gsub("^%s+", ""):gsub("%s+$", "")
  if not U.Open("mapa") then return end
  if not S.box then return end
  S.box:SetText(msg)
  if msg == "" then S.box:SetFocus() return end
  run(msg, true)
end
