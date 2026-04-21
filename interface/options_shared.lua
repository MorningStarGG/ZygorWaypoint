local NS = _G.ZygorWaypointNS
local C = NS.Constants
NS.Internal.Interface = NS.Internal.Interface or {}
NS.Internal.Interface.options = NS.Internal.Interface.options or {}

local M = NS.Internal.Interface.options

-- ============================================================
-- Constants and defaults
-- ============================================================

local ADDON_NAME = NS.ADDON_NAME
local ABOUT_ICON = "Interface\\AddOns\\ZygorWaypoint\\media\\icon.png"
local TWITCH_URL = "https://www.twitch.tv/MorningStarGG"
local TWITCH_COPY_POPUP = "ZWP_COPY_TWITCH_URL"
local RELOAD_RECOMMENDED_POPUP = "ZWP_RELOAD_RECOMMENDED"
local WAYPOINT_UI_RECOMMEND_POPUP = "ZWP_RECOMMEND_NATIVE_OVERLAY"
local WAYPOINT_UI_ADDON_NAME = "WaypointUI"
local ABOUT_SUMMARY = "Navigation bridge and 3D overlay for Zygor Guides and TomTom."
local ABOUT_DESCRIPTION = table.concat({
    "ZygorWaypoint keeps TomTom and Zygor Guides synced and adds an 3D overlay.",
    "",
    "- Uses TomTom's Crazy Arrow as the main navigation arrow",
    "- Can route TomTom waypoints through Zygor's travel system",
    "- Includes 3D waypoint, pinpoint, navigator, and plaque world overlay UI",
    "- Supports Zygor Starlight and Stealth skins for TomTom's arrow",
    "- Supports compact guide presentation including transparent step backgrounds",
    "- Imported /ttpaste waypoints function as ordered queues",
    "- Supports manual waypoint auto-clear with adjustable arrival distance",
    "- Includes `/zwp search` helpers for common services and professions",
}, "\n")
local ABOUT_CARD_HEIGHT = 340

local GetTomTom = NS.GetTomTom
local GetAddonMetadataValue = NS.GetAddonMetadataValue

-- ============================================================
-- Static popup helpers
-- ============================================================

local function GetStaticPopupPreferredIndex()
    return _G["STATICPOPUP_NUMDIALOGS"] or 4
end

local DB_DEFAULTS = NS.Internal.DBDefaults
local DEFAULTS = {}
for key, value in pairs(DB_DEFAULTS) do
    DEFAULTS[key] = value
end
DEFAULTS.useCustomSkin = true
DEFAULTS.customSkin = C.SKIN_STARLIGHT
M.rememberedCustomSkin = M.rememberedCustomSkin or DEFAULTS.customSkin

