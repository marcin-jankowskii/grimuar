-- Grimuar UI: zakladka Nowosci (patch notes). Dwie strony: Grimuar (zmiany wedlug wersji) i WoW Forever (lacznie
-- z datami i zrodlami). Dane: Nowosci\NowosciDane.lua. Po nowej wersji Grimuara jeden komunikat po wejsciu do gry
-- (GrimuarUIDB.nowosciSeen). /hub nowosci otwiera zakladke.
-- 14.11 (gracz: „w patch notesach filtr, co to wplywa dla mojego builda”): przycisk „Dla mojego buildu”. Wpis pasuje,
-- gdy dotyczy Twojej klasy, roli albo czarow (who), Twojego poziomu (lvl), jest jeszcze aktualny (ends), albo w tresci
-- pada nazwa czaru lub talentu z aktywnego buildu (plan talentow, trener, paski, combo). Pod wpisem: dlaczego Cie dotyczy.
-- Wpisy na wyzszy poziom trafiaja do sekcji „Pozniej”.
local ADDON, U = ...
local C = U.C
local G = U.G or {}

local S = { page = "grimuar" }
local GOLD, MUTED, OK, TEXT = U.hex(C.gold), U.hex(C.muted), U.hex(C.ok), U.hex(C.text)
local CLASS_PL = { WARRIOR = "wojownik", PALADIN = "paladyn", HUNTER = "łowca", ROGUE = "łotrzyk", PRIEST = "kapłan", SHAMAN = "szaman",
  MAGE = "mag", WARLOCK = "czarnoksiężnik", DRUID = "druid" }
local TOPIC_PL = { lochy = "lochy", rajd = "rajdy", ah = "dom aukcyjny", grupa = "gra w grupie", pvp = "PvP", profesje = "profesje", event = "wydarzenie", sprzet = "sprzęt" }

local function lang() return (G.Lang and G.Lang()) or "pl" end
local function bt(v) return (G.BT and G.BT(v)) or (type(v) == "table" and (v.pl or v.en)) or v or "" end
local function itext(it) if type(it) ~= "table" then return tostring(it or "") end return (lang() == "en" and it.en) or it.pl or it.en or "" end
local function latest() local n = U.NOWOSCI_GRIMUAR and U.NOWOSCI_GRIMUAR[1] return n and n.ver end

-- ---------- profil buildu ----------
local function profile()
  local _, cls = UnitClass("player")
  local M = G.BD_META or {}
  local role = M.role
  local caster = cls == "MAGE" or cls == "WARLOCK" or cls == "PRIEST" or ((cls == "DRUID" or cls == "SHAMAN") and (M.spec == 1 or role == "HEALER"))
  local names = {}
  local function add(n)
    if type(n) == "string" and #n >= 4 and not n:find("^macro:") then names[n] = true end
  end
  local BD = G.BD or {}
  for _, p in ipairs(BD.talPlan or {}) do add(p[1]) end
  for k in pairs(BD.keep or {}) do add(k) end
  for _, bar in ipairs({ BD.main or {}, BD.bar2 or {}, BD.bar3 or {} }) do
    for _, cands in pairs(bar) do for _, c in ipairs(cands) do add(c) end end
  end
  for _, s in ipairs(BD.steps or {}) do add(s.spell) end
  return { cls = cls, role = role, caster = caster, level = UnitLevel("player") or 1, names = names, build = M.name }
end

