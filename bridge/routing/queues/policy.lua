local NS = _G.AzerothWaypointNS
local state = NS.State
local Queue = NS.RouteQueueInternal
if type(Queue) ~= "table" then
    Queue = {}
    NS.RouteQueueInternal = Queue
end
function NS.GetManualClickQueueMode()
    local db = type(NS.GetDB) == "function" and NS.GetDB() or nil
    local mode = type(db) == "table" and db.manualClickQueueMode or nil
    if Queue.MANUAL_CLICK_QUEUE_MODES[mode] then
        return mode
    end
    return "create"
end

function NS.SetManualClickQueueMode(value)
    local db = type(NS.GetDB) == "function" and NS.GetDB() or nil
    if type(db) ~= "table" then
        return "create"
    end
    if not Queue.MANUAL_CLICK_QUEUE_MODES[value] then
        value = "create"
    end
    db.manualClickQueueMode = value
    return value
end

function NS.GetManualClickQueueModeOptions()
    return {
        { value = "create", label = "Create new queue" },
        { value = "replace", label = "Replace active" },
        { value = "append", label = "Append" },
        { value = "ask", label = "Ask" },
    }
end

function Queue.ShouldApplyManualClickQueuePolicy(sourceType, opts)
    return sourceType == "manual_click"
        or (type(opts) == "table" and type(opts.clickContext) == "table")
end

function NS.HandleManualQueueRoutingPolicy(mapID, x, y, title, meta, opts)
    if type(opts) == "table" and type(opts.queueContext) == "table" then
        return false
    end

    local normalizedMeta = Queue.NormalizeQueueItemMeta(meta, mapID, x, y)
    local sourceType = Queue.InferQueueSourceType(normalizedMeta)
    if type(opts) == "table" and type(opts.clickContext) == "table" then
        sourceType = "manual_click"
    end
    if sourceType == "transient_source" or not Queue.ShouldApplyManualClickQueuePolicy(sourceType, opts) then
        return false
    end

    local mode = NS.GetManualClickQueueMode()
    if mode == "ask" then
        if type(NS.ShowManualQueuePlacementPrompt) == "function" then
            NS.ShowManualQueuePlacementPrompt({
                mapID = mapID,
                x = x,
                y = y,
                title = title,
                meta = normalizedMeta,
            }, function(choice)
                if choice ~= "create" and choice ~= "replace" and choice ~= "append" then
                    return
                end
                Queue.HandleManualClickMode(choice, mapID, x, y, title, normalizedMeta, "manual_click")
            end)
        else
            Queue.HandleManualClickMode("create", mapID, x, y, title, normalizedMeta, "manual_click")
        end
        return true
    end

    return Queue.HandleManualClickMode(mode, mapID, x, y, title, normalizedMeta, "manual_click")
end

