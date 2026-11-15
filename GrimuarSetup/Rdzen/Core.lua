-- Grimuar Setup: ustawienia i okno "Grimuar maga" w grze (dla gracz Frost).
-- Opcje (CVar), klawisze, dwa makra, automatyczne ukladanie czarow na paskach,
-- okno z zakladkami jak na stronie, przycisk przy minimapie i porzadek przyciskow addonow.
-- Komendy: /grimuar (okno), /grimuar setup, /grimuar reset, /grimuar ikony. Skrot: Shift+G.

local ADDON_NAME, G = ...
local PREFIX = "|cff5fcdf0Grimuar:|r "
local function say(msg) DEFAULT_CHAT_FRAME:AddMessage(PREFIX .. (G.tr and G.tr(msg) or msg)) end -- E6: G.tr (Locales)

-- ============================================================
-- USTAWIENIA GRY
-- ============================================================
local CVARS = {
  { "nameplateShowEnemies", "1", "tabliczki wrogów" },
  { "autoLootDefault", "1", "automatyczne zbieranie łupów" },
  { "cameraDistanceMaxZoomFactor", "2.6", "większy zoom kamery" },
  { "cameraSmoothStyle", "0", "kamera nie podąża sama" },
  -- R17 (13.11): bez useMaxFPS=1 limit nie dziala; suwak gry ma zakres 8-200 (237 ustawisz w panelu NVIDIA)
  { "useMaxFPS", "1", "limit FPS włączony" },
  { "maxFPS", "200", "limit 200 FPS" },
  { "useMaxFPSBk", "1", "limit FPS w tle włączony" },
  { "maxFPSBk", "30", "limit 30 FPS w tle" },
  -- 14.11 (gracz: „tu 2 razy, nie jest to samo?”): te same czasy odnowienia pokazuje pakiet WeakAuras Musca przy lukach
  -- zycia i many, wiec wbudowany Cooldown Manager gry wylaczony (wlaczysz go w Opcjach gry > Rozgrywka > Walka)
  { "cooldownViewerEnabled", "0", "Cooldown Manager wyłączony (dubluje WeakAuras Musca)", true }, -- tylko tryb prywatny
}

local function getCVar(name)
  local v
  pcall(function()
    if C_CVar and C_CVar.GetCVar then v = C_CVar.GetCVar(name) else v = GetCVar(name) end
  end)
  return v
end

local function setCVar(name, value)
  local ok = pcall(function()
    if C_CVar and C_CVar.SetCVar then C_CVar.SetCVar(name, value) else SetCVar(name, value) end
  end)
  local cur = getCVar(name)
  return ok and cur ~= nil and tonumber(cur) == tonumber(value)
end

local function applyCVars()
  local okList, failList = {}, {}
  for _, c in ipairs(CVARS) do
    if c[4] and not G.personal() then -- preferencja prywatna (Grimuar_Osobiste), w wersji publicznej pomijana
    elseif setCVar(c[1], c[2]) then table.insert(okList, c[3]) else table.insert(failList, c[3]) end
  end
  return okList, failList
end

-- ---------- makra ----------
-- Makra (research R3 11.11): /stopcasting przed Nova i Blinkiem przerywa rzucany czar; Counterspell na focus, gdy go masz.
local MACROS = G.BD.macros -- dane z aktywnego buildu (Build/Api.lua, Buildy/Mag_Frost.lua)
-- Makro trafia na pasek dopiero, gdy znasz jego czar (bez znaku zapytania na pasku).
local MACRO_NEEDS = G.BD.macroNeeds

local function ensureMacros()
  local made = 0
  for _, m in ipairs(MACROS) do
    local idx = GetMacroIndexByName(m[1])
    if idx == 0 then
      local ok, newIdx = pcall(CreateMacro, m[1], "INV_MISC_QUESTIONMARK", m[2], false)
      if ok and newIdx then made = made + 1 end
    else
      local _, _, body = GetMacroInfo(idx)
      if body and body ~= m[2] and not InCombatLockdown() then pcall(EditMacro, idx, nil, nil, m[2]) end
    end
  end
  return made
end

-- ---------- klawisze ----------
-- Pasek 2 (dolny lewy, sloty akcji 61-72) dostaje klawisze wokol WSAD.
local BINDS = G.BD.keys

local function applyBinds()
  local n = 0
  for _, b in ipairs(BINDS) do
    local ok, res = pcall(SetBinding, b[1], b[2])
    if ok and res then n = n + 1 end
  end
  pcall(function() SaveBindings(GetCurrentBindingSet()) end)
  return n
end

-- 15.11 (gracz: „nie widze pod Shift+T nic”): klawisze dopisane do buildu (np. Dampen Magic pod Shift+T) dochodzily
-- tylko przy pelnej konfiguracji albo przez „Napraw” w Kontroli. Teraz po wejsciu i po zmianie buildu Grimuar podpina
-- brakujace klawisze buildu, ale tylko na wolnych klawiszach (cudzego przypisania nie zmienia), poza walka.
local function applyMissingBinds()
  if InCombatLockdown() or not (G.barsAllowed and G.barsAllowed()) then return 0 end
  local n = 0
  for _, b in ipairs(BINDS) do
    local cur = GetBindingAction(b[1])
    if (cur == nil or cur == "") and GetBindingKey(b[2]) == nil then
      local ok, res = pcall(SetBinding, b[1], b[2])
      if ok and res then n = n + 1 end
    elseif cur ~= b[2] and GetBindingKey(b[2]) == nil and not (GrimuarSetupDB.bindTaken or {})[b[1]] then
      -- klawisz zajety czym innym: mowimy raz, czym (gracz decyduje: Kontrola > Napraw albo Ustawienia > Klawisze)
      GrimuarSetupDB.bindTaken = GrimuarSetupDB.bindTaken or {}
      GrimuarSetupDB.bindTaken[b[1]] = true
      local what = (_G["BINDING_NAME_" .. tostring(cur)] or tostring(cur))
      say("klawisz " .. b[1]:gsub("SHIFT%-", "Shift+"):gsub("CTRL%-", "Ctrl+"):gsub("ALT%-", "Alt+") .. " jest zajęty (" .. what ..
        "), więc go nie ruszam. Kontrola > Napraw albo hub > Ustawienia > Klawisze przypnie go do paska buildu.")
    end
  end
  if n > 0 then
    pcall(function() SaveBindings(GetCurrentBindingSet()) end)
    say("nowe klawisze z buildu podpięte: " .. n .. " (tylko wolne klawisze).")
  end
  return n
