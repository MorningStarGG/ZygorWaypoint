local NS = _G.ZygorWaypointNS
local C = NS.Constants

local optionsPanel
local TWITCH_URL = "https://www.twitch.tv/MorningStarGG"
local TWITCH_COPY_POPUP = "ZWP_COPY_TWITCH_URL"

local function SetTooltip(widget, title, text)
    widget:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText(title, 1, 1, 1)
        GameTooltip:AddLine(text, nil, nil, nil, true)
        GameTooltip:Show()
    end)
    widget:SetScript("OnLeave", function()
        GameTooltip:Hide()
    end)
end

local function UpdateScaleText(scale)
    local value = NS.NormalizeScale(scale:GetValue())
    scale.Text:SetText(string.format("TomTom Arrow Scale: %.2fx", value))
end

local function GetCustomSkinLabel(skin)
    if skin == C.SKIN_STEALTH then
        return "Stealth"
    end
    return "Starlight"
end

local function UpdateSkinChoiceText(button, skin)
    if not button then return end
    button:SetText("Skin: " .. GetCustomSkinLabel(skin))
end

local function ShowCopyLinkPopup(url)
    if not StaticPopupDialogs then
        NS.Msg("Twitch:", url)
        return
    end

    if not StaticPopupDialogs[TWITCH_COPY_POPUP] then
        StaticPopupDialogs[TWITCH_COPY_POPUP] = {
            text = "Copy Twitch URL (Ctrl+C):",
            button1 = OKAY,
            hasEditBox = 1,
            editBoxWidth = 320,
            timeout = 0,
            whileDead = 1,
            hideOnEscape = 1,
            preferredIndex = STATICPOPUP_NUMDIALOGS,
            OnShow = function(self, data)
                local editBox = self.EditBox or self.editBox
                if not editBox then return end
                editBox:SetText(data or "")
                editBox:HighlightText()
                editBox:SetFocus()
            end,
            OnAccept = function(self)
                self:Hide()
            end,
            EditBoxOnEnterPressed = function(self)
                self:HighlightText()
            end,
            EditBoxOnEscapePressed = function(self)
                self:GetParent():Hide()
            end,
        }
    end

    StaticPopup_Show(TWITCH_COPY_POPUP, nil, nil, url)
end

