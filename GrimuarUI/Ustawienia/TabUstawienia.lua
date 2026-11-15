-- Grimuar UI: zakladka Ustawienia na caly ekran (15.11, plan R29 etap 2; gracz: „klikam ustawienia… przestarzale okno…
-- w nowym naszym stylu”, „fullscreen”). Zamiast okna Options (ForeverSkin) z menu Esc:
-- * lewo: szyna stron: Gra (Sterowanie, Kamera, Walka, Interfejs), System (Grafika, Dzwiek), Grimuar (przelaczniki
--   Grimuara, Klawisze, Makra), Wiecej („Pelne ustawienia gry” otwiera okno gry / ForeverSkin);
-- * prawo: wyszukiwarka po wszystkich stronach i wiersze opcji po polsku: przelacznik, suwak albo wybor (klik = nastepna
--   wartosc); znaczek „Grimuar” przy opcji, ktora ustawia Grimuar (G.CVARS z Core.lua), z powodem w dymku.
-- Zmiany przez CVary gry (C_CVar.SetCVar) poza walka; w walce czekaja do jej konca. Opcje, ktorych klient nie zna
-- (brak CVaru), sa pomijane. Strony Klawisze i Makra: Ustawienia\Klawisze.lua, Ustawienia\Makra.lua (U.UST.pages).
local ADDON, U = ...
local C = U.C
local G = U.G or {}

local UST = U.UST or { pages = {} }
U.UST = UST
local S = { page = "sterowanie", q = "", rows = {}, pending = {} }
local RAIL_W = 260

-- ---------- CVary ----------
local function getCVar(name)
  local ok, v = pcall(function() return C_CVar and C_CVar.GetCVar and C_CVar.GetCVar(name) or GetCVar(name) end)
  return ok and v or nil
end
local function setCVar(name, value)
  if InCombatLockdown() then S.pending[name] = value U.say("zmienię po walce: " .. name .. ".") return end
  pcall(function() if C_CVar and C_CVar.SetCVar then C_CVar.SetCVar(name, tostring(value)) else SetCVar(name, tostring(value)) end end)
end
local function grimuarWhy(cvar)
  for _, c in ipairs(G.CVARS or {}) do if c[1] == cvar then return c[3] or "ustawia Grimuar" end end
  return nil
end

