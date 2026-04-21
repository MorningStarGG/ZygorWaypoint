local NS = _G.ZygorWaypointNS
local C = NS.Constants
local state = NS.State
local M = NS.Internal.Bridge

local bridge = M.bridge
local signature = NS.Signature
local GetTomTom = NS.GetTomTom
local GetZygorPointer = NS.GetZygorPointer
local GetArrowFrame = NS.GetArrowFrame
local ReadWaypointCoords = NS.ReadWaypointCoords
local GetZygorDisplayState = NS.GetZygorDisplayState
local SyncZygorDisplayState = NS.SyncZygorDisplayState
local SyncWorldOverlay = NS.SyncWorldOverlay
local ResolveGuideContentSnapshot = NS.ResolveGuideContentSnapshot
local NormalizeWaypointTitle = NS.NormalizeWaypointTitle
local GetWaypointTravelDescriptorFields = NS.GetWaypointTravelDescriptorFields

local IsArrowWaypointSource = M.IsArrowWaypointSource
local IsFallbackSource = M.IsFallbackSource
local HasBridgeMirrorState = M.HasBridgeMirrorState
local RemoveBridgeWaypoint = M.RemoveBridgeWaypoint
local ClearBridgeMirror = M.ClearBridgeMirror
local GetBridgeMode = M.GetBridgeMode
local TransitionBridgeLifecycleMode = M.TransitionBridgeLifecycleMode
local ResolveCanonicalTarget = M.ResolveCanonicalTarget
local ShouldExtractFallbackTarget = M.ShouldExtractFallbackTarget
local IsDisplayTextVisible = M.IsDisplayTextVisible
local SyncGuideVisibilityState = M.SyncGuideVisibilityState
local HandleLifecycleState = M.HandleLifecycleState
local SyncTomTomArrowVisualSuppression = M.SyncTomTomArrowVisualSuppression
local GetActiveManualDestination = M.GetActiveManualDestination

-- ============================================================
-- Module-level caches
-- ============================================================

-- Reusable context table for ResolveGuideContentSnapshot to avoid per-tick allocation.
local guideSnapshotContext = {}
local routeSnapshotContext = { kind = "route" }

-- Single-entry cache: skips CloneContentSnapshot when the base snapshot
-- identity, target kind, and travel type are unchanged from the last finalize.
local lastFinalizedBase = nil
local lastFinalizedKind = nil
local lastFinalizedTravelType = nil
local lastFinalizedSourceAddon = nil
local lastFinalizedSearchKind = nil
local lastFinalizedResult = nil

-- Single-entry cache for non-guide route fallback content snapshots. This avoids
-- rebuilding the same route-leg presentation table every heartbeat when guide
-- route presentation is intentionally bypassed.
local lastRouteFallbackLiveTravelType = nil
local lastRouteFallbackGoalMapID = nil
local lastRouteFallbackLegKind = nil
local lastRouteFallbackRouteTravelType = nil
local lastRouteFallbackSourceAddon = nil
local lastRouteFallbackResult = nil

-- ============================================================
-- Arrow / UID helpers
-- ============================================================

local function GetWaypointSig(mapID, x, y)
    if type(mapID) ~= "number" or type(x) ~= "number" or type(y) ~= "number" then
        return
    end

    return signature(mapID, x, y)
end

local function NormalizeSourceAddon(sourceAddon)
    if sourceAddon == "silverdragon" or sourceAddon == "rarescanner" then
        return sourceAddon
    end
end

local function ResolveWaypointSourceAddon(waypoint)
    if type(waypoint) ~= "table" then
        return nil
    end

    return NormalizeSourceAddon(waypoint.zwpSourceAddon)
end

local function ResolveWaypointSearchKind(waypoint)
    if type(waypoint) ~= "table" then
        return nil
    end

    local searchKind = waypoint.zwpSearchKind
    if type(searchKind) == "string" and searchKind ~= "" then
        return searchKind
    end

    return nil
end

local function ResolveActiveSearchKind(targetKind, activeManualDestination)
    if targetKind ~= "manual" then
        return nil
    end

    local destination = activeManualDestination
    if type(destination) ~= "table" then
        destination = GetActiveManualDestination()
    end

    local searchKind = ResolveWaypointSearchKind(destination)
    if searchKind then
        return searchKind
    end

    -- Fallback: check DB for persisted search kind (lost across /reload)
    if type(destination) == "table" then
        local m, x, y = ReadWaypointCoords(destination)
        local sig = GetWaypointSig(m, x, y)
        if type(sig) == "string" then
            local db = NS.GetDB()
            local saved = type(db._zwpManual) == "table" and db._zwpManual or nil
            if saved and saved.sig == sig and type(saved.searchKind) == "string" then
                destination.zwpSearchKind = saved.searchKind
                return saved.searchKind
            end
        end
    end

    return nil
