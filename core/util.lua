local NS = _G.ZygorWaypointNS
local C = NS.Constants

-- ============================================================
-- Addon accessors
-- ============================================================

function NS.GetTomTom()
    return _G["TomTom"]
end

function NS.GetTomTomArrow()
    return _G["TomTomCrazyArrow"]
end

function NS.IsAddonLoaded(name)
    if type(name) ~= "string" or name == "" then
        return false
    end
    return C_AddOns.IsAddOnLoaded(name)
end

function NS.GetCurrentCharacterName()
    if type(UnitNameUnmodified) == "function" then
        return UnitNameUnmodified("player")
    end
    if type(UnitName) == "function" then
        return UnitName("player")
    end
    return nil
end

function NS.IsAddonEnabledForCurrentCharacter(name)
    if type(name) ~= "string" or name == "" then
        return false
    end
    if type(C_AddOns) ~= "table" or type(C_AddOns.GetAddOnEnableState) ~= "function" then
        return NS.IsAddonLoaded(name)
    end

    local characterName = NS.GetCurrentCharacterName()
    if type(characterName) ~= "string" or characterName == "" then
        return NS.IsAddonLoaded(name)
    end

    return (tonumber(C_AddOns.GetAddOnEnableState(name, characterName)) or 0) > 0
end

function NS.DisableAddonForCurrentCharacter(name)
    if type(name) ~= "string" or name == "" then
        return false
    end

    local characterName = NS.GetCurrentCharacterName()
    if type(characterName) ~= "string" or characterName == "" then
        return false
    end

    if type(C_AddOns) == "table" and type(C_AddOns.DisableAddOn) == "function" then
        return pcall(C_AddOns.DisableAddOn, name, characterName)
    end

    return false
end

-- ============================================================
-- Text utilities
-- ============================================================

function NS.IsBlankText(value)
    return type(value) ~= "string" or value:match("^%s*$") ~= nil
end

-- ============================================================
-- Waypoint introspection
-- ============================================================

function NS.ReadWaypointCoords(waypoint)
    if type(waypoint) ~= "table" then
        return
    end

    return waypoint.map or waypoint.mapid or waypoint.mapID or waypoint.m,
        waypoint.x or waypoint.mapx or waypoint.wx,
        waypoint.y or waypoint.mapy or waypoint.wy
end

local _normalizeTitleCache = {}
local _normalizeTitleCacheSize = 0
local NORMALIZE_TITLE_CACHE_MAX = 64

function NS.NormalizeWaypointTitle(title)
    if title == nil then
        return
    end

    local key = tostring(title)
    local cached = _normalizeTitleCache[key]
    if cached ~= nil then
        return cached ~= "" and cached or nil
    end

    local result = key
    result = result:gsub("[\r\n]+", " ")
    result = result:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "")
    result = result:gsub("%s*%d+[%.,]%s*%d+%s*,?%s*", " ")
    result = result:gsub("%s*%d+[%.,]%s*%d+%s*$", " ")
    result = result:gsub("%s+", " "):gsub("^%s+", ""):gsub("%s+$", "")

    if _normalizeTitleCacheSize >= NORMALIZE_TITLE_CACHE_MAX then
        _normalizeTitleCache = {}
        _normalizeTitleCacheSize = 0
    end

    if result == "" then
        _normalizeTitleCache[key] = ""
        _normalizeTitleCacheSize = _normalizeTitleCacheSize + 1
        return
    end

    _normalizeTitleCache[key] = result
    _normalizeTitleCacheSize = _normalizeTitleCacheSize + 1
    return result
end

function NS.ResolveWaypointOwner(waypoint)
    if type(waypoint) ~= "table" then
        return
    end

    local surrogate = waypoint.surrogate_for
    if type(surrogate) == "table" then
        return surrogate
    end

    local sourceWaypoint = waypoint.pathnode and waypoint.pathnode.waypoint
    if type(sourceWaypoint) == "table" then
        return sourceWaypoint
    end

    return waypoint
end

function NS.IsWaypointOwnedBy(waypoint, owner)
    if type(waypoint) ~= "table" or type(owner) ~= "table" then
        return false
    end

    return NS.ResolveWaypointOwner(waypoint) == owner
end

function NS.GetWaypointKind(waypoint, source)
    local owner = NS.ResolveWaypointOwner(waypoint)
    local ownerType = owner and owner.type or nil
    if ownerType == "manual" then
        return "manual"
    end
    if ownerType == "corpse" then
        return "corpse"
    end

    if type(waypoint) == "table" then
        local waypointType = waypoint.type
        if waypointType == "route" or waypointType == "path" or waypoint.pathnode or waypoint.in_set then
            return "route"
        end
    end

    if type(source) == "string" and (source:find("^step%.goal#") or source == "text+playerMap") then
        return "guide"
    end

    return "guide"
