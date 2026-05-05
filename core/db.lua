local NS = _G.AzerothWaypointNS
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

-- ============================================================
-- Schema
-- ============================================================

local DB_DEFAULTS = {
    guideStepsOnlyHover = false,
    guideStepBackgroundsHover = C.GUIDE_STEP_BACKGROUND_MODE_NONE,
    manualWaypointAutoClear = false,
    manualWaypointClearDistance = C.MANUAL_CLEAR_DISTANCE_DEFAULT,
    trackedQuestAutoRoute = false,
    untrackedQuestAutoClear = false,
    superTrackedQuestAutoClear = false,
    genericAddonBlizzardTakeoverEnabled = true,
    manualClickQueueMode = "replace",

    routingEnabled           = true,
    routingBackend           = "direct",  -- first-run auto-selects zygor | farstrider | mapzeroth | direct
    combatHideMode           = C.COMBAT_HIDE_MODE_DISABLED,
    startupHelpMode          = C.STARTUP_HELP_MODE_CHARACTER,
    startupWhatsNewMode      = C.STARTUP_HELP_MODE_ACCOUNT,
    resumeManualRoute        = true,
    arrowSkin                = C.SKIN_STARLIGHT,
    arrowScale               = C.SCALE_DEFAULT,
    specialTravelDisplayMode = "replace_arrow",  -- "replace_arrow" | "companion_icon"
    specialTravelButtonScale = C.SCALE_DEFAULT,
    -- manualAuthority is the persisted authority record; nil by default
    -- and only set when there is an active manual route to resume.
}

