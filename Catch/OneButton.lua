-- Catch's one fishing button, on a keyboard key and a controller button at the same time (FishMate's way, MIT):
-- each press does the next thing. Holding a weapon: your fishing pole goes on. No lure on the pole: the best lure in
-- your bags goes on. Otherwise: cast. While the bobber is out: reel in (the game's "interact" with your bobber as the
-- soft target). And a "done fishing" key (only while you fish) and icon: the cast stops, your weapons go back on,
-- fishing winds down.
--
-- The keys are override bindings, always on (user: "always"); a press clicks a secure button that applies the lure
-- (the template's "item onto slot 16") or casts ("/cast Fishing"), and while you're channelling the same keys are bound
-- to INTERACTTARGET. Bindings and secure attributes only change out of combat. Keys are set on Catch's page of Deadbeat's settings console.
local _, ns = ...
local Core = ns.Core
local OneButton = {}
ns.OneButton = OneButton

local K, P
local owner = CreateFrame("Frame", "CatchBindingOwner", UIParent)
local button                         -- CatchFishButton
local doneButton                     -- CatchDoneButton
local appliedAt = -100               -- when a press last put a lure on
local step, dirty = nil, true

local function secret(v) return issecretvalue ~= nil and issecretvalue(v) end
local function print_(msg) DEFAULT_CHAT_FRAME:AddMessage("|cffd8a446Catch|r: " .. msg) end

local function fishingSpell()
    for _, id in ipairs({ 131474, 7620 }) do
        local name = C_Spell and C_Spell.GetSpellName and C_Spell.GetSpellName(id)
        if name and not secret(name) then return name end
    end
    return "Fishing"
end

local function channeling() return ns.C.cast().active end

-- Fishing poles: weapons (class 2) of subclass 20.
local function isPole(id)
    if not id or secret(id) then return false end
    local get = (C_Item and C_Item.GetItemInfoInstant) or GetItemInfoInstant
    if not get then return false end
    local _, _, _, _, _, classID, subClassID = get(id)
    return classID == 2 and subClassID == 20
end

function OneButton.poleOn()
    local id = GetInventoryItemID and GetInventoryItemID("player", 16)
    return isPole(id)
end

-- The pole to put on: the one you fished with last, else the first in your bags.
local function bagPole()
    local C = C_Container
    if not (C and C.GetContainerNumSlots) then return nil end
    local first
    for bag = 0, NUM_BAG_SLOTS or 4 do
        for slot = 1, C.GetContainerNumSlots(bag) or 0 do
            local id = C.GetContainerItemID(bag, slot)
            if isPole(id) then
                if id == CatchDB.pole then return id end
                first = first or id
            end
        end
    end
    return first
end

local function nextStep()
    local lure = ns.Lure and ns.Lure.best()
    local poleOn = OneButton.poleOn()
    local main = GetInventoryItemID and GetInventoryItemID("player", 16)
    if poleOn then
        CatchDB.pole = main
    elseif main and not secret(main) then                -- your weapons, for "done fishing"
        ns.C.char().weapons = { main = main, off = GetInventoryItemID("player", 17) }
    end
    local pole = not poleOn and bagPole()
    return Core.fishStep(channeling(), ns.Lure and ns.Lure.left(), lure ~= nil, GetTime() - appliedAt, poleOn,
        pole ~= nil), lure, pole
end

local buildDone                      -- below

local function keys(a, b)
    local list = {}
    local db = CatchDB.oneButton or {}
    a, b = db[a or "key"], db[b or "pad"]
    if a then list[#list + 1] = a end
    if b and b ~= a then list[#list + 1] = b end
    return list
end

local function itemName(id) return id and C_Item and C_Item.GetItemNameByID and C_Item.GetItemNameByID(id) end

-- The done button's macro: stop the cast, your weapons back on.
local function setDone()
    local w = ns.C.char() and ns.C.char().weapons or {}
    local main = w.main and (itemName(w.main) or ("item:%d"):format(w.main))
    local off = w.off and (itemName(w.off) or ("item:%d"):format(w.off))
    doneButton:SetAttribute("type", "macro")
    doneButton:SetAttribute("macrotext", Core.weaponMacro(main, off) or "/stopcasting")
    local icon = w.main and C_Item and C_Item.GetItemIconByID and C_Item.GetItemIconByID(w.main)
    doneButton.icon:SetTexture(icon or "Interface\\Icons\\INV_Sword_04")
end

-- What the button does now, and the keys bound to it. Out of combat only.
function OneButton.refresh()
    if not button then return end
    if InCombatLockdown() then dirty = true return end
    dirty = false
    local now, lure, pole = nextStep()
    if now == "pole" then
        local name = C_Item and C_Item.GetItemNameByID and C_Item.GetItemNameByID(pole)
        button:SetAttribute("type", "macro")
        button:SetAttribute("item", nil)
        button:SetAttribute("target-slot", nil)
        button:SetAttribute("macrotext", "/equipslot 16 " .. (name or ("item:%d"):format(pole)))
    elseif now == "lure" then
        button:SetAttribute("type", "item")
        button:SetAttribute("item", ("item:%d"):format(lure))
        button:SetAttribute("target-slot", 16)
    else
        button:SetAttribute("type", "macro")
        button:SetAttribute("item", nil)
        button:SetAttribute("target-slot", nil)
        button:SetAttribute("macrotext", "/cleartarget [nocombat]\n/cast " .. fishingSpell())
    end
    step = now
    setDone()
    ClearOverrideBindings(owner)
    for _, key in ipairs(keys()) do
        if now == "reel" then
            SetOverrideBinding(owner, true, key, "INTERACTTARGET")
        else
            SetOverrideBindingClick(owner, true, key, "CatchFishButton", "LeftButton")
        end
    end
    local fishing = ns.C.fishingNow()
    if fishing then
        for _, key in ipairs(keys("exitKey", "exitPad")) do
            SetOverrideBindingClick(owner, true, key, "CatchDoneButton", "LeftButton")
        end
    end
    -- the done icon: there and clickable while you fish
    doneButton:SetAlpha(fishing and 1 or 0)
    doneButton:EnableMouse(fishing and true or false)
    doneButton.fishing = fishing
    if Deadbeat and Deadbeat.RefreshSettings then Deadbeat.RefreshSettings() end
end

function OneButton.step() return step end

-- --- keys: set on Catch's page of Deadbeat's settings console --------------------------------------------

-- which = "fish" (key, pad) or "done" (exitKey, exitPad); slot = "key" or "pad"
local FIELDS = { fish = { key = "key", pad = "pad" }, done = { key = "exitKey", pad = "exitPad" } }

function OneButton.getKey(which, slot)
    return (CatchDB.oneButton or {})[FIELDS[which][slot]]
end

function OneButton.setKey(which, slot, value)
    if InCombatLockdown() then print_("keys can't change in combat") return end
    CatchDB.oneButton = CatchDB.oneButton or {}
    CatchDB.oneButton[FIELDS[which][slot]] = value
    OneButton.refresh()
end

function OneButton.nextText()
    return ({ reel = "reel in", lure = "put on your lure", pole = "put on your fishing pole" })[step] or "cast"
end

-- --- done fishing: an icon right of the creel, and the exit keys ----------------------------------------

local function doneTooltip(self)
    GameTooltip:SetOwner(self, "ANCHOR_TOP")
    GameTooltip:AddLine("Done fishing", P.bronze4[1], P.bronze4[2], P.bronze4[3])
    local w = ns.C.char() and ns.C.char().weapons
    local g = P.warmGrey
    if w and w.main then
        local main, off = itemName(w.main) or "your weapon", w.off and (itemName(w.off) or "your off-hand")
        GameTooltip:AddLine(main .. (off and (" + " .. off) or "") .. " back on", 1, 1, 1)
    else
        GameTooltip:AddLine("no weapon remembered yet: it's noted when you hold one", g[1], g[2], g[3])
    end
    local k = keys("exitKey", "exitPad")
    GameTooltip:AddLine(#k > 0 and ("Key: " .. table.concat(k, " / ")) or "Set a key: the gear on the bar, Catch", g[1], g[2], g[3])
    GameTooltip:Show()
end

buildDone = function()
    doneButton = CreateFrame("Button", "CatchDoneButton", UIParent, "SecureActionButtonTemplate")
    doneButton:SetSize(30, 30)
    doneButton:SetFrameStrata("MEDIUM")
    doneButton:SetPoint("LEFT", CatchCreel or CatchCastBar, "RIGHT", 14, 0)
    doneButton:RegisterForClicks("AnyUp", "AnyDown")
    doneButton:SetScript("PreClick", function() ns.C.done() end)
    doneButton:SetScript("PostClick", function() C_Timer.After(0.3, OneButton.refresh) end)
    doneButton:SetScript("OnEnter", doneTooltip)
    doneButton:SetScript("OnLeave", function() GameTooltip:Hide() end)
    local shadow = doneButton:CreateTexture(nil, "BACKGROUND")
    shadow:SetTexture("Interface\\AddOns\\Catch\\Textures\\glow")
    shadow:SetSize(52, 52)
    shadow:SetPoint("CENTER")
    shadow:SetVertexColor(0, 0, 0, 0.8)
    doneButton.icon = doneButton:CreateTexture(nil, "ARTWORK")
    doneButton.icon:SetSize(22, 22)
    doneButton.icon:SetPoint("CENTER")
    if doneButton.CreateMaskTexture then
        local mask = doneButton:CreateMaskTexture()
        mask:SetTexture("Interface\\CharacterFrame\\TempPortraitAlphaMask", "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
        mask:SetAllPoints(doneButton.icon)
        doneButton.icon:AddMaskTexture(mask)
    end
    local ring = doneButton:CreateTexture(nil, "ARTWORK", nil, 1)
    ring:SetTexture("Interface\\AddOns\\Catch\\Textures\\ring")
    ring:SetAllPoints()
    ring:SetVertexColor(P.bronze4[1], P.bronze4[2], P.bronze4[3], 0.9)
    local hi = doneButton:CreateTexture(nil, "HIGHLIGHT")
    hi:SetTexture("Interface\\AddOns\\Catch\\Textures\\glow")
    hi:SetSize(40, 40)
    hi:SetPoint("CENTER")
    hi:SetBlendMode("ADD")
    hi:SetVertexColor(1, 0.85, 0.55, 0.35)
    doneButton:SetAlpha(0)
    doneButton:EnableMouse(false)
end

-- --- from Catch.lua -------------------------------------------------------------------------------------

function OneButton.build()
    if not Deadbeat then return end
    K, P = Deadbeat.kit, Deadbeat.kit.P
    button = CreateFrame("Button", "CatchFishButton", UIParent, "SecureActionButtonTemplate")
    button:SetSize(1, 1)
    button:SetPoint("BOTTOMLEFT")
    button:RegisterForClicks("AnyUp", "AnyDown")    -- a binding click: the template acts on press or release by the cvar
    button:SetScript("PostClick", function()
        if step == "lure" then appliedAt = GetTime() end
        C_Timer.After(0.5, OneButton.refresh)
    end)
    buildDone()
    OneButton.refresh()
end

-- The first time you fish without a key set, Catch's settings page opens once.
function OneButton.onCast()
    OneButton.refresh()
    if #keys() == 0 and not CatchDB.oneButtonAsked and Deadbeat and Deadbeat.OpenSettings then
        CatchDB.oneButtonAsked = true
        Deadbeat.OpenSettings("Catch")
    end
end

function OneButton.onStop() C_Timer.After(0.2, OneButton.refresh) end

-- Every second: the lure ran out, a bag changed, combat ended.
function OneButton.tick()
    if not button or InCombatLockdown() then return end
    if dirty or nextStep() ~= step or ns.C.fishingNow() ~= doneButton.fishing then OneButton.refresh() end
end