end

local function IsRouteLikeWaypoint(waypoint)
    if type(waypoint) ~= "table" then
        return false
    end

    local waypointType = waypoint.type
    return waypointType == "route" or waypointType == "path" or waypoint.pathnode ~= nil or waypoint.in_set ~= nil
end

local routeInstanceInfoCache = {}

local function GetRouteInstanceInfo(destinationMapID)
    if type(destinationMapID) ~= "number" or destinationMapID <= 0 then
        return nil
    end

    local cached = routeInstanceInfoCache[destinationMapID]
    if cached ~= nil then
        return cached == false and nil or cached
    end

    local mapInfo = C_Map.GetMapInfo and C_Map.GetMapInfo(destinationMapID) or nil
    local parentMapID = mapInfo and mapInfo.parentMapID or nil
    if type(parentMapID) ~= "number" or parentMapID <= 0 then
        routeInstanceInfoCache[destinationMapID] = false
        return nil
    end

    local mapType = mapInfo and mapInfo.mapType or nil
    if mapType ~= Enum.UIMapType.Dungeon and mapType ~= Enum.UIMapType.Micro then
        routeInstanceInfoCache[destinationMapID] = false
        return nil
    end

    local journalInstanceID = EJ_GetInstanceForMap and EJ_GetInstanceForMap(destinationMapID) or nil
    if type(journalInstanceID) ~= "number" or journalInstanceID <= 0 then
        local Z = NS.ZGV()
        local mapGroupIDs = Z and Z.LibRover and Z.LibRover.data and Z.LibRover.data.MapGroupIDs
        if not mapGroupIDs or not mapGroupIDs[destinationMapID] then
            routeInstanceInfoCache[destinationMapID] = false
            return nil
        end
        local info = { travelType = "delve", parentMapID = parentMapID, name = mapInfo.name }
        routeInstanceInfoCache[destinationMapID] = info
        return info
    end

    local instanceName = nil
    local isRaid = false
    if EJ_GetInstanceInfo then
        local _, _, _, _, _, _, _, _, _, _, _, raidFlag
        instanceName, _, _, _, _, _, _, _, _, _, _, raidFlag = EJ_GetInstanceInfo(journalInstanceID)
        isRaid = raidFlag == true
    end

    local info = {
        travelType = isRaid and "raid" or "dungeon",
        parentMapID = parentMapID,
        journalInstanceID = journalInstanceID,
        name = instanceName,
    }
    routeInstanceInfoCache[destinationMapID] = info
    return info
end

function NS.ResolveInstanceDestinationTravelType(destinationMapID, liveMapID, legKind)
    local instanceInfo = GetRouteInstanceInfo(destinationMapID)
    if type(instanceInfo) ~= "table" then
        return nil
    end
    if type(liveMapID) ~= "number" then
        return nil
    end

    if legKind == "destination" then
        if liveMapID ~= destinationMapID then
            return nil
        end
    elseif legKind == "carrier" then
        if liveMapID ~= instanceInfo.parentMapID then
            return nil
        end
    else
        return nil
    end

    return instanceInfo.travelType, instanceInfo.parentMapID, instanceInfo.journalInstanceID, instanceInfo.name
end

-- ============================================================
-- Travel classification
-- ============================================================

local function GetWaypointTravelNode(waypoint)
    if type(waypoint) ~= "table" then
        return
    end

    if type(waypoint.pathnode) == "table" then
        return waypoint.pathnode, "pathnode"
    end

    local surrogate = waypoint.surrogate_for
    if type(surrogate) == "table" then
        if type(surrogate.pathnode) == "table" then
            return surrogate.pathnode, "surrogate.pathnode"
        end

        local surrogateSourceWaypoint = surrogate.pathnode and surrogate.pathnode.waypoint
        if type(surrogateSourceWaypoint) == "table" and type(surrogateSourceWaypoint.pathnode) == "table" then
            return surrogateSourceWaypoint.pathnode, "surrogate.pathnode.waypoint.pathnode"
        end
    end

    local sourceWaypoint = waypoint.pathnode and waypoint.pathnode.waypoint
    if type(sourceWaypoint) == "table" and type(sourceWaypoint.pathnode) == "table" then
        return sourceWaypoint.pathnode, "pathnode.waypoint.pathnode"
    end
end

local function GetTravelField(node, key)
    if type(node) ~= "table" then
        return
    end

    if node[key] ~= nil then
        return node[key], "node." .. key
    end

    local link = node.link
    if type(link) == "table" and link[key] ~= nil then
        return link[key], "node.link." .. key
    end
end

