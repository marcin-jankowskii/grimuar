-- Grimuar UI: Rzemioslo, „Cele i surowce” (14.11, gracz: „tutaj mozna by opisac obecne cele, na czym sie skupiac, co
-- robic z kazdym zebranym surowcem, bo zebralem troche copperu i nie wiem, co z nim”).
-- Surowce w torbach z ocena: przetop / zrob / gotuj / zostaw / dom aukcyjny / kupiec / do zadania, z wyjasnieniem.
-- Wiedza: plan profesji Grimuara (R13: Zielarstwo + Gornictwo, Pierwsza pomoc robi w Forever tez mikstury, na 40-42
-- Gornictwo -> Krawiectwo; ziola i rude sprzedawac od razu na AH). Przedmiot spoza tabeli ocenia klasa: szary -> kupiec,
-- przedmiot do zadania -> zostaw, inny surowiec -> AH.
local ADDON, U = ...

-- werdykty: etykieta i kolor (indeks DCOL w TabRzemioslo + nowe)
U.MAT_VERDICT = {
  przetop = { "przetop", 0 }, zrob = { "zrób", 0 }, gotuj = { "ugotuj", 0 }, zostaw = { "zostaw", 1 },
  ah = { "dom aukcyjny", 2 }, kupiec = { "sprzedaj kupcowi", 3 }, quest = { "do zadania", 5 },
}

-- { werdykt, rada }
local MATS = {
  -- ruda i sztabki (Gornictwo: przetapianie w kuzni daje punkty)
  [2770] = { "przetop", "Przetop na Copper Bar w kuźni (Kharanos albo Wielka Kuźnia w Ironforge): każde przetopienie daje punkt Górnictwa do ok. 65. Sztabki sprzedaj na domu aukcyjnym albo kupcowi." },
  [2771] = { "przetop", "Od 65 Górnictwa przetop na Tin Bar (punkty), wcześniej sprzedaj na domu aukcyjnym." },
  [2775] = { "ah", "Srebro jest rzadkie i drogie: sprzedaj na domu aukcyjnym (od 75 Górnictwa możesz też przetopić)." },
  [2772] = { "przetop", "Od 125 Górnictwa przetop na Iron Bar, wcześniej sprzedaj na domu aukcyjnym." },
  [2776] = { "ah", "Złoto (ruda) jest drogie: sprzedaj na domu aukcyjnym." },
  [3858] = { "ah", "Mithril schodzi dobrze na domu aukcyjnym; od 175 Górnictwa przetop." },
  [2840] = { "ah", "Copper Bar: sprzedaj na domu aukcyjnym (kowale i inżynierowie kupują), a gdy tanio idzie, kupcowi." },
  [3576] = { "ah", "Tin Bar: na dom aukcyjny." },
  [2841] = { "ah", "Bronze Bar: na dom aukcyjny." },
  [2842] = { "ah", "Silver Bar: na dom aukcyjny." },
  [3575] = { "ah", "Iron Bar: na dom aukcyjny." },
  [3577] = { "ah", "Gold Bar: na dom aukcyjny." },
  [2835] = { "kupiec", "Rough Stone przydaje się kowalom i inżynierom, magowi nie: sprzedaj kupcowi." },
  [2836] = { "kupiec", "Coarse Stone: magowi niepotrzebny, sprzedaj kupcowi." },
  [2838] = { "kupiec", "Heavy Stone: sprzedaj kupcowi." },
  [7912] = { "kupiec", "Solid Stone: sprzedaj kupcowi." },
  -- tkaniny (Pierwsza pomoc: bandaze; plan: Manaweave Robe na 15)
  [2589] = { "zrob", "Linen Bandage (1 sztuka) do 40 Pierwszej pomocy, potem Heavy Linen Bandage (2 sztuki) do 80. Zostaw 10 sztuk na Manaweave Robe (15 poziom, plan Grimuara)." },
  [2592] = { "zrob", "Wool Bandage od 80 Pierwszej pomocy, Heavy Wool od 115. Nadwyżkę sprzedaj na domu aukcyjnym." },
  [4306] = { "zrob", "Silk Bandage od 150 Pierwszej pomocy; do tego czasu sprzedaj nadwyżkę na domu aukcyjnym." },
  [4338] = { "zrob", "Mageweave Bandage od 210 Pierwszej pomocy; nadwyżkę na dom aukcyjny." },
  [14047] = { "zrob", "Runecloth Bandage od 260 Pierwszej pomocy; nadwyżkę na dom aukcyjny." },
  -- ziola (w Forever mikstury leczenia robi Pierwsza pomoc; reszta od razu na AH, calymi stackami)
  [2447] = { "zostaw", "Zostaw ok. 10 na Minor Healing Potion (Pierwsza pomoc od 55, w Forever robi mikstury). Resztę sprzedaj na domu aukcyjnym całymi stackami po 20." },
  [765] = { "ah", "Silverleaf: sprzedaj na domu aukcyjnym całymi stackami po 20 (ceny ziół spadają, sprzedawaj od razu)." },
  [2449] = { "ah", "Earthroot drożeje: sprzedaj na domu aukcyjnym całymi stackami po 20." },
  [785] = { "ah", "Mageroyal: na dom aukcyjny całymi stackami." },
  [2450] = { "zostaw", "Zostaw ok. 10 na Lesser Healing Potion (Pierwsza pomoc od 85), resztę na dom aukcyjny." },
  [3820] = { "ah", "Stranglekelp: na dom aukcyjny." },
  [2453] = { "zostaw", "Zostaw ok. 10 na Healing Potion (Pierwsza pomoc od 135), resztę na dom aukcyjny." },
  [3355] = { "ah", "Wild Steelbloom: na dom aukcyjny." },
  [3369] = { "ah", "Grave Moss: na dom aukcyjny." },
  [3356] = { "ah", "Kingsblood: na dom aukcyjny." },
  [3357] = { "zostaw", "Zostaw ok. 10 na Greater Healing Potion (Pierwsza pomoc od 155), resztę na dom aukcyjny." },
  -- mieso (Gotowanie: danie przy ognisku daje punkt; zrobisz je przy Basic Campfire)
  [769] = { "gotuj", "Roasted Boar Meat przy ognisku (Gotowanie). Ognisko: Basic Campfire z księgi profesji, potrzebne Simple Wood i Flint and Tinder (Kreg Bilmn w Kharanos)." },
  [2672] = { "gotuj", "Charred albo Spiced Wolf Meat przy ognisku (Gotowanie)." },
  [2886] = { "gotuj", "Crag Boar Rib: zadanie kucharskie „Beer Basted Boar Ribs” (Ragnar Thunderbrew, Kharanos) albo ugotuj." },
  [3173] = { "gotuj", "Bear Meat: Smoked Bear Meat przy ognisku (Gotowanie od 40)." },
  [2673] = { "gotuj", "Coyote Meat: Coyote Steak (Gotowanie)." },
  [2674] = { "gotuj", "Crawler Meat: Crawler Claw/Crab Cake (Gotowanie)." },
  [723] = { "gotuj", "Goretusk Liver: Goretusk Liver Pie (Gotowanie)." },
  [6889] = { "gotuj", "Small Egg: Herb Baked Egg (Gotowanie)." },
  [1015] = { "gotuj", "Lean Wolf Flank: Seasoned Wolf Kabob (Gotowanie)." },
  [2677] = { "gotuj", "Boar Ribs: Dry Pork Ribs (Gotowanie)." },
}

