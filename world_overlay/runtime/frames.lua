local NS                              = _G.AzerothWaypointNS
local C                               = NS.Constants
local M                               = NS.Internal.WorldOverlay
local overlay                         = M.overlay
local target                          = M.target
local derived                         = M.derived
local transition                      = M.transition
local fontStringTextCache             = M.fontStringTextCache
local _settings                       = M.settingsSnapshot
local unpackCoords                    = M.unpackCoords
local CFG                             = M.Config

local WAYPOINT_TEXTURE                = CFG.WAYPOINT_TEXTURE
local WAYPOINT_BEACON_TEXTURE           = CFG.WAYPOINT_BEACON_TEXTURE
local CONTEXT_TEXTURE                 = CFG.CONTEXT_TEXTURE
local WAYPOINT_BEACON_MASK_TEXTURE      = CFG.WAYPOINT_BEACON_MASK_TEXTURE
local WAYPOINT_BEACON_TEX_COORDS        = CFG.WAYPOINT_BEACON_TEX_COORDS
local WAYPOINT_BEACON_LAYOUT            = CFG.WAYPOINT_BEACON_LAYOUT
local PINPOINT_ARROW_TEXTURE          = CFG.PINPOINT_ARROW_TEXTURE
local PINPOINT_ARROW_TEX_COORDS       = CFG.PINPOINT_ARROW_TEX_COORDS
local PINPOINT_ARROW_WIDTH            = CFG.PINPOINT_ARROW_WIDTH
local PINPOINT_ARROW_HEIGHT           = CFG.PINPOINT_ARROW_HEIGHT
local PINPOINT_ARROW_SLOT_OVERLAP     = CFG.PINPOINT_ARROW_SLOT_OVERLAP
local NAVIGATOR_ARROW_TEXTURE         = CFG.NAVIGATOR_ARROW_TEXTURE
local NAVIGATOR_ARROW_TEX_COORDS      = CFG.NAVIGATOR_ARROW_TEX_COORDS
local NAVIGATOR_ARROW_WIDTH           = CFG.NAVIGATOR_ARROW_WIDTH
local NAVIGATOR_ARROW_HEIGHT          = CFG.NAVIGATOR_ARROW_HEIGHT
local Plaques                         = M.Plaques
local PlaqueAnimations                = M.PlaqueAnimations
local UPDATE_INTERVAL                 = CFG.UPDATE_INTERVAL
local WAYPOINT_BEACON_WIDTH             = CFG.WAYPOINT_BEACON_WIDTH
local WAYPOINT_BEACON_HEIGHT            = CFG.WAYPOINT_BEACON_HEIGHT
local WAYPOINT_BEACON_OFFSET_Y          = CFG.WAYPOINT_BEACON_OFFSET_Y
local WAYPOINT_BEACON_MASK_SIZE         = CFG.WAYPOINT_BEACON_MASK_SIZE
local WAYPOINT_CONTEXT_SIZE           = CFG.WAYPOINT_CONTEXT_SIZE
local PINPOINT_CONTEXT_SIZE           = CFG.PINPOINT_CONTEXT_SIZE
local NAVIGATOR_CONTEXT_SIZE          = CFG.NAVIGATOR_CONTEXT_SIZE
local CONTEXT_ICON_REFERENCE_SIZE     = CFG.CONTEXT_ICON_REFERENCE_SIZE or WAYPOINT_CONTEXT_SIZE
local CONTEXT_ICON_FILL_RATIO         = CFG.CONTEXT_ICON_FILL_RATIO
local CONTEXT_ICON_ONLY_FILL_RATIO    = CFG.CONTEXT_ICON_ONLY_FILL_RATIO
local CONTEXT_ICON_IMAGE_Y_OFFSET     = CFG.CONTEXT_ICON_IMAGE_Y_OFFSET
local PINPOINT_ARROW_GROUP_Y          = CFG.PINPOINT_ARROW_GROUP_Y
local WAYPOINT_FOOTER_WIDTH           = CFG.WAYPOINT_FOOTER_WIDTH
local WAYPOINT_FOOTER_HEIGHT          = CFG.WAYPOINT_FOOTER_HEIGHT
local WAYPOINT_FOOTER_TITLE_MAX_LINES = CFG.WAYPOINT_FOOTER_TITLE_MAX_LINES
local PINPOINT_TITLE_MAX_LINES        = CFG.PINPOINT_TITLE_MAX_LINES
local PINPOINT_SUBTEXT_MAX_LINES      = CFG.PINPOINT_SUBTEXT_MAX_LINES
local PINPOINT_TEXT_INSET_X           = CFG.PINPOINT_TEXT_INSET_X
local PINPOINT_TEXT_INSET_TOP         = CFG.PINPOINT_TEXT_INSET_TOP
local PINPOINT_TEXT_INSET_BOTTOM      = CFG.PINPOINT_TEXT_INSET_BOTTOM
local PINPOINT_TEXT_GAP               = CFG.PINPOINT_TEXT_GAP
local PINPOINT_CONTEXT_OFFSET_Y       = CFG.PINPOINT_CONTEXT_OFFSET_Y
local PINPOINT_FRAME_EXTRA_HEIGHT     = CFG.PINPOINT_FRAME_EXTRA_HEIGHT
local DEFAULT_TINT                    = CFG.DEFAULT_TINT
local CONTEXT_DISPLAY_DIAMOND_ICON    = C.WORLD_OVERLAY_CONTEXT_DISPLAY_DIAMOND_ICON
local CONTEXT_DISPLAY_ICON_ONLY       = C.WORLD_OVERLAY_CONTEXT_DISPLAY_ICON_ONLY
local CONTEXT_DISPLAY_HIDDEN          = C.WORLD_OVERLAY_CONTEXT_DISPLAY_HIDDEN

local SetIconTexture                  = M.SetIconTexture
local ResolveContextDiamondColor      = M.ResolveContextDiamondColor
local ResolveIconGlyphStyle           = M.ResolveIconGlyphStyle

local DEFAULT_PINPOINT_PANEL_SPEC = {
    minW = 140,
    baseH = 72,
    maxH = 96,
    heightRatio = 0.28,
    textInsetX = PINPOINT_TEXT_INSET_X,
}

local function GetDefaultPinpointPanelSpec()
    local spec = Plaques and Plaques.GetSpec and Plaques.GetSpec(C.WORLD_OVERLAY_PLAQUE_DEFAULT) or nil
    if type(spec) ~= "table" then
        return DEFAULT_PINPOINT_PANEL_SPEC
    end

    return {
        minW = spec.minW or DEFAULT_PINPOINT_PANEL_SPEC.minW,
        baseH = spec.baseH or DEFAULT_PINPOINT_PANEL_SPEC.baseH,
        maxH = spec.maxH or DEFAULT_PINPOINT_PANEL_SPEC.maxH,
        heightRatio = spec.heightRatio or DEFAULT_PINPOINT_PANEL_SPEC.heightRatio,
        textInsetX = spec.textInsetX or DEFAULT_PINPOINT_PANEL_SPEC.textInsetX,
    }
