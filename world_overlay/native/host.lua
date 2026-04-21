local NS = _G.ZygorWaypointNS
local M = NS.Internal.WorldOverlayNative
local overlay = M.overlay
local target = M.target
local derived = M.derived
local transition = M.transition
local _settings = M.settingsSnapshot
local CFG = M.Config
local Signature = NS.Signature
local NormalizeWaypointTitle = NS.NormalizeWaypointTitle

local Clamp01 = M.Clamp01
local GetTargetDistance = M.GetTargetDistance
local UpdateArrivalState = M.UpdateArrivalState
local ResetModeTransition = M.ResetModeTransition
local ApplySuperTrackedFrameVisibility = M.ApplySuperTrackedFrameVisibility

local IsCurrentZygorSpecialTravelIconActive = NS.IsCurrentZygorSpecialTravelIconActive
local GetCurrentZygorSpecialTravelIconSignature = NS.GetCurrentZygorSpecialTravelIconSignature

local BuildUserWaypointPoint = NS.BuildUserWaypointPoint
local GetCurrentUserWaypoint = NS.GetCurrentUserWaypoint
local GetPlayerMapID = NS.GetPlayerMapID
local ResolveSettableUserWaypointTarget = NS.ResolveSettableUserWaypointTarget
local StabilizeCoordForUserWaypoint = NS.StabilizeCoordForUserWaypoint
local SharedUtilGlobal = rawget(_G, "SharedUtil")

local PINPOINT_TRANSITION_DURATION = CFG.PINPOINT_TRANSITION_DURATION
local CLAMP_THRESHOLD = CFG.CLAMP_THRESHOLD
local CLAMP_THRESHOLD_EXIT = CFG.CLAMP_THRESHOLD_EXIT
local CLAMP_MARGIN = 48
local CLAMP_MARGIN_EXIT = 80
local HOVER_FADE_ALPHA = CFG.HOVER_FADE_ALPHA
local HOVER_FADE_RESTORE = CFG.HOVER_FADE_RESTORE
local HOST_RESEED_COOLDOWN = 0.2
local INSTANCE_CAPABILITY_PROBE_COOLDOWN = 1.0
local SPECIAL_TRAVEL_SUPPRESS_HYSTERESIS = 2.0
local SAME_MAP_ROUTE_MATCH_TOLERANCE = 0.01

local ClearNativeNavigationHost
local IsNativeNavigationHostReady

-- ============================================================
-- Navigator state
-- ============================================================

local function ResetNavigatorClampState()
    overlay.navigatorClampActive = false
    derived.clamped = false
end

local function ResolveNavigatorClampState(anchorFrame, anchorX, anchorY)
    local wasClamped = overlay.navigatorClampActive == true
    local isClamped

    if anchorFrame and SharedUtilGlobal and type(SharedUtilGlobal.GetFrameDistanceFromScreenEdge) == "function" then
        local threshold = wasClamped and CLAMP_THRESHOLD_EXIT or CLAMP_THRESHOLD
        local edgeDistance = SharedUtilGlobal.GetFrameDistanceFromScreenEdge(anchorFrame)
        isClamped = type(edgeDistance) ~= "number" or edgeDistance < threshold
    else
        local left, bottom = UIParent:GetLeft() or 0, UIParent:GetBottom() or 0
        local right, top = UIParent:GetRight() or (left + UIParent:GetWidth()),
            UIParent:GetTop() or (bottom + UIParent:GetHeight())
        local margin = wasClamped and CLAMP_MARGIN_EXIT or CLAMP_MARGIN
        isClamped = not anchorX or not anchorY
            or anchorX <= left + margin or anchorX >= right - margin
            or anchorY <= bottom + margin or anchorY >= top - margin
    end

    overlay.navigatorClampActive = isClamped
    derived.clamped = isClamped
    return isClamped
end

local function IsWaypointPinpointTransition(fromMode, toMode)
    return (fromMode == "waypoint" and toMode == "pinpoint")
        or (fromMode == "pinpoint" and toMode == "waypoint")
end

