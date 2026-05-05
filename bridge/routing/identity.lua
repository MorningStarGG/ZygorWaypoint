local NS = _G.AzerothWaypointNS

-- ============================================================
-- Canonical route identity and metadata
-- ============================================================

local Signature = NS.Signature

local IDENTITY_KINDS = {
    manual = true,
    blizzard_user_waypoint = true,
    map_pin = true,
    quest = true,
    vignette = true,
    gossip_poi = true,
    zygor_poi = true,
    external_tomtom = true,
}

NS.IdentityKinds = IDENTITY_KINDS

local function TrimString(value)
    if type(value) ~= "string" then
        return nil
    end
    value = value:gsub("^%s+", ""):gsub("%s+$", "")
    if value == "" then
        return nil
    end
    return value
end

local function NormalizeSourceAddon(value)
    value = TrimString(value)
    if not value then
        return nil
    end
    local externalSource = type(NS.NormalizeExternalWaypointSource) == "function"
        and NS.NormalizeExternalWaypointSource(value)
        or nil
    if externalSource then
        return externalSource
    end
    return value
end

local function NormalizeQueueSourceType(value)
    value = TrimString(value)
    if value == "transient_source" then
        return value
    end
    return nil
end

local function PositiveNumber(value)
    return type(value) == "number" and value > 0 and value or nil
end

local function CopyTable(source)
    if type(source) ~= "table" then
        return nil
    end
    local out = {}
    for key, value in pairs(source) do
        if type(value) == "table" then
            local child = {}
            for childKey, childValue in pairs(value) do
                child[childKey] = childValue
            end
            out[key] = child
        else
            out[key] = value
        end
    end
    return out
end

function NS.RouteSignature(mapID, x, y)
    if type(Signature) == "function"
        and type(mapID) == "number"
        and type(x) == "number"
        and type(y) == "number"
    then
        return Signature(mapID, x, y)
    end
    return nil
end

local function BaseIdentity(kind, source, mapID, x, y, opts)
    opts = type(opts) == "table" and opts or {}
    return {
        kind = kind,
        source = source,
        sig = TrimString(opts.sig) or NS.RouteSignature(mapID, x, y),
        mapID = mapID,
        x = x,
        y = y,
    }
end

function NS.BuildManualIdentity(mapID, x, y, opts)
    return BaseIdentity("manual", "manual", mapID, x, y, opts)
end

function NS.BuildUserWaypointIdentity(mapID, x, y, opts)
    return BaseIdentity("blizzard_user_waypoint", "blizzard", mapID, x, y, opts)
end

function NS.BuildMapPinInfo(kind, mapID, x, y, opts)
    kind = TrimString(kind)
    if not kind then
        return nil
    end
    opts = type(opts) == "table" and opts or {}
    return {
        kind = kind,
        mapPinType = type(opts.mapPinType) == "number" and opts.mapPinType or nil,
        mapPinID = PositiveNumber(opts.mapPinID),
        sig = TrimString(opts.sig) or NS.RouteSignature(mapID, x, y),
        mapID = type(opts.mapID) == "number" and opts.mapID or mapID,
        x = type(opts.x) == "number" and opts.x or x,
        y = type(opts.y) == "number" and opts.y or y,
        atlas = TrimString(opts.atlas),
        rawAtlas = TrimString(opts.rawAtlas),
        textureIndex = PositiveNumber(opts.textureIndex),
        description = TrimString(opts.description),
        isCurrentEvent = opts.isCurrentEvent == true or nil,
        tooltipWidgetSet = PositiveNumber(opts.tooltipWidgetSet),
        ownerType = type(opts.ownerType) == "number" and opts.ownerType or nil,
    }
end

function NS.BuildMapPinIdentity(mapPinInfo, opts)
    if type(mapPinInfo) ~= "table" or not TrimString(mapPinInfo.kind) then
        return nil
    end
    opts = type(opts) == "table" and opts or {}
    local identity = BaseIdentity(
        "map_pin",
        "blizzard",
        type(opts.mapID) == "number" and opts.mapID or mapPinInfo.mapID,
        type(opts.x) == "number" and opts.x or mapPinInfo.x,
        type(opts.y) == "number" and opts.y or mapPinInfo.y,
        { sig = opts.sig or mapPinInfo.sig }
    )
    identity.mapPinKind = mapPinInfo.kind
    identity.mapPinType = mapPinInfo.mapPinType
    identity.mapPinID = mapPinInfo.mapPinID
    return identity
end

function NS.BuildQuestIdentity(questID, mapID, x, y, opts)
    questID = PositiveNumber(questID)
    if not questID then
        return nil
    end
    opts = type(opts) == "table" and opts or {}
    local identity = BaseIdentity("quest", "blizzard", mapID, x, y, opts)
    identity.questID = questID
    identity.questSource = TrimString(opts.questSource)
    return identity
end

function NS.BuildVignetteIdentity(mapID, x, y, opts)
    opts = type(opts) == "table" and opts or {}
    local identity = BaseIdentity("vignette", "blizzard", mapID, x, y, opts)
    identity.guid = TrimString(opts.guid)
    identity.vignetteKind = TrimString(opts.vignetteKind)
    identity.vignetteID = PositiveNumber(opts.vignetteID)
    identity.vignetteType = opts.vignetteType
    return identity
end

function NS.BuildGossipPoiIdentity(mapID, x, y, opts)
    opts = type(opts) == "table" and opts or {}
    local identity = BaseIdentity("gossip_poi", "blizzard", mapID, x, y, opts)
    identity.optionName = TrimString(opts.optionName)
    return identity
