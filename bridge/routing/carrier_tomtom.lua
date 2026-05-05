local NS = _G.AzerothWaypointNS
local state = NS.State

-- ============================================================
-- TomTom carrier
-- ============================================================
--
-- The single writer to TomTom. Owns:
--   - the live carrier UID representing the active AWP target
--   - crazy-arrow hijack/release lifecycle (opt-in per active carrier)
--   - title/status updates on the arrow
--   - route-menu clear/remove integration
--   - external-TomTom-waypoint hook

local Signature = NS.Signature
local externalWaypointBuffer = {}
local pendingRemovedTomTomUIDs = {}
local pendingRemovedTomTomFlush = false

local EXTERNAL_SOURCE_STACK_START = 3
local EXTERNAL_SOURCE_STACK_COUNT = 12

local function GetTomTomAddon()
    return rawget(_G, "TomTom")
end

local function HasUsableTomTom()
    local tomtom = GetTomTomAddon()
    return type(tomtom) == "table" and type(tomtom.AddWaypoint) == "function"
end

local function CopyWaypointOptions(opts)
    local copy = {}
    if type(opts) == "table" then
        for key, value in pairs(opts) do
            copy[key] = value
        end
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
    local externalSource = type(NS.NormalizeExternalWaypointSource) == "function"
        and NS.NormalizeExternalWaypointSource(normalized)
        or nil
    if externalSource then
        return externalSource
    end
    normalized = normalized:gsub("/", "\\"):lower()
    if normalized == "wowpro" or normalized:find("\\wowpro\\", 1, true) or normalized:find("interface\\addons\\wowpro", 1, true) then
        return "WoWPro"
    end
    return value:gsub("^%s+", ""):gsub("%s+$", "")
end

local function IsGuideProviderTomTomSource(sourceAddon)
    sourceAddon = NormalizeSourceAddonCandidate(sourceAddon)
    return sourceAddon == "WoWPro"
end

local function ScheduleGuideProviderForTomTomSource(sourceAddon, reason)
    if not IsGuideProviderTomTomSource(sourceAddon) then
        return false
    end
    if type(NS.ScheduleGuideProviderEvaluation) == "function" then
        NS.ScheduleGuideProviderEvaluation("wowpro", reason or "WoWProTomTom", { allowProviderSwitch = true })
    end
    return true
end

local function ResolveExplicitTomTomSourceAddon(opts, uid)
    local fields = {
        type(opts) == "table" and opts.from or nil,
        type(opts) == "table" and opts.source or nil,
        type(uid) == "table" and uid.from or nil,
        type(uid) == "table" and uid.source or nil,
    }
    for index = 1, #fields do
        local sourceAddon = NormalizeSourceAddonCandidate(fields[index])
        if sourceAddon then
            return sourceAddon
        end
    end
    return nil
end

local function ResolveDebugStackTomTomSourceAddon()
    if type(debugstack) ~= "function" then
        return nil
    end
    return NormalizeSourceAddonCandidate(debugstack(
        EXTERNAL_SOURCE_STACK_START,
        EXTERNAL_SOURCE_STACK_COUNT,
        EXTERNAL_SOURCE_STACK_COUNT
    ))
end

local function ResolveExternalTomTomSourceAddon(opts, uid, allowDebugStack)
    return NormalizeSourceAddonCandidate(type(uid) == "table" and uid.awpSourceAddon or nil)
        or NormalizeSourceAddonCandidate(type(opts) == "table" and opts.awpSourceAddon or nil)
        or ResolveExplicitTomTomSourceAddon(opts, uid)
        or (allowDebugStack and ResolveDebugStackTomTomSourceAddon() or nil)
end

local function GetLocalizedMapNameForWaypoint(mapID)
    if type(mapID) ~= "number" then
        return nil
    end
    local tomtom = GetTomTomAddon()
    local hbd = tomtom and tomtom.hbd or nil
    if hbd and type(hbd.GetLocalizedMap) == "function" then
        local name = hbd:GetLocalizedMap(mapID)
        if type(name) == "string" and name ~= "" then
            return name
        end
    end
    local mapInfo = C_Map and C_Map.GetMapInfo and C_Map.GetMapInfo(mapID) or nil
    local name = mapInfo and mapInfo.name or nil
    if type(name) == "string" and name ~= "" then
        return name
    end
    return nil
end

local function NormalizeExternalTomTomTitle(mapID, x, y, opts)
    if type(opts) ~= "table" then
        return nil
    end
    if opts.from ~= "TomTom/way" then
        return opts.title
    end
    local tomtom = GetTomTomAddon()
    local genericTitle = tomtom and tomtom.L and tomtom.L["TomTom waypoint"] or nil
    if type(genericTitle) ~= "string" or genericTitle == "" or opts.title ~= genericTitle then
        return opts.title
    end
    local mapName = GetLocalizedMapNameForWaypoint(mapID)
    if type(mapName) == "string" and type(x) == "number" and type(y) == "number" then
        return string.format("%s %.0f, %.0f", mapName, x * 100, y * 100)
    end
    return opts.title
