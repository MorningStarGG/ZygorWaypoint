local NS = _G.ZygorWaypointNS
local C = NS.Constants

local DB_DEFAULTS = {
    enabled = true,
    tomtomOverride = true,
    arrowAlignment = true,
    zygorRouting = true,
    tomtomSkin = C.SKIN_STARLIGHT,
    tomtomArrowScale = C.SCALE_DEFAULT,
}

function NS.NormalizeSkin(value)
    if value == C.SKIN_STARLIGHT then
        return C.SKIN_STARLIGHT
    end
    return C.SKIN_DEFAULT
end

function NS.NormalizeScale(value)
    local n = tonumber(value) or C.SCALE_DEFAULT
    if n < C.SCALE_MIN then n = C.SCALE_MIN end
    if n > C.SCALE_MAX then n = C.SCALE_MAX end
    n = math.floor((n / C.SCALE_STEP) + 0.5) * C.SCALE_STEP
    return tonumber(string.format("%.2f", n)) or C.SCALE_DEFAULT
end

function NS.GetDB()
    if type(ZygorWaypointDB) ~= "table" then
        ZygorWaypointDB = {}
    end
    return ZygorWaypointDB
end

function NS.ApplyDBDefaults()
    local db = NS.GetDB()
    for key, value in pairs(DB_DEFAULTS) do
        if db[key] == nil then
            db[key] = value
        end
    end

    db.tomtomSkin = NS.NormalizeSkin(db.tomtomSkin)
    db.tomtomArrowScale = NS.NormalizeScale(db.tomtomArrowScale)

    NS.Runtime.enabled = db.enabled ~= false
    return db
end

function NS.IsBridgeEnabled()
    return NS.GetDB().enabled ~= false
end

function NS.SetBridgeEnabled(enabled)
    local db = NS.GetDB()
    db.enabled = enabled and true or false
    NS.Runtime.enabled = db.enabled
end

function NS.IsRoutingEnabled()
    local db = NS.GetDB()
    return db.enabled ~= false and db.zygorRouting ~= false
end

function NS.GetSkinChoice()
    local db = NS.GetDB()
    db.tomtomSkin = NS.NormalizeSkin(db.tomtomSkin)
    return db.tomtomSkin
end

function NS.SetSkinChoice(skin)
    local db = NS.GetDB()
    db.tomtomSkin = NS.NormalizeSkin(skin)
end

function NS.GetArrowScale()
    local db = NS.GetDB()
    db.tomtomArrowScale = NS.NormalizeScale(db.tomtomArrowScale)
    return db.tomtomArrowScale
end

function NS.SetArrowScale(value)
    local db = NS.GetDB()
    db.tomtomArrowScale = NS.NormalizeScale(value)
    return db.tomtomArrowScale
end

function NS.ApplyTomTomScalePolicy()
    local db = NS.GetDB()
    db.tomtomArrowScale = NS.NormalizeScale(db.tomtomArrowScale)
end