local function ShowCopyLinkPopup(url)
    if not StaticPopupDialogs[TWITCH_COPY_POPUP] then
        StaticPopupDialogs[TWITCH_COPY_POPUP] = {
            text = "Copy Twitch URL (Ctrl+C):",
            button1 = OKAY,
            hasEditBox = 1,
            editBoxWidth = 320,
            timeout = 0,
            whileDead = 1,
            hideOnEscape = 1,
            preferredIndex = GetStaticPopupPreferredIndex(),
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

local function ShowReloadRecommendedPopup(settingName)
    if not StaticPopupDialogs[RELOAD_RECOMMENDED_POPUP] then
        StaticPopupDialogs[RELOAD_RECOMMENDED_POPUP] = {
            text = "A reload is recommended after changing \"%s\".\n\nReload now?",
            button1 = RELOADUI or "Reload Now",
            button2 = "Not Now",
            timeout = 0,
            whileDead = 1,
            hideOnEscape = 1,
            preferredIndex = GetStaticPopupPreferredIndex(),
            OnAccept = function()
                ReloadUI()
            end,
        }
    end

    if StaticPopup_Visible(RELOAD_RECOMMENDED_POPUP) then
        return
    end

    StaticPopup_Show(RELOAD_RECOMMENDED_POPUP, settingName or "this setting")
end

local function IsWaypointUIRecommendationRelevant()
    if type(NS.IsWorldOverlayEnabled) ~= "function" or NS.IsWorldOverlayEnabled() ~= true then
        return false
    end

    return type(NS.IsAddonEnabledForCurrentCharacter) == "function"
        and NS.IsAddonEnabledForCurrentCharacter(WAYPOINT_UI_ADDON_NAME)
        or false
end

local function EnsureWaypointUIRecommendPopup()
    if StaticPopupDialogs[WAYPOINT_UI_RECOMMEND_POPUP] then
        return
    end

    StaticPopupDialogs[WAYPOINT_UI_RECOMMEND_POPUP] = {
        text = table.concat({
            "WaypointUI is enabled for this character.",
            "",
            "ZygorWaypoint's 3D overlay is already active, so you can compare both live right now.",
            "For the better recommended setup, disable WaypointUI for this character and reload.",
        }, "\n"),
        button1 = "Disable + Reload",
        button2 = "Keep Enabled",
        timeout = 0,
        whileDead = 1,
        hideOnEscape = 1,
        preferredIndex = GetStaticPopupPreferredIndex(),
        OnAccept = function()
            local ok = type(NS.DisableAddonForCurrentCharacter) == "function"
                and NS.DisableAddonForCurrentCharacter(WAYPOINT_UI_ADDON_NAME)
                or false
            if ok then
                if type(NS.MarkPendingOverviewReplayForCurrentCharacter) == "function" then
                    NS.MarkPendingOverviewReplayForCurrentCharacter()
                end
                ReloadUI()
            else
                NS.Msg("Unable to disable WaypointUI automatically. Disable it for this character in the AddOns list.")
            end
        end,
    }
end

function NS.MaybeShowWaypointUIRecommendationPopup()
    if not IsWaypointUIRecommendationRelevant() then
        return
    end
    if type(NS.GetWaypointUIPromptVersion) == "function" and NS.GetWaypointUIPromptVersion() == NS.VERSION then
        return
    end
    if StaticPopup_Visible(WAYPOINT_UI_RECOMMEND_POPUP) then
        return
    end

    EnsureWaypointUIRecommendPopup()
    local dialog = StaticPopup_Show(WAYPOINT_UI_RECOMMEND_POPUP)
    if dialog and type(NS.MarkWaypointUIPromptShown) == "function" then
        NS.MarkWaypointUIPromptShown()
    end
end

function NS.MaybeAnnounceWaypointUIRecommendation()
    if not IsWaypointUIRecommendationRelevant() then
        return
    end

    NS.Msg("WaypointUI is still enabled. ZWP's 3D overlay is already active so you can compare both live. Disable WaypointUI when you're ready for the better native setup.")
end

-- ============================================================
-- Apply helpers
-- ============================================================

local function ApplySkinAndScale()
    local tomtom = GetTomTom()
    NS.ApplyTomTomScalePolicy()
    NS.HookTomTomThemeBridge()
    NS.ApplyTomTomArrowSkin()

    local db = NS.GetDB()
    if db.arrowAlignment ~= false then
        NS.AlignTomTomToZygor()
        NS.HookUnifiedArrowDrag()
    end

    if tomtom and type(tomtom.ShowHideCrazyArrow) == "function" then
        tomtom:ShowHideCrazyArrow()
    end
end

local function RefreshViewerChromeMode()
    NS.HookZygorViewerChromeMode()
    NS.RefreshZygorViewerChromeMode()
end

-- ============================================================
-- About card
-- ============================================================

local function CreateAboutCardInitializer()
    local initializer = CreateFromMixins(
        ScrollBoxFactoryInitializerMixin,
        SettingsElementHierarchyMixin,
        SettingsSearchableElementMixin
    )

    function initializer:Init()
        ScrollBoxFactoryInitializerMixin.Init(self, "SettingsListElementTemplate")
        self.data = {
            name = "About",
            tooltip = ABOUT_SUMMARY,
        }
        self:AddSearchTags("About")
        self:AddSearchTags(ADDON_NAME)
        self:AddSearchTags("MorningStarGG")
        self:AddSearchTags("Twitch")
        self:AddSearchTags("TomTom")
        self:AddSearchTags("Zygor")
        self:AddSearchTags("Help")
        self:AddSearchTags("What's New")
    end

    function initializer:GetExtent()
        return ABOUT_CARD_HEIGHT
    end

    function initializer:InitFrame(frame)
        frame:SetHeight(self:GetExtent())
        if frame.Text then
            frame.Text:SetText("")
            frame.Text:Hide()
        end

        local card = frame.aboutCard
        if not card then
            card = CreateFrame("Frame", nil, frame)
            frame.aboutCard = card
            card:SetPoint("TOPLEFT", frame, "TOPLEFT", 0, -4)
            card:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -8, -4)
            card:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", 0, 4)

            card.icon = card:CreateTexture(nil, "ARTWORK")
            card.icon:SetSize(96, 96)
            card.icon:SetPoint("TOPLEFT", 8, -4)

            card.title = card:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
            card.title:SetPoint("TOPLEFT", card.icon, "TOPRIGHT", 16, 0)
            card.title:SetPoint("RIGHT", card, "RIGHT", -8, 0)
            card.title:SetJustifyH("LEFT")

            card.version = card:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
            card.version:SetPoint("TOPLEFT", card.title, "BOTTOMLEFT", 0, -4)
            card.version:SetPoint("RIGHT", card, "RIGHT", -8, 0)
            card.version:SetJustifyH("LEFT")

            card.summary = card:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
            card.summary:SetPoint("TOPLEFT", card.version, "BOTTOMLEFT", 0, -4)
            card.summary:SetPoint("RIGHT", card, "RIGHT", -8, 0)
            card.summary:SetJustifyH("LEFT")
            card.summary:SetWordWrap(true)

            card.separator = card:CreateTexture(nil, "ARTWORK")
            card.separator:SetColorTexture(1, 1, 1, 0.14)
            card.separator:SetHeight(1)
            card.separator:SetPoint("TOPLEFT", card, "TOPLEFT", 8, -112)
            card.separator:SetPoint("TOPRIGHT", card, "TOPRIGHT", -8, -112)

            card.description = card:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
            card.description:SetPoint("TOPLEFT", card.separator, "BOTTOMLEFT", 0, -12)
            card.description:SetPoint("RIGHT", card, "RIGHT", -8, 0)
            card.description:SetJustifyH("LEFT")
            card.description:SetJustifyV("TOP")
            card.description:SetWordWrap(true)

            card.author = card:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
            card.author:SetPoint("TOPLEFT", card.description, "BOTTOMLEFT", 0, -10)
            card.author:SetPoint("RIGHT", card, "RIGHT", -8, 0)
            card.author:SetJustifyH("LEFT")

            card.twitch = card:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
            card.twitch:SetPoint("TOPLEFT", card.author, "BOTTOMLEFT", 0, -4)
            card.twitch:SetPoint("RIGHT", card, "RIGHT", -8, 0)
            card.twitch:SetJustifyH("LEFT")

            card.copyButton = CreateFrame("Button", nil, card, "UIPanelButtonTemplate")
            card.copyButton:SetSize(140, 22)
            card.copyButton:SetPoint("TOPLEFT", card.twitch, "BOTTOMLEFT", 0, -10)
            card.copyButton:SetText("Copy Twitch URL")
            card.copyButton:SetScript("OnClick", function()
                ShowCopyLinkPopup(TWITCH_URL)
            end)

            card.helpButton = CreateFrame("Button", nil, card, "UIPanelButtonTemplate")
            card.helpButton:SetSize(70, 22)
            card.helpButton:SetPoint("LEFT", card.copyButton, "RIGHT", 8, 0)
            card.helpButton:SetText("Help")
            card.helpButton:SetScript("OnClick", function()
                if type(NS.ShowHelp) == "function" then
                    NS.ShowHelp("overview")
                end
            end)

            card.changelogButton = CreateFrame("Button", nil, card, "UIPanelButtonTemplate")
            card.changelogButton:SetSize(100, 22)
            card.changelogButton:SetPoint("LEFT", card.helpButton, "RIGHT", 8, 0)
            card.changelogButton:SetText("What's New")
            card.changelogButton:SetScript("OnClick", function()
                if type(NS.ShowWhatsNew) == "function" then
                    NS.ShowWhatsNew()
                elseif type(NS.ShowChangelog) == "function" then
                    NS.ShowChangelog()
                end
            end)
        end

        card:Show()
        card.icon:SetTexture(ABOUT_ICON)
        card.title:SetText(ADDON_NAME)
        card.version:SetText("Version " .. GetAddonMetadataValue("Version", "2.2"))
        card.summary:SetText(ABOUT_SUMMARY)
        card.description:SetText(ABOUT_DESCRIPTION)
        card.author:SetText("Author: " .. GetAddonMetadataValue("Author", "MorningStarGG"))
        card.twitch:SetText("Twitch: " .. TWITCH_URL)
    end

    function initializer:Resetter(frame)
        if frame.aboutCard then
            frame.aboutCard:Hide()
        end
        if frame.Text then
            frame.Text:Show()
        end
    end

    initializer:Init()
    return initializer
