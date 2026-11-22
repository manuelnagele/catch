-- Catch core: the fishing math. No WoW calls here, so it runs under LuaJIT in tests (tests/run.lua).
local _, ns = ...
ns = ns or {}
local Core = {}
ns.Core = Core

Core.SESSION_GAP = 1800   -- logged out longer than this = a new fishing session
Core.FISHING_IDLE = 60    -- seconds after a cast that still count as fishing time
Core.BITE_MIN = 8         -- casts needed before the cast bar shows a bite window

-- --- formatting / chat ---------------------------------------------------------

function Core.pattern(fmt)
    local p = fmt:gsub("([%(%)%.%[%]%*%+%-%?%^%$])", "%%%1")
    p = p:gsub("%%s", "(.+)"):gsub("%%d", "(%%d+)")
    return "^" .. p .. "$"
end

function Core.parseLoot(msg, patterns)
    for _, p in ipairs(patterns) do
        local link, count = msg:match(p)
        if link then return link, tonumber(count) or 1 end
    end
end

function Core.itemID(link) return tonumber(link and link:match("item:(%d+)")) end

function Core.perHour(copper, active)
    if not active or active < 60 then return nil end
    return math.floor(copper * 3600 / active)
end

function Core.clock(seconds)
    seconds = math.floor(seconds or 0)
    local h, m, s = math.floor(seconds / 3600), math.floor(seconds / 60) % 60, seconds % 60
    if h > 0 then return ("%d:%02d:%02d"):format(h, m, s) end
    return ("%d:%02d"):format(m, s)
end

-- "GameObject-0-<server>-<map>-<copy>-<entry>-<spawn>" -> entry (string)
function Core.objectEntry(guid)
    if type(guid) ~= "string" then return nil end
    local kind, entry = guid:match("^(%a+)%-%d+%-%d+%-%d+%-%d+%-(%d+)%-")
    return kind == "GameObject" and entry or nil
end

-- --- stats -----------------------------------------------------------------------

function Core.meanSd(values)
    local n = #values
    if n == 0 then return nil end
    local sum = 0
    for _, v in ipairs(values) do sum = sum + v end
    local mean = sum / n
    if n == 1 then return mean, 0, nil end
    local sq = 0
    for _, v in ipairs(values) do sq = sq + (v - mean) ^ 2 end
    local sd = math.sqrt(sq / (n - 1))
    return mean, sd, 1.96 * sd / math.sqrt(n)
end

