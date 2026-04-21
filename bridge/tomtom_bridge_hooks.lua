local NS = _G.ZygorWaypointNS
local C = NS.Constants
local M = NS.Internal.Bridge

local bridge = M.bridge
local GetTomTom = NS.GetTomTom
local GetTomTomArrow = NS.GetTomTomArrow
local ReadWaypointCoords = NS.ReadWaypointCoords
local IsSameLocation = NS.IsSameLocation

local GetGuideVisibilityState = M.GetGuideVisibilityState
local IsGuideHiddenState = M.IsGuideHiddenState
local GetHiddenOverrideWaypoint = M.GetHiddenOverrideWaypoint
local IsAllowedHiddenOverrideWaypoint = M.IsAllowedHiddenOverrideWaypoint
local ShowHiddenOverrideWaypoint = M.ShowHiddenOverrideWaypoint
local GetActiveManualDestination = M.GetActiveManualDestination
local HandleRemovedManualDestination = M.HandleRemovedManualDestination

local ROUTE_CARRIER_ADVANCE_RADIUS = 1

-- ============================================================
-- Zygor tick hooks
-- Hooks on Zygor guide methods to drive bridge TickUpdate.
-- ============================================================

local function TickUpdateFromHook()
    local churn = NS.State and NS.State.churn
    if churn and churn.active then
        churn.tickFromHook = churn.tickFromHook + 1
    end
    NS.TickUpdate()
end

-- Coalesces hook-triggered TickUpdates fired within the same frame into a
-- single trailing call scheduled via NS.After(0, ...). Zygor's step change
-- drives pointer.SetWaypoint (synchronous, inside ShowWaypoints) and the
-- Z:SetCurrentStep/FocusStep/GoalProgress post-hooks in the same frame;
-- running TickUpdate for each one races partially-updated state. Coalescing
-- guarantees exactly one TickUpdate per frame, on the next frame boundary,
-- by which time CurrentStep, pointer.ArrowFrame.waypoint, and DestinationWaypoint
-- are all settled.
local function ScheduleCoalescedTickUpdate()
    if bridge.coalescedTickPending then
        return
    end
    bridge.coalescedTickPending = true
    NS.After(0, function()
        bridge.coalescedTickPending = false
        TickUpdateFromHook()
    end)
end

function NS.HookZygorTickHooks()
    if bridge.zygorTickHooked then return end

    local Z = NS.ZGV()
    if not Z then return end

    local pointer = Z.Pointer
    local function invalidateGuideResolverFacts()
        if type(NS.InvalidateGuideResolverFactsState) == "function" then
            NS.InvalidateGuideResolverFactsState()
        end
    end
    for _, methodName in ipairs({ "FocusStep", "SetCurrentStep", "GoalProgress" }) do
        if type(Z[methodName]) == "function" then
            hooksecurefunc(Z, methodName, function()
                invalidateGuideResolverFacts()
                ScheduleCoalescedTickUpdate()
            end)
        end
    end

    if pointer and type(pointer.SetWaypoint) == "function" then
        hooksecurefunc(pointer, "SetWaypoint", function()
            ScheduleCoalescedTickUpdate()
        end)
    end

    if pointer and type(pointer.ClearWaypoints) == "function" then
        hooksecurefunc(pointer, "ClearWaypoints", function()
            ScheduleCoalescedTickUpdate()
        end)
    end

    if not bridge.zygorTravelReportedHooked and type(Z.AddMessageHandler) == "function" then
        bridge.zygorTravelReportedHandler = function()
            bridge.lastRouteTravelReportedAt = GetTime and GetTime() or 0
            ScheduleCoalescedTickUpdate()
        end
        Z:AddMessageHandler("LIBROVER_TRAVEL_REPORTED", bridge.zygorTravelReportedHandler)
        bridge.zygorTravelReportedHooked = true
    end

    bridge.zygorTickHooked = true
end

-- ============================================================
-- Zygor guide guards
-- Guards on Zygor pointer/visibility methods to preserve
-- manual destinations and enforce bridge visibility policy.
-- ============================================================

local function IsZygorRouteMenuRemoveButton(button)
    if type(button) ~= "table" or type(button.GetParent) ~= "function" or type(button.GetText) ~= "function" then
        return false
    end

    local Z = NS.ZGV()
    local pointer = Z and Z.Pointer
    local routeMenuFrame = pointer and pointer.ArrowFrame and pointer.ArrowFrame.routemenuframe
    local removeText = Z and Z.L and Z.L["pointer_arrowmenu_removeway"]
    if not routeMenuFrame or type(removeText) ~= "string" or removeText == "" then
        return false
    end

    local dropdownList = button:GetParent()
    return dropdownList and dropdownList.dropdown == routeMenuFrame and button:GetText() == removeText or false
