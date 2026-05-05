local NS = _G.AzerothWaypointNS

NS.Internal = NS.Internal or {}
NS.Internal.Interface = NS.Internal.Interface or {}
NS.Internal.Interface.Framework = NS.Internal.Interface.Framework or {}

local M = NS.Internal.Interface.Framework

local CreateFrame = _G.CreateFrame
local GameTooltip = _G.GameTooltip
local UIParent = _G.UIParent

---@diagnostic disable: need-check-nil, undefined-field

M.COLORS = M.COLORS or {
    mainBg = { 0.025, 0.020, 0.016, 0.97 },
    titleBg = { 0.055, 0.040, 0.030, 0.96 },
    footerBg = { 0.040, 0.030, 0.024, 0.96 },
    outerBorder = { 0.62, 0.45, 0.18, 0.72 },
    titleSeparator = { 1.00, 0.82, 0.08, 0.45 },
    footerSeparator = { 0.52, 0.35, 0.16, 0.55 },
    buttonBg = { 0.045, 0.033, 0.025, 0.95 },
    buttonBorder = { 0.62, 0.42, 0.18, 0.45 },
    buttonInset = { 0.020, 0.016, 0.014, 0.92 },
    buttonInsetHover = { 0.090, 0.060, 0.030, 0.95 },
    buttonInsetDisabled = { 0.015, 0.012, 0.010, 0.70 },
    buttonTextDisabled = { 0.35, 0.30, 0.24, 0.45 },
    closeBg = { 0, 0, 0, 0 },
    closeBgHover = { 0.50, 0.15, 0.10, 0.35 },
    closeText = { 0.72, 0.66, 0.58, 0.85 },
    closeTextHover = { 1.00, 0.82, 0.00, 1.00 },
    scrollThumb = { 0.88, 0.78, 0.58, 0.95 },
    scrollTrack = { 0, 0, 0, 0.52 },
}

local function ResolveColor(keyOrColor, fallback)
    if type(keyOrColor) == "table" then
        return keyOrColor
    elseif type(keyOrColor) == "string" and type(M.COLORS[keyOrColor]) == "table" then
        return M.COLORS[keyOrColor]
    end
    return fallback
end

local function GetPixelSize(frame, pixels)
    pixels = tonumber(pixels) or 1

    local scale = 1
    if frame and type(frame.GetEffectiveScale) == "function" then
        scale = frame:GetEffectiveScale() or scale
    elseif UIParent and type(UIParent.GetEffectiveScale) == "function" then
        scale = UIParent:GetEffectiveScale() or scale
    end

    if scale <= 0 then
        scale = 1
    end

    return pixels / scale
end

function M.ColorTexture(texture, color)
    if not texture or type(texture.SetColorTexture) ~= "function" then
        return
    end
    color = ResolveColor(color, M.COLORS.mainBg)
    texture:SetColorTexture(color[1] or 1, color[2] or 1, color[3] or 1, color[4] or 1)
end

local function ApplyOuterBorder(frame, color, pixels)
    local holder = CreateFrame("Frame", nil, frame)
    holder:SetAllPoints(frame)
    holder:EnableMouse(false)
    if type(frame.GetFrameLevel) == "function" and type(holder.SetFrameLevel) == "function" then
        holder:SetFrameLevel((frame:GetFrameLevel() or 0) + 50)
    end

    local thickness = GetPixelSize(frame, pixels or 1)

    local function MakeBorder(pointA, pointB, horizontal)
        local border = holder:CreateTexture(nil, "OVERLAY")
        border:SetPoint(pointA, holder, pointA, 0, 0)
        border:SetPoint(pointB, holder, pointB, 0, 0)
        if horizontal then
            border:SetHeight(thickness)
        else
            border:SetWidth(thickness)
        end
        M.ColorTexture(border, color)
        return border
    end

    return {
        holder = holder,
        top = MakeBorder("TOPLEFT", "TOPRIGHT", true),
        bottom = MakeBorder("BOTTOMLEFT", "BOTTOMRIGHT", true),
        left = MakeBorder("TOPLEFT", "BOTTOMLEFT", false),
        right = MakeBorder("TOPRIGHT", "BOTTOMRIGHT", false),
    }
