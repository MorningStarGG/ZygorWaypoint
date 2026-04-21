local NS = _G.ZygorWaypointNS

local M = NS.Internal.GuideResolver
local P = M.Private

local NormalizeText = P.NormalizeText
local Signature = P.Signature
local HasVisibleActionableQuestAction = P.HasVisibleActionableQuestAction
local IsCurrentGoalInstructionFact = P.IsCurrentGoalInstructionFact
local HasVisibleDialogOrQuestCluster = P.HasVisibleDialogOrQuestCluster
local IsHeaderFact = P.IsHeaderFact
local SelectInstructionNeighborSubtext = P.SelectInstructionNeighborSubtext
local IsInteractivePresentationFact = P.IsInteractivePresentationFact
local IsSameTargetFact = P.IsSameTargetFact
local SelectDetachedQuestPresentationFact = P.SelectDetachedQuestPresentationFact
local BuildQuestPresentationSnapshot = P.BuildQuestPresentationSnapshot
local ApplyRoutePresentationPolicy = P.ApplyRoutePresentationPolicy
local FindSameTargetFallbackSeedIndex = P.FindSameTargetFallbackSeedIndex
local SelectHeaderFact = P.SelectHeaderFact
local SelectObjectiveInteractionChainHeaders = P.SelectObjectiveInteractionChainHeaders
local GetCurrentGoalFact = P.GetCurrentGoalFact
local BuildSemanticInfo = P.BuildSemanticInfo
local DetectExplicitTravelTypeForSemantics = P.DetectExplicitTravelTypeForSemantics
local BuildSnapshot = P.BuildSnapshot
local IsQuestObjectiveHelperSeedFact = P.IsQuestObjectiveHelperSeedFact
local SelectQuestObjectiveHelperActionFact = P.SelectQuestObjectiveHelperActionFact
local SelectQuestObjectiveHelperClusterSetupSubtext = P.SelectQuestObjectiveHelperClusterSetupSubtext
local SelectQuestObjectiveInstructionSubtext = P.SelectQuestObjectiveInstructionSubtext
local SelectPassiveSubtextFallback = P.SelectPassiveSubtextFallback
local FindAnchorIndex = P.FindAnchorIndex
local FindNearestAnchorActionIndex = P.FindNearestAnchorActionIndex
local FindNearbyBridgedAnchorActionIndex = P.FindNearbyBridgedAnchorActionIndex
local ExpandActionBlock = P.ExpandActionBlock
local CollectActionFactsInBlock = P.CollectActionFactsInBlock
local IsQuestActionFact = P.IsQuestActionFact
local BuildLiveCurrentnessContext = P.BuildLiveCurrentnessContext
local GetFactTooltipOrText = P.GetFactTooltipOrText

-- ============================================================
-- Input preparation
-- ============================================================

local function IsScenarioNonActionableFact(fact)
    return type(fact) == "table"
        and (fact.action == "scenariogoal" or fact.action == "scenarioend")
        and fact.visible == true
        and fact.suppressed ~= true
        and fact.status == "incomplete"
        and type(fact.text) == "string"
        and fact.text ~= ""
end

