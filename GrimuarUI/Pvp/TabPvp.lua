-- Grimuar UI: zakladka PvP (15.11, propozycja 5: „zakladka PvP pod Twojego maga”; gracz: „te wszystkie mozesz zrobic”).
-- Karty zamiast tekstu (Hub\Bloki.lua), wszystko tylko do podgladu:
-- * kafelki: honorowe zabojstwa dzis i lacznie, honor, ranga, bilans ze Spy (swiat);
-- * kolejka: pola bitew, na ktore czekasz albo na ktorych jestes (GetBattlefieldStatus), z czasem oczekiwania;
-- * pola bitew Forever z poziomem wejscia (odblokowane / od poziomu N) i rola maga;
-- * ostatnie mecze: zapis po kazdym polu bitwy (zwyciezca i Twoj wiersz tabeli wynikow) w GrimuarUIDB.pvpMecze;
-- * matchupy: rada na kazda klase (build: G.BD.pvp / pvp60 od 40), wynik 1v1 z bety i Twoj bilans z ta klasa ze Spy;
-- * zasady i nagrody (te same co na stronie PvP Grimuara).
local ADDON, U = ...
local G = U.G or {}
local C = U.C

local S = {}
local CLS = { "WARRIOR", "ROGUE", "PALADIN", "HUNTER", "SHAMAN", "DRUID", "PRIEST", "WARLOCK", "MAGE" }
local BETA = { WARRIOR = "67%", ROGUE = "65%", PALADIN = "56%", HUNTER = "47%", SHAMAN = "47%", DRUID = "43%", PRIEST = "40%", WARLOCK = "26%" }
local BGS = {
  { "Warsong Gulch", 10, "10 na 10, flaga", "Spowalniaj nosiciela wroga (Frostbolt, Nova, Cone of Cold), swojego chroń: Nova na goniących, owca na healera." },
  { "Arathi Basin", 20, "15 na 15, 5 baz", "Broń bazy: Nova na wchodzących, Counterspell na healera. Każde trafienie przerywa przejmowanie flagi." },
  { "Darkspear Islands", 30, "15 na 15, 4 punkty i flaga", "Portal w Northwatch. Na mostach Nova, wpadnięcie do wody zabija." },
  { "Alterac Valley", 51, "40 na 40, bunkry i wieże", "Blizzard na zbitych w przejściach, Counterspell na healerów." },
}
local RULES = {
  { "Kontrola najpierw", "Counterspell na leczenie albo Fear, owca na drugiego (focus). Owcy nie bij." },
  { "Bij, gdy masz przewagę", "Wojownik i łotrzyk na Twoim poziomie tak; czarnoksiężnik, kapłan, druid i wyższe poziomy: Nova, Blink, za przeszkodę." },
  { "Tarcza w strefie spornej", "Ice Barrier zawsze (od 40). Pij tylko w bezpiecznym miejscu." },
  { "Ratunek", "Ice Block na burst albo ogłuszenie, Cold Snap odnawia Block i Novę." },
  { "Ktoś Cię ciągle zabija", "Nie wracaj w to samo miejsce: Hearthstone, inna strefa albo zaproszenie do grupy (inna warstwa)." },
}
local LOOT = {
  { "Free Action Potion", "od 20: 30 s odporności na ogłuszenie i spowolnienie. Najważniejsza mikstura PvP.", 5634 },
  { "Lieutenant Commander's Regalia", "od 55 za honor: z 4 częściami Blink odnawia się 1,5 s szybciej.", nil },
  { "Rangi", "R2 to trinket PvP, R5 mikstury bojowe. Rangi z pól bitew i questów PvP, reset co sezon.", nil },
}

local function db() return U.db() end
local function n(v) return U.num(v) or 0 end
local function classIcon(t) return "Interface\\Icons\\ClassIcon_" .. (t:sub(1, 1) .. t:sub(2):lower()) end
local function clock(sec)
  sec = math.max(0, math.floor(n(sec)))
  return string.format("%d:%02d", math.floor(sec / 60), sec % 60)
end

