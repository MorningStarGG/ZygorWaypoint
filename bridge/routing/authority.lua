local NS = _G.AzerothWaypointNS
local state = NS.State

-- ============================================================
-- Manual authority lifecycle
-- ============================================================
--
-- Owns state.routing.manualAuthority — the persisted route that always
-- outranks guide routing in carrier arbitration. Sources include:
--   - manual /way commands
--   - Blizzard takeovers (quest, taxi, vignette, area POI, …)
--   - external TomTom waypoints adopted from other addons
--   - manual queue entries
--   - named/manual searches (Zygor-only)
--   - Zygor POI takeover
--
-- The persisted record (db.manualAuthority) carries enough info to
-- restore the route on /reload via routing_core.RouteViaBackend against
-- the current selected backend. The persisted .backend field is
-- diagnostic-only — restore does NOT honor it.

local Signature = NS.Signature
local SafeCall = NS.SafeCall

local function GetTime_Safe()
    if type(GetTime) == "function" then return GetTime() end
    return 0
end

local function TrimString(value)
    if type(value) ~= "string" then return nil end
    value = value:gsub("^%s+", ""):gsub("%s+$", "")
    if value == "" then return nil end
    return value
end

local function NormalizeSourceAddonCandidate(value)
    value = TrimString(value)
    if not value then return nil end
    local externalSource = type(NS.NormalizeExternalWaypointSource) == "function"
        and NS.NormalizeExternalWaypointSource(value)
        or nil
    if externalSource then
        return externalSource
    end
    return value
end

local function NormalizeSearchKindCandidate(value)
    return TrimString(value)
end

local function NormalizeManualQuestIDCandidate(value)
    if type(value) == "number" and value > 0 then
        return value
    end
    return nil
end

local function NormalizePositiveNumber(value)
    if type(value) ~= "number" or value <= 0 then
        return nil
    end
    return value
end

local ACTIVE_ROUTE_SOURCES = {
    guide = true,
    manual = true,
}

local function IsTransientManualAuthorityRecord(record)
    if type(record) ~= "table" then
        return false
    end
    if record.queueIsTransient == true or record.queueSourceType == "transient_source" then
        return true
    end
    local meta = type(record.meta) == "table" and record.meta or nil
    return type(meta) == "table" and meta.queueSourceType == "transient_source"
end

local function HasSavedManualRouteCandidate(db)
    if type(db) ~= "table" then
        return false
    end
    if type(db.manualAuthority) == "table" and not IsTransientManualAuthorityRecord(db.manualAuthority) then
        return true
    end
    local queues = type(db.manualQueues) == "table" and db.manualQueues or nil
    return type(queues) == "table" and type(queues.activeQueueID) == "string"
end

function NS.GetSavedActiveRouteSource()
    local db = NS.GetDB()
    if type(db) ~= "table" then
        return "guide"
    end

    local source = db.activeRouteSource
    if source == "manual" then
        return HasSavedManualRouteCandidate(db) and "manual" or "guide"
    end
    if source == "guide" then
        return "guide"
    end

    return HasSavedManualRouteCandidate(db) and "manual" or "guide"
end

function NS.SetActiveRouteSource(source)
    if ACTIVE_ROUTE_SOURCES[source] ~= true then
        return false
    end
    local db = NS.GetDB()
    if type(db) ~= "table" then
        return false
    end
    db.activeRouteSource = source
    return true
end

-- ------------------------------------------------------------
-- Record building
-- ------------------------------------------------------------

