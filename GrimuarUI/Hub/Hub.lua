-- Grimuar UI: Hub. Jedno menu poza walka jak w Wiedzminie (makieta 14.11), zakladki Q / E.
-- Klawisz ` (Tab zostaje celem wroga); I i B otwieraja hub na Postaci. Walka zamyka hub; I/B w walce = same torby.
-- Klawiatura: w hubie zostaja tylko Esc, Q, E i klawisz huba, reszta idzie do gry (ruch dziala).
-- Hub nie ma bezpiecznych (chronionych) przyciskow, wiec moze sie zamknac takze w walce.
local ADDON, U = ...
local G, C = U.G, U.C
local say = U.say

BINDING_HEADER_GRIMUARUI = "Grimuar — hub"
BINDING_NAME_GRIMUAR_HUB = "Hub (menu jak w Wiedźminie)"
BINDING_NAME_GRIMUAR_HUB_POSTAC = "Hub: Postać i torba"
BINDING_NAME_GRIMUAR_HUB_CZARY = "Hub: Umiejętności (w walce księga czarów)"
BINDING_NAME_GRIMUAR_HUB_TALENTY = "Hub: Umiejętności (w walce talenty)"
BINDING_NAME_GRIMUAR_HUB_DZIENNIK = "Hub: Dziennik (w walce dziennik gry)"
BINDING_NAME_GRIMUAR_HUB_MAPA = "Hub: Mapa (w walce mapa gry)"
BINDING_NAME_GRIMUAR_HUB_RZEMIOSLO = "Hub: Rzemiosło (w walce profesje)"
BINDING_NAME_GRIMUAR_HUB_SPOLECZNOSC = "Hub: Społeczność (w walce znajomi)"

local TOP_H, BOT_H, PAD = 76, 40, 32
U.PAD = PAD
local tabs = {}
local hub, top, bottom, content, tabHolder, current, qKey, eKey, noteText, metaName, metaZone
local tabBtns, hintPool = {}, {}

local function db()
  GrimuarUIDB = GrimuarUIDB or {}
  return GrimuarUIDB
end
U.db = db

function U.RegisterTab(def)
  tabs[#tabs + 1] = def
  table.sort(tabs, function(a, b) return (a.order or 99) < (b.order or 99) end)
end
local function find(id)
  for _, d in ipairs(tabs) do if d.id == id then return d end end
end
local function sound(name, fallback)
  pcall(PlaySound, (SOUNDKIT and SOUNDKIT[name]) or fallback)
end

-- ---------- pasek zakladek ----------
local function paintTabs()
  for _, d in ipairs(tabs) do
    local b = tabBtns[d.id]
    if b then
      local on = current == d
      U.Color(b.t, on and C.gold or (b:IsMouseOver() and C.text or C.muted))
      U.Color(b.k, on and C.goldDim or C.faint)
      b.line:SetShown(on)
    end
  end
end

local function layoutTabs()
  if not tabHolder then return end
  qKey:ClearAllPoints()
  qKey:SetPoint("LEFT", tabHolder, "LEFT", 0, 6)
  local x = qKey:GetWidth() + 12
  for _, d in ipairs(tabs) do
    local b = tabBtns[d.id]
    local w = math.floor(math.max(b.t:GetStringWidth(), b.k:GetStringWidth()) + 22)
    b:SetWidth(w)
    b:ClearAllPoints()
    b:SetPoint("BOTTOMLEFT", tabHolder, "BOTTOMLEFT", x, 0)
    x = x + w
  end
  eKey:ClearAllPoints()
  eKey:SetPoint("LEFT", tabHolder, "LEFT", x + 12, 6)
  tabHolder:SetWidth(x + 12 + eKey:GetWidth())
  -- 15.11: 15 zakladek (Ekwipunek, Ustawienia): gdy pasek nie miesci sie miedzy nazwa a postacia, lekko sie zmniejsza
  local avail = (UIParent:GetWidth() or 1600) - 560
  local need = x + 12 + eKey:GetWidth()
  tabHolder:SetScale(need > avail and math.max(0.72, avail / need) or 1)
end

-- ---------- podpowiedzi klawiszy na dole ----------
local function hintEntry(i)
  local e = hintPool[i]
  if not e then
    e = { keys = {}, label = U.Text(bottom, 12, "body", C.muted) }
    e.label:SetJustifyV("MIDDLE")
    hintPool[i] = e
  end
  return e
end
local function setHints(list, note)
  for _, e in ipairs(hintPool) do
    e.label:Hide()
    for _, k in ipairs(e.keys) do k:Hide() end
  end
  local x = PAD
  for i, h in ipairs(list) do
    local e = hintEntry(i)
    for j, key in ipairs(h[1]) do
      local k = e.keys[j] or U.Key(bottom, key)
      e.keys[j] = k
      k:SetKey(key)
      k:ClearAllPoints()
      k:SetPoint("LEFT", bottom, "LEFT", x, 0)
      k:Show()
      x = x + k:GetWidth() + 4
    end
    e.label:SetText(h[2])
    e.label:ClearAllPoints()
    e.label:SetPoint("LEFT", bottom, "LEFT", x + 4, 0)
    e.label:Show()
    x = x + 4 + e.label:GetStringWidth() + 24
  end
  noteText:SetText(note or "")
end

-- ---------- klawiatura ----------
local function onKey(self, key)
  if InCombatLockdown() then return end
  local handled = false
  if key == "ESCAPE" then
    U.Close()
    handled = true
  elseif not IsModifierKeyDown() then
    local hubKey = GetBindingKey("GRIMUAR_HUB")
    if hubKey and key == hubKey then U.Close() handled = true
    elseif key == "Q" then U.Step(-1) handled = true
    elseif key == "E" then U.Step(1) handled = true end
  end
  -- klawisz zakladki (np. Enter = Utworz w Rzemiosle); zwraca true, gdy go uzyla
  if not handled and current and current.onKey then
    local ok, used = pcall(current.onKey, key)
    handled = ok and used == true
  end
  pcall(self.SetPropagateKeyboardInput, self, not handled)
end

-- ---------- okno ----------
local function gradient(tex, fromA, toA)
  local ok = pcall(function()
    tex:SetColorTexture(1, 1, 1, 1)
    tex:SetGradient("VERTICAL", CreateColor(C.bg[1], C.bg[2], C.bg[3], fromA), CreateColor(C.bg[1], C.bg[2], C.bg[3], toA))
  end)
  if not ok then tex:Hide() end
end

local function create()
  hub = CreateFrame("Frame", "GrimuarHubFrame", UIParent)
  hub:SetAllPoints(UIParent)
  hub:SetFrameStrata("HIGH")
  hub:SetFrameLevel(10)
  hub:EnableMouse(true)
  -- klawiatura tylko poza walka: w walce gra nie pozwala addonom przepuszczac klawiszy (ruch musi dzialac)
  if not InCombatLockdown() then
    hub:EnableKeyboard(true)
    pcall(hub.SetPropagateKeyboardInput, hub, true)
  end
  hub:Hide()

  hub.veil = hub:CreateTexture(nil, "BACKGROUND", nil, -8)
  hub.veil:SetAllPoints()
  local vTop = hub:CreateTexture(nil, "BACKGROUND", nil, -7)
  vTop:SetPoint("TOPLEFT") vTop:SetPoint("TOPRIGHT") vTop:SetHeight(220)
  gradient(vTop, 0, 0.55)
  local vBot = hub:CreateTexture(nil, "BACKGROUND", nil, -7)
  vBot:SetPoint("BOTTOMLEFT") vBot:SetPoint("BOTTOMRIGHT") vBot:SetHeight(180)
  gradient(vBot, 0.55, 0)

  -- gora: marka, zakladki, kto i gdzie
  top = CreateFrame("Frame", nil, hub)
  top:SetPoint("TOPLEFT") top:SetPoint("TOPRIGHT") top:SetHeight(TOP_H)
  local tb = U.Rect(top, { 0.031, 0.027, 0.02 }, 0.6) tb:SetAllPoints()
  local tl = U.Line(top) tl:SetPoint("BOTTOMLEFT") tl:SetPoint("BOTTOMRIGHT")
  local mark = U.Diamond(top, 16, C.gold, true)
  mark:SetPoint("LEFT", top, "LEFT", PAD, 6)
  local brand = U.Text(top, 14, "title", C.goldDim)
  brand:SetPoint("LEFT", mark, "RIGHT", 8, 0)
  brand:SetJustifyV("MIDDLE")
  brand:SetText("GRIMUAR")
  metaName = U.Text(top, 15, "title", C.text)
  metaName:SetPoint("TOPRIGHT", top, "TOPRIGHT", -PAD, -22)
  metaName:SetJustifyH("RIGHT")
  metaZone = U.Text(top, 12, "body", C.muted)
  metaZone:SetPoint("TOPRIGHT", metaName, "BOTTOMRIGHT", 0, -3)
  metaZone:SetJustifyH("RIGHT")

  tabHolder = CreateFrame("Frame", nil, top)
  tabHolder:SetPoint("TOP") tabHolder:SetPoint("BOTTOM")
  tabHolder:SetWidth(10)
  qKey = U.Key(tabHolder, "Q")
  eKey = U.Key(tabHolder, "E")
  for _, k in ipairs({ { qKey, -1 }, { eKey, 1 } }) do
    k[1]:EnableMouse(true)
    k[1]:SetScript("OnMouseDown", function() U.Step(k[2]) end)
  end
  for _, d in ipairs(tabs) do
    local b = CreateFrame("Button", nil, tabHolder)
    b:SetHeight(TOP_H)
    b.t = U.Text(b, 17, "title", C.muted)
    b.t:SetPoint("TOP", b, "TOP", 0, -22)
    b.t:SetJustifyH("CENTER")
    b.t:SetText(d.title)
    b.k = U.Text(b, 10, "body", C.faint)
    b.k:SetPoint("TOP", b.t, "BOTTOM", 0, -4)
    b.k:SetJustifyH("CENTER")
    b.k:SetText(d.keys or "")
    b.line = b:CreateTexture(nil, "OVERLAY")
    b.line:SetColorTexture(C.gold[1], C.gold[2], C.gold[3], 1)
    b.line:SetPoint("BOTTOMLEFT", 6, 0) b.line:SetPoint("BOTTOMRIGHT", -6, 0)
    b.line:SetHeight(2)
    b.line:Hide()
    b:SetScript("OnClick", function() U.Select(d.id) end)
    b:SetScript("OnEnter", paintTabs)
    b:SetScript("OnLeave", paintTabs)
    tabBtns[d.id] = b
  end

  -- dol: klawisze i notka
  bottom = CreateFrame("Frame", nil, hub)
  bottom:SetPoint("BOTTOMLEFT") bottom:SetPoint("BOTTOMRIGHT") bottom:SetHeight(BOT_H)
  local bb = U.Rect(bottom, { 0.031, 0.027, 0.02 }, 0.6) bb:SetAllPoints()
  local bl = U.Line(bottom) bl:SetPoint("TOPLEFT") bl:SetPoint("TOPRIGHT")
  noteText = U.Text(bottom, 12, "body", C.faint)
  noteText:SetPoint("RIGHT", bottom, "RIGHT", -PAD, 0)
  noteText:SetJustifyH("RIGHT")
  noteText:SetJustifyV("MIDDLE")

  content = CreateFrame("Frame", nil, hub)
  content:SetPoint("TOPLEFT", top, "BOTTOMLEFT", PAD, -20)
  content:SetPoint("BOTTOMRIGHT", bottom, "TOPRIGHT", -PAD, 20)
  U.content = content

  -- wejscie 0,15 s (kanon); wyjscie od razu (walka nie czeka)
  local ag = hub:CreateAnimationGroup()
  local a = ag:CreateAnimation("Alpha")
  a:SetFromAlpha(0) a:SetToAlpha(1) a:SetDuration(0.15)
  pcall(a.SetSmoothing, a, "OUT")
  hub.fade = ag
  hub:SetScript("OnShow", function(self) self.fade:Stop() self.fade:Play() end)
  hub:SetScript("OnHide", function()
    if current and current.leave and current.page then pcall(current.leave, current.page) end
  end)
  hub:SetScript("OnKeyDown", onKey)
  U.fontChanged[#U.fontChanged + 1] = layoutTabs
end

local function updateMeta()
  metaName:SetText((UnitName("player") or "") .. " · " .. (UnitLevel("player") or ""))
  local zone, sub = GetRealZoneText() or "", GetSubZoneText() or ""
  metaZone:SetText((sub ~= "" and sub ~= zone) and (sub .. ", " .. zone) or zone)
end

function U.Select(id)
  if not hub then return end
  local def = find(id) or find(db().tab or "") or tabs[1]
  if not def then return end
  if current and current ~= def then
    if current.leave and current.page then pcall(current.leave, current.page) end
    if current.page then current.page:Hide() end
    sound("IG_CHARACTER_INFO_TAB", 841)
  end
  current = def
  db().tab = def.id
  if not def.page then
    def.page = CreateFrame("Frame", nil, content)
    def.page:SetAllPoints()
    local ok, err = pcall(def.build, def.page)
    if not ok then say("hub, " .. def.title .. ": błąd budowy — " .. tostring(err)) U.logError(def.id .. " build", err) end
  end
  def.page:Show()
  if def.refresh then
    local ok, err = pcall(def.refresh, def.page)
    if not ok then say("hub, " .. def.title .. ": błąd — " .. tostring(err)) U.logError(def.id .. " refresh", err) end
  end
  local hints = { { { "Esc" }, "Zamknij" }, { { "Q", "E" }, "Zakładka" } }
  for _, h in ipairs(def.hints or {}) do hints[#hints + 1] = h end
  setHints(hints, def.note or "W walce hub działa myszą; zamyka go ten sam klawisz")
  paintTabs()
end

function U.Step(dir)
  if #tabs == 0 then return end
  local idx = 1
  for i, d in ipairs(tabs) do if d == current then idx = i end end
  idx = ((idx - 1 + dir) % #tabs) + 1
  U.Select(tabs[idx].id)
end

function U.Open(id)
  if not hub then create() end
  layoutTabs()
  updateMeta()
  hub.veil:SetColorTexture(C.bg[1], C.bg[2], C.bg[3], db().veil or 0.93)
  local was = hub:IsShown()
  hub:Show()
  if not was then sound("IG_CHARACTER_INFO_OPEN", 839) end
  pcall(U.TT.Hide, U.TT)
  U.Select(id or db().tab or "grimuar")
  return true
end

function U.Close()
  if hub and hub:IsShown() then
    hub:Hide()
    sound("IG_CHARACTER_INFO_CLOSE", 840)
  end
end
function U.IsOpen() return hub ~= nil and hub:IsShown() end
function U.Current() return current and current.id end
G.hubOpen = U.IsOpen -- Grimuar Setup: przy otwartym hubie torba nie otwiera okna postaci gry

-- zamyka hub i otwiera okno gry w nastepnej klatce (osobno od naszego kodu)
function U.OpenGame(fn)
  U.Close()
  C_Timer.After(0, function()
    local ok, err = pcall(fn)
    if not ok then say("nie udało się otworzyć okna gry: " .. tostring(err)) end
  end)
end

-- ---------- polecenia klawiszy (Bindings.xml) ----------
function GrimuarHubToggle()
  if U.IsOpen() then U.Close() else U.Open() end
end
-- u kupca, w banku, na poczcie, przy handlu i na rynku I/B otwiera same torby (hub zaslonilby okno)
local BUSY = { "MerchantFrame", "BankFrame", "MailFrame", "AuctionHouseFrame", "TradeFrame", "GuildBankFrame", "GrimuarRynekFrame" }
local function busyWindow()
  for _, n in ipairs(BUSY) do
    local f = _G[n]
    if type(f) == "table" and f.IsShown and f:IsShown() then return true end
  end
end
function GrimuarHubOpen(id)
  -- I/B: w walce, u kupca, w banku, na poczcie i przy handlu same torby (plecak przypiety do huba gra blokuje w walce)
  if id == "postac" and (InCombatLockdown() or (busyWindow() and not U.IsOpen())) then
    if U.bagsToggle then U.bagsToggle() end
    return
  end
  if id and U.IsOpen() and current and current.id == id then U.Close() return end
  U.Open(id)
end

-- ---------- 14.11 (gracz: „chcialbym juz, zeby nasz hud dzialal pod klawiszami”): P/N/L/M/K otwieraja zakladki huba.
-- Hub nie otwiera sie w walce, wtedy te klawisze otwieraja okna gry (jak I/B torby).
local GAME = {
  czary = function()
    if ToggleSpellBook then ToggleSpellBook(BOOKTYPE_SPELL or "spell")
    elseif PlayerSpellsUtil and PlayerSpellsUtil.ToggleSpellBookFrame then PlayerSpellsUtil.ToggleSpellBookFrame() end
  end,
  talenty = function()
    if ToggleTalentFrame then ToggleTalentFrame()
    elseif PlayerSpellsUtil and PlayerSpellsUtil.ToggleClassTalentFrame then PlayerSpellsUtil.ToggleClassTalentFrame() end
  end,
  dziennik = function() if ToggleQuestLog then ToggleQuestLog() end end,
  znajomi = function() if ToggleFriendsFrame then ToggleFriendsFrame() end end,
  mapa = function() ToggleWorldMap() end,
  profesje = function()
    if ToggleProfessionsBook then ToggleProfessionsBook()
    elseif ToggleSpellBook then ToggleSpellBook(BOOKTYPE_PROFESSION or BOOKTYPE_SPELL or "spell") end
  end,
}
U.GameWindow = GAME
function GrimuarHubKey(id, game)
  GrimuarHubOpen(id) -- 14.11: takze w walce hub (okna gry zostaja pod przyciskami w zakladkach)
end

-- ---------- klawisze raz na wersje (stare przypisania zapamietane, /hub klawisze-cofnij) ----------
-- 1: ` = hub, I i B = Postac. 2: P, N, L, M, K = zakladki (tylko gdy klawisz ma domyslne okno gry albo nic).
local KEYSETS = {
  { { "`", "GRIMUAR_HUB" }, { "I", "GRIMUAR_HUB_POSTAC" }, { "B", "GRIMUAR_HUB_POSTAC" } },
  { { "P", "GRIMUAR_HUB_CZARY", "TOGGLESPELLBOOK" }, { "N", "GRIMUAR_HUB_TALENTY", "TOGGLETALENTS" },
    { "L", "GRIMUAR_HUB_DZIENNIK", "TOGGLEQUESTLOG" }, { "M", "GRIMUAR_HUB_MAPA", "TOGGLEWORLDMAP" },
    { "K", "GRIMUAR_HUB_RZEMIOSLO", "TOGGLEPROFESSIONBOOK" }, { "O", "GRIMUAR_HUB_SPOLECZNOSC", "TOGGLESOCIAL" } },
  -- 3 (14.11, gracz: „pod J bym chcial journal questy miec”): J = Dziennik, okno Polestara na Shift+J (gdy wolny)
  { { "J", "GRIMUAR_HUB_DZIENNIK", "GRIMUAR_POLESTAR" }, { "SHIFT-J", "GRIMUAR_POLESTAR", "" } },
}
local function bindKeys()
  local d = db()
  if (d.keysV or 0) >= #KEYSETS then return end
  if InCombatLockdown() then C_Timer.After(15, bindKeys) return end
  d.prevKeys = d.prevKeys or {}
  local set, busy = {}, {}
  for v = (d.keysV or 0) + 1, #KEYSETS do
    for _, k in ipairs(KEYSETS[v]) do
      local cur = GetBindingAction(k[1]) or ""
      if cur ~= k[2] then
        local free = cur == "" or (k[3] and k[3] ~= "" and (cur == k[3] or cur:find("^" .. k[3])))
        if (k[1] == "`" or k[3]) and not free then
          busy[#busy + 1] = k[1] .. " (zajęty: " .. cur .. ")"
        else
          if d.prevKeys[k[1]] == nil then d.prevKeys[k[1]] = cur end
          if pcall(SetBinding, k[1], k[2]) then set[#set + 1] = k[1] end
        end
      end
    end
  end
  pcall(function() SaveBindings(GetCurrentBindingSet()) end)
  d.keysV = #KEYSETS
  if #set > 0 or #busy > 0 then
    say("hub: " .. (#set > 0 and ("klawisze " .. table.concat(set, ", ") .. " otwierają zakładki huba (Q/E zmienia zakładkę; J i L = Dziennik, okno Polestara: Shift+J). W walce te klawisze otwierają okna gry") or "hub gotowy") ..
      (#busy > 0 and (". Nie ruszam " .. table.concat(busy, ", ") .. " — ustawisz je w Klawiszach gry: Grimuar — hub") or "") ..
      ". Cofnięcie: /hub klawisze-cofnij.")
  end
end
local function restoreKeys()
  if InCombatLockdown() then say("poza walką, proszę.") return end
  local d = db()
  for key, act in pairs(d.prevKeys or {}) do
    if act == "" then pcall(SetBinding, key) else pcall(SetBinding, key, act) end
  end
  pcall(function() SaveBindings(GetCurrentBindingSet()) end)
  d.prevKeys, d.keysV = {}, #KEYSETS
  say("hub: klawisze jak przed hubem. Hub dalej pod /hub i w menu Esc.")
end

SLASH_GRIMUARHUB1 = "/hub"
-- ---------- 14.11: autotest zakladek i dziennik bledow (gracz: „na moj powrot niech wszystko dziala”) ----------
-- Bledy huba trafiaja do GrimuarUIDB.errors (ostatnie 30, z data): Claude czyta je z pliku SavedVariables po grze.
function U.logError(where, err)
  local d = db()
  d.errors = d.errors or {}
  table.insert(d.errors, 1, date("%d.%m %H:%M") .. " " .. tostring(where) .. ": " .. tostring(err))
  while #d.errors > 30 do table.remove(d.errors) end
end
-- Po cichu buduje i odswieza kazda zakladke przy schowanym hubie (U.testing: bez otwierania toreb itp.).
local function version()
  local v
  pcall(function() v = (C_AddOns and C_AddOns.GetAddOnMetadata or GetAddOnMetadata)(ADDON, "Version") end)
  return v or "?"
end
local function selfTest(manual)
  if InCombatLockdown() then if manual then say("test huba poza walką.") end return end
  if U.IsOpen() then U.Close() end
  if not hub then create() end
  local keep = db().tab
  U.testing = true
  local okN, bad = 0, {}
  for _, def in ipairs(tabs) do
    local ok, err = pcall(function()
      if not def.page then
        def.page = CreateFrame("Frame", nil, content)
        def.page:SetAllPoints()
        def.build(def.page)
      end
      if def.refresh and not def.heavy then def.refresh(def.page) end
    end)
    if def.leave and def.page then pcall(def.leave, def.page) end
    if def.page then def.page:Hide() end
    if ok then okN = okN + 1 else
      bad[#bad + 1] = def.title .. ": " .. tostring(err)
      U.logError("test " .. def.id, err)
    end
  end
  U.testing = false
  current = nil
  db().tab = keep
  local d = db()
  d.lastTest = { at = date("%d.%m %H:%M"), version = version(), ok = okN, total = #tabs, bad = bad }
  if #bad == 0 then
    say("hub " .. version() .. ": sprawdziłem " .. okN .. " zakładek, wszystkie działają.")
  else
    say("hub " .. version() .. ": " .. #bad .. " z " .. #tabs .. " zakładek ma błąd (zapisane: /hub bledy):")
    for _, b in ipairs(bad) do say("  " .. b) end
  end
end
U.SelfTest = selfTest

SlashCmdList.GRIMUARHUB = function(msg)
  msg = (msg or ""):lower():gsub("^%s+", ""):gsub("%s+$", "")
  if msg == "test" then selfTest(true)
  elseif msg == "bledy" or msg == "błędy" then
    local e = db().errors or {}
    if #e == 0 then say("hub: brak zapisanych błędów.") else for i = 1, math.min(10, #e) do say("  " .. e[i]) end end
  elseif msg == "minimapa" then
    db().minimapAvail = db().minimapAvail == false
    say("hub: „!” na minimapie " .. (db().minimapAvail ~= false and "włączone" or "wyłączone") .. ".")
    if U.minimapAvailUpdate then pcall(U.minimapAvailUpdate) end
  elseif msg == "minimapa zbieranie" then
    -- 15.11: ziola i ruda Grimuara na minimapie (Mapa\MinimapaZadania.lua)
    if U.minimapGatherCmd then U.minimapGatherCmd() end
  elseif msg == "cel" then
    if U.hudCmd then U.hudCmd("cel") end
  elseif msg == "cel ramka" then
    if U.hudCmd then U.hudCmd("ramka") end
  elseif msg == "minimapa-tryb" then
    if U.hudCmd then U.hudCmd("minimapa") end
  elseif msg == "zrzuty" or msg == "poprzednio" then
    if U.kronikaCmd then U.kronikaCmd(msg) end
  elseif msg == "kolo" or msg == "koło" then
    if U.koloToggle then U.koloToggle() end
  elseif msg == "rywale" then
    if U.rivalCmd then U.rivalCmd() end
  elseif msg == "strefa" or msg == "komunikaty" then
    if U.hudEkranCmd then U.hudEkranCmd(msg) end
  elseif msg == "paski" then
    if U.paskiCmd then U.paskiCmd() end
  elseif msg == "paski-akcji" then
    if U.paskiCmd then U.paskiCmd("akcji") end
  elseif msg == "pas" then
    if U.pasCmd then U.pasCmd() end
  elseif msg == "lot" then
    -- 15.11 (R30 P26): pasek lotu u gory ekranu (Hud\Lot.lua)
    if U.lotHudCmd then U.lotHudCmd() end
  elseif msg == "rozmowa" then
    if U.rozmowaCmd then U.rozmowaCmd() end
  elseif msg == "kreator" then
    if U.wizard then U.wizard() end
  elseif msg == "dziel" then
    if U.shareAllQuests then U.shareAllQuests() end
  elseif msg == "porzadki" or msg == "porządki" then
    if U.porzadkiToggle then U.porzadkiToggle() end
  elseif msg == "start" then
    if U.startSesji then U.startSesji(true) end
  elseif msg:find("^okna") then
    if U.oknaCmd then U.oknaCmd(msg:match("^okna%s*(%S*)")) end
  elseif msg == "ustawienia" or msg == "klawisze" or msg == "makra" then
    if U.ustawieniaOpen then U.ustawieniaOpen(msg ~= "ustawienia" and msg or nil) end
  elseif msg:find("^grupa") then
    if U.groupCmd then U.groupCmd(msg:match("^grupa%s+(%S+)")) end
  elseif msg:find("^kompas") then
    if U.kompasCmd then U.kompasCmd(msg:match("^kompas%s+(%S+)")) end
  elseif msg == "klawisze-cofnij" then restoreKeys()
  elseif msg:find("^tlo") or msg:find("^tło") then
    local v = tonumber(((msg:match("([%d%.,]+)") or ""):gsub(",", ".")))
    if v and v >= 0.5 and v <= 0.98 then db().veil = v say("hub: tło " .. v .. " (0,5–0,98).") else say("hub: /hub tlo 0.93 (od 0.5 do 0.98)") end
  elseif find(msg) then GrimuarHubOpen(msg)
  else GrimuarHubToggle() end
end

local ev = CreateFrame("Frame")
ev:RegisterEvent("ADDON_LOADED")
ev:RegisterEvent("PLAYER_LOGIN")
ev:RegisterEvent("PLAYER_REGEN_DISABLED")
ev:RegisterEvent("PLAYER_REGEN_ENABLED")
ev:RegisterEvent("ZONE_CHANGED")
ev:RegisterEvent("ZONE_CHANGED_NEW_AREA")
ev:SetScript("OnEvent", function(_, event, arg)
  if event == "ADDON_LOADED" and arg == ADDON then
    db()
  elseif event == "PLAYER_LOGIN" then
    C_Timer.After(4, bindKeys)
    -- raz na nowa wersje: test wszystkich zakladek po cichu (wynik jedna linijka w czacie)
    C_Timer.After(15, function()
      if db().testedV ~= version() and not InCombatLockdown() and not U.IsOpen() then
        db().testedV = version()
        selfTest(false)
      end
    end)
  elseif event == "PLAYER_REGEN_DISABLED" then
    -- tuz przed blokada walki (jeszcze wolno): klawiatura do gry, zakladka odpina to, czego gra w walce nie pozwala ruszac
    if hub then hub:EnableKeyboard(false) end
    if U.IsOpen() and current and current.combat then pcall(current.combat, true) end
  elseif event == "PLAYER_REGEN_ENABLED" then
    if hub then
      hub:EnableKeyboard(true)
      pcall(hub.SetPropagateKeyboardInput, hub, true)
    end
    if U.IsOpen() and current and current.combat then pcall(current.combat, false) end
  elseif U.IsOpen() then
    pcall(updateMeta)
  end
end)
