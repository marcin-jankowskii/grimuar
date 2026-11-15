-- Grimuar UI: zakladka Spolecznosc (makieta 14.11 „Hub · Spolecznosc”, krok D).
-- Lewo: znajomi (najpierw w grze, potem poza gra) z poziomem, klasa i strefa. Srodek: Twoja grupa i gildia (osoby w grze,
-- od najwyzszego poziomu). Prawo: szukanie grupy (okno gry) i lochy na Twoj poziom z planu Grimuara (Core.lua DUNGEONS).
-- Klikniecia tylko Twoje: LPM szepnij (hub sie zamyka, otwiera sie czat), PPM zaproszenie do grupy.
-- API jak ForeverSkin na 1.60.1 (Friends.lua, Guild.lua): C_FriendList, GetGuildRosterInfo, C_PartyInfo.InviteUnit.
local ADDON, U = ...
local G, C = U.G, U.C
local say = U.say

local S = { fRows = {}, gRows = {}, pRows = {}, dRows = {} }
local L_W, R_W, ROW_H = 440, 330, 42
local CLASS_PL = { WARRIOR = "Wojownik", PALADIN = "Paladyn", HUNTER = "Łowca", ROGUE = "Łotrzyk", PRIEST = "Kapłan",
  SHAMAN = "Szaman", MAGE = "Mag", WARLOCK = "Czarnoksiężnik", DRUID = "Druid", DEATHKNIGHT = "Rycerz śmierci", MONK = "Mnich" }
local PRIO = { [1] = "z zadaniami Przymierza", [2] = "daleko albo strefa sporna", [3] = "teren Hordy, tylko z grupą" }

local function str(v)
  if type(v) ~= "string" or v == "" then return nil end
  if issecretvalue and issecretvalue(v) then return nil end
  return v
end
local function token(className, classFile)
  local t = str(classFile)
  if t then return t end
  local n = str(className)
  if not n then return nil end
  for tok, loc in pairs(LOCALIZED_CLASS_NAMES_MALE or {}) do if loc == n then return tok end end
  for tok, loc in pairs(LOCALIZED_CLASS_NAMES_FEMALE or {}) do if loc == n then return tok end end
  return (n:upper():gsub("%s", ""))
end
local function classColor(tok)
  local c = tok and RAID_CLASS_COLORS and RAID_CLASS_COLORS[tok]
  if type(c) == "table" and c.r then return { c.r, c.g, c.b } end
  return C.text
end
local function classPl(tok, className) return (tok and CLASS_PL[tok]) or str(className) or "" end
local function short(name) return (tostring(name):match("^[^-]+")) or name end

-- ---------- dane ----------
local function readFriends()
  local list = {}
  local FL = C_FriendList
  if FL and FL.GetNumFriends and FL.GetFriendInfoByIndex then
    for i = 1, U.num(U.call(FL.GetNumFriends)) or 0 do
      pcall(function()
        local f = FL.GetFriendInfoByIndex(i)
        if type(f) == "table" and str(f.name) then
          local tok = token(f.className)
          list[#list + 1] = { name = f.name, level = U.num(f.level), tok = tok, cls = classPl(tok, f.className),
            area = str(f.area), online = f.connected == true, afk = f.afk == true, dnd = f.dnd == true, note = str(f.notes) }
        end
      end)
    end
  elseif GetNumFriends and GetFriendInfo then
    for i = 1, U.num(U.call(GetNumFriends)) or 0 do
      pcall(function()
        local name, level, className, area, connected, status, note = GetFriendInfo(i)
        if str(name) then
          local tok = token(className)
          list[#list + 1] = { name = name, level = U.num(level), tok = tok, cls = classPl(tok, className), area = str(area),
            online = connected and true or false, afk = status == "<AFK>", dnd = status == "<DND>", note = str(note) }
        end
      end)
    end
  end
  -- znajomi z Battle.net (jak okno znajomych ForeverSkin: BNGetNumFriends + C_BattleNet.GetFriendAccountInfo)
  local bn = (BNGetNumFriends and U.num(U.call(BNGetNumFriends))) or 0
  for i = 1, bn do
    pcall(function()
      local info = C_BattleNet and C_BattleNet.GetFriendAccountInfo and C_BattleNet.GetFriendAccountInfo(i)
      if type(info) ~= "table" then return end
      local game = type(info.gameAccountInfo) == "table" and info.gameAccountInfo or {}
      local online = game.isOnline == true
      local acc = str(info.accountName) or (str(info.battleTag) and (info.battleTag:gsub("#.*$", ""))) or "?"
      local char = online and game.clientProgram == "WoW" and str(game.characterName) or nil
      local same = char and (not WOW_PROJECT_ID or game.wowProjectID == WOW_PROJECT_ID)
      local tok = same and token(game.className, game.classFilename) or nil
      list[#list + 1] = { name = acc .. (char and (" (" .. char .. ")") or ""), bnet = true, account = acc, char = char,
        realm = str(game.realmName), gameID = U.num(game.gameAccountID), level = same and U.num(game.characterLevel) or nil,
        tok = tok, cls = same and classPl(tok, game.className) or (online and (str(game.richPresence) or "Battle.net") or ""),
        area = same and str(game.areaName) or nil, online = online, afk = info.isAFK == true or game.isGameAFK == true,
        dnd = info.isDND == true or game.isGameBusy == true, note = str(info.note) }
    end)
  end
  table.sort(list, function(a, b)
    if a.online ~= b.online then return a.online end
    return a.name < b.name
  end)
  return list