local function NormalizeTravelMode(mode)
    if type(mode) ~= "string" then
        return
    end

    mode = mode:lower():gsub("^%s+", ""):gsub("%s+$", "")
    if mode == "" then
        return
    end

    return mode
end

local function NormalizeTravelToken(value)
    return NormalizeTravelMode(value)
end

local function GetTravelNodeType(node)
    if type(node) ~= "table" then
        return
    end

    return NormalizeTravelToken(node.subtype or node.type)
end

local function GetTravelNodeNextType(node)
    if type(node) ~= "table" or type(node.next) ~= "table" then
        return
    end

    return NormalizeTravelToken(node.next.subtype or node.next.type)
end

local function GetTravelNodeTemplate(node)
    local template = GetTravelField(node, "template")
    return NormalizeTravelToken(template)
end

local function GetTravelNodeContext(node)
    if type(node) ~= "table" then
        return
    end

    return NormalizeTravelToken(node.a_b__c_d or node.a_b)
end

local function ContainsTravelToken(value, token)
    return type(value) == "string"
        and type(token) == "string"
        and token ~= ""
        and value:find(token, 1, true) ~= nil
end

local function IsPortalContextPattern(context)
    return ContainsTravelToken(context, "__portal_")
        or ContainsTravelToken(context, "__portalauto_")
        or ContainsTravelToken(context, "__portaldungeonenter_")
        or ContainsTravelToken(context, "__portaldungeonexit_")
        or ContainsTravelToken(context, "__pinkportal_")
        or ContainsTravelToken(context, "__darkportal_")
        or ContainsTravelToken(context, "__darkportalred_")
        or ContainsTravelToken(context, "__cityportal_")
end

local function DetectTravelTypeFromNodeSemantics(node)
    local nodeType = GetTravelNodeType(node)
    if nodeType == "portal" then
        return "portal", "high", true, "node-type"
    end

    local nodeTemplate = GetTravelNodeTemplate(node)
    if ContainsTravelToken(nodeTemplate, "portal") then
        return "portal", "high", true, "node-template"
    end

    local nodeContext = GetTravelNodeContext(node)
    if IsPortalContextPattern(nodeContext) then
        return "portal", "high", true, "node-context"
    end

    local nextType = GetTravelNodeNextType(node)
    if nextType == "portal" then
        return "portal", "high", true, "node-next-type"
    end

    return nil
end

local function NormalizeTravelTitle(title)
    title = NS.NormalizeWaypointTitle(title)
    return type(title) == "string" and title:lower() or nil
end

local function DetectTravelTypeFromTitle(title)
    local normalizedTitle = NormalizeTravelTitle(title)
    if type(normalizedTitle) ~= "string" then
        return nil, nil, false
    end

    if normalizedTitle:find("click the portal", 1, true)
        or normalizedTitle:find("enter the portal", 1, true)
        or normalizedTitle:find("portal to", 1, true)
        or normalizedTitle:find("use the portal", 1, true)
    then
        return "portal", "high", true
    end

    if normalizedTitle:find("take a flight", 1, true)
        or normalizedTitle:find("fly to", 1, true)
        or normalizedTitle:find("flight to", 1, true)
        or normalizedTitle:find("take the flight", 1, true)
        or normalizedTitle:find("begin flying", 1, true)
        or normalizedTitle:find("flying to", 1, true)
    then
        return "taxi", "high", true
    end

    if normalizedTitle:find("queue", 1, true)
        or normalizedTitle:find("dungeon", 1, true)
    then
        return "travel", "high", true
    end

    if normalizedTitle:find("taxi", 1, true) or normalizedTitle:find("flight", 1, true) then
        return "taxi", "medium", false
    end

    return nil, nil, false
end

local function TitleContainsToken(title, token)
    return type(title) == "string"
        and type(token) == "string"
        and token ~= ""
        and title:find(token, 1, true) ~= nil
end

local function LooksLikeExplicitPortalInteractionTitle(title)
    if type(title) ~= "string" then
        return false
    end

    return TitleContainsToken(title, "click the portal")
        or TitleContainsToken(title, "enter the portal")
        or TitleContainsToken(title, "use the portal")
        or TitleContainsToken(title, "go through the portal")
        or TitleContainsToken(title, "pass through the portal")
        or TitleContainsToken(title, "portal back")
        or TitleContainsToken(title, "entrance portal")
        or TitleContainsToken(title, "exit portal")
        or TitleContainsToken(title, "swirling portal")
        or TitleContainsToken(title, "scenic getaway portal")
        or TitleContainsToken(title, "spatial rift")
        or TitleContainsToken(title, "click the rift to")
        or (TitleContainsToken(title, "walk into the") and TitleContainsToken(title, "portal"))
end

