local NS                         = _G.AzerothWaypointNS
local M                          = NS.Internal.WorldOverlay
local CFG                        = M.Config

local ROOT_PATH                  = "Interface\\AddOns\\AzerothWaypoint\\media\\world-overlay\\"
local ICON_PATH                  = ROOT_PATH .. "icons\\"

local DEFAULT_TINT               = { r = 0.95, g = 0.84, b = 0.44, a = 1 }
local CORPSE_TINT                = { r = 1, g = 1, b = 1, a = 1 }
local QUEST_REPEATABLE_TINT      = { r = 0.38, g = 0.74, b = 1, a = 1 }
local QUEST_IMPORTANT_TINT       = { r = 0.94, g = 0.55, b = 0.82, a = 1 }
local TAXI_TINT                  = { r = 0.72, g = 0.93, b = 1, a = 1 }
local INN_TINT                   = { r = 0.71, g = 0.753, b = 0.765, a = 1 }
local DELVE_TINT                 = { r = 0.435, g = 0.306, b = 0.216, a = 1 }
local DUNGEON_TINT               = { r = 0.251, g = 0.675, b = 0.812, a = 1 }
local RAID_TINT                  = { r = 0.082, g = 0.502, b = 0.133, a = 1 }
local NPC_AUCTIONEER_TINT        = { r = 0.941, g = 0.757, b = 0.278, a = 1 }
local NPC_BANKER_TINT            = { r = 0.337, g = 0.839, b = 0.396, a = 1 }
local NPC_BARBER_TINT            = { r = 0.886, g = 0.298, b = 0.231, a = 1 }
local NPC_REPAIR_TINT            = { r = 0.298, g = 0.298, b = 0.271, a = 1 }
local NPC_RIDING_TINT            = { r = 0.149, g = 0.067, b = 0.008, a = 1 }
local NPC_STABLE_TINT            = { r = 0.604, g = 0.447, b = 0.267, a = 1 }
local NPC_TRANSMOG_TINT          = { r = 0.212, g = 0.024, b = 0.29, a = 1 }
local NPC_VENDOR_TINT            = { r = 0.906, g = 0.678, b = 0.471, a = 1 }
local NPC_VOID_TINT              = { r = 0.290, g = 0.137, b = 0.518, a = 1 }
local NPC_MAILBOX_TINT           = { r = 0.792, g = 0.718, b = 0.624, a = 1 }
local SILVERDRAGON_TINT          = { r = 0.753, g = 0.753, b = 0.753, a = 1 }
local RARESCANNER_TINT           = SILVERDRAGON_TINT
local QUEST_DEFAULT_TINT         = { r = 1, g = 1, b = 0, a = 1 }
local QUEST_DAILY_TINT           = QUEST_REPEATABLE_TINT
local QUEST_WEEKLY_TINT          = QUEST_REPEATABLE_TINT
local QUEST_CAMPAIGN_TINT        = { r = 1, g = 0.6, b = 0, a = 1 }
local QUEST_BONUS_OBJECTIVE_TINT = { r = 1, g = 0.72, b = 0.22, a = 1 }
local QUEST_QUESTLINE_TINT       = QUEST_DEFAULT_TINT
local QUEST_LEGENDARY_TINT       = { r = 1, g = 0.5, b = 0, a = 1 }
local QUEST_ARTIFACT_TINT        = DEFAULT_TINT
local QUEST_CALLING_TINT         = { r = 0.051, g = 0.647, b = 0.996, a = 1 }
local QUEST_WORLD_BOSS_TINT      = { r = 0.89, g = 0.196, b = 0.176, a = 1 }
local QUEST_BATTLEPET_TINT       = { r = 0.337, g = 0.686, b = 0.922, a = 1 }
local QUEST_META_TINT            = { r = 0.169, g = 0.992, b = 0.996, a = 1 }
local QUEST_RECURRING_TINT       = QUEST_REPEATABLE_TINT
local QUEST_INCOMPLETE_TINT      = { r = 0.1, g = 0.84, b = 0, a = 1 }
local QUEST_COMPLETE_TINT        = { r = 0.98, g = 0.86, b = 0.29, a = 1 }

CFG.ICON_PATH                    = ICON_PATH

