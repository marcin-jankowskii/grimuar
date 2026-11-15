-- Grimuar UI: Kronika — zapis sesji (14.11, R24 P1/P2/P12; gracz: „wszystkie wyzej wymienione rzeczy rob”).
-- Sesja = granie bez przerwy dluzszej niz 15 min (ta sama zasada co GrimuarSetup Prowadzenie.lua).
-- Zapisuje: oddane zadania, poziomy, lochy, lupy z wartoscia (Auctionator, inaczej cena u kupca), rachunki (skad
-- przyszlo i na co poszlo zloto: okno kupca, trenera, lotu, poczty, domu aukcyjnego, lupu, nagrody), zabitych graczy
-- Hordy (honor), zrzuty ekranu w waznych chwilach (awans, pierwszy raz w lochu; /hub zrzuty wylacza).
-- „Poprzednio w Grimuarze”: po powrocie po co najmniej 4 h okienko z poprzednia sesja i pierwszym krokiem na dzis.
-- Stan: GrimuarUIDB.kronika[postac] = { cur, list (ostatnie 60), first = { lochy } }.
local ADDON, U = ...
local C = U.C
local G = U.G or {}

local RESUME, MAXLIST, PREV_GAP = 900, 60, 4 * 3600
local K = { ctx = {} }

U.MONEY_PL = {
  quest = "nagrody za zadania", loot = "łupy (monety)", sell = "sprzedaż u kupca", buy = "zakupy u kupca",
  repair = "naprawy", train = "trener", taxi = "loty", mail = "poczta (sprzedane na aukcji)", post = "poczta i wystawianie",
  ah = "dom aukcyjny", inc = "inne wpływy", out = "inne wydatki",
}
local WDAY = { "nd", "pn", "wt", "śr", "cz", "pt", "sob" }

local function charKey() return (G.charKey and U.call(G.charKey)) or ((UnitName("player") or "?") .. "-" .. (GetRealmName() or "?")) end
local function store()
  local d = U.db()
  d.kronika = d.kronika or {}
  local key = charKey()
  d.kronika[key] = d.kronika[key] or { list = {}, first = { lochy = {} } }
  local s = d.kronika[key]
  s.list = s.list or {}
  s.first = s.first or { lochy = {} }
  s.first.lochy = s.first.lochy or {}
  return s
end
function U.kronika() return store() end

local function newRec()
  return { start = time(), last = time(), level0 = UnitLevel("player"), level = UnitLevel("player"), quests = {}, nq = 0,
    loot = {}, lootV = 0, money = {}, levels = {}, dungeons = {}, shots = 0, hk = 0, zone = GetRealZoneText() }
end

-- ---------- pieniadze i formatowanie ----------
-- 15.11 gracz: „co to znaczy s o m”: monety jak w grze (zloto, srebro, miedz), bez zerowych czesci; przy zlocie bez miedzi
local COIN = { "|TInterface\\MoneyFrame\\UI-GoldIcon:0:0:2:0|t", "|TInterface\\MoneyFrame\\UI-SilverIcon:0:0:2:0|t",
  "|TInterface\\MoneyFrame\\UI-CopperIcon:0:0:2:0|t" }
