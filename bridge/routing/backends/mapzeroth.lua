local NS = _G.AzerothWaypointNS
local RouteSpecials = NS.RouteSpecials or {}

-- ============================================================
-- Mapzeroth backend
-- ============================================================

local backend = {}
NS.RoutingBackend_Mapzeroth = backend

backend.id = "mapzeroth"

local MOVEMENT_ADVANCE_YARDS = 55
local INSTANCE_NODE_COORD_EPSILON = 0.025
local ABILITY_INVALIDATION_EVENTS = {
    BAG_UPDATE_DELAYED = true,
    HEARTHSTONE_BOUND = true,
    SPELL_UPDATE_COOLDOWN = true,
    SPELLS_CHANGED = true,
    TOYS_UPDATED = true,
}
local VOLATILE_ABILITY_FIELDS = {
    cooldownRemaining = true,
    duration = true,
    enable = true,
    remaining = true,
    startTime = true,
}
local MOVEMENT_METHOD = {
    walk = true,
    fly = true,
    _INITIAL_STEP = true,
}
local STORMWIND_MAGE_TOWER_ENTRANCE_NODE_ID = "STORMWIND_MAGE_TOWER_ENTRANCE"
local MAPZEROTH_WIZARDS_SANCTUM_NODE_IDS = {
    STORMWIND_PORTAL_ROOM_LOWER = true,
    STORMWIND_PORTAL_ROOM_UPPER = true,
    STORMWIND_DARK_PORTAL_BL_NPC = true,
}

local function GetMapzeroth()
    return rawget(_G, "Mapzeroth")
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

local function GetTravelNode(mz, nodeID)
    if type(nodeID) ~= "string" or nodeID == "" or type(mz) ~= "table" or type(mz.GetTravelNode) ~= "function" then
        return nil
    end
    return mz:GetTravelNode(nodeID)
end

local function IsMapzerothWizardsSanctumNode(mz, nodeID)
    local node = GetTravelNode(mz, nodeID)
    if type(node) ~= "table" or node.mapID ~= RouteSpecials.STORMWIND_MAP_ID or node.interior ~= true then
        return false
    end
    return MAPZEROTH_WIZARDS_SANCTUM_NODE_IDS[nodeID] == true
        or nodeID:match("^STORMWIND_.+_PORTAL$") ~= nil
end

local function CoordsMatch(mapID, x, y, targetMapID, targetX, targetY, epsilon)
    if type(RouteSpecials.CoordsMatch) == "function" then
        return RouteSpecials.CoordsMatch(mapID, x, y, targetMapID, targetX, targetY, epsilon)
    end
    return false
end

local function ResolveMageTowerEntryCoords(mz)
    local node = GetTravelNode(mz, STORMWIND_MAGE_TOWER_ENTRANCE_NODE_ID)
    if type(node) == "table"
        and type(node.mapID) == "number"
        and type(node.x) == "number"
        and type(node.y) == "number"
    then
        return node.mapID, node.x, node.y
    end
    return RouteSpecials.GetMageTowerEntryFallback()
end

local function IsMageTowerEntryLeg(mz, leg)
    local mapID, x, y = ResolveMageTowerEntryCoords(mz)
    return type(RouteSpecials.IsMageTowerEntryLeg) == "function"
        and RouteSpecials.IsMageTowerEntryLeg(leg, mapID, x, y, INSTANCE_NODE_COORD_EPSILON)
        or false
end

local function EnsureMageTowerEntryBeforeWizardsSanctumLeg(mz, legs)
    local mapID, x, y = ResolveMageTowerEntryCoords(mz)
    RouteSpecials.EnsureMageTowerEntryBeforeWizardsSanctumLeg(legs, "mapzeroth", mapID, x, y, function(leg)
        return IsMageTowerEntryLeg(mz, leg)
    end)
end

local function IsInstancePlanningWaypoint(waypoint)
    return type(waypoint) == "table" and type(waypoint.instanceRouteIntent) == "table"
