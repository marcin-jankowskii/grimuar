-- Grimuar UI: tempo wedlug trasy na pasku tempa (15.11, R30 P15; gracz: „wstepnie wszystko jak rekomendujesz”).
-- Polestar.Levels.Pace (Core\Levels.lua:510) mowi, do jakiego poziomu trasa Polestara dowiezie Cie w kroku, ktory
-- wymaga poziomu (albo do konca przewodnika), ile paskow XP brakuje (1 pasek = 5% poziomu) i ktory quest przed tym
-- krokiem bedzie za trudny (3+ poziomy nad Toba). Pasek tempa (GrimuarSetup Prowadzenie\Dock.lua, GrimuarHUD) czyta
-- gotowy napis z G.paceLine() i dymek z G.paceTip(). Liczymy tylko na zdarzenia (krok, przewodnik, poziom, oddany
-- quest; XP najwyzej raz na 20 s), z pamiecia. Bez Polestara, bez Codexu albo na 60 poziomie linii nie ma.
local ADDON, U = ...
local G = U.G or {}
local C = U.C

local K = { line = nil, tip = nil, at = -100, due = nil }
local SLACK = 1      -- jak Polestar (UI\GuideFrame.lua GF.PACE_SLACK): do 1 poziomu straty to jeszcze „na tempie”
local XP_EVERY = 20  -- s: XP zmienia sie co zabicie, Pace najwyzej tak czesto

local function tr(s) return G.tr and G.tr(s) or s end
local function lvlText(v)
  if type(v) ~= "number" then return "?" end
  if v % 1 == 0 then return tostring(v) end
  return (string.format("%.1f", v):gsub("%.", ","))
end
local function reachText(v)
  if type(v) ~= "number" then return "?" end
  return (string.format("%.1f", v):gsub("%.", ","))
end
local function plural(n, one, few, many)
  if n == 1 then return one end
  local d, h = n % 10, n % 100
  if d >= 2 and d <= 4 and (h < 12 or h > 14) then return few end
  return many
end
-- numer kroku tak, jak liczy go gracz (Polestar Engine.StepNumber, Core\Engine.lua:9021)
local function stepNo(s)
  local E = _G.Polestar and _G.Polestar.Engine
  if E and type(E.StepNumber) == "function" and type(s) == "number" then
    local ok, n = pcall(E.StepNumber, s)
    if ok and type(n) == "number" then return n end
  end
  return s
end

