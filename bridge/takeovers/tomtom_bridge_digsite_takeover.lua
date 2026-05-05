local NS = _G.AzerothWaypointNS
local state = NS.State

NS.Internal = NS.Internal or {}

NS.Internal.BlizzardTakeovers = NS.Internal.BlizzardTakeovers or {}
local M = NS.Internal.BlizzardTakeovers

M.BlizzardKinds = M.BlizzardKinds or {}

state.bridgeDigSiteTakeover = state.bridgeDigSiteTakeover or {
    adoptionRetrySerial = 0,
    lastDigSiteID = nil,
}

local digSite = state.bridgeDigSiteTakeover

local GetActiveManualDestination = NS.GetActiveManualDestination
local ClearActiveManualDestination = NS.ClearActiveManualDestination
local GetGuideVisibilityState = NS.GetGuideVisibilityState
local ReadWaypointCoords = NS.ReadWaypointCoords
local Signature = NS.Signature

local DIGSITE_ADOPTION_RETRY_DELAY_SECONDS = 0.05
local DIGSITE_ADOPTION_RETRY_MAX_ATTEMPTS = 4
local BLIZZARD_MAP_PIN_KIND_DIG_SITE = "dig_site"
local DIGSITE_MAP_PIN_TYPE = Enum.SuperTrackingMapPinType and Enum.SuperTrackingMapPinType.DigSite or 3

-- ============================================================
-- Helpers
-- ============================================================

local function NormalizeDigSiteID(digSiteID)
    if type(digSiteID) == "number" and digSiteID > 0 then
        return digSiteID
    end
end

local function GetWaypointSignature(mapID, x, y)
    if type(Signature) ~= "function" then return nil end
    if type(mapID) ~= "number" or type(x) ~= "number" or type(y) ~= "number" then return nil end
    return Signature(mapID, x, y)
end

local function GetCurrentSuperTrackedDigSiteID()
    if type(C_SuperTrack) ~= "table" or type(C_SuperTrack.GetSuperTrackedMapPin) ~= "function" then
        return nil
    end
    local pinType, pinID = C_SuperTrack.GetSuperTrackedMapPin()
    if pinType == DIGSITE_MAP_PIN_TYPE and type(pinID) == "number" and pinID > 0 then
        return pinID
    end
end

-- ============================================================
-- Resolution
-- ============================================================