local function StartModeTransition(fromMode, toMode)
    if not IsWaypointPinpointTransition(fromMode, toMode) then
        ResetModeTransition(toMode)
        return
    end

    if transition.active then
        if transition.fromMode == fromMode and transition.toMode == toMode then
            return
        end

        if transition.fromMode == toMode and transition.toMode == fromMode then
            local duration = transition.duration > 0 and transition.duration or PINPOINT_TRANSITION_DURATION
            local progress = Clamp01(transition.elapsed / duration)
            transition.fromMode = fromMode
            transition.toMode = toMode
            transition.duration = duration
            transition.elapsed = duration * (1 - progress)
            return
        end
    end

    transition.active = true
    transition.fromMode = fromMode
    transition.toMode = toMode
    transition.elapsed = 0
    transition.duration = PINPOINT_TRANSITION_DURATION
end

local function GetNavigatorAngle(y, x)
    return math.atan2(y, x)
end

-- ============================================================
-- Frame utilities
-- ============================================================

local function GetShownFrameCenter(frame)
    if not frame then
        return nil, nil
    end
    if not frame:IsShown() then
        return nil, nil
    end

    local x, y = frame:GetCenter()
    if not x or not y then
        return nil, nil
    end

    return x, y
end

local function UpdateCachedNavFrame()
    -- Nav frame is managed by NAVIGATION_FRAME_CREATED/DESTROYED events.
    -- This only returns the cached value; do not poll C_Navigation.GetFrame() here.
    return overlay.cachedNavFrame
end

local function HasActiveCachedNavFrame()
    local navFrame = overlay.cachedNavFrame or UpdateCachedNavFrame()
    if not navFrame then
        return false
    end

    return navFrame:IsShown() == true
end

local function ResolvePlacementAnchor()
    local navFrame = overlay.cachedNavFrame or UpdateCachedNavFrame()
    local navX, navY = GetShownFrameCenter(navFrame)
    if navX and navY then
        return navFrame, navFrame, navX, navY
    end

    return navFrame, nil, nil, nil
end

local function GetRootScreenOrigin()
    local root = overlay.root
    if root then
        local left, bottom = root:GetLeft(), root:GetBottom()
        if left and bottom then
            return left, bottom
        end
    end

    return UIParent:GetLeft() or 0, UIParent:GetBottom() or 0
end

-- ============================================================
-- Waypoint utilities
-- ============================================================

local function IsSameWaypoint(mapA, xA, yA, mapB, xB, yB)
    if type(mapA) ~= "number" or type(mapB) ~= "number" or mapA ~= mapB then
        return false
    end
    if type(xA) ~= "number" or type(yA) ~= "number" or type(xB) ~= "number" or type(yB) ~= "number" then
        return false
    end

    local epsilon = 1e-5
    return math.abs(xA - xB) <= epsilon and math.abs(yA - yB) <= epsilon
end

-- ============================================================
-- Instance capability
-- ============================================================

local function SetInstanceCapability(mapID, allowed, pending)
    overlay.instanceCapabilityMapID = mapID
    overlay.instanceCapabilityKnown = allowed ~= nil
    overlay.instanceCapabilityAllowed = allowed == true
    overlay.instanceCapabilityPending = pending == true
    overlay.instanceCapabilityLastProbeAt = GetTime()
end

local function ClearInstanceCapability()
    overlay.instanceCapabilityMapID = nil
    overlay.instanceCapabilityKnown = false
    overlay.instanceCapabilityAllowed = false
    overlay.instanceCapabilityPending = false
    overlay.instanceCapabilityLastProbeAt = 0
end

local function ResetInstanceCapabilityForMap(mapID)
    if type(mapID) ~= "number" or overlay.instanceCapabilityMapID ~= mapID then
        return
    end

    ClearInstanceCapability()
end

local function GetCurrentInstanceCapability(mapID)
    if type(mapID) ~= "number" then
        return nil, false
    end
    if overlay.instanceCapabilityMapID ~= mapID then
        return nil, false
    end

    if overlay.instanceCapabilityKnown then
        return overlay.instanceCapabilityAllowed == true, overlay.instanceCapabilityPending == true
    end

    return nil, overlay.instanceCapabilityPending == true
end

