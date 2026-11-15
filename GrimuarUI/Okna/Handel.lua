-- Grimuar UI: Handel z graczem w stylu huba (15.11; gracz: „okna gry, ktore jeszcze nie sa w stylu Grimuara: Mistrz
-- lotow i Handel”). Zamiast okna handlu ForeverSkin (ForeverSkinTradeFrame) albo gry (TradeFrame) okno Grimuara
-- przyczepione i wieksze, wiec je przykrywa (Okna/Wspolne.lua). Okno gry zostaje otwarte pod spodem (przezroczystosc 0):
-- prawy klik w torbie dalej wklada przedmiot, gra pilnuje swoich ostrzezen, zamkniecie handlu konczy wizyte.
-- Dwie kolumny kart: „Ty dajesz” (GetTradePlayerItemInfo/Link, GetPlayerTradeMoney) i „Dostajesz” (GetTradeTargetItemInfo/
-- Link, GetTargetTradeMoney), w naglowku stan akceptacji obu stron (TRADE_ACCEPT_UPDATE). Twoje miejsca: klik albo
-- upuszczenie przedmiotu = ClickTradeButton(i), jak miejsca gry (tak samo wklada wode GrupaLatwo.lua „Daj wode”).
-- Karta „Sprawdz, zanim zaakceptujesz”: dajesz przedmioty warte u kupca > 0, a nic nie dostajesz; wtedy „Akceptuj”
-- trzeba kliknac drugi raz w 5 s (oferta nie moze sie w tym czasie zmienic).
-- Akceptuj i Anuluj: AcceptTrade bywa chronione (ForeverSkin Windows\More.lua z tego powodu naciska przyciski gry), wiec
-- Grimuar sam nie wola AcceptTrade ani CancelTrade: nasze przyciski (InsecureActionButtonTemplate typu „click”, ten sam
-- sposob co ForeverSkin) naciskaja przyciski okna gry TradeFrameTradeButton i TradeFrameCancelButton, a gra robi reszte
-- swoim kodem i na swoich warunkach. Gdyby gra mimo to zablokowala klik (ADDON_ACTION_BLOCKED z Grimuara tuz po nim),
-- zapisujemy to (GrimuarUIDB.handelBlok, do nowej wersji) i od tej pory „Akceptuj” oddaje okno gry.
-- Kwote wpisuje sie tylko w oknie gry (pole kwoty gry jest dla addonow zakazane): „Zmien kwote” oddaje okno gry.
-- W walce zostaje okno gry. Wylaczenie: /hub okna handel.
local ADDON, U = ...
local C = U.C
local G = U.G or {}

local W, H, ROW, SLOTS, ARM = 800, 566, 40, 7, 5
local CW = (W - 44 - 16) / 2
local COL_H = 36 + SLOTS * (ROW + 2) + 40
local S = { acc = { 0, 0 }, armed = nil, armKey = nil, warn = false, pressAt = -100 }
local F

local function money(c) return U.money and U.money(c) or tostring(c) end
local function tr(s) return G.tr and G.tr(s) or s end
local function pub(v) return not (issecretvalue and issecretvalue(v)) end
local function str(v) if type(v) == "string" and pub(v) then return v end return nil end
local function idOf(link) link = str(link) return link and tonumber(link:match("item:(%d+)")) or nil end
local function plural(n, one, few, many)
  if n == 1 then return one end
  local d, h = n % 10, n % 100
  if d >= 2 and d <= 4 and (h < 12 or h > 14) then return few end
  return many
end
local function vendor(id)
  if not id then return 0 end
  local ok, v = pcall(function() return select(11, (C_Item and C_Item.GetItemInfo or GetItemInfo)(id)) end)
  return ok and U.num(v) or 0
end
local function blocked()
  local b = U.db().handelBlok
  return type(b) == "table" and U.version ~= nil and b.version == U.version() or false
end
local function toClassic()
  if not F then return end
  F.classicNow = true
  F:Hide()
  F:HostsAlpha(1)
end

