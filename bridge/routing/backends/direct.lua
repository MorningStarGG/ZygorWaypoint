local NS = _G.AzerothWaypointNS

-- ============================================================
-- Direct backend - fallback when no planner is selected/available
-- ============================================================
--
-- Single-destination only. No multi-leg planning, no special-action
-- emission. Always available so manual routes, takeovers, and external
-- TomTom adoption still work as straight-line waypoints.

local backend = {}
NS.RoutingBackend_Direct = backend

backend.id = "direct"

function backend.IsAvailable()
    return true
end

function backend.PlanRoute(stateRecord, mapID, x, y, title)
    if not stateRecord or not mapID or not x or not y then return end

    local legs = {
        {
            mapID = mapID,
            x = x,
            y = y,
            kind = "destination",
            routeLegKind = "destination",
            title = title,
            source = "direct",
        },
    }

    if type(NS.AcceptBackendPlan) == "function" then
        NS.AcceptBackendPlan(stateRecord, "direct", legs, "direct_plan")
        return
    end

    stateRecord.backend = "direct"
    stateRecord.legs = legs
    stateRecord.currentLegIndex = nil
    stateRecord.currentLeg = nil
    stateRecord.specialAction = nil
    stateRecord.replanReason = "direct_plan"
end

function backend.PollCurrentLeg(stateRecord)
    if type(NS.PollNeutralRouteLeg) == "function" then
        return NS.PollNeutralRouteLeg(stateRecord, "direct_poll")
    end
    return false
end

function backend.Clear(stateRecord)
    if not stateRecord then return end
    stateRecord.legs = nil
    stateRecord.currentLegIndex = nil
    stateRecord.currentLeg = nil
    stateRecord.specialAction = nil
    stateRecord._corePlanning = nil
    stateRecord._coreRoutePending = nil
    stateRecord.planFingerprint = nil
    stateRecord.lastPlanSkippedAt = nil
    stateRecord.lastPlanSkipReason = nil
    stateRecord.lastPlanSkipStatus = nil
    stateRecord.lastPlanSkippedFingerprint = nil
    stateRecord.routeOutcome = nil
    stateRecord.routeOutcomeReason = nil
    stateRecord.routeOutcomeAt = nil
end
