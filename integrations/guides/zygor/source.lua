local NS = _G.AzerothWaypointNS
if not NS.IsZygorLoaded() then return end

local IsBlankText = NS.IsBlankText
local GetZygorPointer = NS.GetZygorPointer
local NormalizeWaypointTitle = NS.NormalizeWaypointTitle
local GetWaypointKind = NS.GetWaypointKind
local ResolveWaypointOwner = NS.ResolveWaypointOwner
local IsWaypointOwnedBy = NS.IsWaypointOwnedBy
local ReadWaypointCoords = NS.ReadWaypointCoords
local Signature = NS.Signature

local MANUAL_ROUTE_PROXY_GRACE_SECONDS = 0.5
local manualRouteFallbackState = {
    sig = nil,
    startedAt = 0,
}


-- ============================================================
-- Title resolution
-- ============================================================

local function normalizeTitle(title)
    return NormalizeWaypointTitle(title)
end

local function chooseFirstTitle(...)
    for i = 1, select("#", ...) do
        local title = normalizeTitle(select(i, ...))
        if title then
            return title
        end
    end

    return " "
end

local function callTitleMethod(target, methodName, ...)
    if type(target) ~= "table" then
        return
    end

    local method = target[methodName]
    if type(method) ~= "function" then
        return
    end

    local ok, title = pcall(method, target, ...)
    if ok then
        return title
    end
end

-- Title priority contract:
-- 1. Waypoint arrow title
-- 2. Waypoint display title
-- 3. Current goal text/title/header/tooltip/quest title
-- 4. Current step way/title/title field
local function getGoalTitle(goal)
    if type(goal) ~= "table" then
        return
    end

    return callTitleMethod(goal, "GetText", true, false, false)
        or goal.title
        or goal.header
        or goal.tooltip
        or (goal.quest and goal.quest.title)
end

local function getCurrentWaypointGoal(step)
    if not step or type(step.goals) ~= "table" then return end
    local canonical = NS.ResolveCanonicalGuideGoal(step)
    local goalNum = canonical and canonical.canonicalGoalNum
    if not goalNum then return end
    return step.goals[goalNum]
end

local function getWaypointArrowTitle(waypoint)
    return chooseFirstTitle(
        callTitleMethod(waypoint, "GetArrowTitle"),
        waypoint and waypoint.arrowtitle
    )
end

local function getWaypointDisplayTitle(waypoint)
    return chooseFirstTitle(
        callTitleMethod(waypoint, "GetTitle"),
        waypoint and waypoint.title
    )
end

local function chooseWaypointTitle(waypoint)
    return chooseFirstTitle(
        getWaypointArrowTitle(waypoint),
        getWaypointDisplayTitle(waypoint)
    )
end

local function getWaypointOwnerType(waypoint)
    local owner = ResolveWaypointOwner(waypoint)
    return type(owner) == "table" and owner.type or nil
end

local function isManualWaypoint(w)
    return getWaypointOwnerType(w) == "manual"
end

local function isCorpseWaypoint(waypoint)
    return getWaypointOwnerType(waypoint) == "corpse"
end

local function chooseStepishTitle(Z, waypoint)
    local step = Z and Z.CurrentStep
    local goal = getCurrentWaypointGoal(step)

    return chooseFirstTitle(
        getWaypointArrowTitle(waypoint),
        getGoalTitle(goal),
        getWaypointDisplayTitle(waypoint),
        step and callTitleMethod(step, "GetWayTitle"),
        step and callTitleMethod(step, "GetTitle"),
        step and step.title
    )
end

local function chooseTitle(pointerOnly, Z, waypoint)
    if pointerOnly or isManualWaypoint(waypoint) or isCorpseWaypoint(waypoint) then
        return chooseWaypointTitle(waypoint)
    end
    return chooseStepishTitle(Z, waypoint)
end

local function hasUsableTitle(title)
    return not IsBlankText(title)
end

local function shouldRequireGuideTitle(pointerOnly, waypoint)
    return not pointerOnly and not isManualWaypoint(waypoint) and not isCorpseWaypoint(waypoint)
end

