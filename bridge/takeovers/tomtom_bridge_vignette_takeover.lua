local NS = _G.AzerothWaypointNS
local state = NS.State
NS.Internal.BlizzardTakeovers = NS.Internal.BlizzardTakeovers or {}
local M = NS.Internal.BlizzardTakeovers

local GetActiveManualDestination = NS.GetActiveManualDestination
local ClearActiveManualDestination = NS.ClearActiveManualDestination
local GetGuideVisibilityState = NS.GetGuideVisibilityState
local ReadWaypointCoords = NS.ReadWaypointCoords
local Signature = NS.Signature

state.bridgeVignetteTakeover = state.bridgeVignetteTakeover or {
    adoptionRetrySerial = 0,
}

local vignette = state.bridgeVignetteTakeover

local BLIZZARD_VIGNETTE_KIND = "vignette"
local VIGNETTE_ADOPTION_RETRY_DELAY_SECONDS = 0.05
local VIGNETTE_ADOPTION_RETRY_MAX_ATTEMPTS = 4

-- ============================================================
-- Local helpers
-- ============================================================

local function NormalizeVignetteGUID(vignetteGUID)
    if type(vignetteGUID) == "string" and vignetteGUID ~= "" then
        return vignetteGUID
    end
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

local function ReadMapPositionCoords(position)
    if type(position) ~= "table" then
        return nil, nil
    end
    if type(position.GetXY) == "function" then
        local ok, x, y = pcall(position.GetXY, position)
        if ok and type(x) == "number" and type(y) == "number" then
            return x, y
        end
    end
    local x = type(position.x) == "number" and position.x or nil
    local y = type(position.y) == "number" and position.y or nil
    return x, y
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

-- ============================================================
-- GetCurrentSuperTrackedVignetteGUID
-- ============================================================

local function GetCurrentSuperTrackedVignetteGUID()
    if type(C_SuperTrack) ~= "table"
        or type(C_SuperTrack.GetSuperTrackedVignette) ~= "function"
    then
        return nil
    end
    return NormalizeVignetteGUID(C_SuperTrack.GetSuperTrackedVignette())
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

local function BuildVignetteMapCandidates(preferredMapID)
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

local function SafeGetVignetteInfo(vignetteGUID)
    if type(C_VignetteInfo) ~= "table"
        or type(C_VignetteInfo.GetVignetteInfo) ~= "function"
    then
        return nil
    end
    local ok, info = pcall(C_VignetteInfo.GetVignetteInfo, vignetteGUID)
    if ok and type(info) == "table" then
        return info
    end
end

local function SafeGetVignettePosition(vignetteGUID, mapID)
    if type(C_VignetteInfo) ~= "table"
        or type(C_VignetteInfo.GetVignettePosition) ~= "function"
    then
        return nil, nil
    end
    local ok, position = pcall(C_VignetteInfo.GetVignettePosition, vignetteGUID, mapID)
    if ok then
        return ReadMapPositionCoords(position)
    end
end

local function ResolveVignetteSearchKind(vignetteInfo)
    local vignetteType = type(vignetteInfo) == "table" and vignetteInfo.type or nil
    local atlasName = type(vignetteInfo) == "table"
        and type(vignetteInfo.atlasName) == "string"
        and vignetteInfo.atlasName:lower()
        or nil
    if atlasName and atlasName:find("kill", 1, true) then
        return "zygor_poi_rare"
    end
    if atlasName and (atlasName:find("treasure", 1, true) or atlasName:find("loot", 1, true)) then
        return "zygor_poi_treasure"
    end
    if atlasName then
        return BLIZZARD_VIGNETTE_KIND
    end
    if vignetteType == 0 or vignetteType == "VignetteKillElite" then
        return "zygor_poi_rare"
    end
    if vignetteType == 1 or vignetteType == "VignetteLoot" then
        return "zygor_poi_treasure"
    end
    return BLIZZARD_VIGNETTE_KIND
end

