local NS = _G.AzerothWaypointNS
local state = NS.State
local Queue = NS.RouteQueueInternal
if type(Queue) ~= "table" then
    Queue = {}
    NS.RouteQueueInternal = Queue
end
function Queue.NormalizeQueueItemMeta(meta, mapID, x, y)
    local normalized = type(NS.ValidateRouteMeta) == "function"
        and NS.ValidateRouteMeta(meta)
        and meta
        or nil
    if type(normalized) ~= "table" and type(meta) == "table" and type(meta.identity) == "table" then
        normalized = NS.BuildRouteMeta(meta.identity, {
            sourceAddon = meta.sourceAddon,
            searchKind = meta.searchKind,
            manualQuestID = meta.manualQuestID,
            mapPinInfo = meta.mapPinInfo,
            queueSourceType = meta.queueSourceType,
        })
    end
    if type(normalized) ~= "table" then
        normalized = NS.BuildRouteMeta(NS.BuildManualIdentity(mapID, x, y), nil)
    end
    if type(normalized) ~= "table" then
        return nil
    end

    return NS.BuildRouteMeta(normalized.identity, {
        sourceAddon = Queue.NormalizeSourceAddon(normalized.sourceAddon),
        searchKind = Queue.TrimString(normalized.searchKind),
        manualQuestID = type(normalized.manualQuestID) == "number" and normalized.manualQuestID or nil,
        mapPinInfo = Queue.DeepCopy(normalized.mapPinInfo),
        queueSourceType = Queue.TrimString(normalized.queueSourceType),
    })
end

function Queue.InferQueueSourceType(meta)
    local normalized = type(meta) == "table" and meta or nil
    if Queue.TrimString(normalized and normalized.queueSourceType) == "transient_source" then
        return "transient_source"
    end

    local sourceAddon = Queue.NormalizeSourceAddon(normalized and normalized.sourceAddon)
    if sourceAddon and type(Queue.IsTransientSourceAddon) == "function" and Queue.IsTransientSourceAddon(sourceAddon) then
        return "transient_source"
    end

    local identity = normalized and normalized.identity or nil
    local kind = type(identity) == "table" and Queue.TrimString(identity.kind) or nil
    if kind == "blizzard_user_waypoint" then
        return "manual_click"
    end
    if kind == "external_tomtom" then
        return "external"
    end
    return "manual"
end

function Queue.GetIdentityKind(meta)
    local identity = type(meta) == "table" and meta.identity or nil
    local kind = type(identity) == "table" and identity.kind or nil
    return Queue.TrimString(kind)
end

function Queue.ShouldCreateDestinationQueue(sourceType, meta)
    if sourceType == "imported"
        or sourceType == "manual_click"
        or sourceType == "external"
    then
        return true
    end
    if sourceType ~= "manual" then
        return false
    end

    local identityKind = Queue.GetIdentityKind(meta)
    return identityKind == nil
        or identityKind == "manual"
        or identityKind == "blizzard_user_waypoint"
        or identityKind == "external_tomtom"
end

function Queue.BuildQueueLabel(kind, sourceType, title, queueID)
    local trimmedTitle = Queue.TrimString(title)
    if sourceType == "guide" then
        return "Guide"
    end
    if sourceType == "transient_source" then
        return trimmedTitle or "Transient Route"
    end
    if sourceType == "imported" then
        return trimmedTitle or ("Imported Queue " .. tostring(queueID or ""))
    end
    if kind == "destination_queue" then
        return trimmedTitle or ("Manual Queue " .. tostring(queueID or ""))
    end
    return trimmedTitle or ("Manual Route " .. tostring(queueID or ""))
end

function Queue.BuildQueueItem(mapID, x, y, title, meta, sourceType)
    return {
        mapID = mapID,
        x = x,
        y = y,
        title = title,
        sig = Queue.GetWaypointSig(mapID, x, y),
        sourceType = sourceType,
        meta = Queue.NormalizeQueueItemMeta(meta, mapID, x, y),
    }
end

function Queue.BuildRouteMetaForQueueItem(item)
    if type(item) ~= "table" then
        return nil
    end
    return Queue.DeepCopy(item.meta)
end

