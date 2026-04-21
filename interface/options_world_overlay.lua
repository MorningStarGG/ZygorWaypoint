local NS = _G.ZygorWaypointNS
local M = NS.Internal.Interface.options
local AddSectionHeader = M.AddSectionHeader
local AddCheckbox = M.AddCheckbox
local AddSlider = M.AddSlider
local AddDropdown = M.AddDropdown
local AddColorDropdownWithSwatch = M.AddColorDropdownWithSwatch
local RefreshWorldOverlay = M.RefreshWorldOverlay
local FormatWorldOverlayDistance = M.FormatWorldOverlayDistance
local CreateWorldOverlayInfoOptions = M.CreateWorldOverlayInfoOptions
local CreateWorldOverlayContextDisplayOptions = M.CreateWorldOverlayContextDisplayOptions
local CreateWorldOverlayBeaconStyleOptions = M.CreateWorldOverlayBeaconStyleOptions
local CreateWorldOverlayPlaqueTypeOptions = M.CreateWorldOverlayPlaqueTypeOptions
local CreateWorldOverlayWaypointModeOptions = M.CreateWorldOverlayWaypointModeOptions
local CreateWorldOverlayPinpointModeOptions = M.CreateWorldOverlayPinpointModeOptions
local DEFS = NS.Internal.OverlaySettingDefs

function M.AddWorldOverlayOptions(category)
    AddCheckbox(
        category,
        "WORLD_OVERLAY_ENABLED",
        "Enable 3D World Overlay",
        DEFS.worldOverlayEnabled.default,
        "Uses ZWP's 3D overlay for waypoint, pinpoint, navigator, and plaque presentation.",
        function()
            return NS.IsWorldOverlayEnabled()
        end,
        function(value)
            NS.SetWorldOverlaySetting("worldOverlayEnabled", value)
            RefreshWorldOverlay()
        end
    )

    AddCheckbox(
        category,
        "WORLD_OVERLAY_FADE_ON_HOVER",
        "Fade on Hover",
        DEFS.worldOverlayFadeOnHover.default,
        "Fades the 3D overlay when you hover over it.",
        function()
            return NS.GetWorldOverlaySetting("worldOverlayFadeOnHover")
        end,
        function(value)
            NS.SetWorldOverlaySetting("worldOverlayFadeOnHover", value)
            RefreshWorldOverlay()
        end
    )

    AddDropdown(
        category,
        "WORLD_OVERLAY_CONTEXT_DISPLAY_MODE",
        "Context Display",
        DEFS.worldOverlayContextDisplayMode.default,
        function()
            return NS.GetWorldOverlaySetting("worldOverlayContextDisplayMode")
        end,
        function(value)
            NS.SetWorldOverlaySetting("worldOverlayContextDisplayMode", value)
            RefreshWorldOverlay()
        end,
        CreateWorldOverlayContextDisplayOptions,
        "Controls the 3D overlay context marker. Context Diamond + Icon shows both layers. Icon Only hides the diamond. Hidden turns both off."
    )

    AddSectionHeader(category, "Colors")

    AddColorDropdownWithSwatch(
        category,
        nil,
        "Context Diamond",
        "Controls the color of the diamond behind waypoint, pinpoint, and navigator icons.",
        "worldOverlayContextDiamondColorMode",
        "worldOverlayContextDiamondCustomColor"
    )

    AddColorDropdownWithSwatch(
        category,
        nil,
        "Icons",
        "Controls the context icon color. Presets and Custom selections force a unified override tint.",
        "worldOverlayIconColorMode",
        "worldOverlayIconCustomColor"
    )
end

