-- Grimuar UI: Wyprawy — wieczor i druzyna (14.11, R25 G3/G8/G9).
-- G3 karta wieczoru: loch, dzien i godzina, zbiorka (wejscie z Polestara), prowadzacy. Gotowy tekst PL i EN do
--    skopiowania na Discord, szept do zaznaczonych znajomych i na czat druzyny (tylko po kliknieciu), przypomnienie
--    15 min wczesniej, prowadzenie na zbiorke. Stan: GrimuarUIDB.wieczor.
-- G8 Grimuar<->Grimuar: gdy znajomi tez maja GrimuarUI, w grupie addony wymieniaja stan (poziom, XP, strefa, woda,
--    sprzet, torby, Drakefire, „moge dzis”). Prefiks GRIMUAR, wiadomosci addonu (C_ChatInfo.SendAddonMessage), separator
--    „;”. W walce i przy blokadzie czatu (spotkanie z bossem) kolejka do konca walki. Konta probne nie wysylaja.
-- G9 termin z potwierdzeniem: karta wieczoru wyslana do grupy i zaznaczonych znajomych (szept addonu); u nich okienko
--    Bede / Moze / Nie, odpowiedz wraca do Ciebie (Wyprawy i Kronika: „4/5 potwierdzonych”).
local ADDON, U = ...
local C = U.C
local G = U.G or {}

local PREFIX, VER = "GRIMUAR", 1
local DRAKEFIRE = 16309
local K = { peers = {}, queue = {}, sent = 0 }

local function db() return U.db() end
local function short(n) return n and (tostring(n):match("^[^-]+")) or n end
local function clean(s) return (tostring(s or ""):gsub("[;|]", " ")) end

-- ---------- G3: wieczor ----------
function U.eveningGet() return db().wieczor end
function U.eveningSet(key, dayText, timeText, leader)
  local d = U.dungeonGet and U.dungeonGet(key)
  if not d then U.say("wybierz loch z listy.") return nil end
  local now = date("*t")
  local dd, mm = (dayText or ""):match("(%d+)%.(%d+)")
  local hh, mi = (timeText or ""):match("(%d+):(%d+)")
  local t = time({ year = now.year, month = tonumber(mm) or now.month, day = tonumber(dd) or now.day, hour = tonumber(hh) or 20, min = tonumber(mi) or 0 })
  if t < time() - 3600 and not mm then t = t + 86400 end
  local plan = { id = tostring(time()) .. math.random(100, 999), key = key, name = d.name, epoch = t,
    place = d.zoneName and ("wejście, " .. d.zoneName) or "przy wejściu", zoneName = d.zoneName,
    leader = leader ~= "" and leader or UnitName("player"), lmin = d.minLevel, lmax = d.maxLevel, answers = {}, mine = true }
  db().wieczor = plan
  U.say("wieczór zapisany: " .. d.name .. ", " .. U.fmtDate(t) .. ". Przypomnę 15 min wcześniej.")
  return plan
end
function U.eveningText(p, lang)
  p = p or db().wieczor
  if not p then return "" end
  local when = U.fmtDate(p.epoch)
  local lv = (p.lmin and p.lmax) and (" (" .. p.lmin .. "–" .. p.lmax .. ")") or ""
  if lang == "en" then
    return "Grimuar night: " .. p.name .. lv .. " · " .. date("%a %d.%m %H:%M", p.epoch) .. " · meet: " .. (p.zoneName or "entrance") ..
      " · lead: " .. p.leader .. ". Bring water, repair gear, take the dungeon quests. Who's in?"
  end
  return "Wieczór Grimuara: " .. p.name .. lv .. " · " .. when .. " · zbiórka: " .. p.place .. " · prowadzi: " .. p.leader ..
    ". Weźcie wodę, naprawcie sprzęt i weźcie questy do lochu. Kto jest?"
end
function U.eveningWhisper(names)
  local p = db().wieczor
  if not p then U.say("najpierw zapisz wieczór.") return end
  local txt, n = U.eveningText(p), 0
  for _, f in ipairs(U.onlineFriends and U.onlineFriends() or {}) do
    if names[f.name] then
      local ok
      if f.bnet and BNSendWhisper then ok = pcall(BNSendWhisper, f.bnet, txt) else ok = pcall(SendChatMessage, txt, "WHISPER", nil, f.name) end
      if ok then n = n + 1 end
    end
  end
  U.say(n > 0 and ("wysłałem kartę wieczoru do " .. n .. " " .. (n == 1 and "osoby" or "osób") .. ".") or "zaznacz znajomych online.")
  if U.planSend then pcall(U.planSend, names) end
end
function U.eveningParty()
  local p = db().wieczor
  if not p then U.say("najpierw zapisz wieczór.") return end
  if not U.call(IsInGroup) then U.say("nie jesteś w grupie.") return end
  pcall(SendChatMessage, U.eveningText(p), U.call(IsInRaid) and "RAID" or "PARTY")
  if U.planSend then pcall(U.planSend, {}) end
end
function U.eveningGuide()
  local p = db().wieczor
  if p and U.dungeonGuide then U.dungeonGuide(p.key) else U.say("najpierw zapisz wieczór.") end