-- ---------- dane ----------
-- przedmiot w miejscu i (side "p" = Ty, "t" = druga strona) albo nil; wartosci sekretne (Midnight) tylko rysowane
local function item(side, i)
  local name, tex, count, quality, ench, id
  local usable = true
  if side == "p" then
    local ok, a, b, c, d, e, _, _, h = pcall(GetTradePlayerItemInfo, i)
    if ok then name, tex, count, quality, ench, id = a, b, c, d, e, h end
  else
    local ok, a, b, c, d, e, f, g = pcall(GetTradeTargetItemInfo, i)
    if ok then
      name, tex, count, quality, ench, id = a, b, c, d, f, g
      usable = not (pub(e) and e == false)
    end
  end
  local link = str(U.call(side == "p" and GetTradePlayerItemLink or GetTradeTargetItemLink, i))
  local has = str(name) or link or (not pub(tex)) or tex ~= nil
  if not has then return nil end
  id = U.num(id) or idOf(link)
  local n = U.num(count) or 1
  return { i = i, name = str(name) or (link and link:match("%[(.-)%]")) or "?", tex = (pub(tex) and tex) or 134400,
    count = n, quality = U.num(quality), ench = str(ench), id = id, link = link, usable = usable,
    value = vendor(id) * math.max(1, n) }
