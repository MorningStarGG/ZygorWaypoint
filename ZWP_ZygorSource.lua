local NS = _G.ZygorWaypointNS
local POINTER_WAYPOINT_KEYS = { "DestinationWaypoint", "waypoint", "current_waypoint" }


local function normalizeTitle(title)
    if title == nil then
        return
    end

    title = tostring(title)
    title = title:gsub("[\r\n]+", " ")
    title = title:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "")
    title = title:gsub("%s*%d+[%.,]%s*%d+%s*,?%s*", " ")
    title = title:gsub("%s*%d+[%.,]%s*%d+%s*$", " ")
    title = title:gsub("%s+", " "):gsub("^%s+", ""):gsub("%s+$", "")
    if title == "" then
        return
    end
    return title
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
    if not step or not step.current_waypoint_goal_num or type(step.goals) ~= "table" then
        return
    end

    return step.goals[step.current_waypoint_goal_num]
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
    if pointerOnly then
        return chooseWaypointTitle(waypoint)
    end
    return chooseStepishTitle(Z, waypoint)
end

local function readWaypointCoords(w)
    if type(w) ~= "table" then return end
    local m = w.map or w.mapid or w.mapID or w.m
    local x = w.x or w.mapx or w.wx
    local y = w.y or w.mapy or w.wy
    if m and x and y then
        return m, x, y
    end
end

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

local function isManualWaypoint(w)
    return type(w) == "table" and w.type == "manual"
end

local function isCurrentStepGoalWaypoint(step, w)
    local goal = type(w) == "table" and w.goal
    if type(goal) ~= "table" or goal.parentStep ~= step then
        return false
    end

    local currentGoalNum = step and step.current_waypoint_goal_num
    return type(currentGoalNum) ~= "number" or goal.num == currentGoalNum
end

local function shouldUseWaypointListFallback(step, w)
    return isManualWaypoint(w) or isCurrentStepGoalWaypoint(step, w)
end

function NS.IsCurrentGuideStepWaypointSuppressed()
    local Z = NS.ZGV()
    local step = Z and Z.CurrentStep
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

function NS.ExtractWaypointFromZygor(pointerOnly)
    local Z = NS.ZGV()
    if not Z then return end
    local P = Z.Pointer
    local step = Z.CurrentStep
    local suppressGuideWaypoint = not pointerOnly and NS.IsCurrentGuideStepWaypointSuppressed()

    if P and P.ArrowFrame and P.ArrowFrame.waypoint then
        local w = P.ArrowFrame.waypoint
        local m, x, y = readWaypointCoords(w)
        if m and x and y and (not suppressGuideWaypoint or isManualWaypoint(w)) then
            return m, x, y, chooseTitle(pointerOnly, Z, w), "pointer.ArrowFrame.waypoint"
        end
    end

    if P and P.arrow and P.arrow.waypoint then
        local w = P.arrow.waypoint
        local m, x, y = readWaypointCoords(w)
        if m and x and y and (not suppressGuideWaypoint or isManualWaypoint(w)) then
            return m, x, y, chooseTitle(pointerOnly, Z, w), "pointer.arrow.waypoint"
        end
    end

    if P then
        for _, key in ipairs(POINTER_WAYPOINT_KEYS) do
            local w = P[key]
            local m, x, y = readWaypointCoords(w)
            if m and x and y and (not suppressGuideWaypoint or isManualWaypoint(w)) then
                return m, x, y, chooseTitle(pointerOnly, Z, w), "pointer." .. key
            end
        end

        if type(P.waypoints) == "table" and P.waypoints[1] then
            local w = P.waypoints[1]
            local m, x, y = readWaypointCoords(w)
            if m and x and y and shouldUseWaypointListFallback(step, w) and (not suppressGuideWaypoint or isManualWaypoint(w)) then
                return m, x, y, chooseTitle(pointerOnly, Z, w), "pointer.waypoints[1]"
            end
        end
    end

    if pointerOnly then return end
    if suppressGuideWaypoint then return end

    if step and step.current_waypoint_goal_num and step.goals then
        local g = step.goals[step.current_waypoint_goal_num]
        if g and not isSuppressedGoal(g) then
            local m = g.map or g.mapid or g.mapID
            local x = g.x
            local y = g.y
            if m and x and y then
                return m, x, y, chooseStepishTitle(Z, nil), "step.goal#" .. step.current_waypoint_goal_num
            end
        end
    end

    if step and type(step.goals) == "table" then
        for i, g in ipairs(step.goals) do
            local m = g and not isSuppressedGoal(g) and (g.map or g.mapid or g.mapID)
            local x = g and not isSuppressedGoal(g) and g.x
            local y = g and not isSuppressedGoal(g) and g.y
            if m and x and y then
                return m, x, y, chooseStepishTitle(Z, nil), "step.goal#" .. i
            end
        end
    end

    local pm = C_Map.GetBestMapForUnit and C_Map.GetBestMapForUnit("player")
    if step and pm and step.goals then
        for _, g in ipairs(step.goals) do
            local x, y = parseCoordPairFromText((not isSuppressedGoal(g)) and g and (g.tooltip or g.title or g.header))
            if x and y then
                return pm, x, y, chooseStepishTitle(Z, nil), "text+playerMap"
            end
        end
    end
end
