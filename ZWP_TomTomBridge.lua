local NS = _G.ZygorWaypointNS
local C = NS.Constants
local state = NS.State

state.bridge = state.bridge or {
    lastSig = nil,
    lastUID = nil,
    lastAppliedSource = nil,
    lastAppliedAt = 0,
    lastArrowSeenAt = 0,
    lastArrowSeenMap = nil,
    pendingFallbackSwitch = nil,
    lastSuppressLogAt = 0,
    lastSuppressLogSig = nil,
    unifiedDragHooked = false,
    zygorTickHooked = false,
    zygorArrowHooked = false,
    zygorGuideGuardsHooked = false,
    guideVisibilityState = nil,
    cinematicActive = false,
    heartbeatFrame = nil,
    heartbeatElapsed = 0,
    manualAutoClearWaypoint = nil,
    manualAutoClearArmed = false,
    suppressTomTomClearSync = 0,
}

local bridge = state.bridge
local HBD = _G.LibStub and LibStub("HereBeDragons-2.0", true)

local function IsArrowWaypointSource(src)
    return src == "pointer.ArrowFrame.waypoint" or src == "pointer.arrow.waypoint"
end

local function GetCustomSkinAutoYOffset()
    local skin = type(NS.GetSkinChoice) == "function" and NS.GetSkinChoice() or C.SKIN_DEFAULT
    local scale = C.SCALE_DEFAULT
    if type(NS.GetArrowScale) == "function" then
        scale = tonumber(NS.GetArrowScale()) or C.SCALE_DEFAULT
    end

    -- Keep custom skins tight, but give Stealth a small baseline lift because its
    -- lower edge rides closer to the travel text than Starlight does.
    local yOffset = (skin == C.SKIN_STEALTH) and 3 or 0

    -- Progressively lift custom skins at larger scales so the arrow does not
    -- overlap the text block.
    local grow = scale - 1.0
    if grow > 0 then
        yOffset = yOffset + (grow * 12)
        if yOffset > 15 then
            yOffset = 15
        end
    end
    return yOffset
end

function NS.AlignTomTomToZygor()
    local Z = NS.ZGV()
    if not Z or not Z.Pointer or not Z.Pointer.ArrowFrame then return end

    local zygorFrame = Z.Pointer.ArrowFrame
    local tomArrow = _G.TomTomCrazyArrow
    if not tomArrow then return end

    local yOffset = 10
    if type(NS.GetSkinChoice) == "function" and NS.GetSkinChoice() ~= C.SKIN_DEFAULT then
        yOffset = GetCustomSkinAutoYOffset()
    end

    tomArrow:ClearAllPoints()
    tomArrow:SetPoint("CENTER", zygorFrame, "CENTER", 0, yOffset)
end

function NS.HookUnifiedArrowDrag()
    if bridge.unifiedDragHooked then return end

    local Z = NS.ZGV()
    if not Z or not Z.Pointer or not Z.Pointer.ArrowFrame then return end

    local zFrame = Z.Pointer.ArrowFrame
    local tFrame = _G.TomTomCrazyArrow
    if not tFrame then return end

    zFrame:SetMovable(true)
    zFrame:EnableMouse(true)

    tFrame:SetMovable(false)
    tFrame:EnableMouse(false)

    bridge.unifiedDragHooked = true
end

function NS.EnsureGuideArrowVisibilityPolicy()
    local Z = NS.ZGV()
    if not Z or not Z.db or not Z.db.profile then return end

    if Z.db.profile.hidearrowwithguide == false then return end

    Z.db.profile.hidearrowwithguide = false

    local P = Z.Pointer
    if P and type(P.UpdateArrowVisibility) == "function" then
        P:UpdateArrowVisibility()
    end
end

local function ResetAppliedWaypointState()
    bridge.lastSig = nil
    bridge.lastAppliedSource = nil
    bridge.lastAppliedAt = 0
    bridge.lastArrowSeenAt = 0
    bridge.lastArrowSeenMap = nil
    bridge.pendingFallbackSwitch = nil
    bridge.lastSuppressLogAt = 0
    bridge.lastSuppressLogSig = nil
end

local function ResetManualAutoClearState()
    bridge.manualAutoClearWaypoint = nil
    bridge.manualAutoClearArmed = false
end

