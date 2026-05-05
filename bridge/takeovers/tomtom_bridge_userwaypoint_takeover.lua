local NS = _G.AzerothWaypointNS
local state = NS.State
NS.Internal.BlizzardTakeovers = NS.Internal.BlizzardTakeovers or {}
local M = NS.Internal.BlizzardTakeovers

local GetActiveManualDestination = NS.GetActiveManualDestination
local ClearActiveManualDestination = NS.ClearActiveManualDestination
local GetGuideVisibilityState = NS.GetGuideVisibilityState
local ReadWaypointCoords = NS.ReadWaypointCoords
local Signature = NS.Signature

local USER_WAYPOINT_SUPERTRACK_CLEAR_SUPPRESSION_SECONDS = 0.15
local WAYPOINT_LOCATION_DATA_PROVIDER_STACK_MATCH = "blizzard_sharedmapdataproviders\\waypointlocationdataprovider.lua"
local WOWPRO_STACK_MATCH = "interface\\addons\\wowpro\\"

-- ============================================================
-- Local helpers
-- ============================================================

local function GetTimeSafe()
    return type(GetTime) == "function" and GetTime() or 0
end

local function IsManualClickAskMode()
    return type(NS.GetManualClickQueueMode) == "function" and NS.GetManualClickQueueMode() == "ask"
end

local function IsWaypointLocationDataProviderStack()
    if type(debugstack) ~= "function" then
        return false
    end

    local ok, stack = pcall(debugstack, 3, 10, 10)
    if not ok or type(stack) ~= "string" or stack == "" then
        return false
    end

    stack = stack:gsub("/", "\\"):lower()
    return stack:find(WAYPOINT_LOCATION_DATA_PROVIDER_STACK_MATCH, 1, true) ~= nil
end

local function IsWoWProUserWaypointStack()
    if type(debugstack) ~= "function" then
        return false
    end

    local ok, stack = pcall(debugstack, 3, 16, 16)
    if not ok or type(stack) ~= "string" or stack == "" then
        return false
    end

    stack = stack:gsub("/", "\\"):lower()
    return stack:find(WOWPRO_STACK_MATCH, 1, true) ~= nil
end

local function ArmUserWaypointSupertrackClearSuppression(mapID, x, y)
    local takeoverState = state.bridgeTakeover or {}
    state.bridgeTakeover = takeoverState
    takeoverState.suppressNextUserWaypointSupertrackClear = {
        expiresAt = GetTimeSafe() + USER_WAYPOINT_SUPERTRACK_CLEAR_SUPPRESSION_SECONDS,
        mapID = mapID,
        x = x,
        y = y,
    }
end

local function ConsumeUserWaypointSupertrackClearSuppression()
    local takeoverState = state.bridgeTakeover
    local suppression = type(takeoverState) == "table"
        and takeoverState.suppressNextUserWaypointSupertrackClear
        or nil
    if type(suppression) ~= "table" then
        return false
    end

    if GetTimeSafe() > (tonumber(suppression.expiresAt) or 0) then
        takeoverState.suppressNextUserWaypointSupertrackClear = nil
        return false
    end
    if not IsWaypointLocationDataProviderStack() then
        return false
    end

    takeoverState.suppressNextUserWaypointSupertrackClear = nil
    return true
end

local function GetWaypointSignature(mapID, x, y)
    if type(Signature) ~= "function" then
        return nil
    end
    if type(mapID) ~= "number" or type(x) ~= "number" or type(y) ~= "number" then
        return nil
    end
    return Signature(mapID, x, y)
end

local function ResolveMapTitle(mapID, x, y)
    local mapInfo = type(C_Map) == "table"
        and type(C_Map.GetMapInfo) == "function"
        and C_Map.GetMapInfo(mapID)
        or nil
    local mapName = mapInfo and mapInfo.name or nil
    if type(mapName) == "string" and mapName ~= "" then
        if type(x) == "number" and type(y) == "number" then
            return string.format("%s %.0f, %.0f", mapName, x * 100, y * 100)
        end
        return mapName
    end
    if type(mapID) == "number" then
        if type(x) == "number" and type(y) == "number" then
            return string.format("Waypoint %d %.0f, %.0f", mapID, x * 100, y * 100)
        end
        return "Waypoint " .. tostring(mapID)
    end
    return "Waypoint"