end

local function IsAWPWaypoint(uid)
    return type(uid) == "table" and
    (uid.fromAWP == true or uid.awpCarrier == true or uid.from == "AzerothWaypoint:Carrier")
end

local function IsQueueProjectionWaypoint(uid)
    return type(uid) == "table"
        and uid.awpQueueProjection == true
end

local function RouteQueueProjectionWaypoint(uid)
    if not IsQueueProjectionWaypoint(uid)
        or type(uid.awpQueueID) ~= "string"
        or tonumber(uid.awpQueueItemIndex) == nil
        or uid.awpQueueEntryType ~= "destination"
        or type(NS.RouteQueueByID) ~= "function"
    then
        return false
    end
    return NS.RouteQueueByID(uid.awpQueueID, tonumber(uid.awpQueueItemIndex))
end

local function IsExternalTomTomWaypoint(uid)
    return type(uid) == "table"
        and type(uid[1]) == "number"
        and type(uid[2]) == "number"
        and type(uid[3]) == "number"
        and not IsAWPWaypoint(uid)
end

local function GetExternalWaypointSig(uid)
    if not IsExternalTomTomWaypoint(uid) then
        return nil
    end
    return Signature and Signature(uid[1], uid[2], uid[3]) or nil
end

local function GetExternalWaypointIndex()
    state.routing.externalWaypointsBySig = state.routing.externalWaypointsBySig or {}
    return state.routing.externalWaypointsBySig
end

local function IsTomTomWaypointActive(tomtom, uid)
    if not tomtom or type(uid) ~= "table" or type(tomtom.waypoints) ~= "table" then
        return false
    end
    local mapWaypoints = type(uid[1]) == "number" and tomtom.waypoints[uid[1]] or nil
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

local function IndexExternalTomTomWaypoint(uid)
    local sig = GetExternalWaypointSig(uid)
    if type(sig) ~= "string" then
        return
    end
    local index = GetExternalWaypointIndex()
    local bucket = index[sig]
    if type(bucket) ~= "table" then
        bucket = {}
        index[sig] = bucket
    end
    bucket[uid] = true
end

local function UnindexExternalTomTomWaypoint(uid)
    local sig = GetExternalWaypointSig(uid)
    local index = state.routing.externalWaypointsBySig
    if type(index) ~= "table" or type(sig) ~= "string" then
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

local function GetIndexedExternalTomTomWaypointBySig(sig)
    local tomtom = GetTomTomAddon()
    local index = state.routing.externalWaypointsBySig
    if type(sig) ~= "string" or type(index) ~= "table" or not tomtom then
        return nil
    end
    local bucket = index[sig]
    if type(bucket) ~= "table" then
        return nil
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
    return nil
end

local function GetIndexedExternalTomTomWaypointsBySig(sig)
    local tomtom = GetTomTomAddon()
    local index = state.routing.externalWaypointsBySig
    if type(sig) ~= "string" or type(index) ~= "table" or not tomtom then
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
    state.routing.externalWaypointsBySig = {}
    if not tomtom or type(tomtom.waypoints) ~= "table" then
        return
    end
    for _, mapWaypoints in pairs(tomtom.waypoints) do
        if type(mapWaypoints) == "table" then
            for _, uid in pairs(mapWaypoints) do
                IndexExternalTomTomWaypoint(uid)
            end
        end
    end
end

function NS.GetExternalTomTomWaypointBySig(sig)
    return GetIndexedExternalTomTomWaypointBySig(sig)
end

-- ------------------------------------------------------------
-- UID lifecycle
-- ------------------------------------------------------------
--
-- The live carrier UID lives in state.routing.carrierState.uid.
-- We dedupe writes via a sig comparison so identical re-pushes are no-ops.
-- Build the waypoint options table TomTom expects. Title is AWP's choice.
local function BuildCarrierOpts(title, meta)
    local opts = {}
    if type(meta) == "table" then
        for k, v in pairs(meta) do
            opts[k] = v
        end
    end

    -- The carrier waypoint is an internal AWP route leg, not a user-owned
    -- persistent TomTom destination. TomTom must never auto-remove it on
    -- arrival, because AWP owns leg advancement and explicit clear.
    opts.title           = title or "AWP Route"
    opts.arrowtitle      = opts.title
    opts.from            = "AzerothWaypoint:Carrier"
    opts.cleartype       = true
    opts.cleardistance   = -1
    opts.arrivaldistance = 15
    opts.callbacks       = nil
    opts.persistent      = false
    opts.onminimap       = "always"
    opts.overworld       = true
    opts.showonedge      = true
    opts.findpath        = true
    opts.errortext       = false
    opts.awpCarrier      = true
    -- Marker used by this carrier's TomTom hook so internal carrier
    -- writes are never adopted as external user waypoints.
    opts.fromAWP         = true
    return opts
