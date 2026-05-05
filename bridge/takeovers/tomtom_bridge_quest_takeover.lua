local NS = _G.AzerothWaypointNS
local state = NS.State

NS.Internal = NS.Internal or {}

NS.Internal.BlizzardTakeovers = NS.Internal.BlizzardTakeovers or {}
local M = NS.Internal.BlizzardTakeovers

M.BlizzardKinds = M.BlizzardKinds or {}

state.bridgeQuestTakeover = state.bridgeQuestTakeover or {
    refreshSerial = 0,
    adoptionRetrySerial = 0,
}

local quest = state.bridgeQuestTakeover

local GetActiveManualDestination = NS.GetActiveManualDestination
local ClearActiveManualDestination = NS.ClearActiveManualDestination
local GetGuideVisibilityState = NS.GetGuideVisibilityState
local ReadWaypointCoords = NS.ReadWaypointCoords
local Signature = NS.Signature

local QUEST_TAKEOVER_REFRESH_DELAY_SECONDS = 0.05
local QUEST_TAKEOVER_ADOPTION_RETRY_DELAY_SECONDS = 0.05
local QUEST_TAKEOVER_ADOPTION_RETRY_MAX_ATTEMPTS = 8
local QUEST_TAKEOVER_SOURCE_SUPERTRACK = "supertrack"
local QUEST_TAKEOVER_SOURCE_WATCH = "watch"
local QUEST_TAKEOVER_SOURCE_QUEST_OFFER = "quest_offer"
local BLIZZARD_VIGNETTE_KIND = "vignette"

-- ============================================================
-- Forward declarations
-- ============================================================

local CancelQuestAdoptionRetry
local AdoptQuestAsManual
local ScheduleQuestAdoptionRetry
local ClearQuestBackedManual
local ClearQuestBackedManualForReason
local ClearQuestOfferBackedManual
local ResolveQuestDestination

-- ============================================================
-- Normalizers
-- ============================================================

local function NormalizeQuestID(questID)
    if type(questID) == "number" and questID > 0 then
        return questID
    end
end

local function NormalizeQuestTakeoverSource(takeoverSource)
    if takeoverSource == QUEST_TAKEOVER_SOURCE_WATCH then
        return QUEST_TAKEOVER_SOURCE_WATCH
    end
    if takeoverSource == QUEST_TAKEOVER_SOURCE_QUEST_OFFER then
        return QUEST_TAKEOVER_SOURCE_QUEST_OFFER
    end
    return QUEST_TAKEOVER_SOURCE_SUPERTRACK
end

local function GetQuestOfferMapPinType()
    local mapPinTypes = type(Enum) == "table"
        and type(Enum.SuperTrackingMapPinType) == "table"
        and Enum.SuperTrackingMapPinType
        or nil
    local pinType = type(mapPinTypes) == "table" and mapPinTypes["QuestOffer"] or nil
    if type(pinType) == "number" then return pinType end
    return 1
end

local function GetWaypointSignature(mapID, x, y)
    if type(Signature) ~= "function" then return nil end
    if type(mapID) ~= "number" or type(x) ~= "number" or type(y) ~= "number" then return nil end
    return Signature(mapID, x, y)
end

-- ============================================================
-- Quest resolution
-- ============================================================

local function ReadQuestCoords(entry)
    if type(entry) ~= "table" then return nil, nil end
    local x = type(entry.x) == "number" and entry.x or nil
    local y = type(entry.y) == "number" and entry.y or nil
    if x ~= nil and y ~= nil then return x, y end
    local position = entry.position
    if type(position) == "table" then
        x = type(position.x) == "number" and position.x or nil
        y = type(position.y) == "number" and position.y or nil
    end
    return x, y
end

local function FindQuestDestinationOnMap(mapID, questID, listProvider)
    if type(mapID) ~= "number" or mapID <= 0 or type(listProvider) ~= "function" then
        return nil
    end
    local entries = listProvider(mapID)
    if type(entries) ~= "table" then return nil end
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

local function ResolveQuestLineOfferTitle(info)
    if type(info) ~= "table" then return nil end
    local title = type(info.questName) == "string" and info.questName ~= "" and info.questName or nil
    if title then return title end
    title = type(info.questLineName) == "string" and info.questLineName ~= "" and info.questLineName or nil
    if title then return title end
    return type(info.name) == "string" and info.name ~= "" and info.name or nil
end

local function ReadQuestLineOfferDestination(mapID, questID, info)
    if type(mapID) ~= "number" or mapID <= 0 or type(info) ~= "table" or info.questID ~= questID then
        return nil
    end
    local x, y = ReadQuestCoords(info)
    if type(x) == "number" and type(y) == "number" then
        return mapID, x, y, ResolveQuestLineOfferTitle(info)
    end
end

