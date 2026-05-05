local NS = _G.AzerothWaypointNS
if not NS.IsWoWProLoaded() then return end

local PROVIDER = "wowpro"
local Presentation = NS.Internal and NS.Internal.WoWProPresentation or nil

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

local function GetWoWPro()
    return rawget(_G, "WoWPro")
end

local function IsLoaded()
    return type(NS.IsWoWProLoaded) == "function" and NS.IsWoWProLoaded() or type(GetWoWPro()) == "table"
end

local function GetCurrentGuideID(WoWPro)
    local db = rawget(_G, "WoWProDB")
    local char = type(db) == "table" and db.char or nil
    local guideID = type(char) == "table" and char.currentguide or nil
    if type(guideID) == "string" and guideID ~= "" and type(WoWPro.Guides) == "table" and type(WoWPro.Guides[guideID]) == "table" then
        return guideID
    end
    return nil
end

local function IsGuideLoaded(WoWPro)
    return WoWPro and WoWPro.GuideLoaded ~= nil and WoWPro.GuideLoaded ~= false
end

local function GetVisibilityState()
    local WoWPro = GetWoWPro()
    if not IsLoaded() or type(WoWPro) ~= "table" or not GetCurrentGuideID(WoWPro) or not IsGuideLoaded(WoWPro) then
        return "absent"
    end
    local frame = WoWPro.MainFrame or WoWPro.GuideFrame
    if frame and type(frame.IsShown) == "function" then
        return frame:IsShown() and "visible" or "hidden"
    end
    return "visible"
end

local function GetCurrentStepIndex(WoWPro)
    if type(WoWPro.NextStepNotSticky) == "function" then
        local ok, stepIndex = pcall(WoWPro.NextStepNotSticky, tonumber(WoWPro.ActiveStep) or 1)
        if ok and tonumber(stepIndex) then
            return tonumber(stepIndex)
        end
    end
    return tonumber(WoWPro.ActiveStep)
end

local function ParseFirstCoordPair(coords)
    coords = TrimText(coords)
    if not coords or coords == "PLAYER" then
        return nil, nil
    end
    local first = coords:match("^%s*([^;]+)")
    if not first then
        return nil, nil
    end
    local sx = first:match("^%s*([^,|]+)")
    local sy = first:match(",%s*([^|]+)")
    local x = tonumber(sx)
    local y = tonumber(sy)
    if not x or not y or x < 0 or y < 0 or x > 100 or y > 100 then
        return nil, nil
    end
    return x / 100, y / 100
end

local function ResolvePlayerCoords(WoWPro)
    if type(WoWPro.GetPlayerZonePosition) ~= "function" then
        return nil, nil, nil
    end
    local ok, x, y, mapID = pcall(WoWPro.GetPlayerZonePosition, WoWPro)
    if ok and type(x) == "number" and type(y) == "number" and type(mapID) == "number" then
        return x, y, mapID
    end
    return nil, nil, nil
end

local function ResolveStepMapID(WoWPro, guideID, stepIndex)
    local zone = type(WoWPro.zone) == "table" and WoWPro.zone[stepIndex] or nil
    zone = zone or (WoWPro.Guides and WoWPro.Guides[guideID] and WoWPro.Guides[guideID].zone)
    local mapID = nil
    if zone and type(WoWPro.ValidZone) == "function" then
        local ok, _, resolvedMapID = pcall(WoWPro.ValidZone, WoWPro, zone)
        if ok and type(resolvedMapID) == "number" and resolvedMapID > 0 then
            mapID = resolvedMapID
        end
    end
    if type(mapID) ~= "number" and type(WoWPro.GetZoneText) == "function" then
        local ok, _, resolvedMapID = pcall(WoWPro.GetZoneText)
        if ok and type(resolvedMapID) == "number" and resolvedMapID > 0 then
            mapID = resolvedMapID
        end
    end
    return mapID
end