end

local function MapzerothCategoryForTravelType(travelType)
    if travelType == "bountiful_delve" then
        return "delve"
    end
    return travelType
end

local function FindMapzerothEntranceNode(mz, intent)
    local entrance = type(intent) == "table" and intent.entrance or nil
    local graph = type(mz) == "table" and mz.TravelGraph or nil
    local nodes = type(graph) == "table" and graph.nodes or nil
    if type(entrance) ~= "table" or type(nodes) ~= "table" then
        return nil
    end

    local wantedCategory = MapzerothCategoryForTravelType(intent.travelType)
    local bestNodeID, bestScore
    for _, groupData in pairs(nodes) do
        if type(groupData) == "table" then
            for nodeID, node in pairs(groupData) do
                if type(node) == "table"
                    and type(nodeID) == "string"
                    and node.category == wantedCategory
                    and CoordsMatch(
                        node.mapID,
                        node.x,
                        node.y,
                        entrance.mapID,
                        entrance.x,
                        entrance.y,
                        INSTANCE_NODE_COORD_EPSILON
                    )
                then
                    local dx = node.x - entrance.x
                    local dy = node.y - entrance.y
                    local score = dx * dx + dy * dy
                    if not bestScore or score < bestScore then
                        bestNodeID = nodeID
                        bestScore = score
                    end
                end
            end
        end
    end

    return bestNodeID
end

