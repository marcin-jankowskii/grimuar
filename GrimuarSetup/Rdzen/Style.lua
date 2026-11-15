-- Grimuar: modul Style. Wspolny wyglad: ciemne, plaskie panele jak okno Polestar,
-- mrozny niebieski akcent, zlote naglowki, plaskie przyciski z podswietleniem.
local ADDON_NAME, G = ...

local WHITE = "Interface\\Buttons\\WHITE8X8"
local FONT = G.FONT or "Fonts\\ARIALN.TTF"
local TITLE_FONT = G.TF() -- wyglad 13.11: tytuly jak tytuly questow

-- kolory jako { r, g, b, a }
-- wyglad 13.11: motyw Pustynia i Runy (ciemny braz i zloto zamiast granatu i mrozu)
local COL = {
  bg = { 0.067, 0.059, 0.047, 0.96 },
  header = { 0.098, 0.082, 0.059, 1 },
  sidebar = { 0.078, 0.066, 0.05, 1 },
  edge = { 0.48, 0.39, 0.2, 0.9 },
  accent = { 0.85, 0.71, 0.36, 1 },
  accentSoft = { 0.85, 0.71, 0.36, 0.14 },
  gold = { 0.85, 0.71, 0.36, 1 },
  goldSoft = { 0.85, 0.71, 0.36, 0.25 },
  text = { 0.93, 0.91, 0.86, 1 },
  muted = { 0.6, 0.59, 0.55, 1 },
  btn = { 0.1, 0.086, 0.06, 1 },
  btnHover = { 0.16, 0.13, 0.08, 1 },
  btnEdge = { 0.29, 0.25, 0.16, 1 },
  danger = { 0.94, 0.54, 0.44, 1 },
}

local function setBackdrop(frame, bg, edge, edgeSize)
  pcall(function()
    frame:SetBackdrop({ bgFile = WHITE, edgeFile = WHITE, edgeSize = edgeSize or 1 })
    frame:SetBackdropColor(unpack(bg or COL.bg))
    frame:SetBackdropBorderColor(unpack(edge or COL.edge))
  end)
end

-- Plaski przycisk: SetText / GetFontString / Enable / Disable dzialaja jak w zwyklym przycisku.
local function FlatButton(parent, w, h, text, primary)
  local b = CreateFrame("Button", nil, parent, "BackdropTemplate")
  b:SetSize(w or 80, h or 22)
  b.primary = primary
  local fs = b:CreateFontString(nil, "OVERLAY")
  fs:SetFont(FONT, 12, "")
  fs:SetPoint("CENTER", b, "CENTER", 0, 0)
  b:SetFontString(fs)
  local function paint(self, hover)
    if not self:IsEnabled() then
      setBackdrop(self, COL.btn, COL.edge)
      fs:SetTextColor(0.42, 0.44, 0.48)
      return
    end
    if self.active then
      setBackdrop(self, COL.accentSoft, COL.accent)
      fs:SetTextColor(unpack(COL.accent))
      return
    end
    -- 15.11 (gracz: karta „Grimuar · Teraz” w stylu huba): b.hub = wyglad przyciskow huba (U.Button w GrimuarUI)
    if self.hub then
      if self.primary then
        setBackdrop(self, { 0.85, 0.71, 0.36, hover and 1 or 0.9 }, { 0.85, 0.71, 0.36, 1 })
        fs:SetTextColor(0.051, 0.043, 0.035)
      else
        local k = hover and 1.45 or 1
        setBackdrop(self, { 0.102 * k, 0.082 * k, 0.059 * k, 1 }, hover and { 0.85, 0.71, 0.36, 1 } or { 0.43, 0.35, 0.2, 1 })
        fs:SetTextColor(0.93, 0.91, 0.86)
      end
      return
    end
    setBackdrop(self, hover and COL.btnHover or COL.btn, hover and COL.accent or (self.primary and COL.gold or COL.btnEdge))
    if self.primary then fs:SetTextColor(unpack(COL.gold)) else fs:SetTextColor(unpack(COL.text)) end
  end
  b.Repaint = function(self) paint(self, self:IsMouseOver()) end
  b:SetScript("OnEnter", function(self) paint(self, true) end)
  b:SetScript("OnLeave", function(self) paint(self, false) end)
  b:SetScript("OnEnable", function(self) paint(self, false) end)
  b:SetScript("OnDisable", function(self) paint(self, false) end)
  b:SetText(text or "")
  paint(b, false)
  return b
end

-- Szerokosc przycisku dopasowana do tekstu.
local function FitButton(b, minW)
  local fs = b:GetFontString()
  b:SetWidth(math.max(minW or 60, ((fs and fs:GetStringWidth()) or 40) + 22))
end

