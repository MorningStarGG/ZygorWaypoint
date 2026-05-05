local NS = _G.AzerothWaypointNS

NS.Internal.Interface = NS.Internal.Interface or {}
NS.Internal.Interface.canvas = NS.Internal.Interface.canvas or {}

local M = NS.Internal.Interface.canvas
local Dropdown = {}
M.Dropdown = Dropdown

local CreateFrame = _G.CreateFrame
local UIParent = _G.UIParent
local GameTooltip = _G.GameTooltip
local BackdropTemplateMixin = _G.BackdropTemplateMixin

local ROW_H = 24
local MAX_ROWS = 10
local POPUP_PADDING_Y = 12
local POPUP_GAP = 3
local SCREEN_MARGIN = 8

local function ColorTexture(texture, color)
    texture:SetColorTexture(color[1], color[2], color[3], color[4] or 1)
end

local function SetRowOption(row, option, selected, args)
    row.option = option
    row.disabledReason = option and option.disabledReason or nil
    row.check:SetText(selected and "*" or "")
    row.label:SetText(option and (option.text or tostring(option.value)) or "")
    if option and option.disabled then
        row.label:SetTextColor(0.50, 0.47, 0.42, 1)
        row.check:SetTextColor(0.50, 0.47, 0.42, 1)
    elseif selected then
        row.label:SetTextColor(1.00, 0.82, 0.00, 1)
        row.check:SetTextColor(1.00, 0.82, 0.00, 1)
    else
        row.label:SetTextColor(0.86, 0.80, 0.70, 1)
        row.check:SetTextColor(1.00, 0.82, 0.00, 1)
    end
    row.label:ClearAllPoints()
    row.label:SetPoint("LEFT", row.check, "RIGHT", 6, 0)

    local r, g, b, a
    if args and args.getSwatchColor and option then
        r, g, b, a = args.getSwatchColor(option)
    end
    row.swatch:SetShown(r ~= nil)
    if r then
        row.swatch:SetColorTexture(r, g or r, b or r, a or 1)
        row.label:SetPoint("RIGHT", row.swatch, "LEFT", -6, 0)
    else
        row.label:SetPoint("RIGHT", row, "RIGHT", -8, 0)
    end
end

local function RenderRows(popup)
    local args = popup.args
    if not args then return end

    local options = args.options or {}
    local count = #options
    local visibleRows = popup.visibleRows or MAX_ROWS
    local rowCount = math.min(visibleRows, count)
    local offset = popup.offset or 1
    local currentValue = args.currentValue

    for index = 1, MAX_ROWS do
        local row = popup.rows[index]
        if index <= rowCount then
            local option = options[offset + index - 1]
            row:SetShown(option ~= nil)
            SetRowOption(row, option, option and option.value == currentValue, args)
        else
            row:Hide()
        end
    end

    popup.topMore:SetShown(offset > 1)
    popup.bottomMore:SetShown(offset + rowCount - 1 < count)
end

local function GetFrameVerticalBounds(frame)
    if type(frame) ~= "table" or type(frame.GetTop) ~= "function" or type(frame.GetBottom) ~= "function" then
        return nil, nil
    end
    local top = frame:GetTop()
    local bottom = frame:GetBottom()
    if type(top) ~= "number" or type(bottom) ~= "number" then
        return nil, nil
    end
    return top, bottom
end

local function FindScrollViewport(anchor)
    local child = anchor
    while type(child) == "table" and type(child.GetParent) == "function" do
        local parent = child:GetParent()
        if not parent then
            break
        end
        if type(parent.GetScrollChild) == "function" then
            local ok, scrollChild = pcall(parent.GetScrollChild, parent)
            if ok and scrollChild == child then
                return parent
            end
        end
        child = parent
    end
    return nil
end

local function ResolvePopupPlacement(anchor, preferredRows)
    local viewport = FindScrollViewport(anchor) or UIParent
    local viewportTop, viewportBottom = GetFrameVerticalBounds(viewport)
    local screenTop, screenBottom = GetFrameVerticalBounds(UIParent)
    local anchorTop, anchorBottom = GetFrameVerticalBounds(anchor)

    if not (viewportTop and viewportBottom and screenTop and screenBottom and anchorTop and anchorBottom) then
        return "down", preferredRows
    end

    viewportTop = math.min(viewportTop, screenTop - SCREEN_MARGIN)
    viewportBottom = math.max(viewportBottom, screenBottom + SCREEN_MARGIN)

    local preferredHeight = preferredRows * ROW_H + POPUP_PADDING_Y
    local availableBelow = math.max(0, anchorBottom - viewportBottom - POPUP_GAP)
    local availableAbove = math.max(0, viewportTop - anchorTop - POPUP_GAP)
    local direction = "down"

    if availableBelow < preferredHeight and availableAbove > availableBelow then
        direction = "up"
    end

    local available = direction == "up" and availableAbove or availableBelow
    local maxRows = math.floor((available - POPUP_PADDING_Y) / ROW_H)
    if maxRows >= 1 and maxRows < preferredRows then
        return direction, maxRows
    end

    return direction, preferredRows
end