end

-- ============================================================
-- Destination metadata
-- ============================================================

local function BuildBlizzardUserWaypointMeta(mapID, x, y, context)
    local sig = GetWaypointSignature(mapID, x, y)
    return NS.BuildRouteMeta(NS.BuildUserWaypointIdentity(mapID, x, y, { sig = sig }), {
        manualQuestID = type(context) == "table" and context.questID or nil,
        searchKind = type(context) == "table" and context.searchKind or nil,
        sourceAddon = type(context) == "table" and context.sourceAddon or nil,
    })
end

local function GetBlizzardUserWaypointSignature(destination)
    if type(destination) ~= "table" or destination.type ~= "manual" then
        return nil
    end
    local identity = type(destination.identity) == "table" and destination.identity or nil
    if not (type(identity) == "table" and identity.kind == "blizzard_user_waypoint") then
        return nil
    end
    if type(identity) == "table" and type(identity.sig) == "string" then
        return identity.sig
    end
    local mapID, x, y = ReadWaypointCoords(destination)
    return GetWaypointSignature(mapID, x, y)
end

local function GetActiveBlizzardUserWaypointManual()
    local destination = GetActiveManualDestination and GetActiveManualDestination() or nil
    local sig = GetBlizzardUserWaypointSignature(destination)
    if not sig then
        return nil, nil
    end
    return destination, sig
end

-- ============================================================
-- Adoption and clear
-- ============================================================

local function ClearBlizzardUserWaypointBackedManual(clearReason)
    local destination, sig = GetActiveBlizzardUserWaypointManual()
    if not destination then
        return false
    end
    local visibilityState = GetGuideVisibilityState and GetGuideVisibilityState() or nil
    if type(ClearActiveManualDestination) ~= "function" then
        return false
    end
    NS.Log("Blizzard waypoint takeover clear",
        tostring(sig), tostring(clearReason or "system"))
    return ClearActiveManualDestination(visibilityState, clearReason or "system")
end

local function HandleExplicitBlizzardUserWaypointSet(mapID, x, y)
    if IsWoWProUserWaypointStack() then
        if type(NS.IsRoutingEnabled) == "function" and not NS.IsRoutingEnabled() then
            return false
        end
        if type(NS.ScheduleGuideProviderEvaluation) == "function" then
            NS.ScheduleGuideProviderEvaluation("wowpro", "WoWProSetUserWaypoint")
        end
        NS.Log("WoWPro user waypoint ignored as guide provider signal",
            tostring(mapID), tostring(x), tostring(y))
        return true
    end

    NS.ClearPendingGuideTakeover()
    local context = type(NS.GetWorldQuestTabUserWaypointContext) == "function"
        and NS.GetWorldQuestTabUserWaypointContext(mapID, x, y)
        or nil
    context = context
        or (type(NS.GetGenericAddonBlizzardTakeoverContext) == "function"
            and NS.GetGenericAddonBlizzardTakeoverContext("user_waypoint"))
        or nil
    local title = type(context) == "table" and context.title or nil
    title = title or ResolveMapTitle(mapID, x, y)
    local meta = BuildBlizzardUserWaypointMeta(mapID, x, y, context)
    local clickSource = "blizzard_user_waypoint"
    if type(context) == "table" and context.sourceAddon == "WorldQuestTab" then
        clickSource = "worldquesttab_user_waypoint"
    elseif type(context) == "table" and type(context.sourceAddon) == "string" then
        clickSource = "addon_user_waypoint"
    end
    return NS.RequestManualRoute(mapID, x, y, title, meta, {
        clickContext = {
            source = clickSource,
            explicit = true,
        },
    })
end

local function HandleExplicitBlizzardUserWaypointCleared()
    if type(NS.ClearPendingGuideTakeoverForClear) == "function" then
        NS.ClearPendingGuideTakeoverForClear()
    else
        NS.ClearPendingGuideTakeover()
    end
    local cancelledPending = type(NS.CancelPendingManualRoute) == "function"
        and NS.CancelPendingManualRoute("explicit_user_waypoint_clear")
        or false
    local mapID, x, y = nil, nil, nil
    if type(NS.GetCurrentUserWaypoint) == "function" then
        mapID, x, y = NS.GetCurrentUserWaypoint()
    end
    local destination = GetActiveManualDestination and GetActiveManualDestination() or nil
    if type(destination) == "table"
        and type(NS.RouteIdentityMatchesHost) == "function"
        and NS.RouteIdentityMatchesHost(destination, mapID, x, y)
        and type(ClearActiveManualDestination) == "function"
    then
        return ClearActiveManualDestination("explicit") or cancelledPending
    end
    return ClearBlizzardUserWaypointBackedManual("explicit") or cancelledPending
