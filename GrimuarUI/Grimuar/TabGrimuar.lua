-- Grimuar UI: zakladka Grimuar (makieta 14.11 „Hub · Grimuar”). Same prawdziwe dane Grimuar Setup:
-- Teraz = pierwszy krok planu (G.buildSteps, to samo co dok), Rozwoj = alarmy z Rozwoj.lua (G.rozwojSteps),
-- Trasa = odcinki G.TRASA z biezacym (G.trasaLeg, G.trasaText), Postep = poziom, tempo, cel zlota, sesja.
-- Przycisk kroku zamyka hub i robi to, co w doku (strzalka, Polestar, torby).
local ADDON, U = ...
local G, C = U.G, U.C

local S = {}
local ROWS, LEGS = 6, 16

local function stepButton(b, spec)
  if not spec then b:Hide() return end
  b:SetLabel(spec[1] or "")
  b:SetScript("OnClick", function() if type(spec[2]) == "function" then U.OpenGame(spec[2]) end end)
  b:Show()
end

local function build(page)
  -- ---------- lewa: Teraz i Rozwoj ----------
  local L = CreateFrame("Frame", nil, page)
  L:SetPoint("TOPLEFT") L:SetPoint("BOTTOMLEFT") L:SetWidth(360)
  L:SetClipsChildren(true)
  local h = U.H2(L, "Teraz")
  h:SetPoint("TOPLEFT", 0, -2)
  local card = U.Panel(L, 0.55, true, C.edge)
  card:SetPoint("TOPLEFT", h, "BOTTOMLEFT", 0, -10)
  card:SetWidth(360)
  card.lab = U.Label(card, "Krok planu")
  card.lab:SetPoint("TOPLEFT", 14, -12)
  card.title = U.Para(card, 17, 332, C.text, "title")
  card.title:SetPoint("TOPLEFT", card.lab, "BOTTOMLEFT", 0, -6)
  card.why = U.Para(card, 12, 332, C.muted)
  card.why:SetPoint("TOPLEFT", card.title, "BOTTOMLEFT", 0, -6)
  card.b1 = U.Button(card, "Prowadź", nil, 28, true)
  card.b2 = U.Button(card, "", nil, 28)
  card.b1:SetPoint("TOPLEFT", card.why, "BOTTOMLEFT", 0, -12)
  card.b2:SetPoint("LEFT", card.b1, "RIGHT", 8, 0)
  S.card = card
  S.tH = h
  -- 15.11 (R30 P03): karta „Teraz wg Polestara” pod krokiem planu (GrimuarPolestar.lua); pozycje ustawia refreshData
  S.psNow = U.psNowWidget and U.psNowWidget(L, 360)

  S.rozH = U.H2(L, "Rozwój")
  S.rozH:SetPoint("TOPLEFT", card, "BOTTOMLEFT", 0, -20)
  S.rozTag = U.Tag(L, "")
  S.rozTag:SetPoint("TOPRIGHT", S.rozH, "TOPLEFT", 360, 2)
  S.rows = {}
  for i = 1, ROWS do
    local r = U.Panel(L, 0.45, false)
    r:SetWidth(360)
    r.dot = U.Diamond(r, 12, C.danger, false)
    r.dot:SetPoint("TOPLEFT", 10, -10)
    r.text = U.Para(r, 13, 250, C.text)
    r.text:SetPoint("TOPLEFT", r.dot, "TOPRIGHT", 8, 0)
    r.btn = U.Button(r, "", nil, 22)
    r.btn:SetPoint("TOPRIGHT", r, "TOPRIGHT", -8, -7)
    r:EnableMouse(true)
    r:SetScript("OnEnter", function(self)
      if not self.why or self.why == "" then return end
      GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
      GameTooltip:SetText(self.short or "", 1, 1, 1)
      GameTooltip:AddLine(self.why, 0.85, 0.82, 0.75, true)
      GameTooltip:Show()
    end)
    r:SetScript("OnLeave", function() GameTooltip:Hide() end)
    S.rows[i] = r
  end
  S.optional = U.Para(L, 12, 360, C.faint)

  -- ---------- prawa: Postep ----------
  local R = CreateFrame("Frame", nil, page)
  R:SetPoint("TOPRIGHT") R:SetPoint("BOTTOMRIGHT") R:SetWidth(320)
  local ph = U.H2(R, "Postęp")
  ph:SetPoint("TOPLEFT", 0, -2)
  local lv = U.KV(R, 320, 14)
  lv:SetPoint("TOPLEFT", ph, "BOTTOMLEFT", 0, -10)
  S.lv = lv
  S.lvBar = U.Bar(R, 7, C.gold)
  S.lvBar:SetPoint("TOPLEFT", lv, "BOTTOMLEFT", 0, -4)
  S.lvBar:SetWidth(320)
  S.tempo = U.Para(R, 12, 320, C.muted)
  S.tempo:SetPoint("TOPLEFT", S.lvBar, "BOTTOMLEFT", 0, -6)
  local gk = U.KV(R, 320, 14)
  gk:SetPoint("TOPLEFT", S.tempo, "BOTTOMLEFT", 0, -16)
  S.gold = gk
  S.goldBar = U.Bar(R, 7, C.gold)
  S.goldBar:SetPoint("TOPLEFT", gk, "BOTTOMLEFT", 0, -4)
  S.goldBar:SetWidth(320)
  S.goldNote = U.Para(R, 12, 320, C.muted)
  S.goldNote:SetPoint("TOPLEFT", S.goldBar, "BOTTOMLEFT", 0, -6)
  local box = U.Panel(R, 0.45, false)
  box:SetPoint("TOPLEFT", S.goldNote, "BOTTOMLEFT", 0, -18)
  box:SetSize(320, 30 + 5 * 20 + 10)
  local bl = U.Label(box, "Ta sesja")
  bl:SetPoint("TOPLEFT", 12, -10)
  S.sess = {}
  local prev = bl
  for i = 1, 5 do
    local r = U.KV(box, 296, 13)
    r:SetPoint("TOPLEFT", prev, "BOTTOMLEFT", 0, i == 1 and -6 or 0)
    S.sess[i] = r
    prev = r
  end
  local endBtn = U.Button(R, "Kończę grę — podsumuj", 320, 30)
  endBtn:SetPoint("BOTTOMLEFT", R, "BOTTOMLEFT", 0, 0)
  endBtn:SetScript("OnClick", function() if G.showSessionEnd then U.OpenGame(G.showSessionEnd) end end)
  local fullBtn = U.Button(R, "Pełne okno Grimuara (Shift+G)", 320, 30)
  fullBtn:SetPoint("BOTTOMLEFT", endBtn, "TOPLEFT", 0, 8)
  fullBtn:SetScript("OnClick", function()
    if SlashCmdList.GRIMUAR then U.OpenGame(function() SlashCmdList.GRIMUAR("") end) end
  end)
  -- 15.11 (R30 P34, P11): miedzy sesja a przyciskami karty z Polestara: ulepszenia przed Toba (EkwipunekPolestar.lua)
  -- i questy klasowe maga (GrimuarPolestar.lua); panel przewijany kolkiem
  S.extra = U.Blocks(R)
  S.extra:SetPoint("TOPLEFT", box, "BOTTOMLEFT", 0, -14)
  S.extra:SetPoint("BOTTOMRIGHT", fullBtn, "TOPRIGHT", 0, 10)
  S.extra.bg:SetAlpha(0.5)
  S.extra.view:ClearAllPoints()
  S.extra.view:SetPoint("TOPLEFT", 12, -10)
  S.extra.view:SetPoint("BOTTOMRIGHT", -8, 8)

  -- ---------- srodek: Trasa ----------
  local M = CreateFrame("Frame", nil, page)
  M:SetPoint("TOPLEFT", L, "TOPRIGHT", 36, 0)
  M:SetPoint("BOTTOMRIGHT", R, "BOTTOMLEFT", -36, 0)
  M:SetClipsChildren(true)
  S.M = M
  local th = U.H2(M, "Trasa Grimuara")
  th:SetPoint("TOPLEFT", 0, -2)
  local ts = U.Text(M, 12, "body", C.muted)
  ts:SetPoint("LEFT", th, "RIGHT", 12, 0)
  ts:SetText("odcinki z przewodnikami Polestara")
  local spine = M:CreateTexture(nil, "BACKGROUND")
  spine:SetColorTexture(C.edge[1], C.edge[2], C.edge[3], 0.8)
  spine:SetWidth(1)
  S.spine = spine
  S.legs = {}
  for i = 1, LEGS do
    local r = CreateFrame("Frame", nil, M)
    r:SetSize(300, 26)
    r:SetPoint("TOPLEFT", th, "BOTTOMLEFT", 0, -12 - (i - 1) * 26)
    r.bg = U.Rect(r, C.gold, 0.09)
    r.bg:SetAllPoints()
    r.dot = U.Diamond(r, 13, C.edge, false)
    r.dot:SetPoint("LEFT", 4, 0)
    r.lv = U.Text(r, 12, "body", C.faint)
    r.lv:SetPoint("LEFT", r.dot, "RIGHT", 10, 0)
    r.lv:SetJustifyV("MIDDLE")
    r.name = U.Text(r, 14, "body", C.text)
    r.name:SetPoint("LEFT", r, "LEFT", 92, 0)
    r.name:SetJustifyV("MIDDLE")
    S.legs[i] = r
  end
  S.legH = U.H2(M, "Ten odcinek")
  S.legLines = {}
  S.polestar = U.Button(M, "Okno Polestara (Shift+J)", nil, 28)
  S.polestar:SetScript("OnClick", function() if GrimuarPolestar then U.OpenGame(GrimuarPolestar) end end)
