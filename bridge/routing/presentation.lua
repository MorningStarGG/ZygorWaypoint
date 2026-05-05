local NS = _G.AzerothWaypointNS
local state = NS.State

-- ============================================================
-- Presentation resolver
-- ============================================================
--
-- AWP's pushed snapshot must satisfy the existing native overlay and
-- diagnostics consumers. This keeps the push-driven model and
-- uses richer content snapshot fields they already understand.

local Signature = NS.Signature

local presentationScratch = {
    carrierTitle = nil,
    carrierStatus = nil,
    overlayTitle = nil,
    overlaySubtext = nil,
    pinpointSubtext = nil,
    iconHint = nil,
    specialAction = nil,
    carrierSig = nil,
    overlaySig = nil,
    sourceAddon = nil,
    guideProvider = nil,
    searchKind = nil,
    manualQuestID = nil,
    guideRoutePresentation = false,
    liveTravelType = nil,
    routeGoalMapID = nil,
    routeLegKind = nil,
    routeTravelType = nil,
    mapPinKind = nil,
    mapPinType = nil,
    mapPinID = nil,
    iconHintAtlas = nil,
    iconHintRawAtlas = nil,
    iconHintTextureIndex = nil,
    mapPinDescription = nil,
    mapPinIsCurrentEvent = nil,
    mapPinTooltipWidgetSet = nil,
    semanticKind = nil,
    semanticQuestID = nil,
    semanticTravelType = nil,
    iconHintKind = nil,
    iconHintQuestID = nil,
    mirrorTitle = nil,
    contentSig = nil,
}

local _contentSigParts = {}
local _finalContentSigParts = {}

local function TrimString(value)
    if type(value) ~= "string" then return nil end
    value = value:gsub("^%s+", ""):gsub("%s+$", "")
    if value == "" then return nil end
    return value
end

local function NormalizeCompareText(value)
    value = TrimString(value)
    if not value then return nil end
    value = value:lower()
    value = value:gsub("%s+", " ")
    return value
end

local function IsSameDisplayText(a, b)
    local left = NormalizeCompareText(a)
    local right = NormalizeCompareText(b)
    return left ~= nil and right ~= nil and left == right
end

local function NormalizeSourceAddon(sourceAddon)
    sourceAddon = TrimString(sourceAddon)
    if not sourceAddon then return nil end
    local externalSource = type(NS.NormalizeExternalWaypointSource) == "function"
        and NS.NormalizeExternalWaypointSource(sourceAddon)
        or nil
    if externalSource then
        return externalSource
    end
    return sourceAddon
end

local function ResolveGuideProvider(authority)
    if type(authority) == "table" then
        local provider = TrimString(authority.guideProvider)
            or TrimString(authority.provider)
        if provider then
            return provider
        end
    end

    local routing = state.routing or {}
    local activeProvider = type(NS.GetActiveGuideProvider) == "function" and TrimString(NS.GetActiveGuideProvider()) or nil
    if activeProvider then
        return activeProvider
    end
    local guideQueue = type(routing.guideQueue) == "table" and routing.guideQueue or nil
    return guideQueue and TrimString(guideQueue.provider) or nil
end

local function ResolveSemanticTravelType(action)
    if type(action) ~= "table" then
        return nil
    end
    if action.semanticKind == "portal"
        or action.semanticKind == "hearth"
        or action.semanticKind == "taxi"
        or action.semanticKind == "travel"
    then
        return action.semanticKind
    end
    if action.semanticKind == "spell"
        or action.semanticKind == "item"
        or action.semanticKind == "toy"
        or action.semanticKind == "macro"
    then
        return "travel"
    end
    return nil
end

local function ResolveCarrierTitle(action, carrier, authorityTitle)
    if type(action) == "table" and TrimString(action.name) then
        return TrimString(action.name)
    end
    if type(carrier) == "table" and TrimString(carrier.title) then
        return TrimString(carrier.title)
    end
    if TrimString(authorityTitle) then
        return TrimString(authorityTitle)
    end
    return "AWP Route"
end

local function ResolveOverlayTitle(action, carrier, authorityTitle, routeLegKind)
    if routeLegKind == "carrier" then
        return ResolveCarrierTitle(action, carrier, authorityTitle)
    end
    if type(action) == "table" and TrimString(action.destinationName) then
        return TrimString(action.destinationName)
    end
    if type(carrier) == "table"
        and carrier.routeLegKind == "carrier"
        and TrimString(carrier.title)
    then
        return TrimString(carrier.title)
    end
    if TrimString(authorityTitle) then
        return TrimString(authorityTitle)
    end
    if type(carrier) == "table" and TrimString(carrier.title) then
        return TrimString(carrier.title)
    end
    return nil