function Core.percentile(values, p)
    if #values == 0 then return nil end
    local v = {}
    for i, x in ipairs(values) do v[i] = x end
    table.sort(v)
    local idx = 1 + (#v - 1) * p
    local lo, hi = math.floor(idx), math.ceil(idx)
    return v[lo] + (v[hi] - v[lo]) * (idx - lo)
end

-- Bite window from cast-to-catch seconds: 20th–80th percentile and the mean (nil with too few casts).
function Core.biteWindow(times)
    if #times < Core.BITE_MIN then return nil end
    local mean = Core.meanSd(times)
    return { low = Core.percentile(times, 0.2), high = Core.percentile(times, 0.8), avg = mean, n = #times }
end

-- Catch log entries {t, id, n} -> catches (one per loot window = same t), per-fish breakdown, best catch.
function Core.fishSummary(log, price)
    local catches, byFish, order = {}, {}, {}
    local lastT, total = nil, 0
    for _, e in ipairs(log) do
        local vendor, market = price(e.id)
        local each = market or vendor or 0
        local value = each * (e.n or 1)
        if e.t ~= lastT then catches[#catches + 1] = 0 lastT = e.t end
        catches[#catches] = catches[#catches] + value
        local f = byFish[e.id]
        if not f then
            f = { id = e.id, count = 0, value = 0, each = each, junk = (market == nil) }
            byFish[e.id] = f
            order[#order + 1] = f
        end
        f.count = f.count + (e.n or 1)
        f.value = f.value + value
        total = total + value
    end
    table.sort(order, function(a, b) return a.value > b.value end)
    local best = 0
    for _, v in ipairs(catches) do best = math.max(best, v) end
    local mean, sd, ci = Core.meanSd(catches)
    return { catches = #catches, total = total, mean = mean, sd = sd, ci = ci, best = best, fish = order }
end

function Core.minuteBins(log, price, now, minutes)
    local bins = {}
    for i = 1, minutes do bins[i] = 0 end
    for _, e in ipairs(log) do
        local age = math.floor((now - e.t) / 60)
        if age >= 0 and age < minutes then
            local vendor, market = price(e.id)
            local i = minutes - age
            bins[i] = bins[i] + (market or vendor or 0) * (e.n or 1)
        end
    end
    return bins
end

function Core.etaMinutes(target, perHour)
    if not perHour or perHour <= 0 then return nil end
    return math.ceil(target / perHour * 60)
end

-- --- drop tables -----------------------------------------------------------------

-- The water for a subzone in a zone's tables: the entry listing it in `spots`, else open water (no spots).
function Core.water(tables, subzone)
    if not tables then return nil end
    local open
    for _, w in ipairs(tables) do
        if w.spots then
            for _, s in ipairs(w.spots) do if s == subzone then return w end end
        elseif not open then
            open = w
        end
    end
    return open
end

-- Rows with chances: nil chance = the rest (100 % minus everything else that isn't quest-only).
-- Returns {id, name, chance, quest} with every chance filled in.
function Core.chances(rows)
    local fixed = 0
    for _, r in ipairs(rows or {}) do
        if r[3] and r[4] ~= "q" then fixed = fixed + r[3] end
    end
    local out = {}
    for _, r in ipairs(rows or {}) do
        out[#out + 1] = { id = r[1], name = r[2], chance = r[3] or math.max(0, 100 - fixed), quest = r[4] == "q" }
    end
    return out
end

-- Expected value per catch of a water: Σ chance × value (quest-only rows and name-only rows count 0).
function Core.waterEV(rows, price)
    local ev, parts = 0, {}
    for _, r in ipairs(Core.chances(rows)) do
        if not r.quest and r.id and r.id > 0 then
            local vendor, market = price(r.id)
            local each = market or vendor or 0
            local part = each * r.chance / 100
            ev = ev + part
            parts[#parts + 1] = { id = r.id, name = r.name, chance = r.chance, each = each, part = part }
        end
    end
    table.sort(parts, function(a, b) return a.part > b.part end)
    return ev, parts
end

-- Classic catch chance: (skill + bonus − zone base) + 5 %, capped 100; no lost casts from base + 95.
function Core.catchChance(skill, base)
    if not skill or not base then return nil end
    return math.max(0, math.min(100, skill - base + 5))
end

-- --- spots (map hotspots) ------------------------------------------------------------

-- Cluster catch positions per map (~`radius` in map units, 0..1): {map, x, y, n, value, pools, last}.
function Core.clusterSpots(spots, price, radius)
    radius = radius or 0.02
    local clusters = {}
    for _, s in ipairs(spots) do
        local vendor, market = price(s.id)
        local value = (market or vendor or 0) * (s.n or 1)
        local hit
        for _, c in ipairs(clusters) do
            if c.map == s.map and (c.x - s.x) ^ 2 + (c.y - s.y) ^ 2 <= radius * radius then hit = c break end
        end
        if not hit then
            hit = { map = s.map, x = s.x, y = s.y, n = 0, catches = 0, value = 0, pools = 0, last = 0, sub = s.sub,
                    lastT = nil }
            clusters[#clusters + 1] = hit
        end
        -- running mean position
        hit.n = hit.n + 1
        hit.x = hit.x + (s.x - hit.x) / hit.n
        hit.y = hit.y + (s.y - hit.y) / hit.n
        if s.t ~= hit.lastT then hit.catches = hit.catches + 1 hit.lastT = s.t end
        hit.value = hit.value + value
        if s.pool then hit.pools = hit.pools + 1 end
        hit.last = math.max(hit.last, s.t or 0)
    end
    for _, c in ipairs(clusters) do c.perCatch = c.catches > 0 and c.value / c.catches or 0 end
    return clusters
end

-- The lure to put on: the one with the highest skill bonus among your bag items ({[itemID] = count}).
function Core.bestLure(items, lures)
    local best, bonus
    for id, n in pairs(items) do
        local b = lures[id]
        if b and n > 0 and (not bonus or b > bonus or (b == bonus and id < best)) then best, bonus = id, b end
    end
    return best, bonus
end

-- How your lure stands: "none", "low" (≤ low seconds left) or "ok", and the share of its time left.
function Core.lureState(left, total, low)
    if not left or left <= 0 then return "none", 0 end
    local share = math.min(1, left / math.max(total or left, left))
    return left <= low and "low" or "ok", share
end

-- The lure's full time: a reading that went up means a fresh lure; round it up to the minute.
function Core.lureTotal(left, prevLeft, total)
    if left and (not prevLeft or left > prevLeft + 2) then return math.ceil(left / 60) * 60 end
    return total
end

-- What kind of moment a catch is: "best" (beats the session's best catch, after a few), "rare" (rare quality, or worth
-- 3× your average catch), else "plain". best, mean, catches: the session before this catch.
function Core.catchMoment(value, quality, best, mean, catches)
    if catches >= 5 and value > 0 and value > (best or 0) then return "best" end
    if (quality or 0) >= 3 or (catches >= 5 and (mean or 0) > 0 and value >= 3 * mean) then return "rare" end
    return "plain"
end

-- The fish-count milestone crossed between two counts (10, 25, 50, 100, then every 50), or nil.
function Core.milestone(before, after)
    local hit
    for _, m in ipairs({ 10, 25, 50, 100 }) do if before < m and after >= m then hit = m end end
    if after >= 150 and math.floor(after / 50) > math.floor(math.max(before, 100) / 50) then
        hit = math.floor(after / 50) * 50
    end
    return hit
end

-- One fishing button (FishMate's order): what the next press does. "reel" while the bobber is out, "pole" when you
-- hold something else and have a pole in your bags, "lure" when there's no lure on the pole (and none just applied: the
-- game takes a moment to show it) and one in the bags, else "cast".
function Core.fishStep(channeling, lureLeft, haveLure, sinceApplied, poleOn, havePole)
    if channeling then return "reel" end
    if poleOn == false and havePole then return "pole" end
    if not lureLeft and haveLure and (sinceApplied or math.huge) > 12 then return "lure" end
    return "cast"
end

-- Done fishing: stop the cast and put your weapons back (main hand, off hand if you had one). Names as /equipslot
-- takes them; nil when there's nothing to put back.
function Core.weaponMacro(mainName, offName)
    if not mainName then return nil end
    local lines = { "/stopcasting", "/equipslot 16 " .. mainName }
    if offName then lines[#lines + 1] = "/equipslot 17 " .. offName end
    return table.concat(lines, "\n")
end

return Core
