-- Grimuar: modul PlecakRuny (gracz 13.11: „o cos takiego doslownie chce”, makieta
-- (makieta Grimuara), wariant z podpisami). Baganator w ukladzie i wygladzie Grimuara:
-- 1) grupy po polsku, kazda w osobnym rzedzie (separator „----”): Do walki, Questy, Sprzet, Profesje, Inne, Smieci, Wolne;
--    bez „Recent”; wolne miejsca pojedynczo, jak siatka w Black Desert; 8 kolumn, ikony 40 px, 3 znaczki na ikonie;
-- 2) wyglad Runy na skorce Dark: ciemny braz, zlota ramka i rogi, brazowe sloty, zlote podpisy grup;
-- 3) plecak przyklejony z prawej do okna postaci; bez okna postaci wraca nad menu w prawym dolnym rogu.
-- Uklad raz (plecakV) przez BAGANATOR_CONFIG i publiczne Baganator.API.ImportString; wyglad co sesje przez
-- Baganator.API.Skins.RegisterListener, podpiety przy wczytaniu (Barwy.lua podpinal sie po 6 s, gdy okna juz byly gotowe).
local ADDON_NAME, G = ...
local say = G.say

-- Dwie palety: Runy (braz i zloto, bez Forever Skin) i Forever Skin (jego Style.lua: grafit, czarne kontury 1 px,
-- zloty akcent), zeby plecak pasowal do przebudowanych okien (gracz 13.11: „bagi nie sa w tym stylu”).
local RUNY = { bg = { 0.098, 0.082, 0.059, 0.96 }, edge = { 0.85, 0.71, 0.36, 0.65 }, accent = { 0.85, 0.71, 0.36 },
  slot = { 0.043, 0.035, 0.027, 0.95 }, slotEdge = { 0.23, 0.19, 0.13, 1 }, btnBg = { 0.098, 0.082, 0.059, 0.92 },
  btnEdge = { 0.85, 0.71, 0.36, 0.45 }, corners = true }
local FSS = { bg = { 0.075, 0.08, 0.09, 0.95 }, edge = { 0, 0, 0, 1 }, accent = { 0.95, 0.76, 0.35 },
  slot = { 0.1, 0.1, 0.11, 0.9 }, slotEdge = { 0, 0, 0, 1 }, btnBg = { 0.1, 0.1, 0.11, 0.9 },
  btnEdge = { 0, 0, 0, 1 }, corners = false }
local function theme()
  local ok, loaded = pcall(C_AddOns.IsAddOnLoaded, "ForeverSkin")
  -- 15.11: z lata ForeverSkin w kolorach Grimuara (GRIMUAR_FSS_LATKA) zostaje paleta Grimuara
  return (ok and loaded and not GRIMUAR_FSS_LATKA) and FSS or RUNY
end
local HEARTHSTONE = 6948
local HOME = { "BOTTOMRIGHT", -6, 110 } -- nad menu i torbami w prawym dolnym rogu (Ekran.lua v6)

local function on() return not (GrimuarSetupDB and GrimuarSetupDB.noSkins) end

local function profile()
  local all = BAGANATOR_CONFIG and BAGANATOR_CONFIG.Profiles
  if type(all) ~= "table" then return nil end
  return all[BAGANATOR_CURRENT_PROFILE or "DEFAULT"] or all.DEFAULT
end

-- ---------- 1. uklad (raz) ----------
local function cls(enum)
  local ok, n = pcall(C_Item.GetItemClassInfo, enum)
  return ok and type(n) == "string" and n ~= "" and n:lower() or nil
end
local function kw(key)
  return Syndicator and Syndicator.Locales and Syndicator.Locales[key] or nil
end

