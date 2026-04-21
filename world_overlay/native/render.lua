local NS = _G.ZygorWaypointNS
local C = NS.Constants
local M = NS.Internal.WorldOverlayNative
local Plaques = M.Plaques
local PlaqueAnimations = M.PlaqueAnimations
local overlay = M.overlay
local target = M.target
local arrival = M.arrival
local derived = M.derived
local transition = M.transition
local _frameCache = M.frameCache
local _settings = M.settingsSnapshot
local CFG = M.Config

local ICON_SPECS = CFG.ICON_SPECS
local DEFAULT_TINT = CFG.DEFAULT_TINT
local BASE_SCALE_DISTANCE = CFG.BASE_SCALE_DISTANCE
local CONTENT_REFRESH_INTERVAL = CFG.CONTENT_REFRESH_INTERVAL
local PINPOINT_TRANSITION_DURATION = CFG.PINPOINT_TRANSITION_DURATION
local PINPOINT_TRANSITION_INTRO_FADE_DURATION = CFG.PINPOINT_TRANSITION_INTRO_FADE_DURATION
local PINPOINT_TRANSITION_INTRO_MOVE_DURATION = CFG.PINPOINT_TRANSITION_INTRO_MOVE_DURATION
local PINPOINT_TRANSITION_OUTRO_FADE_DURATION = CFG.PINPOINT_TRANSITION_OUTRO_FADE_DURATION
local PINPOINT_TRANSITION_OUTRO_MOVE_DURATION = CFG.PINPOINT_TRANSITION_OUTRO_MOVE_DURATION
local PINPOINT_ARROW_CYCLE = CFG.PINPOINT_ARROW_CYCLE
local PINPOINT_ARROW_OFFSETS = CFG.PINPOINT_ARROW_OFFSETS
local PINPOINT_ARROW_FADE_TIME = CFG.PINPOINT_ARROW_FADE_TIME
local PINPOINT_ARROW_SOLID_TIME = CFG.PINPOINT_ARROW_SOLID_TIME
local PINPOINT_ARROW_TRAVEL = CFG.PINPOINT_ARROW_TRAVEL
local PINPOINT_ARROW_EDGE_ALPHA = CFG.PINPOINT_ARROW_EDGE_ALPHA or 0
local WAYPOINT_BEACON_MASK_HIDDEN_SCALE = CFG.WAYPOINT_BEACON_MASK_HIDDEN_SCALE
local WAYPOINT_BEACON_MASK_SHOWN_SCALE = CFG.WAYPOINT_BEACON_MASK_SHOWN_SCALE
local WAYPOINT_BEACON_LAYOUT = CFG.WAYPOINT_BEACON_LAYOUT
local WAYPOINT_BEACON_ALPHA_MULTIPLIERS = CFG.WAYPOINT_BEACON_ALPHA_MULTIPLIERS
local WAYPOINT_BEACON_GLOW_PULSE_DURATION = CFG.WAYPOINT_BEACON_GLOW_PULSE_DURATION
local WAYPOINT_BEACON_GLOW_PULSE_ALPHA_MIN = CFG.WAYPOINT_BEACON_GLOW_PULSE_ALPHA_MIN
local WAYPOINT_BEACON_GLOW_PULSE_ALPHA_MAX = CFG.WAYPOINT_BEACON_GLOW_PULSE_ALPHA_MAX
local WAYPOINT_BEACON_SIDE_FLOW_DURATION = CFG.WAYPOINT_BEACON_SIDE_FLOW_DURATION
local WAYPOINT_ICON_INTRO_DURATION = CFG.WAYPOINT_ICON_INTRO_DURATION
local WAYPOINT_ICON_INTRO_SCALE = CFG.WAYPOINT_ICON_INTRO_SCALE
local WAYPOINT_TRANSITION_INTRO_BEACON_DELAY = CFG.WAYPOINT_TRANSITION_INTRO_BEACON_DELAY
local WAYPOINT_TRANSITION_INTRO_BEACON_DURATION = CFG.WAYPOINT_TRANSITION_INTRO_BEACON_DURATION
local WAYPOINT_TRANSITION_INTRO_FADE_DURATION = CFG.WAYPOINT_TRANSITION_INTRO_FADE_DURATION
local WAYPOINT_TRANSITION_OUTRO_BEACON_DURATION = CFG.WAYPOINT_TRANSITION_OUTRO_BEACON_DURATION
local WAYPOINT_TRANSITION_OUTRO_FADE_DURATION = CFG.WAYPOINT_TRANSITION_OUTRO_FADE_DURATION
local PINPOINT_PANEL_TEXT_PADDING_X = CFG.PINPOINT_PANEL_TEXT_PADDING_X
local PINPOINT_TEXT_INSET_X = CFG.PINPOINT_TEXT_INSET_X
local PINPOINT_CONTEXT_OFFSET_Y = CFG.PINPOINT_CONTEXT_OFFSET_Y
local PINPOINT_FRAME_EXTRA_HEIGHT = CFG.PINPOINT_FRAME_EXTRA_HEIGHT
local PINPOINT_HOST_CONTEXT_GAP_Y = CFG.PINPOINT_HOST_CONTEXT_GAP_Y
local PINPOINT_HOST_CONTEXT_TAPER_START = CFG.PINPOINT_HOST_CONTEXT_TAPER_START
local PINPOINT_HOST_CONTEXT_TAPER_RANGE = CFG.PINPOINT_HOST_CONTEXT_TAPER_RANGE
local PINPOINT_HOST_CONTEXT_TAPER_MAX_REDUCTION = CFG.PINPOINT_HOST_CONTEXT_TAPER_MAX_REDUCTION
local WAYPOINT_BEACON_BOTTOMCAP_CORE_PULSE_DURATION = CFG.WAYPOINT_BEACON_BOTTOMCAP_CORE_PULSE_DURATION or 0.90
local WAYPOINT_BEACON_BOTTOMCAP_CORE_ALPHA_MIN = CFG.WAYPOINT_BEACON_BOTTOMCAP_CORE_ALPHA_MIN or 0.82
local WAYPOINT_BEACON_BOTTOMCAP_CORE_ALPHA_MAX = CFG.WAYPOINT_BEACON_BOTTOMCAP_CORE_ALPHA_MAX or 1.00
local WAYPOINT_BEACON_BOTTOMCAP_CORE_SCALE_MIN = CFG.WAYPOINT_BEACON_BOTTOMCAP_CORE_SCALE_MIN or 0.96
local WAYPOINT_BEACON_BOTTOMCAP_CORE_SCALE_MAX = CFG.WAYPOINT_BEACON_BOTTOMCAP_CORE_SCALE_MAX or 1.05
local WAYPOINT_BEACON_BOTTOMCAP_FLAME_DURATION = CFG.WAYPOINT_BEACON_BOTTOMCAP_FLAME_DURATION or 0.72
local WAYPOINT_BEACON_BOTTOMCAP_FLAME_ALPHA_MIN = CFG.WAYPOINT_BEACON_BOTTOMCAP_FLAME_ALPHA_MIN or 0.10
local WAYPOINT_BEACON_BOTTOMCAP_FLAME_ALPHA_MAX = CFG.WAYPOINT_BEACON_BOTTOMCAP_FLAME_ALPHA_MAX or 0.58
local WAYPOINT_BEACON_BOTTOMCAP_FLAME_SCALE_MIN = CFG.WAYPOINT_BEACON_BOTTOMCAP_FLAME_SCALE_MIN or 0.90
local WAYPOINT_BEACON_BOTTOMCAP_FLAME_SCALE_MAX = CFG.WAYPOINT_BEACON_BOTTOMCAP_FLAME_SCALE_MAX or 1.22
local WAYPOINT_BEACON_BOTTOMCAP_FLAME_DRIFT_X = CFG.WAYPOINT_BEACON_BOTTOMCAP_FLAME_DRIFT_X or 2.5
local WAYPOINT_BEACON_BOTTOMCAP_FLAME_DRIFT_Y = CFG.WAYPOINT_BEACON_BOTTOMCAP_FLAME_DRIFT_Y or 8

