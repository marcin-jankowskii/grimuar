-- Grimuar UI: Trener w stylu huba (15.11, plan R29 etap 2). Zamiast okna trenera ForeverSkin (ForeverSkinTrainerFrame)
-- albo gry (ClassTrainerFrame), przyczepione i wieksze, wiec je przykrywa (Okna/Wspolne.lua). Okno gry zostaje otwarte pod
-- spodem (jego zamkniecie konczy wizyte), dostaje tylko przezroczystosc 0.
-- Sekcje: „Do kupienia wg buildu” (z suma i przyciskiem „Kup wg buildu”: GrimuarSetup Trener.lua, te same zasady co
-- dotad), „Dostepne, pomijasz” (z powodem z buildu; klik i tak kupuje), „Pozniej” (wymagany poziom), „Masz” (liczba).
-- Trener profesji: wszystko dostepne w jednej sekcji. Klik w wiersz = BuyTrainerService (zwykla funkcja gry).
local ADDON, U = ...
local C = U.C
local G = U.G or {}

local W, H = 900, 600
local F

local function money(c) return U.money and U.money(c) or tostring(c) end
local function services()
  local out = {}
  for i = 1, U.num(U.call(GetNumTrainerServices)) or 0 do
    local okS, name, kind, _, _, rank = pcall(GetTrainerServiceInfo, i)
    if not okS then name = nil end
    if name and kind ~= "header" then
      out[#out + 1] = { i = i, name = name, kind = kind, rank = rank, cost = U.num(U.call(GetTrainerServiceCost, i)) or 0,
        lvl = U.num(U.call(GetTrainerServiceLevelReq, i)), icon = U.call(GetTrainerServiceIcon, i) }
    end
  end
  return out
end