-- Build a manual-authority record from a route request. Called by
-- routing_core.RouteViaBackend when opts.authority == "manual".
-- The record is the canonical persisted shape — see PLAN.
function NS.BuildManualAuthorityRecord(mapID, x, y, title, meta, backendID)
    if type(mapID) ~= "number" or type(x) ~= "number" or type(y) ~= "number" then
        return nil
    end

    local routeMeta = type(NS.ValidateRouteMeta) == "function"
        and NS.ValidateRouteMeta(meta)
        and meta
        or nil
    if type(routeMeta) ~= "table" then
        local identity = type(meta) == "table" and meta.identity or nil
        if type(NS.ValidateRouteIdentity) == "function" and NS.ValidateRouteIdentity(identity) then
            routeMeta = NS.BuildRouteMeta(identity, {
                sourceAddon = meta.sourceAddon,
                searchKind = meta.searchKind,
                manualQuestID = meta.manualQuestID,
                mapPinInfo = meta.mapPinInfo,
            })
        end
    end
    if type(routeMeta) ~= "table" then
        routeMeta = NS.BuildRouteMeta(NS.BuildManualIdentity(mapID, x, y), nil)
    end
    if type(routeMeta) ~= "table" then
        return nil
    end

    local record = {
        mapID     = mapID,
        map       = mapID,
        x         = x,
        y         = y,
        title     = title,
        type      = "manual",
        sig       = Signature and Signature(mapID, x, y) or nil,
        meta      = routeMeta,
        backend   = backendID,    -- diagnostic only; restore does NOT honor this
        createdAt = GetTime_Safe(),
        -- legs / currentLeg / specialAction populated by the backend in PlanRoute.
    }

    -- Identity fields are pulled from meta so persistence carries enough
    -- info for explicit-remove and queue follow-up logic.
    record.identity = routeMeta.identity
    record.sourceAddon = routeMeta.sourceAddon
    record.searchKind = routeMeta.searchKind
    record.manualQuestID = routeMeta.manualQuestID
    record.mapPinInfo = routeMeta.mapPinInfo

    return record
end

-- ------------------------------------------------------------
-- Lifecycle
-- ------------------------------------------------------------

function NS.SetManualAuthority(record)
    if type(record) ~= "table"
        or type(NS.ValidateRouteIdentity) ~= "function"
        or not NS.ValidateRouteIdentity(record.identity)
    then
        return false
    end
    state.routing.manualAuthority = record
    if type(NS.SetActiveRouteSource) == "function" then
        NS.SetActiveRouteSource("manual")
    end
    NS.PersistManualAuthority()
    return true
end

function NS.CommitManualAuthority(record)
    return NS.SetManualAuthority(record)
end

function NS.GetManualAuthority()
    return state.routing.manualAuthority
end

function NS.GetActiveManualDestination()
    return state.routing.manualAuthority
end

function NS.ClearManualAuthority(clearReason)
    local current = state.routing.manualAuthority
    if current and type(current.backend) == "string" then
        local backend = nil
        if current.backend == "zygor" then
            backend = NS.RoutingBackend_Zygor
        elseif current.backend == "mapzeroth" then
            backend = NS.RoutingBackend_Mapzeroth
        elseif current.backend == "farstrider" then
            backend = NS.RoutingBackend_Farstrider
        elseif current.backend == "direct" then
            backend = NS.RoutingBackend_Direct
        end
        if backend and type(backend.Clear) == "function" then
            SafeCall(backend.Clear, current, clearReason or "manual_clear")
        end
    end
    state.routing.manualAuthority = nil
    NS.PersistManualAuthority()
end

-- ------------------------------------------------------------
-- Persistence
-- ------------------------------------------------------------
--
-- Persist exactly the fields we need to restore the route through the
-- current selected backend. Backend-internal scratch (legs, currentLeg)
-- is NOT persisted — the backend re-plans on restore.

local PERSISTED_FIELDS = {
    "mapID", "x", "y", "title", "sig",
    "meta", "backend", "createdAt",
    "identity", "sourceAddon", "searchKind",
    "manualQuestID", "mapPinInfo",
    "queueID", "queueKind", "queueSourceType",
    "queueItemIndex", "queueIsTransient",
}

