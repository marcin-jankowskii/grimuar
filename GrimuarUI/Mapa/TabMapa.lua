-- Grimuar UI: zakladka Mapa (makieta 14.11 „Hub · Mapa”; krok B, przebudowa 14.11 po zrzucie gracza „ta mape chcialbym
-- zebys jakos lepiej zrobil”). Wlasne rysowanie mapy z kafli gry (C_Map.GetMapArtLayerTextures + odkryte obszary),
-- bez ruszania okna mapy gry. Mapa wypelnia cale miejsce: kolko przybliza (do x5), przeciaganie przesuwa.
-- Na mapie: Ty (duza strzalka z poswiata), cele zadan z Questie (romb w kolorze zadania), „?” = gdzie oddac gotowe,
-- krok planu Grimuara z linia, Twoj znacznik, zwloki. Warstwy wlaczasz w panelu. Panel: zadania tutaj od najblizszego
-- (odleglosc i kierunek); LPM prowadzi strzalka Polestara, PPM otwiera zadanie w Dzienniku. Dane zadan: MapaQuestie.lua.
local ADDON, U = ...
local G, C = U.G, U.C

local M = { base = {}, over = {}, marks = {}, qp = {}, sp = {}, ap = {}, z = 1, ox = 0, oy = 0 }
U.MAP = M -- MapaLegenda.lua: tryby mapy, legenda i zbieractwo
local TILE, SIDE, ZMAX = 256, 340, 5
local TINT = { 0.9, 0.87, 0.82 } -- pergamin mapy lekko przygaszony pod ciemny hub
local GAP = 20

local function layers()
  local d = U.db()
  d.mapLayers = d.mapLayers or { obj = true, done = true, route = true }
  if d.mapLayers.svc == nil then d.mapLayers.svc = true end
  return d.mapLayers
end
local function mapInfo(id) return id and U.call(C_Map.GetMapInfo, id) or nil end
local function playerMap() return U.call(C_Map.GetBestMapForUnit, "player") end
local function playerPos(mapID)
  local p = U.call(C_Map.GetPlayerMapPosition, mapID, "player")
  if not p or not p.GetXY then return nil end
  local x, y = p:GetXY()
  x, y = U.num(x), U.num(y)
  if x and y and (x > 0 or y > 0) and x <= 1 and y <= 1 then return x, y end
end
local function fmt(v) return (string.format("%.1f", v * 100):gsub("%.", ",")) end
local function isZone(info)
  return info and info.mapType and info.mapType >= ((Enum and Enum.UIMapType and Enum.UIMapType.Zone) or 3)
end

-- ---------- widok: dopasowanie, przyblizenie, przesuwanie ----------
local function fit()
  local W, H = M.cv:GetWidth() or 0, M.cv:GetHeight() or 0
  local bw = math.max(100, math.min(W, H * 1.5))
  return bw, bw / 1.5, W, H
end
local function clampView()
  local bw, bh, W, H = fit()
  local aw, ah = bw * M.z, bh * M.z
  if aw <= W then M.ox = (W - aw) / 2 else M.ox = math.max(W - aw, math.min(0, M.ox)) end
  if ah <= H then M.oy = (H - ah) / 2 else M.oy = math.max(H - ah, math.min(0, M.oy)) end
end
local function anchorArt()
  M.art:ClearAllPoints()
  M.art:SetPoint("TOPLEFT", M.cv, "TOPLEFT", M.ox, -M.oy)
end
local function cvCursor()
  local x, y = GetCursorPosition()
  local s = M.cv:GetEffectiveScale()
  local l, t = M.cv:GetLeft(), M.cv:GetTop()
  if not l or not t then return nil end
  return x / s - l, t - y / s
end
local function cursorXY()
  local x, y = GetCursorPosition()
  local s = M.art:GetEffectiveScale()
  local l, t = M.art:GetLeft(), M.art:GetTop()
  if not l or not t then return end
  local mx, my = (x / s - l) / M.art:GetWidth(), (t - y / s) / M.art:GetHeight()
  if mx < 0 or mx > 1 or my < 0 or my > 1 then return end
  return mx, my
end

-- ---------- kafle ----------
local function tex(pool, i, layer)
  local t = pool[i]
  if not t then
    t = M.art:CreateTexture(nil, layer)
    t:SetVertexColor(TINT[1], TINT[2], TINT[3])
    pool[i] = t
  end
  return t
