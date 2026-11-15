-- Grimuar: modul Engine (wspolne funkcje przez tabele G z innych modulow).
local ADDON_NAME, G = ...
local C_FROST = G.C_FROST
local C_GOLD = G.C_GOLD
local C_MUTED = G.C_MUTED
local C_OK = G.C_OK
local DUNGEONS = G.DUNGEONS
local FONT = G.FONT
local STAGES = G.STAGES
local TALENT_AT = G.TALENT_AT
local charKey = G.charKey
local knownSpellId = G.knownSpellId
local say = G.say

-- Czesc wydzielona z Engine.lua (podzial plikow >1000 linii, 12.11).

-- ============================================================
-- SESJA, TEMPO, PRZYPOMINAJKI, ZNACZNIKI, DZIENNIK (wszystko poza walka)
-- ============================================================
local S = { startEpoch = nil, xpGained = 0, lastXP = nil, lastMax = nil, lastLevel = nil, level0 = nil, money0 = nil,
  deaths = {}, zones = {}, budgetEnd = nil, budgetMins = nil, warned10 = false, warnedEnd = false }

local function safeStr(v)
  if v == nil then return nil end
  local ok, s = pcall(function() return tostring(v) .. "" end)
  if ok then return s end
  return nil
end

local function fmtK(n)
  if not n then return "?" end
  if n >= 1000 then return string.format("%.1fk", n / 1000) end
  return tostring(math.floor(n + 0.5))
end

local function fmtMoney(c)
  c = math.floor(c or 0)
  local sign = c < 0 and "-" or "+"
  c = math.abs(c)
  local g, s = math.floor(c / 10000), math.floor((c % 10000) / 100)
  if g > 0 then return sign .. g .. "g " .. s .. "s" end
  return sign .. s .. "s " .. (c % 100) .. "c"
end

local function sessionStart(resume)
  if resume then
    S.startEpoch, S.xpGained, S.level0 = resume.startEpoch, resume.xpGained or 0, resume.level0
    S.money0, S.deaths, S.zones = resume.money0, resume.deaths or {}, resume.zones or {}
  else
    S.startEpoch, S.xpGained, S.level0 = time(), 0, UnitLevel("player")
    S.money0, S.deaths, S.zones = GetMoney(), {}, {}
  end
  S.xpEvents = (resume and resume.xpEvents) or {}
  S.lastXP, S.lastMax, S.lastLevel = UnitXP("player"), UnitXPMax("player"), UnitLevel("player")
end

local function xpUpdate()
  local xp, mx, lv = UnitXP("player"), UnitXPMax("player"), UnitLevel("player")
  if not S.lastXP then
    S.lastXP, S.lastMax, S.lastLevel = xp, mx, lv
    return
  end
  local gain
  if lv > S.lastLevel then
    gain = math.max(0, S.lastMax - S.lastXP) + xp
  else
    gain = math.max(0, xp - S.lastXP)
  end
  S.xpGained = S.xpGained + gain
  if gain > 0 then
    S.xpEvents = S.xpEvents or {}
    table.insert(S.xpEvents, { time(), gain })
    while #S.xpEvents > 0 and time() - S.xpEvents[1][1] > 1800 do table.remove(S.xpEvents, 1) end
  end
  S.lastXP, S.lastMax, S.lastLevel = xp, mx, lv
end

local function sessionMinutes()
  if not S.startEpoch then return 0 end
  return (time() - S.startEpoch) / 60
end
-- Tempo z ostatnich 20 minut (a nie od poczatku sesji), zeby przerwy i ustawianie addonow nie zanizaly wyniku.
local function xpPerHour()
  local now = time()
  local win = 1200
  local span = math.min(win, now - (S.startEpoch or now))
  if span < 300 then return nil end
  local sum = 0
  for _, ev in ipairs(S.xpEvents or {}) do
    if now - ev[1] <= win then sum = sum + ev[2] end
  end
  if sum <= 0 then return nil end
  return sum / span * 3600
end
local function minutesToLevel()
  local xph = xpPerHour()
  if not xph then return nil end
  return (UnitXPMax("player") - UnitXP("player")) / xph * 60
end
local function restedPercent()
  local r = GetXPExhaustion and GetXPExhaustion() or 0
  local mx = UnitXPMax("player")
  if not r or not mx or mx == 0 then return 0 end
  return math.floor(r / mx * 100 + 0.5)
end

