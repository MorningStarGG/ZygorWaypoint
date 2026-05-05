local NS = _G.AzerothWaypointNS
if not NS.IsZygorLoaded() then return end

local M = NS.Internal.GuideResolver
local P = M.Private

-- ============================================================
-- Constants
-- ============================================================

local EXPECT_NIL = "__nil__"

local LEGACY_DEBUG_REASON_MAP = {
    hidden_or_cluster = "hidden_or_cluster",
    current_goal_instruction = "current_goal_instruction",
    current_goal_non_actionable_title = "current_goal_non_actionable_title",
    instruction_neighbor_action = "instruction_neighbor_action",
    instruction_neighbor_guidance = "instruction_neighbor_guidance",
    instruction_neighbor_text = "instruction_neighbor_text",
    non_actionable_objective_text_fallback = "non_actionable_objective_text_fallback",
    non_actionable_objective_guidance_fallback = "non_actionable_objective_guidance_fallback",
    non_actionable_interaction_chain_fallback = "non_actionable_interaction_chain_fallback",
    detached_quest_title_fallback = "detached_quest_title_fallback",
    non_actionable_header_fallback = "non_actionable_header_fallback",
    non_actionable_helper_action_fallback = "non_actionable_helper_action_fallback",
    visible_quest_goal_semantic_fallback = "visible_quest_goal_semantic_fallback",
    actionable_helper_action_fallback = "actionable_helper_action_fallback",
    no_visible_actionable_goal = "no_visible_actionable_goal",
    no_anchor = "no_anchor",
    no_target_coords = "no_target_coords",
    no_same_target_action = "no_same_target_action",
    empty_action_block = "empty_action_block",
    carrier_leg_suppressed = "carrier_leg_suppressed",
}

local LEGACY_SUBTEXT_REASON_MAP = {
    live_quest_match = "live_quest_match",
    alternate_generic_accept = "alternate_generic_accept",
    alternate_generic_turnin = "alternate_generic_turnin",
    alternate_tip = "alternate_tip",
    secondary_action = "secondary_action",
    context_header = "context_header",
    preceding_talk_header = "preceding_talk_header",
    passive_kill_fallback = "passive_kill_fallback",
    passive_get_fallback = "passive_get_fallback",
    coordinate_fallback = "coordinate_fallback",
    current_goal_instruction = "current_goal_instruction",
    instruction_neighbor_action = "instruction_neighbor_action",
    instruction_neighbor_guidance = "instruction_neighbor_guidance",
    instruction_neighbor_text = "instruction_neighbor_text",
    non_actionable_objective_text_fallback = "non_actionable_objective_text_fallback",
    non_actionable_objective_guidance_fallback = "non_actionable_objective_guidance_fallback",
    non_actionable_interaction_chain_fallback = "non_actionable_interaction_chain_fallback",
    non_actionable_header_fallback = "non_actionable_header_fallback",
    non_actionable_helper_action_fallback = "non_actionable_helper_action_fallback",
    actionable_helper_action_fallback = "actionable_helper_action_fallback",
    carrier_leg_suppressed = "carrier_leg_suppressed",
}

-- ============================================================
-- Test helpers
-- ============================================================

local function makeFact(index, fields)
    local fact = {
        index = index,
        goal = nil,
        action = nil,
        visible = true,
        status = "passive",
        questid = 0,
        questTitle = nil,
        npcid = 0,
        orlogic = nil,
        mapID = nil,
        x = nil,
        y = nil,
        text = nil,
        tooltip = nil,
        suppressed = false,
    }

    for key, value in pairs(fields or {}) do
        fact[key] = value
    end

    return fact
end

local function deepCopy(value)
    if type(value) ~= "table" then
        return value
    end

    local result = {}
    for key, innerValue in pairs(value) do
        result[key] = deepCopy(innerValue)
    end
    return result
end

