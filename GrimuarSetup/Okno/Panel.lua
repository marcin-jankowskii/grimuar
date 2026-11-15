-- Grimuar: modul Panel (wspolne funkcje przez tabele G z innych modulow).
local ADDON_NAME, G = ...
local C_FROST = G.C_FROST
local C_GOLD = G.C_GOLD
local C_MUTED = G.C_MUTED
local C_OK = G.C_OK
local C_WARN = G.C_WARN
local DUNGEONS = G.DUNGEONS
local FONT = G.FONT
local GLOSSARY = G.GLOSSARY
local GUIDE = G.GUIDE
local QUESTS = G.QUESTS
local S = G.S
local SPELLS = G.SPELLS
local STAGES = G.STAGES
local TALENT_AT = G.TALENT_AT
local TALENT_NOTE_AT = G.TALENT_NOTE_AT
local W = 430 -- szerokosc tresci w nowym oknie z bocznym menu
local FlatButton, FitButton, StyledWindow, Divider = G.FlatButton, G.FitButton, G.StyledWindow, G.Divider
local STYLE, setBackdrop = G.STYLE, G.setBackdrop
local bookDone = G.bookDone
local buildSteps = G.buildSteps
local charKey = G.charKey
local clearGuide = G.clearGuide
local enableGatherTracking = G.enableGatherTracking
local guideTo = G.guideTo
local openTalents = G.openTalents
local say = G.say
local setBudget = G.setBudget
local showToast = G.showToast
local skipped = G.skipped
local tempoLine = G.tempoLine
local updateHUD = G.updateHUD

-- Czesc wydzielona z Panel.lua (podzial plikow >1000 linii, 12.11).
local buildAddony = G.buildAddony
local buildCzary = G.buildCzary
local buildDungeony = G.buildDungeony
local buildMapa = G.buildMapa
local buildPlan = G.buildPlan
local buildPodstawy = G.buildPodstawy
local buildProfesje = G.buildProfesje
local buildPvP = G.buildPvP
local buildSamouczek = G.buildSamouczek
local buildSlownik = G.buildSlownik
local buildSprzet = G.buildSprzet
local buildTalenty = G.buildTalenty
local buildTeraz = G.buildTeraz
local buildWalka = G.buildWalka

-- ============================================================
-- OKNO "GRIMUAR MAGA"
-- ============================================================
local panel, scroll, content
local tabButtons = {}
local fsPool, cbPool, btnPool, rowPool, linePool = {}, {}, {}, {}, {}
local R = { y = 0, fi = 0, ci = 0, bi = 0, ri = 0, li = 0 }
local TUT_REF = {} -- uzupelniane przez samouczek (chapters, start)
local currentTab = "teraz"