-- Tints (all exported for future user tint-override support)
CFG.DEFAULT_TINT                 = DEFAULT_TINT
CFG.CORPSE_TINT                  = CORPSE_TINT
CFG.QUEST_INCOMPLETE_TINT        = QUEST_INCOMPLETE_TINT
CFG.QUEST_COMPLETE_TINT          = QUEST_COMPLETE_TINT
CFG.QUEST_DEFAULT_TINT           = QUEST_DEFAULT_TINT
CFG.QUEST_DAILY_TINT             = QUEST_DAILY_TINT
CFG.QUEST_WEEKLY_TINT            = QUEST_WEEKLY_TINT
CFG.QUEST_REPEATABLE_TINT        = QUEST_REPEATABLE_TINT
CFG.QUEST_IMPORTANT_TINT         = QUEST_IMPORTANT_TINT
CFG.QUEST_CAMPAIGN_TINT          = QUEST_CAMPAIGN_TINT
CFG.QUEST_BONUS_OBJECTIVE_TINT   = QUEST_BONUS_OBJECTIVE_TINT
CFG.QUEST_QUESTLINE_TINT         = QUEST_QUESTLINE_TINT
CFG.QUEST_LEGENDARY_TINT         = QUEST_LEGENDARY_TINT
CFG.QUEST_ARTIFACT_TINT          = QUEST_ARTIFACT_TINT
CFG.QUEST_CALLING_TINT           = QUEST_CALLING_TINT
CFG.QUEST_WORLD_BOSS_TINT        = QUEST_WORLD_BOSS_TINT
CFG.QUEST_META_TINT              = QUEST_META_TINT
CFG.QUEST_RECURRING_TINT         = QUEST_RECURRING_TINT
CFG.TAXI_TINT                    = TAXI_TINT
CFG.INN_TINT                     = INN_TINT
CFG.DUNGEON_TINT                 = DUNGEON_TINT
CFG.RAID_TINT                    = RAID_TINT

