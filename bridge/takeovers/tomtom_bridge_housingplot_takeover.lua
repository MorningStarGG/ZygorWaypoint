local NS = _G.AzerothWaypointNS
local state = NS.State

NS.Internal = NS.Internal or {}

NS.Internal.BlizzardTakeovers = NS.Internal.BlizzardTakeovers or {}
local M = NS.Internal.BlizzardTakeovers

M.BlizzardKinds = M.BlizzardKinds or {}

state.bridgeHousingPlotTakeover = state.bridgeHousingPlotTakeover or {
    lastPlotDataID = nil,
}

local housingPlot = state.bridgeHousingPlotTakeover

local GetActiveManualDestination = NS.GetActiveManualDestination
local ClearActiveManualDestination = NS.ClearActiveManualDestination
local GetGuideVisibilityState = NS.GetGuideVisibilityState
local ReadWaypointCoords = NS.ReadWaypointCoords
local Signature = NS.Signature

local BLIZZARD_MAP_PIN_KIND_HOUSING_PLOT = "housing_plot"
local HOUSING_PLOT_MAP_PIN_TYPE = Enum.SuperTrackingMapPinType and Enum.SuperTrackingMapPinType.HousingPlot or 4

-- ============================================================
-- Helpers
-- ============================================================

local function NormalizePlotDataID(plotDataID)
    if type(plotDataID) == "number" and plotDataID > 0 then
        return plotDataID
    end
end

local function GetWaypointSignature(mapID, x, y)
    if type(Signature) ~= "function" then return nil end
    if type(mapID) ~= "number" or type(x) ~= "number" or type(y) ~= "number" then return nil end
    return Signature(mapID, x, y)
end

local function GetCurrentSuperTrackedHousingPlotDataID()
    if type(C_SuperTrack) ~= "table" or type(C_SuperTrack.GetSuperTrackedMapPin) ~= "function" then
        return nil
    end
    local pinType, pinID = C_SuperTrack.GetSuperTrackedMapPin()
    if pinType == HOUSING_PLOT_MAP_PIN_TYPE and type(pinID) == "number" and pinID > 0 then
        return pinID
    end
end

-- ============================================================
-- Resolution
-- NOTE: All APIs only work when inside a neighborhood instance.
-- When outside, GetCurrentNeighborhoodGUID() returns nil and fails gracefully.
-- No retry loop, this is a location constraint, not a timing one.
-- Do NOT hardcode map IDs; always resolve via GetUIMapIDForNeighborhood.
-- ============================================================

local function ResolveHousingPlotDestination(plotDataID)
    if type(C_Housing) ~= "table"
        or type(C_Housing.GetCurrentNeighborhoodGUID) ~= "function"
        or type(C_Housing.GetUIMapIDForNeighborhood) ~= "function"
    then
        return nil
    end
    if type(C_HousingNeighborhood) ~= "table"
        or type(C_HousingNeighborhood.GetNeighborhoodMapData) ~= "function"
    then
        return nil
    end

    local guid = C_Housing.GetCurrentNeighborhoodGUID()
    if not guid then return nil end
    local mapID = C_Housing.GetUIMapIDForNeighborhood(guid)
    if not mapID then return nil end

    local ok, plots = pcall(C_HousingNeighborhood.GetNeighborhoodMapData)
    if not ok or type(plots) ~= "table" then return nil end

    for _, plot in ipairs(plots) do
        if type(plot) == "table" and plot.plotDataID == plotDataID then
            local pos = plot.mapPosition
            local x = type(pos) == "table" and pos.x or nil
            local y = type(pos) == "table" and pos.y or nil
            if type(x) == "number" and type(y) == "number" then
                local ownerType = type(plot.ownerType) == "number" and plot.ownerType or nil
                local ownerName = type(plot.ownerName) == "string" and plot.ownerName ~= "" and plot.ownerName or nil
                ---@diagnostic disable-next-line: undefined-field
                local plotName = type(plot.plotName) == "string" and plot.plotName ~= "" and plot.plotName or nil
                local title
                if ownerType == 3 then
                    title = ownerName and ("Home (" .. ownerName .. ")") or "Home"
                elseif ownerType == 0 then
                    title = plotName or "Unoccupied Plot"
                else
                    title = ownerName or plotName or nil
                end
                return mapID, x, y, title, ownerType
            end
        end
    end
