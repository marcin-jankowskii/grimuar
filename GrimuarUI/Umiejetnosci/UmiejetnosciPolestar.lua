-- Grimuar UI: czary na kolejny poziom z kosztem i gdzie trenowac (15.11, R30 P09; gracz: „wstepnie wszystko jak
-- rekomendujesz”). Dwie karty (Hub\Bloki.lua U.Card) w zakladce Umiejetnosci (nad „Trener”) i w oknie trenera klasy
-- (Okna\Trener.lua, nad lista):
-- * „Na 26: 3 czary” z kosztem: Polestar.QoL.Spells.NewAt(poziom) (QoL\Spells.lua:184 -> { { id, rank, cost } } czarow,
--   ktorych jeszcze nie znasz, z kosztem w miedziakach), pierwszy poziom powyzej Twojego, na ktorym trener cos ma;
-- * gdzie trenowac: Polestar.Engine.TrainingAdvice (Core\Engine.lua:7345): krok przewodnika z treningiem (do 10 krokow
--   przed Toba) albo najblizszy trener klasy na trasie, z czasem dojscia (G.etaText); klik prowadzi (G.wayTo).
-- Liczone przy otwarciu zakladki albo okna, z pamiecia 20 s albo do zdarzenia Polestara (trening, krok, nowy poziom).
local ADDON, U = ...
local G, C = U.G or {}, U.C

local K = { at = -100, d = nil }
local TTL = 20       -- s: najblizszy trener zalezy od tego, gdzie stoisz
local AHEAD = 6      -- ile poziomow w przod szukac nastepnych czarow
local TRAIN_ICON = "Interface\\Icons\\INV_Misc_Book_11"

local function PS() return _G.Polestar end
local function plural(n, one, few, many)
  if n == 1 then return one end
  local d, h = n % 10, n % 100
  if d >= 2 and d <= 4 and (h < 12 or h > 14) then return few end
  return many
end
local function money(c) return U.money and U.money(c) or (math.floor((c or 0) / 100) / 100 .. " g") end
local function spellName(id)
  if C_Spell and C_Spell.GetSpellName then return (U.call(C_Spell.GetSpellName, id)) end
  return (U.call(GetSpellInfo, id))
end
local function spellIcon(id)
  if C_Spell and C_Spell.GetSpellTexture then return (U.call(C_Spell.GetSpellTexture, id)) end
  return (select(3, U.call(GetSpellInfo, id)))
end
local function mapName(map)
  local i = map and U.call(C_Map.GetMapInfo, map)
  return type(i) == "table" and i.name or nil
end