local function FindQuestLineOfferDestinationOnMap(mapID, questID)
    if type(mapID) ~= "number" or mapID <= 0 or type(C_QuestLine) ~= "table" then
        return nil
    end

    if type(C_QuestLine.GetQuestLineInfo) == "function" then
        local ok, info = pcall(C_QuestLine.GetQuestLineInfo, questID, mapID)
        if ok then
            local rMapID, rX, rY, title = ReadQuestLineOfferDestination(mapID, questID, info)
            if type(rMapID) == "number" then return rMapID, rX, rY, title end
        end
    end

    if type(C_QuestLine.GetAvailableQuestLines) == "function" then
        local ok, questLines = pcall(C_QuestLine.GetAvailableQuestLines, mapID)
        if ok and type(questLines) == "table" then
            for _, info in ipairs(questLines) do
                local rMapID, rX, rY, title = ReadQuestLineOfferDestination(mapID, questID, info)
                if type(rMapID) == "number" then return rMapID, rX, rY, title end
            end
        end
    end

    if type(C_QuestLine.GetForceVisibleQuests) == "function" and type(C_QuestLine.GetQuestLineInfo) == "function" then
        local ok, questIDs = pcall(C_QuestLine.GetForceVisibleQuests, mapID)
        if ok and type(questIDs) == "table" then
            for _, forceVisibleQuestID in ipairs(questIDs) do
                if forceVisibleQuestID == questID then
                    local infoOK, info = pcall(C_QuestLine.GetQuestLineInfo, questID, mapID)
                    if infoOK then
                        local rMapID, rX, rY, title = ReadQuestLineOfferDestination(mapID, questID, info)
                        if type(rMapID) == "number" then return rMapID, rX, rY, title end
                    end
                end
            end
        end
    end
end

local function SafeGetQuestUiMapID(questID, ignoreWaypoints)
    if type(GetQuestUiMapID) ~= "function" then return nil end
    if ignoreWaypoints == nil then
        local mapID = GetQuestUiMapID(questID)
        if type(mapID) == "number" then return mapID end
        return nil
    end
    local ok, mapID = pcall(GetQuestUiMapID, questID, ignoreWaypoints)
    if ok and type(mapID) == "number" then return mapID end
    return nil
end

ResolveQuestDestination = function(questID, preferredMapID)
    if type(questID) ~= "number" then return nil end

    if type(preferredMapID) == "number" and preferredMapID > 0 then
        local rMapID, rX, rY, title = FindQuestLineOfferDestinationOnMap(preferredMapID, questID)
        if type(rMapID) == "number" then
            return rMapID, rX, rY, "preferred_quest_offer", title
        end

        if type(C_QuestLog) == "table" then
            rMapID, rX, rY = FindQuestDestinationOnMap(preferredMapID, questID, C_QuestLog.GetQuestsOnMap)
            if type(rMapID) == "number" then return rMapID, rX, rY, "preferred_quest_map" end
        end
        if type(C_TaskQuest) == "table" then
            rMapID, rX, rY = FindQuestDestinationOnMap(preferredMapID, questID, C_TaskQuest.GetQuestsOnMap)
            if type(rMapID) == "number" then return rMapID, rX, rY, "preferred_task_map" end
        end
    end

    if type(C_QuestLog) == "table" then
        local mapID = SafeGetQuestUiMapID(questID, true)
        local rMapID, rX, rY = FindQuestDestinationOnMap(mapID, questID, C_QuestLog.GetQuestsOnMap)
        if type(rMapID) == "number" then return rMapID, rX, rY, "quest_ui_map_ignore_waypoints" end

        mapID = SafeGetQuestUiMapID(questID)
        rMapID, rX, rY = FindQuestDestinationOnMap(mapID, questID, C_QuestLog.GetQuestsOnMap)
        if type(rMapID) == "number" then return rMapID, rX, rY, "quest_ui_map" end
    end

    if type(C_TaskQuest) == "table" and type(C_TaskQuest.GetQuestZoneID) == "function" then
        local taskMapID = C_TaskQuest.GetQuestZoneID(questID)
        local rMapID, rX, rY = FindQuestDestinationOnMap(taskMapID, questID, C_TaskQuest.GetQuestsOnMap)
        if type(rMapID) == "number" then return rMapID, rX, rY, "task_zone" end
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
    local sharedTitle = type(NS.ResolveQuestTitle) == "function" and NS.ResolveQuestTitle(questID) or nil
    if type(sharedTitle) == "string" and sharedTitle ~= "" then return sharedTitle end

    local title = type(C_QuestLog) == "table" and type(C_QuestLog.GetTitleForQuestID) == "function"
        and C_QuestLog.GetTitleForQuestID(questID)
        or nil
    if type(title) == "string" and title ~= "" then return title end
    title = type(C_TaskQuest) == "table" and type(C_TaskQuest.GetQuestInfoByQuestID) == "function"
        and C_TaskQuest.GetQuestInfoByQuestID(questID)
        or nil
    if type(title) == "string" and title ~= "" then return title end
    return "Quest " .. tostring(questID)
end

local function ResolveQuestTakeoverTitle(questID, fallbackTitle)
    if type(NS.ResolveQuestActionTitle) == "function" then
        local title = NS.ResolveQuestActionTitle(questID, fallbackTitle)
        if type(title) == "string" and title ~= "" then
            return title
        end
    end
    return fallbackTitle or ResolveQuestTitle(questID)