end
local function drawArt(mapID)
  for _, t in ipairs(M.base) do t:Hide() end
  for _, t in ipairs(M.over) do t:Hide() end
  local W, H = M.art:GetWidth(), M.art:GetHeight()
  local ls = C_Map.GetMapArtLayers and U.call(C_Map.GetMapArtLayers, mapID)
  local L = type(ls) == "table" and ls[1]
  if not L or not W or W <= 0 then M.noArt:Show() return end
  M.noArt:Hide()
  local files = (C_Map.GetMapArtLayerTextures and U.call(C_Map.GetMapArtLayerTextures, mapID, 1)) or {}
  local sx, sy = W / L.layerWidth, H / L.layerHeight
  local cols, rows = math.ceil(L.layerWidth / L.tileWidth), math.ceil(L.layerHeight / L.tileHeight)
  local i = 0
  for r = 1, rows do
    for c = 1, cols do
      i = i + 1
      local t = tex(M.base, i, "BACKGROUND")
      t:SetTexture(files[i])
      t:SetTexCoord(0, 1, 0, 1)
      t:SetSize(L.tileWidth * sx, L.tileHeight * sy)
      t:ClearAllPoints()
      t:SetPoint("TOPLEFT", M.art, "TOPLEFT", (c - 1) * L.tileWidth * sx, -(r - 1) * L.tileHeight * sy)
      t:Show()
    end
  end
  -- odkryte obszary (jak MapExplorationPin gry: kafle 256, ostatni rzad i kolumna przyciete)
  local fn = C_MapExplorationInfo and C_MapExplorationInfo.GetExploredMapTextures
  local ex = fn and U.call(fn, mapID)
  local n = 0
  for _, info in ipairs(type(ex) == "table" and ex or {}) do
    local nW, nH, k = info.numTexturesWide or 1, info.numTexturesTall or 1, 0
    for row = 1, nH do
      local ph, fh = TILE, TILE
      if row == nH then
        ph = (info.textureHeight or TILE) % TILE
        if ph == 0 then ph = TILE end
        fh = 16
        while fh < ph do fh = fh * 2 end
      end
      for col = 1, nW do
        local pw, fw = TILE, TILE
        if col == nW then
          pw = (info.textureWidth or TILE) % TILE
          if pw == 0 then pw = TILE end
          fw = 16
          while fw < pw do fw = fw * 2 end
        end
        k, n = k + 1, n + 1
        local t = tex(M.over, n, "BORDER")
        t:SetTexture(info.fileDataIDs and info.fileDataIDs[k])
        t:SetTexCoord(0, pw / fw, 0, ph / fh)
        t:SetSize(pw * sx, ph * sy)
        t:ClearAllPoints()
        t:SetPoint("TOPLEFT", M.art, "TOPLEFT", ((info.offsetX or 0) + TILE * (col - 1)) * sx, -((info.offsetY or 0) + TILE * (row - 1)) * sy)
        t:Show()
      end
    end
  end
end

-- ---------- znaczniki Grimuara ----------
local function mark(i)
  local m = M.marks[i]
  if m then return m end
  m = CreateFrame("Frame", nil, M.pins)
  m:SetSize(26, 26)
  m:SetFrameLevel(M.pins:GetFrameLevel() + 6)
  m.d = U.Diamond(m, 20, C.gold, true)
  m.d:SetPoint("CENTER")
  m.label = U.Text(m, 13, "title", C.text, "OUTLINE")
  m.label:SetPoint("BOTTOM", m, "TOP", 0, 2)
  m.label:SetJustifyH("CENTER")
  M.marks[i] = m
  return m
