local NS = _G.ZygorWaypointNS
local state = NS.State

state.init = state.init or {}
state.init.playerLoggedIn = state.init.playerLoggedIn == true

local f = CreateFrame("Frame")
state.init.frame = f

f:RegisterEvent("ADDON_LOADED")
f:RegisterEvent("PLAYER_LOGIN")
f:RegisterEvent("CINEMATIC_START")
f:RegisterEvent("CINEMATIC_STOP")
f:RegisterEvent("PLAY_MOVIE")
f:RegisterEvent("STOP_MOVIE")
f:RegisterEvent("SUPER_TRACKING_CHANGED")
f:RegisterEvent("USER_WAYPOINT_UPDATED")

f:SetScript("OnEvent", function(_, ev, arg1)
    if ev == "ADDON_LOADED" then
        if arg1 == NS.ADDON_NAME then
            if type(NS.InstallWaypointUICompat) == "function" then
                NS.InstallWaypointUICompat()
            end
            NS.ApplyDBDefaults()
            NS.RegisterOptionsPanel()
            NS.RegisterCommands()
            NS.InstallSuperTrackDebugHooks()
            NS.StartBridgeHeartbeat()
            NS.Msg("ZygorWaypoint loaded. Use /zwp for commands.")
        end
    elseif ev == "PLAYER_LOGIN" then
        state.init.playerLoggedIn = true
        NS.HookZygorTickHooks()
        NS.After(0.5, NS.HookZygorGuideGuards)
        NS.After(0.5, NS.HookZygorWhoWhereFallbacks)
        NS.After(0.5, NS.ApplyTomTomArrowDefaults)
        NS.After(0.5, NS.HookZygorArrowTextures)
        NS.After(0.5, NS.HookZygorViewerChromeMode)
        NS.After(0.6, NS.HookTomTomRouting)
        NS.After(0.8, NS.ResumeTomTomRoutingStartupSync)
        NS.After(1.0, NS.TickUpdate)
    elseif ev == "CINEMATIC_START" or ev == "PLAY_MOVIE" then
        if type(NS.SetCinematicActive) == "function" then
            NS.SetCinematicActive(true)
        end
    elseif ev == "CINEMATIC_STOP" or ev == "STOP_MOVIE" then
        if type(NS.SetCinematicActive) == "function" then
            NS.SetCinematicActive(false)
        end
    elseif ev == "SUPER_TRACKING_CHANGED" then
        local superType = C_SuperTrack and C_SuperTrack.GetHighestPrioritySuperTrackingType and C_SuperTrack.GetHighestPrioritySuperTrackingType()
        NS.LogSuperTrackTrace("SUPER_TRACKING_CHANGED", tostring(superType))
        if superType ~= Enum.SuperTrackingType.UserWaypoint and type(NS.TickUpdate) == "function" then
            NS.After(0, NS.TickUpdate)
        end
    elseif ev == "USER_WAYPOINT_UPDATED" then
        local hasUserWaypoint = C_Map and C_Map.HasUserWaypoint and C_Map.HasUserWaypoint()
        NS.LogSuperTrackTrace("USER_WAYPOINT_UPDATED", tostring(hasUserWaypoint))
    end
end)
