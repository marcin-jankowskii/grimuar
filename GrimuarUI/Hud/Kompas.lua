-- Grimuar UI: kompas u gory ekranu (makieta 14.11 „HUD · Eksploracja”, zaakceptowana razem z hubem; gracz 14.11:
-- „tego kompasu z gory gry na pewno nie dodales”). Pasek 360° jak w Skyrimie i Crimson Desert:
-- * kierunki Pn / Wsch / Pd / Zach (ten najblizej srodka na zloto), kreski co 11,25°;
-- * pelny zloty romb + odleglosc = cel strzalki Polestara (takze „Prowadz” z huba, G.wayTo);
-- * romb w kolorze zadania (te same kolory co mapa huba) = najblizszy cel kazdego zadania na tej mapie, „?” = oddaj;
-- * kropka = najblizsze ziolo (zielona) albo ruda (miedziana), ktore da punkt (GatherMate2, bez odleglosci);
-- * 15.11 (R30 P04): pelny niebieski romb + odleglosc = „Przy okazji” Polestara (cel z dalszego kroku trasy obok,
--   Dziennik\DziennikPrzyOkazji.lua U.psHereSpots); prowadzi klik w karte w Dzienniku, kompas dalej nie lapie myszy.
-- Gdy u gory jest pasek celu (makieta „HUD · Walka”), kompas sie chowa. 15.11 gracz: „kompas tez mi zniknal”: w walce
-- i w lochu zostaje (bez kierunku z gry jest przezroczysty); /hub kompas walka chowa go w walce.
-- Pasek tempa Grimuara (GrimuarHUD), jesli go nie przesuwales, schodzi pod kompas.
-- Tylko wlasne ramki, bez myszy (nie lapie klikniec). /hub kompas wlacza i wylacza, /hub kompas walka: chowanie w walce.
local ADDON, U = ...
local C = U.C

local W0, H0 = 640, 54                   -- makieta 1600 x 900
local PXR = 160 / (math.pi / 2)          -- 90° = 160 px makiety (caly pasek = 360°)
local NTICK = 32                         -- kreska co 11,25° (co 20 px makiety)
local TWO_PI = 2 * math.pi
local DIRS = { { 0, "Pn" }, { math.pi / 2, "Zach" }, { math.pi, "Pd" }, { -math.pi / 2, "Wsch" } }
local HERB, ORE = { 0.50, 0.79, 0.35 }, { 0.82, 0.55, 0.32 }
local MAX_QUESTS, MAX_NODES, NODE_RANGE = 5, 2, 250   -- jardy
local MAX_HERE = 3                                     -- romby „Przy okazji” Polestara
local DEDUP = 40                                       -- cel zadania blizej celu Polestara = ten sam punkt

local K = { k = 1, items = {}, vis = {}, built = false, combat = false }
local f                                 -- ramka kompasu
local ticks, letters, pool = {}, {}, {}

local function db() return U.db and U.db() or {} end
local function logErr(where, e) if U.logError then U.logError(where, e) end end

local function wrap(a)
  a = a % TWO_PI
  if a > math.pi then a = a - TWO_PI end
  return a
end

-- ---------- pozycja i wektory ----------
local function playerPos()
  local map = U.call(C_Map.GetBestMapForUnit, "player")
  if not map then return nil end
  local p = U.call(C_Map.GetPlayerMapPosition, map, "player")
  if not (p and p.GetXY) then return nil end
  local x, y = p:GetXY()
  x, y = U.num(x), U.num(y)
  if not (x and y) or (x == 0 and y == 0) then return nil end
  return map, x, y
end

