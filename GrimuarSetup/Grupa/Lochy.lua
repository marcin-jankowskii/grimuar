-- Grimuar: modul Lochy. Wnioski z researchu R7 (12.11): lista „przed lochem”, gdy jestes w grupie (pasek Grimuara),
-- 6 zasad maga w grupie po wejsciu do lochu (raz na loch) i /loch z calym zestawem. Bez Dungeon Findera w Forever
-- grupe zbierasz recznie (okno LFG albo czat), wiec lista pokazuje sie po dolaczeniu do grupy, jeszcze przed wejsciem.
local ADDON_NAME, G = ...
local say = G.say

local RULES = {
  "Zaczynaj 2–3 s po tanku i bij cel z czaszką. Threat blisko tanka (pasek Threat)? Przejdź na różdżkę (G).",
  "Księżyc to Twoja owca: przed pullem Alt+R na mobie z księżycem, potem R. Nie rzucaj Novy ani AoE obok owcy.",
  "AoE tylko na znak tanka i gdy healer wie.",
  "Przed wejściem: woda i jedzenie dla grupy (healer pierwszy), Arcane Intellect na wszystkich (trwa godzinę).",
  "Klątwy zdejmujesz Ty (Remove Lesser Curse od 18). F przerywa leczenie i strach u mobów (od 24).",
  "Need tylko na to, co założysz od razu. Kostury, różdżki i tkaniny ustal z kapłanem i warlockiem przed pierwszym bossem.",
}

local dismissed = false
local shownFor = {}

local function inParty()
  local ok, r = pcall(function() return IsInGroup() and not IsInRaid() end)
  return ok and r
end

local function inDungeon()
  local ok, inst, kind = pcall(IsInInstance)
  return ok and inst and kind == "party"
end

local function wandEquipped()
  local id
  pcall(function() id = GetInventoryItemID("player", 18) end)
  return id ~= nil
end

-- Lista problemow przed lochem: { text, why, btn }
local function prep()
  local out = {}
  local function add(text, why, btn) out[#out + 1] = { text = text, why = why, btn = btn } end
  pcall(function()
    if G.knownSpellId("Conjure Water") and G.waterCount then
      local w = G.waterCount()
      if w < 40 then add("Zrób wodę: 2 stacki dla siebie i 1 dla healera (masz " .. w .. ").", "Klawisz 0 tworzy wodę. W lochu nie ma czasu na robienie zapasu.") end
    end
  end)
  pcall(function()
    local d = G.minDurability and G.minDurability()
    if d and d < 60 then
      add("Napraw sprzęt przed lochem (zużycie " .. math.floor(100 - d) .. "%).", "Śmierć w lochu dodatkowo psuje sprzęt.",
        { "Do naprawy", function() pcall(G.guideVendor, true) end })
    end
  end)
  pcall(function()
    local f = G.freeBagSlots and G.freeBagSlots()
    if f and f < 6 then
      add("Zrób miejsce w torbach: co najmniej 6 wolnych (masz " .. f .. ").", "Na łupy z bossów i questowe przedmioty.",
        { "Do kupca", function() pcall(G.guideVendor, false) end })
    end
  end)
  if not wandEquipped() then add("Załóż różdżkę.", "Różdżka dobija moby bez many, w lochu bardzo się przydaje.") end
  pcall(function()
    if (UnitLevel("player") or 1) >= 10 and G.talentPoints and G.talentPoints() > 0 then
      add("Rozdaj punkty talentów (N).", "Talenty to darmowa moc.", { "Talenty", function() pcall(G.openTalents) end })
    end
  end)
  pcall(function()
    local miss = G.missingTraining and G.missingTraining() or {}
    if #miss > 0 then add("Kup u trenera: " .. table.concat(miss, ", ") .. ".", "Nowe rangi to więcej obrażeń.",
      { "Prowadź", function() pcall(G.guideTrainer) end }) end
  end)
  pcall(function()
    if G.knownSpellId("Arcane Intellect") and not (G.hasAura("Arcane Intellect") or G.hasAura("Arcane Brilliance")) then
      add("Rzuć Arcane Intellect na siebie i grupę (9).", "Trwa godzinę, więcej many dla wszystkich casterów.")
    end
  end)
  return out
end