local function CopyForPersistence(record)
    if type(record) ~= "table" then return nil end
    if IsTransientManualAuthorityRecord(record) then return nil end
    if type(NS.ValidateRouteIdentity) == "function" and not NS.ValidateRouteIdentity(record.identity) then
        return nil
    end
    if type(record.meta) ~= "table" or type(NS.ValidateRouteMeta) ~= "function" or not NS.ValidateRouteMeta(record.meta) then
        record.meta = NS.BuildRouteMeta(record.identity, {
            sourceAddon = record.sourceAddon,
            searchKind = record.searchKind,
            manualQuestID = record.manualQuestID,
            mapPinInfo = record.mapPinInfo,
            queueSourceType = record.queueSourceType,
        })
    end
    local out = {}
    for _, k in ipairs(PERSISTED_FIELDS) do
        out[k] = record[k]
    end
    return out
end

function NS.PersistManualAuthority()
    local db = NS.GetDB()
    if not db then return end
    local record = state.routing.manualAuthority
    db.manualAuthority = CopyForPersistence(record)
end

-- ------------------------------------------------------------
-- Restore on boot
-- ------------------------------------------------------------
--
-- Reads db.manualAuthority and replans through the *currently selected*
-- backend. The persisted .backend field is logged but not honored —
-- this avoids hidden backend stickiness across config changes.

function NS.RestoreManualAuthority()
    local db = NS.GetDB()
    if not db or db.resumeManualRoute == false then return false end
    local record = db.manualAuthority
    if type(record) ~= "table" then return false end
    if IsTransientManualAuthorityRecord(record) then
        db.manualAuthority = nil
        return false
    end
    if type(record.mapID) ~= "number"
        or type(record.x) ~= "number"
        or type(record.y) ~= "number"
    then
        db.manualAuthority = nil
        return false
    end
    if type(NS.ValidateRouteIdentity) ~= "function" or not NS.ValidateRouteIdentity(record.identity) then
        db.manualAuthority = nil
        return false
    end
    local meta = type(NS.ValidateRouteMeta) == "function" and NS.ValidateRouteMeta(record.meta) and record.meta or nil
    if type(meta) ~= "table" then
        meta = NS.BuildRouteMeta(record.identity, {
            sourceAddon = record.sourceAddon,
            searchKind = record.searchKind,
            manualQuestID = record.manualQuestID,
            mapPinInfo = record.mapPinInfo,
            queueSourceType = record.queueSourceType,
        })
    end
    if type(meta) ~= "table" then
        db.manualAuthority = nil
        return false
    end

    -- Re-route via the currently selected backend. opts.authority="manual"
    -- causes routing_core to build a fresh manualAuthority record and call
    -- backend.PlanRoute(...) to populate legs/specialAction.
    if type(NS.RouteViaBackend) ~= "function" then return false end
    return NS.RouteViaBackend(record.mapID, record.x, record.y, record.title, meta, {
        authority = "manual",
    })
end

-- ------------------------------------------------------------
-- Adoption helpers (used by carrier_tomtom for external waypoints)
-- ------------------------------------------------------------

function NS.CreateRouteMetaForExternalWaypoint(uid, mapID, x, y, title)
    local sourceAddon = nil
    if type(uid) == "table" then
        sourceAddon = NormalizeSourceAddonCandidate(uid.awpSourceAddon or uid.sourceAddon or uid.source or uid.from)
    end
    local sig = type(mapID) == "number" and type(x) == "number" and type(y) == "number"
        and Signature and Signature(mapID, x, y)
        or nil
    local identity = NS.BuildExternalTomTomIdentity(uid, mapID, x, y, {
        sig = sig,
        externalSig = sig,
        sourceAddon = sourceAddon,
    })
    return NS.BuildRouteMeta(identity, {
        sourceAddon = sourceAddon,
    })
end

function NS.AdoptExternalWaypoint(mapID, x, y, title, meta)
    if type(NS.RouteViaBackend) ~= "function" then return false end
    return NS.RouteViaBackend(mapID, x, y, title, meta, { authority = "manual" })
end

