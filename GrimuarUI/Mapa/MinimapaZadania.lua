-- Grimuar UI: „!” na minimapie (14.11, gracz: „na minimapie w prawym gornym rogu tez chce szare i zolte”).
-- Te same znaczniki co na mapie huba: zloty „!” = zadanie z trasy Polestara, szary = spoza trasy.
-- Dane: MapaQuestie.lua U.availablePins (Questie AvailableQuests + Polestar). Rysuje HereBeDragons-Pins (biblioteka
-- GatherMate2 albo Questie). Nasze ikony leza nad zoltymi „!” Questie, wiec szary zakrywa zolty tam, gdzie trzeba.
-- Odswiezanie: zmiana strefy, dziennik zadan, poziom i co 10 s. Wylaczenie: /hub minimapa.
-- 15.11 (makieta „Znaczniki Grimuara” M4): „!” to medaliony z Hub\Znaczniki.lua (zloty: trasa Polestara, szary: spoza
-- niej) zamiast ikon Questie z poswiata.
-- 15.11 (gracz chce tam nasze ikony ziolo i ruda): ziola i ruda na minimapie jako znaczniki Grimuara
-- (M6) zamiast kolek GatherMate2. Wezly z U.gatherNodes (MapaLegenda.lua, baza GatherMate2), te same rodzaje i filtr,
-- ktore pokazuje GatherMate2 (jego Visible i profile.filter, tylko odczyt), najblizsze w zasiegu minimapy. Rysujemy je
-- tylko, gdy w GatherMate2 wylaczone sa jego ikony na minimapie („Show Minimap Icons”, profile.showMinimap): ustawien
-- GatherMate2 nie zmieniamy, a tak nie ma dwoch kompletow ikon naraz. /hub minimapa zbieranie: nasze wl./wyl.
local ADDON, U = ...

local REF = "GrimuarUIAvail"
local GREF = "GrimuarUIZbieranie"
local pool, shown = {}, 0
local gpool, gshown = {}, 0
local MAX_NODES, NODE_PAD = 60, 250 -- wezly: najwyzej 60 najblizszych w zasiegu minimapy + zapas w jardach

local function hbdp()
  if not LibStub then return nil end
  return LibStub("HereBeDragons-Pins-2.0", true) or LibStub("HereBeDragonsQuestie-Pins-2.0", true)
end
local function hbd()
  if not LibStub then return nil end
  return LibStub("HereBeDragons-2.0", true) or LibStub("HereBeDragonsQuestie-2.0", true)
end
-- poziom nad minimapa (HereBeDragons ustawia tylko rodzica); jak w Questie trzeba zdjac staly poziom na chwile
local function level(f, lvl)
  pcall(f.SetFixedFrameLevel, f, false)
  f:SetFrameLevel(lvl)
  pcall(f.SetFixedFrameLevel, f, true)
end
local function enabled()
  local d = U.db()
  return d.minimapAvail ~= false
end

local function pin(i)
  local f = pool[i]
  if f then return f end
  f = CreateFrame("Button", nil, Minimap)
  f:SetSize(17, 17)
  -- medalion zajmuje ok. 0,63 tekstury, wiec tekstura 1,6 x pole: widac medalion wielkosci pola (17-18 px)
  f.i = f:CreateTexture(nil, "OVERLAY")
  f.i:SetPoint("CENTER")
  f:SetScript("OnEnter", function(self)
    local d = self.d
    if not d then return end
    U.TT:SetOwner(self, "ANCHOR_LEFT")
    U.TT:SetText("Do wzięcia u: " .. (d.name or "?"), 0.85, 0.71, 0.36)
    for _, q in ipairs(d.quests or {}) do
      local c = q.route and 1 or 0.6
      U.TT:AddLine((q.level and ("[" .. q.level .. "] ") or "") .. q.title .. (q.route and "  · trasa Polestara" or "  · poza trasą"), c, c, c)
    end
    U.TT:Show()
  end)
  f:SetScript("OnLeave", function() U.TT:Hide() end)
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
    f.i:SetTexture(d.route and U.ZN.wez or U.ZN.wez_szary)
    -- szary o 1 px wiekszy: zakrywa zolty „!” Questie pod spodem
    local s = d.route and 17 or 18
    f:SetSize(s, s)
    f.i:SetSize(s * 1.6, s * 1.6)
    pcall(P.AddMinimapIconMap, P, REF, f, map, d.x, d.y, false, d.route == true)
    -- nad ikonami Questie (one maja staly poziom ramki ok. 2016+, QuestieMapUtils.lua)
    level(f, 2100 + (d.route and 1 or 0))
  end
  shown = n
