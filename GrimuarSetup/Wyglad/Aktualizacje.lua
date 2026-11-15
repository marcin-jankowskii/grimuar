-- Grimuar: aktualizacje addonow (15.11, gracz: „trzeba regularnie wszystkie addony aktualizowac, z ktorych korzystamy”).
-- 1) Gdy zmieni sie wersja addonu, z ktorym Grimuar wspolpracuje (Polestar, Questie, Baganator...), autotest Grimuara
--    rusza sam (jak po aktualizacji Grimuara) i mowi, co sie zmienilo i czy wszystko dziala.
-- 2) Tryb prywatny: Grimuar_Osobiste\Aktualizacje.lua (narzedzie addony.py, co czwartek z Harmonogramu Windows) daje
--    liste addonow z nowsza wersja; Grimuar pokazuje ja raz na sprawdzenie jako karte.
local ADDON_NAME, G = ...

local WATCH = { "Polestar", "Questie", "QuestieDB", "Baganator", "Syndicator", "Auctionator", "GatherMate2", "GatherMate2_Data",
  "ForeverSkin", "ForeverCast", "ForeverDR", "Spy", "Pawn", "Leatrix_Plus", "Leatrix_Maps", "BetterBlizzPlates", "WeakAuras",
  "DBM-Core", "AtlasLootClassic", "Masque" }

local function ver(name)
  local ok, loaded = pcall(C_AddOns.IsAddOnLoaded, name)
  if not (ok and loaded) then return nil end
  local okV, v = pcall(C_AddOns.GetAddOnMetadata, name, "Version")
  return okV and v and tostring(v) or "?"
end

local function changedAddons()
  local old = GrimuarSetupDB.addonVer
  local now, changed = {}, {}
  for _, name in ipairs(WATCH) do
    local v = ver(name)
    if v then
      now[name] = v
      if type(old) == "table" and old[name] and old[name] ~= v then
        changed[#changed + 1] = name .. " " .. old[name] .. " → " .. v
      end
    end
  end
  GrimuarSetupDB.addonVer = now
  return changed
end

local function updateCard()
  local A = type(_G.GrimuarOsobiste) == "table" and GrimuarOsobiste.aktualizacje
  if type(A) ~= "table" or type(A.list) ~= "table" or #A.list == 0 then return end
  if GrimuarSetupDB.aktualizacjeSaid == A.checked then return end
  GrimuarSetupDB.aktualizacjeSaid = A.checked
  local names = {}
  for i, a in ipairs(A.list) do
    if i <= 3 then names[#names + 1] = tostring(a.name) .. " " .. tostring(a.new) end
  end
  local n = #A.list
  local msg = n .. (n == 1 and " addon ma" or (n < 5 and " addony mają" or " addonów ma")) .. " nowszą wersję: " ..
    table.concat(names, ", ") .. (n > 3 and ", …" or "") .. ". Napisz Claude'owi „aktualizuj addony”."
  pcall(G.showToast, msg, "todo", false)
  if G.say then G.say(msg .. " (sprawdzone " .. tostring(A.checked) .. ")") end
end

local ev = CreateFrame("Frame")
ev:RegisterEvent("PLAYER_LOGIN")
ev:SetScript("OnEvent", function()
  -- po autoteście nowej wersji Grimuara (Test.lua, 30 s), zeby nie ruszaly naraz
  C_Timer.After(40, function()
    local changed = changedAddons()
    if #changed > 0 and G.selfTest and not InCombatLockdown() then
      if G.say then G.say("zaktualizowane addony: " .. table.concat(changed, ", ") .. ". Sprawdzam, czy Grimuar dalej z nimi działa…") end
      local ok, nFail = pcall(G.selfTest, false)
      local msg = (ok and nFail == 0) and "Addony po aktualizacji działają z Grimuarem."
        or ("Po aktualizacji addonów: " .. tostring(ok and nFail or "?") .. " problem(y) z Grimuarem. Szczegóły na czacie (/gr test).")
      pcall(G.showToast, msg, "todo", not (ok and nFail == 0))
    end
    if G.personal and G.personal() then
      C_Timer.After(#changed > 0 and 8 or 0, updateCard)
    end
  end)
end)
