-- Grimuar: modul Vendor. Przycisk "najblizszy kupiec": lista NPC z bazy Questie, odleglosc liczona
-- przez Questie (DistanceUtils), strzalka przez G.wayTo. Szare rzeczy sprzedaje, a sprzet naprawia
-- Leatrix Plus (AutoSellJunk, AutoRepairGear), gdy otworzysz okno kupca.
local ADDON_NAME, G = ...
local say = G.say
local C_GOLD = G.C_GOLD
local C_MUTED = G.C_MUTED

local VENDOR_KEYS = { "Food", "Drink", "Trade Goods", "Bags", "Reagents" }
local KEYS_TRY = { "SHIFT-V", "ALT-V", "CTRL-V" }

local function questieModules()
  if not QuestieLoader then return nil end
  local ok, QDB, DU, ZDB = pcall(function()
    return QuestieLoader:ImportModule("QuestieDB"), QuestieLoader:ImportModule("DistanceUtils"),
      QuestieLoader:ImportModule("ZoneDB")
  end)
  if ok and QDB and DU and ZDB and QDB.QueryNPCSingle and DU.GetNearestSpawn and ZDB.GetUiMapIdByAreaId then
    return QDB, DU, ZDB
  end
  return nil
end

local function addIds(ids, list, kind)
  for k, v in pairs(list or {}) do
    local id = type(v) == "number" and v or k
    if type(id) == "number" and not ids[id] then ids[id] = kind end
  end
end

-- Kandydaci: naprawa (kupiec z kowadlem), karczmarze i kupcy jedzenia, picia, towarow, toreb.
-- mode: nil = kazdy kupiec, true = tylko naprawa, "inn" = tylko karczmarze.
local function candidates(mode)
  local ids = {}
  local char = Questie and Questie.db and Questie.db.char
  if type(char) ~= "table" then return ids end
  local tf, vl = char.townsfolk or {}, char.vendorList or {}
  -- 13.11: Questie 12.6 trzyma karczmarzy i naprawe w module Townsfolk (jak QuestieMenu), a w char tylko frakcje i klasy
  local town = {}
  pcall(function() town = QuestieLoader:ImportModule("Townsfolk").townsfolk or {} end)
  local function list(key) return town[key] or tf[key] end
  if mode == "inn" then
    addIds(ids, list("Innkeeper"), "karczmarz")
    return ids
  end
  if mode == "bags" then -- 14.11: kupcy z torbami (Questie: Small Brown Pouch, Heavy Brown Bag, Brown Leather Satchel...)
    addIds(ids, vl["Bags"], "torby")
    return ids
  end
  if mode == "ah" then -- 14.11: aukcjonerzy (Rozwoj.lua: bron, rozdzka)
    addIds(ids, list("Auctioneer"), "dom aukcyjny")
    return ids
  end
  addIds(ids, list("Repair"), "naprawa")
  if not mode then
    addIds(ids, list("Innkeeper"), "karczmarz")
    for _, key in ipairs(VENDOR_KEYS) do addIds(ids, vl[key], "kupiec") end
  end
  return ids
end

local function findNearest(mode)
  local QDB, DU, ZDB = questieModules()
  if not QDB then return nil, "noquestie" end
  local ids = candidates(mode)
  if next(ids) == nil then return nil, "empty" end
  local fac = UnitFactionGroup("player") == "Horde" and "H" or "A"
  local best
  for id, kind in pairs(ids) do
    pcall(function()
      local f = QDB.QueryNPCSingle(id, "friendlyToFaction")
      if f and f ~= "AH" and f ~= fac then return end
      local spawns = QDB.QueryNPCSingle(id, "spawns")
      if type(spawns) ~= "table" then return end
      local sp, zone, dist = DU.GetNearestSpawn(spawns)
      -- ponad 500000 = inny kontynent (tak liczy Questie)
      if sp and zone and dist and dist < 500000 and sp[1] and sp[1] >= 0 and (not best or dist < best.dist) then
        best = { id = id, kind = kind, x = sp[1], y = sp[2], zone = zone, dist = dist }
      end
    end)
  end
  if not best then return nil, "far" end
  pcall(function()
    best.name = QDB.QueryNPCSingle(best.id, "name")
    best.sub = QDB.QueryNPCSingle(best.id, "subName")
    best.map = ZDB:GetUiMapIdByAreaId(best.zone)
  end)
  return best