local OVERLAY_SETTING_DEFS = {
    worldOverlayEnabled = { default = true, kind = "boolean" },
    worldOverlayFadeOnHover = { default = true, kind = "boolean" },
    worldOverlayContextDisplayMode = {
        default = C.WORLD_OVERLAY_CONTEXT_DISPLAY_DIAMOND_ICON,
        kind = "string",
        values = C.WORLD_OVERLAY_CONTEXT_DISPLAY_MODES,
    },
    worldOverlayPinpointDistance = { default = 35, kind = "number", min = 25, max = 500, step = 5 },
    worldOverlayHideDistance = { default = 0, kind = "number", min = 0, max = 500, step = 5 },
    worldOverlayUseMeters = { default = false, kind = "boolean" },
    worldOverlayWaypointMode = { default = C.WORLD_OVERLAY_WAYPOINT_MODE_FULL, kind = "string", values = C.WORLD_OVERLAY_WAYPOINT_MODES },
    worldOverlayWaypointSize = { default = 1, kind = "number", min = 0.5, max = 5, step = 0.1 },
    worldOverlayWaypointSizeMin = { default = 0.75, kind = "number", min = 0.125, max = 1, step = 0.125 },
    worldOverlayWaypointSizeMax = { default = 1, kind = "number", min = 1, max = 2, step = 0.1 },
    worldOverlayWaypointOpacity = { default = 1, kind = "number", min = 0.1, max = 1, step = 0.1 },
    worldOverlayWaypointOffsetY = { default = -25, kind = "number", min = -200, max = 200, step = 5 },
    worldOverlayBeaconStyle = { default = C.WORLD_OVERLAY_BEACON_STYLE_DISTANCE, kind = "string", values = C.WORLD_OVERLAY_BEACON_STYLES },
    worldOverlayBeaconBaseDistance = { default = 75, kind = "number", min = 5, max = 500, step = 5 },
    worldOverlayBeaconOpacity = { default = 1, kind = "number", min = 0.1, max = 1, step = 0.1 },
    worldOverlayBeaconBaseOffsetY = { default = 25, kind = "number", min = -200, max = 200, step = 5 },
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
    worldOverlayPinpointManualVerticalGap = { default = 75, kind = "number", min = 75, max = 800, step = 1 },
    worldOverlayShowDestinationInfo = { default = true, kind = "boolean" },
    worldOverlayShowExtendedInfo = { default = true, kind = "boolean" },
    worldOverlayShowCoordinateFallback = { default = true, kind = "boolean" },
    worldOverlayShowPinpointArrows = { default = true, kind = "boolean" },
    worldOverlayNavigatorShow = { default = true, kind = "boolean" },
    worldOverlayNavigatorSize = { default = 1, kind = "number", min = 0.5, max = 2, step = 0.1 },
    worldOverlayNavigatorOpacity = { default = 1, kind = "number", min = 0.1, max = 1, step = 0.1 },
    worldOverlayNavigatorDistance = { default = 1, kind = "number", min = 0.1, max = 3, step = 0.1 },
    worldOverlayNavigatorDynamicDistance = { default = true, kind = "boolean" },
    worldOverlayWaypointTextColorMode = { default = C.WORLD_OVERLAY_COLOR_GRAY, kind = "string", values = C.WORLD_OVERLAY_COLOR_MODES },
    worldOverlayWaypointTextCustomColor = { default = DEFAULT_OVERLAY_CUSTOM_COLOR, kind = "color" },
    worldOverlayPinpointTitleColorMode = { default = C.WORLD_OVERLAY_COLOR_AUTO, kind = "string", values = C.WORLD_OVERLAY_COLOR_MODES },
    worldOverlayPinpointTitleCustomColor = { default = DEFAULT_OVERLAY_CUSTOM_COLOR, kind = "color" },
    worldOverlayPinpointSubtextColorMode = { default = C.WORLD_OVERLAY_COLOR_AUTO, kind = "string", values = C.WORLD_OVERLAY_COLOR_MODES },
    worldOverlayPinpointSubtextCustomColor = { default = DEFAULT_OVERLAY_CUSTOM_COLOR, kind = "color" },
    worldOverlayBeaconColorMode = { default = C.WORLD_OVERLAY_COLOR_AUTO, kind = "string", values = C.WORLD_OVERLAY_COLOR_MODES },
    worldOverlayBeaconCustomColor = { default = DEFAULT_OVERLAY_CUSTOM_COLOR, kind = "color" },
    worldOverlayContextDiamondColorMode = { default = C.WORLD_OVERLAY_COLOR_AUTO, kind = "string", values = C.WORLD_OVERLAY_COLOR_MODES },
    worldOverlayContextDiamondCustomColor = { default = DEFAULT_OVERLAY_CUSTOM_COLOR, kind = "color" },
    worldOverlayIconColorMode = { default = C.WORLD_OVERLAY_COLOR_AUTO, kind = "string", values = C.WORLD_OVERLAY_COLOR_MODES },
    worldOverlayIconCustomColor = { default = DEFAULT_OVERLAY_CUSTOM_COLOR, kind = "color" },
    worldOverlayArrowColorMode = { default = C.WORLD_OVERLAY_COLOR_AUTO, kind = "string", values = C.WORLD_OVERLAY_COLOR_MODES },
    worldOverlayArrowCustomColor = { default = DEFAULT_OVERLAY_CUSTOM_COLOR, kind = "color" },
    worldOverlayNavArrowColorMode = { default = C.WORLD_OVERLAY_COLOR_AUTO, kind = "string", values = C.WORLD_OVERLAY_COLOR_MODES },
    worldOverlayNavArrowCustomColor = { default = DEFAULT_OVERLAY_CUSTOM_COLOR, kind = "color" },
    worldOverlayPlaqueColorMode = { default = C.WORLD_OVERLAY_COLOR_AUTO, kind = "string", values = C.WORLD_OVERLAY_COLOR_MODES },
    worldOverlayPlaqueCustomColor = { default = DEFAULT_OVERLAY_CUSTOM_COLOR, kind = "color" },
    worldOverlayAnimatedColorMode = { default = C.WORLD_OVERLAY_COLOR_AUTO, kind = "string", values = C.WORLD_OVERLAY_COLOR_MODES },
    worldOverlayAnimatedCustomColor = { default = DEFAULT_OVERLAY_CUSTOM_COLOR, kind = "color" },
}

NS.Internal = NS.Internal or {}
NS.Internal.DBDefaults = DB_DEFAULTS
NS.Internal.OverlaySettingDefs = OVERLAY_SETTING_DEFS

state.db = state.db or {
    initCaptured = false,
    hadExistingData = false,
}

local dbState = state.db

local ROUTING_BACKEND_DEFAULT_PRIORITY = {
    {
        id = "zygor",
        addons = { "ZygorGuidesViewer" },
    },
    {
        id = "farstrider",
        addons = { "FarstriderLib", "FarstriderLibData" },
    },
    {
        id = "mapzeroth",
        addons = { "Mapzeroth" },
    },
    {
        id = "direct",
    },
}

local VALID_ROUTING_BACKENDS = {
    zygor = true,
    mapzeroth = true,
    farstrider = true,
    direct = true,
}