local ResolveIconSpec = M.ResolveIconSpec
local GetTargetSubtext = M.GetTargetSubtext
local Clamp01 = M.Clamp01
local Lerp = M.Lerp
local EaseInExpo = M.EaseInExpo
local EaseOutCubic = M.EaseOutCubic
local SetCachedFontStringText = M.SetCachedFontStringText
local UpdateDistanceFontString = M.UpdateDistanceFontString
local UpdateArrivalFontString = M.UpdateArrivalFontString
local GetScaleForDistance = M.GetScaleForDistance
local GetHoverMultiplier = M.GetHoverMultiplier
local ShowFrameSet = M.ShowFrameSet
local ResetModeTransition = M.ResetModeTransition
local GetRootScreenOrigin = M.GetRootScreenOrigin
local SetContextIconSpec = M.SetContextIconSpec
local GetPinpointTextMetrics = M.GetPinpointTextMetrics
local LayoutPinpointText = M.LayoutPinpointText
local IsWaypointPinpointTransition = M.IsWaypointPinpointTransition
local EnsureWaypointFrame = M.EnsureWaypointFrame
local EnsurePinpointFrame = M.EnsurePinpointFrame
local EnsureNavigatorFrame = M.EnsureNavigatorFrame
local ResolveWaypointTextColor = M.ResolveWaypointTextColor
local ResolvePinpointTitleColor = M.ResolvePinpointTitleColor
local ResolvePinpointSubtextColor = M.ResolvePinpointSubtextColor
local ResolveBeaconColors = M.ResolveBeaconColors
local ResolveArrowColor = M.ResolveArrowColor
local ResolveNavArrowColor = M.ResolveNavArrowColor
local ResolvePlaqueColors = M.ResolvePlaqueColors
local ResolveAnimatedColor = M.ResolveAnimatedColor

local PINPOINT_PANEL_HEIGHT_REDUCTION_THRESHOLD = 6
local NAVIGATOR_UP_VECTOR_X = 0
local NAVIGATOR_UP_VECTOR_Y = 1
local NAVIGATOR_MIN_ZOOM = 12
local NAVIGATOR_ROTATION_THRESHOLD = 0.01
local NAVIGATOR_POSITION_THRESHOLD = 1
local NAVIGATOR_BASE_ZOOM = 35
local NAVIGATOR_BASE_MAJOR = 200
local NAVIGATOR_BASE_MINOR = 100
local NAVIGATOR_MAX_AXIS = 500
local NAVIGATOR_FADE_DURATION = 0.175
local PINPOINT_ARROW_COUNT = 3

local DEFAULT_PINPOINT_PANEL_SPEC = {
    minW = 140,
    wrapW = 176,
    maxW = 224,
    textInsetX = PINPOINT_TEXT_INSET_X,
    textPaddingX = PINPOINT_PANEL_TEXT_PADDING_X,
}

local DEFAULT_PINPOINT_PULSE = {
    speed = math.pi,
    amplitude = 0.15,
    base = 0.15,
}

local function GetDefaultPinpointPanelSpec()
    local spec = Plaques and Plaques.GetSpec and Plaques.GetSpec(C.WORLD_OVERLAY_PLAQUE_DEFAULT) or nil
    if type(spec) ~= "table" then
        return DEFAULT_PINPOINT_PANEL_SPEC
    end

    return {
        minW = spec.minW or DEFAULT_PINPOINT_PANEL_SPEC.minW,
        wrapW = spec.wrapW or DEFAULT_PINPOINT_PANEL_SPEC.wrapW,
        maxW = spec.maxW or DEFAULT_PINPOINT_PANEL_SPEC.maxW,
        textInsetX = spec.textInsetX or DEFAULT_PINPOINT_PANEL_SPEC.textInsetX,
        textPaddingX = spec.textPaddingX or DEFAULT_PINPOINT_PANEL_SPEC.textPaddingX,
    }
end

local function GetGlowingGemsGlowDefaults()
    local specs = PlaqueAnimations and PlaqueAnimations.GetSpec and PlaqueAnimations.GetSpec(C.WORLD_OVERLAY_PLAQUE_GLOWING_GEMS) or nil
    if type(specs) ~= "table" then
        return DEFAULT_PINPOINT_PULSE
    end

    for _, spec in ipairs(specs) do
        if spec and spec.type == "corner_gems" and type(spec.glow) == "table" then
            return spec.glow
        end
    end

    return DEFAULT_PINPOINT_PULSE
end

local function GetPinpointPlaqueSpec(frame)
    local defaultSpec = GetDefaultPinpointPanelSpec()
    if not frame then
        return defaultSpec
    end

    local spec = frame.__zwpPlaqueSpec
    if type(spec) ~= "table" and frame.Panel then
        spec = frame.Panel.__zwpPlaqueSpec
    end

    if type(spec) ~= "table" then
        return defaultSpec
    end

    return {
        minW = spec.minW or defaultSpec.minW,
        wrapW = spec.wrapW or defaultSpec.wrapW,
        maxW = spec.maxW or defaultSpec.maxW,
        textInsetX = spec.textInsetX or defaultSpec.textInsetX,
        textPaddingX = spec.textPaddingX or defaultSpec.textPaddingX,
    }
end

-- ============================================================
-- Panel measurement
-- ============================================================

local function ClampPanelWidth(width, frame)
    local spec = GetPinpointPlaqueSpec(frame)
    local defaultSpec = GetDefaultPinpointPanelSpec()
    local minW = spec.minW or defaultSpec.minW
    local maxW = spec.maxW or defaultSpec.maxW
    return math.max(minW, math.min(maxW, width or minW))
end

local function MeasureWrappedFontStringWidth(fontString)
    if not fontString or not fontString:IsShown() then
        return 0, false
    end

    -- Touch height first so the client has resolved wrapping before width/truncation checks.
    fontString:GetStringHeight()

    local wrappedWidth = fontString:GetWrappedWidth() or 0
    if wrappedWidth <= 0 then
        wrappedWidth = fontString:GetStringWidth() or 0
    end

    local truncated = fontString:IsTruncated() or false
    return wrappedWidth, truncated
end

local function MeasurePinpointPanelWidth(frame, panelWidth)
    local spec = GetPinpointPlaqueSpec(frame)
    local defaultSpec = GetDefaultPinpointPanelSpec()
    local actualPanelWidth = ClampPanelWidth(panelWidth, frame)
    local _, _, _, totalHeight, titleTruncated, subtextTruncated = GetPinpointTextMetrics(frame, actualPanelWidth)

    local titleWidth, _ = MeasureWrappedFontStringWidth(frame.Title)
    local subtextWidth, _ = MeasureWrappedFontStringWidth(frame.Subtext)
    local textPaddingX = spec.textPaddingX or defaultSpec.textPaddingX
    local measuredWidth = math.max(titleWidth, subtextWidth) + textPaddingX
    return ClampPanelWidth(measuredWidth, frame), (titleTruncated or subtextTruncated), totalHeight
end

local function MeasurePinpointSingleLineWidth(measureFontString, text)
    if not measureFontString or type(text) ~= "string" or text == "" then
        return 0
    end

    measureFontString:SetText(text)
    return measureFontString:GetStringWidth() or 0
end

local function ResolvePinpointTextRescueWidth(frame, fontString, measureFontString, text, currentWidth, currentHeight)
    if not frame or not fontString or not measureFontString or not fontString:IsShown() then
        return nil
    end

    local spec = GetPinpointPlaqueSpec(frame)
    local defaultSpec = GetDefaultPinpointPanelSpec()
    local naturalWidth = MeasurePinpointSingleLineWidth(measureFontString, text)
    if naturalWidth <= 0 then
        return nil
    end

    local textPaddingX = spec.textPaddingX or defaultSpec.textPaddingX
    local textInsetX = spec.textInsetX or defaultSpec.textInsetX
    local requiredWidth = ClampPanelWidth(math.ceil(naturalWidth +
        math.max(textPaddingX, textInsetX * 2)), frame)
    if requiredWidth <= currentWidth then
        return nil
    end

    local _, truncated, rescueHeight = MeasurePinpointPanelWidth(frame, requiredWidth)
    if truncated then
        return nil
    end

    if rescueHeight <= (currentHeight - PINPOINT_PANEL_HEIGHT_REDUCTION_THRESHOLD) then
        return requiredWidth
    end

    return nil
end

