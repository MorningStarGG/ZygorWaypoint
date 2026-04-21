local NS                          = _G.ZygorWaypointNS
local M                           = NS.Internal.WorldOverlayNative

-- ============================================================
-- Internal cross-references (locals only — not exported)
-- ============================================================

local ROOT_PATH                   = "Interface\\AddOns\\ZygorWaypoint\\media\\world-overlay\\"
local ICON_PATH                   = ROOT_PATH .. "icons\\"

local DEFAULT_FOOTER_TEXT_TINT    = { r = 0.89, g = 0.89, b = 0.89, a = 1 }
local DEFAULT_TINT                = { r = 0.95, g = 0.84, b = 0.44, a = 1 }
local CORPSE_TINT                 = { r = 1, g = 1, b = 1, a = 1 }
local QUEST_REPEATABLE_TINT       = { r = 0.38, g = 0.74, b = 1, a = 1 }
local QUEST_IMPORTANT_TINT        = { r = 0.94, g = 0.55, b = 0.82, a = 1 }
local TAXI_TINT                   = { r = 0.72, g = 0.93, b = 1, a = 1 }
local INN_TINT                    = { r = 0.71, g = 0.753, b = 0.765, a = 1 }
local DELVE_TINT                  = { r = 0.435, g = 0.306, b = 0.216, a = 1 }
local DUNGEON_TINT                = { r = 0.251, g = 0.675, b = 0.812, a = 1 }
local RAID_TINT                   = { r = 0.082, g = 0.502, b = 0.133, a = 1 }
local NPC_AUCTIONEER_TINT         = { r = 0.941, g = 0.757, b = 0.278, a = 1 }
local NPC_BANKER_TINT             = { r = 0.337, g = 0.839, b = 0.396, a = 1 }
local NPC_BARBER_TINT             = { r = 0.886, g = 0.298, b = 0.231, a = 1 }
local NPC_REPAIR_TINT             = { r = 0.298, g = 0.298, b = 0.271, a = 1 }
local NPC_RIDING_TINT             = { r = 0.149, g = 0.067, b = 0.008, a = 1 }
local NPC_STABLE_TINT             = { r = 0.604, g = 0.447, b = 0.267, a = 1 }
local NPC_TRANSMOG_TINT           = { r = 0.212, g = 0.024, b = 0.29, a = 1 }
local NPC_VENDOR_TINT             = { r = 0.906, g = 0.678, b = 0.471, a = 1 }
local NPC_VOID_TINT               = { r = 0.290, g = 0.137, b = 0.518, a = 1 }
local NPC_MAILBOX_TINT            = { r = 0.792, g = 0.718, b = 0.624, a = 1 }
local SILVERDRAGON_TINT           = { r = 0.753, g = 0.753, b = 0.753, a = 1 }
local RARESCANNER_TINT            = SILVERDRAGON_TINT
local QUEST_DEFAULT_TINT          = { r = 1, g = 1, b = 0, a = 1 }
local QUEST_DAILY_TINT            = QUEST_REPEATABLE_TINT
local QUEST_WEEKLY_TINT           = QUEST_REPEATABLE_TINT
local QUEST_CAMPAIGN_TINT         = { r = 1, g = 0.6, b = 0, a = 1 }
local QUEST_QUESTLINE_TINT        = QUEST_DEFAULT_TINT
local QUEST_LEGENDARY_TINT        = { r = 1, g = 0.5, b = 0, a = 1 }
local QUEST_ARTIFACT_TINT         = DEFAULT_TINT
local QUEST_CALLING_TINT          = { r = 0.051, g = 0.647, b = 0.996, a = 1 }
local QUEST_META_TINT             = { r = 0.169, g = 0.992, b = 0.996, a = 1 }
local QUEST_RECURRING_TINT        = QUEST_REPEATABLE_TINT

-- ============================================================
-- Config
-- ============================================================

