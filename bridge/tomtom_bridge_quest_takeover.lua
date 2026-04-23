local NS = _G.ZygorWaypointNS
local state = NS.State

NS.Internal = NS.Internal or {}
NS.Internal.Bridge = NS.Internal.Bridge or {}

local M = NS.Internal.Bridge

state.bridgeQuestTakeover = state.bridgeQuestTakeover or {
    hooksInstalled = false,
    refreshSerial = 0,
    adoptionRetrySerial = 0,
}

local takeover = state.bridgeQuestTakeover

local GetActiveManualDestination = M.GetActiveManualDestination
local ClearActiveManualDestination = M.ClearActiveManualDestination
local GetGuideVisibilityState = M.GetGuideVisibilityState
local ReadWaypointCoords = NS.ReadWaypointCoords
local Signature = NS.Signature

local BLIZZARD_USER_WAYPOINT_STACK_START = 4
local BLIZZARD_USER_WAYPOINT_STACK_COUNT = 12
local BLIZZARD_USER_WAYPOINT_STACK_MATCHES = {
    "blizzard_sharedmapdataproviders\\waypointlocationdataprovider.lua",
}
local EXPLICIT_USER_SUPERTRACK_STACK_MATCHES = {
    "blizzard_poibutton\\poibutton.lua",
}
local QUEST_TAKEOVER_REFRESH_DELAY_SECONDS = 0.05
local QUEST_TAKEOVER_ADOPTION_RETRY_DELAY_SECONDS = 0.05
local QUEST_TAKEOVER_ADOPTION_RETRY_MAX_ATTEMPTS = 8
local QUEST_TAKEOVER_SOURCE_SUPERTRACK = "supertrack"
local QUEST_TAKEOVER_SOURCE_WATCH = "watch"

local function NormalizeQuestID(questID)
    if type(questID) == "number" and questID > 0 then
        return questID
    end
end

local function GetNormalizedDebugStack(startLevel, frameCount)
    if type(debugstack) ~= "function" then
        return nil
    end

    local ok, stack = pcall(
        debugstack,
        startLevel or BLIZZARD_USER_WAYPOINT_STACK_START,
        frameCount or BLIZZARD_USER_WAYPOINT_STACK_COUNT,
        frameCount or BLIZZARD_USER_WAYPOINT_STACK_COUNT
    )
    if not ok or type(stack) ~= "string" or stack == "" then
        return nil
    end

    return stack:gsub("/", "\\"):lower()
end

local function DoesStackMatchAnyPattern(stack, patterns)
    if type(stack) ~= "string" or type(patterns) ~= "table" then
        return false
    end

    for _, pattern in ipairs(patterns) do
        if type(pattern) == "string" and stack:find(pattern, 1, true) then
            return true
        end
    end

    return false
end

local function IsExplicitBlizzardUserWaypointCall()
    return DoesStackMatchAnyPattern(GetNormalizedDebugStack(), BLIZZARD_USER_WAYPOINT_STACK_MATCHES)
end

local function IsExplicitUserSupertrack()
    return DoesStackMatchAnyPattern(GetNormalizedDebugStack(), EXPLICIT_USER_SUPERTRACK_STACK_MATCHES)
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

local function ReadQuestCoords(entry)
    if type(entry) ~= "table" then
        return nil, nil
    end

    local x = type(entry.x) == "number" and entry.x or nil
    local y = type(entry.y) == "number" and entry.y or nil
    if x ~= nil and y ~= nil then
        return x, y
    end

    local position = entry.position
    if type(position) == "table" then
        x = type(position.x) == "number" and position.x or nil
        y = type(position.y) == "number" and position.y or nil
    end

    return x, y
end

local function ReadUiMapPointCoords(uiMapPoint)
    if type(uiMapPoint) ~= "table" then
        return nil, nil, nil
    end

    local mapID = type(uiMapPoint.uiMapID) == "number" and uiMapPoint.uiMapID or nil
    local position = uiMapPoint.position
    local x = type(position) == "table" and type(position.x) == "number" and position.x or nil
    local y = type(position) == "table" and type(position.y) == "number" and position.y or nil

    return mapID, x, y
end