end

-- ============================================================
-- Hook installation
-- CRITICAL: Hook-based, NOT event-based. hooksecurefunc reads debugstack() at
-- the C_Map.SetUserWaypoint call site. USER_WAYPOINT_UPDATED fires after return
-- and loses the call stack, so the hook must live here.
-- ============================================================

function NS.InstallUserWaypointHooks()
    local takeoverState = state.bridgeTakeover or {}
    if takeoverState.userWaypointHooksInstalled then
        return
    end
    takeoverState.userWaypointHooksInstalled = true
    state.bridgeTakeover = takeoverState

    if type(C_Map) == "table" and type(C_Map.SetUserWaypoint) == "function" then
        local originalSetUserWaypoint = C_Map.SetUserWaypoint
        takeoverState.originalSetUserWaypoint = takeoverState.originalSetUserWaypoint or originalSetUserWaypoint
        C_Map.SetUserWaypoint = function(uiMapPoint, ...) ---@diagnostic disable-line: duplicate-set-field
            if type(NS.IsInternalUserWaypointMutation) == "function" and NS.IsInternalUserWaypointMutation() then
                return originalSetUserWaypoint(uiMapPoint, ...)
            end
            if not NS.IsExplicitBlizzardUserWaypointCall() then
                return originalSetUserWaypoint(uiMapPoint, ...)
            end

            local mapID, x, y = NS.ReadUiMapPointCoords(uiMapPoint)
            if type(mapID) ~= "number" or type(x) ~= "number" or type(y) ~= "number" then
                return originalSetUserWaypoint(uiMapPoint, ...)
            end

            local adopted = NS.SafeCall(HandleExplicitBlizzardUserWaypointSet, mapID, x, y)
            if adopted then
                if IsManualClickAskMode() then
                    ArmUserWaypointSupertrackClearSuppression(mapID, x, y)
                end
                return
            end
            return originalSetUserWaypoint(uiMapPoint, ...)
        end
    end

    if type(C_SuperTrack) == "table" and type(C_SuperTrack.SetSuperTrackedUserWaypoint) == "function" then
        local originalSetSuperTrackedUserWaypoint = C_SuperTrack.SetSuperTrackedUserWaypoint
        takeoverState.originalSetSuperTrackedUserWaypoint = takeoverState.originalSetSuperTrackedUserWaypoint
            or originalSetSuperTrackedUserWaypoint
        C_SuperTrack.SetSuperTrackedUserWaypoint = function(enabled, ...) ---@diagnostic disable-line: duplicate-set-field
            if type(NS.IsInternalSuperTrackMutation) == "function" and NS.IsInternalSuperTrackMutation() then
                return originalSetSuperTrackedUserWaypoint(enabled, ...)
            end
            if enabled == false and ConsumeUserWaypointSupertrackClearSuppression() then
                NS.Log("Blizzard waypoint supertrack clear suppressed", "ask")
                return
            end
            return originalSetSuperTrackedUserWaypoint(enabled, ...)
        end
    end

    if type(C_Map) == "table" and type(C_Map.ClearUserWaypoint) == "function" then
        local originalClearUserWaypoint = C_Map.ClearUserWaypoint
        takeoverState.originalClearUserWaypoint = takeoverState.originalClearUserWaypoint or originalClearUserWaypoint
        C_Map.ClearUserWaypoint = function(...) ---@diagnostic disable-line: duplicate-set-field
            if type(NS.IsInternalUserWaypointMutation) == "function" and NS.IsInternalUserWaypointMutation() then
                return originalClearUserWaypoint(...)
            end
            if not NS.IsExplicitBlizzardUserWaypointCall() then
                return originalClearUserWaypoint(...)
            end

            local cleared = NS.SafeCall(HandleExplicitBlizzardUserWaypointCleared)
            if cleared then
                return
            end
            return originalClearUserWaypoint(...)
        end
    end
end
