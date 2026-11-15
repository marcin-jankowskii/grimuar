-- Grimuar: warstwa tlumaczen (R27 E6, 14.11). Kod pisze po polsku; gdy jezyk huba to angielski (kreator albo
-- /gr jezyk en), napisy przechodza przez G.tr: dokladne tlumaczenie ze slownika (Locales\enUS.lua), potem wzorce
-- dla napisow z liczbami. Przechodza tedy: czat Grimuara (say), wstegi i komunikaty, wszystkie napisy huba
-- (GrimuarUI Theme: U.Text). Brakujace tlumaczenia zbiera GrimuarSetupDB.trMissing (do 400), /gr jezyk brak je pokazuje.
-- Teksty buildow maja wlasne pola {pl, en} (Build\Api.lua G.BT). Klient WoW nie ma polskiego, wiec jezyk wybiera gracz.
local ADDON_NAME, G = ...

G.TR = G.TR or {}     -- [polski] = angielski
G.TRP = G.TRP or {}   -- { wzorzec, zamiana } dla napisow z liczbami

local function secret(v) return issecretvalue and issecretvalue(v) end

function G.tr(s)
  -- najpierw sekret (Midnight): porownanie ukrytej wartosci w walce to blad
  if secret(s) or type(s) ~= "string" or s == "" then return s end
  if not (GrimuarSetupDB and GrimuarSetupDB.lang == "en") then return s end
  local t = G.TR[s]
  if t then return t end
  for _, p in ipairs(G.TRP) do
    local r, n = s:gsub(p[1], p[2])
    if n > 0 then return r end
  end
  -- napis z polskimi literami bez tlumaczenia: do listy brakow
  if s:find("[\196\197\195]") and #s < 300 then
    GrimuarSetupDB.trMissing = GrimuarSetupDB.trMissing or {}
    local m = GrimuarSetupDB.trMissing
    if not m[s] then
      local n = 0
      for _ in pairs(m) do n = n + 1 if n >= 400 then break end end
      if n < 400 then m[s] = true end
    end
  end
  return s
end

function G.setLang(l)
  GrimuarSetupDB.lang = (l == "en") and "en" or "pl"
  return GrimuarSetupDB.lang
end