local function resolvePointerTitle(pointerOnly, Z, waypoint)
    local title = chooseTitle(pointerOnly, Z, waypoint)
    if shouldRequireGuideTitle(pointerOnly, waypoint) and not hasUsableTitle(title) then
        return
    end
    return title
end

local function resolveGuideStepTitle(Z)
    local title = chooseStepishTitle(Z, nil)
    if hasUsableTitle(title) then
        return title
    end
end

-- ============================================================
-- Manual route tracking
-- ============================================================

local function resetManualRouteFallbackState()
    manualRouteFallbackState.sig = nil
    manualRouteFallbackState.startedAt = 0
end

local function getWaypointSignature(waypoint)
    local m, x, y = ReadWaypointCoords(waypoint)
    if not (m and x and y) then
        return
    end

    return Signature(m, x, y)
end

local function isSameWaypointLocation(a, b)
    if type(a) ~= "table" or type(b) ~= "table" then
        return false
    end

    local sigA = getWaypointSignature(a)
    local sigB = getWaypointSignature(b)
    return type(sigA) == "string" and sigA == sigB
end

local function shouldExpectManualRouteProxy(manualDestination)
    if type(manualDestination) ~= "table" then
        return false
    end

    local identity = type(manualDestination.identity) == "table" and manualDestination.identity or nil
    return manualDestination.findpath == true
        or manualDestination.pathfind == true
        or (type(identity) == "table" and identity.kind == "external_tomtom")
end

local function isFailedRoutedManualDestination(manualDestination)
    return shouldExpectManualRouteProxy(manualDestination)
        and not IsBlankText(manualDestination.errortext)
end

local function primeManualRouteFallbackState(manualDestination)
    if not shouldExpectManualRouteProxy(manualDestination) then
        resetManualRouteFallbackState()
        return false
    end

    local sig = getWaypointSignature(manualDestination)
    if type(sig) ~= "string" then
        resetManualRouteFallbackState()
        return false
    end

    if manualRouteFallbackState.sig ~= sig then
        manualRouteFallbackState.sig = sig
        manualRouteFallbackState.startedAt = GetTime()
    end

    return true
end

local function shouldDeferManualFallback(manualDestination)
    if not primeManualRouteFallbackState(manualDestination) then
        return false
    end

    local now = GetTime()
    return (now - (manualRouteFallbackState.startedAt or now)) < MANUAL_ROUTE_PROXY_GRACE_SECONDS
end

-- ============================================================
-- Waypoint extraction
-- ============================================================

local function parseCoordPairFromText(s)
    if type(s) ~= "string" then return end
    local sx, sy = s:match("(%d+%.?%d*)%s*[,;:/]%s*(%d+%.?%d*)")
    if sx and sy then
        return tonumber(sx) / 100, tonumber(sy) / 100
    end
end

local function isSuppressedGoal(g)
    return type(g) == "table" and g.force_noway
end

local function getGoalMapID(goal)
    if type(goal) ~= "table" then
        return
    end

    return goal.map or goal.mapid or goal.mapID
end

local function isCurrentStepGoalWaypoint(step, w)
    local goal = type(w) == "table" and w.goal
    if type(goal) ~= "table" or goal.parentStep ~= step then
        return false
    end

    local canonical      = step and NS.ResolveCanonicalGuideGoal(step)
    local currentGoalNum = canonical and canonical.canonicalGoalNum
    return type(currentGoalNum) ~= "number" or goal.num == currentGoalNum
end

local function isGuideGoalWaypoint(waypoint)
    if type(waypoint) ~= "table" then
        return false
    end
    if waypoint.goal then
        return true
    end

    local surrogate = waypoint.surrogate_for
    if type(surrogate) == "table" and surrogate.goal then
        return true
    end

    local pathWaypoint = waypoint.pathnode and waypoint.pathnode.waypoint
    if type(pathWaypoint) == "table" and pathWaypoint.goal then
        return true
    end

    return false
end

local function isRouteLikeWaypoint(waypoint, source)
    if type(waypoint) ~= "table" then
        return false
    end

    local kind = GetWaypointKind(waypoint, source)
    if kind == "route" then
        return true
    end

    local waypointType = waypoint.type
    return waypointType == "route" or waypointType == "path" or waypoint.pathnode ~= nil or waypoint.in_set ~= nil
