local NS = _G.ZygorWaypointNS
local C = NS.Constants
local state = NS.State
local Options = NS.Internal.Interface.options

NS.Internal.Interface.commands = NS.Internal.Interface.commands or {}

local M = NS.Internal.Interface.commands
local ApplySkinAndScale = Options.ApplySkinAndScale
local RefreshViewerChromeMode = Options.RefreshViewerChromeMode

state.commands = state.commands or {
    registered = false,
    whoWhereFallbackHooked = false,
    vendorFallbackToken = 0,
    pendingVendorFallback = nil,
}

-- ============================================================
-- String utilities
-- ============================================================

local function trim(s)
    return (s or ""):match("^%s*(.-)%s*$")
end

local function normalizeSearchText(s)
    s = trim((s or ""):lower())
    s = s:gsub("[%-%_]+", " ")
    s = s:gsub("%s+", " ")
    return s
end

-- ============================================================
-- Search data
-- ============================================================

local SEARCH_ALIASES = {
    ["ah"] = { type = "Auctioneer", label = "Auctioneer" },
    ["auction"] = { type = "Auctioneer", label = "Auctioneer" },
    ["auctioneer"] = { type = "Auctioneer", label = "Auctioneer" },
    ["auctioneers"] = { type = "Auctioneer", label = "Auctioneer" },
    ["bank"] = { type = "Banker", label = "Banker" },
    ["banker"] = { type = "Banker", label = "Banker" },
    ["bankers"] = { type = "Banker", label = "Banker" },
    ["barber"] = { type = "Barber", label = "Barber" },
    ["barbers"] = { type = "Barber", label = "Barber" },
    ["barbershop"] = { type = "Barber", label = "Barber" },
    ["flight master"] = { type = "Flightmaster", label = "Flightmaster" },
    ["flightmaster"] = { type = "Flightmaster", label = "Flightmaster" },
    ["flightmasters"] = { type = "Flightmaster", label = "Flightmaster" },
    ["inn"] = { type = "Innkeeper", label = "Innkeeper" },
    ["innkeeper"] = { type = "Innkeeper", label = "Innkeeper" },
    ["innkeepers"] = { type = "Innkeeper", label = "Innkeeper" },
    ["mail"] = { mailbox = true, label = "Mailbox" },
    ["mailbox"] = { mailbox = true, label = "Mailbox" },
    ["mailboxes"] = { mailbox = true, label = "Mailbox" },
    ["repair"] = { type = "Repair", label = "Repair" },
    ["repairs"] = { type = "Repair", label = "Repair" },
    ["repair vendor"] = { type = "Repair", label = "Repair" },
    ["riding"] = { type = "TrainerRiding", label = "Riding Trainer" },
    ["riding trainer"] = { type = "TrainerRiding", label = "Riding Trainer" },
    ["riding trainers"] = { type = "TrainerRiding", label = "Riding Trainer" },
    ["stable"] = { type = "Stable Master", label = "Stable Master" },
    ["stable master"] = { type = "Stable Master", label = "Stable Master" },
    ["stablemaster"] = { type = "Stable Master", label = "Stable Master" },
    ["stable masters"] = { type = "Stable Master", label = "Stable Master" },
    ["stables"] = { type = "Stable Master", label = "Stable Master" },
    ["mog"] = { type = "Transmogrifier", label = "Transmogrifier" },
    ["tmog"] = { type = "Transmogrifier", label = "Transmogrifier" },
    ["transmog"] = { type = "Transmogrifier", label = "Transmogrifier" },
    ["transmogs"] = { type = "Transmogrifier", label = "Transmogrifier" },
    ["transmogrifier"] = { type = "Transmogrifier", label = "Transmogrifier" },
    ["transmogrifiers"] = { type = "Transmogrifier", label = "Transmogrifier" },
    ["store"] = { type = "Vendor", label = "Vendor" },
    ["vendor"] = { type = "Vendor", label = "Vendor" },
    ["vendors"] = { type = "Vendor", label = "Vendor" },
    ["void storage"] = { type = "Void Storage", label = "Void Storage" },
    ["voidstorage"] = { type = "Void Storage", label = "Void Storage" },
    ["void"] = { type = "Void Storage", label = "Void Storage" },
}

local SEARCH_PROFESSIONS = {
    ["alchemy"] = "Alchemy",
    ["archaeology"] = "Archaeology",
    ["bandages"] = "Bandages",
    ["blacksmithing"] = "Blacksmithing",
    ["cooking"] = "Cooking",
    ["enchanting"] = "Enchanting",
    ["engineering"] = "Engineering",
    ["first aid"] = "First Aid",
    ["fishing"] = "Fishing",
    ["herbalism"] = "Herbalism",
    ["inscription"] = "Inscription",
    ["jewelcrafting"] = "Jewelcrafting",
    ["leatherworking"] = "Leatherworking",
    ["mining"] = "Mining",
    ["skinning"] = "Skinning",
    ["tailoring"] = "Tailoring",
}

