local NS = _G.ZygorWaypointNS
local M = NS.Internal.Bridge

local bridge = M.bridge
local GetArrowFrame = NS.GetArrowFrame
local GetZygorPointer = NS.GetZygorPointer
local GetTomTomArrow = NS.GetTomTomArrow
local ReadWaypointCoords = NS.ReadWaypointCoords
local signature = NS.Signature

local HasBridgeMirrorState = M.HasBridgeMirrorState
local ClearBridgeMirror = M.ClearBridgeMirror
local ClearHiddenGuideWaypoints = M.ClearHiddenGuideWaypoints
local RefreshVisibleGuideWaypoints = M.RefreshVisibleGuideWaypoints
local ResetManualAutoClearState = M.ResetManualAutoClearState
local GetActiveManualDestination = M.GetActiveManualDestination
local ClearActiveManualDestination = M.ClearActiveManualDestination
local MaybeAutoClearManualDestination = M.MaybeAutoClearManualDestination

-- ============================================================
-- Display target helpers
-- ============================================================

local function IsDisplayTextVisible(displayState)
    local snapshot = displayState and displayState.snapshot
    return snapshot and snapshot.textVisible == true or false
end

local function ResolveDisplayTarget(displayState)
    local displayTarget = displayState and displayState.target
    if not displayTarget or not displayTarget.visible then
        return
    end

    local mapID = displayTarget.map
    local x = displayTarget.x
    local y = displayTarget.y
    local title = displayTarget.title
    if not (mapID and x and y and title) then
        return
    end

    return mapID, x, y, title, displayTarget.source, displayTarget.kind
end

local function GetBridgeMode(visibilityState)
    if not visibilityState then
        return
    end

    if visibilityState == "cinematic" then
        return "cinematic"
    end

    if visibilityState == "hidden-override" then
        return "hidden-override"
    end

    if visibilityState == "hidden-idle" then
        return "hidden-idle"
    end

    return "visible-guide"
end

-- ============================================================
-- Bridge lifecycle
-- ============================================================

local function TransitionBridgeLifecycleMode(nextMode)
    local previousMode = bridge.lifecycleMode
    if nextMode ~= previousMode then
        bridge.lifecycleMode = nextMode
        NS.Log("Bridge mode", tostring(previousMode), "->", tostring(nextMode))
    end

    return nextMode
end

local function ResolveCanonicalTarget(mode, displayState, fallbackM, fallbackX, fallbackY, fallbackTitle, fallbackSource, fallbackKind)
    local displayM, displayX, displayY, displayTitle, displaySource, displayKind = ResolveDisplayTarget(displayState)

    if mode == "cinematic" or mode == "hidden-idle" then
        return
    end

    if not IsDisplayTextVisible(displayState) then
        return
    end

    if displayKind then
        return displayM, displayX, displayY, displayTitle, displaySource, displayKind, true
    end

    if fallbackM and fallbackX and fallbackY and fallbackTitle and fallbackKind then
        return fallbackM, fallbackX, fallbackY, fallbackTitle, fallbackSource, fallbackKind, false
    end
end

local function ShouldExtractFallbackTarget(mode, displayState)
    if mode == "cinematic" or mode == "hidden-idle" then
        return false
    end

    if not IsDisplayTextVisible(displayState) then
        return false
    end

    local displayM, displayX, displayY, displayTitle, displaySource, displayKind = ResolveDisplayTarget(displayState)
    return not (displayM and displayX and displayY and displayTitle and displaySource and displayKind)
end

-- ============================================================
-- Hidden override waypoint
-- ============================================================

local function IsHiddenOverrideWaypoint(waypoint)
    return waypoint and (waypoint.type == "manual" or waypoint.type == "corpse")
end

local function GetHiddenOverrideWaypoint()
    local _, pointer, arrowFrame = GetArrowFrame()
    if not pointer then
        _, pointer = GetZygorPointer()
    end
    if not pointer then
        return
    end

    local waypoint = pointer.DestinationWaypoint
    if IsHiddenOverrideWaypoint(waypoint) then
        return waypoint
    end

    waypoint = arrowFrame and arrowFrame.waypoint
    if IsHiddenOverrideWaypoint(waypoint) then
        return waypoint
    end

    waypoint = pointer.arrow and pointer.arrow.waypoint
    if IsHiddenOverrideWaypoint(waypoint) then
        return waypoint
    end

    waypoint = pointer.current_waypoint
    if IsHiddenOverrideWaypoint(waypoint) then
        return waypoint
    end

    waypoint = type(pointer.waypoints) == "table" and pointer.waypoints[1] or nil
    if IsHiddenOverrideWaypoint(waypoint) then
        return waypoint
    end
