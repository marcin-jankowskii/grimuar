-- Grimuar UI: elementy makiety „HUD · Eksploracja” i „Walka” (14.11, gracz: „Tak” na zalegle elementy makiet).
-- 1) Nazwa miejsca: po wejsciu do strefy albo podstrefy na srodku u gory mala nazwa krainy, duza nazwa miejsca
--    (Alegreya SC) i rodzaj ziemi (Przymierze, Horda, strefa sporna, sanktuarium). Napisy gry (ZoneTextString itd.)
--    dostaja tylko przezroczystosc 0. Ponizej strzalki Polestara (ona stoi na TOP -140). /hub strefa wylacza.
-- 2) Jeden kanal powiadomien po lewej (makieta: .toasts): komunikaty Grimuara (zamiast wstegi u gory; GrimuarSetup
--    Wstegi.lua zostaje zapasem, /hub komunikaty wraca do niej), „Odkryto” (nowe miejsce i XP), „Zebrano” (ziola, ruda,
--    kamien), „Postep zadania”. Najwyzej 4 naraz, 5 s (wazne 7 s). Obok sciagi Combo Frosta, gdy jest na ekranie.
local ADDON, U = ...
local C = U.C
local G = U.G or {}

local PVP = { sanctuary = { "Sanktuarium", { 0.55, 0.75, 0.95 } }, friendly = { "Ziemie Przymierza", { 0.62, 0.80, 0.50 } },
  hostile = { "Ziemie Hordy: uważaj", { 0.94, 0.45, 0.40 } }, contested = { "Strefa sporna", { 0.95, 0.70, 0.35 } },
  combat = { "Strefa walki", { 0.94, 0.45, 0.40 } }, arena = { "Arena", { 0.94, 0.45, 0.40 } } }
local GREEN = { 0.50, 0.79, 0.35 }
local K = { toasts = {}, pool = {} }

local function db() return U.db() end
local function kf() return math.max(0.6, (UIParent:GetHeight() or 900) / 900) end

-- ---------- 1) nazwa miejsca ----------
local Z
local BLIZZ_ZONE = { "ZoneTextString", "SubZoneTextString", "PVPInfoTextString", "PVPArenaTextString" }
local function blizzZone(alpha)
  for _, n in ipairs(BLIZZ_ZONE) do local fs = _G[n] if fs and fs.SetAlpha then pcall(fs.SetAlpha, fs, alpha) end end
end
local function buildZone()
  if Z then return end
  local k = kf()
  Z = CreateFrame("Frame", "GrimuarStrefa", UIParent)
  Z:SetFrameStrata("LOW")
  Z:SetSize(900 * k, 90 * k)
  Z:SetPoint("TOP", UIParent, "TOP", 0, -230 * k)
  Z:EnableMouse(false)
  Z.small = U.Text(Z, math.floor(14 * k + 0.5), "title", C.text)
  Z.small:SetPoint("TOP", 0, 0)
  Z.small:SetJustifyH("CENTER")
  U.Shadow(Z.small)
  Z.big = U.Text(Z, math.floor(44 * k + 0.5), "title", C.text)
  Z.big:SetPoint("TOP", Z.small, "BOTTOM", 0, -2)
  Z.big:SetJustifyH("CENTER")
  U.Shadow(Z.big)
  Z.pvp = U.Text(Z, math.floor(13 * k + 0.5), "body", C.muted)
  Z.pvp:SetPoint("TOP", Z.big, "BOTTOM", 0, -4)
  Z.pvp:SetJustifyH("CENTER")
  U.Shadow(Z.pvp)
  Z:Hide()
  Z:SetScript("OnUpdate", function(self)
    local t = GetTime() - (self.t0 or 0)
    local a = t < 0.4 and t / 0.4 or (t < 3.6 and 1 or math.max(0, 1 - (t - 3.6) / 1.0))
    self:SetAlpha(a * 0.95)
    if t > 4.7 then self:Hide() end
  end)
end
local function showZone()
  if db().noStrefa or InCombatLockdown() then return end
  buildZone()
  local zone, sub = GetRealZoneText() or "", GetSubZoneText() or ""
  local big, small = zone, ""
  if sub ~= "" and sub ~= zone then big, small = sub, zone end
  local key = zone .. "|" .. big
  if key == K.lastZone and GetTime() - (K.zoneAt or 0) < 60 then return end
  K.lastZone, K.zoneAt = key, GetTime()
  Z.small:SetText(small:upper())
  Z.big:SetText(big)
  local pt = U.call(GetZonePVPInfo)
  local p = pt and PVP[pt]
  Z.pvp:SetText(p and p[1] or "")
  if p then U.Color(Z.pvp, p[2]) end
  blizzZone(0)
  Z.t0 = GetTime()
  Z:SetAlpha(0)
  Z:Show()
end

