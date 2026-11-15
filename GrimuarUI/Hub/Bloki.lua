-- Grimuar UI: panel z blokami (15.11, gracz o Kronice i Wyprawach: „lepiej niz jak tekst z notatnika”, „to by mozna
-- bylo ikonami pokazywac”). Zamiast jednego napisu: tytul, naglowki z linia, karty z paskiem postepu (siatka), kafelki
-- liczb, siatka ikon przedmiotow (dymek gry, w nim ocena Pawna; Shift+klik linkuje, Ctrl+klik przymierza) i wydarzenia
-- z kartka kalendarza. Uzycie: p:Begin() p:Title() p:Head() p:Cards() p:Stats() p:Icons() p:Events() p:Para()
-- p:Button() p:End(). Karta z onClick jest klikalna (np. Prowadz do trenera), z tip ma dymek.
-- Widzety z puli: Begin() chowa wszystkie, kolejne wywolania biora nastepny wolny (zero nowych ramek przy odswiezaniu).
local ADDON, U = ...
local C = U.C

local MON = { "sty", "lut", "mar", "kwi", "maj", "cze", "lip", "sie", "wrz", "paź", "lis", "gru" }
U.MONTH_SHORT = MON
local GAP = 8

local function take(p, kind, make)
  local P = p.pools[kind]
  if not P then P = { n = 0 } p.pools[kind] = P end
  P.n = P.n + 1
  local w = P[P.n]
  if not w then w = make(p.child) P[P.n] = w end
  w:ClearAllPoints()
  w:Show()
  return w
end
local function colsFor(W, minW) return math.max(1, math.floor((W + GAP) / (minW + GAP))) end

-- ---------- karta: ikona albo romb, tytul, prawy napis, podpis, pasek ----------
local function makeCard(par)
  local f = CreateFrame("Frame", nil, par)
  f.bg = U.Rect(f, C.panel2, 0.75) f.bg:SetAllPoints()
  U.Border(f, C.line)
  f.acc = f:CreateTexture(nil, "ARTWORK")
  f.acc:SetWidth(2) f.acc:SetPoint("TOPLEFT", 1, -1) f.acc:SetPoint("BOTTOMLEFT", 1, 1)
  f.ic = f:CreateTexture(nil, "ARTWORK")
  f.ic:SetSize(26, 26) f.ic:SetPoint("TOPLEFT", 12, -9) f.ic:SetTexCoord(0.08, 0.92, 0.08, 0.92)
  f.d = U.Diamond(f, 14, C.goldDim, false) f.d:SetPoint("TOPLEFT", 14, -10)
  f.t = U.Text(f, 13, "body", C.text)
  f.r = U.Text(f, 12, "body", C.muted) f.r:SetPoint("TOPRIGHT", -12, -10) f.r:SetJustifyH("RIGHT")
  f.s = U.Text(f, 11, "body", C.muted)
  f.bar = U.Bar(f, 6, C.gold)
  f:SetScript("OnEnter", function(self)
    if not self.tip then return end
    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
    GameTooltip:SetText(self.tip, 1, 1, 1, 1, true)
    GameTooltip:Show()
  end)
  f:SetScript("OnLeave", function() GameTooltip:Hide() end)
  f:SetScript("OnMouseUp", function(self) if self.onClick then self.onClick() end end)
  f.hl = f:CreateTexture(nil, "HIGHLIGHT")
  f.hl:SetAllPoints()
  f.hl:SetColorTexture(1, 1, 1, 0.04)
  return f
end
local function fillCard(f, c, cw, ch)
  local done = c.done and true or false
  local x = c.icon and 48 or 38
  f.ic:SetShown(c.icon ~= nil)
  if c.icon then f.ic:SetTexture(c.icon) pcall(f.ic.SetDesaturated, f.ic, done) end
  f.d:SetShown(c.icon == nil)
  if not c.icon then f.d:Set(done and C.ok or (c.col or C.goldDim), done) end
  local acc = done and C.ok or (c.col or C.goldDim)
  f.acc:SetColorTexture(acc[1], acc[2], acc[3], done and 0.9 or 0.55)
  f.r:SetText(c.right or "")
  U.Color(f.r, done and C.ok or (c.rightCol or C.muted))
  f.t:ClearAllPoints()
  f.t:SetPoint("TOPLEFT", x, -10)
  f.t:SetWidth(math.max(40, cw - x - 20 - (f.r:GetStringWidth() or 0)))
  f.t:SetText(c.title or "")
  U.Color(f.t, done and C.muted or C.text)
  f.s:ClearAllPoints()
  f.s:SetPoint("TOPLEFT", x, -29)
  f.s:SetWidth(cw - x - 12)
  f.s:SetText(c.sub or "")
  f.s:SetShown(c.sub ~= nil)
  f.bar:ClearAllPoints()
  f.bar:SetPoint("BOTTOMLEFT", x, 11)
  f.bar:SetWidth(cw - x - 12)
  f.bar:SetShown(c.frac ~= nil)
  if c.frac then
    f.bar:SetFillColor(done and C.ok or (c.col or C.gold))
    f.bar:SetValue(c.frac, c.mark)
  end
  f:EnableMouse(c.tip ~= nil or c.onClick ~= nil)
  f.tip = c.tip
  f.onClick = c.onClick
