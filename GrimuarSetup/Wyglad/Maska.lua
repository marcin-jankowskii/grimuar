-- Grimuar: modul Maska. Skorka Masque „Grimuar Runy” (makieta 13.11, Masque 12.1.8 + Masque Blizzard Bars 12.1.5.0):
-- kwadratowe przyciski z przyblizonymi ikonami (szablon Zoomed), ciemnobrazowe tlo i zlota ramka z runa (Media/przycisk.tga).
-- Raz ustawiamy ja jako skorke glownej grupy Masque (dziedzicza ja wszystkie grupy, tez paski Blizzarda i odnowienia).
-- Pozniej mozna ja zmienic w opcjach Masque (/msq). Gdy Masque dziala, nasze cienkie ramki 1px z Runy.lua sie wylaczaja.
local ADDON_NAME, G = ...
local say = G.say

local SKIN = "Grimuar Runy"
local MSQ = LibStub and LibStub("Masque", true)

if MSQ then
  pcall(function()
    MSQ:AddSkin(SKIN, {
      API_VERSION = 120001,
      Shape = "Square",
      Template = "Zoomed",
      Author = "Grimuar",
      Version = "1.0",
      Description = "Złota ramka w stylu Pustynia i Runy.",
      Backdrop = { Color = { 0.067, 0.059, 0.047, 0.9 }, UseColor = true },
      Normal = {
        Texture = "Interface\\AddOns\\GrimuarSetup\\Media\\przycisk",
        Color = { 1, 1, 1, 1 },
        EmptyColor = { 1, 1, 1, 0.55 },
        Width = 42,
        Height = 42,
      },
    })
  end)
  G.masqueSkin = SKIN
end

local function setDefaultSkin()
  if not MSQ or GrimuarSetupDB.msqV == 1 then return end
  local ok = pcall(function()
    local root = MSQ:Group("Masque")
    if root and root.__Set then root:__Set("SkinID", SKIN) end
  end)
  if ok then
    GrimuarSetupDB.msqV = 1
    say("przyciski: skórka Masque „Grimuar Runy” ustawiona. Zmienisz ją w opcjach Masque (/msq).")
  end
end

-- 13.11: paski w stylu Forever Skin (wybor gracza): dwie skorki na tych samych przyciskach sie gryza, wiec glowna
-- grupa Masque (a z nia paski Blizzarda i odnowienia) zostaje wylaczona, tak jak przelacznik w opcjach Masque (/msq).
local function fssBars()
  local ok, loaded = pcall(C_AddOns.IsAddOnLoaded, "ForeverSkin")
  return ok and loaded and type(ForeverSkinDB) == "table" and ForeverSkinDB.actionBars ~= false
end
local function masqueOffForFss()
  if not (MSQ and fssBars()) then return end
  local root = MSQ:Group("Masque")
  if root and root.db and not root.db.Disabled and root.__Disable then
    root:__Disable()
    say("przyciski: skórka Masque wyłączona, paski rysuje Forever Skin. Powrót: /msq i odznacz Disable.")
  end
end

local ev = CreateFrame("Frame")
ev:RegisterEvent("PLAYER_LOGIN")
ev:SetScript("OnEvent", function()
  C_Timer.After(4, function()
    if fssBars() then pcall(masqueOffForFss) else pcall(setDefaultSkin) end
  end)
end)

G.masqueActive = function() return MSQ ~= nil end
