-- Grimuar: pilnowanie lokalnej laty ForeverSkin w kolorach Grimuara (zgoda gracza 15.11: „Latka ForeverSkin”).
-- Latka (gaming-warsztat/wow/grimuar/narzedzia/latka_foreverskin.py) zmienia palete i tytuly okien ForeverSkin i ustawia
-- globalna flage GRIMUAR_FSS_LATKA. Aktualizacja ForeverSkin ja nadpisuje: wtedy raz na wersje ForeverSkin przypomnienie.
-- Tylko tryb prywatny (Grimuar_Osobiste): publiczny Grimuar nie rozdaje zmian cudzego addonu.
local ADDON_NAME, G = ...

local ev = CreateFrame("Frame")
ev:RegisterEvent("PLAYER_LOGIN")
ev:SetScript("OnEvent", function()
  C_Timer.After(12, function()
    if not (G.personal and G.personal()) then return end
    local ok, loaded = pcall(C_AddOns.IsAddOnLoaded, "ForeverSkin")
    if not (ok and loaded) or GRIMUAR_FSS_LATKA then return end
    local ver = C_AddOns.GetAddOnMetadata and C_AddOns.GetAddOnMetadata("ForeverSkin", "Version") or "?"
    if GrimuarSetupDB.fssLatkaSaid == ver then return end
    GrimuarSetupDB.fssLatkaSaid = ver
    if G.say then G.say("ForeverSkin " .. tostring(ver) .. " bez łatki kolorów Grimuara (aktualizacja ją nadpisała). Poproś o ponowne nałożenie: narzedzia/latka_foreverskin.py.") end
  end)
end)
