local NS = _G.AzerothWaypointNS
NS.Internal = NS.Internal or {}
NS.Internal.QueueUI = NS.Internal.QueueUI or {}
local M = NS.Internal.QueueUI
local QUEUE_ICON_OPTS_MANUAL = { kind = "manual" }
local QUEUE_ICON_OPTS_ROUTE = { kind = "route" }
local _guideRouteIconOptsByProvider = {}

local function GetNativeOverlay()
    return NS.Internal and NS.Internal.WorldOverlay or nil
end

function M.IsGuideQueueAvailable(queue)
    local projection = type(queue) == "table" and queue.projection or nil
    local entries = projection and projection.entries or nil
    return type(entries) == "table" and #entries > 0
end

local function FindGuideQueueByKey(snapshot, selectedKey)
    if type(snapshot) ~= "table" or type(selectedKey) ~= "string" then
        return nil
    end
    if selectedKey == "guide" then
        selectedKey = snapshot.activeGuideQueueID
    end
    if type(snapshot.guideQueues) == "table" then
        for index = 1, #snapshot.guideQueues do
            local queue = snapshot.guideQueues[index]
            if type(queue) == "table" and queue.id == selectedKey and M.IsGuideQueueAvailable(queue) then
                return queue
            end
        end
    end
    if selectedKey == (snapshot.guideQueue and snapshot.guideQueue.id) and M.IsGuideQueueAvailable(snapshot.guideQueue) then
        return snapshot.guideQueue
    end
    return nil
end

function M.FindQueueByKey(snapshot, selectedKey)
    if type(snapshot) ~= "table" or type(selectedKey) ~= "string" then
        return nil, nil
    end
    local guideQueue = FindGuideQueueByKey(snapshot, selectedKey)
    if type(guideQueue) == "table" then
        return guideQueue, "guide"
    end
    if type(snapshot.transientQueue) == "table" and snapshot.transientQueue.id == selectedKey then
        return snapshot.transientQueue, "transient"
    end
    if type(snapshot.manualQueues) == "table" then
        for index = 1, #snapshot.manualQueues do
            local queue = snapshot.manualQueues[index]
            if type(queue) == "table" and queue.id == selectedKey then
                return queue, "manual"
            end
        end
    end
    return nil, nil
end

function M.ResolveSelectedQueue(snapshot)
    if type(snapshot) ~= "table" then
        return nil, nil
    end

    local selectedKey = type(NS.GetQueuePanelSelection) == "function" and NS.GetQueuePanelSelection() or nil
    local selectedQueue, queueType = M.FindQueueByKey(snapshot, selectedKey)
    if type(selectedQueue) == "table" then
        return selectedQueue, queueType
    end
    if type(snapshot.transientQueue) == "table" then
        return snapshot.transientQueue, "transient"
    end
    if type(snapshot.manualQueues) == "table" then
        for index = 1, #snapshot.manualQueues do
            local queue = snapshot.manualQueues[index]
            if type(queue) == "table" and queue.id == snapshot.activeManualQueueID then
                return queue, "manual"
            end
        end
        if type(snapshot.manualQueues[1]) == "table" then
            return snapshot.manualQueues[1], "manual"
        end
    end
    local activeGuideQueue = FindGuideQueueByKey(snapshot, snapshot.activeGuideQueueID)
    if type(activeGuideQueue) == "table" then
        return activeGuideQueue, "guide"
    end
    if type(snapshot.guideQueues) == "table" then
        for index = 1, #snapshot.guideQueues do
            local queue = snapshot.guideQueues[index]
            if M.IsGuideQueueAvailable(queue) then
                return queue, "guide"
            end
        end
    end
    if M.IsGuideQueueAvailable(snapshot.guideQueue) then
        return snapshot.guideQueue, "guide"
    end
    return nil, nil
end

