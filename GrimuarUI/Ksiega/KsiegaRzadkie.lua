-- Grimuar UI: Ksiega > Krainy: rzadkie stwory i skarby wybranej strefy (15.11, R30 P32; gracz: „rzadkie potwory
-- w strefie i alarm”). Dane: Polestar.Rares.ListOf("rare"|"treasure") (Polestar Rares\Pins.lua: rekordy Codexu
-- z poziomem, elita, lupami i miejscami), filtr po mapie spawnu = strefa z Krain (uiMapID). ListOf dekoduje ~470
-- rekordow naraz („tens of milliseconds”), wiec indeks „mapa -> lista” (kopie: nazwa, poziom, elita, do 6 lupow,
-- miejsca w strefie) liczymy raz, przy pierwszym otwarciu Krain, i trzymamy do konca sesji. Codex wczytujemy dopiero
-- tu (Rares.Codex(true), nigdy w walce: wtedy napis i odswiezenie po walce). „Widziany X temu” z Rares.History()
-- (zapis Polestara na realm). Wyglad: naglowek z rombem i karty U.Card (Hub\Bloki.lua) pod tekstem strefy, w karcie
-- lupy jako ikony (dymek przedmiotu, Shift+klik: link). Klik w karte: Prowadz do najblizszego miejsca w strefie
-- (mapa huba i strzalka; ramka Era przez U.psLive). Bez Polestara: cicho nic (tekst Krain jak dotad).
local ADDON, U = ...
local C = U.C
local G = U.G or {}

local R = { idx = nil, loadFailed = false, waitCombat = false }
local pool = {}
local GAP, SLOT, LOOT_MAX, CARD_MIN = 8, 24, 6, 300
local ICON = { rare = "Interface\\Icons\\Ability_Hunter_SniperShot", elite = "Interface\\Icons\\INV_Misc_Head_Dragon_01",
  treasure = "Interface\\Icons\\INV_Misc_Key_03" }

local function PS() return _G.Polestar end
local function tr(s) return (G.tr and type(s) == "string") and G.tr(s) or s end
local function rares()
  local P = PS()
  local Rs = type(P) == "table" and P.Rares
  if Rs and type(Rs.ListOf) == "function" and type(Rs.History) == "function" then return Rs end
end
local function now() return (GetServerTime and GetServerTime()) or time() end
local function ago(t)
  local d = now() - t
  if d < 60 then return "przed chwilą" end
  if d < 3600 then return math.floor(d / 60) .. " min temu" end
  if d < 86400 then return math.floor(d / 3600) .. " h temu" end
  local days = math.floor(d / 86400)
  return days == 1 and "wczoraj" or (days .. " dni temu")
end
U.rareAgo = ago
local function levelText(lo, hi)
  if lo == -1 then return "??" end
  if not lo then return nil end
  if hi and hi ~= lo then return lo .. "–" .. hi end
  return tostring(lo)
end
U.rareLevelText = levelText