end

local function round2(v) return math.floor(v * 100 + 0.5) / 100 end

local function bindKey()
  return GrimuarSetupDB and GrimuarSetupDB.vendorKey
end

local function guideVendor(repairOnly)
  local v, why = findNearest(repairOnly)
  if not v then
    if why == "noquestie" then
      say("nie widzę bazy Questie. Włącz addon Questie (Esc > AddOns) i wpisz /reload.")
    elseif why == "empty" then
      say("Questie jeszcze wczytuje listę kupców. Spróbuj za kilka sekund.")
    else
      say("na tym kontynencie nie znalazłem kupca. Wróć kamieniem (Hearthstone) do karczmy i sprzedaj u karczmarza.")
    end
    return false
  end
  if not v.map then
    say("znalazłem kupca " .. (v.name or "?") .. ", ale bez mapy do strzałki. Sprawdź go na mapie M (ikony Questie).")
    return false
  end
  local label = (v.name or "kupiec") .. ((v.sub and v.sub ~= "") and (" <" .. v.sub .. ">") or "")
  local m = math.floor(v.dist * 0.9144 + 0.5)
  G.wayTo(v.map, round2(v.x), round2(v.y), label)
  GrimuarSetupDB.vendorGuided = true
  local fix = v.kind == "naprawa" and " i naprawi sprzęt" or ""
  local msg = "najbliższy kupiec: " .. label .. ", ok. " .. m .. " m. Kliknij go prawym przyciskiem myszy: Leatrix sam sprzeda szare rzeczy" .. fix .. "."
  pcall(G.showToast, msg, "bags", false)
  return true
end

-- 14.11 (gracz: „bagow nie mam kupionych, powinno mnie zawsze prowadzic, to wazne rzeczy”): puste miejsca na torby
-- (torby 1-4 bez torby) i prowadzenie do najblizszego kupca, ktory sprzedaje torby.
local function emptyBagSlots()
  local n = 0
  for bag = 1, (NUM_BAG_SLOTS or 4) do
    local slots = 0
    pcall(function() slots = (C_Container and C_Container.GetContainerNumSlots or GetContainerNumSlots)(bag) or 0 end)
    if slots == 0 then n = n + 1 end
  end
  return n
end

local function guideBags()
  local v, why = findNearest("bags")
  if not v or not v.map then
    if why == "empty" then say("Questie jeszcze wczytuje listę kupców. Spróbuj za kilka sekund.") return false end
    say("nie znalazłem kupca z torbami na tym kontynencie. Torby kupisz też w domu aukcyjnym (Ironforge).")
    return false
  end
  local label = "torby: " .. (v.name or "kupiec") .. ((v.sub and v.sub ~= "") and (" <" .. v.sub .. ">") or "")
  G.wayTo(v.map, round2(v.x), round2(v.y), label)
  local m = math.floor(v.dist * 0.9144 + 0.5)
  pcall(G.showToast, "kupiec z torbami: " .. (v.name or "?") .. ", ok. " .. m .. " m. Najtańsza: Small Brown Pouch (6 miejsc). Większe: dom aukcyjny.", "bags", false)
  return true
end

local function guideAH()
  local v, why = findNearest("ah")
  if not v or not v.map then
    if why == "empty" then say("Questie jeszcze wczytuje listę aukcjonerów. Spróbuj za kilka sekund.") return false end
    say("nie znalazłem domu aukcyjnego na tym kontynencie. Najbliższy dla Ciebie: Ironforge (Hearthstone albo pieszo z Dun Morogh).")
    return false
  end
  G.wayTo(v.map, round2(v.x), round2(v.y), "dom aukcyjny: " .. (v.name or "aukcjoner"))
  return true
