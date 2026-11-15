-- Grimuar: modul Grafika (13.11, punkt 5 „pominietych tematow”, research R17-grafika-wydajnosc-2611.md).
-- 1) czytelnosc walki przez CVary (raz, potem pilnuje kontrola ustawien): bez trzesienia kamery i UI, wyrazniejsze procki,
--    kolejka czarow 400 ms, osobne ustawienia raid/BG z mniejsza gestoscia cudzych czarow;
-- 2) plakietki dalej (nameplateMaxDistance 60, gra moze przyjac mniej: zapisujemy, co przyjela);
-- 3) „Spokojny ekran” (przelacznik): bez poswiaty, szarosci po smierci i efektu Netheru;
-- 4) strona okna: Ustawienia > Grafika (stan teraz + kroki reczne: NVIDIA, G-Sync, rozdzielczosc okna).
-- Limit FPS (useMaxFPS + maxFPS 200) jest w Core.lua (CVARS). LowLatencyMode, rozdzielczosc i sterownik tylko recznie (R17 §6).
local ADDON_NAME, G = ...
local say = G.say

local GFX_CVARS = {
  { "ShakeStrengthCamera", "0", "kamera się nie trzęsie" },
  { "ShakeStrengthUI", "0", "interfejs się nie trzęsie" },
  { "displaySpellActivationOverlays", "1", "alerty procków włączone" },
  { "spellActivationOverlayOpacity", "0.8", "procki wyraźniejsze" },
  { "SpellQueueWindow", "400", "kolejka czarów 400 ms" },
  { "RAIDsettingsEnabled", "1", "osobne ustawienia grafiki w raidzie i na BG" },
  { "raidGraphicsSpellDensity", "1", "w raidzie i na BG mniej cudzych efektów" },
}
local CALM = { "ffxGlow", "ffxDeath", "ffxNether" }

local function getCVar(n)
  local v
  pcall(function() v = C_CVar and C_CVar.GetCVar(n) or GetCVar(n) end)
  return v
end

local function setCVar(n, v)
  return pcall(function() if C_CVar and C_CVar.SetCVar then C_CVar.SetCVar(n, v) else SetCVar(n, v) end end)
end