-- ---------- indeks: mapa -> { kopie rekordow } ----------
local function index()
  if R.idx then return R.idx end
  local Rs = rares()
  local Cx = PS().Codex
  if not (Cx and type(Cx.IsLoaded) == "function" and U.call(Cx.IsLoaded)) then
    if InCombatLockdown() then return nil, "combat" end
    if R.loadFailed then return nil, "nocodex" end
    return nil, "load"
  end
  local idx = {}
  for _, kind in ipairs({ "rare", "treasure" }) do
    local ok, list = pcall(Rs.ListOf, kind)
    if not ok then return nil, "error" end
    if type(list) ~= "table" then return nil, "nocodex" end
    for _, rec in ipairs(list) do
      if type(rec) == "table" and type(rec.spawns) == "table" then
        local per = {}
        for _, s in ipairs(rec.spawns) do
          local m = type(s) == "table" and U.num(s.map)
          if m and U.num(s.x) and U.num(s.y) then
            local e = per[m]
            if not e then
              e = { kind = kind, id = rec.id, name = rec.name or "?", level = U.num(rec.level), levelMax = U.num(rec.levelMax),
                elite = rec.elite and true or false, loot = {}, spawns = {} }
              local loot = type(rec.loot) == "table" and rec.loot or {}
              for i = 1, math.min(LOOT_MAX, #loot) do e.loot[i] = loot[i] end
              per[m] = e
              idx[m] = idx[m] or {}
              table.insert(idx[m], e)
            end
            e.spawns[#e.spawns + 1] = { map = m, x = s.x, y = s.y, f = s.f }
          end
        end
      end
    end
  end
  for _, list in pairs(idx) do
    table.sort(list, function(a, b)
      if (a.level or 0) ~= (b.level or 0) then return (a.level or 0) < (b.level or 0) end
      return tostring(a.name) < tostring(b.name)
    end)
  end
  R.idx = idx
  return idx
end

local function loadThenRefresh()
  if InCombatLockdown() then R.waitCombat = true return end
  local Rs = rares()
  if not Rs then return end
  local ok, Cx = false, nil
  if type(Rs.Codex) == "function" then ok, Cx = pcall(Rs.Codex, true) end
  if not (ok and Cx) and not InCombatLockdown() and not UnitAffectingCombat("player") then R.loadFailed = true end
  if U.ksiegaRefresh then U.ksiegaRefresh() end
end

-- ---------- widzety z puli (wszystkie dzieci R.box) ----------
local function take(kind, make)
  local P = pool[kind]
  if not P then P = { n = 0 } pool[kind] = P end
  P.n = P.n + 1
  local w = P[P.n]
  if not w then w = make() P[P.n] = w end
  w:ClearAllPoints()
  w:Show()
  return w
end
local function hideAll()
  for _, P in pairs(pool) do
    for i = 1, #P do P[i]:Hide() end
    P.n = 0
  end
end

local function head(y, W, text, right)
  local f = take("head", function()
    local w = CreateFrame("Frame", nil, R.box)
    w:SetHeight(22)
    w.d = U.Diamond(w, 10, C.gold, true) w.d:SetPoint("LEFT", 0, 0)
    w.t = U.Text(w, 14, "title", C.gold) w.t:SetPoint("LEFT", w.d, "RIGHT", 7, 0) w.t:SetJustifyV("MIDDLE")
    w.r = U.Text(w, 11, "body", C.muted) w.r:SetPoint("RIGHT", 0, 0) w.r:SetJustifyH("RIGHT") w.r:SetJustifyV("MIDDLE")
    w.l = U.Line(w, C.edge, 0.5)
    w.l:SetPoint("LEFT", w.t, "RIGHT", 10, 0)
    w.l:SetPoint("RIGHT", w.r, "LEFT", -10, 0)
    return w
  end)
  f:SetPoint("TOPLEFT", R.box, "TOPLEFT", 0, -y)
  f:SetWidth(W)
  f.t:SetText(text)
  f.r:SetText(right or "")
  return y + 30
end
local function para(y, W, text)
  local fs = take("para", function() return U.Para(R.box, 12, 300, C.muted) end)
  fs:SetWidth(W)
  fs:SetText(text)
  fs:SetPoint("TOPLEFT", R.box, "TOPLEFT", 0, -y)
  return y + (fs:GetStringHeight() or 12) + 8
end

local function lootSlot(card, i)
  card.loot = card.loot or {}
  local s = card.loot[i]
  if s then return s end
  s = U.Slot(card, SLOT)
  s:SetScript("OnEnter", function(self)
    U.TT:SetOwner(self, "ANCHOR_RIGHT")
    if not (self.id and pcall(U.TT.SetItemByID, U.TT, self.id)) then U.TT:SetText("przedmiot " .. tostring(self.id)) end
    U.TT:Show()
  end)
  s:SetScript("OnLeave", function() U.TT:Hide() end)
  s:SetScript("OnClick", function(self)
    if not IsShiftKeyDown() then return end
    local _, link = U.call(C_Item and C_Item.GetItemInfo, self.id)
    if link and HandleModifiedItemClick then pcall(HandleModifiedItemClick, link) end
  end)
  card.loot[i] = s
  return s
end

local function guide(e)
  local P = PS()
  local sp = e.spawns[1]
  local okP, me = false, nil
  if P and type(P.PlayerPoint) == "function" then okP, me = pcall(P.PlayerPoint) end
  local Rs = rares()
  if okP and me and Rs and type(Rs.Nearest) == "function" then
    local ok, s = pcall(Rs.Nearest, e.spawns, me)
    if ok and type(s) == "table" then sp = s end
  end
  local m, x, y = sp.map, sp.x, sp.y
  if U.psLive then m, x, y = U.psLive(sp) end
  x, y = U.num(x), U.num(y)
  if not (m and x and y) then U.say("Polestar nie zna miejsca: " .. e.name .. ".") return end
  if U.mapGuide then U.mapGuide(m, x / 100, y / 100, e.name)
  elseif G.wayTo then pcall(G.wayTo, m, x, y, e.name) end
end

local function rareCard(e, h, Rs, x, y, cw, ch)
  local key = (e.kind == "treasure" and "treasure:" or "rare:") .. tostring(e.id)
  local seen = type(h) == "table" and type(h[key]) == "table" and h[key] or nil
  local grey = e.kind == "rare" and e.level and e.level > 0 and type(Rs.GreyLevel) == "function" and
    (U.call(Rs.GreyLevel, UnitLevel("player") or 1) or 0) >= e.level
  local parts = {}
  local lv = levelText(e.level, e.levelMax)
  if e.kind == "treasure" then parts[#parts + 1] = tr("skarb") elseif lv then parts[#parts + 1] = tr("poziom " .. lv) end
  if seen and U.num(seen.t) then
    local dead = U.num(seen.dead) and seen.dead >= seen.t
    parts[#parts + 1] = tr((dead and "zabity " or "widziany ") .. tr(ago(seen.t)))
  end
  local tip = { e.name, (e.kind == "treasure" and "Skarb" or ("Rzadki stwór" .. (lv and (", poziom " .. lv) or "") .. (e.elite and ", elita" or ""))) }
  tip[#tip + 1] = "Miejsc w tej strefie: " .. #e.spawns
  if seen and U.num(seen.t) then tip[#tip + 1] = "Ostatnio widziany: " .. ago(seen.t) .. " (Polestar, ten realm)" end
  if #e.loot > 0 then tip[#tip + 1] = "Łupy: ikony w karcie (dymek przedmiotu)." end
  tip[#tip + 1] = "Klik: Prowadź do najbliższego miejsca (mapa i strzałka Polestar)."
  local f = take("card", function() return U.Card(R.box) end)
  f:Fill({ title = e.name, sub = table.concat(parts, " · "), icon = e.kind == "treasure" and ICON.treasure or (e.elite and ICON.elite or ICON.rare),
    right = grey and "szary" or (e.elite and "elita" or nil), rightCol = grey and C.faint or C.gold,
    col = grey and C.faint or (e.kind == "treasure" and C.gold or (e.elite and C.gold or C.frost)),
    tip = table.concat(tip, "\n"), onClick = function() guide(e) end }, cw, ch)
  f:SetPoint("TOPLEFT", R.box, "TOPLEFT", x, -y)
  for i = 1, math.max(#e.loot, f.loot and #f.loot or 0) do
    local id = e.loot[i]
    if id then
      local s = lootSlot(f, i)
      s:ClearAllPoints()
      s:SetPoint("TOPLEFT", f, "TOPLEFT", 48 + (i - 1) * (SLOT + 4), -50)
      s.id = id
      s.icon:SetTexture(U.call(C_Item and C_Item.GetItemIconByID, id) or 134400)
      local q = U.num(U.call(C_Item and C_Item.GetItemQualityByID, id))
      if not q and C_Item and C_Item.RequestLoadItemDataByID then pcall(C_Item.RequestLoadItemDataByID, id) end
      s:SetQuality(q)
      s.count:SetText("")
      s:Show()
    elseif f.loot and f.loot[i] then
      f.loot[i]:Hide()
    end
  end
end

local function section(y, W, title, list, h, Rs)
  if #list == 0 then return y end
  y = head(y, W, title .. " (" .. #list .. ")", "Polestar")
  local nc = math.max(1, math.floor((W + GAP) / (CARD_MIN + GAP)))
  local cw = math.floor((W - GAP * (nc - 1)) / nc)
  local anyLoot = false
  for _, e in ipairs(list) do if #e.loot > 0 then anyLoot = true end end
  local ch = 53 + (anyLoot and (SLOT + 10) or 0)
  for i, e in ipairs(list) do
    local col, row = (i - 1) % nc, math.floor((i - 1) / nc)
    rareCard(e, h, Rs, col * (cw + GAP), y + row * (ch + GAP), cw, ch)
  end
  return y + math.ceil(#list / nc) * (ch + GAP) + 4
end

-- TabKsiega.lua (Krainy): det = panel szczegolow (U.TextPanel: child, text), ui = uiMapID strefy; nil = schowaj
function U.ksiegaRares(det, ui)
  hideAll()
  if R.box then R.box:Hide() end
  R.waitCombat = false
  if not (det and det.child and det.text and ui) then return end
  local Rs = rares()
  if not Rs then return end
  if not R.box then R.box = CreateFrame("Frame", nil, det.child) end
  local W = math.max(260, math.floor(det.child:GetWidth() or 400))
  local top = math.floor((det.text:GetStringHeight() or 0) + 22)
  R.box:ClearAllPoints()
  R.box:SetPoint("TOPLEFT", det.child, "TOPLEFT", 0, -top)
  R.box:SetWidth(W)
  R.box:Show()
  local y = 0
  local idx, why = index()
  if not idx then
    y = head(y, W, "Rzadkie stwory i skarby", "Polestar")
    if why == "combat" then
      R.waitCombat = true
      y = para(y, W, "W walce baza Polestara się nie ładuje: rzadkie stwory pokażę po walce.")
    elseif why == "load" then
      y = para(y, W, "Ładuję bazę Polestara…")
      C_Timer.After(0.05, function() pcall(loadThenRefresh) end)
    else
      y = para(y, W, "Polestar nie wczytał swojej bazy (addon Polestar_Codex): bez rzadkich stworów.")
    end
  else
    local okH, h = pcall(Rs.History)
    if not okH then h = nil end
    local rs, ts = {}, {}
    for _, e in ipairs(idx[ui] or {}) do
      if e.kind == "treasure" then ts[#ts + 1] = e else rs[#rs + 1] = e end
    end
    if #rs + #ts == 0 then
      y = head(y, W, "Rzadkie stwory i skarby", "Polestar")
      y = para(y, W, "Polestar nie zna rzadkich stworów ani skarbów w tej strefie.")
    else
      y = section(y, W, "Rzadkie stwory", rs, h, Rs)
      y = section(y, W, "Skarby", ts, h, Rs)
    end
  end
  R.box:SetHeight(math.max(1, y))
  det.child:SetHeight(top + y + 10)
end

local ev = CreateFrame("Frame")
ev:RegisterEvent("PLAYER_REGEN_ENABLED")
ev:SetScript("OnEvent", function()
  if R.waitCombat and R.box and R.box:IsVisible() and U.ksiegaRefresh then C_Timer.After(0.5, U.ksiegaRefresh) end
end)

-- ---------- /gr test ----------
U.testChecksExtra = U.testChecksExtra or {}
table.insert(U.testChecksExtra, { "Polestar: rzadkie w Księdze (Rares.ListOf, History)", function()
  local P = PS()
  if type(P) ~= "table" then return "brak Polestara (Krainy bez rzadkich stworów)" end
  local Rs = P.Rares
  if not (Rs and type(Rs.ListOf) == "function") then error("brak Polestar.Rares.ListOf (Rares\\Pins.lua:160)") end
  if type(Rs.History) ~= "function" then error("brak Polestar.Rares.History (Rares\\Rares.lua:143)") end
  for _, fn in ipairs({ "Codex", "Nearest" }) do
    if type(Rs[fn]) ~= "function" then error("brak Polestar.Rares." .. fn .. " (Rares\\Rares.lua)") end
  end
  local ok, h = pcall(Rs.History)
  if not ok then error("History: " .. tostring(h)) end
  if type(h) ~= "table" then error("History zwraca " .. type(h)) end
  local n, last, lastT = 0, nil, 0
  for _, e in pairs(h) do
    n = n + 1
    if type(e) == "table" and (U.num(e.t) or 0) > lastT then last, lastT = e, e.t end
  end
  local zones = 0
  for _ in pairs(R.idx or {}) do zones = zones + 1 end
  return "historia: " .. n .. " wpisów" .. (last and (", ostatni: " .. tostring(last.name) .. " " .. ago(lastT)) or "") ..
    (R.idx and (", indeks: " .. zones .. " stref") or ", indeks policzy pierwsze otwarcie Krain")
end })
