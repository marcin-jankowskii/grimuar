-- Grimuar: modul Sesja. Plan sesji („ile masz czasu?” -> kroki, ostatni zawsze karczma) i „Kończę grę”
-- (prowadzenie do najblizszej karczmy, bo wylogowanie tam nalicza odpoczynek). Propozycje 1 i 2, zgoda gracza 12.11.
-- Kroki trafiaja na pasek Grimuara przez G.sessionSteps(add), wolane z buildSteps (Engine).
-- Komendy: /koniec (prowadz do karczmy), /plan (uloz plan od nowa).
local ADDON_NAME, G = ...
local say = G.say

local P = { asked = false, plan = nil, ending = false }
local innCache = { t = 0 }

local function refresh() if G.refreshAll then pcall(G.refreshAll) end end

local function save()
  if not GrimuarSetupDB then return end
  GrimuarSetupDB.plan = { char = G.charKey(), lastSeen = time(), asked = P.asked, plan = P.plan, ending = P.ending }
end

-- Po /reload albo krotkim wyjsciu (do 15 min, jak minutnik w Engine) plan wraca.
local function resume()
  local d = GrimuarSetupDB and GrimuarSetupDB.plan
  if type(d) == "table" and d.char == G.charKey() and time() - (d.lastSeen or 0) < 900 then
    P.asked, P.plan, P.ending = d.asked and true or false, d.plan, d.ending and true or false
  end
end

local function prettyKey(k)
  if not k then return nil end
  return (k:gsub("SHIFT%-", "Shift+"):gsub("CTRL%-", "Ctrl+"):gsub("ALT%-", "Alt+"))
end

local function innInfo()
  if time() - innCache.t < 15 then return innCache.name, innCache.m end
  innCache.t = time()
  innCache.name, innCache.m = nil, nil
  if not G.findNearestVendor then return nil end
  local ok, v = pcall(G.findNearestVendor, "inn")
  if ok and type(v) == "table" and v.dist then
    innCache.name, innCache.m = v.name or "karczmarz", math.floor(v.dist * 0.9144 + 0.5)
  end
  return innCache.name, innCache.m
end

local function resting()
  local ok, r = pcall(IsResting)
  return ok and r and true or false
end

-- ---------- uklad planu ----------
local function nextTodo()
  local l = UnitLevel("player") or 1
  local checks = (GrimuarSetupDB.checks and GrimuarSetupDB.checks[G.charKey()]) or {}
  for _, stg in ipairs(G.STAGES or {}) do
    if stg.from > l then break end
    for i, t in ipairs(stg.todo or {}) do
      local k = stg.id .. "-" .. i
      if not checks[k] then return t, k end
    end
  end
end

-- XP na godzine: z ostatnich 20 min, a gdy brak, z ostatnich sesji w dzienniku Grimuara.
local function paceXPH()
  local xph = G.xpPerHour and G.xpPerHour()
  if xph then return xph end
  local L = GrimuarSetupDB.log and GrimuarSetupDB.log[G.charKey()]
  if type(L) ~= "table" then return nil end
  local xp, mins = 0, 0
  for i = #L, math.max(1, #L - 4), -1 do
    local e = L[i]
    if type(e) == "table" and (e.minutes or 0) >= 15 then xp, mins = xp + (e.xp or 0), mins + e.minutes end
  end
  if mins < 30 or xp <= 0 then return nil end
  return xp / mins * 60
end

local function goalText(mins)
  local xph, mx = paceXPH(), UnitXPMax("player")
  if not xph or not mx or mx <= 0 or (UnitLevel("player") or 1) >= 60 then return nil end
  local h = math.floor(xph * mins / 60 / mx * 2 + 0.5) / 2
  if h < 0.5 then return "kawałek poziomu" end
  if h == 0.5 then return "około pół poziomu" end
  if h == 1 then return "około 1 poziomu" end
  if h == 1.5 then return "około półtora poziomu" end
  if h == math.floor(h) then return "około " .. h .. " poziomów" end
  return "około " .. (tostring(h):gsub("%.", ",")) .. " poziomu"
