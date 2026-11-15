-- Grimuar: modul Apteczka (prosba gracza 13.11: skrot do bandazy i mikstur). Dwa makra z najlepszym przedmiotem z torby:
--   C = Bandaz: na osobe pod myszka, na przyjazny cel, inaczej na siebie;
--   V = Mikstura: leczenie, z Shiftem mana.
-- Przedmioty rozpoznaje po czarze (bandaz: First Aid, mikstury: Healing Potion / Restore Mana), a gdy gra go nie poda, po nazwie.
-- Tresc makr Grimuar podmienia poza walka po kazdej zmianie w torbach (w walce gra nie pozwala edytowac makr).
-- C dotad otwieralo postac (to samo co I i B), V przelaczalo paski zdrowia nad postaciami.
local ADDON_NAME, G = ...
local say = G.say

local KINDS = {
  bandaz = { spells = { ["First Aid"] = true }, pat = "Bandage" },
  leczenie = { spells = { ["Healing Potion"] = true }, pat = "Healing Potion" },
  mana = { spells = { ["Restore Mana"] = true }, pat = "Mana Potion" },
}
local KEYS = {
  { "C", "MACRO Bandaz", "bandaż" },
  { "V", "MACRO Mikstura", "mikstura leczenia" },
  { "SHIFT-V", "MACRO Mikstura", "mikstura many" },
  -- 13.11 v2: przelaczanie sledzenia zioła/ruda (Engine.lua toggleGather); pierwszy wolny z listy
  { { "Y", "SHIFT-C", "ALT-C" }, "MACRO Sledzenie", "śledzenie: zioła albo ruda" },
}
-- klawisze, ktore wolno zajac: wolne albo z domyslnym przypisaniem gry
local FREE = { [""] = true, TOGGLECHARACTER0 = true, NAMEPLATES = true, ALLNAMEPLATES = true, FRIENDNAMEPLATES = true }

local function itemInfo(id)
  local name, spell, ilvl, req, usable
  pcall(function()
    local info = { (C_Item and C_Item.GetItemInfo or GetItemInfo)(id) }
    name, ilvl, req = info[1], info[4], info[5]
  end)
  pcall(function() spell = (C_Item and C_Item.GetItemSpell or GetItemSpell)(id) end)
  pcall(function() usable = (C_Item and C_Item.IsUsableItem or IsUsableItem)(id) end)
  return name, spell, tonumber(ilvl) or 0, tonumber(req) or 0, usable
end

-- najlepszy przedmiot kazdego rodzaju w torbach: najwyzszy poziom przedmiotu, ktorego mozesz uzyc
local function scan()
  local best = {}
  local lvl = UnitLevel("player") or 1
  for bag = 0, 4 do
    local n = 0
    pcall(function() n = (C_Container and C_Container.GetContainerNumSlots or GetContainerNumSlots)(bag) end)
    for slot = 1, (n or 0) do
      local id
      pcall(function()
        if C_Container and C_Container.GetContainerItemID then id = C_Container.GetContainerItemID(bag, slot)
        else id = GetContainerItemID(bag, slot) end
      end)
      if id then
        local name, spell, ilvl, req, usable = itemInfo(id)
        if name and req <= lvl and usable ~= false then
          for kind, k in pairs(KINDS) do
            if (spell and k.spells[spell]) or name:find(k.pat, 1, true) then
              if not best[kind] or ilvl > best[kind].ilvl then best[kind] = { name = name, ilvl = ilvl } end
            end
          end
        end
      end
    end
  end
  return best
end

local function warn(text)
  return "/run UIErrorsFrame:AddMessage(\"Grimuar: " .. text .. "\", 1, 0.3, 0.3)"
end

