-- Grimuar: tresci dla kazdej klasy i rasy (R27 E2/E5 dokonczenie, 14.11; gracz: „jak reszte skonczysz”).
-- Strony okna Grimuara (Talenty, Czary, Walka, PvP, Sprzet) i etapy planu powstaly pod maga Frost z Dun Morogh.
-- Dla innych klas strony rysuja sie z aktywnego buildu (G.BD: plan talentow, trener, combo, porady PvP), a dla innych
-- ras albo klas etapy planu sa neutralne (te same id s1–s7, wiec odhaczone punkty zostaja). Samouczek pomija kroki
-- pisane pod maga. Mag z Dun Morogh widzi wszystko jak dotad.
local ADDON_NAME, G = ...

local function isMage() local _, c = UnitClass("player") return c == "MAGE" end
local function dunMorogh()
  local _, race = UnitRace("player")
  return (race == "Gnome" or race == "Dwarf") and UnitFactionGroup("player") == "Alliance"
end
local function bname() return (G.BD_META and G.BD_META.name) or "aktywny build" end

-- ---------- strony okna z aktywnego buildu ----------
local function genTalenty(l)
  G.T("Plan talentów: " .. bname() .. ". Punkt na poziom od 10, razem 51. Plan zmienisz w hubie: Buildy > Duplikuj do edycji.")
  G.H("Poziom po poziomie")
  local any = false
  for lv = 10, 60 do
    local t = G.TALENT_AT and G.TALENT_AT[lv]
    if t then
      any = true
      local note = G.TALENT_NOTE_AT and G.TALENT_NOTE_AT[lv]
      G.T(G.lvCol(lv, l) .. lv .. "|r   " .. t .. (note and (G.C_MUTED .. "  " .. note .. "|r") or ""), 13, 2)
    end
  end
  if not any then G.M("Ten build nie ma planu talentów. Wybierz szkic z Polestara albo zapisz swoje talenty (hub > Buildy).") end
end
local function genCzary(l)
  G.T("Trener według buildu: " .. bname() .. ".")
  local sp = G.BD and G.BD.spells or {}
  if #sp > 0 then
    G.H("Czary")
    for _, s in ipairs(sp) do G.T(G.lvCol(s[1], l) .. s[1] .. "|r   " .. s[2] .. ((s[3] or "") ~= "" and (G.C_MUTED .. "  " .. s[3] .. "|r") or ""), 13, 2) end
  elseif G.BD_META and G.BD_META.trainAll then
    G.M("Ten build kupuje u trenera wszystko (przycisk „Kup wg buildu”).")
  else
    G.M("Ten build nie ma listy czarów. U trenera pomoże przycisk „Kup wg buildu”.")
  end