end

local function GetTomTomWaypointKey(tomtom, mapID, x, y, title)
    if type(tomtom) == "table" and type(tomtom.GetKeyArgs) == "function" then
        local ok, key = pcall(tomtom.GetKeyArgs, tomtom, mapID, x, y, title)
        if ok then
            return key
        end
    end
end

local function UpdateIndexedTomTomWaypointTitle(tomtom, uid, title)
    if type(tomtom) ~= "table" or type(uid) ~= "table" then
        return false
    end
    title = title or "AWP Route"

    local mapID, x, y = uid[1], uid[2], uid[3]
    local mapWaypoints = type(tomtom.waypoints) == "table"
        and type(mapID) == "number"
        and tomtom.waypoints[mapID]
        or nil

    local indexedKey = nil
    if type(mapWaypoints) == "table" then
        local oldKey = GetTomTomWaypointKey(tomtom, mapID, x, y, uid.title)
        if oldKey and mapWaypoints[oldKey] == uid then
            indexedKey = oldKey
        else
            for key, activeUID in pairs(mapWaypoints) do
                if activeUID == uid then
                    indexedKey = key
                    break
                end
            end
        end
    end

    uid.title = title
    uid.arrowtitle = title

    if type(mapWaypoints) ~= "table" then
        return false
    end
    if not indexedKey then
        return false
    end

    local newKey = GetTomTomWaypointKey(tomtom, mapID, x, y, title)
    if newKey and newKey ~= indexedKey then
        mapWaypoints[indexedKey] = nil
        mapWaypoints[newKey] = uid
    end
    return true
end

local function SetCarrierArrowTitle(tomtom, carrier, title)
    if type(carrier) ~= "table" or not carrier.uid then
        return false
    end
    title = title or "AWP Route"
    carrier.title = title
    local indexed = UpdateIndexedTomTomWaypointTitle(tomtom, carrier.uid, title)
    local setCrazyArrow = state.routing.originalSetCrazyArrow or tomtom and tomtom.SetCrazyArrow
    if indexed and type(tomtom) == "table" and type(setCrazyArrow) == "function" then
        pcall(setCrazyArrow, tomtom, carrier.uid, 15, title)
    end
    return indexed
end

local function PromoteQueueProjectionToCarrier(uid, opts)
    if not IsQueueProjectionWaypoint(uid) then
        return false
    end

    local published = state.routing and state.routing.publishedQueueState or nil
    local uidByEntryKey = type(published) == "table" and published.uidByEntryKey or nil
    if type(uidByEntryKey) == "table" then
        for key, publishedUID in pairs(uidByEntryKey) do
            if publishedUID == uid then
                uidByEntryKey[key] = nil
            end
        end
        published.signature = nil
    end

    opts = type(opts) == "table" and opts or {}
    uid.from = "AzerothWaypoint:Carrier"
    uid.fromAWP = true
    uid.awpCarrier = true
    uid.awpQueueProjection = nil
    uid.awpQueueID = nil
    uid.awpQueueItemIndex = nil
    uid.awpQueueEntryType = nil
    uid.cleardistance = opts.cleardistance
    uid.arrivaldistance = opts.arrivaldistance
    uid.persistent = opts.persistent
    uid.findpath = opts.findpath
    uid.errortext = opts.errortext
    uid.showonedge = opts.showonedge
    uid.onminimap = opts.onminimap
    uid.overworld = opts.overworld
    return true
end

