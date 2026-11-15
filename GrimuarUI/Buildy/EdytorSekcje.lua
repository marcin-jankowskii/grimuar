-- Grimuar UI: edytor buildu, sekcje poza talentami (15.11, gracz: „in game powinna byc mozliwosc przerabiania
-- i edytowania buildow”). Bez Lua, tylko klikanie i pola:
-- * Trener: kazdy czar Kupuj / AoE / Pomin / — (klik zmienia), powod pominiecia, „Kupuj wszystko”, AoE tak/nie, dodaj czar;
-- * Paski: 3 paski po 12 slotow; klik = wybierz czar albo makro (takze jeszcze nienauczony: wpisz nazwe), prawy klik =
--   pusty; „Wez paski z gry” zapisuje obecne paski (makra z gry dochodza do makr buildu, bez /run);
-- * Combo i Ratunek: kroki z czarem albo tekstem, wskazowka, kolejnosc; klawisz bierze sie sam z paskow;
-- * Kolo: czary i podpisy, kolejnosc; * Makra: nazwa i tresc (bez /run, /script, /console, /dump);
-- * Porady: PvP na klasy (do 39 i od 40) oraz na typy stworow.
-- Wszystko na kopii roboczej (U.ED.b z BuildyEdytor.lua), zapis dopiero „Zapisz” (G.SaveOwnBuild z walidacja).
local ADDON, U = ...
local C = U.C
local G = U.G or {}

local X = U.ED or {}
U.ED = X
X.secs = X.secs or {}
local BAD = { "/run", "/script", "/console", "/dump", "/scr ", "runscript" }

local function dirty() if X.markDirty then X.markDirty() end end
local function B() return X.b end
local function bt(v) return U.bt and U.bt(v) or (type(v) == "table" and (v.pl or v.en) or v) end
local function badMacro(body)
  local low = tostring(body or ""):lower()
  for _, w in ipairs(BAD) do if low:find(w, 1, true) then return true end end
  return false
end

-- ---------- wspolne widzety ----------
local function scroller(parent, top)
  local v = CreateFrame("ScrollFrame", nil, parent)
  v:SetPoint("TOPLEFT", 0, top or -40)
  v:SetPoint("BOTTOMRIGHT", 0, 0)
  local c = CreateFrame("Frame", nil, v)
  c:SetSize(500, 10)
  v:SetScrollChild(c)
  v:EnableMouseWheel(true)
  v:SetScript("OnMouseWheel", function(self, d)
    local max = math.max(0, c:GetHeight() - self:GetHeight())
    self:SetVerticalScroll(math.max(0, math.min(max, self:GetVerticalScroll() - d * 70)))
  end)
  return v, c
end
local function input(parent, w, h, multi)
  local e
  if multi then
    e = CreateFrame("EditBox", nil, parent)
    e:SetMultiLine(true)
    e:SetFontObject(ChatFontNormal)
    e:SetTextInsets(6, 6, 4, 4)
    e.bg = U.Rect(e, C.slot, 0.95) e.bg:SetAllPoints()
    U.Border(e, C.edge)
  else
    e = CreateFrame("EditBox", nil, parent, "InputBoxTemplate")
  end
  e:SetSize(w, h or 24)
  e:SetAutoFocus(false)
  e:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
  if not multi then e:SetScript("OnEnterPressed", function(self) self:ClearFocus() end) end
  return e
end
local function tbar(f, items)
  local prev
  for _, it in ipairs(items) do
    local b = U.Button(f, it[1], nil, 26, it[3])
    if prev then b:SetPoint("LEFT", prev, "RIGHT", 6, 0) else b:SetPoint("TOPLEFT", f, "TOPLEFT", 0, -4) end
    b:SetScript("OnClick", function() local ok, e = pcall(it[2], b) if not ok and U.logError then U.logError("edytor", e) end end)
    prev = b
    if it.key then f[it.key] = b end
  end
  return prev
end
local function smallBtn(parent, text, w, fn)
  local b = U.Button(parent, text, w, 22)
  b:SetScript("OnClick", function() local ok, e = pcall(fn) if not ok and U.logError then U.logError("edytor", e) end end)
  return b
end
local function moveIn(list, i, d)
  local j = i + d
  if j < 1 or j > #list then return end
  list[i], list[j] = list[j], list[i]
end

