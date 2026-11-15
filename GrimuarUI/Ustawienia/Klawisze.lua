-- Grimuar UI: Ustawienia > Klawisze (15.11, wybor gracza: wlasne okno Klawiszy). Po polsku, w grupach: Paski akcji
-- (z tym, co lezy na przycisku: czar albo makro), Ruch, Cel i walka, Okna, Grimuar. Kazdy wiersz: dwa klawisze, „Zmien”
-- (nastepny wcisniety klawisz, z Shift/Ctrl/Alt, takze przyciski myszy 3–5 i kolko; Esc anuluje), „Usun”.
-- SetBinding i SaveBindings tylko poza walka (gra blokuje je w walce). Gdy klawisz mial inne polecenie, Grimuar mowi jakie.
local ADDON, U = ...
local C = U.C

local UST = U.UST or { pages = {} }
U.UST = UST
local K = { rows = {} }

local GROUPS = {
  { "Paski akcji", {} },
  { "Ruch", { { "MOVEFORWARD", "Do przodu" }, { "MOVEBACKWARD", "Do tyłu" }, { "STRAFELEFT", "Krok w lewo" },
    { "STRAFERIGHT", "Krok w prawo" }, { "TURNLEFT", "Obrót w lewo" }, { "TURNRIGHT", "Obrót w prawo" }, { "JUMP", "Skok" },
    { "TOGGLEAUTORUN", "Automatyczny bieg" }, { "SITORSTAND", "Usiądź / wstań" } } },
  { "Cel i walka", { { "TARGETNEARESTENEMY", "Najbliższy wróg" }, { "TARGETPREVIOUSENEMY", "Poprzedni wróg" },
    { "INTERACTTARGET", "Interakcja z celem" }, { "ASSISTTARGET", "Pomóż celowi" }, { "FOCUSTARGET", "Focus na cel" },
    { "STARTATTACK", "Atak wręcz" } } },
  { "Okna", { { "TOGGLEWORLDMAP", "Mapa świata" }, { "OPENALLBAGS", "Torby" }, { "TOGGLECHARACTER0", "Postać" },
    { "TOGGLESPELLBOOK", "Księga czarów" }, { "TOGGLETALENTS", "Talenty" }, { "TOGGLEQUESTLOG", "Dziennik zadań" },
    { "TOGGLESOCIAL", "Znajomi" }, { "TOGGLEGAMEMENU", "Menu gry" } } },
  { "Grimuar", { { "GRIMUAR_HUB", "Hub Grimuara" } } },
}
local BAR = { { "ACTIONBUTTON", "Pasek 1", 1 }, { "MULTIACTIONBAR1BUTTON", "Pasek 2", 61 }, { "MULTIACTIONBAR2BUTTON", "Pasek 3", 49 } }
for _, b in ipairs(BAR) do
  for i = 1, 12 do table.insert(GROUPS[1][2], { b[1] .. i, b[2] .. ", przycisk " .. i, slot = b[3] + i - 1 }) end