local function ResolvePinpointPanelWidth(frame)
    local spec = GetPinpointPlaqueSpec(frame)
    local defaultSpec = GetDefaultPinpointPanelSpec()
    local baseProbeWidth = ClampPanelWidth(spec.wrapW or defaultSpec.wrapW, frame)
    local bestProbeWidth = baseProbeWidth
    local bestMeasuredWidth, bestTruncated, bestTotalHeight = MeasurePinpointPanelWidth(frame, baseProbeWidth)

    local probeWidth = baseProbeWidth
    while probeWidth < (spec.maxW or defaultSpec.maxW) do
        probeWidth = math.min(spec.maxW or defaultSpec.maxW, probeWidth + 8)
        local measuredWidth, truncated, totalHeight = MeasurePinpointPanelWidth(frame, probeWidth)
        if not truncated then
            local heightImproved = totalHeight <= (bestTotalHeight - PINPOINT_PANEL_HEIGHT_REDUCTION_THRESHOLD)
            if bestTruncated or heightImproved then
                bestProbeWidth = probeWidth
                bestMeasuredWidth = measuredWidth
                bestTruncated = false
                bestTotalHeight = totalHeight
            end
        end
    end

    local resolvedWidth = ClampPanelWidth(math.max(baseProbeWidth, bestMeasuredWidth), frame)
    if bestProbeWidth > baseProbeWidth then
        resolvedWidth = ClampPanelWidth(math.max(resolvedWidth, bestProbeWidth), frame)
    elseif bestTruncated then
        resolvedWidth = ClampPanelWidth(math.max(resolvedWidth, bestMeasuredWidth), frame)
    end

    local _, _, resolvedHeight = MeasurePinpointPanelWidth(frame, resolvedWidth)
    local currentWidth = resolvedWidth
    local titleRescueWidth = ResolvePinpointTextRescueWidth(
        frame,
        frame.Title,
        frame.TitleMeasure,
        frame.__zwpTitleText or frame.Title:GetText(),
        currentWidth,
        resolvedHeight
    )
    if titleRescueWidth then
        currentWidth = math.max(currentWidth, titleRescueWidth)
        local _, _, nextHeight = MeasurePinpointPanelWidth(frame, currentWidth)
        resolvedHeight = nextHeight
    end

    local subtextRescueWidth = ResolvePinpointTextRescueWidth(
        frame,
        frame.Subtext,
        frame.SubtextMeasure,
        frame.__zwpSubtextText or frame.Subtext:GetText(),
        currentWidth,
        resolvedHeight
    )
    if subtextRescueWidth then
        currentWidth = math.max(currentWidth, subtextRescueWidth)
    end

    return currentWidth
end

-- ============================================================
-- Content refresh
-- ============================================================

local function IsPinpointContentChanged(cache, shownTitle, shownSubtext, showDestination, showExtended)
    if cache.contentTitle ~= shownTitle
        or cache.contentSubtext ~= shownSubtext
        or cache.contentShowDest ~= showDestination
        or cache.contentShowExt ~= showExtended
    then
        cache.contentTitle = shownTitle
        cache.contentSubtext = shownSubtext
        cache.contentShowDest = showDestination
        cache.contentShowExt = showExtended
        return true
    end
    return false
end

local function RefreshNativeOverlayContent(force)
    local now = GetTime()
    if not force and not overlay.contentDirty and (now - (overlay.lastContentRefresh or 0)) < CONTENT_REFRESH_INTERVAL then
        return
    end

    overlay.cachedIconSpec = ResolveIconSpec(target.kind, target.source, target.title)
    overlay.cachedPinpointSubtext = GetTargetSubtext()
    overlay.contentDirty = false
    overlay.lastContentRefresh = now
end

-- ============================================================
-- Pinpoint helpers
-- ============================================================

local function ResolvePinpointArrowPhase(offset, index)
    if type(offset) ~= "number" then
        return ((index or 1) - 1) / PINPOINT_ARROW_COUNT
    end

    if offset > 1 then
        return (offset % PINPOINT_ARROW_CYCLE) / PINPOINT_ARROW_CYCLE
    end

    return offset % 1
end

local function EasePinpointArrowAlpha(t)
    t = Clamp01(t)
    return t * t * (3 - (2 * t))
end

local function ResolvePinpointArrowAlpha(phase)
    if PINPOINT_ARROW_CYCLE <= 0 then
        return 1
    end

    local fadeInEnd = Clamp01(PINPOINT_ARROW_FADE_TIME / PINPOINT_ARROW_CYCLE)
    local edgeAlpha = Clamp01(PINPOINT_ARROW_EDGE_ALPHA or 0)

    if PINPOINT_ARROW_SOLID_TIME and PINPOINT_ARROW_SOLID_TIME > 0 then
        local minFadeOutDuration = Clamp01(PINPOINT_ARROW_SOLID_TIME / PINPOINT_ARROW_CYCLE)
        fadeInEnd = math.min(fadeInEnd, math.max(0, 1 - minFadeOutDuration))
    end

    if phase < fadeInEnd and fadeInEnd > 0 then
        return Lerp(edgeAlpha, 1, EasePinpointArrowAlpha(phase / fadeInEnd))
    end

    if fadeInEnd >= 1 then
        return 1
    end

    local fadeOutProgress = Clamp01((phase - fadeInEnd) / (1 - fadeInEnd))
    return Lerp(1, 0, EasePinpointArrowAlpha(fadeOutProgress))
end

local function UpdatePinpointArrowVisual(arrow, slot, offset, tint, now, index)
    if not arrow or not slot then
        return
    end

    local group = slot:GetParent()
    if not group then
        return
    end

    local groupHeight = math.max(0, group:GetHeight() or 0)
    local arrowHeight = math.max(0, arrow:GetHeight() or 0)
    local halfTravel = math.max(0, PINPOINT_ARROW_TRAVEL or 0) * 0.5
    local visibleTopCenterY = -(arrowHeight * 0.5)
    local visibleBottomCenterY = -(groupHeight - (arrowHeight * 0.5))
    local startCenterY = visibleTopCenterY + halfTravel
    local endCenterY = visibleBottomCenterY - halfTravel
    local basePhase = 0
    if PINPOINT_ARROW_CYCLE > 0 then
        basePhase = (now % PINPOINT_ARROW_CYCLE) / PINPOINT_ARROW_CYCLE
    end
    local phase = (basePhase + ResolvePinpointArrowPhase(offset, index)) % 1
    local centerY = Lerp(startCenterY, endCenterY, phase)
    local alpha = Clamp01(ResolvePinpointArrowAlpha(phase))

    arrow:ClearAllPoints()
    arrow:SetPoint("CENTER", group, "TOP", 0, centerY)
    arrow:SetVertexColor(tint.r or 1, tint.g or 1, tint.b or 1, alpha)
end

local function UpdateFrameAlpha(frame, cache, alpha)
    if cache.alpha ~= alpha then
        frame:SetAlpha(alpha)
        cache.alpha = alpha
    end
end

local function SetBeaconLayerVertexColor(layers, tint)
    if not layers or not tint then
        return
    end

    local r = tint.r or 1
    local g = tint.g or 1
    local b = tint.b or 1
    local a = tint.a or 1
    for i = 1, #layers do
        local layer = layers[i]
        if layer then
            layer:SetVertexColor(r, g, b, a)
        end
    end
end

local BEACON_ALPHA_EPSILON = 0.0025
local BEACON_POINT_EPSILON = 0.01
local BEACON_SIZE_EPSILON = 0.01

local function SetBeaconLayerAlpha(texture, alpha)
    if not texture then
        return
    end

    texture:SetAlpha(alpha)
    texture.__zwpAlpha = alpha
end

local function SetBeaconLayerShown(texture, shown)
    if texture and texture:IsShown() ~= shown then
        texture:SetShown(shown)
    end
end

local function SetBeaconLayerBottom(texture, parent, offsetX, offsetY)
    if not texture then
        return
    end

    local prevX = texture.__zwpBottomX
    local prevY = texture.__zwpBottomY
    local prevParent = texture.__zwpBottomParent

    if prevParent == parent
        and prevX and prevY
        and math.abs(prevX - offsetX) <= BEACON_POINT_EPSILON
        and math.abs(prevY - offsetY) <= BEACON_POINT_EPSILON
    then
        return
    end

    texture:ClearAllPoints()
    texture:SetPoint("BOTTOM", parent, "BOTTOM", offsetX, offsetY)
    texture.__zwpBottomParent = parent
    texture.__zwpBottomX = offsetX
    texture.__zwpBottomY = offsetY
end

local function SetBeaconLayerCenter(texture, parent, offsetX, offsetY)
    if not texture then
        return
    end

    local prevX = texture.__zwpCenterX
    local prevY = texture.__zwpCenterY
    local prevParent = texture.__zwpCenterParent

    if prevParent == parent
        and prevX and prevY
        and math.abs(prevX - offsetX) <= BEACON_POINT_EPSILON
        and math.abs(prevY - offsetY) <= BEACON_POINT_EPSILON
    then
        return
    end

    texture:ClearAllPoints()
    texture:SetPoint("CENTER", parent, "CENTER", offsetX, offsetY)
    texture.__zwpCenterParent = parent
    texture.__zwpCenterX = offsetX
    texture.__zwpCenterY = offsetY
end

local function SetBeaconLayerSize(texture, width, height)
    if not texture then
        return
    end

    local prevW = texture.__zwpWidth
    local prevH = texture.__zwpHeight
    if prevW and prevH
        and math.abs(prevW - width) <= BEACON_SIZE_EPSILON
        and math.abs(prevH - height) <= BEACON_SIZE_EPSILON
    then
        return
    end

    texture:SetSize(width, height)
    texture.__zwpWidth = width
    texture.__zwpHeight = height
