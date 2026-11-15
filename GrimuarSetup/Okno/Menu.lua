-- Grimuar: modul Menu. Menu pauzy (Esc) w stylu Runy (makieta 13.11, research R14): na gorze nasze przyciski Grimuar,
-- Plan sesji i Konczę gre, pod nimi runiczny separator i przyciski Blizzarda. Technika jak w Polestar (UI/GameMenu.lua):
-- nic Blizzarda nie zapisujemy ani nie przesuwamy; nasze ramki maja layoutIndex mniejszy niz pierwszy przycisk menu,
-- a uklad menu sam je ustawia. Konczę gre otwiera podsumowanie sesji z bezpiecznym przyciskiem /logout.
local ADDON_NAME, G = ...
local say = G.say

local GOLD = { 0.85, 0.71, 0.36 }
-- 14.11: z Forever Skin menu Esc dostaje jego palete (Style.lua: grafit, czarne kontury 1 px, zloty akcent), bez rogow
-- Runy, zeby pasowalo do przebudowanych okien. Menu zostaje nasze (przebudowane menu FSS gubiloby przyciski Grimuara).
local function fss()
  local ok, loaded = pcall(C_AddOns.IsAddOnLoaded, "ForeverSkin")
  -- 15.11: z lata ForeverSkin w kolorach Grimuara (GRIMUAR_FSS_LATKA) zostaje paleta Grimuara
  return ok and loaded and not GRIMUAR_FSS_LATKA
end
local function accent() return fss() and { 0.95, 0.76, 0.35 } or GOLD end
local buttons, divider, summary = {}, nil, nil

local function closeMenu()
  local m = _G.GameMenuFrame
  if m and m:IsShown() then if HideUIPanel then HideUIPanel(m) else m:Hide() end end
end

-- ---------- podsumowanie sesji przy Konczę gre ----------
local function buildSummary()
  if summary or not G.StyledWindow then return summary end
  local f = G.StyledWindow("GrimuarKoniecSesji", 360, 190, "Koniec sesji", "DIALOG")
  f:SetPoint("CENTER", UIParent, "CENTER", 0, 80)
  f.text = f:CreateFontString(nil, "OVERLAY")
  f.text:SetFont(G.FONT, 14, "")
  f.text:SetTextColor(0.93, 0.91, 0.86)
  f.text:SetWidth(320)
  f.text:SetJustifyH("LEFT")
  f.text:SetPoint("TOPLEFT", f, "TOPLEFT", 20, -48)
  local go = G.FlatButton(f, 150, 24, "Prowadź do karczmy", true)
  go:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT", 20, 18)
  go:SetScript("OnClick", function() f:Hide() if G.startEnding then G.startEnding() end end)
  -- Wylogowanie: gra pozwala tylko przez bezpieczny przycisk, ktory wpisuje /logout (R14)
  local out = CreateFrame("Button", "GrimuarLogoutButton", f, "SecureActionButtonTemplate, BackdropTemplate")
  out:SetSize(130, 24)
  out:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -20, 18)
  out:SetAttribute("type", "macro")
  out:SetAttribute("macrotext", "/logout")
  pcall(function() out:RegisterForClicks("AnyUp", "AnyDown") end)
  if G.setBackdrop and G.STYLE then G.setBackdrop(out, G.STYLE.btn, G.STYLE.btnEdge) end
  local lbl = out:CreateFontString(nil, "OVERLAY")
  lbl:SetFont(G.FONT, 12, "")
  lbl:SetPoint("CENTER")
  lbl:SetText("Wyloguj teraz")
  lbl:SetTextColor(0.93, 0.91, 0.86)
  out:SetScript("OnEnter", function() if G.STYLE then G.setBackdrop(out, G.STYLE.btnHover, G.STYLE.gold) end end)
  out:SetScript("OnLeave", function() if G.STYLE then G.setBackdrop(out, G.STYLE.btn, G.STYLE.btnEdge) end end)
  if G.addRuneCorners then pcall(G.addRuneCorners, f) end
  f:Hide()
  summary = f
  return f
end

local function showSummary()
  closeMenu()
  if InCombatLockdown() and not summary then say("podsumowanie pokażę po walce.") return end
  local f = buildSummary()
  if not f then return end
  local okS, txt = pcall(G.sessionSummary)
  f.text:SetText((okS and txt or "Dziś: brak danych sesji.") .. "\n\nWyloguj się w karczmie albo w mieście, wtedy nalicza się odpoczynek: podwójne XP za moby w następnej sesji.")
  f:Show()
end

