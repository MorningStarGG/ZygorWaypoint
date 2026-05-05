local NS = _G.AzerothWaypointNS
local C = NS.Constants
local M = NS.Internal.WorldOverlay
local overlay = M.overlay
local target = M.target
local arrival = M.arrival
local questIconCache = M.questIconCache
local questSubtextCache = M.questSubtextCache
local fontStringTextCache = M.fontStringTextCache
local _settings = M.settingsSnapshot
local CFG = M.Config
local GR = type(NS.Internal.GuideResolver) == "table" and NS.Internal.GuideResolver or nil

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
local COLOR_PRESETS = C.WORLD_OVERLAY_COLOR_PRESETS
local AREA_POI_ICON_OVERRIDES = CFG.AREA_POI_ICON_OVERRIDES
local VIGNETTE_ICON_OVERRIDES = CFG.VIGNETTE_ICON_OVERRIDES
local GOSSIP_ICON_FALLBACK_KEY = CFG.GOSSIP_ICON_FALLBACK_KEY
local GOSSIP_ICON_DEFAULTS = CFG.GOSSIP_ICON_DEFAULTS
local GOSSIP_ICON_TYPE_DEFS = CFG.GOSSIP_ICON_TYPE_DEFS
local QUEST_ICON_TYPE_DEFS = CFG.QUEST_ICON_TYPE_DEFS
local ResolveQuestTypeDetails = M.ResolveQuestTypeDetails
local ResolveQuestType = M.ResolveQuestType

local function NormalizeTextFallback(value)
    if type(NS.NormalizeWaypointTitle) == "function" then
        return NS.NormalizeWaypointTitle(value)
    end
    if value == nil then
        return nil
    end
    value = tostring(value)
    value = value:gsub("[\r\n]+", " ")
    value = value:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "")
    value = value:gsub("%s+", " "):gsub("^%s+", ""):gsub("%s+$", "")
    return value ~= "" and value or nil
end

local function FormatCoordinateSubtextFallback(x, y)
    if type(x) ~= "number" or type(y) ~= "number" then
        return nil
    end
    return string.format("x: %.1f, y: %.1f", x * 100, y * 100)
end

local function IsGoalVisibleFallback(goal)
    if type(goal) ~= "table" then
        return false
    end
    if type(goal.IsVisible) ~= "function" then
        return true
    end
    local ok, visible = pcall(goal.IsVisible, goal)
    if not ok then
        return true
    end
    return visible ~= false
end

local function GetGoalQuestIDFallback(goal)
    if type(goal) ~= "table" then
        return nil
    end
    local quest = type(goal.quest) == "table" and goal.quest or nil
    return tonumber(goal.questid or (quest and (quest.id or quest.questid)) or 0) or nil
end

local function GetGoalCoordsFallback(goal)
    if type(goal) ~= "table" then
        return nil, nil, nil
    end
    local mapID = goal.map or goal.mapid or goal.mapID
    local x = goal.x
    local y = goal.y
    if type(mapID) == "number" and type(x) == "number" and type(y) == "number" then
        return mapID, x, y
    end
    return nil, nil, nil
end

local function GetGoalActionFallback(goal)
    if type(goal) ~= "table" then
        return nil
    end
    return type(goal.action) == "string" and goal.action or nil
end

local function GetGuideResolverFunction(key)
    if type(GR) ~= "table" then
        return nil
    end
    local fn = GR[key]
    return type(fn) == "function" and fn or nil
end

local NormalizeText = GetGuideResolverFunction("NormalizeText") or NormalizeTextFallback
local FormatCoordinateSubtext = GetGuideResolverFunction("FormatCoordinateSubtext") or FormatCoordinateSubtextFallback
local IsGoalVisible = GetGuideResolverFunction("IsGoalVisible") or IsGoalVisibleFallback
local GetCurrentGoalQuestID = GetGuideResolverFunction("GetGoalQuestID") or GetGoalQuestIDFallback
local GetGoalCoords = GetGuideResolverFunction("GetGoalCoords") or GetGoalCoordsFallback
local GetCurrentGoalAction = GetGuideResolverFunction("GetGoalAction") or GetGoalActionFallback

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

    local canonical = type(NS.ResolveCanonicalGuideGoal) == "function" and NS.ResolveCanonicalGuideGoal(step) or nil
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
    if type(stateDef) == "table" then
        local stateTint = stateDef.waypointTextTint
        if type(stateTint) == "table" or COLOR_PRESETS[stateTint] then
            return stateTint, stateDef.waypointTextTintKey
        end
    end

    if type(typeDef) == "table" then
        local typeTint = typeDef.waypointTextTint
        if type(typeTint) == "table" or COLOR_PRESETS[typeTint] then
            return typeTint, typeDef.waypointTextTintKey
        end
    end

    return nil, nil
end

