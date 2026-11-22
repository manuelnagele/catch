-- Catch: reference data. From FishMate (MIT, (c) 2026 AndreiBerkut, see LICENSE-FishMate), which took it from the
-- original game's fishing tables via wowforever.ninja (Nov 2026). Classic values; Forever may differ, which is why
-- Catch prefers your own measured catches once you have them.
local _, ns = ...
local data = {}
ns.data = data

-- Fishing (Classic ranks and the new engine's IDs Forever runs on)
data.FISHING_SPELLS = {
    [7620] = true, [7731] = true, [7732] = true, [18248] = true,
    [131474] = true, [131476] = true, [131490] = true,
}

-- The "Fishing Bobber" game object (entry in a GameObject GUID); any other object you fish from is a pool or wreck
data.BOBBER_ENTRY = "35591"

-- Lures: [itemID] = skill bonus
data.LURES = {
    [6533] = 100, -- Aquadynamic Fish Attractor
    [6532] = 75,  -- Bright Baubles
    [7307] = 75,  -- Flesh Eating Worm
    [6530] = 50,  -- Nightcrawlers
    [6811] = 50,  -- Aquadynamic Fish Lens
    [6529] = 25,  -- Shiny Bauble
}

-- Zone base skill (Classic), key = uiMapID. Catch chance = (skill + bonus - base) + 5 %; no lost casts from base + 95.
data.ZONE_BASE = {
    [1411] = -70, [1412] = -70, [1413] = -20, [1416] = 130, [1417] = 130,
    [1420] = -70, [1421] = -20, [1422] = 205, [1423] = 330, [1424] = 55,
    [1425] = 205, [1426] = -70, [1428] = 330, [1429] = -70, [1430] = 330,
    [1431] = 55,  [1432] = -20, [1433] = 55,  [1434] = 130, [1435] = 130,
    [1436] = -20, [1437] = 55,  [1438] = -70, [1439] = -20, [1440] = 55,
    [1441] = 130, [1442] = 55,  [1443] = 130, [1444] = 205, [1445] = 130,
    [1446] = 205, [1447] = 205, [1448] = 205, [1449] = 205, [1450] = 205,
    [1451] = 330, [1452] = 330, [1453] = -20, [1454] = -20, [1455] = -20,
    [1456] = -20, [1457] = -20, [1458] = -20,
}