function M.AddWorldOverlayWaypointOptions(category)
    AddDropdown(
        category,
        "WORLD_OVERLAY_WAYPOINT_MODE",
        "Waypoint",
        DEFS.worldOverlayWaypointMode.default,
        function()
            return NS.GetWorldOverlaySetting("worldOverlayWaypointMode")
        end,
        function(value)
            NS.SetWorldOverlaySetting("worldOverlayWaypointMode", value)
            RefreshWorldOverlay()
        end,
        CreateWorldOverlayWaypointModeOptions,
        "Controls the waypoint beacon shown when the target is far away. Disabled hides the beacon, beacon, context diamond, and footer text entirely."
    )

    local def = DEFS.worldOverlayWaypointSize
    AddSlider(
        category,
        "WORLD_OVERLAY_WAYPOINT_SIZE",
        "Waypoint Size",
        def.default,
        def.min,
        def.max,
        def.step,
        function(value)
            return string.format("%.0f%%", value * 100)
        end,
        "Scales the 3D waypoint frame.",
        function()
            return NS.GetWorldOverlaySetting("worldOverlayWaypointSize")
        end,
        function(value)
            NS.SetWorldOverlaySetting("worldOverlayWaypointSize", value)
            RefreshWorldOverlay()
        end
    )

    def = DEFS.worldOverlayWaypointSizeMin
    AddSlider(
        category,
        "WORLD_OVERLAY_WAYPOINT_SIZE_MIN",
        "Waypoint Min Size",
        def.default,
        def.min,
        def.max,
        def.step,
        function(value)
            return string.format("%.0f%%", value * 100)
        end,
        "Minimum dynamic scale for the 3D waypoint.",
        function()
            return NS.GetWorldOverlaySetting("worldOverlayWaypointSizeMin")
        end,
        function(value)
            NS.SetWorldOverlaySetting("worldOverlayWaypointSizeMin", value)
            RefreshWorldOverlay()
        end
    )

    def = DEFS.worldOverlayWaypointSizeMax
    AddSlider(
        category,
        "WORLD_OVERLAY_WAYPOINT_SIZE_MAX",
        "Waypoint Max Size",
        def.default,
        def.min,
        def.max,
        def.step,
        function(value)
            return string.format("%.0f%%", value * 100)
        end,
        "Maximum dynamic scale for the 3D waypoint.",
        function()
            return NS.GetWorldOverlaySetting("worldOverlayWaypointSizeMax")
        end,
        function(value)
            NS.SetWorldOverlaySetting("worldOverlayWaypointSizeMax", value)
            RefreshWorldOverlay()
        end
    )

    def = DEFS.worldOverlayWaypointOpacity
    AddSlider(
        category,
        "WORLD_OVERLAY_WAYPOINT_OPACITY",
        "Waypoint Opacity",
        def.default,
        def.min,
        def.max,
        def.step,
        function(value)
            return string.format("%.0f%%", value * 100)
        end,
        "Controls 3D waypoint opacity.",
        function()
            return NS.GetWorldOverlaySetting("worldOverlayWaypointOpacity")
        end,
        function(value)
            NS.SetWorldOverlaySetting("worldOverlayWaypointOpacity", value)
            RefreshWorldOverlay()
        end
    )

    def = DEFS.worldOverlayWaypointOffsetY
    AddSlider(
        category,
        "WORLD_OVERLAY_WAYPOINT_OFFSET_Y",
        "Waypoint Vertical Offset",
        def.default,
        def.min,
        def.max,
        def.step,
        function(value)
            return string.format("%+d px", value)
        end,
        "Shifts the 3D waypoint and pinpoint up (positive) or down (negative) on screen, keeping context diamonds aligned across mode transitions.",
        function()
            return NS.GetWorldOverlaySetting("worldOverlayWaypointOffsetY")
        end,
        function(value)
            NS.SetWorldOverlaySetting("worldOverlayWaypointOffsetY", value)
            RefreshWorldOverlay()
        end
    )

    AddDropdown(
        category,
        "WORLD_OVERLAY_BEACON_STYLE",
        "Beacon",
        DEFS.worldOverlayBeaconStyle.default,
        function()
            return NS.GetWorldOverlaySetting("worldOverlayBeaconStyle")
        end,
        function(value)
            NS.SetWorldOverlaySetting("worldOverlayBeaconStyle", value)
            RefreshWorldOverlay()
        end,
        CreateWorldOverlayBeaconStyleOptions,
        "Controls the 3D waypoint beacon. Beacon shows the full column. Base Only shows just the bottom without the full beacon. Off hides it entirely."
    )

    def = DEFS.worldOverlayBeaconOpacity
    AddSlider(
        category,
        "WORLD_OVERLAY_BEACON_OPACITY",
        "Beacon Opacity",
        def.default,
        def.min,
        def.max,
        def.step,
        function(value)
            return string.format("%.0f%%", value * 100)
        end,
        "Controls the beacon opacity.",
        function()
            return NS.GetWorldOverlaySetting("worldOverlayBeaconOpacity")
        end,
        function(value)
            NS.SetWorldOverlaySetting("worldOverlayBeaconOpacity", value)
            RefreshWorldOverlay()
        end
    )

    AddCheckbox(
        category,
        "WORLD_OVERLAY_USE_METERS",
        "Use Meters instead of Yards",
        DEFS.worldOverlayUseMeters.default,
        "Formats overlay distance text in meters instead of yards.",
        function()
            return NS.GetWorldOverlaySetting("worldOverlayUseMeters")
        end,
        function(value)
            NS.SetWorldOverlaySetting("worldOverlayUseMeters", value)
            RefreshWorldOverlay()
        end
    )

    AddSectionHeader(category, "Colors")

    AddColorDropdownWithSwatch(
        category,
        nil,
        "Waypoint Text",
        "Controls the waypoint footer text color. Default follows the icon tint unless that icon spec defines a separate waypointTextTint override in config.lua. None forces plain untinted text.",
        "worldOverlayWaypointTextColorMode",
        "worldOverlayWaypointTextCustomColor"
    )

    AddColorDropdownWithSwatch(
        category,
        nil,
        "Beacon",
        "Controls the 3D waypoint beacon color. Default preserves the current split beacon treatment.",
        "worldOverlayBeaconColorMode",
        "worldOverlayBeaconCustomColor"
    )
