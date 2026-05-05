local NS = _G.AzerothWaypointNS
local state = NS.State
local Queue = NS.RouteQueueInternal

-- ============================================================
-- Guide provider dispatcher
-- ============================================================
--
-- Guide addons are target providers, not routing backends. Each provider
-- extracts one current guide target; the selected routing backend still plans
-- the path. Manual/transient authority remains higher priority than all guide
-- providers.

local GUIDE_COORD_EPSILON = 0.00005
local providers = {}
local providerOrder = {}
local providerStarted = {}
local pendingByProvider = {}
local pendingReasonByProvider = {}
local pendingOptsByProvider = {}

local function TrimString(value)
    if type(value) ~= "string" then
        return nil
    end
    value = value:gsub("^%s+", ""):gsub("%s+$", "")
    if value == "" then
        return nil
    end
    return value
end

local function NormalizeProviderKey(value)
    value = TrimString(value)
    return value and value:lower() or nil
end

local function GetTimeSafe()
    return type(GetTime) == "function" and GetTime() or 0
end

local function EnsureGuideRoutingState()
    state.routing = state.routing or {}
    state.routing.guideRouteStates = state.routing.guideRouteStates or {}
    if type(Queue) == "table" and type(Queue.EnsureQueueState) == "function" then
        Queue.EnsureQueueState()
    end
    return state.routing
end

local function GetDB()
    return type(NS.GetDB) == "function" and NS.GetDB() or nil
end

local function SaveActiveGuideProvider(providerKey)
    local db = GetDB()
    if type(db) == "table" then
        db.activeGuideProvider = providerKey
    end
end

local function GetSavedGuideProvider()
    local db = GetDB()
    return NormalizeProviderKey(type(db) == "table" and db.activeGuideProvider)
end

local function IsValidTarget(target)
    return type(target) == "table"
        and type(target.mapID) == "number"
        and type(target.x) == "number"
        and type(target.y) == "number"
end

function NS.IsValidGuideRouteTarget(target)
    return IsValidTarget(target)
end

local function HasCarrierLeg(legs)
    if type(legs) ~= "table" then
        return false
    end
    for index = 1, #legs do
        local leg = legs[index]
        if type(leg) == "table" and leg.routeLegKind == "carrier" then
            return true
        end
    end
    return false
end

local function IsSameGuideRouteTarget(a, b)
    return IsValidTarget(a)
        and IsValidTarget(b)
        and a.mapID == b.mapID
        and math.abs(a.x - b.x) < GUIDE_COORD_EPSILON
        and math.abs(a.y - b.y) < GUIDE_COORD_EPSILON
end

local function IsGuideDestinationLegForTarget(leg, target)
    if type(leg) ~= "table" or not IsSameGuideRouteTarget(leg, target) then
        return false
    end

    if leg.routeLegKind == "destination" then
        return true
    end

    -- Direct/fallback guide legs should still be considered destinations even
    -- if a backend omitted routeLegKind. Never rewrite carrier/travel legs.
    return leg.routeLegKind == nil
        and (leg.kind == nil or leg.kind == "destination" or leg.kind == "guide_goal" or leg.kind == "guide")
end

local function ClearManualAuthorityForExplicitGuideActivation(reason)
    local authority = type(NS.GetManualAuthority) == "function"
        and NS.GetManualAuthority()
        or state.routing.manualAuthority
    if authority == nil then
        return false
    end

    local clearReason = type(reason) == "string" and reason or "guide_explicit_takeover"
    if type(NS.ClearManualRoute) == "function" then
        NS.ClearManualRoute(clearReason, { preserveGuide = true, preserveManualQueue = true })
    elseif type(NS.ClearManualAuthority) == "function" then
        NS.ClearManualAuthority(clearReason)
    else
        return false
    end

    state.routing.manualArrival = nil
    state.routing.specialActionState = nil
    state.routing.presentationState = nil
    if type(NS.DisarmSpecialActionButton) == "function" then
        NS.DisarmSpecialActionButton()
    end
    if type(NS.ClearCarrierWaypoint) == "function" then
        NS.ClearCarrierWaypoint()
    end
    if type(NS.ClearPublishedQueuePins) == "function" then
        NS.ClearPublishedQueuePins()
    end
    return true