local function tempoLine()
  local parts = {}
  if UnitLevel("player") < 60 then
    local xph = xpPerHour()
    if xph then
      table.insert(parts, "XP/h " .. fmtK(xph))
      local m = minutesToLevel()
      if m then table.insert(parts, "poziom za " .. math.floor(m + 0.5) .. " min") end
    else
      table.insert(parts, "XP/h: liczę")
    end
    table.insert(parts, "rested " .. restedPercent() .. "%")
  end
  table.insert(parts, "sesja " .. math.floor(sessionMinutes()) .. " min")
  if S.budgetEnd then
    table.insert(parts, "zostało " .. math.max(0, math.floor((S.budgetEnd - time()) / 60)) .. " min")
  end
  return table.concat(parts, "  ·  ")
end

-- ---------- komunikat na srodku ekranu (lepszy sygnal niz czat) ----------
local ICONS = {
  armor = "Interface\\Icons\\Spell_Frost_FrostArmor02", ai = "Interface\\Icons\\Spell_Holy_MagicalSentry",
  water = "Interface\\Icons\\INV_Drink_06", train = "Interface\\Icons\\INV_Misc_Book_11",
  tal = "Interface\\Icons\\INV_Misc_Book_09", dura = "Interface\\Icons\\Trade_BlackSmithing",
  repair = "Interface\\Icons\\Trade_BlackSmithing", bags = "Interface\\Icons\\INV_Misc_Bag_08",
  track = "Interface\\Icons\\INV_Misc_Flower_02", pvp = "Interface\\Icons\\Ability_DualWield",
  camp = "Interface\\Icons\\INV_Misc_Rune_01", budget = "Interface\\Icons\\INV_Misc_PocketWatch_01",
  book = "Interface\\Icons\\INV_Misc_Book_07", turnin = "Interface\\Icons\\INV_Misc_Note_01",
  gildia = "Interface\\Icons\\INV_Shirt_GuildTabard_01", grupa = "Interface\\Icons\\Spell_Holy_PrayerOfSpirit",
  klatwa = "Interface\\Icons\\Spell_Nature_RemoveCurse",
  todo = "Interface\\Icons\\INV_Misc_Note_02",   dng = "Interface\\Icons\\INV_Misc_Key_03", rest = "Interface\\Icons\\INV_Drink_07",
}
local function iconFor(key)
  key = key or ""
  for prefix, path in pairs(ICONS) do
    if key:sub(1, #prefix) == prefix then return path end
  end
  return "Interface\\Icons\\Spell_Frost_FrostBolt02"
end

local toast
local toastToken = 0
local function createToast()
  toast = CreateFrame("Frame", "GrimuarToast", UIParent, "BackdropTemplate")
  toast:SetSize(480, 58)
  toast:SetPoint("CENTER", UIParent, "CENTER", 0, 230)
  toast:SetFrameStrata("HIGH")
  toast:EnableMouse(false)
  pcall(function()
    toast:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8X8", edgeFile = "Interface\\Buttons\\WHITE8X8", edgeSize = 2 })
    toast:SetBackdropColor(0.04, 0.05, 0.09, 0.93)
  end)
  toast.icon = toast:CreateTexture(nil, "ARTWORK")
  toast.icon:SetSize(38, 38)
  toast.icon:SetPoint("LEFT", toast, "LEFT", 10, 0)
  toast.head = toast:CreateFontString(nil, "OVERLAY")
  toast.head:SetFont(FONT, 11, "")
  toast.head:SetTextColor(0.37, 0.8, 0.94)
  toast.head:SetPoint("TOPLEFT", toast, "TOPLEFT", 58, -8)
  toast.head:SetText("Grimuar")
  toast.text = toast:CreateFontString(nil, "OVERLAY")
  toast.text:SetFont(FONT, 16, "")
  toast.text:SetTextColor(1, 0.93, 0.75)
  toast.text:SetJustifyH("LEFT")
  toast.text:SetJustifyV("TOP")
  toast.text:SetWidth(404)
  toast.text:SetPoint("TOPLEFT", toast, "TOPLEFT", 58, -22)
  toast:Hide()
end

local function showToast(msg, key, loud)
  if G.showBanner and not GrimuarSetupDB.noBanner then return G.showBanner(msg, key, loud) end -- wstegi (Wstegi.lua)
  if not toast then createToast() end
  toast.icon:SetTexture(iconFor(key))
  toast.text:SetText((msg:gsub("^%l", string.upper)))
  toast:SetHeight(math.max(58, toast.text:GetStringHeight() + 32))
  pcall(function()
    if loud then toast:SetBackdropBorderColor(0.94, 0.54, 0.44, 1) else toast:SetBackdropBorderColor(0.85, 0.71, 0.36, 1) end
  end)
  toast:SetAlpha(1)
  toast:Show()
  pcall(UIFrameFadeIn, toast, 0.25, 0, 1)
  toastToken = toastToken + 1
  local my = toastToken
  C_Timer.After(loud and 10 or 7, function()
    if toastToken ~= my then return end
    pcall(UIFrameFadeOut, toast, 0.8, 1, 0)
    C_Timer.After(0.9, function() if toastToken == my then toast:Hide() end end)
  end)
  pcall(function()
    if loud then PlaySound(SOUNDKIT.RAID_WARNING) else PlaySound(SOUNDKIT.MAP_PING) end
  end)
end

-- ---------- przypominajki ----------
local lastRemind = {}
local function remind(key, msg, loud, cooldown)
  local now = GetTime()
  if lastRemind[key] and now - lastRemind[key] < (cooldown or 300) then return end
  lastRemind[key] = now
  -- UX 12.11: jeden kanal. Wstega (historia w oknie: Dziś), a czat tylko, gdy komunikaty sa wylaczone.
  if GrimuarSetupDB.noToast then say(msg) else pcall(showToast, msg, key, loud) end
end

local function hasAura(name)
  local found = false
  pcall(function()
    if C_UnitAuras and C_UnitAuras.GetAuraDataBySpellName then
      found = C_UnitAuras.GetAuraDataBySpellName("player", name, "HELPFUL") ~= nil
    elseif AuraUtil and AuraUtil.FindAuraByName then
      found = AuraUtil.FindAuraByName(name, "player", "HELPFUL") ~= nil
    end
  end)
  return found
end

local TRAINABLE = {
  { 1, "Arcane Intellect" }, { 4, "Frostbolt" }, { 4, "Conjure Water" }, { 6, "Fire Blast" }, { 6, "Conjure Food" }, { 6, "Comprehend Scroll" },
  { 8, "Polymorph" }, { 10, "Frost Nova" },
  { 20, "Blink" }, { 20, "Evocation" }, { 20, "Teleport: Stormwind" },
  { 20, "Teleport: Ironforge" }, { 24, "Counterspell" }, { 26, "Cone of Cold" }, { 28, "Conjure Mana Agate" },
  { 30, "Ice Armor" }, { 34, "Mage Armor" }, { 40, "Portal: Ironforge" }, { 40, "Portal: Stormwind" }, { 56, "Arcane Brilliance" },
}

-- 13.11 (gracz: „nie pokazuje mi, ze jednego spella od trenera nie wzialem”): po samej nazwie nie widac brakujacej
-- rangi (Frostbolt 2 na 8 poziomie). Dane trenera Forever z Polestara (QoL/ClassSpells.lua: poziom, numer czaru, ranga,
-- poprzednia ranga), przefiltrowane planem Frosta (Trener.lua G.trainWanted). Bez Polestara: stara lista po nazwach.
local function spellKnown(id)
  if C_SpellBook and C_SpellBook.IsSpellKnown and C_SpellBook.IsSpellKnown(id) then return true end
  if IsPlayerSpell and IsPlayerSpell(id) then return true end
  return (IsSpellKnown and IsSpellKnown(id)) and true or false
end

local function missingFromPolestar(l)
  local S = Polestar and Polestar.QoL and Polestar.QoL.Spells
  local _, class = UnitClass("player")
  local d = S and S.Data and S.Data(class)
  if not (d and d.byLevel and next(d.byLevel)) then return nil end
  local out, opt, seen = {}, {}, {}
  local levels = {}
  for lvl in pairs(d.byLevel) do if lvl <= l then levels[#levels + 1] = lvl end end
  table.sort(levels)
  for _, lvl in ipairs(levels) do
    for _, e in ipairs(d.byLevel[lvl]) do
      local prevOk = (e.prev or 0) == 0 or spellKnown(e.prev) or (d.byId[e.prev] and d.byId[e.prev].level <= l)
      if prevOk and not spellKnown(e.id) then
        local name = (C_Spell and C_Spell.GetSpellName and C_Spell.GetSpellName(e.id)) or (GetSpellInfo and GetSpellInfo(e.id))
        local rankText = (e.rank or 0) > 0 and ("Rank " .. e.rank) or ""
        if name and not seen[name] then
          seen[name] = true
          local label = ((e.rank or 0) > 1) and (name .. " " .. e.rank) or name
          -- 14.11 (gracz: „powinno mnie zawsze prowadzic”): czary spoza planu Frosta tez, jako opcjonalne
          if not G.trainWanted or G.trainWanted(name, rankText) then out[#out + 1] = label else opt[#opt + 1] = label end
        end
      end
    end
  end
  return out, opt
end

local lastOptional = {}
local function missingTraining()
  local l = UnitLevel("player") or 1
  local ok, list, opt = pcall(missingFromPolestar, l)
  if ok and list then
    lastOptional = opt or {}
    return list
  end
  local out = {}
  for _, t in ipairs(TRAINABLE) do
    if t[1] <= l and not knownSpellId(t[2]) then table.insert(out, t[2]) end
  end
  return out
end

local WATER = { "Conjured Water", "Conjured Fresh Water", "Conjured Purified Water", "Conjured Spring Water",
  "Conjured Mineral Water", "Conjured Sparkling Water", "Conjured Crystal Water" }
local function waterCount()
  local ok, n = pcall(G.drinkCount)
  if ok and type(n) == "number" then return n end
  return 0
end

local function minDurability()
  local lowest
  for slot = 1, 18 do
    local cur, mx = GetInventoryItemDurability(slot)
    if cur and mx and mx > 0 then
      local p = cur / mx * 100
      if not lowest or p < lowest then lowest = p end
    end
  end
  return lowest
end

local function freeBagSlots()
  local free = 0
  for bag = 0, 4 do
    local ok, n = pcall(function()
      if C_Container and C_Container.GetContainerNumFreeSlots then return C_Container.GetContainerNumFreeSlots(bag) end
      return GetContainerNumFreeSlots(bag)
    end)
    if ok and type(n) == "number" then free = free + n end
  end
  return free
end

-- ---------- sledzenie zbieractwa na minimapie (Find Herbs / Find Minerals) ----------
local GATHER = { ["Find Herbs"] = true, ["Find Minerals"] = true }

local function trackingList()
  local out = {}
  pcall(function()
    local n = (C_Minimap and C_Minimap.GetNumTrackingTypes and C_Minimap.GetNumTrackingTypes())
      or (GetNumTrackingTypes and GetNumTrackingTypes()) or 0
    for i = 1, n do
      local a, _, c
      if C_Minimap and C_Minimap.GetTrackingInfo then a, _, c = C_Minimap.GetTrackingInfo(i) else a, _, c = GetTrackingInfo(i) end
      local name, active
      if type(a) == "table" then name, active = a.name, a.active else name, active = a, c end
      if name then table.insert(out, { i = i, name = name, active = active and true or false }) end
    end
  end)
  return out
end

local function gatherState()
  local has, active = false, false
  for _, t in ipairs(trackingList()) do
    if GATHER[t.name] then
      has = true
      if t.active then active = true end
    end
  end
  return has, active
end

local function enableGatherTracking()
  local found = {}
  for _, t in ipairs(trackingList()) do
    if GATHER[t.name] then
      table.insert(found, t.name)
      if not t.active then
        pcall(function()
          if C_Minimap and C_Minimap.SetTracking then C_Minimap.SetTracking(t.i, true) else SetTracking(t.i, true) end
        end)
      end
    end
  end
  if #found == 0 then
    say("najpierw naucz się Herbalism albo Mining u trenera profesji (zapytaj strażnika o Profession Trainer). Potem kliknij jeszcze raz.")
    return
  end
  C_Timer.After(0.6, function()
    local on = {}
    for _, t in ipairs(trackingList()) do
      if GATHER[t.name] and t.active then table.insert(on, t.name) end
    end
    if #on > 0 then
      say("śledzenie włączone: " .. table.concat(on, ", ") .. ". Zioła i ruda pokażą się na minimapie jako kropki.")
      if #on < #found then say("działa jedno śledzenie naraz. Zmienisz je lupą obok nazwy strefy nad minimapą.") end
    else
      say("nie udało się włączyć śledzenia. Kliknij lupę obok nazwy strefy nad minimapą i zaznacz Find Herbs albo Find Minerals.")
    end
    if G.refreshAll then G.refreshAll() end
  end)
end

-- 13.11 gracz („zrob to”): klawisz przelacza sledzenie zioła <-> ruda (gra sledzi jedno naraz). Makro Sledzenie
-- (Apteczka.lua) wola GrimuarSledzenie(); bez Mining albo Herbalism wlacza to, co jest.
local function toggleGather()
  local herbs, ore
  for _, t in ipairs(trackingList()) do
    if t.name == "Find Herbs" then herbs = t elseif t.name == "Find Minerals" then ore = t end
  end
  local want = (herbs and herbs.active and ore) and ore or herbs or ore
  if want and want.active and not (herbs and ore) then want = nil end
  if not want then
    UIErrorsFrame:AddMessage((herbs or ore) and "Grimuar: śledzenie już włączone" or "Grimuar: najpierw naucz się Herbalism albo Mining", 1, 0.82, 0)
    return
  end
  pcall(function()
    if C_Minimap and C_Minimap.SetTracking then C_Minimap.SetTracking(want.i, true) else SetTracking(want.i, true) end
  end)
  UIErrorsFrame:AddMessage("Grimuar: śledzenie " .. (want.name == "Find Herbs" and "ziół" or "rudy"), 0.49, 0.78, 0.55)
end
function GrimuarSledzenie() pcall(toggleGather) end

local function talentPoints()
  local pts
  pcall(function() if UnitCharacterPoints then pts = UnitCharacterPoints("player") end end)
  if type(pts) == "number" and pts > 0 then return pts end
  -- 14.11: Forever trzyma talenty w C_Traits (jak okno talentow ForeverSkin): punkty do wydania z drzewa klasy
  local q
  pcall(function()
    local CS, T = C_SpecializationInfo, C_Traits
    local cfg = CS.GetCombatConfigIDForSpecGroup(CS.GetActiveSpecGroup() or 1)
    if not cfg and C_ClassTalents then cfg = C_ClassTalents.GetActiveConfigID() end
    local info = T.GetConfigInfo(cfg)
    local cur = T.GetTreeCurrencyInfo(cfg, info.treeIDs[1], false)
    q = cur and cur[1] and cur[1].quantity
  end)
  if type(q) == "number" and not (issecretvalue and issecretvalue(q)) then return q end
  if type(pts) == "number" then return pts end
  return 0
end

local function runReminders(trigger)
  if InCombatLockdown() or UnitIsDeadOrGhost("player") then return end
  local l = UnitLevel("player")
  local auraApi = (C_UnitAuras and C_UnitAuras.GetAuraDataBySpellName) or (AuraUtil and AuraUtil.FindAuraByName)
  if auraApi and not IsMounted() and not UnitOnTaxi("player") then
    local hasArmorSpell = knownSpellId("Frost Armor") or knownSpellId("Ice Armor") or knownSpellId("Mage Armor")
    if hasArmorSpell and not (hasAura("Frost Armor") or hasAura("Ice Armor") or hasAura("Mage Armor")) then
      remind("armor", "brak pancerza: rzuć Frost Armor albo Ice Armor (klawisz 8).", false, 240)
    end
    -- 14.11 (R27 E2): buffy z aktywnego buildu (G.BD.buffs) dla pozostalych klas
    if select(2, UnitClass("player")) ~= "MAGE" then
      for i, bf in ipairs(G.BD and G.BD.buffs or {}) do
        local known, active = false, false
        for _, nm in ipairs(bf.any or {}) do
          if knownSpellId(nm) then known = true end
          if hasAura(nm) then active = true end
        end
        if known and not active then remind("bb" .. i, tostring(bf.msg or "brak buffu") .. (bf.key and (": klawisz " .. bf.key) or "") .. ".", false, 240) end
      end
    end
    if knownSpellId("Arcane Intellect") and not (hasAura("Arcane Intellect") or hasAura("Arcane Brilliance")) then
      remind("ai", "brak Arcane Intellect: klawisz 9.", false, 240)
    end
  end
  local d = minDurability()
  if d and d < 25 then remind("dura", "sprzęt zużyty w " .. math.floor(100 - d) .. "%. Napraw u kupca z kowadłem.", d < 15, 900) end
  local free = freeBagSlots()
  if free <= 2 then remind("bags", "torby prawie pełne (wolne miejsca: " .. free .. "). Kliknij monetę obok toreb" .. (G.vendorKey and G.vendorKey() and (" albo " .. G.vendorKey()) or "") .. ": strzałka do najbliższego kupca.", false, 600) end
  if trigger == "rest" then
    local miss = missingTraining()
    if #miss > 0 then remind("train" .. l, "u trenera maga czeka: " .. table.concat(miss, ", ") .. ".", false, 1800) end
    if talentPoints() > 0 then remind("tal" .. l, "masz wolny punkt talentu (N): " .. (TALENT_AT[l] or "?") .. ".", false, 1800) end
  elseif trigger == "leave" then
    if l >= 4 and knownSpellId("Conjure Water") then
      local w = waterCount()
      if w < 10 then remind("water", "wychodzisz z miasta z wodą: " .. w .. ". Lewy klik na ikonie W tworzy wodę.", false, 900) end
    end
  end
end

local function checkZone()
  local zone = GetZoneText() or ""
  if zone ~= "" then
    local seen = false
    for _, z in ipairs(S.zones) do if z == zone then seen = true end end
    if not seen then table.insert(S.zones, zone) end
  end
  local pvpType
  pcall(function()
    if C_PvP and C_PvP.GetZonePVPInfo then pvpType = C_PvP.GetZonePVPInfo() else pvpType = GetZonePVPInfo() end
  end)
  if pvpType == "contested" or pvpType == "hostile" then
    remind("pvp" .. zone, "strefa sporna PvP: " .. zone .. ". Tabliczki wrogów (V) i Spy włączone, uważaj na Hordę.", true, 1800)
  end
end

-- ---------- minutnik sesji ----------
local function hearthInfo()
  local ok, start, dur = pcall(function()
    if C_Container and C_Container.GetItemCooldown then return C_Container.GetItemCooldown(6948) end
    return GetItemCooldown(6948)
  end)
  if ok and type(start) == "number" and type(dur) == "number" and start > 0 and dur > 1.5 then
    return "Hearthstone za " .. math.ceil((start + dur - GetTime()) / 60) .. " min"
  end
  return "Hearthstone gotowy"
end

local function budgetTick()
  if not S.budgetEnd then return end
  local left = (S.budgetEnd - time()) / 60
  if left <= 10 and not S.warned10 then
    S.warned10 = true
    remind("budget10", "za 10 min koniec sesji. Skończ quest i kieruj się do karczmy (" .. hearthInfo() .. ").", true, 60)
  end
  if left <= 0 and not S.warnedEnd then
    S.warnedEnd = true
    remind("budgetEnd", "koniec zaplanowanej sesji. Wyloguj się w karczmie, żeby dostać rested XP.", true, 60)
  end
end

local function setBudget(mins)
  if not mins or mins <= 0 then
    S.budgetEnd, S.budgetMins = nil, nil
    say("minutnik sesji wyłączony.")
    return
  end
  S.budgetMins = mins
  S.budgetEnd = time() + mins * 60
  S.warned10 = mins <= 10
  S.warnedEnd = false
  say("minutnik: " .. mins .. " min. 10 min przed końcem przypomnę o karczmie.")
end

-- eksport do pozostalych modulow
G.S = S
G.safeStr = safeStr
G.fmtK = fmtK
G.fmtMoney = fmtMoney
G.sessionStart = sessionStart
G.xpUpdate = xpUpdate
G.sessionMinutes = sessionMinutes
G.xpPerHour = xpPerHour
G.minutesToLevel = minutesToLevel
G.restedPercent = restedPercent
G.tempoLine = tempoLine
G.ICONS = ICONS
G.iconFor = iconFor
G.toast = toast
G.toastToken = toastToken
G.createToast = createToast
G.showToast = showToast
G.lastRemind = lastRemind
G.remind = remind
G.hasAura = hasAura
G.TRAINABLE = TRAINABLE
G.missingTraining = missingTraining
G.optionalTraining = function() pcall(missingTraining) return lastOptional end

-- 14.11: komunikat o brakach (trener, torby, sprzet) robi Rozwoj.lua
G.WATER = WATER
G.waterCount = waterCount
G.minDurability = minDurability
G.freeBagSlots = freeBagSlots
G.GATHER = GATHER
G.trackingList = trackingList
G.gatherState = gatherState
G.enableGatherTracking = enableGatherTracking
G.toggleGather = toggleGather
G.talentPoints = talentPoints
G.runReminders = runReminders
G.checkZone = checkZone
G.hearthInfo = hearthInfo
G.budgetTick = budgetTick
G.setBudget = setBudget