function NS.RequestManualRoute(mapID, x, y, title, meta, opts)
    if type(NS.RouteViaBackend) ~= "function" then
        return false
    end
    opts = type(opts) == "table" and opts or {}
    opts.authority = "manual"
    return NS.RouteViaBackend(mapID, x, y, title, meta, opts)
end

-- ------------------------------------------------------------
-- Explicit remove coordinator
-- ------------------------------------------------------------

local function ResolveExternalSignatureForRecord(record)
    local identity = type(record) == "table" and type(record.identity) == "table" and record.identity or nil
    if type(identity) ~= "table" then
        return nil
    end
    return TrimString(identity.externalSig) or TrimString(identity.queueSig) or TrimString(identity.sig)
end

local function ResolveQueuedFollowup(record)
    if type(NS.ResolveManualQueueFollowup) == "function" then
        return NS.ResolveManualQueueFollowup(record)
    end
    return nil
end

local function ClearBlizzardUserWaypointRecord(record)
    local identity = type(record) == "table" and type(record.identity) == "table" and record.identity or nil
    if type(identity) ~= "table" or identity.kind ~= "blizzard_user_waypoint" then
        return false
    end
    if type(C_SuperTrack) == "table"
        and type(C_SuperTrack.IsSuperTrackingUserWaypoint) == "function"
        and type(C_SuperTrack.SetSuperTrackedUserWaypoint) == "function"
        and C_SuperTrack.IsSuperTrackingUserWaypoint()
    then
        if type(NS.WithInternalSuperTrackMutation) == "function" then
            NS.WithInternalSuperTrackMutation(C_SuperTrack.SetSuperTrackedUserWaypoint, false)
        else
            SafeCall(C_SuperTrack.SetSuperTrackedUserWaypoint, false)
        end
    end
    if type(C_Map) == "table" and type(C_Map.ClearUserWaypoint) == "function" then
        if type(NS.WithInternalUserWaypointMutation) == "function" then
            NS.WithInternalUserWaypointMutation(C_Map.ClearUserWaypoint)
        else
            local takeoverState = state.bridgeTakeover
            local clearUserWaypoint = type(takeoverState) == "table"
                and type(takeoverState.originalClearUserWaypoint) == "function"
                and takeoverState.originalClearUserWaypoint
                or C_Map.ClearUserWaypoint
            SafeCall(clearUserWaypoint)
        end
    end
    return true
end

local function ClearBlizzardVignetteRecord(record)
    local identity = type(record) == "table" and type(record.identity) == "table" and record.identity or nil
    if type(identity) ~= "table" or identity.kind ~= "vignette" then
        return false
    end
    local guid = TrimString(identity.guid)
    if guid and type(NS.ClearSuperTrackedVignetteIfCurrent) == "function" then
        NS.ClearSuperTrackedVignetteIfCurrent(guid)
    end
    return true
end

local function ClearQuestRecord(record, clearReason)
    local identity = type(record) == "table" and type(record.identity) == "table" and record.identity or nil
    if type(identity) ~= "table" or identity.kind ~= "quest" then
        return false
    end
    local questID = NormalizeManualQuestIDCandidate(identity.questID or record.manualQuestID)
    if not questID then
        return false
    end
    if clearReason ~= "explicit" and clearReason ~= "arrival" then
        return true
    end
    local source = TrimString(identity.questSource)
    if source == "supertrack" and type(NS.ClearSuperTrackedQuestIfCurrent) == "function" then
        NS.ClearSuperTrackedQuestIfCurrent(questID)
    elseif source == "quest_offer" and type(NS.ClearSuperTrackedQuestOfferIfCurrent) == "function" then
        NS.ClearSuperTrackedQuestOfferIfCurrent(questID)
    end
    return true
end

