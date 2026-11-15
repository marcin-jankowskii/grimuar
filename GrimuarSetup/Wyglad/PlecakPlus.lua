-- Grimuar: Plecak+ (15.11, research R28, makieta „Ekwipunek Grimuara” wariant A, wybor gracza „wszystko po kolei”).
-- Na Baganatorze, wylacznie przez jego publiczne API (przyciski przedmiotow zostaja jego, bezpieczne w walce):
-- * znaki gracza: ulubione (nigdy do smieci) i smiec (GrimuarSetupDB.itemMarks[itemID] = "fav" | "junk"), ustawiane
--   w hubie (Ekwipunek > karta przedmiotu) albo Alt+prawy klik na przedmiocie w plecaku (tylko poza walka);
-- * znaczki w rogach: ◆ potrzebne (skladnik kroku poradnika profesji Polestara, G.psNeededItems z GrimuarUI) i ★ ulubione;
-- * wtyczka smieci „Grimuar”: szare przedmioty i oznaczone jako smiec, ale nigdy ulubione ani potrzebne;
-- * pasek na dole plecaka: „Sprzedaj smieci (N, wartosc)” przy kupcu, „Odloz materialy” i „Kompaktuj” przy banku,
--   „W hubie”; sprzedaz i przenoszenie przez C_Container.UseContainerItem tylko z klikniecia, do 12 na klik;
-- * „Other” i „Empty” Baganatora po polsku (Inne, Wolne) na naglowkach grup;
-- * linia Grimuara w dymku przedmiotu: do czego potrzebny, ulubiony, smiec.
local ADDON_NAME, G = ...
local say = G.say

local function on() return GrimuarSetupDB and not GrimuarSetupDB.noSkins and GrimuarSetupDB.plecakPlus ~= false end
local function marks() GrimuarSetupDB.itemMarks = GrimuarSetupDB.itemMarks or {} return GrimuarSetupDB.itemMarks end
local function refreshBags()
  if Baganator and Baganator.API and Baganator.API.RequestItemButtonsRefresh then pcall(Baganator.API.RequestItemButtonsRefresh) end
end

-- ---------- potrzebne (cache 5 s) ----------
local needCache, needAt = {}, -100
local function needed()
  if GetTime() - needAt < 5 then return needCache end
  local t = {}
  if G.psNeededItems then
    local ok, r = pcall(G.psNeededItems)
    if ok and type(r) == "table" then for k, v in pairs(r) do t[k] = v end end
  end
  needCache, needAt = t, GetTime()
  return t
end

function G.itemMark(id) return id and marks()[id] or nil end
function G.itemMarkSet(id, v)
  if not id then return end
  marks()[id] = v
  refreshBags()
  if G.ekwipunekRefresh then pcall(G.ekwipunekRefresh) end
end
function G.itemNeed(id) return id and needed()[id] or nil end
local function quality(id, bag, slot)
  if bag and slot and C_Container and C_Container.GetContainerItemInfo then
    local ok, info = pcall(C_Container.GetContainerItemInfo, bag, slot)
    if ok and type(info) == "table" and info.quality then return info.quality end
  end
  local ok, q = pcall(C_Item.GetItemQualityByID, id)
  return ok and q or nil
end
function G.itemIsJunk(id, q)
  if not id then return false end
  local m = marks()[id]
  if m == "fav" then return false end
  if m == "junk" then return true end
  if needed()[id] then return false end
  return q == 0
end

-- ---------- przeglad toreb: smieci i materialy ----------
local function eachBagItem(fn)
  for bag = 0, (NUM_BAG_SLOTS or 4) do
    local n = C_Container and C_Container.GetContainerNumSlots and C_Container.GetContainerNumSlots(bag) or 0
    for slot = 1, n do
      local info = C_Container.GetContainerItemInfo(bag, slot)
      if type(info) == "table" and info.itemID then fn(bag, slot, info) end
    end
  end
end
local function sellPrice(id)
  local ok, v = pcall(function() return select(11, C_Item.GetItemInfo(id)) end)
  return (ok and tonumber(v)) or 0
