local NS = _G.ZygorWaypointNS
local C = NS.Constants
local state = NS.State

local function CopyOverlayColor(color)
    color = color or C.WORLD_OVERLAY_COLOR_PRESETS[C.WORLD_OVERLAY_COLOR_GOLD] or { r = 0.95, g = 0.84, b = 0.44 }
    return {
        r = color.r or 1,
        g = color.g or 1,
        b = color.b or 1,
    }
end

local DEFAULT_OVERLAY_CUSTOM_COLOR = CopyOverlayColor(C.WORLD_OVERLAY_COLOR_PRESETS[C.WORLD_OVERLAY_COLOR_GOLD])
local LEGACY_2X_SAVED_VARIABLE_CLEANUP_VERSION = 1
local LEGACY_2X_OBSOLETE_DB_KEYS = {
    "auto",
    "autoPureTomTomWhenGuideHidden",
    "autoTomTomTextWhenGuideHidden",
    -- Replaced by ZygorWaypointCharDB after character-only state moved out
    -- of the global SavedVariables table.
    "characters",
    "disableWhenGuideHidden",
    "hiddenTomTomOnlyWhenGuideHidden",
    "pauseGuideWhenHidden",
    "pureTomTomWhenGuideHidden",
    "pureTomTomWhenHidden",
    "sync",
    "threeDWaypointEnabled",
    "threeDWaypointHideDistance",
    "threeDWaypointNavigator",
    "threeDWaypointPinpointDistance",
    "threeDWaypointScale",
    "threeDWaypointShowDistance",
    "threeDWaypointShowTitle",
    "tomtomOverride",
    "tomtomRegularScale",
    "tomtomScaleOverridden",
    "waypointUIHideDistance",
    "waypointUIOverride",
    "worldOverlayAdditionalInfo",
    "worldOverlayBeamColorMode",
    "worldOverlayBeamCustomColor",
    "worldOverlayBeamOpacity",
    "worldOverlayBeamStyle",
    "worldOverlayPinpointTextColorMode",
    "worldOverlayPinpointTextCustomColor",
    "worldOverlayShowBeam",
    "worldOverlayShowContextDiamond",
    "worldOverlayShowInfoText",
    "worldOverlayShowWhenUIHidden",
}

-- ============================================================
-- Schema
-- ============================================================

local DB_DEFAULTS = {
    arrowAlignment = true,
    zygorRouting = true,
    tomtomSkin = C.SKIN_STARLIGHT,
    tomtomArrowScale = C.SCALE_DEFAULT,
    guideStepsOnlyHover = false,
    guideStepBackgroundsHover = C.GUIDE_STEP_BACKGROUND_MODE_NONE,
    manualWaypointAutoClear = false,
    manualWaypointClearDistance = C.MANUAL_CLEAR_DISTANCE_DEFAULT,
    manualQueueAutoRouting = false,
}

