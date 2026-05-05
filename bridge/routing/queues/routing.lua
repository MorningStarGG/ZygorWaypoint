local NS = _G.AzerothWaypointNS
local state = NS.State
local Queue = NS.RouteQueueInternal
if type(Queue) ~= "table" then
    Queue = {}
    NS.RouteQueueInternal = Queue
end
function Queue.GetQueueRouteItem(queue, itemIndex)
    if type(queue) ~= "table" or type(queue.items) ~= "table" then
        return nil, nil
    end
    itemIndex = tonumber(itemIndex) or tonumber(queue.activeItemIndex) or 1
    local item = queue.items[itemIndex]
    if type(item) ~= "table" then
        return nil, nil
    end
    return item, itemIndex
end

function Queue.BuildRouteRequestForQueue(queue, itemIndex)
    local item
    item, itemIndex = Queue.GetQueueRouteItem(queue, itemIndex)
    if type(item) ~= "table" then
        return nil
    end
    return {
        mapID = item.mapID,
        x = item.x,
        y = item.y,
        title = item.title,
        meta = Queue.BuildRouteMetaForQueueItem(item),
        queueContext = Queue.BuildQueueContext(queue, itemIndex),
    }
end

function Queue.BuildRouteRequestFromQueueID(queueID, itemIndex)
    local queue = Queue.GetQueueByID(queueID)
    if type(queue) ~= "table" then
        return nil
    end
    return Queue.BuildRouteRequestForQueue(queue, itemIndex)
end

function Queue.RouteQueueRequest(request)
    if type(request) ~= "table" or type(NS.RouteViaBackend) ~= "function" then
        return false
    end
    return NS.RouteViaBackend(request.mapID, request.x, request.y, request.title, request.meta, {
        authority = "manual",
        queueContext = request.queueContext,
        queueTransaction = request.queueTransaction,
        strictRouteSuccess = true,
    })
end

function Queue.EnsureDestinationQueue(queue)
    if type(queue) ~= "table" then
        return nil
    end
    if queue.kind == "destination_queue" then
        return queue
    end
    queue.kind = "destination_queue"
    queue.readOnly = false
    return queue
end


function Queue.GetActiveNonTransientManualQueue()
    local manualQueues = Queue.GetManualQueueState()
    local queueID = manualQueues.activeQueueID
    if type(queueID) ~= "string" then
        return nil
    end
    return manualQueues.byID[queueID]
end

function Queue.GetCurrentNonTransientManualQueue()
    local record = type(NS.GetManualAuthority) == "function" and NS.GetManualAuthority() or nil
    local queueID = type(record) == "table" and record.queueID or nil
    local queue = type(queueID) == "string" and Queue.GetManualQueueByID(queueID) or nil
    if type(queue) == "table" then
        return queue
    end
    return Queue.GetActiveNonTransientManualQueue()
end


function Queue.FindSingleDestinationManualQueue(mapID, x, y, title, ignoredQueueID)
    local manualQueues = Queue.GetManualQueueState()
    for index = 1, #manualQueues.order do
        local queueID = manualQueues.order[index]
        local queue = manualQueues.byID[queueID]
        if queueID ~= ignoredQueueID
            and type(queue) == "table"
            and type(queue.items) == "table"
            and #queue.items == 1
            and Queue.QueueItemMatchesDestination(queue.items[1], mapID, x, y, title)
        then
            return queue, 1
        end
    end
    return nil
end

function Queue.ActivateAndRouteQueue(queue, itemIndex)
    if type(queue) ~= "table" then
        return false
    end
    itemIndex = tonumber(itemIndex) or tonumber(queue.activeItemIndex) or 1
    local context = Queue.BuildQueueContext(queue, itemIndex)
    local transaction = Queue.CreateQueueTransaction("activate_queue", context, function()
        queue.activeItemIndex = itemIndex
        if queue.sourceType ~= "transient_source" then
            Queue.GetManualQueueState().activeQueueID = queue.id
        end
    end)
    local request = Queue.BuildRouteRequestForQueue(queue, itemIndex)
    if type(request) ~= "table" then
        return false
    end
    request.queueContext = context
    request.queueTransaction = transaction
    return Queue.RouteQueueRequest(request)
end