end

local function ConfigureTitleText(titleFrame, opts)
    local titleText = titleFrame:CreateFontString(nil, "OVERLAY", opts.titleFontObject or "GameFontNormalLarge")
    if opts.titleLeftInset or opts.titleRightInset then
        titleText:SetPoint("LEFT", titleFrame, "LEFT", opts.titleLeftInset or 0, 0)
        titleText:SetPoint("RIGHT", titleFrame, "RIGHT", -(opts.titleRightInset or 0), 0)
    else
        titleText:SetPoint("CENTER", titleFrame, "CENTER", 0, opts.titleOffsetY or 0)
    end
    titleText:SetJustifyH("CENTER")
    if opts.titleColor then
        local color = ResolveColor(opts.titleColor, M.COLORS.closeTextHover)
        titleText:SetTextColor(color[1], color[2], color[3], color[4] or 1)
    end
    titleText:SetText(opts.title or "")

    if opts.versionText and opts.versionText ~= "" then
        local versionText = titleFrame:CreateFontString(nil, "OVERLAY", opts.versionFontObject or "GameFontDisableSmall")
        versionText:SetPoint("LEFT", titleText, "RIGHT", opts.versionGap or 10, opts.versionOffsetY or 0)
        versionText:SetText(opts.versionText)
        titleFrame.versionText = versionText
    end

    return titleText
end

local function CreateCloseButton(titleFrame, opts)
    local closeButton = CreateFrame("Button", nil, titleFrame)
    closeButton:SetSize(opts.closeSize or 24, opts.closeSize or 24)
    closeButton:SetPoint("RIGHT", titleFrame, "RIGHT", opts.closeOffsetX or -10, opts.closeOffsetY or 0)
    closeButton:SetFrameLevel(titleFrame:GetFrameLevel() + 2)

    closeButton.bg = closeButton:CreateTexture(nil, "BACKGROUND")
    closeButton.bg:SetAllPoints()
    M.ColorTexture(closeButton.bg, opts.closeBg or M.COLORS.closeBg)

    if opts.closeBorder then
        closeButton.border = closeButton:CreateTexture(nil, "BORDER")
        closeButton.border:SetPoint("TOPLEFT", closeButton, "TOPLEFT", 1, -1)
        closeButton.border:SetPoint("BOTTOMRIGHT", closeButton, "BOTTOMRIGHT", -1, 1)
        M.ColorTexture(closeButton.border, opts.closeBorderColor or M.COLORS.footerSeparator)
    end

    closeButton.label = closeButton:CreateFontString(nil, "OVERLAY", opts.closeFontObject or "GameFontNormalLarge")
    closeButton.label:SetPoint("CENTER", closeButton, "CENTER", 0, opts.closeLabelOffsetY or 0)
    closeButton.label:SetText(opts.closeText or "X")
    local closeColor = ResolveColor(opts.closeTextColor, M.COLORS.closeText)
    closeButton.label:SetTextColor(closeColor[1], closeColor[2], closeColor[3], closeColor[4] or 1)

    closeButton:SetScript("OnEnter", function(self)
        local hoverColor = ResolveColor(opts.closeTextHoverColor, M.COLORS.closeTextHover)
        self.label:SetTextColor(hoverColor[1], hoverColor[2], hoverColor[3], hoverColor[4] or 1)
        M.ColorTexture(self.bg, opts.closeBgHover or M.COLORS.closeBgHover)
        if opts.closeTooltip ~= false and GameTooltip then
            GameTooltip:SetOwner(self, opts.closeTooltipAnchor or "ANCHOR_LEFT")
            GameTooltip:SetText(opts.closeTooltipText or "Close", 1, 1, 1)
            GameTooltip:Show()
        end
    end)
    closeButton:SetScript("OnLeave", function(self)
        local color = ResolveColor(opts.closeTextColor, M.COLORS.closeText)
        self.label:SetTextColor(color[1], color[2], color[3], color[4] or 1)
        M.ColorTexture(self.bg, opts.closeBg or M.COLORS.closeBg)
        if GameTooltip then
            GameTooltip:Hide()
        end
    end)
    closeButton:SetScript("OnClick", opts.onClose or function()
        local owner = opts.closeOwner or titleFrame:GetParent()
        if owner and type(owner.Hide) == "function" then
            owner:Hide()
        end
    end)

    return closeButton