local function FindQuestDestinationOnMap(mapID, questID, listProvider)
    if type(mapID) ~= "number" or mapID <= 0 or type(listProvider) ~= "function" then
        return nil
    end

    local entries = listProvider(mapID)
    if type(entries) ~= "table" then
        return nil
    end

    for _, info in ipairs(entries) do
        if type(info) == "table" and info.questID == questID then
            local x, y = ReadQuestCoords(info)
            if type(x) == "number" and type(y) == "number" then
                return mapID, x, y
            end
        end
    end

    return nil
end

local function SafeGetQuestUiMapID(questID, ignoreWaypoints)
    if type(GetQuestUiMapID) ~= "function" then
        return nil
    end

    if ignoreWaypoints == nil then
        local mapID = GetQuestUiMapID(questID)
        if type(mapID) == "number" then
            return mapID
        end
        return nil
    end

    local ok, mapID = pcall(GetQuestUiMapID, questID, ignoreWaypoints)
    if ok and type(mapID) == "number" then
        return mapID
    end

    return nil
end

local function ResolveQuestDestination(questID)
    if type(questID) ~= "number" then
        return nil
    end

    if type(C_QuestLog) == "table" then
        local mapID = SafeGetQuestUiMapID(questID, true)
        local resolvedMapID, resolvedX, resolvedY = FindQuestDestinationOnMap(mapID, questID, C_QuestLog.GetQuestsOnMap)
        if type(resolvedMapID) == "number" then
            return resolvedMapID, resolvedX, resolvedY, "quest_ui_map_ignore_waypoints"
        end

        mapID = SafeGetQuestUiMapID(questID)
        resolvedMapID, resolvedX, resolvedY = FindQuestDestinationOnMap(mapID, questID, C_QuestLog.GetQuestsOnMap)
        if type(resolvedMapID) == "number" then
            return resolvedMapID, resolvedX, resolvedY, "quest_ui_map"
        end
    end

    if type(C_TaskQuest) == "table" and type(C_TaskQuest.GetQuestZoneID) == "function" then
        local taskMapID = C_TaskQuest.GetQuestZoneID(questID)
        local resolvedMapID, resolvedX, resolvedY = FindQuestDestinationOnMap(taskMapID, questID, C_TaskQuest.GetQuestsOnMap)
        if type(resolvedMapID) == "number" then
            return resolvedMapID, resolvedX, resolvedY, "task_zone"
        end
    end

    if type(C_QuestLog) == "table" and type(C_QuestLog.GetNextWaypoint) == "function" then
        local mapID, x, y = C_QuestLog.GetNextWaypoint(questID)
        if type(mapID) == "number" and type(x) == "number" and type(y) == "number" then
            return mapID, x, y, "next_waypoint_fallback"
        end
    end

    return nil
end

local function ResolveQuestTitle(questID)
    local title = type(C_QuestLog) == "table" and type(C_QuestLog.GetTitleForQuestID) == "function"
        and C_QuestLog.GetTitleForQuestID(questID)
        or nil
    if type(title) == "string" and title ~= "" then
        return title
    end

    title = type(C_TaskQuest) == "table" and type(C_TaskQuest.GetQuestInfoByQuestID) == "function"
        and C_TaskQuest.GetQuestInfoByQuestID(questID)
        or nil
    if type(title) == "string" and title ~= "" then
        return title
    end

    return "Quest " .. tostring(questID)
end

local function ResolveMapTitle(mapID, x, y)
    local mapInfo = type(C_Map) == "table" and type(C_Map.GetMapInfo) == "function" and C_Map.GetMapInfo(mapID) or nil
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

local function GetQuestIDForQuestBackedManual(destination)
    if type(destination) ~= "table" or destination.type ~= "manual" then
        return nil
    end
    if destination.zwpBlizzardQuestSupertrack ~= true then
        return nil
    end

    return NormalizeQuestID(destination.zwpQuestID)
end

local function GetQuestTakeoverSource(destination)
    if GetQuestIDForQuestBackedManual(destination) == nil then
        return nil
    end

    local source = type(destination) == "table" and destination.zwpQuestTakeoverSource or nil
    if source == QUEST_TAKEOVER_SOURCE_WATCH then
        return QUEST_TAKEOVER_SOURCE_WATCH
    end

    return QUEST_TAKEOVER_SOURCE_SUPERTRACK
