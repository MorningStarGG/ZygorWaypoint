local NS = _G.ZygorWaypointNS
local M = NS.Internal.WorldOverlayNative
local overlay = M.overlay
local target = M.target
local arrival = M.arrival
local questIconCache = M.questIconCache
local questSubtextCache = M.questSubtextCache
local fontStringTextCache = M.fontStringTextCache
local _settings = M.settingsSnapshot
local CFG = M.Config
local GR = NS.Internal.GuideResolver

local GetPlayerWaypointDistance = NS.GetPlayerWaypointDistance

local BASE_SCALE_DISTANCE = CFG.BASE_SCALE_DISTANCE
local BASE_SCALE = CFG.BASE_SCALE
local ARRIVAL_ALPHA = CFG.ARRIVAL_ALPHA
local ARRIVAL_MIN_DELTA_TIME = CFG.ARRIVAL_MIN_DELTA_TIME
local ARRIVAL_MIN_SPEED = CFG.ARRIVAL_MIN_SPEED
local ARRIVAL_MIN_DELTA_DISTANCE = CFG.ARRIVAL_MIN_DELTA_DISTANCE
local ARRIVAL_MAX_SECONDS = CFG.ARRIVAL_MAX_SECONDS
local DISPLAY_DISTANCE_EPSILON = CFG.DISPLAY_DISTANCE_EPSILON
local DEFAULT_TINT = CFG.DEFAULT_TINT
local QUEST_COMPLETE_TINT = CFG.QUEST_COMPLETE_TINT
local ICON_PATH = CFG.ICON_PATH
local ICON_SPECS = CFG.ICON_SPECS
local QUEST_ICON_TYPE_DEFS = CFG.QUEST_ICON_TYPE_DEFS
local ResolveQuestTypeDetails = M.ResolveQuestTypeDetails
local ResolveQuestType = M.ResolveQuestType
local NormalizeText = GR.NormalizeText
local FormatCoordinateSubtext = GR.FormatCoordinateSubtext
local IsGoalVisible = GR.IsGoalVisible
local GetCurrentGoalQuestID = GR.GetGoalQuestID
local GetGoalCoords = GR.GetGoalCoords
local GetCurrentGoalAction = GR.GetGoalAction

-- ============================================================
-- Math utilities
-- ============================================================

local function GetScaleForDistance(distance, minScale, maxScale)
    if type(distance) ~= "number" or distance <= 0 then
        return maxScale
    end

    local rawScale = BASE_SCALE * (BASE_SCALE_DISTANCE / distance)
    if rawScale < minScale then
        return minScale
    end
    if rawScale > maxScale then
        return maxScale
    end
    return rawScale
end

local function Clamp01(value)
    if value <= 0 then
        return 0
    end
    if value >= 1 then
        return 1
    end
    return value
end

local function Lerp(a, b, t)
    return a + ((b - a) * Clamp01(t))
end

local function EaseInExpo(value)
    value = Clamp01(value)
    if value == 0 or value == 1 then
        return value
    end
    return 2 ^ (10 * value - 10)
end

local function EaseOutCubic(value)
    value = Clamp01(value)
    return 1 - (1 - value) ^ 3
end

local function EaseInOutExpo(value)
    value = Clamp01(value)
    if value == 0 or value == 1 then
        return value
    end
    if value < 0.5 then
        return (2 ^ (20 * value - 10)) * 0.5
    end
    return (2 - (2 ^ (-20 * value + 10))) * 0.5
end

-- ============================================================
-- Goal resolution
-- ============================================================

local function GetCurrentGoal()
    local Z = NS.ZGV()
    local step = Z and Z.CurrentStep
    if not step or type(step.goals) ~= "table" then
        return nil, step
    end

    local canonical      = NS.ResolveCanonicalGuideGoal(step)
    local currentGoalNum = canonical and canonical.canonicalGoalNum
    if type(currentGoalNum) == "number" then
        local currentGoal = step.goals[currentGoalNum]
        if currentGoal then
            return currentGoal, step
        end
    end

    for _, goal in ipairs(step.goals) do
        if IsGoalVisible(goal) then
            return goal, step
        end
    end

    return nil, step
end

local function IsTravelSemanticGoal(goal)
    if type(goal) ~= "table" then
        return false
    end

    local action = GetCurrentGoalAction(goal)
    if action == "fly" or action == "fpath" or action == "ontaxi" or action == "offtaxi" then
        return true
    end

    return goal.waypoint_notravel == true