end

local function readGroup()
  local list = {}
  local n = U.num(U.call(GetNumGroupMembers)) or 0
  if n == 0 then return list, false end
  local raid = U.call(IsInRaid) and true or false
  local units = {}
  if raid then
    for i = 1, n do units[#units + 1] = "raid" .. i end
  else
    units[1] = "player"
    for i = 1, n - 1 do units[#units + 1] = "party" .. i end
  end
  for _, u in ipairs(units) do
    pcall(function()
      local name = str((UnitName(u)))
      if not name then return end
      local _, tok = UnitClass(u)
      tok = str(tok)
      list[#list + 1] = { name = name, level = U.num(UnitLevel(u)), tok = tok, cls = classPl(tok),
        online = UnitIsConnected(u) and true or false, leader = UnitIsGroupLeader(u) and true or false,
        me = UnitIsUnit(u, "player") and true or false, area = nil }
    end)
  end
  return list, raid
end

local function readGuild()
  if not U.call(IsInGuild) then return nil, 0 end
  local list = {}
  local n = U.num(U.call(GetNumGuildMembers)) or 0
  for i = 1, n do
    pcall(function()
      local name, rank, _, level, className, zone, note, _, online, _, classFile = GetGuildRosterInfo(i)
      if str(name) and online then
        local tok = token(className, classFile)
        list[#list + 1] = { name = name, rank = str(rank), level = U.num(level), tok = tok, cls = classPl(tok, className),
          area = str(zone), note = str(note), online = true, me = short(name) == UnitName("player") }
      end
    end)
  end
  table.sort(list, function(a, b)
    if (a.level or 0) ~= (b.level or 0) then return (a.level or 0) > (b.level or 0) end
    return a.name < b.name
  end)
  return list, n
end

-- prosba o swieze listy (serwer i tak ogranicza czestotliwosc)
local function request()
  if GetTime() - (S.asked or -99) < 15 then return end
  S.asked = GetTime()
  if C_FriendList and C_FriendList.ShowFriends then U.call(C_FriendList.ShowFriends) elseif ShowFriends then U.call(ShowFriends) end
  if U.call(IsInGuild) then
    if C_GuildInfo and C_GuildInfo.GuildRoster then U.call(C_GuildInfo.GuildRoster) elseif GuildRoster then U.call(GuildRoster) end
  end
end

-- ---------- akcje (tylko z Twojego klikniecia) ----------
local function whisper(d)
  local name = type(d) == "table" and d.name or d
  U.OpenGame(function()
    local util = ChatFrameUtil
    if type(d) == "table" and d.bnet then
      -- znajomy z Battle.net: szept po nazwie konta
      if type(util) == "table" and type(util.SendBNetTell) == "function" then util.SendBNetTell(d.account)
      elseif ChatFrame_SendBNetTell then ChatFrame_SendBNetTell(d.account)
      else ChatFrame_OpenChat("/w " .. d.account .. " ") end
      return
    end
    if type(util) == "table" and type(util.SendTell) == "function" then util.SendTell(name)
    elseif ChatFrame_SendTell then ChatFrame_SendTell(name)
    else ChatFrame_OpenChat("/w " .. name .. " ") end
  end)
end
local function invite(d)
  if not d.online then say(short(d.name) .. " jest poza grą.") return end
  if d.bnet then
    if not d.char then say(d.account .. " nie gra teraz w WoW.") return end
    local ok = false
    if d.gameID and BNInviteFriend then ok = pcall(BNInviteFriend, d.gameID) end
    if not ok and C_PartyInfo and C_PartyInfo.InviteUnit then
      ok = pcall(C_PartyInfo.InviteUnit, d.char .. (d.realm and ("-" .. d.realm:gsub("%s", "")) or ""))
    end
    say(ok and ("zaproszenie do grupy: " .. d.char .. ".") or "gra nie pozwoliła zaprosić.")
    return
  end
  local ok = false
  if C_PartyInfo and C_PartyInfo.InviteUnit then ok = pcall(C_PartyInfo.InviteUnit, d.name) end
  if not ok and InviteUnit then ok = pcall(InviteUnit, d.name) end
  say(ok and ("zaproszenie do grupy: " .. short(d.name) .. ".") or "gra nie pozwoliła zaprosić.")
end
local function groupFinder()
  if ToggleLFGParentFrame then return ToggleLFGParentFrame() end
  if LFGParentFrame then return ShowUIPanel(LFGParentFrame) end
  if PVEFrame_ToggleFrame then return PVEFrame_ToggleFrame() end
  error("brak okna szukania grupy")
end
local function addFriend()
  if StaticPopupDialogs and StaticPopupDialogs.ADD_FRIEND and StaticPopup_Show and pcall(StaticPopup_Show, "ADD_FRIEND") then return end
  U.OpenGame(function() ToggleFriendsFrame() end)
end

-- ---------- wiersze ----------
local function rowEnter(self)
  local d = self.d
  if not d then return end
  GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
  local c = d.online and classColor(d.tok) or C.faint
  GameTooltip:SetText(short(d.name), c[1], c[2], c[3])
  local line = (d.level and ("Poziom " .. d.level .. " ") or "") .. (d.cls or "")
  if line ~= "" then GameTooltip:AddLine(line, 1, 1, 1) end
  if d.rank then GameTooltip:AddLine("Ranga: " .. d.rank, 0.75, 0.75, 0.75) end
  if d.area then GameTooltip:AddLine(d.area, 0.75, 0.75, 0.75) end
  if d.note then GameTooltip:AddLine(d.note, C.muted[1], C.muted[2], C.muted[3], true) end
  if self.kind == "group" and not d.me and U.groupMemberTip then
    GameTooltip:AddLine(" ")
    pcall(U.groupMemberTip, GameTooltip, d.name)
  end
  -- 14.11 (R25 G8): stan znajomego z Grimuarem; (G4) postep znajomego
  if not d.me and U.peerTip then pcall(U.peerTip, GameTooltip, d.char or d.name) end
  if self.kind == "friend" and U.friendProgress then
    local okP, line, tip = pcall(U.friendProgress, d.char or d.name)
    if okP and line then
      GameTooltip:AddLine(" ")
      GameTooltip:AddLine("Postęp: " .. line, C.gold[1], C.gold[2], C.gold[3], true)
      if tip then GameTooltip:AddLine(tip, 0.8, 0.8, 0.8, true) end
    end
  end
  if not d.me then
    GameTooltip:AddLine(self.kind == "group" and "LPM: szepnij (zamyka hub) · PPM: prowadź do tej osoby" or "LPM: szepnij (zamyka hub) · PPM: zaproś",
      C.faint[1], C.faint[2], C.faint[3])
  end
  GameTooltip:Show()
end
local function rowClick(self, btn)
  local d = self.d
  if not d or d.me then return end
  if btn == "RightButton" then
    if self.kind ~= "group" then invite(d) elseif U.groupGuide then U.groupGuide(d.name) end
  else
    whisper(d)
  end
end
local function row(pool, parent, i)
  local r = pool[i]
  if r then return r end
  r = CreateFrame("Button", nil, parent)
  r:SetHeight(ROW_H)
  local hl = r:CreateTexture(nil, "HIGHLIGHT")
  hl:SetAllPoints()
  hl:SetColorTexture(1, 1, 1, 0.05)
  r.dot = r:CreateTexture(nil, "ARTWORK")
  r.dot:SetSize(3, ROW_H - 14)
  r.dot:SetPoint("LEFT", 0, 0)
  r.name = U.Text(r, 14, "body", C.text)
  r.name:SetPoint("TOPLEFT", 12, -5)
  r.sub = U.Text(r, 11, "body", C.muted)
  r.sub:SetPoint("TOPLEFT", r.name, "BOTTOMLEFT", 0, -4)
  r.lv = U.Text(r, 14, "body", C.text)
  r.lv:SetPoint("RIGHT", -10, 0)
  r.lv:SetJustifyH("RIGHT")
  r.lv:SetJustifyV("MIDDLE")
  r.tag = U.Tag(r, "")
  r.tag:SetPoint("RIGHT", r.lv, "LEFT", -10, 0)
  r:RegisterForClicks("LeftButtonUp", "RightButtonUp")
  r:SetScript("OnClick", rowClick)
  r:SetScript("OnEnter", rowEnter)
  r:SetScript("OnLeave", function() GameTooltip:Hide() end)
  pool[i] = r
  return r
end
local function fill(r, d, kind, width)
  r.d, r.kind = d, kind
  r:SetWidth(width)
  r.name:SetWidth(width - 130)
  r.sub:SetWidth(width - 130)
  r.name:SetText(short(d.name) .. (d.me and " (Ty)" or ""))
  U.Color(r.name, d.online and classColor(d.tok) or C.faint)
  local parts = {}
  if d.cls and d.cls ~= "" then parts[#parts + 1] = d.cls end
  if d.online then
    if d.area then parts[#parts + 1] = d.area end
  else
    parts[#parts + 1] = "poza grą"
  end
  r.sub:SetText(table.concat(parts, " · "))
  r.lv:SetText(d.level and tostring(d.level) or "")
  U.Color(r.lv, d.online and C.text or C.faint)
  local tag = (d.leader and "lider") or (d.afk and "AFK") or (d.dnd and "zajęty") or (kind == "guild" and d.rank) or nil
  r.tag:SetShown(tag ~= nil)
  if tag then r.tag:SetTag(tag, d.leader and C.gold or C.goldDim) end
  r.dot:SetColorTexture((d.online and C.ok or C.line)[1], (d.online and C.ok or C.line)[2], (d.online and C.ok or C.line)[3], 1)
end
local function head(pool, parent, i, text, y, width)
  local h = pool[i]
  if not h then
    h = CreateFrame("Frame", nil, parent)
    h:SetHeight(24)
    h.text = U.Text(h, 12, "title", C.goldDim)
    h.text:SetPoint("LEFT", 0, 0)
    h.text:SetJustifyV("MIDDLE")
    h.line = U.Line(h, C.line)
    h.line:SetPoint("LEFT", h.text, "RIGHT", 10, 0)
    h.line:SetPoint("RIGHT", 0, 0)
    pool[i] = h
  end
  h:SetWidth(width)
  h:ClearAllPoints()
  h:SetPoint("TOPLEFT", parent, "TOPLEFT", 0, -y)
  h.text:SetText(text)
  h:Show()
  return h
end

local function scroll(parent, step)
  local view = CreateFrame("ScrollFrame", nil, parent)
  local list = CreateFrame("Frame", nil, view)
  list:SetSize(300, 10)
  view:SetScrollChild(list)
  view:EnableMouseWheel(true)
  view:SetScript("OnMouseWheel", function(self, d)
    local max = math.max(0, list:GetHeight() - self:GetHeight())
    self:SetVerticalScroll(math.max(0, math.min(max, self:GetVerticalScroll() - d * (step or 84))))
  end)
  return view, list
end
local function fitScroll(view, list, h)
  list:SetHeight(math.max(10, h))
  local max = math.max(0, h - view:GetHeight())
  if view:GetVerticalScroll() > max then view:SetVerticalScroll(max) end
end

-- ---------- rysowanie ----------
local function drawFriends()
  local list = readFriends()
  local w = math.max(200, S.fView:GetWidth() or (L_W - 32))
  S.fList:SetWidth(w)
  local on = 0
  for _, d in ipairs(list) do if d.online then on = on + 1 end end
  S.fCount:SetText(on .. " w grze · " .. #list .. " razem")
  S.fHeads = S.fHeads or {}
  local y, n, hn, offHead = 0, 0, 0, false
  for _, d in ipairs(list) do
    if not d.online and not offHead then
      offHead = true
      hn = hn + 1
      head(S.fHeads, S.fList, hn, "Poza grą", y + 4, w)
      y = y + 32
    end
    n = n + 1
    local r = row(S.fRows, S.fList, n)
    fill(r, d, "friend", w)
    r:ClearAllPoints()
    r:SetPoint("TOPLEFT", S.fList, "TOPLEFT", 0, -y)
    r:Show()
    y = y + ROW_H + 2
  end
  for i = n + 1, #S.fRows do S.fRows[i]:Hide() end
  for i = hn + 1, #S.fHeads do S.fHeads[i]:Hide() end
  fitScroll(S.fView, S.fList, y)
  S.fEmpty:SetShown(#list == 0)
end

local function drawGroup()
  local list, raid = readGroup()
  local w = math.max(200, S.mid:GetWidth() - 36)
  local show = math.min(#list, 5)
  if #list == 0 then
    S.pState:SetText("tylko Ty")
  else
    local st = raid and ("rajd: " .. #list .. " osób") or (#list .. " " .. (#list < 5 and "osoby" or "osób"))
    local sum = U.groupQuestSummary and U.call(U.groupQuestSummary)
    if sum then
      st = st .. " · do udostępnienia " .. #sum.share .. " · wspólne zadania " .. sum.common
      if #sum.theirs > 0 then st = st .. " · oni mają, Ty nie: " .. #sum.theirs end
    end
    S.pState:SetText(st)
  end
  if S.pAct then pcall(S.pAct.Refresh, S.pAct) end
  local top = S.pAct or S.pH
  for i = 1, show do
    local r = row(S.pRows, S.mid, i)
    fill(r, list[i], "group", w)
    r:ClearAllPoints()
    r:SetPoint("TOPLEFT", top, "BOTTOMLEFT", 0, -8 - (i - 1) * (ROW_H + 2))
    r:Show()
  end
  for i = show + 1, #S.pRows do S.pRows[i]:Hide() end
  S.pEmpty:SetShown(#list == 0)
  S.pMore:SetShown(#list > show)
  S.pMore:SetText("i jeszcze " .. (#list - show) .. " (okno gry)")
  -- gildia pod grupa
  local rows = math.max(1, show)
  S.gH:ClearAllPoints()
  S.gH:SetPoint("TOPLEFT", top, "BOTTOMLEFT", 0, -22 - rows * (ROW_H + 2) - (#list > show and 18 or 0))
  S.pMore:ClearAllPoints()
  S.pMore:SetPoint("TOPLEFT", top, "BOTTOMLEFT", 0, -12 - show * (ROW_H + 2))
end

local function drawGuild()
  local list, total = readGuild()
  local w = math.max(200, S.gView:GetWidth() or 300)
  S.gList:SetWidth(w)
  if not list then
    S.gCount:SetText("")
    S.gEmpty:SetText("Nie należysz do gildii. Gildia daje wspólny bank, grupę na lochy i rajdy od 60. Zaproszenie dostaniesz na czacie albo od znajomego.")
    S.gEmpty:Show()
    for _, r in ipairs(S.gRows) do r:Hide() end
    fitScroll(S.gView, S.gList, 10)
    return
  end
  S.gCount:SetText(#list .. " w grze z " .. total)
  S.gEmpty:SetText("Nikt z gildii nie jest teraz w grze.")
  S.gEmpty:SetShown(#list == 0)
  local y = 0
  for i, d in ipairs(list) do
    local r = row(S.gRows, S.gList, i)
    fill(r, d, "guild", w)
    r:ClearAllPoints()
    r:SetPoint("TOPLEFT", S.gList, "TOPLEFT", 0, -y)
    r:Show()
    y = y + ROW_H + 2
  end
  for i = #list + 1, #S.gRows do S.gRows[i]:Hide() end
  fitScroll(S.gView, S.gList, y)
end

local function dungeonRow(i)
  local r = S.dRows[i]
  if r then return r end
  r = CreateFrame("Frame", nil, S.right)
  r:SetSize(R_W - 36, 40)
  r:EnableMouse(true)
  r.name = U.Text(r, 14, "body", C.text)
  r.name:SetPoint("TOPLEFT", 0, -3)
  r.sub = U.Text(r, 11, "body", C.muted)
  r.sub:SetPoint("TOPLEFT", r.name, "BOTTOMLEFT", 0, -4)
  r.sub:SetWidth(R_W - 36)
  r.tag = U.Tag(r, "")
  r.tag:SetPoint("TOPRIGHT", 0, -2)
  r:SetScript("OnEnter", function(self)
    if not self.d then return end
    GameTooltip:SetOwner(self, "ANCHOR_LEFT")
    GameTooltip:SetText(self.d[3], C.gold[1], C.gold[2], C.gold[3])
    GameTooltip:AddLine("Poziom " .. self.d[1] .. "–" .. self.d[2], 1, 1, 1)
    if self.d[4] then GameTooltip:AddLine(self.d[4], 0.8, 0.8, 0.8, true) end
    GameTooltip:Show()
  end)
  r:SetScript("OnLeave", function() GameTooltip:Hide() end)
  S.dRows[i] = r
  return r
end
local function drawDungeons()
  -- 14.11 (R26 P2): lochy sa w zakladce Wyprawy; tu tylko skrot (bez drugiej listy)
  if S.wyprawyBtn then
    for _, r in ipairs(S.dRows) do r:Hide() end
    S.dEmpty:Hide()
    S.tip:ClearAllPoints()
    S.tip:SetPoint("TOPLEFT", S.wyprawyBtn, "BOTTOMLEFT", 0, -16)
    return
  end
  local l = UnitLevel("player") or 1
  local best = U.call(G.bestDungeon, l)
  local list = {}
  for _, d in ipairs(type(G.DUNGEONS) == "table" and G.DUNGEONS or {}) do
    if d[1] <= l + 4 and d[2] >= l then list[#list + 1] = d end
  end
  table.sort(list, function(a, b) return a[1] < b[1] end)
  if #list == 0 then
    for _, d in ipairs(type(G.DUNGEONS) == "table" and G.DUNGEONS or {}) do
      if d[1] > l and (not list[1] or d[1] < list[1][1]) then list[1] = d end
    end
  end
  local n = 0
  for _, d in ipairs(list) do
    if n >= 4 then break end
    n = n + 1
    local r = dungeonRow(n)
    r.d = d
    r:ClearAllPoints()
    r:SetPoint("TOPLEFT", S.dL, "BOTTOMLEFT", 0, -8 - (n - 1) * 44)
    r.name:SetText(d[3])
    U.Color(r.name, d[1] <= l and C.text or C.muted)
    r.sub:SetText("od " .. d[1] .. " do " .. d[2] .. " · " .. (PRIO[d[5] or 2] or ""))
    r.tag:SetShown(best == d or d[1] > l)
    if best == d then r.tag:SetTag("polecany", C.gold) elseif d[1] > l then r.tag:SetTag("od " .. d[1], C.faint) end
    r:Show()
  end
  for i = n + 1, #S.dRows do S.dRows[i]:Hide() end
  S.dEmpty:SetShown(n == 0)
  S.tip:ClearAllPoints()
  S.tip:SetPoint("TOPLEFT", S.dL, "BOTTOMLEFT", 0, -16 - math.max(1, n) * 44)
end

local function refresh()
  if not S.page then return end
  request()
  pcall(drawFriends)
  pcall(drawGroup)
  pcall(drawGuild)
  pcall(drawDungeons)
end

-- ---------- uklad ----------
local function build(page)
  S.page = page
  -- lewo: znajomi
  local L = U.Panel(page, 0.86, true)
  L:SetPoint("TOPLEFT") L:SetPoint("BOTTOMLEFT") L:SetWidth(L_W)
  local h = U.H2(L, "Znajomi")
  h:SetPoint("TOPLEFT", 18, -16)
  S.fCount = U.Text(L, 12, "body", C.muted)
  S.fCount:SetPoint("TOPRIGHT", L, "TOPRIGHT", -18, -18)
  S.fCount:SetJustifyH("RIGHT")
  local add = U.Button(L, "Dodaj znajomego", nil, 30)
  add:SetPoint("BOTTOMLEFT", L, "BOTTOMLEFT", 18, 16)
  add:SetScript("OnClick", addFriend)
  S.fView, S.fList = scroll(L)
  S.fView:SetPoint("TOPLEFT", h, "BOTTOMLEFT", 0, -12)
  S.fView:SetPoint("BOTTOMRIGHT", L, "BOTTOMRIGHT", -14, 58)
  S.fEmpty = U.Para(L, 13, L_W - 36, C.faint)
  S.fEmpty:SetPoint("TOPLEFT", h, "BOTTOMLEFT", 0, -14)
  S.fEmpty:SetText("Nie masz jeszcze znajomych. Dodaj kogoś, z kim grasz: zobaczysz tu jego poziom i strefę.")

  -- prawo: szukanie grupy i lochy
  local R = U.Panel(page, 0.86, true)
  R:SetPoint("TOPRIGHT") R:SetPoint("BOTTOMRIGHT") R:SetWidth(R_W)
  S.right = R
  local w = R_W - 36
  local sh = U.H2(R, "Szukaj grupy")
  sh:SetPoint("TOPLEFT", 18, -16)
  local role = U.Para(R, 13, w, C.text)
  role:SetPoint("TOPLEFT", sh, "BOTTOMLEFT", 0, -8)
  local _, myClass = UnitClass("player")
  local rl = U.G and U.G.BD_META and U.G.BD_META.role
  role:SetText(myClass == "MAGE" and "Rola: obrażenia. Mag nie leczy i nie tankuje, w grupie dajesz wodę i owcę (Polymorph)."
    or (rl == "TANK" and "Rola: tank (według buildu). Wybierz ją też w oknie szukania grupy.")
    or (rl == "HEALER" and "Rola: leczenie (według buildu). Wybierz ją też w oknie szukania grupy.")
    or (rl == "DAMAGER" and "Rola: obrażenia (według buildu). Wybierz ją też w oknie szukania grupy.")
    or "Wybierz rolę w oknie szukania grupy.")
  local find = U.Button(R, "Szukaj grupy (gra)", w, 30, true)
  find:SetPoint("TOPLEFT", role, "BOTTOMLEFT", 0, -12)
  find:SetScript("OnClick", function() U.OpenGame(groupFinder) end)
  local social = U.Button(R, "Znajomi i gildia (gra)", w, 30)
  social:SetPoint("TOPLEFT", find, "BOTTOMLEFT", 0, -8)
  social:SetScript("OnClick", function() U.OpenGame(function() ToggleFriendsFrame() end) end)
  S.dL = U.Label(R, "Lochy na Twój poziom")
  S.dL:SetPoint("TOPLEFT", social, "BOTTOMLEFT", 0, -20)
  S.wyprawyBtn = U.Button(R, "Lochy, rajdy i wieczory: Wyprawy", w, 30)
  S.wyprawyBtn:SetPoint("TOPLEFT", S.dL, "BOTTOMLEFT", 0, -8)
  S.wyprawyBtn:SetScript("OnClick", function() U.Select("wyprawy") end)
  S.dEmpty = U.Text(R, 12, "body", C.faint)
  S.dEmpty:SetPoint("TOPLEFT", S.dL, "BOTTOMLEFT", 0, -8)
  S.dEmpty:SetText("Plan Grimuara nie ma lochu na ten poziom.")
  S.tip = U.Para(R, 12, w, C.faint)
  S.tip:SetPoint("TOPLEFT", S.dL, "BOTTOMLEFT", 0, -60)
  S.tip:SetText("Serwer PvP: poza miastami Horda może zaatakować, w grupie bezpieczniej. Grupy szukasz też na czacie strefy (/1).")

  -- srodek: grupa i gildia
  local M = U.Panel(page, 0.86, true)
  M:SetPoint("TOPLEFT", L, "TOPRIGHT", 20, 0)
  M:SetPoint("BOTTOMRIGHT", R, "BOTTOMLEFT", -20, 0)
  S.mid = M
  S.pH = U.H2(M, "Grupa")
  S.pH:SetPoint("TOPLEFT", 18, -16)
  S.pState = U.Text(M, 12, "body", C.muted)
  S.pState:SetPoint("LEFT", S.pH, "RIGHT", 10, -1)
  -- 14.11 (gracz: „share questów i inne tego typu rzeczy, żeby były łatwe”): GrupaLatwo.lua
  if U.groupActionsBuild then
    local ok, act = pcall(U.groupActionsBuild, M)
    if ok and act then
      S.pAct = act
      act:SetPoint("TOPLEFT", S.pH, "BOTTOMLEFT", 0, -12)
    end
  end
  S.pEmpty = U.Text(M, 13, "body", C.faint)
  S.pEmpty:SetPoint("TOPLEFT", S.pAct or S.pH, "BOTTOMLEFT", 0, -14)
  S.pEmpty:SetText("Grasz sam. PPM na znajomym albo osobie z gildii zaprasza do grupy.")
  S.pMore = U.Text(M, 12, "body", C.faint)
  S.pMore:SetPoint("TOPLEFT", S.pH, "BOTTOMLEFT", 0, -12 - 5 * (ROW_H + 2))
  S.gH = U.H2(M, "Gildia")
  S.gH:SetPoint("TOPLEFT", S.pH, "BOTTOMLEFT", 0, -22 - (ROW_H + 2))
  S.gCount = U.Text(M, 12, "body", C.muted)
  S.gCount:SetPoint("LEFT", S.gH, "RIGHT", 10, -1)
  S.gView, S.gList = scroll(M)
  S.gView:SetPoint("TOPLEFT", S.gH, "BOTTOMLEFT", 0, -10)
  S.gView:SetPoint("BOTTOMRIGHT", M, "BOTTOMRIGHT", -14, 14)
  S.gEmpty = U.Para(M, 13, 420, C.faint)
  S.gEmpty:SetPoint("TOPLEFT", S.gH, "BOTTOMLEFT", 0, -12)
end

-- ---------- zdarzenia (tylko przy otwartej zakladce) ----------
local ev = CreateFrame("Frame")
local EVENTS = { "QUEST_LOG_UPDATE", "BN_FRIEND_INFO_CHANGED", "BN_FRIEND_ACCOUNT_ONLINE", "BN_FRIEND_ACCOUNT_OFFLINE", "BN_FRIEND_LIST_SIZE_CHANGED", "FRIENDLIST_UPDATE", "GROUP_ROSTER_UPDATE", "GUILD_ROSTER_UPDATE", "PLAYER_GUILD_UPDATE", "PLAYER_LEVEL_UP",
  "PARTY_LEADER_CHANGED" }
ev:SetScript("OnEvent", function()
  if S.pending then return end
  S.pending = true
  C_Timer.After(0.5, function()
    S.pending = false
    if S.page and S.page:IsVisible() then
      pcall(drawFriends)
      pcall(drawGroup)
      pcall(drawGuild)
      pcall(drawDungeons)
    end
  end)
end)

U.RegisterTab({
  id = "spolecznosc", order = 6, title = "Społeczność", keys = "O",
  hints = { { { "LPM" }, "Szepnij" }, { { "PPM" }, "Zaproś / prowadź do osoby z grupy" } },
  note = "Szept zamyka hub i otwiera czat",
  build = build,
  refresh = function()
    for _, e in ipairs(EVENTS) do pcall(ev.RegisterEvent, ev, e) end
    refresh()
    C_Timer.After(0, function() if S.page and S.page:IsVisible() then refresh() end end)
  end,
  leave = function() ev:UnregisterAllEvents() end,
})
