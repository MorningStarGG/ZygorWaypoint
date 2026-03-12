local NS = _G.ZygorWaypointNS
local C = NS.Constants

local optionsPanel
local ADDON_NAME = "ZygorWaypoint"
local ABOUT_ICON = "Interface\\AddOns\\ZygorWaypoint\\media\\icon.png"
local TWITCH_URL = "https://www.twitch.tv/MorningStarGG"
local TWITCH_COPY_POPUP = "ZWP_COPY_TWITCH_URL"
local RELOAD_RECOMMENDED_POPUP = "ZWP_RELOAD_RECOMMENDED"
local ABOUT_SUMMARY = "A bridge between Zygor Guides and TomTom's Crazy Arrow."
local ABOUT_DESCRIPTION = table.concat({
    "ZygorWaypoint bridges Zygor Guides and TomTom, using TomTom's Crazy Arrow for navigation while Zygor handles travel routing.",
    "",
    "- Uses Zygor's Travel System to calculate optimal navigation routes",
    "- Displays TomTom's Crazy Arrow as the navigation arrow",
    "- Hides Zygor's arrow while keeping navigation text visible",
    "- Optional routing of TomTom waypoints through Zygor's Travel System",
    "- Optional alignment of TomTom's arrow with Zygor's navigation text",
    "- Optional Zygor Starlight or Stealth skins for TomTom's arrow",
    "- Optional arrow scale control when using Zygor skins",
    "- Optional manual waypoint auto-clear on arrival with distance control",
    "- `/zwp search` commands for routing to common NPCs/Objects",
}, "\n")
local ABOUT_CARD_HEIGHT = 340

local DEFAULTS = {
    tomtomOverride = true,
    arrowAlignment = true,
    zygorRouting = true,
    guideStepsOnlyHover = false,
    manualWaypointAutoClear = false,
    manualWaypointClearDistance = C.MANUAL_CLEAR_DISTANCE_DEFAULT,
    useCustomSkin = true,
    customSkin = C.SKIN_STARLIGHT,
    tomtomArrowScale = C.SCALE_DEFAULT,
}

local rememberedCustomSkin = DEFAULTS.customSkin

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

local function ShowReloadRecommendedPopup(settingName)
    if not StaticPopupDialogs then
        NS.Msg("Reload recommended after changing", settingName .. ". Use /reload when convenient.")
        return
    end

    if not StaticPopupDialogs[RELOAD_RECOMMENDED_POPUP] then
        StaticPopupDialogs[RELOAD_RECOMMENDED_POPUP] = {
            text = "A reload is recommended after changing \"%s\".\n\nReload now?",
            button1 = RELOADUI or "Reload Now",
            button2 = "Not Now",
            timeout = 0,
            whileDead = 1,
            hideOnEscape = 1,
            preferredIndex = STATICPOPUP_NUMDIALOGS,
            OnAccept = function()
                ReloadUI()
            end,
        }
    end

    if type(StaticPopup_Visible) == "function" and StaticPopup_Visible(RELOAD_RECOMMENDED_POPUP) then
        return
    end

    StaticPopup_Show(RELOAD_RECOMMENDED_POPUP, settingName or "this setting")
end

local function ApplySkinAndScale()
    NS.ApplyTomTomScalePolicy()

    if NS.HookTomTomThemeBridge then
        NS.HookTomTomThemeBridge()
    end
    if NS.ApplyTomTomArrowSkin then
        NS.ApplyTomTomArrowSkin()
    end

    local db = NS.GetDB()
    if db.arrowAlignment ~= false then
        NS.AlignTomTomToZygor()
        NS.HookUnifiedArrowDrag()
    end

    if TomTom and type(TomTom.ShowHideCrazyArrow) == "function" then
        TomTom:ShowHideCrazyArrow()
    end
end

local function RefreshViewerChromeMode()
    if NS.HookZygorViewerChromeMode then
        NS.HookZygorViewerChromeMode()
    end
    if NS.RefreshZygorViewerChromeMode then
        NS.RefreshZygorViewerChromeMode()
    end
end

local function GetAddonMetadataValue(field, fallback)
    local value
    if C_AddOns and type(C_AddOns.GetAddOnMetadata) == "function" then
        value = C_AddOns.GetAddOnMetadata(ADDON_NAME, field)
    elseif type(GetAddOnMetadata) == "function" then
        value = GetAddOnMetadata(ADDON_NAME, field)
    end

    if value == nil or value == "" then
        return fallback
    end
    return value