function Queue.NormalizeQuestIDCandidate(value)
    value = tonumber(value)
    return type(value) == "number" and value > 0 and value or nil
end

function Queue.GetQuestIDForQueueItem(item)
    local meta = type(item) == "table" and type(item.meta) == "table" and item.meta or nil
    if type(meta) ~= "table" then
        return nil
    end
    local identity = type(meta.identity) == "table" and meta.identity or nil
    if type(identity) == "table" and identity.kind == "quest" then
        return Queue.NormalizeQuestIDCandidate(identity.questID or meta.manualQuestID)
    end
    return Queue.NormalizeQuestIDCandidate(meta.manualQuestID)
end

function Queue.CreateQueue(kind, sourceType, label)
    local queueID = Queue.AllocateQueueID(kind == "destination_queue" and "mq" or "rq")
    return {
        id = queueID,
        kind = kind,
        sourceType = sourceType,
        label = Queue.BuildQueueLabel(kind, sourceType, label, queueID),
        createdAt = Queue.GetTimeSafe(),
        readOnly = kind == "route",
        items = {},
        activeItemIndex = 1,
        projection = nil,
        detailsExpanded = false,
    }
end

function Queue.CreateRouteQueue(mapID, x, y, title, meta, sourceType)
    local queue = Queue.CreateQueue("route", sourceType, title)
    queue.items[1] = Queue.BuildQueueItem(mapID, x, y, title, meta, sourceType)
    return queue
end

function Queue.CreateDestinationQueue(entries, sourceType, label)
    local queue = Queue.CreateQueue("destination_queue", sourceType, label)
    queue.readOnly = false
    for index = 1, #entries do
        local entry = entries[index]
        if type(entry) == "table"
            and type(entry.mapID) == "number"
            and type(entry.x) == "number"
            and type(entry.y) == "number"
        then
            queue.items[#queue.items + 1] = Queue.BuildQueueItem(
                entry.mapID,
                entry.x,
                entry.y,
                entry.title,
                entry.meta,
                sourceType
            )
        end
    end
    queue.label = Queue.BuildQueueLabel("destination_queue", sourceType, label or queue.items[1] and queue.items[1].title, queue.id)
    return queue
end

function Queue.CreateSingleDestinationQueue(mapID, x, y, title, meta, sourceType)
    return Queue.CreateDestinationQueue({
        {
            mapID = mapID,
            x = x,
            y = y,
            title = title,
            meta = meta,
        },
    }, sourceType, title)
end

function Queue.CreateSingleItemQueue(mapID, x, y, title, meta, sourceType)
    if Queue.ShouldCreateDestinationQueue(sourceType, meta) then
        return Queue.CreateSingleDestinationQueue(mapID, x, y, title, meta, sourceType)
    end
    return Queue.CreateRouteQueue(mapID, x, y, title, meta, sourceType)
end

function Queue.QueueItemMatchesDestination(item, mapID, x, y, title)
    if type(item) ~= "table" then
        return false
    end

    local itemSig = item.sig or Queue.GetWaypointSig(item.mapID, item.x, item.y)
    local sig = Queue.GetWaypointSig(mapID, x, y)
    local sameCoords = itemSig and sig and itemSig == sig
        or Queue.SameWaypointCoords(item.mapID, item.x, item.y, mapID, x, y)
    if not sameCoords then
        return false
    end

    return Queue.NormalizeTitleKey(item.title) == Queue.NormalizeTitleKey(title)
end

function Queue.FindQueueItemByDestination(queue, mapID, x, y, title)
    if type(queue) ~= "table" or type(queue.items) ~= "table" then
        return nil
    end
    for index = 1, #queue.items do
        if Queue.QueueItemMatchesDestination(queue.items[index], mapID, x, y, title) then
            return index, queue.items[index]
        end
    end
    return nil
end

