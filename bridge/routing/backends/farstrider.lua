local NS = _G.AzerothWaypointNS
local RouteSpecials = NS.RouteSpecials or {}

-- ============================================================
-- FarstriderLib backend
-- ============================================================

local backend = {}
NS.RoutingBackend_Farstrider = backend

backend.id = "farstrider"

local MOVEMENT_ADVANCE_YARDS = 55
local INSTANCE_NODE_COORD_EPSILON = 0.025
local COORD_BOUNDS_EPSILON = 0.0001
local FARSTRIDER_LOCA_ENTER_WIZARDS_SANCTUM = 9

local FARSTRIDER_INVALIDATION_EVENTS = {
    BAG_UPDATE_DELAYED = true,
    HEARTHSTONE_BOUND = true,
    PLAYER_ENTERING_WORLD = true,
    SPELL_UPDATE_COOLDOWN = true,
    SPELLS_CHANGED = true,
    TOYS_UPDATED = true,
}

local FARSTRIDER_ABILITY_INVALIDATION_EVENTS = {
    BAG_UPDATE_DELAYED = true,
    HEARTHSTONE_BOUND = true,
    SPELL_UPDATE_COOLDOWN = true,
    SPELLS_CHANGED = true,
    TOYS_UPDATED = true,
}

local EdgeType = {
    TRAVEL     = 1000,
    FLIGHTPATH = 1001,
    PORTAL     = 1002,
    BOAT       = 1003,
    ZEPPELIN   = 1004,
    ITEM       = 1005,
    SPELL      = 1006,
}

local function GetFarstriderAPI()
    local api = rawget(_G, "FarstriderLib_API")
    if type(api) == "table" and type(api.FindTrailTo) == "function" then
        return api
    end
    return nil
end

local function GetFarstriderPathfinding()
    local farstrider = rawget(_G, "FarstriderLib")
    local pathfinding = type(farstrider) == "table" and farstrider.Pathfinding or nil
    if type(pathfinding) == "table" and type(pathfinding.GetValidTravelNodes) == "function" then
        return pathfinding
    end
    return nil
end

local function FingerprintCoord(value, scale)
    if type(value) ~= "number" then
        return "-"
    end
    scale = scale or 10000
    return tostring(math.floor(value * scale + 0.5))
end

local function DynamicNodeLocationToken(node)
    if type(node) ~= "table" or node.isDynamic ~= true or type(node.getLocation) ~= "function" then
        return "-"
    end

    local ok, location = pcall(node.getLocation)
    if not ok or type(location) ~= "table" then
        return "dynamic:unknown"
    end

    local pos = type(location.pos) == "table" and location.pos or nil
    return tostring(location.mapId or "-")
        .. "/"
        .. FingerprintCoord(pos and pos.x)
        .. "/"
        .. FingerprintCoord(pos and pos.y)
        .. "/"
        .. FingerprintCoord(pos and pos.z, 1)
        .. "/"
        .. tostring(location.isUI == true)
end

local function BuildValidTravelNodeFingerprint(validNodes)
    if type(validNodes) ~= "table" then
        return nil
    end

    local count = 0
    local sumA = 0
    local sumB = 0
    for key, node in pairs(validNodes) do
        local text = tostring(key) .. "@" .. DynamicNodeLocationToken(node)
        local hash = 5381
        for index = 1, #text do
            hash = (hash * 33 + string.byte(text, index)) % 2147483647
        end
        count = count + 1
        sumA = (sumA + hash) % 2147483647
        sumB = (sumB + (hash * ((hash % 8191) + 1)) % 2147483629) % 2147483629
    end
    return tostring(count) .. ":" .. tostring(sumA) .. ":" .. tostring(sumB)
end

local function GetFarstriderTravelStateFingerprint(refresh)
    local pathfinding = GetFarstriderPathfinding()
    if not pathfinding then
        return nil
    end
    if refresh and type(pathfinding.InvalidateCache) == "function" then
        pathfinding:InvalidateCache()
    end

    local ok, validNodes = pcall(pathfinding.GetValidTravelNodes, pathfinding)
    if not ok then
        return nil
    end
    return BuildValidTravelNodeFingerprint(validNodes)
