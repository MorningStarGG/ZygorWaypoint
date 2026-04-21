local NS = _G.ZygorWaypointNS
local C = NS.Constants
local state = NS.State

NS.Internal = NS.Internal or {}
NS.Internal.Bridge = NS.Internal.Bridge or {}

local M = NS.Internal.Bridge

state.bridge = state.bridge or {
    lastSig = nil,
    lastTitle = nil,
    lastContentSig = nil,
    lastUID = nil,
    lastUIDOwned = nil,
    lastAppliedSource = nil,
    lastAppliedKind = nil,
    lastAppliedMapID = nil,
    lastAppliedX = nil,
    lastAppliedY = nil,
    lastAppliedAt = 0,
    lastRouteTravelReportedAt = 0,
    lastArrowSeenAt = 0,
    lastArrowSeenMap = nil,
    manualRouteHoldDestinationSig = nil,
    manualRouteHoldPendingSig = nil,
    manualRouteHoldStartedAt = 0,
    lastAppliedGuideRoutePresentation = false,
    pendingFallbackSwitch = {
        sig = nil,
        count = 0,
    },
    lastSuppressLogAt = 0,
    lastSuppressLogSig = nil,
    unifiedDragHooked = false,
    zygorTickHooked = false,
    zygorTravelReportedHooked = false,
    zygorArrowHooked = false,
    zygorGuideGuardsHooked = false,
    arrowVisibilityPolicyHooked = false,
    tomtomTextSuppressionHooked = false,
    tomtomArrowVisualSuppressed = false,
    guideVisibilityState = nil,
    lifecycleMode = nil,
    cinematicActive = false,
    heartbeatFrame = nil,
    heartbeatElapsed = 0,
    manualAutoClearWaypoint = nil,
    manualAutoClearArmed = false,
    suppressTomTomClearSync = 0,
    suppressTomTomArrowRoutingSync = 0,
    suppressZygorManualClearSync = 0,
    pendingZygorManualRemoveIntent = nil,
    zygorDropdownIntentHooked = false,
    zygorManualClearHooked = false,
    coalescedTickPending = false,
}

local bridge = state.bridge
if type(bridge.pendingFallbackSwitch) ~= "table" then
    bridge.pendingFallbackSwitch = { sig = nil, count = 0 }
end

local GetZygorPointer = NS.GetZygorPointer
local GetArrowFrame = NS.GetArrowFrame
local ClearWorldOverlay = NS.ClearWorldOverlay
local GetTomTom = NS.GetTomTom
local GetTomTomArrow = NS.GetTomTomArrow
local ReadWaypointCoords = NS.ReadWaypointCoords

M.bridge = bridge

local function IsArrowWaypointSource(src)
    return src == "pointer.ArrowFrame.waypoint" or src == "pointer.arrow.waypoint"
end

local function IsFallbackSource(src)
    return src == "pointer.DestinationWaypoint"
end

local function HasBridgeMirrorState()
    local pendingFallbackSwitch = bridge.pendingFallbackSwitch
    return bridge.lastUID or bridge.lastSig or bridge.lastAppliedSource
        or (type(pendingFallbackSwitch) == "table" and pendingFallbackSwitch.sig)
end

-- ============================================================
-- Arrow alignment and drag
-- ============================================================

local function GetCustomSkinAutoYOffset()
    local skin = type(NS.GetSkinChoice) == "function" and NS.GetSkinChoice() or C.SKIN_DEFAULT
    local scale = C.SCALE_DEFAULT
    if type(NS.GetArrowScale) == "function" then
        scale = tonumber(NS.GetArrowScale()) or C.SCALE_DEFAULT
    end

    local yOffset = (skin == C.SKIN_STEALTH) and 3 or 0
    local grow = scale - 1.0
    if grow > 0 then
        yOffset = yOffset + (grow * 12)
        if yOffset > 15 then
            yOffset = 15
        end
    end
    return yOffset
end

function NS.AlignTomTomToZygor()
    local _, _, zygorFrame = GetArrowFrame()
    if not zygorFrame then return end

    local tomArrow = GetTomTomArrow()
    if not tomArrow then return end

    local yOffset = 10
    if type(NS.GetSkinChoice) == "function" and NS.GetSkinChoice() ~= C.SKIN_DEFAULT then
        yOffset = GetCustomSkinAutoYOffset()
    end

    tomArrow:ClearAllPoints()
    tomArrow:SetPoint("CENTER", zygorFrame, "CENTER", 0, yOffset)
end

function NS.HookUnifiedArrowDrag()
    if bridge.unifiedDragHooked then return end

    local _, _, zFrame = GetArrowFrame()
    if not zFrame then return end

    local tFrame = GetTomTomArrow()
    if not tFrame then return end

    zFrame:SetMovable(true)
    zFrame:EnableMouse(true)

    tFrame:SetMovable(false)
    tFrame:EnableMouse(false)

    bridge.unifiedDragHooked = true
end

-- ============================================================
-- Arrow visibility policy
-- ============================================================