local function IsAddonEnabledForInitialRoutingDefault(addonName)
    if type(addonName) ~= "string" or addonName == "" then
        return false
    end
    if type(NS.IsAddonEnabledForCurrentCharacter) == "function"
        and NS.IsAddonEnabledForCurrentCharacter(addonName)
    then
        return true
    end
    return type(NS.IsAddonLoaded) == "function" and NS.IsAddonLoaded(addonName) or false
end

local function AreRoutingBackendDependenciesEnabled(def)
    if type(def) ~= "table" then
        return false
    end
    if def.id == "direct" then
        return true
    end
    if type(def.addons) ~= "table" or #def.addons == 0 then
        return false
    end
    for index = 1, #def.addons do
        if not IsAddonEnabledForInitialRoutingDefault(def.addons[index]) then
            return false
        end
    end
    return true
end

local function SelectInitialRoutingBackend()
    for index = 1, #ROUTING_BACKEND_DEFAULT_PRIORITY do
        local def = ROUTING_BACKEND_DEFAULT_PRIORITY[index]
        if AreRoutingBackendDependenciesEnabled(def) then
            return def.id
        end
    end
    return "direct"
end

-- ============================================================
-- Normalizers
-- ============================================================

function NS.NormalizeSkin(value)
    if value == C.SKIN_DEFAULT then
        return C.SKIN_DEFAULT
    end

    if type(value) == "string" then
        local key = value:lower():gsub("%s+", "_")
        if key ~= "tomtom_default" and type(NS.HasArrowSkin) == "function" and NS.HasArrowSkin(key) then
            return key
        end

        -- During early file load the registry may not exist yet. Runtime
        -- normalization will re-check against the final registered skin list.
        if type(NS.HasArrowSkin) ~= "function" then
            if key == C.SKIN_STARLIGHT or key == C.SKIN_STEALTH then
                return key
            end
        end
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

function NS.NormalizeCombatHideMode(value)
    if type(value) == "string" then
        local key = value:lower():gsub("%s+", "_")
        if key == "off" or key == "none" then
            return C.COMBAT_HIDE_MODE_DISABLED
        end
        if key == "tomtom_arrow" or key == "arrow" then
            return C.COMBAT_HIDE_MODE_TOMTOM
        end
        if key == "world_overlay" or key == "worldoverlay" then
            return C.COMBAT_HIDE_MODE_OVERLAY
        end
        if key == "all" then
            return C.COMBAT_HIDE_MODE_BOTH
        end
        if C.COMBAT_HIDE_MODES[key] then
            return key
        end
    end

    return C.COMBAT_HIDE_MODE_DISABLED
end

function NS.NormalizeStartupHelpMode(value)
    if type(value) == "string" then
        local key = value:lower():gsub("%s+", "_")
        if key == "account_wide" or key == "accountwide" or key == "account" then
            return C.STARTUP_HELP_MODE_ACCOUNT
        end
        if key == "per_character" or key == "character_wide" or key == "char" then
            return C.STARTUP_HELP_MODE_CHARACTER
        end
        if key == "off" or key == "none" or key == "disabled" then
            return C.STARTUP_HELP_MODE_DISABLED
        end
        if C.STARTUP_HELP_MODES[key] then
            return key
        end
    end

    return C.STARTUP_HELP_MODE_ACCOUNT
end

