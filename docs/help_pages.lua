local NS = _G.AzerothWaypointNS

local ADDON_NAME = NS.ADDON_NAME or "AzerothWaypoint"
local MEDIA_ROOT = "Interface\\AddOns\\AzerothWaypoint\\media\\"
local MEDIA = "Interface\\AddOns\\AzerothWaypoint\\media\\help\\"

local function JoinLines(lines)
    return table.concat(lines, "\n")
end

-- Help page schema:
-- Each page supports:
--   id      = unique page key used by NS.ShowHelp("page_id")
--   title   = page title shown in the help frame
--   hideTitle = true hides the in-page title while keeping title metadata
--   intro   = optional short intro line shown under the title
--   blocks  = ordered content blocks rendered top-to-bottom
--
-- Supported block types:
--   { type = "heading", text = "Section Title" }
--   { type = "text", text = "Body text" }
--   { type = "note", text = "Smaller secondary text", align = "CENTER", accent = false }
--   { type = "divider" }
--   {
--       type = "image",
--       width = 700,
--       height = 220,
--       texture = MEDIA .. "MainShot",
--       texCoord = { 0, 1, 0, 1 },
--       align = "CENTER",
--       placeholder = "Shown when texture is missing",
--       caption = "Optional caption below the image",
--   }
--   {
--       type = "image_row",
--       gap = 12,
--       items = {
--           {
--               width = 330,
--               height = 150,
--               texture = MEDIA .. "Starlight",
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
-- New placeholder image names added in this pass:
--   MEDIA .. "QueuePanel"
--   MEDIA .. "QueueDetails"
--   MEDIA .. "BlizzardTakeover"
--   MEDIA .. "ExternalSource"
--
NS.HELP_PAGES = {
    {
        id = "overview",
        title = "Overview",
        hideTitle = true,
        blocks = {
            {
                type = "image",
                texture = MEDIA_ROOT .. "banner.png",
                align = "CENTER",
                width = 768,
                height = 256,
                frameless = true,
                spacingAfter = 14,
            },
            {
                type = "note",
                align = "CENTER",
                accent = false,
                text =
                "ZygorWaypoint is now AzerothWaypoint. TomTom is the only required addon. Zygor is still fully supported, but it is now optional.",
            },
            {
                type = "heading",
                text = "What AWP Does",
            },
            {
                type = "text",
                text = JoinLines({
                    ADDON_NAME ..
                    " takes destinations from multiple sources and presents the active route through TomTom, the queue UI, and the 3D world overlay.",
                    "",
                    "Common sources include:",
                    "",
                    "- TomTom waypoints and /way commands.",
                    "- Guide steps from Azeroth Pilot Reloaded, WoWPro, and Zygor",
                    "- Blizzard map clicks, quest POIs, supertracked quests, tracked quests, area POIs, taxi nodes, vignettes, dig sites, gossip POIs, and housing plots.",
                    "- Imported /ttpaste waypoint batches.",
                    "- Supported external addon waypoints from SilverDragon, RareScanner, and similar transient sources.",
                    "",
                    "Simple rule:",
                    "",
                    "TomTom shows the arrow.",
                    "AWP controls the route flow.",
                    "Optional integrations provide richer routing and guide data.",
                }),
            },
            {
                type = "heading",
                text = "Where To Start",
            },
            {
                type = "text",
                text = JoinLines({
                    "- Use /awp options to configure routing, queues, the TomTom arrow, and the world overlay.",
                    "- Use /awp status to check the active backend, loaded integrations, and key toggles.",
                    "- Use /awp queue to manage manual queues, imported routes, and guide queue projections.",
                    "- Use /awp changelog to see recent changes.",
                    "",
                    "The next help pages explain routing, queues, the TomTom arrow, the 3D overlay, customization, and commands.",
                }),
            },
        },
    },
    {
        id = "routing_guides",
        title = "Routing and Guide Providers",
        intro = "AWP separates where a destination came from, how the route is planned, and how it is shown.",
        blocks = {
            {
                type = "image",
                texture = MEDIA .. "OptionsGeneral",
                align = "CENTER",
                width = 512,
                height = 315,
                placeholder = "Options panel screenshot placeholder",
                caption = "General options control routing backend, queues, quest tracking, and addon waypoint adoption.",
            },
            {
                type = "heading",
                text = "The Navigation Model",
            },
            {
                type = "text",
                text = JoinLines({
                    "AWP tracks three separate pieces of navigation state:",
                    "",
                    "- Source: where the destination came from.",
                    "- Backend: how the route is planned.",
                    "- Carrier: what displays the route.",
                    "",
                    "Examples:",
                    "",
                    "- Source: manual click, guide provider, quest, POI, addon waypoint, or imported queue.",
                    "- Backend: Farstrider, Mapzeroth, Zygor, or TomTom directly, ",
                    "- Carrier: TomTom Arrow and the AWP 3D world overlay.",
                    "",
                    "Keeping these separate helps prevent navigation sources from constantly overwriting each other. A guide queue can stay visible while a manual route is active, and a manual queue can survive when a guide temporarily takes control.",
                }),
            },
            {
                type = "heading",
                text = "Routing Backends",
            },
            {
                type = "text",
                text = JoinLines({
                    "Routing Backend controls how AWP plans the active destination.",
                    "",
                    "- TomTom Direct: this is PURE TomTom making it always available. Routes straight to the selected target no pathfinding. Not advised for most users.",
                    "- Farstrider: uses FarstriderLib and FarstriderLibData when available. This I would say is second only to Zygor. Highly recommended.",
                    "- Mapzeroth: uses Mapzeroth pathfinding data when available. This one works well but is not as comprehensive as Farstrider at the moment.",
                    "- Zygor: uses Zygor and LibRover when Zygor is installed. This is the GOLD standard for routing.",
                    "",
                    "If the selected backend is missing or not enabled AWP falls back safely.",
                    "",
                    "Slash command examples:",
                    "",
                    "/awp backend direct",
                    "/awp backend farstrider",
                    "/awp backend mapzeroth",
                    "/awp backend zygor",
                }),
            },
            {
                type = "note",
                text =
                "Use TomTom Direct if you want simple point-to-point navigation with no pathfinding. Use Farstrider, Mapzeroth, or Zygor when you want travel-aware routing with flights, portals, transports, items, spells, or other travel nodes.",
            },
            {
                type = "heading",
                text = "Guide Providers",
            },
            {
                type = "text",
                text = JoinLines({
                    "AWP can read guide targets from:",
                    "",
                    "- Zygor Guides Viewer",
                    "- Azeroth Pilot Reloaded",
                    "- WoWPro",
                    "",
                    "Zygor remains the deepest integration because it can provide LibRover routing, richer guide metadata, search data, and Zygor-style arrow skins. APR and WoWPro still provides guide targets, step text, objective context, and actionable overlay text when their data is available.",
                }),
            },
            {
                type = "note",
                text =
                "A guide appearing in the queue does not always mean it currently owns navigation. Manual queues, transient addon routes, quest routes, and active guide providers can all take turns controlling the active route.",
            },
            {
                type = "heading",
                text = "Blizzard Map and Quest Sources",
            },
            {
                type = "image",
                texture = MEDIA .. "BlizzardPOI",
                align = "CENTER",
                width = 512,
                height = 485,
                caption = "Blizzard quest pins, POIs, and map sources can be adopted into AWP routing.",
            },
            {
                type = "text",
                text = JoinLines({
                    "AWP can adopt supported Blizzard navigation sources and route them through the active backend.",
                    "",
                    "Supported Blizzard sources include:",
                    "",
                    "- user waypoints",
                    "- quest POIs",
                    "- supertracked quests",
                    "- tracked quests",
                    "- area POIs",
                    "- vignettes",
                    "- taxi nodes",
                    "- gossip POIs",
                    "- dig sites",
                    "- housing plots",
                    "",
                    "Quest-backed destinations can use quest-aware titles, icons, progress text, and clearing behavior when Blizzard exposes the needed data.",
                }),
            },
            {
                type = "note",
                text =
                "Use Blizzard takeover support when you want map clicks, quest pins, tracked quests, or supertracked quests to route through AWP instead of behaving like unrelated one-off waypoints.",
            },
            {
                type = "heading",
                text = "External Addon Sources",
            },
            {
                type = "image",
                texture = MEDIA .. "SilverDragon",
                align = "CENTER",
                width = 512,
                height = 472,
                caption =
                "Supported external addons such as SilverDragon waypoints can temporarily take over navigation without destroying manual queues.",
            },
            {
                type = "text",
                text = JoinLines({
                    "AWP includes source-aware handling for supported addon-created waypoints.",
                    "",
                    "Current source-aware integrations include:",
                    "",
                    "- SilverDragon",
                    "- RareScanner",
                    "",
                    "These are handled as transient manual sources, so a rare scan or similar temporary route can briefly take over navigation without deleting your persistent manual queues.",
                }),
            },
            {
                type = "note",
                text =
                "Use addon waypoint adoption when you want known or approved addon-created TomTom waypoints to appear as temporary AWP routes. Use the allowlist and blocklist if unknown addon callers need stricter control.",
            },
        },
    },
    {
        id = "queues",
        title = "Waypoint Queues",
        intro =
        "Queues let manual routes, imported waypoint batches, transient addon routes, and guide projections coexist.",
        blocks = {
            {
                type = "image",
                texture = MEDIA .. "QueueUIMain",
                align = "CENTER",
                width = 273,
                height = 350,
                placeholder = "Queue panel screenshot placeholder",
                caption =
                "The queue panel shows manual queues, guide queues, imported waypoint lists (ttpaste), and transient routes.",
            },
            {
                type = "heading",
                text = "What Queues Are For",
            },
            {
                type = "text",
                text = JoinLines({
                    "Queues let AWP keep track of destinations without treating every waypoint as a throwaway TomTom point.",
                    "",
                    "Open it from the world map side tab or with:",
                    "",
                    "/awp queue",
                }),
            },
            {
                type = "note",
                text =
                "Use the queue panel when you want to inspect what currently owns navigation, reactivate an older queue, manage imported waypoints such as those from ttpaste, or remove queues.",
            },
            {
                type = "heading",
                text = "Queue Types",
            },
            {
                type = "text",
                text = JoinLines({
                    "- Manual queues are created from map clicks, /way commands, Blizzard user waypoints, and imports.",
                    "- Imported queues preserve /ttpaste order and can advance as you clear each point.",
                    "- Transient queues are short-lived sources such as SilverDragon, RareScanner, gossip POIs such as guard directions, or other temporary navigation sources.",
                    "- Guide queues are provided by the guide providers and are read-only and auto update with the guide.",
                }),
            },
            {
                type = "heading",
                text = "Manual Click Queue Behavior",
            },
            {
                type = "image",
                texture = MEDIA .. "ManualQueueAsk",
                align = "CENTER",
                width = 590,
                height = 236,
                placeholder = "Manual queue prompt screenshot placeholder",
                caption = "Ask mode lets each manual click create, replace, or append.",
            },
            {
                type = "text",
                text = JoinLines({
                    "Manual Click Queue Behavior controls what happens when you click a destination on the map:",
                    "",
                    "- Create New Queue: put the clicked destination in its own new queue.",
                    "- Replace Active: replace the currently active manual queue.",
                    "- Append: add the clicked destination to the current queue.",
                    "- Ask: show a prompt each time.",
                    "",
                    "Use Activate Queue when you want a queue to control navigation. Use Deactivate Queue when you want to stop using it without deleting it.",
                }),
            },
            {
                type = "note",
                text =
                "Use Replace Active if you usually want each new map click to become your current destination. Use Append if you are building a route with multiple stops. Use Ask if you switch between both behaviors often.",
            },
            {
                type = "heading",
                text = "Queue Details",
            },
            {
                type = "image",
                texture = MEDIA .. "QueueUIDetails",
                align = "CENTER",
                width = 273,
                height = 350,
                placeholder = "Queue detail page screenshot placeholder",
                caption =
                "Queue details let you inspect destinations, activate queues, delete entries, and show the final destination on the map.",
            },
            {
                type = "text",
                text = JoinLines({
                    "Queue detail pages are useful when a route has more than one destination or when you want to review what AWP imported from /ttpaste or another source.",
                }),
            },
            {
                type = "heading",
                text = "Bulk Management",
            },
            {
                type = "text",
                text = JoinLines({
                    "Queue rows and destination rows can be selected with checkboxes.",
                    "",
                    "The delete icon removes selected queues or selected destinations. Guide queues remain protected from destructive actions and are read-only.",
                }),
            },
            {
                type = "note",
                text =
                "Imported /ttpaste routes are always routed as AWP queues. If an import is not forming a queue, use /awp status and /awp queue to confirm what AWP detected.",
            },
        },
    },
    {
        id = "arrow_guide",
        title = "TomTom Arrow and Travel Actions",
        intro = "TomTom remains the arrow. AWP controls which route owns it and how travel actions are presented.",
        blocks = {
            {
                type = "heading",
                text = "TomTom Arrow Bridge",
            },
            {
                type = "text",
                text = JoinLines({
                    "AWP uses TomTom as the main navigation arrow instead of creating another competing arrow.",
                    "",
                    "AWP can:",
                    "",
                    "- send guide, quest, POI, queue, and addon destinations to TomTom.",
                    "- preserve normal TomTom behavior for direct waypoints.",
                    "- apply custom TomTom arrow skins.",
                    "- show secure travel buttons for route legs that require a click action.",
                }),
            },
            {
                type = "note",
                text =
                "AWP allows you to use TomTom as your navigation arrow with richer sources, routes, queues, and a 3D overlay.",
            },
            {
                type = "heading",
                text = "TomTom Arrow Skins",
            },
            {
                type = "image_row",
                gap = 10,
                items = {
                    { width = 132, height = 183, texture = MEDIA .. "AWP",       placeholder = "AWP",        caption = "AWP" },
                    { width = 132, height = 183, texture = MEDIA .. "AWPBomber", placeholder = "AWP Bomber", caption = "Bomber" },
                    { width = 132, height = 212, texture = MEDIA .. "AWPModern", placeholder = "AWP Modern", caption = "Modern" },
                    { width = 132, height = 208, texture = MEDIA .. "Alliance",  placeholder = "Alliance",   caption = "Alliance" },
                    { width = 132, height = 208, texture = MEDIA .. "Horde",     placeholder = "Horde",      caption = "Horde" },
                },
            },
            {
                type = "text",
                text = JoinLines({
                    "Built-in AWP skins include AWP, AWP Bomber, AWP Modern, Alliance, and Horde.",
                    "",
                    "When Zygor is installed and enabled, Starlight and Stealth will be available so TomTom can visually match Zygor's style.",
                }),
            },
            {
                type = "image_row",
                items = {
                    { width = 330, height = 150, texture = MEDIA .. "Starlight", placeholder = "Starlight arrow screenshot placeholder", caption = "Zygor Starlight" },
                    { width = 330, height = 150, texture = MEDIA .. "Stealth",   placeholder = "Stealth arrow screenshot placeholder",   caption = "Zygor Stealth" },
                },
            },
            {
                type = "heading",
                text = "Special Travel Button",
            },
            {
                type = "image",
                texture = MEDIA .. "TravelButton",
                align = "CENTER",
                width = 297,
                height = 102,
                placeholder = "Special travel button screenshot placeholder",
                caption =
                "Shown when the current route leg needs an item, spell, toy, portal, hearthstone, or similar action.",
            },
            {
                type = "text",
                text = JoinLines({
                    "Some travel routes require items, spells, toys, hearthstones, portals, or similar route steps.",
                    "",
                    "When the current route leg needs one of those actions, AWP will show a special travel button in place of the TomTom arrow.",
                    "",
                    "Use Special Travel Button Scale if the button is too large or too small for your UI.",
                }),
            },
            {
                type = "note",
                text =
                "The special travel button is used when a routing backend identifies that the next route leg is not normal travel. It is expected to appear only for route legs that provide a usable action.",
            },
            {
                type = "heading",
                text = "Zygor Viewer Options",
            },
            {
                type = "image_row",
                items = {
                    { width = 220, height = 80, texture = MEDIA .. "Normal",                  placeholder = "Normal guide view",           caption = "Normal" },
                    { width = 220, height = 80, texture = MEDIA .. "MinimalMode",             placeholder = "Compact guide mode",          caption = "Compact" },
                    { width = 220, height = 80, texture = MEDIA .. "MinimalModeHideBGColors", placeholder = "Compact mode without colors", caption = "Hide Step Backgrounds + Line Colors" },
                },
            },
            {
                type = "text",
                text = JoinLines({
                    "When Zygor is loaded, AWP can compact the guide frame until mouseover and can hide step backgrounds or line colors while compacted.",
                    "",
                    "These options only appear when Zygor is available.",
                }),
            },
        },
    },
    {
        id = "overlay_overview",
        title = "World Overlay",
        intro =
        "The world overlay shows the active destination in-world and changes mode based on distance and camera view.",
        blocks = {
            {
                type = "image_row",
                items = {
                    { width = 330, height = 330, texture = MEDIA .. "Overlay",     placeholder = "Overlay screenshot placeholder",      caption = "Overlay" },
                    { width = 330, height = 330, texture = MEDIA .. "OverlayFade", placeholder = "Overlay fade screenshot placeholder", caption = "Fade on hover" },
                },
            },
            {
                type = "heading",
                text = "Overlay Modes",
            },
            {
                type = "text",
                text = JoinLines({
                    "The world overlay has three main presentation modes:",
                    "",
                    "- Waypoint: long-range in-world destination marker.",
                    "- Pinpoint: close-range destination marker and optional plaque.",
                    "- Navigator: off-screen directional arrow.",
                    "",
                    "The overlay can react to destination context. Quests, route types, services, travel actions, guide providers, and source addons can all affect icons, title text, subtext, and colors.",
                }),
            },
            {
                type = "note",
                text =
                "Use the 3D world overlay when you want destination context in the game world instead of only relying on the TomTom arrow. Disable or reduce opacity if you prefer a cleaner screen.",
            },
            {
                type = "heading",
                text = "Context Display",
            },
            {
                type = "image_row",
                items = {
                    { width = 220, height = 114, texture = MEDIA .. "FullContext",   placeholder = "Context diamond and icon", caption = "Diamond + Icon" },
                    { width = 220, height = 114, texture = MEDIA .. "IconOnly",      placeholder = "Icon only",                caption = "Icon Only" },
                    { width = 220, height = 114, texture = MEDIA .. "ContextHidden", placeholder = "Context hidden",           caption = "Hidden" },
                },
            },
            {
                type = "text",
                text = JoinLines({
                    "Context Display controls the icon frame above the waypoint:",
                    "",
                    "- Diamond + Icon shows both the context diamond and icon.",
                    "- Icon Only removes the backing diamond.",
                    "- Hidden removes both the diamond and icon.",
                }),
            },
            {
                type = "note",
                text =
                "Use Diamond + Icon for the clearest source/type indicator. Use Icon Only for a cleaner look. Use Hidden if you only want the marker and text without extra context art.",
            },
            {
                type = "heading",
                text = "Beacon",
            },
            {
                type = "image_row",
                items = {
                    { width = 220, height = 151, texture = MEDIA .. "Beacon",    placeholder = "Beacon enabled",  caption = "Beacon" },
                    { width = 220, height = 151, texture = MEDIA .. "BaseOnly",  placeholder = "Base only",       caption = "Base Only" },
                    { width = 220, height = 151, texture = MEDIA .. "BeaconOff", placeholder = "Beacon disabled", caption = "Off" },
                },
            },
            {
                type = "text",
                text = JoinLines({
                    "Beacon settings control the vertical light column and base marker used by the long-range waypoint display.",
                    "",
                    "You can adjust beacon style, base distance, opacity, vertical offset, and color from the Waypoint options page.",
                }),
            },
        },
    },
    {
        id = "overlay_waypoint_navigator",
        title = "Waypoint and Navigator",
        intro =
        "Waypoint handles long-range destination display. Navigator points toward destinations that are off screen.",
        blocks = {
            {
                type = "image_row",
                items = {
                    { width = 320, height = 317, texture = MEDIA .. "Waypoint",  placeholder = "Waypoint screenshot placeholder",  caption = "Waypoint" },
                    { width = 360, height = 235, texture = MEDIA .. "Navigator", placeholder = "Navigator screenshot placeholder", caption = "Navigator" },
                },
            },
            {
                type = "heading",
                text = "Waypoint Settings",
            },
            {
                type = "text",
                text = JoinLines({
                    "Waypoint controls the long-range marker shown in the 3D world.",
                    "",
                    "- Waypoint Mode turns the long-range marker on or off.",
                    "- Waypoint Size, Min Size, and Max Size control dynamic scaling.",
                    "- Waypoint Opacity controls marker visibility.",
                    "- Vertical Offset moves the marker up or down in the world.",
                    "- Beacon settings control the vertical light column and base marker.",
                    "- Use Meters instead of Yards changes footer distance formatting.",
                }),
            },
            {
                type = "note",
                text =
                "Use a larger max size when you want distant markers to stay readable. Use lower opacity or disable the beacon if the long-range marker feels too visually heavy.",
            },
            {
                type = "heading",
                text = "Footer Text",
            },
            {
                type = "image_row",
                gap = 10,
                items = {
                    { width = 130, height = 78, texture = MEDIA .. "WaypointFooterAll",             placeholder = "All footer",       caption = "All" },
                    { width = 130, height = 78, texture = MEDIA .. "WaypointFooterDistance",        placeholder = "Distance footer",  caption = "Distance" },
                    { width = 130, height = 78, texture = MEDIA .. "WaypointFooterArrivalTime",     placeholder = "Arrival footer",   caption = "Arrival Time" },
                    { width = 130, height = 78, texture = MEDIA .. "WaypointFooterDestinationName", placeholder = "Destination name", caption = "Destination" },
                    { width = 130, height = 78, texture = MEDIA .. "WaypointFooterNone",            placeholder = "No footer",        caption = "None" },
                },
            },
            {
                type = "text",
                text = JoinLines({
                    "Footer Text controls the small text below the waypoint marker.",
                    "",
                    "It can show destination name, distance, arrival time, all supported footer details, or no footer at all.",
                    "",
                    "Footer size and opacity are controlled separately.",
                }),
            },
            {
                type = "note",
                text =
                "Use Distance or Arrival Time for simple travel guidance. Use Name when destination identity matters more than distance. Use None if you only want the visual marker.",
            },
            {
                type = "heading",
                text = "Navigator Settings",
            },
            {
                type = "text",
                text = JoinLines({
                    "Navigator is the off-screen arrow that points toward the active destination when it is outside your current view.",
                    "",
                    "- Enable Navigator toggles the off-screen arrow.",
                    "- Navigator Size and Opacity control visual weight.",
                    "- Navigator Distance moves it closer to or farther from the screen center.",
                    "- Navigator Dynamic Distance adjusts placement based on camera zoom.",
                    "- Navigator Arrow color controls the navigator arrow tint.",
                }),
            },
            {
                type = "note",
                text =
                "Use Navigator Dynamic Distance if the off-screen arrow feels good at one camera zoom but too close or too far away at another.",
            },
        },
    },
    {
        id = "overlay_pinpoint_plaque",
        title = "Pinpoint and Plaque",
        intro =
        "Pinpoint is the close-range destination marker. Plaques can show title, subtext, coordinates, and extra context.",
        blocks = {
            {
                type = "image_row",
                items = {
                    { width = 220, height = 168, texture = MEDIA .. "Pinpoint",          placeholder = "Pinpoint full",      caption = "Full" },
                    { width = 220, height = 168, texture = MEDIA .. "PinpointPlaqueOff", placeholder = "Pinpoint no plaque", caption = "No Plaque" },
                    { width = 220, height = 168, texture = MEDIA .. "PinpointOff",       placeholder = "Pinpoint disabled",  caption = "Disabled" },
                },
            },
            {
                type = "heading",
                text = "Pinpoint Settings",
            },
            {
                type = "text",
                text = JoinLines({
                    "Pinpoint controls what appears when you are close to the destination.",
                    "",
                    "- Pinpoint Mode chooses full, no plaque, or disabled.",
                    "- Show Pinpoint At controls when close-range mode begins.",
                    "- Hide Pinpoint At controls when arrival hides the close-range display.",
                    "- Pinpoint Size and Opacity control the marker.",
                    "- Show Destination Info controls the title/subtext plaque.",
                    "- Show Extended Info adds extra context when available.",
                    "- Show Coordinate Fallback allows coordinates when no better label is available.",
                    "- Show Pinpoint Arrows toggles the close-range arrow indicators.",
                    "- Base Pinpoint Height and Camera Pinpoint Height control vertical placement.",
                }),
            },
            {
                type = "note",
                text =
                "Use Full if you want close-range destination labels. Use No Plaque if you like the arrival marker but not the text panel. Use Disabled if TomTom's arrow is enough for close-range arrival.",
            },
            {
                type = "heading",
                text = "Plaque Styles",
            },
            {
                type = "image",
                align = "CENTER",
                width = 396,
                height = 112,
                texture = MEDIA .. "PlaqueDefault",
                placeholder = "Default plaque screenshot placeholder",
                caption = "Default",
            },
            {
                type = "image",
                align = "CENTER",
                width = 397,
                height = 135,
                texture = MEDIA .. "PlaqueGlowingGems",
                placeholder = "Glowing Gems plaque screenshot placeholder",
                caption = "Glowing Gems",
            },
            {
                type = "image_row",
                items = {
                    { width = 226, height = 95, texture = MEDIA .. "PlaqueAlliance", placeholder = "Alliance plaque", caption = "Alliance" },
                    { width = 226, height = 95, texture = MEDIA .. "PlaqueHorde",    placeholder = "Horde plaque",    caption = "Horde" },
                    { width = 226, height = 95, texture = MEDIA .. "PlaqueModern",   placeholder = "Modern plaque",   caption = "Modern" },
                },
            },
            {
                type = "image",
                align = "CENTER",
                width = 412,
                height = 162,
                texture = MEDIA .. "PlaqueSteampunk",
                placeholder = "Steampunk plaque screenshot placeholder",
                caption = "Steampunk",
            },
            {
                type = "note",
                text =
                "Animate Plaque Effects toggles glow and pulse effects for plaque styles that support them. Not every plaque style has animated parts.",
            },
        },
    },
    {
        id = "customization",
        title = "Options and Customization",
        intro = "The options panel is searchable and includes previews for visual and behavior settings.",
        blocks = {
            {
                type = "image",
                align = "CENTER",
                width = 567,
                height = 350,
                texture = MEDIA .. "Options",
                placeholder = "Options panel screenshot placeholder",
                caption = "Game Menu > Options > AddOns > AzerothWaypoint",
            },
            {
                type = "heading",
                text = "Option Sections",
            },
            {
                type = "text",
                text = JoinLines({
                    "- About: addon summary, help, release notes, and author links.",
                    "- General: routing backend, manual queues, tracked quests, addon adoption, and cleanup settings.",
                    "- TomTom Arrow: arrow skins, arrow scale, and special travel button scale.",
                    "- World Overlay: global overlay behavior and context display.",
                    "- Waypoint: long-range marker, beacon, footer, distance, and text controls.",
                    "- Pinpoint: close-range marker, plaque, title, subtext, arrows, and effects.",
                    "- Navigator: off-screen arrow behavior.",
                    "- Zygor: compact guide options when Zygor is loaded.",
                }),
            },
            {
                type = "note",
                text =
                "Check the General section when navigation ownership needs adjustment. Use the visual sections when you want to adjust the arrow, overlay, marker, plaque, or navigator needs adjustment.",
            },
            {
                type = "heading",
                text = "Colors and Auto Tint",
            },
            {
                type = "text",
                text = JoinLines({
                    "All overlay color dropdowns include Auto.",
                    "",
                    "Auto uses contextual hints such as quest state, destination type, route type, or source addon.",
                    "",
                    "Choosing a fixed color locks that element to the selected preset. Choosing Custom allows you to select your own custom color for that element.",
                    "",
                    "Waypoint Text defaults to Gray for readability. Choosing Auto makes it follow contextual icon/spec tint instead.",
                    "",
                    "Color presets include Auto, Blue, Custom, Cyan, Gold, Gray, Green, Pink, Purple, Red, Silver, and White.",
                }),
            },
            {
                type = "note",
                text =
                "Use Auto when you want quest state, source addon, or route type to drive color. Use a fixed color when you want a consistent UI theme no matter what kind of destination is active.",
            },
            {
                type = "heading",
                text = "Images, Search, and Filters",
            },
            {
                type = "text",
                text = JoinLines({
                    "The right-side preview pane changes as you hover or select settings.",
                    "",
                    "Use search and filters to find settings quickly. Filters can help narrow options by new, updated, visual, navigation, sizing, style, and integration behavior.",
                }),
            },
        },
    },
    {
        id = "commands",
        title = "Commands",
        intro = "Everyday commands worth remembering, plus diagnostics for bug reports and testing.",
        blocks = {
            {
                type = "heading",
                text = "Help, Options, and Status",
            },
            {
                type = "text",
                text = JoinLines({
                    "/awp status",
                    "- Show addon status, routing backend, key toggles, loaded integrations, and version.",
                    "",
                    "/awp options",
                    "- Open the options panel.",
                    "",
                    "/awp help",
                    "- Open this help guide.",
                    "",
                    "/awp changelog",
                    "- Open What's New.",
                    "",
                    "/awp repair",
                    "- Check and repair TomTom/Zygor settings that AWP depends on.",
                }),
            },
            {
                type = "heading",
                text = "Routing and Queues",
            },
            {
                type = "text",
                text = JoinLines({
                    "/awp routing on|off|toggle",
                    "- Enable or disable route ownership.",
                    "",
                    "/awp backend direct|zygor|mapzeroth|farstrider",
                    "- Choose the routing backend. direct means TomTom Direct.",
                    "",
                    "/awp queue",
                    "- Open the queue panel.",
                    "",
                    "/awp queue list",
                    "- List known queues.",
                    "",
                    "/awp queue use <id|index>",
                    "- Activate a queue.",
                    "",
                    "/awp queue clear [id|index]",
                    "- Clear a queue.",
                    "",
                    "/awp queue remove <id|index> <item>",
                    "- Remove one destination from a queue.",
                    "",
                    "/awp queue move <id|index> <from> <to>",
                    "- Move a destination inside a queue.",
                    "",
                    "/awp queue import",
                    "- Import supported queued waypoint data.",
                }),
            },
            {
                type = "heading",
                text = "Manual and Quest Cleanup",
            },
            {
                type = "text",
                text = JoinLines({
                    "/awp manualclear on|off|toggle",
                    "- Toggle auto-clear for manual waypoints on arrival.",
                    "",
                    "/awp cleardistance <5-100>",
                    "- Set manual waypoint arrival clear distance.",
                    "",
                    "/awp trackroute on|off|toggle",
                    "- Toggle auto-routing for newly tracked Blizzard quests.",
                    "",
                    "/awp untrackclear on|off|toggle",
                    "- Toggle clearing matching AWP quest routes and queue items when a quest is untracked.",
                    "",
                    "/awp questclear on|off|toggle",
                    "- Toggle arrival clear for supertracked quest routes.",
                    "",
                    "/awp addontakeover on|off|toggle|status",
                    "- Control waypoint adoption from unknown addon callers.",
                }),
            },
            {
                type = "heading",
                text = "Arrow and Search",
            },
            {
                type = "text",
                text = JoinLines({
                    "/awp skin <skin>",
                    "- Set the TomTom arrow skin.",
                    "",
                    "/awp scale <0.60-2.00>",
                    "- Set custom arrow skin scale.",
                    "",
                    "/awp compact on|off|toggle",
                    "- Toggle Zygor compact viewer mode.",
                    "",
                    "/awp search <service>",
                    "- Route to supported services or profession targets. Search requires Zygor search data.",
                    "",
                    "Examples:",
                    "",
                    "/awp search vendor",
                    "/awp search repair",
                    "/awp search auctioneer",
                    "/awp search mailbox",
                    "/awp search trainer alchemy",
                    "/awp search workshop blacksmithing",
                }),
            },
            {
                type = "heading",
                text = "Diagnostics",
            },
            {
                type = "text",
                text = JoinLines({
                    "/awp debug",
                    "/awp diag",
                    "/awp stepdebug",
                    "/awp waytype",
                    "/awp routedump",
                    "/awp routeenv",
                    "/awp traveldiag",
                    "/awp churn",
                    "/awp resolvercases",
                    "/awp plaque",
                    "",
                    "These are mostly for testing and bug reports.",
                    "",
                    "For most reports, /awp status, /awp waytype, and /awp stepdebug are the most useful commands.",
                }),
            },
        },
    },
    {
        id = "troubleshooting",
        title = "Troubleshooting",
        intro = "Common things to check when routing, arrows, queues, or quest text do not look right.",
        blocks = {
            {
                type = "heading",
                text = "The Arrow Is Missing",
            },
            {
                type = "text",
                text = JoinLines({
                    "Try:",
                    "",
                    "/awp status",
                    "/awp repair",
                    "/reload",
                    "",
                    "Also check that TomTom is installed and enabled.",
                }),
            },
            {
                type = "heading",
                text = "Zygor's Arrow Is Still Showing",
            },
            {
                type = "text",
                text = JoinLines({
                    "Open Zygor options:",
                    "",
                    "/zygor options",
                    "",
                    "Then go to:",
                    "",
                    "Waypoint Arrow > Enable Waypoint Arrow",
                    "",
                    "Turn it off. AWP may also offer a one-click prompt when it detects this conflict.",
                }),
            },
            {
                type = "heading",
                text = "A Guide Queue Is Visible But Not Active",
            },
            {
                type = "text",
                text = JoinLines({
                    "That can be normal.",
                    "",
                    "Guide queues can remain visible even when a manual queue, transient route, quest route, or another provider currently owns navigation.",
                    "",
                    "Activate the queue from the queue panel or use the guide addon normally to make it the active provider again.",
                    "",
                    "If none of that works try removing all TomTom waypoints `/tway reset all` or by going into the queue UI and clicking `Deactivate Queue` on the active queue.",
                    "",
                    "Sometimes a quick `/reload` will work too.",
                }),
            },
            {
                type = "heading",
                text = "Unknown Addon Waypoints Are Ignored",
            },
            {
                type = "text",
                text = JoinLines({
                    "Check:",
                    "",
                    "- General > Adopt Waypoints from Unknown Addons.",
                    "- Detected Addon Callers.",
                    "- Addon Allowlist.",
                    "- Addon Blocklist.",
                    "",
                    "Known source-aware integrations such as SilverDragon and RareScanner are handled separately from unknown addon callers.",
                }),
            },
            {
                type = "note",
                text =
                "Use the allowlist for addon callers you trust and want AWP to adopt. Use the blocklist when an addon creates TomTom waypoints that should remain outside AWP's route flow.",
            },
            {
                type = "heading",
                text = "Quest Text Or Objective Progress Looks Stale",
            },
            {
                type = "text",
                text = JoinLines({
                    "Blizzard quest data can lag behind quest updates, especially after login, tracking changes, turn-ins, or rapid quest state changes.",
                    "",
                    "Try opening the quest log, changing tracking, or waiting for the next quest update event.",
                }),
            },
        },
    },
    {
        id = "whats_new",
        title = "What's New",
        intro = "Recent highlights from the recorded changelog data.",
        blocks = {
            {
                type = "recent_changelog",
                limit = 3,
            },
        },
    },
}