end

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
            card.copyButton:SetSize(160, 22)
            card.copyButton:SetPoint("TOPLEFT", card.twitch, "BOTTOMLEFT", 0, -10)
            card.copyButton:SetText("Copy Twitch URL")
            card.copyButton:SetScript("OnClick", function()
                ShowCopyLinkPopup(TWITCH_URL)
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

local function CreateSkinOptions()
    local container = Settings.CreateControlTextContainer()
    container:Add(C.SKIN_STARLIGHT, "Starlight")
    container:Add(C.SKIN_STEALTH, "Stealth")
    return container:GetData()
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

local function AddCheckbox(category, key, name, defaultValue, tooltip, getValue, setValue)
    local setting = CreateProxySetting(category, key, Settings.VarType.Boolean, name, defaultValue, getValue, setValue)
    Settings.CreateCheckbox(category, setting, tooltip)
end

local function AddSlider(category, key, name, defaultValue, minValue, maxValue, step, formatter, tooltip, getValue, setValue)
    local setting = CreateProxySetting(category, key, Settings.VarType.Number, name, defaultValue, getValue, setValue)
    local options = Settings.CreateSliderOptions(minValue, maxValue, step)
    options:SetLabelFormatter(MinimalSliderWithSteppersMixin.Label.Right, formatter)
    Settings.CreateSlider(category, setting, options, tooltip)
end

local function AddDropdown(category, key, name, defaultValue, getValue, setValue, getOptions, tooltip)
    local setting = CreateProxySetting(category, key, Settings.VarType.String, name, defaultValue, getValue, setValue)
    Settings.CreateDropdown(category, setting, getOptions, tooltip)
end

local function InitializeOptionsPanel()
    if optionsPanel then
        return optionsPanel
    end

    if not (Settings and Settings.RegisterVerticalLayoutCategory and Settings.RegisterAddOnCategory) then
        return
    end

    NS.ApplyDBDefaults()

    local category, layout = Settings.RegisterVerticalLayoutCategory("ZygorWaypoint")
    optionsPanel = {
        settingsCategory = category,
        settingsLayout = layout,
    }

    local currentSkin = NS.GetSkinChoice()
    if currentSkin ~= C.SKIN_DEFAULT then
        rememberedCustomSkin = currentSkin
    end

    layout:AddInitializer(CreateAboutCardInitializer())

    layout:AddInitializer(CreateSettingsListSectionHeaderInitializer("Navigation"))

    AddCheckbox(
        category,
        "TOMTOM_OVERRIDE",
        "Override TomTom Clear Distance on Login",
        DEFAULTS.tomtomOverride,
        "When enabled, ZygorWaypoint sets TomTom clear-distance to 0 on login/reload.",
        function()
            return NS.GetDB().tomtomOverride ~= false
        end,
        function(value)
            local db = NS.GetDB()
            local oldValue = db.tomtomOverride ~= false
            local newValue = value and true or false
            db.tomtomOverride = newValue
            if value and TomTom and TomTom.db and TomTom.db.profile and TomTom.db.profile.persistence then
                TomTom.db.profile.persistence.cleardistance = 0
            end
            if oldValue ~= newValue then
                ShowReloadRecommendedPopup("Override TomTom Clear Distance on Login")
            end
        end
    )

    AddCheckbox(
        category,
        "MANUAL_AUTO_CLEAR",
        "Auto-Clear Manual Waypoints on Arrival",
        DEFAULTS.manualWaypointAutoClear,
        "When enabled, ZygorWaypoint clears true manual destinations when you enter the selected yard range. Nearest NPC searches are not auto-cleared.",
        function()
            return NS.IsManualWaypointAutoClearEnabled()
        end,
        function(value)
            NS.SetManualWaypointAutoClearEnabled(value)
        end
    )

    AddSlider(
        category,
        "MANUAL_CLEAR_DISTANCE",
        "Manual Waypoint Clear Distance",
        DEFAULTS.manualWaypointClearDistance,
        C.MANUAL_CLEAR_DISTANCE_MIN,
        C.MANUAL_CLEAR_DISTANCE_MAX,
        C.MANUAL_CLEAR_DISTANCE_STEP,
        function(value)
            return string.format("%d yd", NS.NormalizeManualWaypointClearDistance(value))
        end,
        "Clears the active manual waypoint, mirrored TomTom pin, and Blizzard user waypoint when you arrive within this many yards.",
        function()
            return NS.GetManualWaypointClearDistance()
        end,
        function(value)
            NS.SetManualWaypointClearDistance(value)
        end
    )

    AddCheckbox(
        category,
        "ARROW_ALIGNMENT",
        "Align TomTom Arrow to Zygor Text",
        DEFAULTS.arrowAlignment,
        "When enabled, TomTom's Crazy Arrow anchors to Zygor's arrow frame position.",
        function()
            return NS.GetDB().arrowAlignment ~= false
        end,
        function(value)
            local db = NS.GetDB()
            local oldValue = db.arrowAlignment ~= false
            local newValue = value and true or false
            db.arrowAlignment = newValue
            if value then
                NS.AlignTomTomToZygor()
                NS.HookUnifiedArrowDrag()
            end
            if oldValue ~= newValue then
                ShowReloadRecommendedPopup("Align TomTom Arrow to Zygor Text")
            end
        end
    )

    AddCheckbox(
        category,
        "ZYGOR_ROUTING",
        "Route TomTom Waypoints via Zygor",
        DEFAULTS.zygorRouting,
        "When enabled, TomTom waypoints are mirrored through Zygor pathfinding.",
        function()
            return NS.IsRoutingEnabled()
        end,
        function(value)
            local db = NS.GetDB()
            db.zygorRouting = value and true or false
        end
    )

    AddCheckbox(
        category,
        "GUIDE_STEPS_ONLY_HOVER",
        "Show Only Guide Steps Until Mouseover",
        DEFAULTS.guideStepsOnlyHover,
        "Keeps the visible guide step rows on screen while fading out the rest of Zygor's guide frame until you mouse over it.",
        function()
            return NS.IsGuideStepsOnlyHoverEnabled()
        end,
        function(value)
            NS.SetGuideStepsOnlyHoverEnabled(value)
            RefreshViewerChromeMode()
        end
    )

    layout:AddInitializer(CreateSettingsListSectionHeaderInitializer("TomTom Arrow"))

    AddCheckbox(
        category,
        "USE_CUSTOM_SKIN",
        "Use Zygor Skin for TomTom Arrow",
        DEFAULTS.useCustomSkin,
        "When enabled, TomTom's Crazy Arrow uses Zygor Starlight or Stealth art.",
        function()
            return NS.GetSkinChoice() ~= C.SKIN_DEFAULT
        end,
        function(value)
            if value then
                NS.SetSkinChoice(rememberedCustomSkin or DEFAULTS.customSkin)
            else
                local current = NS.GetSkinChoice()
                if current ~= C.SKIN_DEFAULT then
                    rememberedCustomSkin = current
                end
                NS.SetSkinChoice(C.SKIN_DEFAULT)
            end
            ApplySkinAndScale()
        end
    )

    AddDropdown(
        category,
        "CUSTOM_SKIN",
        "TomTom Zygor Skin",
        DEFAULTS.customSkin,
        function()
            local skin = NS.GetSkinChoice()
            if skin == C.SKIN_DEFAULT then
                return rememberedCustomSkin or DEFAULTS.customSkin
            end
            rememberedCustomSkin = skin
            return skin
        end,
        function(value)
            rememberedCustomSkin = value
            if NS.GetSkinChoice() ~= C.SKIN_DEFAULT then
                NS.SetSkinChoice(value)
                ApplySkinAndScale()
            end
        end,
        CreateSkinOptions,
        "Selects the Zygor art used by TomTom when the custom skin option is enabled."
    )

    AddSlider(
        category,
        "ARROW_SCALE",
        "TomTom Arrow Scale",
        DEFAULTS.tomtomArrowScale,
        C.SCALE_MIN,
        C.SCALE_MAX,
        C.SCALE_STEP,
        function(value)
            return string.format("%.2fx", NS.NormalizeScale(value))
        end,
        "Applies only when a Zygor TomTom skin is enabled.",
        function()
            return NS.GetArrowScale()
        end,
        function(value)
            NS.SetArrowScale(value)
            ApplySkinAndScale()
        end
    )

    Settings.RegisterAddOnCategory(category)
    return optionsPanel
end

function NS.CreateOptionsPanel()
    return InitializeOptionsPanel()
end

function NS.RegisterOptionsPanel()
    return InitializeOptionsPanel()
end

function NS.OpenOptionsPanel()
    local panel = InitializeOptionsPanel()
    if not panel or not panel.settingsCategory or not (Settings and Settings.OpenToCategory) then
        return
    end

    local category = panel.settingsCategory
    if type(category.GetID) == "function" then
        local categoryID = category:GetID()
        if type(categoryID) == "number" then
            Settings.OpenToCategory(categoryID)
            return
        end
    end

    Settings.OpenToCategory(category)
end
