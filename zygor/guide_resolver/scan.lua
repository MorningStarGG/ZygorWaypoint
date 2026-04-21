local NS = _G.ZygorWaypointNS

local M = NS.Internal.GuideResolver
local P = M.Private

local HEADER_PRIORITY = P.HEADER_PRIORITY
local IsQuestActionFact = P.IsQuestActionFact
local IsHeaderFact = P.IsHeaderFact
local IsGuidanceFact = P.IsGuidanceFact
local IsInformationalTextFact = P.IsInformationalTextFact
local IsBridgeableCompletedQuestFact = P.IsBridgeableCompletedQuestFact
local IsSameTargetFact = P.IsSameTargetFact
local HasSharedActionBlockBridgeContext = P.HasSharedActionBlockBridgeContext
local GetFactTooltipOrText = P.GetFactTooltipOrText

-- ============================================================
-- Constants
-- ============================================================

local INTERACTIVE_PRESENTATION_ACTIONS = {
    talk = true,
    clicknpc = true,
    gossip = true,
    click = true,
}

local INSTRUCTION_NEIGHBOR_ACTIONS = {
    invehicle = true,
}

local OBJECTIVE_HELPER_ACTIONS = {
    click = true,
    use = true,
}

-- ============================================================
-- Walk utilities
-- ============================================================

local function IsInstructionNeighborActionFact(fact)
    local text = GetFactTooltipOrText(fact)
    return type(fact) == "table"
        and fact.visible == true
        and fact.suppressed ~= true
        and INSTRUCTION_NEIGHBOR_ACTIONS[fact.action] == true
        and fact.status ~= "complete"
        and type(text) == "string"
        and text ~= ""
        and not fact.mapID and not fact.x and not fact.y
end

local function WalkDirectionalVisibleFacts(facts, edgeIndex, direction, visitor)
    local i = edgeIndex + direction
    while i >= 1 and i <= #facts do
        local fact = facts[i]
        if fact and fact.visible == true and fact.suppressed ~= true then
            local decision = visitor(fact, i)
            if decision ~= "continue" then
                return decision
            end
        end
        i = i + direction
    end

    return nil
end

local function SelectNearestDirectionalCandidate(backward, forward, edgeIndex, getPriority)
    if backward and forward then
        local backwardDistance = edgeIndex - backward.index
        local forwardDistance = forward.index - edgeIndex
        if backwardDistance < forwardDistance then
            return backward
        end
        if forwardDistance < backwardDistance then
            return forward
        end
        if type(getPriority) == "function" then
            local backwardPriority = getPriority(backward)
            local forwardPriority = getPriority(forward)
            if backwardPriority <= forwardPriority then
                return backward
            end
            return forward
        end
        return backward
    end

    return backward or forward
end

-- ============================================================
-- Header scanning
-- ============================================================

local function ScanHeader(facts, startIndex, direction, allowInformationalTextBridge)
    return WalkDirectionalVisibleFacts(facts, startIndex, direction, function(fact)
        if IsHeaderFact(fact) then
            return fact
        end
        if IsGuidanceFact(fact) then
            return "continue"
        end
        if allowInformationalTextBridge and IsInformationalTextFact(fact) then
            return "continue"
        end
        return nil
    end)
end

local function SelectHeaderFact(facts, startIndex, endIndex, allowInformationalTextBridge)
    local backward = ScanHeader(facts, startIndex, -1, allowInformationalTextBridge)
    local forward = ScanHeader(facts, endIndex, 1, allowInformationalTextBridge)
    return SelectNearestDirectionalCandidate(backward, forward, startIndex, function(fact)
        return HEADER_PRIORITY[fact.action] or math.huge
    end)
end

local function SelectObjectiveInteractionChainHeaders(facts, seedIndex, titleText)
    if type(seedIndex) ~= "number" then
        return nil, nil
    end

    local secondaryHeaderFact = SelectHeaderFact(facts, seedIndex, seedIndex, true)
    if type(secondaryHeaderFact) ~= "table"
        or secondaryHeaderFact.action ~= "gossip"
        or type(secondaryHeaderFact.text) ~= "string"
        or secondaryHeaderFact.text == ""
        or secondaryHeaderFact.text == titleText
    then
        return nil, nil
    end

    for i = secondaryHeaderFact.index - 1, 1, -1 do
        local fact = facts[i]
        if fact and fact.visible == true and fact.suppressed ~= true then
            if (fact.action == "talk" or fact.action == "clicknpc")
                and type(fact.text) == "string"
                and fact.text ~= ""
                and fact.text ~= titleText
            then
                return fact, secondaryHeaderFact
            end

            if IsGuidanceFact(fact) or IsInformationalTextFact(fact) then
                -- Allow lightweight context between the interaction and gossip choice.
            else
                return nil, nil
            end
        end
    end

    return nil, nil
