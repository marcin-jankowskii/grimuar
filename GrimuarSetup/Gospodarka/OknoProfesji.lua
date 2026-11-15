-- Grimuar: modul OknoProfesji (gracz 13.11: „gdzie takie okienko co mam robic z profesjami? najlepiej pod combo frosta”).
-- Stale okienko w stylu sciagi Combo Frosta (Runy.lua), przyczepione pod nia; bez sciagi stoi w tym samym miejscu po lewej.
-- Na profesje: ikona, poziom i jedna wskazowka (Profesje.lua panelRows: kraft z okna profesji, zbieranie, trener).
-- Chowa sie w walce i w rajdzie (15.11: ramki druzyny stoja juz na dole, wiec w druzynie zostaje). Klik otwiera
-- Postac > Moje profesje. Shift + przeciagnij przesuwa. 15.11 gracz: „status profesji tez zniknal” (/profesje
-- przelaczalo okienko jak wlacznik): /profesje otwiera Moje profesje i pokazuje okienko, /profesje ukryj chowa.
local ADDON_NAME, G = ...
local say = G.say

local GOLD = { 0.85, 0.71, 0.36 }
local MUTED = { 0.62, 0.64, 0.7 }
local W = 330
local ICON = { herbalism = "Find Herbs", mining = "Find Minerals", firstaid = "First Aid", cooking = "Cooking",
  fishing = "Fishing", tailoring = "Tailoring" }

local panel
local rows = {}

local function spellIcon(name)
  local icon
  pcall(function()
    if C_Spell and C_Spell.GetSpellTexture then icon = C_Spell.GetSpellTexture(name)
    elseif GetSpellTexture then icon = GetSpellTexture(name) end
  end)
  return icon
end

local function place()
  panel:ClearAllPoints()
  local p = GrimuarSetupDB.profPanelPos
  if type(p) == "table" and p[1] then
    panel:SetPoint(p[1], UIParent, p[1], p[2] or 0, p[3] or 0)
    return
  end
  local combo = _G.GrimuarRunyCombo
  if combo and combo:IsShown() then
    panel:SetPoint("TOPLEFT", combo, "BOTTOMLEFT", 0, -6)
  else
    panel:SetPoint("TOPLEFT", UIParent, "LEFT", 16, 100)
  end
end

local function row(i)
  local r = rows[i]
  if r then return r end
  r = CreateFrame("Frame", nil, panel)
  r:SetWidth(W - 16)
  r.icon = r:CreateTexture(nil, "ARTWORK")
  r.icon:SetSize(20, 20)
  r.icon:SetPoint("TOPLEFT", r, "TOPLEFT", 0, -1)
  r.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
  r.name = r:CreateFontString(nil, "OVERLAY")
  r.name:SetFont(G.BF(), 12, "")
  r.name:SetPoint("TOPLEFT", r.icon, "TOPRIGHT", 6, 1)
  r.name:SetTextColor(0.95, 0.93, 0.88)
  r.hint = r:CreateFontString(nil, "OVERLAY")
  r.hint:SetFont(G.BF(), 11, "")
  r.hint:SetPoint("TOPLEFT", r.name, "BOTTOMLEFT", 0, -1)
  r.hint:SetWidth(W - 44)
  r.hint:SetJustifyH("LEFT")
  pcall(function() r.hint:SetWordWrap(true) end)
  r.hint:SetTextColor(unpack(MUTED))
  rows[i] = r
  return r
end

local function hidden()
  return GrimuarSetupDB.profPanelOff or InCombatLockdown() or (IsInRaid and IsInRaid())
end

local function refresh()
  if not panel then return end
  if hidden() then panel:Hide() return end
  local ok, list = pcall(G.profPanelRows)
  if not ok or type(list) ~= "table" or #list == 0 then panel:Hide() return end
  for _, r in ipairs(rows) do r:Hide() end
  local y = -34
  for i, it in ipairs(list) do
    local r = row(i)
    local ic = spellIcon(ICON[it.key] or it.name)
    if ic then r.icon:SetTexture(ic) r.icon:Show() else r.icon:Hide() end
    r.name:SetText(it.name .. "  |cffd8b25a" .. (it.rank or "?") .. "/" .. (it.max or "?") .. "|r")
    r.hint:SetText(it.hint or "")
    local h = math.max(22, 16 + (r.hint:GetStringHeight() or 12))
    r:SetHeight(h)
    r:ClearAllPoints()
    r:SetPoint("TOPLEFT", panel, "TOPLEFT", 10, y)
    r:Show()
    y = y - h - 4
  end
  panel:SetHeight(-y + 6)
  place()
  panel:Show()
