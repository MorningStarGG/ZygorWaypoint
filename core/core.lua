local NS = _G.AzerothWaypointNS

-- ============================================================
-- Namespace bootstrap
-- ============================================================

NS.Constants = NS.Constants or {}
NS.State = NS.State or {}
NS.Runtime = NS.Runtime or {}
NS.State.debugTrace = NS.State.debugTrace or {}

-- Performance profiling counters, reset at the start of each /awp churn run.
NS.State.churn = NS.State.churn or {
    active = false,
    startedAt = 0,
    duration = 0,
    startMem = 0,
    tickUpdate = 0,
    tickFromHook = 0,
    tickFromHeartbeat = 0,
    tickFromOther = 0,
    resolveHit = 0,
    resolveMiss = 0,
    resolveMissNoCache = 0,
    resolveMissStep = 0,
    resolveMissGoal = 0,
    resolveMissTargetSig = 0,
    resolveMissMap = 0,
    resolveMissCoord = 0,
    resolveMissKind = 0,
    resolveMissLegKind = 0,
    resolveMissRouteType = 0,
    resolveMissTitle = 0,
    resolveMissFactsEpoch = 0,
    resolveMissDialogEpoch = 0,
    resolveMissFactsDirty = 0,
    resolveMissFullDebug = 0,
    resolveMissOther = 0,
    buildFacts = 0,
    invalidateFacts = 0,
    invalidateDialog = 0,
    driverUpdate = 0,
    driverUpdateHidden = 0,
    driverVisuals = 0,
    nativeWorldOverlayUpdate = 0,
    extractWaypoint = 0,
    extractManual = 0,
    manualMapPinAreaHit = 0,
    manualMapPinAreaMiss = 0,
    manualMapPinTaxiHit = 0,
    manualMapPinTaxiMiss = 0,
    manualIdentityAreaHit = 0,
    manualIdentityAreaMiss = 0,
    manualIdentityTaxiHit = 0,
    manualIdentityTaxiMiss = 0,
    manualIdentityEmptyBase = 0,
    manualPersistCalls = 0,
    manualPersistRecordReuse = 0,
    manualPersistRecordBuild = 0,
    manualPersistEqualSkip = 0,
    manualPersistWrite = 0,
    manualPersistNoRecord = 0,
    routePlanAccept = 0,
    routePlanSkip = 0,
    routeBackendInvalidation = 0,
    routeBackendInvalidationSkip = 0,
    ensureHost = 0,
    resolveSettableTarget = 0,
    trySetHost = 0,
    setUserWaypointCall = 0,
    hostNotReady = 0,
    hostThrottled = 0,
    refreshWorldOverlay = 0,
    userWaypointUpdatedEvent = 0,
    phaseMemoryEnabled = false,
    phaseBridgeSetupKB = 0,
    phaseManualExtractKB = 0,
    phaseManualLookupKB = 0,
    phaseManualMapPinResolveKB = 0,
    phaseManualMapPinKeyKB = 0,
    phaseManualIdentityResolveKB = 0,
    phaseTargetKB = 0,
    phaseRouteKB = 0,
    phaseResolverKB = 0,
    phaseFinalizeKB = 0,
    phaseBridgeStatePrepKB = 0,
    phaseBridgeStatePersistKB = 0,
    phaseBridgeStateCompareKB = 0,
    phaseBridgePushKB = 0,
    phaseBridgeOverlayKB = 0,
    phaseWorldOverlayKB = 0,
    phaseNativeSyncKB = 0,
    phaseNativeUpdateKB = 0,
    peakMemKB = 0,
    samples = 0,
}

-- ============================================================
-- Constants
-- ============================================================

local C = NS.Constants

-- Skin / theme identifiers
C.SKIN_DEFAULT = "default"
C.SKIN_STARLIGHT = "starlight"
C.SKIN_STEALTH = "stealth"
C.THEME_STARLIGHT = "awp-zyg-starlight"
C.THEME_STEALTH = "awp-zyg-stealth"

