-- Grimuar UI: zestawy sprzetu PvE i PvP (14.11, R24 P11). Menedzer zestawow gry (C_EquipmentSet, ten sam, ktorego
-- uzywa okno postaci Forever Skin): „Zapisz” zapamietuje to, co masz na sobie, jako „Grimuar PvE” albo „Grimuar PvP”,
-- „Załóż” zaklada zestaw (tylko poza walka). Na 60: PvE = Intelekt i obrazenia, PvP = Wytrzymalosc (R12).
local ADDON, U = ...
local C = U.C

local SETS = { pve = { "Grimuar PvE", "Interface\\Icons\\Spell_Frost_FrostBolt02" }, pvp = { "Grimuar PvP", "Interface\\Icons\\INV_BannerPVP_02" } }

local function api() return C_EquipmentSet end
local function idOf(kind)
  local E = api()
  if not (E and E.GetEquipmentSetID) then return nil end
  return U.num(U.call(E.GetEquipmentSetID, SETS[kind][1]))
end

function U.gearSave(kind)
  local E = api()
  if not E then U.say("ta wersja gry nie ma menedżera zestawów.") return end
  if InCombatLockdown() then U.say("zestawy zapisuję poza walką.") return end
  local id = idOf(kind)
  local ok
  if id then ok = pcall(E.SaveEquipmentSet, id)
  else
    ok = pcall(E.CreateEquipmentSet, SETS[kind][1], SETS[kind][2])
    if ok and not idOf(kind) then ok = false end
  end
  U.say(ok and ("zapisałem to, co masz na sobie, jako „" .. SETS[kind][1] .. "”.") or "gra nie pozwoliła zapisać zestawu.")
end

function U.gearUse(kind)
  local E = api()
  if not E then U.say("ta wersja gry nie ma menedżera zestawów.") return end
  if InCombatLockdown() then U.say("w walce zestawu nie założysz.") return end
  local id = idOf(kind)
  if not id then U.say("najpierw załóż rzeczy i kliknij „Zapisz” przy " .. kind:upper() .. ".") return end
  local ok = pcall(E.UseEquipmentSet, id)
  U.say(ok and ("zakładam „" .. SETS[kind][1] .. "”.") or "gra nie pozwoliła założyć zestawu.")
end

-- blok do lewej kolumny Postaci
function U.gearSetsBuild(parent)
  local f = CreateFrame("Frame", nil, parent)
  f:SetSize(270, 96)
  local h = U.H2(f, "Zestawy sprzętu")
  h:SetPoint("TOPLEFT")
  local prev = h
  for _, kind in ipairs({ "pve", "pvp" }) do
    local row = CreateFrame("Frame", nil, f)
    row:SetSize(270, 28)
    row:SetPoint("TOPLEFT", prev, "BOTTOMLEFT", 0, -8)
    local l = U.Text(row, 13, "body", C.text)
    l:SetPoint("LEFT")
    l:SetText(kind:upper())
    local use = U.Button(row, "Załóż", 80, 26, true)
    use:SetPoint("LEFT", row, "LEFT", 46, 0)
    use:SetScript("OnClick", function() U.gearUse(kind) end)
    local save = U.Button(row, "Zapisz obecny", nil, 26)
    save:SetPoint("LEFT", use, "RIGHT", 8, 0)
    save:SetScript("OnClick", function() U.gearSave(kind) end)
    row.use = use
    f[kind] = row
    prev = row
  end
  function f:Refresh()
    for _, kind in ipairs({ "pve", "pvp" }) do
      local has = idOf(kind) ~= nil
      self[kind].use:SetAlpha(has and 1 or 0.45)
    end
  end
  f:SetScript("OnShow", function(self) pcall(self.Refresh, self) end)
  return f
end
