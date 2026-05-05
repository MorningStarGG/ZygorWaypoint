local NS = _G.AzerothWaypointNS
local state = NS.State

state.bridgeWorldQuestTabTakeover = state.bridgeWorldQuestTabTakeover or {
    hooksInstalled = false,
    context = nil,
    contextDepth = 0,
}

local wqt = state.bridgeWorldQuestTabTakeover

local WORLDQUESTTAB_CONTEXT_SECONDS = 0.75
local WORLDQUESTTAB_COORD_EPSILON = 0.0002

local function GetTimeSafe()
    return type(GetTime) == "function" and GetTime() or 0
end

local function TrimString(value)
    if type(value) ~= "string" then
        return nil
    end
    value = value:gsub("^%s+", ""):gsub("%s+$", "")
    if value == "" then
        return nil
    end
    return value
end

local function NormalizeQuestID(questID)
    return type(questID) == "number" and questID > 0 and questID or nil
end

local function GetWorldQuestTabUtils()
    local utils = _G["WQT_Utils"]
    return type(utils) == "table" and utils or nil
end

local function ResolveQuestTitle(questInfo, questID)
    local title = type(questInfo) == "table" and TrimString(questInfo.title) or nil
    if title then return title end
    if type(C_TaskQuest) == "table" and type(C_TaskQuest.GetQuestInfoByQuestID) == "function" then
        title = C_TaskQuest.GetQuestInfoByQuestID(questID)
        title = TrimString(title)
        if title then return title end
    end
    if type(C_QuestLog) == "table" and type(C_QuestLog.GetTitleForQuestID) == "function" then
        title = C_QuestLog.GetTitleForQuestID(questID)
        title = TrimString(title)
        if title then return title end
    end
end

local function ResolveQuestCoords(utils, questInfo)
    local mapID = type(questInfo) == "table" and type(questInfo.mapID) == "number" and questInfo.mapID or nil
    if type(utils) == "table" and type(utils.GetQuestMapLocation) == "function" then
        local ok, x, y = pcall(utils.GetQuestMapLocation, utils, questInfo, mapID)
        if ok and type(x) == "number" and type(y) == "number" then
            return mapID, x, y
        end
    end
    return mapID, nil, nil
end

local function BuildContext(questInfo, action)
    local questID = NormalizeQuestID(type(questInfo) == "table" and questInfo.questID or nil)
    if not questID then
        return nil
    end
    local utils = GetWorldQuestTabUtils()
    local mapID, x, y = ResolveQuestCoords(utils, questInfo)
    local now = GetTimeSafe()
    return {
        questID = questID,
        mapID = mapID,
        x = x,
        y = y,
        title = ResolveQuestTitle(questInfo, questID),
        action = TrimString(action) or "worldquesttab",
        sourceAddon = "WorldQuestTab",
        createdAt = now,
        expiresAt = now + WORLDQUESTTAB_CONTEXT_SECONDS,
    }
end

local function SetContext(questInfo, action)
    local context = BuildContext(questInfo, action)
    if type(context) == "table" then
        wqt.context = context
    end
    return context
end

local function WithContext(questInfo, action, fn, ...)
    if type(fn) ~= "function" then
        return nil
    end
    wqt.contextDepth = (wqt.contextDepth or 0) + 1
    local previousContext = wqt.context
    SetContext(questInfo, action)
    local results = { pcall(fn, ...) }
    wqt.contextDepth = math.max((wqt.contextDepth or 1) - 1, 0)
    wqt.context = previousContext
    return unpack(results)
end

local function IsFreshContext(context)
    return type(context) == "table" and (tonumber(context.expiresAt) or 0) >= GetTimeSafe()
end

---@return table|nil
local function GetFreshContext()
    local context = wqt.context
    if type(context) ~= "table" or not IsFreshContext(context) then
        return nil
    end
    return context
end