end

-- ============================================================
-- Settings factories
-- ============================================================

local function CreateSkinOptions()
    local container = Settings.CreateControlTextContainer()
    container:Add(C.SKIN_STARLIGHT, "Starlight")
    container:Add(C.SKIN_STEALTH, "Stealth")
    return container:GetData()
end

local function CreateWorldOverlayInfoOptions()
    local container = Settings.CreateControlTextContainer()
    container:Add(C.WORLD_OVERLAY_INFO_ALL, "All")
    container:Add(C.WORLD_OVERLAY_INFO_DISTANCE, "Distance")
    container:Add(C.WORLD_OVERLAY_INFO_ARRIVAL, "Arrival Time")
    container:Add(C.WORLD_OVERLAY_INFO_DESTINATION, "Destination Name")
    container:Add(C.WORLD_OVERLAY_INFO_NONE, "None")
    return container:GetData()
end

local function CreateWorldOverlayColorModeOptions()
    local container = Settings.CreateControlTextContainer()
    container:Add(C.WORLD_OVERLAY_COLOR_DEFAULT, "Default")
    container:Add(C.WORLD_OVERLAY_COLOR_NONE, "None")
    container:Add(C.WORLD_OVERLAY_COLOR_GOLD, "Gold")
    container:Add(C.WORLD_OVERLAY_COLOR_WHITE, "White")
    container:Add(C.WORLD_OVERLAY_COLOR_SILVER, "Silver")
    container:Add(C.WORLD_OVERLAY_COLOR_CYAN, "Cyan")
    container:Add(C.WORLD_OVERLAY_COLOR_BLUE, "Blue")
    container:Add(C.WORLD_OVERLAY_COLOR_GREEN, "Green")
    container:Add(C.WORLD_OVERLAY_COLOR_RED, "Red")
    container:Add(C.WORLD_OVERLAY_COLOR_PURPLE, "Purple")
    container:Add(C.WORLD_OVERLAY_COLOR_PINK, "Pink")
    container:Add(C.WORLD_OVERLAY_COLOR_CUSTOM, "Custom")
    return container:GetData()
