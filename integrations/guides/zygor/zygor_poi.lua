local NS = _G.AzerothWaypointNS
if not NS.IsZygorLoaded() then return end

local state = NS.State
state.zygorPoiTakeover = state.zygorPoiTakeover or {}

local bridge = state.zygorPoiTakeover
local GetActiveManualDestination = NS.GetActiveManualDestination
local ReadWaypointCoords = NS.ReadWaypointCoords
local signature = NS.Signature

local HOOK_RETRY_DELAY_SECONDS = 0.25
local HOOK_RETRY_MAX_COUNT = 20
local GUIDE_LOAD_FALLBACK_DELAY_SECONDS = 0.6
local GUIDE_POI_ADOPTION_DELAYS = { 0, 0.05, 0.15, 0.35 }

local SEARCH_KIND_BY_POI_TYPE = {
    rare = "zygor_poi_rare",
    treasure = "zygor_poi_treasure",
    battlepet = "zygor_poi_battlepet",
    achievement = "zygor_poi_achievement",
    questobjective = "zygor_poi_questobjective",
}

local function NormalizeCoordinate(value)
    local number = tonumber(value)
    if type(number) ~= "number" then
        return nil
    end

    if number > 1 and number <= 100 then
        number = number / 100
    end
    if number < 0 or number > 1 then
        return nil
    end

    return number
end

local function ResolvePointType(point)
    if type(point) ~= "table" then
        return nil
    end

    if type(point.type) == "string" and point.type ~= "" then
        return point.type
    end
    if point.rare then
        return "rare"
    end
    if point.treasure then
        return "treasure"
    end
end

local function ResolveCompletionQuestID(point)
    local questID = type(point) == "table" and tonumber(point.quest) or nil
    if type(questID) == "number" and questID > 0 then
        return questID
    end
end

local function ResolvePointIdent(point)
    if type(point) ~= "table" then
        return nil
    end

    if type(point.ident) == "string" and point.ident ~= "" then
        return point.ident
    end

    local questID = ResolveCompletionQuestID(point)
    if questID then
        return "quest" .. tostring(questID)
    end

    local achievementID = tonumber(point.achieve)
    if type(achievementID) == "number" and achievementID > 0 then
        local criteriaID = tonumber(point.achievecriteria)
        if type(criteriaID) == "number" and criteriaID > 0 then
            return "achieve" .. tostring(achievementID) .. "-" .. tostring(criteriaID)
        end
        return "achieve" .. tostring(achievementID)
    end
end

local function ResolvePointTitle(point)
    if type(point) ~= "table" then
        return "Zygor POI"
    end

    local title = point.name
    if type(title) ~= "string" or title == "" then
        title = point.rare
    end
    if type(title) ~= "string" or title == "" then
        title = point.treasure
    end
    if type(title) ~= "string" or title == "" then
        title = "Zygor POI"
    end

    return title
end

local function ReadZygorPoiPoint(point)
    if type(point) ~= "table" then
        return nil
    end

    local mapID = tonumber(point.map or point.mapid or point.mapID or point.m)
    local x = NormalizeCoordinate(point.x or point.mapx or point.wx)
    local y = NormalizeCoordinate(point.y or point.mapy or point.wy)
    if type(mapID) ~= "number" or not x or not y then
        return nil
    end

    local pointType = ResolvePointType(point)
    local searchKind = SEARCH_KIND_BY_POI_TYPE[pointType] or "zygor_poi"
    return mapID,
        x,
        y,
        ResolvePointTitle(point),
        pointType,
        searchKind,
        ResolvePointIdent(point),
        ResolveCompletionQuestID(point)
end

local function IsSameActiveZygorPoiManual(mapID, x, y, title, pointType, ident)
    local destination = type(GetActiveManualDestination) == "function" and GetActiveManualDestination() or nil
    if type(destination) ~= "table" then
        return false
    end

    local identity = type(destination.identity) == "table" and destination.identity or nil
    if type(identity) ~= "table" or identity.kind ~= "zygor_poi" then
        return false
    end

    local destinationMapID, destinationX, destinationY = ReadWaypointCoords(destination)
    if type(destinationMapID) ~= "number" or type(destinationX) ~= "number" or type(destinationY) ~= "number" then
        return false
    end
    if type(signature) ~= "function"
        or signature(destinationMapID, destinationX, destinationY) ~= signature(mapID, x, y)
    then
        return false
    end

    local destinationTitle = destination["title"]
    return destinationTitle == title
        and identity.poiType == pointType
        and identity.ident == ident
