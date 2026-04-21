local NS = _G.ZygorWaypointNS

local M = NS.Internal.GuideResolver
local P = M.Private

local NormalizeText = P.NormalizeText
local IsQuestActionFact = P.IsQuestActionFact
local IsBridgeableCompletedQuestFact = P.IsBridgeableCompletedQuestFact
local SelectHeaderFact = P.SelectHeaderFact
local ResolveQuestHeaderContext = P.ResolveQuestHeaderContext

-- ============================================================
-- Action helpers
-- ============================================================

local function FindActionFactByIndex(actionFacts, factIndex)
    if type(actionFacts) ~= "table" or type(factIndex) ~= "number" then
        return nil
    end

    for _, fact in ipairs(actionFacts) do
        if type(fact) == "table" and fact.index == factIndex then
            return fact
        end
    end

    return nil
end

local function FindActionFactByText(actionFacts, titleText)
    if type(actionFacts) ~= "table" or type(titleText) ~= "string" or titleText == "" then
        return nil
    end

    for _, fact in ipairs(actionFacts) do
        if type(fact) == "table" and fact.text == titleText then
            return fact
        end
    end

    return nil
end

local function SelectPrimaryActionFact(actionFacts)
    return type(actionFacts) == "table" and actionFacts[1] or nil
end

local function SelectPrimaryActionFactText(actionFacts)
    local primaryFact = SelectPrimaryActionFact(actionFacts)
    local primaryText = primaryFact and NormalizeText(primaryFact.text)
    if type(primaryText) == "string" and primaryText ~= "" then
        return primaryText
    end
    return nil
end

local function ClusterIsAlternateOrChoice(actionFacts)
    if type(actionFacts) ~= "table" or #actionFacts < 2 then
        return false
    end

    for _, fact in ipairs(actionFacts) do
        if type(fact.orlogic) ~= "number" then
            return false
        end
    end

    return true
end

local function RawTitleMatchesBridgeableCompletedCorridor(rawArrowTitle, facts, blockStart, targetMapID, targetX, targetY, targetSig)
    if type(rawArrowTitle) ~= "string" or rawArrowTitle == "" then
        return false
    end

    local bridgedCompletedQuestCount = 0
    for i = (blockStart or 1) - 1, 1, -1 do
        local fact = facts[i]
        if fact and fact.visible == true and fact.suppressed ~= true then
            if not IsBridgeableCompletedQuestFact(facts, i, blockStart, targetMapID, targetX, targetY, targetSig) then
                return false
            end

            bridgedCompletedQuestCount = bridgedCompletedQuestCount + 1
            if bridgedCompletedQuestCount > 2 then
                return false
            end

            if fact.text == rawArrowTitle then
                return true
            end
        end
    end

    return false
end

-- ============================================================
-- Title ownership
-- ============================================================

local function BuildAlternateOrPresentationContext(rawArrowTitle, actionFacts, resolvedHeaderFact, currentGoalFact, mirrorTitleOverride)
    local titleText
    local titleOwnerReason

    if type(mirrorTitleOverride) == "string" and mirrorTitleOverride ~= "" then
        titleText = mirrorTitleOverride
        titleOwnerReason = "mirror_title_override"
    elseif type(resolvedHeaderFact) == "table" and type(resolvedHeaderFact.text) == "string" and resolvedHeaderFact.text ~= "" then
        titleText = resolvedHeaderFact.text
        titleOwnerReason = "alternate_header"
    else
        titleText = rawArrowTitle
        titleOwnerReason = "raw_arrow_title"
    end

    local titleOwnerFact = FindActionFactByText(actionFacts, titleText) or resolvedHeaderFact or SelectPrimaryActionFact(actionFacts)
    local semanticOwnerFact = titleOwnerFact ~= resolvedHeaderFact and titleOwnerFact
        or currentGoalFact
        or SelectPrimaryActionFact(actionFacts)

    return {
        clusterKind = "alternate_or_choice",
        titleText = titleText,
        titleOwnerFact = titleOwnerFact,
        titleOwnerReason = titleOwnerReason,
        headerFact = resolvedHeaderFact,
        headerReason = nil,
        semanticOwnerFact = semanticOwnerFact,
    }
end