end

local function MarkExplicitManualRemoveIntent()
    if bridge.suppressZygorManualClearSync > 0
        or type(NS.MarkPendingZygorManualRemoveIntent) ~= "function"
    then
        return
    end

    local destination = GetActiveManualDestination()
    if destination and destination.zwpExternalTomTom == true then
        NS.MarkPendingZygorManualRemoveIntent(destination)
    end
end

local function FinalizePendingExplicitManualRemoval()
    if bridge.suppressZygorManualClearSync > 0
        or type(NS.ConsumePendingZygorManualRemoveIntent) ~= "function"
    then
        return
    end

    local destination = NS.ConsumePendingZygorManualRemoveIntent()
    if type(destination) ~= "table" or destination.zwpExternalTomTom ~= true then
        return
    end

    if type(HandleRemovedManualDestination) == "function" then
        HandleRemovedManualDestination(destination)
    end
end

local function GetWaypointDistanceYards(waypoint)
    if type(waypoint) ~= "table" then
        return
    end

    local dist = waypoint.frame_minimap and tonumber(waypoint.frame_minimap.dist) or nil
    if type(dist) == "number" then
        return dist
    end

    if type(NS.GetPlayerWaypointDistance) == "function" then
        local mapID, x, y = ReadWaypointCoords(waypoint)
        return NS.GetPlayerWaypointDistance(mapID, x, y)
    end
end

-- Single-entry cache: avoids recomputing the source string when
-- the same destination is queried repeatedly within one tick.
local cachedManualRouteSig = nil
local cachedManualRouteSource = nil


local function GetManualRouteSource(destination)
    if type(destination) ~= "table" then
        return
    end

    local sig = type(destination.zwpExternalSig) == "string" and destination.zwpExternalSig or nil
    if type(sig) ~= "string" or sig == "" then
        local mapID, x, y = ReadWaypointCoords(destination)
        if type(mapID) ~= "number" or type(x) ~= "number" or type(y) ~= "number" then
            return
        end
        if type(NS.Signature) == "function" then
            sig = NS.Signature(mapID, x, y)
        else
            sig = string.format("%s:%.4f:%.4f", tostring(mapID), x, y)
        end
    end

    if sig ~= cachedManualRouteSig then
        cachedManualRouteSig = sig
        cachedManualRouteSource = "manual#" .. sig
    end

    return cachedManualRouteSource
end

local function ResolveManualRouteLegSemantics(waypoint, source, destination)
    if type(destination) ~= "table" or destination.type ~= "manual" or type(waypoint) ~= "table" then
        return
    end

    if waypoint ~= destination and not NS.IsRouteLikeWaypoint(waypoint, source) then
        return
    end
    if type(NS.IsGuideGoalWaypoint) == "function" and NS.IsGuideGoalWaypoint(waypoint) then
        return
    end

    local destinationMapID, destinationX, destinationY = ReadWaypointCoords(destination)
    local waypointMapID, waypointX, waypointY = ReadWaypointCoords(waypoint)
    if type(destinationMapID) ~= "number"
        or type(destinationX) ~= "number"
        or type(destinationY) ~= "number"
        or type(waypointMapID) ~= "number"
        or type(waypointX) ~= "number"
        or type(waypointY) ~= "number"
    then
        return
    end

    return GetManualRouteSource(destination),
        destinationMapID,
        destinationX,
        destinationY,
        waypoint.title,
        waypoint.arrowtitle,
        IsSameLocation(waypointMapID, waypointX, waypointY, destinationMapID, destinationX, destinationY)
            and "destination"
            or "carrier"
end

local function FinalizeRouteLegSemantics(waypoint, source, legSource, mapID, x, y, title, arrowtitle, legKind)
    if type(waypoint) ~= "table" or type(mapID) ~= "number" then
        return
    end

    local waypointMapID = ReadWaypointCoords(waypoint)
    local routeTravelType, parentMapID, journalInstanceID, instanceName
    if type(waypointMapID) == "number" and type(NS.ResolveInstanceDestinationTravelType) == "function" then
        routeTravelType, parentMapID, journalInstanceID, instanceName =
            NS.ResolveInstanceDestinationTravelType(mapID, waypointMapID, legKind)
    end

    return legSource or source,
        mapID,
        x,
        y,
        title,
        arrowtitle,
        legKind,
        routeTravelType,
        parentMapID,
        journalInstanceID,
        instanceName
end

