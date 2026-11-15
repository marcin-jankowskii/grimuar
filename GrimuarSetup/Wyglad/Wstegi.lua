-- Grimuar: modul Wstegi. Komunikaty Grimuara jako zlota wstega u gory ekranu, jak „Nowe zadanie” w Wiedzminie 3
-- (propozycja 5, zgoda gracza 12.11). Engine:showToast oddaje tu wyswietlanie; stary komunikat zostaje jako zapas
-- (/wstegi wylacza i wlacza). Jedna wstega naraz, znika po 4 s (wazne po 6 s). Stoi nad komunikatami bledow gry.
local ADDON_NAME, G = ...
local say = G.say

local FONT = G.FONT or "Fonts\\ARIALN.TTF"
local TITLE_FONT = G.TF()
local WHITE = "Interface\\Buttons\\WHITE8X8"
local W = 560
local GOLD = { 0.85, 0.71, 0.36 }
local RED = { 0.94, 0.54, 0.44 }

-- Tytul wstegi z klucza komunikatu (klucze z remind/showToast w Engine, Vendor, Trener, Sesja).
local TITLES = {
  { "^tal", "Nowy talent" }, { "^train", "Trener czeka" }, { "^bags", "Torby" }, { "^armor", "Brak pancerza" },
  { "^ai$", "Brak Arcane Intellect" }, { "^dura", "Sprzęt zużyty" }, { "^water", "Mało wody" },
  { "^pvp", "Strefa sporna" }, { "^budget", "Koniec sesji" }, { "^camp", "Karczma" }, { "^inn", "Karczma" },
  { "^plan", "Plan na dziś" }, { "^turnin", "Questy" }, { "^rest", "Odpoczynek" }, { "^book", "Biblioteka" },
  { "^todo", "Zadanie etapu" }, { "^dng", "Loch" }, { "^prepull", "Przed walką" }, { "^rangi", "Nowe rangi" }, { "^death", "Po śmierci" }, { "^prof", "Profesje" },
}

local function titleFor(key)
  key = key or ""
  for _, t in ipairs(TITLES) do
    if key:find(t[1]) then return t[2] end
  end
  return "Grimuar"
end

local banner
local token = 0

-- Pozioma polowka z gradientem alfa (od srodka do brzegu zanika).
local function half(layer, side, top, bottom)
  local t = banner:CreateTexture(nil, layer)
  t:SetTexture(WHITE)
  if side == "L" then
    t:SetPoint("TOPLEFT", banner, "TOPLEFT", 0, top)
    t:SetPoint("BOTTOMRIGHT", banner, "BOTTOM", 0, bottom)
  else
    t:SetPoint("TOPLEFT", banner, "TOP", 0, top)
    t:SetPoint("BOTTOMRIGHT", banner, "BOTTOMRIGHT", 0, bottom)
  end
  t.side = side
  return t
end

local function paint(t, r, g, b, a)
  local ok = pcall(function()
    local edge, mid = CreateColor(r, g, b, 0), CreateColor(r, g, b, a)
    if t.side == "L" then t:SetGradient("HORIZONTAL", edge, mid) else t:SetGradient("HORIZONTAL", mid, edge) end
  end)
  if not ok then t:SetVertexColor(r, g, b, a * 0.6) end
end

local function line(side, isTop)
  local t = banner:CreateTexture(nil, "ARTWORK")
  t:SetTexture(WHITE)
  t:SetHeight(1)
  local y = isTop and "TOP" or "BOTTOM"
  if side == "L" then
    t:SetPoint(y .. "LEFT", banner, y .. "LEFT", 0, 0)
    t:SetPoint(y .. "RIGHT", banner, y, 0, 0)
  else
    t:SetPoint(y .. "LEFT", banner, y, 0, 0)
    t:SetPoint(y .. "RIGHT", banner, y .. "RIGHT", 0, 0)
  end
  t.side = side
  return t
end