end

-- ============================================================
-- Quest destination identification
-- ============================================================

local function GetQuestIDForQuestBackedManual(destination)
    if type(destination) ~= "table" or destination.type ~= "manual" then return nil end
    local identity = type(destination.identity) == "table" and destination.identity or nil
    if type(identity) == "table" and identity.kind == "quest" then
        return NormalizeQuestID(identity.questID or destination.manualQuestID)
    end
    local manualQuestID = NormalizeQuestID(destination.manualQuestID)
    if manualQuestID then
        return manualQuestID
    end
end

local function GetQuestTakeoverSource(destination)
    if GetQuestIDForQuestBackedManual(destination) == nil then return nil end
    local identity = type(destination) == "table" and type(destination.identity) == "table" and destination.identity or nil
    local source = type(identity) == "table" and identity.questSource or nil
    return NormalizeQuestTakeoverSource(source)
end

local function GetQuestBackedManualSourceAddon(destination)
    if type(destination) ~= "table" then return nil end
    local sourceAddon = type(destination.sourceAddon) == "string" and destination.sourceAddon or nil
    if sourceAddon and sourceAddon ~= "" then return sourceAddon end
    local meta = type(destination.meta) == "table" and destination.meta or nil
    sourceAddon = type(meta) == "table" and type(meta.sourceAddon) == "string" and meta.sourceAddon or nil
    if sourceAddon and sourceAddon ~= "" then return sourceAddon end
end

local function GetQuestBackedManualPreferredMapID(destination)
    if type(destination) ~= "table" then return nil end
    local identity = type(destination.identity) == "table" and destination.identity or nil
    if type(identity) == "table" and type(identity.mapID) == "number" and identity.mapID > 0 then
        return identity.mapID
    end
    if type(destination.mapID) == "number" and destination.mapID > 0 then
        return destination.mapID
    end
end

local function GetActiveQuestBackedManual()
    local destination = GetActiveManualDestination and GetActiveManualDestination() or nil
    local questID = GetQuestIDForQuestBackedManual(destination)
    if not questID then return nil, nil, nil end
    return destination, questID, GetQuestTakeoverSource(destination)
end

-- ============================================================
-- State checks
-- ============================================================

local function IsCurrentGuideStepQuest(questID)
    local normalizedQuestID = NormalizeQuestID(questID)
    if not normalizedQuestID then return false end
    local Z = NS.ZGV()
    local step = type(Z) == "table" and Z.CurrentStep or nil
    if type(step) ~= "table" or type(step.goals) ~= "table" then return false end
    for _, goal in ipairs(step.goals) do
        if type(goal) == "table" then
            local gqid = tonumber(goal.questid or 0) or nil
            if not gqid then
                local q = goal.quest
                if type(q) == "table" then
                    gqid = tonumber(q.id or q.questid or 0) or nil
                end
            end
            if gqid and gqid > 0 and gqid == normalizedQuestID then return true end
        end
    end
    return false
end

local function IsQuestStillActive(questID)
    local normalizedQuestID = NormalizeQuestID(questID)
    if not normalizedQuestID or type(C_QuestLog) ~= "table" then return false end
    if type(C_QuestLog.IsOnQuest) == "function" then
        local ok, isOnQuest = pcall(C_QuestLog.IsOnQuest, normalizedQuestID)
        if ok then return isOnQuest == true end
    end
    if type(C_QuestLog.GetLogIndexForQuestID) == "function" then
        local ok, logIndex = pcall(C_QuestLog.GetLogIndexForQuestID, normalizedQuestID)
        if ok and type(logIndex) == "number" then return logIndex > 0 end
    end
    return false
end

local function IsSuperTrackedQuestAutoClearEnabled()
    return type(NS.IsSuperTrackedQuestAutoClearEnabled) == "function"
        and NS.IsSuperTrackedQuestAutoClearEnabled()
        or false
end

local function IsQuestBackedManualArrivalAutoClearEnabled(destination)
    if GetQuestIDForQuestBackedManual(destination) == nil then return false end
    local source = GetQuestTakeoverSource(destination)
    return (source == QUEST_TAKEOVER_SOURCE_SUPERTRACK or source == QUEST_TAKEOVER_SOURCE_QUEST_OFFER)
        and IsSuperTrackedQuestAutoClearEnabled()
end

local function IsTrackedQuestAutoRouteEnabled()
    return type(NS.IsTrackedQuestAutoRouteEnabled) == "function"
        and NS.IsTrackedQuestAutoRouteEnabled()
        or false
end

local function IsUntrackedQuestAutoClearEnabled()
    if type(NS.IsUntrackedQuestAutoClearEnabled) ~= "function" then
        return true
    end
    return NS.IsUntrackedQuestAutoClearEnabled() == true
end

-- ============================================================
-- Supertrack getters
-- ============================================================

