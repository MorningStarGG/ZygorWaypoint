local NS = _G.ZygorWaypointNS
local C = NS.Constants
local state = NS.State

state.commands = state.commands or {
    registered = false,
    whoWhereFallbackHooked = false,
    vendorFallbackToken = 0,
    pendingVendorFallback = nil,
}

local function trim(s)
    return (s or ""):match("^%s*(.-)%s*$")
end

local function normalizeSearchText(s)
    s = trim((s or ""):lower())
    s = s:gsub("[%-%_]+", " ")
    s = s:gsub("%s+", " ")
    return s
end

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
    NS.Msg("Usage: /zwp status | debug | options")
    NS.Msg("       /zwp skin default|starlight|stealth")
    NS.Msg("       /zwp scale <" .. string.format("%.2f", C.SCALE_MIN) .. "-" .. string.format("%.2f", C.SCALE_MAX) .. ">")
    NS.Msg("       /zwp routing on|off|toggle")
    NS.Msg("       /zwp align on|off")
    NS.Msg("       /zwp override on|off")
    NS.Msg("       /zwp manualclear on|off|toggle")
    NS.Msg("       /zwp cleardistance <" .. tostring(C.MANUAL_CLEAR_DISTANCE_MIN) .. "-" .. tostring(C.MANUAL_CLEAR_DISTANCE_MAX) .. ">")
    NS.Msg("       /zwp compact on|off|toggle")
    NS.Msg("       /zwp search <type>")
end

local function applySkinAndScale()
    NS.ApplyTomTomScalePolicy()
    NS.HookTomTomThemeBridge()
    NS.ApplyTomTomArrowSkin()
    local db = NS.GetDB()
    if db.arrowAlignment ~= false then
        NS.AlignTomTomToZygor()
        NS.HookUnifiedArrowDrag()
    end
    if TomTom and type(TomTom.ShowHideCrazyArrow) == "function" then
        TomTom:ShowHideCrazyArrow()
    end
end

local function refreshViewerChromeMode()
    if NS.HookZygorViewerChromeMode then
        NS.HookZygorViewerChromeMode()
    end
    if NS.RefreshZygorViewerChromeMode then
        NS.RefreshZygorViewerChromeMode()
    end
end

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

local function handleOverride(arg)
    local db = NS.GetDB()
    if arg == "on" then
        db.tomtomOverride = true
        if TomTom and TomTom.db and TomTom.db.profile and TomTom.db.profile.persistence then
            TomTom.db.profile.persistence.cleardistance = 0
        end
        NS.Msg("TomTom clear-distance override: enabled")
    elseif arg == "off" then
        db.tomtomOverride = false
        NS.Msg("TomTom clear-distance override: disabled")
    else
        NS.Msg("Usage: /zwp override on | off")
    end
end

local function handleSkin(arg)
    if arg == C.SKIN_DEFAULT or arg == C.SKIN_STARLIGHT or arg == C.SKIN_STEALTH then
        NS.SetSkinChoice(arg)
        applySkinAndScale()
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
    applySkinAndScale()
    NS.Msg(string.format("TomTom arrow scale set to %.2fx", applied))
end

local function handleManualClear(arg)
    local current = NS.IsManualWaypointAutoClearEnabled and NS.IsManualWaypointAutoClearEnabled()
    local distance = NS.GetManualWaypointClearDistance and NS.GetManualWaypointClearDistance() or C.MANUAL_CLEAR_DISTANCE_DEFAULT

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
        NS.Msg(
            "Manual waypoint auto-clear:",
            current and "enabled" or "disabled",
            string.format("(%d yd)", distance)
        )
        NS.Msg("Usage: /zwp manualclear on | off | toggle")
    end
end

local function handleClearDistance(arg)
    local value = tonumber(arg)
    if not value then
        NS.Msg(string.format("Manual waypoint clear distance: %d yd", NS.GetManualWaypointClearDistance()))
        NS.Msg(
            "Usage: /zwp cleardistance <"
                .. tostring(C.MANUAL_CLEAR_DISTANCE_MIN)
                .. "-"
                .. tostring(C.MANUAL_CLEAR_DISTANCE_MAX)
                .. ">"
        )
        return
    end

    local applied = NS.SetManualWaypointClearDistance(value)
    NS.Msg(string.format("Manual waypoint clear distance set to %d yd", applied))