end
U.minimapAvailUpdate = update

-- ---------- ziola i ruda ----------
local function gatherOn() return U.db().minimapGather ~= false end
-- profil GatherMate2 tylko do odczytu (rawget: bez tworzenia tabel domyslnych AceDB)
local function gm2Profile()
  local GM = U.GM2 and U.call(U.GM2) or nil
  local db = GM and rawget(GM, "db")
  local p = type(db) == "table" and db.profile
  return GM, type(p) == "table" and p or nil
end

local function gpin(i)
  local f = gpool[i]
  if f then return f end
  f = CreateFrame("Button", nil, Minimap)
  f:SetSize(13, 13)
  -- kolko ziola i rudy zajmuje ok. 0,52 tekstury: widac ok. 13 px
  f.i = f:CreateTexture(nil, "OVERLAY")
  f.i:SetPoint("CENTER")
  f.i:SetSize(26, 26)
  -- klik przechodzi do minimapy (ping), najazd pokazuje dymek jak na mapie huba
  pcall(f.SetMouseClickEnabled, f, false)
  f:SetScript("OnEnter", function(self)
    if self.d and U.gatherTooltip then U.gatherTooltip(self, self.d, nil, "ANCHOR_LEFT") end
  end)
  f:SetScript("OnLeave", function() U.TT:Hide() end)
  gpool[i] = f
  return f
end

-- 15.11 (gracz: „zeby pokazywalo bardziej podswietlone to, co mowi, ze na pewno tam jest zespawnione”): zywe wezly zna
-- tylko gra (zolte kropki sledzenia Find Herbs / Find Minerals na minimapie); addon nie ma do nich dostepu, a nasze
-- ikony to miejsca z bazy GatherMate2 (moze byc, moze nie). Przy wlaczonym sledzeniu danego rodzaju nasze ikony sa
-- male i przygaszone, wiec kropki gry (na pewno zespawnione) sa na wierzchu i najjasniejsze.
local TRACK_SPELL = { [2383] = "Herbalism", [2580] = "Mining" }
local TRACK_NAME = { ["find herbs"] = "Herbalism", ["find minerals"] = "Mining" }
local function tracking()
  local on = {}
  pcall(function()
    local M = C_Minimap
    if not (M and M.GetNumTrackingTypes and M.GetTrackingInfo) then return end
    for i = 1, M.GetNumTrackingTypes() or 0 do
      local a, _, c, _, _, f = M.GetTrackingInfo(i)
      local name, active, spell = a, c, f
      if type(a) == "table" then name, active, spell = a.name, a.active, a.spellID end
      local prof = (spell and TRACK_SPELL[spell]) or (type(name) == "string" and TRACK_NAME[name:lower()])
      if prof and active then on[prof] = true end
    end
  end)
  return on
end
U.gatherTracking = tracking