end

local function shouldUseWaypointListFallback(step, w)
    return isManualWaypoint(w) or isCurrentStepGoalWaypoint(step, w)
end

local function shouldSuppressGuideWaypoint(pointerOnly, step)
    return not pointerOnly and NS.IsCurrentGuideStepWaypointSuppressed(step)
end

local function shouldAllowPointerWaypoint(suppressGuideWaypoint, waypoint)
    return not suppressGuideWaypoint or isManualWaypoint(waypoint)
end

local function extractPointerWaypoint(pointerOnly, suppressGuideWaypoint, step, Z, waypoint, source, requireWaypointListFallback)
    if type(waypoint) ~= "table" then
        return
    end

    if requireWaypointListFallback and not shouldUseWaypointListFallback(step, waypoint) then
        return
    end

    if not shouldAllowPointerWaypoint(suppressGuideWaypoint, waypoint) then
        return
    end

    local m, x, y = ReadWaypointCoords(waypoint)
    local title = resolvePointerTitle(pointerOnly, Z, waypoint)
    local kind = GetWaypointKind(waypoint, source) or "guide"
    if m and x and y and title then
        return m, x, y, title, source, kind
    end
end

local function extractCanonicalGuideTargetFromRouteWaypoint(step, waypoint, source, destinationWaypoint, title)
    if type(NS.CanonicalizeLiveWaypointTarget) ~= "function" then
        return
    end
    if type(step) ~= "table" or type(waypoint) ~= "table" then
        return
    end
    if isManualWaypoint(waypoint) or isCorpseWaypoint(waypoint) then
        return
    end
    if not isRouteLikeWaypoint(waypoint, source) then
        return
    end

    local rawTitle = getWaypointArrowTitle(waypoint)
    local finalTitle = chooseFirstTitle(
        getWaypointArrowTitle(destinationWaypoint),
        getWaypointDisplayTitle(destinationWaypoint),
        title
    )
    local canonical = NS.CanonicalizeLiveWaypointTarget(
        step,
        waypoint,
        source,
        finalTitle,
        rawTitle,
        destinationWaypoint
    )
    if type(canonical) ~= "table"
        or type(canonical.mapID) ~= "number"
        or type(canonical.x) ~= "number"
        or type(canonical.y) ~= "number"
    then
        return
    end

    return {
        mapID = canonical.mapID,
        x = canonical.x,
        y = canonical.y,
        title = canonical.title or finalTitle,
        source = canonical.source or source,
        kind = canonical.kind or "guide",
        rawTitle = canonical.rawTitle or rawTitle,
        liveRouteLegKind = canonical.legKind,
    }
end

local function extractGuideRouteTargetFromPointerSources(Z, P, step, suppressGuideWaypoint)
    if suppressGuideWaypoint or not P then
        return
    end

    local sources = {
        { P.ArrowFrame and P.ArrowFrame.waypoint, "pointer.ArrowFrame.waypoint" },
        { P.arrow and P.arrow.waypoint, "pointer.arrow.waypoint" },
        { P.current_waypoint, "pointer.current_waypoint" },
        { P.waypoint, "pointer.waypoint" },
        { type(P.waypoints) == "table" and P.waypoints[1] or nil, "pointer.waypoints[1]" },
    }

    for index = 1, #sources do
        local waypoint = sources[index][1]
        local source = sources[index][2]
        local m, x, y = ReadWaypointCoords(waypoint)
        if m and x and y then
            local title = resolvePointerTitle(false, Z, waypoint)
            local canonical = extractCanonicalGuideTargetFromRouteWaypoint(
                step,
                waypoint,
                source,
                P.DestinationWaypoint,
                title
            )
            if canonical then
                return canonical
            end
        end
    end
end

local function extractManualAuthorityCandidate(pointerOnly, suppressGuideWaypoint, step, Z, manualDestination, waypoint, source)
    if type(waypoint) ~= "table" or type(manualDestination) ~= "table" then
        return
    end

    if waypoint ~= manualDestination and not IsWaypointOwnedBy(waypoint, manualDestination) then
        return
    end

    return extractPointerWaypoint(pointerOnly, suppressGuideWaypoint, step, Z, waypoint, source)