end

local function RememberTravelStateFingerprint(record, refresh)
    if type(record) ~= "table" then
        return nil
    end
    local fingerprint = GetFarstriderTravelStateFingerprint(refresh)
    record._farstriderTravelStateFingerprint = fingerprint
    return fingerprint
end

local function GetActiveFarstriderRecord()
    local routing = NS.State and NS.State.routing or nil
    local record = routing and routing.manualAuthority or nil
    if not record then
        local guideState = routing and routing.guideRouteState or nil
        if guideState and guideState.target and not guideState.suppressed then
            record = guideState
        end
    end
    if type(record) == "table" and record.backend == "farstrider" then
        return record
    end
    return nil
end

local function IsFarstriderWizardsSanctumNode(node)
    return type(node) == "table" and node.wizardsSanctum == true
end

local function IsFarstriderWizardsSanctumEntryEdge(edge)
    return type(edge) == "table"
        and IsFarstriderWizardsSanctumNode(edge.to)
        and not IsFarstriderWizardsSanctumNode(edge.from)
end

local function IsFarstriderWizardsSanctumSourceEdge(edge)
    return type(edge) == "table" and IsFarstriderWizardsSanctumNode(edge.from)
end

function backend.IsAvailable()
    if not (type(NS.IsAddonLoaded) == "function" and NS.IsAddonLoaded("FarstriderLibData")) then
        return false
    end
    return GetFarstriderAPI() ~= nil
end

local function ResolveSpellName(spellID)
    if type(spellID) ~= "number" then return nil end
    if type(C_Spell) == "table" and type(C_Spell.GetSpellName) == "function" then
        return C_Spell.GetSpellName(spellID)
    end
    return nil
end

local function SpellLooksLikePortal(name)
    if type(name) ~= "string" then return false end
    local lower = name:lower()
    return lower:find("portal", 1, true) ~= nil
        or lower:find("teleport", 1, true) ~= nil
end

local function TrimString(value)
    if type(value) ~= "string" then return nil end
    value = value:gsub("^%s+", ""):gsub("%s+$", "")
    if value == "" then return nil end
    return value
end

local function TitleLooksLikePortal(title)
    title = TrimString(title)
    if not title then return false end
    local lower = title:lower()
    return lower:find("take the portal", 1, true) ~= nil
        or lower:find("use the portal", 1, true) ~= nil
        or lower:find("enter the portal", 1, true) ~= nil
        or lower:find("click the portal", 1, true) ~= nil
        or lower:find("go through the portal", 1, true) ~= nil
        or lower:find("portal to", 1, true) ~= nil
end

local function ResolveItemName(itemID)
    if type(itemID) ~= "number" then return nil end
    if type(C_Item) == "table" and type(C_Item.GetItemNameByID) == "function" then
        return C_Item.GetItemNameByID(itemID)
    end
    local getItemInfo = rawget(_G, "GetItemInfo")
    if type(getItemInfo) == "function" then
        local itemName = getItemInfo(itemID)
        return TrimString(itemName)
    end
    return nil
end

local function ReadVector2XY(vector)
    if type(vector) ~= "table" then
        return nil, nil
    end
    local x = vector.x
    local y = vector.y
    if (type(x) ~= "number" or type(y) ~= "number") and type(vector.GetXY) == "function" then
        local ok, vx, vy = pcall(vector.GetXY, vector)
        if ok then
            x, y = vx, vy
        end
    end
    return x, y
end

local function CoordsAreInBounds(x, y)
    return type(x) == "number"
        and type(y) == "number"
        and x >= -COORD_BOUNDS_EPSILON
        and x <= 1 + COORD_BOUNDS_EPSILON
        and y >= -COORD_BOUNDS_EPSILON
        and y <= 1 + COORD_BOUNDS_EPSILON
end

local function ClampCoord(value)
    return math.max(0, math.min(1, value))
end

