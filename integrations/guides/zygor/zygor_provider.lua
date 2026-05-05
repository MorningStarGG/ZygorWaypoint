local NS = _G.AzerothWaypointNS
if not NS.IsZygorLoaded() then return end

local state = NS.State

local PROVIDER = "zygor"
local EXPLICIT_GUIDE_REASSERT_DELAYS = { 0, 0.05 }
local explicitGuideActivationSerial = 0

local function TrimText(value)
    if type(value) ~= "string" then
        return nil
    end
    value = value:gsub("^%s+", ""):gsub("%s+$", "")
    if value == "" then
        return nil
    end
    return value
end

local function GetZygor()
    return type(NS.ZGV) == "function" and NS.ZGV() or rawget(_G, "ZygorGuidesViewer")
end

local function IsLoaded()
    return type(NS.IsZygorLoaded) == "function" and NS.IsZygorLoaded() or GetZygor() ~= nil
end

local function GetVisibilityState()
    if not IsLoaded() then return "absent" end
    if state.routing.cinematicActive then return "hidden" end

    local Z = GetZygor()
    if not Z or not Z.Frame then return "absent" end
    if not Z.CurrentGuide or not Z.CurrentStep then return "absent" end

    if Z.Frame.IsVisible and Z.Frame:IsVisible() then return "visible" end
    return "hidden"
end

local function ExtractTarget()
    if type(NS.ExtractGuideRouteTargetFromZygor) ~= "function" then
        return nil, false
    end

    local target = NS.ExtractGuideRouteTargetFromZygor()
    if not NS.IsValidGuideRouteTarget(target) then
        return nil, true
    end
    target.kind = target.kind or "guide_goal"
    target.guideProvider = PROVIDER
    return target, false
end

local function GetActivationToken()
    local Z = GetZygor()
    local guide = type(Z) == "table" and Z.CurrentGuide or nil
    if type(guide) ~= "table" then
        return nil
    end

    local step = type(Z.CurrentStep) == "table" and Z.CurrentStep or nil
    return table.concat({
        tostring(guide.title or guide.guid or guide.name or guide),
        tostring(step and (step.num or step.stepnum) or Z.CurrentStepNum or "-"),
    }, "\031", 1, 2)
end

local function CallTextMethod(target, methodName, ...)
    if type(target) ~= "table" or type(target[methodName]) ~= "function" then
        return nil
    end
    local ok, value = pcall(target[methodName], target, ...)
    if ok then
        return TrimText(value)
    end
    return nil
end

local function GetClickedGuideGoalTitle(goal)
    local step = type(goal) == "table" and goal.parentStep or nil
    return CallTextMethod(goal, "GetText", true, false, false)
        or TrimText(goal and goal.title)
        or TrimText(goal and goal.header)
        or TrimText(goal and goal.tooltip)
        or CallTextMethod(step, "GetWayTitle")
        or CallTextMethod(step, "GetTitle")
        or TrimText(step and step.title)
        or "Guide step"
end

local function BuildGuideTargetFromClickedGoal(goal)
    if type(goal) ~= "table" or goal.force_noway == true then
        return nil
    end
    local step = goal.parentStep
    if type(step) == "table"
        and type(step.IsCurrentlySticky) == "function"
        and step:IsCurrentlySticky()
    then
        return nil
    end

    local marker = type(goal.mapmarker) == "table" and goal.mapmarker or nil
    local mapID = goal.map or goal.mapid or goal.mapID or marker and (marker.map or marker.mapid or marker.mapID)
    local x = goal.x or marker and marker.x
    local y = goal.y or marker and marker.y
    if type(mapID) ~= "number" or type(x) ~= "number" or type(y) ~= "number" then
        return nil
    end

    return {
        mapID = mapID,
        x = x,
        y = y,
        title = GetClickedGuideGoalTitle(goal),
        source = type(goal.num) == "number" and ("step.goal#" .. tostring(goal.num)) or "step.goal",
        kind = "guide_goal",
        guideProvider = PROVIDER,
    }