end

local function CreateWorldOverlayContextDisplayOptions()
    local container = Settings.CreateControlTextContainer()
    container:Add(C.WORLD_OVERLAY_CONTEXT_DISPLAY_DIAMOND_ICON, "Context Diamond + Icon")
    container:Add(C.WORLD_OVERLAY_CONTEXT_DISPLAY_ICON_ONLY, "Icon Only")
    container:Add(C.WORLD_OVERLAY_CONTEXT_DISPLAY_HIDDEN, "Hidden")
    return container:GetData()
end

local function CreateWorldOverlayBeaconStyleOptions()
    local container = Settings.CreateControlTextContainer()
    container:Add(C.WORLD_OVERLAY_BEACON_STYLE_BEACON, "Beacon")
    container:Add(C.WORLD_OVERLAY_BEACON_STYLE_BASE, "Base Only")
    container:Add(C.WORLD_OVERLAY_BEACON_STYLE_OFF,  "Off")
    return container:GetData()
end

local function CreateWorldOverlayWaypointModeOptions()
    local container = Settings.CreateControlTextContainer()
    container:Add(C.WORLD_OVERLAY_WAYPOINT_MODE_FULL,     "Enabled")
    container:Add(C.WORLD_OVERLAY_WAYPOINT_MODE_DISABLED, "Disabled")
    return container:GetData()