local function compute()
  K.at = GetTime()
  K.line, K.tip = nil, nil
  local P = _G.Polestar
  local Lv = type(P) == "table" and P.Levels
  if not (Lv and type(Lv.Pace) == "function") then return end
  local ok, p = pcall(Lv.Pace)
  if not ok or type(p) ~= "table" or type(p.target) ~= "number" then return end
  local target = lvlText(p.target)
  local bars, short = tonumber(p.bars) or 0, tonumber(p.short) or 0
  local parts = { tr("Do " .. target .. ":") }
  if bars > 0 then
    parts[1] = parts[1] .. " " .. U.hex(short > SLACK and C.danger or C.gold) .. tr("−" .. bars .. " " .. plural(bars, "pasek", "paski", "pasków")) .. "|r"
  else
    parts[1] = parts[1] .. " " .. U.hex(C.ok) .. tr("na tempie") .. "|r"
  end
  local h = type(p.hard) == "table" and p.hard or nil
  if h and h.title then
    parts[#parts + 1] = U.hex(C.danger) .. tr("trudny: " .. tostring(h.title) .. " (" .. tostring(h.level or "?") .. ")") .. "|r"
  end
  K.line = table.concat(parts, " · ")
  local tip = {}
  tip[#tip + 1] = tr("Trasa Polestara da Ci poziom " .. reachText(p.reach) .. " w kroku " .. tostring(stepNo(p.step)) .. ".")
  if p.kind == "end" then tip[#tip + 1] = tr("To koniec przewodnika: następny zaczyna się od poziomu " .. target .. ".") end
  if bars > 0 then
    tip[#tip + 1] = tr("Do poziomu " .. target .. " brakuje " .. U.thousands(p.xp) .. " XP, czyli " .. bars .. " " ..
      plural(bars, "pasek", "paski", "pasków") .. " (pasek = 5% poziomu).")
    tip[#tip + 1] = tr(short > SLACK and "Dograj moby po drodze, zanim pójdziesz dalej." or "Kilka mobów po drodze wystarczy.")
  else
    tip[#tip + 1] = tr("Same questy z trasy dadzą poziom " .. target .. ".")
  end
  if h then
    tip[#tip + 1] = tr("Trudny quest: " .. tostring(h.title) .. " (poziom " .. tostring(h.level or "?") .. ") w kroku " ..
      tostring(stepNo(h.step)) .. ": dojdziesz tam z poziomem " .. reachText(h.reach) .. ", bezpiecznie od " .. tostring(h.need or "?") .. ".")
  end
  K.tip = tip
end

-- dla paska tempa (GrimuarSetup Dock.lua): gotowy napis albo nil
function G.paceLine() return K.line end
function G.paceTip() return K.tip end

local function soon(delay)
  local due = GetTime() + delay
  if K.due and K.due <= due then return end
  K.due = due
  C_Timer.After(delay, function()
    if not K.due or GetTime() + 0.05 < K.due then return end
    K.due = nil
    local ok, err = pcall(compute)
    if not ok and U.logError then U.logError("tempo trasy", err) end
  end)
end
local function soonXP()
  local since = GetTime() - K.at
  soon(since >= XP_EVERY and 1 or (XP_EVERY - since))
end

-- 15.11 (R30 P01): zdarzenia Polestara przez szyne (Hub\PolestarSzyna.lua)
if U.onPolestar then
  U.onPolestar({ "STEP_CHANGED", "GUIDE_CHANGED", "TABS_CHANGED", "GUIDE_COMPLETED", "CODEX_LOADED", "QOL_XP_UPDATED" }, function(msg)
    if msg == "QOL_XP_UPDATED" then soonXP() else soon(0.5) end
  end)
end

local ev = CreateFrame("Frame")
for _, e in ipairs({ "PLAYER_LOGIN", "PLAYER_LEVEL_UP", "PLAYER_XP_UPDATE", "QUEST_TURNED_IN" }) do pcall(ev.RegisterEvent, ev, e) end
ev:SetScript("OnEvent", function(_, e)
  if e == "PLAYER_LOGIN" then soon(10)
  elseif e == "PLAYER_XP_UPDATE" then soonXP()
  else soon(1) end
end)

U.testChecksExtra = U.testChecksExtra or {}
table.insert(U.testChecksExtra, { "Polestar: tempo trasy (Levels.Pace)", function()
  local P = _G.Polestar
  if type(P) ~= "table" then return "brak Polestara (pasek tempa bez linii trasy)" end
  local Lv = P.Levels
  if not (Lv and type(Lv.Pace) == "function") then error("brak Polestar.Levels.Pace (Core\\Levels.lua:510)") end
  local ok, p = pcall(Lv.Pace)
  if not ok then error("Levels.Pace: " .. tostring(p)) end
  if type(p) ~= "table" then return "Pace zwraca nil (60 poziom, brak przewodnika albo Codexu): linii na pasku nie ma" end
  return "Pace: cel " .. lvlText(p.target) .. " w kroku " .. tostring(stepNo(p.step)) .. " (" .. tostring(p.kind) .. "), trasa daje " ..
    reachText(p.reach) .. ", brakuje " .. tostring(p.bars) .. " pasków" .. (type(p.hard) == "table" and (", trudny: " .. tostring(p.hard.title)) or "") ..
    "; na pasku: " .. (K.line and "jest" or "jeszcze nie policzone")
end })
