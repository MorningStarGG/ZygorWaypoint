local NS = _G.AzerothWaypointNS

-- ============================================================
-- Shared route presentation helpers
-- ============================================================

local RouteSpecials = NS.RouteSpecials or {}
NS.RouteSpecials = RouteSpecials

local HEARTHSTONE_ITEM_ID = 6948
local STORMWIND_MAP_ID = 84
local WIZARDS_SANCTUM_AREA_ID = 10523
local WIZARDS_SANCTUM_FALLBACK_NAME = "Wizard's Sanctum"
local MAGE_TOWER_ENTRY_FALLBACK = {
    mapID = STORMWIND_MAP_ID,
    x = 0.4951,
    y = 0.8666,
}

RouteSpecials.STORMWIND_MAP_ID = STORMWIND_MAP_ID

local function TextEquals(left, right)
    return type(left) == "string" and left ~= "" and left == right
end

function RouteSpecials.IsHearthstoneItemID(itemID)
    return tonumber(itemID) == HEARTHSTONE_ITEM_ID
end

function RouteSpecials.GetWizardsSanctumName()
    local name = type(C_Map) == "table"
        and type(C_Map.GetAreaInfo) == "function"
        and C_Map.GetAreaInfo(WIZARDS_SANCTUM_AREA_ID)
        or nil
    return type(name) == "string" and name ~= "" and name or WIZARDS_SANCTUM_FALLBACK_NAME
end

function RouteSpecials.IsPlayerInWizardsSanctum()
    local sanctumName = RouteSpecials.GetWizardsSanctumName()
    return TextEquals(type(GetSubZoneText) == "function" and GetSubZoneText() or nil, sanctumName)
        or TextEquals(type(GetMinimapZoneText) == "function" and GetMinimapZoneText() or nil, sanctumName)
end

function RouteSpecials.PlayerNeedsWizardsSanctumEntry(location)
    local locationMapID = type(location) == "table" and location.mapID or nil
    local playerMapID = type(NS.GetPlayerMapID) == "function" and NS.GetPlayerMapID() or nil
    return (locationMapID == STORMWIND_MAP_ID or playerMapID == STORMWIND_MAP_ID)
        and not RouteSpecials.IsPlayerInWizardsSanctum()
end

function RouteSpecials.MakeWizardsSanctumArrivalGate()
    return {
        indoors = true,
        subzone = RouteSpecials.GetWizardsSanctumName(),
    }
end

function RouteSpecials.GetMageTowerEntryFallback()
    return MAGE_TOWER_ENTRY_FALLBACK.mapID, MAGE_TOWER_ENTRY_FALLBACK.x, MAGE_TOWER_ENTRY_FALLBACK.y
end

function RouteSpecials.CoordsMatch(mapID, x, y, targetMapID, targetX, targetY, epsilon)
    return type(mapID) == "number"
        and type(x) == "number"
        and type(y) == "number"
        and type(targetMapID) == "number"
        and type(targetX) == "number"
        and type(targetY) == "number"
        and mapID == targetMapID
        and math.abs(x - targetX) <= epsilon
        and math.abs(y - targetY) <= epsilon
end

function RouteSpecials.IsMageTowerEntryLeg(leg, mapID, x, y, epsilon)
    if type(leg) ~= "table" then
        return false
    end
    if leg.kind == "entrance" then
        return true
    end
    if type(mapID) ~= "number" or type(x) ~= "number" or type(y) ~= "number" then
        mapID, x, y = RouteSpecials.GetMageTowerEntryFallback()
    end
    return RouteSpecials.CoordsMatch(leg.mapID, leg.x, leg.y, mapID, x, y, epsilon)
end

function RouteSpecials.MarkMageTowerEntryLeg(leg, title)
    if type(leg) ~= "table" then
        return
    end
    leg.kind = "entrance"
    leg.routeLegKind = "carrier"
    leg.routeTravelType = "travel"
    leg.arrivalRadius = 15
    leg.title = leg.title or title or "Enter the Mage Tower"
    leg.specialAction = nil
    leg.activationCoords = nil
end

function RouteSpecials.MakeMageTowerEntryLeg(source, mapID, x, y, title)
    if type(mapID) ~= "number" or type(x) ~= "number" or type(y) ~= "number" then
        mapID, x, y = RouteSpecials.GetMageTowerEntryFallback()
    end
    return {
        mapID = mapID,
        x = x,
        y = y,
        kind = "entrance",
        routeLegKind = "carrier",
        title = title or "Enter the Mage Tower",
        source = source,
        routeTravelType = "travel",
        arrivalRadius = 15,
    }
end

function RouteSpecials.EnsureMageTowerEntryBeforeWizardsSanctumLeg(legs, source, mapID, x, y, isEntryLeg)
    if type(legs) ~= "table" then
        return
    end
    local previous = legs[#legs]
    local isPreviousEntry = type(isEntryLeg) == "function"
        and isEntryLeg(previous)
        or RouteSpecials.IsMageTowerEntryLeg(previous, mapID, x, y, 0.025)
    if isPreviousEntry then
        RouteSpecials.MarkMageTowerEntryLeg(previous)
        return
    end
    legs[#legs + 1] = RouteSpecials.MakeMageTowerEntryLeg(source, mapID, x, y)
end
