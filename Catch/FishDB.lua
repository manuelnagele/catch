-- Catch: "what bites where". FishMate's FishDB.lua, unchanged below this header except for comments:
-- MIT, (c) 2026 AndreiBerkut (see LICENSE-FishMate). Source: wowforever.ninja (the original game's fishing tables
-- WoW Forever is built on), November 2026. Chance = percent per catch.
-- Row: { item ID or 0, English name, chance or nil, flag }; nil chance = the rest (100 % minus the others);
-- flag "q" = quest-only (not in the expectation). Zone table: { spots = nil (open water) or subzone names, rows = {...} }.
-- FishMate: база "что где ловится".
-- Источник: wowforever.ninja (таблицы рыбалки оригинальной игры, на которых
-- построен WoW Forever), ноябрь 2026. Шанс - процент на один улов.
-- Строка: { ID предмета или 0, английское название, шанс или nil, флаг }
--   шанс nil - "остальное": 100% минус всё прочее в таблице;
--   флаг "q" - только с заданием (в общий расчёт не входит).
-- Таблица зоны: { spots = nil (открытая вода) или список подзон, rows = {...} }.
-- Подзоны записаны по-английски; русские названия аддон узнаёт сам по улову.
-- Только символы ASCII и кириллица.

local _, ns = ...
local data = ns.data

local LT = 0.05 -- "<0.1%"

-- Повторяющиеся таблицы (одинаковые в нескольких зонах)
local START_INLAND = { -- Дун Морог, Элвиннский лес, Тельдрассил
    { 6289, "Raw Longjaw Mud Snapper", 40 },
    { 118, "Minor Healing Potion", 0.4 },
    { 2455, "Minor Mana Potion", 0.4 },
    { 0, "Bloated Brilliant Smallfish", 0.2 },
    { 0, "10 Pound Mud Snapper", 0.1 },
    { 0, "12 Pound Mud Snapper", LT },
    { 0, "15 Pound Mud Snapper", LT },
    { 6291, "Raw Brilliant Smallfish", nil },
}

local CATFISH_INLAND = { -- Стальгорн, Западный Край, реки Степей, Темные берега
    { 6308, "Raw Bristle Whisker Catfish", 30 },
    { 6291, "Raw Brilliant Smallfish", 18 },
    { 858, "Lesser Healing Potion", 0.5 },
    { 3385, "Lesser Mana Potion", 0.5 },
    { 0, "17 Pound Catfish", 0.4 },
    { 0, "Bloated Mud Snapper", 0.3 },
    { 0, "19 Pound Catfish", 0.2 },
    { 0, "22 Pound Catfish", LT },
    { 0, "The 1 Ring", LT },
    { 0, "26 Pound Catfish", LT },
    { 0, "32 Pound Catfish", LT },
    { 6289, "Raw Longjaw Mud Snapper", nil },
}

local LOW_COAST = { -- побережья 10-20
    { 6303, "Raw Slitherskin Mackerel", 33.5 },
    { 6358, "Oily Blackmouth", 15 },
    { 6307, "Message in a Bottle", 0.5 },
    { 0, "Dented Crate", 0.5 },
    { 0, "Small Chest", 0.5 },
    { 6361, "Raw Rainbow Fin Albacore", nil },
}

local MID_INLAND = { -- Ясеневый лес, Предгорья Хилсбрада
    { 6289, "Raw Longjaw Mud Snapper", 35 },
    { 929, "Healing Potion", 0.5 },
    { 3827, "Mana Potion", 0.5 },
    { 0, "Bloated Bristle Whisker Catfish", 0.3 },
    { 0, "19 Pound Catfish", 0.2 },
    { 0, "22 Pound Catfish", LT },
    { 6366, "Darkwood Fishing Pole", LT },
    { 0, "26 Pound Catfish", LT },
    { 0, "32 Pound Catfish", LT },
    { 6308, "Raw Bristle Whisker Catfish", nil },
}

