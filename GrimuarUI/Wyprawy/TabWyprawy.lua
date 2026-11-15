-- Grimuar UI: zakladka Wyprawy (14.11, R25 G1–G10). Lewo: lochy i rajdy (Polestar.Dungeons, plan Grimuara) z ocena dla
-- Waszej druzyny. Srodek: karta lochu: kto idzie (Ty, grupa, zaznaczeni znajomi online), wspolny loch (G1: XP dla
-- wszystkich, szare moby od 13.11), wejscie i teren, bossowie i questy (Polestar), Prowadz do wejscia.
-- Prawo: Wieczor (G3 + G9), Druzyna (G8 stan znajomych z Grimuarem, G10 sklad, G2 wejscia i blokady),
-- Przed lochem (G7 ping i lista). Dane: WyprawyDane.lua, WyprawySync.lua.
-- 14.11 (R26 P2): pasek „Kto idzie” nad cala zakladka z wynikiem G1; lewa lista w sekcjach (Pasuje, Czesc szara,
-- Wkrotce, Rajdy, Za nisko); karta lochu w stronach Przeglad / Bossowie / Questy / Lupy (lupy bossow z Polestar.Codex);
-- „Na mapie” (mapa huba z wejsciem). Historia wypraw jest w Kronice.
-- 15.11 gracz: „to by mozna bylo ikonami jednak pokazywac”: Lupy jako siatka ikon (Hub\Bloki.lua) z ramka jakosci,
-- dymkiem przedmiotu (tam ocena Pawna), strzalka Pawna przy ulepszeniu; receptury osobno, mniejsze.
local ADDON, U = ...
local C = U.C

local S = { sel = nil, right = "wieczor", rows = {}, chips = {}, cpage = "przeglad" }
local L_W, R_W = 340, 430
local GOLD, MUTED, OK, TEXT = U.hex(C.gold), U.hex(C.muted), U.hex(C.ok), U.hex(C.text)
local FIT = { ok = { "pasuje", C.ok }, czesc = { "część szara", C.gold }, szary = { "0 XP", C.danger }, trudny = { "za trudny", C.faint } }

-- ---------- lewa lista ----------
local function row(i)
  local r = S.rows[i]
  if r then return r end
  r = CreateFrame("Button", nil, S.list)
  r:SetHeight(44)
  local hl = r:CreateTexture(nil, "HIGHLIGHT") hl:SetAllPoints() hl:SetColorTexture(1, 1, 1, 0.05)
  r.selT = r:CreateTexture(nil, "BACKGROUND") r.selT:SetAllPoints() r.selT:SetColorTexture(C.gold[1], C.gold[2], C.gold[3], 0.10)
  r.art = r:CreateTexture(nil, "ARTWORK")
  r.art:SetSize(36, 36) r.art:SetPoint("LEFT", 6, 0)
  r.t = U.Text(r, 14, "body", C.text) r.t:SetPoint("TOPLEFT", 10, -5)
  r.s = U.Text(r, 11, "body", C.muted) r.s:SetPoint("TOPLEFT", r.t, "BOTTOMLEFT", 0, -4)
  r.tag = U.Tag(r, "") r.tag:SetPoint("RIGHT", -8, 0)
  r:SetScript("OnClick", function(self) if self.key then S.sel = self.key U.wyprawyRefresh() end end)
  S.rows[i] = r
  return r
end
local SECTIONS = { { "ok", "Pasuje" }, { "czesc", "Część szara" }, { "wkrotce", "Wkrótce" }, { "pozniej", "Później" }, { "rajd", "Rajdy (60)" }, { "nisko", "Za nisko" } }
local function sectionOf(d, members, lvl)
  if d.raid then return "rajd" end
  local v = U.dungeonFit(d, members)
  if v == "ok" then return "ok" elseif v == "czesc" then return "czesc" end
  if v == "trudny" then return ((d.minLevel or 0) <= lvl + 10) and "wkrotce" or "pozniej" end
  return "nisko"