function NS.EnsureGuideArrowVisibilityPolicy()
    if bridge.arrowVisibilityPolicyHooked then return end

    local Z, P = GetZygorPointer()
    if not Z or not Z.db or not P then return end

    local ctrl = P.ArrowFrameCtrl
    if not ctrl or type(ctrl.GetScript) ~= "function" then return end

    local origOnUpdate = ctrl:GetScript("OnUpdate")
    if type(origOnUpdate) ~= "function" then return end

    -- Wrap the ArrowFrameCtrl OnUpdate to temporarily force hidearrowwithguide = false
    -- during each evaluation. This prevents Zygor from hiding its arrow when the guide
    -- panel is closed, without permanently modifying Zygor's saved settings.
    -- During cinematics we step aside and let Zygor's own value pass through so its
    -- cinematic suppression logic can work normally.
    local profile = Z.db.profile
    ctrl:SetScript("OnUpdate", function(self, elapsed)
        if bridge.cinematicActive then
            return origOnUpdate(self, elapsed)
        end
        local saved = profile.hidearrowwithguide
        profile.hidearrowwithguide = false
        origOnUpdate(self, elapsed)
        profile.hidearrowwithguide = saved
    end)

    -- Guard ArrowFrame_ShowSpellArrow during combat: its inner icon is a
    -- SecureActionButton, so Show()/SetAttribute on it are blocked in combat
    -- and raise ADDON_ACTION_BLOCKED. Skip the call entirely under lockdown;
    -- it will resume naturally on the next OnUpdate after combat ends.
    if type(P.ArrowFrame_ShowSpellArrow) == "function" and not bridge.spellArrowCombatGuardHooked then
        local origShowSpellArrow = P.ArrowFrame_ShowSpellArrow
        P.ArrowFrame_ShowSpellArrow = function(pself, waypoint)
            if InCombatLockdown() then return end
            return origShowSpellArrow(pself, waypoint)
        end
        bridge.spellArrowCombatGuardHooked = true
    end

    bridge.arrowVisibilityPolicyHooked = true
end

function NS.SyncTomTomArrowVisualSuppression(forceApply)
    local tomArrow = GetTomTomArrow()
    if not tomArrow then
        local changed = bridge.tomtomArrowVisualSuppressed ~= false
        bridge.tomtomArrowVisualSuppressed = false
        return changed
    end

    local shouldSuppress = type(NS.IsCurrentZygorSpecialTravelIconActive) == "function"
        and NS.IsCurrentZygorSpecialTravelIconActive()
        or false
    local changed = bridge.tomtomArrowVisualSuppressed ~= shouldSuppress

    if not changed and not forceApply then
        return false
    end

    if shouldSuppress then
        if tomArrow:IsShown() then
            tomArrow:Hide()
        end
    else
        local hasMirrorState = bridge.lastUID ~= nil
        if hasMirrorState and not tomArrow:IsShown() then
            tomArrow:Show()
        end
    end

    bridge.tomtomArrowVisualSuppressed = shouldSuppress
    return changed
end

-- ============================================================
-- Waypoint state management
-- ============================================================

local function ResetAppliedWaypointState()
    bridge.lastSig = nil
    bridge.lastTitle = nil
    bridge.lastContentSig = nil
    bridge.lastUID = nil
    bridge.lastUIDOwned = nil
    bridge.lastAppliedSource = nil
    bridge.lastAppliedKind = nil
    bridge.lastAppliedMapID = nil
    bridge.lastAppliedX = nil
    bridge.lastAppliedY = nil
    bridge.lastAppliedAt = 0
    bridge.lastAppliedGuideRoutePresentation = false
    bridge.lastRouteTravelReportedAt = 0
    bridge.lastArrowSeenAt = 0
    bridge.lastArrowSeenMap = nil
    bridge.manualRouteHoldDestinationSig = nil
    bridge.manualRouteHoldPendingSig = nil
    bridge.manualRouteHoldStartedAt = 0
    if type(bridge.pendingFallbackSwitch) == "table" then
        bridge.pendingFallbackSwitch.sig = nil
        bridge.pendingFallbackSwitch.count = 0
    end
    bridge.lastSuppressLogAt = 0
    bridge.lastSuppressLogSig = nil
end

local function ResetManualAutoClearState()
    bridge.manualAutoClearWaypoint = nil
    bridge.manualAutoClearArmed = false
end

-- ============================================================
-- Sync suppression wrappers
-- ============================================================

function NS.WithTomTomClearSyncSuppressed(fn)
    if type(fn) ~= "function" then
        return
    end

    bridge.suppressTomTomClearSync = bridge.suppressTomTomClearSync + 1
    local ok, result1, result2, result3, result4 = pcall(fn)
    bridge.suppressTomTomClearSync = math.max(bridge.suppressTomTomClearSync - 1, 0)
    if not ok then
        error(result1)
    end

    return result1, result2, result3, result4
end

