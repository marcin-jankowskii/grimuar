-- Grimuar: modul Engine (wspolne funkcje przez tabele G z innych modulow).
local ADDON_NAME, G = ...
local C_FROST = G.C_FROST
local C_GOLD = G.C_GOLD
local C_MUTED = G.C_MUTED
local C_OK = G.C_OK
local DUNGEONS = G.DUNGEONS
local FONT = G.FONT
local STAGES = G.STAGES
local TALENT_AT = G.TALENT_AT
local charKey = G.charKey
local knownSpellId = G.knownSpellId
local say = G.say

-- Czesc wydzielona z Engine.lua (podzial plikow >1000 linii, 12.11).
local S = G.S
local budgetTick = G.budgetTick
local buildSteps = G.buildSteps
local fmtK = G.fmtK
local fmtMoney = G.fmtMoney
local hearthInfo = G.hearthInfo
local restedPercent = G.restedPercent
local runReminders = G.runReminders
local saveCurrent = G.saveCurrent
local showToast = G.showToast
local skipped = G.skipped
local tempoLine = G.tempoLine
local wayTo = G.wayTo
local xpPerHour = G.xpPerHour

-- ---------- pasek tempa (HUD) ----------
local hud

-- ---------- Grimuar pod oknem Polestar: kroki spoza questow w jednym miejscu ----------
local dock
local DOCK_SKIP = { polestar = true, quest = true }

local function getTabFont()
  local f = _G.GrimuarTabFont
  if not f then
    f = CreateFont("GrimuarTabFont")
    f:SetFont(FONT, 12, "")
    f:SetTextColor(1, 0.82, 0)
  end
  return f
end

-- Kategorie krokow (drabina UX 12.11): Teraz > Sesja > Postać > Etap > Porządki
local STEP_CATS = {
  { "^dead", "Teraz", "|cffe07a6a" }, { "^klatwa", "Teraz", "|cffe07a6a" }, { "^fight", "Teraz", "|cffe07a6a" }, { "^rest$", "Teraz", "|cffe07a6a" },
  { "^plan", "Sesja", "|cff74d0ee" }, { "^ending", "Sesja", "|cff74d0ee" }, { "^budget", "Sesja", "|cff74d0ee" },
  { "^setup", "Porządki", "|cff9aa4b1" },
  { "^book", "Etap", "|cffd8b25a" }, { "^todo", "Etap", "|cffd8b25a" }, { "^dng", "Etap", "|cffd8b25a" },
  { "^pickup", "Etap", "|cffd8b25a" }, { "^turnin", "Etap", "|cffd8b25a" }, { "^polestar", "Etap", "|cffd8b25a" }, { "^quest", "Etap", "|cffd8b25a" },
}
local function stepCategory(key)
  key = key or ""
  for _, c in ipairs(STEP_CATS) do
    if key:find(c[1]) then return c[2], c[3] end
  end
  return "Postać", "|cff7cc68b"
end

