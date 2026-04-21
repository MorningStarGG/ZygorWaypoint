local NS = _G.ZygorWaypointNS
local C = NS.Constants

local function CopyColorTable(value, fallback)
    fallback = fallback or C.WORLD_OVERLAY_COLOR_PRESETS[C.WORLD_OVERLAY_COLOR_GOLD] or { r = 0.95, g = 0.84, b = 0.44 }
    if type(value) ~= "table" then
        return {
            r = fallback.r or 1,
            g = fallback.g or 1,
            b = fallback.b or 1,
        }
    end

    return {
        r = tonumber(value.r ~= nil and value.r or value[1]) or fallback.r or 1,
        g = tonumber(value.g ~= nil and value.g or value[2]) or fallback.g or 1,
        b = tonumber(value.b ~= nil and value.b or value[3]) or fallback.b or 1,
    }
end

local function ShowControlTooltip(owner, title, body)
    if not owner or type(body) ~= "string" or body == "" then
        return
    end

    local tooltip = SettingsTooltip or GameTooltip
    tooltip:SetOwner(owner, "ANCHOR_NONE")
    tooltip:SetPoint("BOTTOMRIGHT", owner, "TOPLEFT")
    tooltip:SetText(title or "", 1, 1, 1)
    tooltip:AddLine(body, nil, nil, nil, true)
    tooltip:Show()
end

local function HideControlTooltip()
    local tooltip = SettingsTooltip or GameTooltip
    tooltip:Hide()
end

ZWPWorldOverlayColorDropdownControlMixin = CreateFromMixins(SettingsDropdownControlMixin)

function ZWPWorldOverlayColorDropdownControlMixin:RefreshCustomButton()
    local initializer = self.__zwpInitializer
    if not initializer then
        return
    end

    local mode = NS.GetWorldOverlaySetting(initializer.modeSettingKey)
    local isCustom = mode == C.WORLD_OVERLAY_COLOR_CUSTOM
    local color = CopyColorTable(NS.GetWorldOverlaySetting(initializer.customColorSettingKey), initializer.customDefault)

    self.Control:ClearAllPoints()
    self.Control:SetPoint("LEFT", self, "CENTER", -84, 0)
    if isCustom then
        self.Control:SetPoint("RIGHT", self.CustomButton, "LEFT", -8, 0)
        self.CustomButton:Show()
    else
        self.Control:SetPoint("RIGHT", self, "RIGHT", -20, 0)
        self.CustomButton:Hide()
    end

    local width = self.Control:GetWidth()
    if self.Control.Dropdown and type(width) == "number" and width > 0 then
        self.Control.Dropdown:SetWidth(width)
    end

    self.CustomSwatch:SetColorTexture(color.r or 1, color.g or 1, color.b or 1, 1)
end

function ZWPWorldOverlayColorDropdownControlMixin:OpenColorPicker()
    local initializer = self.__zwpInitializer
    if not initializer then
        return
    end

    local initialColor = CopyColorTable(NS.GetWorldOverlaySetting(initializer.customColorSettingKey), initializer.customDefault)
    local previousColor = CopyColorTable(initialColor, initializer.customDefault)

    ColorPickerFrame:Hide()
    ColorPickerFrame:SetupColorPickerAndShow({
        swatchFunc = function()
            local r, g, b = ColorPickerFrame:GetColorRGB()
            initializer:SetCustomColor({ r = r, g = g, b = b })
        end,
        cancelFunc = function()
            initializer:SetCustomColor(previousColor)
        end,
        r = initialColor.r or 1,
        g = initialColor.g or 1,
        b = initialColor.b or 1,
        hasOpacity = false,
    })
end

function ZWPWorldOverlayColorDropdownControlMixin:Init(initializer)
    SettingsDropdownControlMixin.Init(self, initializer)

    self.__zwpInitializer = initializer
    initializer.boundFrame = self

    local leftPad = self:GetIndent() + 37

    self.Text:ClearAllPoints()
    self.Text:SetPoint("LEFT", self, "LEFT", leftPad, 0)
    self.Text:SetPoint("RIGHT", self, "CENTER", -98, 0)
    self.Text:SetJustifyH("LEFT")

    self.Control:ClearAllPoints()
    self.Control:SetHeight(26)

    if not self.CustomButton then
        self.CustomButton = CreateFrame("Button", nil, self, "UIPanelButtonTemplate")
        self.CustomButton:SetSize(136, 22)

        self.CustomSwatchBorder = self.CustomButton:CreateTexture(nil, "ARTWORK")
        self.CustomSwatchBorder:SetSize(16, 16)
        self.CustomSwatchBorder:SetPoint("LEFT", self.CustomButton, "LEFT", 8, 0)
        self.CustomSwatchBorder:SetColorTexture(0, 0, 0, 1)

        self.CustomSwatch = self.CustomButton:CreateTexture(nil, "OVERLAY")
        self.CustomSwatch:SetSize(14, 14)
        self.CustomSwatch:SetPoint("CENTER", self.CustomSwatchBorder, "CENTER")

        local buttonText = self.CustomButton:GetFontString()
        if buttonText then
            buttonText:ClearAllPoints()
            buttonText:SetPoint("LEFT", self.CustomSwatchBorder, "RIGHT", 6, 0)
            buttonText:SetPoint("RIGHT", self.CustomButton, "RIGHT", -8, 0)
            buttonText:SetJustifyH("LEFT")
        end
    end

    self.CustomButton:ClearAllPoints()
    self.CustomButton:SetPoint("RIGHT", self, "RIGHT", -20, 0)
    self.CustomButton:SetText("Custom Color...")
    self.CustomButton:SetScript("OnClick", function()
        self:OpenColorPicker()
    end)
    self.CustomButton:SetScript("OnEnter", function(control)
        ShowControlTooltip(
            control,
            initializer.displayName or initializer:GetName() or "",
            (initializer.inlineTooltip or "") .. " Click to pick the RGB override used when the dropdown is set to Custom."
        )
    end)
    self.CustomButton:SetScript("OnLeave", HideControlTooltip)

    self:RefreshCustomButton()
end