end

local function RefreshZygorPoiPins(Poi)
    if type(Poi) ~= "table" then
        return
    end

    if type(Poi.DataProvider) == "table" and type(Poi.DataProvider.RefreshAllData) == "function" then
        pcall(Poi.DataProvider.RefreshAllData, Poi.DataProvider, true)
    end
    if type(Poi.CurrentZoneDataProvider) == "table"
        and type(Poi.CurrentZoneDataProvider.RefreshPoints) == "function"
    then
        pcall(Poi.CurrentZoneDataProvider.RefreshPoints, Poi.CurrentZoneDataProvider)
    end
end

local function MarkZygorPoiActive(Z, Poi, ident)
    if type(ident) == "string" and ident ~= "" and Z and Z.db and Z.db.char then
        Z.db.char.activepoi = ident
    end

    RefreshZygorPoiPins(Poi)
end

local function BuildZygorPoiMeta(mapID, x, y, pointType, searchKind, ident, completionQuestID)
    return NS.BuildRouteMeta(NS.BuildZygorPoiIdentity(mapID, x, y, {
        poiType = pointType,
        ident = ident,
        completionQuestID = completionQuestID,
        sig = type(signature) == "function" and signature(mapID, x, y) or nil,
    }), {
        searchKind = searchKind,
        manualQuestID = completionQuestID,
    })
end

local function RouteZygorPoiAsManual(Z, Poi, point)
    local mapID, x, y, title, pointType, searchKind, ident, completionQuestID = ReadZygorPoiPoint(point)
    if not mapID then
        return false, "invalid_point"
    end

    MarkZygorPoiActive(Z, Poi, ident)

    if IsSameActiveZygorPoiManual(mapID, x, y, title, pointType, ident) then
        return true, "already_current"
    end

    if type(NS.IsRoutingEnabled) == "function" and not NS.IsRoutingEnabled() then
        return false, "routing_disabled"
    end
    if type(NS.RequestManualRoute) ~= "function" then
        return false, "route_unavailable"
    end

    NS.RequestManualRoute(
        mapID,
        x,
        y,
        title,
        BuildZygorPoiMeta(mapID, x, y, pointType, searchKind, ident, completionQuestID),
        { clickContext = { source = "zygor_poi", explicit = true } }
    )
    NS.Log(
        "Zygor POI takeover route",
        tostring(pointType or "unknown"),
        tostring(ident or "-"),
        tostring(mapID),
        tostring(x),
        tostring(y)
    )
    return true, "routed"
end

local function IsCurrentZygorPoiGuideForPoint(point)
    if type(point) ~= "table" or point.ident == nil then
        return false
    end

    if type(NS.GetGuideVisibilityState) == "function"
        and NS.GetGuideVisibilityState() ~= "visible"
    then
        return false
    end

    local Z = NS.ZGV()
    local Poi = type(Z) == "table" and Z.Poi or nil
    local loaderGuide = type(Poi) == "table" and Poi.LoaderGuide or nil
    local currentGuide = type(Z) == "table" and Z.CurrentGuide or nil
    local activePoi = Z and Z.db and Z.db.char and Z.db.char.activepoi or nil
    if tostring(activePoi or "") ~= tostring(point.ident or "") then
        return false
    end

    return type(currentGuide) == "table"
        and type(loaderGuide) == "table"
        and (currentGuide == loaderGuide or currentGuide.title == loaderGuide.title)
end

local function ActivateZygorPoiGuideAdoption(point, trigger)
    if type(GetActiveManualDestination) ~= "function" or type(GetActiveManualDestination()) ~= "table" then
        return false
    end
    if not IsCurrentZygorPoiGuideForPoint(point) then
        return false
    end
    if type(NS.ActivateGuideRouteForExplicitTakeover) ~= "function" then
        return false
    end

    local activated = NS.ActivateGuideRouteForExplicitTakeover("guide_explicit_zygor_poi", {
        requireGuideChangeOrTargetMatch = false,
    })
    if activated and type(NS.Log) == "function" then
        NS.Log("Zygor POI guide adopted manual authority", tostring(point.ident or "-"), tostring(trigger or "-"))
    end
    return activated
end

