local NS = _G.ZygorWaypointNS
local HBD = _G.LibStub and LibStub("HereBeDragons-2.0", true)

NS.State = NS.State or {}
NS.State.waypointUICompat = NS.State.waypointUICompat or {
    lastRepairSig = nil,
    lastRepairAt = 0,
    clearCompatInstalled = false,
    originalClearAllSuperTracked = nil,
    skipNextClearTraceLog = false,
}

local state = NS.State.waypointUICompat

local function GetTomTom()
    return _G["TomTom"]
end

local function GetBridge()
    return NS.State and NS.State.bridge
end

local function GetWaypointUIApi()
    local api = _G["WaypointUIAPI"]
    if type(api) ~= "table" or type(api.Navigation) ~= "table" then
        return nil
    end
    return api.Navigation
end

-- WaypointUI coord compatibility
function NS.StabilizeCoordForWaypointUI(v)
    if type(v) ~= "number" or not GetWaypointUIApi() then
        return v
    end

    -- WaypointUI compares stored and live Blizzard waypoint positions after
    -- rounding to one decimal place. A tiny positive bias keeps .95-style
    -- coordinates on the same side of the rounding boundary.
    v = v + 1e-5

    if v < 0 then return 0 end
    if v > 1 then return 1 end
    return v
end

local function IsBlankText(value)
    return type(value) ~= "string" or value:match("^%s*$") ~= nil
end

local function GetWaypointUIHideDistance()
    local db = _G["WaypointDB_Global"]
    local distance = db and tonumber(db.DistanceThresholdHidden) or 1
    if distance < 0 then
        distance = 0
    end
    return distance
end

local function GetDisplayDistance(uid, m, x, y)
    if C_SuperTrack and type(C_SuperTrack.IsSuperTrackingUserWaypoint) == "function" and C_SuperTrack.IsSuperTrackingUserWaypoint()
        and C_Navigation and type(C_Navigation.GetDistance) == "function"
    then
        local distance = C_Navigation.GetDistance()
        if type(distance) == "number" and distance > 0 then
            return distance
        end
    end

    if HBD then
        if type(m) == "number" and type(x) == "number" and type(y) == "number" then
            ---@diagnostic disable-next-line: redundant-parameter
            local px, py, pm = HBD:GetPlayerZonePosition(true)
            if px and py and pm then
                local distance = HBD:GetZoneDistance(pm, px, py, m, x, y)
                if type(distance) == "number" then
                    return distance
                end
            end
        end
    end

    local tomtom = GetTomTom()
    if tomtom and type(tomtom.GetDistanceToWaypoint) == "function" and uid then
        local distance = tomtom:GetDistanceToWaypoint(uid)
        if type(distance) == "number" then
            return distance
        end
    end
end

local function Signature(m, x, y)
    if type(x) == "number" then
        x = math.floor(x * 10000 + 0.5) / 10000
    end
    if type(y) == "number" then
        y = math.floor(y * 10000 + 0.5) / 10000
    end
    return tostring(m) .. ":" .. tostring(x) .. ":" .. tostring(y)
end

local function GetCurrentUserWaypoint()
    if not (C_Map and type(C_Map.HasUserWaypoint) == "function" and C_Map.HasUserWaypoint()) then
        return
    end

    local waypoint = C_Map.GetUserWaypoint and C_Map.GetUserWaypoint()
    if not waypoint or not waypoint.uiMapID or not waypoint.position then
        return
    end

    return waypoint.uiMapID, waypoint.position.x, waypoint.position.y
end

local function IsDestinationReachedClear()
    if type(debugstack) ~= "function" then
        return false
    end

    local ok, stack = pcall(debugstack, 3, 8, 0)
    if not ok or type(stack) ~= "string" then
        return false
    end

    return stack:find("Blizzard_QuestNavigation/SuperTrackedFrame.lua", 1, true) ~= nil
        and stack:find("OnDestinationReached", 1, true) ~= nil
end

