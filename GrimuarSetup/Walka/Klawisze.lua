-- Grimuar: modul Klawisze (prosba gracza 13.11, uklad jak w PoE i Black Desert):
-- I i B: ekwipunek = torby i okno postaci razem (przeciaganie przedmiotow prosto na sloty), takze po kliknieciu ikony torby;
-- J: okno Polestara; H: Hearthstone (makro Kamien); czytelniejsze oznaczenia klawiszy na przyciskach (wieksze, zlote, skroty).
-- Strona okna: Wiedza > Klawisze. Polecenia klawiszy w Bindings.xml.
local ADDON_NAME, G = ...
local say = G.say

BINDING_HEADER_GRIMUAR = "Grimuar"
BINDING_NAME_GRIMUAR_EKWIPUNEK = "Ekwipunek: torby i postać razem"
BINDING_NAME_GRIMUAR_POLESTAR = "Okno Polestara"
BINDING_NAME_GRIMUAR_OKNO = "Okno Grimuara"

-- ---------- ekwipunek: torby i postac razem ----------
-- 13.11 (BugSack): okno postaci otwierane kodem addonu psuje w Midnight liczby na pasku zycia Blizzarda
-- („attempt to compare a secret number value, execution tainted by GrimuarSetup”, CharacterFrame > ShowStatusBarText).
-- Bezpieczny przycisk z makrem /click nie zadzialal w Forever (gracz: „klikam I i nic sie nie dzieje”), wiec I i B
-- maja zwykly klawisz gry TOGGLECHARACTER0 (okno postaci otwiera sama gra), a torby idą za oknem postaci
-- w nastepnej klatce (C_Timer.After 0, osobno od kodu gry). Z naszego kodu (ikona torby) postac otwieramy tylko,
-- gdy paski ramki gracza nie trzymaja ukrytych wartosci z walki.
local openedByUs, bagsByChar = false, false
local bagFrames = {}

-- Baganator nie reaguje na OpenAllBags (OpenClose.lua otwiera tylko u kupca, na poczcie itd.).
-- 13.11 (gracz: „czasami dobrze wlaczy, czasami nie”): przelaczanie przez ToggleAllBags zgadywalo stan, okna Baganatora
-- powstaja dopiero przy pierwszym otwarciu, a jego przelacznik odrzuca szybkie powtorzenia (lastToggleTime). Teraz
-- jednoznaczne polecenia Baganatora: BagShow i BagHide (te same, co jego klawisze i szukanie). Bez Baganatora: torby gry.
local function setBags(open)
  local reg = _G.Baganator and Baganator.CallbackRegistry
  if reg and reg.TriggerEvent and pcall(reg.TriggerEvent, reg, open and "BagShow" or "BagHide") then return end
  if open then pcall(OpenAllBags) else pcall(CloseAllBags) end
end

-- 13.11: Forever Skin moze pokazac wlasne, przebudowane okno postaci (ForeverSkinCharacterFrame) zamiast okna gry
local function charWindow()
  local a = _G.ForeverSkinCharacterFrame
  if a and a:IsShown() then return a end
  local b = _G.CharacterFrame
  if b and b:IsShown() then return b end
  return nil
end
local function charShown() return charWindow() ~= nil end
local function hideCharacter()
  local w = charWindow()
  if not w then return end
  if w == _G.CharacterFrame then pcall(HideUIPanel, CharacterFrame) else pcall(w.Hide, w) end
end
G.charWindow = charWindow

local function barsSecret()
  local s = false
  pcall(function()
    local f = _G.PlayerFrame
    for _, b in ipairs({ f and f.healthbar, f and f.manabar }) do
      if b and issecretvalue and (issecretvalue(b.currValue) or issecretvalue(b:GetValue())) then s = true end
    end
  end)
  return s
end

local function openCharacter()
  if charShown() or InCombatLockdown() or barsSecret() then return end
  if pcall(ToggleCharacter, "PaperDollFrame") then openedByUs = true end
