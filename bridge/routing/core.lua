local NS = _G.AzerothWaypointNS
local state = NS.State

local SafeCall = NS.SafeCall
local Signature = NS.Signature
local ROUTE_COORD_TOLERANCE = 0.00005
local ROUTE_REPLAN_DEBOUNCE_SECONDS = 0.35
local DEFAULT_ACTION_RADIUS_YARDS = 15
local DEFAULT_MOVEMENT_RADIUS_YARDS = 55

local NOISY_ACTION_INVALIDATION_REASON = {
    SPELL_UPDATE_COOLDOWN = true,
}

local NOISY_ACTION_INVALIDATION_BACKEND = {
    mapzeroth = true,
    farstrider = true,
}

local SECURE_SPECIAL_TYPES = {
    spell = true,
    item = true,
    toy = true,
    macro = true,
    ["function"] = true,
}

local DISTANCE_ADVANCE_KIND = {
    walk = true,
    fly = true,
    movement = true,
    carrier = true,
    ["_INITIAL_STEP"] = true,
}

local RESET_LEG_ON_REPLAN_REASON = {
    environment = true,
    LOADING_SCREEN_DISABLED = true,
    NEW_WMO_CHUNK = true,
    UNIT_ENTERING_VEHICLE = true,
    UNIT_EXITING_VEHICLE = true,
    ZONE_CHANGED = true,
    ZONE_CHANGED_INDOORS = true,
    ZONE_CHANGED_NEW_AREA = true,
}

local FORCE_ENVIRONMENT_REFRESH_REASON = {
    LOADING_SCREEN_DISABLED = true,
    UNIT_ENTERING_VEHICLE = true,
    UNIT_EXITING_VEHICLE = true,
}

local ENVIRONMENT_REFRESH_REASON = {
    environment = true,
    NEW_WMO_CHUNK = true,
    ZONE_CHANGED = true,
    ZONE_CHANGED_INDOORS = true,
    ZONE_CHANGED_NEW_AREA = true,
}

local ROUTE_SUCCESS_REASON = {
    direct_plan = true,
    mapzeroth_plan = true,
    mapzeroth_instance_entrance_plan = true,
    mapzeroth_instance_node_plan = true,
    zygor_librover_success = true,
    farstrider_plan = true,
    farstrider_instance_entrance_plan = true,
}

local ROUTE_PLANNING_REASON = {
    zygor_planning_fallback = true,
}

local ROUTE_FAILURE_REASON = {
    mapzeroth_missing = true,
    mapzeroth_nopath_fallback = true,
    mapzeroth_emptysteps_fallback = true,
    mapzeroth_nolegs_fallback = true,
    zygor_no_librover = true,
    zygor_queue_failed = true,
    zygor_plan_timeout = true,
    zygor_plan_timeout_fallback = true,
    zygor_librover_arrival = true,
    zygor_librover_failure = true,
    zygor_librover_failed = true,
    farstrider_missing = true,
    farstrider_nopath_fallback = true,
    farstrider_correlation_fallback = true,
}

local function GetTimeSafe()
    return type(GetTime) == "function" and GetTime() or 0
end

local function ShouldResetLegOnReplan(reason)
    return type(reason) == "string" and RESET_LEG_ON_REPLAN_REASON[reason] == true
end

local function CopyMeta(meta)
    if type(meta) ~= "table" then
        return nil
    end
    local copy = {}
    for key, value in pairs(meta) do
        copy[key] = value
    end
    return copy
end

local function BuildPlanMeta(record, reason)
    local sourceMeta = type(record) == "table" and record.meta or nil
    if type(reason) ~= "string" then
        return sourceMeta
    end

    local planMeta = CopyMeta(sourceMeta) or {}
    planMeta.replanReason = reason
    planMeta.routeInvalidated = ShouldResetLegOnReplan(reason) or nil
    return planMeta
end

-- ------------------------------------------------------------
-- Backend selection
-- ------------------------------------------------------------

local BACKEND_PRIORITY = { "zygor", "farstrider", "mapzeroth", "direct" }

local function GetBackendObject(id)
    if id == "zygor"       then return NS.RoutingBackend_Zygor end
    if id == "mapzeroth"   then return NS.RoutingBackend_Mapzeroth end
    if id == "farstrider"  then return NS.RoutingBackend_Farstrider end
    if id == "direct"      then return NS.RoutingBackend_Direct end
    return nil
end

local function ResolveEffectiveBackend(opts)
    local override = opts and opts.backendOverride
    if override then
        local b = GetBackendObject(override)
        if b and b.IsAvailable() then return b end
    end

    local db = NS.GetDB()
    local selected = db and db.routingBackend
    local b = GetBackendObject(selected)
    if b and b.IsAvailable() then return b end

    for _, id in ipairs(BACKEND_PRIORITY) do
        local fallback = GetBackendObject(id)
        if fallback and fallback.IsAvailable() then return fallback end
    end

    -- direct is the floor â€” should never miss, but defensive return.
    return NS.RoutingBackend_Direct
end

function NS.GetSelectedBackendID()
    local db = NS.GetDB()
    return state.routing.selectedBackend
        or (db and db.routingBackend)
        or "direct"
end

function NS.GetEffectiveBackendID()
    local b = ResolveEffectiveBackend()
    return b and b.id or "direct"
end

local function ResolveAuthorityDestination(record)
    if type(record) ~= "table" then
        return nil, nil, nil, nil
    end
    if type(record.destination) == "table" then
        return record.destination.mapID, record.destination.x, record.destination.y, record.destination.title
    end
    if record.target then
        return record.target.mapID, record.target.x, record.target.y, record.target.title
    end
    return record.mapID, record.x, record.y, record.title
end

local function IsValidLeg(leg)
    return type(leg) == "table"
        and type(leg.mapID) == "number"
        and type(leg.x) == "number"
        and type(leg.y) == "number"
end

local function GetLegSignature(leg)
    if not IsValidLeg(leg) then
        return nil
    end
    if type(Signature) == "function" then
        return Signature(leg.mapID, leg.x, leg.y)
    end
    return table.concat({ tostring(leg.mapID), tostring(leg.x), tostring(leg.y) }, ":", 1, 3)
end

local function IsSecureSpecialAction(action)
    return type(action) == "table"
        and SECURE_SPECIAL_TYPES[action.secureType] == true
        and action.securePayload ~= nil
        and action.securePayload ~= ""
end

local function GetSpecialActionIdentity(action)
    if not IsSecureSpecialAction(action) then
        return nil
    end
    return table.concat({
        tostring(action.semanticKind or "-"),
        tostring(action.secureType or "-"),
        tostring(action.securePayload or "-"),
        tostring(action.destinationName or "-"),
    }, "/")
end

local function SanitizeSpecialAction(action)
    if IsSecureSpecialAction(action) then
        return action
    end
    return nil
end

local function IsNoisyActionInvalidation(reason)
    return type(reason) == "string" and NOISY_ACTION_INVALIDATION_REASON[reason] == true
end

local function TrimRouteText(value)
    if type(value) ~= "string" then return nil end
    value = value:gsub("^%s+", ""):gsub("%s+$", "")
    if value == "" then return nil end
    return value
end

local function NormalizeZoneText(value)
    return TrimRouteText(value)
end

local function ReadRouteEnvironmentText(fn)
    if type(fn) ~= "function" then
        return nil
    end
    local ok, value = pcall(fn)
    if not ok then
        return nil
    end
    return NormalizeZoneText(value)
end

function NS.GetRouteEnvironmentSnapshot()
    local indoors = nil
    if type(IsIndoors) == "function" and IsIndoors() then
        indoors = true
    elseif type(IsOutdoors) == "function" and IsOutdoors() then
        indoors = false
    end

    return {
        indoors = indoors,
        zone = ReadRouteEnvironmentText(GetZoneText),
        realzone = ReadRouteEnvironmentText(GetRealZoneText),
        subzone = ReadRouteEnvironmentText(GetSubZoneText),
        minizone = ReadRouteEnvironmentText(GetMinimapZoneText),
    }