function NS.PushCarrierWaypoint(mapID, x, y, title, meta)
    if not HasUsableTomTom() then return false end
    if type(mapID) ~= "number" or type(x) ~= "number" or type(y) ~= "number" then
        return false
    end

    local tomtom = GetTomTomAddon()
    local carrier = state.routing.carrierState
    local newSig = Signature and Signature(mapID, x, y) or string.format("%s:%s:%s", mapID, x, y)

    -- Dedupe: same sig and an existing live UID? Nothing to do.
    if carrier and carrier.sig == newSig and carrier.uid then
        if IsTomTomWaypointActive(tomtom, carrier.uid) then
            SetCarrierArrowTitle(tomtom, carrier, title)
            return true
        end
        carrier.uid = nil
        state.routing.lastPushedCarrierUID = nil
    end

    -- Tear down the old carrier UID (if any) before adding the new one.
    -- Uses the AWP-initiated remove wrapper so our own external-remove
    -- hook doesn't react to this self-initiated cleanup.
    if carrier and carrier.uid and NS.Internal and NS.Internal.CarrierTomTom then
        NS.Internal.CarrierTomTom.RemoveCarrierUID(tomtom, carrier.uid)
    end

    local opts = BuildCarrierOpts(title, meta)
    local ok, uid = pcall(tomtom.AddWaypoint, tomtom, mapID, x, y, opts)
    if not ok or not uid then
        return false
    end
    PromoteQueueProjectionToCarrier(uid, opts)

    state.routing.carrierState         = state.routing.carrierState or {}
    local cs                           = state.routing.carrierState
    cs.mapID                           = mapID
    cs.x                               = x
    cs.y                               = y
    cs.title                           = title
    cs.sig                             = newSig
    cs.uid                             = uid
    state.routing.lastPushedCarrierUID = uid

    -- Make this waypoint the active crazy-arrow target. AddWaypoint just
    -- creates the pin; SetCrazyArrow makes it the live navigation arrow.
    -- The carrier owns arrival display, but not clear/removal.
    return SetCarrierArrowTitle(tomtom, cs, title)
end

function NS.RefreshCarrierWaypointTitle(title)
    local tomtom = GetTomTomAddon()
    local carrier = state.routing.carrierState
    if not tomtom or type(carrier) ~= "table" or not carrier.uid then
        return false
    end
    return SetCarrierArrowTitle(tomtom, carrier, title)
end

function NS.ClearCarrierWaypoint()
    local carrier = state.routing.carrierState
    if not carrier or not carrier.uid then
        state.routing.carrierState = nil
        state.routing.lastPushedCarrierUID = nil
        return
    end

    local tomtom = GetTomTomAddon()
    if tomtom and NS.Internal and NS.Internal.CarrierTomTom then
        NS.Internal.CarrierTomTom.RemoveCarrierUID(tomtom, carrier.uid)
    end

    state.routing.carrierState = nil
    state.routing.lastPushedCarrierUID = nil
end

local function BuildQueueProjectionOpts(entry)
    entry = type(entry) == "table" and entry or {}
    local opts = {
        title = entry.title or "AWP Queue",
        from = "AzerothWaypoint:Queue",
        fromAWP = true,
        awpQueueProjection = true,
        awpQueueID = entry.queueID,
        awpQueueItemIndex = entry.queueItemIndex,
        awpQueueEntryType = entry.entryType,
        persistent = false,
        crazy = false,
        cleartype = true,
        cleardistance = -1,
        onminimap = "always",
        overworld = true,
        showonedge = true,
        findpath = false,
        errortext = false,
    }
    return opts
end

local function BuildQueueProjectionSignature(entries, queueKey)
    if type(queueKey) ~= "string" or type(entries) ~= "table" then
        return nil
    end
    local parts = { queueKey }
    for index = 1, #entries do
        local entry = entries[index]
        parts[#parts + 1] = table.concat({
            tostring(type(entry) == "table" and entry.key or index),
            tostring(type(entry) == "table" and entry.title or "-"),
        }, ":", 1, 2)
    end
    return table.concat(parts, "\031")
end

function NS.ClearPublishedQueuePins()
    local routing = state.routing
    local published = routing.publishedQueueState
    if type(published) ~= "table" or type(published.uidByEntryKey) ~= "table" then
        routing.publishedQueueState = {
            queueKey = nil,
            signature = nil,
            uidByEntryKey = {},
        }
        return
    end

    local tomtom = GetTomTomAddon()
    if tomtom and NS.Internal and NS.Internal.CarrierTomTom then
        for _, uid in pairs(published.uidByEntryKey) do
            if uid then
                NS.Internal.CarrierTomTom.RemoveCarrierUID(tomtom, uid)
            end
        end
    end

    routing.publishedQueueState = {
        queueKey = nil,
        signature = nil,
        uidByEntryKey = {},
    }
end

