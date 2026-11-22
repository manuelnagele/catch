-- luajit tests/run.lua  (from the repo root)
local ns = {}
assert(loadfile("Catch/Core.lua"))("Catch", ns)
local Core = ns.Core
local failures = 0
local function check(name, cond)
    if not cond then failures = failures + 1 print("FAIL " .. name) else print("ok   " .. name) end
end

local pats = { Core.pattern("You receive loot: %sx%d."), Core.pattern("You receive loot: %s.") }
local link = "|cffffffff|Hitem:13422::::::::60:::::|h[Stonescale Eel]|h|r"
local l, n = Core.parseLoot("You receive loot: " .. link .. "x2.", pats)
check("loot line", l == link and n == 2 and Core.itemID(l) == 13422)
check("bobber entry", Core.objectEntry("GameObject-0-4170-1-123-35591-0000AB") == "35591")
check("pool entry", Core.objectEntry("GameObject-0-4170-1-123-180683-0000AB") == "180683")
check("creature isn't an object", Core.objectEntry("Creature-0-4170-1-123-11517-0000AB") == nil)

check("percentile", Core.percentile({ 1, 2, 3, 4, 5 }, 0.5) == 3 and Core.percentile({ 1, 2, 3, 4, 5 }, 0.2) == 1.8)
check("bite window needs casts", Core.biteWindow({ 5, 6 }) == nil)
local w = Core.biteWindow({ 4, 5, 6, 7, 8, 9, 10, 11, 12, 13 })
check("bite window", w and w.n == 10 and w.avg == 8.5 and w.low < w.avg and w.high > w.avg)

local price = function(id) if id == 1 then return 10, 100 elseif id == 2 then return 5, nil end return 0, nil end
local fs = Core.fishSummary({ { t = 1, id = 1, n = 2 }, { t = 2, id = 2, n = 1 }, { t = 2, id = 1, n = 1 } }, price)
check("fish summary", fs.catches == 2 and fs.total == 305 and fs.best == 200 and fs.fish[2].junk)
local bins = Core.minuteBins({ { t = 1000, id = 1, n = 1 }, { t = 939, id = 1, n = 1 } }, price, 1000, 3)
check("minute bins", bins[3] == 100 and bins[2] == 100 and bins[1] == 0)

local tables = {
    { rows = { { 1, "Fish A", 40 }, { 2, "Fish B", nil }, { 0, "Old Boot", 10 }, { 3, "Quest Thing", 50, "q" } } },
    { spots = { "The Lake" }, rows = { { 1, "Fish A", 90 }, { 2, "Fish B", 10 } } },
}
check("water: subzone match", Core.water(tables, "The Lake") == tables[2])
check("water: open water fallback", Core.water(tables, "Somewhere") == tables[1])
local ch = Core.chances(tables[1].rows)
check("chances: rest = 100 - fixed (quest excluded)", ch[2].chance == 50 and ch[4].quest)
local ev, parts = Core.waterEV(tables[1].rows, price)
check("EV per catch", ev == 40 + 2.5 and parts[1].id == 1)
check("catch chance", Core.catchChance(272, 205) == 72 and Core.catchChance(400, 205) == 100)

local spots = {
    { map = 1, x = 0.50, y = 0.50, id = 1, n = 1, t = 10 },
    { map = 1, x = 0.505, y = 0.50, id = 1, n = 2, t = 20, pool = true },
    { map = 1, x = 0.90, y = 0.90, id = 2, n = 1, t = 30 },
}
local cl = Core.clusterSpots(spots, price, 0.02)
check("clusters", #cl == 2 and cl[1].catches == 2 and cl[1].value == 300 and cl[1].pools == 1 and cl[1].perCatch == 150)

local lures = { [6533] = 100, [6532] = 75, [7307] = 75, [6529] = 25 }
check("best lure in the bags", Core.bestLure({ [6529] = 5, [6532] = 1, [2589] = 20 }, lures) == 6532)
check("tie: the lower id, stable", Core.bestLure({ [7307] = 1, [6532] = 1 }, lures) == 6532)
check("no lure in the bags", Core.bestLure({ [2589] = 20 }, lures) == nil)
check("lure ok", select(1, Core.lureState(400, 600, 120)) == "ok" and select(2, Core.lureState(300, 600, 120)) == 0.5)
check("lure low", Core.lureState(90, 600, 120) == "low")
check("no lure", Core.lureState(nil, 600, 120) == "none" and Core.lureState(0, 600, 120) == "none")
check("fresh lure: its full time", Core.lureTotal(599.4, nil, nil) == 600 and Core.lureTotal(598, 30, 600) == 600)
check("same lure ticking down keeps the total", Core.lureTotal(500, 501, 600) == 600)

check("plain catch", Core.catchMoment(100, 1, 500, 120, 10) == "plain")
check("rare: quality or 3× average", Core.catchMoment(100, 3, 500, 120, 10) == "rare" and Core.catchMoment(400, 1, 500, 120, 10) == "rare")
check("best of the session", Core.catchMoment(600, 1, 500, 120, 10) == "best")
check("no 'best' in the first few", Core.catchMoment(600, 1, 500, 120, 2) == "plain")
check("milestones", Core.milestone(9, 10) == 10 and Core.milestone(24, 26) == 25 and Core.milestone(11, 12) == nil)
check("milestones past 100", Core.milestone(99, 101) == 100 and Core.milestone(149, 150) == 150 and Core.milestone(151, 160) == nil
    and Core.milestone(198, 201) == 200)

check("one button: reel while the bobber is out", Core.fishStep(true, nil, true, nil) == "reel")
check("one button: lure first", Core.fishStep(false, nil, true, nil) == "lure")
check("one button: cast with a lure on", Core.fishStep(false, 300, true, nil) == "cast")
check("one button: cast with no lure to put on", Core.fishStep(false, nil, false, nil) == "cast")
check("one button: no second lure right after one", Core.fishStep(false, nil, true, 3) == "cast")
check("one button: the pole first", Core.fishStep(false, 300, true, nil, false, true) == "pole")
check("one button: no pole to put on", Core.fishStep(false, nil, true, nil, false, false) == "lure")
check("one button: pole on, then the lure", Core.fishStep(false, nil, true, nil, true, true) == "lure")

check("done fishing: both hands", Core.weaponMacro("Sword", "Shield") == "/stopcasting\n/equipslot 16 Sword\n/equipslot 17 Shield")
check("done fishing: a staff", Core.weaponMacro("Staff", nil) == "/stopcasting\n/equipslot 16 Staff")
check("done fishing: nothing remembered", Core.weaponMacro(nil, nil) == nil)

print(failures == 0 and "all passed" or (failures .. " failed"))
os.exit(failures == 0 and 0 or 1)
