local NS = _G.ZygorWaypointNS
local state = NS.State

state.routing = state.routing or {
    hooked = false,
    pendingWaypoint = nil,
    retryScheduled = false,
    retryCount = 0,
    startupAdopted = false,
    slashBatchEntries = nil,
    slashBatchScheduled = false,
    manualQueue = nil,
    externalWaypointsBySig = nil,
    originalAddWaypoint = nil,
    originalSetCrazyArrow = nil,
}

local routing = state.routing
local ROUTE_RETRY_DELAY_SECONDS = 0.25
local ROUTE_RETRY_MAX_COUNT = 40
local GetZygorPointer = NS.GetZygorPointer
local GetTomTom = NS.GetTomTom
local ReadWaypointCoords = NS.ReadWaypointCoords
local signature = NS.Signature
local externalWaypointBuffer = {}
local externalSigBuffer = {}
local EXTERNAL_SOURCE_STACK_MATCHES = {
    silverdragon = "silverdragon\\integration\\tomtom.lua",
    rarescanner = "rarescanner\\core\\service\\addons\\rstomtom.lua",
}
local EXTERNAL_SOURCE_STACK_START = 3
local EXTERNAL_SOURCE_STACK_COUNT = 12

-- ============================================================
-- Pending route retry
-- ============================================================

local function GetReadyPointer()
    local _, Pointer = GetZygorPointer()
    if not Pointer or type(Pointer.SetWaypoint) ~= "function" or not Pointer.ArrowFrame then
        return
    end
    return Pointer
end

local function QueuePendingRoute(mapID, x, y, title, meta)
    routing.pendingWaypoint = {
        mapID = mapID,
        x = x,
        y = y,
        title = title,
        meta = meta,
    }
end

local function ApplyRouteViaZygor(mapID, x, y, title, meta)
    local Pointer = GetReadyPointer()
    if not Pointer or not mapID or not x or not y then
        return false
    end

    local waydata = {
        title = title or "ZygorRoute",
        type = "manual",
        cleartype = true,
        icon = Pointer.Icons and Pointer.Icons.greendotbig or nil,
        onminimap = "always",
        overworld = true,
        showonedge = true,
        findpath = true,
        zwpExternalTomTom = true,
        zwpExternalSig = signature(mapID, x, y),
    }
    if type(meta) == "table" then
        for key, value in pairs(meta) do
            waydata[key] = value
        end
    end

    local setWaypoint = function()
        return pcall(Pointer.SetWaypoint, Pointer, mapID, x, y, waydata, true)
    end
    local ok, err = NS.WithZygorManualClearSyncSuppressed(setWaypoint)
    if not ok then
        NS.Log("TomTom -> Zygor route deferred:", tostring(err))
        return false
    end

    return true
end

local function TryApplyPendingRoute()
    local pending = routing.pendingWaypoint
    if not pending then
        return false
    end

    if not ApplyRouteViaZygor(pending.mapID, pending.x, pending.y, pending.title, pending.meta) then
        return false
    end

    routing.pendingWaypoint = nil
    routing.retryCount = 0
    return true
end

local function SchedulePendingRouteRetry()
    if routing.retryScheduled or not routing.pendingWaypoint then
        return
    end

    routing.retryScheduled = true
    NS.After(ROUTE_RETRY_DELAY_SECONDS, function()
        routing.retryScheduled = false

        if TryApplyPendingRoute() then
            return
        end

        if not routing.pendingWaypoint then
            routing.retryCount = 0
            return
        end

        routing.retryCount = routing.retryCount + 1
        if routing.retryCount < ROUTE_RETRY_MAX_COUNT then
            SchedulePendingRouteRetry()
        end
    end)
end

-- ============================================================
-- Manual queue
-- ============================================================

local function ClearManualQueue()
    routing.manualQueue = nil
end

local function SuspendManualQueue()
    local queue = routing.manualQueue
    if type(queue) ~= "table" then
        return false
    end

    queue.state = "suspended"
    queue.activeIndex = nil
    return true
end

local function SetManualQueueActiveIndex(index)
    local queue = routing.manualQueue
    if type(queue) ~= "table" then
        return false
    end

    if type(index) == "number" and type(queue.entries) == "table" and type(queue.entries[index]) == "table" then
        queue.state = "active"
        queue.activeIndex = index
        return true
    end

    queue.state = "suspended"
    queue.activeIndex = nil
    return false
end

local function CreateQueueEntry(mapID, x, y, title)
    return {
        mapID = mapID,
        x = x,
        y = y,
        title = title,
        sig = signature(mapID, x, y),
    }
end