end
local function placeMarks()
  for _, m in ipairs(M.marks) do m:Hide() end
  local W, H = M.art:GetWidth(), M.art:GetHeight()
  local id, n = M.mapID, 0
  M.target = nil
  local function add(x, y, col, text, filled)
    if not x or not y then return end
    n = n + 1
    local m = mark(n)
    m.d:Set(col, filled)
    m.label:SetText(text or "")
    m:ClearAllPoints()
    m:SetPoint("CENTER", M.art, "TOPLEFT", x * W, -y * H)
    m:Show()
    return true
  end
  -- krok planu (to samo, co dok Grimuara)
  local st = layers().route and (U.call(G.buildSteps) or {})[1]
  local loc = st and st.loc
  if type(loc) == "table" and loc[1] == id and loc[2] and loc[3] then
    if add(loc[2] / 100, loc[3] / 100, C.gold, loc[4] or "Krok planu", true) then M.target = { loc[2] / 100, loc[3] / 100 } end
  end
  -- cel strzalki Polestara (to, dokad naprawde prowadzi strzalka); bez Polestara: znacznik z huba
  local nav = Polestar and Polestar.Nav and Polestar.Nav.GetTarget and U.call(Polestar.Nav.GetTarget)
  local nx, ny = nav and tonumber(nav.x), nav and tonumber(nav.y)
  M.navSig = nil
  if nav and nx and ny then
    M.navSig = tostring(nav.map) .. ":" .. nx .. ":" .. ny
    -- cel na innej mapie (np. Ironforge, gdy patrzysz na Dun Morogh): przeliczony przez wspolrzedne swiata;
    -- poza ta mapa: znacznik przy krawedzi w strone celu (zrzut gracza 14.11: „Walk to Ironforge”, a mapa pusta)
    local tx, ty = nx / 100, ny / 100
    local nmap = tonumber(nav.map)
    local label = (U.polestarText and U.polestarText(nav.label)) or nav.label or "Strzałka"
    if nmap ~= id then
      local px2, py2
      if C_Map.GetWorldPosFromMapPos and C_Map.GetMapPosFromWorldPos and CreateVector2D then
        local cont, wpos = U.call(C_Map.GetWorldPosFromMapPos, nmap, CreateVector2D(tx, ty))
        if cont and wpos then
          local _, pos = U.call(C_Map.GetMapPosFromWorldPos, cont, wpos, id)
          if pos and pos.GetXY then px2, py2 = pos:GetXY() px2, py2 = U.num(px2), U.num(py2) end
        end
      end
      local info = mapInfo(nmap)
      if px2 and py2 then
        local inside = px2 >= 0 and px2 <= 1 and py2 >= 0 and py2 <= 1
        tx, ty = math.max(0.02, math.min(0.98, px2)), math.max(0.02, math.min(0.98, py2))
        label = label .. ((info and info.name and not label:find(info.name, 1, true)) and (" · " .. info.name) or "") .. (inside and "" or " (dalej)")
      else
        tx = nil
      end
    end
    if tx then
      add(tx, ty, C.frost, label, true)
      M.target = { tx, ty }
    end
  elseif M.pin and M.pin[1] == id then
    M.navSig = nil
    add(M.pin[2], M.pin[3], C.frost, M.pin[4] or "Znacznik", true)
    M.target = { M.pin[2], M.pin[3] }
  end
  local wp = C_Map.GetUserWaypoint and U.call(C_Map.GetUserWaypoint)
  if wp and wp.uiMapID == id and wp.position and not M.pin and not nav then
    local x, y = wp.position:GetXY()
    add(U.num(x), U.num(y), C.frost, "Znacznik gry", false)
  end
  local cp = C_DeathInfo and C_DeathInfo.GetCorpseMapPosition and U.call(C_DeathInfo.GetCorpseMapPosition, id)
  if cp and cp.GetXY then
    local x, y = cp:GetXY()
    add(U.num(x), U.num(y), C.danger, "Zwłoki", true)
  end
end

local function guide(x, y, label)
  M.pin = { M.mapID, x, y, label }
  if G.wayTo then
    pcall(G.wayTo, M.mapID, tonumber(string.format("%.2f", x * 100)), tonumber(string.format("%.2f", y * 100)), label or "Znacznik z huba")
  end
  placeMarks()
end

-- ---------- znaczniki zadan (Questie) ----------
local function pinSize(p, big)
  local d = p.d
  if d and d.kind == "done" then
    local s = big and 30 or 24
    p:SetSize(s, s) p.q:SetSize(s, s)
  else
    local s = big and 17 or 13
    p:SetSize(s + 4, s + 4) p.o:SetSize(s, s) p.i:SetSize(s - 4, s - 4)
  end
end
local function highlight(qid)
  M.hl = qid
  for i = 1, M.qn or 0 do
    local p = M.qp[i]
    local on = not qid or (p.d and p.d.qid == qid)
    p:SetAlpha(on and 1 or 0.2)
    pinSize(p, qid ~= nil and on)
  end
end
local function pinEnter(self)
  local d = self.d
  if not d then return end
  GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
  GameTooltip:SetText(d.title or "", C.gold[1], C.gold[2], C.gold[3])
  if d.kind == "done" then
    GameTooltip:AddLine("Gotowe — oddaj: " .. (d.name or "?"), C.ok[1], C.ok[2], C.ok[3])
  else
    if d.text then GameTooltip:AddLine(d.text, 1, 1, 1, true) end
    if d.name and d.name ~= d.text then GameTooltip:AddLine(d.name, 0.75, 0.75, 0.75) end
  end
  local px, py = playerPos(M.mapID)
  local m, dir
  if px then m, dir = U.mapDistance(M.mapID, px, py, d.x, d.y) end
  if m then GameTooltip:AddLine(U.fmtDistance(m) .. " na " .. dir, C.muted[1], C.muted[2], C.muted[3]) end
  GameTooltip:AddLine("LPM: prowadź strzałką · PPM: w Dzienniku", C.faint[1], C.faint[2], C.faint[3])
  GameTooltip:Show()
  highlight(d.qid)
end
local function qpin(i)
  local p = M.qp[i]
  if p then return p end
  p = CreateFrame("Button", nil, M.pins)
  p.o = p:CreateTexture(nil, "ARTWORK")
  p.o:SetPoint("CENTER")
  p.o:SetColorTexture(0.06, 0.05, 0.035, 0.95)
  p.i = p:CreateTexture(nil, "ARTWORK", nil, 1)
  p.i:SetPoint("CENTER")
  pcall(p.o.SetRotation, p.o, math.rad(45))
  pcall(p.i.SetRotation, p.i, math.rad(45))
  p.q = p:CreateTexture(nil, "ARTWORK", nil, 2)
  p.q:SetPoint("CENTER")
  p:RegisterForClicks("LeftButtonUp", "RightButtonUp")
  p:SetScript("OnEnter", pinEnter)
  p:SetScript("OnLeave", function() GameTooltip:Hide() highlight(nil) end)
  p:SetScript("OnClick", function(self, btn)
    local d = self.d
    if not d then return end
    if btn == "RightButton" then
      if U.questShow then U.questShow(d.qid) end
    else
      guide(d.x, d.y, d.kind == "done" and ("Oddaj: " .. (d.name or d.title)) or d.title)
    end
  end)
  M.qp[i] = p
  return p
