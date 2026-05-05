local NS = _G.AzerothWaypointNS
local state = NS.State
local M = NS.Internal.Interface.commands

local trim = M.trim
local normalizeSearchText = M.normalizeSearchText
local SEARCH_ALIASES = M.searchAliases
local SEARCH_PROFESSIONS = M.searchProfessions
local SEARCH_HELP_TOPICS = M.searchHelpTopics
local showSearchHelp = M.showSearchHelp

-- ============================================================
-- WhoWhere search hint keys
-- ============================================================

local WHOWHERE_HINT_KEYS = {
    ["Auctioneer"]                   = "npc_auctioneer",
    ["Banker"]                       = "npc_banker",
    ["Barber"]                       = "npc_barber",
    ["Flightmaster"]                 = "npc_flightmaster",
    ["Innkeeper"]                    = "npc_innkeeper",
    ["Repair"]                       = "npc_repair",
    ["TrainerRiding"]                = "npc_trainer_riding",
    ["Stable Master"]                = "npc_stable_master",
    ["Transmogrifier"]               = "npc_transmogrifier",
    ["Vendor"]                       = "npc_vendor",
    ["Void Storage"]                 = "npc_void_storage",
    ["TrainerAlchemy"]               = "npc_trainer_alchemy",
    ["TrainerArchaeology"]           = "npc_trainer_archaeology",
    ["TrainerBandages"]              = "npc_trainer_bandages",
    ["TrainerBlacksmithing"]         = "npc_trainer_blacksmithing",
    ["TrainerCooking"]               = "npc_trainer_cooking",
    ["TrainerEnchanting"]            = "npc_trainer_enchanting",
    ["TrainerEngineering"]           = "npc_trainer_engineering",
    ["TrainerFirst Aid"]             = "npc_trainer_first_aid",
    ["TrainerFishing"]               = "npc_trainer_fishing",
    ["TrainerHerbalism"]             = "npc_trainer_herbalism",
    ["TrainerInscription"]           = "npc_trainer_inscription",
    ["TrainerJewelcrafting"]         = "npc_trainer_jewelcrafting",
    ["TrainerLeatherworking"]        = "npc_trainer_leatherworking",
    ["TrainerMining"]                = "npc_trainer_mining",
    ["TrainerSkinning"]              = "npc_trainer_skinning",
    ["TrainerTailoring"]             = "npc_trainer_tailoring",
    ["TrainerAlchemyWorkshop"]       = "npc_workshop_alchemy",
    ["TrainerArchaeologyWorkshop"]   = "npc_workshop_archaeology",
    ["TrainerBandagesWorkshop"]      = "npc_workshop_bandages",
    ["TrainerBlacksmithingWorkshop"] = "npc_workshop_blacksmithing",
    ["TrainerCookingWorkshop"]       = "npc_workshop_cooking",
    ["TrainerEnchantingWorkshop"]    = "npc_workshop_enchanting",
    ["TrainerEngineeringWorkshop"]   = "npc_workshop_engineering",
    ["TrainerFirst AidWorkshop"]     = "npc_workshop_first_aid",
    ["TrainerFishingWorkshop"]       = "npc_workshop_fishing",
    ["TrainerHerbalismWorkshop"]     = "npc_workshop_herbalism",
    ["TrainerInscriptionWorkshop"]   = "npc_workshop_inscription",
    ["TrainerJewelcraftingWorkshop"] = "npc_workshop_jewelcrafting",
    ["TrainerLeatherworkingWorkshop"]= "npc_workshop_leatherworking",
    ["TrainerMiningWorkshop"]        = "npc_workshop_mining",
    ["TrainerSkinningWorkshop"]      = "npc_workshop_skinning",
    ["TrainerTailoringWorkshop"]     = "npc_workshop_tailoring",
}

-- ============================================================
-- WhoWhere hook machinery
-- ============================================================

local function SetWhoWherePendingSearchKind(WW, kind)
    if type(WW) ~= "table" then
        return
    end

    WW.awpPendingSearchKind = type(kind) == "string" and kind or nil
end

local function TagCurrentWhoWhereWaypoint(WW)
    if type(WW) ~= "table" then
        return
    end

    local currentWay = WW.CurrentWay
    local pendingKind = type(WW.awpPendingSearchKind) == "string" and WW.awpPendingSearchKind or nil
    WW.awpPendingSearchKind = nil

    if type(currentWay) ~= "table" or currentWay.type ~= "manual" or pendingKind == nil then
        return
    end

    currentWay.searchKind = pendingKind
end

local function getWhoWhere()
    local Z = NS.ZGV()
    local WW = Z and Z.WhoWhere
    if not Z or not WW then return end

    if type(WW.FindNPC) ~= "function" or type(WW.FindMailbox) ~= "function" then
        return
    end

    if not state.commands.whoWhereFallbackHooked then
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

    if type(WW.FindNPC) ~= "function"
        or type(WW.FindMailbox) ~= "function"
        or type(WW.SetWaypoint) ~= "function"
        or type(WW.PathFoundHandler) ~= "function"
    then
        return
    end

    local originalFindNPC = WW.FindNPC
    local originalPathFoundHandler = WW.PathFoundHandler
    local originalFindMailbox = WW.FindMailbox
    local originalSetWaypoint = WW.SetWaypoint

    WW.SetWaypoint = function(self, ...)
        local result = originalSetWaypoint(self, ...)
        TagCurrentWhoWhereWaypoint(self)
        return result
    end

    WW.FindMailbox = function(self, ...)
        SetWhoWherePendingSearchKind(self, "npc_mailbox")
        return originalFindMailbox(self, ...)
    end

    WW.FindNPC = function(self, typ, m, f, x, y)
        SetWhoWherePendingSearchKind(self, WHOWHERE_HINT_KEYS[typ])
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

        state.commands.vendorFallbackToken = state.commands.vendorFallbackToken + 1
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

            SetWhoWherePendingSearchKind(self, nil)
            return originalPathFoundHandler(searchState, path, ext, reason)
        end)

        if searchStarted == false then
            return triggerVendorFallback(self)
        end
    end

    state.commands.whoWhereFallbackHooked = true
end

-- ============================================================
-- Query resolution
-- ============================================================

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

-- ============================================================
-- Search handler
-- ============================================================

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
        NS.Msg("Zygor nearest-NPC search requires Zygor Guides Viewer.")
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

M.handleSearch = handleSearch