local function ReadLocCoords(loc)
    if type(loc) ~= "table" then return nil, nil, nil end
    local pos = type(loc.pos) == "table" and loc.pos or nil
    local mapID = loc.mapId
    local x = pos and pos.x or nil
    local y = pos and pos.y or nil
    if type(mapID) ~= "number" or type(x) ~= "number" or type(y) ~= "number" then
        return nil, nil, nil
    end

    if loc.isUI == true then
        return mapID, x, y
    end

    if type(C_Map) ~= "table"
        or type(C_Map.GetMapPosFromWorldPos) ~= "function"
        or type(CreateVector2D) ~= "function"
    then
        return nil, nil, nil
    end

    local worldPosition = CreateVector2D(x, y)
    local ok, uiMapID, mapPosition
    if type(loc.uiMapHint) == "number" then
        ok, uiMapID, mapPosition = pcall(C_Map.GetMapPosFromWorldPos, mapID, worldPosition, loc.uiMapHint)
    else
        ok, uiMapID, mapPosition = pcall(C_Map.GetMapPosFromWorldPos, mapID, worldPosition)
    end
    if not ok then
        return nil, nil, nil
    end
    local uiX, uiY = ReadVector2XY(mapPosition)
    if type(uiMapID) ~= "number" or not CoordsAreInBounds(uiX, uiY) then
        return nil, nil, nil
    end

    return uiMapID, ClampCoord(uiX), ClampCoord(uiY)
end

local function IsExplicitWizardsSanctumEntryEdge(edge)
    return type(edge) == "table" and edge.locaId == FARSTRIDER_LOCA_ENTER_WIZARDS_SANCTUM
end

local function ShouldUseMageTowerEntryFallback(edge, mapID)
    return IsExplicitWizardsSanctumEntryEdge(edge)
        and type(NS.IsMapContinentOrHigher) == "function"
        and NS.IsMapContinentOrHigher(mapID)
end

local function ApplyWizardsSanctumEntryPresentation(edge, step, mapID, x, y, kind, routeTravelType, arrivalRadius)
    if not IsExplicitWizardsSanctumEntryEdge(edge) then
        -- Edges arriving inside the Wizard's Sanctum that are not the local
        -- Stormwind entry edge are remote portals such as Stair of Destiny.
        -- Keep their source-side coords instead of rewriting them to Stormwind.
        return mapID, x, y, "portal", "portal", 20
    end

    kind = "entrance"
    routeTravelType = "travel"
    arrivalRadius = 15
    if ShouldUseMageTowerEntryFallback(edge, mapID) then
        mapID, x, y = RouteSpecials.GetMageTowerEntryFallback()
    end
    return mapID, x, y, kind, routeTravelType, arrivalRadius
end

local function MakeCoords(mapID, x, y)
    if type(mapID) ~= "number" or type(x) ~= "number" or type(y) ~= "number" then
        return nil
    end
    return { mapID = mapID, x = x, y = y }
end

local function CoordsMatch(mapID, x, y, targetMapID, targetX, targetY, epsilon)
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

local function IsMageTowerEntryLeg(leg)
    return type(RouteSpecials.IsMageTowerEntryLeg) == "function"
        and RouteSpecials.IsMageTowerEntryLeg(leg, nil, nil, nil, INSTANCE_NODE_COORD_EPSILON)
        or false
end

local function EnsureMageTowerEntryBeforeWizardsSanctumLeg(legs)
    RouteSpecials.EnsureMageTowerEntryBeforeWizardsSanctumLeg(legs, "farstrider", nil, nil, nil, IsMageTowerEntryLeg)
end

local function IsInstancePlanningTarget(target)
    return type(target) == "table" and type(target.instanceRouteIntent) == "table"
end

