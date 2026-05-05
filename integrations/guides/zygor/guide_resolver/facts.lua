local NS = _G.AzerothWaypointNS
if not NS.IsZygorLoaded() then return end

local state = NS.State

-- ============================================================
-- State initialization
-- ============================================================

NS.Internal.GuideResolver = NS.Internal.GuideResolver or {}

local M = NS.Internal.GuideResolver
M.Private = M.Private or {}

local P = M.Private

state.guideResolver = state.guideResolver or {
    factsEpoch = 0,
    dialogEpoch = 0,
    factsCacheStep = nil,
    factsCacheEpoch = nil,
    factsCacheValue = nil,
    factsCacheStructureSig = nil,
    factsDirty = false,
    factsDirtyAll = false,
    factsDirtyReason = nil,
    factsDirtyQuestIDs = nil,
    factsDirtyQuestIDCount = 0,
    dialogDirty = false,
    dialogDirtyReason = nil,
    dialogDirtyCount = 0,
    dialogSignature = nil,
    snapshotCacheValue = nil,
    snapshotCacheDebug = nil,
    lastSnapshot = nil,
    lastDebug = nil,
}

local resolverState = state.guideResolver
resolverState.factsEpoch = tonumber(resolverState.factsEpoch) or 0
resolverState.dialogEpoch = tonumber(resolverState.dialogEpoch) or 0
resolverState.factsDirty = resolverState.factsDirty == true
resolverState.factsDirtyAll = resolverState.factsDirtyAll == true
resolverState.factsDirtyQuestIDCount = tonumber(resolverState.factsDirtyQuestIDCount) or 0
resolverState.dialogDirty = resolverState.dialogDirty == true
resolverState.dialogDirtyCount = tonumber(resolverState.dialogDirtyCount) or 0

local NormalizeWaypointTitle = NS.NormalizeWaypointTitle
local Signature = NS.Signature

-- ============================================================
-- Constants
-- ============================================================

local SAME_TARGET_TOLERANCE = 0.0025

local QUEST_ACTION_PRIORITY = {
    turnin = 1,
    accept = 2,
}

local HEADER_PRIORITY = {
    talk = 1,
    clicknpc = 2,
    gossip = 3,
}

local STRUCTURAL_ACTIONS = {
    ["goto"] = true,
    at = true,
    confirm = true,
    loadguide = true,
    mapmarker = true,
}

local QUEST_ACTIONS = {
    accept = true,
    turnin = true,
}

local CANONICAL_HANDOFF_ACTIONS = {
    accept = true,
    turnin = true,
    -- Scenario objective stages can behave like same-target handoff runs where
    -- the live arrow title lags one completed stage behind the next objective.
    scenariogoal = true,
}

local HEADER_ACTIONS = {
    talk = true,
    clicknpc = true,
    gossip = true,
}

local CURRENT_GOAL_INSTRUCTION_ACTIONS = {
    ["goto"] = true,
    at = true,
    confirm = true,
    invehicle = true,
}

-- ============================================================
-- Goal field access
-- ============================================================

local normalizeTextCacheIn = nil
local normalizeTextCacheOut = nil

local function NormalizeText(value)
    if value == normalizeTextCacheIn then
        return normalizeTextCacheOut
    end

    local result = NormalizeWaypointTitle(value)
    normalizeTextCacheIn = value
    normalizeTextCacheOut = result
    return result
end

local function SanitizeGoalTooltipTemplateText(value)
    if type(value) ~= "string" or value == "" then
        return value
    end

    -- Zygor can expose raw tooltip templates like "Slay #10# enemies" even
    -- while the live title/text has already resolved the numeric placeholder.
    -- This cleans them up and makes them usable where needed.
    return (value:gsub("#([^#\r\n]+)#", "%1"))
end

local function GetFactTooltipText(fact)
    if type(fact) ~= "table" then
        return nil
    end

    local tooltip = fact.tooltip
    if type(tooltip) ~= "string" or tooltip == "" then
        return nil
    end

    return SanitizeGoalTooltipTemplateText(tooltip)
end

local function GetFactTooltipOrText(fact)
    local tooltip = GetFactTooltipText(fact)
    if tooltip ~= nil then
        return tooltip
    end

    if type(fact) ~= "table" then
        return nil
    end

    local text = fact.text
    if type(text) ~= "string" or text == "" then
        return nil
    end

    return text
end

local function FormatCoordinateSubtext(x, y)
    if type(x) ~= "number" or type(y) ~= "number" then
        return nil
    end

    return string.format("x: %.1f, y: %.1f", x * 100, y * 100)
end

local function GetGoalAction(goal)
    if type(goal) ~= "table" then
        return nil
    end

    return type(goal.action) == "string" and goal.action or nil
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
        return true
    end

    return visible ~= false
end

local function GetGoalStatus(goal, visible)
    if type(goal) == "table" and type(goal.GetStatus) == "function" then
        local ok, status = pcall(goal.GetStatus, goal)
        if ok and type(status) == "string" and status ~= "" then
            return status
        end
    end

    if visible == false then
        return "hidden"
    end

    if type(goal) == "table"
        and type(goal.IsCompleteable) == "function"
        and goal:IsCompleteable()
        and type(goal.IsComplete) == "function"
    then
        local ok, complete = pcall(goal.IsComplete, goal)
        if ok then
            return complete and "complete" or "incomplete"
        end
    end

    return "passive"
end

local function GetGoalQuestID(goal)
    if type(goal) ~= "table" then
        return nil
    end

    return tonumber(goal.questid or (goal.quest and (goal.quest.id or goal.quest.questid)) or 0) or nil
end

local function GetGoalQuestTitle(goal)
    if type(goal) ~= "table" then
        return nil
    end

    return NormalizeText((goal.quest and (goal.quest.title or goal.quest.name)) or goal.title)
end

