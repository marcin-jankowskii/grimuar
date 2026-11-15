-- Grimuar UI: karta startu sesji „Ile masz czasu?” (15.11, propozycja 6: „Mam 30 minut”; gracz: „te wszystkie mozesz
-- zrobic”). Po wejsciu do gry (gdy plan sesji jeszcze nie ustalony, GrimuarSetup Sesja.lua) i po /plan albo /hub start:
-- panel w stylu huba z wyborem czasu (30 min, 1 h, 2 h, 3 h) i kartami „Najwiecej da teraz”, kazda z czasem:
-- odpoczynek (podwojne XP), kontrakty Grimuara, nastepny krok poradnika profesji (Polestar), trener i talenty,
-- loch na Twoj poziom. Wybor czasu uklada plan sesji Grimuara (ten sam co na pasku) i pokazuje go jako karty;
-- karty dluzsze niz wybrany czas gasna. Nic nie dzieje sie samo: to podglad i skroty.
local ADDON, U = ...
local C = U.C
local G = U.G or {}

local F
local S = { mins = nil }

local function n(v) return U.num(v) or 0 end

-- ---------- propozycje ----------
local function ideas()
  local out = {}
  local lvl = UnitLevel("player") or 1
  -- odpoczynek
  local rest, mx = n(U.call(GetXPExhaustion)), n(U.call(UnitXPMax, "player"))
  if rest > 0 and mx > 0 and lvl < 60 then
    local pct = math.floor(rest / mx * 100 + 0.5)
    out[#out + 1] = { title = "Odpoczynek: " .. pct .. "% poziomu z podwójnym XP", sub = "Moby dają teraz 2× XP, aż się zużyje.", frac = math.min(1, rest / mx),
      right = "każda sesja", mins = 0, col = C.frost }
  end
  -- trener i talenty
  local miss = U.call(G.missingTraining) or {}
  if type(miss) == "table" and #miss > 0 then
    out[#out + 1] = { title = "Trener: " .. #miss .. (#miss == 1 and " nowy czar" or " nowe czary"), sub = table.concat(miss, ", "), right = "ok. 5 min", mins = 5,
      onClick = function() if G.guideTrainer then pcall(G.guideTrainer) end end, tip = "Klik: strzałka do trenera." }
  end
  local tp = n(U.call(G.talentPoints))
  if lvl >= 10 and tp > 0 then
    out[#out + 1] = { title = "Wydaj " .. tp .. (tp == 1 and " punkt talentu" or " punkty talentów"), sub = "Plan talentów jest w buildzie (N).", right = "2 min", mins = 2,
      onClick = function() if G.openTalents then pcall(G.openTalents) end end }
  end
  -- kontrakty
  for i, t in ipairs((U.contractTasks and U.contractTasks()) or {}) do
    if i > 3 then break end
    out[#out + 1] = { title = t.title, sub = t.objs and t.objs[1] and t.objs[1].text or nil, right = "kontrakt " .. (t.tag or ""), mins = 20, mark = true }
  end
  -- profesje: nastepny krok poradnika
  for prof, s in pairs(U.call(G.readProfs) or {}) do
    local hint = G.psProfHint and U.call(G.psProfHint, prof, s.rank)
    if hint then
      local pl = (U.SKILL_PL and (function() for id, en in pairs({ [129] = "First Aid", [182] = "Herbalism", [186] = "Mining", [393] = "Skinning",
        [171] = "Alchemy", [164] = "Blacksmithing", [185] = "Cooking", [333] = "Enchanting", [202] = "Engineering", [356] = "Fishing",
        [165] = "Leatherworking", [197] = "Tailoring" }) do if en == prof then return U.SKILL_PL[id] end end end)()) or prof
      out[#out + 1] = { title = pl .. " " .. n(s.rank) .. "/" .. n(s.max), sub = hint, right = "ok. 10 min", mins = 10, frac = n(s.max) > 0 and n(s.rank) / n(s.max) or nil,
        tip = "Okno profesji (K) ma panel poradnika z przyciskiem „Zrób”." }
    end
  end
  -- loch na Twoj poziom
  if lvl >= 13 and U.dungeonList then
    for _, d in ipairs(U.dungeonList()) do
      if not d.raid and (d.minLevel or 99) <= lvl and lvl <= (d.maxLevel or 0) then
        local fit = U.dungeonFit and select(1, U.dungeonFit(d, { { level = lvl, name = UnitName("player") } }))
        if fit == "ok" or fit == nil then
          out[#out + 1] = { title = "Loch: " .. d.name, sub = (d.minLevel or "?") .. "–" .. (d.maxLevel or "?") .. (d.note and (" · " .. d.note) or ""),
            right = "ok. 45 min", mins = 45, tip = "Hub > Wyprawy: łupy, bossowie i grupa.", onClick = function() if U.Open then U.Open("wyprawy") end end }
          break
        end
      end
    end
  end
  return out
end

-- ---------- rysowanie ----------
local function draw()
  local p = F.blocks
  p:Begin()
  if S.mins and G.planView then
    local items, idx = G.planView()
    if items then
      p:Head("Plan na " .. (S.mins >= 60 and ((S.mins / 60) .. " h") or (S.mins .. " min")), "prowadzi pasek Grimuara")
      local cards = {}
      for i, it in ipairs(items) do
        cards[#cards + 1] = { title = i .. ". " .. (it.text or "?"), right = (it.mins or 0) .. " min", done = it.done or (idx and i < idx) or false,
          col = (i == idx) and C.gold or nil }
      end
      p:Cards(cards, { cols = 1 })
    end
  end
  local list = ideas()
  p:Head("Najwięcej da teraz", S.mins and ("pasuje do " .. S.mins .. " min") or "z czasem na każdą rzecz")
  if #list == 0 then p:Para("Nic pilnego: questy za strzałką Polestara.", C.muted, 12) end
  for _, c in ipairs(list) do
    if S.mins and (c.mins or 0) > S.mins then c.rightCol = C.faint c.sub = (c.sub and (c.sub .. " · ") or "") .. "nie zmieści się dziś" end
  end
  p:Cards(list, { minW = 300 })
  p:End()
end

local function build()
  if F then return end
  F = U.Panel(UIParent, 0.96, true, C.edge)
  F:SetSize(700, 560)
  F:SetPoint("TOP", UIParent, "TOP", 0, -110)
  F:SetFrameStrata("DIALOG")
  F:EnableMouse(true)
  F:SetClampedToScreen(true)
  F:Hide()
  _G.GrimuarStartSesji = F
  tinsert(UISpecialFrames, "GrimuarStartSesji")
  F.title = U.Text(F, 22, "title", C.gold)
  F.title:SetPoint("TOPLEFT", 22, -16)
  F.title:SetText("Ile masz czasu?")
  F.close = U.Button(F, "×", 26, 24)
  F.close:SetPoint("TOPRIGHT", -10, -10)
  F.close:SetScript("OnClick", function() F:Hide() end)
  local prev
  for _, o in ipairs({ { 30, "30 min" }, { 60, "1 h" }, { 120, "2 h" }, { 180, "3 h" } }) do
    local b = U.Button(F, o[2], 84, 28, true)
    if prev then b:SetPoint("LEFT", prev, "RIGHT", 8, 0) else b:SetPoint("TOPLEFT", 22, -56) end
    b:SetScript("OnClick", function()
      S.mins = o[1]
      if G.planChoose then pcall(G.planChoose, o[1]) end
      draw()
    end)
    prev = b
  end
  local none = U.Button(F, "Bez planu", nil, 28)
  none:SetPoint("LEFT", prev, "RIGHT", 16, 0)
  none:SetScript("OnClick", function()
    if G.planSkip then pcall(G.planSkip) end
    F:Hide()
  end)
  F.go = U.Button(F, "Ruszam", nil, 28)
  F.go:SetPoint("TOPRIGHT", -46, -56)
  F.go:SetScript("OnClick", function() F:Hide() end)
  F.blocks = U.Blocks(F)
  F.blocks:SetPoint("TOPLEFT", 10, -96)
  F.blocks:SetPoint("BOTTOMRIGHT", -10, 10)
end

function U.startSesji(force)
  if InCombatLockdown() then return end
  if not force and G.planPending and not G.planPending() then return end
  build()
  S.mins = nil
  F:Show()
  local ok, err = pcall(draw)
  if not ok then F:Hide() U.say("karta startu sesji: " .. tostring(err)) end
end
if G then G.planCard = function() U.startSesji(true) end end

local ev = CreateFrame("Frame")
ev:RegisterEvent("PLAYER_LOGIN")
ev:SetScript("OnEvent", function()
  C_Timer.After(12, function()
    if U.db().startSesjiOff then return end
    local inInst = select(2, IsInInstance())
    if inInst and inInst ~= "none" then return end
    pcall(U.startSesji, false)
  end)
end)
