-- Grimuar UI: Wyprawy — dane i logika (14.11, R25 G1/G2/G4/G5/G6/G7/G10; gracz: „wszystkie punkty mozesz zrobic”).
-- Lochy i rajdy z Polestara (Polestar.Dungeons: lista z poziomami, wejscie, bossowie, questy; tylko odczyt), a bez niego
-- z planu Grimuara (G.DUNGEONS). Do tego:
-- G1 wspolny loch: czy wszyscy (Ty, grupa, wybrani znajomi online) dostana XP. Od 13.11 mob szary dla kogokolwiek
--    = 0 XP dla calej druzyny (R25 2.2). Szary poziom: 6–39: poz − ⌊poz/10⌋ − 5; 40+: poz − ⌊poz/5⌋ − 1.
-- G2 wejscia do lochow (limit 5 na godzine, konto) i blokady rajdowe (GetSavedInstanceInfo).
-- G4 postep znajomych (poziomy znajomych online z data, tylko lokalnie).
-- G5 kronika druzyny (loch, z kim, bossowie, czas, lupy) i G6 okienko po lochu (dodaj do znajomych z notatka, GG).
-- G7 ping: czy jest klawisz. G10 sklad rajdu (klasy, klatwy, magia, buffy, Drakefire Amulet).
local ADDON, U = ...
local C = U.C
local G = U.G or {}

local K = { sel = {} }
local RAIDS = {
  { key = "_barrow", name = "Barrow Deeps", minLevel = 60, maxLevel = 60, players = 10, raid = true, note = "8 bossów, od 9.12; wejście przez Blackmaw Hold (Azshara). Zasad łupów jeszcze nie ogłoszono." },
  { key = "_hyjal", name = "Hyjal Summit", minLevel = 60, maxLevel = 60, players = 20, raid = true, note = "13 bossów, od 9.12." },
  { key = "_ony", name = "Onyxia's Lair", minLevel = 60, maxLevel = 60, players = 40, raid = true, note = "Każdy potrzebuje Drakefire Amulet (attunement). Odporność na ogień." },
}
local DRAKEFIRE = 16309

local function db() return U.db() end
local function short(n) return n and (tostring(n):match("^[^-]+")) or n end
local function PD() local P = _G.Polestar return P and P.Dungeons end