end

-- ---------- slot przedmiotu ----------
local function makeSlot(par, size)
  local b = U.Slot(par, size)
  b.up = b:CreateTexture(nil, "OVERLAY", nil, 2)
  b.up:SetSize(math.floor(size * 0.42), math.floor(size * 0.42))
  b.up:SetPoint("TOPLEFT", 1, -1)
  pcall(b.up.SetAtlas, b.up, "bags-greenarrow")
  b.up:Hide()
  b:SetScript("OnEnter", function(self)
    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
    if not (self.id and pcall(GameTooltip.SetItemByID, GameTooltip, self.id)) then GameTooltip:SetText(self.nm or "") end
    GameTooltip:Show()
  end)
  b:SetScript("OnLeave", function() GameTooltip:Hide() end)
  b:SetScript("OnClick", function(self)
    local _, link = U.call(C_Item and C_Item.GetItemInfo, self.id)
    if link and HandleModifiedItemClick then pcall(HandleModifiedItemClick, link) end
  end)
  return b
end
-- Pawn: strzalka ulepszenia, gdy Pawn ja zna (tylko odczyt; brak Pawna albo danych przedmiotu = bez strzalki)
local function pawnUp(id)
  local fn = _G.PawnShouldItemLinkHaveUpgradeArrow
  if type(fn) ~= "function" then return false end
  local _, link = U.call(C_Item and C_Item.GetItemInfo, id)
  if not link then return false end
  local ok, r = pcall(fn, link, true)
  return ok and r and true or false
end

-- ---------- wydarzenie: kartka kalendarza z dniem ----------
local function makeEvent(par)
  local f = CreateFrame("Frame", nil, par)
  f.bg = U.Rect(f, C.panel2, 0.75) f.bg:SetAllPoints()
  U.Border(f, C.line)
  f.date = CreateFrame("Frame", nil, f)
  f.date:SetSize(58, 58) f.date:SetPoint("TOPLEFT", 12, -12)
  f.date.bg = U.Rect(f.date, C.bg, 0.95) f.date.bg:SetAllPoints()
  U.Border(f.date, C.edge)
  f.date.top = U.Rect(f.date, C.goldDim, 0.85, "ARTWORK")
  f.date.top:SetPoint("TOPLEFT", 1, -1) f.date.top:SetPoint("TOPRIGHT", -1, -1) f.date.top:SetHeight(15)
  f.mon = U.Text(f.date, 10, "title", C.bg) f.mon:SetPoint("TOP", 0, -2) f.mon:SetJustifyH("CENTER")
  f.day = U.Text(f.date, 22, "title", C.gold) f.day:SetPoint("TOP", 0, -20) f.day:SetJustifyH("CENTER")
  f.t = U.Text(f, 15, "title", C.text) f.t:SetPoint("TOPLEFT", 84, -13)
  f.tag = U.Tag(f, "") f.tag:SetPoint("TOPRIGHT", -12, -12)
  f.w = U.Text(f, 12, "body", C.muted) f.w:SetPoint("TOPLEFT", f.t, "BOTTOMLEFT", 0, -6)
  f.tip = U.Para(f, 12, 300, C.text) f.tip:SetPoint("TOPLEFT", f.w, "BOTTOMLEFT", 0, -7)
  f.src = U.Text(f, 10, "body", C.faint)
  return f
end