function NS.WithTomTomClearSyncSuppressed(fn)
    if type(fn) ~= "function" then
        return
    end

    bridge.suppressTomTomClearSync = (bridge.suppressTomTomClearSync or 0) + 1
    local ok, err = pcall(fn)
    bridge.suppressTomTomClearSync = math.max((bridge.suppressTomTomClearSync or 1) - 1, 0)
    if not ok then
        error(err)
    end
end

local function RemoveBridgeWaypoint()
    if bridge.lastUID and TomTom and type(TomTom.RemoveWaypoint) == "function" then
        if type(NS.WithTomTomClearSyncSuppressed) == "function" then
            NS.WithTomTomClearSyncSuppressed(function()
                TomTom:RemoveWaypoint(bridge.lastUID)
            end)
        else
            TomTom:RemoveWaypoint(bridge.lastUID)
        end
    end
    bridge.lastUID = nil

    if C_Map and C_Map.HasUserWaypoint and C_Map.HasUserWaypoint() then
        C_SuperTrack.SetSuperTrackedUserWaypoint(false)
        C_Map.ClearUserWaypoint()
    end
end

local function ClearBridgeMirror()
    RemoveBridgeWaypoint()
    ResetAppliedWaypointState()
end

local function ClearHiddenGuideWaypoints()
    local Z = NS.ZGV()
    if not Z then return end

    if type(Z.ShowWaypoints) == "function" then
        Z:ShowWaypoints("clear")
    end

    local P = Z.Pointer
    if P and P.ArrowFrame and type(P.HideArrow) == "function" then
        P:HideArrow()
    end
end

local function RefreshVisibleGuideWaypoints()
    local Z = NS.ZGV()
    if not Z then return end

    if type(Z.ShowWaypoints) == "function" then
        Z:ShowWaypoints()
    end

    local P = Z.Pointer
    if P and type(P.UpdateArrowVisibility) == "function" then
        P:UpdateArrowVisibility()
    end
end

local function GetActiveManualDestination()
    local Z = NS.ZGV()
    local P = Z and Z.Pointer
    local destination = P and P.DestinationWaypoint
    if destination and destination.type == "manual" then
        return destination
    end
end

local function IsAutoClearableManualDestination(waypoint)
    return waypoint
        and waypoint.type == "manual"
        and not waypoint.manualnpcid
end

local function GetWaypointDistanceYards(waypoint)
    if not HBD or not waypoint or not waypoint.m or not waypoint.x or not waypoint.y then
        return
    end

    local px, py, pm = HBD:GetPlayerZonePosition(true)
    if not (px and py and pm) then
        return
    end

    return HBD:GetZoneDistance(pm, px, py, waypoint.m, waypoint.x, waypoint.y)
end

local function ClearActiveManualDestination(visibilityState)
    local Z = NS.ZGV()
    local P = Z and Z.Pointer
    if not Z or not P then
        return false
    end

    if type(P.ClearWaypoints) == "function" then
        P:ClearWaypoints("manual")
    else
        return false
    end

    if type(P.HideArrow) == "function" then
        P:HideArrow()
    end

    ClearBridgeMirror()
    ResetManualAutoClearState()

    if visibilityState == "visible" and type(Z.ShowWaypoints) == "function" then
        Z:ShowWaypoints()
        if type(P.UpdateArrowVisibility) == "function" then
            P:UpdateArrowVisibility()
        end
    end

    return true
end

local function MaybeAutoClearManualDestination(visibilityState)
    if not NS.IsManualWaypointAutoClearEnabled or not NS.IsManualWaypointAutoClearEnabled() then
        ResetManualAutoClearState()
        return false
    end

    local clearDistance = type(NS.GetManualWaypointClearDistance) == "function" and NS.GetManualWaypointClearDistance() or 0
    if clearDistance <= 0 then
        ResetManualAutoClearState()
        return false
    end

    local destination = GetActiveManualDestination()
    if not IsAutoClearableManualDestination(destination) then
        ResetManualAutoClearState()
        return false
    end

    local distance = GetWaypointDistanceYards(destination)
    if not distance then
        return false
    end

    if bridge.manualAutoClearWaypoint ~= destination then
        bridge.manualAutoClearWaypoint = destination
        bridge.manualAutoClearArmed = distance > clearDistance
        return false
    end

    if not bridge.manualAutoClearArmed then
        if distance > clearDistance then
            bridge.manualAutoClearArmed = true
        end
        return false
    end

    if distance > clearDistance then
        return false
    end

    return ClearActiveManualDestination(visibilityState)
end

local function IsGuideHiddenState(visibilityState)
    return visibilityState and visibilityState ~= "visible"
end