end

local function GetPinpointPlaqueSpec(frame)
    local defaultSpec = GetDefaultPinpointPanelSpec()
    if not frame then
        return defaultSpec
    end

    local spec = frame.__awpPlaqueSpec
    if type(spec) ~= "table" and frame.Panel then
        spec = frame.Panel.__awpPlaqueSpec
    end

    if type(spec) ~= "table" then
        return defaultSpec
    end

    return {
        minW = spec.minW or defaultSpec.minW,
        baseH = spec.baseH or defaultSpec.baseH,
        maxH = spec.maxH or defaultSpec.maxH,
        heightRatio = spec.heightRatio or defaultSpec.heightRatio,
        textInsetX = spec.textInsetX or defaultSpec.textInsetX,
    }
end

local function ApplyPinpointTextHostAnchors(frame)
    if not frame or not frame.TextHost or not frame.PanelHost then
        return
    end

    local spec = GetPinpointPlaqueSpec(frame)
    local textInsetX = spec.textInsetX or PINPOINT_TEXT_INSET_X

    frame.TextHost:ClearAllPoints()
    frame.TextHost:SetPoint("TOPLEFT", frame.PanelHost, "TOPLEFT", textInsetX, -PINPOINT_TEXT_INSET_TOP)
    frame.TextHost:SetPoint("TOPRIGHT", frame.PanelHost, "TOPRIGHT", -textInsetX, -PINPOINT_TEXT_INSET_TOP)
    frame.TextHost:SetPoint("BOTTOM", frame.PanelHost, "BOTTOM", 0, PINPOINT_TEXT_INSET_BOTTOM)
end

-- ============================================================
-- Shared frame utilities
-- ============================================================

local function CreateContextIcon(parent, size, iconSize)
    local frame = CreateFrame("Frame", nil, parent)
    frame:SetSize(size, size)
    frame.__awpContainerSize = size

    frame.Background = frame:CreateTexture(nil, "ARTWORK")
    frame.Background:SetTexture(CONTEXT_TEXTURE)
    frame.Background:SetTexCoord(0, 1, 0, 1)
    frame.Background:SetAllPoints()

    frame.Image = frame:CreateTexture(nil, "OVERLAY")
    frame.Image:SetSize(iconSize, iconSize)
    frame.Image:SetPoint("CENTER", 0, CONTEXT_ICON_IMAGE_Y_OFFSET)

    return frame
end

local function StoreDefaultFontStringColor(fontString)
    if not fontString or fontString.__awpDefaultTextColor then
        return
    end

    local r, g, b, a = fontString:GetTextColor()
    fontString.__awpDefaultTextColor = {
        r = r or 1,
        g = g or 1,
        b = b or 1,
        a = a or 1,
    }
end

local function ApplyFooterFontStringStyle(fontString)
    if not fontString then
        return
    end

    fontString:SetShadowColor(0, 0, 0, 0.95)
    fontString:SetShadowOffset(1, -1)
end

local function CreateBeaconTexture(parent, drawLayer, subLevel, texCoords, width, height)
    local texture = parent:CreateTexture(nil, drawLayer)
    texture:SetDrawLayer(drawLayer, subLevel or 0)
    texture:SetTexture(WAYPOINT_BEACON_TEXTURE)
    texture:SetTexCoord(unpackCoords(texCoords))
    texture:SetBlendMode("ADD")
    texture:SetSize(width, height)
    return texture
end

local function CreatePinpointArrowTexture(parent, alpha)
    local texture = parent:CreateTexture(nil, "ARTWORK")
    texture:SetTexture(PINPOINT_ARROW_TEXTURE)
    texture:SetTexCoord(unpackCoords(PINPOINT_ARROW_TEX_COORDS))
    texture:SetBlendMode("ADD")
    texture:SetSize(PINPOINT_ARROW_WIDTH, PINPOINT_ARROW_HEIGHT)
    texture:SetPoint("CENTER")
    if alpha and alpha < 1 then
        texture:SetAlpha(alpha)
    end
    return texture
end