end
local function placeQuest()
  for _, p in ipairs(M.qp) do p:Hide() end
  M.qn = 0
  local pins = U.questPins and U.questPins(M.mapID) or {}
  local L = layers()
  local W, H = M.art:GetWidth(), M.art:GetHeight()
  local n = 0
  for _, d in ipairs(pins) do
    if n >= 500 then break end
    if U.mapShows("quest") then
      n = n + 1
      local p = qpin(n)
      p.d = d
      local done = d.kind == "done"
      p.o:SetShown(not done)
      p.i:SetShown(not done)
      p.q:SetShown(done)
      if done then
        p.q:SetTexture(U.QUEST_DONE_ICON)
        p:SetFrameLevel(M.pins:GetFrameLevel() + 4)
      else
        p.i:SetColorTexture(d.col[1], d.col[2], d.col[3], 1)
        p:SetFrameLevel(M.pins:GetFrameLevel() + 2)
      end
      pinSize(p, false)
      p:ClearAllPoints()
      p:SetPoint("CENTER", M.art, "TOPLEFT", d.x * W, -d.y * H)
      p:Show()
    end
  end
  M.qn = n
  if M.hl then highlight(M.hl) end
  -- „!”: kto ma dla Ciebie nowe zadanie (zlote: z trasy Polestara, szare: spoza niej)
  for _, p in ipairs(M.ap) do p:Hide() end
  if not (U.mapShows and U.mapShows("quest") and U.availablePins) then return end
  local an = 0
  for _, d in ipairs(U.availablePins(M.mapID) or {}) do
    if an >= 120 then break end
    an = an + 1
    local p = M.ap[an]
    if not p then
      p = CreateFrame("Button", nil, M.pins)
      p:SetSize(20, 20)
      p.i = p:CreateTexture(nil, "ARTWORK")
      p.i:SetAllPoints()
      p:RegisterForClicks("LeftButtonUp")
      p:SetScript("OnEnter", function(self)
        local a = self.d
        if not a then return end
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText("Do wzięcia u: " .. (a.name or "?"), C.gold[1], C.gold[2], C.gold[3])
        for _, q in ipairs(a.quests) do
          local col = q.route and C.text or C.faint
          GameTooltip:AddLine((q.level and ("[" .. q.level .. "] ") or "") .. q.title .. (q.route and "  · trasa Polestara" or ""), col[1], col[2], col[3])
        end
        GameTooltip:AddLine("LPM: prowadź strzałką", C.faint[1], C.faint[2], C.faint[3])
        GameTooltip:Show()
      end)
      p:SetScript("OnLeave", function() GameTooltip:Hide() end)
      p:SetScript("OnClick", function(self) if self.d then guide(self.d.x, self.d.y, "Weź: " .. (self.d.name or "zadanie")) end end)
      M.ap[an] = p
    end
    p.d = d
    p:SetFrameLevel(M.pins:GetFrameLevel() + (d.route and 3 or 2))
    p.i:SetTexture(d.route and U.QUEST_AVAIL_ICON or U.QUEST_AVAIL_GRAY)
    p:SetAlpha(d.route and 1 or 0.7)
    p:ClearAllPoints()
    p:SetPoint("CENTER", M.art, "TOPLEFT", d.x * W, -d.y * H)
    p:Show()
  end
end

-- ---------- wazne postacie (MapaUslugi.lua: lot, karczma, bank, aukcje, naprawa, poczta, trenerzy) ----------
local LABEL_ALWAYS = { ["Flight Master"] = true, Innkeeper = true, Banker = true, Auctioneer = true, ["Class Trainer"] = true,
  ["Portal Trainer"] = true }