end

local function ResolveBorrowedManualDestinationUID(mapID, x, y, kind)
    if kind ~= "manual" then
        return
    end

    local destination = GetActiveManualDestination()
    if type(destination) ~= "table" or destination.zwpExternalTomTom ~= true then
        return
    end

    local destinationMapID, destinationX, destinationY = ReadWaypointCoords(destination)
    local targetSig = GetWaypointSig(mapID, x, y)
    local destinationSig = destination.zwpExternalSig or GetWaypointSig(destinationMapID, destinationX, destinationY)
    if type(targetSig) ~= "string" or type(destinationSig) ~= "string" or targetSig ~= destinationSig then
        return
    end

    return NS.GetExternalTomTomWaypointBySig(destinationSig)
end

local function ApplyCrazyArrowUID(tomtom, uid, title, borrowed)
    if not (tomtom and type(tomtom.SetCrazyArrow) == "function" and uid) then
        return
    end

    local apply = function()
        tomtom:SetCrazyArrow(uid, 15, title)
    end

    if borrowed then
        NS.WithTomTomArrowRoutingSyncSuppressed(apply)
        return
    end

    apply()
end

local function PushTomTom(mapID, x, y, title, source, kind, positionChanged, contentSnapshot)
    local tomtom = GetTomTom()
    if not tomtom or not tomtom.AddWaypoint or not tomtom.SetCrazyArrow then
        NS.Msg("TomTom not found (need AddWaypoint + SetCrazyArrow).")
        return
    end

    if type(mapID) ~= "number" then
        local playerMapID = C_Map.GetBestMapForUnit and C_Map.GetBestMapForUnit("player")
        if playerMapID then
            mapID = playerMapID
        end
    end
    if not (mapID and x and y) then
        return
    end

    local borrowedUID = ResolveBorrowedManualDestinationUID(mapID, x, y, kind)
    if bridge.lastUID and tomtom.RemoveWaypoint then
        RemoveBridgeWaypoint(not positionChanged)
    end

    local effectiveTitle = title or " "
    local uid
    local borrowed = borrowedUID ~= nil
    local addX = type(NS.StabilizeCoordForUserWaypoint) == "function" and NS.StabilizeCoordForUserWaypoint(x) or x
    local addY = type(NS.StabilizeCoordForUserWaypoint) == "function" and NS.StabilizeCoordForUserWaypoint(y) or y
    if borrowed then
        uid = borrowedUID
    else
        -- Bridge-managed TomTom waypoints are an internal transport for the arrow
        -- and downstream integrations. Keep them out of HBD pin registries so the
        -- user's destination pin can remain intact while the carrier follows live
        -- route legs.
        uid = tomtom:AddWaypoint(mapID, addX, addY, {
            title = effectiveTitle,
            fromZWP = true,
            cleardistance = 0,
            crazy = false,
            minimap = false,
            world = false,
            persistent = false,
            silent = true,
        })
    end
    if not uid then
        return
    end

    bridge.lastUID = uid
    bridge.lastUIDOwned = not borrowed
    bridge.lastTitle = effectiveTitle
    bridge.lastContentSig = type(contentSnapshot) == "table" and contentSnapshot.contentSig or nil
    ApplyCrazyArrowUID(tomtom, uid, effectiveTitle, borrowed)
    bridge.lastAppliedSource = source
    bridge.lastAppliedKind = kind
    bridge.lastAppliedMapID = mapID
    bridge.lastAppliedX = x
    bridge.lastAppliedY = y
    bridge.lastAppliedAt = GetTime and GetTime() or 0
    bridge.lastAppliedGuideRoutePresentation =
        type(contentSnapshot) == "table" and contentSnapshot.guideRoutePresentation == true or false

    if IsArrowWaypointSource(source) then
        bridge.lastArrowSeenAt = bridge.lastAppliedAt
        bridge.lastArrowSeenMap = mapID
    end

    local db = NS.GetDB()
    if db.arrowAlignment ~= false then
        NS.AlignTomTomToZygor()
        NS.HookUnifiedArrowDrag()
    end

    NS.Log("SetCrazyArrow", source, mapID, x, y, effectiveTitle)
    SyncTomTomArrowVisualSuppression()
    SyncWorldOverlay(uid, mapID, x, y, effectiveTitle, source, kind, contentSnapshot)
    return uid
