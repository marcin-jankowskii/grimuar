-- Grimuar UI: Theme. Kanon „Pustynia i Runy 2.0” (makiety 14.11: (makieta Grimuara)):
-- ciemne panele ~86%, jeden zloty akcent, tytuly Alegreya SC, tresc Alegreya Sans (gdy gra je rysuje, do tego czasu ARIALN
-- z polskimi literami), jakosc przedmiotu na ramce ikony, wejscie 0,15 s. Zasady: tylko wlasne ramki i tekstury,
-- w tabelach Blizzarda nic nie zapisujemy.
local ADDON, U = ...
local G = _G.GrimuarAPI or {}
U.G = G

local WHITE = "Interface\\Buttons\\WHITE8X8"
local ARIALN = "Fonts\\ARIALN.TTF"
U.WHITE = WHITE

local function rgb(h)
  return { tonumber(h:sub(1, 2), 16) / 255, tonumber(h:sub(3, 4), 16) / 255, tonumber(h:sub(5, 6), 16) / 255 }
end
local C = {
  bg = rgb("0d0b09"), panel = rgb("17130e"), panel2 = rgb("1f1912"), line = rgb("2e261b"), edge = rgb("6e5a32"),
  gold = rgb("d9b55c"), goldDim = rgb("a88a48"), text = rgb("ede8db"), muted = rgb("a39c8d"), faint = rgb("8a8374"),
  frost = rgb("8fbfe8"), danger = rgb("e0794a"), ok = rgb("9dbb72"), hp = rgb("b3261e"), mana = rgb("3d85f5"),
  slot = rgb("0f0c09"),
}
U.C = C
U.QUALITY = { [0] = rgb("9d9d9d"), [1] = rgb("cfcfcf"), [2] = rgb("1eff00"), [3] = rgb("0070dd"), [4] = rgb("a335ee"),
  [5] = rgb("ff8000"), [6] = rgb("e6cc80"), [7] = rgb("00ccff") }

function U.hex(c) return string.format("|cff%02x%02x%02x", c[1] * 255, c[2] * 255, c[3] * 255) end
function U.say(msg)
  if G.say then G.say(msg) else print("|cffd9b55cGrimuar:|r " .. tostring(msg)) end
end

-- liczba z gry; w Midnight czesc wartosci bywa „sekretna” (porownanie = blad), wtedy nil
function U.num(v)
  if v == nil then return nil end
  if issecretvalue and issecretvalue(v) then return nil end
  if type(v) ~= "number" then return nil end
  return v
end
function U.thousands(n)
  n = U.num(n)
  if not n then return "—" end
  local s = tostring(math.floor(n + 0.5)):reverse():gsub("(%d%d%d)", "%1 "):reverse()
  return (s:gsub("^ ", ""))
end
function U.call(fn, ...)
  if type(fn) ~= "function" then return nil end
  local ok, a, b, c, d = pcall(fn, ...)
  if ok then return a, b, c, d end
  return nil
end

-- ---------- czcionki ----------
local strings = setmetatable({}, { __mode = "k" })
local function fontPath(kind)
  if G.uiFont then return G.uiFont(kind) end
  return ARIALN
end
local function applyFont(fs)
  local spec = strings[fs]
  if not spec then return end
  local ok, res = pcall(fs.SetFont, fs, fontPath(spec[1]), spec[2], spec[3] or "")
  if not ok or res == false then pcall(fs.SetFont, fs, ARIALN, spec[2], spec[3] or "") end
end
function U.Color(fs, c, a) fs:SetTextColor(c[1], c[2], c[3], a or c[4] or 1) end
function U.Text(parent, size, kind, color, flags)
  local fs = parent:CreateFontString(nil, "OVERLAY")
  -- 14.11 (R27 E6): kazdy napis huba przez tlumaczenie (GrimuarSetup Locales\Tlumacz.lua, jezyk z kreatora)
  local orig = fs.SetText
  fs.SetText = function(self, t, ...) if G.tr then t = G.tr(t) end return orig(self, t, ...) end
  strings[fs] = { kind or "body", size or 13, flags }
  applyFont(fs)
  U.Color(fs, color or C.text)
  fs:SetJustifyH("LEFT")
  fs:SetJustifyV("TOP")
  fs:SetWordWrap(false)
  return fs