end

-- zapas (stare przypisanie z Bindings.xml): bez dotykania okna postaci, gdy paski sa ukryte
function GrimuarEkwipunek()
  if charShown() then
    if not barsSecret() then hideCharacter() end
    setBags(false)
    openedByUs = false
  else
    openCharacter()
    setBags(true)
  end
end

local EQ_KEY = "TOGGLECHARACTER0"

-- torby razem z oknem postaci (I, B, C albo przycisk postaci)
local charHooked = {}
local function hookCharacter()
  for _, cf in ipairs({ _G.CharacterFrame, _G.ForeverSkinCharacterFrame }) do
    if cf and not charHooked[cf] then
      charHooked[cf] = true
      cf:HookScript("OnShow", function()
        if GrimuarSetupDB.noBagsWithChar then return end
        C_Timer.After(0, function()
          if charShown() then
            bagsByChar = true
            setBags(true)
          end
        end)
      end)
      cf:HookScript("OnHide", function()
        if not bagsByChar then return end
        C_Timer.After(0, function()
          if not charShown() then
            bagsByChar = false
            setBags(false)
          end
        end)
      end)
    end
  end
  -- okno Forever Skin powstaje przy pierwszym otwarciu: podpinamy je zaraz po ToggleCharacter
  if not G.toggleCharHooked and ToggleCharacter then
    G.toggleCharHooked = true
    hooksecurefunc("ToggleCharacter", function()
      C_Timer.After(0.1, function()
        pcall(hookCharacter)
        if charShown() and not bagsByChar and not GrimuarSetupDB.noBagsWithChar then
          bagsByChar = true
          setBags(true)
        end
      end)
    end)
  end
end

function GrimuarPolestar()
  if SlashCmdList and SlashCmdList.POLESTAR then pcall(SlashCmdList.POLESTAR, "") end
end

function GrimuarOkno()
  if SlashCmdList and SlashCmdList.GRIMUAR then pcall(SlashCmdList.GRIMUAR, "") end
end