local function LooksLikeExplicitTransportInteractionTitle(title)
    if type(title) ~= "string" then
        return false
    end

    return TitleContainsToken(title, "talk to ")
        or TitleContainsToken(title, "board the drill")
        or TitleContainsToken(title, "mole machine")
        or TitleContainsToken(title, "teleporter")
        or TitleContainsToken(title, "teleportation unit")
        or TitleContainsToken(title, "beacon")
        or TitleContainsToken(title, "tablet")
        or TitleContainsToken(title, "control panel")
        or TitleContainsToken(title, "transport pad")
        or TitleContainsToken(title, "transporter")
        or TitleContainsToken(title, "riftstone")
        or TitleContainsToken(title, "ability on-screen")
        or TitleContainsToken(title, "jump to ")
end

local function DetectNonPortalTravelTypeFromTitle(title)
    local normalizedTitle = NormalizeTravelTitle(title)
    if type(normalizedTitle) ~= "string" then
        return nil
    end

    if normalizedTitle:find("take a flight", 1, true)
        or normalizedTitle:find("fly to", 1, true)
        or normalizedTitle:find("flight to", 1, true)
        or normalizedTitle:find("take the flight", 1, true)
        or normalizedTitle:find("begin flying", 1, true)
        or normalizedTitle:find("flying to", 1, true)
    then
        return "taxi"
    end

    if normalizedTitle:find("queue", 1, true)
        or normalizedTitle:find("dungeon", 1, true)
    then
        return "travel"
    end

    if LooksLikeExplicitTransportInteractionTitle(normalizedTitle) then
        return "travel"
    end

    return nil
end

local function ValidatePortalTravelTypeCandidate(travelType, confidence, isExplicit, sourceKind, title)
    if travelType ~= "portal" then
        return travelType, confidence, isExplicit, sourceKind
    end

    local normalizedTitle = NormalizeTravelTitle(title)
    if type(normalizedTitle) ~= "string" then
        return travelType, confidence, isExplicit, sourceKind
    end

    if LooksLikeExplicitPortalInteractionTitle(normalizedTitle) then
        return travelType, confidence, isExplicit, sourceKind
    end

    local nonPortalTravelType = DetectNonPortalTravelTypeFromTitle(normalizedTitle)
    if type(nonPortalTravelType) == "string" then
        local validatedSourceKind = type(sourceKind) == "string" and sourceKind or "portal-candidate"
        return nonPortalTravelType, "high", true, validatedSourceKind .. ":transport-title"
    end

    return travelType, confidence, isExplicit, sourceKind
end

-- ============================================================
-- LibTaxi structured proof
-- ============================================================

local _libTaxiNpcidIndex = nil

local function GetLibTaxiLib()
    local Z = NS.ZGV()
    local lib = Z and Z.LibTaxi
    if lib and type(lib.taxipoints) == "table" then
        return lib
    end
    return nil
end

local function BuildLibTaxiNpcidIndex()
    if _libTaxiNpcidIndex then
        return _libTaxiNpcidIndex
    end
    local lib = GetLibTaxiLib()
    if not lib then
        return nil
    end

    local npcidIndex = {}
    for _, zones in pairs(lib.taxipoints) do
        if type(zones) == "table" then
            for _, nodes in pairs(zones) do
                if type(nodes) == "table" then
                    for _, node in ipairs(nodes) do
                        if type(node) == "table" then
                            local nid = node.npcid
                            if type(nid) == "number" and nid > 0 and not npcidIndex[nid] then
                                npcidIndex[nid] = node
                            end
                        end
                    end
                end
            end
        end
    end

    _libTaxiNpcidIndex = npcidIndex
    return npcidIndex
end

local TAXI_COORD_EPSILON = 0.0015

local function CheckLibTaxiNpcidProof(npcid)
    if type(npcid) ~= "number" or npcid <= 0 then
        return false
    end
    local index = BuildLibTaxiNpcidIndex()
    return index ~= nil and index[npcid] ~= nil
end

local function CheckLibTaxiCoordProof(mapID, x, y)
    if type(mapID) ~= "number" or type(x) ~= "number" or type(y) ~= "number" then
        return false
    end
    local lib = GetLibTaxiLib()
    if not lib then
        return false
    end
    local taxiMapID = mapID
    local continentZones
    while taxiMapID and taxiMapID > 0 do
        if lib.taxipoints[taxiMapID] then
            continentZones = lib.taxipoints[taxiMapID]
            break
        end
        local info = C_Map.GetMapInfo(taxiMapID)
        taxiMapID = info and info.parentMapID
    end
    if not continentZones then
        return false
    end
    local mapInfo = C_Map.GetMapInfo(mapID)
    local zoneName = mapInfo and mapInfo.name
    local nodes = zoneName and continentZones[zoneName]
    if type(nodes) ~= "table" then
        return false
    end
    local matchCount = 0
    for _, node in ipairs(nodes) do
        if math.abs(node.x - x) <= TAXI_COORD_EPSILON
            and math.abs(node.y - y) <= TAXI_COORD_EPSILON
        then
            matchCount = matchCount + 1
            if matchCount > 1 then
                return false
            end
        end
    end
    return matchCount == 1