function U.trenerDraw()
  if not (F and F:IsShown()) then return end
  local ok, err = pcall(function()
    F.title:SetText(U.call(UnitName, "npc") or "Trener")
    local prof = U.call(IsTradeskillTrainer)
    local classT = not prof and G.trainIsClass and U.call(G.trainIsClass)
    F.sub:SetText(prof and "trener profesji" or (classT and ("trener klasy · build: " .. tostring(G.BD_META and G.BD_META.name or "?")) or "trener"))
    local buy, skip, later, have, cost = {}, {}, {}, 0, 0
    for _, s in ipairs(services()) do
      if s.kind == "available" then
        if classT and G.trainWanted then
          if G.trainWanted(s.name, s.rank) then buy[#buy + 1] = s cost = cost + s.cost else skip[#skip + 1] = s end
        else buy[#buy + 1] = s cost = cost + s.cost end
      elseif s.kind == "unavailable" then later[#later + 1] = s
      elseif s.kind == "used" then have = have + 1 end
    end
    table.sort(later, function(a, b) return (a.lvl or 0) < (b.lvl or 0) end)
    local items = {}
    local function sec(title) items[#items + 1] = { head = title } end
    sec(classT and ("Do kupienia wg buildu (" .. #buy .. ")") or ("Dostępne (" .. #buy .. ")"))
    for _, s in ipairs(buy) do items[#items + 1] = { s = s, why = classT and "w buildzie" or nil, col = C.ok } end
    if #skip > 0 then
      sec("Dostępne, pomijasz (" .. #skip .. ")")
      for _, s in ipairs(skip) do items[#items + 1] = { s = s, why = G.trainReason and U.call(G.trainReason, s.name) or "poza buildem", col = C.faint } end
    end
    if #later > 0 then
      sec("Później (" .. #later .. ")")
      for _, s in ipairs(later) do items[#items + 1] = { s = s, why = s.lvl and ("od poziomu " .. s.lvl) or "jeszcze nie", col = C.muted, later = true } end
    end
    F.list:Fill(#items, function(r, n)
      local it = items[n]
      local head = it.head ~= nil
      r.slot:SetShown(not head) r.s:SetShown(not head) r.why:SetShown(not head) r.r:SetShown(not head)
      r.bg:SetShown(not head)
      if head then
        r.t:SetText(it.head) U.Color(r.t, C.gold)
        r.onClick, r.tip = nil, nil
        return
      end
      local s = it.s
      r.slot.icon:SetTexture(s.icon or 134400)
      r.slot.icon:SetDesaturated(it.later and true or false)
      r.slot:SetQuality(nil)
      r.slot.count:SetText("")
      r.t:SetText(s.name) U.Color(r.t, it.later and C.muted or C.text)
      r.s:SetText((s.rank and s.rank ~= "") and s.rank or "")
      r.why:SetText(it.why or "") U.Color(r.why, it.col)
      r.r:SetText(s.cost > 0 and money(s.cost) or "")
      r.onClick = function()
        if it.later then U.say(s.name .. ": " .. (it.why or "jeszcze nie") .. ".") return end
        pcall(BuyTrainerService, s.i)
      end
      r.tip = function(tt) pcall(tt.SetTrainerService, tt, s.i) end
    end)
    F.buyAll:SetShown(#buy > 0)
    F.buyAll:SetLabel((classT and "Kup wg buildu" or "Kup wszystko") .. " (" .. #buy .. ", " .. money(cost) .. ")")
    local m = U.num(U.call(GetMoney)) or 0
    F.foot:SetText("Masz już " .. have .. " · pieniądze: " .. money(m) .. (cost > m and ("   " .. U.hex(C.danger) .. "brakuje " .. money(cost - m) .. "|r") or ""))
  end)
  if not ok then F:Fail(err) end
end

local function build()
  if F then return end
  F = U.Okno({ name = "GrimuarTrener", width = W, height = H, title = "Trener", key = "trener",
    hosts = { "ForeverSkinTrainerFrame", "ClassTrainerFrame" }, onClose = function() U.call(CloseTrainer) end })
  F.buyAll = U.Button(F, "Kup wg buildu", nil, 28, true)
  F.buyAll:SetPoint("TOPLEFT", 22, -56)
  F.buyAll:SetScript("OnClick", function()
    if U.call(IsTradeskillTrainer) or not (G.trainStart and G.trainIsClass and U.call(G.trainIsClass)) then
      -- trener profesji albo bez buildu: kup po kolei wszystko dostepne
      local n = 0
      for _, s in ipairs(services()) do if s.kind == "available" and n < 1 then pcall(BuyTrainerService, s.i) n = n + 1 end end
      return
    end
    pcall(G.trainStart)
  end)
  local hint = U.Text(F, 11, "body", C.faint)
  hint:SetPoint("LEFT", F.buyAll, "RIGHT", 14, 0)
  hint:SetText("klik w wiersz: kup ten jeden · najedź: opis czaru")
  F.list = U.OknoList(F, 40, function(p) return U.OknoRow(p, 40) end)
  F.list:SetPoint("TOPLEFT", 22, -96) F.list:SetPoint("BOTTOMRIGHT", -22, 40)
  F.foot = U.Text(F, 12, "body", C.muted)
  F.foot:SetPoint("BOTTOMLEFT", 24, 14)
end

local ev = CreateFrame("Frame")
for _, e in ipairs({ "TRAINER_SHOW", "TRAINER_CLOSED", "TRAINER_UPDATE", "PLAYER_MONEY" }) do pcall(ev.RegisterEvent, ev, e) end
ev:SetScript("OnEvent", function(_, e)
  if e == "TRAINER_SHOW" then
    C_Timer.After(0.05, function()
      build()
      if F:Open() then U.trenerDraw() end
    end)
  elseif e == "TRAINER_CLOSED" then
    if F then F:Finish() end
  elseif F and F:IsShown() then
    if F.q then return end
    F.q = true
    C_Timer.After(0.2, function() F.q = nil U.trenerDraw() end)
  end
end)
