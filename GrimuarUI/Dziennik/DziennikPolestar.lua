-- Grimuar UI: Dziennik razem z Polestarem (14.11, zrzut Dziennika: „tu mozna dodac proponowane, niepotrzebne itp.,
-- w pelni zintegrowac z Polestarem”). Czyta otwarte przewodniki Polestara (Engine.GetTabs, Guides.Get(...).steps):
-- * now: zadania z biezacego kroku kazdej zakladki Polestara (sekcja „Teraz wg Polestara”),
-- * take: zadania do wziecia z dalszych krokow (kto daje, gdzie, krok), ktorych nie masz i nie zrobiles,
-- * loc: miejsca z przewodnika (wez / cel / oddaj) — „Prowadz” woli je od Questie, bo sa z trasy Forever.
-- Tylko odczyt z Polestara: niczego w nim nie przestawiamy.
local ADDON, U = ...

local cache = { at = -10 }

local function plain(s)
  if type(s) ~= "string" then return nil end
  s = s:gsub("{(%a+):(%d+)}", function(kind, id)
    id = tonumber(id)
    local n
    if kind == "zone" then
      local i = U.call(C_Map.GetMapInfo, id)
      n = i and i.name
    elseif kind == "area" then
      n = U.call(C_Map.GetAreaInfo, id)
    end
    if not n and Polestar and Polestar.Names and Polestar.Names.Get then n = U.call(Polestar.Names.Get, kind, id) end
    return n or ""
  end)
  return (s:gsub("||", "|"))
end
U.polestarText = plain

local function inLog(q)
  local i = U.call(C_QuestLog.GetLogIndexForQuestID, q)
  return i ~= nil and i ~= 0
end
local function done(q) return U.call(C_QuestLog.IsQuestFlaggedCompleted, q) and true or false end

function U.polestarQuests()
  if GetTime() - cache.at < 2 and cache.d then return cache.d end
  local d = { ok = false, now = {}, take = {}, loc = {}, inGuide = {} }
  local E, PG = Polestar and Polestar.Engine, Polestar and Polestar.Guides
  if E and E.GetTabs and PG and PG.Get then
    local ok, tabs, active = pcall(E.GetTabs)
    if ok and type(tabs) == "table" then
      d.ok = true
      local l = UnitLevel("player") or 1
      local order, seen = {}, {}
      if active and tabs[active] then order[1] = tabs[active] end
      for i, t in ipairs(tabs) do if i ~= active then order[#order + 1] = t end end
      for _, t in ipairs(order) do
        local okg, g = pcall(PG.Get, t.guideId)
        local steps = okg and type(g) == "table" and g.steps
        if type(steps) == "table" then
          local cur = t.stepIndex or 1
          local gtitle = plain(g.title) or "Polestar"
          for si = cur, #steps do
            local st = steps[si]
            for _, goal in ipairs(type(st) == "table" and type(st.goals) == "table" and st.goals or {}) do
              local q = type(goal) == "table" and goal.quest
              if q then
                d.inGuide[q] = true
                if si == cur and not d.now[q] then d.now[q] = { guide = gtitle } end
                -- 15.11 (R30): ramka Era (goal.f) przeliczona na biezaca mape Forever (U.psLive, RzemiosloPolestar.lua)
                local lm, lx, ly = goal.map, goal.x, goal.y
                if goal.f and U.psLive then lm, lx, ly = U.psLive(goal) end
                if lm and lx and ly then
                  local key = goal.t == "turnin" and "turnin" or (goal.t == "accept" and "accept" or "obj")
                  d.loc[q] = d.loc[q] or {}
                  if not d.loc[q][key] then
                    d.loc[q][key] = { map = lm, x = lx / 100, y = ly / 100, name = plain(goal.npcName) }
                  end
                end
                if goal.t == "accept" and not seen[q] and #d.take < 12 and (goal.minLevel or 0) <= l + 1
                  and not inLog(q) and not done(q) then
                  seen[q] = true
                  local stepNo = (E.StepNumberOf and U.call(E.StepNumberOf, g, si)) or si
                  d.take[#d.take + 1] = { qid = q, title = plain(goal.title) or ("#" .. q), npc = plain(goal.npcName),
                    map = lm, x = lx and lx / 100, y = ly and ly / 100, guide = gtitle, step = stepNo,
                    note = plain(st.note) or plain(goal.note), minLevel = goal.minLevel or goal.qlvl, now = si == cur,
                    reward = plain(goal.reward) }
                end
              end
            end
          end
        end
      end
    end
  end
  cache.d, cache.at = d, GetTime()
  return d
end
function U.polestarReset() cache.at = -10 end

-- miejsce z Polestara dla zadania z dziennika: gotowe → oddaj, w toku → cel; nil, gdy przewodnik go nie zna
function U.polestarSpot(qid, complete)
  local loc = U.polestarQuests().loc[qid]
  if not loc then return nil end
  if complete then return loc.turnin end
  return loc.obj
end
