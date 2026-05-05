local NS = _G.AzerothWaypointNS
if not NS.IsZygorLoaded() then return end

local M = NS.Internal.GuideResolver
local P = M.Private

local FormatCoordinateSubtext = P.FormatCoordinateSubtext
local QUEST_ACTION_PRIORITY = P.QUEST_ACTION_PRIORITY
local HasVisibleDialogOrQuestCluster = P.HasVisibleDialogOrQuestCluster
local FindTrailingGuidanceTip = P.FindTrailingGuidanceTip
local SelectQuestObjectiveHelperActionFactForBlock = P.SelectQuestObjectiveHelperActionFactForBlock
local SelectPassiveSubtextFallback = P.SelectPassiveSubtextFallback
local FirstQuestIDInFacts = P.FirstQuestIDInFacts
local ResolveMatchedLiveFact = P.ResolveMatchedLiveFact
local BuildQuestPresentationContext = P.BuildQuestPresentationContext
local GetFactTooltipOrText = P.GetFactTooltipOrText

-- ============================================================
-- Live currentness helpers
-- ============================================================

local function GetLiveAnnotation(liveCurrentness, fact)
    if type(liveCurrentness) ~= "table" or type(fact) ~= "table" then
        return nil
    end

    local annotationsByIndex = liveCurrentness.annotationsByIndex
    if type(annotationsByIndex) ~= "table" then
        return nil
    end

    return annotationsByIndex[fact.index]
end

-- ============================================================
-- Secondary action fact selection
-- ============================================================

local function SelectSecondaryActionFact(actionFacts, titleText, anchorIndex, liveCurrentness, options)
    options = type(options) == "table" and options or nil
    local allowUnconfirmedTurnin = options and options.allowUnconfirmedTurnin == true
    local best
    local bestPriority
    local bestDistance

    for _, fact in ipairs(actionFacts) do
        local eligible = fact.text and fact.text ~= titleText
        if eligible and (fact.action == "turnin" or fact.action == "accept") then
            if allowUnconfirmedTurnin and fact.action == "turnin" then
                eligible = true
            else
                local annotation = GetLiveAnnotation(liveCurrentness, fact)
                eligible = annotation == nil or annotation.secondaryEligible ~= false
            end
        end

        if eligible then
            local priority = QUEST_ACTION_PRIORITY[fact.action] or math.huge
            local distance = math.abs((fact.index or 0) - (anchorIndex or 0))
            if best == nil
                or priority < bestPriority
                or (priority == bestPriority and distance < bestDistance)
                or (priority == bestPriority and distance == bestDistance and fact.index < best.index)
            then
                best = fact
                bestPriority = priority
                bestDistance = distance
            end
        end
    end

    return best
end

-- ============================================================
-- Semantic detection utilities
-- ============================================================

local function DetectExplicitTravelTypeForSemantics(action, rawArrowTitle, detailText, mapID, x, y)
    return NS.ClassifyTravelSemantics(action, mapID, x, y, rawArrowTitle, detailText)
end

-- ============================================================
-- Snapshot construction
-- ============================================================

local function BuildSemanticInfo(semanticKind, semanticTravelType, semanticQuestID)
    local resolvedQuestID = type(semanticQuestID) == "number" and semanticQuestID > 0 and semanticQuestID or nil
    local resolvedTravelType = type(semanticTravelType) == "string" and semanticTravelType or nil
    local resolvedKind = type(semanticKind) == "string" and semanticKind or nil

    if resolvedTravelType then
        resolvedKind = "travel"
    elseif resolvedQuestID and resolvedKind == nil then
        resolvedKind = "quest"
    end

    if resolvedKind == nil and resolvedTravelType == nil and resolvedQuestID == nil then
        return nil
    end

    return {
        semanticKind = resolvedKind,
        semanticTravelType = resolvedTravelType,
        semanticQuestID = resolvedQuestID,
    }
end

local _contentSigParts = {}

