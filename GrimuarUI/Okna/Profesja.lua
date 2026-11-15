-- Grimuar UI: Poradnik przy oknie profesji (15.11, propozycja 2: „okno profesji z poradnikiem Polestara”; gracz:
-- „te wszystkie mozesz zrobic”). Panel w stylu huba przyczepiony z prawej do okna profesji: ForeverSkin
-- (ForeverSkinProfessionsFrame, pelne okno przepisow) albo gry. Okno profesji zostaje, panel dodaje to, czego w nim nie ma:
-- * pasek umiejetnosci i nastepny prog u trenera (z krokow „train” poradnika);
-- * „Teraz”: niezrobione kroki biezacego przedzialu poradnika Polestara jako karty; krok tworzenia ma przycisk
--   „Zrob N” (C_TradeSkillUI.CraftRecipe; N = ile brakuje do konca kroku, najwyzej tyle, na ile masz skladniki);
-- * skladniki kroku: masz / potrzeba do konca kroku, ile lezy w banku, cena na aukcji (Auctionator) i sprzedawca
--   z poradnika (klik: strzalka prowadzi);
-- * kolejne przedzialy i „Otworz w Polestarze”.
-- Bez Polestara albo bez poradnika tej profesji: pasek umiejetnosci i informacja. Wylaczenie: /hub okna profesja.
local ADDON, U = ...
local C = U.C
local G = U.G or {}

local W = 390
local F
local S = {}

local SKILL_IDS = { [129] = "First Aid", [182] = "Herbalism", [186] = "Mining", [393] = "Skinning", [171] = "Alchemy",
  [164] = "Blacksmithing", [185] = "Cooking", [333] = "Enchanting", [202] = "Engineering", [356] = "Fishing",
  [165] = "Leatherworking", [197] = "Tailoring", [755] = "Jewelcrafting" }
local RANK_PL = { [75] = "Czeladnik", [150] = "Czeladnik", [225] = "Ekspert", [300] = "Mistrz" }

local function money(c) return U.money and U.money(c) or tostring(c) end
local function itemIcon(id) return id and U.call(C_Item and C_Item.GetItemIconByID, id) or nil end
local function count(id, bank)
  return U.num(U.call(C_Item and C_Item.GetItemCount or GetItemCount, id, bank and true or false)) or 0
end
local function ahPrice(id)
  local v
  pcall(function()
    local A = Auctionator and Auctionator.API and Auctionator.API.v1
    if A and A.GetAuctionPriceByItemID then v = A.GetAuctionPriceByItemID("Grimuar", id) end
  end)
  return (U.num(v) and v > 0) and v or nil
end

local function host()
  for _, n in ipairs({ "ForeverSkinProfessionsFrame", "ProfessionsFrame", "TradeSkillFrame" }) do
    local f = _G[n]
    if f and f:IsShown() and f:GetAlpha() > 0.05 and (f:GetWidth() or 0) > 200 and f:GetLeft() then return f end
  end
end

-- otwarta profesja: angielska nazwa (klucz poradnika), umiejetnosc, limit
local function profInfo()
  local name, rank, max, line
  pcall(function()
    local T = C_TradeSkillUI
    local b = T and T.GetBaseProfessionInfo and T.GetBaseProfessionInfo()
    if type(b) == "table" and b.professionName and b.professionName ~= "" then
      name, line, rank, max = b.professionName, b.professionID, b.skillLevel, b.maxSkillLevel
    end
    local c = T and T.GetChildProfessionInfo and T.GetChildProfessionInfo()
    if type(c) == "table" and (c.skillLevel or 0) > 0 then
      rank, max = c.skillLevel, c.maxSkillLevel
      name = name or c.professionName
    end
  end)
  if not name and GetTradeSkillLine then pcall(function() name, rank, max = GetTradeSkillLine() end) end
  local key = (line and SKILL_IDS[line]) or name
  if key == "Smelting" then key = "Mining" end
  return key, U.num(rank) or 0, U.num(max) or 0, name
end

local function recipe(spell)
  local T = C_TradeSkillUI
  if not (spell and T and T.GetRecipeInfo) then return nil end
  local ok, info = pcall(T.GetRecipeInfo, spell)
  return ok and type(info) == "table" and info or nil