local function GetQuestWaypointTextTintCacheKey(tint, tintKey)
    if type(tint) == "string" then
        return tintKey or tint
    end
    return GetQuestIconTintCacheKey(tint, tintKey)
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
local _cachedQuestIconQuestID, _cachedQuestIconTypeKey, _cachedQuestIconStatusPrefix, _cachedQuestIconSpec

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
        resolvedWaypointTextTint and GetQuestWaypointTextTintCacheKey(resolvedWaypointTextTint, resolvedWaypointTextTintKey)
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
    if _cachedQuestIconQuestID == questID
        and _cachedQuestIconTypeKey == typeKey
        and _cachedQuestIconStatusPrefix == statusPrefix
    then
        return _cachedQuestIconSpec
    end

    local spec = BuildQuestIconSpec(typeKey, statusPrefix)
    _cachedQuestIconQuestID = questID
    _cachedQuestIconTypeKey = typeKey
    _cachedQuestIconStatusPrefix = statusPrefix
    _cachedQuestIconSpec = spec
    return spec
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
local _cachedAreaPoiIconKey, _cachedAreaPoiIconSpec
local _areaPoiIconCacheKeyParts = {}

local function NormalizeAreaPoiOverrideKey(value)
    if type(value) ~= "string" or value == "" then
        return nil
    end

    return value
end

local function ResolveAreaPoiIconOverride(mapPinID, atlas, texture, textureIndex)
    local overrides = type(AREA_POI_ICON_OVERRIDES) == "table" and AREA_POI_ICON_OVERRIDES or nil
    if not overrides then
        return nil
    end

    local byID = type(overrides.byID) == "table" and overrides.byID or nil
    if byID and type(mapPinID) == "number" and type(byID[mapPinID]) == "table" then
        return byID[mapPinID]
    end

    local byTextureIndex = type(overrides.byTextureIndex) == "table" and overrides.byTextureIndex or nil
    if byTextureIndex and type(textureIndex) == "number" and type(byTextureIndex[textureIndex]) == "table" then
        return byTextureIndex[textureIndex]
    end

    local byAtlas = type(overrides.byAtlas) == "table" and overrides.byAtlas or nil
    local atlasKey = NormalizeAreaPoiOverrideKey(atlas)
    local atlasOverride = byAtlas and atlasKey and byAtlas[atlasKey] or nil
    if type(atlasOverride) == "table" then
        return atlasOverride
    end

    local byTexture = type(overrides.byTexture) == "table" and overrides.byTexture or nil
    local textureKey = NormalizeAreaPoiOverrideKey(texture)
    local textureOverride = byTexture and textureKey and byTexture[textureKey] or nil
    if type(textureOverride) == "table" then
        return textureOverride
    end
end

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
            result = sourceTitle or NS.ClassifyTravelSemantics(action, goalMapID, goalX, goalY, title, nil)
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
local _loggedUnknownTargetKinds = {}

local function ResolveInstanceTravelTypeOverride(contentSnapshot, travelType)
    if travelType ~= "portal" or type(contentSnapshot) ~= "table" then
        return travelType
    end

    local routeTravelType = type(contentSnapshot.routeTravelType) == "string" and contentSnapshot.routeTravelType or nil
    if routeTravelType == "dungeon" or routeTravelType == "raid" or routeTravelType == "delve" or routeTravelType == "bountiful_delve" then
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

local function IsCarrierRouteLeg(contentSnapshot)
    return type(contentSnapshot) == "table" and contentSnapshot.routeLegKind == "carrier"
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
    if travelType == "bountiful_delve" then
        return ICON_SPECS.bountiful_delve
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
    if travelType == "carrier"
        or travelType == "walk"
        or travelType == "fly"
        or travelType == "ship"
        or travelType == "zeppelin"
    then
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

local function ResolveVignetteIconOverride(atlas)
    local overrides = type(VIGNETTE_ICON_OVERRIDES) == "table" and VIGNETTE_ICON_OVERRIDES or nil
    if not overrides then
        return nil
    end
    local byAtlas = type(overrides.byAtlas) == "table" and overrides.byAtlas or nil
    local atlasOverride = byAtlas and type(atlas) == "string" and byAtlas[atlas] or nil
    if type(atlasOverride) == "table" then
        return atlasOverride
    end
end

local _cachedVignetteIconKey = nil
local _cachedVignetteIconSpec = nil
local _cachedGossipIconTypeKey = nil
local _cachedGossipIconSpec = nil
local _queueIconCache = {}
local _queueIconCacheOrder = {}
local _queueIconCacheLimit = 256
local _queueIconCacheKeyParts = {}
local _queueIconSnapshot = {}
local GOSSIP_ICON_OVERRIDE_FIELDS = {
    "atlas",
    "texture",
    "texCoords",
    "tint",
    "tintKey",
    "waypointTextTint",
    "waypointTextTintKey",
    "recolor",
    "iconSize",
    "iconOffsetX",
    "iconOffsetY",
    "iconSizeMode",
    "iconOffsetMode",
}

