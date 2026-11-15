-- Grimuar: modul Skorki. Wyglad Blizzarda w stylu Runy (makiety 13.11, research R14):
-- 1) dymki: ciemny braz, zlota ramka (przedmioty: kolor jakosci), tytul czcionka motywu, zlote naroznik;
-- 2) okna: postac, kupiec, trener, poczta, lupy, bank, rozmowy i questy: zabarwione ramki i tlo, zloty tytul, naroznik;
-- 3) czcionki gry: obiekty czcionek na czcionki motywu (Alegreya z Media), gdy gra je wczyta.
-- 4) minimapa (13.11, punkt 6): zlocony pierscien i pasek strefy, czcionki motywu; kolor nazwy strefy zostaje
--    (gra barwi ja wg PvP: czerwona = teren wroga, wazne na serwerze PvP).
-- Ksiegi czarow i talentow nie ruszamy (ryzyko bledow gry, R14). Wszystko w pcall; /gr skorki wlacza i wylacza.
local ADDON_NAME, G = ...

local GOLD = { 0.85, 0.71, 0.36 }
local BG = { 0.067, 0.059, 0.047, 0.96 }
-- 13.11: z Forever Skin (gotowy wyglad calego UI pod Forever, wybor gracza) podpowiedzi i okna gry robi on; Grimuar ich
-- nie przemalowuje, zeby dwie skorki sie nie gryzly (R14: „dwa skorkowacze naraz sie gryza”). Torby, czat, minimapa,
-- menu Esc i okna Grimuara zostaja nasze.
-- Wykrywany w chwili uzycia: przy wczytaniu Grimuara Forever Skin mogl jeszcze nie byc zaladowany (13.11: fssOnce nie ruszyl).
local function fssLoaded()
  local ok, loaded = pcall(C_AddOns.IsAddOnLoaded, "ForeverSkin")
  G.fss = ok and loaded and true or false
  return G.fss
end
local function on() return not GrimuarSetupDB.noSkins and not fssLoaded() end

-- ---------- 1. dymki ----------
local TIPS = { "GameTooltip", "ItemRefTooltip", "ShoppingTooltip1", "ShoppingTooltip2", "EmbeddedItemTooltip" }

local function qualityColor(tt)
  local r, g, b
  pcall(function()
    local _, link = tt:GetItem()
    if not link then return end
    local q = C_Item.GetItemQualityByID(link)
    if q and q >= 2 then
      local c = (ITEM_QUALITY_COLORS and ITEM_QUALITY_COLORS[q]) or nil
      if c then r, g, b = c.r, c.g, c.b else r, g, b = C_Item.GetItemQualityColor(q) end
    end
  end)
  return r, g, b
end

local function paintTip(tt)
  if not on() or not tt or not tt.NineSlice then return end
  pcall(function()
    tt.NineSlice:SetCenterColor(BG[1], BG[2], BG[3], BG[4])
    local r, g, b = qualityColor(tt)
    if r then tt.NineSlice:SetBorderColor(r, g, b, 1) else tt.NineSlice:SetBorderColor(GOLD[1], GOLD[2], GOLD[3], 0.9) end
  end)
end

local function hookTips()
  pcall(function()
    TooltipDataProcessor.AddTooltipPostCall(TooltipDataProcessor.AllTypes, function(tt) paintTip(tt) end)
  end)
  for _, n in ipairs(TIPS) do
    local tt = _G[n]
    if tt then
      pcall(function() tt:HookScript("OnShow", paintTip) end)
      if G.addRuneCorners and on() then pcall(G.addRuneCorners, tt, 14) end
    end
  end
end

-- ---------- 2. okna Blizzarda ----------
local skinned = {}
local pending = {}

local function tintRegions(frame, r, g, b, a)
  if not frame or not frame.GetRegions then return end
  for _, rg in ipairs({ frame:GetRegions() }) do
    if rg.SetVertexColor and rg.GetObjectType and rg:GetObjectType() == "Texture" then pcall(rg.SetVertexColor, rg, r, g, b, a) end
  end
end

local function skinFrame(f)
  if not on() or not f or skinned[f] then return end
  if InCombatLockdown() then pending[f] = true return end
  skinned[f] = true
  pcall(function()
    if f.NineSlice then tintRegions(f.NineSlice, 0.95, 0.8, 0.5, 1) end
    if f.Bg then f.Bg:SetVertexColor(0.42, 0.35, 0.26, 1) end
    if f.Inset then
      if f.Inset.Bg then f.Inset.Bg:SetVertexColor(0.36, 0.3, 0.22, 1) end
      if f.Inset.NineSlice then tintRegions(f.Inset.NineSlice, 0.7, 0.58, 0.36, 1) end
    end
    local title = (f.TitleContainer and f.TitleContainer.TitleText) or f.TitleText
    if not title and f.GetTitleText then title = f:GetTitleText() end
    if title then
      title:SetTextColor(GOLD[1], GOLD[2], GOLD[3])
      local _, size = title:GetFont()
      if G.TF then title:SetFont(G.TF(), (size or 13) + 1, "") end
    end
  end)
  if G.addRuneCorners then pcall(G.addRuneCorners, f, 20) end
