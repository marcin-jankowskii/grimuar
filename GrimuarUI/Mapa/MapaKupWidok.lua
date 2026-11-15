-- Grimuar UI: „Gdzie kupic” na mapie huba - widok (15.11, gracz: „Powinnismy dodac cos do naszej mapy, zeby latwo
-- mozna bylo szukac, co gdzie kupic”). Obok pola „Szukaj” przelacznik „Kup” (zapamietany w GrimuarUIDB.mapBuy):
-- wlaczony = pole szuka tylko przedmiotow (najpierw te, ktore sprzedaja kupcy), klik albo Enter na przedmiocie = lista
-- kupcow od najblizszego (imie, rola, strefa, czas dojscia Polestara dla 3 najblizszych albo jardy w linii prostej,
-- inny kontynent na koncu, cena i ograniczony zapas, gdy Polestar je zna). Pod polem skroty na jeden klik dla maga
-- (kilof, runa teleportu, torby, reagenty wg poziomu). Na mapie huba znaczniki wszystkich kupcow tego przedmiotu
-- (zloty pierscien uslugi z moneta, Hub\Znaczniki.lua), najblizszy wiekszy z zielonym podpisem. Klik w wiersz albo
-- znacznik: Prowadz po ID mapy (U.mapGuide -> G.wayTo / Polestar Nav.API) i mapa skacze do strefy kupca.
-- Dane: MapaKup.lua. Rysowanie znacznikow wola TabMapa.lua (U.MAP_placeBuy) przy kazdym przerysowaniu mapy.
local ADDON, U = ...
local C = U.C
local G = U.G or {}