end
local function offer(side)
  local o = { slots = {}, n = 0, value = 0, money = U.num(U.call(side == "p" and GetPlayerTradeMoney or GetTargetTradeMoney)) or 0 }
  local key = {}
  for i = 1, SLOTS do
    local it = item(side, i)
    o.slots[i] = it
    if it and i < SLOTS then o.n = o.n + 1 o.value = o.value + it.value end
    key[#key + 1] = it and (tostring(it.id or it.name) .. "x" .. it.count) or "-"
  end
  key[#key + 1] = tostring(o.money)
  o.key = table.concat(key, ",")
  return o
end
-- oferta teraz: Ty, druga strona, klucz (do „drugiego klikniecia”), ostrzezenie
local function current()
  local p, t = offer("p"), offer("t")
  return p, t, p.key .. "|" .. t.key, p.value > 0 and t.n == 0 and t.money == 0
end
local function sideText(o)
  local parts = {}
  if o.n > 0 then parts[#parts + 1] = tr(o.n .. " " .. plural(o.n, "przedmiot", "przedmioty", "przedmiotów")) end
  if o.money > 0 then parts[#parts + 1] = money(o.money) end
  return #parts > 0 and table.concat(parts, " + ") or tr("nic")
end
-- dlaczego „Akceptuj” nie moze teraz nacisnac przycisku gry (albo nil)
local function blocker()
  if InCombatLockdown() then return "w walce handel zostaje w oknie gry." end
  local b = _G.TradeFrameTradeButton
  if not b then return "brak przycisku handlu gry: zaakceptuj w klasycznym oknie." end
  if S.acc[1] == 1 then return "już zaakceptowałeś: czekasz na drugą stronę." end
  local okE, en = pcall(b.IsEnabled, b)
  if not (okE and pub(en) and en) then return "gra jeszcze nie pozwala zaakceptować (oferta właśnie się zmieniła)." end
  local offered, have = U.num(U.call(GetPlayerTradeMoney)), U.num(U.call(GetMoney))
  if offered and have and offered > have then return "oferujesz więcej pieniędzy, niż masz." end
  return nil
end

-- ---------- rysowanie ----------
local function place(i)
  if InCombatLockdown() then return end
  pcall(ClickTradeButton, i)
  C_Timer.After(0.2, function() pcall(U.handelDraw) end)
end
local function fillRow(r, it, side)
  r.it = it
  r.bg:SetAlpha(r.i == SLOTS and 0.4 or 1)
  r.slot.icon:SetShown(it ~= nil)
  r.why:SetText("")
  if it then
    r.slot.icon:SetTexture(it.tex)
    r.slot:SetQuality(it.quality)
    r.slot.count:SetText(it.count > 1 and it.count or "")
    r.t:SetText(it.name)
    U.Color(r.t, it.usable and (U.QUALITY[it.quality or 1] or C.text) or C.danger)
    local sub = {}
    if r.i == SLOTS then sub[#sub + 1] = tr("nie będzie wymieniony (tylko zaklęcie)") end
    if it.ench then sub[#sub + 1] = it.ench end
    if not it.usable then sub[#sub + 1] = tr("nie możesz tego użyć") end
    r.s:SetText(table.concat(sub, " · "))
    r.r:SetText(it.value > 0 and money(it.value) or "")
  else
    r.slot:SetQuality(nil)
    r.slot.count:SetText("")
    if side == "p" then r.t:SetText(r.i == SLOTS and "miejsce na zaklęcie (nie wymieniane)" or "upuść tu przedmiot")
    else r.t:SetText(r.i == SLOTS and "miejsce na zaklęcie" or "—") end
    U.Color(r.t, C.faint)
    r.s:SetText("")
    r.r:SetText("")
  end
  r.tip = function(tt)
    if it then
      local okT = pcall(side == "p" and tt.SetTradePlayerItem or tt.SetTradeTargetItem, tt, r.i)
      if not okT and it.link then pcall(tt.SetHyperlink, tt, it.link) end
      if it.value > 0 then tt:AddLine(tr("U kupca") .. ": " .. money(it.value), 0.85, 0.71, 0.36) end
    else
      tt:SetText(tr(side == "p" and "Przeciągnij tu przedmiot z torby albo kliknij z przedmiotem na kursorze (prawy klik w torbie też działa)."
        or "Tu pojawi się to, co dostajesz."), 1, 1, 1, 1, true)
    end
  end
  r.onClick = function(button)
    if it and it.link and IsModifiedClick("CHATLINK") then pcall(ChatEdit_InsertLink, it.link) return end
    if it and it.link and IsModifiedClick("DRESSUP") then pcall(DressUpItemLink, it.link) return end
    if side ~= "p" or button ~= "LeftButton" then return end
    if U.call(CursorHasItem) or it then place(r.i) end
  end
end
local function tag(col, accepted)
  col.tag:SetTag(accepted and tr("zaakceptowane") or tr("jeszcze nie"), accepted and C.gold or C.muted)
  U.BorderColor(col, accepted and C.gold or C.line, accepted and 0.9 or 1)
end

local function render()
  local p, t, key, warn = current()
  S.key, S.warn = key, warn
  if S.armed and (GetTime() - S.armed > ARM or S.armKey ~= key) then S.armed = nil end
  for i = 1, SLOTS do
    fillRow(F.colP.rows[i], p.slots[i], "p")
    fillRow(F.colT.rows[i], t.slots[i], "t")
  end
  tag(F.colP, S.acc[1] == 1)
  tag(F.colT, S.acc[2] == 1)
  F.colP.money:SetText(tr("Pieniądze") .. ": " .. money(p.money))
  F.colT.money:SetText(tr("Pieniądze") .. ": " .. money(t.money))
  local c
  if warn then
    c = { title = "Sprawdź, zanim zaakceptujesz", col = C.danger, right = money(p.value), rightCol = C.danger,
      sub = tr("Dajesz rzeczy warte u kupca") .. " " .. money(p.value) .. ", " .. tr("a nic nie dostajesz.") ..
        (S.armed and (" " .. tr("Kliknij Akceptuj jeszcze raz, jeśli tak ma być.")) or ""),
      tip = tr("Przy tym ostrzeżeniu Akceptuj działa dopiero za drugim kliknięciem (w 5 s, bez zmian w ofercie).") }
  else
    local both = S.acc[1] == 1 and S.acc[2] == 1
    c = { title = tr("Ty dajesz") .. ": " .. sideText(p) .. "   ·   " .. tr("Dostajesz") .. ": " .. sideText(t),
      sub = tr(S.acc[2] == 1 and "Druga strona zaakceptowała." or "Druga strona jeszcze nie zaakceptowała."),
      col = both and C.ok or C.goldDim, done = both }
  end
  F.card:Fill(c, math.floor(F:GetWidth() - 44))
  -- przyciski
  local blk = blocked()
  F.acc:SetShown(not blk)
  F.accClassic:SetShown(blk)
  F.acc:SetEnabled(S.acc[1] ~= 1)
  F.acc.label:SetText(S.acc[1] == 1 and "Zaakceptowane" or (S.armed and "Na pewno? Kliknij jeszcze raz" or "Akceptuj"))
  F.acc:SetWidth(math.max(160, math.floor(F.acc.label:GetStringWidth() + 36)))
  F.acc:Paint(false)
  return p, t
end

function U.handelDraw()
  if not (F and F:IsShown()) then return end
  local ok, err = pcall(function()
    local name = str((U.call(UnitName, "NPC")))
    F.title:SetText(name and tr("Handel z " .. name) or "Handel")
    local lvl = U.num(U.call(UnitLevel, "NPC"))
    if lvl and lvl < 1 then lvl = nil end
    local cls = str((U.call(UnitClass, "NPC")))
    F.sub:SetText((lvl and (tr("poziom") .. " " .. lvl) or "") .. (cls and ((lvl and " · " or "") .. cls) or ""))
    local p = render()
    -- 15.11 autotest: raz na sesje surowe dane pierwszego Twojego przedmiotu (kolejnosc wartosci w kliencie Forever)
    if not S.diagItem then
      for i = 1, SLOTS - 1 do
        if p.slots[i] then
          S.diagItem = true
          U.diag("handelPrzedmiot", { p = U.raw(GetTradePlayerItemInfo, i), link = tostring(p.slots[i].link) })
          break
        end
      end
    end
  end)
  if not ok then F:Fail(err) end
end

-- ---------- budowa ----------
-- Anuluj i ×: przycisk „Anuluj” okna gry
local function pressCancel(b)
  b:SetScript("PreClick", function(self)
    S.pressAt = GetTime()
    self:SetAttribute("clickbutton", (not InCombatLockdown()) and _G.TradeFrameCancelButton or nil)
  end)
  b:SetScript("PostClick", function(self)
    self:SetAttribute("clickbutton", nil)
    if not _G.TradeFrameCancelButton then toClassic() end
  end)
end

local function column(side, title)
  local col = U.Panel(F, 0.55, false, C.line)
  col:SetSize(CW, COL_H)
  col.h = U.H2(col, title)
  col.h:SetPoint("TOPLEFT", 12, -10)
  col.tag = U.Tag(col, "")
  col.tag:SetPoint("TOPRIGHT", -10, -8)
  col.rows = {}
  for i = 1, SLOTS do
    local r = U.OknoRow(col, ROW)
    r:SetPoint("TOPLEFT", 8, -(36 + (i - 1) * (ROW + 2)))
    r:SetPoint("TOPRIGHT", -8, -(36 + (i - 1) * (ROW + 2)))
    r.i = i
    if side == "p" then
      r:RegisterForDrag("LeftButton")
      r:SetScript("OnReceiveDrag", function(self) place(self.i) end)
      r:SetScript("OnDragStart", function(self) if self.it then place(self.i) end end)
    end
    col.rows[i] = r
  end
  col.money = U.Text(col, 13, "body", C.text)
  col.money:SetPoint("BOTTOMLEFT", 12, 12)
  return col
end

local function build()
  if F then return end
  F = U.Okno({ name = "GrimuarHandel", width = W, height = H, title = "Handel", key = "handel",
    hosts = { "ForeverSkinTradeFrame", "TradeFrame" } })
  F.colP = column("p", "Ty dajesz")
  F.colP:SetPoint("TOPLEFT", 22, -56)
  F.colT = column("t", "Dostajesz")
  F.colT:SetPoint("TOPRIGHT", -22, -56)
  F.moneyBtn = U.Button(F.colP, "Zmień kwotę w oknie gry", nil, 22)
  F.moneyBtn:SetPoint("BOTTOMRIGHT", -10, 8)
  F.moneyBtn:SetScript("OnClick", toClassic)
  F.card = U.Card(F)
  F.card:SetPoint("TOPLEFT", 22, -(56 + COL_H + 10))
  local hint = U.Text(F, 11, "body", C.faint)
  hint:SetPoint("BOTTOMLEFT", 24, 24)
  hint:SetText("przeciągnij przedmiot na „Ty dajesz” albo prawy klik w torbie · Shift+klik: link")
  -- Akceptuj, Anuluj i × naciskaja przyciski okna gry
  F.acc = U.OknoKlik(F, "Akceptuj", 160, 30, true)
  F.cancel = U.OknoKlik(F, "Anuluj", 110, 30)
  F.x = U.OknoKlik(F, "×", 26, 24)
  F.secure = F.acc ~= nil and F.cancel ~= nil and F.x ~= nil
  F.accClassic = U.Button(F, "Akceptuj w oknie gry", nil, 30, true)
  F.accClassic:SetPoint("BOTTOMRIGHT", -22, 16)
  F.accClassic:SetScript("OnClick", toClassic)
  F.accClassic:Hide()
  if not F.secure then return end
  F.acc:SetPoint("BOTTOMRIGHT", -22, 16)
  F.cancel:SetPoint("RIGHT", F.acc, "LEFT", -10, 0)
  F.close:Hide()
  F.x:SetPoint("TOPRIGHT", -10, -10)
  pressCancel(F.cancel)
  pressCancel(F.x)
  F.acc:SetScript("PreClick", function(self)
    local _, _, key, warn = current()
    local go = blocker() == nil and (not warn or (S.armed ~= nil and GetTime() - S.armed <= ARM and S.armKey == key))
    self.go, self.key = go, key
    if go then S.pressAt = GetTime() end
    self:SetAttribute("clickbutton", go and _G.TradeFrameTradeButton or nil)
  end)
  F.acc:SetScript("PostClick", function(self)
    self:SetAttribute("clickbutton", nil)
    if self.go then
      S.armed = nil
    else
      local why = blocker()
      if why then U.say(why)
      elseif S.warn then
        S.armed, S.armKey = GetTime(), self.key
        C_Timer.After(ARM + 0.1, function() pcall(U.handelDraw) end)
      end
    end
    C_Timer.After(0.15, function() pcall(U.handelDraw) end)
  end)
end

local ev = CreateFrame("Frame")
for _, e in ipairs({ "TRADE_SHOW", "TRADE_CLOSED", "TRADE_PLAYER_ITEM_CHANGED", "TRADE_TARGET_ITEM_CHANGED", "TRADE_MONEY_CHANGED",
  "TRADE_ACCEPT_UPDATE", "PLAYER_REGEN_DISABLED", "ADDON_ACTION_BLOCKED", "ADDON_ACTION_FORBIDDEN", "GET_ITEM_INFO_RECEIVED" }) do
  pcall(ev.RegisterEvent, ev, e)
end
ev:SetScript("OnEvent", function(_, e, a1, a2)
  if e == "TRADE_SHOW" then
    S.acc, S.armed = { 0, 0 }, nil
    C_Timer.After(0.05, function()
      build()
      pcall(function()
        U.diag("handel", { secure = F.secure and "tak" or "nie", btn = (_G.TradeFrameTradeButton and _G.TradeFrameCancelButton) and "są" or "brak",
          host = (_G.ForeverSkinTradeFrame and _G.ForeverSkinTradeFrame:IsShown()) and "ForeverSkin" or "gra",
          blok = blocked() and "tak" or "nie" })
      end)
      if InCombatLockdown() or not F.secure then return end
      if F:Open() then
        U.handelDraw()
        -- okno ForeverSkin bywa budowane chwile po zdarzeniu: jeszcze raz przezroczystosc i na wierzch
        C_Timer.After(0.3, function() if F:IsShown() then F:HostsAlpha(0) F:Raise() end end)
      end
    end)
  elseif e == "TRADE_CLOSED" then
    S.armed = nil
    if F then F:Finish() end
  elseif e == "PLAYER_REGEN_DISABLED" then
    if F and F:IsShown() then toClassic() end
  elseif e == "ADDON_ACTION_BLOCKED" or e == "ADDON_ACTION_FORBIDDEN" then
    -- gra zablokowala nasz klik w przycisk handlu: od teraz (do nowej wersji) akceptujesz w oknie gry
    if a1 == ADDON and GetTime() - S.pressAt < 2 then
      U.db().handelBlok = { at = date("%Y-%m-%d %H:%M"), fn = tostring(a2), version = U.version and U.version() or "?" }
      U.say("gra nie pozwoliła Grimuarowi nacisnąć przycisku handlu: akceptujesz w oknie gry (do następnej wersji Grimuara).")
      toClassic()
    end
  else
    if e == "TRADE_ACCEPT_UPDATE" then S.acc = { U.num(a1) or 0, U.num(a2) or 0 } end
    if F and F:IsShown() and not S.q then
      S.q = true
      C_Timer.After(0.1, function() S.q = nil U.handelDraw() end)
    end
  end
end)

-- ---------- /gr test ----------
U.testChecksExtra = U.testChecksExtra or {}
table.insert(U.testChecksExtra, { "okno handlu", function()
  local miss = {}
  for _, n in ipairs({ "GetTradePlayerItemInfo", "GetTradePlayerItemLink", "GetTradeTargetItemInfo", "GetTradeTargetItemLink",
    "GetPlayerTradeMoney", "GetTargetTradeMoney", "ClickTradeButton", "AcceptTrade", "CancelTrade" }) do
    if type(_G[n]) ~= "function" then miss[#miss + 1] = n end
  end
  if #miss > 0 then error("brak w kliencie: " .. table.concat(miss, ", ")) end
  local ok, err = pcall(build)
  if not ok then error("budowa okna: " .. tostring(err)) end
  if not F.secure then error("brak InsecureActionButtonTemplate: handel zostaje w oknie gry") end
  local okR, errR = pcall(render)
  if not okR then error("rysowanie (bez handlu): " .. tostring(errR)) end
  local fail = U.db().oknaFails and U.db().oknaFails.handel
  if fail and U.version and fail.version == U.version() then error("wywróciło się " .. tostring(fail.at) .. ": " .. tostring(fail.err)) end
  local d = U.db().diag and U.db().diag.handel
  return (U.oknoOn("handel") and "włączone" or "okno gry (/hub okna handel)") .. ", Akceptuj: " ..
    (blocked() and "w oknie gry (gra zablokowała klik Grimuara)" or "naciska przycisk gry") .. ", przyciski gry: " ..
    ((_G.TradeFrameTradeButton and _G.TradeFrameCancelButton) and "są" or "brak") ..
    (d and (", ostatni handel " .. tostring(d.at) .. " (" .. tostring(d.host) .. ")") or ", jeszcze bez handlu")
end })