local function AddBeaconMask(texture, maskHost, maskTexturePath)
    local mask = maskHost:CreateMaskTexture(nil, "BACKGROUND")
    mask:SetTexture(maskTexturePath, "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
    mask:SetAllPoints()
    texture:AddMaskTexture(mask)
    texture.Mask = mask
    return mask
end

local function CreateWaypointBeacon(parent)
    local layout = WAYPOINT_BEACON_LAYOUT
    local beacon = CreateFrame("Frame", nil, parent)
    beacon:SetSize(WAYPOINT_BEACON_WIDTH, WAYPOINT_BEACON_HEIGHT)
    beacon:SetPoint("BOTTOM", parent, "CENTER", 0, WAYPOINT_BEACON_OFFSET_Y)

    beacon.MaskHost = CreateFrame("Frame", nil, beacon)
    beacon.MaskHost:SetSize(WAYPOINT_BEACON_MASK_SIZE, WAYPOINT_BEACON_MASK_SIZE)
    beacon.MaskHost:SetPoint("CENTER", beacon, "BOTTOM", 0, 0)

    beacon.BottomCapFlameA = CreateBeaconTexture(
        beacon, "BACKGROUND", 0, WAYPOINT_BEACON_TEX_COORDS.bottomCap,
        layout.bottomCap.width, layout.bottomCap.height
    )
    beacon.BottomCapFlameA:SetPoint("CENTER", parent, "CENTER", layout.bottomCap.offsetX, layout.bottomCap.offsetY)

    beacon.BottomCapFlameB = CreateBeaconTexture(
        beacon, "BACKGROUND", 1, WAYPOINT_BEACON_TEX_COORDS.bottomCap,
        layout.bottomCap.width, layout.bottomCap.height
    )
    beacon.BottomCapFlameB:SetPoint("CENTER", parent, "CENTER", layout.bottomCap.offsetX, layout.bottomCap.offsetY)

    beacon.BottomCap = CreateBeaconTexture(
        beacon, "BACKGROUND", 2, WAYPOINT_BEACON_TEX_COORDS.bottomCap,
        layout.bottomCap.width, layout.bottomCap.height
    )
    beacon.BottomCap:SetPoint("CENTER", parent, "CENTER", layout.bottomCap.offsetX, layout.bottomCap.offsetY)

    beacon.Glow = CreateBeaconTexture(beacon, "BACKGROUND", 1, WAYPOINT_BEACON_TEX_COORDS.glow, layout.glow.width,
        layout.glow.height)
    beacon.Glow:SetBlendMode("BLEND")
    beacon.Glow:SetPoint("BOTTOM", beacon, "BOTTOM", layout.glow.offsetX, layout.glow.offsetY)
    AddBeaconMask(beacon.Glow, beacon.MaskHost, WAYPOINT_BEACON_MASK_TEXTURE)

    beacon.LeftVeilA = CreateBeaconTexture(
        beacon, "BACKGROUND", 0, WAYPOINT_BEACON_TEX_COORDS.leftVeil,
        layout.leftVeil.width, layout.leftVeil.height
    )
    beacon.LeftVeilA:SetPoint("BOTTOM", beacon, "BOTTOM", layout.leftVeil.offsetX, layout.leftVeil.offsetY)
    AddBeaconMask(beacon.LeftVeilA, beacon.MaskHost, WAYPOINT_BEACON_MASK_TEXTURE)

    beacon.LeftVeilB = CreateBeaconTexture(
        beacon, "BACKGROUND", 0, WAYPOINT_BEACON_TEX_COORDS.leftVeil,
        layout.leftVeil.width, layout.leftVeil.height
    )
    beacon.LeftVeilB:SetPoint("BOTTOM", beacon, "BOTTOM", layout.leftVeil.offsetX,
        layout.leftVeil.offsetY + layout.leftVeil.height)
    AddBeaconMask(beacon.LeftVeilB, beacon.MaskHost, WAYPOINT_BEACON_MASK_TEXTURE)

    beacon.LeftVeilC = CreateBeaconTexture(
        beacon, "BACKGROUND", 0, WAYPOINT_BEACON_TEX_COORDS.leftVeil,
        layout.leftVeil.width, layout.leftVeil.height
    )
    beacon.LeftVeilC:SetPoint("BOTTOM", beacon, "BOTTOM", layout.leftVeil.offsetX,
        layout.leftVeil.offsetY + (layout.leftVeil.height * 2))
    AddBeaconMask(beacon.LeftVeilC, beacon.MaskHost, WAYPOINT_BEACON_MASK_TEXTURE)

    beacon.RightVeilA = CreateBeaconTexture(
        beacon, "BACKGROUND", 1, WAYPOINT_BEACON_TEX_COORDS.rightVeil,
        layout.rightVeil.width, layout.rightVeil.height
    )
    beacon.RightVeilA:SetPoint("BOTTOM", beacon, "BOTTOM", layout.rightVeil.offsetX, layout.rightVeil.offsetY)
    AddBeaconMask(beacon.RightVeilA, beacon.MaskHost, WAYPOINT_BEACON_MASK_TEXTURE)

    beacon.RightVeilB = CreateBeaconTexture(
        beacon, "BACKGROUND", 1, WAYPOINT_BEACON_TEX_COORDS.rightVeil,
        layout.rightVeil.width, layout.rightVeil.height
    )
    beacon.RightVeilB:SetPoint("BOTTOM", beacon, "BOTTOM", layout.rightVeil.offsetX,
        layout.rightVeil.offsetY + layout.rightVeil.height)
    AddBeaconMask(beacon.RightVeilB, beacon.MaskHost, WAYPOINT_BEACON_MASK_TEXTURE)

    beacon.RightVeilC = CreateBeaconTexture(
        beacon, "BACKGROUND", 1, WAYPOINT_BEACON_TEX_COORDS.rightVeil,
        layout.rightVeil.width, layout.rightVeil.height
    )
    beacon.RightVeilC:SetPoint("BOTTOM", beacon, "BOTTOM", layout.rightVeil.offsetX,
        layout.rightVeil.offsetY + (layout.rightVeil.height * 2))
    AddBeaconMask(beacon.RightVeilC, beacon.MaskHost, WAYPOINT_BEACON_MASK_TEXTURE)

    beacon.Core = CreateBeaconTexture(beacon, "BACKGROUND", 2, WAYPOINT_BEACON_TEX_COORDS.core, layout.core.width,
        layout.core.height)
    beacon.Core:SetBlendMode("BLEND")
    beacon.Core:SetPoint("BOTTOM", beacon, "BOTTOM", layout.core.offsetX, layout.core.offsetY)
    AddBeaconMask(beacon.Core, beacon.MaskHost, WAYPOINT_BEACON_MASK_TEXTURE)

    beacon.Layout = layout
    beacon.BeaconTintLayers = {
        beacon.BottomCapFlameA,
        beacon.BottomCapFlameB,
        beacon.BottomCap,
        beacon.LeftVeilA,
        beacon.LeftVeilB,
        beacon.LeftVeilC,
        beacon.RightVeilA,
        beacon.RightVeilB,
        beacon.RightVeilC,
        beacon.Core,
        beacon.Glow,
    }
    
    beacon.LeftVeils = { beacon.LeftVeilA, beacon.LeftVeilB, beacon.LeftVeilC }
    beacon.RightVeils = { beacon.RightVeilA, beacon.RightVeilB, beacon.RightVeilC }

    return beacon
end

local function GetContextGlyphSize(containerSize)
    return math.floor((containerSize * CONTEXT_ICON_FILL_RATIO) + 0.5)
end

local function GetContextGlyphDisplaySize(containerSize, showDiamond)
    local fillRatio = showDiamond and CONTEXT_ICON_FILL_RATIO or CONTEXT_ICON_ONLY_FILL_RATIO
    return math.floor((containerSize * fillRatio) + 0.5)
end

local function ResolveContextGlyphReferenceSize(spec)
    local referenceSize = tonumber(spec and spec.iconSizeReference)
    if not referenceSize or referenceSize <= 0 then
        referenceSize = tonumber(CONTEXT_ICON_REFERENCE_SIZE) or tonumber(WAYPOINT_CONTEXT_SIZE)
    end
    if not referenceSize or referenceSize <= 0 then
        return nil
    end
    return referenceSize
end

local function ResolveContextGlyphMetric(value, spec, containerSize, modeField)
    local numberValue = tonumber(value)
    if not numberValue then
        return nil
    end

    if spec and spec[modeField] == "absolute" then
        return numberValue
    end

    local resolvedContainerSize = tonumber(containerSize)
    local referenceSize = ResolveContextGlyphReferenceSize(spec)
    if not resolvedContainerSize or resolvedContainerSize <= 0 or not referenceSize then
        return numberValue
    end

    return numberValue * (resolvedContainerSize / referenceSize)
end

local function ResolveContextGlyphSizeOverride(spec, containerSize)
    local iconSize = spec and spec.iconSize or nil
    local resolvedSize = ResolveContextGlyphMetric(iconSize, spec, containerSize, "iconSizeMode")
    if type(resolvedSize) ~= "number" or resolvedSize <= 0 then
        return nil
    end

    return math.max(1, math.floor(resolvedSize + 0.5))
end

local function ResolveContextGlyphOffset(value, spec, containerSize)
    local resolvedOffset = ResolveContextGlyphMetric(value, spec, containerSize, "iconOffsetMode")
    if type(resolvedOffset) ~= "number" then
        return 0
    end

    return resolvedOffset
end

local function ResolveContextDisplayMode()
    local mode = _settings.worldOverlayContextDisplayMode
    if mode == CONTEXT_DISPLAY_ICON_ONLY or mode == CONTEXT_DISPLAY_HIDDEN then
        return mode
    end

    return CONTEXT_DISPLAY_DIAMOND_ICON
end

local function GetContextDisplayPolicy(displayMode)
    local mode = displayMode
    if mode ~= CONTEXT_DISPLAY_DIAMOND_ICON
        and mode ~= CONTEXT_DISPLAY_ICON_ONLY
        and mode ~= CONTEXT_DISPLAY_HIDDEN
    then
        mode = ResolveContextDisplayMode()
    end

    return mode, mode == CONTEXT_DISPLAY_DIAMOND_ICON, mode ~= CONTEXT_DISPLAY_HIDDEN
end

local function ShouldShowPinpointArrows()
    return _settings.worldOverlayShowPinpointArrows ~= false
end

local function ApplyContextIconStyle(contextIcon, displayMode)
    if not contextIcon then
        return
    end

    local mode, showDiamond, showIcon = GetContextDisplayPolicy(displayMode)

    if contextIcon.Background then
        if showDiamond then
            contextIcon.Background:SetTexture(CONTEXT_TEXTURE)
            contextIcon.Background:SetTexCoord(0, 1, 0, 1)
            contextIcon.Background:SetAlpha(1)
            contextIcon.Background:Show()
        else
            contextIcon.Background:SetTexture(nil)
            contextIcon.Background:SetAlpha(0)
            contextIcon.Background:Hide()
        end
    end
    if contextIcon.Image then
        local containerSize = contextIcon.__awpContainerSize or 0
        local size = contextIcon.__awpIconSizeOverride or GetContextGlyphDisplaySize(containerSize, showDiamond)
        local offsetX = contextIcon.__awpIconOffsetX or 0
        local offsetY = contextIcon.__awpIconOffsetY or 0
        if size > 0 then
            contextIcon.Image:SetSize(size, size)
        end
        contextIcon.Image:ClearAllPoints()
        contextIcon.Image:SetPoint("CENTER", offsetX, (showDiamond and CONTEXT_ICON_IMAGE_Y_OFFSET or 0) + offsetY)
        if showIcon then
            contextIcon.Image:Show()
        else
            contextIcon.Image:Hide()
        end
    end
    contextIcon.__awpDisplayMode = mode
end

local function ApplyContextIconStyleToAll(force)
    local displayMode = ResolveContextDisplayMode()
    if not force and overlay.contextDisplayMode == displayMode then
        return
    end

    overlay.contextDisplayMode = displayMode
    if overlay.waypoint and overlay.waypoint.ContextIcon then
        ApplyContextIconStyle(overlay.waypoint.ContextIcon, displayMode)
    end
    if overlay.pinpoint and overlay.pinpoint.ContextIcon then
        ApplyContextIconStyle(overlay.pinpoint.ContextIcon, displayMode)
    end
    if overlay.navigator and overlay.navigator.ContextIcon then
        ApplyContextIconStyle(overlay.navigator.ContextIcon, displayMode)
    end
end

local function ApplyPinpointArrowVisibility(force)
    local showPinpointArrows = ShouldShowPinpointArrows()
    if not force and overlay.pinpointArrowsShown == showPinpointArrows then
        return
    end

    overlay.pinpointArrowsShown = showPinpointArrows
    if overlay.pinpoint and overlay.pinpoint.ArrowGroup then
        overlay.pinpoint.ArrowGroup:SetShown(showPinpointArrows)
    end
end

local function ApplyOverlayAdornmentStyleToAll(force)
    ApplyContextIconStyleToAll(force)
    ApplyPinpointArrowVisibility(force)
end

local function SetContextIconSpec(contextIcon, spec)
    if not contextIcon then
        return
    end

    local diamondTint = ResolveContextDiamondColor and ResolveContextDiamondColor(spec) or spec and spec.tint or
        DEFAULT_TINT
    local recolor = spec and spec.recolor == true or false
    local iconTint = spec and spec.tint or DEFAULT_TINT
    if ResolveIconGlyphStyle then
        recolor, iconTint = ResolveIconGlyphStyle(spec)
    end
    local containerSize = contextIcon.__awpContainerSize
    contextIcon.__awpIconSizeOverride = ResolveContextGlyphSizeOverride(spec, containerSize)
    contextIcon.__awpIconOffsetX = ResolveContextGlyphOffset(spec and spec.iconOffsetX, spec, containerSize)
    contextIcon.__awpIconOffsetY = ResolveContextGlyphOffset(spec and spec.iconOffsetY, spec, containerSize)
    contextIcon.Background:SetVertexColor(diamondTint.r or 1, diamondTint.g or 1, diamondTint.b or 1, diamondTint.a or 1)
    SetIconTexture(contextIcon.Image, spec, recolor, iconTint)
    ApplyContextIconStyle(contextIcon, contextIcon.__awpDisplayMode)
end


local function GetPinpointTextMetrics(frame, panelWidth)
    if not frame or not frame.Title or not frame.Subtext then
        return 0, 0, 0, 0, false, false
    end

    local spec = GetPinpointPlaqueSpec(frame)
    local defaultSpec = GetDefaultPinpointPanelSpec()
    local actualPanelWidth = panelWidth or frame.Panel:GetWidth() or spec.minW or defaultSpec.minW
    local textInsetX = spec.textInsetX or defaultSpec.textInsetX
    local textWidth = math.max(0, actualPanelWidth - (textInsetX * 2))
    if textWidth > 0 then
        frame.Title:SetWidth(textWidth)
        frame.Subtext:SetWidth(textWidth)
    end

    local showTitle = frame.Title:IsShown()
    local showSubtext = frame.Subtext:IsShown()
    local titleHeight = showTitle and math.max(frame.Title:GetStringHeight() or 0, 0) or 0
    local subtextHeight = showSubtext and math.max(frame.Subtext:GetStringHeight() or 0, 0) or 0
    local totalHeight = titleHeight + subtextHeight
    if showTitle and showSubtext then
        totalHeight = totalHeight + PINPOINT_TEXT_GAP
    end

    local titleTruncated = showTitle and frame.Title:IsTruncated() or false
    local subtextTruncated = showSubtext and frame.Subtext:IsTruncated() or false
    return textWidth, titleHeight, subtextHeight, totalHeight, titleTruncated, subtextTruncated
end

local function LayoutPinpointText(frame, panelWidth)
    if not frame or not frame.Panel or not frame.Title or not frame.Subtext then
        return
    end

    local spec = GetPinpointPlaqueSpec(frame)
    local defaultSpec = GetDefaultPinpointPanelSpec()
    local actualPanelWidth = panelWidth or frame.Panel:GetWidth() or spec.minW or defaultSpec.minW
    local showTitle = frame.Title:IsShown()
    local showSubtext = frame.Subtext:IsShown()
    local _, titleHeight, subtextHeight, totalHeight = GetPinpointTextMetrics(frame, actualPanelWidth)

    local aspectHeight = math.floor((actualPanelWidth * (spec.heightRatio or defaultSpec.heightRatio)) + 0.5)
    local verticalPadding = PINPOINT_TEXT_INSET_TOP + PINPOINT_TEXT_INSET_BOTTOM
    local panelHeight = math.max(
        spec.baseH or defaultSpec.baseH,
        math.min(spec.maxH or defaultSpec.maxH, math.max(totalHeight + verticalPadding, aspectHeight))
    )
    frame.Panel:SetHeight(panelHeight)
    if frame.PanelHost then frame.PanelHost:SetHeight(panelHeight) end
    frame:SetHeight(panelHeight + PINPOINT_FRAME_EXTRA_HEIGHT)

    local textHost = frame.TextHost or frame.PanelHost or frame.Panel
    frame.Title:ClearAllPoints()
    frame.Subtext:ClearAllPoints()

    if showTitle then
        frame.Title:SetPoint("TOP", textHost, "CENTER", 0, totalHeight * 0.5)
    else
        frame.Title:SetPoint("TOP", textHost, "CENTER", 0, 0)
    end

    if showSubtext then
        if showTitle then
            frame.Subtext:SetPoint("TOP", frame.Title, "BOTTOM", 0, -PINPOINT_TEXT_GAP)
        else
            frame.Subtext:SetPoint("TOP", textHost, "CENTER", 0, subtextHeight * 0.5)
        end
    else
        frame.Subtext:SetPoint("TOP", textHost, "CENTER", 0, 0)
    end
end

-- ============================================================
-- Frame state and suppression
-- ============================================================

local function SetHoverHandlers(frame)
    if not frame or frame.__awpHoverHooked then
        return
    end

    frame:EnableMouse(true)
    frame:SetPropagateMouseClicks(true)
    frame:SetPropagateMouseMotion(true)
    frame:SetScript("OnEnter", function()
        overlay.hovered = true
    end)
    frame:SetScript("OnLeave", function()
        overlay.hovered = false
    end)
    frame:SetScript("OnHide", function()
        overlay.hovered = false
    end)
    frame.__awpHoverHooked = true
end

local function CreateFooter(parent)
    local footer = CreateFrame("Frame", nil, parent)
    footer:SetSize(WAYPOINT_FOOTER_WIDTH, WAYPOINT_FOOTER_HEIGHT)

    footer.InfoText = footer:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
    footer.InfoText:SetPoint("TOP", footer, "TOP", 0, -2)
    footer.InfoText:SetWidth(WAYPOINT_FOOTER_WIDTH)
    footer.InfoText:SetJustifyH("CENTER")
    footer.InfoText:SetWordWrap(true)
    footer.InfoText:SetMaxLines(WAYPOINT_FOOTER_TITLE_MAX_LINES)
    ApplyFooterFontStringStyle(footer.InfoText)

    footer.DistanceText = footer:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    footer.DistanceText:SetPoint("TOP", footer.InfoText, "BOTTOM", 0, -1)
    footer.DistanceText:SetWidth(WAYPOINT_FOOTER_WIDTH)
    footer.DistanceText:SetJustifyH("CENTER")
    footer.DistanceText:SetWordWrap(false)
    footer.DistanceText:SetMaxLines(1)
    ApplyFooterFontStringStyle(footer.DistanceText)

    footer.ArrivalTimeText = footer:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    footer.ArrivalTimeText:SetPoint("TOP", footer.DistanceText, "BOTTOM", 0, -1)
    footer.ArrivalTimeText:SetWidth(WAYPOINT_FOOTER_WIDTH)
    footer.ArrivalTimeText:SetJustifyH("CENTER")
    footer.ArrivalTimeText:SetWordWrap(false)
    footer.ArrivalTimeText:SetMaxLines(1)
    ApplyFooterFontStringStyle(footer.ArrivalTimeText)

    return footer
end

local SUPER_TRACKED_VISUAL_MAX_DEPTH = 5
local ClearTable = _G.wipe
local superTrackedVisualScratchVisited = {}
local superTrackedVisualScratchRegions = {}
local superTrackedVisualScratchActive = {}

if type(ClearTable) ~= "function" then
    ClearTable = function(values)
        if type(values) ~= "table" then
            return
        end
        for key in pairs(values) do
            values[key] = nil
        end
    end
end

local function RestoreSuppressedRegionSet(stateKey)
    local suppressed = overlay[stateKey]
    if type(suppressed) ~= "table" then
        overlay[stateKey] = nil
        return
    end

    for region, savedAlpha in pairs(suppressed) do
        if region and type(region.SetAlpha) == "function" then
            region:SetAlpha(savedAlpha or 1)
        end
    end

    overlay[stateKey] = nil
end

local function CollectSuperTrackedVisualRegions(owner, depth, visited, regions)
    if not owner or visited[owner] or depth > SUPER_TRACKED_VISUAL_MAX_DEPTH then
        return
    end
    visited[owner] = true

    local numRegions = type(owner.GetNumRegions) == "function" and owner:GetNumRegions() or 0
    for regionIndex = 1, numRegions do
        local region = select(regionIndex, owner:GetRegions())
        if region and region.IsObjectType then
            if region:IsObjectType("Texture") or region:IsObjectType("FontString") then
                regions[#regions + 1] = region
            end
        end
    end

    if depth >= SUPER_TRACKED_VISUAL_MAX_DEPTH or type(owner.GetNumChildren) ~= "function" then
        return
    end

    local numChildren = owner:GetNumChildren()
    for childIndex = 1, numChildren do
        local child = select(childIndex, owner:GetChildren())
        if child then
            CollectSuperTrackedVisualRegions(child, depth + 1, visited, regions)
        end
    end
end

local function SuppressSuperTrackedVisuals(superTrackedFrame)
    if not superTrackedFrame then
        overlay.suppressedSuperTrackedVisuals = nil
        return
    end

    -- ApplySuperTrackedFrameVisibility() runs from the normal overlay update path
    -- while a target is active. Reuse these scratch tables so suppression stays
    -- allocation-free on the steady-state hot path.
    local regions = superTrackedVisualScratchRegions
    local visited = superTrackedVisualScratchVisited
    local active = superTrackedVisualScratchActive

    ClearTable(regions)
    ClearTable(visited)
    ClearTable(active)
    CollectSuperTrackedVisualRegions(superTrackedFrame, 0, visited, regions)

    local suppressed = overlay.suppressedSuperTrackedVisuals
    if type(suppressed) ~= "table" then
        suppressed = {}
        overlay.suppressedSuperTrackedVisuals = suppressed
    end

    for index = 1, #regions do
        local region = regions[index]
        if type(region.SetAlpha) == "function" and type(region.GetAlpha) == "function" then
            active[region] = true
            if suppressed[region] == nil then
                suppressed[region] = region:GetAlpha()
            end
            if region:GetAlpha() ~= 0 then
                region:SetAlpha(0)
            end
        end
    end

    for region, savedAlpha in pairs(suppressed) do
        if not active[region] then
            if region and type(region.SetAlpha) == "function" then
                region:SetAlpha(savedAlpha or 1)
            end
            suppressed[region] = nil
        end
    end

    if next(suppressed) == nil then
        overlay.suppressedSuperTrackedVisuals = nil
    end
end

local function ShouldSuppressSuperTrackedVisuals()
    local init = NS.State and NS.State.init or nil
    return init and init.playerLoggedIn == true or false
end

local function ApplySuperTrackedFrameVisibility()
    local shouldSuppress = ShouldSuppressSuperTrackedVisuals()
    local superTrackedFrame = rawget(_G, "SuperTrackedFrame")
    if overlay.lastSuppressionWanted == shouldSuppress
        and overlay.suppressedSuperTrackedVisualRootRef == superTrackedFrame
    then
        if not shouldSuppress then
            return
        end

        SuppressSuperTrackedVisuals(superTrackedFrame)
        return
    end

    -- Suppress only visual regions under SuperTrackedFrame.
    -- This hides Blizzard's marker/text without mutating whole frames or
    -- touching the nav-frame tree. Hopefully prevents further taint issues.
    RestoreSuppressedRegionSet("suppressedSuperTrackedVisuals")

    overlay.lastSuppressionWanted = shouldSuppress
    overlay.suppressedSuperTrackedVisualRootRef = shouldSuppress and superTrackedFrame or nil

    if not shouldSuppress then
        return
    end

    SuppressSuperTrackedVisuals(superTrackedFrame)
end

local function EnsureOverlayHooks()
    local superTrackedFrame = rawget(_G, "SuperTrackedFrame")
    if superTrackedFrame and not overlay.superTrackedFrameHooked then
        hooksecurefunc(superTrackedFrame, "Show", ApplySuperTrackedFrameVisibility)
        hooksecurefunc(superTrackedFrame, "SetShown", ApplySuperTrackedFrameVisibility)
        overlay.superTrackedFrameHooked = true
    end
end

-- ============================================================
-- Frame lifecycle
-- ============================================================

local function EnsureDriverRoot()
    if not overlay.driver then
        local driver = CreateFrame("Frame", "AWPWorldOverlayDriver", WorldFrame)
        driver:SetSize(1, 1)
        driver:SetPoint("TOPLEFT", WorldFrame, "TOPLEFT", 0, 0)
        driver:Hide()
        driver:SetScript("OnUpdate", function(_, elapsed)
            local churn = NS.State.churn
            if churn and churn.active then
                churn.driverUpdate = churn.driverUpdate + 1
                if derived.mode == "hidden" then
                    churn.driverUpdateHidden = churn.driverUpdateHidden + 1
                end
            end
            if transition.active or derived.mode == "pinpoint" or derived.mode == "waypoint"
                or derived.mode == "navigator" or overlay.navFadeState == "out" then
                if churn and churn.active then
                    churn.driverVisuals = churn.driverVisuals + 1
                end
                NS.UpdateNativeOverlayVisuals(elapsed)
            end
            overlay.updateElapsed = overlay.updateElapsed + elapsed
            if overlay.updateElapsed < UPDATE_INTERVAL then
                return
            end
            overlay.updateElapsed = 0
            if churn and churn.active then
                churn.nativeWorldOverlayUpdate = churn.nativeWorldOverlayUpdate + 1
            end
            NS.UpdateNativeWorldOverlay()
        end)
        overlay.driver = driver
    end

    if not overlay.root then
        local root = CreateFrame("Frame", "AWPWorldOverlayRoot", WorldFrame)
        root:SetPoint("TOPLEFT", UIParent, "TOPLEFT", 0, 0)
        root:SetPoint("BOTTOMRIGHT", UIParent, "BOTTOMRIGHT", 0, 0)
        root:Hide()
        overlay.root = root
    end

    EnsureOverlayHooks()
end

local function EnsureWaypointFrame()
    EnsureDriverRoot()
    if overlay.waypoint then
        return
    end

    local waypoint = CreateFrame("Frame", "AWPWorldOverlayWaypoint", overlay.root)
    waypoint:SetSize(WAYPOINT_CONTEXT_SIZE, WAYPOINT_CONTEXT_SIZE)
    waypoint:SetFrameStrata("HIGH")
    waypoint:SetFrameLevel(80)
    waypoint:Hide()
    waypoint.Beacon = CreateWaypointBeacon(waypoint)
    waypoint.ContextIcon = CreateContextIcon(waypoint, WAYPOINT_CONTEXT_SIZE, GetContextGlyphSize(WAYPOINT_CONTEXT_SIZE))
    waypoint.ContextIcon:SetPoint("CENTER")
    waypoint.Footer = CreateFooter(waypoint)
    waypoint.Footer:SetPoint("TOP", waypoint, "BOTTOM", 0, -1)
    overlay.waypoint = waypoint
    SetHoverHandlers(waypoint)
    ApplyOverlayAdornmentStyleToAll(true)
end

local function EnsurePinpointFrame()
    EnsureDriverRoot()
    if overlay.pinpoint then
        return
    end

    local plaqueType = NS.GetWorldOverlaySetting("worldOverlayPinpointPlaqueType") or C.WORLD_OVERLAY_PLAQUE_DEFAULT
    local plaqueSpec = Plaques.GetSpec(plaqueType)

    local pinpoint = CreateFrame("Frame", "AWPWorldOverlayPinpoint", overlay.root)
    local defaultSpec = GetDefaultPinpointPanelSpec()
    pinpoint:SetSize((plaqueSpec.minW or defaultSpec.minW),
        (plaqueSpec.baseH or defaultSpec.baseH) + PINPOINT_FRAME_EXTRA_HEIGHT)
    pinpoint:SetFrameStrata("HIGH")
    pinpoint:SetFrameLevel(80)
    pinpoint:Hide()
    pinpoint.__awpPlaqueType = plaqueType
    pinpoint.__awpPlaqueSpec = plaqueSpec
    pinpoint.Panel = Plaques.CreatePanel(pinpoint, plaqueType)
    pinpoint.Panel:SetPoint("TOP", pinpoint, "TOP", 0, 0)
    pinpoint.Panel:SetVertexColor(1, 1, 1, 0.95)
    local anim         = PlaqueAnimations.CreateAnimations(pinpoint, pinpoint.Panel, plaqueType)
    pinpoint.Gems      = anim.Gems    -- nil if plaque has no corner_gems (render.lua guards with "if frame.Gems then")
    pinpoint.Overlay   = anim.Overlay -- nil if plaque has no full_overlay (render.lua guards with "if frame.Overlay then")
    pinpoint.PanelHost = pinpoint.Panel
    pinpoint.TextHost  = CreateFrame("Frame", nil, pinpoint)
    ApplyPinpointTextHostAnchors(pinpoint)
    pinpoint.GlowTL = anim.GlowTL -- nil if plaque has no glow (render.lua guards with "if frame.GlowTL then")
    pinpoint.GlowTR = anim.GlowTR
    pinpoint.GlowBL = anim.GlowBL
    pinpoint.GlowBR = anim.GlowBR
    pinpoint.ContextIcon = CreateContextIcon(pinpoint, PINPOINT_CONTEXT_SIZE, GetContextGlyphSize(PINPOINT_CONTEXT_SIZE))
    pinpoint.ContextIcon:SetPoint("CENTER", pinpoint.Panel, "BOTTOM", 0, PINPOINT_CONTEXT_OFFSET_Y)
    local arrowSlotStep = PINPOINT_ARROW_HEIGHT - PINPOINT_ARROW_SLOT_OVERLAP
    pinpoint.ArrowGroup = CreateFrame("Frame", nil, pinpoint)
    pinpoint.ArrowGroup:SetSize(PINPOINT_ARROW_WIDTH, PINPOINT_ARROW_HEIGHT + (arrowSlotStep * 2))
    pinpoint.ArrowGroup:SetPoint("TOP", pinpoint.ContextIcon, "BOTTOM", 0, PINPOINT_ARROW_GROUP_Y)
    pinpoint.ArrowSlot1 = CreateFrame("Frame", nil, pinpoint.ArrowGroup)
    pinpoint.ArrowSlot1:SetSize(PINPOINT_ARROW_WIDTH, PINPOINT_ARROW_HEIGHT)
    pinpoint.ArrowSlot1:SetPoint("TOP", pinpoint.ArrowGroup, "TOP", 0, 0)
    pinpoint.ArrowSlot2 = CreateFrame("Frame", nil, pinpoint.ArrowGroup)
    pinpoint.ArrowSlot2:SetSize(PINPOINT_ARROW_WIDTH, PINPOINT_ARROW_HEIGHT)
    pinpoint.ArrowSlot2:SetPoint("TOP", pinpoint.ArrowSlot1, "BOTTOM", 0, PINPOINT_ARROW_SLOT_OVERLAP)
    pinpoint.ArrowSlot3 = CreateFrame("Frame", nil, pinpoint.ArrowGroup)
    pinpoint.ArrowSlot3:SetSize(PINPOINT_ARROW_WIDTH, PINPOINT_ARROW_HEIGHT)
    pinpoint.ArrowSlot3:SetPoint("TOP", pinpoint.ArrowSlot2, "BOTTOM", 0, PINPOINT_ARROW_SLOT_OVERLAP)
    pinpoint.Arrow1 = CreatePinpointArrowTexture(pinpoint.ArrowSlot1)
    pinpoint.Arrow2 = CreatePinpointArrowTexture(pinpoint.ArrowSlot2, 0.8)
    pinpoint.Arrow3 = CreatePinpointArrowTexture(pinpoint.ArrowSlot3, 0.6)
    pinpoint.Title = pinpoint.TextHost:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
    pinpoint.Title:SetPoint("TOP", pinpoint.TextHost, "TOP", 0, 0)
    pinpoint.Title:SetJustifyH("CENTER")
    pinpoint.Title:SetJustifyV("MIDDLE")
    pinpoint.Title:SetWordWrap(true)
    pinpoint.Title:SetMaxLines(PINPOINT_TITLE_MAX_LINES)
    StoreDefaultFontStringColor(pinpoint.Title)
    pinpoint.TitleMeasure = pinpoint:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
    pinpoint.TitleMeasure:SetWordWrap(false)
    pinpoint.TitleMeasure:SetMaxLines(1)
    pinpoint.TitleMeasure:Hide()
    pinpoint.Subtext = pinpoint.TextHost:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    pinpoint.Subtext:SetPoint("TOP", pinpoint.Title, "BOTTOM", 0, -PINPOINT_TEXT_GAP)
    pinpoint.Subtext:SetJustifyH("CENTER")
    pinpoint.Subtext:SetJustifyV("MIDDLE")
    pinpoint.Subtext:SetWordWrap(true)
    pinpoint.Subtext:SetMaxLines(PINPOINT_SUBTEXT_MAX_LINES)
    StoreDefaultFontStringColor(pinpoint.Subtext)
    pinpoint.SubtextMeasure = pinpoint:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    pinpoint.SubtextMeasure:SetWordWrap(false)
    pinpoint.SubtextMeasure:SetMaxLines(1)
    pinpoint.SubtextMeasure:Hide()
    pinpoint.HitArea = CreateFrame("Frame", nil, pinpoint)
    pinpoint.HitArea:SetPoint("TOPLEFT", pinpoint.Panel, "TOPLEFT", 18, -4)
    pinpoint.HitArea:SetPoint("TOPRIGHT", pinpoint.Panel, "TOPRIGHT", -18, -4)
    pinpoint.HitArea:SetPoint("BOTTOM", pinpoint.ArrowGroup, "BOTTOM", 0, 2)
    overlay.pinpoint = pinpoint
    SetHoverHandlers(pinpoint.HitArea)
    ApplyOverlayAdornmentStyleToAll(true)
end

local function EnsureNavigatorFrame()
    EnsureDriverRoot()
    if overlay.navigator then
        return
    end

    local navigator = CreateFrame("Frame", "AWPWorldOverlayNavigator", overlay.root)
    navigator:SetSize(NAVIGATOR_CONTEXT_SIZE, NAVIGATOR_CONTEXT_SIZE)
    navigator:SetFrameStrata("HIGH")
    navigator:SetFrameLevel(80)
    navigator:SetClampedToScreen(true)
    navigator:Hide()
    navigator.ContextIcon = CreateContextIcon(navigator, NAVIGATOR_CONTEXT_SIZE,
        GetContextGlyphSize(NAVIGATOR_CONTEXT_SIZE))
    navigator.ContextIcon:SetPoint("CENTER")
    navigator.Arrow = navigator:CreateTexture(nil, "ARTWORK")
    navigator.Arrow:SetTexture(NAVIGATOR_ARROW_TEXTURE)
    navigator.Arrow:SetTexCoord(unpackCoords(NAVIGATOR_ARROW_TEX_COORDS))
    navigator.Arrow:SetSize(NAVIGATOR_ARROW_WIDTH, NAVIGATOR_ARROW_HEIGHT)
    navigator.Arrow:SetPoint("CENTER")
    overlay.navigator = navigator
    SetHoverHandlers(navigator)
    ApplyOverlayAdornmentStyleToAll(true)
end

local function EnsureFrames()
    EnsureDriverRoot()
    EnsureWaypointFrame()
    EnsurePinpointFrame()
    EnsureNavigatorFrame()
    ApplyOverlayAdornmentStyleToAll(true)
end

local function HideAllFrames()
    if overlay.waypoint then overlay.waypoint:Hide() end
    if overlay.pinpoint then overlay.pinpoint:Hide() end
    if overlay.navigator then overlay.navigator:Hide() end
    M.frameCacheDirty = true
end

local function ResetFrameTextCaches()
    if overlay.waypoint and overlay.waypoint.Footer then
        local footer = overlay.waypoint.Footer
        footer.__awpDistanceUnitKey = nil
        footer.__awpDistanceValueKey = nil
        footer.__awpArrivalSecondsKey = nil
        if footer.InfoText then fontStringTextCache[footer.InfoText] = nil end
        if footer.DistanceText then fontStringTextCache[footer.DistanceText] = nil end
        if footer.ArrivalTimeText then fontStringTextCache[footer.ArrivalTimeText] = nil end
    end

    if overlay.pinpoint then
        overlay.pinpoint.__awpTitleText = nil
        overlay.pinpoint.__awpSubtextText = nil
    end
end

local function ShowFrameSet(showWaypoint, showPinpoint, showNavigator)
    if overlay.root then
        local shouldShowRoot = showWaypoint or showPinpoint or showNavigator
        if shouldShowRoot and not overlay.root:IsShown() then
            overlay.root:Show()
        elseif not shouldShowRoot and overlay.root:IsShown() then
            overlay.root:Hide()
        end
    end

    if overlay.waypoint and overlay.waypoint:IsShown() ~= showWaypoint then overlay.waypoint:SetShown(showWaypoint) end
    if overlay.pinpoint and overlay.pinpoint:IsShown() ~= showPinpoint then overlay.pinpoint:SetShown(showPinpoint) end
    if overlay.navigator and overlay.navigator:IsShown() ~= showNavigator then overlay.navigator:SetShown(showNavigator) end
end

local function ShowOnlyFrame(frameToShow)
    ShowFrameSet(
        overlay.waypoint and overlay.waypoint == frameToShow or false,
        overlay.pinpoint and overlay.pinpoint == frameToShow or false,
        overlay.navigator and overlay.navigator == frameToShow or false
    )
end

local function ResetModeTransition(mode)
    transition.active = false
    transition.fromMode = mode or "hidden"
    transition.toMode = mode or "hidden"
    transition.elapsed = 0
    transition.duration = 0
end

M.CreateContextIcon = CreateContextIcon
M.CreateWaypointBeacon = CreateWaypointBeacon
M.GetContextGlyphSize = GetContextGlyphSize
M.GetContextGlyphDisplaySize = GetContextGlyphDisplaySize
M.ApplyContextIconStyle = ApplyContextIconStyle
M.ApplyContextIconStyleToAll = ApplyContextIconStyleToAll
M.ApplyPinpointArrowVisibility = ApplyPinpointArrowVisibility
M.ApplyOverlayAdornmentStyleToAll = ApplyOverlayAdornmentStyleToAll
M.SetContextIconSpec = SetContextIconSpec
M.GetPinpointTextMetrics = GetPinpointTextMetrics
M.LayoutPinpointText = LayoutPinpointText
M.SetHoverHandlers = SetHoverHandlers
M.CreateFooter = CreateFooter
M.ApplySuperTrackedFrameVisibility = ApplySuperTrackedFrameVisibility
M.EnsureDriverRoot = EnsureDriverRoot
M.EnsureWaypointFrame = EnsureWaypointFrame
M.EnsurePinpointFrame = EnsurePinpointFrame
M.EnsureNavigatorFrame = EnsureNavigatorFrame
M.EnsureFrames = EnsureFrames
M.HideAllFrames = HideAllFrames

-- Swaps the pinpoint plaque type in-place with no frame recreation.
-- Updates all 9 panel slice textures, gem textures, and glow textures
-- to match the new plaque spec. No WoW frames are created or orphaned.
M.SwapPinpointPlaqueType = function(plaqueType)
    local pinpoint = overlay.pinpoint
    if not pinpoint or not pinpoint.Panel then return end
    if pinpoint.__awpPlaqueType == plaqueType then return end
    plaqueType = plaqueType or C.WORLD_OVERLAY_PLAQUE_DEFAULT
    Plaques.UpdatePanel(pinpoint.Panel, plaqueType)
    pinpoint.__awpPlaqueSpec = pinpoint.Panel.__awpPlaqueSpec or Plaques.GetSpec(plaqueType)
    ApplyPinpointTextHostAnchors(pinpoint)
    local updated            = PlaqueAnimations.UpdateAnimations(pinpoint, pinpoint.Panel, plaqueType)
    pinpoint.Gems            = updated.Gems
    pinpoint.GlowTL          = updated.GlowTL
    pinpoint.GlowTR          = updated.GlowTR
    pinpoint.GlowBL          = updated.GlowBL
    pinpoint.GlowBR          = updated.GlowBR
    pinpoint.Overlay         = updated.Overlay
    pinpoint.__awpPlaqueType = plaqueType

    local frameCache = M.frameCache and M.frameCache.pinpoint
    if frameCache then
        frameCache.panelWidth = nil
        frameCache.layoutWidth = nil
    end

    M.frameCacheDirty        = true
end
M.ResetFrameTextCaches = ResetFrameTextCaches
M.ShowOnlyFrame = ShowOnlyFrame
M.ShowFrameSet = ShowFrameSet
M.ResetModeTransition = ResetModeTransition
M.EnsureOverlayHooks = EnsureOverlayHooks
