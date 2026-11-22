-- Catch's quotes: while you fish, a quiet line drifts in above the water every few minutes (the first a little after
-- you start) and on fish-count milestones, and fades. Campfire wisdom from Azeroth's shores, written for Catch.
local _, ns = ...
local Quotes = {}
ns.Quotes = Quotes

local SERIF = "Fonts\\MORPHEUS.TTF"
local FIRST, EVERY_MIN, EVERY_MAX = 45, 180, 240     -- seconds
local frame
local nextAt
local bag = {}                                        -- unused quotes this session, shuffled

local QUOTES = {
    { "The water keeps no ledger. You do, and that is fine.", "a goblin dockhand" },
    { "Even warlocks rest their hands.", "an old angler" },
    { "Cast, wait, breathe. The rest is the tide's business.", "a tauren elder" },
    { "Every ripple is the world saying it is still here.", "a night elf sentinel" },
    { "No dragon was ever slain by hurrying.", "a weary adventurer" },
    { "The fish do not care for your titles. That is the gift.", "an old angler" },
    { "Somewhere a raid is wiping. Here, only the line moves.", "a retired healer" },
    { "Patience is a spell anyone can learn.", "a quiet mage" },
    { "Sit long enough by water and you hear the world's heartbeat.", "a tauren elder" },
    { "The best loot does not drop. It surfaces.", "a Steamwheedle fisher" },
    { "The sun sets the same on Horde and Alliance docks.", "a wandering bard" },
    { "Let the line carry what the day left on your shoulders.", "an old angler" },
    { "Gold is a fine thing. A calm evening is finer.", "a goblin, oddly" },
    { "The sea gives slowly, and it gives to those who stay.", "a Booty Bay sailor" },
    { "Between casts there is a small silence. Keep it.", "a priestess of the moon" },
    { "Rivers were here before the Legion came, and will be after.", "a druid of the claw" },
    { "A good evening is measured in sunsets, not in kills.", "a weary adventurer" },
    { "The bobber knows before you do. Watch it kindly.", "an old angler" },
    { "No quest log out here. Only water, and you.", "a wandering bard" },
    { "Rest is not the end of the hunt. It is its root.", "a hunter by the fire" },
    { "Tide in, tide out. Breathe in, breathe out.", "a tauren elder" },
    { "Even the Earthmother fishes, in her way. She calls it rain.", "a tauren elder" },
    { "When the world is loud, the shore is its quiet corner.", "a night elf sentinel" },
    { "Count the fish if you like. Count the stars too.", "a stargazer on the pier" },
    { "The lake has waited ten thousand years. It can wait for your cast.", "a druid of the claw" },
    { "Some catches are fish. Some are moments.", "an old angler" },
    { "A full creel and a quiet mind: the only set worth farming.", "a Steamwheedle fisher" },
    { "Let the water hold your thoughts awhile. It has room.", "a priestess of the moon" },
    { "Not every adventure needs a sword. Some need only a line.", "a weary adventurer" },
    { "The dock creaks, the gulls cry, the line sings. That is the song.", "a wandering bard" },
    { "Fortune favours the patient, and the patient rarely notice.", "a goblin dockhand" },
    { "The tide does not hurry, yet it reaches every shore.", "a Kul Tiran sailor" },
    { "A warm fire, a cold drink, a fish on the line. Enough.", "an innkeeper" },
    { "The world will need saving again tomorrow. Tonight, it needs nothing.", "a weary adventurer" },
}

local MILESTONES = {
    [10] = "Ten fish. The water has noticed you.",
    [25] = "Twenty-five. Your hands have found the rhythm.",
    [50] = "Fifty fish. The old anglers would nod at you.",
    [100] = "A hundred fish. Somewhere, a tavern will hear of this.",
}

local function build()
    frame = CreateFrame("Frame", "CatchQuote", UIParent)
    frame:SetSize(620, 60)
    frame:SetFrameStrata("LOW")
    frame:SetPoint("BOTTOM", CatchCastBar, "TOP", 0, 150)
    frame.text = frame:CreateFontString(nil, "OVERLAY")
    frame.text:SetFont(SERIF, 22, "")
    frame.text:SetShadowOffset(1, -1)
    frame.text:SetShadowColor(0, 0, 0, 0.9)
    frame.text:SetTextColor(1, 0.93, 0.80)
    frame.text:SetPoint("TOP")
    frame.text:SetWidth(620)
    frame.by = frame:CreateFontString(nil, "OVERLAY")
    frame.by:SetFont(SERIF, 14, "")
    frame.by:SetShadowOffset(1, -1)
    frame.by:SetTextColor(0.72, 0.64, 0.52)
    frame.by:SetPoint("TOPRIGHT", frame.text, "BOTTOMRIGHT", -40, -6)
    local g = frame:CreateAnimationGroup()
    local a1 = g:CreateAnimation("Alpha") a1:SetFromAlpha(0) a1:SetToAlpha(1) a1:SetDuration(2.2) a1:SetSmoothing("IN_OUT")
    local drift = g:CreateAnimation("Translation") drift:SetOffset(0, 10) drift:SetDuration(11.5)
    local a2 = g:CreateAnimation("Alpha")
    a2:SetFromAlpha(1) a2:SetToAlpha(0) a2:SetStartDelay(9) a2:SetDuration(2.5) a2:SetSmoothing("IN_OUT")
    g:SetScript("OnFinished", function() frame:Hide() end)
    frame.anim = g
    frame:Hide()
end

local function say(text, by)
    if not frame then return end
    frame.text:SetText("“" .. text .. "”")
    frame.by:SetText(by and ("— " .. by) or "")
    frame.anim:Stop()
    frame:Show()
    frame.anim:Play()
end

local function draw()
    if #bag == 0 then
        for i = 1, #QUOTES do bag[i] = i end
        for i = #bag, 2, -1 do local j = math.random(i) bag[i], bag[j] = bag[j], bag[i] end
    end
    local q = QUOTES[table.remove(bag)]
    return q[1], q[2]
end

function Quotes.build() if CatchCastBar then build() end end

function Quotes.milestone(n)
    say(MILESTONES[n] or ("%d fish. The tide and you are old friends now."):format(n), nil)
    nextAt = GetTime() + math.random(EVERY_MIN, EVERY_MAX)
end

-- Every second (Catch.lua's tick).
function Quotes.tick()
    if not frame or CatchDB.quotes == false then return end
    if not ns.C.fishingNow() then
        nextAt = nil
        if frame:IsShown() and not frame.anim:IsPlaying() then frame:Hide() end
        return
    end
    local now = GetTime()
    if not nextAt then nextAt = now + FIRST end
    if now >= nextAt then
        say(draw())
        nextAt = now + math.random(EVERY_MIN, EVERY_MAX)
    end
end