end

local function GetActiveQuestBackedManual()
    local destination = GetActiveManualDestination and GetActiveManualDestination() or nil
    local questID = GetQuestIDForQuestBackedManual(destination)
    if not questID then
        return nil, nil, nil
    end

    return destination, questID, GetQuestTakeoverSource(destination)
end

local function IsQuestStillActive(questID)
    local normalizedQuestID = NormalizeQuestID(questID)
    if not normalizedQuestID or type(C_QuestLog) ~= "table" then
        return false
    end

    if type(C_QuestLog.IsOnQuest) == "function" then
        local ok, isOnQuest = pcall(C_QuestLog.IsOnQuest, normalizedQuestID)
        if ok then
            return isOnQuest == true
        end
    end

    if type(C_QuestLog.GetLogIndexForQuestID) == "function" then
        local ok, logIndex = pcall(C_QuestLog.GetLogIndexForQuestID, normalizedQuestID)
        if ok and type(logIndex) == "number" then
            return logIndex > 0
        end
    end

    return false
end

local function IsSuperTrackedQuestAutoClearEnabled()
    return type(NS.IsSuperTrackedQuestAutoClearEnabled) == "function"
        and NS.IsSuperTrackedQuestAutoClearEnabled()
        or false
end

local function IsQuestBackedManualArrivalAutoClearEnabled(destination)
    if GetQuestIDForQuestBackedManual(destination) == nil then
        return false
    end

    return GetQuestTakeoverSource(destination) == QUEST_TAKEOVER_SOURCE_SUPERTRACK
        and IsSuperTrackedQuestAutoClearEnabled()
end

local function IsTrackedQuestAutoRouteEnabled()
    return type(NS.IsTrackedQuestAutoRouteEnabled) == "function"
        and NS.IsTrackedQuestAutoRouteEnabled()
        or false
end

local function GetCurrentSuperTrackedQuestID()
    if type(C_SuperTrack) ~= "table" or type(C_SuperTrack.GetSuperTrackedQuestID) ~= "function" then
        return nil
    end

    return NormalizeQuestID(C_SuperTrack.GetSuperTrackedQuestID())
end

local function IsQuestWatched(questID)
    if type(C_QuestLog) ~= "table" or type(C_QuestLog.IsQuestWatched) ~= "function" then
        return nil
    end

    local ok, watched = pcall(C_QuestLog.IsQuestWatched, questID)
    if ok then
        return watched == true
    end

    return nil
end

local function GetBlizzardUserWaypointSignature(destination)
    if type(destination) ~= "table" or destination.type ~= "manual" then
        return nil
    end
    if destination.zwpBlizzardUserWaypoint ~= true then
        return nil
    end

    if type(destination.zwpBlizzardUserWaypointSig) == "string" then
        return destination.zwpBlizzardUserWaypointSig
    end

    local mapID, x, y = ReadWaypointCoords(destination)
    return GetWaypointSignature(mapID, x, y)
end

local function GetActiveBlizzardUserWaypointManual()
    local destination = GetActiveManualDestination and GetActiveManualDestination() or nil
    local sig = GetBlizzardUserWaypointSignature(destination)
    if not sig then
        return nil, nil
    end

    return destination, sig
end

local function BuildQuestTakeoverMeta(questID, destMapID, destX, destY, takeoverSource, explicit)
    return {
        zwpBlizzardQuestSupertrack = true,
        zwpQuestID = questID,
        zwpQuestDestMapID = destMapID,
        zwpQuestDestX = destX,
        zwpQuestDestY = destY,
        zwpQuestTakeoverSource = takeoverSource == QUEST_TAKEOVER_SOURCE_WATCH and QUEST_TAKEOVER_SOURCE_WATCH
            or QUEST_TAKEOVER_SOURCE_SUPERTRACK,
        zwpExplicitAdoption = explicit == true or nil,
    }
end