end
-- tekst zawijany w podanej szerokosci
function U.Para(parent, size, width, color, kind)
  local fs = U.Text(parent, size, kind, color)
  fs:SetWidth(width)
  fs:SetWordWrap(true)
  return fs
end
function U.Shadow(fs)
  fs:SetShadowColor(0, 0, 0, 0.85)
  fs:SetShadowOffset(1, -1)
end
U.fontChanged = {} -- funkcje ukladu do przeliczenia, gdy Alegreya dojdzie pozniej
if G.onUiFonts then
  G.onUiFonts(function()
    for fs in pairs(strings) do pcall(applyFont, fs) end
    for _, fn in ipairs(U.fontChanged) do pcall(fn) end
  end)
end

-- ---------- tekstury ----------
function U.Rect(parent, c, a, layer, sub)
  local t = parent:CreateTexture(nil, layer or "BACKGROUND", nil, sub or 0)
  t:SetColorTexture(c[1], c[2], c[3], a or 1)
  return t
end
function U.Border(f, c, a, size)
  size = size or 1
  local t = {}
  for i = 1, 4 do
    t[i] = f:CreateTexture(nil, "BORDER")
    t[i]:SetColorTexture(c[1], c[2], c[3], a or 1)
  end
  t[1]:SetPoint("TOPLEFT") t[1]:SetPoint("TOPRIGHT") t[1]:SetHeight(size)
  t[2]:SetPoint("BOTTOMLEFT") t[2]:SetPoint("BOTTOMRIGHT") t[2]:SetHeight(size)
  t[3]:SetPoint("TOPLEFT") t[3]:SetPoint("BOTTOMLEFT") t[3]:SetWidth(size)
  t[4]:SetPoint("TOPRIGHT") t[4]:SetPoint("BOTTOMRIGHT") t[4]:SetWidth(size)
  f.borderTex = t
  return t
end
function U.BorderColor(f, c, a)
  for _, t in ipairs(f.borderTex or {}) do t:SetColorTexture(c[1], c[2], c[3], a or 1) end
end
-- zlote narozniki: lewy gorny i prawy dolny
function U.Corners(f, c, len, th)
  c, len, th = c or C.goldDim, len or 11, th or 2
  local function seg(p, w, h, x, y)
    local t = f:CreateTexture(nil, "OVERLAY", nil, 7)
    t:SetColorTexture(c[1], c[2], c[3], 1)
    t:SetSize(w, h)
    t:SetPoint(p, f, p, x, y)
  end
  seg("TOPLEFT", len, th, -1, 1) seg("TOPLEFT", th, len, -1, 1)
  seg("BOTTOMRIGHT", len, th, 1, -1) seg("BOTTOMRIGHT", th, len, 1, -1)
end
function U.Panel(parent, alpha, corners, edge)
  local f = CreateFrame("Frame", nil, parent)
  f.bg = U.Rect(f, C.panel, alpha or 0.86)
  f.bg:SetAllPoints()
  U.Border(f, edge or C.line)
  if corners ~= false then U.Corners(f) end
  return f
end
function U.Line(parent, c, a)
  local t = parent:CreateTexture(nil, "ARTWORK")
  t:SetColorTexture((c or C.line)[1], (c or C.line)[2], (c or C.line)[3], a or 1)
  t:SetHeight(1)
  return t
end