local function createDock()
  if dock then return end
  dock = CreateFrame("Frame", "GrimuarDock", UIParent, "BackdropTemplate")
  dock:SetSize(420, 60)
  dock:SetFrameStrata("MEDIUM")
  dock:SetClampedToScreen(true)
  pcall(function()
    dock:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8X8", edgeFile = "Interface\\Buttons\\WHITE8X8", edgeSize = 1 })
    dock:SetBackdropColor(0.05, 0.06, 0.10, 0.92)
    dock:SetBackdropBorderColor(0.85, 0.71, 0.36, 0.6) -- zloto jak runy (UX 12.11)
  end)
  dock.label = dock:CreateFontString(nil, "OVERLAY")
  dock.label:SetFont(G.TF(), 13, "")
  dock.label:SetPoint("TOPLEFT", dock, "TOPLEFT", 14, -6)
  -- wyglad 13.11: kolorowa belka kategorii z lewej i ikona kroku
  dock.stripe = dock:CreateTexture(nil, "ARTWORK")
  dock.stripe:SetTexture("Interface\\Buttons\\WHITE8X8")
  dock.stripe:SetWidth(4)
  dock.stripe:SetPoint("TOPLEFT", dock, "TOPLEFT", 1, -1)
  dock.stripe:SetPoint("BOTTOMLEFT", dock, "BOTTOMLEFT", 1, 1)
  dock.icon = dock:CreateTexture(nil, "ARTWORK")
  dock.icon:SetSize(32, 32)
  dock.icon:SetPoint("TOPLEFT", dock, "TOPLEFT", 12, -26)
  dock.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
  dock.label:SetText(C_FROST .. "Grimuar|r" .. C_MUTED .. "   poza questami|r")
  dock.more = G.FlatButton(dock, 64, 18, "Więcej")
  dock.more:SetPoint("TOPRIGHT", dock, "TOPRIGHT", -6, -4)
  dock.more:SetScript("OnClick", function() SlashCmdList["GRIMUAR"]("") end)
  dock.text = dock:CreateFontString(nil, "OVERLAY")
  dock.text:SetFont(FONT, 14, "")
  dock.text:SetJustifyH("LEFT")
  dock.text:SetJustifyV("TOP")
  dock.text:SetTextColor(0.93, 0.91, 0.86)
  dock.text:SetPoint("TOPLEFT", dock, "TOPLEFT", 52, -26)
  dock.why = dock:CreateFontString(nil, "OVERLAY")
  dock.why:SetFont(FONT, 12, "")
  dock.why:SetJustifyH("LEFT")
  dock.why:SetJustifyV("TOP")
  dock.why:SetTextColor(0.6, 0.63, 0.69)
  dock.btns = {}
  dock.glow = CreateFrame("Frame", nil, dock, "BackdropTemplate")
  dock.glow:SetPoint("TOPLEFT", dock, "TOPLEFT", -3, 3)
  dock.glow:SetPoint("BOTTOMRIGHT", dock, "BOTTOMRIGHT", 3, -3)
  pcall(function()
    dock.glow:SetBackdrop({ edgeFile = "Interface\\Buttons\\WHITE8X8", edgeSize = 3 })
    dock.glow:SetBackdropBorderColor(0.85, 0.71, 0.36, 1)
  end)
  local ag = dock.glow:CreateAnimationGroup()
  local an = ag:CreateAnimation("Alpha")
  an:SetFromAlpha(1)
  an:SetToAlpha(0.15)
  an:SetDuration(0.45)
  ag:SetLooping("BOUNCE")
  dock.glowAnim = ag
  dock.glow:Hide()
  dock:Hide()
  local pf = _G.PolestarGuideFrame
  if pf and pf.HookScript then
    pf:HookScript("OnShow", function() if G.refreshAll then G.refreshAll() end end)
    pf:HookScript("OnHide", function() if G.refreshAll then G.refreshAll() end end)
  end
end