local function BuildPlanningTarget(mz, mapID, x, y, title)
    local waypoint = {
        mapID = mapID,
        x = x,
        y = y,
        name = title or "Route",
    }
    local target = {
        destinationID = "_WAYPOINT_DESTINATION",
        waypoint = waypoint,
        syntheticWaypoint = waypoint,
        reason = "mapzeroth_plan",
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

    local instanceName = type(intent) == "table" and intent["instanceName"] or nil
    waypoint = {
        mapID = entrance.mapID,
        x = entrance.x,
        y = entrance.y,
        name = title or instanceName or "Route",
        finalMapID = mapID,
        finalX = x,
        finalY = y,
        finalTitle = title,
        instanceRouteIntent = intent,
    }
    target.waypoint = waypoint
    target.syntheticWaypoint = waypoint
    target.instanceRouteIntent = intent
    target.reason = "mapzeroth_instance_entrance_plan"

    local nodeID = FindMapzerothEntranceNode(mz, intent)
    if type(nodeID) == "string" and nodeID ~= "" then
        waypoint.destinationID = nodeID
        target.destinationID = nodeID
        target.syntheticWaypoint = nil
        target.reason = "mapzeroth_instance_node_plan"
    end

    return target
end

local function ResolveSpellName(spellID)
    if type(spellID) ~= "number" then return nil end
    if type(C_Spell) == "table" and type(C_Spell.GetSpellName) == "function" then
        return C_Spell.GetSpellName(spellID)
    end
    return nil
end

local function BuildAbilityIndex(abilities)
    local index = {
        bySpellID = {},
        byItemID = {},
        byName = {},
    }
    if type(abilities) ~= "table" then
        return index
    end
    for _, ability in ipairs(abilities) do
        if type(ability) == "table" then
            if type(ability.spellID) == "number" then
                index.bySpellID[ability.spellID] = ability
            end
            if type(ability.itemID) == "number" then
                index.byItemID[ability.itemID] = ability
            end
            if type(ability.name) == "string" then
                index.byName[ability.name:lower()] = ability
            end
        end
    end
    return index
end

local function SerializeAbilityValue(value, depth)
    depth = tonumber(depth) or 0
    local valueType = type(value)
    if valueType == "nil" then
        return "-"
    end
    if valueType == "number" or valueType == "boolean" or valueType == "string" then
        return tostring(value)
    end
    if valueType ~= "table" then
        return valueType
    end
    if depth >= 3 then
        return "{...}"
    end

    local keys = {}
    for key, child in pairs(value) do
        if not VOLATILE_ABILITY_FIELDS[key] and type(child) ~= "function" then
            keys[#keys + 1] = key
        end
    end
    table.sort(keys, function(a, b)
        return tostring(a) < tostring(b)
    end)

    local parts = {}
    for index = 1, #keys do
        local key = keys[index]
        parts[#parts + 1] = tostring(key) .. "=" .. SerializeAbilityValue(value[key], depth + 1)
    end
    return "{" .. table.concat(parts, ",") .. "}"
end

local function BuildTravelAbilitiesFingerprint(abilities)
    if type(abilities) ~= "table" then
        return "none"
    end

    local parts = {}
    for index = 1, #abilities do
        local ability = abilities[index]
        if type(ability) == "table" then
            parts[#parts + 1] = SerializeAbilityValue(ability, 0)
        end
    end
    table.sort(parts)
    return table.concat(parts, "|")
end

local function FetchTravelAbilities(mz)
    if type(mz) ~= "table" or type(mz.GetAvailableTravelAbilities) ~= "function" then
        return false, nil
    end
    return pcall(mz.GetAvailableTravelAbilities, mz)
end

local function RememberTravelAbilitiesFingerprint(record, abilities)
    if type(record) == "table" then
        record._mapzerothTravelAbilitiesFingerprint = BuildTravelAbilitiesFingerprint(abilities)
    end
end

local function ResolveAbilityForStep(step, abilityIndex)
    if type(step) ~= "table" or type(abilityIndex) ~= "table" then
        return nil
    end
    if type(step.spellID) == "number" then
        return abilityIndex.bySpellID and abilityIndex.bySpellID[step.spellID] or nil
    end
    if type(step.itemID) == "number" then
        return abilityIndex.byItemID and abilityIndex.byItemID[step.itemID] or nil
    end
    if type(step.abilityName) == "string" then
        return abilityIndex.byName and abilityIndex.byName[step.abilityName:lower()] or nil
    end
    return nil
end

local function ClassifyStepAction(step, abilityIndex)
    if type(step) ~= "table" then
        return nil, nil, nil
    end

    local method = step.method
    if method == "walk" or method == "fly" or method == "_INITIAL_STEP" then
        return nil, nil, nil
    end
    if method == "taxi" then
        return nil, nil, nil
    end

    local ability = ResolveAbilityForStep(step, abilityIndex)
    local abilityType = type(ability) == "table" and ability.type or nil
    local abilityName = type(step.abilityName) == "string" and step.abilityName:lower() or ""
    local isHearthstone = (type(RouteSpecials.IsHearthstoneItemID) == "function" and RouteSpecials.IsHearthstoneItemID(step.itemID))
        or method == "hearthstone"
        or (type(ability) == "table" and ability.isHearthstone == true)
        or abilityName:find("hearthstone", 1, true) ~= nil

    if type(step.spellID) == "number" then
        local kind = "spell"
        if method == "portal" or abilityName:find("portal", 1, true) then
            kind = "portal"
        end
        return kind, "spell", ResolveSpellName(step.spellID) or tostring(step.spellID)
    end

    if type(step.itemID) == "number" then
        if isHearthstone then
            return "hearth", "item", step.itemID
        end
        if method == "toy" or abilityType == "toy" then
            return "toy", "toy", step.itemID
        end
        return "item", "item", step.itemID
    end

    return nil, nil, nil
end

local function ResolveStepDestinationCoords(mz, step, waypoint)
    if step.nodeID == "_WAYPOINT_DESTINATION" then
        return waypoint.mapID, waypoint.x, waypoint.y
    end
    if step.nodeID == "_INITIAL_STEP" or step.nodeID == "_PLAYER_POSITION" then
        return nil, nil, nil
    end
    if step.nodeID and type(mz.GetTravelNode) == "function" then
        local node = mz:GetTravelNode(step.nodeID)
        if node and type(node.mapID) == "number" and type(node.x) == "number" and type(node.y) == "number" then
            return node.mapID, node.x, node.y
        end
    end
    return nil, nil, nil
end

local function ResolveStepSourceNodeID(step, previous)
    if type(step) ~= "table" then
        return nil
    end
    if type(step.fromNodeID) == "string" and step.fromNodeID ~= "" then
        return step.fromNodeID
    end
    local prev = type(previous) == "table" and type(step.nodeID) == "string" and previous[step.nodeID] or nil
    if type(prev) == "table" then
        return prev.fromNode or prev.node
    end
    return nil
end

local function ResolveStepSourceCoords(mz, sourceNodeID, location)
    if sourceNodeID == "_PLAYER_POSITION" or sourceNodeID == "_INITIAL_STEP" then
        if type(location) == "table" then
            return location.mapID, location.x, location.y
        end
        return nil, nil, nil
    end
    if sourceNodeID and type(mz.GetTravelNode) == "function" then
        local node = mz:GetTravelNode(sourceNodeID)
        if node and type(node.mapID) == "number" and type(node.x) == "number" and type(node.y) == "number" then
            return node.mapID, node.x, node.y
        end
    end
    return nil, nil, nil
end

local function ResolveActionActivationMode(sourceNodeID, activationCoords)
    if sourceNodeID == "_PLAYER_POSITION" or sourceNodeID == "_INITIAL_STEP" then
        return "portable"
    end
    if type(activationCoords) == "table" then
        return "location"
    end
    return "portable"
end

local function StepToSpecialAction(step, abilityIndex, activationMode, activationCoords)
    local semanticKind, secureType, securePayload = ClassifyStepAction(step, abilityIndex)
    if not semanticKind or not secureType or securePayload == nil or securePayload == "" then return nil end
    if activationMode == "portable" then
        activationCoords = nil
    else
        activationMode = "location"
    end
    return {
        semanticKind = semanticKind,
        secureType = secureType,
        securePayload = securePayload,
        name = step.abilityName or step.destination,
        destinationName = step.destinationName,
        iconTexture = nil,
        activationMode = activationMode,
        activationCoords = activationCoords,
        activationRadiusYards = 15,
        sourceBackend = "mapzeroth",
    }
end

local function ResolveRouteTravelType(waypoint, mapID, x, y, method, routeLegKind, title)
    routeLegKind = routeLegKind == "destination" and "destination" or "carrier"
    if IsInstancePlanningWaypoint(waypoint) then
        local intent = waypoint.instanceRouteIntent
        if routeLegKind == "destination"
            and CoordsMatch(
                mapID,
                x,
                y,
                intent.final and intent.final.mapID,
                intent.final and intent.final.x,
                intent.final and intent.final.y,
                INSTANCE_NODE_COORD_EPSILON
            )
        then
            return intent.travelType
        end
        if routeLegKind == "carrier"
            and CoordsMatch(mapID, x, y, waypoint.mapID, waypoint.x, waypoint.y, INSTANCE_NODE_COORD_EPSILON)
        then
            return intent.travelType
        end
    end
    if type(NS.ResolveInstanceDestinationTravelType) == "function" then
        local destinationMapID = type(waypoint) == "table" and (waypoint.finalMapID or waypoint.mapID) or nil
        local travelType = NS.ResolveInstanceDestinationTravelType(destinationMapID, mapID, x, y, routeLegKind)
        if type(travelType) == "string" then
            return travelType
        end
    end
    if method == "destination" then
        return nil
    end
    if method == "walk"
        or method == "fly"
        or method == "carrier"
        or method == nil
    then
        return routeLegKind == "carrier" and "travel" or nil
    end
    if method == "hearthstone" then
        return "hearth"
    end
    if routeLegKind == "carrier" and TitleLooksLikePortal(title) then
        return "portal"
    end
    if method ~= "" then
        return method
    end
    return nil
end

local function IsInstanceEntranceStep(step, waypoint, mapID, x, y)
    if not IsInstancePlanningWaypoint(waypoint) or type(step) ~= "table" then
        return false
    end
    if step.nodeID == "_WAYPOINT_DESTINATION" then
        return true
    end
    if type(waypoint.destinationID) == "string" and step.nodeID == waypoint.destinationID then
        return true
    end
    return CoordsMatch(mapID, x, y, waypoint.mapID, waypoint.x, waypoint.y, INSTANCE_NODE_COORD_EPSILON)
end

local function ShouldUseSourceCoordsForCarrier(method, routeLegKind, isInstanceEntrance, sm, sx, sy)
    if routeLegKind ~= "carrier" or isInstanceEntrance then
        return false
    end
    if type(sm) ~= "number" or type(sx) ~= "number" or type(sy) ~= "number" then
        return false
    end
    return MOVEMENT_METHOD[method] ~= true
end

local function StepToLeg(mz, step, waypoint, abilityIndex, location, previous)
    local dm, dx, dy = ResolveStepDestinationCoords(mz, step, waypoint)
    if type(dm) ~= "number" or type(dx) ~= "number" or type(dy) ~= "number" then
        return nil
    end
    local sourceNodeID = ResolveStepSourceNodeID(step, previous)
    local sm, sx, sy = ResolveStepSourceCoords(mz, sourceNodeID, location)
    local activationCoords = type(sm) == "number" and type(sx) == "number" and type(sy) == "number"
        and { mapID = sm, x = sx, y = sy }
        or nil
    local activationMode = ResolveActionActivationMode(sourceNodeID, activationCoords)
    local specialAction = StepToSpecialAction(step, abilityIndex, activationMode, activationCoords)
    local isInstanceEntrance = IsInstanceEntranceStep(step, waypoint, dm, dx, dy)
    local routeLegKind = isInstanceEntrance and "carrier"
        or (step.nodeID == "_WAYPOINT_DESTINATION" and "destination" or "carrier")
    local method = step.method or (routeLegKind == "destination" and "destination" or "carrier")
    local title = step.destination or step.destinationName or step.abilityName
    if isInstanceEntrance then
        method = "portal"
    elseif routeLegKind == "carrier"
        and method ~= "walk"
        and method ~= "fly"
        and TitleLooksLikePortal(title)
    then
        method = "portal"
    end
    local useSourceCoords = ShouldUseSourceCoordsForCarrier(method, routeLegKind, isInstanceEntrance, sm, sx, sy)
    local legMapID = useSourceCoords and sm or dm
    local legX = useSourceCoords and sx or dx
    local legY = useSourceCoords and sy or dy
    return {
        mapID = legMapID,
        x = legX,
        y = legY,
        kind = method,
        routeLegKind = routeLegKind,
        title = title,
        source = "mapzeroth",
        routeTravelType = ResolveRouteTravelType(waypoint, legMapID, legX, legY, method, routeLegKind, title),
        arrivalRadius = (method == "walk" or method == "fly") and MOVEMENT_ADVANCE_YARDS or 15,
        activationCoords = activationCoords,
        specialAction = specialAction,
    }
end

local function AppendInstanceDestinationLeg(legs, waypoint)
    if type(legs) ~= "table" or not IsInstancePlanningWaypoint(waypoint) then
        return
    end

    local intent = waypoint.instanceRouteIntent
    local final = type(intent) == "table" and intent.final or nil
    if type(final) ~= "table"
        or type(final.mapID) ~= "number"
        or type(final.x) ~= "number"
        or type(final.y) ~= "number"
    then
        return
    end

    local last = legs[#legs]
    if type(last) == "table"
        and CoordsMatch(last.mapID, last.x, last.y, final.mapID, final.x, final.y, INSTANCE_NODE_COORD_EPSILON)
    then
        return
    end

    legs[#legs + 1] = {
        mapID = final.mapID,
        x = final.x,
        y = final.y,
        kind = "destination",
        routeLegKind = "destination",
        title = final.title or waypoint.finalTitle or waypoint.name,
        source = "mapzeroth",
        routeTravelType = intent.travelType,
        arrivalRadius = 15,
    }
end

local function AcceptPlan(record, legs, reason)
    if type(NS.AcceptBackendPlan) == "function" then
        return NS.AcceptBackendPlan(record, "mapzeroth", legs, reason)
    end
    record.backend = "mapzeroth"
    record.legs = legs
    record.currentLegIndex = nil
    record.currentLeg = nil
    record.specialAction = nil
    record.replanReason = reason
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
            source = "mapzeroth",
        },
    }, reason)
end

function backend.IsAvailable()
    if type(NS.IsMapzerothLoaded) ~= "function" or not NS.IsMapzerothLoaded() then return false end
    local mz = GetMapzeroth()
    return type(mz) == "table"
        and type(mz.GetPlayerLocation) == "function"
        and type(mz.GetAvailableTravelAbilities) == "function"
        and type(mz.BuildSyntheticEdges) == "function"
        and type(mz.FindPath) == "function"
        and type(mz.BuildStepList) == "function"
        and type(mz.GetTravelNode) == "function"
end

function backend.PlanRoute(record, mapID, x, y, title)
    if type(record) ~= "table" or type(mapID) ~= "number" or type(x) ~= "number" or type(y) ~= "number" then
        return
    end

    local mz = GetMapzeroth()
    if not mz then
        SetDirectFallback(record, mapID, x, y, title, "mapzeroth_missing")
        return
    end

    local target = BuildPlanningTarget(mz, mapID, x, y, title)
    local waypoint = target.waypoint
    local okAbilities, abilities = FetchTravelAbilities(mz)
    if not okAbilities then abilities = nil end
    RememberTravelAbilitiesFingerprint(record, abilities)
    local abilityIndex = BuildAbilityIndex(abilities)

    local okLocation, location = pcall(mz.GetPlayerLocation, mz)
    if not okLocation then location = nil end

    local function FindPath(destinationID, syntheticWaypoint)
        local okSynth, synthetic = pcall(mz.BuildSyntheticEdges, mz, location, abilities, syntheticWaypoint)
        if not okSynth then synthetic = nil end
        return pcall(mz.FindPath, mz, "_PLAYER_POSITION", destinationID, abilities, synthetic)
    end

    local okFind, path, cost, previous = FindPath(target.destinationID, target.syntheticWaypoint)
    if (not okFind or not path)
        and IsInstancePlanningWaypoint(waypoint)
        and target.destinationID ~= "_WAYPOINT_DESTINATION"
    then
        waypoint.destinationID = nil
        target.destinationID = "_WAYPOINT_DESTINATION"
        target.syntheticWaypoint = waypoint
        target.reason = "mapzeroth_instance_entrance_plan"
        okFind, path, cost, previous = FindPath(target.destinationID, target.syntheticWaypoint)
    end
    if not okFind or not path then
        SetDirectFallback(record, mapID, x, y, title, "mapzeroth_nopath_fallback")
        return
    end

    local okSteps, rawSteps = pcall(mz.BuildStepList, mz, path, cost, previous, waypoint)
    if not okSteps or type(rawSteps) ~= "table" or #rawSteps == 0 then
        SetDirectFallback(record, mapID, x, y, title, "mapzeroth_emptysteps_fallback")
        return
    end

    local steps = rawSteps
    if type(mz.OptimizeConsecutiveMovement) == "function" then
        local okOpt, optimized = pcall(mz.OptimizeConsecutiveMovement, mz, rawSteps)
        if okOpt and type(optimized) == "table" and #optimized > 0 then
            steps = optimized
        end
    end

    local legs = {}
    local needsWizardsSanctumEntry = type(RouteSpecials.PlayerNeedsWizardsSanctumEntry) == "function"
        and RouteSpecials.PlayerNeedsWizardsSanctumEntry(location)
        or false
    local wizardsSanctumEntryQueued = false
    for index = 1, #steps do
        local step = steps[index]
        local sourceNodeID = ResolveStepSourceNodeID(step, previous)
        local isWizardsSanctumStep = IsMapzerothWizardsSanctumNode(mz, step and step.nodeID)
            or IsMapzerothWizardsSanctumNode(mz, sourceNodeID)
        local leg = StepToLeg(mz, step, waypoint, abilityIndex, location, previous)
        if leg then
            if isWizardsSanctumStep then
                leg.arrivalGate = RouteSpecials.MakeWizardsSanctumArrivalGate()
                if needsWizardsSanctumEntry and not wizardsSanctumEntryQueued then
                    EnsureMageTowerEntryBeforeWizardsSanctumLeg(mz, legs)
                    wizardsSanctumEntryQueued = true
                end
            end
            legs[#legs + 1] = leg
        end
    end

    if #legs == 0 then
        SetDirectFallback(record, mapID, x, y, title, "mapzeroth_nolegs_fallback")
        return
    end
    AppendInstanceDestinationLeg(legs, waypoint)

    record.backend = "mapzeroth"
    AcceptPlan(record, legs, target.reason or "mapzeroth_plan")
end

function backend.PollCurrentLeg(record)
    if type(NS.PollNeutralRouteLeg) == "function" then
        return NS.PollNeutralRouteLeg(record, "mapzeroth_poll")
    end
    return false
end

function backend.Clear(record)
    if type(record) ~= "table" then return end
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
    record._mapzerothTravelAbilitiesFingerprint = nil
    record._mapzerothLastInvalidationSkipped = nil
    record._mapzerothLastInvalidationSkippedAt = nil
end

local function GetActiveMapzerothRecord()
    local routing = NS.State and NS.State.routing or nil
    local record = routing and routing.manualAuthority or nil
    if not record then
        local guideState = routing and routing.guideRouteState or nil
        if guideState and guideState.target and not guideState.suppressed then
            record = guideState
        end
    end
    if type(record) == "table" and record.backend == "mapzeroth" then
        return record
    end
    return nil
end

function backend.OnPlanInvalidated(reason)
    local record = GetActiveMapzerothRecord()
    if ABILITY_INVALIDATION_EVENTS[reason] and type(record) == "table" then
        local okAbilities, abilities = FetchTravelAbilities(GetMapzeroth())
        if okAbilities then
            local fingerprint = BuildTravelAbilitiesFingerprint(abilities)
            if record._mapzerothTravelAbilitiesFingerprint == fingerprint then
                record._mapzerothLastInvalidationSkipped = reason
                record._mapzerothLastInvalidationSkippedAt = type(GetTime) == "function" and GetTime() or nil
                return false
            end
            record._mapzerothTravelAbilitiesFingerprint = fingerprint
        end
    end
    if type(NS.NoteRouteBackendInvalidated) == "function" then
        return NS.NoteRouteBackendInvalidated("mapzeroth", reason or "mapzeroth_invalidated")
    end
    return false
end

function backend.Initialize()
    if backend._eventFrame then
        return
    end
    local frame = CreateFrame("Frame")
    backend._eventFrame = frame
    frame:RegisterEvent("BAG_UPDATE_DELAYED")
    frame:RegisterEvent("HEARTHSTONE_BOUND")
    frame:RegisterEvent("SPELL_UPDATE_COOLDOWN")
    frame:RegisterEvent("SPELLS_CHANGED")
    frame:RegisterEvent("TOYS_UPDATED")
    frame:RegisterEvent("PLAYER_ENTERING_WORLD")
    frame:SetScript("OnEvent", function(_, event)
        backend.OnPlanInvalidated(event)
    end)
end