-- Icon specs.
--
-- The table key is the icon identity used by resolvers and diagnostics. A
-- matching spec.key is filled in automatically after this table, so only set
-- key manually when the rendered/cached identity must intentionally differ.
--
-- Source fields:
-- atlas      = Blizzard atlas name used with Texture:SetAtlas.
-- texture    = full texture path used with Texture:SetTexture.
-- texCoords  = { left, right, top, bottom } for cropped texture sheets.
--
-- Color fields:
-- tint               = automatic semantic color for diamond/beacon/arrow/icon.
-- recolor = true     = desaturate the glyph and apply tint to the icon art.
-- waypointTextTint   only applies when the waypoint text color mode is Auto.
-- waypointTextTint   = nil uses the icon tint.
-- waypointTextTint   = "gray" or another color preset key uses that preset.
-- waypointTextTint   = { r = ..., g = ..., b = ..., a = ... } uses that color.
-- waypointTextTintKey is optional diagnostic/cache metadata for explicit colors.
--
-- Sizing and placement:
-- iconSize      = number overrides glyph size inside the context diamond.
-- iconSize      = false disables the normal glyph size override.
-- iconOffsetX/Y = pixel offsets for visually off-center source art.
-- iconSizeMode / iconOffsetMode = "absolute" keeps values exact instead of
-- scaling them with the context diamond size.
CFG.ICON_SPECS                   = {
    corpse                      = { atlas = "poi-torghast", tint = CORPSE_TINT, recolor = true, iconSize = false },
    taxi                        = { atlas = "Taxi_Frame_Gray", tint = TAXI_TINT, iconSize = 16 },
    inn                         = { atlas = "Innkeeper", tint = INN_TINT, iconSize = 24 },
    dungeon                     = { atlas = "Dungeon", tint = DUNGEON_TINT, iconOffsetY = 1, iconSize = 40 },
    raid                        = { atlas = "Raid", tint = RAID_TINT, iconOffsetY = 1, iconSize = 40 },
    delve                       = { atlas = "delves-regular", tint = DELVE_TINT, iconOffsetY = 2, iconSize = 30 },
    bountiful_delve             = { atlas = "delves-bountiful", tint = DELVE_TINT, iconOffsetY = 1, iconSize = 28 },
    hearth                      = { tint = DEFAULT_TINT },
    manual                      = { atlas = "UI-HUD-MicroMenu-StreamDLGreen-Up", tint = { r = 0.157, g = 0.286, b = 0.145, a = 1 }, iconOffsetX = -0.5, iconSize = 48 },
    area_poi                    = { atlas = "UI-EventPoi-Horn-big", tint = { r = 0.576, g = 0.325, b = 0.753, a = 1 }, iconOffsetY = 1, iconSize = 42 },
    vignette                    = { atlas = "VignetteKill", tint = { r = 0.89, g = 0.196, b = 0.176, a = 1 }, iconSize = 32 },
    dig_site                    = { atlas = "Mobile-Archeology", tint = { r = 0.361, g = 0.176, b = 0.035, a = 1 }, iconSize = 24 },
    housing_plot_own            = { atlas = "housing-map-plot-player-house", tint = { r = 1.0, g = 1.0, b = 1.0, a = 1 }, iconOffsetY = 1, iconSize = 24 },
    housing_plot_occupied       = { atlas = "housing-map-plot-occupied", tint = { r = 1.0, g = 1.0, b = 1.0, a = 1 }, iconOffsetY = 1, iconSize = 20 },
    housing_plot_unoccupied     = { atlas = "housing-map-plot-unoccupied", tint = { r = 0.6, g = 0.6, b = 0.6, a = 1 }, iconOffsetY = 1.5, iconSize = 20 },
    gossip_poi                  = { atlas = "crosshair_directions_48", tint = { r = 0.961, g = 0.769, b = 0.408, a = 1 }, iconOffsetX = -1, iconOffsetY = 0.5, iconSize = 22 },
    zygor_poi                   = { atlas = "VignetteKill", tint = { r = 0.89, g = 0.196, b = 0.176, a = 1 }, iconOffsetY = -0.5, iconSize = 36 },
    zygor_poi_rare              = { atlas = "VignetteKillElite", tint = { r = 0.89, g = 0.196, b = 0.176, a = 1 }, iconOffsetY = -1, iconSize = 24 },
    zygor_poi_treasure          = { atlas = "VignetteLoot", tint = { r = 0.247, g = 0.039, b = 0.439, a = 1 }, iconSize = 26 },
    zygor_poi_battlepet         = { atlas = "WildBattlePetCapturable", tint = { r = 0.337, g = 0.686, b = 0.922, a = 1 }, iconOffsetY = 1, iconSize = 22 },
    zygor_poi_achievement       = { atlas = "VignetteEvent", tint = { r = 0.761, g = 0.557, b = 0.941, a = 1 }, iconSize = 32 },
    zygor_poi_questobjective    = { atlas = "VignetteEvent", tint = { r = 0.941, g = 0.878, b = 0.275, a = 1 }, iconSize = 32 },
    silverdragon                = { atlas = "worldquest-questmarker-dragon-silver", tint = SILVERDRAGON_TINT, iconSize = 26 },
    rarescanner                 = { texture = "Interface\\AddOns\\RareScanner\\Media\\Icons\\OriginalSkull.blp", tint = RARESCANNER_TINT, iconSize = 28 },
    portal                      = { atlas = "MagePortalAlliance", tint = { r = 0.812, g = 0.884, b = 0.873, a = 1 }, iconOffsetY = 2, iconSize = 28 },
    travel                      = { atlas = "poi-traveldirections-arrow2", tint = { r = 1, g = 1, b = 1, a = 1 }, iconOffsetY = -1, iconSize = 28 },
    guide                       = { atlas = "LevelUp-Icon-Book", tint = DEFAULT_TINT, iconOffsetY = 1, iconSize = 24 },
    zygor_guide                 = { texture = "Interface\\AddOns\\ZygorGuidesViewer\\Skins\\addon-icon.tga", tint = { r = 0.996, g = 0.38, b = 0, a = 1 }, iconOffsetY = 1, iconSize = 24 },

    -- WhoWhere NPC search results
    npc_auctioneer              = { atlas = "Auctioneer", tint = NPC_AUCTIONEER_TINT, iconOffsetY = 0.5 },
    npc_banker                  = { atlas = "Banker", tint = NPC_BANKER_TINT, iconOffsetY = 2, iconSize = 24 },
    npc_barber                  = { atlas = "Barbershop-32x32", tint = NPC_BARBER_TINT, iconOffsetY = 1, iconSize = 22 },
    npc_flightmaster            = { atlas = "Taxi_Frame_Gray", tint = TAXI_TINT, iconSize = 20 },
    npc_innkeeper               = { atlas = "Innkeeper", tint = INN_TINT, iconSize = 24 },
    npc_mailbox                 = { atlas = "Mailbox", tint = NPC_MAILBOX_TINT, iconOffsetY = 1, iconSize = 24 },
    npc_repair                  = { atlas = "Mobile-Blacksmithing", tint = NPC_REPAIR_TINT, iconOffsetX = -1, iconSize = 22 },
    npc_trainer_riding          = { atlas = "shop-icon-housing-mounts-up", tint = NPC_RIDING_TINT, iconOffsetY = 1 },
    npc_stable_master           = { atlas = "StableMaster", tint = NPC_STABLE_TINT, iconOffsetY = 0.5, iconSize = 28 },
    npc_transmogrifier          = { atlas = "lootroll-toast-icon-transmog-up", tint = NPC_TRANSMOG_TINT, iconOffsetY = 1, iconSize = 28 },
    npc_vendor                  = { atlas = "Levelup-Icon-Bag", tint = NPC_VENDOR_TINT, iconOffsetY = 2.5, iconSize = 28 },
    npc_void_storage            = { atlas = "pvpqueue-chest-dragonflight-greatvault-collect", tint = NPC_VOID_TINT, recolor = true, iconOffsetY = 1, iconSize = 28 },

    npc_trainer_alchemy         = { atlas = "Mobile-Alchemy", tint = { r = 0.094, g = 0.639, b = 0.549, a = 1 }, iconOffsetY = 1, iconSize = 20 },
    npc_trainer_archaeology     = { atlas = "Mobile-Archeology", tint = { r = 0.361, g = 0.176, b = 0.035, a = 1 }, iconOffsetY = 1, iconSize = 18 },
    npc_trainer_bandages        = { atlas = "Mobile-FirstAid", tint = { r = 0.522, g = 0.078, b = 0.063, a = 1 }, iconOffsetY = 1, iconSize = 22 },
    npc_trainer_blacksmithing   = { atlas = "Mobile-Blacksmithing", tint = NPC_REPAIR_TINT, iconOffsetX = -1, iconSize = 22 },
    npc_trainer_cooking         = { atlas = "Mobile-Cooking", tint = { r = 0.612, g = 0.565, b = 0.447, a = 1 }, iconOffsetY = 1, iconSize = 22 },
    npc_trainer_enchanting      = { atlas = "Crosshair_enchant_48", tint = { r = 0.42, g = 0.694, b = 0.937, a = 1 }, iconOffsetX = -1, iconOffsetY = 2.5, iconSize = 22 },
    npc_trainer_engineering     = { atlas = "Mobile-Enginnering", tint = { r = 0.6, g = 0.42, b = 0.149, a = 1 }, iconOffsetY = 1, iconSize = 22 },
    npc_trainer_first_aid       = { atlas = "Mobile-FirstAid", tint = { r = 0.522, g = 0.078, b = 0.063, a = 1 }, iconOffsetY = 1, iconSize = 22 },
    npc_trainer_fishing         = { atlas = "Mobile-Fishing", tint = { r = 0.439, g = 0.204, b = 0.259, a = 1 }, iconOffsetY = 2.5, iconSize = 20 },
    npc_trainer_herbalism       = { atlas = "Mobile-Herbalism", tint = { r = 0.62, g = 0.733, b = 0.212, a = 1 }, iconOffsetY = 1, iconSize = 18 },
    npc_trainer_inscription     = { atlas = "Mobile-Inscription", tint = { r = 0.145, g = 0.557, b = 0.761, a = 1 }, iconOffsetY = 0.5, iconOffsetX = 0.5, iconSize = 30 },
    npc_trainer_jewelcrafting   = { atlas = "Mobile-Jewelcrafting", tint = { r = 0.533, g = 0.478, b = 0.725, a = 1 }, iconOffsetY = 1, iconSize = 24 },
    npc_trainer_leatherworking  = { atlas = "Mobile-Leatherworking", tint = { r = 0.545, g = 0.424, b = 0.345, a = 1 }, iconOffsetX = -1, iconOffsetY = 1, iconSize = 24 },
    npc_trainer_mining          = { atlas = "Mobile-Mining", tint = { r = 0.349, g = 0.357, b = 0.349, a = 1 }, iconOffsetX = -2.5, iconOffsetY = 1.5, iconSize = 20 },
    npc_trainer_skinning        = { atlas = "professions_tracking_skin", tint = { r = 0.314, g = 0.38, b = 0.314, a = 1 }, iconOffsetY = 1.5, iconSize = 20 },
    npc_trainer_tailoring       = { atlas = "Mobile-Tailoring", tint = { r = 0.6, g = 0.549, b = 0.541, a = 1 }, iconOffsetY = 1, iconSize = 18 },

    npc_workshop_alchemy        = { atlas = "Mobile-Alchemy", tint = { r = 0.094, g = 0.639, b = 0.549, a = 1 }, iconOffsetY = 1, iconSize = 20 },
    npc_workshop_archaeology    = { atlas = "Mobile-Archeology", tint = { r = 0.361, g = 0.176, b = 0.035, a = 1 }, iconOffsetY = 1, iconSize = 18 },
    npc_workshop_bandages       = { atlas = "Mobile-FirstAid", tint = { r = 0.522, g = 0.078, b = 0.063, a = 1 }, iconOffsetY = 1, iconSize = 22 },
    npc_workshop_blacksmithing  = { atlas = "Mobile-Blacksmithing", tint = NPC_REPAIR_TINT, iconOffsetX = -1, iconSize = 22 },
    npc_workshop_cooking        = { atlas = "Mobile-Cooking", tint = { r = 0.612, g = 0.565, b = 0.447, a = 1 }, iconOffsetY = 1, iconSize = 22 },
    npc_workshop_enchanting     = { atlas = "Crosshair_enchant_48", tint = { r = 0.42, g = 0.694, b = 0.937, a = 1 }, iconOffsetX = -1, iconOffsetY = 2.5, iconSize = 22 },
    npc_workshop_engineering    = { atlas = "Mobile-Enginnering", tint = { r = 0.6, g = 0.42, b = 0.149, a = 1 }, iconOffsetY = 1, iconSize = 22 },
    npc_workshop_first_aid      = { atlas = "Mobile-FirstAid", tint = { r = 0.522, g = 0.078, b = 0.063, a = 1 }, iconOffsetY = 1, iconSize = 22 },
    npc_workshop_fishing        = { atlas = "Mobile-Fishing", tint = { r = 0.439, g = 0.204, b = 0.259, a = 1 }, iconOffsetY = 2.5, iconSize = 20 },
    npc_workshop_herbalism      = { atlas = "Mobile-Herbalism", tint = { r = 0.62, g = 0.733, b = 0.212, a = 1 }, iconOffsetY = 1, iconSize = 18 },
    npc_workshop_inscription    = { atlas = "Mobile-Inscription", tint = { r = 0.145, g = 0.557, b = 0.761, a = 1 }, iconOffsetY = 0.5, iconOffsetX = 0.5, iconSize = 30 },
    npc_workshop_jewelcrafting  = { atlas = "Mobile-Jewelcrafting", tint = { r = 0.533, g = 0.478, b = 0.725, a = 1 }, iconOffsetY = 1, iconSize = 24 },
    npc_workshop_leatherworking = { atlas = "Mobile-Leatherworking", tint = { r = 0.545, g = 0.424, b = 0.345, a = 1 }, iconOffsetX = -1, iconOffsetY = 1, iconSize = 24 },
    npc_workshop_mining         = { atlas = "Mobile-Mining", tint = { r = 0.349, g = 0.357, b = 0.349, a = 1 }, iconOffsetX = -2.5, iconOffsetY = 1.5, iconSize = 20 },
    npc_workshop_skinning       = { atlas = "professions_tracking_skin", tint = { r = 0.314, g = 0.38, b = 0.314, a = 1 }, iconOffsetY = 1.5, iconSize = 20 },
    npc_workshop_tailoring      = { atlas = "Mobile-Tailoring", tint = { r = 0.6, g = 0.549, b = 0.541, a = 1 }, iconOffsetY = 1, iconSize = 18 },
}

