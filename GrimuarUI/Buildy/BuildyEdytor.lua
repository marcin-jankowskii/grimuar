-- Grimuar UI: edytor buildu (R27 E4, 14.11; takze kopie szkicow Polestara). Bez Lua, tylko pola i przyciski:
-- nazwa i opis, plan talentow (odcinki: talent i liczba punktow; w gore, w dol, +1, −1, usun, dodaj z listy talentow
-- klasy z Polestara), „Zapisz moje talenty” (obecne talenty z gry, w kolejnosci rzedow), „Nagrywaj” (kazdy wydany punkt
-- dopisuje sie na koncu planu), trener: AoE tak/nie, porady PvP dla klas wroga. Zapis: G.SaveOwnBuild (walidacja).
-- Poziomy liczone same: punkt n = poziom 9 + n (pierwszy talent na 10).
-- 15.11 (gracz: „in game powinna byc mozliwosc przerabiania i edytowania buildow”): zakladki sekcji Talenty, Trener,
-- Paski, Combo, Kolo, Makra, Porady (pozostale w EdytorSekcje.lua); praca na kopii roboczej (zamkniecie bez zapisu nic
-- nie zmienia), przy zapisie makra z /run itp. sa odrzucane z komunikatem.
local ADDON, U = ...
local C = U.C
local G = U.G or {}

local E = { rows = {}, sec = "talenty" }
local X = U.ED or {}
U.ED = X
local function deepcopy(v)
  if type(v) ~= "table" then return v end
  local o = {}
  for k, x in pairs(v) do o[k] = deepcopy(x) end
  return o
end
local CLASSES = { "WARRIOR", "PALADIN", "HUNTER", "ROGUE", "PRIEST", "SHAMAN", "MAGE", "WARLOCK", "DRUID" }

local function PT() local P = _G.Polestar return P and P.Talents end
local function pdata(cls)
  local T = PT()
  if not (T and T.Data) then return nil end
  local ok, d = pcall(T.Data, cls)
  return ok and d or nil
end
local function maxRank(cls, name)
  local d = pdata(cls)
  for _, n in pairs(d and d.nodes or {}) do if n[7] == name then return n[2] end end
  return nil
end