local function BuildNormalQuestTitleOwner(rawArrowTitle, facts, actionFacts, currentGoalFact, blockStart, targetMapID, targetX, targetY, targetSig, mirrorTitleOverride)
    if type(mirrorTitleOverride) == "string" and mirrorTitleOverride ~= "" then
        local overrideOwner = FindActionFactByText(actionFacts, mirrorTitleOverride)
            or FindActionFactByIndex(actionFacts, type(currentGoalFact) == "table" and currentGoalFact.index or nil)
            or SelectPrimaryActionFact(actionFacts)
        return mirrorTitleOverride, overrideOwner, "mirror_title_override"
    end

    local currentActionFact = FindActionFactByIndex(actionFacts, type(currentGoalFact) == "table" and currentGoalFact.index or nil)
    if type(currentActionFact) == "table"
        and IsQuestActionFact(currentActionFact)
        and currentActionFact.status == "incomplete"
    then
        local currentTitle = NormalizeText(currentActionFact.text)
        if type(currentTitle) == "string" and currentTitle ~= "" then
            return currentTitle, currentActionFact, "current_actionable_fact"
        end
    end

    local matchingActionFact = FindActionFactByText(actionFacts, rawArrowTitle)
    if matchingActionFact then
        return rawArrowTitle, matchingActionFact, "action_fact_text_match"
    end

    local primaryActionFact = SelectPrimaryActionFact(actionFacts)
    local primaryText = SelectPrimaryActionFactText(actionFacts)
    if primaryActionFact and primaryText and primaryText ~= rawArrowTitle
        and RawTitleMatchesBridgeableCompletedCorridor(rawArrowTitle, facts, blockStart, targetMapID, targetX, targetY, targetSig)
    then
        return primaryText, primaryActionFact, "bridged_completed_corridor"
    end

    if primaryActionFact and primaryText then
        return primaryText, primaryActionFact, "primary_action_fallback"
    end

    return rawArrowTitle, currentActionFact or primaryActionFact, "raw_arrow_title"
end

local function BuildNormalQuestPresentationContext(rawArrowTitle, facts, actionFacts, blockStart, blockEnd, providedHeaderFact, currentGoalFact, targetMapID, targetX, targetY, targetSig, mirrorTitleOverride)
    local titleText, titleOwnerFact, titleOwnerReason = BuildNormalQuestTitleOwner(
        rawArrowTitle,
        facts,
        actionFacts,
        currentGoalFact,
        blockStart,
        targetMapID,
        targetX,
        targetY,
        targetSig,
        mirrorTitleOverride
    )

    local headerFact = nil
    local headerReason = nil
    if type(providedHeaderFact) == "table" then
        headerFact = providedHeaderFact
        if type(providedHeaderFact.text) == "string"
            and providedHeaderFact.text ~= ""
            and providedHeaderFact.text ~= titleText
        then
            headerReason = "context_header"
        end
    end

    if headerFact == nil or headerReason == nil then
        local resolvedHeaderFact, resolvedHeaderReason = ResolveQuestHeaderContext(
            facts,
            blockStart,
            blockEnd,
            titleText,
            targetMapID,
            targetX,
            targetY,
            targetSig,
            false
        )
        if resolvedHeaderFact ~= nil then
            headerFact = resolvedHeaderFact
        end
        if resolvedHeaderReason ~= nil then
            headerReason = resolvedHeaderReason
        end
    end

    return {
        clusterKind = "normal",
        titleText = titleText,
        titleOwnerFact = titleOwnerFact,
        titleOwnerReason = titleOwnerReason,
        headerFact = headerFact,
        headerReason = headerReason,
        semanticOwnerFact = titleOwnerFact or currentGoalFact or SelectPrimaryActionFact(actionFacts),
    }
end

-- ============================================================
-- Main presentation entry point
-- ============================================================

local function BuildQuestPresentationContext(rawArrowTitle, facts, actionFacts, blockStart, blockEnd, providedHeaderFact, currentGoalFact, targetMapID, targetX, targetY, targetSig, mirrorTitleOverride)
    if type(actionFacts) ~= "table" or #actionFacts == 0 then
        return nil
    end

    local allOr = ClusterIsAlternateOrChoice(actionFacts)
    local resolvedHeaderFact = providedHeaderFact
    if resolvedHeaderFact == nil then
        resolvedHeaderFact = SelectHeaderFact(facts, blockStart, blockEnd, allOr)
    end

    if allOr and resolvedHeaderFact then
        return BuildAlternateOrPresentationContext(
            rawArrowTitle,
            actionFacts,
            resolvedHeaderFact,
            currentGoalFact,
            mirrorTitleOverride
        )
    end

    return BuildNormalQuestPresentationContext(
        rawArrowTitle,
        facts,
        actionFacts,
        blockStart,
        blockEnd,
        providedHeaderFact,
        currentGoalFact,
        targetMapID,
        targetX,
        targetY,
        targetSig,
        mirrorTitleOverride
    )
end

-- ============================================================
-- Exports
-- ============================================================

P.BuildQuestPresentationContext = BuildQuestPresentationContext