end

local function SmoothStep(t)
    t = Clamp01(t)
    return t * t * (3 - (2 * t))
end

local function BeaconFlowAlpha(progress, baseAlpha)
    local x = math.sin(progress * math.pi)
    if x < 0 then
        x = 0
    end
    return baseAlpha * SmoothStep(x)
end

local function UpdateBeaconFlowTriple(textureA, textureB, textureC, parent, layout, progress, travelDirection, baseAlpha)
    local height = layout.height or 0
    local baseOffsetY = layout.offsetY or 0
    local wrapPad = layout.wrapPad or 0
    local wrapDistance = height + wrapPad

    local pA = progress % 1
    local pB = (progress + 0.3333333333) % 1
    local pC = (progress + 0.6666666667) % 1

    SetBeaconLayerBottom(textureA, parent, layout.offsetX, baseOffsetY + (travelDirection * (pA * wrapDistance)))
    SetBeaconLayerBottom(textureB, parent, layout.offsetX, baseOffsetY + (travelDirection * (pB * wrapDistance)))
    SetBeaconLayerBottom(textureC, parent, layout.offsetX, baseOffsetY + (travelDirection * (pC * wrapDistance)))

    if baseAlpha then
        SetBeaconLayerAlpha(textureA, BeaconFlowAlpha(pA, baseAlpha))
        SetBeaconLayerAlpha(textureB, BeaconFlowAlpha(pB, baseAlpha))
        SetBeaconLayerAlpha(textureC, BeaconFlowAlpha(pC, baseAlpha))
    end
end

local function GetPulseAlpha(now, duration, alphaMin, alphaMax)
    local cycle = (now % duration) / duration
    local eased = (math.sin((cycle * math.pi * 2) - (math.pi / 2)) + 1) * 0.5
    return Lerp(alphaMin, alphaMax, eased)
end

local function UpdateBottomCapFlame(texture, parent, layout, progress, baseAlpha, alphaMin, alphaMax, scaleMin, scaleMax,
                                    driftX, driftY)
    if not texture then
        return
    end

    local rise = math.sin(progress * math.pi)
    rise = math.max(0, rise)
    local flare = SmoothStep(rise)
    local sway = math.sin(progress * math.pi * 2)

    local alphaScale = Lerp(alphaMin, alphaMax, flare)
    local sizeScale = Lerp(scaleMin, scaleMax, flare)

    SetBeaconLayerSize(texture, layout.width * sizeScale, layout.height * sizeScale)
    SetBeaconLayerCenter(
        texture,
        parent,
        layout.offsetX + (sway * driftX),
        layout.offsetY + (flare * driftY)
    )
    SetBeaconLayerAlpha(texture, baseAlpha * alphaScale)
end

local function UpdateBottomCapCore(texture, parent, layout, now, beaconAlpha)
    if not texture then
        return
    end

    local pulse = GetPulseAlpha(
        now,
        WAYPOINT_BEACON_BOTTOMCAP_CORE_PULSE_DURATION,
        WAYPOINT_BEACON_BOTTOMCAP_CORE_ALPHA_MIN,
        WAYPOINT_BEACON_BOTTOMCAP_CORE_ALPHA_MAX
    )

    local normalized = 0
    if WAYPOINT_BEACON_BOTTOMCAP_CORE_ALPHA_MAX > WAYPOINT_BEACON_BOTTOMCAP_CORE_ALPHA_MIN then
        normalized = (pulse - WAYPOINT_BEACON_BOTTOMCAP_CORE_ALPHA_MIN) /
            (WAYPOINT_BEACON_BOTTOMCAP_CORE_ALPHA_MAX - WAYPOINT_BEACON_BOTTOMCAP_CORE_ALPHA_MIN)
    end
    normalized = Clamp01(normalized)

    local sizeScale = Lerp(
        WAYPOINT_BEACON_BOTTOMCAP_CORE_SCALE_MIN,
        WAYPOINT_BEACON_BOTTOMCAP_CORE_SCALE_MAX,
        normalized
    )

    SetBeaconLayerSize(texture, layout.width * sizeScale, layout.height * sizeScale)
    SetBeaconLayerCenter(texture, parent, layout.offsetX, layout.offsetY)
    SetBeaconLayerAlpha(texture, beaconAlpha * WAYPOINT_BEACON_ALPHA_MULTIPLIERS.bottomCap * pulse)
end

local function RestoreFontStringDefaultColor(fontString)
    if not fontString then
        return
    end

    local color = fontString.__zwpDefaultTextColor
    if not color then
        return
    end

    fontString:SetTextColor(color.r or 1, color.g or 1, color.b or 1, color.a or 1)
end

local function ApplyResolvedFontStringColor(fontString, color)
    if not fontString then
        return
    end

    if not color then
        RestoreFontStringDefaultColor(fontString)
        return
    end

    fontString:SetTextColor(color.r or 1, color.g or 1, color.b or 1, color.a or 1)
end

local function GetPinpointHostHalfHeight()
    local navFrame = derived.navFrame
    if navFrame then
        return (navFrame:GetHeight() or 0) * 0.5
    end
    return 0
end

local function GetPinpointHostContextGapY()
    local autoAdjust = _settings.worldOverlayPinpointAutoVerticalAdjust ~= false
    local gap = autoAdjust
        and PINPOINT_HOST_CONTEXT_GAP_Y
        or (_settings.worldOverlayPinpointManualVerticalGap or PINPOINT_HOST_CONTEXT_GAP_Y)

    if not autoAdjust then
        return gap
    end

    local hostTopY
    local anchorFrame = derived.anchorFrame
    if anchorFrame and anchorFrame:IsShown() then
        hostTopY = anchorFrame:GetTop()
    elseif type(derived.anchorY) == "number" then
        hostTopY = derived.anchorY + GetPinpointHostHalfHeight()
    end

    local screenBottom = UIParent:GetBottom()
    local screenTop = UIParent:GetTop()
    if type(hostTopY) ~= "number"
        or type(screenBottom) ~= "number"
        or type(screenTop) ~= "number"
        or screenTop <= screenBottom
        or PINPOINT_HOST_CONTEXT_TAPER_RANGE <= 0
    then
        return gap
    end

    local height = screenTop - screenBottom
    local hostTopPct = Clamp01((hostTopY - screenBottom) / height)
    local taper = Clamp01((hostTopPct - PINPOINT_HOST_CONTEXT_TAPER_START) / PINPOINT_HOST_CONTEXT_TAPER_RANGE)
    if taper > 0 then
        gap = math.max(0, gap - (PINPOINT_HOST_CONTEXT_TAPER_MAX_REDUCTION * taper))
    end

    return gap
end

local function GetDiamondAlignOffset()
    -- Returns the signed Y offset from the waypoint diamond's resting position
    -- to the pinpoint diamond's resting position.  Used by the intro/outro
    -- transition so the pinpoint literally slides from the waypoint diamond's
    -- exact screen location rather than a hardcoded pixel guess.
    return -(GetPinpointHostHalfHeight() + GetPinpointHostContextGapY())
end

local function GetPinpointAnchorOffsetY(offsetY)
    -- Anchor the context-icon container relative to the host frame's top edge,
    -- not the frame bottom, so plaque height and the context-diamond toggle do
    -- not change the target gap.
    -- worldOverlayWaypointOffsetY is also applied here so the context diamond
    -- stays vertically aligned with the waypoint context diamond across mode transitions.
    local contextCenterFromFrameBottom = PINPOINT_FRAME_EXTRA_HEIGHT + PINPOINT_CONTEXT_OFFSET_Y
    local sharedOffsetY = _settings.worldOverlayWaypointOffsetY or 0
    return (GetPinpointHostContextGapY() - contextCenterFromFrameBottom) + (offsetY or 0) + sharedOffsetY
end

local function ApplyPinpointAnchor(offsetY)
    local frame = overlay.pinpoint
    if not frame or (not derived.anchorFrame and (not derived.anchorX or not derived.anchorY)) then
        return
    end

    local cache = _frameCache.pinpoint
    local anchorOffsetY = GetPinpointAnchorOffsetY(offsetY)
    local useAnchorFrame = derived.anchorFrame and derived.anchorFrame:IsShown()
    if useAnchorFrame then
        if cache.anchorRef ~= derived.anchorFrame or cache.anchorX ~= 0 or cache.anchorY ~= anchorOffsetY then
            frame:ClearAllPoints()
            frame:SetPoint("BOTTOM", derived.anchorFrame, "TOP", 0, anchorOffsetY)
            cache.anchorRef = derived.anchorFrame
            cache.anchorX = 0
            cache.anchorY = anchorOffsetY
        end
    else
        local left, bottom = GetRootScreenOrigin()
        local newX = derived.anchorX - left
        local newY = derived.anchorY - bottom + GetPinpointHostHalfHeight() + anchorOffsetY
        if cache.anchorRef ~= nil or cache.anchorX ~= newX or cache.anchorY ~= newY then
            frame:ClearAllPoints()
            frame:SetPoint("BOTTOM", overlay.root, "BOTTOMLEFT", newX, newY)
            cache.anchorRef = nil
            cache.anchorX = newX
            cache.anchorY = newY
        end
    end