local function ResolveVignetteDestination(vignetteGUID, preferredMapID)
    local normalizedGUID = NormalizeVignetteGUID(vignetteGUID)
    if not normalizedGUID then
        return nil
    end
    local info = SafeGetVignetteInfo(normalizedGUID)
    for _, mapID in ipairs(BuildVignetteMapCandidates(preferredMapID)) do
        local x, y = SafeGetVignettePosition(normalizedGUID, mapID)
        if type(x) == "number" and type(y) == "number" then
            local title = type(info) == "table"
                and type(info.name) == "string"
                and info.name ~= ""
                and info.name
                or ResolveMapTitle(mapID, x, y)
            return mapID, x, y, title, "vignette_info", info
        end
    end
end

-- ============================================================
-- MapPinInfo and destination metadata
-- ============================================================

local function GetVignetteMapPinInfoForMapPinBackedManual(destination)
    if type(destination) ~= "table" or destination.type ~= "manual" then
        return nil
    end
    local identity = type(destination.identity) == "table" and destination.identity or nil
    if type(identity) ~= "table" or identity.kind ~= BLIZZARD_VIGNETTE_KIND then
        return nil
    end
    local atlas = type(destination.mapPinInfo) == "table"
        and type(destination.mapPinInfo.atlas) == "string"
        and destination.mapPinInfo.atlas
        or nil
    if not atlas then
        return nil
    end
    return {
        kind = BLIZZARD_VIGNETTE_KIND,
        atlas = atlas,
    }
end

local function GetBlizzardVignetteGUID(destination)
    if type(destination) ~= "table" or destination.type ~= "manual" then
        return nil
    end
    local identity = type(destination.identity) == "table" and destination.identity or nil
    if type(identity) == "table" and identity.kind == "vignette" then
        return NormalizeVignetteGUID(identity.guid)
    end
    return nil
end

local function GetBlizzardVignetteSignature(destination)
    local vignetteGUID = GetBlizzardVignetteGUID(destination)
    if not vignetteGUID then
        return nil, nil
    end
    local mapID, x, y = ReadWaypointCoords(destination)
    return GetWaypointSignature(mapID, x, y), vignetteGUID
end

local function GetActiveBlizzardVignetteManual()
    local destination = GetActiveManualDestination and GetActiveManualDestination() or nil
    local sig, vignetteGUID = GetBlizzardVignetteSignature(destination)
    if not sig then
        return nil, nil, nil
    end
    return destination, vignetteGUID, sig
end

-- ============================================================
-- Metadata builder
-- ============================================================

local function BuildBlizzardVignetteMeta(vignetteGUID, mapID, x, y, explicit, vignetteInfo)
    local vignetteID = type(vignetteInfo) == "table" and tonumber(vignetteInfo.vignetteID) or nil
    local vignetteType = type(vignetteInfo) == "table" and vignetteInfo.type or nil
    local atlasName = type(vignetteInfo) == "table"
        and type(vignetteInfo.atlasName) == "string"
        and vignetteInfo.atlasName ~= ""
        and vignetteInfo.atlasName
        or nil
    local sig = GetWaypointSignature(mapID, x, y)
    local searchKind = ResolveVignetteSearchKind(vignetteInfo)

    local identity = NS.BuildVignetteIdentity(mapID, x, y, {
        guid = vignetteGUID,
        vignetteKind = BLIZZARD_VIGNETTE_KIND,
        vignetteID = type(vignetteID) == "number" and vignetteID > 0 and vignetteID or nil,
        vignetteType = vignetteType,
        sig = sig,
    })
    return NS.BuildRouteMeta(identity, {
        searchKind = searchKind,
        mapPinInfo = atlasName and {
            kind = BLIZZARD_VIGNETTE_KIND,
            atlas = atlasName,
            sig = sig,
            mapID = mapID,
            x = x,
            y = y,
        } or nil,
    })
end

-- ============================================================
-- Adoption and retry
-- ============================================================

local function CancelVignetteAdoptionRetry()
    vignette.adoptionRetrySerial = (vignette.adoptionRetrySerial or 0) + 1
