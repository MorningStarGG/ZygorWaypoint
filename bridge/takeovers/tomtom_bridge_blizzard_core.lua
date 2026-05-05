local NS = _G.AzerothWaypointNS
local state = NS.State

NS.Internal = NS.Internal or {}

NS.Internal.BlizzardTakeovers = NS.Internal.BlizzardTakeovers or {}
local M = NS.Internal.BlizzardTakeovers

M.BlizzardKinds = M.BlizzardKinds or {}

state.bridgeTakeover = state.bridgeTakeover or {
    hooksInstalled = false,
    pendingGuideTakeover = nil,
    pendingGuideTakeoverSerial = 0,
}

local takeover = state.bridgeTakeover
takeover.recentGenericAddonTakeoverCallers = takeover.recentGenericAddonTakeoverCallers or {}
takeover.recentGenericAddonTakeoverOrder = takeover.recentGenericAddonTakeoverOrder or {}

local GetGuideVisibilityState = NS.GetGuideVisibilityState

-- ============================================================
-- Constants
-- ============================================================

local BLIZZARD_USER_WAYPOINT_STACK_START = 4
local BLIZZARD_USER_WAYPOINT_STACK_COUNT = 12
local BLIZZARD_USER_WAYPOINT_STACK_MATCHES = {
    "blizzard_sharedmapdataproviders\\waypointlocationdataprovider.lua",
    "worldquesttab\\dataprovider.lua",
}
local EXPLICIT_USER_SUPERTRACK_STACK_MATCHES = {
    "blizzard_poibutton\\poibutton.lua",
    "\\poibutton\\poibutton.lua",
    "blizzard_sharedmapdataproviders\\sharedmappoitemplates.lua",
    "blizzard_sharedmapdataproviders\\worldquestdataprovider.lua",
    "worldquesttab\\templates.lua",
    "worldquesttab\\mappinprovider.lua",
}
local GENERIC_ADDON_CLICK_STACK_MATCHES = {
    "onclick",
    "onmouse",
    "handleclick",
    "handlequestclick",
    "setaswaypoint",
    "setwaypoint",
    "mappin",
    "map_pin",
    "poibutton",
    "dataprovider",
    "provider.lua",
    "templates.lua",
}
local GENERIC_ADDON_AUTOMATION_STACK_MATCHES = {
    "onupdate",
    "ontimer",
    "schedule",
    "callbackhandler",
    "quest_log_update",
    "super_tracking_changed",
    "user_waypoint_updated",
    "addon_loaded",
    "loading_screen",
}
local BUILTIN_GENERIC_ADDON_DENYLIST = {
    azerothwaypoint = true,
    tomtom = true,
    zygorguidesviewer = true,
    zygorguidesviewerclassic = true,
    zygorguidesviewertbc = true,
    zygorguidesviewerwrath = true,
}

local PENDING_GUIDE_TAKEOVER_TIMEOUT_SECONDS = 0.6
local PENDING_GUIDE_TAKEOVER_EARLY_COMMIT_SECONDS = 0.05
local PENDING_GUIDE_TAKEOVER_CLEAR_GRACE_SECONDS = 0.2
local PENDING_GUIDE_TAKEOVER_SIGNAL_DELAYS = { 0, 0.05, 0.15, 0.35 }
local GUIDE_LOAD_SIGNAL_WINDOW_SECONDS = 0.75
local GUIDE_TARGET_COORD_EPSILON = 1e-5
local GENERIC_ADDON_TAKEOVER_CONTEXT_SECONDS = 0.75
local GENERIC_ADDON_RECENT_LIMIT = 20
local GENERIC_ADDON_RECENT_MIN_UPDATE_SECONDS = 0.25

local function GetTimeSafe()
    return type(GetTime) == "function" and GetTime() or 0
end

-- ============================================================
-- Pin type predicates
-- ============================================================

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

local function GetQuestOfferMapPinType()
    return GetSuperTrackingMapPinType("QuestOffer", 1)
end

local function IsQuestOfferMapPinType(pinType)
    return pinType == GetQuestOfferMapPinType()
end

local function GetTaxiNodeMapPinType()
    return GetSuperTrackingMapPinType("TaxiNode", 2)
end

local function IsTaxiNodeMapPinType(pinType)
    return pinType == GetTaxiNodeMapPinType()
end

-- Inline Enum values confirmed in-game: DigSite=3, HousingPlot=4
local DIGSITE_MAP_PIN_TYPE = Enum.SuperTrackingMapPinType and Enum.SuperTrackingMapPinType.DigSite or 3
local HOUSING_PLOT_MAP_PIN_TYPE = Enum.SuperTrackingMapPinType and Enum.SuperTrackingMapPinType.HousingPlot or 4

local function IsDigSiteMapPinType(pinType)
    return pinType == DIGSITE_MAP_PIN_TYPE
end

local function IsHousingPlotMapPinType(pinType)
    return pinType == HOUSING_PLOT_MAP_PIN_TYPE
end

-- ============================================================
-- Stack detection
-- ============================================================

local function GetDebugStack(startLevel, frameCount)
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

    return stack:gsub("/", "\\")
end

local function GetNormalizedDebugStack(startLevel, frameCount)
    local stack = GetDebugStack(startLevel, frameCount)
    return type(stack) == "string" and stack:lower() or nil
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

local IsBuiltinGenericAddonDenied