local function ResolveRouteLegSemantics(pointer, waypoint, source, destinationWaypoint)
    if type(waypoint) ~= "table" then
        return
    end

    local destination = type(destinationWaypoint) == "table" and destinationWaypoint
        or (type(pointer) == "table" and pointer.DestinationWaypoint or nil)
    if type(destination) ~= "table" then
        return
    end

    if destination.type == "manual" then
        local legSource, mapID, x, y, title, arrowtitle, legKind =
            ResolveManualRouteLegSemantics(waypoint, source, destination)
        return FinalizeRouteLegSemantics(waypoint, source, legSource, mapID, x, y, title, arrowtitle, legKind)
    end

    if type(NS.CanonicalizeLiveWaypointTargetFields) ~= "function" then
        return
    end

    local Z = NS.ZGV()
    local step = Z and Z.CurrentStep or nil
    local legSource, mapID, x, y, titleText, arrowTitle, legKind = NS.CanonicalizeLiveWaypointTargetFields(
        step,
        waypoint,
        source,
        waypoint.title,
        waypoint.arrowtitle,
        destination
    )
    return FinalizeRouteLegSemantics(waypoint, source, legSource, mapID, x, y, titleText, arrowTitle, legKind)
end

-- ResolveRouteLegSemantics returns: source, mapID, x, y, title, arrowtitle, legKind,
-- routeTravelType, parentMapID, journalInstanceID, instanceName.
-- This helper surfaces only the two values used by GetCarrierRouteArrivalClampRadius.
local function GetRouteLegKind(pointer, waypoint, source)
    local legSource, _, _, _, _, _, legKind = ResolveRouteLegSemantics(pointer, waypoint, source)
    return legSource, legKind
end

NS.ResolveRouteLegSemantics = ResolveRouteLegSemantics

local function GetCarrierRouteArrivalClampRadius(pointer, waypoint)
    if type(pointer) ~= "table" or type(waypoint) ~= "table" or waypoint.type ~= "route" then
        return
    end

    local route = pointer.pointsets and pointer.pointsets.route or nil
    local nextLeg = route and route.points and route.points[3] or nil
    if type(nextLeg) ~= "table" then
        return
    end

    local carrierSource, carrierLegKind = GetRouteLegKind(pointer, waypoint, "pointer.ArrowFrame.waypoint")
    local destinationSource, destinationLegKind = GetRouteLegKind(pointer, nextLeg, "pointer.pointsets.route.points[3]")

    if carrierLegKind ~= "carrier"
        or destinationLegKind ~= "destination"
        or carrierSource ~= destinationSource
    then
        return
    end

    local distance = GetWaypointDistanceYards(waypoint)
    if type(distance) ~= "number" then
        return
    end

    local zygorRadius = tonumber(waypoint.radius)
        or (type(pointer.GetDefaultStepDist) == "function" and tonumber(pointer:GetDefaultStepDist(waypoint)) or nil)
    if type(zygorRadius) ~= "number" then
        return
    end

    if distance > zygorRadius then
        return
    end

    local clampRadius = ROUTE_CARRIER_ADVANCE_RADIUS
    local explicitRadius = tonumber(waypoint.radius)
    if type(explicitRadius) == "number" and explicitRadius < clampRadius then
        clampRadius = explicitRadius
    end

    if distance <= clampRadius then
        return
    end

    return clampRadius
end

local function WithTemporaryWaypointRadius(waypoint, radius, fn)
    if type(waypoint) ~= "table" or type(radius) ~= "number" or type(fn) ~= "function" then
        if type(fn) == "function" then
            return fn()
        end
        return
    end

    local hadExplicitRadius = waypoint.radius ~= nil
    local originalRadius = waypoint.radius
    waypoint.radius = radius

    local ok, result1, result2, result3, result4 = pcall(fn)

    if hadExplicitRadius then
        waypoint.radius = originalRadius
    else
        waypoint.radius = nil
    end

    if not ok then
        error(result1)
    end

    return result1, result2, result3, result4
end

