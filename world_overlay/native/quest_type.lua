local NS = _G.ZygorWaypointNS
local M = NS.Internal.WorldOverlayNative

local QuestClassification = Enum.QuestClassification or {}
local QuestTag = Enum.QuestTag or {}

local _cachedQuestSubtypeQuestID, _cachedQuestSubtypeResult

local QUEST_CLASSIFICATION_FALLBACKS = {
    Important = 0,
    Legendary = 1,
    Campaign = 2,
    Calling = 3,
    Meta = 4,
    Recurring = 5,
    Questline = 6,
}

local QUEST_TAG_FALLBACKS = {
    Legendary = 83,
    Artifact = 107,
}

local WEEKLY_GUIDE_TITLE_PATTERNS = {
    "Weekly Quests",
    "Weeklies",
    "Weekly Pacts",
    "Event Weeklies",
}

local function GetEnumValueName(enumTable, value)
    if type(enumTable) ~= "table" or value == nil then
        return nil
    end

    for key, enumValue in pairs(enumTable) do
        if enumValue == value then
            return key
        end
    end

    return nil
end

local function GetFallbackValueName(fallbackTable, value)
    if type(fallbackTable) ~= "table" or value == nil then
        return nil
    end

    for key, fallbackValue in pairs(fallbackTable) do
        if fallbackValue == value then
            return key
        end
    end

    return nil
end

local function IsEnumValue(enumTable, value, key, fallbackTable)
    if value == nil or type(key) ~= "string" then
        return false
    end

    local enumValue = type(enumTable) == "table" and enumTable[key] or nil
    if enumValue ~= nil then
        return value == enumValue
    end

    local fallbackValue = type(fallbackTable) == "table" and fallbackTable[key] or nil
    return fallbackValue ~= nil and value == fallbackValue
end

local function NormalizeQuestLabel(value)
    if type(value) ~= "string" then
        return nil
    end

    value = value:lower():gsub("%s+", ""):gsub("[_%-%']", "")
    return value ~= "" and value or nil
end

local function IsQuestTagNameMatch(tagName, expectedName)
    return NormalizeQuestLabel(tagName) == NormalizeQuestLabel(expectedName)
end

local function GetQuestTagDetails(questID)
    if type(questID) ~= "number" or type(C_QuestLog) ~= "table" or type(C_QuestLog.GetQuestTagInfo) ~= "function" then
        return nil, nil, nil
    end

    local questTagInfo = C_QuestLog.GetQuestTagInfo(questID)
    if type(questTagInfo) ~= "table" then
        return nil, nil, nil
    end

    local questTagID = questTagInfo.tagID
    local questTagName = questTagInfo.tagName
    if type(questTagName) ~= "string" or questTagName == "" then
        questTagName = GetEnumValueName(QuestTag, questTagID) or GetFallbackValueName(QUEST_TAG_FALLBACKS, questTagID)
    end

    return questTagInfo, questTagID, questTagName
end

-- ============================================================
-- Quest subtype detection
-- ============================================================

local function IsCallingQuest(questID, classification)
    if type(questID) ~= "number" then
        return false
    end

    if C_QuestLog.IsQuestCalling and C_QuestLog.IsQuestCalling(questID) then
        return true
    end

    return IsEnumValue(QuestClassification, classification, "Calling", QUEST_CLASSIFICATION_FALLBACKS)
end

local function IsDailyQuestFromZygor(questID)
    local zgv = NS.ZGV()
    local dailyQuests = zgv and zgv.dailyQuests
    return type(dailyQuests) == "table" and dailyQuests[questID] == true or false
end

local function IsWeeklyGuideTitle(guideTitle)
    if type(guideTitle) ~= "string" or guideTitle == "" then
        return false
    end

    local path, title = guideTitle:match("^(.*)\\([^\\]+)$")
    local guidePath = path or guideTitle
    local guideLeafTitle = title or guideTitle
    local guideType = guidePath:match("^(.-)\\") or guidePath

    if guideType ~= "DAILIES" and guideType ~= "EVENTS" then
        return false
    end

    for _, pattern in ipairs(WEEKLY_GUIDE_TITLE_PATTERNS) do
        if guideLeafTitle:find(pattern, 1, true) then
            return true
        end
    end

    return false
end

local function IsWeeklyQuestFromZygor(questID)
    local zgv = NS.ZGV()
    local questDB = zgv and zgv.QuestDB
    local guideForQuest = questDB and questDB.GuideForQuest
    local guides = guideForQuest and guideForQuest[questID]
    if type(guides) ~= "table" then
        return false
    end

    for _, guideTitle in ipairs(guides) do
        if IsWeeklyGuideTitle(guideTitle) then
            return true
        end
    end

    return false
end

local function GetQuestSubtype(questID)
    if type(questID) ~= "number" then
        return nil
    end

    if questID == _cachedQuestSubtypeQuestID then
        return _cachedQuestSubtypeResult
    end

    local result
    if IsDailyQuestFromZygor(questID) then
        result = "Daily"
    elseif IsWeeklyQuestFromZygor(questID) then
        result = "Weekly"
    end

    _cachedQuestSubtypeQuestID = questID
    _cachedQuestSubtypeResult = result
    return result
end

-- ============================================================
-- Quest type resolution
-- ============================================================