local function stageFor(l)
  for _, s in ipairs(STAGES) do
    if l >= s.from and l <= s.to then return s end
  end
  return STAGES[#STAGES]
end

local function newFS(size)
  local fs = content:CreateFontString(nil, "OVERLAY")
  fs:SetFont(FONT, size or 13, "")
  fs:SetJustifyH("LEFT")
  fs:SetJustifyV("TOP")
  fs:SetWidth(W)
  fs:SetTextColor(0.93, 0.91, 0.86)
  return fs
end

local function T(str, size, gap, font)
  if G.tr then str = G.tr(str) end
  R.fi = R.fi + 1
  local fs = fsPool[R.fi]
  if not fs then fs = newFS(size); fsPool[R.fi] = fs end
  fs:SetFont(font or FONT, size or 13, "")
  fs:ClearAllPoints()
  fs:SetPoint("TOPLEFT", content, "TOPLEFT", 0, -R.y)
  fs:SetText(str)
  fs:Show()
  R.y = R.y + fs:GetStringHeight() + (gap or 4)
end
local function tr(s) return (G.tr and G.tr(s)) or s end -- E6: tlumaczenie napisow okna (Locales)
local function H(str)
  str = tr(str)
  R.y = R.y + 12
  T(C_GOLD .. str .. "|r", 16, 3, G.TF())
  R.li = R.li + 1
  local ln = linePool[R.li]
  if not ln then
    ln = Divider(content)
    linePool[R.li] = ln
  end
  ln:ClearAllPoints()
  ln:SetPoint("TOPLEFT", content, "TOPLEFT", 0, -R.y)
  ln:SetWidth(W)
  ln:Show()
  R.y = R.y + 7
end
local function M(str) T(C_MUTED .. tr(str) .. "|r", 12) end
local function B(list) for _, s in ipairs(list) do T("• " .. tr(s)) end end
local function N(list) for i, s in ipairs(list) do T(i .. ". " .. tr(s)) end end
local function KV(list) for _, p in ipairs(list) do T(C_FROST .. tr(p[1]) .. "|r   " .. tr(p[2])) end end

local function CHK(k, label)
  R.ci = R.ci + 1
  local cb = cbPool[R.ci]
  if not cb then
    cb = CreateFrame("CheckButton", nil, content, "UICheckButtonTemplate")
    cb:SetSize(22, 22)
    cb.label = newFS(13)
    cb.label:SetWidth(W - 28)
    cb:SetScript("OnClick", function(self)
      local c = GrimuarSetupDB.checks[charKey()]
      if self:GetChecked() then c[self.k] = true else c[self.k] = nil end
    end)
    cbPool[R.ci] = cb
  end
  local checks = GrimuarSetupDB.checks[charKey()]
  cb.k = k
  cb:ClearAllPoints()
  cb:SetPoint("TOPLEFT", content, "TOPLEFT", -3, -R.y + 3)
  cb:SetChecked(checks[k] and true or false)
  cb:Show()
  cb.label:ClearAllPoints()
  cb.label:SetPoint("TOPLEFT", content, "TOPLEFT", 24, -R.y)
  cb.label:SetText(label)
  cb.label:Show()
  R.y = R.y + math.max(20, cb.label:GetStringHeight() + 6)
end

local function GO(label, fn, btnText)
  R.bi = R.bi + 1
  local b = btnPool[R.bi]
  if not b then
    b = FlatButton(content, 78, 22, "", true)
    b.label = newFS(13)
    b.label:SetWidth(W - 88)
    b:SetScript("OnClick", function(self) if self.fn then self.fn() end end)
    btnPool[R.bi] = b
  end
  b.fn = fn
  b:SetText(btnText or "Prowadź")
  b:ClearAllPoints()
  b:SetPoint("TOPLEFT", content, "TOPLEFT", 0, -R.y)
  b:Show()
  b.label:ClearAllPoints()
  b.label:SetPoint("TOPLEFT", content, "TOPLEFT", 88, -R.y - 4)
  b.label:SetText(label)
  b.label:Show()
  R.y = R.y + math.max(28, b.label:GetStringHeight() + 10)
end

-- Rzad przyciskow obok siebie: list = { { "Etykieta", funkcja }, ... }
-- 13.11 gracz: „tu sie przewinac nie da”: 6 zakladek Postaci wychodzilo za okno; przyciski, ktore sie nie mieszcza
-- w szerokosci tresci (W), przechodza do nastepnego rzedu
local function BTNROW(list)
  local x = 0
  for i, spec in ipairs(list) do
    R.ri = R.ri + 1
    local b = rowPool[R.ri]
    if not b then
      b = FlatButton(content, 64, 22, "")
      b:SetScript("OnClick", function(self) if self.fn then self.fn() end end)
      rowPool[R.ri] = b
    end
    b.fn = spec[2]
    b.primary = (i == 1)
    b:SetText(spec[1])
    FitButton(b, 64)
    b:Repaint()
    local w = b:GetWidth()
    if x > 0 and x + w > W then
      x = 0
      R.y = R.y + 28
    end
    b:ClearAllPoints()
    b:SetPoint("TOPLEFT", content, "TOPLEFT", x, -R.y)
    b:Show()
    x = x + w + 6
  end
  if #list > 0 then R.y = R.y + 30 end
end

-- ---------- elementy graficzne (wyglad 13.11): paski postepu, kafelki, plan z rombami ----------
local MORPHEUS = G.TF()
local WHITE8 = "Interface\\Buttons\\WHITE8X8"
local barPool, tilePool, planPool = {}, {}, {}

-- Pasek: etykieta z lewej, wartosc z prawej, pod spodem pasek; markAt = zlota kreska (np. odpoczynek, prog trenera)
local function BAR(label, valueText, value, max, rgb, markAt)
  R.bari = (R.bari or 0) + 1
  local b = barPool[R.bari]
  if not b then
    b = CreateFrame("Frame", nil, content)
    b:SetSize(W, 28)
    b.l = b:CreateFontString(nil, "OVERLAY")
    b.l:SetFont(FONT, 12, "")
    b.l:SetPoint("TOPLEFT", b, "TOPLEFT", 0, 0)
    b.l:SetJustifyH("LEFT")
    pcall(function() b.l:SetWordWrap(false) end)
    b.r = b:CreateFontString(nil, "OVERLAY")
    b.r:SetFont(FONT, 11, "")
    b.r:SetPoint("TOPRIGHT", b, "TOPRIGHT", 0, 0)
    b.r:SetTextColor(0.6, 0.59, 0.55)
    b.bg = b:CreateTexture(nil, "BACKGROUND")
    b.bg:SetTexture(WHITE8)
    b.bg:SetVertexColor(0.04, 0.035, 0.03, 1)
    b.bg:SetPoint("TOPLEFT", b, "TOPLEFT", 0, -15)
    b.bg:SetPoint("BOTTOMRIGHT", b, "BOTTOMRIGHT", 0, 3)
    b.edge = CreateFrame("Frame", nil, b, "BackdropTemplate")
    b.edge:SetAllPoints(b.bg)
    pcall(function() b.edge:SetBackdrop({ edgeFile = WHITE8, edgeSize = 1 }) b.edge:SetBackdropBorderColor(0.48, 0.39, 0.2, 0.6) end)
    b.sb = CreateFrame("StatusBar", nil, b)
    b.sb:SetPoint("TOPLEFT", b.bg, "TOPLEFT", 1, -1)
    b.sb:SetPoint("BOTTOMRIGHT", b.bg, "BOTTOMRIGHT", -1, 1)
    b.sb:SetStatusBarTexture(WHITE8)
    b.mark = b.edge:CreateTexture(nil, "OVERLAY")
    b.mark:SetTexture(WHITE8)
    b.mark:SetVertexColor(0.85, 0.71, 0.36, 1)
    b.mark:SetWidth(2)
    barPool[R.bari] = b
  end
  b:SetWidth(W)
  b.l:SetWidth(W - 90)
  b.l:SetText(label or "")
  b.r:SetText(valueText or "")
  local c = rgb or { 0.54, 0.31, 0.82 }
  b.sb:SetStatusBarColor(c[1], c[2], c[3], 1)
  local mx = (max and max > 0) and max or 1
  b.sb:SetMinMaxValues(0, mx)
  b.sb:SetValue(math.max(0, math.min(value or 0, mx)))
  if markAt and markAt > 0 and markAt < mx then
    local x = (W - 2) * markAt / mx
    b.mark:ClearAllPoints()
    b.mark:SetPoint("TOP", b.bg, "TOPLEFT", x, 1)
    b.mark:SetPoint("BOTTOM", b.bg, "BOTTOMLEFT", x, -1)
    b.mark:Show()
  else
    b.mark:Hide()
  end
  b:ClearAllPoints()
  b:SetPoint("TOPLEFT", content, "TOPLEFT", 0, -R.y)
  b:Show()
  R.y = R.y + 32
end

-- Kafelki w rzedzie (do 3): list = { { "duza liczba", "opis" }, ... }
local function TILES(list)
  local n = math.min(3, #list)
  if n == 0 then return end
  local gap = 8
  local w = math.floor((W - gap * (n - 1)) / n)
  for i = 1, n do
    R.tili = (R.tili or 0) + 1
    local t = tilePool[R.tili]
    if not t then
      t = CreateFrame("Frame", nil, content, "BackdropTemplate")
      pcall(function()
        t:SetBackdrop({ bgFile = WHITE8, edgeFile = WHITE8, edgeSize = 1 })
        t:SetBackdropColor(0.043, 0.039, 0.031, 1)
        t:SetBackdropBorderColor(0.48, 0.39, 0.2, 0.55)
      end)
      t.big = t:CreateFontString(nil, "OVERLAY")
      t.big:SetFont(MORPHEUS, 19, "")
      t.big:SetTextColor(0.85, 0.71, 0.36)
      t.big:SetPoint("TOPLEFT", t, "TOPLEFT", 8, -6)
      t.big:SetJustifyH("LEFT")
      t.small = t:CreateFontString(nil, "OVERLAY")
      t.small:SetFont(FONT, 11, "")
      t.small:SetTextColor(0.6, 0.59, 0.55)
      t.small:SetPoint("TOPLEFT", t.big, "BOTTOMLEFT", 0, -2)
      t.small:SetJustifyH("LEFT")
      tilePool[R.tili] = t
    end
    t:SetSize(w, 56)
    t.small:SetWidth(w - 14)
    t.big:SetText(list[i][1])
    t.small:SetText(list[i][2])
    t:ClearAllPoints()
    t:SetPoint("TOPLEFT", content, "TOPLEFT", (i - 1) * (w + gap), -R.y)
    t:Show()
  end
  R.y = R.y + 64
end

-- Wiersz planu z rombem: state = "done" | "now" | nil
local function PLAN(text, state, right)
  R.pli = (R.pli or 0) + 1
  local p = planPool[R.pli]
  if not p then
    p = CreateFrame("Frame", nil, content)
    p:SetSize(W, 18)
    p.d = p:CreateTexture(nil, "ARTWORK")
    p.d:SetTexture(WHITE8)
    p.d:SetSize(8, 8)
    p.d:SetPoint("LEFT", p, "LEFT", 3, 0)
    pcall(function() p.d:SetRotation(math.rad(45)) end)
    p.t = p:CreateFontString(nil, "OVERLAY")
    p.t:SetFont(FONT, 13, "")
    p.t:SetPoint("LEFT", p, "LEFT", 18, 0)
    p.t:SetJustifyH("LEFT")
    pcall(function() p.t:SetWordWrap(false) end)
    p.r = p:CreateFontString(nil, "OVERLAY")
    p.r:SetFont(FONT, 11, "")
    p.r:SetPoint("RIGHT", p, "RIGHT", 0, 0)
    p.r:SetTextColor(0.6, 0.59, 0.55)
    planPool[R.pli] = p
  end
  p:SetWidth(W)
  p.t:SetWidth(W - 80)
  p.t:SetText(text or "")
  p.r:SetText(right or "")
  if state == "done" then
    p.d:SetVertexColor(0.85, 0.71, 0.36, 1)
    p.t:SetTextColor(0.6, 0.59, 0.55)
  elseif state == "now" then
    p.d:SetVertexColor(1, 0.88, 0.55, 1)
    p.t:SetTextColor(0.97, 0.95, 0.9)
  else
    p.d:SetVertexColor(0.32, 0.27, 0.16, 1)
    p.t:SetTextColor(0.82, 0.8, 0.75)
  end
  p:ClearAllPoints()
  p:SetPoint("TOPLEFT", content, "TOPLEFT", 0, -R.y)
  p:Show()
  R.y = R.y + 20
end

local function lvCol(lv, l) if lv == l then return C_OK elseif lv < l then return C_MUTED end return C_FROST end

local TABS = {
  { "teraz", "Teraz", function(l) buildTeraz(l) if G.pageDzisExtra then pcall(G.pageDzisExtra, G.PT, l) end end },
  { "plan", "Etapy", buildPlan }, { "mapa", "Mapa", buildMapa }, { "talenty", "Talenty", buildTalenty },
  { "czary", "Czary", buildCzary }, { "walka", "Walka", buildWalka }, { "dungeony", "Lochy", buildDungeony },
  { "pvp", "PvP", buildPvP }, { "sprzet", "Sprzęt", buildSprzet }, { "profesje", "Profesje i złoto", buildProfesje },
  { "addony", "Addony", buildAddony }, { "podstawy", "Podstawy", buildPodstawy }, { "slownik", "Słownik", buildSlownik }, { "samouczek", "Samouczek", buildSamouczek },
  { "kontrola", "Kontrola", function(l) if G.pageKontrola then pcall(G.pageKontrola, G.PT, l) end end },
  { "przelaczniki", "Przełączniki", function(l) if G.pageToggles then pcall(G.pageToggles, G.PT, l) end end },
  { "do60", "Do 60 i raidy", function(l) if G.pageDo60 then pcall(G.pageDo60, G.PT, l) end end },
  { "mojeprof", "Moje profesje", function(l) if G.pageMojeProfesje then pcall(G.pageMojeProfesje, G.PT, l) end end },
  { "klawisze", "Klawisze", function(l) if G.pageKlawisze then pcall(G.pageKlawisze, G.PT, l) end end },
  { "grupa", "Grupa", function(l) if G.pageGrupa then pcall(G.pageGrupa, G.PT, l) end end },
  { "grafika", "Grafika", function(l) if G.pageGrafika then pcall(G.pageGrafika, G.PT, l) end end },
}

-- UX 12.11: 5 dzialow zamiast 14 zakladek; strony dzialu jako rzad przyciskow nad trescia.
local SECTIONS = {
  { "dzis", "Dziś", { "teraz", "plan" } },
  { "postac", "Postać", { "talenty", "czary", "sprzet", "mojeprof", "profesje", "do60" } },
  { "swiat", "Świat", { "dungeony", "grupa", "pvp", "mapa" } },
  { "wiedza", "Wiedza", { "klawisze", "walka", "podstawy", "slownik", "samouczek" } },
  { "ustawienia", "Ustawienia", { "kontrola", "przelaczniki", "grafika", "addony" } },
}
local function sectionOf(key)
  for _, s in ipairs(SECTIONS) do
    for _, k in ipairs(s[3]) do if k == key then return s end end
  end
  return SECTIONS[1]
end
local function tabLabel(key)
  for _, t in ipairs(TABS) do if t[1] == key then return t[2] end end
  return key
end

local function renderPanel()
  if not panel or not panel:IsShown() then return end
  GrimuarSetupDB.checks = GrimuarSetupDB.checks or {}
  GrimuarSetupDB.checks[charKey()] = GrimuarSetupDB.checks[charKey()] or {}
  for _, fs in ipairs(fsPool) do fs:Hide() end
  for _, cb in ipairs(cbPool) do cb:Hide(); cb.label:Hide() end
  for _, b in ipairs(btnPool) do b:Hide(); b.label:Hide() end
  for _, b in ipairs(rowPool) do b:Hide() end
  for _, ln in ipairs(linePool) do ln:Hide() end
  for _, x in ipairs(barPool) do x:Hide() end
  for _, x in ipairs(tilePool) do x:Hide() end
  for _, x in ipairs(planPool) do x:Hide() end
  R.y, R.fi, R.ci, R.bi, R.ri, R.li = 0, 0, 0, 0, 0, 0
  R.bari, R.tili, R.pli = 0, 0, 0
  local l = UnitLevel("player") or 1
  local build = TABS[1][3]
  for _, t in ipairs(TABS) do
    if t[1] == currentTab then build = t[3] end
  end
  local sec = sectionOf(currentTab)
  if #sec[3] > 1 then
    local row = {}
    for _, key in ipairs(sec[3]) do
      row[#row + 1] = { (key == currentTab) and (C_GOLD .. tabLabel(key) .. "|r") or tabLabel(key), function() if G.selectTab then G.selectTab(key) end end }
    end
    BTNROW(row)
  end
  build(l)
  R.y = R.y + 10
  M("Pełny poradnik: strona Grimuar maga. Shift+G albo Esc zamyka okno.")
  content:SetHeight(R.y + 10)
  for _, b in ipairs(tabButtons) do
    b.active = (b.key == sec[1])
    b:Repaint()
  end
  if panel.sub then panel.sub:SetText("poziom " .. l .. "  ·  " .. stageFor(l).title) end
end

G.refreshAll = function()
  pcall(updateHUD)
  if panel and panel:IsShown() and (currentTab == "teraz" or currentTab == "mapa") then renderPanel() end
end

local function selectTab(key)
  currentTab = key
  GrimuarSetupDB.tab = key
  GrimuarSetupDB.lastPage = GrimuarSetupDB.lastPage or {}
  GrimuarSetupDB.lastPage[sectionOf(key)[1]] = key
  if scroll then scroll:SetVerticalScroll(0) end
  renderPanel()
end

local function createPanel()
  local f = StyledWindow("GrimuarPanel", 600, 660, "Grimuar maga", "HIGH")
  f:SetPoint("CENTER", UIParent, "CENTER", 360, 40)
  f.OnMoved = function(self)
    local pnt, _, rp, x, y = self:GetPoint()
    GrimuarSetupDB.panelPos = { pnt, rp, x, y }
  end

  -- boczne menu z zakladkami
  local side = CreateFrame("Frame", nil, f, "BackdropTemplate")
  side:SetPoint("TOPLEFT", f, "TOPLEFT", 1, -33)
  side:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT", 1, 1)
  side:SetWidth(124)
  setBackdrop(side, STYLE.sidebar, STYLE.sidebar, 0)
  local sideEdge = side:CreateTexture(nil, "ARTWORK")
  sideEdge:SetColorTexture(unpack(STYLE.edge))
  sideEdge:SetWidth(1)
  sideEdge:SetPoint("TOPRIGHT", side, "TOPRIGHT", 0, 0)
  sideEdge:SetPoint("BOTTOMRIGHT", side, "BOTTOMRIGHT", 0, 0)
  GrimuarSetupDB.lastPage = GrimuarSetupDB.lastPage or {}
  for i, s in ipairs(SECTIONS) do
    local b = FlatButton(side, 112, 30, s[2])
    b:SetPoint("TOPLEFT", side, "TOPLEFT", 6, -8 - (i - 1) * 36)
    local fs = b:GetFontString()
    fs:ClearAllPoints()
    fs:SetPoint("LEFT", b, "LEFT", 32, 0)
    fs:SetFont(G.TF(), 15, "")
    -- wyglad 13.11: ikona dzialu
    local SECTION_ICONS = { dzis = "INV_Misc_PocketWatch_01", postac = "Spell_Frost_FrostBolt02", swiat = "INV_Misc_Map_01",
      wiedza = "INV_Misc_Book_09", ustawienia = "INV_Misc_Gear_01" }
    local ic = b:CreateTexture(nil, "ARTWORK")
    ic:SetSize(20, 20)
    ic:SetPoint("LEFT", b, "LEFT", 6, 0)
    ic:SetTexture("Interface\\Icons\\" .. (SECTION_ICONS[s[1]] or "INV_Misc_QuestionMark"))
    ic:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    b.key = s[1]
    b:SetScript("OnClick", function() selectTab(GrimuarSetupDB.lastPage[s[1]] or s[3][1]) end)
    table.insert(tabButtons, b)
  end

  -- przewijana tresc
  local okS, sf = pcall(CreateFrame, "ScrollFrame", "GrimuarPanelScroll", f, "UIPanelScrollFrameTemplate")
  if not okS or not sf then
    sf = CreateFrame("ScrollFrame", "GrimuarPanelScroll", f)
    sf:EnableMouseWheel(true)
    sf:SetScript("OnMouseWheel", function(self, delta)
      local max = math.max(0, (content:GetHeight() or 0) - self:GetHeight())
      local v = math.min(max, math.max(0, self:GetVerticalScroll() - delta * 40))
      self:SetVerticalScroll(v)
    end)
  end
  sf:SetPoint("TOPLEFT", f, "TOPLEFT", 140, -44)
  sf:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -30, 14)
  content = CreateFrame("Frame", nil, sf)
  content:SetSize(W, 100)
  sf:SetScrollChild(content)
  scroll = sf

  panel = f
  if G.addRuneCorners then pcall(G.addRuneCorners, f) end -- UX 12.11: zlote runy w oknie
  currentTab = GrimuarSetupDB.tab or "teraz"
  f:SetScript("OnShow", function() renderPanel() end)
  f:Hide()
  tinsert(UISpecialFrames, "GrimuarPanel")
  local pos = GrimuarSetupDB.panelPos
  if pos then
    f:ClearAllPoints()
    f:SetPoint(pos[1], UIParent, pos[2], pos[3], pos[4])
  end
end

local function togglePanel()
  if not panel then createPanel() end
  if panel:IsShown() then panel:Hide() else panel:Show() end
end

-- eksport do pozostalych modulow
G.getPanel = function() return panel end
-- pomocnicy rysowania dla stron z innych modulow (Strony.lua)
G.PT = { T = T, H = H, M = M, B = B, KV = KV, BTNROW = BTNROW, BAR = BAR, TILES = TILES, PLAN = PLAN } -- okno powstaje w grze, wiec inne pliki pytaja o nie w chwili uzycia
G.panel = panel
G.scroll = scroll
G.content = content
G.tabButtons = tabButtons
G.fsPool = fsPool
G.cbPool = cbPool
G.btnPool = btnPool
G.rowPool = rowPool
G.R = R
G.TUT_REF = TUT_REF
G.currentTab = currentTab
G.stageFor = stageFor
G.newFS = newFS
G.T = T
G.H = H
G.M = M
G.B = B
G.N = N
G.KV = KV
G.CHK = CHK
G.GO = GO
G.BTNROW = BTNROW
G.lvCol = lvCol
G.TABS = TABS
G.SECTIONS = SECTIONS
G.renderPanel = renderPanel
G.selectTab = selectTab
G.createPanel = createPanel
G.togglePanel = togglePanel