function M.PruneBulkSelections(snapshot)
    local uiState = M.GetQueueUIState()
    local validQueues = {}
    local manualQueuesByID = {}

    if type(snapshot) == "table" then
        if type(snapshot.transientQueue) == "table" and type(snapshot.transientQueue.id) == "string" then
            validQueues[snapshot.transientQueue.id] = true
        end
        if type(snapshot.manualQueues) == "table" then
            for index = 1, #snapshot.manualQueues do
                local queue = snapshot.manualQueues[index]
                if type(queue) == "table" and type(queue.id) == "string" then
                    validQueues[queue.id] = true
                    manualQueuesByID[queue.id] = queue
                end
            end
        end
    end

    for queueKey in pairs(uiState.selectedQueues) do
        if not validQueues[queueKey] then
            uiState.selectedQueues[queueKey] = nil
        end
    end

    for queueKey, selectedItems in pairs(uiState.selectedItems) do
        local queue = manualQueuesByID[queueKey]
        local items = type(queue) == "table" and type(queue.items) == "table" and queue.items or nil
        if type(selectedItems) ~= "table" or not items then
            uiState.selectedItems[queueKey] = nil
        else
            for itemIndex in pairs(selectedItems) do
                local index = tonumber(itemIndex)
                if not index or index < 1 or index > #items then
                    selectedItems[itemIndex] = nil
                end
            end
            if next(selectedItems) == nil then
                uiState.selectedItems[queueKey] = nil
            end
        end
    end
end

function M.FormatCoords(mapID, x, y)
    if type(mapID) ~= "number" or type(x) ~= "number" or type(y) ~= "number" then
        return "Unknown location"
    end
    return string.format("Map %d at %.1f, %.1f", mapID, x * 100, y * 100)
end

function M.GetPrimaryTextLine(text)
    if type(text) ~= "string" then
        return nil
    end
    local line = text:match("([^\n]+)")
    if type(line) ~= "string" or line == "" then
        return nil
    end
    return line
end