local function ShouldAllowHiddenArrowWaypoint(waypoint)
    if not waypoint then return true end
    if waypoint.type == "manual" or waypoint.type == "corpse" then
        return true
    end

    local manualDestination = GetActiveManualDestination()
    if not manualDestination then
        return false
    end

    if waypoint == manualDestination then
        return true
    end

    if waypoint.type == "route" then
        return true
    end

    local surrogate = waypoint.surrogate_for
    if surrogate and surrogate.type == "manual" then
        return true
    end

    local sourceWaypoint = waypoint.pathnode and waypoint.pathnode.waypoint
    if sourceWaypoint and sourceWaypoint.type == "manual" then
        return true
    end

    return false
end

local function IsGuideGoalWaypoint(waypoint)
    if not waypoint then return false end
    if waypoint.goal then return true end

    local surrogate = waypoint.surrogate_for
    if surrogate and surrogate.goal then
        return true
    end

    local pathWaypoint = waypoint.pathnode and waypoint.pathnode.waypoint
    if pathWaypoint and pathWaypoint.goal then
        return true
    end

    return false
end

local function RestoreHiddenManualArrowIfNeeded()
    local Z = NS.ZGV()
    if not Z or not Z.Pointer then return end

    local P = Z.Pointer
    local destination = P.DestinationWaypoint
    if not destination or destination.type ~= "manual" then return end

    local current = P.ArrowFrame and P.ArrowFrame.waypoint
    if not IsGuideGoalWaypoint(current) then
        return
    end

    if type(P.FindTravelPath) == "function" then
        P:FindTravelPath(destination)
    elseif type(P.ShowArrow) == "function" then
        P:ShowArrow(destination)
    end
end

local function HideUnexpectedHiddenGuideArrow()
    local Z = NS.ZGV()
    if not Z or not Z.Pointer then return end

    local af = Z.Pointer.ArrowFrame
    local waypoint = af and af.waypoint
    if waypoint and waypoint.type ~= "manual" and type(Z.Pointer.HideArrow) == "function" then
        -- The wrappers are the primary fix. This only scrubs stale guide arrows
        -- that can survive login/reload before Zygor fully settles.
        Z.Pointer:HideArrow()
    end
end

local function ShowManualDestinationWhileHidden(pointer, destination)
    if not pointer or not destination then return end

    if type(pointer.FindTravelPath) == "function" then
        return pointer:FindTravelPath(destination)
    end
    if type(pointer.ShowArrow) == "function" then
        return pointer:ShowArrow(destination)
    end
end

local function GetGuideVisibilityState()
    local Z = NS.ZGV()
    if not Z or not Z.Pointer or not Z.Frame then return end

    if bridge.cinematicActive then
        return "cinematic"
    end

    -- UIParent is hidden during cinematics, vista points, and similar
    -- scenes.  Treat as cinematic to avoid nuking waypoint state.
    if not UIParent:IsShown() then
        return "cinematic"
    end

    if Z.Frame:IsVisible() then
        return "visible"
    end

    local waypoint = Z.Pointer.DestinationWaypoint
    if waypoint and waypoint.type == "manual" then
        return "hidden-manual"
    end

    return "hidden-idle"
end

local function SyncGuideVisibilityState()
    NS.EnsureGuideArrowVisibilityPolicy()

    local current = GetGuideVisibilityState()
    if not current then return end

    local previous = bridge.guideVisibilityState
    if current == previous then
        return current
    end

    bridge.guideVisibilityState = current
    NS.Log("Guide visibility state", tostring(previous), "->", current)

    if current == "hidden-idle" then
        ClearHiddenGuideWaypoints()
        ClearBridgeMirror()
    elseif current == "cinematic" then
        -- Blizzard hides UIParent during cinematics. Keep mirrored state
        -- intact and resync once the cinematic ends.
    elseif current == "visible" and previous and previous ~= "visible" then
        RefreshVisibleGuideWaypoints()
    elseif current == "hidden-manual" and previous == "cinematic" then
        local Z = NS.ZGV()
        local P = Z and Z.Pointer
        local destination = P and P.DestinationWaypoint
        if destination and destination.type == "manual" then
            ShowManualDestinationWhileHidden(P, destination)
        end
    end

    -- Re-apply TomTom mouse protection after cinematics, which can
    -- reset EnableMouse during the UI show/hide cycle.
    if previous == "cinematic" and bridge.unifiedDragHooked then
        local ta = _G.TomTomCrazyArrow
        if ta then
            ta:EnableMouse(false)
        end
    end

    return current