local function BuildPlanningTarget(mapID, x, y, title)
    local target = {
        mapID = mapID,
        x = x,
        y = y,
        title = title,
        reason = "farstrider_plan",
    }

    local intent = type(NS.ResolveInstanceRouteIntent) == "function"
        and NS.ResolveInstanceRouteIntent(mapID, x, y, title)
        or nil

    local entrance = type(intent) == "table" and intent.entrance or nil
    if type(entrance) ~= "table"
        or type(entrance.mapID) ~= "number"
        or type(entrance.x) ~= "number"
        or type(entrance.y) ~= "number"
    then
        return target
    end

    local instanceName = type(intent) == "table" and intent.instanceName or nil

    target.mapID = entrance.mapID
    target.x = entrance.x
    target.y = entrance.y

    local coordTitle
    local mapInfo = type(_G.C_Map) == "table" and type(_G.C_Map.GetMapInfo) == "function"
        and _G.C_Map.GetMapInfo(entrance.mapID)
    if type(mapInfo) == "table" and type(mapInfo.name) == "string" and mapInfo.name ~= "" then
        coordTitle = string.format("%s %.0f, %.0f", mapInfo.name, entrance.x * 100, entrance.y * 100)
    end
    target.title = (instanceName and ("Enter " .. instanceName)) or coordTitle or title or "Route"
    target.finalMapID = mapID
    target.finalX = x
    target.finalY = y
    target.finalTitle = title
    target.instanceRouteIntent = intent
    target.reason = "farstrider_instance_entrance_plan"

    return target
end

