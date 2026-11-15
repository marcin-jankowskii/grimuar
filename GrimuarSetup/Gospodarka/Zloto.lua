-- Grimuar: modul Zloto. Wnioski z researchu R8 (12.11, gaming-warsztat/wow/research/R8-zloto-2611.md):
-- linia Grimuara w dymku przedmiotu (zatrzymaj / sprzedaj na AH od razu / sprawdz cene), przypomnienie u kupca,
-- /zloto z celami na poziomy i tygodniowym planem. Plan sesji uzywa G.matsCount (krok „dom aukcyjny”).
-- ID tkanin z Classic (R8: do potwierdzenia na wowhead.com/forever); gdy ID sie nie zgadza, linia po prostu sie nie pokaze.
local ADDON_NAME, G = ...
local say = G.say

local GOLD = "|cffd8b25a"
local KEEP = {
  [2589] = { 999, "zatrzymaj: First Aid, 10 szt. na Manaweave Robe (15) i Tailoring" }, -- Linen Cloth
  [2592] = { 999, "zatrzymaj: First Aid i Tailoring" },                                -- Wool Cloth
  [4306] = { 140, "zatrzymaj do 140 szt. (Tailoring), nadwyżkę na AH" },               -- Silk Cloth
  [4338] = { 95, "zatrzymaj do 95 szt. (Tailoring), nadwyżkę na AH" },                 -- Mageweave Cloth
}

-- Cele zlota (R8, nasz plan, nie dane z gry): { poziom, minimum, cel, na co }
local TARGETS = {
  { 10, 0.5, 1, "trening 10, pierwsza torba, First Aid" },
  { 20, 5, 10, "trening 20 (Blink, Evocation, teleporty), torby" },
  { 30, 25, 40, "trening 26–30" },
  { 35, 60, 80, "trening 32–34 (Mage Armor)" },
  { 40, 110, 150, "jazda 100 g (90 przy Honored) i trening 40; Dual Spec 50 g można później" },
  { 60, 1000, 1200, "Journeyman Riding 1000 g (900 przy Honored) i szybki wierzchowiec 200 g; na 60 questy nie dają złota" },
}

local function itemClass(id)
  local classID, subID
  pcall(function()
    local _, _, _, _, _, c, s = C_Item.GetItemInfoInstant(id)
    classID, subID = c, s
  end)
  return classID, subID
end

local function isMat(id)
  local c, s = itemClass(id)
  return c == 7 and (s == 9 or s == 7) -- Trade Goods: zielarstwo albo metal i kamien
end

local function countItem(id)
  local n = 0
  pcall(function() n = (C_Item and C_Item.GetItemCount or GetItemCount)(id, true) or 0 end)
  return n
end

local function adviceFor(id)
  if not id then return nil end
  local k = KEEP[id]
  if k then
    local have = countItem(id)
    if k[1] < 999 and have > k[1] then return "masz " .. have .. ": " .. k[1] .. " zatrzymaj, resztę na AH" end
    return k[2]
  end
  local ph = G.POTION_HERBS and G.POTION_HERBS[id]
  if ph and G.profRank and G.profRank("First Aid") >= ph[1] then
    return "zrób z tego " .. ph[2] .. " (First Aid), nadwyżkę na AH"
  end
  if isMat(id) then return "sprzedaj na AH od razu: ceny ziół i rudy spadają" end
  local c = itemClass(id)
  if c == 9 then return "przepis: najpierw sprawdź cenę na AH, nie sprzedawaj kupcowi" end
  local quality, bind
  pcall(function()
    local info = { C_Item.GetItemInfo(id) }
    quality, bind = info[3], info[14]
  end)
  if quality and quality >= 3 and bind == 2 then return "niebieski albo lepszy, wiąże się po założeniu: najpierw sprawdź cenę na AH" end
  return nil
end

local function onTooltip(tt, data)
  if not tt or not tt.AddLine then return end
  local id = data and data.id
  local text = adviceFor(id)
  if text then tt:AddLine(GOLD .. "Grimuar:|r " .. text, 1, 1, 1, true) end