local function BuildBlizzardUserWaypointMeta(mapID, x, y)
    return {
        zwpBlizzardUserWaypoint = true,
        zwpBlizzardUserWaypointSig = GetWaypointSignature(mapID, x, y),
        zwpBlizzardUserWaypointMapID = mapID,
        zwpBlizzardUserWaypointX = x,
        zwpBlizzardUserWaypointY = y,
    }
end

local function CancelQuestAdoptionRetry()
    takeover.adoptionRetrySerial = (takeover.adoptionRetrySerial or 0) + 1
end

local function AdoptQuestAsManual(questID, takeoverSource, explicit)
    local desiredQuestID = NormalizeQuestID(questID)
    if not desiredQuestID then
        return false, "invalid_quest"
    end
    if not (state.init and state.init.playerLoggedIn) then
        return false, "not_ready"
    end
    if type(NS.IsRoutingEnabled) ~= "function" or not NS.IsRoutingEnabled() then
        return false, "routing_disabled"
    end

    local destMapID, destX, destY, resolutionSource = ResolveQuestDestination(desiredQuestID)
    if not (type(destMapID) == "number" and type(destX) == "number" and type(destY) == "number") then
        return false, "unresolved"
    end

    local desiredSource = takeoverSource == QUEST_TAKEOVER_SOURCE_WATCH and QUEST_TAKEOVER_SOURCE_WATCH
        or QUEST_TAKEOVER_SOURCE_SUPERTRACK
    local isExplicit = explicit == true
    local title = ResolveQuestTitle(desiredQuestID)
    local destination, activeQuestID, activeSource = GetActiveQuestBackedManual()
    if activeQuestID == desiredQuestID then
        local activeMapID, activeX, activeY = ReadWaypointCoords(destination)
        local activeTitle = type(destination) == "table" and destination.title or nil
        local activeExplicit = type(destination) == "table" and destination.zwpExplicitAdoption == true or false
        if GetWaypointSignature(activeMapID, activeX, activeY) == GetWaypointSignature(destMapID, destX, destY)
            and activeTitle == title
            and activeSource == desiredSource
            and activeExplicit == isExplicit
        then
            return false, "already_current"
        end
    end

    NS.RouteViaZygor(
        destMapID,
        destX,
        destY,
        title,
        BuildQuestTakeoverMeta(desiredQuestID, destMapID, destX, destY, desiredSource, isExplicit)
    )
    NS.Log(
        "Quest takeover route",
        tostring(desiredQuestID),
        tostring(destMapID),
        tostring(destX),
        tostring(destY),
        tostring(resolutionSource),
        tostring(desiredSource)
    )
    return true, "routed"
end

local function ShouldRetryQuestAdoption(questID, takeoverSource)
    local normalizedQuestID = NormalizeQuestID(questID)
    if not normalizedQuestID then
        return false
    end
    if not (state.init and state.init.playerLoggedIn) then
        return false
    end
    if type(NS.IsRoutingEnabled) ~= "function" or not NS.IsRoutingEnabled() then
        return false
    end

    if takeoverSource == QUEST_TAKEOVER_SOURCE_WATCH then
        if not IsTrackedQuestAutoRouteEnabled() or not IsQuestStillActive(normalizedQuestID) then
            return false
        end

        local watched = IsQuestWatched(normalizedQuestID)
        if watched == false then
            return false
        end

        return true
    end

    return GetCurrentSuperTrackedQuestID() == normalizedQuestID
end

local function ScheduleQuestAdoptionRetry(questID, takeoverSource, attempt, explicit)
    local normalizedQuestID = NormalizeQuestID(questID)
    local desiredSource = takeoverSource == QUEST_TAKEOVER_SOURCE_WATCH and QUEST_TAKEOVER_SOURCE_WATCH
        or QUEST_TAKEOVER_SOURCE_SUPERTRACK
    local nextAttempt = type(attempt) == "number" and attempt or 1
    local isExplicit = explicit == true

    if nextAttempt > QUEST_TAKEOVER_ADOPTION_RETRY_MAX_ATTEMPTS then
        return false
    end
    if not ShouldRetryQuestAdoption(normalizedQuestID, desiredSource) then
        return false
    end

    takeover.adoptionRetrySerial = (takeover.adoptionRetrySerial or 0) + 1
    local retrySerial = takeover.adoptionRetrySerial

    NS.After(QUEST_TAKEOVER_ADOPTION_RETRY_DELAY_SECONDS, function()
        if takeover.adoptionRetrySerial ~= retrySerial then
            return
        end
        if not ShouldRetryQuestAdoption(normalizedQuestID, desiredSource) then
            return
        end

        local adopted, reason = AdoptQuestAsManual(normalizedQuestID, desiredSource, isExplicit)
        if adopted or reason ~= "unresolved" then
            return
        end

        ScheduleQuestAdoptionRetry(normalizedQuestID, desiredSource, nextAttempt + 1, isExplicit)
    end)

    return true