local function GetCurrentSuperTrackedQuestID()
    if type(C_SuperTrack) ~= "table" or type(C_SuperTrack.GetSuperTrackedQuestID) ~= "function" then
        return nil
    end
    return NormalizeQuestID(C_SuperTrack.GetSuperTrackedQuestID())
end

local function GetCurrentSuperTrackedMapPinID(expectedPinType)
    if type(C_SuperTrack) ~= "table" or type(C_SuperTrack.GetSuperTrackedMapPin) ~= "function" then
        return nil
    end
    local pinType, pinID = C_SuperTrack.GetSuperTrackedMapPin()
    if pinType == expectedPinType and type(pinID) == "number" and pinID > 0 then
        return pinID
    end
end

local function GetCurrentSuperTrackedQuestOfferID()
    return NormalizeQuestID(GetCurrentSuperTrackedMapPinID(GetQuestOfferMapPinType()))
end

local function IsQuestWatched(questID)
    if type(C_QuestLog) ~= "table" or type(C_QuestLog.IsQuestWatched) ~= "function" then
        return nil
    end
    local ok, watched = pcall(C_QuestLog.IsQuestWatched, questID)
    if ok then return watched == true end
    return nil
end

-- ============================================================
-- Metadata builder
-- ============================================================

local function BuildQuestTakeoverMeta(questID, destMapID, destX, destY, takeoverSource, sourceAddon)
    local normalizedSource = NormalizeQuestTakeoverSource(takeoverSource)
    return NS.BuildRouteMeta(NS.BuildQuestIdentity(questID, destMapID, destX, destY, {
        questSource = normalizedSource,
        sig = type(Signature) == "function" and Signature(destMapID, destX, destY) or nil,
    }), {
        manualQuestID = questID,
        sourceAddon = sourceAddon,
    })
end

-- ============================================================
-- Retry and adoption
-- ============================================================

CancelQuestAdoptionRetry = function()
    quest.adoptionRetrySerial = (quest.adoptionRetrySerial or 0) + 1
end

AdoptQuestAsManual = function(questID, takeoverSource, explicit, preferredMapID, sourceAddon)
    local desiredQuestID = NormalizeQuestID(questID)
    if not desiredQuestID then return false, "invalid_quest" end
    if not (state.init and state.init.playerLoggedIn) then return false, "not_ready" end
    if type(NS.IsRoutingEnabled) ~= "function" or not NS.IsRoutingEnabled() then
        return false, "routing_disabled"
    end

    local destMapID, destX, destY, resolutionSource, resolvedTitle = ResolveQuestDestination(desiredQuestID, preferredMapID)
    if not (type(destMapID) == "number" and type(destX) == "number" and type(destY) == "number") then
        return false, "unresolved"
    end

    local desiredSource = NormalizeQuestTakeoverSource(takeoverSource)
    local isExplicit = explicit == true
    local baseTitle = type(resolvedTitle) == "string" and resolvedTitle ~= "" and resolvedTitle
        or ResolveQuestTitle(desiredQuestID)
    local title = ResolveQuestTakeoverTitle(desiredQuestID, baseTitle)
    local destination, activeQuestID, activeSource = GetActiveQuestBackedManual()
    if activeQuestID == desiredQuestID then
        local activeMapID, activeX, activeY = ReadWaypointCoords(destination)
        local activeTitle = type(destination) == "table" and destination.title or nil
        if GetWaypointSignature(activeMapID, activeX, activeY) == GetWaypointSignature(destMapID, destX, destY)
            and activeTitle == title
            and activeSource == desiredSource
        then
            return false, "already_current"
        end
    end

    NS.RequestManualRoute(
        destMapID, destX, destY, title,
        BuildQuestTakeoverMeta(desiredQuestID, destMapID, destX, destY, desiredSource, sourceAddon),
        isExplicit and { clickContext = { source = desiredSource, explicit = true } } or nil
    )
    NS.Log(
        "Quest takeover route",
        tostring(desiredQuestID), tostring(destMapID), tostring(destX), tostring(destY),
        tostring(resolutionSource), tostring(desiredSource)
    )
    return true, "routed"
end

local function ShouldRetryQuestAdoption(questID, takeoverSource)
    local normalizedQuestID = NormalizeQuestID(questID)
    if not normalizedQuestID then return false end
    if not (state.init and state.init.playerLoggedIn) then return false end
    if type(NS.IsRoutingEnabled) ~= "function" or not NS.IsRoutingEnabled() then return false end

    local desiredSource = NormalizeQuestTakeoverSource(takeoverSource)
    if desiredSource == QUEST_TAKEOVER_SOURCE_WATCH then
        if not IsTrackedQuestAutoRouteEnabled() or not IsQuestStillActive(normalizedQuestID) then
            return false
        end
        local watched = IsQuestWatched(normalizedQuestID)
        if watched == false then return false end
        return true
    end
    if desiredSource == QUEST_TAKEOVER_SOURCE_QUEST_OFFER then
        return GetCurrentSuperTrackedQuestOfferID() == normalizedQuestID
    end
    return GetCurrentSuperTrackedQuestID() == normalizedQuestID