end

-- ============================================================
-- Icon resolution
-- ============================================================

local function NormalizeQuestIconSourceValue(value)
    if type(value) ~= "string" or value == "" then
        return nil
    end

    return value
end

local function NormalizeQuestIconSize(value)
    if type(value) ~= "number" or value <= 0 then
        return nil
    end

    return math.floor(value + 0.5)
end

local function NormalizeQuestIconOffset(value)
    local numberValue = tonumber(value)
    if not numberValue then
        return nil
    end

    return numberValue
end

local function GetQuestIconTint(typeDef, stateDef, statusPrefix)
    if type(stateDef) == "table" and type(stateDef.tint) == "table" then
        return stateDef.tint, stateDef.tintKey
    end

    if type(typeDef) == "table" and type(typeDef.tint) == "table" then
        return typeDef.tint, typeDef.tintKey
    end

    if statusPrefix == "Complete" then
        return QUEST_COMPLETE_TINT, "QUEST_COMPLETE_TINT"
    end

    return DEFAULT_TINT, "DEFAULT_TINT"
end

local function GetQuestIconTintCacheKey(tint, tintKey)
    if type(tintKey) == "string" and tintKey ~= "" then
        return tintKey
    end

    if type(tint) ~= "table" then
        return "DEFAULT_TINT"
    end

    return string.format(
        "%.4f:%.4f:%.4f:%.4f",
        tint.r or 1,
        tint.g or 1,
        tint.b or 1,
        tint.a or 1
    )
end

local function GetQuestWaypointTextTint(typeDef, stateDef)
    if type(stateDef) == "table" and type(stateDef.waypointTextTint) == "table" then
        return stateDef.waypointTextTint, stateDef.waypointTextTintKey
    end

    if type(typeDef) == "table" and type(typeDef.waypointTextTint) == "table" then
        return typeDef.waypointTextTint, typeDef.waypointTextTintKey
    end

    return nil, nil
end

local function GetQuestIconOffset(typeDef, stateDef, key)
    if type(key) ~= "string" or key == "" then
        return nil
    end

    local stateValue = type(stateDef) == "table" and NormalizeQuestIconOffset(stateDef[key]) or nil
    if stateValue ~= nil then
        return stateValue
    end

    return type(typeDef) == "table" and NormalizeQuestIconOffset(typeDef[key]) or nil
end

local function GetQuestIconSize(typeDef, stateDef)
    local stateValue = type(stateDef) == "table" and NormalizeQuestIconSize(stateDef.iconSize) or nil
    if stateValue ~= nil then
        return stateValue
    end

    return type(typeDef) == "table" and NormalizeQuestIconSize(typeDef.iconSize) or nil
end

local function GetQuestIconRecolor(typeDef, stateDef)
    if type(stateDef) == "table" and type(stateDef.recolor) == "boolean" then
        return stateDef.recolor
    end

    if type(typeDef) == "table" and type(typeDef.recolor) == "boolean" then
        return typeDef.recolor
    end

    return false
end

local _questIconCacheKeyParts = {}

