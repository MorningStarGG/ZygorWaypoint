local NS = _G.ZygorWaypointNS

local function chooseStepishTitle(Z, waypoint)
    local step = Z and Z.CurrentStep
    local gtitle
    if step and step.current_waypoint_goal_num and step.goals then
        local g = step.goals[step.current_waypoint_goal_num]
        gtitle = g and g.title
    end

    local title = gtitle or (step and step.title) or (waypoint and waypoint.title) or " "
    title = title:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "")
    title = title:gsub("%s*%d+[%.,]%s*%d+%s*,?%s*", " ")
    title = title:gsub("%s*%d+[%.,]%s*%d+%s*$", " ")
    title = title:gsub("%s+", " "):gsub("^%s+", ""):gsub("%s+$", "")
    return title
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

function NS.ExtractWaypointFromZygor(pointerOnly)
    local Z = NS.ZGV()
    if not Z then return end
    local P = Z.Pointer

    if P and P.ArrowFrame and P.ArrowFrame.waypoint then
        local w = P.ArrowFrame.waypoint
        local m, x, y = readWaypointCoords(w)
        if m and x and y then
            return m, x, y, chooseStepishTitle(Z, w), "pointer.ArrowFrame.waypoint"
        end
    end

    if P and P.arrow and P.arrow.waypoint then
        local w = P.arrow.waypoint
        local m, x, y = readWaypointCoords(w)
        if m and x and y then
            return m, x, y, chooseStepishTitle(Z, w), "pointer.arrow.waypoint"
        end
    end

    if P then
        for _, key in ipairs({ "DestinationWaypoint", "waypoint", "current_waypoint" }) do
            local w = P[key]
            local m, x, y = readWaypointCoords(w)
            if m and x and y then
                return m, x, y, chooseStepishTitle(Z, w), "pointer." .. key
            end
        end

        if type(P.waypoints) == "table" and P.waypoints[1] then
            local w = P.waypoints[1]
            local m, x, y = readWaypointCoords(w)
            if m and x and y then
                return m, x, y, chooseStepishTitle(Z, w), "pointer.waypoints[1]"
            end
        end
    end

    if pointerOnly then return end

    local step = Z.CurrentStep
    if step and step.current_waypoint_goal_num and step.goals then
        local g = step.goals[step.current_waypoint_goal_num]
        if g then
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
            local m = g and (g.map or g.mapid or g.mapID)
            local x = g and g.x
            local y = g and g.y
            if m and x and y then
                return m, x, y, chooseStepishTitle(Z, nil), "step.goal#" .. i
            end
        end
    end

    local pm = C_Map.GetBestMapForUnit and C_Map.GetBestMapForUnit("player")
    if step and pm and step.goals then
        for _, g in ipairs(step.goals) do
            local x, y = parseCoordPairFromText(g and (g.tooltip or g.title or g.header))
            if x and y then
                return pm, x, y, chooseStepishTitle(Z, nil), "text+playerMap"
            end
        end
    end
end
