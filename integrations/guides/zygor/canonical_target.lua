local NS = _G.AzerothWaypointNS
if not NS.IsZygorLoaded() then return end

local GetWaypointKind = NS.GetWaypointKind
local ResolveIngressWaypointKind = NS.ResolveIngressWaypointKind
local ReadWaypointCoords = NS.ReadWaypointCoords
local ResolveWaypointOwner = NS.ResolveWaypointOwner
local Signature = NS.Signature

-- ============================================================
-- Internal helpers
-- ============================================================

local function getGoalMapID(goal)
    return goal and (goal.map or goal.mapid or goal.mapID) or nil
end

local function getLinkedGoal(waypoint)
    if type(waypoint) ~= "table" then
        return
    end

    if type(waypoint.goal) == "table" then
        return waypoint.goal
    end

    local surrogate = waypoint.surrogate_for
    if type(surrogate) == "table" and type(surrogate.goal) == "table" then
        return surrogate.goal
    end

    local pathWaypoint = waypoint.pathnode and waypoint.pathnode.waypoint
    if type(pathWaypoint) == "table" and type(pathWaypoint.goal) == "table" then
        return pathWaypoint.goal
    end
end

local function IsSameLocation(mapA, xA, yA, mapB, xB, yB)
    if type(mapA) ~= "number"
        or type(xA) ~= "number"
        or type(yA) ~= "number"
        or type(mapB) ~= "number"
        or type(xB) ~= "number"
        or type(yB) ~= "number"
    then
        return false
    end

    return Signature(mapA, xA, yA) == Signature(mapB, xB, yB)
end

-- ============================================================
-- Route proxy detection
-- ============================================================

-- Confirms that a live route-like waypoint is semantically owned by the current
-- guide goal. Checks ownership identity (linked goal belongs to this step and
-- matches current_waypoint_goal_num), not navigation position carrier legs
-- legitimately navigate through a different location than the goal they deliver
-- the player to.
local function resolveGuideGoalRouteProxy(step, waypoint, source, destinationWaypoint)
    if type(waypoint) ~= "table" then
        return
    end

    if not NS.IsRouteLikeWaypoint(waypoint, source) then
        return
    end

    local owner = ResolveWaypointOwner(waypoint)
    local ownerType = type(owner) == "table" and owner.type or nil
    if ownerType == "manual" or ownerType == "corpse" then
        return
    end

    if type(step) ~= "table" then
        return
    end

    local canonical      = NS.ResolveCanonicalGuideGoal(step)
    local currentGoalNum = canonical and canonical.canonicalGoalNum
    if type(currentGoalNum) ~= "number" or type(step.goals) ~= "table" then
        return
    end

    local currentGoal = step.goals[currentGoalNum]
    local currentGoalMapID = getGoalMapID(currentGoal)
    if type(currentGoal) ~= "table"
        or currentGoal.force_noway == true
        or currentGoalMapID == nil
        or type(currentGoal.x) ~= "number"
        or type(currentGoal.y) ~= "number"
    then
        return
    end

    local linkedGoal = getLinkedGoal(waypoint)
    local linkedGoalMapID = getGoalMapID(linkedGoal)
    if type(linkedGoal) == "table"
        and linkedGoal.parentStep == step
        and linkedGoal.num == currentGoalNum
        and linkedGoal.force_noway ~= true
        and linkedGoalMapID ~= nil
        and type(linkedGoal.x) == "number"
        and type(linkedGoal.y) == "number"
    then
        return linkedGoal
    end

    -- Some live carrier nodes do not retain a direct goal backlink. In that case,
    -- treat the route as guide-owned when the active destination matches the
    -- current goal's location.
    local destinationMapID, destinationX, destinationY = ReadWaypointCoords(destinationWaypoint)
    if IsSameLocation(currentGoalMapID, currentGoal.x, currentGoal.y, destinationMapID, destinationX, destinationY) then
        return currentGoal
    end

    -- Cluster fallback: when canonical override is active and the live linked goal
    -- belongs to the same handoff cluster, return canonical goal for output coords
    -- but live linked goal for legKind so the destination leg is not misclassified.
    if canonical and canonical.usedOverride
        and type(linkedGoal) == "table"
        and linkedGoal.parentStep == step
        and linkedGoal.num >= canonical.clusterStart
        and linkedGoal.num <= canonical.clusterEnd
    then
        return currentGoal, linkedGoal
    end
