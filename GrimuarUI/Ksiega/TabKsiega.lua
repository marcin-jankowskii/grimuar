-- Grimuar UI: zakladka Ksiega (14.11, R24 P3/P6/P7; jak glosariusz Wiedzmina 3). Trzy strony:
-- * Bestiariusz: stwory, z ktorymi walczyles (KsiegaBestie.lua): poziomy, typ, czary, ucieczki, lupy, porada maga;
-- * Rywale: gracze Hordy ze starc (Spy, KsiegaRywale.lua): bilans, ostatnie starcie, rada na klase, Twoja notatka;
-- * Krainy: postep zadan w strefach (Questie, KsiegaKrainy.lua); od 15.11 (R30 P32) pod spodem karty rzadkich stworow
--   i skarbow strefy z Polestara (KsiegaRzadkie.lua).
local ADDON, U = ...
local C = U.C

local S = { page = "bestie", sel = {}, rows = {} }
local L_W = 360
local GOLD, MUTED, OK, TEXT = U.hex(C.gold), U.hex(C.muted), U.hex(C.ok), U.hex(C.text)

local function row(i)
  local r = S.rows[i]
  if r then return r end
  r = CreateFrame("Button", nil, S.list)
  r:SetHeight(44)
  local hl = r:CreateTexture(nil, "HIGHLIGHT") hl:SetAllPoints() hl:SetColorTexture(1, 1, 1, 0.05)
  r.selT = r:CreateTexture(nil, "BACKGROUND") r.selT:SetAllPoints() r.selT:SetColorTexture(C.gold[1], C.gold[2], C.gold[3], 0.10)
  r.t = U.Text(r, 14, "body", C.text) r.t:SetPoint("TOPLEFT", 10, -5)
  r.s = U.Text(r, 11, "body", C.muted) r.s:SetPoint("TOPLEFT", r.t, "BOTTOMLEFT", 0, -4)
  r.tag = U.Tag(r, "") r.tag:SetPoint("RIGHT", -8, 0)
  r:SetScript("OnClick", function(self) S.sel[S.page] = self.key U.ksiegaRefresh() end)
  S.rows[i] = r
  return r