local function BuildQuestIconSpec(typeKey, statusPrefix)
    if type(typeKey) ~= "string" or type(statusPrefix) ~= "string" then
        return nil
    end

    local requestedTypeKey = typeKey
    local questTypeDefs = type(QUEST_ICON_TYPE_DEFS) == "table" and QUEST_ICON_TYPE_DEFS or nil
    if type(questTypeDefs) ~= "table" then
        return nil
    end

    local typeDef = questTypeDefs[requestedTypeKey]
    local resolvedTypeKey = requestedTypeKey
    local familyMode = "requested-family"
    if type(typeDef) ~= "table" then
        resolvedTypeKey = "Default"
        typeDef = questTypeDefs[resolvedTypeKey]
        familyMode = "default-family-fallback"
    end
    if type(typeDef) ~= "table" then
        return nil
    end

    local stateDefs = type(typeDef.states) == "table" and typeDef.states or nil
    local stateDef = stateDefs and stateDefs[statusPrefix] or nil
    if type(stateDef) ~= "table" then
        stateDef = nil
    end

    local suffix = type(typeDef.suffix) == "string" and typeDef.suffix or ""
    local generatedIconKey = statusPrefix .. suffix .. "Quest"
    local explicitAtlas = stateDef and NormalizeQuestIconSourceValue(stateDef.atlas) or nil
    local explicitTexture = stateDef and NormalizeQuestIconSourceValue(stateDef.texture) or nil
    local hasExplicitSource = explicitAtlas ~= nil or explicitTexture ~= nil
    local iconKey = NormalizeQuestIconSourceValue(stateDef and stateDef.key) or generatedIconKey
    local resolvedTint, resolvedTintKey = GetQuestIconTint(typeDef, stateDef, statusPrefix)
    local resolvedWaypointTextTint, resolvedWaypointTextTintKey = GetQuestWaypointTextTint(typeDef, stateDef)
    local iconOffsetX = GetQuestIconOffset(typeDef, stateDef, "iconOffsetX")
    local iconOffsetY = GetQuestIconOffset(typeDef, stateDef, "iconOffsetY")
    local recolor = GetQuestIconRecolor(typeDef, stateDef)
    local iconSize = GetQuestIconSize(typeDef, stateDef)
    local sourceMode = hasExplicitSource and "state-override" or "legacy-suffix"
    _questIconCacheKeyParts[1] = tostring(requestedTypeKey)
    _questIconCacheKeyParts[2] = tostring(resolvedTypeKey)
    _questIconCacheKeyParts[3] = tostring(statusPrefix)
    _questIconCacheKeyParts[4] = tostring(iconKey)
    _questIconCacheKeyParts[5] = tostring(explicitAtlas or "")
    _questIconCacheKeyParts[6] = tostring(explicitTexture or "")
    _questIconCacheKeyParts[7] = tostring(GetQuestIconTintCacheKey(resolvedTint, resolvedTintKey))
    _questIconCacheKeyParts[8] = tostring(
        resolvedWaypointTextTint and GetQuestIconTintCacheKey(resolvedWaypointTextTint, resolvedWaypointTextTintKey)
        or ""
    )
    _questIconCacheKeyParts[9] = tostring(iconOffsetX or "")
    _questIconCacheKeyParts[10] = tostring(iconOffsetY or "")
    _questIconCacheKeyParts[11] = tostring(recolor)
    _questIconCacheKeyParts[12] = tostring(iconSize or "")
    _questIconCacheKeyParts[13] = tostring(sourceMode)
    _questIconCacheKeyParts[14] = tostring(familyMode)
    local cacheKey = table.concat(_questIconCacheKeyParts, "\031", 1, 14)
    local spec = questIconCache[cacheKey]
    if not spec then
        spec = {
            atlas = explicitAtlas,
            texture = explicitTexture or (ICON_PATH .. generatedIconKey),
            tint = resolvedTint,
            tintKey = resolvedTintKey,
            waypointTextTint = resolvedWaypointTextTint,
            waypointTextTintKey = resolvedWaypointTextTintKey,
            iconOffsetX = iconOffsetX,
            iconOffsetY = iconOffsetY,
            key = iconKey,
            recolor = recolor,
            iconSize = iconSize,
            typeKey = resolvedTypeKey,
            statusPrefix = statusPrefix,
            sourceMode = sourceMode,
            familyMode = familyMode,
            requestedTypeKey = requestedTypeKey,
            resolvedTypeKey = resolvedTypeKey,
        }
        questIconCache[cacheKey] = spec
    end

    return spec
end

local function GetQuestIconSpec(questID)
    if type(questID) ~= "number" then
        return nil
    end

    local details = ResolveQuestTypeDetails and ResolveQuestTypeDetails(questID) or nil
    local typeKey = details and details.typeKey or nil
    local statusPrefix = details and details.statusPrefix or nil
    if type(typeKey) ~= "string" or type(statusPrefix) ~= "string" then
        typeKey, statusPrefix = ResolveQuestType(questID)
    end

    return BuildQuestIconSpec(typeKey, statusPrefix)
end

