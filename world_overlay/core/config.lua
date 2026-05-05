local NS                       = _G.AzerothWaypointNS
local M                        = NS.Internal.WorldOverlay

-- ============================================================
-- Internal cross-references (locals only — not exported)
-- ============================================================

local ROOT_PATH                = "Interface\\AddOns\\AzerothWaypoint\\media\\world-overlay\\"

-- ============================================================
-- Config
-- ============================================================

local CFG                      = {

    -- Texture paths
    WAYPOINT_BEACON_TEXTURE                       = ROOT_PATH .. "Beacon",
    CONTEXT_TEXTURE                               = ROOT_PATH .. "ContextDiamond",
    WAYPOINT_BEACON_MASK_TEXTURE                  = ROOT_PATH .. "BeaconMask",

    -- Texture coordinates
    WAYPOINT_BEACON_TEX_COORDS                    = {
        core = { 99 / 1024, 144 / 1024, 205 / 1024, 790 / 1024 },
        glow = { 290 / 1024, 378 / 1024, 233 / 1024, 719 / 1024 },
        leftVeil = { 450 / 1024, 520 / 1024, 232 / 1024, 749 / 900 },
        rightVeil = { 631 / 1024, 703 / 1024, 252 / 1024, 745 / 900 },
        bottomCap = { 865 / 1024, 970 / 1024, 560 / 1024, 800 / 1024 },
    },
    PINPOINT_ARROW_TEXTURE                        = ROOT_PATH .. "Chevron.blp",
    -- Chevron.blp is authored on a 256x256 canvas with transparent padding.
    -- Trim that padding at runtime so the stacked pinpoint arrows use the visible chevron bounds.
    PINPOINT_ARROW_TEX_COORDS                     = { 18 / 256, 239 / 256, 44 / 256, 211 / 256 },
    PINPOINT_ARROW_WIDTH                          = 18,
    PINPOINT_ARROW_HEIGHT                         = 12,
    PINPOINT_ARROW_SLOT_OVERLAP                   = 3,
    NAVIGATOR_ARROW_TEXTURE                       = ROOT_PATH .. "NavArrow.blp",
    -- NavArrow.blp is authored on a 128x128 canvas with the visible arrow biased to the top.
    -- Use the full square as the rotation box so the arrow can orbit around the context diamond.
    NAVIGATOR_ARROW_TEX_COORDS                    = { 0 / 128, 128 / 128, 0 / 128, 128 / 128 },
    NAVIGATOR_ARROW_WIDTH                         = 58,
    NAVIGATOR_ARROW_HEIGHT                        = 58,

    -- Behavior and timing
    BASE_SCALE_DISTANCE                           = 2000,
    BASE_SCALE                                    = 0.25,
    ARRIVAL_ALPHA                                 = 0.2,
    ARRIVAL_MIN_DELTA_TIME                        = 0.05,
    ARRIVAL_MIN_SPEED                             = 0.5,
    ARRIVAL_MIN_DELTA_DISTANCE                    = 0.25,
    ARRIVAL_MAX_SECONDS                           = 86400,
    UPDATE_INTERVAL                               = 0.05,
    HOVER_FADE_ALPHA                              = 0.25,
    HOVER_FADE_RESTORE                            = 1.0,
    CONTENT_REFRESH_INTERVAL                      = 2.0,
    CLAMP_THRESHOLD                               = 0.125,
    CLAMP_THRESHOLD_EXIT                          = 0.16,
    BEACON_COLUMN_FADE_DURATION                    = 0.4,
    PINPOINT_TRANSITION_DURATION                  = 1.0,
    WAYPOINT_TRANSITION_INTRO_FADE_DURATION       = 1.0,
    WAYPOINT_TRANSITION_INTRO_BEACON_DELAY        = 0.175,
    WAYPOINT_TRANSITION_INTRO_BEACON_DURATION     = 0.5,
    WAYPOINT_TRANSITION_OUTRO_FADE_DURATION       = 0.25,
    WAYPOINT_TRANSITION_OUTRO_BEACON_DURATION     = 0.5,
    WAYPOINT_ICON_INTRO_SCALE                     = 2.25,
    WAYPOINT_ICON_INTRO_DURATION                  = 0.5,
    WAYPOINT_BEACON_MASK_HIDDEN_SCALE             = 1,
    WAYPOINT_BEACON_MASK_SHOWN_SCALE              = 50,
    WAYPOINT_BEACON_WIDTH                         = 10,
    WAYPOINT_BEACON_HEIGHT                        = 350,
    WAYPOINT_BEACON_OFFSET_Y                      = 100,
    WAYPOINT_BEACON_MASK_SIZE                     = 50,
    WAYPOINT_BEACON_LAYOUT                        = {
        core      = { width = 10, height = 505, offsetX = 0, offsetY = -120 },
        glow      = { width = 15, height = 505, offsetX = 0, offsetY = -120 },

        leftVeil  = { width = 13, height = 305, offsetX = -2, offsetY = -250, wrapPad = 10 },
        rightVeil = { width = 13, height = 305, offsetX = 2, offsetY = -250, wrapPad = 10 },

        bottomCap = { width = 53, height = 107, offsetX = 0, offsetY = 25 },
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

    PINPOINT_TRANSITION_INTRO_FADE_DURATION       = 0.5,
    PINPOINT_TRANSITION_INTRO_MOVE_DURATION       = 1.0,
    PINPOINT_TRANSITION_OUTRO_FADE_DURATION       = 0.4,
    PINPOINT_TRANSITION_OUTRO_MOVE_DURATION       = 0.55,
    PINPOINT_ARROW_CYCLE                          = 3.75,
    -- Phase offsets for the repeating pinpoint chevron flow.
    -- Values in the 0..1 range are treated as normalized phases through the cycle.
    PINPOINT_ARROW_OFFSETS                        = { 0.0, 1 / 3, 2 / 3 },
    PINPOINT_ARROW_FADE_TIME                      = 0.5,
    PINPOINT_ARROW_SOLID_TIME                     = 1.25,
    PINPOINT_ARROW_TRAVEL                         = 15,
    PINPOINT_ARROW_EDGE_ALPHA                     = 0.20,
    PINPOINT_ARROW_GROUP_Y                        = 6,

    -- Layout and dimensions
    WAYPOINT_FOOTER_WIDTH                         = 200,
    WAYPOINT_FOOTER_HEIGHT                        = 56,
    WAYPOINT_FOOTER_TITLE_MAX_LINES               = 2,
    PINPOINT_PANEL_TEXT_PADDING_X                 = 28,
    PINPOINT_TITLE_MAX_LINES                      = 2,
    PINPOINT_SUBTEXT_MAX_LINES                    = 3,
    PINPOINT_TEXT_INSET_X                         = 16,
    PINPOINT_TEXT_INSET_TOP                       = 10,
    PINPOINT_TEXT_INSET_BOTTOM                    = 10,
    PINPOINT_TEXT_GAP                             = 2,
    PINPOINT_CONTEXT_OFFSET_Y                     = -6,
    PINPOINT_FRAME_EXTRA_HEIGHT                   = 68,
    PINPOINT_HOST_CONTEXT_GAP_Y                   = 400,
    PINPOINT_HOST_CONTEXT_TAPER_START             = 0.30,
    PINPOINT_HOST_CONTEXT_TAPER_RANGE             = 0.20,
    PINPOINT_HOST_CONTEXT_TAPER_MAX_REDUCTION     = 200,
    DISPLAY_DISTANCE_EPSILON                      = 1e-4,
    WAYPOINT_CONTEXT_SIZE                         = 46,
    PINPOINT_CONTEXT_SIZE                         = 36,
    NAVIGATOR_CONTEXT_SIZE                        = 46,
    -- iconSize/iconOffsetX/iconOffsetY numbers are interpreted against this
    -- baseline and scaled per container by default so waypoint, pinpoint, and
    -- navigator keep the same relative glyph fill.
    CONTEXT_ICON_REFERENCE_SIZE                   = 46,
    CONTEXT_ICON_FILL_RATIO                       = 0.56,
    CONTEXT_ICON_ONLY_FILL_RATIO                  = 0.76,
    CONTEXT_ICON_IMAGE_Y_OFFSET                   = -1,

}

M.Config                       = CFG