-- Okno w stylu Grimuara: tlo, ramka, pasek tytulu z przyciskiem zamykania. Zwraca ramke.
local function StyledWindow(name, w, h, title, strata)
  local f = CreateFrame("Frame", name, UIParent, "BackdropTemplate")
  f:SetSize(w, h)
  f:SetFrameStrata(strata or "HIGH")
  f:SetClampedToScreen(true)
  f:SetMovable(true)
  f:EnableMouse(true)
  setBackdrop(f, COL.bg, COL.edge)
  local head = CreateFrame("Frame", nil, f, "BackdropTemplate")
  head:SetPoint("TOPLEFT", f, "TOPLEFT", 1, -1)
  head:SetPoint("TOPRIGHT", f, "TOPRIGHT", -1, -1)
  head:SetHeight(32)
  setBackdrop(head, COL.header, COL.header, 0)
  head:EnableMouse(true)
  head:RegisterForDrag("LeftButton")
  head:SetScript("OnDragStart", function() f:StartMoving() end)
  head:SetScript("OnDragStop", function()
    f:StopMovingOrSizing()
    if f.OnMoved then f.OnMoved(f) end
  end)
  local line = head:CreateTexture(nil, "ARTWORK")
  line:SetColorTexture(unpack(COL.accent))
  line:SetAlpha(0.55)
  line:SetHeight(1)
  line:SetPoint("BOTTOMLEFT", head, "BOTTOMLEFT", 0, 0)
  line:SetPoint("BOTTOMRIGHT", head, "BOTTOMRIGHT", 0, 0)
  local icon = head:CreateTexture(nil, "ARTWORK")
  icon:SetTexture("Interface\\Icons\\Spell_Frost_FrostBolt02")
  icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
  icon:SetSize(20, 20)
  icon:SetPoint("LEFT", head, "LEFT", 10, 0)
  -- runa na srodku zlotej linii pod naglowkiem
  local rune = head:CreateTexture(nil, "OVERLAY")
  rune:SetColorTexture(unpack(COL.gold))
  rune:SetSize(7, 7)
  rune:SetPoint("CENTER", line, "CENTER", 0, 0)
  pcall(function() rune:SetRotation(math.rad(45)) end)
  local t = head:CreateFontString(nil, "OVERLAY")
  t:SetFont(TITLE_FONT, 17, "")
  t:SetTextColor(unpack(COL.gold))
  t:SetPoint("LEFT", icon, "RIGHT", 8, 0)
  t:SetText(title or "")
  local sub = head:CreateFontString(nil, "OVERLAY")
  sub:SetFont(FONT, 12, "")
  sub:SetTextColor(unpack(COL.muted))
  sub:SetPoint("LEFT", t, "RIGHT", 10, -1)
  local close = FlatButton(head, 24, 22, "×")
  close:SetPoint("RIGHT", head, "RIGHT", -6, 0)
  close:GetFontString():SetFont(FONT, 16, "")
  close:SetScript("OnClick", function()
    f:Hide()
    if f.OnClosed then f.OnClosed(f) end
  end)
  f.head, f.title, f.sub, f.close = head, t, sub, close
  return f
end

-- Cienka linia pod naglowkiem sekcji.
local function Divider(parent, layer)
  local tx = parent:CreateTexture(nil, layer or "ARTWORK")
  tx:SetColorTexture(unpack(COL.gold))
  tx:SetAlpha(0.22)
  tx:SetHeight(1)
  return tx
end

G.STYLE = COL
G.TITLE_FONT = TITLE_FONT
G.setBackdrop = setBackdrop
-- 15.11 (gracz: „chcialbym, zeby byl przycisk do zwijania i rozwijania”): maly przycisk −/+ w rogu naglowka;
-- zwiniety panel to sam naglowek, stan w GrimuarSetupDB
function G.FoldButton(parent, key, onToggle)
  local b = CreateFrame("Button", nil, parent)
  b:SetSize(20, 20)
  b:SetPoint("TOPRIGHT", parent, "TOPRIGHT", -6, -6)
  b:SetFrameLevel(parent:GetFrameLevel() + 5)
  b.t = b:CreateFontString(nil, "OVERLAY")
  b.t:SetFont(G.TF and G.TF() or "Fonts\\ARIALN.TTF", 18, "")
  b.t:SetPoint("CENTER", 0, 1)
  b.t:SetTextColor(0.85, 0.71, 0.36)
  local function paint() b.t:SetText(GrimuarSetupDB[key] and "+" or "–") end
  b:SetScript("OnEnter", function(self)
    self.t:SetTextColor(0.95, 0.93, 0.88)
    local tt = G.TT or GameTooltip
    tt:SetOwner(self, "ANCHOR_LEFT")
    tt:SetText(GrimuarSetupDB[key] and "Rozwiń" or "Zwiń", 1, 1, 1)
    tt:Show()
  end)
  b:SetScript("OnLeave", function(self)
    self.t:SetTextColor(0.85, 0.71, 0.36)
    local tt = G.TT or GameTooltip
    tt:Hide()
  end)
  b:SetScript("OnClick", function()
    GrimuarSetupDB[key] = not GrimuarSetupDB[key] or nil
    paint()
    if onToggle then pcall(onToggle) end
  end)
  b.Paint = paint
  paint()
  return b
end
G.FlatButton = FlatButton
G.FitButton = FitButton
G.StyledWindow = StyledWindow
G.Divider = Divider