local OVERLAY_SETTING_DEFS = {
    worldOverlayEnabled = { default = true, kind = "boolean" },
    worldOverlayFadeOnHover = { default = true, kind = "boolean" },
    worldOverlayContextDisplayMode = {
        default = C.WORLD_OVERLAY_CONTEXT_DISPLAY_DIAMOND_ICON,
        kind = "string",
        values = C.WORLD_OVERLAY_CONTEXT_DISPLAY_MODES,
    },
    worldOverlayPinpointDistance = { default = 50, kind = "number", min = 25, max = 500, step = 5 },
    worldOverlayHideDistance = { default = 5, kind = "number", min = 0, max = 100, step = 1 },
    worldOverlayUseMeters = { default = false, kind = "boolean" },
    worldOverlayWaypointMode = { default = C.WORLD_OVERLAY_WAYPOINT_MODE_FULL, kind = "string", values = C.WORLD_OVERLAY_WAYPOINT_MODES },
    worldOverlayWaypointSize = { default = 1, kind = "number", min = 0.5, max = 5, step = 0.1 },
    worldOverlayWaypointSizeMin = { default = 0.25, kind = "number", min = 0.125, max = 1, step = 0.125 },
    worldOverlayWaypointSizeMax = { default = 1, kind = "number", min = 1, max = 2, step = 0.1 },
    worldOverlayWaypointOpacity = { default = 1, kind = "number", min = 0.1, max = 1, step = 0.1 },
    worldOverlayWaypointOffsetY = { default = -50, kind = "number", min = -200, max = 200, step = 5 },
    worldOverlayBeaconStyle = { default = C.WORLD_OVERLAY_BEACON_STYLE_BEACON, kind = "string", values = C.WORLD_OVERLAY_BEACON_STYLES },
    worldOverlayBeaconOpacity = { default = 1, kind = "number", min = 0.1, max = 1, step = 0.1 },
    worldOverlayInfoTextSize = { default = 1, kind = "number", min = 0.1, max = 2, step = 0.1 },
    worldOverlayInfoTextOpacity = { default = 1, kind = "number", min = 0, max = 1, step = 0.1 },
    worldOverlaySubtextOpacity = { default = 0.7, kind = "number", min = 0, max = 1, step = 0.1 },
    worldOverlayFooterText = {
        default = C.WORLD_OVERLAY_INFO_ALL,
        kind = "string",
        values = {
            [C.WORLD_OVERLAY_INFO_ALL] = true,
            [C.WORLD_OVERLAY_INFO_DISTANCE] = true,
            [C.WORLD_OVERLAY_INFO_ARRIVAL] = true,
            [C.WORLD_OVERLAY_INFO_DESTINATION] = true,
            [C.WORLD_OVERLAY_INFO_NONE] = true,
        },
    },
    worldOverlayPinpointMode = { default = C.WORLD_OVERLAY_PINPOINT_MODE_FULL, kind = "string", values = C.WORLD_OVERLAY_PINPOINT_MODES },
    worldOverlayPinpointPlaqueType = {
        default = C.WORLD_OVERLAY_PLAQUE_DEFAULT,
        kind = "string",
        values = C.WORLD_OVERLAY_PLAQUE_TYPES,
    },
    worldOverlayPinpointSize = { default = 1, kind = "number", min = 0.5, max = 2, step = 0.1 },
    worldOverlayPinpointOpacity = { default = 1, kind = "number", min = 0.1, max = 1, step = 0.1 },
    worldOverlayPinpointAnimatePlaqueEffects = { default = true, kind = "boolean" },
    worldOverlayPinpointAutoVerticalAdjust = { default = true, kind = "boolean" },
    worldOverlayPinpointManualVerticalGap = { default = 200, kind = "number", min = 75, max = 300, step = 1 },
    worldOverlayShowDestinationInfo = { default = true, kind = "boolean" },
    worldOverlayShowExtendedInfo = { default = true, kind = "boolean" },
    worldOverlayShowCoordinateFallback = { default = true, kind = "boolean" },
    worldOverlayShowPinpointArrows = { default = true, kind = "boolean" },
    worldOverlayNavigatorShow = { default = true, kind = "boolean" },
    worldOverlayNavigatorSize = { default = 1, kind = "number", min = 0.5, max = 2, step = 0.1 },
    worldOverlayNavigatorOpacity = { default = 1, kind = "number", min = 0.1, max = 1, step = 0.1 },
    worldOverlayNavigatorDistance = { default = 1, kind = "number", min = 0.1, max = 3, step = 0.1 },
    worldOverlayNavigatorDynamicDistance = { default = true, kind = "boolean" },
    worldOverlayWaypointTextColorMode = { default = C.WORLD_OVERLAY_COLOR_DEFAULT, kind = "string", values = C.WORLD_OVERLAY_COLOR_MODES },
    worldOverlayWaypointTextCustomColor = { default = DEFAULT_OVERLAY_CUSTOM_COLOR, kind = "color" },
    worldOverlayPinpointTitleColorMode = { default = C.WORLD_OVERLAY_COLOR_DEFAULT, kind = "string", values = C.WORLD_OVERLAY_COLOR_MODES },
    worldOverlayPinpointTitleCustomColor = { default = DEFAULT_OVERLAY_CUSTOM_COLOR, kind = "color" },
    worldOverlayPinpointSubtextColorMode = { default = C.WORLD_OVERLAY_COLOR_DEFAULT, kind = "string", values = C.WORLD_OVERLAY_COLOR_MODES },
    worldOverlayPinpointSubtextCustomColor = { default = DEFAULT_OVERLAY_CUSTOM_COLOR, kind = "color" },
    worldOverlayBeaconColorMode = { default = C.WORLD_OVERLAY_COLOR_DEFAULT, kind = "string", values = C.WORLD_OVERLAY_COLOR_MODES },
    worldOverlayBeaconCustomColor = { default = DEFAULT_OVERLAY_CUSTOM_COLOR, kind = "color" },
    worldOverlayContextDiamondColorMode = { default = C.WORLD_OVERLAY_COLOR_DEFAULT, kind = "string", values = C.WORLD_OVERLAY_COLOR_MODES },
    worldOverlayContextDiamondCustomColor = { default = DEFAULT_OVERLAY_CUSTOM_COLOR, kind = "color" },
    worldOverlayIconColorMode = { default = C.WORLD_OVERLAY_COLOR_DEFAULT, kind = "string", values = C.WORLD_OVERLAY_COLOR_MODES },
    worldOverlayIconCustomColor = { default = DEFAULT_OVERLAY_CUSTOM_COLOR, kind = "color" },
    worldOverlayArrowColorMode = { default = C.WORLD_OVERLAY_COLOR_DEFAULT, kind = "string", values = C.WORLD_OVERLAY_COLOR_MODES },
    worldOverlayArrowCustomColor = { default = DEFAULT_OVERLAY_CUSTOM_COLOR, kind = "color" },
    worldOverlayNavArrowColorMode = { default = C.WORLD_OVERLAY_COLOR_DEFAULT, kind = "string", values = C.WORLD_OVERLAY_COLOR_MODES },
    worldOverlayNavArrowCustomColor = { default = DEFAULT_OVERLAY_CUSTOM_COLOR, kind = "color" },
    worldOverlayPlaqueColorMode = { default = C.WORLD_OVERLAY_COLOR_DEFAULT, kind = "string", values = C.WORLD_OVERLAY_COLOR_MODES },
    worldOverlayPlaqueCustomColor = { default = DEFAULT_OVERLAY_CUSTOM_COLOR, kind = "color" },
    worldOverlayAnimatedColorMode = { default = C.WORLD_OVERLAY_COLOR_DEFAULT, kind = "string", values = C.WORLD_OVERLAY_COLOR_MODES },
    worldOverlayAnimatedCustomColor = { default = DEFAULT_OVERLAY_CUSTOM_COLOR, kind = "color" },
}