local function CoordinatesMatchContext(context, mapID, x, y)
    if type(context) ~= "table"
        or type(context.mapID) ~= "number"
        or type(context.x) ~= "number"
        or type(context.y) ~= "number"
        or type(mapID) ~= "number"
        or type(x) ~= "number"
        or type(y) ~= "number"
    then
        return false
    end
    return context.mapID == mapID
        and math.abs(context.x - x) <= WORLDQUESTTAB_COORD_EPSILON
        and math.abs(context.y - y) <= WORLDQUESTTAB_COORD_EPSILON
end

function NS.GetWorldQuestTabQuestContext(questID)
    local context = GetFreshContext()
    if not context then
        return nil
    end
    local normalizedQuestID = NormalizeQuestID(questID)
    if normalizedQuestID and context.questID ~= normalizedQuestID then
        return nil
    end
    return context
end

function NS.GetWorldQuestTabUserWaypointContext(mapID, x, y)
    local context = GetFreshContext()
    if not context or not CoordinatesMatchContext(context, mapID, x, y) then
        return nil
    end
    return context
end

function NS.IsWorldQuestTabExplicitSuperTrackCall()
    local context = GetFreshContext()
    if not context then
        return false
    end
    return NormalizeQuestID(context.questID) ~= nil
end

function NS.IsWorldQuestTabExplicitUserWaypointCall()
    local context = GetFreshContext()
    if not context then
        return false
    end
    local action = context.action
    return action == "set_waypoint" or action == "quest_click"
end

local function WrapQuestInfo(questInfo)
    if type(questInfo) ~= "table"
        or questInfo.__awpWorldQuestTabWrapped
        or type(questInfo.SetAsWaypoint) ~= "function"
    then
        return questInfo
    end
    local originalSetAsWaypoint = questInfo.SetAsWaypoint
    questInfo.__awpWorldQuestTabWrapped = true
    questInfo.__awpWorldQuestTabSetAsWaypoint = originalSetAsWaypoint
    questInfo.SetAsWaypoint = function(self, ...)
        local ok, result1, result2, result3, result4 = WithContext(
            self,
            "set_waypoint",
            originalSetAsWaypoint,
            self,
            ...
        )
        if not ok then error(result1, 0) end
        return result1, result2, result3, result4
    end
    return questInfo
end

local function InstallWorldQuestTabHooks()
    if wqt.hooksInstalled then
        return true
    end

    local utils = GetWorldQuestTabUtils()
    if type(utils) ~= "table" then
        return false
    end

    if type(utils.QuestCreationFunc) == "function" then
        local originalQuestCreationFunc = utils.QuestCreationFunc
        wqt.originalQuestCreationFunc = wqt.originalQuestCreationFunc or originalQuestCreationFunc
        utils.QuestCreationFunc = function(self, ...)
            local questInfo = originalQuestCreationFunc(self, ...)
            return WrapQuestInfo(questInfo)
        end
    end

    if type(utils.HandleQuestClick) == "function" then
        local originalHandleQuestClick = utils.HandleQuestClick
        wqt.originalHandleQuestClick = wqt.originalHandleQuestClick or originalHandleQuestClick
        utils.HandleQuestClick = function(self, frame, questInfo, button, ...)
            WrapQuestInfo(questInfo)
            local ok, result1, result2, result3, result4 = WithContext(
                questInfo,
                "quest_click",
                originalHandleQuestClick,
                self,
                frame,
                questInfo,
                button,
                ...
            )
            if not ok then error(result1, 0) end
            return result1, result2, result3, result4
        end
    end

    wqt.hooksInstalled = true
    return true
end

function NS.InstallWorldQuestTabHooks()
    return InstallWorldQuestTabHooks()
end

local eventFrame = CreateFrame and CreateFrame("Frame") or nil
if eventFrame then
    eventFrame:RegisterEvent("ADDON_LOADED")
    eventFrame:SetScript("OnEvent", function(_, _, addonName)
        if addonName == "WorldQuestTab" then
            if type(NS.After) == "function" then
                NS.After(0, InstallWorldQuestTabHooks)
            else
                InstallWorldQuestTabHooks()
            end
        end
    end)
end
