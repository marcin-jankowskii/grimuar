-- Grimuar UI: zakladka Postac (makieta 14.11 „Hub · Postać”): po lewej kim jestes i liczby, w srodku model 3D
-- z 19 slotami (jakosc na ramce, alarm Rozwoju na pustej rozdzce), po prawej torba = plecak Baganatora w skorce Runy,
-- przypiety do huba na czas zakladki (pelne dzialanie: uzyj, sortuj, sprzedaj). Bez Baganatora torba gry.
-- Sloty: LPM bierze/zaklada (kursor), przeciagnij na slot = zaloz, Shift+LPM = link do czatu. Wszystko tylko poza walka.
local ADDON, U = ...
local G, C = U.G, U.C

local LEFT_SLOTS = { "HeadSlot", "NeckSlot", "ShoulderSlot", "BackSlot", "ChestSlot", "ShirtSlot", "TabardSlot", "WristSlot" }
local RIGHT_SLOTS = { "HandsSlot", "WaistSlot", "LegsSlot", "FeetSlot", "Finger0Slot", "Finger1Slot", "Trinket0Slot", "Trinket1Slot" }
local WEAPON_SLOTS = { "MainHandSlot", "SecondaryHandSlot", "RangedSlot" }
local SLOT_PL = { HeadSlot = "Głowa", NeckSlot = "Szyja", ShoulderSlot = "Ramiona", BackSlot = "Plecy", ChestSlot = "Pierś",
  ShirtSlot = "Koszula", TabardSlot = "Tabard", WristSlot = "Nadgarstki", HandsSlot = "Dłonie", WaistSlot = "Pas",
  LegsSlot = "Nogi", FeetSlot = "Stopy", Finger0Slot = "Pierścień", Finger1Slot = "Pierścień", Trinket0Slot = "Dodatek",
  Trinket1Slot = "Dodatek", MainHandSlot = "Główna ręka", SecondaryHandSlot = "Druga ręka", RangedSlot = "Dystans (różdżka)" }
local RACE_PL = { Gnome = "Gnom", Human = "Człowiek", Dwarf = "Krasnolud", ["Night Elf"] = "Nocny elf", Draenei = "Draenei",
  Worgen = "Worgen", ["High Elf"] = "Wysoki elf" }
local CLASS_PL = { Mage = "Mag", Warrior = "Wojownik", Priest = "Kapłan", Rogue = "Łotrzyk", Warlock = "Czarnoksiężnik",
  Hunter = "Łowca", Paladin = "Paladyn", Druid = "Druid", Shaman = "Szaman" }

local S = {} -- widzety strony
local slots = {}

-- ---------- torba: plecak Baganatora przypiety do huba ----------
local packs, docked = {}, nil
local function findPacks()
  for name, obj in pairs(_G) do
    if type(name) == "string" and type(obj) == "table" and name:find("^Baganator_%a+ViewBackpackViewFrame") and obj.IsShown then
      packs[obj] = true
    end
  end
end
-- 14.11 (zrzut z gry): szukanie po nazwie nie znalazlo plecaka; pewne zrodlo = sluchacz skorek Baganatora w PlecakRuny
local function shownPack()
  local tagged = U.call(G.plecakFrames)
  if type(tagged) == "table" then
    for f in pairs(tagged) do
      packs[f] = true
      if f.IsShown and f:IsShown() then return f end
    end
  end
  for f in pairs(packs) do if f:IsShown() then return f end end
end
local function baganator()
  local reg = _G.Baganator and Baganator.CallbackRegistry
  if reg and reg.TriggerEvent then return reg end
end
function U.bags(open)
  local reg = baganator()
  if reg and pcall(reg.TriggerEvent, reg, open and "BagShow" or "BagHide") then return true end
  if open then pcall(OpenAllBags) else pcall(CloseAllBags) end
end
function U.bagsToggle()
  if not next(packs) then findPacks() end
  U.bags(not shownPack())
end
local hooked = setmetatable({}, { __mode = "k" })
local dock
local function dockLoop(n)
  if dock() or (n or 0) >= 20 then return end
  C_Timer.After(0.1, function() dockLoop((n or 0) + 1) end)
