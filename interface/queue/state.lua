local NS = _G.AzerothWaypointNS
NS.Internal = NS.Internal or {}
NS.Internal.QueueUI = NS.Internal.QueueUI or {}
local M = NS.Internal.QueueUI
local state = NS.State

M.ui = M.ui or {
    active = false,
    callbacksRegistered = false,
    rowHeight = 22,
    maxTabsPerColumn = 8,
}

M.SECTION_ORDER = { "transient", "manual", "guide" }
M.SECTION_LABELS = {
    transient = "Transient",
    manual = "Manual Queues",
    guide = "User Guides",
}
M.QUEUE_TYPE_LABELS = {
    transient = "Transient",
    manual = "Manual",
    guide = "User Guides",
}

function M.GetQueueUIState()
    state.routing = state.routing or {}
    state.routing.queueUIState = state.routing.queueUIState or {}
    state.routing.queueUIState.collapsedSections = state.routing.queueUIState.collapsedSections or {}
    state.routing.queueUIState.detailCollapsed = state.routing.queueUIState.detailCollapsed or {}
    state.routing.queueUIState.selectedQueues = state.routing.queueUIState.selectedQueues or {}
    state.routing.queueUIState.selectedItems = state.routing.queueUIState.selectedItems or {}
    return state.routing.queueUIState
end

function M.IsQueueBulkSelectable(queueType)
    return queueType == "manual" or queueType == "transient"
end

function M.IsGuideQueueKey(queueKey)
    return type(queueKey) == "string" and (queueKey == "guide" or queueKey:match("^guide:") ~= nil)
end

function M.IsQueueSelected(queueKey)
    local uiState = M.GetQueueUIState()
    return type(queueKey) == "string" and uiState.selectedQueues[queueKey] == true
end

function M.SetQueueSelected(queueKey, selected)
    if type(queueKey) ~= "string" or M.IsGuideQueueKey(queueKey) then
        return false
    end
    local uiState = M.GetQueueUIState()
    uiState.selectedQueues[queueKey] = selected == true or nil
    return true
end

function M.IsQueueItemSelected(queueKey, itemIndex)
    local uiState = M.GetQueueUIState()
    local selectedItems = type(queueKey) == "string" and uiState.selectedItems[queueKey] or nil
    return type(selectedItems) == "table" and selectedItems[tonumber(itemIndex)] == true
end

function M.SetQueueItemSelected(queueKey, itemIndex, selected)
    itemIndex = tonumber(itemIndex)
    if type(queueKey) ~= "string" or M.IsGuideQueueKey(queueKey) or not itemIndex then
        return false
    end
    local uiState = M.GetQueueUIState()
    local selectedItems = uiState.selectedItems[queueKey]
    if type(selectedItems) ~= "table" then
        selectedItems = {}
        uiState.selectedItems[queueKey] = selectedItems
    end
    selectedItems[itemIndex] = selected == true or nil
    if next(selectedItems) == nil then
        uiState.selectedItems[queueKey] = nil
    end
    return true
end

function M.ClearQueueItemSelection(queueKey)
    local uiState = M.GetQueueUIState()
    if type(queueKey) == "string" then
        uiState.selectedItems[queueKey] = nil
    end
end

function M.GetDetailCollapseKey(queueKey, sectionKey)
    return tostring(queueKey or "none") .. ":" .. tostring(sectionKey or "none")
end

function M.IsDetailSectionCollapsed(queueKey, sectionKey)
    local uiState = M.GetQueueUIState()
    return uiState.detailCollapsed[M.GetDetailCollapseKey(queueKey, sectionKey)] == true
end

function M.SetDetailSectionCollapsed(queueKey, sectionKey, collapsed)
    local uiState = M.GetQueueUIState()
    local key = M.GetDetailCollapseKey(queueKey, sectionKey)
    uiState.detailCollapsed[key] = collapsed == true or nil
end

function M.GetViewMode()
    local uiState = M.GetQueueUIState()
    return uiState.viewMode == "detail" and "detail" or "list"
end

function M.SetViewMode(viewMode)
    local uiState = M.GetQueueUIState()
    uiState.viewMode = viewMode == "detail" and "detail" or "list"
end

function M.IsSectionCollapsed(sectionKey)
    local uiState = M.GetQueueUIState()
    local collapsed = uiState.collapsedSections or {}
    return collapsed[sectionKey] == true
end

function M.SetSectionCollapsed(sectionKey, collapsed)
    local uiState = M.GetQueueUIState()
    uiState.collapsedSections[sectionKey] = collapsed == true or nil
end

function M.GetSelectedQueueIDs()
    local uiState = M.GetQueueUIState()
    local ids = {}
    for queueKey, selected in pairs(uiState.selectedQueues) do
        if selected == true and type(queueKey) == "string" and not M.IsGuideQueueKey(queueKey) then
            ids[#ids + 1] = queueKey
        end
    end
    table.sort(ids)
    return ids
end

function M.GetSelectedQueueItemIndexes(queueKey)
    local uiState = M.GetQueueUIState()
    local selectedItems = type(queueKey) == "string" and uiState.selectedItems[queueKey] or nil
    local indexes = {}
    if type(selectedItems) ~= "table" then
        return indexes
    end
    for itemIndex, selected in pairs(selectedItems) do
        local index = tonumber(itemIndex)
        if selected == true and index then
            indexes[#indexes + 1] = index
        end
    end
    table.sort(indexes)
    return indexes
end