local function ResolveQuestTypeDetails(questID)
    if type(questID) ~= "number" then
        return nil
    end

    local classification = C_QuestInfoSystem.GetQuestClassification and C_QuestInfoSystem.GetQuestClassification(questID)
    local _, questTagID, questTagName = GetQuestTagDetails(questID)
    local questType = C_QuestLog.GetQuestType and C_QuestLog.GetQuestType(questID) or nil
    local questTypeName = GetEnumValueName(QuestTag, questType) or GetFallbackValueName(QUEST_TAG_FALLBACKS, questType)
    if questTagName == nil then
        questTagName = questTypeName
    end
    local isCompleted = C_QuestLog.ReadyForTurnIn and C_QuestLog.ReadyForTurnIn(questID) or false
    local isActive = C_QuestLog.IsOnQuest and C_QuestLog.IsOnQuest(questID) or false
    local isRepeatable = C_QuestLog.IsRepeatableQuest and C_QuestLog.IsRepeatableQuest(questID) or false
    local statusPrefix = isCompleted and "Complete" or (isActive and "Incomplete" or "Available")

    -- Zygor remains authoritative for Daily/Weekly. Everything else prefers
    -- Blizzard quest metadata in a deterministic precedence order.
    local typeKey = "Default"
    local typeSource = "default"
    local subtype = GetQuestSubtype(questID)
    if subtype == "Daily" then
        typeKey = "Daily"
        typeSource = "zygor-daily"
    elseif subtype == "Weekly" then
        typeKey = "Weekly"
        typeSource = "zygor-weekly"
    elseif IsCallingQuest(questID, classification) then
        typeKey = "Calling"
        typeSource = C_QuestLog.IsQuestCalling and C_QuestLog.IsQuestCalling(questID)
            and "blizzard-calling"
            or "blizzard-classification"
    elseif IsEnumValue(QuestClassification, classification, "Important", QUEST_CLASSIFICATION_FALLBACKS) then
        typeKey = "Important"
        typeSource = "blizzard-classification"
    elseif IsEnumValue(QuestClassification, classification, "Campaign", QUEST_CLASSIFICATION_FALLBACKS) then
        typeKey = "Campaign"
        typeSource = "blizzard-classification"
    elseif IsEnumValue(QuestClassification, classification, "Questline", QUEST_CLASSIFICATION_FALLBACKS)
        or IsEnumValue(QuestTag, questType, "Questline", QUEST_TAG_FALLBACKS)
        or IsQuestTagNameMatch(questTagName, "Questline")
    then
        typeKey = "Questline"
        typeSource = IsEnumValue(QuestClassification, classification, "Questline", QUEST_CLASSIFICATION_FALLBACKS)
            and "blizzard-classification"
            or (questTagID ~= nil and "blizzard-tag-info" or "blizzard-quest-type")
    elseif IsEnumValue(QuestClassification, classification, "Legendary", QUEST_CLASSIFICATION_FALLBACKS)
        or IsEnumValue(QuestTag, questTagID, "Legendary", QUEST_TAG_FALLBACKS)
        or IsEnumValue(QuestTag, questType, "Legendary", QUEST_TAG_FALLBACKS)
        or IsQuestTagNameMatch(questTagName, "Legendary")
    then
        typeKey = "Legendary"
        typeSource = IsEnumValue(QuestClassification, classification, "Legendary", QUEST_CLASSIFICATION_FALLBACKS)
            and "blizzard-classification"
            or (questTagID ~= nil and "blizzard-tag-info" or "blizzard-quest-type")
    elseif IsEnumValue(QuestTag, questTagID, "Artifact", QUEST_TAG_FALLBACKS)
        or IsEnumValue(QuestTag, questType, "Artifact", QUEST_TAG_FALLBACKS)
        or IsQuestTagNameMatch(questTagName, "Artifact")
    then
        typeKey = "Artifact"
        typeSource = questTagID ~= nil and "blizzard-tag-info" or "blizzard-quest-type"
    elseif IsEnumValue(QuestClassification, classification, "Meta", QUEST_CLASSIFICATION_FALLBACKS) then
        typeKey = "Meta"
        typeSource = "blizzard-classification"
    elseif IsEnumValue(QuestClassification, classification, "Recurring", QUEST_CLASSIFICATION_FALLBACKS) then
        typeKey = "Recurring"
        typeSource = "blizzard-classification"
    elseif isRepeatable then
        typeKey = "Repeatable"
        typeSource = "blizzard-repeatable"
    end

    return {
        questID = questID,
        typeKey = typeKey,
        typeSource = typeSource,
        statusPrefix = statusPrefix,
        subtype = subtype,
        classification = classification,
        classificationName = GetEnumValueName(QuestClassification, classification)
            or GetFallbackValueName(QUEST_CLASSIFICATION_FALLBACKS, classification),
        questTagID = questTagID,
        questTagName = questTagName,
        questType = questType,
        questTypeName = questTypeName,
        isCompleted = isCompleted == true,
        isActive = isActive == true,
        isRepeatable = isRepeatable == true,
    }
end

local function ResolveQuestType(questID)
    local details = ResolveQuestTypeDetails(questID)
    if not details then
        return nil, nil
    end

    return details.typeKey, details.statusPrefix
end

M.ResolveQuestTypeDetails = ResolveQuestTypeDetails
M.ResolveQuestType = ResolveQuestType