end
G.applyMissingBinds = applyMissingBinds
do
  local ev = CreateFrame("Frame")
  ev:RegisterEvent("PLAYER_LOGIN")
  ev:SetScript("OnEvent", function() C_Timer.After(10, function() pcall(applyMissingBinds) end) end)
  if G.OnBuildChanged then G.OnBuildChanged(function() C_Timer.After(1, function() pcall(applyMissingBinds) end) end) end
end

local function showBar3()
  pcall(function() Settings.SetValue("PROXY_SHOW_ACTIONBAR_3", true) end)
  if MultiBarBottomRight and MultiBarBottomRight:IsShown() then return true end
  pcall(function() local a, _, c, d, e = GetActionBarToggles() SetActionBarToggles(a, true, c, d, e) end)
  pcall(function() if MultiActionBar_Update then MultiActionBar_Update() end end)
  return MultiBarBottomRight and MultiBarBottomRight:IsShown() or false
end

local function showBar2()
  pcall(function() Settings.SetValue("PROXY_SHOW_ACTIONBAR_2", true) end)
  if MultiBarBottomLeft and MultiBarBottomLeft:IsShown() then return true end
  pcall(function() SetActionBarToggles(true, false, false, false, false) end)
  pcall(function() if MultiActionBar_Update then MultiActionBar_Update() end end)
  return MultiBarBottomLeft and MultiBarBottomLeft:IsShown() or false
end

-- ---------- uklad czarow ----------
-- Kazdy slot: lista kandydatow od najlepszego. Nizszy kandydat moze zostac zastapiony wyzszym
-- (Fireball -> Frostbolt, Frost Armor -> Ice Armor). Zajety slot z czyms innym zostaje nietkniety.
local MAIN = G.BD.main
local BAR2 = G.BD.bar2
-- Pasek 3 (dolny prawy, sloty 49-60): czary pomocnicze, klikane myszą. Wyzsza ranga/wersja zastepuje nizsza.
local BAR3 = G.BD.bar3

local function spellName(id)
  local nm
  pcall(function()
    if C_Spell and C_Spell.GetSpellName then nm = C_Spell.GetSpellName(id) else nm = GetSpellInfo(id) end
  end)
  return nm
end

local function knownSpellId(name)
  local id
  pcall(function()
    if C_Spell and C_Spell.GetSpellInfo then
      local info = C_Spell.GetSpellInfo(name)
      if info then id = info.spellID end
    elseif GetSpellInfo then
      id = select(7, GetSpellInfo(name))
    end
  end)
  if not id then return nil end
  local known = false
  pcall(function()
    known = (IsPlayerSpell and IsPlayerSpell(id)) or (IsSpellKnown and IsSpellKnown(id)) or false
  end)
  if known then return id end
  return nil
end

local function slotContent(slot)
  local t, id = GetActionInfo(slot)
  if t == "spell" and id then return spellName(id) end
  if t == "macro" and id then
    local nm = GetMacroInfo(id)
    if nm then return "macro:" .. nm end
  end
  return t
end

local function onBars(entry)
  for s = 1, 120 do
    if slotContent(s) == entry then return s end
  end
  return nil
end

local function pickup(entry)
  if entry:sub(1, 6) == "macro:" then
    local m = entry:sub(7)
    if GetMacroIndexByName(m) > 0 then PickupMacro(m); return true end
    return false
  end
  local id = knownSpellId(entry)
  if not id then return false end
  if C_Spell and C_Spell.PickupSpell then C_Spell.PickupSpell(id) else PickupSpell(id) end
  return true
end

local function isAvailable(entry)
  if entry:sub(1, 6) == "macro:" then
    local nm = entry:sub(7)
    if GetMacroIndexByName(nm) == 0 then return false end
    local need = MACRO_NEEDS[nm]
    return need == nil or knownSpellId(need) ~= nil
  end
  return knownSpellId(entry) ~= nil
end

-- 15.11 (gracz: „kupiony i nic sie nie stalo” - Dampen Magic): gra sama wklada nowo poznany czar w pierwszy wolny
-- slot, a Grimuar uznawal go wtedy za „juz na paskach” i nie kladl na miejsce z buildu (Shift+T). Liczy sie tylko slot
-- z planu buildu; zajete miejsce z planu Grimuar zglasza raz na sesje zamiast milczec.
local function plannedSlotOf(entry)
  for s = 1, 120 do
    if (MAIN[s] or BAR2[s] or BAR3[s]) and slotContent(s) == entry then return s end
  end
  return nil
end
local conflictSaid = {}
local function placeSlot(slot, cands, placed)
  for i, entry in ipairs(cands) do
    if isAvailable(entry) then
      local cur = HasAction(slot) and slotContent(slot) or nil
      if cur == entry then return end
      if plannedSlotOf(entry) then return end
      if cur then
        local replaceable = false
        for j = i + 1, #cands do if cur == cands[j] then replaceable = true end end
        if not replaceable then
          if not conflictSaid[entry] and i == 1 then
            conflictSaid[entry] = true
            say(entry:gsub("^macro:", "makro ") .. ": jego miejsce na pasku (slot " .. slot .. ") zajmuje " .. tostring(cur) ..
              ". Przeciągnij tamto gdzie indziej, a Grimuar położy czar sam.")
          end
          return
        end
      end
      ClearCursor()
      if pickup(entry) then
        PlaceAction(slot)
        ClearCursor()
        table.insert(placed, (entry:gsub("^macro:", "makro ")))
      end
      return
    end
  end
end

-- Picie pod klawiszem Z (pasek 2, slot 67): najlepsza woda, jaka jest w torbach.
local DRINKS = { "Conjured Crystal Water", "Conjured Sparkling Water", "Conjured Mineral Water", "Conjured Spring Water",
  "Conjured Purified Water", "Conjured Fresh Water", "Conjured Water", "Morning Glory Dew", "Moonberry Juice",
  "Sweet Nectar", "Melon Juice", "Ice Cold Milk", "Refreshing Spring Water" }
local DRINK_SET = {}
for _, nm in ipairs(DRINKS) do DRINK_SET[nm] = true end

local function bagCount(name)
  local ok, c = pcall(function()
    if C_Item and C_Item.GetItemCount then return C_Item.GetItemCount(name) end
    return GetItemCount(name)
  end)
  if ok and type(c) == "number" then return c end
  return 0
end

local function itemNameById(id)
  local nm
  pcall(function()
    if C_Item and C_Item.GetItemNameByID then nm = C_Item.GetItemNameByID(id) else nm = GetItemInfo(id) end
  end)
  return nm
end

-- Picie i jedzenie rozpoznajemy po czarze przedmiotu ("Drink"/"Refreshment", "Food"), a nie po nazwie.
local DRINK_SPELL = { Drink = true, Refreshment = true }
local FOOD_SPELL = { Food = true }