local function CanProbeInstanceCapability(mapID)
    if type(mapID) ~= "number" then
        return false
    end

    local _, pending = GetCurrentInstanceCapability(mapID)
    if pending then
        return false
    end

    local now = GetTime()
    if overlay.instanceCapabilityMapID == mapID
        and (now - (overlay.instanceCapabilityLastProbeAt or 0)) < INSTANCE_CAPABILITY_PROBE_COOLDOWN
    then
        return false
    end

    return true
end

local function IsCurrentMapInstanceWaypointCapable(targetMapID)
    if not select(1, IsInInstance()) then
        return true
    end
    if type(targetMapID) ~= "number" then
        return false
    end

    local allowed = GetCurrentInstanceCapability(targetMapID)
    return allowed == true
end

-- ============================================================
-- Host waypoint management
-- ============================================================

local function TrySetNativeHostWaypoint(mapID, x, y, title)
    local churn = NS.State.churn
    if churn and churn.active then
        churn.trySetHost = churn.trySetHost + 1
    end
    if not (type(mapID) == "number" and type(x) == "number" and type(y) == "number") then
        return false
    end
    if type(C_Map.SetUserWaypoint) ~= "function" then
        return false
    end

    local currentMapID, currentX, currentY = GetCurrentUserWaypoint()
    if IsSameWaypoint(mapID, x, y, currentMapID, currentX, currentY) then
        NS.Log("Native overlay host set", tostring(mapID), tostring(x), tostring(y), title or "", "existing")
        return true
    end

    local waypointPoint = BuildUserWaypointPoint(mapID, x, y)
    if not waypointPoint then
        return false
    end

    if churn and churn.active then
        churn.setUserWaypointCall = churn.setUserWaypointCall + 1
    end
    local ok = pcall(C_Map.SetUserWaypoint, waypointPoint)
    if not ok then
        return false
    end

    currentMapID, currentX, currentY = GetCurrentUserWaypoint()
    if IsSameWaypoint(mapID, x, y, currentMapID, currentX, currentY) then
        NS.Log("Native overlay host set", tostring(mapID), tostring(x), tostring(y), title or "", "confirmed")
        return true
    end

    -- Blizzard may apply the user waypoint and create the navigation frame on a later
    -- event tick. Treat a successful SetUserWaypoint call as a pending success and let
    -- USER_WAYPOINT_UPDATED / NAVIGATION_FRAME_CREATED complete the state transition.
    NS.Log("Native overlay host set pending", tostring(mapID), tostring(x), tostring(y), title or "")
    return true
end

local function ProbeInstanceWaypointCapability(targetMapID, targetX, targetY, title)
    if not CanProbeInstanceCapability(targetMapID) then
        local allowed = GetCurrentInstanceCapability(targetMapID)
        return allowed == true
    end

    SetInstanceCapability(targetMapID, nil, true)

    local ok = TrySetNativeHostWaypoint(targetMapID, targetX, targetY, title)
    if not ok then
        SetInstanceCapability(targetMapID, false, false)
        return false
    end

    local currentMapID, currentX, currentY = GetCurrentUserWaypoint()

    if IsSameWaypoint(targetMapID, targetX, targetY, currentMapID, currentX, currentY) then
        SetInstanceCapability(targetMapID, true, false)
        return true
    end

    return false
end

local function ClearResolvedHostTarget()
    overlay.resolvedHostTargetSig = nil
    overlay.resolvedHostMapID = nil
    overlay.resolvedHostX = nil
    overlay.resolvedHostY = nil
    overlay.resolvedHostWaypointSig = nil
end

