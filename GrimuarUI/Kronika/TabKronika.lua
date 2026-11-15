-- Grimuar UI: zakladka Kronika (14.11, R24 P1/P2/P4/P5/P12). Trzy strony:
-- * Sesje: lista sesji (ta i poprzednie) i szczegoly: czas, poziomy, zadania, zgony, lupy z wartoscia, rachunki;
-- * Tydzien: ranga Grimuara, kontrakty dnia i tygodnia z postepem, suma ostatnich 7 dni;
-- * Kalendarz: swieta i Jarmark (kalendarz gry) oraz terminy Grimuara.
-- Dane: KronikaDane.lua, KronikaKontrakty.lua, KronikaKalendarz.lua. Tylko odczyt i rysowanie.
local ADDON, U = ...
local C = U.C

local S = { page = "sesje", sel = 1, rows = {} }
local L_W = 330
local GOLD, MUTED, OK, TEXT = U.hex(C.gold), U.hex(C.muted), U.hex(C.ok), U.hex(C.text)

local function textPanel(parent)
  local p = U.Panel(parent, 0.86, true)
  p.view = CreateFrame("ScrollFrame", nil, p)
  p.view:SetPoint("TOPLEFT", 20, -18)
  p.view:SetPoint("BOTTOMRIGHT", -16, 16)
  p.child = CreateFrame("Frame", nil, p.view)
  p.child:SetSize(400, 10)
  p.view:SetScrollChild(p.child)
  p.text = U.Para(p.child, 14, 400, C.text)
  p.text:SetPoint("TOPLEFT")
  p.text:SetSpacing(4)
  p.view:EnableMouseWheel(true)
  p.view:SetScript("OnMouseWheel", function(self, d)
    local max = math.max(0, p.child:GetHeight() - self:GetHeight())
    self:SetVerticalScroll(math.max(0, math.min(max, self:GetVerticalScroll() - d * 80)))
  end)
  function p:Set(txt)
    local w = math.max(200, (self.view:GetWidth() or 400) - 8)
    self.child:SetWidth(w)
    self.text:SetWidth(w)
    self.text:SetText(txt)
    self.child:SetHeight(self.text:GetStringHeight() + 10)
    self.view:SetVerticalScroll(0)
  end
  return p
end

U.TextPanel = textPanel -- tez dla Ksiegi (TabKsiega.lua)