function NS.PublishQueueProjectionPins()
    if not HasUsableTomTom() then
        return false
    end

    local entries, queueKey = nil, nil
    if type(NS.GetActiveQueuePublishedEntries) == "function" then
        entries, queueKey = NS.GetActiveQueuePublishedEntries()
    end
    if type(entries) ~= "table" or #entries == 0 or type(queueKey) ~= "string" then
        NS.ClearPublishedQueuePins()
        return false
    end

    local signature = BuildQueueProjectionSignature(entries, queueKey)
    local published = state.routing.publishedQueueState or {}
    if published.signature == signature then
        return true
    end

    NS.ClearPublishedQueuePins()

    local tomtom = GetTomTomAddon()
    local addWaypoint = state.routing.originalAddWaypoint or tomtom and tomtom.AddWaypoint
    if not tomtom or type(addWaypoint) ~= "function" then
        return false
    end

    local uidByEntryKey = {}
    for index = 1, #entries do
        local entry = entries[index]
        if type(entry) == "table"
            and type(entry.mapID) == "number"
            and type(entry.x) == "number"
            and type(entry.y) == "number"
        then
            local opts = BuildQueueProjectionOpts(entry)
            local ok, uid = pcall(addWaypoint, tomtom, entry.mapID, entry.x, entry.y, opts)
            if ok and uid then
                if type(uid) == "table" then
                    uid.fromAWP = true
                    uid.awpQueueProjection = true
                    uid.awpQueueID = opts.awpQueueID
                    uid.awpQueueItemIndex = opts.awpQueueItemIndex
                    uid.awpQueueEntryType = opts.awpQueueEntryType
                end
                uidByEntryKey[entry.key or tostring(index)] = uid
            end
        end
    end

    state.routing.publishedQueueState = {
        queueKey = queueKey,
        signature = signature,
        uidByEntryKey = uidByEntryKey,
    }
    return true
end

-- ------------------------------------------------------------
-- External TomTom waypoint hook
-- ------------------------------------------------------------

local function ShouldDivertExternalTomTomAdd(mapID, x, y, opts)
    if type(NS.IsRoutingEnabled) == "function" and not NS.IsRoutingEnabled() then
        return false
    end
    if type(mapID) ~= "number" or type(x) ~= "number" or type(y) ~= "number" then
        return false
    end
    if type(opts) == "table" and (opts.fromAWP == true or opts.awpCarrier == true or opts.from == "AzerothWaypoint:Carrier") then
        return false
    end
    if IsGuideProviderTomTomSource(ResolveExplicitTomTomSourceAddon(opts, nil)) then
        return false
    end
    return true
end

local function BuildExternalTomTomCallbacks(opts)
    local tomtom = GetTomTomAddon()
    if not tomtom or type(tomtom.DefaultCallbacks) ~= "function" then
        return type(opts) == "table" and opts.callbacks or nil
    end

    local callbackOpts = CopyWaypointOptions(opts)
    callbackOpts.cleardistance = -1

    local callbacks = tomtom:DefaultCallbacks(callbackOpts) or {}
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

local function PrepareExternalTomTomAddOptions(mapID, x, y, opts)
    if not ShouldDivertExternalTomTomAdd(mapID, x, y, opts) then
        return opts
    end

    local copied = CopyWaypointOptions(opts)
    copied.title = NormalizeExternalTomTomTitle(mapID, x, y, copied)
    local sourceAddon = ResolveExternalTomTomSourceAddon(copied, nil, true)
    if type(sourceAddon) == "string" then
        copied.awpSourceAddon = sourceAddon
    end
    copied.crazy = false
    copied.cleardistance = -1
    copied.callbacks = BuildExternalTomTomCallbacks(copied)
    return copied
end

local function PrepareGuideProviderTomTomAddOptions(opts)
    local sourceAddon = ResolveExternalTomTomSourceAddon(opts, nil, true)
    if not IsGuideProviderTomTomSource(sourceAddon) then
        return opts, nil
    end

    local copied = CopyWaypointOptions(opts)
    copied.awpSourceAddon = sourceAddon
    copied.crazy = false
    return copied, sourceAddon
end

local function QueueSlashWaypointBatch(mapID, x, y, title)
    state.routing.slashBatchEntries = state.routing.slashBatchEntries or {}
    state.routing.slashBatchEntries[#state.routing.slashBatchEntries + 1] = {
        mapID = mapID,
        x = x,
        y = y,
        title = title,
    }

    if state.routing.slashBatchScheduled then
        return true
    end

    state.routing.slashBatchScheduled = true
    NS.After(0, function()
        local entries = state.routing.slashBatchEntries
        state.routing.slashBatchEntries = nil
        state.routing.slashBatchScheduled = false
        if type(entries) ~= "table" or type(entries[1]) ~= "table" then
            return
        end

        if type(NS.IsRoutingEnabled) == "function" and not NS.IsRoutingEnabled() then
            if type(NS.ClearManualQueues) == "function" then
                NS.ClearManualQueues()
            end
            return
        end

        local first = entries[1]
        if #entries > 1 and type(NS.RouteImportedWaypointBatch) == "function" then
            local routed = NS.RouteImportedWaypointBatch(entries)
            if routed then
                return
            end
        end

        if type(NS.ClearManualQueues) == "function" then
            NS.ClearManualQueues()
        end
        local uid = Signature and GetIndexedExternalTomTomWaypointBySig(Signature(first.mapID, first.x, first.y)) or nil
        local meta = type(NS.CreateRouteMetaForExternalWaypoint) == "function"
            and NS.CreateRouteMetaForExternalWaypoint(uid, first.mapID, first.x, first.y, first.title)
            or nil
        NS.AdoptExternalWaypoint(first.mapID, first.x, first.y, first.title, meta)
    end)
    return true