end
local function fillList(items)
  local w = L_W - 28
  for i, it in ipairs(items) do
    local r = row(i)
    r.key = it.key
    r:SetWidth(w)
    r:ClearAllPoints()
    r:SetPoint("TOPLEFT", S.list, "TOPLEFT", 0, -(i - 1) * 46)
    r.t:SetText(it.title) r.t:SetWidth(w - 90)
    U.Color(r.t, it.col or C.text)
    r.s:SetText(it.sub or "") r.s:SetWidth(w - 20)
    r.tag:SetShown(it.tag ~= nil)
    if it.tag then r.tag:SetTag(it.tag, it.tagCol or C.goldDim) end
    r.selT:SetShown(S.sel[S.page] == it.key)
    r:Show()
  end
  for i = #items + 1, #S.rows do S.rows[i]:Hide() end
  S.list:SetHeight(math.max(10, #items * 46))
end

-- ---------- bestiariusz ----------
local function drawBestie()
  local list = U.bestiaryList and U.bestiaryList() or {}
  local items, pick = {}, nil
  for _, e in ipairs(list) do
    local lv = e.boss and "boss" or ((e.lmin and e.lmax) and (e.lmin == e.lmax and tostring(e.lmin) or (e.lmin .. "–" .. e.lmax)) or "?")
    items[#items + 1] = { key = e.id, title = e.name or ("#" .. e.id),
      sub = (U.BEAST_TYPE_PL[e.type or ""] or e.type or "?") .. " · poziom " .. lv .. " · zabite " .. (e.kills or 0),
      tag = e.cls and ({ elite = "elita", rare = "rzadki", rareelite = "rzadka elita", worldboss = "boss" })[e.cls] or nil,
      col = e.cls and C.gold or C.text }
    if S.sel.bestie == e.id then pick = e end
  end
  if not pick and list[1] then pick = list[1] S.sel.bestie = list[1].id end
  fillList(items)
  S.h:SetText("Bestiariusz (" .. #list .. ")")
  if not pick then
    S.det:Set(MUTED .. "Pusto. Każdy wrogi cel zapisuje się tu sam: poziomy, czary, ucieczki, łupy i porada maga.|r")
    return
  end
  local L = { GOLD .. (pick.name or "?") .. "|r" }
  local lv = pick.boss and "boss" or ((pick.lmin and pick.lmax) and (pick.lmin == pick.lmax and tostring(pick.lmin) or (pick.lmin .. "–" .. pick.lmax)) or "?")
  L[#L + 1] = (U.BEAST_TYPE_PL[pick.type or ""] or pick.type or "?") .. (pick.fam and (" (" .. pick.fam .. ")") or "") .. " · poziom " .. lv
    .. (pick.cls and (" · " .. (({ elite = "elita", rare = "rzadki", rareelite = "rzadka elita", worldboss = "boss" })[pick.cls] or pick.cls)) or "")
  L[#L + 1] = "Zabite: " .. (pick.kills or 0) .. "   ·   zabił Cię: " .. (pick.killedMe or 0) .. "   ·   uciekał: " .. (pick.flees or 0)
  local z = {}
  for k in pairs(pick.zones or {}) do z[#z + 1] = k end
  if #z > 0 then L[#L + 1] = MUTED .. "Gdzie: " .. table.concat(z, ", ") .. "|r" end
  local tip = U.bestiaryTip(pick)
  if tip then L[#L + 1] = "\n" .. GOLD .. "JAK WALCZYĆ|r" L[#L + 1] = tip end
  if (pick.flees or 0) > 0 then L[#L + 1] = "Ucieka przy niskim życiu: zatrzymaj go Frost Novą, zanim sprowadzi pomoc." end
  local casts = {}
  for k in pairs(pick.casts or {}) do casts[#casts + 1] = k end
  if #casts > 0 then
    L[#L + 1] = "\n" .. GOLD .. "RZUCA CZARY|r"
    L[#L + 1] = table.concat(casts, " · ") .. MUTED .. "  — przerwij Counterspellem.|r"
  end
  local loot = {}
  for id, n in pairs(pick.loot or {}) do loot[#loot + 1] = { id = id, n = n } end
  table.sort(loot, function(a, b) return a.n > b.n end)
  if #loot > 0 then
    L[#L + 1] = "\n" .. GOLD .. "WYPADŁO Z NIEGO|r"
    for i = 1, math.min(10, #loot) do L[#L + 1] = U.itemLabel(loot[i].id) .. MUTED .. " ×" .. loot[i].n .. "|r" end
  end
  S.det:Set(table.concat(L, "\n"))
end

-- ---------- rywale ----------
local function drawRywale()
  local list = U.rivalsList and U.rivalsList()
  S.h:SetText("Rywale")
  S.note:Hide() S.noteSave:Hide()
  if not list then
    fillList({})
    S.det:Set(MUTED .. "Rywali liczy Spy (Forever). Gdy Spy jest włączony, każde starcie z Hordą zapisze się tu samo.|r")
    return
  end
  local items, pick = {}, nil
  for _, r in ipairs(list) do
    items[#items + 1] = { key = r.name, title = r.name, sub = (r.clsPl or "?") .. (r.level and (" " .. r.level) or "") .. " · bilans " .. r.wins .. ":" .. r.loses,
      tag = r.kos and "KOS" or (r.rival and "rywal" or nil), tagCol = r.rival and C.danger or C.goldDim, col = r.rival and C.gold or C.text }
    if S.sel.rywale == r.name then pick = r end
  end
  if not pick and list[1] then pick = list[1] S.sel.rywale = list[1].name end
  fillList(items)
  if not pick then
    S.det:Set(MUTED .. "Jeszcze żadnych starć z Hordą. Rywal = ktoś, kto zabił Cię co najmniej 2 razy, albo ktoś z Twojej listy KOS w Spy.|r")
    return
  end
  local L = { GOLD .. pick.name .. "|r" }
  L[#L + 1] = (pick.clsPl or "?") .. (pick.race and (" · " .. pick.race) or "") .. (pick.level and (" · poziom " .. pick.level) or "") .. (pick.guild and (" · <" .. pick.guild .. ">") or "")
  L[#L + 1] = "Bilans: " .. OK .. pick.wins .. " wygranych|r · " .. U.hex(C.danger) .. pick.loses .. " przegranych|r"
  if pick.last then
    L[#L + 1] = MUTED .. "Ostatnie starcie: " .. U.fmtDate(pick.last.t or time()) .. ((U.rivalWhere(pick.last) and (", " .. U.rivalWhere(pick.last))) or "") .. "|r"
  end
  local tip = U.rivalTip(pick)
  if tip then L[#L + 1] = "\n" .. GOLD .. "RADA|r" L[#L + 1] = tip end
  L[#L + 1] = "\n" .. GOLD .. "TWOJA NOTATKA|r"
  S.det:Set(table.concat(L, "\n"))
  S.note:SetText(U.rivalNote(pick.name) or "")
  S.note.name = pick.name
  S.note:Show() S.noteSave:Show()
end

-- ---------- krainy ----------
local function drawKrainy()
  S.h:SetText("Krainy")
  S.note:Hide() S.noteSave:Hide()
  local list = U.realmsBook and U.call(U.realmsBook)
  if not list then
    fillList({})
    S.det:Set(MUTED .. "Księga krain liczy zadania z bazy Questie: włącz Questie.|r")
    return
  end
  local here = GetRealZoneText()
  local items, pick = {}, nil
  for _, z in ipairs(list) do
    local pct = z.total > 0 and math.floor(z.done / z.total * 100 + 0.5) or 0
    -- 15.11 (R30 P25): poziom strefy i groznosc z Polestara, w kolorze trudnosci
    local zi = U.zoneInfo and U.zoneInfo(z.ui, z.lmin, z.lmax)
    z.zi = zi
    items[#items + 1] = { key = z.name, title = z.name,
      sub = (zi and zi.text and ("strefa " .. zi.text .. " · ") or "") .. "zadania " .. z.done .. "/" .. z.total,
      tag = pct .. "%", tagCol = pct >= 100 and C.ok or (pct > 0 and C.gold or C.faint),
      col = z.name == here and C.gold or (zi and zi.mult > 1 and zi.col) or C.text }
    if S.sel.krainy == z.name then pick = z end
    if not S.sel.krainy and z.name == here then pick = z S.sel.krainy = z.name end
  end
  fillList(items)
  local done, total = 0, 0
  for _, z in ipairs(list) do done, total = done + z.done, total + z.total end
  local L = { GOLD .. "Wszystkie krainy|r   " .. done .. " / " .. total .. " zadań Przymierza dla maga (" .. (total > 0 and math.floor(done / total * 100) or 0) .. "%)" }
  if pick then
    local pct = pick.total > 0 and pick.done / pick.total or 0
    local bar = string.rep("■", math.floor(pct * 20 + 0.5)) .. string.rep("□", 20 - math.floor(pct * 20 + 0.5))
    L[#L + 1] = "\n" .. GOLD .. pick.name:upper() .. "|r"
    L[#L + 1] = bar .. "  " .. math.floor(pct * 100 + 0.5) .. "%"
    L[#L + 1] = "Zadania: " .. pick.done .. " z " .. pick.total .. " · poziomy zadań " .. (pick.lmin or "?") .. "–" .. (pick.lmax or "?")
    local zi = pick.zi
    if zi and zi.min then
      local hex = string.format("|cff%02x%02x%02x", zi.col[1] * 255, zi.col[2] * 255, zi.col[3] * 255)
      L[#L + 1] = "Poziom strefy: " .. hex .. zi.text .. "|r" .. (zi.src == "questy" and " (wg zadań)" or "")
      if zi.mult >= 20 then
        L[#L + 1] = MUTED .. "Za wysoko na Twój poziom: trasa Polestara omija tę strefę, a moby zabiją Cię w kilka sekund.|r"
      elseif zi.mult >= 3 then
        L[#L + 1] = MUTED .. "Groźna: moby o 3+ poziomy wyżej. Przechodź drogami, nie skracaj przez pola.|r"
      end
    end
    L[#L + 1] = "Rzadkie stwory spotkane: " .. (pick.rares or 0)
    L[#L + 1] = MUTED .. "Nie musisz robić wszystkiego: trasa Grimuara bierze tylko te, które się opłacają. 100% to wyzwanie na później.|r"
  end
  S.det:Set(table.concat(L, "\n"))
  -- 15.11 (R30 P32): rzadkie stwory i skarby strefy jako karty pod tekstem (KsiegaRzadkie.lua, Polestar.Rares)
  if pick and U.ksiegaRares then pcall(U.ksiegaRares, S.det, pick.ui) end
end

-- ---------- uklad ----------
local DRAW = { bestie = drawBestie, rywale = drawRywale, krainy = drawKrainy }
function U.ksiegaRefresh()
  if not (S.det and S.det:IsVisible()) then return end
  S.note:Hide() S.noteSave:Hide()
  if U.ksiegaRares then pcall(U.ksiegaRares, S.det, nil) end -- 15.11 (R30 P32): karty rzadkich tylko w Krainach
  local ok, e = pcall(DRAW[S.page])
  if not ok and U.logError then U.logError("ksiega/" .. S.page, e) end
end
local function show(p)
  S.page = p
  for k, b in pairs(S.tabs) do
    U.Color(b.label, k == p and C.gold or C.muted)
    U.BorderColor(b, k == p and C.gold or C.edge)
  end
  S.view:SetVerticalScroll(0)
  C_Timer.After(0, U.ksiegaRefresh)
end

local function build(page)
  S.tabs = {}
  local prev
  for _, d in ipairs({ { "bestie", "Bestiariusz" }, { "rywale", "Rywale" }, { "krainy", "Krainy" } }) do
    local b = U.Button(page, d[2], nil, 30)
    if prev then b:SetPoint("LEFT", prev, "RIGHT", 8, 0) else b:SetPoint("TOPLEFT", page, "TOPLEFT", 0, 0) end
    b:SetScript("OnClick", function() show(d[1]) end)
    S.tabs[d[1]] = b
    prev = b
  end
  local body = CreateFrame("Frame", nil, page)
  body:SetPoint("TOPLEFT", 0, -44) body:SetPoint("BOTTOMRIGHT")
  local left = U.Panel(body, 0.86, true)
  left:SetPoint("TOPLEFT") left:SetPoint("BOTTOMLEFT") left:SetWidth(L_W)
  S.h = U.H2(left, "Bestiariusz")
  S.h:SetPoint("TOPLEFT", 16, -14)
  S.view = CreateFrame("ScrollFrame", nil, left)
  S.view:SetPoint("TOPLEFT", S.h, "BOTTOMLEFT", 0, -10)
  S.view:SetPoint("BOTTOMRIGHT", -12, 12)
  S.list = CreateFrame("Frame", nil, S.view)
  S.list:SetSize(L_W - 28, 10)
  S.view:SetScrollChild(S.list)
  S.view:EnableMouseWheel(true)
  S.view:SetScript("OnMouseWheel", function(self, d)
    local max = math.max(0, S.list:GetHeight() - self:GetHeight())
    self:SetVerticalScroll(math.max(0, math.min(max, self:GetVerticalScroll() - d * 92)))
  end)
  S.det = U.TextPanel(body)
  S.det:SetPoint("TOPLEFT", left, "TOPRIGHT", 20, 0)
  S.det:SetPoint("BOTTOMRIGHT")
  -- notatka o rywalu
  S.note = CreateFrame("EditBox", nil, S.det, "InputBoxTemplate")
  S.note:SetSize(420, 28)
  S.note:SetAutoFocus(false)
  S.note:SetMaxLetters(200)
  S.note:SetPoint("BOTTOMLEFT", S.det, "BOTTOMLEFT", 24, 22)
  S.note:SetScript("OnEnterPressed", function(self) U.rivalNote(self.name, self:GetText()) self:ClearFocus() U.say("notatka zapisana.") end)
  S.note:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
  S.noteSave = U.Button(S.det, "Zapisz notatkę", nil, 28)
  S.noteSave:SetPoint("LEFT", S.note, "RIGHT", 10, 0)
  S.noteSave:SetScript("OnClick", function() U.rivalNote(S.note.name, S.note:GetText()) S.note:ClearFocus() U.say("notatka zapisana.") end)
  S.note:Hide() S.noteSave:Hide()
  show(S.page)
end

U.RegisterTab({
  id = "ksiega", order = 4.5, title = "Księga", keys = "",
  hints = { { { "LPM" }, "Wybierz wpis" } },
  note = "Bestiariusz i rywale zapisują się sami z walk",
  build = build,
  refresh = function() C_Timer.After(0, U.ksiegaRefresh) end,
  leave = function() if S.note then S.note:ClearFocus() end end,
})
