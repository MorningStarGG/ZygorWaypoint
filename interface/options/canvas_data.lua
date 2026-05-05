local NS = _G.AzerothWaypointNS
local C = NS.Constants

NS.Internal.Interface = NS.Internal.Interface or {}
NS.Internal.Interface.canvas = NS.Internal.Interface.canvas or {}

local M = NS.Internal.Interface.canvas
local Data = {}
M.Data = Data

local MEDIA_HELP = "Interface\\AddOns\\AzerothWaypoint\\media\\help\\"

Data.MEDIA_HELP = MEDIA_HELP
Data.ICON_PATH = "Interface\\AddOns\\AzerothWaypoint\\media\\icon.png"

Data.PREVIEW_IMAGE_SIZES = {
    [MEDIA_HELP .. "MainShot.tga"] = { w = 700, h = 389 },
    [MEDIA_HELP .. "Starlight.tga"] = { w = 330, h = 150 },
    [MEDIA_HELP .. "Stealth.tga"] = { w = 330, h = 150 },
    [MEDIA_HELP .. "Waypoint.tga"] = { w = 353, h = 350 },
    [MEDIA_HELP .. "Navigator.tga"] = { w = 360, h = 235 },

    [MEDIA_HELP .. "Normal.tga"] = { w = 330, h = 120 },
    [MEDIA_HELP .. "MinimalMode.tga"] = { w = 330, h = 120 },
    [MEDIA_HELP .. "MinimalModeHideBG.tga"] = { w = 330, h = 120 },
    [MEDIA_HELP .. "MinimalModeHideBGColors.tga"] = { w = 330, h = 120 },

    [MEDIA_HELP .. "Pinpoint.tga"] = { w = 350, h = 267 },
    [MEDIA_HELP .. "PinpointPlaqueOff.tga"] = { w = 350, h = 267 },
    [MEDIA_HELP .. "PinpointOff.tga"] = { w = 350, h = 267 },

    [MEDIA_HELP .. "FullContext.tga"] = { w = 250, h = 129 },
    [MEDIA_HELP .. "IconOnly.tga"] = { w = 250, h = 129 },
    [MEDIA_HELP .. "ContextHidden.tga"] = { w = 250, h = 129 },

    [MEDIA_HELP .. "Beacon.tga"] = { w = 250, h = 171 },
    [MEDIA_HELP .. "BeaconOff.tga"] = { w = 250, h = 171 },
    [MEDIA_HELP .. "BaseOnly.tga"] = { w = 250, h = 171 },

    [MEDIA_HELP .. "PlaqueDefault.tga"] = { w = 396, h = 112 },
    [MEDIA_HELP .. "PlaqueGlowingGems.tga"] = { w = 397, h = 135 },
    [MEDIA_HELP .. "PlaqueHorde.tga"] = { w = 396, h = 167 },
    [MEDIA_HELP .. "PlaqueAlliance.tga"] = { w = 396, h = 149 },
    [MEDIA_HELP .. "PlaqueModern.tga"] = { w = 397, h = 128 },
    [MEDIA_HELP .. "PlaqueSteampunk.tga"] = { w = 412, h = 162 },

    [MEDIA_HELP .. "ManualQueueAsk.tga"] = { w = 590, h = 236 },
    [MEDIA_HELP .. "TravelButton.tga"] = { w = 297, h = 102 },
    [MEDIA_HELP .. "AWP.tga"] = { w = 191, h = 266 },
    [MEDIA_HELP .. "AWPBomber.tga"] = { w = 192, h = 266 },
    [MEDIA_HELP .. "AWPModern.tga"] = { w = 192, h = 308 },
    [MEDIA_HELP .. "Alliance.tga"] = { w = 192, h = 302 },
    [MEDIA_HELP .. "Horde.tga"] = { w = 192, h = 302 },
    [MEDIA_HELP .. "Overlay.tga"] = { w = 782, h = 782 },
    [MEDIA_HELP .. "OverlayFade.tga"] = { w = 782, h = 782 },

    [MEDIA_HELP .. "WaypointFooterAll.tga"] = { w = 344, h = 207 },
    [MEDIA_HELP .. "WaypointFooterNone.tga"] = { w = 344, h = 207 },
    [MEDIA_HELP .. "WaypointFooterDestinationName.tga"] = { w = 344, h = 207 },
    [MEDIA_HELP .. "WaypointFooterArrivalTime.tga"] = { w = 344, h = 207 },
    [MEDIA_HELP .. "WaypointFooterDistance.tga"] = { w = 344, h = 207 },
}