local function ClearMapPinRecord(record)
    local identity = type(record) == "table" and type(record.identity) == "table" and record.identity or nil
    if type(identity) ~= "table" or identity.kind ~= "map_pin" then
        return false
    end
    local mapPinInfo = type(record.mapPinInfo) == "table" and record.mapPinInfo or nil
    local mapPinKind = TrimString(identity.mapPinKind or (mapPinInfo and mapPinInfo.kind))
    local mapPinID = NormalizePositiveNumber(identity.mapPinID or (mapPinInfo and mapPinInfo.mapPinID))
    if mapPinKind == "area_poi" and mapPinID and type(NS.ClearSuperTrackedAreaPoiIfCurrent) == "function" then
        NS.ClearSuperTrackedAreaPoiIfCurrent(mapPinID)
        return true
    end
    if mapPinKind == "taxi_node" and mapPinID and type(NS.ClearSuperTrackedTaxiNodeIfCurrent) == "function" then
        NS.ClearSuperTrackedTaxiNodeIfCurrent(mapPinID)
        return true
    end
    if mapPinKind == "dig_site" and mapPinID and type(NS.ClearSuperTrackedDigSiteIfCurrent) == "function" then
        NS.ClearSuperTrackedDigSiteIfCurrent(mapPinID)
        return true
    end
    if mapPinKind == "housing_plot" and mapPinID and type(NS.ClearSuperTrackedHousingPlotIfCurrent) == "function" then
        NS.ClearSuperTrackedHousingPlotIfCurrent(mapPinID)
        return true
    end
    return false
end

local function ClearGossipRecord(record)
    local identity = type(record) == "table" and type(record.identity) == "table" and record.identity or nil
    if type(identity) ~= "table" or identity.kind ~= "gossip_poi" then
        return false
    end
    if type(NS.ClearGossipPoiByIdentity) == "function" then
        return NS.ClearGossipPoiByIdentity(identity)
    end
    return false
end

local function ClearZygorPoiRecord(record)
    local identity = type(record) == "table" and type(record.identity) == "table" and record.identity or nil
    if type(identity) ~= "table" or identity.kind ~= "zygor_poi" then
        return false
    end
    if type(NS.ClearZygorPoiByIdentity) == "function" then
        return NS.ClearZygorPoiByIdentity(identity)
    end
    return false
end

local CLEAR_HANDLERS = {
    quest = ClearQuestRecord,
    map_pin = ClearMapPinRecord,
    vignette = ClearBlizzardVignetteRecord,
    gossip_poi = ClearGossipRecord,
    zygor_poi = ClearZygorPoiRecord,
    blizzard_user_waypoint = ClearBlizzardUserWaypointRecord,
}

local function RunSourceClearHandlers(record, clearReason)
    local identity = type(record) == "table" and type(record.identity) == "table" and record.identity or nil
    local kind = type(identity) == "table" and TrimString(identity.kind) or nil
    local handler = kind and CLEAR_HANDLERS[kind] or nil
    if type(handler) == "function" then
        return handler(record, clearReason)
    end
    return false
end

local function ResetManualArrivalState()
    state.routing.manualArrival = nil
end

local function ClearRoutePresentationState()
    if state.routing.carrierState and type(NS.ClearCarrierWaypoint) == "function" then
        NS.ClearCarrierWaypoint()
    else
        state.routing.carrierState = nil
        state.routing.lastPushedCarrierUID = nil
    end
    if state.routing.specialActionState and type(NS.DisarmSpecialActionButton) == "function" then
        NS.DisarmSpecialActionButton()
    end
    state.routing.specialActionState = nil
    state.routing.presentationState = nil
end

local function ShouldResolveQueueFollowup(opts)
    if type(opts) ~= "table" then
        return true
    end
    if opts.queueFollowup == false or opts.preserveManualQueue == true then
        return false
    end
    return true
end

