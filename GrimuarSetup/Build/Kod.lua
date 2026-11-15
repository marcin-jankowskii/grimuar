-- Grimuar: kod buildu do udostepniania (R27 3e, wzor: import Polestara !PS1! i ElvUI !E2!).
--   !GRB1!<Adler-32 JSON, 8 hex>!<base64 zlib JSON>     (C_EncodingUtil z klienta)
--   !GRB0!<JSON>                                         (zapas, gdy klient nie ma C_EncodingUtil)
-- JSON piszemy i czytamy sami (bez wykonywania czegokolwiek): klucze liczbowe tabel rzadkich jako "#61".
-- Po odczycie build przechodzi G.CleanBuild (Walidacja.lua). Limity: kod 64 000 znakow, JSON 128 KB, glebokosc 8.
local ADDON_NAME, G = ...

local MAXLEN, MAXJSON, MAXDEPTH = 64000, 131072, 8
local byte, char, format, sub = string.byte, string.char, string.format, string.sub

local function adler32(s)
  local a, b = 1, 0
  for i = 1, #s, 4096 do
    local bytes = { byte(s, i, i + 4095) }
    for j = 1, #bytes do a = a + bytes[j] b = b + a end
    a, b = a % 65521, b % 65521
  end
  return format("%04x%04x", b, a)
end

-- ---------- JSON ----------
local function isArray(t)
  local n = 0
  for k in pairs(t) do
    if type(k) ~= "number" or k < 1 or k % 1 ~= 0 then return false end
    n = n + 1
  end
  for i = 1, n do if t[i] == nil then return false end end
  return n > 0