local function UpdateSnapshotContentSig(snapshot)
    if type(snapshot) ~= "table" then
        return
    end

    _contentSigParts[1] = tostring(snapshot.mirrorTitle or "")
    _contentSigParts[2] = tostring(snapshot.pinpointSubtext or "")
    _contentSigParts[3] = tostring(snapshot.clusterKind or "")
    _contentSigParts[4] = tostring(snapshot.subtextReason or "")
    _contentSigParts[5] = tostring(snapshot.semanticKind or "")
    _contentSigParts[6] = tostring(snapshot.semanticTravelType or "")
    _contentSigParts[7] = tostring(snapshot.semanticQuestID or "")
    snapshot.contentSig = table.concat(_contentSigParts, "\031", 1, 7)
end

local function BuildSnapshot(rawArrowTitle, mirrorTitle, pinpointSubtext, clusterKind, subtextReason, headerFact, matchedLiveGoalNum, semanticInfo)
    local snapshot = {
        rawArrowTitle = rawArrowTitle,
        mirrorTitle = mirrorTitle or rawArrowTitle,
        pinpointSubtext = pinpointSubtext,
        clusterKind = clusterKind,
        subtextReason = subtextReason,
        headerGoalNum = headerFact and headerFact.index,
        matchedLiveGoalNum = matchedLiveGoalNum,
        resolverBypassed = false,
        semanticKind = semanticInfo and semanticInfo.semanticKind,
        semanticTravelType = semanticInfo and semanticInfo.semanticTravelType,
        semanticQuestID = semanticInfo and semanticInfo.semanticQuestID,
    }
    UpdateSnapshotContentSig(snapshot)
    return snapshot
end

-- ============================================================
-- Subtext resolution
-- ============================================================

local function ResolveAlternateOrSubtext(facts, actionFacts, blockEnd, liveCurrentness)
    local liveFact, liveEntries = ResolveMatchedLiveFact(liveCurrentness, actionFacts)
    if liveFact and liveFact.text then
        return liveFact.text, "live_quest_match", liveFact.index, liveEntries
    end

    local liveEntriesOnly = liveEntries
    local firstAction = actionFacts[1]
    local allSameAction = true
    for i = 2, #actionFacts do
        if actionFacts[i].action ~= firstAction.action then
            allSameAction = false
            break
        end
    end

    if allSameAction and firstAction.action == "accept" then
        return "Accept Available Quest", "alternate_generic_accept", nil, liveEntriesOnly
    end
    if allSameAction and firstAction.action == "turnin" then
        return "Turn In Available Quest", "alternate_generic_turnin", nil, liveEntriesOnly
    end

    local trailingTip = FindTrailingGuidanceTip(facts, blockEnd)
    if trailingTip then
        return trailingTip, "alternate_tip", nil, liveEntriesOnly
    end

    return nil, nil, nil, liveEntriesOnly
end

local function ShouldPreferHeaderContextForNormalQuestSubtext(actionFacts)
    return type(actionFacts) == "table" and #actionFacts >= 2
end

local function ResolveNormalQuestSubtext(facts, actionFacts, anchorIndex, blockStart, blockEnd, presentationContext, targetMapID, targetX, targetY, targetSig, liveCurrentness)
    local mirrorTitle = presentationContext and presentationContext.titleText
    local resolvedHeaderFact = presentationContext and presentationContext.headerFact
    local headerReason = presentationContext and presentationContext.headerReason
    local preferHeaderContext = ShouldPreferHeaderContextForNormalQuestSubtext(actionFacts)
    local headerText = type(resolvedHeaderFact) == "table" and resolvedHeaderFact.text or nil

    if preferHeaderContext
        and type(headerText) == "string"
        and headerText ~= ""
        and headerText ~= mirrorTitle
        and type(headerReason) == "string"
    then
        return headerText, headerReason, resolvedHeaderFact
    end

    local secondaryFact = SelectSecondaryActionFact(actionFacts, mirrorTitle, anchorIndex, liveCurrentness)
    if secondaryFact and secondaryFact.text then
        return secondaryFact.text, "secondary_action", resolvedHeaderFact
    end

    if not preferHeaderContext
        and type(headerText) == "string"
        and headerText ~= ""
        and headerText ~= mirrorTitle
        and type(headerReason) == "string"
    then
        return headerText, headerReason, resolvedHeaderFact
    end

    local helperActionFact = SelectQuestObjectiveHelperActionFactForBlock(
        facts,
        blockStart,
        blockEnd,
        mirrorTitle,
        targetMapID,
        targetX,
        targetY,
        targetSig
    )
    local helperActionText = helperActionFact and GetFactTooltipOrText(helperActionFact)
    if type(helperActionText) == "string" and helperActionText ~= "" then
        return helperActionText, "actionable_helper_action_fallback", resolvedHeaderFact
    end

    local passiveText, passiveReason = SelectPassiveSubtextFallback(
        facts,
        blockStart,
        blockEnd,
        mirrorTitle
    )
    return passiveText, passiveReason, resolvedHeaderFact
