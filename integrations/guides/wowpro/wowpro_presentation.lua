local NS = _G.AzerothWaypointNS
if not NS.IsWoWProLoaded() then return end

NS.Internal = NS.Internal or {}
NS.Internal.WoWProPresentation = NS.Internal.WoWProPresentation or {}

local M = NS.Internal.WoWProPresentation

local function SafeCall(fn, ...)
    if type(fn) ~= "function" then
        return nil
    end
    local ok, a, b, c = pcall(fn, ...)
    if ok then
        return a, b, c
    end
end

local function StripDisplayMarkup(value)
    value = value:gsub("|c%x%x%x%x%x%x%x%x", "")
    value = value:gsub("|r", "")
    value = value:gsub("|H.-|h(.-)|h", "%1")
    value = value:gsub("|T.-|t", "")
    value = value:gsub("|A.-|a", "")
    value = value:gsub("%[/?color[^%]]*%]", "")
    value = value:gsub("%[[%a]+=[^%]]*;?icon%]", "")
    value = value:gsub("||", "|")
    return value
end

local function NormalizeText(value)
    if type(value) ~= "string" then
        return nil
    end
    value = StripDisplayMarkup(value)
    value = value:gsub("%s+", " "):gsub("^%s+", ""):gsub("%s+$", "")
    if value == "" or value == "?" then
        return nil
    end
    return value
end

local function ExpandWoWProText(WoWPro, value)
    if type(value) ~= "string" then
        return nil
    end
    local expanded = type(WoWPro) == "table" and SafeCall(WoWPro.ExpandMarkup, value) or nil
    return NormalizeText(expanded or value)
end

local function GetRawField(WoWPro, field, stepIndex)
    local values = type(WoWPro) == "table" and type(WoWPro[field]) == "table" and WoWPro[field] or nil
    return values and values[stepIndex] or nil
end

local function GetTextField(WoWPro, field, stepIndex)
    return ExpandWoWProText(WoWPro, GetRawField(WoWPro, field, stepIndex))
end

local function NormalizeID(value)
    local id = tonumber(value)
    if id and id ~= 0 then
        id = math.abs(id)
        if id > 0 then
            return id
        end
    end
end