for key, spec in pairs(CFG.ICON_SPECS) do
    if type(spec) == "table" and spec.key == nil then
        spec.key = key
    end
end

CFG.AREA_POI_ICON_OVERRIDES      = {
    defaultSize = 22,
    -- Override rows accept the same placement/color fields as ICON_SPECS.
    -- byAtlas is the usual path for Blizzard POI atlases; byID is for known
    -- map pin IDs; byTextureIndex covers POI texture-sheet entries.
    byAtlas = {
        ["ui-eventpoi-shippingandhandling"] = { iconSize = 34, iconOffsetY = 0 },
        ["worldquest-Capstone-questmarker-epic-Locked"] = { iconSize = 26, iconOffsetY = 0 },
        ["lorewalking-map-icon"] = { tint = { r = 0.612, g = 0.486, b = 0.278, a = 1 }, iconSize = 32, iconOffsetY = 1.5 },
        ["trading-post-minimap-icon"] = { iconSize = 30, iconOffsetY = 0.5 },
        ["ui-eventpoi-majorattacks"] = { iconSize = 32, iconOffsetY = 1 },
        ["TaxiNode_Continent_Neutral"] = { iconSize = 38, iconOffsetY = 1 },
        ["Ritual-Sites-Map-Icon"] = { iconSize = 34, iconOffsetY = 1, iconOffsetX = -0.5 },
        ["UI-EventPoi-PreyCrystal"] = { iconSize = 40, iconOffsetY = 1 },
        ["TaxiNode_Continent_Alliance"] = { iconSize = 38, iconOffsetY = 1 },
        ["poi-door-down"] = { iconSize = 24, iconOffsetY = 3 },
        ["map-icon_bullletinboard-default-minimap"] = { iconOffsetY = 1 },
        ["housing-map-deed"] = { iconSize = 28, iconOffsetY = 0.5 },
        ["UI-EventPoi-TheatreTroupe"] = { iconSize = 50, iconOffsetY = 0.5, iconOffsetX = -1.5 },
        ["UI-EventPoi-horrificvision"] = { iconSize = 38 },
    },
    byID = {
    },
    byTextureIndex = {
        defaultSize = 18,
    },
}

