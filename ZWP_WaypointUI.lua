local NS = _G.ZygorWaypointNS
local C = NS.Constants
local HBD = _G.LibStub and LibStub("HereBeDragons-2.0", true)

-- ---------------------------------------------------------------------------
-- State
-- ---------------------------------------------------------------------------

NS.State = NS.State or {}
NS.State.waypointUICompat = NS.State.waypointUICompat or {
    lastRepairSig = nil,
    lastRepairAt = 0,
    unsupportedCache = { sig = nil, mapID = nil, attempts = 0 },
    clearCompatInstalled = false,
    originalClearAllSuperTracked = nil,
    skipNextClearTraceLog = false,
}

local state = NS.State.waypointUICompat

local GetTomTom = NS.GetTomTom
local GetTomTomArrow = NS.GetTomTomArrow
local IsBlankText = NS.IsBlankText
local GetPlayerMapID = NS.GetPlayerMapID
local Signature = NS.Signature

local function GetBridge()
    return NS.State and NS.State.bridge
end

-- ---------------------------------------------------------------------------
-- WoW API Adapters (pure query functions, no side effects)
-- ---------------------------------------------------------------------------

local function GetWaypointUIApi()
    local api = _G["WaypointUIAPI"]
    if type(api) ~= "table" or type(api.Navigation) ~= "table" then
        return nil
    end
    return api.Navigation
end

function NS.StabilizeCoordForWaypointUI(v)
    if type(v) ~= "number" or not GetWaypointUIApi() then
        return v
    end

    -- WaypointUI compares stored and live Blizzard waypoint positions after
    -- rounding to one decimal place. A tiny positive bias keeps .95-style
    -- coordinates on the same side of the rounding boundary.
    v = v + C.WAYPOINT_UI_COORD_BIAS

    if v < 0 then return 0 end
    if v > 1 then return 1 end
    return v
end

local function GetWaypointUIHideDistance()
    local db = _G["WaypointDB_Global"]
    local distance = db and tonumber(db.DistanceThresholdHidden) or 1
    if distance < 0 then
        distance = 0
    end
    return distance
end

local function IsPlayerDeadOrGhost()
    return type(UnitIsDeadOrGhost) == "function" and UnitIsDeadOrGhost("player") or false
end

-- Each distance source covers cases the others miss: C_Navigation needs
-- active super-tracking, HBD needs valid map coords, TomTom needs a UID.
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

-- ---------------------------------------------------------------------------
-- Suppression Checks/fixes
-- Prevents Blizzard's OnDestinationReached from clearing waypoints early.
-- ---------------------------------------------------------------------------

-- Only way to distinguish Blizzard's OnDestinationReached auto-clear from
-- intentional user clears -- no event or callback exposes the caller.
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
    if IsPlayerDeadOrGhost() or not GetWaypointUIApi() or not IsDestinationReachedClear() then
        return false
    end

    local bridge = GetBridge()
    if not bridge or not bridge.lastUID then
        return false
    end

    local tomtom = GetTomTom()
    if not tomtom or type(tomtom.IsCrazyArrowEmpty) ~= "function" or tomtom:IsCrazyArrowEmpty() then
        return false
    end

    local nav = GetWaypointUIApi()
    if not nav then
        return false
    end

    local info = type(nav.GetUserNavigation) == "function" and nav.GetUserNavigation() or nil
    if info and info.flags and info.flags ~= "TomTom_Waypoint" then
        return false
    end

    if IsBlankText(bridge.lastTitle) and (not info or IsBlankText(info.name)) then
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

-- ---------------------------------------------------------------------------
-- Session Repair
-- Restores WaypointUI navigation when it falls out of sync with TomTom.
-- ---------------------------------------------------------------------------

local function ClearUnsupportedRestoreGate()
    local cache = state.unsupportedCache
    cache.sig = nil
    cache.mapID = nil
    cache.attempts = 0
end