-- Returns (mirrorTitle, subtext, reason) if currentFact is a scenario non-actionable
-- fact at the target location that owns presentation, or nil if it does not.
-- Scenario objectives can advance at one location while the live arrow title still
-- reflects the previously completed stage; mirrorTitle is always currentFact.text.
-- On the no-subtext path, only returns non-nil when text ~= rawArrowTitle to avoid
-- a no-op title rewrite.
local function ResolveScenarioNonActionable(currentFact, facts, rawArrowTitle, targetMapID, targetX, targetY, targetSig)
    if not IsScenarioNonActionableFact(currentFact) then
        return nil
    end
    if not IsSameTargetFact(currentFact, targetMapID, targetX, targetY, targetSig) then
        return nil
    end

    -- scenarioend: prefer passive subtext before objective instruction
    if currentFact.action == "scenarioend" then
        local passiveText, passiveReason = SelectPassiveSubtextFallback(
            facts, currentFact.index, currentFact.index, rawArrowTitle)
        if type(passiveText) == "string" and passiveText ~= "" then
            return currentFact.text, passiveText, passiveReason
        end
    end

    local instructionText, instructionReason = SelectQuestObjectiveInstructionSubtext(
        facts, currentFact.index, rawArrowTitle)
    if type(instructionText) == "string" and instructionText ~= "" then
        return currentFact.text, instructionText, instructionReason
    end

    -- scenariogoal: passive subtext falls through after instruction attempt
    if currentFact.action == "scenariogoal" then
        local passiveText, passiveReason = SelectPassiveSubtextFallback(
            facts, currentFact.index, currentFact.index, rawArrowTitle)
        if type(passiveText) == "string" and passiveText ~= "" then
            return currentFact.text, passiveText, passiveReason
        end
    end

    -- Title-only: only rewrite when the objective text differs from the raw title
    if currentFact.text ~= rawArrowTitle then
        return currentFact.text, nil, nil
    end

    return nil
end

local function GetDetachedQuestPresentationPriority(fact)
    if type(fact) ~= "table" then
        return math.huge
    end
    if fact.action == "turnin" then
        return 1
    end
    if fact.action == "accept" then
        return 2
    end
    if fact.action == "q" then
        return 3
    end
    return math.huge
end

local function BuildResolutionInput(context)
    context = type(context) == "table" and context or {}

    local rawArrowTitle = NormalizeText(context.rawArrowTitle) or " "
    local targetMapID = context.mapID
    local targetX = context.x
    local targetY = context.y
    local targetSig = context.sig
    if type(targetSig) ~= "string"
        and type(targetMapID) == "number"
        and type(targetX) == "number"
        and type(targetY) == "number"
    then
        targetSig = Signature(targetMapID, targetX, targetY)
    end

    return {
        facts = type(context.facts) == "table" and context.facts or {},
        currentGoalNum = context.currentGoalNum,
        rawArrowTitle = rawArrowTitle,
        mapID = targetMapID,
        x = targetX,
        y = targetY,
        sig = targetSig,
        liveCurrentness = type(context.liveCurrentness) == "table" and context.liveCurrentness or nil,
        context = {
            kind = context.kind,
            legKind = context.legKind,
            routeTravelType = context.routeTravelType,
            source = context.source,
        },
    }
end

local function EnsureLiveCurrentnessContext(input)
    if type(input) ~= "table" then
        return nil
    end

    if type(input.liveCurrentness) ~= "table" then
        input.liveCurrentness = BuildLiveCurrentnessContext(input.facts)
    end

    return input.liveCurrentness
end

local function DetectQuestFallbackTravelType(action, npcid, mapID, x, y, detailText)
    -- Quest fallback branches should only infer travel from the selected
    -- fallback action/text, not from an outer route title.
    return DetectExplicitTravelTypeForSemantics(action, nil, detailText, npcid, mapID, x, y)
end

-- ============================================================
-- Non-actionable resolution
-- ============================================================