local function ExtractTarget()
    local WoWPro = GetWoWPro()
    if type(WoWPro) ~= "table" or not IsGuideLoaded(WoWPro) then
        return nil, true
    end

    local guideID = GetCurrentGuideID(WoWPro)
    local stepIndex = GetCurrentStepIndex(WoWPro)
    if not guideID or not stepIndex then
        return nil, true
    end

    local coords = type(WoWPro.map) == "table" and WoWPro.map[stepIndex] or nil
    local x, y, mapID
    if coords == "PLAYER" then
        x, y, mapID = ResolvePlayerCoords(WoWPro)
    else
        x, y = ParseFirstCoordPair(coords)
        mapID = ResolveStepMapID(WoWPro, guideID, stepIndex)
    end
    if type(mapID) ~= "number" or type(x) ~= "number" or type(y) ~= "number" then
        return nil, true
    end

    local presentation = type(Presentation) == "table"
        and type(Presentation.ResolveStep) == "function"
        and Presentation.ResolveStep(WoWPro, stepIndex)
        or nil
    local title = type(presentation) == "table" and presentation.title or nil
    local subtext = type(presentation) == "table" and presentation.subtext or nil
    local rawTitle = type(presentation) == "table" and presentation.rawTitle or nil
    local questID = type(presentation) == "table" and presentation.primaryQuestID or nil
    title = title or rawTitle or "WoWPro step"
    return {
        mapID = mapID,
        x = x,
        y = y,
        title = title,
        rawTitle = rawTitle or title,
        subtext = subtext,
        source = "wowpro.step#" .. tostring(stepIndex),
        kind = "guide_goal",
        guideProvider = PROVIDER,
        semanticKind = questID and "quest" or nil,
        semanticQuestID = questID,
        iconHintKind = questID and "quest" or nil,
        iconHintQuestID = questID,
    }, false
end

local function GetActivationToken()
    local WoWPro = GetWoWPro()
    if type(WoWPro) ~= "table" then
        return nil
    end
    return table.concat({
        tostring(GetCurrentGuideID(WoWPro) or "-"),
        tostring(GetCurrentStepIndex(WoWPro) or "-"),
    }, "\031", 1, 2)
end

local function HookFrameVisibility(WoWPro, schedule)
    local switchOpts = { allowProviderSwitch = true }
    local frames = { WoWPro.MainFrame, WoWPro.GuideFrame }
    for index = 1, #frames do
        local frame = frames[index]
        if frame and type(frame.HookScript) == "function" and not frame._awpWoWProVisibilityHooked then
            frame:HookScript("OnShow", function() schedule("WoWProFrameOnShow", switchOpts) end)
            frame:HookScript("OnHide", function() schedule("WoWProFrameOnHide") end)
            frame._awpWoWProVisibilityHooked = true
        end
    end
end

local function InstallHooks(schedule)
    local WoWPro = GetWoWPro()
    if type(WoWPro) ~= "table" then
        return
    end

    local switchOpts = { allowProviderSwitch = true }
    local function scheduleFor(reason, opts)
        return function()
            schedule(reason, opts)
            HookFrameVisibility(WoWPro, schedule)
        end
    end

    if type(WoWPro.UpdateGuideReal) == "function" then
        hooksecurefunc(WoWPro, "UpdateGuideReal", scheduleFor("WoWProUpdateGuideReal"))
    end
    if type(WoWPro.MapPoint) == "function" then
        hooksecurefunc(WoWPro, "MapPoint", function(_, row)
            schedule("WoWProMapPoint", { explicit = row ~= nil, allowProviderSwitch = true, reason = "WoWProMapPoint" })
            HookFrameVisibility(WoWPro, schedule)
        end)
    end
    if type(WoWPro.LoadGuide) == "function" then
        hooksecurefunc(WoWPro, "LoadGuide", scheduleFor("WoWProLoadGuide", switchOpts))
    end
    if type(WoWPro.CompleteStep) == "function" then
        hooksecurefunc(WoWPro, "CompleteStep", scheduleFor("WoWProCompleteStep"))
    end
    if type(WoWPro.AutoCompleteQuestUpdate) == "function" then
        hooksecurefunc(WoWPro, "AutoCompleteQuestUpdate", scheduleFor("WoWProAutoCompleteQuestUpdate"))
    end
    HookFrameVisibility(WoWPro, schedule)
end