local MID_COAST = { -- побережья 20-30
    { 6358, "Oily Blackmouth", 25 },
    { 6359, "Firefin Snapper", 15 },
    { 0, "Small Locked Chest", 0.4 },
    { 0, "Waterlogged Crate", 0.4 },
    { 6307, "Message in a Bottle", 0.4 },
    { 0, "Steelscale Crushfish", LT },
    { 6361, "Raw Rainbow Fin Albacore", nil },
}

local DEAD_INLAND = { -- Тирисфальские леса, Серебряный бор
    { 6289, "Raw Longjaw Mud Snapper", 30 },
    { 0, "Sickly Looking Fish", 15 },
    { 0, "Old Skull", 7 },
    { 0, "Old Teamster's Skull", 1.8 },
    { 118, "Minor Healing Potion", 0.4 },
    { 2455, "Minor Mana Potion", 0.4 },
}

local DARKSHORE_RIVER_TAIL = {
    { 6291, "Raw Brilliant Smallfish", 18 },
    { 6308, "Raw Bristle Whisker Catfish", 15 },
    { 858, "Lesser Healing Potion", 0.5 },
    { 3385, "Lesser Mana Potion", 0.5 },
    { 0, "17 Pound Catfish", 0.4 },
    { 0, "Bloated Mud Snapper", 0.3 },
    { 0, "19 Pound Catfish", 0.2 },
    { 0, "22 Pound Catfish", LT },
    { 0, "26 Pound Catfish", LT },
    { 0, "32 Pound Catfish", LT },
    { 6289, "Raw Longjaw Mud Snapper", nil },
}

local function With(head, tail)
    local t = {}
    for _, r in ipairs(head) do table.insert(t, r) end
    for _, r in ipairs(tail) do table.insert(t, r) end
    return t
end