local function AddManualQueueSigIndex(queue, sig, index)
    if type(queue) ~= "table" or type(queue.entriesBySig) ~= "table" or type(sig) ~= "string" then
        return
    end

    local bucket = queue.entriesBySig[sig]
    if type(bucket) ~= "table" then
        bucket = {}
        queue.entriesBySig[sig] = bucket
    end

    bucket[#bucket + 1] = index
end

local function RemoveManualQueueSigIndex(queue, sig, index)
    if type(queue) ~= "table" or type(queue.entriesBySig) ~= "table" or type(sig) ~= "string" then
        return
    end

    local bucket = queue.entriesBySig[sig]
    if type(bucket) ~= "table" then
        return
    end

    for position = 1, #bucket do
        if bucket[position] == index then
            table.remove(bucket, position)
            break
        end
    end

    if #bucket == 0 then
        queue.entriesBySig[sig] = nil
    end
end

local function ClearManualQueueEntry(queue, index)
    if type(queue) ~= "table" or type(queue.entries) ~= "table" or type(index) ~= "number" then
        return false
    end

    local entry = queue.entries[index]
    if type(entry) ~= "table" then
        return false
    end

    queue.entries[index] = nil
    RemoveManualQueueSigIndex(queue, entry.sig, index)
    queue.remainingCount = math.max((queue.remainingCount or 1) - 1, 0)

    if queue.activeIndex == index then
        queue.state = "suspended"
        queue.activeIndex = nil
    end

    if queue.remainingCount <= 0 and routing.manualQueue == queue then
        ClearManualQueue()
    end

    return true
end

local function BuildManualQueue(entries)
    local queue = {
        entries = {},
        entriesBySig = {},
        state = "suspended",
        activeIndex = nil,
        lastIndex = 0,
        remainingCount = 0,
    }

    for index, entry in ipairs(entries) do
        local queueEntry = CreateQueueEntry(entry.mapID, entry.x, entry.y, entry.title)
        queue.entries[index] = queueEntry
        queue.lastIndex = index
        queue.remainingCount = queue.remainingCount + 1
        AddManualQueueSigIndex(queue, queueEntry.sig, index)
    end

    return queue
end

local function CreateRouteMetaForQueueEntry(entry, index)
    if type(entry) ~= "table" then
        return
    end

    return {
        zwpExternalTomTom = true,
        zwpExternalSig = entry.sig,
        zwpQueueIndex = index,
        zwpQueueSig = entry.sig,
    }
end

local function GetManualQueueEntryIndexBySig(sig)
    local queue = routing.manualQueue
    if type(sig) ~= "string" or type(queue) ~= "table" or type(queue.entries) ~= "table"
        or type(queue.entriesBySig) ~= "table"
    then
        return
    end

    local bucket = queue.entriesBySig[sig]
    if type(bucket) ~= "table" then
        return
    end

    for position = 1, #bucket do
        local index = bucket[position]
        local entry = queue.entries[index]
        if type(entry) == "table" then
            return index, entry
        end
    end

    queue.entriesBySig[sig] = nil
end

local function GetManualQueueEntryIndexByUID(uid)
    if type(uid) ~= "table" then
        return
    end

    local mapID, x, y = uid[1], uid[2], uid[3]
    if type(mapID) ~= "number" or type(x) ~= "number" or type(y) ~= "number" then
        return
    end

    return GetManualQueueEntryIndexBySig(signature(mapID, x, y))
end

local function GetQueuedManualDestinationSignature(destination)
    if type(destination) ~= "table" then
        return
    end

    if type(destination.zwpQueueSig) == "string" then
        return destination.zwpQueueSig
    end

    if type(destination.zwpExternalSig) == "string" then
        return destination.zwpExternalSig
    end

    local mapID, x, y = ReadWaypointCoords(destination)
    if type(mapID) ~= "number" or type(x) ~= "number" or type(y) ~= "number" then
        return
    end

    return signature(mapID, x, y)
end

local function GetCurrentQueuedManualDestination()
    local queue = routing.manualQueue
    if type(queue) ~= "table" or type(queue.entries) ~= "table" then
        return
    end

    local _, pointer = GetZygorPointer()
    local destination = pointer and pointer.DestinationWaypoint or nil
    if type(destination) ~= "table" or destination.type ~= "manual" or destination.zwpExternalTomTom ~= true then
        return
    end

    local index = tonumber(destination.zwpQueueIndex)
    local entry = index and queue.entries[index] or nil
    local sig = GetQueuedManualDestinationSignature(destination)
    if type(entry) ~= "table" or type(sig) ~= "string" or entry.sig ~= sig then
        return
    end

    return destination, index, entry
end

-- ============================================================
-- External waypoint index
-- ============================================================

local function IsExternalTomTomWaypoint(uid)
    return type(uid) == "table"
        and uid[1] and uid[2] and uid[3]
        and not uid.fromZWP
        and uid.title ~= "ZygorRoute"
end

local function GetExternalWaypointSig(uid)
    if type(uid) ~= "table" then
        return
    end

    local mapID, x, y = uid[1], uid[2], uid[3]
    if type(mapID) ~= "number" or type(x) ~= "number" or type(y) ~= "number" then
        return
    end

    return signature(mapID, x, y)
end

local function GetExternalWaypointIndex()
    routing.externalWaypointsBySig = routing.externalWaypointsBySig or {}
    return routing.externalWaypointsBySig
end

local function ClearExternalWaypointIndex()
    routing.externalWaypointsBySig = {}
end

local function UnindexExternalTomTomWaypointBySig(sig, uid)
    local index = routing.externalWaypointsBySig
    if type(index) ~= "table" or type(sig) ~= "string" or type(uid) ~= "table" then
        return
    end

    local bucket = index[sig]
    if type(bucket) ~= "table" then
        return
    end

    bucket[uid] = nil
    if next(bucket) == nil then
        index[sig] = nil
    end
end

local function IndexExternalTomTomWaypoint(uid)
    if not IsExternalTomTomWaypoint(uid) then
        return
    end

    local sig = GetExternalWaypointSig(uid)
    if type(sig) ~= "string" then
        return
    end

    local index = GetExternalWaypointIndex()
    if type(index) ~= "table" then
        return
    end
    local bucket = index[sig]
    if type(bucket) ~= "table" then
        bucket = {}
        index[sig] = bucket
    end

    bucket[uid] = true
end

local function UnindexExternalTomTomWaypoint(uid)
    if type(uid) ~= "table" then
        return
    end

    local sig = GetExternalWaypointSig(uid)
    if type(sig) ~= "string" then
        return
    end

    UnindexExternalTomTomWaypointBySig(sig, uid)
end

local function IsTomTomWaypointActive(tomtom, uid)
    if not tomtom or type(uid) ~= "table" or type(tomtom.waypoints) ~= "table" then
        return false
    end

    local mapID = uid[1]
    local mapWaypoints = type(mapID) == "number" and tomtom.waypoints[mapID] or nil
    if type(mapWaypoints) ~= "table" then
        return false
    end

    for _, activeUID in pairs(mapWaypoints) do
        if activeUID == uid then
            return true
        end
    end

    return false
end

local function GetIndexedExternalTomTomWaypointBySig(sig)
    local tomtom = GetTomTom()
    local index = routing.externalWaypointsBySig
    if type(sig) ~= "string" or not tomtom or type(index) ~= "table" then
        return
    end

    local bucket = index[sig]
    if type(bucket) ~= "table" then
        return
    end

    for uid in pairs(bucket) do
        if IsTomTomWaypointActive(tomtom, uid) then
            return uid
        end

        bucket[uid] = nil
    end

    if next(bucket) == nil then
        index[sig] = nil
    end
end

local function GetIndexedExternalTomTomWaypointsBySig(sig)
    local tomtom = GetTomTom()
    local index = routing.externalWaypointsBySig
    if type(sig) ~= "string" or not tomtom or type(index) ~= "table" then
        return 0
    end

    local bucket = index[sig]
    if type(bucket) ~= "table" then
        return 0
    end

    local count = 0
    for uid in pairs(bucket) do
        if IsTomTomWaypointActive(tomtom, uid) then
            count = count + 1
            externalWaypointBuffer[count] = uid
        else
            bucket[uid] = nil
        end
    end

    if next(bucket) == nil then
        index[sig] = nil
    end

    return count
end

local function RebuildExternalTomTomWaypointIndex(tomtom)
    ClearExternalWaypointIndex()

    if not tomtom or type(tomtom.waypoints) ~= "table" then
        return
    end

    for _, mapWaypoints in pairs(tomtom.waypoints) do
        for _, uid in pairs(mapWaypoints) do
            IndexExternalTomTomWaypoint(uid)
        end
    end
end

function NS.GetExternalTomTomWaypointBySig(sig)
    return GetIndexedExternalTomTomWaypointBySig(sig)
end

-- ============================================================
-- Routing intercept
-- ============================================================

local function CopyWaypointOptions(opts)
    if type(opts) ~= "table" then
        return {}
    end

    local copy = {}
    for key, value in pairs(opts) do
        copy[key] = value
    end
    return copy
end

local function NormalizeSourceAddonCandidate(value)
    if type(value) ~= "string" then
        return nil
    end

    local normalized = value:gsub("^%s+", ""):gsub("%s+$", "")
    if normalized == "" then
        return nil
    end

    normalized = normalized:gsub("/", "\\"):lower()
    if normalized == "silverdragon" or normalized:find(EXTERNAL_SOURCE_STACK_MATCHES.silverdragon, 1, true) then
        return "silverdragon"
    end
    if normalized == "rarescanner" or normalized:find(EXTERNAL_SOURCE_STACK_MATCHES.rarescanner, 1, true) then
        return "rarescanner"
    end
end

local function ResolveExplicitTomTomSourceAddon(opts, uid)
    local senderFields = {
        type(opts) == "table" and opts.from or nil,
        type(opts) == "table" and opts.source or nil,
        type(uid) == "table" and uid.from or nil,
        type(uid) == "table" and uid.source or nil,
    }
    local hasExplicitSender = false

    for index = 1, 4 do
        local candidate = senderFields[index]
        if type(candidate) == "string" then
            candidate = candidate:gsub("^%s+", ""):gsub("%s+$", "")
            if candidate ~= "" then
                hasExplicitSender = true
                local sourceAddon = NormalizeSourceAddonCandidate(candidate)
                if sourceAddon then
                    return sourceAddon, true
                end
            end
        end
    end

    return nil, hasExplicitSender
end

local function ResolveDebugStackTomTomSourceAddon()
    if type(debugstack) ~= "function" then
        return nil
    end

    local stack = debugstack(EXTERNAL_SOURCE_STACK_START, EXTERNAL_SOURCE_STACK_COUNT, EXTERNAL_SOURCE_STACK_COUNT)
    return NormalizeSourceAddonCandidate(stack)
end

local function ResolveExternalTomTomSourceAddon(opts, uid, allowDebugStack)
    local cachedSource = type(uid) == "table" and NormalizeSourceAddonCandidate(uid.zwpSourceAddon) or nil
    if cachedSource then
        return cachedSource
    end

    cachedSource = type(opts) == "table" and NormalizeSourceAddonCandidate(opts.zwpSourceAddon) or nil
    if cachedSource then
        return cachedSource
    end

    local explicitSource, hasExplicitSender = ResolveExplicitTomTomSourceAddon(opts, uid)
    if explicitSource or hasExplicitSender then
        return explicitSource
    end

    if allowDebugStack ~= true then
        return nil
    end

    return ResolveDebugStackTomTomSourceAddon()
end

local function LogExternalTomTomSourceAddon(sourceAddon, mapID, x, y, title)
    if type(sourceAddon) ~= "string" then
        return
    end

    NS.Log(
        "Tagged external TomTom waypoint",
        sourceAddon,
        tostring(mapID),
        tostring(x),
        tostring(y),
        tostring(title)
    )
end

local function GetExternalTomTomSourceAddon(uid, mapID, x, y, title)
    local sourceAddon = ResolveExternalTomTomSourceAddon(nil, uid, false)
    if type(sourceAddon) ~= "string" or type(uid) ~= "table" then
        return sourceAddon
    end

    if uid.zwpSourceAddon ~= sourceAddon then
        uid.zwpSourceAddon = sourceAddon
        LogExternalTomTomSourceAddon(sourceAddon, mapID, x, y, title or uid.title)
    end

    return sourceAddon
end

local function CreateRouteMetaForExternalWaypoint(uid, mapID, x, y, title)
    local sourceAddon = GetExternalTomTomSourceAddon(uid, mapID, x, y, title)
    -- Fallback: check DB for persisted source addon (lost across /reload)
    if type(sourceAddon) ~= "string"
        and type(mapID) == "number"
        and type(x) == "number"
        and type(y) == "number"
    then
        local sig = signature(mapID, x, y)
        local db = NS.GetDB()
        local saved = type(db._zwpManual) == "table" and db._zwpManual or nil
        if saved and saved.sig == sig and type(saved.sourceAddon) == "string" then
            sourceAddon = saved.sourceAddon
        end
    end
    if type(sourceAddon) ~= "string" then
        return nil
    end

    return {
        zwpSourceAddon = sourceAddon,
    }
end

local function BuildExternalTomTomCallbacks(opts)
    local tomtom = GetTomTom()
    if not tomtom or type(tomtom.DefaultCallbacks) ~= "function" then
        return type(opts) == "table" and opts.callbacks or nil
    end

    local callbackOpts = CopyWaypointOptions(opts)
    callbackOpts.cleardistance = -1

    local callbacks = tomtom:DefaultCallbacks(callbackOpts)
    local externalCallbacks = type(opts) == "table" and opts.callbacks or nil
    if type(externalCallbacks) == "table" then
        for key, value in pairs(externalCallbacks) do
            if key ~= "distance" then
                callbacks[key] = value
            end
        end
    end

    return callbacks
end

local function GetLocalizedMapNameForWaypoint(mapID)
    if type(mapID) ~= "number" then
        return nil
    end

    local tomtom = GetTomTom()
    local hbd = tomtom and tomtom.hbd or nil
    if hbd and type(hbd.GetLocalizedMap) == "function" then
        local name = hbd:GetLocalizedMap(mapID)
        if type(name) == "string" and name ~= "" then
            return name
        end
    end

    local mapInfo = C_Map.GetMapInfo and C_Map.GetMapInfo(mapID) or nil
    local name = mapInfo and mapInfo.name or nil
    if type(name) == "string" and name ~= "" then
        return name
    end
end

local function FormatExternalTomTomFallbackTitle(mapID, x, y)
    if type(x) ~= "number" or type(y) ~= "number" then
        return nil
    end

    local mapName = GetLocalizedMapNameForWaypoint(mapID)
    if type(mapName) ~= "string" or mapName == "" then
        return nil
    end

    return string.format("%s %.0f, %.0f", mapName, x * 100, y * 100)
end

local function NormalizeExternalTomTomTitle(mapID, x, y, opts)
    if type(opts) ~= "table" then
        return nil
    end

    if opts.from ~= "TomTom/way" then
        return opts.title
    end

    local tomtom = GetTomTom()
    local genericTitle = tomtom and tomtom.L and tomtom.L["TomTom waypoint"] or nil
    if type(genericTitle) ~= "string" or genericTitle == "" or opts.title ~= genericTitle then
        return opts.title
    end

    return FormatExternalTomTomFallbackTitle(mapID, x, y) or opts.title
end

local function ShouldDivertExternalTomTomAdd(mapID, x, y, opts)
    if not NS.IsRoutingEnabled() then
        return false
    end

    if not mapID or not x or not y then
        return false
    end

    if opts and (opts.fromZWP or opts.title == "ZygorRoute") then
        return false
    end

    return true
end

local function PrepareExternalTomTomAddOptions(mapID, x, y, opts)
    if not ShouldDivertExternalTomTomAdd(mapID, x, y, opts) then
        return opts
    end

    local copied = CopyWaypointOptions(opts)
    copied.title = NormalizeExternalTomTomTitle(mapID, x, y, copied)
    local sourceAddon = ResolveExternalTomTomSourceAddon(copied, nil, true)
    if type(sourceAddon) == "string" then
        copied.zwpSourceAddon = sourceAddon
        LogExternalTomTomSourceAddon(sourceAddon, mapID, x, y, copied.title)
    end
    if copied.crazy ~= false then
        copied.crazy = false
        NS.Log("Prevent external AddWaypoint crazy", tostring(mapID), tostring(x), tostring(y), tostring(copied.title))
    end

    -- Routed external manuals should only clear through ZygorWaypoint's own
    -- active-destination logic, never through TomTom's passive distance clears.
    copied.cleardistance = -1
    copied.callbacks = BuildExternalTomTomCallbacks(copied)

    return copied
end

local function RouteExternalTomTomWaypoint(mapID, x, y, title, uid)
    if not NS.IsRoutingEnabled() then
        return false
    end

    if routing.slashBatchScheduled then
        return true
    end

    if NS.IsManualQueueAutoRoutingEnabled() and type(uid) == "table" then
        local index, entry = GetManualQueueEntryIndexByUID(uid)
        if index and entry then
            SetManualQueueActiveIndex(index)
            NS.RouteViaZygor(mapID, x, y, title, CreateRouteMetaForQueueEntry(entry, index))
            return true
        end
    end

    SuspendManualQueue()
    NS.RouteViaZygor(mapID, x, y, title, CreateRouteMetaForExternalWaypoint(uid, mapID, x, y, title))
    return true
end

local function GetSlashBatchEntrySig(entry)
    if type(entry) ~= "table" then
        return
    end

    return entry.sig or signature(entry.mapID, entry.x, entry.y)
end

local function PrimeSlashBatchCrazyArrow(entry)
    local tomtom = GetTomTom()
    if type(entry) ~= "table" or not tomtom or type(tomtom.SetCrazyArrow) ~= "function" then
        return
    end

    local sig = GetSlashBatchEntrySig(entry)
    if type(sig) ~= "string" then
        return
    end

    local uid = GetIndexedExternalTomTomWaypointBySig(sig)
    if type(uid) ~= "table" then
        return
    end

    local arrivalDistance = tomtom.profile and tomtom.profile.arrow and tomtom.profile.arrow.arrival or 15
    tomtom:SetCrazyArrow(uid, arrivalDistance, uid.title or entry.title)
end

local function FinalizeSlashWaypointBatch()
    NS.After(0, function()
        routing.slashBatchScheduled = false
    end)
end

local function RemoveExternalTomTomWaypointsBySig(sig)
    local tomtom = GetTomTom()
    if type(sig) ~= "string" or not tomtom or type(tomtom.RemoveWaypoint) ~= "function" then
        return
    end

    local count = GetIndexedExternalTomTomWaypointsBySig(sig)
    if count == 0 then
        return
    end

    local remover = function()
        for i = 1, count do
            tomtom:RemoveWaypoint(externalWaypointBuffer[i])
            externalWaypointBuffer[i] = nil
        end
    end

    NS.WithTomTomClearSyncSuppressed(remover)
end

local function FlushSlashWaypointBatch()
    local entries = routing.slashBatchEntries
    routing.slashBatchEntries = nil
    if type(entries) ~= "table" or not entries[1] then
        routing.slashBatchScheduled = false
        return
    end

    if not NS.IsRoutingEnabled() then
        ClearManualQueue()
        routing.slashBatchScheduled = false
        return
    end

    local first = entries[1]
    PrimeSlashBatchCrazyArrow(first)

    if NS.IsManualQueueAutoRoutingEnabled() and #entries > 1 then
        routing.manualQueue = BuildManualQueue(entries)
        local queueEntry = routing.manualQueue.entries[1]
        SetManualQueueActiveIndex(1)
        NS.RouteViaZygor(first.mapID, first.x, first.y, first.title, CreateRouteMetaForQueueEntry(queueEntry, 1))
        FinalizeSlashWaypointBatch()
        return
    end

    ClearManualQueue()
    NS.RouteViaZygor(first.mapID, first.x, first.y, first.title)
    FinalizeSlashWaypointBatch()
end

local function QueueSlashWaypointBatch(mapID, x, y, title)
    routing.slashBatchEntries = routing.slashBatchEntries or {}
    routing.slashBatchEntries[#routing.slashBatchEntries + 1] = {
        mapID = mapID,
        x = x,
        y = y,
        title = title,
    }

    if not routing.slashBatchScheduled then
        routing.slashBatchScheduled = true
        NS.After(0, FlushSlashWaypointBatch)
    end

    return true
end

-- ============================================================
-- Startup adoption
-- ============================================================

local function GetActiveTomTomWaypointCandidate()
    local tomtom = GetTomTom()
    if not tomtom or type(tomtom.IsCrazyArrowEmpty) ~= "function" or tomtom:IsCrazyArrowEmpty() then
        return
    end

    if type(tomtom.GetDistanceToWaypoint) ~= "function" or type(routing.externalWaypointsBySig) ~= "table" then
        return
    end

    local bestUID, bestDistance
    local staleSigCount = 0
    for sig, bucket in pairs(routing.externalWaypointsBySig) do
        if type(bucket) == "table" then
            local hasActiveUID = false
            for uid in pairs(bucket) do
                if IsTomTomWaypointActive(tomtom, uid) then
                    hasActiveUID = true
                    local distance = tomtom:GetDistanceToWaypoint(uid)
                    if distance and (not bestDistance or distance < bestDistance) then
                        bestDistance = distance
                        bestUID = uid
                    end
                else
                    bucket[uid] = nil
                end
            end

            if not hasActiveUID and next(bucket) == nil then
                staleSigCount = staleSigCount + 1
                externalSigBuffer[staleSigCount] = sig
            end
        else
            staleSigCount = staleSigCount + 1
            externalSigBuffer[staleSigCount] = sig
        end
    end

    for index = 1, staleSigCount do
        routing.externalWaypointsBySig[externalSigBuffer[index]] = nil
        externalSigBuffer[index] = nil
    end

    return bestUID
end

local function MaybeAdoptExistingTomTomWaypoint()
    if routing.startupAdopted or routing.pendingWaypoint then
        return
    end

    if not NS.IsRoutingEnabled() then
        return
    end

    local uid = GetActiveTomTomWaypointCandidate()
    routing.startupAdopted = true
    if not uid then
        return
    end

    QueuePendingRoute(
        uid[1],
        uid[2],
        uid[3],
        uid.title,
        CreateRouteMetaForExternalWaypoint(uid, uid[1], uid[2], uid[3], uid.title)
    )
    if not TryApplyPendingRoute() then
        SchedulePendingRouteRetry()
    end
end

function NS.ResumeTomTomRoutingStartupSync()
    if not NS.IsRoutingEnabled() then
        routing.pendingWaypoint = nil
        routing.retryCount = 0
        routing.slashBatchEntries = nil
        routing.slashBatchScheduled = false
        ClearManualQueue()
        return
    end

    if routing.pendingWaypoint then
        if not TryApplyPendingRoute() then
            routing.retryCount = 0
            SchedulePendingRouteRetry()
        end
        return
    end

    MaybeAdoptExistingTomTomWaypoint()
end

-- ============================================================
-- Public API
-- ============================================================

function NS.RouteViaZygor(mapID, x, y, title, meta)
    if not mapID or not x or not y then return end

    QueuePendingRoute(mapID, x, y, title, meta)
    if not TryApplyPendingRoute() then
        SchedulePendingRouteRetry()
    end
end

function NS.NoteQueuedTomTomWaypointCleared(uid)
    if not NS.IsManualQueueAutoRoutingEnabled() then
        return false
    end

    local queue = routing.manualQueue
    if type(queue) ~= "table" then
        return false
    end

    local index, entry = GetManualQueueEntryIndexByUID(uid)
    if not index or not entry then
        return false
    end

    local _, activeIndex = GetCurrentQueuedManualDestination()
    if activeIndex == index then
        -- The active queued entry must advance through the manual-destination
        -- follow-up path so the current point can atomically hand off to the
        -- next queued point. Consuming it here orphans the queue.
        SetManualQueueActiveIndex(index)
        return false
    end

    ClearManualQueueEntry(queue, index)
    return true
end

function NS.IsActiveManualQueueEntry(mapID, x, y)
    if not NS.IsManualQueueAutoRoutingEnabled() then
        return false
    end

    local queue = routing.manualQueue
    if type(queue) ~= "table" or type(queue.entries) ~= "table" then
        return false
    end

    local activeIndex = queue.activeIndex
    local activeEntry = type(activeIndex) == "number" and queue.entries[activeIndex] or nil
    if type(activeEntry) ~= "table" then
        return false
    end

    local _, currentIndex, currentEntry = GetCurrentQueuedManualDestination()
    if currentIndex ~= activeIndex or currentEntry ~= activeEntry then
        return false
    end

    if type(mapID) ~= "number" or type(x) ~= "number" or type(y) ~= "number" then
        return false
    end

    return activeEntry.sig == signature(mapID, x, y)
end

function NS.IsActiveQueuedManualDestination(destination)
    if not NS.IsManualQueueAutoRoutingEnabled() then
        return false
    end

    local queue = routing.manualQueue
    if type(destination) ~= "table" or type(queue) ~= "table" or type(queue.entries) ~= "table" then
        return false
    end

    local index = tonumber(destination.zwpQueueIndex)
    local entry = index and queue.entries[index] or nil
    local sig = GetQueuedManualDestinationSignature(destination)
    if type(entry) ~= "table" or type(sig) ~= "string" or entry.sig ~= sig then
        return false
    end

    if queue.state ~= "active" or queue.activeIndex ~= index then
        SetManualQueueActiveIndex(index)
    end

    return queue.state == "active" and queue.activeIndex == index
end

function NS.ConsumeNextQueuedManualRoute(destination)
    if not NS.IsManualQueueAutoRoutingEnabled() then
        return
    end

    local queue = routing.manualQueue
    if type(destination) ~= "table" or type(queue) ~= "table" or type(queue.entries) ~= "table" then
        return
    end

    local currentIndex = tonumber(destination.zwpQueueIndex)
    local currentEntry = currentIndex and queue.entries[currentIndex] or nil
    if not currentEntry then
        return
    end

    local currentSig = GetQueuedManualDestinationSignature(destination) or currentEntry.sig
    if type(currentSig) ~= "string" or currentEntry.sig ~= currentSig then
        return
    end

    SetManualQueueActiveIndex(currentIndex)
    ClearManualQueueEntry(queue, currentIndex)
    RemoveExternalTomTomWaypointsBySig(currentSig)

    queue = routing.manualQueue
    if type(queue) ~= "table" or type(queue.entries) ~= "table" then
        return
    end

    local function resolveNextRange(startIndex, endIndex)
        if type(startIndex) ~= "number" or type(endIndex) ~= "number" or startIndex > endIndex then
            return
        end

        for nextIndex = startIndex, endIndex do
            local nextEntry = queue.entries[nextIndex]
            if type(nextEntry) == "table" then
                if not GetIndexedExternalTomTomWaypointBySig(nextEntry.sig) then
                    ClearManualQueueEntry(queue, nextIndex)
                else
                    SetManualQueueActiveIndex(nextIndex)
                    return {
                        mapID = nextEntry.mapID,
                        x = nextEntry.x,
                        y = nextEntry.y,
                        title = nextEntry.title,
                        meta = CreateRouteMetaForQueueEntry(nextEntry, nextIndex),
                    }
                end
            end
        end
    end

    local nextRoute = resolveNextRange(currentIndex + 1, queue.lastIndex or 0)
    if nextRoute then
        return nextRoute
    end

    nextRoute = resolveNextRange(1, currentIndex - 1)
    if nextRoute then
        return nextRoute
    end

    ClearManualQueue()
end

function NS.RemoveExternalTomTomWaypointsBySig(sig)
    RemoveExternalTomTomWaypointsBySig(sig)
end

function NS.ClearManualRouteQueue()
    ClearManualQueue()
end

-- ============================================================
-- TomTom hooks
-- ============================================================

function NS.HookTomTomRouting()
    if routing.hooked then return end
    local tomtom = GetTomTom()
    if not tomtom or type(tomtom.AddWaypoint) ~= "function" then return end

    routing.hooked = true
    routing.originalAddWaypoint = routing.originalAddWaypoint or tomtom.AddWaypoint
    routing.originalSetCrazyArrow = routing.originalSetCrazyArrow or tomtom.SetCrazyArrow
    RebuildExternalTomTomWaypointIndex(tomtom)

    -- Fix: external TomTom waypoints remain as user pins, but while bridge
    -- routing is enabled they no longer get to claim the crazy arrow directly.
    tomtom.AddWaypoint = function(self, mapID, x, y, opts)
        local originalAddWaypoint = routing.originalAddWaypoint
        if type(originalAddWaypoint) ~= "function" then
            return
        end

        local effectiveOpts = PrepareExternalTomTomAddOptions(mapID, x, y, opts)
        local uid = originalAddWaypoint(self, mapID, x, y, effectiveOpts)
        if type(uid) == "table"
            and type(effectiveOpts) == "table"
            and type(effectiveOpts.zwpSourceAddon) == "string"
            and uid.zwpSourceAddon ~= effectiveOpts.zwpSourceAddon
        then
            uid.zwpSourceAddon = effectiveOpts.zwpSourceAddon
        end
        IndexExternalTomTomWaypoint(uid)
        local effectiveTitle = type(uid) == "table" and uid.title
            or (type(effectiveOpts) == "table" and effectiveOpts.title)
            or (type(opts) == "table" and opts.title)

        if ShouldDivertExternalTomTomAdd(mapID, x, y, opts) then
            if opts and opts.from == "TomTom/way" then
                QueueSlashWaypointBatch(mapID, x, y, effectiveTitle)
            else
                RouteExternalTomTomWaypoint(mapID, x, y, effectiveTitle, uid)
            end
        end

        return uid
    end

    if type(tomtom.ClearWaypoint) == "function" then
        hooksecurefunc(tomtom, "ClearWaypoint", function(_, uid)
            UnindexExternalTomTomWaypoint(uid)

            local bridge = NS.State and NS.State.bridge
            if bridge and (bridge.suppressTomTomClearSync or 0) > 0 then
                return
            end

            NS.NoteQueuedTomTomWaypointCleared(uid)

            NS.After(0, function()
                NS.HandleTomTomMirrorCleared(uid)
            end)
        end)
    end

    if type(tomtom.RemoveWaypoint) == "function" then
        hooksecurefunc(tomtom, "RemoveWaypoint", function(_, uid)
            UnindexExternalTomTomWaypoint(uid)
        end)
    end

    if type(tomtom.SetCrazyArrow) == "function" then
        tomtom.SetCrazyArrow = function(self, uid, dist, title)
            local originalSetCrazyArrow = routing.originalSetCrazyArrow
            if type(originalSetCrazyArrow) ~= "function" then
                return
            end

            local bridge = NS.State and NS.State.bridge
            if not NS.IsRoutingEnabled()
                or (bridge and (
                    (bridge.suppressTomTomClearSync or 0) > 0
                    or (bridge.suppressTomTomArrowRoutingSync or 0) > 0
                ))
                or not IsExternalTomTomWaypoint(uid)
            then
                return originalSetCrazyArrow(self, uid, dist, title)
            end

            NS.Log("Divert external SetCrazyArrow", tostring(uid[1]), tostring(uid[2]), tostring(uid[3]), tostring(uid.title))
            RouteExternalTomTomWaypoint(uid[1], uid[2], uid[3], uid.title or title, uid)
        end
    end

    NS.After(ROUTE_RETRY_DELAY_SECONDS, NS.ResumeTomTomRoutingStartupSync)
    NS.Log("TomTom -> Zygor routing hook active")
end
