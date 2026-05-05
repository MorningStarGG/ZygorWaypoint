local ADDON_NAME = ...

local NS = _G.AzerothWaypointNS
if type(NS) ~= "table" then
    NS = {}
    _G.AzerothWaypointNS = NS
end

function NS.GetAddonMetadataValue(field, fallback)
    local value = C_AddOns.GetAddOnMetadata(ADDON_NAME, field)
    if value == nil or value == "" then
        return fallback
    end
    return value
end

NS.ADDON_NAME = ADDON_NAME
NS.VERSION = NS.GetAddonMetadataValue("Version", "0.0.0")
NS.BUILD = 1
