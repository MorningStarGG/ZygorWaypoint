local ADDON_NAME = ...

local NS = _G.ZygorWaypointNS
if type(NS) ~= "table" then
  NS = {}
  _G.ZygorWaypointNS = NS
end

NS.ADDON_NAME = ADDON_NAME
NS.FRAME = NS.FRAME or CreateFrame("Frame")
NS.API = _G.ZygorWaypoint or {}

_G.ZygorWaypoint = NS.API

if type(ZygorWaypointDB) ~= "table" then
  ZygorWaypointDB = {}
end

NS.DB = ZygorWaypointDB

NS.Constants = NS.Constants or {
  AUTO_WAYPOINT_TYPE = "zwp_auto",
  USER_WAYPOINT_TITLE = "Map waypoint",
  ARRIVAL_DISTANCE = 15, -- yards
}

NS.Enums = NS.Enums or {
  SUPERTRACK_TYPE = Enum and Enum.SuperTrackingType or {},
  SUPERTRACK_MAP_PIN_TYPE = Enum and Enum.SuperTrackingMapPinType or {},
}

NS.State = NS.State or {
  mapCache = {},
  areaPOIMapCache = {},
  isMapCacheBuilt = false,
  hooksInstalled = false,
  suppressHookDepth = 0,
  autoRefreshQueued = false,
  autoWaypointActive = false,
  lastAutoSignature = nil,
  slashRegistered = false,
  manualWaypoint = nil,
  manualArrivalTicker = nil,
}