local function apply(force)
  if not force and (GrimuarSetupDB.gfxV or 0) >= 1 then return end
  if InCombatLockdown() then return end
  local done = {}
  for _, c in ipairs(GFX_CVARS) do
    local cur = getCVar(c[1])
    if cur ~= nil and tonumber(cur) ~= tonumber(c[2]) and setCVar(c[1], c[2]) then done[#done + 1] = c[3] end
  end
  -- plakietki dalej: zapis i odczyt, bo Forever moze miec nizszy limit
  if getCVar("nameplateMaxDistance") ~= nil then
    setCVar("nameplateMaxDistance", "60")
    GrimuarSetupDB.plateDist = tonumber(getCVar("nameplateMaxDistance"))
    if GrimuarSetupDB.plateDist then done[#done + 1] = "plakietki do " .. GrimuarSetupDB.plateDist .. " m" end
  end
  GrimuarSetupDB.gfxV = 1
  if #done > 0 then say("grafika: " .. table.concat(done, ", ") .. ".") end
end

local function calmOn() return GrimuarSetupDB.calmScreen end
local function calmToggle()
  if InCombatLockdown() then say("przełączę po walce.") return end
  GrimuarSetupDB.calmScreen = not GrimuarSetupDB.calmScreen
  for _, n in ipairs(CALM) do setCVar(n, GrimuarSetupDB.calmScreen and "0" or "1") end
end

-- ---------- strona okna ----------
local LATENCY = { ["0"] = "auto", ["1"] = "wyłączone", ["2"] = "wbudowane", ["3"] = "NVIDIA Reflex", ["4"] = "Reflex + Boost", ["5"] = "Intel XeLL" }
local DENSITY = { ["0"] = "minimum", ["1"] = "mniej", ["2"] = "pełna" }

local function pageGrafika(P)
  P.M("Wnioski z researchu R17 (13.11.2026) dla Twojego PC: Ryzen 7 9800X3D, RTX 5070 Ti, monitor 2560×1440, 240 Hz. Zmiany z addonu działają od razu, bez restartu.")
  P.H("Teraz w grze")
  local fps = (getCVar("useMaxFPS") == "1") and ((getCVar("maxFPS") or "?") .. " FPS") or "|cffe07a6awyłączony|r (Ustaw wszystko włączy 200)"
  local bk = (getCVar("useMaxFPSBk") == "0") and "bez limitu" or ((getCVar("maxFPSBk") or "?") .. " FPS")
  local res = getCVar("gxWindowedResolution") or "?"
  P.KV({ { "Limit FPS", fps }, { "W tle", bk },
    { "Opóźnienie", LATENCY[getCVar("LowLatencyMode") or ""] or "?" },
    { "Gęstość czarów", "świat: " .. (DENSITY[getCVar("graphicsSpellDensity") or ""] or "?") .. ", raid i BG: " .. (DENSITY[getCVar("raidGraphicsSpellDensity") or ""] or "?") ..
      ((getCVar("RAIDsettingsEnabled") == "1") and "" or " (ustawienia raid wyłączone)") },
    { "Trzęsienie kamery", (getCVar("ShakeStrengthCamera") == "0") and "wyłączone" or "włączone" },
    { "Procki", "krycie " .. (getCVar("spellActivationOverlayOpacity") or "?") },
    { "Plakietki", (getCVar("nameplateMaxDistance") or "?") .. " m" .. (GrimuarSetupDB.plateDist and GrimuarSetupDB.plateDist < 60 and " (limit gry)" or "") },
    { "Kolejka czarów", (getCVar("SpellQueueWindow") or "?") .. " ms" },
    { "Okno", res .. ((res == "3840x2160") and " |cffe07a6a← stara rozdzielczość z projektora|r" or "") } })
  P.BTNROW({ { "Ustaw czytelność jeszcze raz", function() apply(true) if G.renderPanel then pcall(G.renderPanel) end end },
    { "Spokojny ekran: " .. (calmOn() and "wł." or "wył."), function() calmToggle() if G.renderPanel then pcall(G.renderPanel) end end } })
  P.M("Spokojny ekran wyłącza poświatę, szary ekran po śmierci i efekt Netheru. Cząsteczek nigdy nie dawaj na 0, bo znikną sygnały walki.")
  P.H("Ręcznie (raz)")
  P.B({ "Panel NVIDIA: G-SYNC włącz „dla trybu okienkowego i pełnoekranowego” (Forever ma tylko okno). V-Sync: On w sterowniku, Off w grze.",
    "Nie wiesz, czy masz G-Sync? W panelu NVIDIA jest „Set up G-SYNC”: to masz. Bez G-Sync: V-Sync wyłączony, Reflex włączony, limit 200.",
    "Limit 237 FPS (pod 240 Hz) ustawisz w panelu NVIDIA: Max Frame Rate. Gra przyjmuje najwyżej 200.",
    "Low Latency Mode w grze: NVIDIA Reflex. Sprawdź w menu, czy nie jest „Reflex + Boost” (źródła podają różne numery).",
    "Rozdzielczość okna: Esc > Options > Graphics > Display Mode: Windowed, wybierz 2560×1440, wróć na Windowed (Fullscreen).",
    "PvP: gdy Nova albo Blink „czekają” po Frostbolcie, obniż kolejkę czarów do 250: /run C_CVar.SetCVar(\"SpellQueueWindow\",250)." })
end

local ev = CreateFrame("Frame")
ev:RegisterEvent("PLAYER_LOGIN")
ev:SetScript("OnEvent", function()
  C_Timer.After(15, function() pcall(apply) end)
end)

G.GFX_CVARS = GFX_CVARS
G.gfxApply = apply
G.calmToggle = calmToggle
G.pageGrafika = pageGrafika