end

-- ============================================================
-- Presentation fact helpers
-- ============================================================

local function ResolveSemanticQuestID(facts, actionFacts, semanticOwnerFact, currentGoalFact, matchedLiveGoalNum)
    local semanticQuestID = nil
    local matchedLiveFact = type(matchedLiveGoalNum) == "number" and type(facts) == "table" and facts[matchedLiveGoalNum] or nil
    if type(matchedLiveFact) == "table" then
        semanticQuestID = matchedLiveFact.questid
    end
    if type(semanticQuestID) ~= "number" or semanticQuestID <= 0 then
        semanticQuestID = semanticOwnerFact and semanticOwnerFact.questid
    end
    if type(semanticQuestID) ~= "number" or semanticQuestID <= 0 then
        semanticQuestID = currentGoalFact and currentGoalFact.questid
    end
    if type(semanticQuestID) ~= "number" or semanticQuestID <= 0 then
        semanticQuestID = FirstQuestIDInFacts(actionFacts)
    end
    return semanticQuestID
end

local function ResolveSemanticTravelType(semanticOwnerFact, mirrorTitle, pinpointSubtext)
    if type(semanticOwnerFact) ~= "table" then
        return nil
    end

    return DetectExplicitTravelTypeForSemantics(
        semanticOwnerFact.action,
        mirrorTitle,
        pinpointSubtext,
        semanticOwnerFact.mapID,
        semanticOwnerFact.x,
        semanticOwnerFact.y
    )
end

-- ============================================================
-- Main presentation entry point
-- ============================================================

local function BuildQuestPresentationSnapshot(rawArrowTitle, facts, actionFacts, anchorIndex, blockStart, blockEnd, headerFact, currentGoalFact, targetMapID, targetX, targetY, targetSig, liveCurrentness, mirrorTitleOverride)
    if type(actionFacts) ~= "table" or #actionFacts == 0 then
        return nil
    end

    local presentationContext = BuildQuestPresentationContext(
        rawArrowTitle,
        facts,
        actionFacts,
        blockStart,
        blockEnd,
        headerFact,
        currentGoalFact,
        targetMapID,
        targetX,
        targetY,
        targetSig,
        mirrorTitleOverride
    )
    if type(presentationContext) ~= "table" then
        return nil
    end

    local clusterKind = presentationContext.clusterKind or "normal"
    local mirrorTitle = presentationContext.titleText or mirrorTitleOverride or rawArrowTitle
    local resolvedHeaderFact = presentationContext.headerFact

    local pinpointSubtext
    local subtextReason
    local matchedLiveGoalNum
    local liveEntries = {}
    local liveMatchedReason = nil

    if clusterKind == "alternate_or_choice" then
        pinpointSubtext, subtextReason, matchedLiveGoalNum, liveEntries = ResolveAlternateOrSubtext(facts, actionFacts, blockEnd, liveCurrentness)
        if type(liveCurrentness) == "table" then
            liveMatchedReason = liveCurrentness.matchedLiveReason
        end
    else
        pinpointSubtext, subtextReason, resolvedHeaderFact = ResolveNormalQuestSubtext(
            facts,
            actionFacts,
            anchorIndex,
            blockStart,
            blockEnd,
            presentationContext,
            targetMapID,
            targetX,
            targetY,
            targetSig,
            liveCurrentness
        )
        if type(liveCurrentness) == "table" then
            liveEntries = liveCurrentness.entries or liveEntries
            liveMatchedReason = liveCurrentness.matchedLiveReason
        end
    end

    if not pinpointSubtext
        and NS.GetWorldOverlaySetting("worldOverlayShowCoordinateFallback")
    then
        pinpointSubtext = FormatCoordinateSubtext(targetX, targetY)
        if pinpointSubtext then
            subtextReason = "coordinate_fallback"
        end
    end

    local semanticQuestID = ResolveSemanticQuestID(
        facts,
        actionFacts,
        presentationContext.semanticOwnerFact,
        currentGoalFact,
        matchedLiveGoalNum
    )
    local semanticTravelType = ResolveSemanticTravelType(
        presentationContext.semanticOwnerFact,
        mirrorTitle,
        pinpointSubtext
    )
    local snapshot = BuildSnapshot(
        rawArrowTitle,
        mirrorTitle,
        pinpointSubtext,
        clusterKind,
        subtextReason,
        resolvedHeaderFact,
        matchedLiveGoalNum,
        BuildSemanticInfo("quest", semanticTravelType, semanticQuestID)
    )

    return snapshot, {
        headerFact = resolvedHeaderFact,
        headerReason = presentationContext.headerReason,
        titleOwnerFact = presentationContext.titleOwnerFact,
        titleOwnerReason = presentationContext.titleOwnerReason,
        semanticOwnerFact = presentationContext.semanticOwnerFact,
        liveEntries = liveEntries,
        matchedLiveGoalNum = matchedLiveGoalNum,
        liveMatchedReason = liveMatchedReason,
    }
