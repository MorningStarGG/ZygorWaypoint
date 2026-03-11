local NS = _G.ZygorWaypointNS
local state = NS.State

state.init = state.init or {}

local f = CreateFrame("Frame")
state.init.frame = f

f:RegisterEvent("ADDON_LOADED")
f:RegisterEvent("PLAYER_LOGIN")

f:SetScript("OnEvent", function(_, ev, arg1)
    if ev == "ADDON_LOADED" then
        if arg1 == NS.ADDON_NAME then
            NS.ApplyDBDefaults()
            NS.RegisterOptionsPanel()
            NS.RegisterCommands()
            NS.StartBridgeHeartbeat()
            NS.Msg("ZygorWaypoint loaded. Use /zwp for commands.")
        elseif arg1 == "TomTom" then
            NS.After(0.1, NS.ApplyTomTomArrowDefaults)
            NS.After(0.2, NS.HookTomTomRouting)
        elseif arg1 == "ZygorGuidesViewer" then
            NS.After(0.1, NS.HookZygorGuideGuards)
            NS.After(0.1, NS.HookZygorWhoWhereFallbacks)
            NS.After(0.1, NS.HookZygorArrowTextures)
            NS.After(0.1, NS.HookZygorViewerChromeMode)
        end
    elseif ev == "PLAYER_LOGIN" then
        NS.HookZygorTickHooks()
        NS.After(0.5, NS.HookZygorGuideGuards)
        NS.After(0.5, NS.HookZygorWhoWhereFallbacks)
        NS.After(0.5, NS.ApplyTomTomArrowDefaults)
        NS.After(0.5, NS.HookZygorArrowTextures)
        NS.After(0.5, NS.HookZygorViewerChromeMode)
        NS.After(0.6, NS.HookTomTomRouting)
        NS.After(1.0, NS.TickUpdate)
    end
end)