-- ---------- 2) powiadomienia po lewej ----------
local holder
local function placeHolder()
  local k = kf()
  holder:ClearAllPoints()
  local combo = _G.GrimuarRunyCombo
  if combo and combo:IsShown() then holder:SetPoint("TOPLEFT", combo, "TOPRIGHT", 20 * k, 0)
  else holder:SetPoint("TOPLEFT", UIParent, "TOPLEFT", 40 * k, -300 * k) end
end
local function toastFrame()
  local k = kf()
  local t = table.remove(K.pool)
  if t then return t end
  t = CreateFrame("Frame", nil, holder)
  t:SetSize(360 * k, 50 * k)
  t:EnableMouse(false)
  t.bg = t:CreateTexture(nil, "BACKGROUND")
  t.bg:SetAllPoints()
  pcall(function()
    t.bg:SetColorTexture(1, 1, 1, 1)
    t.bg:SetGradient("HORIZONTAL", CreateColor(C.bg[1], C.bg[2], C.bg[3], 0.88), CreateColor(C.bg[1], C.bg[2], C.bg[3], 0))
  end)
  t.rh = U.Diamond(t, 13 * k, C.gold, true)
  t.rh:SetPoint("TOPLEFT", 14 * k, -14 * k)
  t.title = U.Text(t, math.floor(13 * k + 0.5), "title", C.gold)
  t.title:SetPoint("TOPLEFT", 36 * k, -10 * k)
  U.Shadow(t.title)
  t.text = U.Para(t, math.floor(14 * k + 0.5), 310 * k, C.text)
  t.text:SetPoint("TOPLEFT", t.title, "BOTTOMLEFT", 0, -3 * k)
  U.Shadow(t.text)
  return t
end
local function layoutToasts()
  local k, y = kf(), 0
  for _, t in ipairs(K.toasts) do
    t:ClearAllPoints()
    t:SetPoint("TOPLEFT", holder, "TOPLEFT", 0, -y)
    y = y + t:GetHeight() + 10 * k
  end