function NS.CreateOptionsPanel()
    if optionsPanel then return optionsPanel end

    local panel = CreateFrame("Frame", "ZygorWaypointOptions_AddOns", UIParent)
    panel.name = "ZygorWaypoint"
    optionsPanel = panel

    local logo = panel:CreateTexture(nil, "ARTWORK")
    logo:SetSize(96, 96)
    logo:SetPoint("TOPLEFT", 16, -16)
    pcall(function()
        logo:SetTexture("Interface\\AddOns\\ZygorWaypoint\\media\\icon.png")
    end)

    local title = panel:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
    title:SetPoint("TOPLEFT", logo, "TOPRIGHT", 16, -4)
    title:SetText("ZygorWaypoint")

    local ver = panel:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    ver:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -4)
    ver:SetText(string.format("Version %s", NS.VERSION or "?"))

    local tag = panel:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    tag:SetPoint("TOPLEFT", ver, "BOTTOMLEFT", 0, -4)
    tag:SetText("A bridge between Zygor Guides and TomTom's Crazy Arrow.")

    local sep1 = panel:CreateTexture(nil, "ARTWORK")
    sep1:SetColorTexture(1, 1, 1, 0.15)
    sep1:SetHeight(1)
    sep1:SetPoint("TOPLEFT", logo, "BOTTOMLEFT", 0, -12)
    sep1:SetPoint("RIGHT", panel, "RIGHT", -16, 0)

    local desc = panel:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
    desc:SetPoint("TOPLEFT", sep1, "BOTTOMLEFT", 0, -12)
    desc:SetWidth(560)
    desc:SetJustifyH("LEFT")
    desc:SetText([[ZygorWaypoint drives TomTom's Crazy Arrow using Zygor's active guide destination.

- Uses Zygor's Travel System to calculate navigation routes
- Displays TomTom's Crazy Arrow for waypoint navigation
- Hides Zygor's 3D arrow while keeping guide step text visible
- Optional alignment of TomTom's arrow with Zygor's arrow text
- Optional routing of TomTom waypoints through Zygor's Travel System
- Optional Zygor Starlight/Stealth skins and arrow scale override for TomTom]])

    local author = panel:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
    author:SetPoint("TOPLEFT", desc, "BOTTOMLEFT", 0, -10)
    author:SetText("Author: MorningStarGG")

    local twitchUrl = panel:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    twitchUrl:SetPoint("TOPLEFT", author, "BOTTOMLEFT", 0, -4)
    twitchUrl:SetText("Twitch: " .. TWITCH_URL)

    local twitch = CreateFrame("Button", "ZWP_CopyTwitch_AddOns", panel, "UIPanelButtonTemplate")
    twitch:SetSize(120, 22)
    twitch:SetPoint("TOPLEFT", twitchUrl, "BOTTOMLEFT", 0, -6)
    twitch:SetText("Copy Twitch")
    twitch:SetScript("OnClick", function()
        ShowCopyLinkPopup(TWITCH_URL)
    end)
    SetTooltip(
        twitch,
        "Copy Twitch",
        "Opens a copy box with the Twitch URL selected. Press Ctrl+C."
    )

    local sep2 = panel:CreateTexture(nil, "ARTWORK")
    sep2:SetColorTexture(1, 1, 1, 0.15)
    sep2:SetHeight(1)
    sep2:SetPoint("TOPLEFT", twitch, "BOTTOMLEFT", 0, -12)
    sep2:SetPoint("RIGHT", panel, "RIGHT", -16, 0)

    local optsHeader = panel:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    optsHeader:SetPoint("TOPLEFT", sep2, "BOTTOMLEFT", 0, -10)
    optsHeader:SetText("Options")

    local cb1 = CreateFrame("CheckButton", "ZWP_OptionTomTomOverride_AddOns", panel, "InterfaceOptionsCheckButtonTemplate")
    cb1:SetPoint("TOPLEFT", optsHeader, "BOTTOMLEFT", 0, -8)
    cb1.Text:SetText("Override TomTom Clear Distance on Login")
    SetTooltip(
        cb1,
        "Override TomTom Clear Distance on Login",
        "When enabled, ZygorWaypoint sets TomTom clear-distance to 0 on login/reload."
    )

    local cb2 = CreateFrame("CheckButton", "ZWP_OptionArrowAlignment_AddOns", panel, "InterfaceOptionsCheckButtonTemplate")
    cb2:SetPoint("TOPLEFT", cb1, "BOTTOMLEFT", 0, -8)
    cb2.Text:SetText("Align TomTom Arrow to Zygor Text")
    SetTooltip(
        cb2,
        "Align TomTom Arrow to Zygor Text",
        "When enabled, TomTom's Crazy Arrow anchors to Zygor's arrow frame position."
    )

    local cb3 = CreateFrame("CheckButton", "ZWP_OptionZygorRouting_AddOns", panel, "InterfaceOptionsCheckButtonTemplate")
    cb3:SetPoint("TOPLEFT", cb2, "BOTTOMLEFT", 0, -8)
    cb3.Text:SetText("Route TomTom Waypoints via Zygor Travel")
    SetTooltip(
        cb3,
        "Route TomTom Waypoints via Zygor Travel",
        "When enabled, TomTom waypoints are mirrored through Zygor pathfinding."
    )

    local cb4 = CreateFrame("CheckButton", "ZWP_OptionTomTomZygorSkin_AddOns", panel, "InterfaceOptionsCheckButtonTemplate")
    cb4:SetPoint("TOPLEFT", cb3, "BOTTOMLEFT", 0, -8)
    cb4.Text:SetText("Use Zygor Skin for TomTom Arrow")
    SetTooltip(
        cb4,
        "Use Zygor Skin for TomTom Arrow",
        "When enabled, TomTom's Crazy Arrow uses Zygor Starlight or Stealth art."
    )

    local skinChoice = CreateFrame("Button", "ZWP_OptionTomTomSkinChoice_AddOns", panel, "UIPanelButtonTemplate")
    skinChoice:SetSize(130, 22)
    skinChoice:SetPoint("TOPLEFT", cb4, "BOTTOMLEFT", 28, -6)
    UpdateSkinChoiceText(skinChoice, C.SKIN_STARLIGHT)
    skinChoice:SetScript("OnClick", function(self)
        local nextSkin = self:GetParent().selectedCustomSkin == C.SKIN_STEALTH and C.SKIN_STARLIGHT or C.SKIN_STEALTH
        self:GetParent().selectedCustomSkin = nextSkin
        UpdateSkinChoiceText(self, nextSkin)
    end)
    SetTooltip(
        skinChoice,
        "TomTom Zygor Skin",
        "Cycles between the Zygor Starlight and Stealth TomTom skins."
    )

    local scale = CreateFrame("Slider", "ZWP_OptionArrowScale_AddOns", panel, "OptionsSliderTemplate")
    scale:SetPoint("TOPLEFT", skinChoice, "BOTTOMLEFT", -20, -24)
    scale:SetWidth(220)
    scale:SetMinMaxValues(C.SCALE_MIN, C.SCALE_MAX)
    scale:SetValueStep(C.SCALE_STEP)
    if scale.SetObeyStepOnDrag then
        scale:SetObeyStepOnDrag(true)
    end
    _G[scale:GetName() .. "Low"]:SetText(string.format("%.2f", C.SCALE_MIN))
    _G[scale:GetName() .. "High"]:SetText(string.format("%.2f", C.SCALE_MAX))
    scale:SetScript("OnValueChanged", function(self)
        UpdateScaleText(self)
    end)
    SetTooltip(
        scale,
        "TomTom Arrow Scale",
        "Applies only when a Zygor TomTom skin is enabled."
    )

    cb4:SetScript("OnClick", function(self)
        scale:SetEnabled(self:GetChecked())
        if skinChoice.Enable and skinChoice.Disable then
            if self:GetChecked() then
                skinChoice:Enable()
            else
                skinChoice:Disable()
            end
        end
    end)

    panel.cb1 = cb1
    panel.cb2 = cb2
    panel.cb3 = cb3
    panel.cb4 = cb4
    panel.skinChoice = skinChoice
    panel.scale = scale

    local apply = CreateFrame("Button", "ZWP_ApplyAndReload_AddOns", panel, "UIPanelButtonTemplate")
    apply:SetSize(160, 24)
    apply:SetPoint("TOPLEFT", scale, "BOTTOMLEFT", -8, -22)
    apply:SetText("Apply and Reload")
    apply:SetScript("OnClick", function()
        local db = NS.GetDB()
        db.tomtomOverride = cb1:GetChecked() and true or false
        db.arrowAlignment = cb2:GetChecked() and true or false
        db.zygorRouting = cb3:GetChecked() and true or false
        db.tomtomSkin = cb4:GetChecked() and (panel.selectedCustomSkin or C.SKIN_STARLIGHT) or C.SKIN_DEFAULT
        db.tomtomArrowScale = NS.NormalizeScale(scale:GetValue())
        NS.Msg("ZygorWaypoint options saved. Reloading UI...")
        ReloadUI()
    end)

    panel:SetScript("OnShow", function(self)
        local db = NS.ApplyDBDefaults()

        self.cb1:SetChecked(db.tomtomOverride)
        self.cb2:SetChecked(db.arrowAlignment)
        self.cb3:SetChecked(db.zygorRouting)

        local skinChoice = NS.GetSkinChoice()
        local useCustomSkin = skinChoice ~= C.SKIN_DEFAULT
        self.selectedCustomSkin = useCustomSkin and skinChoice or (self.selectedCustomSkin or C.SKIN_STARLIGHT)
        self.cb4:SetChecked(useCustomSkin)
        UpdateSkinChoiceText(self.skinChoice, self.selectedCustomSkin)

        self.scale:SetValue(NS.GetArrowScale())
        UpdateScaleText(self.scale)
        self.scale:SetEnabled(useCustomSkin)
        if self.skinChoice.Enable and self.skinChoice.Disable then
            if useCustomSkin then
                self.skinChoice:Enable()
            else
                self.skinChoice:Disable()
            end
        end
    end)

    return panel