function NS.HookZygorGuideGuards()
    local Z = NS.ZGV()
    if not Z or not Z.Pointer then return end
    local pointer = Z.Pointer

    if not bridge.zygorStepChangedGuardHooked
        and type(Z.RemoveMessageHandler) == "function"
        and type(Z.AddMessageHandler) == "function"
        and type(pointer.OnEvent) == "function"
    then
        local removed = Z:RemoveMessageHandler("ZGV_STEP_CHANGED", pointer.OnEvent)
        if removed then
            bridge.zygorStepChangedHandler = function(self, event, ...)
                local manualDestination = GetActiveManualDestination()
                if event == "ZGV_STEP_CHANGED" and manualDestination then
                    NS.Log("Preserve manual destination on step change", tostring(manualDestination.title))
                    return self:ShowWaypoints()
                end

                return pointer.OnEvent(self, event, ...)
            end
            Z:AddMessageHandler("ZGV_STEP_CHANGED", bridge.zygorStepChangedHandler)
            bridge.zygorStepChangedGuardHooked = true
        else
            NS.After(0.25, NS.HookZygorGuideGuards)
        end
    end

    if not bridge.zygorShowWaypointsGuardHooked and type(Z.ShowWaypoints) == "function" then
        local originalShowWaypoints = Z.ShowWaypoints
        Z.ShowWaypoints = function(self, command, ...)
            local visibilityState = GetGuideVisibilityState()
            local manualDestination = GetActiveManualDestination()
            if IsGuideHiddenState(visibilityState) then
                if command == "clear" then
                    return originalShowWaypoints(self, command, ...)
                end

                local hiddenOverrideWaypoint = GetHiddenOverrideWaypoint()
                if hiddenOverrideWaypoint then
                    return ShowHiddenOverrideWaypoint(self.Pointer, hiddenOverrideWaypoint)
                end

                if self.Pointer and type(self.Pointer.HideArrow) == "function" then
                    self.Pointer:HideArrow()
                end
                return
            end

            if visibilityState == "visible" and command ~= "clear" and manualDestination then
                NS.Log("Preserve manual destination during guide refresh", tostring(command), tostring(manualDestination.title))
                originalShowWaypoints(self, "clear", ...)
                return ShowHiddenOverrideWaypoint(self.Pointer, manualDestination)
            end

            return originalShowWaypoints(self, command, ...)
        end
        bridge.zygorShowWaypointsGuardHooked = true
    end

    if not bridge.zygorShowArrowGuardHooked and type(pointer.ShowArrow) == "function" then
        local originalShowArrow = pointer.ShowArrow
        pointer.ShowArrow = function(self, waypoint, ...)
            local visibilityState = GetGuideVisibilityState()
            if IsGuideHiddenState(visibilityState) and not IsAllowedHiddenOverrideWaypoint(waypoint) then
                if type(self.HideArrow) == "function" then
                    self:HideArrow()
                end
                return
            end

            return originalShowArrow(self, waypoint, ...)
        end
        bridge.zygorShowArrowGuardHooked = true
    end

    if not bridge.zygorRouteArrivalGuardHooked and type(pointer.ArrowFrame_OnUpdate_Common) == "function" then
        local originalArrowFrameOnUpdateCommon = pointer.ArrowFrame_OnUpdate_Common
        pointer.ArrowFrame_OnUpdate_Common = function(frame, elapsed, ...)
            local waypoint = frame and frame.waypoint or nil
            local clampRadius = GetCarrierRouteArrivalClampRadius(pointer, waypoint)
            if type(clampRadius) ~= "number" then
                return originalArrowFrameOnUpdateCommon(frame, elapsed, ...)
            end

            local extraArgs = { ... }
            return WithTemporaryWaypointRadius(waypoint, clampRadius, function()
                return originalArrowFrameOnUpdateCommon(frame, elapsed, unpack(extraArgs))
            end)
        end
        bridge.zygorRouteArrivalGuardHooked = true
    end

    if not bridge.zygorDropdownIntentHooked and type(_G.UIDropDownForkButton_OnClick) == "function" then
        local originalDropdownClick = _G.UIDropDownForkButton_OnClick
        _G.UIDropDownForkButton_OnClick = function(button, ...)
            -- Pathfinding-mode route-menu remove drops into ClearWaypoints("manual")
            -- without a reason, so capture the active external manual before Zygor clears it.
            if IsZygorRouteMenuRemoveButton(button) then
                MarkExplicitManualRemoveIntent()
            end

            return originalDropdownClick(button, ...)
        end
        bridge.zygorDropdownIntentHooked = true
    end

    if not bridge.zygorManualClearHooked then
        if type(pointer.ClearWaypoints) == "function" then
            hooksecurefunc(pointer, "ClearWaypoints", function(_, waytype)
                if waytype == "manual" then
                    FinalizePendingExplicitManualRemoval()
                end
            end)
        end

        if type(pointer.RemoveWaypoint) == "function" then
            hooksecurefunc(pointer, "RemoveWaypoint", function(_, _, reason)
                if reason == "pointer menu" then
                    FinalizePendingExplicitManualRemoval()
                end
            end)
        end

        bridge.zygorManualClearHooked = true
    end

    bridge.zygorGuideGuardsHooked = bridge.zygorStepChangedGuardHooked
        and bridge.zygorShowWaypointsGuardHooked
        and bridge.zygorShowArrowGuardHooked
        and bridge.zygorRouteArrivalGuardHooked
        and bridge.zygorDropdownIntentHooked
        and bridge.zygorManualClearHooked
