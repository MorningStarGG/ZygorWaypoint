local NS = _G.AzerothWaypointNS
if not NS.IsAPRLoaded() then return end

local PROVIDER = "apr"
local APRPresentation = NS.Internal and NS.Internal.APRPresentation or nil

local function GetAPR()
    return rawget(_G, "APR")
end

local function IsLoaded()
    return type(NS.IsAPRLoaded) == "function" and NS.IsAPRLoaded() or type(GetAPR()) == "table"
end

local function GetCurrentStepIndex(APR)
    local route = APR and APR.ActiveRoute
    local data = rawget(_G, "APRData")
    local playerID = APR and APR.PlayerID
    local playerData = type(data) == "table" and playerID and data[playerID] or nil
    return type(playerData) == "table" and route and tonumber(playerData[route]) or nil
end

local function GetCurrentStep(APR)
    local index = GetCurrentStepIndex(APR)
    if not index or type(APR.GetStep) ~= "function" then
        return nil, nil
    end
    local ok, step = pcall(APR.GetStep, APR, index)
    if ok and type(step) == "table" then
        return step, index
    end
    return nil, index
end

local function IsCurrentStepFrameShown(APR)
    local frame = rawget(_G, "CurrentStepScreenPanel")
    if frame and type(frame.IsShown) == "function" then
        return frame:IsShown()
    end
    local currentStep = APR and APR.currentStep
    if type(currentStep) == "table" and type(currentStep.IsShown) == "function" then
        return currentStep:IsShown()
    end
    return true
end

local function GetVisibilityState()
    local APR = GetAPR()
    if not IsLoaded() or type(APR) ~= "table" then
        return "absent"
    end
    local profile = APR.settings and APR.settings.profile
    if type(profile) == "table" and profile.enableAddon == false then
        return "absent"
    end
    if not APR.ActiveRoute or not GetCurrentStep(APR) then
        return "absent"
    end
    if type(profile) == "table" and profile.currentStepShow == false then
        return "hidden"
    end
    return IsCurrentStepFrameShown(APR) and "visible" or "hidden"
end

local function GetRouteFallbackMapID(APR)
    if type(APR.GetCurrentRouteMapIDsAndName) == "function" then
        local ok, _, mapID = pcall(APR.GetCurrentRouteMapIDsAndName, APR)
        if ok and type(mapID) == "number" and mapID > 0 then
            return mapID
        end
    end
    if APR.ActiveRoute and type(APR.GetRouteMapID) == "function" then
        local ok, mapID = pcall(APR.GetRouteMapID, APR, APR.ActiveRoute)
        if ok and type(mapID) == "number" and mapID > 0 then
            return mapID
        end
    end
    return type(C_Map) == "table" and type(C_Map.GetBestMapForUnit) == "function" and C_Map.GetBestMapForUnit("player") or nil
end

local function ExtractTarget()
    local APR = GetAPR()
    if type(APR) ~= "table" then
        return nil, false
    end

    local step, stepIndex = GetCurrentStep(APR)
    if type(step) ~= "table" then
        return nil, true
    end

    local fallbackMapID = GetRouteFallbackMapID(APR)
    local zoneHint = type(APR.GetPlayerParentMapID) == "function" and APR:GetPlayerParentMapID() or fallbackMapID
    if type(APR.GetStepCoord) ~= "function" or type(APR.GetPlayerMapPos) ~= "function" then
        return nil, true
    end

    local coord, coordMapID = APR:GetStepCoord(step, fallbackMapID, zoneHint)
    local mapID = type(coordMapID) == "number" and coordMapID > 0 and coordMapID or fallbackMapID
    if type(coord) ~= "table" or type(coord.x) ~= "number" or type(coord.y) ~= "number" or type(mapID) ~= "number" then
        return nil, true
    end

    local x, y = APR:GetPlayerMapPos(mapID, coord.y, coord.x)
    if type(x) ~= "number" or type(y) ~= "number" or x < 0 or y < 0 or x > 1 or y > 1 then
        return nil, true
    end

    local presentation = type(APRPresentation) == "table"
        and type(APRPresentation.ResolveStep) == "function"
        and APRPresentation.ResolveStep(APR, step)
        or nil
    local title = type(presentation) == "table" and presentation.title or "APR step"
    local questID = type(presentation) == "table" and presentation.primaryQuestID or nil
    return {
        mapID = mapID,
        x = x,
        y = y,
        title = title,
        rawTitle = type(presentation) == "table" and presentation.rawTitle or title,
        subtext = type(presentation) == "table" and presentation.subtext or nil,
        source = stepIndex and ("apr.step#" .. tostring(stepIndex)) or "apr.step",
        kind = "guide_goal",
        guideProvider = PROVIDER,
        semanticKind = questID and "quest" or nil,
        semanticQuestID = questID,
        iconHintKind = questID and "quest" or nil,
        iconHintQuestID = questID,
        aprStepKey = type(presentation) == "table" and presentation.stepKey or nil,
        aprQuestIDs = type(presentation) == "table" and presentation.questIDs or nil,
        aprTitleSource = type(presentation) == "table" and presentation.titleSource or nil,
        aprSubtextSource = type(presentation) == "table" and presentation.subtextSource or nil,
    }, false
end

local function GetActivationToken()
    local APR = GetAPR()
    if type(APR) ~= "table" then
        return nil
    end
    return table.concat({
        tostring(APR.ActiveRoute or "-"),
        tostring(GetCurrentStepIndex(APR) or "-"),
    }, "\031", 1, 2)
end