end

local function FindPrecedingTalkHeaderContext(facts, startIndex, targetMapID, targetX, targetY, targetSig)
    local bridgedCompletedQuestCount = 0
    local hasBridgedQuestContext = false
    for i = (startIndex or 1) - 1, 1, -1 do
        local fact = facts[i]
        if fact and fact.visible == true and fact.suppressed ~= true then
            if fact.action == "talk" then
                return hasBridgedQuestContext and fact
            end

            if IsBridgeableCompletedQuestFact(facts, i, startIndex, targetMapID, targetX, targetY, targetSig) then
                bridgedCompletedQuestCount = bridgedCompletedQuestCount + 1
                if bridgedCompletedQuestCount > 2 then
                    return nil
                end
                hasBridgedQuestContext = true
            elseif IsQuestActionFact(fact)
                and fact.status == "incomplete"
                and IsSameTargetFact(fact, targetMapID, targetX, targetY, targetSig)
                and HasSharedActionBlockBridgeContext(facts, i, startIndex)
            then
                hasBridgedQuestContext = true
            elseif IsGuidanceFact(fact) or IsInformationalTextFact(fact) then
                -- Allow lightweight local context between the completed handoff and its talk header.
            else
                return nil
            end
        end
    end

    return nil
end

local function ResolveQuestHeaderContext(facts, startIndex, endIndex, mirrorTitle, targetMapID, targetX, targetY, targetSig, allowInformationalTextBridge)
    local headerFact = SelectHeaderFact(facts, startIndex, endIndex, allowInformationalTextBridge)
    if type(headerFact) == "table"
        and type(headerFact.text) == "string"
        and headerFact.text ~= ""
        and headerFact.text ~= mirrorTitle
    then
        return headerFact, "context_header"
    end

    local talkFallback = FindPrecedingTalkHeaderContext(
        facts,
        startIndex,
        targetMapID,
        targetX,
        targetY,
        targetSig
    )
    if type(talkFallback) == "table"
        and type(talkFallback.text) == "string"
        and talkFallback.text ~= ""
        and talkFallback.text ~= mirrorTitle
    then
        return talkFallback, "preceding_talk_header"
    end

    return headerFact, nil
end

local function FindTrailingGuidanceTip(facts, endIndex)
    return WalkDirectionalVisibleFacts(facts, endIndex, 1, function(fact)
        if IsGuidanceFact(fact) then
            return GetFactTooltipOrText(fact)
        end
        return nil
    end)
end

-- ============================================================
-- Instruction neighbor scanning
-- ============================================================

local function UpdateInstructionNeighborCandidate(bestByKind, fact, edgeIndex, titleText)
    local kind
    if IsInstructionNeighborActionFact(fact) then
        kind = "action"
    elseif IsGuidanceFact(fact) then
        kind = "guidance"
    elseif IsInformationalTextFact(fact) then
        kind = "text"
    else
        return
    end

    local text = GetFactTooltipOrText(fact)
    if type(text) ~= "string" or text == "" or text == titleText then
        return
    end

    local distance = math.abs((fact.index or edgeIndex) - edgeIndex)
    local best = bestByKind[kind]
    if best == nil
        or distance < best.distance
        or (distance == best.distance and (fact.index or math.huge) < (best.fact.index or math.huge))
    then
        bestByKind[kind] = {
            fact = fact,
            distance = distance,
            text = text,
        }
    end
end

local function ScanInstructionNeighborCandidates(facts, edgeIndex, direction, bestByKind, titleText)
    WalkDirectionalVisibleFacts(facts, edgeIndex, direction, function(fact)
        if IsInstructionNeighborActionFact(fact) or IsGuidanceFact(fact) or IsInformationalTextFact(fact) then
            UpdateInstructionNeighborCandidate(bestByKind, fact, edgeIndex, titleText)
            return "continue"
        end
        return nil
    end)
end