end

local function ResolveOverlaySubtext(action, overlayTitle, routeLegKind)
    if type(action) ~= "table" then
        return nil
    end

    if routeLegKind == "carrier" then
        local destinationName = TrimString(action.destinationName)
        if destinationName and not IsSameDisplayText(destinationName, overlayTitle) then
            return destinationName
        end
        return nil
    end

    local actionName = TrimString(action.name)
    if actionName
        and action.destinationName ~= nil
        and not IsSameDisplayText(actionName, overlayTitle)
    then
        return actionName
    end
    return nil
end

local function ResolveInstanceTravelIconOverride(liveTravelType, routeTravelType)
    if liveTravelType ~= "portal" then
        return liveTravelType
    end

    if NS.IsInstanceRouteTravelType(routeTravelType) then
        return routeTravelType
    end

    return liveTravelType
end

local function NormalizeRouteTravelType(routeTravelType, routeLegKind, plannerLegKind)
    local value = TrimString(routeTravelType)
    if value == "hearthstone" then
        return "hearth"
    end
    if value == "carrier"
        or value == "walk"
        or value == "fly"
        or value == "ship"
        or value == "zeppelin"
    then
        return "travel"
    end
    if value then
        return value
    end

    local plannerKind = TrimString(plannerLegKind)
    if routeLegKind == "carrier" then
        if plannerKind == "portal" or plannerKind == "taxi" then
            return plannerKind
        end
        if plannerKind == "hearthstone" then
            return "hearth"
        end
        return "travel"
    end
    return nil
end

local function ResolvePresentationIconHint(targetKind, snapshot, liveTravelType, liveTravelConfidence, searchKind, manualQuestID, mapPinInfo)
    if targetKind == "manual" then
        if type(manualQuestID) == "number" and manualQuestID > 0 then
            return "quest", manualQuestID
        end
        if type(mapPinInfo) == "table" and mapPinInfo.kind == "taxi_node" then
            return "taxi", nil
        end
        if type(mapPinInfo) == "table" and mapPinInfo.kind == "area_poi" then
            if type(NS.ResolveAreaPoiTravelType) == "function" then
                local travelType = NS.ResolveAreaPoiTravelType(
                    mapPinInfo.mapID,
                    mapPinInfo.x,
                    mapPinInfo.y,
                    mapPinInfo.mapPinID
                )
                if type(travelType) == "string" then
                    return travelType, nil
                end
            end
            return "area_poi", nil
        end
        if type(mapPinInfo) == "table" and mapPinInfo.kind == "dig_site" then
            return "dig_site", nil
        end
        if type(mapPinInfo) == "table" and mapPinInfo.kind == "housing_plot" then
            local ownerType = mapPinInfo.ownerType
            if ownerType == 3 then return "housing_plot_own", nil end
            if ownerType == 0 then return "housing_plot_unoccupied", nil end
            return "housing_plot_occupied", nil
        end
        return (type(searchKind) == "string" and searchKind or "manual"), nil
    end

    if targetKind == "corpse" then
        return "corpse", nil
    end

    if type(snapshot) ~= "table" then
        return nil, nil
    end

    local isCarrierTravelPresentation = targetKind == "route" or snapshot.routeLegKind == "carrier"
    local resolvedLiveTravelType = liveTravelConfidence == "high"
        and type(liveTravelType) == "string"
        and liveTravelType
        or nil
    local routeTravelType = type(snapshot.routeTravelType) == "string"
        and snapshot.routeTravelType
        or nil
    if isCarrierTravelPresentation then
        resolvedLiveTravelType = ResolveInstanceTravelIconOverride(resolvedLiveTravelType, routeTravelType)
        if type(resolvedLiveTravelType) == "string" then
            return resolvedLiveTravelType, nil
        end
    end

    local semanticQuestID = type(snapshot.semanticQuestID) == "number"
        and snapshot.semanticQuestID > 0
        and snapshot.semanticQuestID
        or nil
    if snapshot.semanticKind == "quest" and semanticQuestID then
        return "quest", semanticQuestID
    end

    local semanticTravelType = type(snapshot.semanticTravelType) == "string" and snapshot.semanticTravelType or nil
    if semanticTravelType then
        return semanticTravelType, nil
    end

    if targetKind == "guide" then
        return "guide", nil
    end

    return nil, nil