end

-- Najblizsza karczma: tam wylogowanie nalicza rested XP, a karczmarz przypisuje Hearthstone.
local function guideInn()
  local v, why = findNearest("inn")
  if not v or not v.map then
    if why == "noquestie" then
      say("nie widzę bazy Questie. Włącz addon Questie i wpisz /reload.")
    else
      say("nie znalazłem karczmy na tym kontynencie. Użyj Hearthstone: przeniesie Cię do Twojej karczmy.")
    end
    return false
  end
  local label = (v.name or "karczmarz") .. " <Innkeeper>"
  local m = math.floor(v.dist * 0.9144 + 0.5)
  G.wayTo(v.map, round2(v.x), round2(v.y), label)
  pcall(G.showToast, "najbliższa karczma: " .. label .. ", ok. " .. m .. " m. Wyloguj się w środku, a naliczy się rested XP (szybszy level przy następnej sesji).", "budget", false)
  return true
end

-- ---------- miejsce w torbach ----------
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

-- ---------- przycisk ----------
local btn

local function savePos(self)
  local p, _, rp, x, y = self:GetPoint(1)
  GrimuarSetupDB.vendorPos = { p, rp, math.floor(x + 0.5), math.floor(y + 0.5) }
end

local function placeButton()
  btn:ClearAllPoints()
  local pos = GrimuarSetupDB.vendorPos
  if type(pos) == "table" and pos[1] then
    btn:SetPoint(pos[1], UIParent, pos[2], pos[3], pos[4])
    return
  end
  -- nad plecakiem (13.11, Ekran v6: torby nad menu w prawym dolnym rogu)
  local bags = _G.BagsBar
  if bags and bags.IsShown and bags:IsShown() then
    btn:SetPoint("BOTTOMRIGHT", bags, "TOPRIGHT", 0, 8)
  else
    btn:SetPoint("BOTTOMRIGHT", UIParent, "BOTTOMRIGHT", -330, 8)
  end
end

local function updateButton()
  if not btn then return end
  local free = freeBagSlots()
  btn.count:SetText(tostring(free))
  if free <= 2 then
    btn.count:SetTextColor(0.94, 0.54, 0.44)
    if not btn.pulse:IsPlaying() then btn.glow:Show() btn.pulse:Play() end
  else
    if free <= 5 then btn.count:SetTextColor(0.85, 0.71, 0.36) else btn.count:SetTextColor(0.93, 0.91, 0.86) end
    btn.pulse:Stop()
    btn.glow:Hide()
  end
end

