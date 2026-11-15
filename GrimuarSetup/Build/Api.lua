-- Grimuar: API buildow (R27 E1/E3, 14.11; gracz: „zrob wszystkie kroki, ma byc tez mozliwosc edycji buildow Polestara”).
-- Build to dane (nigdy kod): talenty, czary u trenera, paski i makra, combo, porady PvP i na stwory, kolo, grupa.
-- Zrodla buildow: wbudowane (Buildy\*.lua, G.RegisterBuild), wlasne i importowane (GrimuarSetupDB.builds, po walidacji
-- Build\Walidacja.lua) oraz szkice z Polestara (Polestar.Talents: plany talentow wszystkich klas, tylko odczyt).
-- Szkic Polestara mozna edytowac: „Duplikuj do edycji” zapisuje kopie jako wlasny build (Polestara nie zmieniamy).
-- Moduly czytaja wspolne tabele G.BD (te same obiekty przez caly czas); zmiana buildu czysci je i wypelnia na nowo,
-- wiec stare odwolania (np. local MAIN = G.BD.main w Core.lua) dalej dzialaja. Aktywny build: na postac,
-- GrimuarSetupDB.buildFor[postac] (= id).
local ADDON_NAME, G = ...

G.BD = {
  macros = {}, macroNeeds = {}, keys = {}, main = {}, bar2 = {}, bar3 = {}, spells = {}, talPlan = {}, talNote = {},
  keep = {}, aoe = {}, whySkip = {}, steps = {}, rescue = {}, pvp = {}, pvp60 = {}, wheel = {}, creatures = {}, give = {},
  groupBuffs = {}, buffs = {},
}
G.BD_META = {}
local BUILTIN, ORDER = {}, {}
local listeners = {}

-- ---------- jezyk tekstow buildu ----------
function G.Lang() return (GrimuarSetupDB and GrimuarSetupDB.lang) or "pl" end
local function isText(v)
  if type(v) ~= "table" or v[1] ~= nil then return false end
  for k in pairs(v) do if k ~= "pl" and k ~= "en" then return false end end
  return v.pl ~= nil or v.en ~= nil
end
function G.BT(v)
  if isText(v) then return v[G.Lang()] or v.en or v.pl or "" end
  return v
end
local function resolved(v)
  if isText(v) then return G.BT(v) end
  if type(v) ~= "table" then return v end
  local out = {}
  for k, x in pairs(v) do out[k] = resolved(x) end
  return out
end

