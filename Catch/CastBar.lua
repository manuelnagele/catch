-- Catch's big cast bar: the one thing that matters while fishing, next to the view, and only while a cast runs.
-- A strip of dusk water, lit amber as the cast runs, a bobber riding the head; your bite window a warm haze, and inside
-- it the bobber dips and rings spread. Movable (shift-drag). Plus the sounds: when the bobber lands, while you wait,
-- when your bite window starts.
local _, ns = ...
local Core = ns.Core
local CastBar = {}
ns.CastBar = CastBar

local K, P
local bar
local WIDTH, HEIGHT = 440, 20           -- tools/make_textures.py draws the shapes for this size

-- Catch's own sounds (tools/make_sounds.py), listed first in the sound window; a sound is a file path (string)
-- or a SOUNDKIT id (number).
local DIR = "Interface\\AddOns\\Catch\\Sounds\\"
local CUSTOM = {
    { name = "Catch · soft plop", file = "lands_plop.ogg" },
    { name = "Catch · distant reel", file = "lands_reel.ogg" },
    { name = "Catch · warm drop", file = "lands_drop.ogg" },
    { name = "Catch · water lap", file = "wait_lap.ogg" },
    { name = "Catch · far bubbles", file = "wait_bubbles.ogg" },
    { name = "Catch · breath", file = "wait_breath.ogg" },
    { name = "Catch · soft pluck", file = "window_pluck.ogg" },
    { name = "Catch · kalimba", file = "window_kalimba.ogg" },
    { name = "Catch · water drop", file = "window_drop.ogg" },
    { name = "Catch · fel hum", file = "window_fel.ogg" },
}
for _, c in ipairs(CUSTOM) do c.id = DIR .. c.file end

local SOUNDS = {
    lands  = { default = DIR .. "lands_plop.ogg" },
    wait   = { default = nil },                      -- silent until you pick one
    window = { default = DIR .. "window_pluck.ogg" },
}

-- Ambience while you fish (the Ambience channel: your ambience volume slider), looped back to back.
local AMBIENCES = {
    { key = "lake", name = "Lakeside", file = DIR .. "ambience_lake.ogg", length = 24 },
    { key = "dusk", name = "Dusk", file = DIR .. "ambience_dusk.ogg", length = 24 },
}
local amb = { handle = nil, timer = nil, key = nil }

local function ambienceChoice()
    local key = CatchDB.ambience or "lake"
    for _, a in ipairs(AMBIENCES) do if a.key == key then return a end end
end

local function stopAmbience(fade)
    if amb.timer then amb.timer:Cancel() amb.timer = nil end
    if amb.handle and StopSound then StopSound(amb.handle, fade or 3000) end
    amb.handle, amb.key = nil, nil
end

local function startAmbience()
    local a = ambienceChoice()
    if not a then stopAmbience() return end
    local ok, willPlay, handle = pcall(PlaySoundFile, a.file, "Ambience")
    amb.handle, amb.key = ok and willPlay and handle or nil, a.key
    amb.timer = C_Timer.NewTimer(a.length - 0.05, function()
        amb.timer = nil
        if ns.C.fishingNow() then startAmbience() else stopAmbience() end
    end)
end

function CastBar.ambienceTick()
    local fishing = ns.C.fishingNow()
    local want = fishing and ambienceChoice()
    if want and amb.key ~= want.key then stopAmbience(1500) startAmbience()
    elseif not want and amb.key then stopAmbience() end
end

local function playId(id)
    if type(id) == "string" then pcall(PlaySoundFile, id, "SFX")
    elseif type(id) == "number" and id > 0 then pcall(PlaySound, id, "SFX") end
end
CastBar.playId = playId
local WAIT_EVERY = 5                 -- seconds between soft reel ticks

local function play(which)
    if CatchDB.sound == false then return end
    local custom = CatchDB.sounds and CatchDB.sounds[which]
    playId(custom or SOUNDS[which].default)
end
CastBar.play = play