function U.money(c, sign)
  c = math.floor(tonumber(c) or 0)
  local neg = c < 0
  c = math.abs(c)
  local g, s, m = math.floor(c / 10000), math.floor((c % 10000) / 100), c % 100
  local parts = {}
  if g > 0 then parts[#parts + 1] = U.thousands(g) .. COIN[1] end
  if s > 0 then parts[#parts + 1] = s .. COIN[2] end
  if m > 0 and g == 0 then parts[#parts + 1] = m .. COIN[3] end
  if #parts == 0 then parts[1] = "0" .. COIN[3] end
  return (neg and "–" or (sign and "+" or "")) .. table.concat(parts, " ")
end
function U.itemValue(id)
  local v
  pcall(function()
    local A = Auctionator and Auctionator.API and Auctionator.API.v1
    if A and A.GetAuctionPriceByItemID then v = A.GetAuctionPriceByItemID("Grimuar", id) end
  end)
  if not (U.num(v) and v > 0) then
    v = nil
    pcall(function()
      local sell = select(11, (C_Item and C_Item.GetItemInfo or GetItemInfo)(id))
      if U.num(sell) and sell > 0 then v = sell end
    end)
  end
  return U.num(v) or 0
end
function U.fmtDate(epoch)
  local t = date("*t", epoch)
  return WDAY[t.wday] .. " " .. string.format("%02d.%02d, %02d:%02d", t.day, t.month, t.hour, t.min)
end
function U.fmtMins(m)
  m = math.floor(m or 0)
  if m < 60 then return m .. " min" end
  return math.floor(m / 60) .. " h " .. (m % 60) .. " min"
end

-- ---------- sesja ----------
local function rec() return K.rec end
local function saveNow()
  local r = rec()
  if not r then return end
  r.last = time()
  r.level = UnitLevel("player") or r.level
  r.zone = GetRealZoneText() or r.zone
  pcall(function() r.xp = G.S and G.S.xpGained or r.xp end)
  pcall(function() r.deaths = G.S and G.S.deaths and #G.S.deaths or r.deaths end)
  pcall(function()
    local hk = GetPVPSessionStats and GetPVPSessionStats()
    if U.num(hk) and K.hk0 then r.hk = math.max(r.hk or 0, hk - K.hk0) end
  end)
  store().cur = r
end
U.kronikaSave = saveNow

local function begin()
  local s = store()
  local cur = s.cur
  if cur and cur.last and time() - cur.last < RESUME then
    K.rec = cur
    K.resumed = true
  else
    if cur and cur.start and (cur.last - cur.start) >= 60 then
      table.insert(s.list, cur)
      while #s.list > MAXLIST do table.remove(s.list, 1) end
    end
    K.rec = newRec()
    K.resumed = false
  end
  s.cur = K.rec
  K.money = GetMoney()
  pcall(function() K.hk0 = U.num(GetPVPSessionStats and GetPVPSessionStats()) or 0 end)
end

local function addMoney(cat, d)
  local r = rec()
  if not r then return end
  r.money[cat] = (r.money[cat] or 0) + d
  if U.contractsMoney then pcall(U.contractsMoney, d) end
end

local function onMoney()
  local now = GetMoney()
  local d = now - (K.money or now)
  K.money = now
  if d == 0 then return end
  local c, t = K.ctx, GetTime()
  local cat
  if c.loot then cat = "loot"
  elseif c.quest then cat = "quest"
  elseif c.merchant then cat = d > 0 and "sell" or ((t - (c.merchantAt or 0) < 2.5) and "repair" or "buy")
  elseif c.trainer then cat = "train"
  elseif c.taxi then cat = "taxi"
  elseif c.mail then cat = d > 0 and "mail" or "post"
  elseif c.ah then cat = "ah"
  else cat = d > 0 and "inc" or "out" end
  addMoney(cat, d)
end

-- ---------- lupy ----------
local PATS
local function toPat(fmt)
  if type(fmt) ~= "string" then return nil end
  local p = fmt:gsub("%%%d?%$?s", "\001"):gsub("%%%d?%$?d", "\002")
  p = p:gsub("[%^%$%(%)%%%.%[%]%*%+%-%?]", "%%%0")
  p = p:gsub("\001", "(.+)"):gsub("\002", "(%%d+)")
  return "^" .. p .. "$"
end
local function pats()
  if PATS then return PATS end
  PATS = {}
  for _, g in ipairs({ { "LOOT_ITEM_SELF_MULTIPLE", true }, { "LOOT_ITEM_PUSHED_SELF_MULTIPLE", true },
    { "LOOT_ITEM_SELF", false }, { "LOOT_ITEM_PUSHED_SELF", false } }) do
    local p = toPat(_G[g[1]])
    if p then PATS[#PATS + 1] = { p, g[2] } end
  end
  return PATS
end
local function onLoot(msg)
  if type(msg) ~= "string" or (issecretvalue and issecretvalue(msg)) then return end
  for _, p in ipairs(pats()) do
    local link, n = msg:match(p[1])
    if link then
      local id = tonumber(link:match("item:(%d+)"))
      if not id then return end
      n = p[2] and tonumber(n) or 1
      local r = rec()
      if not r then return end
      local v = U.itemValue(id) * n
      local e = r.loot[id] or { 0, 0 }
      e[1], e[2] = e[1] + n, e[2] + v
      r.loot[id] = e
      r.lootV = (r.lootV or 0) + v
      if U.bestiaryLoot then pcall(U.bestiaryLoot, id, n) end
      return
    end
  end
end

-- najcenniejsze lupy sesji (bez szarych): { id, n, v }
function U.kronikaTop(r, n)
  local out = {}
  for id, e in pairs(r and r.loot or {}) do
    local q = select(3, U.call(C_Item and C_Item.GetItemInfo or GetItemInfo, id))
    if q == nil or (U.num(q) or 1) >= 1 then out[#out + 1] = { id = id, n = e[1], v = e[2] } end
  end
  table.sort(out, function(a, b) return a.v > b.v end)
  while #out > (n or 5) do table.remove(out) end
  return out
end
function U.itemLabel(id)
  local name, _, q = U.call(C_Item and C_Item.GetItemInfo or GetItemInfo, id)
  if not name then return "przedmiot " .. id end
  local c = U.QUALITY[U.num(q) or 1] or C.text
  return U.hex(c) .. name .. "|r"
end

-- ---------- zrzuty ekranu ----------
local function shot(why)
  if U.db().noShots then return end
  C_Timer.After(1.2, function()
    if InCombatLockdown() then return end
    if pcall(Screenshot) then
      local r = rec()
      if r then r.shots = (r.shots or 0) + 1 end
      U.say("zrzut ekranu do kroniki: " .. why .. ". (/hub zrzuty wyłącza)")
    end
  end)
end
U.kronikaShot = shot

-- ---------- „Poprzednio w Grimuarze” ----------
local PP
function U.kronikaPrevText(p)
  if not p then return nil end
  local lines = {}
  lines[#lines + 1] = U.fmtDate(p.start) .. " · " .. U.fmtMins((p.last - p.start) / 60)
  local net = 0
  for _, v in pairs(p.money or {}) do net = net + v end
  local parts = {}
  if p.level0 and p.level and p.level > p.level0 then parts[#parts + 1] = "poziom " .. p.level0 .. " → " .. p.level
  else parts[#parts + 1] = "poziom " .. tostring(p.level or "?") end
  parts[#parts + 1] = (p.nq or 0) .. " zadań"
  if (p.deaths or 0) > 0 then parts[#parts + 1] = p.deaths .. " " .. (p.deaths == 1 and "zgon" or "zgony") end
  parts[#parts + 1] = "złoto " .. U.money(net, true)
  if (p.lootV or 0) > 0 then parts[#parts + 1] = "łupy ok. " .. U.money(p.lootV) end
  if (p.hk or 0) > 0 then parts[#parts + 1] = p.hk .. " zabitych z Hordy" end
  lines[#lines + 1] = table.concat(parts, " · ")
  local top = U.kronikaTop(p, 1)[1]
  if top then lines[#lines + 1] = "Najlepszy łup: " .. U.itemLabel(top.id) .. " (" .. U.money(top.v) .. ")" end
  if #(p.dungeons or {}) > 0 then lines[#lines + 1] = "Lochy: " .. table.concat(p.dungeons, ", ") end
  if p.zone then lines[#lines + 1] = "Skończyłeś w: " .. p.zone end
  return table.concat(lines, "\n")
end

local function showPrev()
  local s = store()
  local p = s.list[#s.list]
  if not p or K.resumed or (time() - (p.last or 0)) < PREV_GAP or U.db().noPrev then return end
  if InCombatLockdown() then return end
  if not PP then
    PP = U.Panel(UIParent, 0.95, true, C.edge)
    PP:SetFrameStrata("MEDIUM")
    PP:SetSize(460, 200)
    PP:SetPoint("TOP", UIParent, "TOP", 0, -200)
    PP:EnableMouse(true)
    PP.h = U.H2(PP, "Poprzednio w Grimuarze")
    PP.h:SetPoint("TOPLEFT", 18, -16)
    PP.text = U.Para(PP, 13, 424, C.text)
    PP.text:SetPoint("TOPLEFT", PP.h, "BOTTOMLEFT", 0, -10)
    PP.now = U.Para(PP, 13, 424, C.gold)
    PP.now:SetPoint("TOPLEFT", PP.text, "BOTTOMLEFT", 0, -10)
    PP.open = U.Button(PP, "Kronika", nil, 28, true)
    PP.open:SetPoint("BOTTOMLEFT", 18, 16)
    PP.open:SetScript("OnClick", function() PP:Hide() if GrimuarHubOpen then GrimuarHubOpen("kronika") end end)
    PP.close = U.Button(PP, "Graj", nil, 28)
    PP.close:SetPoint("LEFT", PP.open, "RIGHT", 8, 0)
    PP.close:SetScript("OnClick", function() PP:Hide() end)
  end
  PP.text:SetText(U.kronikaPrevText(p) or "")
  local step
  pcall(function()
    local st = G.buildSteps and G.buildSteps()
    step = st and st[1] and st[1].text
  end)
  if not step then
    pcall(function() local t = Polestar and Polestar.Nav and Polestar.Nav.GetTarget() step = t and t.label end)
  end
  PP.now:SetText(step and ("Dziś zacznij od: " .. tostring(step):gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "")) or "")
  PP:SetHeight(math.max(160, 98 + PP.text:GetStringHeight() + PP.now:GetStringHeight()))
  PP:Show()
  C_Timer.After(60, function() if PP then PP:Hide() end end)
end

-- ---------- zdarzenia ----------
local ev = CreateFrame("Frame")
local EV = { "PLAYER_LOGIN", "PLAYER_LOGOUT", "PLAYER_MONEY", "CHAT_MSG_LOOT", "QUEST_TURNED_IN", "PLAYER_LEVEL_UP",
  "PLAYER_ENTERING_WORLD", "LOOT_OPENED", "LOOT_CLOSED", "QUEST_COMPLETE", "QUEST_FINISHED", "MERCHANT_SHOW", "MERCHANT_CLOSED",
  "TRAINER_SHOW", "TRAINER_CLOSED", "TAXIMAP_OPENED", "TAXIMAP_CLOSED", "MAIL_SHOW", "MAIL_CLOSED",
  "AUCTION_HOUSE_SHOW", "AUCTION_HOUSE_CLOSED", "PLAYER_INTERACTION_MANAGER_FRAME_SHOW", "PLAYER_INTERACTION_MANAGER_FRAME_HIDE" }
for _, e in ipairs(EV) do pcall(ev.RegisterEvent, ev, e) end
local CTX = { LOOT_OPENED = { "loot", true }, LOOT_CLOSED = { "loot", false }, QUEST_COMPLETE = { "quest", true },
  QUEST_FINISHED = { "quest", false }, MERCHANT_SHOW = { "merchant", true }, MERCHANT_CLOSED = { "merchant", false },
  TRAINER_SHOW = { "trainer", true }, TRAINER_CLOSED = { "trainer", false }, TAXIMAP_OPENED = { "taxi", true },
  TAXIMAP_CLOSED = { "taxi", false }, MAIL_SHOW = { "mail", true }, MAIL_CLOSED = { "mail", false },
  AUCTION_HOUSE_SHOW = { "ah", true }, AUCTION_HOUSE_CLOSED = { "ah", false } }
ev:SetScript("OnEvent", function(_, event, a1, a2, a3)
  if event == "PLAYER_LOGIN" then
    begin()
    C_Timer.NewTicker(30, function() pcall(saveNow) end)
    C_Timer.After(12, function() pcall(showPrev) end)
    return
  end
  if not K.rec then return end
  local c = CTX[event]
  if c then
    -- zloto przychodzi chwile po zamknieciu okna lupow/nagrody: kontekst gasnie z opoznieniem
    if c[2] then K.ctx[c[1]] = true
      if c[1] == "merchant" then K.ctx.merchantAt = GetTime() end
    else C_Timer.After(0.6, function() K.ctx[c[1]] = nil end) end
    return
  end
  if event == "PLAYER_MONEY" then pcall(onMoney)
  elseif event == "CHAT_MSG_LOOT" then pcall(onLoot, a1)
  elseif event == "QUEST_TURNED_IN" then
    local r = rec()
    r.nq = (r.nq or 0) + 1
    local title = U.call(C_QuestLog.GetTitleForQuestID, a1) or ("#" .. tostring(a1))
    if #r.quests < 40 then r.quests[#r.quests + 1] = title end
    if U.contractsEvent then pcall(U.contractsEvent, "quest") end
  elseif event == "PLAYER_LEVEL_UP" then
    local r = rec()
    r.levels[#r.levels + 1] = { a1, time() }
    r.level = a1
    shot("poziom " .. tostring(a1))
    if U.contractsEvent then pcall(U.contractsEvent, "level") end
  elseif event == "PLAYER_ENTERING_WORLD" then
    C_Timer.After(3, function()
      local inInst, typ = U.call(IsInInstance)
      if inInst and (typ == "party" or typ == "raid") then
        local name = U.call(GetInstanceInfo)
        if type(name) == "string" then
          local r = rec()
          local seen = false
          for _, d in ipairs(r.dungeons) do if d == name then seen = true end end
          if not seen then r.dungeons[#r.dungeons + 1] = name end
          local s = store()
          if not s.first.lochy[name] then
            s.first.lochy[name] = time()
            shot("pierwszy raz: " .. name)
          end
        end
      end
    end)
  elseif event == "PLAYER_LOGOUT" then
    pcall(saveNow)
  end
end)

function U.kronikaCmd(arg)
  local d = U.db()
  if arg == "zrzuty" then
    d.noShots = not d.noShots
    U.say("zrzuty ekranu do kroniki: " .. (d.noShots and "wyłączone" or "włączone") .. ".")
  elseif arg == "poprzednio" then
    d.noPrev = not d.noPrev
    U.say("„Poprzednio w Grimuarze” po powrocie: " .. (d.noPrev and "wyłączone" or "włączone") .. ".")
  end
end
