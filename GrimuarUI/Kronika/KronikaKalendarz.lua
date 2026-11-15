-- Grimuar UI: kalendarz wydarzen (14.11, R24 P5). Swieta i Jarmark Darkmoon z kalendarza gry (C_Calendar, te same daty,
-- z ktorych korzysta klient Forever), a gdy kalendarz nic nie poda: Jarmark w Elwynn 9–16.11.2026 (daty z klienta wg
-- kami-labs, 31.10). Do tego terminy Grimuara: nowe czary u trenera, wierzchowiec na 40, odpoczynek, nowe kontrakty.
-- Wstega po wejsciu do gry, gdy cos trwa albo konczy sie w ciagu doby (raz dziennie na wydarzenie).
local ADDON, U = ...
local G = U.G or {}

local FALLBACK = {
  { title = "Jarmark Darkmoon (Elwynn Forest)", start = time({ year = 2026, month = 11, day = 9, hour = 4, min = 0 }),
    stop = time({ year = 2026, month = 11, day = 16, hour = 4, min = 0 }), src = "daty z klienta (kami-labs, 31.10)" },
}
local TIPS = {
  { "Darkmoon", "Wróżba u Sayge: buff na 2 h. Bilety za przedmioty i zadania jarmarku. Horda musi przejść przez ziemie Przymierza: uważaj w Elwynn." },
  { "Hallow", "Cukierki w karczmach, przebrania." },
  { "Midsummer", "Ogniska w strefach: każde daje trochę doświadczenia." },
  { "Lunar", "Starsi w strefach: każdy daje monetę i trochę doświadczenia." },
}
local K = { events = nil }

local function tipFor(title)
  for _, t in ipairs(TIPS) do if title:find(t[1]) then return t[2] end end
  return nil
end
local function epochOf(ct)
  if type(ct) ~= "table" then return nil end
  return time({ year = ct.year, month = ct.month, day = ct.monthDay or ct.day, hour = ct.hour or 0, min = ct.minute or 0 })
end

