-- Grimuar UI: Bestiariusz maga (14.11, R24 P6, wzor: bestiariusz Wiedzmina 3 i notatki lowcy z Monster Huntera).
-- Rosnie sam z tego, z czym walczysz: wrogi cel zapisuje sie (imie, poziomy, typ, ranga, strefy), do tego to, co
-- widac w grze: czary, ktore rzuca (pasek rzucania celu), ucieczka w strachu (komunikat), ile zabiles (komunikat XP),
-- ile razy zabil Ciebie, co z niego wypada (zrodlo lupu: GetLootSourceInfo). Porada maga na typ stwora.
-- Stan: GrimuarUIDB.bestie[npcID]. Midnight: ukryte wartosci (sekrety) pomijamy.
local ADDON, U = ...

local TYPE_PL = { Humanoid = "humanoid", Beast = "bestia", Undead = "nieumarły", Elemental = "żywiołak", Demon = "demon",
  Dragonkin = "smokowaty", Giant = "olbrzym", Mechanical = "mechaniczny", Critter = "zwierzątko" }
local TIPS = (U.G and U.G.BD and U.G.BD.creatures) or {} -- porady z aktywnego buildu
local K = { byName = {} }

local function secret(v) return issecretvalue and issecretvalue(v) end
local function str(v) if v == nil or secret(v) or type(v) ~= "string" or v == "" then return nil end return v end
local function store()
  local d = U.db()
  d.bestie = d.bestie or {}
  return d.bestie
end
local function npcOf(unit)
  local guid = U.call(UnitGUID, unit)
  if not str(guid) then return nil end
  local kind, _, _, _, _, id = strsplit("-", guid)
  if kind ~= "Creature" and kind ~= "Vehicle" then return nil end
  return tonumber(id)
end
local function entry(id, name)
  local b = store()
  local e = b[id]
  if not e then
    e = { name = name, zones = {}, casts = {}, loot = {}, kills = 0, killedMe = 0, flees = 0 }
    b[id] = e
  end
  if name then e.name = name K.byName[name] = id end
  return e
end

local function onTarget()
  if not U.call(UnitExists, "target") or U.call(UnitIsPlayer, "target") then K.cur = nil return end
  if not U.call(UnitCanAttack, "player", "target") then K.cur = nil return end
  local id = npcOf("target")
  local name = str(U.call(UnitName, "target"))
  if not id or not name then K.cur = nil return end
  local e = entry(id, name)
  K.cur = id
  local lv = U.num(U.call(UnitLevel, "target"))
  if lv and lv > 0 then
    e.lmin = math.min(e.lmin or lv, lv)
    e.lmax = math.max(e.lmax or lv, lv)
  elseif lv == -1 then e.boss = true end
  e.type = str(U.call(UnitCreatureType, "target")) or e.type
  e.fam = str(U.call(UnitCreatureFamily, "target")) or e.fam
  local cl = str(U.call(UnitClassification, "target"))
  if cl and cl ~= "normal" and cl ~= "trivial" and cl ~= "minus" then e.cls = cl end
  local z = str(GetRealZoneText())
  if z then e.zones[z] = true end
  e.seen = time()
end

local function onCast()
  if not K.cur then return end
  local ok, n = pcall(UnitCastingInfo, "target")
  if not ok or not str(n) then ok, n = pcall(UnitChannelInfo, "target") end
  n = ok and str(n)
  if not n then return end
  local e = store()[K.cur]
  if e and not e.casts[n] then e.casts[n] = true end
end

-- „X dies, you gain N experience.” -> zabity
local XP_PAT
local function xpPat()
  if XP_PAT ~= nil then return XP_PAT end
  local f = _G.COMBATLOG_XPGAIN_FIRSTPERSON
  if type(f) ~= "string" then XP_PAT = false return false end
  local p = f:gsub("%%%d?%$?s", "\001", 1):gsub("%%%d?%$?s", "\003"):gsub("%%%d?%$?d", "\002")
  p = p:gsub("[%^%$%(%)%%%.%[%]%*%+%-%?]", "%%%0")
  p = p:gsub("\001", "(.+)"):gsub("\002", "%%d+"):gsub("\003", ".+")
  XP_PAT = "^" .. p
  return XP_PAT
end
local function onXP(msg)
  if not str(msg) then return end
  local pat = xpPat()
  if not pat then return end
  local name = msg:match(pat)
  local id = name and K.byName[name]
  if id then
    local e = store()[id]
    if e then e.kills = (e.kills or 0) + 1 end
  end
end

local function onFlee(msg, sender)
  if not (str(msg) and str(sender)) then return end
  if not (msg:find("run away") or msg:find("flee") or msg:find("ucieka")) then return end
  local id = K.byName[sender]
  local e = id and store()[id]
  if e then e.flees = (e.flees or 0) + 1 end
end

local function onLoot()
  local n = U.num(U.call(GetNumLootItems)) or 0
  for slot = 1, n do
    local link = U.call(GetLootSlotLink, slot)
    local item = str(link) and tonumber(link:match("item:(%d+)"))
    if item then
      local src = { pcall(GetLootSourceInfo, slot) }
      if src[1] then
        for i = 2, #src, 2 do
          local guid, qty = src[i], src[i + 1]
          if str(guid) then
            local kind, _, _, _, _, id = strsplit("-", guid)
            id = tonumber(id)
            if id and (kind == "Creature" or kind == "Vehicle") then
              local e = store()[id]
              if e then e.loot[item] = (e.loot[item] or 0) + (tonumber(qty) or 1) end
            end
          end
        end
      end
    end
  end
end

-- dla zakladki: lista (od ostatnio widzianych) i porada
function U.bestiaryList()
  local out = {}
  for id, e in pairs(store()) do
    e.id = id
    out[#out + 1] = e
    if e.name then K.byName[e.name] = id end
  end
  table.sort(out, function(a, b) return (a.seen or 0) > (b.seen or 0) end)
  return out
end
function U.bestiaryTip(e)
  return e and e.type and TIPS[e.type] or nil
end
U.BEAST_TYPE_PL = TYPE_PL

local ev = CreateFrame("Frame")
for _, x in ipairs({ "PLAYER_LOGIN", "PLAYER_TARGET_CHANGED", "CHAT_MSG_COMBAT_XP_GAIN", "CHAT_MSG_MONSTER_EMOTE", "LOOT_OPENED",
  "PLAYER_DEAD" }) do pcall(ev.RegisterEvent, ev, x) end
pcall(ev.RegisterUnitEvent, ev, "UNIT_SPELLCAST_START", "target")
pcall(ev.RegisterUnitEvent, ev, "UNIT_SPELLCAST_CHANNEL_START", "target")
ev:SetScript("OnEvent", function(_, event, a1, a2)
  if event == "PLAYER_LOGIN" then pcall(U.bestiaryList)
  elseif event == "PLAYER_TARGET_CHANGED" then pcall(onTarget)
  elseif event == "UNIT_SPELLCAST_START" or event == "UNIT_SPELLCAST_CHANNEL_START" then pcall(onCast)
  elseif event == "CHAT_MSG_COMBAT_XP_GAIN" then pcall(onXP, a1)
  elseif event == "CHAT_MSG_MONSTER_EMOTE" then pcall(onFlee, a1, a2)
  elseif event == "LOOT_OPENED" then pcall(onLoot)
  elseif event == "PLAYER_DEAD" then
    if K.cur then local e = store()[K.cur] if e then e.killedMe = (e.killedMe or 0) + 1 end end
  end
end)
