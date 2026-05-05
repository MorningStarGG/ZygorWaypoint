local NS = _G.AzerothWaypointNS
local state = NS.State
NS.Internal.BlizzardTakeovers = NS.Internal.BlizzardTakeovers or {}
local M = NS.Internal.BlizzardTakeovers

local GetActiveManualDestination = NS.GetActiveManualDestination
local ClearActiveManualDestination = NS.ClearActiveManualDestination
local GetGuideVisibilityState = NS.GetGuideVisibilityState
local ReadWaypointCoords = NS.ReadWaypointCoords
local Signature = NS.Signature

state.bridgeAreaPoiTakeover = state.bridgeAreaPoiTakeover or {
    adoptionRetrySerial = 0,
}

local areaPoi = state.bridgeAreaPoiTakeover

local AREA_POI_ADOPTION_RETRY_DELAY_SECONDS = 0.05
local AREA_POI_ADOPTION_RETRY_MAX_ATTEMPTS = 4
local BLIZZARD_MAP_PIN_KIND_AREA_POI = "area_poi"

-- ============================================================
-- Local helpers
-- ============================================================

local function NormalizeAreaPoiID(areaPoiID)
    if type(areaPoiID) == "number" and areaPoiID > 0 then
        return areaPoiID
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

local function GetAreaPoiMapPinType()
    return GetSuperTrackingMapPinType("AreaPOI", 0)
end

local function IsAreaPoiMapPinType(pinType)
    return pinType == GetAreaPoiMapPinType()
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

local function BumpChurnCounter(key, amount)
    if type(NS.BumpChurnCounter) == "function" then
        NS.BumpChurnCounter(key, amount)
    end
end

-- ============================================================
-- GetCurrentSuperTrackedAreaPoiID
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

local function GetCurrentSuperTrackedAreaPoiID()
    return NormalizeAreaPoiID(GetCurrentSuperTrackedMapPinID(GetAreaPoiMapPinType()))
end

-- ============================================================
-- Destination resolution
-- ============================================================

