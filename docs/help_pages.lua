local NS = _G.ZygorWaypointNS

local ADDON_NAME = NS.ADDON_NAME or "ZygorWaypoint"

local function JoinLines(lines)
    return table.concat(lines, "\n")
end

-- Help page schema:
-- Each page supports:
--   id      = unique page key used by NS.ShowHelp("page_id")
--   title   = page title shown in the help frame
--   intro   = optional short intro line shown under the title
--   blocks  = ordered content blocks rendered top-to-bottom
--
-- Supported block types:
--   { type = "heading", text = "Section Title" }
--   { type = "text", text = "Body text" }
--   { type = "note", text = "Smaller secondary text" }
--   { type = "divider" }
--   {
--       type = "image",
--       width = 700,
--       height = 220,
--       texture = "Interface\\AddOns\\ZygorWaypoint\\media\\help\\overview",
--       texCoord = { 0, 1, 0, 1 },   -- optional crop
--       align = "CENTER",            -- optional, defaults to centered
--       placeholder = "Shown when texture is missing",
--       caption = "Optional caption below the image",
--   }
--   {
--       type = "image_row",
--       gap = 12,                    -- optional spacing between images
--       items = {
--           {
--               width = 330,
--               height = 150,
--               texture = "Interface\\AddOns\\ZygorWaypoint\\media\\help\\arrow_starlight",
--               placeholder = "Fallback label",
--               caption = "Optional caption",
--           },
--       },
--   }
--   { type = "recent_changelog", limit = 3 }
--
-- Texture notes:
--   - Use WoW texture paths, not Windows file paths.
--   - Omit the file extension in Lua.
--   - Texture files do not need to be listed in the TOC.
--
NS.HELP_PAGES = {
    {
        id = "overview",
        title = "Overview",
        intro = "Start here for the mental model before you touch settings.",
        blocks = {
            {
                type = "image",
                texture = "Interface\\AddOns\\ZygorWaypoint\\media\\help\\MainShot",
                align = "CENTER",
                width = 700,
                height = 389,
                placeholder = "Overview screenshot placeholder",
                caption = "TomTom arrow, Zygor guide, and world overlay.",
            },
            {
                type = "text",
                text = JoinLines({
                    ADDON_NAME .. " connects ZygorGuidesViewer and TomTom so they work as a single system.",
                    "",
                    "When Zygor advances to a new guide step, the destination is handed to TomTom's Crazy Arrow. Only one arrow ever shows — Zygor's built-in arrow is replaced entirely.",
                    "",
                    "- TomTom's Crazy Arrow is the arrow you follow.",
                    "- Zygor provides travel routing and pathfinding context when waypoint routing is enabled. Even for manual waypoints or those sent to TomTom by other addons.",
                    "- The World Overlay adds 3D waypoint, pinpoint, and navigator markers above your destinations.",
                    "- Imported TomTom waypoints from /ttpaste auto advance to the next waypoint on clear when Auto-Route Imported Manual Queue is enabled.",
                    "- The /zwp search command finds nearby services and routes to them using Zygor's travel system.",
                    "",
                    "The rest of this help flow explains where those systems live and which settings matter first.",
                }),
            },
        },
    },
    {
        id = "arrow_guide",
        title = "Arrow and Guide",
        intro = "Control how the arrow behaves, how the guide reads, and how manual routes are handled.",
        blocks = {
            {
                type = "heading",
                text = "Arrow Presentation",
            },
            {
                type = "image_row",
                items = {
                    {
                        width = 330,
                        height = 150,
                        texture = "Interface\\AddOns\\ZygorWaypoint\\media\\help\\Starlight",
                        placeholder = "Starlight arrow screenshot placeholder",
                        caption = "Starlight skin",
                    },
                    {
                        width = 330,
                        height = 150,
                        texture = "Interface\\AddOns\\ZygorWaypoint\\media\\help\\Stealth",
                        placeholder = "Stealth arrow screenshot placeholder",
                        caption = "Stealth skin",
                    },
                },
            },
            {
                type = "text",
                text = JoinLines({
                    "- Use Zygor Skin for TomTom Arrow switches between default TomTom art and the Zygor-style arrow.",
                    "- You have the choice between Starlight or Stealth.",
                    "- TomTom Arrow Scale adjusts the size of the Zygor arrow skin.",
                    "- Align TomTom Arrow to Zygor Text anchors TomTom's arrow to Zygor's navigation text position.",
                }),
            },
            {
                type = "heading",
                text = "Guide Presentation",
            },
            {
                type = "image_row",
                items = {
                    {
                        width = 330,
                        height = 190,
                        texture = "Interface\\AddOns\\ZygorWaypoint\\media\\help\\Normal",
                        placeholder = "Full guide screenshot placeholder",
                        caption = "Normal guide view",
                    },
                    {
                        width = 330,
                        height = 190,
                        texture = "Interface\\AddOns\\ZygorWaypoint\\media\\help\\MinimalMode",
                        placeholder = "Compact guide screenshot placeholder",
                        caption = "Compact mode — steps only until mouseover",
                    },
                },
            },
            {
                type = "text",
                text = JoinLines({
                    "- Show Only Guide Steps Until Mouseover keeps the visible steps readable while trimming the rest of the guide frame. Mouse over the guide to temporarily restore the full view.",
                    "- Hide Step Backgrounds Until Mouseover lets you decide how much of the original Zygor frame fades away in compact mode.",
                    "- Route TomTom Waypoints via Zygor sends all TomTom waypoints, including those created by other addons that use TomTom, through Zygor's travel system.",
                }),
            },
            {
                type = "heading",
                text = "Manual Waypoints and Queue",
            },
            {
                type = "text",
                text = JoinLines({
                    "/ttpaste is TomTom's command for pasting a sequence of waypoints in one go. ZygorWaypoint keeps them in order even if you temporarily switch to a different target. When 'Auto-Route Imported Manual Queue' is enabled, clearing the current queued point automatically advances to the next one, and changing target to any other a queued waypoint resumes from that point.",
                    "",
                    "Auto-Clear Manual Waypoints on Arrival automatically clears manual waypoints — those set via TomTom's /way command, /ttpaste or any other manually routed waypoints — when you come within the set distance. This does not affect Zygor guide step waypoints.",
                    "",
                    "Manual Waypoint Clear Distance controls the arrival threshold (5–100 yards, default 10).",
                }),
            },
        },
    },
    {
        id = "overlay_overview",
        title = "World Overlay",
        intro = "The overlay places markers in the 3D world that change based on your distance to the destination.",
        blocks = {
            {
                type = "image_row",
                items = {
                    {
                        width = 353,
                        height = 350,
                        texture = "Interface\\AddOns\\ZygorWaypoint\\media\\help\\Waypoint",
                        placeholder = "Waypoint long-range screenshot placeholder",
                        caption = "Waypoint — long range",
                    },
                    {
                        width = 100,
                        height = 73,
                        valign = "center",
                        texture = "Interface\\AddOns\\ZygorWaypoint\\media\\help\\Navigator",
                        placeholder = "Navigator off-screen screenshot placeholder",
                        caption = "Navigator — off screen",
                    },
                    {
                        width = 350,
                        height = 283,
                        valign = "center",
                        texture = "Interface\\AddOns\\ZygorWaypoint\\media\\help\\Pinpoint",
                        placeholder = "Pinpoint close-range screenshot placeholder",
                        caption = "Pinpoint — close range",
                    },
                    
                },
            },
            {
                type = "text",
                text = JoinLines({
                    "The three components hand off based on distance:",
                    "",
                    "- Waypoint is the large 3D marker shown when you are far from the destination. Settings to control most aspects of the waypoint are available.",
                    "- Pinpoint swaps places with the Waypoint at close range, showing a destination panel above the target location. There are many things including different plaques and more you can configure in the settings.",
                    "- Navigator appears when the Waypoint is off screen, showing a directional arrow pointing towards it from the screen edge.",
                    "",
                    "Start with Enable 3D World Overlay, Fade on Hover, and Context Display. Use Meters instead of Yards switches the Waypoint footer from yards to meters if you prefer metric.",
                }),
            },
            {
                type = "heading",
                text = "Context Display",
            },
            {
                type = "image_row",
                items = {
                    {
                        width = 250,
                        height = 129,
                        texture = "Interface\\AddOns\\ZygorWaypoint\\media\\help\\FullContext",
                        placeholder = "Context Diamond + Icon screenshot placeholder",
                        caption = "Context Diamond + Icon",
                    },
                    {
                        width = 250,
                        height = 129,
                        texture = "Interface\\AddOns\\ZygorWaypoint\\media\\help\\IconOnly",
                        placeholder = "Icon Only screenshot placeholder",
                        caption = "Icon Only",
                    },
                    {
                        width = 250,
                        height = 129,
                        texture = "Interface\\AddOns\\ZygorWaypoint\\media\\help\\ContextHidden",
                        placeholder = "Context Hidden screenshot placeholder",
                        caption = "Hidden",
                    },
                },
            },
            {
                type = "text",
                text = JoinLines({
                    "Context Display controls what appears behind the waypoint icon:",
                    "- Context Diamond + Icon shows the diamond background shape with the icon inside it.",
                    "- Icon Only shows just the icon without the background shape.",
                    "- Hidden removes both the diamond and the icon.",
                }),
            },
            {
                type = "heading",
                text = "Beacon",
            },
            {
                type = "image_row",
                items = {
                    {
                        width = 250,
                        height = 171,
                        texture = "Interface\\AddOns\\ZygorWaypoint\\media\\help\\Beacon",
                        placeholder = "Beacon enabled screenshot placeholder",
                        caption = "Beacon enabled",
                    },
                    {
                        width = 250,
                        height = 171,
                        texture = "Interface\\AddOns\\ZygorWaypoint\\media\\help\\BaseOnly",
                        placeholder = "Beacon disabled screenshot placeholder",
                        caption = "Beacon base only",
                    },
                    {
                        width = 250,
                        height = 171,
                        texture = "Interface\\AddOns\\ZygorWaypoint\\media\\help\\BeaconOff",
                        placeholder = "Beacon disabled screenshot placeholder",
                        caption = "Beacon disabled",
                    },
                },
            },
            {
                type = "text",
                text = JoinLines({
                    "Beacon and Beacon Opacity control the vertical light column that rises from the waypoint marker, making the destination easier to spot at a distance. It can be set to full beacon, base only, or off.",
                }),
            },
        },
    },
    {
        id = "overlay_waypoint_navigator",
        title = "Waypoint and Navigator",
        intro = "These settings control the long-range marker and the off-screen direction arrow.",
        blocks = {
            {
                type = "image_row",
                items = {
                    {
                        width = 355,
                        height = 358,
                        texture = "Interface\\AddOns\\ZygorWaypoint\\media\\help\\Waypoint",
                        placeholder = "Waypoint screenshot placeholder",
                        caption = "Waypoint",
                    },
                    {
                        width = 220,
                        height = 160,
                        valign = "center",
                        texture = "Interface\\AddOns\\ZygorWaypoint\\media\\help\\Navigator",
                        placeholder = "Navigator screenshot placeholder",
                        caption = "Navigator",
                    },
                },
            },
            {
                type = "heading",
                text = "Waypoint",
            },
            {
                type = "text",
                text = JoinLines({
                    "- Waypoint mode turns the long-range marker on or off.",
                    "- Waypoint Size, Waypoint Min Size, and Waypoint Max Size control the dynamic scaling range.",
                    "- Waypoint Opacity controls how visible the marker shows on screen.",
                    "- Waypoint Vertical Offset adjusts how high or low the marker appears above the ground.",
                    "- Beacon and Beacon Opacity control the vertical light column rising from the marker.",
                    "- Footer Text, Info Text Size, Info Text Opacity, and Distance/Arrival Time Opacity control the text shown below the marker — destination name, distance, and estimated arrival time.",
                }),
            },
            {
                type = "heading",
                text = "Navigator",
            },
            {
                type = "text",
                text = JoinLines({
                    "- Enable Navigator enables the off-screen guide arrow.",
                    "- Navigator Size and Navigator Opacity controls how it's visually displayed.",
                    "- Navigator Distance moves it farther from or closer to the screen edge.",
                    "- Navigator Dynamic Distance adjusts how far the navigator sits from the screen center based on your camera zoom level, keeping its position visually balanced as you zoom in or out.",
                }),
            },
        },
    },
    {
        id = "overlay_pinpoint_plaque",
        title = "Pinpoint and Plaque",
        intro = "These settings control the close-range destination visuals, plaque style, and text details.",
        blocks = {
            {
                type = "image",
                align = "CENTER",
                width = 396,
                height = 115,
                texture = "Interface\\AddOns\\ZygorWaypoint\\media\\help\\PlaqueDefault",
                placeholder = "Default plaque screenshot placeholder",
                caption = "Default — classic fantasy border panel",
            },
            {
                type = "text",
                text = JoinLines({
                    "- Pinpoint Mode decides whether the close-range display is shown in full (with plaque), shown without the plaque, or disabled.",
                    "- Show Pinpoint At and Hide Pinpoint At define the distance range where the pinpoint is visible.",
                    "- Pinpoint Size and Pinpoint Opacity controls the size and visibility of the close-range marker.",
                    "- Camera Pinpoint Height and Base Pinpoint Height control vertical placement behavior.",
                    "- Show Destination Info, Show Extended Info, Show Coordinate Fallback, and Show Pinpoint Arrows control how much detail appears inside the plaque.",
                }),
            },
            {
                type = "heading",
                text = "Plaque Styles",
            },
            
            {
                type = "image",
                align = "CENTER",
                width = 397,
                height = 135,
                texture = "Interface\\AddOns\\ZygorWaypoint\\media\\help\\PlaqueGlowingGems",
                placeholder = "Glowing Gems plaque screenshot placeholder",
                caption = "Glowing Gems — ornate gem-set border with animated corner gems and glow effects",
            },
            {
                type = "image",
                align = "CENTER",
                width = 396,
                height = 167,
                texture = "Interface\\AddOns\\ZygorWaypoint\\media\\help\\PlaqueHorde",
                placeholder = "Horde plaque screenshot placeholder",
                caption = "Horde — faction-styled panel with Horde design elements",
            },
            {
                type = "image",
                align = "CENTER",
                width = 396,
                height = 149,
                texture = "Interface\\AddOns\\ZygorWaypoint\\media\\help\\PlaqueAlliance",
                placeholder = "Alliance plaque screenshot placeholder",
                caption = "Alliance — faction-styled panel with Alliance design elements",
            },
            {
                type = "image",
                align = "CENTER",
                width = 397,
                height = 128,
                texture = "Interface\\AddOns\\ZygorWaypoint\\media\\help\\PlaqueModern",
                placeholder = "Modern plaque screenshot placeholder",
                caption = "Modern — sleek contemporary panel with minimal border",
            },
            {
                type = "image",
                align = "CENTER",
                width = 412,
                height = 162,
                texture = "Interface\\AddOns\\ZygorWaypoint\\media\\help\\PlaqueModern",
                placeholder = "Steampunk plaque screenshot placeholder",
                caption = "Steampunk — industrial design with heavy mechanical side assemblies",
            },
            {
                type = "note",
                text = "Animate Plaque Effects toggles glow and pulse on plaques that support it. Disabling this setting disables those effects. Not all plaques have animations.",
            },
        },
    },
    {
        id = "customization",
        title = "Customization",
        intro = "Use the options panel to finetune your settings.",
        blocks = {
            {
                type = "note",
                text = "Fastest visual pass: Context Display, Plaque Style, the arrow skin choice, and the overlay color controls give the most visible results with the fewest changes.",
            },
            {
                type = "image",
                align = "CENTER",
                width = 580,
                height = 400,
                texture = "Interface\\AddOns\\ZygorWaypoint\\media\\help\\ZWPOptions",
                placeholder = "Options panel screenshot placeholder",
                caption = "Options panel",
            },
            {
                type = "text",
                text = JoinLines({
                    "Path: Game Menu -> Options -> AddOns -> ZygorWaypoint",
                    "",
                    "- Main 'ZygorWaypoint' section covers routing, compact guide modes, /ttpaste queue handling, and manual waypoint auto clear.",
                    "- TomTom Arrow covers skin selection, scale, and related settings.",
                    "- World Overlay is split into main overlay settings plus Waypoint, Pinpoint, and Navigator subcategories.",
                    "",
                    "If settings are behaving unexpectedly after an upgrade, /zwp repair resets TomTom and Zygor settings that ZygorWaypoint depends on back to their default values.",
                }),
            },
            {
                type = "heading",
                text = "Colors and Dynamic Tinting",
            },
            {
                type = "text",
                text = JoinLines({
                    "By default, overlay elements follow dynamic contextual colors that change based on what you are navigating to. Each quest type, NPC type, and travel type has its own color — campaign quests are orange, daily quests are blue, a search for an auctioneer is gold, a flight master is light blue, and so on.",
                    "",
                    "Setting a custom color for any element locks it to that fixed color and overrides the dynamic behavior for that element only. You get full control, but lose the contextual color cue for whatever you override.",
                    "",
                    "Overridable elements:",
                    "- Context Diamond — the background shape behind the waypoint icon",
                    "- Icons — the icon glyph inside the context diamond",
                    "- Waypoint Text — the destination name and distance shown below the waypoint",
                    "- Beacon — the vertical light column rising from the waypoint",
                    "- Pinpoint Title — the main destination name on the pinpoint panel",
                    "- Pinpoint Subtext — the secondary text below the title",
                    "- Pinpoint Plaque — the plaque panel background",
                    "- Animated Parts — elements with dynamic effects such as glow pulses",
                    "- Chevrons — the stacked downwards arrows under the pinpoint",
                    "- NavArrow — the off-screen navigator arrow",
                }),
            },
        },
    },
    {
        id = "commands",
        title = "Commands",
        intro = "Everyday commands worth remembering.",
        blocks = {
            {
                type = "heading",
                text = "Help and Settings",
            },
            {
                type = "text",
                text = JoinLines({
                    "/zwp help",
                    "- Open this help system.",
                    "",
                    "/zwp changelog",
                    "- Jump straight to the What's New page.",
                    "",
                    "/zwp options",
                    "- Open the addon options panel.",
                    "",
                    "/zwp repair",
                    "- Check and reset TomTom and Zygor settings that ZygorWaypoint depends on back to their required values. Run this if the addon is behaving unexpectedly after an upgrade.",
                }),
            },
            {
                type = "heading",
                text = "Arrow and Skin",
            },
            {
                type = "text",
                text = JoinLines({
                    "/zwp skin default|starlight|stealth",
                    "- Set the TomTom arrow skin.",
                    "",
                    "/zwp scale <0.60-2.00>",
                    "- Set the arrow size. Has no effect when skin is set to default.",
                    "",
                    "/zwp align on|off",
                    "- Anchor the TomTom arrow to Zygor's text position.",
                }),
            },
            {
                type = "heading",
                text = "Routing and Guide",
            },
            {
                type = "text",
                text = JoinLines({
                    "/zwp routing on|off|toggle",
                    "- Route TomTom waypoints through Zygor's pathfinding.",
                    "",
                    "/zwp compact on|off|toggle",
                    "- Toggle compact guide presentation.",
                    "",
                    "/zwp manualclear on|off|toggle",
                    "- Auto-clear manual waypoints when you arrive at the destination.",
                    "",
                    "/zwp cleardistance <5-100>",
                    "- Set the arrival clear distance in yards.",
                }),
            },
            {
                type = "heading",
                text = "Search",
            },
            {
                type = "text",
                text = JoinLines({
                    "/zwp search <service>",
                    "- Find the nearest matching service and route to it via Zygor's travel system.",
                    "",
                    "Services:",
                    "  vendor (store)  |  auctioneer (ah, auction)  |  banker (bank)",
                    "  barber (barbershop)  |  flightmaster  |  innkeeper (inn)",
                    "  mailbox (mail)  |  repair  |  riding trainer (riding)",
                    "  stable master (stable, stables)  |  transmogrifier (mog, tmog)  |  void storage (void)",
                    "",
                    "/zwp search trainer <profession>",
                    "/zwp search workshop <profession>",
                    "- Route to a profession trainer or profession workshop.",
                    "",
                    "Professions:",
                    "  alchemy  |  archaeology  |  bandages  |  blacksmithing  |  cooking",
                    "  enchanting  |  engineering  |  fishing  |  herbalism  |  inscription",
                    "  jewelcrafting  |  leatherworking  |  mining  |  skinning  |  tailoring",
                    "",
                    "/zwp search help",
                    "- Print the full list in chat.",
                }),
            },
        },
    },
    {
        id = "whats_new",
        title = "What's New",
        intro = "Recent highlights from the last three recorded versions.",
        blocks = {
            {
                type = "recent_changelog",
                limit = 3,
            },
        },
    },
}