local function RefreshResolvedHostTarget(force)
    if not target.active then
        ClearResolvedHostTarget()
        return nil, nil, nil, nil
    end

    if not force
        and overlay.resolvedHostTargetSig == target.sig
        and type(overlay.resolvedHostMapID) == "number"
        and type(overlay.resolvedHostX) == "number"
        and type(overlay.resolvedHostY) == "number"
    then
        return overlay.resolvedHostMapID, overlay.resolvedHostX, overlay.resolvedHostY, overlay.resolvedHostWaypointSig
    end

    local resolvedMapID = target.mapID
    local resolvedX = target.x
    local resolvedY = target.y

    local settableMapID, settableX, settableY = ResolveSettableUserWaypointTarget(resolvedMapID, resolvedX, resolvedY)
    if type(settableMapID) == "number" and type(settableX) == "number" and type(settableY) == "number" then
        resolvedMapID = settableMapID
        resolvedX = settableX
        resolvedY = settableY
    end

    resolvedX = StabilizeCoordForUserWaypoint(resolvedX)
    resolvedY = StabilizeCoordForUserWaypoint(resolvedY)

    if type(resolvedMapID) ~= "number" or type(resolvedX) ~= "number" or type(resolvedY) ~= "number" then
        ClearResolvedHostTarget()
        overlay.resolvedHostTargetSig = target.sig
        return nil, nil, nil, nil
    end

    overlay.resolvedHostTargetSig = target.sig
    overlay.resolvedHostMapID = resolvedMapID
    overlay.resolvedHostX = resolvedX
    overlay.resolvedHostY = resolvedY
    overlay.resolvedHostWaypointSig = Signature(resolvedMapID, resolvedX, resolvedY)
    return resolvedMapID, resolvedX, resolvedY, overlay.resolvedHostWaypointSig
end

local function GetStableTargetWaypoint()
    local targetMapID, targetX, targetY = RefreshResolvedHostTarget(false)
    return targetMapID, targetX, targetY
end

local function GetRouteValidationTargetForPlayerMap(playerMapID)
    if type(playerMapID) ~= "number" or not target.active then
        return nil, nil, nil
    end

    if playerMapID == target.mapID then
        return target.mapID, target.x, target.y
    end

    local hostMapID, hostX, hostY = RefreshResolvedHostTarget(false)
    if playerMapID == hostMapID then
        return hostMapID, hostX, hostY
    end

    return nil, nil, nil
end

-- ============================================================
-- Route validation
-- ============================================================

local function FormatModeTraceValue(value)
    if value == nil then
        return "nil"
    end
    if type(value) == "number" then
        return string.format("%.4f", value)
    end
    return tostring(value)
end

