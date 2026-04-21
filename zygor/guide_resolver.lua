local NS = _G.ZygorWaypointNS
local state = NS.State

local M = NS.Internal.GuideResolver
local P = M.Private
local resolverState = P.resolverState

local NormalizeText = P.NormalizeText
local FormatCoordinateSubtext = P.FormatCoordinateSubtext
local GetGoalAction = P.GetGoalAction
local IsGoalVisible = P.IsGoalVisible
local GetGoalStatus = P.GetGoalStatus
local GetGoalQuestID = P.GetGoalQuestID
local GetGoalQuestTitle = P.GetGoalQuestTitle
local GetGoalNPCID = P.GetGoalNPCID
local GetGoalCoords = P.GetGoalCoords
local GetGoalText = P.GetGoalText
local GetGoalTooltipText = P.GetGoalTooltipText
local BuildFacts = P.BuildFacts
local GetGuideResolverCacheToken = P.GetGuideResolverCacheToken
local InvalidateGuideResolverFactsState = P.InvalidateGuideResolverFactsState
local InvalidateGuideResolverDialogState = P.InvalidateGuideResolverDialogState
local GetCachedFacts = P.GetCachedFacts
local MatchesSnapshotCacheKey = P.MatchesSnapshotCacheKey
local StoreSnapshotCacheKey = P.StoreSnapshotCacheKey
local ResolveFromFacts = P.ResolveFromFacts
local BuildQuestPresentationSnapshot = P.BuildQuestPresentationSnapshot
local Signature = P.Signature

-- ============================================================
-- Snapshot resolution
-- ============================================================

local function CacheSnapshotResult(snapshot, debug, context, step, currentGoalNum, rawArrowTitle, targetMapID, targetX, targetY, targetSig)
    StoreSnapshotCacheKey(context, step, currentGoalNum, rawArrowTitle, targetMapID, targetX, targetY, targetSig)
    resolverState.snapshotCacheValue = snapshot or false
    resolverState.snapshotCacheDebug = debug
    return snapshot, debug
end

local function BuildTargetSignature(context, targetMapID, targetX, targetY)
    if type(context) == "table" and type(context.sig) == "string" then
        return context.sig
    end

    if type(targetMapID) == "number"
        and type(targetX) == "number"
        and type(targetY) == "number"
    then
        return Signature(targetMapID, targetX, targetY)
    end

    return nil
end

local function ResolveSnapshotInternal(context)
    context = type(context) == "table" and context or {}

    local Z = NS.ZGV()
    local step = Z and Z.CurrentStep
    local canonicalResult = type(step) == "table" and NS.ResolveCanonicalGuideGoal(step) or nil
    local currentGoalNum = canonicalResult and canonicalResult.canonicalGoalNum or nil
    local rawArrowTitle = NormalizeText(context.rawArrowTitle) or " "
    local targetMapID = context.mapID
    local targetX = context.x
    local targetY = context.y
    local targetSig = BuildTargetSignature(context, targetMapID, targetX, targetY)

    if MatchesSnapshotCacheKey(context, step, currentGoalNum, rawArrowTitle, targetMapID, targetX, targetY, targetSig) then
        local churn = state.churn
        if churn.active then
            churn.resolveHit = churn.resolveHit + 1
        end
        local cachedSnapshot = resolverState.snapshotCacheValue
        return cachedSnapshot == false and nil or cachedSnapshot, resolverState.snapshotCacheDebug
    end

    do
        local churn = state.churn
        if churn.active then
            churn.resolveMiss = churn.resolveMiss + 1
        end
    end

    local facts = GetCachedFacts(step)
    local snapshot, debug = ResolveFromFacts({
        facts = facts,
        currentGoalNum = currentGoalNum,
        rawArrowTitle = rawArrowTitle,
        mapID = targetMapID,
        x = targetX,
        y = targetY,
        sig = targetSig,
        kind = context.kind,
        legKind = context.legKind,
        routeTravelType = context.routeTravelType,
        source = context.source,
    })

    debug.rawArrowTitle = rawArrowTitle
    debug.facts = facts
    debug.step = step
    if canonicalResult then
        debug.rawGoalNum             = canonicalResult.rawGoalNum
        debug.canonicalGoalNum       = canonicalResult.canonicalGoalNum
        debug.usedOverride           = canonicalResult.usedOverride
        debug.canonicalOverrideReason = canonicalResult.overrideReason
        debug.clusterStart           = canonicalResult.clusterStart
        debug.clusterEnd             = canonicalResult.clusterEnd
        debug.firstIncompleteGoalNum = canonicalResult.firstIncompleteGoalNum
    end
    if snapshot ~= nil then
        debug.snapshot = snapshot
    end

    return CacheSnapshotResult(snapshot, debug, context, step, currentGoalNum, rawArrowTitle, targetMapID, targetX, targetY, targetSig)
end

-- ============================================================
-- Public API
-- ============================================================

function NS.ResolveGuideContentSnapshot(context)
    local snapshot, debug = ResolveSnapshotInternal(context)
    resolverState.lastSnapshot = snapshot
    resolverState.lastDebug = debug
    return snapshot
end

function NS.GetLastGuideContentSnapshot()
    return resolverState.lastSnapshot
end

local function FormatDebugValue(value)
    if value == nil then
        return "nil"
    end
    if value == false then
        return "false"
    end
    if value == true then
        return "true"
    end
    return tostring(value)
end

