-- Grimuar UI: pasek lotu (15.11, R30 P26; gracz: „okna gry, ktore jeszcze nie sa w stylu Grimuara: Mistrz lotow
-- i Handel”). W locie (UnitOnTaxi) maly pasek u gory ekranu: „Lot do <cel> · m:ss”. Cel zapamietany przy TakeTaxiNode
-- (hooksecurefunc: nic nie podmieniamy, mapa i okno Grimuara wolaja te sama funkcje gry). Czas: gdy znamy szacunek
-- (w locie Polestar.Maps.GetFlight, ktory uczy sie Twoich lotow; inaczej czas z okna lotow, Okna/Lot.lua U.lotInfo),
-- odlicza w dol z paskiem postepu; bez szacunku liczy od startu. Po wyladowaniu: czas tej trasy zapamietany
-- (GrimuarUIDB.lotyCzas, tylko gdy wyladowales w miejscu celu) i dopisany do sesji Kroniki (rekord sesji: loty, lotyS;
-- Kronika\TabKronika.lua je pokazuje). Po /reload w locie lot wraca z GrimuarUIDB.lotNow.
-- Widoczny domyslnie; wylacznik: Ustawienia > Grimuar („Pasek lotu u góry ekranu”) albo /hub lot (lotHud == false).
local ADDON, U = ...
local C = U.C
local G = U.G or {}

local K = { pend = nil, fly = nil, shown = nil, acc = 0, hooked = false }
local B
local MIN_FLIGHT, MAX_FLIGHT = 5, 3600

local function db() return U.db() end
local function on() return db().lotHud ~= false end
local function tr(s) return G.tr and G.tr(s) or s end
local function str(v)
  if type(v) ~= "string" or (issecretvalue and issecretvalue(v)) then return nil end
  return v
end
local function mmss(s) return U.lotTime and U.lotTime(s) or tostring(math.floor(s or 0)) end
local function onTaxi()
  local ok, v = pcall(UnitOnTaxi, "player")
  if not ok or (issecretvalue and issecretvalue(v)) then return false end
  return v == true
end

-- napis i postep paska dla lotu f: tekst, ulamek (albo nil)
local function line(f)
  local el = GetTime() - (f.start or GetTime())
  local total = U.num(f.sec)
  local left
  -- Polestar w locie: jego zegar (zapamietany czas tej trasy albo szacunek), Maps\FlightTimer.lua
  local M = _G.Polestar and _G.Polestar.Maps
  if type(M) == "table" and type(M.GetFlight) == "function" then
    local ok, _, l = pcall(M.GetFlight)
    l = ok and U.num(l)
    if l then
      left = l
      total = el + l
    end
  end
  if not left and total then left = total - el end
  local head = f.place and tr("Lot do " .. f.place) or tr("Lot")
  if left and left >= 0 then
    return head .. " · " .. mmss(left), (total and total > 0) and math.min(1, el / total) or nil
  end
  return head .. " · " .. mmss(el), nil
end

local function render()
  if not (B and K.fly) then return end
  local txt, frac = line(K.fly)
  if txt ~= K.shown then
    K.shown = txt
    B.t:SetText(txt)
  end
  B.bar:SetShown(frac ~= nil)
  if frac then B.bar:SetValue(frac) end
end