local function AddAreaPoiMapCandidate(candidates, seen, mapID)
    if type(mapID) ~= "number" or mapID <= 0 or seen[mapID] then
        return
    end
    seen[mapID] = true
    candidates[#candidates + 1] = mapID
end

local function BuildAreaPoiMapCandidates(areaPoiID, preferredMapID)
    local candidates, seen = {}, {}
    AddAreaPoiMapCandidate(candidates, seen, preferredMapID)
    AddAreaPoiMapCandidate(candidates, seen, NS.GetShownWorldMapID and NS.GetShownWorldMapID())

    if type(C_EventScheduler) == "table"
        and type(C_EventScheduler.GetEventUiMapID) == "function"
    then
        local ok, eventMapID = pcall(C_EventScheduler.GetEventUiMapID, areaPoiID)
        if ok then
            AddAreaPoiMapCandidate(candidates, seen, eventMapID)
        end
    end

    if type(C_Map) == "table" and type(C_Map.GetBestMapForUnit) == "function" then
        local ok, playerMapID = pcall(C_Map.GetBestMapForUnit, "player")
        if ok then
            AddAreaPoiMapCandidate(candidates, seen, playerMapID)
        end
    end

    return candidates
end

local function SafeGetAreaPoiInfo(mapID, areaPoiID)
    if type(C_AreaPoiInfo) ~= "table"
        or type(C_AreaPoiInfo.GetAreaPOIInfo) ~= "function"
    then
        return nil
    end
    local ok, info = pcall(C_AreaPoiInfo.GetAreaPOIInfo, mapID, areaPoiID)
    if ok and type(info) == "table" then
        return info
    end
end

local function ResolveAreaPoiDisplayAtlas(info)
    if type(info) ~= "table" then
        return nil
    end
    local atlasName = type(info.atlasName) == "string" and info.atlasName ~= "" and info.atlasName or nil
    if atlasName == "minimap-genericevent-hornicon" then
        return "UI-EventPoi-Horn-big"
    end
    if atlasName then
        return atlasName
    end
    local textureIndex = type(info.textureIndex) == "number" and info.textureIndex > 0 and info.textureIndex or nil
    if textureIndex then
        return nil
    end
    if info.isCurrentEvent == false then
        return "UI-EventPoi-Horn-big"
    end
    return nil
end

local function ResolveAreaPoiDestination(areaPoiID, preferredMapID)
    local normalizedAreaPoiID = NormalizeAreaPoiID(areaPoiID)
    if not normalizedAreaPoiID then
        return nil
    end

    for _, mapID in ipairs(BuildAreaPoiMapCandidates(normalizedAreaPoiID, preferredMapID)) do
        local info = SafeGetAreaPoiInfo(mapID, normalizedAreaPoiID)
        local x, y = ReadMapPositionCoords(info and info.position)
        if type(x) == "number" and type(y) == "number" then
            local title = info and type(info.name) == "string" and info.name ~= ""
                and info.name
                or ResolveMapTitle(mapID, x, y)
            return mapID, x, y, title, "area_poi_info", info
        end
    end
end

-- ============================================================
-- MapPinInfo
-- ============================================================

local function ReadCanonicalAreaPoiMapPinInfo(destination)
    if type(destination) ~= "table" or destination.type ~= "manual" then
        return nil
    end
    local mapPinInfo = type(destination.mapPinInfo) == "table" and destination.mapPinInfo or nil
    local identity = type(destination.identity) == "table" and destination.identity or nil
    local mapPinKind = mapPinInfo and mapPinInfo.kind or identity and identity.mapPinKind
    local mapPinType = mapPinInfo and mapPinInfo.mapPinType or identity and identity.mapPinType
    if mapPinKind ~= BLIZZARD_MAP_PIN_KIND_AREA_POI
        or type(mapPinType) == "number" and not IsAreaPoiMapPinType(mapPinType)
    then
        return nil
    end

    local areaPoiID = NormalizeAreaPoiID(mapPinInfo and mapPinInfo.mapPinID or identity and identity.mapPinID)
    if not areaPoiID then
        return nil
    end

    local mapID, x, y = ReadWaypointCoords(destination)
    local mapPinSig = nil
    local identitySig = nil
    local mapPinMapID = nil
    local mapPinX = nil
    local mapPinY = nil
    local atlas = nil
    local rawAtlas = nil
    local description = nil
    local isCurrentEvent = nil
    local tooltipWidgetSet = nil
    local textureIndex = nil

    if type(mapPinInfo) == "table" then
        mapPinSig = type(mapPinInfo["sig"]) == "string" and mapPinInfo["sig"] or nil
        mapPinMapID = type(mapPinInfo["mapID"]) == "number" and mapPinInfo["mapID"] or nil
        mapPinX = type(mapPinInfo["x"]) == "number" and mapPinInfo["x"] or nil
        mapPinY = type(mapPinInfo["y"]) == "number" and mapPinInfo["y"] or nil
        atlas = type(mapPinInfo["atlas"]) == "string" and mapPinInfo["atlas"] or nil
        rawAtlas = type(mapPinInfo["rawAtlas"]) == "string" and mapPinInfo["rawAtlas"] or nil
        description = type(mapPinInfo["description"]) == "string" and mapPinInfo["description"] or nil
        isCurrentEvent = mapPinInfo["isCurrentEvent"] == true or nil
        tooltipWidgetSet = type(mapPinInfo["tooltipWidgetSet"]) == "number" and mapPinInfo["tooltipWidgetSet"] or nil
        textureIndex = type(mapPinInfo["textureIndex"]) == "number"
            and mapPinInfo["textureIndex"] > 0
            and mapPinInfo["textureIndex"]
            or nil
    end
    if type(identity) == "table" then
        identitySig = type(identity["sig"]) == "string" and identity["sig"] or nil
    end

    return {
        kind = BLIZZARD_MAP_PIN_KIND_AREA_POI,
        mapPinType = GetAreaPoiMapPinType(),
        mapPinID = areaPoiID,
        sig = mapPinSig or identitySig or GetWaypointSignature(mapID, x, y),
        mapID = mapPinMapID or mapID,
        x = mapPinX or x,
        y = mapPinY or y,
        atlas = atlas,
        rawAtlas = rawAtlas,
        description = description,
        isCurrentEvent = isCurrentEvent,
        tooltipWidgetSet = tooltipWidgetSet,
        textureIndex = textureIndex,
    }
end

local function GetAreaPoiMapPinInfoForMapPinBackedManual(destination)
    return ReadCanonicalAreaPoiMapPinInfo(destination)
end

local function GetAreaPoiIDForMapPinBackedManual(destination)
    local mapPinInfo = GetAreaPoiMapPinInfoForMapPinBackedManual(destination)
    return mapPinInfo and mapPinInfo.mapPinID or nil
end

local function GetBlizzardAreaPoiSignature(destination)
    local mapPinInfo = GetAreaPoiMapPinInfoForMapPinBackedManual(destination)
    if not mapPinInfo then
        return nil, nil
    end
    if type(mapPinInfo.sig) == "string" then
        return mapPinInfo.sig, mapPinInfo.mapPinID
    end
    local mapID, x, y = ReadWaypointCoords(destination)
    return GetWaypointSignature(mapID, x, y), mapPinInfo.mapPinID
end

local function GetActiveBlizzardAreaPoiManual()
    local destination = GetActiveManualDestination and GetActiveManualDestination() or nil
    local sig, areaPoiID = GetBlizzardAreaPoiSignature(destination)
    if not sig then
        return nil, nil, nil
    end
    return destination, areaPoiID, sig
end

-- ============================================================
-- Metadata builder
-- ============================================================

local function BuildBlizzardAreaPoiMeta(areaPoiID, mapID, x, y, explicit, areaPoiInfo)
    local atlasName = type(areaPoiInfo) == "table"
        and type(areaPoiInfo.atlasName) == "string"
        and areaPoiInfo.atlasName ~= ""
        and areaPoiInfo.atlasName
        or nil
    local displayAtlas = ResolveAreaPoiDisplayAtlas(areaPoiInfo)
    local textureIndex = type(areaPoiInfo) == "table"
        and type(areaPoiInfo.textureIndex) == "number"
        and areaPoiInfo.textureIndex > 0
        and areaPoiInfo.textureIndex
        or nil
    local description = type(areaPoiInfo) == "table"
        and type(areaPoiInfo.description) == "string"
        and areaPoiInfo.description ~= ""
        and areaPoiInfo.description
        or nil
    local tooltipWidgetSet = type(areaPoiInfo) == "table"
        and type(areaPoiInfo.tooltipWidgetSet) == "number"
        and areaPoiInfo.tooltipWidgetSet > 0
        and areaPoiInfo.tooltipWidgetSet
        or nil
    local sig = GetWaypointSignature(mapID, x, y)

    local mapPinInfo = NS.BuildMapPinInfo(BLIZZARD_MAP_PIN_KIND_AREA_POI, mapID, x, y, {
        mapPinType = GetAreaPoiMapPinType(),
        mapPinID = areaPoiID,
        sig = sig,
        atlas = displayAtlas,
        rawAtlas = atlasName,
        textureIndex = textureIndex,
        description = description,
        isCurrentEvent = type(areaPoiInfo) == "table" and areaPoiInfo.isCurrentEvent == true or nil,
        tooltipWidgetSet = tooltipWidgetSet,
    })
    return NS.BuildRouteMeta(NS.BuildMapPinIdentity(mapPinInfo), {
        mapPinInfo = mapPinInfo,
    })
end

-- ============================================================
-- Adoption and retry
-- ============================================================

local function CancelAreaPoiAdoptionRetry()
    areaPoi.adoptionRetrySerial = (areaPoi.adoptionRetrySerial or 0) + 1
end

local function AdoptBlizzardAreaPoiAsManual(areaPoiID, preferredMapID, explicit)
    local normalizedAreaPoiID = NormalizeAreaPoiID(areaPoiID)
    if not normalizedAreaPoiID then
        return false, "invalid_area_poi"
    end
    if not (state.init and state.init.playerLoggedIn) then
        return false, "not_ready"
    end
    if type(NS.IsRoutingEnabled) ~= "function" or not NS.IsRoutingEnabled() then
        return false, "routing_disabled"
    end

    local mapID, x, y, title, resolutionSource, areaPoiInfo =
        ResolveAreaPoiDestination(normalizedAreaPoiID, preferredMapID)
    if not (type(mapID) == "number" and type(x) == "number" and type(y) == "number") then
        return false, "unresolved"
    end

    local destination, activeAreaPoiID, activeSig = GetActiveBlizzardAreaPoiManual()
    local currentSig = GetWaypointSignature(mapID, x, y)
    if activeAreaPoiID == normalizedAreaPoiID and activeSig == currentSig then
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
        BuildBlizzardAreaPoiMeta(normalizedAreaPoiID, mapID, x, y, explicit, areaPoiInfo),
        explicit == true and { clickContext = { source = "area_poi", explicit = true } } or nil
    )
    NS.Log(
        "AreaPOI takeover route",
        tostring(normalizedAreaPoiID),
        tostring(mapID),
        tostring(x),
        tostring(y),
        tostring(resolutionSource),
        tostring(explicit == true and "explicit" or "supertrack")
    )
    return true, "routed"