end

-- ============================================================
-- Route presentation policy
-- ============================================================

local function IsFallbackRoutePresentationAllowed(snapshot, context, currentGoalNum, facts)
    if type(snapshot) ~= "table" or snapshot.clusterKind ~= "non_actionable_fallback" then
        return true
    end

    local hasDialogOrQuestCluster = HasVisibleDialogOrQuestCluster(facts)
    if snapshot.subtextReason == "non_actionable_header_fallback" then
        if type(context) == "table" and context.kind == "route" and context.legKind == "destination" then
            return true
        end
        return not hasDialogOrQuestCluster
    end

    return true
end

local function ApplyRoutePresentationPolicy(snapshot, context, currentGoalNum, facts)
    if type(snapshot) ~= "table" or type(context) ~= "table" or context.kind ~= "route" then
        return snapshot
    end

    local routeTravelType = type(context.routeTravelType) == "string" and context.routeTravelType or nil
    local snapshotTravelType = type(snapshot.semanticTravelType) == "string" and snapshot.semanticTravelType or nil

    if context.legKind == "carrier"
        and snapshotTravelType ~= nil
        and snapshot.rawArrowTitle
        and snapshot.mirrorTitle ~= snapshot.rawArrowTitle
    then
        snapshot.mirrorTitle = snapshot.rawArrowTitle
        UpdateSnapshotContentSig(snapshot)
    end

    if context.legKind == "carrier"
        and snapshot.pinpointSubtext ~= nil
        and not NS.IsInstanceRouteTravelType(routeTravelType)
        and (snapshotTravelType ~= nil or snapshot.semanticKind == "quest")
    then
        snapshot.pinpointSubtext = nil
        snapshot.subtextReason = "carrier_leg_suppressed"
        snapshot.routePresentationAllowed = false
        UpdateSnapshotContentSig(snapshot)
        return snapshot
    end

    if routeTravelType ~= nil then
        snapshot.semanticKind = "travel"
        snapshot.semanticTravelType = routeTravelType
        UpdateSnapshotContentSig(snapshot)
    end

    snapshot.routePresentationAllowed = IsFallbackRoutePresentationAllowed(snapshot, context, currentGoalNum, facts)
    return snapshot
end

-- ============================================================
-- Exports
-- ============================================================

P.SelectSecondaryActionFact = SelectSecondaryActionFact
P.DetectExplicitTravelTypeForSemantics = DetectExplicitTravelTypeForSemantics
P.BuildSemanticInfo = BuildSemanticInfo
P.UpdateSnapshotContentSig = UpdateSnapshotContentSig
P.BuildSnapshot = BuildSnapshot
P.BuildQuestPresentationSnapshot = BuildQuestPresentationSnapshot
P.IsFallbackRoutePresentationAllowed = IsFallbackRoutePresentationAllowed
P.ApplyRoutePresentationPolicy = ApplyRoutePresentationPolicy