end

local function AdoptBlizzardUserWaypointAsManual(mapID, x, y)
    if type(mapID) ~= "number" or type(x) ~= "number" or type(y) ~= "number" then
        return false
    end
    if not (state.init and state.init.playerLoggedIn) then
        return false
    end
    if type(NS.IsRoutingEnabled) ~= "function" or not NS.IsRoutingEnabled() then
        return false
    end

    local title = ResolveMapTitle(mapID, x, y)
    local destination, activeSig = GetActiveBlizzardUserWaypointManual()
    local currentSig = GetWaypointSignature(mapID, x, y)
    if activeSig == currentSig then
        local activeTitle = type(destination) == "table" and destination.title or nil
        if activeTitle == title then
            return false
        end
    end

    NS.RouteViaZygor(mapID, x, y, title, BuildBlizzardUserWaypointMeta(mapID, x, y))
    NS.Log("Blizzard waypoint takeover route", tostring(mapID), tostring(x), tostring(y), tostring(currentSig))
    return true
end

local function ClearQuestBackedManual()
    local destination = GetActiveQuestBackedManual()
    if not destination then
        return false
    end

    local visibilityState = GetGuideVisibilityState and GetGuideVisibilityState() or nil
    if type(ClearActiveManualDestination) ~= "function" then
        return false
    end

    return ClearActiveManualDestination(visibilityState, "system")
end

local function ClearQuestBackedManualForReason(clearReason)
    local destination, questID = GetActiveQuestBackedManual()
    if not destination then
        return false
    end

    local visibilityState = GetGuideVisibilityState and GetGuideVisibilityState() or nil
    if type(ClearActiveManualDestination) ~= "function" then
        return false
    end

    NS.Log("Quest takeover clear", tostring(questID), tostring(clearReason or "system"))
    return ClearActiveManualDestination(visibilityState, clearReason or "system")
end

local function ClearBlizzardUserWaypointBackedManual(clearReason)
    local destination, sig = GetActiveBlizzardUserWaypointManual()
    if not destination then
        return false
    end

    local visibilityState = GetGuideVisibilityState and GetGuideVisibilityState() or nil
    if type(ClearActiveManualDestination) ~= "function" then
        return false
    end

    NS.Log("Blizzard waypoint takeover clear", tostring(sig), tostring(clearReason or "system"))
    return ClearActiveManualDestination(visibilityState, clearReason or "system")
end

local function HandleSuperTrackedQuestIDChanged(questID)
    local explicit = IsExplicitUserSupertrack()
    if not explicit and not IsTrackedQuestAutoRouteEnabled() then return false end
    local normalizedQuestID = NormalizeQuestID(questID)
    if normalizedQuestID then
        if not explicit and GetGuideVisibilityState and GetGuideVisibilityState() == "visible" then return false end
        local adopted, reason = AdoptQuestAsManual(normalizedQuestID, QUEST_TAKEOVER_SOURCE_SUPERTRACK, explicit)
        if adopted then
            CancelQuestAdoptionRetry()
            return true
        end
        if reason == "unresolved" then
            ScheduleQuestAdoptionRetry(normalizedQuestID, QUEST_TAKEOVER_SOURCE_SUPERTRACK, nil, explicit)
        end
        return false
    end

    CancelQuestAdoptionRetry()
    local _, _, activeSource = GetActiveQuestBackedManual()
    if activeSource == QUEST_TAKEOVER_SOURCE_SUPERTRACK then
        return ClearQuestBackedManual()
    end

    return false
end