local function FormatCoords(mapID, x, y)
    if type(mapID) ~= "number" or type(x) ~= "number" or type(y) ~= "number" then
        return "nil"
    end
    return string.format("%s@%.4f,%.4f", tostring(mapID), x, y)
end

local function GetDebugLines(genericLines)
    local lines = {}
    local WoWPro = GetWoWPro()
    if type(WoWPro) ~= "table" then
        lines[#lines + 1] = "provider=wowpro loaded=false"
        return lines
    end

    local guideID = GetCurrentGuideID(WoWPro)
    local stepIndex = GetCurrentStepIndex(WoWPro)
    local coords = type(WoWPro.map) == "table" and stepIndex and WoWPro.map[stepIndex] or nil
    local parsedX, parsedY = ParseFirstCoordPair(coords)
    local mapID = guideID and stepIndex and ResolveStepMapID(WoWPro, guideID, stepIndex) or nil
    local presentation = type(Presentation) == "table"
        and type(Presentation.ResolveStep) == "function"
        and stepIndex
        and Presentation.ResolveStep(WoWPro, stepIndex)
        or nil
    local okTarget, target, suppressed = pcall(ExtractTarget)
    if not okTarget then
        target = nil
        suppressed = true
    end

    lines[#lines + 1] = table.concat({
        "wowpro",
        "loaded=" .. tostring(IsLoaded()),
        "visibility=" .. tostring(GetVisibilityState()),
        "guide=" .. tostring(guideID or "-"),
        "guideLoaded=" .. tostring(IsGuideLoaded(WoWPro)),
        "activeStep=" .. tostring(WoWPro.ActiveStep or "-"),
        "step=" .. tostring(stepIndex or "-"),
        "zone=" .. tostring(type(WoWPro.zone) == "table" and stepIndex and WoWPro.zone[stepIndex] or "-"),
        "mapID=" .. tostring(mapID or "-"),
        "rawCoords=" .. tostring(coords or "-"),
        "parsed=" .. FormatCoords(mapID, parsedX, parsedY),
    }, " ")

    if type(presentation) == "table" then
        lines[#lines + 1] = table.concat({
            "wowproPresentation",
            "action=" .. tostring(presentation.action or "-"),
            "rawStep=" .. tostring(presentation.rawStep or "-"),
            "note=" .. tostring(presentation.rawNote or "-"),
            "questtext=" .. tostring(presentation.rawQuestText or "-"),
            "questIDs=" .. tostring(type(presentation.questIDs) == "table" and table.concat(presentation.questIDs, ",") or "-"),
            "primaryQuestID=" .. tostring(presentation.primaryQuestID or "-"),
            "primaryQuestSource=" .. tostring(presentation.primaryQuestSource or "-"),
            "titleSource=" .. tostring(presentation.titleSource or "-"),
            "subtextSource=" .. tostring(presentation.subtextSource or "-"),
        }, " ")
    end

    if type(target) == "table" then
        lines[#lines + 1] = table.concat({
            "wowproTarget",
            "title=" .. tostring(target.title),
            "subtext=" .. tostring(target.subtext),
            "source=" .. tostring(target.source),
            "coords=" .. FormatCoords(target.mapID, target.x, target.y),
            "questID=" .. tostring(target.semanticQuestID),
        }, " ")
    else
        lines[#lines + 1] = "wowproTarget=nil suppressed=" .. tostring(suppressed)
    end

    if type(genericLines) == "table" then
        for index = 1, #genericLines do
            lines[#lines + 1] = genericLines[index]
        end
    end
    return lines
end

NS.RegisterGuideTargetProvider(PROVIDER, {
    label = "WoWPro",
    displayName = "WoWPro",
    icon = "Interface\\AddOns\\WoWPro\\Textures\\TriRing.tga",
    iconTint = { r = 0.8, g = 0.78, b = 0.95, a = 1 },
    iconSize = 16,
    isLoaded = IsLoaded,
    getVisibilityState = GetVisibilityState,
    getActivationToken = GetActivationToken,
    extractTarget = ExtractTarget,
    getDebugLines = GetDebugLines,
    installHooks = InstallHooks,
})