end

local WINDOWS = { "CharacterFrame", "MerchantFrame", "MailFrame", "LootFrame", "BankFrame", "GossipFrame", "QuestFrame",
  "ClassTrainerFrame", "TradeFrame", "DressUpFrame", "AuctionHouseFrame" }

local function skinAll()
  for _, n in ipairs(WINDOWS) do
    local f = _G[n]
    if f then
      skinFrame(f)
      if not f.grimuarHooked then
        f.grimuarHooked = true
        pcall(function() f:HookScript("OnShow", skinFrame) end)
      end
    end
  end
end

-- ---------- 3. czcionki gry ----------
local TITLE_OBJ = { "GameFontNormalLarge", "GameFontNormalHuge", "GameFontHighlightLarge", "GameFontHighlightHuge",
  "QuestTitleFont", "QuestTitleFontBlackShadow", "QuestFont_Huge", "Fancy16Font", "Fancy22Font", "Fancy24Font",
  "GameTooltipHeaderText", "SystemFont_Large", "SystemFont_Huge1", "SystemFont_Shadow_Large", "SystemFont_Shadow_Huge1" }
local BODY_OBJ = { "GameFontNormal", "GameFontNormalSmall", "GameFontHighlight", "GameFontHighlightSmall", "GameFontDisable",
  "GameFontDisableSmall", "GameFontWhite", "GameFontRed", "GameFontGreen", "GameTooltipText", "GameTooltipTextSmall",
  "SystemFont_Small", "SystemFont_Med1", "SystemFont_Med2", "SystemFont_Med3", "SystemFont_Shadow_Small", "SystemFont_Shadow_Med1",
  "SystemFont_Shadow_Med2", "SystemFont_Shadow_Med3", "QuestFont", "QuestFont_Large", "MailTextFontNormal", "ChatFontNormal", "ChatFontSmall" }

local function setFonts()
  if not on() or GrimuarSetupDB.noGameFonts or not G.customFonts then return 0 end
  local n = 0
  local function apply(list, path)
    for _, name in ipairs(list) do
      local obj = _G[name]
      if obj and obj.GetFont then
        local okF = pcall(function()
          local _, size, flags = obj:GetFont()
          obj:SetFont(path, size or 13, flags or "")
        end)
        if okF then n = n + 1 end
      end
    end
  end
  apply(TITLE_OBJ, G.TF())
  apply(BODY_OBJ, G.BF())
  STANDARD_TEXT_FONT = G.BF()
  UNIT_NAME_FONT = G.BF()
  return n
end
-- 13.11 gracz („czemu dalej nie ma polskich znakow”, dymek „Ko□cz□ gr□”): Forever nie wczytuje czcionek z addonow
-- (customFonts=false), wiec setFonts nic nie robi, a czcionka dymkow i czerwonych komunikatow gry nie ma polskich liter.
-- Te obiekty dostaja ARIALN z polskimi literami (rozmiar i obrys zostaja), takze bez motywu czcionek.
local POLISH_OBJ = { "GameTooltipHeaderText", "GameTooltipText", "GameTooltipTextSmall", "Tooltip_Med", "Tooltip_Small", "ErrorFont" }
local function polishFonts()
  if GrimuarSetupDB.noGameFonts or G.customFonts then return end
  for _, name in ipairs(POLISH_OBJ) do
    local obj = _G[name]
    if obj and obj.GetFont then
      pcall(function()
        local _, size, flags = obj:GetFont()
        obj:SetFont(G.BF(), size or 13, flags or "")
      end)
    end
  end
end

-- Liczby obrazen: gra czyta te zmienna przy starcie, wiec ustawiamy ja od razu przy wczytaniu addonu
if G.customFonts and not (GrimuarSetupDB and (GrimuarSetupDB.noSkins or GrimuarSetupDB.noGameFonts)) then
  DAMAGE_TEXT_FONT = G.TF()
end