end

ScheduleQuestAdoptionRetry = function(questID, takeoverSource, attempt, explicit, preferredMapID)
    local normalizedQuestID = NormalizeQuestID(questID)
    local desiredSource = NormalizeQuestTakeoverSource(takeoverSource)
    local nextAttempt = type(attempt) == "number" and attempt or 1
    local isExplicit = explicit == true

    if nextAttempt > QUEST_TAKEOVER_ADOPTION_RETRY_MAX_ATTEMPTS then return false end
    if not ShouldRetryQuestAdoption(normalizedQuestID, desiredSource) then return false end

    quest.adoptionRetrySerial = (quest.adoptionRetrySerial or 0) + 1
    local retrySerial = quest.adoptionRetrySerial

    NS.After(QUEST_TAKEOVER_ADOPTION_RETRY_DELAY_SECONDS, function()
        if quest.adoptionRetrySerial ~= retrySerial then return end
        if not ShouldRetryQuestAdoption(normalizedQuestID, desiredSource) then return end

        local adopted, reason = AdoptQuestAsManual(normalizedQuestID, desiredSource, isExplicit, preferredMapID)
        if adopted or reason ~= "unresolved" then return end

        ScheduleQuestAdoptionRetry(normalizedQuestID, desiredSource, nextAttempt + 1, isExplicit, preferredMapID)
    end)

    return true
end

-- ============================================================
-- Clear helpers
-- ============================================================

ClearQuestBackedManual = function()
    local destination = GetActiveQuestBackedManual()
    if not destination then return false end
    local visibilityState = GetGuideVisibilityState and GetGuideVisibilityState() or nil
    if type(ClearActiveManualDestination) ~= "function" then return false end
    return ClearActiveManualDestination(visibilityState, "system")
end

ClearQuestBackedManualForReason = function(clearReason)
    local destination, questID = GetActiveQuestBackedManual()
    if not destination then return false end
    local visibilityState = GetGuideVisibilityState and GetGuideVisibilityState() or nil
    if type(ClearActiveManualDestination) ~= "function" then return false end
    NS.Log("Quest takeover clear", tostring(questID), tostring(clearReason or "system"))
    return ClearActiveManualDestination(visibilityState, clearReason or "system")
end

ClearQuestOfferBackedManual = function(clearReason)
    local destination, questID, source = GetActiveQuestBackedManual()
    if not destination or source ~= QUEST_TAKEOVER_SOURCE_QUEST_OFFER then return false end
    local visibilityState = GetGuideVisibilityState and GetGuideVisibilityState() or nil
    if type(ClearActiveManualDestination) ~= "function" then return false end
    NS.Log("QuestOffer takeover clear", tostring(questID), tostring(clearReason or "system"))
    return ClearActiveManualDestination(visibilityState, clearReason or "system")
end

local function ClearSuperTrackedQuestIfCurrent(questID)
    if type(C_SuperTrack) ~= "table"
        or type(C_SuperTrack.GetSuperTrackedQuestID) ~= "function"
        or type(C_SuperTrack.SetSuperTrackedQuestID) ~= "function"
    then
        return
    end
    if NormalizeQuestID(C_SuperTrack.GetSuperTrackedQuestID()) ~= questID then return end
    NS.After(0, function()
        if NormalizeQuestID(C_SuperTrack.GetSuperTrackedQuestID()) == questID then
            if type(NS.WithInternalSuperTrackMutation) == "function" then
                NS.WithInternalSuperTrackMutation(C_SuperTrack.SetSuperTrackedQuestID, 0)
            else
                C_SuperTrack.SetSuperTrackedQuestID(0)
            end
        end
    end)
end

local function ClearSuperTrackedQuestOfferIfCurrent(questID)
    local normalizedQuestID = NormalizeQuestID(questID)
    if not normalizedQuestID
        or type(C_SuperTrack) ~= "table"
        or type(C_SuperTrack.GetSuperTrackedMapPin) ~= "function"
        or type(C_SuperTrack.ClearSuperTrackedMapPin) ~= "function"
    then
        return
    end
    NS.After(0, function()
        if GetCurrentSuperTrackedQuestOfferID() == normalizedQuestID then
            if type(NS.WithInternalSuperTrackMutation) == "function" then
                NS.WithInternalSuperTrackMutation(C_SuperTrack.ClearSuperTrackedMapPin)
            else
                C_SuperTrack.ClearSuperTrackedMapPin()
            end
        end
    end)
end

-- ============================================================
-- Handlers
-- ============================================================

