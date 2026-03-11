local NS = _G.ZygorWaypointNS

NS.Constants = NS.Constants or {}
NS.State = NS.State or {}
NS.Runtime = NS.Runtime or {}

local C = NS.Constants
C.SKIN_DEFAULT = "default"
C.SKIN_STARLIGHT = "starlight"
C.SKIN_STEALTH = "stealth"
C.THEME_STARLIGHT = "zwp-zyg-starlight"
C.THEME_STEALTH = "zwp-zyg-stealth"

C.SCALE_DEFAULT = 1.00
C.SCALE_MIN = 0.60
C.SCALE_MAX = 2.00
C.SCALE_STEP = 0.05
C.MANUAL_CLEAR_DISTANCE_DEFAULT = 10
C.MANUAL_CLEAR_DISTANCE_MIN = 5
C.MANUAL_CLEAR_DISTANCE_MAX = 100
C.MANUAL_CLEAR_DISTANCE_STEP = 1

C.UPDATE_INTERVAL_SECONDS = 0.35
C.FALLBACK_DEBOUNCE_SECONDS = 1.20
C.FALLBACK_CONFIRM_COUNT = 2
C.DEST_FALLBACK_SUPPRESS_RECENT_ARROW_SECONDS = 2.50
C.DEST_FALLBACK_SUPPRESS_MAP_MISMATCH_SECONDS = 25.00

NS.Runtime.debug = NS.Runtime.debug == true

local function JoinArgs(...)
    if tostringall then
        return table.concat({ tostringall(...) }, " ")
    end

    local out = {}
    for i = 1, select("#", ...) do
        out[#out + 1] = tostring(select(i, ...))
    end
    return table.concat(out, " ")
end

function NS.Msg(...)
    if not DEFAULT_CHAT_FRAME then return end
    DEFAULT_CHAT_FRAME:AddMessage("|cff33ff99[ZWP]|r " .. JoinArgs(...))
end

function NS.Log(...)
    if not NS.Runtime.debug or not DEFAULT_CHAT_FRAME then return end
    DEFAULT_CHAT_FRAME:AddMessage("|cff99ccff[ZWP-DBG]|r " .. JoinArgs(...))
end

function NS.ZGV()
    return _G.ZygorGuidesViewer or _G.ZGV
end

function NS.After(delay, fn)
    if C_Timer and type(C_Timer.After) == "function" then
        C_Timer.After(delay, fn)
    else
        fn()
    end
end

function NS.SetDebugEnabled(enabled)
    NS.Runtime.debug = enabled and true or false
end

function NS.ToggleDebug()
    NS.Runtime.debug = not NS.Runtime.debug
    return NS.Runtime.debug
end
