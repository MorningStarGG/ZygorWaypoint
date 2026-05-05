local NS = _G.AzerothWaypointNS
local state = NS.State
NS.Internal.BlizzardTakeovers = NS.Internal.BlizzardTakeovers or {}
local M = NS.Internal.BlizzardTakeovers

local GetActiveManualDestination = NS.GetActiveManualDestination
local ClearActiveManualDestination = NS.ClearActiveManualDestination
local GetGuideVisibilityState = NS.GetGuideVisibilityState
local ReadWaypointCoords = NS.ReadWaypointCoords
local Signature = NS.Signature

state.bridgeTaxiTakeover = state.bridgeTaxiTakeover or {
    adoptionRetrySerial = 0,
}

local taxi = state.bridgeTaxiTakeover

local BLIZZARD_MAP_PIN_KIND_TAXI_NODE = "taxi_node"
local TAXI_NODE_ADOPTION_RETRY_DELAY_SECONDS = 0.05
local TAXI_NODE_ADOPTION_RETRY_MAX_ATTEMPTS = 4

-- ============================================================
-- Local helpers
-- ============================================================

local function NormalizeTaxiNodeID(nodeID)
    if type(nodeID) == "number" and nodeID > 0 then
        return nodeID
    end
end

local function GetSuperTrackingMapPinType(typeKey, fallback)
    local mapPinTypes = type(Enum) == "table"
        and type(Enum.SuperTrackingMapPinType) == "table"
        and Enum.SuperTrackingMapPinType
        or nil
    local pinType = type(mapPinTypes) == "table" and mapPinTypes[typeKey] or nil
    if type(pinType) == "number" then
        return pinType
    end
    return fallback
end

local function GetTaxiNodeMapPinType()
    return GetSuperTrackingMapPinType("TaxiNode", 2)
end

local function IsTaxiNodeMapPinType(pinType)
    return pinType == GetTaxiNodeMapPinType()
end

local function GetWaypointSignature(mapID, x, y)
    if type(Signature) ~= "function" then
        return nil
    end
    if type(mapID) ~= "number" or type(x) ~= "number" or type(y) ~= "number" then
        return nil
    end
    return Signature(mapID, x, y)
end

local function ResolveMapTitle(mapID, x, y)
    local mapInfo = type(C_Map) == "table"
        and type(C_Map.GetMapInfo) == "function"
        and C_Map.GetMapInfo(mapID)
        or nil
    local mapName = mapInfo and mapInfo.name or nil
    if type(mapName) == "string" and mapName ~= "" then
        if type(x) == "number" and type(y) == "number" then
            return string.format("%s %.0f, %.0f", mapName, x * 100, y * 100)
        end
        return mapName
    end
    if type(mapID) == "number" then
        if type(x) == "number" and type(y) == "number" then
            return string.format("Waypoint %d %.0f, %.0f", mapID, x * 100, y * 100)
        end
        return "Waypoint " .. tostring(mapID)
    end
    return "Waypoint"
end

local function BumpChurnCounter(key, amount)
    if type(NS.BumpChurnCounter) == "function" then
        NS.BumpChurnCounter(key, amount)
    end
end

-- ============================================================
-- GetCurrentSuperTrackedTaxiNodeID
-- ============================================================

local function GetCurrentSuperTrackedMapPinID(expectedPinType)
    if type(C_SuperTrack) ~= "table"
        or type(C_SuperTrack.GetSuperTrackedMapPin) ~= "function"
    then
        return nil
    end
    local pinType, pinID = C_SuperTrack.GetSuperTrackedMapPin()
    if pinType == expectedPinType and type(pinID) == "number" and pinID > 0 then
        return pinID
    end
end

local function GetCurrentSuperTrackedTaxiNodeID()
    return NormalizeTaxiNodeID(GetCurrentSuperTrackedMapPinID(GetTaxiNodeMapPinType()))
end

-- ============================================================
-- Destination resolution
-- ============================================================

