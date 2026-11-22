-- Catch's lure: how long the lure on your pole has left, as a round icon left of the cast bar with a ring that drains
-- (warm red and breathing in the last 2 minutes, greyed out with a red glow when it's gone). The icon is a button:
-- click it, or bind the macro "Catch Lure" that Catch keeps up to date, and the best lure in your bags goes on your pole.
-- It's a secure button, so it only changes out of combat. It's always there for the macro (before your first cast too);
-- you see it, and can click it, while you fish.
local _, ns = ...
local Core = ns.Core
local Lure = {}
ns.Lure = Lure

local LOW = 120                      -- seconds: the last 2 minutes warn
local SIZE = 36
local TEX = "Interface\\AddOns\\Catch\\Textures\\"
local RED = { 0.88, 0.40, 0.30 }     -- warm, not alarm red
local K, P
local btn
local state = { left = nil, total = nil, start = nil, lure = nil, dirty = true }

local function secret(v) return issecretvalue ~= nil and issecretvalue(v) end

-- Seconds left on the main hand's temporary enchant (your lure while you hold the pole), or nil.
function Lure.left()
    if not GetWeaponEnchantInfo then return nil end
    if ns.OneButton and not ns.OneButton.poleOn() then return nil end   -- a firestone on your weapon isn't a lure
    local has, expiration = GetWeaponEnchantInfo()
    if secret(has) or secret(expiration) or not has or not expiration then return nil end
    return expiration / 1000
end

local function bagItems()
    local items = {}
    local C = C_Container
    if not (C and C.GetContainerNumSlots) then return items end
    for bag = 0, NUM_BAG_SLOTS or 4 do
        for slot = 1, C.GetContainerNumSlots(bag) or 0 do
            local id = C.GetContainerItemID(bag, slot)
            if id and not secret(id) then items[id] = (items[id] or 0) + 1 end
        end
    end
    return items
end

local function itemName(id) return id and C_Item and C_Item.GetItemNameByID and C_Item.GetItemNameByID(id) end

-- The macro you bind (a gamepad button): a plain macro Catch keeps up to date with your best lure, in your general
-- macros. Plain /use lines, no button behind it (0.6.1's /click CatchLureButton didn't fire from a gamepad macro).
local MACRO = "Catch Lure"
local NO_LURE = '/run DEFAULT_CHAT_FRAME:AddMessage("|cffd8a446Catch|r: no lure in your bags")'

local function syncMacro(body)
    if not (GetMacroIndexByName and CreateMacro and EditMacro) then return end
    local i = GetMacroIndexByName(MACRO)
    if i == 0 then
        local general = GetNumMacros and GetNumMacros() or 0
        if general < (MAX_ACCOUNT_MACROS or 120) then pcall(CreateMacro, MACRO, "INV_MISC_QUESTIONMARK", body, false) end
    elseif GetMacroBody(i) ~= body then
        pcall(EditMacro, i, MACRO, nil, body)
    end
end

-- What a click does: the best lure in your bags, onto the main hand (slot 16). Only out of combat. The template's
-- "item onto a slot" (FishMate's way): a macro's "/use 16" tries to use the pole itself when the game didn't wait for
-- a target ("I can't use that").
local function setAction()
    if not btn or InCombatLockdown() then return end
    state.lure = Core.bestLure(bagItems(), ns.data.LURES)
    local use = state.lure and ("/use item:%d\n/use 16"):format(state.lure)
    btn:SetAttribute("type", state.lure and "item" or nil)
    btn:SetAttribute("item", state.lure and ("item:%d"):format(state.lure) or nil)
    btn:SetAttribute("target-slot", state.lure and 16 or nil)
    syncMacro(use and ("#showtooltip\n" .. use) or NO_LURE)
    local icon = state.lure and C_Item and C_Item.GetItemIconByID and C_Item.GetItemIconByID(state.lure)
    btn.icon:SetTexture(icon or "Interface\\Icons\\Trade_Fishing")
    state.dirty = false
end

local function tooltip(self)
    GameTooltip:SetOwner(self, "ANCHOR_TOP")
    GameTooltip:AddLine("Lure", P.bronze4[1], P.bronze4[2], P.bronze4[3])
    local left = Lure.left()
    GameTooltip:AddLine(left and ("%d:%02d left"):format(left / 60, left % 60) or "no lure on your pole", 1, 1, 1)
    local name = itemName(state.lure)
    local g = P.warmGrey
    if name then
        local n = C_Item.GetItemCount and C_Item.GetItemCount(state.lure) or 1
        GameTooltip:AddLine(("Click: put on %s  (%d in your bags)"):format(name, n), g[1], g[2], g[3])
    else
        GameTooltip:AddLine("no lure in your bags", RED[1], RED[2], RED[3])
    end
    GameTooltip:AddLine("One button for pole, lure, cast and reel: the gear on the bar, Catch", g[1], g[2], g[3])
    GameTooltip:Show()
end

local function build()
    K, P = Deadbeat.kit, Deadbeat.kit.P
    btn = CreateFrame("Button", "CatchLureButton", UIParent, "SecureActionButtonTemplate")
    btn:SetSize(SIZE, SIZE)
    btn:SetFrameStrata("MEDIUM")
    btn:SetPoint("RIGHT", CatchCastBar, "LEFT", -16, 0)
    -- Act on the release only: /click sends a release, and FlareUI turns on ActionButtonUseKeyDown (cast on key press),
    -- which would make the button wait for a press that /click never sends.
    btn:RegisterForClicks("AnyUp", "AnyDown")
    btn:SetAttribute("useOnKeyDown", false)
    btn:SetScript("PreClick", function(_, button, down)
        CatchDB.lureClicks = CatchDB.lureClicks or {}           -- what arrives, for finding out why /click didn't
        table.insert(CatchDB.lureClicks, { t = time(), button = tostring(button), down = tostring(down),
            keyDown = GetCVar and GetCVar("ActionButtonUseKeyDown"), item = btn:GetAttribute("item") })
        while #CatchDB.lureClicks > 10 do table.remove(CatchDB.lureClicks, 1) end
        if not state.lure then
            DEFAULT_CHAT_FRAME:AddMessage("|cffd8a446Catch|r: no lure in your bags")
        end
    end)
    btn:SetScript("OnEnter", tooltip)
    btn:SetScript("OnLeave", function() GameTooltip:Hide() end)

    btn.shadow = btn:CreateTexture(nil, "BACKGROUND")
    btn.shadow:SetTexture(TEX .. "glow")
    btn.shadow:SetSize(SIZE + 26, SIZE + 26)
    btn.shadow:SetPoint("CENTER")
    btn.shadow:SetVertexColor(0, 0, 0, 0.8)
    btn.glow = btn:CreateTexture(nil, "BACKGROUND", nil, 1)
    btn.glow:SetTexture(TEX .. "glow")
    btn.glow:SetSize(SIZE + 34, SIZE + 34)
    btn.glow:SetPoint("CENTER")
    btn.glow:SetBlendMode("ADD")
    btn.glow:SetVertexColor(RED[1], RED[2], RED[3])
    local breathe = btn.glow:CreateAnimationGroup()
    breathe:SetLooping("BOUNCE")
    local b = breathe:CreateAnimation("Alpha")
    b:SetFromAlpha(0.25) b:SetToAlpha(0.8) b:SetDuration(1.4) b:SetSmoothing("IN_OUT")
    btn.glow.anim = breathe
    btn.glow:Hide()

    btn.icon = btn:CreateTexture(nil, "ARTWORK")
    btn.icon:SetSize(SIZE - 10, SIZE - 10)
    btn.icon:SetPoint("CENTER")
    btn.icon:SetTexture("Interface\\Icons\\Trade_Fishing")
    if btn.CreateMaskTexture then
        local mask = btn:CreateMaskTexture()
        mask:SetTexture("Interface\\CharacterFrame\\TempPortraitAlphaMask", "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
        mask:SetAllPoints(btn.icon)
        btn.icon:AddMaskTexture(mask)
    end
    btn.track = btn:CreateTexture(nil, "ARTWORK", nil, 1)
    btn.track:SetTexture(TEX .. "ring")
    btn.track:SetAllPoints()
    btn.track:SetVertexColor(0.10, 0.08, 0.06, 0.9)
    btn.ring = CreateFrame("Cooldown", nil, btn, "CooldownFrameTemplate")
    btn.ring:SetAllPoints()
    btn.ring:SetSwipeTexture(TEX .. "ring")
    btn.ring:SetDrawEdge(false)
    btn.ring:SetDrawBling(false)
    btn.ring:SetHideCountdownNumbers(true)
    btn.ring:EnableMouse(false)
    local hi = btn:CreateTexture(nil, "HIGHLIGHT")
    hi:SetTexture(TEX .. "glow")
    hi:SetSize(SIZE + 10, SIZE + 10)
    hi:SetPoint("CENTER")
    hi:SetBlendMode("ADD")
    hi:SetVertexColor(1, 0.85, 0.55, 0.35)

    btn.text = K.text(btn, "GameFontHighlightSmall", { 1, 0.93, 0.80 })
    btn.text:SetPoint("TOP", btn, "BOTTOM", 0, -3)
    btn:SetAlpha(0)
    btn:EnableMouse(false)
end

-- Every second (Catch.lua's tick), on a cast and when your bags or gear change.
function Lure.update()
    if not btn then return end
    local fishing = ns.C.fishingNow()
    if not InCombatLockdown() then
        if state.dirty then setAction() end
        if fishing ~= btn.visible then            -- shown, invisible and click-through while you don't fish
            btn.visible = fishing
            btn:SetAlpha(fishing and 1 or 0)
            btn:EnableMouse(fishing and true or false)
        end
    end
    if not fishing then return end
    local left = Lure.left()
    state.total = Core.lureTotal(left, state.left, state.total or CatchDB.lureTotal)
    state.left = left
    if state.total then CatchDB.lureTotal = state.total end
    local kind = Core.lureState(left, state.total, LOW)
    if left then
        local start = GetTime() + left - state.total
        if not state.start or math.abs(start - state.start) > 1 then
            state.start = start
            btn.ring:SetCooldown(start, state.total)
        end
        btn.text:SetText(left >= 60 and ("%dm"):format(math.ceil(left / 60)) or ("%ds"):format(left))
    else
        state.start = nil
        btn.ring:Clear()
        btn.text:SetText("no lure")
    end
    local col = kind == "ok" and P.bronze4 or RED
    btn.ring:SetSwipeColor(col[1], col[2], col[3], 1)
    btn.text:SetTextColor(kind == "ok" and 1 or RED[1], kind == "ok" and 0.93 or RED[2], kind == "ok" and 0.80 or RED[3])
    btn.icon:SetDesaturated(kind == "none")
    btn.icon:SetAlpha(kind == "none" and 0.6 or 1)
    if kind == "ok" then
        btn.glow:Hide() btn.glow.anim:Stop()
    else
        btn.glow:Show()
        if not btn.glow.anim:IsPlaying() then btn.glow.anim:Play() end
    end
end

function Lure.best() return state.lure end
function Lure.build() if Deadbeat and CatchCastBar then build() end end
function Lure.bagsChanged() state.dirty = true Lure.update() end
