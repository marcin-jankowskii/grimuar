-- Grimuar: modul Trener. U trenera maga przycisk „Kup dla Frosta”: kupuje tylko czary, ktorych Frost uzywa
-- przy levelowaniu (research R2 11.11: Icy Veins / Wowhead Forever), a reszte wypisuje jako pominieta.
-- Polestar „Train All” kupuje wszystko, takze czary pod AoE i bezuzyteczne (Dampen Magic itp.).
-- AoE (Blizzard, Arcane Explosion, Flamestrike, Mana Shield) wlacza /grimuar aoe (GrimuarSetupDB.trainAoE).
local ADDON_NAME, G = ...
local say = G.say

local KEEP = G.BD.keep -- dane z aktywnego buildu (Build/Api.lua)
local AOE = G.BD.aoe
local WHY_SKIP = G.BD.whySkip

local function wanted(name, rank)
  if not name then return false end
  if G.BD_META and G.BD_META.trainAll then return true end -- build „wszystko” (szkic Polestara)
  if name == "Fireball" then return rank == nil or rank == "" or rank:find("1$") ~= nil end
  if KEEP[name] then return true end
  if AOE[name] then return GrimuarSetupDB.trainAoE == true or (G.BD_META and G.BD_META.aoeOn == true) end
  for k in pairs(KEEP) do
    if k:find("^Portal:") and name:find("^Portal:") then return true end
  end
  if name:find("^Portal:") then return true end
  return false
end

local function reason(name)
  if AOE[name] then return "tylko pod AoE (/grimuar aoe)" end
  return WHY_SKIP[name] or "nie ma go w planie Frosta"
end

local function services()
  local list = {}
  if not (GetNumTrainerServices and GetTrainerServiceInfo) then return list end
  for i = 1, GetNumTrainerServices() do
    local name, kind, _, _, rank = GetTrainerServiceInfo(i)
    if kind == "available" and name then
      table.insert(list, { i = i, name = name, rank = rank, cost = (GetTrainerServiceCost and GetTrainerServiceCost(i)) or 0 })
    end
  end
  return list
end

-- 14.11 (R27 E2): trener Twojej klasy przy dowolnym buildzie (dawniej tylko mag); build „wszystko” = kazdy trener klasy
local function isMageTrainer()
  if IsTradeskillTrainer and IsTradeskillTrainer() then return false end
  if G.BD_META and G.BD_META.trainAll then return true end
  for _, s in ipairs(services()) do
    if KEEP[s.name] or AOE[s.name] or WHY_SKIP[s.name] then return true end
  end
  return false
end

-- 14.11 (BugSack: Trener.lua:149 „attempt to call a nil value”): na tym kliencie GetCoinTextureString jest w C_CurrencyInfo
local function coins(c)
  local f = GetCoinTextureString or (C_CurrencyInfo and C_CurrencyInfo.GetCoinTextureString)
  if f then local ok, t = pcall(f, c) if ok and t then return t end end
  c = math.floor(c or 0)
  return (c >= 10000 and (math.floor(c / 10000) .. "g ") or "") .. math.floor((c % 10000) / 100) .. "s " .. (c % 100) .. "c"
end
local function label(s) return s.name .. ((s.rank and s.rank ~= "") and (" (" .. s.rank .. ")") or "") end

local function plan()
  local buy, skip, cost = {}, {}, 0
  for _, s in ipairs(services()) do
    if wanted(s.name, s.rank) then
      table.insert(buy, s)
      cost = cost + s.cost
    else
      table.insert(skip, s)
    end
  end
  return buy, skip, cost
end

-- Zakupy po jednym: po kazdym TRAINER_UPDATE lista jest czytana od nowa (indeksy sie przesuwaja).
local running, bought, nBought, spent = false, {}, 0, 0

