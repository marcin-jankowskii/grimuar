-- Grimuar: modul Plaskie (gracz 14.11: „auction house tez bym chcial bardziej black desertowy”). Forever Skin
-- przebudowuje wiele okien, ale domu aukcyjnego nie (tylko go skaluje). Tu plaska skorka w jego palecie (Style.lua:
-- grafit, czarne kontury 1 px, zloty akcent), bez Forever Skin w palecie Runy. Zasady jak w Forever Skin: tekstury
-- Blizzarda tylko SetAlpha(0), wszystko, co rysujemy, to nasze tekstury; nic nie zapisujemy w tabelach Blizzarda (stan
-- w slabych tabelach). Zostaja: ikony przedmiotow, strzalki, monety, pola wyboru, poswiaty, paski przewijania.
-- Wiersze wynikow powstaja w trakcie, wiec nowe ramki wygladzamy po kazdym wyszukiwaniu.
local ADDON_NAME, G = ...

local function fss()
  local ok, loaded = pcall(C_AddOns.IsAddOnLoaded, "ForeverSkin")
  -- 15.11: z lata ForeverSkin w kolorach Grimuara (GRIMUAR_FSS_LATKA) zostaje paleta Grimuara
  return ok and loaded and not GRIMUAR_FSS_LATKA
end
local function palette()
  if fss() then
    return { panel = { 0.075, 0.08, 0.09, 0.96 }, inner = { 0.05, 0.05, 0.06, 0.85 }, edge = { 0, 0, 0, 1 },
      btn = { 0.1, 0.1, 0.11, 1 }, accent = { 0.95, 0.76, 0.35 } }
  end
  return { panel = { 0.098, 0.082, 0.059, 0.96 }, inner = { 0.067, 0.059, 0.047, 0.9 }, edge = { 0.42, 0.35, 0.18, 1 },
    btn = { 0.11, 0.094, 0.066, 1 }, accent = { 0.85, 0.71, 0.36 } }
end

local done = setmetatable({}, { __mode = "k" })     -- ramki juz wygladzone
local fills = setmetatable({}, { __mode = "k" })    -- nasze tla przyciskow

local KEEP = { "icon", "arrow", "thumb", "check", "coin", "money", "glow", "spinner", "highlight", "flash", "sort", "track",
  "quality", "selected", "close", "favorite", "star", "gold", "silver", "copper" }

local function keepTexture(r)
  if r:GetDrawLayer() == "HIGHLIGHT" then return true end
  local name = ""
  pcall(function() name = (r:GetDebugName() or "") .. " " .. (r.GetParentKey and (r:GetParentKey() or "") or "") end)
  name = name:lower()
  for _, k in ipairs(KEEP) do if name:find(k) then return true end end
  return false
end

local function edge(f, c, inset)
  inset = inset or 0
  local function line(p1, p2, w, h)
    local t = f:CreateTexture(nil, "BACKGROUND", nil, 1)
    t:SetColorTexture(c[1], c[2], c[3], c[4] or 1)
    t:SetPoint(p1, f, p1, (p1:find("LEFT") and inset or -inset), (p1:find("TOP") and -inset or inset))
    t:SetPoint(p2, f, p2, (p2:find("LEFT") and inset or -inset), (p2:find("TOP") and -inset or inset))
    if w then t:SetWidth(w) else t:SetHeight(h) end
  end
  line("TOPLEFT", "TOPRIGHT", nil, 1)
  line("BOTTOMLEFT", "BOTTOMRIGHT", nil, 1)
  line("TOPLEFT", "BOTTOMLEFT", 1, nil)
  line("TOPRIGHT", "BOTTOMRIGHT", 1, nil)
end

local function fill(f, c, sub)
  local t = f:CreateTexture(nil, "BACKGROUND", nil, sub or -8)
  t:SetAllPoints(f)
  t:SetColorTexture(c[1], c[2], c[3], c[4] or 1)
  return t
end

local function isScroll(f)
  local n = ""
  pcall(function() n = (f:GetDebugName() or ""):lower() end)
  return n:find("scrollbar") ~= nil
end

-- jedna ramka: tekstury ozdobne znikaja; przycisk z napisem i pole tekstowe dostaja plaskie tlo i kontur
local function flatFrame(f, P)
  if done[f] then return end
  done[f] = true
  for _, r in ipairs({ f:GetRegions() }) do
    if r.GetObjectType and r:GetObjectType() == "Texture" and not keepTexture(r) then pcall(r.SetAlpha, r, 0) end
  end
  local t = f.GetObjectType and f:GetObjectType()
  if (t == "Button" and f.GetText and f:GetText() and f:GetText() ~= "") or t == "EditBox" then
    if not fills[f] then
      fills[f] = fill(f, t == "EditBox" and P.inner or P.btn, -8)
      edge(f, P.edge)
    end
  end
end

local function walk(f, P, depth)
  if not f or depth > 8 or isScroll(f) then return end
  pcall(flatFrame, f, P)
  for _, c in ipairs({ f:GetChildren() }) do walk(c, P, depth + 1) end
end

local rootDone = setmetatable({}, { __mode = "k" })
local function skinRoot(root)
  if not root or GrimuarSetupDB.noSkins then return end
  local P = palette()
  if not rootDone[root] then
    rootDone[root] = true
    local bg = CreateFrame("Frame", nil, root)
    bg:SetAllPoints(root)
    bg:SetFrameLevel(math.max(0, root:GetFrameLevel() - 1))
    -- 14.11 (gracz: „auctioner sie zepsul”): nasze tlo jest dzieckiem okna, wiec walk() je „wygladzal” (alfa 0)
    -- i okno robilo sie przezroczyste. Nasze ramki oznaczamy jako gotowe, zanim ruszy walk().
    done[bg] = true
    fill(bg, P.panel, -8)
    edge(bg, P.edge)
    pcall(function()
      local title = (root.TitleContainer and root.TitleContainer.TitleText) or root.TitleText
      if title then title:SetTextColor(P.accent[1], P.accent[2], P.accent[3]) end
    end)
    pcall(function() if root.PortraitContainer then root.PortraitContainer:SetAlpha(0) end end)
  end
  walk(root, P, 0)
end

-- dom aukcyjny laduje sie na zadanie (Blizzard_AuctionHouseUI); wiersze wynikow po kazdym wyszukiwaniu
local pending = false
local function soon()
  if pending then return end
  pending = true
  C_Timer.After(0.2, function()
    pending = false
    if _G.AuctionHouseFrame and AuctionHouseFrame:IsShown() then pcall(skinRoot, AuctionHouseFrame) end
  end)
end

local ev = CreateFrame("Frame")
for _, e in ipairs({ "AUCTION_HOUSE_SHOW", "AUCTION_HOUSE_BROWSE_RESULTS_UPDATED", "COMMODITY_SEARCH_RESULTS_UPDATED",
  "ITEM_SEARCH_RESULTS_UPDATED", "OWNED_AUCTIONS_UPDATED" }) do
  pcall(ev.RegisterEvent, ev, e)
end
ev:SetScript("OnEvent", soon)

G.flatSkin = skinRoot