function Queue.QueueItemMatchesRecord(item, record)
    if type(record) ~= "table" then
        return false
    end
    if type(item) ~= "table" then
        return false
    end

    local itemSig = item.sig or Queue.GetWaypointSig(item.mapID, item.x, item.y)
    local recordSig = record.sig or Queue.GetWaypointSig(record.mapID, record.x, record.y)
    local sameCoords = itemSig and recordSig and itemSig == recordSig
        or Queue.SameWaypointCoords(item.mapID, item.x, item.y, record.mapID, record.x, record.y)
    if not sameCoords then
        return false
    end

    local itemTitle = Queue.NormalizeTitleKey(item.title)
    local recordTitle = Queue.NormalizeTitleKey(record.title)
    return itemTitle == "" or recordTitle == "" or itemTitle == recordTitle
end

function Queue.FindQueueItemIndexForRecord(queue, record, preferredIndex)
    if type(queue) ~= "table" or type(queue.items) ~= "table" or type(record) ~= "table" then
        return nil, nil
    end

    preferredIndex = tonumber(preferredIndex)
    if preferredIndex
        and preferredIndex >= 1
        and preferredIndex <= #queue.items
        and Queue.QueueItemMatchesRecord(queue.items[preferredIndex], record)
    then
        return preferredIndex, queue.items[preferredIndex]
    end

    return Queue.FindQueueItemByDestination(queue, record.mapID, record.x, record.y, record.title)
end

function Queue.PersistManualAuthorityIfAvailable()
    if type(NS.PersistManualAuthority) == "function" then
        NS.PersistManualAuthority()
    end
end

function Queue.RepairActiveManualQueueIndex(queue)
    if type(queue) ~= "table" or type(queue.id) ~= "string" then
        return false
    end

    local record = type(NS.GetManualAuthority) == "function" and NS.GetManualAuthority() or nil
    if type(record) ~= "table" or record.queueID ~= queue.id then
        return false
    end

    local matchedIndex = Queue.FindQueueItemIndexForRecord(queue, record, record.queueItemIndex)
    if not matchedIndex then
        return false
    end

    local changed = tonumber(record.queueItemIndex) ~= matchedIndex
        or tonumber(queue.activeItemIndex) ~= matchedIndex
    record.queueItemIndex = matchedIndex
    queue.activeItemIndex = matchedIndex
    if changed then
        Queue.PersistManualAuthorityIfAvailable()
    end
    return changed
end

function Queue.RemoveQueueItemAt(queue, itemIndex)
    if type(queue) ~= "table" or type(queue.items) ~= "table" then
        return false
    end
    itemIndex = tonumber(itemIndex)
    if not itemIndex or itemIndex < 1 or itemIndex > #queue.items then
        return false
    end
    table.remove(queue.items, itemIndex)
    if #queue.items == 0 then
        if queue.sourceType == "transient_source" then
            Queue.PopTransientQueue(queue.id)
        else
            Queue.DeleteManualQueue(queue.id)
        end
        Queue.RefreshQueueUI()
        return true
    end
    if itemIndex == queue.activeItemIndex then
        queue.activeItemIndex = itemIndex <= #queue.items and itemIndex or 1
    elseif queue.activeItemIndex > #queue.items then
        queue.activeItemIndex = #queue.items
    elseif itemIndex < queue.activeItemIndex then
        queue.activeItemIndex = queue.activeItemIndex - 1
    end
    Queue.RepairActiveManualQueueIndex(queue)
    Queue.PersistManualQueues()
    Queue.RefreshQueueUI()
    return true
end

function Queue.RemoveQuestItemsFromQueue(queue, questID, opts)
    local removed = 0
    if type(queue) ~= "table" or type(queue.items) ~= "table" then
        return removed
    end
    opts = type(opts) == "table" and opts or {}
    local skipQueueID = Queue.TrimString(opts.skipQueueID)
    local skipItemIndex = tonumber(opts.skipQueueItemIndex)
    for itemIndex = #queue.items, 1, -1 do
        local isSkipped = skipQueueID ~= nil
            and skipItemIndex ~= nil
            and queue.id == skipQueueID
            and itemIndex == skipItemIndex
        if not isSkipped and Queue.GetQuestIDForQueueItem(queue.items[itemIndex]) == questID then
            if Queue.RemoveQueueItemAt(queue, itemIndex) then
                removed = removed + 1
            end
            if type(queue.items) ~= "table" or #queue.items == 0 then
                break
            end
        end
    end
    return removed
end