local function SplitTextLines(text)
    if type(text) ~= "string" or text == "" then
        return nil
    end

    local lines = {}
    for line in text:gmatch("([^\n]+)") do
        lines[#lines + 1] = line
    end
    if #lines == 0 then
        return nil
    end
    return lines
end

function M.BuildDetailEntryTexts(entry, prefix)
    local lines = SplitTextLines(type(entry) == "table" and entry.title or nil) or {}
    local title = lines[1] or "Route step"
    if prefix then
        title = prefix .. title
    end

    local details = {}
    for index = 2, #lines do
        details[#details + 1] = lines[index]
    end
    local subtext = type(entry) == "table" and type(entry.subtext) == "string" and entry.subtext or nil
    if subtext and subtext ~= "" then
        details[#details + 1] = subtext
    end
    details[#details + 1] = M.FormatCoords(entry and entry.mapID, entry and entry.x, entry and entry.y)

    return title, table.concat(details, "\n")
end

function M.GetQueueProviderIcon(queue)
    if type(queue) ~= "table" or not queue.provider then return nil end
    if type(NS.GetGuideProviderInfo) ~= "function" then return nil end
    return NS.GetGuideProviderInfo(queue.provider)
end

function M.ResolveQueueEntryIcon(entry, opts)
    local native = GetNativeOverlay()
    if type(entry) ~= "table" or not native or type(native.ResolveWaypointIconSpec) ~= "function" then
        return nil
    end
    return native.ResolveWaypointIconSpec(entry, opts)
end

function M.GetGuideRouteIconOpts(provider)
    provider = type(provider) == "string" and provider or ""
    local opts = _guideRouteIconOptsByProvider[provider]
    if not opts then
        opts = {
            kind = "route",
            source = "guide",
            guideProvider = provider ~= "" and provider or nil,
        }
        _guideRouteIconOptsByProvider[provider] = opts
    end
    return opts
end

local function GetQueueActiveItem(queue)
    local items = type(queue) == "table" and type(queue.items) == "table" and queue.items or nil
    if not items or #items == 0 then
        return nil
    end
    local activeIndex = tonumber(queue.activeItemIndex) or 1
    return items[activeIndex] or items[1]
end

function M.GetQueueDisplayIcon(queue, queueType)
    if queueType == "guide" then
        return M.GetQueueProviderIcon(queue)
    end

    local itemIcon = M.ResolveQueueEntryIcon(GetQueueActiveItem(queue), QUEUE_ICON_OPTS_MANUAL)
    if itemIcon then
        return itemIcon
    end
    return M.GetQueueProviderIcon(queue)
end

function M.BuildQueueRows(snapshot)
    local rows = {}
    local sections = {
        transient = {},
        manual = {},
        guide = {},
    }

    if type(snapshot.transientQueue) == "table" then
        local q = snapshot.transientQueue
        sections.transient[1] = {
            rowType = "queue",
            key = q.id,
            queueType = "transient",
            queue = q,
            label = tostring(q.label or q.id),
            icon = M.GetQueueDisplayIcon(q, "transient"),
        }
    end

    if type(snapshot.manualQueues) == "table" then
        for index = 1, #snapshot.manualQueues do
            local queue = snapshot.manualQueues[index]
            if type(queue) == "table" then
                local prefix = queue.id == snapshot.activeManualQueueID and "* " or ""
                sections.manual[#sections.manual + 1] = {
                    rowType = "queue",
                    key = queue.id,
                    queueType = "manual",
                    queue = queue,
                    label = prefix .. tostring(queue.label or queue.id),
                    icon = M.GetQueueDisplayIcon(queue, "manual"),
                }
            end
        end
    end

    if type(snapshot.guideQueues) == "table" then
        for index = 1, #snapshot.guideQueues do
            local gq = snapshot.guideQueues[index]
            if M.IsGuideQueueAvailable(gq) then
                local prefix = gq.id == snapshot.activeGuideQueueID and "* " or ""
                sections.guide[#sections.guide + 1] = {
                    rowType = "queue",
                    key = gq.id,
                    queueType = "guide",
                    queue = gq,
                    label = prefix .. tostring(gq.label or "Guide"),
                    icon = M.GetQueueDisplayIcon(gq, "guide"),
                }
            end
        end
    elseif M.IsGuideQueueAvailable(snapshot.guideQueue) then
        local gq = snapshot.guideQueue
        sections.guide[1] = {
            rowType = "queue",
            key = gq.id or "guide",
            queueType = "guide",
            queue = gq,
            label = tostring(gq.label or "Guide"),
            icon = M.GetQueueDisplayIcon(gq, "guide"),
        }
    end

    for _, sectionKey in ipairs(M.SECTION_ORDER) do
        local entries = sections[sectionKey]
        rows[#rows + 1] = {
            rowType = "section",
            sectionKey = sectionKey,
            label = M.SECTION_LABELS[sectionKey] or sectionKey,
            count = #entries,
            collapsed = M.IsSectionCollapsed(sectionKey),
        }
        if not M.IsSectionCollapsed(sectionKey) then
            for index = 1, #entries do
                rows[#rows + 1] = entries[index]
            end
        end
    end

    return rows
end

function M.CountQueues(rows)
    local total = 0
    for index = 1, #rows do
        if rows[index].rowType == "queue" then
            total = total + 1
        end
    end
    return total
end

function M.BuildDetailRows(queue, queueType)
    local rows = {}
    if type(queue) ~= "table" then
        return rows
    end

    local queueKey = queue.id
    local function addSection(sectionKey, label, entries, entryBuilder)
        local count = type(entries) == "table" and #entries or 0
        local collapsed = M.IsDetailSectionCollapsed(queueKey, sectionKey)
        rows[#rows + 1] = {
            rowType = "section",
            queueKey = queueKey,
            sectionKey = sectionKey,
            label = label,
            count = count,
            collapsed = collapsed,
        }
        if collapsed or type(entries) ~= "table" then
            return
        end
        for index = 1, #entries do
            local row = entryBuilder(entries[index], index)
            if row then
                rows[#rows + 1] = row
            end
        end
    end

    if queue.kind == "destination_queue" then
        addSection("destinations", "Destinations", queue.items or {}, function(item, index)
            if type(item) ~= "table" then
                return nil
            end
            local prefix = index == (queue.activeItemIndex or 1) and "> " or ""
            local title, detail = M.BuildDetailEntryTexts(item, prefix)
            return {
                rowType = "entry",
                title = title,
                detail = detail,
                icon = M.ResolveQueueEntryIcon(item, QUEUE_ICON_OPTS_MANUAL),
                active = index == (queue.activeItemIndex or 1),
                queueKey = queueKey,
                queueDestinationIndex = index,
                selectableDestination = queueType == "manual",
                removableDestination = queueType == "manual",
            }
        end)

        addSection("travel", "Travel Legs", queue.projection and queue.projection.derivedEntries or {},
            function(entry, index)
                if type(entry) ~= "table" then
                    return nil
                end
                local prefix = entry.isHead and "> " or ""
                local title, detail = M.BuildDetailEntryTexts(entry,
                    string.format("%s%d. [%s] ", prefix, index, tostring(entry.entryType or "travel")))
                return {
                    rowType = "entry",
                    title = title,
                    detail = detail,
                    icon = M.ResolveQueueEntryIcon(entry, QUEUE_ICON_OPTS_ROUTE),
                    active = entry.isHead == true,
                }
            end)
    else
        addSection("route", "Route", queue.projection and queue.projection.entries or {}, function(entry, index)
            if type(entry) ~= "table" then
                return nil
            end
            local prefix = entry.isHead and "> " or ""
            local title, detail = M.BuildDetailEntryTexts(entry,
                string.format("%s%d. [%s] ", prefix, index, tostring(entry.entryType or "travel")))
            local iconOpts = queueType == "guide" and M.GetGuideRouteIconOpts(queue.provider) or QUEUE_ICON_OPTS_ROUTE
            return {
                rowType = "entry",
                title = title,
                detail = detail,
                icon = M.ResolveQueueEntryIcon(entry, iconOpts),
                active = entry.isHead == true,
            }
        end)
    end

    return rows
end

local function FormatQueueKindLabel(kind)
    if kind == "destination_queue" then
        return "Destination Queue"
    end
    if kind == "route" then
        return "Route"
    end
    return tostring(kind or "route")
end

function M.GetQueueCurrentEntry(queue)
    if type(queue) ~= "table" then
        return nil
    end

    if queue.kind == "destination_queue" then
        local derivedEntries = queue.projection and queue.projection.derivedEntries or nil
        if type(derivedEntries) == "table" then
            for index = 1, #derivedEntries do
                local entry = derivedEntries[index]
                if type(entry) == "table" and entry.isHead == true then
                    return entry
                end
            end
            if #derivedEntries > 0 then
                return derivedEntries[1]
            end
        end

        local items = queue.items or nil
        if type(items) == "table" and #items > 0 then
            return items[queue.activeItemIndex or 1] or items[1]
        end
        return nil
    end

    local entries = queue.projection and queue.projection.entries or nil
    if type(entries) == "table" then
        for index = 1, #entries do
            local entry = entries[index]
            if type(entry) == "table" and entry.isHead == true then
                return entry
            end
        end
        if #entries > 0 then
            return entries[1]
        end
    end
    return nil
end

function M.GetQueueFinalEntry(queue)
    if type(queue) ~= "table" then
        return nil
    end

    if queue.kind == "destination_queue" then
        local derivedEntries = queue.projection and queue.projection.derivedEntries or nil
        if type(derivedEntries) == "table" and #derivedEntries > 0 then
            return derivedEntries[#derivedEntries]
        end

        local items = queue.items or nil
        if type(items) == "table" and #items > 0 then
            return items[#items]
        end
        return nil
    end

    local entries = queue.projection and queue.projection.entries or nil
    if type(entries) == "table" and #entries > 0 then
        return entries[#entries]
    end
    return nil
end

function M.GetQueueStepCount(queue)
    if type(queue) ~= "table" then
        return 0
    end

    if queue.kind == "destination_queue" then
        local derivedEntries = queue.projection and queue.projection.derivedEntries or nil
        return type(derivedEntries) == "table" and #derivedEntries or 0
    end

    local entries = queue.projection and queue.projection.entries or nil
    return type(entries) == "table" and #entries or 0
end

function M.GetQueueDetailHeaderIcon(queue, queueType)
    if queueType == "guide" then
        local iconOpts = M.GetGuideRouteIconOpts(queue and queue.provider)
        return M.ResolveQueueEntryIcon(M.GetQueueFinalEntry(queue), iconOpts)
            or M.ResolveQueueEntryIcon(M.GetQueueCurrentEntry(queue), iconOpts)
            or M.GetQueueProviderIcon(queue)
    end
    return M.GetQueueDisplayIcon(queue, queueType)
end

function M.BuildDetailHeaderTexts(queue)
    if type(queue) ~= "table" then
        return "Queue", "", ""
    end

    local finalEntry = M.GetQueueFinalEntry(queue)
    local currentEntry = M.GetQueueCurrentEntry(queue)
    local headline = M.GetPrimaryTextLine(finalEntry and finalEntry.title)
        or M.GetPrimaryTextLine(currentEntry and currentEntry.title)
        or tostring(queue.label or "Queue")

    local subline
    if type(currentEntry) == "table" and currentEntry ~= finalEntry then
        subline = M.GetPrimaryTextLine(currentEntry.title) or
            M.FormatCoords(currentEntry.mapID, currentEntry.x, currentEntry.y)
    elseif type(finalEntry) == "table" then
        subline = M.FormatCoords(finalEntry.mapID, finalEntry.x, finalEntry.y)
    else
        subline = ""
    end

    local hint
    if queue.kind == "destination_queue" then
        local destinationCount = type(queue.items) == "table" and #queue.items or 0
        local stepCount = M.GetQueueStepCount(queue)
        if destinationCount > 0 and stepCount > 0 then
            hint = string.format("%d destinations queued, %d route steps", destinationCount, stepCount)
        elseif destinationCount > 0 then
            hint = string.format("%d destinations queued", destinationCount)
        elseif stepCount > 0 then
            hint = string.format("%d route steps", stepCount)
        else
            hint = "Queue ready"
        end
    else
        local stepCount = M.GetQueueStepCount(queue)
        hint = stepCount > 0 and string.format("%d route steps", stepCount) or "No active route steps"
    end

    return headline, subline or "", hint or ""
end

function M.BuildDetailMetaText(queue, queueType)
    if type(queue) ~= "table" then
        return ""
    end

    local lines = {
        string.format("Type: %s", FormatQueueKindLabel(queue.kind)),
        string.format("Source: %s", tostring(queue.sourceType or queueType or "-")),
    }

    local stepCount = M.GetQueueStepCount(queue)
    if stepCount > 0 then
        lines[#lines + 1] = string.format("Route Steps: %d", stepCount)
    end

    if queue.kind == "destination_queue" and type(queue.items) == "table" and #queue.items > 0 then
        lines[#lines + 1] = string.format("Queued Destinations: %d", #queue.items)
    end

    local finalEntry = M.GetQueueFinalEntry(queue)
    if type(finalEntry) == "table" then
        lines[#lines + 1] = string.format("Final: %s", M.GetPrimaryTextLine(finalEntry.title) or "Destination")
    end

    return table.concat(lines, "\n")
end
