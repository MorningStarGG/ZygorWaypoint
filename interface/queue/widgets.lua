local NS = _G.AzerothWaypointNS
NS.Internal = NS.Internal or {}
NS.Internal.QueueUI = NS.Internal.QueueUI or {}
local M = NS.Internal.QueueUI
local ui = M.ui

local _iconKeyParts = {}

local function GetNativeOverlay()
    return NS.Internal and NS.Internal.WorldOverlay or nil
end

local function NormalizeQueueIconSpec(iconDef)
    if type(iconDef) ~= "table" then
        return nil
    end
    if iconDef.atlas or iconDef.texture then
        return iconDef
    end
    if type(iconDef.icon) == "string" then
        return {
            texture = iconDef.icon,
            tint = iconDef.iconTint,
            key = iconDef.key or iconDef.displayName or iconDef.icon,
            recolor = iconDef.recolor,
        }
    end
    return nil
end

local function BuildIconSpecKey(iconDef)
    if type(iconDef) ~= "table" then
        return nil
    end
    local tint = type(iconDef.tint) == "table" and iconDef.tint or nil
    _iconKeyParts[1] = tostring(iconDef.key or "")
    _iconKeyParts[2] = tostring(iconDef.atlas or "")
    _iconKeyParts[3] = tostring(iconDef.texture or "")
    _iconKeyParts[4] = tostring(iconDef.recolor == true)
    _iconKeyParts[5] = tostring(tint and tint.r or "")
    _iconKeyParts[6] = tostring(tint and tint.g or "")
    _iconKeyParts[7] = tostring(tint and tint.b or "")
    _iconKeyParts[8] = tostring(tint and tint.a or "")
    return table.concat(_iconKeyParts, "\031", 1, 8)
end

function M.ApplyQueueIcon(texture, iconDef, size)
    if not texture then
        return false
    end
    iconDef = NormalizeQueueIconSpec(iconDef)
    if not iconDef then
        texture._awpQueueIconKey = nil
        texture:Hide()
        return false
    end

    local iconKey = BuildIconSpecKey(iconDef)
    texture:SetSize(size or 16, size or 16)
    if texture._awpQueueIconKey ~= iconKey then
        local native = GetNativeOverlay()
        if native and type(native.SetIconTexture) == "function" then
            native.SetIconTexture(texture, iconDef)
        elseif iconDef.atlas then
            texture:SetTexCoord(0, 1, 0, 1)
            texture:SetAtlas(iconDef.atlas, false, true)
            if type(texture.SetDesaturated) == "function" then
                texture:SetDesaturated(false)
            end
            texture:SetVertexColor(1, 1, 1, 1)
        else
            texture:SetTexture(iconDef.texture)
            texture:SetTexCoord(0, 1, 0, 1)
            if type(texture.SetDesaturated) == "function" then
                texture:SetDesaturated(iconDef.recolor == true)
            end
            local tint = type(iconDef.tint) == "table" and iconDef.tint or nil
            texture:SetVertexColor(tint and tint.r or 1, tint and tint.g or 1, tint and tint.b or 1, tint and tint.a or 1)
        end
        texture._awpQueueIconKey = iconKey
    end
    texture:Show()
    return true
end

M.DETAIL_HEADER_TEXT_TOP_OFFSET = -34
local DETAIL_HEADER_TEXT_TOP_OFFSET = M.DETAIL_HEADER_TEXT_TOP_OFFSET
M.DETAIL_HEADER_TEXT_GAP = 4
local DETAIL_HEADER_TEXT_GAP = M.DETAIL_HEADER_TEXT_GAP
M.DETAIL_HEADER_ICON_SIZE = 28
local DETAIL_HEADER_ICON_SIZE = M.DETAIL_HEADER_ICON_SIZE
M.DETAIL_HEADER_ICON_LEFT = 12
local DETAIL_HEADER_ICON_LEFT = M.DETAIL_HEADER_ICON_LEFT
M.DETAIL_HEADER_ICON_TEXT_GAP = 8
local DETAIL_HEADER_ICON_TEXT_GAP = M.DETAIL_HEADER_ICON_TEXT_GAP
local DETAIL_HEADER_ICON_CENTER_X = DETAIL_HEADER_ICON_LEFT + (DETAIL_HEADER_ICON_SIZE * 0.5)

local function GetVisibleFontStringHeight(fontString, fallback)
    if not fontString or (type(fontString.IsShown) == "function" and not fontString:IsShown()) then
        return 0
    end

    local height = type(fontString.GetStringHeight) == "function" and fontString:GetStringHeight() or nil
    if type(height) == "number" and height > 0 then
        return height
    end
    return fallback or 14
end