local function create()
  banner = CreateFrame("Frame", "GrimuarBanner", UIParent)
  banner:SetSize(W, 62)
  banner:SetPoint("TOP", UIParent, "TOP", 0, -60)
  banner:SetFrameStrata("HIGH")
  banner:EnableMouse(false)
  banner.bg = { half("BACKGROUND", "L", 0, 0), half("BACKGROUND", "R", 0, 0) }
  for _, t in ipairs(banner.bg) do paint(t, 0.04, 0.05, 0.07, 0.92) end
  banner.lines = { line("L", true), line("R", true), line("L", false), line("R", false) }
  -- runa (romb) na srodku gornej linii
  banner.rune = banner:CreateTexture(nil, "OVERLAY")
  banner.rune:SetTexture(WHITE)
  banner.rune:SetSize(7, 7)
  banner.rune:SetPoint("CENTER", banner, "TOP", 0, 0)
  pcall(function() banner.rune:SetRotation(math.rad(45)) end)
  banner.title = banner:CreateFontString(nil, "OVERLAY")
  banner.title:SetFont(TITLE_FONT, 20, "")
  banner.title:SetShadowOffset(1, -1)
  banner.title:SetPoint("TOP", banner, "TOP", 0, -10)
  banner.icon = banner:CreateTexture(nil, "OVERLAY")
  banner.icon:SetSize(26, 26)
  banner.icon:SetPoint("RIGHT", banner.title, "LEFT", -8, 0)
  banner.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
  banner.sub = banner:CreateFontString(nil, "OVERLAY")
  banner.sub:SetFont(FONT, 14, "")
  banner.sub:SetTextColor(0.93, 0.91, 0.86)
  banner.sub:SetWidth(W - 90)
  banner.sub:SetJustifyH("CENTER")
  banner.sub:SetPoint("TOP", banner.title, "BOTTOM", 0, -4)
  banner:Hide()
end

local function show(msg, key, loud)
  if not banner then create() end
  -- historia (okno Grimuara, dzial Dziś): ostatnie 8 komunikatow
  G.recent = G.recent or {}
  table.insert(G.recent, 1, { date("%H:%M"), titleFor(key), tostring(msg or "") })
  while #G.recent > 8 do table.remove(G.recent) end
  local c = loud and RED or GOLD
  banner.title:SetText(titleFor(key))
  banner.title:SetTextColor(c[1], c[2], c[3])
  banner.sub:SetText((tostring(msg or ""):gsub("^%l", string.upper)))
  for _, t in ipairs(banner.lines) do paint(t, c[1], c[2], c[3], 1) end
  banner.rune:SetVertexColor(c[1], c[2], c[3], 1)
  banner:SetHeight(10 + banner.title:GetStringHeight() + 4 + banner.sub:GetStringHeight() + 12)
  pcall(function() banner.icon:SetTexture(G.iconFor and G.iconFor(key or "") or "Interface\\Icons\\INV_Misc_Book_09") end)
  banner:SetAlpha(1)
  banner:Show()
  -- wysuwanie z gory (0,25 s)
  banner.t0 = GetTime()
  banner:SetScript("OnUpdate", function(self)
    local p = math.min(1, (GetTime() - self.t0) / 0.25)
    self:ClearAllPoints()
    self:SetPoint("TOP", UIParent, "TOP", 0, -40 - 20 * p)
    if p >= 1 then self:SetScript("OnUpdate", nil) end
  end)
  pcall(UIFrameFadeIn, banner, 0.3, 0, 1)
  token = token + 1
  local my = token
  C_Timer.After(loud and 6 or 4, function()
    if token ~= my then return end
    pcall(UIFrameFadeOut, banner, 0.8, 1, 0)
    C_Timer.After(0.9, function() if token == my then banner:Hide() end end)
  end)
  pcall(function()
    if loud then PlaySound(SOUNDKIT.RAID_WARNING) else PlaySound(SOUNDKIT.MAP_PING) end
  end)
end

SLASH_GRIMUARWSTEGI1 = "/wstegi"
SlashCmdList["GRIMUARWSTEGI"] = function()
  GrimuarSetupDB.noBanner = not GrimuarSetupDB.noBanner
  if GrimuarSetupDB.noBanner then
    say("wstęgi wyłączone: komunikaty wracają do okienka na środku.")
  else
    say("wstęgi włączone.")
    show("tak wyglądają komunikaty Grimuara.", "plan", false)
  end
end

G.showBanner = show
G.bannerTitle = titleFor -- 14.11: tytuly tez dla komunikatow po lewej (GrimuarUI HudEkran.lua)