end

-- ============================================================
-- Waypoint and pinpoint frames
-- ============================================================

local function UpdateWaypointVisual(alpha, iconScale, beaconMaskScale)
    local frame = overlay.waypoint
    if not frame then
        return
    end

    local cache = _frameCache.waypoint
    UpdateFrameAlpha(frame, cache, alpha)

    local contextScale = iconScale or 1
    if frame.ContextIcon and cache.contextScale ~= contextScale then
        frame.ContextIcon:SetScale(contextScale)
        cache.contextScale = contextScale
    end

    local beaconStyle = _settings.worldOverlayBeaconStyle or "beacon"
    local showBeacon = beaconStyle ~= "off" and frame.Beacon ~= nil
    local beaconBaseOnly = beaconStyle == "base"
    if frame.Beacon and frame.Beacon:IsShown() ~= showBeacon then
        frame.Beacon:SetShown(showBeacon)
    end

    if not showBeacon then
        cache.beaconAlpha = 0
        cache.beaconMaskScale = nil
        cache.beaconStyle = nil
        return
    end

    -- Show or hide column parts when the style changes between "beacon" and "base".
    if cache.beaconStyle ~= beaconStyle then
        local showColumn = not beaconBaseOnly
        SetBeaconLayerShown(frame.Beacon.Core, showColumn)
        SetBeaconLayerShown(frame.Beacon.Glow, showColumn)
        SetBeaconLayerShown(frame.Beacon.LeftVeilA, showColumn)
        SetBeaconLayerShown(frame.Beacon.LeftVeilB, showColumn)
        SetBeaconLayerShown(frame.Beacon.LeftVeilC, showColumn)
        SetBeaconLayerShown(frame.Beacon.RightVeilA, showColumn)
        SetBeaconLayerShown(frame.Beacon.RightVeilB, showColumn)
        SetBeaconLayerShown(frame.Beacon.RightVeilC, showColumn)
        cache.beaconStyle = beaconStyle
    end

    local beaconAlpha = _settings.worldOverlayBeaconOpacity
    if cache.beaconAlpha ~= beaconAlpha then
        if not beaconBaseOnly then
            SetBeaconLayerAlpha(frame.Beacon.Core, beaconAlpha * WAYPOINT_BEACON_ALPHA_MULTIPLIERS.core)
        end
        -- Bottom-cap alpha is animated per-tick below so the base can flare like a flame.
        cache.beaconAlpha = beaconAlpha
    end

    if frame.Beacon.MaskHost then
        local maskScale = beaconMaskScale or WAYPOINT_BEACON_MASK_SHOWN_SCALE
        if cache.beaconMaskScale ~= maskScale then
            frame.Beacon.MaskHost:SetScale(maskScale)
            cache.beaconMaskScale = maskScale
        end
    end

    local now = GetTime()
    if not beaconBaseOnly then
        SetBeaconLayerAlpha(
            frame.Beacon.Glow,
            beaconAlpha * GetPulseAlpha(
                now,
                WAYPOINT_BEACON_GLOW_PULSE_DURATION,
                WAYPOINT_BEACON_GLOW_PULSE_ALPHA_MIN,
                WAYPOINT_BEACON_GLOW_PULSE_ALPHA_MAX
            )
        )
    end

    local bottomCapLayout = WAYPOINT_BEACON_LAYOUT.bottomCap
    local flameProgressA = (now % WAYPOINT_BEACON_BOTTOMCAP_FLAME_DURATION) / WAYPOINT_BEACON_BOTTOMCAP_FLAME_DURATION
    local flameProgressB = ((now / WAYPOINT_BEACON_BOTTOMCAP_FLAME_DURATION) + 0.38) % 1
    local bottomCapBaseAlpha = beaconAlpha * WAYPOINT_BEACON_ALPHA_MULTIPLIERS.bottomCap

    UpdateBottomCapCore(frame.Beacon.BottomCap, frame, bottomCapLayout, now, beaconAlpha)

    UpdateBottomCapFlame(
        frame.Beacon.BottomCapFlameA,
        frame,
        bottomCapLayout,
        flameProgressA,
        bottomCapBaseAlpha,
        WAYPOINT_BEACON_BOTTOMCAP_FLAME_ALPHA_MIN,
        WAYPOINT_BEACON_BOTTOMCAP_FLAME_ALPHA_MAX,
        WAYPOINT_BEACON_BOTTOMCAP_FLAME_SCALE_MIN,
        WAYPOINT_BEACON_BOTTOMCAP_FLAME_SCALE_MAX,
        WAYPOINT_BEACON_BOTTOMCAP_FLAME_DRIFT_X,
        WAYPOINT_BEACON_BOTTOMCAP_FLAME_DRIFT_Y
    )

    UpdateBottomCapFlame(
        frame.Beacon.BottomCapFlameB,
        frame,
        bottomCapLayout,
        flameProgressB,
        bottomCapBaseAlpha * 0.82,
        WAYPOINT_BEACON_BOTTOMCAP_FLAME_ALPHA_MIN,
        WAYPOINT_BEACON_BOTTOMCAP_FLAME_ALPHA_MAX * 0.9,
        WAYPOINT_BEACON_BOTTOMCAP_FLAME_SCALE_MIN,
        WAYPOINT_BEACON_BOTTOMCAP_FLAME_SCALE_MAX * 0.96,
        WAYPOINT_BEACON_BOTTOMCAP_FLAME_DRIFT_X * -0.85,
        WAYPOINT_BEACON_BOTTOMCAP_FLAME_DRIFT_Y * 0.9
    )

    if not beaconBaseOnly then
        local veilBaseAlpha = beaconAlpha * WAYPOINT_BEACON_ALPHA_MULTIPLIERS.sideVeil
        local sideFlowProgress = (now % WAYPOINT_BEACON_SIDE_FLOW_DURATION) / WAYPOINT_BEACON_SIDE_FLOW_DURATION

        UpdateBeaconFlowTriple(
            frame.Beacon.LeftVeilA,
            frame.Beacon.LeftVeilB,
            frame.Beacon.LeftVeilC,
            frame.Beacon,
            WAYPOINT_BEACON_LAYOUT.leftVeil,
            sideFlowProgress,
            1,
            veilBaseAlpha * 0.85
        )

        UpdateBeaconFlowTriple(
            frame.Beacon.RightVeilA,
            frame.Beacon.RightVeilB,
            frame.Beacon.RightVeilC,
            frame.Beacon,
            WAYPOINT_BEACON_LAYOUT.rightVeil,
            (sideFlowProgress + 0.5) % 1,
            1,
            veilBaseAlpha * 0.85
        )
    end

end

local function FindPinpointAnimationSpec(frame, animType)
    if not frame or not PlaqueAnimations or not PlaqueAnimations.GetSpec then
        return nil
    end

    local plaqueType = frame.__zwpPlaqueType or C.WORLD_OVERLAY_PLAQUE_DEFAULT
    local specs = PlaqueAnimations.GetSpec(plaqueType)
    if type(specs) ~= "table" then
        return nil
    end

    for _, spec in ipairs(specs) do
        if spec and spec.type == animType then
            return spec
        end
    end

    return nil
end

local function ResolvePinpointPulse(now, pulseSpec, fallbackSpeed, fallbackAmplitude, fallbackBase)
    local speed = pulseSpec and pulseSpec.speed or fallbackSpeed
    local amplitude = pulseSpec and pulseSpec.amplitude or fallbackAmplitude
    local base = pulseSpec and pulseSpec.base or fallbackBase
    return math.sin(now * speed) * amplitude + base
end