-- Detects maps (e.g. instanced dungeons) where no native waypoint system
-- is available by checking that all three support mechanisms return false.
local function IsCurrentMapUnsupportedForWaypointUIRestore(playerMapID)
    if type(playerMapID) ~= "number" then
        playerMapID = GetPlayerMapID()
    end
    if type(playerMapID) ~= "number" then
        return false
    end

    if type(C_Map.CanSetUserWaypointOnMap) == "function" and C_Map.CanSetUserWaypointOnMap(playerMapID) then
        return false
    end

    if C_SuperTrack and type(C_SuperTrack.GetNextWaypointForMap) == "function" then
        local nextWaypointX, nextWaypointY = C_SuperTrack.GetNextWaypointForMap(playerMapID)
        if type(nextWaypointX) == "number" and type(nextWaypointY) == "number" then
            return false
        end
    end

    if C_Navigation and type(C_Navigation.GetFrame) == "function" and C_Navigation.GetFrame() then
        return false
    end

    return true
end

-- When a map doesn't support user waypoints, walk up the map hierarchy
-- converting coordinates via 2D affine transformation until we find one.
local function ResolveSettableUserWaypointTarget(mapID, x, y)
    if type(mapID) ~= "number" or type(x) ~= "number" or type(y) ~= "number" then
        return
    end

    if not C_Map or type(C_Map.CanSetUserWaypointOnMap) ~= "function" then
        return mapID, x, y
    end

    if C_Map.CanSetUserWaypointOnMap(mapID) then
        return mapID, x, y
    end

    if type(C_Map.GetMapInfo) ~= "function"
        or type(C_Map.GetWorldPosFromMapPos) ~= "function"
        or type(CreateVector2D) ~= "function"
    then
        return
    end

    local currentMapID, currentX, currentY = mapID, x, y
    for _ = 1, C.MAX_PARENT_MAP_DEPTH do
        local mapInfo = C_Map.GetMapInfo(currentMapID)
        local parentMapID = mapInfo and mapInfo.parentMapID
        if type(parentMapID) ~= "number" or parentMapID == 0 then
            return
        end

        local _, childOrigin = C_Map.GetWorldPosFromMapPos(currentMapID, CreateVector2D(0, 0))
        local _, childRightEdge = C_Map.GetWorldPosFromMapPos(currentMapID, CreateVector2D(1, 0))
        local _, childBottomEdge = C_Map.GetWorldPosFromMapPos(currentMapID, CreateVector2D(0, 1))
        local _, parentOrigin = C_Map.GetWorldPosFromMapPos(parentMapID, CreateVector2D(0, 0))
        local _, parentRightEdge = C_Map.GetWorldPosFromMapPos(parentMapID, CreateVector2D(1, 0))
        local _, parentBottomEdge = C_Map.GetWorldPosFromMapPos(parentMapID, CreateVector2D(0, 1))
        if not (childOrigin and childRightEdge and childBottomEdge and parentOrigin and parentRightEdge and parentBottomEdge) then
            return
        end

        local worldX = childOrigin.x
            + currentX * (childRightEdge.x - childOrigin.x)
            + currentY * (childBottomEdge.x - childOrigin.x)
        local worldY = childOrigin.y
            + currentX * (childRightEdge.y - childOrigin.y)
            + currentY * (childBottomEdge.y - childOrigin.y)

        local offsetX = worldX - parentOrigin.x
        local offsetY = worldY - parentOrigin.y
        local parentBasisXx = parentRightEdge.x - parentOrigin.x
        local parentBasisYx = parentBottomEdge.x - parentOrigin.x
        local parentBasisXy = parentRightEdge.y - parentOrigin.y
        local parentBasisYy = parentBottomEdge.y - parentOrigin.y
        local determinant = parentBasisXx * parentBasisYy - parentBasisYx * parentBasisXy
        if determinant == 0 then
            return
        end

        local parentX = (offsetX * parentBasisYy - offsetY * parentBasisYx) / determinant
        local parentY = (offsetY * parentBasisXx - offsetX * parentBasisXy) / determinant
        if parentX < -C.COORD_BOUNDS_EPSILON or parentX > 1 + C.COORD_BOUNDS_EPSILON
            or parentY < -C.COORD_BOUNDS_EPSILON or parentY > 1 + C.COORD_BOUNDS_EPSILON
        then
            return
        end

        parentX = math.max(0, math.min(1, parentX))
        parentY = math.max(0, math.min(1, parentY))

        if C_Map.CanSetUserWaypointOnMap(parentMapID) then
            return parentMapID, parentX, parentY
        end

        currentMapID, currentX, currentY = parentMapID, parentX, parentY
    end