local function AddUnique(list, seen, value)
    local id = NormalizeID(value)
    if id and not seen[id] then
        seen[id] = true
        list[#list + 1] = id
    end
    return id
end

local function CollectQuestIDs(rawQID)
    local ids = {}
    local seen = {}
    if type(rawQID) == "number" then
        AddUnique(ids, seen, rawQID)
    elseif type(rawQID) == "string" and rawQID ~= "*" then
        for token in rawQID:gmatch("[^%^&]+") do
            AddUnique(ids, seen, token)
        end
    end
    return ids
end

local function IsQuestInWoWProLog(WoWPro, questID)
    return type(WoWPro) == "table"
        and type(WoWPro.QuestLog) == "table"
        and type(WoWPro.QuestLog[questID]) == "table"
end

local function SelectWoWProQuestInLog(WoWPro, rawQID)
    if type(WoWPro) ~= "table"
        or type(WoWPro.QIDInTable) ~= "function"
        or type(WoWPro.QuestLog) ~= "table"
    then
        return nil
    end
    local activeID = SafeCall(WoWPro.QIDInTable, WoWPro, rawQID, WoWPro.QuestLog)
    return NormalizeID(activeID)
end

local function SelectPrimaryQuestID(WoWPro, rawQID, questIDs)
    local activeID = SelectWoWProQuestInLog(WoWPro, rawQID)
    if activeID then
        return activeID, "wowproQuestLog"
    end

    for index = 1, #questIDs do
        local questID = questIDs[index]
        if IsQuestInWoWProLog(WoWPro, questID) then
            return questID, "wowproQuestLogFallback"
        end
    end

    if type(NS.IsQuestInLog) == "function" then
        for index = 1, #questIDs do
            local questID = questIDs[index]
            if NS.IsQuestInLog(questID) then
                return questID, "blizzardQuestLog"
            end
        end
    end

    return questIDs[1], questIDs[1] and "firstQuestID" or nil
end

local function ResolveQuestTitle(WoWPro, questID, fallbackTitle)
    questID = NormalizeID(questID)
    local questInfo = questID and IsQuestInWoWProLog(WoWPro, questID) and WoWPro.QuestLog[questID] or nil
    local title = NormalizeText(type(questInfo) == "table" and questInfo.title or nil)
    if title then
        return title, "wowproQuestLogTitle"
    end

    title = type(NS.ResolveQuestTitle) == "function" and NS.ResolveQuestTitle(questID) or nil
    title = NormalizeText(title)
    if title then
        return title, "blizzardQuestTitle"
    end

    title = NormalizeText(fallbackTitle)
    if title then
        return title, "fallbackStepTitle"
    end
end

local function QuoteQuestTitle(action, title)
    title = NormalizeText(title)
    if not title then
        return nil
    end
    return action .. " '" .. title .. "'"
end

local function SplitSemicolonList(value)
    local list = {}
    if type(value) ~= "string" then
        return list
    end
    for token in value:gmatch("[^;]+") do
        local normalized = NormalizeText(token)
        if normalized then
            list[#list + 1] = normalized
        end
    end
    return list
end

local function JoinLines(lines)
    local out = {}
    local seen = {}
    for index = 1, #lines do
        local line = NormalizeText(lines[index])
        if line and not seen[line] then
            seen[line] = true
            out[#out + 1] = line
        end
    end
    if #out == 0 then
        return nil
    end
    return table.concat(out, "\n")
end

local function GetObjectiveIndexFromQO(qoText)
    local objective = type(qoText) == "string" and qoText:match("^(%d+)") or nil
    return NormalizeID(objective)
end

local function ResolveSpecificObjectiveText(questID, questText)
    local objectiveIndex = GetObjectiveIndexFromQO(questText)
    if objectiveIndex and type(NS.ResolveQuestObjectiveText) == "function" then
        local text = NS.ResolveQuestObjectiveText(questID, objectiveIndex)
        if NormalizeText(text) then
            return NormalizeText(text), "blizzardObjectiveText"
        end
    end
end

local function ResolveQOProgress(WoWPro, questID, rawQuestText)
    questID = NormalizeID(questID)
    if not questID or type(rawQuestText) ~= "string" then
        return nil
    end

    local lines = {}
    local entries = SplitSemicolonList(rawQuestText)
    for index = 1, #entries do
        local qoText = entries[index]
        if type(WoWPro.ValidObjective) ~= "function" or SafeCall(WoWPro.ValidObjective, qoText) then
            local _, status = SafeCall(WoWPro.QuestObjectiveStatus, questID, qoText)
            status = NormalizeText(status)
            if status and not status:find("^Unknown qid", 1, false) then
                lines[#lines + 1] = status
            end
        end
    end

    local text = JoinLines(lines)
    if text then
        return text, "wowproQOStatus"
    end
end

local function ResolveLeaderboardProgress(WoWPro, questID)
    questID = NormalizeID(questID)
    local questInfo = questID and IsQuestInWoWProLog(WoWPro, questID) and WoWPro.QuestLog[questID] or nil
    local leaderBoard = type(questInfo) == "table" and type(questInfo.leaderBoard) == "table" and questInfo.leaderBoard or nil
    if type(leaderBoard) ~= "table" then
        return nil
    end

    local completedInfo = type(questInfo) == "table" and rawget(questInfo, "ocompleted") or nil
    local completed = type(completedInfo) == "table" and completedInfo or nil
    local lines = {}
    for index = 1, #leaderBoard do
        if leaderBoard[index] and not (completed and completed[index]) then
            lines[#lines + 1] = leaderBoard[index]
        end
    end

    local text = JoinLines(lines)
    if text then
        return text, "wowproLeaderBoard"
    end
end

local function ResolveBlizzardProgress(questID)
    if type(NS.ResolveFirstUnfinishedQuestObjectiveText) ~= "function" then
        return nil
    end
    local text = NS.ResolveFirstUnfinishedQuestObjectiveText(questID)
    if NormalizeText(text) then
        return NormalizeText(text), "blizzardFirstUnfinishedObjective"
    end
end

local function ResolveProgressSubtext(WoWPro, questID, rawQuestText)
    local text, source = ResolveQOProgress(WoWPro, questID, rawQuestText)
    if text then
        return text, source
    end

    text, source = ResolveLeaderboardProgress(WoWPro, questID)
    if text then
        return text, source
    end

    return ResolveBlizzardProgress(questID)
end

local function ResolveObjectiveTitle(WoWPro, questID, rawQuestText)
    local entries = SplitSemicolonList(rawQuestText)
    for index = 1, #entries do
        local text, source = ResolveSpecificObjectiveText(questID, entries[index])
        if text then
            return text, source
        end
    end

    local progressText, progressSource = ResolveQOProgress(WoWPro, questID, rawQuestText)
    if progressText then
        return progressText, progressSource
    end
end

local function GetActionLabel(WoWPro, action)
    if type(WoWPro) == "table" and type(WoWPro.actionlabels) == "table" then
        return NormalizeText(WoWPro.actionlabels[action])
    end
end

local function BuildLabelTitle(label, stepText)
    label = NormalizeText(label)
    stepText = NormalizeText(stepText)
    if label and stepText then
        local lowerStep = stepText:lower()
        local lowerLabel = label:lower()
        if lowerStep == lowerLabel or lowerStep:sub(1, #lowerLabel) == lowerLabel then
            return stepText
        end
        return label .. " " .. stepText
    end
    return stepText or label
end

function M.ResolveStep(WoWPro, stepIndex)
    if type(WoWPro) ~= "table" or type(stepIndex) ~= "number" then
        return nil
    end

    local action = NormalizeText(GetRawField(WoWPro, "action", stepIndex))
    local rawStep = GetRawField(WoWPro, "step", stepIndex)
    local rawNote = GetRawField(WoWPro, "note", stepIndex)
    local rawQuestText = GetRawField(WoWPro, "questtext", stepIndex)
    local rawQID = GetRawField(WoWPro, "QID", stepIndex)

    local stepText = GetTextField(WoWPro, "step", stepIndex)
    local noteText = GetTextField(WoWPro, "note", stepIndex)
    local questIDs = CollectQuestIDs(rawQID)
    local primaryQuestID, primaryQuestSource = SelectPrimaryQuestID(WoWPro, rawQID, questIDs)
    local questTitle, questTitleSource = ResolveQuestTitle(WoWPro, primaryQuestID, stepText)
    local progressText, progressSource = ResolveProgressSubtext(WoWPro, primaryQuestID, rawQuestText)
    local baseAction = action and action:sub(1, 1) or nil

    local title
    local titleSource
    local subtext
    local subtextSource

    if baseAction == "A" or action == "a" then
        title = QuoteQuestTitle("Accept", questTitle)
        titleSource = title and "acceptQuestTitle" or nil
        if not title then
            title = stepText and QuoteQuestTitle("Accept", stepText) or "Accept quest"
            titleSource = "acceptFallback"
        end
        subtext = noteText
        subtextSource = subtext and "note" or nil
    elseif action == "T" or action == "t" then
        title = QuoteQuestTitle("Turn in", questTitle)
        titleSource = title and "turninQuestTitle" or nil
        if not title then
            title = stepText and QuoteQuestTitle("Turn in", stepText) or "Turn in quest"
            titleSource = "turninFallback"
        end
        subtext = noteText
        subtextSource = subtext and "note" or nil
    elseif action == "C" then
        if noteText then
            title = noteText
            titleSource = "noteInstruction"
        else
            title, titleSource = ResolveObjectiveTitle(WoWPro, primaryQuestID, rawQuestText)
            if not title then
                title = QuoteQuestTitle("Complete", questTitle)
                titleSource = title and "completeQuestTitle" or nil
            end
            if not title then
                title = stepText or "Complete objective"
                titleSource = stepText and "stepText" or "completeFallback"
            end
        end
        subtext = progressText
        subtextSource = progressSource
    elseif action == "N" then
        title = stepText or noteText or "Note"
        titleSource = stepText and "stepText" or noteText and "note" or "noteFallback"
        if noteText and noteText ~= title then
            subtext = noteText
            subtextSource = "note"
        end
    else
        local label = GetActionLabel(WoWPro, action)
        title = BuildLabelTitle(label, stepText) or noteText or "WoWPro step"
        titleSource = label and stepText and "actionLabelStep" or stepText and "stepText" or noteText and "note" or "fallback"
        if noteText and noteText ~= title then
            subtext = noteText
            subtextSource = "note"
        end
        if not subtext and action == "K" then
            subtext = progressText
            subtextSource = progressSource
        end
    end

    title = NormalizeText(title) or "WoWPro step"
    subtext = NormalizeText(subtext)

    return {
        title = title,
        rawTitle = stepText or title,
        subtext = subtext,
        stepIndex = stepIndex,
        action = action,
        rawStep = NormalizeText(rawStep),
        rawNote = NormalizeText(rawNote),
        rawQuestText = NormalizeText(rawQuestText),
        questIDs = questIDs,
        primaryQuestID = primaryQuestID,
        primaryQuestSource = primaryQuestSource,
        questTitleSource = questTitleSource,
        titleSource = titleSource,
        subtextSource = subtextSource,
    }
end
