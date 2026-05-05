local NS = _G.AzerothWaypointNS
NS.Internal = NS.Internal or {}
NS.Internal.QueueUI = NS.Internal.QueueUI or {}
local M = NS.Internal.QueueUI
-- M.Refresh is assigned by panel.lua later in TOC order. These functions are
-- registered as callbacks and only run after every queue UI module has loaded.

function M.SelectQueue(key)
    if type(NS.SetQueuePanelSelection) == "function" then
        NS.SetQueuePanelSelection(key)
    end
end

function M.ActivateQueueDestination(queueID, itemIndex)
    itemIndex = tonumber(itemIndex)
    if type(queueID) ~= "string" or not itemIndex or type(NS.RouteQueueByID) ~= "function" then
        return false
    end
    return NS.RouteQueueByID(queueID, itemIndex)
end

local function CenterMapCanvas()
    return type(M.CenterMapCanvas) == "function" and M.CenterMapCanvas() or false
end

function M.FocusQueueFinalDestination(queue)
    local finalEntry = M.GetQueueFinalEntry(queue)
    if type(finalEntry) ~= "table" or type(finalEntry.mapID) ~= "number" then
        return false
    end

    local questMapFrame = type(M.EnsureWorldMapLoaded) == "function" and M.EnsureWorldMapLoaded() or nil
    local mapFrame = type(M.GetMapCanvasFrame) == "function" and M.GetMapCanvasFrame() or nil
    if not questMapFrame or not mapFrame or type(mapFrame.SetMapID) ~= "function" then
        return false
    end

    local mapID = finalEntry.mapID
    mapFrame:SetMapID(mapID)

    CenterMapCanvas()
    if type(C_Timer) == "table" and type(C_Timer.After) == "function" then
        C_Timer.After(0, CenterMapCanvas)
    end
    return true
end

function M.IsQueueUsableFromList(queueType)
    return queueType == "manual" or queueType == "guide"
end

function M.IsQueueClearableFromList(queueType)
    return queueType == "manual" or queueType == "transient"
end

function M.IsQueueDetailsToggleable(queue, queueType)
    return false
end

function M.OpenQueueDetails(queueKey)
    if type(queueKey) ~= "string" then
        return false
    end
    M.SelectQueue(queueKey)
    M.SetViewMode("detail")
    M.Refresh()
    return true
end

function M.UseQueueByKey(queueKey)
    if type(queueKey) ~= "string" then
        return false
    end
    if M.IsGuideQueueKey(queueKey) then
        if type(NS.ActivateGuideQueueByID) ~= "function" then
            return false
        end
        M.SelectQueue(queueKey)
        local ok = NS.ActivateGuideQueueByID(queueKey, "queue_ui")
        M.Refresh()
        return ok == true
    end
    if type(NS.SetActiveManualQueue) ~= "function" then
        return false
    end
    M.SelectQueue(queueKey)
    NS.SetActiveManualQueue(queueKey)
    M.Refresh()
    return true
end

function M.IsManualQueueActive(queueKey, snapshot)
    if type(queueKey) ~= "string" or M.IsGuideQueueKey(queueKey) then
        return false
    end

    local record = type(NS.GetManualAuthority) == "function" and NS.GetManualAuthority() or nil
    if type(record) == "table" then
        return record.queueID == queueKey
    end

    if type(snapshot) == "table" and snapshot.activeManualQueueID == queueKey then
        return true
    end

    if type(snapshot) == "table" then
        return false
    end

    snapshot = type(NS.GetQueuePanelSnapshot) == "function" and NS.GetQueuePanelSnapshot() or nil
    return type(snapshot) == "table" and snapshot.activeManualQueueID == queueKey
end

function M.StopUsingQueueByKey(queueKey)
    if type(queueKey) ~= "string" or M.IsGuideQueueKey(queueKey) or type(NS.StopUsingManualQueue) ~= "function" then
        return false
    end
    M.SelectQueue(queueKey)
    NS.StopUsingManualQueue(queueKey)
    M.Refresh()
    return true
end

function M.ToggleQueueUseByKey(queueKey)
    if M.IsManualQueueActive(queueKey) then
        return M.StopUsingQueueByKey(queueKey)
    end
    return M.UseQueueByKey(queueKey)
end

function M.ClearQueueByKey(queueKey)
    if type(queueKey) ~= "string" or M.IsGuideQueueKey(queueKey) or type(NS.ClearQueueByID) ~= "function" then
        return false
    end

    local selectedKey = type(NS.GetQueuePanelSelection) == "function" and NS.GetQueuePanelSelection() or nil
    NS.ClearQueueByID(queueKey)
    if selectedKey == queueKey then
        if type(NS.SetQueuePanelSelection) == "function" then
            NS.SetQueuePanelSelection(nil)
        end
        M.SetViewMode("list")
    end
    M.Refresh()
    return true
end

function M.RemoveQueueDestination(queueKey, itemIndex)
    itemIndex = tonumber(itemIndex)
    if type(queueKey) ~= "string" or M.IsGuideQueueKey(queueKey) or not itemIndex or type(NS.RemoveQueueItem) ~= "function" then
        return false
    end

    NS.RemoveQueueItem(queueKey, itemIndex)
    M.Refresh()
    return true