end

function NS.MaybeRepairWaypointUISession(uid, m, x, y, title)
    local nav = GetWaypointUIApi()
    if not nav or not uid or IsPlayerDeadOrGhost() then
        return
    end

    local tomtom = GetTomTom()
    if not tomtom or type(tomtom.IsCrazyArrowEmpty) ~= "function" or tomtom:IsCrazyArrowEmpty() then
        return
    end

    local tomArrow = GetTomTomArrow()
    if not tomArrow or not tomArrow.IsShown or not tomArrow:IsShown() then
        return
    end

    local distance = GetDisplayDistance(uid, m, x, y)
    if type(distance) ~= "number" or distance <= GetWaypointUIHideDistance() then
        return
    end

    local playerMapID = GetPlayerMapID()
    local info = type(nav.GetUserNavigation) == "function" and nav.GetUserNavigation() or nil
    local tracked = type(nav.IsUserNavigationTracked) == "function" and nav.IsUserNavigationTracked() or false

    local repairTitle = title
    if IsBlankText(repairTitle) and info and not IsBlankText(info.name) then
        repairTitle = info.name
    end
    if IsBlankText(repairTitle) then
        return
    end

    local targetMapID, targetX, targetY = ResolveSettableUserWaypointTarget(m, x, y)
    if not (targetMapID and targetX and targetY) then
        local unsupportedCurrentMap = IsCurrentMapUnsupportedForWaypointUIRestore(playerMapID)
        if unsupportedCurrentMap then
            local sig = Signature(m, x, y)
            local cache = state.unsupportedCache
            cache.sig = sig
            cache.mapID = playerMapID
            cache.attempts = 2
        end
        return
    end

    if tracked and info and info.flags == "TomTom_Waypoint" and not IsBlankText(info.name) then
        ClearUnsupportedRestoreGate()
        return
    end

    local sig = Signature(m, x, y)
    local unsupportedCurrentMap = IsCurrentMapUnsupportedForWaypointUIRestore(playerMapID)
    local cache = state.unsupportedCache
    if unsupportedCurrentMap and cache.sig == sig and cache.mapID == playerMapID then
        cache.attempts = cache.attempts + 1
        if cache.attempts >= 2 then
            return
        end
    end

    local now = GetTime and GetTime() or 0
    local repairCooldown = C.WAYPOINT_UI_REPAIR_COOLDOWN
    if state.lastRepairSig == sig and (now - (state.lastRepairAt or 0)) < repairCooldown then
        return
    end

    state.lastRepairSig = sig
    state.lastRepairAt = now

    local addX = NS.StabilizeCoordForWaypointUI(targetX) * 100
    local addY = NS.StabilizeCoordForWaypointUI(targetY) * 100
    if type(nav.NewUserNavigation) == "function" then
        if unsupportedCurrentMap then
            cache.sig = sig
            cache.mapID = playerMapID
            cache.attempts = 1
        else
            ClearUnsupportedRestoreGate()
        end
        nav.NewUserNavigation(repairTitle, targetMapID, addX, addY, "TomTom_Waypoint")
        NS.Log("Restore WaypointUI session", repairTitle, targetMapID, targetX, targetY)
    end
end