end

-- ============================================================
-- Destination fallback suppression
-- ============================================================

local function LogSuppressOnce(reason, source, title, mapID)
    if not NS.Runtime.debug then return end

    local now = GetTime and GetTime() or 0
    local sig = string.format("%s|%s|%s|%s", tostring(reason), tostring(source), tostring(title), tostring(mapID))
    if sig ~= bridge.lastSuppressLogSig or (now - bridge.lastSuppressLogAt) > 1.0 then
        local age = now - bridge.lastAppliedAt
        NS.Log(
            "Suppress Destination fallback",
            reason,
            "age",
            string.format("%.2f", age),
            "lastsrc",
            tostring(bridge.lastAppliedSource),
            "map",
            tostring(mapID),
            "title",
            tostring(title)
        )
        bridge.lastSuppressLogAt = now
        bridge.lastSuppressLogSig = sig
    end
end

local function GetDestinationFallbackSuppressionReason(source, title, mapID, allowDestinationFallback)
    if not IsFallbackSource(source) then
        return
    end
    if allowDestinationFallback then
        return
    end

    local now = GetTime and GetTime() or 0
    local ageSinceArrowSeen = now - bridge.lastArrowSeenAt
    local ageSinceApplied = now - bridge.lastAppliedAt

    if title == "ZygorRoute" and bridge.lastAppliedSource and not IsFallbackSource(bridge.lastAppliedSource) then
        return "zygorroute"
    end

    if bridge.lastArrowSeenMap and mapID and mapID ~= bridge.lastArrowSeenMap and ageSinceArrowSeen <= C.DEST_FALLBACK_SUPPRESS_MAP_MISMATCH_SECONDS then
        return "map-mismatch"
    end

    if IsArrowWaypointSource(bridge.lastAppliedSource) and ageSinceApplied <= C.DEST_FALLBACK_SUPPRESS_RECENT_ARROW_SECONDS then
        return "recent-arrow"
    end
end

local function ShouldSuppressDestinationFallback(source, title, mapID, allowDestinationFallback)
    local reason = GetDestinationFallbackSuppressionReason(source, title, mapID, allowDestinationFallback)
    if not reason then
        return false
    end

    LogSuppressOnce(reason, source, title, mapID)
    return true
end

-- ============================================================
-- Tick debounce
-- ============================================================

local function ClearPendingFallbackSwitch()
    local pendingFallbackSwitch = bridge.pendingFallbackSwitch
    if type(pendingFallbackSwitch) ~= "table" then
        pendingFallbackSwitch = { sig = nil, count = 0 }
        bridge.pendingFallbackSwitch = pendingFallbackSwitch
    end

    pendingFallbackSwitch.sig = nil
    pendingFallbackSwitch.count = 0
end

local function ShouldDebounceFallbackSwitch(sig, source)
    if not IsFallbackSource(source) then
        ClearPendingFallbackSwitch()
        return false
    end

    if not IsArrowWaypointSource(bridge.lastAppliedSource) then
        ClearPendingFallbackSwitch()
        return false
    end

    local now = GetTime and GetTime() or 0
    if now - bridge.lastAppliedAt > C.FALLBACK_DEBOUNCE_SECONDS then
        ClearPendingFallbackSwitch()
        return false
    end

    local pendingFallbackSwitch = bridge.pendingFallbackSwitch
    if type(pendingFallbackSwitch) ~= "table" then
        pendingFallbackSwitch = { sig = nil, count = 0 }
        bridge.pendingFallbackSwitch = pendingFallbackSwitch
    end

    if pendingFallbackSwitch.sig ~= sig then
        pendingFallbackSwitch.sig = sig
        pendingFallbackSwitch.count = 1
        NS.Log("Debounce hold", source, sig, "1/" .. tostring(C.FALLBACK_CONFIRM_COUNT))
        return true
    end

    pendingFallbackSwitch.count = pendingFallbackSwitch.count + 1
    if pendingFallbackSwitch.count < C.FALLBACK_CONFIRM_COUNT then
        NS.Log(
            "Debounce hold",
            source,
            sig,
            tostring(pendingFallbackSwitch.count) .. "/" .. tostring(C.FALLBACK_CONFIRM_COUNT)
        )
        return true
    end

    NS.Log(
        "Debounce release",
        source,
        sig,
        tostring(pendingFallbackSwitch.count) .. "/" .. tostring(C.FALLBACK_CONFIRM_COUNT)
    )
    ClearPendingFallbackSwitch()
    return false