CFG.VIGNETTE_ICON_OVERRIDES      = {
    defaultSize = 22,
    byAtlas = {
        ["Quartermaster"] = { iconSize = 24, iconOffsetY = 2.5 },
    },
}


-- Gossip/guard direction icon families. The selected gossip option text is
-- normalized at runtime and matched against either exact optionNames or
-- wildcard optionPatterns. optionPatterns supports * and ? on normalized
-- option text, so "* Auction House" matches "Trade District Auction House"
-- and "Dwarven District Auction House". The table key becomes the stable
-- gossip type key that shows up in /awp waytype as
-- contentSnapshot.iconHintKind. If a selected option is not defined here,
-- the takeover derives a gossip_<normalized_name> key automatically and
-- renders it with the configured fallback presentation until you add a
-- definition. GOSSIP_ICON_DEFAULTS applies shared presentation overrides to
-- every gossip icon after base icon resolution; each type can then override
-- those same fields again locally.
CFG.GOSSIP_ICON_FALLBACK_KEY = "gossip_poi"

CFG.GOSSIP_ICON_DEFAULTS = {
    -- atlas = "crosshair_directions_48",
    -- iconSize = 24,
    -- iconOffsetY = 2.5,
}

CFG.GOSSIP_ICON_TYPE_DEFS = {
    gossip_auction_house = {
        iconKey = "npc_auctioneer",
        optionPatterns = {
            "* Auction House",
        },
        -- iconSize = 24,
        -- iconOffsetY = 2.5,
    },
    gossip_bank = {
        iconKey = "npc_banker",
        optionNames = {
            "* Bank",
        },
    },
    gossip_barber = {
        iconKey = "npc_barber",
        optionNames = {
            "* Barber",
        },
    },
    gossip_battle_pet_trainer = {
        iconKey = "zygor_poi_battlepet",
        optionNames = {
            "* Battle Pet Trainer",
        },
    },
    gossip_flight_master = {
        iconKey = "npc_flightmaster",
        optionNames = {
            "* Flight Master",
        },
    },
    gossip_inn = {
        iconKey = "npc_innkeeper",
        optionNames = {
            "* Inn",
        },
    },
    gossip_mailbox = {
        iconKey = "npc_mailbox",
        optionNames = {
            "* Mailbox",
        },
    },
    gossip_stable_master = {
        iconKey = "npc_stable_master",
        optionNames = {
            "* Stable Master",
        },
    },
    gossip_transmogrification = {
        iconKey = "npc_transmogrifier",
        optionNames = {
            "* Transmogrification",
        },
    },
    gossip_vendor = {
        iconKey = "npc_vendor",
        optionNames = {
            "* Vendor",
        },
    },
    gossip_alchemy = {
        iconKey = "npc_trainer_alchemy",
        optionNames = {
            "* Alchemy",
        },
    },
    gossip_archaeology = {
        iconKey = "npc_trainer_archaeology",
        optionNames = {
            "* Archeology",
        },
    },
    gossip_bandages = {
        iconKey = "npc_trainer_bandages",
        optionNames = {
            "* Bandages",
        },
    },
    gossip_blacksmithing = {
        iconKey = "npc_trainer_blacksmithing",
        optionNames = {
            "* Blacksmithing",
        },
    },
    gossip_cooking = {
        iconKey = "npc_trainer_cooking",
        optionNames = {
            "* Cooking",
        },
    },
    gossip_enchanting = {
        iconKey = "npc_trainer_enchanting",
        optionNames = {
            "* Enchanting",
        },
    },
    gossip_engineering = {
        iconKey = "npc_trainer_engineering",
        optionNames = {
            "* Enginnering",
        },
    },
    gossip_first_aid = {
        iconKey = "npc_trainer_first_aid",
        optionNames = {
            "* FirstAid",
        },
    },
    gossip_fishing = {
        iconKey = "npc_trainer_fishing",
        optionNames = {
            "* Fishing",
        },
    },
    gossip_herbalism = {
        iconKey = "npc_trainer_herbalism",
        optionNames = {
            "* Herbalism",
        },
    },
    gossip_inscription = {
        iconKey = "npc_trainer_inscription",
        optionNames = {
            "* Inscription",
        },
    },
    gossip_jewelcrafting = {
        iconKey = "npc_trainer_jewelcrafting",
        optionNames = {
            "* Jewelcrafting",
        },
    },
    gossip_leatherworking = {
        iconKey = "npc_trainer_leatherworking",
        optionNames = {
            "* Leatherworking",
        },
    },
    gossip_mining = {
        iconKey = "npc_trainer_mining",
        optionNames = {
            "* Mining",
        },
    },
    gossip_skinning = {
        iconKey = "npc_trainer_skinning",
        optionNames = {
            "* Skinning",
        },
    },
    gossip_tailoring = {
        iconKey = "npc_trainer_tailoring",
        optionNames = {
            "* Tailoring",
        },
    },
    gossip_riding = {
        iconKey = "npc_trainer_riding",
        optionNames = {
            "* Riding Trainer *",
        },
    },
    gossip_trading_post = {
        tint = NPC_AUCTIONEER_TINT,
        optionNames = {
            "* Trading Post",
        },
        atlas = "trading-post-minimap-icon",
        iconSize = 30,
        iconOffsetY = 0.5,
    },
    gossip_lorewalking = {
        tint = { r = 0.612, g = 0.486, b = 0.278, a = 1 },
        optionNames = {
            "Lorewalker Cho",
        },
        atlas = "lorewalking-map-icon",
        iconSize = 32,
        iconOffsetY = 1.5,
    },
    gossip_training_dummies = {
        tint = { r = 0.659, g = 0.663, b = 0.678, a = 1 },
        optionNames = {
            "Training Dummies",
        },
        atlas = "Mobile-MechanicIcon-Powerful",
        iconSize = 16,
        iconOffsetY = 0.5,
        iconOffsetX = 0.5,
    },
    gossip_demon_hunter = {
        tint = { r = 0.639, g = 0.188, b = 0.788, a = 1 },
        optionNames = {
            "* Demon Hunter Trainer",
        },
        atlas = "talents-heroclass-demonhunter-felscarred",
        iconSize = 24,
        iconOffsetY = 0.5,
        iconOffsetX = 0.5,
    },
    gossip_druid = {
        tint = { r = 1, g = 0.486, b = 0.039, a = 1 },
        optionNames = {
            "* Druid Trainer",
        },
        atlas = "talents-heroclass-druid-keeperofthegrove",
        iconSize = 24,
        iconOffsetY = 0.5,
        iconOffsetX = 0.5,
    },
    gossip_hunter = {
        tint = { r = 0.667, g = 0.827, b = 0.447, a = 1 },
        optionNames = {
            "* Hunter Trainer",
        },
        atlas = "talents-heroclass-hunter-darkranger",
        iconSize = 24,
        iconOffsetY = 0.5,
        iconOffsetX = 0.5,
    },
    gossip_monk = {
        tint = { r = 0, g = 1, b = 0.596, a = 1 },
        optionNames = {
            "* Monk Trainer",
        },
        atlas = "talents-heroclass-monk-shadopan",
        iconSize = 24,
        iconOffsetY = 0.5,
        iconOffsetX = 0.5,
    },
    gossip_mage = {
        tint = { r = 0.247, g = 0.78, b = 0.922, a = 1 },
        optionNames = {
            "* Mage Trainer",
        },
        atlas = "talents-heroclass-mage-frostfire",
        iconSize = 24,
        iconOffsetY = 0.5,
        iconOffsetX = 0.5,
    },
    gossip_paladin = {
        tint = { r = 0.957, g = 0.549, b = 0.729, a = 1 },
        optionNames = {
            "* Paladin Trainer",
        },
        atlas = "talents-heroclass-paladin-heraldofthesun",
        iconSize = 24,
        iconOffsetY = 0.5,
        iconOffsetX = 0.5,
    },
    gossip_priest = {
        tint = { r = 1, g = 1, b = 1, a = 1 },
        optionNames = {
            "* Priest Trainer",
        },
        atlas = "talents-heroclass-priest-oracle",
        iconSize = 24,
        iconOffsetY = 0.5,
        iconOffsetX = 0.5,
    },
    gossip_rogue = {
        tint = { r = 1, g = 0.957, b = 0.408, a = 1 },
        optionNames = {
            "* Rogue Trainer",
        },
        atlas = "talents-heroclass-rogue-deathstalker",
        iconSize = 24,
        iconOffsetY = 0.5,
        iconOffsetX = 0.5,
    },
    gossip_shaman = {
        tint = { r = 0, g = 0.439, b = 0.867, a = 1 },
        optionNames = {
            "* Shaman Trainer",
        },
        atlas = "talents-heroclass-shaman-totemic",
        iconSize = 24,
        iconOffsetY = 0.5,
        iconOffsetX = 0.5,
    },
    gossip_warlock = {
        tint = { r = 0.529, g = 0.533, b = 0.933, a = 1 },
        optionNames = {
            "* Warlock Trainer",
        },
        atlas = "talents-heroclass-warlock-diabolist",
        iconSize = 24,
        iconOffsetY = 0.5,
        iconOffsetX = 0.5,
    },
    gossip_warrior = {
        tint = { r = 0.776, g = 0.608, b = 0.427, a = 1 },
        optionNames = {
            "* Warrior Trainer",
        },
        atlas = "talents-heroclass-warrior-colossus",
        iconSize = 24,
        iconOffsetY = 0.5,
        iconOffsetX = 0.5,
    },

}