function Queue.RouteSingleDestinationQueue(mapID, x, y, title, meta, sourceType, ignoredQueueID)
    local existingQueue, existingIndex = Queue.FindSingleDestinationManualQueue(mapID, x, y, title, ignoredQueueID)
    if type(existingQueue) == "table" then
        return Queue.ActivateAndRouteQueue(existingQueue, existingIndex)
    end

    local queue = Queue.CreateSingleDestinationQueue(mapID, x, y, title, meta, sourceType)
    local context = Queue.BuildQueueContext(queue, 1)
    local transaction = Queue.CreateQueueTransaction("add_queue", context, function()
        Queue.AddManualQueue(queue, true)
    end)
    local request = Queue.BuildRouteRequestForQueue(queue, 1)
    if type(request) ~= "table" then
        return false
    end
    request.queueContext = context
    request.queueTransaction = transaction
    return Queue.RouteQueueRequest(request)
end

function Queue.RouteQueueByID(queueID, itemIndex)
    local queue = Queue.GetQueueByID(queueID)
    if type(queue) ~= "table" then
        return false
    end
    itemIndex = tonumber(itemIndex) or queue.activeItemIndex or 1
    local context = Queue.BuildQueueContext(queue, itemIndex)
    local transaction = Queue.CreateQueueTransaction("activate_queue", context, function()
        queue.activeItemIndex = itemIndex
        if queue.sourceType ~= "transient_source" then
            Queue.GetManualQueueState().activeQueueID = queue.id
        end
    end)
    local request = Queue.BuildRouteRequestForQueue(queue, itemIndex)
    if type(request) ~= "table" then
        return false
    end
    request.queueContext = context
    request.queueTransaction = transaction
    return Queue.RouteQueueRequest(request)
end