end

local function make()
  if panel then return end
  panel = CreateFrame("Frame", "GrimuarProfPanel", UIParent, "BackdropTemplate")
  panel:SetSize(W, 120)
  panel:SetFrameStrata("LOW")
  if G.setBackdrop then G.setBackdrop(panel, { 0.04, 0.045, 0.065, 0.82 }, { 0.42, 0.35, 0.18, 0.9 }) end
  panel.title = panel:CreateFontString(nil, "OVERLAY")
  panel.title:SetFont(G.TF(), 16, "")
  panel.title:SetTextColor(unpack(GOLD))
  panel.title:SetPoint("TOPLEFT", panel, "TOPLEFT", 12, -10)
  panel.title:SetText("Profesje")
  panel.sub = panel:CreateFontString(nil, "OVERLAY")
  panel.sub:SetFont(G.BF(), 10, "")
  panel.sub:SetTextColor(unpack(MUTED))
  panel.sub:SetPoint("LEFT", panel.title, "RIGHT", 8, -1)
  panel.sub:SetText("klik: więcej, K: okno profesji")
  if G.addRuneCorners then pcall(G.addRuneCorners, panel, 18) end
  panel:SetMovable(true)
  panel:EnableMouse(true)
  panel:RegisterForDrag("LeftButton")
  panel:SetScript("OnDragStart", function(self) if IsShiftKeyDown() then self.moving = true self:StartMoving() end end)
  panel:SetScript("OnDragStop", function(self)
    if not self.moving then return end
    self.moving = false
    self:StopMovingOrSizing()
    local point, _, _, x, y = self:GetPoint()
    GrimuarSetupDB.profPanelPos = { point, x, y }
  end)
  panel:SetScript("OnMouseUp", function(self, button)
    if self.moving or button ~= "LeftButton" or IsShiftKeyDown() then return end
    pcall(function()
      if not (G.getPanel and G.getPanel() and G.getPanel():IsShown()) then SlashCmdList.GRIMUAR("") end
      G.selectTab("mojeprof")
    end)
  end)
  panel:Hide()
end

local ev = CreateFrame("Frame")
ev:RegisterEvent("PLAYER_LOGIN")
local queued = false
local function soon()
  if queued then return end
  queued = true
  C_Timer.After(1, function() queued = false pcall(refresh) end)
end
ev:SetScript("OnEvent", function(_, event)
  if event == "PLAYER_LOGIN" then
    for _, e in ipairs({ "PLAYER_REGEN_DISABLED", "PLAYER_REGEN_ENABLED", "GROUP_ROSTER_UPDATE", "SKILL_LINES_CHANGED",
      "CHAT_MSG_SKILL", "BAG_UPDATE_DELAYED", "PLAYER_LEVEL_UP" }) do pcall(ev.RegisterEvent, ev, e) end
    -- 15.11: okienko wylaczone dawnym przelacznikiem /profesje wraca raz
    if not GrimuarSetupDB.profPanelReset1511 then GrimuarSetupDB.profPanelReset1511 = true GrimuarSetupDB.profPanelOff = nil end
    C_Timer.After(9, function() pcall(make) pcall(refresh) end)
  elseif event == "PLAYER_REGEN_DISABLED" then
    if panel then panel:Hide() end
  else
    soon()
  end
end)

SLASH_GRIMUARPROFESJE1 = "/profesje"
SlashCmdList["GRIMUARPROFESJE"] = function(msg)
  msg = (msg or ""):lower():gsub("^%s+", ""):gsub("%s+$", "")
  if msg == "ukryj" or msg == "schowaj" or msg == "hide" then
    GrimuarSetupDB.profPanelOff = true
    if panel then panel:Hide() end
    say("okienko Profesje schowane. /profesje pokaże je znowu.")
    return
  end
  GrimuarSetupDB.profPanelOff = nil
  pcall(make)
  pcall(refresh)
  pcall(function()
    if not (G.getPanel and G.getPanel() and G.getPanel():IsShown()) then SlashCmdList.GRIMUAR("") end
    G.selectTab("mojeprof")
  end)
end

G.profPanelRefresh = refresh
