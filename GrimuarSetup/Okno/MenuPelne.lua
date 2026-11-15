-- Grimuar: menu Esc wg makiety Esc.dc.html (13.11). gracz 14.11: „menu pod esc jeszcze mi tez inne pokazywales niz
-- obecnie jest, to tez do poprawy”. Lewa kolumna na cala wysokosc ekranu, zaslona z gradientem, w prawym dole „Ta sesja”,
-- w prawym gorze swiat i zegar.
-- Bezpieczenstwo (zasady FSS i R14): menu Blizzarda zostaje pod spodem, dostaje tylko SetAlpha(0); nic w nim nie
-- przesuwamy ani nie zapisujemy. Pozycje Blizzarda (Ustawienia, Edycja HUD, Makra, AddOny, Pomoc, Wyloguj, Wyjdz) to
-- nasze bezpieczne przyciski typu „click”, ktore klikaja prawdziwy przycisk z menu, wiec akcja idzie bezpieczna sciezka.
-- W walce zostaje zwykle menu (bezpiecznych przyciskow nie wolno wtedy pokazywac ani przestawiac); gdy walka zacznie sie
-- przy otwartym menu, PLAYER_REGEN_DISABLED (jeszcze przed blokada) chowa nasze i odslania menu Blizzarda.
local ADDON_NAME, G = ...

local GOLD, GOLD_DIM = { 0.85, 0.71, 0.36 }, { 0.6, 0.5, 0.28 }
local TEXT, MUTED, FAINT = { 0.93, 0.91, 0.86 }, { 0.6, 0.59, 0.55 }, { 0.45, 0.44, 0.41 }
local INK = { 0.039, 0.035, 0.027 }

local O -- nakladka
local items, seps = {}, {}
local classicOnce = false -- „klasyczne menu” do zamkniecia tego otwarcia

-- 15.11 (gracz: „menu sie nie zmienilo”): napis od razu z czcionka. SetText na napisie bez czcionki to blad „Font not
-- set”: build() wywracal sie na „MENU GRY” i pelne menu nigdy nie wstawalo (zostawalo menu Blizzarda).
local function newFS(parent)
  local fs = parent:CreateFontString(nil, "OVERLAY")
  fs:SetFontObject(GameFontHighlight)
  return fs
end
local function gm() return _G.GameMenuFrame end
local function closeMenu()
  local m = gm()
  if m and m:IsShown() then if HideUIPanel then HideUIPanel(m) else m:Hide() end end
end
local function click()
  if SOUNDKIT and SOUNDKIT.IG_MAINMENU_OPTION then pcall(PlaySound, SOUNDKIT.IG_MAINMENU_OPTION) end
end
local function keyOf(binding, fallback)
  local ok, k = pcall(GetBindingKey, binding)
  if ok and type(k) == "string" and k ~= "" then return (k:gsub("SHIFT%-", "Shift+"):gsub("CTRL%-", "Ctrl+")) end
  return fallback
end

-- przyciski Blizzarda z menu po InitButtons (pula) albo starsze nazwy
local BLIZZ = {
  options = { "GAMEMENU_OPTIONS", "Options", "GameMenuButtonOptions" },
  editmode = { "HUD_EDIT_MODE_MENU", "Edit Mode", "GameMenuButtonEditMode" },
  macros = { "MACROS", "Macros", "GameMenuButtonMacros" },
  addons = { "ADDONS", "AddOns", "GameMenuButtonAddons" },
  support = { "GAMEMENU_SUPPORT", "Support", "GameMenuButtonHelp" },
  logout = { "LOG_OUT", "Log Out", "GameMenuButtonLogout" },
  quit = { "EXIT_GAME", "Exit Game", "GameMenuButtonQuit" },
}
local function findBlizz(menu)
  local byText, out = {}, {}
  local pool = menu.buttonPool
  if pool and pool.EnumerateActive then
    for b in pool:EnumerateActive() do
      local ok, t = pcall(b.GetText, b)
      if ok and type(t) == "string" then byText[t] = b end
    end
  end
  for k, n in pairs(BLIZZ) do
    local g = _G[n[1]]
    out[k] = (type(g) == "string" and byText[g]) or byText[n[2]] or _G[n[3]]
  end
  return out
