local NS = _G.ZygorWaypointNS

function NS.GetTomTom()
    return _G["TomTom"]
end

function NS.GetTomTomArrow()
    return _G["TomTomCrazyArrow"]
end

function NS.IsBlankText(value)
    return type(value) ~= "string" or value:match("^%s*$") ~= nil
end

function NS.GetPlayerMapID()
    if not C_Map or type(C_Map.GetBestMapForUnit) ~= "function" then
        return
    end

    local playerMapID = C_Map.GetBestMapForUnit("player")
    if type(playerMapID) ~= "number" then
        return
    end

    return playerMapID
end

function NS.Signature(m, x, y)
    if type(x) == "number" then
        x = math.floor(x * 10000 + 0.5) / 10000
    end
    if type(y) == "number" then
        y = math.floor(y * 10000 + 0.5) / 10000
    end
    return tostring(m) .. ":" .. tostring(x) .. ":" .. tostring(y)
end