local function GetCurrentGoalQuestIconForTarget(targetMapID, targetX, targetY)
    local goal = GetCurrentGoal()
    if IsTravelSemanticGoal(goal) then
        return nil
    end

    local questID = GetCurrentGoalQuestID(goal)
    if type(questID) ~= "number" then
        return nil
    end

    local goalMapID, goalX, goalY = GetGoalCoords(goal)
    if type(goalMapID) ~= "number" or type(goalX) ~= "number" or type(goalY) ~= "number" then
        return nil
    end
    if type(targetMapID) ~= "number" or type(targetX) ~= "number" or type(targetY) ~= "number" then
        return nil
    end
    if goalMapID ~= targetMapID then
        return nil
    end

    local epsilon = 1e-5
    if math.abs(goalX - targetX) > epsilon or math.abs(goalY - targetY) > epsilon then
        return nil
    end

    return GetQuestIconSpec(questID)
end

local _cachedExplicitTravelKind, _cachedExplicitTravelSource, _cachedExplicitTravelTitle, _cachedExplicitTravelNpcid, _cachedExplicitTravelResult

local function DetectExplicitTravelType(kind, source, title)
    local goal = GetCurrentGoal()
    local npcid = type(goal) == "table" and goal.npcid or nil

    if kind == _cachedExplicitTravelKind and source == _cachedExplicitTravelSource and title == _cachedExplicitTravelTitle and npcid == _cachedExplicitTravelNpcid then
        return _cachedExplicitTravelResult
    end

    local result

    if kind == "corpse" then
        result = "corpse"
    elseif kind == "manual" then
        result = "manual"
    end

    if not result then
        local action = GetCurrentGoalAction(goal)
        local goalMapID = type(goal) == "table" and goal.mapID or nil
        local goalX = type(goal) == "table" and goal.x or nil
        local goalY = type(goal) == "table" and goal.y or nil
        if action == "fly" or action == "fpath" then
            result = "taxi"
        elseif action == "home" then
            result = "inn"
        elseif action == "hearth" then
            result = "hearth"
        else
            local lowerSource = type(source) == "string" and source:lower() or ""
            local sourceTitle = lowerSource:find("destinationwaypoint", 1, true) and "portal" or nil
            result = sourceTitle or NS.ClassifyTravelSemantics(action, npcid, goalMapID, goalX, goalY, title, nil)
        end
    end

    _cachedExplicitTravelKind = kind
    _cachedExplicitTravelSource = source
    _cachedExplicitTravelTitle = title
    _cachedExplicitTravelNpcid = npcid
    _cachedExplicitTravelResult = result
    return result
end

local _cachedTravelKind, _cachedTravelSource, _cachedTravelTitle, _cachedTravelContentSig, _cachedTravelResult

local function ResolveInstanceTravelTypeOverride(contentSnapshot, travelType)
    if travelType ~= "portal" or type(contentSnapshot) ~= "table" then
        return travelType
    end

    local routeTravelType = type(contentSnapshot.routeTravelType) == "string" and contentSnapshot.routeTravelType or nil
    if routeTravelType == "dungeon" or routeTravelType == "raid" or routeTravelType == "delve" then
        return routeTravelType
    end

    return travelType
end

local function DetectTravelType(kind, source, title, contentSnapshot)
    local liveTravelType = type(contentSnapshot) == "table"
        and type(contentSnapshot.liveTravelType) == "string"
        and contentSnapshot.liveTravelType
        or nil
    local contentSig = type(contentSnapshot) == "table" and contentSnapshot.contentSig or nil
    if kind == _cachedTravelKind
        and source == _cachedTravelSource
        and title == _cachedTravelTitle
        and contentSig == _cachedTravelContentSig
    then
        return _cachedTravelResult
    end

    local result = ResolveInstanceTravelTypeOverride(contentSnapshot, liveTravelType)
    if not result then
        result = DetectExplicitTravelType(kind, source, title)
    end

    _cachedTravelKind = kind
    _cachedTravelSource = source
    _cachedTravelTitle = title
    _cachedTravelContentSig = contentSig
    _cachedTravelResult = result
    return result
end

local function GetHearthIconSpec()
    local hearthIcon = select(5, C_Item.GetItemInfoInstant(6948))
    if hearthIcon then
        local spec = ICON_SPECS.hearth
        spec.texture = hearthIcon
        return spec
    end
    return ICON_SPECS.travel
end

local function IsGuideRoutePresentation(contentSnapshot)
    return type(contentSnapshot) == "table" and contentSnapshot.guideRoutePresentation == true
end

