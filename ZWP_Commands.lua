local NS = _G.ZygorWaypointNS
local C = NS.Constants
local state = NS.State

state.commands = state.commands or {
    registered = false,
}

local function trim(s)
    return (s or ""):match("^%s*(.-)%s*$")
end

local function usage()
    NS.Msg("Usage: /zwp status | debug | options")
    NS.Msg("       /zwp skin default|starlight")
    NS.Msg("       /zwp scale <" .. string.format("%.2f", C.SCALE_MIN) .. "-" .. string.format("%.2f", C.SCALE_MAX) .. ">")
    NS.Msg("       /zwp routing on|off|toggle")
    NS.Msg("       /zwp align on|off")
    NS.Msg("       /zwp override on|off")
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
    if arg == C.SKIN_DEFAULT or arg == C.SKIN_STARLIGHT then
        NS.SetSkinChoice(arg)
        applySkinAndScale()
        NS.Msg("TomTom arrow skin set to:", arg)
    else
        NS.Msg("TomTom arrow skin:", NS.GetSkinChoice(), "(use /zwp skin default|starlight)")
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
