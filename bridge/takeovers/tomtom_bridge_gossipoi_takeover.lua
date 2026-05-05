local NS = _G.AzerothWaypointNS
local state = NS.State

NS.Internal = NS.Internal or {}

state.bridgeGossipPoiTakeover = state.bridgeGossipPoiTakeover or {
    activeGossipPoiSig = nil,
    activeGossipPoiMapID = nil,
    hooksInstalled = false,
    cachedOptions = nil,
    pendingSelection = nil,
    pendingDynamicPoi = nil,
    pendingDynamicPoiScheduled = false,
}

local gossip = state.bridgeGossipPoiTakeover

NS.Internal.BlizzardTakeovers = NS.Internal.BlizzardTakeovers or {}
local M = NS.Internal.BlizzardTakeovers
local GetActiveManualDestination = NS.GetActiveManualDestination
local ClearActiveManualDestination = NS.ClearActiveManualDestination
local GetGuideVisibilityState = NS.GetGuideVisibilityState
local Signature = NS.Signature

-- Confirmed in-game: GetPoiForUiMapID exists; GetGossipPoiForUiMapID is nil.
local GetPoiForUiMapID = C_GossipInfo and C_GossipInfo.GetPoiForUiMapID
local GetPoiInfo = C_GossipInfo and C_GossipInfo.GetPoiInfo
local GetOptions = C_GossipInfo and C_GossipInfo.GetOptions

local PENDING_GOSSIP_SELECTION_TIMEOUT_SECONDS = 5

local cachedGossipTypeDefs
local cachedGossipTypeMatcher
local gossipEventFrame

-- ============================================================
-- Helpers
-- ============================================================

local function GetWaypointSignature(mapID, x, y)
    if type(Signature) ~= "function" then return nil end
    if type(mapID) ~= "number" or type(x) ~= "number" or type(y) ~= "number" then return nil end
    return Signature(mapID, x, y)
end

local function GetNormalizedGossipPoiCoords(poiInfo)
    if type(poiInfo) ~= "table" then return nil, nil end

    local pos = poiInfo.position or poiInfo.normalizedPosition
    if type(pos) == "table" then
        local x = type(pos.x) == "number" and pos.x or nil
        local y = type(pos.y) == "number" and pos.y or nil
        if x and y then return x, y end
    end

    local x = type(poiInfo.normalizedX) == "number" and poiInfo.normalizedX
        or type(poiInfo.x) == "number" and poiInfo.x
        or nil
    local y = type(poiInfo.normalizedY) == "number" and poiInfo.normalizedY
        or type(poiInfo.y) == "number" and poiInfo.y
        or nil
    return x, y
end

local function GetGossipConfig()
    local native = NS.Internal and NS.Internal.WorldOverlay or nil
    return native and native.Config or nil
end

local function GetGossipFallbackTypeKey()
    local config = GetGossipConfig()
    local fallbackKey = config and config.GOSSIP_ICON_FALLBACK_KEY or nil
    if type(fallbackKey) == "string" and fallbackKey ~= "" then
        return fallbackKey
    end
    return "gossip_poi"
end

local function NormalizeGossipOptionText(text)
    if type(text) ~= "string" then
        return nil
    end

    text = text:lower()
    text = text:gsub("&", " and ")
    text = text:gsub("[\"'`]", "")
    text = text:gsub("[^%w%s]", " ")
    text = text:gsub("_", " ")
    text = text:gsub("%s+", " ")
    text = text:match("^%s*(.-)%s*$")
    if text == "" then
        return nil
    end
    return text
end

local function NormalizeGossipOptionPattern(text)
    if type(text) ~= "string" then
        return nil
    end

    text = text:lower()
    text = text:gsub("&", " and ")
    text = text:gsub("[\"'`]", "")
    text = text:gsub("_", " ")
    text = text:gsub("[^%w%s%*%?]", " ")
    text = text:gsub("%s+", " ")
    text = text:match("^%s*(.-)%s*$")
    if text == "" then
        return nil
    end
    return text
end

local function BuildDerivedGossipTypeKey(normalizedText)
    if type(normalizedText) ~= "string" or normalizedText == "" then
        return nil
    end

    local slug = normalizedText:gsub("%s+", "_")
    slug = slug:gsub("_+", "_")
    if slug == "" then
        return nil
    end
    return "gossip_" .. slug
end