Data.TWITCH_URL = "https://www.twitch.tv/MorningStarGG"
Data.ABOUT_SUMMARY =
"Navigation, route planning, and 3D world overlay for TomTom, guide addons, quests, POIs, and manual waypoint queues."
Data.ABOUT_DESCRIPTION = table.concat({
    "AzerothWaypoint turns guide steps, Blizzard map interactions, TomTom waypoints, tracked quests, and supported addon POIs into one routed navigation flow.",
    "",
    "It can plan routes through Farstrider, Mapzeroth, or Zygor backends, or use TomTom Direct, preserve manual and guide queue state across reloads, and present the active waypoint through TomTom and AWP's 3D waypoint.",
}, "\n")

Data.SECTION_DEFS = {
    { key = "about",     label = "About",         image = MEDIA_HELP .. "MainShot.tga",  desc = Data.ABOUT_SUMMARY },
    { key = "general",   label = "General",       image = MEDIA_HELP .. "MainShot.tga",  desc = "Routing backends, manual queues, and quest tracking." },
    { key = "tomtom",    label = "TomTom Arrow",  image = MEDIA_HELP .. "Starlight.tga", desc = "Arrow skins, scale, and travel action button." },
    { key = "overlay",   label = "World Overlay", image = MEDIA_HELP .. "Overlay.tga",   desc = "3D overlay visibility, fade behavior, and context display." },
    { key = "waypoint",  label = "Waypoint",      image = MEDIA_HELP .. "Waypoint.tga",  desc = "Long-range waypoint size, opacity, beacon, and footer text.",     indent = true },
    { key = "pinpoint",  label = "Pinpoint",      image = MEDIA_HELP .. "Pinpoint.tga",  desc = "Close-range marker, plaque style, arrows, and arrival behavior.", indent = true },
    { key = "navigator", label = "Navigator",     image = MEDIA_HELP .. "Navigator.tga", desc = "Off-screen destination arrow.",                                   indent = true },
}

Data.ZYGOR_SECTION = {
    key = "zygor",
    label = "Zygor",
    image = MEDIA_HELP .. "Normal.tga",
    desc = "Settings for optional Zygor Guides integration.",
}

Data.OPTION_PREVIEWS = {
    ["Use Custom Arrow Skin"] = {
        image = MEDIA_HELP .. "Stealth.tga",
        desc = "Use a custom skin in place of TomTom's default Crazy Arrow art.",
    },
    ["Arrow Skin"] = {
        image = MEDIA_HELP .. "Starlight.tga",
        desc = "Registered skins appear here automatically, including Zygor skins when Zygor is loaded.",
    },
    ["Enable 3D World Overlay"] = {
        image = MEDIA_HELP .. "Overlay.tga",
        desc = "Shows active destinations as in-world markers.",
    },
    ["Fade on Hover"] = {
        image = MEDIA_HELP .. "OverlayFade.tga",
        desc = "Fades the overlay while the mouse is over it.",
    },
    ["Waypoint"] = {
        image = MEDIA_HELP .. "Waypoint.tga",
        desc = "Waypoint controls affect the long-range in-world destination marker.",
    },
    ["Pinpoint Mode"] = {
        image = MEDIA_HELP .. "Pinpoint.tga",
        desc = "Pinpoint controls affect the close-range destination display.",
    },
    ["Plaque Style"] = {
        image = MEDIA_HELP .. "Pinpoint.tga",
        desc = "Plaques frame close-range destination text and quest context.",
    },
    ["Enable Navigator"] = {
        image = MEDIA_HELP .. "Navigator.tga",
        desc = "The navigator arrow appears when the target is outside the camera view.",
    },
    ["Manual Click Queue Behavior"] = {
        image = MEDIA_HELP .. "ManualQueueAsk.tga",
        desc = "Choose whether manual map clicks create, replace, append, or prompt.",
    },
    ["Special Travel Button Scale"] = {
        image = MEDIA_HELP .. "TravelButton.tga",
        desc =
        "Scales the special travel action button shown for hearthstones, items, spells, and other travel actions.",
    },
    ["Show Only Guide Steps Until Mouseover"] = {
        image = MEDIA_HELP .. "MinimalMode.tga",
        desc = "Compacts the Zygor guide frame until you mouse over it.",
    },
}