end

local function EnsureGuideQueue(providerKey, label)
    if type(Queue) == "table" and type(Queue.EnsureGuideQueue) == "function" then
        return Queue.EnsureGuideQueue(providerKey, label)
    end
    if type(NS.SetGuideQueueProvider) == "function" then
        return NS.SetGuideQueueProvider(providerKey, label)
    end
    return nil
end

local function SetActiveGuideProvider(providerKey, persist)
    providerKey = NormalizeProviderKey(providerKey)
    local routing = EnsureGuideRoutingState()
    if providerKey then
        EnsureGuideQueue(providerKey, providers[providerKey] and providers[providerKey].label)
    end
    routing.activeGuideProvider = providerKey
    if type(Queue) == "table" and type(Queue.SetActiveGuideProvider) == "function" then
        Queue.SetActiveGuideProvider(providerKey)
    end
    routing.guideRouteState = providerKey and routing.guideRouteStates[providerKey] or nil
    if persist ~= false then
        SaveActiveGuideProvider(providerKey)
    end
    return providerKey
end

function NS.GetActiveGuideProvider()
    local routing = EnsureGuideRoutingState()
    return NormalizeProviderKey(routing.activeGuideProvider)
end

function NS.GetActiveGuideRouteState()
    local routing = EnsureGuideRoutingState()
    local activeProvider = NormalizeProviderKey(routing.activeGuideProvider)
    if activeProvider then
        return routing.guideRouteStates[activeProvider]
    end
    return routing.guideRouteState
end

function NS.GetGuideRouteState(providerKey)
    local routing = EnsureGuideRoutingState()
    providerKey = NormalizeProviderKey(providerKey)
    if providerKey then
        return routing.guideRouteStates[providerKey]
    end
    return NS.GetActiveGuideRouteState()
end

local function GetProvider(providerKey)
    providerKey = NormalizeProviderKey(providerKey)
    return providerKey and providers[providerKey] or nil, providerKey
end