-- 14.11 v3 (gracz: „to sortowanie mozemy lepsze zrobic, jest bardzo ogolne”): 8 grup zamiast 5, kazda w swoim rzedzie.
-- Slowa kluczowe wyszukiwarki Syndicatora (lokalizowane, angielski zapas). Pierwszenstwo: smieci i questy przed reszta,
-- lepszy sprzet (wtyczka ulepszen: Pawn) przed zwyklym, ziola i ruda przed materialami.
local GRIM_NAMES = { ["Do walki"] = true, ["DO WALKI"] = true, ["Questy"] = true, ["QUESTY"] = true, ["Sprzęt"] = true,
  ["SPRZĘT"] = true, ["Profesje"] = true, ["PROFESJE"] = true, ["Śmieci"] = true, ["ŚMIECI"] = true,
  ["JEDZENIE I PICIE"] = true, ["MIKSTURY, BANDAŻE, ZWOJE"] = true, ["LEPSZY SPRZĘT"] = true, ["ZIOŁA I RUDA"] = true,
  ["MATERIAŁY"] = true, ["GOTOWANIE"] = true, ["TKANINY"] = true, ["RECEPTURY"] = true }

-- stare grupy Grimuara znikaja z ustawien Baganatora, zanim wejda nowe (import dodaje, nie podmienia)
local function removeOldCategories()
  local p = profile()
  if not (p and type(p.custom_categories) == "table") then return end
  for id, c in pairs(p.custom_categories) do
    if type(c) == "table" and GRIM_NAMES[c.name] then
      p.custom_categories[id] = nil
      if type(p.category_modifications) == "table" then p.category_modifications[id] = nil end
    end
  end
end