end

local function extractManualRouteProxy(manualDestination, waypoint, source)
    if type(waypoint) ~= "table" or type(manualDestination) ~= "table" then
        return
    end

    if not isRouteLikeWaypoint(waypoint, source) or isGuideGoalWaypoint(waypoint) then
        return
    end

    local m, x, y = ReadWaypointCoords(waypoint)
    if not (m and x and y) then
        return
    end

    local title = chooseFirstTitle(
        getWaypointArrowTitle(waypoint),
        getWaypointDisplayTitle(waypoint),
        getWaypointArrowTitle(manualDestination),
        getWaypointDisplayTitle(manualDestination)
    )
    local kind = GetWaypointKind(waypoint, source) or "route"
    if isSameWaypointLocation(waypoint, manualDestination) then
        kind = "manual"
    elseif kind ~= "route" then
        kind = "route"
    end

    return m, x, y, title, source, kind
end

local function extractFromPointerSources(pointerOnly, suppressGuideWaypoint, Z, P, step)
    if not P then
        return
    end

    local m, x, y, title, source, kind = extractPointerWaypoint(
        pointerOnly,
        suppressGuideWaypoint,
        step,
        Z,
        P.ArrowFrame and P.ArrowFrame.waypoint,
        "pointer.ArrowFrame.waypoint"
    )
    if m and x and y and title then
        return m, x, y, title, source, kind
    end

    m, x, y, title, source, kind = extractPointerWaypoint(
        pointerOnly,
        suppressGuideWaypoint,
        step,
        Z,
        P.arrow and P.arrow.waypoint,
        "pointer.arrow.waypoint"
    )
    if m and x and y and title then
        return m, x, y, title, source, kind
    end

    m, x, y, title, source, kind = extractPointerWaypoint(
        pointerOnly,
        suppressGuideWaypoint,
        step,
        Z,
        P.DestinationWaypoint,
        "pointer.DestinationWaypoint"
    )
    if m and x and y and title then
        return m, x, y, title, source, kind
    end

    m, x, y, title, source, kind = extractPointerWaypoint(
        pointerOnly,
        suppressGuideWaypoint,
        step,
        Z,
        P.waypoint,
        "pointer.waypoint"
    )
    if m and x and y and title then
        return m, x, y, title, source, kind
    end

    m, x, y, title, source, kind = extractPointerWaypoint(
        pointerOnly,
        suppressGuideWaypoint,
        step,
        Z,
        P.current_waypoint,
        "pointer.current_waypoint"
    )
    if m and x and y and title then
        return m, x, y, title, source, kind
    end

    m, x, y, title, source, kind = extractPointerWaypoint(
        pointerOnly,
        suppressGuideWaypoint,
        step,
        Z,
        type(P.waypoints) == "table" and P.waypoints[1] or nil,
        "pointer.waypoints[1]",
        true
    )
    if m and x and y and title then
        return m, x, y, title, source, kind
    end
end

local function extractFromCurrentGoal(Z, step)
    if not step or type(step.goals) ~= "table" then return end
    local canonical = NS.ResolveCanonicalGuideGoal(step)
    local goalNum   = canonical and canonical.canonicalGoalNum
    if not goalNum then return end
    local goal = step.goals[goalNum]
    if not goal or isSuppressedGoal(goal) then return end
    local m     = getGoalMapID(goal)
    local x     = goal.x
    local y     = goal.y
    local title = resolveGuideStepTitle(Z)
    if m and x and y and title then
        return m, x, y, title, "step.goal#" .. goalNum, "guide"
    end
end

local function extractFromAnyGoal(Z, step)
    if not step or type(step.goals) ~= "table" then
        return
    end

    local title = resolveGuideStepTitle(Z)
    if not title then
        return
    end

    for i, goal in ipairs(step.goals) do
        if not isSuppressedGoal(goal) then
            local m = getGoalMapID(goal)
            local x = goal and goal.x
            local y = goal and goal.y
            if m and x and y then
                return m, x, y, title, "step.goal#" .. i, "guide"
            end
        end
    end
end