local function svcPin(i)
  local p = M.sp[i]
  if p then return p end
  p = CreateFrame("Button", nil, M.pins)
  p:SetSize(22, 22)
  p:SetFrameLevel(M.pins:GetFrameLevel() + 1)
  p.bg = p:CreateTexture(nil, "BACKGROUND")
  p.bg:SetTexture("Interface\\CharacterFrame\\TempPortraitAlphaMask")
  p.bg:SetVertexColor(0.05, 0.04, 0.03, 0.75)
  p.bg:SetPoint("CENTER")
  p.bg:SetSize(24, 24)
  p.i = p:CreateTexture(nil, "ARTWORK")
  p.i:SetPoint("CENTER")
  p.i:SetSize(18, 18)
  p.t = U.Text(p, 11, "body", C.text, "OUTLINE")
  p.t:SetPoint("TOP", p, "BOTTOM", 0, -1)
  p.t:SetJustifyH("CENTER")
  p:RegisterForClicks("LeftButtonUp")
  p:SetScript("OnEnter", function(self)
    local d = self.d
    if not d then return end
    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
    GameTooltip:SetText(d.name or d.kind.pl, C.gold[1], C.gold[2], C.gold[3])
    if d.sub and d.sub ~= "" then GameTooltip:AddLine("<" .. d.sub .. ">", 1, 1, 1) end
    GameTooltip:AddLine(d.kind.pl, C.muted[1], C.muted[2], C.muted[3])
    local px, py = playerPos(M.mapID)
    local m, dir
    if px then m, dir = U.mapDistance(M.mapID, px, py, d.x, d.y) end
    if m then GameTooltip:AddLine(U.fmtDistance(m) .. " na " .. dir, C.muted[1], C.muted[2], C.muted[3]) end
    GameTooltip:AddLine("LPM: prowadź strzałką", C.faint[1], C.faint[2], C.faint[3])
    GameTooltip:Show()
  end)
  p:SetScript("OnLeave", function() GameTooltip:Hide() end)
  p:SetScript("OnClick", function(self) if self.d then guide(self.d.x, self.d.y, self.d.name or self.d.kind.pl) end end)
  M.sp[i] = p
  return p
end
local function placeService()
  for _, p in ipairs(M.sp) do p:Hide() end
  if not (U.mapShows and U.mapShows("svc")) or not U.servicePins then return end
  local id = M.mapID
  U.servicePins(id, function(pins)
    if id ~= M.mapID then return end
    for _, p in ipairs(M.sp) do p:Hide() end
    local W, H = M.art:GetWidth(), M.art:GetHeight()
    local n = 0
    for _, d in ipairs(pins) do
      if n >= 300 then break end
      n = n + 1
      local p = svcPin(n)
      p.d = d
      p.i:SetTexture(d.kind.icon)
      local show = LABEL_ALWAYS[d.kind.key] or (d.kind.key or ""):find("^prof") or M.z >= 2
      p.t:SetText((show and not d.object) and (d.name or "") or "")
      p:ClearAllPoints()
      p:SetPoint("CENTER", M.art, "TOPLEFT", d.x * W, -d.y * H)
      p:Show()
    end
  end)
end

local function applyView(redraw)
  local bw, bh = fit()
  clampView()
  M.art:SetSize(bw * M.z, bh * M.z)
  anchorArt()
  if redraw ~= false then
    drawArt(M.mapID)
    placeMarks()
    placeQuest()
    placeService()
    if U.MAP_placeGather then U.MAP_placeGather() end
  end
  M.zoomT:SetText(M.z > 1.01 and (string.format("x%.1f", M.z):gsub("%.", ",")) or "")
end
local function zoomAt(f, cx, cy)
  local bw, bh, W, H = fit()
  cx, cy = cx or W / 2, cy or H / 2
  local nz = math.max(1, math.min(ZMAX, M.z * f))
  if math.abs(nz - M.z) < 0.001 then return end
  local u, v = (cx - M.ox) / (bw * M.z), (cy - M.oy) / (bh * M.z)
  M.z = nz
  M.ox, M.oy = cx - u * bw * nz, cy - v * bh * nz
  applyView()
end
local function centerOnMe()
  local x, y = playerPos(M.mapID)
  if not x then
    local id = playerMap()
    if id and id ~= M.mapID then M.show(id) x, y = playerPos(id) end
  end
  if not x then return end
  if M.z < 2 then M.z = 2.5 end
  local bw, bh, W, H = fit()
  M.ox, M.oy = W / 2 - x * bw * M.z, H / 2 - y * bh * M.z
  applyView()
end

-- ---------- panel boczny ----------
local function crumbs(id)
  local names, guard = {}, 0
  local info = mapInfo(id)
  while info and info.parentMapID and info.parentMapID > 0 and guard < 6 do
    info = mapInfo(info.parentMapID)
    guard = guard + 1
    if info and info.name then table.insert(names, 1, info.name) end
  end
  return table.concat(names, " › ")
end

local function sidebar()
  local id = M.mapID
  local info = mapInfo(id)
  M.crumbs:SetText(crumbs(id))
  M.title:SetText(info and info.name or "Mapa")
  local lo, hi = U.call(C_Map.GetMapLevels, id)
  lo, hi = U.num(lo), U.num(hi)
  M.levels:SetText((lo and hi and hi > 0) and ("Poziomy " .. lo .. "–" .. hi) or "")
  M.bind:SetText(GetBindLocation and (GetBindLocation() or "—") or "—")
  if U.mapLegendRefresh then pcall(U.mapLegendRefresh) end
end