-- ---------- dane ----------
local function honorStats()
  local out = {}
  local okS, hkToday = pcall(GetPVPSessionStats)
  local okL, hkAll = pcall(GetPVPLifetimeStats)
  out[#out + 1] = { okS and n(hkToday) or "—", "zabójstw dziś" }
  out[#out + 1] = { okL and n(hkAll) or "—", "zabójstw łącznie" }
  local honor
  pcall(function()
    if C_CurrencyInfo and C_CurrencyInfo.GetCurrencyInfo and Constants and Constants.CurrencyConsts and Constants.CurrencyConsts.HONOR_CURRENCY_ID then
      local i = C_CurrencyInfo.GetCurrencyInfo(Constants.CurrencyConsts.HONOR_CURRENCY_ID)
      honor = i and i.quantity
    end
    if not honor and GetHonorCurrency then honor = GetHonorCurrency() end
  end)
  out[#out + 1] = { honor and n(honor) or "—", "honor" }
  local rankName
  pcall(function()
    local r = UnitPVPRank and UnitPVPRank("player")
    if r and r > 0 and GetPVPRankInfo then rankName = GetPVPRankInfo(r, "player") end
  end)
  out[#out + 1] = { rankName or "bez rangi", "ranga", rankName and C.gold or C.muted }
  local list = U.rivalsList and U.rivalsList()
  if list then
    local w, l = 0, 0
    for _, r in ipairs(list) do w, l = w + r.wins, l + r.loses end
    out[#out + 1] = { w .. "–" .. l, "świat: wygrane–przegrane (Spy)", w >= l and C.ok or C.danger }
  end
  return out
end

local function queueCards()
  local out = {}
  local max = n(U.call(GetMaxBattlefieldID)) > 0 and n(U.call(GetMaxBattlefieldID)) or 3
  for i = 1, max do
    local ok, status, map = pcall(GetBattlefieldStatus, i)
    if ok and status and status ~= "none" then
      local c = { title = map or "Pole bitwy" }
      if status == "queued" then
        local waited = n(U.call(GetBattlefieldTimeWaited, i)) / 1000
        local est = n(U.call(GetBattlefieldEstimatedWaitTime, i)) / 1000
        c.right = "czekasz " .. clock(waited)
        c.sub = est > 0 and ("szacunkowo " .. clock(est)) or "szacunkowo: brak danych"
        if est > 0 then c.frac = math.min(1, waited / est) end
      elseif status == "confirm" then
        c.right, c.col, c.sub = "wejście gotowe", C.ok, "Wejdź przez okienko gry (masz na to chwilę)."
      elseif status == "active" then
        c.right, c.col = "trwa", C.gold
      else
        c.right = status
      end
      out[#out + 1] = c
    end
  end
  return out
end

local function bgCards()
  local lvl = UnitLevel("player") or 1
  local out = {}
  for _, b in ipairs(BGS) do
    local open = lvl >= b[2]
    out[#out + 1] = { title = b[1], right = open and "dostępne" or ("od " .. b[2] .. " poziomu"), rightCol = open and C.ok or C.muted,
      sub = b[3], tip = b[4], done = open, frac = open and 1 or math.min(1, lvl / b[2]) }
  end
  return out
end

local function matchCards()
  local lvl = UnitLevel("player") or 1
  local adv = (G.BD and ((lvl >= 40 and next(G.BD.pvp60 or {})) and G.BD.pvp60 or G.BD.pvp)) or {}
  local spyBy = {}
  for _, r in ipairs((U.rivalsList and U.rivalsList()) or {}) do
    if r.cls then
      local e = spyBy[r.cls] or { 0, 0 }
      e[1], e[2] = e[1] + r.wins, e[2] + r.loses
      spyBy[r.cls] = e
    end
  end
  local out = {}
  for _, t in ipairs(CLS) do
    local a = adv[t]
    if a then
      local tip = a
      local name, rest = a:match("^([^:]+):%s*(.+)$")
      local sb = spyBy[t]
      out[#out + 1] = { title = (U.CLASS_PL and U.CLASS_PL[t]) or name or t, icon = classIcon(t),
        right = (BETA[t] and ("1v1 z bety " .. BETA[t]) or "") .. (sb and ("   Ty " .. sb[1] .. "–" .. sb[2]) or ""),
        sub = rest or a, tip = tip }
    end
  end
  return out
end

-- ---------- zapis meczu ----------
local function myScore()
  local me = UnitName("player")
  for i = 1, n(U.call(GetNumBattlefieldScores)) do
    local row
    if C_PvP and C_PvP.GetScoreInfo then
      local ok, s = pcall(C_PvP.GetScoreInfo, i)
      if ok and type(s) == "table" and s.name and (s.name == me or s.name:match("^([^-]+)") == me) then
        row = { kb = s.killingBlows, hk = s.honorableKills, deaths = s.deaths, honor = s.honorGained, dmg = s.damageDone, heal = s.healingDone }
      end
    end
    if not row then
      local ok, name, kb, hk, deaths, honor, _, _, _, _, _, dmg, heal = pcall(GetBattlefieldScore, i)
      if ok and name and (name == me or tostring(name):match("^([^-]+)") == me) then
        row = { kb = kb, hk = hk, deaths = deaths, honor = honor, dmg = dmg, heal = heal }
      end
    end
    if row then return row end
  end
end
local function recordMatch()
  local winner = U.call(GetBattlefieldWinner)
  if winner == nil or S.recorded then return end
  S.recorded = true
  local mine = (UnitFactionGroup("player") == "Horde") and 0 or 1
  local d = db()
  d.pvpMecze = d.pvpMecze or {}
  local row = myScore() or {}
  local inst = select(1, GetInstanceInfo())
  table.insert(d.pvpMecze, 1, { at = date("%Y-%m-%d %H:%M"), map = inst or GetZoneText() or "?", win = (winner == mine),
    kb = n(row.kb), hk = n(row.hk), deaths = n(row.deaths), honor = n(row.honor), dmg = n(row.dmg), heal = n(row.heal) })
  while #d.pvpMecze > 30 do table.remove(d.pvpMecze) end
end
local function matchHistory()
  local out = {}
  for i, m in ipairs(db().pvpMecze or {}) do
    if i > 8 then break end
    out[#out + 1] = { title = m.map .. (m.win and " · wygrana" or " · przegrana"), right = m.at:sub(6), col = m.win and C.ok or C.danger,
      sub = "zabójstwa " .. m.kb .. " · honorowe " .. m.hk .. " · zgony " .. m.deaths ..
        (m.dmg > 0 and (" · obrażenia " .. (m.dmg >= 1000 and (math.floor(m.dmg / 100) / 10 .. " tys.") or m.dmg)) or "") ..
        (m.honor > 0 and (" · honor +" .. m.honor) or "") }
  end
  return out
end

-- ---------- rysowanie ----------
local function draw()
  local p = S.p
  if not p then return end
  p:Begin(true)
  p:Title("PvP", "Mag na serwerze PvP: pola bitew, rywale ze świata i plan na każdą klasę.")
  p:Stats(honorStats(), { minW = 140 })
  local q = queueCards()
  if #q > 0 then p:Head("Kolejka") p:Cards(q, { minW = 320 }) end
  p:Head("Pola bitew", "kolejka u battlemastera w Stormwind Keep · aren w Forever nie ma")
  p:Cards(bgCards(), { minW = 300 })
  local h = matchHistory()
  p:Head("Ostatnie mecze", #h > 0 and ("zapisane: " .. #(db().pvpMecze or {})) or nil)
  if #h > 0 then p:Cards(h, { minW = 340 }) else p:Para("Po pierwszym polu bitwy zobaczysz tu wynik i swoje statystyki.", C.muted, 12) end
  local mc = matchCards()
  if #mc > 0 then
    p:Head("Na każdą klasę", (UnitLevel("player") or 1) >= 40 and "rady od 40 poziomu" or "rady do 40 poziomu")
    p:Cards(mc, { minW = 360 })
  end
  local rv = U.rivalsList and U.rivalsList()
  if rv and #rv > 0 then
    local cards = {}
    for i, r in ipairs(rv) do
      if i > 6 or not r.rival then break end
      cards[#cards + 1] = { title = r.name, icon = r.cls and classIcon(r.cls) or nil, right = r.wins .. "–" .. r.loses, rightCol = r.wins >= r.loses and C.ok or C.danger,
        sub = (r.clsPl or "") .. (r.level and (" · poziom " .. r.level) or "") .. (r.kos and " · zabij od razu" or ""), tip = U.rivalTip and U.rivalTip(r) or nil }
    end
    if #cards > 0 then p:Head("Rywale", "pełna lista: Księga > Rywale") p:Cards(cards, { minW = 280 }) end
  end
  local rc = {}
  for _, r in ipairs(RULES) do rc[#rc + 1] = { title = r[1], sub = r[2], tip = r[2] } end
  p:Head("Zasady")
  p:Cards(rc, { minW = 360 })
  local lc = {}
  for _, l in ipairs(LOOT) do lc[#lc + 1] = { title = l[1], sub = l[2], tip = l[2], icon = l[3] and U.call(C_Item and C_Item.GetItemIconByID, l[3]) or nil } end
  p:Head("Nagrody i mikstury")
  p:Cards(lc, { minW = 360 })
  p:End()
end

local function safeDraw()
  local ok, err = pcall(draw)
  if not ok and U.logError then U.logError("pvp", err) end
end

local function build(page)
  S.p = U.Blocks(page)
  S.p:SetPoint("TOPLEFT", 24, -12)
  S.p:SetPoint("BOTTOMRIGHT", -24, 12)
end

local ev = CreateFrame("Frame")
for _, e in ipairs({ "UPDATE_BATTLEFIELD_STATUS", "UPDATE_BATTLEFIELD_SCORE", "PLAYER_ENTERING_WORLD", "PLAYER_PVP_KILLS_CHANGED",
  "HONOR_CURRENCY_UPDATE" }) do pcall(ev.RegisterEvent, ev, e) end
ev:SetScript("OnEvent", function(_, e)
  if e == "UPDATE_BATTLEFIELD_SCORE" then pcall(recordMatch)
  elseif e == "PLAYER_ENTERING_WORLD" then S.recorded = nil end
  if S.p and S.p:IsVisible() then
    if S.q then return end
    S.q = true
    C_Timer.After(0.5, function() S.q = nil safeDraw() end)
  end
end)

U.RegisterTab({
  id = "pvp", order = 6.7, title = "PvP", keys = "",
  hints = { { { "Najedź" }, "Pełna rada" } },
  note = "Mecze z pól bitew zapisują się same",
  build = build,
  refresh = function() C_Timer.After(0, safeDraw) end,
})