-- Sound browser: the game's SOUNDKIT entries whose names sound like fishing, for auditioning a replacement.
local WORDS = { "FISH", "REEL", "WATER", "SPLASH", "BUBBLE", "BOBBER", "DROP", "WOOD", "LINE", "CAST", "LIQUID", "SWIM" }
function CastBar.candidates()
    local list = {}
    for name, id in pairs(SOUNDKIT or {}) do
        if type(id) == "number" then
            for _, w in ipairs(WORDS) do
                if name:find(w, 1, true) then list[#list + 1] = { name = name, id = id } break end
            end
        end
    end
    table.sort(list, function(a, b) return a.name < b.name end)
    for i = #CUSTOM, 1, -1 do table.insert(list, 1, CUSTOM[i]) end
    return list
end

-- --- building ----------------------------------------------------------------------

-- Catch's own textures (tools/make_textures.py): the strip of water, its rim and shadow, the bobber, a ripple.
local TEX = "Interface\\AddOns\\Catch\\Textures\\"
local TILE = 80                      -- the water texture's width on screen; make_textures.py draws it for this
local WATER = { 0.16, 0.24, 0.34 }   -- dusk
local AMBER = { 0.86, 0.58, 0.30 }   -- the fill
local GOLD = { 1.00, 0.80, 0.45 }    -- the fill inside your bite window
local HAZE = { 0.92, 0.70, 0.38 }    -- the bite window on the water

local function layer(parent, file, drawLayer, sub)
    local t = parent:CreateTexture(nil, drawLayer, nil, sub)
    t:SetTexture(TEX .. file)
    return t
end

local function masked(t)
    if bar.mask and t.AddMaskTexture then t:AddMaskTexture(bar.mask) end
    return t
end

local function fade(frame, from, to, seconds)
    local group = frame:CreateAnimationGroup()
    local a = group:CreateAnimation("Alpha")
    a:SetFromAlpha(from) a:SetToAlpha(to) a:SetDuration(seconds) a:SetSmoothing("IN_OUT")
    group:SetToFinalAlpha(true)
    return group
end

local function build()
    K, P = Deadbeat.kit, Deadbeat.kit.P
    bar = CreateFrame("Frame", "CatchCastBar", UIParent)
    bar:SetSize(WIDTH, HEIGHT)
    bar:SetFrameStrata("MEDIUM")
    local p = CatchDB.castbar
    if p then bar:SetPoint(p[1], UIParent, p[2], p[3], p[4]) else bar:SetPoint("CENTER", UIParent, "CENTER", 0, -160) end
    bar:SetMovable(true)
    bar:SetClampedToScreen(true)
    bar:EnableMouse(true)
    bar:RegisterForDrag("LeftButton")
    bar:SetScript("OnDragStart", function(self) if IsShiftKeyDown() then self:StartMoving() end end)
    bar:SetScript("OnMouseUp", function(_, button) if button == "RightButton" then CastBar.openSounds() end end)
    bar:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_TOP")
        GameTooltip:AddLine("Catch", P.bronze4[1], P.bronze4[2], P.bronze4[3])
        GameTooltip:AddLine("Right-click: sounds  ·  Shift-drag: move", P.warmGrey[1], P.warmGrey[2], P.warmGrey[3])
        GameTooltip:Show()
    end)
    bar:SetScript("OnLeave", function() GameTooltip:Hide() end)
    bar:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
        local point, _, rel, x, y = self:GetPoint()
        CatchDB.castbar = { point, rel, x, y }
    end)

    -- the pool it sits in, the rounded shape everything is cut to, the water
    bar.shadow = layer(bar, "shadow", "BACKGROUND", 0)
    bar.shadow:SetPoint("TOPLEFT", -16, 16)
    bar.shadow:SetPoint("BOTTOMRIGHT", 16, -16)
    bar.shadow:SetAlpha(0.7)
    if bar.CreateMaskTexture then
        bar.mask = bar:CreateMaskTexture()
        bar.mask:SetTexture(TEX .. "mask", "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
        bar.mask:SetAllPoints()
    end
    bar.water = masked(bar:CreateTexture(nil, "BACKGROUND", nil, 2))
    bar.water:SetTexture(TEX .. "water", "REPEAT", "CLAMP")
    bar.water:SetAllPoints()
    bar.water:SetVertexColor(WATER[1], WATER[2], WATER[3])

    -- your bite window: a warm haze on the water, breathing
    bar.window = masked(layer(bar, "band", "BORDER", 0))
    bar.window:SetVertexColor(HAZE[1], HAZE[2], HAZE[3])
    local breathe = bar.window:CreateAnimationGroup()
    breathe:SetLooping("BOUNCE")
    local b = breathe:CreateAnimation("Alpha")
    b:SetFromAlpha(0.22) b:SetToAlpha(0.42) b:SetDuration(1.6) b:SetSmoothing("IN_OUT")
    bar.window.anim = breathe
    bar.avg = layer(bar, "glow", "BORDER", 2)
    bar.avg:SetSize(10, 10)
    bar.avg:SetBlendMode("ADD")
    bar.avg:SetVertexColor(1, 0.9, 0.6)

    -- the fill: the same water, lit amber, flowing with it
    bar.fill = masked(bar:CreateTexture(nil, "ARTWORK", nil, 0))
    bar.fill:SetTexture(TEX .. "water", "REPEAT", "CLAMP")
    bar.fill:SetPoint("TOPLEFT")
    bar.fill:SetPoint("BOTTOMLEFT")
    bar.fill:SetWidth(1)
    bar.rim = layer(bar, "rim", "ARTWORK", 3)
    bar.rim:SetAllPoints()
    bar.rim:SetVertexColor(P.bronze4[1], P.bronze4[2], P.bronze4[3], 0.85)
    bar.headGlow = layer(bar, "glow", "ARTWORK", 4)
    bar.headGlow:SetSize(44, 44)
    bar.headGlow:SetBlendMode("ADD")

    -- the bobber at the head, and the rings it leaves on the water
    bar.float = CreateFrame("Frame", nil, bar)
    bar.float:SetSize(20, 40)
    bar.float:SetFrameLevel(bar:GetFrameLevel() + 3)
    bar.ripple = layer(bar, "ripple", "ARTWORK", 5)
    bar.ripple:SetSize(44, 16)
    bar.ripple:SetVertexColor(1, 0.95, 0.85)
    bar.ripple:SetAlpha(0)
    local rings = bar.ripple:CreateAnimationGroup()
    local grow = rings:CreateAnimation("Scale")
    grow:SetScaleFrom(0.35, 0.35) grow:SetScaleTo(1.3, 1.3) grow:SetDuration(1.4) grow:SetSmoothing("OUT")
    local ebb = rings:CreateAnimation("Alpha")
    ebb:SetFromAlpha(0.7) ebb:SetToAlpha(0) ebb:SetDuration(1.4) ebb:SetSmoothing("OUT")
    bar.ripple.anim = rings
    bar.bobber = layer(bar.float, "bobber", "ARTWORK")
    bar.bobber:SetAllPoints()

    bar.timer = K.text(bar, "GameFontNormalLarge", { 1, 0.93, 0.80 })
    bar.timer:SetPoint("LEFT", bar, "RIGHT", 12, 0)
    bar.label = K.text(bar, "GameFontHighlightSmall", P.warmGrey)
    bar.label:SetPoint("TOPLEFT", bar.timer, "BOTTOMLEFT", 1, -2)   -- under the timer: the creel has the space below

    -- only while a cast runs: in quick, out soft
    bar.fadeIn = fade(bar, 0, 1, 0.15)
    bar.fadeOut = fade(bar, 1, 0, 0.35)
    bar.fadeOut:SetScript("OnFinished", function() bar:Hide() end)

    bar:SetScript("OnUpdate", CastBar.update)
    bar:Hide()
end

-- --- drawing ----------------------------------------------------------------------------

local soundState = {}                -- per cast: lands played, last wait tick, window cue played

-- The bobber's height over the water: a slow bob while you wait, a twitchy dip inside your bite window.
function CastBar.bob(t, inWindow)
    if inWindow then return 1 - 4 * math.abs(math.sin(t * math.pi / 0.45)) end
    return 1.5 * math.sin(t * 2 * math.pi / 2.6)
end

local function flow(tex, width, t)
    local u = (t * 0.06) % 1                  -- the water drifts slowly to the left
    tex:SetTexCoord(u, u + width / TILE, 0, 1)
end

function CastBar.update(self)
    local c = ns.C.cast()
    if not c.active then return end
    local w, h = self:GetWidth(), self:GetHeight()
    local now = GetTime()
    local win = Core.biteWindow(ns.C.bites())
    local duration = (c.duration and c.duration > 0) and c.duration or 30
    local elapsed = now - c.start
    flow(self.water, w, now)
    if win then
        local x1, x2 = w * math.min(1, win.low / duration), w * math.min(1, win.high / duration)
        local soft = 0.1 * (x2 - x1)         -- the band's soft ends reach a little past the window
        self.window:ClearAllPoints()
        self.window:SetPoint("TOPLEFT", self, "TOPLEFT", x1 - soft, 0)
        self.window:SetSize(math.max(4, x2 - x1 + 2 * soft), h)
        self.window:Show()
        if not self.window.anim:IsPlaying() then self.window.anim:Play() end
        self.avg:ClearAllPoints()
        self.avg:SetPoint("CENTER", self, "LEFT", w * math.min(1, win.avg / duration), 0)
        self.avg:Show()
    else
        self.window:Hide() self.avg:Hide()
    end

    local x = math.max(1, w * math.min(1, elapsed / duration))
    local inWindow = win and elapsed >= win.low and elapsed <= win.high
    local col = inWindow and GOLD or AMBER
    self.fill:SetWidth(x)
    flow(self.fill, x, now)
    self.fill:SetVertexColor(col[1], col[2], col[3], 0.92)
    self.headGlow:ClearAllPoints()
    self.headGlow:SetPoint("CENTER", self, "LEFT", x, 0)
    self.headGlow:SetVertexColor(col[1], col[2] * 0.95, col[3] * 0.9, inWindow and 0.7 or 0.4)
    self.float:ClearAllPoints()
    self.float:SetPoint("BOTTOM", self, "LEFT", x, -10 + CastBar.bob(now, inWindow))   -- its waterline on the centre
    self.ripple:ClearAllPoints()
    self.ripple:SetPoint("CENTER", self, "LEFT", x, 0)
    if inWindow and not self.ripple.anim:IsPlaying() then self.ripple.anim:Play() end
    self.timer:SetText(("%.1f"):format(elapsed))

    -- sounds, once per cast
    local s = soundState
    if s.cast ~= c.current then soundState = { cast = c.current, lastWait = 0 } s = soundState end
    if not s.lands and elapsed >= 1.6 then s.lands = true play("lands") self.ripple.anim:Play() end
    if win and not s.window and elapsed >= win.low then s.window = true play("window") end
    if elapsed >= 3 and elapsed - s.lastWait >= WAIT_EVERY and not (win and elapsed >= win.low) then
        s.lastWait = elapsed
        if s.lands and elapsed - 1.6 >= 1 and not CatchDB.waitOff and CatchDB.sounds and CatchDB.sounds.wait then
            play("wait")
        end
    end
    local text = win and ("bite %.0f–%.0f s  ·  avg %.1f s"):format(win.low, win.high, win.avg)
        or ("learning your bite window  ·  %d/%d"):format(#ns.C.bites(), Core.BITE_MIN)
    if ns.Lure and not ns.Lure.left() then text = "|cffe0664dno lure|r  ·  " .. text end
    self.label:SetText(text)
end

-- --- events from Catch.lua ----------------------------------------------------------------

function CastBar.build() if Deadbeat then build() end end

function CastBar.onCast()
    if not bar then return end
    bar.fadeOut:Stop()
    bar.fill:SetWidth(1)
    bar.ripple.anim:Stop()
    bar:SetAlpha(1)
    bar:Show()
    bar.fadeIn:Play()
end

-- The cast ended (a catch, a miss, a move): the bar goes, so a shown bar always means a cast is running.
function CastBar.onStop()
    if not bar or not bar:IsShown() then return end
    bar.fadeOut:Play()
end

-- A safety net: no running cast (a /reload mid-cast, a missed stop event) and the bar goes anyway.
function CastBar.tick()
    if not bar or not bar:IsShown() then return end
    if not ns.C.cast().active and not bar.fadeOut:IsPlaying() then bar.fadeOut:Play() end
end

function CastBar.reset()
    CatchDB.castbar = nil
    if bar then bar:ClearAllPoints() bar:SetPoint("CENTER", UIParent, "CENTER", 0, -160) end
end

-- --- the sound picker (right-click the cast bar or the panel) --------------------------------

local SLOTS = { { key = "lands", label = "Bobber lands" }, { key = "wait", label = "While waiting" },
                { key = "window", label = "Bite window" } }
local ROWS = 12
local picker

local function soundName(id)
    for _, c in ipairs(CUSTOM) do if c.id == id then return c.name end end
    for name, v in pairs(SOUNDKIT or {}) do if v == id then return name:lower():gsub("_", " ") end end
    return id and tostring(id) or "—"
end

local function current(key)
    if key == "wait" and (CatchDB.waitOff or not (CatchDB.sounds and CatchDB.sounds.wait)) then return nil end
    local id = (CatchDB.sounds and CatchDB.sounds[key]) or SOUNDS[key].default
    if id == 0 then return nil end
    return id
end

local function button(parent, text, width, onClick)
    local b = CreateFrame("Button", nil, parent)
    b:SetSize(width, 18)
    K.ground(b, 0.95)
    K.border(b, true)
    b.text = K.text(b, "GameFontHighlightSmall", P.bronze4)
    b.text:SetPoint("CENTER")
    b.text:SetText(text)
    local hi = b:CreateTexture(nil, "HIGHLIGHT")
    hi:SetAllPoints()
    hi:SetColorTexture(P.bronze4[1], P.bronze4[2], P.bronze4[3], 0.18)
    b:SetScript("OnClick", onClick)
    return b
end

local function filtered()
    local q = (picker.search:GetText() or ""):upper():gsub("%s+", "_")
    if q == "" then return CastBar.candidates() end
    local list = {}
    for _, c in ipairs(CUSTOM) do if c.name:upper():gsub("%s+", "_"):find(q, 1, true) then list[#list + 1] = c end end
    for name, id in pairs(SOUNDKIT or {}) do
        if type(id) == "number" and name:find(q, 1, true) then list[#list + 1] = { name = name, id = id } end
    end
    table.sort(list, function(a, b) return a.name < b.name end)
    return list
end

local function refreshPicker()
    if not picker or not picker:IsShown() then return end
    for _, row in ipairs(picker.slots) do
        local id = current(row.key)
        row.value:SetText(id and soundName(id) or "|cff8f8275off|r")
    end
    local a = ambienceChoice()
    picker.ambValue:SetText(a and a.name or "|cff8f8275off|r")
    local list = filtered()
    local pages = math.max(1, math.ceil(#list / ROWS))
    picker.page = math.min(picker.page, pages)
    picker.pageText:SetText(("%d / %d  ·  %d sounds"):format(picker.page, pages, #list))
    for i, row in ipairs(picker.rows) do
        local e = list[(picker.page - 1) * ROWS + i]
        row.entry = e
        if e then
            row.name:SetText(e.file and ("|cffcc9957" .. e.name .. "|r") or e.name:lower():gsub("_", " "))
            row:Show()
        else
            row:Hide()
        end
    end
end

local function assign(key, id)
    CatchDB.sounds = CatchDB.sounds or {}
    CatchDB.sounds[key] = id
    if key == "wait" then CatchDB.waitOff = nil end
    playId(id)
    refreshPicker()
end

-- The picker lives on the "Catch · Sounds" page of Deadbeat's settings console (it was its own window until 0.9). Its
-- rows sit where they did under the old title, so the frame starts 30 px above the page.
local PICKER_HEIGHT = 134 + ROWS * 22 + 34
CastBar.SOUNDS_HEIGHT = PICKER_HEIGHT - 30

local function buildPicker(parent)
    picker = CreateFrame("Frame", "CatchSounds", parent)
    picker:SetSize(420, PICKER_HEIGHT)
    picker:SetPoint("TOPLEFT", parent, "TOPLEFT", -14, 30)

    -- your three sounds
    picker.slots = {}
    for i, slot in ipairs(SLOTS) do
        local row = CreateFrame("Frame", nil, picker)
        row:SetSize(392, 20)
        row:SetPoint("TOPLEFT", 14, -36 - (i - 1) * 22)
        row.key = slot.key
        local label = K.text(row, "GameFontHighlightSmall", P.warmGrey)
        label:SetPoint("LEFT")
        label:SetText(slot.label)
        row.value = K.text(row, "GameFontHighlightSmall")
        row.value:SetPoint("LEFT", 100, 0)
        row.value:SetWidth(190)
        row.value:SetJustifyH("LEFT")
        local off = button(row, "Off", 40, function()
            if slot.key == "wait" then CatchDB.waitOff = true
            else CatchDB.sounds = CatchDB.sounds or {} CatchDB.sounds[slot.key] = 0 end
            refreshPicker()
        end)
        off:SetPoint("RIGHT")
        local playBtn = button(row, "▶", 26, function() playId(current(slot.key)) end)
        playBtn:SetPoint("RIGHT", off, "LEFT", -6, 0)
        picker.slots[i] = row
    end

    -- ambience while fishing
    local ambRow = CreateFrame("Frame", nil, picker)
    ambRow:SetSize(392, 20)
    ambRow:SetPoint("TOPLEFT", 14, -36 - 3 * 22)
    local ambLabel = K.text(ambRow, "GameFontHighlightSmall", P.warmGrey)
    ambLabel:SetPoint("LEFT")
    ambLabel:SetText("Ambience")
    picker.ambValue = K.text(ambRow, "GameFontHighlightSmall")
    picker.ambValue:SetPoint("LEFT", 100, 0)
    local x = 0
    for i = #AMBIENCES + 1, 1, -1 do
        local a = AMBIENCES[i]
        local b = button(ambRow, a and a.name or "Off", a and 70 or 40, function()
            CatchDB.ambience = a and a.key or "off"
            if a then
                stopAmbience(800)
                local ok, willPlay, handle = pcall(PlaySoundFile, a.file, "Ambience")   -- a taste
                if ok and willPlay and handle then C_Timer.After(6, function() StopSound(handle, 2500) end) end
            else
                stopAmbience()
            end
            CastBar.ambienceTick()
            refreshPicker()
        end)
        b:SetPoint("RIGHT", ambRow, "RIGHT", -x, 0)
        x = x + (a and 74 or 44)
    end

    -- search
    local searchLabel = K.text(picker, "GameFontHighlightSmall", P.warmGrey)
    searchLabel:SetPoint("TOPLEFT", 14, -132)
    searchLabel:SetText("Search")
    picker.search = CreateFrame("EditBox", nil, picker)
    picker.search:SetSize(200, 18)
    picker.search:SetPoint("LEFT", searchLabel, "RIGHT", 10, 0)
    picker.search:SetFontObject("GameFontHighlightSmall")
    picker.search:SetAutoFocus(false)
    picker.search:SetTextInsets(6, 6, 0, 0)
    K.ground(picker.search, 0.95)
    K.border(picker.search, true)
    picker.search:SetScript("OnTextChanged", function() picker.page = 1 refreshPicker() end)
    picker.search:SetScript("OnEscapePressed", picker.search.ClearFocus)
    picker.search:SetScript("OnEnterPressed", picker.search.ClearFocus)
    local hint = K.text(picker, "GameFontHighlightSmall", P.warmGrey)
    hint:SetPoint("LEFT", picker.search, "RIGHT", 8, 0)
    hint:SetText("empty = fishing-like")

    -- the list
    picker.rows = {}
    for i = 1, ROWS do
        local row = CreateFrame("Frame", nil, picker)
        row:SetSize(392, 20)
        row:SetPoint("TOPLEFT", 14, -158 - (i - 1) * 22)
        local playBtn = button(row, "▶", 26, function() if row.entry then playId(row.entry.id) end end)
        playBtn:SetPoint("LEFT")
        row.name = K.text(row, "GameFontHighlightSmall")
        row.name:SetPoint("LEFT", playBtn, "RIGHT", 8, 0)
        row.name:SetWidth(190)
        row.name:SetJustifyH("LEFT")
        local x = 0
        for j = #SLOTS, 1, -1 do
            local slot = SLOTS[j]
            local b = button(row, ({ lands = "Lands", wait = "Wait", window = "Window" })[slot.key], 50,
                function() if row.entry then assign(slot.key, row.entry.id) end end)
            b:SetPoint("RIGHT", row, "RIGHT", -x, 0)
            x = x + 54
        end
        picker.rows[i] = row
    end

    -- pages
    picker.page = 1
    local prev = button(picker, "‹", 26, function() picker.page = math.max(1, picker.page - 1) refreshPicker() end)
    prev:SetPoint("BOTTOMLEFT", 14, 12)
    local nextBtn = button(picker, "›", 26, function() picker.page = picker.page + 1 refreshPicker() end)
    nextBtn:SetPoint("LEFT", prev, "RIGHT", 6, 0)
    picker.pageText = K.text(picker, "GameFontHighlightSmall", P.warmGrey)
    picker.pageText:SetPoint("LEFT", nextBtn, "RIGHT", 10, 0)
    local test = button(picker, "Play all three", 110, function()
        for i, slot in ipairs(SLOTS) do
            C_Timer.After((i - 1) * 1.5, function() playId(current(slot.key)) end)
        end
    end)
    test:SetPoint("BOTTOMRIGHT", -14, 12)
    picker:SetScript("OnShow", refreshPicker)
end

-- for the settings page
function CastBar.buildSounds(frame) if K then buildPicker(frame) end end
function CastBar.showSounds() refreshPicker() end

function CastBar.openSounds()
    if Deadbeat and Deadbeat.OpenSettings then Deadbeat.OpenSettings("Catch · Sounds") end
end