NS.Internal = NS.Internal or {}
NS.Internal.DBDefaults = DB_DEFAULTS
NS.Internal.OverlaySettingDefs = OVERLAY_SETTING_DEFS

state.db = state.db or {
    initCaptured = false,
    hadExistingData = false,
    previousAddonVersion = nil,
}

local dbState = state.db

-- ============================================================
-- Normalizers
-- ============================================================

function NS.NormalizeSkin(value)
    if value == C.SKIN_STARLIGHT then
        return C.SKIN_STARLIGHT
    end
    if value == C.SKIN_STEALTH then
        return C.SKIN_STEALTH
    end
    return C.SKIN_DEFAULT
end

function NS.NormalizeScale(value)
    local n = tonumber(value) or C.SCALE_DEFAULT
    if n < C.SCALE_MIN then n = C.SCALE_MIN end
    if n > C.SCALE_MAX then n = C.SCALE_MAX end
    n = math.floor((n / C.SCALE_STEP) + 0.5) * C.SCALE_STEP
    return tonumber(string.format("%.2f", n)) or C.SCALE_DEFAULT
end

function NS.NormalizeGuideStepBackgroundsHoverMode(value)
    if value == true then
        return C.GUIDE_STEP_BACKGROUND_MODE_BG
    end

    if value == false or value == nil then
        return C.GUIDE_STEP_BACKGROUND_MODE_NONE
    end

    if C.GUIDE_STEP_BACKGROUND_MODES[value] then
        return value
    end

    return C.GUIDE_STEP_BACKGROUND_MODE_NONE