local function ResolveVignetteIconSpec(contentSnapshot)
    if type(contentSnapshot) ~= "table" then
        return nil
    end
    if contentSnapshot.iconHintKind ~= "vignette" then
        return nil
    end
    local atlas = type(contentSnapshot.iconHintAtlas) == "string" and contentSnapshot.iconHintAtlas or nil
    local fallback = ICON_SPECS.vignette
    if not atlas or atlas == (fallback and fallback.atlas) then
        return fallback
    end
    local override = ResolveVignetteIconOverride(atlas)
    local cacheKey = atlas .. "\031" .. tostring(override and override.key or "")
    if cacheKey == _cachedVignetteIconKey and _cachedVignetteIconSpec then
        return _cachedVignetteIconSpec
    end
    local spec = {}
    if type(fallback) == "table" then
        for k, v in pairs(fallback) do
            spec[k] = v
        end
    end
    spec.atlas = atlas
    if type(override) == "table" then
        for k, v in pairs(override) do
            spec[k] = v
        end
        spec.atlas = type(override.atlas) == "string" and override.atlas or atlas
    end
    local overrideHasSize = type(override) == "table" and override.iconSize ~= nil
    if not overrideHasSize then
        local defaultSize = type(VIGNETTE_ICON_OVERRIDES) == "table" and VIGNETTE_ICON_OVERRIDES.defaultSize or nil
        if defaultSize then
            spec.iconSize = defaultSize
        end
    end
    spec.key = "vignette:" .. atlas
    _cachedVignetteIconKey = cacheKey
    _cachedVignetteIconSpec = spec
    return spec
end

local function ResolveAreaPoiIconSpec(contentSnapshot)
    if type(contentSnapshot) ~= "table" then
        return nil
    end

    local iconHintKind = type(contentSnapshot.iconHintKind) == "string" and contentSnapshot.iconHintKind or nil
    local mapPinKind = type(contentSnapshot.mapPinKind) == "string" and contentSnapshot.mapPinKind or nil
    if iconHintKind and iconHintKind ~= "area_poi" then
        return nil
    end
    if iconHintKind ~= "area_poi" and mapPinKind ~= "area_poi" then
        return nil
    end

    local textureIndex = type(contentSnapshot.iconHintTextureIndex) == "number"
        and contentSnapshot.iconHintTextureIndex > 0
        and contentSnapshot.iconHintTextureIndex
        or nil
    local fallback = ICON_SPECS.area_poi or ICON_SPECS.manual
    local rawAtlas = type(contentSnapshot.iconHintAtlas) == "string" and contentSnapshot.iconHintAtlas ~= ""
        and contentSnapshot.iconHintAtlas
        or nil
    -- When there's a textureIndex but no atlas, skip the fallback atlas so the
    -- textureIndex path handles the icon instead of the fallback placeholder.
    local atlas = rawAtlas
        or (not textureIndex and fallback and fallback.atlas)
        or nil
    local texture = atlas == nil and not textureIndex and fallback and fallback.texture or nil
    local mapPinID = type(contentSnapshot.mapPinID) == "number" and contentSnapshot.mapPinID or 0
    local override = ResolveAreaPoiIconOverride(mapPinID, atlas, texture, textureIndex)
    _areaPoiIconCacheKeyParts[1] = tostring(mapPinID)
    _areaPoiIconCacheKeyParts[2] = tostring(atlas or "")
    _areaPoiIconCacheKeyParts[3] = tostring(texture or "")
    _areaPoiIconCacheKeyParts[4] = tostring(override and override.key or "")
    _areaPoiIconCacheKeyParts[5] = tostring(override and override.iconSize or "")
    _areaPoiIconCacheKeyParts[6] = tostring(override and override.iconOffsetX or "")
    _areaPoiIconCacheKeyParts[7] = tostring(override and override.iconOffsetY or "")
    _areaPoiIconCacheKeyParts[8] = tostring(override and override.iconSizeMode or "")
    _areaPoiIconCacheKeyParts[9] = tostring(override and override.iconOffsetMode or "")
    _areaPoiIconCacheKeyParts[10] = tostring(textureIndex or "")
    local cacheKey = table.concat(_areaPoiIconCacheKeyParts, "\031", 1, 10)

    if cacheKey == _cachedAreaPoiIconKey and _cachedAreaPoiIconSpec then
        return _cachedAreaPoiIconSpec
    end

    local spec = {}
    if type(fallback) == "table" then
        for key, value in pairs(fallback) do
            spec[key] = value
        end
    end

    spec.atlas = atlas
    spec.texture = texture
    spec.texCoords = nil
    if type(override) == "table" then
        for key, value in pairs(override) do
            spec[key] = value
        end
        spec.atlas = type(override.atlas) == "string" and override.atlas or atlas
        spec.texture = type(override.texture) == "string" and override.texture or texture
    end

    if textureIndex and not spec.atlas then
        local x1, x2, y1, y2 = C_Minimap.GetPOITextureCoords(textureIndex)
        if x1 then
            spec.texture = "Interface/Minimap/POIIcons"
            spec.texCoords = { x1, x2, y1, y2 }
        end
    end

    local isFallbackAtlas = atlas == nil or (type(fallback) == "table" and atlas == fallback.atlas)
    local overrideHasSize = type(override) == "table" and override.iconSize ~= nil
    -- For atlas-based POIs that aren't using the fallback placeholder, apply the
    -- top-level defaultSize when no per-entry override specified a size.
    if not isFallbackAtlas and not overrideHasSize then
        local defaultSize = type(AREA_POI_ICON_OVERRIDES) == "table" and AREA_POI_ICON_OVERRIDES.defaultSize or nil
        if defaultSize then
            spec.iconSize = defaultSize
        end
    end
    -- For textureIndex POIs, apply byTextureIndex.defaultSize when no per-entry
    -- override specified a size. The specific [index] entry wins over the default.
    if textureIndex and not overrideHasSize then
        local byTI = type(AREA_POI_ICON_OVERRIDES) == "table"
            and type(AREA_POI_ICON_OVERRIDES.byTextureIndex) == "table"
            and AREA_POI_ICON_OVERRIDES.byTextureIndex
            or nil
        local tiDefaultSize = byTI and type(byTI.defaultSize) == "number" and byTI.defaultSize or nil
        if tiDefaultSize then
            spec.iconSize = tiDefaultSize
        end
    end

    local iconSig = rawAtlas or (textureIndex and ("idx:" .. textureIndex)) or texture or "fallback"
    spec.key = "area_poi:" .. tostring(mapPinID) .. ":" .. iconSig
    _cachedAreaPoiIconKey = cacheKey
    _cachedAreaPoiIconSpec = spec
    return spec
