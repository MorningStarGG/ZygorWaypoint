local NS = _G.AzerothWaypointNS
local state = NS.State
local Queue = NS.RouteQueueInternal
if type(Queue) ~= "table" then
    Queue = {}
    NS.RouteQueueInternal = Queue
end
function NS.GetQueuePanelSnapshot()
    Queue.EnsureQueueState()
    local manualQueues = Queue.GetManualQueueState()
    local record = type(NS.GetManualAuthority) == "function" and NS.GetManualAuthority() or nil
    local activeManualQueueID = manualQueues.activeQueueID
    if type(record) == "table"
        and type(record.queueID) == "string"
        and type(manualQueues.byID[record.queueID]) == "table"
    then
        activeManualQueueID = record.queueID
    end
    local stack = Queue.GetTransientQueueStack()
    local guideQueues = {}
    local activeGuideQueue = type(Queue.GetActiveGuideQueue) == "function" and Queue.GetActiveGuideQueue() or Queue.GetGuideQueueState()
    if type(Queue.GetGuideQueueList) == "function" then
        local list = Queue.GetGuideQueueList()
        for index = 1, #list do
            guideQueues[#guideQueues + 1] = Queue.DeepCopy(list[index])
        end
    end

    local snapshot = {
        activeManualQueueID = activeManualQueueID,
        activeGuideQueueID = type(activeGuideQueue) == "table" and activeGuideQueue.id or nil,
        selectedKey = state.routing.queueUIState and state.routing.queueUIState.selectedKey or nil,
        guideQueue = Queue.DeepCopy(activeGuideQueue or Queue.GetGuideQueueState()),
        guideQueues = guideQueues,
        manualQueues = {},
        transientQueue = nil,
    }

    for index = 1, #manualQueues.order do
        local queueID = manualQueues.order[index]
        local queue = manualQueues.byID[queueID]
        if type(queue) == "table" then
            snapshot.manualQueues[#snapshot.manualQueues + 1] = Queue.DeepCopy(queue)
        end
    end
    if #stack > 0 then
        snapshot.transientQueue = Queue.DeepCopy(stack[#stack])
    end
    return snapshot
end

function NS.GetQueuePanelSelection()
    Queue.EnsureQueueState()
    return state.routing.queueUIState.selectedKey
end

function NS.SetQueuePanelSelection(selectedKey)
    Queue.EnsureQueueState()
    state.routing.queueUIState.selectedKey = selectedKey
end

function NS.ToggleQueueDetails(queueID)
    local queue = Queue.GetManualQueueByID(queueID) or Queue.GetTransientQueueByID(queueID)
    if type(queue) ~= "table" or queue.kind ~= "destination_queue" then
        return false
    end
    queue.detailsExpanded = queue.detailsExpanded ~= true
    Queue.PersistManualQueues()
    Queue.RefreshQueueUI()
    return queue.detailsExpanded
end

function NS.GetManualQueueList()
    local manualQueues = Queue.GetManualQueueState()
    local list = {}
    for index = 1, #manualQueues.order do
        local queueID = manualQueues.order[index]
        local queue = manualQueues.byID[queueID]
        if type(queue) == "table" then
            list[#list + 1] = queue
        end
    end
    return list
end

function NS.ResolveQueueToken(token)
    token = Queue.TrimString(token)
    if not token then
        local activeQueue, queueType = Queue.ResolveActiveQueueReference()
        if queueType == "guide" then
            return type(activeQueue) == "table" and activeQueue.id or Queue.GetGuideQueueIDForProvider("zygor")
        end
        return type(activeQueue) == "table" and activeQueue.id or Queue.GetManualQueueState().activeQueueID
    end

    if token == "guide" then
        local activeQueue = type(Queue.GetActiveGuideQueue) == "function" and Queue.GetActiveGuideQueue() or nil
        return type(activeQueue) == "table" and activeQueue.id or Queue.GetGuideQueueIDForProvider("zygor")
    end

    if type(Queue.GetGuideProviderFromQueueID) == "function"
        and Queue.GetGuideProviderFromQueueID(token)
        and type(Queue.GetGuideQueueByProvider(Queue.GetGuideProviderFromQueueID(token))) == "table"
    then
        return token
    end

    local manualQueues = Queue.GetManualQueueState()
    local numeric = tonumber(token)
    if numeric and numeric >= 1 and numeric <= #manualQueues.order then
        return manualQueues.order[numeric]
    end

    if manualQueues.byID[token] then
        return token
    end

    local transientQueue = Queue.GetTransientQueueByID(token)
    if type(transientQueue) == "table" then
        return token
    end

    return nil
end