end

local function CreateWorldOverlayPinpointModeOptions()
    local container = Settings.CreateControlTextContainer()
    container:Add(C.WORLD_OVERLAY_PINPOINT_MODE_FULL,      "Full")
    container:Add(C.WORLD_OVERLAY_PINPOINT_MODE_NO_PLAQUE, "Plaque Off")
    container:Add(C.WORLD_OVERLAY_PINPOINT_MODE_DISABLED,  "Disabled")
    return container:GetData()
end

local function CreateWorldOverlayPlaqueTypeOptions()
    local container = Settings.CreateControlTextContainer()
    container:Add(C.WORLD_OVERLAY_PLAQUE_DEFAULT, "Default")
    container:Add(C.WORLD_OVERLAY_PLAQUE_GLOWING_GEMS, "Glowing Gems")
    container:Add(C.WORLD_OVERLAY_PLAQUE_HORDE,   "Horde")
    container:Add(C.WORLD_OVERLAY_PLAQUE_ALLIANCE,"Alliance")
    container:Add(C.WORLD_OVERLAY_PLAQUE_MODERN,  "Modern")
    container:Add(C.WORLD_OVERLAY_PLAQUE_STEAMPUNK, "Steampunk")
    return container:GetData()
end

local function RefreshWorldOverlay()
    NS.RefreshWorldOverlay()
end

local function FormatWorldOverlayDistance(value)
    local yards = tonumber(value) or 0
    if NS.GetWorldOverlaySetting("worldOverlayUseMeters") then
        local meters = yards * 0.9144
        if meters >= 1000 then
            return string.format("%.1f km", meters / 1000)
        end
        return string.format("%d m", meters + 0.5)
    end

    return string.format("%d yd", yards + 0.5)
end

local function CreateProxySetting(category, key, varType, name, defaultValue, getValue, setValue)
    return Settings.RegisterProxySetting(
        category,
        "ZWP_" .. key,
        varType,
        name,
        defaultValue,
        getValue,
        setValue
    )
end

local function AddSectionHeader(category, text)
    local layout = SettingsPanel and SettingsPanel.GetLayout and SettingsPanel:GetLayout(category) or nil
    if layout then
        layout:AddInitializer(CreateSettingsListSectionHeaderInitializer(text))
    end
end

local function AddCheckbox(category, key, name, defaultValue, tooltip, getValue, setValue)
    local setting = CreateProxySetting(category, key, Settings.VarType.Boolean, name, defaultValue, getValue, setValue)
    return Settings.CreateCheckbox(category, setting, tooltip)
end

local function AddSlider(category, key, name, defaultValue, minValue, maxValue, step, formatter, tooltip, getValue, setValue)
    local setting = CreateProxySetting(category, key, Settings.VarType.Number, name, defaultValue, getValue, setValue)
    local options = Settings.CreateSliderOptions(minValue, maxValue, step)
    options:SetLabelFormatter(MinimalSliderWithSteppersMixin.Label.Right, formatter)
    return Settings.CreateSlider(category, setting, options, tooltip)
end