local function AddMapCandidate(candidates, seen, mapID)
    if type(mapID) ~= "number" or mapID <= 0 or seen[mapID] then
        return
    end
    seen[mapID] = true
    candidates[#candidates + 1] = mapID
end

local function BuildTaxiNodeMapCandidates(preferredMapID)
    local candidates, seen = {}, {}
    AddMapCandidate(candidates, seen, preferredMapID)
    AddMapCandidate(candidates, seen, NS.GetShownWorldMapID and NS.GetShownWorldMapID())
    if type(C_Map) == "table" and type(C_Map.GetBestMapForUnit) == "function" then
        local ok, playerMapID = pcall(C_Map.GetBestMapForUnit, "player")
        if ok then
            AddMapCandidate(candidates, seen, playerMapID)
        end
    end
    return candidates
end

local function ResolveTaxiNodeDestination(nodeID, preferredMapID)
    local normalizedNodeID = NormalizeTaxiNodeID(nodeID)
    if not normalizedNodeID then return nil end
    if type(C_TaxiMap) ~= "table" or type(C_TaxiMap.GetTaxiNodesForMap) ~= "function" then
        return nil
    end
    for _, mapID in ipairs(BuildTaxiNodeMapCandidates(preferredMapID)) do
        local nodes = C_TaxiMap.GetTaxiNodesForMap(mapID)
        if type(nodes) == "table" then
            for _, node in ipairs(nodes) do
                if node.nodeID == normalizedNodeID then
                    local pos = node.position
                    local x = type(pos) == "table" and pos.x or nil
                    local y = type(pos) == "table" and pos.y or nil
                    if type(x) == "number" and type(y) == "number"
                        and x >= 0 and x <= 1 and y >= 0 and y <= 1
                    then
                        local title = type(node.name) == "string" and node.name ~= "" and node.name
                            or ResolveMapTitle(mapID, x, y)
                        return mapID, x, y, title
                    end
                end
            end
        end
    end
end

-- ============================================================
-- MapPinInfo
-- ============================================================

local function ReadCanonicalTaxiNodeMapPinInfo(destination)
    if type(destination) ~= "table" or destination.type ~= "manual" then
        return nil
    end
    local mapPinInfo = type(destination.mapPinInfo) == "table" and destination.mapPinInfo or nil
    local identity = type(destination.identity) == "table" and destination.identity or nil
    local mapPinKind = mapPinInfo and mapPinInfo.kind or identity and identity.mapPinKind
    local mapPinType = mapPinInfo and mapPinInfo.mapPinType or identity and identity.mapPinType
    if mapPinKind ~= BLIZZARD_MAP_PIN_KIND_TAXI_NODE
        or type(mapPinType) == "number" and not IsTaxiNodeMapPinType(mapPinType)
    then
        return nil
    end
    local nodeID = NormalizeTaxiNodeID(mapPinInfo and mapPinInfo.mapPinID or identity and identity.mapPinID)
    if not nodeID then return nil end

    local mapID, x, y = ReadWaypointCoords(destination)
    local mapPinSig = nil
    local identitySig = nil
    local mapPinMapID = nil
    local mapPinX = nil
    local mapPinY = nil

    if type(mapPinInfo) == "table" then
        mapPinSig = type(mapPinInfo["sig"]) == "string" and mapPinInfo["sig"] or nil
        mapPinMapID = type(mapPinInfo["mapID"]) == "number" and mapPinInfo["mapID"] or nil
        mapPinX = type(mapPinInfo["x"]) == "number" and mapPinInfo["x"] or nil
        mapPinY = type(mapPinInfo["y"]) == "number" and mapPinInfo["y"] or nil
    end
    if type(identity) == "table" then
        identitySig = type(identity["sig"]) == "string" and identity["sig"] or nil
    end

    return {
        kind = BLIZZARD_MAP_PIN_KIND_TAXI_NODE,
        mapPinType = GetTaxiNodeMapPinType(),
        mapPinID = nodeID,
        sig = mapPinSig or identitySig or GetWaypointSignature(mapID, x, y),
        mapID = mapPinMapID or mapID,
        x = mapPinX or x,
        y = mapPinY or y,
    }
end

local function GetTaxiNodeMapPinInfoForMapPinBackedManual(destination)
    return ReadCanonicalTaxiNodeMapPinInfo(destination)
end

local function GetTaxiNodeIDForMapPinBackedManual(destination)
    local mapPinInfo = GetTaxiNodeMapPinInfoForMapPinBackedManual(destination)
    return mapPinInfo and mapPinInfo.mapPinID or nil
end

local function GetBlizzardTaxiNodeSignature(destination)
    local mapPinInfo = GetTaxiNodeMapPinInfoForMapPinBackedManual(destination)
    if not mapPinInfo then return nil, nil end
    if type(mapPinInfo.sig) == "string" then
        return mapPinInfo.sig, mapPinInfo.mapPinID
    end
    local mapID, x, y = ReadWaypointCoords(destination)
    return GetWaypointSignature(mapID, x, y), mapPinInfo.mapPinID
end

local function GetActiveBlizzardTaxiNodeManual()
    local destination = GetActiveManualDestination and GetActiveManualDestination() or nil
    local sig, nodeID = GetBlizzardTaxiNodeSignature(destination)
    if not sig then return nil, nil, nil end
    return destination, nodeID, sig
end

-- ============================================================
-- Metadata builder
-- ============================================================

local function BuildBlizzardTaxiNodeMeta(nodeID, mapID, x, y, explicit)
    local sig = GetWaypointSignature(mapID, x, y)
    local mapPinInfo = NS.BuildMapPinInfo(BLIZZARD_MAP_PIN_KIND_TAXI_NODE, mapID, x, y, {
        mapPinType = GetTaxiNodeMapPinType(),
        mapPinID = nodeID,
        sig = sig,
    })
    return NS.BuildRouteMeta(NS.BuildMapPinIdentity(mapPinInfo), {
        mapPinInfo = mapPinInfo,
    })
end

-- ============================================================
-- Adoption and retry
-- ============================================================

local function CancelTaxiNodeAdoptionRetry()
    taxi.adoptionRetrySerial = (taxi.adoptionRetrySerial or 0) + 1
end

local function AdoptBlizzardTaxiNodeAsManual(nodeID, preferredMapID, explicit)
    local normalizedNodeID = NormalizeTaxiNodeID(nodeID)
    if not normalizedNodeID then
        return false, "invalid_node"
    end
    if not (state.init and state.init.playerLoggedIn) then
        return false, "not_ready"
    end
    if type(NS.IsRoutingEnabled) ~= "function" or not NS.IsRoutingEnabled() then
        return false, "routing_disabled"
    end

    local mapID, x, y, title = ResolveTaxiNodeDestination(normalizedNodeID, preferredMapID)
    if not (type(mapID) == "number" and type(x) == "number" and type(y) == "number") then
        return false, "unresolved"
    end

    local destination, activeNodeID, activeSig = GetActiveBlizzardTaxiNodeManual()
    local currentSig = GetWaypointSignature(mapID, x, y)
    if activeNodeID == normalizedNodeID and activeSig == currentSig then
        local activeTitle = type(destination) == "table" and destination.title or nil
        if activeTitle == title then
            return false, "already_current"
        end
    end

    NS.RequestManualRoute(
        mapID,
        x,
        y,
        title,
        BuildBlizzardTaxiNodeMeta(normalizedNodeID, mapID, x, y, explicit),
        explicit == true and { clickContext = { source = "taxi_node", explicit = true } } or nil
    )
    NS.Log(
        "TaxiNode takeover route",
        tostring(normalizedNodeID),
        tostring(mapID),
        tostring(x),
        tostring(y),
        tostring(explicit == true and "explicit" or "supertrack")
    )
    return true, "routed"
end

local function ShouldRetryTaxiNodeAdoption(nodeID)
    local normalizedNodeID = NormalizeTaxiNodeID(nodeID)
    if not normalizedNodeID then return false end
    if not (state.init and state.init.playerLoggedIn) then return false end
    if type(NS.IsRoutingEnabled) ~= "function" or not NS.IsRoutingEnabled() then return false end
    return GetCurrentSuperTrackedTaxiNodeID() == normalizedNodeID
end

local function ScheduleTaxiNodeAdoptionRetry(nodeID, preferredMapID, explicit, attempt)
    local normalizedNodeID = NormalizeTaxiNodeID(nodeID)
    local nextAttempt = type(attempt) == "number" and attempt or 1
    local isExplicit = explicit == true

    if nextAttempt > TAXI_NODE_ADOPTION_RETRY_MAX_ATTEMPTS then return false end
    if not ShouldRetryTaxiNodeAdoption(normalizedNodeID) then return false end

    taxi.adoptionRetrySerial = (taxi.adoptionRetrySerial or 0) + 1
    local retrySerial = taxi.adoptionRetrySerial

    NS.After(TAXI_NODE_ADOPTION_RETRY_DELAY_SECONDS, function()
        if taxi.adoptionRetrySerial ~= retrySerial then return end
        if not ShouldRetryTaxiNodeAdoption(normalizedNodeID) then return end
        local adopted, reason = AdoptBlizzardTaxiNodeAsManual(normalizedNodeID, preferredMapID, isExplicit)
        if adopted or reason ~= "unresolved" then return end
        ScheduleTaxiNodeAdoptionRetry(normalizedNodeID, preferredMapID, isExplicit, nextAttempt + 1)
    end)

    return true
end

-- ============================================================
-- Clear
-- ============================================================

local function ClearBlizzardTaxiNodeBackedManual(clearReason)
    local destination, nodeID, sig = GetActiveBlizzardTaxiNodeManual()
    if not destination then return false end
    local visibilityState = GetGuideVisibilityState and GetGuideVisibilityState() or nil
    if type(ClearActiveManualDestination) ~= "function" then return false end
    NS.Log("TaxiNode takeover clear",
        tostring(nodeID), tostring(sig), tostring(clearReason or "system"))
    return ClearActiveManualDestination(visibilityState, clearReason or "system")
end

local function ClearSuperTrackedTaxiNodeIfCurrent(nodeID)
    local normalizedNodeID = NormalizeTaxiNodeID(nodeID)
    if not normalizedNodeID
        or type(C_SuperTrack) ~= "table"
        or type(C_SuperTrack.GetSuperTrackedMapPin) ~= "function"
        or type(C_SuperTrack.ClearSuperTrackedMapPin) ~= "function"
    then
        return
    end
    NS.After(0, function()
        if GetCurrentSuperTrackedTaxiNodeID() == normalizedNodeID then
            if type(NS.WithInternalSuperTrackMutation) == "function" then
                NS.WithInternalSuperTrackMutation(C_SuperTrack.ClearSuperTrackedMapPin)
            else
                C_SuperTrack.ClearSuperTrackedMapPin()
            end
        end
    end)
end

-- ============================================================
-- Pin changed handler
-- ============================================================

local function HandleTaxiNodeMapPinChanged(pinID, preferredMapID, explicit)
    local nodeID = NormalizeTaxiNodeID(pinID)
    if not nodeID then
        NS.ClearPendingGuideTakeover()
        CancelTaxiNodeAdoptionRetry()
        return false
    end

    if explicit then
        return NS.BeginPendingGuideTakeover({
            kind = "taxi_node",
            nodeID = nodeID,
            preferredMapID = preferredMapID,
        })
    end
    NS.ClearPendingGuideTakeover()
    if GetGuideVisibilityState and GetGuideVisibilityState() == "visible" then
        return false
    end

    local adopted, reason = AdoptBlizzardTaxiNodeAsManual(nodeID, preferredMapID, explicit)
    if adopted then
        CancelTaxiNodeAdoptionRetry()
        return true
    end
    if reason == "unresolved" then
        ScheduleTaxiNodeAdoptionRetry(nodeID, preferredMapID, explicit)
    end
    return false
end

-- ============================================================
-- NS exports
-- ============================================================

function NS.GetTaxiNodeIDForMapPinBackedManual(destination)
    return GetTaxiNodeIDForMapPinBackedManual(destination)
end

function NS.GetTaxiNodeMapPinInfoForMapPinBackedManual(destination)
    return GetTaxiNodeMapPinInfoForMapPinBackedManual(destination)
end

function NS.ClearSuperTrackedTaxiNodeIfCurrent(nodeID)
    return ClearSuperTrackedTaxiNodeIfCurrent(nodeID)
end

-- ============================================================
-- Kind registration
-- ============================================================

M.BlizzardKinds["taxi_node"] = {
    onChanged = HandleTaxiNodeMapPinChanged,
    resolvePending = function(pending)
        local mapID, x, y = ResolveTaxiNodeDestination(pending.nodeID, pending.preferredMapID)
        return mapID, x, y
    end,
    commitPending = function(pending)
        local adopted, reason = AdoptBlizzardTaxiNodeAsManual(
            pending.nodeID, pending.preferredMapID, true)
        if adopted then CancelTaxiNodeAdoptionRetry(); return true end
        if reason == "unresolved" then
            ScheduleTaxiNodeAdoptionRetry(pending.nodeID, pending.preferredMapID, true)
        end
        return false
    end,
    clearOnMapPinCleared = function()
        CancelTaxiNodeAdoptionRetry()
        return ClearBlizzardTaxiNodeBackedManual("explicit")
    end,
    startupSync = nil,
}
