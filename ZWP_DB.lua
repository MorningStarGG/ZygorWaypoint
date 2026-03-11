local NS = _G.ZygorWaypointNS
local C = NS.Constants

local DB_DEFAULTS = {
    tomtomOverride = true,
    arrowAlignment = true,
    zygorRouting = true,
    tomtomSkin = C.SKIN_STARLIGHT,
    tomtomArrowScale = C.SCALE_DEFAULT,
    guideStepsOnlyHover = false,
    manualWaypointAutoClear = false,
    manualWaypointClearDistance = C.MANUAL_CLEAR_DISTANCE_DEFAULT,
}

function NS.NormalizeSkin(value)
    if value == C.SKIN_STARLIGHT then
        return C.SKIN_STARLIGHT
    end
    if value == C.SKIN_STEALTH then
        return C.SKIN_STEALTH
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

function NS.NormalizeManualWaypointClearDistance(value)
    local n = tonumber(value) or C.MANUAL_CLEAR_DISTANCE_DEFAULT
    if n < C.MANUAL_CLEAR_DISTANCE_MIN then n = C.MANUAL_CLEAR_DISTANCE_MIN end
    if n > C.MANUAL_CLEAR_DISTANCE_MAX then n = C.MANUAL_CLEAR_DISTANCE_MAX end
    n = math.floor((n / C.MANUAL_CLEAR_DISTANCE_STEP) + 0.5) * C.MANUAL_CLEAR_DISTANCE_STEP
    return n
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

    db.enabled = nil

    db.tomtomSkin = NS.NormalizeSkin(db.tomtomSkin)
    db.tomtomArrowScale = NS.NormalizeScale(db.tomtomArrowScale)
    db.manualWaypointClearDistance = NS.NormalizeManualWaypointClearDistance(db.manualWaypointClearDistance)
    return db
end

function NS.IsRoutingEnabled()
    local db = NS.GetDB()
    return db.zygorRouting ~= false
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

function NS.IsGuideStepsOnlyHoverEnabled()
    local db = NS.GetDB()
    return db.guideStepsOnlyHover == true
end

function NS.SetGuideStepsOnlyHoverEnabled(enabled)
    local db = NS.GetDB()
    db.guideStepsOnlyHover = enabled and true or false
    return db.guideStepsOnlyHover
end

function NS.IsManualWaypointAutoClearEnabled()
    local db = NS.GetDB()
    return db.manualWaypointAutoClear == true
end

function NS.SetManualWaypointAutoClearEnabled(enabled)
    local db = NS.GetDB()
    db.manualWaypointAutoClear = enabled and true or false
    return db.manualWaypointAutoClear
end

function NS.GetManualWaypointClearDistance()
    local db = NS.GetDB()
    db.manualWaypointClearDistance = NS.NormalizeManualWaypointClearDistance(db.manualWaypointClearDistance)
    return db.manualWaypointClearDistance
end

function NS.SetManualWaypointClearDistance(value)
    local db = NS.GetDB()
    db.manualWaypointClearDistance = NS.NormalizeManualWaypointClearDistance(value)
    return db.manualWaypointClearDistance
end