end

local function BuildFinalContentSig(snapshot)
    _finalContentSigParts[1] = tostring(snapshot.contentSig or "")
    _finalContentSigParts[2] = tostring(snapshot.guideRoutePresentation == true)
    _finalContentSigParts[3] = tostring(snapshot.iconHintKind or "")
    _finalContentSigParts[4] = tostring(snapshot.iconHintQuestID or "")
    _finalContentSigParts[5] = tostring(snapshot.iconHintAtlas or "")
    _finalContentSigParts[6] = tostring(snapshot.mapPinKind or "")
    _finalContentSigParts[7] = tostring(snapshot.mapPinID or "")
    _finalContentSigParts[8] = tostring(snapshot.sourceAddon or "")
    _finalContentSigParts[9] = tostring(snapshot.iconHintTextureIndex or "")
    _finalContentSigParts[10] = tostring(snapshot.guideProvider or "")
    return table.concat(_finalContentSigParts, "\031", 1, 10)
end

local function ResolveSnapshotContentSig(snapshot)
    _contentSigParts[1] = tostring(snapshot.guideRoutePresentation == true)
    _contentSigParts[2] = tostring(snapshot.liveTravelType or "")
    _contentSigParts[3] = tostring(snapshot.routeGoalMapID or "")
    _contentSigParts[4] = tostring(snapshot.routeLegKind or "")
    _contentSigParts[5] = tostring(snapshot.routeTravelType or "")
    _contentSigParts[6] = tostring(snapshot.sourceAddon or "")
    _contentSigParts[7] = tostring(snapshot.searchKind or "")
    _contentSigParts[8] = tostring(snapshot.manualQuestID or "")
    _contentSigParts[9] = tostring(snapshot.mapPinKind or "")
    _contentSigParts[10] = tostring(snapshot.mapPinID or "")
    _contentSigParts[11] = tostring(snapshot.semanticKind or "")
    _contentSigParts[12] = tostring(snapshot.semanticQuestID or "")
    _contentSigParts[13] = tostring(snapshot.semanticTravelType or "")
    _contentSigParts[14] = tostring(snapshot.pinpointSubtext or snapshot.overlaySubtext or "")
    _contentSigParts[15] = tostring(snapshot.guideProvider or "")
    return table.concat(_contentSigParts, "\031", 1, 15)
end

local function FillMapPinFields(snapshot, mapPinInfo)
    snapshot.mapPinKind = nil
    snapshot.mapPinType = nil
    snapshot.mapPinID = nil
    snapshot.iconHintAtlas = nil
    snapshot.iconHintRawAtlas = nil
    snapshot.iconHintTextureIndex = nil
    snapshot.mapPinDescription = nil
    snapshot.mapPinIsCurrentEvent = nil
    snapshot.mapPinTooltipWidgetSet = nil

    if type(mapPinInfo) ~= "table" then
        return
    end

    snapshot.mapPinKind = TrimString(mapPinInfo.kind)
    snapshot.mapPinType = type(mapPinInfo.mapPinType) == "number" and mapPinInfo.mapPinType or nil
    snapshot.mapPinID = type(mapPinInfo.mapPinID) == "number" and mapPinInfo.mapPinID or nil
    snapshot.iconHintAtlas = TrimString(mapPinInfo.atlas)
    snapshot.iconHintRawAtlas = TrimString(mapPinInfo.rawAtlas)
    snapshot.iconHintTextureIndex = type(mapPinInfo.textureIndex) == "number"
        and mapPinInfo.textureIndex > 0
        and mapPinInfo.textureIndex
        or nil
    snapshot.mapPinDescription = TrimString(mapPinInfo.description)
    snapshot.mapPinIsCurrentEvent = mapPinInfo.isCurrentEvent == true or nil
    snapshot.mapPinTooltipWidgetSet = type(mapPinInfo.tooltipWidgetSet) == "number"
        and mapPinInfo.tooltipWidgetSet
        or nil
end

local function ComputeOverlaySig(carrierSig, snapshot)
    local baseSig = carrierSig
    if type(baseSig) ~= "string" then
        return nil
    end
    return table.concat({
        baseSig,
        BuildFinalContentSig(snapshot),
        tostring(snapshot.mirrorTitle or snapshot.overlayTitle or ""),
        tostring(snapshot.overlaySubtext or ""),
    }, "\031", 1, 4)