local function HandleExplicitBlizzardUserWaypointSet(mapID, x, y)
    return AdoptBlizzardUserWaypointAsManual(mapID, x, y)
end

local function HandleExplicitBlizzardUserWaypointCleared()
    return ClearBlizzardUserWaypointBackedManual("explicit")
end

local function HandleQuestWatchRemoved(questID)
    local normalizedQuestID = NormalizeQuestID(questID)
    if not normalizedQuestID then
        return false
    end

    local _, activeQuestID = GetActiveQuestBackedManual()
    if activeQuestID ~= normalizedQuestID then
        return false
    end

    local visibilityState = GetGuideVisibilityState and GetGuideVisibilityState() or nil
    if type(ClearActiveManualDestination) ~= "function" then
        return false
    end

    NS.Log("Quest takeover clear", tostring(normalizedQuestID), "remove_watch")
    return ClearActiveManualDestination(visibilityState, "explicit")
end

local function HandleQuestWatchAdded(questID)
    local normalizedQuestID = NormalizeQuestID(questID)
    if not normalizedQuestID or not IsTrackedQuestAutoRouteEnabled() then
        return false
    end
    if not IsQuestStillActive(normalizedQuestID) then
        return false
    end
    if GetGuideVisibilityState and GetGuideVisibilityState() == "visible" then return false end
    local adopted, reason = AdoptQuestAsManual(normalizedQuestID, QUEST_TAKEOVER_SOURCE_WATCH)
    if adopted then
        CancelQuestAdoptionRetry()
        return true
    end
    if reason == "unresolved" then
        ScheduleQuestAdoptionRetry(normalizedQuestID, QUEST_TAKEOVER_SOURCE_WATCH)
    end
    return false
end

local function RefreshActiveQuestBackedManual(eventName, eventQuestID)
    local destination, activeQuestID, activeSource = GetActiveQuestBackedManual()
    if not activeQuestID then
        return false
    end

    local normalizedEventQuestID = NormalizeQuestID(eventQuestID)
    if normalizedEventQuestID and normalizedEventQuestID ~= activeQuestID then
        return false
    end

    if not IsQuestStillActive(activeQuestID) then
        local clearReason = eventName == "QUEST_TURNED_IN" and "quest_turned_in"
            or eventName == "QUEST_REMOVED" and "quest_removed"
            or "quest_missing"
        return ClearQuestBackedManualForReason(clearReason)
    end

    local destMapID, destX, destY = ResolveQuestDestination(activeQuestID)
    if not (type(destMapID) == "number" and type(destX) == "number" and type(destY) == "number") then
        return ClearQuestBackedManualForReason("quest_unresolved")
    end

    local isExplicit = type(destination) == "table" and destination.zwpExplicitAdoption == true
    if not isExplicit and GetGuideVisibilityState and GetGuideVisibilityState() == "visible" then
        return false
    end
    return AdoptQuestAsManual(activeQuestID, activeSource, isExplicit)
end

local function ScheduleActiveQuestBackedManualRefresh(eventName, eventQuestID)
    takeover.refreshSerial = (takeover.refreshSerial or 0) + 1
    local refreshSerial = takeover.refreshSerial
    local normalizedEventQuestID = NormalizeQuestID(eventQuestID)

    NS.After(QUEST_TAKEOVER_REFRESH_DELAY_SECONDS, function()
        if takeover.refreshSerial ~= refreshSerial then
            return
        end

        NS.SafeCall(RefreshActiveQuestBackedManual, eventName, normalizedEventQuestID)
    end)
end

local function ClearSuperTrackedQuestIfCurrent(questID)
    if type(C_SuperTrack) ~= "table"
        or type(C_SuperTrack.GetSuperTrackedQuestID) ~= "function"
        or type(C_SuperTrack.SetSuperTrackedQuestID) ~= "function"
    then
        return
    end

    if NormalizeQuestID(C_SuperTrack.GetSuperTrackedQuestID()) ~= questID then
        return
    end

    NS.After(0, function()
        if NormalizeQuestID(C_SuperTrack.GetSuperTrackedQuestID()) == questID then
            C_SuperTrack.SetSuperTrackedQuestID(0)
        end
    end)