end

local function hookTooltips()
  local ok = pcall(function()
    TooltipDataProcessor.AddTooltipPostCall(Enum.TooltipDataType.Item, onTooltip)
  end)
  if ok then G.tooltipHooked = true end
  if not ok and GameTooltip and GameTooltip.HookScript then
    pcall(function()
      GameTooltip:HookScript("OnTooltipSetItem", function(tt)
        local _, link = tt:GetItem()
        local id = link and tonumber(link:match("item:(%d+)"))
        onTooltip(tt, { id = id })
      end)
      G.tooltipHooked = true
    end)
  end
end

-- Ile ziol i rudy masz w torbach (do kroku „dom aukcyjny” w planie sesji).
local function matsCount()
  local n = 0
  for bag = 0, 4 do
    local slots = 0
    pcall(function() slots = C_Container.GetContainerNumSlots(bag) or 0 end)
    for slot = 1, slots do
      pcall(function()
        local info = C_Container.GetContainerItemInfo(bag, slot)
        if info and info.itemID and isMat(info.itemID) then n = n + (info.stackCount or 1) end
      end)
    end
  end
  return n
end

local function nextTarget()
  local l = UnitLevel("player") or 1
  for _, t in ipairs(TARGETS) do
    if l <= t[1] then return t end
  end
end

local function goldNow() return (GetMoney() or 0) / 10000 end

local function fmt(g)
  if g >= 10 then return math.floor(g + 0.5) .. " g" end
  return (string.format("%.1f", g):gsub("%.", ",")) .. " g"
end

local function report()
  local g = goldNow()
  say("złoto: masz " .. fmt(g) .. ".")
  for _, t in ipairs(TARGETS) do
    local mark = (g >= t[3]) and "ok" or ((g >= t[2]) and "minimum ok" or "brakuje " .. fmt(t[2] - g))
    say("  na " .. t[1] .. ": minimum " .. fmt(t[2]) .. ", cel " .. fmt(t[3]) .. " (" .. t[4] .. ") — " .. mark)
  end
  say("raz w tygodniu (15 min, w mieście): skan Auctionatorem, wystaw zioła, rudę i nadwyżkę tkanin, zielone bez wartości do kupca, tkaniny do banku.")
  say("brakuje ponad 20% do celu? Jedna sesja 45–60 min zbierania ziół i rudy po drodze questów.")
end

local merchantSaid = 0
local function atMerchant()
  if time() - merchantSaid < 600 then return end
  local keep, mats = {}, matsCount()
  for id, k in pairs(KEEP) do
    if countItem(id) > 0 then
      local nm
      pcall(function() nm = C_Item.GetItemNameByID(id) end)
      keep[#keep + 1] = nm or ("przedmiot " .. id)
    end
  end
  if #keep == 0 and mats == 0 then return end
  merchantSaid = time()
  local parts = {}
  if #keep > 0 then parts[#parts + 1] = "nie sprzedawaj: " .. table.concat(keep, ", ") end
  if mats > 0 then parts[#parts + 1] = "zioła i rudę (" .. mats .. ") wystaw na AH, nie u kupca" end
  pcall(G.showToast, "u kupca: " .. table.concat(parts, "; ") .. ". Szare rzeczy sprzedał już Leatrix.", "bags", false)
end

local ev = CreateFrame("Frame")
ev:RegisterEvent("PLAYER_LOGIN")
ev:RegisterEvent("MERCHANT_SHOW")
ev:SetScript("OnEvent", function(_, event)
  if event == "PLAYER_LOGIN" then
    pcall(hookTooltips)
  elseif event == "MERCHANT_SHOW" then
    C_Timer.After(1.2, function() pcall(atMerchant) end)
  end
end)

SLASH_GRIMUARZLOTO1 = "/zloto"
SlashCmdList["GRIMUARZLOTO"] = function() report() end

G.matsCount = matsCount
G.goldTarget = nextTarget
G.goldNow = goldNow
