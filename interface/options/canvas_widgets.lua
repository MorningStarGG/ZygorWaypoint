local NS = _G.AzerothWaypointNS
local C = NS.Constants

NS.Internal.Interface = NS.Internal.Interface or {}
NS.Internal.Interface.canvas = NS.Internal.Interface.canvas or {}

local M = NS.Internal.Interface.canvas

function M.CreateWidgets(ctx)
    local CreateFrame = ctx.CreateFrame
    local ColorPickerFrame = ctx.ColorPickerFrame
    local GameTooltip = ctx.GameTooltip
    local CreatePanelButton = ctx.CreatePanelButton
    local CreateDropdownButton = ctx.CreateDropdownButton
    local GetOpts = ctx.GetOpts
    local GetOptionText = ctx.GetOptionText
    local UnpackOptions = ctx.UnpackOptions
    local ShowTip = ctx.ShowTip
    local HideTip = ctx.HideTip
    local ShowHoverPreview = ctx.ShowHoverPreview
    local ShowDropdownOptionPreview = ctx.ShowDropdownOptionPreview
    local RestoreSectionPreview = ctx.RestoreSectionPreview
    local AddSettingMarkerTag = ctx.AddSettingMarkerTag
    local RefreshActiveSection = ctx.RefreshActiveSection
    local GetScrollChild = ctx.GetScrollChild
    local GetCursorY = ctx.GetCursorY
    local SetCursorY = ctx.SetCursorY

    local PAD = ctx.PAD
    local SECTION_H = ctx.SECTION_H
    local SPACER_H = ctx.SPACER_H
    local TOGGLE_H = ctx.TOGGLE_H
    local SLIDER_H = ctx.SLIDER_H
    local DROPDOWN_H = ctx.DROPDOWN_H
    local COLOR_H = ctx.COLOR_H
    local COLOR_TEXT_DIM = ctx.COLOR_TEXT_DIM

    local function RefreshSection()
        if type(RefreshActiveSection) == "function" then
            RefreshActiveSection()
        end
    end

    local function SectionHeader(text)
        local scrollChild = GetScrollChild()
        local y = GetCursorY()

        local lbl = scrollChild:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        lbl:SetTextColor(1, 0.82, 0, 1)
        lbl:SetText(text:upper())
        lbl:SetPoint("TOPLEFT", scrollChild, "TOPLEFT", PAD, -y - 8)

        local line = scrollChild:CreateTexture(nil, "ARTWORK")
        line:SetColorTexture(1, 0.82, 0, 0.22)
        line:SetHeight(1)
        line:SetPoint("LEFT", lbl, "RIGHT", 6, 0)
        line:SetPoint("RIGHT", scrollChild, "RIGHT", -PAD, 0)
        line:SetPoint("TOP", lbl, "CENTER", 0, 0)

        SetCursorY(y + SECTION_H)
    end

    local function Spacer(h)
        SetCursorY(GetCursorY() + (h or SPACER_H))
    end

    local function AddText(text, fontObject, color, indent, gap)
        local scrollChild = GetScrollChild()
        local y = GetCursorY()
        indent = indent or 0

        local fs = scrollChild:CreateFontString(nil, "OVERLAY", fontObject or "GameFontHighlightSmall")
        local textWidth = math.max(1, (scrollChild:GetWidth() or 0) - (PAD + indent) - PAD)
        fs:SetPoint("TOPLEFT", scrollChild, "TOPLEFT", PAD + indent, -y)
        fs:SetWidth(textWidth)
        fs:SetJustifyH("LEFT")
        fs:SetJustifyV("TOP")
        fs:SetWordWrap(true)
        fs:SetMaxLines(0)
        if color then fs:SetTextColor(color[1], color[2], color[3], color[4] or 1) end
        fs:SetText(text or "")

        SetCursorY(y + math.max(16, fs:GetStringHeight()) + (gap or 8))
        return fs
    end

    local function AddActionButton(text, width, onClick)
        local btn = CreatePanelButton(GetScrollChild())
        btn:SetSize(width or 118, 24)
        btn:SetDisplayText(text)
        btn:SetScript("OnClick", onClick)
        return btn
    end

    local function AddToggle(label, tooltip, getter, setter)
        local scrollChild = GetScrollChild()
        local y = GetCursorY()

        local check = CreateFrame("CheckButton", nil, scrollChild)
        check:SetHeight(TOGGLE_H)
        check:SetPoint("TOPLEFT", scrollChild, "TOPLEFT", PAD, -y)
        check:SetPoint("TOPRIGHT", scrollChild, "TOPRIGHT", -PAD, -y)
        local checked = getter()
        check:SetChecked(checked)

        check.rowHighlight = check:CreateTexture(nil, "BACKGROUND")
        check.rowHighlight:SetPoint("TOPLEFT", check, "TOPLEFT", -4, -1)
        check.rowHighlight:SetPoint("BOTTOMRIGHT", check, "BOTTOMRIGHT", 4, 1)
        check.rowHighlight:SetColorTexture(1, 0.82, 0, 0.07)
        check.rowHighlight:Hide()

        check.boxBorder = check:CreateTexture(nil, "ARTWORK")
        check.boxBorder:SetSize(14, 14)
        check.boxBorder:SetPoint("LEFT", check, "LEFT", 2, 0)
        check.boxBorder:SetColorTexture(0.72, 0.54, 0.30, 0.78)

        check.boxInset = check:CreateTexture(nil, "ARTWORK")
        check.boxInset:SetPoint("TOPLEFT", check.boxBorder, "TOPLEFT", 2, -2)
        check.boxInset:SetPoint("BOTTOMRIGHT", check.boxBorder, "BOTTOMRIGHT", -2, 2)
        check.boxInset:SetColorTexture(0.020, 0.018, 0.016, 0.96)

        local checkedTex = check:CreateTexture(nil, "OVERLAY")
        checkedTex:SetSize(18, 18)
        checkedTex:SetPoint("CENTER", check.boxBorder, "CENTER", 0, 0)
        checkedTex:SetTexture("Interface\\Buttons\\UI-CheckBox-Check")
        checkedTex:SetVertexColor(1, 0.78, 0.24, 1)
        check:SetCheckedTexture(checkedTex)
        check:SetChecked(checked)

        local pushedTex = check:CreateTexture(nil, "OVERLAY")
        pushedTex:SetAllPoints(check.boxBorder)
        pushedTex:SetColorTexture(1, 0.82, 0, 0.12)
        check:SetPushedTexture(pushedTex)

        local lbl = scrollChild:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
        lbl:SetPoint("LEFT", check, "LEFT", 22, 0)
        lbl:SetPoint("RIGHT", scrollChild, "RIGHT", -PAD, 0)
        lbl:SetJustifyH("LEFT")
        lbl:SetText(label)

        local tag = AddSettingMarkerTag(scrollChild, label)
        if tag then tag:SetPoint("RIGHT", check, "RIGHT", -4, 0) end

        check:SetScript("OnEnter", function(self)
            self.rowHighlight:Show()
            ShowTip(self, label, tooltip)
        end)
        check:SetScript("OnLeave", function(self)
            self.rowHighlight:Hide()
            HideTip()
        end)
        check:SetScript("OnClick", function(self)
            local v = self:GetChecked()
            setter(v == true or v == 1)
        end)

        SetCursorY(y + TOGGLE_H)
        return check
    end

    local function AddSlider(label, tooltip, minV, maxV, step, formatter, getter, setter)
        local scrollChild = GetScrollChild()
        local y = GetCursorY()

        local lbl = scrollChild:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
        lbl:SetPoint("TOPLEFT", scrollChild, "TOPLEFT", PAD, -y - 6)
        lbl:SetJustifyH("LEFT")
        lbl:SetText(label)

        local valText = scrollChild:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        valText:SetPoint("TOPRIGHT", scrollChild, "TOPRIGHT", -PAD, -y - 6)
        valText:SetJustifyH("RIGHT")

        local tag = AddSettingMarkerTag(scrollChild, label)
        if tag then tag:SetPoint("RIGHT", valText, "LEFT", -8, 0) end

        local slider = CreateFrame("Slider", nil, scrollChild, "OptionsSliderTemplate")
        slider:SetPoint("TOPLEFT", scrollChild, "TOPLEFT", PAD + 4, -y - 26)
        slider:SetPoint("TOPRIGHT", scrollChild, "TOPRIGHT", -PAD - 4, -y - 26)
        slider:SetHeight(16)
        slider:SetMinMaxValues(minV, maxV)
        slider:SetValueStep(step)
        if slider.Low  then slider.Low:SetText("")  slider.Low:SetAlpha(0)  end
        if slider.High then slider.High:SetText("") slider.High:SetAlpha(0) end
        if slider.Text then slider.Text:SetAlpha(0) end

        -- Hide all inherited template regions and replace with custom visuals
        for _, region in ipairs({ slider:GetRegions() }) do
            if type(region.SetAlpha) == "function" then region:SetAlpha(0) end
        end

        local trackOuter = slider:CreateTexture(nil, "BACKGROUND")
        trackOuter:SetPoint("TOPLEFT",  slider, "TOPLEFT",  0, -6)
        trackOuter:SetPoint("TOPRIGHT", slider, "TOPRIGHT", 0, -6)
        trackOuter:SetHeight(4)
        trackOuter:SetColorTexture(0.52, 0.35, 0.16, 0.55)

        local trackInner = slider:CreateTexture(nil, "ARTWORK")
        trackInner:SetPoint("TOPLEFT",  slider, "TOPLEFT",  1, -7)
        trackInner:SetPoint("TOPRIGHT", slider, "TOPRIGHT", -1, -7)
        trackInner:SetHeight(2)
        trackInner:SetColorTexture(0.045, 0.033, 0.025, 0.98)

        slider:SetThumbTexture("Interface\\Buttons\\WHITE8X8")
        local thumb = slider:GetThumbTexture()
        if thumb then
            thumb:SetSize(8, 18)
            thumb:SetVertexColor(0.88, 0.62, 0.22, 0.95)
        end

        local function refresh()
            local v = slider:GetValue()
            valText:SetText(formatter and formatter(v) or tostring(v))
        end

        slider:SetValue(getter())
        refresh()

        slider:SetScript("OnValueChanged", function(self, v, byUser)
            if byUser then setter(v) end
            refresh()
        end)

        if tooltip then
            slider:SetScript("OnEnter", function(self)
                ShowTip(self, label, tooltip)
            end)
            slider:SetScript("OnLeave", HideTip)
        end

        SetCursorY(y + SLIDER_H)
        return slider
    end

    local function AddDropdown(label, tooltip, optionsFunc, getter, setter)
        local scrollChild = GetScrollChild()
        local y = GetCursorY()

        local lbl = scrollChild:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
        lbl:SetPoint("TOPLEFT", scrollChild, "TOPLEFT", PAD, -y - 6)
        lbl:SetJustifyH("LEFT")
        lbl:SetText(label)

        local tag = AddSettingMarkerTag(scrollChild, label)
        if tag then tag:SetPoint("LEFT", lbl, "RIGHT", 8, 0) end

        local btn = CreateDropdownButton(scrollChild)
        btn:SetHeight(22)
        btn:SetPoint("TOPLEFT", scrollChild, "TOPLEFT", PAD, -y - 24)
        btn:SetPoint("TOPRIGHT", scrollChild, "TOPRIGHT", -PAD, -y - 24)

        local function refresh()
            btn:SetDisplayText(GetOptionText(optionsFunc, getter()))
        end
        refresh()

        if tooltip then
            btn:HookScript("OnEnter", function(self) ShowTip(self, label, tooltip) end)
            btn:HookScript("OnLeave", HideTip)
        end

        btn:SetScript("OnClick", function(self)
            if not (M.Dropdown and M.Dropdown.Open) then return end
            M.Dropdown.Open(self, {
                label = label,
                options = UnpackOptions(optionsFunc),
                currentValue = getter(),
                width = self:GetWidth(),
                onHover = function(opt)
                    ShowDropdownOptionPreview(label, opt.value, opt.text)
                end,
                onLeave = RestoreSectionPreview,
                onSelect = function(value)
                    setter(value)
                    refresh()
                    RestoreSectionPreview()
                end,
            })
        end)

        SetCursorY(y + DROPDOWN_H)
        return btn
    end

    local function AddTextInputList(label, tooltip, placeholder, listGetter, addEntry, removeEntry, clearEntries)
        local scrollChild = GetScrollChild()
        local y = GetCursorY()
        local list = type(listGetter) == "function" and listGetter() or {}

        local lbl = scrollChild:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
        lbl:SetPoint("TOPLEFT", scrollChild, "TOPLEFT", PAD, -y - 5)
        lbl:SetJustifyH("LEFT")
        lbl:SetText(label)

        local tag = AddSettingMarkerTag(scrollChild, label)
        if tag then tag:SetPoint("LEFT", lbl, "RIGHT", 8, 0) end

        local edit = CreateFrame("EditBox", nil, scrollChild, "InputBoxTemplate")
        edit:SetAutoFocus(false)
        edit:SetHeight(22)
        edit:SetPoint("TOPLEFT", scrollChild, "TOPLEFT", PAD + 4, -y - 25)
        edit:SetPoint("TOPRIGHT", scrollChild, "TOPRIGHT", -PAD - 126, -y - 25)
        edit:SetFontObject("GameFontHighlightSmall")
        edit:SetMaxLetters(64)
        edit:SetTextInsets(6, 6, 0, 0)

        local hint = edit:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
        hint:SetPoint("LEFT", edit, "LEFT", 8, 0)
        hint:SetPoint("RIGHT", edit, "RIGHT", -8, 0)
        hint:SetJustifyH("LEFT")
        hint:SetText(placeholder or "Addon name")

        local function refreshHint()
            if edit:GetText() == "" and not edit:HasFocus() then
                hint:Show()
            else
                hint:Hide()
            end
        end

        local function commit()
            local text = edit:GetText()
            if type(addEntry) == "function" and text ~= "" then
                addEntry(text)
                edit:SetText("")
                edit:ClearFocus()
                RefreshSection()
            end
        end

        edit:SetScript("OnEditFocusGained", refreshHint)
        edit:SetScript("OnEditFocusLost", refreshHint)
        edit:SetScript("OnTextChanged", refreshHint)
        edit:SetScript("OnEnterPressed", commit)
        edit:SetScript("OnEscapePressed", function(self)
            self:SetText("")
            self:ClearFocus()
        end)
        refreshHint()

        local addBtn = CreatePanelButton(scrollChild)
        addBtn:SetSize(54, 22)
        addBtn:SetPoint("LEFT", edit, "RIGHT", 8, 0)
        addBtn:SetDisplayText("Add")
        addBtn:SetScript("OnClick", commit)

        local clearBtn = CreatePanelButton(scrollChild)
        clearBtn:SetSize(58, 22)
        clearBtn:SetPoint("LEFT", addBtn, "RIGHT", 6, 0)
        clearBtn:SetDisplayText("Clear")
        clearBtn:SetScript("OnClick", function()
            if type(clearEntries) == "function" then
                clearEntries()
                RefreshSection()
            end
        end)

        if tooltip then
            edit:SetScript("OnEnter", function(self) ShowTip(self, label, tooltip) end)
            edit:SetScript("OnLeave", HideTip)
            addBtn:HookScript("OnEnter", function(self) ShowTip(self, label, tooltip) end)
            addBtn:HookScript("OnLeave", HideTip)
            clearBtn:HookScript("OnEnter", function(self) ShowTip(self, label, tooltip) end)
            clearBtn:HookScript("OnLeave", HideTip)
        end

        local rowY = y + 54
        if #list == 0 then
            local empty = scrollChild:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
            empty:SetPoint("TOPLEFT", scrollChild, "TOPLEFT", PAD + 6, -rowY)
            empty:SetPoint("RIGHT", scrollChild, "RIGHT", -PAD, 0)
            empty:SetJustifyH("LEFT")
            empty:SetText("No entries.")
            rowY = rowY + 18
        else
            for _, addonName in ipairs(list) do
                local row = CreateFrame("Frame", nil, scrollChild)
                row:SetHeight(24)
                row:SetPoint("TOPLEFT", scrollChild, "TOPLEFT", PAD, -rowY)
                row:SetPoint("TOPRIGHT", scrollChild, "TOPRIGHT", -PAD, -rowY)

                row.bg = row:CreateTexture(nil, "BACKGROUND")
                row.bg:SetAllPoints()
                row.bg:SetColorTexture(0.035, 0.028, 0.022, 0.70)

                local text = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
                text:SetPoint("LEFT", row, "LEFT", 8, 0)
                text:SetPoint("RIGHT", row, "RIGHT", -76, 0)
                text:SetJustifyH("LEFT")
                text:SetText(tostring(addonName))

                local removeBtn = CreatePanelButton(row)
                removeBtn:SetSize(66, 20)
                removeBtn:SetPoint("RIGHT", row, "RIGHT", -2, 0)
                removeBtn:SetDisplayText("Remove")
                removeBtn:SetScript("OnClick", function()
                    if type(removeEntry) == "function" then
                        removeEntry(addonName)
                        RefreshSection()
                    end
                end)

                rowY = rowY + 26
            end
        end

        SetCursorY(rowY + 4)
        return edit
    end

    local function AddRecentAddonCallerList(label, tooltip, listGetter, allowEntry, denyEntry, clearEntries)
        local scrollChild = GetScrollChild()
        local y = GetCursorY()
        local list = type(listGetter) == "function" and listGetter() or {}

        local lbl = scrollChild:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
        lbl:SetPoint("TOPLEFT", scrollChild, "TOPLEFT", PAD, -y - 5)
        lbl:SetJustifyH("LEFT")
        lbl:SetText(label)

        local clearBtn = CreatePanelButton(scrollChild)
        clearBtn:SetSize(96, 22)
        clearBtn:SetPoint("TOPRIGHT", scrollChild, "TOPRIGHT", -PAD, -y - 1)
        clearBtn:SetDisplayText("Clear Recent")
        clearBtn:SetScript("OnClick", function()
            if type(clearEntries) == "function" then
                clearEntries()
                RefreshSection()
            end
        end)

        if tooltip then
            clearBtn:HookScript("OnEnter", function(self) ShowTip(self, label, tooltip) end)
            clearBtn:HookScript("OnLeave", HideTip)
        end

        local rowY = y + 30
        if #list == 0 then
            local empty = scrollChild:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
            empty:SetPoint("TOPLEFT", scrollChild, "TOPLEFT", PAD + 6, -rowY)
            empty:SetPoint("RIGHT", scrollChild, "RIGHT", -PAD, 0)
            empty:SetJustifyH("LEFT")
            if COLOR_TEXT_DIM then
                empty:SetTextColor(COLOR_TEXT_DIM[1], COLOR_TEXT_DIM[2], COLOR_TEXT_DIM[3], 0.9)
            end
            empty:SetText("No unknown addon waypoint calls detected this session.")
            rowY = rowY + 22
        else
            for _, entry in ipairs(list) do
                local row = CreateFrame("Frame", nil, scrollChild)
                row:SetHeight(34)
                row:SetPoint("TOPLEFT", scrollChild, "TOPLEFT", PAD, -rowY)
                row:SetPoint("TOPRIGHT", scrollChild, "TOPRIGHT", -PAD, -rowY)

                row.bg = row:CreateTexture(nil, "BACKGROUND")
                row.bg:SetAllPoints()
                row.bg:SetColorTexture(0.035, 0.028, 0.022, 0.70)

                local name = row:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
                name:SetPoint("TOPLEFT", row, "TOPLEFT", 8, -4)
                name:SetPoint("RIGHT", row, "RIGHT", -150, 0)
                name:SetJustifyH("LEFT")
                name:SetText(tostring(entry.addonName or "-"))

                local detail = row:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
                detail:SetPoint("TOPLEFT", name, "BOTTOMLEFT", 0, -2)
                detail:SetPoint("RIGHT", row, "RIGHT", -150, 0)
                detail:SetJustifyH("LEFT")
                detail:SetText(string.format(
                    "%s, %s, %d calls",
                    tostring(entry.lastApiKind or "unknown"),
                    tostring(entry.lastDecision or "-"),
                    tonumber(entry.count) or 0
                ))

                local allowBtn = CreatePanelButton(row)
                allowBtn:SetSize(54, 22)
                allowBtn:SetPoint("RIGHT", row, "RIGHT", -62, 0)
                allowBtn:SetDisplayText("Allow")
                allowBtn:SetScript("OnClick", function()
                    if type(allowEntry) == "function" then
                        allowEntry(entry.addonName)
                        RefreshSection()
                    end
                end)

                local denyBtn = CreatePanelButton(row)
                denyBtn:SetSize(54, 22)
                denyBtn:SetPoint("RIGHT", row, "RIGHT", -2, 0)
                denyBtn:SetDisplayText("Block")
                denyBtn:SetScript("OnClick", function()
                    if type(denyEntry) == "function" then
                        denyEntry(entry.addonName)
                        RefreshSection()
                    end
                end)

                rowY = rowY + 38
            end
        end

        SetCursorY(rowY + 4)
    end

    local function AddColorRow(label, tooltip, modeGetter, modeSetter, customGetter, customSetter)
        local scrollChild = GetScrollChild()
        local y = GetCursorY()
        local opts = GetOpts()
        local copyColor = opts.CopyColorTable
        local colorModeOpts = opts.CreateWorldOverlayColorModeOptions

        local lbl = scrollChild:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
        lbl:SetPoint("TOPLEFT", scrollChild, "TOPLEFT", PAD, -y - 6)
        lbl:SetJustifyH("LEFT")
        lbl:SetText(label)

        local tag = AddSettingMarkerTag(scrollChild, label)
        if tag then tag:SetPoint("LEFT", lbl, "RIGHT", 8, 0) end

        local SWATCH_W = 26
        local swatch = CreateFrame("Button", nil, scrollChild)
        swatch:SetSize(SWATCH_W, 22)
        swatch:SetPoint("TOPRIGHT", scrollChild, "TOPRIGHT", -PAD, -y - 24)

        local swatchBorder = swatch:CreateTexture(nil, "BACKGROUND")
        swatchBorder:SetAllPoints()
        swatchBorder:SetColorTexture(0.62, 0.42, 0.18, 0.75)

        local swatchTex = swatch:CreateTexture(nil, "ARTWORK")
        swatchTex:SetPoint("TOPLEFT", swatch, "TOPLEFT", 2, -2)
        swatchTex:SetPoint("BOTTOMRIGHT", swatch, "BOTTOMRIGHT", -2, 2)

        local swatchAutoLabel = swatch:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        swatchAutoLabel:SetPoint("CENTER", swatch, "CENTER", 0, 0)
        swatchAutoLabel:SetText("~")
        swatchAutoLabel:SetTextColor(0.72, 0.66, 0.58, 0.85)
        swatchAutoLabel:Hide()

        local function GetEffectiveColor()
            local mode = modeGetter()
            if mode == C.WORLD_OVERLAY_COLOR_CUSTOM then
                local color = customGetter()
                if type(color) == "table" then
                    return color.r or 1, color.g or 1, color.b or 1, 1
                end
                return 0.95, 0.84, 0.44, 1
            end

            local preset = C.WORLD_OVERLAY_COLOR_PRESETS and C.WORLD_OVERLAY_COLOR_PRESETS[mode]
            if preset then
                return preset.r or 1, preset.g or 1, preset.b or 1, 1
            end
            return nil -- Auto: dynamic, no fixed color
        end

        local function refreshSwatch()
            local r, g, b, a = GetEffectiveColor()
            if r then
                swatchTex:SetColorTexture(r, g, b, a or 1)
                swatchAutoLabel:Hide()
            else
                swatchTex:SetColorTexture(0.10, 0.08, 0.06, 0.95)
                swatchAutoLabel:Show()
            end
        end

        local ddBtn = CreateDropdownButton(scrollChild)
        ddBtn:SetHeight(22)
        ddBtn:SetPoint("TOPLEFT", scrollChild, "TOPLEFT", PAD, -y - 24)
        ddBtn:SetPoint("TOPRIGHT", scrollChild, "TOPRIGHT", -(PAD + SWATCH_W + 6), -y - 24)

        local function refreshVisibility()
            local mode = modeGetter()
            swatch:SetAlpha((mode == C.WORLD_OVERLAY_COLOR_CUSTOM or mode == C.WORLD_OVERLAY_COLOR_AUTO) and 1 or 0.75)
        end

        local function refreshDD()
            ddBtn:SetDisplayText(GetOptionText(colorModeOpts, modeGetter()))
            refreshVisibility()
            refreshSwatch()
        end
        refreshDD()

        if tooltip then
            ddBtn:HookScript("OnEnter", function(self) ShowTip(self, label, tooltip) end)
            ddBtn:HookScript("OnLeave", HideTip)
        end

        ddBtn:SetScript("OnClick", function(self)
            if not (M.Dropdown and M.Dropdown.Open) then return end
            M.Dropdown.Open(self, {
                label = label,
                options = UnpackOptions(colorModeOpts),
                currentValue = modeGetter(),
                width = self:GetWidth(),
                getSwatchColor = function(opt)
                    if opt.value == C.WORLD_OVERLAY_COLOR_CUSTOM then
                        return GetEffectiveColor()
                    end
                    local preset = C.WORLD_OVERLAY_COLOR_PRESETS and C.WORLD_OVERLAY_COLOR_PRESETS[opt.value]
                    if preset then
                        return preset.r or 1, preset.g or 1, preset.b or 1, 1
                    end
                    return nil
                end,
                onHover = function(opt)
                    ShowDropdownOptionPreview(label, opt.value, opt.text)
                end,
                onLeave = RestoreSectionPreview,
                onSelect = function(value)
                    modeSetter(value)
                    NS.RefreshWorldOverlay()
                    refreshDD()
                    RestoreSectionPreview()
                end,
            })
        end)

        swatch:SetScript("OnEnter", function(self) ShowTip(self, label, tooltip) end)
        swatch:SetScript("OnLeave", HideTip)
        swatch:SetScript("OnClick", function()
            if modeGetter() ~= C.WORLD_OVERLAY_COLOR_CUSTOM then return end
            local color = customGetter()
            local safe = copyColor(color)
            ColorPickerFrame:SetupColorPickerAndShow({
                r = safe.r, g = safe.g, b = safe.b,
                swatchFunc = function()
                    local r, g, b = ColorPickerFrame:GetColorRGB()
                    customSetter({ r = r, g = g, b = b })
                    NS.RefreshWorldOverlay()
                    refreshSwatch()
                end,
                cancelFunc = function(prev)
                    customSetter(copyColor(prev))
                    NS.RefreshWorldOverlay()
                    refreshSwatch()
                end,
            })
        end)

        SetCursorY(y + COLOR_H)
    end

    return {
        SectionHeader = SectionHeader,
        Spacer = Spacer,
        AddText = AddText,
        AddActionButton = AddActionButton,
        AddToggle = AddToggle,
        AddSlider = AddSlider,
        AddDropdown = AddDropdown,
        AddTextInputList = AddTextInputList,
        AddRecentAddonCallerList = AddRecentAddonCallerList,
        AddColorRow = AddColorRow,
        GetScrollChild = GetScrollChild,
        GetCursorY = GetCursorY,
        SetCursorY = SetCursorY,
        PAD = PAD,
        COLOR_TEXT_DIM = ctx.COLOR_TEXT_DIM,
        COLOR_GOLD = ctx.COLOR_GOLD,
    }
end