-- -> stan ("teraz" | "pozniej" | "nie" | "stare"), lista powodow
local function relevance(it, P)
  if type(it) ~= "table" then return "teraz", {} end
  local why = {}
  if it.ends and date("%Y-%m-%d") > it.ends then return "stare", { "już nieaktualne" } end
  local matchSpell = {}
  for _, s in ipairs(it.spells or {}) do if P.names[s] then matchSpell[#matchSpell + 1] = s end end
  local txt = (it.pl or "") .. " " .. (it.en or "")
  for n in pairs(P.names) do
    if #matchSpell < 4 and txt:find(n, 1, true) then
      local dup = false
      for _, m in ipairs(matchSpell) do if m == n then dup = true end end
      if not dup then matchSpell[#matchSpell + 1] = n end
    end
  end
  local who, ok = it.who or "all", false
  if who == "all" then ok = true
  elseif who == "caster" then ok = P.caster if ok then why[#why + 1] = "rzucasz czary" end
  elseif who == "healer" then ok = P.role == "HEALER" if ok then why[#why + 1] = "leczysz" end
  elseif who == "tank" then ok = P.role == "TANK" if ok then why[#why + 1] = "tankujesz" end
  elseif type(who) == "table" then
    for _, c in ipairs(who) do if c == P.cls then ok = true end end
    if ok then why[#why + 1] = "Twoja klasa (" .. (CLASS_PL[P.cls] or P.cls) .. ")" end
  end
  if #matchSpell > 0 then
    ok = true
    why[#why + 1] = "Twój build: " .. table.concat(matchSpell, ", ")
  end
  if not ok then return "nie", why end
  if it.lvl then
    if P.level > it.lvl[2] then return "nie", { "nie na Twój poziom" } end
    if P.level < it.lvl[1] then why[#why + 1] = "od " .. it.lvl[1] .. " poziomu" return "pozniej", why end
    why[#why + 1] = "Twój poziom (" .. P.level .. ")"
  end
  for _, tp in ipairs(it.topic or {}) do why[#why + 1] = TOPIC_PL[tp] or tp end
  return "teraz", why
end

-- ---------- tekst ----------
local function render(list, P, mine)
  local L, later = {}, {}
  local seen = U.db().nowosciSeenShown
  local shown = 0
  for i, n in ipairs(list or {}) do
    local lines, laterLines = {}, {}
    for _, it in ipairs(n.items or {}) do
      local st, why = relevance(it, P)
      local reason = (#why > 0) and (MUTED .. "   " .. (st == "teraz" and "dotyczy Cię: " or "") .. table.concat(why, " · ") .. "|r") or nil
      if not mine then
        lines[#lines + 1] = (st == "stare" and MUTED or TEXT) .. "◆ " .. itext(it) .. "|r"
        if st == "stare" then lines[#lines + 1] = MUTED .. "   już nieaktualne|r" end
      elseif st == "teraz" then
        lines[#lines + 1] = "◆ " .. itext(it)
        if reason then lines[#lines + 1] = reason end
      elseif st == "pozniej" then
        laterLines[#laterLines + 1] = MUTED .. "◇ " .. itext(it) .. "|r"
        if reason then laterLines[#laterLines + 1] = reason end
      end
    end
    local head = GOLD .. (n.ver and ("Grimuar " .. n.ver .. " · ") or "") .. n.date .. " · " .. bt(n.title):upper() .. "|r" ..
      ((S.page == "grimuar" and seen and n.ver ~= seen and i == 1) and (OK .. "   nowe|r") or "")
    if #lines > 0 then
      shown = shown + 1
      L[#L + 1] = (#L > 0 and "\n" or "") .. head
      for _, x in ipairs(lines) do L[#L + 1] = x end
      if n.src then L[#L + 1] = MUTED .. "źródło: " .. n.src .. "|r" end
    end
    if #laterLines > 0 then
      later[#later + 1] = MUTED .. n.date .. " · " .. bt(n.title) .. "|r"
      for _, x in ipairs(laterLines) do later[#later + 1] = x end
    end
  end
  if mine then
    local intro = GOLD .. "DLA TWOJEGO BUILDU|r" .. MUTED .. "   " .. (P.build or "aktywny build") .. " · " .. (CLASS_PL[P.cls] or "?") .. " · poziom " .. P.level .. "|r\n"
    if shown == 0 then intro = intro .. MUTED .. "Nic z tej listy nie dotyczy Twojego buildu teraz.|r\n" end
    table.insert(L, 1, intro)
    if #later > 0 then
      L[#L + 1] = "\n" .. GOLD .. "PÓŹNIEJ|r" .. MUTED .. "   dotyczy Cię na wyższym poziomie|r"
      for _, x in ipairs(later) do L[#L + 1] = x end
    end
  end
  return table.concat(L, "\n")
end

function U.nowosciRefresh()
  if not (S.det and S.det:IsVisible()) then return end
  for k, b in pairs(S.tabs) do
    U.Color(b.label, k == S.page and C.gold or C.muted)
    U.BorderColor(b, k == S.page and C.gold or C.edge)
  end
  local mine = U.db().nowosciMoje == true
  S.mine:SetLabel(mine and "◆ Dla mojego buildu" or "Dla mojego buildu")
  U.Color(S.mine.label, mine and C.gold or C.muted)
  local list = S.page == "forever" and U.NOWOSCI_FOREVER or U.NOWOSCI_GRIMUAR
  local txt = render(list, profile(), mine)
  if S.page == "forever" and U.NOWOSCI_FOREVER_NOTE then txt = txt .. "\n\n" .. MUTED .. bt(U.NOWOSCI_FOREVER_NOTE) .. "|r" end
  S.det:Set(txt)
end

local function build(page)
  S.tabs = {}
  local prev
  for _, d in ipairs({ { "grimuar", "Grimuar" }, { "forever", "WoW Forever" } }) do
    local b = U.Button(page, d[2], nil, 30)
    if prev then b:SetPoint("LEFT", prev, "RIGHT", 8, 0) else b:SetPoint("TOPLEFT", page, "TOPLEFT", 0, 0) end
    b:SetScript("OnClick", function() S.page = d[1] U.nowosciRefresh() end)
    S.tabs[d[1]] = b
    prev = b
  end
  S.mine = U.Button(page, "Dla mojego buildu", nil, 30)
  S.mine:SetPoint("LEFT", prev, "RIGHT", 24, 0)
  S.mine:SetScript("OnClick", function() U.db().nowosciMoje = not U.db().nowosciMoje U.nowosciRefresh() end)
  S.det = U.TextPanel(page)
  S.det:SetPoint("TOPLEFT", 0, -44)
  S.det:SetPoint("BOTTOMRIGHT")
end

U.RegisterTab({
  id = "nowosci", order = 9, title = "Nowości", keys = "",
  note = "Zmiany w Grimuarze i łatki WoW Forever",
  build = build,
  refresh = function()
    -- „nowe” widac przy tym otwarciu, potem wersja uznana za przeczytana
    U.db().nowosciSeenShown = U.db().nowosciSeen
    U.db().nowosciSeen = latest()
    C_Timer.After(0, function() pcall(U.nowosciRefresh) end)
  end,
})

-- komunikat po wejsciu do gry, gdy jest nowa wersja Grimuara; wpisy Forever, ktore dotycza buildu, osobno
local ev = CreateFrame("Frame")
ev:RegisterEvent("PLAYER_LOGIN")
ev:SetScript("OnEvent", function()
  C_Timer.After(20, function()
    local v = latest()
    if v and U.db().nowosciSeen ~= v then
      local n = U.NOWOSCI_GRIMUAR[1]
      local msg = "Grimuar " .. v .. ": " .. bt(n.title) .. ". Szczegóły: hub > Nowości"
      if G.showToast then pcall(G.showToast, msg, "plan", false) end
      U.say(msg .. " (/hub nowosci).")
    end
    -- nowe lacznie Forever dla Twojego buildu (od ostatniego razu)
    local P, hits = profile(), 0
    local d = U.db()
    d.nowosciForeverSeen = d.nowosciForeverSeen or {}
    for _, n in ipairs(U.NOWOSCI_FOREVER or {}) do
      for _, it in ipairs(n.items or {}) do
        local key = n.date .. "|" .. (it.pl or ""):sub(1, 40)
        if not d.nowosciForeverSeen[key] and relevance(it, P) == "teraz" then hits = hits + 1 end
        d.nowosciForeverSeen[key] = true
      end
    end
    if hits > 0 and not d.nowosciFirstRun then
      U.say("łatki WoW Forever: " .. hits .. " " .. (hits == 1 and "zmiana dotyczy" or "zmian dotyczy") .. " Twojego buildu. Hub > Nowości > Dla mojego buildu.")
    end
    d.nowosciFirstRun = nil
  end)
end)
