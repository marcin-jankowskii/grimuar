-- Grimuar: modul Prostokat. Minimapa wieksza i prostokatna (prosba gracza 13.11: „troche wieksza i bardziej prostokatna”).
-- Gra rysuje minimape jako kwadrat (inny ksztalt ramki ja rozciaga), wiec: kwadrat SIZE px i maska, ktora zakrywa pasy
-- u gory i u dolu (Media/minimapa-prostokat.tga, 28 z 256 wierszy) -> widac ok. 290 x 227. Kliki w zakryte pasy
-- nie dzialaja (HitRectInsets). Innym addonom: GetMinimapShape = SQUARE (przyciski LibDBIcon), sciezki Questie
-- przycina nasza maska (Questie czyta ostatnia maske minimapy). Zlota ramka Runy wokol widocznego prostokata.
-- Leatrix „Enhance minimap” musi byc wylaczony (jego kwadrat nadpisuje kazda inna maske): tu raz, potem Kontrola.
-- Tu tez raz opcje czatu w Leatrix (Czat.lua): bez bocznych przyciskow i Combat Log, bez spamu z pojedynkow.
-- /minimapa przelacza prostokat i okragla (okragla wraca po /reload). Shift + przeciagnij przesuwa minimape (14.11).
local ADDON_NAME, G = ...
local say = G.say

local MASK = "Interface\\AddOns\\GrimuarSetup\\Media\\minimapa-prostokat.tga"
local SIZE = 290 -- 13.11 gracz: „mapka fajna, ale moze byc jeszcze wieksza” (bylo 250)
local BAND = math.floor(SIZE * 28 / 256 + 0.5)
local SHIFT = 36 -- w lewo, zeby szerszy prostokat i przyciski nie wychodzily za prawa krawedz ekranu
local DROP = 14 -- w dol, zeby wyzszy prostokat nie wchodzil na pasek z nazwa strefy
local GOLD = { 0.85, 0.71, 0.36 }

local leatrixLive = false -- Leatrix rysuje kwadrat w tej sesji: wtedy nie walczymy z nim o maske
local active, busy, border, placed = false, false, nil, nil
local tries, triesAt = 0, 0

local function wanted() return GrimuarSetupDB.minimapRect ~= false end

local function place()
  if Minimap:GetNumPoints() ~= 1 then return end
  local p, rel, rp, x, y = Minimap:GetPoint(1)
  if not p then return end
  if placed and placed[1] == p and placed[2] == rel and placed[3] == rp
    and math.abs(placed[4] - x) < 0.5 and math.abs(placed[5] - y) < 0.5 then return end
  Minimap:ClearAllPoints()
  Minimap:SetPoint(p, rel, rp, x - SHIFT, y - DROP)
  placed = { p, rel, rp, x - SHIFT, y - DROP }
end

local function makeBorder()
  if border then return end
  border = CreateFrame("Frame", nil, Minimap, "BackdropTemplate")
  border:SetPoint("TOPLEFT", Minimap, "TOPLEFT", -2, -BAND + 2)
  border:SetPoint("BOTTOMRIGHT", Minimap, "BOTTOMRIGHT", 2, BAND - 2)
  border:SetFrameLevel(Minimap:GetFrameLevel() + 2)
  border:EnableMouse(false)
  border:SetBackdrop({ edgeFile = "Interface\\Buttons\\WHITE8X8", edgeSize = 2 })
  border:SetBackdropBorderColor(GOLD[1], GOLD[2], GOLD[3], 0.9)
end

local function hideRing()
  pcall(function() if MinimapCompassTexture then MinimapCompassTexture:Hide() end end)
  pcall(function() if MinimapCompassTextureUnderlay then MinimapCompassTextureUnderlay:Hide() end end)
end

local function apply()
  if not (wanted() and not leatrixLive and Minimap) then return end
  -- ochrona przed przepychanka z innym addonem o maske: najwyzej 8 razy na 5 s
  local now = GetTime()
  if now - triesAt > 5 then triesAt, tries = now, 0 end
  tries = tries + 1
  if tries > 8 then return end
  busy = true
  local ok = pcall(function()
    Minimap:SetSize(SIZE, SIZE)
    Minimap:SetMaskTexture(MASK)
    Minimap:SetHitRectInsets(0, 0, BAND, BAND)
  end)
  busy = false
  if not ok then return end
  active = true
  pcall(place)
  hideRing()
  pcall(makeBorder)
  if border then border:Show() end
  GetMinimapShape = function() return "SQUARE" end
  -- przelicz przyciski addonow i ikony na nowy rozmiar
  pcall(function()
    local z = Minimap:GetZoom()
    Minimap:SetZoom(z > 0 and z - 1 or z + 1)
    Minimap:SetZoom(z)
  end)
  pcall(function()
    local L = LibStub and LibStub("LibDBIcon-1.0", true)
    if L and L.SetButtonRadius then L:SetButtonRadius(L.radius or 5) end
  end)
  C_Timer.After(0, function() pcall(G.minimapButtons) end)
end