local function createVendorButton()
  if btn then return end
  btn = CreateFrame("Button", "GrimuarVendorButton", UIParent, "BackdropTemplate")
  btn:SetSize(36, 36)
  btn:SetFrameStrata("MEDIUM")
  btn:SetFrameLevel(50)
  btn:SetClampedToScreen(true)
  btn:SetMovable(true)
  btn:RegisterForClicks("LeftButtonUp", "RightButtonUp")
  btn:RegisterForDrag("LeftButton")
  G.setBackdrop(btn, G.STYLE.btn, G.STYLE.gold)
  local ic = btn:CreateTexture(nil, "ARTWORK")
  ic:SetTexture("Interface\\Icons\\INV_Misc_Coin_01")
  ic:SetTexCoord(0.08, 0.92, 0.08, 0.92)
  ic:SetPoint("TOPLEFT", btn, "TOPLEFT", 2, -2)
  ic:SetPoint("BOTTOMRIGHT", btn, "BOTTOMRIGHT", -2, 2)
  btn.count = btn:CreateFontString(nil, "OVERLAY")
  btn.count:SetFont(G.FONT, 13, "OUTLINE")
  btn.count:SetPoint("BOTTOMRIGHT", btn, "BOTTOMRIGHT", -2, 2)
  btn.glow = CreateFrame("Frame", nil, btn, "BackdropTemplate")
  btn.glow:SetPoint("TOPLEFT", btn, "TOPLEFT", -3, 3)
  btn.glow:SetPoint("BOTTOMRIGHT", btn, "BOTTOMRIGHT", 3, -3)
  pcall(function()
    btn.glow:SetBackdrop({ edgeFile = "Interface\\Buttons\\WHITE8X8", edgeSize = 3 })
    btn.glow:SetBackdropBorderColor(0.94, 0.54, 0.44, 1)
  end)
  local ag = btn.glow:CreateAnimationGroup()
  local an = ag:CreateAnimation("Alpha")
  an:SetFromAlpha(1)
  an:SetToAlpha(0.15)
  an:SetDuration(0.5)
  ag:SetLooping("BOUNCE")
  btn.pulse = ag
  btn.glow:Hide()
  btn:SetScript("OnClick", function(_, mb) guideVendor(mb == "RightButton") end)
  btn:SetScript("OnDragStart", function(self) if IsShiftKeyDown() then self:StartMoving() end end)
  btn:SetScript("OnDragStop", function(self)
    self:StopMovingOrSizing()
    savePos(self)
  end)
  btn:SetScript("OnEnter", function(self)
    GameTooltip:SetOwner(self, "ANCHOR_TOP")
    GameTooltip:AddLine("Najbliższy kupiec", 0.85, 0.71, 0.36)
    GameTooltip:AddLine("Klik: strzałka do najbliższego kupca. Prawy klik: tylko kupiec z naprawą.", 0.93, 0.91, 0.86, true)
    GameTooltip:AddLine("Liczba na przycisku: wolne miejsca w torbach. Miga na czerwono, gdy zostają 2 lub mniej.", 0.6, 0.63, 0.69, true)
    GameTooltip:AddLine("U kupca Leatrix sam sprzeda szare rzeczy i naprawi sprzęt.", 0.6, 0.63, 0.69, true)
    if bindKey() then GameTooltip:AddLine("Klawisz: " .. bindKey(), 0.37, 0.8, 0.94) end
    GameTooltip:AddLine("Shift + przeciągnij: przesuń przycisk.", 0.6, 0.63, 0.69)
    GameTooltip:Show()
  end)
  btn:SetScript("OnLeave", function() GameTooltip:Hide() end)
  placeButton()
  updateButton()
end

-- Klawisz: pierwszy wolny z KEYS_TRY, raz na konto.
local function bindVendorKey()
  if GrimuarSetupDB.vendorKey or InCombatLockdown() then return end
  for _, key in ipairs(KEYS_TRY) do
    local cur = GetBindingAction(key)
    if cur == nil or cur == "" then
      local ok = pcall(SetBindingClick, key, "GrimuarVendorButton", "LeftButton")
      if ok then
        pcall(function() SaveBindings(GetCurrentBindingSet()) end)
        GrimuarSetupDB.vendorKey = key:gsub("SHIFT%-", "Shift+"):gsub("ALT%-", "Alt+"):gsub("CTRL%-", "Ctrl+")
        say("nowy przycisk z monetą obok toreb prowadzi do najbliższego kupca. Klawisz: " .. GrimuarSetupDB.vendorKey .. ".")
        return
      end
    end
  end
end

