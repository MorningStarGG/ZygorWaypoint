local NS = _G.AzerothWaypointNS
local state = NS.State
local GetZygorPointer = NS.GetZygorPointer
local GetTomTom = NS.GetTomTom
local SafeCall = NS.SafeCall

-- ============================================================
-- Initialization
-- ============================================================

local INIT_RETRY_DELAY_SECONDS = 0.25
local INIT_RETRY_MAX_COUNT = 8
local QUEST_HANDOFF_RETRY_DELAY_SECONDS = 0.05

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
f:RegisterEvent("LOADING_SCREEN_ENABLED")
f:RegisterEvent("LOADING_SCREEN_DISABLED")
f:RegisterEvent("NEW_WMO_CHUNK")
f:RegisterEvent("PLAYER_DEAD")
f:RegisterEvent("PLAYER_ALIVE")
f:RegisterEvent("PLAYER_UNGHOST")
f:RegisterEvent("UNIT_ENTERING_VEHICLE")
f:RegisterEvent("UNIT_EXITING_VEHICLE")
f:RegisterEvent("UNIT_FLAGS")
f:RegisterEvent("ZONE_CHANGED")
f:RegisterEvent("ZONE_CHANGED_INDOORS")
f:RegisterEvent("ZONE_CHANGED_NEW_AREA")
f:RegisterEvent("SUPER_TRACKING_CHANGED")
f:RegisterEvent("USER_WAYPOINT_UPDATED")
f:RegisterEvent("NAVIGATION_FRAME_CREATED")
f:RegisterEvent("NAVIGATION_FRAME_DESTROYED")
f:RegisterEvent("GOSSIP_SHOW")
f:RegisterEvent("GOSSIP_CLOSED")
f:RegisterEvent("QUEST_GREETING")
f:RegisterEvent("QUEST_DETAIL")
f:RegisterEvent("QUEST_PROGRESS")
f:RegisterEvent("QUEST_COMPLETE")
f:RegisterEvent("QUEST_FINISHED")
f:RegisterEvent("QUEST_ACCEPTED")
f:RegisterEvent("QUEST_TURNED_IN")
f:RegisterEvent("QUEST_LOG_UPDATE")
f:RegisterEvent("QUEST_REMOVED")
f:RegisterEvent("DYNAMIC_GOSSIP_POI_UPDATED")

-- ============================================================
-- Readiness checks and retry
-- ============================================================

local function RunWhenReady(isReady, fn, remaining)
    if type(fn) ~= "function" then
        return
    end

    remaining = remaining or INIT_RETRY_MAX_COUNT
    if type(isReady) ~= "function" or isReady() or remaining <= 0 then
        SafeCall(fn)
        return
    end

    NS.After(INIT_RETRY_DELAY_SECONDS, function()
        RunWhenReady(isReady, fn, remaining - 1)
    end)
end

local function IsZygorPointerReady()
    if type(NS.IsZygorLoaded) == "function" and not NS.IsZygorLoaded() then
        return false
    end
    local Z, P = GetZygorPointer()
    return Z ~= nil and P ~= nil
end

local function IsTomTomReady()
    local tomtom = GetTomTom()
    return tomtom ~= nil and type(tomtom.AddWaypoint) == "function"
end

local function ScheduleZygorPointerWork(fn)
    if type(NS.IsZygorLoaded) == "function" and not NS.IsZygorLoaded() then
        return
    end
    RunWhenReady(IsZygorPointerReady, fn)
end

local function ScheduleTomTomWork(fn)
    RunWhenReady(IsTomTomReady, fn)
end

local function MarkGuideResolverFactsDirty(reason, questID)
    SafeCall(NS.MarkGuideResolverFactsDirty, reason, questID)
end

local function MarkGuideResolverDialogDirty(reason)
    SafeCall(NS.MarkGuideResolverDialogDirty, reason)
end

local function ScheduleQuestHandoffRefreshRetry(reason, questID)
    NS.After(QUEST_HANDOFF_RETRY_DELAY_SECONDS, function()
        MarkGuideResolverDialogDirty(reason or "quest_handoff_retry")
        MarkGuideResolverFactsDirty(reason or "quest_handoff_retry", questID)
        SafeCall(NS.TickUpdate)
    end)
end

local function MarkGuideResolverForQuestLogChange(reason, questID)
    MarkGuideResolverFactsDirty(reason or "quest_log_update", questID)
end

-- ============================================================
-- Event handler
-- ============================================================