end

function M.CreatePanelShell(frame, opts)
    opts = type(opts) == "table" and opts or {}

    if opts.toplevel ~= false and type(frame.SetToplevel) == "function" then
        frame:SetToplevel(true)
    end
    if opts.raiseOnMouseDown ~= false and type(frame.SetScript) == "function" then
        frame:SetScript("OnMouseDown", function(self)
            if type(self.Raise) == "function" then
                self:Raise()
            end
        end)
    end

    local mainBg = frame:CreateTexture(nil, "BACKGROUND", nil, -4)
    mainBg:SetAllPoints()
    M.ColorTexture(mainBg, opts.backgroundColor or M.COLORS.mainBg)

    local borders = ApplyOuterBorder(frame, opts.outerBorderColor or M.COLORS.outerBorder, opts.outerBorderPixels)

    local titleFrame = CreateFrame("Frame", nil, frame)
    titleFrame:SetPoint("TOPLEFT", frame, "TOPLEFT", 1, -1)
    titleFrame:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -1, -1)
    titleFrame:SetHeight(opts.titleHeight or 44)
    if opts.movable then
        local dragTarget = opts.dragTarget or frame
        titleFrame:EnableMouse(true)
        titleFrame:RegisterForDrag("LeftButton")
        titleFrame:SetScript("OnMouseDown", function()
            if type(dragTarget.Raise) == "function" then
                dragTarget:Raise()
            end
        end)
        titleFrame:SetScript("OnDragStart", function()
            if type(dragTarget.StartMoving) == "function" then
                dragTarget:StartMoving()
            end
        end)
        titleFrame:SetScript("OnDragStop", function()
            if type(dragTarget.StopMovingOrSizing) == "function" then
                dragTarget:StopMovingOrSizing()
            end
        end)
    end

    local titleBg = titleFrame:CreateTexture(nil, "BACKGROUND")
    titleBg:SetAllPoints()
    M.ColorTexture(titleBg, opts.titleBgColor or M.COLORS.titleBg)

    local titleSeparator = titleFrame:CreateTexture(nil, "ARTWORK")
    titleSeparator:SetPoint("BOTTOMLEFT", titleFrame, "BOTTOMLEFT", 0, 0)
    titleSeparator:SetPoint("BOTTOMRIGHT", titleFrame, "BOTTOMRIGHT", 0, 0)
    titleSeparator:SetHeight(1)
    M.ColorTexture(titleSeparator, opts.titleSeparatorColor or M.COLORS.titleSeparator)

    local footerFrame = CreateFrame("Frame", nil, frame)
    footerFrame:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", 1, 1)
    footerFrame:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -1, 1)
    footerFrame:SetHeight(opts.footerHeight or 44)

    local footerBg = footerFrame:CreateTexture(nil, "BACKGROUND")
    footerBg:SetAllPoints()
    M.ColorTexture(footerBg, opts.footerBgColor or M.COLORS.footerBg)

    local footerSeparator = footerFrame:CreateTexture(nil, "ARTWORK")
    footerSeparator:SetPoint("TOPLEFT", footerFrame, "TOPLEFT", 0, 0)
    footerSeparator:SetPoint("TOPRIGHT", footerFrame, "TOPRIGHT", 0, 0)
    footerSeparator:SetHeight(1)
    M.ColorTexture(footerSeparator, opts.footerSeparatorColor or M.COLORS.footerSeparator)

    local bodyFrame = CreateFrame("Frame", nil, frame)
    bodyFrame:SetPoint("TOPLEFT", titleFrame, "BOTTOMLEFT", 0, opts.bodyTopOffset or 0)
    bodyFrame:SetPoint("BOTTOMRIGHT", footerFrame, "TOPRIGHT", 0, opts.bodyBottomOffset or 0)

    local titleText = ConfigureTitleText(titleFrame, opts)
    local closeButton = nil
    if opts.closeButton ~= false then
        opts.closeOwner = opts.closeOwner or frame
        closeButton = CreateCloseButton(titleFrame, opts)
    end

    return {
        frame = frame,
        mainBg = mainBg,
        borders = borders,
        titleFrame = titleFrame,
        titleBg = titleBg,
        titleSeparator = titleSeparator,
        titleText = titleText,
        footerFrame = footerFrame,
        footerBg = footerBg,
        footerSeparator = footerSeparator,
        bodyFrame = bodyFrame,
        closeButton = closeButton,
    }