local function HookFrameVisibility(schedule)
    local switchOpts = { allowProviderSwitch = true }
    local frame = rawget(_G, "CurrentStepScreenPanel")
    if frame and type(frame.HookScript) == "function" and not frame._awpAPRVisibilityHooked then
        frame:HookScript("OnShow", function() schedule("APRCurrentStepOnShow", switchOpts) end)
        frame:HookScript("OnHide", function() schedule("APRCurrentStepOnHide") end)
        frame._awpAPRVisibilityHooked = true
    end
end

local function InstallHooks(schedule)
    local APR = GetAPR()
    if type(APR) ~= "table" then
        return
    end

    local switchOpts = { allowProviderSwitch = true }
    local function scheduleFor(reason, opts)
        return function()
            schedule(reason, opts)
            HookFrameVisibility(schedule)
        end
    end

    if type(APR.UpdateStep) == "function" then
        hooksecurefunc(APR, "UpdateStep", scheduleFor("APRUpdateStep", switchOpts))
    end
    if type(APR.UpdateNextStep) == "function" then
        hooksecurefunc(APR, "UpdateNextStep", scheduleFor("APRUpdateNextStep", switchOpts))
    end
    if type(APR.ResetRoute) == "function" then
        hooksecurefunc(APR, "ResetRoute", scheduleFor("APRResetRoute", switchOpts))
    end
    if type(APR.Arrow) == "table" and type(APR.Arrow.SetCoord) == "function" then
        hooksecurefunc(APR.Arrow, "SetCoord", scheduleFor("APRArrowSetCoord", switchOpts))
    end
    HookFrameVisibility(schedule)
end

local function FormatCoords(mapID, x, y)
    if type(mapID) ~= "number" or type(x) ~= "number" or type(y) ~= "number" then
        return "nil"
    end
    return string.format("%s@%.4f,%.4f", tostring(mapID), x, y)
end

local function FormatRawCoord(coord)
    if type(coord) ~= "table" or type(coord.x) ~= "number" or type(coord.y) ~= "number" then
        return "nil"
    end
    return string.format("%.2f,%.2f", coord.x, coord.y)
end

local function FormatQuestIDs(ids)
    if type(ids) ~= "table" or #ids == 0 then
        return "-"
    end
    local parts = {}
    for index = 1, #ids do
        parts[index] = tostring(ids[index])
    end
    return table.concat(parts, ",")
end

local function FormatDebugText(value)
    if value == nil then
        return "nil"
    end
    return tostring(value):gsub("\n", "\\n")
end

local function GetDebugLines(genericLines)
    local lines = {}
    local APR = GetAPR()
    if type(APR) ~= "table" then
        lines[#lines + 1] = "provider=apr loaded=false"
        return lines
    end

    local step, stepIndex = GetCurrentStep(APR)
    local fallbackMapID = GetRouteFallbackMapID(APR)
    local zoneHint = type(APR.GetPlayerParentMapID) == "function" and APR:GetPlayerParentMapID() or fallbackMapID
    local coord, coordMapID
    if type(step) == "table" and type(APR.GetStepCoord) == "function" then
        local ok, resolvedCoord, resolvedMapID = pcall(APR.GetStepCoord, APR, step, fallbackMapID, zoneHint)
        if ok then
            coord = resolvedCoord
            coordMapID = resolvedMapID
        end
    end

    local okTarget, target, suppressed = pcall(ExtractTarget)
    if not okTarget then
        target = nil
        suppressed = true
    end

    lines[#lines + 1] = table.concat({
        "apr",
        "loaded=" .. tostring(IsLoaded()),
        "visibility=" .. tostring(GetVisibilityState()),
        "activeRoute=" .. tostring(APR.ActiveRoute or "-"),
        "step=" .. tostring(stepIndex or "-"),
        "fallbackMap=" .. tostring(fallbackMapID or "-"),
        "zoneHint=" .. tostring(zoneHint or "-"),
        "coordMap=" .. tostring(coordMapID or "-"),
        "rawCoord=" .. FormatRawCoord(coord),
    }, " ")

    if type(target) == "table" then
        lines[#lines + 1] = table.concat({
            "aprTarget",
            "title=" .. FormatDebugText(target.title),
            "subtext=" .. FormatDebugText(target.subtext),
            "source=" .. tostring(target.source),
            "coords=" .. FormatCoords(target.mapID, target.x, target.y),
            "questID=" .. tostring(target.semanticQuestID),
            "questIDs=" .. FormatQuestIDs(target.aprQuestIDs),
            "stepKey=" .. tostring(target.aprStepKey or "-"),
            "titleSource=" .. tostring(target.aprTitleSource or "-"),
            "subtextSource=" .. tostring(target.aprSubtextSource or "-"),
        }, " ")
    else
        lines[#lines + 1] = "aprTarget=nil suppressed=" .. tostring(suppressed)
    end

    if type(genericLines) == "table" then
        for index = 1, #genericLines do
            lines[#lines + 1] = genericLines[index]
        end
    end
    return lines
end

NS.RegisterGuideTargetProvider(PROVIDER, {
    label = "Azeroth Pilot Reloaded",
    displayName = "APR",
    icon = "Interface\\AddOns\\APR\\APR-Core\\assets\\APR_logo.blp",
    iconTint = { r = 0.22, g = 0.75, b = 1, a = 1 },
    iconSize = 16,
    isLoaded = IsLoaded,
    getVisibilityState = GetVisibilityState,
    getActivationToken = GetActivationToken,
    extractTarget = ExtractTarget,
    getDebugLines = GetDebugLines,
    installHooks = InstallHooks,
})