local function step()
  if not running then return end
  local money = GetMoney()
  for _, s in ipairs(services()) do
    local key = label(s)
    if wanted(s.name, s.rank) and not bought[key] and s.cost <= money then
      bought[key] = true
      nBought, spent = nBought + 1, spent + s.cost
      BuyTrainerService(s.i)
      return
    end
  end
  running = false
  local buy = plan()
  local msg = nBought > 0 and ("kupione dla Frosta: " .. nBought .. " za " .. coins(spent) .. ".") or "nie było nic do kupienia."
  if #buy > 0 then msg = msg .. " Zabrakło pieniędzy na: " .. #buy .. "." end
  say(msg)
end

local function start()
  if running then return end
  running, bought, nBought, spent = true, {}, 0, 0
  step()
  C_Timer.After(8, function() if running then running = false end end)
end

local btn
local function makeButton()
  if btn or not ClassTrainerFrame then return end
  btn = CreateFrame("Button", "GrimuarTrainFrostButton", ClassTrainerFrame, "UIPanelButtonTemplate")
  btn:SetSize(118, 22)
  btn:SetText("Kup wg buildu")
  local anchor = _G.PolestarTrainAllButton or _G.ClassTrainerTrainButton
  if anchor then btn:SetPoint("RIGHT", anchor, "LEFT", -4, 0) else btn:SetPoint("BOTTOMLEFT", ClassTrainerFrame, "BOTTOMLEFT", 12, 54) end
  btn:SetScript("OnClick", start)
  btn:SetScript("OnEnter", function(self)
    local buy, skip, cost = plan()
    GameTooltip:SetOwner(self, "ANCHOR_TOP")
    GameTooltip:AddLine("Grimuar: kup tylko to, czego Frost używa", 0.85, 0.71, 0.36)
    if #buy > 0 then
      GameTooltip:AddLine("Kupię (" .. coins(cost) .. "):", 0.49, 0.78, 0.55)
      for _, s in ipairs(buy) do GameTooltip:AddLine("  " .. label(s), 0.93, 0.91, 0.86) end
    else
      GameTooltip:AddLine("Nic do kupienia dla Frosta.", 0.93, 0.91, 0.86)
    end
    if #skip > 0 then
      GameTooltip:AddLine("Pominę:", 0.94, 0.54, 0.44)
      for _, s in ipairs(skip) do GameTooltip:AddLine("  " .. label(s) .. ": " .. reason(s.name), 0.6, 0.63, 0.69, true) end
    end
    GameTooltip:Show()
  end)
  btn:SetScript("OnLeave", function() GameTooltip:Hide() end)
end

local ev = CreateFrame("Frame")
ev:RegisterEvent("TRAINER_SHOW")
ev:RegisterEvent("TRAINER_UPDATE")
ev:RegisterEvent("TRAINER_CLOSED")
ev:SetScript("OnEvent", function(_, event)
  if event == "TRAINER_SHOW" then
    C_Timer.After(0.2, function()
      if not isMageTrainer() then if btn then btn:Hide() end return end
      pcall(makeButton)
      if btn then btn:Show() end
      local buy, skip, cost = plan()
      if #buy > 0 or #skip > 0 then
        local names = {}
        for _, s in ipairs(buy) do table.insert(names, label(s)) end
        local msg = (#buy > 0 and ("u trenera kup wg buildu: " .. table.concat(names, ", ") .. " (" .. coins(cost) .. "). Kliknij „Kup wg buildu”.") or "nic nowego dla Twojego buildu.")
        if #skip > 0 then msg = msg .. " Pomijam " .. #skip .. " (najedź na przycisk). Nie klikaj Train All: kupi wszystko." end
        pcall(G.showToast, msg, "train", false)
      end
    end)
  elseif event == "TRAINER_UPDATE" then
    if running then C_Timer.After(0.3, step) end
  elseif event == "TRAINER_CLOSED" then
    running = false
  end
end)

G.trainPlan = plan
G.trainWanted = wanted -- plan Frosta dla listy brakujacych czarow (Engine.lua missingTraining)