end

local function RouteExternalTomTomWaypoint(mapID, x, y, title, uid)
    if type(NS.IsRoutingEnabled) == "function" and not NS.IsRoutingEnabled() then
        return false
    end
    if state.routing.slashBatchScheduled then
        return true
    end

    local meta = type(NS.CreateRouteMetaForExternalWaypoint) == "function"
        and NS.CreateRouteMetaForExternalWaypoint(uid, mapID, x, y, title)
        or nil
    local queue = NS.RouteQueueInternal
    local sourceType = type(queue) == "table"
        and type(queue.InferQueueSourceType) == "function"
        and queue.InferQueueSourceType(meta)
        or nil
    if sourceType ~= "transient_source" and type(NS.ClearManualQueues) == "function" then
        NS.ClearManualQueues()
    end
    return NS.AdoptExternalWaypoint(mapID, x, y, title, meta)
end

local function ReassertCarrierArrow()
    local tomtom = GetTomTomAddon()
    local originalSetCrazyArrow = state.routing.originalSetCrazyArrow
    local carrier = state.routing.carrierState
    if not tomtom or type(originalSetCrazyArrow) ~= "function" or type(carrier) ~= "table" or not carrier.uid then
        return
    end
    pcall(originalSetCrazyArrow, tomtom, carrier.uid, 15, carrier.title or "AWP Route")
end

function NS.InstallExternalTomTomHooks()
    local tomtom = GetTomTomAddon()
    if not tomtom or type(tomtom.AddWaypoint) ~= "function" then
        return
    end
    if state.routing._externalTomTomHooksInstalled then
        return
    end

    state.routing.originalAddWaypoint = state.routing.originalAddWaypoint or tomtom.AddWaypoint
    state.routing.originalSetCrazyArrow = state.routing.originalSetCrazyArrow or tomtom.SetCrazyArrow
    RebuildExternalTomTomWaypointIndex(tomtom)

    tomtom.AddWaypoint = function(self, mapID, x, y, opts)
        local originalAddWaypoint = state.routing.originalAddWaypoint
        if type(originalAddWaypoint) ~= "function" then
            return nil
        end

        local effectiveOpts, guideSourceAddon = PrepareGuideProviderTomTomAddOptions(opts)
        local divert = guideSourceAddon == nil and ShouldDivertExternalTomTomAdd(mapID, x, y, opts)
        if guideSourceAddon == nil then
            effectiveOpts = PrepareExternalTomTomAddOptions(mapID, x, y, opts)
        end
        local uid = originalAddWaypoint(self, mapID, x, y, effectiveOpts)
        if guideSourceAddon then
            if type(uid) == "table" then
                uid.awpSourceAddon = guideSourceAddon
            end
            ScheduleGuideProviderForTomTomSource(guideSourceAddon, "WoWProTomTomAddWaypoint")
        elseif type(uid) == "table" and divert then
            local sourceAddon = ResolveExternalTomTomSourceAddon(effectiveOpts, uid, false)
            if type(sourceAddon) == "string" then
                uid.awpSourceAddon = sourceAddon
            end
            IndexExternalTomTomWaypoint(uid)
        elseif type(uid) == "table" then
            local sourceAddon = ResolveExternalTomTomSourceAddon(effectiveOpts, uid, false)
            if ScheduleGuideProviderForTomTomSource(sourceAddon, "WoWProTomTomAddWaypoint") then
                uid.awpSourceAddon = sourceAddon
            end
        end

        local effectiveTitle = type(uid) == "table" and uid.title
            or type(effectiveOpts) == "table" and effectiveOpts.title
            or type(opts) == "table" and opts.title
            or nil

        if divert then
            if type(opts) == "table" and opts.from == "TomTom/way" then
                QueueSlashWaypointBatch(mapID, x, y, effectiveTitle)
            else
                RouteExternalTomTomWaypoint(mapID, x, y, effectiveTitle, uid)
            end
        end

        return uid
    end

    if type(tomtom.SetCrazyArrow) == "function" then
        tomtom.SetCrazyArrow = function(self, uid, dist, title)
            local originalSetCrazyArrow = state.routing.originalSetCrazyArrow
            if type(originalSetCrazyArrow) ~= "function" then
                return nil
            end
            if IsQueueProjectionWaypoint(uid) then
                RouteQueueProjectionWaypoint(uid)
                ReassertCarrierArrow()
                return nil
            end
            if not IsExternalTomTomWaypoint(uid) or (type(NS.IsRoutingEnabled) == "function" and not NS.IsRoutingEnabled()) then
                return originalSetCrazyArrow(self, uid, dist, title)
            end
            local sourceAddon = ResolveExternalTomTomSourceAddon(nil, uid, false)
            if ScheduleGuideProviderForTomTomSource(sourceAddon, "WoWProTomTomSetCrazyArrow") then
                return nil
            end

            local adopted = RouteExternalTomTomWaypoint(uid[1], uid[2], uid[3], title or uid.title, uid)
            if adopted then
                ReassertCarrierArrow()
                return nil
            end
            return originalSetCrazyArrow(self, uid, dist, title)
        end
    end

    state.routing._externalTomTomHooksInstalled = true