end

local function ShouldRetryAreaPoiAdoption(areaPoiID)
    local normalizedAreaPoiID = NormalizeAreaPoiID(areaPoiID)
    if not normalizedAreaPoiID then
        return false
    end
    if not (state.init and state.init.playerLoggedIn) then
        return false
    end
    if type(NS.IsRoutingEnabled) ~= "function" or not NS.IsRoutingEnabled() then
        return false
    end
    return GetCurrentSuperTrackedAreaPoiID() == normalizedAreaPoiID
end

local function ScheduleAreaPoiAdoptionRetry(areaPoiID, preferredMapID, explicit, attempt)
    local normalizedAreaPoiID = NormalizeAreaPoiID(areaPoiID)
    local nextAttempt = type(attempt) == "number" and attempt or 1
    local isExplicit = explicit == true

    if nextAttempt > AREA_POI_ADOPTION_RETRY_MAX_ATTEMPTS then
        return false
    end
    if not ShouldRetryAreaPoiAdoption(normalizedAreaPoiID) then
        return false
    end

    areaPoi.adoptionRetrySerial = (areaPoi.adoptionRetrySerial or 0) + 1
    local retrySerial = areaPoi.adoptionRetrySerial

    NS.After(AREA_POI_ADOPTION_RETRY_DELAY_SECONDS, function()
        if areaPoi.adoptionRetrySerial ~= retrySerial then
            return
        end
        if not ShouldRetryAreaPoiAdoption(normalizedAreaPoiID) then
            return
        end
        local adopted, reason = AdoptBlizzardAreaPoiAsManual(normalizedAreaPoiID, preferredMapID, isExplicit)
        if adopted or reason ~= "unresolved" then
            return
        end
        ScheduleAreaPoiAdoptionRetry(normalizedAreaPoiID, preferredMapID, isExplicit, nextAttempt + 1)
    end)

    return true