local function GetGoalNPCID(goal)
    if type(goal) ~= "table" then
        return nil
    end

    return tonumber(goal.useid or goal.npcid or goal.targetid or 0) or nil
end

local function GetGoalCoords(goal)
    if type(goal) ~= "table" then
        return nil, nil, nil
    end

    local mapID = goal.map or goal.mapid or goal.mapID
    local x = goal.x
    local y = goal.y
    if type(mapID) == "number" and type(x) == "number" and type(y) == "number" then
        return mapID, x, y
    end

    return nil, nil, nil
end

local function GetGoalText(goal)
    if type(goal) ~= "table" then
        return nil
    end

    if type(goal.GetText) == "function" then
        local ok, text = pcall(goal.GetText, goal)
        text = ok and NormalizeText(text) or nil
        if text then
            return text
        end

        ok, text = pcall(goal.GetText, goal, true, false, false)
        text = ok and NormalizeText(text) or nil
        if text then
            return text
        end
    end

    return NormalizeText(goal.text or goal.title or goal.header or goal.tooltip or (goal.quest and goal.quest.title))
end

local function GetGoalTooltipText(goal)
    if type(goal) ~= "table" then
        return nil
    end

    if goal.tooltip ~= nil then
        return NormalizeText(SanitizeGoalTooltipTemplateText(goal.tooltip))
    end

    return NormalizeText(goal.header or goal.text or goal.title)
end

-- ============================================================
-- Fact building
-- ============================================================

local _structureSigParts = {}

local function NormalizeRawStructureValue(value)
    if value == nil then
        return ""
    end
    return tostring(value)
end

local function GetRawGoalTextForStructure(goal)
    if type(goal) ~= "table" then
        return ""
    end

    local quest = type(goal.quest) == "table" and goal.quest or nil
    return NormalizeRawStructureValue(goal.text)
        .. "\030" .. NormalizeRawStructureValue(goal.title)
        .. "\030" .. NormalizeRawStructureValue(goal.header)
        .. "\030" .. NormalizeRawStructureValue(goal.tooltip)
        .. "\030" .. NormalizeRawStructureValue(quest and (quest.title or quest.name))
end