end
-- polecenia Grimuara z Bindings.xml (jesli sa)
local function grimuarBinds()
  local out = {}
  for i = 1, U.num(U.call(GetNumBindings)) or 0 do
    local cmd = U.call(GetBinding, i)
    if type(cmd) == "string" and cmd:find("^GRIMUAR") then
      local lbl = _G["BINDING_NAME_" .. cmd] or cmd
      out[#out + 1] = { cmd, lbl }
    end
  end
  return out
end

local function keyText(k)
  if not k then return "—" end
  return (k:gsub("SHIFT%-", "Shift+"):gsub("CTRL%-", "Ctrl+"):gsub("ALT%-", "Alt+"):gsub("BUTTON3", "Środkowy myszy")
    :gsub("BUTTON4", "Mysz 4"):gsub("BUTTON5", "Mysz 5"):gsub("MOUSEWHEELUP", "Kółko w górę"):gsub("MOUSEWHEELDOWN", "Kółko w dół"))
end
local function slotWhat(slot)
  if not slot then return nil end
  local kind, id = U.call(GetActionInfo, slot)
  if kind == "spell" and id then return (C_Spell and C_Spell.GetSpellName and U.call(C_Spell.GetSpellName, id)) or U.call(GetSpellInfo, id) end
  if kind == "macro" and id then local nm = U.call(GetMacroInfo, id) return nm and ("makro " .. nm) end
  if kind == "item" and id then return U.call(C_Item.GetItemNameByID, id) end
  return nil
end

-- ---------- przechwycenie klawisza ----------
local cap
local MODS = { LSHIFT = true, RSHIFT = true, LCTRL = true, RCTRL = true, LALT = true, RALT = true, LMETA = true, RMETA = true }
local function finishBind(cmd, key)
  if InCombatLockdown() then U.say("klawisze zmieniam poza walką.") return end
  local prev = U.call(GetBindingAction, key)
  for _, k in ipairs({ U.call(GetBindingKey, cmd) }) do if k == key then return end end
  local ok = pcall(SetBinding, key, cmd)
  if ok then
    pcall(SaveBindings, U.call(GetCurrentBindingSet) or 1)
    U.say(keyText(key) .. " → " .. cmd .. (prev and prev ~= "" and prev ~= cmd and (" (zastąpione: " .. prev .. ")") or "") .. ".")
  end
  if K.draw then pcall(K.draw) end
end
local function withMods(key)
  local p = ""
  if IsAltKeyDown() then p = p .. "ALT-" end
  if IsControlKeyDown() then p = p .. "CTRL-" end
  if IsShiftKeyDown() then p = p .. "SHIFT-" end
  return p .. key
end
local function startCapture(cmd, label)
  if InCombatLockdown() then U.say("klawisze zmieniam poza walką.") return end
  if not cap then
    cap = CreateFrame("Button", nil, UIParent)
    cap:SetAllPoints()
    cap:SetFrameStrata("FULLSCREEN_DIALOG")
    cap.bg = U.Rect(cap, { 0, 0, 0 }, 0.6) cap.bg:SetAllPoints()
    cap.t = U.Text(cap, 22, "title", C.gold)
    cap.t:SetPoint("CENTER", 0, 20) cap.t:SetJustifyH("CENTER")
    cap.s = U.Text(cap, 13, "body", C.text)
    cap.s:SetPoint("TOP", cap.t, "BOTTOM", 0, -10) cap.s:SetJustifyH("CENTER")
    cap:EnableKeyboard(true)
    cap:SetScript("OnKeyDown", function(self, key)
      if MODS[key] then return end
      self:Hide()
      if key == "ESCAPE" then return end
      finishBind(self.cmd, withMods(key))
    end)
    cap:SetScript("OnMouseDown", function(self, btn)
      local map = { MiddleButton = "BUTTON3", Button4 = "BUTTON4", Button5 = "BUTTON5" }
      if not map[btn] then self:Hide() return end
      self:Hide()
      finishBind(self.cmd, withMods(map[btn]))
    end)
    cap:SetScript("OnMouseWheel", function(self, d)
      self:Hide()
      finishBind(self.cmd, withMods(d > 0 and "MOUSEWHEELUP" or "MOUSEWHEELDOWN"))
    end)
    cap:EnableMouseWheel(true)
  end
  cap.cmd = cmd
  cap.t:SetText(label)
  cap.s:SetText("Wciśnij nowy klawisz (z Shift, Ctrl, Alt; także mysz 3–5 i kółko). Esc albo klik: anuluj.")
  pcall(cap.SetPropagateKeyboardInput, cap, false)
  cap:Show()
end
U.klawiszeCapture = startCapture

-- ---------- strona ----------
local function row(i)
  local r = K.rows[i]
  if r then return r end
  r = CreateFrame("Frame", nil, K.list)
  r:SetHeight(32)
  local hl = r:CreateTexture(nil, "BACKGROUND") hl:SetAllPoints() hl:SetColorTexture(1, 1, 1, 0) r.hl = hl
  r.head = U.Text(r, 14, "title", C.gold) r.head:SetPoint("LEFT", 4, -4)
  r.line = U.Line(r, C.gold, 0.25) r.line:SetPoint("BOTTOMLEFT", 4, 2) r.line:SetPoint("BOTTOMRIGHT", -4, 2)
  r.t = U.Text(r, 14, "body", C.text) r.t:SetPoint("LEFT", 12, 0) r.t:SetWidth(230) r.t:SetJustifyV("MIDDLE")
  r.w = U.Text(r, 12, "body", C.faint) r.w:SetPoint("LEFT", 250, 0) r.w:SetWidth(220) r.w:SetJustifyV("MIDDLE")
  r.k1 = U.Tag(r, "") r.k1:SetPoint("LEFT", 480, 0)
  r.k2 = U.Tag(r, "") r.k2:SetPoint("LEFT", r.k1, "RIGHT", 8, 0)
  r.del = U.Button(r, "Usuń", nil, 24) r.del:SetPoint("RIGHT", -12, 0)
  r.ch = U.Button(r, "Zmień", nil, 24, true) r.ch:SetPoint("RIGHT", r.del, "LEFT", -8, 0)
  K.rows[i] = r
  return r
end
function K.draw()
  if not K.frame then return end
  local list = {}
  local groups = {}
  for _, g in ipairs(GROUPS) do groups[#groups + 1] = g end
  local gb = grimuarBinds()
  if #gb > 0 then groups[#groups] = { "Grimuar", gb } end
  for _, g in ipairs(groups) do
    list[#list + 1] = { head = g[1] }
    for _, b in ipairs(g[2]) do list[#list + 1] = b end
  end
  local w = K.list:GetWidth() or 800
  for i, it in ipairs(list) do
    local r = row(i)
    r:ClearAllPoints() r:SetPoint("TOPLEFT", K.list, "TOPLEFT", 0, -(i - 1) * 34) r:SetWidth(w)
    local isHead = it.head ~= nil
    r.head:SetShown(isHead) r.line:SetShown(isHead)
    for _, x in ipairs({ r.t, r.w, r.k1, r.k2, r.del, r.ch }) do x:SetShown(not isHead) end
    if isHead then r.head:SetText(it.head)
    else
      local cmd = it[1]
      local k1, k2 = U.call(GetBindingKey, cmd)
      r.t:SetText(it[2])
      r.w:SetText(slotWhat(it.slot) or "")
      r.k1:SetTag(keyText(k1), k1 and C.gold or C.faint)
      r.k2:SetShown(k2 ~= nil)
      if k2 then r.k2:SetTag(keyText(k2), C.gold) end
      r.ch:SetScript("OnClick", function() startCapture(cmd, it[2]) end)
      r.del:SetScript("OnClick", function()
        if InCombatLockdown() then U.say("klawisze zmieniam poza walką.") return end
        for _, k in ipairs({ U.call(GetBindingKey, cmd) }) do pcall(SetBinding, k, nil) end
        pcall(SaveBindings, U.call(GetCurrentBindingSet) or 1)
        K.draw()
      end)
    end
    r:Show()
  end
  for i = #list + 1, #K.rows do K.rows[i]:Hide() end
  K.list:SetHeight(#list * 34)
end

UST.pages.klawisze = {
  title = "Klawisze",
  note = "Zmień: wciśnij nowy klawisz. Usuń: zdejmuje oba klawisze. Zmiany zapisują się od razu (poza walką).",
  build = function(parent)
    local f = CreateFrame("Frame", nil, parent)
    f:SetPoint("TOPLEFT", 16, -70) f:SetPoint("BOTTOMRIGHT", -16, 16)
    local v = CreateFrame("ScrollFrame", nil, f)
    v:SetAllPoints()
    K.list = CreateFrame("Frame", nil, v)
    K.list:SetSize(800, 10)
    v:SetScrollChild(K.list)
    v:EnableMouseWheel(true)
    v:SetScript("OnMouseWheel", function(self, d)
      local max = math.max(0, K.list:GetHeight() - self:GetHeight())
      self:SetVerticalScroll(math.max(0, math.min(max, self:GetVerticalScroll() - d * 102)))
    end)
    v:SetScript("OnSizeChanged", function(_, w) K.list:SetWidth(w) end)
    K.frame = f
    return f
  end,
  draw = function() K.draw() end,
  -- wyszukiwarka Ustawien: wiersze „Zmien” dla polecen pasujacych do nazwy albo zawartosci przycisku
  search = function(q)
    local out = {}
    for _, g in ipairs(GROUPS) do
      for _, b in ipairs(g[2]) do
        local what = slotWhat(b.slot) or ""
        if b[2]:lower():find(q, 1, true) or what:lower():find(q, 1, true) then
          local k1 = U.call(GetBindingKey, b[1])
          out[#out + 1] = { kind = "action", label = b[2] .. (what ~= "" and (" · " .. what) or "") .. "   " .. keyText(k1), btn = "Zmień",
            fn = function() startCapture(b[1], b[2]) end }
        end
      end
    end
    return out
  end,
}
