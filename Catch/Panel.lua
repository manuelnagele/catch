-- Catch's fishing panel, docked under Deadbeat's bar: cast bar with your bite window, catch feed with value pops,
-- where the gold comes from (value share per fish), the live numbers and value per minute. Hover: the nerd numbers.
local _, ns = ...
local Core = ns.Core
local Panel = {}
ns.Panel = Panel

local K, P
local panel
local FEED, SLOT = 10, 24
local MINUTES = 30
local IDLE = 120
local WIDTH = 360
local POLE = "Interface\\Icons\\Trade_Fishing"
local SHARE_COLORS                -- top fish colours in the value-share bar

local function itemColor(id)
    local link = ns.C.link(id)
    local hexColor = link and link:match("|c(%x%x%x%x%x%x%x%x)")
    if hexColor then
        return tonumber(hexColor:sub(3, 4), 16) / 255, tonumber(hexColor:sub(5, 6), 16) / 255,
            tonumber(hexColor:sub(7, 8), 16) / 255
    end
    return 0.8, 0.8, 0.8
end

local function itemName(id)
    local link = ns.C.link(id)
    return (link and link:match("%[(.-)%]")) or C_Item.GetItemNameByID(id) or ("item " .. id)
end

-- --- building --------------------------------------------------------------------------

local function slot(parent, i)
    local f = CreateFrame("Frame", nil, parent, "BackdropTemplate")
    f:SetSize(SLOT, SLOT)
    f:SetPoint("LEFT", parent, "LEFT", (i - 1) * (SLOT + 4), 0)
    f:SetBackdrop({ edgeFile = "Interface\\Buttons\\WHITE8x8", edgeSize = 1 })
    f.icon = f:CreateTexture(nil, "ARTWORK")
    f.icon:SetPoint("TOPLEFT", 1, -1)
    f.icon:SetPoint("BOTTOMRIGHT", -1, 1)
    f.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    f.count = f:CreateFontString(nil, "OVERLAY", "NumberFontNormalSmall")
    f.count:SetPoint("BOTTOMRIGHT", -1, 1)
    local anim = f:CreateAnimationGroup()
    local move = anim:CreateAnimation("Translation")
    move:SetOffset(SLOT + 4, 0) move:SetDuration(0) move:SetOrder(1)
    local back = anim:CreateAnimation("Translation")
    back:SetOffset(-(SLOT + 4), 0) back:SetDuration(0.25) back:SetSmoothing("OUT") back:SetOrder(2)
    local fade = anim:CreateAnimation("Alpha")
    fade:SetFromAlpha(0) fade:SetToAlpha(1) fade:SetDuration(0.25) fade:SetOrder(2)
    f.slideIn = anim
    f:Hide()
    return f
end

local pops, nextPop = {}, 1
local function pop()
    local fs = panel:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    fs:SetPoint("BOTTOMRIGHT", panel, "TOPRIGHT", -12, 2)
    fs:SetAlpha(0)
    local anim = fs:CreateAnimationGroup()
    local fadeIn = anim:CreateAnimation("Alpha")
    fadeIn:SetFromAlpha(0) fadeIn:SetToAlpha(1) fadeIn:SetDuration(0.12) fadeIn:SetOrder(1)
    local rise = anim:CreateAnimation("Translation")
    rise:SetOffset(0, 34) rise:SetDuration(1.4) rise:SetSmoothing("OUT") rise:SetOrder(2)
    local fadeOut = anim:CreateAnimation("Alpha")
    fadeOut:SetFromAlpha(1) fadeOut:SetToAlpha(0) fadeOut:SetDuration(0.9) fadeOut:SetStartDelay(0.5) fadeOut:SetOrder(2)
    anim:SetScript("OnFinished", function() fs:SetAlpha(0) end)
    fs.anim = anim
    return fs
end

local function track(parent, height)
    local t = parent:CreateTexture(nil, "BACKGROUND")
    t:SetAllPoints()
    t:SetColorTexture(P.bronze1[1], P.bronze1[2], P.bronze1[3], 0.45)
    return t
end

