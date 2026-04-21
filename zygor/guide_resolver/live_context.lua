local NS = _G.ZygorWaypointNS

local M = NS.Internal.GuideResolver
local P = M.Private

local NormalizeText = P.NormalizeText
local IsQuestActionFact = P.IsQuestActionFact

-- ============================================================
-- Live dialog quest detection
-- ============================================================

local function CollectLiveDialogQuestEntries()
    local entries = {}
    local directEntries = {}
    local seenEntries = {}
    local seenDirectEntries = {}

    local function addEntry(target, seen, kind, questID, title, complete)
        title = NormalizeText(title)
        questID = tonumber(questID or 0)
        if not title and not questID then
            return
        end

        local key = table.concat({
            tostring(kind or ""),
            tostring(questID or ""),
            tostring(title or ""),
            tostring(complete == true),
        }, "|")
        if seen[key] then
            return
        end

        seen[key] = true
        target[#target + 1] = {
            kind = kind,
            questID = questID,
            title = title,
            isComplete = complete == true,
        }
    end

    if type(C_GossipInfo) == "table" then
        if type(C_GossipInfo.GetAvailableQuests) == "function" then
            local available = C_GossipInfo.GetAvailableQuests() or {}
            for _, info in ipairs(available) do
                addEntry(entries, seenEntries, "accept", info.questID, info.title, false)
            end
        end
        if type(C_GossipInfo.GetActiveQuests) == "function" then
            local active = C_GossipInfo.GetActiveQuests() or {}
            for _, info in ipairs(active) do
                addEntry(entries, seenEntries, "turnin", info.questID, info.title, info.isComplete)
            end
        end
    end

    if type(GetNumAvailableQuests) == "function" and type(GetAvailableTitle) == "function" then
        for i = 1, GetNumAvailableQuests() or 0 do
            local questID = nil
            if type(GetAvailableQuestInfo) == "function" then
                local _, _, _, _, infoQuestID = GetAvailableQuestInfo(i)
                questID = infoQuestID
            end
            addEntry(entries, seenEntries, "accept", questID, GetAvailableTitle(i), false)
        end
    end

    if type(GetNumActiveQuests) == "function" and type(GetActiveTitle) == "function" then
        for i = 1, GetNumActiveQuests() or 0 do
            local questID = nil
            if type(GetActiveQuestID) == "function" then
                questID = GetActiveQuestID(i)
            end
            addEntry(entries, seenEntries, "turnin", questID, GetActiveTitle(i), false)
        end
    end

    local questID = type(GetQuestID) == "function" and GetQuestID() or nil
    if type(questID) == "number" and questID > 0 then
        local title = nil
        local questInfoTitleHeader = rawget(_G, "QuestInfoTitleHeader")
        if questInfoTitleHeader and type(questInfoTitleHeader.GetText) == "function" then
            title = questInfoTitleHeader:GetText()
        end
        if not title and type(C_QuestLog) == "table" and type(C_QuestLog.GetTitleForQuestID) == "function" then
            title = C_QuestLog.GetTitleForQuestID(questID)
        end

        local kind = nil
        local questFrame = rawget(_G, "QuestFrame")
        local questFrameProgressPanel = rawget(_G, "QuestFrameProgressPanel")
        local questFrameRewardPanel = rawget(_G, "QuestFrameRewardPanel")
        local questFrameCompleteQuestButton = rawget(_G, "QuestFrameCompleteQuestButton")
        local questFrameCompleteButton = rawget(_G, "QuestFrameCompleteButton")
        local questFrameAcceptButton = rawget(_G, "QuestFrameAcceptButton")

        if questFrame and questFrame.DetailPanel and questFrame.DetailPanel:IsShown() then
            kind = "accept"
        elseif questFrameAcceptButton and questFrameAcceptButton:IsVisible() then
            kind = "accept"
        elseif (questFrameProgressPanel and questFrameProgressPanel:IsShown())
            or (questFrameRewardPanel and questFrameRewardPanel:IsShown())
            or (questFrameCompleteQuestButton and questFrameCompleteQuestButton:IsVisible())
            or (questFrameCompleteButton and questFrameCompleteButton:IsVisible())
        then
            kind = "turnin"
        end

        if kind == nil and type(C_QuestLog) == "table" and type(C_QuestLog.GetLogIndexForQuestID) == "function" then
            local logIndex = tonumber(C_QuestLog.GetLogIndexForQuestID(questID) or 0) or 0
            kind = logIndex > 0 and "turnin" or "accept"
        end

        if kind then
            local complete = false
            if kind == "turnin" and type(C_QuestLog) == "table" and type(C_QuestLog.IsComplete) == "function" then
                complete = C_QuestLog.IsComplete(questID) == true
            end
            addEntry(directEntries, seenDirectEntries, kind, questID, title, complete)
        end
    end

    for _, entry in ipairs(directEntries) do
        addEntry(entries, seenEntries, entry.kind, entry.questID, entry.title, entry.isComplete)
    end

    return entries, directEntries
end

-- ============================================================
-- Matching helpers
-- ============================================================

