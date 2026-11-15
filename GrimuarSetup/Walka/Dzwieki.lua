-- Grimuar: modul Dzwieki (13.11, punkt 4 „pominietych tematow”): krotkie sygnaly, gdy patrzysz gdzie indziej.
-- Tylko to, czego gra nie ukrywa w walce (Midnight): proc swieci przycisk, focus zaczyna rzucac, rzadki mob na plakietce,
-- atak z zaskoczenia (walka bez celu, solo). Wrogich graczy oglasza Spy wlasnym dzwiekiem (FrugNearby wyciszony 12.11).
-- Przelaczniki i „Posluchaj”: okno Grimuara, Ustawienia > Przelaczniki. /dzwieki gra wszystkie po kolei.
local ADDON_NAME, G = ...
local say = G.say

-- Dzwieki z gry (SOUNDKIT), z zapasowym numerem, gdyby nazwy nie bylo
local function kit(name, fallback) return (SOUNDKIT and SOUNDKIT[name]) or fallback end

local CUES = {
  { key = "proc", label = "Proc (przycisk zaświecił, np. Fingers of Frost)", def = true, sound = function() return kit("MAP_PING", 3175) end },
  { key = "focus", label = "Focus zaczyna rzucać czar (przerwij: F)", def = true, sound = function() return kit("ALARM_CLOCK_WARNING_2", 12867) end },
  { key = "target", label = "Cel zaczyna rzucać czar", def = false, sound = function() return kit("ALARM_CLOCK_WARNING_2", 12867) end },
  { key = "rare", label = "Rzadki mob w pobliżu (srebrny smok)", def = true, sound = function() return kit("UI_RAID_BOSS_WHISPER_WARNING", 37666) end },
  { key = "surprise", label = "Atak z zaskoczenia (walka bez celu, solo)", def = true, sound = function() return kit("RAID_WARNING", 8959) end },
}
local BY_KEY = {}
for _, c in ipairs(CUES) do BY_KEY[c.key] = c end

local function cfg()
  GrimuarSetupDB.sound = GrimuarSetupDB.sound or {}
  return GrimuarSetupDB.sound
end

local function on(key)
  if GrimuarSetupDB.noSounds then return false end
  local v = cfg()[key]
  if v == nil then return BY_KEY[key] and BY_KEY[key].def end
  return v
end

local last = {}
local function play(key, gap, force)
  local c = BY_KEY[key]
  if not c or (not force and not on(key)) then return end
  local now = GetTime()
  if not force and last[key] and now - last[key] < (gap or 1.5) then return end
  last[key] = now
  pcall(PlaySound, c.sound(), "Master")
end

-- R21: glos Blizzarda (Combat Audio Alerts): „przerwij” (wie, czy cast da sie przerwac) i „klatwa na Tobie"; dziala w walce
local CAA = { { "CAAEnabled", "1" }, { "CAADebuffSelfAlert", "1" }, { "CAAInterruptCast", "1" }, { "CAAInterruptCastSuccess", "0" }, { "CAASayIfTargeted", "0" } }
local function caaAvailable()
  local ok, v = pcall(function() return C_CVar.GetCVar("CAAEnabled") end)
  return ok and v ~= nil
end
local function caaToggle()
  if InCombatLockdown() then say("przełączę po walce.") return end
  GrimuarSetupDB.caaOn = not GrimuarSetupDB.caaOn
  for _, c in ipairs(CAA) do
    pcall(function()
      if C_CVar.GetCVar(c[1]) ~= nil then C_CVar.SetCVar(c[1], GrimuarSetupDB.caaOn and c[2] or "0") end
    end)
  end
  say(GrimuarSetupDB.caaOn and "głos Blizzarda włączony: „przerwij” przy czarach celu, „klątwa” na Tobie." or "głos Blizzarda wyłączony.")
end

local function secret(v)
  local ok, r = pcall(function() return issecretvalue and issecretvalue(v) end)
  return ok and r or false
end

local function hostile(u)
  local ok, r = pcall(UnitCanAttack, "player", u)
  return ok and not secret(r) and r
end

-- rzadkie moby: kazdy raz na 5 minut (po nazwie; gdy nazwa ukryta, raz na minute)
local rareSeen = {}
local function rareCheck(u)
  if not on("rare") then return end
  local okC, cls = pcall(UnitClassification, u)
  if not okC or secret(cls) or (cls ~= "rare" and cls ~= "rareelite") then return end
  local okD, dead = pcall(UnitIsDead, u)
  if okD and not secret(dead) and dead then return end
  if not hostile(u) then return end
  local okN, nm = pcall(UnitName, u)
  local key = (okN and not secret(nm) and type(nm) == "string") and nm or "?"
  local now = GetTime()
  if rareSeen[key] and now - rareSeen[key] < ((key == "?") and 60 or 300) then return end
  rareSeen[key] = now
  play("rare", 0)
  if key ~= "?" and G.showToast then pcall(G.showToast, "rzadki mob w pobliżu: " .. key .. ". Często ma lepszy łup.", "rare", false) end
end

