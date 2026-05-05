local NS = _G.AzerothWaypointNS
local FW = NS.Internal.Interface.Framework

local frame

local FRAME_WIDTH = 880
local FRAME_HEIGHT = 660
local DEFAULT_CONTENT_WIDTH = 740
local CONTENT_TOP_PADDING = 12
local CONTENT_BOTTOM_PADDING = 16
local CONTENT_RIGHT_PADDING = 10
local SCROLL_STEP = 48
local BLOCK_SPACING      = 16
local IMAGE_GAP          = 12
local BODY_INDENT        = 14

local HEADING_LINE_R, HEADING_LINE_G, HEADING_LINE_B, HEADING_LINE_A = 1.0, 0.82, 0.08, 0.38
local HEADING_GLOW_ATLAS = "AftLevelup-GlowLine"
local HEADING_GLOW_W     = 322
local HEADING_GLOW_H     = 18
local PAGE_GLOW_W        = 360
local PAGE_GLOW_H        = 20
local PAGE_INTRO_PAD_X   = 16
local PAGE_INTRO_PAD_Y   = 10
local PAGE_INTRO_BG      = { 0.050, 0.040, 0.026, 0.72 }
local PAGE_INTRO_BORDER  = { 1.000, 0.820, 0.080, 0.22 }

local NOTE_BG_R,     NOTE_BG_G,     NOTE_BG_B,     NOTE_BG_A     = 0.08, 0.10, 0.15, 0.92
local NOTE_ACCENT_R, NOTE_ACCENT_G, NOTE_ACCENT_B, NOTE_ACCENT_A = 0.38, 0.62, 0.90, 0.88
local NOTE_ACCENT_WIDTH = 3
local NOTE_PAD_X        = 10
local NOTE_PAD_Y        = 7
local FRAME_TITLE = "AzerothWaypoint Help"
local ChangelogFormat = NS.ChangelogFormat or {}

local TEXT_STYLES = {
    heading = {
        fontObject = "GameFontNormal",
        justifyH = "CENTER",
        justifyV = "TOP",
        spacing = 2,
        color = { 1.0, 0.85, 0.1, 1.0 },
    },
    body = {
        fontObject = "GameFontHighlight",
        justifyH = "LEFT",
        justifyV = "TOP",
        spacing = 3,
    },
    intro = {
        fontObject = "GameFontHighlight",
        justifyH = "LEFT",
        justifyV = "TOP",
        spacing = 3,
    },
    note = {
        fontObject = "GameFontHighlightSmall",
        justifyH = "LEFT",
        justifyV = "TOP",
        spacing = 2,
        color = { 0.82, 0.84, 0.88, 1.0 },
    },
    caption = {
        fontObject = "GameFontHighlightSmall",
        justifyH = "CENTER",
        justifyV = "TOP",
        spacing = 2,
        color = { 0.82, 0.84, 0.88, 1.0 },
    },
}

local function Clamp(value, minimum, maximum)
    if value < minimum then
        return minimum
    end
    if value > maximum then
        return maximum
    end
    return value
end

local function GetHelpPages()
    local pages = NS.HELP_PAGES
    if type(pages) ~= "table" then
        return {}
    end
    return pages
end

local function GetPageIndex(pageRef)
    local pages = GetHelpPages()
    if #pages == 0 then
        return nil
    end

    if type(pageRef) == "number" then
        if pageRef >= 1 and pageRef <= #pages then
            return pageRef
        end
        return 1
    end

    if type(pageRef) == "string" and pageRef ~= "" then
        local needle = pageRef:lower()
        for index, page in ipairs(pages) do
            if type(page) == "table" and type(page.id) == "string" and page.id:lower() == needle then
                return index
            end
        end
    end

    return 1
end

local function FormatRecentChangelogText(limit)
    if type(ChangelogFormat.FormatReleaseText) == "function" then
        return ChangelogFormat.FormatReleaseText(NS.CHANGELOG_DATA, limit or 3)
    end

    return "No changelog data available."
end

local function ResetPool(pool)
    for _, widget in ipairs(pool) do
        widget:Hide()
    end
    pool.nextIndex = 1
end

local function AcquireText(frameRef)
    local pool = frameRef.textPool
    local index = pool.nextIndex
    local widget = pool[index]
    if not widget then
        widget = frameRef.content:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
        widget:SetJustifyH("LEFT")
        widget:SetJustifyV("TOP")
        widget:SetWordWrap(true)
        pool[index] = widget
    end
    pool.nextIndex = index + 1
    widget:Show()
    return widget
end

local function CreateDivider(parent)
    local divider = parent:CreateTexture(nil, "ARTWORK")
    divider:SetHeight(1)
    divider:SetColorTexture(1, 1, 1, 0.12)
    return divider
end

local function AcquireDivider(frameRef)
    local pool = frameRef.dividerPool
    local index = pool.nextIndex
    local widget = pool[index]
    if not widget then
        widget = CreateDivider(frameRef.content)
        pool[index] = widget
    end
    pool.nextIndex = index + 1
    widget:Show()
    return widget
end