end
local function dropToast(t)
  for i, x in ipairs(K.toasts) do if x == t then table.remove(K.toasts, i) break end end
  t:Hide()
  t:SetScript("OnUpdate", nil)
  K.pool[#K.pool + 1] = t
  layoutToasts()
end
-- 15.11 (R30 P33): onClick (opcjonalny) = wpis klikalny (alarm rzadkiego: Prowadz), po kliknieciu znika
function U.toast(title, text, col, secs, filled, onClick)
  if not holder then
    holder = CreateFrame("Frame", "GrimuarKomunikaty", UIParent)
    holder:SetFrameStrata("MEDIUM")
    holder:SetSize(10, 10)
  end
  placeHolder()
  -- ten sam tytul w ciagu 3 s: dopisz do istniejacego („Zebrano: Silverleaf ×2 · Peacebloom”)
  local last = K.toasts[#K.toasts]
  if last and last.key == title and GetTime() - last.t0 < 3 and title == "Zebrano" then
    last.text:SetText(last.text:GetText() .. " · " .. text)
    last.t0 = GetTime()
    last:SetHeight(math.max(44 * kf(), 26 * kf() + last.title:GetStringHeight() + last.text:GetStringHeight()))
    layoutToasts()
    return
  end
  while #K.toasts >= 4 do dropToast(K.toasts[1]) end
  local t = toastFrame()
  col = col or C.gold
  t.key, t.t0, t.secs = title, GetTime(), secs or 5
  t.title:SetText(((G.tr and G.tr(title)) or title):upper())
  U.Color(t.title, col)
  t.text:SetText(text or "")
  t.rh:Set(col, filled ~= false)
  t:SetHeight(math.max(44 * kf(), 26 * kf() + t.title:GetStringHeight() + t.text:GetStringHeight()))
  t:EnableMouse(onClick ~= nil)
  t:SetScript("OnMouseUp", onClick and function(self)
    pcall(onClick)
    dropToast(self)
  end or nil)
  K.toasts[#K.toasts + 1] = t
  layoutToasts()
  t:SetAlpha(0)
  t:Show()
  t:SetScript("OnUpdate", function(self)
    local e = GetTime() - self.t0
    if e < 0.25 then self:SetAlpha(e / 0.25)
    elseif e < self.secs then self:SetAlpha(1)
    elseif e < self.secs + 0.6 then self:SetAlpha(1 - (e - self.secs) / 0.6)
    else dropToast(self) end
  end)
end

-- komunikaty Grimuara (Engine.showToast -> G.showBanner) do kanalu po lewej
local oldBanner
local function grimuarBanner(msg, key, loud)
  if db().toastsTop and oldBanner then return oldBanner(msg, key, loud) end
  local title = (G.bannerTitle and U.call(G.bannerTitle, key)) or "Grimuar"
  G.recent = G.recent or {}
  table.insert(G.recent, 1, { date("%H:%M"), title, tostring(msg or "") })
  while #G.recent > 8 do table.remove(G.recent) end
  local text = (tostring(msg or ""):gsub("^%l", string.upper))
  U.toast(title, text, loud and C.danger or C.gold, loud and 7 or 5, true)
  pcall(function() if loud then PlaySound(SOUNDKIT.RAID_WARNING) else PlaySound(SOUNDKIT.MAP_PING) end end)
end

-- „Odkryto”, „Zebrano”, „Postep zadania”
local function toPat(fmt)
  if type(fmt) ~= "string" then return nil end
  local p = fmt:gsub("%%%d?%$?s", "\001"):gsub("%%%d?%$?d", "\002")
  p = p:gsub("[%^%$%(%)%%%.%[%]%*%+%-%?]", "%%%0")
  return "^" .. p:gsub("\001", "(.+)"):gsub("\002", "(%%d+)") .. "$"
end
local EXP_XP, EXP = toPat(_G.ERR_ZONE_EXPLORED_XP), toPat(_G.ERR_ZONE_EXPLORED)
local SELF_PREFIX = type(_G.LOOT_ITEM_SELF) == "string" and _G.LOOT_ITEM_SELF:match("^(.-)%%") or nil
local function secret(v) return issecretvalue and issecretvalue(v) end

local function onSystem(msg)
  if type(msg) ~= "string" or secret(msg) or db().toastsTop then return end
  if EXP_XP then
    local place, xp = msg:match(EXP_XP)
    if place then U.toast("Odkryto", place .. " · +" .. xp .. " doświadczenia", C.gold, 5, true) return end
  end
  if EXP then
    local place = msg:match(EXP)
    if place then U.toast("Odkryto", place, C.gold, 5, true) end
  end
end
local function onLoot(msg)
  if type(msg) ~= "string" or secret(msg) or db().toastsTop or not SELF_PREFIX then return end
  if msg:sub(1, #SELF_PREFIX) ~= SELF_PREFIX then return end
  local id = tonumber(msg:match("item:(%d+)"))
  if not id then return end
  local _, _, _, _, _, classID, subID = U.call(C_Item and C_Item.GetItemInfoInstant or GetItemInfoInstant, id)
  if classID ~= 7 or not (subID == 9 or subID == 7) then return end -- dobra handlowe: zioła (9), metal i kamień (7)
  local n = tonumber(msg:match("x(%d+)%.?$")) or 1
  local name = msg:match("%[(.-)%]") or ("#" .. id)
  U.toast("Zebrano", name .. (n > 1 and (" ×" .. n) or ""), GREEN, 5, false)
end
local function onInfo(msg)
  if type(msg) ~= "string" or secret(msg) or db().toastsTop then return end
  local what, a, b = msg:match("^(.+): (%d+)/(%d+)$")
  if what then U.toast("Postęp zadania", what .. "  " .. a .. " / " .. b, C.gold, 4, a == b) end
end

-- ---------- zdarzenia ----------
local ev = CreateFrame("Frame")
for _, e in ipairs({ "PLAYER_LOGIN", "ZONE_CHANGED", "ZONE_CHANGED_NEW_AREA", "ZONE_CHANGED_INDOORS", "CHAT_MSG_SYSTEM",
  "UI_INFO_MESSAGE", "CHAT_MSG_LOOT", "PLAYER_ENTERING_WORLD" }) do pcall(ev.RegisterEvent, ev, e) end
ev:SetScript("OnEvent", function(_, event, a1, a2)
  if event == "PLAYER_LOGIN" then
    oldBanner = G.showBanner
    G.showBanner = grimuarBanner
    blizzZone(db().noStrefa and 1 or 0)
  elseif event == "ZONE_CHANGED" or event == "ZONE_CHANGED_NEW_AREA" or event == "ZONE_CHANGED_INDOORS" or event == "PLAYER_ENTERING_WORLD" then
    C_Timer.After(0.3, function() pcall(showZone) end)
  elseif event == "CHAT_MSG_SYSTEM" then pcall(onSystem, a1)
  elseif event == "UI_INFO_MESSAGE" then
    pcall(onSystem, a2)
    pcall(onInfo, a2)
  elseif event == "CHAT_MSG_LOOT" then pcall(onLoot, a1)
  end
end)

function U.hudEkranCmd(what)
  local d = db()
  if what == "strefa" then
    d.noStrefa = not d.noStrefa
    blizzZone(d.noStrefa and 1 or 0)
    U.say("nazwa miejsca Grimuara: " .. (d.noStrefa and "wyłączona (napisy gry wracają)" or "włączona") .. ".")
  elseif what == "komunikaty" then
    d.toastsTop = not d.toastsTop
    U.say(d.toastsTop and "komunikaty wracają na wstęgę u góry." or "komunikaty po lewej (jeden kanał).")
  end
end
if U.G then U.G.hudEkranCmd = U.hudEkranCmd end