end

local function AdoptBlizzardVignetteAsManual(vignetteGUID, preferredMapID, explicit)
    local normalizedGUID = NormalizeVignetteGUID(vignetteGUID)
    if not normalizedGUID then
        return false, "invalid_vignette"
    end
    if not (state.init and state.init.playerLoggedIn) then
        return false, "not_ready"
    end
    if type(NS.IsRoutingEnabled) ~= "function" or not NS.IsRoutingEnabled() then
        return false, "routing_disabled"
    end

    local mapID, x, y, title, resolutionSource, vignetteInfo =
        ResolveVignetteDestination(normalizedGUID, preferredMapID)
    if not (type(mapID) == "number" and type(x) == "number" and type(y) == "number") then
        return false, "unresolved"
    end

    local destination, activeGUID, activeSig = GetActiveBlizzardVignetteManual()
    local currentSig = GetWaypointSignature(mapID, x, y)
    if activeGUID == normalizedGUID and activeSig == currentSig then
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
        BuildBlizzardVignetteMeta(normalizedGUID, mapID, x, y, explicit, vignetteInfo),
        explicit == true and { clickContext = { source = "vignette", explicit = true } } or nil
    )
    NS.Log(
        "Vignette takeover route",
        tostring(normalizedGUID),
        tostring(type(vignetteInfo) == "table" and vignetteInfo.vignetteID or "-"),
        tostring(type(vignetteInfo) == "table" and vignetteInfo.type or "-"),
        tostring(mapID),
        tostring(x),
        tostring(y),
        tostring(resolutionSource),
        tostring(explicit == true and "explicit" or "supertrack")
    )
    return true, "routed"
end

local function ShouldRetryVignetteAdoption(vignetteGUID)
    local normalizedGUID = NormalizeVignetteGUID(vignetteGUID)
    if not normalizedGUID then
        return false
    end
    if not (state.init and state.init.playerLoggedIn) then
        return false
    end
    if type(NS.IsRoutingEnabled) ~= "function" or not NS.IsRoutingEnabled() then
        return false
    end
    return GetCurrentSuperTrackedVignetteGUID() == normalizedGUID
end

local function ScheduleVignetteAdoptionRetry(vignetteGUID, preferredMapID, explicit, attempt)
    local normalizedGUID = NormalizeVignetteGUID(vignetteGUID)
    local nextAttempt = type(attempt) == "number" and attempt or 1
    local isExplicit = explicit == true

    if nextAttempt > VIGNETTE_ADOPTION_RETRY_MAX_ATTEMPTS then
        return false
    end
    if not ShouldRetryVignetteAdoption(normalizedGUID) then
        return false
    end

    vignette.adoptionRetrySerial = (vignette.adoptionRetrySerial or 0) + 1
    local retrySerial = vignette.adoptionRetrySerial

    NS.After(VIGNETTE_ADOPTION_RETRY_DELAY_SECONDS, function()
        if vignette.adoptionRetrySerial ~= retrySerial then
            return
        end
        if not ShouldRetryVignetteAdoption(normalizedGUID) then
            return
        end
        local adopted, reason = AdoptBlizzardVignetteAsManual(normalizedGUID, preferredMapID, isExplicit)
        if adopted or reason ~= "unresolved" then
            return
        end
        ScheduleVignetteAdoptionRetry(normalizedGUID, preferredMapID, isExplicit, nextAttempt + 1)
    end)

    return true
end

-- ============================================================
-- Clear
-- ============================================================

local function ClearBlizzardVignetteBackedManual(clearReason)
    local destination, vignetteGUID, sig = GetActiveBlizzardVignetteManual()
    if not destination then
        return false
    end
    local visibilityState = GetGuideVisibilityState and GetGuideVisibilityState() or nil
    if type(ClearActiveManualDestination) ~= "function" then
        return false
    end
    NS.Log("Vignette takeover clear",
        tostring(vignetteGUID), tostring(sig), tostring(clearReason or "system"))
    return ClearActiveManualDestination(visibilityState, clearReason or "system")