end
function G.junkList()
  local list, value = {}, 0
  pcall(eachBagItem, function(bag, slot, info)
    if not info.isLocked and G.itemIsJunk(info.itemID, info.quality) then
      local v = sellPrice(info.itemID) * (info.stackCount or 1)
      if v > 0 then list[#list + 1] = { bag, slot, v } value = value + v end
    end
  end)
  return list, value
end
local function moneyText(c)
  c = math.floor(c or 0)
  local g, s, m = math.floor(c / 10000), math.floor(c % 10000 / 100), c % 100
  local p = {}
  if g > 0 then p[#p + 1] = g .. "|TInterface\\MoneyFrame\\UI-GoldIcon:0:0:2:0|t" end
  if s > 0 then p[#p + 1] = s .. "|TInterface\\MoneyFrame\\UI-SilverIcon:0:0:2:0|t" end
  if m > 0 and g == 0 then p[#p + 1] = m .. "|TInterface\\MoneyFrame\\UI-CopperIcon:0:0:2:0|t" end
  return #p > 0 and table.concat(p, " ") or "0"
end
G.moneyIcons = moneyText

local K = { merchant = false, bank = false }
local function sellJunk()
  if not K.merchant then say("śmieci sprzedasz przy kupcu.") return end
  if InCombatLockdown() then return end
  local list, value = G.junkList()
  local n = 0
  for _, it in ipairs(list) do
    if n >= 12 then break end
    pcall(C_Container.UseContainerItem, it[1], it[2])
    n = n + 1
  end
  if n > 0 then say("sprzedane śmieci: " .. n .. (n < #list and (" (zostało " .. (#list - n) .. ", kliknij jeszcze raz)") or "") .. ", ok. " .. moneyText(value) .. ".")
  else say("nie ma śmieci do sprzedania.") end
end
-- materialy do banku: tkaniny, ziola, ruda, mieso, kamienie (klasa Tradegoods), ale nie potrzebne i nie ulubione
local function depositMaterials()
  if not K.bank then say("materiały odłożysz przy banku.") return end
  if InCombatLockdown() then return end
  local n = 0
  pcall(eachBagItem, function(bag, slot, info)
    if n >= 12 then return end
    local _, _, _, _, _, classID = C_Item.GetItemInfoInstant(info.itemID)
    if classID == (Enum.ItemClass and Enum.ItemClass.Tradegoods or 7) and not needed()[info.itemID] and marks()[info.itemID] ~= "fav" then
      pcall(C_Container.UseContainerItem, bag, slot)
      n = n + 1
    end
  end)
  say(n > 0 and ("odłożone do banku: " .. n .. " stosów materiałów (potrzebne do poradnika zostają).") or "nie ma materiałów do odłożenia.")
end
local function compact()
  if InCombatLockdown() then return end
  if C_Container and C_Container.SortBags then pcall(C_Container.SortBags) elseif SortBags then pcall(SortBags) end
end

-- ---------- Baganator: wtyczki, znaczki, pasek ----------
local function cornerDiamond(button, r, g, b)
  local f = CreateFrame("Frame", nil, button)
  f:SetSize(12, 12)
  local t = f:CreateTexture(nil, "OVERLAY")
  t:SetSize(8, 8)
  t:SetPoint("CENTER")
  t:SetColorTexture(r, g, b, 1)
  pcall(t.SetRotation, t, math.rad(45))
  local e = f:CreateTexture(nil, "ARTWORK")
  e:SetSize(10, 10)
  e:SetPoint("CENTER")
  e:SetColorTexture(0, 0, 0, 0.9)
  pcall(e.SetRotation, e, math.rad(45))
  f.padding = 0.6
  return f
end
local function cornerStar(button)
  local f = CreateFrame("Frame", nil, button)
  f:SetSize(13, 13)
  local t = f:CreateTexture(nil, "OVERLAY")
  t:SetAllPoints()
  if not pcall(t.SetAtlas, t, "PetJournal-FavoritesIcon") then
    t:SetColorTexture(0.85, 0.71, 0.36, 1)
    pcall(t.SetRotation, t, math.rad(45))
  end
  f.padding = 0.5
  return f
end

local bar
local function barButton(text, fn)
  local b = CreateFrame("Button", nil, bar)
  b:SetHeight(20)
  b.bg = b:CreateTexture(nil, "BACKGROUND")
  b.bg:SetAllPoints()
  b.bg:SetColorTexture(0.098, 0.082, 0.059, 0.92)
  b.edge = CreateFrame("Frame", nil, b, "BackdropTemplate")
  b.edge:SetAllPoints()
  if b.edge.SetBackdrop then b.edge:SetBackdrop({ edgeFile = "Interface\\Buttons\\WHITE8X8", edgeSize = 1 }) b.edge:SetBackdropBorderColor(0.85, 0.71, 0.36, 0.45) end
  b.t = b:CreateFontString(nil, "OVERLAY")
  b.t:SetFontObject(GameFontHighlightSmall)
  if G.BF then pcall(b.t.SetFont, b.t, G.BF(), 11, "") end
  b.t:SetPoint("CENTER")
  b.t:SetTextColor(0.85, 0.71, 0.36)
  local hl = b:CreateTexture(nil, "HIGHLIGHT")
  hl:SetAllPoints()
  hl:SetColorTexture(1, 1, 1, 0.08)
  b:SetScript("OnClick", function() pcall(fn) C_Timer.After(0.6, function() pcall(G.plecakBarUpdate) end) end)
  function b:SetLabel(t) self.t:SetText(t) self:SetWidth(math.floor(self.t:GetStringWidth() + 16)) end
  return b
end
function G.plecakBarUpdate()
  if not bar then return end
  local list, value = G.junkList()
  bar.sell:SetShown(K.merchant or #list > 0)
  bar.sell:SetLabel(K.merchant and ("Sprzedaj śmieci (" .. #list .. ", " .. moneyText(value) .. ")") or ("Śmieci: " .. #list .. ", " .. moneyText(value)))
  bar.dep:SetShown(K.bank)
  bar.comp:SetShown(true)
  bar.hub:SetShown(GrimuarHubOpen ~= nil)
  local x = 0
  for _, b in ipairs({ bar.sell, bar.dep, bar.comp, bar.hub }) do
    if b:IsShown() then
      b:ClearAllPoints()
      b:SetPoint("LEFT", bar, "LEFT", x, 0)
      x = x + b:GetWidth() + 4
    end
  end
  bar:SetWidth(math.max(10, x))
  if Baganator and Baganator.API and Baganator.API.RequestLayoutUpdate then pcall(Baganator.API.RequestLayoutUpdate) end
end

local function hookHeaders()
  if not BaganatorCategoryViewsCategoryButtonMixin then return end
  local REN = { Other = "INNE", Empty = "WOLNE" }
  hooksecurefunc(BaganatorCategoryViewsCategoryButtonMixin, "OnLoad", function(self)
    hooksecurefunc(self, "SetText", function(btn, txt)
      if type(txt) ~= "string" or btn.grimRen then return end
      for en, pl in pairs(REN) do
        if txt == en or txt:find("^" .. en .. " ") then
          btn.grimRen = true
          btn:SetText((txt:gsub("^" .. en, pl)))
          btn.grimRen = nil
          return
        end
      end
    end)
  end)
end

local function register()
  if not (Baganator and Baganator.API) then return end
  local A = Baganator.API
  if A.RegisterJunkPlugin then
    A.RegisterJunkPlugin("Grimuar: szare i oznaczone (bez ulubionych i potrzebnych)", "grimuar_junk", function(bag, slot, itemID)
      if not itemID then return nil end
      return G.itemIsJunk(itemID, quality(itemID, bag, slot)) and true or false
    end)
  end
  if A.RegisterCornerWidget then
    A.RegisterCornerWidget("Grimuar: potrzebne (poradnik profesji)", "grimuar_need", function(_, details)
      if not details.itemID then return nil end
      return G.itemNeed(details.itemID) ~= nil
    end, function(button) return cornerDiamond(button, 0.49, 0.88, 0.49) end, { corner = "bottom_left", priority = 1 })
    A.RegisterCornerWidget("Grimuar: ulubione", "grimuar_fav", function(_, details)
      if not details.itemID then return nil end
      return marks()[details.itemID] == "fav"
    end, function(button) return cornerStar(button) end, { corner = "top_right", priority = 2 })
  end
  if A.RegisterRegion then
    bar = CreateFrame("Frame", nil, UIParent)
    bar:SetSize(10, 20)
    bar.sell = barButton("Śmieci", sellJunk)
    bar.dep = barButton("Odłóż materiały", depositMaterials)
    bar.dep:SetLabel("Odłóż materiały")
    bar.comp = barButton("Kompaktuj", compact)
    bar.comp:SetLabel("Kompaktuj")
    bar.hub = barButton("W hubie", function() if GrimuarHubOpen then GrimuarHubOpen("ekwipunek") end end)
    bar.hub:SetLabel("W hubie")
    pcall(A.RegisterRegion, "Grimuar: śmieci, bank, hub", "grimuar_bar", "backpack", "bottom_left", bar)
    pcall(G.plecakBarUpdate)
  end
end

-- Alt+prawy klik na przedmiocie w plecaku: ulubione -> smiec -> bez znaku (tylko poza walka, przycisk Baganatora zostaje)
local function altMark(itemID)
  local m = marks()[itemID]
  local nxt = (m == nil and "fav") or (m == "fav" and "junk") or nil
  G.itemMarkSet(itemID, nxt)
  local name = C_Item.GetItemNameByID(itemID) or ("przedmiot " .. itemID)
  say(name .. ": " .. (nxt == "fav" and "★ ulubione (nigdy do śmieci)" or (nxt == "junk" and "oznaczony jako śmieć" or "bez znaku")) .. ".")
end
G.itemAltMark = altMark

-- dymek: linia Grimuara
local function tooltipLine(tt, data)
  if not on() or type(data) ~= "table" then return end
  local id = data.id
  if not id then return end
  local need = G.itemNeed(id)
  local m = marks()[id]
  if need then tt:AddLine("|cff7ce07c◆ Grimuar: potrzebne|r " .. need, 0.8, 0.9, 0.75, true) end
  if m == "fav" then tt:AddLine("|cffd8b25a★ Grimuar: ulubione|r (nie trafi do śmieci)", 0.8, 0.8, 0.8, true)
  elseif m == "junk" then tt:AddLine("|cffa0a0a0● Grimuar: śmieć|r (sprzedasz przy kupcu)", 0.8, 0.8, 0.8, true) end
end

local ev = CreateFrame("Frame")
for _, e in ipairs({ "PLAYER_LOGIN", "MERCHANT_SHOW", "MERCHANT_CLOSED", "BANKFRAME_OPENED", "BANKFRAME_CLOSED", "BAG_UPDATE_DELAYED" }) do
  pcall(ev.RegisterEvent, ev, e)
end
ev:SetScript("OnEvent", function(_, e)
  if e == "PLAYER_LOGIN" then
    if not on() then return end
    pcall(register)
    pcall(hookHeaders)
    if TooltipDataProcessor and TooltipDataProcessor.AddTooltipPostCall and Enum.TooltipDataType then
      pcall(TooltipDataProcessor.AddTooltipPostCall, Enum.TooltipDataType.Item, function(tt, data) pcall(tooltipLine, tt, data) end)
    end
    -- Alt+prawy klik: HookScript po kliknieciu przycisku Baganatora (nic nie podmieniamy)
    if Baganator and Baganator.API and Baganator.API.Skins and Baganator.API.Skins.RegisterListener then
      Baganator.API.Skins.RegisterListener(function(details)
        if details.regionType ~= "ItemButton" or not details.region or details.region.grimAlt then return end
        details.region.grimAlt = true
        details.region:HookScript("OnMouseUp", function(btn, button)
          if button ~= "RightButton" or not IsAltKeyDown() or InCombatLockdown() then return end
          local id = btn.BGR and btn.BGR.itemID
          if not id then
            local bag, slot = btn.GetBagID and btn:GetBagID(), btn.GetID and btn:GetID()
            local info = bag and slot and C_Container.GetContainerItemInfo(bag, slot)
            id = type(info) == "table" and info.itemID or nil
          end
          if id then altMark(id) end
        end)
      end)
    end
    return
  end
  if e == "MERCHANT_SHOW" then K.merchant = true elseif e == "MERCHANT_CLOSED" then K.merchant = false
  elseif e == "BANKFRAME_OPENED" then K.bank = true elseif e == "BANKFRAME_CLOSED" then K.bank = false end
  if bar then C_Timer.After(0.2, function() pcall(G.plecakBarUpdate) end) end
end)