end

local function PushExplicitGuideTarget(fallbackTarget)
    NS.UpdateGuideTarget(PROVIDER, fallbackTarget, false, {
        explicit = true,
        reason = "guide_goal_click",
    })
    if type(NS.RecomputeCarrier) == "function" then
        NS.RecomputeCarrier()
    end
end

local function ActivateGuideTargetFromExplicitGoalClick(goal)
    local fallbackTarget = BuildGuideTargetFromClickedGoal(goal)
    if not NS.IsValidGuideRouteTarget(fallbackTarget) then
        return false
    end

    explicitGuideActivationSerial = explicitGuideActivationSerial + 1
    local serial = explicitGuideActivationSerial

    PushExplicitGuideTarget(fallbackTarget)

    if type(NS.After) == "function" then
        for index = 1, #EXPLICIT_GUIDE_REASSERT_DELAYS do
            NS.After(EXPLICIT_GUIDE_REASSERT_DELAYS[index], function()
                if serial ~= explicitGuideActivationSerial then
                    return
                end
                PushExplicitGuideTarget(fallbackTarget)
            end)
        end
    end
    return true
end

local function HookExplicitGuideGoalClicks(Z)
    local goalProto = type(Z) == "table" and type(Z.GoalProto) == "table" and Z.GoalProto or nil
    if not goalProto or goalProto._awpExplicitGuideClickHooked or type(goalProto.OnClick) ~= "function" then
        return
    end
    hooksecurefunc(goalProto, "OnClick", function(goal, button)
        if button ~= nil and button ~= "LeftButton" then
            return
        end
        ActivateGuideTargetFromExplicitGoalClick(goal)
    end)
    goalProto._awpExplicitGuideClickHooked = true
end

local function GetTimeSafe()
    return type(GetTime) == "function" and GetTime() or 0
end

local function ShouldBlockHiddenGuideAutoLoad(special)
    if type(NS.GetGuideVisibilityState) ~= "function" or NS.GetGuideVisibilityState(PROVIDER) ~= "hidden" then
        return false
    end

    local takeover = state.bridgeTakeover
    if type(takeover) == "table"
        and type(takeover.blockHiddenGuideLoadsUntil) == "number"
        and takeover.blockHiddenGuideLoadsUntil > GetTimeSafe()
    then
        return true
    end

    if type(special) == "string" and special ~= "" then
        return true
    end

    return type(NS.IsExplicitUserSupertrack) == "function" and NS.IsExplicitUserSupertrack() or false
end

local function HookHiddenGuideAutoLoadGuard(Z)
    local tabs = type(Z) == "table" and type(Z.Tabs) == "table" and Z.Tabs or nil
    if not tabs or tabs._awpHiddenGuideAutoLoadGuarded or type(tabs.LoadGuideToTab) ~= "function" then
        return
    end

    local originalLoadGuideToTab = tabs.LoadGuideToTab
    tabs.LoadGuideToTab = function(self, guide, step, special, ...)
        local notifiedGuideLoad = false
        local explicitSupertrack = type(NS.IsExplicitUserSupertrack) == "function"
            and NS.IsExplicitUserSupertrack()
            or false
        local pendingTakeover = type(NS.HasPendingGuideTakeover) == "function"
            and NS.HasPendingGuideTakeover()
            or false
        if type(special) == "string" and special ~= ""
            and (explicitSupertrack or pendingTakeover)
            and type(NS.NotifyPendingGuideTakeoverGuideLoad) == "function"
        then
            notifiedGuideLoad = NS.NotifyPendingGuideTakeoverGuideLoad("LoadGuideToTab", special) == true
        end
        if ShouldBlockHiddenGuideAutoLoad(special) then
            if type(NS.Log) == "function" then
                NS.Log("Hidden Zygor guide auto-load blocked", tostring(special or "-"))
            end
            return false
        end
        local result = originalLoadGuideToTab(self, guide, step, special, ...)
        if notifiedGuideLoad and type(NS.HandlePendingGuideTakeoverSignal) == "function" then
            NS.HandlePendingGuideTakeoverSignal("LoadGuideToTab")
        end
        return result
    end
    tabs._awpHiddenGuideAutoLoadGuarded = true
