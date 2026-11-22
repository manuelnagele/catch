-- Catch's creel: every catch rises out of the water as a card (its icon in a ring of its quality, name, count, worth),
-- a rare or valuable one with sparkles and a rising kalimba, a session best with a banner. Under the cast bar while you
-- fish: the creel, your fish count and the session's worth counting up, and the last catches as small icons.
local _, ns = ...
local Core = ns.Core
local Creel = {}
ns.Creel = Creel

local K, P
local card, creel
local TEX = "Interface\\AddOns\\Catch\\Textures\\"
local SOUND = "Interface\\AddOns\\Catch\\Sounds\\"
local SERIF = "Fonts\\MORPHEUS.TTF"
local CREAM = { 1, 0.93, 0.80 }
local RECENT = 8
local before                         -- the session's summary before the latest catch
local shown = { worth = 0, target = 0, from = 0, at = 0 }

local function quality(id)
    local q = C_Item and C_Item.GetItemQualityByID and C_Item.GetItemQualityByID(id)
    return type(q) == "number" and q or 1
end

local function qualityColor(q)
    local c = ITEM_QUALITY_COLORS and ITEM_QUALITY_COLORS[q]
    if c then return { c.r, c.g, c.b } end
    return { 0.9, 0.9, 0.9 }
end

local function icon(id)
    return (C_Item and C_Item.GetItemIconByID and C_Item.GetItemIconByID(id)) or "Interface\\Icons\\INV_Misc_Fish_02"
end