local function BuildDigSiteMapCandidates(preferredMapID)
    local candidates, seen = {}, {}
    local function add(mapID)
        if type(mapID) ~= "number" or mapID <= 0 or seen[mapID] then return end
        seen[mapID] = true
        candidates[#candidates + 1] = mapID
    end
    add(preferredMapID)
    local worldMapFrame = rawget(_G, "WorldMapFrame")
    if worldMapFrame
        and type(worldMapFrame.IsShown) == "function"
        and worldMapFrame:IsShown()
        and type(worldMapFrame.GetMapID) == "function"
    then
        local ok, mapID = pcall(worldMapFrame.GetMapID, worldMapFrame)
        if ok and type(mapID) == "number" then add(mapID) end
    end
    if type(C_Map) == "table" and type(C_Map.GetBestMapForUnit) == "function" then
        local ok, mapID = pcall(C_Map.GetBestMapForUnit, "player")
        if ok then add(mapID) end
    end
    return candidates
end

local function ResolveDigSiteDestination(digSiteID, preferredMapID)
    local normalizedID = NormalizeDigSiteID(digSiteID)
    if not normalizedID then return nil end
    if type(C_ResearchInfo) ~= "table" or type(C_ResearchInfo.GetDigSitesForMap) ~= "function" then
        return nil
    end

    for _, mapID in ipairs(BuildDigSiteMapCandidates(preferredMapID)) do
        local ok, sites = pcall(C_ResearchInfo.GetDigSitesForMap, mapID)
        if ok and type(sites) == "table" then
            for _, site in ipairs(sites) do
                if type(site) == "table" and site.researchSiteID == normalizedID then
                    local pos = site.position
                    local x = type(pos) == "table" and pos.x or nil
                    local y = type(pos) == "table" and pos.y or nil
                    if type(x) == "number" and type(y) == "number" then
                        return mapID, x, y
                    end
                end
            end
        end
    end
end

-- ============================================================
-- MapPinInfo getters
-- ============================================================

local function ReadCanonicalDigSiteMapPinInfo(destination)
    if type(destination) ~= "table" or destination.type ~= "manual" then return nil end
    local mapPinInfo = type(destination.mapPinInfo) == "table" and destination.mapPinInfo or nil
    local identity = type(destination.identity) == "table" and destination.identity or nil
    local mapPinKind = mapPinInfo and mapPinInfo.kind or identity and identity.mapPinKind
    local mapPinType = mapPinInfo and mapPinInfo.mapPinType or identity and identity.mapPinType
    if mapPinKind ~= BLIZZARD_MAP_PIN_KIND_DIG_SITE
        or type(mapPinType) == "number" and mapPinType ~= DIGSITE_MAP_PIN_TYPE
    then
        return nil
    end
    local digSiteID = NormalizeDigSiteID(mapPinInfo and mapPinInfo.mapPinID or identity and identity.mapPinID)
    if not digSiteID then return nil end

    local mapID, x, y = ReadWaypointCoords(destination)
    local mapPinSig = type(mapPinInfo) == "table" and rawget(mapPinInfo, "sig") or nil
    local mapPinMapID = type(mapPinInfo) == "table" and rawget(mapPinInfo, "mapID") or nil
    local mapPinX = type(mapPinInfo) == "table" and rawget(mapPinInfo, "x") or nil
    local mapPinY = type(mapPinInfo) == "table" and rawget(mapPinInfo, "y") or nil
    local identitySig = type(identity) == "table" and rawget(identity, "sig") or nil
    return {
        kind = BLIZZARD_MAP_PIN_KIND_DIG_SITE,
        mapPinType = DIGSITE_MAP_PIN_TYPE,
        mapPinID = digSiteID,
        sig = type(mapPinSig) == "string" and mapPinSig
            or type(identitySig) == "string" and identitySig
            or GetWaypointSignature(mapID, x, y),
        mapID = type(mapPinMapID) == "number" and mapPinMapID or mapID,
        x = type(mapPinX) == "number" and mapPinX or x,
        y = type(mapPinY) == "number" and mapPinY or y,
    }
end

local function GetDigSiteMapPinInfoForMapPinBackedManual(destination)
    return ReadCanonicalDigSiteMapPinInfo(destination)
end

local function GetDigSiteIDForMapPinBackedManual(destination)
    local mapPinInfo = GetDigSiteMapPinInfoForMapPinBackedManual(destination)
    return mapPinInfo and mapPinInfo.mapPinID or nil
end

-- ============================================================
-- Meta builder
-- ============================================================

local function BuildBlizzardDigSiteMeta(digSiteID, mapID, x, y, explicit)
    local sig = GetWaypointSignature(mapID, x, y)
    local mapPinInfo = NS.BuildMapPinInfo(BLIZZARD_MAP_PIN_KIND_DIG_SITE, mapID, x, y, {
        mapPinType = DIGSITE_MAP_PIN_TYPE,
        mapPinID = digSiteID,
        sig = sig,
    })
    return NS.BuildRouteMeta(NS.BuildMapPinIdentity(mapPinInfo), {
        mapPinInfo = mapPinInfo,
    })
end

-- ============================================================
-- Adoption and retry
-- ============================================================

local CancelDigSiteAdoptionRetry
local AdoptBlizzardDigSiteAsManual
local ScheduleDigSiteAdoptionRetry

CancelDigSiteAdoptionRetry = function()
    digSite.adoptionRetrySerial = (digSite.adoptionRetrySerial or 0) + 1
end

local function GetActiveBlizzardDigSiteManual()
    local destination = GetActiveManualDestination and GetActiveManualDestination() or nil
    local mapPinInfo = GetDigSiteMapPinInfoForMapPinBackedManual(destination)
    if not mapPinInfo then return nil, nil end
    return destination, mapPinInfo.mapPinID
end

AdoptBlizzardDigSiteAsManual = function(digSiteID, preferredMapID, explicit)
    local normalizedID = NormalizeDigSiteID(digSiteID)
    if not normalizedID then return false, "invalid_dig_site" end
    if not (state.init and state.init.playerLoggedIn) then return false, "not_ready" end
    if type(NS.IsRoutingEnabled) ~= "function" or not NS.IsRoutingEnabled() then
        return false, "routing_disabled"
    end

    local mapID, x, y = ResolveDigSiteDestination(normalizedID, preferredMapID)
    if not (type(mapID) == "number" and type(x) == "number" and type(y) == "number") then
        return false, "unresolved"
    end

    local destination, activeID = GetActiveBlizzardDigSiteManual()
    local currentSig = GetWaypointSignature(mapID, x, y)
    if activeID == normalizedID then
        local activeSig = destination and GetWaypointSignature(ReadWaypointCoords(destination))
        if activeSig == currentSig then
            return false, "already_current"
        end
    end

    NS.RequestManualRoute(
        mapID,
        x,
        y,
        nil,
        BuildBlizzardDigSiteMeta(normalizedID, mapID, x, y, explicit),
        explicit == true and { clickContext = { source = "dig_site", explicit = true } } or nil
    )
    NS.Log(
        "DigSite takeover route",
        tostring(normalizedID), tostring(mapID), tostring(x), tostring(y),
        tostring(explicit == true and "explicit" or "supertrack")
    )
    digSite.lastDigSiteID = normalizedID
    return true, "routed"
end

local function ShouldRetryDigSiteAdoption(digSiteID)
    local normalizedID = NormalizeDigSiteID(digSiteID)
    if not normalizedID then return false end
    if not (state.init and state.init.playerLoggedIn) then return false end
    if type(NS.IsRoutingEnabled) ~= "function" or not NS.IsRoutingEnabled() then return false end
    return GetCurrentSuperTrackedDigSiteID() == normalizedID
end

ScheduleDigSiteAdoptionRetry = function(digSiteID, preferredMapID, explicit, attempt)
    local normalizedID = NormalizeDigSiteID(digSiteID)
    local nextAttempt = type(attempt) == "number" and attempt or 1
    local isExplicit = explicit == true

    if nextAttempt > DIGSITE_ADOPTION_RETRY_MAX_ATTEMPTS then return false end
    if not ShouldRetryDigSiteAdoption(normalizedID) then return false end

    digSite.adoptionRetrySerial = (digSite.adoptionRetrySerial or 0) + 1
    local retrySerial = digSite.adoptionRetrySerial

    NS.After(DIGSITE_ADOPTION_RETRY_DELAY_SECONDS, function()
        if digSite.adoptionRetrySerial ~= retrySerial then return end
        if not ShouldRetryDigSiteAdoption(normalizedID) then return end

        local adopted, reason = AdoptBlizzardDigSiteAsManual(normalizedID, preferredMapID, isExplicit)
        if adopted or reason ~= "unresolved" then return end

        ScheduleDigSiteAdoptionRetry(normalizedID, preferredMapID, isExplicit, nextAttempt + 1)
    end)

    return true
end

-- ============================================================
-- Clear helpers
-- ============================================================

local function ClearBlizzardDigSiteBackedManual(clearReason)
    local destination, digSiteID = GetActiveBlizzardDigSiteManual()
    if not destination then return false end
    local visibilityState = GetGuideVisibilityState and GetGuideVisibilityState() or nil
    if type(ClearActiveManualDestination) ~= "function" then return false end
    NS.Log("DigSite takeover clear", tostring(digSiteID), tostring(clearReason or "system"))
    return ClearActiveManualDestination(visibilityState, clearReason or "system")
end

-- ============================================================
-- Handler
-- ============================================================

local function HandleDigSiteMapPinChanged(pinID, preferredMapID, explicit)
    local digSiteID = NormalizeDigSiteID(pinID)
    if not digSiteID then
        NS.ClearPendingGuideTakeover()
        CancelDigSiteAdoptionRetry()
        return false
    end

    if explicit then
        return NS.BeginPendingGuideTakeover({
            kind = "dig_site",
            digSiteID = digSiteID,
            preferredMapID = preferredMapID,
        })
    end
    NS.ClearPendingGuideTakeover()
    if GetGuideVisibilityState and GetGuideVisibilityState() == "visible" then
        return false
    end

    local adopted, reason = AdoptBlizzardDigSiteAsManual(digSiteID, preferredMapID, explicit)
    if adopted then CancelDigSiteAdoptionRetry(); return true end
    if reason == "unresolved" then
        ScheduleDigSiteAdoptionRetry(digSiteID, preferredMapID, explicit)
    end
    return false
end

-- ============================================================
-- NS exports
-- ============================================================

function NS.GetDigSiteIDForMapPinBackedManual(destination)
    return GetDigSiteIDForMapPinBackedManual(destination)
end

function NS.GetDigSiteMapPinInfoForMapPinBackedManual(destination)
    return GetDigSiteMapPinInfoForMapPinBackedManual(destination)
end

function NS.ClearSuperTrackedDigSiteIfCurrent(digSiteID)
    local normalizedID = NormalizeDigSiteID(digSiteID)
    if not normalizedID
        or type(C_SuperTrack) ~= "table"
        or type(C_SuperTrack.GetSuperTrackedMapPin) ~= "function"
        or type(C_SuperTrack.ClearSuperTrackedMapPin) ~= "function"
    then
        return
    end
    NS.After(0, function()
        if GetCurrentSuperTrackedDigSiteID() == normalizedID then
            if type(NS.WithInternalSuperTrackMutation) == "function" then
                NS.WithInternalSuperTrackMutation(C_SuperTrack.ClearSuperTrackedMapPin)
            else
                C_SuperTrack.ClearSuperTrackedMapPin()
            end
        end
    end)
end

-- ============================================================
-- BlizzardKinds registration
-- ============================================================

M.BlizzardKinds["dig_site"] = {
    onChanged = HandleDigSiteMapPinChanged,
    resolvePending = function(pending)
        local mapID, x, y = ResolveDigSiteDestination(pending.digSiteID, pending.preferredMapID)
        return mapID, x, y
    end,
    commitPending = function(pending)
        local adopted, reason = AdoptBlizzardDigSiteAsManual(pending.digSiteID, pending.preferredMapID, true)
        if adopted then CancelDigSiteAdoptionRetry(); return true end
        if reason == "unresolved" then
            ScheduleDigSiteAdoptionRetry(pending.digSiteID, pending.preferredMapID, true)
        end
        return false
    end,
    clearOnMapPinCleared = function()
        CancelDigSiteAdoptionRetry()
        return ClearBlizzardDigSiteBackedManual("explicit")
    end,
    startupSync = nil,
}
