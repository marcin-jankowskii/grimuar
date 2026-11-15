-- Grimuar: modul Rozwoj (gracz 14.11: „wszystko, co zwiazane z rozwojem: jak broni nie zmienilem mimo lvla itp.,
-- powinno na mnie krzyczec”). Sprawdza rozwoj postaci i alarmuje (czat + wstega) po wejsciu do gry, przy awansie i co
-- 10 minut, dopoki tego nie zalatwisz:
--   * czary z planu Frosta u trenera (Engine.lua missingTraining, dane trenera Forever z Polestara),
--   * puste miejsca na torby (Vendor.lua emptyBagSlots),
--   * niewydane punkty talentow (od 10 poziomu),
--   * bron za slaba na poziom (wyzszy z: wymagany poziom, poziom przedmiotu - 5; o 5+ nizej) albo pusty slot broni,
--   * brak rozdzki (slot Ranged pusty: strzal rozdzka pod G nie dziala),
--   * lepszy sprzet w torbach (Pawn: ta sama strzalka, ktora pokazuje Baganator).
-- Kazda rzecz ma krok w planie z Prowadz (Kroki.lua wola G.rozwojSteps; czary, torby i talenty maja juz swoje kroki).
local ADDON_NAME, G = ...
local say = G.say

local SLOT_MAIN, SLOT_RANGED = 16, 18
local WEAPON_GAP = 5
local REPEAT = 600 -- co ile sekund przypominac, dopoki cos zostaje

local function itemInfo(link)
  local i = { C_Item.GetItemInfo(link) }
  return i[1], tonumber(i[4]) or 0, tonumber(i[5]) or 1
end