local function LogResolveModeDecision(mode, reason, ...)
    if not NS.Runtime.debug then
        return
    end
    if reason == "clamped" or reason == "clamped_navigator_disabled" then
        return
    end

    local sig = target.sig or "nil"
    if overlay.lastLogSig == sig
        and overlay.lastLogMode == mode
        and overlay.lastLogReason == reason then
        return
    end

    overlay.lastLogSig = sig
    overlay.lastLogMode = mode
    overlay.lastLogReason = reason

    local messageParts = {
        "Native overlay mode",
        tostring(mode or "nil"),
        tostring(reason or "nil"),
    }
    for i = 1, select("#", ...) do
        messageParts[#messageParts + 1] = FormatModeTraceValue(select(i, ...))
    end
    NS.Log(unpack(messageParts))
end

local function GetSameMapRouteEquivalenceReason(validationX, validationY, nextX, nextY, waypointDescription)
    if target.kind ~= "route" then
        return
    end

    local normalizedTargetTitle = NormalizeWaypointTitle(target.title)
    local normalizedWaypointDescription = NormalizeWaypointTitle(waypointDescription)

    if type(normalizedTargetTitle) == "string"
        and normalizedTargetTitle ~= ""
        and normalizedTargetTitle == normalizedWaypointDescription
    then
        return "same_map_route_title_match"
    end

    if type(validationX) ~= "number" or type(validationY) ~= "number"
        or type(nextX) ~= "number" or type(nextY) ~= "number"
    then
        return
    end

    local dx = validationX - nextX
    local dy = validationY - nextY
    if (dx * dx + dy * dy) <= (SAME_MAP_ROUTE_MATCH_TOLERANCE * SAME_MAP_ROUTE_MATCH_TOLERANCE) then
        return "same_map_route_near_match"
    end
end

local function GetNativeHostRouteValidation()
    if not target.active then
        return false, "inactive", nil, nil, nil, nil
    end
    local playerMapID = GetPlayerMapID()
    if type(playerMapID) ~= "number" then
        return false, "no_player_map", nil, nil, nil, nil
    end

    local nextX, nextY, waypointDescription = C_SuperTrack.GetNextWaypointForMap(playerMapID)
    local validationMapID, validationX, validationY = GetRouteValidationTargetForPlayerMap(playerMapID)
    if type(validationMapID) == "number" then
        if type(nextX) ~= "number" or type(nextY) ~= "number" then
            return true, "same_map_no_next_waypoint", playerMapID, nextX, nextY, waypointDescription
        end

        local exactMatch = IsSameWaypoint(playerMapID, nextX, nextY, validationMapID, validationX, validationY)
        if exactMatch then
            return true, "same_map_exact_match", playerMapID, nextX, nextY, waypointDescription
        end

        local routeEquivalenceReason = GetSameMapRouteEquivalenceReason(
            validationX,
            validationY,
            nextX,
            nextY,
            waypointDescription
        )
        if routeEquivalenceReason then
            return true, routeEquivalenceReason, playerMapID, nextX, nextY, waypointDescription
        end

        return false, "same_map_next_waypoint_mismatch", playerMapID, nextX, nextY, waypointDescription
    end

    local valid = type(nextX) == "number" and type(nextY) == "number" and waypointDescription ~= nil
    if valid then
        return true, "cross_map_has_next_waypoint", playerMapID, nextX, nextY, waypointDescription
    end

    -- Some routed cross-map legs keep a live navigation frame even when
    -- GetNextWaypointForMap(playerMapID) does not report a player-map waypoint.
    if HasActiveCachedNavFrame() then
        return true, "cross_map_nav_frame_fallback", playerMapID, nextX, nextY, waypointDescription
    end

    return false, "cross_map_missing_next_waypoint", playerMapID, nextX, nextY, waypointDescription
end

local function IsNativeHostRouteValid()
    local valid = GetNativeHostRouteValidation()
    return valid
end

local function MarkNativeRouteProbe(valid, playerMapID)
    overlay.routeProbeSig = target.sig
    overlay.routeProbePlayerMapID = playerMapID
    overlay.routeProbeValid = valid == true
end

local function IsNativeHostRouteProbeBlocked()
    if HasActiveCachedNavFrame() then
        return false
    end
    if overlay.routeProbeValid ~= false or overlay.routeProbeSig ~= target.sig then
        return false
    end

    local playerMapID = GetPlayerMapID()
    return type(playerMapID) == "number" and overlay.routeProbePlayerMapID == playerMapID
end

local function ShouldThrottleNativeHostEnsure(targetMapID, targetX, targetY)
    local now = GetTime()
    if overlay.lastEnsureSig ~= target.sig then
        return false
    end
    if not IsSameWaypoint(targetMapID, targetX, targetY, overlay.lastEnsureMapID, overlay.lastEnsureX, overlay.lastEnsureY) then
        return false
    end

    return (now - (overlay.lastEnsureTime or 0)) < HOST_RESEED_COOLDOWN
end

local function RecordNativeHostEnsure(targetMapID, targetX, targetY)
    overlay.lastEnsureSig = target.sig
    overlay.lastEnsureMapID = targetMapID
    overlay.lastEnsureX = targetX
    overlay.lastEnsureY = targetY
    overlay.lastEnsureTime = GetTime()
end

local function IsNativeHostFullySatisfied(targetMapID, targetX, targetY)
    local currentMapID, currentX, currentY = GetCurrentUserWaypoint()

    local hostMatches = IsSameWaypoint(targetMapID, targetX, targetY, overlay.hostMapID, overlay.hostX, overlay.hostY)
    local userWaypointMatches = IsSameWaypoint(targetMapID, targetX, targetY, currentMapID, currentX, currentY)
    local superTracked = C_SuperTrack.IsSuperTrackingUserWaypoint()

    return hostMatches and userWaypointMatches and superTracked
end

local function IsNativeSpecialTravelSuppressed()
    local specialTravelSig = GetCurrentZygorSpecialTravelIconSignature()
    local active = IsCurrentZygorSpecialTravelIconActive()
    if active then
        overlay.lastSpecialTravelAt = GetTime()
        overlay.lastSpecialTravelSig = specialTravelSig
        return true
    end
    return GetTime() - (overlay.lastSpecialTravelAt or 0) < SPECIAL_TRAVEL_SUPPRESS_HYSTERESIS
end

-- ============================================================
-- Navigation host lifecycle
-- ============================================================

local function EnsureNativeNavigationHost()
    local churn = NS.State.churn
    if churn and churn.active then
        churn.ensureHost = churn.ensureHost + 1
    end
    if not target.active then
        return false
    end
    if IsNativeSpecialTravelSuppressed() then
        ClearNativeNavigationHost()
        return false
    end

    -- Cheap gates first: bail before running the expensive GetStableTargetWaypoint
    -- remap when the probe is blocked or we're inside the reseed cooldown for the
    -- same target signature.
    if IsNativeHostRouteProbeBlocked() then
        return false
    end

    local nowForSig = GetTime()
    if overlay.lastEnsureSig == target.sig
        and (nowForSig - (overlay.lastEnsureTime or 0)) < HOST_RESEED_COOLDOWN
    then
        if churn and churn.active then
            churn.hostThrottled = churn.hostThrottled + 1
        end
        return IsNativeNavigationHostReady()
    end

    local targetMapID, targetX, targetY = GetStableTargetWaypoint()
    if not (type(targetMapID) == "number" and type(targetX) == "number" and type(targetY) == "number") then
        return false
    end

    if not IsCurrentMapInstanceWaypointCapable(targetMapID) then
        if not ProbeInstanceWaypointCapability(targetMapID, targetX, targetY, target.title) then
            return false
        end
    end

    if IsNativeHostFullySatisfied(targetMapID, targetX, targetY) then
        ApplySuperTrackedFrameVisibility()
        return true
    end

    if ShouldThrottleNativeHostEnsure(targetMapID, targetX, targetY) then
        if churn and churn.active then
            churn.hostThrottled = churn.hostThrottled + 1
        end
        return IsNativeNavigationHostReady()
    end

    RecordNativeHostEnsure(targetMapID, targetX, targetY)

    if not TrySetNativeHostWaypoint(targetMapID, targetX, targetY, target.title) then
        overlay.hostMapID = nil
        overlay.hostX = nil
        overlay.hostY = nil
        NS.Log("Native overlay host unavailable", tostring(target.mapID), tostring(target.x), tostring(target.y))
        return false
    end

    overlay.hostMapID = targetMapID
    overlay.hostX = targetX
    overlay.hostY = targetY
    overlay.routeProbeSig = nil
    overlay.routeProbePlayerMapID = nil
    overlay.routeProbeValid = nil

    if not C_SuperTrack.IsSuperTrackingUserWaypoint() then
        C_SuperTrack.SetSuperTrackedUserWaypoint(true)
        NS.Log("Native overlay host supertrack", "true")
        if not C_SuperTrack.IsSuperTrackingUserWaypoint() then
            -- Map immediately rejected the supertrack — it does not support user waypoint
            -- navigation. Clear the host state we just recorded and block further retries
            -- until the player changes maps or the target changes.
            overlay.hostMapID = nil
            overlay.hostX = nil
            overlay.hostY = nil
            local playerMapID = GetPlayerMapID()
            if type(playerMapID) == "number" then
                MarkNativeRouteProbe(false, playerMapID)
            end
            NS.Log("Native overlay host supertrack rejected — map unsupported, probe blocked")
            return false
        end
    end

    ApplySuperTrackedFrameVisibility()
    return true
end

ClearNativeNavigationHost = function()
    local hostMapID, hostX, hostY = overlay.hostMapID, overlay.hostX, overlay.hostY
    overlay.hostMapID = nil
    overlay.hostX = nil
    overlay.hostY = nil
    ResetNavigatorClampState()
    overlay.routeProbeSig = nil
    overlay.routeProbePlayerMapID = nil
    overlay.routeProbeValid = nil
    if not (type(hostMapID) == "number" and type(hostX) == "number" and type(hostY) == "number") then
        return
    end

    local currentMapID, currentX, currentY = GetCurrentUserWaypoint()
    if not IsSameWaypoint(hostMapID, hostX, hostY, currentMapID, currentX, currentY) then
        return
    end

    if C_SuperTrack.IsSuperTrackingUserWaypoint() then
        C_SuperTrack.SetSuperTrackedUserWaypoint(false)
    end

    C_Map.ClearUserWaypoint()

    NS.Log("Native overlay host cleared", tostring(hostMapID), tostring(hostX), tostring(hostY))
    ApplySuperTrackedFrameVisibility()
end

-- Called by NAVIGATION_FRAME_CREATED event: WoW has a routable path to target.
function NS.OnNativeNavFrameCreated()
    overlay.cachedNavFrame = C_Navigation.GetFrame()
    overlay.routeProbeSig = nil
    overlay.routeProbePlayerMapID = nil
    overlay.routeProbeValid = nil
    local targetMapID, targetX, targetY = GetStableTargetWaypoint()
    if target.active and type(targetMapID) == "number" then
        SetInstanceCapability(targetMapID, true, false)
    end
    if target.active and overlay.cachedNavFrame then
        if not IsNativeHostFullySatisfied(targetMapID, targetX, targetY) then
            EnsureNativeNavigationHost()
        else
            ApplySuperTrackedFrameVisibility()
        end
        NS.UpdateNativeWorldOverlay()
    end
end

-- Called by NAVIGATION_FRAME_DESTROYED event: no routable path, hide everything.
function NS.OnNativeNavFrameDestroyed()
    overlay.cachedNavFrame = nil
    local targetMapID = GetStableTargetWaypoint()
    if target.active and type(targetMapID) == "number" then
        local allowed, pending = GetCurrentInstanceCapability(targetMapID)
        if pending then
            SetInstanceCapability(targetMapID, false, false)
        elseif allowed == nil then
            ResetInstanceCapabilityForMap(targetMapID)
        end
    end
    ClearNativeNavigationHost()
    local playerMapID = GetPlayerMapID()
    if target.active and type(playerMapID) == "number" then
        MarkNativeRouteProbe(false, playerMapID)
    end
    NS.UpdateNativeWorldOverlay()
end

IsNativeNavigationHostReady = function()
    local hostMapID, hostX, hostY = overlay.hostMapID, overlay.hostX, overlay.hostY
    if not (type(hostMapID) == "number" and type(hostX) == "number" and type(hostY) == "number") then
        return false
    end

    return C_SuperTrack.IsSuperTrackingUserWaypoint()
end

-- ============================================================
-- Mode resolution
-- ============================================================

local function ResolveMode()
    derived.distance = GetTargetDistance()
    UpdateArrivalState(derived.distance)

    if not target.active or not UIParent:IsShown() then
        ResetNavigatorClampState()
        overlay.arrivalHideActive = false
        LogResolveModeDecision("hidden", not target.active and "inactive_target" or "ui_hidden")
        return "hidden"
    end

    if IsNativeSpecialTravelSuppressed() then
        ClearNativeNavigationHost()
        ResetNavigatorClampState()
        overlay.arrivalHideActive = false
        LogResolveModeDecision("hidden", "special_travel")
        return "hidden"
    end

    if not IsNativeNavigationHostReady() then
        if not IsNativeHostRouteProbeBlocked() then
            EnsureNativeNavigationHost()
        end
        if not IsNativeNavigationHostReady() then
            local churn = NS.State.churn
            if churn and churn.active then
                churn.hostNotReady = churn.hostNotReady + 1
            end
            ResetNavigatorClampState()
            overlay.arrivalHideActive = false
            LogResolveModeDecision("hidden", "host_not_ready", overlay.hostMapID, overlay.hostX, overlay.hostY)
            return "hidden"
        end
    end

    -- No nav frame means WoW cannot route to this target — stay hidden.
    if not overlay.cachedNavFrame then
        ResetNavigatorClampState()
        overlay.arrivalHideActive = false
        LogResolveModeDecision("hidden", "no_nav_frame", target.mapID, target.x, target.y)
        return "hidden"
    end

    local routeValid, routeReason, playerMapID, nextX, nextY, waypointDescription = GetNativeHostRouteValidation()
    if type(playerMapID) == "number" then
        MarkNativeRouteProbe(routeValid, playerMapID)
    end
    if not routeValid then
        ResetNavigatorClampState()
        overlay.arrivalHideActive = false
        LogResolveModeDecision("hidden", "route_invalid", routeReason, playerMapID, nextX, nextY, waypointDescription,
            target.mapID, target.x, target.y)
        return "hidden"
    end

    local navFrame, anchorFrame, anchorX, anchorY = ResolvePlacementAnchor()
    derived.navFrame = navFrame
    derived.anchorFrame = anchorFrame

    if not anchorX or not anchorY then
        anchorX, anchorY = overlay.lastAnchorX, overlay.lastAnchorY
    else
        overlay.lastAnchorX, overlay.lastAnchorY = anchorX, anchorY
    end
    derived.anchorX, derived.anchorY = anchorX, anchorY

    local hideBase = _settings.worldOverlayHideDistance
    local hideThreshold = hideBase
    if type(derived.distance) == "number" and derived.distance <= hideThreshold then
        overlay.arrivalHideActive = true
        LogResolveModeDecision("hidden", "hide_distance", derived.distance, hideThreshold)
        return "hidden"
    end
    overlay.arrivalHideActive = false

    local navFrameForClamp = derived.anchorFrame
    local isClamped = ResolveNavigatorClampState(navFrameForClamp, anchorX, anchorY)

    if isClamped then
        if _settings.worldOverlayNavigatorShow and anchorX and anchorY then
            LogResolveModeDecision("navigator", "clamped", anchorX, anchorY, derived.distance)
            return "navigator"
        end
        LogResolveModeDecision("hidden", "clamped_navigator_disabled", anchorX, anchorY)
        return "hidden"
    end

    local pinpointBase = _settings.worldOverlayPinpointDistance
    local pinpointThreshold = pinpointBase
    if type(derived.distance) == "number" and derived.distance <= pinpointThreshold then
        if _settings.worldOverlayPinpointMode == "disabled" then
            LogResolveModeDecision("hidden", "pinpoint_disabled", derived.distance, pinpointThreshold)
            return "hidden"
        end
        LogResolveModeDecision("pinpoint", "within_pinpoint_distance", derived.distance,
            pinpointThreshold)
        return "pinpoint"
    end

    if _settings.worldOverlayWaypointMode == "disabled" then
        LogResolveModeDecision("hidden", "waypoint_disabled", derived.distance)
        return "hidden"
    end
    LogResolveModeDecision("waypoint", "default", derived.distance)
    return "waypoint"
end

local function GetHoverMultiplier()
    if overlay.hovered and _settings.worldOverlayFadeOnHover then
        return HOVER_FADE_ALPHA
    end
    return HOVER_FADE_RESTORE
end

M.IsWaypointPinpointTransition = IsWaypointPinpointTransition
M.StartModeTransition = StartModeTransition
M.GetNavigatorAngle = GetNavigatorAngle
M.GetShownFrameCenter = GetShownFrameCenter
M.UpdateCachedNavFrame = UpdateCachedNavFrame
M.ResolvePlacementAnchor = ResolvePlacementAnchor
M.GetRootScreenOrigin = GetRootScreenOrigin
M.IsSameWaypoint = IsSameWaypoint
M.TrySetNativeHostWaypoint = TrySetNativeHostWaypoint
M.GetStableTargetWaypoint = GetStableTargetWaypoint
M.ClearResolvedHostTarget = ClearResolvedHostTarget
M.RefreshResolvedHostTarget = RefreshResolvedHostTarget
M.IsNativeSpecialTravelSuppressed = IsNativeSpecialTravelSuppressed
M.IsNativeHostRouteValid = IsNativeHostRouteValid
M.IsNativeNavigationHostReady = IsNativeNavigationHostReady
M.EnsureNativeNavigationHost = EnsureNativeNavigationHost
M.ResolveMode = ResolveMode
M.GetHoverMultiplier = GetHoverMultiplier
M.ClearNativeNavigationHost = ClearNativeNavigationHost
M.IsCurrentMapInstanceWaypointCapable = IsCurrentMapInstanceWaypointCapable
M.ProbeInstanceWaypointCapability = ProbeInstanceWaypointCapability