end

-- ============================================================
-- Manual route fallback hold
-- ============================================================

local function ClearPendingManualRouteFallbackHold()
    bridge.manualRouteHoldPendingSig = nil
    bridge.manualRouteHoldStartedAt = 0
end

local function ClearManualRouteFallbackHold()
    bridge.manualRouteHoldDestinationSig = nil
    ClearPendingManualRouteFallbackHold()
end

local function GetRoutedManualDestinationSignature()
    local destination = GetActiveManualDestination()
    if type(destination) ~= "table" or destination.type ~= "manual" then
        return
    end

    if destination.findpath ~= true
        and destination.pathfind ~= true
        and destination.zwpExternalTomTom ~= true
    then
        return
    end

    local mapID, x, y = ReadWaypointCoords(destination)
    return GetWaypointSig(mapID, x, y)
end

local function SyncManualRouteFallbackDestination(destinationSig)
    if type(destinationSig) ~= "string" then
        ClearManualRouteFallbackHold()
        return
    end

    if type(bridge.manualRouteHoldDestinationSig) == "string"
        and bridge.manualRouteHoldDestinationSig ~= destinationSig
    then
        ClearManualRouteFallbackHold()
    end
end

local function ObserveManualRouteCarrier(destinationSig, sig, kind)
    if type(destinationSig) ~= "string" or type(sig) ~= "string" then
        return
    end

    if kind == "route" and sig ~= destinationSig then
        bridge.manualRouteHoldDestinationSig = destinationSig
        ClearPendingManualRouteFallbackHold()
    end
end

local function ShouldHoldManualRouteFallbackSwitch(destinationSig, sig, source, kind)
    if type(destinationSig) ~= "string" or bridge.manualRouteHoldDestinationSig ~= destinationSig then
        ClearPendingManualRouteFallbackHold()
        return false
    end

    if kind == "route" then
        ClearPendingManualRouteFallbackHold()
        return false
    end

    if bridge.lastAppliedKind ~= "route"
        or type(bridge.lastSig) ~= "string"
        or bridge.lastSig == destinationSig
    then
        ClearPendingManualRouteFallbackHold()
        return false
    end

    if type(sig) ~= "string" then
        return false
    end

    local now = GetTime and GetTime() or 0
    if bridge.manualRouteHoldPendingSig ~= sig then
        bridge.manualRouteHoldPendingSig = sig
        bridge.manualRouteHoldStartedAt = now
        NS.Log("Manual route fallback hold", tostring(source), tostring(sig))
        return true
    end

    local holdAge = now - (bridge.manualRouteHoldStartedAt or now)
    if holdAge < (C.ROUTE_RECALC_HOLD_SECONDS or 0.80) then
        return true
    end

    NS.Log("Manual route fallback release", tostring(source), tostring(sig), string.format("%.2f", holdAge))
    ClearPendingManualRouteFallbackHold()
    return false
end

-- ============================================================
-- Route leg resolution
-- ============================================================

local function NormalizeRouteDisplayTitle(title)
    local normalized = NormalizeWaypointTitle(title)
    if type(normalized) ~= "string" then
        return
    end

    normalized = normalized:gsub("%s+", " "):gsub("^%s+", ""):gsub("%s+$", "")
    if normalized == "" then
        return
    end

    return normalized
end

local function ResolveWaypointForSource(source, displayState)
    local snapshot = displayState and displayState.snapshot
    if type(snapshot) == "table" and snapshot.source == source and type(snapshot.waypoint) == "table" then
        return snapshot.waypoint
    end

    local _, pointer, arrowFrame = GetArrowFrame()
    if not pointer then
        _, pointer = GetZygorPointer()
        arrowFrame = pointer and pointer.ArrowFrame or nil
    end
    if type(pointer) ~= "table" then
        return
    end

    if source == "pointer.ArrowFrame.waypoint" then
        return arrowFrame and arrowFrame.waypoint or nil
    end
    if source == "pointer.arrow.waypoint" then
        return pointer.arrow and pointer.arrow.waypoint or nil
    end
    if source == "pointer.DestinationWaypoint" then
        return pointer.DestinationWaypoint
    end
    if source == "pointer.waypoint" then
        return pointer.waypoint
    end
    if source == "pointer.current_waypoint" then
        return pointer.current_waypoint
    end
    if source == "pointer.waypoints[1]" then
        return type(pointer.waypoints) == "table" and pointer.waypoints[1] or nil
    end
