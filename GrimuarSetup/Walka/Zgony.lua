-- Grimuar: modul Zgony. Porada po smierci (prosba gracza 13.11): przy zgonie zapisuje, kto zabil (klasa gracza Hordy,
-- elita, roznica poziomow), a po odrodzeniu pokazuje jedna konkretna rade na wstedze. Porady PvP z researchu R3,
-- PvE z R6. Podsumowanie zgonow: okno Grimuara, Dziś. Wartosci czytane w pcall (w walce moga byc ukryte).
local ADDON_NAME, G = ...

local PVP = G.BD.pvp -- porady PvP z aktywnego buildu (Build/Api.lua)

-- Od 40 poziomu porady na 60 (R11, 13.11)
local PVP60 = G.BD.pvp60

local last -- { name, class, player, elite, diff }

local function snapshot()
  local d = {}
  pcall(function()
    if not UnitExists("target") then return end
    d.name = UnitName("target")
    d.player = UnitIsPlayer("target") and true or false
    local _, token = UnitClass("target")
    d.class = token
    local c = UnitClassification("target")
    d.elite = (c == "elite" or c == "rareelite" or c == "worldboss")
    local tl, pl = UnitLevel("target"), UnitLevel("player")
    if tl == -1 then d.diff = 10 elseif tl and pl then d.diff = tl - pl end
  end)
  return d
end

local function tipFor(d)
  if not d then return nil end
  if d.player then
    if d.diff and d.diff >= 5 then
      return "Zabił Cię gracz o " .. (d.diff >= 10 and "wiele" or d.diff) .. " poziomów wyżej. Z takim nie walcz: zmień strefę albo wróć Hearthstonem."
    end
    local book = ((UnitLevel("player") or 1) >= 40) and PVP60 or PVP
    return book[d.class or ""] or "Gracz Hordy: walcz tylko 1 na 1 i ze swojego poziomu, inaczej Nova (Q), Blink (E) i uciekaj."
  end
  if d.elite then return "To był mob elitarny (złota ramka): takie bierz tylko z grupą." end
  if d.diff and d.diff >= 3 then
    return "Mob był o " .. d.diff .. " poziomy wyżej. Wybieraj moby najwyżej 1–2 poziomy wyżej od siebie."
  end
  return "Zacznij Frostboltem z daleka, przy dwóch mobach owca (Alt+R, R), a przed walką napij się do pełna (Z)."
end

local function deathsToday()
  local S = G.S
  return (S and S.deaths) and #S.deaths or 0
end

local function onRevive()
  if not last then return end
  local tip = tipFor(last)
  last = nil
  if not tip then return end
  local n = deathsToday()
  if n >= 3 then tip = tip .. " To już " .. n .. ". zgon dziś: sprawdź trenera, talenty i różdżkę (okno Grimuara: Dziś)." end
  G.lastDeathTip = tip
  C_Timer.After(2, function() pcall(G.showToast, tip, "death", false) end)
end

-- ---------- prowadzenie do ciala (gracz 13.11: „nie da sie ustawic, zeby mnie prowadzilo do trupa?”) ----------
-- Po Release Spirit gra podaje miejsce ciala na mapie strefy (C_DeathInfo.GetCorpseMapPosition). Grimuar sam stawia
-- tam strzalke Polestar (G.wayTo), tak samo po /reload jako duch; po wskrzeszeniu strzalke zdejmuje.
local guidingCorpse = false

local function corpseSpot()
  local okM, map = pcall(C_Map.GetBestMapForUnit, "player")
  map = okM and map or nil
  for _ = 1, 3 do
    if not map then return nil end
    local okP, pos = pcall(C_DeathInfo.GetCorpseMapPosition, map)
    if okP and pos and pos.GetXY then
      local x, y = pos:GetXY()
      if x and y and (x > 0 or y > 0) then return map, x, y end
    end
    local okI, info = pcall(C_Map.GetMapInfo, map)
    map = (okI and info and info.parentMapID and info.parentMapID > 0) and info.parentMapID or nil
  end