end

function NS.SetCinematicActive(active)
    local nextState = active and true or false
    if bridge.cinematicActive == nextState then
        return
    end

    bridge.cinematicActive = nextState
    if nextState then
        bridge.guideVisibilityState = "cinematic"
        return
    end

    -- Let SyncGuideVisibilityState handle the transition once UIParent
    -- is visible again. Schedule a tick to pick it up promptly.
    NS.After(0, NS.TickUpdate)
end

function NS.HandleTomTomMirrorCleared(uid)
    if not uid or uid ~= bridge.lastUID then
        return false
    end

    if (bridge.suppressTomTomClearSync or 0) > 0 then
        return false
    end

    local visibilityState = SyncGuideVisibilityState()
    if not visibilityState then
        return false
    end

    local destination = GetActiveManualDestination()
    if destination then
        return ClearActiveManualDestination(visibilityState)
    end

    ClearBridgeMirror()
    ResetManualAutoClearState()
    return true
end

local function pushTomTom(m, x, y, title, src)
    if not TomTom or not TomTom.AddWaypoint or not TomTom.SetCrazyArrow then
        NS.Msg("TomTom not found (need AddWaypoint + SetCrazyArrow).")
        return
    end

    if type(m) ~= "number" then
        local pm = C_Map.GetBestMapForUnit and C_Map.GetBestMapForUnit("player")
        if pm then m = pm end
    end
    if not (m and x and y) then return end

    if bridge.lastUID and TomTom.RemoveWaypoint then
        if type(NS.WithTomTomClearSyncSuppressed) == "function" then
            NS.WithTomTomClearSyncSuppressed(function()
                TomTom:RemoveWaypoint(bridge.lastUID)
            end)
        else
            TomTom:RemoveWaypoint(bridge.lastUID)
        end
        bridge.lastUID = nil
    end

    if TomTom.waypoints and TomTom.waypoints[m] then
        local dupes = {}
        for key, wp in pairs(TomTom.waypoints[m]) do
            if wp[2] == x and wp[3] == y and not wp.fromZWP then
                dupes[#dupes + 1] = wp
            end
        end
        for _, wp in ipairs(dupes) do
            TomTom:RemoveWaypoint(wp)
        end
    end

    local t = title or " "
    local uid = TomTom:AddWaypoint(m, x, y, { title = t, fromZWP = true })
    if not uid then return end

    bridge.lastUID = uid
    TomTom:SetCrazyArrow(uid, 15, t)
    bridge.lastAppliedSource = src
    bridge.lastAppliedAt = GetTime and GetTime() or 0

    if IsArrowWaypointSource(src) then
        bridge.lastArrowSeenAt = bridge.lastAppliedAt
        bridge.lastArrowSeenMap = m
    end

    local db = NS.GetDB()
    if db.arrowAlignment ~= false then
        NS.AlignTomTomToZygor()
        NS.HookUnifiedArrowDrag()
    end

    NS.Log("SetCrazyArrow", src, m, x, y, t)
end

local function signature(m, x, y)
    if type(x) == "number" then
        x = math.floor(x * 10000 + 0.5) / 10000
    end
    if type(y) == "number" then
        y = math.floor(y * 10000 + 0.5) / 10000
    end
    return tostring(m) .. ":" .. tostring(x) .. ":" .. tostring(y)
end

local function LogSuppressOnce(reason, src, title, m)
    local now = GetTime and GetTime() or 0
    local sig = tostring(reason) .. "|" .. tostring(src) .. "|" .. tostring(title) .. "|" .. tostring(m)
    if sig ~= bridge.lastSuppressLogSig or (now - bridge.lastSuppressLogAt) > 1.0 then
        local age = now - (bridge.lastAppliedAt or 0)
        NS.Log(
            "Suppress Destination fallback",
            reason,
            "age",
            string.format("%.2f", age),
            "lastsrc",
            tostring(bridge.lastAppliedSource),
            "map",
            tostring(m),
            "title",
            tostring(title)
        )
        bridge.lastSuppressLogAt = now
        bridge.lastSuppressLogSig = sig
    end
end

local function ShouldSuppressDestinationFallback(src, title, m, allowDestinationFallback)
    if src ~= "pointer.DestinationWaypoint" then return false end
    if allowDestinationFallback then return false end

    local now = GetTime and GetTime() or 0
    local ageSinceArrowSeen = now - (bridge.lastArrowSeenAt or 0)
    local ageSinceApplied = now - (bridge.lastAppliedAt or 0)

    if title == "ZygorRoute" and bridge.lastAppliedSource and bridge.lastAppliedSource ~= "pointer.DestinationWaypoint" then
        LogSuppressOnce("zygorroute", src, title, m)
        return true
    end

    if bridge.lastArrowSeenMap and m and m ~= bridge.lastArrowSeenMap and ageSinceArrowSeen <= C.DEST_FALLBACK_SUPPRESS_MAP_MISMATCH_SECONDS then
        LogSuppressOnce("map-mismatch", src, title, m)
        return true
    end

    if IsArrowWaypointSource(bridge.lastAppliedSource) and ageSinceApplied <= C.DEST_FALLBACK_SUPPRESS_RECENT_ARROW_SECONDS then
        LogSuppressOnce("recent-arrow", src, title, m)
        return true
    end

    return false
end

local function ShouldDebounceFallbackSwitch(sig, src)
    local isFallback = (src == "pointer.DestinationWaypoint")
    if not isFallback then
        bridge.pendingFallbackSwitch = nil
        return false
    end

    if not IsArrowWaypointSource(bridge.lastAppliedSource) then
        bridge.pendingFallbackSwitch = nil
        return false
    end

    local now = GetTime and GetTime() or 0
    if now - (bridge.lastAppliedAt or 0) > C.FALLBACK_DEBOUNCE_SECONDS then
        bridge.pendingFallbackSwitch = nil
        return false
    end

    if not bridge.pendingFallbackSwitch or bridge.pendingFallbackSwitch.sig ~= sig then
        bridge.pendingFallbackSwitch = { sig = sig, count = 1 }
        NS.Log("Debounce hold", src, sig, "1/" .. tostring(C.FALLBACK_CONFIRM_COUNT))
        return true
    end

    bridge.pendingFallbackSwitch.count = bridge.pendingFallbackSwitch.count + 1
    if bridge.pendingFallbackSwitch.count < C.FALLBACK_CONFIRM_COUNT then
        NS.Log(
            "Debounce hold",
            src,
            sig,
            tostring(bridge.pendingFallbackSwitch.count) .. "/" .. tostring(C.FALLBACK_CONFIRM_COUNT)
        )
        return true
    end

    NS.Log(
        "Debounce release",
        src,
        sig,
        tostring(bridge.pendingFallbackSwitch.count) .. "/" .. tostring(C.FALLBACK_CONFIRM_COUNT)
    )
    bridge.pendingFallbackSwitch = nil
    return false
end

function NS.TickUpdate()
    local visibilityState = SyncGuideVisibilityState()
    if MaybeAutoClearManualDestination(visibilityState) then
        return
    end

    if visibilityState == "cinematic" then
        return
    end

    if visibilityState == "hidden-idle" then
        if bridge.lastUID or bridge.lastSig or bridge.lastAppliedSource or bridge.pendingFallbackSwitch then
            ClearBridgeMirror()
        end
        HideUnexpectedHiddenGuideArrow()
        return
    end

    local pointerOnly = (visibilityState == "hidden-manual")
    if pointerOnly then
        RestoreHiddenManualArrowIfNeeded()
    end

    local m, x, y, title, src = NS.ExtractWaypointFromZygor(pointerOnly)
    if not (m and x and y) then
        if bridge.lastAppliedSource and bridge.lastAppliedSource ~= "pointer.DestinationWaypoint" then
            ClearBridgeMirror()
        end
        return
    end
    if ShouldSuppressDestinationFallback(src, title, m, pointerOnly) then return end

    local sig = signature(m, x, y)
    if sig ~= bridge.lastSig then
        if ShouldDebounceFallbackSwitch(sig, src) then return end
        bridge.lastSig = sig
        pushTomTom(m, x, y, title, src)
    end
end

function NS.HookZygorTickHooks()
    if bridge.zygorTickHooked then return end
    local Z = NS.ZGV()
    if not Z then return end

    local P = Z.Pointer
    -- UpdateFrame is a hot redraw path while the guide is visible, so let the
    -- bridge heartbeat handle it instead of calling TickUpdate on every redraw.
    for _, fn in ipairs({ "FocusStep", "SetCurrentStep", "GoalProgress" }) do
        if type(Z[fn]) == "function" then
            hooksecurefunc(Z, fn, function() NS.TickUpdate() end)
        end
    end

    if P and type(P.SetWaypoint) == "function" then
        hooksecurefunc(P, "SetWaypoint", function() NS.TickUpdate() end)
    end

    if P and type(P.ClearWaypoints) == "function" then
        hooksecurefunc(P, "ClearWaypoints", function()
            NS.After(0, NS.TickUpdate)
        end)
    end

    bridge.zygorTickHooked = true
end

function NS.HookZygorGuideGuards()
    if bridge.zygorGuideGuardsHooked then return end

    local Z = NS.ZGV()
    if not Z or not Z.Pointer then return end
    local P = Z.Pointer

    if type(Z.ShowWaypoints) == "function" then
        local originalShowWaypoints = Z.ShowWaypoints
        Z.ShowWaypoints = function(self, command, ...)
            local visibilityState = GetGuideVisibilityState()
            if IsGuideHiddenState(visibilityState) then
                if command == "clear" then
                    return originalShowWaypoints(self, command, ...)
                end

                local manualDestination = GetActiveManualDestination()
                if manualDestination then
                    return ShowManualDestinationWhileHidden(self.Pointer, manualDestination)
                else
                    if self.Pointer and type(self.Pointer.HideArrow) == "function" then
                        self.Pointer:HideArrow()
                    end
                end
                return
            end

            return originalShowWaypoints(self, command, ...)
        end
    end

    if type(P.ShowArrow) == "function" then
        local originalShowArrow = P.ShowArrow
        P.ShowArrow = function(self, waypoint, ...)
            local visibilityState = GetGuideVisibilityState()
            if IsGuideHiddenState(visibilityState) then
                if not ShouldAllowHiddenArrowWaypoint(waypoint) then
                    if type(self.HideArrow) == "function" then
                        self:HideArrow()
                    end
                    return
                end
            end

            return originalShowArrow(self, waypoint, ...)
        end
    end

    bridge.zygorGuideGuardsHooked = true
end

function NS.StartBridgeHeartbeat()
    if bridge.heartbeatFrame then return end

    local frame = CreateFrame("Frame")
    frame:SetScript("OnUpdate", function(_, dt)
        bridge.heartbeatElapsed = bridge.heartbeatElapsed + dt
        if bridge.heartbeatElapsed > C.UPDATE_INTERVAL_SECONDS then
            bridge.heartbeatElapsed = 0
            NS.TickUpdate()
        end
    end)

    bridge.heartbeatFrame = frame
end

function NS.ApplyTomTomArrowDefaults()
    NS.EnsureGuideArrowVisibilityPolicy()

    if TomTom and TomTom.db and TomTom.db.profile then
        if TomTom.db.profile.arrow then
            TomTom.db.profile.arrow.showtta = false
            TomTom.db.profile.arrow.title_alpha = 0
        end

        if TomTom.db.profile.persistence then
            local db = NS.GetDB()
            if db.tomtomOverride ~= false then
                TomTom.db.profile.persistence.cleardistance = 0
            end
        end
    end

    NS.ApplyTomTomScalePolicy()

    if NS.HookTomTomThemeBridge then
        NS.HookTomTomThemeBridge()
    end
    if NS.ApplyTomTomArrowSkin then
        NS.ApplyTomTomArrowSkin()
    end
end

function NS.HideZygorArrowTextures()
    local Z = NS.ZGV()
    if not Z or not Z.Pointer or not Z.Pointer.ArrowFrame then return end

    local f = Z.Pointer.ArrowFrame

    if f.arrow then
        f.arrow:SetAlpha(0)
        if f.arrow.arr then f.arrow.arr:SetAlpha(0) end
        if f.arrow.arrspecular then f.arrow.arrspecular:SetAlpha(0) end
    end

    if f.special then
        f.special:SetAlpha(0)
    end
end

function NS.HookZygorArrowTextures()
    if bridge.zygorArrowHooked then return end

    local Z = NS.ZGV()
    if not Z or not Z.Pointer then return end
    local P = Z.Pointer

    NS.EnsureGuideArrowVisibilityPolicy()

    if type(P.SetArrowSkin) == "function" then
        hooksecurefunc(P, "SetArrowSkin", function()
            NS.After(0.05, NS.HideZygorArrowTextures)
        end)
    end

    if type(P.UpdatePointer) == "function" then
        hooksecurefunc(P, "UpdatePointer", function()
            NS.After(0.05, NS.HideZygorArrowTextures)
        end)
    end

    bridge.zygorArrowHooked = true
    NS.After(0.1, NS.HideZygorArrowTextures)
end