-- ---------- 4. minimapa ----------
local function skinMinimap()
  if not on() then return end
  pcall(function() if MinimapCompassTexture then MinimapCompassTexture:SetVertexColor(1, 0.86, 0.55) end end)
  pcall(function()
    local bt = MinimapCluster and MinimapCluster.BorderTop
    if bt and bt.GetObjectType and bt:GetObjectType() == "Texture" then bt:SetVertexColor(0.95, 0.8, 0.5, 1)
    elseif bt then tintRegions(bt, 0.95, 0.8, 0.5, 1) end
  end)
  if G.customFonts and not GrimuarSetupDB.noGameFonts then
    pcall(function()
      local _, size = MinimapZoneText:GetFont()
      MinimapZoneText:SetFont(G.TF(), size or 12, "")
    end)
    pcall(function()
      local _, size, flags = TimeManagerClockTicker:GetFont()
      TimeManagerClockTicker:SetFont(G.BF(), size or 12, flags or "")
    end)
  end
end

-- Forever Skin raz (fssV): przebudowane okna wlaczone (postac, kupiec, trener, poczta, bank, ksiega, profesje, talenty,
-- handel); menu Esc zostaje nasze (przyciski Grimuar, Plan sesji, Konczę gre); tabliczki zostaja z BetterBlizzPlates,
-- paski z Masque i stylem Runy, torby z Baganatorem. Dziala po kolejnym /reload.
local FSS_PREFS = {
  rebuiltCharacter = true, rebuiltMerchant = true, rebuiltTrainer = true, rebuiltMail = true, rebuiltBank = true,
  rebuiltSpellbook = true, rebuiltProfessions = true, rebuiltTalents = true, rebuiltTrade = true,
  rebuiltMenu = false, nameplates = false, bags = false,
  actionBars = true, -- v2 (13.11): gracz chce paski w stylu Forever Skin; skorke Masque wylacza Maska.lua
  -- v3 (13.11: „moje paski i targetu troche wieksze”): paski ramek Ty i cel dluzsze o 60 px i grubsze o 6 px
  playerLength = 60, targetLength = 60, playerHeight = 6, targetHeight = 6,
  -- v4 (14.11: „nakladka nie weszla na wszystko”, okno Options): reszta przebudowanych okien
  rebuiltOptions = true, rebuiltMacros = true, rebuiltSocial = true, rebuiltGuild = true, lfgWindow = true,
}
local function fssOnce()
  if not fssLoaded() or (GrimuarSetupDB.fssV or 0) >= 4 or type(ForeverSkinDB) ~= "table" then return end
  GrimuarSetupDB.fssV = 4
  local changed = false
  for k, v in pairs(FSS_PREFS) do
    if ForeverSkinDB[k] ~= v then ForeverSkinDB[k] = v changed = true end
  end
  if changed then
    pcall(G.say, "Forever Skin: przebudowane wszystkie okna (też opcje gry, makra, znajomi, gildia, szukanie grupy). Wpisz /reload.")
    pcall(G.showToast, "wpisz /reload: przebudowane okna Forever Skin.", "", false)
  end
end

local ev = CreateFrame("Frame")
ev:RegisterEvent("PLAYER_LOGIN")
ev:RegisterEvent("ADDON_LOADED")
ev:RegisterEvent("PLAYER_REGEN_ENABLED")
ev:SetScript("OnEvent", function(_, event, name)
  if event == "PLAYER_LOGIN" then
    pcall(hookTips)
    pcall(skinAll)
    pcall(setFonts)
    pcall(polishFonts)
    C_Timer.After(3, function() pcall(fssOnce) end)
    pcall(skinMinimap)
    -- R21: maksymalne przyblizenie minimapy chowa ziola i wrogow; porada raz
    C_Timer.After(20, function()
      pcall(function()
        if GrimuarSetupDB.zoomTip or not Minimap or not Minimap.GetZoom or IsIndoors() then return end
        if Minimap:GetZoom() >= 4 and G.showToast then
          GrimuarSetupDB.zoomTip = true
          G.showToast("oddal minimapę kółkiem myszy do 1–2: zobaczysz więcej ziół, rudy i wrogów.", "track", false)
        end
      end)
    end)
  elseif event == "ADDON_LOADED" then
    if name == "Blizzard_TimeManager" then C_Timer.After(0, function() pcall(skinMinimap) end) end
    if name == "Blizzard_TrainerUI" or name == "Blizzard_ClassTrainerUI" or name == "Blizzard_AuctionHouseUI" then C_Timer.After(0, function() pcall(skinAll) end) end
  elseif event == "PLAYER_REGEN_ENABLED" then
    for f in pairs(pending) do pending[f] = nil pcall(skinFrame, f) end
  end
end)

G.skinFrame = skinFrame
G.setGameFonts = setFonts
G.skinMinimap = skinMinimap