-- romb (runa): pelny albo obrys
function U.Diamond(parent, size, c, filled)
  local f = CreateFrame("Frame", nil, parent)
  f:SetSize(size, size)
  local s = size * 0.7
  f.outer = f:CreateTexture(nil, "ARTWORK")
  f.outer:SetSize(s, s)
  f.outer:SetPoint("CENTER")
  f.inner = f:CreateTexture(nil, "ARTWORK", nil, 1)
  f.inner:SetSize(math.max(1, s - 3), math.max(1, s - 3))
  f.inner:SetPoint("CENTER")
  pcall(f.outer.SetRotation, f.outer, math.rad(45))
  pcall(f.inner.SetRotation, f.inner, math.rad(45))
  function f:Set(col, full)
    col = col or C.gold
    self.outer:SetColorTexture(col[1], col[2], col[3], 1)
    self.inner:SetColorTexture(C.bg[1], C.bg[2], C.bg[3], 1)
    self.inner:SetShown(not full)
  end
  f:Set(c, filled)
  return f
end

-- pasek postepu (z opcjonalna kreska, np. odpoczynek)
function U.Bar(parent, h, col)
  local f = CreateFrame("Frame", nil, parent)
  f:SetHeight(h or 7)
  f.bg = U.Rect(f, { 0.035, 0.031, 0.024 }, 1)
  f.bg:SetAllPoints()
  U.Border(f, C.line)
  f.fill = f:CreateTexture(nil, "ARTWORK")
  f.fill:SetPoint("TOPLEFT", 1, -1)
  f.fill:SetPoint("BOTTOMLEFT", 1, 1)
  f.mark = f:CreateTexture(nil, "OVERLAY")
  f.mark:SetColorTexture(C.frost[1], C.frost[2], C.frost[3], 1)
  f.mark:SetSize(2, (h or 7) + 4)
  f.mark:Hide()
  function f:SetFillColor(c) self.fill:SetColorTexture(c[1], c[2], c[3], 1) end
  function f:SetValue(v, m)
    v = math.max(0, math.min(1, U.num(v) or 0))
    local w = math.max(0, (self:GetWidth() or 0) - 2)
    self.fill:SetWidth(math.max(0.01, w * v))
    self.fill:SetShown(v > 0)
    m = U.num(m)
    if m and m > 0 then
      self.mark:ClearAllPoints()
      self.mark:SetPoint("CENTER", self, "LEFT", 1 + w * math.min(1, m), 0)
      self.mark:Show()
    else
      self.mark:Hide()
    end
  end
  f:SetFillColor(col or C.goldDim)
  return f
end

-- przycisk: zwykly (ciemny, ramka braz) albo glowny (zloty)
function U.Button(parent, text, w, h, primary)
  local b = CreateFrame("Button", nil, parent)
  b:SetSize(w or 140, h or 28)
  b.bg = b:CreateTexture(nil, "BACKGROUND")
  b.bg:SetAllPoints()
  U.Border(b, C.edge)
  b.label = U.Text(b, 13, "title", primary and C.bg or C.text)
  b.label:SetPoint("CENTER", 0, 0)
  b.label:SetJustifyH("CENTER")
  b.label:SetJustifyV("MIDDLE")
  local function paint(hover)
    if primary then
      b.bg:SetColorTexture(C.gold[1], C.gold[2], C.gold[3], hover and 1 or 0.9)
      U.BorderColor(b, C.gold)
    else
      local k = hover and 1.45 or 1
      b.bg:SetColorTexture(0.102 * k, 0.082 * k, 0.059 * k, 1)
      U.BorderColor(b, hover and C.gold or C.edge)
    end
  end
  function b:SetLabel(t)
    self.label:SetText(t or "")
    if not w then self:SetWidth(math.floor(self.label:GetStringWidth() + 30)) end
  end
  paint(false)
  b:SetScript("OnEnter", function() paint(true) end)
  b:SetScript("OnLeave", function() paint(false) end)
  b:SetLabel(text)
  return b
end