end

local function CallRouteTitleMethod(target, methodName)
    if type(target) ~= "table" then
        return
    end

    local method = target[methodName]
    if type(method) ~= "function" then
        return
    end

    local ok, value = pcall(method, target)
    if ok then
        return value
    end
end

local function ResolveRouteSemanticTitle(waypoint)
    if type(waypoint) ~= "table" then
        return
    end

    return NormalizeRouteDisplayTitle(CallRouteTitleMethod(waypoint, "GetArrowTitle"))
        or NormalizeRouteDisplayTitle(waypoint.arrowtitle)
        or NormalizeRouteDisplayTitle(CallRouteTitleMethod(waypoint, "GetTitle"))
        or NormalizeRouteDisplayTitle(waypoint.title)
end

local function ResolveRouteLeg(source, displayState)
    local waypoint = ResolveWaypointForSource(source, displayState)
    local routeTitle = ResolveRouteSemanticTitle(waypoint)
    return waypoint, routeTitle
end

-- ============================================================
-- Content snapshot resolution
-- ============================================================

local function IsGuideRoutePresentationSnapshotAllowed(snapshot)
    if type(snapshot) ~= "table" then
        return false
    end

    if snapshot.routePresentationAllowed == false then
        return false
    end

    return true
end

local function ResolveGuideRoutePresentationSnapshot(
    title,
    canonicalSource,
    canonicalMapID,
    canonicalX,
    canonicalY,
    legKind,
    routeTravelType
)
    -- Manual destinations always have authority; guide semantics must not override them.
    local activeManualDestination = GetActiveManualDestination()
    if type(activeManualDestination) == "table" then
        return
    end

    if type(canonicalMapID) ~= "number" or type(canonicalX) ~= "number" or type(canonicalY) ~= "number" then
        return
    end

    -- Pass canonical goal coords to the resolver; rawArrowTitle stays as the live arrow title.
    -- Use canonical.source ("step.goal#N") for stable resolver debug output.
    routeSnapshotContext.rawArrowTitle = title
    routeSnapshotContext.mapID = canonicalMapID
    routeSnapshotContext.x = canonicalX
    routeSnapshotContext.y = canonicalY
    routeSnapshotContext.source = canonicalSource
    routeSnapshotContext.legKind = legKind
    routeSnapshotContext.routeTravelType = routeTravelType
    local snapshot = ResolveGuideContentSnapshot(routeSnapshotContext)
    if type(snapshot) ~= "table" then
        return
    end

    if not IsGuideRoutePresentationSnapshotAllowed(snapshot) then
        return
    end

    snapshot.routeGoalMapID = canonicalMapID
    snapshot.routeLegKind = legKind
    snapshot.routeTravelType = routeTravelType
    return snapshot
end

local function CloneContentSnapshot(snapshot)
    if type(snapshot) ~= "table" then
        return nil
    end

    local copy = {}
    for key, value in pairs(snapshot) do
        copy[key] = value
    end
    return copy
end

local function ResolveInstanceTravelIconOverride(liveTravelType, routeTravelType)
    if liveTravelType ~= "portal" then
        return liveTravelType
    end

    if routeTravelType == "dungeon" or routeTravelType == "raid" or routeTravelType == "delve" then
        return routeTravelType
    end

    return liveTravelType
end

local function ResolvePresentationIconHint(targetKind, snapshot, liveTravelType, liveTravelConfidence, searchKind)
    if targetKind == "manual" then
        return (type(searchKind) == "string" and searchKind or "manual"), nil
    end
    if targetKind == "corpse" then
        return "corpse", nil
    end

    local resolvedLiveTravelType = liveTravelConfidence == "high"
        and type(liveTravelType) == "string"
        and liveTravelType
        or nil
    local routeTravelType = type(snapshot) == "table"
        and type(snapshot.routeTravelType) == "string"
        and snapshot.routeTravelType
        or nil
    resolvedLiveTravelType = ResolveInstanceTravelIconOverride(resolvedLiveTravelType, routeTravelType)
    if type(resolvedLiveTravelType) == "string" then
        return resolvedLiveTravelType, nil
    end

    if type(snapshot) ~= "table" then
        return nil, nil
    end

    local semanticQuestID = type(snapshot.semanticQuestID) == "number" and snapshot.semanticQuestID > 0 and snapshot.semanticQuestID or nil
    if snapshot.semanticKind == "quest" and semanticQuestID then
        return "quest", semanticQuestID
    end

    local semanticTravelType = type(snapshot.semanticTravelType) == "string" and snapshot.semanticTravelType or nil
    if semanticTravelType then
        return semanticTravelType, nil
    end

    return "guide", nil