local ev = CreateFrame("Frame")
ev:RegisterEvent("PLAYER_LOGIN")
ev:SetScript("OnEvent", function(_, event, a1)
  if event == "PLAYER_LOGIN" then
    pcall(ev.RegisterEvent, ev, "SPELL_ACTIVATION_OVERLAY_GLOW_SHOW")
    pcall(ev.RegisterUnitEvent, ev, "UNIT_SPELLCAST_START", "focus", "target")
    pcall(ev.RegisterUnitEvent, ev, "UNIT_SPELLCAST_CHANNEL_START", "focus", "target")
    pcall(ev.RegisterEvent, ev, "NAME_PLATE_UNIT_ADDED")
    pcall(ev.RegisterEvent, ev, "PLAYER_REGEN_DISABLED")
    pcall(ev.RegisterEvent, ev, "PLAYER_REGEN_ENABLED")
  elseif event == "SPELL_ACTIVATION_OVERLAY_GLOW_SHOW" then
    play("proc", 1)
    -- R18: zapis, co w Forever swieci (Claude czyta przy sync; potem ewentualny filtr po ID)
    pcall(function()
      if a1 == nil or secret(a1) then return end
      GrimuarSetupDB.glowSeen = GrimuarSetupDB.glowSeen or {}
      local nm = C_Spell and C_Spell.GetSpellName and C_Spell.GetSpellName(a1)
      GrimuarSetupDB.glowSeen[a1] = (type(nm) == "string" and nm or "?") .. " @" .. (UnitLevel("player") or 0)
    end)
  elseif event == "UNIT_SPELLCAST_START" or event == "UNIT_SPELLCAST_CHANNEL_START" then
    if (a1 == "focus" or a1 == "target") and hostile(a1) then
      if a1 == "focus" then play("focus", 1.5) else
        local same = false
        pcall(function() local r = UnitIsUnit("target", "focus") same = (not secret(r)) and r or false end)
        if not same then play("target", 1.5) end
      end
    end
  elseif event == "NAME_PLATE_UNIT_ADDED" then
    if a1 then pcall(rareCheck, a1) end
  elseif event == "PLAYER_REGEN_ENABLED" then
    -- R21: ID Fingers of Frost (po walce czesto jeszcze wisi) do aury Musca i Cooldown Managera; Claude czyta przy sync
    C_Timer.After(0.2, function()
      pcall(function()
        if GrimuarSetupDB.fofId or not C_UnitAuras or not C_UnitAuras.GetAuraDataBySpellName then return end
        local a = C_UnitAuras.GetAuraDataBySpellName("player", "Fingers of Frost", "HELPFUL")
        if a and not secret(a) and not secret(a.spellId) and a.spellId then GrimuarSetupDB.fofId = a.spellId end
      end)
    end)
  elseif event == "PLAYER_REGEN_DISABLED" then
    local inGroup = IsInGroup and IsInGroup()
    local hasTarget = UnitExists("target")
    if not inGroup and not hasTarget then
      play("surprise", 5)
      if on("surprise") and G.showToast then pcall(G.showToast, "atak! Ktoś Cię bije: Tab wybierze najbliższego wroga.", "fight", true) end
    end
  end
end)

-- ---------- okno: Ustawienia > Przelaczniki (sekcja Dzwieki) ----------
local function soundPage(P, rerender)
  P.H("Dźwięki")
  P.M("Krótkie sygnały, gdy patrzysz gdzie indziej. Wrogich graczy ogłasza Spy własnym dźwiękiem. Głośność: kanał Master.")
  if caaAvailable() then
    P.BTNROW({ { "Głos Blizzarda: „przerwij” i „klątwa na Tobie”:  " .. (GrimuarSetupDB.caaOn and "|cff7cc68bwł.|r" or "|cff9aa4b1wył.|r"), function()
      caaToggle()
      if rerender then pcall(rerender) end
    end } })
  end
  P.BTNROW({ { "Wszystkie dźwięki Grimuara:  " .. (GrimuarSetupDB.noSounds and "|cff9aa4b1wył.|r" or "|cff7cc68bwł.|r"), function()
    GrimuarSetupDB.noSounds = not GrimuarSetupDB.noSounds
    if rerender then pcall(rerender) end
  end } })
  for _, c in ipairs(CUES) do
    local st = on(c.key)
    P.BTNROW({
      { c.label .. ":  " .. (st and "|cff7cc68bwł.|r" or "|cff9aa4b1wył.|r"), function()
        cfg()[c.key] = not on(c.key)
        if rerender then pcall(rerender) end
      end },
      { "Posłuchaj", function() play(c.key, 0, true) end },
    })
  end
  P.M("Dźwięk „gotowe” dla Novy, Ice Blocka i Cold Snapa (raz, ręcznie): Edit Mode > Cooldown Manager > ustawienia czaru > Alert > Dźwięk > Dostępne > Short: Bell Strike. Od 24 to samo dla Counterspella.")
end

SLASH_GRIMUARDZWIEKI1 = "/dzwieki"
SlashCmdList["GRIMUARDZWIEKI"] = function()
  for i, c in ipairs(CUES) do
    C_Timer.After((i - 1) * 1.6, function()
      say("dźwięk: " .. c.label .. (on(c.key) and "" or " (wyłączony)"))
      play(c.key, 0, true)
    end)
  end
end

G.soundPage = soundPage
G.caaToggle = caaToggle
G.playCue = play