-- Scale and distance settings
C.SCALE_DEFAULT = 1.00
C.SCALE_MIN = 0.60
C.SCALE_MAX = 2.00
C.SCALE_STEP = 0.05
C.MANUAL_CLEAR_DISTANCE_DEFAULT = 10
C.MANUAL_CLEAR_DISTANCE_MIN = 5
C.MANUAL_CLEAR_DISTANCE_MAX = 100
C.MANUAL_CLEAR_DISTANCE_STEP = 1

-- Guide compact chrome step background modes
C.GUIDE_STEP_BACKGROUND_MODE_NONE = "none"
C.GUIDE_STEP_BACKGROUND_MODE_BG = "bg"
C.GUIDE_STEP_BACKGROUND_MODE_BG_GOAL = "bg_goal"

C.GUIDE_STEP_BACKGROUND_MODES = {
    [C.GUIDE_STEP_BACKGROUND_MODE_NONE] = true,
    [C.GUIDE_STEP_BACKGROUND_MODE_BG] = true,
    [C.GUIDE_STEP_BACKGROUND_MODE_BG_GOAL] = true,
}

-- Timing constants
C.UPDATE_INTERVAL_SECONDS = 0.35
C.FALLBACK_DEBOUNCE_SECONDS = 1.20
C.FALLBACK_CONFIRM_COUNT = 2
C.DEST_FALLBACK_SUPPRESS_RECENT_ARROW_SECONDS = 2.50
C.DEST_FALLBACK_SUPPRESS_MAP_MISMATCH_SECONDS = 25.00
C.ROUTE_RECALC_HOLD_SECONDS = 0.10

-- User waypoint coordinate constants
C.USER_WAYPOINT_COORD_BIAS = 1e-5
C.MAX_PARENT_MAP_DEPTH = 12
C.COORD_BOUNDS_EPSILON = 0.001

-- World overlay backend identifiers
C.WORLD_OVERLAY_BACKEND_NONE = "none"
C.WORLD_OVERLAY_BACKEND_NATIVE = "native"

-- World overlay info mode identifiers
C.WORLD_OVERLAY_INFO_ALL = "all"
C.WORLD_OVERLAY_INFO_DISTANCE = "distance"
C.WORLD_OVERLAY_INFO_ARRIVAL = "arrival"
C.WORLD_OVERLAY_INFO_DESTINATION = "destination"
C.WORLD_OVERLAY_INFO_NONE = "none"

-- World overlay context display identifiers
C.WORLD_OVERLAY_CONTEXT_DISPLAY_DIAMOND_ICON = "diamond_icon"
C.WORLD_OVERLAY_CONTEXT_DISPLAY_ICON_ONLY = "icon_only"
C.WORLD_OVERLAY_CONTEXT_DISPLAY_HIDDEN = "hidden"

C.WORLD_OVERLAY_CONTEXT_DISPLAY_MODES = {
    [C.WORLD_OVERLAY_CONTEXT_DISPLAY_DIAMOND_ICON] = true,
    [C.WORLD_OVERLAY_CONTEXT_DISPLAY_ICON_ONLY] = true,
    [C.WORLD_OVERLAY_CONTEXT_DISPLAY_HIDDEN] = true,
}

-- World overlay waypoint display mode identifiers
C.WORLD_OVERLAY_WAYPOINT_MODE_FULL     = "full"
C.WORLD_OVERLAY_WAYPOINT_MODE_DISABLED = "disabled"

C.WORLD_OVERLAY_WAYPOINT_MODES = {
    [C.WORLD_OVERLAY_WAYPOINT_MODE_FULL]     = true,
    [C.WORLD_OVERLAY_WAYPOINT_MODE_DISABLED] = true,
}

-- World overlay pinpoint display mode identifiers
C.WORLD_OVERLAY_PINPOINT_MODE_FULL     = "full"
C.WORLD_OVERLAY_PINPOINT_MODE_NO_PLAQUE = "no_plaque"
C.WORLD_OVERLAY_PINPOINT_MODE_DISABLED  = "disabled"

C.WORLD_OVERLAY_PINPOINT_MODES = {
    [C.WORLD_OVERLAY_PINPOINT_MODE_FULL]      = true,
    [C.WORLD_OVERLAY_PINPOINT_MODE_NO_PLAQUE] = true,
    [C.WORLD_OVERLAY_PINPOINT_MODE_DISABLED]  = true,
}

