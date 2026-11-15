-- Grimuar: modul Panel (wspolne funkcje przez tabele G z innych modulow).
local ADDON_NAME, G = ...
local C_FROST = G.C_FROST
local C_GOLD = G.C_GOLD
local C_MUTED = G.C_MUTED
local C_OK = G.C_OK
local C_WARN = G.C_WARN
local DUNGEONS = G.DUNGEONS
local FONT = G.FONT
local GLOSSARY = G.GLOSSARY
local GUIDE = G.GUIDE
local QUESTS = G.QUESTS
local S = G.S
local SPELLS = G.SPELLS
local STAGES = G.STAGES
local TALENT_AT = G.TALENT_AT
local TALENT_NOTE_AT = G.TALENT_NOTE_AT
local W = 430 -- szerokosc tresci w nowym oknie z bocznym menu
local FlatButton, FitButton, StyledWindow, Divider = G.FlatButton, G.FitButton, G.StyledWindow, G.Divider
local STYLE, setBackdrop = G.STYLE, G.setBackdrop
local bookDone = G.bookDone
local buildSteps = G.buildSteps
local charKey = G.charKey
local clearGuide = G.clearGuide
local enableGatherTracking = G.enableGatherTracking
local guideTo = G.guideTo
local openTalents = G.openTalents
local say = G.say
local setBudget = G.setBudget
local showToast = G.showToast
local skipped = G.skipped
local tempoLine = G.tempoLine
local updateHUD = G.updateHUD

-- Czesc wydzielona z Panel.lua (podzial plikow >1000 linii, 12.11).
local renderPanel = G.renderPanel
local togglePanel = G.togglePanel

-- ---------- przycisk przy minimapie ----------
local function createMinimapButton()
  if not Minimap or _G.GrimuarMinimapButton then return end
  local b = CreateFrame("Button", "GrimuarMinimapButton", Minimap)
  b:SetSize(31, 31)
  b:SetFrameStrata("MEDIUM")
  b:SetFrameLevel(8)
  b:RegisterForClicks("AnyUp")
  b:RegisterForDrag("LeftButton")
  local bg = b:CreateTexture(nil, "BACKGROUND")
  bg:SetTexture("Interface\\Minimap\\UI-Minimap-Background")
  bg:SetSize(20, 20)
  bg:SetPoint("TOPLEFT", b, "TOPLEFT", 7, -5)
  local icon = b:CreateTexture(nil, "ARTWORK")
  icon:SetTexture("Interface\\Icons\\Spell_Frost_FrostBolt02")
  icon:SetSize(17, 17)
  icon:SetPoint("TOPLEFT", b, "TOPLEFT", 7, -6)
  local border = b:CreateTexture(nil, "OVERLAY")
  border:SetTexture("Interface\\Minimap\\MiniMap-TrackingBorder")
  border:SetSize(53, 53)
  border:SetPoint("TOPLEFT", b, "TOPLEFT", 0, 0)
  pcall(function() b:SetHighlightTexture("Interface\\Minimap\\UI-Minimap-ZoomButton-Highlight") end)
  if GrimuarSetupDB.mmAngleV ~= 2 then
    GrimuarSetupDB.mmAngle = 135
    GrimuarSetupDB.mmAngleV = 2
  end
  local function place()
    local a = math.rad(GrimuarSetupDB.mmAngle or 135)
    local r = (Minimap:GetWidth() / 2) + 6
    b:ClearAllPoints()
    b:SetPoint("CENTER", Minimap, "CENTER", math.cos(a) * r, math.sin(a) * r)
  end
  b:SetScript("OnDragStart", function(self)
    self:SetScript("OnUpdate", function()
      local mx, my = Minimap:GetCenter()
      local cx, cy = GetCursorPosition()
      local s = Minimap:GetEffectiveScale()
      GrimuarSetupDB.mmAngle = math.deg(math.atan2(cy / s - my, cx / s - mx))
      place()
    end)
  end)
  b:SetScript("OnDragStop", function(self) self:SetScript("OnUpdate", nil) end)
  b:SetScript("OnClick", function() togglePanel() end)
  b:SetScript("OnEnter", function(self)
    GameTooltip:SetOwner(self, "ANCHOR_LEFT")
    GameTooltip:AddLine("Grimuar maga")
    GameTooltip:AddLine("Kliknij albo Shift+G: okno z planem", 1, 1, 1)
    GameTooltip:AddLine("Przeciągnij: przesuń przycisk", 0.7, 0.7, 0.7)
    GameTooltip:Show()
  end)
  b:SetScript("OnLeave", function() GameTooltip:Hide() end)
  place()
end

-- ---------- komunikat przy awansie ----------
local function announceLevel(l)
  local parts = {}
  if TALENT_AT[l] then table.insert(parts, "talent: " .. TALENT_AT[l] .. " (N)") end
  local sp = {}
  for _, s in ipairs(SPELLS) do
    if s[1] == l and s[3] ~= "pomiń przy levelowaniu" then table.insert(sp, s[2]) end
  end
  if #sp > 0 then table.insert(parts, "u trenera: " .. table.concat(sp, ", ")) end
  for _, st in ipairs(STAGES) do
    if st.from == l then table.insert(parts, "nowy etap: " .. st.title .. " (" .. st.zones .. ")") end
  end
  for _, d in ipairs(DUNGEONS) do
    if d[1] == l then table.insert(parts, "nowy dungeon: " .. d[3]) end
  end
  if #parts > 0 then
    say(C_FROST .. "Poziom " .. l .. "!|r " .. table.concat(parts, "; ") .. ".")
  else
    say(C_FROST .. "Poziom " .. l .. "!|r Szczegóły pod Shift+G.")
  end
  if G.getPanel() and G.getPanel():IsShown() then renderPanel() end
end

-- eksport do pozostalych modulow
G.createMinimapButton = createMinimapButton
G.announceLevel = announceLevel