local function info(id)
  -- pcall wprost: U.call oddaje tylko 4 wartosci, a ikona, cena i klasa sa dalej
  local f = (C_Item and C_Item.GetItemInfo) or GetItemInfo
  if not f then return nil end
  local ok, name, _, quality, _, _, _, _, _, _, icon, sell, classID = pcall(f, id)
  if not ok then return nil end
  return name, U.num(quality), icon, sell, U.num(classID)
end

-- surowce w torbach (bez sprzetu i rzeczy do uzycia): { id, name, icon, count, verdict, text }
function U.bagMaterials()
  local CC = C_Container
  if not (CC and CC.GetContainerNumSlots and CC.GetContainerItemInfo) then return {} end
  local counts, order = {}, {}
  for bag = 0, (NUM_BAG_SLOTS or 4) do
    for slot = 1, U.num(U.call(CC.GetContainerNumSlots, bag)) or 0 do
      local it = U.call(CC.GetContainerItemInfo, bag, slot)
      local id = type(it) == "table" and U.num(it.itemID)
      if id then
        if not counts[id] then counts[id] = 0 order[#order + 1] = id end
        counts[id] = counts[id] + (U.num(it.stackCount) or 1)
      end
    end
  end
  local out = {}
  for _, id in ipairs(order) do
    local name, quality, icon, sell, classID = info(id)
    local m = MATS[id]
    local verdict, text
    if m then
      verdict, text = m[1], m[2]
    elseif quality == 0 then
      verdict, text = "kupiec", "Szary przedmiot: sprzedaj kupcowi (Leatrix sprzedaje szare sam przy otwarciu okna kupca)."
    elseif classID == 12 then
      verdict, text = "quest", "Przedmiot do zadania: zostaw, zniknie po oddaniu zadania."
    elseif classID == 7 then
      verdict, text = "ah", "Surowiec, którego Twoje profesje nie używają: sprzedaj na domu aukcyjnym (Rynek Grimuara podpowie cenę), a gdy idzie tanio, kupcowi."
    end
    if verdict then
      out[#out + 1] = { id = id, name = name or ("#" .. id), icon = icon, count = counts[id], verdict = verdict, text = text,
        sell = U.num(sell), quality = quality }
    end
  end
  local ORDER = { przetop = 1, zrob = 2, gotuj = 3, zostaw = 4, ah = 5, kupiec = 6, quest = 7 }
  table.sort(out, function(a, b)
    if ORDER[a.verdict] ~= ORDER[b.verdict] then return (ORDER[a.verdict] or 9) < (ORDER[b.verdict] or 9) end
    return a.name < b.name
  end)
  return out
end
