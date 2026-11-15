-- Grimuar: wlasny dymek z polskimi literami (15.11, gracz: zrzut dymku „du□e ulepszenie”, „Prowad□ do oddania”).
-- Czcionka dymkow gry (GameTooltipText) nie ma ą ć ę ł ń ś ź ż, a ramek Blizzarda poza przezroczystoscia nie zmieniamy.
-- G.TT to posrednik z tym samym API co GameTooltip; wszystkie dymki Grimuara ida przez niego:
-- * napisy (SetText, AddLine, AddDoubleLine) trafiaja do wlasnego dymku GrimuarTooltip (GameTooltipTemplate) z czcionka
--   motywu (G.uiFont, gdy gra ja wczyta, inaczej ARIALN z polskimi literami);
-- * dymek gry: kazde inne Set* (SetItemByID, SetSpellByID, SetBagItem, SetLootItem, SetHyperlink...) przelacza na
--   GameTooltip, wiec Pawn, ceny i linie innych addonow zostaja; polskie linie dodane potem (AddLine) pokazuja sie
--   w malym dymku Grimuara tuz pod nim.
-- Zaczepy dymkow gry (TooltipDataProcessor, HookScript) dalej pisza do GameTooltip.
local ADDON_NAME, G = ...

local ARIALN = "Fonts\\ARIALN.TTF"
local own, extra
local P = { mode = "text", args = nil, extraN = 0 }

local function make(name)
  local t = CreateFrame("GameTooltip", name, UIParent, "GameTooltipTemplate")
  t:SetFrameStrata("TOOLTIP")
  t:SetClampedToScreen(true)
  return t
end

local function fixFonts(tt)
  if not tt then return end
  local name = tt:GetName()
  local path = (G.uiFont and G.uiFont("body")) or ARIALN
  for i = 1, tt:NumLines() or 0 do
    for _, side in ipairs({ "Left", "Right" }) do
      local fs = _G[name .. "Text" .. side .. i]
      if fs then
        -- 15.11 (gracz: „zepsula sie wielkosc”): staly rozmiar jak w dymku gry (+1 dla waskiej czcionki), a nie
        -- „obecny + 1”, bo te same napisy wracaja przy kazdym pokazaniu i dymek rosl z kazdym najechaniem
        local size = (i == 1) and 15 or 13
        local ok, res = pcall(fs.SetFont, fs, path, size, "")
        if not ok or res == false then pcall(fs.SetFont, fs, ARIALN, size, "") end
      end
    end
  end
end

local function ensureOwn()
  if not own then own = make("GrimuarTooltip") end
  if not own:GetOwner() then own:SetOwner(UIParent, "ANCHOR_CURSOR") end
  return own
end

local function toGame()
  if P.mode == "game" then return end
  P.mode = "game"
  if own then own:Hide() end
  local a = P.args or { UIParent, "ANCHOR_CURSOR", 0, 0 }
  GameTooltip:SetOwner(a[1], a[2], a[3], a[4])
end

local function extraLine(method, ...)
  if not extra then
    extra = make("GrimuarTooltipExtra")
    pcall(GameTooltip.HookScript, GameTooltip, "OnHide", function() if extra then extra:Hide() end end)
  end
  if P.extraN == 0 then
    extra:SetOwner(GameTooltip, "ANCHOR_NONE")
    extra:ClearAllPoints()
    extra:SetPoint("TOPLEFT", GameTooltip, "BOTTOMLEFT", 0, 2)
  end
  extra[method](extra, ...)
  P.extraN = P.extraN + 1
end

function P:SetOwner(owner, anchor, x, y)
  P.mode, P.extraN = "text", 0
  P.args = { owner or UIParent, anchor or "ANCHOR_RIGHT", x or 0, y or 0 }
  if extra then extra:Hide() end
  if not own then own = make("GrimuarTooltip") end
  own:SetOwner(P.args[1], P.args[2], P.args[3], P.args[4])
end
function P:SetText(...)
  if P.mode == "game" then return GameTooltip:SetText(...) end
  return ensureOwn():SetText(...)
end
function P:AddLine(...)
  if P.mode == "game" then return extraLine("AddLine", ...) end
  return ensureOwn():AddLine(...)
end
function P:AddDoubleLine(...)
  if P.mode == "game" then return extraLine("AddDoubleLine", ...) end
  return ensureOwn():AddDoubleLine(...)
end
function P:Show()
  if P.mode == "game" then
    GameTooltip:Show()
    if extra and P.extraN > 0 then fixFonts(extra) extra:Show() end
    return
  end
  local t = ensureOwn()
  fixFonts(t)
  t:Show()
end
function P:Hide()
  if own then own:Hide() end
  if extra then extra:Hide() end
  GameTooltip:Hide()
end
function P:ClearLines()
  P.extraN = 0
  if extra then extra:Hide() end
  if P.mode == "game" then return GameTooltip:ClearLines() end
  return ensureOwn():ClearLines()
end
function P:IsOwned(f) return (own and own:IsOwned(f)) or GameTooltip:IsOwned(f) end
function P:IsShown() return (own and own:IsShown()) or GameTooltip:IsShown() end
function P:IsVisible() return (own and own:IsVisible()) or GameTooltip:IsVisible() end
function P:GetOwner() if P.mode == "game" then return GameTooltip:GetOwner() end return own and own:GetOwner() end
function P:NumLines() if P.mode == "game" then return GameTooltip:NumLines() end return own and own:NumLines() or 0 end
function P:SetMinimumWidth(...) if P.mode == "game" then return GameTooltip:SetMinimumWidth(...) end return ensureOwn():SetMinimumWidth(...) end
function P:SetPadding(...) if P.mode == "game" then return GameTooltip:SetPadding(...) end return ensureOwn():SetPadding(...) end

-- reszta metod: polozenie i wyglad ramki ida do aktywnego dymku; Set* z trescia gry (przedmiot, czar, link,
-- jednostka...) przelacza na dymek gry; Get*/Is* czytaja aktywny dymek
local FRAME = { SetPoint = true, SetAllPoints = true, ClearAllPoints = true, SetFrameStrata = true, SetFrameLevel = true,
  SetScale = true, SetAlpha = true, SetWidth = true, SetHeight = true, SetSize = true, SetAnchorType = true,
  SetClampedToScreen = true, SetShown = true, AddTexture = true }
setmetatable(P, { __index = function(_, k)
  local gf = GameTooltip[k]
  if type(gf) ~= "function" then return gf end
  return function(_, ...)
    if FRAME[k] then
      if P.mode == "text" then local t = ensureOwn() return t[k](t, ...) end
      return gf(GameTooltip, ...)
    end
    if type(k) == "string" and k:find("^Set") then toGame() return gf(GameTooltip, ...) end
    if P.mode == "text" and own and type(own[k]) == "function" then return own[k](own, ...) end
    return gf(GameTooltip, ...)
  end
end })

G.TT = P