local function ResolveTravelIconSpec(travelType)
    if travelType == "taxi" then
        return ICON_SPECS.taxi
    end
    if travelType == "inn" then
        return ICON_SPECS.inn
    end
    if travelType == "dungeon" then
        return ICON_SPECS.dungeon
    end
    if travelType == "raid" then
        return ICON_SPECS.raid
    end
    if travelType == "delve" then
        return ICON_SPECS.delve
    end
    if travelType == "hearth" then
        return GetHearthIconSpec()
    end
    if travelType == "portal" then
        return ICON_SPECS.portal
    end
    if travelType == "travel" then
        return ICON_SPECS.travel
    end

    return nil
end

local function ResolveSourceAddonIconSpec(contentSnapshot)
    if type(contentSnapshot) ~= "table" then
        return nil
    end

    local sourceAddon = type(contentSnapshot.sourceAddon) == "string" and contentSnapshot.sourceAddon or nil
    if sourceAddon == "silverdragon" then
        return ICON_SPECS.silverdragon
    end
    if sourceAddon == "rarescanner" then
        return ICON_SPECS.rarescanner
    end

    return nil
end

local function ResolveSnapshotIconSpec(contentSnapshot)
    if type(contentSnapshot) ~= "table" then
        return nil
    end

    local iconHintKind = type(contentSnapshot.iconHintKind) == "string" and contentSnapshot.iconHintKind or nil
    local travelIcon = ResolveTravelIconSpec(iconHintKind)
    if travelIcon then
        return travelIcon
    end

    local iconHintQuestID = type(contentSnapshot.iconHintQuestID) == "number"
        and contentSnapshot.iconHintQuestID > 0
        and contentSnapshot.iconHintQuestID
        or nil

    if iconHintKind == "quest" and iconHintQuestID then
        local questIcon = GetQuestIconSpec(iconHintQuestID)
        if questIcon then
            return questIcon
        end
    end

    if iconHintKind == "guide" then
        return ICON_SPECS.guide
    end

    if iconHintKind == "manual" then
        return ICON_SPECS.manual
    end

    if iconHintKind == "corpse" then
        return ICON_SPECS.corpse
    end

    return nil
end

local function ResolveIconSpec(kind, source, title, contentSnapshotOverride, targetMapID, targetX, targetY)
    local contentSnapshot = contentSnapshotOverride or target.contentSnapshot or overlay.contentSnapshot
    local snapshotIcon = ResolveSnapshotIconSpec(contentSnapshot)
    if kind == "corpse" then
        return ICON_SPECS.corpse
    end

    if kind == "guide" or (kind == "route" and IsGuideRoutePresentation(contentSnapshot)) then
        if snapshotIcon then
            return snapshotIcon
        end
        return ICON_SPECS.guide
    end

    local travelType = DetectTravelType(kind, source, title, contentSnapshot)

    -- Route nodes can briefly survive after travel steps. If the active
    -- native target already matches the current quest goal, prefer the
    -- quest icon over the generic navigation glyph.
    if kind == "route" then
        if snapshotIcon then
            return snapshotIcon
        end
        local goalQuestIcon = GetCurrentGoalQuestIconForTarget(
            targetMapID or target.mapID,
            targetX or target.x,
            targetY or target.y
        )
        if goalQuestIcon then
            return goalQuestIcon
        end
    end

    local travelIcon = ResolveTravelIconSpec(travelType)
    if travelIcon then
        return travelIcon
    end

    local sourceAddonIcon = ResolveSourceAddonIconSpec(contentSnapshot)
    if sourceAddonIcon and (kind == "manual" or kind == "route") then
        return sourceAddonIcon
    end

    if kind == "manual" then
        if snapshotIcon then
            return snapshotIcon
        end
        local npcSpec = type(contentSnapshot) == "table"
            and type(contentSnapshot.iconHintKind) == "string"
            and ICON_SPECS[contentSnapshot.iconHintKind]
        if npcSpec then return npcSpec end
        return ICON_SPECS.manual
    end

    local questIcon = GetQuestIconSpec(GetCurrentGoalQuestID(GetCurrentGoal()))
    if questIcon then
        return questIcon
    end

    if kind == "route" then
        return ICON_SPECS.travel
    end

    return ICON_SPECS.guide
end

-- ============================================================
-- Distance and arrival
-- ============================================================