-- World overlay beacon style identifiers
C.WORLD_OVERLAY_BEACON_STYLE_BEACON = "beacon"
C.WORLD_OVERLAY_BEACON_STYLE_BASE = "base"
C.WORLD_OVERLAY_BEACON_STYLE_DISTANCE = "distance"
C.WORLD_OVERLAY_BEACON_STYLE_OFF  = "off"

C.WORLD_OVERLAY_BEACON_STYLES = {
    [C.WORLD_OVERLAY_BEACON_STYLE_BEACON] = true,
    [C.WORLD_OVERLAY_BEACON_STYLE_BASE] = true,
    [C.WORLD_OVERLAY_BEACON_STYLE_DISTANCE] = true,
    [C.WORLD_OVERLAY_BEACON_STYLE_OFF]  = true,
}

-- World overlay plaque type identifiers
C.WORLD_OVERLAY_PLAQUE_DEFAULT       = "Default"
C.WORLD_OVERLAY_PLAQUE_GLOWING_GEMS  = "GlowingGems"
C.WORLD_OVERLAY_PLAQUE_HORDE         = "HordePlaque"
C.WORLD_OVERLAY_PLAQUE_ALLIANCE      = "AlliancePlaque"
C.WORLD_OVERLAY_PLAQUE_MODERN        = "ModernPlaque"
C.WORLD_OVERLAY_PLAQUE_STEAMPUNK     = "SteamPunkPlaque"

C.WORLD_OVERLAY_PLAQUE_TYPES = {
    [C.WORLD_OVERLAY_PLAQUE_DEFAULT]       = true,
    [C.WORLD_OVERLAY_PLAQUE_GLOWING_GEMS]  = true,
    [C.WORLD_OVERLAY_PLAQUE_HORDE]         = true,
    [C.WORLD_OVERLAY_PLAQUE_ALLIANCE]      = true,
    [C.WORLD_OVERLAY_PLAQUE_MODERN]        = true,
    [C.WORLD_OVERLAY_PLAQUE_STEAMPUNK]     = true,
}

-- World overlay color mode identifiers
C.WORLD_OVERLAY_COLOR_AUTO = "auto"
C.WORLD_OVERLAY_COLOR_GRAY = "gray"
C.WORLD_OVERLAY_COLOR_GOLD = "gold"
C.WORLD_OVERLAY_COLOR_WHITE = "white"
C.WORLD_OVERLAY_COLOR_SILVER = "silver"
C.WORLD_OVERLAY_COLOR_CYAN = "cyan"
C.WORLD_OVERLAY_COLOR_BLUE = "blue"
C.WORLD_OVERLAY_COLOR_GREEN = "green"
C.WORLD_OVERLAY_COLOR_RED = "red"
C.WORLD_OVERLAY_COLOR_PURPLE = "purple"
C.WORLD_OVERLAY_COLOR_PINK = "pink"
C.WORLD_OVERLAY_COLOR_CUSTOM = "custom"

C.WORLD_OVERLAY_COLOR_MODES = {
    [C.WORLD_OVERLAY_COLOR_AUTO] = true,
    [C.WORLD_OVERLAY_COLOR_GRAY] = true,
    [C.WORLD_OVERLAY_COLOR_GOLD] = true,
    [C.WORLD_OVERLAY_COLOR_WHITE] = true,
    [C.WORLD_OVERLAY_COLOR_SILVER] = true,
    [C.WORLD_OVERLAY_COLOR_CYAN] = true,
    [C.WORLD_OVERLAY_COLOR_BLUE] = true,
    [C.WORLD_OVERLAY_COLOR_GREEN] = true,
    [C.WORLD_OVERLAY_COLOR_RED] = true,
    [C.WORLD_OVERLAY_COLOR_PURPLE] = true,
    [C.WORLD_OVERLAY_COLOR_PINK] = true,
    [C.WORLD_OVERLAY_COLOR_CUSTOM] = true,
}

