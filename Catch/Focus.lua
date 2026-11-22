-- Catch's focus mode: while you fish out of combat, the interface fades away except what you fish with: the big
-- cast bar, Deadbeat's bar, Catch's panel, chat, the minimap (and loot, popups, tooltips, error messages). It comes
-- back when combat starts, when you move, or 2 minutes after your last cast.
--
-- Fading, not hiding: alpha may change at any time, even in combat; showing/hiding the protected UI may not. Frames
-- that open later (bags, map, loot) aren't touched. Faded frames still take clicks where they are.
local _, ns = ...
local Focus = {}
ns.Focus = Focus

local KEEP = { "^DeadbeatBar$", "^Catch", "^HaulToast$", "^ChatFrame", "^GeneralDockManager", "Minimap",
               "^LootFrame$", "^GroupLootFrame", "^StaticPopup", "Tooltip", "^UIErrorsFrame$", "^RaidWarningFrame$" }
local FADE_TIME = 0.4

local faded = {}                     -- frame -> original alpha
local active = false
local driver = CreateFrame("Frame")

local function keep(frame)
    local name = frame.GetName and frame:GetName()
    if not name then return false end
    for _, p in ipairs(KEEP) do if name:find(p) then return true end end
    return false
end

local function animate(to, done)
    local from, t = to == 0 and 1 or 0, 0
    driver:SetScript("OnUpdate", function(_, elapsed)
        t = math.min(1, t + elapsed / FADE_TIME)
        local a = from + (to - from) * t
        for frame, orig in pairs(faded) do pcall(frame.SetAlpha, frame, orig * a) end
        if t >= 1 then driver:SetScript("OnUpdate", nil) if done then done() end end
    end)
end

function Focus.enter()
    if active or CatchDB.focus == false or InCombatLockdown() then return end
    active = true
    faded = {}
    for _, frame in ipairs({ UIParent:GetChildren() }) do
        -- forbidden frames (store, protected dialogs) must not even be asked for their alpha
        if not (frame.IsForbidden and frame:IsForbidden()) then
            local ok, shown, alpha = pcall(function() return frame:IsShown(), frame:GetAlpha() end)
            if ok and shown and (alpha or 1) > 0 and not keep(frame) then faded[frame] = alpha or 1 end
        end
    end
    animate(0)
end

function Focus.leave()
    if not active then return end
    active = false
    animate(1, function()
        for frame, orig in pairs(faded) do pcall(frame.SetAlpha, frame, orig) end
        faded = {}
    end)
end

function Focus.active() return active end
function Focus.count() local n = 0 for _ in pairs(faded) do n = n + 1 end return n end

-- events: combat and movement bring it back; Catch.lua calls enter on a cast and checks idle in its tick
local events = CreateFrame("Frame")
events:RegisterEvent("PLAYER_REGEN_DISABLED")
events:RegisterEvent("PLAYER_STARTED_MOVING")
events:SetScript("OnEvent", function(_, event)
    if event == "PLAYER_REGEN_DISABLED" or event == "PLAYER_STARTED_MOVING" then Focus.leave() end
end)

function Focus.tick()
    if active and not ns.C.fishingNow() then Focus.leave() end
end
