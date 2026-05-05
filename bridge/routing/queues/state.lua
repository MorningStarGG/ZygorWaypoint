local NS = _G.AzerothWaypointNS
local state = NS.State
local Queue = NS.RouteQueueInternal or {}
NS.RouteQueueInternal = Queue

local Signature = NS.Signature
Queue.TRANSIENT_SOURCE_ADDONS = Queue.TRANSIENT_SOURCE_ADDONS or {}

Queue.MANUAL_CLICK_QUEUE_MODES = {
    create = true,
    replace = true,
    append = true,
    ask = true,
}

function Queue.GetTimeSafe()
    if type(GetTime) == "function" then
        return GetTime()
    end
    return 0
end

function Queue.TrimString(value)
    if type(value) ~= "string" then
        return nil
    end
    value = value:gsub("^%s+", ""):gsub("%s+$", "")
    if value == "" then
        return nil
    end
    return value
end

function Queue.NormalizeSourceAddon(value)
    value = Queue.TrimString(value)
    if not value then
        return nil
    end
    local externalSource = type(NS.NormalizeExternalWaypointSource) == "function"
        and NS.NormalizeExternalWaypointSource(value)
        or nil
    if externalSource then
        return externalSource
    end
    return value
end

function Queue.IsTransientSourceAddon(sourceAddon)
    if type(NS.IsTransientExternalWaypointSource) == "function" and NS.IsTransientExternalWaypointSource(sourceAddon) then
        return true
    end

    sourceAddon = Queue.NormalizeSourceAddon(sourceAddon)
    return sourceAddon ~= nil and Queue.TRANSIENT_SOURCE_ADDONS[sourceAddon] == true
end

local function NormalizeGuideProviderKey(value)
    value = Queue.TrimString(value)
    if not value then
        return nil
    end
    return value:lower()
end

local function BuildGuideQueueID(provider)
    provider = NormalizeGuideProviderKey(provider) or "guide"
    return "guide:" .. provider
end