end

local function ClassifyTravelSemanticsImpl(action, npcid, mapID, x, y, rawArrowTitle, detailText)
    if action == "fly" or action == "fpath" or action == "ontaxi" or action == "offtaxi" then
        return "taxi"
    end
    if action == "home" then
        return "inn"
    end
    if action == "hearth" then
        return "hearth"
    end
    if action == "portal" then
        return "portal"
    end

    if CheckLibTaxiNpcidProof(npcid) then
        return "taxi"
    end

    if CheckLibTaxiCoordProof(mapID, x, y) then
        return "taxi"
    end

    local lowerArrow = rawArrowTitle and NormalizeTravelTitle(rawArrowTitle) or nil
    local lowerDetail = detailText and NormalizeTravelTitle(detailText) or nil

    local function inAny(token)
        return (lowerArrow and lowerArrow:find(token, 1, true) ~= nil)
            or (lowerDetail and lowerDetail:find(token, 1, true) ~= nil)
    end

    if inAny("portal") then
        return "portal"
    end
    if inAny("queue") or inAny("dungeon") then
        return "travel"
    end
    if inAny("take a flight") or inAny("fly to") or inAny("flight to") or inAny("take the flight")
        or inAny("begin flying") or inAny("flying to")
    then
        return "taxi"
    end
    if inAny("taxi") or inAny("flight") then
        return "taxi"
    end

    return nil
end

function NS.ClassifyTravelSemantics(action, npcid, mapID, x, y, rawArrowTitle, detailText)
    return ClassifyTravelSemanticsImpl(action, npcid, mapID, x, y, rawArrowTitle, detailText)
end

function NS.GetWaypointTravelMode(waypoint)
    local node = GetWaypointTravelNode(waypoint)
    local mode = GetTravelField(node, "mode")
    return NormalizeTravelMode(mode)
end

local waypointTravelDescriptor = {}

local function ResolveWaypointTravelDescriptorFields(waypoint, source, title, routeTravelType, routeLegKind, routeSource)
    if type(waypoint) ~= "table" then
        return nil
    end

    local owner = NS.ResolveWaypointOwner(waypoint)
    local ownerType = owner and owner.type or waypoint.type
    if (ownerType == "manual" or ownerType == "corpse") and not IsRouteLikeWaypoint(waypoint) then
        return nil
    end

    local node = GetWaypointTravelNode(waypoint)
    local mode = NormalizeTravelMode(GetTravelField(node, "mode"))
    local spell = GetTravelField(node, "spell")
    local item = GetTravelField(node, "item")
    local toy = GetTravelField(node, "toy")
    local arrivalToy = GetTravelField(node, "arrivaltoy")
    local initFunc = GetTravelField(node, "initfunc")
    local atlas = GetTravelField(node, "atlas")

    local travelType, confidence, isExplicit, sourceKind = DetectTravelTypeFromNodeSemantics(node)

    if type(travelType) ~= "string" then
        local wm, wx, wy = NS.ReadWaypointCoords(waypoint)
        if CheckLibTaxiCoordProof(wm, wx, wy) then
            travelType = "taxi"
            confidence = "high"
            isExplicit = true
            sourceKind = "libtaxi-coord"
        end
    end

    if type(travelType) ~= "string" then
        travelType, confidence, isExplicit = DetectTravelTypeFromTitle(title)
        sourceKind = type(confidence) == "string" and "title" or nil
    end

    if spell ~= nil or item ~= nil or toy ~= nil or arrivalToy ~= nil or initFunc ~= nil or atlas ~= nil then
        if type(travelType) ~= "string" then
            if mode == "hearth" then
                travelType = "hearth"
            elseif type(mode) == "string" and mode:find("portal", 1, true) then
                travelType = "portal"
            else
                travelType = "travel"
            end
        end
        confidence = "high"
        isExplicit = true
        sourceKind = "node"
    end

    if type(travelType) ~= "string" and type(mode) == "string" then
        if mode == "hearth" or mode:find("hearth", 1, true) then
            travelType = "hearth"
            confidence = "high"
            isExplicit = true
            sourceKind = "mode"
        elseif mode:find("portal", 1, true) then
            travelType = "portal"
            confidence = "high"
            isExplicit = true
            sourceKind = "mode"
        elseif mode == "spell" or mode == "item" or mode == "toy" then
            travelType = "travel"
            confidence = "high"
            isExplicit = true
            sourceKind = "mode"
        elseif mode:find("fly", 1, true) or mode:find("taxi", 1, true) or mode:find("flight", 1, true) then
            travelType = "taxi"
            confidence = "low"
            isExplicit = false
            sourceKind = "mode"
        end
    end

    if type(routeTravelType) == "string"
        and (
            type(travelType) ~= "string"
            or (travelType == "travel" and sourceKind == "title")
        )
    then
        local routeSourceKind = "route-instance"
        if type(routeLegKind) == "string" and routeLegKind ~= "" then
            routeSourceKind = routeSourceKind .. ":" .. routeLegKind
        end
        return routeTravelType, "high", true, routeSourceKind, mode, routeSource or source
    end

    if type(travelType) ~= "string" then
        return nil
    end

    travelType, confidence, isExplicit, sourceKind = ValidatePortalTravelTypeCandidate(
        travelType,
        confidence,
        isExplicit,
        sourceKind,
        title
    )

    return travelType, confidence or "low", isExplicit == true, sourceKind or "unknown", mode, source
