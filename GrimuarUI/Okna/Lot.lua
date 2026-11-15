-- Grimuar UI: Mistrz lotow w stylu huba (15.11; gracz: „okna gry, ktore jeszcze nie sa w stylu Grimuara: Mistrz lotow
-- i Handel”). Zamiast mapy lotow gry (TaxiFrame; nowszy klient: FlightMapFrame) okno Grimuara przyczepione i wieksze,
-- wiec ja przykrywa (Okna/Wspolne.lua: mapa gry dostaje tylko przezroczystosc 0, jej zamkniecie konczy wizyte).
-- Karty celow: miejsce, strefa, koszt (monety jak u Kupca), czas lotu i przesiadki (GetNumRoutes). Czas: Polestar
-- (Maps.FlightSeconds: Twoj zapamietany lot albo szacunek z danych podrozy, wtedy „~”), bez niego czas zapamietany przez
-- Grimuara po wyladowaniu (Hud/Lot.lua, GrimuarUIDB.lotyCzas). Kolejnosc: najpierw cel prowadzenia (wezel, ktory Polestar
-- zaznacza na mapie lotow: QoL.Flight; inaczej, gdy strzalka prowadzi (Nav.API.Active), wezel najblizej jej celu albo
-- w strefie celu), potem najblizsze od miejsca, w ktorym stoisz. Niedostepne (TaxiNodeGetType ~= "REACHABLE") szare
-- na koncu. Klik w karte = TakeTaxiNode (zwykla funkcja gry, jak klik na mapie). Pole szukania: miejsce albo strefa.
-- Wylaczenie: /hub okna lot (wraca mapa gry). Dane mapy lotow: Okna/LotDane.lua.
local ADDON, U = ...
local C = U.C
local G = U.G or {}

local W, H, CARD_H, GAP = 820, 600, 56, 8
local ICON = 132057 -- Interface\GossipFrame\TaxiGossipIcon: ta sama ikona lotu co w rozmowie z mistrzem lotow
local S = { q = "", cards = {}, heads = {}, nc = 0, nh = 0, y = 0, W = 400, have = 0 }
local F

local function money(c) return U.money and U.money(c) or tostring(c) end
local function tr(s) return G.tr and G.tr(s) or s end
local function str(v)
  if type(v) ~= "string" or (issecretvalue and issecretvalue(v)) then return nil end
  return v
end
local function plural(n, one, few, many)
  if n == 1 then return one end
  local d, h = n % 10, n % 100
  if d >= 2 and d <= 4 and (h < 12 or h > 14) then return few end
  return many
end

local L = U.lot -- dane mapy lotow, cel prowadzenia i czas lotu (Okna\LotDane.lua)

-- ---------- rysowanie ----------
local function fly(n)
  if n.kind ~= "REACHABLE" then U.say(tr("ten lot jest niedostępny stąd") .. ": " .. n.place .. ".") return end
  if n.cost > S.have then U.say(tr("za mało pieniędzy na lot") .. ": " .. n.place .. " (" .. money(n.cost) .. ").") return end
  if not pcall(TakeTaxiNode, n.i) then U.say(tr("gra nie pozwoliła polecieć: wybierz cel w klasycznym oknie.")) end
end