local W = { pins = {}, chips = {} }
local COIN = "Interface\\Icons\\INV_Misc_Coin_01"
local WHY = { level = "za niski poziom", reputation = "wymaga reputacji", profession = "wymaga profesji", retired = "już niedostępne" }
-- skroty: etykieta, przedmioty (jeden = od razu kupcy, kilka = wybor), opis w dymku
local CHIPS = {
  { label = "Kilof", ids = function() return { 2901 } end, tip = "Mining Pick: bez niego nie wydobędziesz rudy." },
  { label = "Runa teleportu", ids = function() return { 17031 } end, tip = "Rune of Teleportation: teleport maga do miasta (od 20. poziomu)." },
  { label = "Torby", ids = function() return { 4497, 4498, 4496 } end, tip = "Torby u kupca: 10, 8 i 6 miejsc." },
  { label = "Reagenty", ids = function()
      local l = UnitLevel("player") or 1
      local t = { 17056 }
      if l >= 40 then t[#t + 1] = 17032 end
      if l >= 56 then t[#t + 1] = 17020 end
      return t
    end, tip = "Light Feather (Slow Fall), od 40 Rune of Portals, od 56 Arcane Powder." },
}

local function tr(s) return (G.tr and type(s) == "string") and G.tr(s) or s end
local function on() return U.db().mapBuy == true end
U.buyOn = on
local function itemName(id) return U.call(C_Item and C_Item.GetItemNameByID, id) end
local function itemIcon(id) return U.call(C_Item and C_Item.GetItemIconByID, id) or "Interface\\Icons\\INV_Misc_QuestionMark" end
local function vendorsText(n) return n == 1 and "u 1 kupca" or ("u " .. n .. " kupców") end
local function still(q) return W.box ~= nil and (W.box:GetText() or "") == q end
local function loadCodex()
  local X = _G.Polestar and _G.Polestar.Codex
  if X and type(X.Load) == "function" and not InCombatLockdown() then pcall(X.Load) end
end

local function distText(v, i)
  if not v.yards then return W.here and "inny kontynent" or "" end
  local yd = (math.floor(v.yards / 10 + 0.5) * 10) .. " yd"
  local eta = (i <= 3 and G.etaText) and U.call(G.etaText, v.map, v.x, v.y) or nil
  eta = type(eta) == "string" and eta:gsub("^ · ", "") or ""
  return eta ~= "" and (eta .. " (" .. yd .. ")") or yd
end

-- Prowadz do kupca: zawsze ID mapy + wspolrzedne; mapa huba pokazuje strefe kupca
local function go(v, s)
  s = s or v
  if W.api then W.api.close() end
  if not (s.map and s.x and s.y) then U.say("nie znam miejsca: " .. tostring(v.name) .. ".") return end
  if U.mapGuide then U.mapGuide(s.map, s.x / 100, s.y / 100, v.name)
  elseif G.wayTo then pcall(G.wayTo, s.map, s.x, s.y, v.name) end
end

local function tipOf(v)
  local t = { v.name .. ((v.role and v.role ~= "") and (" <" .. v.role .. ">") or ""), (v.zone or "?") .. ((v.yards or not W.here) and "" or " (inny kontynent)") }
  if v.price and v.price > 0 and U.money then t[#t + 1] = "Cena: " .. U.money(v.price) end
  if v.limited then t[#t + 1] = "Ograniczony zapas: kupiec odnawia go co jakiś czas." end
  if #v.spawns > 1 then t[#t + 1] = "Miejsc: " .. #v.spawns .. " (prowadzę do najbliższego)." end
  t[#t + 1] = "Źródło: " .. v.src .. " · klik: Prowadź, mapa skacze do strefy."
  return table.concat(t, "\n")
end

local function vendorItem(v, i)
  local parts = {}
  if v.role and v.role ~= "" then parts[#parts + 1] = v.role end
  parts[#parts + 1] = v.zone or "?"
  local d = distText(v, i)
  if d ~= "" then parts[#parts + 1] = tr(d) end
  if v.price and v.price > 0 and U.money then parts[#parts + 1] = U.money(v.price) end
  if v.limited then parts[#parts + 1] = tr("ograniczony zapas") end
  if v.why then parts[#parts + 1] = tr(WHY[v.why] or "niedostępne") end
  local near = i == 1 and v.yards ~= nil
  return { title = (near and (tr("Najbliżej") .. ": ") or "") .. v.name, sub = table.concat(parts, " · "), icon = COIN,
    col = near and C.ok or (v.yards and C.gold or C.muted), tip = tipOf(v), r = { name = v.name, act = function() go(v) end } }
end

-- lista kupcow przedmiotu (prev = lista, do ktorej wraca „Wroc do wynikow”)
function U.buyShow(id, name, prev, loaded)
  local A = W.api
  if not A then return end
  name = name or itemName(id) or ("przedmiot " .. tostring(id))
  local st = U.psSearchState and U.psSearchState()
  if st == "load" and not loaded then
    A.render({ { head = tr("Gdzie kupić") .. ": " .. name } }, "Ładuję bazę Polestara…")
    C_Timer.After(0.05, function() loadCodex() U.buyShow(id, name, prev, true) end)
    return
  end
  W.pick = id
  local list, raw = U.buyVendors(id)
  W.here = raw.here
  local items = { { head = tr("Gdzie kupić") .. ": " .. name .. " (" .. #list .. ")" } }
  for i, v in ipairs(list) do
    if i > 30 then break end
    items[#items + 1] = vendorItem(v, i)
  end
  if #list == 0 and raw.ps and U.psSourcesView then
    -- nikt nie sprzedaje: „Skad zdobyc” z Polestara (P28)
    return U.psSourcesView(id, name, { render = A.render, close = A.close }, prev)
  end
  if prev then
    items[#items + 1] = { title = "Wróć do wyników", sub = "lista przedmiotów", icon = "Interface\\Icons\\INV_Misc_Map_01",
      r = { act = function() A.render(prev) end } }
  end
  local src = (raw.ps and raw.qs) and "Polestar + Questie" or (raw.ps and "Polestar" or (raw.qs and "Questie" or nil))
  A.render(items, #list == 0 and (src and "Nikt tego nie sprzedaje." or "Bez Polestara i Questie nie znam kupców.")
    or (st == "combat" and "W walce tylko Questie (baza Polestara po walce)." or ("Źródła: " .. src .. " · klik: Prowadź")))
  if U.MAP_placeBuy then pcall(U.MAP_placeBuy) end
end

-- przedmioty jako karty: najpierw te u kupca
local function itemsView(list, note)
  local A = W.api
  local buy, other = {}, {}
  for _, it in ipairs(list) do
    it.n = U.buyCount and U.buyCount(it.id) or 0
    if it.n > 0 then buy[#buy + 1] = it else other[#other + 1] = it end
  end
  local all = {}
  local function add(it)
    local id, name = it.id, it.name
    all[#all + 1] = { title = name, sub = it.n > 0 and tr(vendorsText(it.n)) or "nie sprzedają tego kupcy", icon = itemIcon(id),
      col = (it.quality and U.QUALITY[it.quality]) or C.text, item = id,
      tip = it.n > 0 and "Klik: kupcy od najbliższego i znaczniki na mapie." or "Klik: skąd zdobyć (Polestar).",
      r = { name = name, act = function() U.buyShow(id, name, all) end } }
  end
  if #buy > 0 then all[#all + 1] = { head = "Do kupienia (" .. #buy .. ")" } end
  for _, it in ipairs(buy) do add(it) end
  if #other > 0 then all[#all + 1] = { head = "Nie u kupca (" .. #other .. ")" } end
  for _, it in ipairs(other) do add(it) end
  A.render(all, note or (#all == 0 and "Nic nie znalazłem." or nil))
end

-- tryb Kup: wpisany tekst -> przedmioty (Polestar.Search, bez niego Questie); MapaSzukaj.lua run()
function U.buyRun(raw, loaded)
  local A = W.api
  if not A then return end
  local q = (raw or ""):gsub("^%s+", ""):gsub("%s+$", "")
  if #q < 2 then A.render({}, "Kup: wpisz przedmiot albo kliknij skrót pod polem.") return end
  local st = U.psSearchState and U.psSearchState()
  if st == "load" and not loaded then
    A.render({}, "Ładuję bazę Polestara…")
    C_Timer.After(0.05, function() if still(raw) then loadCodex() U.buyRun(raw, true) end end)
    return
  end
  local list = U.buyItemsPolestar and U.buyItemsPolestar(q)
  if list then return itemsView(list) end
  A.render({}, "Szukam przedmiotów w Questie…")
  U.buyItemsQuestie(q, function(l)
    if not still(raw) then return end
    if not l then A.render({}, "Brak Polestara i Questie: nie mam bazy przedmiotów.") return end
    itemsView(l, st == "combat" and "W walce przedmioty z Questie (Polestar po walce)." or nil)
  end)
end

-- wiersz „Gdzie kupic” w „Skad zdobyc” zwyklego szukania (MapaSzukajPolestar.lua)
function U.buyEntry(id, name, prev)
  local n = U.buyCount and U.buyCount(id) or 0
  if n == 0 then return nil end
  return { title = tr("Gdzie kupić") .. ": " .. tr(vendorsText(n)), sub = "kupcy od najbliższego, znaczniki na mapie", icon = COIN, col = C.ok,
    r = { act = function() W.setBuy(true) U.buyShow(id, name, prev) end } }
end

-- ---------- znaczniki kupcow na mapie huba ----------
local function onHub(s, hub)
  if s.map == hub then return s.x / 100, s.y / 100 end
  if not (C_Map.GetMapPosFromWorldPos and CreateVector2D and U.buyWorld) then return nil end
  local c, wx, wy = U.buyWorld(s.map, s.x, s.y)
  if not c then return nil end
  local ok, m, pos = pcall(C_Map.GetMapPosFromWorldPos, c, CreateVector2D(wx, wy), hub)
  if not (ok and pos and pos.GetXY) or (m and m ~= hub) then return nil end
  local x, y = pos:GetXY()
  x, y = U.num(x), U.num(y)
  if x and y and x >= 0 and x <= 1 and y >= 0 and y <= 1 then return x, y end
end
local function pin(i)
  local p = W.pins[i]
  if p then return p end
  local M = U.MAP
  p = CreateFrame("Button", nil, M.pins)
  p:SetSize(24, 24)
  p:SetFrameLevel(M.pins:GetFrameLevel() + 7)
  p.zn = U.Znacznik(p, 34)
  p.zn:SetPoint("CENTER")
  p.t = U.Text(p, 11, "body", C.text, "OUTLINE")
  p.t:SetPoint("TOP", p, "BOTTOM", 0, -2)
  p.t:SetJustifyH("CENTER")
  p:RegisterForClicks("LeftButtonUp")
  p:SetScript("OnEnter", function(self)
    if not self.v then return end
    U.TT:SetOwner(self, "ANCHOR_RIGHT")
    U.TT:SetText(tipOf(self.v), 1, 1, 1, 1, true)
    U.TT:Show()
  end)
  p:SetScript("OnLeave", function() U.TT:Hide() end)
  p:SetScript("OnClick", function(self) if self.v then go(self.v, self.s) end end)
  W.pins[i] = p
  return p
end
function U.MAP_placeBuy()
  for _, p in ipairs(W.pins) do p:Hide() end
  local M = U.MAP
  if not (W.pick and on() and M and M.art and M.mapID and M.pins and U.buyVendors) then return end
  local list, raw = U.buyVendors(W.pick)
  W.here = raw.here
  local w, h = M.art:GetWidth(), M.art:GetHeight()
  local n = 0
  for i, v in ipairs(list) do
    for _, s in ipairs(v.spawns) do
      local x, y = onHub(s, M.mapID)
      if x and n < 60 then
        n = n + 1
        local p = pin(n)
        local near = i == 1 and v.yards ~= nil
        p.v, p.s = v, s
        p.zn:SetSizeAll(near and 46 or 34)
        p.zn:Set("usluga", { icon = COIN })
        p.t:SetText((near or (M.z or 1) >= 2 or #list <= 6) and v.name or "")
        U.Color(p.t, near and C.ok or C.text)
        p:SetFrameLevel(M.pins:GetFrameLevel() + (near and 8 or 7))
        p:ClearAllPoints()
        p:SetPoint("CENTER", M.art, "TOPLEFT", x * w, -y * h)
        p:Show()
      end
    end
  end
end

-- ---------- przelacznik „Kup” i skroty pod polem (MapaSzukaj.lua mapSearchBuild) ----------
local function paint()
  local b = W.toggle
  if not b then return end
  local v = on()
  U.BorderColor(b, v and C.gold or C.edge)
  b.bg:SetColorTexture(v and C.gold[1] * 0.3 or C.bg[1], v and C.gold[2] * 0.3 or C.bg[2], v and C.gold[3] * 0.3 or C.bg[3], 0.92)
  U.Color(b.t, v and C.gold or C.muted)
  pcall(b.ic.SetDesaturated, b.ic, not v)
  if W.ph then W.ph:SetText(v and "Kup: wpisz przedmiot, np. Mining Pick" or "Szukaj: postać, przedmiot, quest, loch") end
end
function W.setBuy(v)
  U.db().mapBuy = v and true or false
  if not v then W.pick = nil end
  paint()
  if U.MAP_placeBuy then pcall(U.MAP_placeBuy) end
end

local function chipClick(c)
  W.setBuy(true)
  local ids = c.ids()
  if #ids == 1 then
    local name = itemName(ids[1]) or c.label
    W.box:SetText(name)
    return U.buyShow(ids[1], name, nil)
  end
  W.box:SetText("")
  local list = {}
  for _, id in ipairs(ids) do
    list[#list + 1] = { id = id, name = itemName(id) or ("przedmiot " .. id), quality = U.num(U.call(C_Item and C_Item.GetItemQualityByID, id)) }
  end
  itemsView(list)
end

local function tipButton(b, text)
  b:SetScript("OnEnter", function(self)
    U.TT:SetOwner(self, "ANCHOR_BOTTOM")
    U.TT:SetText(text, 1, 1, 1, 1, true)
    U.TT:Show()
  end)
  b:SetScript("OnLeave", function() U.TT:Hide() end)
end

function U.mapBuyBuild(box, ph, api)
  W.box, W.ph, W.api = box, ph, api
  local parent = box:GetParent()
  local b = CreateFrame("Button", nil, parent)
  b:SetSize(76, 32)
  b:SetPoint("LEFT", box, "RIGHT", 6, 0)
  b.bg = b:CreateTexture(nil, "BACKGROUND")
  b.bg:SetAllPoints()
  U.Border(b, C.edge)
  b.ic = b:CreateTexture(nil, "ARTWORK")
  b.ic:SetSize(18, 18)
  b.ic:SetPoint("LEFT", 9, 0)
  b.ic:SetTexture(COIN)
  b.ic:SetTexCoord(0.08, 0.92, 0.08, 0.92)
  b.t = U.Text(b, 14, "title", C.muted)
  b.t:SetPoint("LEFT", b.ic, "RIGHT", 7, 0)
  b.t:SetJustifyV("MIDDLE")
  b.t:SetText("Kup")
  tipButton(b, "Gdzie kupić: pole szuka tylko przedmiotów, klik w przedmiot = kupcy od najbliższego i znaczniki na mapie. Kliknij jeszcze raz, żeby wrócić do zwykłego szukania.")
  b:SetScript("OnClick", function()
    W.setBuy(not on())
    local t = box:GetText() or ""
    if on() or #t >= 2 then api.run() else api.close() end
  end)
  W.toggle = b
  local prev
  for i, c in ipairs(CHIPS) do
    local ch = CreateFrame("Button", nil, parent)
    ch:SetHeight(24)
    ch.bg = U.Rect(ch, C.bg, 0.85)
    ch.bg:SetAllPoints()
    U.Border(ch, C.edge)
    local hl = ch:CreateTexture(nil, "HIGHLIGHT")
    hl:SetAllPoints()
    hl:SetColorTexture(1, 1, 1, 0.08)
    ch.ic = ch:CreateTexture(nil, "ARTWORK")
    ch.ic:SetSize(16, 16)
    ch.ic:SetPoint("LEFT", 5, 0)
    ch.ic:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    ch.ic:SetTexture(itemIcon(c.ids()[1]))
    ch.t = U.Text(ch, 12, "body", C.text)
    ch.t:SetPoint("LEFT", ch.ic, "RIGHT", 5, 0)
    ch.t:SetJustifyV("MIDDLE")
    ch.t:SetText(c.label)
    ch:SetWidth(math.floor((ch.t:GetStringWidth() or 40) + 34))
    local a, rel, ra, x, y = "TOPLEFT", box, "BOTTOMLEFT", 0, -6
    if prev then a, rel, ra, x, y = "LEFT", prev, "RIGHT", 6, 0 end
    ch:SetPoint(a, rel, ra, x, y)
    tipButton(ch, tr("Kup") .. ": " .. tr(c.tip))
    ch:SetScript("OnClick", function() chipClick(c) end)
    W.chips[i] = ch
    prev = ch
  end
  paint()
end

-- ---------- /gr test ----------
U.testChecksExtra = U.testChecksExtra or {}
table.insert(U.testChecksExtra, { "Gdzie kupić: przełącznik Kup i skróty", function()
  if type(U.mapGuide) ~= "function" then error("brak U.mapGuide (Mapa\\TabMapa.lua): bez Prowadź do kupca") end
  if type(U.Znacznik) ~= "function" then error("brak U.Znacznik (Hub\\Znaczniki.lua): bez znaczników kupców") end
  local names = {}
  for _, c in ipairs(CHIPS) do
    for _, id in ipairs(c.ids()) do
      local okI, inst = pcall(C_Item.GetItemInfoInstant, id)
      if not (okI and inst) then error("skrót „" .. c.label .. "”: gra nie zna przedmiotu " .. id) end
      names[#names + 1] = itemName(id) or tostring(id)
    end
  end
  return "tryb Kup: " .. (on() and "włączony" or "wyłączony") .. (W.toggle and "" or " (mapa jeszcze nie otwarta)") ..
    "; skróty: " .. table.concat(names, ", ") .. (W.pick and ("; znaczniki: przedmiot " .. W.pick) or "")
end })