-- Przyciski przy minimapie (13.11 gracz: „na mapce jeszcze wszystko ladnie nie lezy”): przy prostokacie przyciski
-- addonow stawaly wzdluz niewidocznego kwadratu (czesc na mapie, czesc w powietrzu). Grimuar stawia je w kolumnach
-- po lewej stronie mapy, od gory: Grimuar, Polestar, potem przyciski LibDBIcon wg nazwy. Przeciagniety reka przycisk
-- wraca do kolumny przy nastepnym /reload. Lista pozostalych nazwanych ramek przy minimapie idzie do minimapDiag.
local BTN, GAP = 31, 3
local clockMoved = false -- zegar raz zabrany z mapy zostaje w kolumnie (inaczej przy kolejnym ukladzie zwolnilby miejsce)
local function buttonList()
  local list, seen = {}, {}
  local function add(b)
    if b and not seen[b] and b.IsShown and b:IsShown() then seen[b] = true list[#list + 1] = b end
  end
  add(_G.GrimuarMinimapButton)
  add(_G.PolestarMinimapButton)
  local L = LibStub and LibStub("LibDBIcon-1.0", true)
  if L and type(L.objects) == "table" then
    local names = {}
    for name in pairs(L.objects) do names[#names + 1] = name end
    table.sort(names)
    for _, n in ipairs(names) do add(L.objects[n]) end
  end
  -- 13.11 gracz („ten spy jeszcze zostal na mapie”): addony Forever stawiaja przyciski recznie po kole o promieniu 80
  -- (SpyMinimapButton i podobne). Kazdy przycisk przy minimapie z „MinimapButton” w nazwie idzie do kolumn,
  -- a zegar dnia i nocy gry (GameTimeFrame, ksiezyc albo slonce) na koniec.
  local extra = {}
  for _, parent in ipairs({ Minimap, MinimapCluster }) do
    if parent and parent.GetChildren then
      for _, c in ipairs({ parent:GetChildren() }) do
        local n = c.GetName and c:GetName()
        if n and n:find("MinimapButton", 1, true) then extra[#extra + 1] = { n, c } end
      end
    end
  end
  table.sort(extra, function(a, b) return a[1] < b[1] end)
  for _, e in ipairs(extra) do add(e[2]) end
  -- zegar gry tylko wtedy, gdy lezy na widocznej mapie (ikona kalendarza w pasku strefy zostaje)
  pcall(function()
    local g = _G.GameTimeFrame
    local gx, gy = g:GetCenter()
    local mx, my = Minimap:GetCenter()
    local s = g:GetEffectiveScale() / Minimap:GetEffectiveScale()
    if clockMoved or (math.abs(gx * s - mx) < SIZE / 2 and math.abs(gy * s - my) < SIZE / 2 - BAND) then
      clockMoved = true
      add(g)
    end
  end)
  return list, seen
end

local function diag(seen)
  local out = {}
  local mx, my = Minimap:GetCenter()
  local function scan(parent, depth)
    for _, c in ipairs({ parent:GetChildren() }) do
      local n = c.GetName and c:GetName()
      if n and not seen[c] and c:IsShown() and #out < 40 then
        local cx, cy = c:GetCenter()
        out[#out + 1] = string.format("%s %dx%d @%d,%d", n, c:GetWidth() or 0, c:GetHeight() or 0,
          math.floor((cx or mx) - mx), math.floor((cy or my) - my))
      end
      if depth < 1 then scan(c, depth + 1) end
    end
  end
  pcall(scan, Minimap, 0)
  if MinimapCluster then pcall(scan, MinimapCluster, 0) end
  GrimuarSetupDB.minimapDiag = out
end

local function layoutButtons()
  if not active then return end
  local list, seen = buttonList()
  local perCol = math.max(1, math.floor((SIZE - 2 * BAND + GAP) / (BTN + GAP)))
  for i, b in ipairs(list) do
    local col, row = math.floor((i - 1) / perCol), (i - 1) % perCol
    pcall(function()
      b:ClearAllPoints()
      b:SetPoint("TOPRIGHT", Minimap, "TOPLEFT", -4 - col * (BTN + GAP), -BAND - row * (BTN + GAP))
    end)
  end
  pcall(diag, seen)
end

-- Leatrix raz (jak Kontrola: zapis w LeaPlusDB i „nosave”, zeby Leatrix przy /reload nie nadpisal go swoja kopia)
local LEA = { MinimapModder = "Off", NoChatButtons = "On", NoCombatLogTab = "On", RestoreChatMessages = "On" }
-- (filtr spamu Leatrixa w Forever jest zablokowany przez sam Leatrix, wiec go nie ustawiamy)
local function leatrixOnce()
  if (GrimuarSetupDB.leatrixUiV or 0) >= 1 or type(LeaPlusDB) ~= "table" then return end
  GrimuarSetupDB.leatrixUiV = 1
  local changed = false
  for k, v in pairs(LEA) do
    if LeaPlusDB[k] ~= v then LeaPlusDB[k] = v changed = true end
  end
  if not changed then return end
  pcall(SlashCmdList.Leatrix_Plus, "nosave")
  say("jeszcze jeden /reload: prostokątna minimapa i czat bez bocznych przycisków, zakładki Combat Log i spamu z pojedynków.")
  pcall(G.showToast, "wpisz /reload jeszcze raz: prostokątna minimapa i czytelniejszy czat.", "", false)
end

-- 14.11 (gracz: „czy daloby sie przesuwac ta mape?” → „tak”): Shift + przeciagnij lewym przyciskiem przesuwa minimape
-- razem z nazwa strefy i przyciskami (ramka MinimapCluster; gdy minimapa wisi gdzie indziej, sama Minimap). Pozycja
-- w GrimuarSetupDB.minimapPos wraca po /reload i po zmianie ukladu w Edit Mode; /minimapa pozycja oddaje miejsce grze.
-- Samego widoku mapy (srodka) gra przesuwac nie pozwala: zawsze jest wysrodkowany na postaci.
local moving
local function moveTarget()
  local _, rel = Minimap:GetPoint(1)
  if MinimapCluster and rel == MinimapCluster then return MinimapCluster end
  return Minimap
end
local function restorePos()
  local p = GrimuarSetupDB.minimapPos
  if not p or moving or InCombatLockdown() then return end
  if EditModeManagerFrame and EditModeManagerFrame:IsShown() then return end
  local f = (p.f == "Minimap") and Minimap or MinimapCluster
  if not f then return end
  f:ClearAllPoints()
  f:SetPoint(p[1], UIParent, p[2], p[3], p[4])
  if f == Minimap then placed = { p[1], UIParent, p[2], p[3], p[4] } end
end
local function startMove(_, button)
  if button ~= "LeftButton" or not IsShiftKeyDown() or InCombatLockdown() then return end
  local f = moveTarget()
  local ok = pcall(function()
    f:SetMovable(true)
    f:SetClampedToScreen(true)
    f:StartMoving()
  end)
  if ok then moving = f end
end
local function stopMove()
  local f = moving
  if not f then return end
  moving = nil
  pcall(f.StopMovingOrSizing, f)
  pcall(f.SetUserPlaced, f, false)
  local p, _, rp, x, y = f:GetPoint(1)
  if not p then return end
  f:ClearAllPoints()
  f:SetPoint(p, UIParent, rp, x, y)
  if f == Minimap then placed = { p, UIParent, rp, x, y } end
  local first = GrimuarSetupDB.minimapPos == nil
  GrimuarSetupDB.minimapPos = { p, rp, x, y, f = (f == Minimap) and "Minimap" or "MinimapCluster" }
  if first then say("minimapa przesunięta i zapamiętana. Miejsce gry wraca po /minimapa pozycja i /reload.") end
end

local ev = CreateFrame("Frame")
ev:RegisterEvent("PLAYER_LOGIN")
ev:SetScript("OnEvent", function(_, event)
  if event == "PLAYER_LOGIN" then
    leatrixLive = type(LeaPlusDB) == "table" and LeaPlusDB.MinimapModder == "On"
    ev:RegisterEvent("PLAYER_ENTERING_WORLD")
    ev:RegisterEvent("EDIT_MODE_LAYOUTS_UPDATED")
    pcall(hooksecurefunc, Minimap, "SetMaskTexture", function(_, asset)
      if not busy and active and asset ~= MASK then C_Timer.After(0, apply) end
    end)
    if MinimapCompassTexture then
      pcall(hooksecurefunc, MinimapCompassTexture, "Show", function(t) if active then t:Hide() end end)
    end
    C_Timer.After(2, function() pcall(apply) end)
    for _, t in ipairs({ 6, 15, 40 }) do C_Timer.After(t, function() pcall(layoutButtons) end) end
    C_Timer.After(4, function() pcall(leatrixOnce) end)
    pcall(Minimap.HookScript, Minimap, "OnMouseDown", startMove)
    pcall(Minimap.HookScript, Minimap, "OnMouseUp", stopMove)
    C_Timer.After(2.5, function() pcall(restorePos) end)
  else
    C_Timer.After(0.5, function() if active then pcall(apply) end end)
    C_Timer.After(0.7, function() pcall(restorePos) end)
  end
end)

SLASH_GRIMUARMINIMAPA1 = "/minimapa"
SlashCmdList["GRIMUARMINIMAPA"] = function(msg)
  msg = (msg or ""):lower():gsub("^%s+", ""):gsub("%s+$", "")
  if msg == "pozycja" or msg == "miejsce" then
    GrimuarSetupDB.minimapPos = nil
    say("minimapa: wraca na miejsce gry po /reload.")
    return
  end
  if wanted() then
    GrimuarSetupDB.minimapRect = false
    say("minimapa: okrągła po /reload. Prostokąt wraca przez /minimapa.")
  else
    GrimuarSetupDB.minimapRect = true
    pcall(apply)
    say(leatrixLive and "minimapa: prostokąt po /reload (teraz kwadrat rysuje Leatrix)." or "minimapa: prostokąt.")
  end
end

G.minimapRectApply = apply
G.minimapButtons = layoutButtons
G.minimapLeatrixLive = function() return leatrixLive end
