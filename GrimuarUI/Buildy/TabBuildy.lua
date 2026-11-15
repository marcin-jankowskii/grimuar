-- Grimuar UI: zakladka Buildy (R27 E3/E4, 14.11; gracz: „zrob wszystkie kroki, ma byc tez mozliwosc edycji buildow
-- Polestara”). Lewo: buildy dla Twojej klasy (Grimuar, Moje, Importowane, szkice Polestara; „Wszystkie klasy”).
-- Srodek: podglad w sekcjach (talenty wg poziomow, trener, paski, combo, PvP, stwory, kolo, grupa, statystyki).
-- Prawo: Ustaw jako aktywny, Duplikuj do edycji (takze szkic Polestara), Edytuj i Usun (wlasne), Eksport (kod do
-- skopiowania), Import (wklej, podglad, zapis). Dane i zasady: GrimuarSetup Build\Api.lua, Walidacja.lua, Kod.lua.
-- 15.11: srodek to karty (BuildyPodglad.lua) z „Edytuj” przy kazdej sekcji; „Edytuj” dziala dla kazdego buildu:
-- wbudowany i szkic Polestara najpierw kopiuje do „Moje” (jedno klikniecie zamiast „Duplikuj”, potem „Edytuj”).
local ADDON, U = ...
local C = U.C
local G = U.G or {}

local S = { rows = {}, sel = nil, allClasses = false }
local L_W, R_W = 360, 420
local GOLD, MUTED, OK, TEXT = U.hex(C.gold), U.hex(C.muted), U.hex(C.ok), U.hex(C.text)
local SRC = { grimuar = "Grimuar", moje = "Moje", import = "Importowane", polestar = "Polestar (szkice)" }
local SRC_ORDER = { "grimuar", "moje", "import", "polestar" }
local CLASS_PL = { WARRIOR = "Wojownik", PALADIN = "Paladyn", HUNTER = "Łowca", ROGUE = "Łotrzyk", PRIEST = "Kapłan",
  SHAMAN = "Szaman", MAGE = "Mag", WARLOCK = "Czarnoksiężnik", DRUID = "Druid" }
local ALL = { "WARRIOR", "PALADIN", "HUNTER", "ROGUE", "PRIEST", "SHAMAN", "MAGE", "WARLOCK", "DRUID" }

local function bt(v) return G.BT and G.BT(v) or (type(v) == "table" and (v.pl or v.en) or v) end
local function myClass() return G.playerClassToken and G.playerClassToken() end