-- Pokazuje pierwszy krok spoza questow. Zwraca true, gdy pasek jest widoczny.
local function updateDock(steps)
  if not dock then return false end
  if GrimuarSetupDB.noDock then dock:Hide() return false end
  local cands = {}
  for _, st in ipairs(steps or {}) do
    if not DOCK_SKIP[st.key] then table.insert(cands, st) end
  end
  local s, pos = cands[1], 1
  if not cands[1] or dock.firstKey ~= cands[1].key then dock.view = nil end
  dock.firstKey = cands[1] and cands[1].key
  if dock.view and s and s.key ~= "fight" and s.key ~= "dead" then
    for i, st in ipairs(cands) do
      if st.key == dock.view then s, pos = st, i end
    end
    if pos == 1 then dock.view = nil end
  end
  if not s then
    dock.lastKey = nil
    dock:Hide()
    return false
  end
  if pos == 1 and s.key ~= dock.lastKey and s.key ~= "fight" and s.key ~= "dead" then
    dock.glow:Show()
    dock.glowAnim:Play()
    C_Timer.After(3, function()
      if dock.glowAnim then
        dock.glowAnim:Stop()
        dock.glow:Hide()
      end
    end)
    if dock.lastKey ~= nil then pcall(function() PlaySound(SOUNDKIT.MAP_PING) end) end
  end
  if pos == 1 then dock.lastKey = s.key end
  -- jeden licznik: wlasny licznik kroku (plan, ustawienia, lochy) albo pozycja na pasku
  local cat, col = stepCategory(s.key)
  local cnt = s.count or ((#cands > 1) and (pos .. " z " .. #cands) or nil)
  dock.label:SetText(C_GOLD .. "Grimuar|r   " .. col .. cat .. (cnt and (" · " .. cnt) or "") .. "|r")
  pcall(function()
    local r, g, b = col:match("|cff(%x%x)(%x%x)(%x%x)")
    dock.stripe:SetVertexColor(tonumber(r, 16) / 255, tonumber(g, 16) / 255, tonumber(b, 16) / 255, 1)
    dock.icon:SetTexture(G.iconFor and G.iconFor(s.key) or "Interface\\Icons\\INV_Misc_Book_09")
  end)
  local pf = _G.PolestarGuideFrame
  local width = 420
  dock:ClearAllPoints()
  if pf and pf:IsShown() then
    dock:SetPoint("TOPLEFT", pf, "BOTTOMLEFT", 0, -4)
    dock:SetPoint("TOPRIGHT", pf, "BOTTOMRIGHT", 0, -4)
    width = pf:GetWidth() or 420
  elseif hud then
    dock:SetPoint("TOP", hud, "BOTTOM", 0, -4)
    dock:SetWidth(width)
  else
    dock:SetPoint("TOP", UIParent, "TOP", 0, -50)
    dock:SetWidth(width)
  end
  local inner = math.max(160, width - 62)
  dock.text:SetWidth(inner)
  dock.why:SetWidth(inner)
  dock.text:SetText(C_OK .. "» |r" .. s.text)
  local h = 26 + dock.text:GetStringHeight()
  if s.why and s.why ~= "" then
    dock.why:ClearAllPoints()
    dock.why:SetPoint("TOPLEFT", dock.text, "BOTTOMLEFT", 0, -3)
    dock.why:SetText(s.why)
    dock.why:Show()
    h = h + 3 + dock.why:GetStringHeight()
  else
    dock.why:Hide()
  end
  local list = {}
  for _, b in ipairs(s.btns or {}) do table.insert(list, b) end
  if G.withGuide then pcall(G.withGuide, list, s.text) end -- Prowadz przy kazdym kroku z questem (13.11)
  if s.key ~= "fight" and s.key ~= "dead" then
    table.insert(list, { "Pomiń", function() skipped[s.key] = true; if G.refreshAll then G.refreshAll() end end })
  end
  if #cands > 1 and s.key ~= "fight" and s.key ~= "dead" then
    local nextSt = cands[pos + 1]
    table.insert(list, { "Dalej ›", function()
      dock.view = nextSt and nextSt.key or nil
      if G.refreshAll then G.refreshAll() end
    end })
  end
  if pos > 1 then
    table.insert(list, { "‹ Wróć", function()
      dock.view = nil
      if G.refreshAll then G.refreshAll() end
    end })
  end
  if S.undo then
    table.insert(list, { "Cofnij", function()
      local u = S.undo
      S.undo = nil
      if u then
        u[2]()
        say("cofnięte: " .. u[1] .. ".")
      end
      if G.refreshAll then G.refreshAll() end
    end })
  end
  for _, b in ipairs(dock.btns) do b:Hide() end
  local x = 52
  for i, spec in ipairs(list) do
    local b = dock.btns[i]
    if not b then
      b = G.FlatButton(dock, 58, 20, "")
      b:SetScript("OnClick", function(self) if self.fn then self.fn() end end)
      dock.btns[i] = b
    end
    b.fn = spec[2]
    b.primary = (i == 1)
    b:SetText(spec[1])
    G.FitButton(b, 58)
    b:Repaint()
    local w = b:GetWidth()
    if x > 52 and x + w > width - 10 then
      x = 52
      h = h + 26
    end
    b:ClearAllPoints()
    b:SetPoint("TOPLEFT", dock, "TOPLEFT", x, -h - 6)
    b:Show()
    x = x + w + 6
  end
  if #list > 0 then h = h + 28 end
  dock:SetHeight(math.max(h + 10, 66))
  dock:Show()
  return true
end

local function autoGuide(steps)
  if GrimuarSetupDB.noAutoGuide or InCombatLockdown() then return end
  local want
  for _, st in ipairs(steps) do
    if st.loc and st.loc[1] then
      want = st
      break
    end
  end
  if want then
    if S.autoTarget ~= want.key then
      S.autoTarget = want.key
      wayTo(want.loc[1], want.loc[2], want.loc[3], want.loc[4])
      if not GrimuarSetupDB.noToast then
        pcall(showToast, "strzałka prowadzi teraz do: " .. want.loc[4] .. ". Potem sama wróci do questów.", want.key, false)
      end
    end
  elseif S.autoTarget then
    S.autoTarget = nil
    pcall(G.releaseArrow)
    if not GrimuarSetupDB.noToast then pcall(showToast, "gotowe. Strzałka wraca do questów Polestar.", "turnin", false) end
  end
end

local function updateHUD()
  if not hud then return end
  local ok, line = pcall(tempoLine)
  hud.text:SetText(C_FROST .. "Grimuar|r   " .. (ok and line or ""))
  local w = hud.text:GetStringWidth()
  local okS, steps = pcall(buildSteps)
  if not okS or type(steps) ~= "table" then steps = {} end
  pcall(autoGuide, steps)
  local okD, docked = pcall(updateDock, steps)
  docked = okD and docked
  local s1 = steps[1]
  if GrimuarSetupDB.hideStep or docked or not s1 or DOCK_SKIP[s1.key] then
    hud.step:Hide()
    hud:SetHeight(20)
  else
    hud.step:SetText(C_GOLD .. "» " .. s1.text .. "|r")
    hud.step:Show()
    hud:SetHeight(38)
    w = math.max(w, math.min(560, hud.step:GetStringWidth()))
  end
  hud:SetWidth(math.max(160, w + 24))
end

local function createHUD()
  if hud then return end
  hud = CreateFrame("Button", "GrimuarHUD", UIParent, "BackdropTemplate")
  hud:SetSize(320, 20)
  pcall(function()
    hud:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8X8", edgeFile = "Interface\\Buttons\\WHITE8X8", edgeSize = 1 })
    hud:SetBackdropColor(0.03, 0.04, 0.07, 0.75)
    hud:SetBackdropBorderColor(0.37, 0.8, 0.94, 0.5)
  end)
  local pos = GrimuarSetupDB.hudPos
  if pos then hud:SetPoint(pos[1], UIParent, pos[2], pos[3], pos[4]) else hud:SetPoint("TOP", UIParent, "TOP", 0, -6) end
  hud:SetMovable(true)
  hud:EnableMouse(true)
  hud:SetClampedToScreen(true)
  hud:RegisterForDrag("LeftButton")
  hud:RegisterForClicks("AnyUp")
  hud:SetScript("OnDragStart", function(self) self:StartMoving() end)
  hud:SetScript("OnDragStop", function(self)
    self:StopMovingOrSizing()
    local p, _, rp, x, y = self:GetPoint()
    GrimuarSetupDB.hudPos = { p, rp, x, y }
  end)
  hud.text = hud:CreateFontString(nil, "OVERLAY")
  hud.text:SetFont(FONT, 12, "")
  hud.text:SetPoint("TOP", hud, "TOP", 0, -4)
  hud.step = hud:CreateFontString(nil, "OVERLAY")
  hud.step:SetFont(FONT, 13, "")
  hud.step:SetPoint("BOTTOM", hud, "BOTTOM", 0, 4)
  hud.step:SetWidth(560)
  hud.step:SetWordWrap(false)
  hud:SetScript("OnClick", function() SlashCmdList["GRIMUAR"]("") end)
  hud:SetScript("OnEnter", function(self)
    GameTooltip:SetOwner(self, "ANCHOR_BOTTOM")
    GameTooltip:AddLine("Grimuar: tempo i sesja")
    GameTooltip:AddLine("XP w tej sesji: " .. fmtK(S.xpGained), 1, 1, 1)
    local xph = xpPerHour()
    if xph then GameTooltip:AddLine("XP na godzinę: " .. fmtK(xph), 1, 1, 1) end
    GameTooltip:AddLine("Rested: " .. restedPercent() .. "% poziomu", 1, 1, 1)
    GameTooltip:AddLine("Złoto w tej sesji: " .. fmtMoney(GetMoney() - (S.money0 or GetMoney())), 1, 1, 1)
    GameTooltip:AddLine(hearthInfo(), 1, 1, 1)
    GameTooltip:AddLine("Klik: okno Grimuara. Przeciągnij: przesuń. /grimuar sesja 60 włącza minutnik.", 0.7, 0.7, 0.7, true)
    GameTooltip:Show()
  end)
  hud:SetScript("OnLeave", function() GameTooltip:Hide() end)
  updateHUD()
end

local tickN = 0
local function tick()
  tickN = tickN + 1
  pcall(updateHUD)
  pcall(budgetTick)
  if tickN % 6 == 0 then pcall(runReminders, "periodic") end
  if tickN % 2 == 0 and G.refreshAll then pcall(G.refreshAll) end
  if tickN % 12 == 0 and not InCombatLockdown() then pcall(saveCurrent) end
end

-- eksport do pozostalych modulow
G.hud = hud
G.dock = dock
G.DOCK_SKIP = DOCK_SKIP
G.getTabFont = getTabFont
G.stepCategory = stepCategory
G.createDock = createDock
G.updateDock = updateDock
G.autoGuide = autoGuide
G.updateHUD = updateHUD
G.createHUD = createHUD
G.tickN = tickN
G.tick = tick
