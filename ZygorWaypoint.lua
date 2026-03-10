local ADDON_NAME = ...

local NS = _G.ZygorWaypointNS
if type(NS) ~= "table" then
    NS = {}
    _G.ZygorWaypointNS = NS
end

NS.ADDON_NAME = ADDON_NAME
NS.VERSION = "2.0.0"
NS.BUILD = 1