-- opcja: { label, cvar, kind = "toggle" | "slider" | "choice", inv, min, max, step, fmt, choices = { { value, label } } }
local P = {
  sterowanie = { title = "Sterowanie", group = "GRA", rows = {
    { "Automatyczne łupy", "autoLootDefault", "toggle" },
    { "Interakcja lewym przyciskiem myszy", "interactOnLeftClick", "toggle" },
    { "Klik w ziemię nie zdejmuje celu", "deselectOnClick", "toggle", inv = true },
    { "Okno łupów przy myszce", "lootUnderMouse", "toggle" },
    { "Wychodzisz z „Zaraz wracam”, gdy się ruszysz", "autoClearAFK", "toggle" },
    { "Czułość myszy", "mouseSpeed", "slider", min = 0.5, max = 1.5, step = 0.05, fmt = "%.2f" },
    { "Szybkość obrotu kamery myszą", "cameraYawMoveSpeed", "slider", min = 90, max = 270, step = 10, fmt = "%d" },
    { "Odwróć mysz", "mouseInvertPitch", "toggle" },
  } },
  kamera = { title = "Kamera", group = "GRA", rows = {
    { "Maksymalne oddalenie kamery", "cameraDistanceMaxZoomFactor", "slider", min = 1, max = 2.6, step = 0.1, fmt = "%.1f" },
    { "Kamera podąża za postacią", "cameraSmoothStyle", "choice", choices = { { "0", "nigdy" }, { "1", "gdy idziesz" }, { "2", "zawsze" }, { "4", "sprytnie" } } },
    { "Kamera w wodzie nie zderza się z powierzchnią", "cameraWaterCollision", "toggle", inv = true },
  } },
  walka = { title = "Walka", group = "GRA", rows = {
    { "Liczby obrażeń nad celem", "floatingCombatTextCombatDamage", "toggle" },
    { "Liczby leczenia nad celem", "floatingCombatTextCombatHealing", "toggle" },
    { "Czary przy wciśnięciu klawisza (nie przy puszczeniu)", "ActionButtonUseKeyDown", "toggle" },
    { "Okno kolejki czarów (ms)", "SpellQueueWindow", "slider", min = 0, max = 400, step = 10, fmt = "%d" },
    { "Automatyczne rzucanie na siebie", "autoSelfCast", "toggle" },
    { "Cel celu przy ramce celu", "showTargetOfTarget", "toggle" },
    { "Wbudowany Cooldown Manager gry", "cooldownViewerEnabled", "toggle" },
  } },
  interfejs = { title = "Interfejs", group = "GRA", rows = {
    { "Tabliczki wrogów", "nameplateShowEnemies", "toggle" },
    { "Tabliczki przyjaciół", "nameplateShowFriends", "toggle" },
    { "Imiona graczy wroga", "UnitNameEnemyPlayerName", "toggle" },
    { "Imiona NPC", "UnitNameNPC", "toggle" },
    { "Dymki czatu", "chatBubbles", "toggle" },
    { "Własna skala interfejsu", "useUiScale", "toggle" },
    { "Skala interfejsu", "uiScale", "slider", min = 0.64, max = 1.15, step = 0.01, fmt = "%.2f" },
  } },
  grafika = { title = "Grafika", group = "SYSTEM", rows = {
    { "Jakość grafiki (1–10)", "graphicsQuality", "slider", min = 1, max = 10, step = 1, fmt = "%d" },
    { "Synchronizacja pionowa", "gxVSync", "toggle" },
    { "Limit FPS włączony", "useMaxFPS", "toggle" },
    { "Limit FPS", "maxFPS", "slider", min = 30, max = 240, step = 5, fmt = "%d" },
    { "Limit FPS w tle włączony", "useMaxFPSBk", "toggle" },
    { "Limit FPS w tle", "maxFPSBk", "slider", min = 8, max = 60, step = 1, fmt = "%d" },
  } },
  dzwiek = { title = "Dźwięk", group = "SYSTEM", rows = {
    { "Dźwięk włączony", "Sound_EnableAllSound", "toggle" },
    { "Głośność ogólna", "Sound_MasterVolume", "slider", min = 0, max = 1, step = 0.05, pct = true },
    { "Muzyka włączona", "Sound_EnableMusic", "toggle" },
    { "Muzyka", "Sound_MusicVolume", "slider", min = 0, max = 1, step = 0.05, pct = true },
    { "Efekty", "Sound_SFXVolume", "slider", min = 0, max = 1, step = 0.05, pct = true },
    { "Otoczenie", "Sound_AmbienceVolume", "slider", min = 0, max = 1, step = 0.05, pct = true },
    { "Dialogi", "Sound_DialogVolume", "slider", min = 0, max = 1, step = 0.05, pct = true },
    { "Dźwięk, gdy gra jest w tle", "Sound_EnableSoundWhenGameIsInBG", "toggle" },
  } },
}
local ORDER = {
  { "GRA", { "sterowanie", "kamera", "walka", "interfejs" } },
  { "SYSTEM", { "grafika", "dzwiek" } },
  { "GRIMUAR", { "grimuar", "klawisze", "makra" } },
}
P.grimuar = { title = "Grimuar", group = "GRIMUAR", custom = true }
UST.cvarPages = P

-- ---------- kontrolki wiersza ----------
local function toggle(parent)
  local b = CreateFrame("Button", nil, parent)
  b:SetSize(44, 20)
  b.bg = U.Rect(b, { 0, 0, 0 }, 0.4) b.bg:SetAllPoints()
  U.Border(b, C.edge)
  b.d = U.Diamond(b, 14, C.faint, true)
  function b:Set(on)
    self.d:ClearAllPoints()
    self.d:SetPoint("CENTER", self, "CENTER", on and 11 or -11, 0)
    self.d:Set(on and C.gold or { 0.35, 0.31, 0.25 }, true)
    U.BorderColor(self, on and C.gold or C.edge)
  end
  return b