local function UpdatePinpointVisual(alpha, offsetY, arrowTint, animatedTint)
    local frame = overlay.pinpoint
    if not frame or (not derived.anchorFrame and (not derived.anchorX or not derived.anchorY)) then
        return
    end

    ApplyPinpointAnchor(offsetY)
    UpdateFrameAlpha(frame, _frameCache.pinpoint, alpha)

    local now = GetTime()
    arrowTint = arrowTint or DEFAULT_TINT
    animatedTint = animatedTint or arrowTint

    if frame.ArrowGroup and frame.ArrowGroup:IsShown() then
        UpdatePinpointArrowVisual(frame.Arrow1, frame.ArrowSlot1, PINPOINT_ARROW_OFFSETS[1], arrowTint, now, 1)
        UpdatePinpointArrowVisual(frame.Arrow2, frame.ArrowSlot2, PINPOINT_ARROW_OFFSETS[2], arrowTint, now, 2)
        UpdatePinpointArrowVisual(frame.Arrow3, frame.ArrowSlot3, PINPOINT_ARROW_OFFSETS[3], arrowTint, now, 3)
    end

    local r, g, b = animatedTint.r or 1, animatedTint.g or 1, animatedTint.b or 1
    local animatedAlpha = animatedTint.a or 1
    local plaqueEffectsAnimated = _settings.worldOverlayPinpointAnimatePlaqueEffects ~= false

    local gemAnimSpec = FindPinpointAnimationSpec(frame, "corner_gems")
    local glowSpec = gemAnimSpec and gemAnimSpec.glow or nil
    local defaultGlow = GetGlowingGemsGlowDefaults()
    local glowPulseAlpha = 0
    if plaqueEffectsAnimated then
        glowPulseAlpha = ResolvePinpointPulse(
            now,
            glowSpec,
            defaultGlow.speed,
            defaultGlow.amplitude,
            defaultGlow.base
        )
    end

    if frame.GlowTL then frame.GlowTL:SetVertexColor(r, g, b, glowPulseAlpha) end
    if frame.GlowTR then frame.GlowTR:SetVertexColor(r, g, b, glowPulseAlpha) end
    if frame.GlowBL then frame.GlowBL:SetVertexColor(r, g, b, glowPulseAlpha) end
    if frame.GlowBR then frame.GlowBR:SetVertexColor(r, g, b, glowPulseAlpha) end

    if frame.Overlay then
        local overlayAnimSpec = FindPinpointAnimationSpec(frame, "full_overlay")
        local overlayPulseSpec = overlayAnimSpec and overlayAnimSpec.pulse or nil
        local overlayPulseAlpha
        if plaqueEffectsAnimated then
            overlayPulseAlpha = ResolvePinpointPulse(
                now,
                overlayPulseSpec,
                defaultGlow.speed,
                defaultGlow.amplitude,
                defaultGlow.base
            )
        else
            overlayPulseAlpha = (overlayPulseSpec and overlayPulseSpec.base) or animatedAlpha
        end


        frame.Overlay:SetVertexColor(r, g, b, overlayPulseAlpha)
    end
end

local function UpdateWaypointFrame(iconSpec, title)
    local frame = overlay.waypoint
    if not frame then
        EnsureWaypointFrame()
        frame = overlay.waypoint
    end
    if not frame or (not derived.anchorFrame and (not derived.anchorX or not derived.anchorY)) then
        return
    end

    local cache = _frameCache.waypoint
    local baseScale = _settings.worldOverlayWaypointSize
    local minScale = _settings.worldOverlayWaypointSizeMin
    local maxScale = _settings.worldOverlayWaypointSizeMax
    local newScale = GetScaleForDistance(derived.distance or BASE_SCALE_DISTANCE, minScale, maxScale) * baseScale
    if cache.scale ~= newScale then
        frame:SetScale(newScale)
        cache.scale = newScale
    end
    local offsetY = _settings.worldOverlayWaypointOffsetY or 0
    local useAnchorFrame = derived.anchorFrame and derived.anchorFrame:IsShown()
    if useAnchorFrame then
        if cache.anchorRef ~= derived.anchorFrame or cache.anchorOffsetY ~= offsetY then
            frame:ClearAllPoints()
            frame:SetPoint("CENTER", derived.anchorFrame, "CENTER", 0, offsetY)
            cache.anchorRef = derived.anchorFrame
            cache.anchorX = nil
            cache.anchorY = nil
            cache.anchorOffsetY = offsetY
        end
    else
        local left, bottom = GetRootScreenOrigin()
        local newX = derived.anchorX - left
        local newY = derived.anchorY - bottom + offsetY
        if cache.anchorRef ~= nil or cache.anchorX ~= newX or cache.anchorY ~= newY then
            frame:ClearAllPoints()
            frame:SetPoint("CENTER", overlay.root, "BOTTOMLEFT", newX, newY)
            cache.anchorRef = nil
            cache.anchorX = newX
            cache.anchorY = newY
            cache.anchorOffsetY = offsetY
        end
    end

    local textTint = ResolveWaypointTextColor and ResolveWaypointTextColor(iconSpec) or iconSpec.tint or DEFAULT_TINT
    local beaconTint = iconSpec.tint or DEFAULT_TINT
    if ResolveBeaconColors then
        beaconTint = ResolveBeaconColors(iconSpec)
    end
    SetContextIconSpec(frame.ContextIcon, iconSpec)
    if frame.Beacon then
        SetBeaconLayerVertexColor(frame.Beacon.BeaconTintLayers, beaconTint)
    end

    local footer = frame.Footer
    local infoMode = _settings.worldOverlayFooterText
    footer:SetShown(infoMode ~= C.WORLD_OVERLAY_INFO_NONE)
    footer:SetScale(_settings.worldOverlayInfoTextSize)
    footer:SetAlpha(_settings.worldOverlayInfoTextOpacity)
    local subtextOpacity = _settings.worldOverlaySubtextOpacity
    footer.InfoText:SetTextColor(textTint.r or 1, textTint.g or 1, textTint.b or 1, textTint.a or 1)
    footer.DistanceText:SetTextColor(textTint.r or 1, textTint.g or 1, textTint.b or 1, subtextOpacity)
    footer.ArrivalTimeText:SetTextColor(textTint.r or 1, textTint.g or 1, textTint.b or 1, subtextOpacity)

    if footer:IsShown() then
        local titleText = nil
        local showDistance = false
        local showArrival = false
        if infoMode == C.WORLD_OVERLAY_INFO_ALL then
            titleText = title
            showDistance = UpdateDistanceFontString(footer, footer.DistanceText, derived.distance)
            showArrival = UpdateArrivalFontString(footer, footer.ArrivalTimeText, arrival.seconds)
        elseif infoMode == C.WORLD_OVERLAY_INFO_DISTANCE then
            showDistance = UpdateDistanceFontString(footer, footer.DistanceText, derived.distance)
            UpdateArrivalFontString(footer, footer.ArrivalTimeText, nil)
        elseif infoMode == C.WORLD_OVERLAY_INFO_ARRIVAL then
            UpdateDistanceFontString(footer, footer.DistanceText, nil)
            showArrival = UpdateArrivalFontString(footer, footer.ArrivalTimeText, arrival.seconds)
        elseif infoMode == C.WORLD_OVERLAY_INFO_DESTINATION then
            titleText = title
            UpdateDistanceFontString(footer, footer.DistanceText, nil)
            UpdateArrivalFontString(footer, footer.ArrivalTimeText, nil)
        else
            UpdateDistanceFontString(footer, footer.DistanceText, nil)
            UpdateArrivalFontString(footer, footer.ArrivalTimeText, nil)
        end
        SetCachedFontStringText(footer.InfoText, titleText or "")
        footer.InfoText:SetShown(type(titleText) == "string" and titleText ~= "")
        footer.DistanceText:SetShown(showDistance)
        footer.ArrivalTimeText:SetShown(showArrival)
    end
end