end

function NS.GetQuestIDForQuestBackedManualDestination(destination)
    return GetQuestIDForQuestBackedManual(destination)
end

function NS.IsQuestBackedManualArrivalAutoClearEnabled(destination)
    return IsQuestBackedManualArrivalAutoClearEnabled(destination)
end

function NS.HandleRemovedBlizzardQuestDestination(destination, clearReason)
    local questID = GetQuestIDForQuestBackedManual(destination)
    if not questID then
        return false
    end

    if clearReason == "explicit" and GetQuestTakeoverSource(destination) == QUEST_TAKEOVER_SOURCE_SUPERTRACK then
        ClearSuperTrackedQuestIfCurrent(questID)
    end

    return true
end

function NS.SyncSuperTrackedQuestToManual()
    if not IsTrackedQuestAutoRouteEnabled() then return false end
    if GetGuideVisibilityState and GetGuideVisibilityState() == "visible" then return false end
    local questID = GetCurrentSuperTrackedQuestID()

    if questID then
        local adopted, reason = AdoptQuestAsManual(questID, QUEST_TAKEOVER_SOURCE_SUPERTRACK)
        if adopted then
            CancelQuestAdoptionRetry()
            return true
        end
        if reason == "unresolved" then
            ScheduleQuestAdoptionRetry(questID, QUEST_TAKEOVER_SOURCE_SUPERTRACK)
        end
        return false
    end

    CancelQuestAdoptionRetry()
    local _, _, activeSource = GetActiveQuestBackedManual()
    if activeSource == QUEST_TAKEOVER_SOURCE_SUPERTRACK then
        return ClearQuestBackedManual()
    end

    return false
end

function NS.ScheduleActiveQuestBackedManualRefresh(eventName, eventQuestID)
    return ScheduleActiveQuestBackedManualRefresh(eventName, eventQuestID)
end

function NS.InstallBlizzardQuestTakeoverHooks()
    if takeover.hooksInstalled then
        return true
    end
    if type(C_SuperTrack) ~= "table" or type(C_SuperTrack.SetSuperTrackedQuestID) ~= "function" then
        return false
    end

    hooksecurefunc(C_SuperTrack, "SetSuperTrackedQuestID", function(questID)
        NS.SafeCall(HandleSuperTrackedQuestIDChanged, questID)
    end)

    if type(C_QuestLog) == "table" then
        if type(C_QuestLog.AddQuestWatch) == "function" then
            hooksecurefunc(C_QuestLog, "AddQuestWatch", function(questID)
                NS.After(0, function()
                    NS.SafeCall(HandleQuestWatchAdded, questID)
                end)
            end)
        end

        if type(C_QuestLog.RemoveQuestWatch) == "function" then
            hooksecurefunc(C_QuestLog, "RemoveQuestWatch", function(questID)
                NS.After(0, function()
                    NS.SafeCall(HandleQuestWatchRemoved, questID)
                end)
            end)
        end
    end

    if type(C_Map) == "table" and type(C_Map.SetUserWaypoint) == "function" then
        hooksecurefunc(C_Map, "SetUserWaypoint", function(uiMapPoint)
            if not IsExplicitBlizzardUserWaypointCall() then
                return
            end

            local mapID, x, y = ReadUiMapPointCoords(uiMapPoint)
            if type(mapID) ~= "number" or type(x) ~= "number" or type(y) ~= "number" then
                mapID, x, y = NS.GetCurrentUserWaypoint()
            end
            if type(mapID) ~= "number" or type(x) ~= "number" or type(y) ~= "number" then
                return
            end

            NS.After(0, function()
                NS.SafeCall(HandleExplicitBlizzardUserWaypointSet, mapID, x, y)
            end)
        end)
    end

    if type(C_Map) == "table" and type(C_Map.ClearUserWaypoint) == "function" then
        hooksecurefunc(C_Map, "ClearUserWaypoint", function()
            if not IsExplicitBlizzardUserWaypointCall() then
                return
            end

            NS.After(0, function()
                NS.SafeCall(HandleExplicitBlizzardUserWaypointCleared)
            end)
        end)
    end

    takeover.hooksInstalled = true
    return true
end