end

NS.GetWaypointTravelDescriptorFields = ResolveWaypointTravelDescriptorFields

function NS.GetWaypointTravelDescriptor(waypoint, source, title)
    local travelType, confidence, isExplicit, sourceKind, mode, descriptorSource =
        ResolveWaypointTravelDescriptorFields(waypoint, source, title)
    if type(travelType) ~= "string" then
        return nil
    end

    waypointTravelDescriptor.travelType = travelType
    waypointTravelDescriptor.confidence = confidence
    waypointTravelDescriptor.isExplicit = isExplicit
    waypointTravelDescriptor.sourceKind = sourceKind
    waypointTravelDescriptor.mode = mode
    waypointTravelDescriptor.source = descriptorSource
    return waypointTravelDescriptor
end

function NS.IsZygorSpecialTravelIconWaypoint(waypoint)
    if type(waypoint) ~= "table" then
        return false
    end

    local owner = NS.ResolveWaypointOwner(waypoint)
    local ownerType = owner and owner.type or waypoint.type
    if ownerType == "manual" or ownerType == "corpse" then
        return false
    end

    local node = GetWaypointTravelNode(waypoint)
    if type(node) ~= "table" then
        return false
    end

    local spell = GetTravelField(node, "spell")
    local item = GetTravelField(node, "item")
    local toy = GetTravelField(node, "toy")
    local arrivalToy = GetTravelField(node, "arrivaltoy")
    local initFunc = GetTravelField(node, "initfunc")
    local atlas = GetTravelField(node, "atlas")
    local mode = GetTravelField(node, "mode")

    if spell ~= nil or item ~= nil or toy ~= nil or arrivalToy ~= nil or initFunc ~= nil or atlas ~= nil then
        return true
    end

    if type(mode) == "string" then
        mode = mode:lower()
        if mode == "hearth" or mode == "spell" or mode == "item" or mode == "toy" or mode == "portal" then
            return true
        end
    end

    return false
end

local function GetCurrentZygorSpecialTravelIconWaypoint()
    local _, pointer, arrowFrame = NS.GetArrowFrame()
    if not pointer then
        _, pointer = NS.GetZygorPointer()
        arrowFrame = pointer and pointer.ArrowFrame or nil
    end

    if not pointer then
        return
    end

    local w
    w = arrowFrame and arrowFrame.waypoint
    if w and NS.IsZygorSpecialTravelIconWaypoint(w) then return w end
    w = pointer.current_waypoint
    if w and NS.IsZygorSpecialTravelIconWaypoint(w) then return w end
    w = pointer.arrow and pointer.arrow.waypoint
    if w and NS.IsZygorSpecialTravelIconWaypoint(w) then return w end
    w = pointer.DestinationWaypoint
    if w and NS.IsZygorSpecialTravelIconWaypoint(w) then return w end
    w = pointer.waypoint
    if w and NS.IsZygorSpecialTravelIconWaypoint(w) then return w end
    w = type(pointer.waypoints) == "table" and pointer.waypoints[1] or nil
    if w and NS.IsZygorSpecialTravelIconWaypoint(w) then return w end
end

function NS.IsCurrentZygorSpecialTravelIconActive()
    return GetCurrentZygorSpecialTravelIconWaypoint() ~= nil
end

function NS.GetCurrentZygorSpecialTravelIconSignature()
    local waypoint = GetCurrentZygorSpecialTravelIconWaypoint()
    local mapID, x, y = NS.ReadWaypointCoords(waypoint)
    if type(mapID) ~= "number" or type(x) ~= "number" or type(y) ~= "number" then
        return
    end

    return NS.Signature(mapID, x, y)
