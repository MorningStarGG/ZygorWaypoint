local NS = _G.AzerothWaypointNS
local state = NS.State
local Queue = NS.RouteQueueInternal
if type(Queue) ~= "table" then
    Queue = {}
    NS.RouteQueueInternal = Queue
end
function Queue.BuildProjectionEntryKey(queue, index, mapID, x, y, entryType)
    return table.concat({
        tostring(queue and queue.id or "-"),
        tostring(index or "-"),
        tostring(mapID or "-"),
        tostring(type(x) == "number" and string.format("%.5f", x) or "-"),
        tostring(type(y) == "number" and string.format("%.5f", y) or "-"),
        tostring(entryType or "-"),
    }, "\031", 1, 6)
end

function Queue.CopyGuidePresentationFields(entry, snapshot)
    if type(entry) ~= "table" or type(snapshot) ~= "table" then
        return
    end

    local title = Queue.TrimString(snapshot.mirrorTitle) or Queue.TrimString(snapshot.overlayTitle)
    if title then
        entry.title = title
    end

    entry.subtext = Queue.TrimString(snapshot.pinpointSubtext) or Queue.TrimString(snapshot.overlaySubtext)
    entry.semanticKind = Queue.TrimString(snapshot.semanticKind)
    entry.semanticQuestID = type(snapshot.semanticQuestID) == "number" and snapshot.semanticQuestID > 0
        and snapshot.semanticQuestID
        or nil
    entry.semanticTravelType = Queue.TrimString(snapshot.semanticTravelType)
    entry.iconHintKind = Queue.TrimString(snapshot.iconHintKind) or entry.semanticKind
    entry.iconHintQuestID = type(snapshot.iconHintQuestID) == "number" and snapshot.iconHintQuestID > 0
        and snapshot.iconHintQuestID
        or entry.semanticKind == "quest" and entry.semanticQuestID
        or nil
    entry.liveTravelType = Queue.TrimString(snapshot.liveTravelType)
    entry.guideProvider = Queue.TrimString(snapshot.guideProvider)
    entry.presentationContentSig = Queue.TrimString(snapshot.contentSig)
end

function Queue.ResolveGuideFinalProjectionSnapshot(record)
    if type(record) ~= "table" then
        return nil
    end

    local target = type(record.target) == "table" and record.target or nil
    local mapID = type(record.mapID) == "number" and record.mapID or target and target.mapID
    local x = type(record.x) == "number" and record.x or target and target.x
    local y = type(record.y) == "number" and record.y or target and target.y
    if type(mapID) ~= "number" or type(x) ~= "number" or type(y) ~= "number" then
        return nil
    end

    local provider = Queue.TrimString(record.guideProvider) or Queue.TrimString(target and target.guideProvider)
    if provider ~= "zygor" or type(NS.ResolveGuideContentSnapshot) ~= "function" then
        local targetSemanticQuestID = target and rawget(target, "semanticQuestID") or nil
        local targetIconHintQuestID = target and rawget(target, "iconHintQuestID") or nil
        local title = Queue.TrimString(record.title)
            or Queue.TrimString(target and target.title)
            or Queue.TrimString(record.rawTitle)
            or Queue.TrimString(target and target.rawTitle)
            or "Guide step"
        local subtext = Queue.TrimString(record.subtext) or Queue.TrimString(target and target.subtext)
        return {
            mirrorTitle = title,
            overlayTitle = title,
            overlaySubtext = subtext,
            pinpointSubtext = subtext,
            guideProvider = provider,
            semanticKind = Queue.TrimString(record.semanticKind) or Queue.TrimString(target and target.semanticKind),
            semanticQuestID = type(record.semanticQuestID) == "number" and record.semanticQuestID
                or type(targetSemanticQuestID) == "number" and targetSemanticQuestID
                or nil,
            iconHintKind = Queue.TrimString(record.iconHintKind) or Queue.TrimString(target and target.iconHintKind),
            iconHintQuestID = type(record.iconHintQuestID) == "number" and record.iconHintQuestID
                or type(targetIconHintQuestID) == "number" and targetIconHintQuestID
                or nil,
            routePresentationAllowed = true,
            contentSig = table.concat({
                tostring(provider or "guide"),
                tostring(mapID),
                tostring(type(x) == "number" and string.format("%.5f", x) or "-"),
                tostring(type(y) == "number" and string.format("%.5f", y) or "-"),
                tostring(title),
                tostring(subtext or ""),
            }, "\031", 1, 6),
        }
    end

    local snapshot = NS.ResolveGuideContentSnapshot({
        rawArrowTitle = Queue.TrimString(record.rawTitle) or Queue.TrimString(target and target.rawTitle) or Queue.TrimString(record.title),
        mapID = mapID,
        x = x,
        y = y,
        sig = Queue.GetWaypointSig(mapID, x, y),
        kind = "guide",
        legKind = "destination",
        source = Queue.TrimString(record.guideSource) or Queue.TrimString(target and target.source) or "guide",
    })
    if type(snapshot) ~= "table" or snapshot.routePresentationAllowed == false then
        return nil
    end
    return snapshot