end

-- ============================================================
-- Clear
-- ============================================================

local function ClearBlizzardAreaPoiBackedManual(clearReason)
    local destination, areaPoiID, sig = GetActiveBlizzardAreaPoiManual()
    if not destination then
        return false
    end
    local visibilityState = GetGuideVisibilityState and GetGuideVisibilityState() or nil
    if type(ClearActiveManualDestination) ~= "function" then
        return false
    end
    NS.Log("AreaPOI takeover clear",
        tostring(areaPoiID), tostring(sig), tostring(clearReason or "system"))
    return ClearActiveManualDestination(visibilityState, clearReason or "system")
end

local function ClearSuperTrackedAreaPoiIfCurrent(areaPoiID)
    local normalizedAreaPoiID = NormalizeAreaPoiID(areaPoiID)
    if not normalizedAreaPoiID
        or type(C_SuperTrack) ~= "table"
        or type(C_SuperTrack.GetSuperTrackedMapPin) ~= "function"
        or type(C_SuperTrack.ClearSuperTrackedMapPin) ~= "function"
    then
        return
    end
    NS.After(0, function()
        if GetCurrentSuperTrackedAreaPoiID() == normalizedAreaPoiID then
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

local function HandleAreaPoiMapPinChanged(pinID, preferredMapID, explicit)
    local areaPoiID = NormalizeAreaPoiID(pinID)
    if not areaPoiID then
        NS.ClearPendingGuideTakeover()
        CancelAreaPoiAdoptionRetry()
        return false
    end

    if explicit then
        return NS.BeginPendingGuideTakeover({
            kind = "area_poi",
            areaPoiID = areaPoiID,
            preferredMapID = preferredMapID,
        })
    end
    NS.ClearPendingGuideTakeover()
    if GetGuideVisibilityState and GetGuideVisibilityState() == "visible" then
        return false
    end

    local adopted, reason = AdoptBlizzardAreaPoiAsManual(areaPoiID, preferredMapID, explicit)
    if adopted then
        CancelAreaPoiAdoptionRetry()
        return true
    end
    if reason == "unresolved" then
        ScheduleAreaPoiAdoptionRetry(areaPoiID, preferredMapID, explicit)
    end
    return false
end

-- ============================================================
-- NS exports
-- ============================================================

function NS.GetAreaPoiIDForMapPinBackedManual(destination)
    return GetAreaPoiIDForMapPinBackedManual(destination)
end

function NS.GetAreaPoiMapPinInfoForMapPinBackedManual(destination)
    return GetAreaPoiMapPinInfoForMapPinBackedManual(destination)
end

function NS.ClearSuperTrackedAreaPoiIfCurrent(areaPoiID)
    return ClearSuperTrackedAreaPoiIfCurrent(areaPoiID)
end

-- ============================================================
-- Kind registration
-- ============================================================

M.BlizzardKinds["area_poi"] = {
    onChanged = HandleAreaPoiMapPinChanged,
    resolvePending = function(pending)
        local mapID, x, y = ResolveAreaPoiDestination(pending.areaPoiID, pending.preferredMapID)
        return mapID, x, y
    end,
    commitPending = function(pending)
        local adopted, reason = AdoptBlizzardAreaPoiAsManual(
            pending.areaPoiID, pending.preferredMapID, true)
        if adopted then CancelAreaPoiAdoptionRetry(); return true end
        if reason == "unresolved" then
            ScheduleAreaPoiAdoptionRetry(pending.areaPoiID, pending.preferredMapID, true)
        end
        return false
    end,
    clearOnMapPinCleared = function()
        CancelAreaPoiAdoptionRetry()
        return ClearBlizzardAreaPoiBackedManual("explicit")
    end,
    startupSync = nil,
}
