local NS = _G.ZygorWaypointNS
local state = NS.State

local function BuildSignature(mapID, x, y)
  return string.format("%d:%.5f:%.5f", mapID, x, y)
end

local function NormalizeWaypointCoords(mapID, x, y)
  mapID = NS.NormalizeMapID(mapID)
  x, y = NS.NormalizeCoords(x, y)
  if not (mapID and x and y) then
    return nil
  end

  return mapID, x, y, BuildSignature(mapID, x, y)
end

local function GetCurrentUserWaypointSignature()
  if not (C_Map and type(C_Map.GetUserWaypoint) == "function") then
    return nil
  end

  local point = C_Map.GetUserWaypoint()
  if not point then
    return nil
  end

  local mapID = point.uiMapID or point.mapID
  local x, y = NS.GetPointXY(point)
  local normalizedMapID, normalizedX, normalizedY, signature = NormalizeWaypointCoords(mapID, x, y)
  if not normalizedMapID then
    return nil
  end

  return signature, normalizedMapID, normalizedX, normalizedY
end

local function SetBlizzardUserWaypoint(mapID, x, y)
  if not (UiMapPoint and C_Map and type(C_Map.SetUserWaypoint) == "function") then
    return false
  end

  local okPoint, point = pcall(UiMapPoint.CreateFromCoordinates, mapID, x, y)
  if not (okPoint and point) then
    return false
  end

  NS.BeginHookSuppression()
  pcall(C_Map.SetUserWaypoint, point)
  if C_SuperTrack and type(C_SuperTrack.SetSuperTrackedUserWaypoint) == "function" then
    pcall(C_SuperTrack.SetSuperTrackedUserWaypoint, true)
  end
  NS.EndHookSuppression()

  return true
end

function NS.SyncWaypointToDiamond(waypoint)
  if not NS.IsSyncEnabled() then
    return false
  end

  if not waypoint then
    return NS.ClearSyncedDiamondWaypoint("no waypoint")
  end

  local mapID = waypoint.m or waypoint.map
  local x, y = waypoint.x, waypoint.y
  local normalizedMapID, normalizedX, normalizedY, signature = NormalizeWaypointCoords(mapID, x, y)
  if not normalizedMapID then
    return false
  end

  if state.diamondOwned and state.lastDiamondSignature == signature then
    return true
  end

  local currentSignature = GetCurrentUserWaypointSignature()
  if currentSignature == signature then
    state.lastDiamondSignature = signature
    state.diamondOwned = true
    if C_SuperTrack and type(C_SuperTrack.SetSuperTrackedUserWaypoint) == "function" then
      NS.BeginHookSuppression()
      pcall(C_SuperTrack.SetSuperTrackedUserWaypoint, true)
      NS.EndHookSuppression()
    end
    return true
  end

  local ok = SetBlizzardUserWaypoint(normalizedMapID, normalizedX, normalizedY)
  if not ok then
    return false
  end

  state.lastDiamondSignature = signature
  state.diamondOwned = true
  return true
end

function NS.ClearSyncedDiamondWaypoint(reason)
  if not state.diamondOwned then
    state.lastDiamondSignature = nil
    return false
  end

  local currentSignature = GetCurrentUserWaypointSignature()
  local shouldClear = not currentSignature or currentSignature == state.lastDiamondSignature

  if shouldClear and C_Map and type(C_Map.ClearUserWaypoint) == "function" and C_Map.HasUserWaypoint and C_Map.HasUserWaypoint() then
    NS.BeginHookSuppression()
    pcall(C_Map.ClearUserWaypoint)
    NS.EndHookSuppression()
  end

  state.diamondOwned = false
  state.lastDiamondSignature = nil
  return true
end

function NS.SyncCurrentArrowToDiamond()
  if not NS.IsSyncEnabled() then
    return false
  end

  local pointer = NS.GetPointer()
  if not pointer or not pointer.ArrowFrame then
    return false
  end

  return NS.SyncWaypointToDiamond(pointer.ArrowFrame.waypoint)
end

function NS.InstallDiamondSyncHooks()
  if state.diamondHooksInstalled then
    return true
  end

  if not hooksecurefunc then
    return false
  end

  local pointer = NS.GetPointer()
  if not pointer or type(pointer.ShowArrow) ~= "function" then
    return false
  end

  state.diamondHooksInstalled = true

  hooksecurefunc(pointer, "ShowArrow", function(_, waypoint)
    if NS.AreHooksSuppressed() or not NS.IsSyncEnabled() then
      return
    end
    NS.SyncWaypointToDiamond(waypoint)
  end)

  if type(pointer.HideArrow) == "function" then
    hooksecurefunc(pointer, "HideArrow", function()
      if NS.AreHooksSuppressed() then
        return
      end
      NS.ClearSyncedDiamondWaypoint("hide arrow")
    end)
  end

  return true
end

function NS.EnsureDiamondSyncHooks()
  if NS.InstallDiamondSyncHooks() then
    return
  end

  if state.diamondRetryTicker then
    return
  end

  state.diamondRetryTicker = C_Timer.NewTicker(1, function()
    if NS.InstallDiamondSyncHooks() then
      state.diamondRetryTicker:Cancel()
      state.diamondRetryTicker = nil
      NS.SyncCurrentArrowToDiamond()
    end
  end)
end

