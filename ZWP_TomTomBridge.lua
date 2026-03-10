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
    heartbeatFrame = nil,
    heartbeatElapsed = 0,
}

local bridge = state.bridge

local function IsArrowWaypointSource(src)
    return src == "pointer.ArrowFrame.waypoint" or src == "pointer.arrow.waypoint"
end

local function GetStarlightAutoYOffset()
    local scale = C.SCALE_DEFAULT
    if type(NS.GetArrowScale) == "function" then
        scale = tonumber(NS.GetArrowScale()) or C.SCALE_DEFAULT
    end

    -- Keep the tighter look at 1.00x, then progressively lift Starlight at larger scales
    -- so the arrow does not overlap the text block.
    local grow = scale - 1.0
    if grow <= 0 then
        return 0
    end

    local yOffset = grow * 12
    if yOffset > 12 then
        yOffset = 12
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
    if type(NS.GetSkinChoice) == "function" and NS.GetSkinChoice() == C.SKIN_STARLIGHT then
        yOffset = GetStarlightAutoYOffset()
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
        TomTom:RemoveWaypoint(bridge.lastUID)
        bridge.lastUID = nil
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

local function ShouldSuppressDestinationFallback(src, title, m)
    if src ~= "pointer.DestinationWaypoint" then return false end

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
    if not NS.IsBridgeEnabled() then return end

    local m, x, y, title, src = NS.ExtractWaypointFromZygor()
    if not (m and x and y) then return end
    if ShouldSuppressDestinationFallback(src, title, m) then return end

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
    for _, fn in ipairs({ "FocusStep", "SetCurrentStep", "GoalProgress", "UpdateFrame" }) do
        if type(Z[fn]) == "function" then
            hooksecurefunc(Z, fn, function() NS.TickUpdate() end)
        end
    end

    if P and type(P.SetWaypoint) == "function" then
        hooksecurefunc(P, "SetWaypoint", function() NS.TickUpdate() end)
    end

    bridge.zygorTickHooked = true
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
