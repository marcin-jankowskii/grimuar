-- Grimuar UI: znaczniki (15.11, makieta „Znaczniki Grimuara” M1-M10; gracz: „chodzi mi o wyglad, te na kompasie sa
-- brzydkie”, potem „super, podobaja mi sie, dodaj”). Jeden zestaw dla kompasu, minimapy i mapy huba: kształt mowi, czym
-- jest znacznik, kolor - do ktorego zadania nalezy, znak w srodku - co zrobic. Tekstury 64x64 rysuje
-- gaming-warsztat\wow\grimuar\narzedzia\gen_znaczniki_tga.py do Media\Znaczniki (TGA, ostre na kazdej wielkosci).
-- Ramka celu zadania i znaki czynnosci sa biale: kolor zadania daje SetVertexColor.
local ADDON, U = ...

local DIR = "Interface\\AddOns\\GrimuarUI\\Media\\Znaczniki\\"
U.ZN = {
  cel = DIR .. "cel", zadanie = DIR .. "zadanie", oddaj = DIR .. "oddaj", wez = DIR .. "wez", wez_szary = DIR .. "wez_szary",
  przy_okazji = DIR .. "przy_okazji", ziolo = DIR .. "ziolo", ruda = DIR .. "ruda", usluga = DIR .. "usluga",
  krawedz = DIR .. "krawedz",
  g = { zabij = DIR .. "g_zabij", zbierz = DIR .. "g_zbierz", uzyj = DIR .. "g_uzyj", rozmowa = DIR .. "g_rozmowa", idz = DIR .. "g_idz" },
}
-- typ celu z Questie (objective.Type) -> znak czynnosci
U.ZN_TYPE = { monster = "zabij", killcredit = "zabij", item = "zbierz", object = "uzyj", spell = "uzyj", event = "idz",
  talk = "rozmowa", reputation = "idz" }

-- napis |T...|t do tekstow (legenda mapy): U.znTex("oddaj", 14), U.znTex("zadanie", 14, kolor), U.znTex("zabij", 14).
-- 15.11 (znaczniki M10): tekstura ma pusty brzeg, wiec w tekscie wycinamy srodek (znak czynnosci: srodkowa polowa),
-- zeby przy 14 px byl czytelny; kolor {r,g,b} barwi ramke celu zadania jak SetVertexColor.
function U.znTex(kind, size, col)
  local p, a, b = U.ZN[kind], 8, 56
  if type(p) ~= "string" then p, a, b = U.ZN.g[kind], 16, 48 end
  if type(p) ~= "string" then p, a, b = U.ZN.zadanie, 8, 56 end
  local s = size or 14
  local t = "|T" .. p .. ":" .. s .. ":" .. s .. ":0:0:64:64:" .. a .. ":" .. b .. ":" .. a .. ":" .. b
  if col then
    t = t .. ":" .. math.floor(col[1] * 255 + 0.5) .. ":" .. math.floor(col[2] * 255 + 0.5) .. ":" .. math.floor(col[3] * 255 + 0.5)
  end
  return t .. "|t"
end

-- znacznik: ramka z warstwami. m:Set(kind, { col = {r,g,b}, glyph = "zabij", icon = tekstura }) - kind jak w U.ZN.
-- Usluga: zloty pierscien, w srodku ikona gry w kole.
-- 15.11 (znaczniki M10): ikona uslugi 0,52 wielkosci: ciemne wnetrze pierscienia ma 0,54 (gen_znaczniki_tga.py: r 10,8
-- z 20), a przy 0,64 ikona zakrywala caly pierscien.
local ICON_K = 0.52
function U.Znacznik(parent, size)
  local m = CreateFrame("Frame", nil, parent)
  m:SetSize(size, size)
  m.base = m:CreateTexture(nil, "ARTWORK", nil, 1)
  m.base:SetAllPoints()
  m.icon = m:CreateTexture(nil, "ARTWORK", nil, 2)
  m.icon:SetPoint("CENTER")
  m.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
  pcall(function()
    local mk = m:CreateMaskTexture()
    mk:SetTexture("Interface\\CHARACTERFRAME\\TempPortraitAlphaMask", "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
    mk:SetAllPoints(m.icon)
    m.icon:AddMaskTexture(mk)
  end)
  m.icon:Hide()
  m.glyph = m:CreateTexture(nil, "ARTWORK", nil, 3)
  m.glyph:SetAllPoints()
  m.glyph:Hide()
  function m:Set(kind, o)
    o = o or {}
    self.kind = kind
    self.base:SetTexture(U.ZN[kind] or U.ZN.zadanie)
    local c = (kind == "zadanie") and o.col or nil
    if c then self.base:SetVertexColor(c[1], c[2], c[3], 1) else self.base:SetVertexColor(1, 1, 1, 1) end
    local g = kind == "zadanie" and o.glyph and U.ZN.g[o.glyph] or nil
    self.glyph:SetShown(g ~= nil)
    if g then self.glyph:SetTexture(g) end
    self.icon:SetShown(kind == "usluga" and o.icon ~= nil)
    if kind == "usluga" and o.icon then
      self.icon:SetTexture(o.icon)
      local s = (self:GetWidth() or 24) * ICON_K
      self.icon:SetSize(s, s)
    end
  end
  function m:SetSizeAll(s)
    self:SetSize(s, s)
    if self.icon:IsShown() then self.icon:SetSize(s * ICON_K, s * ICON_K) end
  end
  return m
end