end

local function minutesText(m)
  m = math.floor(m or 0)
  if m < 60 then return m .. " min" end
  return math.floor(m / 60) .. " h " .. (m % 60) .. " min"
end

local function refreshData()
  local lvl = UnitLevel("player") or 1

  -- Teraz
  local steps = U.call(G.buildSteps) or {}
  local st = steps[1]
  local card = S.card
  if st then
    card.title:SetText(st.text or "")
    card.why:SetText(st.why or "")
    stepButton(card.b1, st.btns and st.btns[1])
    stepButton(card.b2, st.btns and st.btns[2])
  else
    card.title:SetText("Plan pusty — graj według Polestara.")
    card.why:SetText("")
    card.b1:Hide() card.b2:Hide()
  end
  local ch = 12 + 12 + 6 + card.title:GetStringHeight() + 6 + card.why:GetStringHeight() + (card.b1:IsShown() and (12 + 28) or 0) + 14
  card:SetHeight(math.floor(ch + 0.5))
  -- 15.11 (R30 P03): karta „Teraz wg Polestara” (GrimuarPolestar.lua); ogolny krok planu „idź za strzałką Polestar”
  -- zastepuje sama, wiec wtedy karta planu znika, a Polestar pokazuje do 4 celow
  local psH = 0
  if S.psNow then
    local generic = (not st) or st.key == "polestar"
    local okD, hh = pcall(S.psNow.Draw, S.psNow, generic and 4 or 3)
    psH = okD and hh or 0
    card:SetShown(not (generic and psH > 0))
    S.psNow:ClearAllPoints()
    if card:IsShown() then S.psNow:SetPoint("TOPLEFT", card, "BOTTOMLEFT", 0, -14)
    else S.psNow:SetPoint("TOPLEFT", S.tH, "BOTTOMLEFT", 0, -10) end
  end
  S.rozH:ClearAllPoints()
  S.rozH:SetPoint("TOPLEFT", psH > 0 and S.psNow or card, "BOTTOMLEFT", 0, -20)

  -- Rozwoj
  local items = {}
  if G.rozwojSteps then
    pcall(G.rozwojSteps, function(key, text, why, btns) items[#items + 1] = { key = key, text = text, why = why, btns = btns } end)
  end
  S.rozTag:SetTag(#items == 0 and "wszystko gotowe" or (#items .. (#items == 1 and " sprawa" or (#items < 5 and " sprawy" or " spraw"))), #items == 0 and C.ok or C.danger)
  local prev = S.rozH
  for i, r in ipairs(S.rows) do
    local it = items[i]
    if it then
      r.text:SetText(it.text or "")
      r.short, r.why = it.text, it.why
      local b = it.btns and it.btns[1]
      if b then stepButton(r.btn, b) r.text:SetWidth(250) else r.btn:Hide() r.text:SetWidth(320) end
      r:SetHeight(math.max(22, r.text:GetStringHeight()) + 16)
      r:ClearAllPoints()
      r:SetPoint("TOPLEFT", prev, "BOTTOMLEFT", 0, i == 1 and -10 or -6)
      r:Show()
      prev = r
    else
      r:Hide()
    end
  end
  local opt = U.call(G.optionalTraining)
  local names = {}
  if type(opt) == "table" then
    for _, o in ipairs(opt) do names[#names + 1] = type(o) == "table" and tostring(o[1] or o.name or "") or tostring(o) end
  end
  S.optional:ClearAllPoints()
  S.optional:SetPoint("TOPLEFT", prev, "BOTTOMLEFT", 0, -12)
  S.optional:SetText(#names > 0 and ("Opcjonalnie u trenera: " .. table.concat(names, ", ")) or "")

  -- Trasa
  local legs = G.TRASA or {}
  local cur = U.call(G.trasaLeg, lvl)
  local shown = 0
  local rowW = math.max(200, math.floor((S.M:GetWidth() or 0) - 36))
  for i, r in ipairs(S.legs) do
    r:SetWidth(rowW)
    local leg = legs[i]
    if leg then
      shown = i
      local now = cur == leg or (cur and cur[1] == leg[1] and cur[3] == leg[3])
      local done = not now and (leg[2] or 0) < lvl
      r.lv:SetText((leg[1] or "?") .. "–" .. (leg[2] or "?"))
      r.name:SetText("Rozdział " .. i .. ": " .. (leg[3] or "")) -- 14.11: trasa jako rozdzialy (TrasaRozdzialy.lua)
      r.bg:SetShown(now)
      r.dot:Set(now and C.gold or (done and C.ok or C.edge), now or done)
      U.Color(r.name, now and C.gold or (done and C.muted or C.text))
      r:Show()
    else
      r:Hide()
    end
  end
  S.spine:ClearAllPoints()
  if shown > 1 then
    S.spine:SetPoint("TOP", S.legs[1].dot, "CENTER", 0, 0)
    S.spine:SetPoint("BOTTOM", S.legs[shown].dot, "CENTER", 0, 0)
    S.spine:Show()
  else
    S.spine:Hide()
  end
  local last = S.legs[math.max(1, shown)]
  S.legH:ClearAllPoints()
  S.legH:SetPoint("TOPLEFT", last, "BOTTOMLEFT", 0, -22)
  local width = math.max(200, (S.M:GetWidth() or 400) - 4)
  local lines = (cur and U.call(G.trasaText, cur)) or {}
  local prevL = S.legH
  for i = 1, math.max(#lines, #S.legLines) do
    local fs = S.legLines[i]
    if not fs then fs = U.Para(S.M, 13, width, C.text) S.legLines[i] = fs end
    if lines[i] then
      fs:SetWidth(width)
      fs:SetText(lines[i])
      U.Color(fs, i == 1 and C.text or C.muted)
      fs:ClearAllPoints()
      fs:SetPoint("TOPLEFT", prevL, "BOTTOMLEFT", 0, i == 1 and -8 or -5)
      fs:Show()
      prevL = fs
    else
      fs:Hide()
    end
  end
  S.legH:SetShown(#lines > 0)
  S.polestar:ClearAllPoints()
  S.polestar:SetPoint("TOPLEFT", prevL, "BOTTOMLEFT", 0, -14)

  -- Postep
  S.lv:Set("Poziom", lvl .. " / 60", C.gold)
  S.lvBar:SetValue(lvl / 60)
  local tempo = U.call(G.tempoLine)
  if type(tempo) == "table" then tempo = table.concat(tempo, " · ") end
  S.tempo:SetText(type(tempo) == "string" and tempo or "")
  local t = U.call(G.goldTarget)
  local now = (U.call(G.goldNow)) or ((GetMoney() or 0) / 10000)
  local function g(x) return (x >= 10 and tostring(math.floor(x + 0.5)) or (string.format("%.1f", x):gsub("%.", ","))) .. " g" end
  if type(t) == "table" and t[2] then
    S.gold:Set("Złoto na " .. tostring(t[1]) .. " poziom", g(now) .. " / " .. g(t[2]))
    S.goldBar:SetValue(now / t[2])
    S.goldNote:SetText((t[3] and ("cel " .. g(t[2]) .. "–" .. g(t[3]) .. ": ") or "") .. tostring(t[4] or ""))
  else
    S.gold:Set("Złoto", g(now))
    S.goldBar:SetValue(0)
    S.goldNote:SetText("")
  end
  local SS = G.S or {}
  local mins = U.call(G.sessionMinutes) or 0
  S.sess[1]:Set("Czas", minutesText(mins))
  S.sess[2]:Set("Poziomy", (SS.level0 and (SS.level0 .. " → ") or "") .. lvl)
  S.sess[3]:Set("Doświadczenie", "+" .. U.thousands(SS.xpGained or 0))
  S.sess[4]:Set("Zgony", tostring(type(SS.deaths) == "table" and #SS.deaths or 0))
  local money = (SS.money0 and G.fmtMoney) and U.call(G.fmtMoney, (GetMoney() or 0) - SS.money0) or "—"
  S.sess[5]:Set("Złoto", money or "—")

  -- 15.11 (R30 P34, P11): ulepszenia przed Toba i questy klasowe (karty z Polestara, liczone z pamiecia)
  local p = S.extra
  if p then
    p:Begin(true)
    local any = false
    local up = U.psUpgradeCards and U.call(U.psUpgradeCards, 2) or {}
    if #up > 0 then
      any = true
      p:Head("Przed Tobą", "ulepszenia na trasie")
      p:Cards(up, { cols = 1 })
    end
    local cq, cqDone = {}, 0
    if U.psClassCards then
      local okC, a, b = pcall(U.psClassCards, 4)
      if okC then cq, cqDone = a or {}, b or 0 end
    end
    if #cq > 0 then
      any = true
      p:Head("Questy klasowe", cqDone > 0 and ("zrobione: " .. cqDone) or "Polestar")
      p:Cards(cq, { cols = 1 })
    end
    if not any then p:Para(_G.Polestar and "Polestar: na razie bez ulepszeń na trasie i bez questów klasowych do wzięcia." or "Ulepszenia na trasie i questy klasowe pokazuje Polestar (włącz go na liście addonów).", C.faint, 12) end
    p:End()
  end
end

-- 15.11 (R30 P03): zamiast tykania co 3 s odswiezanie na komunikaty Polestara (U.onPolestar, Hub\PolestarSzyna.lua)
-- i zdarzenia gry, zebrane w jedno odswiezenie na 0,3 s, tylko przy widocznej zakladce. Zostaje wolny zegar 15 s
-- (czas sesji, odpoczynek po walce, many przybywa bez zdarzen).
local function soon()
  if S.q or not (S.page and S.page:IsVisible()) then return end
  S.q = true
  C_Timer.After(0.3, function()
    S.q = nil
    if S.page and S.page:IsVisible() then pcall(refreshData) end
  end)
end
-- szyna Polestara laduje sie pozniej w TOC: zapis przy pierwszym otwarciu zakladki
local function hookPolestar()
  if S.psHooked or not U.onPolestar then return end
  S.psHooked = true
  U.onPolestar({ "STEP_CHANGED", "STEP_UPDATED", "WAYPOINT_CHANGED", "GUIDE_CHANGED", "TABS_CHANGED", "GUIDE_COMPLETED",
    "GEAR_UPDATED", "CLASS_QUEST_READY", "TRAIN_DUE", "CLASS_TRAINED", "ITEMDB_LOADED" }, soon)
end
local ev = CreateFrame("Frame")
for _, e in ipairs({ "PLAYER_LEVEL_UP", "PLAYER_XP_UPDATE", "PLAYER_MONEY", "PLAYER_REGEN_ENABLED", "PLAYER_REGEN_DISABLED",
  "BAG_UPDATE_DELAYED", "PLAYER_EQUIPMENT_CHANGED", "LEARNED_SPELL_IN_TAB", "QUEST_TURNED_IN", "QUEST_ACCEPTED", "QUEST_LOG_UPDATE",
  "ZONE_CHANGED_NEW_AREA", "PLAYER_DEAD", "PLAYER_ALIVE", "PLAYER_UNGHOST", "CHARACTER_POINTS_CHANGED", "SKILL_LINES_CHANGED" }) do
  pcall(ev.RegisterEvent, ev, e)
end
pcall(ev.RegisterUnitEvent, ev, "UNIT_AURA", "player")
ev:SetScript("OnEvent", soon)

local function refresh(page)
  S.page = page
  hookPolestar()
  refreshData()
  if S.ticker then S.ticker:Cancel() end
  S.ticker = C_Timer.NewTicker(15, function() if page:IsVisible() then pcall(refreshData) end end)
end
local function leave()
  if S.ticker then S.ticker:Cancel() S.ticker = nil end
end

U.RegisterTab({
  id = "grimuar", order = 8, title = "Grimuar", keys = "`",
  build = build, refresh = refresh, leave = leave,
  hints = { { { "LPM" }, "Wykonaj krok (zamyka hub)" }, { { "Shift", "J" }, "Okno Polestara" } },
  note = "Rozwój przypomina też na wstędze co 10 minut",
})