local function SelectInstructionNeighborSubtext(facts, currentIndex, titleText)
    if type(currentIndex) ~= "number" then
        return nil
    end

    local bestByKind = {}
    ScanInstructionNeighborCandidates(facts, currentIndex, -1, bestByKind, titleText)
    ScanInstructionNeighborCandidates(facts, currentIndex, 1, bestByKind, titleText)

    local action = bestByKind.action
    if action and action.text then
        return action.text, "instruction_neighbor_action"
    end

    local guidance = bestByKind.guidance
    if guidance and guidance.text then
        return guidance.text, "instruction_neighbor_guidance"
    end

    local text = bestByKind.text
    if text and text.text then
        return text.text, "instruction_neighbor_text"
    end

    return nil
end

-- ============================================================
-- Quest objective helper scanning
-- ============================================================

local function IsQuestObjectiveHelperActionFact(fact, titleText)
    if type(fact) ~= "table" then return false end
    local helperText = GetFactTooltipOrText(fact)
    return fact.visible == true
        and fact.suppressed ~= true
        and OBJECTIVE_HELPER_ACTIONS[fact.action] == true
        and fact.status ~= "complete"
        and type(helperText) == "string"
        and helperText ~= ""
        and helperText ~= titleText
        and type(fact.mapID) ~= "number"
        and type(fact.x) ~= "number"
        and type(fact.y) ~= "number"
end

local function ScanQuestObjectiveHelperActionFact(facts, edgeIndex, direction, titleText, targetMapID, targetX, targetY, targetSig)
    local bridgedCompletedQuestCount = 0
    return WalkDirectionalVisibleFacts(facts, edgeIndex, direction, function(fact)
        if IsGuidanceFact(fact) or IsInformationalTextFact(fact) then
            return "continue"
        end
        if IsQuestObjectiveHelperActionFact(fact, titleText) then
            return fact
        end
        if IsBridgeableCompletedQuestFact(facts, fact.index, edgeIndex, targetMapID, targetX, targetY, targetSig) then
            bridgedCompletedQuestCount = bridgedCompletedQuestCount + 1
            if bridgedCompletedQuestCount <= 2 then
                return "continue"
            end
        end
        return nil
    end)
end

local function SelectQuestObjectiveHelperActionFact(facts, seedIndex, titleText)
    if type(seedIndex) ~= "number" then
        return nil
    end

    local backward = ScanQuestObjectiveHelperActionFact(facts, seedIndex, -1, titleText)
    local forward = ScanQuestObjectiveHelperActionFact(facts, seedIndex, 1, titleText)
    return SelectNearestDirectionalCandidate(backward, forward, seedIndex)
end

local function SelectQuestObjectiveHelperActionFactForBlock(facts, startIndex, endIndex, titleText, targetMapID, targetX, targetY, targetSig)
    if type(startIndex) ~= "number" or type(endIndex) ~= "number" then
        return nil
    end

    local backward = ScanQuestObjectiveHelperActionFact(
        facts,
        startIndex,
        -1,
        titleText,
        targetMapID,
        targetX,
        targetY,
        targetSig
    )
    local forward = ScanQuestObjectiveHelperActionFact(
        facts,
        endIndex,
        1,
        titleText,
        targetMapID,
        targetX,
        targetY,
        targetSig
    )
    return SelectNearestDirectionalCandidate(backward, forward, startIndex)
end

local function SelectQuestObjectiveHelperClusterSetupSubtext(facts, seedIndex, titleText)
    if type(seedIndex) ~= "number" then
        return nil, nil
    end

    local helperCount = 0
    local firstHelperIndex = nil
    WalkDirectionalVisibleFacts(facts, seedIndex, -1, function(fact)
        if IsGuidanceFact(fact) or IsInformationalTextFact(fact) then
            return "continue"
        end
        if IsQuestObjectiveHelperActionFact(fact, titleText) then
            helperCount = helperCount + 1
            firstHelperIndex = fact.index
            return "continue"
        end
        return nil
    end)

    if helperCount < 2 or type(firstHelperIndex) ~= "number" then
        return nil, nil
    end

    for i = firstHelperIndex - 1, 1, -1 do
        local fact = facts[i]
        if fact and fact.visible == true and fact.suppressed ~= true then
            if IsGuidanceFact(fact) or IsInformationalTextFact(fact) then
                local text = GetFactTooltipOrText(fact)
                if type(text) == "string" and text ~= "" and text ~= titleText then
                    return text, "non_actionable_objective_guidance_fallback"
                end
                return nil, nil
            end
            return nil, nil
        end
    end

    return nil, nil