-- ---------- przyciski w menu ----------
local SPECS = {
  -- 14.11: hub jak w Wiedzminie (addon GrimuarUI, klawisz `)
  { "Hub (`)", function()
      closeMenu()
      if GrimuarHubOpen then C_Timer.After(0, function() GrimuarHubOpen() end)
      else say("hub to addon GrimuarUI: włącz go na liście addonów.") end
    end },
  { "Grimuar (Shift+G)", function() closeMenu() if SlashCmdList.GRIMUAR then SlashCmdList.GRIMUAR("") end end },
  { "Plan sesji", function()
      closeMenu()
      if SlashCmdList.GRIMUAR and not (G.getPanel and G.getPanel() and G.getPanel():IsShown()) then SlashCmdList.GRIMUAR("") end
      if G.selectTab then pcall(G.selectTab, "teraz") end
    end },
  { "Kończę grę", showSummary },
}

-- ---------- wyglad menu jak w makiecie 13.11: ciemne tlo, zlota ramka, plaskie przyciski ----------
-- gracz 13.11: „przyciski dalej czerwone, wyglada jak klasyczny WoW”. Tylko wyglad (wzor EllesmereUI, R14):
-- tekstury Blizzarda dostaja alfe 0, pod napisem sa nasze tekstury, czcionka idzie przez nasze obiekty czcionek
-- (ARIALN albo Alegreya: polskie litery w „Kończę grę”). Nic nie zapisujemy w tabelach Blizzarda (stan w slabej
-- tabeli), wiec Wyloguj i Wyjdz z gry dzialaja jak dotad. Przycisk Polestara sam kopiuje wyglad sasiada.
local S = G.STYLE or {}
local skinned = setmetatable({}, { __mode = "k" })
local menuSkin, FONTS

local function menuFonts()
  if FONTS then return FONTS end
  local function mk(name, c)
    local f = CreateFont(name)
    f:SetFont(G.BF(), 14, "")
    f:SetTextColor(c[1], c[2], c[3])
    return f
  end
  FONTS = {
    normal = mk("GrimuarMenuFont", S.text or { 0.93, 0.91, 0.86 }),
    gold = mk("GrimuarMenuFontGold", accent()),
    hover = mk("GrimuarMenuFontHover", { 1, 0.86, 0.5 }),
    off = mk("GrimuarMenuFontOff", S.muted or { 0.6, 0.59, 0.55 }),
  }
  return FONTS
end

-- ours: nasz przycisk (zloty napis i ramka); full: pelna skorka (bez niej tylko czcionka z polskimi literami)
local function skinButton(b, ours, full)
  local F = menuFonts()
  b:SetNormalFontObject(ours and F.gold or F.normal)
  b:SetHighlightFontObject(F.hover)
  b:SetDisabledFontObject(F.off)
  if not full then return end
  local st = skinned[b]
  if not st then
    for _, r in ipairs({ b:GetRegions() }) do
      if r.GetObjectType and r:GetObjectType() == "Texture" then pcall(r.SetAlpha, r, 0) end
    end
    st = {}
    st.edge = b:CreateTexture(nil, "BACKGROUND", nil, -8)
    st.edge:SetAllPoints(b)
    st.fill = b:CreateTexture(nil, "BACKGROUND", nil, -7)
    st.fill:SetPoint("TOPLEFT", b, "TOPLEFT", 1, -1)
    st.fill:SetPoint("BOTTOMRIGHT", b, "BOTTOMRIGHT", -1, 1)
    local c = fss() and { 0.1, 0.1, 0.11, 1 } or (S.btn or { 0.1, 0.086, 0.06, 1 })
    st.fill:SetColorTexture(c[1], c[2], c[3], 1)
    st.hl = b:CreateTexture(nil, "HIGHLIGHT")
    st.hl:SetPoint("TOPLEFT", b, "TOPLEFT", 1, -1)
    st.hl:SetPoint("BOTTOMRIGHT", b, "BOTTOMRIGHT", -1, 1)
    local A = accent()
    st.hl:SetColorTexture(A[1], A[2], A[3], 0.16)
    skinned[b] = st
  end
  local A = accent()
  local e = ours and { A[1], A[2], A[3], 0.85 } or (fss() and { 0, 0, 0, 1 } or (S.btnEdge or { 0.29, 0.25, 0.16, 1 }))
  st.edge:SetColorTexture(e[1], e[2], e[3], e[4] or 1)
end

local function skinMenu(menu)
  if menuSkin then return end
  for _, k in ipairs({ "Border", "Header", "NineSlice", "Bg", "TitleBg" }) do
    local c = rawget(menu, k)
    if type(c) == "table" and c.SetAlpha then pcall(c.SetAlpha, c, 0) end
  end
  for _, r in ipairs({ menu:GetRegions() }) do
    if r.GetObjectType and r:GetObjectType() == "Texture" then pcall(r.SetAlpha, r, 0) end
  end
  menuSkin = CreateFrame("Frame", nil, menu, "BackdropTemplate")
  menuSkin:SetAllPoints(menu)
  menuSkin:SetFrameLevel(math.max(0, menu:GetFrameLevel()))
  local A = accent()
  if G.setBackdrop then
    if fss() then G.setBackdrop(menuSkin, { 0.075, 0.08, 0.09, 0.95 }, { 0, 0, 0, 1 }, 1)
    else G.setBackdrop(menuSkin, S.bg, { GOLD[1], GOLD[2], GOLD[3], 0.85 }, 2) end
  end
  local t = menuSkin:CreateFontString(nil, "OVERLAY")
  t:SetFont(G.TF(), 17, "")
  t:SetTextColor(A[1], A[2], A[3])
  t:SetPoint("TOP", menuSkin, "TOP", 0, -12)
  t:SetText("Menu")
