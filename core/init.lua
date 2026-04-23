local NS = _G.ZygorWaypointNS
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
f:RegisterEvent("PLAYER_DEAD")
f:RegisterEvent("PLAYER_ALIVE")
f:RegisterEvent("PLAYER_UNGHOST")
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
    local Z, P = GetZygorPointer()
    return Z ~= nil and P ~= nil
end

local function IsTomTomReady()
    local tomtom = GetTomTom()
    return tomtom ~= nil and type(tomtom.AddWaypoint) == "function"
end

local function ScheduleZygorPointerWork(fn)
    RunWhenReady(IsZygorPointerReady, fn)
end

local function ScheduleTomTomWork(fn)
    RunWhenReady(IsTomTomReady, fn)
end

local function RunLegacy2xAutoRepairMigration()
    local shouldRepair = type(NS.ShouldRunLegacy2xAutoRepair) == "function"
        and NS.ShouldRunLegacy2xAutoRepair()
        or false
    local shouldCleanup = type(NS.ShouldRunLegacy2xSavedVariableCleanup) == "function"
        and NS.ShouldRunLegacy2xSavedVariableCleanup()
        or false
    local fixed = nil
    local removed = nil

    if shouldRepair and type(NS.RunRepair) == "function" then
        fixed = NS.RunRepair({ silent = true })
    end

    if shouldCleanup and type(NS.RunLegacy2xSavedVariableCleanup) == "function" then
        removed = NS.RunLegacy2xSavedVariableCleanup()
    end

    if type(NS.MarkLegacy2xAutoRepairDone) == "function" then
        NS.MarkLegacy2xAutoRepairDone()
    end

    if shouldCleanup and type(NS.MarkLegacy2xSavedVariableCleanupDone) == "function" then
        NS.MarkLegacy2xSavedVariableCleanupDone()
    end

    if type(fixed) == "table" and #fixed > 0 then
        NS.Msg("Applied one-time repair for settings from an older ZWP 2.x version. Type /reload to apply.")
    end

    if type(removed) == "table" and #removed > 0 then
        local count = #removed
        NS.Msg(string.format(
            "Cleaned %d obsolete saved setting%s from older ZWP 2.x data.",
            count,
            count == 1 and "" or "s"
        ))
    end
end

local function ScheduleQuestHandoffRefreshRetry()
    NS.After(QUEST_HANDOFF_RETRY_DELAY_SECONDS, function()
        SafeCall(NS.InvalidateGuideResolverDialogState)
        SafeCall(NS.InvalidateGuideResolverFactsState)
        SafeCall(NS.TickUpdate)
    end)
end

-- ============================================================
-- Event handler
-- ============================================================

f:SetScript("OnEvent", function(_, ev, arg1)
    if ev == "ADDON_LOADED" then
        if arg1 == NS.ADDON_NAME then
            SafeCall(NS.ApplyDBDefaults)
            SafeCall(NS.InitializeWorldOverlay)
            SafeCall(NS.RegisterOptionsPanel)
            SafeCall(NS.RegisterCommands)
            SafeCall(NS.StartBridgeHeartbeat)
            NS.Msg("ZygorWaypoint loaded. Use /zwp for commands.")
        end
    elseif ev == "PLAYER_LOGIN" then
        state.init.playerLoggedIn = true
        SafeCall(NS.RefreshSuperTrackedFrameSuppression)
        SafeCall(NS.InstallBlizzardQuestTakeoverHooks)
        -- Immediate method hooks on the viewer. These are safe to install as soon
        -- as PLAYER_LOGIN fires, even if Pointer-derived objects are not fully ready.
        SafeCall(NS.HookZygorTickHooks)
        NS.After(0, function()
            SafeCall(NS.CheckStartupHelpNotification)
            SafeCall(RunLegacy2xAutoRepairMigration)
            SafeCall(NS.MaybeAnnounceWaypointUIRecommendation)
            NS.After(0.35, function()
                SafeCall(NS.MaybeShowWaypointUIRecommendationPopup)
            end)
        end)

        -- These features require Zygor.Pointer/ArrowFrame-style objects and are
        -- retried until that dependency becomes available.
        ScheduleZygorPointerWork(function()
            SafeCall(NS.HookZygorGuideGuards)
            SafeCall(NS.HookZygorDisplayState)
        end)
        ScheduleZygorPointerWork(NS.HookZygorWhoWhereFallbacks)
        ScheduleZygorPointerWork(NS.ApplyTomTomArrowDefaults)
        ScheduleZygorPointerWork(NS.HookZygorArrowTextures)
        ScheduleZygorPointerWork(NS.HookZygorViewerChromeMode)

        -- TomTom routing only depends on TomTom's waypoint API being available.
        ScheduleTomTomWork(NS.HookTomTomRouting)

        -- Keep these staged: both addons can exist but still need a beat to settle
        -- after login/reload before startup adoption and the first bridge sync.
        NS.After(0.4, function()
            SafeCall(NS.RefreshWorldOverlay)
            -- Seed nav frame in case NAVIGATION_FRAME_CREATED already fired before we registered
            if type(C_Navigation.GetFrame) == "function" and C_Navigation.GetFrame() then
                SafeCall(NS.OnNativeNavFrameCreated)
            end
        end)
        NS.After(0.8, function() SafeCall(NS.ResumeTomTomRoutingStartupSync) end)
        NS.After(0.9, function() SafeCall(NS.SyncSuperTrackedQuestToManual) end)
        NS.After(1.0, function() SafeCall(NS.TickUpdate) end)
    elseif ev == "CINEMATIC_START" or ev == "PLAY_MOVIE" or ev == "LOADING_SCREEN_ENABLED" then
        SafeCall(NS.SetCinematicActive, true)
    elseif ev == "CINEMATIC_STOP" or ev == "STOP_MOVIE" or ev == "LOADING_SCREEN_DISABLED" then
        SafeCall(NS.SetCinematicActive, false)
    elseif ev == "PLAYER_DEAD" or ev == "PLAYER_ALIVE" or ev == "PLAYER_UNGHOST" then
        NS.After(0, function() SafeCall(NS.TickUpdate) end)
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
        SafeCall(NS.InvalidateGuideResolverDialogState)
        if ev == "QUEST_ACCEPTED" or ev == "QUEST_TURNED_IN" then
            SafeCall(NS.InvalidateGuideResolverFactsState)
            ScheduleQuestHandoffRefreshRetry()
        end
        NS.After(0, function() SafeCall(NS.TickUpdate) end)
    end
end)