local function CreateImageBlock(parent)
    local wrapper = CreateFrame("Frame", nil, parent)

    wrapper.canvas = CreateFrame("Frame", nil, wrapper)
    wrapper.canvas:SetPoint("TOPLEFT", wrapper, "TOPLEFT", 0, 0)

    wrapper.background = wrapper.canvas:CreateTexture(nil, "BACKGROUND")
    wrapper.background:SetAllPoints()
    wrapper.background:SetColorTexture(0.07, 0.07, 0.07, 0.92)

    wrapper.texture = wrapper.canvas:CreateTexture(nil, "ARTWORK")
    wrapper.texture:SetAllPoints()

    wrapper.placeholder = wrapper.canvas:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
    wrapper.placeholder:SetPoint("CENTER", wrapper.canvas, "CENTER", 0, 0)
    wrapper.placeholder:SetJustifyH("CENTER")
    wrapper.placeholder:SetJustifyV("MIDDLE")
    wrapper.placeholder:SetWordWrap(true)

    wrapper.borderTop = wrapper.canvas:CreateTexture(nil, "BORDER")
    wrapper.borderTop:SetColorTexture(1, 1, 1, 0.16)
    wrapper.borderBottom = wrapper.canvas:CreateTexture(nil, "BORDER")
    wrapper.borderBottom:SetColorTexture(1, 1, 1, 0.16)
    wrapper.borderLeft = wrapper.canvas:CreateTexture(nil, "BORDER")
    wrapper.borderLeft:SetColorTexture(1, 1, 1, 0.16)
    wrapper.borderRight = wrapper.canvas:CreateTexture(nil, "BORDER")
    wrapper.borderRight:SetColorTexture(1, 1, 1, 0.16)

    wrapper.caption = wrapper:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    wrapper.caption:SetPoint("TOPLEFT", wrapper.canvas, "BOTTOMLEFT", 0, -6)
    wrapper.caption:SetPoint("TOPRIGHT", wrapper.canvas, "BOTTOMRIGHT", 0, -6)
    wrapper.caption:SetJustifyH("CENTER")
    wrapper.caption:SetJustifyV("TOP")
    wrapper.caption:SetWordWrap(true)

    return wrapper
end

local function ApplyImageBlockData(blockFrame, data)
    local width = tonumber(data.width) or 320
    local height = tonumber(data.height) or 180
    local caption = tostring(data.caption or "")
    local placeholder = tostring(data.placeholder or "Image placeholder")

    blockFrame.canvas:SetSize(width, height)
    blockFrame.canvas:ClearAllPoints()
    blockFrame.canvas:SetPoint("TOPLEFT", blockFrame, "TOPLEFT", 0, 0)

    blockFrame.placeholder:SetWidth(math.max(width - 24, 80))
    blockFrame.placeholder:SetText(placeholder)

    blockFrame.borderTop:SetPoint("TOPLEFT", blockFrame.canvas, "TOPLEFT", 0, 0)
    blockFrame.borderTop:SetPoint("TOPRIGHT", blockFrame.canvas, "TOPRIGHT", 0, 0)
    blockFrame.borderTop:SetHeight(1)

    blockFrame.borderBottom:SetPoint("BOTTOMLEFT", blockFrame.canvas, "BOTTOMLEFT", 0, 0)
    blockFrame.borderBottom:SetPoint("BOTTOMRIGHT", blockFrame.canvas, "BOTTOMRIGHT", 0, 0)
    blockFrame.borderBottom:SetHeight(1)

    blockFrame.borderLeft:SetPoint("TOPLEFT", blockFrame.canvas, "TOPLEFT", 0, 0)
    blockFrame.borderLeft:SetPoint("BOTTOMLEFT", blockFrame.canvas, "BOTTOMLEFT", 0, 0)
    blockFrame.borderLeft:SetWidth(1)

    blockFrame.borderRight:SetPoint("TOPRIGHT", blockFrame.canvas, "TOPRIGHT", 0, 0)
    blockFrame.borderRight:SetPoint("BOTTOMRIGHT", blockFrame.canvas, "BOTTOMRIGHT", 0, 0)
    blockFrame.borderRight:SetWidth(1)

    local frameless = data.frameless == true or data.frame == false or data.border == false
    if frameless then
        blockFrame.background:SetColorTexture(0, 0, 0, 0)
        blockFrame.borderTop:Hide()
        blockFrame.borderBottom:Hide()
        blockFrame.borderLeft:Hide()
        blockFrame.borderRight:Hide()
    else
        blockFrame.borderTop:Show()
        blockFrame.borderBottom:Show()
        blockFrame.borderLeft:Show()
        blockFrame.borderRight:Show()
    end

    if type(data.texture) == "string" and data.texture ~= "" then
        blockFrame.texture:SetTexture(data.texture)
        if type(data.texCoord) == "table" then
            blockFrame.texture:SetTexCoord(unpack(data.texCoord))
        else
            blockFrame.texture:SetTexCoord(0, 1, 0, 1)
        end
        blockFrame.texture:Show()
        blockFrame.placeholder:Hide()
    else
        blockFrame.texture:SetTexture(nil)
        blockFrame.texture:Hide()
        blockFrame.placeholder:Show()
    end

    if frameless then
        blockFrame.background:SetColorTexture(0, 0, 0, 0)
    elseif type(data.backgroundColor) == "table" then
        blockFrame.background:SetColorTexture(
            tonumber(data.backgroundColor.r or data.backgroundColor[1]) or 0.07,
            tonumber(data.backgroundColor.g or data.backgroundColor[2]) or 0.07,
            tonumber(data.backgroundColor.b or data.backgroundColor[3]) or 0.07,
            tonumber(data.backgroundColor.a or data.backgroundColor[4]) or 0.92
        )
    else
        blockFrame.background:SetColorTexture(0.07, 0.07, 0.07, 0.92)
    end

    blockFrame.caption:SetText(caption)
    local captionHeight = 0
    if caption ~= "" then
        blockFrame.caption:Show()
        captionHeight = math.ceil(blockFrame.caption:GetStringHeight() or blockFrame.caption:GetHeight() or 0)
        captionHeight = captionHeight + 6
    else
        blockFrame.caption:Hide()
    end

    blockFrame:SetSize(width, height + captionHeight)
    blockFrame.totalHeight = height + captionHeight