end

local function BuildFinalContentSig(snapshot)
    return table.concat({
        tostring(snapshot.contentSig or ""),
        tostring(snapshot.guideRoutePresentation == true),
        tostring(snapshot.iconHintKind or ""),
        tostring(snapshot.iconHintQuestID or ""),
        tostring(snapshot.sourceAddon or ""),
    }, "\031")
end

local function FinalizeContentSnapshot(
    baseSnapshot,
    targetKind,
    isGuideRoutePresentation,
    liveTravelType,
    liveTravelConfidence,
    sourceAddon,
    searchKind
)
    sourceAddon = NormalizeSourceAddon(sourceAddon)
    searchKind = targetKind == "manual" and type(searchKind) == "string" and searchKind or nil

    local snapshot = CloneContentSnapshot(baseSnapshot)
    if type(snapshot) ~= "table" then
        if type(sourceAddon) ~= "string" and searchKind == nil then
            return nil
        end
        snapshot = {}
    end

    snapshot.guideRoutePresentation = isGuideRoutePresentation == true or false
    snapshot.liveTravelType = liveTravelConfidence == "high"
        and type(liveTravelType) == "string"
        and liveTravelType
        or nil
    snapshot.sourceAddon = sourceAddon
    snapshot.iconHintKind, snapshot.iconHintQuestID = ResolvePresentationIconHint(
        targetKind,
        snapshot,
        liveTravelType,
        liveTravelConfidence,
        searchKind
    )
    snapshot.contentSig = BuildFinalContentSig(snapshot)
    return snapshot
end

local function BuildRouteContentSnapshot(
    liveTravelType,
    liveTravelConfidence,
    routeGoalMapID,
    routeLegKind,
    routeTravelType,
    sourceAddon
)
    sourceAddon = NormalizeSourceAddon(sourceAddon)
    local resolvedLiveTravelType = liveTravelConfidence == "high"
        and type(liveTravelType) == "string"
        and liveTravelType
        or nil
    local resolvedIconHintKind = ResolveInstanceTravelIconOverride(resolvedLiveTravelType, routeTravelType)
    if resolvedLiveTravelType == nil
        and type(routeLegKind) ~= "string"
        and type(routeTravelType) ~= "string"
        and type(routeGoalMapID) ~= "number"
        and type(sourceAddon) ~= "string"
    then
        return nil
    end

    if resolvedLiveTravelType == lastRouteFallbackLiveTravelType
        and routeGoalMapID == lastRouteFallbackGoalMapID
        and routeLegKind == lastRouteFallbackLegKind
        and routeTravelType == lastRouteFallbackRouteTravelType
        and sourceAddon == lastRouteFallbackSourceAddon
        and lastRouteFallbackResult
    then
        return lastRouteFallbackResult
    end

    local snapshot = {
        guideRoutePresentation = false,
        liveTravelType = resolvedLiveTravelType,
        iconHintKind = resolvedIconHintKind,
        iconHintQuestID = nil,
        routeGoalMapID = routeGoalMapID,
        routeLegKind = routeLegKind,
        routeTravelType = routeTravelType,
        sourceAddon = sourceAddon,
    }
    snapshot.contentSig = BuildFinalContentSig(snapshot)
    lastRouteFallbackLiveTravelType = resolvedLiveTravelType
    lastRouteFallbackGoalMapID = routeGoalMapID
    lastRouteFallbackLegKind = routeLegKind
    lastRouteFallbackRouteTravelType = routeTravelType
    lastRouteFallbackSourceAddon = sourceAddon
    lastRouteFallbackResult = snapshot
    return snapshot
end

-- ============================================================
-- Main tick
-- ============================================================

local function HandleNilExtraction(visibilityState, mode, displayState)
    if visibilityState == "visible" and NS.IsCurrentGuideStepWaypointSuppressed() then
        ClearBridgeMirror()
        SyncTomTomArrowVisualSuppression()
        return
    end

    if not IsDisplayTextVisible(displayState) or mode == "cinematic" or mode == "hidden-idle" then
        ClearPendingFallbackSwitch()
        if HasBridgeMirrorState() then
            ClearBridgeMirror()
        end
        SyncTomTomArrowVisualSuppression()
        return
    end