local function HandleSuperTrackedQuestIDChanged(questID)
    local explicit = NS.IsExplicitUserSupertrack()
    if not explicit then NS.ClearPendingGuideTakeover() end
    if not explicit and not IsTrackedQuestAutoRouteEnabled() then return false end
    local normalizedQuestID = NormalizeQuestID(questID)
    if normalizedQuestID then
        local worldQuestTabContext = explicit
            and type(NS.GetWorldQuestTabQuestContext) == "function"
            and NS.GetWorldQuestTabQuestContext(normalizedQuestID)
            or nil
        local addonContext = worldQuestTabContext
            or (explicit
                and type(NS.GetGenericAddonBlizzardTakeoverContext) == "function"
                and NS.GetGenericAddonBlizzardTakeoverContext("supertrack"))
            or nil
        if explicit then
            return NS.BeginPendingGuideTakeover({
                kind = "quest",
                questID = normalizedQuestID,
                preferredMapID = type(addonContext) == "table" and addonContext.mapID or nil,
                sourceAddon = type(addonContext) == "table" and addonContext.sourceAddon or nil,
            })
        end
        if GetGuideVisibilityState and GetGuideVisibilityState() == "visible"
            and IsCurrentGuideStepQuest(normalizedQuestID)
        then
            return false
        end
        local adopted, reason = AdoptQuestAsManual(
            normalizedQuestID,
            QUEST_TAKEOVER_SOURCE_SUPERTRACK,
            explicit,
            type(addonContext) == "table" and addonContext.mapID or nil,
            type(addonContext) == "table" and addonContext.sourceAddon or nil
        )
        if adopted then CancelQuestAdoptionRetry(); return true end
        if reason == "unresolved" then
            ScheduleQuestAdoptionRetry(normalizedQuestID, QUEST_TAKEOVER_SOURCE_SUPERTRACK, nil, explicit)
        end
        return false
    end

    NS.ClearPendingGuideTakeover()
    CancelQuestAdoptionRetry()
    local destination, _, activeSource = GetActiveQuestBackedManual()
    if activeSource == QUEST_TAKEOVER_SOURCE_SUPERTRACK
        and not GetQuestBackedManualSourceAddon(destination)
    then
        return ClearQuestBackedManual()
    end
    return false
end

local function HandleQuestOfferMapPinChanged(pinID, preferredMapID, explicit)
    local questID = NormalizeQuestID(pinID)
    if not questID then
        NS.ClearPendingGuideTakeover()
        CancelQuestAdoptionRetry()
        return false
    end
    if not explicit then NS.ClearPendingGuideTakeover() end
    if not explicit and not IsTrackedQuestAutoRouteEnabled() then return false end
    if explicit then
        return NS.BeginPendingGuideTakeover({
            kind = "quest_offer",
            questID = questID,
            preferredMapID = preferredMapID,
        })
    end
    if GetGuideVisibilityState and GetGuideVisibilityState() == "visible" then
        return false
    end
    local adopted, reason = AdoptQuestAsManual(questID, QUEST_TAKEOVER_SOURCE_QUEST_OFFER, explicit, preferredMapID)
    if adopted then CancelQuestAdoptionRetry(); return true end
    if reason == "unresolved" then
        ScheduleQuestAdoptionRetry(questID, QUEST_TAKEOVER_SOURCE_QUEST_OFFER, nil, explicit, preferredMapID)
    end
    return false
end

local function HandleQuestWatchAdded(questID)
    local normalizedQuestID = NormalizeQuestID(questID)
    if not normalizedQuestID or not IsTrackedQuestAutoRouteEnabled() then return false end
    if not IsQuestStillActive(normalizedQuestID) then return false end
    if GetGuideVisibilityState and GetGuideVisibilityState() == "visible"
        and IsCurrentGuideStepQuest(normalizedQuestID)
    then
        return false
    end
    local adopted, reason = AdoptQuestAsManual(normalizedQuestID, QUEST_TAKEOVER_SOURCE_WATCH)
    if adopted then CancelQuestAdoptionRetry(); return true end
    if reason == "unresolved" then
        ScheduleQuestAdoptionRetry(normalizedQuestID, QUEST_TAKEOVER_SOURCE_WATCH)
    end
    return false
end

local function HandleQuestWatchRemoved(questID)
    local normalizedQuestID = NormalizeQuestID(questID)
    if not normalizedQuestID then return false end
    CancelQuestAdoptionRetry()
    if not IsUntrackedQuestAutoClearEnabled() then return false end
    if GetGuideVisibilityState and GetGuideVisibilityState() == "visible"
        and IsCurrentGuideStepQuest(normalizedQuestID)
    then
        return false
    end

    local activeDestination, activeQuestID = GetActiveQuestBackedManual()
    local skipQueueID = activeQuestID == normalizedQuestID
        and type(activeDestination) == "table"
        and activeDestination.queueID
        or nil
    local skipQueueItemIndex = activeQuestID == normalizedQuestID
        and type(activeDestination) == "table"
        and activeDestination.queueItemIndex
        or nil
    local removedQueued = type(NS.RemoveQuestBackedManualQueueItems) == "function"
        and NS.RemoveQuestBackedManualQueueItems(normalizedQuestID, {
            skipQueueID = skipQueueID,
            skipQueueItemIndex = skipQueueItemIndex,
        })
        or false

    if activeQuestID ~= normalizedQuestID then
        return removedQueued
    end

    local visibilityState = GetGuideVisibilityState and GetGuideVisibilityState() or nil
    if type(ClearActiveManualDestination) ~= "function" then return false end
    NS.Log("Quest takeover clear", tostring(normalizedQuestID), "remove_watch")
    return ClearActiveManualDestination(visibilityState, "explicit") or removedQueued
