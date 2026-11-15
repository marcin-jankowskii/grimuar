-- Grimuar: modul Uklad. Damage Done i okno Threat w lewym gornym rogu (decyzja gracza 11.11),
-- zeby pod oknem Polestar zostalo cale miejsce na pasek Grimuara.
local ADDON_NAME, G = ...
local say = G.say

local PAD = 16

local function damageMeterFrame()
  local mgr = _G.EditModeManagerFrame
  local ES = Enum and Enum.EditModeSystem
  if not (mgr and ES and ES.DamageMeter and type(mgr.registeredSystemFrames) == "table") then return nil end
  for _, f in ipairs(mgr.registeredSystemFrames) do
    if f.system == ES.DamageMeter then return f end
  end
  return nil
end

-- Pozycja dla ukladu Edit Mode (lewy gorny rog).
local function meterAnchorInfo()
  return { point = "TOPLEFT", relativeTo = "UIParent", relativePoint = "TOPLEFT", offsetX = PAD, offsetY = -PAD }
end

-- Threat pod Damage Done; wysokosc licznika z gry, a gdy jej brak, 12% ekranu.
local function threatPosition()
  local dm = damageMeterFrame()
  local mh = dm and dm.GetHeight and dm:GetHeight() or 0
  if not mh or mh < 20 then mh = 0.12 * UIParent:GetHeight() end
  return { "TOPLEFT", "UIParent", "TOPLEFT", PAD, -math.floor(PAD + mh + 8) }
end

local function moveThreat()
  local tdb = ThreatClassic2DB
  if type(tdb) ~= "table" or type(tdb.profiles) ~= "table" then return false end
  local key = "Default"
  if type(tdb.profileKeys) == "table" then
    for _, v in pairs(tdb.profileKeys) do key = v break end
  end
  local prof = tdb.profiles[key]
  if type(prof) ~= "table" then return false end
  prof.frame = prof.frame or {}
  prof.frame.position = threatPosition()
  local f = _G.ThreatClassic2BarFrame
  if f then
    pcall(function()
      f:ClearAllPoints()
      f:SetPoint(unpack(prof.frame.position))
    end)
  end
  return true
end

-- Zapis w aktywnym wlasnym ukladzie Edit Mode, zeby zostalo po /reload.
local function saveMeterInLayout()
  local ES = Enum and Enum.EditModeSystem
  assert(C_EditMode and C_EditMode.GetLayouts and C_EditMode.SaveLayouts and ES and ES.DamageMeter, "brak Edit Mode")
  local info = C_EditMode.GetLayouts()
  local nPre = 0
  if EditModePresetLayoutManager and EditModePresetLayoutManager.GetCopyOfPresetLayouts then
    nPre = #(EditModePresetLayoutManager:GetCopyOfPresetLayouts() or {})
  end
  local active = info and info.activeLayout
  assert(active and active > nPre, "aktywny jest układ wbudowany")
  local lay = info.layouts[active - nPre]
  assert(lay and type(lay.systems) == "table", "brak układu")
  local found = false
  for _, sys in ipairs(lay.systems) do
    if sys.system == ES.DamageMeter then
      sys.anchorInfo = meterAnchorInfo()
      sys.anchorInfo2 = nil
      sys.isInDefaultPosition = false
      found = true
    end
  end
  assert(found, "brak Damage Done w układzie")
  C_EditMode.SaveLayouts(info)
  return true
end

local function metersTopLeft(silent)
  if InCombatLockdown() then return false end
  local dm = damageMeterFrame()
  if dm then
    pcall(function()
      dm:ClearAllPoints()
      dm:SetPoint("TOPLEFT", UIParent, "TOPLEFT", PAD, -PAD)
    end)
  end
  local okL, err = pcall(saveMeterInLayout)
  local okT = moveThreat()
  if not silent then
    if okL then
      say("Damage Done" .. (okT and " i Threat" or "") .. " przeniesione do lewego górnego rogu. Pod Polestarem zostaje miejsce na pasek Grimuara.")
    else
      say("Damage Done przesunięty do lewego górnego rogu tylko do /reload (" .. tostring(err) .. "). Na stałe: Esc > Edit Mode, przeciągnij Damage Done w lewy górny róg, Save.")
    end
  end
  return okL
end

local ev = CreateFrame("Frame")
ev:RegisterEvent("PLAYER_LOGIN")
ev:SetScript("OnEvent", function()
  local function try()
    if GrimuarSetupDB.metersV == 1 then return end
    if InCombatLockdown() then C_Timer.After(15, try) return end
    if metersTopLeft(false) then GrimuarSetupDB.metersV = 1 end
  end
  C_Timer.After(6.5, try)
end)

G.damageMeterFrame = damageMeterFrame
G.meterAnchorInfo = meterAnchorInfo
G.threatPosition = threatPosition
G.metersTopLeft = metersTopLeft
