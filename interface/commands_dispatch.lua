local NS = _G.ZygorWaypointNS
local state = NS.State
local M = NS.Internal.Interface.commands

local trim = M.trim
local usage = M.showUsage
local handleStatus = M.handleStatus
local handleRouting = M.handleRouting
local handleAlign = M.handleAlign
local handleSkin = M.handleSkin
local handleScale = M.handleScale
local handleManualClear = M.handleManualClear
local handleClearDistance = M.handleClearDistance
local handleCompact = M.handleCompact
local handleSearch = M.handleSearch
local handleDiag = M.handleDiag
local handleMem = M.handleMem
local handlePlaque = M.handlePlaque
local handleWaytype = M.handleWaytype
local handleTravelDiag = M.handleTravelDiag
local handleRepair = M.handleRepair
local handleStepDebug = M.handleStepDebug
local handleResolverCases = M.handleResolverCases
local handleChurn = M.handleChurn

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
    elseif cmd == "mem" or cmd == "memory" then
        handleMem()
    elseif cmd == "traveldiag" or cmd == "tdiag" then
        handleTravelDiag()
    elseif cmd == "plaque" or cmd == "pinpoint" then
        handlePlaque(rest)
    elseif cmd == "waytype" then
        handleWaytype(rest)
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
    elseif cmd == "manualclear" or cmd == "autoclear" then
        handleManualClear(rest:lower())
    elseif cmd == "cleardistance" then
        handleClearDistance(rest)
    elseif cmd == "compact" or cmd == "guidechrome" or cmd == "guidehover" then
        handleCompact(rest:lower())
    elseif cmd == "search" then
        handleSearch(rest)
    elseif cmd == "repair" then
        handleRepair()
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

    SLASH_ZYGORWAYPOINT1 = "/zwp"
    SlashCmdList.ZYGORWAYPOINT = handleCommand
end
