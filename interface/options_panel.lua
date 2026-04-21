local NS = _G.ZygorWaypointNS
local C = NS.Constants
local M = NS.Internal.Interface.options

local optionsPanel

local DEFAULTS = M.DEFAULTS
local CreateAboutCardInitializer = M.CreateAboutCardInitializer
local CreateSkinOptions = M.CreateSkinOptions
local ApplySkinAndScale = M.ApplySkinAndScale
local AddCheckbox = M.AddCheckbox
local AddSlider = M.AddSlider
local AddDropdown = M.AddDropdown

local function AddTomTomArrowOptions(category)
    AddCheckbox(
        category,
        "USE_CUSTOM_SKIN",
        "Use Zygor Arrow Skin for TomTom Arrow",
        DEFAULTS.useCustomSkin,
        "When enabled, TomTom's Crazy Arrow uses Zygor's Starlight or Stealth skins.",
        function()
            return NS.GetSkinChoice() ~= C.SKIN_DEFAULT
        end,
        function(value)
            if value then
                NS.SetSkinChoice(M.rememberedCustomSkin or DEFAULTS.customSkin)
            else
                local skin = NS.GetSkinChoice()
                if skin ~= C.SKIN_DEFAULT then
                    M.rememberedCustomSkin = skin
                end
                NS.SetSkinChoice(C.SKIN_DEFAULT)
            end
            ApplySkinAndScale()
        end
    )

    AddDropdown(
        category,
        "CUSTOM_SKIN",
        "TomTom Zygor Arrow Skin",
        DEFAULTS.customSkin,
        function()
            local skin = NS.GetSkinChoice()
            if skin == C.SKIN_DEFAULT then
                return M.rememberedCustomSkin or DEFAULTS.customSkin
            end
            M.rememberedCustomSkin = skin
            return skin
        end,
        function(value)
            M.rememberedCustomSkin = value
            if NS.GetSkinChoice() ~= C.SKIN_DEFAULT then
                NS.SetSkinChoice(value)
                ApplySkinAndScale()
            end
        end,
        CreateSkinOptions,
        "Select the Zygor skin to use for TomTom when 'Use Zygor Arrow Skin for TomTom Arrow' option is enabled."
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
end

local function InitializeOptionsPanel()
    if optionsPanel then
        return optionsPanel
    end

    if not (Settings and Settings.RegisterVerticalLayoutCategory and Settings.RegisterAddOnCategory) then
        return
    end

    NS.ApplyDBDefaults()

    local currentSkin = NS.GetSkinChoice()
    if currentSkin ~= C.SKIN_DEFAULT then
        M.rememberedCustomSkin = currentSkin
    end

    -- Parent category — About card only
    local category, layout = Settings.RegisterVerticalLayoutCategory("ZygorWaypoint")
    layout:AddInitializer(CreateAboutCardInitializer())

    -- Subcategories
    local tomtomCat  = Settings.RegisterVerticalLayoutSubcategory(category, "TomTom Arrow")
    local overlayCat = Settings.RegisterVerticalLayoutSubcategory(category, "World Overlay")

    -- World Overlay sub-subcategories
    local wpCat        = Settings.RegisterVerticalLayoutSubcategory(overlayCat, "Waypoint")
    local pinpointCat  = Settings.RegisterVerticalLayoutSubcategory(overlayCat, "Pinpoint")
    local navigatorCat = Settings.RegisterVerticalLayoutSubcategory(overlayCat, "Navigator")

    M.AddGeneralOptions(category)
    AddTomTomArrowOptions(tomtomCat)
    M.AddWorldOverlayOptions(overlayCat)
    M.AddWorldOverlayWaypointOptions(wpCat)
    M.AddWorldOverlayInfoTextOptions(wpCat)
    M.AddWorldOverlayPinpointOptions(pinpointCat)
    M.AddWorldOverlayNavigatorOptions(navigatorCat)

    Settings.RegisterAddOnCategory(category)

    optionsPanel = {
        settingsCategory = category,
        settingsLayout = layout,
    }
    return optionsPanel
end

function NS.RegisterOptionsPanel()
    return InitializeOptionsPanel()
end

function NS.OpenOptionsPanel()
    local panel = InitializeOptionsPanel()
    if not panel or not panel.settingsCategory or not Settings.OpenToCategory then
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
