-- Grimuar UI: Ustawienia > Makra (15.11, wybor gracza: wlasny edytor makr w stylu huba). Lewo: makra ogolne (konto)
-- i tej postaci, z ikona; znaczek „build”, gdy makro lezy w paskach aktywnego buildu. Prawo: nazwa (do 16 znakow),
-- tresc (do 255), Zapisz, Nowe ogolne, Nowe postaci, Usun (drugi klik w 3 s), „Na pasek” (makro na kursor, hub sie
-- zamyka, klikasz slot paska). CreateMacro, EditMacro, DeleteMacro i PickupMacro tylko poza walka.
local ADDON, U = ...
local C = U.C
local G = U.G or {}

local UST = U.UST or { pages = {} }
U.UST = UST
local M = { sel = nil, rows = {} }
local MAXA = MAX_ACCOUNT_MACROS or 120

local function macros()
  local out = {}
  local na, nc = U.call(GetNumMacros)
  na, nc = U.num(na) or 0, U.num(nc) or 0
  for i = 1, na do
    local name, icon, body = U.call(GetMacroInfo, i)
    if name then out[#out + 1] = { i = i, name = name, icon = icon, body = body, char = false } end
  end
  for i = MAXA + 1, MAXA + nc do
    local name, icon, body = U.call(GetMacroInfo, i)
    if name then out[#out + 1] = { i = i, name = name, icon = icon, body = body, char = true } end
  end
  return out
end
local function inBuild(name)
  local b = G.Build and U.call(G.Build)
  for _, bar in pairs((b and b.bars) or {}) do
    for _, alts in pairs(bar) do
      for _, a in ipairs(type(alts) == "table" and alts or { alts }) do if a == "macro:" .. name then return true end end
    end
  end
  return false
end

local function row(i)
  local r = M.rows[i]
  if r then return r end
  r = CreateFrame("Button", nil, M.list)
  r:SetHeight(32)
  local hl = r:CreateTexture(nil, "HIGHLIGHT") hl:SetAllPoints() hl:SetColorTexture(1, 1, 1, 0.05)
  r.sel = U.Rect(r, C.gold, 0.12) r.sel:SetAllPoints()
  r.head = U.Text(r, 13, "title", C.gold) r.head:SetPoint("LEFT", 4, -2)
  r.ic = r:CreateTexture(nil, "ARTWORK") r.ic:SetSize(26, 26) r.ic:SetPoint("LEFT", 4, 0) r.ic:SetTexCoord(0.08, 0.92, 0.08, 0.92)
  r.t = U.Text(r, 14, "body", C.text) r.t:SetPoint("LEFT", 38, 0) r.t:SetJustifyV("MIDDLE")
  r.tag = U.Tag(r, "build", C.ok) r.tag:SetPoint("RIGHT", -8, 0)
  r:SetScript("OnClick", function(self) if self.m then M.sel = self.m.i M.draw() end end)
  M.rows[i] = r
  return r
end

local function selected()
  for _, m in ipairs(macros()) do if m.i == M.sel then return m end end
  return nil
end
local function canEdit()
  if InCombatLockdown() then U.say("makra zmieniam poza walką.") return false end
  return true
end

function M.draw()
  if not M.frame then return end
  local list = macros()
  local items = {}
  local acc, chr = {}, {}
  for _, m in ipairs(list) do if m.char then chr[#chr + 1] = m else acc[#acc + 1] = m end end
  items[#items + 1] = { head = "Ogólne (" .. #acc .. ")" }
  for _, m in ipairs(acc) do items[#items + 1] = m end
  items[#items + 1] = { head = "Tej postaci (" .. #chr .. ")" }
  for _, m in ipairs(chr) do items[#items + 1] = m end
  for i, it in ipairs(items) do
    local r = row(i)
    r:ClearAllPoints() r:SetPoint("TOPLEFT", M.list, "TOPLEFT", 0, -(i - 1) * 33) r:SetWidth(M.list:GetWidth() or 300)
    local head = it.head ~= nil
    r.head:SetShown(head) r.ic:SetShown(not head) r.t:SetShown(not head)
    r.m = not head and it or nil
    if head then r.head:SetText(it.head) r.tag:Hide() r.sel:Hide()
    else
      r.ic:SetTexture(it.icon or 134400)
      r.t:SetText(it.name)
      r.tag:SetShown(inBuild(it.name))
      r.sel:SetShown(it.i == M.sel)
    end
    r:Show()
  end
  for i = #items + 1, #M.rows do M.rows[i]:Hide() end
  M.list:SetHeight(#items * 33)
  local m = selected()
  if not M.name:HasFocus() then M.name:SetText(m and m.name or "") end
  if not M.body:HasFocus() then M.body:SetText(m and (m.body or "") or "") end
  M.edH:SetText(m and ("Makro: " .. m.name .. (m.char and " (tej postaci)" or " (ogólne)")) or "Wybierz makro albo utwórz nowe")
  for _, b in ipairs({ M.save, M.del, M.pick }) do b:SetEnabled(m ~= nil) end
  M.count:SetText(#(M.body:GetText() or "") .. " / 255")
end

local function create(perChar)
  if not canEdit() then return end
  local name = (M.name:GetText() or ""):gsub("^%s+", ""):gsub("%s+$", "")
  if name == "" then name = "Nowe" end
  local ok, idx = pcall(CreateMacro, name:sub(1, 16), "INV_MISC_QUESTIONMARK", M.body:GetText() or "", perChar)
  if ok and idx then M.sel = idx U.say("makro „" .. name .. "” utworzone.") else U.say("nie udało się utworzyć makra (limit ogólnych 120, postaci 18).") end
  M.draw()
end

UST.pages.makra = {
  title = "Makra",
  note = "Ogólne działają na każdej postaci, „tej postaci” tylko tutaj. Na pasek: makro trafia na kursor, kliknij slot.",
  build = function(parent)
    local f = CreateFrame("Frame", nil, parent)
    f:SetPoint("TOPLEFT", 16, -70) f:SetPoint("BOTTOMRIGHT", -16, 16)
    M.frame = f
    local lv = CreateFrame("ScrollFrame", nil, f)
    lv:SetPoint("TOPLEFT") lv:SetPoint("BOTTOMLEFT") lv:SetWidth(320)
    M.list = CreateFrame("Frame", nil, lv) M.list:SetSize(310, 10)
    lv:SetScrollChild(M.list)
    lv:EnableMouseWheel(true)
    lv:SetScript("OnMouseWheel", function(self, d)
      local max = math.max(0, M.list:GetHeight() - self:GetHeight())
      self:SetVerticalScroll(math.max(0, math.min(max, self:GetVerticalScroll() - d * 99)))
    end)
    local ed = CreateFrame("Frame", nil, f)
    ed:SetPoint("TOPLEFT", lv, "TOPRIGHT", 24, 0) ed:SetPoint("BOTTOMRIGHT")
    M.edH = U.H2(ed, "")
    M.edH:SetPoint("TOPLEFT", 0, -2)
    local nl = U.Label(ed, "NAZWA") nl:SetPoint("TOPLEFT", M.edH, "BOTTOMLEFT", 0, -14)
    M.name = CreateFrame("EditBox", nil, ed, "InputBoxTemplate")
    M.name:SetSize(260, 26) M.name:SetPoint("TOPLEFT", nl, "BOTTOMLEFT", 6, -4)
    M.name:SetAutoFocus(false) M.name:SetMaxLetters(16)
    M.name:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
    M.name:SetScript("OnEnterPressed", function(self) self:ClearFocus() end)
    local bl = U.Label(ed, "TREŚĆ") bl:SetPoint("TOPLEFT", M.name, "BOTTOMLEFT", -6, -14)
    M.body = CreateFrame("EditBox", nil, ed)
    M.body:SetMultiLine(true)
    M.body:SetFontObject(ChatFontNormal)
    M.body:SetTextInsets(8, 8, 6, 6)
    M.body:SetPoint("TOPLEFT", bl, "BOTTOMLEFT", 0, -4)
    M.body:SetPoint("RIGHT", ed, "RIGHT", 0, 0)
    M.body:SetHeight(220)
    M.body:SetAutoFocus(false)
    M.body:SetMaxLetters(255)
    M.body.bg = U.Rect(M.body, C.slot, 0.95) M.body.bg:SetAllPoints()
    U.Border(M.body, C.edge)
    M.body:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
    M.body:SetScript("OnTextChanged", function(self) M.count:SetText(#(self:GetText() or "") .. " / 255") end)
    M.count = U.Text(ed, 11, "body", C.faint)
    M.count:SetPoint("TOPRIGHT", M.body, "BOTTOMRIGHT", 0, -4)
    M.count:SetJustifyH("RIGHT")
    local prev
    local function btn(text, fn, primary)
      local b = U.Button(ed, text, nil, 28, primary)
      if prev then b:SetPoint("LEFT", prev, "RIGHT", 8, 0) else b:SetPoint("TOPLEFT", M.body, "BOTTOMLEFT", 0, -26) end
      b:SetScript("OnClick", function() pcall(fn) end)
      prev = b
      return b
    end
    M.save = btn("Zapisz", function()
      local m = selected()
      if not (m and canEdit()) then return end
      local name = (M.name:GetText() or ""):gsub("^%s+", ""):gsub("%s+$", "")
      if name == "" then name = m.name end
      local ok = pcall(EditMacro, m.i, name:sub(1, 16), m.icon or "INV_MISC_QUESTIONMARK", M.body:GetText() or "")
      U.say(ok and ("makro „" .. name .. "” zapisane.") or "nie udało się zapisać makra.")
      M.name:ClearFocus() M.body:ClearFocus()
      M.draw()
    end, true)
    btn("Nowe ogólne", function() create(false) end)
    btn("Nowe tej postaci", function() create(true) end)
    M.pick = btn("Na pasek", function()
      local m = selected()
      if not (m and canEdit()) then return end
      if U.Close then pcall(U.Close) end
      C_Timer.After(0.05, function() pcall(PickupMacro, m.i) U.say("makro na kursorze: kliknij slot paska akcji.") end)
    end)
    M.del = btn("Usuń", function()
      local m = selected()
      if not (m and canEdit()) then return end
      if M.delAt and GetTime() - M.delAt < 3 and M.delIdx == m.i then
        M.delAt = nil
        pcall(DeleteMacro, m.i)
        U.say("makro „" .. m.name .. "” usunięte.")
        M.sel = nil
        M.draw()
      else
        M.delAt, M.delIdx = GetTime(), m.i
        U.say("kliknij „Usuń” jeszcze raz w ciągu 3 s, żeby usunąć „" .. m.name .. "”.")
      end
    end)
    local hint = U.Para(ed, 12, 520, C.faint)
    hint:SetPoint("TOPLEFT", M.save, "BOTTOMLEFT", 0, -14)
    hint:SetText("Makra buildu (Buildy > Edytuj > Makra) Grimuar zakłada sam przy treningu; tu zmieniasz makra w grze. „build” = makro leży na paskach aktywnego buildu.")
    return f
  end,
  draw = function() M.draw() end,
  search = function(q)
    local out = {}
    for _, m in ipairs(macros()) do
      if m.name:lower():find(q, 1, true) or (m.body or ""):lower():find(q, 1, true) then
        out[#out + 1] = { kind = "action", label = "Makro: " .. m.name, btn = "Otwórz",
          fn = function() M.sel = m.i if U.ustawieniaOpen then U.ustawieniaOpen("makra") end end }
      end
    end
    return out
  end,
}

local ev = CreateFrame("Frame")
ev:RegisterEvent("UPDATE_MACROS")
ev:SetScript("OnEvent", function() if M.frame and M.frame:IsVisible() then pcall(M.draw) end end)
