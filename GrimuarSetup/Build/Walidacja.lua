-- Grimuar: walidacja buildu (R27 3d/3e). Build to wylacznie dane: biala lista kluczy i typow, limity, makra bez
-- /run, /script, /console i /dump, teksty z podwojonym „|” (zadnych linkow, tekstur ani kolorow udajacych gre).
-- Nieznany klucz: odrzucony z ostrzezeniem. Nic z buildu nie jest uruchamiane (zadnego loadstring).
local ADDON_NAME, G = ...

local CLASSES = { WARRIOR = true, PALADIN = true, HUNTER = true, ROGUE = true, PRIEST = true, SHAMAN = true, MAGE = true, WARLOCK = true, DRUID = true }
local TOP = {
  schema = "number", id = "string", version = "number", updated = "string", name = "text", desc = "text", author = "text",
  license = "string", sources = "table", class = "string", spec = "number", role = "string", levels = "table", family = "string",
  macros = "table", macroNeeds = "table", keys = "table", bars = "table", trainer = "table", talents = "table", combo = "table",
  pvp = "table", wheel = "table", creatures = "table", group = "table", buffs = "table", consumables = "table", stats = "table",
  route = "table", professions = "table", src = "string", addons = "table",
}
local LIMIT = { text = 400, macro = 255, depth = 7, items = 400, macros = 18, picks = 80 }
local BAD_MACRO = { "/run", "/script", "/console", "/dump", "/scr", "runscript" }

local function textOk(s, max)
  if type(s) ~= "string" then return false, "tekst nie jest napisem" end
  if #s > (max or LIMIT.text) then return false, "tekst za długi (" .. #s .. ")" end
  return true
end
-- „|” podwojone: w grze napis nie wstawi linku, tekstury ani koloru
local function clean(s) return (s:gsub("|", "||")) end

local function walk(v, depth, path, problems, count)
  if depth > LIMIT.depth then problems[#problems + 1] = path .. ": za głęboko" return nil end
  local t = type(v)
  if t == "string" then
    local ok, why = textOk(v, path:find("macros") and 600 or LIMIT.text)
    if not ok then problems[#problems + 1] = path .. ": " .. why return nil end
    return path:find("macros") and v or clean(v)
  elseif t == "number" or t == "boolean" then return v
  elseif t == "table" then
    local out, n = {}, 0
    for k, x in pairs(v) do
      n = n + 1
      count[1] = count[1] + 1
      if count[1] > 6000 then problems[#problems + 1] = "build za duży" return nil end
      if type(k) ~= "string" and type(k) ~= "number" then problems[#problems + 1] = path .. ": zły klucz" return nil end
      if n > LIMIT.items then problems[#problems + 1] = path .. ": za dużo pozycji" break end
      out[k] = walk(x, depth + 1, path .. "." .. tostring(k), problems, count)
    end
    return out
  end
  problems[#problems + 1] = path .. ": niedozwolony typ " .. t
  return nil
end

-- -> czysty build albo nil; problems (lista tekstow)
function G.CleanBuild(b)
  local problems = {}
  if type(b) ~= "table" then return nil, { "to nie jest build" } end
  local out, count = {}, { 0 }
  for k, v in pairs(b) do
    local want = TOP[k]
    if not want then problems[#problems + 1] = "pominięty nieznany klucz: " .. tostring(k)
    elseif want == "text" then
      if type(v) == "string" or type(v) == "table" then out[k] = walk(v, 1, k, problems, count) end
    elseif type(v) ~= want then problems[#problems + 1] = k .. ": zły typ"
    else out[k] = walk(v, 1, k, problems, count) end
  end
  if type(out.id) ~= "string" or out.id == "" or #out.id > 80 then return nil, { "brak id buildu" } end
  if not CLASSES[out.class or ""] then return nil, { "nieznana klasa: " .. tostring(out.class) } end
  out.schema = out.schema or 1
  if out.schema > 1 then return nil, { "build z nowszej wersji Grimuara (schemat " .. out.schema .. "): zaktualizuj Grimuar" } end
  -- makra: dlugosc i zakazane komendy
  if type(out.macros) == "table" then
    if #out.macros > LIMIT.macros then problems[#problems + 1] = "za dużo makr" end
    local keep = {}
    for _, m in ipairs(out.macros) do
      local body = type(m) == "table" and (type(m[2]) == "table" and table.concat(m[2], "\n") or m[2]) or nil
      local name = type(m) == "table" and m[1] or nil
      local bad = type(body) ~= "string" or type(name) ~= "string" or #body > LIMIT.macro or #name > 16
      if not bad then
        local low = body:lower()
        for _, w in ipairs(BAD_MACRO) do if low:find(w, 1, true) then bad = true end end
      end
      if bad then problems[#problems + 1] = "makro odrzucone: " .. tostring(name)
      elseif #keep < LIMIT.macros then keep[#keep + 1] = { name, body } end
    end
    out.macros = keep
  end
  if type(out.talents) == "table" and type(out.talents.picks) == "table" and #out.talents.picks > LIMIT.picks then
    problems[#problems + 1] = "za dużo punktów talentów"
    while #out.talents.picks > LIMIT.picks do table.remove(out.talents.picks) end
  end
  return out, problems
end

function G.ValidateBuild(b)
  local out, problems = G.CleanBuild(b)
  if not out then return false, table.concat(problems or {}, "; ") end
  return true, problems
end