end

-- Polestar ma wlasnego pomocnika ducha (qol.deathHelper): do 10 poziomu wybiera Spirit Healera (bez oslabienia)
-- i trzyma na nim strzalke (Nav.Hold), wiec nasz /way nic nie zmienial (gracz 13.11: „nie prowadzi do ciala”).
-- Wylaczamy go jego wlasnym API (Polestar.Set): to od razu zwalnia strzalke. Kontrola pilnuje tego ustawienia.
local function polestarDeathOff()
  local was = false
  pcall(function()
    if type(Polestar) == "table" and Polestar.Get and Polestar.Set and Polestar.Get("qol.deathHelper") then
      Polestar.Set("qol.deathHelper", false)
      was = true
    end
  end)
  return was
end

-- Cialo w jaskini (gracz 13.11: „nie potrafie znalezc wejscia do jaskini”): punkt ciala nie ma wysokosci, wiec
-- trasa Polestara konczy sie na zboczu nad jaskinia. Przy smierci zapisujemy podstrefe (np. „The Grizzled Den”);
-- gdy to jaskinia z listy wejsc Polestara (PolestarNavChokepoints, kind "cave"), strzalka prowadzi najpierw
-- do wejscia, a w srodku (ta sama podstrefa albo 15 m od wejscia) do ciala.
local caveTicker

local function caveMouth(name)
  if not name or name == "" then return nil end
  local cps = _G.PolestarNavChokepoints
  if type(cps) ~= "table" then return nil end
  local okI, cont = pcall(function() return select(8, GetInstanceInfo()) end)
  for _, c in ipairs((okI and cps[cont]) or {}) do
    if c.kind == "cave" then
      -- nazwa z AreaTable w jezyku klienta (C_Map.GetAreaInfo), zapasowo angielska z listy
      local okA, an = pcall(C_Map.GetAreaInfo, c.area or 0)
      if c.name == name or (okA and an == name) then return c, cont end
    end
  end
end

local function mouthOnMap(c, cont, map)
  local x, y
  pcall(function()
    local _, pos = C_Map.GetMapPosFromWorldPos(cont, CreateVector2D(c.wx, c.wy), map)
    if pos then x, y = pos:GetXY() end
  end)
  if x and y and x > 0 and y > 0 and x < 1 and y < 1 then return math.floor(x * 10000 + 0.5) / 100, math.floor(y * 10000 + 0.5) / 100 end
end

local function nearMouth(c)
  local near = false
  pcall(function()
    local py, px = UnitPosition("player")
    if py and not (issecretvalue and issecretvalue(py)) then near = ((py - c.wx) ^ 2 + (px - c.wy) ^ 2) < 15 * 15 end
  end)
  return near
end

local function stopCave()
  if caveTicker then caveTicker:Cancel() caveTicker = nil end
end