end

local function RouteEnvironmentFingerprint(env)
    env = type(env) == "table" and env or NS.GetRouteEnvironmentSnapshot()
    local mapID = type(NS.GetPlayerMapID) == "function" and NS.GetPlayerMapID() or nil
    return table.concat({
        tostring(mapID or "-"),
        tostring(env.indoors),
        tostring(env.zone or "-"),
        tostring(env.realzone or "-"),
        tostring(env.subzone or "-"),
        tostring(env.minizone or "-"),
    }, "|")
end

local function RememberRouteEnvironment()
    local current = NS.GetRouteEnvironmentSnapshot()
    local fingerprint = RouteEnvironmentFingerprint(current)
    state.routing._routeEnvironmentSnapshot = current
    state.routing._routeEnvironmentFingerprint = fingerprint
    return current, fingerprint
end

local function ShouldRefreshForEnvironment(reason)
    local previous = state.routing._routeEnvironmentFingerprint
    local _, fingerprint = RememberRouteEnvironment()

    if type(reason) == "string" and FORCE_ENVIRONMENT_REFRESH_REASON[reason] then
        return true
    end
    if type(reason) == "string" and not ENVIRONMENT_REFRESH_REASON[reason] then
        return true
    end

    return previous ~= fingerprint
end

local function IsStrictRouteRecord(record)
    if type(record) ~= "table" then
        return false
    end
    if record.strictRouteSuccess == true or record._coreStrictRouteSuccess == true then
        return true
    end
    local queueTransaction = record._corePendingQueueTransaction
    if type(queueTransaction) == "table" and queueTransaction.strictRouteSuccess == true then
        return true
    end
    return false
end

local function IsFallbackRouteReason(reason)
    if type(reason) ~= "string" then
        return false
    end
    if ROUTE_FAILURE_REASON[reason] then
        return true
    end
    return reason:find("_fallback$", 1, false) ~= nil
end

local function IsFailedRouteReason(reason)
    if type(reason) ~= "string" then
        return false
    end
    if ROUTE_FAILURE_REASON[reason] then
        return true
    end
    return reason:find("failure", 1, true) ~= nil
        or reason:find("failed", 1, true) ~= nil
        or reason:find("timeout", 1, true) ~= nil
        or reason:find("nopath", 1, true) ~= nil
        or reason:find("emptysteps", 1, true) ~= nil
        or reason:find("nolegs", 1, true) ~= nil
end

local function ClassifyRouteOutcome(record, backendID, legs, reason)
    if type(record) == "table" and record._coreRouteOutcomeHint == "planning" then
        return "planning"
    end
    if ROUTE_PLANNING_REASON[reason] then
        return "planning"
    end
    if ROUTE_SUCCESS_REASON[reason] then
        return "success"
    end
    if IsFallbackRouteReason(reason) then
        return IsStrictRouteRecord(record) and "failed" or "fallback"
    end
    if IsFailedRouteReason(reason) then
        return "failed"
    end
    if type(legs) == "table" and #legs > 0 then
        return "success"
    end
    if backendID == "direct" then
        return "success"
    end
    return IsStrictRouteRecord(record) and "failed" or "fallback"
end

local function MarkRouteOutcome(record, outcome, reason)
    if type(record) ~= "table" then
        return
    end
    record.routeOutcome = outcome
    record.routeOutcomeReason = reason
    record.routeOutcomeAt = GetTimeSafe()
end

local function ResolveRouteFailureTitle(record)
    if type(record) ~= "table" then
        return "destination"
    end
    local _, _, _, title = ResolveAuthorityDestination(record)
    return TrimRouteText(title) or "destination"
end

local function ReportStrictRouteFailure(record, reason)
    if type(record) ~= "table" then
        return
    end
    local title = ResolveRouteFailureTitle(record)
    local key = table.concat({
        tostring(record._corePendingRouteSerial or "-"),
        tostring(record.backend or "-"),
        tostring(reason or "-"),
        tostring(title),
    }, "\031", 1, 4)
    if record._coreLastStrictFailureMessageKey == key then
        return
    end
    record._coreLastStrictFailureMessageKey = key
    if type(NS.Msg) == "function" then
        NS.Msg(string.format("Routing failed: no route found to %s.", title))
    end
end

local function IsPendingManualRouteRecord(record)
    return type(record) == "table" and record._corePendingManualRoute == true
end

local function ClearPendingManualRoute(record)
    if type(record) ~= "table" then
        return
    end
    if state.routing.pendingManualAuthority == record then
        state.routing.pendingManualAuthority = nil
    end
    record._corePendingManualRoute = nil
    record._corePendingRouteSerial = nil
end

local function CancelPendingManualRoute(reason)
    local pending = state.routing.pendingManualAuthority
    if type(pending) ~= "table" then
        return false
    end
    if type(NS.RollbackPendingManualQueueTransaction) == "function" then
        NS.RollbackPendingManualQueueTransaction(pending, "cancelled", reason or "superseded")
    end
    ClearPendingManualRoute(pending)
    pending._coreStrictRouteCompleted = true
    pending._coreStrictRouteSucceeded = false
    pending._coreRoutePending = nil
    pending._corePlanning = nil
    return true
end

function NS.CancelPendingManualRoute(reason)
    return CancelPendingManualRoute(reason)
end

local function CompletePendingManualRoute(record, outcome, reason)
    if not IsPendingManualRouteRecord(record) then
        return nil
    end

    local routing = state.routing
    if routing.pendingManualAuthority ~= record
        or routing._pendingManualRouteSerial ~= record._corePendingRouteSerial
    then
        return false
    end

    if outcome == "planning" then
        return nil
    end

    if outcome ~= "success" then
        if type(NS.RollbackPendingManualQueueTransaction) == "function" then
            NS.RollbackPendingManualQueueTransaction(record, outcome, reason)
        end
        ReportStrictRouteFailure(record, reason)
        ClearPendingManualRoute(record)
        record._coreRoutePending = nil
        record._corePlanning = nil
        record._coreStrictRouteCompleted = true
        record._coreStrictRouteSucceeded = false
        return false
    end

    if type(NS.CommitPendingManualQueueTransaction) == "function" then
        NS.CommitPendingManualQueueTransaction(record)
    end
    ClearPendingManualRoute(record)
    record._coreStrictRouteCompleted = true
    record._coreStrictRouteSucceeded = true
    if type(NS.CommitManualAuthority) == "function" then
        return NS.CommitManualAuthority(record)
    end
    return false
end

local function GateTextMatches(expected, actual)
    expected = NormalizeZoneText(expected)
    if not expected then
        return true
    end
    return expected == NormalizeZoneText(actual)
end

local function ArrivalGateMatches(leg)
    local gate = type(leg) == "table" and leg.arrivalGate or nil
    if type(gate) ~= "table" then
        return true
    end

    local env = NS.GetRouteEnvironmentSnapshot()
    if gate.indoors ~= nil and env.indoors ~= nil and gate.indoors ~= env.indoors then
        return false
    end
    if gate.indoors == true and env.indoors ~= true then
        return false
    end
    if not GateTextMatches(gate.zone, env.zone) then
        return false
    end
    if not GateTextMatches(gate.realzone, env.realzone) then
        return false
    end
    if not GateTextMatches(gate.subzone, env.subzone) then
        return false
    end
    if not GateTextMatches(gate.minizone, env.minizone) then
        return false
    end

    return true
end

NS.RouteArrivalGateMatches = ArrivalGateMatches