end
local function slider(parent)
  local s = CreateFrame("Slider", nil, parent)
  s:SetSize(220, 16)
  s:SetOrientation("HORIZONTAL")
  s.track = U.Rect(s, C.gold, 0.15, "BACKGROUND") s.track:SetPoint("LEFT") s.track:SetPoint("RIGHT") s.track:SetHeight(4)
  s.fill = U.Rect(s, C.gold, 0.9, "ARTWORK") s.fill:SetPoint("LEFT") s.fill:SetHeight(4)
  local thumb = s:CreateTexture(nil, "OVERLAY")
  thumb:SetTexture(U.WHITE)
  thumb:SetVertexColor(C.gold[1], C.gold[2], C.gold[3], 1)
  thumb:SetSize(10, 10)
  s:SetThumbTexture(thumb)
  pcall(thumb.SetRotation, thumb, math.rad(45))
  pcall(s.SetObeyStepOnDrag, s, true)
  s.val = U.Text(parent, 12, "body", C.text)
  s.val:SetPoint("LEFT", s, "RIGHT", 10, 0)
  s.val:SetWidth(46)
  return s
end

local function rowFrame(i)
  local r = S.rows[i]
  if r then return r end
  r = CreateFrame("Frame", nil, S.list)
  r:SetHeight(34)
  r.bg = U.Rect(r, C.gold, 0, "BACKGROUND") r.bg:SetAllPoints()
  r:SetScript("OnEnter", function(self) self.bg:SetColorTexture(C.gold[1], C.gold[2], C.gold[3], 0.05)
    if self.tip then GameTooltip:SetOwner(self, "ANCHOR_RIGHT") GameTooltip:SetText(self.tip, 1, 1, 1, 1, true) GameTooltip:Show() end end)
  r:SetScript("OnLeave", function(self) self.bg:SetColorTexture(1, 1, 1, 0) GameTooltip:Hide() end)
  r.t = U.Text(r, 14, "body", C.text)
  r.t:SetPoint("LEFT", 12, 0) r.t:SetJustifyV("MIDDLE")
  r.badge = U.Tag(r, "Grimuar", C.ok)
  r.badge:SetPoint("LEFT", r.t, "RIGHT", 10, 0)
  r.head = U.Text(r, 14, "title", C.gold)
  r.head:SetPoint("LEFT", 4, -4)
  r.line = U.Line(r, C.gold, 0.25)
  r.line:SetPoint("BOTTOMLEFT", 4, 2) r.line:SetPoint("BOTTOMRIGHT", -4, 2)
  r.tog = toggle(r)
  r.tog:SetPoint("RIGHT", -16, 0)
  r.sl = slider(r)
  r.sl:SetPoint("RIGHT", -76, 0)
  r.ch = U.Button(r, "", 170, 24)
  r.ch:SetPoint("RIGHT", -16, 0)
  r.act = U.Button(r, "", nil, 24)
  r.act:SetPoint("RIGHT", -16, 0)
  S.rows[i] = r
  return r
end

local function hideCtl(r)
  r.tog:Hide() r.sl:Hide() r.sl.val:Hide() r.ch:Hide() r.act:Hide() r.badge:Hide() r.head:Hide() r.line:Hide()
  r.t:Show()
  r.tip = nil
  r.sl:SetScript("OnValueChanged", nil)
end

-- ---------- opisy wierszy do rysowania (opcja CVar albo przelacznik Grimuara) ----------
local function cvarRow(o)
  local v = getCVar(o[2])
  if v == nil then return nil end
  return { kind = o[3], label = o[1], cvar = o[2], o = o, why = grimuarWhy(o[2]) }