end

local function build(menu)
  if #buttons > 0 then return end
  local template = type(menu.buttonTemplate) == "string" and menu.buttonTemplate or "MainMenuFrameButtonTemplate"
  for i, spec in ipairs(SPECS) do
    local ok, b = pcall(CreateFrame, "Button", "GrimuarGameMenuButton" .. i, UIParent, template)
    if not ok or not b then b = CreateFrame("Button", "GrimuarGameMenuButton" .. i, UIParent, "UIPanelButtonTemplate") end
    b:SetParent(menu)
    b:SetSize(144, 21)
    b:SetText(spec[1])
    b:SetScript("OnClick", function()
      if SOUNDKIT and SOUNDKIT.IG_MAINMENU_OPTION then pcall(PlaySound, SOUNDKIT.IG_MAINMENU_OPTION) end
      spec[2]()
    end)
    b:Hide()
    buttons[i] = b
  end
  -- separator z runa pod naszymi przyciskami (tez element ukladu menu)
  divider = CreateFrame("Frame", nil, UIParent)
  divider:SetParent(menu)
  divider:SetSize(150, 14)
  local A = accent()
  local line = divider:CreateTexture(nil, "ARTWORK")
  line:SetColorTexture(A[1], A[2], A[3], 0.6)
  line:SetHeight(1)
  line:SetPoint("LEFT", divider, "LEFT", 6, 0)
  line:SetPoint("RIGHT", divider, "RIGHT", -6, 0)
  local rune = divider:CreateTexture(nil, "OVERLAY")
  rune:SetColorTexture(A[1], A[2], A[3], 1)
  rune:SetSize(7, 7)
  rune:SetPoint("CENTER")
  pcall(function() rune:SetRotation(math.rad(45)) end)
  divider:Hide()
  if G.addRuneCorners and not fss() then pcall(G.addRuneCorners, menu, 20) end
end

-- Po InitButtons: nasze ramki przed pierwszym przyciskiem menu (najmniejszy layoutIndex)
local function place(menu)
  if GrimuarSetupDB.noEscMenu then
    for _, b in ipairs(buttons) do b:Hide() end
    if divider then divider:Hide() end
    return
  end
  local pool = menu.buttonPool
  if not (pool and pool.EnumerateActive) then return end
  local first, ref
  for b in pool:EnumerateActive() do
    if type(b.layoutIndex) == "number" and (not first or b.layoutIndex < first) then first, ref = b.layoutIndex, b end
  end
  if not first then return end
  build(menu)
  local w, h = ref:GetWidth(), ref:GetHeight()
  for i, b in ipairs(buttons) do
    if w and w > 0 and h and h > 0 then b:SetSize(w, h) end
    b.layoutIndex, b.topPadding = first - 1 + i * 0.2, nil
    b:Show()
  end
  divider:SetWidth((w and w > 0) and w or 150)
  divider.layoutIndex, divider.topPadding = first - 1 + 0.9, 4
  divider:Show()
  -- skorka: menu i przyciski z puli (co otwarcie, bo pula oddaje te same ramki), nasze zawsze z polskimi literami
  local full = not GrimuarSetupDB.noSkins
  if full then
    pcall(skinMenu, menu)
    for b in pool:EnumerateActive() do pcall(skinButton, b, false, true) end
  end
  for _, b in ipairs(buttons) do pcall(skinButton, b, true, full) end
end

local function hook()
  local menu = _G.GameMenuFrame
  if not menu or G.escHooked then return end
  G.escHooked = true
  if type(rawget(menu, "InitButtons")) == "function" then
    hooksecurefunc(menu, "InitButtons", function(m) pcall(place, m) end)
  else
    -- starsze menu bez InitButtons: nasze przyciski pod dolna krawedzia menu
    menu:HookScript("OnShow", function(m)
      if GrimuarSetupDB.noEscMenu then return end
      build(m)
      local prev
      for _, b in ipairs(buttons) do
        b:ClearAllPoints()
        if prev then b:SetPoint("TOP", prev, "BOTTOM", 0, -2) else b:SetPoint("TOP", m, "BOTTOM", 0, -4) end
        b:Show()
        pcall(skinButton, b, true, not GrimuarSetupDB.noSkins)
        prev = b
      end
    end)
  end
end

local ev = CreateFrame("Frame")
ev:RegisterEvent("PLAYER_LOGIN")
ev:SetScript("OnEvent", function() pcall(hook) end)

G.showSessionEnd = showSummary