end

local function AcquireImage(frameRef)
    local pool = frameRef.imagePool
    local index = pool.nextIndex
    local widget = pool[index]
    if not widget then
        widget = CreateImageBlock(frameRef.content)
        pool[index] = widget
    end
    pool.nextIndex = index + 1
    widget:Show()
    return widget
end

local function CreateImageRow(parent)
    local row = CreateFrame("Frame", nil, parent)
    row.items = {}
    return row
end

local function AcquireRowItem(row)
    local index = (row.nextItemIndex or 1)
    local item = row.items[index]
    if not item then
        item = CreateImageBlock(row)
        row.items[index] = item
    end
    row.nextItemIndex = index + 1
    item:Show()
    return item
end

local function ResetRowItems(row)
    row.nextItemIndex = 1
    for _, item in ipairs(row.items) do
        item:Hide()
    end
end

local function AcquireHeadingLine(frameRef)
    local pool = frameRef.headingLinePool
    local index = pool.nextIndex
    local widget = pool[index]
    if not widget then
        widget = frameRef.content:CreateTexture(nil, "ARTWORK")
        if type(widget.SetAtlas) == "function" then
            local ok = pcall(widget.SetAtlas, widget, HEADING_GLOW_ATLAS)
            if ok then
                widget:SetVertexColor(1, 0.86, 0.18, 0.78)
            else
                widget:SetColorTexture(HEADING_LINE_R, HEADING_LINE_G, HEADING_LINE_B, HEADING_LINE_A)
            end
        else
            widget:SetColorTexture(HEADING_LINE_R, HEADING_LINE_G, HEADING_LINE_B, HEADING_LINE_A)
        end
        pool[index] = widget
    end
    pool.nextIndex = index + 1
    widget:SetSize(HEADING_GLOW_W, HEADING_GLOW_H)
    widget:Show()
    return widget
end

local function ApplyGlowLine(texture, width, height, alpha)
    if not texture then
        return
    end
    texture:SetSize(width or HEADING_GLOW_W, height or HEADING_GLOW_H)
    texture:SetAlpha(alpha or 1)
    if type(texture.SetAtlas) == "function" then
        local ok = pcall(texture.SetAtlas, texture, HEADING_GLOW_ATLAS)
        if ok then
            texture:SetVertexColor(1, 0.86, 0.18, 0.82)
            return
        end
    end
    texture:SetColorTexture(HEADING_LINE_R, HEADING_LINE_G, HEADING_LINE_B, HEADING_LINE_A)
end

local function CreateNoteBlock(parent)
    local wrapper = CreateFrame("Frame", nil, parent)

    wrapper.bg = wrapper:CreateTexture(nil, "BACKGROUND")
    wrapper.bg:SetAllPoints()
    wrapper.bg:SetColorTexture(NOTE_BG_R, NOTE_BG_G, NOTE_BG_B, NOTE_BG_A)

    wrapper.accent = wrapper:CreateTexture(nil, "BORDER")
    wrapper.accent:SetWidth(NOTE_ACCENT_WIDTH)
    wrapper.accent:SetPoint("TOPLEFT",    wrapper, "TOPLEFT",    0, 0)
    wrapper.accent:SetPoint("BOTTOMLEFT", wrapper, "BOTTOMLEFT", 0, 0)
    wrapper.accent:SetColorTexture(NOTE_ACCENT_R, NOTE_ACCENT_G, NOTE_ACCENT_B, NOTE_ACCENT_A)

    wrapper.label = wrapper:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    wrapper.label:SetJustifyH("LEFT")
    wrapper.label:SetJustifyV("TOP")
    wrapper.label:SetWordWrap(true)
    wrapper.label:SetSpacing(2)
    wrapper.label:SetTextColor(0.84, 0.88, 0.95, 1.0)

    return wrapper
end

local function AcquireNoteBlock(frameRef)
    local pool = frameRef.notePool
    local index = pool.nextIndex
    local widget = pool[index]
    if not widget then
        widget = CreateNoteBlock(frameRef.content)
        pool[index] = widget
    end
    pool.nextIndex = index + 1
    widget:Show()
    return widget
end

local function ResolveJustifyH(align, fallback)
    if align == "CENTER" or align == "center" then
        return "CENTER"
    elseif align == "RIGHT" or align == "right" then
        return "RIGHT"
    end
    return fallback or "LEFT"
end