-- ---------- tekst sesji ----------
local function sessionText(r, isCur)
  if not r then return MUTED .. "Brak zapisanych sesji. Kronika zaczyna się od tej sesji.|r" end
  local L = {}
  local function h(t) L[#L + 1] = "\n" .. GOLD .. t:upper() .. "|r" end
  L[#L + 1] = GOLD .. (isCur and "Ta sesja" or U.fmtDate(r.start)) .. "|r" .. MUTED .. "   od " .. U.fmtDate(r.start) .. " · " .. U.fmtMins(((r.last or time()) - r.start) / 60) .. "|r"
  local lv = (r.level0 and r.level and r.level > r.level0) and (r.level0 .. " → " .. r.level) or tostring(r.level or "?")
  L[#L + 1] = "Poziom " .. lv .. "   ·   zadania " .. (r.nq or 0) .. "   ·   zgony " .. (r.deaths or 0)
    .. ((r.hk or 0) > 0 and ("   ·   zabici z Hordy " .. r.hk) or "") .. ((r.shots or 0) > 0 and ("   ·   zrzuty " .. r.shots) or "")
    -- 15.11 (R30 P26, „Mistrz lotow”): loty w sesji z paska lotu (Hud\Lot.lua: r.loty, r.lotyS)
    .. ((r.loty or 0) > 0 and ("   ·   loty " .. r.loty .. " (" .. U.fmtMins((r.lotyS or 0) / 60) .. ")") or "")
  if r.zone then L[#L + 1] = MUTED .. "Ostatnio: " .. r.zone .. "|r" end
  -- rachunki
  local inc, out, net = {}, {}, 0
  for k, v in pairs(r.money or {}) do
    net = net + v
    if v > 0 then inc[#inc + 1] = { k, v } elseif v < 0 then out[#out + 1] = { k, v } end
  end
  table.sort(inc, function(a, b) return a[2] > b[2] end)
  table.sort(out, function(a, b) return a[2] < b[2] end)
  h("Złoto: " .. U.money(net, true))
  if #inc == 0 and #out == 0 then L[#L + 1] = MUTED .. "Bez zmian w złocie.|r" end
  for _, e in ipairs(inc) do L[#L + 1] = OK .. U.money(e[2], true) .. "|r  " .. (U.MONEY_PL[e[1]] or e[1]) end
  for _, e in ipairs(out) do L[#L + 1] = U.hex(C.danger) .. U.money(e[2]) .. "|r  " .. (U.MONEY_PL[e[1]] or e[1]) end
  -- lupy
  h("Łupy: ok. " .. U.money(r.lootV or 0))
  local top = U.kronikaTop(r, 10)
  if #top == 0 then L[#L + 1] = MUTED .. "Nic poza szarymi rzeczami.|r" end
  for _, e in ipairs(top) do
    L[#L + 1] = U.itemLabel(e.id) .. (e.n > 1 and (" ×" .. e.n) or "") .. MUTED .. "  — " .. U.money(e.v) .. "|r"
  end
  L[#L + 1] = MUTED .. "Wartość: cena z domu aukcyjnego (Auctionator), a bez niej cena u kupca.|r"
  -- zadania, poziomy, lochy
  if #(r.quests or {}) > 0 then
    h("Oddane zadania (" .. (r.nq or #r.quests) .. ")")
    L[#L + 1] = table.concat(r.quests, " · ")
  end
  if #(r.levels or {}) > 0 then
    local t = {}
    for _, e in ipairs(r.levels) do t[#t + 1] = e[1] .. " (" .. date("%H:%M", e[2]) .. ")" end
    h("Awanse")
    L[#L + 1] = table.concat(t, " · ")
  end
  if #(r.dungeons or {}) > 0 then h("Lochy") L[#L + 1] = table.concat(r.dungeons, " · ") end
  -- 14.11 (R25 G5): wspolne wyprawy tej sesji (WyprawyDane.lua)
  if #(r.runs or {}) > 0 then
    h("Wyprawy z drużyną")
    for _, w in ipairs(r.runs) do
      L[#L + 1] = w.name .. MUTED .. " · " .. U.fmtMins(w.mins) .. " · bossowie " .. #(w.bosses or {}) ..
        (#(w.members or {}) > 0 and (" · z: " .. table.concat(w.members, ", ")) or "") .. "|r"
    end
  end
  return table.concat(L, "\n")
end

local function sessions()
  if U.kronikaSave then pcall(U.kronikaSave) end
  local s = U.kronika and U.kronika() or { list = {} }
  local out = {}
  if s.cur then out[#out + 1] = { r = s.cur, cur = true } end
  for i = #s.list, 1, -1 do out[#out + 1] = { r = s.list[i] } end
  return out
end

local function row(i)
  local r = S.rows[i]
  if r then return r end
  r = CreateFrame("Button", nil, S.list)
  r:SetHeight(48)
  local hl = r:CreateTexture(nil, "HIGHLIGHT") hl:SetAllPoints() hl:SetColorTexture(1, 1, 1, 0.05)
  r.sel = r:CreateTexture(nil, "BACKGROUND") r.sel:SetAllPoints() r.sel:SetColorTexture(C.gold[1], C.gold[2], C.gold[3], 0.10)
  r.t = U.Text(r, 14, "body", C.text) r.t:SetPoint("TOPLEFT", 10, -6)
  r.s = U.Text(r, 11, "body", C.muted) r.s:SetPoint("TOPLEFT", r.t, "BOTTOMLEFT", 0, -4)
  r:SetScript("OnClick", function(self) S.sel = self.i U.kronikaRefresh() end)
  S.rows[i] = r
  return r
end

local function drawSesje()
  local list = sessions()
  if S.sel > #list then S.sel = 1 end
  local w = L_W - 28
  for i, e in ipairs(list) do
    local r = row(i)
    r.i = i
    r:SetWidth(w)
    r:ClearAllPoints()
    r:SetPoint("TOPLEFT", S.list, "TOPLEFT", 0, -(i - 1) * 50)
    local net = 0
    for _, v in pairs(e.r.money or {}) do net = net + v end
    r.t:SetText(e.cur and "Ta sesja" or U.fmtDate(e.r.start))
    U.Color(r.t, e.cur and C.gold or C.text)
    local lv = (e.r.level0 and e.r.level and e.r.level > e.r.level0) and ("poz. " .. e.r.level0 .. "→" .. e.r.level) or ("poz. " .. tostring(e.r.level or "?"))
    r.s:SetText(U.fmtMins(((e.r.last or time()) - e.r.start) / 60) .. " · " .. lv .. " · " .. U.money(net, true))
    r.sel:SetShown(i == S.sel)
    r:Show()
  end
  for i = #list + 1, #S.rows do S.rows[i]:Hide() end
  S.list:SetHeight(math.max(10, #list * 50))
  local e = list[S.sel]
  S.det:Set(sessionText(e and e.r, e and e.cur))
end

-- ---------- tydzien (15.11 gracz: „to tez jakos lepiej niz jak tekst z notatnika”: karty z paskami, kafelki) ----------
local KIND_ICON = {
  quest = "Interface\\Icons\\INV_Misc_Note_01", level = "Interface\\Icons\\Spell_ChargePositive",
  income = "Interface\\Icons\\INV_Misc_Coin_01", skill = "Interface\\Icons\\Trade_Engineering",
  boss = "Interface\\Icons\\INV_Misc_Bone_HumanSkull_01", hk = "Interface\\Icons\\INV_BannerPVP_02",
  inn = "Interface\\Icons\\Spell_Nature_Sleep",
}
local function drawWeek(p)
  p:Begin(S.drawn == "tydzien")
  S.drawn = "tydzien"
  local st = U.contractsState and U.call(U.contractsState)
  if st then
    local pts = st.pts or 0
    local rank, nxt, left, from, to = U.contractRank(pts)
    p:Cards({ {
      title = "Ranga: " .. rank, right = pts .. " pkt", icon = "Interface\\Icons\\INV_Misc_Book_11", col = C.gold,
      sub = nxt and ("do rangi " .. nxt .. ": jeszcze " .. left .. " pkt") or "najwyższa ranga",
      frac = (to and to > (from or 0)) and ((pts - (from or 0)) / (to - (from or 0))) or 1,
    } }, { cols = 1, maxW = 640 })
    local d = U.num(U.call(C_DateAndTime and C_DateAndTime.GetSecondsUntilDailyReset))
    local w = U.num(U.call(C_DateAndTime and C_DateAndTime.GetSecondsUntilWeeklyReset))
    for _, part in ipairs({ { st.daily, "Kontrakty dnia", 10, d }, { st.weekly, "Kontrakty tygodnia", 30, w } }) do
      local list, ndone = {}, 0
      for _, c in ipairs(part[1] or {}) do
        local money = c.kind == "income"
        local have, need = U.num(c.have) or 0, U.num(c.need) or 1
        if c.done then ndone = ndone + 1 end
        list[#list + 1] = {
          title = (U.contractText and U.contractText(c)) or c.text, icon = KIND_ICON[c.kind], done = c.done,
          right = c.done and ("+" .. part[3] .. " pkt") or ((money and U.money(have) or tostring(have)) .. " / " .. (money and U.money(need) or tostring(need))),
          frac = math.min(1, have / math.max(1, need)),
        }
      end
      p:Head(part[2], ndone .. " z " .. #list .. " · po " .. part[3] .. " pkt" .. (part[4] and (" · nowe za " .. U.inText(part[4])) or ""))
      p:Cards(list)
    end
  end
  -- 14.11 (R26 P1.3): wspolne wyprawy (WyprawyDane.lua) tu, nie w Wyprawach
  local runs = U.expeditionRuns and U.call(U.expeditionRuns) or {}
  if #runs > 0 then
    p:Head("Wspólne wyprawy", #runs .. " razem")
    local list, with = {}, {}
    for i = #runs, 1, -1 do
      local r = runs[i]
      for _, m in ipairs(r.members or {}) do with[m] = (with[m] or 0) + 1 end
      if #runs - i < 8 then
        list[#list + 1] = { title = r.name, right = U.fmtDate(r.start),
          sub = U.fmtMins(r.mins) .. " · bossowie " .. #(r.bosses or {}) .. (#(r.members or {}) > 0 and (" · z: " .. table.concat(r.members, ", ")) or "") }
      end
    end
    p:Cards(list, { minW = 380 })
    local tt = {}
    for m, n in pairs(with) do tt[#tt + 1] = m .. " " .. n end
    if #tt > 0 then p:Para("Najczęściej z: " .. table.concat(tt, " · "), C.muted, 12) end
  end
  -- suma 7 dni
  local s = U.kronika and U.kronika() or { list = {} }
  local since = time() - 7 * 86400
  local mins, nq, money, loot, lv0, lv1, n = 0, 0, 0, 0, nil, nil, 0
  local all = {}
  for _, r in ipairs(s.list or {}) do all[#all + 1] = r end
  if s.cur then all[#all + 1] = s.cur end
  for _, r in ipairs(all) do
    if (r.start or 0) >= since then
      n = n + 1
      mins = mins + ((r.last or time()) - r.start) / 60
      nq = nq + (r.nq or 0)
      loot = loot + (r.lootV or 0)
      for _, v in pairs(r.money or {}) do money = money + v end
      if r.level0 and (not lv0 or r.level0 < lv0) then lv0 = r.level0 end
      if r.level and (not lv1 or r.level > lv1) then lv1 = r.level end
    end
  end
  p:Head("Ostatnie 7 dni")
  local lvTxt = (lv0 and lv1 and lv1 > lv0) and (lv0 .. "–" .. lv1) or tostring(lv1 or lv0 or "?")
  p:Stats({
    { n, n == 1 and "sesja" or "sesje" }, { U.fmtMins(mins), "czas gry" }, { lvTxt, "poziom" }, { nq, "oddane zadania" },
    { U.money(money, true), "złoto", money > 0 and C.ok or (money < 0 and C.danger or C.text) }, { U.money(loot), "łupy (wartość)" },
  })
  p:End()
end

-- ---------- kalendarz: kartki z data i karty terminow ----------
local function drawCal(p)
  p:Begin(S.drawn == "kalendarz")
  S.drawn = "kalendarz"
  local ev = U.calendarEvents and U.call(U.calendarEvents) or {}
  p:Head("Wydarzenia", "najbliższe 30 dni")
  if #ev == 0 then p:Para("W najbliższych 30 dniach nic. (Kalendarz gry wczytuje się kilkanaście sekund po wejściu.)", C.muted, 12) end
  p:Events(ev)
  p:Head("Terminy Grimuara")
  local list = {}
  for _, x in ipairs(U.grimuarTimers and U.call(U.grimuarTimers) or {}) do
    list[#list + 1] = { title = x.title, right = x.right, sub = x.text, frac = x.frac, icon = x.icon, col = x.col }
  end
  p:Cards(list, { minW = 360 })
  p:End()
end

-- ---------- uklad ----------
local function show(p)
  S.page = p
  for k, b in pairs(S.tabs) do
    U.Color(b.label, k == p and C.gold or C.muted)
    U.BorderColor(b, k == p and C.gold or C.edge)
  end
  S.left:SetShown(p == "sesje")
  S.det:SetShown(p == "sesje")
  S.blk:SetShown(p ~= "sesje")
  S.drawn = nil
  C_Timer.After(0, function() pcall(U.kronikaRefresh) end)
end

function U.kronikaRefresh()
  if not (S.body and S.body:IsVisible()) then return end
  if S.page == "sesje" then drawSesje()
  elseif S.page == "tydzien" then drawWeek(S.blk)
  else drawCal(S.blk) end
end

local function build(page)
  S.tabs = {}
  local prev
  for _, d in ipairs({ { "sesje", "Sesje" }, { "tydzien", "Tydzień i kontrakty" }, { "kalendarz", "Kalendarz" } }) do
    local b = U.Button(page, d[2], nil, 30)
    if prev then b:SetPoint("LEFT", prev, "RIGHT", 8, 0) else b:SetPoint("TOPLEFT", page, "TOPLEFT", 0, 0) end
    b:SetScript("OnClick", function() show(d[1]) end)
    S.tabs[d[1]] = b
    prev = b
  end
  S.body = CreateFrame("Frame", nil, page)
  S.body:SetPoint("TOPLEFT", 0, -44)
  S.body:SetPoint("BOTTOMRIGHT")
  S.left = U.Panel(S.body, 0.86, true)
  S.left:SetPoint("TOPLEFT") S.left:SetPoint("BOTTOMLEFT") S.left:SetWidth(L_W)
  local h = U.H2(S.left, "Sesje")
  h:SetPoint("TOPLEFT", 16, -14)
  local view = CreateFrame("ScrollFrame", nil, S.left)
  view:SetPoint("TOPLEFT", h, "BOTTOMLEFT", 0, -10)
  view:SetPoint("BOTTOMRIGHT", -12, 12)
  S.list = CreateFrame("Frame", nil, view)
  S.list:SetSize(L_W - 28, 10)
  view:SetScrollChild(S.list)
  view:EnableMouseWheel(true)
  view:SetScript("OnMouseWheel", function(self, d)
    local max = math.max(0, S.list:GetHeight() - self:GetHeight())
    self:SetVerticalScroll(math.max(0, math.min(max, self:GetVerticalScroll() - d * 100)))
  end)
  S.det = textPanel(S.body)
  S.det:SetPoint("TOPLEFT", S.left, "TOPRIGHT", 20, 0)
  S.det:SetPoint("BOTTOMRIGHT", S.body, "BOTTOMRIGHT", 0, 0)
  S.blk = U.Blocks(S.body)
  S.blk:SetPoint("TOPLEFT", S.body, "TOPLEFT", 0, 0)
  S.blk:SetPoint("BOTTOMRIGHT", S.body, "BOTTOMRIGHT", 0, 0)
  show(S.page)
end

U.RegisterTab({
  id = "kronika", order = 7.5, title = "Kronika", keys = "",
  hints = { { { "LPM" }, "Wybierz sesję" } },
  note = "Łupy, rachunki, kontrakty i kalendarz liczą się same",
  build = build,
  refresh = function() C_Timer.After(0, function() pcall(U.kronikaRefresh) end) end,
})

function GrimuarHubKronika() if GrimuarHubOpen then GrimuarHubOpen("kronika") end end