f:SetScript("OnEvent", function(_, ev, arg1)
    if ev == "ADDON_LOADED" then
        if arg1 == NS.ADDON_NAME then
            SafeCall(NS.ApplyDBDefaults)
            SafeCall(NS.InitializeRoutingCore)
            SafeCall(NS.InitializeWorldOverlay)
            SafeCall(NS.RegisterOptionsPanel)
            SafeCall(NS.RegisterCommands)
            NS.Msg("AzerothWaypoint loaded. Use /awp for commands.")
        end
    elseif ev == "PLAYER_LOGIN" then
        state.init.playerLoggedIn = true
        if type(rawget(_G, "ZygorWaypointNS")) == "table"
            or (type(C_AddOns) == "table" and type(C_AddOns.IsAddOnLoaded) == "function"
                and C_AddOns.IsAddOnLoaded("ZygorWaypoint"))
        then
            NS.Msg("|cffff4040WARNING:|r Old 'ZygorWaypoint' addon is still installed. Delete the ZygorWaypoint folder from Interface/AddOns to avoid conflicts.")
        end
        SafeCall(NS.RefreshSuperTrackedFrameSuppression)
        SafeCall(NS.InstallBlizzardTakeoverHooks)
        if type(NS.IsZygorLoaded) == "function" and NS.IsZygorLoaded() then
            SafeCall(NS.InstallZygorPoiTakeoverHooks)
        end
        NS.After(0, function()
            local startupHelpPage = SafeCall(NS.CheckStartupHelpNotification)
            SafeCall(NS.MaybeAnnounceWaypointUIRecommendation)
            NS.After(0.85, function()
                SafeCall(NS.MaybeAnnounceZygorArrowRecommendation, 1)
            end)
            NS.After(startupHelpPage and 4.0 or 0.35, function()
                SafeCall(NS.MaybeShowWaypointUIRecommendationPopup, 1)
            end)
            NS.After(0.5, function()
                SafeCall(NS.MaybeShowZygorWaypointConflictPopup)
                SafeCall(NS.StartZygorWaypointConflictReminders)
            end)
            NS.After(startupHelpPage and 6.0 or 1.25, function()
                SafeCall(NS.MaybeShowZygorArrowRecommendationPopup, 1)
            end)
        end)

        ScheduleZygorPointerWork(NS.HookZygorWhoWhereFallbacks)
        ScheduleZygorPointerWork(NS.HookZygorViewerChromeMode)

        SafeCall(NS.HydrateManualQueues)

        -- TomTom routing only depends on TomTom's waypoint API being available.
        ScheduleTomTomWork(function()
            SafeCall(NS.ApplyTomTomArrowDefaults)
            SafeCall(NS.InstallExternalTomTomHooks)
            SafeCall(NS.InstallCarrierTomTomHooks)
            local savedRouteSource = type(NS.GetSavedActiveRouteSource) == "function"
                and NS.GetSavedActiveRouteSource()
                or "manual"
            local restoredManualRoute = false
            if savedRouteSource ~= "guide" then
                if type(NS.RestoreManualQueues) == "function" then
                    restoredManualRoute = NS.RestoreManualQueues({
                        allowActiveQueueFallback = true,
                        skipHydrate = true,
                    }) == true
                end
                if not restoredManualRoute and type(NS.RestoreManualAuthority) == "function" then
                    restoredManualRoute = NS.RestoreManualAuthority() == true
                end
            end
            if not restoredManualRoute then
                SafeCall(NS.RecomputeCarrier)
            end
            -- Drive guide routing through AWP after the saved
            -- route source has had first chance to restore. Manual authority
            -- still wins once guide evaluation starts.
            SafeCall(NS.StartGuideRoutingEvaluation)
        end)

        -- Keep these staged: both addons can exist but still need a beat to settle
        -- after login/reload before startup adoption and the first bridge sync.
        NS.After(0.4, function()
            SafeCall(NS.RefreshWorldOverlay)
            -- Seed nav frame in case NAVIGATION_FRAME_CREATED already fired before we registered
            if type(C_Navigation.GetFrame) == "function" and C_Navigation.GetFrame() then
                SafeCall(NS.OnNativeNavFrameCreated)
            end
        end)
        NS.After(0.9, function() SafeCall(NS.SyncBlizzardTakeovers) end)
        NS.After(1.0, function() SafeCall(NS.TickUpdate) end)
    elseif ev == "CINEMATIC_START" or ev == "PLAY_MOVIE" or ev == "LOADING_SCREEN_ENABLED" then
        SafeCall(NS.SetCinematicActive, true)
    elseif ev == "CINEMATIC_STOP" or ev == "STOP_MOVIE" or ev == "LOADING_SCREEN_DISABLED" then
        SafeCall(NS.SetCinematicActive, false)
        if ev == "LOADING_SCREEN_DISABLED" then
            NS.After(0, function()
                SafeCall(NS.NoteRouteEnvironmentChanged, ev)
            end)
        end
    elseif ev == "PLAYER_DEAD" or ev == "PLAYER_ALIVE" or ev == "PLAYER_UNGHOST" then
        NS.After(0, function() SafeCall(NS.TickUpdate) end)
    elseif ev == "NEW_WMO_CHUNK"
        or ev == "UNIT_ENTERING_VEHICLE" or ev == "UNIT_EXITING_VEHICLE"
    then
        NS.After(0, function()
            SafeCall(NS.NoteRouteEnvironmentChanged, ev)
        end)
    elseif ev == "UNIT_FLAGS" and arg1 == "player" then
        NS.After(0, function()
            SafeCall(NS.TickUpdate)
        end)
    elseif ev == "ZONE_CHANGED" or ev == "ZONE_CHANGED_INDOORS" or ev == "ZONE_CHANGED_NEW_AREA" then
        NS.After(0, function()
            SafeCall(NS.NoteRouteEnvironmentChanged, ev)
        end)
    elseif ev == "SUPER_TRACKING_CHANGED" then
        local superType = C_SuperTrack.GetHighestPrioritySuperTrackingType and C_SuperTrack.GetHighestPrioritySuperTrackingType()
        NS.LogSuperTrackTrace("SUPER_TRACKING_CHANGED", tostring(superType))
        SafeCall(NS.RefreshSuperTrackedFrameSuppression)
        if superType ~= Enum.SuperTrackingType.UserWaypoint then
            NS.After(0, function()
                SafeCall(NS.RefreshWorldOverlay)
                SafeCall(NS.TickUpdate)
            end)
        end
    elseif ev == "USER_WAYPOINT_UPDATED" then
        local churn = state.churn
        if churn and churn.active then
            churn.userWaypointUpdatedEvent = churn.userWaypointUpdatedEvent + 1
        end
        local hasUserWaypoint = C_Map.HasUserWaypoint and C_Map.HasUserWaypoint()
        NS.LogSuperTrackTrace("USER_WAYPOINT_UPDATED", tostring(hasUserWaypoint))
        SafeCall(NS.RefreshSuperTrackedFrameSuppression)
        NS.After(0, function() SafeCall(NS.RefreshWorldOverlay) end)
    elseif ev == "QUEST_LOG_UPDATE" or ev == "QUEST_REMOVED" then
        SafeCall(NS.InvalidateNativeOverlayQuestCaches, arg1)
        SafeCall(NS.ScheduleActiveQuestBackedManualRefresh, ev, arg1)
        MarkGuideResolverForQuestLogChange(ev, arg1)
        SafeCall(NS.ScheduleActiveGuidePresentationRefresh, ev)
    elseif ev == "NAVIGATION_FRAME_CREATED" then
        SafeCall(NS.OnNativeNavFrameCreated)
    elseif ev == "NAVIGATION_FRAME_DESTROYED" then
        SafeCall(NS.OnNativeNavFrameDestroyed)
    elseif ev == "GOSSIP_SHOW"
        or ev == "GOSSIP_CLOSED"
        or ev == "QUEST_GREETING"
        or ev == "QUEST_DETAIL"
        or ev == "QUEST_PROGRESS"
        or ev == "QUEST_COMPLETE"
        or ev == "QUEST_FINISHED"
        or ev == "QUEST_ACCEPTED"
        or ev == "QUEST_TURNED_IN"
    then
        SafeCall(NS.InvalidateNativeOverlayQuestCaches, arg1)
        if ev == "QUEST_TURNED_IN" then
            SafeCall(NS.ScheduleActiveQuestBackedManualRefresh, ev, arg1)
        end
        MarkGuideResolverDialogDirty(ev)
        if ev == "QUEST_ACCEPTED" or ev == "QUEST_TURNED_IN" then
            MarkGuideResolverFactsDirty(ev, arg1)
            ScheduleQuestHandoffRefreshRetry(ev .. "_retry", arg1)
        end
        NS.After(0, function() SafeCall(NS.TickUpdate) end)
    elseif ev == "DYNAMIC_GOSSIP_POI_UPDATED" then
        NS.After(0, function() SafeCall(NS.OnDynamicGossipPoiUpdated) end)
    end
end)
