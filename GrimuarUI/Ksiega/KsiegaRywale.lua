-- Grimuar UI: Rywale (14.11, R24 P3, wzor: system Nemezis z Shadow of Mordor; Scout i True Spy jako addony).
-- Tylko odczyt z Spy (Forever 1.3.8): SpyPerCharDB.PlayerData (wygrane, przegrane, klasa, rasa, poziom, gildia),
-- SpyPerCharDB.Encounters (ostatnie starcie: miejsce i czas), SpyPerCharDB.KOSData (Twoja lista „zabij od razu”),
-- Spy.NearbyList (kto jest teraz w poblizu). Do bazy Spy nic nie zapisujemy.
-- Rywal = gracz Hordy, ktory zabil Cie co najmniej 2 razy, albo jest na liscie KOS. Gdy Spy zobaczy rywala w poblizu:
-- wstega i dzwiek z bilansem i rada na jego klase (te same porady co po zgonie, GrimuarSetup Zgony.lua).
-- Twoje notatki o rywalach: GrimuarUIDB.rywale[imie].
local ADDON, U = ...
local G = U.G or {}

local CLASS_PL = { WARRIOR = "Wojownik", ROGUE = "Łotrzyk", PALADIN = "Paladyn", HUNTER = "Łowca", SHAMAN = "Szaman",
  DRUID = "Druid", PRIEST = "Kapłan", WARLOCK = "Czarnoksiężnik", MAGE = "Mag" }
local K = { alerted = {} }

local function spy() return type(SpyPerCharDB) == "table" and SpyPerCharDB or nil end
local function tok(cls)
  if type(cls) ~= "string" then return nil end
  local up = cls:upper():gsub("%s", "")
  if CLASS_PL[up] then return up end
  for t, pl in pairs(CLASS_PL) do if pl == cls then return t end end
  return up
end
U.CLASS_PL = CLASS_PL

local function lastEncounter(name)
  local db = spy()
  local list = db and type(db.Encounters) == "table" and db.Encounters or {}
  for i = #list, 1, -1 do
    local e = list[i]
    if type(e) == "table" and e.n == name then return e end
  end
end

-- lista rywali i wszystkich, z ktorymi bylo starcie: { name, cls, clsPl, race, level, guild, wins, loses, kos, rival, last }
function U.rivalsList()
  local db = spy()
  if not db or type(db.PlayerData) ~= "table" then return nil end
  local kos = type(db.KOSData) == "table" and db.KOSData or {}
  local out = {}
  for name, p in pairs(db.PlayerData) do
    if type(p) == "table" and p.isEnemy ~= false then
      local w, l = tonumber(p.wins) or 0, tonumber(p.loses) or 0
      local isKos = kos[name] ~= nil
      if w + l > 0 or isKos then
        local t = tok(p.class)
        out[#out + 1] = { name = name, cls = t, clsPl = CLASS_PL[t or ""] or p.class, race = p.race, level = (p.isGuess == false) and p.level or nil,
          guild = p.guild, wins = w, loses = l, kos = isKos, rival = l >= 2 or isKos, last = lastEncounter(name) }
      end
    end
  end
  table.sort(out, function(a, b)
    if a.rival ~= b.rival then return a.rival end
    if a.loses ~= b.loses then return a.loses > b.loses end
    return a.wins > b.wins
  end)
  return out
end

function U.rivalTip(r)
  local diff = r.level and (r.level - (UnitLevel("player") or 1)) or nil
  return G.deathTip and U.call(G.deathTip, { player = true, class = r.cls, diff = diff }) or nil
end
function U.rivalNote(name, text)
  local d = U.db()
  d.rywale = d.rywale or {}
  if text ~= nil then d.rywale[name] = (text ~= "" and text or nil) end
  return d.rywale[name]
end
function U.rivalWhere(e)
  if not (e and e.m) then return nil end
  local info = U.call(C_Map.GetMapInfo, e.m)
  return (info and info.name or "?") .. (e.x and string.format(" (%.0f, %.0f)", e.x * 100, e.y * 100) or "")
end

-- alarm: rywal w poblizu (Spy.NearbyList), raz na 10 min na osobe
local function scan()
  if U.db().noRivalAlarm then return end
  local S = _G.Spy
  local near = S and type(S.NearbyList) == "table" and S.NearbyList
  if not near then return end
  local db = spy()
  if not db then return end
  for name in pairs(near) do
    local p = db.PlayerData and db.PlayerData[name]
    local l = p and tonumber(p.loses) or 0
    local isKos = db.KOSData and db.KOSData[name] ~= nil
    if (l >= 2 or isKos) and GetTime() - (K.alerted[name] or -9999) > 600 then
      K.alerted[name] = GetTime()
      local t = tok(p and p.class)
      local r = { name = name, cls = t, level = p and p.isGuess == false and p.level or nil }
      local msg = "Rywal w pobliżu: " .. name .. " (" .. (CLASS_PL[t or ""] or "?") .. (r.level and (" " .. r.level) or "")
        .. ", bilans " .. (tonumber(p and p.wins) or 0) .. ":" .. l .. ")"
      if G.showToast then pcall(G.showToast, msg, "pvp", true) end
      local tip = U.rivalTip(r)
      local note = U.rivalNote(name)
      U.say(msg .. ". " .. (tip or "") .. (note and (" Notatka: " .. note) or ""))
      pcall(PlaySound, (SOUNDKIT and SOUNDKIT.RAID_WARNING) or 8959, "Master")
    end
  end
end

local ev = CreateFrame("Frame")
ev:RegisterEvent("PLAYER_LOGIN")
ev:SetScript("OnEvent", function()
  C_Timer.NewTicker(3, function() pcall(scan) end)
end)

function U.rivalCmd()
  local d = U.db()
  d.noRivalAlarm = not d.noRivalAlarm
  U.say("alarm o rywalach w pobliżu: " .. (d.noRivalAlarm and "wyłączony" or "włączony") .. ".")
end
