-- Grimuar: modul Pomocnik. Drobne pomoce z researchu R5 (12.11, zgoda gracza „zróbmy wszystkie kroki”):
-- 1) wieksza ramka focusa (debuffy z czasem, pod Alt+R i owce),
-- 2) wstega „przed walka”: brak pancerza / Arcane Intellect, malo many, malo wody (tylko poza walka, wartosci jawne),
-- 3) po wizycie u trenera podmiana starszych rang czarow na paskach na najnowsze (tylko poza walka),
-- 4) jednorazowy zapis ustawien gry ze slowem „swing” (wbudowany timer rozdzki), zeby Claude mogl je potem ustawic.
-- Komendy: /rangi (sprawdz rangi teraz), /focusramka (wlacz/wylacz powiekszenie ramki focusa).
local ADDON_NAME, G = ...
local say = G.say

local FOCUS_SCALE = 1.25

-- ---------- 1. ramka focusa ----------
-- focusBase = skala z gry; gdy Edit Mode ustawi inna niz nasza ostatnia, bierzemy ja jako nowa baze (bez mnozenia 2 razy).
local focusBase, lastSet
local function focusFrame()
  if InCombatLockdown() then return end
  local f = _G.FocusFrame
  if not (f and f.SetScale and f.GetScale) then return end
  local cur = f:GetScale() or 1
  if not focusBase or (lastSet and math.abs(cur - lastSet) > 0.001) then focusBase = cur end
  local want = GrimuarSetupDB.focusSmall and focusBase or focusBase * FOCUS_SCALE
  if pcall(f.SetScale, f, want) then lastSet = want end
end

-- ---------- 2. przed walka ----------
local function prePull()
  if InCombatLockdown() or UnitIsDeadOrGhost("player") then return end
  local ok, hostile = pcall(function()
    return UnitExists("target") and UnitCanAttack("player", "target") and not UnitIsDead("target")
  end)
  if not (ok and hostile) then return end
  local issues = {}
  pcall(function()
    local armor = G.knownSpellId("Frost Armor") or G.knownSpellId("Ice Armor") or G.knownSpellId("Mage Armor")
    if armor and not (G.hasAura("Frost Armor") or G.hasAura("Ice Armor") or G.hasAura("Mage Armor")) then
      issues[#issues + 1] = "brak pancerza (8)"
    end
    if G.knownSpellId("Arcane Intellect") and not (G.hasAura("Arcane Intellect") or G.hasAura("Arcane Brilliance")) then
      issues[#issues + 1] = "brak Arcane Intellect (9)"
    end
  end)
  pcall(function()
    local mp, mx = UnitPower("player", 0), UnitPowerMax("player", 0)
    if mx and mx > 0 and mp / mx < 0.4 then
      issues[#issues + 1] = "mana " .. math.floor(mp / mx * 100) .. "%: najpierw się napij (Z)"
    end
  end)
  pcall(function()
    if (UnitLevel("player") or 1) >= 4 and G.knownSpellId("Conjure Water") and G.waterCount and G.waterCount() < 3 then
      issues[#issues + 1] = "mało wody: zrób zapas (0)"
    end
  end)
  if #issues == 0 then return end
  if G.remind then pcall(G.remind, "prepull", "przed walką: " .. table.concat(issues, ", ") .. ".", false, 60) end
end

-- ---------- 3. rangi na paskach ----------
local function spellNameOf(id)
  local nm
  pcall(function()
    if C_Spell and C_Spell.GetSpellName then nm = C_Spell.GetSpellName(id) else nm = GetSpellInfo(id) end
  end)
  return nm
end

local function upgradeRanks(quiet)
  if InCombatLockdown() then return 0 end
  local done, names = 0, {}
  for slot = 1, 120 do
    local ok, kind, id = pcall(GetActionInfo, slot)
    if ok and kind == "spell" and type(id) == "number" then
      local name = spellNameOf(id)
      local best = name and G.knownSpellId(name)
      if best and best ~= id and spellNameOf(best) == name then
        local placed = pcall(function()
          ClearCursor()
          if C_Spell and C_Spell.PickupSpell then C_Spell.PickupSpell(best) else PickupSpell(best) end
          PlaceAction(slot)
          ClearCursor()
        end)
        if placed then
          local _, nowId = GetActionInfo(slot)
          if nowId == best then
            done = done + 1
            if not names[name] then names[name] = true names[#names + 1] = name end
          end
        end
      end
    end
  end
  pcall(ClearCursor)
  if done > 0 then
    if G.remind then pcall(G.remind, "rangi", "na paskach podmieniłem stare rangi na nowe: " .. table.concat(names, ", ") .. ".", false, 5) end
  elseif not quiet then
    say("rangi na paskach są aktualne.")
  end
  return done
end

-- ---------- 4. wbudowany timer rozdzki: zapis nazw ustawien ----------
local function swingScan()
  if GrimuarSetupDB.swingScanV == 1 then return end
  local found = {}
  pcall(function()
    for _, c in ipairs(ConsoleGetAllCommands() or {}) do
      local n = type(c) == "table" and c.command
      if type(n) == "string" and n:lower():find("swing") then
        local v
        pcall(function() v = (C_CVar and C_CVar.GetCVar or GetCVar)(n) end)
        found[#found + 1] = n .. "=" .. tostring(v)
      end
    end
  end)
  local loaded
  pcall(function() loaded = C_AddOns and C_AddOns.IsAddOnLoaded and C_AddOns.IsAddOnLoaded("Blizzard_SwingTimer") end)
  GrimuarSetupDB.swingCVars = found
  GrimuarSetupDB.swingLoaded = loaded and true or false
  GrimuarSetupDB.swingScanV = 1
end

local ev = CreateFrame("Frame")
ev:RegisterEvent("PLAYER_LOGIN")
ev:SetScript("OnEvent", function(_, event)
  if event == "PLAYER_LOGIN" then
    ev:RegisterEvent("PLAYER_TARGET_CHANGED")
    ev:RegisterEvent("TRAINER_CLOSED")
    ev:RegisterEvent("EDIT_MODE_LAYOUTS_UPDATED")
    ev:RegisterEvent("PLAYER_REGEN_ENABLED")
    C_Timer.After(7, function() pcall(focusFrame) end)
    C_Timer.After(16, function() pcall(swingScan) end)
    C_Timer.After(20, function() pcall(upgradeRanks, true) end)
  elseif event == "PLAYER_TARGET_CHANGED" then
    pcall(prePull)
  elseif event == "TRAINER_CLOSED" then
    C_Timer.After(0.6, function() pcall(upgradeRanks, true) end)
  elseif event == "EDIT_MODE_LAYOUTS_UPDATED" then
    C_Timer.After(0.5, function() pcall(focusFrame) end)
  elseif event == "PLAYER_REGEN_ENABLED" then
    pcall(focusFrame)
  end
end)

SLASH_GRIMUARRANGI1 = "/rangi"
SlashCmdList["GRIMUARRANGI"] = function()
  if InCombatLockdown() then say("rangi sprawdzę po walce.") return end
  upgradeRanks(false)
end

SLASH_GRIMUARFOCUSRAMKA1 = "/focusramka"
SlashCmdList["GRIMUARFOCUSRAMKA"] = function()
  GrimuarSetupDB.focusSmall = not GrimuarSetupDB.focusSmall
  focusFrame()
  say("ramka focusa: " .. (GrimuarSetupDB.focusSmall and "zwykła" or "powiększona") .. ".")
end

G.upgradeRanks = upgradeRanks
G.prePull = prePull
