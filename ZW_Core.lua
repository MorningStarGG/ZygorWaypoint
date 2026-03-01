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

end

function NS.IsEnabled()
  local db = NS.GetDB()
  return db.enabled
end

function NS.IsAutoEnabled()
  local db = NS.GetDB()
  return db.enabled and db.auto
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
  if not zoneName or zoneName == "" then
    return nil
  end

  if not state.isMapCacheBuilt then
    NS.BuildMapCache()
  end

  local baseZone, subZone = strsplit(":", zoneName)
  if subZone then
    zoneName = subZone:match("^%s*(.-)%s*$")
  else
    zoneName = baseZone
  end

  local mapID = zoneName and state.mapCache[zoneName:lower()] or nil
  return NS.NormalizeMapID(mapID)
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