function NS.NormalizeAddonTakeoverName(value)
    if type(value) ~= "string" then
        return nil
    end
    value = value:gsub("^%s+", ""):gsub("%s+$", "")
    value = value:gsub("/", "\\")
    local marker = "Interface\\AddOns\\"
    local lowered = value:lower()
    local markerStart = lowered:find(marker:lower(), 1, true)
    if markerStart then
        value = value:sub(markerStart + #marker)
        local slash = value:find("\\", 1, true)
        if slash then
            value = value:sub(1, slash - 1)
        end
    end
    value = value:gsub("^\\+", ""):gsub("\\+$", "")
    value = value:gsub("^%s+", ""):gsub("%s+$", "")
    if value == "" then
        return nil
    end
    return value
end

local function NormalizeAddonTakeoverList(list)
    local keyed = {}
    local out = {}

    local function add(value)
        local name = NS.NormalizeAddonTakeoverName(value)
        if not name then
            return
        end
        local key = name:lower()
        if keyed[key] then
            return
        end
        keyed[key] = true
        out[#out + 1] = name
    end

    if type(list) == "table" then
        for key, value in pairs(list) do
            if type(key) == "string" and value == true then
                add(key)
            else
                add(value)
            end
        end
    end

    table.sort(out, function(a, b) return a:lower() < b:lower() end)
    return out
end

local function NormalizeAddonTakeoverLists(db)
    db.genericAddonBlizzardTakeoverAllowlist =
        NormalizeAddonTakeoverList(db.genericAddonBlizzardTakeoverAllowlist)
    db.genericAddonBlizzardTakeoverBlocklist =
        NormalizeAddonTakeoverList(db.genericAddonBlizzardTakeoverBlocklist)
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
    if type(AzerothWaypointCharDB) ~= "table" then
        AzerothWaypointCharDB = {}
    end
    return AzerothWaypointCharDB
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

local function ParseVersionSuffix(version)
    if type(version) ~= "string" then
        return ""
    end

    return version:lower():match("^%s*%d+%.%d+%.%d+([%a][%w%-]*)") or ""
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

    local leftSuffix = ParseVersionSuffix(left)
    local rightSuffix = ParseVersionSuffix(right)
    if leftSuffix ~= rightSuffix then
        if leftSuffix == "" then
            return -1
        end
        if rightSuffix == "" then
            return 1
        end
        return leftSuffix < rightSuffix and -1 or 1
    end

    return 0
end

-- ============================================================
-- DB access
-- ============================================================

function NS.GetDB()
    if type(AzerothWaypointDB) ~= "table" then
        AzerothWaypointDB = {}
    end
    return AzerothWaypointDB
end

function NS.ApplyDBDefaults()
    local db = NS.GetDB()
    if not dbState.initCaptured then
        dbState.initCaptured = true
        dbState.hadExistingData = next(db) ~= nil
    end
    for key, value in pairs(DB_DEFAULTS) do
        if db[key] == nil then
            db[key] = value
        end
    end

    db.arrowSkin = NS.NormalizeSkin(db.arrowSkin)
    db.arrowScale = NS.NormalizeScale(db.arrowScale)
    db.specialTravelButtonScale = NS.NormalizeScale(db.specialTravelButtonScale)
    if dbState.hadExistingData == false then
        db.routingBackend = SelectInitialRoutingBackend()
    elseif not VALID_ROUTING_BACKENDS[db.routingBackend] then
        db.routingBackend = "direct"
    end
    db.combatHideMode = NS.NormalizeCombatHideMode(db.combatHideMode)
    db.startupHelpMode = NS.NormalizeStartupHelpMode(db.startupHelpMode)
    db.startupWhatsNewMode = NS.NormalizeStartupHelpMode(db.startupWhatsNewMode)
    db.guideStepBackgroundsHover = NS.NormalizeGuideStepBackgroundsHoverMode(db.guideStepBackgroundsHover)
    db.manualWaypointClearDistance = NS.NormalizeManualWaypointClearDistance(db.manualWaypointClearDistance)
    if db.manualClickQueueMode ~= "create"
        and db.manualClickQueueMode ~= "replace"
        and db.manualClickQueueMode ~= "append"
        and db.manualClickQueueMode ~= "ask"
    then
        db.manualClickQueueMode = "create"
    end
    NormalizeAddonTakeoverLists(db)

    for key, def in pairs(OVERLAY_SETTING_DEFS) do
        if db[key] == nil then
            db[key] = NormalizeOverlaySetting(key, def.default)
        end
        db[key] = NormalizeOverlaySetting(key, db[key])
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

function NS.GetStoredAddonVersionForCurrentCharacter()
    local version = GetCharDB().lastAddonVersion
    if type(version) ~= "string" or version == "" then
        return nil
    end
    return version
end

function NS.UpdateStoredAddonVersionForCurrentCharacter()
    GetCharDB().lastAddonVersion = NS.VERSION
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

function NS.HasSeenZygorArrowPrompt()
    return GetCharDB().zygorArrowPromptShown == true
end

function NS.MarkZygorArrowPromptShown()
    GetCharDB().zygorArrowPromptShown = true
    return true
end

function NS.HasSeenOverviewAccountWide()
    return GetDBMeta().overviewShown == true
end

function NS.MarkOverviewShownAccountWide()
    GetDBMeta().overviewShown = true
    return true
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

function NS.GetStartupHelpMode()
    local db = NS.GetDB()
    db.startupHelpMode = NS.NormalizeStartupHelpMode(db.startupHelpMode)
    return db.startupHelpMode
end

function NS.SetStartupHelpMode(mode)
    local db = NS.GetDB()
    db.startupHelpMode = NS.NormalizeStartupHelpMode(mode)
    return db.startupHelpMode
end

function NS.GetStartupWhatsNewMode()
    local db = NS.GetDB()
    db.startupWhatsNewMode = NS.NormalizeStartupHelpMode(db.startupWhatsNewMode)
    return db.startupWhatsNewMode
end

function NS.SetStartupWhatsNewMode(mode)
    local db = NS.GetDB()
    db.startupWhatsNewMode = NS.NormalizeStartupHelpMode(mode)
    return db.startupWhatsNewMode
end

-- ============================================================
-- Arrow and skin settings
-- ============================================================

function NS.IsRoutingEnabled()
    local db = NS.GetDB()
    return db.routingEnabled ~= false
end

function NS.GetSkinChoice()
    local db = NS.GetDB()
    db.arrowSkin = NS.NormalizeSkin(db.arrowSkin)
    return db.arrowSkin
end

function NS.SetSkinChoice(skin)
    local db = NS.GetDB()
    db.arrowSkin = NS.NormalizeSkin(skin)
end

function NS.GetArrowScale()
    local db = NS.GetDB()
    db.arrowScale = NS.NormalizeScale(db.arrowScale)
    return db.arrowScale
end

function NS.SetArrowScale(value)
    local db = NS.GetDB()
    db.arrowScale = NS.NormalizeScale(value)
    return db.arrowScale
end

function NS.ApplyTomTomScalePolicy()
    local db = NS.GetDB()
    db.arrowScale = NS.NormalizeScale(db.arrowScale)
end

-- ============================================================
-- Combat visibility settings
-- ============================================================

function NS.GetCombatHideMode()
    local db = NS.GetDB()
    db.combatHideMode = NS.NormalizeCombatHideMode(db.combatHideMode)
    return db.combatHideMode
end

function NS.SetCombatHideMode(mode)
    local db = NS.GetDB()
    db.combatHideMode = NS.NormalizeCombatHideMode(mode)
    if type(NS.ApplyCombatVisibilityGuard) == "function" then
        NS.ApplyCombatVisibilityGuard("setting")
    end
    return db.combatHideMode
end

function NS.ShouldHideTomTomInCombat()
    local mode = NS.GetCombatHideMode()
    return mode == C.COMBAT_HIDE_MODE_TOMTOM or mode == C.COMBAT_HIDE_MODE_BOTH
end

function NS.ShouldHideWorldOverlayInCombat()
    local mode = NS.GetCombatHideMode()
    return mode == C.COMBAT_HIDE_MODE_OVERLAY or mode == C.COMBAT_HIDE_MODE_BOTH
end

function NS.GetSpecialTravelButtonScale()
    local db = NS.GetDB()
    db.specialTravelButtonScale = NS.NormalizeScale(db.specialTravelButtonScale)
    return db.specialTravelButtonScale
end

function NS.SetSpecialTravelButtonScale(value)
    local db = NS.GetDB()
    db.specialTravelButtonScale = NS.NormalizeScale(value)
    return db.specialTravelButtonScale
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

function NS.IsTrackedQuestAutoRouteEnabled()
    local db = NS.GetDB()
    return db.trackedQuestAutoRoute == true
end

function NS.SetTrackedQuestAutoRouteEnabled(enabled)
    local db = NS.GetDB()
    db.trackedQuestAutoRoute = enabled and true or false
    return db.trackedQuestAutoRoute
end

function NS.IsUntrackedQuestAutoClearEnabled()
    local db = NS.GetDB()
    return db.untrackedQuestAutoClear ~= false
end

function NS.SetUntrackedQuestAutoClearEnabled(enabled)
    local db = NS.GetDB()
    db.untrackedQuestAutoClear = enabled and true or false
    return db.untrackedQuestAutoClear
end

function NS.IsGenericAddonBlizzardTakeoverEnabled()
    local db = NS.GetDB()
    return db.genericAddonBlizzardTakeoverEnabled == true
end

function NS.SetGenericAddonBlizzardTakeoverEnabled(enabled)
    local db = NS.GetDB()
    db.genericAddonBlizzardTakeoverEnabled = enabled and true or false
    return db.genericAddonBlizzardTakeoverEnabled
end

local function GetAddonTakeoverListField(kind)
    kind = type(kind) == "string" and kind:lower() or ""
    if kind == "allowlist" then
        return "genericAddonBlizzardTakeoverAllowlist", "allowlist"
    end
    if kind == "blocklist" then
        return "genericAddonBlizzardTakeoverBlocklist", "blocklist"
    end
    return nil, nil
end

local function GetNormalizedAddonTakeoverList(db, field)
    db[field] = NormalizeAddonTakeoverList(db[field])
    return db[field]
end

local function FindAddonTakeoverListIndex(list, addonName)
    local normalized = NS.NormalizeAddonTakeoverName(addonName)
    if not normalized then
        return nil, nil
    end
    local key = normalized:lower()
    for index, entry in ipairs(list or {}) do
        if type(entry) == "string" and entry:lower() == key then
            return index, entry
        end
    end
    return nil, normalized
end

function NS.GetGenericAddonBlizzardTakeoverList(kind)
    local field = GetAddonTakeoverListField(kind)
    if not field then
        return {}
    end
    local db = NS.GetDB()
    local list = GetNormalizedAddonTakeoverList(db, field)
    local copy = {}
    for index, entry in ipairs(list) do
        copy[index] = entry
    end
    return copy
end

function NS.AddGenericAddonBlizzardTakeoverListEntry(kind, addonName)
    local field, canonicalKind = GetAddonTakeoverListField(kind)
    if not field then
        return false, "invalid_list"
    end
    local normalized = NS.NormalizeAddonTakeoverName(addonName)
    if not normalized then
        return false, "invalid_addon"
    end

    local db = NS.GetDB()
    local list = GetNormalizedAddonTakeoverList(db, field)
    local existingIndex, existingName = FindAddonTakeoverListIndex(list, normalized)
    if not existingIndex then
        list[#list + 1] = existingName or normalized
        db[field] = NormalizeAddonTakeoverList(list)
    end

    local opposite = canonicalKind == "allowlist"
        and "genericAddonBlizzardTakeoverBlocklist"
        or "genericAddonBlizzardTakeoverAllowlist"
    local oppositeList = GetNormalizedAddonTakeoverList(db, opposite)
    local oppositeIndex = FindAddonTakeoverListIndex(oppositeList, normalized)
    if oppositeIndex then
        table.remove(oppositeList, oppositeIndex)
        db[opposite] = NormalizeAddonTakeoverList(oppositeList)
    end

    return true, normalized
end

function NS.RemoveGenericAddonBlizzardTakeoverListEntry(kind, addonName)
    local field = GetAddonTakeoverListField(kind)
    if not field then
        return false, "invalid_list"
    end
    local db = NS.GetDB()
    local list = GetNormalizedAddonTakeoverList(db, field)
    local index, existingName = FindAddonTakeoverListIndex(list, addonName)
    if not index then
        return false, "not_found"
    end
    table.remove(list, index)
    db[field] = NormalizeAddonTakeoverList(list)
    return true, existingName
end

function NS.ClearGenericAddonBlizzardTakeoverList(kind)
    local field = GetAddonTakeoverListField(kind)
    if not field then
        return false, "invalid_list"
    end
    local db = NS.GetDB()
    db[field] = {}
    return true
end

function NS.GetGenericAddonBlizzardTakeoverDecision(addonName)
    local normalized = NS.NormalizeAddonTakeoverName(addonName)
    if not normalized then
        return false, "invalid_addon"
    end
    local db = NS.GetDB()
    local blocklist = GetNormalizedAddonTakeoverList(db, "genericAddonBlizzardTakeoverBlocklist")
    local blockedIndex, blockedName = FindAddonTakeoverListIndex(blocklist, normalized)
    if blockedIndex then
        return false, "blocklist", blockedName
    end

    local allowlist = GetNormalizedAddonTakeoverList(db, "genericAddonBlizzardTakeoverAllowlist")
    local allowedIndex, allowedName = FindAddonTakeoverListIndex(allowlist, normalized)
    if allowedIndex then
        return true, "allowlist", allowedName
    end

    if db.genericAddonBlizzardTakeoverEnabled == true then
        return true, "unknown_enabled", normalized
    end
    return false, "unknown_disabled", normalized
end

function NS.IsSuperTrackedQuestAutoClearEnabled()
    local db = NS.GetDB()
    return db.superTrackedQuestAutoClear ~= false
end

function NS.SetSuperTrackedQuestAutoClearEnabled(enabled)
    local db = NS.GetDB()
    db.superTrackedQuestAutoClear = enabled and true or false
    return db.superTrackedQuestAutoClear
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
