-- Catch: fishing, stripped down. What bites here and what it's worth, the cast bar with your bite window, the live
-- panel, hotspots on the map. A Deadbeat module (spec 0.1).
local ADDON, ns = ...
local Core = ns.Core
local VERSION = "0.10.0"

local db, char, session
local fishingNames = {}
local patterns = {}
local loot = { open = false, closedAt = 0, fishing = false, pool = false, at = 0 }
local cast = { active = false, start = 0, duration = 0 }
local m                                   -- Deadbeat module
local SPOTS, LOG, BITES = 5000, 3000, 200

local function secret(v) return issecretvalue ~= nil and issecretvalue(v) end
local function print_(msg) DEFAULT_CHAT_FRAME:AddMessage("|cffd8a446Catch|r: " .. msg) end

-- --- prices ----------------------------------------------------------------------

local itemInfo = {}
local function price(id)
    local i = itemInfo[id]
    if not i then
        local get = (C_Item and C_Item.GetItemInfo) or GetItemInfo
        local name, _, quality, _, _, _, _, _, _, _, sell, _, _, bind = get(id)
        if name then i = { sell = sell or 0, quality = quality, bind = bind } itemInfo[id] = i end
    end
    local vendor = i and i.sell or 0
    local p = ForeverMarketPrices
    if not p or not i or i.quality == 0 or i.bind == 1 then return vendor, nil end
    return vendor, (p.c and p.c[id]) or (p.g and p.g[id])
end

-- --- state ---------------------------------------------------------------------------

local function newSession(now) return { start = now, lastSeen = now, casts = 0, catches = 0, active = 0, log = {} } end

local function fishingNow()
    return session and session.lastCast and time() - session.lastCast <= 120
        and not (session.doneAt and session.doneAt >= session.lastCast)
end

-- Done fishing (the exit key or the weapon icon): everything fishing winds down now instead of after 2 min idle.
local function done()
    if not session then return end
    session.doneAt = time()
    if ns.Focus and ns.Focus.active() then ns.Focus.leave() end
end

-- Fishing skill + bonus (lure, hat): the profession API, else the classic skill lines.
local function skill()
    if GetProfessions and GetProfessionInfo then
        local ok, _, _, _, fishing = pcall(GetProfessions)
        if ok and fishing then
            local _, _, rank, maxRank, _, _, _, modifier = GetProfessionInfo(fishing)
            if rank and not secret(rank) then return rank, maxRank, (not secret(modifier) and modifier) or 0 end
        end
    end
    if GetNumSkillLines and GetSkillLineInfo then
        for i = 1, GetNumSkillLines() do
            local name, header, _, rank, temp, modifier, maxRank = GetSkillLineInfo(i)
            if not header and fishingNames[name] then return rank, maxRank, (modifier or 0) + (temp or 0) end
        end
    end
end

local function here()
    local map = C_Map.GetBestMapForUnit and C_Map.GetBestMapForUnit("player")
    local sub = GetSubZoneText and GetSubZoneText() or ""
    local zone = GetZoneText and GetZoneText() or ""
    return map, (sub ~= "" and sub or zone), zone
end

-- The water you're at: FishMate's table for this subzone/zone (or nil) + the zone's base skill.
local function water()
    local map, sub = here()
    local tables = map and ns.data.FISHDB[map]
    return Core.water(tables, sub), map and ns.data.ZONE_BASE[map], map, sub
end

local function position()
    local map = C_Map.GetBestMapForUnit and C_Map.GetBestMapForUnit("player")
    if not map or secret(map) then return nil end
    local pos = C_Map.GetPlayerMapPosition and C_Map.GetPlayerMapPosition(map, "player")
    if not pos then return nil end
    local x, y = pos:GetXY()
    if not x or secret(x) or secret(y) then return nil end
    return map, x, y
end

-- --- the bar (Deadbeat) ------------------------------------------------------------

local PRIORITY = 50