local function ExtractAddonNameFromStack(stack)
    if type(stack) ~= "string" then
        return nil
    end
    for addonName in stack:gmatch("[Ii]nterface\\[Aa]dd[Oo]ns\\([^\\%]%s:]+)") do
        local normalized = type(NS.NormalizeAddonTakeoverName) == "function"
            and NS.NormalizeAddonTakeoverName(addonName)
            or addonName
        if normalized and not IsBuiltinGenericAddonDenied(normalized) then
            return normalized
        end
    end
    return nil
end

IsBuiltinGenericAddonDenied = function(addonName)
    if type(addonName) ~= "string" then
        return true
    end
    local key = addonName:lower()
    return BUILTIN_GENERIC_ADDON_DENYLIST[key] == true
        or key:find("^blizzard_") ~= nil
        or key:find("^zygorguidesviewer") ~= nil
end

local function IsGenericAddonClickStack(stack)
    local normalizedStack = type(stack) == "string" and stack:lower() or nil
    return DoesStackMatchAnyPattern(normalizedStack, GENERIC_ADDON_CLICK_STACK_MATCHES)
        and not DoesStackMatchAnyPattern(normalizedStack, GENERIC_ADDON_AUTOMATION_STACK_MATCHES)
end

local function RecordGenericAddonTakeoverCaller(addonName, apiKind, allowed, reason)
    addonName = type(NS.NormalizeAddonTakeoverName) == "function"
        and NS.NormalizeAddonTakeoverName(addonName)
        or addonName
    if type(addonName) ~= "string" or addonName == "" then
        return
    end
    local key = addonName:lower()
    local callers = takeover.recentGenericAddonTakeoverCallers
    local order = takeover.recentGenericAddonTakeoverOrder
    local entry = callers[key]
    local now = GetTimeSafe()
    if type(entry) ~= "table" then
        entry = {
            addonName = addonName,
            firstAt = now,
            count = 0,
        }
        callers[key] = entry
        order[#order + 1] = key
    end
    local previousAt = tonumber(entry.lastAt) or 0
    local previousApi = entry.lastApiKind
    local previousDecision = entry.lastDecision
    local previousReason = entry.lastReason
    if now - previousAt < GENERIC_ADDON_RECENT_MIN_UPDATE_SECONDS
        and previousApi == tostring(apiKind or "unknown")
        and previousDecision == (allowed == true and "allowed" or "blocked")
        and previousReason == tostring(reason or "-")
    then
        entry.count = (tonumber(entry.count) or 0) + 1
        return
    end
    entry.addonName = addonName
    entry.lastAt = now
    entry.lastApiKind = tostring(apiKind or "unknown")
    entry.lastDecision = allowed == true and "allowed" or "blocked"
    entry.lastReason = tostring(reason or "-")
    entry.count = (tonumber(entry.count) or 0) + 1

    table.sort(order, function(left, right)
        local leftEntry = callers[left]
        local rightEntry = callers[right]
        return (tonumber(leftEntry and leftEntry.lastAt) or 0) > (tonumber(rightEntry and rightEntry.lastAt) or 0)
    end)
    while #order > GENERIC_ADDON_RECENT_LIMIT do
        local removedKey = table.remove(order)
        callers[removedKey] = nil
    end
end

local function SetGenericAddonTakeoverContext(addonName, apiKind, decision)
    local now = GetTimeSafe()
    takeover.genericAddonTakeoverContext = {
        sourceAddon = addonName,
        apiKind = apiKind,
        decision = decision,
        createdAt = now,
        expiresAt = now + GENERIC_ADDON_TAKEOVER_CONTEXT_SECONDS,
    }
end

local function IsFreshGenericAddonTakeoverContext(context)
    return type(context) == "table" and (tonumber(context.expiresAt) or 0) >= GetTimeSafe()
end

local function ResolveGenericAddonTakeoverCall(apiKind)
    local stack = GetDebugStack(BLIZZARD_USER_WAYPOINT_STACK_START, BLIZZARD_USER_WAYPOINT_STACK_COUNT)
    local addonName = ExtractAddonNameFromStack(stack)
    if not addonName or IsBuiltinGenericAddonDenied(addonName) then
        return false
    end

    local allowed, reason, canonicalName = false, "settings_unavailable", addonName
    if type(NS.GetGenericAddonBlizzardTakeoverDecision) == "function" then
        allowed, reason, canonicalName = NS.GetGenericAddonBlizzardTakeoverDecision(addonName)
    end

    local finalAllowed = false
    local finalReason = reason
    if allowed and reason == "allowlist" then
        finalAllowed = true
    elseif allowed and IsGenericAddonClickStack(stack) then
        finalAllowed = true
    elseif allowed then
        finalReason = "not_click_stack"
    end

    local displayName = type(canonicalName) == "string" and canonicalName or addonName
    RecordGenericAddonTakeoverCaller(displayName, apiKind, finalAllowed, finalReason)
    if finalAllowed then
        SetGenericAddonTakeoverContext(displayName, apiKind, finalReason)
    end
    return finalAllowed
end

function NS.GetGenericAddonBlizzardTakeoverContext(apiKind)
    local context = takeover.genericAddonTakeoverContext
    if not IsFreshGenericAddonTakeoverContext(context) then
        return nil
    end
    if apiKind ~= nil and context.apiKind ~= apiKind then
        return nil
    end
    return context
end

function NS.GetRecentGenericAddonBlizzardTakeoverCallers()
    local out = {}
    local callers = takeover.recentGenericAddonTakeoverCallers or {}
    local order = takeover.recentGenericAddonTakeoverOrder or {}
    for index, key in ipairs(order) do
        local entry = callers[key]
        if type(entry) == "table" then
            out[#out + 1] = {
                addonName = entry.addonName,
                lastAt = entry.lastAt,
                firstAt = entry.firstAt,
                lastApiKind = entry.lastApiKind,
                lastDecision = entry.lastDecision,
                lastReason = entry.lastReason,
                count = entry.count,
            }
        end
    end
    return out
end

function NS.ClearRecentGenericAddonBlizzardTakeoverCallers()
    takeover.recentGenericAddonTakeoverCallers = {}
    takeover.recentGenericAddonTakeoverOrder = {}
    return true
end

local function IsExplicitBlizzardUserWaypointCall()
    if type(NS.IsInternalUserWaypointMutation) == "function" and NS.IsInternalUserWaypointMutation() then
        return false
    end
    if type(NS.IsWorldQuestTabExplicitUserWaypointCall) == "function"
        and NS.IsWorldQuestTabExplicitUserWaypointCall()
    then
        return true
    end
    if DoesStackMatchAnyPattern(GetNormalizedDebugStack(), BLIZZARD_USER_WAYPOINT_STACK_MATCHES) then
        takeover.genericAddonTakeoverContext = nil
        return true
    end
    return ResolveGenericAddonTakeoverCall("user_waypoint")
end

local function IsExplicitUserSupertrack()
    if type(NS.IsWorldQuestTabExplicitSuperTrackCall) == "function"
        and NS.IsWorldQuestTabExplicitSuperTrackCall()
    then
        return true
    end
    if DoesStackMatchAnyPattern(GetNormalizedDebugStack(), EXPLICIT_USER_SUPERTRACK_STACK_MATCHES) then
        takeover.genericAddonTakeoverContext = nil
        return true
    end
    return ResolveGenericAddonTakeoverCall("supertrack")
end

function NS.IsExplicitBlizzardUserWaypointCall()
    return IsExplicitBlizzardUserWaypointCall()
end

function NS.IsExplicitUserSupertrack()
    return IsExplicitUserSupertrack()
end

local function ShouldPreemptManualQueueAskSupertrack()
    if type(NS.IsInternalSuperTrackMutation) == "function" and NS.IsInternalSuperTrackMutation() then
        return false
    end
    if type(NS.GetManualClickQueueMode) ~= "function" or NS.GetManualClickQueueMode() ~= "ask" then
        return false
    end
    if type(NS.IsRoutingEnabled) == "function" and not NS.IsRoutingEnabled() then
        return false
    end
    return IsExplicitUserSupertrack()
end

-- ============================================================
-- Coord and visibility helpers
-- ============================================================

local function GetWaypointSignature(mapID, x, y)
    local Signature = NS.Signature
    if type(Signature) ~= "function" then
        return nil
    end
    if type(mapID) ~= "number" or type(x) ~= "number" or type(y) ~= "number" then
        return nil
    end
    return Signature(mapID, x, y)
end

NS.GetWaypointSignatureForCoords = GetWaypointSignature

local function AreCoordsWithinEpsilon(xA, yA, xB, yB)
    if type(xA) ~= "number" or type(yA) ~= "number"
        or type(xB) ~= "number" or type(yB) ~= "number"
    then
        return false
    end
    return math.abs(xA - xB) <= GUIDE_TARGET_COORD_EPSILON
        and math.abs(yA - yB) <= GUIDE_TARGET_COORD_EPSILON
end

local function GetGoalMapID(goal)
    if type(goal) ~= "table" then
        return nil
    end
    return goal.map or goal.mapid or goal.mapID
end

local function IsGoalVisible(goal)
    if type(goal) ~= "table" then
        return false
    end
    if type(goal.IsVisible) ~= "function" then
        return true
    end
    local ok, visible = pcall(goal.IsVisible, goal)
    if not ok then
        return false
    end
    return visible ~= false
end

local function DoesGoalMatchTargetByCoords(goal, mapID, x, y)
    if type(goal) ~= "table"
        or goal.force_noway == true
        or not IsGoalVisible(goal)
        or type(goal.x) ~= "number"
        or type(goal.y) ~= "number"
    then
        return false
    end
    local goalMapID = GetGoalMapID(goal)
    if type(goalMapID) ~= "number" or goalMapID ~= mapID then
        return false
    end
    return AreCoordsWithinEpsilon(goal.x, goal.y, x, y)
end

local function DoesCurrentGuideTargetMatchByCoords(mapID, x, y)
    if type(mapID) ~= "number" or type(x) ~= "number" or type(y) ~= "number" then
        return false
    end
    local Z = NS.ZGV()
    local step = type(Z) == "table" and Z.CurrentStep or nil
    if type(step) ~= "table" or type(step.goals) ~= "table" then
        return false
    end
    local canonical = type(NS.ResolveCanonicalGuideGoal) == "function"
        and NS.ResolveCanonicalGuideGoal(step)
        or nil
    local goalNum = canonical and canonical.canonicalGoalNum or nil
    if type(goalNum) ~= "number" then
        return false
    end
    return DoesGoalMatchTargetByCoords(step.goals[goalNum], mapID, x, y)
end

local function GetCurrentGuideStateToken()
    if type(NS.GetCurrentGuideActivationToken) == "function" then
        return NS.GetCurrentGuideActivationToken()
    end

    local Z = NS.ZGV()
    local guide = type(Z) == "table" and Z.CurrentGuide or nil
    if type(guide) ~= "table" then
        return nil
    end
    local step = type(Z.CurrentStep) == "table" and Z.CurrentStep or nil
    return table.concat({
        tostring(guide.title or guide.guid or guide.name or guide),
        tostring(step and (step.num or step.stepnum) or Z.CurrentStepNum or "-"),
    }, "\031", 1, 2)
end

local function SameNumericID(left, right)
    local leftNumber = tonumber(left)
    local rightNumber = tonumber(right)
    return type(leftNumber) == "number"
        and type(rightNumber) == "number"
        and leftNumber == rightNumber
end

local function DoesHeaderValueMatch(value, expected)
    if type(value) == "table" then
        for _, entry in pairs(value) do
            if SameNumericID(entry, expected) or tostring(entry) == tostring(expected) then
                return true
            end
        end
        return false
    end
    return SameNumericID(value, expected) or tostring(value) == tostring(expected)
end

local function DoesCurrentGuideHeaderMatch(fieldName, expected)
    local Z = NS.ZGV()
    local guide = type(Z) == "table" and Z.CurrentGuide or nil
    local header = type(guide) == "table" and guide.headerdata or nil
    if type(header) ~= "table" or expected == nil then
        return false
    end
    return DoesHeaderValueMatch(header[fieldName], expected)
end

local function DoesCurrentGuideStepLabelMatchID(id)
    if id == nil then
        return false
    end

    local Z = NS.ZGV()
    local guide = type(Z) == "table" and Z.CurrentGuide or nil
    local labels = type(guide) == "table" and guide.steplabels or nil
    if type(labels) ~= "table" then
        return false
    end

    local step = type(Z.CurrentStep) == "table" and Z.CurrentStep or nil
    local currentStepNum = tonumber(step and step.num or Z.CurrentStepNum)
    if type(currentStepNum) ~= "number" then
        return false
    end

    local suffix = "-" .. tostring(id)
    for labelName, labelData in pairs(labels) do
        local labelStepNum = type(labelData) == "table" and tonumber(labelData[1]) or tonumber(labelData)
        if type(labelName) == "string"
            and labelName:sub(-#suffix) == suffix
            and labelStepNum == currentStepNum
        then
            return true
        end
    end
    return false
end

local function DoesCurrentGuideMatchAreaPoiID(areaPoiID)
    return DoesCurrentGuideHeaderMatch("areapoiid", areaPoiID)
        or DoesCurrentGuideStepLabelMatchID(areaPoiID)
end

local function DoesCurrentGuideMatchVignetteID(vignetteID)
    return DoesCurrentGuideHeaderMatch("vignetteID", vignetteID)
        or DoesCurrentGuideStepLabelMatchID(vignetteID)
end

local function BuildZygorBlizzardIconGuideSignal(object)
    if type(object) ~= "table" then
        return nil
    end

    local poiInfo = type(object.poiInfo) == "table" and object.poiInfo or nil
    local areaPoiID = tonumber(object.areaPoiID or object.areaPOIID or (poiInfo and poiInfo.areaPoiID))
    local vignetteID = tonumber(object.vignetteID or (poiInfo and poiInfo.vignetteID))
    if type(areaPoiID) ~= "number" and type(vignetteID) ~= "number" then
        return nil
    end

    return {
        at = GetTimeSafe(),
        areaPoiID = areaPoiID,
        vignetteID = vignetteID,
        guideStateToken = GetCurrentGuideStateToken(),
    }
end

local function DoesPendingGuideLoadSignalMatch(pending)
    local signal = takeover.lastZygorBlizzardIconGuideSignal
    if type(pending) ~= "table" or type(signal) ~= "table" then
        return false
    end

    local signalAt = tonumber(signal.at)
    if type(signalAt) ~= "number" then
        return false
    end

    local createdAt = tonumber(pending.createdAt) or signalAt
    if signalAt + GUIDE_LOAD_SIGNAL_WINDOW_SECONDS < createdAt
        or GetTimeSafe() - signalAt > GUIDE_LOAD_SIGNAL_WINDOW_SECONDS
    then
        return false
    end

    if pending.kind == "area_poi"
        and SameNumericID(signal.areaPoiID, pending.areaPoiID)
    then
        return DoesCurrentGuideMatchAreaPoiID(pending.areaPoiID)
    end

    if pending.kind == "vignette"
        and type(pending.vignetteID) == "number"
        and SameNumericID(signal.vignetteID, pending.vignetteID)
    then
        return DoesCurrentGuideMatchVignetteID(pending.vignetteID)
    end

    return false
end

local function DidPendingGuideStateChange(pending)
    if type(pending) ~= "table" or type(pending.startGuideStateToken) ~= "string" then
        return false
    end
    local currentToken = GetCurrentGuideStateToken()
    return type(currentToken) == "string" and currentToken ~= pending.startGuideStateToken
end

local function GetRecentGuideLoadRequestForPending(pending)
    if type(pending) ~= "table" then
        return nil
    end
    if type(pending.guideLoadRequestedAt) == "number" then
        return pending
    end
    local request = takeover.lastGuideLoadRequest
    local requestAt = type(request) == "table" and tonumber(request.at) or nil
    local createdAt = tonumber(pending.createdAt)
    if type(requestAt) ~= "number" or type(createdAt) ~= "number" then
        return nil
    end
    if requestAt + GUIDE_LOAD_SIGNAL_WINDOW_SECONDS < createdAt
        or GetTimeSafe() - requestAt > GUIDE_LOAD_SIGNAL_WINDOW_SECONDS
    then
        return nil
    end
    return request
end

local function HasPendingGuideLoadRequest(pending)
    return GetRecentGuideLoadRequestForPending(pending) ~= nil
        or DoesPendingGuideLoadSignalMatch(pending)
end

local function ShouldSuppressGuideOwnedTakeover(mapID, x, y, questID, pending)
    if GetGuideVisibilityState == nil or GetGuideVisibilityState() ~= "visible" then
        return false
    end
    local guideChanged = type(pending) ~= "table" or DidPendingGuideStateChange(pending)
    local hasGuideLoadRequest = type(pending) == "table" and HasPendingGuideLoadRequest(pending) or false
    if questID and type(NS.IsCurrentGuideStepQuest) == "function"
        and NS.IsCurrentGuideStepQuest(questID)
    then
        return guideChanged or hasGuideLoadRequest
    end
    if DoesCurrentGuideTargetMatchByCoords(mapID, x, y) then
        return guideChanged or hasGuideLoadRequest
    end
    return DoesPendingGuideLoadSignalMatch(pending)
end

function NS.DoesGuideOwnTarget(mapID, x, y)
    return ShouldSuppressGuideOwnedTakeover(mapID, x, y)
end

local function GetShownWorldMapID()
    local worldMapFrame = rawget(_G, "WorldMapFrame")
    if not worldMapFrame
        or type(worldMapFrame.IsShown) ~= "function"
        or not worldMapFrame:IsShown()
        or type(worldMapFrame.GetMapID) ~= "function"
    then
        return nil
    end
    local ok, mapID = pcall(worldMapFrame.GetMapID, worldMapFrame)
    if ok and type(mapID) == "number" and mapID > 0 then
        return mapID
    end
end

NS.GetShownWorldMapID = GetShownWorldMapID

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

NS.ReadUiMapPointCoords = ReadUiMapPointCoords

local function ResolveSuperTrackedMapPinArgs(pinType, pinID)
    if type(pinID) == "number" and pinID > 0 then
        return pinType, pinID
    end
    if type(C_SuperTrack) ~= "table"
        or type(C_SuperTrack.GetSuperTrackedMapPin) ~= "function"
    then
        return pinType, pinID
    end
    local currentType, currentID = C_SuperTrack.GetSuperTrackedMapPin()
    if currentType == pinType or pinType == nil then
        return currentType, currentID
    end
    return pinType, pinID
end

-- ============================================================
-- Pending guide takeover state machine
-- ============================================================

local function ClearPendingGuideTakeover()
    takeover.pendingGuideTakeover = nil
    takeover.pendingGuideTakeoverSerial = (takeover.pendingGuideTakeoverSerial or 0) + 1
end

function NS.ClearPendingGuideTakeover()
    ClearPendingGuideTakeover()
end

local function ShouldPreservePendingGuideTakeoverForClear()
    local pending = takeover.pendingGuideTakeover
    if type(pending) ~= "table" or pending.preserveAcrossInitialClear ~= true then
        return false
    end
    local createdAt = tonumber(pending.createdAt)
    return createdAt ~= nil and GetTimeSafe() - createdAt <= PENDING_GUIDE_TAKEOVER_CLEAR_GRACE_SECONDS
end

local function ClearPendingGuideTakeoverForClear()
    if ShouldPreservePendingGuideTakeoverForClear() then
        return false
    end
    ClearPendingGuideTakeover()
    return true
end

function NS.ClearPendingGuideTakeoverForClear()
    return ClearPendingGuideTakeoverForClear()
end

function NS.HasPendingGuideTakeover()
    return type(takeover.pendingGuideTakeover) == "table"
end

local function MarkRecentExplicitMapPinCommit()
    takeover.suppressNextMapPinClearUntil = GetTimeSafe() + PENDING_GUIDE_TAKEOVER_CLEAR_GRACE_SECONDS
end

local function ConsumeRecentExplicitMapPinCommitClear()
    local suppressUntil = tonumber(takeover.suppressNextMapPinClearUntil)
    takeover.suppressNextMapPinClearUntil = nil
    return suppressUntil ~= nil and GetTimeSafe() <= suppressUntil
end

local function ResolvePendingGuideTakeoverTarget(pending)
    if type(pending) ~= "table" then
        return nil
    end
    local descriptor = M.BlizzardKinds[pending.kind]
    local resolver = descriptor and descriptor.resolvePending
    if resolver then
        return resolver(pending)
    end
    return nil
end

local function CommitPendingGuideTakeover(pending)
    if type(pending) ~= "table" then
        return false
    end
    local descriptor = M.BlizzardKinds[pending.kind]
    local committer = descriptor and descriptor.commitPending
    if committer then
        return committer(pending)
    end
    return false
end

local function ShouldCommitPendingGuideTakeoverEarly(pending)
    if type(pending) ~= "table" or HasPendingGuideLoadRequest(pending) then
        return false
    end
    local createdAt = tonumber(pending.createdAt)
    return createdAt ~= nil and GetTimeSafe() - createdAt >= PENDING_GUIDE_TAKEOVER_EARLY_COMMIT_SECONDS
end

local function ActivateGuideRouteFromPendingTakeover(pending, mapID, x, y, trigger)
    if type(NS.ActivateGuideRouteForExplicitTakeover) ~= "function" then
        return false
    end

    local activated = NS.ActivateGuideRouteForExplicitTakeover("guide_explicit_" .. tostring(pending.kind or "takeover"), {
        startGuideStateToken = pending.startGuideStateToken,
        fallbackTarget = {
            mapID = mapID,
            x = x,
            y = y,
        },
        -- The pending takeover state already proved guide ownership for this
        -- exact click. Do not re-apply the coordinate fallback gate here,
        -- because guide-loaded POIs often route to the guide's first step,
        -- not to the clicked map pin itself.
        requireGuideChangeOrTargetMatch = false,
    })

    if activated and type(NS.Log) == "function" then
        NS.Log("Guide takeover adopted manual authority", tostring(pending.kind or "-"), tostring(trigger or "-"))
    end
    return activated
end

local function FlushPendingGuideTakeover(trigger)
    local pending = takeover.pendingGuideTakeover
    if type(pending) ~= "table" then
        return false
    end

    local mapID, x, y, questID = ResolvePendingGuideTakeoverTarget(pending)
    if type(mapID) == "number" and type(x) == "number" and type(y) == "number" then
        if ShouldSuppressGuideOwnedTakeover(mapID, x, y, questID, pending) then
            if pending.kind == "quest" or pending.kind == "quest_offer" then
                NS.Log("Guide-owned quest takeover suppressed",
                    tostring(questID), tostring(pending.kind), tostring(trigger))
            else
                NS.Log("Guide-owned takeover suppressed",
                    tostring(pending.kind), tostring(trigger))
            end
            ActivateGuideRouteFromPendingTakeover(pending, mapID, x, y, trigger)
            ClearPendingGuideTakeover()
            return true
        end
    end

    if trigger ~= "timeout" then
        if ShouldCommitPendingGuideTakeoverEarly(pending) then
            ClearPendingGuideTakeover()
            return CommitPendingGuideTakeover(pending)
        end
        return false
    end

    ClearPendingGuideTakeover()
    return CommitPendingGuideTakeover(pending)
end

function NS.HandleZygorBlizzardIconGuideSignal(object)
    local signal = BuildZygorBlizzardIconGuideSignal(object)
    if type(signal) ~= "table" then
        return false
    end

    takeover.lastZygorBlizzardIconGuideSignal = signal
    local pending = takeover.pendingGuideTakeover
    if type(pending) == "table" then
        pending.guideLoadRequestedAt = signal.at
        pending.guideLoadTrigger = "zygor_blizzard_icon"
    end
    return FlushPendingGuideTakeover("zygor_blizzard_icon")
end

function NS.NotifyPendingGuideTakeoverGuideLoad(trigger, detail)
    local now = GetTimeSafe()
    takeover.lastGuideLoadRequest = {
        at = now,
        trigger = tostring(trigger or "guide_load"),
        detail = type(detail) == "string" and detail or nil,
        guideStateToken = GetCurrentGuideStateToken(),
    }
    local pending = takeover.pendingGuideTakeover
    if type(pending) == "table" then
        pending.guideLoadRequestedAt = now
        pending.guideLoadTrigger = takeover.lastGuideLoadRequest.trigger
        pending.guideLoadDetail = takeover.lastGuideLoadRequest.detail
    end
    return true
end

local function InstallZygorBlizzardIconGuideSignalHook()
    if takeover.zygorBlizzardIconGuideSignalHooked then
        return true
    end

    local Z = type(NS.ZGV) == "function" and NS.ZGV() or rawget(_G, "ZygorGuidesViewer")
    if type(Z) ~= "table" or type(Z.SuggestGuideFromBlizzardIcon) ~= "function" then
        return false
    end

    hooksecurefunc(Z, "SuggestGuideFromBlizzardIcon", function(_, object)
        NS.SafeCall(NS.HandleZygorBlizzardIconGuideSignal, object)
    end)
    takeover.zygorBlizzardIconGuideSignalHooked = true
    return true
end

function NS.InstallZygorBlizzardIconGuideSignalHook()
    return InstallZygorBlizzardIconGuideSignalHook()
end

local function BeginPendingGuideTakeover(pending)
    if type(pending) ~= "table" then
        return false
    end

    if GetGuideVisibilityState and GetGuideVisibilityState() ~= "visible" then
        NS.BlockHiddenGuideAutoLoads(PENDING_GUIDE_TAKEOVER_TIMEOUT_SECONDS)
        local committed = CommitPendingGuideTakeover(pending)
        if committed then
            MarkRecentExplicitMapPinCommit()
        end
        return committed
    end

    takeover.pendingGuideTakeoverSerial = (takeover.pendingGuideTakeoverSerial or 0) + 1
    local pendingSerial = takeover.pendingGuideTakeoverSerial
    pending.createdAt = pending.createdAt or GetTimeSafe()
    pending.preserveAcrossInitialClear = true
    pending.startGuideStateToken = pending.startGuideStateToken or GetCurrentGuideStateToken()
    takeover.pendingGuideTakeover = pending

    for index = 1, #PENDING_GUIDE_TAKEOVER_SIGNAL_DELAYS do
        NS.After(PENDING_GUIDE_TAKEOVER_SIGNAL_DELAYS[index], function()
            if takeover.pendingGuideTakeoverSerial ~= pendingSerial then
                return
            end
            NS.SafeCall(FlushPendingGuideTakeover, "guide_wait")
        end)
    end

    NS.After(PENDING_GUIDE_TAKEOVER_TIMEOUT_SECONDS, function()
        if takeover.pendingGuideTakeoverSerial ~= pendingSerial then
            return
        end
        NS.SafeCall(FlushPendingGuideTakeover, "timeout")
    end)

    return true
end

function NS.BeginPendingGuideTakeover(pending)
    return BeginPendingGuideTakeover(pending)
end

function NS.BlockHiddenGuideAutoLoads(duration)
    takeover.blockHiddenGuideLoadsUntil = math.max(
        tonumber(takeover.blockHiddenGuideLoadsUntil) or 0,
        GetTimeSafe() + (tonumber(duration) or PENDING_GUIDE_TAKEOVER_TIMEOUT_SECONDS)
    )
end

-- ============================================================
-- Kind dispatch
-- ============================================================

local function ResolvePinTypeToKind(pinType)
    if IsAreaPoiMapPinType(pinType) then return "area_poi" end
    if IsQuestOfferMapPinType(pinType) then return "quest_offer" end
    if IsTaxiNodeMapPinType(pinType) then return "taxi_node" end
    if IsDigSiteMapPinType(pinType) then return "dig_site" end
    if IsHousingPlotMapPinType(pinType) then return "housing_plot" end
    return nil
end

local function HandleSuperTrackedMapPinChanged(pinType, pinID, preferredMapID)
    local resolvedPinType, resolvedPinID = ResolveSuperTrackedMapPinArgs(pinType, pinID)
    local explicit = IsExplicitUserSupertrack()

    local kind = ResolvePinTypeToKind(resolvedPinType)
    local descriptor = kind and M.BlizzardKinds[kind]
    local handler = descriptor and descriptor.onChanged
    if handler then
        return handler(resolvedPinID, preferredMapID, explicit)
    end

    ClearPendingGuideTakeover()
    return false
end

local function HandleSuperTrackedMapPinCleared()
    local suppressReplacementClear = ConsumeRecentExplicitMapPinCommitClear()
    ClearPendingGuideTakeoverForClear()
    if not suppressReplacementClear
        and IsExplicitUserSupertrack()
        and type(NS.CancelPendingManualRoute) == "function"
    then
        NS.CancelPendingManualRoute("explicit_map_pin_clear")
    end
    if suppressReplacementClear then
        return false
    end
    local cleared = false
    for _, descriptor in pairs(M.BlizzardKinds) do
        if type(descriptor.clearOnMapPinCleared) == "function" then
            if descriptor.clearOnMapPinCleared() then
                cleared = true
            end
        end
    end
    return cleared
end

-- ============================================================
-- Multi-type resolver chains (used by manual.lua and sync.lua)
-- ============================================================

function NS.HandleRemovedBlizzardMapPinDestination(destination)
    local areaPoiID = type(NS.GetAreaPoiIDForMapPinBackedManual) == "function"
        and NS.GetAreaPoiIDForMapPinBackedManual(destination)
        or nil
    if areaPoiID then
        if type(NS.ClearSuperTrackedAreaPoiIfCurrent) == "function" then
            NS.ClearSuperTrackedAreaPoiIfCurrent(areaPoiID)
        end
        return true
    end

    local nodeID = type(NS.GetTaxiNodeIDForMapPinBackedManual) == "function"
        and NS.GetTaxiNodeIDForMapPinBackedManual(destination)
        or nil
    if nodeID then
        if type(NS.ClearSuperTrackedTaxiNodeIfCurrent) == "function" then
            NS.ClearSuperTrackedTaxiNodeIfCurrent(nodeID)
        end
        return true
    end

    local digSiteID = type(NS.GetDigSiteIDForMapPinBackedManual) == "function"
        and NS.GetDigSiteIDForMapPinBackedManual(destination)
        or nil
    if digSiteID then
        if type(NS.ClearSuperTrackedDigSiteIfCurrent) == "function" then
            NS.ClearSuperTrackedDigSiteIfCurrent(digSiteID)
        end
        return true
    end

    local plotID = type(NS.GetHousingPlotIDForMapPinBackedManual) == "function"
        and NS.GetHousingPlotIDForMapPinBackedManual(destination)
        or nil
    if plotID then
        if type(NS.ClearSuperTrackedHousingPlotIfCurrent) == "function" then
            NS.ClearSuperTrackedHousingPlotIfCurrent(plotID)
        end
        return true
    end

    return false
end

function NS.GetMapPinInfoForMapPinBackedManualDestination(destination)
    return (type(NS.GetAreaPoiMapPinInfoForMapPinBackedManual) == "function"
            and NS.GetAreaPoiMapPinInfoForMapPinBackedManual(destination))
        or (type(NS.GetTaxiNodeMapPinInfoForMapPinBackedManual) == "function"
            and NS.GetTaxiNodeMapPinInfoForMapPinBackedManual(destination))
        or (type(NS.GetVignetteMapPinInfoForMapPinBackedManual) == "function"
            and NS.GetVignetteMapPinInfoForMapPinBackedManual(destination))
        or (type(NS.GetDigSiteMapPinInfoForMapPinBackedManual) == "function"
            and NS.GetDigSiteMapPinInfoForMapPinBackedManual(destination))
        or (type(NS.GetHousingPlotMapPinInfoForMapPinBackedManual) == "function"
            and NS.GetHousingPlotMapPinInfoForMapPinBackedManual(destination))
        or nil
end

-- ============================================================
-- NS exports called from init.lua and hooks.lua
-- ============================================================

function NS.HandlePendingGuideTakeoverSignal(trigger)
    return FlushPendingGuideTakeover(trigger or "signal")
end

function NS.SyncBlizzardTakeovers()
    for _, descriptor in pairs(M.BlizzardKinds) do
        if type(descriptor.startupSync) == "function" then
            NS.SafeCall(descriptor.startupSync)
        end
    end
end

function NS.InstallBlizzardTakeoverHooks()
    if takeover.hooksInstalled then
        return true
    end
    if type(C_SuperTrack) ~= "table"
        or type(C_SuperTrack.SetSuperTrackedQuestID) ~= "function"
    then
        return false
    end

    -- Quest supertrack: dedicated hook (NOT dispatched via SetSuperTrackedMapPin)
    hooksecurefunc(C_SuperTrack, "SetSuperTrackedQuestID", function(questID)
        if type(NS.IsInternalSuperTrackMutation) == "function" and NS.IsInternalSuperTrackMutation() then
            return
        end
        NS.SafeCall(NS.HandleSuperTrackedQuestIDChanged, questID)
    end)

    if type(C_SuperTrack.SetSuperTrackedMapPin) == "function" then
        local originalSetSuperTrackedMapPin = C_SuperTrack.SetSuperTrackedMapPin
        takeover.originalSetSuperTrackedMapPin = takeover.originalSetSuperTrackedMapPin or originalSetSuperTrackedMapPin
        -- Ask mode needs a pre-call guard: hooksecurefunc runs after Blizzard
        -- has already changed native supertracking, which makes the overlay
        -- briefly follow the clicked pin before the placement prompt resolves.
        C_SuperTrack.SetSuperTrackedMapPin = function(pinType, pinID, ...) ---@diagnostic disable-line: duplicate-set-field
            if type(NS.IsInternalSuperTrackMutation) == "function" and NS.IsInternalSuperTrackMutation() then
                return originalSetSuperTrackedMapPin(pinType, pinID, ...)
            end

            local preferredMapID = GetShownWorldMapID()
            if ShouldPreemptManualQueueAskSupertrack() then
                local handled = NS.SafeCall(HandleSuperTrackedMapPinChanged, pinType, pinID, preferredMapID)
                if handled then
                    return
                end
            end

            local results = { originalSetSuperTrackedMapPin(pinType, pinID, ...) }
            NS.SafeCall(HandleSuperTrackedMapPinChanged, pinType, pinID, preferredMapID)
            return unpack(results)
        end
    end

    if type(C_SuperTrack.SetSuperTrackedVignette) == "function" then
        hooksecurefunc(C_SuperTrack, "SetSuperTrackedVignette", function(vignetteGUID)
            if type(NS.IsInternalSuperTrackMutation) == "function" and NS.IsInternalSuperTrackMutation() then
                return
            end
            NS.SafeCall(NS.HandleSuperTrackedVignetteChanged, vignetteGUID)
        end)
    end

    if type(C_SuperTrack.ClearSuperTrackedMapPin) == "function" then
        hooksecurefunc(C_SuperTrack, "ClearSuperTrackedMapPin", function()
            if type(NS.IsInternalSuperTrackMutation) == "function" and NS.IsInternalSuperTrackMutation() then
                return
            end
            NS.SafeCall(HandleSuperTrackedMapPinCleared)
        end)
    end

    -- ClearAllSuperTracked does NOT internally fire ClearSuperTrackedMapPin (confirmed in-game).
    -- Map-pin types (AreaPOI, TaxiNode, DigSite, HousingPlot) are intentionally not cleared by it.
    -- Only vignette needs clearing here.
    if type(C_SuperTrack.ClearAllSuperTracked) == "function" then
        hooksecurefunc(C_SuperTrack, "ClearAllSuperTracked", function()
            if type(NS.IsInternalSuperTrackMutation) == "function" and NS.IsInternalSuperTrackMutation() then
                return
            end
            NS.SafeCall(NS.HandleSuperTrackedVignetteChanged)
        end)
    end

    if type(C_QuestLog) == "table" then
        if type(C_QuestLog.AddQuestWatch) == "function" then
            hooksecurefunc(C_QuestLog, "AddQuestWatch", function(questID)
                NS.After(0, function()
                    NS.SafeCall(NS.HandleQuestWatchAdded, questID)
                end)
            end)
        end

        if type(C_QuestLog.RemoveQuestWatch) == "function" then
            hooksecurefunc(C_QuestLog, "RemoveQuestWatch", function(questID)
                NS.After(0, function()
                    NS.SafeCall(NS.HandleQuestWatchRemoved, questID)
                end)
            end)
        end
    end

    -- UserWaypoint hooks install themselves (hook-based, not event-based; reads debugstack at call site)
    if type(NS.InstallUserWaypointHooks) == "function" then
        NS.InstallUserWaypointHooks()
    end
    if type(NS.InstallGossipPoiHooks) == "function" then
        NS.InstallGossipPoiHooks()
    end
    if type(NS.InstallWorldQuestTabHooks) == "function" then
        NS.InstallWorldQuestTabHooks()
    end
    InstallZygorBlizzardIconGuideSignalHook()

    takeover.hooksInstalled = true
    return true
end