end

function M.CreatePanelButton(parent, opts)
    opts = type(opts) == "table" and opts or {}

    local button = CreateFrame("Button", nil, parent)
    button:SetHeight(opts.height or 24)

    button.bg = button:CreateTexture(nil, "BACKGROUND")
    button.bg:SetAllPoints()
    M.ColorTexture(button.bg, opts.bgColor or M.COLORS.buttonBg)

    button.border = button:CreateTexture(nil, "BORDER")
    button.border:SetAllPoints()
    M.ColorTexture(button.border, opts.borderColor or M.COLORS.buttonBorder)

    button.inset = button:CreateTexture(nil, "ARTWORK")
    button.inset:SetPoint("TOPLEFT", button, "TOPLEFT", 1, -1)
    button.inset:SetPoint("BOTTOMRIGHT", button, "BOTTOMRIGHT", -1, 1)
    M.ColorTexture(button.inset, opts.insetColor or M.COLORS.buttonInset)

    button.label = button:CreateFontString(nil, "OVERLAY", opts.fontObject or "GameFontHighlightSmall")
    button.label:SetPoint("LEFT", button, "LEFT", opts.labelInsetLeft or 9, 0)
    button.label:SetPoint("RIGHT", button, "RIGHT", -(opts.labelInsetRight or 9), 0)
    button.label:SetJustifyH(opts.justifyH or "CENTER")

    button:SetScript("OnEnter", function(self)
        if self:IsEnabled() then
            M.ColorTexture(self.inset, opts.hoverInsetColor or M.COLORS.buttonInsetHover)
        end
    end)
    button:SetScript("OnLeave", function(self)
        M.ColorTexture(self.inset, opts.insetColor or M.COLORS.buttonInset)
    end)
    button:SetScript("OnDisable", function(self)
        if self.label and type(self.label.SetTextColor) == "function" then
            local color = ResolveColor(opts.disabledTextColor, M.COLORS.buttonTextDisabled)
            self.label:SetTextColor(color[1], color[2], color[3], color[4] or 1)
        end
        M.ColorTexture(self.inset, opts.disabledInsetColor or M.COLORS.buttonInsetDisabled)
    end)
    button:SetScript("OnEnable", function(self)
        if self.label and type(self.label.SetTextColor) == "function" then
            self.label:SetTextColor(1, 1, 1, 1)
        end
        M.ColorTexture(self.inset, opts.insetColor or M.COLORS.buttonInset)
    end)

    function button:SetDisplayText(text)
        self.label:SetText(text or "")
    end

    return button
end

local function ResolveScrollBar(scrollFrame)
    if type(scrollFrame) ~= "table" then
        return nil
    end
    if type(scrollFrame.ScrollBar) == "table" then
        return scrollFrame.ScrollBar
    end

    local name = type(scrollFrame.GetName) == "function" and scrollFrame:GetName() or nil
    if type(name) == "string" and _G[name .. "ScrollBar"] then
        return _G[name .. "ScrollBar"]
    end

    if type(scrollFrame.GetChildren) == "function" then
        local children = { scrollFrame:GetChildren() }
        for index = 1, #children do
            local child = children[index]
            if type(child) == "table"
                and type(child.SetValue) == "function"
                and type(child.GetMinMaxValues) == "function"
            then
                return child
            end
        end
    end

    return nil