end

local function openKeybindings()
  if InCombatLockdown() or not (Settings and Settings.OpenToCategory) then return end
  local id = Settings.KEYBINDINGS_CATEGORY_ID
  if id then pcall(Settings.OpenToCategory, id) end
end

local function hubSettings(page)
  closeMenu()
  if G.ustawieniaOpen then C_Timer.After(0, function() G.ustawieniaOpen(page) end) return end
  C_Timer.After(0, function()
    if page == "klawisze" then openKeybindings()
    elseif page == "makra" then if ShowMacroFrame then pcall(ShowMacroFrame) end
    elseif Settings and Settings.OpenToCategory then pcall(Settings.OpenToCategory) end
  end)
end

local SPECS = {
  { "Wróć do gry", key = "Esc", run = closeMenu },
  { "Hub", keyB = { "GRIMUAR_HUB", "`" }, run = function()
      closeMenu()
      if GrimuarHubOpen then C_Timer.After(0, function() GrimuarHubOpen() end)
      else G.say("hub to addon GrimuarUI: włącz go na liście addonów.") end
    end },
  { "Plan sesji", run = function()
      closeMenu()
      if SlashCmdList.GRIMUAR and not (G.getPanel and G.getPanel() and G.getPanel():IsShown()) then SlashCmdList.GRIMUAR("") end
      if G.selectTab then pcall(G.selectTab, "teraz") end
    end },
  { sep = true },
  -- 15.11 (gracz: „klikam ustawienia… przestarzale okno… w nowym naszym stylu”, „fullscreen”): Ustawienia, Klawisze
  -- i Makra otwieraja zakladke Ustawienia huba (GrimuarUI); bez GrimuarUI zostaje okno gry
  { "Ustawienia", run = function() hubSettings(nil) end },
  { "Interfejs i tryby HUD", blizz = "editmode" },
  { "Klawisze", run = function() hubSettings("klawisze") end },
  { "Makra", run = function() hubSettings("makra") end },
  { "AddOny", blizz = "addons" },
  { "Pomoc i zgłoszenia", blizz = "support" },
  { sep = true },
  { "Kończę grę — podsumuj", run = function() if G.showSessionEnd then G.showSessionEnd() end end },
  { "Wyloguj", blizz = "logout", macro = "/logout", quiet = true },
  { "Wyjdź z gry", blizz = "quit", macro = "/quit", quiet = true },
}

local function font(fs, path, size)
  -- SetFont oddaje false, gdy pliku nie ma: wtedy zwykla czcionka gry
  if fs:SetFont(path, size, "") == false then fs:SetFont("Fonts\\ARIALN.TTF", size, "") end
end

local function paint(it, on)
  local c = on and GOLD or (it.spec.quiet and FAINT or MUTED)
  it.b.t:SetTextColor(c[1], c[2], c[3])
  it.b.hl:SetShown(on)
  it.b.rh:SetShown(on)
end
local function selectItem(b)
  for _, it in ipairs(items) do paint(it, it.b == b) end
end