local function splitPath(path)
    local parts = {}
    for segment in tostring(path):gmatch("[^%.]+") do
        parts[#parts + 1] = segment
    end
    return parts
end

local function applyPatches(patches)
    local restore = {}
    for _, patch in ipairs(patches or {}) do
        local parts = splitPath(patch.path)
        local parent = _G
        for i = 1, #parts - 1 do
            local segment = parts[i]
            if type(parent[segment]) ~= "table" then
                parent[segment] = {}
            end
            parent = parent[segment]
        end
        local leaf = parts[#parts]
        restore[#restore + 1] = {
            parent = parent,
            key = leaf,
            value = parent[leaf],
        }
        parent[leaf] = patch.value
    end
    return restore
end

local function restorePatches(restore)
    for i = #restore, 1, -1 do
        local item = restore[i]
        item.parent[item.key] = item.value
    end
end

local function compareField(expected, actual)
    if expected == nil then
        return true
    end
    if expected == EXPECT_NIL then
        return actual == nil
    end
    return expected == actual
end

local function RewriteCanonicalSource(source, canonicalGoalNum)
    if type(source) ~= "string" or type(canonicalGoalNum) ~= "number" then
        return source
    end

    if source:match("^step%.goal#%d+$") then
        return string.format("step.goal#%d", canonicalGoalNum)
    end

    return source
end

local function buildCaseContext(case)
    local context = deepCopy(case.context or {})
    context.facts = deepCopy(case.facts or {})
    local rawGoalNum = case.currentGoalNum
    local resolveCanonicalGoalFromFacts = P.ResolveCanonicalGoalFromFacts
    local canonical = type(resolveCanonicalGoalFromFacts) == "function"
        and resolveCanonicalGoalFromFacts(context.facts, rawGoalNum)
        or nil

    context.currentGoalNum = canonical and canonical.canonicalGoalNum or rawGoalNum
    context.source = RewriteCanonicalSource(context.source, context.currentGoalNum)
    return context
end

-- ============================================================
-- Test cases
-- ============================================================

local CASES = {
    {
        id = "visible_or_accept_cluster",
        category = "or_cluster",
        classification = "parity",
        sourceNote = "Visible accept |or| accept cluster with a talk header.",
        currentGoalNum = 2,
        context = {
            rawArrowTitle = "Accept 'Quest A'",
            kind = "guide",
            source = "step.goal#2",
            mapID = 100,
            x = 0.1000,
            y = 0.2000,
        },
        facts = {
            makeFact(1, { action = "talk", text = "Talk to Field Marshal Brock" }),
            makeFact(2, { action = "accept", status = "incomplete", questid = 1001, orlogic = 1, mapID = 100, x = 0.1000, y = 0.2000, text = "Accept 'Quest A'" }),
            makeFact(3, { action = "accept", status = "incomplete", questid = 1002, orlogic = 2, mapID = 100, x = 0.1000, y = 0.2000, text = "Accept 'Quest B'" }),
        },
        expected = {
            title = "Talk to Field Marshal Brock",
            subtext = "Accept Available Quest",
            clusterKind = "alternate_or_choice",
            debugReason = EXPECT_NIL,
            subtextReason = "alternate_generic_accept",
        },
    },
    {
        id = "visible_or_turnin_cluster",
        category = "or_cluster",
        classification = "parity",
        sourceNote = "Visible turnin |or| turnin cluster with a talk header.",
        currentGoalNum = 2,
        context = {
            rawArrowTitle = "Turn in 'Quest A'",
            kind = "guide",
            source = "step.goal#2",
            mapID = 101,
            x = 0.2200,
            y = 0.3300,
        },
        facts = {
            makeFact(1, { action = "talk", text = "Talk to Quartermaster Brevin" }),
            makeFact(2, { action = "turnin", status = "incomplete", questid = 2001, orlogic = 1, mapID = 101, x = 0.2200, y = 0.3300, text = "Turn in 'Quest A'" }),
            makeFact(3, { action = "turnin", status = "incomplete", questid = 2002, orlogic = 2, mapID = 101, x = 0.2200, y = 0.3300, text = "Turn in 'Quest B'" }),
        },
        expected = {
            title = "Talk to Quartermaster Brevin",
            subtext = "Turn In Available Quest",
            clusterKind = "alternate_or_choice",
            debugReason = EXPECT_NIL,
            subtextReason = "alternate_generic_turnin",
        },
    },
    {
        id = "hidden_or_cluster",
        category = "or_cluster",
        classification = "parity",
        sourceNote = "Hidden questpossible-style or-cluster still surfaces as alternate accept.",
        currentGoalNum = 1,
        context = {
            rawArrowTitle = "Accept Available Quest",
            kind = "guide",
            source = "step.goal#1",
        },
        facts = {
            makeFact(1, { action = "talk", text = "Talk to Commander Althea" }),
            makeFact(2, { action = "accept", visible = false, status = "hidden", questid = 3001, orlogic = 1, text = "Accept 'Quest A'" }),
            makeFact(3, { action = "accept", visible = false, status = "hidden", questid = 3002, orlogic = 2, text = "Accept 'Quest B'" }),
        },
        expected = {
            title = "Talk to Commander Althea",
            subtext = "Accept Available Quest",
            clusterKind = "alternate_or_choice",
            debugReason = "hidden_or_cluster",
            subtextReason = "alternate_generic_accept",
        },
    },
    {
        id = "alternate_or_direct_live_match_prefers_direct_entry",
        category = "live_currentness",
        classification = "parity",
        sourceNote = "When list entries are ambiguous but the direct quest frame points at one quest, the unique direct match should win.",
        currentGoalNum = 2,
        context = {
            rawArrowTitle = "Accept 'Quest A'",
            kind = "guide",
            source = "step.goal#2",
            mapID = 110,
            x = 0.4100,
            y = 0.2200,
        },
        patches = {
            { path = "C_GossipInfo.GetAvailableQuests", value = function()
                return {
                    { questID = 9701, title = "Quest A" },
                    { questID = 9702, title = "Quest B" },
                }
            end },
            { path = "GetQuestID", value = function() return 9702 end },
            { path = "QuestFrame", value = {
                DetailPanel = {
                    IsShown = function() return true end,
                },
            } },
            { path = "QuestInfoTitleHeader", value = {
                GetText = function() return "Quest B" end,
            } },
        },
        facts = {
            makeFact(1, { action = "talk", text = "Talk to Archivist Lyra" }),
            makeFact(2, { action = "accept", status = "incomplete", questid = 9701, orlogic = 1, mapID = 110, x = 0.4100, y = 0.2200, text = "Accept 'Quest A'" }),
            makeFact(3, { action = "accept", status = "incomplete", questid = 9702, orlogic = 2, mapID = 110, x = 0.4100, y = 0.2200, text = "Accept 'Quest B'" }),
        },
        expected = {
            title = "Talk to Archivist Lyra",
            subtext = "Accept 'Quest B'",
            clusterKind = "alternate_or_choice",
            debugReason = EXPECT_NIL,
            subtextReason = "live_quest_match",
            matchedLiveGoalNum = 3,
        },
    },
    {
        id = "alternate_or_ambiguous_live_match_falls_back_generic",
        category = "live_currentness",
        classification = "parity",
        sourceNote = "Ambiguous list-only live matches should not pick a quest and should fall back to the generic alternate accept label.",
        currentGoalNum = 2,
        context = {
            rawArrowTitle = "Accept 'Quest A'",
            kind = "guide",
            source = "step.goal#2",
            mapID = 111,
            x = 0.4600,
            y = 0.2800,
        },
        patches = {
            { path = "C_GossipInfo.GetAvailableQuests", value = function()
                return {
                    { questID = 9801, title = "Quest A" },
                    { questID = 9802, title = "Quest B" },
                }
            end },
        },
        facts = {
            makeFact(1, { action = "talk", text = "Talk to Lorekeeper Sela" }),
            makeFact(2, { action = "accept", status = "incomplete", questid = 9801, orlogic = 1, mapID = 111, x = 0.4600, y = 0.2800, text = "Accept 'Quest A'" }),
            makeFact(3, { action = "accept", status = "incomplete", questid = 9802, orlogic = 2, mapID = 111, x = 0.4600, y = 0.2800, text = "Accept 'Quest B'" }),
        },
        expected = {
            title = "Talk to Lorekeeper Sela",
            subtext = "Accept Available Quest",
            clusterKind = "alternate_or_choice",
            debugReason = EXPECT_NIL,
            subtextReason = "alternate_generic_accept",
            matchedLiveGoalNum = EXPECT_NIL,
        },
    },
    {
        id = "stale_turnin_secondary_suppressed",
        category = "stale_secondary",
        classification = "parity",
        sourceNote = "Stale turnin should not remain secondary when it is no longer in live dialog state.",
        currentGoalNum = 3,
        context = {
            rawArrowTitle = "Accept 'Finding a Foothold'",
            kind = "guide",
            source = "step.goal#3",
            mapID = 539,
            x = 0.2697,
            y = 0.0810,
        },
        patches = {
            { path = "C_GossipInfo.GetAvailableQuests", value = function() return {} end },
            { path = "C_GossipInfo.GetActiveQuests", value = function() return {} end },
            { path = "GetNumAvailableQuests", value = function() return 0 end },
            { path = "GetNumActiveQuests", value = function() return 0 end },
            { path = "GetQuestID", value = function() return nil end },
        },
        facts = {
            makeFact(1, { action = "talk", text = "Talk to Prophet Velen" }),
            makeFact(2, { action = "turnin", status = "incomplete", questid = 34575, mapID = 539, x = 0.2697, y = 0.0810, text = "Turn in 'Step Three: Prophet!'" }),
            makeFact(3, { action = "accept", status = "incomplete", questid = 34582, mapID = 539, x = 0.2697, y = 0.0810, text = "Accept 'Finding a Foothold'" }),
        },
        expected = {
            title = "Accept 'Finding a Foothold'",
            subtext = "Talk to Prophet Velen",
            clusterKind = "normal",
            debugReason = EXPECT_NIL,
            subtextReason = "context_header",
        },
    },
    {
        id = "stale_accept_secondary_suppressed",
        category = "stale_secondary",
        classification = "parity",
        sourceNote = "Accept should not remain secondary once it is already in the quest log.",
        currentGoalNum = 2,
        context = {
            rawArrowTitle = "Turn in 'Go to the Front'",
            kind = "guide",
            source = "step.goal#2",
            mapID = 100,
            x = 0.6829,
            y = 0.2855,
        },
        patches = {
            { path = "C_QuestLog.GetLogIndexForQuestID", value = function(questID) return questID == 10394 and 1 or 0 end },
        },
        facts = {
            makeFact(1, { action = "talk", text = "Talk to Field Marshal Brock" }),
            makeFact(2, { action = "turnin", status = "incomplete", questid = 10382, mapID = 100, x = 0.6829, y = 0.2855, text = "Turn in 'Go to the Front'" }),
            makeFact(3, { action = "accept", status = "incomplete", questid = 10394, mapID = 100, x = 0.6829, y = 0.2855, text = "Accept 'Disruption - Forge Camp: Mageddon'" }),
        },
        expected = {
            title = "Turn in 'Go to the Front'",
            subtext = "Talk to Field Marshal Brock",
            clusterKind = "normal",
            debugReason = EXPECT_NIL,
            subtextReason = "context_header",
        },
    },
    {
        id = "actionable_accept_click_helper",
        category = "helper_action",
        classification = "approved_improvement",
        sourceNote = "Actionable accept blocks should use a nearby click helper when stale secondary turnin and header fallbacks are unavailable.",
        currentGoalNum = 4,
        context = {
            rawArrowTitle = "Accept 'Defenstrations'",
            kind = "guide",
            source = "pointer.ArrowFrame.waypoint",
            mapID = 539,
            x = 0.5694,
            y = 0.3473,
        },
        patches = {
            { path = "C_GossipInfo.GetAvailableQuests", value = function() return {} end },
            { path = "C_GossipInfo.GetActiveQuests", value = function() return {} end },
            { path = "GetNumAvailableQuests", value = function() return 0 end },
            { path = "GetNumActiveQuests", value = function() return 0 end },
            { path = "GetQuestID", value = function() return nil end },
        },
        facts = {
            makeFact(1, { action = "click", npcid = 230933, text = "Click Defense Pylon Central Control Console" }),
            makeFact(2, { tooltip = "Inside the building." }),
            makeFact(3, { action = "turnin", status = "incomplete", questid = 34780, mapID = 539, x = 0.5694, y = 0.3473, text = "Turn in 'Invisible Ramparts'" }),
            makeFact(4, { action = "accept", status = "incomplete", questid = 34781, mapID = 539, x = 0.5694, y = 0.3473, text = "Accept 'Defenstrations'" }),
        },
        expected = {
            title = "Accept 'Defenstrations'",
            subtext = "Click Defense Pylon Central Control Console",
            clusterKind = "normal",
            debugReason = EXPECT_NIL,
            subtextReason = "actionable_helper_action_fallback",
        },
    },
    {
        id = "actionable_accept_click_helper_bridged_complete",
        category = "helper_action",
        classification = "approved_improvement",
        sourceNote = "Actionable accept blocks should bridge across completed same-target turnins to reach a nearby click helper.",
        currentGoalNum = 4,
        context = {
            rawArrowTitle = "Accept 'Defenstrations'",
            kind = "guide",
            source = "pointer.ArrowFrame.waypoint",
            mapID = 539,
            x = 0.5694,
            y = 0.3473,
        },
        patches = {
            { path = "C_GossipInfo.GetAvailableQuests", value = function() return {} end },
            { path = "C_GossipInfo.GetActiveQuests", value = function() return {} end },
            { path = "GetNumAvailableQuests", value = function() return 0 end },
            { path = "GetNumActiveQuests", value = function() return 0 end },
            { path = "GetQuestID", value = function() return nil end },
        },
        facts = {
            makeFact(1, { action = "click", npcid = 230933, text = "Click Defense Pylon Central Control Console" }),
            makeFact(2, { tooltip = "Inside the building." }),
            makeFact(3, { action = "turnin", status = "complete", questid = 34780, mapID = 539, x = 0.5694, y = 0.3473, text = "Turned in 'Invisible Ramparts'" }),
            makeFact(4, { action = "accept", status = "incomplete", questid = 34781, mapID = 539, x = 0.5694, y = 0.3473, text = "Accept 'Defenstrations'" }),
        },
        expected = {
            title = "Accept 'Defenstrations'",
            subtext = "Click Defense Pylon Central Control Console",
            clusterKind = "normal",
            debugReason = EXPECT_NIL,
            subtextReason = "actionable_helper_action_fallback",
        },
    },
    {
        id = "stale_completed_title_promotes_primary_action",
        category = "stale_title",
        classification = "approved_improvement",
        sourceNote = "Completed same-target quest titles immediately before the current actionable block should not remain as the displayed title.",
        currentGoalNum = 3,
        context = {
            rawArrowTitle = "Turned in 'The Exarch Council'",
            kind = "guide",
            source = "pointer.ArrowFrame.waypoint",
            mapID = 539,
            x = 0.5937,
            y = 0.2656,
        },
        facts = {
            makeFact(1, { action = "talk", text = "Talk to Exarch Othaar" }),
            makeFact(2, { action = "turnin", status = "complete", questid = 34782, mapID = 539, x = 0.5937, y = 0.2656, text = "Turned in 'The Exarch Council'" }),
            makeFact(3, { action = "accept", status = "complete", questid = 34783, mapID = 539, x = 0.5937, y = 0.2656, text = "Accepted 'Naielle, The Rangari'" }),
            makeFact(4, { action = "accept", status = "incomplete", questid = 34785, mapID = 539, x = 0.5937, y = 0.2656, text = "Accept 'Hataaru, the Artificer'" }),
        },
        expected = {
            title = "Accept 'Hataaru, the Artificer'",
            subtext = "Talk to Exarch Othaar",
            clusterKind = "normal",
            debugReason = EXPECT_NIL,
            subtextReason = "preceding_talk_header",
        },
    },
    {
        id = "stale_block_title_prefers_current_goal_action",
        category = "stale_title",
        classification = "approved_improvement",
        sourceNote = "Stale raw titles in mixed turnin/accept blocks should still hand title ownership to the current actionable goal, not reorder across action types.",
        currentGoalNum = 4,
        context = {
            rawArrowTitle = "Turned in 'The Clarity Elixir'",
            kind = "guide",
            source = "pointer.ArrowFrame.waypoint",
            mapID = 539,
            x = 0.3527,
            y = 0.4913,
        },
        facts = {
            makeFact(1, { action = "talk", text = "Talk to Prophet Velen" }),
            makeFact(2, { tooltip = "In the entrance of the tree." }),
            makeFact(3, { action = "turnin", status = "incomplete", questid = 33076, mapID = 539, x = 0.3527, y = 0.4913, text = "Turn in 'The Clarity Elixir'" }),
            makeFact(4, { action = "accept", status = "incomplete", questid = 33059, mapID = 539, x = 0.3527, y = 0.4913, text = "Accept 'The Fate of Karabor'" }),
        },
        expected = {
            title = "Accept 'The Fate of Karabor'",
            subtext = "Talk to Prophet Velen",
            clusterKind = "normal",
            debugReason = EXPECT_NIL,
            subtextReason = "context_header",
        },
    },
    {
        id = "stale_completed_block_title_bridges_guidance_to_talk_header",
        category = "stale_title",
        classification = "approved_improvement",
        sourceNote = "Completed same-target handoffs should still recover the talk header when lightweight guidance sits between the completed turnin and the live accept.",
        currentGoalNum = 3,
        context = {
            rawArrowTitle = "Turned in 'The Clarity Elixir'",
            kind = "route",
            legKind = "destination",
            source = "step.goal#3",
            mapID = 539,
            x = 0.3527,
            y = 0.4913,
        },
        facts = {
            makeFact(1, { action = "talk", text = "Talk to Prophet Velen" }),
            makeFact(2, { tooltip = "In the entrance of the tree." }),
            makeFact(3, { action = "turnin", status = "complete", questid = 33076, mapID = 539, x = 0.3527, y = 0.4913, text = "Turned in 'The Clarity Elixir'" }),
            makeFact(4, { action = "accept", status = "incomplete", questid = 33059, mapID = 539, x = 0.3527, y = 0.4913, text = "Accept 'The Fate of Karabor'" }),
        },
        expected = {
            title = "Accept 'The Fate of Karabor'",
            subtext = "Talk to Prophet Velen",
            clusterKind = "normal",
            debugReason = EXPECT_NIL,
            subtextReason = "preceding_talk_header",
            routePresentationAllowed = true,
        },
    },
    {
        id = "multi_accept_block_prefers_header_context",
        category = "multi_action_context",
        classification = "approved_improvement",
        sourceNote = "Multi-accept blocks should prefer the shared talk context over a sibling accept as subtext.",
        currentGoalNum = 2,
        context = {
            rawArrowTitle = "Turned in 'The Exarch Council'",
            kind = "guide",
            source = "pointer.ArrowFrame.waypoint",
            mapID = 539,
            x = 0.5937,
            y = 0.2656,
        },
        patches = {
            { path = "C_QuestLog.GetLogIndexForQuestID", value = function() return 0 end },
        },
        facts = {
            makeFact(1, { action = "talk", text = "Talk to Exarch Othaar" }),
            makeFact(2, { action = "turnin", status = "complete", questid = 34782, mapID = 539, x = 0.5937, y = 0.2656, text = "Turned in 'The Exarch Council'" }),
            makeFact(3, { action = "accept", status = "incomplete", questid = 34783, mapID = 539, x = 0.5937, y = 0.2656, text = "Accept 'Naielle, The Rangari'" }),
            makeFact(4, { action = "accept", status = "incomplete", questid = 34785, mapID = 539, x = 0.5937, y = 0.2656, text = "Accept 'Hataaru, the Artificer'" }),
        },
        expected = {
            title = "Accept 'Naielle, The Rangari'",
            subtext = "Talk to Exarch Othaar",
            clusterKind = "normal",
            debugReason = EXPECT_NIL,
            subtextReason = "preceding_talk_header",
        },
    },
    {
        id = "split_multi_accept_block_recovers_talk_header",
        category = "multi_action_context",
        classification = "approved_improvement",
        sourceNote = "Raw goal points at the last incomplete accept; canonical selects the first incomplete accept (goal 2) as the earliest in the cluster.",
        currentGoalNum = 4,
        context = {
            rawArrowTitle = "Accept 'The Great Salvation'",
            kind = "guide",
            source = "pointer.ArrowFrame.waypoint",
            mapID = 539,
            x = 0.3584,
            y = 0.3696,
        },
        facts = {
            makeFact(1, { action = "talk", npcid = 81176, text = "Talk to Rangari Saa'to" }),
            makeFact(2, { action = "accept", status = "incomplete", questid = 33083, mapID = 539, x = 0.3584, y = 0.3696, text = "Accept 'On the Offensive'" }),
            makeFact(3, { action = "accept", status = "complete", questid = 33793, mapID = 539, x = 0.3584, y = 0.3696, text = "Accepted 'Harbingers of the Void'" }),
            makeFact(4, { action = "accept", status = "incomplete", questid = 33794, mapID = 539, x = 0.3584, y = 0.3696, text = "Accept 'The Great Salvation'" }),
        },
        expected = {
            title = "Accept 'On the Offensive'",
            subtext = "Talk to Rangari Saa'to",
            clusterKind = "normal",
            debugReason = EXPECT_NIL,
            subtextReason = "context_header",
            headerGoalNum = 1,
        },
    },
    {
        id = "presentation_current_action_owns_title_over_sibling_raw_match",
        category = "presentation_context",
        classification = "approved_improvement",
        sourceNote = "When raw title still matches a sibling in the current mixed block, title ownership stays on the selected current actionable fact.",
        currentGoalNum = 3,
        context = {
            rawArrowTitle = "Turn in 'Quest A'",
            kind = "guide",
            source = "pointer.ArrowFrame.waypoint",
            mapID = 107,
            x = 0.1111,
            y = 0.2222,
        },
        facts = {
            makeFact(1, { action = "talk", text = "Talk to Prophet Velen" }),
            makeFact(2, { action = "turnin", status = "incomplete", questid = 9701, mapID = 107, x = 0.1111, y = 0.2222, text = "Turn in 'Quest A'" }),
            makeFact(3, { action = "accept", status = "incomplete", questid = 9702, mapID = 107, x = 0.1111, y = 0.2222, text = "Accept 'Quest B'" }),
        },
        expected = {
            title = "Accept 'Quest B'",
            subtext = "Talk to Prophet Velen",
            clusterKind = "normal",
            debugReason = EXPECT_NIL,
            subtextReason = "context_header",
            titleOwnerGoal = 3,
            titleOwnerReason = "current_actionable_fact",
            headerContextGoal = 1,
            headerContextReason = "context_header",
        },
    },
    {
        id = "presentation_bridged_completed_corridor_promotes_primary_title_owner",
        category = "presentation_context",
        classification = "approved_improvement",
        sourceNote = "When raw title only exists in a bridgeable completed corridor before the live block, title ownership promotes to the block primary fact.",
        currentGoalNum = 2,
        context = {
            rawArrowTitle = "Turned in 'Quest A'",
            kind = "guide",
            source = "pointer.ArrowFrame.waypoint",
            mapID = 108,
            x = 0.3333,
            y = 0.4444,
        },
        facts = {
            makeFact(1, { action = "talk", text = "Talk to Prophet Velen" }),
            makeFact(2, { action = "turnin", status = "complete", questid = 9801, mapID = 108, x = 0.3333, y = 0.4444, text = "Turned in 'Quest A'" }),
            makeFact(3, { action = "accept", status = "incomplete", questid = 9802, mapID = 108, x = 0.3333, y = 0.4444, text = "Accept 'Quest B'" }),
        },
        expected = {
            title = "Accept 'Quest B'",
            subtext = "Talk to Prophet Velen",
            clusterKind = "normal",
            debugReason = EXPECT_NIL,
            subtextReason = "preceding_talk_header",
            titleOwnerGoal = 3,
            titleOwnerReason = "bridged_completed_corridor",
            headerContextGoal = 1,
            headerContextReason = "preceding_talk_header",
        },
    },
    {
        id = "presentation_direct_header_beats_corridor_fallback",
        category = "presentation_context",
        classification = "approved_improvement",
        sourceNote = "A direct header around the live action block should win before a bridged corridor fallback to an earlier talk header.",
        currentGoalNum = 2,
        context = {
            rawArrowTitle = "Turned in 'Quest A'",
            kind = "guide",
            source = "pointer.ArrowFrame.waypoint",
            mapID = 109,
            x = 0.5555,
            y = 0.6666,
        },
        facts = {
            makeFact(1, { action = "talk", text = "Talk to Prophet Velen" }),
            makeFact(2, { action = "turnin", status = "complete", questid = 9901, mapID = 109, x = 0.5555, y = 0.6666, text = "Turned in 'Quest A'" }),
            makeFact(3, { action = "accept", status = "incomplete", questid = 9902, mapID = 109, x = 0.5555, y = 0.6666, text = "Accept 'Quest B'" }),
            makeFact(4, { action = "talk", text = "Talk to Archmage Khadgar" }),
        },
        expected = {
            title = "Accept 'Quest B'",
            subtext = "Talk to Archmage Khadgar",
            clusterKind = "normal",
            debugReason = EXPECT_NIL,
            subtextReason = "context_header",
            titleOwnerGoal = 3,
            titleOwnerReason = "bridged_completed_corridor",
            headerContextGoal = 4,
            headerContextReason = "context_header",
        },
    },
    {
        id = "presentation_corridor_recovers_preceding_talk_header",
        category = "presentation_context",
        classification = "approved_improvement",
        sourceNote = "The unified header resolver should still recover the preceding talk header across one completed bridge fact when no direct header exists.",
        currentGoalNum = 3,
        context = {
            rawArrowTitle = "Accept 'Quest B'",
            kind = "guide",
            source = "pointer.ArrowFrame.waypoint",
            mapID = 110,
            x = 0.7777,
            y = 0.2222,
        },
        facts = {
            makeFact(1, { action = "talk", text = "Talk to Rangari Arepheon" }),
            makeFact(2, { action = "turnin", status = "complete", questid = 9911, mapID = 110, x = 0.7777, y = 0.2222, text = "Turned in 'Quest A'" }),
            makeFact(3, { action = "accept", status = "incomplete", questid = 9912, mapID = 110, x = 0.7777, y = 0.2222, text = "Accept 'Quest B'" }),
        },
        expected = {
            title = "Accept 'Quest B'",
            subtext = "Talk to Rangari Arepheon",
            clusterKind = "normal",
            debugReason = EXPECT_NIL,
            subtextReason = "preceding_talk_header",
            titleOwnerGoal = 3,
            titleOwnerReason = "current_actionable_fact",
            headerContextGoal = 1,
            headerContextReason = "preceding_talk_header",
        },
    },
    {
        id = "presentation_corridor_stops_on_broken_bridge",
        category = "presentation_context",
        classification = "approved_improvement",
        sourceNote = "The unified header resolver must still stop when a visible non-bridge fact breaks the corridor before the earlier talk header.",
        currentGoalNum = 4,
        context = {
            rawArrowTitle = "Accept 'Quest B'",
            kind = "guide",
            source = "pointer.ArrowFrame.waypoint",
            mapID = 111,
            x = 0.8888,
            y = 0.3333,
        },
        facts = {
            makeFact(1, { action = "talk", text = "Talk to Rangari Arepheon" }),
            makeFact(2, { action = "clicknpc", text = "Talk to Guardian Yrel" }),
            makeFact(3, { action = "turnin", status = "complete", questid = 9921, mapID = 111, x = 0.8888, y = 0.3333, text = "Turned in 'Quest A'" }),
            makeFact(4, { action = "accept", status = "incomplete", questid = 9922, mapID = 111, x = 0.8888, y = 0.3333, text = "Accept 'Quest B'" }),
        },
        expected = {
            title = "Accept 'Quest B'",
            subtext = EXPECT_NIL,
            clusterKind = "normal",
            debugReason = EXPECT_NIL,
            subtextReason = EXPECT_NIL,
            titleOwnerGoal = 4,
            titleOwnerReason = "current_actionable_fact",
            headerContextGoal = EXPECT_NIL,
            headerContextReason = EXPECT_NIL,
        },
    },
    {
        id = "mixed_turnin_accept_block_prefers_header_context",
        category = "multi_action_context",
        classification = "approved_improvement",
        sourceNote = "Mixed turnin+accept blocks should prefer the shared talk context over a sibling quest action as subtext.",
        currentGoalNum = 2,
        context = {
            rawArrowTitle = "Turn in 'Quest A'",
            kind = "guide",
            source = "pointer.ArrowFrame.waypoint",
            mapID = 100,
            x = 0.4000,
            y = 0.5000,
        },
        patches = {
            { path = "C_QuestLog.GetLogIndexForQuestID", value = function() return 0 end },
        },
        facts = {
            makeFact(1, { action = "talk", text = "Talk to Field Marshal Brock" }),
            makeFact(2, { action = "turnin", status = "incomplete", questid = 5001, mapID = 100, x = 0.4000, y = 0.5000, text = "Turn in 'Quest A'" }),
            makeFact(3, { action = "accept", status = "incomplete", questid = 5002, mapID = 100, x = 0.4000, y = 0.5000, text = "Accept 'Quest B'" }),
        },
        expected = {
            title = "Turn in 'Quest A'",
            subtext = "Talk to Field Marshal Brock",
            clusterKind = "normal",
            debugReason = EXPECT_NIL,
            subtextReason = "context_header",
        },
    },
    {
        id = "multi_turnin_block_prefers_header_context",
        category = "multi_action_context",
        classification = "approved_improvement",
        sourceNote = "Multi-turnin blocks should prefer the shared talk context over a sibling turnin as subtext.",
        currentGoalNum = 2,
        context = {
            rawArrowTitle = "Turn in 'Quest A'",
            kind = "guide",
            source = "pointer.ArrowFrame.waypoint",
            mapID = 100,
            x = 0.4200,
            y = 0.5200,
        },
        patches = {
            { path = "C_GossipInfo.GetAvailableQuests", value = function() return {} end },
            { path = "C_GossipInfo.GetActiveQuests", value = function()
                return {
                    { questID = 6001, title = "Quest A", isComplete = true },
                    { questID = 6002, title = "Quest B", isComplete = true },
                }
            end },
            { path = "GetNumAvailableQuests", value = function() return 0 end },
            { path = "GetNumActiveQuests", value = function() return 0 end },
            { path = "GetQuestID", value = function() return nil end },
        },
        facts = {
            makeFact(1, { action = "talk", text = "Talk to Quartermaster Brevin" }),
            makeFact(2, { action = "turnin", status = "incomplete", questid = 6001, mapID = 100, x = 0.4200, y = 0.5200, text = "Turn in 'Quest A'" }),
            makeFact(3, { action = "turnin", status = "incomplete", questid = 6002, mapID = 100, x = 0.4200, y = 0.5200, text = "Turn in 'Quest B'" }),
        },
        expected = {
            title = "Turn in 'Quest A'",
            subtext = "Talk to Quartermaster Brevin",
            clusterKind = "normal",
            debugReason = EXPECT_NIL,
            subtextReason = "context_header",
        },
    },
    {
        id = "nearby_turnin_accept_shared_header_bridge",
        category = "action_block_bridge",
        classification = "approved_improvement",
        sourceNote = "Adjacent quest actions with tiny coordinate drift should join the same block when a shared interaction header clearly supports them.",
        currentGoalNum = 3,
        context = {
            rawArrowTitle = "Accept 'The Clarity Elixir'",
            kind = "guide",
            source = "pointer.ArrowFrame.waypoint",
            mapID = 539,
            x = 0.4053,
            y = 0.5489,
        },
        facts = {
            makeFact(1, { action = "talk", npcid = 79043, text = "Talk to Prophet Velen" }),
            makeFact(2, { action = "turnin", status = "incomplete", questid = 33072, mapID = 539, x = 0.4054, y = 0.5492, text = "Turn in 'Into Twilight'" }),
            makeFact(3, { action = "accept", status = "incomplete", questid = 33076, mapID = 539, x = 0.4053, y = 0.5489, text = "Accept 'The Clarity Elixir'" }),
        },
        expected = {
            title = "Accept 'The Clarity Elixir'",
            subtext = "Talk to Prophet Velen",
            clusterKind = "normal",
            debugReason = EXPECT_NIL,
            subtextReason = "context_header",
        },
    },
    {
        id = "nearby_turnin_accept_no_header_no_bridge",
        category = "action_block_bridge",
        classification = "parity",
        sourceNote = "Tiny coordinate drift alone should not merge adjacent quest actions when no shared interaction header exists.",
        currentGoalNum = 3,
        context = {
            rawArrowTitle = "Accept 'Quest B'",
            kind = "guide",
            source = "pointer.ArrowFrame.waypoint",
            mapID = 100,
            x = 0.4001,
            y = 0.5002,
        },
        facts = {
            makeFact(1, { action = "text", text = "Watch the dialogue", tooltip = "Watch the dialogue" }),
            makeFact(2, { action = "turnin", status = "incomplete", questid = 7001, mapID = 100, x = 0.4000, y = 0.5000, text = "Turn in 'Quest A'" }),
            makeFact(3, { action = "accept", status = "incomplete", questid = 7002, mapID = 100, x = 0.4001, y = 0.5002, text = "Accept 'Quest B'" }),
        },
        expected = {
            title = "Accept 'Quest B'",
            subtext = EXPECT_NIL,
            clusterKind = "normal",
            debugReason = EXPECT_NIL,
            subtextReason = EXPECT_NIL,
        },
    },
    {
        id = "stale_completed_anchor_shared_header_seed_bridge",
        category = "action_block_bridge",
        classification = "approved_improvement",
        sourceNote = "A stale completed quest anchor should still find the nearby current quest action when a shared interaction header clearly supports the same NPC handoff.",
        currentGoalNum = 2,
        context = {
            rawArrowTitle = "Turned in 'Into Twilight'",
            kind = "guide",
            source = "pointer.ArrowFrame.waypoint",
            mapID = 539,
            x = 0.4054,
            y = 0.5492,
        },
        patches = {
            { path = "C_QuestLog.GetLogIndexForQuestID", value = function() return 0 end },
        },
        facts = {
            makeFact(1, { action = "talk", npcid = 79043, text = "Talk to Prophet Velen" }),
            makeFact(2, { action = "turnin", status = "complete", questid = 33072, mapID = 539, x = 0.4054, y = 0.5492, text = "Turned in 'Into Twilight'" }),
            makeFact(3, { action = "accept", status = "incomplete", questid = 33076, mapID = 539, x = 0.4053, y = 0.5489, text = "Accept 'The Clarity Elixir'" }),
        },
        expected = {
            title = "Accept 'The Clarity Elixir'",
            subtext = "Talk to Prophet Velen",
            clusterKind = "normal",
            debugReason = EXPECT_NIL,
            subtextReason = "preceding_talk_header",
        },
    },
    {
        id = "completed_turnin_bridge_recovers_talk_header_with_drift",
        category = "action_block_bridge",
        classification = "approved_improvement",
        sourceNote = "A completed same-target turnin with tiny coordinate drift should still bridge to the preceding talk header for the live accept.",
        currentGoalNum = 3,
        context = {
            rawArrowTitle = "Accept 'Gestating Genesaur'",
            kind = "guide",
            source = "pointer.ArrowFrame.waypoint",
            mapID = 539,
            x = 0.5567,
            y = 0.7198,
        },
        facts = {
            makeFact(1, { action = "talk", npcid = 80781, text = "Talk to Rangari Arepheon" }),
            makeFact(2, { action = "turnin", status = "complete", questid = 35014, mapID = 539, x = 0.5566, y = 0.7198, text = "Turned in 'Blademoon Bloom'" }),
            makeFact(3, { action = "accept", status = "incomplete", questid = 35015, mapID = 539, x = 0.5567, y = 0.7198, text = "Accept 'Gestating Genesaur'" }),
        },
        expected = {
            title = "Accept 'Gestating Genesaur'",
            subtext = "Talk to Rangari Arepheon",
            clusterKind = "normal",
            debugReason = EXPECT_NIL,
            subtextReason = "preceding_talk_header",
        },
    },
    {
        id = "stale_completed_anchor_no_header_no_seed_bridge",
        category = "action_block_bridge",
        classification = "parity",
        sourceNote = "A stale completed quest anchor should not bridge to a nearby current quest action on coordinate drift alone when no shared interaction header exists.",
        currentGoalNum = 2,
        context = {
            rawArrowTitle = "Turned in 'Quest A'",
            kind = "guide",
            source = "pointer.ArrowFrame.waypoint",
            mapID = 100,
            x = 0.4000,
            y = 0.5000,
        },
        patches = {
            { path = "C_QuestLog.GetLogIndexForQuestID", value = function() return 0 end },
        },
        facts = {
            makeFact(1, { action = "text", text = "Watch the dialogue", tooltip = "Watch the dialogue" }),
            makeFact(2, { action = "turnin", status = "complete", questid = 7101, mapID = 100, x = 0.4000, y = 0.5000, text = "Turned in 'Quest A'" }),
            makeFact(3, { action = "accept", status = "incomplete", questid = 7102, mapID = 100, x = 0.4001, y = 0.5002, text = "Accept 'Quest B'" }),
        },
        expected = {
            title = EXPECT_NIL,
            subtext = EXPECT_NIL,
            clusterKind = EXPECT_NIL,
            debugReason = "no_same_target_action",
            subtextReason = EXPECT_NIL,
        },
    },
    {
        id = "instruction_neighbor_confirm",
        category = "instruction_neighbor",
        classification = "parity",
        sourceNote = "Confirm current-goal step should pick nearby guidance when the current text equals the title.",
        currentGoalNum = 3,
        context = {
            rawArrowTitle = "Click Here Once Baron Alexston Arrives",
            kind = "guide",
            source = "step.goal#3",
            mapID = 582,
            x = 0.3271,
            y = 0.3404,
        },
        facts = {
            makeFact(1, { action = "text", text = "Watch the dialogue", tooltip = "Watch the dialogue" }),
            makeFact(2, { tooltip = "Wait for Baron Alexston to appear and walk to this location." }),
            makeFact(3, { action = "confirm", status = "incomplete", questid = 34583, mapID = 582, x = 0.3271, y = 0.3404, text = "Click Here Once Baron Alexston Arrives", tooltip = "Click Here Once Baron Alexston Arrives" }),
        },
        expected = {
            title = "Click Here Once Baron Alexston Arrives",
            subtext = "Wait for Baron Alexston to appear and walk to this location.",
            clusterKind = "non_actionable_fallback",
            debugReason = "instruction_neighbor_guidance",
            subtextReason = "instruction_neighbor_guidance",
        },
    },
    {
        id = "talk_invehicle_instruction_neighbor",
        category = "instruction_neighbor",
        classification = "approved_improvement",
        sourceNote = "Interactive route targets should allow nearby invehicle travel instructions as subtext.",
        currentGoalNum = 1,
        context = {
            rawArrowTitle = "Talk to Dungar Longdrink",
            kind = "route",
            legKind = "destination",
            source = "step.goal#1",
            mapID = 582,
            x = 0.4800,
            y = 0.4980,
        },
        facts = {
            makeFact(1, { action = "talk", npcid = 81103, mapID = 582, x = 0.4800, y = 0.4980, text = "Talk to Dungar Longdrink" }),
            makeFact(4, { action = "invehicle", status = "incomplete", questid = 34778, text = "Take a Flight to Embaari Village, Shadowmoon Valley", tooltip = "Take a Flight to Embaari Village, Shadowmoon Valley" }),
        },
        expected = {
            title = "Talk to Dungar Longdrink",
            subtext = "Take a Flight to Embaari Village, Shadowmoon Valley",
            clusterKind = "non_actionable_fallback",
            debugReason = "instruction_neighbor_action",
            subtextReason = "instruction_neighbor_action",
            routePresentationAllowed = true,
            semanticKind = "travel",
            semanticTravelType = "taxi",
        },
    },
    {
        id = "taxi_npcid_proof_neutral_subtext",
        category = "instruction_neighbor",
        classification = "approved_improvement",
        sourceNote = "Coord epsilon proof via C_TaxiMap should classify as taxi even when subtext wording has no flight keywords.",
        currentGoalNum = 1,
        context = {
            rawArrowTitle = "Talk to Dungar Longdrink",
            kind = "route",
            legKind = "destination",
            source = "step.goal#1",
            mapID = 582,
            x = 0.4800,
            y = 0.4980,
        },
        facts = {
            makeFact(1, { action = "talk", npcid = 81103, mapID = 582, x = 0.4800, y = 0.4980, text = "Talk to Dungar Longdrink" }),
            makeFact(4, { action = "invehicle", status = "incomplete", questid = 34778, text = "Speak with the flight master", tooltip = "Speak with the flight master" }),
        },
        expected = {
            title = "Talk to Dungar Longdrink",
            subtext = "Speak with the flight master",
            clusterKind = "non_actionable_fallback",
            debugReason = "instruction_neighbor_action",
            subtextReason = "instruction_neighbor_action",
            routePresentationAllowed = true,
            semanticKind = "travel",
            semanticTravelType = "taxi",
        },
    },
    {
        id = "taxi_text_fallback_begin_flying",
        category = "instruction_neighbor",
        classification = "approved_improvement",
        sourceNote = "'Begin Flying to' phrase should classify as taxi via text fallback when coord has no C_TaxiMap proof.",
        currentGoalNum = 1,
        context = {
            rawArrowTitle = "Talk to Innkeeper",
            kind = "route",
            legKind = "destination",
            source = "step.goal#1",
            mapID = 1,
            x = 0.5000,
            y = 0.5000,
        },
        facts = {
            makeFact(1, { action = "talk", npcid = 99999, mapID = 1, x = 0.5000, y = 0.5000, text = "Talk to Innkeeper" }),
            makeFact(4, { action = "invehicle", status = "incomplete", questid = 10001, text = "Begin Flying to Stormwind", tooltip = "Begin Flying to Stormwind" }),
        },
        expected = {
            title = "Talk to Innkeeper",
            subtext = "Begin Flying to Stormwind",
            clusterKind = "non_actionable_fallback",
            debugReason = "instruction_neighbor_action",
            subtextReason = "instruction_neighbor_action",
            routePresentationAllowed = true,
            semanticKind = "travel",
            semanticTravelType = "taxi",
        },
    },
    {
        id = "taxi_no_proof_non_taxi_npc",
        category = "instruction_neighbor",
        classification = "approved_improvement",
        sourceNote = "Non-taxi NPC with generic subtext should NOT classify as taxi when coord has no C_TaxiMap proof.",
        currentGoalNum = 1,
        context = {
            rawArrowTitle = "Talk to Quest Giver",
            kind = "route",
            legKind = "destination",
            source = "step.goal#1",
            mapID = 1,
            x = 0.5000,
            y = 0.5000,
        },
        facts = {
            makeFact(1, { action = "talk", npcid = 12345, mapID = 1, x = 0.5000, y = 0.5000, text = "Talk to Quest Giver" }),
            makeFact(4, { action = "invehicle", status = "incomplete", questid = 10002, text = "Continue your journey", tooltip = "Continue your journey" }),
        },
        expected = {
            title = "Talk to Quest Giver",
            subtext = "Continue your journey",
            clusterKind = "non_actionable_fallback",
            debugReason = "instruction_neighbor_action",
            subtextReason = "instruction_neighbor_action",
            routePresentationAllowed = true,
            semanticKind = EXPECT_NIL,
            semanticTravelType = EXPECT_NIL,
        },
    },
    {
        id = "confirm_instruction_sanitizes_tooltip_template_tokens",
        category = "instruction_neighbor",
        classification = "approved_improvement",
        sourceNote = "Current-goal instruction fallback should sanitize raw tooltip template tokens before using them as subtext.",
        currentGoalNum = 1,
        context = {
            rawArrowTitle = "Hold this position",
            kind = "guide",
            source = "step.goal#1",
            mapID = 539,
            x = 0.3000,
            y = 0.4000,
        },
        facts = {
            makeFact(1, { action = "confirm", status = "incomplete", questid = 33120, mapID = 539, x = 0.3000, y = 0.4000, text = "Hold this position", tooltip = "Wait for #10# enemies to arrive" }),
        },
        expected = {
            title = "Hold this position",
            subtext = "Wait for 10 enemies to arrive",
            clusterKind = "non_actionable_fallback",
            debugReason = "current_goal_instruction",
            subtextReason = "current_goal_instruction",
        },
    },
    {
        id = "q_objective_tooltip_template_prefers_passive_kill_context",
        category = "objective_text",
        classification = "approved_improvement",
        sourceNote = "Non-actionable q objectives with templated tooltip counts should fall through to nearby passive kill context instead of surfacing the raw tooltip template.",
        currentGoalNum = 2,
        context = {
            rawArrowTitle = "Slay 5 Fel-cursed Creatures",
            kind = "guide",
            source = "pointer.ArrowFrame.waypoint",
            mapID = 539,
            x = 0.2419,
            y = 0.1871,
        },
        facts = {
            makeFact(1, { action = "kill", status = "passive", npcid = 73101, text = "Kill enemies" }),
            makeFact(2, { action = "q", status = "incomplete", questid = 33120, mapID = 539, x = 0.2419, y = 0.1871, text = "Slay 10 Fel-cursed Creatures", tooltip = "Slay #10# Fel-cursed Creatures" }),
        },
        expected = {
            title = "Slay 5 Fel-cursed Creatures",
            subtext = "Kill enemies",
            clusterKind = "non_actionable_fallback",
            debugReason = "passive_kill_fallback",
            subtextReason = "passive_kill_fallback",
        },
    },
    {
        id = "q_objective_text_fallback",
        category = "objective_text",
        classification = "approved_improvement",
        sourceNote = "Non-actionable q objectives should prefer nearby text instructions over generic tooltip guidance.",
        currentGoalNum = 4,
        context = {
            rawArrowTitle = "Defend the Camp",
            kind = "guide",
            source = "pointer.ArrowFrame.waypoint",
            mapID = 539,
            x = 0.5132,
            y = 0.2850,
        },
        facts = {
            makeFact(1, { action = "text", text = "Watch the dialogue", tooltip = "Watch the dialogue" }),
            makeFact(2, { action = "text", text = "Kill the enemies that attack", tooltip = "Kill the enemies that attack" }),
            makeFact(3, { tooltip = "Be careful not to pull too many." }),
            makeFact(4, { action = "q", status = "incomplete", questid = 34779, mapID = 539, x = 0.5132, y = 0.2850, text = "Defend the Camp", tooltip = "Defend the Camp" }),
        },
        expected = {
            title = "Defend the Camp",
            subtext = "Kill the enemies that attack",
            clusterKind = "non_actionable_fallback",
            debugReason = "non_actionable_objective_text_fallback",
            subtextReason = "non_actionable_objective_text_fallback",
        },
    },
    {
        id = "get_objective_passive_kill_preferred_over_guidance",
        category = "objective_text",
        classification = "approved_improvement",
        sourceNote = "Non-actionable get objectives should prefer nearby passive kill context over generic guidance tips.",
        currentGoalNum = 3,
        context = {
            rawArrowTitle = "Collect 1000 Raw Elekk Steaks",
            kind = "route",
            legKind = "destination",
            source = "step.goal#3",
            mapID = 539,
            x = 0.6250,
            y = 0.3560,
        },
        facts = {
            makeFact(1, { action = "kill", text = "Kill Rockhide enemies" }),
            makeFact(2, { tooltip = "They look like elephants." }),
            makeFact(3, { action = "get", status = "incomplete", questid = 33084, mapID = 539, x = 0.6250, y = 0.3560, text = "Collect 1000 Raw Elekk Steaks (0/1000)" }),
        },
        expected = {
            title = "Collect 1000 Raw Elekk Steaks",
            subtext = "Kill Rockhide enemies",
            clusterKind = "non_actionable_fallback",
            debugReason = "passive_kill_fallback",
            subtextReason = "passive_kill_fallback",
            routePresentationAllowed = true,
        },
    },
    {
        id = "objective_helper_cluster_prefers_setup_guidance",
        category = "objective_text",
        classification = "approved_improvement",
        sourceNote = "Multi-helper objective clusters should prefer the setup guidance immediately before the helper cluster over a single ingredient-specific helper action.",
        currentGoalNum = 13,
        context = {
            rawArrowTitle = "Complete the Elixir",
            kind = "guide",
            source = "pointer.ArrowFrame.waypoint",
            mapID = 539,
            x = 0.5358,
            y = 0.5729,
        },
        facts = {
            makeFact(1, { action = "text", text = "Watch the dialogue", tooltip = "Watch the dialogue" }),
            makeFact(2, { tooltip = "Fiona will tell you the ingredients she needs as she cooks." }),
            makeFact(3, { tooltip = "Click each ingredient when she tells you to." }),
            makeFact(4, { tooltip = "You can reach all of the ingredients from this location." }),
            makeFact(5, { action = "click", npcid = 108395, text = "Click Swamplighter Venom" }),
            makeFact(6, { tooltip = "Click these when she says \"toxic\"." }),
            makeFact(7, { action = "click", npcid = 108396, text = "Click Riotvine" }),
            makeFact(8, { tooltip = "Click these when she says \"wriggle around\"." }),
            makeFact(9, { action = "click", npcid = 108394, text = "Click Riverbeast Heart" }),
            makeFact(10, { tooltip = "Click these when she says \"something meaty\"." }),
            makeFact(11, { action = "click", npcid = 225998, text = "Click Moonlit Herb" }),
            makeFact(12, { tooltip = "Click these when she says \"give a nice glow\"." }),
            makeFact(13, { action = "q", status = "warning", questid = 33788, mapID = 539, x = 0.5358, y = 0.5729, text = "Complete the Elixir", tooltip = "Complete the Elixir" }),
        },
        expected = {
            title = "Complete the Elixir",
            subtext = "You can reach all of the ingredients from this location.",
            clusterKind = "non_actionable_fallback",
            debugReason = "non_actionable_objective_guidance_fallback",
            subtextReason = "non_actionable_objective_guidance_fallback",
        },
    },
    {
        id = "objective_interaction_chain_promotes_talk_title",
        category = "objective_text",
        classification = "approved_improvement",
        sourceNote = "A talk-to interaction followed by a gossip choice should promote the interaction title over the raw objective text for non-actionable objective seeds.",
        currentGoalNum = 3,
        context = {
            rawArrowTitle = "Obtain an Orc Disguise From Sylene",
            kind = "route",
            legKind = "destination",
            source = "step.goal#3",
            mapID = 539,
            x = 0.4065,
            y = 0.5461,
        },
        facts = {
            makeFact(1, { action = "talk", npcid = 73106, text = "Talk to Sylene" }),
            makeFact(2, { action = "gossip", text = "Select \"I need a Shadowmoon orc illusion.\"", tooltip = "Select \"I need a Shadowmoon orc illusion.\"" }),
            makeFact(3, { action = "q", status = "incomplete", questid = 33080, mapID = 539, x = 0.4065, y = 0.5461, text = "Obtain an Orc Disguise From Sylene", tooltip = "Obtain an Orc Disguise From Sylene" }),
        },
        expected = {
            title = "Talk to Sylene",
            subtext = "Select \"I need a Shadowmoon orc illusion.\"",
            clusterKind = "non_actionable_fallback",
            debugReason = "non_actionable_interaction_chain_fallback",
            subtextReason = "non_actionable_interaction_chain_fallback",
            routePresentationAllowed = true,
            headerGoalNum = 1,
        },
    },
    {
        id = "objective_interaction_chain_bridges_text_to_gossip",
        category = "objective_text",
        classification = "approved_improvement",
        sourceNote = "A q objective should still promote the talk/gossip interaction chain when informational text and lightweight guidance sit between the q seed and the gossip choice.",
        currentGoalNum = 6,
        context = {
            rawArrowTitle = "Escort Your Garrison Army to Karabor",
            kind = "guide",
            source = "pointer.ArrowFrame.waypoint",
            mapID = 539,
            x = 0.5223,
            y = 0.4604,
        },
        facts = {
            makeFact(1, { action = "talk", npcid = 77312, text = "Talk to Vindicator Maraad" }),
            makeFact(2, { action = "gossip", text = "Select \"I am ready to join the attack against the Iron Horde.\"", tooltip = "Select \"I am ready to join the attack against the Iron Horde.\"" }),
            makeFact(3, { action = "text", text = "Kill enemies around this area", tooltip = "Kill enemies around this area" }),
            makeFact(4, { tooltip = "They are on the ground as you fly." }),
            makeFact(5, { tooltip = "Use the ability on your action bar." }),
            makeFact(6, { action = "q", status = "incomplete", questid = 33255, mapID = 539, x = 0.5223, y = 0.4604, text = "Escort Your Garrison Army to Karabor", tooltip = "Escort Your Garrison Army to Karabor" }),
        },
        expected = {
            title = "Talk to Vindicator Maraad",
            subtext = "Select \"I am ready to join the attack against the Iron Horde.\"",
            clusterKind = "non_actionable_fallback",
            debugReason = "non_actionable_interaction_chain_fallback",
            subtextReason = "non_actionable_interaction_chain_fallback",
            headerGoalNum = 1,
        },
    },
    {
        id = "objective_interaction_chain_bridges_passive_kill_to_gossip",
        category = "objective_text",
        classification = "approved_improvement",
        sourceNote = "A q objective should still promote the talk/gossip interaction chain when passive kill text and lightweight guidance sit between the q seed and the gossip choice.",
        currentGoalNum = 5,
        context = {
            rawArrowTitle = "Defeat Soulbinder Halaari",
            kind = "guide",
            source = "step.goal#5",
            mapID = 535,
            x = 0.5734,
            y = 0.5269,
        },
        facts = {
            makeFact(1, { action = "talk", status = "passive", npcid = 79977, text = "Talk to Soulbinder Halaari" }),
            makeFact(2, { action = "gossip", status = "passive", text = "Select \"So be it.\"", tooltip = "Select \"So be it.\"" }),
            makeFact(3, { action = "kill", status = "passive", npcid = 79977, text = "Kill Soulbinder Halaari" }),
            makeFact(4, { status = "passive", tooltip = "She will eventually surrender." }),
            makeFact(5, { action = "q", status = "incomplete", questid = 34777, mapID = 535, x = 0.5734, y = 0.5269, text = "Defeat Soulbinder Halaari", tooltip = "Defeat Soulbinder Halaari" }),
        },
        expected = {
            title = "Talk to Soulbinder Halaari",
            subtext = "Select \"So be it.\"",
            clusterKind = "non_actionable_fallback",
            debugReason = "non_actionable_interaction_chain_fallback",
            subtextReason = "non_actionable_interaction_chain_fallback",
            headerGoalNum = 1,
        },
    },
    {
        id = "scenario_goal_prefers_objective_text_subtext",
        category = "non_actionable_scenario",
        classification = "approved_improvement",
        sourceNote = "Incomplete scenariogoal should keep its current title and use nearby objective text as subtext.",
        currentGoalNum = 3,
        context = {
            rawArrowTitle = "Defend K'ara Until it Becomes Fully Empowered",
            kind = "guide",
            source = "pointer.ArrowFrame.waypoint",
            mapID = 539,
            x = 0.7966,
            y = 0.4662,
        },
        facts = {
            makeFact(1, { action = "text", status = "passive", text = "Kill the enemies that attack in waves", tooltip = "Kill the enemies that attack in waves" }),
            makeFact(2, { status = "passive", tooltip = "Fill up the bottom at the bottom of the screen." }),
            makeFact(3, { action = "scenariogoal", status = "incomplete", questid = 33256, mapID = 539, x = 0.7966, y = 0.4662, text = "Defend K'ara Until it Becomes Fully Empowered", tooltip = "Defend K'ara Until it Becomes Fully Empowered" }),
        },
        expected = {
            title = "Defend K'ara Until it Becomes Fully Empowered",
            subtext = "Kill the enemies that attack in waves",
            clusterKind = "non_actionable_fallback",
            debugReason = "non_actionable_objective_text_fallback",
            subtextReason = "non_actionable_objective_text_fallback",
        },
    },
    {
        id = "scenario_end_prefers_passive_kill_subtext",
        category = "non_actionable_scenario",
        classification = "approved_improvement",
        sourceNote = "Incomplete scenarioend should keep its current title and prefer nearby passive kill context over generic tooltip lines.",
        currentGoalNum = 4,
        context = {
            rawArrowTitle = "Defeat Commander Vorka",
            kind = "guide",
            source = "pointer.ArrowFrame.waypoint",
            mapID = 539,
            x = 0.8054,
            y = 0.4657,
        },
        facts = {
            makeFact(1, { action = "kill", status = "passive", npcid = 74715, text = "Kill Commander Vorka" }),
            makeFact(2, { status = "passive", tooltip = "Avoid the circles on the ground." }),
            makeFact(3, { status = "passive", tooltip = "Kill the enemies he summons quickly." }),
            makeFact(4, { action = "scenarioend", status = "incomplete", questid = 33256, mapID = 539, x = 0.8054, y = 0.4657, text = "Defeat Commander Vorka", tooltip = "Defeat Commander Vorka" }),
        },
        expected = {
            title = "Defeat Commander Vorka",
            subtext = "Kill Commander Vorka",
            clusterKind = "non_actionable_fallback",
            debugReason = "passive_kill_fallback",
            subtextReason = "passive_kill_fallback",
        },
    },
    {
        id = "scenario_start_click_helper",
        category = "non_actionable_scenario",
        classification = "approved_improvement",
        sourceNote = "scenariostart step should surface a nearby click helper as subtext.",
        currentGoalNum = 2,
        context = {
            rawArrowTitle = "Begin the Daggerspine Point Scenario",
            kind = "route",
            legKind = "destination",
            source = "step.goal#2",
            mapID = 2395,
            x = 0.3756,
            y = 0.6526,
        },
        facts = {
            makeFact(1, { action = "click", text = "Click Curious Obelisk" }),
            makeFact(2, { action = "scenariostart", status = "incomplete", mapID = 2395, x = 0.3756, y = 0.6526, text = "Begin the Daggerspine Point Scenario", tooltip = "Begin the Daggerspine Point Scenario" }),
        },
        expected = {
            title = "Begin the Daggerspine Point Scenario",
            subtext = "Click Curious Obelisk",
            clusterKind = "non_actionable_fallback",
            debugReason = "non_actionable_helper_action_fallback",
            subtextReason = "non_actionable_helper_action_fallback",
            routePresentationAllowed = true,
        },
    },
    {
        id = "objective_gossip_only_keeps_objective_title",
        category = "objective_text",
        classification = "parity",
        sourceNote = "A standalone gossip header without a preceding primary interaction header should keep the existing objective-title presentation.",
        currentGoalNum = 2,
        context = {
            rawArrowTitle = "Obtain an Orc Disguise From Sylene",
            kind = "route",
            legKind = "destination",
            source = "step.goal#2",
            mapID = 539,
            x = 0.4065,
            y = 0.5461,
        },
        facts = {
            makeFact(1, { action = "gossip", text = "Select \"I need a Shadowmoon orc illusion.\"", tooltip = "Select \"I need a Shadowmoon orc illusion.\"" }),
            makeFact(2, { action = "q", status = "incomplete", questid = 33080, mapID = 539, x = 0.4065, y = 0.5461, text = "Obtain an Orc Disguise From Sylene", tooltip = "Obtain an Orc Disguise From Sylene" }),
        },
        expected = {
            title = "Obtain an Orc Disguise From Sylene",
            subtext = "Select \"I need a Shadowmoon orc illusion.\"",
            clusterKind = "non_actionable_fallback",
            debugReason = "non_actionable_header_fallback",
            subtextReason = "non_actionable_header_fallback",
            routePresentationAllowed = true,
            headerGoalNum = 1,
        },
    },
    {
        id = "objective_gossip_only_bridges_passive_kill_to_subtext",
        category = "objective_text",
        classification = "approved_improvement",
        sourceNote = "A standalone gossip helper should still surface as subtext when passive kill text sits between the q seed and the gossip line.",
        currentGoalNum = 4,
        context = {
            rawArrowTitle = "Defeat Soulbinder Halaari",
            kind = "guide",
            source = "step.goal#4",
            mapID = 535,
            x = 0.5734,
            y = 0.5269,
        },
        facts = {
            makeFact(1, { action = "gossip", status = "passive", text = "Select \"So be it.\"", tooltip = "Select \"So be it.\"" }),
            makeFact(2, { action = "kill", status = "passive", npcid = 79977, text = "Kill Soulbinder Halaari" }),
            makeFact(3, { status = "passive", tooltip = "She will eventually surrender." }),
            makeFact(4, { action = "q", status = "incomplete", questid = 34777, mapID = 535, x = 0.5734, y = 0.5269, text = "Defeat Soulbinder Halaari", tooltip = "Defeat Soulbinder Halaari" }),
        },
        expected = {
            title = "Defeat Soulbinder Halaari",
            subtext = "Select \"So be it.\"",
            clusterKind = "non_actionable_fallback",
            debugReason = "non_actionable_header_fallback",
            subtextReason = "non_actionable_header_fallback",
            headerGoalNum = 1,
        },
    },
    {
        id = "detached_q_suppressed_by_gossip",
        category = "detached_q",
        classification = "parity",
        sourceNote = "Detached q title detour must stay suppressed when a better local header helper exists.",
        currentGoalNum = 1,
        context = {
            rawArrowTitle = "Talk to Shelly Hamby",
            kind = "guide",
            source = "step.goal#1",
            mapID = 582,
            x = 0.3250,
            y = 0.3440,
        },
        facts = {
            makeFact(1, { action = "talk", mapID = 582, x = 0.3250, y = 0.3440, text = "Talk to Shelly Hamby" }),
            makeFact(2, { action = "gossip", text = "Select \"Gather Shelly's report.\"" }),
            makeFact(3, { action = "q", status = "incomplete", questid = 35176, text = "Gather Shelly's Report", tooltip = "Gather Shelly's Report" }),
        },
        expected = {
            title = "Talk to Shelly Hamby",
            subtext = "Select \"Gather Shelly's report.\"",
            clusterKind = "non_actionable_fallback",
            debugReason = "non_actionable_header_fallback",
            subtextReason = "non_actionable_header_fallback",
        },
    },
    {
        id = "home_step_header_fallback_semantic_inn",
        category = "instruction_neighbor",
        classification = "approved_improvement",
        sourceNote = "Home-setting steps should classify as inn travel when the header fallback keeps the inkeeper talk line as subtext.",
        currentGoalNum = 2,
        context = {
            rawArrowTitle = "Make Highpass Inn Your Home",
            kind = "route",
            legKind = "destination",
            source = "step.goal#2",
            mapID = 543,
            x = 0.5323,
            y = 0.5979,
        },
        facts = {
            makeFact(1, { action = "talk", npcid = 85968, mapID = 543, x = 0.5323, y = 0.5979, text = "Talk to Trader Yula" }),
            makeFact(2, { action = "home", status = "incomplete", mapID = 543, x = 0.5323, y = 0.5979, text = "Make Highpass Inn Your Home" }),
        },
        expected = {
            title = "Make Highpass Inn Your Home",
            subtext = "Talk to Trader Yula",
            clusterKind = "non_actionable_fallback",
            debugReason = "non_actionable_header_fallback",
            subtextReason = "non_actionable_header_fallback",
            routePresentationAllowed = true,
            headerGoalNum = 1,
            semanticKind = "travel",
            semanticTravelType = "inn",
        },
    },
    {
        id = "detached_warning_q_clicknpc",
        category = "detached_q",
        classification = "approved_improvement",
        sourceNote = "Warning q should support detached quest-title presentation over clicknpc context.",
        currentGoalNum = 1,
        context = {
            rawArrowTitle = "Click Architect Table",
            kind = "route",
            legKind = "destination",
            source = "step.goal#1",
            mapID = 582,
            x = 0.4110,
            y = 0.4900,
        },
        facts = {
            makeFact(1, { action = "clicknpc", mapID = 582, x = 0.4110, y = 0.4900, text = "Click Architect Table" }),
            makeFact(2, { tooltip = "Select the \"Large\" tab at the top." }),
            makeFact(3, { tooltip = "Drag the \"Barracks\" to a Large Empty Plot." }),
            makeFact(4, { action = "q", status = "warning", questid = 34587, text = "Build Your Barracks", tooltip = "Build Your Barracks" }),
        },
        expected = {
            title = "Build Your Barracks",
            subtext = "Click Architect Table",
            clusterKind = "normal",
            debugReason = "detached_quest_title_fallback",
            subtextReason = "context_header",
            routePresentationAllowed = true,
        },
    },
    {
        id = "detached_accept_title_detour",
        category = "detached_accept",
        classification = "approved_improvement",
        sourceNote = "Detached accept should present the quest title with the live talk header as subtext.",
        currentGoalNum = 1,
        context = {
            rawArrowTitle = "Talk to Field Marshal Brock",
            kind = "route",
            legKind = "destination",
            source = "step.goal#1",
            mapID = 100,
            x = 0.6829,
            y = 0.2855,
        },
        patches = {
            { path = "C_QuestLog.GetLogIndexForQuestID", value = function() return 0 end },
        },
        facts = {
            makeFact(1, { action = "talk", mapID = 100, x = 0.6829, y = 0.2855, text = "Talk to Field Marshal Brock" }),
            makeFact(2, { action = "accept", status = "incomplete", questid = 10394, text = "Accept 'Disruption - Forge Camp: Mageddon'" }),
        },
        expected = {
            title = "Accept 'Disruption - Forge Camp: Mageddon'",
            subtext = "Talk to Field Marshal Brock",
            clusterKind = "normal",
            debugReason = "detached_quest_title_fallback",
            subtextReason = "context_header",
            routePresentationAllowed = true,
        },
    },
    {
        id = "detached_turnin_title_detour",
        category = "detached_turnin",
        classification = "approved_improvement",
        sourceNote = "Detached turnin should present the quest title when live dialog confirms the turnin is current.",
        currentGoalNum = 1,
        context = {
            rawArrowTitle = "Talk to Baros Alexston",
            kind = "route",
            legKind = "destination",
            source = "step.goal#1",
            mapID = 582,
            x = 0.4120,
            y = 0.4930,
        },
        patches = {
            { path = "C_GossipInfo.GetAvailableQuests", value = function() return {} end },
            { path = "C_GossipInfo.GetActiveQuests", value = function()
                return {
                    { questID = 34586, title = "Establish Your Garrison", isComplete = true },
                }
            end },
        },
        facts = {
            makeFact(1, { action = "talk", npcid = 77209, mapID = 582, x = 0.4120, y = 0.4930, text = "Talk to Baros Alexston" }),
            makeFact(2, { text = "?" }),
            makeFact(3, { text = "?" }),
            makeFact(4, { text = "?" }),
            makeFact(5, { action = "turnin", status = "incomplete", questid = 34586, questTitle = "Establish Your Garrison", text = "Turn in 'Establish Your Garrison'" }),
        },
        expected = {
            title = "Turn in 'Establish Your Garrison'",
            subtext = "Talk to Baros Alexston",
            clusterKind = "normal",
            debugReason = "detached_quest_title_fallback",
            subtextReason = "context_header",
            routePresentationAllowed = true,
        },
    },
    {
        id = "detached_turnin_title_detour_without_live",
        category = "detached_turnin",
        classification = "approved_improvement",
        sourceNote = "Detached turnin should still present when it is the best detached quest candidate and stricter same-target/live checks fail.",
        currentGoalNum = 1,
        context = {
            rawArrowTitle = "Talk to Baros Alexston",
            kind = "route",
            legKind = "destination",
            source = "step.goal#1",
            mapID = 582,
            x = 0.4120,
            y = 0.4930,
        },
        patches = {
            { path = "C_GossipInfo.GetAvailableQuests", value = function() return {} end },
            { path = "C_GossipInfo.GetActiveQuests", value = function() return {} end },
        },
        facts = {
            makeFact(1, { action = "talk", npcid = 77209, mapID = 582, x = 0.4120, y = 0.4930, text = "Talk to Baros Alexston" }),
            makeFact(5, { action = "turnin", status = "incomplete", questid = 35905, questTitle = "Supply Drop", text = "Turn in 'Supply Drop'" }),
        },
        expected = {
            title = "Turn in 'Supply Drop'",
            subtext = "Talk to Baros Alexston",
            clusterKind = "normal",
            debugReason = "detached_quest_title_fallback",
            subtextReason = "context_header",
            routePresentationAllowed = true,
        },
    },
    {
        id = "detached_turnin_accept_priority_without_live",
        category = "detached_turnin",
        classification = "approved_improvement",
        sourceNote = "When live confirmation is absent, detached turnin should still outrank detached accept in the same step.",
        currentGoalNum = 1,
        context = {
            rawArrowTitle = "Talk to Baros Alexston",
            kind = "route",
            legKind = "destination",
            source = "step.goal#1",
            mapID = 582,
            x = 0.4120,
            y = 0.4930,
        },
        patches = {
            { path = "C_GossipInfo.GetAvailableQuests", value = function() return {} end },
            { path = "C_GossipInfo.GetActiveQuests", value = function() return {} end },
            { path = "C_QuestLog.GetLogIndexForQuestID", value = function() return 0 end },
        },
        facts = {
            makeFact(1, { action = "talk", npcid = 77209, mapID = 582, x = 0.4120, y = 0.4930, text = "Talk to Baros Alexston" }),
            makeFact(2, { action = "turnin", status = "incomplete", questid = 35905, questTitle = "Supply Drop", text = "Turn in 'Supply Drop'" }),
            makeFact(3, { action = "accept", status = "incomplete", questid = 35906, questTitle = "New Orders", text = "Accept 'New Orders'" }),
        },
        expected = {
            title = "Turn in 'Supply Drop'",
            subtext = "Talk to Baros Alexston",
            clusterKind = "normal",
            debugReason = "detached_quest_title_fallback",
            subtextReason = "context_header",
            routePresentationAllowed = true,
        },
    },
    {
        id = "get_click_helper",
        category = "helper_action",
        classification = "approved_improvement",
        sourceNote = "Get objective should surface a nearby click helper as subtext.",
        currentGoalNum = 3,
        context = {
            rawArrowTitle = "Collect Draenei Bucket (0/1)",
            kind = "route",
            legKind = "destination",
            source = "step.goal#3",
            mapID = 539,
            x = 0.5179,
            y = 0.3253,
        },
        facts = {
            makeFact(1, { action = "click", text = "Click Draenei Buckets" }),
            makeFact(2, { tooltip = "They look like small buckets of water on the ground around this area." }),
            makeFact(3, { action = "get", status = "incomplete", questid = 33813, npcid = 111908, mapID = 539, x = 0.5179, y = 0.3253, text = "Collect Draenei Bucket (0/1)" }),
        },
        expected = {
            title = "Collect Draenei Bucket (0/1)",
            subtext = "Click Draenei Buckets",
            clusterKind = "non_actionable_fallback",
            debugReason = "non_actionable_helper_action_fallback",
            subtextReason = "non_actionable_helper_action_fallback",
            routePresentationAllowed = true,
        },
    },
    {
        id = "q_click_helper",
        category = "helper_action",
        classification = "approved_improvement",
        sourceNote = "Quest objective should surface a nearby click helper as subtext without broadening click into a global header action.",
        currentGoalNum = 2,
        context = {
            rawArrowTitle = "Find the Blueprints",
            kind = "route",
            legKind = "destination",
            source = "step.goal#2",
            mapID = 582,
            x = 0.4518,
            y = 0.4045,
        },
        facts = {
            makeFact(1, { action = "click", npcid = 231855, text = "Click Garrison Blueprint: Barracks" }),
            makeFact(2, { action = "q", status = "incomplete", questid = 34587, mapID = 582, x = 0.4518, y = 0.4045, text = "Find the Blueprints", tooltip = "Find the Blueprints" }),
        },
        expected = {
            title = "Find the Blueprints",
            subtext = "Click Garrison Blueprint: Barracks",
            clusterKind = "non_actionable_fallback",
            debugReason = "non_actionable_helper_action_fallback",
            subtextReason = "non_actionable_helper_action_fallback",
            routePresentationAllowed = true,
        },
    },
    {
        id = "q_use_helper",
        category = "helper_action",
        classification = "approved_improvement",
        sourceNote = "Quest objective should surface a nearby use helper as subtext.",
        currentGoalNum = 4,
        context = {
            rawArrowTitle = "Douse the Bookshelf Fire",
            kind = "route",
            legKind = "destination",
            source = "step.goal#4",
            mapID = 539,
            x = 0.5209,
            y = 0.3286,
        },
        facts = {
            makeFact(1, { action = "use", text = "Use the Draenei Bucket" }),
            makeFact(2, { tooltip = "Use it on the blue fire." }),
            makeFact(3, { tooltip = "Inside the building." }),
            makeFact(4, { action = "q", status = "incomplete", questid = 33813, mapID = 539, x = 0.5209, y = 0.3286, text = "Douse the Bookshelf Fire", tooltip = "Douse the Bookshelf Fire" }),
        },
        expected = {
            title = "Douse the Bookshelf Fire",
            subtext = "Use the Draenei Bucket",
            clusterKind = "non_actionable_fallback",
            debugReason = "non_actionable_helper_action_fallback",
            subtextReason = "non_actionable_helper_action_fallback",
            routePresentationAllowed = true,
        },
    },
    {
        id = "havebuff_click_helper",
        category = "helper_action",
        classification = "approved_improvement",
        sourceNote = "Havebuff objectives should surface a nearby click helper as subtext.",
        currentGoalNum = 2,
        context = {
            rawArrowTitle = "Carry the Crystal",
            kind = "route",
            legKind = "destination",
            source = "step.goal#2",
            mapID = 539,
            x = 0.5680,
            y = 0.3428,
        },
        facts = {
            makeFact(1, { action = "click", text = "Click Charged Resonance Crystal" }),
            makeFact(2, { action = "havebuff", status = "incomplete", questid = 34780, mapID = 539, x = 0.5680, y = 0.3428, text = "Carry the Crystal", tooltip = "Carry the Crystal" }),
        },
        expected = {
            title = "Carry the Crystal",
            subtext = "Click Charged Resonance Crystal",
            clusterKind = "non_actionable_fallback",
            debugReason = "non_actionable_helper_action_fallback",
            subtextReason = "non_actionable_helper_action_fallback",
            routePresentationAllowed = true,
        },
    },
    {
        id = "carrier_portal_q_click_helper_suppressed",
        category = "route_policy",
        classification = "parity",
        sourceNote = "Carrier-leg portal titles should not reclassify quest helper fallback as travel or keep helper subtext alive.",
        currentGoalNum = 3,
        context = {
            rawArrowTitle = "Click the Portal to Stormwind City",
            kind = "route",
            legKind = "carrier",
            source = "step.goal#3",
            mapID = 2302,
            x = 0.4104,
            y = 0.4553,
        },
        facts = {
            makeFact(1, { action = "click", text = "Click Sturdy Chest" }),
            makeFact(2, { tooltip = "Behind the rocks." }),
            makeFact(3, { action = "q", status = "incomplete", questid = 83677, mapID = 2302, x = 0.4104, y = 0.4553, text = "Loot the Treasure", tooltip = "Loot the Treasure" }),
        },
        expected = {
            title = "Click the Portal to Stormwind City",
            subtext = EXPECT_NIL,
            clusterKind = "non_actionable_fallback",
            debugReason = "non_actionable_helper_action_fallback",
            subtextReason = "carrier_leg_suppressed",
            routePresentationAllowed = false,
        },
    },
    {
        id = "passive_kill_preferred_over_get",
        category = "passive_fallback",
        classification = "approved_improvement",
        sourceNote = "Passive kill should win over passive get when both are viable late subtext fallbacks.",
        currentGoalNum = 3,
        context = {
            rawArrowTitle = "Accept 'Disruption - Forge Camp: Mageddon'",
            kind = "guide",
            source = "step.goal#3",
            mapID = 37,
            x = 0.3039,
            y = 0.9137,
        },
        facts = {
            makeFact(1, { action = "kill", text = "Kill Daetan Swiftplume" }),
            makeFact(2, { action = "get", text = "Collect Noblegarden Trinket (0)" }),
            makeFact(3, { action = "accept", status = "incomplete", questid = 10394, mapID = 37, x = 0.3039, y = 0.9137, text = "Accept 'Disruption - Forge Camp: Mageddon'" }),
        },
        expected = {
            title = "Accept 'Disruption - Forge Camp: Mageddon'",
            subtext = "Kill Daetan Swiftplume",
            clusterKind = "normal",
            debugReason = EXPECT_NIL,
            subtextReason = "passive_kill_fallback",
        },
    },
    {
        id = "passive_get_fallback",
        category = "passive_fallback",
        classification = "approved_improvement",
        sourceNote = "Passive get/collect should remain available as the late subtext fallback when kill is absent.",
        currentGoalNum = 2,
        context = {
            rawArrowTitle = "Accept 'Disruption - Forge Camp: Mageddon'",
            kind = "guide",
            source = "step.goal#2",
            mapID = 37,
            x = 0.3039,
            y = 0.9137,
        },
        facts = {
            makeFact(1, { action = "get", text = "Collect Noblegarden Trinket (0)" }),
            makeFact(2, { action = "accept", status = "incomplete", questid = 10394, mapID = 37, x = 0.3039, y = 0.9137, text = "Accept 'Disruption - Forge Camp: Mageddon'" }),
        },
        expected = {
            title = "Accept 'Disruption - Forge Camp: Mageddon'",
            subtext = "Collect Noblegarden Trinket (0)",
            clusterKind = "normal",
            debugReason = EXPECT_NIL,
            subtextReason = "passive_get_fallback",
        },
    },
    {
        id = "carrier_leg_suppressed",
        category = "route_policy",
        classification = "parity",
        sourceNote = "Quest-derived presentation should not ride along on carrier route legs.",
        currentGoalNum = 2,
        context = {
            rawArrowTitle = "Accept 'Quest A'",
            kind = "route",
            legKind = "carrier",
            source = "step.goal#2",
            mapID = 100,
            x = 0.1000,
            y = 0.2000,
        },
        facts = {
            makeFact(1, { action = "talk", text = "Talk to Commander Althea" }),
            makeFact(2, { action = "accept", status = "incomplete", questid = 3001, mapID = 100, x = 0.1000, y = 0.2000, text = "Accept 'Quest A'" }),
        },
        expected = {
            title = "Accept 'Quest A'",
            subtext = EXPECT_NIL,
            clusterKind = "normal",
            debugReason = EXPECT_NIL,
            subtextReason = "carrier_leg_suppressed",
            routePresentationAllowed = false,
        },
    },
    -- ============================================================
    -- Canonical goal selector cases
    -- ============================================================
    {
        id = "canonical_scenariogoal_completed_stage_advances_to_next_objective",
        category = "canonical_goal",
        classification = "approved_improvement",
        sourceNote = "Completed same-target scenariogoal should advance to the next incomplete scenariogoal, and the non-actionable snapshot should let that current scenario objective own the title.",
        currentGoalNum = 3,
        context = {
            rawArrowTitle = "Clear a Path to Karabor Harbor",
            kind = "route",
            legKind = "destination",
            source = "step.goal#3",
            mapID = 539,
            x = 0.7972,
            y = 0.4686,
        },
        facts = {
            makeFact(1, { action = "text", text = "Kill enemies around this area", tooltip = "Kill enemies around this area" }),
            makeFact(2, { tooltip = "Kill enemies as you walk, to clear a path for your allies." }),
            makeFact(3, { action = "scenariogoal", status = "complete", questid = 33256, mapID = 539, x = 0.7972, y = 0.4686, text = "Clear a Path to Karabor Harbor", tooltip = "Clear a Path to Karabor Harbor" }),
            makeFact(4, { action = "scenariogoal", status = "incomplete", questid = 33256, mapID = 539, x = 0.7972, y = 0.4686, text = "Meet Yrel at the Karabor Harbor", tooltip = "Meet Yrel at the Karabor Harbor" }),
        },
        expected = {
            title = "Meet Yrel at the Karabor Harbor",
            subtext = EXPECT_NIL,
            clusterKind = "non_actionable_fallback",
            debugReason = "current_goal_non_actionable_title",
            subtextReason = EXPECT_NIL,
            routePresentationAllowed = true,
        },
    },
    {
        id = "canonical_middle_complete_accept_selects_first_remaining",
        category = "canonical_goal",
        classification = "approved_improvement",
        sourceNote = "Canonical selector provides the first incomplete accept when raw current is a completed middle sibling. Resolver receives canonical goal num and anchors correctly.",
        currentGoalNum = 3,
        context = {
            rawArrowTitle = "Accepted 'Quest B'",
            kind = "guide",
            source = "step.goal#3",
            mapID = 100,
            x = 0.5000,
            y = 0.5000,
        },
        facts = {
            makeFact(1, { action = "talk", text = "Talk to Warden Thelassa" }),
            makeFact(2, { action = "accept", status = "incomplete", questid = 9001, mapID = 100, x = 0.5000, y = 0.5000, text = "Accept 'Quest A'" }),
            makeFact(3, { action = "accept", status = "complete",   questid = 9002, mapID = 100, x = 0.5000, y = 0.5000, text = "Accepted 'Quest B'" }),
            makeFact(4, { action = "accept", status = "incomplete", questid = 9003, mapID = 100, x = 0.5000, y = 0.5000, text = "Accept 'Quest C'" }),
        },
        expected = {
            title = "Accept 'Quest A'",
            subtext = "Talk to Warden Thelassa",
            clusterKind = "normal",
            debugReason = EXPECT_NIL,
            subtextReason = "context_header",
        },
    },
    {
        id = "canonical_middle_complete_turnin_selects_first_remaining",
        category = "canonical_goal",
        classification = "approved_improvement",
        sourceNote = "Canonical selector provides the first incomplete turnin when raw current is a completed middle sibling. Resolver receives canonical goal num and anchors correctly.",
        currentGoalNum = 3,
        context = {
            rawArrowTitle = "Turned in 'Quest B'",
            kind = "guide",
            source = "step.goal#3",
            mapID = 101,
            x = 0.3000,
            y = 0.4000,
        },
        facts = {
            makeFact(1, { action = "talk", text = "Talk to Overseer Vinara" }),
            makeFact(2, { action = "turnin", status = "incomplete", questid = 9101, mapID = 101, x = 0.3000, y = 0.4000, text = "Turn in 'Quest A'" }),
            makeFact(3, { action = "turnin", status = "complete",   questid = 9102, mapID = 101, x = 0.3000, y = 0.4000, text = "Turned in 'Quest B'" }),
            makeFact(4, { action = "turnin", status = "incomplete", questid = 9103, mapID = 101, x = 0.3000, y = 0.4000, text = "Turn in 'Quest C'" }),
        },
        expected = {
            title = "Turn in 'Quest A'",
            subtext = "Talk to Overseer Vinara",
            clusterKind = "normal",
            debugReason = EXPECT_NIL,
            subtextReason = "context_header",
        },
    },
    {
        id = "canonical_earliest_completes_advances_to_next",
        category = "canonical_goal",
        classification = "approved_improvement",
        sourceNote = "When the earliest accept completes, canonical advances to the next incomplete. Resolver receives the advanced canonical goal num.",
        currentGoalNum = 3,
        context = {
            rawArrowTitle = "Accept 'Quest B'",
            kind = "guide",
            source = "step.goal#3",
            mapID = 102,
            x = 0.6000,
            y = 0.2000,
        },
        facts = {
            makeFact(1, { action = "talk", text = "Talk to Sergeant Aldric" }),
            makeFact(2, { action = "accept", status = "complete",   questid = 9201, mapID = 102, x = 0.6000, y = 0.2000, text = "Accept 'Quest A'" }),
            makeFact(3, { action = "accept", status = "incomplete", questid = 9202, mapID = 102, x = 0.6000, y = 0.2000, text = "Accept 'Quest B'" }),
            makeFact(4, { action = "accept", status = "incomplete", questid = 9203, mapID = 102, x = 0.6000, y = 0.2000, text = "Accept 'Quest C'" }),
        },
        expected = {
            title = "Accept 'Quest B'",
            subtext = "Talk to Sergeant Aldric",
            clusterKind = "normal",
            debugReason = EXPECT_NIL,
            subtextReason = "preceding_talk_header",
        },
    },
    {
        id = "canonical_nearby_drift_without_bridge_no_override",
        category = "canonical_goal",
        classification = "parity",
        sourceNote = "Coordinate drift alone without shared bridge context does not form a cluster. Canonical selector passes through raw goal unchanged.",
        currentGoalNum = 2,
        context = {
            rawArrowTitle = "Accept 'Quest B'",
            kind = "guide",
            source = "step.goal#2",
            mapID = 103,
            x = 0.7000,
            y = 0.3000,
        },
        facts = {
            makeFact(1, { action = "accept", status = "complete",   questid = 9301, mapID = 103, x = 0.7500, y = 0.3500, text = "Accept 'Quest A'" }),
            makeFact(2, { action = "accept", status = "incomplete", questid = 9302, mapID = 103, x = 0.7000, y = 0.3000, text = "Accept 'Quest B'" }),
        },
        expected = {
            title = "Accept 'Quest B'",
            subtext = EXPECT_NIL,
            clusterKind = "normal",
            debugReason = EXPECT_NIL,
            subtextReason = EXPECT_NIL,
        },
    },
    {
        id = "canonical_raw_later_incomplete_not_earliest",
        category = "canonical_goal",
        classification = "approved_improvement",
        sourceNote = "Raw points at a later incomplete sibling while an earlier incomplete exists in the cluster. Canonical selector provides the earlier incomplete. Resolver receives canonical goal and anchors to it.",
        currentGoalNum = 4,
        context = {
            rawArrowTitle = "Accept 'Quest C'",
            kind = "guide",
            source = "step.goal#4",
            mapID = 104,
            x = 0.4000,
            y = 0.6000,
        },
        facts = {
            makeFact(1, { action = "talk", text = "Talk to Spiritwalker Yalna" }),
            makeFact(2, { action = "accept", status = "incomplete", questid = 9401, mapID = 104, x = 0.4000, y = 0.6000, text = "Accept 'Quest A'" }),
            makeFact(3, { action = "accept", status = "incomplete", questid = 9402, mapID = 104, x = 0.4000, y = 0.6000, text = "Accept 'Quest B'" }),
            makeFact(4, { action = "accept", status = "incomplete", questid = 9403, mapID = 104, x = 0.4000, y = 0.6000, text = "Accept 'Quest C'" }),
        },
        expected = {
            title = "Accept 'Quest A'",
            subtext = "Talk to Spiritwalker Yalna",
            clusterKind = "normal",
            debugReason = EXPECT_NIL,
            subtextReason = "context_header",
        },
    },
    {
        id = "canonical_all_cluster_goals_complete_no_override",
        category = "canonical_goal",
        classification = "parity",
        sourceNote = "When all goals in a same-target cluster are complete, canonical selector passes through raw goal unchanged. Non-actionable fallback path fires.",
        currentGoalNum = 2,
        context = {
            rawArrowTitle = "Accept 'Quest B'",
            kind = "guide",
            source = "step.goal#2",
            mapID = 105,
            x = 0.2000,
            y = 0.8000,
        },
        facts = {
            makeFact(1, { action = "accept", status = "complete", questid = 9501, mapID = 105, x = 0.2000, y = 0.8000, text = "Accept 'Quest A'" }),
            makeFact(2, { action = "accept", status = "complete", questid = 9502, mapID = 105, x = 0.2000, y = 0.8000, text = "Accept 'Quest B'" }),
            makeFact(3, { action = "accept", status = "complete", questid = 9503, mapID = 105, x = 0.2000, y = 0.8000, text = "Accept 'Quest C'" }),
        },
        expected = {
            title = EXPECT_NIL,
            debugReason = "no_visible_actionable_goal",
        },
    },
    {
        id = "visible_kill_goal_keeps_quest_semantics",
        category = "presentation",
        classification = "approved_improvement",
        sourceNote = "A visible incomplete kill goal with no actionable presentation should still expose quest semantics so guide destinations can render quest-family icons instead of falling back to a provider icon.",
        currentGoalNum = 5,
        context = {
            rawArrowTitle = "Kill Witch Lord Morkurk",
            kind = "guide",
            source = "step.goal#5",
            mapID = 535,
            x = 0.6399,
            y = 0.8179,
        },
        facts = {
            makeFact(1, { action = "use", status = "passive", text = "Use the Emergency Rocket Pack" }),
            makeFact(2, { status = "passive", tooltip = "Use it as you fight Witch Lord Morkurk." }),
            makeFact(3, { status = "passive", tooltip = "Use it when he is almost finished casting Astral Annihilation." }),
            makeFact(4, { status = "passive", tooltip = "It will launch you up, to avoid taking damage." }),
            makeFact(5, { action = "kill", status = "incomplete", questid = 34980, npcid = 80335, mapID = 535, x = 0.6399, y = 0.8179, text = "Kill Witch Lord Morkurk" }),
        },
        expected = {
            title = "Kill Witch Lord Morkurk",
            subtext = EXPECT_NIL,
            clusterKind = "normal",
            debugReason = "visible_quest_goal_semantic_fallback",
            subtextReason = EXPECT_NIL,
            headerGoalNum = 5,
            semanticKind = "quest",
            semanticQuestID = 34980,
        },
    },
    {
        id = "canonical_solo_goal_no_cluster_no_override",
        category = "canonical_goal",
        classification = "parity",
        sourceNote = "Single visible quest-action goal has no sibling at same target, so cluster size < 2 and canonical selector passes through. Resolver anchors normally.",
        currentGoalNum = 2,
        context = {
            rawArrowTitle = "Accept 'Quest A'",
            kind = "guide",
            source = "step.goal#2",
            mapID = 106,
            x = 0.5500,
            y = 0.5500,
        },
        facts = {
            makeFact(1, { action = "talk", text = "Talk to Healer Moswen" }),
            makeFact(2, { action = "accept", status = "incomplete", questid = 9601, mapID = 106, x = 0.5500, y = 0.5500, text = "Accept 'Quest A'" }),
        },
        expected = {
            title = "Accept 'Quest A'",
            subtext = "Talk to Healer Moswen",
            clusterKind = "normal",
            debugReason = EXPECT_NIL,
            subtextReason = "context_header",
        },
    },
    {
        id = "live_direct_accept_seed_beats_stale_first_incomplete_turnin",
        category = "live_currentness",
        classification = "approved_improvement",
        sourceNote = "A direct live accept should seed presentation when a same-target canonical turnin remains stale/incomplete but is no longer offered.",
        currentGoalNum = 3,
        context = {
            rawArrowTitle = "Turned in 'Leave Every Soldier Behind'",
            kind = "guide",
            source = "pointer.ArrowFrame.waypoint",
            mapID = 543,
            x = 0.4394,
            y = 0.4887,
        },
        patches = {
            { path = "C_GossipInfo.GetAvailableQuests", value = function() return {} end },
            { path = "C_GossipInfo.GetActiveQuests", value = function() return {} end },
            { path = "GetNumAvailableQuests", value = function() return 0 end },
            { path = "GetNumActiveQuests", value = function() return 0 end },
            { path = "GetQuestID", value = function() return 35139 end },
            { path = "QuestFrame", value = {
                DetailPanel = {
                    IsShown = function() return true end,
                },
            } },
            { path = "QuestInfoTitleHeader", value = {
                GetText = function() return "Eye in the Sky" end,
            } },
            { path = "C_QuestLog.GetLogIndexForQuestID", value = function() return 0 end },
        },
        facts = {
            makeFact(1, { action = "talk", npcid = 84131, text = "Talk to Rexxar" }),
            makeFact(2, { action = "turnin", status = "incomplete", questid = 36223, mapID = 543, x = 0.4394, y = 0.4887, text = "Turn in 'Leave Every Soldier Behind'" }),
            makeFact(3, { action = "turnin", status = "complete", questid = 35128, mapID = 543, x = 0.4394, y = 0.4887, text = "Turned in 'Fair Warning'" }),
            makeFact(4, { action = "turnin", status = "complete", questid = 35210, mapID = 543, x = 0.4394, y = 0.4887, text = "Turned in 'A Great Escape'" }),
            makeFact(5, { action = "accept", status = "incomplete", questid = 35139, mapID = 543, x = 0.4394, y = 0.4887, text = "Accept 'Eye in the Sky'" }),
        },
        expected = {
            title = "Accept 'Eye in the Sky'",
            subtext = "Talk to Rexxar",
            clusterKind = "normal",
            debugReason = EXPECT_NIL,
            subtextReason = "preceding_talk_header",
            titleOwnerGoal = 5,
            titleOwnerReason = "primary_action_fallback",
            headerContextGoal = 1,
            headerContextReason = "preceding_talk_header",
        },
    },
    {
        id = "completed_three_turnin_corridor_recovers_talk_header",
        category = "completed_corridor",
        classification = "approved_improvement",
        sourceNote = "A settled three-turnin same-target handoff should still recover the NPC talk context for the following accept.",
        currentGoalNum = 2,
        context = {
            rawArrowTitle = "Turned in 'Leave Every Soldier Behind'",
            kind = "guide",
            source = "pointer.ArrowFrame.waypoint",
            mapID = 543,
            x = 0.4394,
            y = 0.4887,
        },
        patches = {
            { path = "C_GossipInfo.GetAvailableQuests", value = function() return {} end },
            { path = "C_GossipInfo.GetActiveQuests", value = function() return {} end },
            { path = "GetNumAvailableQuests", value = function() return 0 end },
            { path = "GetNumActiveQuests", value = function() return 0 end },
            { path = "GetQuestID", value = function() return nil end },
            { path = "C_QuestLog.GetLogIndexForQuestID", value = function() return 0 end },
        },
        facts = {
            makeFact(1, { action = "talk", npcid = 84131, text = "Talk to Rexxar" }),
            makeFact(2, { action = "turnin", status = "complete", questid = 36223, mapID = 543, x = 0.4394, y = 0.4887, text = "Turned in 'Leave Every Soldier Behind'" }),
            makeFact(3, { action = "turnin", status = "complete", questid = 35128, mapID = 543, x = 0.4394, y = 0.4887, text = "Turned in 'Fair Warning'" }),
            makeFact(4, { action = "turnin", status = "complete", questid = 35210, mapID = 543, x = 0.4394, y = 0.4887, text = "Turned in 'A Great Escape'" }),
            makeFact(5, { action = "accept", status = "incomplete", questid = 35139, mapID = 543, x = 0.4394, y = 0.4887, text = "Accept 'Eye in the Sky'" }),
        },
        expected = {
            title = "Accept 'Eye in the Sky'",
            subtext = "Talk to Rexxar",
            clusterKind = "normal",
            debugReason = EXPECT_NIL,
            subtextReason = "preceding_talk_header",
            titleOwnerGoal = 5,
            titleOwnerReason = "primary_action_fallback",
            headerContextGoal = 1,
            headerContextReason = "preceding_talk_header",
        },
    },
    {
        id = "completed_turnin_corridor_stops_on_unrelated_visible_fact",
        category = "completed_corridor",
        classification = "parity",
        sourceNote = "Header recovery must still stop when an unrelated visible fact breaks a long completed handoff corridor.",
        currentGoalNum = 2,
        context = {
            rawArrowTitle = "Turned in 'Leave Every Soldier Behind'",
            kind = "guide",
            source = "pointer.ArrowFrame.waypoint",
            mapID = 543,
            x = 0.4394,
            y = 0.4887,
        },
        patches = {
            { path = "C_GossipInfo.GetAvailableQuests", value = function() return {} end },
            { path = "C_GossipInfo.GetActiveQuests", value = function() return {} end },
            { path = "GetNumAvailableQuests", value = function() return 0 end },
            { path = "GetNumActiveQuests", value = function() return 0 end },
            { path = "GetQuestID", value = function() return nil end },
            { path = "C_QuestLog.GetLogIndexForQuestID", value = function() return 0 end },
        },
        facts = {
            makeFact(1, { action = "talk", npcid = 84131, text = "Talk to Rexxar" }),
            makeFact(2, { action = "turnin", status = "complete", questid = 36223, mapID = 543, x = 0.4394, y = 0.4887, text = "Turned in 'Leave Every Soldier Behind'" }),
            makeFact(3, { action = "emote", text = "Perform an unrelated action" }),
            makeFact(4, { action = "turnin", status = "complete", questid = 35128, mapID = 543, x = 0.4394, y = 0.4887, text = "Turned in 'Fair Warning'" }),
            makeFact(5, { action = "turnin", status = "complete", questid = 35210, mapID = 543, x = 0.4394, y = 0.4887, text = "Turned in 'A Great Escape'" }),
            makeFact(6, { action = "accept", status = "incomplete", questid = 35139, mapID = 543, x = 0.4394, y = 0.4887, text = "Accept 'Eye in the Sky'" }),
        },
        expected = {
            title = "Accept 'Eye in the Sky'",
            subtext = EXPECT_NIL,
            clusterKind = "normal",
            debugReason = EXPECT_NIL,
            subtextReason = EXPECT_NIL,
            titleOwnerGoal = 6,
            titleOwnerReason = "primary_action_fallback",
            headerContextGoal = EXPECT_NIL,
            headerContextReason = EXPECT_NIL,
        },
    },
    {
        id = "ready_turnin_before_accept_seed_prefers_turnin",
        category = "mixed_handoff",
        classification = "approved_improvement",
        sourceNote = "When Zygor's pointer advances to same-target accepts near the NPC, an earlier quest-log-ready turnin should still own presentation.",
        currentGoalNum = 5,
        context = {
            rawArrowTitle = "Accept 'Mercy for the Living'",
            kind = "guide",
            source = "pointer.ArrowFrame.waypoint",
            mapID = 543,
            x = 0.5826,
            y = 0.5990,
        },
        patches = {
            { path = "C_GossipInfo.GetAvailableQuests", value = function() return {} end },
            { path = "C_GossipInfo.GetActiveQuests", value = function() return {} end },
            { path = "GetNumAvailableQuests", value = function() return 0 end },
            { path = "GetNumActiveQuests", value = function() return 0 end },
            { path = "GetQuestID", value = function() return nil end },
            { path = "C_QuestLog.IsComplete", value = function(questID) return questID == 35640 end },
        },
        facts = {
            makeFact(1, { action = "talk", npcid = 82476, text = "Talk to Khaano" }),
            makeFact(2, { action = "turnin", status = "incomplete", questid = 35640, mapID = 543, x = 0.5826, y = 0.5990, text = "Turn in 'Vengeance for the Fallen'" }),
            makeFact(3, { action = "turnin", status = "complete", questid = 35633, mapID = 543, x = 0.5826, y = 0.5990, text = "Turned in 'Scout Forensics'" }),
            makeFact(4, { action = "turnin", status = "complete", questid = 35642, mapID = 543, x = 0.5826, y = 0.5990, text = "Turned in 'Mysterious Pod'" }),
            makeFact(5, { action = "accept", status = "incomplete", questid = 35644, mapID = 543, x = 0.5826, y = 0.5990, text = "Accept 'Mercy for the Living'" }),
            makeFact(6, { action = "accept", status = "incomplete", questid = 35645, mapID = 543, x = 0.5826, y = 0.5990, text = "Accept 'The Secret of the Fungus'" }),
        },
        expected = {
            title = "Turn in 'Vengeance for the Fallen'",
            subtext = "Talk to Khaano",
            clusterKind = "normal",
            debugReason = EXPECT_NIL,
            subtextReason = "context_header",
            titleOwnerGoal = 2,
            titleOwnerReason = "primary_action_fallback",
            headerContextGoal = 1,
            headerContextReason = "context_header",
        },
    },
    {
        id = "ready_turnin_before_accept_seed_keeps_accept_without_ready_proof",
        category = "mixed_handoff",
        classification = "parity",
        sourceNote = "A stale or not-ready earlier turnin must not steal ownership from a same-target accept seed without quest-log or live-dialog readiness proof.",
        currentGoalNum = 5,
        context = {
            rawArrowTitle = "Accept 'Mercy for the Living'",
            kind = "guide",
            source = "pointer.ArrowFrame.waypoint",
            mapID = 543,
            x = 0.5826,
            y = 0.5990,
        },
        patches = {
            { path = "C_GossipInfo.GetAvailableQuests", value = function() return {} end },
            { path = "C_GossipInfo.GetActiveQuests", value = function() return {} end },
            { path = "GetNumAvailableQuests", value = function() return 0 end },
            { path = "GetNumActiveQuests", value = function() return 0 end },
            { path = "GetQuestID", value = function() return nil end },
            { path = "C_QuestLog.IsComplete", value = function() return false end },
        },
        facts = {
            makeFact(1, { action = "talk", npcid = 82476, text = "Talk to Khaano" }),
            makeFact(2, { action = "turnin", status = "incomplete", questid = 35640, mapID = 543, x = 0.5826, y = 0.5990, text = "Turn in 'Vengeance for the Fallen'" }),
            makeFact(3, { action = "turnin", status = "complete", questid = 35633, mapID = 543, x = 0.5826, y = 0.5990, text = "Turned in 'Scout Forensics'" }),
            makeFact(4, { action = "turnin", status = "complete", questid = 35642, mapID = 543, x = 0.5826, y = 0.5990, text = "Turned in 'Mysterious Pod'" }),
            makeFact(5, { action = "accept", status = "incomplete", questid = 35644, mapID = 543, x = 0.5826, y = 0.5990, text = "Accept 'Mercy for the Living'" }),
            makeFact(6, { action = "accept", status = "incomplete", questid = 35645, mapID = 543, x = 0.5826, y = 0.5990, text = "Accept 'The Secret of the Fungus'" }),
        },
        expected = {
            title = "Accept 'Mercy for the Living'",
            subtext = "Talk to Khaano",
            clusterKind = "normal",
            debugReason = EXPECT_NIL,
            subtextReason = "preceding_talk_header",
            titleOwnerGoal = 5,
            titleOwnerReason = "current_actionable_fact",
            headerContextGoal = 1,
            headerContextReason = "preceding_talk_header",
        },
    },
    {
        id = "ready_turnin_before_accept_seed_stops_on_unrelated_visible_fact",
        category = "mixed_handoff",
        classification = "parity",
        sourceNote = "Ready-turnin correction must not cross unrelated visible facts between the earlier turnin and the accept seed.",
        currentGoalNum = 6,
        context = {
            rawArrowTitle = "Accept 'Mercy for the Living'",
            kind = "guide",
            source = "pointer.ArrowFrame.waypoint",
            mapID = 543,
            x = 0.5826,
            y = 0.5990,
        },
        patches = {
            { path = "C_GossipInfo.GetAvailableQuests", value = function() return {} end },
            { path = "C_GossipInfo.GetActiveQuests", value = function() return {} end },
            { path = "GetNumAvailableQuests", value = function() return 0 end },
            { path = "GetNumActiveQuests", value = function() return 0 end },
            { path = "GetQuestID", value = function() return nil end },
            { path = "C_QuestLog.IsComplete", value = function(questID) return questID == 35640 end },
        },
        facts = {
            makeFact(1, { action = "talk", npcid = 82476, text = "Talk to Khaano" }),
            makeFact(2, { action = "turnin", status = "incomplete", questid = 35640, mapID = 543, x = 0.5826, y = 0.5990, text = "Turn in 'Vengeance for the Fallen'" }),
            makeFact(3, { action = "turnin", status = "complete", questid = 35633, mapID = 543, x = 0.5826, y = 0.5990, text = "Turned in 'Scout Forensics'" }),
            makeFact(4, { action = "emote", text = "Perform an unrelated action" }),
            makeFact(5, { action = "turnin", status = "complete", questid = 35642, mapID = 543, x = 0.5826, y = 0.5990, text = "Turned in 'Mysterious Pod'" }),
            makeFact(6, { action = "accept", status = "incomplete", questid = 35644, mapID = 543, x = 0.5826, y = 0.5990, text = "Accept 'Mercy for the Living'" }),
        },
        expected = {
            title = "Accept 'Mercy for the Living'",
            subtext = EXPECT_NIL,
            clusterKind = "normal",
            debugReason = EXPECT_NIL,
            subtextReason = EXPECT_NIL,
            titleOwnerGoal = 6,
            titleOwnerReason = "current_actionable_fact",
            headerContextGoal = EXPECT_NIL,
            headerContextReason = EXPECT_NIL,
        },
    },
}

-- ============================================================
-- Runner
-- ============================================================

local function buildReasonMapping(reason, mapping)
    if reason == nil then
        return nil
    end
    return mapping[reason] or reason
end

local function evaluateCase(case)
    local context = buildCaseContext(case)
    local restore = applyPatches(case.patches)
    local ok, snapshot, debug = pcall(function()
        local resolvedSnapshot, resolvedDebug = M.ResolveFromFacts(context)
        return resolvedSnapshot, resolvedDebug
    end)
    restorePatches(restore)

    local result = {
        id = case.id,
        category = case.category,
        classification = case.classification,
        ok = ok,
        error = ok and nil or snapshot,
        snapshot = ok and snapshot or nil,
        debug = ok and debug or nil,
    }

    if not ok then
        result.pass = false
        return result
    end

    local resolvedTitle = nil
    local resolvedSubtext = nil
    local resolvedClusterKind = nil
    local resolvedSubtextReason = nil
    local resolvedRouteAllowed = nil
    local resolvedHeaderGoal = nil
    local resolvedMatchedLiveGoal = nil
    local resolvedTitleOwnerGoal = nil
    local resolvedTitleOwnerReason = nil
    local resolvedHeaderContextGoal = nil
    local resolvedHeaderContextReason = nil
    local resolvedSemanticKind = nil
    local resolvedSemanticTravelType = nil
    local resolvedSemanticQuestID = nil
    if type(snapshot) == "table" then
        resolvedTitle = snapshot.mirrorTitle
        resolvedSubtext = snapshot.pinpointSubtext
        resolvedClusterKind = snapshot.clusterKind
        resolvedSubtextReason = snapshot.subtextReason
        resolvedRouteAllowed = snapshot.routePresentationAllowed
        resolvedHeaderGoal = snapshot.headerGoalNum
        resolvedMatchedLiveGoal = snapshot.matchedLiveGoalNum
        resolvedSemanticKind = snapshot.semanticKind
        resolvedSemanticTravelType = snapshot.semanticTravelType
        resolvedSemanticQuestID = snapshot.semanticQuestID
    end

    local resolvedDebugReason = debug.reason
    if type(debug) == "table" then
        resolvedTitleOwnerGoal = debug.titleOwnerGoal
        resolvedTitleOwnerReason = debug.titleOwnerReason
        resolvedHeaderContextGoal = debug.headerContextGoal
        resolvedHeaderContextReason = debug.headerContextReason
    end

    local expected = case.expected or {}
    local mismatches = {}

    if not compareField(expected.title, resolvedTitle) then
        mismatches[#mismatches + 1] = string.format("title expected=%s actual=%s", tostring(expected.title), tostring(resolvedTitle))
    end
    if not compareField(expected.subtext, resolvedSubtext) then
        mismatches[#mismatches + 1] = string.format("subtext expected=%s actual=%s", tostring(expected.subtext), tostring(resolvedSubtext))
    end
    if not compareField(expected.clusterKind, resolvedClusterKind) then
        mismatches[#mismatches + 1] = string.format("clusterKind expected=%s actual=%s", tostring(expected.clusterKind), tostring(resolvedClusterKind))
    end
    if not compareField(expected.debugReason, resolvedDebugReason) then
        mismatches[#mismatches + 1] = string.format("debugReason expected=%s actual=%s", tostring(expected.debugReason), tostring(resolvedDebugReason))
    end
    if not compareField(expected.subtextReason, resolvedSubtextReason) then
        mismatches[#mismatches + 1] = string.format("subtextReason expected=%s actual=%s", tostring(expected.subtextReason), tostring(resolvedSubtextReason))
    end
    if not compareField(expected.routePresentationAllowed, resolvedRouteAllowed) then
        mismatches[#mismatches + 1] = string.format("routePresentationAllowed expected=%s actual=%s", tostring(expected.routePresentationAllowed), tostring(resolvedRouteAllowed))
    end
    if not compareField(expected.headerGoalNum, resolvedHeaderGoal) then
        mismatches[#mismatches + 1] = string.format("headerGoalNum expected=%s actual=%s", tostring(expected.headerGoalNum), tostring(resolvedHeaderGoal))
    end
    if not compareField(expected.matchedLiveGoalNum, resolvedMatchedLiveGoal) then
        mismatches[#mismatches + 1] = string.format("matchedLiveGoalNum expected=%s actual=%s", tostring(expected.matchedLiveGoalNum), tostring(resolvedMatchedLiveGoal))
    end
    if not compareField(expected.titleOwnerGoal, resolvedTitleOwnerGoal) then
        mismatches[#mismatches + 1] = string.format("titleOwnerGoal expected=%s actual=%s", tostring(expected.titleOwnerGoal), tostring(resolvedTitleOwnerGoal))
    end
    if not compareField(expected.titleOwnerReason, resolvedTitleOwnerReason) then
        mismatches[#mismatches + 1] = string.format("titleOwnerReason expected=%s actual=%s", tostring(expected.titleOwnerReason), tostring(resolvedTitleOwnerReason))
    end
    if not compareField(expected.headerContextGoal, resolvedHeaderContextGoal) then
        mismatches[#mismatches + 1] = string.format("headerContextGoal expected=%s actual=%s", tostring(expected.headerContextGoal), tostring(resolvedHeaderContextGoal))
    end
    if not compareField(expected.headerContextReason, resolvedHeaderContextReason) then
        mismatches[#mismatches + 1] = string.format("headerContextReason expected=%s actual=%s", tostring(expected.headerContextReason), tostring(resolvedHeaderContextReason))
    end
    if not compareField(expected.semanticKind, resolvedSemanticKind) then
        mismatches[#mismatches + 1] = string.format("semanticKind expected=%s actual=%s", tostring(expected.semanticKind), tostring(resolvedSemanticKind))
    end
    if not compareField(expected.semanticTravelType, resolvedSemanticTravelType) then
        mismatches[#mismatches + 1] = string.format("semanticTravelType expected=%s actual=%s", tostring(expected.semanticTravelType), tostring(resolvedSemanticTravelType))
    end
    if not compareField(expected.semanticQuestID, resolvedSemanticQuestID) then
        mismatches[#mismatches + 1] = string.format("semanticQuestID expected=%s actual=%s", tostring(expected.semanticQuestID), tostring(resolvedSemanticQuestID))
    end

    result.pass = #mismatches == 0
    result.mismatches = mismatches
    result.title = resolvedTitle
    result.subtext = resolvedSubtext
    result.debugReason = resolvedDebugReason
    result.subtextReason = resolvedSubtextReason
    result.legacyDebugReason = buildReasonMapping(resolvedDebugReason, LEGACY_DEBUG_REASON_MAP)
    result.legacySubtextReason = buildReasonMapping(resolvedSubtextReason, LEGACY_SUBTEXT_REASON_MAP)
    result.clusterKind = resolvedClusterKind
    result.routePresentationAllowed = resolvedRouteAllowed
    result.titleOwnerGoal = resolvedTitleOwnerGoal
    result.titleOwnerReason = resolvedTitleOwnerReason
    result.headerContextGoal = resolvedHeaderContextGoal
    result.headerContextReason = resolvedHeaderContextReason
    result.semanticKind = resolvedSemanticKind
    result.semanticTravelType = resolvedSemanticTravelType
    result.semanticQuestID = resolvedSemanticQuestID
    return result
end

local function RunCase(caseId)
    for _, case in ipairs(CASES) do
        if case.id == caseId then
            return evaluateCase(case)
        end
    end
    return nil
end

local function RunAllCases()
    local results = {}
    local passCount = 0
    for _, case in ipairs(CASES) do
        local result = evaluateCase(case)
        results[#results + 1] = result
        if result.pass then
            passCount = passCount + 1
        end
    end
    return {
        results = results,
        total = #results,
        passed = passCount,
        failed = #results - passCount,
    }
end

-- ============================================================
-- Public API
-- ============================================================

M.GetCases = function()
    return CASES
end

M.RunCase = RunCase
M.RunAllCases = RunAllCases
M.GetLegacyDebugReasonMapping = function(reason)
    return buildReasonMapping(reason, LEGACY_DEBUG_REASON_MAP)
end
M.GetLegacySubtextReasonMapping = function(reason)
    return buildReasonMapping(reason, LEGACY_SUBTEXT_REASON_MAP)
end