end

function NS.NormalizeManualWaypointClearDistance(value)
    local n = tonumber(value) or C.MANUAL_CLEAR_DISTANCE_DEFAULT
    if n < C.MANUAL_CLEAR_DISTANCE_MIN then n = C.MANUAL_CLEAR_DISTANCE_MIN end
    if n > C.MANUAL_CLEAR_DISTANCE_MAX then n = C.MANUAL_CLEAR_DISTANCE_MAX end
    n = math.floor((n / C.MANUAL_CLEAR_DISTANCE_STEP) + 0.5) * C.MANUAL_CLEAR_DISTANCE_STEP
    return n
end

-- Pre-compute format strings for each number-type overlay setting def.
-- This avoids creating 5 temporary strings per GetSetting call in the hot path.
for _, def in pairs(OVERLAY_SETTING_DEFS) do
    if def.kind == "number" then
        local step = def.step or 1
        local stepString = tostring(step)
        local decimals = stepString:match("%.(%d+)")
        def._precision = decimals and #decimals or 0
        if def._precision > 0 then
            def._fmt = "%." .. tostring(def._precision) .. "f"
        end
    end
end

local function NormalizeOverlayNumber(def, value)
    local n = tonumber(value) or def.default
    if n < def.min then n = def.min end
    if n > def.max then n = def.max end
    local step = def.step or 1
    n = math.floor((n / step) + 0.5) * step
    if def._fmt then
        return tonumber(string.format(def._fmt, n)) or def.default
    end
    return n
end

local function ClampColorComponent(value, fallback)
    local n = tonumber(value)
    if not n then
        return fallback
    end

    if n < 0 then n = 0 end
    if n > 1 then n = 1 end
    return n
end

local function NormalizeOverlayColor(def, value)
    local fallback = type(def.default) == "table" and def.default or DEFAULT_OVERLAY_CUSTOM_COLOR
    local r = fallback.r or 1
    local g = fallback.g or 1
    local b = fallback.b or 1

    if type(value) == "table" then
        r = ClampColorComponent(value.r ~= nil and value.r or value[1], r)
        g = ClampColorComponent(value.g ~= nil and value.g or value[2], g)
        b = ClampColorComponent(value.b ~= nil and value.b or value[3], b)
    elseif type(value) == "string" then
        local hex = value:gsub("^#", "")
        if #hex == 8 then
            hex = hex:sub(3)
        end
        if #hex == 6 then
            local parsedR = tonumber(hex:sub(1, 2), 16)
            local parsedG = tonumber(hex:sub(3, 4), 16)
            local parsedB = tonumber(hex:sub(5, 6), 16)
            if parsedR and parsedG and parsedB then
                r = parsedR / 255
                g = parsedG / 255
                b = parsedB / 255
            end
        end
    end

    return {
        r = r,
        g = g,
        b = b,
    }
end

local function NormalizeOverlaySetting(key, value)
    local def = OVERLAY_SETTING_DEFS[key]
    if not def then
        return value
    end

    if def.kind == "boolean" then
        return value and true or false
    end

    if def.kind == "string" then
        if type(value) == "string" and def.values and def.values[value] then
            return value
        end
        return def.default
    end

    if def.kind == "number" then
        return NormalizeOverlayNumber(def, value)
    end

    if def.kind == "color" then
        return NormalizeOverlayColor(def, value)
    end

    return value
end

local function GetDBMeta()
    local db = NS.GetDB()
    if type(db._meta) ~= "table" then
        db._meta = {}
    end
    return db._meta
end

local function GetCharDB()
    if type(ZygorWaypointCharDB) ~= "table" then
        ZygorWaypointCharDB = {}
    end
    return ZygorWaypointCharDB
end