local SEARCH_PROFESSION_ORDER = {
    "alchemy",
    "archaeology",
    "bandages",
    "blacksmithing",
    "cooking",
    "enchanting",
    "engineering",
    "first aid",
    "fishing",
    "herbalism",
    "inscription",
    "jewelcrafting",
    "leatherworking",
    "mining",
    "skinning",
    "tailoring",
}

local SEARCH_HELP_TOPICS = {
    ["profession trainer"] = true,
    ["profession trainers"] = true,
    ["trainer"] = true,
    ["trainers"] = true,
    ["profession workshop"] = true,
    ["profession workshops"] = true,
    ["workshop"] = true,
    ["workshops"] = true,
}

-- ============================================================
-- Search help
-- ============================================================

local function getSupportedProfessionNames()
    local Z = NS.ZGV()
    local names = {}

    for _, key in ipairs(SEARCH_PROFESSION_ORDER) do
        if key ~= "first aid" or not (Z and Z.IsRetail) then
            if key ~= "bandages" or not (Z and (Z.IsClassicMOP or Z.IsClassicTBC or Z.IsClassicWOTLK or Z.IsClassic)) then
                if key ~= "inscription" or not (Z and (Z.IsClassicTBC or Z.IsClassic)) then
                    if key ~= "jewelcrafting" or not (Z and Z.IsClassic) then
                        names[#names + 1] = key
                    end
                end
            end
        end
    end

    return names
end

local function joinKeys(keys)
    return table.concat(keys, ", ")
end

local function showSearchHelp()
    NS.Msg("Usage: /zwp search <type> | /zwp search help")
    NS.Msg("Services: vendor, auctioneer, banker, barber, innkeeper, flightmaster, mailbox, repair, riding trainer, stable master, transmogrifier, void storage")
    NS.Msg("Profession trainers: trainer <profession>")
    NS.Msg("Professions:", joinKeys(getSupportedProfessionNames()))
    NS.Msg("Profession workshops: workshop <profession>")
    NS.Msg("Examples: /zwp search vendor | /zwp search trainer alchemy | /zwp search workshop blacksmithing")
end

local function usage()
    NS.Msg("Usage: /zwp status | debug | diag | mem | stepdebug | resolvercases | plaque | waytype | options")
    NS.Msg("       /zwp help | changelog")
    NS.Msg("       /zwp skin default|starlight|stealth")
    NS.Msg("       /zwp scale <" .. string.format("%.2f", C.SCALE_MIN) .. "-" .. string.format("%.2f", C.SCALE_MAX) .. ">")
    NS.Msg("       /zwp routing on|off|toggle")
    NS.Msg("       /zwp align on|off")
    NS.Msg("       /zwp manualclear on|off|toggle")
    NS.Msg("       /zwp cleardistance <" .. tostring(C.MANUAL_CLEAR_DISTANCE_MIN) .. "-" .. tostring(C.MANUAL_CLEAR_DISTANCE_MAX) .. ">")
    NS.Msg("       /zwp trackroute on|off|toggle")
    NS.Msg("       /zwp questclear on|off|toggle")
    NS.Msg("       /zwp compact on|off|toggle")
    NS.Msg("       /zwp resolvercases [all|case_id]")
    NS.Msg("       /zwp plaque [width] | /zwp plaque short [width] | /zwp plaque wrap [width] | /zwp plaque off")
    NS.Msg("       /zwp waytype [help|off|quest <id>|<type>]")
    NS.Msg("       /zwp search <type>")
    NS.Msg("       /zwp repair")
end

-- ============================================================
-- Setting handlers
-- ============================================================

local function handleRouting(arg)
    local db = NS.GetDB()
    if arg == "on" then
        db.zygorRouting = true
        NS.Msg("Routing: enabled")
    elseif arg == "off" then
        db.zygorRouting = false
        NS.Msg("Routing: disabled")
    elseif arg == "toggle" then
        db.zygorRouting = not db.zygorRouting
        NS.Msg("Routing:", db.zygorRouting and "enabled" or "disabled")
    else
        NS.Msg("Routing:", db.zygorRouting ~= false and "enabled" or "disabled")
        NS.Msg("Usage: /zwp routing on | off | toggle")
    end
end

local function handleAlign(arg)
    local db = NS.GetDB()
    if arg == "on" then
        db.arrowAlignment = true
        NS.AlignTomTomToZygor()
        NS.HookUnifiedArrowDrag()
        NS.Msg("Alignment: enabled")
    elseif arg == "off" then
        db.arrowAlignment = false
        NS.Msg("Alignment: disabled")
    else
        NS.Msg("Usage: /zwp align on | off")
    end
end

local function handleSkin(arg)
    if arg == C.SKIN_DEFAULT or arg == C.SKIN_STARLIGHT or arg == C.SKIN_STEALTH then
        NS.SetSkinChoice(arg)
        ApplySkinAndScale()
        NS.Msg("TomTom arrow skin set to:", arg)
    else
        NS.Msg("TomTom arrow skin:", NS.GetSkinChoice(), "(use /zwp skin default|starlight|stealth)")
    end
end

local function handleScale(arg)
    local value = tonumber(arg)
    if not value then
        NS.Msg("Usage: /zwp scale <" .. string.format("%.2f", C.SCALE_MIN) .. "-" .. string.format("%.2f", C.SCALE_MAX) .. ">")
        return
    end

    local applied = NS.SetArrowScale(value)
    ApplySkinAndScale()
    NS.Msg(string.format("TomTom arrow scale set to %.2fx", applied))
end

local function handleManualClear(arg)
    local current = NS.IsManualWaypointAutoClearEnabled()
    local distance = NS.GetManualWaypointClearDistance()

    if arg == "on" then
        NS.SetManualWaypointAutoClearEnabled(true)
        NS.Msg(string.format("Manual waypoint auto-clear: enabled (%d yd)", distance))
    elseif arg == "off" then
        NS.SetManualWaypointAutoClearEnabled(false)
        NS.Msg("Manual waypoint auto-clear: disabled")
    elseif arg == "toggle" then
        local enabled = NS.SetManualWaypointAutoClearEnabled(not current)
        if enabled then
            NS.Msg(string.format("Manual waypoint auto-clear: enabled (%d yd)", distance))
        else
            NS.Msg("Manual waypoint auto-clear: disabled")
        end
    else
        NS.Msg("Manual waypoint auto-clear:", current and "enabled" or "disabled", string.format("(%d yd)", distance))
        NS.Msg("Usage: /zwp manualclear on | off | toggle")
    end
end

local function handleClearDistance(arg)
    local value = tonumber(arg)
    if not value then
        NS.Msg(string.format("Manual waypoint clear distance: %d yd", NS.GetManualWaypointClearDistance()))
        NS.Msg("Usage: /zwp cleardistance <" .. tostring(C.MANUAL_CLEAR_DISTANCE_MIN) .. "-" .. tostring(C.MANUAL_CLEAR_DISTANCE_MAX) .. ">")
        return
    end

    local applied = NS.SetManualWaypointClearDistance(value)
    NS.Msg(string.format("Manual waypoint clear distance set to %d yd", applied))
end

local function handleQuestClear(arg)
    local current = NS.IsSuperTrackedQuestAutoClearEnabled()

    if arg == "on" then
        NS.SetSuperTrackedQuestAutoClearEnabled(true)
        NS.Msg("Supertracked quest arrival clear: enabled")
    elseif arg == "off" then
        NS.SetSuperTrackedQuestAutoClearEnabled(false)
        NS.Msg("Supertracked quest arrival clear: disabled")
    elseif arg == "toggle" then
        local enabled = NS.SetSuperTrackedQuestAutoClearEnabled(not current)
        NS.Msg("Supertracked quest arrival clear:", enabled and "enabled" or "disabled")
    else
        NS.Msg("Supertracked quest arrival clear:", current and "enabled" or "disabled")
        NS.Msg("Usage: /zwp questclear on | off | toggle")
    end
end

local function handleTrackRoute(arg)
    local current = NS.IsTrackedQuestAutoRouteEnabled()

    if arg == "on" then
        NS.SetTrackedQuestAutoRouteEnabled(true)
        NS.Msg("Tracked quest auto-route: enabled")
    elseif arg == "off" then
        NS.SetTrackedQuestAutoRouteEnabled(false)
        NS.Msg("Tracked quest auto-route: disabled")
    elseif arg == "toggle" then
        local enabled = NS.SetTrackedQuestAutoRouteEnabled(not current)
        NS.Msg("Tracked quest auto-route:", enabled and "enabled" or "disabled")
    else
        NS.Msg("Tracked quest auto-route:", current and "enabled" or "disabled")
        NS.Msg("Usage: /zwp trackroute on | off | toggle")
    end
end

local function handleCompact(arg)
    local current = NS.IsGuideStepsOnlyHoverEnabled()

    if arg == "on" then
        NS.SetGuideStepsOnlyHoverEnabled(true)
        RefreshViewerChromeMode()
        NS.Msg("Guide viewer compact mode: enabled")
    elseif arg == "off" then
        NS.SetGuideStepsOnlyHoverEnabled(false)
        RefreshViewerChromeMode()
        NS.Msg("Guide viewer compact mode: disabled")
    elseif arg == "toggle" then
        local enabled = NS.SetGuideStepsOnlyHoverEnabled(not current)
        RefreshViewerChromeMode()
        NS.Msg("Guide viewer compact mode:", enabled and "enabled" or "disabled")
    else
        NS.Msg("Guide viewer compact mode:", current and "enabled" or "disabled")
        NS.Msg("Usage: /zwp compact on | off | toggle")
    end
end

-- ============================================================
-- Status and repair
-- ============================================================

local function collectRepairChanges()
    local fixed = {}

    local Z = NS.ZGV()
    if Z and Z.db and Z.db.profile then
        local p = Z.db.profile
        if p.hidearrowwithguide ~= true then
            p.hidearrowwithguide = true
            fixed[#fixed + 1] = "Zygor: hidearrowwithguide restored to true"
        end
    end

    local tomtom = _G["TomTom"]
    if tomtom and tomtom.db and tomtom.db.profile and tomtom.db.profile.arrow then
        local a = tomtom.db.profile.arrow
        if a.showtta ~= true then
            a.showtta = true
            fixed[#fixed + 1] = "TomTom: showtta restored to true"
        end
        if a.title_alpha ~= 1 then
            a.title_alpha = 1
            fixed[#fixed + 1] = "TomTom: title_alpha restored to 1"
        end
        if a.cleardistance ~= 10 then
            a.cleardistance = 10
            fixed[#fixed + 1] = "TomTom: cleardistance restored to 10"
        end
    end

    -- Clean up stale ZWP saved variable keys from previous versions
    local zwpDB = NS.GetDB()
    if zwpDB.tomtomOverride ~= nil then
        zwpDB.tomtomOverride = nil
        fixed[#fixed + 1] = "ZWP: removed stale tomtomOverride setting"
    end

    return fixed
end

function NS.RunRepair(options)
    options = options or {}
    local fixed = collectRepairChanges()

    if options.silent then
        return fixed
    end

    if #fixed == 0 then
        NS.Msg("Repair: all external addon settings are already at their defaults.")
    else
        for _, msg in ipairs(fixed) do
            NS.Msg(msg)
        end
        NS.Msg("Repair complete. Type /reload to apply.")
    end

    return fixed
end

local function handleRepair()
    NS.RunRepair()
end

local function handleStatus()
    local tomtom = _G["TomTom"]
    local Z = NS.ZGV()
    local stepTitle = Z and Z.CurrentStep and Z.CurrentStep.title
    NS.Msg(
        "Status - Zygor:", Z and "found" or "missing",
        "Step:", stepTitle or "nil",
        "TomTom:", tomtom and "found" or "missing",
        "Routing:", NS.IsRoutingEnabled() and "on" or "off",
        "Skin:", NS.GetSkinChoice(),
        "Scale:", NS.GetArrowScale(),
        "v" .. NS.VERSION
    )
    NS.Msg(
        "Manual auto-clear:",
        NS.IsManualWaypointAutoClearEnabled() and "on" or "off",
        string.format("(%d yd)", NS.GetManualWaypointClearDistance()),
        "Track route:",
        NS.IsTrackedQuestAutoRouteEnabled() and "on" or "off",
        "Supertrack arrival clear:",
        NS.IsSuperTrackedQuestAutoClearEnabled() and "on" or "off",
        "Compact viewer:",
        NS.IsGuideStepsOnlyHoverEnabled() and "on" or "off"
    )
end

M.trim = trim
M.normalizeSearchText = normalizeSearchText
M.searchAliases = SEARCH_ALIASES
M.searchProfessions = SEARCH_PROFESSIONS
M.searchProfessionOrder = SEARCH_PROFESSION_ORDER
M.searchHelpTopics = SEARCH_HELP_TOPICS
M.getSupportedProfessionNames = getSupportedProfessionNames
M.joinKeys = joinKeys
M.showSearchHelp = showSearchHelp
M.showUsage = usage
M.handleRepair = handleRepair
M.handleRouting = handleRouting
M.handleAlign = handleAlign
M.handleSkin = handleSkin
M.handleScale = handleScale
M.handleManualClear = handleManualClear
M.handleClearDistance = handleClearDistance
M.handleTrackRoute = handleTrackRoute
M.handleQuestClear = handleQuestClear
M.handleCompact = handleCompact
M.handleStatus = handleStatus