local function UpdatePinpointFrame(iconSpec, title, subtext)
    local frame = overlay.pinpoint
    if not frame then
        EnsurePinpointFrame()
        frame = overlay.pinpoint
    end
    if not frame or (not derived.anchorFrame and (not derived.anchorX or not derived.anchorY)) then
        return
    end

    local cache = _frameCache.pinpoint
    local newScale = _settings.worldOverlayPinpointSize
    if cache.scale ~= newScale then
        frame:SetScale(newScale)
        cache.scale = newScale
    end

    local showPlaque = _settings.worldOverlayPinpointMode ~= "no_plaque"
    if cache.showPlaque ~= showPlaque then
        frame.Panel:SetShown(showPlaque)
        if frame.PanelHost then frame.PanelHost:SetShown(showPlaque) end
        frame.TextHost:SetShown(showPlaque)
        if frame.Gems then frame.Gems:SetShown(showPlaque) end
        if frame.Overlay then frame.Overlay:SetShown(showPlaque) end
        if frame.GlowTL then frame.GlowTL:SetShown(showPlaque) end
        if frame.GlowTR then frame.GlowTR:SetShown(showPlaque) end
        if frame.GlowBL then frame.GlowBL:SetShown(showPlaque) end
        if frame.GlowBR then frame.GlowBR:SetShown(showPlaque) end
        cache.showPlaque = showPlaque
    end

    local arrowTint    = ResolveArrowColor and ResolveArrowColor(iconSpec) or iconSpec.tint or DEFAULT_TINT
    local animatedTint = ResolveAnimatedColor and ResolveAnimatedColor(iconSpec) or iconSpec.tint or DEFAULT_TINT
    if showPlaque then
        local panelTint   = ResolvePlaqueColors and ResolvePlaqueColors(iconSpec) or DEFAULT_TINT
        local titleTint   = ResolvePinpointTitleColor and ResolvePinpointTitleColor() or nil
        local subtextTint = ResolvePinpointSubtextColor and ResolvePinpointSubtextColor() or nil
        frame.Panel:SetVertexColor(panelTint.r or 1, panelTint.g or 1, panelTint.b or 1, 0.95)
        if frame.Gems then
            frame.Gems:SetVertexColor(animatedTint.r or 1, animatedTint.g or 1, animatedTint.b or 1, animatedTint.a or 1)
        end
        ApplyResolvedFontStringColor(frame.Title, titleTint)
        ApplyResolvedFontStringColor(frame.Subtext, subtextTint)

        local showDestination = _settings.worldOverlayShowDestinationInfo
        local showExtended = _settings.worldOverlayShowExtendedInfo
        frame.Title:SetShown(showDestination and type(title) == "string" and title ~= "")
        frame.Subtext:SetShown(showExtended and type(subtext) == "string" and subtext ~= "")
        local shownTitle = (showDestination and title) or ""
        local shownSubtext = (showExtended and subtext) or ""
        local contentChanged = IsPinpointContentChanged(cache, shownTitle, shownSubtext, showDestination, showExtended)
        if frame.__zwpTitleText ~= shownTitle then
            frame.Title:SetText(shownTitle)
            frame.__zwpTitleText = shownTitle
        end
        if frame.__zwpSubtextText ~= shownSubtext then
            frame.Subtext:SetText(shownSubtext)
            frame.__zwpSubtextText = shownSubtext
        end

        local panelWidth = cache.panelWidth
        if contentChanged or panelWidth == nil then
            panelWidth = ResolvePinpointPanelWidth(frame)
            cache.panelWidth = panelWidth
        end

        if frame.Panel:GetWidth() ~= panelWidth then
            frame.Panel:SetWidth(panelWidth)
        end
        if frame.PanelHost and frame.PanelHost:GetWidth() ~= panelWidth then
            frame.PanelHost:SetWidth(panelWidth)
        end
        if frame:GetWidth() ~= panelWidth then
            frame:SetWidth(panelWidth)
        end

        if contentChanged or cache.layoutWidth ~= panelWidth then
            LayoutPinpointText(frame, panelWidth)
            cache.layoutWidth = panelWidth
        end
    end

    frame.Arrow1:SetVertexColor(arrowTint.r or 1, arrowTint.g or 1, arrowTint.b or 1, 1)
    frame.Arrow2:SetVertexColor(arrowTint.r or 1, arrowTint.g or 1, arrowTint.b or 1, 0.9)
    frame.Arrow3:SetVertexColor(arrowTint.r or 1, arrowTint.g or 1, arrowTint.b or 1, 0.8)
    if cache.iconSpecRef ~= iconSpec then
        SetContextIconSpec(frame.ContextIcon, iconSpec)
        cache.iconSpecRef = iconSpec
    end
end

-- ============================================================
-- Navigator frame
-- ============================================================

local function GetNavigatorScreenCenter()
    local centerX, centerY = WorldFrame:GetCenter()
    local scale = UIParent:GetEffectiveScale() or 1
    return (centerX or 0) / scale, (centerY or 0) / scale
end

local function SetNavigatorEllipticalRadii(cache, major, minor)
    cache.majorAxisSquared = major * major
    cache.minorAxisSquared = minor * minor
    cache.axesMultiplied = major * minor
end

local function GetNavigatorAngleBetween(fromX, fromY, toX, toY)
    local fromLength = math.sqrt((fromX * fromX) + (fromY * fromY))
    local toLength = math.sqrt((toX * toX) + (toY * toY))
    if fromLength <= 0 or toLength <= 0 then
        return 0
    end

    local dot = ((fromX * toX) + (fromY * toY)) / (fromLength * toLength)
    dot = math.max(-1, math.min(1, dot))
    local angle = math.acos(dot)
    local cross = (fromX * toY) - (fromY * toX)
    if cross < 0 then
        angle = -angle
    end
    return angle
end

local function UpdateNavigatorFrame(iconSpec, alphaOverride)
    local frame = overlay.navigator
    if not frame then
        EnsureNavigatorFrame()
        frame = overlay.navigator
    end
    local navFrame = derived.navFrame
    if not frame or not navFrame then
        return
    end

    local cache = _frameCache.navigator
    local newScale = _settings.worldOverlayNavigatorSize
    if cache.scale ~= newScale then
        frame:SetScale(newScale)
        cache.scale = newScale
    end
    local newAlpha = (alphaOverride ~= nil) and alphaOverride
        or (_settings.worldOverlayNavigatorOpacity * GetHoverMultiplier())
    if cache.alpha ~= newAlpha then
        frame:SetAlpha(newAlpha)
        cache.alpha = newAlpha
    end

    local distanceSetting = _settings.worldOverlayNavigatorDistance or 1
    local useDynamicDistance = _settings.worldOverlayNavigatorDynamicDistance
    local zoom = useDynamicDistance and math.max(NAVIGATOR_MIN_ZOOM, GetCameraZoom()) or 39
    if cache.zoom ~= zoom or cache.distanceSetting ~= distanceSetting then
        local major = math.min(NAVIGATOR_BASE_MAJOR * (NAVIGATOR_BASE_ZOOM / zoom), NAVIGATOR_MAX_AXIS)
        local minor = math.min(NAVIGATOR_BASE_MINOR * (NAVIGATOR_BASE_ZOOM / zoom), NAVIGATOR_MAX_AXIS)
        major = major * distanceSetting
        minor = minor * distanceSetting
        cache.zoom = zoom
        cache.distanceSetting = distanceSetting
        SetNavigatorEllipticalRadii(cache, major, minor)
    end

    local centerX, centerY = GetNavigatorScreenCenter()
    local navX, navY = navFrame:GetCenter()
    if type(navX) ~= "number" or type(navY) ~= "number" then
        return
    end

    local posX = navX - centerX
    local posY = navY - centerY
    local denominator = math.sqrt((cache.majorAxisSquared * posY * posY) + (cache.minorAxisSquared * posX * posX))
    if denominator <= 0 then
        return
    end

    local ratio = cache.axesMultiplied / denominator
    cache.targetPositionX = posX * ratio
    cache.targetPositionY = posY * ratio

    if cache.currentPositionX == nil or cache.currentPositionY == nil then
        cache.currentPositionX = cache.targetPositionX
        cache.currentPositionY = cache.targetPositionY
    else
        cache.currentPositionX = cache.currentPositionX + ((cache.targetPositionX - cache.currentPositionX) * 0.5)
        cache.currentPositionY = cache.currentPositionY + ((cache.targetPositionY - cache.currentPositionY) * 0.5)
    end

    frame:ClearAllPoints()
    frame:SetPoint("CENTER", WorldFrame, "CENTER", cache.currentPositionX, cache.currentPositionY)

    local targetAngle = -GetNavigatorAngleBetween(
        navX - centerX,
        navY - centerY,
        NAVIGATOR_UP_VECTOR_X,
        NAVIGATOR_UP_VECTOR_Y
    )
    if cache.currentAngle == nil then
        cache.currentAngle = targetAngle
    else
        local angleDiff = (targetAngle - cache.currentAngle + math.pi) % (2 * math.pi) - math.pi
        if math.abs(angleDiff) > NAVIGATOR_ROTATION_THRESHOLD then
            cache.currentAngle = cache.currentAngle + (angleDiff * 0.5)
        else
            cache.currentAngle = targetAngle
        end
    end
    frame.Arrow:SetRotation(cache.currentAngle)

    cache.lastNavX = navX
    cache.lastNavY = navY
    cache.updateNeeded = math.abs(cache.targetPositionX - cache.currentPositionX) > NAVIGATOR_POSITION_THRESHOLD
        or math.abs(cache.targetPositionY - cache.currentPositionY) > NAVIGATOR_POSITION_THRESHOLD
        or math.abs((targetAngle - cache.currentAngle + math.pi) % (2 * math.pi) - math.pi) >
        NAVIGATOR_ROTATION_THRESHOLD

    if cache.iconSpecRef ~= iconSpec then
        local arrowTint = ResolveNavArrowColor and ResolveNavArrowColor(iconSpec) or iconSpec.tint or DEFAULT_TINT
        frame.Arrow:SetVertexColor(arrowTint.r or 1, arrowTint.g or 1, arrowTint.b or 1, 1)
        SetContextIconSpec(frame.ContextIcon, iconSpec)
        cache.iconSpecRef = iconSpec
    end