end

function M.AddWorldOverlayInfoTextOptions(category)
    AddSectionHeader(category, "Footer Info Text")

    AddDropdown(
        category,
        "WORLD_OVERLAY_FOOTER_TEXT",
        "Footer Text",
        DEFS.worldOverlayFooterText.default,
        function()
            return NS.GetWorldOverlaySetting("worldOverlayFooterText")
        end,
        function(value)
            NS.SetWorldOverlaySetting("worldOverlayFooterText", value)
            RefreshWorldOverlay()
        end,
        CreateWorldOverlayInfoOptions,
        "Chooses which info appears in the waypoint footer."
    )

    local def = DEFS.worldOverlayInfoTextSize
    AddSlider(
        category,
        "WORLD_OVERLAY_INFO_TEXT_SIZE",
        "Info Text Size",
        def.default,
        def.min,
        def.max,
        def.step,
        function(value)
            return string.format("%.0f%%", value * 100)
        end,
        "Scales the 3D waypoint info text.",
        function()
            return NS.GetWorldOverlaySetting("worldOverlayInfoTextSize")
        end,
        function(value)
            NS.SetWorldOverlaySetting("worldOverlayInfoTextSize", value)
            RefreshWorldOverlay()
        end
    )

    def = DEFS.worldOverlayInfoTextOpacity
    AddSlider(
        category,
        "WORLD_OVERLAY_INFO_TEXT_OPACITY",
        "Info Text Opacity",
        def.default,
        def.min,
        def.max,
        def.step,
        function(value)
            return string.format("%.0f%%", value * 100)
        end,
        "Controls the opacity of the waypoint footer info text.",
        function()
            return NS.GetWorldOverlaySetting("worldOverlayInfoTextOpacity")
        end,
        function(value)
            NS.SetWorldOverlaySetting("worldOverlayInfoTextOpacity", value)
            RefreshWorldOverlay()
        end
    )

    def = DEFS.worldOverlaySubtextOpacity
    AddSlider(
        category,
        "WORLD_OVERLAY_SUBTEXT_OPACITY",
        "Distance/Arrival Time Opacity",
        def.default,
        def.min,
        def.max,
        def.step,
        function(value)
            return string.format("%.0f%%", value * 100)
        end,
        "Controls the opacity of the waypoint footer distance and arrival-time text.",
        function()
            return NS.GetWorldOverlaySetting("worldOverlaySubtextOpacity")
        end,
        function(value)
            NS.SetWorldOverlaySetting("worldOverlaySubtextOpacity", value)
            RefreshWorldOverlay()
        end
    )
end

