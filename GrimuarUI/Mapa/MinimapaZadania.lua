-- Grimuar UI: „!” na minimapie (14.11, gracz: „na minimapie w prawym gornym rogu tez chce szare i zolte”).
-- Te same znaczniki co na mapie huba: zloty „!” = zadanie z trasy Polestara, szary = spoza trasy.
-- Dane: MapaQuestie.lua U.availablePins (Questie AvailableQuests + Polestar). Rysuje HereBeDragons-Pins (biblioteka
-- GatherMate2 albo Questie). Nasze ikony leza nad zoltymi „!” Questie, wiec szary zakrywa zolty tam, gdzie trzeba.
-- Odswiezanie: zmiana strefy, dziennik zadan, poziom i co 10 s. Wylaczenie: /hub minimapa.
local ADDON, U = ...

local REF = "GrimuarUIAvail"
local pool, shown = {}, 0

local function hbdp()
  if not LibStub then return nil end
  return LibStub("HereBeDragons-Pins-2.0", true) or LibStub("HereBeDragonsQuestie-Pins-2.0", true)
end
local function enabled()
  local d = U.db()
  return d.minimapAvail ~= false
end

local function pin(i)
  local f = pool[i]
  if f then return f end
  f = CreateFrame("Button", nil, Minimap)
  f:SetSize(16, 16)
  -- zlota poswiata pod „!” z trasy Polestara (zolty „!” Questie wyglada tak samo, wiec sam kolor nie wystarczal)
  f.glow = f:CreateTexture(nil, "BACKGROUND")
  f.glow:SetTexture(((U.QUEST_AVAIL_ICON or ""):gsub("available%.blp$", "glow.blp")))
  f.glow:SetVertexColor(1, 0.82, 0.3, 0.95)
  f.glow:SetPoint("CENTER")
  f.glow:SetSize(30, 30)
  f.i = f:CreateTexture(nil, "OVERLAY")
  f.i:SetAllPoints()
  f:SetScript("OnEnter", function(self)
    local d = self.d
    if not d then return end
    GameTooltip:SetOwner(self, "ANCHOR_LEFT")
    GameTooltip:SetText("Do wzięcia u: " .. (d.name or "?"), 0.85, 0.71, 0.36)
    for _, q in ipairs(d.quests or {}) do
      local c = q.route and 1 or 0.6
      GameTooltip:AddLine((q.level and ("[" .. q.level .. "] ") or "") .. q.title .. (q.route and "  · trasa Polestara" or "  · poza trasą"), c, c, c)
    end
    GameTooltip:Show()
  end)
  f:SetScript("OnLeave", function() GameTooltip:Hide() end)
  pool[i] = f
  return f
end

local function update()
  local P = hbdp()
  if not P then return end
  pcall(P.RemoveAllMinimapIcons, P, REF)
  for i = 1, shown do pool[i]:Hide() end
  shown = 0
  if not enabled() or not U.availablePins then return end
  local map = U.call(C_Map.GetBestMapForUnit, "player")
  if not map then return end
  local n = 0
  for _, d in ipairs(U.availablePins(map) or {}) do
    if n >= 60 then break end
    n = n + 1
    local f = pin(n)
    f.d = d
    f.i:SetTexture(d.route and U.QUEST_AVAIL_ICON or U.QUEST_AVAIL_GRAY)
    f:SetSize(d.route and 16 or 17, d.route and 16 or 17)
    f.glow:SetShown(d.route == true)
    pcall(P.AddMinimapIconMap, P, REF, f, map, d.x, d.y, false, d.route == true)
    -- nad ikonami Questie (one maja staly poziom ramki ok. 2016+, QuestieMapUtils.lua)
    pcall(f.SetFixedFrameLevel, f, false)
    f:SetFrameLevel(2100 + (d.route and 1 or 0))
    pcall(f.SetFixedFrameLevel, f, true)
  end
  shown = n
end
U.minimapAvailUpdate = update

local queued = false
local function queue(delay)
  if queued then return end
  queued = true
  C_Timer.After(delay or 1.5, function()
    queued = false
    pcall(update)
  end)
end

local ev = CreateFrame("Frame")
for _, e in ipairs({ "PLAYER_LOGIN", "ZONE_CHANGED_NEW_AREA", "QUEST_LOG_UPDATE", "QUEST_TURNED_IN", "PLAYER_LEVEL_UP" }) do
  pcall(ev.RegisterEvent, ev, e)
end
ev:SetScript("OnEvent", function(_, event)
  if event == "PLAYER_LOGIN" then
    C_Timer.After(12, function() pcall(update) end)
    C_Timer.NewTicker(10, function() pcall(update) end)
  else
    queue(event == "QUEST_LOG_UPDATE" and 2 or 1)
  end
end)