end

-- ============================================================
-- Seed fact classification
-- ============================================================

local function IsQuestObjectiveHelperSeedFact(fact)
    if type(fact) ~= "table"
        or fact.visible ~= true
        or fact.suppressed == true
        or type(fact.text) ~= "string"
        or fact.text == ""
        or type(fact.questid) ~= "number"
        or fact.questid <= 0
    then
        return false
    end

    if fact.action == "q" then
        return fact.status == "incomplete" or fact.status == "warning"
    end

    if fact.action == "get" then
        return fact.status == "incomplete"
    end

    if fact.action == "havebuff" then
        return fact.status == "incomplete"
    end

    return false
end

-- ============================================================
-- Objective instruction scanning
-- ============================================================

local function UpdateQuestObjectiveInstructionCandidate(bestByKind, fact, edgeIndex, titleText)
    local kind
    if IsInformationalTextFact(fact) then
        kind = "text"
    elseif IsGuidanceFact(fact) then
        kind = "guidance"
    else
        return
    end

    local text = GetFactTooltipOrText(fact)
    if type(text) ~= "string" or text == "" or text == titleText then
        return
    end

    local distance = math.abs((fact.index or edgeIndex) - edgeIndex)
    local best = bestByKind[kind]
    if best == nil
        or distance < best.distance
        or (distance == best.distance and (fact.index or math.huge) < (best.fact.index or math.huge))
    then
        bestByKind[kind] = {
            fact = fact,
            distance = distance,
            text = text,
        }
    end
end

local function ScanQuestObjectiveInstructionCandidates(facts, edgeIndex, direction, bestByKind, titleText)
    WalkDirectionalVisibleFacts(facts, edgeIndex, direction, function(fact)
        if IsInformationalTextFact(fact) or IsGuidanceFact(fact) then
            UpdateQuestObjectiveInstructionCandidate(bestByKind, fact, edgeIndex, titleText)
            return "continue"
        end
        return nil
    end)
end

local function SelectQuestObjectiveInstructionSubtext(facts, seedIndex, titleText)
    if type(seedIndex) ~= "number" then
        return nil
    end

    local bestByKind = {}
    ScanQuestObjectiveInstructionCandidates(facts, seedIndex, -1, bestByKind, titleText)
    ScanQuestObjectiveInstructionCandidates(facts, seedIndex, 1, bestByKind, titleText)

    local text = bestByKind.text
    if text and text.text then
        return text.text, "non_actionable_objective_text_fallback"
    end

    local guidance = bestByKind.guidance
    if guidance and guidance.text then
        return guidance.text, "non_actionable_objective_guidance_fallback"
    end

    return nil
end

-- ============================================================
-- Passive subtext scanning
-- ============================================================

local function IsPassiveSubtextCandidateFact(fact)
    return type(fact) == "table"
        and fact.visible == true
        and fact.suppressed ~= true
        and fact.status == "passive"
        and (fact.action == "kill" or fact.action == "get")
        and type(fact.text) == "string"
        and fact.text ~= ""
end

local function UpdatePassiveSubtextCandidate(bestByAction, fact, edgeIndex, titleText)
    if not IsPassiveSubtextCandidateFact(fact) or fact.text == titleText then
        return
    end

    local action = fact.action
    local distance = math.abs((fact.index or edgeIndex) - edgeIndex)
    local best = bestByAction[action]
    if best == nil
        or distance < best.distance
        or (distance == best.distance and (fact.index or math.huge) < (best.fact.index or math.huge))
    then
        bestByAction[action] = {
            fact = fact,
            distance = distance,
        }
    end
end

local function ScanPassiveSubtextCandidates(facts, edgeIndex, direction, bestByAction, titleText)
    WalkDirectionalVisibleFacts(facts, edgeIndex, direction, function(fact)
        if IsPassiveSubtextCandidateFact(fact) then
            UpdatePassiveSubtextCandidate(bestByAction, fact, edgeIndex, titleText)
            return "continue"
        end
        if IsGuidanceFact(fact) or IsInformationalTextFact(fact) then
            return "continue"
        end
        return nil
    end)
end

local function SelectPassiveSubtextFallback(facts, startIndex, endIndex, titleText)
    local bestByAction = {}
    ScanPassiveSubtextCandidates(facts, startIndex, -1, bestByAction, titleText)
    ScanPassiveSubtextCandidates(facts, endIndex, 1, bestByAction, titleText)

    local killFact = bestByAction.kill and bestByAction.kill.fact
    if killFact then
        return killFact.text, "passive_kill_fallback"
    end

    local getFact = bestByAction.get and bestByAction.get.fact
    if getFact then
        return getFact.text, "passive_get_fallback"
    end

    return nil