end

local function ScheduleZygorPresentationRefresh(reason)
    if type(NS.MarkGuideResolverFactsDirty) == "function" then
        NS.MarkGuideResolverFactsDirty(reason or "zygor_goal_progress")
    end
    if type(NS.ScheduleActiveGuidePresentationRefresh) == "function" then
        NS.ScheduleActiveGuidePresentationRefresh(reason or "zygor_goal_progress")
    end
end

local function InstallHooks(schedule)
    local Z = GetZygor()
    if not Z then
        return
    end

    local switchOpts = { allowProviderSwitch = true }

    HookExplicitGuideGoalClicks(Z)
    HookHiddenGuideAutoLoadGuard(Z)
    if type(NS.InstallZygorBlizzardIconGuideSignalHook) == "function" then
        NS.InstallZygorBlizzardIconGuideSignalHook()
    end

    local function scheduleFor(reason, opts)
        return function()
            schedule(reason, opts)
        end
    end

    if type(Z.SetCurrentStep) == "function" then
        hooksecurefunc(Z, "SetCurrentStep", scheduleFor("SetCurrentStep", switchOpts))
    end
    if type(Z.FocusStep) == "function" then
        hooksecurefunc(Z, "FocusStep", scheduleFor("FocusStep", switchOpts))
    end
    if type(Z.GoalProgress) == "function" then
        hooksecurefunc(Z, "GoalProgress", scheduleFor("GoalProgress"))
    end
    if type(Z.Tabs) == "table" and type(Z.Tabs.LoadGuideToTab) == "function" then
        hooksecurefunc(Z.Tabs, "LoadGuideToTab", scheduleFor("LoadGuideToTab", switchOpts))
    end
    if type(Z.AddMessageHandler) == "function" then
        pcall(Z.AddMessageHandler, Z, "LIBROVER_TRAVEL_REPORTED", function()
            schedule("LIBROVER_TRAVEL_REPORTED")
        end)
        pcall(Z.AddMessageHandler, Z, "ZGV_GOAL_PROGRESS", function()
            ScheduleZygorPresentationRefresh("ZGV_GOAL_PROGRESS")
        end)
        pcall(Z.AddMessageHandler, Z, "ZGV_GOAL_COMPLETED", function()
            ScheduleZygorPresentationRefresh("ZGV_GOAL_COMPLETED")
        end)
        pcall(Z.AddMessageHandler, Z, "ZGV_GOAL_UNCOMPLETED", function()
            ScheduleZygorPresentationRefresh("ZGV_GOAL_UNCOMPLETED")
        end)
        pcall(Z.AddMessageHandler, Z, "ZGV_STEP_CHANGED", function()
            ScheduleZygorPresentationRefresh("ZGV_STEP_CHANGED")
        end)
    end
    if Z.Frame and type(Z.Frame.HookScript) == "function" then
        Z.Frame:HookScript("OnShow", scheduleFor("GuideFrameOnShow", switchOpts))
        Z.Frame:HookScript("OnHide", scheduleFor("GuideFrameOnHide"))
    end
end

NS.RegisterGuideTargetProvider(PROVIDER, {
    label = "Zygor",
    displayName = "Zygor",
    icon = "Interface\\AddOns\\ZygorGuidesViewer\\Skins\\addon-icon.tga",
    iconTint = { r = 0.996, g = 0.38, b = 0, a = 1 },
    iconSize = 16,
    isLoaded = IsLoaded,
    getVisibilityState = GetVisibilityState,
    getActivationToken = GetActivationToken,
    extractTarget = ExtractTarget,
    installHooks = InstallHooks,
})