function NS.RegisterGuideTargetProvider(providerKey, adapter)
    providerKey = NormalizeProviderKey(providerKey)
    if not providerKey or type(adapter) ~= "table" then
        return false
    end
    if providers[providerKey] == nil then
        providerOrder[#providerOrder + 1] = providerKey
    end
    adapter.key = providerKey
    adapter.label = adapter.label or adapter.displayName or providerKey
    providers[providerKey] = adapter

    if type(NS.RegisterGuideProvider) == "function" then
        NS.RegisterGuideProvider(providerKey, {
            displayName = adapter.displayName or adapter.label or providerKey,
            icon = adapter.icon,
            iconTint = adapter.iconTint,
            iconSize = adapter.iconSize,
        })
    end
    EnsureGuideQueue(providerKey, adapter.label or adapter.displayName or providerKey)
    return true
end

function NS.GetGuideTargetProvider(providerKey)
    return GetProvider(providerKey)
end

function NS.GetGuideProviderList()
    local list = {}
    for index = 1, #providerOrder do
        list[#list + 1] = providerOrder[index]
    end
    return list
end

local function ProviderIsLoaded(adapter)
    if type(adapter) ~= "table" then
        return false
    end
    if type(adapter.isLoaded) ~= "function" then
        return true
    end
    local ok, loaded = pcall(adapter.isLoaded)
    return ok and loaded == true
end

local function GetProviderVisibility(providerKey)
    local adapter = providers[providerKey]
    if not ProviderIsLoaded(adapter) then
        return "absent"
    end
    if state.routing.cinematicActive then
        return "hidden"
    end
    if type(adapter.getVisibilityState) == "function" then
        local ok, value = pcall(adapter.getVisibilityState)
        if ok and (value == "visible" or value == "hidden" or value == "absent") then
            return value
        end
    end
    return "visible"
end

function NS.GetGuideVisibilityState(providerKey)
    providerKey = NormalizeProviderKey(providerKey)
    if providerKey then
        return GetProviderVisibility(providerKey)
    end

    local activeProvider = NS.GetActiveGuideProvider()
    if activeProvider then
        local activeState = GetProviderVisibility(activeProvider)
        if activeState ~= "absent" then
            return activeState
        end
    end

    local sawHidden = false
    for index = 1, #providerOrder do
        local visibility = GetProviderVisibility(providerOrder[index])
        if visibility == "visible" then
            return "visible"
        elseif visibility == "hidden" then
            sawHidden = true
        end
    end
    return sawHidden and "hidden" or "absent"
end

local function ShouldShowGuideVisuals()
    if NS.GetGuideVisibilityState() ~= "visible" then
        return false
    end
    if state.routing.manualAuthority ~= nil or state.routing.pendingManualAuthority ~= nil then
        return false
    end
    return NS.GetActiveGuideRouteState() ~= nil
end

function NS.SyncGuideVisualState()
    state.routing.guideVisualShown = ShouldShowGuideVisuals()
    return state.routing.guideVisualShown
end

function NS.ClearGuideRouteState(providerKey)
    local routing = EnsureGuideRoutingState()
    providerKey = NormalizeProviderKey(providerKey) or NormalizeProviderKey(routing.activeGuideProvider)
    if not providerKey then
        routing.guideRouteState = nil
        NS.SyncGuideVisualState()
        if type(NS.RecomputeCarrier) == "function" then
            NS.RecomputeCarrier()
        end
        return
    end

    local record = routing.guideRouteStates[providerKey]
    if type(record) == "table" and type(record.backend) == "string" then
        local backend = nil
        if record.backend == "zygor" then
            backend = NS.RoutingBackend_Zygor
        elseif record.backend == "mapzeroth" then
            backend = NS.RoutingBackend_Mapzeroth
        elseif record.backend == "farstrider" then
            backend = NS.RoutingBackend_Farstrider
        elseif record.backend == "direct" then
            backend = NS.RoutingBackend_Direct
        end
        if backend and type(backend.Clear) == "function" then
            pcall(backend.Clear, record, "guide_clear")
        end
    end

    routing.guideRouteStates[providerKey] = nil
    if routing.activeGuideProvider == providerKey then
        routing.guideRouteState = nil
    end
    if type(NS.ClearGuideQueueProjection) == "function" then
        NS.ClearGuideQueueProjection(providerKey)
    end
    NS.SyncGuideVisualState()
    if type(NS.RecomputeCarrier) == "function" then
        NS.RecomputeCarrier()
    end
end

local function BuildPassiveGuideRecord(providerKey, target)
    return {
        mapID = target.mapID,
        x = target.x,
        y = target.y,
        title = target.title,
        rawTitle = target.rawTitle,
        subtext = target.subtext,
        target = target,
        suppressed = false,
        authority = "guide",
        guideProvider = providerKey,
        guideSource = target.source,
        sourceAddon = providerKey,
        semanticKind = target.semanticKind,
        semanticQuestID = target.semanticQuestID,
        semanticTravelType = target.semanticTravelType,
        iconHintKind = target.iconHintKind,
        iconHintQuestID = target.iconHintQuestID,
        createdAt = GetTimeSafe(),
    }
end

local function ApplyGuideTargetPresentation(record, target, providerKey)
    if type(record) ~= "table" or type(target) ~= "table" then
        return false
    end

    local changed = false
    local function set(tbl, key, value)
        if tbl[key] ~= value then
            tbl[key] = value
            changed = true
        end
    end

    providerKey = NormalizeProviderKey(providerKey)
        or NormalizeProviderKey(target.guideProvider)
        or NormalizeProviderKey(record.guideProvider)

    local recordTarget = type(record.target) == "table" and record.target or {}
    if record.target ~= recordTarget then
        record.target = recordTarget
        changed = true
    end

    set(recordTarget, "mapID", target.mapID)
    set(recordTarget, "x", target.x)
    set(recordTarget, "y", target.y)
    set(recordTarget, "title", target.title)
    set(recordTarget, "rawTitle", target.rawTitle)
    set(recordTarget, "subtext", target.subtext)
    set(recordTarget, "source", target.source)
    set(recordTarget, "kind", target.kind or "guide_goal")
    set(recordTarget, "guideProvider", providerKey)
    set(recordTarget, "liveRouteLegKind", target.liveRouteLegKind)
    set(recordTarget, "semanticKind", target.semanticKind)
    set(recordTarget, "semanticQuestID", target.semanticQuestID)
    set(recordTarget, "semanticTravelType", target.semanticTravelType)
    set(recordTarget, "iconHintKind", target.iconHintKind)
    set(recordTarget, "iconHintQuestID", target.iconHintQuestID)

    set(record, "mapID", target.mapID)
    set(record, "x", target.x)
    set(record, "y", target.y)
    set(record, "title", target.title)
    set(record, "rawTitle", target.rawTitle)
    set(record, "subtext", target.subtext)
    set(record, "guideProvider", providerKey)
    set(record, "guideSource", target.source)
    set(record, "sourceAddon", providerKey)
    set(record, "liveRouteLegKind", target.liveRouteLegKind)
    set(record, "semanticKind", target.semanticKind)
    set(record, "semanticQuestID", target.semanticQuestID)
    set(record, "semanticTravelType", target.semanticTravelType)
    set(record, "iconHintKind", target.iconHintKind)
    set(record, "iconHintQuestID", target.iconHintQuestID)

    local function applyLegPresentation(leg)
        if not IsGuideDestinationLegForTarget(leg, target) then
            return
        end

        set(leg, "title", target.title)
        set(leg, "rawTitle", target.rawTitle)
        set(leg, "subtext", target.subtext)
        set(leg, "source", target.source)
        set(leg, "guideProvider", providerKey)
        set(leg, "semanticKind", target.semanticKind)
        set(leg, "semanticQuestID", target.semanticQuestID)
        set(leg, "semanticTravelType", target.semanticTravelType)
        set(leg, "iconHintKind", target.iconHintKind)
        set(leg, "iconHintQuestID", target.iconHintQuestID)
    end

    if type(record.legs) == "table" then
        for index = 1, #record.legs do
            applyLegPresentation(record.legs[index])
        end
    end
    applyLegPresentation(record.currentLeg)

    return changed
end

local function SameGuideRecordTarget(record, target, providerKey)
    return type(record) == "table"
        and NormalizeProviderKey(record.guideProvider) == providerKey
        and IsSameGuideRouteTarget(record.target, target)
        and tostring(record.target and record.target.rawTitle or "") == tostring(target and target.rawTitle or "")
        and tostring(record.target and record.target.source or "") == tostring(target and target.source or "")
end

local function ShouldRouteProvider(providerKey, opts)
    opts = type(opts) == "table" and opts or {}
    if opts.explicit == true then
        return true
    end
    if state.routing.manualAuthority ~= nil or state.routing.pendingManualAuthority ~= nil then
        return false
    end

    local savedSource = type(NS.GetSavedActiveRouteSource) == "function"
        and NS.GetSavedActiveRouteSource()
        or "guide"
    if savedSource ~= "guide" then
        return false
    end

    local allowProviderSwitch = opts.allowProviderSwitch == true
    local activeProvider = NS.GetActiveGuideProvider()
    if activeProvider then
        if activeProvider == providerKey then
            return true
        end
        if GetProviderVisibility(activeProvider) ~= "visible" then
            return true
        end
        return allowProviderSwitch
    end

    local savedProvider = GetSavedGuideProvider()
    if savedProvider and ProviderIsLoaded(providers[savedProvider]) and GetProviderVisibility(savedProvider) == "visible" then
        return savedProvider == providerKey or allowProviderSwitch
    end
    return true
end

local function StorePassiveGuideProjection(providerKey, target)
    local routing = EnsureGuideRoutingState()
    local record = BuildPassiveGuideRecord(providerKey, target)
    local previous = routing.guideRouteStates[providerKey]
    if type(previous) == "table"
        and previous.authority == "guide"
        and SameGuideRecordTarget(previous, target, providerKey)
        and type(previous.legs) == "table"
    then
        if ApplyGuideTargetPresentation(previous, target, providerKey)
            and type(NS.SyncGuideQueueProjection) == "function"
        then
            NS.SyncGuideQueueProjection(previous)
        end
        return previous
    end
    routing.guideRouteStates[providerKey] = record
    if routing.activeGuideProvider == providerKey then
        routing.guideRouteState = record
    end
    if type(NS.SyncGuideQueueProjection) == "function" then
        NS.SyncGuideQueueProjection(record)
    end
    return record
end

function NS.UpdateGuideTarget(providerKey, target, suppressed, opts)
    if type(providerKey) == "table" then
        opts = suppressed
        suppressed = target
        target = providerKey
        providerKey = NormalizeProviderKey(target and target.guideProvider)
            or NS.GetActiveGuideProvider()
            or "zygor"
    else
        providerKey = NormalizeProviderKey(providerKey) or "zygor"
    end
    opts = type(opts) == "table" and opts or {}

    EnsureGuideQueue(providerKey, providers[providerKey] and providers[providerKey].label)

    if suppressed or not IsValidTarget(target) then
        NS.ClearGuideRouteState(providerKey)
        return false
    end

    target.guideProvider = providerKey
    target.kind = target.kind or "guide_goal"
    target.title = TrimString(target.title) or TrimString(target.rawTitle) or "Guide step"

    if not ShouldRouteProvider(providerKey, opts) then
        StorePassiveGuideProjection(providerKey, target)
        return true
    end

    SetActiveGuideProvider(providerKey, true)
    if type(NS.SetActiveRouteSource) == "function" then
        NS.SetActiveRouteSource("guide")
    end
    if opts.explicit == true then
        ClearManualAuthorityForExplicitGuideActivation(opts.reason or "guide_explicit_takeover")
    end

    local routing = EnsureGuideRoutingState()
    local gs = routing.guideRouteStates[providerKey]
    local effectiveBackend = type(NS.GetEffectiveBackendID) == "function" and NS.GetEffectiveBackendID() or nil
    local sameTarget = SameGuideRecordTarget(gs, target, providerKey)
    local routePending = sameTarget and gs and gs._coreRoutePending == true
    local hasPlannedLegs = sameTarget and type(gs and gs.legs) == "table" and #gs.legs > 0
    local needsCarrierRetry = effectiveBackend ~= "direct"
        and target.liveRouteLegKind == "carrier"
        and not HasCarrierLeg(gs and gs.legs)
        and not routePending
    if sameTarget and (hasPlannedLegs or routePending) and not needsCarrierRetry then
        local presentationChanged = ApplyGuideTargetPresentation(gs, target, providerKey)
        routing.guideRouteState = gs
        if presentationChanged or opts.presentationRefresh == true then
            if hasPlannedLegs and type(NS.RecomputeCarrier) == "function" then
                NS.RecomputeCarrier()
            elseif type(NS.SyncGuideQueueProjection) == "function" then
                NS.SyncGuideQueueProjection(gs)
            end
        end
        NS.SyncGuideVisualState()
        return true
    end

    if type(NS.RouteViaBackend) ~= "function" then
        return false
    end
    local routed = NS.RouteViaBackend(target.mapID, target.x, target.y, target.title, nil, {
        authority = "guide",
        guideTarget = target,
        guideProvider = providerKey,
    })
    NS.SyncGuideVisualState()
    return routed == true
end

local function ExtractProviderTarget(providerKey)
    local adapter = providers[providerKey]
    if not ProviderIsLoaded(adapter) or type(adapter.extractTarget) ~= "function" then
        return nil, true
    end
    local ok, target, suppressed = pcall(adapter.extractTarget)
    if not ok then
        return nil, true
    end
    if IsValidTarget(target) then
        target.guideProvider = providerKey
        target.kind = target.kind or "guide_goal"
        return target, suppressed == true
    end
    return nil, suppressed ~= false
end

local function ChooseDebugProvider(providerKey)
    providerKey = NormalizeProviderKey(providerKey) or NS.GetActiveGuideProvider()
    if providerKey and providers[providerKey] then
        return providerKey
    end

    local activeRecord = NS.GetActiveGuideRouteState()
    providerKey = NormalizeProviderKey(type(activeRecord) == "table" and activeRecord.guideProvider)
    if providerKey and providers[providerKey] then
        return providerKey
    end

    for index = 1, #providerOrder do
        local candidate = providerOrder[index]
        if GetProviderVisibility(candidate) == "visible" then
            return candidate
        end
    end

    for index = 1, #providerOrder do
        local candidate = providerOrder[index]
        if ProviderIsLoaded(providers[candidate]) then
            return candidate
        end
    end
    return nil
end

local function FormatDebugCoords(mapID, x, y)
    if type(mapID) ~= "number" or type(x) ~= "number" or type(y) ~= "number" then
        return "nil"
    end
    return string.format("%s@%.4f,%.4f", tostring(mapID), x, y)
end

local function BuildGenericProviderDebugLines(providerKey)
    local adapter = providers[providerKey]
    local target, suppressed = ExtractProviderTarget(providerKey)
    local record = NS.GetGuideRouteState(providerKey)
    local currentLeg = type(record) == "table" and record.currentLeg or nil
    local lines = {}

    lines[#lines + 1] = table.concat({
        "provider=" .. tostring(providerKey),
        "label=" .. tostring(adapter and adapter.label or "-"),
        "loaded=" .. tostring(ProviderIsLoaded(adapter)),
        "visibility=" .. tostring(GetProviderVisibility(providerKey)),
        "active=" .. tostring(NS.GetActiveGuideProvider() == providerKey),
    }, " ")

    if type(target) == "table" then
        lines[#lines + 1] = table.concat({
            "target",
            "title=" .. tostring(target.title),
            "subtext=" .. tostring(target.subtext),
            "source=" .. tostring(target.source),
            "coords=" .. FormatDebugCoords(target.mapID, target.x, target.y),
            "semanticKind=" .. tostring(target.semanticKind),
            "semanticQuestID=" .. tostring(target.semanticQuestID),
        }, " ")
    else
        lines[#lines + 1] = table.concat({
            "target=nil",
            "suppressed=" .. tostring(suppressed),
        }, " ")
    end

    if type(record) == "table" then
        lines[#lines + 1] = table.concat({
            "route",
            "backend=" .. tostring(record.backend),
            "outcome=" .. tostring(record.routeOutcome),
            "reason=" .. tostring(record.routeOutcomeReason or record.replanReason),
            "legs=" .. tostring(type(record.legs) == "table" and #record.legs or 0),
            "currentLegIndex=" .. tostring(record.currentLegIndex),
            "current=" .. FormatDebugCoords(currentLeg and currentLeg.mapID, currentLeg and currentLeg.x, currentLeg and currentLeg.y),
            "currentTitle=" .. tostring(currentLeg and currentLeg.title),
        }, " ")
    else
        lines[#lines + 1] = "route=nil"
    end

    return lines
end

function NS.GetGuideProviderDebugLines(providerKey)
    providerKey = ChooseDebugProvider(providerKey)
    if not providerKey then
        return { "no guide provider available" }
    end

    local adapter = providers[providerKey]
    if type(adapter) == "table" and type(adapter.getDebugLines) == "function" then
        local ok, lines = pcall(adapter.getDebugLines, BuildGenericProviderDebugLines(providerKey))
        if ok and type(lines) == "table" and #lines > 0 then
            return lines
        end
    end

    return BuildGenericProviderDebugLines(providerKey)
end

local function EvaluateGuideProvider(providerKey, reason, opts)
    providerKey = NormalizeProviderKey(providerKey)
    if not providerKey or GetProviderVisibility(providerKey) ~= "visible" then
        NS.ClearGuideRouteState(providerKey)
        return false
    end
    local target, suppressed = ExtractProviderTarget(providerKey)
    return NS.UpdateGuideTarget(providerKey, target, suppressed, opts)
end

local function MergeEvaluationOpts(previous, nextOpts)
    if type(previous) ~= "table" then
        return nextOpts
    end
    if type(nextOpts) ~= "table" then
        return previous
    end

    local merged = {}
    for key, value in pairs(previous) do
        merged[key] = value
    end
    for key, value in pairs(nextOpts) do
        if key == "explicit" or key == "allowProviderSwitch" then
            merged[key] = merged[key] == true or value == true
        else
            merged[key] = value
        end
    end
    return merged
end

function NS.ScheduleGuideProviderEvaluation(providerKey, reason, opts)
    providerKey = NormalizeProviderKey(providerKey)
    if not providerKey then
        return false
    end
    pendingReasonByProvider[providerKey] = type(reason) == "string" and reason or pendingReasonByProvider[providerKey] or "guide_signal"
    pendingOptsByProvider[providerKey] = MergeEvaluationOpts(pendingOptsByProvider[providerKey], opts)
    if pendingByProvider[providerKey] then
        return true
    end
    pendingByProvider[providerKey] = true
    local function run()
        local signalReason = pendingReasonByProvider[providerKey] or "guide_signal"
        local signalOpts = pendingOptsByProvider[providerKey]
        pendingByProvider[providerKey] = nil
        pendingReasonByProvider[providerKey] = nil
        pendingOptsByProvider[providerKey] = nil
        EvaluateGuideProvider(providerKey, signalReason, signalOpts)
        if type(NS.HandlePendingGuideTakeoverSignal) == "function" then
            NS.HandlePendingGuideTakeoverSignal(signalReason)
        end
    end
    if type(NS.After) == "function" then
        NS.After(0, run)
    else
        run()
    end
    return true
end

function NS.ScheduleActiveGuidePresentationRefresh(reason, opts)
    local routing = EnsureGuideRoutingState()
    if routing.manualAuthority ~= nil or routing.pendingManualAuthority ~= nil then
        return false
    end
    if NS.GetActiveGuideRouteState() == nil then
        return false
    end
    local providerKey = NS.GetActiveGuideProvider()
    if not providerKey or GetProviderVisibility(providerKey) ~= "visible" then
        return false
    end
    opts = type(opts) == "table" and opts or {}
    opts.presentationRefresh = true
    return NS.ScheduleGuideProviderEvaluation(providerKey, reason or "guide_presentation_refresh", opts)
end

function NS.GetCurrentGuideActivationToken(providerKey)
    providerKey = NormalizeProviderKey(providerKey) or NS.GetActiveGuideProvider()
    local adapter = providers[providerKey]
    if type(adapter) == "table" and type(adapter.getActivationToken) == "function" then
        local ok, token = pcall(adapter.getActivationToken)
        if ok then
            return token
        end
    end
    return nil
end

local function DidGuideActivationTokenChange(providerKey, startToken)
    local currentToken = NS.GetCurrentGuideActivationToken(providerKey)
    if startToken == nil then
        return type(currentToken) == "string"
    end
    if type(startToken) ~= "string" then
        return false
    end
    return type(currentToken) == "string" and currentToken ~= startToken
end

local function FindVisibleProviderForTarget(fallbackTarget)
    local activeProvider = NS.GetActiveGuideProvider()
    if activeProvider and GetProviderVisibility(activeProvider) == "visible" then
        return activeProvider
    end
    for index = 1, #providerOrder do
        local providerKey = providerOrder[index]
        if GetProviderVisibility(providerKey) == "visible" then
            local target = ExtractProviderTarget(providerKey)
            if IsSameGuideRouteTarget(target, fallbackTarget) then
                return providerKey
            end
        end
    end
    for index = 1, #providerOrder do
        local providerKey = providerOrder[index]
        if GetProviderVisibility(providerKey) == "visible" then
            return providerKey
        end
    end
    return nil
end

function NS.ActivateGuideProvider(providerKey, reason, opts)
    providerKey = NormalizeProviderKey(providerKey)
    if not providerKey or GetProviderVisibility(providerKey) ~= "visible" then
        return false
    end
    local target, suppressed = ExtractProviderTarget(providerKey)
    if suppressed or not IsValidTarget(target) then
        return false
    end
    opts = type(opts) == "table" and opts or {}
    opts.explicit = true
    opts.reason = reason or opts.reason or "guide_explicit_takeover"
    return NS.UpdateGuideTarget(providerKey, target, false, opts)
end

function NS.ActivateGuideQueueByID(queueID, reason)
    local providerKey = type(Queue) == "table"
        and type(Queue.GetGuideProviderFromQueueID) == "function"
        and Queue.GetGuideProviderFromQueueID(queueID)
        or nil
    providerKey = NormalizeProviderKey(providerKey)
    return providerKey and NS.ActivateGuideProvider(providerKey, reason or "queue_ui") or false
end

function NS.ActivateGuideRouteForExplicitTakeover(reason, opts)
    opts = type(opts) == "table" and opts or {}
    local providerKey = NormalizeProviderKey(opts.providerKey) or FindVisibleProviderForTarget(opts.fallbackTarget)
    if not providerKey then
        return false
    end

    if opts.requireGuideChangeOrTargetMatch == true then
        local target, suppressed = ExtractProviderTarget(providerKey)
        if suppressed or not IsValidTarget(target) then
            return false
        end
        local changed = DidGuideActivationTokenChange(providerKey, opts.startGuideStateToken)
        local matchesTarget = IsSameGuideRouteTarget(target, opts.fallbackTarget)
        if not changed and not matchesTarget then
            return false
        end
    end

    return NS.ActivateGuideProvider(providerKey, reason or "guide_explicit_takeover", opts)
end

local function InstallProviderHooks(providerKey)
    if providerStarted[providerKey] then
        return true
    end
    local adapter = providers[providerKey]
    if not ProviderIsLoaded(adapter) then
        return false
    end
    if type(adapter.installHooks) == "function" then
        local function schedule(reason, opts)
            NS.ScheduleGuideProviderEvaluation(providerKey, reason, opts)
        end
        local ok = pcall(adapter.installHooks, schedule)
        if not ok then
            return false
        end
    end
    providerStarted[providerKey] = true
    return true
end

function NS.StartGuideRoutingEvaluation()
    local routing = EnsureGuideRoutingState()
    if not NormalizeProviderKey(routing.activeGuideProvider) then
        local savedSource = type(NS.GetSavedActiveRouteSource) == "function"
            and NS.GetSavedActiveRouteSource()
            or "guide"
        local savedProvider = savedSource == "guide" and GetSavedGuideProvider() or nil
        if savedProvider and ProviderIsLoaded(providers[savedProvider]) then
            SetActiveGuideProvider(savedProvider, false)
        end
    end

    for index = 1, #providerOrder do
        local providerKey = providerOrder[index]
        if InstallProviderHooks(providerKey) then
            NS.ScheduleGuideProviderEvaluation(providerKey, "initial", { initial = true })
        end
    end
    NS.SyncGuideVisualState()
end
