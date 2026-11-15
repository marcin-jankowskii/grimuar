-- Grimuar: modul Kraft (gracz 13.11: „chcialbym tez wiedziec co mam kraftowac”). Gdy otworzysz okno profesji (K),
-- Grimuar czyta przepisy z gry: kolor (pomaranczowy = punkt zawsze, zolty = prawie zawsze, zielony = czasem, szary = nigdy),
-- na ile sztuk masz materialy i czego brakuje do najlepszego. Wstega mowi od razu, co robic; krok „Profesje” na pasku
-- Grimuara i strona Postac > Moje profesje pamietaja wynik. Dane z okna gry, wiec zgodne z Forever (tez jego przepisy).
local ADDON_NAME, G = ...
local say = G.say

local COLOR = { [0] = { "pomarańczowy", "|cffff8040" }, [1] = { "żółty", "|cffffff00" }, [2] = { "zielony", "|cff40c040" },
  [3] = { "szary", "|cff9a9a9a" } }
local DIFF = { optimal = 0, difficult = 0, medium = 1, easy = 2, trivial = 3 }
-- 14.11 (gracz: „po co kazales mi go craftowac, zrobilem 14”): Grimuar patrzyl tylko na kolor przepisu. W Herbalism
-- przepisy to obiekty obozowe (Incense Candle: buff Int, ktory nie laczy sie z Arcane Intellect), a ziola sa warte wiecej
-- na sprzedaz albo na mikstury (First Aid). Dla tych profesji zadnych podpowiedzi „zrob …”.
local NO_CRAFT_HINT = { Herbalism = true }

local function store()
  GrimuarSetupDB.kraft = GrimuarSetupDB.kraft or {}
  local k = G.charKey and G.charKey() or "?"
  GrimuarSetupDB.kraft[k] = GrimuarSetupDB.kraft[k] or {}
  return GrimuarSetupDB.kraft[k]
end

-- nazwa profesji z otwartego okna i jej poziom
local function lineInfo()
  local name, rank, max
  pcall(function()
    local T = C_TradeSkillUI
    if T and T.GetBaseProfessionInfo then
      local i = T.GetBaseProfessionInfo()
      if i and i.professionName and i.professionName ~= "" then name, rank, max = i.professionName, i.skillLevel, i.maxSkillLevel end
    end
    if T and T.GetChildProfessionInfo then
      local c = T.GetChildProfessionInfo()
      if c and c.skillLevel and c.skillLevel > 0 then
        rank, max = c.skillLevel, c.maxSkillLevel
        name = name or c.professionName
      end
    end
    if not name and T and T.GetTradeSkillLine then
      local _
      _, name, rank, max = T.GetTradeSkillLine()
    end
  end)
  if not name and GetTradeSkillLine then pcall(function() name, rank, max = GetTradeSkillLine() end) end
  if type(name) ~= "string" or name == "" or name == "UNKNOWN" then return nil end
  return name, rank, max
end