-- dla MapaLegenda.lua
M.guide, M.highlight, M.playerPos, M.mapInfo, M.isZone = guide, highlight, playerPos, mapInfo, isZone
function M.placeAll()
  placeMarks()
  placeQuest()
  placeService()
  if U.MAP_placeGather then U.MAP_placeGather() end
end

function M.show(id)
  id = id or M.mapID or playerMap()
  if not id then return end
  if id ~= M.mapID then M.z, M.ox, M.oy, M.hl = 1, 0, 0, nil end
  M.mapID = id
  applyView()
  sidebar()
end

local function onClick(_, btn)
  local info = mapInfo(M.mapID)
  if btn == "RightButton" then
    if info and info.parentMapID and info.parentMapID > 0 then M.show(info.parentMapID) end
    return
  end
  local mx, my = cursorXY()
  if not mx then return end
  if info and not isZone(info) then
    local child = U.call(C_Map.GetMapInfoAtPosition, M.mapID, mx, my)
    if child and child.mapID and child.mapID ~= M.mapID then M.show(child.mapID) end
    return
  end
  guide(mx, my, "Znacznik z huba")
end

-- ---------- uklad ----------
local function vignette(f, point, w, h, horiz, flip)
  local t = f:CreateTexture(nil, "ARTWORK")
  t:SetPoint(point)
  if w then t:SetWidth(w) else t:SetPoint(point == "TOP" and "TOPLEFT" or "BOTTOMLEFT") t:SetPoint(point == "TOP" and "TOPRIGHT" or "BOTTOMRIGHT") end
  if h then t:SetHeight(h) else t:SetPoint(point == "LEFT" and "TOPLEFT" or "TOPRIGHT") t:SetPoint(point == "LEFT" and "BOTTOMLEFT" or "BOTTOMRIGHT") end
  local ok = pcall(function()
    t:SetColorTexture(1, 1, 1, 1)
    local a, b = CreateColor(C.bg[1], C.bg[2], C.bg[3], 0.75), CreateColor(C.bg[1], C.bg[2], C.bg[3], 0)
    if flip then a, b = b, a end
    t:SetGradient(horiz and "HORIZONTAL" or "VERTICAL", a, b)
  end)
  if not ok then t:SetColorTexture(C.bg[1], C.bg[2], C.bg[3], 0.25) end
end