end

local function GetGossipFallbackIconSpec()
    local fallbackKey = type(GOSSIP_ICON_FALLBACK_KEY) == "string"
        and GOSSIP_ICON_FALLBACK_KEY ~= ""
        and GOSSIP_ICON_FALLBACK_KEY
        or "gossip_poi"
    local configuredFallback = ICON_SPECS[fallbackKey]
    if configuredFallback then
        return configuredFallback
    end

    local fallbackSpec = ICON_SPECS.gossip_poi or ICON_SPECS.manual
    if type(fallbackSpec) ~= "table" then
        return nil
    end

    local spec = {}
    for key, value in pairs(fallbackSpec) do
        spec[key] = value
    end

    if fallbackKey:find("[/\\]") then
        spec.atlas = nil
        spec.texture = fallbackKey
    else
        spec.atlas = fallbackKey
        spec.texture = nil
    end
    spec.key = fallbackKey
    return spec
end

local function IsDerivedGossipTypeKey(typeKey)
    return type(typeKey) == "string" and typeKey:sub(1, 7) == "gossip_"
end

local function CloneGossipIconOverrideValue(value)
    if type(value) ~= "table" then
        return value
    end

    local copy = {}
    for key, nestedValue in pairs(value) do
        copy[key] = nestedValue
    end
    return copy
end

local _cachedGuideProviderKey = nil
local _cachedGuideProviderSpec = nil
local _cachedGuideProviderRevision = nil

local function NormalizeProviderKey(provider)
    if type(provider) ~= "string" then
        return nil
    end
    provider = provider:gsub("^%s+", ""):gsub("%s+$", "")
    if provider == "" then
        return nil
    end
    return provider:lower()
end

local function ResolveRegisteredGuideProviderIconSpec(providerKey)
    if type(NS.GetGuideProviderInfo) ~= "function" then
        return nil
    end

    local info = NS.GetGuideProviderInfo(providerKey)
    if type(info) ~= "table" then
        return nil
    end

    local texture = type(info.texture) == "string" and info.texture
        or type(info.icon) == "string" and info.icon
        or nil
    local atlas = type(info.atlas) == "string" and info.atlas or nil
    if not texture and not atlas then
        return nil
    end

    local spec = {}
    local base = ICON_SPECS.guide
    if type(base) == "table" then
        for key, value in pairs(base) do
            spec[key] = CloneGossipIconOverrideValue(value)
        end
    end

    spec.key = providerKey .. "_guide"
    if atlas then
        spec.atlas = atlas
        spec.texture = nil
    else
        spec.texture = texture
        spec.atlas = nil
    end
    spec.tint = type(info.iconTint) == "table" and CloneGossipIconOverrideValue(info.iconTint)
        or type(info.tint) == "table" and CloneGossipIconOverrideValue(info.tint)
        or spec.tint
    spec.tintKey = type(info.tintKey) == "string" and info.tintKey or spec.tintKey
    spec.iconSize = type(info.iconSize) == "number" and info.iconSize or spec.iconSize
    spec.iconOffsetX = type(info.iconOffsetX) == "number" and info.iconOffsetX or spec.iconOffsetX
    spec.iconOffsetY = type(info.iconOffsetY) == "number" and info.iconOffsetY or spec.iconOffsetY
    spec.recolor = info.recolor == true or spec.recolor
    return spec
end

local function ResolveGuideIconSpec(contentSnapshot)
    local providerKey = type(contentSnapshot) == "table"
        and NormalizeProviderKey(contentSnapshot.guideProvider)
        or nil
    if not providerKey then
        return ICON_SPECS.guide
    end

    local revision = type(NS.GetGuideProviderRegistryRevision) == "function"
        and NS.GetGuideProviderRegistryRevision()
        or 0
    if providerKey == _cachedGuideProviderKey
        and revision == _cachedGuideProviderRevision
    then
        return _cachedGuideProviderSpec
    end

    local spec = ICON_SPECS[providerKey .. "_guide"]
        or ResolveRegisteredGuideProviderIconSpec(providerKey)
        or ICON_SPECS.guide

    _cachedGuideProviderKey = providerKey
    _cachedGuideProviderSpec = spec
    _cachedGuideProviderRevision = revision
    return spec
end

local function ApplyGossipIconOverrides(spec, overrides)
    if type(spec) ~= "table" or type(overrides) ~= "table" then
        return spec
    end

    for _, field in ipairs(GOSSIP_ICON_OVERRIDE_FIELDS) do
        if overrides[field] ~= nil then
            spec[field] = CloneGossipIconOverrideValue(overrides[field])
        end
    end

    return spec
end