-- ---------- rejestr ----------
function G.RegisterBuild(b)
  if type(b) ~= "table" or type(b.id) ~= "string" then return end
  b.src = b.src or "grimuar"
  if not BUILTIN[b.id] then ORDER[#ORDER + 1] = b.id end
  BUILTIN[b.id] = b
end
function G.OnBuildChanged(fn) listeners[#listeners + 1] = fn end

local function charKey()
  if G.charKey then local ok, k = pcall(G.charKey) if ok and k then return k end end
  return (UnitName("player") or "?") .. "-" .. (GetRealmName() or "?")
end
local function playerClass()
  local ok, _, tok = pcall(UnitClass, "player")
  return ok and tok or nil
end
G.playerClassToken = playerClass

-- ---------- szkice z Polestara ----------
local function PT() local P = _G.Polestar return P and P.Talents end
local function polestarData(cls)
  local T = PT()
  if not (T and T.Data) then return nil end
  local ok, d = pcall(T.Data, cls)
  return ok and type(d) == "table" and d or nil
end
-- picks Polestara ({ node, ranga } po kolei, punkt na poziom od 10) -> plan Grimuara { nazwa, od, do, rang razem }
function G.picksToPlan(cls, picks)
  local d = polestarData(cls)
  local plan, prev = {}, nil
  for i, p in ipairs(type(picks) == "table" and picks or {}) do
    local node = d and d.nodes and d.nodes[p[1]]
    local name = node and node[7] or ("#" .. tostring(p[1]))
    local maxr = node and node[2] or 1
    local lvl = 9 + i
    if prev and prev[1] == name and prev[3] == lvl - 1 then prev[3] = lvl
    else prev = { name, lvl, lvl, maxr } plan[#plan + 1] = prev end
  end
  return plan
end
function G.PolestarBuilds(cls)
  local d = polestarData(cls or playerClass())
  local out = {}
  if not d then return out end
  for _, b in ipairs(d.builds or {}) do
    local spec = d.specs and d.specs[b.spec] or b.key
    out[#out + 1] = { id = "polestar:" .. d.class .. ":" .. b.key, key = b.key, class = d.class, spec = b.spec, specName = spec,
      split = b.split, link = b.link, picks = b.picks, src = "polestar" }
  end
  return out
end
function G.DraftFromPolestar(id)
  local cls, key = tostring(id):match("^polestar:(%u+):(.+)$")
  if not cls then return nil end
  for _, p in ipairs(G.PolestarBuilds(cls)) do
    if p.key == key then
      local picks = {}
      for i, x in ipairs(p.picks or {}) do picks[i] = { x[1], x[2] } end
      return { schema = 1, id = id, version = 1, src = "polestar", class = cls, spec = p.spec, role = "DAMAGER", levels = { 10, 60 },
        name = { pl = "Polestar: " .. p.specName .. (p.split and (" (" .. p.split .. ")") or ""), en = "Polestar: " .. p.specName .. (p.split and (" (" .. p.split .. ")") or "") },
        desc = { pl = "Szkic z planu talentów Polestara. Trener: wszystko (jak „Train All”). Duplikuj, żeby edytować.",
          en = "Draft from Polestar's talent plan. Trainer: everything (like Train All). Duplicate to edit." },
        author = "Polestar", license = "GPL-3.0", sources = { p.link or "Polestar" },
        talents = { picks = picks, from = "polestar:" .. key, tree = (polestarData(cls) or {}).tree },
        trainer = { all = true } }
    end
  end
end

-- ---------- lista i pobieranie ----------
local function db() GrimuarSetupDB = GrimuarSetupDB or {} return GrimuarSetupDB end
function G.GetBuild(id)
  if not id then return nil end
  if BUILTIN[id] then return BUILTIN[id] end
  local own = db().builds and db().builds[id]
  if own then return own end
  return G.DraftFromPolestar(id)
end
-- { { id, name, src = grimuar | moje | import | polestar, class, spec } } dla klasy (nil = wszystkie)
function G.BuildList(cls)
  local out = {}
  local function add(b, src)
    if not cls or b.class == cls then out[#out + 1] = { id = b.id, name = G.BT(b.name) or b.id, src = src or b.src, class = b.class, spec = b.spec, version = b.version } end
  end
  for _, id in ipairs(ORDER) do add(BUILTIN[id], "grimuar") end
  for _, b in pairs(db().builds or {}) do add(b, b.src == "import" and "import" or "moje") end
  for _, p in ipairs(G.PolestarBuilds(cls or playerClass())) do
    out[#out + 1] = { id = p.id, name = "Polestar: " .. p.specName .. (p.split and (" (" .. p.split .. ")") or ""), src = "polestar", class = p.class, spec = p.spec }
  end
  return out
end
function G.DefaultBuildId(cls)
  cls = cls or playerClass()
  for _, id in ipairs(ORDER) do if BUILTIN[id].class == cls then return id end end
  local p = G.PolestarBuilds(cls)[1]
  return p and p.id or nil
end
-- 14.11 (R27 4b): build osobno dla kazdej specjalizacji (dual spec od 40). Stary zapis (sam id) = specjalizacja 1.
local function specGroup()
  local CS = C_SpecializationInfo
  local g = CS and CS.GetActiveSpecGroup and select(2, pcall(CS.GetActiveSpecGroup))
  if type(g) ~= "number" and GetActiveTalentGroup then g = select(2, pcall(GetActiveTalentGroup)) end
  return (type(g) == "number" and g >= 1 and g <= 2) and g or 1
end
G.specGroup = specGroup
local function storedId()
  local d = db()
  local v = d.buildFor and d.buildFor[charKey()]
  if type(v) == "table" then return v[specGroup()] or v[1] end
  return v
end
function G.ActiveBuildId()
  local id = storedId()
  if id and G.GetBuild(id) then return id end
  return G.DefaultBuildId()
end
function G.Build() return G.GetBuild(G.ActiveBuildId()) end

-- ---------- wypelnianie G.BD ----------
local function fill(t, src)
  wipe(t)
  for k, v in pairs(type(src) == "table" and src or {}) do t[k] = resolved(v) end
end
local function asMap(src)
  local m = {}
  if type(src) ~= "table" then return m end
  for k, v in pairs(src) do
    if type(k) == "number" then m[v] = true else m[k] = resolved(v) end
  end
  return m
end
function G.ApplyBuild(b)
  local BD = G.BD
  b = type(b) == "table" and b or {}
  local macros = {}
  for i, m in ipairs(b.macros or {}) do
    local bodyT = type(m[2]) == "table" and table.concat(m[2], "\n") or m[2]
    macros[i] = { m[1], bodyT }
  end
  fill(BD.macros, macros)
  fill(BD.macroNeeds, b.macroNeeds)
  fill(BD.keys, b.keys)
  local bars = b.bars or {}
  fill(BD.main, bars.main) fill(BD.bar2, bars.bar2) fill(BD.bar3, bars.bar3)
  local tr = b.trainer or {}
  fill(BD.spells, tr.list)
  fill(BD.keep, asMap(tr.keep))
  fill(BD.aoe, asMap(tr.aoe))
  fill(BD.whySkip, tr.skip)
  local ta = b.talents or {}
  if type(ta.plan) == "table" and #ta.plan > 0 then fill(BD.talPlan, ta.plan)
  else fill(BD.talPlan, G.picksToPlan(b.class, ta.picks)) end
  fill(BD.talNote, ta.notes)
  local co = b.combo or {}
  fill(BD.steps, co.steps) fill(BD.rescue, co.rescue)
  local pv = b.pvp or {}
  fill(BD.pvp, pv[1]) fill(BD.pvp60, pv[40])
  fill(BD.wheel, b.wheel)
  fill(BD.creatures, b.creatures)
  local gr = b.group or {}
  fill(BD.give, gr.give) fill(BD.groupBuffs, gr.buffs)
  fill(BD.buffs, b.buffs)
  local M = G.BD_META
  wipe(M)
  M.id, M.name, M.class, M.spec, M.role, M.src = b.id, G.BT(b.name), b.class, b.spec, b.role, b.src
  M.trainAll, M.aoeOn = tr.all == true, tr.aoeOn == true
  M.stats, M.route, M.consumables, M.cc, M.dispel = b.stats, b.route, b.consumables, gr.cc, gr.dispel
  for _, fn in ipairs(listeners) do pcall(fn, b) end
end

function G.SetActiveBuild(id, quiet)
  local b = G.GetBuild(id)
  if not b then return false end
  local d = db()
  d.buildFor = d.buildFor or {}
  local cur = d.buildFor[charKey()]
  if type(cur) ~= "table" then cur = { cur } end
  cur[specGroup()] = id
  d.buildFor[charKey()] = cur
  G.ApplyBuild(b)
  if not quiet and G.say then G.say("aktywny build: " .. (G.BT(b.name) or id) .. ".") end
  return true
end

-- kopia do edycji (takze szkicu Polestara): nowy id „moje/…”, zrodlo „moje”
local function deepcopy(v)
  if type(v) ~= "table" then return v end
  local o = {}
  for k, x in pairs(v) do o[k] = deepcopy(x) end
  return o
end
G.deepcopy = deepcopy
function G.DuplicateBuild(id)
  local b = G.GetBuild(id)
  if not b then return nil end
  local c = deepcopy(b)
  local base = (tostring(b.id):gsub("^[^/:]+[/:]", ""):gsub("[^%w%-]", "-"))
  local n, newId = 1, nil
  repeat newId = "moje/" .. base .. (n > 1 and ("-" .. n) or "") n = n + 1 until not G.GetBuild(newId)
  c.id, c.src, c.version, c.updated = newId, "moje", 1, date("%Y-%m-%d")
  c.author = (G.BT(b.author) ~= "" and b.author) or "anonim"
  local nm = G.BT(b.name) or newId
  c.name = { pl = nm .. " (moja kopia)", en = nm .. " (my copy)" }
  -- szkic Polestara: talenty jako plan do edycji (picks zostaja jako zrodlo)
  if c.talents and (not c.talents.plan or #c.talents.plan == 0) and c.talents.picks then
    c.talents.plan = G.picksToPlan(c.class, c.talents.picks)
  end
  local d = db()
  d.builds = d.builds or {}
  d.builds[newId] = c
  return newId
end
function G.SaveOwnBuild(b)
  if type(b) ~= "table" or not b.id then return false end
  local ok, err = true, nil
  if G.ValidateBuild then ok, err = G.ValidateBuild(b) end
  if not ok then return false, err end
  local d = db()
  d.builds = d.builds or {}
  b.updated = date("%Y-%m-%d")
  d.builds[b.id] = b
  if G.ActiveBuildId() == b.id then G.ApplyBuild(b) end
  return true
end
function G.DeleteOwnBuild(id)
  local d = db()
  if not (d.builds and d.builds[id]) then return false end
  d.builds[id] = nil
  local cur = d.buildFor and d.buildFor[charKey()]
  if type(cur) == "table" then for k, v in pairs(cur) do if v == id then cur[k] = nil end end
  elseif cur == id then d.buildFor[charKey()] = nil end
  G.ApplyBuild(G.Build() or {})
  return true
end

-- ---------- start ----------
-- przy ladowaniu plikow: build domyslny dla klasy (mag: wbudowany Frost), zeby Core.lua mial dane od razu;
-- po wczytaniu zapisanych ustawien (ADDON_LOADED): build wybrany dla tej postaci
function G.BuildBoot()
  local cls = playerClass()
  local id = (cls == nil or cls == "MAGE") and "grimuar/mage-frost-leveling" or G.DefaultBuildId(cls)
  local b = id and (BUILTIN[id] or G.GetBuild(id))
  if b then G.ApplyBuild(b) end
end
-- ---------- Pawn: skala z buildu albo z wag Polestara ----------
-- b.stats.tag = gotowy napis Pawn; b.stats.from = "polestar" albo szkic Polestara: wagi z Polestar.Gear.WEIGHT_BANDS
-- dla Twojego poziomu, napis z Polestar.Gear.Pawn.Build. Zmiana w Pawn tylko po kliknieciu (Buildy).
function G.BuildPawnTag(b)
  if type(b) ~= "table" then return nil end
  local st = b.stats or {}
  if type(st.tag) == "string" and st.tag:find("^%s*%( Pawn:") then return st.tag end
  local key = b.talents and type(b.talents.from) == "string" and b.talents.from:match("^polestar:(.+)$")
  key = key or (type(st.from) == "string" and st.from:match("^polestar:(.+)$"))
  local P = _G.Polestar
  local Gear = P and P.Gear
  if not (key and Gear and Gear.WEIGHT_BANDS and Gear.Pawn and Gear.Pawn.Build) then return nil end
  local bands = Gear.WEIGHT_BANDS[b.class or ""] and Gear.WEIGHT_BANDS[b.class][key]
  if type(bands) ~= "table" then return nil end
  local lvl, pick = UnitLevel("player") or 1, nil
  for _, band in ipairs(bands) do if not pick and lvl <= (band.upTo or 60) then pick = band end end
  pick = pick or bands[#bands]
  local ok, tag = pcall(Gear.Pawn.Build, "Grimuar " .. (G.BT(b.name) or key), b.class, pick.weights or {})
  return ok and tag or nil
end
function G.ApplyBuildPawn(b)
  local tag = G.BuildPawnTag(b)
  if not tag then return false, "ten build nie ma skali Pawn (ani wag Polestara)" end
  if type(PawnImportScale) ~= "function" then return false, "Pawn nie jest włączony" end
  local ok, res = pcall(PawnImportScale, tag, true)
  if not ok then return false, tostring(res) end
  local name = tag:match('^%s*%( Pawn: v1: "([^"]+)"')
  if name and type(PawnSetScaleVisible) == "function" then pcall(PawnSetScaleVisible, name, true) end
  return true, name
end

local ev = CreateFrame("Frame")
ev:RegisterEvent("ADDON_LOADED")
ev:RegisterEvent("PLAYER_LOGIN")
pcall(ev.RegisterEvent, ev, "ACTIVE_TALENT_GROUP_CHANGED")
pcall(ev.RegisterEvent, ev, "PLAYER_SPECIALIZATION_CHANGED")
ev:SetScript("OnEvent", function(_, event, name)
  if event == "ADDON_LOADED" and name ~= ADDON_NAME then return end
  local id = G.ActiveBuildId()
  if id and id ~= G.BD_META.id then
    local b = G.GetBuild(id)
    if b then pcall(G.ApplyBuild, b) end
  end
end)