C.WORLD_OVERLAY_COLOR_PRESETS = {
    [C.WORLD_OVERLAY_COLOR_GRAY] = { r = 0.89, g = 0.89, b = 0.89 },
    [C.WORLD_OVERLAY_COLOR_GOLD] = { r = 0.95, g = 0.84, b = 0.44 },
    [C.WORLD_OVERLAY_COLOR_WHITE] = { r = 1.00, g = 1.00, b = 1.00 },
    [C.WORLD_OVERLAY_COLOR_SILVER] = { r = 0.78, g = 0.82, b = 0.88 },
    [C.WORLD_OVERLAY_COLOR_CYAN] = { r = 0.72, g = 0.93, b = 1.00 },
    [C.WORLD_OVERLAY_COLOR_BLUE] = { r = 0.38, g = 0.74, b = 1.00 },
    [C.WORLD_OVERLAY_COLOR_GREEN] = { r = 0.42, g = 0.90, b = 0.55 },
    [C.WORLD_OVERLAY_COLOR_RED] = { r = 1.00, g = 0.35, b = 0.35 },
    [C.WORLD_OVERLAY_COLOR_PURPLE] = { r = 0.78, g = 0.58, b = 1.00 },
    [C.WORLD_OVERLAY_COLOR_PINK] = { r = 0.94, g = 0.55, b = 0.82 },
}

NS.Runtime.debug = NS.Runtime.debug == true

-- ============================================================
-- Core utilities
-- ============================================================

local _joinBuf = {}

local function FormatControlCharForChat(char)
    if char == "\r" or char == "\n" or char == "\t" then
        return " "
    end

    local byte = string.byte(char)
    if byte == 31 then
        return "<US>"
    end

    return string.format("<0x%02X>", byte or 0)
end

function NS.SanitizeDiagnosticText(value)
    value = tostring(value)
    return (value:gsub("[%c]", FormatControlCharForChat))
end

local function JoinArgs(...)
    local n = select("#", ...)
    for i = 1, n do
        _joinBuf[i] = NS.SanitizeDiagnosticText(select(i, ...))
    end
    local result = table.concat(_joinBuf, " ", 1, n)
    for i = 1, n do
        _joinBuf[i] = nil
    end
    return result
end

function NS.Msg(...)
    if not DEFAULT_CHAT_FRAME then return end
    DEFAULT_CHAT_FRAME:AddMessage("|cff33ff99[AWP]|r " .. JoinArgs(...))
end

function NS.Log(...)
    if not NS.Runtime.debug or not DEFAULT_CHAT_FRAME then return end
    DEFAULT_CHAT_FRAME:AddMessage("|cff99ccff[AWP-DBG]|r " .. JoinArgs(...))
end

function NS.ChurnPhaseStart()
    local churn = NS.State and NS.State.churn
    if not (churn and churn.active and churn.phaseMemoryEnabled) then
        return nil
    end
    if type(UpdateAddOnMemoryUsage) ~= "function" or type(GetAddOnMemoryUsage) ~= "function" then
        return nil
    end
    UpdateAddOnMemoryUsage()
    return tonumber(GetAddOnMemoryUsage(NS.ADDON_NAME)) or 0
end

function NS.ChurnPhaseEnd(key, startedKB)
    if type(key) ~= "string" or type(startedKB) ~= "number" then
        return
    end
    local churn = NS.State and NS.State.churn
    if not (churn and churn.active and churn.phaseMemoryEnabled) then
        return
    end
    if type(UpdateAddOnMemoryUsage) ~= "function" or type(GetAddOnMemoryUsage) ~= "function" then
        return
    end

    UpdateAddOnMemoryUsage()
    local delta = (tonumber(GetAddOnMemoryUsage(NS.ADDON_NAME)) or startedKB) - startedKB
    if delta <= 0 then
        return
    end

    churn[key] = (tonumber(churn[key]) or 0) + delta
    local peakKey = key .. "Peak"
    if delta > (tonumber(churn[peakKey]) or 0) then
        churn[peakKey] = delta
    end
    local countKey = key .. "Count"
    churn[countKey] = (tonumber(churn[countKey]) or 0) + 1
end