function M.AddWorldOverlayPinpointOptions(category)
    AddDropdown(
        category,
        "WORLD_OVERLAY_PINPOINT_MODE",
        "Pinpoint Mode",
        DEFS.worldOverlayPinpointMode.default,
        function()
            return NS.GetWorldOverlaySetting("worldOverlayPinpointMode")
        end,
        function(value)
            NS.SetWorldOverlaySetting("worldOverlayPinpointMode", value)
            RefreshWorldOverlay()
        end,
        CreateWorldOverlayPinpointModeOptions,
        "Controls the close-range pinpoint. Full shows everything. Plaque Off hides the title panel but keeps the context icon and arrows. Disabled hides the pinpoint entirely."
    )

    local def = DEFS.worldOverlayPinpointDistance
    AddSlider(
        category,
        "WORLD_OVERLAY_PINPOINT_DISTANCE",
        "Show Pinpoint At",
        def.default,
        def.min,
        def.max,
        def.step,
        FormatWorldOverlayDistance,
        "Switches from the large waypoint to the close-range pinpoint within this distance.",
        function()
            return NS.GetWorldOverlaySetting("worldOverlayPinpointDistance")
        end,
        function(value)
            NS.SetWorldOverlaySetting("worldOverlayPinpointDistance", value)
            RefreshWorldOverlay()
        end
    )

    def = DEFS.worldOverlayHideDistance
    AddSlider(
        category,
        "WORLD_OVERLAY_HIDE_DISTANCE",
        "Hide Pinpoint At",
        def.default,
        def.min,
        def.max,
        def.step,
        FormatWorldOverlayDistance,
        "Hides the 3D overlay within this arrival range.",
        function()
            return NS.GetWorldOverlaySetting("worldOverlayHideDistance")
        end,
        function(value)
            NS.SetWorldOverlaySetting("worldOverlayHideDistance", value)
            RefreshWorldOverlay()
        end
    )

    def = DEFS.worldOverlayPinpointSize
    AddSlider(
        category,
        "WORLD_OVERLAY_PINPOINT_SIZE",
        "Pinpoint Size",
        def.default,
        def.min,
        def.max,
        def.step,
        function(value)
            return string.format("%.0f%%", value * 100)
        end,
        "Scales the 3D pinpoint.",
        function()
            return NS.GetWorldOverlaySetting("worldOverlayPinpointSize")
        end,
        function(value)
            NS.SetWorldOverlaySetting("worldOverlayPinpointSize", value)
            RefreshWorldOverlay()
        end
    )

    def = DEFS.worldOverlayPinpointOpacity
    AddSlider(
        category,
        "WORLD_OVERLAY_PINPOINT_OPACITY",
        "Pinpoint Opacity",
        def.default,
        def.min,
        def.max,
        def.step,
        function(value)
            return string.format("%.0f%%", value * 100)
        end,
        "Controls 3D pinpoint opacity.",
        function()
            return NS.GetWorldOverlaySetting("worldOverlayPinpointOpacity")
        end,
        function(value)
            NS.SetWorldOverlaySetting("worldOverlayPinpointOpacity", value)
            RefreshWorldOverlay()
        end
    )

    AddCheckbox(
        category,
        "WORLD_OVERLAY_PINPOINT_ANIMATE_PLAQUE_EFFECTS",
        "Animate Plaque Effects",
        DEFS.worldOverlayPinpointAnimatePlaqueEffects.default,
        "Enables pulsing plaque overlays and gem glows. When off, plaque overlays stay steady and glow layers are hidden. Does not affect pinpoint arrows.",
        function()
            return NS.GetWorldOverlaySetting("worldOverlayPinpointAnimatePlaqueEffects")
        end,
        function(value)
            NS.SetWorldOverlaySetting("worldOverlayPinpointAnimatePlaqueEffects", value)
            RefreshWorldOverlay()
        end
    )

    AddCheckbox(
        category,
        "WORLD_OVERLAY_PINPOINT_AUTO_VERTICAL_ADJUST",
        "Camera Pinpoint Height",
        DEFS.worldOverlayPinpointAutoVerticalAdjust.default,
        "Automatically adjusts the pinpoint's vertical height when panning the camera higher or lower on the screen.",
        function()
            return NS.GetWorldOverlaySetting("worldOverlayPinpointAutoVerticalAdjust")
        end,
        function(value)
            NS.SetWorldOverlaySetting("worldOverlayPinpointAutoVerticalAdjust", value)
            RefreshWorldOverlay()
        end
    )

    def = DEFS.worldOverlayPinpointManualVerticalGap
    AddSlider(
        category,
        "WORLD_OVERLAY_PINPOINT_MANUAL_VERTICAL_GAP",
        "Base Pinpoint Height",
        def.default,
        def.min,
        def.max,
        def.step,
        function(value)
            return string.format("%d px", value + 0.5)
        end,
        "Sets the pinpoint's base vertical height when Camera Pinpoint Height is off.",
        function()
            return NS.GetWorldOverlaySetting("worldOverlayPinpointManualVerticalGap")
        end,
        function(value)
            NS.SetWorldOverlaySetting("worldOverlayPinpointManualVerticalGap", value)
            RefreshWorldOverlay()
        end
    )

    AddCheckbox(
        category,
        "WORLD_OVERLAY_SHOW_DESTINATION_INFO",
        "Show Destination Info",
        DEFS.worldOverlayShowDestinationInfo.default,
        "Shows the title inside the 3D pinpoint plaque.",
        function()
            return NS.GetWorldOverlaySetting("worldOverlayShowDestinationInfo")
        end,
        function(value)
            NS.SetWorldOverlaySetting("worldOverlayShowDestinationInfo", value)
            RefreshWorldOverlay()
        end
    )

    AddCheckbox(
        category,
        "WORLD_OVERLAY_SHOW_EXTENDED_INFO",
        "Show Extended Info",
        DEFS.worldOverlayShowExtendedInfo.default,
        "Shows extended quest or guide context inside the 3D pinpoint plaque.",
        function()
            return NS.GetWorldOverlaySetting("worldOverlayShowExtendedInfo")
        end,
        function(value)
            NS.SetWorldOverlaySetting("worldOverlayShowExtendedInfo", value)
            RefreshWorldOverlay()
        end
    )

    AddCheckbox(
        category,
        "WORLD_OVERLAY_SHOW_COORDINATE_FALLBACK",
        "Show Coordinate Fallback",
        DEFS.worldOverlayShowCoordinateFallback.default,
        "Shows x/y coordinates in the pinpoint plaque when no other extended text is available.",
        function()
            return NS.GetWorldOverlaySetting("worldOverlayShowCoordinateFallback")
        end,
        function(value)
            NS.SetWorldOverlaySetting("worldOverlayShowCoordinateFallback", value)
            RefreshWorldOverlay()
        end
    )

    AddCheckbox(
        category,
        "WORLD_OVERLAY_SHOW_PINPOINT_ARROWS",
        "Show Pinpoint Arrows",
        DEFS.worldOverlayShowPinpointArrows.default,
        "Shows the animated downward chevrons under the 3D pinpoint context icon.",
        function()
            return NS.GetWorldOverlaySetting("worldOverlayShowPinpointArrows")
        end,
        function(value)
            NS.SetWorldOverlaySetting("worldOverlayShowPinpointArrows", value)
            RefreshWorldOverlay()
        end
    )

    AddDropdown(
        category,
        "WORLD_OVERLAY_PINPOINT_PLAQUE_TYPE",
        "Plaque Style",
        DEFS.worldOverlayPinpointPlaqueType.default,
        function()
            return NS.GetWorldOverlaySetting("worldOverlayPinpointPlaqueType")
        end,
        function(value)
            local saved = NS.SetWorldOverlaySetting("worldOverlayPinpointPlaqueType", value)
            NS.SwapNativePinpointPlaque(saved)
            RefreshWorldOverlay()
        end,
        CreateWorldOverlayPlaqueTypeOptions,
        "Selects the plaque style used for the pinpoint."
    )

    AddSectionHeader(category, "Colors")

    AddColorDropdownWithSwatch(
        category,
        nil,
        "Pinpoint Title",
        "Controls the pinpoint title text color. Default and None preserve the untinted font-template colors.",
        "worldOverlayPinpointTitleColorMode",
        "worldOverlayPinpointTitleCustomColor"
    )

    AddColorDropdownWithSwatch(
        category,
        nil,
        "Pinpoint Subtext",
        "Controls the pinpoint subtext color. Default and None preserve the untinted font-template colors.",
        "worldOverlayPinpointSubtextColorMode",
        "worldOverlayPinpointSubtextCustomColor"
    )

    AddColorDropdownWithSwatch(
        category,
        nil,
        "Pinpoint Plaque",
        "Controls the pinpoint plaque panel treatment. Default uses original plaque colors.",
        "worldOverlayPlaqueColorMode",
        "worldOverlayPlaqueCustomColor"
    )

    AddColorDropdownWithSwatch(
        category,
        nil,
        "Animated Parts",
        "Controls pinpoint gem and glow colors. Beacon FX stays under the Beacon color control.",
        "worldOverlayAnimatedColorMode",
        "worldOverlayAnimatedCustomColor"
    )

    AddColorDropdownWithSwatch(
        category,
        nil,
        "Chevrons",
        "Controls the animated downward chevron arrows under the pinpoint context icon.",
        "worldOverlayArrowColorMode",
        "worldOverlayArrowCustomColor"
    )