local CFG                         = {

    -- Texture paths
    WAYPOINT_BEACON_TEXTURE                       = ROOT_PATH .. "waypoint\\Beacon",
    CONTEXT_TEXTURE                             = ROOT_PATH .. "waypoint\\ContextDiamond",
    WAYPOINT_BEACON_MASK_TEXTURE                  = ROOT_PATH .. "waypoint\\BeaconMask",
    ICON_PATH                                   = ICON_PATH, -- local alias, re-exported for consumer use

    -- Texture coordinates
    WAYPOINT_BEACON_TEX_COORDS                    = {
        core = { 99 / 1024, 144 / 1024, 205 / 1024, 790 / 1024 },
        glow = { 290 / 1024, 378 / 1024, 233 / 1024, 719 / 1024 },
        leftVeil = { 450 / 1024, 520 / 1024, 232 / 1024, 749 / 900 },
        rightVeil = { 631 / 1024, 703 / 1024, 252 / 1024, 745 / 900 },
        bottomCap = { 865 / 1024, 970 / 1024, 560 / 1024, 800 / 1024 },
    },
    PINPOINT_ARROW_TEXTURE                      = ROOT_PATH .. "waypoint\\Chevron.blp",
    -- Chevron.blp is authored on a 256x256 canvas with transparent padding.
    -- Trim that padding at runtime so the stacked pinpoint arrows use the visible chevron bounds.
    PINPOINT_ARROW_TEX_COORDS                   = { 18 / 256, 239 / 256, 44 / 256, 211 / 256 },
    PINPOINT_ARROW_WIDTH                        = 18,
    PINPOINT_ARROW_HEIGHT                       = 12,
    PINPOINT_ARROW_SLOT_OVERLAP                 = 3,
    NAVIGATOR_ARROW_TEXTURE                     = ROOT_PATH .. "waypoint\\NavArrow.blp",
    -- NavArrow.blp is authored on a 128x128 canvas with the visible arrow biased to the top.
    -- Use the full square as the rotation box so the arrow can orbit around the context diamond.
    NAVIGATOR_ARROW_TEX_COORDS                  = { 0 / 128, 128 / 128, 0 / 128, 128 / 128 },
    NAVIGATOR_ARROW_WIDTH                       = 58,
    NAVIGATOR_ARROW_HEIGHT                      = 58,

    -- Behavior and timing
    BASE_SCALE_DISTANCE                         = 2000,
    BASE_SCALE                                  = 0.25,
    ARRIVAL_ALPHA                               = 0.2,
    ARRIVAL_MIN_DELTA_TIME                      = 0.05,
    ARRIVAL_MIN_SPEED                           = 0.5,
    ARRIVAL_MIN_DELTA_DISTANCE                  = 0.25,
    ARRIVAL_MAX_SECONDS                         = 86400,
    UPDATE_INTERVAL                             = 0.05,
    HOVER_FADE_ALPHA                            = 0.25,
    HOVER_FADE_RESTORE                          = 1.0,
    CONTENT_REFRESH_INTERVAL                    = 2.0,
    CLAMP_THRESHOLD                             = 0.125,
    CLAMP_THRESHOLD_EXIT                        = 0.16,
    PINPOINT_TRANSITION_DURATION                = 1.0,
    WAYPOINT_TRANSITION_INTRO_FADE_DURATION     = 1.0,
    WAYPOINT_TRANSITION_INTRO_BEACON_DELAY        = 0.175,
    WAYPOINT_TRANSITION_INTRO_BEACON_DURATION     = 0.5,
    WAYPOINT_TRANSITION_OUTRO_FADE_DURATION     = 0.25,
    WAYPOINT_TRANSITION_OUTRO_BEACON_DURATION     = 0.5,
    WAYPOINT_ICON_INTRO_SCALE                   = 2.25,
    WAYPOINT_ICON_INTRO_DURATION                = 0.5,
    WAYPOINT_BEACON_MASK_HIDDEN_SCALE             = 1,
    WAYPOINT_BEACON_MASK_SHOWN_SCALE              = 50,
    WAYPOINT_BEACON_WIDTH                         = 10,
    WAYPOINT_BEACON_HEIGHT                        = 350,
    WAYPOINT_BEACON_OFFSET_Y                      = 100,
    WAYPOINT_BEACON_MASK_SIZE                     = 50,
    WAYPOINT_BEACON_LAYOUT                        = {
        core                = { width = 10, height = 505, offsetX = 0, offsetY = -120 },
        glow                = { width = 15, height = 505, offsetX = 0, offsetY = -120 },
        
        leftVeil            = { width = 13, height = 305, offsetX = -2, offsetY = -250, wrapPad = 10 },
        rightVeil           = { width = 13, height = 305, offsetX = 2, offsetY = -250, wrapPad = 10 },

        bottomCap           = { width = 53, height = 107, offsetX = 0, offsetY = 25 },
    },
    WAYPOINT_BEACON_ALPHA_MULTIPLIERS             = {
        core = 0.35,
        glow = 0.45,
        sideVeil = 0.45,
        bottomCap = 0.75,
    },
    WAYPOINT_BEACON_GLOW_PULSE_DURATION           = 2.30,
    WAYPOINT_BEACON_GLOW_PULSE_ALPHA_MIN          = 0.35,
    WAYPOINT_BEACON_GLOW_PULSE_ALPHA_MAX          = 0.45,

    WAYPOINT_BEACON_SIDE_FLOW_DURATION            = 2.30,

    WAYPOINT_BEACON_BOTTOMCAP_CORE_PULSE_DURATION = 2.30,
    WAYPOINT_BEACON_BOTTOMCAP_CORE_ALPHA_MIN      = 0.30,
    WAYPOINT_BEACON_BOTTOMCAP_CORE_ALPHA_MAX      = 0.75,
    WAYPOINT_BEACON_BOTTOMCAP_CORE_SCALE_MIN      = 0.96,
    WAYPOINT_BEACON_BOTTOMCAP_CORE_SCALE_MAX      = 1.05,

    WAYPOINT_BEACON_BOTTOMCAP_FLAME_DURATION      = 2.30,
    WAYPOINT_BEACON_BOTTOMCAP_FLAME_ALPHA_MIN     = 0.10,
    WAYPOINT_BEACON_BOTTOMCAP_FLAME_ALPHA_MAX     = 0.58,
    WAYPOINT_BEACON_BOTTOMCAP_FLAME_SCALE_MIN     = 0.90,
    WAYPOINT_BEACON_BOTTOMCAP_FLAME_SCALE_MAX     = 1.22,
    WAYPOINT_BEACON_BOTTOMCAP_FLAME_DRIFT_X       = 0.35,
    WAYPOINT_BEACON_BOTTOMCAP_FLAME_DRIFT_Y       = 8,

    PINPOINT_TRANSITION_INTRO_FADE_DURATION     = 0.5,
    PINPOINT_TRANSITION_INTRO_MOVE_DURATION     = 1.0,
    PINPOINT_TRANSITION_OUTRO_FADE_DURATION     = 0.4,
    PINPOINT_TRANSITION_OUTRO_MOVE_DURATION     = 0.55,
    PINPOINT_ARROW_CYCLE                        = 3.75,
    -- Phase offsets for the repeating pinpoint chevron flow.
    -- Values in the 0..1 range are treated as normalized phases through the cycle.
    PINPOINT_ARROW_OFFSETS                      = { 0.0, 1 / 3, 2 / 3 },
    PINPOINT_ARROW_FADE_TIME                    = 0.5,
    PINPOINT_ARROW_SOLID_TIME                   = 1.25,
    PINPOINT_ARROW_TRAVEL                       = 15,
    PINPOINT_ARROW_EDGE_ALPHA                   = 0.20,
    PINPOINT_ARROW_GROUP_Y                      = 6,

    -- Layout and dimensions
    WAYPOINT_FOOTER_WIDTH                       = 200,
    WAYPOINT_FOOTER_HEIGHT                      = 56,
    WAYPOINT_FOOTER_TITLE_MAX_LINES             = 2,
    PINPOINT_PANEL_TEXT_PADDING_X               = 28,
    PINPOINT_TITLE_MAX_LINES                    = 2,
    PINPOINT_SUBTEXT_MAX_LINES                  = 3,
    PINPOINT_TEXT_INSET_X                       = 16,
    PINPOINT_TEXT_INSET_TOP                     = 10,
    PINPOINT_TEXT_INSET_BOTTOM                  = 10,
    PINPOINT_TEXT_GAP                           = 2,
    PINPOINT_CONTEXT_OFFSET_Y                   = -6,
    PINPOINT_FRAME_EXTRA_HEIGHT                 = 68,
    PINPOINT_HOST_CONTEXT_GAP_Y                 = 400,
    PINPOINT_HOST_CONTEXT_TAPER_START           = 0.30,
    PINPOINT_HOST_CONTEXT_TAPER_RANGE           = 0.20,
    PINPOINT_HOST_CONTEXT_TAPER_MAX_REDUCTION   = 200,
    DISPLAY_DISTANCE_EPSILON                    = 1e-4,
    WAYPOINT_CONTEXT_SIZE                       = 46,
    PINPOINT_CONTEXT_SIZE                       = 36,
    NAVIGATOR_CONTEXT_SIZE                      = 46,
    -- iconSize/iconOffsetX/iconOffsetY numbers are interpreted against this
    -- baseline and scaled per container by default so waypoint, pinpoint, and
    -- navigator keep the same relative glyph fill.
    CONTEXT_ICON_REFERENCE_SIZE                 = 46,
    CONTEXT_ICON_FILL_RATIO                     = 0.56,
    CONTEXT_ICON_ONLY_FILL_RATIO                = 0.76,
    CONTEXT_ICON_IMAGE_Y_OFFSET                 = -1,

    -- Tints (all exported for future user tint-override support)
    DEFAULT_TINT                                = DEFAULT_TINT,
    CORPSE_TINT                                 = CORPSE_TINT,
    QUEST_INCOMPLETE_TINT                       = { r = 0.1, g = 0.84, b = 0, a = 1 },
    QUEST_COMPLETE_TINT                         = { r = 0.98, g = 0.86, b = 0.29, a = 1 },
    QUEST_DEFAULT_TINT                          = QUEST_DEFAULT_TINT,
    QUEST_DAILY_TINT                            = QUEST_DAILY_TINT,
    QUEST_WEEKLY_TINT                           = QUEST_WEEKLY_TINT,
    QUEST_REPEATABLE_TINT                       = QUEST_REPEATABLE_TINT,
    QUEST_IMPORTANT_TINT                        = QUEST_IMPORTANT_TINT,
    QUEST_CAMPAIGN_TINT                         = QUEST_CAMPAIGN_TINT,
    QUEST_QUESTLINE_TINT                        = QUEST_QUESTLINE_TINT,
    QUEST_LEGENDARY_TINT                        = QUEST_LEGENDARY_TINT,
    QUEST_ARTIFACT_TINT                         = QUEST_ARTIFACT_TINT,
    QUEST_CALLING_TINT                          = QUEST_CALLING_TINT,
    QUEST_META_TINT                             = QUEST_META_TINT,
    QUEST_RECURRING_TINT                        = QUEST_RECURRING_TINT,
    TAXI_TINT                                   = TAXI_TINT,
    INN_TINT                                    = INN_TINT,
    DUNGEON_TINT                                = DUNGEON_TINT,
    RAID_TINT                                   = RAID_TINT,

    -- Icon specs.
    -- Optional per-icon footer override:
    -- waypointTextTint = { r = 1, g = 1, b = 1, a = 1 },
    -- waypointTextTintKey = "WAYPOINT_TEXT_WHITE",
    -- Optional visual placement override for atlas/textures with off-center art:
    -- iconOffsetX = 0, -- decimals allowed
    -- iconOffsetY = 0, -- decimals allowed
    -- Optional icon metric override:
    -- iconSizeMode = "absolute", -- keep iconSize in exact pixels instead of scaling by container
    -- iconOffsetMode = "absolute", -- keep offsets in exact pixels instead of scaling by container
    ICON_SPECS                                  = {
        corpse = { atlas = "poi-torghast", tint = CORPSE_TINT, key = "corpse", recolor = true, iconSize = false },
        taxi   = { atlas = "Taxi_Frame_Gray", tint = TAXI_TINT, waypointTextTint = DEFAULT_FOOTER_TEXT_TINT, key = "taxi", iconSize = 16 },
        inn    = { atlas = "Innkeeper", tint = INN_TINT, waypointTextTint = DEFAULT_FOOTER_TEXT_TINT, key = "inn", iconSize = 24 },
        dungeon = { atlas = "Dungeon", tint = DUNGEON_TINT, waypointTextTint = DEFAULT_FOOTER_TEXT_TINT, key = "dungeon", iconOffsetY = 1, iconSize = 40 },
        raid   = { atlas = "Raid", tint = RAID_TINT, waypointTextTint = DEFAULT_FOOTER_TEXT_TINT, key = "raid", iconOffsetY = 1, iconSize = 40 },
        delve  = { atlas = "delves-regular", tint = DELVE_TINT, waypointTextTint = DEFAULT_FOOTER_TEXT_TINT, key = "delve", iconOffsetY = 2, iconSize = 30 },
        hearth = { tint = DEFAULT_TINT, key = "hearth" },
        manual = { atlas = "UI-HUD-MicroMenu-StreamDLGreen-Up", tint = { r = 0.157, g = 0.286, b = 0.145, a = 1 }, waypointTextTint = DEFAULT_FOOTER_TEXT_TINT, key = "manual", iconOffsetX = -0.5, iconSize = 48 },
        silverdragon = { atlas = "worldquest-questmarker-dragon-silver", tint = SILVERDRAGON_TINT, waypointTextTint = DEFAULT_FOOTER_TEXT_TINT, key = "silverdragon", iconSize = 26 },
        rarescanner = { texture = "Interface\\AddOns\\RareScanner\\Media\\Icons\\OriginalSkull.blp", tint = RARESCANNER_TINT, waypointTextTint = DEFAULT_FOOTER_TEXT_TINT, key = "rarescanner", iconSize = 28 },
        portal = { atlas =  "MagePortalAlliance", tint = { r = 0.812, g = 0.884, b = 0.873, a = 1 }, waypointTextTint = DEFAULT_FOOTER_TEXT_TINT, key = "portal", iconOffsetY = 2, iconSize = 28 },
        travel = { atlas =   "poi-traveldirections-arrow2", tint = { r = 1, g = 1, b = 1, a = 1 }, waypointTextTint = DEFAULT_FOOTER_TEXT_TINT, key = "travel", iconOffsetY = -1, iconSize = 28 },
        guide  = { texture = "Interface\\AddOns\\ZygorGuidesViewer\\Skins\\addon-icon.tga", tint = { r = 0.996, g = 0.38, b = 0, a = 1 }, waypointTextTint = DEFAULT_FOOTER_TEXT_TINT, key = "guide", iconOffsetY = 1, iconSize = 24 },

        -- WhoWhere NPC search results
        npc_auctioneer      = { atlas = "Auctioneer", tint = NPC_AUCTIONEER_TINT, waypointTextTint = DEFAULT_FOOTER_TEXT_TINT, key = "npc_auctioneer", iconOffsetY = 0.5 },
        npc_banker          = { atlas = "Banker", tint = NPC_BANKER_TINT, waypointTextTint = DEFAULT_FOOTER_TEXT_TINT, key = "npc_banker", iconOffsetY = 2, iconSize = 24 },
        npc_barber          = { atlas = "Barbershop-32x32", tint = NPC_BARBER_TINT, waypointTextTint = DEFAULT_FOOTER_TEXT_TINT, key = "npc_barber", iconOffsetY = 1, iconSize = 22 },
        npc_flightmaster    = { atlas = "Taxi_Frame_Gray", tint = TAXI_TINT, waypointTextTint = DEFAULT_FOOTER_TEXT_TINT, key = "npc_flightmaster", iconSize = 20 },
        npc_innkeeper       = { atlas = "Innkeeper", tint = INN_TINT, waypointTextTint = DEFAULT_FOOTER_TEXT_TINT, key = "npc_innkeeper", iconSize = 24 },
        npc_mailbox         = { atlas = "Mailbox", tint = NPC_MAILBOX_TINT, waypointTextTint = DEFAULT_FOOTER_TEXT_TINT, key = "npc_mailbox", iconOffsetY = 1, iconSize = 24 },
        npc_repair          = { atlas = "Mobile-Blacksmithing", tint = NPC_REPAIR_TINT, waypointTextTint = DEFAULT_FOOTER_TEXT_TINT, key = "npc_repair", iconOffsetX = -1, iconSize = 22 },
        npc_trainer_riding  = { atlas = "shop-icon-housing-mounts-up", tint = NPC_RIDING_TINT, waypointTextTint = DEFAULT_FOOTER_TEXT_TINT, key = "npc_trainer_riding", iconOffsetY = 1 },
        npc_stable_master   = { atlas = "StableMaster", tint = NPC_STABLE_TINT, waypointTextTint = DEFAULT_FOOTER_TEXT_TINT, key = "npc_stable_master", iconOffsetY = 0.5, iconSize = 28 },
        npc_transmogrifier  = { atlas = "lootroll-toast-icon-transmog-up", tint = NPC_TRANSMOG_TINT, waypointTextTint = DEFAULT_FOOTER_TEXT_TINT, key = "npc_transmogrifier", iconOffsetY = 1, iconSize = 28 },
        npc_vendor          = { atlas = "Levelup-Icon-Bag", tint = NPC_VENDOR_TINT, waypointTextTint = DEFAULT_FOOTER_TEXT_TINT, key = "npc_vendor", iconOffsetY = 2.5, iconSize = 28 },
        npc_void_storage    = { atlas = "pvpqueue-chest-dragonflight-greatvault-collect", tint = NPC_VOID_TINT, waypointTextTint = DEFAULT_FOOTER_TEXT_TINT, key = "npc_void_storage", recolor = true, iconOffsetY = 1, iconSize = 28 },

        npc_trainer_alchemy       = { atlas = "Mobile-Alchemy", tint = { r = 0.094, g = 0.639, b = 0.549, a = 1 }, waypointTextTint = DEFAULT_FOOTER_TEXT_TINT, key = "npc_trainer_alchemy", iconOffsetY = 1, iconSize = 20 },
        npc_trainer_archaeology   = { atlas = "Mobile-Archeology", tint = { r = 0.361, g = 0.176, b = 0.035, a = 1 }, waypointTextTint = DEFAULT_FOOTER_TEXT_TINT, key = "npc_trainer_archaeology", iconOffsetY = 1, iconSize = 18 },
        npc_trainer_bandages      = { atlas = "Mobile-FirstAid", tint = { r = 0.522, g = 0.078, b = 0.063, a = 1 }, waypointTextTint = DEFAULT_FOOTER_TEXT_TINT, key = "npc_trainer_bandages", iconOffsetY = 1, iconSize = 22 },
        npc_trainer_blacksmithing = { atlas = "Mobile-Blacksmithing", tint = NPC_REPAIR_TINT, waypointTextTint = DEFAULT_FOOTER_TEXT_TINT, key = "npc_trainer_blacksmithing", iconOffsetX = -1, iconSize = 22 },
        npc_trainer_cooking       = { atlas = "Mobile-Cooking", tint = { r = 0.612, g = 0.565, b = 0.447, a = 1 }, waypointTextTint = DEFAULT_FOOTER_TEXT_TINT, key = "npc_trainer_cooking", iconOffsetY = 1, iconSize = 22 },
        npc_trainer_enchanting    = { atlas = "Crosshair_enchant_48", tint = { r = 0.42, g = 0.694, b = 0.937, a = 1 }, waypointTextTint = DEFAULT_FOOTER_TEXT_TINT, key = "npc_trainer_enchanting", iconOffsetX = -1, iconOffsetY = 2.5, iconSize = 22 },
        npc_trainer_engineering   = { atlas = "Mobile-Enginnering", tint = { r = 0.6, g = 0.42, b = 0.149, a = 1 }, waypointTextTint = DEFAULT_FOOTER_TEXT_TINT, key = "npc_trainer_engineering", iconOffsetY = 1, iconSize = 22 },
        npc_trainer_first_aid     = { atlas = "Mobile-FirstAid", tint = { r = 0.522, g = 0.078, b = 0.063, a = 1 }, waypointTextTint = DEFAULT_FOOTER_TEXT_TINT, key = "npc_trainer_first_aid", iconOffsetY = 1, iconSize = 22 },
        npc_trainer_fishing       = { atlas = "Mobile-Fishing", tint = { r = 0.439, g = 0.204, b = 0.259, a = 1 }, waypointTextTint = DEFAULT_FOOTER_TEXT_TINT, key = "npc_trainer_fishing", iconOffsetY = 2.5, iconSize = 20 },
        npc_trainer_herbalism     = { atlas = "Mobile-Herbalism", tint = { r = 0.62, g = 0.733, b = 0.212, a = 1 }, waypointTextTint = DEFAULT_FOOTER_TEXT_TINT, key = "npc_trainer_herbalism", iconOffsetY = 1, iconSize = 18 },
        npc_trainer_inscription   = { atlas = "Mobile-Inscription", tint = { r = 0.145, g = 0.557, b = 0.761, a = 1 }, waypointTextTint = DEFAULT_FOOTER_TEXT_TINT, key = "npc_trainer_inscription", iconOffsetY = 0.5, iconOffsetX = 0.5, iconSize = 30 },
        npc_trainer_jewelcrafting = { atlas = "Mobile-Jewelcrafting", tint = { r = 0.533, g = 0.478, b = 0.725, a = 1 }, waypointTextTint = DEFAULT_FOOTER_TEXT_TINT, key = "npc_trainer_jewelcrafting", iconOffsetY = 1, iconSize = 24 },
        npc_trainer_leatherworking= { atlas = "Mobile-Leatherworking", tint = { r = 0.545, g = 0.424, b = 0.345, a = 1 }, waypointTextTint = DEFAULT_FOOTER_TEXT_TINT, key = "npc_trainer_leatherworking", iconOffsetX = -1, iconOffsetY = 1, iconSize = 24 },
        npc_trainer_mining        = { atlas = "Mobile-Mining", tint = { r = 0.349, g = 0.357, b = 0.349, a = 1 }, waypointTextTint = DEFAULT_FOOTER_TEXT_TINT, key = "npc_trainer_mining", iconOffsetX = -2.5, iconOffsetY = 1.5, iconSize = 20 },
        npc_trainer_skinning      = { atlas = "professions_tracking_skin", tint = { r = 0.314, g = 0.38, b = 0.314, a = 1 }, waypointTextTint = DEFAULT_FOOTER_TEXT_TINT, key = "npc_trainer_skinning", iconOffsetY = 1.5, iconSize = 20 },
        npc_trainer_tailoring     = { atlas = "Mobile-Tailoring", tint = { r = 0.6, g = 0.549, b = 0.541, a = 1 }, waypointTextTint = DEFAULT_FOOTER_TEXT_TINT, key = "npc_trainer_tailoring", iconOffsetY = 1, iconSize = 18 },

        npc_workshop_alchemy       = { atlas = "Mobile-Alchemy", tint = { r = 0.094, g = 0.639, b = 0.549, a = 1 }, waypointTextTint = DEFAULT_FOOTER_TEXT_TINT, key = "npc_workshop_alchemy", iconOffsetY = 1, iconSize = 20 },
        npc_workshop_archaeology   = { atlas = "Mobile-Archeology", tint = { r = 0.361, g = 0.176, b = 0.035, a = 1 }, waypointTextTint = DEFAULT_FOOTER_TEXT_TINT, key = "npc_workshop_archaeology", iconOffsetY = 1, iconSize = 18 },
        npc_workshop_bandages      = { atlas = "Mobile-FirstAid", tint = { r = 0.522, g = 0.078, b = 0.063, a = 1 }, waypointTextTint = DEFAULT_FOOTER_TEXT_TINT, key = "npc_workshop_bandages", iconOffsetY = 1, iconSize = 22 },
        npc_workshop_blacksmithing = { atlas = "Mobile-Blacksmithing", tint = NPC_REPAIR_TINT, waypointTextTint = DEFAULT_FOOTER_TEXT_TINT, key = "npc_workshop_blacksmithing", iconOffsetX = -1, iconSize = 22 },
        npc_workshop_cooking       = { atlas = "Mobile-Cooking", tint = { r = 0.612, g = 0.565, b = 0.447, a = 1 }, waypointTextTint = DEFAULT_FOOTER_TEXT_TINT, key = "npc_workshop_cooking", iconOffsetY = 1, iconSize = 22 },
        npc_workshop_enchanting    = { atlas = "Crosshair_enchant_48", tint = { r = 0.42, g = 0.694, b = 0.937, a = 1 }, waypointTextTint = DEFAULT_FOOTER_TEXT_TINT, key = "npc_workshop_enchanting", iconOffsetX = -1, iconOffsetY = 2.5, iconSize = 22 },
        npc_workshop_engineering   = { atlas = "Mobile-Enginnering", tint = { r = 0.6, g = 0.42, b = 0.149, a = 1 }, waypointTextTint = DEFAULT_FOOTER_TEXT_TINT, key = "npc_workshop_engineering", iconOffsetY = 1, iconSize = 22 },
        npc_workshop_first_aid     = { atlas = "Mobile-FirstAid", tint = { r = 0.522, g = 0.078, b = 0.063, a = 1 }, waypointTextTint = DEFAULT_FOOTER_TEXT_TINT, key = "npc_workshop_first_aid", iconOffsetY = 1, iconSize = 22 },
        npc_workshop_fishing       = { atlas = "Mobile-Fishing", tint = { r = 0.439, g = 0.204, b = 0.259, a = 1 }, waypointTextTint = DEFAULT_FOOTER_TEXT_TINT, key = "npc_workshop_fishing", iconOffsetY = 2.5, iconSize = 20 },
        npc_workshop_herbalism     = { atlas = "Mobile-Herbalism", tint = { r = 0.62, g = 0.733, b = 0.212, a = 1 }, waypointTextTint = DEFAULT_FOOTER_TEXT_TINT, key = "npc_workshop_herbalism", iconOffsetY = 1, iconSize = 18 },
        npc_workshop_inscription   = { atlas = "Mobile-Inscription", tint = { r = 0.145, g = 0.557, b = 0.761, a = 1 }, waypointTextTint = DEFAULT_FOOTER_TEXT_TINT, key = "npc_workshop_inscription", iconOffsetY = 0.5, iconOffsetX = 0.5, iconSize = 30 },
        npc_workshop_jewelcrafting = { atlas = "Mobile-Jewelcrafting", tint = { r = 0.533, g = 0.478, b = 0.725, a = 1 }, waypointTextTint = DEFAULT_FOOTER_TEXT_TINT, key = "npc_workshop_jewelcrafting", iconOffsetY = 1, iconSize = 24 },
        npc_workshop_leatherworking= { atlas = "Mobile-Leatherworking", tint = { r = 0.545, g = 0.424, b = 0.345, a = 1 }, waypointTextTint = DEFAULT_FOOTER_TEXT_TINT, key = "npc_workshop_leatherworking", iconOffsetX = -1, iconOffsetY = 1, iconSize = 24 },
        npc_workshop_mining        = { atlas = "Mobile-Mining", tint = { r = 0.349, g = 0.357, b = 0.349, a = 1 }, waypointTextTint = DEFAULT_FOOTER_TEXT_TINT, key = "npc_workshop_mining", iconOffsetX = -2.5, iconOffsetY = 1.5, iconSize = 20 },
        npc_workshop_skinning      = { atlas = "professions_tracking_skin", tint = { r = 0.314, g = 0.38, b = 0.314, a = 1 }, waypointTextTint = DEFAULT_FOOTER_TEXT_TINT, key = "npc_workshop_skinning", iconOffsetY = 1.5, iconSize = 20 },
        npc_workshop_tailoring     = { atlas = "Mobile-Tailoring", tint = { r = 0.6, g = 0.549, b = 0.541, a = 1 }, waypointTextTint = DEFAULT_FOOTER_TEXT_TINT, key = "npc_workshop_tailoring", iconOffsetY = 1, iconSize = 18 },
    },

    -- Quest icon families. Add new type keys here and return the same key from
    -- ResolveQuestTypeDetails() to make both live rendering and /zwp waytype
    -- previews pick them up automatically. Families can optionally define
    -- states.Available / states.Incomplete / states.Complete to override the
    -- default suffix-generated texture for specific quest states. Families and
    -- individual states can also define waypointTextTint / waypointTextTintKey
    -- to give the waypoint footer text a different color than the icon itself.
    -- Quest families and states can also define iconOffsetX / iconOffsetY to
    -- nudge atlas art that is visually biased within its source region.
    -- iconSize/iconOffsetX/iconOffsetY are container-relative by default here
    -- too; set iconSizeMode/iconOffsetMode = "absolute" on a family or state
    -- only when exact pixels are truly required.
    QUEST_ICON_TYPE_DEFS                        = {
        Default = {
            suffix = "",
            tint = QUEST_DEFAULT_TINT,
            waypointTextTint = DEFAULT_FOOTER_TEXT_TINT,
            iconSize = 30,
            states = {
                Available = {
                    atlas = "Crosshair_Quest_128",
                    key = "AvailableQuest",
                },
                Incomplete = {
                    atlas = "Crosshair_unableQuestturnin_128",
                    key = "IncompleteQuest",
                },
                Complete = {
                    atlas = "Crosshair_Questturnin_128",
                    key = "CompleteQuest",
                },
            },
        },
        Daily = {
            suffix = "Daily",
            tint = QUEST_DAILY_TINT,
            waypointTextTint = DEFAULT_FOOTER_TEXT_TINT,
            iconSize = 28,
            iconOffsetY = 1,
            states = {
                Available = {
                    atlas =  "Crosshair_unableRecurringturnin_128",
                    key = "AvailableDailyQuest",
                },
                Incomplete = {
                    atlas = "Crosshair_unableRecurringturnin_128",
                    key = "IncompleteDailyQuest",
                },
                Complete = {
                    atlas =  "Crosshair_Recurringturnin_128",
                    key = "CompleteDailyQuest",
                },
            },
        },
        Weekly = {
            suffix = "Weekly",
            tint = QUEST_WEEKLY_TINT,
            waypointTextTint = DEFAULT_FOOTER_TEXT_TINT,
            iconSize = 28,
            iconOffsetY = 1,
            states = {
                Available = {
                    atlas =  "Crosshair_Recurring_128",
                    key = "AvailableRecurringQuest",
                },
                Incomplete = {
                    atlas =  "Crosshair_unableRecurringturnin_128",
                    key = "IncompleteRecurringQuest",
                },
                Complete = {
                    atlas = "Crosshair_Recurringturnin_128",
                    key = "CompleteRecurringQuest",
                },
            },
        },
        Important = {
            suffix = "Important",
            tint = QUEST_IMPORTANT_TINT,
            waypointTextTint = DEFAULT_FOOTER_TEXT_TINT,
            iconOffsetX = -2,
            iconOffsetY = -0.5,
            iconSize = 30,
            states = {
                Available = {
                    atlas = "Crosshair_important_128",
                    key = "AvailableImportantQuest",
                },
                Incomplete = {
                    atlas =  "Crosshair_unableimportantturnin_128",
                    key = "IncompleteImportantQuest",
                },
                Complete = {
                    atlas =  "Crosshair_importantturnin_128",
                    key = "CompleteImportantQuest",
                },
            },
        },
        Campaign = {
            suffix = "Campaign",
            tint = QUEST_CAMPAIGN_TINT,
            waypointTextTint = DEFAULT_FOOTER_TEXT_TINT,
            iconOffsetX = -3.8,
            iconOffsetY = 0.5,
            iconSize = 28,
            states = {
                Available = {
                    atlas =  "Crosshair_campaignquest_128",
                    key = "AvailableCampaignQuest",
                },
                Incomplete = {
                    atlas =  "Crosshair_unablecampaignquestturnin_128",
                    key = "IncompleteCampaignQuest",
                },
                Complete = {
                    atlas =  "Crosshair_campaignquestturnin_128",
                    key = "CompleteCampaignQuest",
                },
            },
        },
        Questline = {
            suffix = "Questline",
            tint = QUEST_QUESTLINE_TINT,
            waypointTextTint = DEFAULT_FOOTER_TEXT_TINT,
            iconSize = 30,
            states = {
                Available = {
                    atlas =  "Crosshair_Quest_128",
                    key = "AvailableQuestlineQuest",
                },
                Incomplete = {
                    atlas =  "Crosshair_unableQuestturnin_128",
                    key = "IncompleteQuestlineQuest",
                },
                Complete = {
                    atlas =  "Crosshair_Questturnin_128",
                    key = "CompleteQuestlineQuest",
                },
            },
        },
        Legendary = {
            suffix = "Legendary",
            tint = QUEST_LEGENDARY_TINT,
            waypointTextTint = DEFAULT_FOOTER_TEXT_TINT,
            iconOffsetX = -1.1,
            iconOffsetY = 1.3,
            iconSize = 30,
            states = {
                Available = {
                    atlas =  "Crosshair_legendaryquest_128",
                    key = "AvailableLegendaryQuest",
                },
                Incomplete = {
                    atlas =  "Crosshair_legendaryquest_128",
                    key = "IncompleteLegendaryQuest",
                },
                Complete = {
                    atlas =  "Crosshair_legendaryquestturnin_128",
                    key = "CompleteLegendaryQuest",
                },
            },
        },
        Artifact = {
            suffix = "Artifact",
            tint = QUEST_ARTIFACT_TINT,
            waypointTextTint = DEFAULT_FOOTER_TEXT_TINT,
            iconSize = 30,
            states = {
                Available = {
                    atlas = "Crosshair_Quest_128",
                    key = "AvailableArtifactQuest",
                },
                Incomplete = {
                    atlas = "Crosshair_unableQuestturnin_128",
                    key = "IncompleteArtifactQuest",
                },
                Complete = {
                    atlas = "Crosshair_Questturnin_128",
                    key = "CompleteArtifactQuest",
                },
            },
        },
        Calling = {
            suffix = "Calling",
            tint = QUEST_CALLING_TINT,
            waypointTextTint = DEFAULT_FOOTER_TEXT_TINT,
            states = {
                Available = {
                    atlas = "Quest-DailyCampaign-Available",
                    key = "AvailableCallingQuest",
                    iconSize = 16,
                    iconOffsetX = 0.5,
                    iconOffsetY = -1,
                },
                Incomplete = {
                    atlas = "Crosshair_unablecampaignquestturnin_128",
                    key = "IncompleteCallingQuest",
                    iconOffsetX = -3.8,
                    iconOffsetY = 0.5,
                    iconSize = 28,
                },
                Complete = {
                    atlas = "Quest-DailyCampaign-TurnIn",
                    key = "CompleteCallingQuest",
                    iconSize = 22,
                    iconOffsetX = 0.5,
                    iconOffsetY = -1.4,
                },
            },
        },
        Meta = {
            suffix = "Meta",
            tint = QUEST_META_TINT,
            waypointTextTint = DEFAULT_FOOTER_TEXT_TINT,
            iconOffsetX = -1.5,
            iconOffsetY = 2.3,
            iconSize = 28,
            states = {
                Available = {
                    atlas = "Crosshair_Wrapper_128",
                    key = "AvailableMetaQuest",
                },
                Incomplete = {
                    atlas = "Crosshair_unableWrapperturnin_128",
                    key = "IncompleteMetaQuest",
                },
                Complete = {
                    atlas = "Crosshair_Wrapperturnin_128",
                    key = "CompleteMetaQuest",
                },
            },
        },
        Recurring = {
            suffix = "Recurring",
            tint = QUEST_RECURRING_TINT,
            waypointTextTint = DEFAULT_FOOTER_TEXT_TINT,
            iconSize = 28,
            iconOffsetY = 1,
            states = {
                Available = {
                    atlas =  "Crosshair_Recurring_128",
                    key = "AvailableRecurringQuest",
                },
                Incomplete = {
                    atlas =  "Crosshair_unableRecurringturnin_128",
                    key = "IncompleteRecurringQuest",
                },
                Complete = {
                    atlas = "Crosshair_Recurringturnin_128",
                    key = "CompleteRecurringQuest",
                },
            },
        },
        Repeatable = {
            suffix = "Repeatable",
            tint = QUEST_REPEATABLE_TINT,
            waypointTextTint = DEFAULT_FOOTER_TEXT_TINT,
            iconSize = 28,
            iconOffsetY = 1,
            states = {
                Available = {
                    atlas =  "Crosshair_Recurring_128",
                    key = "AvailableRecurringQuest",
                },
                Incomplete = {
                    atlas =  "Crosshair_unableRecurringturnin_128",
                    key = "IncompleteRecurringQuest",
                },
                Complete = {
                    atlas = "Crosshair_Recurringturnin_128",
                    key = "CompleteRecurringQuest",
                },
            },
        },
    },
}

M.Config                          = CFG