local function FormatDistance(distanceYards)
    if type(distanceYards) ~= "number" then
        return nil
    end

    if _settings.worldOverlayUseMeters then
        local meters = distanceYards * 0.9144
        if meters >= 1000 then
            return string.format("%.1f km", meters / 1000)
        end
        return string.format("%d m", meters + 0.5)
    end

    if distanceYards >= 1760 then
        return string.format("%.1f mi", distanceYards / 1760)
    end
    return string.format("%d yd", distanceYards + 0.5)
end

local function FormatArrival(seconds)
    if type(seconds) ~= "number" or seconds < 0 then
        return nil
    end

    local hours = math.floor(seconds / 3600)
    local minutes = math.floor((seconds % 3600) / 60)
    local secs = math.floor(seconds % 60)
    if hours > 0 then
        return string.format("%d:%02d:%02d", hours, minutes, secs)
    end
    return string.format("%d:%02d", minutes, secs)
end

local function GetDistanceDisplayKey(distanceYards)
    if type(distanceYards) ~= "number" then
        return nil, nil
    end

    if _settings.worldOverlayUseMeters then
        local meters = distanceYards * 0.9144
        if meters >= 1000 then
            return "km", math.floor((meters / 1000) * 10 + DISPLAY_DISTANCE_EPSILON)
        end
        return "m", math.floor(meters + DISPLAY_DISTANCE_EPSILON)
    end

    if distanceYards >= 1760 then
        return "mi", math.floor((distanceYards / 1760) * 10 + DISPLAY_DISTANCE_EPSILON)
    end
    return "yd", math.floor(distanceYards + DISPLAY_DISTANCE_EPSILON)
end

local function SetCachedFontStringText(fontString, text)
    if not fontString then
        return
    end

    local nextText = text or ""
    if fontStringTextCache[fontString] ~= nextText then
        fontString:SetText(nextText)
        fontStringTextCache[fontString] = nextText
    end
end

local function UpdateDistanceFontString(footer, fontString, distanceYards)
    local unitKey, valueKey = GetDistanceDisplayKey(distanceYards)
    if not unitKey or type(valueKey) ~= "number" then
        if footer then
            footer.__zwpDistanceUnitKey = nil
            footer.__zwpDistanceValueKey = nil
        end
        SetCachedFontStringText(fontString, "")
        return false
    end

    if footer
        and footer.__zwpDistanceUnitKey == unitKey
        and footer.__zwpDistanceValueKey == valueKey
    then
        return true
    end

    if unitKey == "km" then
        fontString:SetFormattedText("%.1f km", valueKey / 10)
    elseif unitKey == "m" then
        fontString:SetFormattedText("%d m", valueKey)
    elseif unitKey == "mi" then
        fontString:SetFormattedText("%.1f mi", valueKey / 10)
    else
        fontString:SetFormattedText("%d yd", valueKey)
    end

    if footer then
        footer.__zwpDistanceUnitKey = unitKey
        footer.__zwpDistanceValueKey = valueKey
    end
    return true
end

local function UpdateArrivalFontString(footer, fontString, seconds)
    local valueKey = (type(seconds) == "number" and seconds >= 0) and math.floor(seconds) or nil
    if valueKey == nil then
        if footer then
            footer.__zwpArrivalSecondsKey = nil
        end
        SetCachedFontStringText(fontString, "")
        return false
    end

    if footer and footer.__zwpArrivalSecondsKey == valueKey then
        return true
    end

    local hours = math.floor(valueKey / 3600)
    local minutes = math.floor((valueKey % 3600) / 60)
    local secs = math.floor(valueKey % 60)
    if hours > 0 then
        fontString:SetFormattedText("%d:%02d:%02d", hours, minutes, secs)
    else
        fontString:SetFormattedText("%d:%02d", minutes, secs)
    end
    if footer then
        footer.__zwpArrivalSecondsKey = valueKey
    end
    return true
end

local function ResetArrivalState()
    arrival.seconds = -1
    arrival.lastDistance = nil
    arrival.lastTime = nil
    arrival.averageSpeed = nil
end