end

local function craft(spell, name, n)
  if InCombatLockdown() then U.say("w walce nie tworzę.") return end
  n = math.max(1, n or 1)
  local ok = false
  if C_TradeSkillUI and C_TradeSkillUI.CraftRecipe then ok = pcall(C_TradeSkillUI.CraftRecipe, spell, n) end
  if not ok and DoTradeSkill and GetNumTradeSkills then
    for i = 1, U.num(U.call(GetNumTradeSkills)) or 0 do
      if (U.call(GetTradeSkillInfo, i)) == name then ok = pcall(DoTradeSkill, i, n) break end
    end
  end
  if ok then S.queue = { name = name, left = n, total = n } U.profDraw()
  else U.say("gra nie pozwoliła utworzyć z panelu: kliknij „Utwórz” w oknie profesji.") end
end

-- ile razy jeszcze zrobic, zeby dojsc do untilSkill (pomaranczowy 1 punkt, zolty ok. 1 na 1,4)
local function crafts(g, rank)
  local left = (U.num(g.untilSkill) or rank) - rank
  if left <= 0 then return 0 end
  if U.num(g.yellow) and rank >= g.yellow then return math.ceil(left * 1.4), true end
  return left, false
end

-- skladnik: karta z liczba w torbach, banku, cena i sprzedawca z poradnika
local function reagentCard(guide, r, times)
  local id = r.item
  local need = (U.num(r.count) or 1) * math.max(1, times)
  local bags = count(id, false)
  local bank = math.max(0, count(id, true) - bags)
  local name = r.itemName or U.call(C_Item and C_Item.GetItemNameByID, id) or ("przedmiot " .. tostring(id))
  local subs = {}
  if bank > 0 then subs[#subs + 1] = "w banku " .. bank end
  local p = ahPrice(id)
  if p then subs[#subs + 1] = "aukcja " .. money(p) .. "/szt." end
  local card = { title = (U.num(r.count) or 1) .. "× " .. name, right = bags .. " / " .. need, frac = math.min(1, bags / math.max(1, need)),
    done = bags >= need, icon = itemIcon(id) }
  -- sprzedawca z krokow „buy” poradnika
  for _, st in ipairs(guide.steps or {}) do
    for _, gl in ipairs(type(st.goals) == "table" and st.goals or {}) do
      if gl.t == "buy" and gl.item == id and not card.go then
        local c = U.psCandidate and U.psCandidate(gl)
        if c then
          subs[#subs + 1] = "sprzedawca: " .. (c.npcName or "?") .. " · klik: prowadź"
          card.go = { c.map, c.x, c.y, c.npcName }
        end
      end
    end
  end
  if bags < need then
    card.rightCol = C.danger
    local miss = need - bags
    if bank >= miss then subs[#subs + 1] = "weź z banku" end
  end
  card.sub = #subs > 0 and table.concat(subs, " · ") or nil
  card.tip = name .. ": w torbach " .. bags .. ", potrzeba " .. need .. " do końca kroku"
  if card.go then
    local go = card.go
    card.onClick = function() if G.wayTo then G.wayTo(go[1], go[2], go[3], go[4]) end end
  end
  return card
end

function U.profDraw()
  if not (F and F:IsShown()) then return end
  local ok, err = pcall(function()
    local p = F.blocks
    local key, rank, max, shownName = profInfo()
    p:Begin(S.lastKey == key)
    S.lastKey = key
    local pl = (U.SKILL_PL and (function() for id, en in pairs(SKILL_IDS) do if en == key then return U.SKILL_PL[id] end end end)()) or shownName or key or "Profesja"
    F.title:SetText(pl or "Profesja")
    F.sub:SetText(rank .. " / " .. max)
    local g, gid = nil, nil
    if U.psProfGuide and key then g, gid = U.psProfGuide(key) end
    -- pasek umiejetnosci i nastepny prog
    local nextTrain
    if g then
      for _, st in ipairs(g.steps) do
        for _, gl in ipairs(type(st.goals) == "table" and st.goals or {}) do
          if gl.t == "train" and U.num(gl.rankMax) and gl.rankMax > max and not nextTrain then
            local sec = g.sections and g.sections[st.section]
            nextTrain = { rankMax = gl.rankMax, from = sec and U.num(sec.from) or nil, card = U.psStepCard(st, rank, sec, g) }
          end
        end
      end
    end
    local bar = { title = "Umiejętność", right = rank .. " / " .. max, frac = max > 0 and rank / max or 0, icon = nil }
    if nextTrain then
      bar.sub = (RANK_PL[nextTrain.rankMax] or "wyższa ranga") .. " (limit " .. nextTrain.rankMax .. ")" ..
        (nextTrain.from and (" od umiejętności " .. nextTrain.from) or "") .. (rank >= (nextTrain.from or 1e9) and " · czas do trenera" or "")
      if rank >= (nextTrain.from or 1e9) then bar.col = C.ok end
    elseif max > 0 and rank >= max then
      bar.sub = "limit osiągnięty"
    end
    p:Cards({ bar }, { cols = 1 })
    if S.queue then
      p:Para("Tworzę: " .. S.queue.name .. " (" .. (S.queue.total - S.queue.left) .. " z " .. S.queue.total .. ")", C.gold, 12)
    end
    if not g then
      p:Para(_G.Polestar and "Polestar nie ma poradnika tej profesji." or "Poradniki profesji są w Polestarze: włącz Polestar na liście addonów.", C.muted, 12)
      p:End()
      return
    end
    local si, sec = U.psSectionFor(g, rank)
    p:Head("Teraz", (sec and (sec.from .. "–" .. sec.to) or "") .. " · Polestar")
    local shown = 0
    for _, st in ipairs(g.steps) do
      if st.section == si then
        local card = U.psStepCard(st, rank, sec, g)
        if not card.done then
          shown = shown + 1
          p:Cards({ card }, { cols = 1 })
          -- krok tworzenia: przycisk i skladniki
          for _, gl in ipairs(type(st.goals) == "table" and st.goals or {}) do
            if gl.t == "craft" and gl.spell then
              local info = recipe(gl.spell)
              local times, approx = crafts(gl, rank)
              local avail = info and U.num(info.numAvailable) or 0
              local name = (info and info.name) or gl.spellName or gl.itemName or "?"
              if info and info.learned == false then
                p:Para("Najpierw naucz się przepisu „" .. name .. "” (krok wyżej: trener).", C.danger, 12)
              elseif times > 0 then
                local n = math.min(times, avail)
                if n > 0 then
                  p:Button("Zrób " .. n .. "× " .. name .. (approx and " (ok. " .. times .. " do " .. gl.untilSkill .. ")" or ""), function() craft(gl.spell, name, n) end, true)
                else
                  p:Para("Brakuje składników na „" .. name .. "”: zobacz niżej.", C.danger, 12)
                end
              end
              local rc = {}
              for _, r in ipairs(type(gl.reagents) == "table" and gl.reagents or {}) do rc[#rc + 1] = reagentCard(g, r, times) end
              if #rc > 0 then p:Cards(rc, { cols = 1 }) end
            end
          end
          if shown >= 3 then break end
        end
      end
    end
    if shown == 0 then p:Para("Ten przedział jest zrobiony: podnieś umiejętność albo idź do trenera.", C.ok, 12) end
    -- dalej
    local nxt = {}
    for i, sc in ipairs(type(g.sections) == "table" and g.sections or {}) do
      if i > si and #nxt < 3 then
        local what
        for _, st in ipairs(g.steps) do if st.section == i and not what then what = U.psText(g, st.title) end end
        nxt[#nxt + 1] = { title = (sc.from or "?") .. "–" .. (sc.to or "?"), sub = what }
      end
    end
    if #nxt > 0 then p:Head("Dalej") p:Cards(nxt, { cols = 1 }) end
    p:Gap(4)
    p:Button("Otwórz w Polestarze", function() U.psOpenGuide(gid) end)
    p:Para("Klik w kartę ze sprzedawcą albo trenerem: strzałka Polestara prowadzi. Najedź: notatka z poradnika.", C.faint, 11)
    p:End()
  end)
  if not ok then
    if F then F:Hide() end
    if not S.errSaid then S.errSaid = true U.say("poradnik przy profesji: " .. tostring(err)) end
    pcall(U.logError, "okno profesja", err)
  end
end

local function build()
  if F then return end
  F = U.Panel(UIParent, 0.95, true)
  F:SetSize(W, 560)
  F:SetFrameStrata("HIGH")
  F:SetClampedToScreen(true)
  F:EnableMouse(true)
  F:Hide()
  F.title = U.Text(F, 20, "title", C.gold)
  F.title:SetPoint("TOPLEFT", 18, -14)
  F.sub = U.Text(F, 12, "body", C.muted)
  F.sub:SetPoint("LEFT", F.title, "RIGHT", 10, -1)
  F.close = U.Button(F, "×", 24, 22)
  F.close:SetPoint("TOPRIGHT", -8, -8)
  F.close:SetScript("OnClick", function() F:Hide() end)
  F.blocks = U.Blocks(F)
  F.blocks:SetPoint("TOPLEFT", 0, -40)
  F.blocks:SetPoint("BOTTOMRIGHT", 0, 0)
end

local function open()
  if not U.oknoOn("profesja") or InCombatLockdown() then return end
  build()
  local h = host()
  F:ClearAllPoints()
  if h then
    F:SetPoint("TOPLEFT", h, "TOPRIGHT", 8, 0)
    F:SetHeight(math.max(480, math.min(760, h:GetHeight() or 560)))
  else
    F:SetPoint("RIGHT", UIParent, "RIGHT", -24, 0)
    F:SetHeight(600)
  end
  F:Show()
  U.profDraw()
  pcall(function()
    local key, rank, max, name = profInfo()
    local g = key and U.psProfGuide and U.psProfGuide(key)
    U.diag("profesja", { key = tostring(key), name = tostring(name), rank = rank, max = max, guide = g and true or false,
      host = h and (h:GetName() or "?") or "brak", craftApi = (C_TradeSkillUI and C_TradeSkillUI.CraftRecipe) and "CraftRecipe" or "DoTradeSkill" })
  end)
end

local ev = CreateFrame("Frame")
for _, e in ipairs({ "TRADE_SKILL_SHOW", "TRADE_SKILL_CLOSE", "TRADE_SKILL_LIST_UPDATE", "TRADE_SKILL_DATA_SOURCE_CHANGED",
  "BAG_UPDATE_DELAYED", "SKILL_LINES_CHANGED", "UNIT_SPELLCAST_SUCCEEDED", "UNIT_SPELLCAST_INTERRUPTED", "UNIT_SPELLCAST_FAILED" }) do
  pcall(ev.RegisterEvent, ev, e)
end
ev:SetScript("OnEvent", function(_, e, unit)
  if e == "TRADE_SKILL_SHOW" then
    C_Timer.After(0.3, open)
  elseif e == "TRADE_SKILL_CLOSE" then
    S.queue = nil
    if F then F:Hide() end
  elseif e:find("^UNIT_SPELLCAST") then
    if unit ~= "player" or not S.queue then return end
    if e == "UNIT_SPELLCAST_SUCCEEDED" then
      S.queue.left = S.queue.left - 1
      if S.queue.left <= 0 then S.queue = nil end
    else
      S.queue = nil
    end
  elseif F and F:IsShown() then
    if S.q then return end
    S.q = true
    C_Timer.After(0.3, function() S.q = nil U.profDraw() end)
  end
end)

U.testChecksExtra = U.testChecksExtra or {}
table.insert(U.testChecksExtra, { "poradnik profesji", function()
  local d = U.db().diag and U.db().diag.profesja
  if not d then return "jeszcze nie otwierane (otwórz okno profesji)" end
  if d.key == "nil" then error("nie odczytano profesji z okna (" .. tostring(d.name) .. ")") end
  return "dane z " .. d.at .. ": " .. d.key .. " " .. tostring(d.rank) .. "/" .. tostring(d.max) .. ", poradnik " ..
    (d.guide and "jest" or "brak") .. ", przy oknie " .. d.host .. ", " .. d.craftApi
end })