function Panel.build(module)
    if not Deadbeat then return end
    K, P = Deadbeat.kit, Deadbeat.kit.P
    SHARE_COLORS = { P.goldOn, { K.soft(0.32, 0.60, 0.92) }, { K.soft(0.36, 0.78, 0.38) }, P.bronze4,
                     { K.soft(0.70, 0.46, 0.92) } }
    local bar = K.barTexture()
    panel = CreateFrame("Frame", "CatchPanel", UIParent)
    panel:SetSize(WIDTH, 136)
    K.ground(panel)
    K.border(panel, true)
    panel:EnableMouse(true)

    -- header: pole, "Fishing · Zone", g/h, fishing time
    panel.pole = panel:CreateTexture(nil, "ARTWORK")
    panel.pole:SetSize(16, 16)
    panel.pole:SetPoint("TOPLEFT", 9, -7)
    panel.pole:SetTexture(POLE)
    panel.pole:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    panel.title = K.text(panel, "GameFontNormalSmall", P.bronze4)
    panel.title:SetPoint("LEFT", panel.pole, "RIGHT", 6, 0)
    panel.clock = K.text(panel, "GameFontHighlightSmall", P.warmGrey)
    panel.clock:SetPoint("TOPRIGHT", -10, -9)
    panel.rate = K.text(panel, "GameFontHighlightSmall")
    panel.rate:SetPoint("RIGHT", panel.clock, "LEFT", -12, 0)

    -- catch feed
    panel.feed = CreateFrame("Frame", nil, panel)
    panel.feed:SetPoint("TOPLEFT", 9, -30)
    panel.feed:SetSize(FEED * (SLOT + 4), SLOT)
    panel.slots = {}
    for i = 1, FEED do panel.slots[i] = slot(panel.feed, i) end

    -- where the gold comes from: value share per fish + the top 3 named
    panel.share = CreateFrame("Frame", nil, panel)
    panel.share:SetPoint("TOPLEFT", 9, -62)
    panel.share:SetSize(WIDTH - 18, 6)
    track(panel.share)
    panel.share.segs = {}
    for i = 1, #SHARE_COLORS + 1 do
        local s = panel.share:CreateTexture(nil, "ARTWORK")
        s:SetTexture(bar)
        local c = SHARE_COLORS[i] or P.warmGrey
        s:SetVertexColor(c[1], c[2], c[3], 1)
        s:Hide()
        panel.share.segs[i] = s
    end
    panel.legend = K.text(panel, "GameFontHighlightSmall")
    panel.legend:SetPoint("TOPLEFT", 10, -72)
    panel.legend:SetPoint("RIGHT", panel, "RIGHT", -10, 0)
    panel.legend:SetJustifyH("LEFT")

    -- live numbers
    panel.stats = K.text(panel, "GameFontHighlightSmall", P.warmGrey)
    panel.stats:SetPoint("TOPLEFT", 10, -90)
    panel.ev = K.text(panel, "GameFontHighlightSmall")
    panel.ev:SetPoint("TOPRIGHT", -10, -90)

    -- value per minute, last 30 minutes
    panel.hist = CreateFrame("Frame", nil, panel)
    panel.hist:SetPoint("BOTTOMLEFT", 9, 7)
    panel.hist:SetPoint("BOTTOMRIGHT", -9, 7)
    panel.hist:SetHeight(18)
    local base = panel.hist:CreateTexture(nil, "BACKGROUND")
    base:SetPoint("BOTTOMLEFT") base:SetPoint("BOTTOMRIGHT") base:SetHeight(1)
    base:SetColorTexture(P.bronze2[1], P.bronze2[2], P.bronze2[3], 0.6)
    panel.bars = {}
    local gap = 2
    local width = (WIDTH - 18 - gap * (MINUTES - 1)) / MINUTES
    for i = 1, MINUTES do
        local b = panel.hist:CreateTexture(nil, "ARTWORK")
        b:SetTexture(bar)
        b:SetWidth(width)
        b:SetPoint("BOTTOMLEFT", panel.hist, "BOTTOMLEFT", (i - 1) * (width + gap), 0)
        panel.bars[i] = b
    end

    for i = 1, 3 do pops[i] = pop() end
    panel:SetScript("OnEnter", Panel.tooltip)
    panel:SetScript("OnMouseUp", function(_, button) if button == "RightButton" and ns.CastBar then ns.CastBar.openSounds() end end)
    panel:SetScript("OnLeave", function() GameTooltip:Hide() end)
    panel.fadeOut = panel:CreateAnimationGroup()
    local out = panel.fadeOut:CreateAnimation("Alpha")
    out:SetFromAlpha(1) out:SetToAlpha(0) out:SetDuration(1.5)
    panel.fadeOut:SetScript("OnFinished", function() panel:Hide() panel:SetAlpha(1) end)
    panel:Hide()
    if module then module:Dock(panel) else panel:SetPoint("TOP", Minimap, "BOTTOM", 0, -64) end
end

-- --- drawing ---------------------------------------------------------------------------