local function guideCorpse(quiet)
  if not (UnitIsGhost and UnitIsGhost("player")) then
    if not quiet then G.say("strzałka do ciała działa po Release Spirit, gdy jesteś duchem.") end
    return false
  end
  local map, x, y = corpseSpot()
  if not map then
    if not quiet then G.say("gra nie podaje teraz miejsca ciała. Ikona ciała jest na minimapie i na mapie M.") end
    return false
  end
  guidingCorpse = true
  local wx, wy = math.floor(x * 10000 + 0.5) / 100, math.floor(y * 10000 + 0.5) / 100
  -- najpierw wejscie do jaskini, w ktorej lezy cialo
  stopCave()
  local sub = GrimuarSetupDB.deathSub
  local cave, cont = caveMouth(sub)
  if cave and GetSubZoneText() ~= sub and not nearMouth(cave) then
    local mx, my = mouthOnMap(cave, cont, map)
    if mx then
      polestarDeathOff()
      C_Timer.After(0.3, function() pcall(G.wayTo, map, mx, my, "wejście: " .. sub) end)
      G.say("ciało jest w jaskini " .. sub .. ": najpierw strzałka do wejścia, w środku poprowadzę do ciała.")
      caveTicker = C_Timer.NewTicker(1, function()
        if not UnitIsGhost("player") then stopCave() return end
        if GetSubZoneText() == sub or nearMouth(cave) then
          stopCave()
          pcall(G.wayTo, map, wx, wy, "Twoje ciało")
        end
      end)
      return true
    end
  end
  if polestarDeathOff() then
    -- Polestar zwalnia swoja strzalke na Spirit Healerze; nasz punkt chwile pozniej
    C_Timer.After(0.3, function() pcall(G.wayTo, map, wx, wy, "Twoje ciało") end)
    return true
  end
  return G.wayTo(map, wx, wy, "Twoje ciało")
end

local function stopCorpse()
  stopCave()
  GrimuarSetupDB.deathSub = nil
  if not guidingCorpse then return end
  guidingCorpse = false
  pcall(G.releaseArrow)
end

local ev = CreateFrame("Frame")
ev:RegisterEvent("PLAYER_DEAD")
ev:RegisterEvent("PLAYER_ALIVE")
ev:RegisterEvent("PLAYER_UNGHOST")
ev:RegisterEvent("PLAYER_ENTERING_WORLD")
ev:SetScript("OnEvent", function(_, event)
  if event == "PLAYER_ENTERING_WORLD" or (event == "PLAYER_ALIVE" and UnitIsGhost("player")) then
    -- duch: po Release Spirit, po /reload i po wejsciu do innej strefy
    C_Timer.After(event == "PLAYER_ALIVE" and 1.5 or 6, function()
      if UnitIsGhost("player") then pcall(guideCorpse, true) end
    end)
    if event == "PLAYER_ENTERING_WORLD" then
      C_Timer.After(5, function() pcall(polestarDeathOff) end) -- od razu, zeby kontrola nie pytala
      return
    end
  end
  if event == "PLAYER_UNGHOST" or (event == "PLAYER_ALIVE" and not UnitIsDeadOrGhost("player")) then pcall(stopCorpse) end
  if event == "PLAYER_DEAD" then
    pcall(function() GrimuarSetupDB.deathSub = GetSubZoneText() end)
    last = snapshot()
    -- dopisz klase i elite do wpisu zgonu z Engine (dziennik sesji)
    C_Timer.After(0.2, function()
      pcall(function()
        local e = G.S.deaths[#G.S.deaths]
        if e and last then e.class, e.elite, e.diff = last.class, last.elite, last.diff end
      end)
    end)
  elseif event == "PLAYER_UNGHOST" or (event == "PLAYER_ALIVE" and not UnitIsDeadOrGhost("player")) then
    onRevive()
  end
end)

-- Podsumowanie do okna: zgony dzis i najczestszy zabojca z ostatnich sesji
local function deathSummary()
  local n = deathsToday()
  local counts = {}
  local L = GrimuarSetupDB.log and GrimuarSetupDB.log[G.charKey()]
  for i = math.max(1, #(L or {}) - 9), #(L or {}) do
    for _, d in ipairs((L[i] and L[i].deaths) or {}) do
      local k = d.class or d.by or "?"
      counts[k] = (counts[k] or 0) + 1
    end
  end
  for _, d in ipairs((G.S and G.S.deaths) or {}) do
    local k = d.class or d.by or "?"
    counts[k] = (counts[k] or 0) + 1
  end
  local top, topN = nil, 0
  for k, v in pairs(counts) do if v > topN then top, topN = k, v end end
  return n, top, topN
end

G.guideCorpse = guideCorpse
G.deathTip = tipFor
G.deathSummary = deathSummary