-- ---------- lista ----------
local function entries()
  local out = {}
  local classes = S.allClasses and ALL or { myClass() }
  for _, cls in ipairs(classes) do
    for _, b in ipairs(G.BuildList and G.BuildList(cls) or {}) do out[#out + 1] = b end
  end
  table.sort(out, function(a, b)
    local ia, ib = 9, 9
    for i, s in ipairs(SRC_ORDER) do if a.src == s then ia = i end if b.src == s then ib = i end end
    if ia ~= ib then return ia < ib end
    if a.class ~= b.class then return (a.class or "") < (b.class or "") end
    return (a.name or "") < (b.name or "")
  end)
  return out
end

local function row(i)
  local r = S.rows[i]
  if r then return r end
  r = CreateFrame("Button", nil, S.list)
  r:SetHeight(40)
  local hl = r:CreateTexture(nil, "HIGHLIGHT") hl:SetAllPoints() hl:SetColorTexture(1, 1, 1, 0.05)
  r.selT = r:CreateTexture(nil, "BACKGROUND") r.selT:SetAllPoints() r.selT:SetColorTexture(C.gold[1], C.gold[2], C.gold[3], 0.10)
  r.t = U.Text(r, 13, "body", C.text) r.t:SetPoint("TOPLEFT", 10, -4)
  r.s = U.Text(r, 11, "body", C.muted) r.s:SetPoint("TOPLEFT", r.t, "BOTTOMLEFT", 0, -3)
  r.tag = U.Tag(r, "") r.tag:SetPoint("RIGHT", -6, 0)
  r.head = U.Text(r, 12, "title", C.goldDim) r.head:SetPoint("LEFT", 4, -6)
  r:SetScript("OnClick", function(self) if self.id then S.sel = self.id U.buildyRefresh() end end)
  S.rows[i] = r
  return r
end

local function drawList()
  local list = entries()
  local act = G.ActiveBuildId and G.ActiveBuildId()
  if not S.sel or not G.GetBuild(S.sel) then S.sel = act or (list[1] and list[1].id) end
  local w, y, n, lastSrc = L_W - 28, 0, 0, nil
  for _, b in ipairs(list) do
    if b.src ~= lastSrc then
      lastSrc = b.src
      n = n + 1
      local h = row(n)
      h.id = nil
      h:SetWidth(w) h:ClearAllPoints() h:SetPoint("TOPLEFT", S.list, "TOPLEFT", 0, -y)
      h.head:SetText((SRC[b.src] or b.src):upper()) h.head:Show()
      h.t:SetText("") h.s:SetText("") h.tag:Hide() h.selT:Hide()
      h:SetHeight(28) h:Show()
      y = y + 30
    end
    n = n + 1
    local r = row(n)
    r.id = b.id
    r:SetHeight(40) r:SetWidth(w)
    r:ClearAllPoints() r:SetPoint("TOPLEFT", S.list, "TOPLEFT", 0, -y)
    r.head:Hide()
    r.t:SetText(b.name or b.id) r.t:SetWidth(w - 80)
    U.Color(r.t, b.id == act and C.gold or C.text)
    r.s:SetText((CLASS_PL[b.class or ""] or b.class or "?") .. (b.version and (" · wersja " .. b.version) or ""))
    r.tag:SetShown(b.id == act)
    if b.id == act then r.tag:SetTag("aktywny", C.gold) end
    r.selT:SetShown(b.id == S.sel)
    r:Show()
    y = y + 42
  end
  for i = n + 1, #S.rows do S.rows[i]:Hide() end
  S.list:SetHeight(math.max(10, y))
end

-- ---------- podglad ----------
function U.buildPreview(b)
  if not b then return MUTED .. "Wybierz build z listy.|r" end
  local L = { GOLD .. (bt(b.name) or b.id) .. "|r" }
  L[#L + 1] = (CLASS_PL[b.class or ""] or b.class or "?") .. (b.role and (" · " .. ({ DAMAGER = "obrażenia", TANK = "tank", HEALER = "leczenie" })[b.role] or b.role) or "") ..
    " · autor: " .. (bt(b.author) or "anonim") .. " · wersja " .. tostring(b.version or 1) .. (b.license and (" · " .. b.license) or "")
  if b.desc then L[#L + 1] = MUTED .. bt(b.desc) .. "|r" end
  if b.sources then L[#L + 1] = MUTED .. "Źródła: " .. table.concat(b.sources, ", ") .. "|r" end
  local function sec(title, has) L[#L + 1] = "\n" .. (has and GOLD or MUTED) .. title:upper() .. (has and "" or " — brak w tym buildzie") .. "|r" return has end
  -- talenty
  local plan = (b.talents and b.talents.plan and #b.talents.plan > 0) and b.talents.plan or (G.picksToPlan and b.talents and b.talents.picks and G.picksToPlan(b.class, b.talents.picks)) or {}
  if sec("Talenty", #plan > 0) then
    local t = {}
    for _, p in ipairs(plan) do t[#t + 1] = (p[2] == p[3] and p[2] or (p[2] .. "–" .. p[3])) .. " " .. p[1] end
    L[#L + 1] = table.concat(t, " · ")
  end
  -- trener
  local tr = b.trainer or {}
  if sec("Trener", tr.all or tr.keep or tr.list) then
    if tr.all then L[#L + 1] = "Kupuje wszystko (jak „Train All” w Polestarze)." end
    local keep = {}
    for k, v in pairs(tr.keep or {}) do keep[#keep + 1] = type(k) == "number" and tostring(v) or k end
    table.sort(keep)
    if #keep > 0 then L[#L + 1] = "Kupuje: " .. table.concat(keep, ", ") end
    local skip = {}
    for k in pairs(tr.skip or {}) do skip[#skip + 1] = k end
    table.sort(skip)
    if #skip > 0 then L[#L + 1] = MUTED .. "Pomija: " .. table.concat(skip, ", ") .. "|r" end
  end
  -- paski
  local bars = b.bars or {}
  if sec("Paski akcji", bars.main or bars.bar2) then
    local t = {}
    for s = 1, 12 do local c = bars.main and bars.main[s] if c then t[#t + 1] = s .. ": " .. tostring(c[1]) end end
    if #t > 0 then L[#L + 1] = "Pasek 1 — " .. table.concat(t, " · ") end
    t = {}
    for s = 61, 72 do local c = bars.bar2 and bars.bar2[s] if c then t[#t + 1] = tostring(c[1]) end end
    if #t > 0 then L[#L + 1] = "Pasek 2 — " .. table.concat(t, " · ") end
  end
  -- combo
  local co = b.combo or {}
  if sec("Combo", co.steps and #co.steps > 0) then
    for i, s in ipairs(co.steps) do L[#L + 1] = i .. ". " .. (s.spell or bt(s.text) or "?") .. (s.hint and (MUTED .. " — " .. bt(s.hint) .. "|r") or "") end
  end
  -- pvp, stwory, kolo, grupa, statystyki
  local pv = 0
  for _, band in pairs(b.pvp or {}) do for _ in pairs(band) do pv = pv + 1 end end
  if sec("PvP", pv > 0) then L[#L + 1] = pv .. " porad na klasy wroga" end
  local cr = 0
  for _ in pairs(b.creatures or {}) do cr = cr + 1 end
  if sec("Stwory", cr > 0) then L[#L + 1] = cr .. " porad na typy stworów" end
  if sec("Koło", b.wheel and #b.wheel > 0) then
    local t = {}
    for _, w in ipairs(b.wheel) do t[#t + 1] = w[2] or (type(w[1]) == "table" and w[1][1]) or tostring(w[1]) end
    L[#L + 1] = table.concat(t, " · ")
  end
  if sec("Statystyki", b.stats ~= nil) then L[#L + 1] = "Pawn: " .. tostring(b.stats.pawn or b.stats.from or "?") end
  return table.concat(L, "\n")
end

-- ---------- akcje ----------
local function act(fn) return function() local ok, e = pcall(fn) if not ok and U.logError then U.logError("buildy", e) end U.buildyRefresh() end end

local function showCode(text, title)
  S.codeL:SetText(title)
  S.code:SetText(text or "")
  S.code:Show() S.codeL:Show()
  S.code:SetFocus()
  S.code:HighlightText()
end

-- roznice importu wzgledem posiadanej wersji (albo „nowy build”)
function U.buildDiff(old, new, problems)
  local L = { GOLD .. "IMPORT: " .. (bt(new.name) or new.id) .. "|r" }
  local function cnt(t) local n = 0 for _ in pairs(t or {}) do n = n + 1 end return n end
  if not old then L[#L + 1] = "Nowy build (" .. (new.class or "?") .. ", wersja " .. tostring(new.version or 1) .. ")."
  else
    L[#L + 1] = "Masz już ten build: wersja " .. tostring(old.version or 1) .. " → " .. tostring(new.version or 1) .. "."
    if bt(old.author) ~= bt(new.author) then L[#L + 1] = U.hex(C.danger) .. "Inny autor: " .. tostring(bt(old.author)) .. " → " .. tostring(bt(new.author)) .. "|r" end
    if old.license ~= new.license then L[#L + 1] = U.hex(C.danger) .. "Inna licencja: " .. tostring(old.license) .. " → " .. tostring(new.license) .. "|r" end
    local op = (old.talents and old.talents.plan) or {}
    local np = (new.talents and new.talents.plan) or {}
    local first
    for i = 1, math.max(#op, #np) do
      local a, b2 = op[i], np[i]
      if not a or not b2 or a[1] ~= b2[1] or a[2] ~= b2[2] or a[3] ~= b2[3] then first = (b2 or a) break end
    end
    L[#L + 1] = "Talenty: " .. (first and ("zmiana od poziomu " .. tostring(first[2]) .. " (" .. tostring(first[1]) .. ")") or "bez zmian")
    local ok_, nk = cnt(old.trainer and old.trainer.keep), cnt(new.trainer and new.trainer.keep)
    L[#L + 1] = "Trener: " .. (ok_ == nk and "tyle samo czarów" or (ok_ .. " → " .. nk .. " czarów"))
    local slots = 0
    for _, bar in ipairs({ "main", "bar2", "bar3" }) do
      local a, b2 = (old.bars or {})[bar] or {}, (new.bars or {})[bar] or {}
      for s, c in pairs(b2) do if not a[s] or a[s][1] ~= c[1] then slots = slots + 1 end end
    end
    L[#L + 1] = "Paski: " .. (slots == 0 and "bez zmian" or (slots .. " zmienionych slotów"))
    L[#L + 1] = "Makra: " .. #(old.macros or {}) .. " → " .. #(new.macros or {}) .. " · porady PvP i na stwory: " .. cnt(new.pvp and new.pvp[1]) .. " / " .. cnt(new.creatures)
  end
  if problems and #problems > 0 then L[#L + 1] = "\n" .. U.hex(C.danger) .. "Uwagi walidacji: " .. table.concat(problems, "; ") .. "|r" end
  L[#L + 1] = "\n" .. MUTED .. "Kliknij „Zapisz import”, żeby zapisać. Nic nie zmienia się w grze, dopóki nie ustawisz buildu jako aktywnego.|r"
  return table.concat(L, "\n")
end

-- edycja: wlasny build od razu, inny (wbudowany, Polestar) najpierw jako kopia w „Moje”
local function editBuild(id, sec)
  local b = G.GetBuild and G.GetBuild(id)
  if not b then return end
  if b.src ~= "moje" and b.src ~= "import" then
    local nid = G.DuplicateBuild(id)
    if not nid then U.say("nie udało się zrobić kopii.") return end
    S.sel = nid
    U.say("kopia „" .. (bt(G.GetBuild(nid).name) or nid) .. "” w „Moje”. Gdy skończysz, „Ustaw jako aktywny”.")
    id = nid
  end
  if U.buildEditorOpen then U.buildEditorOpen(id, sec) end
end
U.buildyEdit = editBuild

function U.buildyRefresh()
  if not (S.page and S.page:IsVisible()) then return end
  pcall(drawList)
  local b = S.sel and G.GetBuild and G.GetBuild(S.sel)
  if S.det:IsShown() then
    if S.diffText then
      S.det:Begin() S.det:Para(S.diffText) S.det:End()
      S.diffText = nil
    else
      local ok, err = pcall(U.buildPreviewDraw, S.det, b, editBuild)
      if not ok then S.det:Begin() S.det:Para(U.buildPreview(b) .. "\n\n" .. tostring(err)) S.det:End() end
    end
  end
  local own = b and (b.src == "moje" or b.src == "import")
  S.bEdit:SetShown(b ~= nil)
  S.bEdit:SetLabel(own and "Edytuj" or "Edytuj kopię (zrobi ją w „Moje”)")
  S.bDel:SetShown(own and true or false)
  S.bPolestar:SetShown(b and b.src == "polestar" or false)
  S.bAll:SetLabel(S.allClasses and "Tylko moja klasa" or "Wszystkie klasy")
  if U.buildEditorRefresh then pcall(U.buildEditorRefresh) end
end

local function build(page)
  local left = U.Panel(page, 0.86, true)
  left:SetPoint("TOPLEFT") left:SetPoint("BOTTOMLEFT") left:SetWidth(L_W)
  local h = U.H2(left, "Buildy") h:SetPoint("TOPLEFT", 16, -14)
  S.bAll = U.Button(left, "Wszystkie klasy", nil, 24)
  S.bAll:SetPoint("TOPRIGHT", left, "TOPRIGHT", -14, -12)
  S.bAll:SetScript("OnClick", function() S.allClasses = not S.allClasses U.buildyRefresh() end)
  local view = CreateFrame("ScrollFrame", nil, left)
  view:SetPoint("TOPLEFT", h, "BOTTOMLEFT", 0, -12) view:SetPoint("BOTTOMRIGHT", -12, 12)
  S.list = CreateFrame("Frame", nil, view) S.list:SetSize(L_W - 28, 10)
  view:SetScrollChild(S.list)
  view:EnableMouseWheel(true)
  view:SetScript("OnMouseWheel", function(self, d)
    local max = math.max(0, S.list:GetHeight() - self:GetHeight())
    self:SetVerticalScroll(math.max(0, math.min(max, self:GetVerticalScroll() - d * 84)))
  end)

  local right = U.Panel(page, 0.86, true)
  right:SetPoint("TOPRIGHT") right:SetPoint("BOTTOMRIGHT") right:SetWidth(R_W)
  S.right = right
  local function btn(text, primary, fn, anchor, dy)
    local b = U.Button(right, text, R_W - 40, 30, primary)
    if anchor then b:SetPoint("TOPLEFT", anchor, "BOTTOMLEFT", 0, dy or -8) else b:SetPoint("TOPLEFT", right, "TOPLEFT", 20, -18) end
    b:SetScript("OnClick", act(fn))
    return b
  end
  S.bActive = btn("Ustaw jako aktywny", true, function()
    if InCombatLockdown() then U.say("buildy zmieniam poza walką.") return end
    G.SetActiveBuild(S.sel)
  end)
  S.bDup = btn("Duplikuj do edycji", false, function()
    local id = G.DuplicateBuild(S.sel)
    if id then S.sel = id U.say("kopia do edycji zapisana w „Moje”.") if U.buildEditorOpen then U.buildEditorOpen(id) end end
  end, S.bActive)
  S.bEdit = btn("Edytuj", false, function() editBuild(S.sel) end, S.bDup)
  S.bDel = btn("Usuń (tylko moje i importowane)", false, function()
    if S.delAt and GetTime() - S.delAt < 3 then
      S.delAt = nil
      if G.DeleteOwnBuild(S.sel) then U.say("build usunięty.") S.sel = nil end
    else S.delAt = GetTime() U.say("kliknij jeszcze raz w ciągu 3 s, żeby usunąć.") end
  end, S.bEdit)
  S.bPolestar = btn("Ustaw też w Polestarze", false, function()
    local key = tostring(S.sel):match("^polestar:%u+:(.+)$")
    local T = Polestar and Polestar.Talents
    if key and T and T.Choose and pcall(T.Choose, key) then U.say("Polestar prowadzi talenty według: " .. key .. ".")
    else U.say("Polestar nie przyjął wyboru.") end
  end, S.bDel)
  local pawn = btn("Skala Pawn z buildu", false, function()
    local ok, res = G.ApplyBuildPawn(G.GetBuild(S.sel))
    U.say(ok and ("Pawn: skala „" .. tostring(res) .. "” zapisana i widoczna. Zielona strzałka pokaże lepsze przedmioty dla tego buildu.") or ("Pawn: " .. tostring(res) .. "."))
  end, S.bPolestar, -14)
  local exp = btn("Eksportuj (kod do skopiowania)", false, function()
    local code, err = G.BuildExport(G.GetBuild(S.sel))
    if code then showCode(code, "Kod buildu: Ctrl+C, wklej znajomemu albo na Discord")
    else U.say("eksport się nie udał: " .. tostring(err)) end
  end, pawn)
  -- import w dwoch krokach (R27 4b): 1) wklej i kliknij: podglad z roznicami wzgledem posiadanej wersji, 2) zapisz
  local imp
  imp = btn("Importuj: wklej kod niżej, potem kliknij", false, function()
    if S.pending then
      local b = S.pending
      S.pending = nil
      imp:SetLabel("Importuj: wklej kod niżej, potem kliknij")
      local ok, id = G.BuildImportSave(b)
      if ok then S.sel = id U.say("zaimportowano: " .. (bt(b.name) or id) .. ". Ustaw jako aktywny, gdy chcesz.") end
      return
    end
    local b, err, problems = G.BuildImport(S.code:GetText())
    if not b then U.say("import: " .. tostring(err)) return end
    S.pending = b
    imp:SetLabel("Zapisz import (" .. G.BuildImportState(b) .. ")")
    S.diffText = U.buildDiff(G.GetBuild(b.id), b, problems)
  end, exp)
  S.codeL = U.Text(right, 12, "body", C.muted)
  S.codeL:SetPoint("TOPLEFT", imp, "BOTTOMLEFT", 0, -12)
  S.codeL:SetText("Kod buildu (wklej tutaj przy imporcie):")
  local cf = CreateFrame("ScrollFrame", nil, right, "InputScrollFrameTemplate")
  cf:SetPoint("TOPLEFT", S.codeL, "BOTTOMLEFT", 4, -6)
  cf:SetSize(R_W - 52, 150)
  S.code = cf.EditBox
  S.code:SetWidth(R_W - 70)
  S.code:SetMaxLetters(64000)
  S.code:SetAutoFocus(false)
  pcall(function() cf.CharCount:Hide() end)
  S.code:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
  local note = U.Para(right, 12, R_W - 40, C.faint)
  note:SetPoint("TOPLEFT", cf, "BOTTOMLEFT", -4, -10)
  note:SetText("Import przyjmuje tylko dane: bez kodu, makra bez /run i /script. „Edytuj” przy buildzie wbudowanym albo z Polestara robi Twoją kopię w „Moje”. Sam Polestar nie przyjmuje zmienionych planów, więc kopia żyje w Grimuarze.")

  S.det = U.Blocks(page)
  S.det:SetPoint("TOPLEFT", left, "TOPRIGHT", 20, 0)
  S.det:SetPoint("BOTTOMRIGHT", right, "BOTTOMLEFT", -20, 0)
  S.page = page
  if U.buildEditorBuild then pcall(U.buildEditorBuild, page, S.det) end
end

U.RegisterTab({
  id = "buildy", order = 2.5, title = "Buildy", keys = "",
  hints = { { { "LPM" }, "Wybierz build" } },
  note = "Build to dane: talenty, trener, paski, combo i porady. Kod udostępniasz znajomym",
  build = build,
  refresh = function() C_Timer.After(0, function() pcall(U.buildyRefresh) end) end,
  leave = function() if S.code then S.code:ClearFocus() end end,
})
function U.buildySelected() return S.sel end
function U.buildySelect(id) S.sel = id end