function U.Blocks(parent)
  local p = U.Panel(parent, 0.86, true)
  p.view = CreateFrame("ScrollFrame", nil, p)
  p.view:SetPoint("TOPLEFT", 20, -18)
  p.view:SetPoint("BOTTOMRIGHT", -16, 16)
  p.child = CreateFrame("Frame", nil, p.view)
  p.child:SetSize(400, 10)
  p.view:SetScrollChild(p.child)
  p.view:EnableMouseWheel(true)
  p.view:SetScript("OnMouseWheel", function(self, d)
    local max = math.max(0, p.child:GetHeight() - self:GetHeight())
    self:SetVerticalScroll(math.max(0, math.min(max, self:GetVerticalScroll() - d * 80)))
  end)
  p.pools, p.y, p.W = {}, 0, 400

  function p:Begin(keepScroll)
    for _, P in pairs(self.pools) do
      for i = 1, #P do P[i]:Hide() end
      P.n = 0
    end
    self.y = 0
    self.W = math.max(260, math.floor((self.view:GetWidth() or 400) - 8))
    self.child:SetWidth(self.W)
    self.keep = keepScroll
  end
  function p:End()
    self.child:SetHeight(self.y + 10)
    if not self.keep then self.view:SetVerticalScroll(0) end
  end
  function p:Gap(h) self.y = self.y + (h or 10) end

  -- tytul (np. nazwa lochu) i linia pod nim
  function p:Title(text, sub)
    local f = take(self, "title", function(par)
      local w = CreateFrame("Frame", nil, par)
      w.t = U.Text(w, 22, "title", C.gold) w.t:SetPoint("TOPLEFT")
      w.s = U.Para(w, 12, 300, C.muted) w.s:SetPoint("TOPLEFT", w.t, "BOTTOMLEFT", 0, -6)
      return w
    end)
    f:SetPoint("TOPLEFT", self.child, "TOPLEFT", 0, -self.y)
    f:SetWidth(self.W)
    f.t:SetText(text or "")
    f.s:SetWidth(self.W)
    f.s:SetText(sub or "")
    f.s:SetShown(sub ~= nil)
    local h = (f.t:GetStringHeight() or 22) + (sub and ((f.s:GetStringHeight() or 14) + 6) or 0)
    f:SetHeight(h)
    self.y = self.y + h + 12
    return f
  end

  -- naglowek sekcji: romb, nazwa, linia do prawego napisu
  -- btnLabel, btnFn: maly przycisk po prawej (np. „Edytuj” sekcji buildu)
  function p:Head(text, right, btnLabel, btnFn)
    if self.y > 0 then self.y = self.y + 10 end
    local f = take(self, "head", function(par)
      local w = CreateFrame("Frame", nil, par)
      w:SetHeight(22)
      w.d = U.Diamond(w, 10, C.gold, true) w.d:SetPoint("LEFT", 0, 0)
      w.t = U.Text(w, 14, "title", C.gold) w.t:SetPoint("LEFT", w.d, "RIGHT", 7, 0) w.t:SetJustifyV("MIDDLE")
      w.btn = U.Button(w, "", nil, 22)
      w.btn:SetPoint("RIGHT", 0, 0)
      w.r = U.Text(w, 11, "body", C.muted) w.r:SetJustifyH("RIGHT") w.r:SetJustifyV("MIDDLE")
      w.l = U.Line(w, C.edge, 0.5)
      w.l:SetPoint("LEFT", w.t, "RIGHT", 10, 0)
      w.l:SetPoint("RIGHT", w.r, "LEFT", -10, 0)
      return w
    end)
    f:SetPoint("TOPLEFT", self.child, "TOPLEFT", 0, -self.y)
    f:SetWidth(self.W)
    f.t:SetText(text or "")
    f.r:SetText(right or "")
    f.r:ClearAllPoints()
    if btnFn then
      f.btn:SetLabel(btnLabel or "Edytuj")
      f.btn:SetScript("OnClick", btnFn)
      f.btn:Show()
      f.r:SetPoint("RIGHT", f.btn, "LEFT", -10, 0)
    else
      f.btn:Hide()
      f.r:SetPoint("RIGHT", f, "RIGHT", 0, 0)
    end
    self.y = self.y + 22 + 8
    return f
  end

  -- zetony: krotkie napisy w ramce, zawijane w wiersze; { text, col, tip }
  function p:Chips(list)
    if #list == 0 then return end
    local x, rowH = 0, 22
    for _, c in ipairs(list) do
      local f = take(self, "chip", function(par)
        local w = CreateFrame("Frame", nil, par)
        w.bg = U.Rect(w, C.panel2, 0.7) w.bg:SetAllPoints()
        U.Border(w, C.edge)
        w.t = U.Text(w, 12, "body", C.text) w.t:SetPoint("CENTER", 0, 0) w.t:SetJustifyH("CENTER") w.t:SetJustifyV("MIDDLE")
        w:SetScript("OnEnter", function(self)
          if not self.tip then return end
          GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
          GameTooltip:SetText(self.tip, 1, 1, 1, 1, true)
          GameTooltip:Show()
        end)
        w:SetScript("OnLeave", function() GameTooltip:Hide() end)
        return w
      end)
      f.t:SetText(c.text or "")
      U.Color(f.t, c.col or C.text)
      U.BorderColor(f, c.col or C.edge, 0.55)
      local cw = math.floor((f.t:GetStringWidth() or 40) + 18)
      if x > 0 and x + cw > self.W then x = 0 self.y = self.y + rowH + 6 end
      f:SetSize(cw, rowH)
      f:SetPoint("TOPLEFT", self.child, "TOPLEFT", x, -self.y)
      f.tip = c.tip
      f:EnableMouse(c.tip ~= nil)
      x = x + cw + 6
    end
    self.y = self.y + rowH + 10
  end

  -- sloty czarow (np. pasek akcji): { icon, label, tip, spellId, empty }; podpis pod ikona (klawisz)
  function p:Slots(list, opts)
    if #list == 0 then return end
    local size = (opts and opts.size) or 40
    local per = math.max(1, math.floor((self.W + 6) / (size + 6)))
    local rows = math.ceil(#list / per)
    for i, s in ipairs(list) do
      local b = take(self, "sslot" .. size, function(par)
        local x = U.Slot(par, size)
        x.lab = U.Text(x, 10, "body", C.faint)
        x.lab:SetPoint("TOP", x, "BOTTOM", 0, -2)
        x.lab:SetJustifyH("CENTER")
        x:SetScript("OnEnter", function(self)
          if not (self.spellId or self.tip) then return end
          GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
          if not (self.spellId and pcall(GameTooltip.SetSpellByID, GameTooltip, self.spellId)) then
            GameTooltip:SetText(self.tip or "", 1, 1, 1, 1, true)
          elseif self.tip then GameTooltip:AddLine(self.tip, 0.8, 0.8, 0.8, true) end
          GameTooltip:Show()
        end)
        x:SetScript("OnLeave", function() GameTooltip:Hide() end)
        return x
      end)
      local col, row = (i - 1) % per, math.floor((i - 1) / per)
      b:SetPoint("TOPLEFT", self.child, "TOPLEFT", col * (size + 6), -(self.y + row * (size + 20)))
      b.icon:SetShown(not s.empty)
      if not s.empty then b.icon:SetTexture(s.icon or 134400) end
      b:SetQuality(nil)
      b.count:SetText("")
      b.lab:SetText(s.label or "")
      b.tip, b.spellId = s.tip, s.spellId
    end
    self.y = self.y + rows * (size + 20) + 4
  end

  -- przycisk w tresci (np. „Otworz w Polestarze”)
  function p:Button(label, fn, primary)
    local b = take(self, primary and "btnP" or "btn", function(par) return U.Button(par, "", nil, 28, primary) end)
    b:SetLabel(label or "")
    b:SetScript("OnClick", function() if fn then fn() end end)
    b:SetPoint("TOPLEFT", self.child, "TOPLEFT", 0, -self.y)
    self.y = self.y + 28 + 10
    return b
  end

  -- akapit
  function p:Para(text, col, size)
    size = size or 13
    local fs = take(self, "para" .. size, function(par)
      local t = U.Para(par, size, 300, C.text)
      t:SetSpacing(3)
      return t
    end)
    fs:SetWidth(self.W)
    U.Color(fs, col or C.text)
    fs:SetText(text or "")
    fs:SetPoint("TOPLEFT", self.child, "TOPLEFT", 0, -self.y)
    self.y = self.y + (fs:GetStringHeight() or size) + 8
    return fs
  end

  -- karty w siatce: { title, right, sub, frac, mark, done, col, icon, rightCol }; opts: minW, cols, maxW
  function p:Cards(list, opts)
    opts = opts or {}
    if #list == 0 then return end
    local nc = opts.cols or colsFor(self.W, opts.minW or 330)
    local cw = math.floor((self.W - GAP * (nc - 1)) / nc)
    if opts.maxW then cw = math.min(cw, opts.maxW) end
    local anySub, anyBar = false, false
    for _, c in ipairs(list) do
      anySub = anySub or (c.sub ~= nil and c.sub ~= "")
      anyBar = anyBar or c.frac ~= nil
    end
    local ch = 36 + (anySub and 17 or 0) + (anyBar and 14 or 0)
    for i, c in ipairs(list) do
      local f = take(self, "card", makeCard)
      local col, row = (i - 1) % nc, math.floor((i - 1) / nc)
      f:SetSize(cw, ch)
      f:SetPoint("TOPLEFT", self.child, "TOPLEFT", col * (cw + GAP), -(self.y + row * (ch + GAP)))
      fillCard(f, c, cw, ch)
    end
    self.y = self.y + math.ceil(#list / nc) * (ch + GAP) + 2
  end

  -- kafelki liczb: { value, label, col }
  function p:Stats(list, opts)
    if #list == 0 then return end
    local nc = math.min(#list, colsFor(self.W, (opts and opts.minW) or 130))
    local cw = math.floor((self.W - GAP * (nc - 1)) / nc)
    local ch = 60
    for i, s in ipairs(list) do
      local f = take(self, "stat", function(par)
        local w = CreateFrame("Frame", nil, par)
        w.bg = U.Rect(w, C.panel2, 0.75) w.bg:SetAllPoints()
        U.Border(w, C.line)
        w.v = U.Text(w, 19, "title", C.text) w.v:SetPoint("TOP", 0, -11) w.v:SetJustifyH("CENTER")
        w.l = U.Text(w, 11, "body", C.faint) w.l:SetPoint("BOTTOM", 0, 9) w.l:SetJustifyH("CENTER")
        return w
      end)
      local col, row = (i - 1) % nc, math.floor((i - 1) / nc)
      f:SetSize(cw, ch)
      f:SetPoint("TOPLEFT", self.child, "TOPLEFT", col * (cw + GAP), -(self.y + row * (ch + GAP)))
      f.v:SetText(tostring(s[1] or "—"))
      U.Color(f.v, s[3] or C.text)
      f.l:SetText(s[2] or "")
    end
    self.y = self.y + math.ceil(#list / nc) * (ch + GAP) + 2
  end

  -- siatka ikon przedmiotow: { id, name, quality, icon }; opts.size
  function p:Icons(items, opts)
    if #items == 0 then return end
    local size = (opts and opts.size) or 38
    local per = math.max(1, math.floor((self.W + 6) / (size + 6)))
    for i, it in ipairs(items) do
      local b = take(self, "slot" .. size, function(par) return makeSlot(par, size) end)
      local col, row = (i - 1) % per, math.floor((i - 1) / per)
      b:SetPoint("TOPLEFT", self.child, "TOPLEFT", col * (size + 6), -(self.y + row * (size + 6)))
      b.id, b.nm = it.id, it.name
      b.icon:SetTexture(it.icon or (it.id and U.call(C_Item and C_Item.GetItemIconByID, it.id)) or 134400)
      b:SetQuality(it.quality)
      b.count:SetText("")
      b.up:SetShown(it.id ~= nil and pawnUp(it.id))
    end
    self.y = self.y + math.ceil(#items / per) * (size + 6) + 4
  end

  -- wydarzenia: { title, start, stop, now, tip, src }
  function p:Events(list)
    local t = time()
    for _, e in ipairs(list) do
      local f = take(self, "event", makeEvent)
      f:SetPoint("TOPLEFT", self.child, "TOPLEFT", 0, -self.y)
      f:SetWidth(self.W)
      local at = e.now and (e.stop or t) or (e.start or t)
      local dt = date("*t", at)
      f.mon:SetText(e.now and "do" or MON[dt.month])
      f.day:SetText(e.now and (dt.day .. "." .. string.format("%02d", dt.month)) or tostring(dt.day))
      f.t:SetText(e.title or "?")
      if e.now then f.tag:SetTag("trwa · jeszcze " .. U.inText((e.stop or t) - t), C.ok)
      else f.tag:SetTag("za " .. U.inText((e.start or t) - t), C.gold) end
      f.t:SetWidth(math.max(80, self.W - 84 - (f.tag:GetWidth() or 0) - 24))
      f.w:SetText(e.now and ("do " .. U.fmtDate(e.stop)) or ("od " .. U.fmtDate(e.start) .. " do " .. U.fmtDate(e.stop)))
      f.tip:SetWidth(self.W - 96)
      f.tip:SetText(e.tip or "")
      f.tip:SetShown(e.tip ~= nil)
      f.src:ClearAllPoints()
      f.src:SetPoint("TOPLEFT", e.tip and f.tip or f.w, "BOTTOMLEFT", 0, -6)
      f.src:SetText(e.src and ("źródło: " .. e.src) or "")
      local h = 13 + 18 + 6 + 14 + (e.tip and ((f.tip:GetStringHeight() or 14) + 7) or 0) + (e.src and 18 or 0) + 14
      f:SetHeight(math.max(82, h))
      self.y = self.y + math.max(82, h) + GAP
    end
  end

  return p
end
