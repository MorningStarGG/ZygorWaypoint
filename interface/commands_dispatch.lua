local NS = _G.AzerothWaypointNS
local state = NS.State
local M = NS.Internal.Interface.commands

local trim = M.trim
local usage = M.showUsage
local handleStatus = M.handleStatus
local handleRouting = M.handleRouting
local handleBackend = M.handleBackend
local handleSkin = M.handleSkin
local handleScale = M.handleScale
local handleManualClear = M.handleManualClear
local handleClearDistance = M.handleClearDistance
local handleTrackRoute = M.handleTrackRoute
local handleUntrackClear = M.handleUntrackClear
local handleQuestClear = M.handleQuestClear
local handleAddonTakeover = M.handleAddonTakeover
local handleCompact = M.handleCompact
local handleSearch = M.handleSearch
local handleDiag = M.handleDiag
local handleMem = M.handleMem
local handlePlaque = M.handlePlaque
local handleWaytype = M.handleWaytype
local handleRouteDump = M.handleRouteDump
local handleRouteEnvTrace = M.handleRouteEnvTrace
local handleTravelDiag = M.handleTravelDiag
local handleRepair = M.handleRepair
local handleStepDebug = M.handleStepDebug
local handleResolverCases = M.handleResolverCases
local handleChurn = M.handleChurn
local handleQueueList = M.handleQueueList
local handleQueueUse = M.handleQueueUse
local handleQueueClear = M.handleQueueClear
local handleQueueRemove = M.handleQueueRemove
local handleQueueMove = M.handleQueueMove
local handleQueuePanel = M.handleQueuePanel

local function showQueueUsage()
    NS.Msg("Usage: /awp queue [list|use <id|index>|clear [id|index]|remove <id|index> <item>|move <id|index> <from> <to>|import]")
end

local function handleQueueCommand(arg)
    local subcmd, rest = trim(arg):match("^(%S+)%s*(.-)$")
    subcmd = (subcmd or ""):lower()
    rest = trim(rest)

    if subcmd == "" or subcmd == "panel" or subcmd == "open" or subcmd == "show" then
        handleQueuePanel()
    elseif subcmd == "list" or subcmd == "ls" then
        handleQueueList()
    elseif subcmd == "use" then
        handleQueueUse(rest)
    elseif subcmd == "clear" then
        handleQueueClear(rest)
    elseif subcmd == "remove" or subcmd == "rm" then
        handleQueueRemove(rest)
    elseif subcmd == "move" then
        handleQueueMove(rest)
    elseif subcmd == "import" or subcmd == "paste" or subcmd == "ttpaste" then
        if type(NS.OpenTomTomPasteWindow) == "function" then
            NS.OpenTomTomPasteWindow()
        else
            NS.Msg("TomTom paste window unavailable.")
        end
    elseif subcmd == "help" then
        showQueueUsage()
    else
        showQueueUsage()
    end
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
        if enabled then
            NS.InstallSuperTrackDebugHooks()
        end
        NS.Msg("Debug:", enabled and "ON" or "OFF")
    elseif cmd == "diag" then
        handleDiag()
    elseif cmd == "stepdebug" then
        handleStepDebug()
    elseif cmd == "resolvercases" or cmd == "resolvercase" then
        handleResolverCases(rest)
    elseif cmd == "churn" then
        handleChurn(rest)
    elseif cmd == "churnmem" or cmd == "churnphases" then
        handleChurn((rest ~= "" and (rest .. " ") or "") .. "phases")
    elseif cmd == "mem" or cmd == "memory" then
        handleMem()
    elseif cmd == "traveldiag" or cmd == "tdiag" then
        handleTravelDiag()
    elseif cmd == "routedump" or cmd == "routecheck" then
        handleRouteDump(rest)
    elseif cmd == "routeenv" or cmd == "routenv" or cmd == "envroute" then
        handleRouteEnvTrace(rest)
    elseif cmd == "plaque" or cmd == "pinpoint" then
        handlePlaque(rest)
    elseif cmd == "waytype" then
        handleWaytype(rest)
    elseif cmd == "skin" then
        handleSkin(rest:lower())
    elseif cmd == "scale" then
        handleScale(rest)
    elseif cmd == "options" or cmd == "config" then
        NS.OpenOptionsPanel()
    elseif cmd == "routing" then
        handleRouting(rest:lower())
    elseif cmd == "backend" then
        handleBackend(rest:lower())
    elseif cmd == "manualclear" or cmd == "autoclear" then
        handleManualClear(rest:lower())
    elseif cmd == "cleardistance" then
        handleClearDistance(rest)
    elseif cmd == "trackroute" or cmd == "trackedroute" then
        handleTrackRoute(rest:lower())
    elseif cmd == "untrackclear" or cmd == "untrackedclear" then
        handleUntrackClear(rest:lower())
    elseif cmd == "questclear" or cmd == "superquestclear" then
        handleQuestClear(rest:lower())
    elseif cmd == "addontakeover" or cmd == "unknownaddons" or cmd == "addonwaypoints" then
        handleAddonTakeover(rest)
    elseif cmd == "compact" or cmd == "guidechrome" or cmd == "guidehover" then
        handleCompact(rest:lower())
    elseif cmd == "search" then
        handleSearch(rest)
    elseif cmd == "repair" then
        handleRepair()
    elseif cmd == "queue" or cmd == "queues" then
        handleQueueCommand(rest)
    elseif cmd == "help" or cmd == "tour" then
        if type(NS.ShowHelp) == "function" then
            NS.ShowHelp("overview")
        end
    elseif cmd == "changelog" or cmd == "whatsnew" or cmd == "whatnew" or cmd == "new" then
        if type(NS.ShowWhatsNew) == "function" then
            NS.ShowWhatsNew()
        elseif type(NS.ShowChangelog) == "function" then
            NS.ShowChangelog()
        end
    else
        usage()
    end
end

function NS.RegisterCommands()
    if state.commands.registered then
        return
    end
    state.commands.registered = true

    SLASH_AZEROTHWAYPOINT1 = "/awp"
    SlashCmdList.AZEROTHWAYPOINT = handleCommand
end