end

local function IsAllowedHiddenOverrideWaypoint(waypoint)
    if not waypoint then return true end
    if IsHiddenOverrideWaypoint(waypoint) then return true end

    local manualDestination = GetActiveManualDestination()
    if not manualDestination then
        return false
    end

    if waypoint == manualDestination then
        return true
    end

    if waypoint.type == "route" then
        return true
    end

    local surrogate = waypoint.surrogate_for
    if surrogate and surrogate.type == "manual" then
        return true
    end

    local sourceWaypoint = waypoint.pathnode and waypoint.pathnode.waypoint
    if sourceWaypoint and sourceWaypoint.type == "manual" then
        return true
    end

    return false
end

local function IsGuideGoalWaypoint(waypoint)
    if not waypoint then return false end
    if waypoint.goal then return true end

    local surrogate = waypoint.surrogate_for
    if surrogate and surrogate.goal then
        return true
    end

    local pathWaypoint = waypoint.pathnode and waypoint.pathnode.waypoint
    if pathWaypoint and pathWaypoint.goal then
        return true
    end

    return false
end

local function ShowHiddenOverrideWaypoint(pointer, waypoint)
    if not pointer or not waypoint then
        return
    end
    if InCombatLockdown() then return end

    if waypoint.type == "manual" and type(pointer.FindTravelPath) == "function" then
        return pointer:FindTravelPath(waypoint)
    end
    if type(pointer.ShowArrow) == "function" then
        return pointer:ShowArrow(waypoint)
    end
end

local function RestoreHiddenOverrideArrowIfNeeded()
    local _, pointer = GetZygorPointer()
    if not pointer then return end

    local destination = GetHiddenOverrideWaypoint()
    if not destination then return end

    local current = pointer.ArrowFrame and pointer.ArrowFrame.waypoint
    if destination.type == "manual" and not IsGuideGoalWaypoint(current) then
        return
    end
    if destination.type == "corpse" and current and current.type == "corpse" then
        return
    end

    ShowHiddenOverrideWaypoint(pointer, destination)
end

local function HideUnexpectedHiddenGuideArrow()
    if InCombatLockdown() then return end
    local _, pointer, arrowFrame = GetArrowFrame()
    if not pointer then return end

    local waypoint = arrowFrame and arrowFrame.waypoint
    if waypoint and not IsHiddenOverrideWaypoint(waypoint) and type(pointer.HideArrow) == "function" then
        pointer:HideArrow()
    end
end

-- ============================================================
-- Guide visibility state machine
-- ============================================================

local function IsGuideHiddenState(visibilityState)
    return visibilityState and visibilityState ~= "visible"
end

local function GetGuideVisibilityState()
    local Z = NS.ZGV()
    if not Z or not Z.Pointer or not Z.Frame then
        return
    end

    if bridge.cinematicActive then
        return "cinematic"
    end

    if not UIParent:IsShown() then
        return "cinematic"
    end

    if Z.Frame:IsVisible() then
        return "visible"
    end

    if GetHiddenOverrideWaypoint() then
        return "hidden-override"
    end

    return "hidden-idle"
end

-- ============================================================
-- TomTom mirror sync
-- ============================================================

local function DoesExternalTomTomClearMatchActiveManual(uid, destination)
    if type(uid) ~= "table" or type(destination) ~= "table" then
        return false
    end

    if uid.fromZWP or destination.zwpExternalTomTom ~= true then
        return false
    end

    local uidMapID = uid[1]
    local uidX = uid[2]
    local uidY = uid[3]
    if type(uidMapID) ~= "number" or type(uidX) ~= "number" or type(uidY) ~= "number" then
        return false
    end

    if destination.zwpExternalSig then
        return signature(uidMapID, uidX, uidY) == destination.zwpExternalSig
    end

    local destinationMapID, destinationX, destinationY = ReadWaypointCoords(destination)
    if type(destinationMapID) ~= "number"
        or type(destinationX) ~= "number" or type(destinationY) ~= "number"
    then
        return false
    end

    return signature(uidMapID, uidX, uidY) == signature(destinationMapID, destinationX, destinationY)
end

local function ApplyGuideVisibilityTransition(nextState, previousState)
    if nextState == "hidden-idle" then
        ClearHiddenGuideWaypoints()
        ClearBridgeMirror()
    elseif nextState == "cinematic" then
        -- Preserve mirrored state during cinematics and resync when UI returns.
    elseif nextState == "visible" and previousState and previousState ~= "visible" then
        RefreshVisibleGuideWaypoints()
    elseif nextState == "hidden-override" and previousState == "cinematic" then
        local _, pointer = GetZygorPointer()
        local destination = GetHiddenOverrideWaypoint()
        if pointer and destination then
            ShowHiddenOverrideWaypoint(pointer, destination)
        end
    end

    if previousState == "cinematic" and bridge.unifiedDragHooked then
        local tomArrow = GetTomTomArrow()
        if tomArrow then
            tomArrow:EnableMouse(false)
        end
    end