local function scanBySpell(set)
  local list = {}
  for bag = 0, 4 do
    local n = 0
    pcall(function()
      if C_Container and C_Container.GetContainerNumSlots then n = C_Container.GetContainerNumSlots(bag) else n = GetContainerNumSlots(bag) end
    end)
    for slot = 1, (n or 0) do
      local id, count
      pcall(function()
        if C_Container and C_Container.GetContainerItemInfo then
          local info = C_Container.GetContainerItemInfo(bag, slot)
          if info then id, count = info.itemID, info.stackCount end
        else
          id = GetContainerItemID(bag, slot)
          count = select(2, GetContainerItemInfo(bag, slot))
        end
      end)
      if id then
        local spell
        pcall(function()
          if C_Item and C_Item.GetItemSpell then spell = C_Item.GetItemSpell(id) else spell = GetItemSpell(id) end
        end)
        if spell and set[spell] then
          local req = 0
          pcall(function()
            if C_Item and C_Item.GetItemInfo then req = select(5, C_Item.GetItemInfo(id)) or 0 else req = select(5, GetItemInfo(id)) or 0 end
          end)
          local nm = itemNameById(id) or ""
          table.insert(list, { bag = bag, slot = slot, id = id, name = nm, count = count or 1,
            score = (tonumber(req) or 0) + (nm:find("^Conjured") and 0.5 or 0) })
        end
      end
    end
  end
  return list
end

local function scanDrinks() return scanBySpell(DRINK_SPELL) end
local function scanFood() return scanBySpell(FOOD_SPELL) end

local function drinkCount()
  local n = 0
  for _, d in ipairs(scanDrinks()) do n = n + (d.count or 1) end
  return n
end

-- Najlepszy przedmiot z listy (scan) w slocie; nie rusza slotu z czarem ani z innym przedmiotem, ktory masz w torbie.
local function placeBest(slot, scan, label, placed)
  local best
  local drinkIds = {}
  for _, d in ipairs(scan()) do
    drinkIds[d.id] = true
    if not best or d.score > best.score then best = d end
  end
  if not best then return end
  local t, id = GetActionInfo(slot)
  if HasAction(slot) then
    if t ~= "item" then return end
    if id == best.id then return end
    if id and not drinkIds[id] and bagCount(itemNameById(id) or "") > 0 then return end
  end
  ClearCursor()
  local ok = pcall(function()
    if C_Container and C_Container.PickupContainerItem then C_Container.PickupContainerItem(best.bag, best.slot)
    else PickupContainerItem(best.bag, best.slot) end
  end)
  if ok and CursorHasItem and CursorHasItem() then
    PlaceAction(slot)
    table.insert(placed, (best.name ~= "" and best.name or label[1]) .. " pod " .. label[2])
  end
  ClearCursor()
end

local function placeDrink(placed) placeBest(67, scanDrinks, { "picie", "Z" }, placed) end
local function placeFood(placed) placeBest(68, scanFood, { "jedzenie", "X" }, placed) end

-- 14.11 (R27 4a): paski ukladamy tylko za zgoda z kreatora (GrimuarSetupDB.barsConsent) albo w trybie prywatnym
local function barsAllowed() return (G.personal and G.personal()) or (GrimuarSetupDB and GrimuarSetupDB.barsConsent) end
G.barsAllowed = barsAllowed
local function layoutBars(silent)
  if not barsAllowed() then return end
  if InCombatLockdown() then GrimuarSetupDB.pending = true; return end
  local placed = {}
  for slot = 1, 12 do if MAIN[slot] then placeSlot(slot, MAIN[slot], placed) end end
  for slot = 61, 72 do if BAR2[slot] then placeSlot(slot, BAR2[slot], placed) end end
  local before = #placed
  for slot = 49, 60 do if BAR3[slot] then placeSlot(slot, BAR3[slot], placed) end end
  if #placed > before or (GrimuarSetupDB.bar3V ~= 1 and HasAction(49)) then
    GrimuarSetupDB.bar3V = 1
    showBar3()
  end
  pcall(placeDrink, placed)
  pcall(placeFood, placed)
  GrimuarSetupDB.pending = nil
  if #placed > 0 then
    say("na paskach: " .. table.concat(placed, ", "))
  elseif not silent then
    say("paski bez zmian")
  end
end

local function clearMainBar()
  if not barsAllowed() then return false end
  if InCombatLockdown() then return false end
  for slot = 1, 12 do
    if HasAction(slot) then PickupAction(slot); ClearCursor() end
  end
  return true
end

local function charKey()
  return (UnitName("player") or "?") .. "-" .. (GetRealmName() or "?")
end