end

function Queue.BuildProjectionEntry(queue, leg, index, record, entryType, projectionContext)
    local sourceMeta = type(record) == "table" and record.meta or nil
    local title = type(leg) == "table" and leg.title or nil
    if not title then
        title = type(record) == "table" and record.title or nil
    end
    local entry = {
        key = Queue.BuildProjectionEntryKey(queue, index, leg and leg.mapID, leg and leg.x, leg and leg.y, entryType),
        mapID = leg and leg.mapID,
        x = leg and leg.x,
        y = leg and leg.y,
        title = title,
        entryType = entryType,
        routeLegKind = type(leg) == "table" and leg.routeLegKind or nil,
        routeTravelType = type(leg) == "table" and leg.routeTravelType or nil,
        plannerLegKind = type(leg) == "table" and leg.kind or nil,
        sourceAddon = type(sourceMeta) == "table" and sourceMeta.sourceAddon or nil,
        searchKind = type(sourceMeta) == "table" and sourceMeta.searchKind or nil,
        manualQuestID = type(sourceMeta) == "table" and sourceMeta.manualQuestID or nil,
        mapPinInfo = type(sourceMeta) == "table" and Queue.DeepCopy(sourceMeta.mapPinInfo) or nil,
        isHead = type(record) == "table" and tonumber(record.currentLegIndex) == index or false,
        readOnly = true,
    }

    if type(projectionContext) == "table" and projectionContext.source == "guide" then
        if entry.entryType == "final_destination" then
            Queue.CopyGuidePresentationFields(entry, projectionContext.finalSnapshot)
        end
        if entry.isHead == true then
            Queue.CopyGuidePresentationFields(entry, projectionContext.activePresentation)
        end
        entry.guideProvider = entry.guideProvider or Queue.TrimString(queue and queue.provider)
    end

    return entry
end