local function build(page)
  -- panel boczny
  local side = U.Panel(page, 0.86, true)
  side:SetPoint("TOPRIGHT") side:SetPoint("BOTTOMRIGHT")
  side:SetWidth(SIDE + 36)
  local inner = CreateFrame("Frame", nil, side)
  inner:SetPoint("TOPLEFT", 18, -16) inner:SetPoint("BOTTOMRIGHT", -18, 16)
  M.side = inner
  M.crumbs = U.Text(inner, 12, "body", C.faint)
  M.crumbs:SetPoint("TOPLEFT")
  M.crumbs:SetWidth(SIDE)
  M.title = U.Para(inner, 30, SIDE, C.gold, "title")
  M.title:SetPoint("TOPLEFT", M.crumbs, "BOTTOMLEFT", 0, -4)
  M.levels = U.Text(inner, 13, "body", C.muted)
  M.levels:SetPoint("TOPLEFT", M.title, "BOTTOMLEFT", 0, -4)
  M.coords = U.Text(inner, 13, "body", C.text)
  M.coords:SetPoint("TOPLEFT", M.levels, "BOTTOMLEFT", 0, -8)

  if U.mapLegendBuild then U.mapLegendBuild(inner, M.coords) end

  local bGame = U.Button(inner, "Mapa gry z Questie", SIDE, 30)
  bGame:SetPoint("BOTTOMLEFT", inner, "BOTTOMLEFT", 0, 0)
  bGame:SetScript("OnClick", function() U.OpenGame(function() ToggleWorldMap() end) end)
  local bClear = U.Button(inner, "Usuń mój znacznik", SIDE, 30)
  bClear:SetPoint("BOTTOMLEFT", bGame, "TOPLEFT", 0, 8)
  bClear:SetScript("OnClick", function()
    M.pin = nil
    if G.releaseArrow then pcall(G.releaseArrow) end
    if C_Map.ClearUserWaypoint then pcall(C_Map.ClearUserWaypoint) end
    placeMarks()
  end)
  local bHome = U.Button(inner, "Moja strefa", SIDE, 30, true)
  bHome:SetPoint("BOTTOMLEFT", bClear, "TOPLEFT", 0, 8)
  bHome:SetScript("OnClick", function() M.show(playerMap()) end)
  local box = U.Panel(inner, 0.45, false)
  box:SetSize(SIDE, 52)
  box:SetPoint("BOTTOMLEFT", bHome, "TOPLEFT", 0, 14)
  M.box = box
  local bl = U.Label(box, "Kamień powrotu")
  bl:SetPoint("TOPLEFT", 12, -9)
  M.bind = U.Text(box, 14, "body", C.text)
  M.bind:SetPoint("TOPLEFT", bl, "BOTTOMLEFT", 0, -4)

  -- plotno mapy: cale miejsce po lewej od panelu
  local cv = CreateFrame("Frame", nil, page)
  cv:SetPoint("TOPLEFT")
  cv:SetPoint("BOTTOMRIGHT", side, "BOTTOMLEFT", -GAP, 0)
  cv:SetClipsChildren(true)
  M.cv = cv
  local cbg = U.Rect(cv, C.bg, 0.92)
  cbg:SetAllPoints()
  local art = CreateFrame("Frame", nil, cv)
  art:SetSize(300, 200)
  M.art = art
  local vig = CreateFrame("Frame", nil, cv)
  vig:SetAllPoints()
  vig:SetFrameLevel(art:GetFrameLevel() + 2)
  vignette(vig, "LEFT", 70, nil, true, false)
  vignette(vig, "RIGHT", 70, nil, true, true)
  vignette(vig, "TOP", nil, 60, false, true)
  vignette(vig, "BOTTOM", nil, 60, false, false)
  M.pins = CreateFrame("Frame", nil, cv)
  M.pins:SetAllPoints()
  M.pins:SetFrameLevel(art:GetFrameLevel() + 5)
  local frame = CreateFrame("Frame", nil, page)
  frame:SetAllPoints(cv)
  frame:SetFrameLevel(M.pins:GetFrameLevel() + 20)
  U.Border(frame, C.edge)
  U.Corners(frame)
  M.noArt = U.Text(cv, 16, "body", C.muted)
  M.noArt:SetPoint("CENTER")
  M.noArt:SetText("Gra nie podała kafli tej mapy. Mapa gry: przycisk po prawej.")
  M.noArt:Hide()

  M.line = M.pins:CreateLine(nil, "ARTWORK")
  M.line:SetThickness(3)
  M.line:SetColorTexture(C.gold[1], C.gold[2], C.gold[3], 0.8)
  M.line:Hide()
  M.me = CreateFrame("Frame", nil, M.pins)
  M.me:SetSize(44, 44)
  M.me:SetFrameLevel(M.pins:GetFrameLevel() + 10)
  M.halo = M.me:CreateTexture(nil, "BACKGROUND")
  M.halo:SetTexture("Interface\\CharacterFrame\\TempPortraitAlphaMask")
  M.halo:SetVertexColor(C.frost[1], C.frost[2], C.frost[3], 0.45)
  M.halo:SetSize(40, 40)
  M.halo:SetPoint("CENTER")
  pcall(function()
    local ag = M.halo:CreateAnimationGroup()
    ag:SetLooping("BOUNCE")
    local a = ag:CreateAnimation("Alpha")
    a:SetFromAlpha(1)
    a:SetToAlpha(0.25)
    a:SetDuration(0.9)
    ag:Play()
  end)
  M.arrow = M.me:CreateTexture(nil, "OVERLAY")
  M.arrow:SetTexture("Interface\\Minimap\\MinimapArrow")
  M.arrow:SetSize(42, 42)
  M.arrow:SetPoint("CENTER")
  M.me:Hide()

  M.hover = U.Text(frame, 16, "title", C.text, "OUTLINE")
  M.hover:SetPoint("TOP", frame, "TOP", 0, -14)
  M.hover:SetJustifyH("CENTER")
  M.cursorT = U.Text(frame, 13, "body", C.text, "OUTLINE")
  M.cursorT:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", 14, 12)
  M.zoomT = U.Text(frame, 13, "body", C.muted, "OUTLINE")
  M.zoomT:SetPoint("LEFT", M.cursorT, "RIGHT", 14, 0)

  if U.mapSearchBuild then pcall(U.mapSearchBuild, frame) end
  -- przyciski widoku (prawy dolny rog mapy)
  local zIn = U.Button(frame, "+", 34, 34)
  zIn:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -12, 12)
  zIn:SetScript("OnClick", function() zoomAt(1.5) end)
  local zOut = U.Button(frame, "-", 34, 34)
  zOut:SetPoint("RIGHT", zIn, "LEFT", -6, 0)
  zOut:SetScript("OnClick", function() zoomAt(1 / 1.5) end)
  local me = U.Button(frame, "Ja", nil, 34)
  me:SetPoint("RIGHT", zOut, "LEFT", -6, 0)
  me:SetScript("OnClick", centerOnMe)

  cv:EnableMouse(true)
  cv:EnableMouseWheel(true)
  cv:SetScript("OnMouseDown", function(_, btn)
    if btn ~= "LeftButton" then return end
    local cx, cy = cvCursor()
    if cx then M.drag = { cx = cx, cy = cy, ox = M.ox, oy = M.oy, moved = false } end
  end)
  cv:SetScript("OnMouseUp", function(self, btn)
    local d = M.drag
    M.drag = nil
    if btn == "LeftButton" and d and d.moved then return end
    onClick(self, btn)
  end)
  cv:SetScript("OnMouseWheel", function(_, delta)
    local cx, cy = cvCursor()
    zoomAt(delta > 0 and 1.3 or 1 / 1.3, cx, cy)
  end)
  local acc, accSide = 0, 0
  cv:SetScript("OnUpdate", function(_, el)
    local d = M.drag
    if d then
      local cx, cy = cvCursor()
      if cx then
        if not d.moved and math.abs(cx - d.cx) + math.abs(cy - d.cy) > 4 then d.moved = true end
        if d.moved then
          M.ox, M.oy = d.ox + (cx - d.cx), d.oy + (cy - d.cy)
          clampView()
          anchorArt()
        end
      end
    end
    acc, accSide = acc + el, accSide + el
    if accSide > 1 then
      accSide = 0
      pcall(U.mapLegendRefresh)
      -- strzalka Polestara poszla gdzie indziej (nastepny krok, inny przycisk): przestaw znacznik i linie
      local nav = Polestar and Polestar.Nav and Polestar.Nav.GetTarget and U.call(Polestar.Nav.GetTarget)
      local sig = nav and nav.x and (tostring(nav.map) .. ":" .. tonumber(nav.x) .. ":" .. tonumber(nav.y)) or nil
      if sig ~= M.navSig then pcall(placeMarks) end
    end
    if acc < 0.05 then return end
    acc = 0
    local W, H = M.art:GetWidth(), M.art:GetHeight()
    local x, y = playerPos(M.mapID)
    if x then
      M.me:ClearAllPoints()
      M.me:SetPoint("CENTER", M.art, "TOPLEFT", x * W, -y * H)
      local f = U.num(U.call(GetPlayerFacing))
      if f then pcall(M.arrow.SetRotation, M.arrow, f) end
      M.me:Show()
      M.coords:SetText("Ty: " .. fmt(x) .. " · " .. fmt(y))
      if M.target then
        M.line:SetStartPoint("TOPLEFT", M.art, x * W, -y * H)
        M.line:SetEndPoint("TOPLEFT", M.art, M.target[1] * W, -M.target[2] * H)
        M.line:Show()
      else
        M.line:Hide()
      end
    else
      M.me:Hide()
      M.line:Hide()
      M.coords:SetText("Nie ma Cię na tej mapie")
    end
    local info = mapInfo(M.mapID)
    local hov, cur = "", ""
    if cv:IsMouseOver() then
      local mx, my = cursorXY()
      if mx then
        cur = "Kursor: " .. fmt(mx) .. " · " .. fmt(my)
        if info and not isZone(info) then
          local child = U.call(C_Map.GetMapInfoAtPosition, M.mapID, mx, my)
          hov = child and child.mapID ~= M.mapID and child.name or ""
        end
      end
    end
    M.hover:SetText(hov)
    M.cursorT:SetText(cur)
  end)