local function importCategories()
  local E = Enum.ItemClass
  local function k(key, fallback) return "#" .. (kw(key) or fallback) end
  local quest, trade, recipe = cls(E.Questitem), cls(E.Tradegoods), cls(E.Recipe)
  assert(quest and trade, "brak słów kluczowych wyszukiwania")
  -- v4 (15.11, R28 P1, makieta „Ekwipunek Grimuara” A): Do walki razem (jedzenie, picie, mikstury, bandaze, zwoje,
  -- Hearthstone), Materialy rozbite na Gotowanie, Tkaniny, Ziola i rude, Receptury i reszte materialow
  local cats = {
    { "DO WALKI", k("KEYWORD_FOOD", "food") .. "|" .. k("KEYWORD_DRINK", "drink") .. "|" ..
      k("KEYWORD_SUBCLASS_FOOD_AND_DRINK", "food & drink") .. "|" .. k("KEYWORD_POTION", "potion") .. "|" ..
      k("KEYWORD_SUBCLASS_BANDAGES", "bandages") .. "|" .. k("KEYWORD_SUBCLASS_ELIXIR", "elixir") .. "|" ..
      k("KEYWORD_SUBCLASS_FLASK", "flask") .. "|" .. k("KEYWORD_SUBCLASS_SCROLL", "scroll") .. "|scroll|hearthstone",
      "grim_walka", "D8B25A", 1 },
    { "QUESTY", "#" .. quest, "grim_questy", "D8B25A", 3 },
    -- 15.11 v5 (gracz: „zebym wiecej nie sprzedal przez przypadek pickaxe”): narzedzia profesji po nazwie, przed Sprzetem
    { "PROFESJE", (function()
        -- wyszukiwarka Syndicatora: „-” to zakres, wiec nazwy z myslnikiem zostaja tylko w Porzadkach (G.isProfTool)
        local names = {}
        for _, n in ipairs(G.PROF_TOOL_NAMES or { "mining pick", "skinning knife", "fishing pole" }) do
          if not n:find("-", 1, true) then names[#names + 1] = n end
        end
        return table.concat(names, "|")
      end)(), "grim_profesje", "7DC8E0", 3 },
    { "LEPSZY SPRZĘT", k("KEYWORD_UPGRADE", "upgrade"), "grim_lepszy", "4ED86A", 2 },
    { "SPRZĘT", k("KEYWORD_GEAR", "gear"), "grim_sprzet", "D8B25A", 0 },
    { "GOTOWANIE", k("KEYWORD_SUBCLASS_MEAT", "meat") .. "&#" .. trade, "grim_gotowanie", "D8B25A", 1 },
    { "TKANINY", k("KEYWORD_SUBCLASS_CLOTH", "cloth") .. "&#" .. trade, "grim_tkaniny", "D8B25A", 1 },
    { "ZIOŁA I RUDA", k("KEYWORD_SUBCLASS_HERB", "herb") .. "|" .. k("KEYWORD_SUBCLASS_METAL_AND_STONE", "metal & stone"),
      "grim_ziola", "D8B25A", 1 },
    recipe and { "RECEPTURY", "#" .. recipe, "grim_receptury", "D8B25A", 1 } or nil,
    { "MATERIAŁY", "#" .. trade .. "|" .. k("KEYWORD_REAGENT", "reagent"), "grim_materialy", "D8B25A", 0 },
    { "ŚMIECI", k("KEYWORD_JUNK", "junk"), "grim_smieci", "9A917F", 3 },
  }
  local packed = {}
  for i = 1, 12 do if cats[i] then packed[#packed + 1] = cats[i] end end
  cats = packed
  local data = { version = 3, addon = "Baganator", kind = "categories", categories = {}, modifications = {},
    sections = {}, hidden = {}, order = {} }
  for _, c in ipairs(cats) do
    data.categories[#data.categories + 1] = { name = c[1], search = c[2], source = c[3] }
    data.modifications[#data.modifications + 1] = { source = c[3], color = c[4], priority = c[5] }
  end
  for _, src in ipairs({ "grim_walka", "----", "grim_questy", "----", "grim_profesje", "----", "grim_lepszy", "----", "grim_sprzet", "----",
    "grim_gotowanie", "----", "grim_tkaniny", "----", "grim_ziola", "----", recipe and "grim_receptury" or "----", "----",
    "grim_materialy", "----", "default_other", "----", "grim_smieci", "----", "default_special_empty" }) do
    data.order[#data.order + 1] = src
  end
  local enc = C_EncodingUtil
  local str = "BGR!1!" .. enc.EncodeBase64(enc.CompressString(enc.SerializeCBOR(data)))
  Baganator.API.ImportString(str, "Grimuar")
end

local function applySettings()
  local p = profile()
  assert(type(p) == "table", "brak profilu Baganatora")
  p.bag_view_type = "category"
  p.bag_view_width = 8
  p.bag_icon_size = 40
  p.category_group_empty_slots = false
  p.category_item_grouping = true
  p.icon_top_left_corner_array = { "pawn", "polestar_upgrade" }
  p.icon_top_right_corner_array = { "polestar_quest_needed", "grimuar_fav" }
  p.icon_bottom_left_corner_array = { "grimuar_need" }
  p.icon_bottom_right_corner_array = { "quantity" }
  p.current_skin = "dark"
  p.skins = p.skins or {}
  p.skins.dark = p.skins.dark or {}
  p.skins.dark.view_transparency = 0.04
  p.skins.dark.no_frame_borders = true
  p.skins.dark.square_icons = true
  p.skins.dark.empty_slot_background = false
  p.bag_view_position = { HOME[1], HOME[2], HOME[3] }
end

local function setupOnce()
  if (GrimuarSetupDB.plecakV or 0) >= 1 or InCombatLockdown() then return end
  if not (Baganator and Baganator.API and Baganator.API.ImportString and C_EncodingUtil and C_EncodingUtil.SerializeCBOR) then return end
  local okS, errS = pcall(applySettings)
  local okI, errI = pcall(importCategories)
  if not (okS and okI) then
    say("plecak: nie udało się ustawić Baganatora (" .. tostring(errS or errI) .. "). " .. G.helpHint() .. "")
    return
  end
  GrimuarSetupDB.plecakV = 4
  say("plecak w stylu Grimuara: grupy po polsku w rzędach, bez Recent, 8 kolumn. Wpisz /reload, żeby zobaczyć nowy wygląd.")
  pcall(G.showToast, "wpisz /reload: nowy plecak (grupy po polsku, styl Grimuara).", "", false)
end

-- ---------- 2. wyglad Runy ----------
local styled = setmetatable({}, { __mode = "k" })
local backpacks = setmetatable({}, { __mode = "k" })

local function frameEdge(f, inset, r, g, b, a, layer, sub)
  local function line(p1, p2, w, h)
    local t = f:CreateTexture(nil, layer or "BORDER", nil, sub or 7)
    t:SetColorTexture(r, g, b, a)
    t:SetPoint(p1, f, p1, (p1:find("LEFT") and inset or -inset), (p1:find("TOP") and -inset or inset))
    t:SetPoint(p2, f, p2, (p2:find("LEFT") and inset or -inset), (p2:find("TOP") and -inset or inset))
    if w then t:SetWidth(w) else t:SetHeight(h) end
  end
  line("TOPLEFT", "TOPRIGHT", nil, 1)
  line("BOTTOMLEFT", "BOTTOMRIGHT", nil, 1)
  line("TOPLEFT", "BOTTOMLEFT", 1, nil)
  line("TOPRIGHT", "BOTTOMRIGHT", 1, nil)
end

local function paintButton(b, T)
  local function rest()
    pcall(function()
      b:SetBackdropColor(unpack(T.btnBg))
      b:SetBackdropBorderColor(unpack(T.btnEdge))
    end)
  end
  rest()
  pcall(function()
    b:HookScript("OnEnter", function()
      if b.IsEnabled and b:IsEnabled() then pcall(b.SetBackdropBorderColor, b, T.accent[1], T.accent[2], T.accent[3], 1) end
    end)
    b:HookScript("OnLeave", rest)
  end)
end

local function style(details)
  if type(details) ~= "table" then return end
  local t, f = details.regionType, details.region
  if not f or styled[f] then return end
  local tags = {}
  for _, tag in ipairs(details.tags or {}) do tags[tag] = true end
  if t == "ButtonFrame" and tags.backpack then backpacks[f] = true end -- przyklejanie do postaci takze bez skorek
  if not on() then return end
  styled[f] = true
  local T = theme()
  local A = T.accent
  if t == "ButtonFrame" then
    pcall(function()
      f:SetBackdropColor(unpack(T.bg))
      f:SetBackdropBorderColor(0, 0, 0, 0)
    end)
    pcall(frameEdge, f, 0, T.edge[1], T.edge[2], T.edge[3], T.edge[4], "BORDER", 7)
    if T.corners and G.addRuneCorners then pcall(G.addRuneCorners, f, 18) end
    pcall(function()
      local tt = (f.TitleContainer and f.TitleContainer.TitleText) or f.TitleText
      if tt then tt:SetTextColor(A[1], A[2], A[3]) end
    end)
  elseif t == "ItemButton" then
    pcall(function()
      if f.SlotBackground then
        f.SlotBackground:SetColorTexture(unpack(T.slot))
        f.SlotBackground:ClearAllPoints()
        f.SlotBackground:SetAllPoints(f)
      end
    end)
    pcall(frameEdge, f, 0, T.slotEdge[1], T.slotEdge[2], T.slotEdge[3], T.slotEdge[4], "BACKGROUND", 2)
  elseif t == "Button" or t == "IconButton" then
    paintButton(f, T)
  elseif t == "Divider" then
    -- linia miedzy grupami: cienka zlota, gasnaca w prawo (jak na makiecie), zamiast szarej ramki Blizzarda
    pcall(function()
      f:SetTexture("Interface\\Buttons\\WHITE8X8")
      f:SetHeight(1)
      f:ClearAllPoints()
      f:SetPoint("TOPLEFT", f:GetParent(), "TOPLEFT", 0, -2)
      f:SetPoint("TOPRIGHT", f:GetParent(), "TOPRIGHT", 0, -2)
      f:SetGradient("HORIZONTAL", CreateColor(A[1], A[2], A[3], 0.55), CreateColor(A[1], A[2], A[3], 0))
    end)
  elseif t == "SearchBox" or t == "EditBox" then
    pcall(function()
      for _, k in ipairs({ "Left", "Middle", "Right", "Mid" }) do if f[k] then f[k]:SetAlpha(0) end end
      local bg = f:CreateTexture(nil, "BACKGROUND", nil, -8)
      bg:SetPoint("TOPLEFT", -4, 2)
      bg:SetPoint("BOTTOMRIGHT", 2, -2)
      bg:SetColorTexture(0, 0, 0, 0.45)
    end)
  end
end

-- ---------- 3. plecak przy oknie postaci ----------
-- gracz 13.11: „panel po lewej zasloniety”: okno postaci Forever Skin otwiera sie w lewym gornym rogu (16, -116),
-- na sciadze Combo i okienku Profesje. Z tego domyslnego miejsca przesuwamy je zaraz za te panele (przeciagniete
-- recznie zostaje tam, gdzie je postawisz); plecak musi sie zmiescic z prawej.
local function placeFssChar(cf)
  if cf ~= _G.ForeverSkinCharacterFrame then return end
  pcall(function()
    cf:SetClampedToScreen(true)
    local p, rel, _, x, y = cf:GetPoint(1)
    if not (p == "TOPLEFT" and (rel == nil or rel == UIParent) and math.abs((x or 0) - 16) < 2 and math.abs((y or 0) + 116) < 2) then return end
    local k = UIParent:GetEffectiveScale() / cf:GetEffectiveScale()
    local left = 16
    for _, n in ipairs({ "GrimuarRunyCombo", "GrimuarProfPanel" }) do
      local f = _G[n]
      if f and f:IsShown() and f:GetRight() then left = math.max(left, (f:GetRight() + 12) * k) end
    end
    local bagW = 0
    for b in pairs(backpacks) do bagW = math.max(bagW, (b:GetWidth() or 0) * b:GetEffectiveScale() / cf:GetEffectiveScale()) end
    local maxLeft = UIParent:GetWidth() * k - cf:GetWidth() - bagW - 16
    left = math.max(16, math.min(left, maxLeft))
    cf:ClearAllPoints()
    cf:SetPoint("TOPLEFT", UIParent, "TOPLEFT", left, -116)
  end)
end

local function attach(f)
  local cf = G.charWindow and G.charWindow()
  if not cf or GrimuarSetupDB.noBagsWithChar then return end
  placeFssChar(cf)
  pcall(function()
    f:SetClampedToScreen(true)
    f:ClearAllPoints()
    f:SetPoint("TOPLEFT", cf, "TOPRIGHT", 6, 0)
  end)
end

local function home(f)
  local p = profile()
  local pos = (p and type(p.bag_view_position) == "table" and p.bag_view_position[1]) and p.bag_view_position or HOME
  pcall(function()
    f:ClearAllPoints()
    if type(pos[2]) == "string" then f:SetPoint(unpack(pos)) else f:SetPoint(pos[1], UIParent, pos[1], pos[2] or 0, pos[3] or 0) end
  end)
end

local function hookBackpacks()
  for f in pairs(backpacks) do
    if not f.grimuarAttach then
      f.grimuarAttach = true
      f:HookScript("OnShow", function(self) C_Timer.After(0, function() if self:IsShown() then attach(self) end end) end)
    end
  end
  G.plecakCharHooked = G.plecakCharHooked or {}
  for _, cf in ipairs({ _G.CharacterFrame, _G.ForeverSkinCharacterFrame }) do
    if cf and not G.plecakCharHooked[cf] then
      G.plecakCharHooked[cf] = true
      cf:HookScript("OnShow", function()
        C_Timer.After(0.15, function() for f in pairs(backpacks) do if f:IsShown() then attach(f) end end end)
      end)
      cf:HookScript("OnHide", function()
        C_Timer.After(0.05, function()
          if G.charWindow and G.charWindow() then return end
          for f in pairs(backpacks) do if f:IsShown() then home(f) end end
        end)
      end)
    end
  end
  -- okno postaci Forever Skin powstaje przy pierwszym otwarciu
  if not G.plecakToggleHooked and ToggleCharacter then
    G.plecakToggleHooked = true
    hooksecurefunc("ToggleCharacter", function()
      C_Timer.After(0.2, function()
        pcall(hookBackpacks)
        for f in pairs(backpacks) do if f:IsShown() then attach(f) end end
      end)
    end)
  end
end

-- Podpisy grup (szablon Baganatora, czcionka GameFontNormal bez polskich liter: „Sprz□t”): nasza czcionka ARIALN,
-- zlota. Podpiete pod OnLoad szablonu, zanim Baganator zbuduje okno (przy PLAYER_LOGIN albo pierwszym otwarciu).
local headerFont
local function headerFontObj()
  if headerFont then return headerFont end
  headerFont = CreateFont("GrimuarBagHeaderFont")
  headerFont:SetFont(G.BF(), 12, "")
  local A = theme().accent
  headerFont:SetTextColor(A[1], A[2], A[3])
  headerFont:SetShadowColor(0, 0, 0, 1)
  headerFont:SetShadowOffset(1, -1)
  return headerFont
end
if BaganatorCategoryViewsCategoryButtonMixin and BaganatorCategoryViewsCategoryButtonMixin.OnLoad then
  hooksecurefunc(BaganatorCategoryViewsCategoryButtonMixin, "OnLoad", function(self)
    if not on() then return end
    pcall(function() self:SetNormalFontObject(headerFontObj()) end)
  end)
end

-- 13.11 v2: nazwy grup wielkimi literami, jak na makiecie (zmiana w zapisanych kategoriach, widoczna po /reload)
local UPPER = { ["Do walki"] = "DO WALKI", ["Questy"] = "QUESTY", ["Sprzęt"] = "SPRZĘT", ["Profesje"] = "PROFESJE", ["Śmieci"] = "ŚMIECI" }
local function upperNames()
  if (GrimuarSetupDB.plecakV or 0) ~= 1 then return end
  local p = profile()
  if not (p and type(p.custom_categories) == "table") then return end
  for _, c in pairs(p.custom_categories) do
    if type(c) == "table" and UPPER[c.name] then c.name = UPPER[c.name] end
  end
  GrimuarSetupDB.plecakV = 2
end

-- podpiecie wygladu od razu przy wczytaniu (Baganator laduje sie przed Grimuarem), Barwy.lua juz nie podpina swojego
if Baganator and Baganator.API and Baganator.API.Skins and Baganator.API.Skins.RegisterListener then
  G.bagListener = true
  Baganator.API.Skins.RegisterListener(function(details) pcall(style, details) end)
end

local ev = CreateFrame("Frame")
ev:RegisterEvent("PLAYER_LOGIN")
ev:SetScript("OnEvent", function()
  C_Timer.After(1, function()
    -- okna, ktore Baganator zbudowal, zanim podpielismy wyglad
    pcall(function()
      for _, details in ipairs(Baganator.API.Skins.GetAllFrames() or {}) do pcall(style, details) end
    end)
    pcall(hookBackpacks)
  end)
  C_Timer.After(7, function() pcall(setupOnce) pcall(upperNames) pcall(G.plecakRegroup) end)
end)

G.plecakSetup = setupOnce

-- v4 dla plecakow ustawionych wczesniej (plecakV 1-3): grupy v4 i znaczki Grimuara (Plecak+, PlecakPlus.lua)
local function regroup()
  local v = GrimuarSetupDB.plecakV or 0
  if v < 1 or v >= 5 or InCombatLockdown() then return end
  if not (Baganator and Baganator.API and Baganator.API.ImportString) then return end
  pcall(removeOldCategories)
  local ok, err = pcall(importCategories)
  if not ok then say("plecak: nie udało się przebudować grup (" .. tostring(err) .. "). " .. G.helpHint() .. "") return end
  pcall(function()
    local p = profile()
    if not p then return end
    local tr = p.icon_top_right_corner_array or {}
    local has = false
    for _, x in ipairs(tr) do if x == "grimuar_fav" then has = true end end
    if not has then tr[#tr + 1] = "grimuar_fav" end
    p.icon_top_right_corner_array = tr
    local bl = p.icon_bottom_left_corner_array or {}
    has = false
    for _, x in ipairs(bl) do if x == "grimuar_need" then has = true end end
    if not has then table.insert(bl, 1, "grimuar_need") end
    p.icon_bottom_left_corner_array = bl
  end)
  GrimuarSetupDB.plecakV = 5
  say("plecak+: Do walki, Questy, Profesje (narzędzia), Sprzęt, Gotowanie, Tkaniny, Zioła i ruda, Receptury, Materiały, Inne, Śmieci; ◆ potrzebne, ★ ulubione (Alt+prawy klik), przyciski na dole. Wpisz /reload.")
end
G.plecakRegroup = regroup
-- 14.11: hub (GrimuarUI) przypina plecak w zakladce Postac; ramki plecaka z sluchacza skorek Baganatora
G.plecakFrames = function() return backpacks end