end
local function collect()
  local out = {}
  local q = (S.q or ""):lower()
  local function match(label) return q == "" or label:lower():find(q, 1, true) end
  local pages = {}
  if q ~= "" then
    for _, grp in ipairs(ORDER) do for _, k in ipairs(grp[2]) do pages[#pages + 1] = k end end
  else
    pages = { S.page }
  end
  for _, k in ipairs(pages) do
    local pg = P[k]
    local rows = {}
    if pg and pg.rows then
      for _, o in ipairs(pg.rows) do
        if match(o[1]) then local r = cvarRow(o) if r then rows[#rows + 1] = r end end
      end
    elseif k == "grimuar" then
      for _, t in ipairs(G.TOGGLES or {}) do
        if match(t[1]) then rows[#rows + 1] = { kind = "gtoggle", label = t[1], t = t } end
      end
    elseif UST.pages[k] and UST.pages[k].search and q ~= "" then
      for _, r in ipairs(UST.pages[k].search(q) or {}) do rows[#rows + 1] = r end
    end
    if #rows > 0 then
      if q ~= "" then out[#out + 1] = { kind = "head", label = (P[k] and P[k].title) or (UST.pages[k] and UST.pages[k].title) or k } end
      for _, r in ipairs(rows) do out[#out + 1] = r end
    end
  end
  return out
end

local function fmtVal(o, v)
  v = tonumber(v) or 0
  if o.pct then return math.floor(v * 100 + 0.5) .. "%" end
  return string.format(o.fmt or "%s", v)
end

local function drawRows()
  local list = collect()
  local w = S.list:GetWidth() or 600
  for i, it in ipairs(list) do
    local r = rowFrame(i)
    r:ClearAllPoints() r:SetPoint("TOPLEFT", S.list, "TOPLEFT", 0, -(i - 1) * 36) r:SetWidth(w)
    hideCtl(r)
    if it.kind == "head" then
      r.t:Hide() r.head:Show() r.line:Show()
      r.head:SetText(it.label)
    else
      r.t:SetText(it.label)
      if it.why then r.badge:Show() r.tip = "Grimuar: " .. it.why .. " (kreator albo build)" end
      if it.kind == "toggle" then
        local on = getCVar(it.cvar) == "1"
        if it.o.inv then on = not on end
        r.tog:Show() r.tog:Set(on)
        r.tog:SetScript("OnClick", function()
          local now = getCVar(it.cvar) == "1"
          setCVar(it.cvar, now and "0" or "1")
          C_Timer.After(0.05, function() pcall(drawRows) end)
        end)
      elseif it.kind == "slider" then
        local o = it.o
        r.sl:Show() r.sl.val:Show()
        r.sl:SetMinMaxValues(o.min, o.max)
        r.sl:SetValueStep(o.step)
        local v = tonumber(getCVar(it.cvar)) or o.min
        r.sl:SetValue(v)
        r.sl.fill:SetWidth(math.max(1, 220 * (v - o.min) / math.max(0.0001, o.max - o.min)))
        r.sl.val:SetText(fmtVal(o, v))
        r.sl:SetScript("OnValueChanged", function(self, nv, user)
          self.fill:SetWidth(math.max(1, 220 * (nv - o.min) / math.max(0.0001, o.max - o.min)))
          self.val:SetText(fmtVal(o, nv))
          if user then
            S.slideAt = GetTime()
            local key, val = it.cvar, nv
            C_Timer.After(0.35, function() if GetTime() - (S.slideAt or 0) >= 0.3 then setCVar(key, (o.step >= 1) and math.floor(val + 0.5) or val) end end)
          end
        end)
      elseif it.kind == "choice" then
        local cur = getCVar(it.cvar)
        local label, idx = cur, 1
        for k, c in ipairs(it.o.choices) do if c[1] == cur then label, idx = c[2], k end end
        r.ch:Show() r.ch:SetLabel(label .. "  ▸")
        r.ch:SetScript("OnClick", function()
          local nxt = it.o.choices[idx % #it.o.choices + 1]
          setCVar(it.cvar, nxt[1])
          C_Timer.After(0.05, function() pcall(drawRows) end)
        end)
      elseif it.kind == "gtoggle" then
        local on = false
        pcall(function() on = it.t[2]() and true or false end)
        r.tog:Show() r.tog:Set(on)
        r.tog:SetScript("OnClick", function()
          if InCombatLockdown() then U.say("przełączę po walce.") return end
          pcall(it.t[3])
          C_Timer.After(0.1, function() pcall(drawRows) end)
        end)
      elseif it.kind == "action" then
        r.act:Show() r.act:SetLabel(it.btn or "Zmień")
        r.act:SetScript("OnClick", function() pcall(it.fn) end)
        if it.sub then r.tip = it.sub end
      end
    end
    r:Show()
  end
  for i = #list + 1, #S.rows do S.rows[i]:Hide() end
  S.list:SetHeight(math.max(10, #list * 36))
  S.empty:SetShown(#list == 0)
end

function U.ustawieniaRefresh()
  if not (S.page and S.root and S.root:IsVisible()) then return end
  for k, b in pairs(S.rail) do
    U.Color(b.t, k == S.page and C.gold or C.text)
    local on = k == S.page and (S.q or "") == ""
    b.sel:SetShown(on) b.bar:SetShown(on)
  end
  local custom = UST.pages[S.page]
  local useCustom = custom and (S.q or "") == ""
  S.view:SetShown(not useCustom)
  for k, pg in pairs(UST.pages) do if pg.frame then pg.frame:SetShown(useCustom and k == S.page) end end
  if useCustom then
    if not custom.frame then custom.frame = custom.build(S.body) end
    custom.frame:Show()
    pcall(custom.draw)
    S.ptitle:SetText(custom.title)
    S.pnote:SetText(custom.note or "")
  else
    S.ptitle:SetText((S.q or "") ~= "" and ("Szukaj: " .. S.q) or (P[S.page] and P[S.page].title or ""))
    S.pnote:SetText(InCombatLockdown() and "w walce zmiany czekają do jej końca" or "zmiany od razu")
    pcall(drawRows)
  end
end
function U.ustawieniaOpen(page)
  if page then S.page = page end
  S.q = ""
  if S.search then S.search:SetText("") S.search:ClearFocus() end
  if GrimuarHubOpen then GrimuarHubOpen("ustawienia") end
  C_Timer.After(0, function() pcall(U.ustawieniaRefresh) end)
end
if U.G then U.G.ustawieniaOpen = U.ustawieniaOpen end

local function openFull()
  if InCombatLockdown() then U.say("pełne ustawienia gry po walce.") return end
  if U.Close then pcall(U.Close) end
  C_Timer.After(0.05, function()
    if Settings and Settings.OpenToCategory then
      if not pcall(Settings.OpenToCategory) and SettingsPanel then pcall(ShowUIPanel, SettingsPanel) end
    elseif SettingsPanel then pcall(ShowUIPanel, SettingsPanel) end
  end)
end

local function build(page)
  S.root = page
  local rail = U.Panel(page, 0.86, true)
  rail:SetPoint("TOPLEFT") rail:SetPoint("BOTTOMLEFT") rail:SetWidth(RAIL_W)
  local h = U.H2(rail, "Ustawienia")
  h:SetPoint("TOPLEFT", 18, -16)
  S.rail = {}
  local y = -52
  for _, grp in ipairs(ORDER) do
    local gl = U.Label(rail, grp[1])
    gl:SetPoint("TOPLEFT", 18, y)
    y = y - 22
    for _, k in ipairs(grp[2]) do
      local b = CreateFrame("Button", nil, rail)
      b:SetSize(RAIL_W - 16, 30)
      b:SetPoint("TOPLEFT", 8, y)
      b.sel = U.Rect(b, C.gold, 0.12) b.sel:SetAllPoints()
      b.bar = U.Rect(b, C.gold, 1, "ARTWORK") b.bar:SetPoint("TOPLEFT") b.bar:SetPoint("BOTTOMLEFT") b.bar:SetWidth(2)
      b.sel:Hide() b.bar:Hide()
      local hl = b:CreateTexture(nil, "HIGHLIGHT") hl:SetAllPoints() hl:SetColorTexture(1, 1, 1, 0.05)
      b.t = U.Text(b, 15, "body", C.text)
      b.t:SetPoint("LEFT", 18, 0) b.t:SetJustifyV("MIDDLE")
      b.t:SetText((P[k] and P[k].title) or (UST.pages[k] and UST.pages[k].title) or (k == "klawisze" and "Klawisze") or (k == "makra" and "Makra") or k)
      b:SetScript("OnClick", function() S.page = k S.q = "" S.search:SetText("") U.ustawieniaRefresh() end)
      S.rail[k] = b
      y = y - 31
    end
    y = y - 10
  end
  local more = U.Label(rail, "WIĘCEJ")
  more:SetPoint("TOPLEFT", 18, y)
  local full = U.Button(rail, "Pełne ustawienia gry", RAIL_W - 36, 28)
  full:SetPoint("TOPLEFT", 18, y - 24)
  full:SetScript("OnClick", openFull)
  local edit = U.Button(rail, "Tryb edycji interfejsu (HUD)", RAIL_W - 36, 28)
  edit:SetPoint("TOPLEFT", full, "BOTTOMLEFT", 0, -8)
  edit:SetScript("OnClick", function()
    if InCombatLockdown() then return end
    if U.Close then pcall(U.Close) end
    C_Timer.After(0.05, function() if EditModeManagerFrame then pcall(ShowUIPanel, EditModeManagerFrame) end end)
  end)
  -- prawo
  local body = U.Panel(page, 0.86, true)
  body:SetPoint("TOPLEFT", rail, "TOPRIGHT", 20, 0)
  body:SetPoint("BOTTOMRIGHT")
  S.body = body
  S.search = CreateFrame("EditBox", nil, body, "InputBoxTemplate")
  S.search:SetSize(380, 26)
  S.search:SetPoint("TOPRIGHT", -20, -14)
  S.search:SetAutoFocus(false)
  S.search:SetScript("OnTextChanged", function(self, user) if user then S.q = self:GetText() or "" U.ustawieniaRefresh() end end)
  S.search:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
  S.search:SetScript("OnEnterPressed", function(self) self:ClearFocus() end)
  local sl = U.Text(body, 11, "body", C.faint)
  sl:SetPoint("RIGHT", S.search, "LEFT", -12, 0)
  sl:SetText("szukaj we wszystkich ustawieniach, klawiszach i makrach")
  S.ptitle = U.Text(body, 22, "title", C.gold)
  S.ptitle:SetPoint("TOPLEFT", 22, -16)
  S.pnote = U.Text(body, 12, "body", C.faint)
  S.pnote:SetPoint("TOPLEFT", S.ptitle, "BOTTOMLEFT", 0, -6)
  local view = CreateFrame("ScrollFrame", nil, body)
  view:SetPoint("TOPLEFT", 16, -70) view:SetPoint("BOTTOMRIGHT", -16, 16)
  S.list = CreateFrame("Frame", nil, view)
  S.list:SetSize(800, 10)
  view:SetScrollChild(S.list)
  view:EnableMouseWheel(true)
  view:SetScript("OnMouseWheel", function(self, d)
    local max = math.max(0, S.list:GetHeight() - self:GetHeight())
    self:SetVerticalScroll(math.max(0, math.min(max, self:GetVerticalScroll() - d * 108)))
  end)
  view:SetScript("OnSizeChanged", function(self, w) S.list:SetWidth(w) end)
  S.view = view
  S.empty = U.Text(body, 13, "body", C.muted)
  S.empty:SetPoint("TOPLEFT", 22, -80)
  S.empty:SetText("Nic nie pasuje. Rzadkie opcje: „Pełne ustawienia gry” po lewej.")
  S.empty:Hide()
end

-- zmiany z walki po jej koncu
local ev = CreateFrame("Frame")
ev:RegisterEvent("PLAYER_REGEN_ENABLED")
ev:RegisterEvent("CVAR_UPDATE")
ev:SetScript("OnEvent", function(_, e)
  if e == "PLAYER_REGEN_ENABLED" then
    for k, v in pairs(S.pending) do setCVar(k, v) end
    wipe(S.pending)
  end
  if S.root and S.root:IsVisible() and not S.qd then
    S.qd = true
    C_Timer.After(0.2, function() S.qd = nil pcall(U.ustawieniaRefresh) end)
  end
end)

U.RegisterTab({
  id = "ustawienia", order = 8.5, title = "Ustawienia", keys = "",
  hints = { { { "LPM" }, "Zmień" }, { { "Esc" }, "Zamknij" } },
  note = "Ustawienia gry i Grimuara po polsku, klawisze i makra",
  build = build,
  refresh = function() C_Timer.After(0, function() pcall(U.ustawieniaRefresh) end) end,
  leave = function() if S.search then S.search:ClearFocus() end end,
})
