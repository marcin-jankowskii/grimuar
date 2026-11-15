-- Grimuar: modul Grupa (13.11, punkt 1 „pominietych tematow”): gra w grupie od strony interfejsu.
-- 1) ramki druzyny w stylu rajdowym (Edit Mode w Ekran.lua) i CVary ramek: kolory klas, tylko klatwy do zdjecia,
--    podswietlenie aggro, pasek many (widac mane healera);
-- 2) makra „na ramke pod myszka”: Intelekt (klawisz 9) i Klatwa (klawisz =) — myszka na ramke czlonka grupy + klawisz;
-- 3) pasek Grimuara (poza walka): kto ma klatwe do zdjecia (Teraz), komu brakuje Arcane Intellect (Postac);
-- 4) wyglad: zlote narozniki na ramkach druzyny, czcionka motywu na imionach;
-- 5) strona okna: Swiat > Grupa: zadania maga, gildia i spolecznosc (R16: kanal LookingForGroup, ogloszenie, skroty, szablony).
-- R18: w walce, encounterze i meczu PvP aury czlonkow grupy sa ukryte (brak wyniku wyglada jak „brak buffa”), wiec wtedy nie pytamy.
-- Midnight: dane aur w walce bywaja ukryte, wiec wszystko liczymy poza walka, a ukryte wartosci pomijamy.
local ADDON_NAME, G = ...
local say = G.say

local GROUP_CVARS = {
  { "raidFramesDisplayClassColor", "1", "ramki grupy w kolorach klas" },
  { "raidFramesDisplayOnlyDispellableDebuffs", "1", "na ramkach grupy tylko klątwy, które zdejmiesz" },
  { "raidFramesDisplayAggroHighlight", "1", "ramka świeci, gdy mob bije tę osobę" },
  { "raidFramesDisplayPowerBars", "1", "pasek many pod ramkami grupy" },
  -- R18 (13.11): wskaznik dispel z Midnight, tylko na tym, co zdejmiesz; debuffy musza byc wlaczone
  { "raidFramesDisplayDebuffs", "1", "debuffy na ramkach grupy" },
  { "raidFramesDispelIndicatorType", "1", "znacznik tylko na klątwach, które zdejmiesz" },
  { "raidFramesDispelIndicatorOverlay", "1", "ramka w kolorze klątwy" },
  { "raidFramesDispelIndicatorOverlayAnimation", "1", "znacznik klątwy pulsuje" },
  { "raidFramesDispelIndicatorAnimatedBorder", "1", "animowana ramka klątwy" }, -- R19: gdy CVaru brak, pomijamy
  { "raidOptionDisplayPets", "0", "bez pupili na ramkach" },
}
local GROUP_VER = 2

local MANA_CLASSES = { MAGE = true, PRIEST = true, WARLOCK = true, DRUID = true, SHAMAN = true, PALADIN = true, HUNTER = true }

local function secret(v)
  local ok, r = pcall(function() return issecretvalue and issecretvalue(v) end)
  return ok and r or false
end

local function safe(f, ...)
  local ok, r = pcall(f, ...)
  if not ok or secret(r) then return nil end
  return r
end

local function keyOf(cmd, fallback)
  local k = safe(GetBindingKey, cmd)
  if not k then return fallback end
  return (k:gsub("SHIFT%-", "Shift+"):gsub("ALT%-", "Alt+"):gsub("CTRL%-", "Ctrl+"))
end