local function extractFromTextCoords(Z, step)
    local playerMapID = C_Map.GetBestMapForUnit and C_Map.GetBestMapForUnit("player")
    if not (step and playerMapID and type(step.goals) == "table") then
        return
    end

    local title = resolveGuideStepTitle(Z)
    if not title then
        return
    end

    for _, goal in ipairs(step.goals) do
        if not isSuppressedGoal(goal) then
            local x, y = parseCoordPairFromText(goal and (goal.tooltip or goal.title or goal.header))
            if x and y then
                return playerMapID, x, y, title, "text+playerMap", "guide"
            end
        end
    end
end

-- ============================================================
-- Public API
-- ============================================================

function NS.IsCurrentGuideStepWaypointSuppressed(step)
    if step == nil then
        local Z = NS.ZGV()
        step = Z and Z.CurrentStep
    end

    if not step or type(step.goals) ~= "table" then
        return false
    end

    local hasCoordinateGoals = false
    local hasAllowedCoordinateGoals = false

    for _, g in ipairs(step.goals) do
        local visible = true
        if g and type(g.IsVisible) == "function" then
            visible = g:IsVisible()
        end

        if visible and g and g.x and g.y then
            hasCoordinateGoals = true
            if not isSuppressedGoal(g) then
                hasAllowedCoordinateGoals = true
                break
            end
        end
    end

    return hasCoordinateGoals and not hasAllowedCoordinateGoals
end

function NS.HasUsableCurrentGuideNavTitle()
    local displayState = NS.GetZygorDisplayState()
    local snapshot = displayState and displayState.snapshot
    local displayTarget = displayState and displayState.target
    return displayState
        and snapshot
        and snapshot.textVisible == true
        and (
            (displayTarget and displayTarget.kind == "guide" and hasUsableTitle(displayTarget.title))
            or hasUsableTitle(snapshot.title)
            or hasUsableTitle(snapshot.label)
        )
        or false
end

function NS.ExtractWaypointFromZygor(pointerOnly)
    local churn = NS.State.churn
    if churn.active then
        churn.extractWaypoint = churn.extractWaypoint + 1
    end
    local Z, P = GetZygorPointer()
    if not Z then return end
    local step = Z.CurrentStep
    local suppressGuideWaypoint = shouldSuppressGuideWaypoint(pointerOnly, step)

    local m, x, y, title, source, kind = extractFromPointerSources(pointerOnly, suppressGuideWaypoint, Z, P, step)
    if m and x and y and title then
        return m, x, y, title, source, kind
    end

    if pointerOnly or suppressGuideWaypoint then
        return
    end

    local goalM, goalX, goalY, goalTitle, goalSource, goalKind = extractFromCurrentGoal(Z, step)
    if goalM and goalX and goalY and goalTitle then
        return goalM, goalX, goalY, goalTitle, goalSource, goalKind
    end

    local anyGoalM, anyGoalX, anyGoalY, anyGoalTitle, anyGoalSource, anyGoalKind = extractFromAnyGoal(Z, step)
    if anyGoalM and anyGoalX and anyGoalY and anyGoalTitle then
        return anyGoalM, anyGoalX, anyGoalY, anyGoalTitle, anyGoalSource, anyGoalKind
    end

    return extractFromTextCoords(Z, step)
end

function NS.ExtractGuideRouteTargetFromZygor()
    local Z = NS.ZGV()
    if not Z then return end

    local step = Z.CurrentStep
    local suppressGuideWaypoint = shouldSuppressGuideWaypoint(false, step)
    if suppressGuideWaypoint then
        return
    end

    local m, x, y, title, source, kind = extractFromCurrentGoal(Z, step)
    if not (m and x and y and title) then
        m, x, y, title, source, kind = extractFromAnyGoal(Z, step)
    end
    if not (m and x and y and title) then
        m, x, y, title, source, kind = extractFromTextCoords(Z, step)
    end
    if not (m and x and y and title) then
        return
    end

    return {
        mapID = m,
        x = x,
        y = y,
        title = title,
        source = source,
        kind = kind or "guide",
    }
end