end

-- ============================================================
-- Presentation fact queries
-- ============================================================

local function IsInteractivePresentationFact(fact)
    return type(fact) == "table"
        and INTERACTIVE_PRESENTATION_ACTIONS[fact.action] == true
        and fact.visible == true
        and fact.suppressed ~= true
        and type(fact.text) == "string"
        and fact.text ~= ""
end

local function IsDetachedQuestPresentationFact(fact)
    return type(fact) == "table"
        and fact.visible == true
        and fact.suppressed ~= true
        and type(fact.text) == "string"
        and fact.text ~= ""
        and type(fact.mapID) ~= "number"
        and type(fact.x) ~= "number"
        and type(fact.y) ~= "number"
        and (
            (IsQuestActionFact(fact) and fact.status == "incomplete")
            or (
                fact.action == "q"
                and (fact.status == "incomplete" or fact.status == "warning")
                and type(fact.questid) == "number"
                and fact.questid > 0
            )
        )
end

local function HasDetachedQuestPresentationHeaderHelper(facts, currentFact, detachedFact, titleText)
    if type(facts) ~= "table"
        or type(currentFact) ~= "table"
        or type(detachedFact) ~= "table"
        or type(currentFact.index) ~= "number"
        or type(detachedFact.index) ~= "number"
    then
        return false
    end

    local startIndex = math.min(currentFact.index, detachedFact.index)
    local endIndex = math.max(currentFact.index, detachedFact.index)
    for i = startIndex + 1, endIndex - 1 do
        local fact = facts[i]
        if IsHeaderFact(fact)
            and fact.text
            and fact.text ~= ""
            and fact.text ~= titleText
        then
            return true
        end
    end

    return false
end

local function SelectDetachedQuestPresentationFact(facts, currentFact, titleText, anchorIndex, liveCurrentness, options)
    if type(facts) ~= "table" then
        return nil
    end

    local presentationFacts = {}
    for _, fact in ipairs(facts) do
        if IsDetachedQuestPresentationFact(fact) then
            presentationFacts[#presentationFacts + 1] = fact
        end
    end

    local selectedFact = P.SelectSecondaryActionFact(presentationFacts, titleText, anchorIndex, liveCurrentness, options)
    if type(selectedFact) == "table"
        and selectedFact.action == "q"
        and HasDetachedQuestPresentationHeaderHelper(facts, currentFact, selectedFact, titleText)
    then
        return nil
    end

    return selectedFact
end

-- ============================================================
-- Exports
-- ============================================================

P.WalkDirectionalVisibleFacts = WalkDirectionalVisibleFacts
P.SelectNearestDirectionalCandidate = SelectNearestDirectionalCandidate
P.SelectHeaderFact = SelectHeaderFact
P.ResolveQuestHeaderContext = ResolveQuestHeaderContext
P.SelectObjectiveInteractionChainHeaders = SelectObjectiveInteractionChainHeaders
P.FindTrailingGuidanceTip = FindTrailingGuidanceTip
P.SelectInstructionNeighborSubtext = SelectInstructionNeighborSubtext
P.IsQuestObjectiveHelperActionFact = IsQuestObjectiveHelperActionFact
P.SelectQuestObjectiveHelperActionFact = SelectQuestObjectiveHelperActionFact
P.SelectQuestObjectiveHelperActionFactForBlock = SelectQuestObjectiveHelperActionFactForBlock
P.SelectQuestObjectiveHelperClusterSetupSubtext = SelectQuestObjectiveHelperClusterSetupSubtext
P.SelectQuestObjectiveInstructionSubtext = SelectQuestObjectiveInstructionSubtext
P.IsQuestObjectiveHelperSeedFact = IsQuestObjectiveHelperSeedFact
P.SelectPassiveSubtextFallback = SelectPassiveSubtextFallback
P.IsInteractivePresentationFact = IsInteractivePresentationFact
P.IsDetachedQuestPresentationFact = IsDetachedQuestPresentationFact
P.HasDetachedQuestPresentationHeaderHelper = HasDetachedQuestPresentationHeaderHelper
P.SelectDetachedQuestPresentationFact = SelectDetachedQuestPresentationFact