local function updateGather()
  local P = hbdp()
  if not P then return end
  pcall(P.RemoveAllMinimapIcons, P, GREF)
  for i = 1, gshown do gpool[i]:Hide() end
  gshown = 0
  local GM, prof = gm2Profile()
  if not (gatherOn() and prof and rawget(prof, "showMinimap") == false and U.gatherNodes) then return end
  local H = hbd()
  local map = U.call(C_Map.GetBestMapForUnit, "player")
  if not (H and map) then return end
  local pos = U.call(C_Map.GetPlayerMapPosition, map, "player")
  if not (pos and pos.GetXY) then return end
  local px, py = pos:GetXY()
  px, py = U.num(px), U.num(py)
  local w, h = U.call(H.GetZoneSize, H, map)
  w, h = U.num(w), U.num(h)
  if not (px and py and w and h and w > 0 and h > 0) or (px == 0 and py == 0) then return end
  local vr = C_Minimap and C_Minimap.GetViewRadius and U.num(U.call(C_Minimap.GetViewRadius)) or nil
  local r2 = ((vr or 233) + NODE_PAD) ^ 2
  -- rodzaje jak w GatherMate2 (Visible z profile.show: zawsze, z profesja...) i wezly odfiltrowane w jego ustawieniach
  local vis = type(GM.Visible) == "table" and GM.Visible or nil
  local filter = rawget(prof, "filter")
  local near = {}
  for _, nd in ipairs(U.call(U.gatherNodes, map) or {}) do
    local okType
    if vis then okType = vis[nd.gtype] and true or false else okType = nd.skill ~= nil end
    local ft = okType and type(filter) == "table" and nd.gtype and rawget(filter, nd.gtype)
    if okType and not (type(ft) == "table" and nd.id and rawget(ft, nd.id) == false) then
      local dx, dy = (nd.x - px) * w, (nd.y - py) * h
      local dd = dx * dx + dy * dy
      if dd <= r2 then near[#near + 1] = { nd = nd, dd = dd } end
    end
  end
  table.sort(near, function(a, b) return a.dd < b.dd end)
  local lvl = (Minimap:GetFrameLevel() or 0) + 5
  local tr = tracking()
  local n = 0
  for i = 1, math.min(MAX_NODES, #near) do
    local nd = near[i].nd
    n = n + 1
    local f = gpin(n)
    f.d = nd
    f.i:SetTexture(nd.prof == "Mining" and U.ZN.ruda or U.ZN.ziolo)
    -- 15.11 (gracz: „za bardzo przygaszone i za male”, potem „mining tak samo zrob”): ziola i ruda zawsze jednakowo,
    -- 11 px i 0,65 (wezly bez punktu umiejetnosci 0,4), zeby zolte kropki sledzenia gry (zywe wezly) byly na wierzchu
    local _ = tr
    f:SetSize(11, 11) f.i:SetSize(22, 22)
    f:SetAlpha((nd.d == 4 or not nd.skill) and 0.4 or 0.65)
    pcall(P.AddMinimapIconMap, P, GREF, f, map, nd.x, nd.y, false, false)
    -- pod „!” i ikonami Questie, jak kolka GatherMate2 (poziom minimapy + 5)
    level(f, lvl)
  end
  gshown = n
end
U.minimapGatherUpdate = updateGather

-- /hub minimapa zbieranie: nasze ziola i ruda wl./wyl. (ustawien GatherMate2 nie ruszamy)
function U.minimapGatherCmd()
  local d = U.db()
  d.minimapGather = d.minimapGather == false
  local _, prof = gm2Profile()
  local msg = "hub: zioła i ruda Grimuara na minimapie " .. (gatherOn() and "włączone" or "wyłączone") .. "."
  if gatherOn() and not prof then
    msg = msg .. " GatherMate2 jest wyłączony, bez niego nie ma węzłów."
  elseif gatherOn() and rawget(prof, "showMinimap") ~= false then
    msg = msg .. " Pokażą się, gdy w GatherMate2 wyłączysz jego ikony na minimapie (Show Minimap Icons)."
  end
  U.say(msg)
  pcall(updateGather)
end

local queued = false
local function queue(delay)
  if queued then return end
  queued = true
  C_Timer.After(delay or 1.5, function()
    queued = false
    pcall(update)
  end)
end

-- ziola i ruda: zmiana strefy, umiejetnosci, przyblizenie minimapy i co 5 s (gracz idzie, zapas NODE_PAD)
local gqueued = false
local function gqueue(delay)
  if gqueued then return end
  gqueued = true
  C_Timer.After(delay or 1, function()
    gqueued = false
    pcall(updateGather)
  end)
end

local ev = CreateFrame("Frame")
for _, e in ipairs({ "PLAYER_LOGIN", "ZONE_CHANGED_NEW_AREA", "QUEST_LOG_UPDATE", "QUEST_TURNED_IN", "PLAYER_LEVEL_UP",
  "QUEST_ACCEPTED", "QUEST_REMOVED", "SKILL_LINES_CHANGED", "MINIMAP_UPDATE_ZOOM", "MINIMAP_UPDATE_TRACKING" }) do
  pcall(ev.RegisterEvent, ev, e)
end
ev:SetScript("OnEvent", function(_, event)
  if event == "PLAYER_LOGIN" then
    C_Timer.After(12, function() pcall(update) pcall(updateGather) end)
    C_Timer.NewTicker(10, function() pcall(update) end)
    C_Timer.NewTicker(5, function() pcall(updateGather) end)
  elseif event == "SKILL_LINES_CHANGED" or event == "MINIMAP_UPDATE_ZOOM" or event == "MINIMAP_UPDATE_TRACKING" then
    gqueue(1)
  elseif event == "QUEST_ACCEPTED" or event == "QUEST_TURNED_IN" or event == "QUEST_REMOVED" then
    -- 15.11: przyjety albo oddany quest znika z minimapy od razu (bez 8 s pamieci listy)
    if U.availableReset then U.availableReset() end
    queue(0.3)
  else
    queue(event == "QUEST_LOG_UPDATE" and 2 or 1)
    if event == "ZONE_CHANGED_NEW_AREA" then gqueue(1) end
  end
end)