end

local function ClearSuperTrackedVignetteIfCurrent(vignetteGUID)
    local normalizedGUID = NormalizeVignetteGUID(vignetteGUID)
    if not normalizedGUID
        or type(C_SuperTrack) ~= "table"
        or type(C_SuperTrack.GetSuperTrackedVignette) ~= "function"
        or type(C_SuperTrack.ClearAllSuperTracked) ~= "function"
    then
        return
    end
    NS.After(0, function()
        if GetCurrentSuperTrackedVignetteGUID() == normalizedGUID then
            if type(NS.WithInternalSuperTrackMutation) == "function" then
                NS.WithInternalSuperTrackMutation(C_SuperTrack.ClearAllSuperTracked)
            else
                C_SuperTrack.ClearAllSuperTracked()
            end
        end
    end)
end

-- ============================================================
-- Vignette changed handler (exported called from hook + ClearAllSuperTracked)
-- ============================================================

function NS.HandleSuperTrackedVignetteChanged(vignetteGUID)
    local normalizedGUID = NormalizeVignetteGUID(vignetteGUID)
    if not normalizedGUID then
        NS.ClearPendingGuideTakeover()
        CancelVignetteAdoptionRetry()
        return ClearBlizzardVignetteBackedManual("explicit")
    end

    local explicit = NS.IsExplicitUserSupertrack()
    if explicit then
        local vignetteInfo = SafeGetVignetteInfo(normalizedGUID)
        local vignetteID = type(vignetteInfo) == "table" and tonumber(vignetteInfo.vignetteID) or nil
        return NS.BeginPendingGuideTakeover({
            kind = "vignette",
            vignetteGUID = normalizedGUID,
            vignetteID = type(vignetteID) == "number" and vignetteID > 0 and vignetteID or nil,
            preferredMapID = NS.GetShownWorldMapID and NS.GetShownWorldMapID(),
        })
    end
    NS.ClearPendingGuideTakeover()
    if GetGuideVisibilityState and GetGuideVisibilityState() == "visible" then
        return false
    end

    local adopted, reason = AdoptBlizzardVignetteAsManual(
        normalizedGUID,
        NS.GetShownWorldMapID and NS.GetShownWorldMapID(),
        explicit
    )
    if adopted then
        CancelVignetteAdoptionRetry()
        return true
    end
    if reason == "unresolved" then
        ScheduleVignetteAdoptionRetry(
            normalizedGUID,
            NS.GetShownWorldMapID and NS.GetShownWorldMapID(),
            explicit
        )
    end
    return false
end

-- ============================================================
-- NS exports
-- ============================================================

function NS.GetBlizzardVignetteGUID(destination)
    return GetBlizzardVignetteGUID(destination)
end

function NS.GetVignetteMapPinInfoForMapPinBackedManual(destination)
    return GetVignetteMapPinInfoForMapPinBackedManual(destination)
end

function NS.ClearSuperTrackedVignetteIfCurrent(vignetteGUID)
    return ClearSuperTrackedVignetteIfCurrent(vignetteGUID)
end

-- ============================================================
-- Kind registration
-- ============================================================

M.BlizzardKinds["vignette"] = {
    onChanged = nil, -- vignette dispatched via NS.HandleSuperTrackedVignetteChanged, not via mapPin
    resolvePending = function(pending)
        local mapID, x, y = ResolveVignetteDestination(pending.vignetteGUID, pending.preferredMapID)
        return mapID, x, y
    end,
    commitPending = function(pending)
        local adopted, reason = AdoptBlizzardVignetteAsManual(
            pending.vignetteGUID, pending.preferredMapID, true)
        if adopted then CancelVignetteAdoptionRetry(); return true end
        if reason == "unresolved" then
            ScheduleVignetteAdoptionRetry(pending.vignetteGUID, pending.preferredMapID, true)
        end
        return false
    end,
    clearOnMapPinCleared = nil, -- vignette cleared via HandleSuperTrackedVignetteChanged only
    startupSync = nil,
}