end

local function ResolveGuideRouteSnapshot(authority, carrier, targetKind, routeLegKind, routeTravelType, rawArrowTitle)
    if type(carrier) ~= "table" or carrier.source ~= "guide" then
        return nil
    end
    local target = type(authority) == "table" and authority.target or nil
    local mapID = type(carrier.finalMapID) == "number" and carrier.finalMapID or target and target.mapID
    local x = type(carrier.finalX) == "number" and carrier.finalX or target and target.x
    local y = type(carrier.finalY) == "number" and carrier.finalY or target and target.y
    if type(mapID) ~= "number" or type(x) ~= "number" or type(y) ~= "number" then
        return nil
    end

    local provider = ResolveGuideProvider(authority)
    if provider ~= "zygor" or type(NS.ResolveGuideContentSnapshot) ~= "function" then
        local authoritySemanticQuestID = type(authority) == "table" and rawget(authority, "semanticQuestID") or nil
        local authorityIconHintQuestID = type(authority) == "table" and rawget(authority, "iconHintQuestID") or nil
        local targetSemanticQuestID = target and rawget(target, "semanticQuestID") or nil
        local targetIconHintQuestID = target and rawget(target, "iconHintQuestID") or nil
        local title = TrimString(target and target.title)
            or TrimString(authority and authority.title)
            or TrimString(rawArrowTitle)
            or TrimString(target and target.rawTitle)
            or "Guide step"
        local subtext = TrimString(authority and authority.subtext) or TrimString(target and target.subtext)
        return {
            mirrorTitle = title,
            overlayTitle = title,
            overlaySubtext = subtext,
            pinpointSubtext = subtext,
            guideProvider = provider,
            semanticKind = TrimString(authority and authority.semanticKind) or TrimString(target and target.semanticKind),
            semanticQuestID = type(authoritySemanticQuestID) == "number" and authoritySemanticQuestID
                or type(targetSemanticQuestID) == "number" and targetSemanticQuestID
                or nil,
            semanticTravelType = TrimString(authority and authority.semanticTravelType) or TrimString(target and target.semanticTravelType),
            iconHintKind = TrimString(authority and authority.iconHintKind) or TrimString(target and target.iconHintKind),
            iconHintQuestID = type(authorityIconHintQuestID) == "number" and authorityIconHintQuestID
                or type(targetIconHintQuestID) == "number" and targetIconHintQuestID
                or nil,
            routePresentationAllowed = true,
            contentSig = table.concat({
                tostring(provider or "guide"),
                tostring(mapID),
                tostring(type(x) == "number" and string.format("%.5f", x) or "-"),
                tostring(type(y) == "number" and string.format("%.5f", y) or "-"),
                tostring(title),
                tostring(subtext or ""),
            }, "\031", 1, 6),
        }
    end

    local snapshot = NS.ResolveGuideContentSnapshot({
        rawArrowTitle = rawArrowTitle,
        mapID = mapID,
        x = x,
        y = y,
        sig = carrier.sig,
        kind = targetKind,
        legKind = routeLegKind,
        routeTravelType = routeTravelType,
        source = type(authority) == "table" and authority.guideSource
            or target and target.source
            or carrier.source,
    })
    if type(snapshot) ~= "table" or snapshot.routePresentationAllowed == false then
        return nil
    end
    return snapshot
end