local function ClearManualAuthorityWithFollowup(clearReason, opts)
    local reason = clearReason or "manual_clear"
    local cancelledPending = type(NS.CancelPendingManualRoute) == "function"
        and NS.CancelPendingManualRoute(reason)
        or false
    local record = state.routing.manualAuthority
    if type(record) ~= "table" then
        if cancelledPending and type(NS.RecomputeCarrier) == "function" then
            NS.RecomputeCarrier()
        end
        return cancelledPending
    end

    local nextQueuedRoute = ShouldResolveQueueFollowup(opts) and ResolveQueuedFollowup(record) or nil

    RunSourceClearHandlers(record, reason)

    local externalSig = ResolveExternalSignatureForRecord(record)
    if externalSig and type(NS.RemoveExternalTomTomWaypointsBySig) == "function" then
        NS.RemoveExternalTomTomWaypointsBySig(externalSig)
    end

    ResetManualArrivalState()
    NS.ClearManualAuthority(reason)
    ClearRoutePresentationState()

    if type(nextQueuedRoute) == "table" and type(NS.RouteViaBackend) == "function" then
        return NS.RouteViaBackend(
            nextQueuedRoute.mapID,
            nextQueuedRoute.x,
            nextQueuedRoute.y,
            nextQueuedRoute.title,
            nextQueuedRoute.meta,
            {
                authority = "manual",
                queueContext = nextQueuedRoute.queueContext,
                queueTransaction = nextQueuedRoute.queueTransaction,
                strictRouteSuccess = true,
            }
        )
    end

    if type(NS.RecomputeCarrier) == "function" then
        NS.RecomputeCarrier()
    end
    return true
end

function NS.ClearActiveManualDestination(visibilityOrReason, clearReason)
    local reason = clearReason
    if type(reason) ~= "string" then
        if visibilityOrReason ~= "visible" and visibilityOrReason ~= "hidden" and visibilityOrReason ~= "absent" then
            reason = visibilityOrReason
        end
    end
    return ClearManualAuthorityWithFollowup(type(reason) == "string" and reason or "system")
end

function NS.ClearManualRoute(clearReason, opts)
    return ClearManualAuthorityWithFollowup(type(clearReason) == "string" and clearReason or "system", opts)
end

local function IsAutoClearableManualAuthority(record)
    if type(record) ~= "table" then
        return false
    end

    local identity = type(record.identity) == "table" and record.identity or nil
    if type(identity) == "table" then
        if identity.kind == "quest" then
            return type(NS.IsSuperTrackedQuestAutoClearEnabled) == "function"
                and NS.IsSuperTrackedQuestAutoClearEnabled()
                or false
        end
        if identity.kind == "external_tomtom" and type(record.queueID) == "string" then
            return type(NS.IsActiveManualQueueItem) == "function" and NS.IsActiveManualQueueItem(record) or false
        end
    end

    if type(record.searchKind) == "string" and record.searchKind ~= "" then
        return false
    end

    return true
end

local function GetManualAuthorityArrivalTarget(record)
    if type(record) ~= "table" then
        return nil
    end
    if type(NS.GetManualQueueArrivalTarget) == "function" then
        local queueTarget = NS.GetManualQueueArrivalTarget(record)
        if type(queueTarget) == "table"
            and type(queueTarget.mapID) == "number"
            and type(queueTarget.x) == "number"
            and type(queueTarget.y) == "number"
        then
            return queueTarget
        end
    end
    local leg = type(record.currentLeg) == "table" and record.currentLeg or nil
    if type(leg) == "table"
        and type(leg.mapID) == "number"
        and type(leg.x) == "number"
        and type(leg.y) == "number"
    then
        return leg
    end
    if type(record.mapID) == "number" and type(record.x) == "number" and type(record.y) == "number" then
        return record
    end
    return nil
end