end

-- ============================================================
-- MapPinInfo getters
-- ============================================================

local function ReadCanonicalHousingPlotMapPinInfo(destination)
    if type(destination) ~= "table" or destination.type ~= "manual" then return nil end
    local mapPinInfo = type(destination.mapPinInfo) == "table" and destination.mapPinInfo or nil
    local identity = type(destination.identity) == "table" and destination.identity or nil
    local mapPinKind = mapPinInfo and mapPinInfo.kind or identity and identity.mapPinKind
    local mapPinType = mapPinInfo and mapPinInfo.mapPinType or identity and identity.mapPinType
    if mapPinKind ~= BLIZZARD_MAP_PIN_KIND_HOUSING_PLOT
        or type(mapPinType) == "number" and mapPinType ~= HOUSING_PLOT_MAP_PIN_TYPE
    then
        return nil
    end
    local plotDataID = NormalizePlotDataID(mapPinInfo and mapPinInfo.mapPinID or identity and identity.mapPinID)
    if not plotDataID then return nil end

    local mapID, x, y = ReadWaypointCoords(destination)
    local mapPinSig = nil
    local identitySig = nil
    local mapPinMapID = nil
    local mapPinX = nil
    local mapPinY = nil
    local ownerType = nil

    if type(mapPinInfo) == "table" then
        mapPinSig = type(mapPinInfo["sig"]) == "string" and mapPinInfo["sig"] or nil
        mapPinMapID = type(mapPinInfo["mapID"]) == "number" and mapPinInfo["mapID"] or nil
        mapPinX = type(mapPinInfo["x"]) == "number" and mapPinInfo["x"] or nil
        mapPinY = type(mapPinInfo["y"]) == "number" and mapPinInfo["y"] or nil
        ownerType = type(mapPinInfo["ownerType"]) == "number" and mapPinInfo["ownerType"] or nil
    end
    if type(identity) == "table" then
        identitySig = type(identity["sig"]) == "string" and identity["sig"] or nil
    end

    return {
        kind = BLIZZARD_MAP_PIN_KIND_HOUSING_PLOT,
        mapPinType = HOUSING_PLOT_MAP_PIN_TYPE,
        mapPinID = plotDataID,
        sig = mapPinSig or identitySig or GetWaypointSignature(mapID, x, y),
        mapID = mapPinMapID or mapID,
        x = mapPinX or x,
        y = mapPinY or y,
        ownerType = ownerType,
    }
end

local function GetHousingPlotMapPinInfoForMapPinBackedManual(destination)
    return ReadCanonicalHousingPlotMapPinInfo(destination)
end

local function GetHousingPlotIDForMapPinBackedManual(destination)
    local mapPinInfo = GetHousingPlotMapPinInfoForMapPinBackedManual(destination)
    return mapPinInfo and mapPinInfo.mapPinID or nil
end

-- ============================================================
-- Meta builder
-- ============================================================

local function BuildBlizzardHousingPlotMeta(plotDataID, mapID, x, y, explicit, ownerType)
    local sig = GetWaypointSignature(mapID, x, y)
    local mapPinInfo = NS.BuildMapPinInfo(BLIZZARD_MAP_PIN_KIND_HOUSING_PLOT, mapID, x, y, {
        mapPinType = HOUSING_PLOT_MAP_PIN_TYPE,
        mapPinID = plotDataID,
        sig = sig,
        ownerType = type(ownerType) == "number" and ownerType or nil,
    })
    return NS.BuildRouteMeta(NS.BuildMapPinIdentity(mapPinInfo), {
        mapPinInfo = mapPinInfo,
    })
end

-- ============================================================
-- Adoption (single attempt, location constraint, no retry)
-- ============================================================

local function GetActiveBlizzardHousingPlotManual()
    local destination = GetActiveManualDestination and GetActiveManualDestination() or nil
    local mapPinInfo = GetHousingPlotMapPinInfoForMapPinBackedManual(destination)
    if not mapPinInfo then return nil, nil end
    return destination, mapPinInfo.mapPinID
