-- Catch on the world map: hotspots where you've caught fish (clustered, coloured by value per catch, pools marked)
-- and a waters panel ranking the shown zone's waters by expected gold per catch. Works on Blizzard's map and on
-- OpenMap's stitched map (OpenMapAPI's coordinates), with a switch in OpenMap's menu.
local _, ns = ...
local Core = ns.Core
local Map = {}
ns.Map = Map

local K, P
local overlay, panel
local pins = {}

local function enabled() return CatchDB.map ~= false end

-- canvas position (0..1 of the shown map) for a cluster, or nil when it isn't on the shown map
local function place(c, shownMap)
    local api = OpenMapAPI
    if api and api.IsStitched and api.IsStitched() then
        local u, v = api.WorldFromMap(c.map, c.x, c.y)
        if u then return api.MapFromWorld(shownMap, u, v) end
        return nil
    end
    if c.map == shownMap then return c.x, c.y end
end

local function pin(i)
    if pins[i] then return pins[i] end
    local f = CreateFrame("Button", nil, overlay)
    f:SetSize(14, 14)
    f.rim = f:CreateTexture(nil, "BORDER")
    f.rim:SetTexture("Interface\\Buttons\\WHITE8x8")
    f.rim:SetSize(12, 12)
    f.rim:SetPoint("CENTER")
    f.rim:SetRotation(math.pi / 4)
    f.rim:SetVertexColor(P.ground[1], P.ground[2], P.ground[3], 1)
    f.dot = f:CreateTexture(nil, "ARTWORK")
    f.dot:SetTexture("Interface\\Buttons\\WHITE8x8")
    f.dot:SetSize(8, 8)
    f.dot:SetPoint("CENTER")
    f.dot:SetRotation(math.pi / 4)
    f.ring = f:CreateTexture(nil, "BACKGROUND")
    f.ring:SetTexture("Interface\\Buttons\\WHITE8x8")
    f.ring:SetSize(16, 16)
    f.ring:SetPoint("CENTER")
    f.ring:SetRotation(math.pi / 4)
    f.ring:SetVertexColor(K.soft(0.32, 0.60, 0.92))
    f:SetScript("OnEnter", function(self)
        local c, g = self.cluster, P.warmGrey
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:AddDoubleLine(c.sub or "Fishing spot", date("%d %b", c.last), P.bronze4[1], P.bronze4[2], P.bronze4[3],
            g[1], g[2], g[3])
        GameTooltip:AddDoubleLine("Value per catch", K.coins(c.perCatch, 11), g[1], g[2], g[3], 1, 1, 1)
        GameTooltip:AddDoubleLine("Catches", tostring(c.catches) .. (c.pools > 0 and ("  ·  %d from pools"):format(c.pools) or ""),
            g[1], g[2], g[3], 1, 1, 1)
        GameTooltip:AddDoubleLine("Total", K.coins(c.value, 11), g[1], g[2], g[3], 1, 1, 1)
        GameTooltip:Show()
    end)
    f:SetScript("OnLeave", function() GameTooltip:Hide() end)
    pins[i] = f
    return f
end

-- --- the waters panel --------------------------------------------------------------------

local function waterKey(w) return w.spots and table.concat(w.spots, ", ") or "Open water" end