-- ---------- lista lochow ----------
function U.dungeonList()
  if K.list then return K.list end
  local out = {}
  local D = PD()
  if D and D.List and U.call(D.Load) then
    for _, d in ipairs(U.call(D.List) or {}) do
      out[#out + 1] = { key = d.key, name = d.name, minLevel = d.minLevel, maxLevel = d.maxLevel, players = d.players,
        raid = d.kind == "raid", zoneName = d.zoneName, entrance = d.entrance, bosses = d.bosses, forever = d.forever,
        quests = d.quests and d.quests.A or 0, enemy = U.call(D.EnemyEntrance, d.key, "A"), src = "Polestar" }
    end
  end
  -- 14.11 (R26 P1): plan Grimuara (Core.lua DUNGEONS, zakresy Forever z WT) zawsze: opis i zakres do oceny XP
  -- dla lochow z Polestara (Polestar ma zakresy Classic Era), a nowe lochy Forever, ktorych Polestar nie zna, dochodza
  local function norm(s) return (tostring(s or ""):lower():gsub("^the ", ""):gsub("[^%a]", "")) end
  for _, g in ipairs(type(G.DUNGEONS) == "table" and G.DUNGEONS or {}) do
    local found
    for _, d in ipairs(out) do
      local a, b = norm(d.name), norm(g[3])
      if a == b or a:find(b, 1, true) or b:find(a, 1, true) then found = d break end
    end
    if found then
      found.note = found.note or g[4]
      if found.minLevel ~= g[1] or found.maxLevel ~= g[2] then found.pRange = (found.minLevel or "?") .. "–" .. (found.maxLevel or "?") end
      found.minLevel, found.maxLevel = g[1], g[2]
    else
      out[#out + 1] = { key = "_" .. g[3], name = g[3], minLevel = g[1], maxLevel = g[2], players = 5, note = g[4], src = "Grimuar" }
    end
  end
  local have = {}
  for _, d in ipairs(out) do have[d.name] = true end
  for _, r in ipairs(RAIDS) do if not have[r.name] then out[#out + 1] = r end end
  table.sort(out, function(a, b)
    if (a.raid and 1 or 0) ~= (b.raid and 1 or 0) then return not a.raid end
    return (a.minLevel or 0) < (b.minLevel or 0)
  end)
  K.list = #out > 0 and out or nil
  return out
end
function U.dungeonGet(key) for _, d in ipairs(U.dungeonList()) do if d.key == key then return d end end end
-- 15.11 (gracz: „dungi tez”, „lepiej zintegruj”): obraz lochu z Polestara (ekran ladowania z klienta, kwadratowe
-- kadrowanie l, r, t, b; Polestar.Dungeons.Art) i poziom „najlepiej na” (Polestar.Dungeons.BestAt). Tylko odczyt.
function U.dungeonArt(key)
  local D = PD()
  if not (D and D.Art) or not key or key:sub(1, 1) == "_" then return nil end
  local ok, a = pcall(D.Art, key)
  if not ok or type(a) ~= "table" or not U.num(a.file) then return nil end
  local l, r, t, b = U.num(a.l), U.num(a.r), U.num(a.t), U.num(a.b)
  if not (l and r and t and b and r > l and b > t) then return nil end
  return { file = a.file, l = l, r = r, t = t, b = b }
end
function U.dungeonBestAt(key)
  local D = PD()
  if not (D and D.BestAt) or not key or key:sub(1, 1) == "_" then return nil end
  return U.num(U.call(D.BestAt, key))
end
function U.dungeonBosses(key) local D = PD() return D and key and key:sub(1, 1) ~= "_" and U.call(D.Bosses, key) or {} end
function U.dungeonQuests(key) local D = PD() return D and key and key:sub(1, 1) ~= "_" and U.call(D.Quests, key, "A") or {} end
function U.dungeonGuide(key)
  local D = PD()
  if D and D.GuideTo and key:sub(1, 1) ~= "_" and U.call(D.GuideTo, key) then
    U.say("prowadzę do wejścia: " .. ((U.dungeonGet(key) or {}).name or key) .. ".")
    if U.IsOpen and U.IsOpen() then U.Close() end
    return true
  end
  U.say("nie znam wejścia do tego miejsca (Polestar wyłączony albo brak danych).")
end

-- ---------- G1: kto idzie i czy wszyscy dostana XP ----------
function U.grayLevel(l)
  l = tonumber(l) or 1
  if l <= 5 then return 0 end
  if l < 40 then return l - math.floor(l / 10) - 5 end
  return l - math.floor(l / 5) - 1
end

local function onlineFriends()
  local out = {}
  pcall(function()
    for i = 1, (C_FriendList.GetNumFriends() or 0) do
      local f = C_FriendList.GetFriendInfoByIndex(i)
      if f and f.connected and f.name then out[#out + 1] = { name = short(f.name), level = U.num(f.level), cls = f.className, area = f.area } end
    end
  end)
  pcall(function()
    for i = 1, (BNGetNumFriends() or 0) do
      local a = C_BattleNet.GetFriendAccountInfo(i)
      local g = a and a.gameAccountInfo
      if g and g.isOnline and g.characterName and U.num(g.characterLevel) then
        out[#out + 1] = { name = g.characterName, level = g.characterLevel, cls = g.className, area = g.areaName, bnet = a.bnetAccountID }
      end
    end
  end)
  return out
end
U.onlineFriends = onlineFriends

-- uczestnicy: Ty, drużyna, zaznaczeni znajomi online
function U.expeditionMembers()
  local out = { { name = UnitName("player"), level = UnitLevel("player"), me = true } }
  local seen = { [UnitName("player")] = true }
  local n = U.num(U.call(GetNumGroupMembers)) or 0
  local raid = U.call(IsInRaid)
  for i = 1, raid and n or math.max(0, n - 1) do
    local u = raid and ("raid" .. i) or ("party" .. i)
    local nm = short(U.call(UnitName, u))
    if nm and not seen[nm] then seen[nm] = true out[#out + 1] = { name = nm, level = U.num(U.call(UnitLevel, u)), unit = u } end
  end
  for _, f in ipairs(onlineFriends()) do
    if K.sel[f.name] and not seen[f.name] then seen[f.name] = true out[#out + 1] = { name = f.name, level = f.level, friend = true } end
  end
  return out
end
function U.expeditionToggle(name) K.sel[name] = not K.sel[name] or nil end
function U.expeditionSelected(name) return K.sel[name] == true end

-- ocena lochu dla uczestnikow: verdict "ok" | "czesc" | "szary" | "trudny", tekst
function U.dungeonFit(d, members)
  members = members or U.expeditionMembers()
  local lo, hi, hiName, loName = 99, 0, nil, nil
  for _, m in ipairs(members) do
    local l = m.level or 0
    if l > 0 and l < lo then lo, loName = l, m.name end
    if l > hi then hi, hiName = l, m.name end
  end
  if hi == 0 then return "ok", "" end
  local gray = U.grayLevel(hi)
  local dmin, dmax = d.minLevel or 1, d.maxLevel or 60
  if d.raid then
    if hi < 60 then return "trudny", "rajd na 60 poziom" end
    return "ok", d.players .. " osób"
  end
  if dmax <= gray then
    return "szary", "dla " .. (#members > 1 and hiName or "Ciebie") .. " wszystkie moby są szare (≤ " .. gray .. "): 0 XP dla wszystkich"
  end
  if dmin > lo + 4 then return "trudny", "za trudny dla " .. (loName or "?") .. " (" .. lo .. "), loch od " .. dmin end
  if dmin <= gray then
    return "czesc", "moby ≤ " .. gray .. " są szare dla " .. (hiName or "?") .. ": przy nich nikt nie dostanie XP (od 13.11)"
  end
  return "ok", "wszyscy dostaną XP" .. (#members > 1 and (" (poziomy " .. lo .. "–" .. hi .. ")") or "")
end

-- ---------- G2: wejscia i blokady ----------
local RESET_PAT
local function resetPat()
  if RESET_PAT ~= nil then return RESET_PAT end
  local f = _G.INSTANCE_RESET_SUCCESS
  RESET_PAT = type(f) == "string" and ("^" .. f:gsub("[%^%$%(%)%.%[%]%*%+%-%?]", "%%%0"):gsub("%%s", "(.+)") .. "$") or false
  return RESET_PAT
end
local function entries()
  local d = db()
  d.wejscia = d.wejscia or {}
  local now, keep = time(), {}
  for _, e in ipairs(d.wejscia) do if now - e[1] < 3600 then keep[#keep + 1] = e end end
  d.wejscia = keep
  return keep
end
function U.instanceEntries()
  local list = entries()
  local nextFree
  if #list >= 5 then nextFree = list[#list - 4][1] + 3600 end
  return #list, nextFree, list
end
function U.savedInstances()
  local out = {}
  pcall(function()
    for i = 1, (GetNumSavedInstances() or 0) do
      local name, _, reset, _, locked, _, _, isRaid, maxPlayers, diffName, nEnc, prog = GetSavedInstanceInfo(i)
      if name and locked then
        out[#out + 1] = { name = name, reset = U.num(reset), raid = isRaid, players = maxPlayers, diff = diffName, n = U.num(nEnc), prog = U.num(prog) }
      end
    end
  end)
  return out
end

-- ---------- G4: postep znajomych ----------
local function trackFriends()
  local d = db()
  d.znajomi = d.znajomi or {}
  local now = time()
  for _, f in ipairs(onlineFriends()) do
    if f.name and f.level then
      local z = d.znajomi[f.name] or { hist = {} }
      local last = z.hist[#z.hist]
      if not last or last[2] ~= f.level or now - last[1] > 86400 then
        z.hist[#z.hist + 1] = { now, f.level }
        while #z.hist > 30 do table.remove(z.hist, 1) end
      end
      z.cls, z.area, z.seen = f.cls, f.area, now
      d.znajomi[f.name] = z
    end
  end
end
-- „znajomeja: 24 → 27 w 7 dni · różnica z Tobą: 2” i rada (modele z R25 2.2)
function U.friendProgress(name)
  local z = (db().znajomi or {})[short(name)]
  if not z or #z.hist == 0 then return nil end
  local now, lvl = time(), z.hist[#z.hist][2]
  local from = z.hist[1]
  for _, h in ipairs(z.hist) do if now - h[1] <= 7 * 86400 then from = h break end end
  local days = math.max(1, math.floor((now - from[1]) / 86400 + 0.5))
  local me = UnitLevel("player") or 1
  local diff = me - lvl
  local tip
  if diff >= 5 then tip = "jesteś " .. diff .. " wyżej: solo tylko profesje, AH i zbieranie, wylogowanie w karczmie"
  elseif diff <= -5 then tip = "on jest " .. (-diff) .. " wyżej: nadrabiaj solo questami"
  else tip = "różnica do 4 poziomów: lochy z questami razem" end
  return (from[2] ~= lvl and (from[2] .. " → " .. lvl .. " w " .. days .. " " .. (days == 1 and "dzień" or "dni")) or ("poziom " .. lvl)) ..
    " · różnica z Tobą: " .. math.abs(diff), tip, z
end

-- ---------- G7: ping ----------
function U.pingKey()
  for _, b in ipairs({ "TOGGLEPINGLISTENER", "PING", "PINGATTACK", "PINGWARNING", "PINGONMYWAY", "PINGASSIST" }) do
    local k = U.call(GetBindingKey, b)
    if k then return k end
  end
  return nil
end

-- „przed lochem”: { { tekst, ok } }
function U.beforeDungeon(d)
  local out = {}
  -- 14.11 (R26 P1.4): jedna lista z GrimuarSetup Lochy.lua (woda, sprzet, torby, rozdzka, talenty, trener)
  local prep = G.dungeonPrep and U.call(G.dungeonPrep)
  if type(prep) == "table" then
    for _, p in ipairs(prep) do out[#out + 1] = { p.text .. (p.why and ("  " .. p.why) or ""), false } end
    if #prep == 0 then out[#out + 1] = { "Woda, sprzęt, torby, talenty i trener w porządku.", true } end
  end
  local pk = U.pingKey()
  out[#out + 1] = { pk and ("Ping pod klawiszem " .. pk) or "Ping bez klawisza: Opcje → Skróty → Ping (koło: Uwaga, Idę, Pomóż, Atak)", pk ~= nil }
  if d then
    local qs = U.dungeonQuests(d.key)
    if #qs > 0 then
      local inLog, done = 0, 0
      for _, q in ipairs(qs) do
        if U.call(C_QuestLog.IsQuestFlaggedCompleted, q.id) then done = done + 1
        elseif U.call(C_QuestLog.GetLogIndexForQuestID, q.id) then inLog = inLog + 1 end
      end
      out[#out + 1] = { "Zadania lochu: " .. inLog .. " w dzienniku, " .. done .. " zrobione z " .. #qs, inLog > 0 or done == #qs }
    end
  end
  return out
end

-- ---------- G10: sklad ----------
function U.raidComposition()
  local n = U.num(U.call(GetNumGroupMembers)) or 0
  local units = {}
  if U.call(IsInRaid) then for i = 1, n do units[#units + 1] = "raid" .. i end
  else units[1] = "player" for i = 1, math.max(0, n - 1) do units[#units + 1] = "party" .. i end end
  local cls, roles = {}, { TANK = 0, HEALER = 0, DAMAGER = 0, NONE = 0 }
  for _, u in ipairs(units) do
    local _, t = U.call(UnitClass, u)
    if t then cls[t] = (cls[t] or 0) + 1 end
    local r = U.call(UnitGroupRolesAssigned, u) or "NONE"
    roles[r] = (roles[r] or 0) + 1
  end
  local function has(...) for _, c in ipairs({ ... }) do if (cls[c] or 0) > 0 then return true end end return false end
  local lines = {}
  lines[#lines + 1] = { "Osób: " .. #units .. " · tanki " .. roles.TANK .. " · leczący " .. roles.HEALER .. (roles.NONE > 0 and (" · bez roli " .. roles.NONE) or ""), true }
  lines[#lines + 1] = { "Klątwy zdejmuje: " .. (has("MAGE", "DRUID") and "mag lub druid jest" or "nikt"), has("MAGE", "DRUID") }
  lines[#lines + 1] = { "Magię zdejmuje: " .. (has("PRIEST", "PALADIN") and "kapłan lub paladyn jest" or "nikt"), has("PRIEST", "PALADIN") }
  lines[#lines + 1] = { "Buffy: " .. table.concat({ has("MAGE") and "Intelekt ◆" or "Intelekt —", has("DRUID") and "Mark of the Wild ◆" or "Mark of the Wild —",
    has("PRIEST") and "Fortitude ◆" or "Fortitude —", has("PALADIN") and "Blessings ◆" or "Blessings —" }, " · "), true }
  local drake = (U.num(U.call(C_Item and C_Item.GetItemCount or GetItemCount, DRAKEFIRE, true)) or 0) > 0
  lines[#lines + 1] = { "Twój Drakefire Amulet (Onyxia): " .. (drake and "masz" or "brak (attunement, R12)"), drake }
  return lines, cls
end

-- ---------- G5 i G6: wyprawa i okienko po lochu ----------
local function charKey() return (G.charKey and U.call(G.charKey)) or (UnitName("player") or "?") end
local function runs()
  local d = db()
  d.wyprawy = d.wyprawy or {}
  local key = charKey()
  d.wyprawy[key] = d.wyprawy[key] or {}
  return d.wyprawy[key]
end
U.expeditionRuns = runs
local function groupNames()
  local out = {}
  for _, m in ipairs(U.expeditionMembers()) do if not m.me and not m.friend then out[#out + 1] = m.name end end
  return out
end

local PP
local function afterPopup(run)
  if InCombatLockdown() or #run.members == 0 or #run.bosses == 0 or db().noAfterRun then return end
  if not PP then
    PP = U.Panel(UIParent, 0.95, true, C.edge)
    PP:SetFrameStrata("MEDIUM")
    PP:SetSize(440, 200)
    PP:SetPoint("TOP", UIParent, "TOP", 0, -220)
    PP:EnableMouse(true)
    PP.h = U.H2(PP, "Po lochu")
    PP.h:SetPoint("TOPLEFT", 16, -14)
    PP.text = U.Para(PP, 13, 408, C.text)
    PP.text:SetPoint("TOPLEFT", PP.h, "BOTTOMLEFT", 0, -8)
    PP.rows = {}
    PP.gg = U.Button(PP, "GG na czat drużyny", nil, 28, true)
    PP.gg:SetPoint("BOTTOMLEFT", 16, 14)
    PP.close = U.Button(PP, "Zamknij", nil, 28)
    PP.close:SetPoint("LEFT", PP.gg, "RIGHT", 8, 0)
    PP.close:SetScript("OnClick", function() PP:Hide() end)
  end
  PP.text:SetText(run.name .. " · bossowie " .. #run.bosses .. " · " .. U.fmtMins(run.mins) .. (run.lootV and run.lootV > 0 and (" · łupy ok. " .. U.money(run.lootV)) or "")
    .. "\nKto był dobry? Klik dodaje do znajomych z notatką (albo dopisuje notatkę).")
  local y = -70
  for i, name in ipairs(run.members) do
    local r = PP.rows[i]
    if not r then
      r = U.Button(PP, "", 200, 26)
      PP.rows[i] = r
    end
    r:ClearAllPoints()
    r:SetPoint("TOPLEFT", PP, "TOPLEFT", 16, y - (i - 1) * 30)
    r:SetLabel("+ " .. name)
    r:SetScript("OnClick", function(self)
      local note = run.name .. " " .. date("%d.%m")
      local isFriend = false
      pcall(function() local f = C_FriendList.GetFriendInfo(name) isFriend = f ~= nil end)
      local ok
      if isFriend then ok = pcall(C_FriendList.SetFriendNotes, name, note) else ok = pcall(C_FriendList.AddFriend, name, note) end
      U.say(ok and (name .. ": " .. (isFriend and "notatka dopisana" or "dodany do znajomych") .. " („" .. note .. "”).") or "gra nie pozwoliła dodać.")
      self:SetLabel("◆ " .. name)
    end)
    r:Show()
  end
  for i = #run.members + 1, #PP.rows do PP.rows[i]:Hide() end
  PP.gg:SetScript("OnClick", function()
    if U.call(IsInGroup) then pcall(SendChatMessage, "GG, dzięki za " .. run.name .. "!", U.call(IsInRaid) and "RAID" or "PARTY") end
    PP.gg:SetLabel("Wysłane")
  end)
  PP:SetHeight(120 + #run.members * 30)
  PP:Show()
  C_Timer.After(90, function() if PP then PP:Hide() end end)
end

local function finishRun()
  local run = K.run
  K.run = nil
  if not run then return end
  run.mins = (time() - run.start) / 60
  if run.mins < 3 then return end
  local s = U.kronika and U.kronika()
  local cur = s and s.cur
  if cur and run.loot0 then run.lootV = math.max(0, (cur.lootV or 0) - run.loot0) end
  local list = runs()
  list[#list + 1] = { name = run.name, start = run.start, mins = math.floor(run.mins), members = run.members, bosses = run.bosses, lootV = run.lootV }
  while #list > 60 do table.remove(list, 1) end
  if cur then cur.runs = cur.runs or {} table.insert(cur.runs, list[#list]) end
  C_Timer.After(2, function() pcall(afterPopup, run) end)
end

local ev = CreateFrame("Frame")
for _, e in ipairs({ "PLAYER_LOGIN", "PLAYER_ENTERING_WORLD", "CHAT_MSG_SYSTEM", "ENCOUNTER_END", "GROUP_ROSTER_UPDATE",
  "FRIENDLIST_UPDATE", "BN_FRIEND_INFO_CHANGED", "UPDATE_INSTANCE_INFO" }) do pcall(ev.RegisterEvent, ev, e) end
ev:SetScript("OnEvent", function(_, event, a1, a2, a3, a4, a5)
  if event == "PLAYER_LOGIN" then
    C_Timer.After(20, function() pcall(trackFriends) end)
    C_Timer.After(10, function() pcall(RequestRaidInfo) end)
  elseif event == "PLAYER_ENTERING_WORLD" then
    C_Timer.After(2, function()
      local inInst, typ = U.call(IsInInstance)
      if inInst and (typ == "party" or typ == "raid") then
        local name = U.call(GetInstanceInfo)
        if type(name) == "string" then
          if K.lastInst ~= name or K.resetSince then
            local d = db()
            d.wejscia = d.wejscia or {}
            table.insert(d.wejscia, { time(), name })
            K.lastInst, K.resetSince = name, false
          end
          if not U.pingKey() and not db().pingHinted and (U.num(U.call(GetNumGroupMembers)) or 0) > 1 then
            db().pingHinted = true
            U.say("w lochu przyda się ping (koło: Uwaga, Idę, Pomóż, Atak): Opcje → Skróty → Ping. Lista: hub > Wyprawy > Przed lochem.")
          end
          if not K.run or K.run.name ~= name then
            local s = U.kronika and U.kronika()
            K.run = { name = name, start = time(), members = groupNames(), bosses = {}, loot0 = s and s.cur and s.cur.lootV or 0 }
          end
        end
      elseif K.run then
        pcall(finishRun)
      end
    end)
  elseif event == "CHAT_MSG_SYSTEM" then
    local p = resetPat()
    if p and type(a1) == "string" and not (issecretvalue and issecretvalue(a1)) and a1:match(p) then K.resetSince = true end
  elseif event == "ENCOUNTER_END" then
    if K.run and (a5 == 1 or a5 == true) then
      local nm = type(a2) == "string" and not (issecretvalue and issecretvalue(a2)) and a2 or "boss"
      table.insert(K.run.bosses, nm)
    end
  elseif event == "GROUP_ROSTER_UPDATE" then
    if K.run then
      local seen = {}
      for _, n in ipairs(K.run.members) do seen[n] = true end
      for _, n in ipairs(groupNames()) do if not seen[n] then table.insert(K.run.members, n) end end
    end
  elseif event == "FRIENDLIST_UPDATE" or event == "BN_FRIEND_INFO_CHANGED" then
    if not K.fq then K.fq = true C_Timer.After(5, function() K.fq = false pcall(trackFriends) end) end
  end
end)

-- ---------- lupy bossow (R26 2b: Polestar.Codex.Instance, tylko odczyt) ----------
-- -> { { name, items = { { id, name, quality } } } } albo nil; nazwy z klienta, a gdy jeszcze ich nie ma, z Codexu
function U.dungeonLoot(key)
  local P = _G.Polestar
  local Cx = P and P.Codex
  if not (Cx and Cx.Instance) or not key or key:sub(1, 1) == "_" then return nil end
  pcall(Cx.Load)
  local ok, inst = pcall(Cx.Instance, key)
  if not ok or type(inst) ~= "table" then return nil end
  local out = {}
  for _, b in ipairs(inst.bosses or {}) do
    local items = {}
    for _, id in ipairs(b.items or {}) do
      local name = U.call(C_Item and C_Item.GetItemNameByID, id)
      local q = U.num(U.call(C_Item and C_Item.GetItemQualityByID, id))
      if not name and Cx.Item then
        local r = U.call(Cx.Item, id)
        if type(r) == "table" then name = r.name or r[1] q = q or U.num(r.quality) end
      end
      if not name then pcall(C_Item.RequestLoadItemDataByID, id) end
      if (q or 2) >= 2 then items[#items + 1] = { id = id, name = name or ("przedmiot " .. id), quality = q } end
    end
    out[#out + 1] = { name = b.name or "?", role = b.role, items = items }
  end
  return out
end