end
local function genWalka()
  local steps = G.BD and G.BD.steps or {}
  if #steps == 0 then G.M("Ten build nie ma ściągi walki. Dodasz ją, edytując kopię buildu.") return end
  G.H("Combo: " .. bname())
  local list = {}
  for _, s in ipairs(steps) do list[#list + 1] = (s.spell or s.text or "?") .. (s.hint and ("  — " .. s.hint) or "") end
  G.N(list)
  local rescue = G.BD.rescue or {}
  if #rescue > 0 then
    G.H("Ratunek")
    list = {}
    for _, s in ipairs(rescue) do list[#list + 1] = (s.spell or s.text or "?") .. (s.hint and ("  — " .. s.hint) or "") end
    G.B(list)
  end
end
local CLASS_PL = { WARRIOR = "Wojownik", ROGUE = "Łotrzyk", PALADIN = "Paladyn", HUNTER = "Łowca", SHAMAN = "Szaman", DRUID = "Druid",
  PRIEST = "Kapłan", WARLOCK = "Czarnoksiężnik", MAGE = "Mag" }
local function genPvP()
  local any = false
  for _, band in ipairs({ { G.BD and G.BD.pvp, "Do 39 poziomu" }, { G.BD and G.BD.pvp60, "Od 40 poziomu" } }) do
    if band[1] and next(band[1]) then
      any = true
      G.H(band[2])
      local list = {}
      for cls, txt in pairs(band[1]) do list[#list + 1] = (CLASS_PL[cls] or cls) .. ": " .. tostring(txt) end
      table.sort(list)
      G.B(list)
    end
  end
  if not any then G.M("Ten build nie ma porad PvP. Ogólnie: walcz 1 na 1 i ze swojego poziomu, w strefie spornej trzymaj się grupy.") end
end
local function genSprzet()
  G.H("Statystyki")
  local st = G.BD_META and G.BD_META.stats
  G.T("Skala Pawn z buildu: " .. tostring(st and (st.pawn or st.from) or "brak (Pawn użyje domyślnej skali klasy)") .. ".")
  G.M("Pawn pokazuje zieloną strzałkę na lepszym przedmiocie. Łupy z lochów: hub > Wyprawy.")
  G.H("Raidy od 9 grudnia")
  G.KV({ { "Barrow Deeps", "10 osób, 8 bossów" }, { "Hyjal Summit", "20 osób, 13 bossów" }, { "Onyxia's Lair", "40 osób; Drakefire Amulet" } })
end

local function wrap(key, gen)
  local orig = G[key]
  G[key] = function(...)
    if isMage() then return orig(...) end
    return gen(...)
  end
end
wrap("buildTalenty", genTalenty)
wrap("buildCzary", genCzary)
wrap("buildWalka", genWalka)
wrap("buildPvP", genPvP)
wrap("buildSprzet", genSprzet)

-- ---------- etapy planu bez maga z Dun Morogh ----------
local NEUTRAL = {
  { id = "s1", from = 1, to = 9, title = "Start", zones = "strefa startowa Twojej rasy",
    focus = { "Czytaj opisy questów, Polestar prowadzi po kolei.", "Trener klasy co 2 poziomy (przycisk „Kup wg buildu”).", "Szare łupy sprzedaje Leatrix u kupca." },
    todo = { "Hearthstone przypisany w pierwszej karczmie", "Dwie profesje zbierackie u trenerów", "Pierwsza torba założona" } },
  { id = "s2", from = 10, to = 19, title = "Pierwsze talenty", zones = "strefy według przewodnika Polestara",
    focus = { "Talenty od 10 według buildu (hub > Buildy, złoty talent to następny punkt).", "Lochy z questami w grupie dają najwięcej (hub > Wyprawy)." },
    todo = { "Pierwszy punkt talentu wydany", "Pierwszy loch z questami" } },
  { id = "s3", from = 20, to = 29, title = "Pierwsze lochy", zones = "strefy według przewodnika Polestara",
    focus = { "Od 20 więcej czarów u trenera i drugie lochy.", "Profesje podnoś po drodze (hub > Rzemiosło, zadania profesji)." },
    todo = { "Profesje na 75 (Czeladnik)", "Hearthstone w strefie questów" } },
  { id = "s4", from = 30, to = 39, title = "Środek drogi", zones = "strefy według przewodnika Polestara",
    focus = { "Lochy z questami co wieczór ze znajomymi (hub > Wyprawy > Wieczór).", "Złoto odkładaj na wierzchowca (40)." },
    todo = { "Loty w nowych strefach", "Złoto na wierzchowca" } },
  { id = "s5", from = 40, to = 49, title = "Wierzchowiec", zones = "strefy według przewodnika Polestara",
    focus = { "Na 40 jazda u trenera Twojej rasy.", "Talenty i sprzęt według buildu (Pawn)." },
    todo = { "Wierzchowiec", "Profesje na 225 (Ekspert)" } },
  { id = "s6", from = 50, to = 59, title = "Ostatnia prosta", zones = "strefy według przewodnika Polestara",
    focus = { "Lochy z łupami pod 60.", "Odpoczynek: wylogowanie w karczmie daje podwójne XP." },
    todo = { "Profesje na 300", "Sprzęt na 60 z lochów" } },
  { id = "s7", from = 60, to = 60, title = "Poziom 60", zones = "lochy i rajdy",
    focus = { "Rajdy od 9 grudnia: Barrow Deeps (10 osób) na start (hub > Wyprawy).", "Build na 60: hub > Buildy." },
    todo = { "Attunement do Onyxii", "Pierwszy rajd" } },
}
local ev = CreateFrame("Frame")
ev:RegisterEvent("PLAYER_LOGIN")
ev:SetScript("OnEvent", function()
  if isMage() and dunMorogh() then return end
  local S = G.STAGES
  if type(S) ~= "table" then return end
  wipe(S)
  for i, s in ipairs(NEUTRAL) do S[i] = s end
  G.stagesNeutral = true
  -- samouczek: bez krokow pisanych pod maga
  if not isMage() and type(G.TUTORIAL) == "table" then
    local MAGE_WORDS = { "Frostbolt", "Frost Nova", "Blink", "Polymorph", "Ice Lance", "Arcane Intellect", "Conjure", "Frost Armor", "Ice Block", "Evocation", "Combo Frosta" }
    for i = #G.TUTORIAL, 1, -1 do
      local text = tostring(G.TUTORIAL[i][3] or "") .. " " .. tostring(G.TUTORIAL[i][2] or "")
      for _, w in ipairs(MAGE_WORDS) do
        if text:find(w, 1, true) then table.remove(G.TUTORIAL, i) break end
      end
    end
  end
end)

-- ---------- krotkie komendy (R27 E5) ----------
-- /gr <nazwa> dziala zawsze (Events.lua). Krotkie /plan, /loch itd. tylko w trybie prywatnym (Grimuar_Osobiste),
-- bo w wersji publicznej moglyby zajac komendy innych addonow. Komendy rejestruja sie przy pierwszym uzyciu czatu,
-- wiec zdejmujemy ich nazwy przy wczytaniu (PLAYER_LOGIN, przed pierwsza komenda).
G.SLASH_SHORT = { plan = "GRIMUARPLAN", koniec = "GRIMUARKONIEC", loch = "GRIMUARLOCH", npc = "GRIMUARNPC", rangi = "GRIMUARRANGI",
  ustaw = "GRIMUARUSTAW", sprawdz = "GRIMUARSPRAWDZ", zloto = "GRIMUARZLOTO", runy = "GRIMUARRUNY", wstegi = "GRIMUARWSTEGI",
  focusramka = "GRIMUARFOCUSRAMKA", globy = "GRIMUARGLOBY", ekran = "GRIMUAREKRAN", trasa = "GRIMUARTRASA", dzwieki = "GRIMUARDZWIEKI",
  minimapa = "GRIMUARMINIMAPA", profesje = "GRIMUARPROFESJE", rynek = "GRIMUARRYNEK" }
local sl = CreateFrame("Frame")
sl:RegisterEvent("PLAYER_LOGIN")
sl:SetScript("OnEvent", function()
  if G.personal and G.personal() then return end
  for _, key in pairs(G.SLASH_SHORT) do _G["SLASH_" .. key .. "1"] = nil end
end)