local function MarkInstanceEntranceLeg(legs, target)
    if type(legs) ~= "table" or not IsInstancePlanningTarget(target) then
        return
    end

    local last = legs[#legs]
    if type(last) ~= "table" then
        return
    end

    if not CoordsMatch(
            last.mapID,
            last.x,
            last.y,
            target.mapID,
            target.x,
            target.y,
            INSTANCE_NODE_COORD_EPSILON
        ) then
        return
    end

    last.kind = "portal"
    last.routeLegKind = "carrier"
    last.routeTravelType = target.instanceRouteIntent.travelType
    last.arrivalRadius = 15
    last.title = target.title or last.title
end

local function AppendInstanceDestinationLeg(legs, target)
    if type(legs) ~= "table" or not IsInstancePlanningTarget(target) then
        return
    end

    local intent = target.instanceRouteIntent
    local final = type(intent.final) == "table" and intent.final or nil

    local finalMapID = type(final) == "table" and final.mapID or target.finalMapID
    local finalX = type(final) == "table" and final.x or target.finalX
    local finalY = type(final) == "table" and final.y or target.finalY
    local finalTitle = type(final) == "table" and final.title or target.finalTitle

    if type(finalMapID) ~= "number"
        or type(finalX) ~= "number"
        or type(finalY) ~= "number"
    then
        return
    end

    local last = legs[#legs]
    if type(last) == "table"
        and CoordsMatch(last.mapID, last.x, last.y, finalMapID, finalX, finalY, INSTANCE_NODE_COORD_EPSILON)
    then
        return
    end

    legs[#legs + 1] = {
        mapID = finalMapID,
        x = finalX,
        y = finalY,
        kind = "destination",
        routeLegKind = "destination",
        title = finalTitle or target.finalTitle or target.title,
        source = "farstrider",
        routeTravelType = intent.travelType,
        arrivalRadius = 15,
    }
end

local function ReadEdgeLocaArgs(edge)
    if type(edge) ~= "table" or type(edge.locaArgs) ~= "function" then
        return nil
    end
    local ok, args = pcall(edge.locaArgs)
    if ok and type(args) == "table" then
        return args
    end
    return nil
end

local function ResolveActionPresentation(step, edge, fallbackActionName)
    local args = ReadEdgeLocaArgs(edge)
    local actionName = TrimString(type(args) == "table" and args[1] or nil)
        or TrimString(fallbackActionName)
    local destinationName = TrimString(type(args) == "table" and args[2] or nil)

    return TrimString(step and step.loca) or actionName, destinationName
end

local function IsUsableItemID(itemID)
    if type(itemID) ~= "number" then
        return false
    end

    local farstriderData = rawget(_G, "FarstriderLibData")
    local farstriderUtil = type(farstriderData) == "table" and farstriderData.Util or nil
    if type(farstriderUtil) == "table" and type(farstriderUtil.CanUseItem) == "function" then
        local ok, canUse = pcall(farstriderUtil.CanUseItem, itemID)
        if ok then
            return canUse == true
        end
    end

    local hasItemOrToy = false
    if type(PlayerHasToy) == "function" then
        local ok, hasToy = pcall(PlayerHasToy, itemID)
        hasItemOrToy = ok and hasToy == true
    end
    if not hasItemOrToy and type(C_Item) == "table" and type(C_Item.GetItemCount) == "function" then
        local ok, count = pcall(C_Item.GetItemCount, itemID)
        hasItemOrToy = ok and type(count) == "number" and count > 0
    end
    if not hasItemOrToy then
        local getItemCount = rawget(_G, "GetItemCount")
        if type(getItemCount) == "function" then
            local ok, count = pcall(getItemCount, itemID)
            hasItemOrToy = ok and type(count) == "number" and count > 0
        end
    end
    if not hasItemOrToy then
        return false
    end

    if type(C_Item) == "table" and type(C_Item.IsUsableItem) == "function" then
        local ok, usable = pcall(C_Item.IsUsableItem, itemID)
        if ok and usable ~= true then
            return false
        end
    end
    local isUsableItem = rawget(_G, "IsUsableItem")
    if type(isUsableItem) == "function" then
        local ok, usable = pcall(isUsableItem, itemID)
        if ok and usable ~= true then
            return false
        end
    end

    local duration
    if type(C_Item) == "table" and type(C_Item.GetItemCooldown) == "function" then
        local ok, _, cooldownDuration = pcall(C_Item.GetItemCooldown, itemID)
        if ok then
            duration = cooldownDuration
        end
    elseif type(C_Container) == "table" and type(C_Container.GetItemCooldown) == "function" then
        local ok, _, cooldownDuration = pcall(C_Container.GetItemCooldown, itemID)
        if ok then
            duration = cooldownDuration
        end
    end
    return type(duration) ~= "number" or duration <= 0
end

local function SelectFarstriderAction(actionOptions)
    if type(actionOptions) ~= "table" then
        return nil
    end

    local firstAction = nil
    for index = 1, #actionOptions do
        local action = actionOptions[index]
        if type(action) == "table" then
            firstAction = firstAction or action
            if action.allowAny == true and action.type == "item" and IsUsableItemID(action.data) then
                return action
            end
        end
    end
    return firstAction
end

local function IsFarstriderHearthstoneAction(action, edge)
    return type(action) == "table"
        and action.type == "item"
        and action.allowAny == true
        and type(edge) == "table"
        and type(edge.to) == "table"
        and edge.to.isDynamic == true
end

local function IsFlightpathEdge(edge)
    return type(edge) == "table" and edge.locaId == EdgeType.FLIGHTPATH
end

local function BuildOptimizedEdges(edges, path)
    local optimizedEdges = {}
    if type(edges) ~= "table" then
        return optimizedEdges
    end

    local virtualGoalKey = nil
    if type(path) == "table" and type(path[#path]) == "table" then
        virtualGoalKey = path[#path].key
    end

    -- Mirror FarstriderLib's optimized-path filtering. The final edge is
    -- intentionally kept even when it is a direct TRAVEL edge.
    for index = 1, #edges do
        local edge = edges[index]
        local skip = false
        if type(edge) ~= "table" then
            skip = true
        elseif index == #edges
            or (virtualGoalKey ~= nil and type(edge.to) == "table" and edge.to.key == virtualGoalKey)
        then
            skip = false
        elseif edge.skipOptimized then
            skip = true
        elseif edge.locaId == EdgeType.TRAVEL then
            skip = true
        elseif IsFlightpathEdge(edge) and index + 1 < #edges and IsFlightpathEdge(edges[index + 1]) then
            skip = true
        end

        if not skip then
            optimizedEdges[#optimizedEdges + 1] = edge
        end
    end

    return optimizedEdges
end

local function BuildSpecialAction(semanticKind, secureType, securePayload, name, destinationName)
    return {
        semanticKind          = semanticKind,
        secureType            = secureType,
        securePayload         = securePayload,
        name                  = name,
        title                 = name,
        destinationName       = destinationName,
        activationMode        = "portable",
        activationCoords      = nil,
        activationRadiusYards = 15,
        sourceBackend         = "farstrider",
    }
end

local FARSTRIDER_GENERIC_TITLES = {
    ["Reach the destination"] = true,
}

local function BuildFarstriderLegTitle(mapID, x, y, rawTitle)
    if not rawTitle or not FARSTRIDER_GENERIC_TITLES[rawTitle] then
        return rawTitle
    end
    local mapInfo = type(_G.C_Map) == "table" and type(_G.C_Map.GetMapInfo) == "function"
        and _G.C_Map.GetMapInfo(mapID)
    if type(mapInfo) == "table" and type(mapInfo.name) == "string" and mapInfo.name ~= "" then
        return string.format("%s %.0f, %.0f", mapInfo.name, x * 100, y * 100)
    end
    return rawTitle
end

local function StepToLeg(step, edge, isLast, destinationTitle)
    if type(step) ~= "table" then return nil end

    local edgeType                   = type(edge) == "table" and edge.locaId or nil
    local isWizardsSanctumEntryEdge  = IsFarstriderWizardsSanctumEntryEdge(edge)
    local isWizardsSanctumSourceEdge = IsFarstriderWizardsSanctumSourceEdge(edge)
    local actionOptions              = step.actionOptions
    local action                     = SelectFarstriderAction(actionOptions)
    local actionType                 = type(action) == "table" and action.type or nil

    local mapID, x, y
    local kind
    local routeTravelType            = nil
    local arrivalRadius              = MOVEMENT_ADVANCE_YARDS
    local specialAction              = nil
    local activationCoords           = nil
    local routeLegKind               = isLast and "destination" or "carrier"

    if isLast then
        -- Final leg: always use completionLoc as the leg coord.
        mapID, x, y = ReadLocCoords(step.completionLoc)
        if type(mapID) ~= "number" then
            mapID, x, y = ReadLocCoords(step.loc)
        end
        kind = "destination"
        arrivalRadius = 15

        if actionType == "item" then
            local itemID = action and action.data or nil
            if type(itemID) == "number" then
                local sk = IsFarstriderHearthstoneAction(action, edge) and "hearth" or "item"
                local actionTitle, destinationName = ResolveActionPresentation(step, edge, ResolveItemName(itemID))
                specialAction = BuildSpecialAction(sk, "item", itemID, actionTitle, destinationName)
                routeTravelType = sk == "hearth" and "hearth" or nil
                kind = sk
            end
        elseif actionType == "spell" then
            local spellID = action and action.data or nil
            if type(spellID) == "number" then
                local spellName = ResolveSpellName(spellID) or tostring(spellID)
                local sk = SpellLooksLikePortal(spellName) and "portal" or "spell"
                local actionTitle, destinationName = ResolveActionPresentation(step, edge, spellName)
                specialAction = BuildSpecialAction(sk, "spell", spellName, actionTitle, destinationName)
                routeTravelType = sk == "portal" and "portal" or nil
                kind = sk
            end
        end

        if type(mapID) ~= "number" then return nil end
    elseif actionType == "item" then
        local itemID = action and action.data or nil
        if type(itemID) ~= "number" then return nil end
        local sk                           = IsFarstriderHearthstoneAction(action, edge) and "hearth" or "item"
        local actionTitle, destinationName = ResolveActionPresentation(step, edge, ResolveItemName(itemID))
        specialAction                      = BuildSpecialAction(sk, "item", itemID, actionTitle, destinationName)
        routeTravelType                    = sk == "hearth" and "hearth" or nil
        kind                               = sk
        mapID, x, y                        = ReadLocCoords(step.loc)
        if type(mapID) ~= "number" then
            mapID, x, y = ReadLocCoords(step.completionLoc)
        end
        if type(mapID) ~= "number" then return nil end
        activationCoords = MakeCoords(mapID, x, y)
    elseif actionType == "spell" then
        local spellID = action and action.data or nil
        if type(spellID) ~= "number" then return nil end
        local spellName                    = ResolveSpellName(spellID) or tostring(spellID)
        local sk                           = SpellLooksLikePortal(spellName) and "portal" or "spell"
        local actionTitle, destinationName = ResolveActionPresentation(step, edge, spellName)
        specialAction                      = BuildSpecialAction(sk, "spell", spellName, actionTitle, destinationName)
        routeTravelType                    = sk == "portal" and "portal" or nil
        kind                               = sk
        mapID, x, y                        = ReadLocCoords(step.loc)
        if type(mapID) ~= "number" then
            mapID, x, y = ReadLocCoords(step.completionLoc)
        end
        if type(mapID) ~= "number" then return nil end
        activationCoords = MakeCoords(mapID, x, y)
    elseif actionType == "housing" or actionType == "housing_return" then
        kind          = "carrier"
        arrivalRadius = 55
        mapID, x, y   = ReadLocCoords(step.loc)
        if type(mapID) ~= "number" then return nil end
    elseif edgeType == EdgeType.FLIGHTPATH then
        kind            = "taxi"
        routeTravelType = "taxi"
        arrivalRadius   = 15
        mapID, x, y     = ReadLocCoords(step.loc)
        if type(mapID) ~= "number" then return nil end
    elseif edgeType == EdgeType.PORTAL then
        kind            = "portal"
        routeTravelType = "portal"
        arrivalRadius   = 20
        mapID, x, y     = ReadLocCoords(step.loc)
        if type(mapID) ~= "number" then return nil end
    elseif edgeType == EdgeType.BOAT or edgeType == EdgeType.ZEPPELIN then
        kind          = "carrier"
        arrivalRadius = 55
        mapID, x, y   = ReadLocCoords(step.loc)
        if type(mapID) ~= "number" then return nil end
    else
        kind            = "carrier"
        routeTravelType = "travel"
        mapID, x, y     = ReadLocCoords(step.loc)
        if type(mapID) ~= "number" then return nil end
    end

    if isWizardsSanctumEntryEdge then
        specialAction = nil
        activationCoords = nil
        mapID, x, y, kind, routeTravelType, arrivalRadius =
            ApplyWizardsSanctumEntryPresentation(edge, step, mapID, x, y, kind, routeTravelType, arrivalRadius)
    elseif routeLegKind == "carrier" and TitleLooksLikePortal(step.loca) then
        kind = "portal"
        routeTravelType = "portal"
        arrivalRadius = 20
    end

    local legTitle
    if routeLegKind == "destination" then
        legTitle = TrimString(destinationTitle) or TrimString(step.loca)
    else
        legTitle = BuildFarstriderLegTitle(mapID, x, y, step.loca)
    end

    return {
        mapID            = mapID,
        x                = x,
        y                = y,
        kind             = kind,
        routeLegKind     = routeLegKind,
        title            = legTitle,
        source           = "farstrider",
        routeTravelType  = routeTravelType,
        arrivalRadius    = arrivalRadius,
        activationCoords = activationCoords,
        arrivalGate      = isWizardsSanctumSourceEdge and RouteSpecials.MakeWizardsSanctumArrivalGate() or nil,
        specialAction    = specialAction,
    }
end

local function AcceptPlan(record, legs, reason)
    if type(NS.AcceptBackendPlan) == "function" then
        return NS.AcceptBackendPlan(record, "farstrider", legs, reason)
    end
    record.backend         = "farstrider"
    record.legs            = legs
    record.currentLegIndex = nil
    record.currentLeg      = nil
    record.specialAction   = nil
    record.replanReason    = reason
    return true
end

local function SetDirectFallback(record, mapID, x, y, title, reason)
    AcceptPlan(record, {
        {
            mapID = mapID,
            x = x,
            y = y,
            kind = "destination",
            routeLegKind = "destination",
            title = title,
            source = "farstrider",
        },
    }, reason)
end

function backend.PlanRoute(record, mapID, x, y, title, meta) --luacheck: ignore 212
    if type(record) ~= "table" or type(mapID) ~= "number"
        or type(x) ~= "number" or type(y) ~= "number"
    then
        return
    end

    local api = GetFarstriderAPI()
    if not api then
        SetDirectFallback(record, mapID, x, y, title, "farstrider_missing")
        return
    end

    local target = BuildPlanningTarget(mapID, x, y, title)

    local ok, optimizedPath, path, edges = pcall(api.FindTrailTo, target.mapID, target.x, target.y, 0)
    RememberTravelStateFingerprint(record, false)
    if not ok or type(optimizedPath) ~= "table" or #optimizedPath == 0 then
        SetDirectFallback(record, mapID, x, y, title, "farstrider_nopath_fallback")
        return
    end

    local optimizedEdges = BuildOptimizedEdges(edges, path)
    record._farstriderLastStepCount = #optimizedPath
    record._farstriderLastEdgeCount = type(edges) == "table" and #edges or 0
    record._farstriderLastOptimizedEdgeCount = #optimizedEdges
    record._farstriderLastCorrelationMismatch = #optimizedEdges ~= #optimizedPath or nil

    local legs = {}
    local needsWizardsSanctumEntry = type(RouteSpecials.PlayerNeedsWizardsSanctumEntry) == "function"
        and RouteSpecials.PlayerNeedsWizardsSanctumEntry()
        or false
    local wizardsSanctumEntryQueued = false
    for i = 1, #optimizedPath do
        local leg = StepToLeg(
            optimizedPath[i],
            optimizedEdges[i],
            i == #optimizedPath,
            target.finalTitle or target.title or title
        )
        if leg then
            if leg.kind == "entrance" then
                wizardsSanctumEntryQueued = true
            elseif leg.arrivalGate and needsWizardsSanctumEntry and not wizardsSanctumEntryQueued then
                EnsureMageTowerEntryBeforeWizardsSanctumLeg(legs)
                wizardsSanctumEntryQueued = true
            end
            legs[#legs + 1] = leg
        end
    end

    if #legs == 0 then
        SetDirectFallback(record, mapID, x, y, title, "farstrider_nopath_fallback")
        return
    end

    MarkInstanceEntranceLeg(legs, target)
    AppendInstanceDestinationLeg(legs, target)

    AcceptPlan(record, legs, target.reason or "farstrider_plan")
end

function backend.PollCurrentLeg(record)
    if type(NS.PollNeutralRouteLeg) == "function" then
        return NS.PollNeutralRouteLeg(record, "farstrider_poll")
    end
    return false
end

function backend.Clear(record)
    if type(record) ~= "table" then return end
    record._farstriderPendingSig = nil
    record._farstriderLastStepCount = nil
    record._farstriderLastEdgeCount = nil
    record._farstriderLastOptimizedEdgeCount = nil
    record._farstriderLastCorrelationMismatch = nil
    record._farstriderTravelStateFingerprint = nil
    record._farstriderLastInvalidationSkipped = nil
    record._farstriderLastInvalidationSkippedAt = nil
    record.legs = nil
    record.currentLegIndex = nil
    record.currentLeg = nil
    record.specialAction = nil
    record.replanReason = nil
    record._corePlanning = nil
    record._coreRoutePending = nil
    record.planFingerprint = nil
    record.lastPlanSkippedAt = nil
    record.lastPlanSkipReason = nil
    record.lastPlanSkipStatus = nil
    record.lastPlanSkippedFingerprint = nil
    record.routeOutcome = nil
    record.routeOutcomeReason = nil
    record.routeOutcomeAt = nil
end

function backend.OnPlanInvalidated(reason)
    local record = GetActiveFarstriderRecord()
    if FARSTRIDER_ABILITY_INVALIDATION_EVENTS[reason] and type(record) == "table" then
        local fingerprint = GetFarstriderTravelStateFingerprint(true)
        if type(fingerprint) == "string" then
            if record._farstriderTravelStateFingerprint == fingerprint then
                record._farstriderLastInvalidationSkipped = reason
                record._farstriderLastInvalidationSkippedAt = type(GetTime) == "function" and GetTime() or nil
                return false
            end
            record._farstriderTravelStateFingerprint = fingerprint
        end
    end
    if type(NS.NoteRouteBackendInvalidated) == "function" then
        return NS.NoteRouteBackendInvalidated("farstrider", reason or "farstrider_invalidated")
    end
    return false
end

function backend.Initialize()
    if backend._eventFrame then
        return
    end

    local frame = CreateFrame("Frame")
    backend._eventFrame = frame
    for event in pairs(FARSTRIDER_INVALIDATION_EVENTS) do
        frame:RegisterEvent(event)
    end
    frame:SetScript("OnEvent", function(_, event)
        backend.OnPlanInvalidated(event)
    end)
end
