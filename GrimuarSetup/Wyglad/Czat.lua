-- Grimuar: modul Czat (prosba gracza 13.11: „z tym chatem tez bym cos powalczyl, zeby byl ladniejszy”).
-- 1) tlo Runy pod czatem: ciemny braz, gestszy z lewej, zlota kreska u gory (tekst czytelny na jasnym tle swiata);
-- 2) pole pisania: ciemne tlo i zlota ramka zamiast szarej ramki gry;
-- 3) zakladki bez tla gry, aktywna zlota, pozostale przygaszone;
-- 4) krotsze kanaly: [1. General - Dun Morogh] -> [1. General] (filtr wiadomosci gry, tresc bez zmian);
-- 5) cien pod literami.
-- Boczne przyciski, zakladke Combat Log i spam z cudzych pojedynkow chowa Leatrix (Prostokat.lua raz, Kontrola pilnuje).
-- Wszystko w pcall, wlasne tekstury w slabej tabeli (bez pol na ramkach gry). /gr skorki wylacza razem z innymi skorkami.
local ADDON_NAME, G = ...

local BG = { 0.067, 0.059, 0.047 }
local GOLD = { 0.85, 0.71, 0.36 }
local MUTED = { 0.6, 0.56, 0.48 }
local made = setmetatable({}, { __mode = "k" })

local function on() return not GrimuarSetupDB.noSkins end

local function gradient(tex, orient, a1, a2, c)
  c = c or BG
  tex:SetColorTexture(1, 1, 1, 1)
  local ok = pcall(function()
    tex:SetGradient(orient, CreateColor(c[1], c[2], c[3], a1), CreateColor(c[1], c[2], c[3], a2))
  end)
  if not ok then tex:SetColorTexture(c[1], c[2], c[3], (a1 + a2) / 2) end
end

-- 1) tlo pod oknem czatu (wlasna ramka przy UIParent, idzie za ChatFrame1, takze gdy wybrana inna zakladka)
local panel
local function skinPanel()
  local cf = _G.ChatFrame1
  if not cf then return end
  if not panel then
    panel = CreateFrame("Frame", nil, UIParent)
    panel:SetFrameStrata("BACKGROUND")
    panel:SetFrameLevel(0)
    panel:EnableMouse(false)
    local bg = panel:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints()
    gradient(bg, "HORIZONTAL", 0.62, 0.12)
    local line = panel:CreateTexture(nil, "BORDER")
    line:SetPoint("TOPLEFT")
    line:SetPoint("TOPRIGHT")
    line:SetHeight(1)
    gradient(line, "HORIZONTAL", 0.8, 0, GOLD)
  end
  panel:ClearAllPoints()
  panel:SetPoint("TOPLEFT", cf, "TOPLEFT", -6, 6)
  panel:SetPoint("BOTTOMRIGHT", cf, "BOTTOMRIGHT", 6, -6)
  panel:SetShown(on())
end

-- 2) pole pisania
local function skinEditBox(eb)
  if not eb or made[eb] then return end
  made[eb] = true
  for _, r in ipairs({ eb:GetRegions() }) do
    if r.GetObjectType and r:GetObjectType() == "Texture" then
      local layer = r:GetDrawLayer()
      if layer == "BACKGROUND" or layer == "BORDER" then r:SetAlpha(0) end
    end
  end
  local bg = eb:CreateTexture(nil, "BACKGROUND", nil, -8)
  bg:SetPoint("TOPLEFT", 4, -4)
  bg:SetPoint("BOTTOMRIGHT", -4, 4)
  bg:SetColorTexture(BG[1], BG[2], BG[3], 0.88)
  local function edge(p1, p2, w, h)
    local t = eb:CreateTexture(nil, "BORDER", nil, 7)
    t:SetColorTexture(GOLD[1], GOLD[2], GOLD[3], 0.75)
    t:SetPoint(p1, bg, p1)
    t:SetPoint(p2, bg, p2)
    if w then t:SetWidth(w) else t:SetHeight(h) end
  end
  edge("TOPLEFT", "TOPRIGHT", nil, 1)
  edge("BOTTOMLEFT", "BOTTOMRIGHT", nil, 1)
  edge("TOPLEFT", "BOTTOMLEFT", 1, nil)
  edge("TOPRIGHT", "BOTTOMRIGHT", 1, nil)
end

-- 3) zakladki
local TAB_ART = { "Left", "Middle", "Right", "ActiveLeft", "ActiveMiddle", "ActiveRight",
  "HighlightLeft", "HighlightMiddle", "HighlightRight", "SelectedLeft", "SelectedMiddle", "SelectedRight" }
local function tabText(tab)
  return tab.Text or (tab.GetName and tab:GetName() and _G[tab:GetName() .. "Text"])
end
local function colorTab(tab, selected)
  local t = tabText(tab)
  if not t then return end
  if selected == nil then
    local id = tab.GetID and tab:GetID()
    local cf = id and _G["ChatFrame" .. id]
    selected = cf and _G.SELECTED_CHAT_FRAME == cf
  end
  local c = selected and GOLD or MUTED
  t:SetTextColor(c[1], c[2], c[3])
end
local function skinTab(tab)
  if not tab then return end
  for _, key in ipairs(TAB_ART) do
    local r = tab[key] or (tab:GetName() and _G[tab:GetName() .. key])
    if r and r.SetAlpha then r:SetAlpha(0) end
  end
  colorTab(tab)
end

-- 5) cien pod literami
local function shadow(cf)
  pcall(function()
    cf:SetShadowOffset(1, -1)
    cf:SetShadowColor(0, 0, 0, 0.95)
  end)
end

local function skinAll()
  if not on() then
    if panel then panel:Hide() end
    return
  end
  pcall(skinPanel)
  for i = 1, (NUM_CHAT_WINDOWS or 10) do
    local cf = _G["ChatFrame" .. i]
    if cf then
      shadow(cf)
      pcall(skinEditBox, cf.editBox or _G["ChatFrame" .. i .. "EditBox"])
      pcall(skinTab, _G["ChatFrame" .. i .. "Tab"])
    end
  end
end

-- 4) krotsze nazwy kanalow: arg4 to tekst w nawiasie; kanal rozpoznawany dalej po pelnej nazwie (arg9)
local function shortChannel(_, _, msg, author, lang, chan, ...)
  if type(chan) ~= "string" or (issecretvalue and issecretvalue(chan)) then return false end
  local short = chan:gsub(" %- .+$", "")
  if short == chan then return false end
  return false, msg, author, lang, short, ...
end

local ev = CreateFrame("Frame")
ev:RegisterEvent("PLAYER_LOGIN")
ev:SetScript("OnEvent", function(_, event)
  if event == "PLAYER_LOGIN" then
    ev:RegisterEvent("UPDATE_CHAT_WINDOWS")
    if on() then
      local add = (ChatFrameUtil and ChatFrameUtil.AddMessageEventFilter) or ChatFrame_AddMessageEventFilter
      if add then pcall(add, "CHAT_MSG_CHANNEL", shortChannel) end
    end
    pcall(hooksecurefunc, "FCFTab_UpdateColors", function(tab, selected) if on() then pcall(colorTab, tab, selected) end end)
    pcall(hooksecurefunc, "FCF_OpenTemporaryWindow", function() C_Timer.After(0, function() pcall(skinAll) end) end)
    C_Timer.After(3, function() pcall(skinAll) end)
  else
    C_Timer.After(0.2, function() pcall(skinAll) end)
  end
end)

G.chatSkin = skinAll