-- ---------- zdarzenia ----------
local ev = CreateFrame("Frame")
ev:RegisterEvent("PLAYER_LOGIN")
ev:RegisterEvent("BAG_UPDATE_DELAYED")
ev:RegisterEvent("MERCHANT_SHOW")
ev:SetScript("OnEvent", function(_, event)
  if event == "PLAYER_LOGIN" then
    C_Timer.After(4, function()
      pcall(createVendorButton)
      pcall(bindVendorKey)
    end)
  elseif event == "BAG_UPDATE_DELAYED" then
    pcall(updateButton)
  elseif event == "MERCHANT_SHOW" then
    GrimuarSetupDB.vendorGuided = nil
    C_Timer.After(1.5, function()
      pcall(updateButton)
      if freeBagSlots() <= 2 then
        pcall(G.remind, "bagsAfter", "torby dalej pełne. Sprzedaj białe rzeczy, których nie potrzebujesz: prawy klik na przedmiot w torbie, gdy okno kupca jest otwarte.", false, 600)
      end
    end)
  end
end)

-- ---------- oddawanie questow (gracz 13.11: „tu tez brakuje prowadzenia”) ----------
-- Gotowe questy z dziennika, kto je przyjmuje (Questie: finishedBy = { NPC, obiekty }), najblizsze miejsce;
-- strzalka przez G.wayTo. Kolejne klikniecie prowadzi do nastepnego, gdy pierwszy juz oddany.
local function readyQuests()
  local list = {}
  pcall(function()
    for i = 1, C_QuestLog.GetNumQuestLogEntries() do
      local info = C_QuestLog.GetInfo(i)
      if info and not info.isHeader and info.questID and C_QuestLog.IsComplete(info.questID) then
        list[#list + 1] = { id = info.questID, title = info.title }
      end
    end
  end)
  return list
end

local function guideTurnin()
  local QDB, DU, ZDB = questieModules()
  if not QDB then say("nie widzę bazy Questie: oddaj questy według żółtych ? na mapie (M).") return false end
  local best
  for _, q in ipairs(readyQuests()) do
    pcall(function()
      local fin = QDB.QueryQuestSingle(q.id, "finishedBy")
      if type(fin) ~= "table" then return end
      for kind = 1, 2 do
        for _, id in ipairs(fin[kind] or {}) do
          local query = (kind == 1) and QDB.QueryNPCSingle or QDB.QueryObjectSingle
          local spawns = query and query(id, "spawns")
          if type(spawns) == "table" then
            local sp, zone, dist = DU.GetNearestSpawn(spawns)
            if sp and zone and dist and dist < 500000 and sp[1] and sp[1] >= 0 and (not best or dist < best.dist) then
              best = { x = sp[1], y = sp[2], zone = zone, dist = dist, who = query(id, "name"), quest = q.title }
            end
          end
        end
      end
    end)
  end
  if not best then say("nie znalazłem, komu oddać gotowe questy. Żółty ? na mapie (M) pokazuje miejsce.") return false end
  local map
  pcall(function() map = ZDB:GetUiMapIdByAreaId(best.zone) end)
  if not map then say("oddaj „" .. (best.quest or "?") .. "”: " .. (best.who or "?") .. ". Żółty ? na mapie (M).") return false end
  return G.wayTo(map, round2(best.x), round2(best.y), "oddaj " .. (best.quest or "quest") .. " (" .. (best.who or "?") .. ")")
end

-- ---------- prowadzenie do questu z kroku (gracz 13.11: „fajnie jakby zawsze mozna bylo przy kazdym kliknac prowadz”) ----------
-- Quest w dzienniku: gotowy -> kto go przyjmuje; niegotowy -> najblizszy cel (moby, obiekty, przedmioty z mobow i obiektow).
-- Quest niewziety -> kto go daje. Miejsca z bazy Questie (spawny), najblizsze do Ciebie; strzalka przez G.wayTo.
local function nearestOf(QDB, DU, npcs, objs, best, label)
  for kind, list in ipairs({ npcs or {}, objs or {} }) do
    for _, id in ipairs(list) do
      pcall(function()
        local query = (kind == 1) and QDB.QueryNPCSingle or QDB.QueryObjectSingle
        local spawns = query and query(id, "spawns")
        if type(spawns) ~= "table" then return end
        local sp, zone, dist = DU.GetNearestSpawn(spawns)
        if sp and zone and dist and dist < 500000 and sp[1] and sp[1] >= 0 and (not best.dist or dist < best.dist) then
          best.x, best.y, best.zone, best.dist, best.who, best.label = sp[1], sp[2], zone, dist, query(id, "name"), label
        end
      end)
    end
  end
end

local function firstIds(list)
  local out = {}
  for _, o in ipairs(list or {}) do
    local id = type(o) == "table" and o[1] or o
    if type(id) == "number" then out[#out + 1] = id end
  end
  return out
end

local function guideQuest(name)
  local QDB, DU, ZDB = questieModules()
  if not (QDB and name) then say("nie widzę bazy Questie: drogę do „" .. tostring(name) .. "” pokaże Polestar albo ! i ? na mapie (M).") return false end
  local id, inLog
  pcall(function()
    for i = 1, C_QuestLog.GetNumQuestLogEntries() do
      local info = C_QuestLog.GetInfo(i)
      if info and not info.isHeader and info.title == name then id, inLog = info.questID, true return end
    end
  end)
  if not id then
    local list = G.questIds and G.questIds(name)
    id = list and list[1]
  end
  if not id then say("nie znalazłem questu „" .. name .. "” w bazie Questie. Drogę pokaże Polestar albo ! na mapie (M).") return false end
  local best = {}
  pcall(function()
    if inLog and C_QuestLog.IsComplete and C_QuestLog.IsComplete(id) then
      local fin = QDB.QueryQuestSingle(id, "finishedBy")
      if type(fin) == "table" then nearestOf(QDB, DU, fin[1], fin[2], best, "oddaj " .. name) end
    elseif inLog then
      local obj = QDB.QueryQuestSingle(id, "objectives")
      if type(obj) == "table" then
        local npcs, objs = firstIds(obj[1]), firstIds(obj[2])
        for _, item in ipairs(firstIds(obj[3])) do
          pcall(function()
            for _, n in ipairs(QDB.QueryItemSingle(item, "npcDrops") or {}) do npcs[#npcs + 1] = n end
            for _, o in ipairs(QDB.QueryItemSingle(item, "objectDrops") or {}) do objs[#objs + 1] = o end
          end)
        end
        nearestOf(QDB, DU, npcs, objs, best, name)
      end
    else
      local st = QDB.QueryQuestSingle(id, "startedBy")
      if type(st) == "table" then nearestOf(QDB, DU, st[1], st[2], best, "weź " .. name) end
    end
  end)
  if not best.dist then say("nie znalazłem miejsca dla „" .. name .. "”. Drogę pokaże Polestar albo ! i ? na mapie (M).") return false end
  local map
  pcall(function() map = ZDB:GetUiMapIdByAreaId(best.zone) end)
  if not map then say(best.label .. ": " .. (best.who or "?") .. ". Sprawdź mapę (M).") return false end
  return G.wayTo(map, round2(best.x), round2(best.y), best.label .. " (" .. (best.who or "?") .. ")")
end

-- Przycisk Prowadz dla kroku z nazwa questu w „…”, gdy krok nie ma wlasnego (pasek Grimuara i okno, Teraz zrob)
local function withGuide(btns, text)
  for _, b in ipairs(btns) do if b[1] == "Prowadź" then return btns end end
  local qn = type(text) == "string" and text:match("„([^”]+)”")
  if qn then table.insert(btns, 1, { "Prowadź", function() pcall(guideQuest, qn) end }) end
  return btns
end

G.guideQuest = guideQuest
G.withGuide = withGuide
G.guideTurnin = guideTurnin
G.guideBags = guideBags
G.guideAH = guideAH
G.emptyBagSlots = emptyBagSlots
G.findNearestVendor = findNearest
G.guideVendor = guideVendor
G.guideInn = guideInn
G.updateVendorButton = updateButton
G.vendorKey = bindKey