end

local function RefreshActiveQuestBackedManual(eventName, eventQuestID)
    local destination, activeQuestID, activeSource = GetActiveQuestBackedManual()
    if not activeQuestID then return false end

    local normalizedEventQuestID = NormalizeQuestID(eventQuestID)
    if normalizedEventQuestID and normalizedEventQuestID ~= activeQuestID then return false end

    local preferredMapID = GetQuestBackedManualPreferredMapID(destination)
    local sourceAddon = GetQuestBackedManualSourceAddon(destination)
    local isExternalQuestPin = sourceAddon ~= nil
    local isActiveQuest = IsQuestStillActive(activeQuestID)

    if activeSource ~= QUEST_TAKEOVER_SOURCE_QUEST_OFFER and eventName == "QUEST_TURNED_IN" then
        return ClearQuestBackedManualForReason("quest_turned_in")
    end

    if activeSource ~= QUEST_TAKEOVER_SOURCE_QUEST_OFFER
        and eventName == "QUEST_REMOVED"
        and not isExternalQuestPin
    then
        return ClearQuestBackedManualForReason("quest_removed")
    end

    if activeSource == QUEST_TAKEOVER_SOURCE_WATCH and not isActiveQuest then
        return ClearQuestBackedManualForReason("quest_missing")
    end

    if activeSource ~= QUEST_TAKEOVER_SOURCE_QUEST_OFFER
        and not isExternalQuestPin
        and not isActiveQuest
    then
        return ClearQuestBackedManualForReason("quest_missing")
    end

    local destMapID, destX, destY = ResolveQuestDestination(activeQuestID, preferredMapID)
    if not (type(destMapID) == "number" and type(destX) == "number" and type(destY) == "number") then
        if activeSource ~= QUEST_TAKEOVER_SOURCE_QUEST_OFFER then
            if eventName == "QUEST_REMOVED" then
                return ClearQuestBackedManualForReason("quest_removed")
            end
            if not isExternalQuestPin then
                return ClearQuestBackedManualForReason("quest_unresolved")
            end
        end
        return false
    end

    if GetGuideVisibilityState and GetGuideVisibilityState() == "visible"
        and IsCurrentGuideStepQuest(activeQuestID)
    then
        return false
    end
    return AdoptQuestAsManual(activeQuestID, activeSource, false, preferredMapID, sourceAddon)
end

local function ScheduleActiveQuestBackedManualRefresh(eventName, eventQuestID)
    quest.refreshSerial = (quest.refreshSerial or 0) + 1
    local refreshSerial = quest.refreshSerial
    local normalizedEventQuestID = NormalizeQuestID(eventQuestID)

    NS.After(QUEST_TAKEOVER_REFRESH_DELAY_SECONDS, function()
        if quest.refreshSerial ~= refreshSerial then return end
        NS.SafeCall(RefreshActiveQuestBackedManual, eventName, normalizedEventQuestID)
    end)
end

-- ============================================================
-- NS exports
-- ============================================================

function NS.IsCurrentGuideStepQuest(questID)
    return IsCurrentGuideStepQuest(questID)
end

function NS.GetQuestIDForQuestBackedManualDestination(destination)
    return GetQuestIDForQuestBackedManual(destination)
end

function NS.IsQuestBackedManualArrivalAutoClearEnabled(destination)
    return IsQuestBackedManualArrivalAutoClearEnabled(destination)
end

function NS.HandleRemovedBlizzardQuestDestination(destination, clearReason)
    local questID = GetQuestIDForQuestBackedManual(destination)
    if not questID then return false end
    if clearReason == "explicit" then
        local source = GetQuestTakeoverSource(destination)
        if source == QUEST_TAKEOVER_SOURCE_SUPERTRACK then
            ClearSuperTrackedQuestIfCurrent(questID)
        elseif source == QUEST_TAKEOVER_SOURCE_QUEST_OFFER then
            ClearSuperTrackedQuestOfferIfCurrent(questID)
        end
    end
    return true
end

function NS.SyncSuperTrackedQuestToManual()
    if not IsTrackedQuestAutoRouteEnabled() then return false end
    local questID = GetCurrentSuperTrackedQuestID()
    if GetGuideVisibilityState and GetGuideVisibilityState() == "visible" then
        if not questID or IsCurrentGuideStepQuest(questID) then return false end
    end

    if questID then
        local adopted, reason = AdoptQuestAsManual(questID, QUEST_TAKEOVER_SOURCE_SUPERTRACK)
        if adopted then CancelQuestAdoptionRetry(); return true end
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

function NS.HandleSuperTrackedQuestIDChanged(questID)
    return HandleSuperTrackedQuestIDChanged(questID)
end