local function fullSetup()
  local okList, failList = applyCVars()
  local made = ensureMacros()
  local binds = applyBinds()
  local bar2 = showBar2()
  say("ustawione: " .. table.concat(okList, ", ") .. ".")
  if #failList > 0 then say("nie udało się (zrób ręcznie w Opcjach): " .. table.concat(failList, ", ") .. ".") end
  say("klawisze: " .. binds .. " z " .. #BINDS .. ". Makra nowe: " .. made .. ".")
  if not bar2 then say("włącz Action Bar 2 w Opcjach (Action Bars), tam są klawisze Q E R F G T Z X.") end
  GrimuarSetupDB.account = true
end

-- ---------- przyciski addonow przy minimapie ----------
-- Wszystkie addony z LibDBIcon domyslnie stoja na 225 stopniach i nachodza na siebie.
local MM_SLOTS = { 160, 184, 208, 232, 256, 280, 112, 304 }

local function arrangeMinimapIcons(force)
  if GrimuarSetupDB.mmIconsV == 1 and not force then return end
  local lib = LibStub and LibStub("LibDBIcon-1.0", true)
  if not lib or not lib.objects then return end
  local names = {}
  for name, button in pairs(lib.objects) do
    if button and button.IsShown and button:IsShown() then table.insert(names, name) end
  end
  table.sort(names)
  local done = 0
  for i, name in ipairs(names) do
    local angle = MM_SLOTS[i]
    if angle then
      local button = lib.objects[name]
      if button.db then button.db.minimapPos = angle else button.minimapPos = angle end
      if pcall(function() lib:Refresh(name) end) then done = done + 1 end
    end
  end
  GrimuarSetupDB.mmIconsV = 1
  say("przyciski addonów przy minimapie rozłożone: " .. done .. ". Każdy możesz dalej przeciągać.")
end

-- ---------- ikona W/B i pasek jedzenia ForeverConsumables ----------
-- Pozycje zapisuje sam ForeverConsumables (ForeverConsumablesDB), wiec liczymy je wzgledem srodka ekranu.
local function saveCenterTo(frame, db)
  local cx, cy = frame:GetCenter()
  local ux, uy = UIParent:GetCenter()
  if not cx or not ux then return false end
  db.point, db.relativePoint = "CENTER", "CENTER"
  db.x = math.floor(cx - ux + 0.5)
  db.y = math.floor(cy - uy + 0.5)
  frame:ClearAllPoints()
  frame:SetPoint("CENTER", UIParent, "CENTER", db.x, db.y)
  return true
end

-- Skalowanie jak w ForeverConsumables (ApplySize): licznik ma min. 44 px szerokosci,
-- wiec ponizej ok. 72% oba liczniki W i B nachodza na siebie. Uzywamy 80%.
local FC_PERCENT = 80
local function sizeSupplyWidget(w)
  local p = FC_PERCENT
  local size = math.floor(156 * p / 100 + 0.5)
  local font = math.max(8, math.floor(11 * p / 100 + 0.5))
  local bw = math.max(44, math.floor(61 * p / 100 + 0.5))
  local bh = math.max(18, math.floor(24 * p / 100 + 0.5))
  w:SetSize(size, size)
  if w.waterBadge then w.waterBadge:SetSize(bw, bh) end
  if w.foodBadge then w.foodBadge:SetSize(bw, bh) end
  if w.waterCountText then w.waterCountText:SetFont(STANDARD_TEXT_FONT, font, "OUTLINE") end
  if w.foodCountText then w.foodCountText:SetFont(STANDARD_TEXT_FONT, font, "OUTLINE") end
  return size
end

local function placeConsumables(force)
  if GrimuarSetupDB.fcLayoutV == 2 and not force then return end
  if InCombatLockdown() then return end
  local fcdb = ForeverConsumablesDB
  local bar2 = MultiBarBottomLeft
  if type(fcdb) ~= "table" or not bar2 or not bar2:IsShown() then return end
  local moved = 0
  local w = _G.ForeverConsumablesSupplyWidget
  if w and type(fcdb.supplyWidget) == "table" then
    local size = sizeSupplyWidget(w)
    fcdb.supplyWidget.scalePercent = FC_PERCENT
    fcdb.supplyWidget.size = size
    w:ClearAllPoints()
    w:SetPoint("LEFT", bar2, "RIGHT", 14, 12)
    if saveCenterTo(w, fcdb.supplyWidget) then moved = moved + 1 end
  end
  local q = _G.ForeverConsumablesQuickBar
  if q and type(fcdb.quickbar) == "table" then
    q:ClearAllPoints()
    q:SetPoint("RIGHT", bar2, "LEFT", -14, 0)
    if saveCenterTo(q, fcdb.quickbar) then moved = moved + 1 end
  end
  GrimuarSetupDB.fcLayoutV = 2
  if moved > 0 then
    say("ikona W/B jest na prawo od paska Q–S-R (80% wielkości), a pasek jedzenia na lewo od niego.")
  end
end

-- ============================================================
-- DANE (jak na stronie: Wowhead 11.11, Icy Veins, Seemeta, Warcraft Tavern, Timesaver)
-- ============================================================
-- Czcionki motywu (13.11): Alegreya z Media (SIL OFL, polskie litery). Gdy gra ich nie wczyta: czcionki gry.
local MEDIA_FONTS = "Interface\\AddOns\\GrimuarSetup\\Media\\"
-- 13.11 (zrzut z gry): czcionki nie weszly. SetFont moze nic nie zwracac, wiec sprawdzamy tez odczytem GetFont.
-- Zapas tytulow: ARIALN, bo MORPHEUS nie ma polskich liter („Dzi□”, „Posta□”).
G.fontDiag = {}
local function fontOK(path)
  local ok = false
  pcall(function()
    local fs = UIParent:CreateFontString(nil, "OVERLAY")
    local ret = fs:SetFont(path, 12, "")
    local got = fs:GetFont()
    local same = type(got) == "string" and got:lower():gsub("/", "\\") == path:lower()
    ok = (ret and true) or (ret == nil and same) or false -- jawne false z gry = plik sie nie wczytal
    G.fontDiag[#G.fontDiag + 1] = (path:match("[^\\]+$") or path) .. ": SetFont=" .. tostring(ret) .. ", GetFont=" .. tostring(got)
    fs:Hide()
  end)
  return ok
end
local TITLE_PATH, BODY_PATH = "Fonts\\ARIALN.TTF", "Fonts\\ARIALN.TTF"
local customFonts = false
if fontOK(MEDIA_FONTS .. "AlegreyaSC-Bold.ttf") and fontOK(MEDIA_FONTS .. "AlegreyaSans-Medium.ttf") then
  TITLE_PATH, BODY_PATH = MEDIA_FONTS .. "AlegreyaSC-Bold.ttf", MEDIA_FONTS .. "AlegreyaSans-Medium.ttf"
  customFonts = true
end
G.TF = function() return TITLE_PATH end
G.BF = function() return BODY_PATH end
G.customFonts = customFonts
-- 14.11 KOREKTA (R23): „Forever nie wczytuje czcionek z addonow” to byl blad naszego testu: SetFont na napisie bez punktu
-- nigdy nie startuje wczytywania. Wzor z Forever Skin (Nameplates.lua ~1037): pusty napis przypiety w widocznej ramce
-- zaczyna wczytywanie, czcionka rysuje sie klatke pozniej; sprawdzamy co 0,5 s przez 5 s (i po kazdym ekranie ladowania).
-- Tylko dla nowego huba (addon GrimuarUI, G.uiFont): stare okna i czcionki gry zostaja jak byly (G.TF/G.BF, customFonts).
do
  local files = { MEDIA_FONTS .. "AlegreyaSC-Bold.ttf", MEDIA_FONTS .. "AlegreyaSans-Medium.ttf" }
  local host, probe, waiters, running, uiT, uiB = nil, nil, {}, false, nil, nil
  local function draws(file)
    if not probe then probe = CreateFrame("Frame"):CreateFontString(nil, "OVERLAY") end
    pcall(probe.SetFont, probe, STANDARD_TEXT_FONT or "Fonts\\FRIZQT__.TTF", 12, "")
    local ran, loaded = pcall(probe.SetFont, probe, file, 12, "")
    local got = probe:GetFont()
    return ran and loaded == true and type(got) == "string" and got:lower():gsub("/", "\\") == file:lower()
  end
  local function ask()
    if not host then
      host = CreateFrame("Frame", nil, UIParent)
      host:SetSize(1, 1)
      host:SetPoint("CENTER")
    end
    for _, file in ipairs(files) do
      local blank = host:CreateFontString(nil, "OVERLAY")
      blank:SetPoint("CENTER")
      pcall(blank.SetFont, blank, file, 40, "")
    end
  end
  local function try(n)
    if uiT then running = false return end
    if draws(files[1]) and draws(files[2]) then
      uiT, uiB, running = files[1], files[2], false
      G.fontDiag[#G.fontDiag + 1] = "hub: Alegreya rysuje po " .. (n * 0.5) .. " s"
      for _, fn in ipairs(waiters) do pcall(fn) end
      waiters = {}
    elseif n < 10 then
      C_Timer.After(0.5, function() try(n + 1) end)
    else
      running = false
      G.fontDiag[#G.fontDiag + 1] = "hub: Alegreya nie rysuje po 5 s (zostaje ARIALN)"
    end
  end
  G.retryUiFonts = function()
    if uiT or running then return end
    running = true
    pcall(ask)
    try(0)
  end
  G.uiFont = function(kind) if kind == "title" then return uiT or TITLE_PATH end return uiB or BODY_PATH end
  G.uiFontsReady = function() return uiT ~= nil end
  G.onUiFonts = function(fn) if uiT then pcall(fn) else waiters[#waiters + 1] = fn end end
  local ev = CreateFrame("Frame")
  ev:RegisterEvent("PLAYER_ENTERING_WORLD")
  ev:SetScript("OnEvent", function() G.retryUiFonts() end)
  G.retryUiFonts()
end
local FONT = BODY_PATH
-- wyglad 13.11: C_FROST jako jasne zloto (etykiety, klucze), zeby okno mialo jeden motyw
local C_GOLD, C_FROST, C_MUTED, C_OK, C_WARN = "|cffd8b65c", "|cffe2c78a", "|cff9a958b", "|cff7fcf8d", "|cfff08a6f"
local W = 400

local SPELLS = G.BD.spells

-- Build Frost (Icy Veins Forever, akt. 09.11.2026; research R2 11.11): talent, od poziomu, do poziomu, rang razem.
-- Poprzedni plan (Wowhead, Wand Spec na start) w gaming-warsztat/wow/research/R2-leveling-frost-2611.md.
local TAL_PLAN = G.BD.talPlan
local TAL_NOTE = G.BD.talNote
local TALENT_AT, TALENT_NOTE_AT = {}, {}
-- przeliczane przy zmianie buildu (G.OnBuildChanged), tabele te same, wiec odwolania w innych modulach zostaja
local function recalcTalents()
  wipe(TALENT_AT)
  wipe(TALENT_NOTE_AT)
  local cnt = {}
  for _, t in ipairs(TAL_PLAN) do
    for lv = t[2], t[3] do
      cnt[t[1]] = (cnt[t[1]] or 0) + 1
      if (t[4] or 1) > 1 then TALENT_AT[lv] = t[1] .. " " .. cnt[t[1]] .. "/" .. t[4] else TALENT_AT[lv] = t[1] end
      if cnt[t[1]] == 1 then TALENT_NOTE_AT[lv] = TAL_NOTE[t[1]] end
    end
  end
end
recalcTalents()
G.recalcTalents = recalcTalents
if G.OnBuildChanged then G.OnBuildChanged(function() pcall(recalcTalents) end) end

-- Lochy wg researchu R7 (12.11, gaming-warsztat/wow/research/R7-lochy-grupa-2611.md).
-- { od, do, nazwa, notka, prio }  prio: 1 = bezpieczny, z questami Przymierza; 2 = daleko albo strefa sporna; 3 = teren Hordy.
local DUNGEONS = {
  { 13, 20, "Hall of Thanes", "pod Ironforge, nowy. Questy: Dark Iron Map (Spy), Thom Filch. Deepblaze, Dwarven Tome, Fang of Magmatus", 1 },
  { 15, 22, "Ruins of Lordaeron", "nad Undercity (Horda!), tylko z całą grupą. Coldspire Staff +32 do mrozu", 3 },
  { 17, 26, "Deadmines", "najpierw łańcuch Defias (Sentinel Hill): Staff of Westfall. Emberstone Staff", 1 },
  { 20, 30, "Shadowfang Keep", "Silverpine (Horda), brak questów Przymierza. Tylko łup: Odo's Ley Staff", 3 },
  { 24, 32, "Blackfathom Deeps", "weź In Search of Thaelrid (Darnassus): różdżka Gravestone Scepter", 1 },
  { 24, 30, "Stormwind Stockade", "bezpiecznie w Stormwind, 6 questów. Kam's Walking Stick +32 SP", 1 },
  { 26, 33, "Excavation Site: Wetlands", "nowy, questy z Menethil i Redridge. Raptor's Gaze, Ring of Power Regulation", 1 },
  { 28, 35, "City of Dalaran", "nowy, klucz z questu w Southshore. Szata, różdżka i kostur dla maga; wejście obozowane na PvP", 2 },
  { 29, 38, "Gnomeregan", "Dun Morogh, questy z Tinker Town. Grand Betrayal: Civinad Robes", 1 },
  { 29, 38, "Razorfen Kraul", "Barrens (Horda). Quest Crone of the Kraul", 3 },
  { 30, 38, "SM Graveyard", "Tirisfal (Horda). Orb of the Forgotten Seer, Necrotic Wand", 2 },
  { 33, 41, "SM Library", "książka Rituals of Power do różdżki klasowej. Hypnotic Blade", 2 },
  { 35, 42, "Drowned City", "Stranglethorn, nowy", 2 },
  { 36, 46, "SM Armory i Cathedral", "In the Name of the Light (Southshore). Triune Amulet", 2 },
  { 37, 46, "Razorfen Downs", "Barrens. Extinguishing the Idol", 3 },
  { 40, 47, "Krol'Dok Stronghold", "Riverglades, nowy; wejście sporne na PvP", 2 },
  { 41, 49, "Uldaman", "Badlands. Quest maga Power in Uldaman (Celestial Power), Restoring the Necklace", 1 },
  { 44, 54, "Zul'Farrak", "Tanaris", 2 },
  { 46, 55, "Maraudon", "Desolace", 2 },
  { 48, 55, "Alcaz Island Prison", "obok Theramore, nowy; Dustwallow to strefa ganków", 2 },
  { 50, 60, "Sunken Temple", "quest maga Destroy Morphaz od 52 (Archmage Xylem, Azshara)", 2 },
  { 52, 60, "Blackrock Depths", "ścieżka do Onyxii (Windsor)", 2 },
  { 54, 60, "Dire Maul", "Feralas", 2 },
  { 55, 60, "Lower Blackrock Spire", "Blackrock Mountain", 2 },
  { 55, 60, "Blackmaw Hold", "Azshara, nowy", 2 },
  { 58, 60, "Shaper's Terrace", "Un'Goro, nowy", 2 },
  { 58, 60, "Stratholme", "pre-raid BiS", 2 },
  { 58, 60, "Scholomance", "pre-raid BiS", 2 },
  { 59, 60, "Upper Blackrock Spire", "rozmiar grupy w Forever niepotwierdzony; Drakkisath: ścieżka do Onyxii", 2 },
}

-- Najlepszy loch na poziom: poziom w [od, do-2], najnizsze prio, przy remisie wyzszy poziom startowy (R7).
local function bestDungeon(l)
  local best
  for _, d in ipairs(DUNGEONS) do
    local top = math.max(d[1], d[2] - 2)
    if d[1] <= l and l <= top then
      if not best or (d[5] or 2) < (best[5] or 2) or ((d[5] or 2) == (best[5] or 2) and d[1] > best[1]) then best = d end
    end
  end
  return best
end

local QUESTS = {
  { 5, "Quest „Rare Books”", "Apprentice's Spellstaff" },
  -- 14.11 R22: poprawki nagrod (Polestar ItemDB, dane Forever) i karty Grimuara w Polestarze (Trasa.lua)
  { 9, "Quest „Old Ironforge Incursion”: różdżka Deepblaze", "Dark Iron Map z Dark Iron Spy (Ironbeard's Compound) → Earthseer Farsen (Dun Morogh 64.9, 58.5) → ostatni boss Hall of Thanes z grupą → Magni (Ironforge). Karta Grimuara „Hall of Thanes” w Polestarze" },
  { 10, "Quest „Mage-tastic Gizmonitor”", "Magis Sparkmantle (Kharanos) → Bink (Ironforge 27, 8) → skrzynka (Dun Morogh 27, 36): Arcane Orb albo Arcane Staff. Wyklucza się z Mirror Lake (Ley Orb, Ley Staff)" },
  { 13, "Quest „Important Heirlooms”", "Thom Filch (Ironforge 32.2, 44.5), przedmioty z Hall of Thanes: Dwarven Tome (off-hand, moc zaklęć) albo Tomb Robber's Gloves (Intelekt)" },
  { 15, "Quest „Vyrin's Revenge”", "Loch Modan, Vyrin Swiftwind (81.7, 64.1): darmowa torba na 10. Karta Grimuara w Polestarze" },
  { 17, "Deadmines z grupą", "po łańcuchu Defias w Westfall: Cookie's Stirring Rod (różdżka), Emberstone Staff" },
  { 21, "Quest „Baron Marinous”", "Darkshore, przedmiot z barona (ruiny Mathystry 59, 22) → Onu (43.6, 76.3): Mathystra Channeling Orb (+5 Int). Karta Grimuara w Polestarze" },
  { 25, "Quest „WANTED: Incinerator Gar'im”", "Redridge, list gończy w Lakeshire: Incinerator's Boots (+6 Int)" },
  { 10, "Książki: Elwynn i Ironforge", "Tower of Azora 65,70; Hall of Explorers 76,10" },
  { 15, "Quest „Manaweave Robe”", "dla gnoma zaczyna Dink w Ironforge → Jennea Cannon (Stormwind 49, 86): 10 Linen Cloth i 6 Charged Rift Gems z Silver Stream Mine. Przewodnik klasowy Polestara" },
  { 15, "Książki: Westfall i Loch Modan", "Moonbrook 45,70; Sentinel Hill Inn 53,54; Thelsamar 36,49; Mo'grosh 77,14" },
  { 18, "Książki: Darkshore", "Mathystra 60,22" },
  { 20, "20 książek do oddania", "Garion Wendell, Mage Quarter, Stormwind 38,81: Philanthropist's Ring" },
  { 24, "Książki: Wetlands i Duskwood", "Whelgar's 34,48; Raven Hill Crypt 17,29" },
  { 26, "Quest „Astral Knot Garment”", "szata, można pominąć" },
  { 30, "Łańcuch „Mage's Wand” (finał ok. 40)", "Trener: Journey to the Marsh → Tabetha (Dustwallow, na zachód od Theramore) → Arathi (Witherbark) i Magus Tirth (Mirage Raceway) → SM Library (Doan): Icefury Wand" },
  { 30, "Quest „Strahnbrad Mystery”", "Alterac: Brilliant Cloak" },
  { 40, "Jazda: Apprentice Riding", "Steelgrill's Depot (Dun Morogh 49, 48): 100 g (przy Honored 90 g) i quest na darmowego mechanostridera" },
  { 40, "Łańcuch „Celestial Power”", "Po Mage's Wand: Tabetha → Infernal Orb → Exorcism → Power in Uldaman (Obsidian Sentinel) → Mana Surges (Badlands): Celestial Orb albo Stave" },
  { 45, "Questy „Southsea Shakedown” i „The Dunemaul Compound”", "Tanaris: Southsea Mojo Boots, Witherseed Gloves" },
  { 50, "Quest „The Morrow Stone”", "Feathermoon (Feralas), łańcuch In Search of Knowledge: różdżka Cairnstone Sliver" },
  { 52, "Łańcuch „Destroy Morphaz”", "Archmage Xylem (Azshara): Magic Dust → The Siren's Coral → Morphaz w Sunken Temple: Glacial Spike, Fire Ruby albo Arcane Crystal Pendant" },
  { 48, "Onyxia 1/4: „Dragonkin Menace”", "Helendis Riverhorn (Morgan's Vigil, Burning Steppes). Potem „The True Masters”: Solomon (Lakeshire 29.8, 44.2) → Bolvar (Stormwind 77.8, 18.7) → Prestor → Solomon → Maxwell (84.6, 68.8) → Ragged John (Burning Steppes 65.0, 23.6)" },
  { 52, "Onyxia 2/4: Marshal Windsor (BRD)", "Cela w Detention Block (klucz od Gerstahna). „A Crumpled Up Note” (rzadki łup, każdy swój) → „A Shred of Hope” (Argelmach i Angerforge) → „Jail Break!” (eskorta)" },
  { 55, "Onyxia 3/4: Stormwind", "„Stormwind Rendezvous”: Squire Rowe przy bramie (70.4, 85.5) → „The Great Masquerade” z grupą → Bolvar: „The Dragon's Eye”" },
  { 56, "Guardians of Hyjal", "Questy Mount Hyjal (wejście z Winterspring). Friendly i „Friendly Advice”: wzór Manaflare Pants. Revered: Rousing Seed Pod (10 g)" },
  { 58, "Onyxia 4/4: Haleh i Drakkisath", "Haleh w Mazthoril (Winterspring, runa na końcu jaskini, 54.5, 51.2) → UBRS: Blood of the Black Dragon Champion (każdy swoją) → Haleh: Drakefire Amulet" },
  { 60, "Barrow Deeps i Hyjal Summit", "Bez attunementu. Po 09.12 sprawdź „dodatkowe kroki” i dzień resetu (/raidinfo)" },
  { 60, "Łańcuch „Fragmented Magic”", "Xylem: Warlord Krellian → Scalebeard → Fragmented Magic: Polymorph: Pig" },
}

local STAGES = {
  { id = "s1", from = 1, to = 9, title = "Start", zones = "Dun Morogh: Coldridge Valley, potem Kharanos",
    focus = { "Naucz się sterowania i czytaj opisy questów.", "Trener co 2 poziomy. Arcane Intellect kup od razu.", "Wodę i jedzenie tylko z czaru. Szare łupy do kupca, zioła (Peacebloom, Silverleaf, Earthroot drożeją) na AH całymi stackami. Linen zostaw na First Aid." },
    todo = { "Hearthstone przypisany w Kharanos", "First Aid, Herbalism i Mining u trenerów", "Pierwsza torba założona (przeciągnij do slotu)", "Frost Armor i Arcane Intellect zawsze włączone", "Quest „Rare Books”: Apprentice's Spellstaff" } },
  -- 14.11 R22: kolejnosc stref jak w trasie Polestara (Trasa.lua), poboczne jako karty Grimuara w Polestarze
  { id = "s2", from = 10, to = 19, title = "Pierwsze talenty", zones = "Dun Morogh do 14, Westfall (11–17), Darkshore (15–19), Loch Modan (17–21)",
    focus = { "Talenty od 10 (klawisz N): 2 punkty w Precision, potem Improved Frostbolt i Frostbite.", "Różdżka: Deepblaze z „Old Ironforge Incursion” (Hall of Thanes z grupą). Dobijaj nią moby (klawisz G).", "Idź za trasą Polestara; karty Grimuara otworzą się same (różdżka, torby, off-hand). Zostaw 10 Linen Cloth na Manaweave Robe (15). /trasa w czacie mówi, co zbierać i sprzedawać." },
    todo = { "Quest „Mage-tastic Gizmonitor” (Arcane Orb albo Arcane Staff)", "Quest „Old Ironforge Incursion” (Deepblaze)", "Quest „Vyrin's Revenge” (torba 10)", "Pierwsze 10 książek z bibliotek", "Hall of Thanes albo Deadmines z ekipą", "Wszystkie flight pathy w odwiedzonych strefach" , "Fishing do 20: Fish Bowl przy ognisku (+8% statystyk)" } },
  { id = "s3", from = 20, to = 29, title = "Blink, Ice Lance i pierwsze AoE", zones = "Darkshore (21–23), Ashenvale (22–25), Redridge (25–27), Duskwood, Wetlands (27–30)",
    focus = { "Od 20 masz Blink, Evocation i teleport. Hearthstone przenieś do strefy questów.", "Od 20 Ice Lance (talent) na zamrożony cel, od 29 Ice Block.", "Strefy sporne PvP: patrz na okno Spy, uciekaj przed wyższym poziomem." },
    todo = { "20 książek oddane: Philanthropist's Ring", "Counterspell na pasku (F)", "Excavation Site: Wetlands z ekipą", "Pierwszy punkt Legacy: Thrill of Adventure", "First Aid do 150" } },
  -- s4-s6 wg researchu R10 (13.11, gaming-warsztat/wow/research/R10-leveling-30-60-2611.md)
  { id = "s4", from = 30, to = 39, title = "Ice Armor, Mage Armor i różdżka", zones = "Hillsbrad i Alterac, Arathi, Stranglethorn, Desolace; od 36 Riverglades (Farholde Keep)",
    focus = { "Na 30 weź od trenera Journey to the Marsh. Cały łańcuch Mage's Wand robisz realnie na 38–40 (Dustwallow, Arathi, Thousand Needles, SM Library).", "Kupuj tylko rangi Frost (zakładka Czary). Na 34 Mage Armor do grup, Ice Armor solo. Odkładaj 100 g na 40.", "PvP: Dustwallow i Stranglethorn to strefy ganków. Arathi i Desolace są spokojniejsze. Riverglades zastępuje drugą połowę Stranglethorn." },
    todo = { "Ice Armor (30) i Mage Armor (34) na pasku", "Loty: Southshore, Refuge Pointe, Booty Bay, Theramore, Nijel's Point, Farholde Keep", "Hearthstone w karczmie strefy questów", "Gnomeregan albo SM Graveyard i Library z ekipą", "Quest „Mage's Wand”: Icefury Wand", "100 g odłożone na jazdę" } },
  { id = "s5", from = 40, to = 49, title = "Wierzchowiec, Ice Barrier, Celestial Power", zones = "Riverglades, Badlands, Dustwallow, Tanaris, Feralas, Hinterlands, Searing Gorge",
    focus = { "Na 40 najpierw jazda: Steelgrill's Depot w Dun Morogh, 100 g i darmowy mechanostrider. Dual Spec 50 g dopiero potem.", "Ice Barrier przed każdą walką. Portale kup dopiero po jeździe. Na 40–42, zaraz po jeździe, zamień Mining na Tailoring (225–300 to 1100–3000 Runecloth, trzeba zacząć wcześnie).", "Łańcuch Celestial Power (Tabetha, Uldaman, Badlands) daje Celestial Orb albo Stave. Od 48 questy dają dodatkowo złoto." },
    todo = { "Apprentice Riding i mechanostrider", "Quest „Celestial Power”", "Uldaman (z Power in Uldaman) i Zul'Farrak z ekipą", "Punkt Legacy na 45", "Cairnstone Sliver (The Morrow Stone, Feathermoon)", "Mining zamienione na Tailoring (40–42)" } },
  { id = "s6", from = 50, to = 59, title = "Azshara, Plaguelands i 60", zones = "Un'Goro, Azshara, Felwood, Blasted Lands, Burning Steppes, Plaguelands, Winterspring, Silithus; Hyjal od ok. 55 (niepewne)",
    focus = { "Na 52 Archmage Xylem w Azsharze: Magic Dust, Siren's Coral, potem Destroy Morphaz w Sunken Temple (Glacial Spike albo Fire Ruby).", "Eastern Plaguelands i Burning Steppes to strefy seryjnych ganków. Gdy Cię polują, Hearthstone i wróć później.", "Tailoring dalej na Runecloth (od 50). Robe of the Archmage: Tailoring 295, wzór z LBRS. Zioła z 55–60 trzymaj pod raidy." },
    todo = { "Quest „Destroy Morphaz”", "Arcane Brilliance (56) i Mana Ruby (58)", "Attunement do Onyxii (Helendis Riverhorn, Burning Steppes)", "Tailoring 225 i więcej (Artisan w Theramore)", "1200 g na 60 (jazda 1000 g i wierzchowiec 200 g)", "Talenty pod raid na 60" } },
  -- s7 wg R12 (13.11): 60 i przygotowanie do raidow (raidy od 09.12.2026; dane odswiezyc przed wejsciem w ten etap)
  { id = "s7", from = 60, to = 60, title = "Przed raidami", zones = "Burning Steppes i Blackrock (BRD, LBRS, UBRS), Winterspring (Mazthoril, Everlook), Mount Hyjal, Felwood",
    focus = { "Pierwszy raid to Barrow Deeps (10 osób, bez attunementu). Onyxia (40 osób) wymaga Drakefire Amulet w torbie.", "Sprzęt: Netherfroth Cuffs i Robe of the Archmage (Tailoring), reszta z BRD, LBRS i UBRS przy łańcuchu Onyxii. Hit z przedmiotów do ok. 10%.", "Raz w tygodniu zbierz zioła na eliksiry (Dreamfoil, Mountain Silversage). Spec raidowy wybierz po pierwszych logach (drugi spec)." },
    todo = { "Drakefire Amulet (łańcuch Onyxii)", "Guardians of Hyjal: Friendly, potem Revered (Rousing Seed Pod)", "Tailoring 300 i Robe of the Archmage", "Eliksiry na 2 wieczory (Greater Arcane Elixir, Mageblood) i jedzenie +SP", "Drugi spec pod raid i Legacy: Reagent Economy", "DBM aktualny i /combatlog włączony" } },
}

local GLOSSARY = {
  { "Aggro", "na kogo patrzy mob; ma je mieć tank" },
  { "Threat", "licznik aggro; kto ma najwięcej, tego mob bije" },
  { "Pull", "ściągnięcie moba albo grupy do walki" },
  { "Add", "dodatkowy mob, który dołączył do walki" },
  { "Tank", "trzyma aggro i przyjmuje ciosy" },
  { "Healer", "leczy grupę" },
  { "DPS", "obrażenia na sekundę; też rola, czyli Ty" },
  { "CC", "crowd control, wyłączenie moba, np. Polymorph" },
  { "Sheep", "owca; „sheep moon” to owca na cel z księżycem" },
  { "Kite", "bicie spowolnionego moba z dystansu" },
  { "OOM", "brak many" },
  { "Drink", "przerwa na picie" },
  { "AoE", "obrażenia w kilka celów naraz" },
  { "DoT", "obrażenia rozłożone w czasie" },
  { "Buff / debuff", "pozytywny / negatywny efekt" },
  { "Proc", "efekt odpalany z pewną szansą" },
  { "CD", "cooldown, czas odnowienia" },
  { "GCD", "ok. 1,5 s przerwy po każdym czarze" },
  { "LoS", "zejście za ścianę, żeby wróg nie rzucił czaru" },
  { "Wipe", "cała grupa zginęła" },
  { "Res", "wskrzeszenie" },
  { "Elite", "silniejszy mob na grupę (złoty smok przy portrecie)" },
  { "Trash", "zwykłe moby między bossami" },
  { "Instance", "osobna kopia dungeonu dla Twojej grupy" },
  { "Lockout", "bossa w raidzie zabijasz raz na tydzień" },
  { "BiS", "best in slot, najlepszy przedmiot na slot" },
  { "Need / Greed", "losowanie łupu: potrzebuję / na sprzedaż" },
  { "Ninja", "ktoś, kto zabiera niepotrzebne mu łupy" },
  { "Gank", "atak silniejszego gracza z zaskoczenia" },
  { "Flag", "oznaczenie PvP" },
  { "Mats", "materiały do craftingu" },
  { "AH", "dom aukcyjny" },
  { "HS", "Hearthstone" },
  { "FP", "flight path, lot" },
  { "Rep", "reputacja u frakcji" },
  { "LFG / LFM", "szukam grupy / szukamy ludzi" },
  { "SP", "Spell Power, moc zaklęć" },
  { "Hit cap", "ilość Hit, przy której przestajesz pudłować" },
}

-- eksport do pozostalych modulow
G.PREFIX = PREFIX
G.say = say
-- 14.11 (R27 E5): tryb prywatny (addon Grimuar_Osobiste) i podpowiedz przy bledach dla wersji publicznej
function G.personal() return type(_G.GrimuarOsobiste) == "table" end
function G.helpHint()
  if G.personal() then return "Zrób zrzut czatu dla Claude'a." end
  return "Zgłoś to autorom Grimuara: zrzut czatu i wynik /gr test."
end
G.CVARS = CVARS
G.getCVar = getCVar
G.setCVar = setCVar
G.applyCVars = applyCVars
G.MACROS = MACROS
G.ensureMacros = ensureMacros
G.BINDS = BINDS
G.applyBinds = applyBinds
G.showBar2 = showBar2
G.MAIN = MAIN
G.BAR2 = BAR2
G.spellName = spellName
G.knownSpellId = knownSpellId
G.slotContent = slotContent
G.onBars = onBars
G.pickup = pickup
G.isAvailable = isAvailable
G.placeSlot = placeSlot
G.DRINKS = DRINKS
G.DRINK_SET = DRINK_SET
G.bagCount = bagCount
G.itemNameById = itemNameById
G.placeDrink = placeDrink
G.layoutBars = layoutBars
G.clearMainBar = clearMainBar
G.charKey = charKey
G.fullSetup = fullSetup
G.MM_SLOTS = MM_SLOTS
G.arrangeMinimapIcons = arrangeMinimapIcons
G.saveCenterTo = saveCenterTo
G.FC_PERCENT = FC_PERCENT
G.sizeSupplyWidget = sizeSupplyWidget
G.placeConsumables = placeConsumables
G.FONT = FONT
G.C_GOLD = C_GOLD
G.C_FROST = C_FROST
G.C_MUTED = C_MUTED
G.C_OK = C_OK
G.C_WARN = C_WARN
G.W = W
G.SPELLS = SPELLS
G.TAL_PLAN = TAL_PLAN
G.TAL_NOTE = TAL_NOTE
G.TALENT_AT = TALENT_AT
G.TALENT_NOTE_AT = TALENT_NOTE_AT
G.DUNGEONS = DUNGEONS
G.bestDungeon = bestDungeon
G.QUESTS = QUESTS
G.STAGES = STAGES
G.GLOSSARY = GLOSSARY
G.scanDrinks = scanDrinks
G.drinkCount = drinkCount
G.showBar3 = showBar3
G.BAR3 = BAR3
G.scanFood = scanFood
-- 14.11: hub (osobny addon GrimuarUI, ## Dependencies: GrimuarSetup) czyta stad dane i funkcje Grimuara
_G.GrimuarAPI = G