local function updateBar()
    if not m then return end
    if m.Claim then m:Claim("farm", fishingNow()) end    -- Deadbeat's context: farming while you fish
    if not fishingNow() then
        for _, f in ipairs({ "label", "clock", "primary", "secondary" }) do m:Clear(f) end
        if m.skillBadge then m.skillBadge:Hide() end
        return
    end
    local K = Deadbeat.kit
    local _, sub = here()
    local sum = Core.fishSummary(session.log, price)
    local hourly = Core.perHour(sum.total, session.active)
    m:Set("label", sub, PRIORITY)
    m:Set("clock", Core.clock(session.active), PRIORITY)
    m:Set("primary", K.coins(sum.total, 12), PRIORITY)
    m:Set("secondary", (hourly and (K.coins(hourly, 10, true) .. "|cff" .. K.hex(K.GREEN) .. "/h|r") or ""), PRIORITY)
    -- skill badge: your skill vs. this water's base (green = no lost casts)
    local rank, _, bonus = skill()
    local _, base = water()
    local b = m.skillBadge
    if rank then
        local total = rank + (bonus or 0)
        local c = (base and total >= base + 95) and K.GREEN or (base and K.P.bronze4 or K.P.warmGrey)
        b.text:SetText(("|cff%s%d|r"):format(K.hex(c), total))
        b:Show()
    else
        b:Hide()
    end
end