end

function NS.TickUpdate()
    local churn = state.churn
    if churn and churn.active then
        churn.tickUpdate = churn.tickUpdate + 1
    end
    if not (state.init and state.init.playerLoggedIn) then
        return
    end

    local visibilityState = SyncGuideVisibilityState()
    SyncZygorDisplayState()
    local displayState = GetZygorDisplayState()
    local mode = TransitionBridgeLifecycleMode(GetBridgeMode(visibilityState))
    if HandleLifecycleState(visibilityState, mode) then
        return
    end

    local pointerOnly = (mode == "hidden-override")
    local mapID, x, y, title, source, targetKind, fromDisplay
    local manualAuthorityActive = false

    mapID, x, y, title, source, targetKind, manualAuthorityActive = NS.ExtractActiveManualTargetFromZygor(pointerOnly)
    local activeManualDestination = manualAuthorityActive and GetActiveManualDestination() or nil
    local sourceAddon = ResolveWaypointSourceAddon(activeManualDestination)

    if not manualAuthorityActive then
        local fallbackM, fallbackX, fallbackY, fallbackTitle, fallbackSource, fallbackKind
        if ShouldExtractFallbackTarget(mode, displayState) then
            fallbackM, fallbackX, fallbackY, fallbackTitle, fallbackSource, fallbackKind = NS.ExtractWaypointFromZygor(pointerOnly)
            if fallbackM and ShouldSuppressDestinationFallback(fallbackSource, fallbackTitle, fallbackM, pointerOnly) then
                fallbackM, fallbackX, fallbackY, fallbackTitle, fallbackSource, fallbackKind = nil, nil, nil, nil, nil, nil
            end
        end

        mapID, x, y, title, source, targetKind, fromDisplay = ResolveCanonicalTarget(
            mode,
            displayState,
            fallbackM,
            fallbackX,
            fallbackY,
            fallbackTitle,
            fallbackSource,
            fallbackKind
        )
    end

    local activeManualRouteDestinationSig = manualAuthorityActive and GetRoutedManualDestinationSignature() or nil
    SyncManualRouteFallbackDestination(activeManualRouteDestinationSig)

    if not (mapID and x and y and title and source and targetKind) then
        if manualAuthorityActive then
            ClearPendingFallbackSwitch()
            SyncTomTomArrowVisualSuppression()
            return
        end
        HandleNilExtraction(visibilityState, mode, displayState)
        return
    end

    if manualAuthorityActive or fromDisplay then
        ClearPendingFallbackSwitch()
    end

    local routeWaypoint, routeTitle
    local liveTravelType, liveTravelConfidence
    local routeCanonicalSource, routeGoalMapID, routeGoalX, routeGoalY, routeLegKind, routeTravelType
    if targetKind == "route" then
        routeWaypoint, routeTitle = ResolveRouteLeg(source, displayState)
        if type(routeWaypoint) == "table" and type(NS.ResolveRouteLegSemantics) == "function" then
            local destinationWaypoint = ResolveWaypointForSource("pointer.DestinationWaypoint", displayState)
            routeCanonicalSource, routeGoalMapID, routeGoalX, routeGoalY, _, _, routeLegKind, routeTravelType =
                NS.ResolveRouteLegSemantics(nil, routeWaypoint, source, destinationWaypoint)
        end
        liveTravelType, liveTravelConfidence = GetWaypointTravelDescriptorFields(
            routeWaypoint,
            source,
            routeTitle or title,
            routeTravelType,
            routeLegKind,
            routeCanonicalSource
        )
    end

    local baseContentSnapshot
    if targetKind == "guide" and not manualAuthorityActive then
        guideSnapshotContext.rawArrowTitle = title
        guideSnapshotContext.mapID = mapID
        guideSnapshotContext.x = x
        guideSnapshotContext.y = y
        guideSnapshotContext.source = source
        guideSnapshotContext.kind = targetKind
        guideSnapshotContext.legKind = nil
        baseContentSnapshot = ResolveGuideContentSnapshot(guideSnapshotContext)
    elseif targetKind == "route" and not manualAuthorityActive then
        baseContentSnapshot = ResolveGuideRoutePresentationSnapshot(
            title,
            routeCanonicalSource,
            routeGoalMapID,
            routeGoalX,
            routeGoalY,
            routeLegKind,
            routeTravelType
        )
    end

    local isGuideRoute = targetKind == "route" and type(baseContentSnapshot) == "table"
    local effectiveTravelType = liveTravelConfidence == "high"
        and type(liveTravelType) == "string"
        and liveTravelType
        or nil
    local currentSearchKind = ResolveActiveSearchKind(targetKind, activeManualDestination)
    local contentSnapshot
    if targetKind == "route" and baseContentSnapshot == nil then
        contentSnapshot = BuildRouteContentSnapshot(
            liveTravelType,
            liveTravelConfidence,
            routeGoalMapID,
            routeLegKind,
            routeTravelType,
            sourceAddon
        )
    elseif baseContentSnapshot == lastFinalizedBase
        and targetKind == lastFinalizedKind
        and effectiveTravelType == lastFinalizedTravelType
        and sourceAddon == lastFinalizedSourceAddon
        and currentSearchKind == lastFinalizedSearchKind
        and lastFinalizedResult
    then
        contentSnapshot = lastFinalizedResult
    else
        contentSnapshot = FinalizeContentSnapshot(
            baseContentSnapshot,
            targetKind,
            isGuideRoute,
            liveTravelType,
            liveTravelConfidence,
            sourceAddon,
            currentSearchKind
        )
        lastFinalizedBase = baseContentSnapshot
        lastFinalizedKind = targetKind
        lastFinalizedTravelType = effectiveTravelType
        lastFinalizedSourceAddon = sourceAddon
        lastFinalizedSearchKind = currentSearchKind
        lastFinalizedResult = contentSnapshot
    end

    local effectiveTitle = (type(contentSnapshot) == "table" and contentSnapshot.mirrorTitle) or title or " "
    local contentSig = type(contentSnapshot) == "table" and contentSnapshot.contentSig or nil
    if targetKind == "route" then
        if type(routeTitle) == "string"
            and not (type(contentSnapshot) == "table" and contentSnapshot.guideRoutePresentation == true)
        then
            effectiveTitle = routeTitle
        end
    end
    local sig = signature(mapID, x, y)
    -- Persist manual waypoint source identity so it survives /reload
    if targetKind == "manual" and (sourceAddon or currentSearchKind) then
        local db = NS.GetDB()
        local saved = db._zwpManual
        if not (type(saved) == "table" and saved.sig == sig
            and saved.sourceAddon == sourceAddon
            and saved.searchKind == currentSearchKind)
        then
            db._zwpManual = { sig = sig, sourceAddon = sourceAddon, searchKind = currentSearchKind }
        end
    end
    ObserveManualRouteCarrier(activeManualRouteDestinationSig, sig, targetKind)
    local sigChanged = sig ~= bridge.lastSig
    local titleChanged = effectiveTitle ~= (bridge.lastTitle or " ")
    local contentChanged = contentSig ~= bridge.lastContentSig
    if sigChanged or titleChanged or contentChanged then
        if ShouldHoldManualRouteFallbackSwitch(activeManualRouteDestinationSig, sig, source, targetKind) then
            return
        end
        if sigChanged and not fromDisplay and not manualAuthorityActive and ShouldDebounceFallbackSwitch(sig, source) then
            return
        end
        bridge.lastSig = sig
        if not sigChanged and bridge.lastUID then
            -- Title/content-only change: update mirrored consumers in place without
            -- removing/re-adding the TomTom waypoint or disturbing the host waypoint.
            bridge.lastTitle = effectiveTitle
            bridge.lastContentSig = contentSig
            bridge.lastAppliedSource = source
            bridge.lastAppliedKind = targetKind
            bridge.lastAppliedMapID = mapID
            bridge.lastAppliedX = x
            bridge.lastAppliedY = y
            bridge.lastAppliedGuideRoutePresentation =
                type(contentSnapshot) == "table" and contentSnapshot.guideRoutePresentation == true or false
            if titleChanged then
                local tomtom = GetTomTom()
                ApplyCrazyArrowUID(tomtom, bridge.lastUID, effectiveTitle, bridge.lastUIDOwned == false)
            end
            SyncTomTomArrowVisualSuppression()
            SyncWorldOverlay(bridge.lastUID, mapID, x, y, effectiveTitle, source, targetKind, contentSnapshot)
            return
        end
        PushTomTom(mapID, x, y, effectiveTitle, source, targetKind, sigChanged, contentSnapshot)
        return
    end

    SyncTomTomArrowVisualSuppression()
end