end

function U.mapShow(id)
  M.want = id
  U.Select("mapa")
end
-- wyszukiwarka postaci (MapaSzukaj.lua) i inne zakladki: pokaz strefe, postaw znacznik i ustaw strzalke Polestara
function U.mapGuide(mapID, x, y, label)
  if not (U.IsOpen() and U.Current() == "mapa") then
    M.want = mapID
    if not U.Open("mapa") then return end
  end
  if M.mapID ~= mapID then M.show(mapID) end
  guide(x, y, label)
end

-- zdarzenia przy otwartej zakladce: dziennik zadan (postep celow, oddane zadania)
local ev = CreateFrame("Frame")
ev:SetScript("OnEvent", function()
  if M.pending then return end
  M.pending = true
  C_Timer.After(0.6, function()
    M.pending = false
    if M.cv and M.cv:IsVisible() then
      if U.questPinsReset then U.questPinsReset() end
      pcall(placeQuest)
      pcall(U.mapLegendRefresh)
    end
  end)
end)

U.RegisterTab({
  id = "mapa", order = 4, title = "Mapa", keys = "M",
  build = build,
  refresh = function()
    for _, e in ipairs({ "QUEST_LOG_UPDATE", "QUEST_WATCH_UPDATE", "QUEST_TURNED_IN", "QUEST_ACCEPTED" }) do pcall(ev.RegisterEvent, ev, e) end
    if U.questPinsReset then U.questPinsReset() end
    local id = M.want or M.mapID or playerMap()
    M.want = nil
    M.show(id)
    -- rozmiary plotna sa pewne dopiero w nastepnej klatce
    C_Timer.After(0, function() if M.cv and M.cv:IsVisible() then M.show(M.mapID) end end)
  end,
  leave = function() ev:UnregisterAllEvents() M.drag = nil end,
  hints = { { { "LPM" }, "Znacznik / strefa" }, { { "Przeciągnij" }, "Przesuń" }, { { "Kółko" }, "Przybliż" }, { { "PPM" }, "Mapa wyżej" } },
  note = "Postacie: kliknij pole „Szukaj” na mapie (lista miast) albo /npc nazwa",
})