local function section(tip, shift)
    if not fishingNow() then return end                 -- only while you fish: elsewhere the tooltip has other jobs
    local K, g = Deadbeat.kit, Deadbeat.kit.P.warmGrey
    local w, base, _, sub = water()
    local rank, _, bonus = skill()
    tip:AddDoubleLine("Fishing · " .. sub, rank and ("skill %d%s"):format(rank + (bonus or 0),
        base and ("  ·  %d %%"):format(Core.catchChance(rank + (bonus or 0), base)) or "") or "",
        K.P.bronze4[1], K.P.bronze4[2], K.P.bronze4[3], g[1], g[2], g[3])
    if w then
        local ev, parts = Core.waterEV(w.rows, price)
        tip:AddDoubleLine("  What bites here", "EV " .. K.coins(ev, 11) .. " per catch", g[1], g[2], g[3], 1, 1, 1)
        for i = 1, math.min(5, #parts) do
            local p = parts[i]
            tip:AddDoubleLine(("    %s |cff%s%.1f %%|r"):format(p.name, K.hex(g), p.chance),
                K.coins(p.each, 10) .. ("  |cff%s%d %% of EV|r"):format(K.hex(g), ev > 0 and math.floor(p.part / ev * 100 + 0.5) or 0),
                1, 1, 1, 1, 1, 1)
        end
    else
        tip:AddLine("  No drop table for this water yet: Catch measures your catches here.", g[1], g[2], g[3])
    end
    if shift and ns.Panel then ns.Panel.nerd(tip) end
end

-- Catch's pages in Deadbeat's settings console (the gear on the bar).
local function options(module)
    local OB = ns.OneButton
    local function keyRow(label, which)
        return { kind = "keys", label = label, get = function(slot) return OB and OB.getKey(which, slot) end,
                 set = function(slot, key) if OB then OB.setKey(which, slot, key) end end }
    end
    module:Options({ title = "Catch", icon = "Interface\\Icons\\Trade_Fishing", rows = {
        { kind = "header", label = "While you fish" },
        { kind = "toggle", label = "Fade the rest of the UI", get = function() return db.focus ~= false end,
          set = function(on) db.focus = on if not on and ns.Focus then ns.Focus.leave() end end },
        { kind = "toggle", label = "Adventurer quotes", get = function() return db.quotes ~= false end,
          set = function(on) db.quotes = on end },
        { kind = "toggle", label = "Sounds (choose them on the next page)", get = function() return db.sound ~= false end,
          set = function(on) db.sound = on end },
        { kind = "toggle", label = "Fishing panel under the bar", get = function() return not (ns.Panel and ns.Panel.off) end,
          set = function() if ns.Panel then ns.Panel.toggle() end end },
        { kind = "toggle", label = "Hotspots on the map", get = function() return db.map ~= false end,
          set = function() if ns.Map then ns.Map.toggle() end end },
        { kind = "header", label = "One button" },
        { kind = "note", label = "Each press: your fishing pole on, then your best lure, then a cast; while the bobber is out, it reels in." },
        keyRow("Fishing button", "fish"),
        { kind = "note", label = "Done fishing (only while you fish): stops the cast, your weapon and off-hand back on." },
        keyRow("Done fishing", "done"),
        { kind = "header", label = "Places" },
        { kind = "button", label = "Cast bar position (shift-drag the bar)", text = "Reset",
          run = function() if ns.CastBar then ns.CastBar.reset() end end },
        { kind = "button", label = "Fishing session (count and worth start over)", text = "Reset", confirm = true,
          run = function() SlashCmdList.CATCH("reset") end },
    } })
    module:Options({ title = "Catch · Sounds", icon = "Interface\\Icons\\INV_Misc_Note_01", rows = {
        { kind = "custom", height = ns.CastBar and ns.CastBar.SOUNDS_HEIGHT or 400,
          build = function(frame) if ns.CastBar then ns.CastBar.buildSounds(frame) end end,
          show = function() if ns.CastBar then ns.CastBar.showSounds() end end },
    } })
end

local function buildBar()
    if not Deadbeat then return end
    m = Deadbeat.Register("Catch", 30, { spec = "0.1" })
    local b = m:Badge(34, { id = "catch.skill", label = "Fishing skill", contexts = { farm = true } })
    b.icon = b:CreateTexture(nil, "ARTWORK")
    b.icon:SetSize(12, 12)
    b.icon:SetPoint("LEFT")
    b.icon:SetTexture("Interface\\Icons\\Trade_Fishing")
    b.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    b.text = b:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    b.text:SetPoint("LEFT", b.icon, "RIGHT", 3, 0)
    b:Hide()
    m.skillBadge = b
    m:Section(section)
    if m.Options then options(m) end
end

-- --- API for Panel.lua and Map.lua -----------------------------------------------------

ns.C = {
    price = price,
    session = function() return session end,
    summary = function() return Core.fishSummary(session.log, price) end,
    char = function() return char end,
    link = function(id) return db.links[id] end,
    water = water,
    skill = skill,
    fishingNow = fishingNow,
    done = done,
    cast = function() return cast end,
    bites = function() return char.bites end,
    module = function() return m end,
}

-- --- events ----------------------------------------------------------------------------

local function onCastStart()
    session.casts = session.casts + 1
    session.lastCast = time()
    session.zone = select(3, here())
    cast.active, cast.start = true, GetTime()
    cast.current = { start = cast.start }
    local name, _, _, startMs, endMs = UnitChannelInfo("player")
    if name and not secret(startMs) and startMs and endMs then cast.duration = (endMs - startMs) / 1000
    else cast.duration = 30 end
    if ns.Panel then ns.Panel.onCast() end
    if ns.CastBar then ns.CastBar.onCast() end
    if ns.Lure then ns.Lure.update() end
    if ns.OneButton then ns.OneButton.onCast() end
    if ns.Focus then ns.Focus.enter() end
    updateBar()
end

local function readLootWindow()
    local fishing = IsFishingLoot and IsFishingLoot()
    if secret(fishing) or not fishing then loot.fishing = false return end
    loot.fishing, loot.open, loot.at = true, true, time()
    loot.pool = false
    for slot = 1, GetNumLootItems() do
        local guid = GetLootSourceInfo(slot)
        if guid and not secret(guid) then
            local entry = Core.objectEntry(guid)
            if entry and entry ~= ns.data.BOBBER_ENTRY then loot.pool = true end
        end
    end
    session.catches = session.catches + 1
    if cast.current then cast.current.looted = true end
    if cast.active or GetTime() - cast.start < 40 then
        local bite = GetTime() - cast.start
        if bite > 0 and bite < 40 then
            char.bites[#char.bites + 1] = bite
            while #char.bites > BITES do table.remove(char.bites, 1) end
        end
    end
end

local function onLootLine(msg)
    if secret(msg) then return end
    if not (loot.fishing and (loot.open or GetTime() - loot.closedAt < 3)) then return end
    local link, count = Core.parseLoot(msg, patterns)
    local id = Core.itemID(link)
    if not id then return end
    db.links[id] = link
    session.log[#session.log + 1] = { t = loot.at, id = id, n = count }
    while #session.log > LOG do table.remove(session.log, 1) end
    local map, x, y = position()
    if map then
        local _, sub = here()
        char.spots[#char.spots + 1] = { map = map, x = x, y = y, sub = sub, id = id, n = count, t = loot.at,
                                       pool = loot.pool or nil }
        while #char.spots > SPOTS do table.remove(char.spots, 1) end
    end
    local vendor, market = price(id)
    if ns.Panel then ns.Panel.onCatch(id, count, (market or vendor or 0) * count) end
    if ns.Creel then ns.Creel.onCatch(id, count, (market or vendor or 0) * count) end
    updateBar()
end

local f = CreateFrame("Frame")
local handlers = {}

function handlers.ADDON_LOADED(name)
    if name ~= ADDON then return end
    CatchDB = CatchDB or {}
    db = CatchDB
    if (db.soundsVersion or 0) < 5 then db.sounds, db.waitOff, db.soundsVersion = nil, nil, 5 end   -- the cozy set, pass 2
    db.version, db.chars, db.links = VERSION, db.chars or {}, db.links or {}
end

function handlers.PLAYER_LOGIN()
    local guid = UnitGUID("player")
    db.chars[guid] = db.chars[guid] or { spots = {}, bites = {} }
    char = db.chars[guid]
    char.spots, char.bites = char.spots or {}, char.bites or {}
    local now = time()
    if char.session and char.session.lastSeen and now - char.session.lastSeen <= Core.SESSION_GAP then
        session = char.session
    else
        session = newSession(now)
        char.session = session
    end
    for id in pairs(ns.data.FISHING_SPELLS) do
        local name = C_Spell and C_Spell.GetSpellName and C_Spell.GetSpellName(id)
        if name and not secret(name) then fishingNames[name] = true end
    end
    fishingNames["Fishing"] = true
    for _, key in ipairs({ "LOOT_ITEM_SELF_MULTIPLE", "LOOT_ITEM_SELF", "LOOT_ITEM_PUSHED_SELF_MULTIPLE",
                           "LOOT_ITEM_PUSHED_SELF" }) do
        if _G[key] then patterns[#patterns + 1] = Core.pattern(_G[key]) end
    end
    buildBar()
    if ns.Panel then ns.Panel.build(m) end
    if ns.CastBar then ns.CastBar.build() end
    if ns.Lure then ns.Lure.build() end
    if ns.Creel then ns.Creel.build() end
    if ns.OneButton then ns.OneButton.build() end
    if ns.Quotes then ns.Quotes.build() end
    if ns.Map then ns.Map.build() end
    C_Timer.NewTicker(1, function()
        session.lastSeen = time()
        if session.lastCast and time() - session.lastCast <= Core.FISHING_IDLE then session.active = session.active + 1 end
        if ns.Panel then ns.Panel.tick() end
        if ns.CastBar then ns.CastBar.tick() ns.CastBar.ambienceTick() end
        if ns.Lure then ns.Lure.update() end
        if ns.OneButton then ns.OneButton.tick() end
        if ns.Creel then ns.Creel.tick() end
        if ns.Quotes then ns.Quotes.tick() end
        if ns.Focus then ns.Focus.tick() end
        updateBar()
    end)
end

function handlers.UNIT_SPELLCAST_CHANNEL_START(unit, _, spellID)
    if unit ~= "player" then return end
    local name = C_Spell and C_Spell.GetSpellName and C_Spell.GetSpellName(spellID)
    if name and not secret(name) and fishingNames[name] then onCastStart() end
end

-- A cast ends as a catch (loot), "got away" (the game's message), or ran out (the channel ran its full time
-- without a bite). Anything else — a re-cast, a click before the bite, moving — isn't a lost cast.
local function resolve(c, elapsed)
    if c.looted then return end
    if c.escaped then session.escaped = (session.escaped or 0) + 1
    elseif elapsed >= (cast.duration or 30) - 1.5 then session.missed = (session.missed or 0) + 1 end
    updateBar()
end

function handlers.UNIT_SPELLCAST_CHANNEL_STOP(unit)
    if unit == "player" and cast.active then
        cast.active = false
        local c, elapsed = cast.current, GetTime() - cast.start
        if c then C_Timer.After(1.5, function() resolve(c, elapsed) end) end
        if ns.Panel then ns.Panel.onCastStop() end
        if ns.CastBar then ns.CastBar.onStop() end
        if ns.OneButton then ns.OneButton.onStop() end
    end
end

function handlers.UI_ERROR_MESSAGE(_, msg)
    if not cast.current or secret(msg) or type(msg) ~= "string" then return end
    if msg == ERR_FISH_ESCAPED or msg:lower():find("got away", 1, true) then cast.current.escaped = true end
end

function handlers.LOOT_READY() if not loot.open then readLootWindow() end end
function handlers.LOOT_OPENED() if not loot.open then readLootWindow() end end
function handlers.LOOT_CLOSED() loot.open, loot.closedAt = false, GetTime() end
handlers.CHAT_MSG_LOOT = onLootLine
function handlers.BAG_UPDATE_DELAYED()
    if ns.Lure then ns.Lure.bagsChanged() end
    if ns.OneButton then ns.OneButton.refresh() end
end
function handlers.PLAYER_REGEN_ENABLED()
    if ns.Lure then ns.Lure.update() end
    if ns.OneButton then ns.OneButton.refresh() end
end
function handlers.UNIT_INVENTORY_CHANGED(unit)
    if unit ~= "player" then return end
    if ns.Lure then ns.Lure.update() end
    if ns.OneButton then ns.OneButton.refresh() end
end
function handlers.PLAYER_LOGOUT() if session then session.lastSeen = time() end end

f:SetScript("OnEvent", function(_, event, ...) local h = handlers[event] if h then h(...) end end)
for event in pairs(handlers) do pcall(f.RegisterEvent, f, event) end

-- --- commands -------------------------------------------------------------------------

SLASH_CATCH1 = "/catch"
SlashCmdList.CATCH = function(msg)
    local cmd = strtrim(msg or ""):lower()
    if cmd == "" then
        if ns.Panel then ns.Panel.toggle() end
    elseif cmd == "reset" then
        session = newSession(time())
        char.session = session
        print_("fishing session reset.")
    elseif cmd == "sounds" or cmd == "options" then
        ns.CastBar.openSounds()
    elseif cmd == "keys" or cmd == "button" then
        if Deadbeat and Deadbeat.OpenSettings then Deadbeat.OpenSettings("Catch") end
    elseif cmd == "focus" then
        CatchDB.focus = CatchDB.focus == false
        if not CatchDB.focus and ns.Focus then ns.Focus.leave() end
        print_("focus mode (fade the UI while fishing) " .. (CatchDB.focus and "on." or "off."))
    elseif cmd == "bar reset" then
        ns.CastBar.reset()
        print_("cast bar back in the middle.")
    elseif cmd == "sound off" or cmd == "sound on" then
        CatchDB.sound = cmd == "sound on"
        print_("sounds " .. (CatchDB.sound and "on." or "off."))
    elseif cmd == "sound test" then
        local i = 0
        for _, which in ipairs({ "lands", "wait", "window" }) do
            C_Timer.After(i * 1.5, function() print_("sound: " .. which) ns.CastBar.play(which) end)
            i = i + 1
        end
    elseif cmd == "sound browse" or cmd:match("^sound browse %d+$") then
        local list = ns.CastBar.candidates()
        local page = tonumber(cmd:match("(%d+)$")) or 1
        if #list == 0 then print_("no fishing-like sounds found in SOUNDKIT.") return end
        print_(("%d sounds (page %d): /catch sound try <n> to hear one, /catch sound wait <n> to use it"):format(#list, page))
        for i = (page - 1) * 15 + 1, math.min(#list, page * 15) do print_(("  %d  %s"):format(i, list[i].name)) end
        if #list > page * 15 then print_(("  … /catch sound browse %d"):format(page + 1)) end
    elseif cmd:match("^sound try %d+$") then
        local list = ns.CastBar.candidates()
        local e = list[tonumber(cmd:match("(%d+)$"))]
        if e then print_(("playing %s"):format(e.name)) ns.CastBar.playId(e.id) end
    elseif cmd:match("^sound %a+ %d+$") then
        local which, id = cmd:match("^sound (%a+) (%d+)$")
        id = tonumber(id)
        if which == "wait" and id == 0 then CatchDB.waitOff = true print_("no sound while waiting.") return end
        local list = ns.CastBar.candidates()
        if id >= 1 and id <= #list then id = list[id].id end
        CatchDB.waitOff = nil
        CatchDB.sounds = CatchDB.sounds or {}
        CatchDB.sounds[which] = id
        ns.CastBar.play(which)
        print_(("sound '%s' is now %s."):format(which, id))
    elseif cmd == "map" then
        if ns.Map then print_("map markers " .. (ns.Map.toggle() and "on." or "off.")) end
    elseif cmd == "debug" then
        local rank, maxRank, bonus = skill()
        local map, sub, zone = here()
        local w, base = water()
        print_(("focus: %s, %d frames faded"):format(ns.Focus and ns.Focus.active() and "on" or "off", ns.Focus and ns.Focus.count() or 0))
        print_(("v%s · skill %s/%s +%s · map %s · %s / %s · table %s · base %s · casts %d · catches %d · got away %d · ran out %d · bites %d · spots %d"):format(
            VERSION, tostring(rank), tostring(maxRank), tostring(bonus), tostring(map), zone, sub, w and "yes" or "no",
            tostring(base), session.casts, session.catches, session.escaped or 0, session.missed or 0, #char.bites, #char.spots))
    else
        print_("/catch (panel) · reset · map · focus · bar reset · sound test|on|off|browse|try <n>|<lands|wait|window> <n or id> (wait 0 = silent) · debug")
    end
end