-- klawisz jak w podpowiedziach na dole ekranu
function U.Key(parent, text)
  local f = CreateFrame("Frame", nil, parent)
  f.bg = U.Rect(f, { 0.071, 0.059, 0.043 }, 1)
  f.bg:SetAllPoints()
  U.Border(f, C.edge)
  local under = f:CreateTexture(nil, "BORDER", nil, 1)
  under:SetColorTexture(C.edge[1], C.edge[2], C.edge[3], 1)
  under:SetPoint("BOTTOMLEFT") under:SetPoint("BOTTOMRIGHT") under:SetHeight(2)
  f.label = U.Text(f, 11, "body", C.text)
  f.label:SetPoint("CENTER", 0, 1)
  f.label:SetJustifyH("CENTER")
  f.label:SetJustifyV("MIDDLE")
  function f:SetKey(t)
    self.label:SetText(t)
    self:SetSize(math.max(20, math.floor(self.label:GetStringWidth() + 12)), 20)
  end
  f:SetKey(text)
  return f
end

-- maly znacznik tekstowy w ramce
function U.Tag(parent, text, c)
  local f = CreateFrame("Frame", nil, parent)
  U.Border(f, c or C.edge)
  f.label = U.Text(f, 11, "body", c or C.goldDim)
  f.label:SetPoint("CENTER", 0, 0)
  f.label:SetJustifyV("MIDDLE")
  function f:SetTag(t, col)
    col = col or c or C.goldDim
    self.label:SetText(t)
    U.Color(self.label, col)
    U.BorderColor(self, col, 0.7)
    self:SetSize(math.floor(self.label:GetStringWidth() + 14), 18)
  end
  f:SetTag(text or "", c)
  return f
end

-- slot na ikone: ramka = jakosc (szara bez przedmiotu)
function U.Slot(parent, size)
  local b = CreateFrame("Button", nil, parent)
  b:SetSize(size, size)
  b.bg = U.Rect(b, C.slot, 1)
  b.bg:SetAllPoints()
  b.icon = b:CreateTexture(nil, "ARTWORK")
  b.icon:SetPoint("TOPLEFT", 2, -2)
  b.icon:SetPoint("BOTTOMRIGHT", -2, 2)
  b.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
  U.Border(b, C.line, 1, 2)
  b.count = U.Text(b, 11, "body", C.text, "OUTLINE")
  b.count:SetPoint("BOTTOMRIGHT", -3, 3)
  b.count:SetJustifyH("RIGHT")
  local hl = b:CreateTexture(nil, "HIGHLIGHT")
  hl:SetAllPoints()
  hl:SetColorTexture(1, 1, 1, 0.08)
  function b:SetQuality(q, alarm)
    if alarm then U.BorderColor(self, C.danger) return end
    local c = q and U.QUALITY[q]
    if c and q >= 1 then U.BorderColor(self, c) else U.BorderColor(self, q == 0 and U.QUALITY[0] or C.line) end
  end
  return b
end

-- wiersz „etykieta ............ wartosc”
function U.KV(parent, width, size)
  local r = CreateFrame("Frame", nil, parent)
  r:SetSize(width, (size or 14) + 6)
  r.l = U.Text(r, size or 14, "body", C.muted)
  r.l:SetPoint("LEFT", 0, 0)
  r.l:SetJustifyV("MIDDLE")
  r.r = U.Text(r, size or 14, "body", C.text)
  r.r:SetPoint("RIGHT", 0, 0)
  r.r:SetJustifyH("RIGHT")
  r.r:SetJustifyV("MIDDLE")
  function r:Set(a, b, col) self.l:SetText(a or "") self.r:SetText(b or "—") U.Color(self.r, col or C.text) end
  return r
end

-- naglowek sekcji (kapitaliki, zloto)
function U.H2(parent, text)
  local fs = U.Text(parent, 14, "title", C.gold)
  fs:SetText(text)
  return fs
end
function U.Label(parent, text)
  local fs = U.Text(parent, 11, "title", C.faint)
  fs:SetText(text)
  return fs
end