-- Klikniecie ikony torby (Baganator albo torby gry): postac otwiera sie obok, a znika razem z torbami
local function hookBagFrame(f)
  if not f or f.grimuarEq then return end
  f.grimuarEq = true
  bagFrames[#bagFrames + 1] = f
  -- 14.11: przy otwartym hubie (GrimuarUI) torba siedzi w zakladce Postac, bez okna postaci gry
  f:HookScript("OnShow", function()
    if G.hubOpen and G.hubOpen() then return end
    if not GrimuarSetupDB.noBagsWithChar then openCharacter() end
  end)
  f:HookScript("OnHide", function()
    if openedByUs and charShown() and not InCombatLockdown() and not barsSecret() then hideCharacter() end
    openedByUs = false
  end)
end

local function hookBags()
  for name, obj in pairs(_G) do
    if type(name) == "string" and type(obj) == "table" and name:find("^Baganator_%a+ViewBackpackViewFrame") and obj.HookScript then
      pcall(hookBagFrame, obj)
    end
  end
  if _G.ContainerFrame1 then pcall(hookBagFrame, ContainerFrame1) end
  if _G.ContainerFrameCombinedBags then pcall(hookBagFrame, ContainerFrameCombinedBags) end
end

-- ---------- klawisze okien (raz, z informacja, co bylo wczesniej) ----------
local KEYS = {
  { "I", EQ_KEY, "ekwipunek (torby i postać)" },
  { "B", EQ_KEY, "ekwipunek (torby i postać)" },
  { "J", "GRIMUAR_POLESTAR", "okno Polestara" },
  { "H", "MACRO Kamien", "Hearthstone" },
}

local function bindKeys()
  if (GrimuarSetupDB.keysV or 0) >= 3 or InCombatLockdown() then return end
  if G.ensureMacros then pcall(G.ensureMacros) end
  local changed, was = {}, {}
  for _, k in ipairs(KEYS) do
    local cur
    pcall(function() cur = GetBindingAction(k[1]) end)
    if cur ~= k[2] then
      if cur and cur ~= "" and k[1] ~= "B" and cur ~= "GRIMUAR_EKWIPUNEK" and cur ~= "CLICK GrimuarEqButton:LeftButton" then was[#was + 1] = k[1] .. " (było: " .. cur .. ")" end
      if pcall(SetBinding, k[1], k[2]) then changed[#changed + 1] = k[1] .. " " .. k[3] end
    end
  end
  pcall(function() SaveBindings(GetCurrentBindingSet()) end)
  GrimuarSetupDB.keysV = 3
  if #changed > 0 then
    say("klawisze: " .. table.concat(changed, ", ") .. "." .. (#was > 0 and (" Zastąpione: " .. table.concat(was, ", ") .. ".") or "") ..
      " Wszystkie klawisze: okno Grimuara, Wiedza > Klawisze.")
  end
end

-- ---------- czytelne oznaczenia klawiszy na przyciskach ----------
local function shortKey(key)
  if not key or key == "" then return "" end
  local s = key
  s = s:gsub("SHIFT%-", "S·"):gsub("ALT%-", "A·"):gsub("CTRL%-", "C·")
  s = s:gsub("BUTTON(%d+)", "M%1"):gsub("MOUSEWHEELUP", "MWU"):gsub("MOUSEWHEELDOWN", "MWD")
  s = s:gsub("NUMPAD", "N")
  return s
end

local function styleHotkey(b)
  local hk = b and b.HotKey
  if not hk then return end
  pcall(function()
    local cmd = b.commandName or b.bindingAction
    local key = cmd and GetBindingKey(cmd)
    if key then hk:SetText(shortKey(key)) end
    hk:SetFont(G.BF and G.BF() or "Fonts\\ARIALN.TTF", 13, "OUTLINE")
    hk:SetTextColor(0.95, 0.82, 0.48)
  end)
end

local function hookHotkeys()
  for _, prefix in ipairs({ "ActionButton", "MultiBarBottomLeftButton", "MultiBarBottomRightButton" }) do
    for i = 1, 12 do
      local b = _G[prefix .. i]
      if b and not b.grimuarHK then
        b.grimuarHK = true
        if type(b.UpdateHotkeys) == "function" then pcall(hooksecurefunc, b, "UpdateHotkeys", styleHotkey) end
        styleHotkey(b)
      end
    end
  end
  if type(ActionButton_UpdateHotkeys) == "function" then pcall(hooksecurefunc, "ActionButton_UpdateHotkeys", styleHotkey) end
end

-- ---------- strona okna: Wiedza > Klawisze ----------
local function keyOf(cmd, fallback)
  local k
  pcall(function() k = GetBindingKey(cmd) end)
  if not k then return fallback or "—" end
  return (k:gsub("SHIFT%-", "Shift+"):gsub("ALT%-", "Alt+"):gsub("CTRL%-", "Ctrl+"))
end

local function pageKlawisze(P)
  P.M("Klawisze odczytane z gry. Zmienisz je w Esc > Options > Keybindings (polecenia Grimuara są w sekcji Grimuar).")
  P.H("Walka")
  P.KV({ { keyOf("ACTIONBUTTON1", "1"), "Frostbolt (wcześniej Fireball)" }, { keyOf("ACTIONBUTTON2", "2"), "Fire Blast" },
    { keyOf("ACTIONBUTTON3", "3"), "Ice Lance" }, { keyOf("ACTIONBUTTON4", "4"), "Cone of Cold" }, { keyOf("ACTIONBUTTON6", "6"), "Blizzard" },
    { keyOf("MULTIACTIONBAR1BUTTON1", "Q"), "Frost Nova" }, { keyOf("MULTIACTIONBAR1BUTTON3", "R"), "owca (najpierw focus)" },
    { keyOf("MULTIACTIONBAR1BUTTON4", "F"), "Counterspell" }, { keyOf("MULTIACTIONBAR1BUTTON5", "G"), "różdżka" },
    { keyOf("MULTIACTIONBAR1BUTTON11", "Shift+F"), "Eureka!" }, { keyOf("MULTIACTIONBAR1BUTTON9", "Shift+Q"), "Ice Barrier" } })
  P.H("Ucieczka i ratunek")
  P.KV({ { keyOf("MULTIACTIONBAR1BUTTON2", "E"), "Blink" }, { keyOf("MULTIACTIONBAR1BUTTON10", "Shift+E"), "Ice Block" },
    { keyOf("MULTIACTIONBAR1BUTTON6", "T"), "Escape Artist" }, { keyOf("MULTIACTIONBAR1BUTTON12", "Shift+R"), "Mana Shield, od 39 Cold Snap" },
    { keyOf("MACRO Focus", "Alt+R"), "focus na mobie pod kursorem" } })
  P.H("Mana i jedzenie")
  P.KV({ { keyOf("MULTIACTIONBAR1BUTTON7", "Z"), "picie (najlepsza woda)" }, { keyOf("MULTIACTIONBAR1BUTTON8", "X"), "jedzenie" },
    { keyOf("MULTIACTIONBAR2BUTTON10", "Shift+X"), "Evocation" }, { keyOf("ACTIONBUTTON10", "0"), "Conjure Water" },
    { keyOf("MACRO Bandaz", "C"), "bandaż: na osobę pod myszką, inaczej na siebie (najlepszy z torby)" },
    { keyOf("MACRO Mikstura", "V"), "mikstura leczenia; Shift+V: mikstura many" },
    { keyOf("MACRO Sledzenie", "Y"), "śledzenie na minimapie: zioła albo ruda" } })
  P.H("Okna")
  P.KV({ { "I", "ekwipunek: torby i postać razem (też B)" },
    { keyOf("TOGGLESPELLBOOK", "P"), "księga czarów" }, { keyOf("TOGGLETALENTS", "N"), "talenty" }, { keyOf("TOGGLEPROFESSIONBOOK", "K"), "profesje" },
    { keyOf("TOGGLEWORLDMAP", "M"), "mapa" }, { keyOf("TOGGLEQUESTLOG", "L"), "dziennik questów" },
    { keyOf("GRIMUAR_POLESTAR", "J"), "okno Polestara" }, { keyOf("MACRO Kamien", "H"), "Hearthstone" } })
  P.H("Grupa (myszka na ramce)")
  P.KV({ { keyOf("ACTIONBUTTON9", "9"), "Arcane Intellect na osobę pod myszką" }, { keyOf("ACTIONBUTTON12", "="), "zdejmij klątwę z osoby pod myszką" } })
  P.H("Grimuar")
  P.KV({ { "Shift+G", "okno Grimuara" }, { (G.vendorKey and G.vendorKey()) or "Alt+V", "najbliższy kupiec" },
    { "Esc", "menu z przyciskami Grimuar, Plan sesji, Kończę grę" } })
  P.M("Na przyciskach skróty: S· = Shift, A· = Alt, C· = Ctrl, M4 i M5 = boczne przyciski myszy.")
end

local ev = CreateFrame("Frame")
ev:RegisterEvent("PLAYER_LOGIN")
ev:RegisterEvent("UPDATE_BINDINGS")
ev:SetScript("OnEvent", function(_, event)
  if event == "PLAYER_LOGIN" then
    C_Timer.After(5, function() pcall(hookBags) pcall(hookHotkeys) pcall(hookCharacter) end)
    C_Timer.After(14, function() pcall(bindKeys) end)
  else
    for _, prefix in ipairs({ "ActionButton", "MultiBarBottomLeftButton", "MultiBarBottomRightButton" }) do
      for i = 1, 12 do styleHotkey(_G[prefix .. i]) end
    end
  end
end)

G.pageKlawisze = pageKlawisze
G.shortKey = shortKey
