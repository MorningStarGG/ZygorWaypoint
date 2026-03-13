local NS = _G.ZygorWaypointNS
local state = NS.State

state.routing = state.routing or {
    hooked = false,
    pendingWaypoint = nil,
    retryScheduled = false,
    retryCount = 0,
    startupAdopted = false,
}

local routing = state.routing
local ROUTE_RETRY_DELAY_SECONDS = 0.25
local ROUTE_RETRY_MAX_COUNT = 40

local function GetReadyPointer()
    local Z = NS.ZGV and NS.ZGV() or _G.ZygorGuidesViewer
    local Pointer = Z and Z.Pointer
    if not Pointer or type(Pointer.SetWaypoint) ~= "function" or not Pointer.ArrowFrame then
        return
    end
    return Pointer
end

local function QueuePendingRoute(mapID, x, y)
    routing.pendingWaypoint = {
        mapID = mapID,
        x = x,
        y = y,
    }
end

local function ApplyRouteViaZygor(mapID, x, y)
    local Pointer = GetReadyPointer()
    if not Pointer or not mapID or not x or not y then
        return false
    end

    local waydata = {
        title = "ZygorRoute",
        type = "manual",
        cleartype = true,
        icon = Pointer.Icons and Pointer.Icons.greendotbig or nil,
        onminimap = "always",
        overworld = true,
        showonedge = true,
        findpath = true,
    }

    local ok, err = pcall(Pointer.SetWaypoint, Pointer, mapID, x, y, waydata, true)
    if not ok then
        NS.Log("TomTom -> Zygor route deferred:", tostring(err))
        return false
    end

    return true
end

local function TryApplyPendingRoute()
    local pending = routing.pendingWaypoint
    if not pending then
        return false
    end

    if not ApplyRouteViaZygor(pending.mapID, pending.x, pending.y) then
        return false
    end

    routing.pendingWaypoint = nil
    routing.retryCount = 0
    return true
end

local function SchedulePendingRouteRetry()
    if routing.retryScheduled or not routing.pendingWaypoint then
        return
    end

    routing.retryScheduled = true
    NS.After(ROUTE_RETRY_DELAY_SECONDS, function()
        routing.retryScheduled = false

        if TryApplyPendingRoute() then
            return
        end

        if not routing.pendingWaypoint then
            routing.retryCount = 0
            return
        end

        routing.retryCount = (routing.retryCount or 0) + 1
        if routing.retryCount < ROUTE_RETRY_MAX_COUNT then
            SchedulePendingRouteRetry()
        end
    end)
end

local function IsExternalTomTomWaypoint(uid)
    return type(uid) == "table"
        and uid[1] and uid[2] and uid[3]
        and not uid.fromZWP
        and uid.title ~= "ZygorRoute"
end

local function GetActiveTomTomWaypointCandidate()
    if not TomTom or type(TomTom.IsCrazyArrowEmpty) ~= "function" or TomTom:IsCrazyArrowEmpty() then
        return
    end

    if type(TomTom.GetDistanceToWaypoint) ~= "function" or type(TomTom.waypoints) ~= "table" then
        return
    end

    local bestUID, bestDistance
    for _, mapWaypoints in pairs(TomTom.waypoints) do
        for _, uid in pairs(mapWaypoints) do
            if IsExternalTomTomWaypoint(uid) then
                local distance = TomTom:GetDistanceToWaypoint(uid)
                if distance and (not bestDistance or distance < bestDistance) then
                    bestDistance = distance
                    bestUID = uid
                end
            end
        end
    end

    return bestUID
end

local function MaybeAdoptExistingTomTomWaypoint()
    if routing.startupAdopted or routing.pendingWaypoint then
        return
    end

    if not NS.IsRoutingEnabled or not NS.IsRoutingEnabled() then
        return
    end

    local uid = GetActiveTomTomWaypointCandidate()
    routing.startupAdopted = true
    if not uid then
        return
    end

    QueuePendingRoute(uid[1], uid[2], uid[3])
    if not TryApplyPendingRoute() then
        SchedulePendingRouteRetry()
    end
end

function NS.ResumeTomTomRoutingStartupSync()
    if NS.IsRoutingEnabled and not NS.IsRoutingEnabled() then
        routing.pendingWaypoint = nil
        routing.retryCount = 0
        return
    end

    if routing.pendingWaypoint then
        if not TryApplyPendingRoute() then
            routing.retryCount = 0
            SchedulePendingRouteRetry()
        end
        return
    end

    MaybeAdoptExistingTomTomWaypoint()
end

function NS.RouteViaZygor(mapID, x, y)
    if not mapID or not x or not y then return end

    QueuePendingRoute(mapID, x, y)
    if not TryApplyPendingRoute() then
        SchedulePendingRouteRetry()
    end
end

function NS.HookTomTomRouting()
    if routing.hooked then return end
    if not TomTom or type(TomTom.AddWaypoint) ~= "function" then return end

    routing.hooked = true

    hooksecurefunc(TomTom, "AddWaypoint", function(_, mapID, x, y, opts)
        if not NS.IsRoutingEnabled() then return end
        if not mapID or not x or not y then return end

        if opts and opts.fromZWP then return end
        if opts and opts.title == "ZygorRoute" then return end

        NS.RouteViaZygor(mapID, x, y)
    end)

    if type(TomTom.ClearWaypoint) == "function" then
        hooksecurefunc(TomTom, "ClearWaypoint", function(_, uid)
            local bridge = NS.State and NS.State.bridge
            if bridge and (bridge.suppressTomTomClearSync or 0) > 0 then
                return
            end

            if type(NS.HandleTomTomMirrorCleared) == "function" then
                NS.After(0, function()
                    NS.HandleTomTomMirrorCleared(uid)
                end)
            end
        end)
    end

    NS.After(ROUTE_RETRY_DELAY_SECONDS, NS.ResumeTomTomRoutingStartupSync)
    NS.Log("TomTom -> Zygor routing hook active")
end