local function ResolveGossipIconSpec(typeKey)
    if type(typeKey) ~= "string" or typeKey == "" then
        return nil
    end
    if typeKey == _cachedGossipIconTypeKey then
        return _cachedGossipIconSpec
    end

    local resolved
    local fallbackKey = type(GOSSIP_ICON_FALLBACK_KEY) == "string"
        and GOSSIP_ICON_FALLBACK_KEY ~= ""
        and GOSSIP_ICON_FALLBACK_KEY
        or "gossip_poi"
    local defaults = type(GOSSIP_ICON_DEFAULTS) == "table" and GOSSIP_ICON_DEFAULTS or nil
    local defs = type(GOSSIP_ICON_TYPE_DEFS) == "table" and GOSSIP_ICON_TYPE_DEFS or nil
    local typeDef = defs and defs[typeKey] or nil
    local isKnownGossipType = typeKey == fallbackKey or IsDerivedGossipTypeKey(typeKey) or type(typeDef) == "table"
    if not isKnownGossipType then
        _cachedGossipIconTypeKey = typeKey
        _cachedGossipIconSpec = nil
        return nil
    end
    local baseIconKey = fallbackKey
    local directBaseOverride = false

    if type(typeDef) == "table" then
        local iconKey = type(typeDef.iconKey) == "string" and typeDef.iconKey ~= "" and typeDef.iconKey or nil
        if iconKey then
            baseIconKey = iconKey
        end
    end

    if type(baseIconKey) == "string" and baseIconKey ~= "" then
        resolved = ICON_SPECS[baseIconKey]
        if not resolved and baseIconKey ~= fallbackKey then
            resolved = ICON_SPECS[fallbackKey]
            baseIconKey = fallbackKey
        end
        if not resolved and (typeKey == fallbackKey or IsDerivedGossipTypeKey(typeKey) or type(typeDef) == "table") then
            resolved = GetGossipFallbackIconSpec()
            directBaseOverride = type(resolved) == "table" and resolved.key == fallbackKey and ICON_SPECS[fallbackKey] == nil
        end
    end

    if type(resolved) == "table" then
        if directBaseOverride then
            local directSpec = resolved
            resolved = {}
            for key, value in pairs(directSpec) do
                resolved[key] = CloneGossipIconOverrideValue(value)
            end
        else
            local baseSpec = resolved
            resolved = {}
            for key, value in pairs(baseSpec) do
                resolved[key] = CloneGossipIconOverrideValue(value)
            end
        end
        ApplyGossipIconOverrides(resolved, defaults)
        ApplyGossipIconOverrides(resolved, typeDef)
        resolved.key = typeKey
    end

    _cachedGossipIconTypeKey = typeKey
    _cachedGossipIconSpec = resolved
    return resolved
end

local function ResolveSnapshotIconSpec(contentSnapshot)
    if type(contentSnapshot) ~= "table" then
        return nil
    end

    local areaPoiIcon = ResolveAreaPoiIconSpec(contentSnapshot)
    if areaPoiIcon then
        return areaPoiIcon
    end

    local vignetteIcon = ResolveVignetteIconSpec(contentSnapshot)
    if vignetteIcon then
        return vignetteIcon
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
        return ResolveGuideIconSpec(contentSnapshot)
    end

    if iconHintKind == "manual" then
        return ICON_SPECS.manual
    end

    if iconHintKind == "corpse" then
        return ICON_SPECS.corpse
    end

    local gossipIcon = ResolveGossipIconSpec(iconHintKind)
    if gossipIcon then
        return gossipIcon
    end

    local hintedSpec = iconHintKind and ICON_SPECS[iconHintKind]
    if hintedSpec then
        return hintedSpec
    end

    return nil
end

local function TrimIconString(value)
    if type(value) ~= "string" then
        return nil
    end
    value = value:gsub("^%s+", ""):gsub("%s+$", "")
    if value == "" then
        return nil
    end
    return value
end

local function ResolveQueueIconQuestTypeKey(questID)
    if type(questID) ~= "number" or questID <= 0 then
        return nil, nil
    end
    local details = ResolveQuestTypeDetails and ResolveQuestTypeDetails(questID) or nil
    local typeKey = details and details.typeKey or nil
    local statusPrefix = details and details.statusPrefix or nil
    if type(typeKey) ~= "string" or type(statusPrefix) ~= "string" then
        typeKey, statusPrefix = ResolveQuestType(questID)
    end
    return typeKey, statusPrefix
end

local function GetQueueIconManualQuestID(record, meta, identity)
    local questID = type(record) == "table" and record.manualQuestID or nil
    if type(questID) == "number" and questID > 0 then
        return questID
    end
    questID = type(record) == "table"
        and record.iconHintKind == "quest"
        and type(record.iconHintQuestID) == "number"
        and record.iconHintQuestID
        or nil
    if type(questID) == "number" and questID > 0 then
        return questID
    end
    questID = type(record) == "table"
        and record.semanticKind == "quest"
        and type(record.semanticQuestID) == "number"
        and record.semanticQuestID
        or nil
    if type(questID) == "number" and questID > 0 then
        return questID
    end
    questID = type(meta) == "table" and meta.manualQuestID or nil
    if type(questID) == "number" and questID > 0 then
        return questID
    end
    questID = type(identity) == "table" and (identity.questID or identity.completionQuestID) or nil
    if type(questID) == "number" and questID > 0 then
        return questID
    end
    return nil