function Panel.draw()
    if not panel or not panel:IsShown() then return end
    local s = ns.C.session()
    if not s then return end
    local sum = Core.fishSummary(s.log, ns.C.price)
    local hourly = Core.perHour(sum.total, s.active)
    local _, _, _, sub = ns.C.water()
    panel.title:SetText("Fishing · " .. (sub or s.zone or ""))
    panel.clock:SetText(Core.clock(s.active))
    panel.rate:SetText(hourly and (K.coins(hourly, 10, true) .. "|cff" .. K.hex(K.GREEN) .. "/h|r") or "")

    -- feed: the last catches, newest on the right
    local recent = {}
    for i = #s.log, math.max(1, #s.log - FEED + 1), -1 do table.insert(recent, 1, s.log[i]) end
    for i, sl in ipairs(panel.slots) do
        local e = recent[i]
        if e then
            sl.icon:SetTexture(C_Item.GetItemIconByID and C_Item.GetItemIconByID(e.id) or POLE)
            sl:SetBackdropBorderColor(itemColor(e.id))
            sl.count:SetText(e.n > 1 and e.n or "")
            sl:Show()
        else
            sl:Hide()
        end
    end

    -- where the gold comes from
    local width, x = panel.share:GetWidth(), 0
    local legend = {}
    for i, seg in ipairs(panel.share.segs) do
        local value
        if i <= #SHARE_COLORS then
            value = sum.fish[i] and sum.fish[i].value or 0
        else
            value = 0
            for j = #SHARE_COLORS + 1, #sum.fish do value = value + sum.fish[j].value end
        end
        local w = sum.total > 0 and width * value / sum.total or 0
        if w >= 1 then
            seg:ClearAllPoints()
            seg:SetPoint("TOPLEFT", panel.share, "TOPLEFT", x, 0)
            seg:SetSize(w, panel.share:GetHeight())
            seg:Show()
            x = x + w
        else
            seg:Hide()
        end
        if i <= 3 and sum.fish[i] and sum.total > 0 then
            local c = SHARE_COLORS[i]
            legend[#legend + 1] = ("|cff%s%s|r %d %%"):format(K.hex(c), itemName(sum.fish[i].id),
                math.floor(sum.fish[i].value / sum.total * 100 + 0.5))
        end
    end
    panel.legend:SetText(#legend > 0 and table.concat(legend, "  ·  ") or "|cff8f8275no catches yet|r")

    local lost = (s.escaped or 0) + (s.missed or 0)
    local tries = s.catches + lost
    panel.stats:SetText(("|cffffffff%d|r caught  ·  |cffffffff%d|r lost  ·  %d %%  ·  %.1f/min"):format(
        s.catches, lost, tries > 0 and math.floor(s.catches / tries * 100 + 0.5) or 0,
        s.catches / math.max(1, s.active / 60)))
    panel.ev:SetText(sum.mean and ("EV " .. K.coins(sum.mean, 10) .. " |cff" .. K.hex(P.warmGrey) .. "/catch|r") or "")

    local bins = Core.minuteBins(s.log, ns.C.price, time(), MINUTES)
    local top = 0
    for _, v in ipairs(bins) do top = math.max(top, v) end
    local fc = { K.soft(0.32, 0.60, 0.92) }
    for i, b in ipairs(panel.bars) do
        local v = bins[i]
        if v > 0 and top > 0 then
            b:SetHeight(math.max(2, panel.hist:GetHeight() * v / top))
            local c = i == MINUTES and P.bronze4 or fc
            b:SetVertexColor(c[1], c[2], c[3], 0.95)
        else
            b:SetHeight(1)
            b:SetVertexColor(P.bronze2[1], P.bronze2[2], P.bronze2[3], 0.35)
        end
    end
end

-- --- events from Catch.lua -------------------------------------------------------------

local function show()
    if not panel then return end
    panel.fadeOut:Stop()
    panel:SetAlpha(1)
    if not panel:IsShown() then panel:Show() end
    Panel.draw()
end

function Panel.onCast() if not Panel.off then show() end end
function Panel.onCastStop() end

function Panel.onCatch(id, count, value)
    if Panel.off or not panel then return end
    show()
    local s = ns.C.session()
    local newest = panel.slots[math.min(FEED, s and #s.log or FEED)]
    if newest and newest:IsShown() then newest.slideIn:Stop() newest.slideIn:Play() end
    if value and value > 0 then
        local fs = pops[nextPop]
        nextPop = nextPop % #pops + 1
        local r, g, b = itemColor(id)
        fs:SetText(("|cff%02x%02x%02x+|r "):format(r * 255, g * 255, b * 255) .. K.coins(value, 12))
        fs.anim:Stop()
        fs.anim:Play()
    end
end

function Panel.tick()
    if not panel or not panel:IsShown() then return end
    local s = ns.C.session()
    if not s or not s.lastCast or time() - s.lastCast > IDLE then
        if not panel.fadeOut:IsPlaying() then panel.fadeOut:Play() end
        return
    end
    Panel.draw()
end

function Panel.toggle()
    if not panel then return end
    if panel:IsShown() then panel:Hide() Panel.off = true else Panel.off = false show() end
end

-- --- nerd numbers (panel hover; also Shift on Deadbeat's bar) ------------------------------

function Panel.nerd(tip)
    local s = ns.C.session()
    if not s then return end
    local g = P.warmGrey
    local sum = Core.fishSummary(s.log, ns.C.price)
    local hourly = Core.perHour(sum.total, s.active)
    tip:AddLine(" ")
    tip:AddLine("Fishing nerd stats", P.bronze4[1], P.bronze4[2], P.bronze4[3])
    local tries = s.catches + (s.escaped or 0) + (s.missed or 0)
    tip:AddDoubleLine("  Casts", ("%d  ·  %d caught  ·  %d got away  ·  %d ran out  ·  %d %%"):format(s.casts, s.catches,
        s.escaped or 0, s.missed or 0, tries > 0 and math.floor(s.catches / tries * 100 + 0.5) or 0),
        g[1], g[2], g[3], 1, 1, 1)
    if s.active >= 60 and s.catches > 0 then
        tip:AddDoubleLine("  Pace", ("%.1f catches/min  ·  %.0f s per catch"):format(s.catches / (s.active / 60),
            s.active / s.catches), g[1], g[2], g[3], 1, 1, 1)
    end
    local win = Core.biteWindow(ns.C.bites())
    if win then
        tip:AddDoubleLine("  Bite window", ("%.1f–%.1f s  ·  avg %.1f s  ·  %d casts"):format(win.low, win.high, win.avg,
            win.n), g[1], g[2], g[3], 1, 1, 1)
    end
    if sum.mean then
        tip:AddDoubleLine("  Expected value", K.coins(sum.mean, 11) .. " per catch", g[1], g[2], g[3], 1, 1, 1)
        tip:AddDoubleLine("  Spread", "σ " .. K.coins(sum.sd or 0, 10) ..
            (sum.ci and ("   95 % CI ±" .. K.coins(sum.ci, 10)) or ""), g[1], g[2], g[3], 1, 1, 1)
        tip:AddDoubleLine("  Best catch", K.coins(sum.best, 11), g[1], g[2], g[3], 1, 1, 1)
        local junk = 0
        for _, fish in ipairs(sum.fish) do if fish.junk then junk = junk + fish.value end end
        if sum.total > 0 then
            tip:AddDoubleLine("  Vendor-only share", ("%d %% of the value"):format(math.floor(junk / sum.total * 100 + 0.5)),
                g[1], g[2], g[3], 1, 1, 1)
        end
        local eta = Core.etaMinutes(100000, hourly)
        if eta then tip:AddDoubleLine("  Next 10g", ("~%d min at this pace"):format(eta), g[1], g[2], g[3], 1, 1, 1) end
    end
end

function Panel.tooltip(self)
    local s = ns.C.session()
    if not s then return end
    local g = P.warmGrey
    local sum = Core.fishSummary(s.log, ns.C.price)
    local hourly = Core.perHour(sum.total, s.active)
    local tip = GameTooltip
    tip:SetOwner(self, "ANCHOR_BOTTOM", 0, -4)
    tip:AddDoubleLine("Fishing · " .. (s.zone or ""), Core.clock(s.active), P.bronze4[1], P.bronze4[2], P.bronze4[3],
        g[1], g[2], g[3])
    tip:AddDoubleLine("  Total", K.coins(sum.total, 12) ..
        (hourly and ("  |cff" .. K.hex(K.GREEN) .. "·|r  " .. K.coins(hourly, 10, true) .. "/h") or ""), g[1], g[2], g[3], 1, 1, 1)
    Panel.nerd(tip)
    if #sum.fish > 0 then
        tip:AddLine(" ")
        tip:AddLine("Catch table", g[1], g[2], g[3])
        for i = 1, math.min(10, #sum.fish) do
            local fish = sum.fish[i]
            local r, gg, b = itemColor(fish.id)
            local itemIcon = C_Item.GetItemIconByID and C_Item.GetItemIconByID(fish.id)
            tip:AddDoubleLine((itemIcon and (K.icon(itemIcon) .. "  ") or "") .. itemName(fish.id) ..
                ("|cffffffff ×%d|r |cff%s%d %%|r"):format(fish.count, K.hex(g),
                    sum.total > 0 and math.floor(fish.value / sum.total * 100 + 0.5) or 0),
                K.coins(fish.each, 10) .. " |cff" .. K.hex(g) .. "ea|r   " .. K.coins(fish.value, 11), r, gg, b, 1, 1, 1)
        end
    end
    tip:AddLine(" ")
    tip:AddLine("Right-click: sounds", g[1], g[2], g[3])
    tip:Show()
end