function NS.ResolvePresentation()
    local routing = state.routing or {}
    local carrier = routing.carrierState
    local action = routing.specialActionState
    local authority = carrier and carrier.source == "manual" and routing.manualAuthority
        or carrier and carrier.source == "guide" and (type(NS.GetActiveGuideRouteState) == "function" and NS.GetActiveGuideRouteState() or routing.guideRouteState)
        or nil

    if not carrier or not authority then
        for key in pairs(presentationScratch) do
            presentationScratch[key] = nil
        end
        presentationScratch.guideRoutePresentation = false
        return presentationScratch
    end

    local targetKind = carrier.kind or (carrier.source == "guide" and "guide" or "manual")
    local routeLegKind = carrier.routeLegKind
    local routeTravelType = NormalizeRouteTravelType(carrier.routeTravelType, routeLegKind, carrier.plannerLegKind)
    local authorityTitle = authority.title or (authority.target and authority.target.title) or nil
    local manualQuestID = carrier.source == "manual" and authority.manualQuestID or nil
    local searchKind = carrier.source == "manual" and authority.searchKind or nil
    local mapPinInfo = carrier.source == "manual" and authority.mapPinInfo or nil
    local semanticTravelType = ResolveSemanticTravelType(action)
    local isCarrierTravelPresentation = targetKind == "route" or routeLegKind == "carrier"
    local liveTravelType = semanticTravelType or (isCarrierTravelPresentation and routeTravelType or nil)
    local liveTravelConfidence = liveTravelType and "high" or nil
    local guideSnapshot = ResolveGuideRouteSnapshot(
        authority,
        carrier,
        targetKind,
        routeLegKind,
        routeTravelType,
        TrimString(authority.rawTitle) or TrimString(carrier.title) or TrimString(authorityTitle)
    )

    presentationScratch.carrierTitle = ResolveCarrierTitle(action, carrier, authorityTitle)
    presentationScratch.carrierStatus = nil
    presentationScratch.overlayTitle = ResolveOverlayTitle(action, carrier, authorityTitle, routeLegKind)
    presentationScratch.overlaySubtext = ResolveOverlaySubtext(action, presentationScratch.overlayTitle, routeLegKind)
    if guideSnapshot then
        local guideSubtext = TrimString(guideSnapshot.pinpointSubtext)
        if routeLegKind == "carrier" then
            if NS.IsInstanceRouteTravelType(routeTravelType) and guideSubtext then
                presentationScratch.overlaySubtext = guideSubtext
            end
        else
            presentationScratch.overlayTitle = TrimString(guideSnapshot.mirrorTitle) or presentationScratch.overlayTitle
            presentationScratch.overlaySubtext = guideSubtext or presentationScratch.overlaySubtext
        end
    end
    presentationScratch.pinpointSubtext = presentationScratch.overlaySubtext
    presentationScratch.iconHint = nil
    presentationScratch.specialAction = action
    presentationScratch.carrierSig = carrier.sig
    presentationScratch.overlaySig = nil
    presentationScratch.sourceAddon = NormalizeSourceAddon(authority.sourceAddon)
    presentationScratch.guideProvider = carrier.source == "guide" and ResolveGuideProvider(authority) or nil
    presentationScratch.searchKind = type(searchKind) == "string" and searchKind or nil
    presentationScratch.manualQuestID = type(manualQuestID) == "number" and manualQuestID > 0 and manualQuestID or nil
    presentationScratch.guideRoutePresentation = carrier.source == "guide"
    presentationScratch.liveTravelType = liveTravelConfidence == "high" and liveTravelType or nil
    presentationScratch.routeGoalMapID = carrier.finalMapID
    presentationScratch.routeLegKind = routeLegKind
    presentationScratch.routeTravelType = routeTravelType
    presentationScratch.semanticKind = type(action) == "table" and action.semanticKind
        or presentationScratch.manualQuestID and "quest"
        or nil
    presentationScratch.semanticQuestID = presentationScratch.manualQuestID
    presentationScratch.semanticTravelType = semanticTravelType
    if guideSnapshot then
        presentationScratch.semanticKind = TrimString(guideSnapshot.semanticKind) or presentationScratch.semanticKind
        presentationScratch.semanticQuestID = type(guideSnapshot.semanticQuestID) == "number"
            and guideSnapshot.semanticQuestID > 0
            and guideSnapshot.semanticQuestID
            or presentationScratch.semanticQuestID
        presentationScratch.semanticTravelType = TrimString(guideSnapshot.semanticTravelType)
            or presentationScratch.semanticTravelType
    end
    presentationScratch.mirrorTitle = presentationScratch.overlayTitle
    presentationScratch.carrierTitle = presentationScratch.overlayTitle or presentationScratch.carrierTitle

    FillMapPinFields(presentationScratch, mapPinInfo)

    presentationScratch.contentSig = ResolveSnapshotContentSig(presentationScratch)
    presentationScratch.iconHintKind, presentationScratch.iconHintQuestID = ResolvePresentationIconHint(
        targetKind,
        presentationScratch,
        presentationScratch.liveTravelType,
        liveTravelConfidence,
        presentationScratch.searchKind,
        presentationScratch.manualQuestID,
        mapPinInfo
    )
    presentationScratch.iconHint = presentationScratch.iconHintKind
    presentationScratch.overlaySig = ComputeOverlaySig(carrier.sig, presentationScratch)
    return presentationScratch
end