end

local function FillQueueIconMapPinSnapshot(snapshot, mapPinInfo)
    if type(mapPinInfo) ~= "table" then
        return
    end
    snapshot.mapPinKind = TrimIconString(mapPinInfo.kind)
    snapshot.mapPinType = type(mapPinInfo.mapPinType) == "number" and mapPinInfo.mapPinType or nil
    snapshot.mapPinID = type(mapPinInfo.mapPinID) == "number" and mapPinInfo.mapPinID or nil
    snapshot.iconHintAtlas = TrimIconString(mapPinInfo.atlas)
    snapshot.iconHintRawAtlas = TrimIconString(mapPinInfo.rawAtlas)
    snapshot.iconHintTextureIndex = type(mapPinInfo.textureIndex) == "number"
        and mapPinInfo.textureIndex > 0
        and mapPinInfo.textureIndex
        or nil
    snapshot.mapPinIsCurrentEvent = mapPinInfo.isCurrentEvent == true or nil
    snapshot.mapPinTooltipWidgetSet = type(mapPinInfo.tooltipWidgetSet) == "number"
        and mapPinInfo.tooltipWidgetSet
        or nil
end

local function ResolveQueueIconHintKind(record, meta, identity, mapPinInfo, manualQuestID, opts)
    local routeTravelType = TrimIconString(record and record.liveTravelType)
        or TrimIconString(record and record.semanticTravelType)
        or TrimIconString(record and record.routeTravelType)
    local routeLegKind = TrimIconString(record and record.routeLegKind)
    local entryType = TrimIconString(record and record.entryType)
    if routeLegKind == "carrier" or entryType == "travel" then
        return ResolveTravelIconSpec(routeTravelType) and routeTravelType or "travel"
    end

    if type(manualQuestID) == "number" and manualQuestID > 0 then
        return "quest"
    end

    local explicitHint = TrimIconString(record and record.iconHintKind)
    if explicitHint then
        return explicitHint
    end
    local semanticKind = TrimIconString(record and record.semanticKind)
    if semanticKind then
        return semanticKind
    end

    local mapPinKind = TrimIconString(mapPinInfo and mapPinInfo.kind)
    if mapPinKind == "taxi_node" then
        return "taxi"
    end
    if mapPinKind == "area_poi" then
        return "area_poi"
    end
    if mapPinKind == "dig_site" then
        return "dig_site"
    end
    if mapPinKind == "housing_plot" then
        local ownerType = mapPinInfo.ownerType
        if ownerType == 3 then return "housing_plot_own" end
        if ownerType == 0 then return "housing_plot_unoccupied" end
        return "housing_plot_occupied"
    end

    local identityKind = TrimIconString(identity and identity.kind)
    if identityKind == "vignette" then
        return "vignette"
    end
    if identityKind == "gossip_poi" then
        return TrimIconString(meta and meta.searchKind) or "gossip_poi"
    end
    if identityKind == "zygor_poi" then
        return TrimIconString(meta and meta.searchKind) or "zygor_poi"
    end

    return TrimIconString(meta and meta.searchKind)
        or TrimIconString(record and record.searchKind)
        or (type(opts) == "table" and TrimIconString(opts.source) == "guide" and "guide")
        or "manual"
end