local function build()
  if B then return end
  B = CreateFrame("Frame", "GrimuarLotPasek", UIParent)
  B:SetSize(380, 40)
  B:SetPoint("TOP", UIParent, "TOP", 0, -86) -- pod kompasem, nad strzalka Polestara (TOP -140)
  B:SetFrameStrata("MEDIUM")
  B.bg = U.Rect(B, C.bg, 0.86) B.bg:SetAllPoints()
  U.Border(B, C.edge, 0.7)
  U.Corners(B, C.gold, 9, 2)
  B.ic = B:CreateTexture(nil, "ARTWORK")
  B.ic:SetSize(22, 22)
  B.ic:SetPoint("LEFT", 9, 2)
  B.ic:SetTexture(132057) -- ikona lotu (TaxiGossipIcon), jak na kartach okna lotow
  B.t = U.Text(B, 14, "title", C.text)
  B.t:SetPoint("LEFT", B.ic, "RIGHT", 8, 0)
  B.t:SetPoint("RIGHT", B, "RIGHT", -10, 2)
  B.t:SetJustifyV("MIDDLE")
  B.bar = U.Bar(B, 4, C.gold)
  B.bar:SetPoint("BOTTOMLEFT", 9, 5)
  B.bar:SetPoint("BOTTOMRIGHT", -9, 5)
  B:EnableMouse(true)
  B:SetScript("OnEnter", function(self)
    local f = K.fly
    if not f then return end
    U.TT:SetOwner(self, "ANCHOR_BOTTOM")
    U.TT:SetText(f.to or tr("Lot"), 1, 1, 1)
    if f.from then U.TT:AddLine(tr("Skąd") .. ": " .. f.from, 0.64, 0.61, 0.55, true) end
    U.TT:AddLine(tr(f.sec and (f.est and "Czas: szacunek Polestara (odliczam)" or "Czas: zapamiętany lot (odliczam)") or "Czas od startu (szacunku brak)"), 0.64, 0.61, 0.55, true)
    U.TT:AddLine(tr("Wyłączysz w Ustawieniach (Grimuar) albo /hub lot."), 0.54, 0.51, 0.45, true)
    U.TT:Show()
  end)
  B:SetScript("OnLeave", function() U.TT:Hide() end)
  B:SetScript("OnUpdate", function(_, el)
    K.acc = K.acc + el
    if K.acc < 0.25 then return end
    K.acc = 0
    local ok, err = pcall(render)
    if not ok and U.logError then U.logError("pasek lotu", err) end
  end)
  B:Hide()
end

local function show()
  if not (K.fly and on()) then
    if B then B:Hide() end
    return
  end
  build()
  K.shown = nil
  B:Show()
  render()
end

-- czy stoisz w miejscu celu (nazwa przed przecinkiem w nazwie wezla vs napisy strefy)
local function arrived(place)
  local p = place:lower()
  for _, n in ipairs({ "GetSubZoneText", "GetZoneText", "GetMinimapZoneText" }) do
    local z = str(U.call(_G[n]))
    if z and z ~= "" then
      z = z:lower()
      if z:find(p, 1, true) or p:find(z, 1, true) then return true end
    end
  end
  return false
end

local function land()
  local f = K.fly
  K.fly = nil
  db().lotNow = nil
  if B then B:Hide() end
  if not f then return end
  local secs = GetTime() - f.start
  if secs < MIN_FLIGHT or secs > MAX_FLIGHT then return end
  -- 15.11 (R30 P26): sesja Kroniki: ile lotow i ile czasu w powietrzu (KronikaDane.lua: U.kronika().cur)
  pcall(function()
    local r = U.kronika and U.kronika().cur
    if type(r) == "table" then
      r.loty = (r.loty or 0) + 1
      r.lotyS = (r.lotyS or 0) + math.floor(secs + 0.5)
    end
  end)
  -- czas tej trasy: tylko pelny lot (wyladowales u celu, nie po rozlaczeniu)
  if f.from and f.to and f.place and not f.restored and arrived(f.place) then
    local d = db()
    d.lotyCzas = d.lotyCzas or {}
    d.lotyCzas[f.from .. ">" .. f.to] = math.floor(secs + 0.5)
  end
end

local function stopWatch()
  if K.tick then K.tick:Cancel() K.tick = nil end
end
local function check()
  local now = onTaxi()
  if now and not K.fly then
    local p = K.pend
    if p and GetTime() - p.at > 20 then p = nil end
    K.pend = nil
    p = p or {}
    K.fly = { to = p.to, place = p.place, from = p.from, sec = p.sec, est = p.est, start = GetTime() }
    db().lotNow = { to = p.to, place = p.place, from = p.from, sec = p.sec, est = p.est, epoch = time() }
    show()
  elseif not now and K.fly then
    land()
  end
  -- nic do pilnowania: ani lotu, ani swiezego wyboru, ani utraty sterowania (lot bez mapy, np. z questu)
  if not now and not K.fly and not (K.pend and GetTime() - K.pend.at <= 20) and GetTime() - (K.lostAt or -100) > 8 then stopWatch() end
end
local function watch()
  if K.tick or not (C_Timer and C_Timer.NewTicker) then return end
  K.tick = C_Timer.NewTicker(0.5, function()
    local ok, err = pcall(check)
    if not ok then
      stopWatch()
      if U.logError then U.logError("pasek lotu", err) end
    end
  end)
end

