local NS = _G.ZygorWaypointNS
local C = NS.Constants
local M = NS.Internal.WorldOverlayNative
local _settings = M.settingsSnapshot
local CFG = M.Config

local DEFAULT_TINT = CFG.DEFAULT_TINT
local COLOR_PRESETS = C.WORLD_OVERLAY_COLOR_PRESETS
local NEUTRAL_COLOR = COLOR_PRESETS[C.WORLD_OVERLAY_COLOR_WHITE] or { r = 1, g = 1, b = 1, a = 1 }
local FALLBACK_CUSTOM_COLOR = COLOR_PRESETS[C.WORLD_OVERLAY_COLOR_GOLD] or DEFAULT_TINT or NEUTRAL_COLOR

local COLOR_SETTING_KEYS = {
    waypointText = {
        mode = "worldOverlayWaypointTextColorMode",
        custom = "worldOverlayWaypointTextCustomColor",
    },
    pinpointTitle = {
        mode = "worldOverlayPinpointTitleColorMode",
        custom = "worldOverlayPinpointTitleCustomColor",
    },
    pinpointSubtext = {
        mode = "worldOverlayPinpointSubtextColorMode",
        custom = "worldOverlayPinpointSubtextCustomColor",
    },
    beacon = {
        mode = "worldOverlayBeaconColorMode",
        custom = "worldOverlayBeaconCustomColor",
    },
    contextDiamond = {
        mode = "worldOverlayContextDiamondColorMode",
        custom = "worldOverlayContextDiamondCustomColor",
    },
    icon = {
        mode = "worldOverlayIconColorMode",
        custom = "worldOverlayIconCustomColor",
    },
    arrow = {
        mode = "worldOverlayArrowColorMode",
        custom = "worldOverlayArrowCustomColor",
    },
    navArrow = {
        mode = "worldOverlayNavArrowColorMode",
        custom = "worldOverlayNavArrowCustomColor",
    },
    plaque = {
        mode = "worldOverlayPlaqueColorMode",
        custom = "worldOverlayPlaqueCustomColor",
    },
    animated = {
        mode = "worldOverlayAnimatedColorMode",
        custom = "worldOverlayAnimatedCustomColor",
    },
}

local function CopyColor(color)
    color = color or DEFAULT_TINT or NEUTRAL_COLOR
    return {
        r = color.r or 1,
        g = color.g or 1,
        b = color.b or 1,
        a = color.a,
    }
end

local function GetNeutralColor()
    return NEUTRAL_COLOR
end

local function GetDefaultSurfaceColor(iconSpec, surfaceKey)
    if surfaceKey == "waypointText" and type(iconSpec) == "table" then
        local waypointTextTint = iconSpec.waypointTextTint
        if type(waypointTextTint) == "table" then
            return waypointTextTint
        end
    end

    return (iconSpec and iconSpec.tint) or DEFAULT_TINT or NEUTRAL_COLOR
end

local function GetSurfaceMode(surfaceKey)
    local keys = COLOR_SETTING_KEYS[surfaceKey]
    if not keys then
        return C.WORLD_OVERLAY_COLOR_DEFAULT
    end

    local mode = _settings[keys.mode]
    if type(mode) ~= "string" or not C.WORLD_OVERLAY_COLOR_MODES[mode] then
        return C.WORLD_OVERLAY_COLOR_DEFAULT
    end

    return mode
end

local function GetSurfaceCustomColor(surfaceKey)
    local keys = COLOR_SETTING_KEYS[surfaceKey]
    if not keys then
        return FALLBACK_CUSTOM_COLOR
    end

    return _settings[keys.custom] or FALLBACK_CUSTOM_COLOR
end

local function GetExplicitSurfaceColor(surfaceKey)
    local mode = GetSurfaceMode(surfaceKey)
    if mode == C.WORLD_OVERLAY_COLOR_CUSTOM then
        return GetSurfaceCustomColor(surfaceKey)
    end

    local preset = COLOR_PRESETS[mode]
    if preset then
        return preset
    end

    return nil
end

local function ResolveSurfaceColor(surfaceKey, iconSpec)
    local mode = GetSurfaceMode(surfaceKey)
    if mode == C.WORLD_OVERLAY_COLOR_DEFAULT then
        return GetDefaultSurfaceColor(iconSpec, surfaceKey)
    end
    if mode == C.WORLD_OVERLAY_COLOR_NONE then
        return GetNeutralColor()
    end

    return GetExplicitSurfaceColor(surfaceKey) or GetNeutralColor()
end

function M.ResolveWaypointTextColor(iconSpec)
    return ResolveSurfaceColor("waypointText", iconSpec)
end

function M.ResolvePinpointTitleColor()
    local mode = GetSurfaceMode("pinpointTitle")
    if mode == C.WORLD_OVERLAY_COLOR_DEFAULT or mode == C.WORLD_OVERLAY_COLOR_NONE then
        return nil
    end

    return GetExplicitSurfaceColor("pinpointTitle") or GetNeutralColor()
end

function M.ResolvePinpointSubtextColor()
    local mode = GetSurfaceMode("pinpointSubtext")
    if mode == C.WORLD_OVERLAY_COLOR_DEFAULT or mode == C.WORLD_OVERLAY_COLOR_NONE then
        return nil
    end

    return GetExplicitSurfaceColor("pinpointSubtext") or GetNeutralColor()
end

function M.ResolveBeaconColors(iconSpec)
    local mode = GetSurfaceMode("beacon")
    if mode == C.WORLD_OVERLAY_COLOR_DEFAULT then
        return GetDefaultSurfaceColor(iconSpec, "beacon"), GetNeutralColor()
    end

    local color = (mode == C.WORLD_OVERLAY_COLOR_NONE) and GetNeutralColor()
        or (GetExplicitSurfaceColor("beacon") or GetNeutralColor())
    return color, color
end

function M.ResolveContextDiamondColor(iconSpec)
    return ResolveSurfaceColor("contextDiamond", iconSpec)
end

function M.ResolveIconGlyphStyle(iconSpec)
    local mode = GetSurfaceMode("icon")
    if mode == C.WORLD_OVERLAY_COLOR_DEFAULT then
        return iconSpec and iconSpec.recolor == true or false, GetDefaultSurfaceColor(iconSpec, "icon")
    end
    if mode == C.WORLD_OVERLAY_COLOR_NONE then
        return false, GetNeutralColor()
    end

    return true, GetExplicitSurfaceColor("icon") or GetNeutralColor()
end

function M.ResolveArrowColor(iconSpec)
    return ResolveSurfaceColor("arrow", iconSpec)
end

function M.ResolveNavArrowColor(iconSpec)
    return ResolveSurfaceColor("navArrow", iconSpec)
end

function M.ResolvePlaqueColors()
    local mode = GetSurfaceMode("plaque")
    if mode == C.WORLD_OVERLAY_COLOR_DEFAULT then
        return GetNeutralColor()
    end

    local color = (mode == C.WORLD_OVERLAY_COLOR_NONE) and GetNeutralColor()
        or (GetExplicitSurfaceColor("plaque") or GetNeutralColor())
    return color
end

function M.ResolveAnimatedColor(iconSpec)
    return ResolveSurfaceColor("animated", iconSpec)
end

function M.GetNeutralOverlayColor()
    return GetNeutralColor()
end

function M.CopyOverlayColor(color)
    return CopyColor(color)
end