local function bodies(best)
  local b = best.bandaz and best.bandaz.name
  local bandaz = b and ("#showtooltip " .. b .. "\n/use [@mouseover,help,nodead][help,nodead][@player] " .. b)
    or ("#showtooltip\n" .. warn("brak bandaży. Zrobisz je z Linen Cloth w First Aid (K)."))
  local h, m = best.leczenie and best.leczenie.name, best.mana and best.mana.name
  local mikstura
  if h and m then
    mikstura = "#showtooltip\n/use [mod:shift] " .. m .. "; " .. h
  elseif h then
    mikstura = "#showtooltip " .. h .. "\n/use [nomod:shift] " .. h .. "\n/run if IsShiftKeyDown() then UIErrorsFrame:AddMessage(\"Grimuar: brak mikstury many\", 1, 0.3, 0.3) end"
  elseif m then
    mikstura = "#showtooltip " .. m .. "\n/use [mod:shift] " .. m .. "\n/run if not IsShiftKeyDown() then UIErrorsFrame:AddMessage(\"Grimuar: brak mikstury leczenia\", 1, 0.3, 0.3) end"
  else
    mikstura = "#showtooltip\n" .. warn("brak mikstur w torbach. Leczenie robi First Aid, many kupisz u alchemika.")
  end
  return { Bandaz = bandaz, Mikstura = mikstura, Sledzenie = "#showtooltip Find Herbs\n/run GrimuarSledzenie()" }
end

local pending = false
local function update()
  if InCombatLockdown() then pending = true return end
  pending = false
  for name, body in pairs(bodies(scan())) do
    local idx = GetMacroIndexByName(name)
    if idx == 0 then
      pcall(CreateMacro, name, "INV_MISC_QUESTIONMARK", body, false)
    else
      local _, _, cur = GetMacroInfo(idx)
      if cur ~= body then pcall(EditMacro, idx, nil, nil, body) end
    end
  end
end

-- klawisze raz na konto; zajetych przez Ciebie nie rusza
local function bindKeys()
  if (GrimuarSetupDB.apteczkaV or 0) >= 2 or InCombatLockdown() then return end
  if GetMacroIndexByName("Bandaz") == 0 or GetMacroIndexByName("Mikstura") == 0 or GetMacroIndexByName("Sledzenie") == 0 then return end
  local function nice(key) return (key:gsub("SHIFT%-", "Shift+"):gsub("ALT%-", "Alt+")) end
  local done, busy = {}, {}
  for _, k in ipairs(KEYS) do
    local keys = type(k[1]) == "table" and k[1] or { k[1] }
    local placed, last = false, nil
    for _, key in ipairs(keys) do
      local cur = GetBindingAction(key) or ""
      if cur == k[2] then
        placed = true
      elseif FREE[cur] and pcall(SetBinding, key, k[2]) then
        placed = true
      else
        last = nice(key) .. " (" .. cur .. ")"
      end
      if placed then done[#done + 1] = nice(key) .. " " .. k[3] break end
    end
    if not placed and last then busy[#busy + 1] = last end
  end
  pcall(function() SaveBindings(GetCurrentBindingSet()) end)
  GrimuarSetupDB.apteczkaV = 2
  say("apteczka: " .. table.concat(done, ", ") .. "." .. (#busy > 0 and (" Zajęte, nie ruszam: " .. table.concat(busy, ", ") .. ".") or "") ..
    " Bandaż leczy osobę pod myszką, inaczej Ciebie. Postać i torby dalej pod I i B.")
end

local ev = CreateFrame("Frame")
ev:RegisterEvent("PLAYER_LOGIN")
local queued = false
ev:SetScript("OnEvent", function(_, event)
  if event == "PLAYER_LOGIN" then
    ev:RegisterEvent("BAG_UPDATE_DELAYED")
    ev:RegisterEvent("PLAYER_REGEN_ENABLED")
    ev:RegisterEvent("PLAYER_LEVEL_UP")
    C_Timer.After(6, function() pcall(update) end)
    C_Timer.After(16, function() pcall(bindKeys) end)
  elseif event == "PLAYER_REGEN_ENABLED" then
    if pending then pcall(update) end
    if (GrimuarSetupDB.apteczkaV or 0) < 2 then C_Timer.After(2, function() pcall(bindKeys) end) end
  elseif not queued then
    queued = true
    C_Timer.After(1, function() queued = false pcall(update) end)
  end
end)

G.apteczkaUpdate = update