end

-- ============================================================
-- Player and map utilities
-- ============================================================

function NS.GetPlayerMapID()
    if type(C_Map.GetBestMapForUnit) ~= "function" then
        return
    end

    local playerMapID = C_Map.GetBestMapForUnit("player")
    if type(playerMapID) ~= "number" then
        return
    end

    return playerMapID
end

function NS.GetZygorPointer()
    local Z = NS.ZGV()
    local P = Z and Z.Pointer
    if not P then
        return
    end

    return Z, P
end

function NS.GetArrowFrame()
    local Z, P = NS.GetZygorPointer()
    local frame = P and P.ArrowFrame
    if not frame then
        return
    end

    return Z, P, frame
end

function NS.ResolveWaypointBySource(source)
    local _, pointer, arrowFrame = NS.GetArrowFrame()
    if not pointer then
        _, pointer = NS.GetZygorPointer()
        arrowFrame = pointer and pointer.ArrowFrame or nil
    end
    if type(pointer) ~= "table" then
        return nil
    end

    if source == "pointer.ArrowFrame.waypoint" then
        return arrowFrame and arrowFrame.waypoint or nil
    end
    if source == "pointer.arrow.waypoint" then
        return pointer.arrow and pointer.arrow.waypoint or nil
    end
    if source == "pointer.DestinationWaypoint" then
        return pointer.DestinationWaypoint
    end
    if source == "pointer.waypoint" then
        return pointer.waypoint
    end
    if source == "pointer.current_waypoint" then
        return pointer.current_waypoint
    end
    if source == "pointer.waypoints[1]" then
        return type(pointer.waypoints) == "table" and pointer.waypoints[1] or nil
    end

    return nil
end

function NS.SafeCall(fn, ...)
    if type(fn) ~= "function" then
        return
    end

    return fn(...)
end

function NS.GetPlayerWaypointDistance(mapID, x, y)
    local HBD = _G.LibStub and LibStub("HereBeDragons-2.0", true)
    if not HBD or type(mapID) ~= "number" or type(x) ~= "number" or type(y) ~= "number" then
        return
    end

    ---@diagnostic disable-next-line: redundant-parameter
    local px, py, playerMapID = HBD:GetPlayerZonePosition(true)
    if not (px and py and playerMapID) then
        return
    end

    local distance = HBD:GetZoneDistance(playerMapID, px, py, mapID, x, y)
    if type(distance) == "number" then
        return distance
    end
end

function NS.GetCurrentUserWaypoint()
    if not (type(C_Map.HasUserWaypoint) == "function" and C_Map.HasUserWaypoint()) then
        return
    end

    local waypoint = C_Map.GetUserWaypoint and C_Map.GetUserWaypoint()
    if not waypoint or not waypoint.uiMapID or not waypoint.position then
        return
    end

    return waypoint.uiMapID, waypoint.position.x, waypoint.position.y
end

function NS.BuildUserWaypointPoint(mapID, x, y)
    if type(mapID) ~= "number" or type(x) ~= "number" or type(y) ~= "number" then
        return
    end
    if type(CreateVector2D) ~= "function"
        or type(UiMapPoint) ~= "table"
        or type(UiMapPoint.CreateFromVector2D) ~= "function"
    then
        return
    end

    return UiMapPoint.CreateFromVector2D(mapID, CreateVector2D(x, y))
end

-- ============================================================
-- Coordinate utilities
-- ============================================================

function NS.StabilizeCoordForUserWaypoint(v)
    if type(v) ~= "number" then
        return v
    end

    v = v + C.USER_WAYPOINT_COORD_BIAS
    if v < 0 then return 0 end
    if v > 1 then return 1 end
    return v
end

local _settableCacheInMapID, _settableCacheInX, _settableCacheInY
local _settableCacheOutMapID, _settableCacheOutX, _settableCacheOutY
local _settableCacheHasResult = false

function NS.InvalidateSettableUserWaypointCache()
    _settableCacheInMapID = nil
    _settableCacheInX = nil
    _settableCacheInY = nil
    _settableCacheOutMapID = nil
    _settableCacheOutX = nil
    _settableCacheOutY = nil
    _settableCacheHasResult = false
end