end

local function TransitionGuideVisibilityState(nextState)
    local previousState = bridge.guideVisibilityState
    if nextState == previousState then
        return nextState
    end

    bridge.guideVisibilityState = nextState
    NS.Log("Guide visibility state", tostring(previousState), "->", nextState)
    ApplyGuideVisibilityTransition(nextState, previousState)
    return nextState
end

local function SyncGuideVisibilityState()
    NS.EnsureGuideArrowVisibilityPolicy()

    local current = GetGuideVisibilityState()
    if not current then
        return
    end
    return TransitionGuideVisibilityState(current)
end

local function HandleLifecycleState(visibilityState, mode)
    if MaybeAutoClearManualDestination(visibilityState) then
        return true
    end

    if mode == "cinematic" then
        return true
    end

    if mode == "hidden-idle" then
        if HasBridgeMirrorState() then
            ClearBridgeMirror()
        end
        HideUnexpectedHiddenGuideArrow()
        return true
    end

    if mode == "hidden-override" then
        RestoreHiddenOverrideArrowIfNeeded()
    end

    return false
end

function NS.SetCinematicActive(active)
    local nextState = active and true or false
    if bridge.cinematicActive == nextState then
        return
    end

    bridge.cinematicActive = nextState
    if nextState then
        TransitionGuideVisibilityState("cinematic")
        return
    end

    NS.After(0, NS.TickUpdate)
end

local function FindReplacementUID(removedUID, destination)
    if type(removedUID) ~= "table" then
        return nil
    end

    local mapID, x, y = removedUID[1], removedUID[2], removedUID[3]
    if type(mapID) ~= "number" or type(x) ~= "number" or type(y) ~= "number" then
        return nil
    end

    if type(destination) ~= "table" or destination.zwpExternalTomTom ~= true then
        return nil
    end

    local sig = signature(mapID, x, y)
    if type(destination.zwpExternalSig) == "string" and destination.zwpExternalSig ~= sig then
        return nil
    end

    local replacementUID = NS.GetExternalTomTomWaypointBySig(sig)
    if replacementUID == nil or replacementUID == removedUID then
        return nil
    end

    return replacementUID
end

function NS.HandleTomTomMirrorCleared(uid)
    local destination = GetActiveManualDestination()
    local matchesActiveExternalManual = DoesExternalTomTomClearMatchActiveManual(uid, destination)
    if not uid or (uid ~= bridge.lastUID and not matchesActiveExternalManual) then
        return false
    end

    if bridge.suppressTomTomClearSync > 0 then
        return false
    end

    local replacementUID = FindReplacementUID(uid, destination)
    if replacementUID then
        NS.Log("External waypoint replaced, retargeting bridge carrier", tostring(uid[1]), tostring(uid[2]), tostring(uid[3]))
        if bridge.lastUID == uid and bridge.lastUIDOwned == false then
            bridge.lastUID = replacementUID
            local tomtom = NS.GetTomTom and NS.GetTomTom()
            if tomtom and type(tomtom.SetCrazyArrow) == "function" then
                NS.WithTomTomArrowRoutingSyncSuppressed(function()
                    tomtom:SetCrazyArrow(replacementUID, 15, bridge.lastTitle)
                end)
            end
        end
        return false
    end

    local visibilityState = SyncGuideVisibilityState()
    if not visibilityState then
        return false
    end

    if destination then
        return ClearActiveManualDestination(visibilityState)
    end

    ClearBridgeMirror()
    ResetManualAutoClearState()
    return true
end

M.IsDisplayTextVisible = IsDisplayTextVisible
M.GetBridgeMode = GetBridgeMode
M.TransitionBridgeLifecycleMode = TransitionBridgeLifecycleMode
M.ResolveCanonicalTarget = ResolveCanonicalTarget
M.ShouldExtractFallbackTarget = ShouldExtractFallbackTarget
M.GetHiddenOverrideWaypoint = GetHiddenOverrideWaypoint
M.IsAllowedHiddenOverrideWaypoint = IsAllowedHiddenOverrideWaypoint
M.ShowHiddenOverrideWaypoint = ShowHiddenOverrideWaypoint
M.IsGuideHiddenState = IsGuideHiddenState
M.GetGuideVisibilityState = GetGuideVisibilityState
M.SyncGuideVisibilityState = SyncGuideVisibilityState
M.HandleLifecycleState = HandleLifecycleState