-- nauczone przepisy: { name, d (0 pomaranczowy .. 3 szary), n (na ile sztuk masz materialy), id albo idx }
local function recipes()
  local out = {}
  local T = C_TradeSkillUI
  if T and T.GetAllRecipeIDs and T.GetRecipeInfo then
    for _, id in ipairs(T.GetAllRecipeIDs() or {}) do
      local ok, r = pcall(T.GetRecipeInfo, id)
      if ok and r and r.learned and r.name then
        local d = r.relativeDifficulty
        if type(d) ~= "number" then d = DIFF[r.difficulty or ""] end
        if d then out[#out + 1] = { id = id, name = r.name, d = d, n = r.numAvailable or 0 } end
      end
    end
  elseif GetNumTradeSkills and GetTradeSkillInfo then
    for i = 1, GetNumTradeSkills() do
      local name, kind, n = GetTradeSkillInfo(i)
      local d = DIFF[kind or ""]
      if name and d then out[#out + 1] = { idx = i, name = name, d = d, n = n or 0 } end
    end
  end
  return out
end

-- materialy przepisu: „2× Linen Cloth (masz 5)”
local function mats(r)
  local parts, missing = {}, false
  pcall(function()
    if r.id and C_TradeSkillUI.GetRecipeSchematic then
      local s = C_TradeSkillUI.GetRecipeSchematic(r.id, false)
      for _, slot in ipairs(s and s.reagentSlotSchematics or {}) do
        local rg = slot.reagents and slot.reagents[1]
        if rg and rg.itemID and slot.required ~= false then
          local have = (C_Item and C_Item.GetItemCount or GetItemCount)(rg.itemID) or 0
          local nm = (C_Item and C_Item.GetItemNameByID and C_Item.GetItemNameByID(rg.itemID)) or ("#" .. rg.itemID)
          parts[#parts + 1] = (slot.quantityRequired or 1) .. "× " .. nm .. " (masz " .. have .. ")"
          if have < (slot.quantityRequired or 1) then missing = true end
        end
      end
    elseif r.idx and GetTradeSkillNumReagents then
      for j = 1, GetTradeSkillNumReagents(r.idx) do
        local nm, _, count, have = GetTradeSkillReagentInfo(r.idx, j)
        if nm then
          parts[#parts + 1] = (count or 1) .. "× " .. nm .. " (masz " .. (have or 0) .. ")"
          if (have or 0) < (count or 1) then missing = true end
        end
      end
    end
  end)
  return table.concat(parts, ", "), missing
end

-- 13.11 (gracz: „czyli nie craftowac bandazy albo incense?”): materialy sa, a gra liczy 0 sztuk = brak miejsca/narzedzia
local TOOL = { Cooking = "ognisko (Basic Campfire z księgi profesji)", Mining = "kuźnia (Forge), np. w Kharanos",
  Smelting = "kuźnia (Forge), np. w Kharanos" }
local CLOTH_TIP = { ["First Aid"] = " Tkanina wypada z humanoidów (troggi, trolle Frostmane, bandyci)." }

-- krotki tekst: co zrobic w tej profesji (okienko Profesje, wstega, strona)
local function shortText(prof, rec)
  if rec.need and rec.need.missing == nil and type(rec.need.mats) == "string" then
    -- odczyt sprzed 13.11 bez pola missing: policz z tekstu „2× Linen Cloth (masz 0)”
    local miss = false
    for need, have in rec.need.mats:gmatch("(%d+)× [^(]+%(masz (%d+)%)") do
      if tonumber(have) < tonumber(need) then miss = true end
    end
    rec.need.missing = miss
  end
  if rec.now then
    return "zrób " .. rec.now.name .. " (" .. (COLOR[rec.now.d] or COLOR[3])[1] .. ", materiały na " .. rec.now.n .. ")"
  elseif rec.need and rec.need.missing == false then
    return rec.need.name .. " (" .. COLOR[rec.need.d][1] .. "): materiały masz, potrzebne " .. (TOOL[prof] or "narzędzie albo miejsce z opisu przepisu")
  elseif rec.need then
    return "do " .. rec.need.name .. " (" .. COLOR[rec.need.d][1] .. ") brakuje: " .. rec.need.mats .. "." .. (CLOTH_TIP[prof] or "")
  elseif rec.green then
    return "tylko zielone przepisy (punkt czasem): " .. rec.green.name .. (rec.green.mats ~= "" and (", potrzeba: " .. rec.green.mats) or "")
  end
  return "żaden przepis nie daje już punktu: nowy przepis u trenera tej profesji"
end

-- teraz: najlepszy przepis z punktem, na ktory masz materialy; best: najlepszy w ogole (moze brakowac materialow)
local function pick(list)
  local now, best
  for _, r in ipairs(list) do
    if r.d <= 1 then
      if r.n > 0 and (not now or r.d < now.d or (r.d == now.d and r.n > now.n)) then now = r end
      if not best or r.d < best.d then best = r end
    end
  end
  if not now then
    for _, r in ipairs(list) do if r.d == 2 and r.n > 0 and (not now or r.n > now.n) then now = r end end
  end
  return now, best
end

local function describe(prof, rec)
  local t = prof .. " " .. (rec.rank or "?") .. "/" .. (rec.max or "?") .. ": " .. shortText(prof, rec)
  if rec.now and rec.need and rec.need.missing then
    t = t .. ". Lepszy " .. rec.need.name .. " (" .. COLOR[rec.need.d][1] .. "), brakuje: " .. rec.need.mats
  end
  return t .. (t:sub(-1) == "." and "" or ".")
end

local last = {}
local function scan(announce)
  local prof, rank, max = lineInfo()
  if not prof then return end
  local list = recipes()
  if #list == 0 then return end
  local now, best = pick(list)
  local rec = { rank = rank, max = max, at = time() }
  if now then rec.now = { name = now.name, d = now.d, n = now.n } end
  if best and (not now or best.d < now.d) then
    local m, missing = mats(best)
    rec.need = { name = best.name, d = best.d, mats = m, missing = missing }
  end
  if not now and not best then
    for _, r in ipairs(list) do
      if r.d == 2 then
        rec.green = { name = r.name, mats = (mats(r)) }
        break
      end
    end
  end
  local prev = store()[prof]
  store()[prof] = rec
  -- wstega przy otwarciu okna i gdy zmieni sie zalecany przepis (np. pomaranczowy zrobil sie zielony)
  local changed = prev and ((prev.now and prev.now.name) ~= (rec.now and rec.now.name))
  if NO_CRAFT_HINT[prof] then
    if announce then say(prof .. ": przedmioty z tego okna magowi nic nie dają (Incense Candle nie łączy się z Arcane Intellect). Zioła sprzedaj albo zostaw na mikstury.") end
    return
  end
  if (announce or changed) and (not last[prof] or GetTime() - last[prof] > 20 or changed) then
    last[prof] = GetTime()
    local msg = describe(prof, rec)
    say(msg)
    if G.showToast then pcall(G.showToast, msg, "prof", false) end
  end
  if G.refreshAll then pcall(G.refreshAll) end
  if G.profPanelRefresh then pcall(G.profPanelRefresh) end
end

-- kroki do paska (Profesje.lua reminders): co zrobic z materialow w torbie
local function items()
  local out = {}
  for prof, rec in pairs(store()) do
    if not NO_CRAFT_HINT[prof] and rec.now and rec.now.d <= 1 and (rec.now.n or 0) > 0 then
      out[#out + 1] = { key = "kraft-" .. prof, prio = 2,
        text = prof .. " " .. (rec.rank or "?") .. "/" .. (rec.max or "?") .. ": zrób " .. rec.now.name .. " (" .. COLOR[rec.now.d][1] .. ", materiały na " .. rec.now.n .. ").",
        why = "Okno profesji: K, potem " .. prof .. ". Pomarańczowy przepis daje punkt zawsze, żółty prawie zawsze." ..
          ((prof == "Cooking") and " Gotujesz przy ognisku: Basic Campfire z księgi profesji." or "") .. " Stan z ostatniego otwarcia okna." }
    end
  end
  return out
end

-- strona Postac > Moje profesje
local function page(P)
  local s = store()
  P.H("Co kraftować (z ostatniego otwarcia okna profesji)")
  local any = false
  for prof, rec in pairs(s) do
    any = true
    P.M(describe(prof, rec))
  end
  if not any then P.M("Otwórz okno profesji (K, potem First Aid, Cooking albo Smelting): Grimuar przeczyta przepisy i powie, co robić.") end
end

local ev = CreateFrame("Frame")
for _, e in ipairs({ "TRADE_SKILL_SHOW", "TRADE_SKILL_LIST_UPDATE", "TRADE_SKILL_UPDATE", "TRADE_SKILL_DATA_SOURCE_CHANGED" }) do
  pcall(ev.RegisterEvent, ev, e)
end
local pending, wantAnnounce = false, false
ev:SetScript("OnEvent", function(_, event)
  local announce = event == "TRADE_SKILL_SHOW" or event == "TRADE_SKILL_DATA_SOURCE_CHANGED"
  wantAnnounce = wantAnnounce or announce
  if pending then return end
  pending = true
  C_Timer.After(0.6, function()
    pending = false
    local a = wantAnnounce
    wantAnnounce = false
    pcall(scan, a)
  end)
end)

G.kraftItems = items
-- krotko do okienka Profesje (OknoProfesji.lua)
G.kraftShort = function(prof)
  local r = store()[prof]
  if not r or NO_CRAFT_HINT[prof] then return nil end
  return shortText(prof, r), r
end
G.kraftPage = page
G.kraftHas = function(prof) local r = store()[prof] return r and r.now ~= nil end
G.tradeLine = lineInfo -- 14.11: hub (Rzemioslo) poznaje po tym, ktore okno profesji jest otwarte