Data.COLOR_OPTION_VALUE_PREVIEWS = {
    [C.WORLD_OVERLAY_COLOR_AUTO] = {
        desc = "Auto uses contextual target hints, such as quest state, destination type, route type, or source addon.",
    },
}

Data.OPTION_VALUE_PREVIEWS = {
    ["Arrow Skin"] = {
        [C.SKIN_STARLIGHT] = { image = MEDIA_HELP .. "Starlight.tga", desc = "Zygor Starlight arrow skin." },
        [C.SKIN_STEALTH] = { image = MEDIA_HELP .. "Stealth.tga", desc = "Zygor Stealth arrow skin." },
        ["AWP"] = {
            image = MEDIA_HELP .. "AWP.tga",
            desc = "AWP arrow skin.",
        },
        ["AWP Bomber"] = {
            image = MEDIA_HELP .. "AWPBomber.tga",
            desc = "AWP Bomber arrow skin.",
        },
        ["AWP Modern"] = {
            image = MEDIA_HELP .. "AWPModern.tga",
            desc = "AWP Modern arrow skin.",
        },
        ["Alliance"] = {
            image = MEDIA_HELP .. "Alliance.tga",
            desc = "Alliance arrow skin.",
        },
        ["Horde"] = {
            image = MEDIA_HELP .. "Horde.tga",
            desc = "Horde arrow skin.",
        },
    },
    ["Hide Step Backgrounds Until Mouseover"] = {
        ["Disabled"] = {
            image = MEDIA_HELP .. "MinimalMode.tga",
            desc = "Shows normal guide step backgrounds.",
        },
        ["Hide Step Backgrounds"] = {
            image = MEDIA_HELP .. "MinimalModeHideBG.tga",
            desc = "Hides guide step row backgrounds until mouseover.",
        },
        ["Hide Step Backgrounds + Line Colors"] = {
            image = MEDIA_HELP .. "MinimalModeHideBGColors.tga",
            desc = "Hides guide step row backgrounds and removes goal line colors until mouseover.",
        },
    },
    ["Manual Click Queue Behavior"] = {
        ["ask"] = {
            image = MEDIA_HELP .. "ManualQueueAsk.tga",
            desc = "Shows a prompt so you can create, replace, or append the manual waypoint.",
        },
    },
    ["Context Display"] = {
        [C.WORLD_OVERLAY_CONTEXT_DISPLAY_DIAMOND_ICON] = { image = MEDIA_HELP .. "FullContext.tga", desc = "Shows both the context diamond and destination icon." },
        [C.WORLD_OVERLAY_CONTEXT_DISPLAY_ICON_ONLY] = { image = MEDIA_HELP .. "IconOnly.tga", desc = "Shows the destination icon without the backing diamond." },
        [C.WORLD_OVERLAY_CONTEXT_DISPLAY_HIDDEN] = { image = MEDIA_HELP .. "ContextHidden.tga", desc = "Hides both the context diamond and destination icon." },
    },
    ["Waypoint"] = {
        [C.WORLD_OVERLAY_WAYPOINT_MODE_FULL] = { image = MEDIA_HELP .. "Waypoint.tga", desc = "Shows the full long-range waypoint presentation." },
        [C.WORLD_OVERLAY_WAYPOINT_MODE_DISABLED] = { desc = "Hides the long-range waypoint presentation." },
    },
    ["Footer Text"] = {
        [C.WORLD_OVERLAY_INFO_ALL] = { image = MEDIA_HELP .. "WaypointFooterAll.tga", desc = "Shows destination name, distance, and arrival time." },
        [C.WORLD_OVERLAY_INFO_DISTANCE] = { image = MEDIA_HELP .. "WaypointFooterDistance.tga", desc = "Shows only the distance." },
        [C.WORLD_OVERLAY_INFO_ARRIVAL] = { image = MEDIA_HELP .. "WaypointFooterArrivalTime.tga", desc = "Shows only the estimated arrival time." },
        [C.WORLD_OVERLAY_INFO_DESTINATION] = { image = MEDIA_HELP .. "WaypointFooterDestinationName.tga", desc = "Shows only the destination name." },
        [C.WORLD_OVERLAY_INFO_NONE] = { image = MEDIA_HELP .. "WaypointFooterNone.tga", desc = "Hides waypoint footer text." },
    },
    ["Beacon Style"] = {
        [C.WORLD_OVERLAY_BEACON_STYLE_BEACON] = { image = MEDIA_HELP .. "Beacon.tga", desc = "Shows the full vertical beacon column." },
        [C.WORLD_OVERLAY_BEACON_STYLE_BASE] = { image = MEDIA_HELP .. "BaseOnly.tga", desc = "Shows only the destination base marker." },
        [C.WORLD_OVERLAY_BEACON_STYLE_DISTANCE] = { image = MEDIA_HELP .. "Waypoint.tga", desc = "Shows the full beacon at range, then switches to base-only near the destination." },
        [C.WORLD_OVERLAY_BEACON_STYLE_OFF] = { image = MEDIA_HELP .. "BeaconOff.tga", desc = "Hides the waypoint beacon art." },
    },
    ["Pinpoint Mode"] = {
        [C.WORLD_OVERLAY_PINPOINT_MODE_FULL] = { image = MEDIA_HELP .. "Pinpoint.tga", desc = "Shows the close-range pinpoint, plaque, and context marker." },
        [C.WORLD_OVERLAY_PINPOINT_MODE_NO_PLAQUE] = { image = MEDIA_HELP .. "PinpointPlaqueOff.tga", desc = "Shows the pinpoint marker without the title plaque." },
        [C.WORLD_OVERLAY_PINPOINT_MODE_DISABLED] = { image = MEDIA_HELP .. "PinpointOff.tga", desc = "Disables the close-range pinpoint presentation." },
    },
    ["Plaque Style"] = {
        [C.WORLD_OVERLAY_PLAQUE_DEFAULT] = { image = MEDIA_HELP .. "PlaqueDefault.tga", desc = "The default compact pinpoint plaque." },
        [C.WORLD_OVERLAY_PLAQUE_GLOWING_GEMS] = { image = MEDIA_HELP .. "PlaqueGlowingGems.tga", desc = "A gemmed plaque with animated glow support." },
        [C.WORLD_OVERLAY_PLAQUE_HORDE] = { image = MEDIA_HELP .. "PlaqueHorde.tga", desc = "A Horde-themed pinpoint plaque." },
        [C.WORLD_OVERLAY_PLAQUE_ALLIANCE] = { image = MEDIA_HELP .. "PlaqueAlliance.tga", desc = "An Alliance-themed pinpoint plaque." },
        [C.WORLD_OVERLAY_PLAQUE_MODERN] = { image = MEDIA_HELP .. "PlaqueModern.tga", desc = "A flatter modern pinpoint plaque." },
        [C.WORLD_OVERLAY_PLAQUE_STEAMPUNK] = { image = MEDIA_HELP .. "PlaqueSteampunk.tga", desc = "A brass steampunk pinpoint plaque." },
    },
}