local function AddDropdown(category, key, name, defaultValue, getValue, setValue, getOptions, tooltip)
    local setting = CreateProxySetting(category, key, Settings.VarType.String, name, defaultValue, getValue, setValue)
    return Settings.CreateDropdown(category, setting, getOptions, tooltip)
end

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

local function AddColorDropdownWithSwatch(category, layout, name, tooltip, modeSettingKey, customColorSettingKey)
    local defs = NS.Internal.OverlaySettingDefs
    local customDef = defs and defs[customColorSettingKey] or nil
    local customDefault = customDef and customDef.default
        or C.WORLD_OVERLAY_COLOR_PRESETS[C.WORLD_OVERLAY_COLOR_GOLD]
        or { r = 0.95, g = 0.84, b = 0.44 }

    local initializer
    local setting = CreateProxySetting(
        category,
        customColorSettingKey .. "_MODE",
        Settings.VarType.String,
        name,
        C.WORLD_OVERLAY_COLOR_DEFAULT,
        function()
            return NS.GetWorldOverlaySetting(modeSettingKey)
        end,
        function(value)
            NS.SetWorldOverlaySetting(modeSettingKey, value)
            RefreshWorldOverlay()
            local frame = initializer and initializer.boundFrame or nil
            if frame and type(frame.RefreshCustomButton) == "function" then
                frame:RefreshCustomButton()
            end
        end
    )

    layout = layout or (SettingsPanel and SettingsPanel.GetLayout and SettingsPanel:GetLayout(category)) or nil
    if not layout then
        return nil
    end

    initializer = Settings.CreateControlInitializer(
        "ZWPWorldOverlayColorDropdownControlTemplate",
        setting,
        CreateWorldOverlayColorModeOptions,
        tooltip
    )
    initializer.modeSettingKey = modeSettingKey
    initializer.customColorSettingKey = customColorSettingKey
    initializer.customDefault = CopyColorTable(customDefault)
    initializer.displayName = name
    initializer.inlineTooltip = tooltip
    initializer.SetCustomColor = function(self, color)
        NS.SetWorldOverlaySetting(self.customColorSettingKey, CopyColorTable(color, self.customDefault))
        RefreshWorldOverlay()
        local frame = self.boundFrame
        if frame and type(frame.RefreshCustomButton) == "function" then
            frame:RefreshCustomButton()
        end
    end

    layout:AddInitializer(initializer)
    return initializer
end

M.ADDON_NAME = ADDON_NAME
M.DEFAULTS = DEFAULTS
M.ShowCopyLinkPopup = ShowCopyLinkPopup
M.ShowReloadRecommendedPopup = ShowReloadRecommendedPopup
M.ApplySkinAndScale = ApplySkinAndScale
M.RefreshViewerChromeMode = RefreshViewerChromeMode
M.CreateAboutCardInitializer = CreateAboutCardInitializer
M.CreateSkinOptions = CreateSkinOptions
M.CreateWorldOverlayInfoOptions = CreateWorldOverlayInfoOptions
M.CreateWorldOverlayColorModeOptions = CreateWorldOverlayColorModeOptions
M.CreateWorldOverlayContextDisplayOptions = CreateWorldOverlayContextDisplayOptions
M.CreateWorldOverlayBeaconStyleOptions = CreateWorldOverlayBeaconStyleOptions
M.CreateWorldOverlayPlaqueTypeOptions = CreateWorldOverlayPlaqueTypeOptions
M.CreateWorldOverlayWaypointModeOptions = CreateWorldOverlayWaypointModeOptions
M.CreateWorldOverlayPinpointModeOptions = CreateWorldOverlayPinpointModeOptions
M.RefreshWorldOverlay = RefreshWorldOverlay
M.FormatWorldOverlayDistance = FormatWorldOverlayDistance
M.CreateProxySetting = CreateProxySetting
M.AddSectionHeader = AddSectionHeader
M.AddCheckbox = AddCheckbox
M.AddSlider = AddSlider
M.AddDropdown = AddDropdown
M.AddColorDropdownWithSwatch = AddColorDropdownWithSwatch