data.FISHDB = {
    -- Дун Морог
    [1426] = { { rows = START_INLAND } },
    -- Элвиннский лес
    [1429] = { { rows = START_INLAND } },
    -- Тельдрассил
    [1438] = {
        { rows = START_INLAND },
        { spots = { "Rut'theran Village" }, rows = {
            { 0, "Battered Chest", 2 },
            { 6303, "Raw Slitherskin Mackerel", nil },
        } },
    },
    -- Тирисфальские леса
    [1420] = {
        { rows = DEAD_INLAND },
        { spots = { "The North Coast", "Whispering Shore" }, rows = {
            { 0, "Battered Chest", 2 },
            { 6303, "Raw Slitherskin Mackerel", nil },
        } },
    },
    -- Серебряный бор
    [1421] = {
        { rows = DEAD_INLAND },
        { spots = { "North Tide's Run", "South Tide's Run", "The Great Sea", "The Skittering Dark" }, rows = LOW_COAST },
    },
    -- Подгород
    [1458] = { { rows = {
        { 0, "Old Skull", 15 },
        { 0, "Sickly Looking Fish", 15 },
        { 6308, "Raw Bristle Whisker Catfish", 15 },
        { 6291, "Raw Brilliant Smallfish", 12.5 },
        { 858, "Lesser Healing Potion", 0.5 },
        { 3385, "Lesser Mana Potion", 0.5 },
        { 0, "Old Teamster's Skull", 0.5 },
        { 0, "17 Pound Catfish", 0.4 },
        { 0, "Bloated Mud Snapper", 0.3 },
        { 0, "19 Pound Catfish", 0.2 },
        { 0, "22 Pound Catfish", LT },
        { 0, "The 1 Ring", LT },
        { 0, "26 Pound Catfish", LT },
        { 0, "32 Pound Catfish", LT },
        { 6289, "Raw Longjaw Mud Snapper", nil },
    } } },
    -- Стальгорн
    [1455] = { { rows = CATFISH_INLAND } },
    -- Западный Край
    [1436] = {
        { rows = CATFISH_INLAND },
        { spots = { "Longshore", "Westfall Lighthouse" }, rows = LOW_COAST },
    },
    -- Лок Модан (на сайте только одна строка)
    [1432] = { { rows = { { 6317, "Raw Loch Frenzy", 25 } }, partial = true } },
    -- Предгорья Хилсбрада
    [1424] = {
        { rows = MID_INLAND },
        { spots = { "Eastern Strand", "Southshore", "Western Strand" }, rows = MID_COAST },
    },
    -- Ясеневый лес
    [1440] = {
        { rows = MID_INLAND },
        { spots = { "The Zoram Strand" }, rows = MID_COAST },
    },
    -- Темные берега
    [1439] = {
        { rows = {
            { 0, "Darkshore Grouper", 30, "q" },
            { 6303, "Raw Slitherskin Mackerel", 18.5 },
            { 6358, "Oily Blackmouth", 10 },
            { 0, "Gaffer Jack", 10, "q" },
            { 6307, "Message in a Bottle", 0.5 },
            { 0, "Dented Crate", 0.5 },
            { 0, "Small Chest", 0.5 },
            { 6361, "Raw Rainbow Fin Albacore", nil },
        } },
        { spots = { "Cliffspring Falls", "Cliffspring River", "Grove of the Ancients", "Wildbend River" },
          rows = With({ { 0, "Electropeller", 45, "q" }, { 0, "Darkshore Grouper", 30, "q" } }, DARKSHORE_RIVER_TAIL) },
        { spots = { "Ruins of Mathystra", "Twilight Vale" },
          rows = With({ { 0, "Darkshore Grouper", 30, "q" }, { 0, "Electropeller", 25, "q" } }, DARKSHORE_RIVER_TAIL) },
    },
    -- Степи
    [1413] = {
        { rows = LOW_COAST },
        { spots = { "Blackthorn Ridge", "Dreadmist Peak", "Southern Barrens", "Southfury River" }, rows = CATFISH_INLAND },
        { spots = { "Lushwater Oasis", "The Forgotten Pools", "The Stagnant Oasis" }, rows = {
            { 6522, "Deviate Fish", 30 },
            { 6308, "Raw Bristle Whisker Catfish", 15 },
            { 6291, "Raw Brilliant Smallfish", 13 },
            { 858, "Lesser Healing Potion", 0.5 },
            { 3385, "Lesser Mana Potion", 0.5 },
            { 0, "17 Pound Catfish", 0.4 },
            { 0, "Bloated Mud Snapper", 0.3 },
            { 0, "19 Pound Catfish", 0.2 },
            { 0, "22 Pound Catfish", LT },
            { 0, "26 Pound Catfish", LT },
            { 0, "32 Pound Catfish", LT },
            { 6289, "Raw Longjaw Mud Snapper", nil },
        } },
        { spots = { "The Sludge Fen" }, rows = {
            { 6308, "Raw Bristle Whisker Catfish", 15 },
            { 0, "Old Wagonwheel", 10 },
            { 0, "Acidic Slime", 10 },
            { 0, "Rusted Engineering Parts", 10 },
            { 0, "Oil Covered Fish", 10 },
            { 6291, "Raw Brilliant Smallfish", 7 },
            { 858, "Lesser Healing Potion", 0.5 },
            { 3385, "Lesser Mana Potion", 0.5 },
            { 0, "17 Pound Catfish", 0.4 },
            { 0, "Bloated Mud Snapper", 0.3 },
            { 0, "19 Pound Catfish", 0.2 },
            { 0, "Broken Wine Bottle", 0.1 },
            { 0, "22 Pound Catfish", LT },
            { 0, "26 Pound Catfish", LT },
            { 0, "32 Pound Catfish", LT },
            { 6289, "Raw Longjaw Mud Snapper", nil },
        } },
    },
    -- Фералас (таблица Verdantis River на сайте неполная)
    [1444] = {
        { rows = {
            { 6308, "Raw Bristle Whisker Catfish", 40 },
            { 1710, "Greater Healing Potion", 0.5 },
            { 3827, "Mana Potion", 0.5 },
            { 0, "Bloated Mithril Head Trout", 0.2 },
            { 0, "17 Pound Catfish", 0.1 },
            { 0, "19 Pound Catfish", 0.1 },
            { 0, "22 Pound Catfish", 0.1 },
            { 0, "26 Pound Catfish", 0.1 },
            { 0, "32 Pound Catfish", LT },
            { 8365, "Raw Mithril Head Trout", nil },
        } },
        { spots = { "Feathermoon Stronghold", "Isle of Dread", "Ruins of Solarsal", "Sardor Isle", "The Forgotten Coast" }, rows = {
            { 13755, "Raw Winter Squid", 10 },
            { 13756, "Raw Summer Bass", 10 },
        }, partial = true },
        { spots = { "Jademir Lake" }, rows = {
            { 13759, "Raw Nightfin Snapper", 17 },
            { 13760, "Raw Sunscale Salmon", 17 },
            { 13890, "Raw Plated Armorfish", 17 },
            { 0, "Lightning Eel", 12 },
            { 13758, "Raw Redgill", 5 },
            { 13446, "Major Healing Potion", 0.4 },
            { 0, "Bloated Whitescale Salmon", 0.4 },
            { 13443, "Superior Mana Potion", 0.3 },
            { 0, "15 Pound Salmon", 0.2 },
            { 0, "18 Pound Salmon", 0.1 },
            { 0, "22 Pound Salmon", LT },
            { 0, "25 Pound Salmon", LT },
            { 0, "29 Pound Salmon", LT },
            { 13889, "Raw Whitescale Salmon", nil },
        } },
        { spots = { "Verdantis River" }, rows = {
            { 0, "Feralas Ahi", 20, "q" },
        }, partial = true },
    },
    -- Танарис
    [1446] = { { rows = {
        { 13756, "Raw Summer Bass", 25 },
        { 13422, "Stonescale Eel", 15 },
        { 13754, "Raw Glossy Mightfish", 15 },
        { 6359, "Firefin Snapper", 10 },
        { 6362, "Raw Rockscale Cod", 10 },
        { 13755, "Raw Winter Squid", 10 },
        { 7973, "Big-mouth Clam", 8 },
        { 0, "Heavy Crate", 0.5 },
        { 0, "Ironbound Locked Chest", 0.5 },
        { 0, "40 Pound Yellowtail", 0.4 },
        { 0, "47 Pound Yellowtail", 0.2 },
        { 0, "53 Pound Yellowtail", LT },
        { 0, "59 Pound Yellowtail", LT },
        { 0, "68 Pound Yellowtail", LT },
        { 4603, "Raw Spotted Yellowtail", nil },
    } } },
    -- Кратер Ун'Горо
    [1449] = {
        { rows = {
            { 13759, "Raw Nightfin Snapper", 18 },
            { 13760, "Raw Sunscale Salmon", 18 },
            { 6358, "Oily Blackmouth", 10 },
            { 8365, "Raw Mithril Head Trout", 10 },
            { 0, "Lightning Eel", 7 },
            { 3928, "Superior Healing Potion", 0.3 },
            { 6149, "Greater Mana Potion", 0.3 },
            { 0, "Bloated Redgill", 0.3 },
            { 0, "34 Pound Redgill", 0.3 },
            { 0, "37 Pound Redgill", 0.2 },
            { 0, "42 Pound Redgill", 0.1 },
            { 0, "45 Pound Redgill", LT },
            { 0, "49 Pound Redgill", LT },
            { 0, "52 Pound Redgill", LT },
            { 13758, "Raw Redgill", nil },
        } },
        { spots = { "Fire Plume Ridge" }, rows = {
            { 3857, "Coal", 20 },
            { 0, "Old Skull", nil },
        } },
    },
}
