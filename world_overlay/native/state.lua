local NS = _G.ZygorWaypointNS
local state = NS.State

NS.Internal = NS.Internal or {}
NS.Internal.WorldOverlayNative = NS.Internal.WorldOverlayNative or {}

local M = NS.Internal.WorldOverlayNative

---@class ZWPWorldOverlayNativeTarget
---@field active boolean
---@field uid table|nil
---@field mapID number|nil
---@field x number|nil
---@field y number|nil
---@field title string|nil
---@field source string|nil
---@field kind string|nil
---@field sig string|nil
---@field contentSig string|nil
---@field contentSnapshot table|nil

---@class ZWPWorldOverlayNativeArrival
---@field seconds number
---@field lastDistance number|nil
---@field lastTime number|nil
---@field averageSpeed number|nil

---@class ZWPWorldOverlayNativeDerived
---@field distance number|nil
---@field mode string
---@field clamped boolean
---@field navFrame table|nil
---@field anchorFrame table|nil
---@field anchorX number|nil
---@field anchorY number|nil
---@field iconKey string|nil

-- ============================================================
-- State initialization
-- ============================================================

state.worldOverlayNative = state.worldOverlayNative or {
    target = {
        active = false,
        uid = nil,
        mapID = nil,
        x = nil,
        y = nil,
        title = nil,
        source = nil,
        kind = nil,
        sig = nil,
        contentSig = nil,
        contentSnapshot = nil,
    },
    arrival = {
        seconds = -1,
        lastDistance = nil,
        lastTime = nil,
        averageSpeed = nil,
    },
    derived = {
        distance = nil,
        mode = "hidden",
        clamped = false,
        navFrame = nil,
        anchorFrame = nil,
        anchorX = nil,
        anchorY = nil,
        iconKey = nil,
    },
    transition = {
        active = false,
        fromMode = "hidden",
        toMode = "hidden",
        elapsed = 0,
        duration = 0,
    },
    -- Frame references
    driver = nil,
    root = nil,
    waypoint = nil,
    pinpoint = nil,
    navigator = nil,
    -- Hover and update timing
    hovered = false,
    updateElapsed = 0,
    lastAnchorX = nil,
    lastAnchorY = nil,
    -- Host resolution cache
    resolvedHostTargetSig = nil,
    resolvedHostMapID = nil,
    resolvedHostX = nil,
    resolvedHostY = nil,
    resolvedHostWaypointSig = nil,
    -- Host position
    hostMapID = nil,
    hostX = nil,
    hostY = nil,
    -- Instance capability probe
    instanceCapabilityMapID = nil,
    instanceCapabilityKnown = false,
    instanceCapabilityAllowed = false,
    instanceCapabilityPending = false,
    instanceCapabilityLastProbeAt = 0,
    -- SuperTrackedFrame suppression
    superTrackedFrameHooked = false,
    suppressedSuperTrackedVisuals = nil,
    suppressedSuperTrackedVisualRootRef = nil,
    lastSuppressionWanted = false,
    -- Navigation frame cache
    cachedNavFrame = nil,
    -- Special travel
    lastSpecialTravelAt = 0,
    lastSpecialTravelSig = nil,
    -- Content state
    contentDirty = true,
    lastContentRefresh = 0,
    cachedIconSpec = nil,
    cachedPinpointSubtext = nil,
    contentSnapshot = nil,
    questIconCache = {},
    -- Host restore / context
    lastHostRestoreAt = 0,
    contextDisplayMode = nil,
    pinpointArrowsShown = nil,
    -- Navigator fade/clamp
    navFadeAlpha = 0,
    navFadeState = "hidden",
    navigatorClampActive = false,
    -- Pending mode
    pendingMode = nil,
    pendingModeSince = 0,
    pendingModeSig = nil,
    -- Arrival
    arrivalHideActive = false,
}

-- ============================================================
-- Module state
-- ============================================================

M.overlay = state.worldOverlayNative
M.target = M.overlay.target
M.arrival = M.overlay.arrival
M.derived = M.overlay.derived
M.transition = M.overlay.transition
M.questIconCache = M.overlay.questIconCache
M.fontStringTextCache = setmetatable({}, { __mode = "k" })
M.settingsSnapshot = {}

local overlay = M.overlay
local _settings = M.settingsSnapshot
M.frameCache = { waypoint = {}, pinpoint = {}, navigator = {} }
M.settingsDirty = true
M.frameCacheDirty = true

-- ============================================================
-- Frame cache invalidation
-- ============================================================

local function InvalidateFrameVisuals(entry)
    entry.scale = nil
    entry.alpha = nil
    entry.beaconAlpha = nil
    entry.beaconMaskScale = nil
    entry.contextScale = nil
    entry.anchorRef = nil
    entry.anchorX = nil
    entry.anchorY = nil
    entry.angle = nil
    entry.currentPositionX = nil
    entry.currentPositionY = nil
    entry.currentAngle = nil
end

local function InvalidateFrameCacheEntry(key)
    local entry = M.frameCache[key]
    if entry then
        InvalidateFrameVisuals(entry)
        entry.iconSpecRef = nil
        entry.contentTitle = nil
        entry.contentSubtext = nil
        entry.contentShowDest = nil
        entry.contentShowExt = nil
        entry.panelWidth = nil
        entry.layoutWidth = nil
    end
end

local function InvalidateFrameVisualsOnly(key)
    local entry = M.frameCache[key]
    if entry then
        InvalidateFrameVisuals(entry)
    end
end

-- ============================================================
-- Settings snapshot
-- ============================================================

local function RefreshSettingsSnapshot()
    if not M.settingsDirty then
        return
    end

    local getWorldOverlaySetting = NS.GetWorldOverlaySetting
    local defs = NS.Internal.OverlaySettingDefs

    for key in pairs(defs) do
        _settings[key] = getWorldOverlaySetting(key)
    end

    M.settingsDirty = false
end

-- ============================================================
-- Exports
-- ============================================================

local function unpackCoords(values)
    return values[1], values[2], values[3], values[4]
end

function M.InvalidateOverlaySettings()
    M.settingsDirty = true
    M.frameCacheDirty = true
    overlay.contentDirty = true
    overlay.contextDisplayMode = nil
    overlay.pinpointArrowsShown = nil
end

M.InvalidateFrameCacheEntry = InvalidateFrameCacheEntry
M.InvalidateFrameVisualsOnly = InvalidateFrameVisualsOnly
M.RefreshSettingsSnapshot = RefreshSettingsSnapshot
M.unpackCoords = unpackCoords
