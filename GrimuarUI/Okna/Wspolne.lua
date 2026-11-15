-- Grimuar UI: wspolny szkielet okien Grimuara w miejsce okien gry i ForeverSkin (15.11, plan R29 etap 2 i 3).
-- U.Okno(def) buduje okno w stylu huba (ciemny braz, zlote rogi, tytul Alegreya SC, × i „klasyczne okno”):
--   def = { name, width, height, title, hosts = { "ForeverSkinMerchantFrame", "MerchantFrame" }, onClose = fn, key = "kupiec" }
-- okno:Open() przyczepia sie do pierwszego widocznego okna z hosts (wieksze od niego, wiec przykrywa je calkiem i lapie
-- kazde klikniecie), daje mu przezroczystosc 0 (nic wiecej w nim nie zmieniamy); okno:Close() oddaje przezroczystosc.
-- „Klasyczne okno” pokazuje okno gry do konca tej wizyty. Wylaczenie na stale: GrimuarUIDB.oknaOff[key] (/hub okna).
local ADDON, U = ...
local C = U.C

local function db() return U.db() end

-- 15.11 autotest (/gr test, GrimuarUI\Hub\Autotest.lua): surowe dane z pierwszej wizyty u NPC, zeby sprawdzic,
-- czy klient Forever zwraca to, czego okna sie spodziewaja (kolejnosc wartosci, zakladki banku). Czyta je Claude.
function U.raw(fn, ...)
  if type(fn) ~= "function" then return "brak funkcji" end
  local r = (function(...) return { n = select("#", ...), ... } end)(pcall(fn, ...))
  if not r[1] then return "błąd: " .. tostring(r[2]) end
  local parts = {}
  for i = 2, r.n do parts[#parts + 1] = tostring(r[i]) end
  return table.concat(parts, " | ")
end
function U.diag(key, t)
  local d = db()
  d.diag = d.diag or {}
  t = t or {}
  t.at = date("%Y-%m-%d %H:%M")
  t.version = U.version and U.version() or nil
  d.diag[key] = t
end
function U.oknoOn(key)
  local d = db()
  return not (d.oknaOff and d.oknaOff[key])
end

local function hostFrames(names)
  local out = {}
  for _, n in ipairs(names or {}) do
    local f = _G[n]
    if f then out[#out + 1] = f end
  end
  return out
end

function U.Okno(def)
  local F = CreateFrame("Frame", def.name, UIParent)
  F:SetSize(def.width or 1000, def.height or 600)
  F:SetFrameStrata("DIALOG")
  F:SetToplevel(true)
  F:EnableMouse(true)
  F:SetClampedToScreen(true)
  F:Hide()
  F.bg = U.Rect(F, C.bg, 0.97) F.bg:SetAllPoints()
  U.Border(F, C.edge, 0.7)
  U.Corners(F, C.gold, 16, 2)
  F.title = U.Text(F, 22, "title", C.gold)
  F.title:SetPoint("TOPLEFT", 22, -16)
  F.title:SetText(def.title or "")
  F.sub = U.Text(F, 12, "body", C.muted)
  F.sub:SetPoint("LEFT", F.title, "RIGHT", 14, -2)
  F.close = U.Button(F, "×", 26, 24)
  F.close:SetPoint("TOPRIGHT", -10, -10)
  F.classic = U.Button(F, "klasyczne okno", nil, 24)
  F.classic:SetPoint("RIGHT", F.close, "LEFT", -8, 0)
  F.def = def
  F.hosts = def.hosts or {}

  function F:HostsAlpha(a)
    for _, h in ipairs(hostFrames(self.hosts)) do pcall(h.SetAlpha, h, a) end
  end
  function F:Open()
    if self.classicNow or not U.oknoOn(def.key) then return false end
    local host
    for _, h in ipairs(hostFrames(self.hosts)) do if h:IsShown() and h:GetLeft() then host = h break end end
    self:ClearAllPoints()
    if host then self:SetPoint("TOPLEFT", host, "TOPLEFT", -10, 30)
    else self:SetPoint("TOPLEFT", UIParent, "TOPLEFT", 8, -86) end
    self:SetWidth(math.min(def.width or 1000, (UIParent:GetWidth() or 1400) - 16))
    self:HostsAlpha(0)
    self:Show()
    self:Raise()
    return true
  end
  -- koniec wizyty (zdarzenie gry): oddaje przezroczystosc i zeruje „klasyczne”
  function F:Finish()
    self:Hide()
    self:HostsAlpha(1)
    self.classicNow = nil
  end
  F.classic:SetScript("OnClick", function()
    F.classicNow = true
    F:Hide()
    F:HostsAlpha(1)
  end)
  F.close:SetScript("OnClick", function()
    if def.onClose then pcall(def.onClose) end
    F:Finish()
  end)
  -- blad rysowania: wraca okno gry, Grimuar mowi raz
  function F:Fail(err)
    self:Hide()
    self:HostsAlpha(1)
    if not self.errSaid then self.errSaid = true U.say((def.title or "okno") .. " Grimuara: " .. tostring(err) .. " (zostaje okno gry).") end
    local d = db()
    d.oknaFails = d.oknaFails or {}
    d.oknaFails[def.key or def.name or "?"] = { at = date("%Y-%m-%d %H:%M"), err = tostring(err):sub(1, 300), version = U.version and U.version() or nil }
    if U.logError then pcall(U.logError, "okno " .. tostring(def.key), err) end
  end
  return F
end

-- przewijana lista z pula wierszy: U.OknoList(parent, rowH, makeRow) -> list z :SetCount(n, fill)
function U.OknoList(parent, rowH, makeRow)
  local v = CreateFrame("ScrollFrame", nil, parent)
  local c = CreateFrame("Frame", nil, v)
  c:SetSize(400, 10)
  v:SetScrollChild(c)
  v:EnableMouseWheel(true)
  v:SetScript("OnMouseWheel", function(self, d)
    local max = math.max(0, c:GetHeight() - self:GetHeight())
    self:SetVerticalScroll(math.max(0, math.min(max, self:GetVerticalScroll() - d * rowH * 3)))
  end)
  v.rows, v.child = {}, c
  function v:Fill(n, fill)
    local w = self:GetWidth() or 400
    c:SetWidth(w)
    for i = 1, n do
      local r = self.rows[i]
      if not r then r = makeRow(c) self.rows[i] = r end
      r:ClearAllPoints()
      r:SetPoint("TOPLEFT", c, "TOPLEFT", 0, -(i - 1) * (rowH + 2))
      r:SetWidth(w)
      r:Show()
      fill(r, i)
    end
    for i = n + 1, #self.rows do self.rows[i]:Hide() end
    c:SetHeight(math.max(10, n * (rowH + 2)))
  end
  return v
end

-- wiersz towaru / uslugi: ikona, nazwa, podpis, prawy napis, tlo i podswietlenie; klik -> row.onClick(button)
function U.OknoRow(parent, h)
  local r = CreateFrame("Button", nil, parent)
  r:SetHeight(h or 40)
  r:RegisterForClicks("LeftButtonUp", "RightButtonUp")
  r.bg = U.Rect(r, C.panel2, 0.55) r.bg:SetAllPoints()
  local hl = r:CreateTexture(nil, "HIGHLIGHT") hl:SetAllPoints() hl:SetColorTexture(C.gold[1], C.gold[2], C.gold[3], 0.08)
  r.slot = U.Slot(r, (h or 40) - 6)
  r.slot:SetPoint("LEFT", 3, 0)
  r.slot:EnableMouse(false)
  r.t = U.Text(r, 13, "body", C.text)
  r.t:SetPoint("TOPLEFT", r.slot, "TOPRIGHT", 10, -3)
  r.t:SetPoint("RIGHT", r, "RIGHT", -150, 0)
  r.s = U.Text(r, 11, "body", C.faint)
  r.s:SetPoint("TOPLEFT", r.t, "BOTTOMLEFT", 0, -3)
  r.s:SetPoint("RIGHT", r, "RIGHT", -150, 0)
  r.why = U.Text(r, 11, "body", C.ok)
  r.why:SetPoint("RIGHT", r, "RIGHT", -96, 0)
  r.why:SetJustifyH("RIGHT")
  r.why:SetJustifyV("MIDDLE")
  r.r = U.Text(r, 12, "body", C.text)
  r.r:SetPoint("RIGHT", r, "RIGHT", -10, 0)
  r.r:SetJustifyH("RIGHT")
  r.r:SetJustifyV("MIDDLE")
  r:SetScript("OnClick", function(self, button) if self.onClick then pcall(self.onClick, button) end end)
  r:SetScript("OnEnter", function(self)
    if not self.tip then return end
    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
    pcall(self.tip, GameTooltip)
    GameTooltip:Show()
  end)
  r:SetScript("OnLeave", function() GameTooltip:Hide() end)
  return r
end

-- /hub okna <nazwa>: wlacza i wylacza okno Grimuara (kupiec, trener, poczta, bank, profesja, lup, rzuty)
function U.oknaCmd(key)
  local d = db()
  d.oknaOff = d.oknaOff or {}
  if not key or key == "" then
    U.say("okna Grimuara: /hub okna kupiec|trener|poczta|bank|profesja|lup|rzuty przełącza okno Grimuara albo okno gry.")
    return
  end
  d.oknaOff[key] = not d.oknaOff[key] or nil
  U.say(key .. ": " .. (d.oknaOff[key] and "okno gry." or "okno Grimuara."))
end
if U.G then U.G.oknaCmd = U.oknaCmd end