end

-- ============================================================
-- Zygor arrow texture suppression
-- Hides Zygor's arrow visuals when TomTom's arrow is active.
-- ============================================================

function NS.HideZygorArrowTextures()
    local Z = NS.ZGV()
    if not Z or not Z.Pointer or not Z.Pointer.ArrowFrame then
        return
    end

    local frame = Z.Pointer.ArrowFrame
    if frame.arrow and frame.arrow:GetAlpha() > 0 then
        frame.arrow:SetAlpha(0)
        if frame.arrow.arr then frame.arrow.arr:SetAlpha(0) end
        if frame.arrow.arrspecular then frame.arrow.arrspecular:SetAlpha(0) end
    end

    if frame.special and frame.special:GetAlpha() > 0 then
        frame.special:SetAlpha(0)
    end
end

function NS.HookZygorArrowTextures()
    if bridge.zygorArrowHooked then return end

    local Z = NS.ZGV()
    if not Z or not Z.Pointer then return end
    local pointer = Z.Pointer

    NS.EnsureGuideArrowVisibilityPolicy()

    if type(pointer.SetArrowSkin) == "function" then
        hooksecurefunc(pointer, "SetArrowSkin", function()
            NS.After(0.05, NS.HideZygorArrowTextures)
        end)
    end

    if type(pointer.UpdatePointer) == "function" then
        hooksecurefunc(pointer, "UpdatePointer", function()
            NS.HideZygorArrowTextures()
        end)
    end

    bridge.zygorArrowHooked = true
    NS.After(0.1, NS.HideZygorArrowTextures)
end

-- ============================================================
-- TomTom hooks
-- Bridge heartbeat and hooks on TomTom objects.
-- ============================================================

function NS.StartBridgeHeartbeat()
    if bridge.heartbeatFrame then return end

    local frame = CreateFrame("Frame")
    frame:SetScript("OnUpdate", function(_, dt)
        bridge.heartbeatElapsed = bridge.heartbeatElapsed + dt
        if bridge.heartbeatElapsed > C.UPDATE_INTERVAL_SECONDS then
            bridge.heartbeatElapsed = 0
            local churn = NS.State and NS.State.churn
            if churn and churn.active then
                churn.tickFromHeartbeat = churn.tickFromHeartbeat + 1
            end
            NS.TickUpdate()
        end
    end)

    bridge.heartbeatFrame = frame
end

function NS.ApplyTomTomArrowDefaults()
    NS.EnsureGuideArrowVisibilityPolicy()
    NS.ApplyTomTomScalePolicy()

    if NS.HookTomTomThemeBridge then
        NS.HookTomTomThemeBridge()
    end
    if NS.ApplyTomTomArrowSkin then
        NS.ApplyTomTomArrowSkin()
    end
    NS.HookTomTomArrowTextSuppression()
end

function NS.HookTomTomArrowTextSuppression()
    if bridge.tomtomTextSuppressionHooked then return end

    local tomtom = GetTomTom()
    if not tomtom or type(tomtom.ShowHideCrazyArrow) ~= "function" then return end

    local wayframe = GetTomTomArrow()
    if not wayframe then return end

    -- Cache the titleframe once via the parent of wayframe.title (a FontString child of
    -- the local titleframe in TomTom_CrazyArrow.lua). Avoids GetParent() every call.
    local titleframe = wayframe.title and wayframe.title:GetParent()

    local function suppressText()
        if wayframe.tta then wayframe.tta:Hide() end
        if titleframe then titleframe:SetAlpha(0) end
    end

    -- ShowHideCrazyArrow re-applies title_alpha from the DB profile each call,
    -- so we must suppress after it runs to keep text hidden.
    hooksecurefunc(tomtom, "ShowHideCrazyArrow", suppressText)

    -- SetCrazyArrow calls ShowCrazyArrow() directly (not ShowHideCrazyArrow),
    -- so initial waypoint display bypasses the hook above entirely.
    if type(tomtom.SetCrazyArrow) == "function" then
        hooksecurefunc(tomtom, "SetCrazyArrow", suppressText)
    end

    -- Suppress immediately in case the arrow is already visible when the hook installs.
    suppressText()

    bridge.tomtomTextSuppressionHooked = true
end