end

-- ------------------------------------------------------------
-- Carrier-UID removal detection
-- ------------------------------------------------------------
--
-- When the user right-clicks the TomTom arrow and chooses Remove, or
-- otherwise dismisses the waypoint via TomTom UI, tomtom.RemoveWaypoint
-- (or ClearWaypoint) fires. We add our own observer so AWP knows
-- to clear manualAuthority and stop the world overlay
-- from re-syncing the gone destination.
--
-- We must NOT react when AWP itself removed the UID (during
-- PushCarrierWaypoint's old-UID teardown, or ClearCarrierWaypoint).
-- A counter lets the hook ignore those self-initiated removes.

local awpInitiatedRemove = 0

local function IsAWPInitiatedRemove()
    return awpInitiatedRemove > 0
end

local function ForgetExternalClearedCarrier(resetQueuePins)
    local routing = NS.State.routing
    if type(routing) ~= "table" then
        return
    end
    routing.carrierState = nil
    routing.lastPushedCarrierUID = nil
    if resetQueuePins and type(NS.ClearPublishedQueuePins) == "function" then
        NS.ClearPublishedQueuePins()
    end
end

local function ReassertGuideCarrierAfterExternalClear(reason, resetQueuePins)
    local routing = NS.State.routing
    if type(routing) ~= "table" then
        return false
    end
    if type(NS.GetGuideRouteState) ~= "function" or not NS.GetGuideRouteState() then
        return false
    end
    if type(NS.GetGuideVisibilityState) == "function"
        and NS.GetGuideVisibilityState() ~= "visible"
    then
        return false
    end

    ForgetExternalClearedCarrier(resetQueuePins)
    if type(NS.RecomputeCarrier) == "function" then
        NS.RecomputeCarrier()
    end
    if type(NS.Log) == "function" then
        NS.Log("Guide waypoint clear ignored", tostring(reason or "-"))
    end
    return true
end

local function HandleExternalCarrierRemove(uid)
    if not uid then return end
    if IsAWPInitiatedRemove() then return end
    local cs = NS.State.routing and NS.State.routing.carrierState
    if not cs or cs.uid ~= uid then return false end
    -- Our carrier UID was removed externally. Manual authority routes
    -- must run the explicit-clear fan-out first. Guide routes are read-only:
    -- TomTom can remove the physical UID, but the live guide step remains
    -- authoritative and is immediately re-pushed.
    if type(NS.GetManualAuthority) == "function" and NS.GetManualAuthority() then
        if type(NS.HandleExplicitManualAuthorityRemove) == "function" then
            NS.HandleExplicitManualAuthorityRemove()
            return true
        end
    elseif cs.source == "guide"
        and type(NS.GetGuideRouteState) == "function"
        and NS.GetGuideRouteState()
    then
        if not ReassertGuideCarrierAfterExternalClear("remove_waypoint", false) then
            ForgetExternalClearedCarrier(false)
            if type(NS.RecomputeCarrier) == "function" then
                NS.RecomputeCarrier()
            end
        end
        return true
    end
    NS.State.routing.carrierState = nil
    NS.State.routing.lastPushedCarrierUID = nil
    if type(NS.RecomputeCarrier) == "function" then
        NS.RecomputeCarrier()
    end
    return true
end

local function GetActiveExternalManualSig()
    local record = type(NS.GetManualAuthority) == "function" and NS.GetManualAuthority() or nil
    local identity = type(record) == "table" and type(record.identity) == "table" and record.identity or nil
    if type(identity) ~= "table" or identity.kind ~= "external_tomtom" then
        return nil
    end
    return identity.queueSig or identity.externalSig or identity.sig
end

local function HandleTomTomWaypointRemoved(uid)
    if not uid then
        return
    end
    if HandleExternalCarrierRemove(uid) then
        return
    end

    local sig = GetExternalWaypointSig(uid)
    UnindexExternalTomTomWaypoint(uid)
    if IsAWPInitiatedRemove() then
        return
    end

    if type(NS.NoteQueuedTomTomWaypointCleared) == "function" then
        NS.NoteQueuedTomTomWaypointCleared(uid)
    end

    if type(sig) == "string" and sig == GetActiveExternalManualSig()
        and type(NS.HandleExplicitManualAuthorityRemove) == "function"
    then
        NS.HandleExplicitManualAuthorityRemove()
    end
end

local function QueueTomTomWaypointRemoved(uid)
    if not uid or IsAWPInitiatedRemove() then
        return
    end

    pendingRemovedTomTomUIDs[uid] = true
    if pendingRemovedTomTomFlush then
        return
    end

    pendingRemovedTomTomFlush = true
    NS.After(0, function()
        pendingRemovedTomTomFlush = false
        for removedUID in pairs(pendingRemovedTomTomUIDs) do
            pendingRemovedTomTomUIDs[removedUID] = nil
            HandleTomTomWaypointRemoved(removedUID)
        end
    end)
end

function NS.InstallCarrierTomTomHooks()
    local tomtom = GetTomTomAddon()
    if not tomtom then return end
    if NS.State.routing._carrierHooksInstalled then return end

    if type(tomtom.RemoveWaypoint) == "function" then
        hooksecurefunc(tomtom, "RemoveWaypoint", function(_, uid)
            QueueTomTomWaypointRemoved(uid)
        end)
    end

    if type(tomtom.ClearWaypoint) == "function" then
        hooksecurefunc(tomtom, "ClearWaypoint", function(_, uid)
            QueueTomTomWaypointRemoved(uid)
        end)
    end

    if type(tomtom.RemoveAllWaypoints) == "function" then
        hooksecurefunc(tomtom, "RemoveAllWaypoints", function()
            if IsAWPInitiatedRemove() then
                return
            end
            local activeQueueKey = state.routing and state.routing.activeQueueKey or nil
            local cs = state.routing and state.routing.carrierState or nil
            if activeQueueKey == "guide"
                or (type(activeQueueKey) == "string" and activeQueueKey:match("^guide:") ~= nil)
                or (type(cs) == "table" and cs.source == "guide")
            then
                if not ReassertGuideCarrierAfterExternalClear("remove_all", true) then
                    ForgetExternalClearedCarrier(true)
                    if type(NS.RecomputeCarrier) == "function" then
                        NS.RecomputeCarrier()
                    end
                end
            elseif type(activeQueueKey) == "string" and type(NS.ClearQueueByID) == "function" then
                NS.ClearQueueByID(activeQueueKey)
            elseif type(NS.GetManualAuthority) == "function"
                and NS.GetManualAuthority()
                and type(NS.HandleExplicitManualAuthorityRemove) == "function"
            then
                NS.HandleExplicitManualAuthorityRemove()
            else
                ReassertGuideCarrierAfterExternalClear("remove_all", true)
            end
        end)
    end

    NS.State.routing._carrierHooksInstalled = true
end

-- Wrap the in-module helper that performs AWP-initiated removes so the
-- counter is bumped only around our own RemoveWaypoint calls. Called
-- from PushCarrierWaypoint (when tearing down an old UID) and from
-- ClearCarrierWaypoint (full teardown).
local function AWPRemoveCarrierUID(tomtom, uid)
    if not tomtom or not uid or type(tomtom.RemoveWaypoint) ~= "function" then
        return
    end
    awpInitiatedRemove = awpInitiatedRemove + 1
    pcall(tomtom.RemoveWaypoint, tomtom, uid)
    awpInitiatedRemove = awpInitiatedRemove - 1
end
NS.Internal = NS.Internal or {}
NS.Internal.CarrierTomTom = NS.Internal.CarrierTomTom or {}
NS.Internal.CarrierTomTom.RemoveCarrierUID = AWPRemoveCarrierUID

function NS.RemoveExternalTomTomWaypointsBySig(sig)
    local tomtom = GetTomTomAddon()
    if type(sig) ~= "string" or not tomtom or type(tomtom.RemoveWaypoint) ~= "function" then
        return
    end

    local count = GetIndexedExternalTomTomWaypointsBySig(sig)
    if count <= 0 then
        return
    end

    awpInitiatedRemove = awpInitiatedRemove + 1
    for index = 1, count do
        local uid = externalWaypointBuffer[index]
        externalWaypointBuffer[index] = nil
        if uid then
            pcall(tomtom.RemoveWaypoint, tomtom, uid)
            UnindexExternalTomTomWaypoint(uid)
        end
    end
    awpInitiatedRemove = awpInitiatedRemove - 1
end
