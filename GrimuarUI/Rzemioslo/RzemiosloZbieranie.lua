-- Grimuar UI: Rzemioslo dla zbieractwa (14.11, zrzut gracza „tutaj dalej nie ma nic” przy Zielarstwie). Zbieractwo nie ma
-- przepisow, wiec zakladka pokazuje liste jak przepisy: co zbierac teraz (kolor = szansa na punkt), co dalej, gdzie
-- i ile masz w torbach. Progi vanilla (Forever moze sie roznic): pomaranczowy do wymaganego +25, zolty do +50,
-- zielony do +100, potem szary; ponizej wymaganego czerwony (jeszcze nie zbierzesz).
local ADDON, U = ...

-- { nazwa, wymagana umiejetnosc, ID przedmiotu, gdzie (Przymierze) }
local HERBS = {
  { "Peacebloom", 1, 2447, "Dun Morogh, Elwynn, Loch Modan, Westfall, Darkshore" },
  { "Silverleaf", 1, 765, "Dun Morogh, Elwynn, Loch Modan, Westfall, Darkshore" },
  { "Earthroot", 15, 2449, "Dun Morogh, Loch Modan, Westfall, Darkshore (zbocza)" },
  { "Mageroyal", 50, 785, "Loch Modan, Westfall, Darkshore, Redridge" },
  { "Briarthorn", 70, 2450, "Loch Modan, Westfall, Darkshore, Redridge, Duskwood" },
  { "Stranglekelp", 85, 3820, "wybrzeża i woda: Westfall, Darkshore, Wetlands" },
  { "Bruiseweed", 100, 2453, "Redridge, Wetlands, Duskwood, Ashenvale" },
  { "Wild Steelbloom", 115, 3355, "Wetlands, Arathi, Stonetalon" },
  { "Grave Moss", 120, 3369, "cmentarze: Duskwood, Wetlands" },
  { "Kingsblood", 125, 3356, "Wetlands, Hillsbrad, Duskwood, Ashenvale" },
  { "Liferoot", 150, 3357, "rzeki i jeziora: Wetlands, Arathi, Stranglethorn" },
  { "Fadeleaf", 160, 3818, "Arathi, Stranglethorn, Swamp of Sorrows" },
  { "Goldthorn", 170, 3821, "Arathi, Stranglethorn, Badlands" },
  { "Khadgar's Whisker", 185, 3358, "Arathi, Stranglethorn, Hinterlands" },
  { "Wintersbite", 195, 3819, "Alterac Mountains" },
  { "Firebloom", 205, 4625, "Searing Gorge, Badlands, Tanaris" },
  { "Purple Lotus", 210, 8831, "Stranglethorn, Tanaris, Feralas, Hinterlands" },
  { "Arthas' Tears", 220, 8836, "Plaguelands, Felwood" },
  { "Sungrass", 230, 8838, "Hinterlands, Feralas, Un'Goro, Plaguelands" },
  { "Blindweed", 235, 8839, "Swamp of Sorrows, Un'Goro" },
  { "Ghost Mushroom", 245, 8845, "jaskinie: Hinterlands, Maraudon" },
  { "Gromsblood", 250, 8846, "Felwood, Blasted Lands, Desolace" },
  { "Golden Sansam", 260, 13464, "Feralas, Un'Goro, Burning Steppes" },
  { "Dreamfoil", 270, 13463, "Un'Goro, Felwood, Azshara" },
  { "Mountain Silversage", 280, 13465, "Winterspring, Un'Goro, Burning Steppes" },
  { "Plaguebloom", 285, 13466, "Plaguelands, Felwood" },
  { "Icecap", 290, 13467, "Winterspring" },
  { "Black Lotus", 300, 13468, "rzadko: Burning Steppes, Winterspring, Silithus" },
}
local ORES = {
  { "Copper Ore (żyła miedzi)", 1, 2770, "Dun Morogh, Loch Modan, Elwynn, Westfall, Darkshore" },
  { "Tin Ore (żyła cyny)", 65, 2771, "Loch Modan, Westfall, Redridge, Wetlands, Darkshore" },
  { "Silver Ore (żyła srebra, rzadka)", 75, 2775, "tam gdzie cyna" },
  { "Iron Ore (złoże żelaza)", 125, 2772, "Arathi, Hillsbrad, Alterac, Stranglethorn, Desolace" },
  { "Gold Ore (żyła złota, rzadka)", 155, 2776, "tam gdzie żelazo, Badlands" },
  { "Mithril Ore (złoże mithrilu)", 175, 3858, "Badlands, Hinterlands, Stranglethorn, Searing Gorge" },
  { "Truesilver Ore (rzadkie)", 230, 7911, "tam gdzie mithril" },
  { "Dark Iron Ore", 230, 11370, "Searing Gorge, Burning Steppes (Blackrock)" },
  { "Thorium Ore (mała żyła)", 245, 10620, "Un'Goro, Felwood, Burning Steppes, Winterspring" },
  { "Thorium Ore (bogata żyła)", 275, 10620, "Silithus, Plaguelands, Winterspring" },
}
U.GATHER_DATA = { Herbalism = HERBS, Mining = ORES }