local function BuildStepStructureSignature(step)
    if type(step) ~= "table" or type(step.goals) ~= "table" then
        return ""
    end

    local goals = step.goals
    local n = 1
    _structureSigParts[n] = tostring(#goals)
    for i, goal in ipairs(goals) do
        local mapID = type(goal) == "table" and (goal.map or goal.mapid or goal.mapID) or nil
        n = n + 1; _structureSigParts[n] = tostring(i)
        n = n + 1; _structureSigParts[n] = NormalizeRawStructureValue(GetGoalAction(goal))
        n = n + 1; _structureSigParts[n] = NormalizeRawStructureValue(GetGoalQuestID(goal))
        n = n + 1; _structureSigParts[n] = NormalizeRawStructureValue(mapID)
        n = n + 1; _structureSigParts[n] = NormalizeRawStructureValue(type(goal) == "table" and goal.x or nil)
        n = n + 1; _structureSigParts[n] = NormalizeRawStructureValue(type(goal) == "table" and goal.y or nil)
        n = n + 1; _structureSigParts[n] = tostring(type(goal) == "table" and goal.force_noway == true)
        n = n + 1; _structureSigParts[n] = NormalizeRawStructureValue(type(goal) == "table" and goal.orlogic or nil)
        n = n + 1; _structureSigParts[n] = GetRawGoalTextForStructure(goal)
    end

    return table.concat(_structureSigParts, "\031", 1, n)
end

local function PopulateFact(fact, index, goal)
    fact.index = index
    fact.goal = goal

    local action = GetGoalAction(goal)
    local suppressed = (goal.force_noway == true) or action == "mapmarker"
    local visible = not suppressed and IsGoalVisible(goal)
    local status = GetGoalStatus(goal, visible)
    local mapID, x, y = GetGoalCoords(goal)
    local text = GetGoalText(goal)
    local tooltip = GetGoalTooltipText(goal)

    fact.action = action
    fact.visible = visible
    fact.status = status
    fact.questid = GetGoalQuestID(goal)
    fact.questTitle = GetGoalQuestTitle(goal)
    fact.npcid = GetGoalNPCID(goal)
    fact.orlogic = type(goal) == "table" and type(goal.orlogic) == "number" and goal.orlogic or nil
    fact.mapID = mapID
    fact.x = x
    fact.y = y
    fact.text = text
    fact.tooltip = tooltip
    fact.suppressed = suppressed
end

local function RefreshDynamicFactState(fact, goal)
    if type(fact) ~= "table" or type(goal) ~= "table" then
        return false
    end

    local action = GetGoalAction(goal)
    local suppressed = (goal.force_noway == true) or action == "mapmarker"
    local visible = not suppressed and IsGoalVisible(goal)
    local status = GetGoalStatus(goal, visible)
    local questid = GetGoalQuestID(goal)
    local changed = fact.goal ~= goal
        or fact.action ~= action
        or fact.suppressed ~= suppressed
        or fact.visible ~= visible
        or fact.status ~= status
        or fact.questid ~= questid
    fact.goal = goal
    fact.action = action
    fact.suppressed = suppressed
    fact.visible = visible
    fact.status = status
    fact.questid = questid
    return changed
end

local function BuildFacts(step, reuseFacts)
    local churn = state.churn
    if churn.active then
        churn.buildFacts = churn.buildFacts + 1
    end

    local facts = type(reuseFacts) == "table" and reuseFacts or {}
    if type(step) ~= "table" or type(step.goals) ~= "table" then
        for i = #facts, 1, -1 do
            facts[i] = nil
        end
        return facts
    end

    for i, goal in ipairs(step.goals) do
        local fact = facts[i]
        if type(fact) ~= "table" then
            fact = {}
            facts[i] = fact
        end
        PopulateFact(fact, i, goal)
    end
    for i = #step.goals + 1, #facts do
        facts[i] = nil
    end

    return facts
end

-- ============================================================
-- Cache
-- ============================================================

local snapshotCacheStep = nil
local snapshotCacheGoalNum = nil
local snapshotCacheSig = nil
local snapshotCacheMapID = nil
local snapshotCacheX = nil
local snapshotCacheY = nil
local snapshotCacheKind = nil
local snapshotCacheLegKind = nil
local snapshotCacheRouteTravelType = nil
local snapshotCacheTitle = nil
local snapshotCacheFactsEpoch = nil
local snapshotCacheDialogEpoch = nil
local snapshotCacheClearReason = nil

local function ClearSnapshotCache(reason)
    resolverState.snapshotCacheValue = nil
    resolverState.snapshotCacheDebug = nil
    snapshotCacheStep = nil
    snapshotCacheGoalNum = nil
    snapshotCacheSig = nil
    snapshotCacheMapID = nil
    snapshotCacheX = nil
    snapshotCacheY = nil
    snapshotCacheKind = nil
    snapshotCacheLegKind = nil
    snapshotCacheRouteTravelType = nil
    snapshotCacheTitle = nil
    snapshotCacheFactsEpoch = nil
    snapshotCacheDialogEpoch = nil
    if reason ~= nil then
        snapshotCacheClearReason = reason
    elseif snapshotCacheClearReason == nil then
        snapshotCacheClearReason = "clear"
    end
end

local canonicalCacheStep = nil
local canonicalCacheRawGoalNum = nil
local canonicalCacheFactsEpoch = nil
local canonicalCacheResult = nil

local function ClearCanonicalCache()
    canonicalCacheStep = nil
    canonicalCacheRawGoalNum = nil
    canonicalCacheFactsEpoch = nil
    canonicalCacheResult = nil
end

local function ClearFactsDirtyState()
    resolverState.factsDirty = false
    resolverState.factsDirtyAll = false
    resolverState.factsDirtyReason = nil
    resolverState.factsDirtyQuestIDCount = 0
    local questIDs = resolverState.factsDirtyQuestIDs
    if type(questIDs) == "table" then
        for questID in pairs(questIDs) do
            questIDs[questID] = nil
        end
    end
end

local function ClearFactsCache()
    resolverState.factsCacheStep = nil
    resolverState.factsCacheEpoch = nil
    resolverState.factsCacheValue = nil
    resolverState.factsCacheStructureSig = nil
    ClearFactsDirtyState()
    ClearCanonicalCache()
end

local function GetGuideResolverCacheToken()
    return resolverState.factsEpoch, resolverState.dialogEpoch
end

local function BumpFactsEpoch()
    resolverState.factsEpoch = resolverState.factsEpoch + 1
    ClearCanonicalCache()
    ClearSnapshotCache("factsEpoch")
    return resolverState.factsEpoch
end

local function ClearDialogDirtyState()
    resolverState.dialogDirty = false
    resolverState.dialogDirtyReason = nil
    resolverState.dialogDirtyCount = 0
end

local function BumpDialogEpoch(dialogSignature)
    local churn = state.churn
    if churn.active then
        churn.invalidateDialog = churn.invalidateDialog + 1
    end

    resolverState.dialogEpoch = resolverState.dialogEpoch + 1
    resolverState.dialogSignature = dialogSignature
    ClearDialogDirtyState()
    ClearSnapshotCache("dialogEpoch")
    return resolverState.dialogEpoch
end

local function MarkGuideResolverFactsDirty(reason, questID)
    resolverState.factsDirty = true
    resolverState.factsDirtyReason = reason

    questID = tonumber(questID or 0)
    if type(questID) == "number" and questID > 0 then
        local questIDs = resolverState.factsDirtyQuestIDs
        if type(questIDs) ~= "table" then
            questIDs = {}
            resolverState.factsDirtyQuestIDs = questIDs
        end
        if not questIDs[questID] then
            questIDs[questID] = true
            resolverState.factsDirtyQuestIDCount = (resolverState.factsDirtyQuestIDCount or 0) + 1
        end
    else
        resolverState.factsDirtyAll = true
    end
end

local function MarkGuideResolverDialogDirty(reason)
    resolverState.dialogDirty = true
    resolverState.dialogDirtyReason = reason
    resolverState.dialogDirtyCount = (resolverState.dialogDirtyCount or 0) + 1
end

local function FlushGuideResolverDialogDirty()
    if resolverState.dialogDirty ~= true then
        return false
    end

    local dialogSignature = type(P.GetLiveDialogQuestSignature) == "function"
        and P.GetLiveDialogQuestSignature()
        or nil
    if dialogSignature ~= nil and dialogSignature == resolverState.dialogSignature then
        ClearDialogDirtyState()
        return false
    end

    BumpDialogEpoch(dialogSignature)
    return true
end

local function PrepareGuideResolverSnapshotCache()
    FlushGuideResolverDialogDirty()
end

local function IsDirtyRelevantToFacts(facts)
    if resolverState.factsDirtyAll == true then
        return true
    end

    if type(facts) ~= "table" then
        return true
    end

    local questIDs = resolverState.factsDirtyQuestIDs
    if type(questIDs) ~= "table" or (resolverState.factsDirtyQuestIDCount or 0) <= 0 then
        return true
    end

    for _, fact in ipairs(facts) do
        local questID = type(fact) == "table" and fact.questid or nil
        if type(questID) == "number" and questIDs[questID] then
            return true
        end
    end

    return false
end

local function CanReuseCachedGuideResolverResults()
    if resolverState.factsDirty ~= true then
        return true
    end

    local cachedFacts = resolverState.factsCacheValue
    if type(cachedFacts) ~= "table" then
        return false
    end

    if IsDirtyRelevantToFacts(cachedFacts) then
        return false
    end

    ClearFactsDirtyState()
    resolverState.factsCacheEpoch = resolverState.factsEpoch
    return true
end

local function RefreshCachedFactsDynamics(step, facts)
    local changed = false
    local goals = type(step) == "table" and step.goals or nil
    if type(goals) ~= "table" then
        return false
    end

    for i, goal in ipairs(goals) do
        if RefreshDynamicFactState(facts[i], goal) then
            changed = true
        end
    end

    return changed
end

local function InvalidateGuideResolverFactsState()
    local churn = state.churn
    if churn.active then
        churn.invalidateFacts = churn.invalidateFacts + 1
    end

    BumpFactsEpoch()
    ClearFactsCache()
    ClearSnapshotCache()
end

local function InvalidateGuideResolverDialogState()
    BumpDialogEpoch(nil)
end

local function GetCachedFacts(step)
    if type(step) ~= "table" or type(step.goals) ~= "table" then
        return {}
    end

    local factsEpoch = resolverState.factsEpoch
    local cachedFacts = resolverState.factsCacheValue
    local cacheMatchesStep = resolverState.factsCacheStep == step
        and type(cachedFacts) == "table"

    if cacheMatchesStep
        and resolverState.factsCacheEpoch == factsEpoch
        and resolverState.factsDirty ~= true
    then
        return cachedFacts
    end

    local structureSig = BuildStepStructureSignature(step)
    if cacheMatchesStep then
        if resolverState.factsDirty == true and not IsDirtyRelevantToFacts(cachedFacts) then
            ClearFactsDirtyState()
            resolverState.factsCacheEpoch = resolverState.factsEpoch
            return cachedFacts
        end

        if resolverState.factsCacheStructureSig == structureSig then
            local changed = resolverState.factsDirty == true
                and RefreshCachedFactsDynamics(step, cachedFacts)
                or false
            ClearFactsDirtyState()
            if changed then
                factsEpoch = BumpFactsEpoch()
            else
                factsEpoch = resolverState.factsEpoch
            end
            resolverState.factsCacheEpoch = factsEpoch
            return cachedFacts
        end

        factsEpoch = BumpFactsEpoch()
    end

    local facts = BuildFacts(step, cacheMatchesStep and cachedFacts or nil)
    resolverState.factsCacheStep = step
    resolverState.factsCacheEpoch = factsEpoch
    resolverState.factsCacheValue = facts
    resolverState.factsCacheStructureSig = structureSig
    ClearFactsDirtyState()
    return facts
end

-- ============================================================
-- Fact queries
-- ============================================================

local resolveCanonicalGuideGoal  -- forward declaration; defined after ExpandActionBlock

local function ResolveCurrentGoalNum(stepOrGoalNum)
    if type(stepOrGoalNum) == "table" then
        local canonical = resolveCanonicalGuideGoal(stepOrGoalNum)
        return canonical and canonical.canonicalGoalNum
    end

    if type(stepOrGoalNum) == "number" then
        return stepOrGoalNum
    end

    return nil
end

local function IsQuestActionFact(fact)
    return type(fact) == "table" and QUEST_ACTIONS[fact.action] == true
end

local function IsCanonicalHandoffFact(fact)
    return type(fact) == "table" and CANONICAL_HANDOFF_ACTIONS[fact.action] == true
end

local function IsHeaderFact(fact)
    return type(fact) == "table" and HEADER_ACTIONS[fact.action] == true
end

local function IsCurrentGoalInstructionFact(fact)
    return type(fact) == "table" and CURRENT_GOAL_INSTRUCTION_ACTIONS[fact.action] == true
end

local function IsActionableFact(fact)
    return type(fact) == "table"
        and fact.visible == true
        and fact.suppressed ~= true
        and fact.status == "incomplete"
end

local function IsStructuralBoundaryFact(fact)
    if type(fact) ~= "table" or fact.visible ~= true or fact.suppressed == true then
        return false
    end

    if STRUCTURAL_ACTIONS[fact.action] then
        return true
    end

    if fact.action and not IsQuestActionFact(fact) and not IsHeaderFact(fact) then
        return true
    end

    return false
end

local function IsGuidanceFact(fact)
    if type(fact) ~= "table" or fact.visible ~= true or fact.suppressed == true then
        return false
    end

    if fact.action ~= nil then
        return false
    end

    if fact.mapID or fact.x or fact.y then
        return false
    end

    return fact.tooltip ~= nil or fact.text ~= nil
end

local function IsInformationalTextFact(fact)
    if type(fact) ~= "table" or fact.visible ~= true or fact.suppressed == true then
        return false
    end

    if fact.action ~= "text" then
        return false
    end

    if fact.mapID or fact.x or fact.y then
        return false
    end

    return fact.tooltip ~= nil or fact.text ~= nil
end

local function IsSameTargetFact(fact, targetMapID, targetX, targetY, targetSig)
    if type(fact) ~= "table" then
        return false
    end

    local factMapID = fact.mapID
    local factX = fact.x
    local factY = fact.y
    if type(factMapID) ~= "number" or type(factX) ~= "number" or type(factY) ~= "number" then
        return false
    end

    if type(targetSig) == "string" then
        return Signature(factMapID, factX, factY) == targetSig
    end

    if type(targetMapID) ~= "number" or type(targetX) ~= "number" or type(targetY) ~= "number" then
        return false
    end

    return factMapID == targetMapID
        and math.abs(factX - targetX) <= SAME_TARGET_TOLERANCE
        and math.abs(factY - targetY) <= SAME_TARGET_TOLERANCE
end

local function IsWithinSameMapTargetTolerance(fact, targetMapID, targetX, targetY)
    if type(fact) ~= "table" then
        return false
    end

    local factMapID = fact.mapID
    local factX = fact.x
    local factY = fact.y
    return type(factMapID) == "number"
        and type(factX) == "number"
        and type(factY) == "number"
        and type(targetMapID) == "number"
        and type(targetX) == "number"
        and type(targetY) == "number"
        and factMapID == targetMapID
        and math.abs(factX - targetX) <= SAME_TARGET_TOLERANCE
        and math.abs(factY - targetY) <= SAME_TARGET_TOLERANCE
end

local function HasSharedActionBlockBridgeContext(facts, startIndex, endIndex, anchorIndex)
    if type(facts) ~= "table"
        or type(startIndex) ~= "number"
        or type(endIndex) ~= "number"
    then
        return false
    end

    if startIndex > endIndex then
        startIndex, endIndex = endIndex, startIndex
    end

    for i = startIndex + 1, endIndex - 1 do
        local fact = facts[i]
        if fact and fact.visible == true and fact.suppressed ~= true then
            if IsQuestActionFact(fact) or IsGuidanceFact(fact) or IsInformationalTextFact(fact) then
                -- Allow lightweight quest-run context between the bridged facts.
            else
                return false
            end
        end
    end

    local anchorFact = type(anchorIndex) == "number" and facts[anchorIndex] or nil
    if anchorFact
        and anchorFact.visible == true
        and anchorFact.suppressed ~= true
        and IsHeaderFact(anchorFact)
        and anchorIndex >= startIndex
        and anchorIndex <= endIndex
    then
        return true
    end

    for i = (startIndex or 1) - 1, 1, -1 do
        local fact = facts[i]
        if fact and fact.visible == true and fact.suppressed ~= true then
            if IsHeaderFact(fact) then
                return true
            end
            if IsGuidanceFact(fact) or IsInformationalTextFact(fact) then
                -- Allow lightweight context lines between the header and the quest block.
            elseif IsQuestActionFact(fact) and fact.status == "complete" then
                -- Allow completed quest facts between the header and the bridged run.
            else
                return false
            end
        end
    end

    return false
end

local function IsLocallyBridgedQuestFact(facts, factIndex, bridgeIndex, targetMapID, targetX, targetY, targetSig, anchorIndex, requiredStatus)
    local fact = type(facts) == "table" and facts[factIndex] or nil
    if not (fact
        and IsQuestActionFact(fact)
        and fact.visible == true
        and fact.suppressed ~= true
    ) then
        return false
    end

    if type(requiredStatus) == "string" and fact.status ~= requiredStatus then
        return false
    end

    local exactSameTarget = false
    if type(targetSig) == "string" then
        exactSameTarget = Signature(fact.mapID, fact.x, fact.y) == targetSig
    elseif type(targetMapID) == "number"
        and type(targetX) == "number"
        and type(targetY) == "number"
    then
        exactSameTarget = fact.mapID == targetMapID
            and fact.x == targetX
            and fact.y == targetY
    end

    if exactSameTarget then
        return true
    end

    if not IsWithinSameMapTargetTolerance(fact, targetMapID, targetX, targetY) then
        return false
    end

    if type(bridgeIndex) ~= "number" then
        return false
    end

    return HasSharedActionBlockBridgeContext(
        facts,
        math.min(factIndex, bridgeIndex),
        math.max(factIndex, bridgeIndex),
        anchorIndex
    )
end

local function CanBridgeNearbyActionBlockCandidate(facts, candidateIndex, blockStart, targetMapID, targetX, targetY, anchorIndex)
    return IsLocallyBridgedQuestFact(
        facts,
        candidateIndex,
        blockStart,
        targetMapID,
        targetX,
        targetY,
        nil,
        anchorIndex,
        "incomplete"
    )
end

local function IsBridgeableCompletedQuestFact(facts, factIndex, bridgeIndex, targetMapID, targetX, targetY, targetSig, anchorIndex)
    return IsLocallyBridgedQuestFact(
        facts,
        factIndex,
        bridgeIndex,
        targetMapID,
        targetX,
        targetY,
        targetSig,
        anchorIndex,
        "complete"
    )
end

local function HasVisibleActionableQuestAction(facts)
    for _, fact in ipairs(facts) do
        if IsQuestActionFact(fact) and IsActionableFact(fact) then
            return true
        end
    end

    return false
end

local function HasVisibleDialogOrQuestCluster(facts)
    for _, fact in ipairs(facts) do
        if type(fact) == "table" and fact.visible == true and fact.suppressed ~= true then
            if IsHeaderFact(fact) then
                return true
            end
            if IsQuestActionFact(fact) and fact.status == "incomplete" then
                return true
            end
        end
    end

    return false
end

local function FindAnchorIndex(stepOrGoalNum, facts)
    local currentGoalNum = ResolveCurrentGoalNum(stepOrGoalNum)
    if type(currentGoalNum) == "number" then
        local fact = facts[currentGoalNum]
        if fact and fact.visible == true and fact.suppressed ~= true then
            return currentGoalNum
        end
    end

    for _, fact in ipairs(facts) do
        if IsQuestActionFact(fact) and IsActionableFact(fact) then
            return fact.index
        end
    end

    return nil
end

local function FindNearestAnchorActionIndex(facts, anchorIndex, targetMapID, targetX, targetY, targetSig)
    local best
    local bestDistance
    for _, fact in ipairs(facts) do
        if IsQuestActionFact(fact)
            and IsActionableFact(fact)
            and IsSameTargetFact(fact, targetMapID, targetX, targetY, targetSig)
        then
            local distance = math.abs(fact.index - anchorIndex)
            if best == nil
                or distance < bestDistance
                or (distance == bestDistance and fact.index < best.index)
            then
                best = fact
                bestDistance = distance
            end
        end
    end

    return best and best.index or nil
end

local function FindNearbyBridgedAnchorActionIndex(facts, anchorIndex, targetMapID, targetX, targetY)
    local best
    local bestDistance
    for _, fact in ipairs(facts) do
        if IsQuestActionFact(fact)
            and IsActionableFact(fact)
            and CanBridgeNearbyActionBlockCandidate(
                facts,
                fact.index,
                anchorIndex,
                targetMapID,
                targetX,
                targetY,
                anchorIndex
            )
        then
            local distance = math.abs(fact.index - anchorIndex)
            if best == nil
                or distance < bestDistance
                or (distance == bestDistance and fact.index < best.index)
            then
                best = fact
                bestDistance = distance
            end
        end
    end

    return best and best.index or nil
end

local function ExpandActionBlock(facts, seedIndex, targetMapID, targetX, targetY, targetSig)
    local startIndex = seedIndex
    local endIndex = seedIndex

    while startIndex > 1 do
        local candidate = facts[startIndex - 1]
        local candidateIndex = startIndex - 1
        if candidate
            and IsQuestActionFact(candidate)
            and IsActionableFact(candidate)
            and (
                IsSameTargetFact(candidate, targetMapID, targetX, targetY, targetSig)
                or CanBridgeNearbyActionBlockCandidate(
                    facts,
                    candidateIndex,
                    startIndex,
                    targetMapID,
                    targetX,
                    targetY,
                    nil
                )
            )
        then
            startIndex = candidateIndex
        else
            break
        end
    end

    while endIndex < #facts do
        local candidate = facts[endIndex + 1]
        local candidateIndex = endIndex + 1
        if candidate
            and IsQuestActionFact(candidate)
            and IsActionableFact(candidate)
            and (
                IsSameTargetFact(candidate, targetMapID, targetX, targetY, targetSig)
                or CanBridgeNearbyActionBlockCandidate(
                    facts,
                    candidateIndex,
                    startIndex,
                    targetMapID,
                    targetX,
                    targetY,
                    nil
                )
            )
        then
            endIndex = candidateIndex
        else
            break
        end
    end

    return startIndex, endIndex
end

local function IsHandoffClusterCandidate(facts, candidateIndex, referenceIndex, targetMapID, targetX, targetY, requiredAction, requiredQuestID)
    local fact = type(facts) == "table" and facts[candidateIndex] or nil
    if not fact then return false end
    if not IsCanonicalHandoffFact(fact) then return false end
    if fact.visible ~= true or fact.suppressed == true then return false end
    if fact.orlogic ~= nil then return false end
    if type(requiredAction) == "string" and fact.action ~= requiredAction then return false end
    if requiredAction == "scenariogoal"
        and type(requiredQuestID) == "number"
        and requiredQuestID > 0
        and fact.questid ~= requiredQuestID
    then
        return false
    end
    if IsSameTargetFact(fact, targetMapID, targetX, targetY, nil) then
        return true
    end
    return IsWithinSameMapTargetTolerance(fact, targetMapID, targetX, targetY)
        and HasSharedActionBlockBridgeContext(
            facts,
            math.min(candidateIndex, referenceIndex),
            math.max(candidateIndex, referenceIndex)
        )
end

local function BuildCanonicalGoalResult(rawGoalNum, rawFact, canonicalGoalNum, canonicalFact, usedOverride, overrideReason, clusterStart, clusterEnd, firstIncompleteGoalNum)
    return {
        rawGoalNum             = rawGoalNum,
        canonicalGoalNum       = canonicalGoalNum,
        rawFact                = rawFact,
        canonicalFact          = canonicalFact,
        usedOverride           = usedOverride,
        overrideReason         = overrideReason,
        clusterStart           = clusterStart,
        clusterEnd             = clusterEnd,
        firstIncompleteGoalNum = firstIncompleteGoalNum,
    }
end

local function BuildCanonicalGoalPassthrough(rawGoalNum, rawFact, clusterStart, clusterEnd, firstIncompleteGoalNum)
    return BuildCanonicalGoalResult(
        rawGoalNum,
        rawFact,
        rawGoalNum,
        rawFact,
        false,
        nil,
        clusterStart ~= nil and clusterStart or rawGoalNum,
        clusterEnd ~= nil and clusterEnd or rawGoalNum,
        firstIncompleteGoalNum
    )
end

local function resolveCanonicalGoalFromFacts(facts, rawGoalNum)
    local rawFact = type(rawGoalNum) == "number" and type(facts) == "table" and facts[rawGoalNum] or nil

    if type(facts) ~= "table" then return BuildCanonicalGoalPassthrough(rawGoalNum, rawFact) end
    if type(rawGoalNum) ~= "number" then return BuildCanonicalGoalPassthrough(rawGoalNum, rawFact) end
    if not rawFact then return BuildCanonicalGoalPassthrough(rawGoalNum, rawFact) end
    if rawFact.visible ~= true then return BuildCanonicalGoalPassthrough(rawGoalNum, rawFact) end
    if rawFact.suppressed == true then return BuildCanonicalGoalPassthrough(rawGoalNum, rawFact) end
    if not IsCanonicalHandoffFact(rawFact) then return BuildCanonicalGoalPassthrough(rawGoalNum, rawFact) end
    if rawFact.orlogic ~= nil then return BuildCanonicalGoalPassthrough(rawGoalNum, rawFact) end
    if type(rawFact.mapID) ~= "number" or type(rawFact.x) ~= "number" or type(rawFact.y) ~= "number" then
        return BuildCanonicalGoalPassthrough(rawGoalNum, rawFact)
    end

    local clusterStart = rawGoalNum
    local clusterEnd   = rawGoalNum

    while clusterStart > 1
        and IsHandoffClusterCandidate(
            facts,
            clusterStart - 1,
            clusterStart,
            rawFact.mapID,
            rawFact.x,
            rawFact.y,
            rawFact.action,
            rawFact.questid
        )
    do
        clusterStart = clusterStart - 1
    end

    while clusterEnd < #facts
        and IsHandoffClusterCandidate(
            facts,
            clusterEnd + 1,
            clusterEnd,
            rawFact.mapID,
            rawFact.x,
            rawFact.y,
            rawFact.action,
            rawFact.questid
        )
    do
        clusterEnd = clusterEnd + 1
    end

    local clusterCount = 0
    for i = clusterStart, clusterEnd do
        local fact = facts[i]
        if fact and IsCanonicalHandoffFact(fact) and fact.visible == true and fact.suppressed ~= true then
            clusterCount = clusterCount + 1
        end
    end
    if clusterCount < 2 then return BuildCanonicalGoalPassthrough(rawGoalNum, rawFact, clusterStart, clusterEnd) end

    local firstIncompleteGoalNum
    local firstIncompleteFact
    for i = clusterStart, clusterEnd do
        local fact = facts[i]
        if fact
            and IsCanonicalHandoffFact(fact)
            and fact.visible == true
            and fact.suppressed ~= true
            and fact.status == "incomplete"
        then
            firstIncompleteGoalNum = i
            firstIncompleteFact = fact
            break
        end
    end

    if firstIncompleteGoalNum == nil then
        return BuildCanonicalGoalPassthrough(rawGoalNum, rawFact, clusterStart, clusterEnd)
    end

    if firstIncompleteGoalNum == rawGoalNum then
        return BuildCanonicalGoalPassthrough(rawGoalNum, rawFact, clusterStart, clusterEnd, firstIncompleteGoalNum)
    end

    return BuildCanonicalGoalResult(
        rawGoalNum,
        rawFact,
        firstIncompleteGoalNum,
        firstIncompleteFact,
        true,
        "same_target_handoff_first_incomplete",
        clusterStart,
        clusterEnd,
        firstIncompleteGoalNum
    )
end

resolveCanonicalGuideGoal = function(step)
    if type(step) ~= "table" or type(step.goals) ~= "table" then
        return nil
    end

    local rawGoalNum = step.current_waypoint_goal_num
    local factsEpoch = resolverState.factsEpoch
    if canonicalCacheStep == step
        and canonicalCacheRawGoalNum == rawGoalNum
        and canonicalCacheFactsEpoch == factsEpoch
        and CanReuseCachedGuideResolverResults()
    then
        return canonicalCacheResult
    end

    local facts = GetCachedFacts(step)
    local result = resolveCanonicalGoalFromFacts(facts, rawGoalNum)
    canonicalCacheStep = step
    canonicalCacheRawGoalNum = rawGoalNum
    canonicalCacheFactsEpoch = resolverState.factsEpoch
    canonicalCacheResult = result
    return result
end

local function CollectActionFactsInBlock(facts, startIndex, endIndex)
    local results = {}
    for i = startIndex, endIndex do
        local fact = facts[i]
        if IsQuestActionFact(fact) and IsActionableFact(fact) then
            results[#results + 1] = fact
        end
    end
    return results
end

local function FindSameTargetFallbackSeedIndex(facts, titleText, targetMapID, targetX, targetY, targetSig)
    local best
    for _, fact in ipairs(facts) do
        if fact
            and fact.visible == true
            and fact.suppressed ~= true
            and IsSameTargetFact(fact, targetMapID, targetX, targetY, targetSig)
        then
            if fact.text and fact.text == titleText then
                return fact.index
            end
            if best == nil then
                best = fact
            end
        end
    end

    return best and best.index or nil
end

local function GetCurrentGoalFact(stepOrGoalNum, facts)
    local currentGoalNum = ResolveCurrentGoalNum(stepOrGoalNum)
    if type(currentGoalNum) ~= "number" or type(facts) ~= "table" then
        return nil
    end

    return facts[currentGoalNum]
end

local function FirstQuestIDInFacts(facts)
    if type(facts) ~= "table" then
        return nil
    end

    for _, fact in ipairs(facts) do
        if type(fact.questid) == "number" and fact.questid > 0 then
            return fact.questid
        end
    end

    return nil
end

-- ============================================================
-- Snapshot cache key
-- ============================================================

local function MatchesSnapshotCacheKey(context, step, currentGoalNum, rawArrowTitle, targetMapID, targetX, targetY, targetSig)
    local factsEpoch, dialogEpoch = GetGuideResolverCacheToken()
    return step == snapshotCacheStep
        and currentGoalNum == snapshotCacheGoalNum
        and targetSig == snapshotCacheSig
        and targetMapID == snapshotCacheMapID
        and targetX == snapshotCacheX
        and targetY == snapshotCacheY
        and (context and context.kind or nil) == snapshotCacheKind
        and (context and context.legKind or nil) == snapshotCacheLegKind
        and (context and context.routeTravelType or nil) == snapshotCacheRouteTravelType
        and rawArrowTitle == snapshotCacheTitle
        and factsEpoch == snapshotCacheFactsEpoch
        and dialogEpoch == snapshotCacheDialogEpoch
end

local function IncrementChurnCounter(churn, key)
    churn[key] = (tonumber(churn[key]) or 0) + 1
end

local function CountSnapshotCacheMissReasons(churn, context, step, currentGoalNum, rawArrowTitle, targetMapID, targetX, targetY, targetSig)
    if type(churn) ~= "table" then
        return
    end

    local counted = false
    local function count(key)
        IncrementChurnCounter(churn, key)
        counted = true
    end

    if snapshotCacheFactsEpoch == nil
        and snapshotCacheDialogEpoch == nil
        and snapshotCacheStep == nil
        and snapshotCacheTitle == nil
    then
        if snapshotCacheClearReason == "factsEpoch" then
            count("resolveMissFactsEpoch")
        elseif snapshotCacheClearReason == "dialogEpoch" then
            count("resolveMissDialogEpoch")
        else
            count("resolveMissNoCache")
        end
        return
    end

    local factsEpoch, dialogEpoch = GetGuideResolverCacheToken()
    if factsEpoch ~= snapshotCacheFactsEpoch then count("resolveMissFactsEpoch") end
    if dialogEpoch ~= snapshotCacheDialogEpoch then count("resolveMissDialogEpoch") end
    if step ~= snapshotCacheStep then count("resolveMissStep") end
    if currentGoalNum ~= snapshotCacheGoalNum then count("resolveMissGoal") end
    if targetSig ~= snapshotCacheSig then count("resolveMissTargetSig") end
    if targetMapID ~= snapshotCacheMapID then count("resolveMissMap") end
    if targetX ~= snapshotCacheX or targetY ~= snapshotCacheY then count("resolveMissCoord") end
    if (context and context.kind or nil) ~= snapshotCacheKind then count("resolveMissKind") end
    if (context and context.legKind or nil) ~= snapshotCacheLegKind then count("resolveMissLegKind") end
    if (context and context.routeTravelType or nil) ~= snapshotCacheRouteTravelType then count("resolveMissRouteType") end
    if rawArrowTitle ~= snapshotCacheTitle then count("resolveMissTitle") end

    if not counted then
        count("resolveMissOther")
    end
end

local function StoreSnapshotCacheKey(context, step, currentGoalNum, rawArrowTitle, targetMapID, targetX, targetY, targetSig)
    local factsEpoch, dialogEpoch = GetGuideResolverCacheToken()
    snapshotCacheStep = step
    snapshotCacheGoalNum = currentGoalNum
    snapshotCacheSig = targetSig
    snapshotCacheMapID = targetMapID
    snapshotCacheX = targetX
    snapshotCacheY = targetY
    snapshotCacheKind = context and context.kind or nil
    snapshotCacheLegKind = context and context.legKind or nil
    snapshotCacheRouteTravelType = context and context.routeTravelType or nil
    snapshotCacheTitle = rawArrowTitle
    snapshotCacheFactsEpoch = factsEpoch
    snapshotCacheDialogEpoch = dialogEpoch
    snapshotCacheClearReason = nil
end

-- ============================================================
-- Exports
-- ============================================================

P.resolverState = resolverState
P.Signature = Signature
P.SAME_TARGET_TOLERANCE = SAME_TARGET_TOLERANCE
P.QUEST_ACTION_PRIORITY = QUEST_ACTION_PRIORITY
P.HEADER_PRIORITY = HEADER_PRIORITY
P.NormalizeText = NormalizeText
P.FormatCoordinateSubtext = FormatCoordinateSubtext
P.GetGoalAction = GetGoalAction
P.IsGoalVisible = IsGoalVisible
P.GetGoalStatus = GetGoalStatus
P.GetGoalQuestID = GetGoalQuestID
P.GetGoalQuestTitle = GetGoalQuestTitle
P.GetGoalNPCID = GetGoalNPCID
P.GetGoalCoords = GetGoalCoords
P.GetGoalText = GetGoalText
P.GetGoalTooltipText = GetGoalTooltipText
P.BuildFacts = BuildFacts
P.GetFactTooltipText = GetFactTooltipText
P.GetFactTooltipOrText = GetFactTooltipOrText
P.ClearSnapshotCache = ClearSnapshotCache
P.ClearFactsCache = ClearFactsCache
P.GetGuideResolverCacheToken = GetGuideResolverCacheToken
P.CanReuseCachedGuideResolverResults = CanReuseCachedGuideResolverResults
P.CountSnapshotCacheMissReasons = CountSnapshotCacheMissReasons
P.MarkGuideResolverFactsDirty = MarkGuideResolverFactsDirty
P.MarkGuideResolverDialogDirty = MarkGuideResolverDialogDirty
P.FlushGuideResolverDialogDirty = FlushGuideResolverDialogDirty
P.PrepareGuideResolverSnapshotCache = PrepareGuideResolverSnapshotCache
P.InvalidateGuideResolverFactsState = InvalidateGuideResolverFactsState
P.InvalidateGuideResolverDialogState = InvalidateGuideResolverDialogState
P.GetCachedFacts = GetCachedFacts
P.ResolveCurrentGoalNum = ResolveCurrentGoalNum
P.IsQuestActionFact = IsQuestActionFact
P.IsHeaderFact = IsHeaderFact
P.IsCurrentGoalInstructionFact = IsCurrentGoalInstructionFact
P.IsActionableFact = IsActionableFact
P.IsStructuralBoundaryFact = IsStructuralBoundaryFact
P.IsGuidanceFact = IsGuidanceFact
P.IsInformationalTextFact = IsInformationalTextFact
P.IsSameTargetFact = IsSameTargetFact
P.IsWithinSameMapTargetTolerance = IsWithinSameMapTargetTolerance
P.IsBridgeableCompletedQuestFact = IsBridgeableCompletedQuestFact
P.HasSharedActionBlockBridgeContext = HasSharedActionBlockBridgeContext
P.HasVisibleActionableQuestAction = HasVisibleActionableQuestAction
P.HasVisibleDialogOrQuestCluster = HasVisibleDialogOrQuestCluster
P.FindAnchorIndex = FindAnchorIndex
P.FindNearestAnchorActionIndex = FindNearestAnchorActionIndex
P.FindNearbyBridgedAnchorActionIndex = FindNearbyBridgedAnchorActionIndex
P.ExpandActionBlock = ExpandActionBlock
P.CollectActionFactsInBlock = CollectActionFactsInBlock
P.FindSameTargetFallbackSeedIndex = FindSameTargetFallbackSeedIndex
P.GetCurrentGoalFact = GetCurrentGoalFact
P.FirstQuestIDInFacts = FirstQuestIDInFacts
P.MatchesSnapshotCacheKey = MatchesSnapshotCacheKey
P.StoreSnapshotCacheKey = StoreSnapshotCacheKey
P.IsHandoffClusterCandidate = IsHandoffClusterCandidate
P.ResolveCanonicalGoalFromFacts = resolveCanonicalGoalFromFacts
P.ResolveCanonicalGuideGoal = resolveCanonicalGuideGoal

NS.ResolveCanonicalGuideGoal = resolveCanonicalGuideGoal