function NS.RemoveQuestBackedManualQueueItems(questID, opts)
    local normalizedQuestID = Queue.NormalizeQuestIDCandidate(questID)
    if not normalizedQuestID then
        return false, 0
    end
    opts = type(opts) == "table" and opts or {}

    local removed = 0
    local manualQueues = Queue.GetManualQueueState()
    for orderIndex = #manualQueues.order, 1, -1 do
        local queue = manualQueues.byID[manualQueues.order[orderIndex]]
        removed = removed + Queue.RemoveQuestItemsFromQueue(queue, normalizedQuestID, opts)
    end

    local transientStack = Queue.GetTransientQueueStack()
    for stackIndex = #transientStack, 1, -1 do
        removed = removed + Queue.RemoveQuestItemsFromQueue(transientStack[stackIndex], normalizedQuestID, opts)
    end

    if removed > 0 and type(NS.RecomputeCarrier) == "function" then
        NS.RecomputeCarrier()
    end
    return removed > 0, removed
end

function NS.ClearManualQueues()
    local routing = Queue.EnsureQueueState()
    routing.manualQueuesHydrated = true
    local manualQueues = routing.manualQueues
    manualQueues.order = {}
    manualQueues.byID = {}
    manualQueues.activeQueueID = nil
    Queue.PersistManualQueues()
    Queue.RefreshQueueUI()
    return true
end

function NS.IsActiveManualQueueItem(record)
    if type(record) ~= "table" or type(record.queueID) ~= "string" then
        return false
    end
    local queue = Queue.GetManualQueueByID(record.queueID)
    if type(queue) ~= "table" or type(queue.items) ~= "table" then
        return false
    end
    local index = Queue.FindQueueItemIndexForRecord(queue, record, record.queueItemIndex)
        or tonumber(record.queueItemIndex)
        or queue.activeItemIndex
        or 1
    local item = queue.items[index]
    if type(item) ~= "table" then
        return false
    end
    local changed = tonumber(record.queueItemIndex) ~= index
        or tonumber(queue.activeItemIndex) ~= index
    record.queueItemIndex = index
    queue.activeItemIndex = index
    if changed then
        Queue.PersistManualAuthorityIfAvailable()
        Queue.PersistManualQueues()
    end
    local recordSig = record.sig or Queue.GetWaypointSig(record.mapID, record.x, record.y)
    local itemSig = item.sig or Queue.GetWaypointSig(item.mapID, item.x, item.y)
    return queue.activeItemIndex == index and type(recordSig) == "string" and recordSig == itemSig
end

function NS.NoteQueuedTomTomWaypointCleared(uid)
    if type(uid) ~= "table" or type(uid[1]) ~= "number" or type(uid[2]) ~= "number" or type(uid[3]) ~= "number" then
        return false
    end
    local sig = Queue.GetWaypointSig(uid[1], uid[2], uid[3])
    if type(sig) ~= "string" then
        return false
    end
    local active = type(NS.GetManualAuthority) == "function" and NS.GetManualAuthority() or nil
    if type(active) == "table" and (active.sig == sig or active.identity and (active.identity.externalSig == sig or active.identity.queueSig == sig)) then
        return false
    end

    local manualQueues = Queue.GetManualQueueState()
    for orderIndex = #manualQueues.order, 1, -1 do
        local queue = manualQueues.byID[manualQueues.order[orderIndex]]
        if type(queue) == "table" and type(queue.items) == "table" then
            for itemIndex = #queue.items, 1, -1 do
                local item = queue.items[itemIndex]
                if type(item) == "table" and (item.sig == sig or Queue.GetWaypointSig(item.mapID, item.x, item.y) == sig) then
                    Queue.RemoveQueueItemAt(queue, itemIndex)
                    return true
                end
            end
        end
    end
    return false
end

local function DeleteManualQueueWithoutRefresh(queueID)
    local manualQueues = Queue.GetManualQueueState()
    if type(manualQueues.byID[queueID]) ~= "table" then
        return false
    end

    local index = Queue.FindManualQueueIndex(queueID)
    if index then
        table.remove(manualQueues.order, index)
    end
    manualQueues.byID[queueID] = nil
    if manualQueues.activeQueueID == queueID then
        manualQueues.activeQueueID = nil
    end
    return true