end
local ESC = { ['"'] = '\\"', ['\\'] = '\\\\', ['\n'] = '\\n', ['\r'] = '\\r', ['\t'] = '\\t' }
local function str(s) return '"' .. s:gsub('[%c"\\]', function(c) return ESC[c] or format("\\u%04x", byte(c)) end) .. '"' end
local function enc(v, depth)
  if depth > MAXDEPTH then error("za głęboko") end
  local t = type(v)
  if t == "string" then return str(v)
  elseif t == "number" then return (v % 1 == 0) and format("%d", v) or format("%.6g", v)
  elseif t == "boolean" then return v and "true" or "false"
  elseif t == "table" then
    local parts = {}
    if isArray(v) then
      for i = 1, #v do parts[i] = enc(v[i], depth + 1) end
      return "[" .. table.concat(parts, ",") .. "]"
    end
    local keys = {}
    for k in pairs(v) do keys[#keys + 1] = k end
    table.sort(keys, function(a, b) return tostring(a) < tostring(b) end)
    for _, k in ipairs(keys) do
      local key = type(k) == "number" and ("#" .. format("%d", k)) or tostring(k)
      parts[#parts + 1] = str(key) .. ":" .. enc(v[k], depth + 1)
    end
    return "{" .. table.concat(parts, ",") .. "}"
  end
  error("niedozwolony typ: " .. t)
end

local function parse(s)
  local pos = 1
  local function ws() pos = s:find("[^ \t\r\n]", pos) or (#s + 1) end
  local value
  local function strv()
    local out, i = {}, pos + 1
    while true do
      local c = sub(s, i, i)
      if c == "" then error("koniec") end
      if c == '"' then pos = i + 1 return table.concat(out) end
      if c == "\\" then
        local e = sub(s, i + 1, i + 1)
        if e == "u" then
          local h = tonumber(sub(s, i + 2, i + 5), 16) or 63
          out[#out + 1] = h < 128 and char(h) or "?"
          i = i + 6
        else
          out[#out + 1] = ({ n = "\n", r = "\r", t = "\t", ['"'] = '"', ["\\"] = "\\", ["/"] = "/" })[e] or e
          i = i + 2
        end
      else
        local j = s:find('["\\]', i) or (#s + 1)
        out[#out + 1] = sub(s, i, j - 1)
        i = j
      end
    end
  end
  function value(depth)
    if depth > MAXDEPTH then error("za głęboko") end
    ws()
    local c = sub(s, pos, pos)
    if c == "{" then
      pos = pos + 1
      local t = {}
      ws()
      if sub(s, pos, pos) == "}" then pos = pos + 1 return t end
      while true do
        ws()
        if sub(s, pos, pos) ~= '"' then error("klucz") end
        local k = strv()
        ws()
        if sub(s, pos, pos) ~= ":" then error(":") end
        pos = pos + 1
        local v = value(depth + 1)
        local nk = k:match("^#(%-?%d+)$")
        t[nk and tonumber(nk) or k] = v
        ws()
        local d = sub(s, pos, pos)
        pos = pos + 1
        if d == "}" then return t elseif d ~= "," then error(",") end
      end
    elseif c == "[" then
      pos = pos + 1
      local t = {}
      ws()
      if sub(s, pos, pos) == "]" then pos = pos + 1 return t end
      while true do
        t[#t + 1] = value(depth + 1)
        ws()
        local d = sub(s, pos, pos)
        pos = pos + 1
        if d == "]" then return t elseif d ~= "," then error(",") end
      end
    elseif c == '"' then return strv()
    elseif s:find("^true", pos) then pos = pos + 4 return true
    elseif s:find("^false", pos) then pos = pos + 5 return false
    elseif s:find("^null", pos) then pos = pos + 4 return nil
    else
      local num = s:match("^%-?%d+%.?%d*[eE]?[%+%-]?%d*", pos)
      if not num or num == "" then error("wartość") end
      pos = pos + #num
      return tonumber(num)
    end
  end
  local ok, v = pcall(value, 1)
  if not ok then return nil end
  return v
end
G.jsonEncode = function(v) return enc(v, 1) end
G.jsonDecode = parse

-- ---------- kod buildu ----------
local function encUtil()
  local e = C_EncodingUtil
  if type(e) == "table" and e.CompressString and e.EncodeBase64 and e.DecodeBase64 and e.DecompressString then return e end
end
local function method() return Enum and Enum.CompressionMethod and Enum.CompressionMethod.Zlib end

function G.BuildExport(b)
  local clean = G.CleanBuild and G.CleanBuild(b) or b
  if not clean then return nil, "build nie przeszedł walidacji" end
  clean.src = nil
  local ok, json = pcall(enc, clean, 1)
  if not ok then return nil, json end
  local e = encUtil()
  if e then
    local okc, packed = pcall(e.CompressString, json, method())
    local okb, b64 = pcall(e.EncodeBase64, okc and packed or "")
    if okc and okb and type(b64) == "string" then return "!GRB1!" .. adler32(json) .. "!" .. b64 end
  end
  return "!GRB0!" .. json
end

-- -> build (oczyszczony) albo nil, powod; problems: ostrzezenia walidacji
function G.BuildImport(text)
  if type(text) ~= "string" or text == "" then return nil, "wklej kod buildu" end
  if #text > MAXLEN then return nil, "kod za długi" end
  local json
  if text:find("^%s*!GRB0!") then
    json = text:gsub("^%s*!GRB0!", "")
  else
    local s = text:gsub("%s+", "")
    local sum, body = s:match("^!GRB1!(%x%x%x%x%x%x%x%x)!([A-Za-z0-9+/]+=?=?)$")
    if not sum then return nil, "to nie jest kod buildu Grimuara (!GRB1!…)" end
    local e = encUtil()
    if not e then return nil, "ten klient nie odczyta kodu: poproś o wersję !GRB0!" end
    local ok, packed = pcall(e.DecodeBase64, body)
    if not ok or type(packed) ~= "string" then return nil, "kod uszkodzony" end
    local ok2, raw = pcall(e.DecompressString, packed, method())
    if not ok2 or type(raw) ~= "string" then return nil, "kod uszkodzony" end
    if adler32(raw) ~= sum:lower() then return nil, "kod uszkodzony (suma kontrolna)" end
    json = raw
  end
  if #json > MAXJSON then return nil, "build za duży" end
  local tree = parse(json)
  if type(tree) ~= "table" then return nil, "kod uszkodzony (JSON)" end
  local b, problems = G.CleanBuild(tree)
  if not b then return nil, table.concat(problems or {}, "; ") end
  return b, nil, problems
end

-- zapis importu: nowy, aktualizacja, ta sama albo starsza wersja
function G.BuildImportState(b)
  local cur = G.GetBuild(b.id)
  if not cur then return "nowy" end
  local a, c = tonumber(b.version) or 0, tonumber(cur.version) or 0
  if a > c then return "aktualizacja" elseif a == c then return "ta sama" end
  return "starsza"
end
function G.BuildImportSave(b)
  GrimuarSetupDB.builds = GrimuarSetupDB.builds or {}
  b.src = "import"
  if G.GetBuild(b.id) and G.GetBuild(b.id).src == "grimuar" then
    b.id = "import/" .. b.id:gsub("^[^/]+/", "")
  end
  GrimuarSetupDB.builds[b.id] = b
  return true, b.id
end