function M.LayoutDetailHeaderIdentity(content, iconShown)
    if type(content) ~= "table" or not content.detailHeader or not content.detailHeadline then
        return
    end

    local textLeft = iconShown
        and (DETAIL_HEADER_ICON_LEFT + DETAIL_HEADER_ICON_SIZE + DETAIL_HEADER_ICON_TEXT_GAP)
        or 12
    content.detailHeadline:ClearAllPoints()
    content.detailHeadline:SetPoint("TOPLEFT", content.detailHeader, "TOPLEFT", textLeft, DETAIL_HEADER_TEXT_TOP_OFFSET)
    content.detailHeadline:SetPoint("RIGHT", content.detailHeader, "RIGHT", -36, 0)

    if iconShown and content.detailIcon then
        local blockHeight = GetVisibleFontStringHeight(content.detailHeadline, 16)
        if content.detailSubline and content.detailSubline:IsShown() then
            blockHeight = blockHeight + DETAIL_HEADER_TEXT_GAP + GetVisibleFontStringHeight(content.detailSubline, 14)
        end
        if content.detailHint and content.detailHint:IsShown() then
            blockHeight = blockHeight + DETAIL_HEADER_TEXT_GAP + GetVisibleFontStringHeight(content.detailHint, 14)
        end

        content.detailIcon:ClearAllPoints()
        content.detailIcon:SetPoint(
            "CENTER",
            content.detailHeader,
            "TOPLEFT",
            DETAIL_HEADER_ICON_CENTER_X,
            DETAIL_HEADER_TEXT_TOP_OFFSET - (blockHeight * 0.5)
        )
    end
end


function M.GetScrollContentWidth(scrollFrame, minimumWidth)
    local width = type(scrollFrame) == "table" and scrollFrame:GetWidth() or 0
    return math.max(math.floor(width or 0), minimumWidth or 1)
end

local function GetLegacyScrollBar(scrollFrame)
    if type(scrollFrame) ~= "table" then
        return nil
    end

    if type(scrollFrame.ScrollBar) == "table" then
        return scrollFrame.ScrollBar
    end

    local name = type(scrollFrame.GetName) == "function" and scrollFrame:GetName() or nil
    if type(name) == "string" then
        return _G[name .. "ScrollBar"]
    end

    return nil
end

local function HideLegacyScrollButton(scrollBar, suffixes)
    if type(scrollBar) ~= "table" or type(suffixes) ~= "table" then
        return
    end

    local name = type(scrollBar.GetName) == "function" and scrollBar:GetName() or nil
    for index = 1, #suffixes do
        local suffix = suffixes[index]
        local button = scrollBar[suffix]
        if not button and type(name) == "string" then
            button = _G[name .. suffix]
        end
        if type(button) == "table" and type(button.Hide) == "function" then
            button:Hide()
            if type(button.SetAlpha) == "function" then
                button:SetAlpha(0)
            end
        end
    end
end

function M.StyleLegacyScrollBar(scrollFrame, ownerFrame)
    local scrollBar = GetLegacyScrollBar(scrollFrame)
    if not scrollBar or not ownerFrame then
        return
    end

    HideLegacyScrollButton(scrollBar, {
        "ScrollUpButton",
        "ScrollDownButton",
        "UpButton",
        "DownButton",
        "DecrementButton",
        "IncrementButton",
    })

    local thumb = type(scrollBar.GetThumbTexture) == "function" and scrollBar:GetThumbTexture() or nil
    if type(scrollBar.SetThumbTexture) == "function" then
        scrollBar:SetThumbTexture("Interface\\Buttons\\WHITE8X8")
        thumb = type(scrollBar.GetThumbTexture) == "function" and scrollBar:GetThumbTexture() or thumb
    end
    if type(thumb) == "table" and type(thumb.SetTexture) == "function" then
        thumb:SetTexture("Interface\\Buttons\\WHITE8X8")
        thumb:SetVertexColor(0.85, 0.85, 0.85, 0.95)
        if type(thumb.SetWidth) == "function" then
            thumb:SetWidth(5)
        end
    end

    local regions = { scrollBar:GetRegions() }
    for index = 1, #regions do
        local region = regions[index]
        if region ~= thumb and type(region) == "table" and type(region.SetAlpha) == "function" then
            region:SetAlpha(0)
        end
    end

    if not scrollBar.awpTrack then
        scrollBar.awpTrack = scrollBar:CreateTexture(nil, "BACKGROUND")
        scrollBar.awpTrack:SetColorTexture(0, 0, 0, 0.45)
        scrollBar.awpTrack:SetPoint("TOP", scrollBar, "TOP", 0, -4)
        scrollBar.awpTrack:SetPoint("BOTTOM", scrollBar, "BOTTOM", 0, 4)
        scrollBar.awpTrack:SetWidth(2)
    end

    scrollBar:ClearAllPoints()
    scrollBar:SetPoint("TOPRIGHT", ownerFrame, "TOPRIGHT", -7, -12)
    scrollBar:SetPoint("BOTTOMRIGHT", ownerFrame, "BOTTOMRIGHT", -7, 12)
    scrollBar:SetWidth(6)
    if type(scrollBar.SetHitRectInsets) == "function" then
        scrollBar:SetHitRectInsets(-6, -6, 0, 0)
    end
    if type(scrollBar.SetHideIfUnscrollable) == "function" then
        scrollBar:SetHideIfUnscrollable(true)
    end