end

function NS.RegisterOptionsPanel()
    NS.ApplyDBDefaults()
    local panel = NS.CreateOptionsPanel()

    if Settings and Settings.RegisterCanvasLayoutCategory and Settings.RegisterAddOnCategory then
        if not panel.settingsCategory then
            local category = Settings.RegisterCanvasLayoutCategory(panel, "ZygorWaypoint")
            Settings.RegisterAddOnCategory(category)
            panel.settingsCategory = category
        end
    elseif InterfaceOptions_AddCategory and not panel.added then
        InterfaceOptions_AddCategory(panel)
        panel.added = true
    end
end

function NS.OpenOptionsPanel()
    NS.RegisterOptionsPanel()
    local panel = optionsPanel
    if not panel then return end

    if Settings and Settings.OpenToCategory and panel.settingsCategory then
        if type(panel.settingsCategory.GetID) == "function" then
            local categoryID = panel.settingsCategory:GetID()
            if type(categoryID) == "number" then
                Settings.OpenToCategory(categoryID)
                return
            end
        end

        Settings.OpenToCategory(panel.settingsCategory)
        return
    end

    if InterfaceOptionsFrame_OpenToCategory then
        InterfaceOptionsFrame_OpenToCategory(panel)
        InterfaceOptionsFrame_OpenToCategory(panel)
        return
    end

    panel:Show()
end