-- R12: przed raidem (grupa rajdowa, jeszcze poza instancja)
local function raidPrep()
  local out = {}
  local function add(text, why, btn) out[#out + 1] = { text = text, why = why, btn = btn } end
  pcall(function()
    local d = G.minDurability and G.minDurability()
    if d and d < 95 then add("Napraw sprzęt do 100% (zużycie " .. math.floor(100 - d) .. "%).", "W raidzie każdy wipe dodatkowo psuje sprzęt.",
      { "Do naprawy", function() pcall(G.guideVendor, true) end }) end
  end)
  pcall(function()
    if G.knownSpellId("Arcane Brilliance") and GetItemCount(17020) < 10 then
      add("Kup Arcane Powder (masz " .. GetItemCount(17020) .. ").", "Arcane Brilliance na cały raid zużywa proszek. Sprzedaje go sprzedawca reagentów.")
    end
  end)
  pcall(function()
    local loaded = C_AddOns and C_AddOns.IsAddOnLoaded and C_AddOns.IsAddOnLoaded("DBM-Core")
    if not loaded then add("Włącz DBM (ostrzeżenia na bossach).", "Esc > AddOns > DBM, potem /reload.") end
  end)
  pcall(function()
    if LoggingCombat and not LoggingCombat() then add("Włącz zapis walki: wpisz /combatlog.", "Logi wrzucisz na foreverlogs.gg i zobaczysz, co poprawić.") end
  end)
  pcall(function()
    if G.knownSpellId("Conjure Water") and G.waterCount and G.waterCount() < 40 then add("Zrób wodę na raid (masz " .. G.waterCount() .. ").", "Klawisz 0. W raidzie nie ma czasu na robienie zapasu.") end
  end)
  return out
end

local function groupSteps(add)
  if not dismissed and IsInRaid and IsInRaid() and not inDungeon() then
    local list = raidPrep()
    local it = list[1]
    if it then
      local btns = {}
      if it.btn then btns[#btns + 1] = it.btn end
      btns[#btns + 1] = { "Gotowe", function() dismissed = true if G.refreshAll then pcall(G.refreshAll) end end }
      add("loch-raid", "Przed raidem: " .. it.text, it.why .. " Eliksiry, jedzenie +SP i Drakefire Amulet (Onyxia): okno Grimuara, Postać > Do 60.", btns, nil,
        (#list > 1) and ("1 z " .. #list) or nil)
    end
    return
  end
  if dismissed or not inParty() or inDungeon() then return end
  if (UnitLevel("player") or 1) < 13 then return end
  local list = prep()
  if #list == 0 then return end
  local it = list[1]
  local btns = {}
  if it.btn then btns[#btns + 1] = it.btn end
  btns[#btns + 1] = { "Gotowe", function()
    dismissed = true
    if G.refreshAll then pcall(G.refreshAll) end
  end }
  add("loch-prep", "Przed lochem: " .. it.text,
    it.why .. " Questy do lochu weź wcześniej, a na serwerze PvP zbierzcie się w mieście, nie przy wejściu.", btns, nil,
    (#list > 1) and ("1 z " .. #list) or nil)
end

local function sayRules()
  say("zasady maga w grupie:")
  for i, r in ipairs(RULES) do say("  " .. i .. ". " .. r) end
end

local function report()
  local l = UnitLevel("player") or 1
  local dg = G.bestDungeon and G.bestDungeon(l)
  if dg then say("loch na Twój poziom: " .. dg[3] .. " (" .. dg[1] .. "–" .. dg[2] .. "): " .. dg[4] .. ".") end
  local list = prep()
  if #list == 0 then say("przed lochem: wszystko gotowe.") else
    say("przed lochem zostało:")
    for i, it in ipairs(list) do say("  " .. i .. ". " .. it.text) end
  end
  sayRules()
end

local ev = CreateFrame("Frame")
ev:RegisterEvent("GROUP_ROSTER_UPDATE")
ev:RegisterEvent("PLAYER_ENTERING_WORLD")
ev:SetScript("OnEvent", function(_, event)
  if event == "GROUP_ROSTER_UPDATE" then
    if not inParty() and not (IsInRaid and IsInRaid()) then dismissed = false end
    if G.refreshAll then pcall(G.refreshAll) end
  elseif event == "PLAYER_ENTERING_WORLD" then
    if inDungeon() then
      local name = GetInstanceInfo and GetInstanceInfo() or "loch"
      if not shownFor[name] then
        shownFor[name] = true
        C_Timer.After(3, function()
          pcall(sayRules)
          pcall(G.showToast, "zasady maga w grupie są w czacie. Księżyc to Twoja owca, AoE tylko na znak tanka.", "dng", false)
        end)
      end
    end
  end
end)

SLASH_GRIMUARLOCH1 = "/loch"
SlashCmdList["GRIMUARLOCH"] = function() report() end

G.groupSteps = groupSteps
G.dungeonPrep = prep -- 14.11 (R26): ta sama lista w hubie (GrimuarUI WyprawyDane.lua)