Data.SEARCH_FILTERS = {
    { value = "all",          text = "All Settings" },
    { value = "new",          text = "New Settings",     desc = "Settings added in this version." },
    { value = "updated",      text = "Updated Settings", desc = "Existing settings changed in this version." },
    { value = "navigation",   text = "Navigation Flow",  desc = "Routing, queues, manual waypoints, and tracked quests." },
    { value = "visual",       text = "Visual Markers",   desc = "World overlay, waypoints, pinpoint, navigator, and arrow presentation." },
    { value = "sizing",       text = "Size & Opacity",   desc = "Scale, distance, opacity, offset, and height controls." },
    { value = "styles",       text = "Colors & Styles",  desc = "Skins, colors, plaques, context display, and text styling." },
    { value = "integrations", text = "Integrations",     desc = "TomTom, Zygor, routing backends, and special travel behavior." },
}

Data.OPTIONS = {
    { key = "about",     label = "About",                                     desc = Data.ABOUT_SUMMARY },
    { key = "general",   label = "Enable Routing",                            desc = "Enable or disable AzerothWaypoint route ownership.",                                                  added = "3.0.0", updated = "4.0.0",                                                                                                 note = "Reworked for v4 route ownership and backend selection." },
    { key = "general",   label = "Routing Backend",                           desc = "Choose the routing backend: Farstrider, Mapzeroth, Zygor or use TomTom Directly",                     added = "4.0.0", note = "Adds TomTom Direct, Zygor, Mapzeroth, and FarstriderLib backend support.",                                 tags = "direct tomtom direct farstrider mapzeroth zygor" },
    { key = "general",   label = "Manual Click Queue Behavior",               desc = "Choose how Blizzard map clicks enter the manual queue.",                                              added = "4.0.0", note = "Adds explicit create, replace, append, and prompt behavior for map clicks.",                               tags = "create new queue replace active append ask prompt" },
    { key = "general",   label = "Auto-Clear Manual Waypoints on Arrival",    desc = "Clear manual waypoints when you reach the destination.",                                              added = "2.3.0" },
    { key = "general",   label = "Manual Waypoint Clear Distance",            desc = "Set the arrival distance used to clear manual waypoints.",                                            added = "2.3.0" },
    { key = "general",   label = "Auto-Route Tracked Quests",                 desc = "Automatically route tracked Blizzard quests. Guide steps are protected while a guide is active.",     added = "3.1.0", updated = "4.0.0",                                                                                                 note = "Now uses v4 route authority and guide protection." },
    { key = "general",   label = "Auto-Clear Untracked Quests",               desc = "Remove matching AWP quest waypoint and queue entries when quests are untracked.",                     added = "4.0.0", tags = "quest tracking untracking queue clear" },
    { key = "general",   label = "Auto-Clear Supertracked Quests on Arrival", desc = "Clear supertracked quest routes when you reach the destination.",                                     added = "3.1.0" },
    { key = "general",   label = "Adopt Waypoints from Unknown Addons",       desc = "Adopt click-like Blizzard waypoint calls from addons without dedicated AWP support.",                 added = "4.0.0", tags = "addon whitelist denylist worldquesttab" },
    { key = "general",   label = "Detected Addon Callers",                    desc = "Review recent unknown addon waypoint API callers and allow or deny them.",                            added = "4.0.0", tags = "addon whitelist denylist" },
    { key = "general",   label = "Addon Whitelist",                           desc = "Addon folder names allowed to use generic waypoint adoption.",                                        added = "4.0.0", tags = "addon allowlist whitelist" },
    { key = "general",   label = "Addon Denylist",                            desc = "Addon folder names blocked from generic waypoint adoption.",                                          added = "4.0.0", tags = "addon blacklist denylist blocklist" },
    { key = "tomtom",    label = "Use Custom Arrow Skin",                     desc = "Use a registered skin instead of TomTom's default arrow art.",                                        added = "3.0.0", updated = "4.0.0",                                                                                                 note = "Now uses the registered arrow skin system.",                                    tags = "zygor starlight stealth" },
    { key = "tomtom",    label = "Arrow Skin",                                desc = "Choose the active TomTom arrow skin.",                                                                added = "3.0.0", updated = "4.0.0",                                                                                                 note = "Now lists registered skins dynamically, including Zygor skins when available.", tags = "tomtom default zygor starlight stealth awp awp bomber awp modern alliance horde" },
    { key = "tomtom",    label = "TomTom Arrow Scale",                        desc = "Scale the active custom TomTom arrow skin.",                                                          added = "3.0.0", updated = "4.0.0",                                                                                                 note = "Moved into the v4 arrow skin settings.",                                        tags = "zygor arrow scale" },
    { key = "tomtom",    label = "Special Travel Button Scale",               desc = "Scale the button that shows for routes using hearthstones, items, spells, and other travel actions.", added = "4.0.0", note = "Adds a scale control for the special travel button.",                                                      tags = "travel action button hearthstone portal item spell" },
    { key = "overlay",   label = "Enable 3D World Overlay",                   desc = "Show or hide the in-world waypoint overlay.",                                                         added = "3.0.0" },
    { key = "overlay",   label = "Fade on Hover",                             desc = "Fade the 3D overlay while the mouse is over it.",                                                     added = "3.0.0" },
    { key = "overlay",   label = "Context Display",                           desc = "Choose context display: diamond and icon, icon only, or hidden.",                                     added = "3.0.0", tags = "context diamond + icon context diamond icon icon only hidden" },
    { key = "overlay",   label = "Context Diamond",                           desc = "Change the context diamond color.",                                                                   added = "3.0.0", updated = "4.0.0",                                                                                                 note = "Color modes now use Auto contextual hints and the Gray preset.",                tags = "color tint auto blue custom cyan gold gray green pink purple red silver white" },
    { key = "overlay",   label = "Icons",                                     desc = "Change overlay icon color.",                                                                          added = "3.0.0", updated = "4.0.0",                                                                                                 note = "Color modes now use Auto contextual hints and the Gray preset.",                tags = "color tint auto blue custom cyan gold gray green pink purple red silver white" },
    { key = "waypoint",  label = "Waypoint",                                  desc = "Control the long-range waypoint marker.",                                                             added = "3.0.0", tags = "enabled disabled" },
    { key = "waypoint",  label = "Waypoint Size",                             desc = "Scale the 3D waypoint frame.",                                                                        added = "3.0.0" },
    { key = "waypoint",  label = "Waypoint Min Size",                         desc = "Set the minimum dynamic waypoint scale.",                                                             added = "3.0.0" },
    { key = "waypoint",  label = "Waypoint Max Size",                         desc = "Set the maximum dynamic waypoint scale.",                                                             added = "3.0.0" },
    { key = "waypoint",  label = "Waypoint Opacity",                          desc = "Change waypoint marker opacity.",                                                                     added = "3.0.0" },
    { key = "waypoint",  label = "Vertical Offset",                           desc = "Move the waypoint marker up or down.",                                                                added = "3.0.0" },
    { key = "waypoint",  label = "Beacon Style",                              desc = "Choose beacon, base only, distance based, or off.",                                                   added = "3.0.0" },
    { key = "waypoint",  label = "Beacon Base Distance",                      desc = "Set the distance where the beacon switches to base-only.",                                            added = "3.0.0" },
    { key = "waypoint",  label = "Beacon Opacity",                            desc = "Change beacon opacity.",                                                                              added = "3.0.0" },
    { key = "waypoint",  label = "Base Vertical Offset",                      desc = "Move the base-only beacon vertically.",                                                               added = "3.0.0" },
    { key = "waypoint",  label = "Use Meters instead of Yards",               desc = "Format overlay distance in meters.",                                                                  added = "3.0.0" },
    { key = "waypoint",  label = "Footer Text",                               desc = "Choose waypoint footer information.",                                                                 added = "3.0.0", tags = "all distance arrival time destination name none" },
    { key = "waypoint",  label = "Info Text Size",                            desc = "Scale waypoint footer text.",                                                                         added = "3.0.0" },
    { key = "waypoint",  label = "Info Text Opacity",                         desc = "Change waypoint footer text opacity.",                                                                added = "3.0.0" },
    { key = "waypoint",  label = "Distance/Arrival Time Opacity",             desc = "Change distance and arrival time text opacity.",                                                      added = "3.0.0" },
    { key = "waypoint",  label = "Waypoint Text",                             desc = "Change waypoint footer text color.",                                                                  added = "3.0.0", updated = "4.0.0",                                                                                                 note = "Color modes now use Auto contextual hints and the Gray preset.",                tags = "color tint auto blue custom cyan gold gray green pink purple red silver white" },
    { key = "waypoint",  label = "Beacon",                                    desc = "Change 3D beacon color.",                                                                             added = "3.0.0", updated = "4.0.0",                                                                                                 note = "Color modes now use Auto contextual hints and the Gray preset.",                tags = "color tint auto blue custom cyan gold gray green pink purple red silver white" },
    { key = "pinpoint",  label = "Pinpoint Mode",                             desc = "Control the close-range pinpoint display.",                                                           added = "3.0.0", tags = "full plaque off no plaque disabled box dialog popup overhead" },
    { key = "pinpoint",  label = "Show Pinpoint At",                          desc = "Set the distance where the overlay switches to pinpoint mode.",                                       added = "3.0.0" },
    { key = "pinpoint",  label = "Hide Pinpoint At",                          desc = "Set the arrival distance where the pinpoint display hides.",                                          added = "3.0.0" },
    { key = "pinpoint",  label = "Pinpoint Size",                             desc = "Scale the 3D pinpoint.",                                                                              added = "3.0.0" },
    { key = "pinpoint",  label = "Pinpoint Opacity",                          desc = "Change pinpoint opacity.",                                                                            added = "3.0.0" },
    { key = "pinpoint",  label = "Plaque Style",                              desc = "Choose the pinpoint plaque art style.",                                                               added = "3.0.0", tags = "default glowing gems horde alliance modern steampunk steam punk" },
    { key = "pinpoint",  label = "Animate Plaque Effects",                    desc = "Toggle pulsing plaque overlays and gem glows.",                                                       added = "3.0.0" },
    { key = "pinpoint",  label = "Show Destination Info",                     desc = "Show the title inside the pinpoint plaque.",                                                          added = "3.0.0" },
    { key = "pinpoint",  label = "Show Extended Info",                        desc = "Show quest or guide context in the plaque.",                                                          added = "3.0.0" },
    { key = "pinpoint",  label = "Show Coordinate Fallback",                  desc = "Show coordinates when no extended text exists.",                                                      added = "3.0.0" },
    { key = "pinpoint",  label = "Show Pinpoint Arrows",                      desc = "Show animated downward chevrons.",                                                                    added = "3.0.0" },
    { key = "pinpoint",  label = "Base Pinpoint Height",                      desc = "Adjust the pinpoint height.",                                                                         added = "3.0.0" },
    { key = "pinpoint",  label = "Camera Pinpoint Height",                    desc = "Adjust pinpoint height based on camera pitch.",                                                       added = "3.0.0" },
    { key = "pinpoint",  label = "Pinpoint Title",                            desc = "Change pinpoint title color.",                                                                        added = "3.0.0", updated = "4.0.0",                                                                                                 note = "Color modes now use Auto contextual hints and the Gray preset.",                tags = "color tint auto blue custom cyan gold gray green pink purple red silver white" },
    { key = "pinpoint",  label = "Pinpoint Subtext",                          desc = "Change pinpoint subtext color.",                                                                      added = "3.0.0", updated = "4.0.0",                                                                                                 note = "Color modes now use Auto contextual hints and the Gray preset.",                tags = "color tint auto blue custom cyan gold gray green pink purple red silver white" },
    { key = "pinpoint",  label = "Pinpoint Plaque",                           desc = "Change pinpoint plaque color.",                                                                       added = "3.0.0", updated = "4.0.0",                                                                                                 note = "Color modes now use Auto contextual hints and the Gray preset.",                tags = "color tint auto blue custom cyan gold gray green pink purple red silver white" },
    { key = "pinpoint",  label = "Animated Parts",                            desc = "Change plaque gem and glow colors.",                                                                  added = "3.0.0", updated = "4.0.0",                                                                                                 note = "Color modes now use Auto contextual hints and the Gray preset.",                tags = "color tint auto blue custom cyan gold gray green pink purple red silver white" },
    { key = "pinpoint",  label = "Chevrons",                                  desc = "Change pinpoint chevron colors.",                                                                     added = "3.0.0", updated = "4.0.0",                                                                                                 note = "Color modes now use Auto contextual hints and the Gray preset.",                tags = "color tint auto blue custom cyan gold gray green pink purple red silver white" },
    { key = "navigator", label = "Enable Navigator",                          desc = "Show the off-screen navigator arrow.",                                                                added = "3.0.0" },
    { key = "navigator", label = "Navigator Size",                            desc = "Scale the navigator.",                                                                                added = "3.0.0" },
    { key = "navigator", label = "Navigator Opacity",                         desc = "Change navigator opacity.",                                                                           added = "3.0.0" },
    { key = "navigator", label = "Navigator Distance",                        desc = "Move the navigator closer to or farther away from the screen center.",                                added = "3.0.0" },
    { key = "navigator", label = "Navigator Dynamic Distance",                desc = "Adjust navigator distance with camera zoom.",                                                         added = "3.0.0" },
    { key = "navigator", label = "Navigator Arrow",                           desc = "Change navigator arrow color.",                                                                       added = "3.0.0", updated = "4.0.0",                                                                                                 note = "Color modes now use Auto contextual hints and the Gray preset.",                tags = "color tint auto blue custom cyan gold gray green pink purple red silver white" },
    { key = "zygor",     label = "Show Only Guide Steps Until Mouseover",     desc = "Compact the Zygor guide frame until you mouse over it.",                                              added = "3.0.0" },
    { key = "zygor",     label = "Hide Step Backgrounds Until Mouseover",     desc = "Fade guide step row backgrounds while compacted.",                                                    added = "3.0.0", tags = "hide step backgrounds hide step backgrounds + line colors line colors goal lines disabled mouseover zygor" },
    { key = "release",   label = "Release Notes",                             desc = "Recent changes and version notes." },
}