function NS.WithTomTomArrowRoutingSyncSuppressed(fn)
    if type(fn) ~= "function" then
        return
    end

    bridge.suppressTomTomArrowRoutingSync = bridge.suppressTomTomArrowRoutingSync + 1
    local ok, result1, result2, result3, result4 = pcall(fn)
    bridge.suppressTomTomArrowRoutingSync = math.max(bridge.suppressTomTomArrowRoutingSync - 1, 0)
    if not ok then
        error(result1)
    end

    return result1, result2, result3, result4
end

function NS.WithZygorManualClearSyncSuppressed(fn)
    if type(fn) ~= "function" then
        return
    end

    bridge.suppressZygorManualClearSync = bridge.suppressZygorManualClearSync + 1
    local ok, result1, result2, result3, result4 = pcall(fn)
    bridge.suppressZygorManualClearSync = math.max(bridge.suppressZygorManualClearSync - 1, 0)
    if not ok then
        error(result1)
    end

    return result1, result2, result3, result4
end

-- ============================================================
-- Manual remove intent
-- ============================================================

local function SnapshotExplicitManualRemoveDestination(destination)
    if type(destination) ~= "table" or destination.zwpExternalTomTom ~= true then
        return
    end

    local mapID, x, y = ReadWaypointCoords(destination)

    return {
        type = "manual",
        title = destination.title,
        zwpExternalTomTom = true,
        zwpExternalSig = destination.zwpExternalSig,
        zwpSourceAddon = destination.zwpSourceAddon,
        zwpQueueIndex = destination.zwpQueueIndex,
        zwpQueueSig = destination.zwpQueueSig,
        map = mapID,
        mapid = mapID,
        mapID = mapID,
        m = mapID,
        x = x,
        y = y,
    }
end

function NS.MarkPendingZygorManualRemoveIntent(destination)
    local pending = SnapshotExplicitManualRemoveDestination(destination)
    bridge.pendingZygorManualRemoveIntent = pending
    if type(pending) ~= "table" then
        return
    end

    NS.After(0, function()
        if bridge.pendingZygorManualRemoveIntent == pending then
            bridge.pendingZygorManualRemoveIntent = nil
        end
    end)

    return pending
end

function NS.ConsumePendingZygorManualRemoveIntent()
    local pending = bridge.pendingZygorManualRemoveIntent
    bridge.pendingZygorManualRemoveIntent = nil
    return pending
end

-- ============================================================
-- Bridge mirror operations
-- ============================================================

local function RemoveBridgeWaypoint(skipUserWaypointClear)
    local tomtom = GetTomTom()
    if bridge.lastUID and tomtom then
        if bridge.lastUIDOwned == false and type(tomtom.ClearCrazyArrowPoint) == "function" then
            local arrowProfile = tomtom.profile and tomtom.profile.arrow or nil
            local savedSetClosest = arrowProfile and arrowProfile.setclosest or false
            if arrowProfile then
                arrowProfile.setclosest = false
            end
            tomtom:ClearCrazyArrowPoint(false)
            if arrowProfile then
                arrowProfile.setclosest = savedSetClosest
            end
        elseif type(tomtom.RemoveWaypoint) == "function" then
            NS.WithTomTomClearSyncSuppressed(function()
                tomtom:RemoveWaypoint(bridge.lastUID)
            end)
        end
    end
    bridge.lastUID = nil
    bridge.lastUIDOwned = nil

    if not skipUserWaypointClear and C_Map and C_Map.HasUserWaypoint and C_Map.HasUserWaypoint() then
        C_SuperTrack.SetSuperTrackedUserWaypoint(false)
        C_Map.ClearUserWaypoint()
    end
end

local function ClearBridgeMirror()
    RemoveBridgeWaypoint()
    if type(ClearWorldOverlay) == "function" then
        ClearWorldOverlay()
    end
    ResetAppliedWaypointState()
end

local function ClearHiddenGuideWaypoints()
    if InCombatLockdown() then return end
    local Z = NS.ZGV()
    if not Z then return end

    if type(Z.ShowWaypoints) == "function" then
        Z:ShowWaypoints("clear")
    end

    local P = Z.Pointer
    if P and P.ArrowFrame and type(P.HideArrow) == "function" then
        P:HideArrow()
    end
end

local function RefreshVisibleGuideWaypoints()
    if InCombatLockdown() then return end
    local Z = NS.ZGV()
    if not Z then return end

    if type(Z.ShowWaypoints) == "function" then
        Z:ShowWaypoints()
    end

    local P = Z.Pointer
    if P and type(P.UpdateArrowVisibility) == "function" then
        P:UpdateArrowVisibility()
    end
end

M.SyncTomTomArrowVisualSuppression = NS.SyncTomTomArrowVisualSuppression
M.IsArrowWaypointSource = IsArrowWaypointSource
M.IsFallbackSource = IsFallbackSource
M.HasBridgeMirrorState = HasBridgeMirrorState
M.ResetManualAutoClearState = ResetManualAutoClearState
M.RemoveBridgeWaypoint = RemoveBridgeWaypoint
M.ClearBridgeMirror = ClearBridgeMirror
M.ClearHiddenGuideWaypoints = ClearHiddenGuideWaypoints
M.RefreshVisibleGuideWaypoints = RefreshVisibleGuideWaypoints