local function roundIcon(parent, size, drawLayer)
    local t = parent:CreateTexture(nil, drawLayer or "ARTWORK")
    t:SetSize(size, size)
    if parent.CreateMaskTexture then
        local mask = parent:CreateMaskTexture()
        mask:SetTexture("Interface\\CharacterFrame\\TempPortraitAlphaMask", "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
        mask:SetAllPoints(t)
        t:AddMaskTexture(mask)
    end
    return t
end

local function tex(parent, file, drawLayer, sub)
    local t = parent:CreateTexture(nil, drawLayer, nil, sub)
    t:SetTexture(TEX .. file)
    return t
end

-- --- the card ------------------------------------------------------------------------------

local SPARKS = 7
local RISE_FROM, RISE, RISE_TIME = 26, 34, 3.6

local function buildCard()
    card = CreateFrame("Frame", "CatchCard", UIParent)
    card:SetSize(360, 64)
    card:SetFrameStrata("MEDIUM")
    card:SetPoint("BOTTOM", CatchCastBar, "TOP", 0, 26)

    card.glow = tex(card, "glow", "BACKGROUND")
    card.glow:SetSize(120, 120)
    card.glow:SetBlendMode("ADD")
    card.shade = tex(card, "glow", "BACKGROUND", -1)      -- a soft dark pool behind the words
    card.shade:SetSize(420, 110)
    card.shade:SetPoint("CENTER", 20, 0)
    card.shade:SetVertexColor(0, 0, 0, 0.55)
    card.icon = roundIcon(card, 44)
    card.icon:SetPoint("LEFT", 8, 0)
    card.glow:SetPoint("CENTER", card.icon)
    card.ring = tex(card, "ring", "ARTWORK", 2)
    card.ring:SetSize(54, 54)
    card.ring:SetPoint("CENTER", card.icon)

    card.banner = card:CreateFontString(nil, "OVERLAY")
    card.banner:SetFont(SERIF, 14, "")
    card.banner:SetShadowOffset(1, -1)
    card.banner:SetPoint("BOTTOMLEFT", card.icon, "TOPRIGHT", 8, -10)
    card.banner:SetTextColor(P.goldOn[1], P.goldOn[2], P.goldOn[3])
    card.name = card:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    card.name:SetShadowOffset(1, -1)
    card.name:SetPoint("LEFT", card.icon, "RIGHT", 12, 9)
    card.value = card:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    card.value:SetShadowOffset(1, -1)
    card.value:SetPoint("TOPLEFT", card.name, "BOTTOMLEFT", 0, -4)

    -- sparkles for a rare one: small glints drifting up around the icon
    card.sparks = {}
    for i = 1, SPARKS do
        local s = tex(card, "glow", "OVERLAY")
        s:SetSize(10, 10)
        s:SetBlendMode("ADD")
        s:SetAlpha(0)
        local g = s:CreateAnimationGroup()
        local a1 = g:CreateAnimation("Alpha") a1:SetFromAlpha(0) a1:SetToAlpha(1) a1:SetDuration(0.3) a1:SetOrder(1)
        local mv = g:CreateAnimation("Translation") mv:SetDuration(1.6) mv:SetSmoothing("OUT") mv:SetOrder(2)
        local a2 = g:CreateAnimation("Alpha") a2:SetFromAlpha(1) a2:SetToAlpha(0) a2:SetDuration(1.6) a2:SetOrder(2)
        s.move, s.anim = mv, g
        card.sparks[i] = s
    end

    -- the rise: in quick, up slowly, out soft. The rise moves the anchor itself: a Translation animation leaves the
    -- coin icons inside the text behind (they stayed put while the numbers rose, 0.6.0).
    local g = card:CreateAnimationGroup()
    local fadeIn = g:CreateAnimation("Alpha") fadeIn:SetFromAlpha(0) fadeIn:SetToAlpha(1) fadeIn:SetDuration(0.25)
    card:SetScript("OnUpdate", function(self)
        local p = math.min(1, (GetTime() - (self.started or 0)) / RISE_TIME)
        self:SetPoint("BOTTOM", CatchCastBar, "TOP", 0, RISE_FROM + RISE * (1 - (1 - p) ^ 3))
    end)
    local fadeOut = g:CreateAnimation("Alpha")
    fadeOut:SetFromAlpha(1) fadeOut:SetToAlpha(0) fadeOut:SetStartDelay(2.8) fadeOut:SetDuration(0.8)
    g:SetScript("OnFinished", function() card:Hide() end)
    card.rise = g
    card:Hide()
end

local function showCard(id, count, value, moment)
    local link = ns.C.link(id)
    local name = link and link:match("%[(.-)%]") or ("item " .. id)
    local q = quality(id)
    local qc = qualityColor(q)
    card.icon:SetTexture(icon(id))
    card.ring:SetVertexColor(qc[1], qc[2], qc[3], 0.95)
    card.name:SetText(name .. (count > 1 and ("  |cffd8c9a8×%d|r"):format(count) or ""))
    card.name:SetTextColor(qc[1], qc[2], qc[3])
    card.value:SetText(value > 0 and ("|cff8fd18f+|r " .. K.coins(value, 14)) or "|cff8f8275vendor trash, still a fish|r")
    local special = moment ~= "plain"
    card.glow:SetVertexColor(qc[1], qc[2], qc[3], special and 0.9 or 0.45)
    card.glow:SetSize(special and 150 or 100, special and 150 or 100)
    card.banner:SetText(moment == "best" and "best catch this session" or (moment == "rare" and "a fine catch" or ""))
    for i, s in ipairs(card.sparks) do
        s:ClearAllPoints()
        s:SetPoint("CENTER", card.icon, "CENTER", math.random(-26, 26), math.random(-18, 10))
        if special then
            s:SetVertexColor(1, 0.85 + 0.15 * math.random(), 0.55)
            s.move:SetOffset(math.random(-14, 14), math.random(24, 52))
            s.anim:Stop()
            C_Timer.After(0.08 * i, function() s.anim:Play() end)
        end
    end
    card.rise:Stop()
    card.started = GetTime()
    card:SetPoint("BOTTOM", CatchCastBar, "TOP", 0, RISE_FROM)
    card:Show()
    card.rise:Play()
    if CatchDB.sound ~= false then
        pcall(PlaySoundFile, SOUND .. (special and "catch_rare.ogg" or "catch_soft.ogg"), "SFX")
    end
end

-- --- the creel under the bar --------------------------------------------------------------------

local function buildCreel()
    creel = CreateFrame("Frame", "CatchCreel", UIParent)
    creel:SetSize(440, 28)
    creel:SetFrameStrata("MEDIUM")
    creel:SetPoint("TOP", CatchCastBar, "BOTTOM", 0, -12)
    creel.basket = roundIcon(creel, 24)
    creel.basket:SetPoint("LEFT", 6, 0)
    creel.basket:SetTexture("Interface\\Icons\\INV_Misc_Fish_02")
    creel.basketRing = tex(creel, "ring", "ARTWORK", 2)
    creel.basketRing:SetSize(30, 30)
    creel.basketRing:SetPoint("CENTER", creel.basket)
    creel.basketRing:SetVertexColor(P.bronze4[1], P.bronze4[2], P.bronze4[3], 0.9)
    creel.count = creel:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    creel.count:SetShadowOffset(1, -1)
    creel.count:SetTextColor(CREAM[1], CREAM[2], CREAM[3])
    creel.count:SetPoint("LEFT", creel.basket, "RIGHT", 10, 0)
    creel.worth = creel:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    creel.worth:SetShadowOffset(1, -1)
    creel.worth:SetPoint("LEFT", creel.count, "RIGHT", 12, 0)
    creel.recent = {}
    for i = 1, RECENT do
        local t = roundIcon(creel, 18)
        t:SetPoint("RIGHT", creel, "RIGHT", -6 - (i - 1) * 24, 0)
        local ring = tex(creel, "ring", "ARTWORK", 2)
        ring:SetSize(23, 23)
        ring:SetPoint("CENTER", t)
        t.ring = ring
        local g = t:CreateAnimationGroup()
        local a = g:CreateAnimation("Alpha") a:SetFromAlpha(0) a:SetToAlpha(1) a:SetDuration(0.6)
        t.fadeIn = g
        creel.recent[i] = t
    end
    creel:SetScript("OnUpdate", function()
        if shown.worth == shown.target then return end
        local p = math.min(1, (GetTime() - shown.at) / 1.4)
        p = 1 - (1 - p) ^ 3                                  -- ease out
        shown.worth = p >= 1 and shown.target or math.floor(shown.from + (shown.target - shown.from) * p)
        creel.worth:SetText(K.coins(shown.worth, 14))
    end)
    creel:Hide()
end

local function fishCount(sum)
    local n = 0
    for _, f in ipairs(sum.fish) do n = n + f.count end
    return n
end

local function drawCreel(sum, animate)
    local n = fishCount(sum)
    creel.count:SetText(("%d |cffb8a98ffish|r"):format(n))
    if animate then
        shown.from, shown.target, shown.at = shown.worth, sum.total, GetTime()
    else
        shown.worth, shown.target = sum.total, sum.total
        creel.worth:SetText(K.coins(sum.total, 14))
    end
    local log = ns.C.session().log
    for i, t in ipairs(creel.recent) do
        local e = log[#log - i + 1]
        if e then
            local qc = qualityColor(quality(e.id))
            t:SetTexture(icon(e.id))
            t.ring:SetVertexColor(qc[1], qc[2], qc[3], 0.9)
            t:Show() t.ring:Show()
            t:SetAlpha(1 - (i - 1) * 0.08)                   -- older ones a little fainter
        else
            t:Hide() t.ring:Hide()
        end
    end
    if animate then creel.recent[1].fadeIn:Play() end
    return n
end

-- --- from Catch.lua ---------------------------------------------------------------------------

function Creel.build()
    if not (Deadbeat and CatchCastBar) then return end
    K, P = Deadbeat.kit, Deadbeat.kit.P
    buildCard()
    buildCreel()
end

function Creel.onCatch(id, count, value)
    if not card then return end
    local sum = ns.C.summary()
    local prev = before or { best = 0, mean = 0, catches = 0, fish = {} }
    local moment = Core.catchMoment(value or 0, quality(id), prev.best, prev.mean, prev.catches)
    showCard(id, count or 1, value or 0, moment)
    local n = drawCreel(sum, true)
    local m = Core.milestone(fishCount(prev), n)
    if m and ns.Quotes then ns.Quotes.milestone(m) end
    before = sum
    creel:Show()
end

-- Every second: the creel is there while you fish.
function Creel.tick()
    if not creel then return end
    local fishing = ns.C.fishingNow()
    if fishing and not creel:IsShown() then
        before = ns.C.summary()
        drawCreel(before, false)
        creel:Show()
    elseif not fishing and creel:IsShown() then
        creel:Hide()
    end
end