local function ResolveNonActionable(input, debug)
    local facts = input.facts
    local rawArrowTitle = input.rawArrowTitle
    local targetMapID = input.mapID
    local targetX = input.x
    local targetY = input.y
    local targetSig = input.sig
    local context = input.context
    local currentGoalNum = input.currentGoalNum

    local hiddenOrCount = 0
    local hiddenFirstQuestID
    local hiddenFirstIndex
    local hiddenLastIndex
    for _, fact in ipairs(facts) do
        if IsQuestActionFact(fact) and not fact.visible
            and type(fact.orlogic) == "number"
            and type(fact.questid) == "number" and fact.questid > 0
        then
            hiddenOrCount = hiddenOrCount + 1
            hiddenFirstQuestID = hiddenFirstQuestID or fact.questid
            hiddenFirstIndex = hiddenFirstIndex or fact.index
            hiddenLastIndex = fact.index
        end
    end
    if hiddenOrCount >= 2 then
        local headerFact = SelectHeaderFact(facts, hiddenFirstIndex, hiddenLastIndex, true)
        local mirrorTitle = (headerFact and headerFact.text) or rawArrowTitle
        local snapshot = BuildSnapshot(
            rawArrowTitle,
            mirrorTitle,
            "Accept Available Quest",
            "alternate_or_choice",
            "alternate_generic_accept",
            headerFact,
            nil,
            BuildSemanticInfo("quest", nil, hiddenFirstQuestID)
        )
        ApplyRoutePresentationPolicy(snapshot, context, currentGoalNum, facts)
        debug.reason = "hidden_or_cluster"
        debug.blockStart = hiddenFirstIndex
        debug.blockEnd = hiddenLastIndex
        debug.snapshot = snapshot
        return snapshot, debug
    end

    local currentFact = GetCurrentGoalFact(currentGoalNum, facts)
    local allowCurrentGoalInstructionFallback = IsCurrentGoalInstructionFact(currentFact)
    if allowCurrentGoalInstructionFallback and context.kind == "route" then
        allowCurrentGoalInstructionFallback = not HasVisibleDialogOrQuestCluster(facts)
    end

    if allowCurrentGoalInstructionFallback
        and currentFact
        and currentFact.visible == true
        and currentFact.suppressed ~= true
        and currentFact.status == "incomplete"
        and not IsHeaderFact(currentFact)
        and (currentFact.tooltip ~= nil or currentFact.text ~= nil)
    then
        local instructionText = GetFactTooltipOrText(currentFact)
        if instructionText and instructionText ~= rawArrowTitle then
            local semanticInfo = BuildSemanticInfo(
                nil,
                IsCurrentGoalInstructionFact(currentFact)
                    and DetectExplicitTravelTypeForSemantics(currentFact.action, rawArrowTitle, instructionText, currentFact.npcid, currentFact.mapID, currentFact.x, currentFact.y),
                currentFact.questid
            )
            local snapshot = BuildSnapshot(
                rawArrowTitle,
                rawArrowTitle,
                instructionText,
                "non_actionable_fallback",
                "current_goal_instruction",
                nil,
                nil,
                semanticInfo
            )
            ApplyRoutePresentationPolicy(snapshot, context, currentGoalNum, facts)
            debug.reason = "current_goal_instruction"
            debug.snapshot = snapshot
            return snapshot, debug
        end

        if IsCurrentGoalInstructionFact(currentFact) then
            local neighborSubtext, neighborReason = SelectInstructionNeighborSubtext(
                facts,
                currentFact.index,
                rawArrowTitle
            )
            if neighborSubtext then
                local semanticInfo = BuildSemanticInfo(
                    nil,
                    DetectExplicitTravelTypeForSemantics(currentFact.action, rawArrowTitle, neighborSubtext, currentFact.npcid, currentFact.mapID, currentFact.x, currentFact.y),
                    currentFact.questid
                )
                local snapshot = BuildSnapshot(
                    rawArrowTitle,
                    rawArrowTitle,
                    neighborSubtext,
                    "non_actionable_fallback",
                    neighborReason,
                    nil,
                    nil,
                    semanticInfo
                )
                ApplyRoutePresentationPolicy(snapshot, context, currentGoalNum, facts)
                debug.reason = neighborReason
                debug.snapshot = snapshot
                return snapshot, debug
            end
        end
    end

    local currentPresentationFact = type(currentFact) == "table" and currentFact
    local currentPresentationIndex = currentPresentationFact and type(currentPresentationFact.index) == "number"
        and currentPresentationFact.index
        or nil
    local detachedPresentationFact = currentPresentationIndex
        and IsInteractivePresentationFact(currentPresentationFact)
        and IsSameTargetFact(currentPresentationFact, targetMapID, targetX, targetY, targetSig)
        and SelectDetachedQuestPresentationFact(
            facts,
            currentPresentationFact,
            rawArrowTitle,
            currentPresentationIndex,
            EnsureLiveCurrentnessContext(input)
        )
    if type(input.liveCurrentness) == "table" then
        debug.liveCurrentness = input.liveCurrentness
    end
    if type(detachedPresentationFact) == "table"
        and detachedPresentationFact.text
        and detachedPresentationFact.text ~= rawArrowTitle
    then
        debug.anchorGoalNum = currentPresentationIndex
        debug.blockStart = detachedPresentationFact.index
        debug.blockEnd = detachedPresentationFact.index
        debug.headerGoalNum = currentPresentationIndex
        local snapshot, metadata = BuildQuestPresentationSnapshot(
            rawArrowTitle,
            facts,
            { detachedPresentationFact },
            currentPresentationIndex,
            detachedPresentationFact.index,
            detachedPresentationFact.index,
            currentPresentationFact,
            currentPresentationFact,
            targetMapID,
            targetX,
            targetY,
            targetSig,
            input.liveCurrentness,
            detachedPresentationFact.text
        )
        ApplyRoutePresentationPolicy(snapshot, context, currentGoalNum, facts)
        debug.reason = "detached_quest_title_fallback"
        debug.snapshot = snapshot
        debug.liveEntries = metadata.liveEntries
        debug.liveCurrentness = input.liveCurrentness
        debug.liveMatchedReason = metadata.liveMatchedReason
        debug.headerGoalNum = metadata.headerFact and metadata.headerFact.index or debug.headerGoalNum
        debug.titleOwnerGoal = metadata.titleOwnerFact and metadata.titleOwnerFact.index or nil
        debug.titleOwnerReason = metadata.titleOwnerReason
        debug.headerContextGoal = metadata.headerFact and metadata.headerFact.index or nil
        debug.headerContextReason = metadata.headerReason
        return snapshot, debug
    end

    local fallbackSeedIndex = (
        IsScenarioNonActionableFact(currentFact)
        and currentFact.text ~= rawArrowTitle
        and IsSameTargetFact(currentFact, targetMapID, targetX, targetY, targetSig)
    )
        and currentFact.index
        or (
            type(targetMapID) == "number"
            and type(targetX) == "number"
            and type(targetY) == "number"
            and FindSameTargetFallbackSeedIndex(facts, rawArrowTitle, targetMapID, targetX, targetY, targetSig)
            or nil
        )
    debug.blockStart = fallbackSeedIndex
    debug.blockEnd = fallbackSeedIndex
    if type(fallbackSeedIndex) == "number" then
        local resolvedFallbackSeedIndex = fallbackSeedIndex
        local fallbackSeedFact = facts[resolvedFallbackSeedIndex]
        local interactionTitleFact, interactionSubtextFact
        if IsQuestObjectiveHelperSeedFact(fallbackSeedFact) then
            interactionTitleFact, interactionSubtextFact = SelectObjectiveInteractionChainHeaders(
                facts,
                resolvedFallbackSeedIndex,
                rawArrowTitle
            )
        end
        if type(interactionTitleFact) == "table"
            and type(interactionSubtextFact) == "table"
            and interactionTitleFact.text
            and interactionSubtextFact.text
        then
            debug.headerGoalNum = interactionTitleFact.index
            local semanticFact = GetCurrentGoalFact(currentGoalNum, facts) or fallbackSeedFact
            local semanticInfo = BuildSemanticInfo(
                nil,
                DetectExplicitTravelTypeForSemantics(
                    interactionTitleFact.action,
                    rawArrowTitle,
                    interactionSubtextFact.text,
                    interactionTitleFact.npcid,
                    interactionTitleFact.mapID,
                    interactionTitleFact.x,
                    interactionTitleFact.y
                ),
                semanticFact and semanticFact.questid
            )
            local snapshot = BuildSnapshot(
                rawArrowTitle,
                interactionTitleFact.text,
                interactionSubtextFact.text,
                "non_actionable_fallback",
                "non_actionable_interaction_chain_fallback",
                interactionTitleFact,
                nil,
                semanticInfo
            )
            ApplyRoutePresentationPolicy(snapshot, context, currentGoalNum, facts)
            debug.reason = "non_actionable_interaction_chain_fallback"
            debug.snapshot = snapshot
            return snapshot, debug
        end

        local headerFact = SelectHeaderFact(facts, resolvedFallbackSeedIndex, resolvedFallbackSeedIndex)
        debug.headerGoalNum = headerFact and headerFact.index
        if headerFact and headerFact.text and headerFact.text ~= rawArrowTitle then
            local semanticFact = GetCurrentGoalFact(currentGoalNum, facts) or headerFact
            local semanticInfo = BuildSemanticInfo(
                nil,
                DetectExplicitTravelTypeForSemantics(
                    semanticFact and semanticFact.action,
                    rawArrowTitle,
                    semanticFact and GetFactTooltipOrText(semanticFact) or headerFact.text,
                    semanticFact and semanticFact.npcid,
                    semanticFact and semanticFact.mapID,
                    semanticFact and semanticFact.x,
                    semanticFact and semanticFact.y
                ),
                semanticFact and semanticFact.questid
            )
            local snapshot = BuildSnapshot(
                rawArrowTitle,
                rawArrowTitle,
                headerFact.text,
                "non_actionable_fallback",
                "non_actionable_header_fallback",
                headerFact,
                nil,
                semanticInfo
            )
            ApplyRoutePresentationPolicy(snapshot, context, currentGoalNum, facts)
            debug.reason = "non_actionable_header_fallback"
            debug.snapshot = snapshot
            return snapshot, debug
        end

        local instructionSubtext, instructionReason
        if IsInteractivePresentationFact(fallbackSeedFact) then
            instructionSubtext, instructionReason = SelectInstructionNeighborSubtext(
                facts,
                resolvedFallbackSeedIndex,
                rawArrowTitle
            )
        end
        if instructionSubtext then
            local semanticFact = GetCurrentGoalFact(currentGoalNum, facts) or fallbackSeedFact
            local semanticInfo = BuildSemanticInfo(
                nil,
                DetectExplicitTravelTypeForSemantics(
                    semanticFact and semanticFact.action,
                    rawArrowTitle,
                    instructionSubtext,
                    semanticFact and semanticFact.npcid,
                    semanticFact and semanticFact.mapID,
                    semanticFact and semanticFact.x,
                    semanticFact and semanticFact.y
                ),
                semanticFact and semanticFact.questid
            )
            local snapshot = BuildSnapshot(
                rawArrowTitle,
                rawArrowTitle,
                instructionSubtext,
                "non_actionable_fallback",
                instructionReason,
                nil,
                nil,
                semanticInfo
            )
            ApplyRoutePresentationPolicy(snapshot, context, currentGoalNum, facts)
            debug.reason = instructionReason
            debug.snapshot = snapshot
            return snapshot, debug
        end

        local helperClusterSetupText, helperClusterSetupReason
        if IsQuestObjectiveHelperSeedFact(fallbackSeedFact) then
            helperClusterSetupText, helperClusterSetupReason = SelectQuestObjectiveHelperClusterSetupSubtext(
                facts,
                resolvedFallbackSeedIndex,
                rawArrowTitle
            )
        end
        if type(helperClusterSetupText) == "string" and helperClusterSetupText ~= "" then
            local semanticFact = GetCurrentGoalFact(currentGoalNum, facts) or fallbackSeedFact
            local semanticInfo = BuildSemanticInfo(
                nil,
                DetectQuestFallbackTravelType(
                    semanticFact and semanticFact.action,
                    semanticFact and semanticFact.npcid,
                    semanticFact and semanticFact.mapID,
                    semanticFact and semanticFact.x,
                    semanticFact and semanticFact.y,
                    helperClusterSetupText
                ),
                semanticFact and semanticFact.questid
            )
            local snapshot = BuildSnapshot(
                rawArrowTitle,
                rawArrowTitle,
                helperClusterSetupText,
                "non_actionable_fallback",
                helperClusterSetupReason,
                nil,
                nil,
                semanticInfo
            )
            ApplyRoutePresentationPolicy(snapshot, context, currentGoalNum, facts)
            debug.reason = helperClusterSetupReason
            debug.snapshot = snapshot
            return snapshot, debug
        end

        local helperActionFact = IsQuestObjectiveHelperSeedFact(fallbackSeedFact)
            and SelectQuestObjectiveHelperActionFact(facts, resolvedFallbackSeedIndex, rawArrowTitle)
        local helperActionText = helperActionFact and GetFactTooltipOrText(helperActionFact)
        if type(helperActionText) == "string" and helperActionText ~= "" then
            local semanticFact = GetCurrentGoalFact(currentGoalNum, facts) or fallbackSeedFact
            local semanticInfo = BuildSemanticInfo(
                nil,
                DetectQuestFallbackTravelType(
                    helperActionFact and helperActionFact.action,
                    helperActionFact and helperActionFact.npcid,
                    helperActionFact and helperActionFact.mapID,
                    helperActionFact and helperActionFact.x,
                    helperActionFact and helperActionFact.y,
                    helperActionText
                ),
                semanticFact and semanticFact.questid
            )
            local snapshot = BuildSnapshot(
                rawArrowTitle,
                rawArrowTitle,
                helperActionText,
                "non_actionable_fallback",
                "non_actionable_helper_action_fallback",
                nil,
                nil,
                semanticInfo
            )
            ApplyRoutePresentationPolicy(snapshot, context, currentGoalNum, facts)
            debug.reason = "non_actionable_helper_action_fallback"
            debug.snapshot = snapshot
            return snapshot, debug
        end

        local objectiveInstructionText, objectiveInstructionReason
        if IsQuestObjectiveHelperSeedFact(fallbackSeedFact) then
            objectiveInstructionText, objectiveInstructionReason = SelectQuestObjectiveInstructionSubtext(
                facts,
                resolvedFallbackSeedIndex,
                rawArrowTitle
            )
        end
        if objectiveInstructionReason == "non_actionable_objective_text_fallback"
            and type(objectiveInstructionText) == "string"
            and objectiveInstructionText ~= ""
        then
            local semanticFact = GetCurrentGoalFact(currentGoalNum, facts) or fallbackSeedFact
            local semanticInfo = BuildSemanticInfo(
                nil,
                DetectQuestFallbackTravelType(
                    semanticFact and semanticFact.action,
                    semanticFact and semanticFact.npcid,
                    semanticFact and semanticFact.mapID,
                    semanticFact and semanticFact.x,
                    semanticFact and semanticFact.y,
                    objectiveInstructionText
                ),
                semanticFact and semanticFact.questid
            )
            local snapshot = BuildSnapshot(
                rawArrowTitle,
                rawArrowTitle,
                objectiveInstructionText,
                "non_actionable_fallback",
                objectiveInstructionReason,
                nil,
                nil,
                semanticInfo
            )
            ApplyRoutePresentationPolicy(snapshot, context, currentGoalNum, facts)
            debug.reason = objectiveInstructionReason
            debug.snapshot = snapshot
            return snapshot, debug
        end

        local passiveText, passiveReason
        if IsQuestObjectiveHelperSeedFact(fallbackSeedFact) then
            passiveText, passiveReason = SelectPassiveSubtextFallback(
                facts,
                resolvedFallbackSeedIndex,
                resolvedFallbackSeedIndex,
                rawArrowTitle
            )
        end
        if type(passiveText) == "string" and passiveText ~= "" then
            local semanticFact = GetCurrentGoalFact(currentGoalNum, facts) or fallbackSeedFact
            local semanticInfo = BuildSemanticInfo(
                nil,
                DetectQuestFallbackTravelType(
                    semanticFact and semanticFact.action,
                    semanticFact and semanticFact.npcid,
                    semanticFact and semanticFact.mapID,
                    semanticFact and semanticFact.x,
                    semanticFact and semanticFact.y,
                    passiveText
                ),
                semanticFact and semanticFact.questid
            )
            local snapshot = BuildSnapshot(
                rawArrowTitle,
                rawArrowTitle,
                passiveText,
                "non_actionable_fallback",
                passiveReason,
                nil,
                nil,
                semanticInfo
            )
            ApplyRoutePresentationPolicy(snapshot, context, currentGoalNum, facts)
            debug.reason = passiveReason
            debug.snapshot = snapshot
            return snapshot, debug
        end

        if type(objectiveInstructionText) == "string" and objectiveInstructionText ~= "" then
            local semanticFact = GetCurrentGoalFact(currentGoalNum, facts) or fallbackSeedFact
            local semanticInfo = BuildSemanticInfo(
                nil,
                DetectQuestFallbackTravelType(
                    semanticFact and semanticFact.action,
                    semanticFact and semanticFact.npcid,
                    semanticFact and semanticFact.mapID,
                    semanticFact and semanticFact.x,
                    semanticFact and semanticFact.y,
                    objectiveInstructionText
                ),
                semanticFact and semanticFact.questid
            )
            local snapshot = BuildSnapshot(
                rawArrowTitle,
                rawArrowTitle,
                objectiveInstructionText,
                "non_actionable_fallback",
                objectiveInstructionReason,
                nil,
                nil,
                semanticInfo
            )
            ApplyRoutePresentationPolicy(snapshot, context, currentGoalNum, facts)
            debug.reason = objectiveInstructionReason
            debug.snapshot = snapshot
            return snapshot, debug
        end
    end

    local scenarioMirror, scenarioSubtext, scenarioReason = ResolveScenarioNonActionable(
        currentFact,
        facts,
        rawArrowTitle,
        targetMapID,
        targetX,
        targetY,
        targetSig
    )
    if type(scenarioMirror) == "string" then
        local snapshot = BuildSnapshot(
            rawArrowTitle,
            scenarioMirror,
            scenarioSubtext,
            "non_actionable_fallback",
            scenarioReason,
            nil,
            nil,
            BuildSemanticInfo("quest", nil, currentFact.questid)
        )
        ApplyRoutePresentationPolicy(snapshot, context, currentGoalNum, facts)
        debug.reason = scenarioReason or "current_goal_non_actionable_title"
        debug.snapshot = snapshot
        return snapshot, debug
    end

    debug.reason = "no_visible_actionable_goal"
    return nil, debug