local function EnsurePopup()
    if Dropdown.popup then return Dropdown.popup end

    local popup = CreateFrame("Frame", "AWPOptionsDropdownPopup", UIParent, BackdropTemplateMixin and "BackdropTemplate" or nil)
    popup:SetFrameStrata("DIALOG")
    popup:SetClampedToScreen(true)
    popup:EnableMouse(true)
    if type(popup.EnableMouseWheel) == "function" then
        popup:EnableMouseWheel(true)
    end
    popup:Hide()

    if type(popup.SetBackdrop) == "function" then
        popup:SetBackdrop({
            bgFile = "Interface\\Buttons\\WHITE8X8",
            edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
            edgeSize = 10,
        })
        popup:SetBackdropColor(0.025, 0.019, 0.015, 0.98)
        popup:SetBackdropBorderColor(0.62, 0.42, 0.20, 0.82)
    else
        popup.bg = popup:CreateTexture(nil, "BACKGROUND")
        popup.bg:SetAllPoints()
        ColorTexture(popup.bg, { 0.025, 0.019, 0.015, 0.98 })
    end

    popup.rows = {}
    for index = 1, MAX_ROWS do
        local row = CreateFrame("Button", nil, popup)
        row:SetHeight(ROW_H)
        row:SetPoint("LEFT", popup, "LEFT", 6, 0)
        row:SetPoint("RIGHT", popup, "RIGHT", -6, 0)
        if index == 1 then
            row:SetPoint("TOP", popup, "TOP", 0, -6)
        else
            row:SetPoint("TOP", popup.rows[index - 1], "BOTTOM", 0, 0)
        end

        row.highlight = row:CreateTexture(nil, "BACKGROUND")
        row.highlight:SetAllPoints()
        row.highlight:SetColorTexture(1, 0.82, 0, 0.10)
        row.highlight:Hide()

        row.check = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        row.check:SetPoint("LEFT", row, "LEFT", 4, 0)
        row.check:SetWidth(12)
        row.check:SetTextColor(1, 0.82, 0, 1)

        row.label = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        row.label:SetPoint("LEFT", row.check, "RIGHT", 6, 0)
        row.label:SetPoint("RIGHT", row, "RIGHT", -8, 0)
        row.label:SetJustifyH("LEFT")

        row.swatch = row:CreateTexture(nil, "OVERLAY")
        row.swatch:SetSize(10, 10)
        row.swatch:SetPoint("RIGHT", row, "RIGHT", -8, 0)
        row.swatch:Hide()

        row:SetScript("OnEnter", function(self)
            self.highlight:Show()
            if self.option and self.option.disabled and self.disabledReason and GameTooltip then
                GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
                GameTooltip:SetText(self.option.text or tostring(self.option.value), 1, 1, 1, 1, true)
                GameTooltip:AddLine(self.disabledReason, nil, nil, nil, true)
                GameTooltip:Show()
            end
            if popup.args and popup.args.onHover and self.option then
                popup.args.onHover(self.option)
            end
        end)
        row:SetScript("OnLeave", function(self)
            self.highlight:Hide()
            if GameTooltip then
                GameTooltip:Hide()
            end
            if popup.args and popup.args.onLeave then
                popup.args.onLeave(self.option)
            end
        end)
        row:SetScript("OnClick", function(self)
            if self.option and self.option.disabled then
                return
            end
            if popup.args and popup.args.onSelect and self.option then
                popup.args.onSelect(self.option.value, self.option)
            end
            popup:Hide()
        end)

        popup.rows[index] = row
    end

    popup.topMore = popup:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    popup.topMore:SetPoint("TOPRIGHT", popup, "TOPRIGHT", -8, -2)
    popup.topMore:SetText("^")
    popup.topMore:Hide()

    popup.bottomMore = popup:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    popup.bottomMore:SetPoint("BOTTOMRIGHT", popup, "BOTTOMRIGHT", -8, 2)
    popup.bottomMore:SetText("v")
    popup.bottomMore:Hide()

    popup:SetScript("OnMouseWheel", function(self, delta)
        local options = self.args and self.args.options or nil
        local visibleRows = self.visibleRows or MAX_ROWS
        if not options or #options <= visibleRows then return end

        local maxOffset = math.max(1, #options - visibleRows + 1)
        if delta < 0 then
            self.offset = math.min(maxOffset, (self.offset or 1) + 1)
        else
            self.offset = math.max(1, (self.offset or 1) - 1)
        end
        RenderRows(self)
    end)

    Dropdown.popup = popup
    return popup
end

function Dropdown.Close()
    if Dropdown.popup then
        Dropdown.popup:Hide()
    end
end

function Dropdown.Open(anchor, args)
    if not anchor or type(args) ~= "table" then return end

    local popup = EnsurePopup()
    if popup:IsShown() and popup.anchor == anchor then
        popup:Hide()
        return
    end

    local options = args.options or {}
    local preferredRows = math.min(MAX_ROWS, math.max(1, #options))
    local direction, rowCount = ResolvePopupPlacement(anchor, preferredRows)
    local width = args.width or anchor:GetWidth() or 180

    popup.anchor = anchor
    popup.args = args
    popup.visibleRows = rowCount
    popup.offset = 1
    popup:SetParent(UIParent)
    popup:SetFrameLevel((anchor:GetFrameLevel() or 1) + 30)
    popup:SetSize(width, rowCount * ROW_H + POPUP_PADDING_Y)
    popup:ClearAllPoints()
    if direction == "up" then
        popup:SetPoint("BOTTOMLEFT", anchor, "TOPLEFT", 0, POPUP_GAP)
    else
        popup:SetPoint("TOPLEFT", anchor, "BOTTOMLEFT", 0, -POPUP_GAP)
    end
    popup:Show()
    RenderRows(popup)
end