local function BuildQueueIconCacheKey(record, opts)
    record = type(record) == "table" and record or {}
    opts = type(opts) == "table" and opts or {}
    local meta = type(record.meta) == "table" and record.meta or type(opts.meta) == "table" and opts.meta or nil
    local identity = type(meta) == "table" and type(meta.identity) == "table" and meta.identity or nil
    local mapPinInfo = type(record.mapPinInfo) == "table" and record.mapPinInfo
        or type(meta) == "table" and type(meta.mapPinInfo) == "table" and meta.mapPinInfo
        or nil
    local manualQuestID = GetQueueIconManualQuestID(record, meta, identity)
    local questTypeKey, questStatusPrefix = ResolveQueueIconQuestTypeKey(manualQuestID)

    _queueIconCacheKeyParts[1] = tostring(opts.kind or "")
    _queueIconCacheKeyParts[2] = tostring(record.entryType or "")
    _queueIconCacheKeyParts[3] = tostring(record.routeLegKind or "")
    _queueIconCacheKeyParts[4] = tostring(record.routeTravelType or "")
    _queueIconCacheKeyParts[5] = tostring(record.plannerLegKind or "")
    _queueIconCacheKeyParts[6] = tostring(record.sourceAddon or meta and meta.sourceAddon or identity and identity.sourceAddon or "")
    _queueIconCacheKeyParts[7] = tostring(record.searchKind or meta and meta.searchKind or "")
    _queueIconCacheKeyParts[8] = tostring(manualQuestID or "")
    _queueIconCacheKeyParts[9] = tostring(questTypeKey or "")
    _queueIconCacheKeyParts[10] = tostring(questStatusPrefix or "")
    _queueIconCacheKeyParts[11] = tostring(identity and identity.kind or "")
    _queueIconCacheKeyParts[12] = tostring(identity and (identity.questID or identity.completionQuestID) or "")
    _queueIconCacheKeyParts[13] = tostring(identity and identity.mapPinKind or mapPinInfo and mapPinInfo.kind or "")
    _queueIconCacheKeyParts[14] = tostring(identity and identity.mapPinType or mapPinInfo and mapPinInfo.mapPinType or "")
    _queueIconCacheKeyParts[15] = tostring(identity and identity.mapPinID or mapPinInfo and mapPinInfo.mapPinID or "")
    _queueIconCacheKeyParts[16] = tostring(mapPinInfo and mapPinInfo.atlas or "")
    _queueIconCacheKeyParts[17] = tostring(mapPinInfo and mapPinInfo.rawAtlas or "")
    _queueIconCacheKeyParts[18] = tostring(mapPinInfo and mapPinInfo.textureIndex or "")
    _queueIconCacheKeyParts[19] = tostring(mapPinInfo and mapPinInfo.ownerType or "")
    _queueIconCacheKeyParts[20] = tostring(identity and identity.vignetteID or "")
    _queueIconCacheKeyParts[21] = tostring(identity and identity.vignetteKind or "")
    _queueIconCacheKeyParts[22] = tostring(identity and identity.poiType or "")
    _queueIconCacheKeyParts[23] = tostring(identity and identity.ident or "")
    _queueIconCacheKeyParts[24] = tostring(opts.source or "")
    _queueIconCacheKeyParts[25] = tostring(record.title or "")
    _queueIconCacheKeyParts[26] = tostring(record.guideProvider or opts.guideProvider or "")
    _queueIconCacheKeyParts[27] = tostring(record.iconHintKind or "")
    _queueIconCacheKeyParts[28] = tostring(record.iconHintQuestID or "")
    _queueIconCacheKeyParts[29] = tostring(record.semanticKind or "")
    _queueIconCacheKeyParts[30] = tostring(record.semanticQuestID or "")
    _queueIconCacheKeyParts[31] = tostring(record.semanticTravelType or "")
    _queueIconCacheKeyParts[32] = tostring(record.presentationContentSig or "")
    _queueIconCacheKeyParts[33] = tostring(record.liveTravelType or "")
    _queueIconCacheKeyParts[34] = tostring(
        (opts.guideProvider or record.guideProvider)
        and type(NS.GetGuideProviderRegistryRevision) == "function"
        and NS.GetGuideProviderRegistryRevision()
        or ""
    )
    return table.concat(_queueIconCacheKeyParts, "\031", 1, 34)
end