-- cel zapamietany przy wyborze lotu (mapa gry, okno Grimuara, klawisz Polestara: zawsze TakeTaxiNode)
local function onPick(slot)
  slot = U.num(slot)
  if not slot then return end
  local info = U.lotInfo and U.lotInfo(slot)
  if not info then
    local name = str(U.call(TaxiNodeName, slot))
    if not name then return end
    info = { to = name, place = name:match("^([^,]+),") or name }
  end
  info.at = GetTime()
  K.pend = info
  watch()
end
if type(TakeTaxiNode) == "function" and hooksecurefunc then
  hooksecurefunc("TakeTaxiNode", function(slot)
    local ok, err = pcall(onPick, slot)
    if not ok and U.logError then U.logError("pasek lotu", err) end
  end)
  K.hooked = true
end

-- /reload albo wejscie do gry w locie: lot z zapisu (jesli swiezy), inaczej sam czas
local function resume()
  if K.fly or not onTaxi() then return end
  local s = db().lotNow
  local ago = type(s) == "table" and U.num(s.epoch) and (time() - s.epoch)
  if ago and ago >= 0 and ago < MAX_FLIGHT then
    K.fly = { to = s.to, place = s.place, from = s.from, sec = s.sec, est = s.est, start = GetTime() - ago, restored = true }
  else
    K.fly = { start = GetTime(), restored = true }
  end
  show()
  watch()
end

local ev = CreateFrame("Frame")
for _, e in ipairs({ "PLAYER_ENTERING_WORLD", "PLAYER_CONTROL_LOST", "PLAYER_CONTROL_GAINED" }) do pcall(ev.RegisterEvent, ev, e) end
ev:SetScript("OnEvent", function(_, e)
  if e == "PLAYER_ENTERING_WORLD" then
    C_Timer.After(2, function() pcall(resume) end)
  else
    -- wsiadanie i ladowanie: sprawdz od razu i pilnuj, az sie skonczy
    if e == "PLAYER_CONTROL_LOST" then K.lostAt = GetTime() end
    pcall(check)
    if K.fly or K.pend or e == "PLAYER_CONTROL_LOST" then watch() end
  end
end)

-- ---------- przelacznik (Ustawienia > Grimuar, /hub lot) ----------
function U.lotHudCmd()
  local d = db()
  d.lotHud = d.lotHud == false
  U.say(d.lotHud ~= false and "pasek lotu u góry ekranu włączony." or "pasek lotu wyłączony.")
  pcall(show)
end
if U.G then U.G.lotHudCmd = U.lotHudCmd end
-- przelaczniki Grimuara (GrimuarSetup Okno\Strony.lua G.TOGGLES, tez strona Grimuar w Ustawieniach huba): za pasem podrecznym
if type(G.TOGGLES) == "table" then
  local entry = { "Pasek lotu u góry ekranu: cel i czas lotu (hub)", function() return not (GrimuarUIDB and GrimuarUIDB.lotHud == false) end,
    function() if G.lotHudCmd then G.lotHudCmd() end end }
  local at = #G.TOGGLES + 1
  for i, t in ipairs(G.TOGGLES) do
    if type(t) == "table" and type(t[1]) == "string" and t[1]:find("^Pas podręczny") then at = i + 1 end
  end
  table.insert(G.TOGGLES, at, entry)
end

-- ---------- /gr test ----------
U.testChecksExtra = U.testChecksExtra or {}
table.insert(U.testChecksExtra, { "pasek lotu (UnitOnTaxi, TakeTaxiNode)", function()
  if type(UnitOnTaxi) ~= "function" then error("brak UnitOnTaxi w kliencie: pasek lotu się nie pokaże") end
  local ok, err = pcall(build)
  if not ok then error("budowa paska: " .. tostring(err)) end
  local okL, txt = pcall(line, { place = "Test", start = GetTime() - 65, sec = 120 })
  if not okL then error("napis paska: " .. tostring(txt)) end
  local n = 0
  for _ in pairs(db().lotyCzas or {}) do n = n + 1 end
  local M = _G.Polestar and _G.Polestar.Maps
  local src = (type(M) == "table" and type(M.GetFlight) == "function") and "Polestar.Maps.GetFlight" or "okno lotów i czasy Grimuara"
  return (on() and "włączony" or "wyłączony (Ustawienia > Grimuar)") .. (K.hooked and "" or ", bez TakeTaxiNode (cel nieznany)") ..
    ", czas: " .. src .. ", zapamiętane trasy: " .. n .. ", próbka: " .. tostring(txt) .. (K.fly and ", teraz w locie" or "")
end })
