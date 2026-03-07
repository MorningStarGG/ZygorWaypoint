local NS = _G.ZygorWaypointNS
local state = NS.State

function NS.Msg(text)
  DEFAULT_CHAT_FRAME:AddMessage("|cff6cf0ffZygorWaypoint:|r " .. text)
end

function NS.GetDB()
  if type(ZygorWaypointDB) ~= "table" then
    ZygorWaypointDB = {}
  end

  NS.DB = ZygorWaypointDB
  return ZygorWaypointDB
end


function NS.EnsureDBDefaults()
  local db = NS.GetDB()

  if db.enabled == nil then
    db.enabled = true
  end
  if db.auto == nil then
    db.auto = true
  end
  if db.sync == nil then
    db.sync = true
  end

end

function NS.IsEnabled()
  local db = NS.GetDB()
  return db.enabled
end

function NS.IsAutoEnabled()
  local db = NS.GetDB()
  return db.enabled and db.auto
end

function NS.IsSyncEnabled()
  local db = NS.GetDB()
  return db.enabled and db.sync ~= false
end

function NS.BeginHookSuppression()
  state.suppressHookDepth = state.suppressHookDepth + 1
end

function NS.EndHookSuppression()
  state.suppressHookDepth = state.suppressHookDepth - 1
  if state.suppressHookDepth < 0 then
    state.suppressHookDepth = 0
  end
end

function NS.AreHooksSuppressed()
  return state.suppressHookDepth > 0
end

function NS.GetPointer()
  local viewer = _G.ZygorGuidesViewer or _G.ZGV
  if viewer and viewer.Pointer and type(viewer.Pointer.SetWaypoint) == "function" then
    return viewer.Pointer
  end
end

local function GetLibRover()
  local viewer = _G.ZygorGuidesViewer or _G.ZGV
  if viewer and viewer.LibRover then
    return viewer.LibRover
  end
  if _G.LibRover then
    return _G.LibRover
  end
end

local function PickMapIDFromFloors(floorMap)
  if type(floorMap) ~= "table" then
    return nil
  end

  local defaultFloor = tonumber(floorMap.default)
  if defaultFloor and tonumber(floorMap[defaultFloor]) then
    return tonumber(floorMap[defaultFloor])
  end

  if tonumber(floorMap[0]) then
    return tonumber(floorMap[0])
  end

  local bestFloor
  local bestMapID
  for floor, mapID in pairs(floorMap) do
    if type(floor) == "number" and tonumber(mapID) then
      if bestFloor == nil or floor < bestFloor then
        bestFloor = floor
        bestMapID = tonumber(mapID)
      end
    end
  end

  return bestMapID
end

function NS.NormalizeZoneName(zoneName)
  if not zoneName then
    return nil
  end

  local baseZone, subZone = strsplit(":", zoneName)
  if subZone then
    return subZone:match("^%s*(.-)%s*$")
  end

  return baseZone and baseZone:match("^%s*(.-)%s*$")
end

function NS.NormalizeMapID(mapID)
  mapID = tonumber(mapID)
  if not mapID then
    return nil
  end

  local mapInfo = C_Map.GetMapInfo(mapID)
  if not mapInfo then
    return nil
  end

  if Enum
    and Enum.UIMapType
    and mapInfo.mapType == Enum.UIMapType.Micro
    and mapInfo.parentMapID
    and mapInfo.parentMapID > 0
  then
    mapID = mapInfo.parentMapID
  end

  return mapID
end

function NS.GetMapIDByNameFromZygor(zoneName)
  zoneName = NS.NormalizeZoneName(zoneName)
  if not zoneName or zoneName == "" then
    return nil
  end

  local rover = GetLibRover()
  if not rover then
    return nil
  end

  if type(rover.GetMapByNameFloor) == "function" then
    local ok, mapID = pcall(rover.GetMapByNameFloor, rover, zoneName)
    mapID = ok and mapID or nil
    mapID = mapID and mapID ~= false and NS.NormalizeMapID(mapID) or nil
    if mapID then
      return mapID
    end
  end

  local byName = rover.data and rover.data.MapIDsByName
  if type(byName) ~= "table" then
    return nil
  end

  local mapData = byName[zoneName]
  if not mapData then
    local target = zoneName:lower()
    for name, data in pairs(byName) do
      if type(name) == "string" and name:lower() == target then
        mapData = data
        break
      end
    end
  end

  if type(mapData) == "number" then
    return NS.NormalizeMapID(mapData)
  end

  if type(mapData) == "table" then
    return NS.NormalizeMapID(PickMapIDFromFloors(mapData))
  end