local function FindMatchingLegIndex(legs, previousLeg)
    local previousSig = GetLegSignature(previousLeg)
    if type(previousSig) ~= "string" or type(legs) ~= "table" then
        return nil
    end
    for index = 1, #legs do
        if GetLegSignature(legs[index]) == previousSig then
            -- Do not let a temporary direct/fallback destination leg skip a
            -- newly available route plan. This was the failure mode where a
            -- guide target first planned as one final destination, then a
            -- backend returned carrier legs, and the core jumped straight to
            -- the matching final destination coordinate.
            if previousLeg.routeLegKind == "destination" then
                for prior = 1, index - 1 do
                    local leg = legs[prior]
                    if IsValidLeg(leg) and leg.routeLegKind == "carrier" then
                        return nil
                    end
                end
            end
            return index
        end
    end
    return nil
end

local function FindMatchingSpecialActionLegIndex(legs, previousLeg)
    if type(legs) ~= "table" or not IsValidLeg(previousLeg) then
        return nil
    end
    local previousActionIdentity = GetSpecialActionIdentity(previousLeg.specialAction)
    if type(previousActionIdentity) ~= "string" then
        return nil
    end
    for index = 1, #legs do
        local leg = legs[index]
        if IsValidLeg(leg)
            and ArrivalGateMatches(leg)
            and GetSpecialActionIdentity(leg.specialAction) == previousActionIdentity
        then
            return index
        end
    end
    return nil
end

local function PreservePreviousSpecialActionLeg(legs, previousLeg)
    if type(legs) ~= "table" or not IsValidLeg(previousLeg) then
        return nil
    end
    if type(GetSpecialActionIdentity(previousLeg.specialAction)) ~= "string" then
        return nil
    end
    if FindMatchingSpecialActionLegIndex(legs, previousLeg) then
        return nil
    end

    local previousSig = GetLegSignature(previousLeg)
    if type(previousSig) ~= "string" then
        return nil
    end

    for index = 1, #legs do
        local leg = legs[index]
        if IsValidLeg(leg)
            and GetLegSignature(leg) == previousSig
            and ArrivalGateMatches(leg)
            and not IsSecureSpecialAction(leg.specialAction)
        then
            leg.specialAction = previousLeg.specialAction
            leg.activationCoords = leg.activationCoords or previousLeg.activationCoords
            leg.kind = previousLeg.kind or leg.kind
            leg.routeTravelType = previousLeg.routeTravelType or leg.routeTravelType
            leg.arrivalRadius = previousLeg.arrivalRadius or leg.arrivalRadius
            leg.title = previousLeg.title or leg.title
            leg._corePreservedSpecialAction = true
            return index
        end
    end

    return nil
end

local function MakeFallbackLeg(record)
    local mapID, x, y, title = ResolveAuthorityDestination(record)
    if type(mapID) ~= "number" or type(x) ~= "number" or type(y) ~= "number" then
        return nil
    end
    return {
        mapID = mapID,
        x = x,
        y = y,
        title = title,
        kind = "destination",
        routeLegKind = "destination",
        source = record and record.backend or "direct",
    }
end

local function MakeDirectDestinationLeg(record, backendID)
    local leg = MakeFallbackLeg(record)
    if type(leg) ~= "table" then
        return nil
    end
    leg.source = backendID or record and record.backend or leg.source
    return leg
end

local NON_COLLAPSIBLE_ROUTE_TRAVEL_TYPE = {
    taxi = true,
    dungeon = true,
    raid = true,
    delve = true,
    bountiful_delve = true,
}

local function IsInstanceRouteReason(reason)
    return type(reason) == "string" and reason:find("instance", 1, true) ~= nil
end

local function LegRequiresHardTransition(leg)
    if type(leg) ~= "table" then
        return false
    end
    if type(leg.arrivalGate) == "table" then
        return true
    end
    if leg.kind == "entrance" then
        return true
    end
    return NON_COLLAPSIBLE_ROUTE_TRAVEL_TYPE[leg.routeTravelType] == true
end

local function PlanRequiresHardTransition(legs)
    if type(legs) ~= "table" then
        return false
    end
    for index = 1, #legs do
        if LegRequiresHardTransition(legs[index]) then
            return true
        end
    end
    return false
end

local function LegRequiresExplicitTransition(leg)
    return LegRequiresHardTransition(leg) or IsSecureSpecialAction(type(leg) == "table" and leg.specialAction or nil)
end

local function PlanRequiresExplicitTransition(legs)
    if type(legs) ~= "table" then
        return false
    end
    for index = 1, #legs do
        if LegRequiresExplicitTransition(legs[index]) then
            return true
        end
    end
    return false
end

local function CurrentMapRouteContext(record)
    local targetMapID, targetX, targetY = ResolveAuthorityDestination(record)
    if type(targetMapID) ~= "number" or type(targetX) ~= "number" or type(targetY) ~= "number" then
        return nil
    end

    local playerMapID = type(NS.GetPlayerMapID) == "function" and NS.GetPlayerMapID() or nil
    if playerMapID ~= targetMapID then
        return nil
    end
    return targetMapID
end

local function FindFirstOffTargetMapLegIndex(legs, targetMapID)
    if type(legs) ~= "table" or type(targetMapID) ~= "number" then
        return nil
    end
    for index = 1, #legs do
        local leg = legs[index]
        if IsValidLeg(leg) and leg.mapID ~= targetMapID then
            return index
        end
    end
    return nil
end

local function ShouldCollapseCurrentMapSetupRoute(record, legs, reason)
    if type(record) ~= "table" or type(legs) ~= "table" or #legs == 0 then
        return false
    end
    local firstLeg = legs[1]
    if type(firstLeg) ~= "table" or firstLeg.routeLegKind ~= "carrier" then
        return false
    end

    local targetMapID = CurrentMapRouteContext(record)
    if type(targetMapID) ~= "number" then
        return false
    end
    if IsInstanceRouteReason(reason) then
        return false
    end

    -- Current-map plans that leave the target map are backend detours. Only
    -- the first presented local leg can block collapse; later off-map gates
    -- belong to the detour we are intentionally discarding.
    if FindFirstOffTargetMapLegIndex(legs, targetMapID) then
        return not LegRequiresHardTransition(firstLeg)
    end

    if PlanRequiresHardTransition(legs) then
        return false
    end
    if record.type == "manual" then
        return true
    end

    return not PlanRequiresExplicitTransition(legs)
end

local function NormalizeAcceptedLegs(record, backendID, legs, reason)
    if ShouldCollapseCurrentMapSetupRoute(record, legs, reason) then
        local directLeg = MakeDirectDestinationLeg(record, backendID)
        if directLeg then
            return { directLeg }
        end
    end
    return legs
end

local function ClearRecordPlan(record)
    if type(record) ~= "table" then
        return
    end
    record.legs = nil
    record.currentLegIndex = nil
    record.currentLeg = nil
    record.specialAction = nil
    record._corePlanning = nil
    record._coreRoutePending = nil
    record.planFingerprint = nil
    record.lastPlanSkippedAt = nil
    record.lastPlanSkipReason = nil
    record.lastPlanSkipStatus = nil
    record.lastPlanSkippedFingerprint = nil
    record.routeOutcome = nil
    record.routeOutcomeReason = nil
    record.routeOutcomeAt = nil
end

local function FormatPlanCoord(value)
    if type(value) == "number" then
        return string.format("%.5f", value)
    end
    return "-"
end

local function BuildAuthorityTargetSignature(mapID, x, y, title, guideTarget)
    return table.concat({
        tostring(mapID or "-"),
        FormatPlanCoord(x),
        FormatPlanCoord(y),
        tostring(title or "-"),
        tostring(type(guideTarget) == "table" and guideTarget.guideProvider or "-"),
        tostring(type(guideTarget) == "table" and guideTarget.rawTitle or "-"),
        tostring(type(guideTarget) == "table" and guideTarget.source or "-"),
    }, "|")
end