end
dock = function()
  if InCombatLockdown() then return true end -- w walce gra nie pozwala ruszac plecaka (chronione przyciski przedmiotow)
  if not S.dock or not U.IsOpen() or U.Current() ~= "postac" then return true end
  local f = shownPack()
  if not f then findPacks() f = shownPack() end
  if not f then return false end
  if not hooked[f] then
    hooked[f] = true
    f:HookScript("OnShow", function() if U.IsOpen() and U.Current() == "postac" then C_Timer.After(0, dock) end end)
  end
  if not docked or docked.f ~= f then
    local pts = {}
    for i = 1, f:GetNumPoints() do pts[i] = { f:GetPoint(i) } end
    docked = { f = f, pts = pts, strata = f:GetFrameStrata() }
  end
  pcall(function()
    f:SetFrameStrata("DIALOG")
    f:ClearAllPoints()
    f:SetPoint("TOPLEFT", S.dock, "TOPLEFT", 0, 0)
  end)
  return true
end
local function undock()
  if not docked or InCombatLockdown() then return end
  local d = docked
  docked = nil
  pcall(function()
    d.f:ClearAllPoints()
    for _, p in ipairs(d.pts) do d.f:SetPoint(p[1], p[2] or UIParent, p[3], p[4], p[5]) end
    if d.strata then d.f:SetFrameStrata(d.strata) end
  end)
end

-- ---------- sloty ekwipunku ----------
local function slotId(name)
  local ok, id, tex = pcall(GetInventorySlotInfo, name)
  if ok and id then return id, tex end
