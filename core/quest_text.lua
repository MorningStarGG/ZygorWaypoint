local NS = _G.AzerothWaypointNS

local function NormalizeText(value)
    if type(value) ~= "string" then
        return nil
    end
    value = value:gsub("%s+", " "):gsub("^%s+", ""):gsub("%s+$", "")
    if value == "" then
        return nil
    end
    return value
end

local function NormalizeQuestID(value)
    local questID = tonumber(value)
    if questID and questID > 0 then
        return questID
    end
end

local function NormalizeObjectiveIndex(value)
    local objectiveIndex = tonumber(value)
    if objectiveIndex and objectiveIndex > 0 then
        return objectiveIndex
    end
end

local function SafeCall(fn, ...)
    if type(fn) ~= "function" then
        return nil
    end
    local ok, result = pcall(fn, ...)
    if ok then
        return result
    end
end

local function GetQuestObjectives(questID)
    if type(C_QuestLog) ~= "table" or type(C_QuestLog.GetQuestObjectives) ~= "function" then
        return nil
    end
    local ok, objectives = pcall(C_QuestLog.GetQuestObjectives, questID)
    if ok and type(objectives) == "table" then
        return objectives
    end
end

local function IsQuestInLog(questID)
    if type(C_QuestLog) ~= "table" then
        return false
    end

    if type(C_QuestLog.IsOnQuest) == "function" then
        local ok, active = pcall(C_QuestLog.IsOnQuest, questID)
        if ok then
            return active == true
        end
    end

    if type(C_QuestLog.GetLogIndexForQuestID) == "function" then
        local ok, logIndex = pcall(C_QuestLog.GetLogIndexForQuestID, questID)
        if ok and type(logIndex) == "number" then
            return logIndex > 0
        end
    end

    return false
end

local function IsQuestReadyForTurnIn(questID)
    if type(C_QuestLog) ~= "table" or type(C_QuestLog.ReadyForTurnIn) ~= "function" then
        return false
    end
    local ok, ready = pcall(C_QuestLog.ReadyForTurnIn, questID)
    return ok and ready == true
end

local function QuoteQuestAction(action, title)
    title = NormalizeText(title)
    if not title then
        return nil
    end
    return action .. " '" .. title .. "'"
end

function NS.ResolveQuestTitle(questID)
    questID = NormalizeQuestID(questID)
    if not questID then
        return nil
    end

    local title = type(C_QuestLog) == "table"
        and SafeCall(C_QuestLog.GetTitleForQuestID, questID)
        or nil
    title = NormalizeText(title)
    if title then
        return title
    end

    title = type(C_TaskQuest) == "table"
        and SafeCall(C_TaskQuest.GetQuestInfoByQuestID, questID)
        or nil
    return NormalizeText(title)
end

function NS.IsQuestInLog(questID)
    questID = NormalizeQuestID(questID)
    return questID and IsQuestInLog(questID) or false
end

function NS.IsQuestReadyForTurnIn(questID)
    questID = NormalizeQuestID(questID)
    return questID and IsQuestReadyForTurnIn(questID) or false
end

function NS.ResolveQuestActionTitle(questID, fallbackTitle)
    questID = NormalizeQuestID(questID)
    if not questID then
        return NormalizeText(fallbackTitle)
    end

    local title = NormalizeText(fallbackTitle) or NS.ResolveQuestTitle(questID)
    if not title then
        return nil
    end

    if IsQuestReadyForTurnIn(questID) then
        return QuoteQuestAction("Turn in", title)
    end
    if IsQuestInLog(questID) then
        return QuoteQuestAction("Complete", title)
    end
    return QuoteQuestAction("Accept", title)
end

function NS.ResolveQuestObjectiveText(questID, objectiveIndex)
    questID = NormalizeQuestID(questID)
    objectiveIndex = NormalizeObjectiveIndex(objectiveIndex)
    if not questID or not objectiveIndex then
        return nil
    end

    local objectives = GetQuestObjectives(questID)
    local objective = objectives and objectives[objectiveIndex] or nil
    if type(objective) ~= "table" then
        return nil
    end

    return NormalizeText(objective.text or rawget(objective, "description"))
end

function NS.ResolveFirstUnfinishedQuestObjectiveText(questID)
    questID = NormalizeQuestID(questID)
    if not questID then
        return nil
    end

    if IsQuestReadyForTurnIn(questID) then
        return "Ready to turn in"
    end

    if not IsQuestInLog(questID) then
        return nil
    end

    local objectives = GetQuestObjectives(questID)
    if type(objectives) ~= "table" then
        return nil
    end

    for _, objective in ipairs(objectives) do
        if type(objective) == "table" and objective.finished ~= true then
            local text = NormalizeText(objective.text or rawget(objective, "description"))
            if text then
                return text
            end
        end
    end
end