end

-- ============================================================
-- Render dispatch
-- ============================================================

local function RenderNativeOverlayVisuals(elapsed)
    local iconSpec = overlay.cachedIconSpec or ICON_SPECS.guide
    local arrowTint = ResolveArrowColor and ResolveArrowColor(iconSpec) or iconSpec.tint or DEFAULT_TINT
    local animatedTint = ResolveAnimatedColor and ResolveAnimatedColor(iconSpec) or arrowTint
    local hoverMultiplier = GetHoverMultiplier()

    -- Navigator fade: 0→1 when entering navigator mode, 1→0 when leaving.
    local navFadeState = overlay.navFadeState
    local navFadeAlpha = overlay.navFadeAlpha
    local isNavMode = derived.mode == "navigator"
    if isNavMode then
        if navFadeState ~= "in" and navFadeState ~= "steady" then
            navFadeState = "in"
            overlay.navFadeState = "in"
        end
    elseif navFadeState == "in" or navFadeState == "steady" then
        navFadeState = "out"
        overlay.navFadeState = "out"
    end
    if navFadeState == "in" then
        navFadeAlpha = math.min(1, navFadeAlpha + elapsed / NAVIGATOR_FADE_DURATION)
        overlay.navFadeAlpha = navFadeAlpha
        if navFadeAlpha >= 1 then
            overlay.navFadeState = "steady"
            navFadeState = "steady"
        end
    elseif navFadeState == "out" then
        navFadeAlpha = math.max(0, navFadeAlpha - elapsed / NAVIGATOR_FADE_DURATION)
        overlay.navFadeAlpha = navFadeAlpha
        if navFadeAlpha <= 0 then
            overlay.navFadeState = "hidden"
            navFadeState = "hidden"
        end
    end
    local navIsFading = navFadeState == "out"
    local showNav = isNavMode or navIsFading

    if transition.active and IsWaypointPinpointTransition(transition.fromMode, transition.toMode) then
        local duration = transition.duration > 0 and transition.duration or PINPOINT_TRANSITION_DURATION
        if elapsed > 0 then
            transition.elapsed = math.min(duration, transition.elapsed + elapsed)
        end

        local progress = Clamp01(transition.elapsed / duration)
        local waypointProgress
        local waypointBeaconProgress
        local waypointIconProgress
        local pinpointAlphaProgress
        local pinpointMoveProgress
        local waypointAlpha
        local waypointIconScale
        local waypointMaskScale
        local pinpointAlpha
        local pinpointOffset
        if transition.fromMode == "waypoint" and transition.toMode == "pinpoint" then
            waypointProgress = Clamp01(transition.elapsed / WAYPOINT_TRANSITION_OUTRO_FADE_DURATION)
            waypointBeaconProgress = EaseInExpo(Clamp01(transition.elapsed / WAYPOINT_TRANSITION_OUTRO_BEACON_DURATION))
            pinpointAlphaProgress = Clamp01(transition.elapsed / PINPOINT_TRANSITION_INTRO_FADE_DURATION)
            pinpointMoveProgress = EaseOutCubic(Clamp01(transition.elapsed / PINPOINT_TRANSITION_INTRO_MOVE_DURATION))
            waypointAlpha = _settings.worldOverlayWaypointOpacity * hoverMultiplier * (1 - waypointProgress)
            waypointIconScale = 1
            waypointMaskScale = Lerp(WAYPOINT_BEACON_MASK_SHOWN_SCALE, WAYPOINT_BEACON_MASK_HIDDEN_SCALE,
                waypointBeaconProgress)
            pinpointAlpha = _settings.worldOverlayPinpointOpacity * hoverMultiplier * pinpointAlphaProgress
            pinpointOffset = GetDiamondAlignOffset() * (1 - pinpointMoveProgress)
        else
            waypointProgress = Clamp01(transition.elapsed / WAYPOINT_TRANSITION_INTRO_FADE_DURATION)
            waypointIconProgress = EaseInExpo(Clamp01(transition.elapsed / WAYPOINT_ICON_INTRO_DURATION))
            waypointBeaconProgress = 0
            if transition.elapsed > WAYPOINT_TRANSITION_INTRO_BEACON_DELAY then
                waypointBeaconProgress = EaseInExpo(Clamp01((transition.elapsed - WAYPOINT_TRANSITION_INTRO_BEACON_DELAY) /
                    WAYPOINT_TRANSITION_INTRO_BEACON_DURATION))
            end
            pinpointAlphaProgress = Clamp01(transition.elapsed / PINPOINT_TRANSITION_OUTRO_FADE_DURATION)
            pinpointMoveProgress = EaseOutCubic(Clamp01(transition.elapsed / PINPOINT_TRANSITION_OUTRO_MOVE_DURATION))
            waypointAlpha = _settings.worldOverlayWaypointOpacity * hoverMultiplier * waypointProgress
            waypointIconScale = Lerp(WAYPOINT_ICON_INTRO_SCALE, 1, waypointIconProgress)
            waypointMaskScale = Lerp(WAYPOINT_BEACON_MASK_HIDDEN_SCALE, WAYPOINT_BEACON_MASK_SHOWN_SCALE,
                waypointBeaconProgress)
            pinpointAlpha = _settings.worldOverlayPinpointOpacity * hoverMultiplier * (1 - pinpointAlphaProgress)
            pinpointOffset = GetDiamondAlignOffset() * pinpointMoveProgress
        end

        ShowFrameSet(true, true, showNav)
        UpdateWaypointVisual(waypointAlpha, waypointIconScale, waypointMaskScale)
        UpdatePinpointVisual(pinpointAlpha, pinpointOffset, arrowTint, animatedTint)

        if progress >= 1 then
            local completedMode = transition.toMode
            ResetModeTransition(completedMode)
            if completedMode == "waypoint" then
                ShowFrameSet(true, false, showNav)
                UpdateWaypointVisual(_settings.worldOverlayWaypointOpacity * hoverMultiplier, 1,
                    WAYPOINT_BEACON_MASK_SHOWN_SCALE)
            else
                ShowFrameSet(false, true, showNav)
                UpdatePinpointVisual(_settings.worldOverlayPinpointOpacity * hoverMultiplier, 0, arrowTint, animatedTint)
            end
        end
        if navIsFading then
            UpdateNavigatorFrame(iconSpec, navFadeAlpha * _settings.worldOverlayNavigatorOpacity * hoverMultiplier)
        end
        return
    end

    if derived.mode == "waypoint" then
        ShowFrameSet(true, false, showNav)
        UpdateWaypointVisual(_settings.worldOverlayWaypointOpacity * hoverMultiplier, 1, WAYPOINT_BEACON_MASK_SHOWN_SCALE)
        if navIsFading then
            UpdateNavigatorFrame(iconSpec, navFadeAlpha * _settings.worldOverlayNavigatorOpacity * hoverMultiplier)
        end
        return
    end

    if derived.mode == "pinpoint" then
        ShowFrameSet(false, true, showNav)
        UpdatePinpointVisual(_settings.worldOverlayPinpointOpacity * hoverMultiplier, 0, arrowTint, animatedTint)
        if navIsFading then
            UpdateNavigatorFrame(iconSpec, navFadeAlpha * _settings.worldOverlayNavigatorOpacity * hoverMultiplier)
        end
        return
    end

    if derived.mode == "navigator" then
        ShowFrameSet(false, false, true)
        UpdateNavigatorFrame(iconSpec, navFadeAlpha * _settings.worldOverlayNavigatorOpacity * hoverMultiplier)
        return
    end

    ShowFrameSet(false, false, false)
end

M.RefreshNativeOverlayContent = RefreshNativeOverlayContent
M.UpdatePinpointArrowVisual = UpdatePinpointArrowVisual
M.UpdateFrameAlpha = UpdateFrameAlpha
M.ApplyPinpointAnchor = ApplyPinpointAnchor
M.UpdateWaypointVisual = UpdateWaypointVisual
M.UpdatePinpointVisual = UpdatePinpointVisual
M.UpdateWaypointFrame = UpdateWaypointFrame
M.UpdatePinpointFrame = UpdatePinpointFrame
M.UpdateNavigatorFrame = UpdateNavigatorFrame
M.RenderNativeOverlayVisuals = RenderNativeOverlayVisuals