end


function M.CreateContextMenuButton(rootDescription, text, callback, enabled)
    local elementDescription = rootDescription:CreateButton(text, callback)
    if enabled == false and elementDescription and type(elementDescription.SetEnabled) == "function" then
        elementDescription:SetEnabled(false)
    end
    return elementDescription
end

function M.AddContextMenuDivider(rootDescription)
    if type(rootDescription.CreateDivider) == "function" then
        rootDescription:CreateDivider()
    end
end

function M.SetContentPageBounds(page, bottomInset)
    if not page or not ui.content then
        return
    end

    page:ClearAllPoints()
    page:SetPoint("TOPLEFT", ui.content, "TOPLEFT", 12, -42)
    page:SetPoint("BOTTOMRIGHT", ui.content, "BOTTOMRIGHT", -12, bottomInset or 12)
end

function M.ReflowFooterButtons(viewMode, selectedQueue, queueType)
    if not ui.content then
        return 0
    end

    local visibleButtons = {}
    local availableWidth = math.max((ui.content:GetWidth() or 0) - 24, 160)
    local function addButton(button, width)
        if button and button:IsShown() then
            button:SetWidth(math.min(width, availableWidth))
            visibleButtons[#visibleButtons + 1] = button
        end
    end

    if viewMode == "detail" and type(selectedQueue) == "table" then
        if queueType == "manual" then
            addButton(ui.content.useButton, 96)
        end
        addButton(ui.content.clearButton, 60)
    else
        addButton(ui.content.importButton, 72)
        addButton(ui.content.questsButton, 84)
    end

    if #visibleButtons == 0 then
        return 0
    end

    -- Group buttons into rows, then center each row horizontally.
    local rows = {}
    local curRow = { width = 0 }
    rows[1] = curRow
    for index = 1, #visibleButtons do
        local btn = visibleButtons[index]
        local w = btn:GetWidth() or 0
        local gap = curRow.width > 0 and 6 or 0
        if curRow.width > 0 and curRow.width + gap + w > availableWidth then
            curRow = { width = 0 }
            rows[#rows + 1] = curRow
        end
        gap = curRow.width > 0 and 6 or 0
        curRow[#curRow + 1] = btn
        curRow.width = curRow.width + gap + w
    end

    local bottom = 12
    local totalHeight = 0

    for rowIndex = 1, #rows do
        local row = rows[rowIndex]
        -- Center this row within the available area (left margin = 12).
        local startX = math.floor(12 + (availableWidth - row.width) / 2)
        local cursorX = startX
        local rowHeight = 0

        for btnIndex = 1, #row do
            local btn = row[btnIndex]
            local w = btn:GetWidth() or 0
            local h = btn:GetHeight() or 24
            btn:ClearAllPoints()
            btn:SetPoint("BOTTOMLEFT", ui.content, "BOTTOMLEFT", cursorX, bottom + totalHeight)
            cursorX = cursorX + w + 6
            if h > rowHeight then rowHeight = h end
        end

        totalHeight = totalHeight + rowHeight
        if rowIndex < #rows then
            totalHeight = totalHeight + 6
        end
    end

    return totalHeight
end

function M.UpdateBulkDeleteButton(selectedQueue, queueType, viewMode)
    local button = ui.content and ui.content.bulkDeleteButton or nil
    if not button then
        return
    end

    local count = 0
    local enabled = false
    local anchorFrame = ui.content.listPage
    if viewMode == "detail"
        and queueType == "manual"
        and type(selectedQueue) == "table"
        and type(selectedQueue.id) == "string"
    then
        count = #M.GetSelectedQueueItemIndexes(selectedQueue.id)
        enabled = count > 0 and type(NS.RemoveQueueItems) == "function"
        button.deleteMode = "items"
        button.queueKey = selectedQueue.id
        anchorFrame = ui.content.summaryPanel or ui.content.detailPage
    else
        count = #M.GetSelectedQueueIDs()
        enabled = count > 0 and type(NS.ClearQueuesByID) == "function"
        button.deleteMode = "queues"
        button.queueKey = nil
    end

    button.deleteCount = count
    button:SetShown(count > 0)
    button:SetEnabled(enabled)
    button:SetAlpha(enabled and 1 or 0.45)
    if count <= 0 then
        return
    end

    button:ClearAllPoints()
    button:SetPoint("BOTTOMRIGHT", anchorFrame, "BOTTOMRIGHT", -18, 14)
end
