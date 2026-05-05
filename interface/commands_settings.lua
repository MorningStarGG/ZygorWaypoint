local NS = _G.AzerothWaypointNS
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

local function getSkinCommandKeys()
    local keys = { C.SKIN_DEFAULT }
    if type(NS.GetRegisteredArrowSkins) == "function" then
        for _, key in ipairs(NS.GetRegisteredArrowSkins()) do
            if key ~= "tomtom_default" and key ~= C.SKIN_DEFAULT and type(NS.HasArrowSkin) == "function" and NS.HasArrowSkin(key) then
                keys[#keys + 1] = key
            end
        end
    end
    return keys
end

local function getSkinUsage()
    return "/awp skin " .. joinKeys(getSkinCommandKeys())
end

local function showSearchHelp()
    NS.Msg("Usage: /awp search <type> | /awp search help")
    NS.Msg("Services: vendor, auctioneer, banker, barber, innkeeper, flightmaster, mailbox, repair, riding trainer, stable master, transmogrifier, void storage")
    NS.Msg("Profession trainers: trainer <profession>")
    NS.Msg("Professions:", joinKeys(getSupportedProfessionNames()))
    NS.Msg("Profession workshops: workshop <profession>")
    NS.Msg("Examples: /awp search vendor | /awp search trainer alchemy | /awp search workshop blacksmithing")
end

local function usage()
    NS.Msg("Usage: /awp status | debug | diag | mem | routedump [legs] | routeenv | stepdebug | resolvercases | plaque | waytype | options")
    NS.Msg("       /awp help | changelog")
    NS.Msg("       " .. getSkinUsage())
    NS.Msg("       /awp scale <" .. string.format("%.2f", C.SCALE_MIN) .. "-" .. string.format("%.2f", C.SCALE_MAX) .. ">")
    NS.Msg("       /awp routing on|off|toggle")
    NS.Msg("       /awp backend direct|zygor|mapzeroth|farstrider")
    NS.Msg("       /awp manualclear on|off|toggle")
    NS.Msg("       /awp cleardistance <" .. tostring(C.MANUAL_CLEAR_DISTANCE_MIN) .. "-" .. tostring(C.MANUAL_CLEAR_DISTANCE_MAX) .. ">")
    NS.Msg("       /awp trackroute on|off|toggle")
    NS.Msg("       /awp untrackclear on|off|toggle")
    NS.Msg("       /awp questclear on|off|toggle")
    NS.Msg("       /awp addontakeover on|off|toggle|status")
    NS.Msg("       /awp addontakeover allowlist|blocklist add|remove|list|clear <addon>")
    NS.Msg("       /awp compact on|off|toggle")
    NS.Msg("       /awp resolvercases [all|case_id]")
    NS.Msg("       /awp routeenv on|off|dump")
    NS.Msg("       /awp churn [seconds] [phases] | /awp churnmem [seconds]")
    NS.Msg("       /awp plaque [width] | /awp plaque short [width] | /awp plaque wrap [width] | /awp plaque off")
    NS.Msg("       /awp waytype [help|off|quest <id>|<type>]")
    NS.Msg("       /awp search <type>")
    NS.Msg("       /awp queue [list|use <id|index>|clear [id|index]|remove <id|index> <item>|move <id|index> <from> <to>|import]")
    NS.Msg("       /awp repair")
end

-- ============================================================
-- Setting handlers
-- ============================================================

local function handleRouting(arg)
    local db = NS.GetDB()
    if arg == "on" then
        db.routingEnabled = true
        NS.Msg("Routing: enabled")
    elseif arg == "off" then
        db.routingEnabled = false
        NS.Msg("Routing: disabled")
    elseif arg == "toggle" then
        db.routingEnabled = db.routingEnabled == false
        NS.Msg("Routing:", db.routingEnabled and "enabled" or "disabled")
    else
        NS.Msg("Routing:", db.routingEnabled ~= false and "enabled" or "disabled")
        NS.Msg("Usage: /awp routing on | off | toggle")
    end
    if type(NS.RecomputeCarrier) == "function" then
        NS.RecomputeCarrier()
    end
end

local function IsBackendAvailable(id)
    if id == "direct" then
        return true
    end
    if id == "zygor" then
        return type(NS.RoutingBackend_Zygor) == "table" and NS.RoutingBackend_Zygor.IsAvailable()
    end
    if id == "mapzeroth" then
        return type(NS.RoutingBackend_Mapzeroth) == "table" and NS.RoutingBackend_Mapzeroth.IsAvailable()
    end
    if id == "farstrider" then
        return type(NS.RoutingBackend_Farstrider) == "table" and NS.RoutingBackend_Farstrider.IsAvailable()
    end
    return false
end

local function FormatBackendName(id)
    if id == "direct" then
        return "TomTom Direct"
    end
    if id == "zygor" then
        return "Zygor"
    end
    if id == "mapzeroth" then
        return "Mapzeroth"
    end
    if id == "farstrider" then
        return "FarstriderLib"
    end
    return tostring(id or "-")
end

local function FormatCombatHideMode(mode)
    mode = type(NS.NormalizeCombatHideMode) == "function"
        and NS.NormalizeCombatHideMode(mode)
        or tostring(mode or "")
    if mode == C.COMBAT_HIDE_MODE_TOMTOM then
        return "TomTom + Travel Button"
    end
    if mode == C.COMBAT_HIDE_MODE_OVERLAY then
        return "World Overlay"
    end
    if mode == C.COMBAT_HIDE_MODE_BOTH then
        return "Both"
    end
    return "Disabled"
end

local function FormatStartupHelpMode(mode)
    mode = type(NS.NormalizeStartupHelpMode) == "function"
        and NS.NormalizeStartupHelpMode(mode)
        or tostring(mode or "")
    if mode == C.STARTUP_HELP_MODE_CHARACTER then
        return "Per Character"
    end
    if mode == C.STARTUP_HELP_MODE_DISABLED then
        return "Disabled"
    end
    return "Account Wide"
end

local function handleBackend(arg)
    local db = NS.GetDB()
    if arg == "direct" or arg == "zygor" or arg == "mapzeroth" or arg == "farstrider" then
        if not IsBackendAvailable(arg) then
            NS.Msg("Backend unavailable:", FormatBackendName(arg))
            return
        end
        if type(NS.SetBackend) == "function" and NS.SetBackend(arg) then
            NS.Msg("Routing backend:", FormatBackendName(arg))
        end
    else
        local effective = type(NS.GetEffectiveBackendID) == "function" and NS.GetEffectiveBackendID() or "direct"
        NS.Msg("Routing backend:", FormatBackendName(db.routingBackend or "direct"), "(effective:", FormatBackendName(effective) .. ")")
        NS.Msg("Usage: /awp backend direct | zygor | mapzeroth | farstrider")
    end
end

local function handleSkin(arg)
    arg = trim((arg or ""):lower()):gsub("%s+", "_")
    local isRegisteredSkin = arg ~= "tomtom_default"
        and type(NS.HasArrowSkin) == "function"
        and NS.HasArrowSkin(arg)

    if arg == C.SKIN_DEFAULT or isRegisteredSkin then
        NS.SetSkinChoice(arg)
        ApplySkinAndScale()
        NS.Msg("TomTom arrow skin set to:", arg)
    else
        NS.Msg("TomTom arrow skin:", NS.GetSkinChoice(), "(use " .. getSkinUsage() .. ")")
    end
end

local function handleScale(arg)
    local value = tonumber(arg)
    if not value then
        NS.Msg("Usage: /awp scale <" .. string.format("%.2f", C.SCALE_MIN) .. "-" .. string.format("%.2f", C.SCALE_MAX) .. ">")
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
        NS.Msg("Usage: /awp manualclear on | off | toggle")
    end
end

local function handleClearDistance(arg)
    local value = tonumber(arg)
    if not value then
        NS.Msg(string.format("Manual waypoint clear distance: %d yd", NS.GetManualWaypointClearDistance()))
        NS.Msg("Usage: /awp cleardistance <" .. tostring(C.MANUAL_CLEAR_DISTANCE_MIN) .. "-" .. tostring(C.MANUAL_CLEAR_DISTANCE_MAX) .. ">")
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
        NS.Msg("Usage: /awp questclear on | off | toggle")
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
        NS.Msg("Usage: /awp trackroute on | off | toggle")
    end
end

local function handleUntrackClear(arg)
    local current = NS.IsUntrackedQuestAutoClearEnabled()

    if arg == "on" then
        NS.SetUntrackedQuestAutoClearEnabled(true)
        NS.Msg("Untracked quest auto-clear: enabled")
    elseif arg == "off" then
        NS.SetUntrackedQuestAutoClearEnabled(false)
        NS.Msg("Untracked quest auto-clear: disabled")
    elseif arg == "toggle" then
        local enabled = NS.SetUntrackedQuestAutoClearEnabled(not current)
        NS.Msg("Untracked quest auto-clear:", enabled and "enabled" or "disabled")
    else
        NS.Msg("Untracked quest auto-clear:", current and "enabled" or "disabled")
        NS.Msg("Usage: /awp untrackclear on | off | toggle")
    end
end

local function formatList(list)
    if type(list) ~= "table" or #list == 0 then
        return "(empty)"
    end
    return table.concat(list, ", ")
end

local function handleAddonTakeover(arg)
    local text = trim(arg or "")
    local lowered = text:lower()
    local current = type(NS.IsGenericAddonBlizzardTakeoverEnabled) == "function"
        and NS.IsGenericAddonBlizzardTakeoverEnabled()
        or false

    if lowered == "on" then
        NS.SetGenericAddonBlizzardTakeoverEnabled(true)
        NS.Msg("Unknown addon waypoint adoption: enabled")
        return
    elseif lowered == "off" then
        NS.SetGenericAddonBlizzardTakeoverEnabled(false)
        NS.Msg("Unknown addon waypoint adoption: disabled")
        return
    elseif lowered == "toggle" then
        local enabled = NS.SetGenericAddonBlizzardTakeoverEnabled(not current)
        NS.Msg("Unknown addon waypoint adoption:", enabled and "enabled" or "disabled")
        return
    elseif lowered == "" or lowered == "status" then
        NS.Msg("Unknown addon waypoint adoption:", current and "enabled" or "disabled")
        NS.Msg("Allowlist:", formatList(NS.GetGenericAddonBlizzardTakeoverList("allowlist")))
        NS.Msg("Blocklist:", formatList(NS.GetGenericAddonBlizzardTakeoverList("blocklist")))
        NS.Msg("Usage: /awp addontakeover allowlist|blocklist add|remove|list|clear <addon>")
        return
    end

    local listKind, action, addonName = text:match("^(%S+)%s+(%S+)%s*(.-)%s*$")
    listKind = listKind and listKind:lower() or nil
    action = action and action:lower() or nil

    if listKind ~= "allowlist" and listKind ~= "blocklist" then
        NS.Msg("Usage: /awp addontakeover allowlist|blocklist add|remove|list|clear <addon>")
        return
    end

    if action == "list" then
        NS.Msg((listKind == "allowlist" and "Allowlist:" or "Blocklist:"),
            formatList(NS.GetGenericAddonBlizzardTakeoverList(listKind)))
        return
    end
    if action == "clear" then
        NS.ClearGenericAddonBlizzardTakeoverList(listKind)
        NS.Msg((listKind == "allowlist" and "Allowlist" or "Blocklist") .. " cleared.")
        return
    end
    if action == "add" then
        local ok, result = NS.AddGenericAddonBlizzardTakeoverListEntry(listKind, addonName)
        if ok then
            NS.Msg((listKind == "allowlist" and "Allowed:" or "Blocked:"), result)
        else
            NS.Msg("Addon list add failed:", tostring(result))
        end
        return
    end
    if action == "remove" or action == "delete" then
        local ok, result = NS.RemoveGenericAddonBlizzardTakeoverListEntry(listKind, addonName)
        if ok then
            NS.Msg("Removed:", result)
        else
            NS.Msg("Addon list remove failed:", tostring(result))
        end
        return
    end

    NS.Msg("Usage: /awp addontakeover allowlist|blocklist add|remove|list|clear <addon>")
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
        NS.Msg("Usage: /awp compact on | off | toggle")
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

    -- Clean up stale AWP saved variable keys from previous versions
    local awpDB = NS.GetDB()
    if awpDB.tomtomOverride ~= nil then
        awpDB.tomtomOverride = nil
        fixed[#fixed + 1] = "AWP: removed stale tomtomOverride setting"
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
        "Backend:", FormatBackendName(type(NS.GetEffectiveBackendID) == "function" and NS.GetEffectiveBackendID() or "direct"),
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
        "Untrack clear:",
        NS.IsUntrackedQuestAutoClearEnabled() and "on" or "off",
        "Supertrack arrival clear:",
        NS.IsSuperTrackedQuestAutoClearEnabled() and "on" or "off",
        "Combat hide:",
        FormatCombatHideMode(type(NS.GetCombatHideMode) == "function" and NS.GetCombatHideMode() or nil),
        "Quick-start:",
        FormatStartupHelpMode(type(NS.GetStartupHelpMode) == "function" and NS.GetStartupHelpMode() or nil),
        "What's New:",
        FormatStartupHelpMode(type(NS.GetStartupWhatsNewMode) == "function" and NS.GetStartupWhatsNewMode() or nil),
        "Unknown addon waypoints:",
        NS.IsGenericAddonBlizzardTakeoverEnabled() and "on" or "off",
        "Compact viewer:",
        NS.IsGuideStepsOnlyHoverEnabled() and "on" or "off"
    )
end

local function describeQueue(queue, activeQueueID, index)
    local itemCount = type(queue) == "table" and type(queue.items) == "table" and #queue.items or 0
    local kind = type(queue) == "table" and queue.kind or "route"
    local label = type(queue) == "table" and queue.label or "Queue"
    local activeMarker = type(queue) == "table" and queue.id == activeQueueID and "*" or " "
    return string.format("%s%d. %s [%s] items=%d id=%s", activeMarker, index, tostring(label), tostring(kind), itemCount, tostring(queue and queue.id or "-"))
end

local function handleQueueList()
    local queues = type(NS.GetManualQueueList) == "function" and NS.GetManualQueueList() or {}
    local activeQueueID = type(NS.ResolveQueueToken) == "function" and NS.ResolveQueueToken(nil) or nil
    if type(NS.ShowQueuePanel) == "function" then
        NS.ShowQueuePanel()
    end
    if #queues == 0 then
        NS.Msg("Queues: none")
        return
    end
    NS.Msg("Queues:")
    for index = 1, #queues do
        NS.Msg(describeQueue(queues[index], activeQueueID, index))
    end
end

local function handleQueueUse(arg)
    if trim(arg) == "" then
        NS.Msg("Usage: /awp queue use <queue id|index>")
        return
    end
    local queueID = type(NS.ResolveQueueToken) == "function" and NS.ResolveQueueToken(arg) or nil
    if not queueID then
        NS.Msg("Usage: /awp queue use <queue id|index>")
        return
    end
    if queueID == "guide" then
        NS.Msg("Guide queue is read-only.")
        return
    end
    if type(NS.SetActiveManualQueue) == "function" and NS.SetActiveManualQueue(queueID) then
        NS.Msg("Queue active:", tostring(queueID))
        return
    end
    NS.Msg("Queue not found:", tostring(arg))
end

local function handleQueueClear(arg)
    local queueID = type(NS.ResolveQueueToken) == "function" and NS.ResolveQueueToken(arg) or nil
    if not queueID then
        NS.Msg("Usage: /awp queue clear [queue id|index]")
        return
    end
    if queueID == "guide" then
        NS.Msg("Guide queue is read-only.")
        return
    end
    if type(NS.ClearQueueByID) == "function" and NS.ClearQueueByID(queueID) then
        NS.Msg("Queue cleared:", tostring(queueID))
        return
    end
    NS.Msg("Queue not found:", tostring(arg))
end

local function handleQueueRemove(arg)
    local queueToken, itemToken = trim(arg):match("^(%S+)%s+(%S+)$")
    local queueID = type(NS.ResolveQueueToken) == "function" and NS.ResolveQueueToken(queueToken) or nil
    local itemIndex = tonumber(itemToken)
    if not queueID or not itemIndex then
        NS.Msg("Usage: /awp queue remove <queue id|index> <item index>")
        return
    end
    if type(NS.RemoveQueueItem) == "function" and NS.RemoveQueueItem(queueID, itemIndex) then
        NS.Msg("Removed queue item:", tostring(queueID), tostring(itemIndex))
        return
    end
    NS.Msg("Unable to remove queue item.")
end

local function handleQueueMove(arg)
    local queueToken, fromToken, toToken = trim(arg):match("^(%S+)%s+(%S+)%s+(%S+)$")
    local queueID = type(NS.ResolveQueueToken) == "function" and NS.ResolveQueueToken(queueToken) or nil
    local fromIndex = tonumber(fromToken)
    local toIndex = tonumber(toToken)
    if not queueID or not fromIndex or not toIndex then
        NS.Msg("Usage: /awp queue move <queue id|index> <from> <to>")
        return
    end
    if type(NS.MoveQueueItem) == "function" and NS.MoveQueueItem(queueID, fromIndex, toIndex) then
        NS.Msg("Moved queue item:", tostring(queueID), tostring(fromIndex), "->", tostring(toIndex))
        return
    end
    NS.Msg("Unable to move queue item.")
end

local function handleQueuePanel()
    if type(NS.ShowQueuePanel) == "function" then
        NS.ShowQueuePanel()
        return
    end
    NS.Msg("Queue panel unavailable.")
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
M.handleBackend = handleBackend
M.handleSkin = handleSkin
M.handleScale = handleScale
M.handleManualClear = handleManualClear
M.handleClearDistance = handleClearDistance
M.handleTrackRoute = handleTrackRoute
M.handleUntrackClear = handleUntrackClear
M.handleQuestClear = handleQuestClear
M.handleAddonTakeover = handleAddonTakeover
M.handleCompact = handleCompact
M.handleStatus = handleStatus
M.handleQueueList = handleQueueList
M.handleQueueUse = handleQueueUse
M.handleQueueClear = handleQueueClear
M.handleQueueRemove = handleQueueRemove
M.handleQueueMove = handleQueueMove
M.handleQueuePanel = handleQueuePanel