end

function NS.BuildZygorPoiIdentity(mapID, x, y, opts)
    opts = type(opts) == "table" and opts or {}
    local identity = BaseIdentity("zygor_poi", "zygor", mapID, x, y, opts)
    identity.poiType = TrimString(opts.poiType)
    identity.ident = TrimString(opts.ident)
    identity.completionQuestID = PositiveNumber(opts.completionQuestID)
    return identity
end

function NS.BuildExternalTomTomIdentity(uid, mapID, x, y, opts)
    opts = type(opts) == "table" and opts or {}
    local sourceAddon = opts.sourceAddon
    if type(uid) == "table" and not sourceAddon then
        sourceAddon = uid.awpSourceAddon or uid.sourceAddon or uid.source or uid.from
    end
    local sig = TrimString(opts.externalSig) or TrimString(opts.queueSig) or TrimString(opts.sig) or NS.RouteSignature(mapID, x, y)
    local identity = BaseIdentity("external_tomtom", "external", mapID, x, y, { sig = sig })
    identity.externalSig = TrimString(opts.externalSig) or sig
    identity.queueSig = TrimString(opts.queueSig)
    identity.queueIndex = type(opts.queueIndex) == "number" and opts.queueIndex or nil
    identity.sourceAddon = NormalizeSourceAddon(sourceAddon)
    return identity
end

function NS.BuildRouteMeta(identity, opts)
    if not NS.ValidateRouteIdentity(identity) then
        return nil
    end
    opts = type(opts) == "table" and opts or {}
    local meta = {
        identity = CopyTable(identity),
        sourceAddon = NormalizeSourceAddon(opts.sourceAddon or identity.sourceAddon),
        searchKind = TrimString(opts.searchKind),
        manualQuestID = PositiveNumber(opts.manualQuestID or identity.questID or identity.completionQuestID),
        mapPinInfo = CopyTable(opts.mapPinInfo),
        queueSourceType = NormalizeQueueSourceType(opts.queueSourceType or identity.queueSourceType),
    }
    if meta.identity.kind == "map_pin" and type(meta.mapPinInfo) ~= "table" then
        meta.mapPinInfo = NS.BuildMapPinInfo(meta.identity.mapPinKind, meta.identity.mapID, meta.identity.x, meta.identity.y, {
            mapPinType = meta.identity.mapPinType,
            mapPinID = meta.identity.mapPinID,
            sig = meta.identity.sig,
        })
    end
    return meta
end

function NS.ValidateRouteIdentity(identity)
    if type(identity) ~= "table" or IDENTITY_KINDS[identity.kind] ~= true then
        return false
    end
    if type(identity.mapID) ~= "number" or type(identity.x) ~= "number" or type(identity.y) ~= "number" then
        return false
    end
    if identity.kind == "quest" then
        return PositiveNumber(identity.questID) ~= nil
    end
    if identity.kind == "map_pin" then
        return TrimString(identity.mapPinKind) ~= nil
    end
    if identity.kind == "vignette" then
        return TrimString(identity.guid) ~= nil or PositiveNumber(identity.vignetteID) ~= nil
    end
    if identity.kind == "zygor_poi" then
        return TrimString(identity.poiType) ~= nil and TrimString(identity.ident) ~= nil
    end
    return true
end

function NS.ValidateRouteMeta(meta)
    return type(meta) == "table" and NS.ValidateRouteIdentity(meta.identity)
end

local function IdentityKey(identity)
    if not NS.ValidateRouteIdentity(identity) then
        return nil
    end
    if identity.kind == "quest" then
        return table.concat({ identity.kind, tostring(identity.questID), tostring(identity.questSource or "") }, "\031")
    end
    if identity.kind == "map_pin" then
        return table.concat({
            identity.kind,
            tostring(identity.mapPinKind or ""),
            tostring(identity.mapPinType or ""),
            tostring(identity.mapPinID or ""),
            tostring(identity.sig or NS.RouteSignature(identity.mapID, identity.x, identity.y) or ""),
        }, "\031")
    end
    if identity.kind == "vignette" then
        return table.concat({ identity.kind, tostring(identity.guid or ""), tostring(identity.vignetteID or "") }, "\031")
    end
    if identity.kind == "gossip_poi" then
        return table.concat({ identity.kind, tostring(identity.sig or ""), tostring(identity.optionName or "") }, "\031")
    end
    if identity.kind == "zygor_poi" then
        return table.concat({ identity.kind, tostring(identity.poiType or ""), tostring(identity.ident or "") }, "\031")
    end
    if identity.kind == "external_tomtom" then
        return table.concat({ identity.kind, tostring(identity.externalSig or identity.queueSig or identity.sig or "") }, "\031")
    end
    return table.concat({ identity.kind, tostring(identity.sig or NS.RouteSignature(identity.mapID, identity.x, identity.y) or "") }, "\031")
end

function NS.RouteIdentitiesMatch(a, b)
    local aKey = IdentityKey(a)
    local bKey = IdentityKey(b)
    return aKey ~= nil and aKey == bKey
end

function NS.RouteIdentityMatchesHost(identityOrRecord, mapID, x, y)
    local identity = type(identityOrRecord) == "table"
        and (identityOrRecord.identity or identityOrRecord)
        or nil
    if type(identity) ~= "table" then
        return false
    end
    local sig = TrimString(identity.sig) or NS.RouteSignature(identity.mapID, identity.x, identity.y)
    local hostSig = NS.RouteSignature(mapID, x, y)
    return type(sig) == "string" and sig == hostSig
end