end

local function makePlan(mins)
  local items = {}
  local function add(id, text, m, extra)
    local it = { id = id, text = text, mins = m }
    for k, v in pairs(extra or {}) do it[k] = v end
    items[#items + 1] = it
  end
  local l = UnitLevel("player") or 1
  if (G.freeBagSlots and G.freeBagSlots() or 99) <= 6 then
    local vk = prettyKey(G.vendorKey and G.vendorKey())
    add("bags", "Sprzedaj śmieci u kupca" .. (vk and (" (" .. vk .. ")") or ""), 3)
  end
  -- 14.11 (gracz: „to nie musi mowic o oddaniu questow, dzieki hubowi bede sam dobrze trackowac”): bez kroku „Oddaj gotowe questy”
  local miss = G.missingTraining and G.missingTraining() or {}
  if #miss > 0 then add("train", "Trener: kup " .. table.concat(miss, ", "), 5) end
  if l >= 10 and G.talentPoints and G.talentPoints() > 0 then add("talent", "Wydaj punkt talentu (N)", 2) end
  local endM = (mins >= 60) and 7 or 5
  local used = endM
  for _, it in ipairs(items) do used = used + it.mins end
  local extra = {}
  if mins >= 120 then
    local t, k = nextTodo()
    if t then extra[#extra + 1] = { "todo", "Zadanie etapu: " .. t, 25, { check = k } } end
    local dg = (l >= 13 and G.bestDungeon) and G.bestDungeon(l) or nil
    if dg then extra[#extra + 1] = { "dng", "Loch " .. dg[3] .. " z grupą, jeśli ktoś szuka", 30 } end
  end
  local extraM = 0
  for _, e in ipairs(extra) do extraM = extraM + e[3] end
  if mins - used - extraM < 30 then extra, extraM = {}, 0 end
  -- R8: ziola i rude sprzedawac od razu (ceny spadaja), raz w tygodniu skan Auctionatorem
  if mins >= 60 and G.matsCount and G.matsCount() >= 20 then
    add("ah", "Dom aukcyjny: wystaw zioła i rudę (Auctionator)", 10)
    used = used + 10
  end
  -- profesje (R13): trener przed limitem, bandaże, mikstury
  local pi = G.profPlanItem and G.profPlanItem()
  if pi then
    add("prof", pi, 5)
    used = used + 5
  end
  local hasTrack = G.gatherState and G.gatherState()
  local guide = G.polestarLoaded and G.polestarLoaded()
  add("quest", (guide and "Questy za strzałką Polestar" or "Questy w strefie (mapa: M)") .. (hasTrack and ", zioła i ruda po drodze" or ""),
    math.max(10, mins - used - extraM))
  for _, e in ipairs(extra) do add(e[1], e[2], e[3], e[4]) end
  add("inn", "Wyloguj się w karczmie", endM)
  return { mins = mins, items = items, goal = goalText(mins) }
end

local function minutesLeft()
  local S = G.S
  if not (S and S.budgetEnd) then return nil end
  return math.max(0, math.floor((S.budgetEnd - time()) / 60))
end

-- Biezacy krok = pierwszy niezrobiony. Automatycznie sprawdzamy tylko biezacy, zeby np. karczma
-- na starcie (jestes w miescie) nie odhaczyla sie z gory.
local function autoDone(it, idx, plan)
  if it.done then return true end
  local ok, res = pcall(function()
    if it.id == "bags" then return (G.freeBagSlots() or 0) > 6 end
    -- 14.11 (gracz: „to sie samo nie updateuje, mimo ze oddalem quest”): tekst z liczba liczony na biezaco, nie raz na starcie sesji
    if it.id == "turnin" then
      do return true end -- plan zapisany przed 14.11: krok od razu odhaczony
      local _, d = G.questStats()
      if d > 0 then it.text = "Oddaj gotowe questy (" .. d .. ")" end
      return d == 0
    end
    if it.id == "train" then
      local miss = G.missingTraining()
      if #miss > 0 then it.text = "Trener: kup " .. table.concat(miss, ", ") end
      return #miss == 0
    end
    if it.id == "talent" then return G.talentPoints() == 0 end
    if it.id == "todo" then
      local c = GrimuarSetupDB.checks and GrimuarSetupDB.checks[G.charKey()]
      return c and it.check and c[it.check] and true or false
    end
    if it.id == "quest" then
      local left = minutesLeft()
      if not left then return false end
      local after = 0
      for j = idx + 1, #plan.items do after = after + (plan.items[j].mins or 0) end
      return left <= after
    end
    if it.id == "inn" then return resting() end
    if it.id == "prof" then return not (G.profPlanItem and G.profPlanItem()) end
    return false
  end)
  if ok and res then it.done = true end
  return it.done
end

local function current(plan)
  for i, it in ipairs(plan.items or {}) do
    if not autoDone(it, i, plan) then return i, it end
  end
  return nil
end

-- ---------- podsumowanie sesji (13.11): pokazywane w karczmie, przed wylogowaniem ----------
local function plural(n, one, few, many)
  if n == 1 then return one end
  local d, h = n % 10, n % 100
  if d >= 2 and d <= 4 and (h < 12 or h > 14) then return few end
  return many
end

local function sessionSummary()
  local S = G.S or {}
  local parts = {}
  local mx, xp = UnitXPMax("player") or 0, S.xpGained or 0
  if mx > 0 and xp > 0 then parts[#parts + 1] = "+" .. (string.format("%.1f", xp / mx):gsub("%.", ",")) .. " poziomu" end
  local money = (GetMoney() or 0) - (S.money0 or GetMoney() or 0)
  if money > 0 and G.fmtMoney then parts[#parts + 1] = "+" .. G.fmtMoney(money) end
  local d = S.deaths and #S.deaths or 0
  parts[#parts + 1] = d .. " " .. plural(d, "zgon", "zgony", "zgonów")
  if G.sessionMinutes then parts[#parts + 1] = math.floor(G.sessionMinutes()) .. " min gry" end
  local nextTxt
  if P.plan then
    local _, it = current(P.plan)
    if it and it.id ~= "inn" then nextTxt = it.text end
  end
  if not nextTxt then
    local l = UnitLevel("player") or 1
    if l < 60 then nextTxt = "trener na " .. ((l % 2 == 0) and (l + 2) or (l + 1)) .. " poziomie" end
  end
  return "Dziś: " .. table.concat(parts, ", ") .. "." .. (nextTxt and (" Następnym razem: " .. nextTxt .. ".") or "")
end

-- ---------- kroki na pasku Grimuara ----------
local function stopEnding()
  P.ending = false
  if P.plan then P.plan.closed = true end
  save()
  refresh()
end

local function endingStep(add)
  if resting() then
    local okS, summary = pcall(sessionSummary)
    add("ending", "Możesz się wylogować: odpoczynek się nalicza.",
      (okS and (summary .. " ") or "") .. "Esc > Wyloguj albo wpisz /camp. Następna sesja zacznie się z podwójnym XP za moby.",
      { { "Gotowe", stopEnding } })
  else
    local name, m = innInfo()
    add("ending", "Kończysz: wyloguj się w karczmie" .. (name and (" (" .. name .. ", ok. " .. m .. " m)") or "") .. ".",
      "W karczmie albo w mieście nalicza się odpoczynek: podwójne XP za moby w następnej sesji. " ..
      (G.hearthInfo and (G.hearthInfo() .. ".") or ""),
      { { "Prowadź", function() pcall(G.guideInn) end }, { "Zostaję", stopEnding } })
  end
end

local function choose(mins)
  P.asked = true
  P.plan = makePlan(mins)
  P.ending = false
  if G.setBudget then pcall(G.setBudget, mins) end
  save()
  local label = (mins >= 60) and ((mins / 60) .. " h") or (mins .. " min")
  say("plan na " .. label .. ": " .. #P.plan.items .. " kroków" .. (P.plan.goal and (", cel " .. P.plan.goal) or "") ..
    ". Pasek Grimuara prowadzi po kolei, a 10 min przed końcem przypomnę o karczmie.")
  refresh()
end

local function clearPlan()
  P.plan = nil
  P.ending = false
  if G.setBudget then pcall(G.setBudget, 0) end
  save()
  refresh()
end

local ITEM_BTN = {
  bags = { "Do kupca", function() pcall(G.guideVendor, false) end },
  turnin = { "Prowadź", function() pcall(G.guideTurnin) end },
  train = { "Prowadź", function() pcall(G.guideTrainer) end },
  talent = { "Talenty", function() pcall(G.openTalents) end },
  inn = { "Prowadź", function() pcall(G.guideInn) end },
  ah = { "Złoto", function() if SlashCmdList.GRIMUARZLOTO then SlashCmdList.GRIMUARZLOTO("") end end },
}

local function planStep(add)
  local plan = P.plan
  local idx, it = current(plan)
  if not it then
    if not plan.closed then endingStep(add) end
    return
  end
  local n = #plan.items
  local left = minutesLeft()
  local text = it.text
  local why
  if it.id == "inn" then
    local name, m = innInfo()
    if name then text = text .. " (" .. name .. ", ok. " .. m .. " m)" end
    why = "Odpoczynek w karczmie albo w mieście da podwójne XP za moby w następnej sesji. " ..
      (G.hearthInfo and (G.hearthInfo() .. ".") or "")
  else
    local nxt = {}
    for j = idx + 1, math.min(n, idx + 2) do nxt[#nxt + 1] = plan.items[j].text end
    why = (left and ("Zostało " .. left .. " min. ") or "") ..
      ((#nxt > 0) and ("Potem: " .. table.concat(nxt, " · ") .. ".") or "") ..
      (plan.goal and ("  Cel: " .. plan.goal .. ".") or "")
  end
  local btns = {}
  if ITEM_BTN[it.id] then btns[#btns + 1] = ITEM_BTN[it.id] end
  btns[#btns + 1] = { "Zrobione", function() it.done = true; save(); refresh() end }
  btns[#btns + 1] = { "Koniec planu", clearPlan }
  add("plan", text .. ".", why, btns, nil, idx .. " z " .. n)
end

local function sessionSteps(add)
  if P.ending then endingStep(add) return end
  if not P.asked then
    if GrimuarSetupDB.noPlanAsk then return end
    add("plan-ask", "Plan na dziś: ile masz czasu?",
      "Ułożę kroki z tego, co już wiem: torby, questy, trener, talenty. Ostatni krok to karczma, żeby następna sesja zaczęła się z odpoczynkiem.",
      { { "30 min", function() choose(30) end }, { "1 h", function() choose(60) end }, { "2 h", function() choose(120) end },
        { "Bez planu", function() P.asked = true; save(); refresh() end } })
    return
  end
  if P.plan then planStep(add) end
end

local function startEnding()
  P.ending = true
  save()
  if resting() then
    say("jesteś w karczmie albo w mieście: możesz się wylogować, odpoczynek się nalicza.")
  else
    pcall(G.guideInn)
  end
  refresh()
end

-- ---------- przyciski „Kończę grę”: w naglowku paska Grimuara i ikona kamienia obok monety ----------
local function addButtons()
  local dock = _G.GrimuarDock
  if dock and dock.more and not dock.endBtn and G.FlatButton then
    local b = G.FlatButton(dock, 84, 18, "Kończę grę", true)
    b:SetPoint("RIGHT", dock.more, "LEFT", -4, 0)
    b:SetScript("OnClick", startEnding)
    if G.FitButton then G.FitButton(b, 84) end
    if b.Repaint then b:Repaint() end
    dock.endBtn = b
  end
  local coin = _G.GrimuarVendorButton
  if coin and not _G.GrimuarInnButton then
    local b = CreateFrame("Button", "GrimuarInnButton", coin)
    b:SetSize(30, 30)
    b:SetPoint("RIGHT", coin, "LEFT", -4, 0)
    local ic = b:CreateTexture(nil, "ARTWORK")
    ic:SetPoint("TOPLEFT", b, "TOPLEFT", 2, -2)
    ic:SetPoint("BOTTOMRIGHT", b, "BOTTOMRIGHT", -2, 2)
    ic:SetTexture("Interface\\Icons\\INV_Misc_Rune_01")
    ic:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    local hl = b:CreateTexture(nil, "HIGHLIGHT")
    hl:SetAllPoints(ic)
    hl:SetColorTexture(1, 1, 1, 0.15)
    b:SetScript("OnClick", startEnding)
    b:SetScript("OnEnter", function(self)
      GameTooltip:SetOwner(self, "ANCHOR_TOP")
      GameTooltip:AddLine("Kończę grę")
      GameTooltip:AddLine("Strzałka do najbliższej karczmy. Wylogowanie tam daje odpoczynek: podwójne XP za moby w następnej sesji.", 1, 1, 1, true)
      GameTooltip:Show()
    end)
    b:SetScript("OnLeave", function() GameTooltip:Hide() end)
  end
end

local ev = CreateFrame("Frame")
ev:RegisterEvent("PLAYER_LOGIN")
ev:RegisterEvent("PLAYER_LOGOUT")
ev:RegisterEvent("PLAYER_UPDATE_RESTING")
ev:RegisterEvent("MERCHANT_CLOSED")
ev:SetScript("OnEvent", function(_, event)
  if event == "PLAYER_LOGIN" then
    pcall(resume)
    C_Timer.After(6, function() pcall(addButtons) end)
    C_Timer.After(15, function() pcall(addButtons) end)
    C_Timer.NewTicker(30, function() if P.asked then pcall(save) end end)
  elseif event == "PLAYER_LOGOUT" then
    pcall(save)
  elseif event == "PLAYER_UPDATE_RESTING" then
    local onInnStep = false
    if P.plan then
      local _, it = current(P.plan)
      onInnStep = (it == nil and not P.plan.closed) or (it and it.id == "inn")
    end
    if (P.ending or onInnStep) and resting() then
      local okS, summary = pcall(sessionSummary)
      pcall(G.showToast, "możesz się wylogować: odpoczynek się nalicza. " .. (okS and summary or ""), "inn", false)
    end
    refresh()
  elseif event == "MERCHANT_CLOSED" then
    if P.plan then
      local _, it = current(P.plan)
      if it and it.id == "bags" then it.done = true save() refresh() end
    end
  end
end)

SLASH_GRIMUARKONIEC1 = "/koniec"
SlashCmdList["GRIMUARKONIEC"] = function() startEnding() end
SLASH_GRIMUARPLAN1 = "/plan"
SlashCmdList["GRIMUARPLAN"] = function()
  P.asked, P.plan, P.ending = false, nil, false
  save()
  say("pytanie o plan jest znowu na pasku Grimuara.")
  refresh()
  -- 15.11: karta „Ile masz czasu?” w stylu huba (GrimuarUI Hud\StartSesji.lua)
  if G.planCard then pcall(G.planCard) end
end

G.sessionSteps = sessionSteps
G.planActive = function() return (P.plan ~= nil and not P.plan.closed) or P.ending end
G.startEnding = startEnding
G.sessionSummary = sessionSummary
G.planView = function()
  if not P.plan or P.plan.closed then return nil end
  local idx = current(P.plan)
  return P.plan.items, idx, P.plan.mins
end
G.planPending = function() return not P.asked and not GrimuarSetupDB.noPlanAsk end
-- 15.11: dla karty startu sesji (GrimuarUI Hud\StartSesji.lua)
G.planChoose = choose
G.planSkip = function() P.asked = true save() refresh() end