local function CacheQueueIconSpec(cacheKey, spec)
    _queueIconCache[cacheKey] = spec or false
    _queueIconCacheOrder[#_queueIconCacheOrder + 1] = cacheKey
    while #_queueIconCacheOrder > _queueIconCacheLimit do
        local oldKey = table.remove(_queueIconCacheOrder, 1)
        _queueIconCache[oldKey] = nil
    end
end

local ResolveIconSpec

local function ResolveWaypointIconSpec(record, opts)
    record = type(record) == "table" and record or {}
    opts = type(opts) == "table" and opts or {}
    local cacheKey = BuildQueueIconCacheKey(record, opts)
    local cached = _queueIconCache[cacheKey]
    if cached ~= nil then
        return cached ~= false and cached or nil
    end

    local meta = type(record.meta) == "table" and record.meta or type(opts.meta) == "table" and opts.meta or nil
    local identity = type(meta) == "table" and type(meta.identity) == "table" and meta.identity or nil
    local mapPinInfo = type(record.mapPinInfo) == "table" and record.mapPinInfo
        or type(meta) == "table" and type(meta.mapPinInfo) == "table" and meta.mapPinInfo
        or nil
    local manualQuestID = GetQueueIconManualQuestID(record, meta, identity)

    for key in pairs(_queueIconSnapshot) do
        _queueIconSnapshot[key] = nil
    end
    _queueIconSnapshot.sourceAddon = TrimIconString(record.sourceAddon)
        or TrimIconString(meta and meta.sourceAddon)
        or TrimIconString(identity and identity.sourceAddon)
    _queueIconSnapshot.searchKind = TrimIconString(record.searchKind) or TrimIconString(meta and meta.searchKind)
    _queueIconSnapshot.manualQuestID = manualQuestID
    _queueIconSnapshot.routeLegKind = TrimIconString(record.routeLegKind)
    _queueIconSnapshot.routeTravelType = TrimIconString(record.routeTravelType)
    _queueIconSnapshot.guideProvider = TrimIconString(record.guideProvider) or TrimIconString(opts.guideProvider)
    _queueIconSnapshot.iconHintKind = ResolveQueueIconHintKind(record, meta, identity, mapPinInfo, manualQuestID, opts)
    _queueIconSnapshot.iconHintQuestID = type(record.iconHintQuestID) == "number" and record.iconHintQuestID > 0
        and record.iconHintQuestID
        or _queueIconSnapshot.iconHintKind == "quest" and manualQuestID
        or nil
    _queueIconSnapshot.semanticKind = TrimIconString(record.semanticKind)
        or (_queueIconSnapshot.iconHintKind == "quest" and "quest" or nil)
    _queueIconSnapshot.semanticQuestID = type(record.semanticQuestID) == "number" and record.semanticQuestID > 0
        and record.semanticQuestID
        or _queueIconSnapshot.iconHintQuestID
    _queueIconSnapshot.semanticTravelType = TrimIconString(record.semanticTravelType)
    _queueIconSnapshot.liveTravelType = TrimIconString(record.liveTravelType)
    _queueIconSnapshot.contentSig = TrimIconString(record.presentationContentSig)
    FillQueueIconMapPinSnapshot(_queueIconSnapshot, mapPinInfo)

    local kind = TrimIconString(opts.kind)
        or (_queueIconSnapshot.routeLegKind == "carrier" and "route")
        or (TrimIconString(record.entryType) == "travel" and "route")
        or "manual"
    local spec = ResolveIconSpec(
        kind,
        TrimIconString(opts.source) or TrimIconString(record.source) or "manual",
        record.title,
        _queueIconSnapshot,
        record.mapID,
        record.x,
        record.y
    )
    CacheQueueIconSpec(cacheKey, spec)
    return spec
end

function ResolveIconSpec(kind, source, title, contentSnapshotOverride, targetMapID, targetX, targetY)
    local contentSnapshot = contentSnapshotOverride or target.contentSnapshot or overlay.contentSnapshot
    local snapshotIcon = ResolveSnapshotIconSpec(contentSnapshot)
    if kind == "corpse" then
        return ICON_SPECS.corpse
    end

    if kind == "guide" or (kind == "route" and IsGuideRoutePresentation(contentSnapshot)) then
        if snapshotIcon then
            return snapshotIcon
        end
        return ResolveGuideIconSpec(contentSnapshot)
    end

    local travelType = DetectTravelType(kind, source, title, contentSnapshot)

    -- Route nodes can briefly survive after travel steps. If the active
    -- native target already matches the current quest goal, prefer the
    -- quest icon over the generic navigation glyph.
    if kind == "route" then
        if snapshotIcon then
            return snapshotIcon
        end
        if IsCarrierRouteLeg(contentSnapshot) then
            return ICON_SPECS.travel
        end
        if IsGuideRoutePresentation(contentSnapshot) then
            local goalQuestIcon = GetCurrentGoalQuestIconForTarget(
                targetMapID or target.mapID,
                targetX or target.x,
                targetY or target.y
            )
            if goalQuestIcon then
                return goalQuestIcon
            end
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

    if kind == "route" then
        return ICON_SPECS.travel
    end

    local unknownKind = tostring(kind)
    if _loggedUnknownTargetKinds[unknownKind] ~= true then
        _loggedUnknownTargetKinds[unknownKind] = true
        if type(NS.Log) == "function" then
            NS.Log("Unknown native overlay kind", unknownKind, tostring(source), tostring(title))
        end
    end

    if snapshotIcon then
        return snapshotIcon
    end
    if source == "manual" then
        return ICON_SPECS.manual
    end
    return ResolveGuideIconSpec(contentSnapshot)
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
            footer.__awpDistanceUnitKey = nil
            footer.__awpDistanceValueKey = nil
        end
        SetCachedFontStringText(fontString, "")
        return false
    end

    if footer
        and footer.__awpDistanceUnitKey == unitKey
        and footer.__awpDistanceValueKey == valueKey
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
        footer.__awpDistanceUnitKey = unitKey
        footer.__awpDistanceValueKey = valueKey
    end
    return true
end

local function UpdateArrivalFontString(footer, fontString, seconds)
    local valueKey = (type(seconds) == "number" and seconds >= 0) and math.floor(seconds) or nil
    if valueKey == nil then
        if footer then
            footer.__awpArrivalSecondsKey = nil
        end
        SetCachedFontStringText(fontString, "")
        return false
    end

    if footer and footer.__awpArrivalSecondsKey == valueKey then
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
        footer.__awpArrivalSecondsKey = valueKey
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
local GetPlayerWorldDistance = NS.GetPlayerWorldDistance

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

        distance = GetPlayerWorldDistance and GetPlayerWorldDistance(target.mapID, target.x, target.y)
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
    if manualQuestID
        and (
            target.kind == "manual"
            or (target.kind == "route" and not IsCarrierRouteLeg(contentSnapshot))
        )
    then
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
        -- Atlas application does not reliably discard a previous POI texture crop.
        texture:SetTexCoord(0, 1, 0, 1)
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
        texture:SetTexCoord(0, 1, 0, 1)
        texture:SetAtlas(spec.atlas, false, true)
    else
        texture:SetTexture(spec and spec.texture or nil)
        if spec and spec.texCoords then
            texture:SetTexCoord(spec.texCoords[1], spec.texCoords[2], spec.texCoords[3], spec.texCoords[4])
        else
            texture:SetTexCoord(0, 1, 0, 1)
        end
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

function M.InvalidateQuestIconSpecCache(questID)
    if type(questID) ~= "number" or questID == _cachedQuestIconQuestID then
        _cachedQuestIconQuestID = nil
        _cachedQuestIconTypeKey = nil
        _cachedQuestIconStatusPrefix = nil
        _cachedQuestIconSpec = nil
    end
end

M.DetectTravelType = DetectTravelType
M.IsGuideRoutePresentation = IsGuideRoutePresentation
M.ResolveTravelIconSpec = ResolveTravelIconSpec
M.ResolveGossipIconSpec = ResolveGossipIconSpec
M.ResolveSnapshotIconSpec = ResolveSnapshotIconSpec
M.ResolveIconSpec = ResolveIconSpec
M.ResolveWaypointIconSpec = ResolveWaypointIconSpec
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