-- mapa huba (tryb Zbieranie): wymagana umiejetnosc po nazwie wezla z GatherMate2 i kolor szansy na punkt
local NODE_REQ = { ["Copper Vein"] = 1, ["Tin Vein"] = 65, ["Silver Vein"] = 75, ["Iron Deposit"] = 125, ["Gold Vein"] = 155,
  ["Mithril Deposit"] = 175, ["Truesilver Deposit"] = 230, ["Dark Iron Deposit"] = 230, ["Small Thorium Vein"] = 245,
  ["Rich Thorium Vein"] = 275, ["Ooze Covered Silver Vein"] = 75, ["Ooze Covered Gold Vein"] = 155,
  ["Ooze Covered Mithril Deposit"] = 175, ["Ooze Covered Truesilver Deposit"] = 230, ["Ooze Covered Thorium Vein"] = 245,
  ["Incendicite Mineral Vein"] = 65, ["Lesser Bloodstone Deposit"] = 75, ["Indurium Mineral Vein"] = 150 }
for _, h in ipairs(HERBS) do NODE_REQ[h[1]] = h[2] end
function U.gatherReq(name) return name and NODE_REQ[name] or nil end
function U.gatherD(req, skill)
  if skill < req then return 4 elseif skill < req + 25 then return 0 elseif skill < req + 50 then return 1
  elseif skill < req + 100 then return 2 end
  return 3
end

local GROUPS = { [0] = "Dają punkty", [1] = "Dają punkty", [2] = "Dają punkty", [4] = "Później", [3] = "Bez punktu: sprzedaj albo na mikstury" }
local ORDER = { [0] = 1, [1] = 1, [2] = 1, [4] = 2, [3] = 3 }

local function count(id)
  return U.num(U.call((C_Item and C_Item.GetItemCount) or GetItemCount, id)) or 0
end

-- lista w ksztalcie przepisow Rzemiosla: { name, d (0-4), can (ile masz), group, id, icon, req, zones, gather = true }
function U.gatherRec(prof, skill)
  local data = U.GATHER_DATA[prof]
  if not data then return nil end
  skill = skill or 0
  local potion = U.G and U.G.POTION_HERBS or {}
  local list = {}
  for _, h in ipairs(data) do
    local req = h[2]
    if req <= skill + 50 then
      local d
      if skill < req then d = 4 elseif skill < req + 25 then d = 0 elseif skill < req + 50 then d = 1
      elseif skill < req + 100 then d = 2 else d = 3 end
      local p = potion[h[3]]
      list[#list + 1] = { name = h[1], req = req, id = h[3], zones = h[4], d = d, gather = true, reagents = {},
        n = count(h[3]), group = GROUPS[d], ord = ORDER[d],
        potion = p and (p[2] .. " od " .. p[1] .. " Pierwszej pomocy") or nil,
        icon = U.call(C_Item and C_Item.GetItemIconByID, h[3]), link = "item:" .. h[3] }
    end
  end
  table.sort(list, function(a, b)
    if a.ord ~= b.ord then return a.ord < b.ord end
    return a.req < b.req
  end)
  return { list = list, gather = true, at = time() }
end