-- { ok, next = { level, spells = { { id, rank, cost, name } }, cost }, advice = { steps, title, guide, trainer = { name, map, x, y, eta } } }
function U.psTraining(force)
  if not force and K.d and GetTime() - K.at < TTL then return K.d end
  local d = { ok = false }
  local P = PS()
  local Sp = type(P) == "table" and P.QoL and P.QoL.Spells
  local l = UnitLevel("player") or 1
  if Sp and type(Sp.NewAt) == "function" then
    d.ok = true
    for lv = l + 1, math.min(60, l + AHEAD) do
      local ok, list = pcall(Sp.NewAt, lv)
      if ok and type(list) == "table" and #list > 0 then
        local nx = { level = lv, spells = {}, cost = 0 }
        for _, s in ipairs(list) do
          if type(s) == "table" and s.id then
            nx.spells[#nx.spells + 1] = { id = s.id, rank = s.rank, cost = U.num(s.cost) or 0, name = spellName(s.id) or ("#" .. s.id) }
            nx.cost = nx.cost + (U.num(s.cost) or 0)
          end
        end
        if #nx.spells > 0 then d.next = nx break end
      end
    end
  end
  local E = type(P) == "table" and P.Engine
  if E and type(E.TrainingAdvice) == "function" then
    local ok, a = pcall(E.TrainingAdvice)
    if ok and type(a) == "table" then
      d.ok = true
      local adv = { steps = a.steps, title = a.title and (U.polestarText and U.polestarText(a.title) or a.title), guide = a.guide == true }
      local t = type(a.trainer) == "table" and a.trainer or nil
      if t and t.map and t.x and t.y then
        local m, x, y = t.map, t.x, t.y
        if U.psLive then m, x, y = U.psLive(t) end
        adv.trainer = { name = t.npcName or t.npcEnglish or "trener", map = m, x = U.num(x), y = U.num(y) }
        if adv.trainer.x and G.etaText then adv.trainer.eta = U.call(G.etaText, m, adv.trainer.x, adv.trainer.y) or "" end
      end
      d.advice = adv
    end
  end
  K.d, K.at = d, GetTime()
  return d
end

local function stepsText(n)
  if type(n) ~= "number" then return nil end
  if n <= 1 then return "w tym kroku" end
  return "za " .. n .. " " .. plural(n, "krok", "kroki", "kroków")
end

-- 15.11 (R30 P45, gracz: „stare rangi czarow na paskach”): czary w starszej randze na paskach z
-- Polestar.QoL.Spells.OldRanks() (QoL\Spells.lua: { { id, bestId, name, have, best, slots } }, liczba przyciskow).
-- Klik: Spells.Upgrade() podmienia na najwyzsza range (poza walka; w walce Polestar czeka do jej konca).
-- Polestar ma tez wlasna karte OLD_RANKS (powiadomienie po treningu); nasza to stala lista w Umiejetnosciach i u trenera.
K.rows = setmetatable({}, { __mode = "k" })
local function redrawRows()
  for row in pairs(K.rows) do
    if row:IsVisible() and row.lastW then pcall(row.Draw, row, row.lastW, row.lastOpts) end
  end
end
local function oldRanksCard()
  local P = PS()
  local Sp = P and P.QoL and P.QoL.Spells
  if not (Sp and type(Sp.OldRanks) == "function") then return nil end
  local ok, list, n = pcall(Sp.OldRanks)
  if not ok or type(list) ~= "table" or #list == 0 then return nil end
  n = U.num(n) or #list
  local names, tip = {}, { "Na paskach są starsze rangi czarów:" }
  for i, e in ipairs(list) do
    local nm = e.name or spellName(e.id) or "?"
    local ns = #(e.slots or {})
    if i <= 2 then names[#names + 1] = nm .. " " .. tostring(e.have) .. " → " .. tostring(e.best) end
    tip[#tip + 1] = "• " .. nm .. ": na pasku ranga " .. tostring(e.have) .. ", znasz " .. tostring(e.best) ..
      " (" .. ns .. " " .. plural(ns, "przycisk", "przyciski", "przycisków") .. ")"
  end
  if #list > 2 then names[#names + 1] = "…" end
  tip[#tip + 1] = "\nStarsza ranga zadaje mniej obrażeń za prawie tę samą manę."
  tip[#tip + 1] = "Klik: podmień wszystkie na najwyższą rangę (Polestar; w walce poczeka do jej końca)."
  return {
    title = "Stare rangi na paskach: " .. n, sub = table.concat(names, ", "),
    icon = spellIcon(list[1].bestId or list[1].id) or TRAIN_ICON, col = C.gold,
    right = "Podmień", rightCol = C.gold, tip = table.concat(tip, "\n"),
    onClick = function()
      local okU, r = pcall(Sp.Upgrade)
      if not okU then
        U.say("nie udało się podmienić rang: " .. tostring(r))
      elseif type(r) == "number" then
        U.say("podmienione przyciski: " .. r .. ".")
      else
        U.say("podmienię rangi po walce.")
      end
      C_Timer.After(1, redrawRows)
    end,
  }
end

-- karty: { oldRanks?, spells?, trainer? } w formacie p:Cards; opts.here: imie trenera, przy ktorym stoisz (bez karty „najblizszy”)
function U.psTrainCards(opts)
  local d = U.psTraining()
  local out = {}
  local okO, old = pcall(oldRanksCard)
  if okO and old then out[#out + 1] = old end
  if not d.ok then return out end
  local nx = d.next
  if nx then
    local names, tip = {}, { "Na poziomie " .. nx.level .. " trener maga nauczy:" }
    for i, s in ipairs(nx.spells) do
      local r = (U.num(s.rank) or 0) > 1 and (" " .. s.rank) or ""
      if i <= 3 then names[#names + 1] = s.name .. r end
      tip[#tip + 1] = "• " .. s.name .. r .. " — " .. ((s.cost or 0) > 0 and money(s.cost) or "za darmo")
    end
    if #nx.spells > 3 then names[#names + 1] = "…" end
    local have = U.num(U.call(GetMoney)) or 0
    tip[#tip + 1] = "\nRazem " .. money(nx.cost) .. (have >= nx.cost and " · masz tyle" or (" · brakuje " .. money(nx.cost - have)))
    tip[#tip + 1] = "Dane: Polestar (lista trenerów Forever)."
    out[#out + 1] = {
      title = "Na " .. nx.level .. ": " .. #nx.spells .. " " .. plural(#nx.spells, "czar", "czary", "czarów"),
      right = money(nx.cost), rightCol = have >= nx.cost and C.ok or C.danger,
      sub = table.concat(names, ", "), icon = spellIcon(nx.spells[1].id) or TRAIN_ICON, col = C.gold,
      tip = table.concat(tip, "\n"),
    }
  end
  local a = d.advice
  if a then
    if a.guide then
      out[#out + 1] = {
        title = "Trener po drodze " .. (stepsText(a.steps) or ""), sub = a.title and ("przewodnik Polestara: " .. a.title) or "przewodnik Polestara",
        icon = TRAIN_ICON, col = C.ok,
        tip = "Przewodnik Polestara sam zaprowadzi Cię do trenera " .. (stepsText(a.steps) or "") .. ". Nie zbaczaj z trasy.",
      }
    elseif a.trainer and not (opts and opts.here and opts.here == a.trainer.name) then
      local t = a.trainer
      local zone = mapName(t.map)
      local guideLine = (a.steps == false) and "przewodnik nie ma treningu przed Tobą"
        or (type(a.steps) == "number" and ("przewodnik: trening " .. stepsText(a.steps)) or nil)
      local sub = table.concat({ zone or "", guideLine or "" }, (zone and guideLine) and " · " or "")
      out[#out + 1] = {
        title = "Najbliższy trener: " .. t.name, right = ((t.eta or ""):gsub("^ · ", "")), rightCol = C.frost,
        sub = sub ~= "" and sub or nil, icon = TRAIN_ICON, col = C.frost,
        tip = t.name .. (zone and (", " .. zone) or "") .. "\nPolestar wybiera trenera z najmniejszym zbaczaniem z trasy.\nKlik: Prowadź (strzałka Polestar).",
        onClick = function()
          if t.map and t.x and G.wayTo then
            pcall(G.wayTo, t.map, tonumber(string.format("%.2f", t.x)), tonumber(string.format("%.2f", t.y)), t.name .. ", trener maga")
            if U.IsOpen and U.IsOpen() then U.Close() end
          end
        end,
      }
    end
  end
  return out
end

-- rzad kart do wstawienia w ramke: row:Draw(szerokosc, opts) -> wysokosc (0 = nic do pokazania, rzad schowany)
function U.psTrainRow(parent)
  local row = CreateFrame("Frame", nil, parent)
  row:SetSize(10, 10)
  row.cards = {}
  K.rows[row] = true
  function row:Draw(w, opts)
    self.lastW, self.lastOpts = w, opts
    local ok, list = pcall(U.psTrainCards, opts)
    if not ok or type(list) ~= "table" or #list == 0 then
      if not ok and U.logError then U.logError("trener/karty", list) end
      self:Hide()
      return 0
    end
    local n = #list
    local cw = math.floor((w - 8 * (n - 1)) / n)
    local h = 0
    for _, c in ipairs(list) do h = math.max(h, U.cardHeight(c)) end
    for i = 1, math.max(n, #self.cards) do
      local c = self.cards[i]
      if list[i] then
        if not c then c = U.Card(self) self.cards[i] = c end
        c:ClearAllPoints()
        c:SetPoint("TOPLEFT", self, "TOPLEFT", (i - 1) * (cw + 8), 0)
        c:Fill(list[i], cw, h)
        c:Show()
      elseif c then c:Hide() end
    end
    self:SetSize(w, h)
    self:Show()
    return h
  end
  return row
end

if U.onPolestar then
  U.onPolestar({ "LEVELUP_SPELLS", "CLASS_TRAINED", "TRAIN_DUE", "STEP_CHANGED", "GUIDE_CHANGED" }, function() K.at = -100 end)
end
local ev = CreateFrame("Frame")
for _, e in ipairs({ "PLAYER_LEVEL_UP", "LEARNED_SPELL_IN_TAB", "TRAINER_CLOSED" }) do pcall(ev.RegisterEvent, ev, e) end
ev:SetScript("OnEvent", function() K.at = -100 end)

-- ---------- /gr test ----------
U.testChecksExtra = U.testChecksExtra or {}
table.insert(U.testChecksExtra, { "Polestar: stare rangi na paskach (Spells.OldRanks, P45)", function()
  local P = PS()
  if type(P) ~= "table" then return "brak Polestara (karta rang się nie pokaże)" end
  local Sp = P.QoL and P.QoL.Spells
  if not (Sp and type(Sp.OldRanks) == "function" and type(Sp.Upgrade) == "function") then
    error("brak Polestar.QoL.Spells.OldRanks/Upgrade (QoL\\Spells.lua)")
  end
  local ok, list, n = pcall(Sp.OldRanks)
  if not ok then error("OldRanks: " .. tostring(list)) end
  return (type(list) == "table" and #list or 0) .. " czarów w starej randze, przycisków: " .. tostring(n or 0)
end })
table.insert(U.testChecksExtra, { "Polestar: czary na poziom (Spells.NewAt)", function()
  local P = PS()
  if type(P) ~= "table" then return "brak Polestara (karta czarów się nie pokaże)" end
  local Sp = P.QoL and P.QoL.Spells
  if not (Sp and type(Sp.NewAt) == "function") then error("brak Polestar.QoL.Spells.NewAt (QoL\\Spells.lua:184)") end
  local l = UnitLevel("player") or 1
  local parts = {}
  for lv = l, math.min(60, l + AHEAD) do
    local ok, list = pcall(Sp.NewAt, lv)
    if not ok then error("NewAt(" .. lv .. "): " .. tostring(list)) end
    if type(list) ~= "table" then error("NewAt(" .. lv .. ") zwraca " .. type(list)) end
    if #list > 0 then
      local c = 0
      for _, s in ipairs(list) do c = c + (U.num(s.cost) or 0) end
      parts[#parts + 1] = lv .. ": " .. #list .. " (" .. math.floor(c / 100) / 100 .. " g)"
    end
  end
  return #parts > 0 and ("nowe czary na poziomach " .. table.concat(parts, ", ")) or ("działa: na " .. l .. "–" .. math.min(60, l + AHEAD) .. " nic nowego")
end })
table.insert(U.testChecksExtra, { "Polestar: gdzie trenować (TrainingAdvice)", function()
  local P = PS()
  if type(P) ~= "table" then return "brak Polestara (karta trenera się nie pokaże)" end
  local E = P.Engine
  if not (E and type(E.TrainingAdvice) == "function") then error("brak Polestar.Engine.TrainingAdvice (Core\\Engine.lua:7345)") end
  local ok, a = pcall(E.TrainingAdvice)
  if not ok then error("TrainingAdvice: " .. tostring(a)) end
  if type(a) ~= "table" then error("TrainingAdvice zwraca " .. type(a) .. " zamiast tabeli") end
  if a.guide then return "przewodnik trenuje " .. tostring(stepsText(a.steps)) .. " (" .. tostring(a.title) .. ")" end
  local t = a.trainer
  return "kroki do treningu w przewodniku: " .. tostring(a.steps) .. "; trener: " ..
    (type(t) == "table" and (tostring(t.npcName) .. ", mapa " .. tostring(t.map) .. (t.f and " (ramka Era)" or "")) or "brak")
end })