local function EnsureGuideQueueForRouting(routing, provider, label)
    provider = NormalizeGuideProviderKey(provider) or "zygor"
    routing.guideQueues = routing.guideQueues or {
        order = {},
        byID = {},
        activeProvider = nil,
    }
    routing.guideQueues.order = routing.guideQueues.order or {}
    routing.guideQueues.byID = routing.guideQueues.byID or {}

    local queueID = BuildGuideQueueID(provider)
    local queue = routing.guideQueues.byID[queueID]
    if type(queue) ~= "table" then
        queue = {
            id = queueID,
            kind = "route",
            sourceType = "guide",
            provider = provider,
            label = label or provider,
            readOnly = true,
            items = {},
            projection = nil,
        }
        routing.guideQueues.byID[queueID] = queue
        routing.guideQueues.order[#routing.guideQueues.order + 1] = queueID
    end

    queue.provider = provider
    queue.label = label or queue.label or provider
    queue.readOnly = true
    queue.sourceType = "guide"
    queue.kind = "route"
    queue.items = queue.items or {}
    return queue
end

local function GetGuideQueueByProviderFromRouting(routing, provider)
    provider = NormalizeGuideProviderKey(provider)
    if not provider then
        return nil
    end
    local queues = type(routing) == "table" and routing.guideQueues or nil
    local byID = type(queues) == "table" and queues.byID or nil
    return type(byID) == "table" and byID[BuildGuideQueueID(provider)] or nil
end

local function SetLegacyGuideQueueAlias(routing)
    if type(routing) ~= "table" then
        return nil
    end
    local activeProvider = NormalizeGuideProviderKey(routing.activeGuideProvider)
        or type(routing.guideQueues) == "table" and NormalizeGuideProviderKey(routing.guideQueues.activeProvider)
        or nil
    local queue = GetGuideQueueByProviderFromRouting(routing, activeProvider)
    if type(queue) ~= "table" and type(routing.guideQueues) == "table" and type(routing.guideQueues.order) == "table" then
        for index = 1, #routing.guideQueues.order do
            queue = routing.guideQueues.byID[routing.guideQueues.order[index]]
            if type(queue) == "table" then
                break
            end
        end
    end
    routing.guideQueue = queue
    return queue
end

function Queue.DeepCopy(value)
    if type(value) ~= "table" then
        return value
    end
    local copy = {}
    for key, item in pairs(value) do
        copy[key] = Queue.DeepCopy(item)
    end
    return copy
end

function Queue.GetWaypointSig(mapID, x, y)
    if type(Signature) == "function"
        and type(mapID) == "number"
        and type(x) == "number"
        and type(y) == "number"
    then
        return Signature(mapID, x, y)
    end
    return nil
end

function Queue.SameWaypointCoords(aMapID, aX, aY, bMapID, bX, bY)
    return type(aMapID) == "number"
        and type(aX) == "number"
        and type(aY) == "number"
        and type(bMapID) == "number"
        and type(bX) == "number"
        and type(bY) == "number"
        and aMapID == bMapID
        and math.abs(aX - bX) <= 0.00005
        and math.abs(aY - bY) <= 0.00005
end

function Queue.NormalizeTitleKey(value)
    value = Queue.TrimString(value)
    if not value then
        return ""
    end
    return value:lower()
end

function Queue.EnsureQueueState()
    local routing = state.routing
    routing.manualQueues = routing.manualQueues or {
        order = {},
        byID = {},
        activeQueueID = nil,
        nextID = 1,
    }
    routing.guideQueues = routing.guideQueues or {
        order = {},
        byID = {},
        activeProvider = routing.activeGuideProvider,
    }
    routing.guideRouteStates = routing.guideRouteStates or {}
    if type(routing.guideQueue) == "table"
        and type(routing.guideQueue.provider) == "string"
        and type(routing.guideQueues.order) == "table"
        and #routing.guideQueues.order == 0
    then
        local legacyQueue = routing.guideQueue
        local queue = EnsureGuideQueueForRouting(routing, legacyQueue.provider, legacyQueue.label)
        queue.projection = legacyQueue.projection
        routing.activeGuideProvider = routing.activeGuideProvider or legacyQueue.provider
        routing.guideQueues.activeProvider = routing.guideQueues.activeProvider or legacyQueue.provider
    end
    SetLegacyGuideQueueAlias(routing)
    routing.transientQueueStack = routing.transientQueueStack or {}
    routing.queueUIState = routing.queueUIState or {
        selectedKey = nil,
        detailsByKey = {},
    }
    routing.publishedQueueState = routing.publishedQueueState or {
        queueKey = nil,
        signature = nil,
        uidByEntryKey = {},
    }
    return routing
end

function Queue.GetManualQueueState()
    local routing = Queue.EnsureQueueState()
    return routing.manualQueues
end

function Queue.GetGuideQueueState(provider)
    local routing = Queue.EnsureQueueState()
    provider = NormalizeGuideProviderKey(provider)
    local queue = provider and GetGuideQueueByProviderFromRouting(routing, provider) or SetLegacyGuideQueueAlias(routing)
    return queue or (provider and EnsureGuideQueueForRouting(routing, provider)) or EnsureGuideQueueForRouting(routing, "zygor", "Guide")
end

function NS.SetGuideQueueProvider(key, label)
    local routing = Queue.EnsureQueueState()
    local q = EnsureGuideQueueForRouting(routing, key, label)
    SetLegacyGuideQueueAlias(routing)
    return q
end

function Queue.NormalizeGuideProviderKey(value)
    return NormalizeGuideProviderKey(value)
end

function Queue.GetGuideQueueIDForProvider(provider)
    provider = NormalizeGuideProviderKey(provider)
    return provider and BuildGuideQueueID(provider) or nil
end

function NS.GetGuideQueueIDForProvider(provider)
    return Queue.GetGuideQueueIDForProvider(provider)
end

function Queue.GetGuideProviderFromQueueID(queueID)
    queueID = Queue.TrimString(queueID)
    if not queueID then
        return nil
    end
    return queueID:match("^guide:(.+)$")
end

function NS.GetGuideProviderFromQueueID(queueID)
    return Queue.GetGuideProviderFromQueueID(queueID)
end

function Queue.GetGuideQueueByProvider(provider)
    local routing = Queue.EnsureQueueState()
    return GetGuideQueueByProviderFromRouting(routing, provider)
end

function Queue.EnsureGuideQueue(provider, label)
    local routing = Queue.EnsureQueueState()
    return EnsureGuideQueueForRouting(routing, provider, label)
end

function Queue.GetActiveGuideQueue()
    local routing = Queue.EnsureQueueState()
    local provider = NormalizeGuideProviderKey(routing.activeGuideProvider)
        or type(routing.guideQueues) == "table" and NormalizeGuideProviderKey(routing.guideQueues.activeProvider)
        or nil
    local queue = GetGuideQueueByProviderFromRouting(routing, provider)
    if type(queue) == "table" then
        return queue
    end
    if type(routing.guideQueues.order) == "table" then
        for index = 1, #routing.guideQueues.order do
            queue = routing.guideQueues.byID[routing.guideQueues.order[index]]
            if type(queue) == "table" then
                return queue
            end
        end
    end
    return nil
end

function Queue.SetActiveGuideProvider(provider)
    provider = NormalizeGuideProviderKey(provider)
    local routing = Queue.EnsureQueueState()
    if provider then
        EnsureGuideQueueForRouting(routing, provider)
    end
    routing.activeGuideProvider = provider
    routing.guideQueues.activeProvider = provider
    SetLegacyGuideQueueAlias(routing)
    return provider
end

function Queue.GetGuideQueueList()
    local routing = Queue.EnsureQueueState()
    local list = {}
    if type(routing.guideQueues.order) == "table" then
        for index = 1, #routing.guideQueues.order do
            local queueID = routing.guideQueues.order[index]
            local queue = routing.guideQueues.byID[queueID]
            if type(queue) == "table" then
                list[#list + 1] = queue
            end
        end
    end
    return list
end

function Queue.GetTransientQueueStack()
    local routing = Queue.EnsureQueueState()
    return routing.transientQueueStack
end

function Queue.RefreshQueueUI()
    if type(NS.RefreshQueuePanel) == "function" then
        NS.RefreshQueuePanel()
    end
end

function Queue.AllocateQueueID(prefix)
    local manualQueues = Queue.GetManualQueueState()
    local id = string.format("%s%d", prefix or "q", tonumber(manualQueues.nextID) or 1)
    manualQueues.nextID = (tonumber(manualQueues.nextID) or 1) + 1
    return id
end


function Queue.FindManualQueueIndex(queueID)
    local manualQueues = Queue.GetManualQueueState()
    for index = 1, #manualQueues.order do
        if manualQueues.order[index] == queueID then
            return index
        end
    end
    return nil
end

function Queue.GetManualQueueByID(queueID)
    local manualQueues = Queue.GetManualQueueState()
    if type(queueID) ~= "string" then
        return nil
    end
    return manualQueues.byID[queueID]
end

function Queue.GetTransientQueueByID(queueID)
    local stack = Queue.GetTransientQueueStack()
    for index = 1, #stack do
        local queue = stack[index]
        if type(queue) == "table" and queue.id == queueID then
            return queue, index
        end
    end
    return nil, nil
end

function Queue.GetQueueByID(queueID)
    return Queue.GetManualQueueByID(queueID)
        or Queue.GetTransientQueueByID(queueID)
end

function Queue.GetAnyQueueByID(queueID)
    return Queue.GetQueueByID(queueID)
        or (type(queueID) == "string" and Queue.GetGuideProviderFromQueueID(queueID) and Queue.GetGuideQueueByProvider(Queue.GetGuideProviderFromQueueID(queueID)) or nil)
end

function Queue.PersistManualQueues()
    local db = type(NS.GetDB) == "function" and NS.GetDB() or nil
    if type(db) ~= "table" then
        return
    end

    local routing = Queue.EnsureQueueState()
    local manualQueues = routing.manualQueues
    if routing.manualQueuesHydrated ~= true
        and type(db.manualQueues) == "table"
        and type(manualQueues.order) == "table"
        and #manualQueues.order == 0
        and manualQueues.activeQueueID == nil
    then
        return
    end

    local saved = {
        nextID = manualQueues.nextID,
        activeQueueID = manualQueues.activeQueueID,
        order = {},
        byID = {},
    }

    for index = 1, #manualQueues.order do
        local queueID = manualQueues.order[index]
        local queue = manualQueues.byID[queueID]
        if type(queue) == "table" then
            saved.order[#saved.order + 1] = queueID
            local queueCopy = {
                id = queue.id,
                kind = queue.kind,
                sourceType = queue.sourceType,
                label = queue.label,
                createdAt = queue.createdAt,
                activeItemIndex = queue.activeItemIndex,
                detailsExpanded = queue.detailsExpanded == true or nil,
                items = {},
            }
            for itemIndex = 1, #(queue.items or {}) do
                local item = queue.items[itemIndex]
                local itemMeta = type(item) == "table" and Queue.BuildRouteMetaForQueueItem(item) or nil
                if type(item) == "table"
                    and type(NS.ValidateRouteMeta) == "function"
                    and NS.ValidateRouteMeta(itemMeta)
                then
                    queueCopy.items[#queueCopy.items + 1] = {
                        mapID = item.mapID,
                        x = item.x,
                        y = item.y,
                        title = item.title,
                        sig = item.sig,
                        sourceType = item.sourceType,
                        meta = itemMeta,
                    }
                end
            end
            if #queueCopy.items > 0 then
                saved.byID[queueID] = queueCopy
            else
                saved.order[#saved.order] = nil
            end
        end
    end
    if type(saved.activeQueueID) == "string" and type(saved.byID[saved.activeQueueID]) ~= "table" then
        saved.activeQueueID = nil
    end

    db.manualQueues = saved
end

function Queue.AddManualQueue(queue, makeActive)
    if type(queue) ~= "table" or type(queue.id) ~= "string" then
        return nil
    end
    local manualQueues = Queue.GetManualQueueState()
    manualQueues.byID[queue.id] = queue
    if not Queue.FindManualQueueIndex(queue.id) then
        manualQueues.order[#manualQueues.order + 1] = queue.id
    end
    if makeActive ~= false then
        manualQueues.activeQueueID = queue.id
    end
    Queue.PersistManualQueues()
    Queue.RefreshQueueUI()
    return queue
end

function Queue.DeleteManualQueue(queueID)
    local manualQueues = Queue.GetManualQueueState()
    local index = Queue.FindManualQueueIndex(queueID)
    if index then
        table.remove(manualQueues.order, index)
    end
    manualQueues.byID[queueID] = nil
    if manualQueues.activeQueueID == queueID then
        manualQueues.activeQueueID = nil
    end
    Queue.PersistManualQueues()
    Queue.RefreshQueueUI()
end

function Queue.PushTransientQueue(queue)
    if type(queue) ~= "table" then
        return nil
    end
    local stack = Queue.GetTransientQueueStack()
    local top = stack[#stack]
    local manualQueues = Queue.GetManualQueueState()
    local record = type(NS.GetManualAuthority) == "function" and NS.GetManualAuthority() or nil
    local activeQueueID = type(record) == "table"
        and type(record.queueID) == "string"
        and manualQueues.byID[record.queueID]
        and record.queueID
        or manualQueues.activeQueueID
    queue.resumeManualQueueID = top == nil and activeQueueID or nil
    stack[#stack + 1] = queue
    return queue
end

function Queue.PopTransientQueue(queueID)
    local stack = Queue.GetTransientQueueStack()
    if #stack == 0 then
        return nil
    end
    if type(queueID) ~= "string" or stack[#stack].id == queueID then
        return table.remove(stack)
    end
    for index = #stack, 1, -1 do
        if stack[index].id == queueID then
            return table.remove(stack, index)
        end
    end
    return nil
end

function Queue.BuildQueueContext(queue, itemIndex)
    if type(queue) ~= "table" then
        return nil
    end
    return {
        queueID = queue.id,
        queueKind = queue.kind,
        queueSourceType = queue.sourceType,
        queueItemIndex = itemIndex or queue.activeItemIndex or 1,
        queueIsTransient = queue.sourceType == "transient_source",
        strictRouteSuccess = true,
    }
end

function Queue.CreateQueueTransaction(label, queueContext, commitFn, rollbackFn)
    if type(queueContext) == "table" then
        queueContext.strictRouteSuccess = true
    end
    return {
        label = label,
        queueContext = queueContext,
        strictRouteSuccess = true,
        commit = commitFn,
        rollback = rollbackFn,
    }
end

function Queue.CommitQueueTransaction(transaction, record)
    if type(transaction) ~= "table" then
        return false
    end
    if type(transaction.commit) == "function" then
        transaction.commit(record)
    end
    Queue.PersistManualQueues()
    Queue.RefreshQueueUI()
    return true
end

function Queue.RollbackQueueTransaction(transaction, record, outcome, reason)
    if type(transaction) ~= "table" then
        return false
    end
    if type(transaction.rollback) == "function" then
        transaction.rollback(record, outcome, reason)
    end
    Queue.RefreshQueueUI()
    return true
end

function NS.CommitPendingManualQueueTransaction(record)
    local transaction = type(record) == "table" and record._corePendingQueueTransaction or nil
    if type(record) == "table" then
        record._corePendingQueueTransaction = nil
    end
    return Queue.CommitQueueTransaction(transaction, record)
end

function NS.RollbackPendingManualQueueTransaction(record, outcome, reason)
    local transaction = type(record) == "table" and record._corePendingQueueTransaction or nil
    if type(record) == "table" then
        record._corePendingQueueTransaction = nil
    end
    return Queue.RollbackQueueTransaction(transaction, record, outcome, reason)
end

function Queue.AddQueueRestoreCandidate(candidates, seen, queueID)
    if type(queueID) ~= "string" or seen[queueID] then
        return
    end
    seen[queueID] = true
    candidates[#candidates + 1] = queueID
end

function Queue.ResolveSavedActiveQueueRoute(saved, manualQueues, record)
    if type(saved) ~= "table"
        or type(manualQueues) ~= "table"
        or type(record) ~= "table"
        or type(record.mapID) ~= "number"
        or type(record.x) ~= "number"
        or type(record.y) ~= "number"
    then
        return nil, nil
    end

    local candidates = {}
    local seen = {}
    Queue.AddQueueRestoreCandidate(candidates, seen, record.queueID)
    Queue.AddQueueRestoreCandidate(candidates, seen, manualQueues.activeQueueID)
    Queue.AddQueueRestoreCandidate(candidates, seen, saved.activeQueueID)

    for index = 1, #candidates do
        local queueID = candidates[index]
        local queue = manualQueues.byID[queueID]
        if type(queue) == "table" then
            local itemIndex = tonumber(record.queueItemIndex) or tonumber(queue.activeItemIndex) or 1
            if Queue.QueueItemMatchesDestination(queue.items and queue.items[itemIndex], record.mapID, record.x, record.y, record.title) then
                return queueID, itemIndex
            end

            local matchedIndex = Queue.FindQueueItemByDestination(queue, record.mapID, record.x, record.y, record.title)
            if matchedIndex then
                return queueID, matchedIndex
            end
        end
    end

    return nil, nil
end

function NS.HydrateManualQueues()
    local db = type(NS.GetDB) == "function" and NS.GetDB() or nil
    if type(db) ~= "table" then
        return false
    end

    local saved = db.manualQueues
    local routing = Queue.EnsureQueueState()
    local manualQueues = routing.manualQueues
    if type(saved) ~= "table" then
        routing.manualQueuesHydrated = true
        return false
    end

    manualQueues.order = {}
    manualQueues.byID = {}
    manualQueues.activeQueueID = nil
    manualQueues.nextID = tonumber(saved.nextID) or 1
    local prunedDuplicateQueues = false
    local prunedInvalidQueues = false

    if type(saved.order) ~= "table" or type(saved.byID) ~= "table" then
        db.manualQueues = nil
        routing.manualQueuesHydrated = true
        return false
    end

    routing.manualQueuesHydrated = true

    for index = 1, #saved.order do
        local queueID = saved.order[index]
        local savedQueue = saved.byID[queueID]
        if type(savedQueue) == "table" and type(savedQueue.items) == "table" and #savedQueue.items > 0 then
            local savedItemCount = #savedQueue.items
            local queue = {
                id = savedQueue.id or queueID,
                kind = savedQueue.kind == "destination_queue" and "destination_queue" or "route",
                sourceType = savedQueue.sourceType or "manual",
                label = savedQueue.label or Queue.BuildQueueLabel(savedQueue.kind, savedQueue.sourceType, nil, queueID),
                createdAt = savedQueue.createdAt,
                readOnly = savedQueue.kind ~= "destination_queue",
                items = {},
                activeItemIndex = tonumber(savedQueue.activeItemIndex) or 1,
                projection = nil,
                detailsExpanded = savedQueue.detailsExpanded == true,
            }
            for itemIndex = 1, #savedQueue.items do
                local item = savedQueue.items[itemIndex]
                local itemMeta = type(item) == "table" and item.meta or nil
                if type(itemMeta) == "table"
                    and (type(NS.ValidateRouteMeta) ~= "function" or not NS.ValidateRouteMeta(itemMeta))
                    and type(itemMeta.identity) == "table"
                then
                    itemMeta = NS.BuildRouteMeta(itemMeta.identity, {
                        sourceAddon = itemMeta.sourceAddon,
                        searchKind = itemMeta.searchKind,
                        manualQuestID = itemMeta.manualQuestID,
                        mapPinInfo = itemMeta.mapPinInfo,
                    })
                end
                if type(item) == "table"
                    and type(item.mapID) == "number"
                    and type(item.x) == "number"
                    and type(item.y) == "number"
                    and type(NS.ValidateRouteMeta) == "function"
                    and NS.ValidateRouteMeta(itemMeta)
                then
                    queue.items[#queue.items + 1] = {
                        mapID = item.mapID,
                        x = item.x,
                        y = item.y,
                        title = item.title,
                        sig = item.sig or Queue.GetWaypointSig(item.mapID, item.x, item.y),
                        sourceType = item.sourceType or queue.sourceType,
                        meta = Queue.DeepCopy(itemMeta),
                    }
                else
                    prunedInvalidQueues = true
                end
            end
            if #queue.items ~= savedItemCount then
                prunedInvalidQueues = true
            end
            if queue.kind ~= "destination_queue" and Queue.ShouldCreateDestinationQueue(queue.sourceType, queue.items[1] and queue.items[1].meta) then
                queue.kind = "destination_queue"
                queue.readOnly = false
            end
            if #queue.items > 0 then
                local duplicateQueue = nil
                if #queue.items == 1 then
                    local item = queue.items[1]
                    duplicateQueue = Queue.FindSingleDestinationManualQueue(item.mapID, item.x, item.y, item.title)
                end
                if type(duplicateQueue) == "table" then
                    prunedDuplicateQueues = true
                    if saved.activeQueueID == queue.id then
                        manualQueues.activeQueueID = duplicateQueue.id
                    end
                else
                    manualQueues.order[#manualQueues.order + 1] = queue.id
                    manualQueues.byID[queue.id] = queue
                end
            else
                prunedInvalidQueues = true
            end
        else
            prunedInvalidQueues = true
        end
    end

    if type(saved.activeQueueID) == "string" and manualQueues.byID[saved.activeQueueID] then
        manualQueues.activeQueueID = saved.activeQueueID
    end
    if type(saved.activeQueueID) == "string" and not manualQueues.byID[saved.activeQueueID] then
        prunedInvalidQueues = true
    end
    if prunedDuplicateQueues or prunedInvalidQueues then
        Queue.PersistManualQueues()
    end

    Queue.RefreshQueueUI()
    return true
end

function NS.RestoreManualQueues(opts)
    local db = type(NS.GetDB) == "function" and NS.GetDB() or nil
    if type(db) ~= "table" or type(db.manualQueues) ~= "table" then
        return false
    end

    opts = type(opts) == "table" and opts or {}
    if opts.skipHydrate ~= true and not NS.HydrateManualQueues() then
        return false
    end

    local saved = db.manualQueues
    local manualQueues = Queue.GetManualQueueState()
    local restoreQueueID, restoreItemIndex = Queue.ResolveSavedActiveQueueRoute(saved, manualQueues, db.manualAuthority)
    if not restoreQueueID and opts.allowActiveQueueFallback == true then
        local activeQueueID = type(manualQueues.activeQueueID) == "string" and manualQueues.activeQueueID
            or type(saved.activeQueueID) == "string" and saved.activeQueueID
            or nil
        local activeQueue = activeQueueID and manualQueues.byID[activeQueueID] or nil
        if type(activeQueue) == "table" then
            restoreQueueID = activeQueueID
            restoreItemIndex = tonumber(activeQueue.activeItemIndex) or 1
        end
    end
    if type(restoreQueueID) == "string" and type(NS.RouteViaBackend) == "function" then
        manualQueues.activeQueueID = restoreQueueID
        return Queue.RouteQueueByID(restoreQueueID, restoreItemIndex)
    end
    return false
end

