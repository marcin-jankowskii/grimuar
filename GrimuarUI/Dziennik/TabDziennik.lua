-- Grimuar UI: zakladka Dziennik (makieta 14.11 „Hub · Dziennik”, krok B). Lista zadan wedlug stref z kolorem trudnosci
-- i postepem; szczegoly na pergaminie (kanon: pergamin tylko w dzienniku, ksiazkach i poczcie): cele, opis, nagroda;
-- nad nim pasek trasy Grimuara. Sledz / Pokaz na mapie (zakladka Mapa) / Udostepnij grupie / Porzuc (okno potwierdzenia gry).
-- Dane: C_QuestLog (tak jak Questie w Forever). Zadania pod zwinietym naglowkiem w dzienniku gry nie sa widoczne.
local ADDON, U = ...
local G, C = U.G, U.C

local D = {}
local P = { bg = { 0.902, 0.847, 0.722 }, title = { 0.29, 0.173, 0.055 }, lab = { 0.42, 0.29, 0.118 },
  text = { 0.169, 0.129, 0.09 }, muted = { 0.353, 0.29, 0.212 }, done = { 0.365, 0.42, 0.227 }, edge = { 0.541, 0.416, 0.227 } }

-- ---------- dane ----------
function U.questList()
  local list, header = {}, nil
  if not (C_QuestLog and C_QuestLog.GetNumQuestLogEntries and C_QuestLog.GetInfo) then return list end
  local n = U.call(C_QuestLog.GetNumQuestLogEntries) or 0
  for i = 1, n do
    local info = U.call(C_QuestLog.GetInfo, i)
    if info then
      if info.isHeader then
        header = info.title
        list[#list + 1] = { header = true, title = info.title }
      elseif not info.isHidden and info.questID then
        list[#list + 1] = { id = info.questID, index = i, title = info.title or "?", level = info.level, zone = header,
          group = info.suggestedGroup, complete = U.call(C_QuestLog.IsComplete, info.questID) and true or false }
      end
    end
  end
  return list
end
local function objectives(id)
  local objs = U.call(C_QuestLog.GetQuestObjectives, id)
  return type(objs) == "table" and objs or {}
end
local function progress(id)
  local a, b = 0, 0
  for _, o in ipairs(objectives(id)) do
    a = a + (U.num(o.numFulfilled) or 0)
    b = b + (U.num(o.numRequired) or 0)
  end
  return a, b
end
local function watched(q)
  if C_QuestLog.GetQuestWatchType then
    local ok, t = pcall(C_QuestLog.GetQuestWatchType, q.id)
    if ok then return t ~= nil end
  end
  if IsQuestWatched then return U.call(IsQuestWatched, q.index) and true or false end
  return false
end
local function setWatch(q, on)
  if on then
    if C_QuestLog.AddQuestWatch then pcall(C_QuestLog.AddQuestWatch, q.id) elseif AddQuestWatch then pcall(AddQuestWatch, q.index) end
  else
    if C_QuestLog.RemoveQuestWatch then pcall(C_QuestLog.RemoveQuestWatch, q.id) elseif RemoveQuestWatch then pcall(RemoveQuestWatch, q.index) end
  end
end
local function levelColor(level)
  local c = U.call(GetQuestDifficultyColor, level or 1)
  if type(c) == "table" and c.r then return { c.r, c.g, c.b } end
  return C.text
end

-- ---------- przyciski na pergaminie ----------
local function pButton(parent, text)
  local b = CreateFrame("Button", nil, parent)
  b:SetHeight(30)
  b.bg = b:CreateTexture(nil, "BACKGROUND")
  b.bg:SetAllPoints()
  U.Border(b, P.edge)
  b.label = U.Text(b, 13, "title", P.text)
  b.label:SetPoint("CENTER", 0, 0)
  b.label:SetJustifyH("CENTER")
  b.label:SetJustifyV("MIDDLE")
  function b:SetOn(on)
    if on then
      self.bg:SetColorTexture(P.title[1], P.title[2], P.title[3], 1)
      U.Color(self.label, { 0.953, 0.902, 0.776 })
    else
      self.bg:SetColorTexture(1, 0.973, 0.902, 0.35)
      U.Color(self.label, P.text)
    end
  end
  function b:SetLabel(t)
    self.label:SetText(t)
    self:SetWidth(math.floor(self.label:GetStringWidth() + 32))
  end
  b:SetOn(false)
  b:SetLabel(text)
  b:SetScript("OnEnter", function(self) U.BorderColor(self, P.title) end)
  b:SetScript("OnLeave", function(self) U.BorderColor(self, P.edge) end)
  return b
end

local function listRow(i)
  local r = D.rows[i]
  if r then return r end
  r = CreateFrame("Button", nil, D.list)
  r:SetSize(400, 28)
  r.sel = r:CreateTexture(nil, "BACKGROUND")
  r.sel:SetAllPoints()
  r.sel:SetColorTexture(C.gold[1], C.gold[2], C.gold[3], 0.1)
  local hl = r:CreateTexture(nil, "HIGHLIGHT")
  hl:SetAllPoints()
  hl:SetColorTexture(1, 1, 1, 0.04)
  r.lv = U.Text(r, 12, "body", C.text)
  r.lv:SetPoint("LEFT", 4, 0)
  r.lv:SetWidth(28)
  r.lv:SetJustifyH("CENTER")
  r.lv:SetJustifyV("MIDDLE")
  r.title = U.Text(r, 14, "body", C.text)
  r.title:SetPoint("LEFT", 38, 0)
  r.title:SetPoint("RIGHT", -84, 0)
  r.title:SetJustifyV("MIDDLE")
  r.tag = U.Tag(r, "")
  r.tag:SetPoint("RIGHT", -4, 0)
  r.head = U.Text(r, 11, "title", C.faint)
  r.head:SetPoint("BOTTOMLEFT", 4, 4)
  r:SetScript("OnClick", function(self) if self.q then D.sel = self.q.id D.refresh() end end)
  D.rows[i] = r
  return r
end

local function rewardSlot(i)
  local s = D.rew[i]
  if s then return s end
  s = U.Slot(D.pa, 40)
  s:SetScript("OnEnter", function(self)
    U.TT:SetOwner(self, "ANCHOR_RIGHT")
    if not pcall(U.TT.SetQuestLogItem, U.TT, self.kind, self.idx, D.sel) then U.TT:SetText(self.name or "") end
    U.TT:Show()
  end)
  s:SetScript("OnLeave", function() U.TT:Hide() end)
  D.rew[i] = s
  return s
end

local function objRow(i)
  local o = D.objs[i]
  if o then return o end
  o = { dot = U.Diamond(D.pa, 11, P.lab, false), text = U.Text(D.pa, 16, "body", P.text) }
  o.text:SetJustifyV("MIDDLE")
  D.objs[i] = o
  return o
end

local function build(page)
  -- lista zadan
  local L = U.Panel(page, 0.86, true)
  L:SetPoint("TOPLEFT") L:SetPoint("BOTTOMLEFT") L:SetWidth(440)
  local h = U.H2(L, "Zadania")
  h:SetPoint("TOPLEFT", 18, -16)
  D.count = U.Text(L, 13, "body", C.muted)
  D.count:SetPoint("TOPRIGHT", L, "TOPRIGHT", -18, -16)
  D.count:SetJustifyH("RIGHT")
  local view = CreateFrame("ScrollFrame", nil, L)
  view:SetPoint("TOPLEFT", h, "BOTTOMLEFT", -2, -12)
  view:SetPoint("BOTTOMRIGHT", L, "BOTTOMRIGHT", -16, 40)
  local list = CreateFrame("Frame", nil, view)
  list:SetSize(400, 10)
  view:SetScrollChild(list)
  view:EnableMouseWheel(true)
  view:SetScript("OnMouseWheel", function(self, d)
    local max = math.max(0, list:GetHeight() - self:GetHeight())
    self:SetVerticalScroll(math.max(0, math.min(max, self:GetVerticalScroll() - d * 56)))
  end)
  D.view, D.list, D.rows = view, list, {}
  local legend = U.Text(L, 11, "body", C.faint)
  legend:SetPoint("BOTTOMLEFT", L, "BOTTOMLEFT", 18, 14)
  legend:SetText("Kolor poziomu: |cffff8040trudne|r · |cffffd100na Twój poziom|r · |cff40c040łatwe|r · |cff9d9d9dbez doświadczenia|r")

  -- prawa strona: pasek trasy i pergamin
  local R = CreateFrame("Frame", nil, page)
  R:SetPoint("TOPLEFT", L, "TOPRIGHT", 22, 0)
  R:SetPoint("BOTTOMRIGHT")
  local strip = U.Panel(R, 0.86, false)
  strip:SetPoint("TOPLEFT") strip:SetPoint("TOPRIGHT") strip:SetHeight(46)
  local rune = U.Diamond(strip, 14, C.gold, true)
  rune:SetPoint("LEFT", 16, 0)
  local sl = U.Label(strip, "Trasa Grimuara")
  sl:SetPoint("LEFT", rune, "RIGHT", 10, 0)
  D.stripBtn = U.Button(strip, "Prowadź", nil, 30)
  D.stripBtn:SetPoint("RIGHT", -10, 0)
  D.stripText = U.Text(strip, 14, "body", C.text)
  D.stripText:SetPoint("LEFT", sl, "RIGHT", 14, 0)
  D.stripText:SetPoint("RIGHT", D.stripBtn, "LEFT", -14, 0)
  D.stripText:SetJustifyV("MIDDLE")

  local pa = CreateFrame("Frame", nil, R)
  pa:SetPoint("TOPLEFT", strip, "BOTTOMLEFT", 0, -14)
  pa:SetPoint("BOTTOMRIGHT")
  pa:SetClipsChildren(true)
  local bg = U.Rect(pa, P.bg, 1)
  bg:SetAllPoints()
  local glowTop = pa:CreateTexture(nil, "BACKGROUND", nil, 1)
  glowTop:SetPoint("TOPLEFT") glowTop:SetPoint("TOPRIGHT") glowTop:SetHeight(260)
  pcall(function()
    glowTop:SetColorTexture(1, 1, 1, 1)
    glowTop:SetGradient("VERTICAL", CreateColor(1, 0.98, 0.92, 0), CreateColor(1, 0.98, 0.92, 0.45))
  end)
  local shadeBot = pa:CreateTexture(nil, "BACKGROUND", nil, 1)
  shadeBot:SetPoint("BOTTOMLEFT") shadeBot:SetPoint("BOTTOMRIGHT") shadeBot:SetHeight(200)
  pcall(function()
    shadeBot:SetColorTexture(1, 1, 1, 1)
    shadeBot:SetGradient("VERTICAL", CreateColor(0.47, 0.35, 0.16, 0.3), CreateColor(0.47, 0.35, 0.16, 0))
  end)
  U.Border(pa, { 0, 0, 0 }, 1)
  D.pa = pa
  D.zone = U.Text(pa, 12, "title", P.lab)
  D.zone:SetPoint("TOPLEFT", 44, -32)
  D.title = U.Para(pa, 28, 600, P.title, "title")
  D.title:SetPoint("TOPLEFT", D.zone, "BOTTOMLEFT", 0, -8)
  D.objLab = U.Text(pa, 12, "title", P.lab)
  D.objLab:SetText("Cele")
  D.objs = {}
  D.descLab = U.Text(pa, 12, "title", P.lab)
  D.descLab:SetText("Opis")
  D.desc = U.Para(pa, 15, 600, P.muted)
  D.rewLab = U.Text(pa, 12, "title", P.lab)
  D.rewLab:SetText("Nagroda")
  D.rewText = U.Text(pa, 15, "body", P.text)
  D.rew = {}
  D.empty = U.Para(pa, 16, 600, P.muted)
  D.empty:SetPoint("TOPLEFT", 44, -40)
  D.empty:SetText("Dziennik jest pusty. Zadania dają postacie z „!” nad głową; Grimuar prowadzi do nich w zakładce Grimuar.")

  D.bGuide = pButton(pa, "Prowadź")
  D.bGuide:SetPoint("BOTTOMLEFT", pa, "BOTTOMLEFT", 44, 28)
  D.bGuide:SetOn(true)
  D.bWatch = pButton(pa, "Śledź")
  D.bWatch:SetPoint("LEFT", D.bGuide, "RIGHT", 10, 0)
  D.bMap = pButton(pa, "Pokaż na mapie")
  D.bMap:SetPoint("LEFT", D.bWatch, "RIGHT", 10, 0)
  D.bShare = pButton(pa, "Udostępnij grupie")
  D.bShare:SetPoint("LEFT", D.bMap, "RIGHT", 10, 0)
  D.bAbandon = pButton(pa, "Porzuć")
  D.bAbandon:SetPoint("BOTTOMRIGHT", pa, "BOTTOMRIGHT", -44, 28)
  U.Color(D.bAbandon.label, { 0.54, 0.16, 0.07 })
  -- 14.11: ocena Grimuara (Questy.lua G.questAdvice): porzucic, zostawic na grupe, za trudne
  D.verdict = U.Para(pa, 14, 560, { 0.54, 0.16, 0.07 })
  D.verdict:SetPoint("BOTTOMLEFT", D.bGuide, "TOPLEFT", 0, 14)

  local ev = CreateFrame("Frame", nil, page)
  D.ev = ev
  local queued = false
  ev:SetScript("OnEvent", function()
    if queued then return end
    queued = true
    C_Timer.After(0.2, function()
      queued = false
      if page:IsVisible() then pcall(D.refresh) end
    end)
  end)
end

-- 14.11: zadanie do wziecia z przewodnika Polestara (nie ma go jeszcze w dzienniku)
local function questieText(qid)
  local L = QuestieLoader
  local ok, DB = pcall(function() return L and L:ImportModule("QuestieDB") end)
  local txt = ok and DB and DB.QueryQuestSingle and U.call(DB.QueryQuestSingle, qid, "objectivesText")
  if type(txt) == "table" then return table.concat(txt, " ") end
  return type(txt) == "string" and txt or nil
end
local function detailsTake(e)
  for _, w in ipairs({ D.objLab, D.rewLab, D.rewText, D.bWatch, D.bAbandon, D.bShare, D.empty }) do w:Hide() end
  for _, o in ipairs(D.objs) do o.dot:Hide() o.text:Hide() end
  for _, s in ipairs(D.rew) do s:Hide() end
  for _, w in ipairs({ D.zone, D.title, D.descLab, D.desc, D.bGuide, D.bMap }) do w:Show() end
  local W = math.max(300, math.floor((D.pa:GetWidth() or 700) - 88))
  D.zone:SetText("Do wzięcia · " .. (e.guide or "Polestar") .. " · krok " .. tostring(e.step or "?") .. (e.minLevel and (" · od poziomu " .. e.minLevel) or ""))
  D.title:SetWidth(W)
  D.title:SetText(e.title)
  D.descLab:ClearAllPoints()
  D.descLab:SetPoint("TOPLEFT", D.title, "BOTTOMLEFT", 0, -18)
  D.descLab:SetText("Gdzie i po co")
  D.desc:SetWidth(math.min(W, 820))
  D.desc:ClearAllPoints()
  D.desc:SetPoint("TOPLEFT", D.descLab, "BOTTOMLEFT", 0, -8)
  local info = e.map and U.call(C_Map.GetMapInfo, e.map)
  local parts = {}
  parts[#parts + 1] = "Weź u: " .. (e.npc or "?") .. (info and (" — " .. info.name) or "") ..
    (e.x and (" " .. string.format("%.1f", e.x * 100):gsub("%.", ",") .. " · " .. string.format("%.1f", e.y * 100):gsub("%.", ",")) or "")
  local qt = questieText(e.qid)
  if qt and qt ~= "" then parts[#parts + 1] = qt end
  if e.note and e.note ~= "" then parts[#parts + 1] = "Polestar: " .. e.note end
  if e.reward and e.reward ~= "" then parts[#parts + 1] = "Nagroda: " .. e.reward end
  D.desc:SetText(table.concat(parts, "\n\n"))
  D.verdict:SetText(e.now and "Polestar: weź je w tym kroku." or "Polestar: weźmiesz je dalej na trasie, możesz już teraz.")
  U.Color(D.verdict, P.muted)
  D.bGuide:SetLabel("Prowadź do zleceniodawcy")
  D.bGuide:SetScript("OnClick", function()
    if not (e.map and e.x) then U.say("Polestar nie podał miejsca tego zadania.") return end
    if G.wayTo then pcall(G.wayTo, e.map, tonumber(string.format("%.2f", e.x * 100)), tonumber(string.format("%.2f", e.y * 100)), "Weź: " .. e.title) end
    U.say("prowadzę do " .. (e.npc or "zleceniodawcy") .. ": " .. e.title .. ".")
    U.Close()
  end)
  D.bMap:SetScript("OnClick", function()
    if e.map and e.x and U.mapGuide then U.mapGuide(e.map, e.x, e.y, "Weź: " .. e.title) end
  end)
end

-- 14.11: zadanie profesji Grimuara (RzemiosloZadania.lua)
local function detailsProf(t)
  for _, w in ipairs({ D.rewLab, D.rewText, D.bAbandon, D.bShare, D.empty, D.bMap }) do w:Hide() end
  for _, o in ipairs(D.objs) do o.dot:Hide() o.text:Hide() end
  for _, s in ipairs(D.rew) do s:Hide() end
  for _, w in ipairs({ D.zone, D.title, D.objLab, D.descLab, D.desc, D.bWatch }) do w:Show() end
  local W = math.max(300, math.floor((D.pa:GetWidth() or 700) - 88))
  D.zone:SetText(t.zoneLine or ("Profesje · " .. (t.profPl or "") .. " · zadanie Grimuara"))
  D.title:SetWidth(W)
  D.title:SetText(t.title)
  D.objLab:ClearAllPoints()
  D.objLab:SetPoint("TOPLEFT", D.title, "BOTTOMLEFT", 0, -18)
  local prev = D.objLab
  for i, ob in ipairs(t.objs or {}) do
    local o = objRow(i)
    o.text:SetText(ob.text)
    o.dot:Set(ob.done and P.done or P.lab, ob.done)
    U.Color(o.text, ob.done and P.done or P.text)
    o.dot:ClearAllPoints()
    o.dot:SetPoint("TOPLEFT", prev, "BOTTOMLEFT", 0, i == 1 and -10 or -6)
    o.text:ClearAllPoints()
    o.text:SetPoint("LEFT", o.dot, "RIGHT", 10, 0)
    o.dot:Show() o.text:Show()
    prev = o.dot
  end
  D.descLab:ClearAllPoints()
  D.descLab:SetPoint("TOPLEFT", prev, "BOTTOMLEFT", 0, -20)
  D.descLab:SetText("Gdzie i po co")
  D.desc:SetWidth(math.min(W, 820))
  D.desc:ClearAllPoints()
  D.desc:SetPoint("TOPLEFT", D.descLab, "BOTTOMLEFT", 0, -8)
  D.desc:SetText((t.where or "") .. ((t.why and t.why ~= "") and ("\n\n" .. t.why) or ""))
  D.verdict:SetText("Grimuar: postęp liczy się sam z umiejętności i toreb; po ukończeniu dostaniesz komunikat.")
  U.Color(D.verdict, P.muted)
  D.bGuide:SetShown(t.nav ~= nil)
  D.bGuide:SetLabel("Prowadź" .. (t.navLabel and (": " .. t.navLabel) or ""))
  D.bGuide:SetScript("OnClick", function() if U.profTaskGuide and U.profTaskGuide(t) then U.Close() end end)
  D.bWatch:SetLabel(t.group == "Kontrakt" and "Otwórz w Kronice" or "Otwórz w Rzemiośle")
  D.bWatch:SetOn(false)
  D.bWatch:SetScript("OnClick", function()
    if t.group == "Kontrakt" then if GrimuarHubOpen then GrimuarHubOpen("kronika") end return end
    if U.profTasksShow then U.profTasksShow(t.title) end
  end)
end

local function details(q)
  -- 15.11 (R30 P04): „Przy okazji i za Toba” jako karty zamiast pergaminu (DziennikPrzyOkazji.lua)
  if U.psNearShow then U.psNearShow(D, q ~= nil and q.near ~= nil) end
  if q and q.near then return end
  if q and q.take then return detailsTake(q.take) end
  if q and q.prof then return detailsProf(q.prof) end
  D.descLab:SetText("Opis")
  local has = q ~= nil
  for _, w in ipairs({ D.zone, D.title, D.objLab, D.descLab, D.desc, D.rewLab, D.rewText, D.bGuide, D.bWatch, D.bMap, D.bAbandon }) do w:SetShown(has) end
  D.empty:SetShown(not has)
  for _, o in ipairs(D.objs) do o.dot:Hide() o.text:Hide() end
  for _, s in ipairs(D.rew) do s:Hide() end
  D.verdict:SetText("")
  if not has then D.bShare:Hide() return end
  local adv = D.adv and D.adv[q.id]
  if adv and adv.why then
    local lead = ({ porzuc = "Grimuar: porzuć — ", grupa = "Grimuar: zostaw — ", pozniej = "Grimuar: na później — " })[adv.verdict] or "Grimuar: "
    D.verdict:SetText(lead .. adv.why .. ".")
    U.Color(D.verdict, adv.verdict == "porzuc" and { 0.54, 0.16, 0.07 } or P.muted)
  end
  -- 14.11: kto z grupy ma to zadanie (Questie, GrupaLatwo.lua)
  local gl = U.groupQuestLine and U.call(U.groupQuestLine, q.id)
  if gl then
    local cur = D.verdict:GetText() or ""
    D.verdict:SetText(cur ~= "" and (cur .. "\n" .. gl) or gl)
    if cur == "" then U.Color(D.verdict, P.muted) end
  end
  D.bAbandon:SetOn(adv ~= nil and adv.verdict == "porzuc")
  U.Color(D.bAbandon.label, (adv and adv.verdict == "porzuc") and { 0.953, 0.902, 0.776 } or { 0.54, 0.16, 0.07 })
  if D.applied ~= q.id and not U.testing then
    pcall(C_QuestLog.SetSelectedQuest, q.id)
    D.applied = q.id
  end
  local W = math.max(300, math.floor((D.pa:GetWidth() or 700) - 88))
  D.zone:SetText((q.zone or "") .. " · poziom " .. tostring(q.level or "?") .. ((U.num(q.group) or 0) > 1 and (" · grupa " .. q.group) or ""))
  D.title:SetWidth(W)
  D.title:SetText(q.title)

  -- cele
  D.objLab:ClearAllPoints()
  D.objLab:SetPoint("TOPLEFT", D.title, "BOTTOMLEFT", 0, -18)
  local prev = D.objLab
  local objs = objectives(q.id)
  if #objs == 0 then
    local o = objRow(1)
    o.text:SetText(q.complete and "Gotowe: wróć do zleceniodawcy." or "Zobacz opis.")
    objs = { { finished = q.complete } }
  end
  for i, ob in ipairs(objs) do
    local o = objRow(i)
    if ob.text then o.text:SetText(ob.text) end
    o.dot:Set(ob.finished and P.done or P.lab, ob.finished)
    U.Color(o.text, ob.finished and P.done or P.text)
    o.dot:ClearAllPoints()
    o.dot:SetPoint("TOPLEFT", prev, "BOTTOMLEFT", 0, i == 1 and -10 or -6)
    o.text:ClearAllPoints()
    o.text:SetPoint("LEFT", o.dot, "RIGHT", 10, 0)
    o.dot:Show() o.text:Show()
    prev = o.dot
  end

  -- opis
  local ok, desc = pcall(GetQuestLogQuestText, q.index)
  if not ok or not desc or desc == "" then ok, desc = pcall(GetQuestLogQuestText) end
  D.descLab:ClearAllPoints()
  D.descLab:SetPoint("TOPLEFT", prev, "BOTTOMLEFT", 0, -20)
  D.desc:SetWidth(math.min(W, 820))
  D.desc:ClearAllPoints()
  D.desc:SetPoint("TOPLEFT", D.descLab, "BOTTOMLEFT", 0, -8)
  D.desc:SetText(ok and desc or "")

  -- nagroda
  local parts = {}
  local xp = U.num(U.call(GetQuestLogRewardXP, q.id))
  local money = U.num(U.call(GetQuestLogRewardMoney, q.id))
  if xp and xp > 0 then parts[#parts + 1] = U.thousands(xp) .. " doświadczenia" end
  if money and money > 0 then parts[#parts + 1] = U.call(GetCoinTextureString or (C_CurrencyInfo and C_CurrencyInfo.GetCoinTextureString), money) or "" end
  D.rewLab:ClearAllPoints()
  D.rewLab:SetPoint("TOPLEFT", D.desc, "BOTTOMLEFT", 0, -20)
  D.rewText:ClearAllPoints()
  D.rewText:SetPoint("TOPLEFT", D.rewLab, "BOTTOMLEFT", 0, -8)
  local n = 0
  local function addItem(kind, idx, name, tex, count, quality)
    n = n + 1
    local s = rewardSlot(n)
    s.kind, s.idx, s.name = kind, idx, name
    s.icon:SetTexture(tex)
    s.icon:SetAlpha(1)
    s.count:SetText((U.num(count) or 0) > 1 and count or "")
    s:SetQuality(U.num(quality))
    s:ClearAllPoints()
    s:SetPoint("TOPLEFT", D.rewText, "BOTTOMLEFT", (n - 1) * 48, -8)
    s:Show()
  end
  for i = 1, (U.num(U.call(GetNumQuestLogRewards, q.id)) or 0) do
    local name, tex, count, quality = U.call(GetQuestLogRewardInfo, i, q.id)
    if tex then addItem("reward", i, name, tex, count, quality) end
  end
  local nc = U.num(U.call(GetNumQuestLogChoices, q.id, true)) or U.num(U.call(GetNumQuestLogChoices)) or 0
  for i = 1, nc do
    local name, tex, count, quality = U.call(GetQuestLogChoiceInfo, i)
    if tex then addItem("choice", i, name, tex, count, quality) end
  end
  if nc > 1 then parts[#parts + 1] = "do wyboru jeden z " .. nc end
  D.rewText:SetText(#parts > 0 and table.concat(parts, "   ·   ") or (n > 0 and "" or "—"))

  -- przyciski
  local w = watched(q)
  D.bWatch:SetLabel(w and "Śledzone" or "Śledź")
  D.bWatch:SetOn(w)
  D.bWatch:SetScript("OnClick", function() setWatch(q, not w) C_Timer.After(0.1, function() pcall(D.refresh) end) end)
  -- Prowadz: strzalka Polestara do najblizszego celu (gotowe: do oddajacego) i hub sie zamyka, zebys biegl
  -- 15.11 (R30 P18): czas dojscia z planera Polestara na przycisku
  local spot = (U.polestarSpot and U.polestarSpot(q.id, q.complete)) or (U.questBest and U.questBest(q.id))
  local etaS = spot and spot.map and spot.x and G.etaText and G.etaText(spot.map, spot.x * 100, spot.y * 100) or ""
  D.bGuide:SetLabel((q.complete and "Prowadź do oddania" or "Prowadź") .. etaS)
  D.bGuide:SetScript("OnClick", function()
    local t = (U.polestarSpot and U.polestarSpot(q.id, q.complete)) or (U.questBest and U.questBest(q.id))
    if not t then U.say("Ani Polestar, ani Questie nie znają miejsca tego zadania. Zobacz opis.") return end
    local label = q.title .. (t.name and (": " .. t.name) or "")
    if G.wayTo then pcall(G.wayTo, t.map, tonumber(string.format("%.2f", t.x * 100)), tonumber(string.format("%.2f", t.y * 100)), label) end
    local info = U.call(C_Map.GetMapInfo, t.map)
    U.say("prowadzę: " .. label .. " (" .. (info and info.name or "?") .. ").")
    U.Close()
  end)
  D.bMap:SetScript("OnClick", function()
    local t = (U.polestarSpot and U.polestarSpot(q.id, q.complete)) or (U.questBest and U.questBest(q.id))
    if t and U.mapGuide then U.mapGuide(t.map, t.x, t.y, q.title) return end
    local id = q.zone and G.findMapId and U.call(G.findMapId, q.zone)
    if U.mapShow then U.mapShow(id) end
  end)
  local push = U.call(C_QuestLog.IsPushableQuest, q.id) and IsInGroup and IsInGroup()
  D.bShare:SetShown(push and true or false)
  D.bShare:SetScript("OnClick", function() pcall(C_QuestLog.SetSelectedQuest, q.id) pcall(QuestLogPushQuest) end)
  D.bAbandon:SetScript("OnClick", function()
    pcall(C_QuestLog.SetSelectedQuest, q.id)
    pcall(C_QuestLog.SetAbandonQuest)
    pcall(StaticPopup_Show, "ABANDON_QUEST", q.title)
  end)
end

-- kolejnosc listy: Teraz wg Polestara, strefy z dziennika, Niepotrzebne (Grimuar), Do wziecia (Polestar)
local function arrange(log)
  local ps = U.polestarQuests and U.polestarQuests() or { now = {}, take = {} }
  local now, bad, out = {}, {}, {}
  local rest, header, pending = {}, nil, nil
  for _, q in ipairs(log) do
    if q.header then
      header = q
    else
      local adv = D.adv[q.id]
      if adv and adv.verdict == "porzuc" then bad[#bad + 1] = q
      elseif ps.now and ps.now[q.id] then now[#now + 1] = q
      else
        if header ~= pending then rest[#rest + 1] = header pending = header end
        rest[#rest + 1] = q
      end
    end
  end
  if #now > 0 then
    out[#out + 1] = { header = true, title = "Teraz wg Polestara", special = true }
    for _, q in ipairs(now) do out[#out + 1] = q end
  end
  -- 15.11 (R30 P04): cele z dalszych krokow w poblizu i questy, ktore trasa minela (karty po kliknieciu)
  local near = U.psNearRow and U.call(U.psNearRow)
  if near then
    out[#out + 1] = { header = true, title = "Przy okazji i za Tobą", special = true }
    out[#out + 1] = { id = "psnear", near = near, title = near.title }
  end
  for _, q in ipairs(rest) do if q then out[#out + 1] = q end end
  -- 14.11: zadania profesji Grimuara (zbierz / zrob / do trenera / sprzedaj)
  local pt = U.profTasks and U.profTasks() or {}
  if #pt > 0 then
    out[#out + 1] = { header = true, title = "Profesje — zadania Grimuara", special = true }
    for _, t in ipairs(pt) do out[#out + 1] = { id = "p" .. t.key, prof = t, title = t.title } end
  end
  -- 14.11: kontrakty dnia i tygodnia (KronikaKontrakty.lua), ten sam widok szczegolow co zadania profesji
  local kt = U.contractTasks and U.call(U.contractTasks) or {}
  if #kt > 0 then
    out[#out + 1] = { header = true, title = "Kontrakty Grimuara — dzień i tydzień", special = true }
    for _, t in ipairs(kt) do out[#out + 1] = { id = "k" .. t.key, prof = t, title = t.title } end
  end
  if #bad > 0 then
    out[#out + 1] = { header = true, title = "Niepotrzebne — Grimuar: porzuć", special = true }
    for _, q in ipairs(bad) do out[#out + 1] = q end
  end
  if ps.take and #ps.take > 0 then
    out[#out + 1] = { header = true, title = "Do wzięcia wg Polestara", special = true }
    for _, e in ipairs(ps.take) do
      out[#out + 1] = { id = "t" .. e.qid, take = e, title = e.title, level = e.minLevel }
    end
  end
  return out
end

function D.refresh()
  local log = U.questList()
  local nq = 0
  for _, q in ipairs(log) do if not q.header then nq = nq + 1 end end
  local maxQ = U.num(U.call(C_QuestLog.GetMaxNumQuestsCanAccept)) or 25
  D.adv = {}
  local nBad = 0
  for _, a in ipairs(U.call(G.questAdvice) or {}) do
    D.adv[a.id] = a
    if a.verdict == "porzuc" then nBad = nBad + 1 end
  end
  local all = arrange(log)
  local first, found, nTake = nil, false, 0
  for _, q in ipairs(all) do
    if not q.header then
      if not q.near then first = first or q end -- karty „Przy okazji” tylko na klik
      if q.id == D.sel then found = true end
      if q.take then nTake = nTake + 1 end
    end
  end
  if not found then D.sel = first and first.id end
  D.count:SetText(nq .. " / " .. maxQ .. (nBad > 0 and (" · " .. U.hex(C.danger) .. nBad .. " do porzucenia|r") or "") ..
    (nTake > 0 and (" · " .. U.hex(C.gold) .. nTake .. " do wzięcia|r") or ""))

  local y, selQ = 0, nil
  for i, q in ipairs(all) do
    local r = listRow(i)
    r:ClearAllPoints()
    r:SetPoint("TOPLEFT", D.list, "TOPLEFT", 0, -y)
    if q.header then
      r.q = nil
      r:SetHeight(i == 1 and 22 or 32)
      r.head:SetText(q.title or "")
      U.Color(r.head, q.special and C.gold or C.faint)
      r.head:Show() r.lv:Hide() r.title:Hide() r.tag:Hide() r.sel:Hide()
      r:EnableMouse(false)
    else
      r.q = q
      r:SetHeight(28)
      r:EnableMouse(true)
      r.head:Hide()
      r.lv:SetText(q.level or "")
      U.Color(r.lv, levelColor(q.level))
      r.title:SetText(q.title)
      U.Color(r.title, q.id == D.sel and C.gold or C.text)
      local a, b = 0, 0
      if not q.take and not q.prof and not q.near then a, b = progress(q.id) end
      local adv = not q.take and D.adv[q.id]
      if q.near then
        U.Color(r.title, q.id == D.sel and C.gold or C.frost)
        r.tag:SetTag(q.near.tag or "", C.frost)
      elseif q.prof then
        U.Color(r.title, q.id == D.sel and C.gold or C.text)
        r.tag:SetTag(q.prof.tag or q.prof.group or "", q.prof.group == "Sprzedaj" and C.muted or C.gold)
      elseif q.take then
        U.Color(r.title, q.id == D.sel and C.gold or C.muted)
        r.tag:SetTag(q.take.now and "weź teraz" or ("krok " .. tostring(q.take.step or "?")), q.take.now and C.gold or C.muted)
      elseif q.complete then r.tag:SetTag("gotowe", C.ok)
      elseif adv and adv.verdict == "porzuc" then r.tag:SetTag("porzuć?", C.danger)
      elseif adv and adv.verdict == "grupa" then r.tag:SetTag("grupa", C.muted)
      elseif watched(q) then r.tag:SetTag("śledzone", C.frost)
      elseif b > 0 then r.tag:SetTag(a .. " / " .. b, C.muted)
      else r.tag:SetTag("", C.muted) end
      r.tag:SetShown(r.tag.label:GetText() ~= "")
      r.lv:Show() r.title:Show()
      r.sel:SetShown(q.id == D.sel)
      if q.id == D.sel then selQ = q end
    end
    r:Show()
    y = y + r:GetHeight() + 2
  end
  for i = #all + 1, #D.rows do D.rows[i]:Hide() end
  D.list:SetHeight(math.max(10, y))
  details(selQ)

  -- pasek trasy: pierwszy krok planu albo biezacy odcinek
  local st = (U.call(G.buildSteps) or {})[1]
  local leg = U.call(G.trasaLeg, UnitLevel("player") or 1)
  local txt = st and st.text or (leg and ("teraz " .. tostring(leg[3]) .. " (" .. tostring(leg[1]) .. "–" .. tostring(leg[2]) .. ")")) or "graj według Polestara"
  D.stripText:SetText(txt)
  local b = st and st.btns and st.btns[1]
  if b and type(b[2]) == "function" then
    D.stripBtn:SetLabel(b[1] or "Prowadź")
    D.stripBtn:SetScript("OnClick", function() U.OpenGame(b[2]) end)
    D.stripBtn:Show()
  else
    D.stripBtn:Hide()
  end
end

local EVENTS = { "QUEST_LOG_UPDATE", "QUEST_WATCH_LIST_CHANGED", "QUEST_ACCEPTED", "QUEST_REMOVED", "UNIT_QUEST_LOG_CHANGED", "QUEST_TURNED_IN",
  "SKILL_LINES_CHANGED" }

-- z innych zakladek: otworz Dziennik na zadaniu
function U.questShow(id)
  D.sel = id
  U.Select("dziennik")
end

-- 15.11 (R30 P01): odswiezenie bez przewijania na zdarzenie Polestara (Hub\PolestarSzyna.lua)
function U.dziennikSoft() if D.refresh then D.refresh() end end

U.RegisterTab({
  id = "dziennik", order = 3, title = "Dziennik", keys = "J · L",
  build = build,
  refresh = function()
    for _, e in ipairs(EVENTS) do pcall(D.ev.RegisterEvent, D.ev, e) end
    D.applied = nil
    if U.polestarReset then U.polestarReset() end
    D.refresh()
    D.view:SetVerticalScroll(0)
  end,
  leave = function() D.ev:UnregisterAllEvents() end,
  hints = { { { "LPM" }, "Wybierz zadanie" }, { { "Kółko" }, "Przewiń listę" } },
  note = "Pergamin tylko w dzienniku, książkach i poczcie",
})