end
local function drawList(members)
  local list = U.dungeonList and U.dungeonList() or {}
  local w = L_W - 28
  local lvl = UnitLevel("player") or 1
  local by = {}
  for _, d in ipairs(list) do
    local sec = sectionOf(d, members, lvl)
    by[sec] = by[sec] or {}
    table.insert(by[sec], d)
  end
  if not S.sel then
    local first = (by.ok and by.ok[1]) or (by.czesc and by.czesc[1]) or list[1]
    S.sel = first and first.key
  end
  local n, y = 0, 0
  for _, sec in ipairs(SECTIONS) do
    local items = by[sec[1]]
    if items and #items > 0 then
      n = n + 1
      local h = row(n)
      h.key = nil
      h:SetWidth(w) h:SetHeight(26)
      h:ClearAllPoints() h:SetPoint("TOPLEFT", S.list, "TOPLEFT", 0, -y)
      h.t:SetText(sec[2]:upper() .. "  (" .. #items .. ")") U.Color(h.t, C.goldDim)
      h.s:SetText("") h.tag:Hide() h.selT:Hide() h.art:Hide()
      h.t:ClearAllPoints() h.t:SetPoint("TOPLEFT", 10, -5)
      h:Show()
      y = y + 28
      for _, d in ipairs(items) do
        n = n + 1
        local r = row(n)
        r.key = d.key
        r:SetWidth(w) r:SetHeight(44)
        r:ClearAllPoints() r:SetPoint("TOPLEFT", S.list, "TOPLEFT", 0, -y)
        local art = U.dungeonArt and U.dungeonArt(d.key)
        r.art:SetShown(art ~= nil)
        if art then r.art:SetTexture(art.file) r.art:SetTexCoord(art.l, art.r, art.t, art.b) end
        r.t:ClearAllPoints() r.t:SetPoint("TOPLEFT", art and 50 or 10, -5)
        r.t:SetText(d.name) r.t:SetWidth(w - (art and 140 or 100))
        U.Color(r.t, d.key == S.sel and C.gold or ((sec[1] == "nisko" or sec[1] == "wkrotce") and C.muted or C.text))
        r.s:SetText((d.forever and (U.hex(C.frost) .. "Forever|r · ") or "") .. "poz. " .. (d.minLevel or "?") .. "–" .. (d.maxLevel or "?") .. " · " .. (d.players or 5) .. " os." .. (d.zoneName and (" · " .. d.zoneName) or "") .. (d.enemy and " · teren Hordy" or ""))
        r.s:SetWidth(w - (art and 60 or 20))
        local v = U.dungeonFit(d, members)
        local f = FIT[v]
        r.tag:SetShown(f ~= nil and sec[1] ~= "nisko")
        if f then r.tag:SetTag(d.raid and (d.players .. " os.") or f[1], f[2]) end
        r.selT:SetShown(d.key == S.sel)
        r:Show()
        y = y + 46
      end
    end
  end
  for i = n + 1, #S.rows do S.rows[i]:Hide() end
  S.list:SetHeight(math.max(10, y))
end

-- ---------- srodek: karta lochu ----------
local function drawChips()
  local fr = U.onlineFriends and U.onlineFriends() or {}
  local x = 0
  for i = 1, math.max(#fr, #S.chips) do
    local f, b = fr[i], S.chips[i]
    if f and i <= 8 then
      if not b then
        b = U.Button(S.chipRow, "", nil, 24)
        S.chips[i] = b
      end
      local on = U.expeditionSelected(f.name)
      b:SetLabel((on and "◆ " or "+ ") .. f.name .. (f.level and (" " .. f.level) or ""))
      U.Color(b.label, on and C.gold or C.muted)
      b:ClearAllPoints()
      b:SetPoint("LEFT", S.chipRow, "LEFT", x, 0)
      x = x + b:GetWidth() + 6
      b:SetScript("OnClick", function() U.expeditionToggle(f.name) U.wyprawyRefresh() end)
      b:Show()
    elseif b then b:Hide() end
  end
  S.chipNone:SetShown(#fr == 0)
end

local function questLines(qs, limit)
  local L = {}
  for i, q in ipairs(qs) do
    if limit and i > limit then L[#L + 1] = MUTED .. "… i jeszcze " .. (#qs - limit) .. " (strona Questy)|r" break end
    local done = U.call(C_QuestLog.IsQuestFlaggedCompleted, q.id)
    local has = U.call(C_QuestLog.GetLogIndexForQuestID, q.id)
    local mark = done and (OK .. "◆ zrobione|r") or (has and (GOLD .. "◇ w dzienniku|r") or (MUTED .. "◇ do wzięcia|r"))
    local start = q.start and q.start.name and (MUTED .. " · od: " .. q.start.name .. "|r") or ""
    local inside = q.inside and (MUTED .. " · w lochu|r") or ""
    L[#L + 1] = "[" .. tostring(q.level or "?") .. "] " .. (q.title or "?") .. "  " .. mark .. start .. inside
  end
  return L
end

local function infoLine(d)
  local best = U.dungeonBestAt and U.dungeonBestAt(d.key)
  return (d.raid and "Rajd, " or "Loch, ") .. (d.players or 5) .. " osób · poziomy " .. (d.minLevel or "?") .. "–" .. (d.maxLevel or "?") ..
    ((best and (d.maxLevel or 0) > (d.minLevel or 0)) and (" · najlepiej na " .. best) or "") ..
    (d.pRange and (MUTED .. " (Polestar: " .. d.pRange .. ")|r") or "") ..
    (d.zoneName and (" · wejście: " .. d.zoneName) or "")
end

-- ---------- lupy: siatka ikon ----------
local function instant(id)
  if not (C_Item and C_Item.GetItemInfoInstant) then return nil end
  local ok, _, _, _, equip, icon, classID = pcall(C_Item.GetItemInfoInstant, id)
  if ok then return equip, icon, classID end
  return nil
end
local function drawLoot(d)
  local p = S.lootP
  p:Begin(S.lootKey == "l:" .. d.key)
  S.lootKey = "l:" .. d.key
  if S.hasBanner then p:Para(infoLine(d), C.text) else p:Title(d.name, infoLine(d)) end
  local loot = U.dungeonLoot and U.dungeonLoot(d.key)
  if not loot or #loot == 0 then
    p:Para("Polestar nie ma łupów tego miejsca (nowe lochy Forever i rajdy jeszcze nie są opisane).", C.muted)
    p:End()
    return
  end
  -- 15.11 (R30 P28): klik w ikone wybiera przedmiot, nad lupami „Skąd zdobyć” i „Prowadź po to” (EkwipunekPolestar.lua)
  if S.pickKey ~= d.key then S.pick, S.pickName, S.pickKey = nil, nil, d.key end
  if S.pick and U.psSourceBlocks then
    local okS, err = pcall(U.psSourceBlocks, p, S.pick, S.pickName)
    if not okS and U.logError then U.logError("wyprawy/skad", err) end
  end
  local iconOpts = { onPick = function(id, nm) S.pick, S.pickName = id, nm U.wyprawyRefresh() end, selected = S.pick }
  for _, b in ipairs(loot) do
    if #b.items > 0 then
      local gear, rec = {}, {}
      for _, it in ipairs(b.items) do
        local _, icon, classID = instant(it.id)
        local x = { id = it.id, name = it.name, quality = it.quality, icon = icon }
        if classID == 9 then rec[#rec + 1] = x else gear[#gear + 1] = x end
      end
      table.sort(gear, function(a, c) return (a.quality or 2) > (c.quality or 2) end)
      p:Head(b.name or "?", #gear .. " przedm." .. (#rec > 0 and (" · " .. #rec .. " receptur") or ""))
      p:Icons(gear, iconOpts)
      if #rec > 0 then
        p:Para("Receptury i plany", C.faint, 11)
        p:Icons(rec, { size = 30, onPick = iconOpts.onPick, selected = S.pick })
      end
    end
  end
  p:Gap(6)
  p:Para("Najedź na ikonę: dymek przedmiotu z oceną Pawna (zielona strzałka = ulepszenie dla Ciebie). Klik: skąd zdobyć (Polestar). Shift+klik: link na czat, Ctrl+klik: przymierz.", C.muted, 12)
  p:End()
end

-- 15.11 (R30 P46): strona Questy jako bloki: zbierz questy, oddaj po lochu, zestrojenia (WyprawyPolestar.lua), pod nimi
-- pelna lista questow lochu jak dotad
local function drawQuests(d)
  local p = S.lootP
  p:Begin(S.lootKey == "q:" .. d.key)
  S.lootKey = "q:" .. d.key
  if S.hasBanner then p:Para(infoLine(d), C.text) else p:Title(d.name, infoLine(d)) end
  if U.dungeonPlanBlocks then
    local ok, err = pcall(U.dungeonPlanBlocks, p, d)
    if not ok and U.logError then U.logError("wyprawy/plan", err) end
  end
  local qs = U.dungeonQuests and U.dungeonQuests(d.key) or {}
  p:Head("Wszystkie questy lochu", #qs > 0 and tostring(#qs) or "")
  if #qs == 0 then
    p:Para(d.src ~= "Polestar" and "Zadania lochu: włącz Polestar (moduł lochów)." or "Brak zadań Przymierza do tego lochu.", C.muted)
  else
    local xl = U.dungeonQuestXPLine and U.call(U.dungeonQuestXPLine, d.key)
    if xl then p:Para(xl, C.text, 12) end
    p:Para(table.concat(questLines(qs), "\n"), C.text, 12)
  end
  p:End()
end

local function cardText(d, members)
  local L = {}
  if not S.hasBanner then L[#L + 1] = GOLD .. d.name .. "|r" end
  L[#L + 1] = infoLine(d)
  local qs = U.dungeonQuests and U.dungeonQuests(d.key) or {}
  local bosses = U.dungeonBosses and U.dungeonBosses(d.key) or {}
  if S.cpage == "przeglad" then
    if d.enemy then L[#L + 1] = U.hex(C.danger) .. d.enemy .. "|r" end
    if d.note then L[#L + 1] = MUTED .. d.note .. "|r" end
    if d.raid then
      local _, cls = UnitClass("player")
      L[#L + 1] = MUTED .. "Skład i blokady: prawa kolumna, Drużyna." .. (cls and "" or "") .. "|r"
    end
    -- postep: questy i ostatnia wyprawa (Kronika)
    if #qs > 0 then
      local done, has = 0, 0
      for _, q in ipairs(qs) do
        if U.call(C_QuestLog.IsQuestFlaggedCompleted, q.id) then done = done + 1 elseif U.call(C_QuestLog.GetLogIndexForQuestID, q.id) then has = has + 1 end
      end
      L[#L + 1] = "\n" .. GOLD .. "TWÓJ POSTĘP|r"
      L[#L + 1] = "Zadania: " .. done .. " zrobione, " .. has .. " w dzienniku, " .. (#qs - done - has) .. " do wzięcia · bossowie: " .. #bosses
      -- 15.11 (R30 P47): ile poziomu daja questy lochu (Polestar Dungeons.QuestXP, WyprawyPolestar.lua)
      local xl = U.dungeonQuestXPLine and U.call(U.dungeonQuestXPLine, d.key)
      if xl then L[#L + 1] = xl end
    end
    local last
    for _, r in ipairs(U.expeditionRuns and U.expeditionRuns() or {}) do if r.name == d.name then last = r end end
    if last then L[#L + 1] = "Ostatnio: " .. U.fmtDate(last.start) .. " · bossowie " .. #(last.bosses or {}) .. ((#(last.members or {}) > 0) and (" · z: " .. table.concat(last.members, ", ")) or "") end
    -- 15.11 (R30 P27): limit wejsc do lochow (Polestar Maps.GetInstanceStatus); rajd ma blokade, nie limit
    if not d.raid then
      local il = U.instanceStatusLine and U.call(U.instanceStatusLine)
      if il then L[#L + 1] = (#qs > 0 and "" or "\n") .. il end
    end
  elseif S.cpage == "bossowie" then
    if #bosses == 0 then L[#L + 1] = "\n" .. MUTED .. "Polestar nie zna bossów tego miejsca (nowy loch Forever albo Polestar wyłączony).|r" end
    for _, b in ipairs(bosses) do
      L[#L + 1] = "\n" .. TEXT .. (b.order and (b.order .. ". ") or "") .. (b.name or "?") .. "|r" .. (b.level and (MUTED .. "  poziom " .. b.level .. "|r") or "") ..
        (b.role and (MUTED .. "  · " .. ({ rare = "rzadki", event = "wydarzenie", optional = "opcjonalny" })[b.role] or b.role) .. "|r" or "")
      local tq = {}
      for _, q in ipairs(b.quests or {}) do tq[#tq + 1] = (q.itemName or ("zadanie " .. tostring(q.id))) .. " (" .. (({ kill = "zabij", item = "przedmiot", starts = "zaczyna zadanie", involved = "w zadaniu" })[q.how] or q.how or "?") .. ")" end
      if #tq > 0 then L[#L + 1] = MUTED .. "   zadania: " .. table.concat(tq, ", ") .. "|r" end
    end
  elseif S.cpage == "questy" then
    if #qs == 0 then L[#L + 1] = "\n" .. MUTED .. (d.src ~= "Polestar" and "Zadania lochu: włącz Polestar (moduł lochów)." or "Brak zadań Przymierza do tego lochu.") .. "|r" end
    local xl = #qs > 0 and U.dungeonQuestXPLine and U.call(U.dungeonQuestXPLine, d.key)
    if xl then L[#L + 1] = "\n" .. xl end
    L[#L + 1] = ""
    for _, x in ipairs(questLines(qs)) do L[#L + 1] = x end
  elseif S.cpage == "lupy" then
    local loot = U.dungeonLoot and U.dungeonLoot(d.key)
    if not loot or #loot == 0 then
      L[#L + 1] = "\n" .. MUTED .. "Polestar nie ma łupów tego miejsca (nowe lochy Forever i rajdy jeszcze nie są opisane).|r"
    else
      for _, b in ipairs(loot) do
        if #b.items > 0 then
          L[#L + 1] = "\n" .. GOLD .. (b.name or "?"):upper() .. "|r"
          local t2 = {}
          for _, it in ipairs(b.items) do
            local col = U.QUALITY[it.quality or 2] or C.text
            t2[#t2 + 1] = U.hex(col) .. it.name .. "|r"
          end
          L[#L + 1] = table.concat(t2, " · ")
        end
      end
      L[#L + 1] = "\n" .. MUTED .. "Zielone i lepsze. Czy to ulepszenie dla Ciebie, pokaże Pawn w dymku przedmiotu.|r"
    end
  end
  return table.concat(L, "\n")
end

-- ---------- prawo ----------
local function rightText(d)
  local L = {}
  if S.right == "druzyna" then
    L[#L + 1] = GOLD .. "ZNAJOMI Z GRIMUAREM|r"
    local any = false
    for name, p in pairs(U.peers and U.peers() or {}) do
      any = true
      local parts = { "poz. " .. p.lvl .. " (" .. p.xp .. "%)", p.zone or "?" }
      if p.water >= 0 then parts[#parts + 1] = "woda " .. p.water end
      if p.dura >= 0 then parts[#parts + 1] = "sprzęt " .. p.dura .. "%" end
      if p.bags >= 0 then parts[#parts + 1] = "torby " .. p.bags end
      L[#L + 1] = TEXT .. name .. "|r  " .. table.concat(parts, " · ") .. ((p.avail and p.avail ~= "") and (MUTED .. " · może: " .. p.avail .. "|r") or "")
    end
    if not any then L[#L + 1] = MUTED .. "Nikt z grupy nie ma GrimuarUI. Gdy znajomi go zainstalują, zobaczysz tu ich poziom, strefę, wodę i sprzęt.|r" end
    L[#L + 1] = "\n" .. GOLD .. "SKŁAD|r"
    for _, ln in ipairs(U.raidComposition and U.raidComposition() or {}) do L[#L + 1] = (ln[2] and OK .. "◆ |r" or U.hex(C.danger) .. "◇ |r") .. ln[1] end
    local n, nextFree = U.instanceEntries()
    L[#L + 1] = "\n" .. GOLD .. "WEJŚCIA I BLOKADY|r"
    -- 15.11 (R30 P27): licznik Polestara (konto, Maps.GetInstanceStatus), bez niego licznik Grimuara
    local il = U.instanceStatusLine and U.call(U.instanceStatusLine)
    L[#L + 1] = il or ("Nowe wejścia w tej godzinie: " .. n .. " / 5" .. (nextFree and (" · następne wolne o " .. date("%H:%M", nextFree)) or ""))
    L[#L + 1] = MUTED .. "Limit liczy konto: 5 różnych lochów na godzinę. Reset lochu: PPM na swoim portrecie (lider).|r"
    local saved = U.savedInstances()
    if #saved == 0 then L[#L + 1] = MUTED .. "Brak blokad rajdowych.|r" end
    for _, s in ipairs(saved) do
      L[#L + 1] = s.name .. (s.diff and (" (" .. s.diff .. ")") or "") .. (s.n and (" · " .. (s.prog or 0) .. "/" .. s.n .. " bossów") or "") ..
        (s.reset and (" · reset za " .. U.inText(s.reset)) or "")
    end
  elseif S.right == "przed" then
    L[#L + 1] = GOLD .. "PRZED LOCHEM: " .. (d and d.name or "") .. "|r"
    for _, ln in ipairs(U.beforeDungeon and U.beforeDungeon(d) or {}) do L[#L + 1] = (ln[2] and OK .. "◆ |r" or GOLD .. "◇ |r") .. ln[1] end
    local _, cls = UnitClass("player")
    if cls == "MAGE" then
      L[#L + 1] = "\n" .. MUTED .. "Mag w grupie: woda dla wszystkich, owca (księżyc) na drugiego humanoida, klątwy z ramek, Arcane Intellect przed walką.|r"
    end
  end
  return table.concat(L, "\n")
end

local function drawEvening(d)
  local p = U.eveningGet and U.eveningGet()
  S.form.dname:SetText("Loch: " .. GOLD .. (d and d.name or "?") .. "|r")
  if p then
    local yes, n, ans = U.planAnswers()
    local a = {}
    for who, x in pairs(ans) do a[#a + 1] = who .. " " .. (x == "tak" and "◆" or (x == "moze" and "?" or "×")) end
    S.form.state:SetText(GOLD .. "Zapisany: " .. p.name .. " · " .. U.fmtDate(p.epoch) .. "|r\n" ..
      (n > 0 and ("Potwierdzenia: " .. yes .. " z " .. n .. "  (" .. table.concat(a, ", ") .. ")") or MUTED .. "Odpowiedzi przyjdą od znajomych z Grimuarem.|r"))
    S.form.copy:SetText(U.eveningText(p, S.lang))
  else
    S.form.state:SetText(MUTED .. "Wybierz loch z listy, wpisz dzień i godzinę, kliknij Zapisz.|r")
    S.form.copy:SetText("")
  end
end

-- 14.11 (R26 P1.3): jeden blok wg stanu, dopoki sam nie wybierzesz: w lochu Druzyna, w grupie Przed lochem, solo Wieczor
local function autoRight()
  if S.userRight then return end
  local inInst, typ = U.call(IsInInstance)
  if inInst and (typ == "party" or typ == "raid") then S.right = "druzyna"
  elseif U.call(IsInGroup) then S.right = "przed"
  else S.right = "wieczor" end
end

-- 15.11: obraz lochu z Polestara nad karta (pas z ekranu ladowania, przyciemniony u dolu), nazwa i znak Forever
local BANNER_H = 118
local function paintBanner(d)
  local art = d and U.dungeonArt and U.dungeonArt(d.key)
  local y = -48
  S.hasBanner = art ~= nil
  if art then
    local W = S.banner:GetWidth() or 0
    if W < 50 then W = (S.mid:GetWidth() or 600) - 2 end
    local R = (art.b - art.t) / (art.r - art.l) -- szerokosc / wysokosc obrazu (kadr l..r, t..b jest kwadratem)
    local v = math.min(1, R / (W / BANNER_H))
    local top = math.max(0, math.min(1 - v, (art.t + art.b) / 2 - v / 2))
    S.banner.tex:SetTexture(art.file)
    S.banner.tex:SetTexCoord(0, 1, top, top + v)
    S.banner.name:SetText(d.name)
    S.banner.tag:SetShown(d.forever == true)
    S.banner:Show()
    y = -48 - BANNER_H - 6
  else
    S.banner:Hide()
  end
  for _, f in ipairs({ S.card, S.lootP }) do
    f:ClearAllPoints()
    f:SetPoint("TOPLEFT", S.mid, "TOPLEFT", 0, y)
    f:SetPoint("BOTTOMRIGHT", S.mid, "BOTTOMRIGHT", 0, 52)
  end
end

function U.wyprawyRefresh()
  if not (S.mid and S.mid:IsVisible()) then return end
  autoRight()
  local members = U.expeditionMembers and U.expeditionMembers() or {}
  pcall(drawChips)
  pcall(drawList, members)
  local d = S.sel and U.dungeonGet(S.sel)
  pcall(paintBanner, d)
  S.psBtn:SetShown(d ~= nil and d.src == "Polestar")
  -- 15.11 (R30 P18/P27): czas dojscia do wejscia na przycisku (planer Polestara, G.etaText)
  if S.goBtn then S.goBtn:SetLabel("Prowadź do wejścia" .. ((d and U.dungeonEntranceEta and U.call(U.dungeonEntranceEta, d)) or "")) end
  -- 15.11 (R30 P46): Lupy i Questy jako bloki (karty), Przeglad i Bossowie jako tekst
  local lootPage = d ~= nil and (S.cpage == "lupy" or S.cpage == "questy")
  S.card:SetShown(not lootPage)
  S.lootP:SetShown(lootPage)
  if lootPage then
    local ok, err = pcall(S.cpage == "questy" and drawQuests or drawLoot, d)
    if not ok then S.lootP:Hide() S.card:Show() S.card:Set(cardText(d, members) .. "\n" .. MUTED .. tostring(err) .. "|r") end
  elseif d then S.card:Set(cardText(d, members)) else S.card:Set(MUTED .. "Brak listy lochów.|r") end
  -- pasek „Kto idzie”: wynik G1 dla wybranego lochu
  local names = {}
  for _, m in ipairs(members) do names[#names + 1] = (m.me and "Ty" or m.name) .. " " .. tostring(m.level or "?") end
  if d then
    local v, txt = U.dungeonFit(d, members)
    S.fit:SetText(table.concat(names, " · ") .. "   " .. (v == "ok" and OK or (v == "czesc" and GOLD or U.hex(C.danger))) .. "◆ " .. d.name .. ": " .. txt .. "|r")
  else S.fit:SetText(table.concat(names, " · ")) end
  for k, b in pairs(S.ctabs) do
    U.Color(b.label, k == S.cpage and C.gold or C.muted)
    U.BorderColor(b, k == S.cpage and C.gold or C.edge)
  end
  for k, b in pairs(S.rtabs) do
    U.Color(b.label, k == S.right and C.gold or C.muted)
    U.BorderColor(b, k == S.right and C.gold or C.edge)
  end
  S.form:SetShown(S.right == "wieczor")
  S.rtext:SetShown(S.right ~= "wieczor")
  if S.right == "wieczor" then pcall(drawEvening, d) else S.rtext:Set(rightText(d)) end
end

local function edit(parent, w, default)
  local e = CreateFrame("EditBox", nil, parent, "InputBoxTemplate")
  e:SetSize(w, 26)
  e:SetAutoFocus(false)
  e:SetText(default or "")
  e:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
  e:SetScript("OnEnterPressed", function(self) self:ClearFocus() end)
  return e
end

local function build(page)
  -- gora: kto idzie (cala szerokosc)
  local top = CreateFrame("Frame", nil, page)
  top:SetPoint("TOPLEFT") top:SetPoint("TOPRIGHT") top:SetHeight(40)
  local kh = U.Label(top, "Kto idzie")
  kh:SetPoint("LEFT", 0, 0)
  S.chipRow = CreateFrame("Frame", nil, top)
  S.chipRow:SetPoint("LEFT", kh, "RIGHT", 12, 0)
  S.chipRow:SetSize(700, 26)
  S.chipNone = U.Text(S.chipRow, 12, "body", C.faint)
  S.chipNone:SetPoint("LEFT")
  S.chipNone:SetText("Nikt ze znajomych nie jest w grze. Drużyna liczy się sama.")
  S.fit = U.Text(top, 13, "body", C.text)
  S.fit:SetPoint("RIGHT", top, "RIGHT", 0, 0)
  S.fit:SetJustifyH("RIGHT")
  -- lewo
  local left = U.Panel(page, 0.86, true)
  left:SetPoint("TOPLEFT", 0, -52) left:SetPoint("BOTTOMLEFT") left:SetWidth(L_W)
  local h = U.H2(left, "Lochy i rajdy") h:SetPoint("TOPLEFT", 16, -14)
  local view = CreateFrame("ScrollFrame", nil, left)
  view:SetPoint("TOPLEFT", h, "BOTTOMLEFT", 0, -10) view:SetPoint("BOTTOMRIGHT", -12, 12)
  S.list = CreateFrame("Frame", nil, view) S.list:SetSize(L_W - 28, 10)
  view:SetScrollChild(S.list)
  view:EnableMouseWheel(true)
  view:SetScript("OnMouseWheel", function(self, dd)
    local max = math.max(0, S.list:GetHeight() - self:GetHeight())
    self:SetVerticalScroll(math.max(0, math.min(max, self:GetVerticalScroll() - dd * 92)))
  end)
  -- prawo
  local right = U.Panel(page, 0.86, true)
  right:SetPoint("TOPRIGHT", 0, -52) right:SetPoint("BOTTOMRIGHT") right:SetWidth(R_W)
  S.rtabs = {}
  local prev
  for _, t in ipairs({ { "wieczor", "Wieczór" }, { "druzyna", "Drużyna" }, { "przed", "Przed lochem" } }) do
    local b = U.Button(right, t[2], nil, 26)
    if prev then b:SetPoint("LEFT", prev, "RIGHT", 6, 0) else b:SetPoint("TOPLEFT", right, "TOPLEFT", 16, -14) end
    b:SetScript("OnClick", function() S.right, S.userRight = t[1], true U.wyprawyRefresh() end)
    S.rtabs[t[1]] = b
    prev = b
  end
  S.rtext = U.TextPanel(right)
  S.rtext:SetPoint("TOPLEFT", 0, -48) S.rtext:SetPoint("BOTTOMRIGHT")
  S.rtext.bg:Hide()
  -- formularz wieczoru (G3, G9)
  local f = CreateFrame("Frame", nil, right)
  f:SetPoint("TOPLEFT", 16, -52) f:SetPoint("BOTTOMRIGHT", -16, 14)
  S.form = f
  f.dname = U.Text(f, 14, "body", C.text) f.dname:SetPoint("TOPLEFT", 0, 0)
  local labels, y = {}, -28
  local function field(label, w, def)
    local l = U.Text(f, 12, "body", C.muted) l:SetPoint("TOPLEFT", 0, y - 6) l:SetText(label)
    local e = edit(f, w, def) e:SetPoint("TOPLEFT", 110, y)
    y = y - 32
    labels[#labels + 1] = l
    return e
  end
  f.day = field("Dzień (dd.mm)", 90, date("%d.%m"))
  f.time = field("Godzina", 90, "20:00")
  f.lead = field("Prowadzi", 160, UnitName("player"))
  f.avail = field("Mogę dziś", 160, U.db().mogeDzis or "")
  f.avail:SetScript("OnTextChanged", function(self) U.db().mogeDzis = self:GetText() end)
  local save = U.Button(f, "Zapisz wieczór", nil, 28, true)
  save:SetPoint("TOPLEFT", 0, y - 4)
  save:SetScript("OnClick", function()
    if U.eveningSet(S.sel, f.day:GetText(), f.time:GetText(), f.lead:GetText()) then U.wyprawyRefresh() end
  end)
  local guide = U.Button(f, "Prowadź na zbiórkę", nil, 28)
  guide:SetPoint("LEFT", save, "RIGHT", 8, 0)
  guide:SetScript("OnClick", function() U.eveningGuide() end)
  y = y - 40
  local wh = U.Button(f, "Szepnij zaznaczonym", nil, 28)
  wh:SetPoint("TOPLEFT", 0, y)
  wh:SetScript("OnClick", function()
    local names = {}
    for _, fr in ipairs(U.onlineFriends()) do if U.expeditionSelected(fr.name) then names[fr.name] = true end end
    U.eveningWhisper(names)
  end)
  local party = U.Button(f, "Na czat drużyny", nil, 28)
  party:SetPoint("LEFT", wh, "RIGHT", 8, 0)
  party:SetScript("OnClick", function() U.eveningParty() end)
  y = y - 40
  f.state = U.Para(f, 13, R_W - 40, C.text)
  f.state:SetPoint("TOPLEFT", 0, y)
  local cl = U.Text(f, 12, "body", C.muted)
  cl:SetPoint("TOPLEFT", f.state, "BOTTOMLEFT", 0, -14)
  cl:SetText("Tekst na Discord (kliknij, Ctrl+A, Ctrl+C):")
  local lang = U.Button(f, "PL / EN", nil, 22)
  lang:SetPoint("LEFT", cl, "RIGHT", 8, 0)
  lang:SetScript("OnClick", function() S.lang = S.lang == "en" and nil or "en" U.wyprawyRefresh() end)
  f.copy = CreateFrame("EditBox", nil, f, "InputBoxTemplate")
  f.copy:SetSize(R_W - 50, 26)
  f.copy:SetAutoFocus(false)
  f.copy:SetPoint("TOPLEFT", cl, "BOTTOMLEFT", 6, -8)
  f.copy:SetScript("OnEditFocusGained", function(self) self:HighlightText() end)
  f.copy:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
  -- srodek
  local mid = U.Panel(page, 0.86, true)
  mid:SetPoint("TOPLEFT", left, "TOPRIGHT", 20, 0)
  mid:SetPoint("BOTTOMRIGHT", right, "BOTTOMLEFT", -20, 0)
  S.mid = mid
  S.ctabs = {}
  local cprev
  for _, c in ipairs({ { "przeglad", "Przegląd" }, { "bossowie", "Bossowie" }, { "questy", "Questy" }, { "lupy", "Łupy" } }) do
    local b = U.Button(mid, c[2], nil, 26)
    if cprev then b:SetPoint("LEFT", cprev, "RIGHT", 6, 0) else b:SetPoint("TOPLEFT", mid, "TOPLEFT", 20, -14) end
    b:SetScript("OnClick", function() S.cpage = c[1] U.wyprawyRefresh() end)
    S.ctabs[c[1]] = b
    cprev = b
  end
  S.banner = CreateFrame("Frame", nil, mid)
  S.banner:SetPoint("TOPLEFT", mid, "TOPLEFT", 1, -48)
  S.banner:SetPoint("TOPRIGHT", mid, "TOPRIGHT", -1, -48)
  S.banner:SetHeight(BANNER_H)
  S.banner.tex = S.banner:CreateTexture(nil, "BACKGROUND", nil, 2)
  S.banner.tex:SetAllPoints()
  S.banner.shade = S.banner:CreateTexture(nil, "ARTWORK")
  S.banner.shade:SetAllPoints()
  S.banner.shade:SetColorTexture(1, 1, 1, 1)
  pcall(S.banner.shade.SetGradient, S.banner.shade, "VERTICAL", CreateColor(C.panel[1], C.panel[2], C.panel[3], 0.95),
    CreateColor(C.panel[1], C.panel[2], C.panel[3], 0.05))
  S.banner.name = U.Text(S.banner, 24, "title", C.gold, "OUTLINE")
  S.banner.name:SetPoint("BOTTOMLEFT", 20, 12)
  S.banner.tag = U.Tag(S.banner, "Forever", C.frost)
  S.banner.tag:SetPoint("LEFT", S.banner.name, "RIGHT", 10, 0)
  S.banner.line = U.Line(S.banner, C.edge, 0.8)
  S.banner.line:SetPoint("BOTTOMLEFT") S.banner.line:SetPoint("BOTTOMRIGHT")
  S.banner:Hide()
  S.card = U.TextPanel(mid)
  S.card:SetPoint("TOPLEFT", 0, -48) S.card:SetPoint("BOTTOMRIGHT", 0, 52)
  S.card.bg:Hide()
  S.lootP = U.Blocks(mid)
  S.lootP:SetPoint("TOPLEFT", 0, -48) S.lootP:SetPoint("BOTTOMRIGHT", 0, 52)
  S.lootP.bg:Hide()
  S.lootP:Hide()
  local go = U.Button(mid, "Prowadź do wejścia", nil, 30, true)
  go:SetPoint("BOTTOMLEFT", 20, 14)
  go:SetScript("OnClick", function() if S.sel then U.dungeonGuide(S.sel) end end)
  S.goBtn = go
  local onmap = U.Button(mid, "Na mapie", nil, 30)
  onmap:SetPoint("LEFT", go, "RIGHT", 8, 0)
  onmap:SetScript("OnClick", function()
    local d = S.sel and U.dungeonGet(S.sel)
    local e2 = d and d.entrance
    if e2 and e2.map and U.mapGuide then U.mapGuide(e2.map, (e2.x or 0) / ((e2.x or 0) > 1 and 100 or 1), (e2.y or 0) / ((e2.y or 0) > 1 and 100 or 1), d.name)
    else U.say("nie znam wejścia do tego miejsca.") end
  end)
  local ev = U.Button(mid, "Wieczór z tym lochem", nil, 30)
  ev:SetPoint("LEFT", onmap, "RIGHT", 8, 0)
  ev:SetScript("OnClick", function() S.right, S.userRight = "wieczor", true U.wyprawyRefresh() end)
  -- 15.11: strona lochu w Polestarze (Polestar.Dungeons.Open: tylko otwiera jego okno)
  S.psBtn = U.Button(mid, "W Polestarze", nil, 30)
  S.psBtn:SetPoint("LEFT", ev, "RIGHT", 8, 0)
  S.psBtn:SetScript("OnClick", function()
    local D = _G.Polestar and _G.Polestar.Dungeons
    if not (S.sel and D and D.Open and pcall(D.Open, S.sel)) then U.say("Polestar nie otworzył tego lochu.") end
  end)
  S.psBtn:Hide()
  pcall(RequestRaidInfo)
end

-- dane przedmiotow (nazwa, jakosc) dochodza z serwera po chwili: strona Lupy odswiezona raz na 1 s
local itemEv = CreateFrame("Frame")
pcall(itemEv.RegisterEvent, itemEv, "GET_ITEM_INFO_RECEIVED")
itemEv:SetScript("OnEvent", function()
  if S.itemQ or S.cpage ~= "lupy" or not (S.mid and S.mid:IsVisible()) then return end
  S.itemQ = true
  C_Timer.After(1, function() S.itemQ = nil pcall(U.wyprawyRefresh) end)
end)

U.RegisterTab({
  id = "wyprawy", order = 6.5, title = "Wyprawy", keys = "",
  hints = { { { "LPM" }, "Wybierz loch" } },
  heavy = true,
  note = "Lochy, rajdy i wieczory ze znajomymi",
  build = build,
  refresh = function() pcall(RequestRaidInfo) C_Timer.After(0, function() pcall(U.wyprawyRefresh) end) end,
  leave = function() S.userRight = nil if S.form then for _, e in ipairs({ S.form.day, S.form.time, S.form.lead, S.form.avail, S.form.copy }) do e:ClearFocus() end end end,
})