local function UpdateArrivalState(distance)
    if type(distance) ~= "number" then
        ResetArrivalState()
        return
    end

    if distance <= 0 then
        arrival.seconds = 0
        arrival.lastDistance = nil
        arrival.lastTime = nil
        arrival.averageSpeed = nil
        return
    end

    -- Skip when distance is unchanged (throttled cached value) to avoid
    -- resetting arrival.seconds on ticks where no fresh reading exists.
    if distance == arrival.lastDistance then
        return
    end

    local now = GetTime()
    if not arrival.lastDistance then
        arrival.lastDistance = distance
        arrival.lastTime = now
        return
    end

    local deltaTime = now - (arrival.lastTime or now)
    if deltaTime < ARRIVAL_MIN_DELTA_TIME then
        return
    end

    local deltaDistance = (arrival.lastDistance or distance) - distance
    arrival.lastDistance = distance
    arrival.lastTime = now

    if deltaDistance <= 0 then
        arrival.seconds = -1
        return
    end
    if deltaDistance < ARRIVAL_MIN_DELTA_DISTANCE then
        return
    end

    local instantSpeed = deltaDistance / deltaTime
    arrival.averageSpeed = arrival.averageSpeed and
    (arrival.averageSpeed + ARRIVAL_ALPHA * (instantSpeed - arrival.averageSpeed)) or instantSpeed
    if not arrival.averageSpeed or arrival.averageSpeed <= ARRIVAL_MIN_SPEED then
        arrival.seconds = -1
        return
    end

    local seconds = math.floor(distance / arrival.averageSpeed + 0.5)
    arrival.seconds = (seconds <= ARRIVAL_MAX_SECONDS) and seconds or -1
end

local DISTANCE_THROTTLE_INTERVAL = 0.15
M.cachedDistanceTime = 0

local function GetTargetDistance()
    local now = GetTime()
    if M.cachedDistance and (now - M.cachedDistanceTime) < DISTANCE_THROTTLE_INTERVAL then
        return M.cachedDistance
    end

    local distance
    if target.mapID and target.x and target.y then
        distance = GetPlayerWaypointDistance(target.mapID, target.x, target.y)
        if type(distance) == "number" and distance > 0 then
            M.cachedDistance = distance
            M.cachedDistanceTime = now
            return distance
        end
    end

    if C_SuperTrack.IsSuperTrackingUserWaypoint() then
        distance = C_Navigation.GetDistance()
        if type(distance) == "number" and distance > 0 then
            M.cachedDistance = distance
            M.cachedDistanceTime = now
            return distance
        end
    end

    M.cachedDistance = nil
    M.cachedDistanceTime = now
end

-- ============================================================
-- Content resolution
-- ============================================================

local function NormalizeQuestSubtext(text)
    if type(text) ~= "string" then
        return nil
    end

    text = text:gsub("%s+", " "):gsub("^%s+", ""):gsub("%s+$", "")
    if text == "" then
        return nil
    end

    return text
end

local function GetQuestBackedManualQuestID(contentSnapshot)
    local questID = type(contentSnapshot) == "table" and contentSnapshot.manualQuestID or nil
    if type(questID) == "number" and questID > 0 then
        return questID
    end

    return nil
end

local function ResolveQuestBackedManualSubtext(questID)
    if type(questID) ~= "number" then
        return nil
    end

    local cachedEntry = type(questSubtextCache) == "table" and questSubtextCache[questID] or nil
    if type(cachedEntry) == "table" then
        return cachedEntry.text
    end

    local resolvedText = nil
    if type(C_QuestLog) == "table" then
        if type(C_QuestLog.ReadyForTurnIn) == "function" and C_QuestLog.ReadyForTurnIn(questID) == true then
            resolvedText = "Ready to turn in"
        elseif type(C_QuestLog.GetQuestObjectives) == "function" then
            local objectives = C_QuestLog.GetQuestObjectives(questID)
            if type(objectives) == "table" then
                for _, objective in ipairs(objectives) do
                    if type(objective) == "table" and objective.finished ~= true then
                        local objectiveText = objective.text or rawget(objective, "description")
                        resolvedText = NormalizeQuestSubtext(objectiveText)
                        if resolvedText then
                            break
                        end
                    end
                end
            end
        end
    end

    if type(questSubtextCache) == "table" then
        questSubtextCache[questID] = { text = resolvedText }
    end

    return resolvedText
end