local function FingerprintGate(gate)
    if type(gate) ~= "table" then
        return "-"
    end
    return table.concat({
        tostring(gate.indoors),
        tostring(NormalizeZoneText(gate.zone) or "-"),
        tostring(NormalizeZoneText(gate.realzone) or "-"),
        tostring(NormalizeZoneText(gate.subzone) or "-"),
        tostring(NormalizeZoneText(gate.minizone) or "-"),
    }, "/")
end

local function FingerprintCoords(coords)
    if type(coords) ~= "table" then
        return "-"
    end
    return table.concat({
        tostring(coords.mapID or "-"),
        FormatPlanCoord(coords.x),
        FormatPlanCoord(coords.y),
    }, "/")
end

local function FingerprintSpecialAction(action)
    if type(action) ~= "table" then
        return "-"
    end
    return table.concat({
        tostring(action.semanticKind or "-"),
        tostring(action.secureType or "-"),
        tostring(action.securePayload or "-"),
        tostring(action.destinationName or "-"),
        tostring(action.activationMode or "-"),
        FingerprintCoords(action.activationCoords),
    }, "/")
end

local function FingerprintLeg(leg)
    if type(leg) ~= "table" then
        return "-"
    end
    return table.concat({
        tostring(leg.mapID or "-"),
        FormatPlanCoord(leg.x),
        FormatPlanCoord(leg.y),
        tostring(leg.title or "-"),
        tostring(leg.source or "-"),
        tostring(leg.kind or "-"),
        tostring(leg.routeLegKind or "-"),
        tostring(leg.routeTravelType or "-"),
        tostring(leg.arrivalRadius or "-"),
        FingerprintCoords(leg.activationCoords),
        FingerprintGate(leg.arrivalGate),
        FingerprintSpecialAction(leg.specialAction),
    }, ":")
end