-- ---------- wybor czaru (lista z ksiegi, makra buildu, wpisana nazwa) ----------
local PK
local function entriesFor(opts)
  local out, seen = {}, {}
  local function add(label, value, icon)
    if seen[value] then return end
    seen[value] = true
    out[#out + 1] = { label = label, value = value, icon = icon }
  end
  if opts.macros then
    for _, m in ipairs((B() or {}).macros or {}) do add("Makro: " .. m[1], "macro:" .. m[1], U.bIcon("macro:" .. m[1])) end
  end
  local groups = {}
  if U.readSpellBook then
    local ok, g = pcall(U.readSpellBook)
    if ok and type(g) == "table" then groups = g end
  end
  local sp = {}
  for _, g in ipairs(type(groups) == "table" and groups or {}) do
    for _, s in ipairs(g.list or {}) do sp[#sp + 1] = s end
  end
  table.sort(sp, function(a, b) return a.name < b.name end)
  for _, s in ipairs(sp) do add(s.name, s.name, U.call(C_Spell.GetSpellTexture, s.id)) end
  return out
end
local function pickerRow(i)
  local r = PK.rows[i]
  if r then return r end
  r = CreateFrame("Button", nil, PK.list)
  r:SetSize(296, 24)
  local hl = r:CreateTexture(nil, "HIGHLIGHT") hl:SetAllPoints() hl:SetColorTexture(1, 1, 1, 0.07)
  r.ic = r:CreateTexture(nil, "ARTWORK") r.ic:SetSize(20, 20) r.ic:SetPoint("LEFT", 2, 0) r.ic:SetTexCoord(0.08, 0.92, 0.08, 0.92)
  r.t = U.Text(r, 13, "body", C.text) r.t:SetPoint("LEFT", r.ic, "RIGHT", 8, 0) r.t:SetJustifyV("MIDDLE") r.t:SetWidth(260)
  r:SetScript("OnClick", function(self) local fn = PK.onPick PK:Hide() if fn then fn(self.value) end end)
  PK.rows[i] = r
  return r
end
local function pickerFill()
  local q = (PK.search:GetText() or ""):lower()
  local list = {}
  if PK.opts.empty then list[1] = { label = "(pusty)", value = false } end
  for _, e in ipairs(PK.all) do
    if q == "" or e.label:lower():find(q, 1, true) then list[#list + 1] = e end
  end
  for i, e in ipairs(list) do
    local r = pickerRow(i)
    r:ClearAllPoints() r:SetPoint("TOPLEFT", PK.list, "TOPLEFT", 0, -(i - 1) * 25)
    r.value = e.value
    r.t:SetText(e.label)
    r.ic:SetShown(e.icon ~= nil)
    if e.icon then r.ic:SetTexture(e.icon) end
    r:Show()
  end
  for i = #list + 1, #PK.rows do PK.rows[i]:Hide() end
  PK.list:SetHeight(math.max(10, #list * 25))
end
function X.pick(title, opts, onPick)
  if not PK then
    PK = U.Panel(X.f or UIParent, 0.98, true, C.gold)
    PK:SetSize(330, 460)
    PK:SetToplevel(true)
    PK:EnableMouse(true)
    PK.title = U.Label(PK, "") PK.title:SetPoint("TOPLEFT", 12, -10)
    local x = U.Button(PK, "×", 24, 22) x:SetPoint("TOPRIGHT", -8, -6)
    x:SetScript("OnClick", function() PK:Hide() end)
    PK.search = input(PK, 300, 24)
    PK.search:SetPoint("TOPLEFT", 16, -32)
    PK.search:SetScript("OnTextChanged", function() pickerFill() end)
    PK.search:SetScript("OnEnterPressed", function(self)
      local t = (self:GetText() or ""):gsub("^%s+", ""):gsub("%s+$", "")
      self:ClearFocus()
      if t ~= "" then local fn = PK.onPick PK:Hide() if fn then fn(t) end end
    end)
    PK.hint = U.Para(PK, 11, 300, C.faint)
    PK.hint:SetPoint("TOPLEFT", PK.search, "BOTTOMLEFT", -4, -4)
    PK.hint:SetText("Szukaj albo wpisz nazwę i Enter (czar, którego jeszcze nie masz).")
    local v = CreateFrame("ScrollFrame", nil, PK)
    v:SetPoint("TOPLEFT", 12, -88) v:SetPoint("BOTTOMRIGHT", -12, 10)
    PK.list = CreateFrame("Frame", nil, v) PK.list:SetSize(300, 10)
    v:SetScrollChild(PK.list)
    v:EnableMouseWheel(true)
    v:SetScript("OnMouseWheel", function(self, d)
      local max = math.max(0, PK.list:GetHeight() - self:GetHeight())
      self:SetVerticalScroll(math.max(0, math.min(max, self:GetVerticalScroll() - d * 75)))
    end)
    PK.rows = {}
  end
  PK:ClearAllPoints()
  PK:SetPoint("CENTER", X.f or UIParent, "CENTER", 0, 0)
  if X.f then PK:SetFrameLevel(X.f:GetFrameLevel() + 40) end
  PK.opts, PK.onPick = opts or {}, onPick
  PK.all = entriesFor(PK.opts)
  PK.title:SetText(title or "Wybierz czar")
  PK.search:SetText("")
  pickerFill()
  PK:Show()
  PK.search:SetFocus()
end
function X.hidePicker() if PK then PK:Hide() end end

-- ================= Trener =================
local TR = {}
local STATES = { "kupuj", "aoe", "pomin", "brak" }
local ST_TXT = { kupuj = "Kupuj", aoe = "Tylko AoE", pomin = "Pomiń", brak = "—" }
local ST_COL = { kupuj = C.ok, aoe = C.frost, pomin = C.muted, brak = C.faint }
local function trNorm(b)
  b.trainer = b.trainer or {}
  local tr = b.trainer
  for _, k in ipairs({ "keep", "aoe" }) do
    local m = {}
    for a, v in pairs(tr[k] or {}) do if type(a) == "number" then m[v] = true else m[a] = true end end
    tr[k] = m
  end
  local s = {}
  for a, v in pairs(tr.skip or {}) do if type(a) == "string" then s[a] = bt(v) or "" end end
  tr.skip = s
  return tr
end
local function trState(tr, n)
  if tr.keep[n] then return "kupuj" elseif tr.aoe[n] then return "aoe" elseif tr.skip[n] then return "pomin" end
  return "brak"
end
local function trSet(tr, n, st)
  tr.keep[n], tr.aoe[n] = nil, nil
  local why = tr.skip[n]
  tr.skip[n] = nil
  if st == "kupuj" then tr.keep[n] = true
  elseif st == "aoe" then tr.aoe[n] = true
  elseif st == "pomin" then tr.skip[n] = (why and why ~= "") and why or "pomijam w moim buildzie" end
end
local function trRow(i)
  local r = TR.rows[i]
  if r then return r end
  r = CreateFrame("Frame", nil, TR.c)
  r:SetHeight(28)
  r.lv = U.Text(r, 11, "body", C.faint) r.lv:SetPoint("LEFT", 2, 0) r.lv:SetWidth(34) r.lv:SetJustifyV("MIDDLE")
  r.t = U.Text(r, 13, "body", C.text) r.t:SetPoint("LEFT", 38, 0) r.t:SetWidth(210) r.t:SetJustifyV("MIDDLE")
  r.st = smallBtn(r, "", 96, function()
    local tr = B().trainer
    local cur = trState(tr, r.name)
    local nxt
    for k, s in ipairs(STATES) do if s == cur then nxt = STATES[k % #STATES + 1] end end
    trSet(tr, r.name, nxt)
    dirty()
    TR.draw()
  end)
  r.st:SetPoint("LEFT", 254, 0)
  r.why = input(r, 260, 22)
  r.why:SetPoint("LEFT", r.st, "RIGHT", 12, 0)
  r.why:SetScript("OnTextChanged", function(self, user)
    if not user then return end
    local tr = B().trainer
    if tr.skip[r.name] then tr.skip[r.name] = self:GetText() dirty() end
  end)
  r.del = smallBtn(r, "×", 24, function()
    local tr = B().trainer
    trSet(tr, r.name, "brak")
    for k = #(tr.list or {}), 1, -1 do local e = tr.list[k] if type(e) == "table" and e[2] == r.name then table.remove(tr.list, k) end end
    dirty()
    TR.draw()
  end)
  r.del:SetPoint("LEFT", r.why, "RIGHT", 8, 0)
  TR.rows[i] = r
  return r
end
function TR.draw()
  local b = B()
  if not (b and TR.f) then return end
  local tr = trNorm(b)
  TR.f.all:SetLabel("Kupuj wszystko: " .. (tr.all and "tak" or "nie"))
  TR.f.aoe:SetLabel("AoE u trenera: " .. (tr.aoeOn and "tak" or "nie"))
  local lv, names = {}, {}
  for _, e in ipairs(tr.list or {}) do if type(e) == "table" and e[2] then lv[e[2]] = lv[e[2]] or e[1] end end
  local seen = {}
  local function add(n) if type(n) == "string" and not seen[n] then seen[n] = true names[#names + 1] = n end end
  for n in pairs(lv) do add(n) end
  for n in pairs(tr.keep) do add(n) end
  for n in pairs(tr.aoe) do add(n) end
  for n in pairs(tr.skip) do add(n) end
  table.sort(names, function(a, c)
    local la, lc = lv[a] or 99, lv[c] or 99
    if la ~= lc then return la < lc end
    return a < c
  end)
  for i, n in ipairs(names) do
    local r = trRow(i)
    r.name = n
    r:SetWidth(TR.c:GetWidth())
    r:ClearAllPoints() r:SetPoint("TOPLEFT", TR.c, "TOPLEFT", 0, -(i - 1) * 30)
    r.lv:SetText(lv[n] and ("poz. " .. lv[n]) or "")
    r.t:SetText(n)
    local st = trState(tr, n)
    r.st:SetLabel(ST_TXT[st])
    U.Color(r.st.label, ST_COL[st])
    r.why:SetShown(st == "pomin")
    if st == "pomin" and not r.why:HasFocus() then r.why:SetText(tr.skip[n] or "") end
    r:Show()
  end
  for i = #names + 1, #TR.rows do TR.rows[i]:Hide() end
  TR.c:SetHeight(math.max(10, #names * 30))
  TR.note:SetText(tr.all and "„Kupuj wszystko” włączone: trener kupuje każdy czar, lista niżej to tylko opisy." or
    "Klik w stan zmienia: Kupuj → Tylko AoE → Pomiń → —. „—” = nie kupuje i nie tłumaczy. Kolejność: poziom z planu.")
end
X.secs.trener = { title = "Trener", order = 2, build = function(host)
  local f = CreateFrame("Frame", nil, host)
  f:SetAllPoints()
  TR.f, TR.rows = f, {}
  local last = tbar(f, {
    { "Kupuj wszystko", function() local tr = trNorm(B()) tr.all = not tr.all or nil dirty() TR.draw() end, key = "all" },
    { "AoE u trenera", function() local tr = trNorm(B()) tr.aoeOn = not tr.aoeOn or nil dirty() TR.draw() end, key = "aoe" },
  })
  TR.add = input(f, 200, 24)
  TR.add:SetPoint("LEFT", last, "RIGHT", 16, 0)
  local addB = U.Button(f, "Dodaj czar", nil, 26)
  addB:SetPoint("LEFT", TR.add, "RIGHT", 6, 0)
  local function doAdd()
    local n = (TR.add:GetText() or ""):gsub("^%s+", ""):gsub("%s+$", "")
    if n == "" then X.pick("Czar do kupienia", {}, function(v) if v then trSet(trNorm(B()), v, "kupuj") dirty() TR.draw() end end) return end
    trSet(trNorm(B()), n, "kupuj")
    TR.add:SetText("")
    dirty()
    TR.draw()
  end
  addB:SetScript("OnClick", doAdd)
  TR.add:SetScript("OnEnterPressed", function(self) self:ClearFocus() doAdd() end)
  TR.note = U.Para(f, 11, 700, C.faint)
  TR.note:SetPoint("TOPLEFT", f, "TOPLEFT", 0, -36)
  local _, c = scroller(f, -60)
  TR.c = c
  c:SetWidth(700)
  return f
end, draw = function() TR.draw() end }

-- ================= Paski =================
local PS = { slots = {} }
local function barsOf(b) b.bars = b.bars or {} return b.bars end
local function slotBtn(di, i)
  local key = di * 100 + i
  local s = PS.slots[key]
  if s then return s end
  s = U.Slot(PS.c, 40)
  s:RegisterForClicks("LeftButtonUp", "RightButtonUp")
  s.lab = U.Text(s, 10, "body", C.faint) s.lab:SetPoint("TOP", s, "BOTTOM", 0, -2) s.lab:SetJustifyH("CENTER")
  s:SetScript("OnClick", function(self, button)
    local d = U.BAR_DEF[di]
    local slot = d.from + i - 1
    local bar = barsOf(B())
    bar[d.key] = bar[d.key] or {}
    if button == "RightButton" then bar[d.key][slot] = nil dirty() PS.draw() return end
    X.pick(d.title .. ", slot " .. i, { empty = true, macros = true }, function(v)
      if v == false then bar[d.key][slot] = nil else bar[d.key][slot] = { v } end
      dirty()
      PS.draw()
    end)
  end)
  s:SetScript("OnEnter", function(self)
    U.TT:SetOwner(self, "ANCHOR_RIGHT")
    U.TT:SetText(self.tip or "pusty", 1, 1, 1)
    U.TT:AddLine("Klik: wybierz czar albo makro. Prawy klik: wyczyść.", 0.7, 0.7, 0.7, true)
    U.TT:Show()
  end)
  s:SetScript("OnLeave", function() U.TT:Hide() end)
  PS.slots[key] = s
  return s
end
function PS.draw()
  local b = B()
  if not (b and PS.f) then return end
  local bars = barsOf(b)
  local y = 0
  for di, d in ipairs(U.BAR_DEF) do
    PS.heads[di]:ClearAllPoints()
    PS.heads[di]:SetPoint("TOPLEFT", PS.c, "TOPLEFT", 0, -y)
    PS.heads[di]:SetText(d.title)
    y = y + 20
    for i = 1, 12 do
      local s = slotBtn(di, i)
      local alts = (bars[d.key] or {})[d.from + i - 1]
      local first = type(alts) == "table" and alts[1] or alts
      s:ClearAllPoints()
      s:SetPoint("TOPLEFT", PS.c, "TOPLEFT", (i - 1) * 48, -y)
      s.icon:SetShown(first ~= nil)
      if first then s.icon:SetTexture(U.bIcon(first) or 134400) end
      s.tip = first and table.concat(type(alts) == "table" and alts or { alts }, " albo ") or nil
      s.lab:SetText(U.bKey(d.bind .. i) or tostring(i))
      s:SetQuality(nil)
      s.count:SetText("")
      s:Show()
    end
    y = y + 70
  end
  PS.c:SetHeight(y)
end
-- obecne paski z gry -> build (makra z gry dochodza do makr buildu)
local function snapshot()
  local b = B()
  local bars = barsOf(b)
  b.macros = b.macros or {}
  local have, n, skipped = {}, 0, {}
  for _, m in ipairs(b.macros) do have[m[1]] = true end
  for _, d in ipairs(U.BAR_DEF) do
    local t = {}
    for i = 1, 12 do
      local slot = d.from + i - 1
      local kind, id = U.call(GetActionInfo, slot)
      local val
      if kind == "spell" and id then
        local nm = C_Spell and C_Spell.GetSpellName and U.call(C_Spell.GetSpellName, id) or U.call(GetSpellInfo, id)
        val = nm
      elseif kind == "macro" and id then
        local nm, _, body = U.call(GetMacroInfo, id)
        if nm then
          if badMacro(body) then skipped[#skipped + 1] = nm
          else
            if not have[nm] and #b.macros < 18 then b.macros[#b.macros + 1] = { nm:sub(1, 16), tostring(body or ""):sub(1, 255) } have[nm] = true end
            val = "macro:" .. nm
          end
        end
      end
      if val then
        local old = (bars[d.key] or {})[slot]
        local keep = false
        for _, a in ipairs(type(old) == "table" and old or {}) do if a == val then keep = true end end
        t[slot] = keep and old or { val }
        n = n + 1
      end
    end
    bars[d.key] = t
  end
  dirty()
  PS.draw()
  U.say("paski z gry zapisane w buildzie: " .. n .. " slotów." .. (#skipped > 0 and (" Pominięte makra z /run itp.: " .. table.concat(skipped, ", ") .. ".") or "") .. " Kliknij Zapisz.")
end
X.secs.paski = { title = "Paski", order = 3, build = function(host)
  local f = CreateFrame("Frame", nil, host)
  f:SetAllPoints()
  PS.f, PS.heads = f, {}
  tbar(f, {
    { "Weź paski z gry", snapshot, true },
    { "Wyczyść pasek 3", function() barsOf(B()).bar3 = {} dirty() PS.draw() end },
  })
  local note = U.Para(f, 11, 700, C.faint)
  note:SetPoint("TOPLEFT", f, "TOPLEFT", 0, -36)
  note:SetText("Ułóż paski w grze i kliknij „Weź paski z gry” albo klikaj sloty. Nowe czary trafią na swoje miejsca same po treningu (jeśli zgodziłeś się w kreatorze).")
  local _, c = scroller(f, -62)
  PS.c = c
  c:SetWidth(600)
  for di = 1, #U.BAR_DEF do PS.heads[di] = U.Text(c, 12, "title", C.goldDim) end
  return f
end, draw = function() PS.draw() end }

-- ================= Combo i Ratunek =================
local CO = { rows = {} }
local function coList(which)
  local b = B()
  b.combo = b.combo or {}
  b.combo[which] = b.combo[which] or {}
  return b.combo[which]
end
local function coRow(i)
  local r = CO.rows[i]
  if r then return r end
  r = CreateFrame("Frame", nil, CO.c)
  r:SetHeight(30)
  r.head = U.Text(r, 12, "title", C.goldDim) r.head:SetPoint("LEFT", 0, 0) r.head:SetJustifyV("MIDDLE")
  r.ic = r:CreateTexture(nil, "ARTWORK") r.ic:SetSize(24, 24) r.ic:SetPoint("LEFT", 0, 0) r.ic:SetTexCoord(0.08, 0.92, 0.08, 0.92)
  r.sp = smallBtn(r, "", 170, function()
    X.pick("Czar kroku", { macros = true }, function(v)
      if not v then return end
      local s = coList(r.which)[r.i]
      local m = v:match("^macro:(.+)$")
      if m then s.spell, s.text, s.bind = nil, m, "MACRO " .. m
      else s.spell, s.text, s.bind = v, nil, U.bBindFor(B(), v) end
      dirty()
      CO.draw()
    end)
  end)
  r.sp:SetPoint("LEFT", 30, 0)
  r.hint = input(r, 300, 22)
  r.hint:SetPoint("LEFT", r.sp, "RIGHT", 12, 0)
  r.hint:SetScript("OnTextChanged", function(self, user)
    if not user then return end
    local s = coList(r.which)[r.i]
    if not s then return end
    local t = self:GetText()
    if s.spell then s.hint = t ~= "" and t or nil else s.text = t end
    dirty()
  end)
  r.key = U.Text(r, 11, "body", C.muted) r.key:SetPoint("LEFT", r.hint, "RIGHT", 10, 0) r.key:SetWidth(70) r.key:SetJustifyV("MIDDLE")
  r.up = smallBtn(r, "Wyżej", 56, function() moveIn(coList(r.which), r.i, -1) dirty() CO.draw() end)
  r.up:SetPoint("LEFT", r.key, "RIGHT", 6, 0)
  r.dn = smallBtn(r, "Niżej", 56, function() moveIn(coList(r.which), r.i, 1) dirty() CO.draw() end)
  r.dn:SetPoint("LEFT", r.up, "RIGHT", 4, 0)
  r.del = smallBtn(r, "×", 24, function() table.remove(coList(r.which), r.i) dirty() CO.draw() end)
  r.del:SetPoint("LEFT", r.dn, "RIGHT", 4, 0)
  CO.rows[i] = r
  return r
end
function CO.draw()
  local b = B()
  if not (b and CO.f) then return end
  local n, y = 0, 0
  for _, part in ipairs({ { "steps", "Combo" }, { "rescue", "Ratunek" } }) do
    n = n + 1
    local h = coRow(n)
    h.which, h.i = nil, nil
    h:ClearAllPoints() h:SetPoint("TOPLEFT", CO.c, "TOPLEFT", 0, -y) h:SetWidth(CO.c:GetWidth())
    h.head:SetText(part[2] .. " (" .. #coList(part[1]) .. ")") h.head:Show()
    for _, w in ipairs({ h.ic, h.sp, h.hint, h.key, h.up, h.dn, h.del }) do w:Hide() end
    h:Show()
    y = y + 30
    for i, s in ipairs(coList(part[1])) do
      n = n + 1
      local r = coRow(n)
      r.which, r.i = part[1], i
      r:ClearAllPoints() r:SetPoint("TOPLEFT", CO.c, "TOPLEFT", 0, -y) r:SetWidth(CO.c:GetWidth())
      r.head:Hide()
      for _, w in ipairs({ r.ic, r.sp, r.hint, r.key, r.up, r.dn, r.del }) do w:Show() end
      local ic = s.spell and U.bIcon(s.spell)
      r.ic:SetTexture(ic or 134400)
      r.ic:SetShown(s.spell ~= nil)
      r.sp:SetLabel(s.spell and (i .. ". " .. s.spell) or (i .. ". (tekst)"))
      if not r.hint:HasFocus() then r.hint:SetText(s.spell and (bt(s.hint) or "") or (bt(s.text) or "")) end
      local bind = s.bind or (s.spell and U.bBindFor(b, s.spell))
      r.key:SetText(bind and (U.bKey(bind) or "bez klawisza") or "")
      r:Show()
      y = y + 32
    end
  end
  for i = n + 1, #CO.rows do CO.rows[i]:Hide() end
  CO.c:SetHeight(math.max(10, y))
end
X.secs.combo = { title = "Combo", order = 4, build = function(host)
  local f = CreateFrame("Frame", nil, host)
  f:SetAllPoints()
  CO.f = f
  tbar(f, {
    { "+ krok combo", function() X.pick("Nowy krok combo", { macros = true }, function(v)
        if not v then return end
        local m = v:match("^macro:(.+)$")
        table.insert(coList("steps"), m and { text = m, bind = "MACRO " .. m } or { spell = v, bind = U.bBindFor(B(), v) })
        dirty() CO.draw()
      end) end },
    { "+ krok ratunku", function() X.pick("Nowy krok ratunku", { macros = true }, function(v)
        if not v then return end
        local m = v:match("^macro:(.+)$")
        table.insert(coList("rescue"), m and { text = m, bind = "MACRO " .. m } or { spell = v, bind = U.bBindFor(B(), v) })
        dirty() CO.draw()
      end) end },
    { "+ tekst", function() table.insert(coList("steps"), { text = "nowa wskazówka" }) dirty() CO.draw() end },
  })
  local note = U.Para(f, 11, 700, C.faint)
  note:SetPoint("TOPLEFT", f, "TOPLEFT", 0, -36)
  note:SetText("Ściąga Combo na ekranie pokazuje te kroki. Klawisz bierze się z pasków buildu (sekcja Paski). Pole obok czaru to wskazówka, przy kroku tekstowym sam tekst.")
  local _, c = scroller(f, -62)
  CO.c = c
  c:SetWidth(760)
  return f
end, draw = function() CO.draw() end }

-- ================= Kolo =================
local KO = { rows = {} }
local function wheel() local b = B() b.wheel = b.wheel or {} return b.wheel end
local function koRow(i)
  local r = KO.rows[i]
  if r then return r end
  r = CreateFrame("Frame", nil, KO.c)
  r:SetHeight(30)
  r.ic = r:CreateTexture(nil, "ARTWORK") r.ic:SetSize(24, 24) r.ic:SetPoint("LEFT", 0, 0) r.ic:SetTexCoord(0.08, 0.92, 0.08, 0.92)
  r.sp = smallBtn(r, "", 200, function()
    X.pick("Czar na kole", {}, function(v)
      if not v then return end
      local w = wheel()[r.i]
      w[1] = v
      if not w[2] or w[2] == "" then w[2] = v end
      dirty() KO.draw()
    end)
  end)
  r.sp:SetPoint("LEFT", 30, 0)
  r.lab = input(r, 170, 22)
  r.lab:SetPoint("LEFT", r.sp, "RIGHT", 12, 0)
  r.lab:SetScript("OnTextChanged", function(self, user) if user and wheel()[r.i] then wheel()[r.i][2] = self:GetText() dirty() end end)
  r.up = smallBtn(r, "Wyżej", 56, function() moveIn(wheel(), r.i, -1) dirty() KO.draw() end)
  r.up:SetPoint("LEFT", r.lab, "RIGHT", 10, 0)
  r.dn = smallBtn(r, "Niżej", 56, function() moveIn(wheel(), r.i, 1) dirty() KO.draw() end)
  r.dn:SetPoint("LEFT", r.up, "RIGHT", 4, 0)
  r.del = smallBtn(r, "×", 24, function() table.remove(wheel(), r.i) dirty() KO.draw() end)
  r.del:SetPoint("LEFT", r.dn, "RIGHT", 4, 0)
  KO.rows[i] = r
  return r
end
function KO.draw()
  if not (B() and KO.f) then return end
  local list = wheel()
  for i, w in ipairs(list) do
    local r = koRow(i)
    r.i = i
    r:ClearAllPoints() r:SetPoint("TOPLEFT", KO.c, "TOPLEFT", 0, -(i - 1) * 32) r:SetWidth(KO.c:GetWidth())
    local first = type(w[1]) == "table" and w[1][1] or w[1]
    r.ic:SetTexture(U.bIcon(first) or 134400)
    r.sp:SetLabel(type(w[1]) == "table" and (first .. " (+" .. (#w[1] - 1) .. ")") or tostring(first))
    if not r.lab:HasFocus() then r.lab:SetText(w[2] or "") end
    r:Show()
  end
  for i = #list + 1, #KO.rows do KO.rows[i]:Hide() end
  KO.c:SetHeight(math.max(10, #list * 32))
end
X.secs.kolo = { title = "Koło", order = 5, build = function(host)
  local f = CreateFrame("Frame", nil, host)
  f:SetAllPoints()
  KO.f = f
  tbar(f, { { "+ pozycja", function()
    if #wheel() >= 16 then U.say("koło mieści 16 pozycji.") return end
    X.pick("Czar na kole", {}, function(v) if v then table.insert(wheel(), { v, v }) dirty() KO.draw() end end)
  end } })
  local note = U.Para(f, 11, 700, C.faint)
  note:SetPoint("TOPLEFT", f, "TOPLEFT", 0, -36)
  note:SetText("Koło szybkiego wyboru (klawisz koła w Grimuarze): czar i krótki podpis. Kolejność = kolejność na kole.")
  local _, c = scroller(f, -62)
  KO.c = c
  c:SetWidth(640)
  return f
end, draw = function() KO.draw() end }

-- ================= Makra =================
local MA = { rows = {} }
local function macros() local b = B() b.macros = b.macros or {} return b.macros end
local function renameRefs(old, new)
  if not old or old == new then return end
  local b = B()
  for _, d in ipairs(U.BAR_DEF) do
    for _, alts in pairs((b.bars or {})[d.key] or {}) do
      for k, a in ipairs(type(alts) == "table" and alts or {}) do if a == "macro:" .. old then alts[k] = "macro:" .. new end end
    end
  end
  if b.macroNeeds and b.macroNeeds[old] then b.macroNeeds[new], b.macroNeeds[old] = b.macroNeeds[old], nil end
end
local function maRow(i)
  local r = MA.rows[i]
  if r then return r end
  r = CreateFrame("Frame", nil, MA.c)
  r:SetHeight(78)
  r.name = input(r, 150, 24)
  r.name:SetPoint("TOPLEFT", 6, -2)
  r.name:SetMaxLetters(16)
  r.name:SetScript("OnEditFocusGained", function(self) r.oldName = self:GetText() end)
  r.name:SetScript("OnEditFocusLost", function(self)
    local m = macros()[r.i]
    if not m then return end
    local nn = self:GetText():gsub("^%s+", ""):gsub("%s+$", "")
    if nn == "" then self:SetText(m[1]) return end
    if nn ~= m[1] then renameRefs(m[1], nn) m[1] = nn dirty() end
  end)
  r.body = input(r, 470, 70, true)
  r.body:SetPoint("TOPLEFT", r.name, "TOPRIGHT", 12, 2)
  r.body:SetMaxLetters(255)
  r.body:SetScript("OnTextChanged", function(self, user)
    local m = macros()[r.i]
    if not m then return end
    if user then m[2] = self:GetText() dirty() end
    U.BorderColor(self, badMacro(self:GetText()) and C.danger or C.edge)
  end)
  r.del = smallBtn(r, "×", 24, function() table.remove(macros(), r.i) dirty() MA.draw() end)
  r.del:SetPoint("TOPLEFT", r.body, "TOPRIGHT", 8, 0)
  MA.rows[i] = r
  return r
end
function MA.draw()
  if not (B() and MA.f) then return end
  local list = macros()
  for i, m in ipairs(list) do
    local r = maRow(i)
    r.i = i
    r:ClearAllPoints() r:SetPoint("TOPLEFT", MA.c, "TOPLEFT", 0, -(i - 1) * 82) r:SetWidth(MA.c:GetWidth())
    if not r.name:HasFocus() then r.name:SetText(m[1] or "") end
    local body = type(m[2]) == "table" and table.concat(m[2], "\n") or tostring(m[2] or "")
    if not r.body:HasFocus() then r.body:SetText(body) end
    U.BorderColor(r.body, badMacro(body) and C.danger or C.edge)
    r:Show()
  end
  for i = #list + 1, #MA.rows do MA.rows[i]:Hide() end
  MA.c:SetHeight(math.max(10, #list * 82))
end
X.secs.makra = { title = "Makra", order = 6, build = function(host)
  local f = CreateFrame("Frame", nil, host)
  f:SetAllPoints()
  MA.f = f
  tbar(f, { { "+ makro", function()
    if #macros() >= 18 then U.say("build mieści 18 makr.") return end
    local n = 1
    local names = {}
    for _, m in ipairs(macros()) do names[m[1]] = true end
    while names["Makro" .. n] do n = n + 1 end
    table.insert(macros(), { "Makro" .. n, "#showtooltip\n/cast " })
    dirty() MA.draw()
  end } })
  local note = U.Para(f, 11, 700, C.faint)
  note:SetPoint("TOPLEFT", f, "TOPLEFT", 0, -36)
  note:SetText("Nazwa do 16 znaków, treść do 255. Bez /run, /script, /console i /dump (czerwona ramka: takie makro nie zapisze się). Na paski: sekcja Paski, „Makro: nazwa”.")
  local _, c = scroller(f, -62)
  MA.c = c
  c:SetWidth(680)
  return f
end, draw = function() MA.draw() end }

-- ================= Porady =================
local PO = { rows = {}, band = 1 }
local PVP_ORDER = { "WARRIOR", "ROGUE", "HUNTER", "MAGE", "WARLOCK", "PRIEST", "DRUID", "PALADIN", "SHAMAN" }
local CRE_ORDER = { "Humanoid", "Beast", "Undead", "Elemental", "Demon", "Dragonkin", "Giant", "Mechanical" }
local function poRow(i)
  local r = PO.rows[i]
  if r then return r end
  r = CreateFrame("Frame", nil, PO.c)
  r:SetHeight(30)
  r.t = U.Text(r, 13, "body", C.text) r.t:SetPoint("LEFT", 0, 0) r.t:SetWidth(130) r.t:SetJustifyV("MIDDLE")
  r.e = input(r, 600, 24)
  r.e:SetPoint("LEFT", 136, 0)
  r.e:SetMaxLetters(400)
  r.e:SetScript("OnTextChanged", function(self, user)
    if not user or not r.tbl then return end
    local t = self:GetText()
    r.tbl()[r.key] = t ~= "" and t or nil
    dirty()
  end)
  r.head = U.Text(r, 12, "title", C.goldDim) r.head:SetPoint("LEFT", 0, 0) r.head:SetJustifyV("MIDDLE")
  PO.rows[i] = r
  return r
end
function PO.draw()
  local b = B()
  if not (b and PO.f) then return end
  b.pvp = b.pvp or {}
  b.creatures = b.creatures or {}
  PO.f.b1:SetLabel((PO.band == 1 and "◆ " or "") .. "PvP do 39")
  PO.f.b40:SetLabel((PO.band == 40 and "◆ " or "") .. "PvP od 40")
  local n, y = 0, 0
  local function head(text)
    n = n + 1
    local r = poRow(n)
    r.tbl = nil
    r.t:Hide() r.e:Hide() r.head:Show() r.head:SetText(text)
    r:ClearAllPoints() r:SetPoint("TOPLEFT", PO.c, "TOPLEFT", 0, -y) r:SetWidth(PO.c:GetWidth())
    r:Show()
    y = y + 30
  end
  local function line(label, getTbl, key)
    n = n + 1
    local r = poRow(n)
    r.tbl, r.key = getTbl, key
    r.head:Hide() r.t:Show() r.e:Show()
    r.t:SetText(label)
    if not r.e:HasFocus() then r.e:SetText(bt(getTbl()[key]) or "") r.e:SetCursorPosition(0) end
    r:ClearAllPoints() r:SetPoint("TOPLEFT", PO.c, "TOPLEFT", 0, -y) r:SetWidth(PO.c:GetWidth())
    r:Show()
    y = y + 30
  end
  local band = PO.band
  local function pvpTbl() b.pvp[band] = b.pvp[band] or {} return b.pvp[band] end
  head(band == 1 and "PvP: porady na klasy (do 39 poziomu)" or "PvP: porady na klasy (od 40 poziomu)")
  for _, cls in ipairs(PVP_ORDER) do line(U.CLASS_PL[cls] or cls, pvpTbl, cls) end
  head("Stwory: porady na typy")
  local function creTbl() return b.creatures end
  for _, k in ipairs(CRE_ORDER) do line(U.CREATURE_PL[k] or k, creTbl, k) end
  for i = n + 1, #PO.rows do PO.rows[i]:Hide() end
  PO.c:SetHeight(math.max(10, y))
end
X.secs.porady = { title = "Porady", order = 7, build = function(host)
  local f = CreateFrame("Frame", nil, host)
  f:SetAllPoints()
  PO.f = f
  tbar(f, {
    { "PvP do 39", function() PO.band = 1 PO.draw() end, key = "b1" },
    { "PvP od 40", function() PO.band = 40 PO.draw() end, key = "b40" },
  })
  local note = U.Para(f, 11, 740, C.faint)
  note:SetPoint("TOPLEFT", f, "TOPLEFT", 0, -36)
  note:SetText("Porady pokazują się przy celu (PvP: klasa gracza wroga, stwory: typ moba). Puste pole = brak porady.")
  local _, c = scroller(f, -62)
  PO.c = c
  c:SetWidth(760)
  return f
end, draw = function() PO.draw() end }