local function GetTargetSubtext()
    if target.kind == "corpse" then
        return nil
    end

    local contentSnapshot = target.contentSnapshot or overlay.contentSnapshot
    local manualQuestID = GetQuestBackedManualQuestID(contentSnapshot)
    if manualQuestID and (target.kind == "manual" or target.kind == "route") then
        local questSubtext = ResolveQuestBackedManualSubtext(manualQuestID)
        if questSubtext then
            return questSubtext
        end

        if target.mapID and target.x and target.y
            and (target.kind == "manual" or _settings.worldOverlayShowCoordinateFallback)
        then
            return FormatCoordinateSubtext(target.x, target.y)
        end
        return nil
    end

    if target.kind == "manual" then
        if target.mapID and target.x and target.y then
            return FormatCoordinateSubtext(target.x, target.y)
        end
        return nil
    end

    if target.kind == "guide" or (target.kind == "route" and IsGuideRoutePresentation(contentSnapshot)) then
        if type(contentSnapshot) == "table" then
            return contentSnapshot.pinpointSubtext
        end
        if _settings.worldOverlayShowCoordinateFallback and target.mapID and target.x and target.y then
            return FormatCoordinateSubtext(target.x, target.y)
        end
        return nil
    end

    -- Route nodes should not inherit generic guide-step subtext. Only the
    -- guide-backed snapshot path above is allowed to surface resolver text.
    if target.kind == "route" then
        return nil
    end

    if _settings.worldOverlayShowCoordinateFallback and target.mapID and target.x and target.y then
        return FormatCoordinateSubtext(target.x, target.y)
    end

    return nil
end

local function ApplyTextureSpec(texture, spec)
    if not texture then
        return
    end

    if spec and spec.atlas then
        texture:SetAtlas(spec.atlas, true)
    else
        texture:SetTexture(spec and spec.texture or nil)
        texture:SetTexCoord(0, 1, 0, 1)
    end

    local tint = spec and spec.tint or DEFAULT_TINT
    texture:SetVertexColor(tint.r or 1, tint.g or 1, tint.b or 1, tint.a or 1)
end

local function SetIconTexture(texture, spec, forceRecolor, tintOverride)
    if not texture then
        return
    end

    if spec and spec.atlas then
        -- Keep the icon at the layout-managed size instead of letting atlas
        -- metadata overwrite it. The context icon style owns sizing.
        texture:SetAtlas(spec.atlas, false, true)
    else
        texture:SetTexture(spec and spec.texture or nil)
        texture:SetTexCoord(0, 1, 0, 1)
    end

    local recolor
    if forceRecolor == nil then
        recolor = spec and spec.recolor == true
    else
        recolor = forceRecolor == true
    end
    texture:SetDesaturated(recolor)
    if recolor then
        local tint = tintOverride or spec and spec.tint or DEFAULT_TINT
        texture:SetVertexColor(tint.r or 1, tint.g or 1, tint.b or 1, tint.a or 1)
    else
        texture:SetVertexColor(1, 1, 1, 1)
    end
end

M.GetScaleForDistance = GetScaleForDistance
M.Clamp01 = Clamp01
M.Lerp = Lerp
M.EaseInExpo = EaseInExpo
M.EaseInOutExpo = EaseInOutExpo
M.EaseOutCubic = EaseOutCubic
M.NormalizeText = NormalizeText
M.BuildQuestIconSpec = BuildQuestIconSpec

function M.InvalidateQuestSubtextCache(questID)
    if type(questSubtextCache) ~= "table" then
        return
    end

    if type(questID) == "number" and questID > 0 then
        questSubtextCache[questID] = nil
        return
    end

    for cachedQuestID in pairs(questSubtextCache) do
        questSubtextCache[cachedQuestID] = nil
    end
end

M.DetectTravelType = DetectTravelType
M.IsGuideRoutePresentation = IsGuideRoutePresentation
M.ResolveTravelIconSpec = ResolveTravelIconSpec
M.ResolveIconSpec = ResolveIconSpec
M.FormatDistance = FormatDistance
M.FormatArrival = FormatArrival
M.GetDistanceDisplayKey = GetDistanceDisplayKey
M.SetCachedFontStringText = SetCachedFontStringText
M.UpdateDistanceFontString = UpdateDistanceFontString
M.UpdateArrivalFontString = UpdateArrivalFontString
M.ResetArrivalState = ResetArrivalState
M.UpdateArrivalState = UpdateArrivalState
M.GetTargetDistance = GetTargetDistance
M.GetTargetSubtext = GetTargetSubtext
M.ApplyTextureSpec = ApplyTextureSpec
M.SetIconTexture = SetIconTexture