local sizes = {}
local function mapSize(map)
  local s = sizes[map]
  if s == nil then
    local w, h = U.call(C_Map.GetMapWorldSize, map)
    w, h = U.num(w), U.num(h)
    if not (w and h and w > 0 and h > 0) and CreateVector2D then
      -- zapas jak w HereBeDragons: rogi mapy w swiecie (x = pn., y = zach.)
      local _, a = U.call(C_Map.GetWorldPosFromMapPos, map, CreateVector2D(0, 0))
      local _, b = U.call(C_Map.GetWorldPosFromMapPos, map, CreateVector2D(1, 1))
      if a and b and a.GetXY and b.GetXY then
        local top, left = a:GetXY()
        local bottom, right = b:GetXY()
        top, left, bottom, right = U.num(top), U.num(left), U.num(bottom), U.num(right)
        if top and left and bottom and right then w, h = math.abs(left - right), math.abs(top - bottom) end
      end
    end
    s = (w and h and w > 0 and h > 0) and { w, h } or false
    sizes[map] = s
  end
  return s or nil
end

-- kierunek (radiany: 0 = pn., rosnie przeciwnie do wskazowek zegara, jak GetPlayerFacing) i jardy z (x1, y1) do (x2, y2)
local function vec(map, x1, y1, x2, y2)
  local s = mapSize(map)
  if not s then return nil end
  local de, ds = (x2 - x1) * s[1], (y2 - y1) * s[2]     -- na wschod, na poludnie
  return math.atan2(-de, -ds), math.sqrt(de * de + ds * ds)
end

-- 15.11 (R30 P04): punkt na innej mapie (strefa a jaskinia, miasto): przez wspolrzedne swiata (x = pn., y = zach.)
local function worldPos(map, x, y)
  if not (CreateVector2D and C_Map.GetWorldPosFromMapPos) then return nil end
  local c, w = U.call(C_Map.GetWorldPosFromMapPos, map, CreateVector2D(x, y))
  if not (c and w and w.GetXY) then return nil end
  local wn, ww = w:GetXY()
  wn, ww = U.num(wn), U.num(ww)
  if not (wn and ww) then return nil end
  return c, wn, ww
end
local function vecTo(map, x1, y1, map2, x2, y2)
  if map2 == map then return vec(map, x1, y1, x2, y2) end
  local c1, n1, w1 = worldPos(map, x1, y1)
  local c2, n2, w2 = worldPos(map2, x2, y2)
  if not (c1 and c2 and c1 == c2) then return nil end
  local dn, dw = n2 - n1, w2 - w1
  return math.atan2(dw, dn), math.sqrt(dn * dn + dw * dw)
end

local function polestarTarget()
  local N = Polestar and Polestar.Nav
  if not (N and N.GetTarget and N.TargetOffset) then return nil end
  local okT, t = pcall(N.GetTarget)
  if not okT or not t then return nil end
  local ok, dn, dw = pcall(N.TargetOffset)
  dn, dw = ok and U.num(dn), ok and U.num(dw)
  if not (dn and dw) then return nil end
  return math.atan2(dw, dn), math.sqrt(dn * dn + dw * dw), dn, dw
end