end

local function handleCompact(arg)
    local current = NS.IsGuideStepsOnlyHoverEnabled and NS.IsGuideStepsOnlyHoverEnabled()

    if arg == "on" then
        NS.SetGuideStepsOnlyHoverEnabled(true)
        refreshViewerChromeMode()
        NS.Msg("Guide viewer compact mode: enabled")
    elseif arg == "off" then
        NS.SetGuideStepsOnlyHoverEnabled(false)
        refreshViewerChromeMode()
        NS.Msg("Guide viewer compact mode: disabled")
    elseif arg == "toggle" then
        local enabled = NS.SetGuideStepsOnlyHoverEnabled(not current)
        refreshViewerChromeMode()
        NS.Msg("Guide viewer compact mode:", enabled and "enabled" or "disabled")
    else
        NS.Msg("Guide viewer compact mode:", current and "enabled" or "disabled")
        NS.Msg("Usage: /zwp compact on | off | toggle")
    end
end

local function handleStatus()
    local Z = NS.ZGV()
    local stepTitle = Z and Z.CurrentStep and Z.CurrentStep.title
    NS.Msg(
        "Status - Zygor:", Z and "found" or "missing",
        "Step:", stepTitle or "nil",
        "TomTom:", TomTom and "found" or "missing",
        "Routing:", NS.IsRoutingEnabled() and "on" or "off",
        "Skin:", NS.GetSkinChoice(),
        "Scale:", NS.GetArrowScale(),
        "v" .. (NS.VERSION or "?")
    )
    NS.Msg(
        "Manual auto-clear:",
        NS.IsManualWaypointAutoClearEnabled() and "on" or "off",
        string.format("(%d yd)", NS.GetManualWaypointClearDistance()),
        "Compact viewer:",
        NS.IsGuideStepsOnlyHoverEnabled() and "on" or "off"
    )
end

local function getWhoWhere()
    local Z = NS.ZGV()
    local WW = Z and Z.WhoWhere
    if not Z or not WW then return end

    if type(WW.FindNPC) ~= "function" or type(WW.FindMailbox) ~= "function" then
        return
    end

    if not state.commands.whoWhereFallbackHooked and type(NS.HookZygorWhoWhereFallbacks) == "function" then
        NS.HookZygorWhoWhereFallbacks()
    end

    if Z.startups ~= nil or not Z.NPCData or not Z.MailboxData or not WW.WorkerFrame then
        return
    end

    return Z, WW
end

local function triggerVendorFallback(WW)
    state.commands.pendingVendorFallback = nil
    NS.Msg("Vendor search did not resolve a vendor waypoint. Falling back to nearest repair.")
    return WW:FindNPC("Repair")
end

function NS.HookZygorWhoWhereFallbacks()
    if state.commands.whoWhereFallbackHooked then return end

    local Z = NS.ZGV()
    local WW = Z and Z.WhoWhere
    if not Z or not WW then return end

    if type(WW.FindNPC) ~= "function" or type(WW.PathFoundHandler) ~= "function" then
        return
    end

    local originalFindNPC = WW.FindNPC
    local originalPathFoundHandler = WW.PathFoundHandler
    WW.FindNPC = function(self, typ, m, f, x, y)
        if typ ~= "Vendor" then
            state.commands.pendingVendorFallback = nil
            return originalFindNPC(self, typ, m, f, x, y)
        end

        if not Z.db.profile.pathfinding or type(self.FindNPC_Smart) ~= "function" then
            state.commands.pendingVendorFallback = nil
            return originalFindNPC(self, typ, m, f, x, y)
        end

        self.debuglast = { typ, m, f, x, y }
        self.debugtrace = debugstack()

        state.commands.vendorFallbackToken = (state.commands.vendorFallbackToken or 0) + 1
        local token = state.commands.vendorFallbackToken
        state.commands.pendingVendorFallback = {
            token = token,
            originalWay = self.CurrentWay,
        }

        local searchStarted = self:FindNPC_Smart(typ, nil, function(searchState, path, ext, reason)
            local pending = state.commands.pendingVendorFallback
            if not pending or pending.token ~= token then
                return
            end

            if searchState == "progress" then
                return
            end

            state.commands.pendingVendorFallback = nil

            if searchState == "success" then
                return originalPathFoundHandler(searchState, path, ext, reason)
            end

            if searchState == "failure" then
                return triggerVendorFallback(self)
            end

            return originalPathFoundHandler(searchState, path, ext, reason)
        end)

        if searchStarted == false then
            return triggerVendorFallback(self)
        end
    end

    state.commands.whoWhereFallbackHooked = true