local function ParseVersionParts(version)
    if type(version) ~= "string" or version == "" then
        return nil
    end

    local parts = {}
    for token in version:gmatch("(%d+)") do
        parts[#parts + 1] = tonumber(token)
    end

    if #parts == 0 then
        return nil
    end

    return parts
end

function NS.GetAddonVersionMajor(version)
    local parts = ParseVersionParts(version)
    return parts and parts[1] or nil
end

function NS.CompareAddonVersions(left, right)
    local leftParts = ParseVersionParts(left)
    local rightParts = ParseVersionParts(right)

    if not leftParts and not rightParts then
        return 0
    end
    if not leftParts then
        return -1
    end
    if not rightParts then
        return 1
    end

    local count = math.max(#leftParts, #rightParts)
    for i = 1, count do
        local leftPart = leftParts[i] or 0
        local rightPart = rightParts[i] or 0
        if leftPart < rightPart then
            return -1
        end
        if leftPart > rightPart then
            return 1
        end
    end

    return 0
end

local function IsLegacy2xUpgrade(previousVersion)
    if type(previousVersion) ~= "string" or previousVersion == "" then
        return false
    end

    local previousMajor = NS.GetAddonVersionMajor(previousVersion)
    return previousMajor == 2 and NS.CompareAddonVersions(previousVersion, NS.VERSION) < 0
end

local function HasLegacy2xObsoleteDBKeys(db)
    if type(db) ~= "table" then
        return false
    end

    for _, key in ipairs(LEGACY_2X_OBSOLETE_DB_KEYS) do
        if db[key] ~= nil then
            return true
        end
    end

    return false
end

-- ============================================================
-- DB access
-- ============================================================

function NS.GetDB()
    if type(ZygorWaypointDB) ~= "table" then
        ZygorWaypointDB = {}
    end
    return ZygorWaypointDB
end

function NS.ApplyDBDefaults()
    local db = NS.GetDB()
    if not dbState.initCaptured then
        dbState.initCaptured = true
        dbState.hadExistingData = next(db) ~= nil
        if type(db._meta) == "table" and type(db._meta.lastAddonVersion) == "string" and db._meta.lastAddonVersion ~= "" then
            dbState.previousAddonVersion = db._meta.lastAddonVersion
        end
    end

    local meta = GetDBMeta()

    for key, value in pairs(DB_DEFAULTS) do
        if db[key] == nil then
            db[key] = value
        end
    end

    db.enabled = nil

    db.tomtomSkin = NS.NormalizeSkin(db.tomtomSkin)
    db.tomtomArrowScale = NS.NormalizeScale(db.tomtomArrowScale)
    db.guideStepBackgroundsHover = NS.NormalizeGuideStepBackgroundsHoverMode(db.guideStepBackgroundsHover)
    db.manualWaypointClearDistance = NS.NormalizeManualWaypointClearDistance(db.manualWaypointClearDistance)

    if db.worldOverlayWaypointTextColorMode == nil then
        if db.worldOverlayTintInfoText == false then
            db.worldOverlayWaypointTextColorMode = C.WORLD_OVERLAY_COLOR_NONE
        else
            db.worldOverlayWaypointTextColorMode = C.WORLD_OVERLAY_COLOR_DEFAULT
        end
    end
    db.worldOverlayTintInfoText = nil

    for key, def in pairs(OVERLAY_SETTING_DEFS) do
        if db[key] == nil then
            db[key] = NormalizeOverlaySetting(key, def.default)
        end
        db[key] = NormalizeOverlaySetting(key, db[key])
    end

    if meta.legacy2xAutoRepairDone ~= true then
        meta.legacy2xAutoRepairDone = false
    end

    return db
end

function NS.GetStoredAddonVersion()
    local version = GetDBMeta().lastAddonVersion
    if type(version) ~= "string" or version == "" then
        return nil
    end
    return version
end

function NS.UpdateStoredAddonVersion()
    GetDBMeta().lastAddonVersion = NS.VERSION
end

function NS.GetWaypointUIPromptVersion()
    local version = GetCharDB().waypointUIPromptVersion
    if type(version) ~= "string" or version == "" then
        return nil
    end
    return version
end

function NS.MarkWaypointUIPromptShown()
    GetCharDB().waypointUIPromptVersion = NS.VERSION
end

function NS.HasSeenOverviewOnCurrentCharacter()
    return GetCharDB().overviewShown == true
end

function NS.MarkOverviewShownOnCurrentCharacter()
    GetCharDB().overviewShown = true
    return true
end

function NS.MarkPendingOverviewReplayForCurrentCharacter()
    GetCharDB().pendingOverviewReplay = true
    return true
end

function NS.ConsumePendingOverviewReplayForCurrentCharacter()
    local db = GetCharDB()
    if db.pendingOverviewReplay ~= true then
        return false
    end
    db.pendingOverviewReplay = nil
    return true
end

function NS.MarkLegacy2xAutoRepairDone()
    local meta = GetDBMeta()
    if meta.legacy2xAutoRepairDone ~= true then
        meta.legacy2xAutoRepairVersion = NS.VERSION
    end
    meta.legacy2xAutoRepairDone = true
end

function NS.MarkLegacy2xSavedVariableCleanupDone()
    local meta = GetDBMeta()
    meta.legacy2xSavedVariableCleanupVersion = LEGACY_2X_SAVED_VARIABLE_CLEANUP_VERSION
end

function NS.ShouldRunLegacy2xAutoRepair()
    local meta = GetDBMeta()
    if meta.legacy2xAutoRepairDone == true then
        return false
    end

    local currentVersion = NS.VERSION
    local previousVersion = dbState.previousAddonVersion or NS.GetStoredAddonVersion()
    if IsLegacy2xUpgrade(previousVersion) then
        return true
    end

    local currentMajor = NS.GetAddonVersionMajor(currentVersion)
    return dbState.hadExistingData == true and currentMajor == 2
end

function NS.ShouldRunLegacy2xSavedVariableCleanup()
    local meta = GetDBMeta()
    local appliedVersion = tonumber(meta.legacy2xSavedVariableCleanupVersion) or 0
    if appliedVersion >= LEGACY_2X_SAVED_VARIABLE_CLEANUP_VERSION then
        return false
    end

    local previousVersion = dbState.previousAddonVersion or NS.GetStoredAddonVersion()
    if IsLegacy2xUpgrade(previousVersion) then
        return true
    end

    return HasLegacy2xObsoleteDBKeys(NS.GetDB())
end

function NS.RunLegacy2xSavedVariableCleanup()
    local db = NS.GetDB()
    local removed = {}

    for _, key in ipairs(LEGACY_2X_OBSOLETE_DB_KEYS) do
        if db[key] ~= nil then
            db[key] = nil
            removed[#removed + 1] = key
        end
    end

    return removed
end

-- ============================================================
-- Arrow and skin settings
-- ============================================================

function NS.IsRoutingEnabled()
    local db = NS.GetDB()
    return db.zygorRouting ~= false
end

function NS.GetSkinChoice()
    local db = NS.GetDB()
    db.tomtomSkin = NS.NormalizeSkin(db.tomtomSkin)
    return db.tomtomSkin
end

function NS.SetSkinChoice(skin)
    local db = NS.GetDB()
    db.tomtomSkin = NS.NormalizeSkin(skin)
end

function NS.GetArrowScale()
    local db = NS.GetDB()
    db.tomtomArrowScale = NS.NormalizeScale(db.tomtomArrowScale)
    return db.tomtomArrowScale
end

function NS.SetArrowScale(value)
    local db = NS.GetDB()
    db.tomtomArrowScale = NS.NormalizeScale(value)
    return db.tomtomArrowScale
end

function NS.ApplyTomTomScalePolicy()
    local db = NS.GetDB()
    db.tomtomArrowScale = NS.NormalizeScale(db.tomtomArrowScale)
end

-- ============================================================
-- Manual waypoint settings
-- ============================================================

function NS.IsGuideStepsOnlyHoverEnabled()
    local db = NS.GetDB()
    return db.guideStepsOnlyHover == true
end

function NS.SetGuideStepsOnlyHoverEnabled(enabled)
    local db = NS.GetDB()
    db.guideStepsOnlyHover = enabled and true or false
    return db.guideStepsOnlyHover
end

function NS.GetGuideStepBackgroundsHoverMode()
    local db = NS.GetDB()
    db.guideStepBackgroundsHover = NS.NormalizeGuideStepBackgroundsHoverMode(db.guideStepBackgroundsHover)
    return db.guideStepBackgroundsHover
end

function NS.SetGuideStepBackgroundsHoverMode(mode)
    local db = NS.GetDB()
    db.guideStepBackgroundsHover = NS.NormalizeGuideStepBackgroundsHoverMode(mode)
    return db.guideStepBackgroundsHover
end

function NS.IsGuideStepBackgroundsHoverEnabled()
    return NS.GetGuideStepBackgroundsHoverMode() ~= C.GUIDE_STEP_BACKGROUND_MODE_NONE
end

function NS.SetGuideStepBackgroundsHoverEnabled(enabled)
    if enabled then
        return NS.SetGuideStepBackgroundsHoverMode(C.GUIDE_STEP_BACKGROUND_MODE_BG)
    end
    return NS.SetGuideStepBackgroundsHoverMode(C.GUIDE_STEP_BACKGROUND_MODE_NONE)
end

function NS.IsManualWaypointAutoClearEnabled()
    local db = NS.GetDB()
    return db.manualWaypointAutoClear == true
end

function NS.SetManualWaypointAutoClearEnabled(enabled)
    local db = NS.GetDB()
    db.manualWaypointAutoClear = enabled and true or false
    return db.manualWaypointAutoClear
end

function NS.GetManualWaypointClearDistance()
    local db = NS.GetDB()
    db.manualWaypointClearDistance = NS.NormalizeManualWaypointClearDistance(db.manualWaypointClearDistance)
    return db.manualWaypointClearDistance
end

function NS.SetManualWaypointClearDistance(value)
    local db = NS.GetDB()
    db.manualWaypointClearDistance = NS.NormalizeManualWaypointClearDistance(value)
    return db.manualWaypointClearDistance
end

function NS.IsManualQueueAutoRoutingEnabled()
    local db = NS.GetDB()
    return db.manualQueueAutoRouting == true
end

function NS.SetManualQueueAutoRoutingEnabled(enabled)
    local db = NS.GetDB()
    db.manualQueueAutoRouting = enabled and true or false

    if not db.manualQueueAutoRouting then
        NS.ClearManualRouteQueue()
    end

    return db.manualQueueAutoRouting
end

-- ============================================================
-- Overlay settings
-- ============================================================

function NS.IsWorldOverlayEnabled()
    return NS.GetWorldOverlaySetting("worldOverlayEnabled") == true
end

local _overlaySettingCache = {}
local _overlaySettingCacheRaw = {}

function NS.GetWorldOverlaySetting(key)
    local def = OVERLAY_SETTING_DEFS[key]
    if not def then
        return nil
    end

    local db = NS.GetDB()
    local raw = db[key]
    if _overlaySettingCacheRaw[key] == raw and _overlaySettingCache[key] ~= nil then
        return _overlaySettingCache[key]
    end

    local normalized
    if raw == nil then
        normalized = NormalizeOverlaySetting(key, def.default)
    else
        normalized = NormalizeOverlaySetting(key, raw)
    end
    db[key] = normalized
    _overlaySettingCacheRaw[key] = normalized
    _overlaySettingCache[key] = normalized
    return normalized
end

function NS.SetWorldOverlaySetting(key, value)
    local def = OVERLAY_SETTING_DEFS[key]
    if not def then
        return nil
    end

    _overlaySettingCache[key] = nil
    _overlaySettingCacheRaw[key] = nil

    local db = NS.GetDB()
    db[key] = NormalizeOverlaySetting(key, value)

    NS.InvalidateOverlaySettings()

    return db[key]
end