local function readCalendar()
  if not (C_Calendar and C_Calendar.GetNumDayEvents and C_Calendar.GetDayEvent) then return nil end
  local now = U.call(C_DateAndTime and C_DateAndTime.GetCurrentCalendarTime)
  if type(now) ~= "table" then return nil end
  local by, list = {}, {}
  for off = 0, 1 do
    for day = 1, 31 do
      if off == 1 or day >= (now.monthDay or 1) - 7 then
        local n = U.num(U.call(C_Calendar.GetNumDayEvents, off, day)) or 0
        for i = 1, n do
          local e = U.call(C_Calendar.GetDayEvent, off, day, i)
          if type(e) == "table" and e.title and (e.calendarType == "HOLIDAY" or e.calendarType == nil) then
            local s, t = epochOf(e.startTime), epochOf(e.endTime)
            local x = by[e.title]
            if not x then
              x = { title = e.title, start = s, stop = t, src = "kalendarz gry" }
              by[e.title] = x
              list[#list + 1] = x
            else
              if s and (not x.start or s < x.start) then x.start = s end
              if t and (not x.stop or t > x.stop) then x.stop = t end
            end
          end
        end
      end
    end
  end
  return list
end

-- wydarzenia trwajace i nadchodzace (do 30 dni): { title, start, stop, tip, now = bool, src }
function U.calendarEvents()
  local list = K.events
  if not list or #list == 0 then list = FALLBACK end
  local out, t = {}, time()
  for _, e in ipairs(list) do
    if e.stop and e.stop > t and (not e.start or e.start < t + 30 * 86400) then
      out[#out + 1] = { title = e.title, start = e.start, stop = e.stop, tip = tipFor(e.title), now = (e.start or 0) <= t, src = e.src }
    end
  end
  table.sort(out, function(a, b) return (a.start or 0) < (b.start or 0) end)
  return out
end

local function inText(sec)
  sec = math.max(0, math.floor(sec or 0))
  local d, h, m = math.floor(sec / 86400), math.floor((sec % 86400) / 3600), math.floor((sec % 3600) / 60)
  if d > 0 then return d .. " d " .. h .. " h" end
  if h > 0 then return h .. " h " .. m .. " min" end
  return m .. " min"
end
U.inText = inText

-- terminy Grimuara: { title, text, right, frac, icon, col } (15.11: karty z paskiem w Kronice > Kalendarz)
function U.grimuarTimers()
  local out = {}
  local lvl = UnitLevel("player") or 1
  local xp, xpMax = U.num(U.call(UnitXP, "player")), U.num(U.call(UnitXPMax, "player"))
  local inLvl = (xp and xpMax and xpMax > 0) and (xp / xpMax) or 0
  if lvl < 60 then
    local nxt = lvl % 2 == 0 and lvl + 2 or lvl + 1
    out[#out + 1] = { title = "Trener", right = "poziom " .. nxt, text = "nowe czary co parzysty poziom",
      icon = "Interface\\Icons\\INV_Misc_Book_09", frac = (nxt == lvl + 2) and (inLvl / 2) or (0.5 + inLvl / 2) }
  end
  if lvl < 40 then
    out[#out + 1] = { title = "Wierzchowiec", right = "poziom 40", icon = "Interface\\Icons\\Ability_Mount_RidingHorse",
      text = "jeszcze " .. (40 - lvl) .. " " .. (40 - lvl == 1 and "poziom" or "poziomów") .. ". Cel złota: Grimuar > Postęp.",
      frac = (lvl - 1 + inLvl) / 39 }
  end
  pcall(function()
    local r = U.num(GetXPExhaustion and GetXPExhaustion()) or 0
    if xpMax and xpMax > 0 then
      local pct = math.floor(r / xpMax * 100 + 0.5)
      out[#out + 1] = { title = "Odpoczynek", right = pct .. "%", icon = "Interface\\Icons\\Spell_Nature_Sleep", col = U.C.frost,
        text = "podwójne XP (maks. 150%; w karczmie ok. 5% na 8 h)", frac = math.min(1, pct / 150) }
    end
  end)
  local d = U.num(U.call(C_DateAndTime and C_DateAndTime.GetSecondsUntilDailyReset))
  local w = U.num(U.call(C_DateAndTime and C_DateAndTime.GetSecondsUntilWeeklyReset))
  if d then out[#out + 1] = { title = "Kontrakty dnia", right = "za " .. inText(d), text = "nowe kontrakty po resecie dnia",
    icon = "Interface\\Icons\\INV_Misc_Note_01", frac = math.max(0, 1 - d / 86400) } end
  if w then out[#out + 1] = { title = "Kontrakty tygodnia", right = "za " .. inText(w), text = "nowe kontrakty po resecie tygodnia",
    icon = "Interface\\Icons\\INV_Scroll_03", frac = math.max(0, 1 - w / (7 * 86400)) } end
  return out
end

local function remind()
  local d = U.db()
  d.kalSeen = d.kalSeen or {}
  local today = date("%Y-%m-%d")
  for _, e in ipairs(U.calendarEvents()) do
    local key = e.title .. "|" .. today
    if not d.kalSeen[key] and (e.now or (e.start and e.start - time() < 86400)) then
      d.kalSeen[key] = true
      local msg = e.now and ("Trwa: " .. e.title .. " (do " .. U.fmtDate(e.stop) .. ")")
        or (e.title .. ": od " .. U.fmtDate(e.start))
      if G.showToast then pcall(G.showToast, msg, "kalendarz", false) end
      U.say(msg .. (e.tip and (". " .. e.tip) or "") .. " Kalendarz: hub > Kronika.")
      return
    end
  end
end

local ev = CreateFrame("Frame")
pcall(ev.RegisterEvent, ev, "PLAYER_LOGIN")
pcall(ev.RegisterEvent, ev, "CALENDAR_UPDATE_EVENT_LIST")
ev:SetScript("OnEvent", function(_, event)
  if event == "PLAYER_LOGIN" then
    C_Timer.After(15, function() pcall(function() if C_Calendar and C_Calendar.OpenCalendar then C_Calendar.OpenCalendar() end end) end)
    C_Timer.After(25, function() pcall(remind) end)
  elseif event == "CALENDAR_UPDATE_EVENT_LIST" then
    local ok, list = pcall(readCalendar)
    if ok and list and #list > 0 then K.events = list end
  end
end)