function Queue.HandleManualClickMode(mode, mapID, x, y, title, meta, sourceType)
    sourceType = sourceType or "manual_click"
    local activeQueue = Queue.GetCurrentNonTransientManualQueue()

    if mode == "replace" and type(activeQueue) == "table" then
        local existingIndex = Queue.FindQueueItemByDestination(activeQueue, mapID, x, y, title)
        if existingIndex and #(activeQueue.items or {}) == 1 then
            return Queue.ActivateAndRouteQueue(activeQueue, existingIndex)
        end
        local existingQueue, duplicateIndex = Queue.FindSingleDestinationManualQueue(mapID, x, y, title, activeQueue.id)
        if type(existingQueue) == "table" then
            local context = Queue.BuildQueueContext(existingQueue, duplicateIndex)
            local transaction = Queue.CreateQueueTransaction("replace_with_existing_queue", context, function()
                Queue.DeleteManualQueue(activeQueue.id)
                existingQueue.activeItemIndex = duplicateIndex or existingQueue.activeItemIndex or 1
                Queue.GetManualQueueState().activeQueueID = existingQueue.id
            end)
            local request = Queue.BuildRouteRequestForQueue(existingQueue, duplicateIndex)
            if type(request) ~= "table" then
                return false
            end
            request.queueContext = context
            request.queueTransaction = transaction
            return Queue.RouteQueueRequest(request)
        end

        local replacementQueue = Queue.CreateSingleDestinationQueue(mapID, x, y, title, meta, sourceType)
        local context = Queue.BuildQueueContext(replacementQueue, 1)
        local transaction = Queue.CreateQueueTransaction("replace_queue", context, function()
            Queue.DeleteManualQueue(activeQueue.id)
            Queue.AddManualQueue(replacementQueue, true)
        end)
        local request = Queue.BuildRouteRequestForQueue(replacementQueue, 1)
        if type(request) ~= "table" then
            return false
        end
        request.queueContext = context
        request.queueTransaction = transaction
        return Queue.RouteQueueRequest(request)
    elseif mode == "append" and type(activeQueue) == "table" then
        local existingIndex = Queue.FindQueueItemByDestination(activeQueue, mapID, x, y, title)
        local record = type(NS.GetManualAuthority) == "function" and NS.GetManualAuthority() or nil
        if type(record) == "table" and record.queueID == activeQueue.id then
            Queue.EnsureDestinationQueue(activeQueue)
            if not existingIndex then
                activeQueue.items[#activeQueue.items + 1] = Queue.BuildQueueItem(mapID, x, y, title, meta, sourceType)
            end
            record.queueKind = activeQueue.kind
            Queue.PersistManualQueues()
            Queue.RefreshQueueUI()
            if type(NS.RecomputeCarrier) == "function" then
                NS.RecomputeCarrier()
            end
            return true
        end

        local routeIndex = tonumber(activeQueue.activeItemIndex) or 1
        local context = Queue.BuildQueueContext(activeQueue, routeIndex)
        context.queueKind = "destination_queue"
        local transaction = Queue.CreateQueueTransaction("append_queue", context, function()
            Queue.EnsureDestinationQueue(activeQueue)
            if not Queue.FindQueueItemByDestination(activeQueue, mapID, x, y, title) then
                activeQueue.items[#activeQueue.items + 1] = Queue.BuildQueueItem(mapID, x, y, title, meta, sourceType)
            end
            activeQueue.activeItemIndex = routeIndex
            Queue.GetManualQueueState().activeQueueID = activeQueue.id
        end)
        local request = Queue.BuildRouteRequestForQueue(activeQueue, routeIndex)
        if type(request) ~= "table" then
            return false
        end
        request.queueContext = context
        request.queueTransaction = transaction
        return Queue.RouteQueueRequest(request)
    end

    return Queue.RouteSingleDestinationQueue(mapID, x, y, title, meta, sourceType)
end

function NS.RouteImportedWaypointBatch(entries)
    if type(entries) ~= "table" or type(entries[1]) ~= "table" then
        return false
    end
    local queue = Queue.CreateDestinationQueue(entries, "imported", entries[1].title)
    if #queue.items == 0 then
        return false
    end
    if #queue.items == 1 then
        local item = queue.items[1]
        local existingQueue, existingIndex = Queue.FindSingleDestinationManualQueue(item.mapID, item.x, item.y, item.title)
        if type(existingQueue) == "table" then
            return Queue.ActivateAndRouteQueue(existingQueue, existingIndex)
        end
    end
    local context = Queue.BuildQueueContext(queue, 1)
    local transaction = Queue.CreateQueueTransaction("add_imported_queue", context, function()
        Queue.AddManualQueue(queue, true)
    end)
    local request = Queue.BuildRouteRequestForQueue(queue, 1)
    if type(request) ~= "table" then
        return false
    end
    request.queueContext = context
    request.queueTransaction = transaction
    return Queue.RouteQueueRequest(request)
end

function NS.PrepareManualQueueRouteRequest(mapID, x, y, title, meta, opts)
    Queue.EnsureQueueState()
    if type(opts) == "table" and type(opts.queueContext) == "table" then
        return opts.queueContext, meta, opts.queueTransaction
    end

    local normalizedMeta = Queue.NormalizeQueueItemMeta(meta, mapID, x, y)
    local sourceType = Queue.InferQueueSourceType(normalizedMeta)
    if type(opts) == "table" and type(opts.clickContext) == "table" then
        sourceType = "manual_click"
    end

    if sourceType == "transient_source" then
        local sourceAddon = Queue.NormalizeSourceAddon(type(normalizedMeta) == "table" and normalizedMeta.sourceAddon or nil)
        local queue = Queue.CreateRouteQueue(mapID, x, y, title, normalizedMeta, "transient_source")
        queue.label = Queue.BuildQueueLabel("route", "transient_source", title or sourceAddon or "Transient Route", queue.id)
        queue.sourceAddon = sourceAddon
        local context = Queue.BuildQueueContext(queue, 1)
        local transaction = Queue.CreateQueueTransaction("push_transient_queue", context, function()
            Queue.PushTransientQueue(queue)
        end)
        return context, Queue.BuildRouteMetaForQueueItem(queue.items[1]), transaction
    end

    local existingQueue, existingIndex = Queue.FindSingleDestinationManualQueue(mapID, x, y, title)
    if type(existingQueue) == "table" then
        existingIndex = existingIndex or existingQueue.activeItemIndex or 1
        local context = Queue.BuildQueueContext(existingQueue, existingIndex)
        local transaction = Queue.CreateQueueTransaction("activate_existing_queue", context, function()
            existingQueue.activeItemIndex = existingIndex
            Queue.GetManualQueueState().activeQueueID = existingQueue.id
        end)
        local existingItem = existingQueue.items[existingIndex]
        return context, Queue.BuildRouteMetaForQueueItem(existingItem), transaction
    end

    local queue = Queue.CreateSingleItemQueue(mapID, x, y, title, normalizedMeta, sourceType)
    local context = Queue.BuildQueueContext(queue, 1)
    local transaction = Queue.CreateQueueTransaction("add_manual_queue", context, function()
        Queue.AddManualQueue(queue, true)
    end)
    return context, Queue.BuildRouteMetaForQueueItem(queue.items[1]), transaction
end

function NS.GetManualQueueArrivalTarget(record)
    if type(record) ~= "table" or type(record.queueID) ~= "string" then
        return nil
    end
    local queue = Queue.GetQueueByID(record.queueID)
    if type(queue) ~= "table" or queue.kind ~= "destination_queue" then
        return nil
    end
    local itemIndex, item = Queue.FindQueueItemIndexForRecord(queue, record, record.queueItemIndex)
    if itemIndex then
        local changed = tonumber(record.queueItemIndex) ~= itemIndex
            or tonumber(queue.activeItemIndex) ~= itemIndex
        record.queueItemIndex = itemIndex
        queue.activeItemIndex = itemIndex
        if changed then
            Queue.PersistManualAuthorityIfAvailable()
            Queue.PersistManualQueues()
            Queue.RefreshQueueUI()
        end
    end
    if type(item) ~= "table" then
        return nil
    end
    return item
end

function NS.RouteQueueByID(queueID, itemIndex)
    return Queue.RouteQueueByID(queueID, itemIndex)
end

function NS.SetActiveManualQueue(queueID)
    local queue = Queue.GetManualQueueByID(queueID)
    if type(queue) ~= "table" then
        return false
    end
    return Queue.RouteQueueByID(queueID, queue.activeItemIndex or 1)
end

function NS.StopUsingManualQueue(queueID)
    local queue = Queue.GetManualQueueByID(queueID)
    if type(queue) ~= "table" then
        return false
    end

    local manualQueues = Queue.GetManualQueueState()
    local record = type(NS.GetManualAuthority) == "function" and NS.GetManualAuthority() or nil
    local isActiveRoute = type(record) == "table" and record.queueID == queueID
    local changed = manualQueues.activeQueueID == queueID

    if changed then
        manualQueues.activeQueueID = nil
        Queue.PersistManualQueues()
    end
    if type(NS.SetActiveRouteSource) == "function" then
        NS.SetActiveRouteSource("guide")
    end

    local clearedRoute = false
    if isActiveRoute then
        if type(NS.ClearManualRoute) == "function" then
            clearedRoute = NS.ClearManualRoute("queue_stop", {
                preserveManualQueue = true,
                queueFollowup = false,
            }) == true
        elseif type(NS.ClearManualAuthority) == "function" then
            NS.ClearManualAuthority("queue_stop")
            clearedRoute = true
        end
    elseif changed and type(NS.RecomputeCarrier) == "function" then
        NS.RecomputeCarrier()
    end

    Queue.RefreshQueueUI()
    return changed or clearedRoute
end

function Queue.BuildDestinationQueueFollowupRequest(queue, itemIndex)
    if type(queue) ~= "table" or type(queue.items) ~= "table" then
        return nil
    end
    itemIndex = tonumber(itemIndex) or tonumber(queue.activeItemIndex) or 1
    local itemCount = #queue.items
    if itemCount <= 1 then
        return nil
    end

    local nextOldIndex = itemIndex < itemCount and itemIndex + 1 or 1
    local nextNewIndex = itemIndex < itemCount and itemIndex or 1
    local nextItem = queue.items[nextOldIndex]
    if type(nextItem) ~= "table" then
        return nil
    end

    local context = Queue.BuildQueueContext(queue, nextNewIndex)
    local transaction = Queue.CreateQueueTransaction("advance_destination_queue", context, function()
        Queue.RemoveQueueItemAt(queue, itemIndex)
        if type(Queue.GetQueueByID(queue.id)) == "table" then
            queue.activeItemIndex = nextNewIndex
            Queue.GetManualQueueState().activeQueueID = queue.id
        end
    end)

    return {
        mapID = nextItem.mapID,
        x = nextItem.x,
        y = nextItem.y,
        title = nextItem.title,
        meta = Queue.BuildRouteMetaForQueueItem(nextItem),
        queueContext = context,
        queueTransaction = transaction,
    }
end

function NS.ResolveManualQueueFollowup(record)
    if type(record) ~= "table" or type(record.queueID) ~= "string" then
        return nil
    end

    local queueID = record.queueID
    local queue = Queue.GetQueueByID(queueID)
    if type(queue) ~= "table" then
        return nil
    end

    if queue.sourceType == "transient_source" then
        Queue.PopTransientQueue(queueID)
        local stack = Queue.GetTransientQueueStack()
        if #stack > 0 then
            return Queue.BuildRouteRequestForQueue(stack[#stack], stack[#stack].activeItemIndex)
        end
        local resumeQueueID = queue.resumeManualQueueID
        if type(resumeQueueID) == "string" then
            return Queue.BuildRouteRequestFromQueueID(resumeQueueID)
        end
        return nil
    end

    if queue.kind == "destination_queue" then
        local itemIndex = Queue.FindQueueItemIndexForRecord(queue, record, record.queueItemIndex)
        if not itemIndex then
            return nil
        end
        record.queueItemIndex = itemIndex
        queue.activeItemIndex = itemIndex
        Queue.PersistManualAuthorityIfAvailable()
        Queue.PersistManualQueues()
        local request = Queue.BuildDestinationQueueFollowupRequest(queue, itemIndex)
        if request then
            return request
        end
        Queue.RemoveQueueItemAt(queue, itemIndex)
        return nil
    end

    Queue.DeleteManualQueue(queueID)
    return nil
end