end

local function AdoptBlizzardHousingPlotAsManual(plotDataID, explicit)
    local normalizedID = NormalizePlotDataID(plotDataID)
    if not normalizedID then return false, "invalid_plot" end
    if not (state.init and state.init.playerLoggedIn) then return false, "not_ready" end
    if type(NS.IsRoutingEnabled) ~= "function" or not NS.IsRoutingEnabled() then
        return false, "routing_disabled"
    end

    local mapID, x, y, title, ownerType = ResolveHousingPlotDestination(normalizedID)
    if not (type(mapID) == "number" and type(x) == "number" and type(y) == "number") then
        NS.BypassGuideTakeover()
        return false, "unresolved"
    end

    local destination, activeID = GetActiveBlizzardHousingPlotManual()
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
        title,
        BuildBlizzardHousingPlotMeta(normalizedID, mapID, x, y, explicit, ownerType),
        explicit == true and { clickContext = { source = "housing_plot", explicit = true } } or nil
    )
    NS.Log(
        "HousingPlot takeover route",
        tostring(normalizedID), tostring(mapID), tostring(x), tostring(y),
        tostring(explicit == true and "explicit" or "supertrack")
    )
    housingPlot.lastPlotDataID = normalizedID
    return true, "routed"
end

-- ============================================================
-- Clear helpers
-- ============================================================

local function ClearBlizzardHousingPlotBackedManual(clearReason)
    local destination, plotDataID = GetActiveBlizzardHousingPlotManual()
    if not destination then return false end
    local visibilityState = GetGuideVisibilityState and GetGuideVisibilityState() or nil
    if type(ClearActiveManualDestination) ~= "function" then return false end
    NS.Log("HousingPlot takeover clear", tostring(plotDataID), tostring(clearReason or "system"))
    return ClearActiveManualDestination(visibilityState, clearReason or "system")
end

-- ============================================================
-- Handler
-- ============================================================

local function HandleHousingPlotMapPinChanged(pinID, preferredMapID, explicit)
    local plotDataID = NormalizePlotDataID(pinID)
    if not plotDataID then
        NS.ClearPendingGuideTakeover()
        return false
    end

    if explicit then
        return NS.BeginPendingGuideTakeover({
            kind = "housing_plot",
            plotDataID = plotDataID,
            preferredMapID = preferredMapID,
        })
    end
    NS.ClearPendingGuideTakeover()
    if GetGuideVisibilityState and GetGuideVisibilityState() == "visible" then
        return false
    end

    local adopted = AdoptBlizzardHousingPlotAsManual(plotDataID, explicit)
    return adopted == true
end

-- ============================================================
-- NS exports
-- ============================================================

function NS.GetHousingPlotIDForMapPinBackedManual(destination)
    return GetHousingPlotIDForMapPinBackedManual(destination)
end

function NS.GetHousingPlotMapPinInfoForMapPinBackedManual(destination)
    return GetHousingPlotMapPinInfoForMapPinBackedManual(destination)
end

function NS.ClearSuperTrackedHousingPlotIfCurrent(plotDataID)
    local normalizedID = NormalizePlotDataID(plotDataID)
    if not normalizedID
        or type(C_SuperTrack) ~= "table"
        or type(C_SuperTrack.GetSuperTrackedMapPin) ~= "function"
        or type(C_SuperTrack.ClearSuperTrackedMapPin) ~= "function"
    then
        return
    end
    NS.After(0, function()
        if GetCurrentSuperTrackedHousingPlotDataID() == normalizedID then
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

M.BlizzardKinds["housing_plot"] = {
    onChanged = HandleHousingPlotMapPinChanged,
    resolvePending = function(pending)
        local mapID, x, y = ResolveHousingPlotDestination(pending.plotDataID)
        return mapID, x, y
    end,
    commitPending = function(pending)
        -- No retry: resolution fails if player is outside the neighborhood (location constraint)
        local adopted = AdoptBlizzardHousingPlotAsManual(pending.plotDataID, true)
        return adopted == true
    end,
    clearOnMapPinCleared = function()
        return ClearBlizzardHousingPlotBackedManual("explicit")
    end,
    startupSync = nil,
}