local function DoesLiveEntryMatchFact(fact, entry)
    if type(fact) ~= "table" or type(entry) ~= "table" or entry.kind ~= fact.action then
        return false
    end

    if fact.questid and entry.questID then
        return fact.questid == entry.questID
    end

    if (fact.questid == nil or entry.questID == nil)
        and fact.questTitle
        and entry.title
    then
        return fact.questTitle == entry.title
    end

    return false
end

local function MatchEntriesToFacts(actionFacts, liveEntries)
    local matches = {}
    local matchedByIndex = {}

    for _, fact in ipairs(actionFacts or {}) do
        for _, entry in ipairs(liveEntries or {}) do
            if DoesLiveEntryMatchFact(fact, entry) and not matchedByIndex[fact.index] then
                matchedByIndex[fact.index] = true
                matches[#matches + 1] = fact
            end
        end
    end

    if #matches == 1 then
        return matches[1], "unique"
    end

    if #matches > 1 then
        return nil, "ambiguous"
    end

    return nil, "none"
end

local function BuildFactAnnotation(fact, entries, directEntries)
    if type(fact) ~= "table"
        or fact.visible ~= true
        or fact.suppressed == true
        or not IsQuestActionFact(fact)
        or (fact.action ~= "accept" and fact.action ~= "turnin")
    then
        return nil
    end

    local questID = type(fact.questid) == "number" and fact.questid > 0 and fact.questid or nil
    local directMatch = select(1, MatchEntriesToFacts({ fact }, directEntries))
    local dialogMatch = directMatch or select(1, MatchEntriesToFacts({ fact }, entries))

    local annotation = {
        secondaryEligible = true,
        matchKind = nil,
        reason = nil,
    }

    if directMatch then
        annotation.matchKind = "direct_match"
    elseif dialogMatch then
        annotation.matchKind = "dialog_match"
    end

    if fact.action == "turnin" then
        if questID == nil then
            annotation.reason = "no_quest_id"
            return annotation
        end

        if annotation.matchKind then
            annotation.reason = annotation.matchKind
            return annotation
        end

        annotation.secondaryEligible = false
        annotation.reason = "turnin_not_offered"
        return annotation
    end

    if questID == nil then
        annotation.reason = "no_quest_id"
        return annotation
    end

    if type(C_QuestLog) == "table" and type(C_QuestLog.GetLogIndexForQuestID) == "function" then
        local logIndex = tonumber(C_QuestLog.GetLogIndexForQuestID(questID) or 0) or 0
        if logIndex > 0 then
            annotation.secondaryEligible = false
            annotation.reason = "accept_in_log"
            return annotation
        end
    end

    annotation.reason = annotation.matchKind or "accept_available"
    return annotation
end

local function BuildMatchCacheKey(actionFacts)
    local parts = {}
    for _, fact in ipairs(actionFacts or {}) do
        parts[#parts + 1] = tostring(type(fact) == "table" and fact.index or "?")
    end
    return table.concat(parts, ",")
end

-- ============================================================
-- Context
-- ============================================================

local function BuildLiveCurrentnessContext(facts)
    local entries, directEntries = CollectLiveDialogQuestEntries()
    local annotationsByIndex = {}

    for _, fact in ipairs(facts or {}) do
        local annotation = BuildFactAnnotation(fact, entries, directEntries)
        if annotation then
            annotationsByIndex[fact.index] = annotation
        end
    end

    return {
        entries = entries,
        directEntries = directEntries,
        annotationsByIndex = annotationsByIndex,
        matchedLiveFactIndex = nil,
        matchedLiveReason = nil,
        _matchCache = {},
    }
end

local function ResolveMatchedLiveFact(liveCurrentness, actionFacts)
    if type(liveCurrentness) ~= "table" then
        return nil, {}, nil
    end

    local cacheKey = BuildMatchCacheKey(actionFacts)
    local cached = liveCurrentness._matchCache[cacheKey]
    if cached == nil then
        local matchedFact, matchState = MatchEntriesToFacts(actionFacts, liveCurrentness.directEntries)
        local matchReason = nil

        if matchedFact then
            matchReason = "direct_match"
        elseif matchState == "ambiguous" then
            matchReason = "ambiguous_live_match"
        else
            matchedFact, matchState = MatchEntriesToFacts(actionFacts, liveCurrentness.entries)
            if matchedFact then
                matchReason = "dialog_match"
            elseif matchState == "ambiguous" then
                matchReason = "ambiguous_live_match"
            end
        end

        cached = {
            fact = matchedFact,
            reason = matchReason,
        }
        liveCurrentness._matchCache[cacheKey] = cached
    end

    liveCurrentness.matchedLiveFactIndex = cached.fact and cached.fact.index or nil
    liveCurrentness.matchedLiveReason = cached.reason
    return cached.fact, liveCurrentness.entries, cached.reason
end

-- ============================================================
-- Exports
-- ============================================================

P.BuildLiveCurrentnessContext = BuildLiveCurrentnessContext
P.ResolveMatchedLiveFact = ResolveMatchedLiveFact