function NS.BumpChurnCounter(key, amount)
    if type(key) ~= "string" or key == "" then
        return
    end

    local churn = NS.State and NS.State.churn
    if type(churn) ~= "table" or churn.active ~= true then
        return
    end

    local delta = tonumber(amount) or 1
    churn[key] = (tonumber(churn[key]) or 0) + delta
end

function NS.ZGV()
    return _G["ZygorGuidesViewer"] or _G["ZGV"]
end

function NS.After(delay, fn)
    C_Timer.After(delay, fn)
end

function NS.SetDebugEnabled(enabled)
    NS.Runtime.debug = enabled and true or false
end

function NS.ToggleDebug()
    NS.Runtime.debug = not NS.Runtime.debug
    return NS.Runtime.debug
end

-- ============================================================
-- Debug hooks
-- ============================================================

local function GetDebugTraceStack()
    local ok, stack = pcall(debugstack, 4, 3, 0)
    if not ok or type(stack) ~= "string" or stack == "" then
        return nil
    end

    stack = stack:gsub("[\r\n]+", " | ")
    return stack
end

function NS.LogSuperTrackTrace(label, ...)
    if not NS.Runtime.debug then
        return
    end

    local stack = GetDebugTraceStack()
    if stack then
        NS.Log(label, ..., stack)
    else
        NS.Log(label, ...)
    end
end

function NS.InstallSuperTrackDebugHooks()
    local trace = NS.State.debugTrace
    if trace.installed then
        return
    end
    trace.installed = true

    if C_SuperTrack then
        if type(C_SuperTrack.SetSuperTrackedUserWaypoint) == "function" then
            hooksecurefunc(C_SuperTrack, "SetSuperTrackedUserWaypoint", function(enabled)
                NS.LogSuperTrackTrace("SetSuperTrackedUserWaypoint", tostring(enabled))
            end)
        end

        if type(C_SuperTrack.SetSuperTrackedQuestID) == "function" then
            hooksecurefunc(C_SuperTrack, "SetSuperTrackedQuestID", function(questID)
                NS.LogSuperTrackTrace("SetSuperTrackedQuestID", tostring(questID))
            end)
        end

        if type(C_SuperTrack.SetSuperTrackedMapPin) == "function" then
            hooksecurefunc(C_SuperTrack, "SetSuperTrackedMapPin", function(pinType, pinID)
                NS.LogSuperTrackTrace("SetSuperTrackedMapPin", tostring(pinType), tostring(pinID))
            end)
        end

        if type(C_SuperTrack.ClearSuperTrackedMapPin) == "function" then
            hooksecurefunc(C_SuperTrack, "ClearSuperTrackedMapPin", function()
                NS.LogSuperTrackTrace("ClearSuperTrackedMapPin")
            end)
        end

        if type(C_SuperTrack.SetSuperTrackedContent) == "function" then
            hooksecurefunc(C_SuperTrack, "SetSuperTrackedContent", function(trackableType, trackableID)
                NS.LogSuperTrackTrace("SetSuperTrackedContent", tostring(trackableType), tostring(trackableID))
            end)
        end

        if type(C_SuperTrack.SetSuperTrackedVignette) == "function" then
            hooksecurefunc(C_SuperTrack, "SetSuperTrackedVignette", function(vignetteGUID)
                NS.LogSuperTrackTrace("SetSuperTrackedVignette", tostring(vignetteGUID))
            end)
        end

        if type(C_SuperTrack.ClearAllSuperTracked) == "function" then
            hooksecurefunc(C_SuperTrack, "ClearAllSuperTracked", function()
                NS.LogSuperTrackTrace("ClearAllSuperTracked")
            end)
        end
    end

    if C_Map then
        if type(C_Map.SetUserWaypoint) == "function" then
            hooksecurefunc(C_Map, "SetUserWaypoint", function(uiMapPoint)
                local mapID = uiMapPoint and uiMapPoint.uiMapID or nil
                NS.LogSuperTrackTrace("SetUserWaypoint", tostring(mapID))
            end)
        end

        if type(C_Map.ClearUserWaypoint) == "function" then
            hooksecurefunc(C_Map, "ClearUserWaypoint", function()
                NS.LogSuperTrackTrace("ClearUserWaypoint")
            end)
        end
    end
end
