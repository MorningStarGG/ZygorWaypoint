local NS = _G.ZygorWaypointNS
local M = NS.Internal.Bridge

local bridge = M.bridge
local GetZygorPointer = NS.GetZygorPointer
local ReadWaypointCoords = NS.ReadWaypointCoords
local signature = NS.Signature

local ClearBridgeMirror = M.ClearBridgeMirror
local ResetManualAutoClearState = M.ResetManualAutoClearState

-- ============================================================
-- Destination queries
-- Read active manual destination and supporting lookups.
-- ============================================================

local function GetActiveManualDestination()
    local Z = NS.ZGV()
    local pointer = Z and Z.Pointer
    local destination = pointer and pointer.DestinationWaypoint
    if destination and destination.type == "manual" then
        return destination
    end
end

local function IsAutoClearableManualDestination(waypoint)
    if not waypoint or waypoint.type ~= "manual" or waypoint.manualnpcid then
        return false
    end

    if type(waypoint.zwpQueueIndex) == "number" then
        return type(NS.IsActiveQueuedManualDestination) == "function"
            and NS.IsActiveQueuedManualDestination(waypoint)
            or false
    end

    return true
end

local function GetWaypointDistanceYards(waypoint)
    if not waypoint then
        return
    end

    if type(NS.GetPlayerWaypointDistance) == "function" then
        local mapID, x, y = ReadWaypointCoords(waypoint)
        return NS.GetPlayerWaypointDistance(mapID, x, y)
    end
end

local function GetExternalManualSignature(destination)
    if type(destination) ~= "table" then
        return
    end

    if type(destination.zwpExternalSig) == "string" then
        return destination.zwpExternalSig
    end

    if type(signature) ~= "function" then
        return
    end

    local mapID, x, y = ReadWaypointCoords(destination)
    if type(mapID) ~= "number" or type(x) ~= "number" or type(y) ~= "number" then
        return
    end

    return signature(mapID, x, y)
end

-- ============================================================
-- Removal handling
-- Clean up a removed manual destination and chain the next route.
-- ============================================================

local function ResolveManualDestinationFollowup(destination)
    if type(destination) ~= "table" or destination.zwpExternalTomTom ~= true then
        return
    end

    local nextQueuedRoute
    if type(destination.zwpQueueIndex) == "number"
        and type(destination.zwpQueueSig) == "string"
        and type(NS.IsActiveQueuedManualDestination) == "function"
        and NS.IsActiveQueuedManualDestination(destination)
        and type(NS.ConsumeNextQueuedManualRoute) == "function"
    then
        nextQueuedRoute = NS.ConsumeNextQueuedManualRoute(destination)
    end

    local externalSig = GetExternalManualSignature(destination)
    if type(externalSig) == "string" and type(NS.RemoveExternalTomTomWaypointsBySig) == "function" then
        NS.RemoveExternalTomTomWaypointsBySig(externalSig)
    end

    return nextQueuedRoute
end

local function ApplyRemovedManualDestinationFollowup(nextQueuedRoute)
    ClearBridgeMirror()
    ResetManualAutoClearState()

    if type(nextQueuedRoute) == "table" and type(NS.RouteViaZygor) == "function" then
        NS.RouteViaZygor(
            nextQueuedRoute.mapID,
            nextQueuedRoute.x,
            nextQueuedRoute.y,
            nextQueuedRoute.title,
            nextQueuedRoute.meta
        )
        return true
    end

    return false
end

local function HandleRemovedManualDestination(destination)
    local nextQueuedRoute = ResolveManualDestinationFollowup(destination)
    return ApplyRemovedManualDestinationFollowup(nextQueuedRoute)
end

-- ============================================================
-- Auto-clear
-- Proximity-based automatic clearance of manual destinations.
-- ============================================================

local function ClearActiveManualDestination(visibilityState)
    local Z, pointer = GetZygorPointer()
    if not Z or not pointer then
        return false
    end

    local destination = GetActiveManualDestination()
    local nextQueuedRoute = ResolveManualDestinationFollowup(destination)

    if type(pointer.ClearWaypoints) ~= "function" then
        return false
    end

    NS.WithZygorManualClearSyncSuppressed(function()
        pointer:ClearWaypoints("manual")
    end)

    if not InCombatLockdown() then
        if type(pointer.HideArrow) == "function" then
            pointer:HideArrow()
        end
    end

    if ApplyRemovedManualDestinationFollowup(nextQueuedRoute) then
        return true
    end

    if visibilityState == "visible" and not InCombatLockdown() then
        if type(Z.ShowWaypoints) == "function" then
            Z:ShowWaypoints()
        end
        if type(pointer.UpdateArrowVisibility) == "function" then
            pointer:UpdateArrowVisibility()
        end
    end

    return true
end

local function MaybeAutoClearManualDestination(visibilityState)
    if not NS.IsManualWaypointAutoClearEnabled or not NS.IsManualWaypointAutoClearEnabled() then
        ResetManualAutoClearState()
        return false
    end

    local clearDistance = type(NS.GetManualWaypointClearDistance) == "function" and NS.GetManualWaypointClearDistance() or 0
    if clearDistance <= 0 then
        ResetManualAutoClearState()
        return false
    end

    local destination = GetActiveManualDestination()
    if not IsAutoClearableManualDestination(destination) then
        ResetManualAutoClearState()
        return false
    end

    local distance = GetWaypointDistanceYards(destination)
    if not distance then
        return false
    end

    if bridge.manualAutoClearWaypoint ~= destination then
        bridge.manualAutoClearWaypoint = destination
        bridge.manualAutoClearArmed = distance > clearDistance
        return false
    end

    if not bridge.manualAutoClearArmed then
        if distance > clearDistance then
            bridge.manualAutoClearArmed = true
        end
        return false
    end

    if distance > clearDistance then
        return false
    end

    return ClearActiveManualDestination(visibilityState)
end

M.GetActiveManualDestination = GetActiveManualDestination
M.ClearActiveManualDestination = ClearActiveManualDestination
M.MaybeAutoClearManualDestination = MaybeAutoClearManualDestination
M.HandleRemovedManualDestination = HandleRemovedManualDestination