end

function M.AddWorldOverlayNavigatorOptions(category)
    AddCheckbox(
        category,
        "WORLD_OVERLAY_NAVIGATOR_SHOW",
        "Enable Navigator",
        DEFS.worldOverlayNavigatorShow.default,
        "Shows the off-screen navigator when the target leaves the screen.",
        function()
            return NS.GetWorldOverlaySetting("worldOverlayNavigatorShow")
        end,
        function(value)
            NS.SetWorldOverlaySetting("worldOverlayNavigatorShow", value)
            RefreshWorldOverlay()
        end
    )

    local def = DEFS.worldOverlayNavigatorSize
    AddSlider(
        category,
        "WORLD_OVERLAY_NAVIGATOR_SIZE",
        "Navigator Size",
        def.default,
        def.min,
        def.max,
        def.step,
        function(value)
            return string.format("%.0f%%", value * 100)
        end,
        "Scales the 3D navigator.",
        function()
            return NS.GetWorldOverlaySetting("worldOverlayNavigatorSize")
        end,
        function(value)
            NS.SetWorldOverlaySetting("worldOverlayNavigatorSize", value)
            RefreshWorldOverlay()
        end
    )

    def = DEFS.worldOverlayNavigatorOpacity
    AddSlider(
        category,
        "WORLD_OVERLAY_NAVIGATOR_OPACITY",
        "Navigator Opacity",
        def.default,
        def.min,
        def.max,
        def.step,
        function(value)
            return string.format("%.0f%%", value * 100)
        end,
        "Controls 3D navigator opacity.",
        function()
            return NS.GetWorldOverlaySetting("worldOverlayNavigatorOpacity")
        end,
        function(value)
            NS.SetWorldOverlaySetting("worldOverlayNavigatorOpacity", value)
            RefreshWorldOverlay()
        end
    )

    def = DEFS.worldOverlayNavigatorDistance
    AddSlider(
        category,
        "WORLD_OVERLAY_NAVIGATOR_DISTANCE",
        "Navigator Distance",
        def.default,
        def.min,
        def.max,
        def.step,
        function(value)
            return string.format("%.1fx", value)
        end,
        "Moves the 3D navigator farther from or closer to screen center.",
        function()
            return NS.GetWorldOverlaySetting("worldOverlayNavigatorDistance")
        end,
        function(value)
            NS.SetWorldOverlaySetting("worldOverlayNavigatorDistance", value)
            RefreshWorldOverlay()
        end
    )

    AddCheckbox(
        category,
        "WORLD_OVERLAY_NAVIGATOR_DYNAMIC_DISTANCE",
        "Navigator Dynamic Distance",
        DEFS.worldOverlayNavigatorDynamicDistance.default,
        "Adjusts 3D navigator distance slightly with camera zoom.",
        function()
            return NS.GetWorldOverlaySetting("worldOverlayNavigatorDynamicDistance")
        end,
        function(value)
            NS.SetWorldOverlaySetting("worldOverlayNavigatorDynamicDistance", value)
            RefreshWorldOverlay()
        end
    )

    AddSectionHeader(category, "Colors")

    AddColorDropdownWithSwatch(
        category,
        nil,
        "NavArrow",
        "Controls the navigator arrow color.",
        "worldOverlayNavArrowColorMode",
        "worldOverlayNavArrowCustomColor"
    )
end