-- Quest icon families. Add new type keys here and return the same key from
-- ResolveQuestTypeDetails() to make both live rendering and /awp waytype
-- previews pick them up automatically. Families can optionally define
-- states.Available / states.Incomplete / states.Complete to override the
-- default suffix-generated texture for specific quest states. Families and
-- individual states can override waypoint footer text when the user-selected
-- waypoint text color mode is Auto. Set waypointTextTint to a color preset key
-- such as "gray", or provide a color table plus optional waypointTextTintKey.
-- State key values name the quest icon asset/cache identity; unlike
-- ICON_SPECS table keys, they are intentionally explicit.
-- Quest families and states can also define iconOffsetX / iconOffsetY to
-- nudge atlas art that is visually biased within its source region.
-- iconSize/iconOffsetX/iconOffsetY are container-relative by default here
-- too; set iconSizeMode/iconOffsetMode = "absolute" on a family or state
-- only when exact pixels are truly required.
CFG.QUEST_ICON_TYPE_DEFS = {
    Default = {
        suffix = "",
        tint = QUEST_DEFAULT_TINT,
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
        iconSize = 28,
        iconOffsetY = 1,
        states = {
            Available = {
                atlas = "Crosshair_unableRecurringturnin_128",
                key = "AvailableDailyQuest",
            },
            Incomplete = {
                atlas = "Crosshair_unableRecurringturnin_128",
                key = "IncompleteDailyQuest",
            },
            Complete = {
                atlas = "Crosshair_Recurringturnin_128",
                key = "CompleteDailyQuest",
            },
        },
    },
    Weekly = {
        suffix = "Weekly",
        tint = QUEST_WEEKLY_TINT,
        iconSize = 28,
        iconOffsetY = 1,
        states = {
            Available = {
                atlas = "Crosshair_Recurring_128",
                key = "AvailableRecurringQuest",
            },
            Incomplete = {
                atlas = "Crosshair_unableRecurringturnin_128",
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
        iconOffsetX = -2,
        iconOffsetY = -1,
        iconSize = 30,
        states = {
            Available = {
                atlas = "Crosshair_important_128",
                key = "AvailableImportantQuest",
            },
            Incomplete = {
                atlas = "Crosshair_unableimportantturnin_128",
                key = "IncompleteImportantQuest",
            },
            Complete = {
                atlas = "Crosshair_importantturnin_128",
                key = "CompleteImportantQuest",
            },
        },
    },
    Campaign = {
        suffix = "Campaign",
        tint = QUEST_CAMPAIGN_TINT,
        iconOffsetX = -3.8,
        iconOffsetY = 0.5,
        iconSize = 28,
        states = {
            Available = {
                atlas = "Crosshair_campaignquest_128",
                key = "AvailableCampaignQuest",
            },
            Incomplete = {
                atlas = "Crosshair_unablecampaignquestturnin_128",
                key = "IncompleteCampaignQuest",
            },
            Complete = {
                atlas = "Crosshair_campaignquestturnin_128",
                key = "CompleteCampaignQuest",
            },
        },
    },
    BonusObjective = {
        suffix = "BonusObjective",
        tint = QUEST_BONUS_OBJECTIVE_TINT,
        iconSize = 36,
        iconOffsetY = -0.5,
        states = {
            Available = {
                atlas = "QuestBonusObjective",
                key = "AvailableBonusObjectiveQuest",
            },
            Incomplete = {
                atlas = "Bonus-Objective-Star",
                key = "IncompleteBonusObjectiveQuest",
                iconSize = 22,
                iconOffsetY = 1.5,
                iconOffsetX = -0.5,
            },
            Complete = {
                atlas = "questbonusobjective-SuperTracked",
                key = "CompleteBonusObjectiveQuest",
            },
        },
    },
    Questline = {
        suffix = "Questline",
        tint = QUEST_QUESTLINE_TINT,
        iconSize = 30,
        states = {
            Available = {
                atlas = "Crosshair_Quest_128",
                key = "AvailableQuestlineQuest",
            },
            Incomplete = {
                atlas = "Crosshair_unableQuestturnin_128",
                key = "IncompleteQuestlineQuest",
            },
            Complete = {
                atlas = "Crosshair_Questturnin_128",
                key = "CompleteQuestlineQuest",
            },
        },
    },
    Legendary = {
        suffix = "Legendary",
        tint = QUEST_LEGENDARY_TINT,
        iconOffsetX = -1.1,
        iconOffsetY = 1.3,
        iconSize = 30,
        states = {
            Available = {
                atlas = "Crosshair_legendaryquest_128",
                key = "AvailableLegendaryQuest",
            },
            Incomplete = {
                atlas = "Crosshair_legendaryquest_128",
                key = "IncompleteLegendaryQuest",
            },
            Complete = {
                atlas = "Crosshair_legendaryquestturnin_128",
                key = "CompleteLegendaryQuest",
            },
        },
    },
    Artifact = {
        suffix = "Artifact",
        tint = QUEST_ARTIFACT_TINT,
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
    WorldQuest = {
        suffix = "WorldQuest",
        tint = QUEST_DEFAULT_TINT,
        iconSize = 36,
        iconOffsetY = -0.5,
        states = {
            Available = {
                atlas = "VignetteKill",
                key = "AvailableWorldQuest",
            },
            Incomplete = {
                atlas = "Worldquest-icon",
                key = "IncompleteWorldQuest",
                iconSize = 32,
                iconOffsetY = 1,
            },
            Complete = {
                atlas = "VignetteEvent-SuperTracked",
                key = "CompleteWorldQuest",
            },
        },
    },
    WorldBoss = {
        suffix = "WorldBoss",
        tint = QUEST_WORLD_BOSS_TINT,
        iconSize = 26,
        states = {
            Available = {
                atlas = "worldquest-icon-boss",
                key = "AvailableWorldBossQuest",
            },
            Incomplete = {
                atlas = "worldquest-icon-boss",
                key = "IncompleteWorldBossQuest",
            },
            Complete = {
                atlas = "worldquest-icon-boss",
                key = "CompleteWorldBossQuest",
            },
        },
    },
    Racing = {
        suffix = "Racing",
        tint = QUEST_DEFAULT_TINT,
        iconSize = 24,
        iconOffsetY = 1.5,
        iconOffsetX = 1.5,
        states = {
            Available = {
                atlas = "racing",
                key = "AvailableRacingQuest",
            },
            Incomplete = {
                atlas = "racing",
                key = "IncompleteRacingQuest",
            },
            Complete = {
                atlas = "racing",
                key = "CompleteRacingQuest",
            },
        },
    },
    BattlePet = {
        suffix = "BattlePet",
        tint = QUEST_BATTLEPET_TINT,
        iconOffsetY = 1,
        iconSize = 22,
        states = {
            Available = {
                atlas = "WildBattlePetCapturable",
                key = "AvailableBattlePetQuest",
            },
            Incomplete = {
                atlas = "WildBattlePetCapturable",
                key = "IncompleteBattlePetQuest",
            },
            Complete = {
                atlas = "WildBattlePetCapturable",
                key = "CompleteBattlePetQuest",
            },
        },
    },
    Meta = {
        suffix = "Meta",
        tint = QUEST_META_TINT,
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
        iconSize = 28,
        iconOffsetY = 1,
        states = {
            Available = {
                atlas = "Crosshair_Recurring_128",
                key = "AvailableRecurringQuest",
            },
            Incomplete = {
                atlas = "Crosshair_unableRecurringturnin_128",
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
        iconSize = 28,
        iconOffsetY = 1,
        states = {
            Available = {
                atlas = "Crosshair_Recurring_128",
                key = "AvailableRecurringQuest",
            },
            Incomplete = {
                atlas = "Crosshair_unableRecurringturnin_128",
                key = "IncompleteRecurringQuest",
            },
            Complete = {
                atlas = "Crosshair_Recurringturnin_128",
                key = "CompleteRecurringQuest",
            },
        },
    },
}