-- ---------- dane: co pokazac (co 2 s) ----------
local function collect()
  local items = {}
  local map, px, py = playerPos()
  if map then
    -- zadania: najblizszy punkt kazdego zadania na tej mapie
    local _, quests = U.call(U.questPins, map)
    local qs = {}
    for _, q in ipairs(type(quests) == "table" and quests or {}) do
      local best, bd
      for _, p in ipairs(q.pins or {}) do
        local _, d = vec(map, px, py, p.x, p.y)
        if d and (not bd or d < bd) then best, bd = p, d end
      end
      if best then qs[#qs + 1] = { kind = best.kind == "done" and "done" or "obj", x = best.x, y = best.y, col = q.col, d = bd } end
    end
    table.sort(qs, function(a, b) return a.d < b.d end)
    for i = 1, math.min(MAX_QUESTS, #qs) do items[#items + 1] = qs[i] end
    -- zbieractwo: najblizsze wezly, ktore dadza punkt
    local nodes = U.call(U.gatherNodes, map)
    local ns = {}
    for _, n in ipairs(type(nodes) == "table" and nodes or {}) do
      if n.req and n.skill and n.req <= n.skill and (n.d or 0) ~= 3 then
        local _, d = vec(map, px, py, n.x, n.y)
        if d and d <= NODE_RANGE then ns[#ns + 1] = { kind = "node", x = n.x, y = n.y, col = n.prof == "Mining" and ORE or HERB, d = d } end
      end
    end
    table.sort(ns, function(a, b) return a.d < b.d end)
    for i = 1, math.min(MAX_NODES, #ns) do items[#items + 1] = ns[i] end
    -- 15.11 (R30 P04): „Przy okazji” Polestara (najblizsze pierwsze, procenty na mapie zywej)
    local here = U.psHereSpots and U.call(U.psHereSpots)
    for i, h in ipairs(type(here) == "table" and here or {}) do
      if i > MAX_HERE then break end
      items[#items + 1] = { kind = "here", map = h.map, x = h.x / 100, y = h.y / 100, col = C.frost }
    end
  end
  K.items, K.map = items, map
end

-- ---------- rysowanie ----------
local function txt(parent, size, kind, col)
  local fs = U.Text(parent, math.max(8, math.floor(size + 0.5)), kind, col)
  fs:SetJustifyH("CENTER")
  U.Shadow(fs)
  return fs
end

local function fadeBar(parent, y, h, col, a, layer)
  local k, w = K.k, W0 * K.k
  local parts = {}
  for i = 1, 3 do
    local t = parent:CreateTexture(nil, layer or "BACKGROUND")
    t:SetColorTexture(1, 1, 1, 1)
    t:SetHeight(h)
    parts[i] = t
  end
  local edge = w * 0.18
  parts[1]:SetPoint("TOPLEFT", parent, "TOPLEFT", 0, -y) parts[1]:SetWidth(edge)
  parts[3]:SetPoint("TOPRIGHT", parent, "TOPRIGHT", 0, -y) parts[3]:SetWidth(edge)
  parts[2]:SetPoint("TOPLEFT", parts[1], "TOPRIGHT") parts[2]:SetPoint("TOPRIGHT", parts[3], "TOPLEFT")
  local c0, c1 = CreateColor(col[1], col[2], col[3], 0), CreateColor(col[1], col[2], col[3], a)
  pcall(parts[1].SetGradient, parts[1], "HORIZONTAL", c0, c1)
  parts[2]:SetColorTexture(col[1], col[2], col[3], a)
  pcall(parts[3].SetGradient, parts[3], "HORIZONTAL", c1, c0)
  return parts
end

local function marker(i)
  local m = pool[i]
  if m then return m end
  local k = K.k
  m = CreateFrame("Frame", nil, f)
  m:SetSize(56 * k, 34 * k)
  m.rh = U.Diamond(m, 16 * k, C.gold, true)
  m.rh:SetPoint("TOP", m, "TOP", 0, 0)
  m.q = txt(m, 17 * k, "title", C.gold)
  m.q:SetText("?")
  m.q:SetPoint("TOP", m, "TOP", 0, 3 * k)
  m.dot = m:CreateTexture(nil, "ARTWORK")
  m.dot:SetSize(8 * k, 8 * k)
  m.dot:SetPoint("TOP", m, "TOP", 0, -4 * k)
  m.dot:SetColorTexture(1, 1, 1, 1)
  pcall(function()
    local mk = m:CreateMaskTexture()
    mk:SetTexture("Interface\\CHARACTERFRAME\\TempPortraitAlphaMask", "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
    mk:SetAllPoints(m.dot)
    m.dot:AddMaskTexture(mk)
  end)
  m.num = txt(m, 12 * k, "body", C.text)
  m.num:SetPoint("TOP", m, "TOP", 0, -17 * k)
  pool[i] = m
  return m
end

local function build()
  if K.built then return end
  local k = math.max(0.6, (UIParent:GetHeight() or 900) / 900)
  K.k = k
  f = CreateFrame("Frame", "GrimuarKompas", UIParent)
  f:SetFrameStrata("LOW")
  f:SetSize(W0 * k, H0 * k)
  f:SetPoint("TOP", UIParent, "TOP", 0, -6 * k)
  f:EnableMouse(false)
  f:Hide()
  -- delikatne tlo pod kreskami (czytelnosc na sniegu Dun Morogh), wygaszone na koncach jak w makiecie
  fadeBar(f, 0, H0 * k, C.bg, 0.22, "BACKGROUND")
  -- kreski i linia bazowa
  for i = 1, NTICK do
    local t = f:CreateTexture(nil, "ARTWORK")
    t:SetColorTexture(C.text[1], C.text[2], C.text[3], 1)
    t:SetSize(math.max(1, k), (i % 4 == 1 and 15 or 11) * k)
    ticks[i] = t
  end
  fadeBar(f, 34 * k, math.max(1, k), C.text, 0.6, "ARTWORK")
  -- srodek: krotka zlota kreska = Twoj kierunek
  local mid = f:CreateTexture(nil, "OVERLAY")
  mid:SetColorTexture(C.gold[1], C.gold[2], C.gold[3], 0.9)
  mid:SetSize(math.max(2, 2 * k), 9 * k)
  mid:SetPoint("TOP", f, "TOP", 0, -30 * k)
  for i, d in ipairs(DIRS) do
    letters[i] = txt(f, 15 * k, "title", C.text)
    letters[i]:SetText(d[2])
    letters[i].a = d[1]
  end
  f:SetScript("OnUpdate", function(_, el)
    K.acc = (K.acc or 0) + el
    if K.acc < 0.03 then return end
    K.acc = 0
    local ok, e = pcall(U.kompasDraw)
    -- 15.11: blad rysowania nie chowa kompasu na stale; zapis raz na 60 s, rysowanie probuje dalej
    if not ok and (not K.errAt or GetTime() - K.errAt > 60) then K.errAt = GetTime() logErr("kompas/draw", e) end
  end)
  K.built = true
end

-- odleglosci i kierunki (co 0,2 s, bo gracz idzie)
local function measure()
  local vis = {}
  local tb, td, tn, tw = polestarTarget()
  if tb then vis[#vis + 1] = { kind = "target", b = tb, d = td } end
  local map, px, py = playerPos()
  if map then
    for _, it in ipairs(K.items) do
      local b, d
      if it.map then b, d = vecTo(map, px, py, it.map, it.x, it.y)
      elseif map == K.map then b, d = vec(map, px, py, it.x, it.y) end
      if b then
        local dup = false
        if tb and it.kind ~= "node" then
          local dn, dw = d * math.cos(b), d * math.sin(b)
          dup = math.sqrt((dn - tn) ^ 2 + (dw - tw) ^ 2) < DEDUP
        end
        if not dup then vis[#vis + 1] = { kind = it.kind, b = b, d = d, col = it.col } end
      end
    end
  end
  K.vis = vis
  -- 15.11 (R30 P18): czas dojscia do celu strzalki z planera Polestara (Nav.travel.Remaining, co 1 s)
  if tb and (not K.etaAt or GetTime() - K.etaAt > 1) then
    K.etaAt, K.eta = GetTime(), nil
    local T = Polestar and Polestar.Nav and Polestar.Nav.travel
    if T and T.Remaining then
      local ok, s = pcall(T.Remaining, td)
      if ok and type(s) == "number" and s > 0 then K.eta = s end
    end
  elseif not tb then K.eta = nil end
  K.measured = GetTime()
end

local function fade(x, hw)
  local a = (hw - math.abs(x)) / (0.36 * hw)
  if a <= 0 then return 0 end
  return a > 1 and 1 or a
end

function U.kompasDraw()
  local facing = U.num(GetPlayerFacing and GetPlayerFacing())
  if not facing then f:SetAlpha(0) return end
  f:SetAlpha(1)
  if not K.measured or GetTime() - K.measured > 0.2 then measure() end
  local k, hw = K.k, W0 * K.k / 2
  for i, t in ipairs(ticks) do
    local x = -wrap((i - 1) * (TWO_PI / NTICK) - facing) * PXR * k
    local a = fade(x, hw)
    if a > 0 then
      t:ClearAllPoints()
      t:SetPoint("TOP", f, "TOP", x, -(i % 4 == 1 and 19 or 23) * k)
      t:SetAlpha(0.5 * a)
      t:Show()
    else t:Hide() end
  end
  local bestI, bestR
  for i, fs in ipairs(letters) do
    local r = math.abs(wrap(fs.a - facing))
    if not bestR or r < bestR then bestI, bestR = i, r end
  end
  for i, fs in ipairs(letters) do
    local x = -wrap(fs.a - facing) * PXR * k
    local a = fade(x, hw)
    if a > 0 then
      fs:ClearAllPoints()
      fs:SetPoint("TOP", f, "TOP", x, 0)
      if i == bestI and bestR < math.pi / 4 then U.Color(fs, C.gold, a) else U.Color(fs, C.text, 0.6 * a) end
      fs:Show()
    else fs:Hide() end
  end
  -- znaczniki: cel Polestara pierwszy, potem od najblizszego; odleglosc tylko tam, gdzie nie nachodzi na inna
  local used = {}
  local n = 0
  for _, v in ipairs(K.vis) do
    local x = -wrap(v.b - facing) * PXR * k
    local a = fade(x, hw)
    if a > 0 then
      n = n + 1
      local m = marker(n)
      m:ClearAllPoints()
      m:SetPoint("TOP", f, "TOP", x, -21 * k)
      m:SetAlpha(a)
      -- 15.11 (gracz: „zniknal mi kompas, chyba po walce”): przy wielu znacznikach poziom wychodzil ujemny (node: 2 - 9),
      -- gra zglaszala blad SetFrameLevel, a kompas chowal sie na stale. Podstawa +10 i przyciecie do 0–65535.
      local lvl = f:GetFrameLevel() + 10 + (v.kind == "target" and 20 or (v.kind == "node" and 2 or (v.kind == "here" and 15 or 10))) - math.min(n, 9)
      m:SetFrameLevel(math.max(0, math.min(65535, lvl)))
      m.rh:SetShown(v.kind == "target" or v.kind == "obj" or v.kind == "here")
      if v.kind == "target" then m.rh:Set(C.gold, true)
      elseif v.kind == "here" then m.rh:Set(C.frost, true)
      elseif v.kind == "obj" then m.rh:Set(v.col or C.text, false) end
      m.q:SetShown(v.kind == "done")
      m.dot:SetShown(v.kind == "node")
      if v.kind == "node" then local c = v.col or HERB m.dot:SetVertexColor(c[1], c[2], c[3], 1) end
      local free = v.kind ~= "node"
      if free then
        for _, ux in ipairs(used) do if math.abs(ux - x) < 38 * k then free = false break end end
      end
      if free then
        used[#used + 1] = x
        local eta = v.kind == "target" and K.eta and U.G and U.G.etaShort and U.G.etaShort(K.eta)
        m.num:SetText((U.fmtDistance and U.fmtDistance(v.d * 0.9144) or "") .. (eta and (" · " .. eta) or ""))
        U.Color(m.num, v.kind == "target" and C.gold or (v.kind == "here" and C.frost or C.text))
        m.num:Show()
      else m.num:Hide() end
      m:Show()
    end
  end
  for i = n + 1, #pool do pool[i]:Hide() end
end

-- ---------- kiedy widac ----------
local function want()
  local d = db()
  if d.kompas == false then return false end
  if K.combat and d.kompasWalka == false then return false end
  -- makieta „HUD · Walka”: przy wrogim celu u gory jest cel (HudWalka.lua)
  if U.hudTargetActive and U.hudTargetActive() then return false end
  return true
end

-- pasek tempa Grimuara (GrimuarSetup, Dock.lua): pod kompas, chyba ze przesuniety recznie (GrimuarSetupDB.hudPos)
local function anchorHud()
  local hud = _G.GrimuarHUD
  if not hud or (GrimuarSetupDB and GrimuarSetupDB.hudPos) then return end
  hud:ClearAllPoints()
  if K.built and db().kompas ~= false then hud:SetPoint("TOP", f, "BOTTOM", 0, -2)
  else hud:SetPoint("TOP", UIParent, "TOP", 0, -6) end
end

local function apply()
  if not K.built then return end
  if want() then
    if not f:IsShown() then K.measured = nil pcall(collect) end
    f:Show()
  else
    f:Hide()
  end
  pcall(anchorHud)
end
U.kompasApply = apply

function U.kompasCmd(arg)
  local d = db()
  if arg == "walka" then
    d.kompasWalka = d.kompasWalka == false
    U.say("kompas w walce: " .. (d.kompasWalka == false and "chowa się" or "zostaje") .. ".")
  else
    d.kompas = d.kompas == false
    U.say("kompas u góry ekranu " .. (d.kompas ~= false and "włączony" or "wyłączony") .. ". /hub kompas walka: chowanie w walce.")
  end
  apply()
end
if U.G then U.G.kompasCmd = U.kompasCmd end -- przelacznik w oknie Grimuara (GrimuarSetup Strony.lua)

-- ---------- zdarzenia ----------
local queued = false
local function soon(delay)
  if queued then return end
  queued = true
  C_Timer.After(delay or 1, function()
    queued = false
    if K.built and f:IsShown() and not (U.IsOpen and U.IsOpen()) then
      local ok, e = pcall(collect)
      if not ok then logErr("kompas/collect", e) end
      K.measured = nil
    end
  end)
end

U.kompasSoon = function(d) soon(d or 0) end

local ev = CreateFrame("Frame")
for _, e in ipairs({ "PLAYER_LOGIN", "PLAYER_ENTERING_WORLD", "ZONE_CHANGED_NEW_AREA", "ZONE_CHANGED", "ZONE_CHANGED_INDOORS",
  "QUEST_LOG_UPDATE", "QUEST_TURNED_IN", "SKILL_LINES_CHANGED", "PLAYER_REGEN_DISABLED", "PLAYER_REGEN_ENABLED" }) do
  pcall(ev.RegisterEvent, ev, e)
end
ev:SetScript("OnEvent", function(_, event)
  if event == "PLAYER_LOGIN" then
    K.combat = InCombatLockdown() and true or false
    -- po pasku tempa (GrimuarSetup Events.lua tworzy go 3 s po wejsciu)
    C_Timer.After(5, function()
      local ok, e = pcall(build)
      if not ok then logErr("kompas/build", e) return end
      apply()
      -- 15.11 (R30 P01): krok i cel Polestara odswiezaja kompas od razu (Hub\PolestarSzyna.lua); zegar zostaje jako zapas
      C_Timer.NewTicker(5, function() soon(0) end)
      C_Timer.After(5, function() pcall(anchorHud) end)
    end)
  elseif event == "PLAYER_REGEN_DISABLED" then
    K.combat = true
    apply()
  elseif event == "PLAYER_REGEN_ENABLED" then
    K.combat = false
    apply()
  elseif event == "PLAYER_ENTERING_WORLD" or event == "ZONE_CHANGED_NEW_AREA" then
    apply()
    soon(1)
  else
    soon(event == "QUEST_LOG_UPDATE" and 1.5 or 0.5)
  end
end)