-- ---------- budowa (raz, poza walka) ----------
local function build()
  if O then return O end
  O = CreateFrame("Frame", "GrimuarEscMenu", UIParent)
  O:SetAllPoints(UIParent)
  O:SetFrameStrata("FULLSCREEN")
  O:EnableMouse(true) -- lapie klikniecia, zeby nie trafialy w niewidoczne menu Blizzarda pod spodem
  O:Hide()
  -- zaslona: od lewej prawie czarna, do 42% szerokosci 0.72, w prawo do 0.25
  O.v1 = O:CreateTexture(nil, "BACKGROUND", nil, -8)
  O.v2 = O:CreateTexture(nil, "BACKGROUND", nil, -8)
  for i, v in ipairs({ O.v1, O.v2 }) do
    v:SetColorTexture(1, 1, 1, 1)
    local a1, a2 = (i == 1) and 0.96 or 0.72, (i == 1) and 0.72 or 0.25
    pcall(v.SetGradient, v, "HORIZONTAL", CreateColor(INK[1], INK[2], INK[3], a1), CreateColor(INK[1], INK[2], INK[3], a2))
  end
  -- naglowek
  O.rune = O:CreateTexture(nil, "ARTWORK")
  O.rune:SetColorTexture(GOLD_DIM[1], GOLD_DIM[2], GOLD_DIM[3], 1)
  pcall(O.rune.SetRotation, O.rune, math.rad(45))
  O.brand = newFS(O)
  O.brand:SetTextColor(GOLD_DIM[1], GOLD_DIM[2], GOLD_DIM[3])
  O.brand:SetText("MENU GRY")
  O.sub = newFS(O)
  O.sub:SetTextColor(FAINT[1], FAINT[2], FAINT[3])
  O.sub:SetText("Świat się nie zatrzymuje — Esc nie pauzuje gry.")
  O.sub:SetJustifyH("LEFT")
  -- pozycje
  for i, spec in ipairs(SPECS) do
    if spec.sep then
      local s = O:CreateTexture(nil, "ARTWORK")
      s:SetColorTexture(GOLD[1], GOLD[2], GOLD[3], 0.22)
      seps[#seps + 1] = s
      spec.tex = s
    else
      local b
      if spec.blizz then
        b = CreateFrame("Button", "GrimuarEscItem" .. i, O, "SecureActionButtonTemplate")
        pcall(b.RegisterForClicks, b, "AnyUp", "AnyDown")
        b:SetScript("PostClick", function()
          click()
          if spec.after then C_Timer.After(0.05, spec.after) end
        end)
      else
        b = CreateFrame("Button", nil, O)
        b:RegisterForClicks("LeftButtonUp")
        b:SetScript("OnClick", function() click() spec.run() end)
      end
      b.hl = b:CreateTexture(nil, "BACKGROUND")
      b.hl:SetAllPoints(b)
      b.hl:SetColorTexture(1, 1, 1, 1)
      pcall(b.hl.SetGradient, b.hl, "HORIZONTAL", CreateColor(GOLD[1], GOLD[2], GOLD[3], 0.12), CreateColor(GOLD[1], GOLD[2], GOLD[3], 0))
      b.rh = b:CreateTexture(nil, "ARTWORK")
      b.rh:SetColorTexture(GOLD[1], GOLD[2], GOLD[3], 1)
      pcall(b.rh.SetRotation, b.rh, math.rad(45))
      b.t = newFS(b)
      b.t:SetJustifyH("LEFT")
      b.t:SetText(spec[1])
      b.k = newFS(b)
      b.k:SetJustifyH("RIGHT")
      b.k:SetTextColor(FAINT[1], FAINT[2], FAINT[3])
      b:SetScript("OnEnter", function(self) selectItem(self) end)
      items[#items + 1] = { b = b, spec = spec }
      spec.item = items[#items]
    end
  end
  -- klasyczne menu Blizzarda (Sklep, przycisk Polestara): na to jedno otwarcie
  O.classic = CreateFrame("Button", nil, O)
  O.classic.t = newFS(O.classic)
  O.classic.t:SetPoint("LEFT")
  O.classic.t:SetTextColor(FAINT[1], FAINT[2], FAINT[3])
  O.classic.t:SetText("Klasyczne menu gry (Sklep, Polestar)")
  O.classic:SetScript("OnEnter", function(self) self.t:SetTextColor(GOLD[1], GOLD[2], GOLD[3]) end)
  O.classic:SetScript("OnLeave", function(self) self.t:SetTextColor(FAINT[1], FAINT[2], FAINT[3]) end)
  O.classic:SetScript("OnClick", function()
    click()
    classicOnce = true
    if not InCombatLockdown() then O:Hide() end
    local m = gm()
    if m then m:SetAlpha(1) end
  end)
  -- prawy gorny rog: swiat i zegar
  O.clock = newFS(O)
  O.clock:SetTextColor(FAINT[1], FAINT[2], FAINT[3])
  O.clock:SetJustifyH("RIGHT")
  -- prawy dol: „Ta sesja”
  O.pane = CreateFrame("Frame", nil, O, "BackdropTemplate")
  if G.setBackdrop then G.setBackdrop(O.pane, { 0.051, 0.043, 0.035, 0.82 }, { GOLD[1], GOLD[2], GOLD[3], 0.18 }, 1) end
  O.pane.lab = newFS(O.pane)
  O.pane.lab:SetTextColor(GOLD_DIM[1], GOLD_DIM[2], GOLD_DIM[3])
  O.pane.lab:SetText("TA SESJA")
  O.pane.rows = {}
  for i, name in ipairs({ "Czas", "Poziom", "Zgony" }) do
    local dt = newFS(O.pane)
    dt:SetTextColor(MUTED[1], MUTED[2], MUTED[3])
    dt:SetText(name)
    local dd = newFS(O.pane)
    dd:SetTextColor(TEXT[1], TEXT[2], TEXT[3])
    dd:SetJustifyH("RIGHT")
    O.pane.rows[i] = { dt = dt, dd = dd }
  end
  O.pane.sep = O.pane:CreateTexture(nil, "ARTWORK")
  O.pane.sep:SetColorTexture(GOLD[1], GOLD[2], GOLD[3], 0.22)
  O.pane.next = newFS(O.pane)
  O.pane.next:SetTextColor(TEXT[1], TEXT[2], TEXT[3])
  O.pane.next:SetJustifyH("LEFT")
  O.pane.next:SetWordWrap(true)
  local acc = 0
  O:SetScript("OnUpdate", function(self, el)
    acc = acc + el
    if acc < 1 then return end
    acc = 0
    if self.fill then pcall(self.fill) end
  end)
  return O
end

-- ---------- dane ----------
local function hm(mins)
  mins = math.floor(mins or 0)
  if mins < 60 then return mins .. " min" end
  return math.floor(mins / 60) .. " h " .. (mins % 60) .. " min"
end
local function fill()
  local realm = (GetRealmName and GetRealmName()) or ""
  O.clock:SetText(realm .. (realm ~= "" and "     " or "") .. date("%H:%M"))
  local S = G.S or {}
  local r = O.pane.rows
  r[1].dd:SetText(G.sessionMinutes and hm(G.sessionMinutes()) or "—")
  local l, l0 = UnitLevel("player") or 1, S.level0
  r[2].dd:SetText((l0 and l0 ~= l) and (l0 .. " → " .. l) or tostring(l))
  r[3].dd:SetText(tostring(S.deaths and #S.deaths or 0))
  local nextTxt
  if G.planView then
    local okP, list, idx = pcall(G.planView)
    if okP and list and idx and list[idx] then nextTxt = (list[idx].text or "") .. "  ·  " .. idx .. " / " .. #list end
  end
  if not nextTxt and Polestar and Polestar.Nav and Polestar.Nav.GetTarget then
    local okN, t = pcall(Polestar.Nav.GetTarget)
    if okN and type(t) == "table" and t.label then nextTxt = tostring(t.label) .. " (Polestar)" end
  end
  local M = "|cff99968c"
  O.pane.next:SetText(M .. "Następny krok:|r " .. (nextTxt or "ułóż plan: „Plan sesji” po lewej"))
end

-- ---------- uklad wg makiety (1600 x 900, skalowany do wysokosci ekranu) ----------
local function layout()
  local H = UIParent:GetHeight() or 768
  local W = UIParent:GetWidth() or 1366
  local k = H / 900
  local function px(v) return math.floor(v * k + 0.5) end
  local TF, BF = G.TF and G.TF() or G.FONT, G.BF and G.BF() or G.FONT
  O.v1:ClearAllPoints()
  O.v1:SetPoint("TOPLEFT", O, "TOPLEFT")
  O.v1:SetPoint("BOTTOMLEFT", O, "BOTTOMLEFT")
  O.v1:SetWidth(W * 0.42)
  O.v2:ClearAllPoints()
  O.v2:SetPoint("TOPLEFT", O.v1, "TOPRIGHT")
  O.v2:SetPoint("BOTTOMRIGHT", O, "BOTTOMRIGHT")
  -- wysokosc kolumny: naglowek + pozycje
  local colW, x = px(440), px(110)
  local hBrand, hSub = px(30), px(18)
  local total = hBrand + px(6) + hSub + px(18)
  for _, spec in ipairs(SPECS) do
    if spec.sep then total = total + px(21)
    elseif spec.item and spec.item.on then total = total + (spec.quiet and px(38) or px(44)) + px(4) end
  end
  total = total + px(40)
  local y = math.floor((H - total) / 2)
  O.rune:SetSize(px(8), px(8))
  O.rune:ClearAllPoints()
  O.rune:SetPoint("TOPLEFT", O, "TOPLEFT", x + px(4), -(y + px(11)))
  font(O.brand, TF, px(19))
  O.brand:ClearAllPoints()
  O.brand:SetPoint("LEFT", O.rune, "RIGHT", px(12), 0)
  y = y + hBrand + px(6)
  font(O.sub, BF, px(13))
  O.sub:ClearAllPoints()
  O.sub:SetPoint("TOPLEFT", O, "TOPLEFT", x + px(2), -y)
  O.sub:SetWidth(colW)
  y = y + hSub + px(18)
  for _, spec in ipairs(SPECS) do
    if spec.sep then
      spec.tex:ClearAllPoints()
      spec.tex:SetPoint("TOPLEFT", O, "TOPLEFT", x + px(16), -(y + px(10)))
      spec.tex:SetSize(colW - px(32), 1)
      y = y + px(21)
    elseif spec.item then
      local b = spec.item.b
      if spec.item.on then
        local h = spec.quiet and px(38) or px(44)
        b:ClearAllPoints()
        b:SetPoint("TOPLEFT", O, "TOPLEFT", x, -y)
        b:SetSize(colW, h)
        b.rh:SetSize(px(7), px(7))
        b.rh:ClearAllPoints()
        b.rh:SetPoint("LEFT", b, "LEFT", px(18), 0)
        font(b.t, TF, spec.quiet and px(18) or px(21))
        b.t:ClearAllPoints()
        b.t:SetPoint("LEFT", b, "LEFT", px(16) + px(7) + px(16), 0)
        font(b.k, BF, px(15))
        b.k:ClearAllPoints()
        b.k:SetPoint("RIGHT", b, "RIGHT", -px(16), 0)
        b.k:SetText(spec.key or (spec.keyB and keyOf(spec.keyB[1], spec.keyB[2])) or "")
        b:Show()
        y = y + h + px(4)
      else
        b:Hide()
      end
    end
  end
  font(O.classic.t, BF, px(13))
  O.classic:ClearAllPoints()
  O.classic:SetPoint("TOPLEFT", O, "TOPLEFT", x + px(16), -(y + px(16)))
  O.classic:SetSize(colW - px(32), px(20))
  -- zegar
  font(O.clock, BF, px(13))
  O.clock:ClearAllPoints()
  O.clock:SetPoint("TOPRIGHT", O, "TOPRIGHT", -px(56), -px(40))
  -- panel sesji
  local P = O.pane
  local pw, pad = px(360), px(16)
  P:ClearAllPoints()
  P:SetPoint("BOTTOMRIGHT", O, "BOTTOMRIGHT", -px(56), px(56))
  P:SetWidth(pw)
  font(P.lab, TF, px(13))
  P.lab:ClearAllPoints()
  P.lab:SetPoint("TOPLEFT", P, "TOPLEFT", pad, -pad)
  local py = pad + px(16) + px(10)
  for _, row in ipairs(P.rows) do
    font(row.dt, BF, px(15))
    font(row.dd, BF, px(15))
    row.dt:ClearAllPoints()
    row.dt:SetPoint("TOPLEFT", P, "TOPLEFT", pad, -py)
    row.dd:ClearAllPoints()
    row.dd:SetPoint("TOPRIGHT", P, "TOPRIGHT", -pad, -py)
    py = py + px(22)
  end
  py = py + px(4)
  P.sep:ClearAllPoints()
  P.sep:SetPoint("TOPLEFT", P, "TOPLEFT", pad, -py)
  P.sep:SetSize(pw - 2 * pad, 1)
  py = py + px(10)
  font(P.next, BF, px(14))
  P.next:ClearAllPoints()
  P.next:SetPoint("TOPLEFT", P, "TOPLEFT", pad, -py)
  P.next:SetWidth(pw - 2 * pad)
  fill()
  P:SetHeight(py + math.max(px(18), P.next:GetStringHeight() or 0) + pad)
end

-- ---------- pokazanie / schowanie ----------
local function hideOverlay()
  if O and O:IsShown() and not InCombatLockdown() then O:Hide() end
  local m = gm()
  if m then m:SetAlpha(1) end
end

local function showOverlay(menu)
  if GrimuarSetupDB.noEscMenu or GrimuarSetupDB.escClassic or classicOnce or InCombatLockdown() then
    menu:SetAlpha(1)
    return
  end
  build()
  local found = findBlizz(menu)
  for _, it in ipairs(items) do
    local spec = it.spec
    it.on = true
    if spec.blizz then
      local bb = found[spec.blizz]
      if bb then
        it.b:SetAttribute("type", "click")
        it.b:SetAttribute("clickbutton", bb)
        it.b:SetAttribute("macrotext", nil)
      elseif spec.macro then
        it.b:SetAttribute("type", "macro")
        it.b:SetAttribute("macrotext", spec.macro)
        it.b:SetAttribute("clickbutton", nil)
      else
        it.on = false
      end
    end
  end
  O.fill = fill
  local ok, err = pcall(layout)
  if not ok then
    -- uklad sie nie udal: zostaje menu Blizzarda, blad do /grimuar bledy
    GrimuarSetupDB.escErr = tostring(err)
    menu:SetAlpha(1)
    if not G.escErrSaid then G.escErrSaid = true G.say("menu Esc na cały ekran nie wstało: " .. tostring(err)) end
    return
  end
  selectItem(items[1] and items[1].b)
  menu:SetAlpha(0)
  O:Show()
end

local function hook()
  local menu = gm()
  if not menu or G.escFullHooked then return end
  G.escFullHooked = true
  menu:HookScript("OnShow", function(m)
    local ok, err = pcall(showOverlay, m)
    if not ok then
      GrimuarSetupDB.escErr = tostring(err)
      pcall(m.SetAlpha, m, 1)
      if not G.escErrSaid then G.escErrSaid = true G.say("menu Esc na cały ekran nie wstało: " .. tostring(err)) end
    end
  end)
  menu:HookScript("OnHide", function()
    classicOnce = false
    hideOverlay()
  end)
end

local ev = CreateFrame("Frame")
ev:RegisterEvent("PLAYER_LOGIN")
ev:RegisterEvent("PLAYER_REGEN_DISABLED")
ev:RegisterEvent("PLAYER_REGEN_ENABLED")
ev:SetScript("OnEvent", function(_, e)
  if e == "PLAYER_LOGIN" then
    pcall(hook)
    -- nakladka zbudowana od razu (poza walka), zeby w razie Esc w walce nie tworzyc bezpiecznych przyciskow
    if not InCombatLockdown() then pcall(build) end
  elseif e == "PLAYER_REGEN_DISABLED" then
    -- jeszcze przed blokada: chowamy nasze, menu Blizzarda zostaje widoczne
    hideOverlay()
  else
    local m = gm()
    if m and m:IsShown() and not (O and O:IsShown()) then pcall(showOverlay, m) end
  end
end)