function NS.ExtractActiveManualTargetFromZygor(pointerOnly)
    local churn = NS.State.churn
    if churn.active then
        churn.extractManual = churn.extractManual + 1
    end
    local Z, P = GetZygorPointer()
    if not Z or not P then
        resetManualRouteFallbackState()
        return nil, nil, nil, nil, nil, nil, false
    end

    local step = Z.CurrentStep
    local suppressGuideWaypoint = shouldSuppressGuideWaypoint(pointerOnly, step)
    local manualDestination = P.DestinationWaypoint
    if not isManualWaypoint(manualDestination) then
        resetManualRouteFallbackState()
        return nil, nil, nil, nil, nil, nil, false
    end
    primeManualRouteFallbackState(manualDestination)

    local m, x, y, title, source, kind

    -- For routed manuals, prefer the live travel leg regardless of whether the
    -- destination happens to be on the same map. After zoning/refreshes Zygor
    -- can briefly expose only the passive manual destination before rebuilding
    -- route nodes, so allow only a short initial settle window before falling back.
    -- Longer fallback stabilization happens in the bridge commit layer.
    m, x, y, title, source, kind = extractManualRouteProxy(
        manualDestination,
        P.ArrowFrame and P.ArrowFrame.waypoint,
        "pointer.ArrowFrame.waypoint"
    )
    if m and x and y and title then
        return m, x, y, title, source, kind, true
    end

    m, x, y, title, source, kind = extractManualRouteProxy(
        manualDestination,
        P.arrow and P.arrow.waypoint,
        "pointer.arrow.waypoint"
    )
    if m and x and y and title then
        return m, x, y, title, source, kind, true
    end

    m, x, y, title, source, kind = extractManualRouteProxy(
        manualDestination,
        P.current_waypoint,
        "pointer.current_waypoint"
    )
    if m and x and y and title then
        return m, x, y, title, source, kind, true
    end

    if shouldDeferManualFallback(manualDestination) then
        return nil, nil, nil, nil, nil, nil, true
    end

    if isFailedRoutedManualDestination(manualDestination) then
        resetManualRouteFallbackState()
        return nil, nil, nil, nil, nil, nil, true
    end

    -- Once routing has settled (or if this manual does not expect a routed
    -- proxy), use the passive manual destination state directly.
    m, x, y, title, source, kind = extractManualAuthorityCandidate(
        pointerOnly,
        suppressGuideWaypoint,
        step,
        Z,
        manualDestination,
        P.ArrowFrame and P.ArrowFrame.waypoint,
        "pointer.ArrowFrame.waypoint"
    )
    if m and x and y and title then
        return m, x, y, title, source, kind, true
    end

    m, x, y, title, source, kind = extractManualAuthorityCandidate(
        pointerOnly,
        suppressGuideWaypoint,
        step,
        Z,
        manualDestination,
        P.arrow and P.arrow.waypoint,
        "pointer.arrow.waypoint"
    )
    if m and x and y and title then
        return m, x, y, title, source, kind, true
    end

    m, x, y, title, source, kind = extractManualAuthorityCandidate(
        pointerOnly,
        suppressGuideWaypoint,
        step,
        Z,
        manualDestination,
        P.current_waypoint,
        "pointer.current_waypoint"
    )
    if m and x and y and title then
        return m, x, y, title, source, kind, true
    end

    m, x, y, title, source, kind = extractManualAuthorityCandidate(
        pointerOnly,
        suppressGuideWaypoint,
        step,
        Z,
        manualDestination,
        P.waypoint,
        "pointer.waypoint"
    )
    if m and x and y and title then
        return m, x, y, title, source, kind, true
    end

    m, x, y, title, source, kind = extractManualAuthorityCandidate(
        pointerOnly,
        suppressGuideWaypoint,
        step,
        Z,
        manualDestination,
        type(P.waypoints) == "table" and P.waypoints[1] or nil,
        "pointer.waypoints[1]"
    )
    if m and x and y and title then
        return m, x, y, title, source, kind, true
    end

    -- Finally fall back to the manual destination itself.
    m, x, y, title, source, kind = extractPointerWaypoint(
        pointerOnly,
        suppressGuideWaypoint,
        step,
        Z,
        manualDestination,
        "pointer.DestinationWaypoint"
    )
    if m and x and y and title then
        return m, x, y, title, source, kind, true
    end

    resetManualRouteFallbackState()
    return nil, nil, nil, nil, nil, nil, true
end