end

local function HideScrollButton(scrollBar, key)
    local button = scrollBar and scrollBar[key]
    local name = type(scrollBar.GetName) == "function" and scrollBar:GetName() or nil
    if not button and type(name) == "string" then
        button = _G[name .. key]
    end
    if type(button) == "table" and type(button.Hide) == "function" then
        button:Hide()
        if type(button.SetAlpha) == "function" then button:SetAlpha(0) end
        if type(button.EnableMouse) == "function" then button:EnableMouse(false) end
    end
end

function M.StyleScrollBar(scrollFrame, opts)
    opts = type(opts) == "table" and opts or {}

    local scrollBar = ResolveScrollBar(scrollFrame)
    if not scrollBar then
        return nil
    end

    HideScrollButton(scrollBar, "ScrollUpButton")
    HideScrollButton(scrollBar, "ScrollDownButton")
    HideScrollButton(scrollBar, "UpButton")
    HideScrollButton(scrollBar, "DownButton")
    HideScrollButton(scrollBar, "DecrementButton")
    HideScrollButton(scrollBar, "IncrementButton")

    local thumb = type(scrollBar.GetThumbTexture) == "function" and scrollBar:GetThumbTexture() or nil
    if type(scrollBar.SetThumbTexture) == "function" then
        scrollBar:SetThumbTexture("Interface\\Buttons\\WHITE8X8")
        thumb = type(scrollBar.GetThumbTexture) == "function" and scrollBar:GetThumbTexture() or thumb
    end
    if type(thumb) == "table" and type(thumb.SetTexture) == "function" then
        thumb:SetTexture("Interface\\Buttons\\WHITE8X8")
        local thumbColor = ResolveColor(opts.thumbColor, M.COLORS.scrollThumb)
        thumb:SetVertexColor(thumbColor[1], thumbColor[2], thumbColor[3], thumbColor[4] or 1)
        if type(thumb.SetWidth) == "function" then thumb:SetWidth(opts.thumbWidth or 5) end
    end

    if type(scrollBar.GetRegions) == "function" then
        local regions = { scrollBar:GetRegions() }
        for index = 1, #regions do
            local region = regions[index]
            if region ~= thumb and type(region) == "table" and type(region.SetAlpha) == "function" then
                region:SetAlpha(0)
            end
        end
    end

    if not scrollBar.awpTrack then
        scrollBar.awpTrack = scrollBar:CreateTexture(nil, "BACKGROUND")
    end
    M.ColorTexture(scrollBar.awpTrack, opts.trackColor or M.COLORS.scrollTrack)
    scrollBar.awpTrack:ClearAllPoints()
    scrollBar.awpTrack:SetPoint("TOP", scrollBar, "TOP", 0, -(opts.trackInsetTop or 4))
    scrollBar.awpTrack:SetPoint("BOTTOM", scrollBar, "BOTTOM", 0, opts.trackInsetBottom or 4)
    scrollBar.awpTrack:SetWidth(opts.trackWidth or 2)

    if opts.anchorTo then
        scrollBar:ClearAllPoints()
        scrollBar:SetPoint("TOPRIGHT", opts.anchorTo, "TOPRIGHT", opts.offsetX or -6, opts.topOffsetY or -9)
        scrollBar:SetPoint("BOTTOMRIGHT", opts.anchorTo, "BOTTOMRIGHT", opts.offsetX or -6, opts.bottomOffsetY or 9)
        scrollBar:SetWidth(opts.width or 6)
    elseif opts.width then
        scrollBar:SetWidth(opts.width)
    end

    if type(scrollBar.SetHitRectInsets) == "function" and opts.hitRect ~= false then
        local hit = opts.hitRectInsets or { -6, -6, 0, 0 }
        scrollBar:SetHitRectInsets(hit[1] or 0, hit[2] or 0, hit[3] or 0, hit[4] or 0)
    end
    if type(scrollBar.SetHideIfUnscrollable) == "function" then
        scrollBar:SetHideIfUnscrollable(true)
    end

    return scrollBar
end
