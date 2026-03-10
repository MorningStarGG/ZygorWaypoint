local NS = _G.ZygorWaypointNS
local state = NS.State

state.routing = state.routing or {
    hooked = false,
}

local routing = state.routing

local function ZygorReady()
    return ZygorGuidesViewer
        and ZygorGuidesViewer.Pointer
        and type(ZygorGuidesViewer.Pointer.SetWaypoint) == "function"
end

function NS.RouteViaZygor(mapID, x, y)
    if not ZygorReady() then return end
    if not mapID or not x or not y then return end

    local Pointer = ZygorGuidesViewer.Pointer
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

    Pointer:SetWaypoint(mapID, x, y, waydata, true)
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

    NS.Log("TomTom -> Zygor routing hook active")
end