function Queue.BuildRouteProjection(queue, record, projectionContext)
    projectionContext = type(projectionContext) == "table" and projectionContext or nil
    if projectionContext and projectionContext.source == "guide" and type(projectionContext.finalSnapshot) ~= "table" then
        projectionContext.finalSnapshot = Queue.ResolveGuideFinalProjectionSnapshot(record)
    end

    local projection = {
        kind = "route",
        entries = {},
        headIndex = tonumber(type(record) == "table" and record.currentLegIndex) or 1,
        updatedAt = Queue.GetTimeSafe(),
    }

    if type(record) ~= "table" then
        return projection
    end

    local finalMapID = record.mapID
    local finalX = record.x
    local finalY = record.y
    local finalTitle = record.title

    if type(record.legs) == "table" then
        for index = 1, #record.legs do
            local leg = record.legs[index]
            if type(leg) == "table"
                and type(leg.mapID) == "number"
                and type(leg.x) == "number"
                and type(leg.y) == "number"
            then
                local entryType = leg.routeLegKind == "carrier" and "travel" or "final_destination"
                if entryType ~= "travel"
                    and not Queue.SameWaypointCoords(leg.mapID, leg.x, leg.y, finalMapID, finalX, finalY)
                    and index < #record.legs
                then
                    entryType = "destination"
                end
                projection.entries[#projection.entries + 1] = Queue.BuildProjectionEntry(queue, leg, index, record, entryType, projectionContext)
            end
        end
    end

    local lastEntry = projection.entries[#projection.entries]
    if type(finalMapID) == "number"
        and type(finalX) == "number"
        and type(finalY) == "number"
        and (
            type(lastEntry) ~= "table"
            or not Queue.SameWaypointCoords(lastEntry.mapID, lastEntry.x, lastEntry.y, finalMapID, finalX, finalY)
        )
    then
        projection.entries[#projection.entries + 1] = Queue.BuildProjectionEntry(queue, {
            mapID = finalMapID,
            x = finalX,
            y = finalY,
            title = finalTitle,
            routeLegKind = "destination",
            routeTravelType = nil,
            kind = "destination",
        }, #projection.entries + 1, record, "final_destination", projectionContext)
    end

    return projection
end

function Queue.BuildDestinationQueueProjection(queue, record)
    local projection = {
        kind = "destination_queue",
        items = {},
        derivedEntries = {},
        publishedEntries = {},
        activeItemIndex = tonumber(queue and queue.activeItemIndex) or 1,
        updatedAt = Queue.GetTimeSafe(),
    }

    queue = type(queue) == "table" and queue or nil
    if queue and type(queue.items) == "table" then
        for index = 1, #queue.items do
            local item = queue.items[index]
            if type(item) == "table" then
                projection.items[#projection.items + 1] = {
                    key = Queue.BuildProjectionEntryKey(queue, index, item.mapID, item.x, item.y, "destination"),
                    queueID = queue.id,
                    queueItemIndex = index,
                    mapID = item.mapID,
                    x = item.x,
                    y = item.y,
                    title = item.title,
                    entryType = "destination",
                    readOnly = false,
                    isActive = index == projection.activeItemIndex,
                }
            end
        end
    end

    local routeProjection = Queue.BuildRouteProjection(queue, record)
    projection.derivedEntries = routeProjection.entries
    for index = 1, #routeProjection.entries do
        local entry = routeProjection.entries[index]
        if type(entry) == "table" and entry.isHead ~= true then
            projection.publishedEntries[#projection.publishedEntries + 1] = entry
        end
    end
    if queue and type(queue.items) == "table" then
        for index = 1, #queue.items do
            local item = queue.items[index]
            if type(item) == "table" and index ~= projection.activeItemIndex then
                projection.publishedEntries[#projection.publishedEntries + 1] = {
                    key = Queue.BuildProjectionEntryKey(queue, index, item.mapID, item.x, item.y, "destination"),
                    queueID = queue.id,
                    queueItemIndex = index,
                    mapID = item.mapID,
                    x = item.x,
                    y = item.y,
                    title = item.title,
                    entryType = "destination",
                    readOnly = false,
                    isTopLevel = true,
                }
            end
        end
    end
    return projection
end

function Queue.ResolveActiveQueueReference()
    local stack = Queue.GetTransientQueueStack()
    if #stack > 0 then
        return stack[#stack], "transient"
    end

    local manualQueue = Queue.GetActiveNonTransientManualQueue()
    if type(manualQueue) == "table" then
        return manualQueue, "manual"
    end

    local guideQueue = Queue.GetActiveGuideQueue() or Queue.GetGuideQueueState()
    local guideProj = guideQueue.projection
    local guideEntries = type(guideProj) == "table" and guideProj.entries or nil
    if type(guideEntries) == "table" and #guideEntries > 0 then
        return guideQueue, "guide"
    end

    return nil, nil
end

function Queue.ClearGuideQueueProjection(provider)
    if provider then
        local guideQueue = Queue.GetGuideQueueState(provider)
        if type(guideQueue) == "table" then
            guideQueue.projection = nil
        end
        Queue.RefreshQueueUI()
        return
    end

    local guideQueues = Queue.GetGuideQueueList()
    for index = 1, #guideQueues do
        guideQueues[index].projection = nil
    end
    Queue.RefreshQueueUI()
end

function NS.ClearGuideQueueProjection(provider)
    Queue.ClearGuideQueueProjection(provider)
end

function NS.SyncGuideQueueProjection(authority, opts)
    if type(authority) ~= "table" then
        return nil
    end

    opts = type(opts) == "table" and opts or nil
    Queue.EnsureQueueState()

    local target = type(authority.target) == "table" and authority.target or nil
    local provider = Queue.NormalizeGuideProviderKey(authority.guideProvider)
        or Queue.NormalizeGuideProviderKey(target and target.guideProvider)
        or Queue.NormalizeGuideProviderKey(state.routing and state.routing.activeGuideProvider)
        or "zygor"
    local guideQueue = Queue.EnsureGuideQueue(provider)
    guideQueue.projection = Queue.BuildRouteProjection(guideQueue, authority, {
        source = "guide",
        activePresentation = opts and opts.activePresentation,
    })
    Queue.RefreshQueueUI()
    return guideQueue.projection
end

function NS.SyncAuthorityQueueProjection(authority, source)
    Queue.EnsureQueueState()

    if source == "guide" and type(authority) == "table" then
        local guideProjection = type(NS.SyncGuideQueueProjection) == "function"
            and NS.SyncGuideQueueProjection(authority, {
                activePresentation = state.routing.presentationState,
            })
            or nil
        local provider = Queue.NormalizeGuideProviderKey(authority.guideProvider)
            or Queue.NormalizeGuideProviderKey(type(authority.target) == "table" and authority.target.guideProvider)
            or Queue.NormalizeGuideProviderKey(state.routing and state.routing.activeGuideProvider)
            or "zygor"
        local guideQueue = Queue.EnsureGuideQueue(provider)
        guideQueue.projection = guideProjection or guideQueue.projection
        state.routing.activeQueueProjection = guideQueue.projection
        state.routing.activeQueueKey = guideQueue.id
        return guideQueue.projection
    end

    if source ~= "manual" or type(authority) ~= "table" then
        state.routing.activeQueueProjection = nil
        state.routing.activeQueueKey = nil
        Queue.RefreshQueueUI()
        return nil
    end

    local queue = type(authority.queueID) == "string" and Queue.GetQueueByID(authority.queueID) or nil
    if type(queue) ~= "table" then
        state.routing.activeQueueProjection = nil
        state.routing.activeQueueKey = nil
        return nil
    end

    local authorityItemIndex = Queue.FindQueueItemIndexForRecord(queue, authority, authority.queueItemIndex)
        or tonumber(authority.queueItemIndex)
        or queue.activeItemIndex
        or 1
    authority.queueItemIndex = authorityItemIndex

    if queue.kind == "destination_queue" then
        queue.activeItemIndex = authorityItemIndex
        queue.projection = Queue.BuildDestinationQueueProjection(queue, authority)
        state.routing.activeQueueProjection = queue.projection
    else
        queue.activeItemIndex = authorityItemIndex
        queue.projection = Queue.BuildRouteProjection(queue, authority)
        state.routing.activeQueueProjection = queue.projection
    end
    state.routing.activeQueueKey = queue.id
    Queue.PersistManualAuthorityIfAvailable()
    Queue.PersistManualQueues()
    Queue.RefreshQueueUI()
    return queue.projection
end

function NS.GetActiveQueueProjection()
    return Queue.EnsureQueueState().activeQueueProjection
end

function NS.GetActiveQueuePublishedEntries()
    local routing = Queue.EnsureQueueState()
    local projection = routing.activeQueueProjection
    if type(projection) ~= "table" then
        return nil, nil
    end

    if projection.kind == "destination_queue" then
        return projection.publishedEntries, routing.activeQueueKey
    end

    local entries = {}
    for index = 1, #(projection.entries or {}) do
        local entry = projection.entries[index]
        if type(entry) == "table" and entry.isHead ~= true then
            entries[#entries + 1] = entry
        end
    end
    return entries, routing.activeQueueKey
end