end

local function resolveProfessionSearch(query, kind)
    local patterns
    if kind == "trainer" then
        patterns = {
            "^trainer%s+(.+)$",
            "^profession trainers?%s+(.+)$",
            "^(.+)%s+trainers?$",
        }
    else
        patterns = {
            "^workshop%s+(.+)$",
            "^profession workshops?%s+(.+)$",
            "^(.+)%s+workshops?$",
        }
    end

    for _, pattern in ipairs(patterns) do
        local profession = query:match(pattern)
        if profession then
            local suffix = SEARCH_PROFESSIONS[normalizeSearchText(profession)]
            if suffix then
                if kind == "trainer" then
                    return { type = "Trainer" .. suffix, label = suffix .. " Trainer" }
                end
                return { type = "Trainer" .. suffix .. "Workshop", label = suffix .. " Workshop" }
            end
        end
    end
end

local function resolveSearchQuery(arg)
    local query = normalizeSearchText(arg)
    if query == "" or query == "help" or query == "list" or SEARCH_HELP_TOPICS[query] then
        return nil, true
    end

    local alias = SEARCH_ALIASES[query]
    if alias then
        return alias
    end

    local trainer = resolveProfessionSearch(query, "trainer")
    if trainer then
        return trainer
    end

    local workshop = resolveProfessionSearch(query, "workshop")
    if workshop then
        return workshop
    end

    return nil, false, query
end

local function handleSearch(arg)
    local target, wantsHelp, query = resolveSearchQuery(arg)
    if wantsHelp then
        showSearchHelp()
        return
    end

    if not target then
        NS.Msg("Unknown search target:", query or trim(arg))
        showSearchHelp()
        return
    end

    local _, WW = getWhoWhere()
    if not WW then
        NS.Msg("Zygor nearest-NPC search is not ready.")
        return
    end

    if (target.type == "Flightmaster" or target.type == "Innkeeper") and type(WW.LeechLibRover) == "function" then
        WW:LeechLibRover()
    end

    local result
    if target.mailbox then
        result = WW:FindMailbox()
    else
        result = WW:FindNPC(target.type)
    end

    if result == false then
        NS.Msg("No Zygor search data found for:", target.label)
        return
    end

    NS.Msg("Searching nearest:", target.label)
end

local function handleCommand(msg)
    local input = trim(msg)
    local cmd, rest = input:match("^(%S+)%s*(.-)$")
    cmd = (cmd or ""):lower()
    rest = trim(rest)

    if cmd == "" then
        NS.TickUpdate()
        usage()
        return
    end

    if cmd == "status" then
        handleStatus()
    elseif cmd == "debug" then
        local enabled = NS.ToggleDebug()
        NS.Msg("Debug:", enabled and "ON" or "OFF")
    elseif cmd == "skin" then
        handleSkin(rest:lower())
    elseif cmd == "scale" then
        handleScale(rest)
    elseif cmd == "options" then
        NS.OpenOptionsPanel()
    elseif cmd == "routing" then
        handleRouting(rest:lower())
    elseif cmd == "align" then
        handleAlign(rest:lower())
    elseif cmd == "override" then
        handleOverride(rest:lower())
    elseif cmd == "manualclear" or cmd == "autoclear" then
        handleManualClear(rest:lower())
    elseif cmd == "cleardistance" then
        handleClearDistance(rest)
    elseif cmd == "compact" or cmd == "guidechrome" or cmd == "guidehover" then
        handleCompact(rest:lower())
    elseif cmd == "search" then
        handleSearch(rest)
    else
        usage()
    end
end

function NS.RegisterCommands()
    if state.commands.registered then return end
    state.commands.registered = true

    SLASH_ZYGORWAYPOINT1 = "/zwp"
    SlashCmdList.ZYGORWAYPOINT = handleCommand
end