end

function NS.GetCurrentMapID()
  local mapID = C_Map.GetBestMapForUnit("player")
  if not mapID and WorldMapFrame and WorldMapFrame:IsShown() and type(WorldMapFrame.GetMapID) == "function" then
    mapID = WorldMapFrame:GetMapID()
  end
  return NS.NormalizeMapID(mapID)
end

function NS.GetCursorMapID(mapID)
  if not mapID then
    return nil
  end

  if not (
    WorldMapFrame
    and WorldMapFrame:IsShown()
    and WorldMapFrame.ScrollContainer
    and WorldMapFrame.ScrollContainer:IsMouseOver()
  ) then
    return NS.NormalizeMapID(mapID)
  end

  if type(WorldMapFrame.GetNormalizedCursorPosition) ~= "function" then
    return NS.NormalizeMapID(mapID)
  end

  local cursorX, cursorY = WorldMapFrame:GetNormalizedCursorPosition()
  if not (cursorX and cursorY) then
    return NS.NormalizeMapID(mapID)
  end

  local mapInfo = C_Map.GetMapInfoAtPosition(mapID, cursorX, cursorY)
  if mapInfo and mapInfo.mapID then
    return NS.NormalizeMapID(mapInfo.mapID)
  end

  return NS.NormalizeMapID(mapID)
end

function NS.BuildMapCache()
  local mapCache = state.mapCache
  if wipe then
    wipe(mapCache)
  else
    for key in pairs(mapCache) do
      mapCache[key] = nil
    end
  end

  for mapID = 1, 4000 do
    local mapInfo = C_Map.GetMapInfo(mapID)
    if mapInfo and mapInfo.name then
      mapCache[mapInfo.name:lower()] = NS.NormalizeMapID(mapID) or mapID
    end
  end

  state.isMapCacheBuilt = true
end

function NS.GetMapIDByName(zoneName)
  zoneName = NS.NormalizeZoneName(zoneName)
  if not zoneName or zoneName == "" then
    return nil
  end

  local zygorMapID = NS.GetMapIDByNameFromZygor(zoneName)
  if zygorMapID then
    return zygorMapID
  end

  if not state.isMapCacheBuilt then
    NS.BuildMapCache()
  end

  local mapID = zoneName and state.mapCache[zoneName:lower()] or nil
  return NS.NormalizeMapID(mapID)
end

function NS.ResolveCommandMapID(mapID)
  mapID = NS.NormalizeMapID(mapID)
  if not mapID then
    return nil
  end

  local rover = GetLibRover()
  local knownMap = rover and rover.data and rover.data.MapNamesByID and rover.data.MapNamesByID[mapID]
  if knownMap then
    return mapID
  end

  local mapInfo = C_Map.GetMapInfo(mapID)
  if mapInfo and mapInfo.name then
    local fallbackMapID = NS.GetMapIDByName(mapInfo.name)
    if fallbackMapID then
      return fallbackMapID
    end
  end

  return mapID
end

function NS.NormalizeCoords(x, y)
  x = tonumber(x)
  y = tonumber(y)
  if not (x and y) then
    return nil, nil
  end

  if x > 1 or y > 1 then
    x = x / 100
    y = y / 100
  end

  if x < 0 or x > 1 or y < 0 or y > 1 then
    return nil, nil
  end

  return x, y
end

function NS.GetPointXY(point)
  if not point then
    return nil, nil
  end

  if type(point.GetXY) == "function" then
    local x, y = point:GetXY()
    if x and y then
      return x, y
    end
  end

  if point.position and type(point.position.GetXY) == "function" then
    local x, y = point.position:GetXY()
    if x and y then
      return x, y
    end
  end

  if point.x and point.y then
    return point.x, point.y
  end

  return nil, nil
end

function NS.AddCandidateMap(container, mapID)
  mapID = NS.NormalizeMapID(mapID)
  if not mapID then
    return
  end

  for _, existing in ipairs(container) do
    if existing == mapID then
      return
    end
  end
  container[#container + 1] = mapID
end