local function ShouldSuppressDestinationReachedClear()
    if not GetWaypointUIApi() or not IsDestinationReachedClear() then
        return false
    end

    local nav = GetWaypointUIApi()
    local bridge = GetBridge()
    if not nav or not bridge or not bridge.lastUID then
        return false
    end

    local tomtom = GetTomTom()
    if not tomtom or type(tomtom.IsCrazyArrowEmpty) ~= "function" or tomtom:IsCrazyArrowEmpty() then
        return false
    end

    local info = type(nav.GetUserNavigation) == "function" and nav.GetUserNavigation() or nil
    if not info or info.flags ~= "TomTom_Waypoint" or IsBlankText(info.name) then
        return false
    end

    local mapID, x, y = GetCurrentUserWaypoint()
    if type(mapID) ~= "number" or type(x) ~= "number" or type(y) ~= "number" then
        return false
    end

    local distance = GetDisplayDistance(bridge.lastUID, mapID, x, y)
    if type(distance) ~= "number" then
        return false
    end

    return distance > GetWaypointUIHideDistance()
end

function NS.ConsumeWaypointUIClearTraceSkip()
    if state.skipNextClearTraceLog then
        state.skipNextClearTraceLog = false
        return true
    end
    return false
end

-- WaypointUI session preservation
function NS.InstallWaypointUICompat()
    if state.clearCompatInstalled then
        return
    end

    if not C_SuperTrack or type(C_SuperTrack.ClearAllSuperTracked) ~= "function" then
        return
    end

    state.originalClearAllSuperTracked = C_SuperTrack.ClearAllSuperTracked
    -- Suppress Blizzard's OnDestinationReached clear only while the active
    -- WaypointUI/TomTom marker should still remain visible by WaypointUI's
    -- own hide-distance rules.
    ---@diagnostic disable-next-line: duplicate-set-field
    C_SuperTrack.ClearAllSuperTracked = function(...)
        if ShouldSuppressDestinationReachedClear() then
            state.skipNextClearTraceLog = true
            NS.Log("Suppress ClearAllSuperTracked", "WaypointUI compat")
            return
        end

        return state.originalClearAllSuperTracked(...)
    end
    state.clearCompatInstalled = true
end

function NS.MaybeRepairWaypointUISession(uid, m, x, y, title)
    local nav = GetWaypointUIApi()
    if not nav or not uid then
        return
    end

    local tomtom = GetTomTom()
    if not tomtom or type(tomtom.IsCrazyArrowEmpty) ~= "function" or tomtom:IsCrazyArrowEmpty() then
        return
    end

    local distance = GetDisplayDistance(uid, m, x, y)
    if type(distance) ~= "number" or distance <= GetWaypointUIHideDistance() then
        return
    end

    local info = type(nav.GetUserNavigation) == "function" and nav.GetUserNavigation() or nil
    local tracked = type(nav.IsUserNavigationTracked) == "function" and nav.IsUserNavigationTracked() or false
    if tracked and info and info.flags == "TomTom_Waypoint" and not IsBlankText(info.name) then
        return
    end

    local repairTitle = title
    if IsBlankText(repairTitle) and info and not IsBlankText(info.name) then
        repairTitle = info.name
    end
    if IsBlankText(repairTitle) then
        return
    end

    local now = GetTime and GetTime() or 0
    local sig = Signature(m, x, y)
    if state.lastRepairSig == sig and (now - (state.lastRepairAt or 0)) < 0.75 then
        return
    end

    local addX = NS.StabilizeCoordForWaypointUI(x) * 100
    local addY = NS.StabilizeCoordForWaypointUI(y) * 100
    if type(nav.NewUserNavigation) == "function" then
        nav.NewUserNavigation(repairTitle, m, addX, addY, "TomTom_Waypoint")
        state.lastRepairSig = sig
        state.lastRepairAt = now
        NS.Log("Restore WaypointUI session", repairTitle, m, x, y)
    end
end