end

function M.DeleteSelectedQueues()
    local queueIDs = M.GetSelectedQueueIDs()
    if #queueIDs == 0 or type(NS.ClearQueuesByID) ~= "function" then
        return false
    end

    local selectedKey = type(NS.GetQueuePanelSelection) == "function" and NS.GetQueuePanelSelection() or nil
    NS.ClearQueuesByID(queueIDs)
    local uiState = M.GetQueueUIState()
    for index = 1, #queueIDs do
        uiState.selectedQueues[queueIDs[index]] = nil
        uiState.selectedItems[queueIDs[index]] = nil
        if selectedKey == queueIDs[index] and type(NS.SetQueuePanelSelection) == "function" then
            NS.SetQueuePanelSelection(nil)
            M.SetViewMode("list")
        end
    end
    M.Refresh()
    return true
end

function M.DeleteSelectedQueueItems(queueKey)
    local itemIndexes = M.GetSelectedQueueItemIndexes(queueKey)
    if type(queueKey) ~= "string" or #itemIndexes == 0 or type(NS.RemoveQueueItems) ~= "function" then
        return false
    end

    NS.RemoveQueueItems(queueKey, itemIndexes)
    M.ClearQueueItemSelection(queueKey)
    M.Refresh()
    return true
end

function M.ToggleQueueDetailsByKey(queueKey)
    if type(queueKey) ~= "string" or M.IsGuideQueueKey(queueKey) or type(NS.ToggleQueueDetails) ~= "function" then
        return false
    end
    NS.ToggleQueueDetails(queueKey)
    M.Refresh()
    return true
end

function M.OpenImportWindow()
    if type(NS.OpenTomTomPasteWindow) == "function" then
        return NS.OpenTomTomPasteWindow()
    end
    if type(NS.Msg) == "function" then
        NS.Msg("TomTom paste window is unavailable.")
    end
    return false
end

function M.ShowQueueDestinationContextMenu(owner, rowTitle, queueKey, itemIndex, removable)
    itemIndex = tonumber(itemIndex)
    if type(queueKey) ~= "string" or M.IsGuideQueueKey(queueKey) or not itemIndex then
        return false
    end

    if type(MenuUtil) == "table" and type(MenuUtil.CreateContextMenu) == "function" then
        MenuUtil.CreateContextMenu(owner, function(_, rootDescription)
            if type(rootDescription.CreateTitle) == "function" then
                rootDescription:CreateTitle(tostring(rowTitle or "Queued Destination"))
            end

            M.CreateContextMenuButton(rootDescription, "Switch to this Destination", function()
                M.ActivateQueueDestination(queueKey, itemIndex)
                M.Refresh()
            end)

            if removable then
                M.AddContextMenuDivider(rootDescription)
                M.CreateContextMenuButton(rootDescription, "Remove Destination", function()
                    M.RemoveQueueDestination(queueKey, itemIndex)
                end)
            end
        end)
        return true
    end

    return false
end


function M.ShowQueueRowContextMenu(owner, queue, queueType, queueKey)
    if type(queueKey) ~= "string" or type(queue) ~= "table" then
        return false
    end

    M.SelectQueue(queueKey)
    M.Refresh()

    if type(MenuUtil) == "table" and type(MenuUtil.CreateContextMenu) == "function" then
        MenuUtil.CreateContextMenu(owner, function(_, rootDescription)
            if type(rootDescription.CreateTitle) == "function" then
                rootDescription:CreateTitle(tostring(queue.label or queueKey or "Queue"))
            end

            M.CreateContextMenuButton(rootDescription, "Open Queue", function()
                M.OpenQueueDetails(queueKey)
            end)

            if M.IsQueueUsableFromList(queueType) then
                if M.IsManualQueueActive(queueKey) then
                    M.CreateContextMenuButton(rootDescription, "Deactivate Queue", function()
                        M.StopUsingQueueByKey(queueKey)
                    end)
                else
                    M.CreateContextMenuButton(rootDescription, "Activate Queue", function()
                        M.UseQueueByKey(queueKey)
                    end)
                end
            end

            if M.IsQueueDetailsToggleable(queue, queueType) then
                M.CreateContextMenuButton(rootDescription,
                    queue.detailsExpanded and "Hide Route Details" or "Show Route Details",
                    function()
                        M.ToggleQueueDetailsByKey(queueKey)
                    end)
            end

            if type(M.GetQueueFinalEntry(queue)) == "table" then
                M.CreateContextMenuButton(rootDescription, "Show Final Destination", function()
                    M.FocusQueueFinalDestination(queue)
                end)
            end

            if M.IsQueueClearableFromList(queueType) then
                M.AddContextMenuDivider(rootDescription)
                M.CreateContextMenuButton(rootDescription, "Clear Queue", function()
                    M.ClearQueueByKey(queueKey)
                end)
            end
        end)
        return true
    end

    return false
end