function NS.HandleQuestWatchAdded(questID)
    return HandleQuestWatchAdded(questID)
end

function NS.HandleQuestWatchRemoved(questID)
    return HandleQuestWatchRemoved(questID)
end

function NS.GetManualDestinationPersistenceIdentity(destination)
    if type(destination) ~= "table" or destination.type ~= "manual" then return nil end

    local identity = type(destination.identity) == "table" and destination.identity or nil
    if type(NS.ValidateRouteIdentity) == "function" and not NS.ValidateRouteIdentity(identity) then
        return nil
    end
    if type(identity) ~= "table" then return nil end

    if identity.kind == "quest" then
        local questID = NormalizeQuestID(identity.questID or destination.manualQuestID)
        if not questID then return nil end
        local source = NormalizeQuestTakeoverSource(identity.questSource)
        return {
            kind = source == QUEST_TAKEOVER_SOURCE_QUEST_OFFER and "quest_offer" or "quest",
            questID = questID,
            questSource = source,
            questMapID = identity.mapID,
            questX = identity.x,
            questY = identity.y,
            mapPinKind = source == QUEST_TAKEOVER_SOURCE_QUEST_OFFER and "quest_offer" or nil,
            mapPinType = source == QUEST_TAKEOVER_SOURCE_QUEST_OFFER and GetQuestOfferMapPinType() or nil,
            mapPinID = source == QUEST_TAKEOVER_SOURCE_QUEST_OFFER and questID or nil,
        }
    end

    if identity.kind == "map_pin" then
        local mapPinInfo = type(destination.mapPinInfo) == "table" and destination.mapPinInfo or nil
        local kind = mapPinInfo and mapPinInfo.kind or identity.mapPinKind
        local atlas = mapPinInfo and mapPinInfo.atlas or identity.atlas
        return {
            kind = kind,
            mapPinKind = kind,
            mapPinType = mapPinInfo and mapPinInfo.mapPinType or identity.mapPinType,
            mapPinID = mapPinInfo and mapPinInfo.mapPinID or identity.mapPinID,
            icon = type(atlas) == "string" and {
                kind = "atlas",
                value = atlas,
                key = kind,
            } or nil,
        }
    end

    if identity.kind == "vignette" then
        local mapPinInfo = type(destination.mapPinInfo) == "table" and destination.mapPinInfo or nil
        local atlas = mapPinInfo and mapPinInfo.atlas or nil
        return {
            kind = BLIZZARD_VIGNETTE_KIND,
            vignetteGUID = identity.guid,
            vignetteID = identity.vignetteID,
            vignetteType = identity.vignetteType,
            searchKind = destination.searchKind,
            icon = type(atlas) == "string" and {
                kind = "atlas",
                value = atlas,
                key = BLIZZARD_VIGNETTE_KIND,
            } or nil,
        }
    end
end

-- ============================================================
-- BlizzardKinds registration
-- ============================================================

M.BlizzardKinds["quest"] = {
    onChanged = nil,  -- adopted via SetSuperTrackedQuestID hook NS.HandleSuperTrackedQuestIDChanged
    resolvePending = function(pending)
        local mapID, x, y = ResolveQuestDestination(pending.questID, pending.preferredMapID)
        return mapID, x, y, pending.questID
    end,
    commitPending = function(pending)
        local adopted, reason = AdoptQuestAsManual(
            pending.questID,
            QUEST_TAKEOVER_SOURCE_SUPERTRACK,
            true,
            pending.preferredMapID,
            pending.sourceAddon
        )
        if adopted then CancelQuestAdoptionRetry(); return true end
        if reason == "unresolved" then
            ScheduleQuestAdoptionRetry(
                pending.questID,
                QUEST_TAKEOVER_SOURCE_SUPERTRACK,
                nil,
                true,
                pending.preferredMapID
            )
        end
        return false
    end,
    clearOnMapPinCleared = function()
        CancelQuestAdoptionRetry()
        return false
    end,
    startupSync = NS.SyncSuperTrackedQuestToManual,
}

M.BlizzardKinds["quest_offer"] = {
    onChanged = HandleQuestOfferMapPinChanged,
    resolvePending = function(pending)
        local mapID, x, y = ResolveQuestDestination(pending.questID, pending.preferredMapID)
        return mapID, x, y, pending.questID
    end,
    commitPending = function(pending)
        local adopted, reason = AdoptQuestAsManual(
            pending.questID, QUEST_TAKEOVER_SOURCE_QUEST_OFFER, true, pending.preferredMapID, pending.sourceAddon
        )
        if adopted then CancelQuestAdoptionRetry(); return true end
        if reason == "unresolved" then
            ScheduleQuestAdoptionRetry(
                pending.questID, QUEST_TAKEOVER_SOURCE_QUEST_OFFER, nil, true, pending.preferredMapID
            )
        end
        return false
    end,
    clearOnMapPinCleared = function()
        CancelQuestAdoptionRetry()
        return ClearQuestOfferBackedManual("explicit")
    end,
    startupSync = nil,
}