end

local function BuildDescendingUniqueIndexes(indexes, maxIndex)
    local seen = {}
    local out = {}
    if type(indexes) ~= "table" then
        return out
    end
    for key, value in pairs(indexes) do
        local index = tonumber(value == true and key or value)
        if index and index >= 1 and index <= maxIndex and not seen[index] then
            seen[index] = true
            out[#out + 1] = index
        end
    end
    table.sort(out, function(left, right) return left > right end)
    return out
end

local function BuildUniqueQueueIDs(queueIDs)
    local seen = {}
    local out = {}
    if type(queueIDs) ~= "table" then
        return out
    end
    for key, value in pairs(queueIDs) do
        local queueID = value == true and key or value
        if type(queueID) == "string" and queueID ~= "guide" and queueID:match("^guide:") == nil and not seen[queueID] then
            seen[queueID] = true
            out[#out + 1] = queueID
        end
    end
    return out
end

function NS.RemoveQueueItem(queueID, itemIndex)
    local queue = Queue.GetManualQueueByID(queueID)
    if type(queue) ~= "table" or queue.kind ~= "destination_queue" then
        return false
    end

    local record = type(NS.GetManualAuthority) == "function" and NS.GetManualAuthority() or nil
    local activeIndex = nil
    if type(record) == "table" and record.queueID == queueID then
        activeIndex = Queue.FindQueueItemIndexForRecord(queue, record, record.queueItemIndex)
    end
    if activeIndex then
        record.queueItemIndex = activeIndex
        queue.activeItemIndex = activeIndex
        Queue.PersistManualAuthorityIfAvailable()
    end
    local isActive = type(record) == "table"
        and record.queueID == queueID
        and tonumber(activeIndex or record.queueItemIndex) == tonumber(itemIndex)
    Queue.RemoveQueueItemAt(queue, itemIndex)
    if isActive then
        local nextRequest = Queue.BuildRouteRequestFromQueueID(queueID, queue.activeItemIndex)
        if nextRequest then
            return Queue.RouteQueueRequest(nextRequest)
        end
        if type(NS.HandleExplicitManualAuthorityRemove) == "function" then
            return NS.HandleExplicitManualAuthorityRemove()
        end
    end
    return true
end

function NS.RemoveQueueItems(queueID, itemIndexes)
    local queue = Queue.GetManualQueueByID(queueID)
    if type(queue) ~= "table" or queue.kind ~= "destination_queue" or type(queue.items) ~= "table" then
        return false, 0
    end

    local indexes = BuildDescendingUniqueIndexes(itemIndexes, #queue.items)
    if #indexes == 0 then
        return false, 0
    end

    local record = type(NS.GetManualAuthority) == "function" and NS.GetManualAuthority() or nil
    local activeIndex = tonumber(queue.activeItemIndex) or 1
    local activeRecord = type(record) == "table" and record.queueID == queueID and record or nil
    local isActiveQueue = activeRecord ~= nil
    if type(activeRecord) == "table" then
        activeIndex = Queue.FindQueueItemIndexForRecord(queue, activeRecord, activeRecord.queueItemIndex)
            or tonumber(activeRecord.queueItemIndex)
            or activeIndex
    end

    local removedActive = false
    local removed = 0
    for _, itemIndex in ipairs(indexes) do
        if itemIndex == activeIndex then
            removedActive = true
        elseif itemIndex < activeIndex then
            activeIndex = activeIndex - 1
        end
        table.remove(queue.items, itemIndex)
        removed = removed + 1
    end

    if #queue.items == 0 then
        DeleteManualQueueWithoutRefresh(queueID)
        Queue.PersistManualQueues()
        if isActiveQueue and type(NS.HandleExplicitManualAuthorityRemove) == "function" then
            NS.HandleExplicitManualAuthorityRemove()
        elseif type(NS.RecomputeCarrier) == "function" then
            NS.RecomputeCarrier()
        end
        Queue.RefreshQueueUI()
        return true, removed
    end

    if activeIndex < 1 then
        activeIndex = 1
    elseif activeIndex > #queue.items then
        activeIndex = #queue.items
    end
    queue.activeItemIndex = activeIndex

    if isActiveQueue and type(record) == "table" then
        record.queueItemIndex = activeIndex
        Queue.PersistManualAuthorityIfAvailable()
    end
    Queue.PersistManualQueues()

    if removedActive then
        local nextRequest = Queue.BuildRouteRequestFromQueueID(queueID, queue.activeItemIndex)
        if nextRequest then
            Queue.RouteQueueRequest(nextRequest)
        elseif type(NS.HandleExplicitManualAuthorityRemove) == "function" then
            NS.HandleExplicitManualAuthorityRemove()
        end
    end
    Queue.RefreshQueueUI()
    return true, removed
end

function NS.MoveQueueItem(queueID, fromIndex, toIndex)
    local queue = Queue.GetManualQueueByID(queueID)
    if type(queue) ~= "table" or queue.kind ~= "destination_queue" then
        return false
    end
    fromIndex = tonumber(fromIndex)
    toIndex = tonumber(toIndex)
    if not fromIndex or not toIndex or fromIndex < 1 or toIndex < 1 or fromIndex > #queue.items or toIndex > #queue.items then
        return false
    end
    if fromIndex == toIndex then
        return true
    end

    local item = table.remove(queue.items, fromIndex)
    table.insert(queue.items, toIndex, item)
    if queue.activeItemIndex == fromIndex then
        queue.activeItemIndex = toIndex
    elseif fromIndex < queue.activeItemIndex and toIndex >= queue.activeItemIndex then
        queue.activeItemIndex = queue.activeItemIndex - 1
    elseif fromIndex > queue.activeItemIndex and toIndex <= queue.activeItemIndex then
        queue.activeItemIndex = queue.activeItemIndex + 1
    end
    Queue.PersistManualQueues()
    Queue.RefreshQueueUI()

    local record = type(NS.GetManualAuthority) == "function" and NS.GetManualAuthority() or nil
    if type(record) == "table" and record.queueID == queueID and record.queueItemIndex == fromIndex then
        record.queueItemIndex = queue.activeItemIndex
    end
    Queue.RepairActiveManualQueueIndex(queue)
    return true
end

function NS.ClearQueuesByID(queueIDs)
    local ids = BuildUniqueQueueIDs(queueIDs)
    if #ids == 0 then
        return false, 0
    end

    local record = type(NS.GetManualAuthority) == "function" and NS.GetManualAuthority() or nil
    local activeQueueID = type(record) == "table" and record.queueID or nil
    local removedActive = false
    local removedManual = false
    local removed = 0

    for _, queueID in ipairs(ids) do
        local queue = Queue.GetQueueByID(queueID)
        if type(queue) == "table" then
            if activeQueueID == queueID then
                removedActive = true
            end

            if queue.sourceType == "transient_source" then
                if Queue.PopTransientQueue(queueID) then
                    removed = removed + 1
                end
            elseif DeleteManualQueueWithoutRefresh(queueID) then
                removed = removed + 1
                removedManual = true
            end
        end
    end

    if removed == 0 then
        return false, 0
    end

    if removedManual then
        Queue.PersistManualQueues()
    end
    if removedActive and type(NS.HandleExplicitManualAuthorityRemove) == "function" then
        NS.HandleExplicitManualAuthorityRemove()
    elseif type(NS.RecomputeCarrier) == "function" then
        NS.RecomputeCarrier()
    end
    Queue.RefreshQueueUI()
    return true, removed
end

function NS.ClearQueueByID(queueID)
    local queue = Queue.GetQueueByID(queueID)
    if type(queue) ~= "table" then
        return false
    end

    local record = type(NS.GetManualAuthority) == "function" and NS.GetManualAuthority() or nil
    local isActiveManual = type(record) == "table" and record.queueID == queueID
    if queue.sourceType == "transient_source" then
        if not isActiveManual then
            Queue.PopTransientQueue(queueID)
        end
    else
        Queue.DeleteManualQueue(queueID)
    end

    if isActiveManual and type(NS.HandleExplicitManualAuthorityRemove) == "function" then
        return NS.HandleExplicitManualAuthorityRemove()
    end

    if type(NS.RecomputeCarrier) == "function" then
        NS.RecomputeCarrier()
    end
    return true
end