local function cardData(n, cur, how)
  local sec, est = L.seconds(cur, n)
  local sub, tip = {}, { n.name }
  if how == "guide" and S.why then sub[#sub + 1] = tr(S.why) end
  if n.zone then sub[#sub + 1] = n.zone end
  if how == "off" then
    local why = tr(n.kind == "DISTANT" and "brak połączenia stąd" or "jeszcze nie odkryty")
    sub[#sub + 1] = why
    tip[#tip + 1] = why
  else
    if sec then
      local t = tr((est and "~" or "") .. U.lotTime(sec) .. " lotu")
      sub[#sub + 1] = t
      tip[#tip + 1] = t .. " (" .. tr(est and "szacunek Polestara" or "zapamiętany lot") .. ")"
    end
    if n.legs and n.legs > 0 then
      local k = n.legs - 1
      local hop = tr(k == 0 and "bez przesiadek" or (k .. " " .. plural(k, "przesiadka", "przesiadki", "przesiadek")))
      sub[#sub + 1] = hop
      tip[#tip + 1] = hop
    end
    tip[#tip + 1] = tr("Klik: leć") .. (n.cost > 0 and (" (" .. money(n.cost) .. ")") or "")
  end
  return {
    title = n.place, sub = table.concat(sub, " · "), icon = ICON, tip = table.concat(tip, "\n"),
    right = how == "off" and tr("niedostępny") or (n.cost > 0 and money(n.cost) or ""),
    rightCol = how == "guide" and C.gold or (how == "off" and C.faint or (n.cost > S.have and C.danger or C.text)),
    col = how == "guide" and C.gold or (how == "off" and C.faint or nil),
    onClick = function() fly(n) end,
  }
end

local function takeCard()
  S.nc = S.nc + 1
  local f = S.cards[S.nc]
  if not f then f = U.Card(F.child) S.cards[S.nc] = f end
  f:ClearAllPoints()
  f:Show()
  return f
end
local function head(text)
  if S.y > 0 then S.y = S.y + 10 end
  S.nh = S.nh + 1
  local h = S.heads[S.nh]
  if not h then
    h = CreateFrame("Frame", nil, F.child)
    h:SetHeight(22)
    h.d = U.Diamond(h, 10, C.gold, true) h.d:SetPoint("LEFT", 0, 0)
    h.t = U.Text(h, 14, "title", C.gold) h.t:SetPoint("LEFT", h.d, "RIGHT", 7, 0) h.t:SetJustifyV("MIDDLE")
    h.l = U.Line(h, C.edge, 0.5) h.l:SetPoint("LEFT", h.t, "RIGHT", 10, 0) h.l:SetPoint("RIGHT", h, "RIGHT", 0, 0)
    S.heads[S.nh] = h
  end
  h:ClearAllPoints()
  h:SetPoint("TOPLEFT", F.child, "TOPLEFT", 0, -S.y)
  h:SetWidth(S.W)
  h.t:SetText(text)
  h:Show()
  S.y = S.y + 30
end
local function place(list, cols, cur, how)
  local cw = math.floor((S.W - GAP * (cols - 1)) / cols)
  for k, n in ipairs(list) do
    local f = takeCard()
    local col, row = (k - 1) % cols, math.floor((k - 1) / cols)
    f:SetPoint("TOPLEFT", F.child, "TOPLEFT", col * (cw + GAP), -(S.y + row * (CARD_H + GAP)))
    f:Fill(cardData(n, cur, how), cw, CARD_H)
    -- niedostepne: wyszarzone (Fill ustawia kolory od nowa przy kazdym rysowaniu)
    f.ic:SetAlpha(how == "off" and 0.55 or 1)
    if how == "off" then U.Color(f.t, C.faint) pcall(f.ic.SetDesaturated, f.ic, true) end
  end
  S.y = S.y + math.ceil(#list / cols) * (CARD_H + GAP)
end

local function render()
  S.nc, S.nh, S.y = 0, 0, 0
  S.W = math.max(300, math.floor((F.view:GetWidth() or (W - 44)) - 4))
  F.child:SetWidth(S.W)
  S.have = U.num(U.call(GetMoney)) or 0
  local list, cur = L.nodes()
  local q = (S.q or ""):lower()
  local gs, why = L.guide(list, cur)
  S.why = why
  local guide, near, off = nil, {}, {}
  for _, n in ipairs(list) do
    n.d = L.dist(cur, n)
    if n.kind ~= "CURRENT" and (q == "" or n.name:lower():find(q, 1, true)) then
      if n.kind == "REACHABLE" and n.i == gs then guide = n
      elseif n.kind == "REACHABLE" then near[#near + 1] = n
      else off[#off + 1] = n end
    end
  end
  local function byD(a, b)
    local da, dc = a.d or 1e12, b.d or 1e12
    if da ~= dc then return da < dc end
    return a.name < b.name
  end
  table.sort(near, byD)
  table.sort(off, byD)
  if guide then head("Cel prowadzenia") place({ guide }, 1, cur, "guide") end
  if #near > 0 then head(q ~= "" and "Znalezione" or "Najbliższe") place(near, 2, cur, "near") end
  if #off > 0 then head("Niedostępne") place(off, 2, cur, "off") end
  for i = S.nc + 1, #S.cards do S.cards[i]:Hide() end
  for i = S.nh + 1, #S.heads do S.heads[i]:Hide() end
  F.child:SetHeight(math.max(10, S.y + 10))
  F.empty:SetShown(S.nc == 0)
  F.empty:SetText(q ~= "" and "Nic nie pasuje do szukania." or "Mapa lotów jest pusta.")
  F.foot:SetText(tr("Lecisz z") .. ": " .. (cur and cur.name or "?") .. "   ·   " .. tr("pieniądze") .. ": " .. money(S.have))
  return #list, guide and guide.place or nil
end

function U.lotDraw()
  if not (F and F:IsShown()) then return end
  local ok, err = pcall(function()
    F.title:SetText(str(U.call(UnitName, "npc")) or "Mistrz lotów")
    local zone = str(U.call(GetSubZoneText))
    F.sub:SetText((zone and zone ~= "") and zone or (str(U.call(GetZoneText)) or ""))
    render()
  end)
  if not ok then F:Fail(err) end
end

local function build()
  if F then return end
  F = U.Okno({ name = "GrimuarLot", width = W, height = H, title = "Mistrz lotów", key = "lot",
    hosts = { "TaxiFrame", "FlightMapFrame" }, onClose = function() U.call(CloseTaxiMap) end })
  -- pole szukania (styl jak szukanie na mapie huba, Mapa\MapaSzukaj.lua)
  local box = CreateFrame("EditBox", nil, F)
  box:SetSize(300, 28)
  box:SetPoint("TOPLEFT", 22, -56)
  box:SetAutoFocus(false)
  box:SetMaxLetters(40)
  box.bg = U.Rect(box, C.bg, 0.9) box.bg:SetAllPoints()
  U.Border(box, C.edge)
  box:SetTextInsets(10, 10, 0, 0)
  local font = (G.uiFont and G.uiFont("body")) or "Fonts\\ARIALN.TTF"
  if not pcall(box.SetFont, box, font, 14, "") then pcall(box.SetFont, box, "Fonts\\ARIALN.TTF", 14, "") end
  box:SetTextColor(C.text[1], C.text[2], C.text[3])
  local ph = U.Text(box, 13, "body", C.faint)
  ph:SetPoint("LEFT", 10, 0)
  ph:SetJustifyV("MIDDLE")
  ph:SetText("Szukaj: miejsce albo strefa")
  box:SetScript("OnTextChanged", function(self)
    S.q = self:GetText() or ""
    ph:SetShown(S.q == "")
    U.lotDraw()
  end)
  box:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
  box:SetScript("OnEnterPressed", function(self) self:ClearFocus() end)
  F.search = box
  local hint = U.Text(F, 11, "body", C.faint)
  hint:SetPoint("LEFT", box, "RIGHT", 14, 0)
  hint:SetText("klik w kartę: leć · najedź: szczegóły · szare: niedostępne")
  -- karty
  F.view = CreateFrame("ScrollFrame", nil, F)
  F.view:SetPoint("TOPLEFT", 22, -98)
  F.view:SetPoint("BOTTOMRIGHT", -22, 40)
  F.child = CreateFrame("Frame", nil, F.view)
  F.child:SetSize(W - 44, 10)
  F.view:SetScrollChild(F.child)
  F.view:EnableMouseWheel(true)
  F.view:SetScript("OnMouseWheel", function(self, d)
    local max = math.max(0, F.child:GetHeight() - self:GetHeight())
    self:SetVerticalScroll(math.max(0, math.min(max, self:GetVerticalScroll() - d * 80)))
  end)
  F.empty = U.Text(F.child, 13, "body", C.muted)
  F.empty:SetPoint("TOPLEFT", 0, -4)
  F.empty:Hide()
  F.foot = U.Text(F, 12, "body", C.muted)
  F.foot:SetPoint("BOTTOMLEFT", 24, 14)
end

local ev = CreateFrame("Frame")
for _, e in ipairs({ "TAXIMAP_OPENED", "TAXIMAP_CLOSED", "PLAYER_MONEY" }) do pcall(ev.RegisterEvent, ev, e) end
ev:SetScript("OnEvent", function(_, e)
  if e == "TAXIMAP_OPENED" then
    C_Timer.After(0.05, function()
      build()
      pcall(function()
        local host = (_G.TaxiFrame and _G.TaxiFrame:IsShown()) and "TaxiFrame" or ((_G.FlightMapFrame and _G.FlightMapFrame:IsShown()) and "FlightMapFrame" or "brak")
        U.diag("lot", { n = U.num(U.call(NumTaxiNodes)), first = U.raw(TaxiNodeName, 1), kind = U.raw(TaxiNodeGetType, 1),
          pos = U.raw(TaxiNodePosition, 1), routes = U.raw(GetNumRoutes, 1), map = tostring(U.call(GetTaxiMapID)),
          cmap = (C_TaxiMap and C_TaxiMap.GetAllTaxiNodes) and "C_TaxiMap" or "brak", host = host })
      end)
      F.search:SetText("")
      S.q = ""
      L.reset()
      F.view:SetVerticalScroll(0)
      if F:Open() then
        U.lotDraw()
        -- znacznik Polestara powstaje klatke po otwarciu mapy: jeszcze raz po chwili
        C_Timer.After(0.4, U.lotDraw)
      end
    end)
  elseif e == "TAXIMAP_CLOSED" then
    if F then F.search:ClearFocus() F:Finish() end
  elseif F and F:IsShown() then
    C_Timer.After(0.2, U.lotDraw)
  end
end)

-- ---------- /gr test ----------
U.testChecksExtra = U.testChecksExtra or {}
table.insert(U.testChecksExtra, { "okno lotów (mistrz lotów)", function()
  local miss = {}
  for _, n in ipairs({ "NumTaxiNodes", "TaxiNodeName", "TaxiNodeGetType", "TaxiNodeCost", "TaxiNodePosition", "TakeTaxiNode",
    "GetNumRoutes", "CloseTaxiMap" }) do
    if type(_G[n]) ~= "function" then miss[#miss + 1] = n end
  end
  if #miss > 0 then error("brak w kliencie: " .. table.concat(miss, ", ")) end
  local ok, err = pcall(build)
  if not ok then error("budowa okna: " .. tostring(err)) end
  local okR, n = pcall(render)
  if not okR then error("rysowanie: " .. tostring(n)) end
  local fail = U.db().oknaFails and U.db().oknaFails.lot
  if fail and U.version and fail.version == U.version() then error("wywróciło się " .. tostring(fail.at) .. ": " .. tostring(fail.err)) end
  local P = _G.Polestar
  local src = (type(P) == "table" and type(P.Maps) == "table" and type(P.Maps.FlightSeconds) == "function") and "Polestar.Maps.FlightSeconds"
    or "bez Polestara: przesiadki i czasy zapamiętane przez Grimuara"
  local mark = (type(P) == "table" and type(P.QoL) == "table" and type(P.QoL.Flight) == "table") and "znacznik Polestara (QoL.Flight)" or "cel strzałki"
  local d = U.db().diag and U.db().diag.lot
  return (U.oknoOn("lot") and "włączone" or "mapa gry (/hub okna lot)") .. ", czas: " .. src .. ", cel prowadzenia: " .. mark ..
    (d and (", dane z " .. tostring(d.at) .. ": " .. tostring(d.n) .. " węzłów, " .. tostring(d.cmap)) or ", mistrz lotów jeszcze nie odwiedzony")
end })