local function ApplyNoteBlockLayout(noteFrame, text, contentWidth, block)
    block = type(block) == "table" and block or {}

    local showAccent = block.accent ~= false and block.noAccent ~= true
    local accentW = showAccent and NOTE_ACCENT_WIDTH or 0

    if showAccent then
        noteFrame.accent:Show()
    else
        noteFrame.accent:Hide()
    end

    local noteWidth = tonumber(block.width) or contentWidth
    noteWidth = math.floor(math.max(120, math.min(noteWidth, contentWidth)))
    local innerW = math.max(noteWidth - accentW - NOTE_PAD_X * 2, 80)
    noteFrame.label:SetWidth(innerW)
    noteFrame.label:SetText(text)
    noteFrame.label:SetJustifyH(ResolveJustifyH(block.align, "LEFT"))
    noteFrame.label:ClearAllPoints()
    noteFrame.label:SetPoint("TOPLEFT", noteFrame, "TOPLEFT", accentW + NOTE_PAD_X, -NOTE_PAD_Y)

    local textH   = math.ceil(noteFrame.label:GetStringHeight() or noteFrame.label:GetHeight() or 16)
    local totalH  = textH + NOTE_PAD_Y * 2
    noteFrame:SetSize(noteWidth, totalH)
    noteFrame.totalHeight = totalH
end

local function ApplyIntroPanelLayout(panel, text, contentWidth, align)
    if type(panel) ~= "table" or not panel.label then
        return 0
    end

    local innerW = math.max(contentWidth - PAGE_INTRO_PAD_X * 2, 120)
    panel.label:SetWidth(innerW)
    panel.label:SetText(text or "")
    panel.label:SetJustifyH(ResolveJustifyH(align, "CENTER"))
    panel.label:ClearAllPoints()
    panel.label:SetPoint("TOPLEFT", panel, "TOPLEFT", PAGE_INTRO_PAD_X, -PAGE_INTRO_PAD_Y)

    local textH = math.ceil(panel.label:GetStringHeight() or panel.label:GetHeight() or 16)
    local totalH = textH + PAGE_INTRO_PAD_Y * 2
    panel:SetSize(contentWidth, totalH)
    panel.totalHeight = totalH
    return totalH
end

local function AcquireImageRow(frameRef)
    local pool = frameRef.rowPool
    local index = pool.nextIndex
    local widget = pool[index]
    if not widget then
        widget = CreateImageRow(frameRef.content)
        pool[index] = widget
    end
    pool.nextIndex = index + 1
    widget:Show()
    ResetRowItems(widget)
    return widget
end

local function ApplyTextStyle(fontString, styleKey)
    local style = TEXT_STYLES[styleKey] or TEXT_STYLES.body
    fontString:SetFontObject(style.fontObject or "GameFontHighlight")
    fontString:SetJustifyH(style.justifyH or "LEFT")
    fontString:SetJustifyV(style.justifyV or "TOP")
    fontString:SetSpacing(style.spacing or 0)
    fontString:SetWordWrap(style.wordWrap ~= false)
    if style.color then
        fontString:SetTextColor(style.color[1], style.color[2], style.color[3], style.color[4] or 1)
    else
        fontString:SetTextColor(1, 1, 1, 1)
    end
end

local function LayoutImageRow(row, block, contentWidth)
    local items = block.items or {}
    local itemCount = #items
    local gap = tonumber(block.gap) or IMAGE_GAP
    local totalFixedWidth = 0
    local autoCount = 0

    for _, itemData in ipairs(items) do
        if tonumber(itemData.width) then
            totalFixedWidth = totalFixedWidth + tonumber(itemData.width)
        else
            autoCount = autoCount + 1
        end
    end

    local availableWidth = math.max(contentWidth - (gap * math.max(itemCount - 1, 0)), 0)
    local autoWidth = autoCount > 0 and math.floor((availableWidth - totalFixedWidth) / autoCount) or 0
    autoWidth = math.max(autoWidth, 120)

    local totalWidth = 0
    local tallest = 0
    local configuredItems = {}

    for itemIndex, itemData in ipairs(items) do
        local data = {}
        for key, value in pairs(itemData) do
            data[key] = value
        end
        if not tonumber(data.width) then
            data.width = autoWidth
        end

        local itemFrame = AcquireRowItem(row)
        ApplyImageBlockData(itemFrame, data)
        itemFrame.__valign = data.valign
        configuredItems[itemIndex] = itemFrame
        totalWidth = totalWidth + itemFrame:GetWidth()
        if itemIndex > 1 then
            totalWidth = totalWidth + gap
        end
        tallest = math.max(tallest, itemFrame.totalHeight or itemFrame:GetHeight() or 0)
    end

    local startX = 0
    if block.align == "CENTER" or block.align == nil then
        startX = math.floor(math.max(contentWidth - totalWidth, 0) / 2)
    end

    local cursorX = startX
    for _, itemFrame in ipairs(configuredItems) do
        local offsetY = 0
        if itemFrame.__valign == "center" or itemFrame.__valign == "middle" then
            offsetY = -math.floor((tallest - (itemFrame.totalHeight or itemFrame:GetHeight() or 0)) / 2)
        end
        itemFrame:ClearAllPoints()
        itemFrame:SetPoint("TOPLEFT", row, "TOPLEFT", cursorX, offsetY)
        cursorX = cursorX + itemFrame:GetWidth() + gap
    end

    row:SetSize(contentWidth, tallest)
    row.totalHeight = tallest
end

local function HideDynamicWidgets(frameRef)
    ResetPool(frameRef.textPool)
    ResetPool(frameRef.dividerPool)
    ResetPool(frameRef.imagePool)
    ResetPool(frameRef.rowPool)
    ResetPool(frameRef.notePool)
    ResetPool(frameRef.headingLinePool)

    for _, row in ipairs(frameRef.rowPool) do
        ResetRowItems(row)
    end
end