function NS.GetGuideResolverDebugLines()
    local debug = resolverState.lastDebug
    if type(debug) ~= "table" then
        return { "no resolver debug snapshot available" }
    end

    local lines = {}
    lines[#lines + 1] = table.concat({
        "targetKind=" .. tostring(debug.target.kind),
        "legKind=" .. tostring(debug.target.legKind),
        "routeType=" .. tostring(debug.target.routeTravelType),
        "source=" .. tostring(debug.target.source),
        "rawArrowTitle=" .. tostring(debug.rawArrowTitle),
        "anchor=" .. tostring(debug.anchorGoalNum),
        "block=" .. tostring(debug.blockStart) .. "-" .. tostring(debug.blockEnd),
        "reason=" .. tostring(debug.reason or (debug.snapshot and debug.snapshot.subtextReason) or nil),
        "rawGoal=" .. tostring(debug.rawGoalNum),
        "canonicalGoal=" .. tostring(debug.canonicalGoalNum),
        "override=" .. tostring(debug.usedOverride),
        "overrideReason=" .. tostring(debug.canonicalOverrideReason),
        "cluster=" .. tostring(debug.clusterStart) .. "-" .. tostring(debug.clusterEnd),
        "firstIncomplete=" .. tostring(debug.firstIncompleteGoalNum),
    }, " ")

    if debug.snapshot then
        lines[#lines + 1] = table.concat({
            "mirrorTitle=" .. tostring(debug.snapshot.mirrorTitle),
            "subtext=" .. tostring(debug.snapshot.pinpointSubtext),
            "clusterKind=" .. tostring(debug.snapshot.clusterKind),
            "contentSig=" .. tostring(debug.snapshot.contentSig),
            "routeAllowed=" .. tostring(debug.snapshot.routePresentationAllowed),
            "headerGoal=" .. tostring(debug.snapshot.headerGoalNum),
            "blockLevelMatchGoal=" .. tostring(debug.snapshot.matchedLiveGoalNum),
            "blockLevelMatchReason=" .. tostring(debug.liveMatchedReason),
        }, " ")

        lines[#lines + 1] = table.concat({
            "presentation",
            "titleOwnerGoal=" .. tostring(debug.titleOwnerGoal),
            "titleOwnerReason=" .. tostring(debug.titleOwnerReason),
            "headerContextGoal=" .. tostring(debug.headerContextGoal),
            "headerContextReason=" .. tostring(debug.headerContextReason),
        }, " ")
    end

    if #debug.liveEntries > 0 then
        for _, entry in ipairs(debug.liveEntries) do
            lines[#lines + 1] = table.concat({
                "liveEntry",
                "kind=" .. tostring(entry.kind),
                "questID=" .. tostring(entry.questID),
                "title=" .. tostring(entry.title),
                "complete=" .. tostring(entry.isComplete),
            }, " ")
        end
    else
        lines[#lines + 1] = "liveEntries none"
    end

    if type(debug.liveCurrentness) == "table"
        and (
            debug.liveCurrentness.matchedLiveFactIndex ~= nil
            or debug.liveCurrentness.matchedLiveReason ~= nil
        )
    then
        lines[#lines + 1] = table.concat({
            "blockLevelMatch",
            "goal=" .. tostring(debug.liveCurrentness.matchedLiveFactIndex),
            "reason=" .. tostring(debug.liveCurrentness.matchedLiveReason),
        }, " ")
    elseif #debug.liveEntries > 0 then
        lines[#lines + 1] = "blockLevelMatch unused"
    end

    for _, fact in ipairs(debug.facts) do
        if fact.visible == true then
            local coords = (type(fact.mapID) == "number" and type(fact.x) == "number" and type(fact.y) == "number")
                and string.format("%s@%.4f,%.4f", tostring(fact.mapID), fact.x, fact.y)
                or "nil"
            local annotation = type(debug.liveCurrentness) == "table"
                and type(debug.liveCurrentness.annotationsByIndex) == "table"
                and debug.liveCurrentness.annotationsByIndex[fact.index]
                or nil
            lines[#lines + 1] = table.concat({
                "#" .. tostring(fact.index),
                "action=" .. tostring(fact.action),
                "status=" .. tostring(fact.status),
                "or=" .. tostring(fact.orlogic),
                "questid=" .. tostring(fact.questid),
                "npcid=" .. tostring(fact.npcid),
                "force_noway=" .. tostring(fact.suppressed),
                "coords=" .. coords,
                "text=" .. tostring(fact.text),
                "tooltip=" .. tostring(fact.tooltip),
                "secondaryEligible=" .. FormatDebugValue(annotation and annotation.secondaryEligible),
                "liveMatchKind=" .. FormatDebugValue(annotation and annotation.matchKind),
                "liveEligibilityReason=" .. FormatDebugValue(annotation and annotation.reason),
            }, " ")
        end
    end

    return lines
end

-- ============================================================
-- Re-exports
-- ============================================================

NS.GetGuideResolverCacheToken = GetGuideResolverCacheToken
NS.InvalidateGuideResolverFactsState = InvalidateGuideResolverFactsState
NS.InvalidateGuideResolverDialogState = InvalidateGuideResolverDialogState

M.NormalizeText = NormalizeText
M.FormatCoordinateSubtext = FormatCoordinateSubtext
M.GetGoalAction = GetGoalAction
M.IsGoalVisible = IsGoalVisible
M.GetGoalStatus = GetGoalStatus
M.GetGoalQuestID = GetGoalQuestID
M.GetGoalQuestTitle = GetGoalQuestTitle
M.GetGoalNPCID = GetGoalNPCID
M.GetGoalCoords = GetGoalCoords
M.GetGoalText = GetGoalText
M.GetGoalTooltipText = GetGoalTooltipText
M.BuildFacts = BuildFacts
M.BuildQuestPresentationSnapshot = BuildQuestPresentationSnapshot
M.GetGuideResolverCacheToken = GetGuideResolverCacheToken
M.InvalidateGuideResolverFactsState = InvalidateGuideResolverFactsState
M.InvalidateGuideResolverDialogState = InvalidateGuideResolverDialogState