-- ---------- czlonkowie grupy w zasiegu wzroku ----------
local function members(withPlayer)
  local out = {}
  if withPlayer then out[1] = "player" end
  local raid = safe(IsInRaid)
  local n = (raid and safe(GetNumGroupMembers)) or safe(GetNumSubgroupMembers) or 0
  for i = 1, n do
    local u = (raid and "raid" or "party") .. i
    if safe(UnitExists, u) and not safe(UnitIsUnit, u, "player") and safe(UnitIsVisible, u)
      and safe(UnitIsConnected, u) and not safe(UnitIsDeadOrGhost, u) then
      out[#out + 1] = u
    end
  end
  return out
end

local function nameOf(u)
  if u == "player" then return "Ty" end
  local n = safe(UnitName, u)
  return (type(n) == "string" and n ~= "") and n or "osoba z grupy"
end

-- R18: C_Secrets.ShouldAurasBeSecret() = true w walce, encounterze i meczu PvP
local function aurasHidden()
  if InCombatLockdown() then return true end
  local ok, r = pcall(function() return C_Secrets and C_Secrets.ShouldAurasBeSecret and C_Secrets.ShouldAurasBeSecret() end)
  return ok and r == true
end

local function auraByName(u, name)
  local found, unknown = false, false
  local ok, r = pcall(function()
    if C_UnitAuras and C_UnitAuras.GetAuraDataBySpellName then return C_UnitAuras.GetAuraDataBySpellName(u, name, "HELPFUL") end
    if AuraUtil and AuraUtil.FindAuraByName then return AuraUtil.FindAuraByName(name, u, "HELPFUL") end
  end)
  if not ok or secret(r) then unknown = true elseif r ~= nil then found = true end
  return found, unknown
end

local function hasIntellect(u)
  local a, ua = auraByName(u, "Arcane Intellect")
  if a then return true, false end
  local b, ub = auraByName(u, "Arcane Brilliance")
  if b then return true, false end
  return false, ua or ub
end

-- Filtr HARMFUL|RAID zwraca tylko to, co TY mozesz zdjac (mag: klatwy, gdy znasz Remove Lesser Curse)
local function curseOn(u)
  local hit
  pcall(function()
    if not (C_UnitAuras and C_UnitAuras.GetAuraDataByIndex) then return end
    for i = 1, 40 do
      local a = C_UnitAuras.GetAuraDataByIndex(u, i, "HARMFUL|RAID")
      if a == nil or secret(a) then return end
      local nm = a.name
      hit = (not secret(nm) and type(nm) == "string") and nm or "klątwa"
      return
    end
  end)
  return hit
end

-- ---------- kroki na pasku ----------
local aiSnoozeUntil = 0

local function partySteps(add, phase)
  if GrimuarSetupDB.noGroupHelp then return end
  if aurasHidden() or not safe(IsInGroup) or safe(UnitIsDeadOrGhost, "player") then return end
  if phase == "pilne" then
    if not G.knownSpellId("Remove Lesser Curse") then return end
    local cursed = {}
    for _, u in ipairs(members(true)) do
      local c = curseOn(u)
      if c then cursed[#cursed + 1] = nameOf(u) .. " (" .. c .. ")" end
    end
    if #cursed > 0 then
      local key = keyOf("ACTIONBUTTON12", "=")
      add("klatwa", "Zdejmij klątwę: " .. table.concat(cursed, ", ", 1, math.min(3, #cursed)) .. ".",
        "Najedź myszką na ramkę tej osoby i wciśnij " .. key .. " (Remove Lesser Curse). Bez myszki na ramce zdejmie z celu albo z Ciebie. " ..
        "Klątwy w grupie zdejmujesz Ty: kapłan ich nie zdejmie.", nil, nil, (#cursed > 1) and (#cursed .. " osoby") or nil)
    end
    return
  end
  if not G.knownSpellId("Arcane Intellect") or GetTime() < aiSnoozeUntil then return end
  local miss = {}
  for _, u in ipairs(members(false)) do
    local okC, cls = pcall(function() return select(2, UnitClass(u)) end)
    if okC and not secret(cls) and MANA_CLASSES[cls] then
      local has, unknown = hasIntellect(u)
      if not has and not unknown then miss[#miss + 1] = nameOf(u) end
    end
  end
  if #miss == 0 then return end
  local brill = G.knownSpellId("Arcane Brilliance") and safe(IsInRaid)
  local who = (#miss <= 3) and table.concat(miss, ", ") or (#miss .. " osób")
  add("ai-grupa", (brill and "Arcane Brilliance: Shift+" .. keyOf("ACTIONBUTTON9", "9") .. ", rzuć na siebie" or "Arcane Intellect dla: " .. who) .. ".",
    brill and "Brilliance kosztuje Arcane Powder (sprzedawca reagentów). Komu brakuje: " .. who .. "." or
      ("Najedź myszką na ramkę tej osoby i wciśnij " .. keyOf("ACTIONBUTTON9", "9") ..
      ". Tylko klasy z maną: wojownik i łotrzyk go nie potrzebują. Trwa długo, więc rzuć raz przed pierwszym pullem."),
    { { "Później", function()
      aiSnoozeUntil = GetTime() + 600
      if G.refreshAll then pcall(G.refreshAll) end
    end } }, nil, (#miss > 1) and (#miss .. " osób") or nil)
end

-- ---------- CVary ramek (raz; tylko te, ktore gra zna) ----------
local function groupCVars(force)
  if not force and (GrimuarSetupDB.groupV or 0) >= GROUP_VER then return end
  if InCombatLockdown() then return end
  local done = {}
  for _, c in ipairs(GROUP_CVARS) do
    local cur
    pcall(function() cur = C_CVar and C_CVar.GetCVar(c[1]) or GetCVar(c[1]) end)
    if cur ~= nil and tostring(cur) ~= c[2] then
      if pcall(function() if C_CVar and C_CVar.SetCVar then C_CVar.SetCVar(c[1], c[2]) else SetCVar(c[1], c[2]) end end) then
        done[#done + 1] = c[3]
      end
    end
  end
  GrimuarSetupDB.groupV = GROUP_VER
  if #done > 0 then say("ramki grupy: " .. table.concat(done, ", ") .. ".") end
end

-- ---------- wyglad ramek druzyny ----------
local function styleFrames()
  if GrimuarSetupDB.noSkins or InCombatLockdown() then return end
  local f = _G.CompactPartyFrame
  if f and not f.grimuarRunes and G.addRuneCorners then
    f.grimuarRunes = true
    pcall(G.addRuneCorners, f, 14)
  end
end

local function nameFont(f)
  if GrimuarSetupDB.noSkins or GrimuarSetupDB.noGameFonts or not G.customFonts then return end
  pcall(function()
    local nm = f and f.GetName and f:GetName()
    if type(nm) ~= "string" or not (nm:find("^CompactParty") or nm:find("^CompactRaid")) then return end
    if f.name and f.name.SetFont then f.name:SetFont(G.BF(), 12, "") end
  end)
end

-- ---------- gildia i spolecznosc (R16, 13.11) ----------
local DG_SHORT = { ["Hall of Thanes"] = "HoT", ["Ruins of Lordaeron"] = "RoL", ["Deadmines"] = "DM", ["Shadowfang Keep"] = "SFK",
  ["Blackfathom Deeps"] = "BFD", ["Stormwind Stockade"] = "Stocks", ["Excavation Site: Wetlands"] = "ESW", ["City of Dalaran"] = "CoD",
  ["Gnomeregan"] = "Gnomer", ["Razorfen Kraul"] = "RFK", ["SM Graveyard"] = "SM GY", ["SM Library"] = "SM Lib",
  ["SM Armory i Cathedral"] = "SM Arm/Cath", ["Razorfen Downs"] = "RFD", ["Uldaman"] = "Ulda", ["Zul'Farrak"] = "ZF",
  ["Maraudon"] = "Mara", ["Sunken Temple"] = "ST", ["Blackrock Depths"] = "BRD", ["Lower Blackrock Spire"] = "LBRS",
  ["Upper Blackrock Spire"] = "UBRS", ["Stratholme"] = "Strat", ["Scholomance"] = "Scholo" }

local function lfgChannel()
  local id = safe(GetChannelName, "LookingForGroup")
  return (type(id) == "number" and id > 0) and id or nil
end

local function openChat(text)
  local ok = pcall(function()
    if ChatFrame_OpenChat then ChatFrame_OpenChat(text)
    elseif ChatFrameUtil and ChatFrameUtil.OpenChat then ChatFrameUtil.OpenChat(text)
    else error("brak") end
  end)
  if not ok then say("skopiuj do czatu: " .. text) end
end

local function joinLfg()
  pcall(JoinChannelByName, "LookingForGroup")
  C_Timer.After(1, function()
    local id = lfgChannel()
    say(id and ("kanał grup: [" .. id .. ". LookingForGroup]. Ogłoszenie: okno Grimuara, Świat > Grupa.") or "nie udało się dołączyć: wpisz /join LookingForGroup.")
    if G.refreshAll then pcall(G.refreshAll) end
  end)
end

-- Ogloszenie na kanal grup (gotowe w polu czatu: Enter wysyla, mozna poprawic przed wyslaniem)
local function lfgText()
  local l = UnitLevel("player") or 1
  local dg = G.bestDungeon and G.bestDungeon(l)
  local where = dg and (DG_SHORT[dg[3]] or dg[3]) or "dungeon"
  local extra = {}
  if G.knownSpellId("Polymorph") then extra[#extra + 1] = "can sheep" end
  if G.knownSpellId("Conjure Water") then extra[#extra + 1] = "water + AI for group" end
  local id = lfgChannel()
  return (id and ("/" .. id .. " ") or "") .. "LFG " .. where .. ", mage " .. l .. " DPS" .. (#extra > 0 and (", " .. table.concat(extra, ", ")) or "")
end

local function applyText(lang)
  local l = UnitLevel("player") or 1
  if lang == "en" then
    return "Hi! Gnome Frost Mage, level " .. l .. ", Alliance EU PvP. I play 5-10 h a week, evenings CET. Looking for a friendly guild to level, do dungeons and raid later. Polish, good English, Discord ok."
  end
  return "Cześć! Gnom, Frost Mage, " .. l .. " poziom, Przymierze EU PvP. Gram 5-10 h w tygodniu, wieczorami. Szukam spokojnej gildii do levelowania, lochów i raidów później. Mam Discorda."
end

local function pageGildia(P)
  P.H("Kanał grup i ogłoszenie")
  local id = lfgChannel()
  P.M(id and ("Jesteś na kanale grup: [" .. id .. ". LookingForGroup]. Lochy zbiera się tam i na Discordzie WoW Forever EU PvP (Dungeon Findera nie ma).")
    or "Kanał grup trzeba dołączyć ręcznie. Lochy zbiera się tam i na Discordzie WoW Forever EU PvP (Dungeon Findera nie ma).")
  local row = {}
  if not id then row[#row + 1] = { "Dołącz do LookingForGroup", joinLfg } end
  row[#row + 1] = { "Ogłoszenie: szukam grupy", function() openChat(lfgText()) end }
  P.BTNROW(row)
  P.M("Przycisk wpisuje tekst do czatu, a Enter go wysyła. Zbierasz grupę sam? Napisz: LF2M SFK, need tank + heal, PST.")
  P.KV({ { "LFG / LFM / LF2M", "szukam grupy / szukamy graczy / brakuje dwóch" }, { "PST, inv", "napisz do mnie / zaproś mnie" },
    { "WTS / WTB", "sprzedam / kupię" }, { "MS > OS", "najpierw łup dla głównego speca" }, { "SR", "soft reserve: rezerwacja łupu przed raidem" },
    { "CC, sheep, OOM", "kontrola tłumu, owca, brak many" } })
  P.H("Gildia: teraz towarzyska, raidowa koło 50")
  P.M("Teraz szukaj gildii casual, która chodzi wieczorami na lochy. Raidy ruszają 9 grudnia, ale przy 5–10 h tygodniowo 60 poziom wypadnie ok. lutego–kwietnia 2027. Gildię raidową wybierz koło 50: najwyżej 2 wieczory, zapisy, soft reserve albo EPGP.")
  P.KV({ { "Gdzie szukać", "J > Guild Finder (jeśli serwer go włączył), forum EU Community Connections, Discord WoW Forever EU PvP" },
    { "Polskie (Przymierze, PvP)", "The Ashen Banner (raidy 20–24, gra bez poradników), Innominate (21+). Obie na Discordzie" },
    { "Sprawdź", "EU, PvP, Przymierze; godziny w czasie PL; zasady łupów; czy chodzą na lochy z levelującymi; język i Discord" },
    { "Czerwone flagi", "GDKP (zakazane w Forever), płatne członkostwo, brak zasad łupów, prośby o hasło lub kod" } })
  P.BTNROW({ { "Zgłoszenie po polsku", function() openChat(applyText("pl")) end }, { "Zgłoszenie po angielsku", function() openChat(applyText("en")) end } })
  P.M("Tekst trafia do czatu: dopisz przed nim /w Imię Nazwisko oficera albo skopiuj na Discord. Pełne szablony są na stronie Grimuar maga.")
  P.H("Znajomi")
  P.M("Po dobrym lochu: prawy klik na imię tanka albo healera > Add Friend i dopisz notatkę (np. „tank 22, wieczory”). Imiona w Forever mają dwie części, więc najpewniej przez menu. Przed następnym lochem napisz najpierw do nich.")
end

-- otwiera okno Grimuara na danej stronie
local function showPage(key)
  local p = G.getPanel and G.getPanel()
  if not (p and p:IsShown()) and G.togglePanel then pcall(G.togglePanel) end
  if G.selectTab then pcall(G.selectTab, key) end
end

local guildSnooze = 0
local wasInDungeonGroup = false
local function socialSteps(add)
  if GrimuarSetupDB.noGroupHelp or InCombatLockdown() then return end
  local l = UnitLevel("player") or 1
  if l >= 13 and not lfgChannel() and not GrimuarSetupDB.noLfgStep then
    add("grupa-kanal", "Dołącz do kanału grup (LookingForGroup).", "Lochy zbiera się na tym kanale, bo w Forever nie ma Dungeon Findera. Gra nie dołącza go sama.",
      { { "Dołącz", joinLfg }, { "Nie chcę", function() GrimuarSetupDB.noLfgStep = true if G.refreshAll then pcall(G.refreshAll) end end } })
  end
  if l >= 12 and not safe(IsInGuild) and time() > (GrimuarSetupDB.guildSnooze or 0) and GetTime() > guildSnooze then
    add("gildia", "Poszukaj gildii, która chodzi na lochy.", "Gildia to grupy na lochy bez czekania i pomoc. Gdzie szukać i jak napisać: okno Grimuara, Świat > Grupa.",
      { { "Pokaż", function() showPage("grupa") end },
        { "Za tydzień", function() GrimuarSetupDB.guildSnooze = time() + 7 * 86400 if G.refreshAll then pcall(G.refreshAll) end end } })
  end
end

-- Po lochu (wyjscie z grupy): przypomnienie o znajomych, raz na loch
local raidTipShown = false
local function raidTip()
  if raidTipShown or not safe(IsInRaid) or not G.knownSpellId("Remove Lesser Curse") then return end
  raidTipShown = true
  if G.showToast then pcall(G.showToast, "raid: klątwę w walce pokazuje ramka w kolorze klątwy. Myszka na ramce + " .. keyOf("ACTIONBUTTON12", "=") .. ".", "klatwa", false) end
end

local function afterDungeon()
  local ok, inst, kind = pcall(IsInInstance)
  local inDng = ok and inst and kind == "party"
  if inDng and safe(IsInGroup) then wasInDungeonGroup = true return end
  if wasInDungeonGroup and not safe(IsInGroup) then
    wasInDungeonGroup = false
    if G.showToast then pcall(G.showToast, "dobry tank albo healer? Prawy klik na imię > Add Friend, dopisz notatkę. Następnym razem grupa w minutę.", "grupa", false) end
  end
end

-- ---------- strona okna: Swiat > Grupa ----------
local function pageGrupa(P)
  P.M("Grupa to lochy, a od 9 grudnia raidy. Ramki drużyny ustawia Grimuar (układ ekranu Runy): kolory klas, tylko klątwy do zdjęcia, mana healera pod imieniem.")
  P.H("Twoje zadania w grupie")
  P.KV({ { "Przed pullem", "Arcane Intellect na klasy z maną (" .. keyOf("ACTIONBUTTON9", "9") .. ", myszka na ramce), woda dla healera" },
    { "Księżyc", "Twoja owca: Alt+R na mobie z księżycem, potem R. Bez Novy i AoE obok owcy" },
    { "Klątwy", "zdejmujesz tylko Ty: myszka na ramce + " .. keyOf("ACTIONBUTTON12", "=") .. " (Remove Lesser Curse od 18)" },
    { "Przerwania", "F przerywa leczenie i strach u mobów; na focus (Alt+R) działa bez zmiany celu" },
    { "Aggro", "ramka świeci na czerwono = mob bije tę osobę. Ty? Różdżka (G) albo Ice Block" } })
  P.H("Ramki pod myszką")
  P.M("Makra Intelekt i Klatwa działają na ramkę, nad którą trzymasz myszkę. Bez myszki na ramce: na cel, a bez celu na Ciebie. Nie trzeba klikać ramki ani zmieniać celu.")
  P.H("Woda dla grupy")
  P.M("Zrób stack wody dla healera, zanim wejdziecie (0). Potem kliknij healera (cel) i przycisk niżej: otworzy się wymiana. Healer z maną to szybsze pulle.")
  P.BTNROW({ { "Wymiana z celem", function()
    if InCombatLockdown() then say("wymiana po walce.") return end
    local okP = safe(UnitIsPlayer, "target") and safe(UnitIsFriend, "player", "target")
    if okP then pcall(InitiateTrade, "target") else say("najpierw kliknij gracza z grupy (cel).") end
  end } })
  P.H("Raid (R19)")
  P.B({ "Klątwy w raidzie zdejmujesz Ty i druidzi. Najpierw tank, potem healer. W walce klątwę pokazuje ramka w kolorze klątwy.",
    "Nie bij od pierwszej sekundy. Aggro przejmiesz, gdy masz o 30% zagrożenia więcej niż tank (pasek Threat).",
    "Ice Block ratuje życie, ale nie kasuje aggro. Po 10 s mob wróci do Ciebie.",
    "Amplify Magic na tanka tylko na fizycznym bossie. Na Onyxii nie: ona bije ogniem.",
    "Owce: każdy mag ma swój znak, ustala go lider. Arcane Brilliance: Shift+" .. keyOf("ACTIONBUTTON9", "9") .. " (Arcane Powder)." })
  P.M("Klikanie ramek bez makr: Esc > Options > Keybindings > Click Casting (np. Shift+lewy = klątwa, Shift+prawy = Intellect). Wbudowane w grę, addon niepotrzebny.")
  pageGildia(P)
end

local ev = CreateFrame("Frame")
ev:RegisterEvent("PLAYER_LOGIN")
ev:RegisterEvent("GROUP_ROSTER_UPDATE")
ev:RegisterEvent("PLAYER_REGEN_ENABLED")
ev:RegisterEvent("PLAYER_ENTERING_WORLD")
ev:SetScript("OnEvent", function(_, event)
  if event == "PLAYER_LOGIN" then
    C_Timer.After(12, function() pcall(groupCVars) end)
    C_Timer.After(6, function() pcall(styleFrames) end)
    if type(CompactUnitFrame_UpdateName) == "function" then pcall(hooksecurefunc, "CompactUnitFrame_UpdateName", nameFont) end
  else
    C_Timer.After(1, function() pcall(styleFrames) pcall(afterDungeon) pcall(raidTip) end)
  end
end)

G.GROUP_CVARS = GROUP_CVARS
G.partySteps = partySteps
G.groupCVars = groupCVars
G.pageGrupa = pageGrupa
G.socialSteps = socialSteps
G.lfgText = lfgText
G.showPage = showPage