local function LayoutPage(frameRef, pageIndex, resetScroll)
    local pages = GetHelpPages()
    local page = pages[pageIndex]
    if type(page) ~= "table" then
        return
    end

    local scrollWidth = frameRef.scroll:GetWidth() or 0
    local contentWidth = math.floor(math.max(scrollWidth - CONTENT_RIGHT_PADDING, DEFAULT_CONTENT_WIDTH))

    HideDynamicWidgets(frameRef)

    frameRef.currentPageIndex = pageIndex
    frameRef.content:SetWidth(contentWidth)

    local cursorY = -CONTENT_TOP_PADDING

    if page.hideTitle == true or page.showTitle == false or page.title == false then
        frameRef.pageTitle:Hide()
        frameRef.pageTitleGlow:Hide()
    else
        frameRef.pageTitle:SetWidth(contentWidth)
        frameRef.pageTitle:SetText(tostring(page.title or "Help"))
        frameRef.pageTitle:ClearAllPoints()
        frameRef.pageTitle:SetPoint("TOP", frameRef.content, "TOP", 0, cursorY)
        frameRef.pageTitle:Show()

        local titleH = math.ceil(frameRef.pageTitle:GetStringHeight() or frameRef.pageTitle:GetHeight() or 0)
        cursorY = cursorY - titleH - 2

        local pageGlowW = math.min(PAGE_GLOW_W, math.max(contentWidth - 80, 80))
        ApplyGlowLine(frameRef.pageTitleGlow, pageGlowW, PAGE_GLOW_H, 0.94)
        frameRef.pageTitleGlow:ClearAllPoints()
        frameRef.pageTitleGlow:SetPoint("TOP", frameRef.content, "TOP", 0, cursorY)
        frameRef.pageTitleGlow:Show()
        cursorY = cursorY - PAGE_GLOW_H - 8
    end

    if type(page.intro) == "string" and page.intro ~= "" then
        local introW = math.min(contentWidth, math.max(260, contentWidth - 40))
        local introX = math.floor(math.max(contentWidth - introW, 0) / 2)
        local introH = ApplyIntroPanelLayout(frameRef.pageIntroPanel, page.intro, introW, page.introAlign or "CENTER")
        frameRef.pageIntroPanel:ClearAllPoints()
        frameRef.pageIntroPanel:SetPoint("TOPLEFT", frameRef.content, "TOPLEFT", introX, cursorY)
        frameRef.pageIntroPanel:Show()
        frameRef.pageIntro:Show()
        cursorY = cursorY - math.max(introH or 0, frameRef.pageIntroPanel.totalHeight or 0) - 16
    else
        frameRef.pageIntroPanel:Hide()
        frameRef.pageIntro:Hide()
    end

    for _, block in ipairs(page.blocks or {}) do
        cursorY = cursorY - (tonumber(block.spacingBefore) or 0)

        if block.type == "heading" then
            local widget = AcquireText(frameRef)
            ApplyTextStyle(widget, "heading")
            widget:SetWidth(contentWidth)
            widget:SetText(tostring(block.text or ""))
            widget:ClearAllPoints()
            widget:SetPoint("TOPLEFT", frameRef.content, "TOPLEFT", 0, cursorY)
            local textH = math.ceil(widget:GetStringHeight() or widget:GetHeight() or 0)

            local line = AcquireHeadingLine(frameRef)
            local lineW = math.min(HEADING_GLOW_W, math.max(contentWidth - 120, 90))
            line:ClearAllPoints()
            line:SetSize(lineW, HEADING_GLOW_H)
            line:SetPoint("TOP", frameRef.content, "TOP", 0, cursorY - textH - 3)

            cursorY = cursorY - textH - HEADING_GLOW_H - 3 - (tonumber(block.spacingAfter) or BLOCK_SPACING)
        elseif block.type == "text" then
            local widget = AcquireText(frameRef)
            ApplyTextStyle(widget, "body")
            widget:SetWidth(contentWidth - BODY_INDENT)
            widget:SetText(tostring(block.text or ""))
            widget:ClearAllPoints()
            widget:SetPoint("TOPLEFT", frameRef.content, "TOPLEFT", BODY_INDENT, cursorY)
            cursorY = cursorY - math.ceil(widget:GetStringHeight() or widget:GetHeight() or 0) - (tonumber(block.spacingAfter) or BLOCK_SPACING)
        elseif block.type == "note" then
            local widget = AcquireNoteBlock(frameRef)
            ApplyNoteBlockLayout(widget, tostring(block.text or ""), contentWidth, block)
            widget:ClearAllPoints()
            local noteWidth = widget:GetWidth() or contentWidth
            local offsetX = 0
            if block.align == "CENTER" or block.align == "center" then
                offsetX = math.floor(math.max(contentWidth - noteWidth, 0) / 2)
            elseif block.align == "RIGHT" or block.align == "right" then
                offsetX = math.max(contentWidth - noteWidth, 0)
            end
            widget:SetPoint("TOPLEFT", frameRef.content, "TOPLEFT", offsetX, cursorY)
            cursorY = cursorY - widget.totalHeight - (tonumber(block.spacingAfter) or BLOCK_SPACING)
        elseif block.type == "divider" then
            local divider = AcquireDivider(frameRef)
            divider:ClearAllPoints()
            divider:SetPoint("TOPLEFT", frameRef.content, "TOPLEFT", 0, cursorY)
            divider:SetPoint("TOPRIGHT", frameRef.content, "TOPLEFT", contentWidth, cursorY)
            cursorY = cursorY - 1 - (tonumber(block.spacingAfter) or BLOCK_SPACING)
        elseif block.type == "image" then
            local widget = AcquireImage(frameRef)
            ApplyImageBlockData(widget, block)
            widget:ClearAllPoints()
            local imageWidth = widget:GetWidth()
            local offsetX = 0
            if block.align == "CENTER" or block.align == nil then
                offsetX = math.floor(math.max(contentWidth - imageWidth, 0) / 2)
            end
            widget:SetPoint("TOPLEFT", frameRef.content, "TOPLEFT", offsetX, cursorY)
            cursorY = cursorY - math.ceil(widget.totalHeight or widget:GetHeight() or 0) - (tonumber(block.spacingAfter) or BLOCK_SPACING)
        elseif block.type == "image_row" then
            local row = AcquireImageRow(frameRef)
            LayoutImageRow(row, block, contentWidth)
            row:ClearAllPoints()
            row:SetPoint("TOPLEFT", frameRef.content, "TOPLEFT", 0, cursorY)
            cursorY = cursorY - math.ceil(row.totalHeight or row:GetHeight() or 0) - (tonumber(block.spacingAfter) or BLOCK_SPACING)
        elseif block.type == "recent_changelog" then
            local widget = AcquireText(frameRef)
            ApplyTextStyle(widget, "body")
            widget:SetWidth(contentWidth)
            widget:SetText(FormatRecentChangelogText(block.limit or 3))
            widget:ClearAllPoints()
            widget:SetPoint("TOPLEFT", frameRef.content, "TOPLEFT", 0, cursorY)
            cursorY = cursorY - math.ceil(widget:GetStringHeight() or widget:GetHeight() or 0) - (tonumber(block.spacingAfter) or BLOCK_SPACING)
        end
    end

    frameRef.content:SetHeight(math.abs(cursorY) + CONTENT_BOTTOM_PADDING)
    frameRef.pageNum:SetText(string.format("%d / %d", pageIndex, #pages))
    frameRef.prevButton:SetEnabled(pageIndex > 1)
    frameRef.nextButton:SetEnabled(pageIndex < #pages)

    if resetScroll then
        frameRef.scroll:SetVerticalScroll(0)
    end
end

local function ShowPage(frameRef, pageRef, resetScroll)
    local pageIndex = GetPageIndex(pageRef)
    if not pageIndex then
        return
    end

    LayoutPage(frameRef, pageIndex, resetScroll ~= false)
end

local TITLE_H  = 44
local FOOTER_H = 44

local function GetOrCreateFrame()
    if frame then
        return frame
    end

    -- Base frame
    frame = CreateFrame("Frame", "AWPHelpFrame", UIParent)
    frame:SetSize(FRAME_WIDTH, FRAME_HEIGHT)
    frame:SetPoint("CENTER")
    frame:SetFrameStrata("MEDIUM")
    frame:SetClampedToScreen(true)
    frame:SetMovable(true)
    frame:SetToplevel(true)
    frame:EnableMouse(true)
    frame:RegisterForDrag("LeftButton")
    frame:SetScript("OnDragStart", frame.StartMoving)
    frame:SetScript("OnDragStop",  frame.StopMovingOrSizing)
    frame:Hide()

    local versionStr = type(NS.GetAddonMetadataValue) == "function"
        and NS.GetAddonMetadataValue("Version", "") or ""
    local shell = FW.CreatePanelShell(frame, {
        title = FRAME_TITLE,
        titleHeight = TITLE_H,
        footerHeight = FOOTER_H,
        titleColor = FW.COLORS.closeTextHover,
        versionText = versionStr ~= "" and ("v" .. versionStr) or nil,
        movable = true,
        closeButton = true,
        closeSize = 28,
        closeOffsetX = -10,
        onClose = function() frame:Hide() end,
    })
    local footerFrame = shell.footerFrame

    frame.prevButton = FW.CreatePanelButton(footerFrame, { height = 28 })
    frame.prevButton:SetSize(110, 28)
    frame.prevButton:SetPoint("LEFT", footerFrame, "LEFT", 14, 0)
    frame.prevButton:SetDisplayText("Previous")
    frame.prevButton:SetScript("OnClick", function()
        if frame.currentPageIndex and frame.currentPageIndex > 1 then
            ShowPage(frame, frame.currentPageIndex - 1, true)
        end
    end)

    frame.nextButton = FW.CreatePanelButton(footerFrame, { height = 28 })
    frame.nextButton:SetSize(110, 28)
    frame.nextButton:SetPoint("RIGHT", footerFrame, "RIGHT", -14, 0)
    frame.nextButton:SetDisplayText("Next")
    frame.nextButton:SetScript("OnClick", function()
        local pages = GetHelpPages()
        if frame.currentPageIndex and frame.currentPageIndex < #pages then
            ShowPage(frame, frame.currentPageIndex + 1, true)
        end
    end)

    frame.pageNum = footerFrame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    frame.pageNum:SetPoint("CENTER", footerFrame, "CENTER", 0, 0)
    frame.pageNum:SetTextColor(0.72, 0.66, 0.58, 1.0)

    -- Scroll area
    frame.scroll = CreateFrame("ScrollFrame", nil, frame, "UIPanelScrollFrameTemplate")
    frame.scroll:SetPoint("TOPLEFT",     frame, "TOPLEFT",     14, -(TITLE_H + 12))
    frame.scroll:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -22, FOOTER_H + 12)
    frame.scroll:EnableMouseWheel(true)
    frame.scroll:SetScript("OnMouseWheel", function(self, delta)
        local current = self:GetVerticalScroll() or 0
        local range   = self:GetVerticalScrollRange() or 0
        local target  = Clamp(current - (delta * SCROLL_STEP), 0, range)
        self:SetVerticalScroll(target)
    end)

    FW.StyleScrollBar(frame.scroll, {
        trackInsetTop = 4,
        trackInsetBottom = 4,
        width = 6,
        hitRect = false,
    })

    frame.content = CreateFrame("Frame", nil, frame.scroll)
    frame.content:SetPoint("TOPLEFT", frame.scroll, "TOPLEFT", 0, 0)
    frame.content:SetSize(DEFAULT_CONTENT_WIDTH, 1)
    frame.scroll:SetScrollChild(frame.content)

    -- Page header widgets
    frame.pageTitle = frame.content:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
    frame.pageTitle:SetJustifyH("CENTER")
    frame.pageTitle:SetJustifyV("TOP")
    frame.pageTitle:SetWordWrap(true)
    frame.pageTitle:SetTextColor(1.0, 0.82, 0.0, 1.0)

    frame.pageTitleGlow = frame.content:CreateTexture(nil, "ARTWORK")
    ApplyGlowLine(frame.pageTitleGlow, PAGE_GLOW_W, PAGE_GLOW_H, 0.94)

    frame.pageIntroPanel = CreateFrame("Frame", nil, frame.content)
    frame.pageIntroPanel.bg = frame.pageIntroPanel:CreateTexture(nil, "BACKGROUND")
    frame.pageIntroPanel.bg:SetAllPoints()
    frame.pageIntroPanel.bg:SetColorTexture(PAGE_INTRO_BG[1], PAGE_INTRO_BG[2], PAGE_INTRO_BG[3], PAGE_INTRO_BG[4])
    frame.pageIntroPanel.borderTop = frame.pageIntroPanel:CreateTexture(nil, "BORDER")
    frame.pageIntroPanel.borderTop:SetColorTexture(PAGE_INTRO_BORDER[1], PAGE_INTRO_BORDER[2], PAGE_INTRO_BORDER[3], PAGE_INTRO_BORDER[4])
    frame.pageIntroPanel.borderTop:SetPoint("TOPLEFT", frame.pageIntroPanel, "TOPLEFT", 0, 0)
    frame.pageIntroPanel.borderTop:SetPoint("TOPRIGHT", frame.pageIntroPanel, "TOPRIGHT", 0, 0)
    frame.pageIntroPanel.borderTop:SetHeight(1)
    frame.pageIntroPanel.borderBottom = frame.pageIntroPanel:CreateTexture(nil, "BORDER")
    frame.pageIntroPanel.borderBottom:SetColorTexture(PAGE_INTRO_BORDER[1], PAGE_INTRO_BORDER[2], PAGE_INTRO_BORDER[3], PAGE_INTRO_BORDER[4])
    frame.pageIntroPanel.borderBottom:SetPoint("BOTTOMLEFT", frame.pageIntroPanel, "BOTTOMLEFT", 0, 0)
    frame.pageIntroPanel.borderBottom:SetPoint("BOTTOMRIGHT", frame.pageIntroPanel, "BOTTOMRIGHT", 0, 0)
    frame.pageIntroPanel.borderBottom:SetHeight(1)

    frame.pageIntro = frame.pageIntroPanel:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
    frame.pageIntroPanel.label = frame.pageIntro
    frame.pageIntro:SetJustifyH("LEFT")
    frame.pageIntro:SetJustifyV("TOP")
    frame.pageIntro:SetWordWrap(true)
    frame.pageIntro:SetSpacing(3)
    frame.pageIntro:SetTextColor(0.95, 0.95, 0.85, 1)

    -- Pools
    frame.textPool        = { nextIndex = 1 }
    frame.dividerPool     = { nextIndex = 1 }
    frame.imagePool       = { nextIndex = 1 }
    frame.rowPool         = { nextIndex = 1 }
    frame.notePool        = { nextIndex = 1 }
    frame.headingLinePool = { nextIndex = 1 }

    -- Scripts
    frame:SetScript("OnShow", function(self)
        C_Timer.After(0, function()
            if self and self:IsShown() then
                ShowPage(self, self.pendingPageRef or self.currentPageIndex or 1, true)
                self.pendingPageRef = nil
            end
        end)
    end)

    frame.scroll:SetScript("OnSizeChanged", function()
        if frame and frame:IsShown() and frame.currentPageIndex then
            LayoutPage(frame, frame.currentPageIndex, false)
        end
    end)

    return frame
end

function NS.ShowHelp(pageRef)
    local helpFrame = GetOrCreateFrame()
    helpFrame.pendingPageRef = pageRef or "overview"
    helpFrame:Show()
    helpFrame:Raise()
    if helpFrame.currentPageIndex then
        ShowPage(helpFrame, helpFrame.pendingPageRef, true)
        helpFrame.pendingPageRef = nil
    end
end

function NS.ShowWhatsNew()
    NS.ShowHelp("whats_new")
end

function NS.ShowChangelog()
    NS.ShowWhatsNew()
end

local function GetStartupHelpMode()
    return type(NS.GetStartupHelpMode) == "function"
        and NS.GetStartupHelpMode()
        or NS.Constants.STARTUP_HELP_MODE_ACCOUNT
end

local function GetStartupWhatsNewMode()
    return type(NS.GetStartupWhatsNewMode) == "function"
        and NS.GetStartupWhatsNewMode()
        or NS.Constants.STARTUP_HELP_MODE_ACCOUNT
end

local function GetStoredAddonVersionForStartupMode(mode)
    local C = NS.Constants
    if mode == C.STARTUP_HELP_MODE_CHARACTER then
        return type(NS.GetStoredAddonVersionForCurrentCharacter) == "function"
            and NS.GetStoredAddonVersionForCurrentCharacter()
            or nil
    end
    return NS.GetStoredAddonVersion and NS.GetStoredAddonVersion() or nil
end

local function UpdateStoredAddonVersionForStartupMode(mode)
    local C = NS.Constants
    if mode == C.STARTUP_HELP_MODE_DISABLED then
        if type(NS.UpdateStoredAddonVersion) == "function" then
            NS.UpdateStoredAddonVersion()
        end
        if type(NS.UpdateStoredAddonVersionForCurrentCharacter) == "function" then
            NS.UpdateStoredAddonVersionForCurrentCharacter()
        end
        return
    end
    if mode == C.STARTUP_HELP_MODE_CHARACTER then
        if type(NS.UpdateStoredAddonVersionForCurrentCharacter) == "function" then
            NS.UpdateStoredAddonVersionForCurrentCharacter()
        end
        return
    end
    if type(NS.UpdateStoredAddonVersion) == "function" then
        NS.UpdateStoredAddonVersion()
    end
end

local function HasVersionUpgradePending(mode)
    if mode == NS.Constants.STARTUP_HELP_MODE_DISABLED then
        return false
    end

    local previousVersion = GetStoredAddonVersionForStartupMode(mode)
    if type(previousVersion) ~= "string" or previousVersion == "" then
        return false
    end

    return type(NS.CompareAddonVersions) == "function"
        and NS.CompareAddonVersions(previousVersion, NS.VERSION) < 0
        or false
end

local function HasSeenOverviewForStartupMode(mode)
    local C = NS.Constants
    if mode == C.STARTUP_HELP_MODE_CHARACTER then
        return type(NS.HasSeenOverviewOnCurrentCharacter) == "function"
            and NS.HasSeenOverviewOnCurrentCharacter()
            or false
    end
    if mode == C.STARTUP_HELP_MODE_ACCOUNT then
        if type(NS.HasSeenOverviewAccountWide) == "function" and NS.HasSeenOverviewAccountWide() then
            return true
        end
        if type(NS.HasSeenOverviewOnCurrentCharacter) == "function"
            and NS.HasSeenOverviewOnCurrentCharacter()
        then
            if type(NS.MarkOverviewShownAccountWide) == "function" then
                NS.MarkOverviewShownAccountWide()
            end
            return true
        end
    end
    return mode == C.STARTUP_HELP_MODE_DISABLED
end

local function MarkOverviewShownForStartupMode(mode)
    local C = NS.Constants
    if mode == C.STARTUP_HELP_MODE_CHARACTER then
        if type(NS.MarkOverviewShownOnCurrentCharacter) == "function" then
            NS.MarkOverviewShownOnCurrentCharacter()
        end
    elseif mode == C.STARTUP_HELP_MODE_ACCOUNT then
        if type(NS.MarkOverviewShownAccountWide) == "function" then
            NS.MarkOverviewShownAccountWide()
        end
    end
end

local function ShowOverviewNotification()
    NS.Msg("Opening quick-start guide.")
    NS.After(0.2, function()
        if type(NS.ShowHelp) == "function" then
            NS.ShowHelp("overview")
        end
    end)
end

function NS.CheckHelpNotification()
    local mode = GetStartupWhatsNewMode()
    if not HasVersionUpgradePending(mode) then
        return false
    end

    NS.Msg(string.format("Updated to v%s - opening What's New.", NS.VERSION))
    NS.After(0.2, function()
        if type(NS.ShowWhatsNew) == "function" then
            NS.ShowWhatsNew()
        end
    end)

    UpdateStoredAddonVersionForStartupMode(mode)

    return true
end

function NS.CheckStartupHelpNotification()
    local helpMode = GetStartupHelpMode()
    local whatsNewMode = GetStartupWhatsNewMode()
    local hasVersionUpgrade = HasVersionUpgradePending(whatsNewMode)

    if helpMode ~= NS.Constants.STARTUP_HELP_MODE_DISABLED then
        local replayOverview = type(NS.ConsumePendingOverviewReplayForCurrentCharacter) == "function"
            and NS.ConsumePendingOverviewReplayForCurrentCharacter()
            or false
        local hasSeenOverview = HasSeenOverviewForStartupMode(helpMode)

        if replayOverview or not hasSeenOverview then
            MarkOverviewShownForStartupMode(helpMode)

            ShowOverviewNotification()

            if not hasVersionUpgrade then
                UpdateStoredAddonVersionForStartupMode(whatsNewMode)
            end

            return "overview"
        end
    end

    if NS.CheckHelpNotification() then
        return "whats_new"
    end

    UpdateStoredAddonVersionForStartupMode(whatsNewMode)

    return nil
end

NS.CheckChangelogNotification = NS.CheckHelpNotification