-- plan <-> odcinki { name, pts, max }
local function toSegs(plan)
  local segs = {}
  for _, p in ipairs(plan or {}) do segs[#segs + 1] = { name = p[1], pts = (p[3] - p[2] + 1), max = p[4] } end
  return segs
end
local function toPlan(segs)
  local plan, lvl = {}, 10
  for _, s in ipairs(segs) do
    if s.pts > 0 then
      plan[#plan + 1] = { s.name, lvl, lvl + s.pts - 1, s.max or s.pts }
      lvl = lvl + s.pts
    end
  end
  return plan, lvl - 10
end

local function save()
  if not E.b then return end
  local plan, total = toPlan(E.segs)
  if total > 51 then U.say("za dużo punktów: " .. total .. " (na 60 jest 51).") return end
  E.b.talents = E.b.talents or {}
  E.b.talents.plan = plan
  E.b.talents.from = nil
  E.b.name = { pl = E.name:GetText(), en = E.name:GetText() }
  E.b.desc = { pl = E.desc:GetText(), en = (type(E.b.desc) == "table" and E.b.desc.en) or E.desc:GetText() }
  -- makra: te same zasady co import (G.CleanBuild: bez /run, /script, /console, /dump, limity)
  if G.CleanBuild and E.b.macros then
    local clean, problems = G.CleanBuild(E.b)
    if clean and clean.macros then
      local dropped = #E.b.macros - #clean.macros
      E.b.macros = clean.macros
      if dropped > 0 then U.say("odrzucone makra: " .. dropped .. " (" .. table.concat(problems or {}, "; ") .. ").") end
    end
  end
  E.b.version = (tonumber(E.b.version) or 1) + (E.dirty and 1 or 0)
  local ok, err = G.SaveOwnBuild(E.b)
  if ok then
    U.say("build zapisany: " .. E.name:GetText() .. ".")
    E.dirty = false
    E.b = deepcopy(E.b)
    X.b = E.b
  else U.say("nie zapisano: " .. tostring(err)) end
  if U.buildyRefresh then U.buildyRefresh() end
end

-- obecne talenty z gry (Polestar.Talents.Read): punkty w kolejnosci rzedow drzewa
local function fromLive()
  local T, d = PT(), pdata(E.b and E.b.class)
  if not (T and T.Read and d) then U.say("odczyt talentów potrzebuje Polestara.") return end
  local ok, live = pcall(T.Read, d)
  if not ok or not live then U.say("gra nie podała talentów (otwórz okno talentów raz).") return end
  local list = {}
  for id, n in pairs(live.nodes or {}) do
    local meta = d.nodes and d.nodes[id]
    if (n.active or 0) > 0 and meta then list[#list + 1] = { name = n.name or meta[7], pts = n.active, max = meta[2], row = meta[5], col = meta[6], tree = meta[4] } end
  end
  table.sort(list, function(a, b) if a.row ~= b.row then return a.row < b.row end if a.tree ~= b.tree then return a.tree < b.tree end return a.col < b.col end)
  E.segs = {}
  for _, s in ipairs(list) do E.segs[#E.segs + 1] = { name = s.name, pts = s.pts, max = s.max } end
  E.dirty = true
  U.say("plan talentów z Twoich obecnych talentów: " .. #E.segs .. " talentów. Kolejność: rzędami, popraw strzałkami.")
end

-- nagrywanie: kazdy nowy punkt w grze dopisuje sie do planu
local rec = CreateFrame("Frame")
local function snapshot()
  local T, d = PT(), pdata(E.b and E.b.class)
  if not (T and T.Read and d) then return nil end
  local ok, live = pcall(T.Read, d)
  if not ok or not live then return nil end
  local s = {}
  for id, n in pairs(live.nodes or {}) do s[id] = { n.active or 0, n.name or (d.nodes[id] and d.nodes[id][7]), d.nodes[id] and d.nodes[id][2] } end
  return s
end
rec:SetScript("OnEvent", function()
  if not (E.recording and E.b) then return end
  C_Timer.After(0.3, function()
    local now = snapshot()
    if not now or not E.snap then E.snap = now return end
    for id, n in pairs(now) do
      local was = E.snap[id] and E.snap[id][1] or 0
      for _ = was + 1, n[1] do
        local last = E.segs[#E.segs]
        if last and last.name == n[2] then last.pts = last.pts + 1 else E.segs[#E.segs + 1] = { name = n[2], pts = 1, max = n[3] } end
        U.say("nagrano: " .. tostring(n[2]) .. ".")
      end
    end
    E.snap = now
    E.dirty = true
    pcall(U.buildEditorRefresh)
  end)
end)
for _, e in ipairs({ "TRAIT_NODE_CHANGED", "TRAIT_CONFIG_UPDATED", "CHARACTER_POINTS_CHANGED", "PLAYER_TALENT_UPDATE" }) do pcall(rec.RegisterEvent, rec, e) end

-- ---------- uklad ----------
local function segRow(i)
  local r = E.rows[i]
  if r then return r end
  r = CreateFrame("Frame", nil, E.list)
  r:SetHeight(26)
  r.t = U.Text(r, 13, "body", C.text) r.t:SetPoint("LEFT", 4, 0) r.t:SetWidth(300)
  local x = -2
  r.b = {}
  for _, d in ipairs({ { "×", "del" }, { "–", "minus" }, { "+", "plus" }, { "Niżej", "down" }, { "Wyżej", "up" } }) do
    local bw = (#d[1] > 3) and 60 or 26
    local b = U.Button(r, d[1], bw, 22)
    b:SetPoint("RIGHT", r, "RIGHT", x, 0)
    x = x - bw - 4
    b:SetScript("OnClick", function()
      local s, segs = r.i, E.segs
      if d[2] == "del" then table.remove(segs, s)
      elseif d[2] == "plus" then segs[s].pts = math.min(segs[s].max or 5, segs[s].pts + 1)
      elseif d[2] == "minus" then segs[s].pts = math.max(1, segs[s].pts - 1)
      elseif d[2] == "up" and s > 1 then segs[s], segs[s - 1] = segs[s - 1], segs[s]
      elseif d[2] == "down" and s < #segs then segs[s], segs[s + 1] = segs[s + 1], segs[s] end
      E.dirty = true
      U.buildEditorRefresh()
    end)
    r.b[d[2]] = b
  end
  E.rows[i] = r
  return r
end

-- sekcje: Talenty tutaj, reszta z EdytorSekcje.lua (X.secs)
local function showSection(key)
  E.sec = key
  local tal = key == "talenty"
  for _, w in ipairs(E.talW or {}) do w:SetShown(tal) end
  for k, s in pairs(X.secs or {}) do
    if k == key and not s.frame then s.frame = s.build(E.host) end
    if s.frame then s.frame:SetShown(k == key) end
  end
  for k, b in pairs(E.tabs or {}) do
    U.Color(b.label, k == key and C.gold or C.muted)
    U.BorderColor(b, k == key and C.gold or C.edge)
  end
  if X.hidePicker then X.hidePicker() end
  if not tal and X.secs[key] then pcall(X.secs[key].draw) end
  pcall(U.buildEditorRefresh)
end

function U.buildEditorRefresh()
  if not (E.f and E.f:IsShown() and E.b) then return end
  E.state:SetText(E.dirty and "niezapisane zmiany" or "zapisane")
  U.Color(E.state, E.dirty and C.gold or C.faint)
  if E.sec ~= "talenty" then return end
  local plan, total = toPlan(E.segs)
  E.sum:SetText("Punkty: " .. total .. " / 51" .. (E.recording and "   · NAGRYWAM" or "") .. (E.dirty and "   · niezapisane zmiany" or ""))
  U.Color(E.sum, total > 51 and C.danger or (E.recording and C.gold or C.muted))
  local w = math.max(300, (E.list:GetParent():GetWidth() or 500) - 10)
  for i, s in ipairs(E.segs) do
    local r = segRow(i)
    r.i = i
    r:SetWidth(w)
    r:ClearAllPoints() r:SetPoint("TOPLEFT", E.list, "TOPLEFT", 0, -(i - 1) * 28)
    local p = plan[i]
    r.t:SetText((p and ((p[2] == p[3]) and p[2] or (p[2] .. "–" .. p[3])) or "?") .. "   " .. s.name .. "  " .. U.hex(C.muted) .. s.pts .. "/" .. (s.max or "?") .. "|r")
    r:Show()
  end
  for i = #E.segs + 1, #E.rows do E.rows[i]:Hide() end
  E.list:SetHeight(math.max(10, #E.segs * 28))
  E.rec:SetLabel(E.recording and "Zatrzymaj nagrywanie" or "Nagrywaj")
end

function U.buildEditorOpen(id, sec)
  local b = G.GetBuild(id)
  if not b or (b.src ~= "moje" and b.src ~= "import") then U.say("edytujesz kopię: najpierw „Duplikuj do edycji”.") return end
  E.b = deepcopy(b)
  X.b = E.b
  E.segs = toSegs(b.talents and b.talents.plan)
  if #E.segs == 0 and b.talents and b.talents.picks then E.segs = toSegs(G.picksToPlan(b.class, b.talents.picks)) end
  E.dirty, E.recording = false, false
  E.name:SetText(G.BT(b.name) or b.id)
  E.desc:SetText(G.BT(b.desc) or "")
  E.f:Show()
  E.det:Hide()
  for _, s in pairs(X.secs or {}) do if s.frame then s.frame:Hide() end end
  showSection(X.secs[sec or ""] and sec or "talenty")
end
local function close()
  if E.dirty then U.say("masz niezapisane zmiany: kliknij Zapisz albo Zamknij jeszcze raz (zamknięcie porzuci zmiany).") E.dirty = false return end
  E.recording = false
  if X.hidePicker then X.hidePicker() end
  E.f:Hide()
  E.det:Show()
  E.b, X.b = nil, nil
  if U.buildyRefresh then pcall(U.buildyRefresh) end
end

function U.buildEditorBuild(page, det)
  E.det = det
  local f = U.Panel(page, 0.92, true)
  f:SetAllPoints(det)
  f:Hide()
  E.f = f
  X.f = f
  X.markDirty = function() E.dirty = true pcall(U.buildEditorRefresh) end
  local h = U.H2(f, "Edycja buildu") h:SetPoint("TOPLEFT", 18, -14)
  E.state = U.Text(f, 12, "body", C.faint)
  E.state:SetPoint("LEFT", h, "RIGHT", 14, 0)
  local function edit(w, anchor, dy)
    local e = CreateFrame("EditBox", nil, f, "InputBoxTemplate")
    e:SetSize(w, 26) e:SetAutoFocus(false)
    e:SetPoint("TOPLEFT", anchor, "BOTTOMLEFT", anchor == h and 6 or 0, dy)
    e:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
    e:SetScript("OnEnterPressed", function(self) self:ClearFocus() end)
    e:SetScript("OnTextChanged", function(_, user) if user then E.dirty = true end end)
    return e
  end
  E.name = edit(420, h, -14)
  E.desc = edit(560, E.name, -8)
  -- zakladki sekcji
  E.tabs = {}
  local tprev
  local secs = { { "talenty", "Talenty" } }
  local extra = {}
  for k, s in pairs(X.secs or {}) do extra[#extra + 1] = { k, s.title, s.order or 9 } end
  table.sort(extra, function(a, c) return a[3] < c[3] end)
  for _, s in ipairs(extra) do secs[#secs + 1] = s end
  for _, s in ipairs(secs) do
    local tb = U.Button(f, s[2], nil, 26)
    if tprev then tb:SetPoint("LEFT", tprev, "RIGHT", 4, 0) else tb:SetPoint("TOPLEFT", E.desc, "BOTTOMLEFT", -6, -12) end
    tb:SetScript("OnClick", function() showSection(s[1]) end)
    E.tabs[s[1]] = tb
    tprev = tb
  end
  local bar = CreateFrame("Frame", nil, f)
  bar:SetSize(10, 28) bar:SetPoint("TOPLEFT", E.tabs.talenty, "BOTTOMLEFT", 0, -10)
  local prev
  local function b(text, fn, primary)
    local x = U.Button(f, text, nil, 26, primary)
    if prev then x:SetPoint("LEFT", prev, "RIGHT", 6, 0) else x:SetPoint("LEFT", bar, "LEFT", 0, 0) end
    x:SetScript("OnClick", function() local ok, e = pcall(fn) if not ok and U.logError then U.logError("edytor", e) end pcall(U.buildEditorRefresh) end)
    prev = x
    return x
  end
  b("Zapisz", save, true)
  b("Zamknij", close)
  E.talW = {}
  E.talW[#E.talW + 1] = b("Zapisz moje talenty", fromLive)
  E.rec = b("Nagrywaj", function()
    E.recording = not E.recording
    E.snap = E.recording and snapshot() or nil
    U.say(E.recording and "nagrywam: każdy wydany punkt talentu dopisze się na końcu planu." or "nagrywanie zatrzymane.")
  end)
  E.talW[#E.talW + 1] = E.rec
  -- dodawanie talentu: lista talentow klasy z Polestara (drzewko, rzad), klik dodaje na koniec planu
  E.add = b("+ talent", function()
    local d = pdata(E.b.class)
    if not d then U.say("lista talentów potrzebuje Polestara; możesz użyć „Zapisz moje talenty”.") return end
    if not E.picker then
      local pk = U.Panel(f, 0.98, true, C.gold)
      pk:SetPoint("TOPRIGHT", f, "TOPRIGHT", -16, -60)
      pk:SetSize(320, 420)
      pk:SetFrameLevel(f:GetFrameLevel() + 20)
      pk.h = U.Label(pk, "Wybierz talent")
      pk.h:SetPoint("TOPLEFT", 12, -10)
      local x = U.Button(pk, "×", 24, 22)
      x:SetPoint("TOPRIGHT", -8, -6)
      x:SetScript("OnClick", function() pk:Hide() end)
      local v = CreateFrame("ScrollFrame", nil, pk)
      v:SetPoint("TOPLEFT", 10, -34) v:SetPoint("BOTTOMRIGHT", -10, 10)
      pk.list = CreateFrame("Frame", nil, v) pk.list:SetSize(290, 10)
      v:SetScrollChild(pk.list)
      v:EnableMouseWheel(true)
      v:SetScript("OnMouseWheel", function(self, dd)
        local max = math.max(0, pk.list:GetHeight() - self:GetHeight())
        self:SetVerticalScroll(math.max(0, math.min(max, self:GetVerticalScroll() - dd * 66)))
      end)
      pk.rows = {}
      E.picker = pk
    end
    local pk = E.picker
    local names = {}
    for _, n in pairs(d.nodes or {}) do names[#names + 1] = { n[7], n[2], n[4], n[5] } end
    table.sort(names, function(a, c) if a[3] ~= c[3] then return a[3] < c[3] end if a[4] ~= c[4] then return a[4] < c[4] end return a[1] < c[1] end)
    for i, n in ipairs(names) do
      local r = pk.rows[i]
      if not r then
        r = U.Button(pk.list, "", 288, 22)
        pk.rows[i] = r
      end
      r:ClearAllPoints() r:SetPoint("TOPLEFT", pk.list, "TOPLEFT", 0, -(i - 1) * 24)
      r:SetLabel((d.specs and d.specs[n[3]] or ("drzewko " .. n[3])) .. " " .. n[4] .. ": " .. n[1] .. " (" .. n[2] .. ")")
      r:SetScript("OnClick", function()
        E.segs[#E.segs + 1] = { name = n[1], pts = 1, max = n[2] }
        E.dirty = true
        pk:Hide()
        pcall(U.buildEditorRefresh)
      end)
      r:Show()
    end
    for i = #names + 1, #pk.rows do pk.rows[i]:Hide() end
    pk.list:SetHeight(#names * 24)
    pk:Show()
  end)
  E.talW[#E.talW + 1] = E.add
  E.sum = U.Text(f, 12, "body", C.muted)
  E.sum:SetPoint("TOPLEFT", bar, "BOTTOMLEFT", 6, -10)
  E.talW[#E.talW + 1] = E.sum
  -- miejsce na pozostale sekcje (pod przyciskami Zapisz / Zamknij)
  E.host = CreateFrame("Frame", nil, f)
  E.host:SetPoint("TOPLEFT", bar, "BOTTOMLEFT", 6, -10)
  E.host:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -16, 14)
  local view = CreateFrame("ScrollFrame", nil, f)
  view:SetPoint("TOPLEFT", E.sum, "BOTTOMLEFT", 0, -8)
  view:SetPoint("BOTTOMRIGHT", -16, 14)
  E.talW[#E.talW + 1] = view
  E.list = CreateFrame("Frame", nil, view)
  E.list:SetSize(500, 10)
  view:SetScrollChild(E.list)
  view:EnableMouseWheel(true)
  view:SetScript("OnMouseWheel", function(self, d)
    local max = math.max(0, E.list:GetHeight() - self:GetHeight())
    self:SetVerticalScroll(math.max(0, math.min(max, self:GetVerticalScroll() - d * 84)))
  end)
  local _ = CLASSES
end