end
local function makeSlot(parent, name, size)
  local id, emptyTex = slotId(name)
  if not id then return nil end
  local s = U.Slot(parent, size)
  s.id, s.emptyTex, s.pl, s.name = id, emptyTex, SLOT_PL[name] or name, name
  s:RegisterForClicks("LeftButtonUp", "RightButtonUp")
  s:RegisterForDrag("LeftButton")
  s:SetScript("OnClick", function(self, btn)
    if InCombatLockdown() then return end
    if IsModifiedClick and IsModifiedClick() then
      local link = GetInventoryItemLink("player", self.id)
      if link and HandleModifiedItemClick then pcall(HandleModifiedItemClick, link) end
      return
    end
    if btn == "LeftButton" then
      if CursorHasItem() then pcall(EquipCursorItem, self.id) else pcall(PickupInventoryItem, self.id) end
    end
  end)
  s:SetScript("OnDragStart", function(self) if not InCombatLockdown() then pcall(PickupInventoryItem, self.id) end end)
  s:SetScript("OnReceiveDrag", function(self) if CursorHasItem() and not InCombatLockdown() then pcall(EquipCursorItem, self.id) end end)
  s:SetScript("OnEnter", function(self)
    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
    if GetInventoryItemTexture("player", self.id) then pcall(GameTooltip.SetInventoryItem, GameTooltip, "player", self.id)
    else GameTooltip:SetText(self.pl, 1, 1, 1) if self.hint then GameTooltip:AddLine(self.hint, 0.94, 0.54, 0.44, true) end end
    GameTooltip:Show()
  end)
  s:SetScript("OnLeave", function() GameTooltip:Hide() end)
  slots[#slots + 1] = s
  return s
end
local function paintSlot(s, alarm)
  local tex = GetInventoryItemTexture("player", s.id)
  if tex then
    s.icon:SetTexture(tex)
    s.icon:SetDesaturated(false)
    s.icon:SetAlpha(1)
    s:SetQuality(GetInventoryItemQuality("player", s.id), false)
  else
    s.icon:SetTexture(s.emptyTex)
    s.icon:SetDesaturated(true)
    s.icon:SetAlpha(0.35)
    s:SetQuality(nil, alarm)
  end
end

-- ---------- liczby ----------
local function stat(i) local ok, _, eff = pcall(UnitStat, "player", i) return ok and U.num(eff) or nil end
local function second(fn, ...) local ok, _, b = pcall(fn, ...) return ok and U.num(b) or nil end
local function rozwoj()
  local list = {}
  if G.rozwojSteps then
    pcall(G.rozwojSteps, function(key, text) list[(key or ""):gsub("^rozwoj%-", "")] = text end)
  end
  return list
end

local function build(page)
  -- lewa kolumna
  local L = CreateFrame("Frame", nil, page)
  L:SetPoint("TOPLEFT") L:SetPoint("BOTTOMLEFT") L:SetWidth(270)
  S.name = U.Text(L, 30, "title", C.gold)
  S.name:SetPoint("TOPLEFT", 0, -2)
  S.sub = U.Text(L, 13, "body", C.muted)
  S.sub:SetPoint("TOPLEFT", S.name, "BOTTOMLEFT", 0, -6)
  local xl = U.Label(L, "Doświadczenie")
  xl:SetPoint("TOPLEFT", S.sub, "BOTTOMLEFT", 0, -18)
  S.xpVal = U.Text(L, 12, "body", C.muted)
  S.xpVal:SetPoint("TOPRIGHT", xl, "TOPLEFT", 270, 0)
  S.xpVal:SetJustifyH("RIGHT")
  S.xp = U.Bar(L, 7)
  S.xp:SetPoint("TOPLEFT", xl, "BOTTOMLEFT", 0, -6)
  S.xp:SetWidth(270)
  S.xpNote = U.Text(L, 11, "body", C.faint)
  S.xpNote:SetPoint("TOPLEFT", S.xp, "BOTTOMLEFT", 0, -5)

  local function box(label, x)
    local b = U.Panel(L, 0.5, false)
    b:SetSize(130, 50)
    b:SetPoint("TOPLEFT", S.xpNote, "BOTTOMLEFT", x, -14)
    local l = U.Label(b, label)
    l:SetPoint("TOPLEFT", 10, -7)
    b.v = U.Text(b, 20, "body", C.text)
    b.v:SetPoint("TOPLEFT", l, "BOTTOMLEFT", 0, -3)
    return b
  end
  S.hp = box("Zdrowie", 0)
  S.mp = box("Mana", 140)
  U.Color(S.mp.v, C.frost)

  local h1 = U.H2(L, "Atrybuty")
  h1:SetPoint("TOPLEFT", S.hp, "BOTTOMLEFT", 0, -18)
  S.attr = {}
  local prev = h1
  for i = 1, 5 do
    local r = U.KV(L, 270, 14)
    r:SetPoint("TOPLEFT", prev, "BOTTOMLEFT", 0, i == 1 and -6 or 0)
    S.attr[i] = r
    prev = r
  end
  local h2 = U.H2(L, "Magia i obrona")
  h2:SetPoint("TOPLEFT", prev, "BOTTOMLEFT", 0, -14)
  S.magic = {}
  prev = h2
  for i = 1, 5 do
    local r = U.KV(L, 270, 14)
    r:SetPoint("TOPLEFT", prev, "BOTTOMLEFT", 0, i == 1 and -6 or 0)
    S.magic[i] = r
    prev = r
  end
  local game = U.Button(L, "Reputacje, waluty, honor")
  game:SetPoint("BOTTOMLEFT", L, "BOTTOMLEFT", 0, 0)
  -- 14.11 (R24 P11): zestawy PvE i PvP (ZestawySprzetu.lua)
  if U.gearSetsBuild then
    local okG, gs = pcall(U.gearSetsBuild, L)
    if okG and gs then gs:SetPoint("BOTTOMLEFT", game, "TOPLEFT", 0, 14) end
  end
  game:SetScript("OnClick", function()
    -- 13.11 (Klawisze.lua): okno postaci z kodu addonu psuje paski, gdy trzymaja ukryte wartosci z walki
    local secret = false
    pcall(function()
      local f = _G.PlayerFrame
      for _, b in ipairs({ f and f.healthbar, f and f.manabar }) do
        if b and issecretvalue and (issecretvalue(b.currValue) or issecretvalue(b:GetValue())) then secret = true end
      end
    end)
    if secret then U.say("okno postaci za chwilę: paski jeszcze trzymają wartości z walki. Spróbuj za kilka sekund.") return end
    U.OpenGame(function() ToggleCharacter("PaperDollFrame") end)
  end)

  -- prawa kolumna: torba
  local R = CreateFrame("Frame", nil, page)
  R:SetPoint("TOPRIGHT") R:SetPoint("BOTTOMRIGHT") R:SetWidth(400)
  local th = U.H2(R, "Torba")
  th:SetPoint("TOPLEFT", 0, -2)
  S.free = U.Text(R, 13, "body", C.muted)
  S.free:SetPoint("TOPRIGHT", R, "TOPRIGHT", 0, -2)
  S.free:SetJustifyH("RIGHT")
  S.bagSlots = {}
  for i = 1, 4 do
    local b = U.Slot(R, 30)
    b:SetPoint("TOPLEFT", th, "BOTTOMLEFT", (i - 1) * 36, -10)
    b.bag = i
    b:SetScript("OnEnter", function(self)
      GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
      local inv = (C_Container and C_Container.ContainerIDToInventoryID and C_Container.ContainerIDToInventoryID(self.bag))
        or (ContainerIDToInventoryID and ContainerIDToInventoryID(self.bag))
      if inv and GetInventoryItemTexture("player", inv) then pcall(GameTooltip.SetInventoryItem, GameTooltip, "player", inv)
      else GameTooltip:SetText("Puste miejsce na torbę", 1, 1, 1) GameTooltip:AddLine("Torby: kupiec (Small Brown Pouch) albo dom aukcyjny.", 0.64, 0.61, 0.55, true) end
      GameTooltip:Show()
    end)
    b:SetScript("OnLeave", function() GameTooltip:Hide() end)
    S.bagSlots[i] = b
  end
  S.bagTag = U.Tag(R, "")
  S.bagTag:SetPoint("LEFT", S.bagSlots[4], "RIGHT", 12, 0)
  S.dock = CreateFrame("Frame", nil, R)
  S.dock:SetPoint("TOPLEFT", S.bagSlots[1], "BOTTOMLEFT", 0, -14)
  S.dock:SetPoint("BOTTOMRIGHT", R, "BOTTOMRIGHT", 0, 0)
  S.noBag = U.Para(S.dock, 13, 380, C.muted)
  S.noBag:SetPoint("TOPLEFT", 0, -4)
  S.noBag:SetText("Plecak otworzy się tutaj (Baganator). Bez Baganatora: torby gry po zamknięciu huba.")

  -- srodek: model i sloty
  local M = CreateFrame("Frame", nil, page)
  M:SetPoint("TOPLEFT", L, "TOPRIGHT", 30, 0)
  M:SetPoint("BOTTOMRIGHT", R, "BOTTOMLEFT", -30, 0)
  local glow = M:CreateTexture(nil, "BACKGROUND")
  glow:SetSize(300, 300)
  glow:SetPoint("TOP", M, "TOP", 0, -60) -- przestawiane nizej, pod model
  pcall(function()
    glow:SetColorTexture(1, 1, 1, 1)
    glow:SetGradient("VERTICAL", CreateColor(C.frost[1], C.frost[2], C.frost[3], 0), CreateColor(C.frost[1], C.frost[2], C.frost[3], 0.07))
  end)
  local model = CreateFrame("PlayerModel", nil, M)
  model:SetSize(250, 392)
  -- 14.11 (gracz: „te postac mozna by w dol przesunac, jakos tak wysoko jest”): blok (model 392, bron i podpis
  -- ok. 85 px nizej) wysrodkowany w pionie, zamiast przy gornej krawedzi
  model:SetPoint("CENTER", M, "CENTER", 0, 42)
  model:EnableMouse(true)
  model:EnableMouseWheel(true)
  model.facing, model.zoom = 0.35, 0
  model:SetScript("OnMouseDown", function(self) self.dragX = GetCursorPosition() end)
  model:SetScript("OnMouseUp", function(self) self.dragX = nil end)
  model:SetScript("OnHide", function(self) self.dragX = nil end)
  model:SetScript("OnUpdate", function(self)
    if not self.dragX then return end
    local x = GetCursorPosition()
    self.facing = self.facing + (x - self.dragX) / 90
    self.dragX = x
    pcall(self.SetFacing, self, self.facing)
  end)
  model:SetScript("OnMouseWheel", function(self, d)
    self.zoom = math.max(0, math.min(0.6, self.zoom + d * 0.1))
    pcall(self.SetPortraitZoom, self, self.zoom)
  end)
  S.model = model
  glow:ClearAllPoints()
  glow:SetPoint("TOP", model, "TOP", 0, -60)
  local ped = U.Line(M, C.goldDim, 0.5)
  ped:SetWidth(180)
  ped:SetPoint("TOP", model, "BOTTOM", 0, 2)
  local pedRune = U.Diamond(M, 12, C.goldDim, true)
  pedRune:SetPoint("CENTER", ped, "CENTER")
  local hintM = U.Text(M, 11, "body", C.faint)
  hintM:SetPoint("TOP", ped, "BOTTOM", 0, -6)
  hintM:SetJustifyH("CENTER")
  hintM:SetText("przeciągnij: obrót · kółko: przybliż")

  local function column(list, anchorPoint, relPoint, x)
    local prevS
    for i, name in ipairs(list) do
      local s = makeSlot(M, name, 42)
      if s then
        if not prevS then s:SetPoint(anchorPoint, model, relPoint, x, -4)
        else s:SetPoint("TOP", prevS, "BOTTOM", 0, -6) end
        prevS = s
      end
    end
  end
  column(LEFT_SLOTS, "TOPRIGHT", "TOPLEFT", -20)
  column(RIGHT_SLOTS, "TOPLEFT", "TOPRIGHT", 20)

  local row = CreateFrame("Frame", nil, M)
  row:SetSize(3 * 48 + 2 * 10, 48)
  row:SetPoint("TOP", hintM, "BOTTOM", 0, -12)
  local prevW
  S.weapons = {}
  for _, name in ipairs(WEAPON_SLOTS) do
    local s = makeSlot(row, name, 48)
    if s then
      if not prevW then s:SetPoint("LEFT", row, "LEFT", 0, 0) else s:SetPoint("LEFT", prevW, "RIGHT", 10, 0) end
      prevW = s
      S.weapons[name] = s
    end
  end
  S.alarm = U.Para(M, 12, 200, C.danger)
  S.alarm:SetPoint("LEFT", row, "RIGHT", 14, 0)
  S.alarm:SetJustifyV("MIDDLE")

  -- odswiezanie na zdarzenia, tylko gdy zakladka jest otwarta
  local ev = CreateFrame("Frame", nil, page)
  S.ev = ev
  local queued = false
  ev:SetScript("OnEvent", function()
    if queued then return end
    queued = true
    C_Timer.After(0.15, function()
      queued = false
      if page:IsVisible() then pcall(S.data) end
    end)
  end)
end

-- dane bez ruszania torby
function S.data()
  local name = UnitName("player") or ""
  local lvl = UnitLevel("player") or 0
  S.name:SetText(name)
  local race = UnitRace("player") or ""
  local cls = UnitClass("player") or ""
  S.sub:SetText((RACE_PL[race] or race) .. " · " .. (CLASS_PL[cls] or cls) .. " · poziom " .. lvl)

  local xp, mx, rest = U.num(UnitXP("player")), U.num(UnitXPMax("player")), U.num(GetXPExhaustion and GetXPExhaustion() or 0) or 0
  if lvl >= 60 or not mx or mx == 0 then
    S.xpVal:SetText("")
    S.xp:SetValue(1)
    S.xpNote:SetText("Najwyższy poziom")
  else
    S.xpVal:SetText(U.thousands(xp) .. " / " .. U.thousands(mx))
    S.xp:SetValue((xp or 0) / mx, rest > 0 and ((xp or 0) + rest) / mx or nil)
    S.xpNote:SetText(rest > 0 and ("Odpoczynek: " .. U.thousands(rest) .. " (" .. math.floor(rest / mx * 100 + 0.5) .. "% paska) — potwory ×2") or "Bez odpoczynku — wyloguj się w karczmie")
  end
  S.hp.v:SetText(U.thousands(UnitHealthMax("player")))
  S.mp.v:SetText(U.thousands(UnitPowerMax("player", 0)))

  local A = { { "Intelekt", 4 }, { "Duch", 5 }, { "Wytrzymałość", 3 }, { "Zręczność", 2 }, { "Siła", 1 } }
  for i, a in ipairs(A) do S.attr[i]:Set(a[1], U.thousands(stat(a[2]))) end
  local okC, crit = pcall(GetSpellCritChance, 5)
  crit = okC and U.num(crit)
  local okR, regen = pcall(GetManaRegen)
  regen = okR and U.num(regen)
  local okP, power = pcall(GetSpellBonusDamage, 5)
  power = okP and U.num(power)
  S.magic[1]:Set("Moc czarów mrozu", power and U.thousands(power) or "—")
  S.magic[2]:Set("Kryt. czarów mrozu", crit and (string.format("%.1f", crit):gsub("%.", ",") .. "%") or "—")
  S.magic[3]:Set("Regeneracja many", regen and (U.thousands(regen * 5) .. " / 5 s") or "—")
  S.magic[4]:Set("Pancerz", U.thousands(second(UnitArmor, "player")))
  S.magic[5]:Set("Odporność na arkana", U.thousands(second(UnitResistance, "player", 6)))

  -- sloty i alarmy Rozwoju
  local alarms = rozwoj()
  local wand = alarms.wand
  for _, s in ipairs(slots) do
    s.hint = (s.name == "RangedSlot" and wand) or (s.name == "MainHandSlot" and alarms.weapon) or nil
    paintSlot(s, s.hint ~= nil and not GetInventoryItemTexture("player", s.id))
  end
  S.alarm:SetText(wand or alarms.weapon or "")

  -- torby: wolne miejsca i puste miejsca na torby
  local free, total, emptyBags = 0, 0, 0
  for bag = 0, 4 do
    local n = (C_Container and C_Container.GetContainerNumSlots and U.num(C_Container.GetContainerNumSlots(bag))) or 0
    local f = (C_Container and C_Container.GetContainerNumFreeSlots and U.num((C_Container.GetContainerNumFreeSlots(bag)))) or 0
    total, free = total + n, free + f
  end
  for i, b in ipairs(S.bagSlots) do
    local inv = (C_Container and C_Container.ContainerIDToInventoryID and U.call(C_Container.ContainerIDToInventoryID, i))
      or (ContainerIDToInventoryID and U.call(ContainerIDToInventoryID, i))
    local tex = inv and GetInventoryItemTexture("player", inv)
    if tex then
      b.icon:SetTexture(tex)
      b.icon:SetAlpha(1)
      b:SetQuality(inv and GetInventoryItemQuality("player", inv) or 1, false)
    else
      b.icon:SetTexture(nil)
      b:SetQuality(nil, true)
      emptyBags = emptyBags + 1
    end
  end
  S.free:SetText(free .. " / " .. total .. " wolnych")
  if emptyBags > 0 then S.bagTag:SetTag(emptyBags .. " puste miejsca na torby", C.danger) else S.bagTag:SetTag("torby komplet", C.ok) end
end

local EVENTS = { "PLAYER_EQUIPMENT_CHANGED", "BAG_UPDATE_DELAYED", "PLAYER_XP_UPDATE", "PLAYER_LEVEL_UP", "UPDATE_EXHAUSTION",
  "UNIT_STATS", "UNIT_MAXHEALTH", "UNIT_MAXPOWER", "UNIT_INVENTORY_CHANGED" }

local function refresh(page)
  for _, e in ipairs(EVENTS) do pcall(S.ev.RegisterEvent, S.ev, e) end
  pcall(S.model.SetUnit, S.model, "player")
  pcall(S.model.SetCamDistanceScale, S.model, 0.8) -- 14.11 zrzut: gnom za maly w ramce
  pcall(S.model.SetFacing, S.model, S.model.facing)
  S.data()
  -- plecak: otworz i przypnij (Baganator buduje okno przy pierwszym otwarciu, wiec druga proba chwile pozniej)
  if baganator() then
    S.noBag:Hide()
    if not U.testing then U.bags(true) end
    C_Timer.After(0.05, function() dockLoop(0) end)
  else
    S.noBag:Show()
  end
end

local function leave(page)
  S.ev:UnregisterAllEvents()
  if baganator() then
    undock()
    if not U.testing then U.bags(false) end
  end
end

U.RegisterTab({
  id = "postac", order = 1, title = "Postać", keys = "I · B",
  build = build, refresh = refresh, leave = leave,
  hints = { { { "LPM" }, "Weź / załóż" }, { { "Shift", "LPM" }, "Link do czatu" } },
  note = "Torba: Baganator · w walce plecak wraca na swoje miejsce",
  combat = function(on)
    if on then undock() elseif U.Current() == "postac" then dockLoop() end
  end,
})