local function ScheduleZygorPoiGuideAdoption(point)
    if type(NS.After) ~= "function" then
        return ActivateZygorPoiGuideAdoption(point, "immediate")
    end

    bridge.zygorPoiGuideAdoptionSerial = (tonumber(bridge.zygorPoiGuideAdoptionSerial) or 0) + 1
    local serial = bridge.zygorPoiGuideAdoptionSerial
    for index = 1, #GUIDE_POI_ADOPTION_DELAYS do
        local delay = GUIDE_POI_ADOPTION_DELAYS[index]
        NS.After(delay, function()
            if bridge.zygorPoiGuideAdoptionSerial ~= serial then
                return
            end
            if ActivateZygorPoiGuideAdoption(point, "poi_load") then
                bridge.zygorPoiGuideAdoptionSerial = serial + 1
            end
        end)
    end
    return true
end

local function ShouldTakeOverZygorPoiLoad(point, noswitch)
    if noswitch or type(point) ~= "table" then
        return false
    end

    return type(NS.GetGuideVisibilityState) == "function"
        and NS.GetGuideVisibilityState() ~= "visible"
        or false
end

local function TryInstallZygorPoiTakeoverHook()
    if bridge.zygorPoiTakeoverHooked then
        return true
    end

    local Z = NS.ZGV()
    local Poi = Z and Z.Poi
    if type(Poi) ~= "table" or type(Poi.LoadPoint) ~= "function" then
        return false
    end

    local originalLoadPoint = Poi.LoadPoint
    Poi.LoadPoint = function(self, point, noswitch, ...)
        if ShouldTakeOverZygorPoiLoad(point, noswitch) then
            if type(NS.BlockHiddenGuideAutoLoads) == "function" then
                NS.BlockHiddenGuideAutoLoads(GUIDE_LOAD_FALLBACK_DELAY_SECONDS)
            end
            RouteZygorPoiAsManual(Z, self, point)
            return
        end

        local shouldTryGuideAdoption = not noswitch
            and type(GetActiveManualDestination) == "function"
            and type(GetActiveManualDestination()) == "table"
        local result = originalLoadPoint(self, point, noswitch, ...)
        if shouldTryGuideAdoption then
            ScheduleZygorPoiGuideAdoption(point)
        end
        return result
    end

    bridge.zygorPoiTakeoverOriginalLoadPoint = originalLoadPoint
    bridge.zygorPoiTakeoverHooked = true
    NS.Log("Zygor POI takeover hook active")
    return true
end

function NS.InstallZygorPoiTakeoverHooks()
    if TryInstallZygorPoiTakeoverHook() then
        return true
    end

    bridge.zygorPoiTakeoverRetryCount = (bridge.zygorPoiTakeoverRetryCount or 0) + 1
    if bridge.zygorPoiTakeoverRetryCount > HOOK_RETRY_MAX_COUNT then
        return false
    end

    if bridge.zygorPoiTakeoverRetryScheduled then
        return false
    end

    bridge.zygorPoiTakeoverRetryScheduled = true
    NS.After(HOOK_RETRY_DELAY_SECONDS, function()
        bridge.zygorPoiTakeoverRetryScheduled = false
        NS.InstallZygorPoiTakeoverHooks()
    end)

    return false
end

function NS.HandleRemovedZygorPoiDestination(destination)
    local identity = type(destination) == "table" and type(destination.identity) == "table" and destination.identity or nil
    if type(identity) ~= "table" or identity.kind ~= "zygor_poi" then
        return
    end

    local ident = identity.ident
    if type(ident) ~= "string" or ident == "" then
        return
    end

    local Z = NS.ZGV()
    local Poi = Z and Z.Poi
    if Z and Z.db and Z.db.char and Z.db.char.activepoi == ident then
        Z.db.char.activepoi = nil
    end

    RefreshZygorPoiPins(Poi)
    NS.Log("Zygor POI takeover clear", tostring(ident))
end

function NS.ClearZygorPoiByIdentity(identity)
    if type(identity) ~= "table" or identity.kind ~= "zygor_poi" then
        return false
    end

    local ident = type(identity.ident) == "string" and identity.ident or nil
    if not ident or ident == "" then
        return false
    end

    local Z = NS.ZGV()
    local Poi = Z and Z.Poi
    if Z and Z.db and Z.db.char and Z.db.char.activepoi == ident then
        Z.db.char.activepoi = nil
    end

    RefreshZygorPoiPins(Poi)
    NS.Log("Zygor POI takeover clear", tostring(ident))
    return true
end