end

-- ============================================================
-- Actionable resolution
-- ============================================================

local function ResolveActionable(input, debug)
    local facts = input.facts
    local rawArrowTitle = input.rawArrowTitle
    local targetMapID = input.mapID
    local targetX = input.x
    local targetY = input.y
    local targetSig = input.sig
    local context = input.context
    local currentGoalNum = input.currentGoalNum

    local anchorIndex = FindAnchorIndex(currentGoalNum, facts)
    debug.anchorGoalNum = anchorIndex
    if type(anchorIndex) ~= "number" then
        debug.reason = "no_anchor"
        return nil, debug
    end

    if type(targetMapID) ~= "number" or type(targetX) ~= "number" or type(targetY) ~= "number" then
        debug.reason = "no_target_coords"
        return nil, debug
    end

    local currentFact = GetCurrentGoalFact(currentGoalNum, facts)
    local seedIndex = FindNearestAnchorActionIndex(facts, anchorIndex, targetMapID, targetX, targetY, targetSig)
    if type(seedIndex) ~= "number" then
        seedIndex = FindNearbyBridgedAnchorActionIndex(facts, anchorIndex, targetMapID, targetX, targetY)
    end
    if type(seedIndex) ~= "number" then
        local liveCurrentness = EnsureLiveCurrentnessContext(input)
        debug.liveCurrentness = liveCurrentness
        local detachedActionFact = currentFact
            and IsInteractivePresentationFact(currentFact)
            and IsSameTargetFact(currentFact, targetMapID, targetX, targetY, targetSig)
            and SelectDetachedQuestPresentationFact(
                facts,
                currentFact,
                rawArrowTitle,
                anchorIndex,
                liveCurrentness
            )
        local looseDetachedActionFact = currentFact
            and IsInteractivePresentationFact(currentFact)
            and IsSameTargetFact(currentFact, targetMapID, targetX, targetY, targetSig)
            and SelectDetachedQuestPresentationFact(
                facts,
                currentFact,
                rawArrowTitle,
                anchorIndex,
                liveCurrentness,
                { allowUnconfirmedTurnin = true }
            )
        if GetDetachedQuestPresentationPriority(looseDetachedActionFact)
            < GetDetachedQuestPresentationPriority(detachedActionFact)
        then
            detachedActionFact = looseDetachedActionFact
        end
        if type(detachedActionFact) == "table" and detachedActionFact.text and detachedActionFact.text ~= rawArrowTitle then
            debug.blockStart = detachedActionFact.index
            debug.blockEnd = detachedActionFact.index
            debug.headerGoalNum = currentFact and currentFact.index
            local snapshot, metadata = BuildQuestPresentationSnapshot(
                rawArrowTitle,
                facts,
                { detachedActionFact },
                anchorIndex,
                detachedActionFact.index,
                detachedActionFact.index,
                currentFact,
                currentFact,
                targetMapID,
                targetX,
                targetY,
                targetSig,
                liveCurrentness,
                detachedActionFact.text
            )
            ApplyRoutePresentationPolicy(snapshot, context, currentGoalNum, facts)
            debug.reason = "detached_quest_title_fallback"
            debug.snapshot = snapshot
            debug.liveEntries = metadata.liveEntries
            debug.liveCurrentness = liveCurrentness
            debug.liveMatchedReason = metadata.liveMatchedReason
            debug.headerGoalNum = metadata.headerFact and metadata.headerFact.index or debug.headerGoalNum
            debug.titleOwnerGoal = metadata.titleOwnerFact and metadata.titleOwnerFact.index or nil
            debug.titleOwnerReason = metadata.titleOwnerReason
            debug.headerContextGoal = metadata.headerFact and metadata.headerFact.index or nil
            debug.headerContextReason = metadata.headerReason
            return snapshot, debug
        end
        debug.reason = "no_same_target_action"
        return nil, debug
    end

    local blockStart, blockEnd = ExpandActionBlock(facts, seedIndex, targetMapID, targetX, targetY, targetSig)
    debug.blockStart = blockStart
    debug.blockEnd = blockEnd

    local actionFacts = CollectActionFactsInBlock(facts, blockStart, blockEnd)
    if #actionFacts == 0 then
        debug.reason = "empty_action_block"
        return nil, debug
    end

    local snapshot, metadata = BuildQuestPresentationSnapshot(
        rawArrowTitle,
        facts,
        actionFacts,
        anchorIndex,
        blockStart,
        blockEnd,
        nil,
        currentFact,
        targetMapID,
        targetX,
        targetY,
        targetSig,
        EnsureLiveCurrentnessContext(input),
        nil
    )
    debug.headerGoalNum = metadata.headerFact and metadata.headerFact.index
    debug.titleOwnerGoal = metadata.titleOwnerFact and metadata.titleOwnerFact.index or nil
    debug.titleOwnerReason = metadata.titleOwnerReason
    debug.headerContextGoal = metadata.headerFact and metadata.headerFact.index or nil
    debug.headerContextReason = metadata.headerReason
    debug.liveEntries = metadata.liveEntries
    debug.liveCurrentness = input.liveCurrentness
    debug.liveMatchedReason = metadata.liveMatchedReason
    ApplyRoutePresentationPolicy(snapshot, context, currentGoalNum, facts)
    debug.snapshot = snapshot
    return snapshot, debug
end

-- ============================================================
-- Entry point
-- ============================================================

local function ResolveFromFacts(context)
    local input = BuildResolutionInput(context)
    local facts = input.facts
    local debug = {
        rawArrowTitle = input.rawArrowTitle,
        facts = facts,
        step = nil,
        target = {
            kind = input.context.kind,
            legKind = input.context.legKind,
            routeTravelType = input.context.routeTravelType,
            source = input.context.source,
            mapID = input.mapID,
            x = input.x,
            y = input.y,
        },
        liveEntries = {},
        liveCurrentness = nil,
        liveMatchedReason = nil,
    }

    if not HasVisibleActionableQuestAction(facts) then
        return ResolveNonActionable(input, debug)
    end

    return ResolveActionable(input, debug)
end

-- ============================================================
-- Exports
-- ============================================================

P.ResolveFromFacts = ResolveFromFacts
M.ResolveFromFacts = ResolveFromFacts