function NS.ResolveSettableUserWaypointTarget(mapID, x, y)
    local churn = NS.State.churn
    if churn and churn.active then
        churn.resolveSettableTarget = churn.resolveSettableTarget + 1
    end
    if type(mapID) ~= "number" or type(x) ~= "number" or type(y) ~= "number" then
        return
    end

    if mapID == _settableCacheInMapID and x == _settableCacheInX and y == _settableCacheInY then
        if _settableCacheHasResult then
            return _settableCacheOutMapID, _settableCacheOutX, _settableCacheOutY
        end
        return
    end

    _settableCacheInMapID = mapID
    _settableCacheInX = x
    _settableCacheInY = y
    _settableCacheHasResult = false
    _settableCacheOutMapID = nil
    _settableCacheOutX = nil
    _settableCacheOutY = nil

    if type(C_Map.CanSetUserWaypointOnMap) ~= "function" then
        _settableCacheOutMapID = mapID
        _settableCacheOutX = x
        _settableCacheOutY = y
        _settableCacheHasResult = true
        return mapID, x, y
    end

    if C_Map.CanSetUserWaypointOnMap(mapID) then
        _settableCacheOutMapID = mapID
        _settableCacheOutX = x
        _settableCacheOutY = y
        _settableCacheHasResult = true
        return mapID, x, y
    end

    if type(C_Map.GetMapInfo) ~= "function"
        or type(C_Map.GetWorldPosFromMapPos) ~= "function"
        or type(CreateVector2D) ~= "function"
    then
        return
    end

    local currentMapID, currentX, currentY = mapID, x, y
    for _ = 1, C.MAX_PARENT_MAP_DEPTH do
        local mapInfo = C_Map.GetMapInfo(currentMapID)
        local parentMapID = mapInfo and mapInfo.parentMapID
        if type(parentMapID) ~= "number" or parentMapID == 0 then
            return
        end

        local _, childOrigin = C_Map.GetWorldPosFromMapPos(currentMapID, CreateVector2D(0, 0))
        local _, childRightEdge = C_Map.GetWorldPosFromMapPos(currentMapID, CreateVector2D(1, 0))
        local _, childBottomEdge = C_Map.GetWorldPosFromMapPos(currentMapID, CreateVector2D(0, 1))
        local _, parentOrigin = C_Map.GetWorldPosFromMapPos(parentMapID, CreateVector2D(0, 0))
        local _, parentRightEdge = C_Map.GetWorldPosFromMapPos(parentMapID, CreateVector2D(1, 0))
        local _, parentBottomEdge = C_Map.GetWorldPosFromMapPos(parentMapID, CreateVector2D(0, 1))
        if not (childOrigin and childRightEdge and childBottomEdge and parentOrigin and parentRightEdge and parentBottomEdge) then
            return
        end

        local worldX = childOrigin.x
            + currentX * (childRightEdge.x - childOrigin.x)
            + currentY * (childBottomEdge.x - childOrigin.x)
        local worldY = childOrigin.y
            + currentX * (childRightEdge.y - childOrigin.y)
            + currentY * (childBottomEdge.y - childOrigin.y)

        local offsetX = worldX - parentOrigin.x
        local offsetY = worldY - parentOrigin.y
        local parentBasisXx = parentRightEdge.x - parentOrigin.x
        local parentBasisYx = parentBottomEdge.x - parentOrigin.x
        local parentBasisXy = parentRightEdge.y - parentOrigin.y
        local parentBasisYy = parentBottomEdge.y - parentOrigin.y
        local determinant = parentBasisXx * parentBasisYy - parentBasisYx * parentBasisXy
        if determinant == 0 then
            return
        end

        local parentX = (offsetX * parentBasisYy - offsetY * parentBasisYx) / determinant
        local parentY = (offsetY * parentBasisXx - offsetX * parentBasisXy) / determinant
        local epsilon = C.COORD_BOUNDS_EPSILON
        if parentX < -epsilon or parentX > 1 + epsilon
            or parentY < -epsilon or parentY > 1 + epsilon
        then
            return
        end

        parentX = math.max(0, math.min(1, parentX))
        parentY = math.max(0, math.min(1, parentY))

        if C_Map.CanSetUserWaypointOnMap(parentMapID) then
            _settableCacheOutMapID = parentMapID
            _settableCacheOutX = parentX
            _settableCacheOutY = parentY
            _settableCacheHasResult = true
            return parentMapID, parentX, parentY
        end

        currentMapID, currentX, currentY = parentMapID, parentX, parentY
    end
end

local _sigCacheM, _sigCacheX, _sigCacheY, _sigCacheResult

function NS.Signature(m, x, y)
    if type(x) == "number" then
        x = math.floor(x * 10000 + 0.5) / 10000
    end
    if type(y) == "number" then
        y = math.floor(y * 10000 + 0.5) / 10000
    end
    if m == _sigCacheM and x == _sigCacheX and y == _sigCacheY then
        return _sigCacheResult
    end
    local result = string.format("%s:%.4f:%.4f", tostring(m), x or 0, y or 0)
    _sigCacheM = m
    _sigCacheX = x
    _sigCacheY = y
    _sigCacheResult = result
    return result
end
