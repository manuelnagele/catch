-- luajit tests/smoke.lua: Catch on Deadbeat (sibling repo) on the shared harness (deadbeat-spec), one fishing session.
local W = dofile(os.getenv("HARNESS") or "../deadbeat-spec/harness/wowstub.lua")   -- the shared harness
W.loadDeadbeat(os.getenv("DEADBEAT") or "../deadbeat")

-- what Catch needs beyond the shared stub
C_Spell = { GetSpellName = function(id) return (id == 7620 or id == 131474) and "Fishing" or nil end }
C_Map = {
    GetBestMapForUnit = function() return 1449 end,
    GetPlayerMapPosition = function() return { GetXY = function() return 0.42, 0.61 end } end,
    GetMapInfo = function() return { name = "Un'Goro Crater" } end,
}
function GetSubZoneText() return "Lakkari Tar Pits" end
function GetZoneText() return "Un'Goro Crater" end
function UnitChannelInfo() return "Fishing", nil, nil, 1000, 21000 end
function GetProfessions() return nil, nil, nil, 3 end
function GetProfessionInfo() return "Fishing", nil, 272, 300, nil, nil, nil, 25 end
function hooksecurefunc(t, k, fn) local o = t[k] t[k] = function(...) local r = o and o(...) fn(...) return r end end
local fishy = true
function IsFishingLoot() return fishy end
function GetLootSourceInfo() return "GameObject-0-4170-1-123-180683-0000AB" end   -- a pool, not the bobber
local mapShown = 1449
WorldMapFrame = CreateFrame("Frame", "WorldMapFrame")
rawset(WorldMapFrame, "GetMapID", function() return mapShown end)
rawset(WorldMapFrame, "GetCanvas", function() return CreateFrame("Frame", "Canvas") end)
rawset(WorldMapFrame, "OnMapChanged", function() end)
local toggles = {}
OpenMapAPI = {
    IsStitched = function() return false end,
    ArtTopLevel = function() return 5 end,
    RegisterCallback = function() end,
    RegisterMenuToggle = function(owner, spec) toggles[#toggles + 1] = spec end,
}
LOOT_ITEM_SELF = "You receive loot: %s."
LOOT_ITEM_SELF_MULTIPLE = "You receive loot: %sx%d."
ForeverMarketPrices = { updated = os.time(), c = { [13422] = 3000, [13759] = 900 }, g = {} }

local ns = {}
local played = {}
function PlaySound(id) played[#played + 1] = id end
function PlaySoundFile(path) played[#played + 1] = path return true, #played end
function StopSound() end
function InCombatLockdown() return false end
local lureLeft = 300000
local overrides = {}
function ClearOverrideBindings() overrides = {} end
function SetOverrideBinding(_, _, key, action) overrides[key] = action end
function SetOverrideBindingClick(_, _, key, name) overrides[key] = "CLICK " .. name end
local macros = {}
function GetMacroIndexByName(name) for i, m in ipairs(macros) do if m.name == name then return i end end return 0 end
function GetNumMacros() return #macros end
function GetMacroBody(i) return macros[i].body end
function CreateMacro(name, _, body) macros[#macros + 1] = { name = name, body = body } end
function EditMacro(i, _, _, body) macros[i].body = body end
function GetWeaponEnchantInfo() return lureLeft ~= nil, lureLeft end
C_Container = {
    GetContainerNumSlots = function(bag) return bag == 0 and 3 or 0 end,
    GetContainerItemID = function(_, slot) return ({ 6529, 6532, 6256 })[slot] end,
}
local mainHand = 6256                                           -- the pole, until the test puts a sword on
function GetInventoryItemID(_, slot) return slot == 16 and mainHand or nil end
C_Item.GetItemInfoInstant = function(id) return id, nil, nil, nil, nil, 2, id == 6256 and 20 or 7 end
local faded = CreateFrame("Frame", "FlareUI_ActionBar1", UIParent)
rawset(faded, "IsShown", function() return true end)
rawset(faded, "IsForbidden", function() return false end)
rawset(faded, "GetAlpha", function() return 1 end)
local alphaSet
rawset(faded, "SetAlpha", function(_, a) alphaSet = a end)
rawset(faded, "GetName", function() return "FlareUI_ActionBar1" end)
rawset(DeadbeatBar, "GetName", function() return "DeadbeatBar" end)
rawset(UIParent, "GetChildren", function() return faded, DeadbeatBar end)
for _, f in ipairs({ "Catch/Core.lua", "Catch/Data.lua", "Catch/FishDB.lua", "Catch/Catch.lua", "Catch/Panel.lua",
                     "Catch/CastBar.lua", "Catch/Lure.lua", "Catch/OneButton.lua", "Catch/Creel.lua", "Catch/Quotes.lua", "Catch/Focus.lua", "Catch/Map.lua" }) do
    assert(loadfile(f))("Catch", ns)
end
local ev = W.frames[#W.frames - 0]
-- Catch.lua's event frame: the one that knows CHAT_MSG_LOOT; find it by firing ADDON_LOADED on all
for _, fr in ipairs(W.frames) do fr:_fire("ADDON_LOADED", "Catch") end
for _, fr in ipairs(W.frames) do fr:_fire("PLAYER_LOGIN") end
assert(CatchPanel and CatchWaters, "panel and waters panel built")
assert(CatchCard and CatchCreel and CatchQuote, "catch card, creel and quotes built")
local said, creelCount = {}, nil
rawset(CatchQuote.text, "SetText", function(_, t) said[#said + 1] = t end)
rawset(CatchCreel.count, "SetText", function(_, t) creelCount = t end)
assert(#toggles == 1 and toggles[1].id == "hotspots", "OpenMap menu toggle registered")

for cast = 1, 10 do
    for _, fr in ipairs(W.frames) do fr:_fire("UNIT_SPELLCAST_CHANNEL_START", "player", "c" .. cast, 131474) end
    for _, fr in ipairs(W.frames) do fr:_fire("LOOT_READY") end
    for _, fr in ipairs(W.frames) do
        fr:_fire("CHAT_MSG_LOOT", "You receive loot: |cffffffff|Hitem:13422::::::::60:::::|h[Stonescale Eel]|h|r.")
    end
    for _, fr in ipairs(W.frames) do fr:_fire("LOOT_CLOSED") end
    for _, fr in ipairs(W.frames) do fr:_fire("UNIT_SPELLCAST_CHANNEL_STOP", "player") end
end
assert(CatchCastBar, "big cast bar built")
assert(said[1] and said[1]:find("Ten fish"), "milestone quote at 10 fish: " .. tostring(said[1]))
assert(creelCount and creelCount:find("^10 "), "creel counts 10 fish: " .. tostring(creelCount))
assert(CatchLureButton, "lure button built")
local attrs = {}
rawset(CatchLureButton, "SetAttribute", function(_, k, v) attrs[k] = v end)
for _, fr in ipairs(W.frames) do fr:_fire("BAG_UPDATE_DELAYED") end
assert(attrs.type == "item" and attrs.item == "item:6532" and attrs["target-slot"] == 16,
    "best lure onto slot 16: " .. tostring(attrs.item))
assert(#macros == 1 and macros[1].name == "Catch Lure" and macros[1].body == "#showtooltip\n/use item:6532\n/use 16",
    "the Catch Lure macro kept up to date")
for _, t in ipairs(W.tickers) do t() end
lureLeft = nil
for _, t in ipairs(W.tickers) do t() end
CatchLureButton:_script("OnEnter")
lureLeft = 300000
-- one more cast, left hanging: the bar runs, sounds fire, the UI fades
for _, fr in ipairs(W.frames) do fr:_fire("UNIT_SPELLCAST_CHANNEL_START", "player", "c-last", 131474) end
local clock = os.clock
GetTime = function() return clock() + 20 end      -- 20 s into the cast
CatchCastBar:_script("OnUpdate", 0.1)
local joinedSounds = table.concat((function() local t = {} for i, v in ipairs(played) do t[i] = tostring(v) end return t end)(), " ")
assert(joinedSounds:find("lands_plop.ogg") and joinedSounds:find("window_pluck.ogg"), "cozy plop + pluck: " .. joinedSounds)
assert(joinedSounds:find("catch_soft.ogg"), "a soft note on every catch")
local faded = false
CatchCastBar.fadeOut = { Play = function() faded = true end, Stop = function() end, IsPlaying = function() end }
for _, fr in ipairs(W.frames) do fr:_fire("UNIT_SPELLCAST_CHANNEL_STOP", "player") end
assert(faded, "the cast bar leaves when the cast ends")
-- one button: set F and PAD1 in the window; no lure on -> lure, then cast; while channelling -> interact
CatchDB.oneButton = { key = "F", pad = "PAD1" }
lureLeft = nil
local fishAttrs = {}
rawset(CatchFishButton, "SetAttribute", function(_, k, v) fishAttrs[k] = v end)
for _, t in ipairs(W.tickers) do t() end
for _, fr in ipairs(W.frames) do fr:_fire("BAG_UPDATE_DELAYED") end
assert(overrides.F == "CLICK CatchFishButton" and overrides.PAD1 == "CLICK CatchFishButton", "keys bound to the button")
assert(fishAttrs.type == "item" and fishAttrs.item == "item:6532", "first press: the lure")
lureLeft = 300000
for _, t in ipairs(W.tickers) do t() end
assert(fishAttrs.type == "macro" and fishAttrs.macrotext:find("/cast Fishing"), "with a lure on: cast")
mainHand = 2000                                                  -- a sword in hand
for _, t in ipairs(W.tickers) do t() end
assert(fishAttrs.type == "macro" and fishAttrs.macrotext == "/equipslot 16 Item6256", "holding a sword: the pole first")
mainHand = 6256
for _, t in ipairs(W.tickers) do t() end
for _, fr in ipairs(W.frames) do fr:_fire("UNIT_SPELLCAST_CHANNEL_START", "player", "c-ob", 131474) end
assert(overrides.F == "INTERACTTARGET" and overrides.PAD1 == "INTERACTTARGET", "bobber out: reel in")
for _, fr in ipairs(W.frames) do fr:_fire("UNIT_SPELLCAST_CHANNEL_STOP", "player") end
assert(overrides.F == "CLICK CatchFishButton", "back to casting")
SlashCmdList.CATCH("keys")
assert(DeadbeatSettings, "keys on the settings console")
-- done fishing: B on the pad while you fish; the sword and shield go back on
CatchDB.oneButton.exitPad = "PAD2"
local doneAttrs = {}
rawset(CatchDoneButton, "SetAttribute", function(_, k, v) doneAttrs[k] = v end)
mainHand = 2000
local offHand = 3000
local getInv = GetInventoryItemID
function GetInventoryItemID(_, slot) if slot == 17 then return offHand end return getInv(_, slot) end
for _, t in ipairs(W.tickers) do t() end
mainHand = 6256
for _, fr in ipairs(W.frames) do fr:_fire("UNIT_SPELLCAST_CHANNEL_START", "player", "c-done", 131474) end
assert(overrides.PAD2 == "CLICK CatchDoneButton", "exit button bound while fishing")
assert(doneAttrs.macrotext == "/stopcasting\n/equipslot 16 Item2000\n/equipslot 17 Item3000",
    "weapons back: " .. tostring(doneAttrs.macrotext))
CatchDoneButton:_script("PreClick")
for _, t in ipairs(W.tickers) do t() end
assert(overrides.PAD2 == nil, "exit key released when you're done")
CatchDB.chars["Player-1-ABC"].session.doneAt = nil                  -- back to fishing for the rest
for _, fr in ipairs(W.frames) do fr:_fire("UNIT_SPELLCAST_CHANNEL_START", "player", "c-again", 131474) end
for _, d in ipairs(W.frames) do d:_script("OnUpdate", 1) end   -- run the fade
assert(alphaSet == 0, "other UI faded, got " .. tostring(alphaSet))
for _, fr in ipairs(W.frames) do fr:_fire("PLAYER_STARTED_MOVING") end
for _, d in ipairs(W.frames) do d:_script("OnUpdate", 1) end
assert(alphaSet == 1, "UI back after moving, got " .. tostring(alphaSet))
for _, t in ipairs(W.tickers) do t() end
assert(table.concat((function() local t = {} for i, v in ipairs(played) do t[i] = tostring(v) end return t end)(), " "):find("ambience_lake.ogg"), "ambience started while fishing")
CatchPanel:_script("OnEnter")
WorldMapFrame:_script("OnShow")
SlashCmdList.CATCH("debug")
SlashCmdList.CATCH("map")
SlashCmdList.CATCH("map")
SlashCmdList.CATCH("")
SlashCmdList.CATCH("focus")
SlashCmdList.CATCH("focus")
SlashCmdList.CATCH("sound test")
SlashCmdList.CATCH("sound wait 3407")
SOUNDKIT = { FISHING_REEL_IN = 3407, UI_BOBBER_SPLASH = 9000, RAID_WARNING = 8959 }
SlashCmdList.CATCH("sound browse")
SlashCmdList.CATCH("sound try 1")
SlashCmdList.CATCH("sound wait 4")
assert(CatchDB.sounds.wait:find("wait_lap.ogg"), "picked Catch's own water lap: " .. tostring(CatchDB.sounds.wait))
SlashCmdList.CATCH("sound wait 12")
assert(CatchDB.sounds.wait == 9000, "picked a game sound after the nine of Catch's own")
SlashCmdList.CATCH("sound wait 0")
assert(CatchDB.waitOff, "wait 0 = silent")
SlashCmdList.CATCH("bar reset")
UISpecialFrames = UISpecialFrames or {}
tinsert = tinsert or table.insert
CatchCastBar:_script("OnMouseUp", "RightButton")
assert(CatchSounds, "sound picker opens on right-click")
local char = CatchDB.chars["Player-1-ABC"]
assert(char.session.casts == 14 and char.session.catches == 10 and #char.session.log == 10, "10 casts, 10 catches")
assert(#char.spots == 10 and char.spots[1].pool and char.spots[1].sub == "Lakkari Tar Pits", "spots with pool + subzone")
assert(#char.bites == 10, "bite times recorded")
local function item(id) for _, it in ipairs(Deadbeat.Items()) do if it.key == "Catch." .. id then return it end end end
for _, t in ipairs(W.tickers) do t() end
assert(item("take") and item("take").wanted and item("take").value ~= "", "the take item while fishing")
assert(item("skill") and item("skill").value == "297", "skill 272 + 25: " .. tostring(item("skill").value))
for i = #W.tipLines, 1, -1 do W.tipLines[i] = nil end
local tip = W.tooltip(item("take"))
assert(tip:find("Fishing · Lakkari Tar Pits") and tip:find("What bites here"), "the take's tooltip: " .. tip)
item("take").frame:_script("OnClick", "LeftButton")                     -- toggles the panel
-- without a price addon: every value is the vendor price (public installs)
ForeverMarketPrices = nil
local cardValue
rawset(CatchCard.value, "SetText", function(_, t) cardValue = t end)
for _, fr in ipairs(W.frames) do fr:_fire("UNIT_SPELLCAST_CHANNEL_START", "player", "c-vendor", 131474) end
for _, fr in ipairs(W.frames) do fr:_fire("LOOT_READY") end
for _, fr in ipairs(W.frames) do
    fr:_fire("CHAT_MSG_LOOT", "You receive loot: |cffffffff|Hitem:13422::::::::60:::::|h[Stonescale Eel]|h|r.")
end
assert(cardValue and cardValue:find("150c"), "vendor value on the card without a price addon: " .. tostring(cardValue))
print("catch smoke ok")
