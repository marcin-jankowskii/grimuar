-- Grimuar UI: testy do autotestu Grimuara (15.11, gracz: „wszystkie zrob”, punkt 1). Dopisuje sie do G.testChecks
-- (GrimuarSetup Rdzen\Test.lua), wiec /gr test sprawdza tez okna u NPC, ustawienia i hub. Wynik w czacie
-- i w GrimuarSetupDB.selfTest; surowe dane z wizyt u NPC w GrimuarUIDB.diag (Claude czyta oba pliki przy sync).
-- Testy sprawdzaja to, czego nie da sie sprawdzic poza gra: czy klient Forever zwraca wartosci w kolejnosci, ktorej
-- uzywaja okna (trener, kupiec, poczta), jakie ma zakladki banku, ktorych CVarow brakuje i czy okno sie kiedys wywrocilo.
local ADDON, U = ...
local G = U.G or {}

U.version = U.version or function()
  local v
  pcall(function() v = (C_AddOns and C_AddOns.GetAddOnMetadata or GetAddOnMetadata)(ADDON, "Version") end)
  return v or "?"
end

local function db() return U.db() end
local function split(s)
  local out = {}
  for p in (tostring(s or "") .. " | "):gmatch("(.-) | ") do out[#out + 1] = p end
  return out
end
local function ago(d)
  if not d then return "jeszcze nie odwiedzone" end
  return "dane z " .. tostring(d.at) .. (d.version and d.version ~= U.version() and (" (wersja " .. d.version .. ")") or "")
end

local checks = {}
local function add(name, fn, fullOnly) checks[#checks + 1] = { name = "UI: " .. name, fn = fn, fullOnly = fullOnly } end

-- okna u NPC: wlaczone, bledy w tej wersji
add("okna u NPC", function()
  local d = db()
  local off, bad = {}, {}
  for _, k in ipairs({ "kupiec", "trener", "poczta", "bank", "rozmowa" }) do
    if d.oknaOff and d.oknaOff[k] then off[#off + 1] = k end
    local f = d.oknaFails and d.oknaFails[k]
    if f and f.version == U.version() then bad[#bad + 1] = k .. " (" .. f.at .. "): " .. f.err end
  end
  if #bad > 0 then error("wywróciło się: " .. table.concat(bad, "; ")) end
  return #off == 0 and "wszystkie włączone" or ("okno gry dla: " .. table.concat(off, ", "))
end)

add("ForeverSkin", function()
  local found = {}
  for _, n in ipairs({ "ForeverSkinMerchantFrame", "ForeverSkinTrainerFrame", "ForeverSkinMailFrame", "ForeverSkinBankFrame" }) do
    if _G[n] then found[#found + 1] = n:gsub("ForeverSkin", ""):gsub("Frame", "") end
  end
  return (_G.GRIMUAR_FSS_LATKA and "łatka aktywna" or "bez łatki") .. ", okna FSS już zbudowane: " .. (#found > 0 and table.concat(found, ", ") or "żadne (powstają przy pierwszej wizycie)")
end)

-- trener: GetTrainerServiceInfo(i) -> name, kind ("available"/"unavailable"/"used"), ..., rank (5.)
add("trener", function()
  local t = db().diag and db().diag.trener
  if not t then return ago(nil) end
  local p = split(t.first)
  if not t.first then return ago(t) .. ", brak usług" end
  local kinds = { available = 1, unavailable = 1, used = 1 }
  if not kinds[p[2] or ""] then error("inna kolejność danych: " .. tostring(t.first) .. " (" .. ago(t) .. ")") end
  return ago(t) .. ", " .. tostring(t.n) .. " usług, kolejność danych zgodna"
end)

-- kupiec: GetMerchantItemInfo(i) -> name, texture, price (liczba), quantity, ...
add("kupiec", function()
  local t = db().diag and db().diag.kupiec
  if not t then return ago(nil) end
  local p = split(t.first)
  if t.first and not t.first:find("^brak") and not tonumber(p[3] or "") then
    error("cena nie jest 3. wartością: " .. tostring(t.first) .. " (" .. ago(t) .. ")")
  end
  return ago(t) .. ", " .. tostring(t.n) .. " towarów, " .. tostring(t.c)
end)

-- poczta: GetInboxHeaderInfo(i) -> packageIcon, stationery, sender, subject, money, COD, daysLeft, ...
add("poczta", function()
  local t = db().diag and db().diag.poczta
  if not t then return ago(nil) end
  local n = tonumber(split(t.n)[1] or "") or 0
  if n > 0 then
    local p = split(t.first)
    if not tonumber(p[5] or "") or not tonumber(p[7] or "") then error("inna kolejność danych listu: " .. tostring(t.first)) end
  end
  return ago(t) .. ", listów: " .. n
end)

add("bank", function()
  local t = db().diag and db().diag.bank
  local api = (Enum and Enum.BagIndex and Enum.BagIndex.CharacterBankTab_1) and "zakładki postaci" or "stary bank i torby"
  if not t then return "klient: " .. api .. ", " .. ago(nil) end
  if (t.slots or 0) == 0 then error("bank bez miejsc (" .. tostring(t.tabs) .. ", torby " .. tostring(t.bags) .. ")") end
  return ago(t) .. ", " .. tostring(t.tabs) .. ", " .. tostring(t.slots) .. " miejsc"
end)

-- ustawienia: ile opcji ze stron zna klient
add("ustawienia", function()
  local P = U.UST and U.UST.cvarPages
  if not P then error("brak stron ustawień") end
  local all, miss = 0, {}
  for _, pg in pairs(P) do
    for _, o in ipairs(pg.rows or {}) do
      all = all + 1
      local ok, v = pcall(function() return C_CVar and C_CVar.GetCVar and C_CVar.GetCVar(o[2]) or GetCVar(o[2]) end)
      if not ok or v == nil then miss[#miss + 1] = o[2] end
    end
  end
  return (all - #miss) .. " z " .. all .. " opcji działa" .. (#miss > 0 and (", klient nie zna (ukryte): " .. table.concat(miss, ", ")) or "")
end)

add("klawisze i makra", function()
  local need = { "SetBinding", "SaveBindings", "GetCurrentBindingSet", "GetBindingKey", "CreateMacro", "EditMacro", "DeleteMacro", "PickupMacro" }
  local miss = {}
  for _, n in ipairs(need) do if type(_G[n]) ~= "function" then miss[#miss + 1] = n end end
  if #miss > 0 then error("brak w kliencie: " .. table.concat(miss, ", ")) end
  local a, c = GetNumMacros()
  return "API jest, makra: " .. tostring(a) .. " ogólnych, " .. tostring(c) .. " postaci"
end)

-- hub: przy pelnym tescie buduje i odswieza kazda zakladke (to samo co /hub test)
add("hub", function(full)
  if full and U.SelfTest then pcall(U.SelfTest, true) end
  local t = db().lastTest
  if not t then return "zakładki jeszcze nie sprawdzone (/gr test pełny albo /hub test)" end
  if #(t.bad or {}) > 0 and t.version == U.version() then error(#t.bad .. " zakładek z błędem: " .. table.concat(t.bad, "; "):sub(1, 300)) end
  return t.ok .. " z " .. t.total .. " zakładek działa (" .. t.at .. ")"
end)

-- testy z plikow wczytanych wczesniej (nowe okna): U.testChecksExtra = { { name, fn, fullOnly } }
for _, c in ipairs(U.testChecksExtra or {}) do add(c[1], c[2], c[3]) end
G.testChecks = G.testChecks or {}
for _, c in ipairs(checks) do G.testChecks[#G.testChecks + 1] = c end