local function measured(spots, w, shownMap)
    -- your value per catch in this water (subzones of the water, or anything not in another water's subzones)
    local set = {}
    for _, s in ipairs(w.spots or {}) do set[s] = true end
    local value, catches, lastT = 0, 0, nil
    for _, s in ipairs(spots) do
        if s.map == shownMap and ((w.spots and set[s.sub]) or (not w.spots and not s.inSpot)) then
            local vendor, market = ns.C.price(s.id)
            value = value + (market or vendor or 0) * (s.n or 1)
            if s.t ~= lastT then catches = catches + 1 lastT = s.t end
        end
    end
    return catches > 0 and value / catches or nil, catches
end

local function drawPanel(shownMap, spots)
    local tables = ns.data.FISHDB[shownMap]
    local base = ns.data.ZONE_BASE[shownMap]
    local info = C_Map.GetMapInfo and C_Map.GetMapInfo(shownMap)
    local lines = {}
    if tables then
        local inSpot = {}
        for _, w in ipairs(tables) do for _, s in ipairs(w.spots or {}) do inSpot[s] = true end end
        for _, s in ipairs(spots) do s.inSpot = inSpot[s.sub] end
        for _, w in ipairs(tables) do
            local ev, parts = Core.waterEV(w.rows, ns.C.price)
            local mine, n = measured(spots, w, shownMap)
            lines[#lines + 1] = { name = waterKey(w), ev = (n >= 10 and mine) or ev, measured = n >= 10, n = n,
                                  top = parts[1] and parts[1].name }
        end
    else
        -- no drop table: your own subzones only
        local by = {}
        for _, s in ipairs(spots) do
            if s.map == shownMap then
                local key = s.sub or "?"
                by[key] = by[key] or { value = 0, catches = 0, lastT = nil }
                local vendor, market = ns.C.price(s.id)
                by[key].value = by[key].value + (market or vendor or 0) * (s.n or 1)
                if s.t ~= by[key].lastT then by[key].catches = by[key].catches + 1 by[key].lastT = s.t end
            end
        end
        for name, b in pairs(by) do
            lines[#lines + 1] = { name = name, ev = b.value / b.catches, measured = true, n = b.catches }
        end
    end
    table.sort(lines, function(a, b) return a.ev > b.ev end)
    if #lines == 0 then panel:Hide() return end

    panel.title:SetText("Fishing · " .. (info and info.name or ""))
    local rank, _, bonus = ns.C.skill()
    panel.skill:SetText(base and ("no lost casts from %d%s"):format(base + 95,
        rank and ("  ·  you %d"):format(rank + (bonus or 0)) or "") or "")
    local g = P.warmGrey
    local text = {}
    for i = 1, math.min(8, #lines) do
        local l = lines[i]
        text[#text + 1] = ("%s%s  |cffffffff%s|r  |cff%s%s|r"):format(i == 1 and "|cffffd140" or "|cffcc9957", l.name,
            K.coins(l.ev, 10), K.hex(g), l.measured and ("measured · %d"):format(l.n) or ("table" .. (l.top and (" · " .. l.top) or "")))
    end
    panel.body:SetText(table.concat(text, "\n"))
    panel:SetHeight(42 + 14 * math.min(8, #lines))
    panel:Show()
end

-- --- drawing -------------------------------------------------------------------------------

function Map.redraw()
    if not overlay then return end
    for _, p in ipairs(pins) do p:Hide() end
    local shownMap = WorldMapFrame:GetMapID()
    if not shownMap or not enabled() then panel:Hide() return end
    local char = ns.C.char()
    local spots = char and char.spots or {}
    local clusters = Core.clusterSpots(spots, ns.C.price, 0.015)
    local best = 0
    for _, c in ipairs(clusters) do best = math.max(best, c.perCatch) end
    local canvas = WorldMapFrame:GetCanvas()
    local w, h = canvas:GetWidth(), canvas:GetHeight()
    local i = 0
    for _, c in ipairs(clusters) do
        local x, y = place(c, shownMap)
        if x and y and x >= -0.5 and x <= 1.5 and y >= -0.5 and y <= 1.5 then
            i = i + 1
            local p = pin(i)
            p.cluster = c
            p:ClearAllPoints()
            p:SetPoint("CENTER", canvas, "TOPLEFT", x * w, -y * h)
            local t = best > 0 and c.perCatch / best or 0      -- bronze → gold by value per catch
            p.dot:SetVertexColor(P.bronze2[1] + (P.goldOn[1] - P.bronze2[1]) * t,
                P.bronze2[2] + (P.goldOn[2] - P.bronze2[2]) * t, P.bronze2[3] + (P.goldOn[3] - P.bronze2[3]) * t, 1)
            p.ring:SetShown(c.pools > 0)
            p:SetScale(1 / math.max(0.2, (WorldMapFrame.GetCanvasScale and WorldMapFrame:GetCanvasScale()) or 1))
            p:Show()
        end
    end
    drawPanel(shownMap, spots)
end

function Map.toggle()
    CatchDB.map = not enabled()
    Map.redraw()
    return enabled()
end

function Map.build()
    if not WorldMapFrame or not Deadbeat then return end
    K, P = Deadbeat.kit, Deadbeat.kit.P
    local canvas = WorldMapFrame:GetCanvas()
    overlay = CreateFrame("Frame", "CatchMapOverlay", canvas)
    overlay:SetAllPoints(canvas)
    local level = (OpenMapAPI and OpenMapAPI.ArtTopLevel and OpenMapAPI.ArtTopLevel()) or canvas:GetFrameLevel()
    overlay:SetFrameLevel(level + 20)

    panel = CreateFrame("Frame", "CatchWaters", WorldMapFrame)
    panel:SetSize(260, 60)
    panel:SetPoint("TOPRIGHT", WorldMapFrame.ScrollContainer or WorldMapFrame, "TOPRIGHT", -12, -12)
    panel:SetFrameStrata("HIGH")
    K.ground(panel)
    K.border(panel, true)
    panel.title = K.text(panel, "GameFontNormalSmall", P.bronze4)
    panel.title:SetPoint("TOPLEFT", 10, -8)
    panel.skill = K.text(panel, "GameFontHighlightSmall", P.warmGrey)
    panel.skill:SetPoint("TOPLEFT", 10, -22)
    panel.body = panel:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    panel.body:SetPoint("TOPLEFT", 10, -38)
    panel.body:SetJustifyH("LEFT")
    panel.body:SetSpacing(2)
    panel:Hide()

    if WorldMapFrame.OnMapChanged then hooksecurefunc(WorldMapFrame, "OnMapChanged", Map.redraw) end
    WorldMapFrame:HookScript("OnShow", Map.redraw)
    if OpenMapAPI then
        if OpenMapAPI.RegisterCallback then
            OpenMapAPI.RegisterCallback(Map, "OpenMap_StitchedChanged", Map.redraw)
        end
        if OpenMapAPI.RegisterMenuToggle then
            pcall(OpenMapAPI.RegisterMenuToggle, "Catch", { id = "hotspots", label = "Fishing hotspots",
                icon = "Interface\\Icons\\Trade_Fishing", get = enabled,
                set = function(on) CatchDB.map = on and true or false Map.redraw() end })
        end
    end
end