-- problemy ze sprzetem: { key, short (do wstegi), text, why }
local function gearIssues()
  local l = UnitLevel("player") or 1
  local out = {}
  local main = GetInventoryItemLink("player", SLOT_MAIN)
  if not main then
    out[#out + 1] = { key = "weapon", short = "broń: brak", text = "Załóż broń: slot głównej ręki jest pusty.",
      why = "Bez broni nie masz Intelektu z laski. Najszybciej: nagroda z questu (Polestar podpowiada), inaczej dom aukcyjny." }
  else
    -- 14.11 (gracz: „zmienilem na staffa z questa, a dalej pokazuje, ze mam na poziom 0”): bron z nagrody za quest
    -- czesto nie ma wymaganego poziomu (0), choc jest na swoj poziom. Ocena: wyzszy z (wymagany poziom,
    -- poziom przedmiotu); sam wymagany poziom alarmowal przy dobrej broni.
    local name, ilvl, req = itemInfo(main)
    local eff = math.max(req or 0, ilvl or 0) -- poziom przedmiotu ~ poziom, na ktory jest bron (quest na 10 = przedmiot 10)
    if name and l - eff >= WEAPON_GAP then
      out[#out + 1] = { key = "weapon", short = "broń słaba (" .. name .. ")",
        text = "Twoja broń (" .. name .. ", przedmiot poziomu " .. (ilvl or "?") .. ") jest za słaba na poziom " .. l .. ".",
        why = "Szukaj laski albo sztyletu z Intellect i Spirit: nagroda z questu (zadania etapu Grimuara i Polestar) albo dom aukcyjny. Pawn pokaże zieloną strzałkę na lepszej." }
    end
  end
  local _, class = UnitClass("player")
  if class == "MAGE" and l >= 5 and not GetInventoryItemLink("player", SLOT_RANGED) then
    -- 14.11 R22: Windbough Wand (Zephras Isle) odpada: dla gnoma 45-75 min w jedna strone przez Menethil, Southshore
    -- i Dalaran (sporny Hillsbrad), 5-7 DPS, a czy gnom dostanie quest, nie wiadomo. Zamiast tego Deepblaze (Forever,
    -- 22-41 / 1.7 s, ok. 18 DPS, od 1 poziomu) za „Old Ironforge Incursion” (od 9, Hall of Thanes z grupa); przewodnik
    -- Grimuara w Polestarze (Trasa.lua). Do lochu: Lesser Magic Wand z domu aukcyjnego, gdy starczy pieniedzy.
    if l >= 9 then
      out[#out + 1] = { key = "wand", short = "różdżka: Deepblaze (Hall of Thanes)",
        text = "Zdobądź różdżkę Deepblaze: quest „Old Ironforge Incursion” (Earthseer Farsen, Dun Morogh), finał w lochu Hall of Thanes z grupą.",
        why = "Slot Ranged jest pusty, więc strzał różdżką (G) nie działa. Deepblaze to niebieska różdżka, ok. 18 obrażeń na sekundę, bez many. Karta „Hall of Thanes” w Polestarze prowadzi krok po kroku. Do czasu lochu: Lesser Magic Wand z domu aukcyjnego (Rynek > Różdżki), jeśli Cię stać.",
        polestar = "grimuar/hall-of-thanes" }
    else
      out[#out + 1] = { key = "wand", short = "różdżka: brak (od 9 quest na Deepblaze)",
        text = "Różdżki jeszcze nie masz: od 9 poziomu quest „Old Ironforge Incursion” daje Deepblaze (loch Hall of Thanes z grupą).",
        why = "Do tego czasu: Lesser Magic Wand z domu aukcyjnego w Ironforge (Rynek > Różdżki), gdy starczy pieniędzy. Zephras Isle (Windbough Wand) nie warto: daleko przez strefę PvP i różdżka słabsza." }
    end
  end
  local ups = {}
  if PawnShouldItemLinkHaveUpgradeArrow and C_Container then
    for bag = 0, (NUM_BAG_SLOTS or 4) do
      for slot = 1, (C_Container.GetContainerNumSlots(bag) or 0) do
        local link = C_Container.GetContainerItemLink(bag, slot)
        if link then
          local ok, up = pcall(PawnShouldItemLinkHaveUpgradeArrow, link, true)
          if ok and up then ups[#ups + 1] = (itemInfo(link)) or link end
        end
      end
    end
  end
  if #ups > 0 then
    out[#out + 1] = { key = "upgrade", short = "lepszy sprzęt w torbie", text = "Załóż lepszy sprzęt z torby: " .. table.concat(ups, ", ") .. ".",
      why = "Pawn liczy go jako lepszy dla Frosta (zielona strzałka w torbie). Prawy klik na przedmiot zakłada go." }
  end
  return out
end

-- krotkie hasla do wstegi: wszystko, co czeka
local function shorts()
  local list = {}
  local l = UnitLevel("player") or 1
  local miss = G.missingTraining and G.missingTraining() or {}
  if #miss > 0 then list[#list + 1] = "trener: " .. table.concat(miss, ", ") end
  local bags = G.emptyBagSlots and G.emptyBagSlots() or 0
  if bags > 0 then list[#list + 1] = "torby: " .. bags .. " " .. (bags == 1 and "puste miejsce" or "puste miejsca") end
  local pts = 0
  pcall(function() pts = G.talentPoints and G.talentPoints() or 0 end)
  if l >= 10 and pts > 0 then list[#list + 1] = "talenty: " .. pts .. " " .. (pts == 1 and "punkt" or "punkty") end
  for _, it in ipairs(gearIssues()) do list[#list + 1] = it.short end
  return list
end

local function alert(force)
  if InCombatLockdown() then return end
  local ok, list = pcall(shorts)
  if not ok or #list == 0 then return end
  local msg = "Rozwój: " .. table.concat(list, " · ") .. ". Kroki z Prowadź masz w planie Grimuara."
  say(msg)
  pcall(G.showBanner, msg, "plan", false)
  if force and G.playCue then pcall(G.playCue, "plan") end
end

-- kroki do planu (Kroki.lua): sprzet; prowadzenie do domu aukcyjnego albo okno postaci
local function steps(add)
  local ok, list = pcall(gearIssues)
  if not ok then return end
  for _, it in ipairs(list) do
    local btns
    if it.key == "upgrade" then
      btns = { { "Torby", function() pcall(function() Baganator.CallbackRegistry:TriggerEvent("BagShow") end) end } }
    elseif it.polestar then
      local id = it.polestar
      btns = { { "Otwórz w Polestarze", function() pcall(function() Polestar.Engine.OpenTab(id, true) end) end } }
    elseif it.guide then
      local g = it.guide
      btns = { { "Prowadź", function() pcall(G.wayTo, g[1], g[2], g[3], g[4]) end } }
    else
      btns = { { "Prowadź", function() pcall(G.guideAH) end } }
    end
    add("rozwoj-" .. it.key, it.text, it.why, btns)
  end
end

local ev = CreateFrame("Frame")
ev:RegisterEvent("PLAYER_LOGIN")
ev:RegisterEvent("PLAYER_LEVEL_UP")
ev:SetScript("OnEvent", function(_, event)
  if event == "PLAYER_LOGIN" then
    C_Timer.After(30, function() pcall(alert, false) end)
    C_Timer.NewTicker(REPEAT, function() pcall(alert, false) end)
  else
    C_Timer.After(4, function() pcall(alert, true) end)
  end
end)

G.rozwojSteps = steps
G.rozwojAlert = alert