local function BuildPlanFingerprint(record, backendID, legs)
    local mapID, x, y, title = ResolveAuthorityDestination(record)
    local parts = {
        tostring(backendID or record and record.backend or "-"),
        tostring(mapID or "-"),
        FormatPlanCoord(x),
        FormatPlanCoord(y),
        tostring(title or "-"),
        tostring(type(legs) == "table" and #legs or 0),
    }
    if type(legs) == "table" then
        for index = 1, #legs do
            parts[#parts + 1] = tostring(index) .. "=" .. FingerprintLeg(legs[index])
        end
    end
    return table.concat(parts, "|")
end

function NS.AcceptBackendPlan(record, backendID, legs, reason, serial)
    if type(record) ~= "table" then
        return false
    end

    local acceptedLegs = type(legs) == "table" and legs or nil
    if type(acceptedLegs) ~= "table" or #acceptedLegs == 0 then
        local fallback = MakeFallbackLeg(record)
        acceptedLegs = fallback and { fallback } or nil
    end
    acceptedLegs = NormalizeAcceptedLegs(record, backendID, acceptedLegs, reason)
    if type(acceptedLegs) ~= "table" or #acceptedLegs == 0 then
        return false
    end

    local outcome = ClassifyRouteOutcome(record, backendID, acceptedLegs, reason)
    MarkRouteOutcome(record, outcome, reason)
    if outcome == "failed" and IsStrictRouteRecord(record) then
        record.backend = backendID or record.backend
        record.planSerial = serial or record.planSerial
        record.replanReason = reason
        record.planAcceptStatus = "failed"
        record._corePlanning = nil
        record._coreRoutePending = nil
        record._coreResetLegOnNextPlan = nil
        record.lastPlanSkipStatus = nil
        CompletePendingManualRoute(record, outcome, reason)
        return false
    end

    local previousLeg = record.currentLeg
    local resetLeg = record._coreResetLegOnNextPlan == true
    local preservedActionLegIndex = nil
    if not resetLeg
        and NOISY_ACTION_INVALIDATION_BACKEND[backendID or record.backend] == true
        and IsNoisyActionInvalidation(record._coreLastRefreshReason)
    then
        preservedActionLegIndex = PreservePreviousSpecialActionLeg(acceptedLegs, previousLeg)
    end
    local planFingerprint = BuildPlanFingerprint(record, backendID, acceptedLegs)
    local equivalentPlan = type(record.planFingerprint) == "string"
        and record.planFingerprint == planFingerprint
    local currentGateMismatch = equivalentPlan
        and not resetLeg
        and type(record.legs) == "table"
        and type(record.currentLegIndex) == "number"
        and not ArrivalGateMatches(record.legs[record.currentLegIndex])

    record.backend = backendID or record.backend
    record.planSerial = serial or record.planSerial
    record.replanReason = reason
    record._corePlanning = nil
    record._coreRoutePending = nil
    if equivalentPlan and not resetLeg and not currentGateMismatch then
        local churn = state.churn
        if churn and churn.active then
            churn.routePlanSkip = (churn.routePlanSkip or 0) + 1
        end
        record.lastPlanSkippedAt = GetTimeSafe()
        record.lastPlanSkipReason = reason
        record.lastPlanSkipStatus = "equivalent"
        record.lastPlanSkippedFingerprint = planFingerprint
        record._coreResetLegOnNextPlan = nil
        MarkRouteOutcome(record, outcome, reason)
        CompletePendingManualRoute(record, outcome, reason)
        if record.authority == "guide" and type(NS.SyncGuideQueueProjection) == "function" then
            SafeCall(NS.SyncGuideQueueProjection, record)
        end
        RememberRouteEnvironment()
        return true
    end

    record.backend = backendID or record.backend
    record.legs = acceptedLegs
    record.planSerial = serial or record.planSerial
    record.planFingerprint = planFingerprint
    record.planAcceptedAt = GetTimeSafe()
    local churn = state.churn
    if churn and churn.active then
        churn.routePlanAccept = (churn.routePlanAccept or 0) + 1
    end
    record.planAcceptStatus = currentGateMismatch and "equivalent_gate_reset"
        or (equivalentPlan and "equivalent_reset" or "accepted")
    record.lastPlanSkipStatus = nil
    record.replanReason = reason
    if resetLeg then
        record.currentLegIndex = nil
    else
        record.currentLegIndex = preservedActionLegIndex
            or FindMatchingSpecialActionLegIndex(acceptedLegs, previousLeg)
            or FindMatchingLegIndex(acceptedLegs, previousLeg)
    end
    -- Gate regression safety: FindMatchingLegIndex may preserve a leg whose
    -- arrival gate the player no longer satisfies (e.g. matched a portal leg
    -- that requires being indoors, but player is now outside). Reset to leg 1
    -- so the route guides the player back to the required conditions.
    if not resetLeg and record.currentLegIndex then
        if not ArrivalGateMatches(acceptedLegs[record.currentLegIndex]) then
            record.currentLegIndex = nil
        end
    end
    record.currentLeg = nil
    record.specialAction = nil
    record._corePlanning = nil
    record._coreResetLegOnNextPlan = nil
    record._coreLastPlayerMapID = type(NS.GetPlayerMapID) == "function" and NS.GetPlayerMapID() or nil
    MarkRouteOutcome(record, outcome, reason)
    CompletePendingManualRoute(record, outcome, reason)
    if record.authority == "guide" and type(NS.SyncGuideQueueProjection) == "function" then
        SafeCall(NS.SyncGuideQueueProjection, record)
    end
    RememberRouteEnvironment()
    return true
end

-- Switch backend live. Tears down old backend's state, switches the DB
-- key, re-plans whichever authority is active, and recomputes.
function NS.SetBackend(newID)
    local db = NS.GetDB()
    if not db then return false end
    if newID ~= "zygor" and newID ~= "mapzeroth" and newID ~= "farstrider" and newID ~= "direct" then
        return false
    end

    local oldEffective = ResolveEffectiveBackend()
    db.routingBackend = newID
    state.routing.selectedBackend = newID

    -- Tear down old backend's per-record scratch.
    if oldEffective and type(oldEffective.Clear) == "function" then
        SafeCall(oldEffective.Clear, state.routing.manualAuthority, "backend_change")
        SafeCall(oldEffective.Clear, state.routing.guideRouteState, "backend_change")
        if type(state.routing.guideRouteStates) == "table" then
            for _, guideState in pairs(state.routing.guideRouteStates) do
                if guideState ~= state.routing.guideRouteState then
                    SafeCall(oldEffective.Clear, guideState, "backend_change")
                end
            end
        end
    end

    -- Re-plan whichever authority is currently active under the new backend.
    local newEffective = ResolveEffectiveBackend()
    if state.routing.manualAuthority and newEffective and type(newEffective.PlanRoute) == "function" then
        local ma = state.routing.manualAuthority
        ma.backend = newEffective.id
        SafeCall(newEffective.PlanRoute, ma, ma.mapID, ma.x, ma.y, ma.title, ma.meta)
    end
    if state.routing.guideRouteState and state.routing.guideRouteState.target
        and newEffective and type(newEffective.PlanRoute) == "function"
    then
        local gt = state.routing.guideRouteState.target
        state.routing.guideRouteState.backend = newEffective.id
        SafeCall(newEffective.PlanRoute, state.routing.guideRouteState, gt.mapID, gt.x, gt.y, gt.title, nil)
    end

    NS.RecomputeCarrier()
    return true
end

-- ------------------------------------------------------------
-- Routing entrypoint
-- ------------------------------------------------------------

function NS.RouteViaBackend(mapID, x, y, title, meta, opts)
    if type(mapID) ~= "number" or type(x) ~= "number" or type(y) ~= "number" then
        return false
    end
    if NS.IsRoutingEnabled and NS.IsRoutingEnabled() == false then return false end

    local backend = ResolveEffectiveBackend(opts)
    if not backend then return false end

    local authority = opts and opts.authority or "manual"
    if authority == "manual"
        and not (type(opts) == "table" and type(opts.queueContext) == "table")
        and type(NS.HandleManualQueueRoutingPolicy) == "function"
        and NS.HandleManualQueueRoutingPolicy(mapID, x, y, title, meta, opts)
    then
        return true
    end

    if authority == "guide" then
        local guideTarget = opts and opts.guideTarget or nil
        local providerKey = type(opts) == "table" and type(opts.guideProvider) == "string" and opts.guideProvider
            or type(guideTarget) == "table" and guideTarget.guideProvider
            or type(NS.GetActiveGuideProvider) == "function" and NS.GetActiveGuideProvider()
            or "zygor"
        providerKey = tostring(providerKey):lower()
        state.routing.guideRouteStates = state.routing.guideRouteStates or {}
        local gs = state.routing.guideRouteStates[providerKey] or {}
        local targetSig = BuildAuthorityTargetSignature(mapID, x, y, title, guideTarget)
        if gs._coreTargetSignature ~= targetSig then
            ClearRecordPlan(gs)
            gs._coreTargetSignature = targetSig
        end
        gs.target = gs.target or {}
        gs.target.mapID = mapID
        gs.target.x     = x
        gs.target.y     = y
        gs.target.title = title
        gs.target.kind  = type(guideTarget) == "table" and (guideTarget.kind or "guide_goal") or "guide_goal"
        gs.target.source = type(guideTarget) == "table" and guideTarget.source or nil
        gs.target.rawTitle = type(guideTarget) == "table" and guideTarget.rawTitle or nil
        gs.target.subtext = type(guideTarget) == "table" and guideTarget.subtext or nil
        gs.target.guideProvider = providerKey
        gs.target.liveRouteLegKind = type(guideTarget) == "table" and guideTarget.liveRouteLegKind or nil
        gs.suppressed   = false
        gs.backend = backend.id
        gs.authority = "guide"
        gs.guideProvider = providerKey
        gs.guideSource = gs.target.source
        gs.rawTitle = gs.target.rawTitle
        gs.subtext = gs.target.subtext
        gs.liveRouteLegKind = gs.target.liveRouteLegKind
        gs.semanticKind = type(guideTarget) == "table" and guideTarget.semanticKind or nil
        gs.semanticQuestID = type(guideTarget) == "table" and guideTarget.semanticQuestID or nil
        gs.semanticTravelType = type(guideTarget) == "table" and guideTarget.semanticTravelType or nil
        gs.iconHintKind = type(guideTarget) == "table" and guideTarget.iconHintKind or nil
        gs.iconHintQuestID = type(guideTarget) == "table" and guideTarget.iconHintQuestID or nil
        state.routing.guideRouteStates[providerKey] = gs
        state.routing.activeGuideProvider = providerKey
        if type(NS.SetActiveRouteSource) == "function" then
            NS.SetActiveRouteSource("guide")
        end
        state.routing.guideRouteState = gs
        SafeCall(backend.PlanRoute, gs, mapID, x, y, title, meta)
    else
        local queueContext = nil
        local queueTransaction = nil
        if type(NS.PrepareManualQueueRouteRequest) == "function" then
            queueContext, meta, queueTransaction = NS.PrepareManualQueueRouteRequest(mapID, x, y, title, meta, opts or {})
        end
        local record = NS.BuildManualAuthorityRecord(mapID, x, y, title, meta, backend.id)
        if not record then return false end
        if type(queueContext) == "table" then
            record.queueID = queueContext.queueID
            record.queueKind = queueContext.queueKind
            record.queueSourceType = queueContext.queueSourceType
            record.queueItemIndex = queueContext.queueItemIndex
            record.queueIsTransient = queueContext.queueIsTransient == true or nil
        end
        local strictRouteSuccess = type(opts) == "table" and opts.strictRouteSuccess == true
            or type(queueContext) == "table" and queueContext.strictRouteSuccess == true
            or type(queueTransaction) == "table" and queueTransaction.strictRouteSuccess == true
        if strictRouteSuccess then
            local routing = state.routing
            CancelPendingManualRoute("superseded")
            routing._pendingManualRouteSerial = (tonumber(routing._pendingManualRouteSerial) or 0) + 1
            record.strictRouteSuccess = true
            record._coreStrictRouteSuccess = true
            record._corePendingManualRoute = true
            record._corePendingRouteSerial = routing._pendingManualRouteSerial
            record._corePendingQueueTransaction = queueTransaction
            routing.pendingManualAuthority = record
            SafeCall(backend.PlanRoute, record, mapID, x, y, title, meta)
            if record._corePendingManualRoute == true
                and record._coreRoutePending ~= true
                and record.routeOutcome == nil
            then
                MarkRouteOutcome(record, "failed", "backend_no_plan")
                CompletePendingManualRoute(record, "failed", "backend_no_plan")
            end
            NS.RecomputeCarrier()
            return record._coreStrictRouteSucceeded == true or record._corePendingManualRoute == true
        end

        CancelPendingManualRoute("manual_route")
        SafeCall(backend.PlanRoute, record, mapID, x, y, title, meta)
        if type(NS.CommitManualAuthority) == "function" then
            NS.CommitManualAuthority(record)
        end
    end

    NS.RecomputeCarrier()
    return true
end

-- ------------------------------------------------------------
-- Carrier recompute single arbitration entrypoint
-- ------------------------------------------------------------
--
-- Push-driven on state change. Authority order is manual > guide > idle.
-- Dedupes against state.routing.lastPushedCarrierUID/Sig and
-- lastPushedOverlaySig so identical re-pushes are no-ops.

local function ArbitrateAuthority()
    local routing = state.routing
    if routing.manualAuthority then
        return routing.manualAuthority, "manual"
    end
    if routing.pendingManualAuthority then
        return nil, nil
    end
    local gs = type(NS.GetActiveGuideRouteState) == "function" and NS.GetActiveGuideRouteState() or routing.guideRouteState
    if gs and gs.target and not gs.suppressed
        and type(NS.GetGuideVisibilityState) == "function"
        and NS.GetGuideVisibilityState(gs.guideProvider) == "visible"
    then
        return gs, "guide"
    end
    return nil, nil
end

local function IsSameRouteCoord(aMapID, aX, aY, bMapID, bX, bY)
    return type(aMapID) == "number"
        and type(aX) == "number"
        and type(aY) == "number"
        and type(bMapID) == "number"
        and type(bX) == "number"
        and type(bY) == "number"
        and aMapID == bMapID
        and math.abs(aX - bX) <= ROUTE_COORD_TOLERANCE
        and math.abs(aY - bY) <= ROUTE_COORD_TOLERANCE
end

local function SetCoreLegIndex(record, index, reason)
    if type(record) ~= "table" or type(record.legs) ~= "table" or not IsValidLeg(record.legs[index]) then
        return false
    end

    local previousIndex = tonumber(record.currentLegIndex)
    local previousLeg = record.currentLeg
    local leg = record.legs[index]
    record.currentLegIndex = index
    record.currentLeg = leg
    record.specialAction = SanitizeSpecialAction(leg.specialAction)

    if previousIndex and previousIndex ~= index then
        record._coreLastAdvancedLegSig = GetLegSignature(previousLeg)
        record._coreLastAdvanceReason = reason
        record._coreLastAdvanceAt = GetTimeSafe()
    end
    return previousIndex ~= index
end

local function EnsureCoreLeg(record)
    if type(record) ~= "table" then
        return nil
    end

    if type(record.legs) ~= "table" or #record.legs == 0 then
        if record._corePlanning == true then
            record.currentLegIndex = nil
            record.currentLeg = nil
            record.specialAction = nil
            return nil
        end
        local fallback = MakeFallbackLeg(record)
        if not fallback then
            return nil
        end
        record.legs = { fallback }
        record.currentLegIndex = nil
        record.currentLeg = nil
        record.specialAction = nil
    end

    local index = tonumber(record.currentLegIndex) or 1
    if not IsValidLeg(record.legs[index]) then
        index = 1
    end
    SetCoreLegIndex(record, index, "ensure")
    return record.currentLeg
end

local function ResolveLegToCarry(record)
    return EnsureCoreLeg(record)
end

local function GetPlayerMapIDSafe()
    return type(NS.GetPlayerMapID) == "function" and NS.GetPlayerMapID() or nil
end

local function IsDistanceAdvanceLeg(leg)
    if not IsValidLeg(leg) then
        return false
    end
    if IsSecureSpecialAction(leg.specialAction) then
        return false
    end
    return DISTANCE_ADVANCE_KIND[leg.kind] == true
end

local function ShouldAdvanceByDistance(leg)
    if not IsDistanceAdvanceLeg(leg) or type(NS.GetPlayerWaypointDistance) ~= "function" then
        return false
    end
    if not ArrivalGateMatches(leg) then
        return false
    end

    local distance = NS.GetPlayerWaypointDistance(leg.mapID, leg.x, leg.y)
    if type(distance) ~= "number" then
        return false
    end

    local radius = type(leg.arrivalRadius) == "number" and leg.arrivalRadius or nil
    if type(radius) ~= "number" then
        radius = DISTANCE_ADVANCE_KIND[leg.kind] and DEFAULT_MOVEMENT_RADIUS_YARDS or DEFAULT_ACTION_RADIUS_YARDS
    end
    return distance <= radius
end

local function AdvanceToPlayerMapLeg(record, currentIndex, playerMapID)
    if type(playerMapID) ~= "number" or type(record.legs) ~= "table" then
        return false
    end
    for index = currentIndex + 1, #record.legs do
        local leg = record.legs[index]
        if IsValidLeg(leg) and leg.mapID == playerMapID then
            return SetCoreLegIndex(record, index, "map_transition")
        end
    end
    return false
end

local function AdvanceAuthorityLeg(record, reason)
    local leg = EnsureCoreLeg(record)
    if type(leg) ~= "table" or not IsValidLeg(leg) or type(record.legs) ~= "table" then
        return false
    end

    local currentIndex = tonumber(record.currentLegIndex) or 1
    if currentIndex >= #record.legs then
        record._coreLastPlayerMapID = GetPlayerMapIDSafe()
        return false
    end

    local playerMapID = GetPlayerMapIDSafe()
    local previousMapID = record._coreLastPlayerMapID
    record._coreLastPlayerMapID = playerMapID

    if type(playerMapID) == "number"
        and type(previousMapID) == "number"
        and playerMapID ~= previousMapID
        and AdvanceToPlayerMapLeg(record, currentIndex, playerMapID)
    then
        return true
    end

    local activationCoords = type(leg.activationCoords) == "table" and leg.activationCoords or nil
    if type(playerMapID) == "number"
        and type(activationCoords) == "table"
        and type(activationCoords.mapID) == "number"
        and playerMapID ~= activationCoords.mapID
    then
        return SetCoreLegIndex(record, currentIndex + 1, "left_source_map")
    end

    if ShouldAdvanceByDistance(leg) then
        return SetCoreLegIndex(record, currentIndex + 1, "distance")
    end

    return false
end

function NS.PollNeutralRouteLeg(record, reason)
    return AdvanceAuthorityLeg(record, reason or "backend_poll")
end

local function ResolveCarrierSemanticKind(authority, source, leg)
    if type(leg) ~= "table" then
        return source == "guide" and "guide" or "manual", "destination"
    end

    if leg.kind == "corpse" then
        return "corpse", "destination"
    end

    if leg.routeLegKind == "destination" then
        return source == "guide" and "guide" or "manual", "destination"
    end

    if leg.routeLegKind == "carrier" then
        return "route", "carrier"
    end

    local destMapID, destX, destY = ResolveAuthorityDestination(authority)
    if IsSameRouteCoord(leg.mapID, leg.x, leg.y, destMapID, destX, destY) then
        return source == "guide" and "guide" or "manual", "destination"
    end

    if type(leg.kind) == "string"
        and leg.kind ~= ""
        and leg.kind ~= "destination"
        and leg.kind ~= "guide_goal"
    then
        return "route", "carrier"
    end

    return "route", "carrier"
end

local function NormalizeCarrierRouteTravelType(leg)
    if type(leg) ~= "table" then
        return nil
    end

    local travelType = type(leg.routeTravelType) == "string" and leg.routeTravelType or nil
    if travelType == "hearthstone" then
        return "hearth"
    end
    if travelType == "carrier"
        or travelType == "walk"
        or travelType == "fly"
        or travelType == "ship"
        or travelType == "zeppelin"
    then
        return "travel"
    end
    if travelType then
        return travelType
    end

    if leg.routeLegKind ~= "carrier" then
        return nil
    end
    if leg.kind == "portal" or leg.kind == "taxi" then
        return leg.kind
    end
    if leg.kind == "hearthstone" then
        return "hearth"
    end
    return "travel"
end

local function BuildCarrierSignature(mapID, x, y)
    if type(Signature) == "function" then
        return Signature(mapID, x, y)
    end
    return string.format("%s:%s:%s", tostring(mapID), tostring(x), tostring(y))
end

local function EnsureCarrierStateWithoutTomTom(mapID, x, y, title)
    local routing = state.routing
    local sig = BuildCarrierSignature(mapID, x, y)
    local carrier = type(routing.carrierState) == "table" and routing.carrierState or {}
    if carrier.sig ~= sig then
        carrier.uid = nil
        carrier.overlayUID = nil
    end
    carrier.mapID = mapID
    carrier.x = x
    carrier.y = y
    carrier.title = title
    carrier.sig = sig
    carrier.uid = nil
    carrier.overlayUID = carrier.overlayUID or { fromAWPOverlayCarrier = true }
    routing.carrierState = carrier
    routing.lastPushedCarrierUID = nil
    return carrier
end

local function ResolveCarrierPresentationTitle(
    routing,
    authority,
    source,
    leg,
    fallbackTitle,
    semanticKind,
    routeLegKind,
    destinationMapID,
    destinationX,
    destinationY,
    destinationTitle
)
    if type(NS.ResolvePresentation) ~= "function" then
        return fallbackTitle
    end

    local previousCarrier = routing.carrierState
    local previewCarrier = {
        mapID = leg.mapID,
        x = leg.x,
        y = leg.y,
        title = fallbackTitle,
        sig = BuildCarrierSignature(leg.mapID, leg.x, leg.y),
        source = source,
        kind = semanticKind,
        routeLegKind = routeLegKind,
        routeTravelType = NormalizeCarrierRouteTravelType(leg),
        plannerLegKind = leg.kind or nil,
        finalMapID = destinationMapID,
        finalX = destinationX,
        finalY = destinationY,
        finalTitle = destinationTitle,
    }

    routing.carrierState = previewCarrier
    local ok, presentation = pcall(NS.ResolvePresentation)
    routing.carrierState = previousCarrier

    if ok and type(presentation) == "table" and type(presentation.carrierTitle) == "string" and presentation.carrierTitle ~= "" then
        return presentation.carrierTitle
    end
    return fallbackTitle
end

local function ReplanAuthority(record, reason)
    if type(record) ~= "table" then
        return false
    end

    local mapID, x, y, title = ResolveAuthorityDestination(record)
    if type(mapID) ~= "number" or type(x) ~= "number" or type(y) ~= "number" then
        return false
    end

    local backend = GetBackendObject(record.backend) or ResolveEffectiveBackend()
    if not backend or type(backend.PlanRoute) ~= "function" then
        return false
    end

    record.backend = backend.id
    record._coreLastRefreshReason = reason
    record._coreLastRefreshAt = GetTimeSafe()
    if ShouldResetLegOnReplan(reason) then
        record._coreResetLegOnNextPlan = true
    end
    SafeCall(backend.PlanRoute, record, mapID, x, y, title, BuildPlanMeta(record, reason))
    return true
end

function NS.RefreshActiveRoutePlans(reason)
    local routing = state.routing
    -- Defense in depth: if the cast-freeze flipped on after a refresh
    -- was already scheduled but before the debounce timer fired, drop
    -- the pending replan rather than racing the cast.
    if routing.specialActionCasting then
        return false
    end
    local record = routing.manualAuthority
    if not record then
        local gs = type(NS.GetActiveGuideRouteState) == "function" and NS.GetActiveGuideRouteState() or routing.guideRouteState
        if gs and gs.target and not gs.suppressed then
            record = gs
        end
    end
    local replanned = ReplanAuthority(record, reason or "refresh")
    if replanned and type(NS.RecomputeCarrier) == "function" then
        NS.RecomputeCarrier()
    end
    return replanned
end

function NS.ScheduleActiveRouteRefresh(reason)
    local routing = state.routing

    -- Special-action cast in progress: freeze replans so a transient
    -- side-effect of the cast (e.g. hearthstone going on cooldown,
    -- LibRover/Mapzeroth re-reporting travel options) doesn't switch
    -- the route to an alternative leg mid-cast. The cast-end handler
    -- in bridge/routing/special_actions.lua drops the flag and triggers a
    -- single post_cast refresh.
    if routing.specialActionCasting then
        return
    end

    if routing._routeRefreshPending then
        -- Reset reasons (zone change, map load, vehicle, etc.) take priority
        -- over non-reset reasons (leg_advance, LIBROVER_TRAVEL_REPORTED, etc.).
        -- Without this, a LIBROVER_TRAVEL_REPORTED event arriving after
        -- ZONE_CHANGED would silently overwrite the reset reason and the leg
        -- index would never be cleared on building exit.
        local currentIsReset = ShouldResetLegOnReplan(routing._routeRefreshReason)
        local newIsReset = ShouldResetLegOnReplan(reason)
        if newIsReset or not currentIsReset then
            routing._routeRefreshReason = reason or routing._routeRefreshReason
        end
        return
    end

    local elapsed = GetTimeSafe() - (routing._lastRouteRefreshAt or 0)
    local delay = elapsed >= ROUTE_REPLAN_DEBOUNCE_SECONDS
        and 0
        or ROUTE_REPLAN_DEBOUNCE_SECONDS - elapsed

    routing._routeRefreshPending = true
    routing._routeRefreshReason = reason
    NS.After(delay, function()
        routing._routeRefreshPending = false
        routing._lastRouteRefreshAt = GetTimeSafe()
        NS.RefreshActiveRoutePlans(routing._routeRefreshReason or "scheduled")
        routing._routeRefreshReason = nil
    end)
end

function NS.NoteRouteEnvironmentChanged(reason)
    local routing = state.routing
    routing._lastRouteEnvironmentChange = reason
    local shouldRefresh = ShouldRefreshForEnvironment(reason or "environment")
    if shouldRefresh and (routing.manualAuthority or (type(NS.GetActiveGuideRouteState) == "function" and NS.GetActiveGuideRouteState() or routing.guideRouteState)) then
        NS.ScheduleActiveRouteRefresh(reason or "environment")
    end
    NS.RecomputeCarrier()
end

local function ShouldSuppressNoisyActionInvalidation(record, backendID, reason)
    if not NOISY_ACTION_INVALIDATION_BACKEND[backendID] or not IsNoisyActionInvalidation(reason) then
        return false
    end

    local routing = state.routing
    if routing.specialActionPresented ~= true then
        return false
    end

    local currentLeg = type(record) == "table" and record.currentLeg or nil
    local activeAction = SanitizeSpecialAction(record and record.specialAction)
        or SanitizeSpecialAction(currentLeg and currentLeg.specialAction)
    local presentedAction = SanitizeSpecialAction(routing.specialActionState)
    local activeIdentity = GetSpecialActionIdentity(activeAction)
    local presentedIdentity = GetSpecialActionIdentity(presentedAction)

    return type(activeIdentity) == "string" and activeIdentity == presentedIdentity
end

function NS.NoteRouteBackendInvalidated(backendID, reason)
    local routing = state.routing
    local record = routing.manualAuthority
    if not record then
        local gs = type(NS.GetActiveGuideRouteState) == "function" and NS.GetActiveGuideRouteState() or routing.guideRouteState
        if gs and gs.target and not gs.suppressed then
            record = gs
        end
    end
    if type(record) ~= "table" or record.backend ~= backendID then
        return false
    end
    if backendID == "zygor"
        and reason == "LIBROVER_TRAVEL_REPORTED"
        and type(record._zygorSuppressLibRoverReportedUntil) == "number"
        and record._zygorSuppressLibRoverReportedUntil > GetTimeSafe()
    then
        local churn = state.churn
        if churn and churn.active then
            churn.routeBackendInvalidationSkip = (churn.routeBackendInvalidationSkip or 0) + 1
        end
        record._coreLastBackendInvalidationSkipped = reason
        record._coreLastBackendInvalidationSkippedAt = GetTimeSafe()
        return false
    end
    if ShouldSuppressNoisyActionInvalidation(record, backendID, reason) then
        local churn = state.churn
        if churn and churn.active then
            churn.routeBackendInvalidationSkip = (churn.routeBackendInvalidationSkip or 0) + 1
        end
        record._coreLastBackendInvalidationSkipped = reason
        record._coreLastBackendInvalidationSkippedAt = GetTimeSafe()
        record._coreLastBackendInvalidationSkipReason = "active_special_action"
        return false
    end
    local churn = state.churn
    if churn and churn.active then
        churn.routeBackendInvalidation = (churn.routeBackendInvalidation or 0) + 1
    end
    NS.ScheduleActiveRouteRefresh(reason or "backend_invalidated")
    NS.RecomputeCarrier()
    return true
end

local function ScheduleRefreshAfterAdvance(record)
    if type(record) ~= "table" or record.backend == "direct" then
        return
    end
    local advancedSig = record._coreLastAdvancedLegSig
    if type(advancedSig) ~= "string" or record._coreLastRefreshAdvanceSig == advancedSig then
        return
    end
    record._coreLastRefreshAdvanceSig = advancedSig
    NS.ScheduleActiveRouteRefresh(record._coreLastAdvanceReason or "leg_advance")
end

local function ClearCarrierPresentation()
    local routing = state.routing
    if routing.carrierState then NS.ClearCarrierWaypoint() end
    if type(NS.ClearPublishedQueuePins) == "function" then
        NS.ClearPublishedQueuePins()
    end
    if routing.specialActionState then
        routing.specialActionState = nil
        if NS.DisarmSpecialActionButton then NS.DisarmSpecialActionButton() end
    end
    if routing.lastPushedOverlaySig ~= nil then
        if type(NS.SyncWorldOverlay) == "function" then
            SafeCall(NS.SyncWorldOverlay, nil, nil, nil, nil, nil, nil, nil, nil)
        end
        routing.lastPushedOverlaySig = nil
    end
    routing.presentationState = nil
    if type(NS.SyncGuideVisualState) == "function" then
        NS.SyncGuideVisualState()
    end
end

local function PollCoreCurrentLeg(record, source)
    return AdvanceAuthorityLeg(record, source == "manual" and "manual_progress" or "guide_progress")
end

function NS.RecomputeCarrier()
    if _G.InCombatLockdown() then
        state.routing.pendingCarrierRecompute = true
        return
    end
    local routing = state.routing
    local authority, source = ArbitrateAuthority()
    local advanced = PollCoreCurrentLeg(authority, source)
    if source == "manual"
        and type(NS.CheckManualAuthorityArrival) == "function"
        and not routing._manualArrivalCheckActive
    then
        routing._manualArrivalCheckActive = true
        local cleared = NS.CheckManualAuthorityArrival()
        routing._manualArrivalCheckActive = false
        if cleared then
            return
        end
    end
    if advanced then
        ScheduleRefreshAfterAdvance(authority)
    end
    authority, source = ArbitrateAuthority()

    -- No authority, release carrier.
    if not authority then
        ClearCarrierPresentation()
        return
    end

    local leg = ResolveLegToCarry(authority)
    if not leg then
        ClearCarrierPresentation()
        return
    end
    if type(NS.SetActiveRouteSource) == "function" then
        SafeCall(NS.SetActiveRouteSource, source)
    end
    local semanticKind, routeLegKind = ResolveCarrierSemanticKind(authority, source, leg)
    local destinationMapID, destinationX, destinationY, destinationTitle = ResolveAuthorityDestination(authority)

    -- Surface the active special action (if any) to state.routing.
    routing.specialActionState = SanitizeSpecialAction(authority.specialAction) or SanitizeSpecialAction(leg.specialAction)
    local specialAction = type(routing.specialActionState) == "table" and routing.specialActionState or nil
    if specialAction and rawget(specialAction, "sig") == nil then
        local actionSig = nil
        if type(Signature) == "function"
            and type(leg.mapID) == "number"
            and type(leg.x) == "number"
            and type(leg.y) == "number"
        then
            actionSig = Signature(leg.mapID, leg.x, leg.y)
        end
        if type(actionSig) == "string" then
            specialAction["sig"] = actionSig .. ":" .. tostring(rawget(specialAction, "semanticKind") or "_")
        end
    end

    -- Update carrier (TomTom waypoint + UID), with sig dedupe inside
    -- PushCarrierWaypoint.
    local rawTitle = leg.title or authority.title or destinationTitle
    local title = ResolveCarrierPresentationTitle(
        routing,
        authority,
        source,
        leg,
        rawTitle,
        semanticKind,
        routeLegKind,
        destinationMapID,
        destinationX,
        destinationY,
        destinationTitle
    ) or rawTitle or "AWP Route"
    local tomTomPushed = NS.PushCarrierWaypoint(leg.mapID, leg.x, leg.y, title, authority.meta)
    if not tomTomPushed then
        EnsureCarrierStateWithoutTomTom(leg.mapID, leg.x, leg.y, title)
    end

    -- carrierState.source/kind annotate where the carrier came from.
    if routing.carrierState then
        routing.carrierState.source = source
        routing.carrierState.kind = semanticKind
        routing.carrierState.title = title
        routing.carrierState.routeLegKind = routeLegKind
        routing.carrierState.routeTravelType = NormalizeCarrierRouteTravelType(leg)
        routing.carrierState.plannerLegKind = leg.kind or nil
        routing.carrierState.finalMapID = destinationMapID
        routing.carrierState.finalX = destinationX
        routing.carrierState.finalY = destinationY
        routing.carrierState.finalTitle = destinationTitle
    end

    -- Resolve presentation before showing special actions so the secure
    -- button and TomTom title both see the final mirrored title.
    local presentation = NS.ResolvePresentation()
    routing.presentationState = presentation
    if type(NS.SyncAuthorityQueueProjection) == "function" then
        SafeCall(NS.SyncAuthorityQueueProjection, authority, source)
    end
    if type(NS.PublishQueueProjectionPins) == "function" then
        SafeCall(NS.PublishQueueProjectionPins)
    end
    if presentation and type(NS.RefreshCarrierWaypointTitle) == "function" then
        SafeCall(NS.RefreshCarrierWaypointTitle, presentation.carrierTitle or title)
    end

    -- Apply the special action (combat-safe via ApplySpecialAction).
    if routing.specialActionState then
        if NS.ApplySpecialAction then
            SafeCall(NS.ApplySpecialAction, routing.specialActionState)
        end
    else
        if NS.DisarmSpecialActionButton then NS.DisarmSpecialActionButton() end
    end

    -- Push to world overlay with sig dedupe.
    if presentation and presentation.overlaySig ~= routing.lastPushedOverlaySig then
        if type(NS.SyncWorldOverlay) == "function" then
            local cs = routing.carrierState
            local overlayUID = cs and (cs.uid or cs.overlayUID or cs) or nil
            SafeCall(NS.SyncWorldOverlay,
                overlayUID,
                cs and cs.mapID or nil,
                cs and cs.x or nil,
                cs and cs.y or nil,
                presentation.overlayTitle,
                source,
                cs and cs.kind or nil,
                presentation -- contentSnapshot: world_overlay reads what it needs
            )
        end
        routing.lastPushedOverlaySig = presentation.overlaySig
    end
    if type(NS.SyncGuideVisualState) == "function" then
        NS.SyncGuideVisualState()
    end
end

-- ------------------------------------------------------------
-- Boot
-- ------------------------------------------------------------

function NS.InitializeRoutingCore()
    local db = NS.GetDB()
    if db then
        state.routing.selectedBackend = db.routingBackend or "direct"
    end

    local backends = {
        NS.RoutingBackend_Direct,
        NS.RoutingBackend_Zygor,
        NS.RoutingBackend_Mapzeroth,
        NS.RoutingBackend_Farstrider,
    }
    for index = 1, #backends do
        local backend = backends[index]
        if backend and type(backend.Initialize) == "function" then
            SafeCall(backend.Initialize)
        end
    end

    NS.TickUpdate = function()
        NS.RecomputeCarrier()
    end

    NS.SetCinematicActive = function(active)
        state.routing.cinematicActive = active and true or false
        NS.RecomputeCarrier()
    end

    -- Once Zygor pointer is ready, start guide routing evaluation. The
    -- ScheduleZygorPointerWork helper in init.lua already gates Zygor-
    -- dependent work; we add ours through that channel via init.lua.
end
