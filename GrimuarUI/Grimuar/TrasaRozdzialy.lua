-- Grimuar UI: trasa jako rozdzialy (14.11, R24 P8; wzor: rozdzialy Season Journey z Diablo 4). Odcinki trasy
-- Grimuara (GrimuarSetup Trasa.lua, G.TRASA) to rozdzialy. Gdy awans przenosi Cie do nastepnego odcinka: plansza
-- „Rozdzial ukonczony” z podsumowaniem rozdzialu (czas gry z Kroniki, zadania, zloto) i tym, co dalej, wstega i zrzut
-- ekranu do Kroniki. Stan: GrimuarUIDB.rozdzialy[postac] = { idx, start, money }.
local ADDON, U = ...
local C = U.C
local G = U.G or {}

local P

local function charKey() return (G.charKey and U.call(G.charKey)) or (UnitName("player") or "?") end
local function legIndex(lvl)
  local legs = G.TRASA
  local cur = G.trasaLeg and U.call(G.trasaLeg, lvl)
  if type(legs) ~= "table" or not cur then return nil end
  for i, l in ipairs(legs) do if l == cur then return i, l end end
  return nil
end
U.chapterIndex = legIndex

-- czas gry, zadania i zloto z Kroniki od chwili `since`
local function sinceStats(since)
  local s = U.kronika and U.kronika() or { list = {} }
  local mins, nq, money = 0, 0, 0
  local all = {}
  for _, r in ipairs(s.list or {}) do all[#all + 1] = r end
  if s.cur then all[#all + 1] = s.cur end
  for _, r in ipairs(all) do
    if (r.last or 0) >= since then
      local from = math.max(r.start or since, since)
      mins = mins + math.max(0, ((r.last or time()) - from) / 60)
      nq = nq + (r.nq or 0)
      for _, v in pairs(r.money or {}) do money = money + v end
    end
  end
  return mins, nq, money
end

local function panel()
  if P then return P end
  P = U.Panel(UIParent, 0.96, true, C.gold)
  P:SetFrameStrata("DIALOG")
  P:SetSize(560, 240)
  P:SetPoint("CENTER", UIParent, "CENTER", 0, 120)
  P:EnableMouse(true)
  P:Hide()
  P.rune = U.Diamond(P, 22, C.gold, true)
  P.rune:SetPoint("TOP", P, "TOP", 0, -18)
  P.kicker = U.Text(P, 12, "title", C.goldDim)
  P.kicker:SetPoint("TOP", P.rune, "BOTTOM", 0, -8)
  P.kicker:SetJustifyH("CENTER")
  P.title = U.Text(P, 28, "title", C.gold)
  P.title:SetPoint("TOP", P.kicker, "BOTTOM", 0, -6)
  P.title:SetJustifyH("CENTER")
  P.text = U.Para(P, 13, 500, C.text)
  P.text:SetPoint("TOP", P.title, "BOTTOM", 0, -14)
  P.text:SetJustifyH("CENTER")
  P.go = U.Button(P, "Dalej", 120, 30, true)
  P.go:SetPoint("BOTTOM", P, "BOTTOM", 0, 16)
  P.go:SetScript("OnClick", function() P:Hide() end)
  return P
end

local function ceremony(doneIdx, doneLeg, nextLeg, st)
  local mins, nq, money = sinceStats(st.start or time())
  local p = panel()
  p.kicker:SetText("ROZDZIAŁ " .. doneIdx .. " UKOŃCZONY")
  p.title:SetText(doneLeg[3] or "?")
  local lines = { U.fmtMins(mins) .. " gry · " .. nq .. " zadań · złoto " .. U.money(money, true) }
  if nextLeg then
    lines[#lines + 1] = "\nRozdział " .. (doneIdx + 1) .. ": " .. (nextLeg[3] or "?") .. " (poziomy " .. (nextLeg[1] or "?") .. "–" .. (nextLeg[2] or "?") .. ")"
    if nextLeg.gather then lines[#lines + 1] = "Zbieraj: " .. nextLeg.gather end
    if nextLeg.keep then lines[#lines + 1] = "Zachowaj: " .. nextLeg.keep end
  end
  p.text:SetText(table.concat(lines, "\n"))
  p:SetHeight(math.max(220, 150 + p.text:GetStringHeight()))
  p:Show()
  C_Timer.After(30, function() if P then P:Hide() end end)
  if G.showToast then pcall(G.showToast, "Rozdział " .. doneIdx .. " ukończony: " .. (doneLeg[3] or ""), "trasa", false) end
  pcall(PlaySound, (SOUNDKIT and SOUNDKIT.UI_QUEST_ROLLING_FORWARD_01) or 888, "Master")
  if U.kronikaShot then U.kronikaShot("rozdział " .. doneIdx .. " ukończony") end
end

local function check(fromLevelUp, lvl)
  local d = U.db()
  d.rozdzialy = d.rozdzialy or {}
  local key = charKey()
  local st = d.rozdzialy[key]
  local idx, leg = legIndex(lvl or UnitLevel("player") or 1)
  if not idx then return end
  if not st then
    d.rozdzialy[key] = { idx = idx, start = time(), money = GetMoney() }
    return
  end
  if idx > (st.idx or idx) then
    local legs = G.TRASA
    local doneIdx = idx - 1
    if fromLevelUp and not InCombatLockdown() then ceremony(doneIdx, legs[doneIdx], leg, st)
    elseif fromLevelUp then C_Timer.After(5, function() pcall(ceremony, doneIdx, legs[doneIdx], leg, st) end) end
    d.rozdzialy[key] = { idx = idx, start = time(), money = GetMoney() }
  elseif idx ~= st.idx then
    st.idx = idx
  end
end

local ev = CreateFrame("Frame")
ev:RegisterEvent("PLAYER_LOGIN")
ev:RegisterEvent("PLAYER_LEVEL_UP")
ev:SetScript("OnEvent", function(_, event, lvl)
  if event == "PLAYER_LOGIN" then C_Timer.After(8, function() pcall(check, false) end)
  else C_Timer.After(2, function() pcall(check, true, lvl) end) end
end)