end

-- ---------- G8: wiadomosci addonu ----------
local function lockdown()
  if InCombatLockdown() then return true end
  local ok, l = pcall(function() return C_ChatInfo.InChatMessagingLockdown and C_ChatInfo.InChatMessagingLockdown() end)
  return ok and l and true or false
end
local function rawSend(msg, chan, target)
  if not (C_ChatInfo and C_ChatInfo.SendAddonMessage) then return false end
  local ok, res = pcall(C_ChatInfo.SendAddonMessage, PREFIX, msg:sub(1, 250), chan, target)
  return ok and (res == nil or res == true or res == 0 or (Enum and Enum.SendAddonMessageResult and res == Enum.SendAddonMessageResult.Success))
end
local function send(msg, chan, target)
  if lockdown() then K.queue[#K.queue + 1] = { msg, chan, target } return end
  rawSend(msg, chan, target)
end
local function flush()
  if lockdown() then return end
  local q = K.queue
  K.queue = {}
  for i, m in ipairs(q) do C_Timer.After(i * 0.3, function() rawSend(m[1], m[2], m[3]) end) end
end
local function groupChan()
  if U.call(IsInRaid) then return "RAID" end
  if U.call(IsInGroup) then return "PARTY" end
  return nil
end

local function myStatus()
  local lvl = UnitLevel("player") or 0
  local xp, mx = U.num(UnitXP("player")), U.num(UnitXPMax("player"))
  local pct = (xp and mx and mx > 0) and math.floor(xp / mx * 100) or 0
  local w = U.num(G.waterCount and U.call(G.waterCount)) or -1
  local dura = U.num(G.minDurability and U.call(G.minDurability)) or -1
  if dura >= 0 then dura = math.floor(dura) end -- GrimuarSetup Engine.lua: procent 0–100
  local bags = U.num(G.freeBagSlots and U.call(G.freeBagSlots)) or -1
  local drake = (U.num(U.call(C_Item and C_Item.GetItemCount or GetItemCount, DRAKEFIRE, true)) or 0) > 0 and 1 or 0
  local inst = ""
  local inInst = U.call(IsInInstance)
  if inInst then inst = clean(U.call(GetInstanceInfo)) end
  return table.concat({ "S", VER, lvl, pct, clean(GetRealZoneText()), inst, w, dura, bags, drake, clean(db().mogeDzis or "") }, ";")
end
function U.statusSend(target)
  local chan = groupChan()
  if target then send(myStatus(), "WHISPER", target)
  elseif chan then send(myStatus(), chan) end
end
function U.peers() return K.peers end
function U.peerTip(tt, name)
  local p = K.peers[short(name)]
  if not p then return end
  tt:AddLine(" ")
  tt:AddLine("Grimuar " .. (p.ver or "?") .. ": poziom " .. p.lvl .. " (" .. p.xp .. "%) · " .. (p.zone or "?"), C.gold[1], C.gold[2], C.gold[3])
  local parts = {}
  if p.water >= 0 then parts[#parts + 1] = "woda " .. p.water end
  if p.dura >= 0 then parts[#parts + 1] = "sprzęt " .. p.dura .. "%" end
  if p.bags >= 0 then parts[#parts + 1] = "torby " .. p.bags end
  if p.drake == 1 then parts[#parts + 1] = "Drakefire ◆" end
  if #parts > 0 then tt:AddLine(table.concat(parts, " · "), 1, 1, 1) end
  if p.avail and p.avail ~= "" then tt:AddLine("Może dziś: " .. p.avail, 0.8, 0.8, 0.8) end
end

-- ---------- G9: termin z potwierdzeniem ----------
function U.planSend(names)
  local p = db().wieczor
  if not p then return end
  local msg = table.concat({ "P", p.id, clean(p.name), p.epoch, clean(p.place), clean(p.leader), clean(p.zoneName or "") }, ";")
  local chan = groupChan()
  if chan then send(msg, chan) end
  for _, f in ipairs(U.onlineFriends and U.onlineFriends() or {}) do
    if names and names[f.name] and not f.bnet then send(msg, "WHISPER", f.name) end
  end
end
function U.planAnswers()
  local p = db().wieczor
  if not p then return 0, 0, {} end
  local yes, n = 0, 0
  for _, a in pairs(p.answers or {}) do n = n + 1 if a == "tak" then yes = yes + 1 end end
  return yes, n, p.answers or {}
end

local INV
local function invitePopup(from, p)
  if not INV then
    INV = U.Panel(UIParent, 0.95, true, C.gold)
    INV:SetFrameStrata("DIALOG")
    INV:SetSize(440, 150)
    INV:SetPoint("TOP", UIParent, "TOP", 0, -260)
    INV:EnableMouse(true)
    INV.h = U.H2(INV, "Zaproszenie na wyprawę")
    INV.h:SetPoint("TOPLEFT", 16, -14)
    INV.text = U.Para(INV, 13, 408, C.text)
    INV.text:SetPoint("TOPLEFT", INV.h, "BOTTOMLEFT", 0, -8)
    INV.b = {}
    local prev
    for i, a in ipairs({ { "tak", "Będę" }, { "moze", "Może" }, { "nie", "Nie" } }) do
      local b = U.Button(INV, a[2], 100, 28, i == 1)
      if prev then b:SetPoint("LEFT", prev, "RIGHT", 8, 0) else b:SetPoint("BOTTOMLEFT", 16, 14) end
      b.ans = a[1]
      INV.b[i] = b
      prev = b
    end
  end
  INV.text:SetText(from .. " zaprasza: " .. p.name .. " · " .. U.fmtDate(p.epoch) .. "\nZbiórka: " .. p.place .. " · prowadzi: " .. p.leader)
  for _, b in ipairs(INV.b) do
    b:SetScript("OnClick", function()
      send(table.concat({ "R", p.id, b.ans }, ";"), "WHISPER", from)
      local d = db()
      p.mine = false
      p.myAnswer = b.ans
      if b.ans ~= "nie" then d.wieczor = p end
      U.say("odpowiedź wysłana: " .. b.ans .. ".")
      INV:Hide()
    end)
  end
  INV:Show()
end

local function onMessage(text, chan, sender)
  local who = short(sender)
  if not who or who == UnitName("player") or type(text) ~= "string" then return end
  local f = { strsplit(";", text) }
  if f[1] == "S" then
    local old = K.peers[who]
    K.peers[who] = { ver = tonumber(f[2]), lvl = tonumber(f[3]) or 0, xp = tonumber(f[4]) or 0, zone = f[5], inst = f[6],
      water = tonumber(f[7]) or -1, dura = tonumber(f[8]) or -1, bags = tonumber(f[9]) or -1, drake = tonumber(f[10]) or 0,
      avail = f[11], at = time() }
    if not old then U.statusSend(who) end -- przywitanie: odeslij swoj stan
    local p = db().wieczor
    if p and p.zoneName and f[5] == p.zoneName and (not old or old.zone ~= f[5]) and math.abs(p.epoch - time()) < 3 * 3600 then
      if G.showToast then pcall(G.showToast, who .. " jest już w strefie lochu (" .. p.zoneName .. ")", "dng", false) end
    end
    if U.wyprawyRefresh then pcall(U.wyprawyRefresh) end
  elseif f[1] == "P" then
    local p = { id = f[2], name = f[3], epoch = tonumber(f[4]) or time(), place = f[5], leader = f[6], zoneName = f[7] ~= "" and f[7] or nil, answers = {} }
    local cur = db().wieczor
    if cur and cur.id == p.id then return end
    if not InCombatLockdown() then invitePopup(who, p) end
  elseif f[1] == "R" then
    local p = db().wieczor
    if p and p.id == f[2] then
      p.answers = p.answers or {}
      p.answers[who] = f[3]
      local yes, n = U.planAnswers()
      U.say(who .. " odpowiada: " .. (f[3] == "tak" and "będzie" or (f[3] == "moze" and "może" or "nie będzie")) .. " (" .. yes .. " potwierdzonych z " .. n .. ").")
      if U.wyprawyRefresh then pcall(U.wyprawyRefresh) end
    end
  end
end

-- przypomnienie 15 min przed wieczorem (i wpis w kalendarzu Kroniki)
local function remind()
  local p = db().wieczor
  if not p or p.reminded or p.myAnswer == "nie" then return end
  local left = p.epoch - time()
  if left <= 15 * 60 and left > -30 * 60 then
    p.reminded = true
    local msg = "Za " .. math.max(0, math.floor(left / 60)) .. " min: " .. p.name .. " (zbiórka: " .. p.place .. ")"
    if G.showToast then pcall(G.showToast, msg, "dng", true) end
    U.say(msg .. ". Prowadzenie: hub > Wyprawy > Prowadź na zbiórkę.")
  end
end

local ev = CreateFrame("Frame")
for _, e in ipairs({ "PLAYER_LOGIN", "CHAT_MSG_ADDON", "GROUP_ROSTER_UPDATE", "PLAYER_LEVEL_UP", "ZONE_CHANGED_NEW_AREA",
  "PLAYER_REGEN_ENABLED", "ENCOUNTER_END" }) do pcall(ev.RegisterEvent, ev, e) end
ev:SetScript("OnEvent", function(_, event, a1, a2, a3, a4)
  if event == "PLAYER_LOGIN" then
    pcall(C_ChatInfo.RegisterAddonMessagePrefix, PREFIX)
    C_Timer.NewTicker(60, function() pcall(remind) end)
    C_Timer.After(15, function() pcall(U.statusSend) end)
  elseif event == "CHAT_MSG_ADDON" then
    if a1 == PREFIX then pcall(onMessage, a2, a3, a4) end
  elseif event == "PLAYER_REGEN_ENABLED" or event == "ENCOUNTER_END" then
    C_Timer.After(1, function() pcall(flush) end)
  else
    if not K.pend then
      K.pend = true
      C_Timer.After(3, function() K.pend = false pcall(U.statusSend) end)
    end
  end
end)