end

function NS.IsGuideGoalWaypoint(waypoint)
    return getLinkedGoal(waypoint) ~= nil
end

function NS.IsRouteLikeWaypoint(waypoint, source)
    if type(waypoint) ~= "table" then
        return false
    end

    local kind = (ResolveIngressWaypointKind and ResolveIngressWaypointKind(waypoint, source))
        or GetWaypointKind(waypoint, source)
    if kind == "route" then
        return true
    end

    local waypointType = waypoint.type
    return waypointType == "route" or waypointType == "path" or waypoint.pathnode ~= nil or waypoint.in_set ~= nil
end

function NS.IsGuideGoalRouteProxy(step, waypoint, source, destinationWaypoint)
    return resolveGuideGoalRouteProxy(step, waypoint, source, destinationWaypoint) ~= nil
end

-- ============================================================
-- Canonical target
-- ============================================================

local canonicalResult = {}
local canonicalSourceGoalNum = nil
local canonicalSourceString = nil

local function ResolveCanonicalLiveWaypointTargetFields(step, waypoint, source, title, rawTitle, destinationWaypoint)
    local linkedGoal, legKindGoal = resolveGuideGoalRouteProxy(step, waypoint, source, destinationWaypoint)
    if type(linkedGoal) ~= "table" then
        return
    end
    legKindGoal = type(legKindGoal) == "table" and legKindGoal or linkedGoal

    local canonical = NS.ResolveCanonicalGuideGoal(step)
    local goalNum   = canonical and canonical.canonicalGoalNum
    if goalNum ~= canonicalSourceGoalNum then
        canonicalSourceGoalNum = goalNum
        canonicalSourceString = "step.goal#" .. tostring(goalNum)
    end

    local linkedGoalMapID  = getGoalMapID(linkedGoal)
    local legKindGoalMapID = getGoalMapID(legKindGoal)
    local waypointMapID, waypointX, waypointY = ReadWaypointCoords(waypoint)
    local legKind = IsSameLocation(waypointMapID, waypointX, waypointY, legKindGoalMapID, legKindGoal.x, legKindGoal.y)
        and "destination"
        or "carrier"

    return canonicalSourceString, linkedGoalMapID, linkedGoal.x, linkedGoal.y, title, rawTitle, legKind
end

function NS.IsSameLocation(mapA, xA, yA, mapB, xB, yB)
    return IsSameLocation(mapA, xA, yA, mapB, xB, yB)
end

function NS.CanonicalizeLiveWaypointTargetFields(step, waypoint, source, title, rawTitle, destinationWaypoint)
    return ResolveCanonicalLiveWaypointTargetFields(step, waypoint, source, title, rawTitle, destinationWaypoint)
end

function NS.CanonicalizeLiveWaypointTarget(step, waypoint, source, title, rawTitle, destinationWaypoint)
    local canonicalSource, mapID, x, y, canonicalTitle, canonicalRawTitle, legKind =
        ResolveCanonicalLiveWaypointTargetFields(step, waypoint, source, title, rawTitle, destinationWaypoint)
    if type(mapID) ~= "number" or type(x) ~= "number" or type(y) ~= "number" then
        return
    end

    canonicalResult.kind = "guide"
    canonicalResult.source = canonicalSource
    canonicalResult.mapID = mapID
    canonicalResult.x = x
    canonicalResult.y = y
    canonicalResult.title = canonicalTitle
    canonicalResult.rawTitle = canonicalRawTitle
    canonicalResult.legKind = legKind
    return canonicalResult
end