local function BuildGossipPatternScore(normalizedPattern)
    if type(normalizedPattern) ~= "string" or normalizedPattern == "" then
        return 0
    end

    local literalChars = normalizedPattern:gsub("[%*%?%s]", "")
    local wildcardCount = 0
    for _ in normalizedPattern:gmatch("[%*%?]") do
        wildcardCount = wildcardCount + 1
    end
    return (#literalChars * 100) - wildcardCount
end

local function EscapeLuaPatternChar(char)
    if char:match("[%^%$%(%)%%%.%[%]%+%-%?]") then
        return "%" .. char
    end
    return char
end

local function CompileNormalizedGossipOptionPattern(normalizedPattern)
    if type(normalizedPattern) ~= "string" or normalizedPattern == "" then
        return nil
    end

    local parts = { "^" }
    for index = 1, #normalizedPattern do
        local char = normalizedPattern:sub(index, index)
        if char == "*" then
            parts[#parts + 1] = ".*"
        elseif char == "?" then
            parts[#parts + 1] = "."
        else
            parts[#parts + 1] = EscapeLuaPatternChar(char)
        end
    end
    parts[#parts + 1] = "$"
    return table.concat(parts)
end

local function BuildGossipMatcher(typeDefs)
    local matcher = {
        exact = {},
        patterns = {},
    }
    if type(typeDefs) ~= "table" then
        return matcher
    end

    local typeKeys = {}
    for typeKey in pairs(typeDefs) do
        if type(typeKey) == "string" then
            typeKeys[#typeKeys + 1] = typeKey
        end
    end
    table.sort(typeKeys)

    for _, typeKey in ipairs(typeKeys) do
        local typeDef = typeDefs[typeKey]
        if type(typeDef) == "table" then
            local optionNames = type(typeDef.optionNames) == "table" and typeDef.optionNames or nil
            if optionNames then
                for _, optionName in ipairs(optionNames) do
                    if type(optionName) == "string" then
                        if optionName:find("[%*%?]") then
                            local normalizedPattern = NormalizeGossipOptionPattern(optionName)
                            local compiledPattern = CompileNormalizedGossipOptionPattern(normalizedPattern)
                            if compiledPattern then
                                matcher.patterns[#matcher.patterns + 1] = {
                                    typeKey = typeKey,
                                    normalizedPattern = normalizedPattern,
                                    compiledPattern = compiledPattern,
                                    score = BuildGossipPatternScore(normalizedPattern),
                                }
                            end
                        else
                            local normalizedName = NormalizeGossipOptionText(optionName)
                            if normalizedName then
                                matcher.exact[normalizedName] = typeKey
                            end
                        end
                    end
                end
            end

            local optionPatterns = type(typeDef.optionPatterns) == "table" and typeDef.optionPatterns or nil
            if optionPatterns then
                for _, optionPattern in ipairs(optionPatterns) do
                    local normalizedPattern = NormalizeGossipOptionPattern(optionPattern)
                    local compiledPattern = CompileNormalizedGossipOptionPattern(normalizedPattern)
                    if compiledPattern then
                        matcher.patterns[#matcher.patterns + 1] = {
                            typeKey = typeKey,
                            normalizedPattern = normalizedPattern,
                            compiledPattern = compiledPattern,
                            score = BuildGossipPatternScore(normalizedPattern),
                        }
                    end
                end
            end
        end
    end

    table.sort(matcher.patterns, function(left, right)
        if left.score ~= right.score then
            return left.score > right.score
        end
        if left.normalizedPattern ~= right.normalizedPattern then
            return left.normalizedPattern < right.normalizedPattern
        end
        return left.typeKey < right.typeKey
    end)

    return matcher
end

local function GetGossipTypeMatcher()
    local config = GetGossipConfig()
    local typeDefs = config and config.GOSSIP_ICON_TYPE_DEFS or nil
    if typeDefs ~= cachedGossipTypeDefs then
        cachedGossipTypeDefs = typeDefs
        cachedGossipTypeMatcher = BuildGossipMatcher(typeDefs)
    end
    return cachedGossipTypeMatcher
end

local function ResolveGossipSelectionTypeKey(optionName)
    local normalizedName = NormalizeGossipOptionText(optionName)
    if not normalizedName then
        return GetGossipFallbackTypeKey()
    end

    local matcher = GetGossipTypeMatcher()
    local configuredTypeKey = matcher and matcher.exact and matcher.exact[normalizedName] or nil
    if type(configuredTypeKey) == "string" and configuredTypeKey ~= "" then
        return configuredTypeKey
    end

    local patternEntries = matcher and matcher.patterns or nil
    if type(patternEntries) == "table" then
        for _, entry in ipairs(patternEntries) do
            if normalizedName:match(entry.compiledPattern) then
                return entry.typeKey
            end
        end
    end

    return BuildDerivedGossipTypeKey(normalizedName) or GetGossipFallbackTypeKey()
end

local function RefreshCachedGossipOptions()
    if type(GetOptions) ~= "function" then
        gossip.cachedOptions = nil
        return nil
    end

    local options = GetOptions()
    if type(options) ~= "table" then
        gossip.cachedOptions = nil
        return nil
    end

    local snapshot = {}
    for _, option in pairs(options) do
        if type(option) == "table" then
            snapshot[#snapshot + 1] = {
                name = option.name,
                gossipOptionID = option.gossipOptionID,
                orderIndex = option.orderIndex,
                icon = option.icon,
                overrideIconID = option.overrideIconID,
            }
        end
    end

    gossip.cachedOptions = snapshot
    return snapshot
end

local function ClearCachedGossipOptions()
    gossip.cachedOptions = nil
end

local function EnsureGossipOptionCacheFrame()
    if gossipEventFrame or type(CreateFrame) ~= "function" then
        return
    end

    gossipEventFrame = CreateFrame("Frame")
    gossipEventFrame:RegisterEvent("GOSSIP_SHOW")
    gossipEventFrame:RegisterEvent("GOSSIP_CLOSED")
    gossipEventFrame:SetScript("OnEvent", function(_, event)
        if event == "GOSSIP_SHOW" then
            gossip.pendingSelection = nil
            RefreshCachedGossipOptions()
            return
        end
        ClearCachedGossipOptions()
    end)
end

local function FindCachedGossipOption(predicate)
    if type(predicate) ~= "function" then
        return nil
    end

    local options = type(gossip.cachedOptions) == "table" and gossip.cachedOptions or nil
    if type(options) ~= "table" or #options == 0 then
        return nil
    end

    for _, option in ipairs(options) do
        if predicate(option) then
            return option
        end
    end

    return nil
end

local function RememberPendingGossipSelection(option)
    if type(option) ~= "table" then
        return false
    end

    local optionName = type(option.name) == "string" and option.name or nil
    gossip.pendingSelection = {
        optionName = optionName,
        typeKey = ResolveGossipSelectionTypeKey(optionName),
        setAt = type(GetTime) == "function" and GetTime() or 0,
        gossipOptionID = option.gossipOptionID,
        orderIndex = option.orderIndex,
    }
    return true
end

local function RememberPendingGossipSelectionByOptionID(gossipOptionID)
    if type(gossipOptionID) ~= "number" then
        return false
    end

    return RememberPendingGossipSelection(FindCachedGossipOption(function(option)
        return type(option) == "table" and option.gossipOptionID == gossipOptionID
    end))
end

local function RememberPendingGossipSelectionByOrderIndex(orderIndex)
    if type(orderIndex) ~= "number" then
        return false
    end

    return RememberPendingGossipSelection(FindCachedGossipOption(function(option)
        return type(option) == "table" and option.orderIndex == orderIndex
    end))
end

local function ConsumePendingGossipSelection()
    local pendingSelection = gossip.pendingSelection
    gossip.pendingSelection = nil
    if type(pendingSelection) ~= "table" then
        return nil
    end

    local selectedAt = type(pendingSelection.setAt) == "number" and pendingSelection.setAt or 0
    local now = type(GetTime) == "function" and GetTime() or 0
    if selectedAt > 0 and now > 0 and (now - selectedAt) > PENDING_GOSSIP_SELECTION_TIMEOUT_SECONDS then
        return nil
    end

    return pendingSelection
end

local function GetActiveGossipPoiSearchKind(sig)
    if type(sig) ~= "string" then
        return nil
    end

    local destination = GetActiveManualDestination and GetActiveManualDestination() or nil
    local identity = type(destination) == "table" and type(destination.identity) == "table" and destination.identity or nil
    if type(destination) ~= "table"
        or destination.type ~= "manual"
        or type(identity) ~= "table"
        or identity.kind ~= "gossip_poi"
        or identity.sig ~= sig
    then
        return nil
    end

    local searchKind = destination.searchKind
    if type(searchKind) == "string" and searchKind ~= "" then
        return searchKind
    end

    return nil
end

local function ResolveAdoptedGossipSearchKind(sig)
    local pendingSelection = ConsumePendingGossipSelection()
    local pendingTypeKey = pendingSelection and pendingSelection.typeKey or nil
    local pendingOptionName = type(pendingSelection) == "table" and pendingSelection.optionName or nil
    if type(pendingTypeKey) == "string" and pendingTypeKey ~= "" then
        return pendingTypeKey, pendingOptionName
    end

    local activeSearchKind = GetActiveGossipPoiSearchKind(sig)
    if type(activeSearchKind) == "string" and activeSearchKind ~= "" then
        return activeSearchKind, nil
    end

    return GetGossipFallbackTypeKey(), nil
end

-- ============================================================
-- Meta builder
-- ============================================================

local function BuildBlizzardGossipPoiMeta(mapID, x, y, sig, searchKind, optionName)
    local normalizedSearchKind = type(searchKind) == "string" and searchKind ~= "" and searchKind or GetGossipFallbackTypeKey()
    return NS.BuildRouteMeta(NS.BuildGossipPoiIdentity(mapID, x, y, {
        sig = sig,
        optionName = optionName,
    }), {
        searchKind = normalizedSearchKind,
        queueSourceType = "transient_source",
    })
end

-- ============================================================
-- Adoption
-- ============================================================

local function AdoptGossipPoiAsTransient(mapID, x, y, title, searchKind, optionName)
    if not (state.init and state.init.playerLoggedIn) then return end
    if type(NS.IsRoutingEnabled) ~= "function" or not NS.IsRoutingEnabled() then return end

    local sig = GetWaypointSignature(mapID, x, y)
    if not sig then return end

    gossip.activeGossipPoiSig = sig
    gossip.activeGossipPoiMapID = mapID

    local routed = NS.RequestManualRoute(mapID, x, y, title, BuildBlizzardGossipPoiMeta(mapID, x, y, sig, searchKind, optionName))
    if not routed then
        if gossip.activeGossipPoiSig == sig then
            gossip.activeGossipPoiSig = nil
            gossip.activeGossipPoiMapID = nil
        end
        return
    end

    NS.Log("GossipPOI takeover route", tostring(mapID), tostring(x), tostring(y), tostring(sig), tostring(searchKind))
end

local function ProcessPendingDynamicGossipPoi()
    gossip.pendingDynamicPoiScheduled = false

    local pending = gossip.pendingDynamicPoi
    gossip.pendingDynamicPoi = nil
    if type(pending) ~= "table" then
        return
    end

    local mapID = pending.mapID
    local x = pending.x
    local y = pending.y
    local sig = pending.sig
    if type(mapID) ~= "number" or type(x) ~= "number" or type(y) ~= "number" or type(sig) ~= "string" then
        return
    end

    local searchKind = type(pending.searchKind) == "string" and pending.searchKind ~= "" and pending.searchKind or nil
    local optionName = pending.optionName
    if not searchKind then
        searchKind, optionName = ResolveAdoptedGossipSearchKind(sig)
    end

    if type(NS.DoesGuideOwnTarget) == "function" and NS.DoesGuideOwnTarget(mapID, x, y) then
        return
    end

    AdoptGossipPoiAsTransient(
        mapID,
        x,
        y,
        pending.title,
        searchKind,
        optionName
    )
end

local function ScheduleDynamicGossipPoiAdoption(mapID, x, y, title, sig, searchKind, optionName)
    gossip.pendingDynamicPoi = {
        mapID = mapID,
        x = x,
        y = y,
        title = title,
        sig = sig,
        searchKind = searchKind,
        optionName = optionName,
    }

    if gossip.pendingDynamicPoiScheduled then
        return
    end

    gossip.pendingDynamicPoiScheduled = true
    if type(NS.After) == "function" then
        NS.After(0, function()
            NS.SafeCall(ProcessPendingDynamicGossipPoi)
        end)
    else
        ProcessPendingDynamicGossipPoi()
    end
end

local function CancelPendingDynamicGossipPoi()
    gossip.pendingDynamicPoi = nil
    gossip.pendingDynamicPoiScheduled = false
end

-- ============================================================
-- Clear helper
-- ============================================================

local function HandleRemovedGossipPoiDestination()
    local destination = GetActiveManualDestination and GetActiveManualDestination() or nil
    if type(destination) ~= "table" or destination.type ~= "manual" then
        gossip.activeGossipPoiSig = nil
        gossip.activeGossipPoiMapID = nil
        return false
    end

    local identity = type(destination.identity) == "table" and destination.identity or nil
    local activeSig = type(identity) == "table" and identity.kind == "gossip_poi" and identity.sig or nil
    if not activeSig or activeSig ~= gossip.activeGossipPoiSig then
        gossip.activeGossipPoiSig = nil
        gossip.activeGossipPoiMapID = nil
        return false
    end

    local visibilityState = GetGuideVisibilityState and GetGuideVisibilityState() or nil
    if type(ClearActiveManualDestination) ~= "function" then return false end

    NS.Log("GossipPOI takeover clear", tostring(activeSig))
    gossip.activeGossipPoiSig = nil
    gossip.activeGossipPoiMapID = nil
    return ClearActiveManualDestination(visibilityState, "explicit")
end

-- ============================================================
-- NS exports
-- ============================================================

function NS.HandleRemovedGossipPoiDestination(destination, clearReason)
    local identity = type(destination) == "table" and type(destination.identity) == "table" and destination.identity or nil
    if type(identity) ~= "table" or identity.kind ~= "gossip_poi" then
        return false
    end
    return HandleRemovedGossipPoiDestination()
end

function NS.ClearGossipPoiByIdentity(identity)
    if type(identity) ~= "table" or identity.kind ~= "gossip_poi" then
        return false
    end
    local sig = type(identity.sig) == "string" and identity.sig or nil
    if sig and gossip.activeGossipPoiSig and gossip.activeGossipPoiSig ~= sig then
        return false
    end
    gossip.activeGossipPoiSig = nil
    gossip.activeGossipPoiMapID = nil
    gossip.pendingSelection = nil
    NS.Log("GossipPOI takeover clear", tostring(sig or "-"))
    return true
end

function NS.InstallGossipPoiHooks()
    if gossip.hooksInstalled then
        return true
    end

    EnsureGossipOptionCacheFrame()
    RefreshCachedGossipOptions()

    local installed = false
    if type(C_GossipInfo) == "table" then
        if type(C_GossipInfo.SelectOption) == "function" then
            hooksecurefunc(C_GossipInfo, "SelectOption", function(gossipOptionID)
                NS.SafeCall(RememberPendingGossipSelectionByOptionID, gossipOptionID)
            end)
            installed = true
        end

        if type(C_GossipInfo.SelectOptionByIndex) == "function" then
            hooksecurefunc(C_GossipInfo, "SelectOptionByIndex", function(orderIndex)
                NS.SafeCall(RememberPendingGossipSelectionByOrderIndex, orderIndex)
            end)
            installed = true
        end
    end

    gossip.hooksInstalled = installed
    return installed
end

-- Called by init.lua when DYNAMIC_GOSSIP_POI_UPDATED fires.
-- Fires with zero args; uses GetBestMapForUnit("player") to find context.
function NS.OnDynamicGossipPoiUpdated()
    if type(GetPoiForUiMapID) ~= "function" then return end

    local mapID = type(C_Map) == "table"
        and type(C_Map.GetBestMapForUnit) == "function"
        and C_Map.GetBestMapForUnit("player")
        or nil
    if not mapID then return end

    local poiID = GetPoiForUiMapID(mapID)
    if not poiID then
        gossip.pendingSelection = nil
        CancelPendingDynamicGossipPoi()
        HandleRemovedGossipPoiDestination()
        return
    end

    local poiInfo = type(GetPoiInfo) == "function" and GetPoiInfo(mapID, poiID) or nil
    local x, y = GetNormalizedGossipPoiCoords(poiInfo)
    if not x or not y then
        CancelPendingDynamicGossipPoi()
        return
    end

    local sig = GetWaypointSignature(mapID, x, y)
    if not sig then
        CancelPendingDynamicGossipPoi()
        return
    end

    local searchKind, optionName
    if type(gossip.pendingSelection) == "table" then
        searchKind, optionName = ResolveAdoptedGossipSearchKind(sig)
    end

    ScheduleDynamicGossipPoiAdoption(
        mapID,
        x,
        y,
        poiInfo and type(poiInfo.name) == "string" and poiInfo.name or nil,
        sig,
        searchKind,
        optionName
    )
end