local function GetManualAuthorityArrivalKey(record)
    if type(record) ~= "table" then
        return nil
    end
    local target = GetManualAuthorityArrivalTarget(record)
    local targetSig = target and target.sig
    if type(targetSig) ~= "string"
        and type(Signature) == "function"
        and type(target) == "table"
        and type(target.mapID) == "number"
        and type(target.x) == "number"
        and type(target.y) == "number"
    then
        targetSig = Signature(target.mapID, target.x, target.y)
    end
    if record.queueKind == "destination_queue" and type(record.queueID) == "string" then
        return table.concat({
            tostring(record.queueID),
            tostring(record.queueItemIndex or ""),
            tostring(targetSig or ""),
        }, "\031", 1, 3)
    end
    local identity = type(record.identity) == "table" and record.identity or nil
    if type(identity) == "table" then
        return table.concat({
            tostring(identity.kind or ""),
            tostring(identity.queueIndex or ""),
            tostring(identity.queueSig or identity.externalSig or identity.sig or ""),
            tostring(record.currentLegIndex or ""),
            tostring(targetSig or ""),
        }, "\031", 1, 5)
    end
    return table.concat({
        tostring(record.sig or ""),
        tostring(record.currentLegIndex or ""),
        tostring(targetSig or ""),
    }, "\031", 1, 3)
end

local function IsAreaPoiManualAuthority(record)
    local identity = type(record) == "table" and type(record.identity) == "table" and record.identity or nil
    local mapPinInfo = type(record) == "table" and type(record.mapPinInfo) == "table" and record.mapPinInfo or nil
    if type(identity) == "table"
        and identity.kind == "map_pin"
        and (identity.mapPinKind == "area_poi" or mapPinInfo and mapPinInfo.kind == "area_poi")
    then
        return true
    end
    return type(mapPinInfo) == "table" and mapPinInfo.kind == "area_poi" or false
end

local function IsManualAuthorityMapTransitionArrival(record, target, arrival)
    if type(arrival) ~= "table" or arrival.seenTarget ~= true then
        return false
    end
    if not IsAreaPoiManualAuthority(record) then
        return false
    end
    if type(NS.GetPlayerMapID) ~= "function" or type(target) ~= "table" or type(target.mapID) ~= "number" then
        return false
    end
    local playerMapID = NS.GetPlayerMapID()
    return type(playerMapID) == "number" and playerMapID ~= target.mapID
end

function NS.CheckManualAuthorityArrival()
    local record = state.routing.manualAuthority
    if type(record) ~= "table" then
        ResetManualArrivalState()
        return false
    end

    if not NS.IsManualWaypointAutoClearEnabled or not NS.IsManualWaypointAutoClearEnabled() then
        ResetManualArrivalState()
        return false
    end

    local clearDistance = type(NS.GetManualWaypointClearDistance) == "function" and NS.GetManualWaypointClearDistance() or 0
    if type(clearDistance) ~= "number" or clearDistance <= 0 then
        ResetManualArrivalState()
        return false
    end

    if not IsAutoClearableManualAuthority(record) then
        ResetManualArrivalState()
        return false
    end

    if type(NS.GetPlayerWaypointDistance) ~= "function" then
        return false
    end

    local target = GetManualAuthorityArrivalTarget(record)
    local key = GetManualAuthorityArrivalKey(record)
    local arrival = state.routing.manualArrival
    local distance = target and NS.GetPlayerWaypointDistance(target.mapID, target.x, target.y) or nil
    if type(distance) ~= "number" then
        if type(arrival) == "table" and arrival.key == key
            and IsManualAuthorityMapTransitionArrival(record, target, arrival)
        then
            return ClearManualAuthorityWithFollowup("arrival_map_transition")
        end
        return false
    end

    if type(arrival) ~= "table" or arrival.key ~= key then
        arrival = {
            key = key,
            armed = distance > clearDistance,
            seenTarget = true,
            mapID = target and target.mapID or nil,
        }
        state.routing.manualArrival = arrival
        return false
    end

    arrival.seenTarget = true
    arrival.mapID = target and target.mapID or nil

    if not arrival.armed then
        if distance > clearDistance then
            arrival.armed = true
        end
        return false
    end

    if distance > clearDistance then
        return false
    end

    return ClearManualAuthorityWithFollowup("arrival")
end

function NS.HandleExplicitManualAuthorityRemove()
    return ClearManualAuthorityWithFollowup("explicit")
end
