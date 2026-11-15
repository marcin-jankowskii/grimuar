-- Grimuar UI: kontrakty dnia i tygodnia (14.11, R24 P4, wzor: Wizard's Vault z GW2, zlecenia z Destiny).
-- 3 cele dziennie i 5 na tydzien, losowane (stale dla dnia i postaci) z tego, co da sie zmierzyc: poziomy, oddane zadania,
-- wpływy zlota, punkty profesji, bossowie w lochach, zabici z Hordy, wylogowanie w karczmie. Nagroda: punkty i ranga
-- Grimuara (Nowicjusz -> Arcymag), bez nagrod w grze. Nic nie przepada i nie ma kar: niedokonczone znikaja z resetem.
-- Reset jak w grze (C_DateAndTime: dzien i tydzien), a bez tego o polnocy i w srode.
-- Widac je w Dzienniku (sekcja „Kontrakty Grimuara”) i w Kronice (Tydzien). Stan: GrimuarUIDB.kontrakty[postac].
local ADDON, U = ...
local G = U.G or {}

local DAILY_N, WEEKLY_N, DAILY_PTS, WEEKLY_PTS = 3, 5, 10, 30
local RANKS = { { 0, "Nowicjusz" }, { 100, "Adept" }, { 300, "Czeladnik" }, { 600, "Weteran" }, { 1000, "Mistrz" }, { 1600, "Arcymistrz" } }

-- pula celow: kind, ile (funkcja poziomu), tekst
local POOL_D = {
  { "quest", function() return 5 end, "Oddaj %d zadań" },
  { "level", function(l) return l < 60 and 1 or nil end, "Wbij poziom" },
  { "income", function(l) return math.max(20, l * 4) * 100 end, "Zarób %s (łupy, nagrody, sprzedaż)" },
  { "skill", function() return 5 end, "Podnieś profesje %d razy" },
  { "boss", function(l) return l >= 15 and 1 or nil end, "Pokonaj bossa w lochu" },
  { "hk", function(l) return l >= 20 and 1 or nil end, "Pokonaj gracza Hordy" },
  { "inn", function() return 1 end, "Skończ grę w karczmie albo mieście (odpoczynek)" },
}
local POOL_W = {
  { "quest", function() return 25 end, "Oddaj %d zadań" },
  { "level", function(l) return l < 59 and 2 or (l < 60 and 1 or nil) end, "Wbij %d poziomy" },
  { "income", function(l) return math.max(1, math.floor(l / 6)) * 10000 end, "Zarób %s" },
  { "skill", function() return 25 end, "Podnieś profesje %d razy" },
  { "boss", function(l) return l >= 15 and 4 or nil end, "Pokonaj %d bossów w lochach" },
  { "hk", function(l) return l >= 20 and 5 or nil end, "Pokonaj %d graczy Hordy" },
  { "inn", function() return 3 end, "Skończ grę %d razy w karczmie albo mieście" },
}

local function charKey() return (G.charKey and U.call(G.charKey)) or (UnitName("player") or "?") end
local function periods()
  local now = time()
  local d = U.num(U.call(C_DateAndTime and C_DateAndTime.GetSecondsUntilDailyReset))
  local w = U.num(U.call(C_DateAndTime and C_DateAndTime.GetSecondsUntilWeeklyReset))
  local dKey = d and math.floor((now + d) / 600) or tonumber(date("%Y%m%d"))
  local wKey
  if w then wKey = math.floor((now + w) / 600)
  else
    local t = date("*t", now)
    local back = (t.wday - 4) % 7 -- sroda
    wKey = tonumber(date("%Y%m%d", now - back * 86400))
  end
  return dKey, wKey
end

local function store()
  local db = U.db()
  db.kontrakty = db.kontrakty or {}
  local key = charKey()
  db.kontrakty[key] = db.kontrakty[key] or { pts = 0 }
  return db.kontrakty[key]
end

-- prosty generator liczb z ziarnem (staly wynik dla dnia i postaci)
local function seeded(seed)
  local x = seed % 2147483647
  if x <= 0 then x = x + 2147483646 end
  return function(n)
    x = (x * 16807) % 2147483647
    return (x % n) + 1
  end
end
local function hash(s)
  local h = 5381
  for i = 1, #s do h = (h * 33 + s:byte(i)) % 2147483647 end
  return h
end

local function pick(pool, n, seed, lvl)
  local avail = {}
  for _, p in ipairs(pool) do
    local need = p[2](lvl)
    if need then avail[#avail + 1] = { kind = p[1], need = need, fmt = p[3] } end
  end
  local rnd, out = seeded(seed), {}
  while #out < n and #avail > 0 do
    local i = rnd(#avail)
    out[#out + 1] = table.remove(avail, i)
  end
  return out
end

local function textOf(c)
  local v = c.kind == "income" and U.money(c.need) or c.need
  local fmt = (G.tr and G.tr(c.fmt)) or c.fmt -- E6: szablon tlumaczony przed formatowaniem
  return (fmt:find("%%") and string.format((fmt:gsub("%%d", "%%s")), tostring(v))) or fmt
end
U.contractText = function(c) return (c.fmt and textOf(c)) or c.text or "?" end

local function ensure()
  local s = store()
  local dKey, wKey = periods()
  local lvl = UnitLevel("player") or 1
  if s.dKey ~= dKey then
    s.dKey, s.daily = dKey, pick(POOL_D, DAILY_N, hash(charKey() .. "d" .. dKey), lvl)
    for _, c in ipairs(s.daily) do c.have, c.text = 0, textOf(c) end
  end
  if s.wKey ~= wKey then
    s.wKey, s.weekly = wKey, pick(POOL_W, WEEKLY_N, hash(charKey() .. "w" .. wKey), lvl)
    for _, c in ipairs(s.weekly) do c.have, c.text = 0, textOf(c) end
  end
  return s
end

function U.contractRank(pts)
  local cur, nxt = RANKS[1], nil
  for i, r in ipairs(RANKS) do
    if pts >= r[1] then cur, nxt = r, RANKS[i + 1] end
  end
  return cur[2], nxt and nxt[2], nxt and (nxt[1] - pts), cur[1], nxt and nxt[1]
end

local function bump(kind, n)
  local s = ensure()
  local done = {}
  for _, list in ipairs({ { s.daily, DAILY_PTS, "dzienny" }, { s.weekly, WEEKLY_PTS, "tygodniowy" } }) do
    for _, c in ipairs(list[1] or {}) do
      if c.kind == kind and not c.done then
        c.have = math.min(c.need, (c.have or 0) + n)
        if c.have >= c.need then
          c.done = true
          s.pts = (s.pts or 0) + list[2]
          done[#done + 1] = { c.text, list[2], list[3] }
        end
      end
    end
  end
  for _, d in ipairs(done) do
    local rank = U.contractRank(s.pts)
    local msg = "Kontrakt " .. d[3] .. " wykonany: " .. d[1] .. " (+" .. d[2] .. " pkt, ranga: " .. rank .. ")"
    if G.showToast then pcall(G.showToast, msg, "kontrakt", false) end
    U.say(msg .. ".")
  end
end

function U.contractsEvent(kind) bump(kind, 1) end
function U.contractsMoney(d) if d > 0 then bump("income", d) end end

-- jako zadania do Dziennika (ten sam ksztalt co zadania profesji: title, objs, where, why, tag, group)
function U.contractTasks()
  local s = ensure()
  local out = {}
  for _, list in ipairs({ { s.daily, "dzienny", DAILY_PTS }, { s.weekly, "tygodniowy", WEEKLY_PTS } }) do
    for i, c in ipairs(list[1] or {}) do
      if not c.done then
        local have = c.kind == "income" and U.money(c.have or 0) or tostring(c.have or 0)
        local need = c.kind == "income" and U.money(c.need) or tostring(c.need)
        out[#out + 1] = {
          key = "k" .. list[2]:sub(1, 1) .. i, title = U.contractText(c), tag = list[2], group = "Kontrakt", profPl = "Kontrakt " .. list[2],
          zoneLine = "Kontrakt " .. list[2] .. " · +" .. list[3] .. " pkt · zadanie Grimuara",
          objs = { { text = "Postęp: " .. have .. " / " .. need, done = false } },
          where = "Liczy się samo. Nagroda: " .. list[3] .. " pkt do rangi Grimuara.",
          why = "Nowe kontrakty po resecie dnia i tygodnia. Niedokończone po prostu znikają, bez kar.",
        }
      end
    end
  end
  return out
end

function U.contractsState()
  local s = ensure()
  return s
end

-- zabici z Hordy: licznik honoru z gry (roznica), a gdy go nie ma, komunikat o honorze
local function hkCheck()
  local hk = U.num(U.call(GetPVPLifetimeStats))
  if not hk then return false end
  local s = store()
  if s.hkLast and hk > s.hkLast then bump("hk", hk - s.hkLast) end
  s.hkLast = hk
  return true
end

local ev = CreateFrame("Frame")
for _, e in ipairs({ "PLAYER_LOGIN", "CHAT_MSG_SKILL", "ENCOUNTER_END", "PLAYER_LOGOUT", "CHAT_MSG_COMBAT_HONOR_GAIN",
  "PLAYER_PVP_KILLS_CHANGED" }) do
  pcall(ev.RegisterEvent, ev, e)
end
ev:SetScript("OnEvent", function(_, event, a1, a2, a3, a4, a5)
  if event == "PLAYER_LOGIN" then pcall(ensure) pcall(hkCheck)
  elseif event == "PLAYER_PVP_KILLS_CHANGED" then pcall(hkCheck)
  elseif event == "CHAT_MSG_SKILL" then bump("skill", 1)
  elseif event == "ENCOUNTER_END" then if a5 == 1 or a5 == true then bump("boss", 1) end
  elseif event == "CHAT_MSG_COMBAT_HONOR_GAIN" then
    local ok, used = pcall(hkCheck)
    if not (ok and used) then bump("hk", 1) end
  elseif event == "PLAYER_LOGOUT" then
    if U.call(IsResting) then bump("inn", 1) end
  end
end)
