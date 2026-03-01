local NS = _G.ZygorWaypointNS
local state = NS.State
local constants = NS.Constants
local enums = NS.Enums

local function ResolveQuestWaypoint(questID)
  questID = tonumber(questID)
  if not questID or questID <= 0 then
    return nil
  end

  local title = C_QuestLog.GetTitleForQuestID(questID) or C_TaskQuest.GetQuestInfoByQuestID(questID) or ("Quest " .. questID)

  local mapID, x, y = C_QuestLog.GetNextWaypoint(questID)
  mapID = NS.NormalizeMapID(mapID)
  x, y = NS.NormalizeCoords(x, y)
  if mapID and x and y then
    return mapID, x, y, title
  end

  mapID = NS.NormalizeMapID(GetQuestUiMapID and GetQuestUiMapID(questID))
  if mapID then
    local quests = C_QuestLog.GetQuestsOnMap(mapID)
    if quests then
      for _, info in ipairs(quests) do
        if info.questID == questID then
          x, y = NS.NormalizeCoords(info.x, info.y)
          if x and y then
            return mapID, x, y, title
          end
          break
        end
      end
    end

    local tasks = C_TaskQuest.GetQuestsOnMap and C_TaskQuest.GetQuestsOnMap(mapID)
    if tasks then
      for _, info in ipairs(tasks) do
        if info.questID == questID then
          x, y = NS.NormalizeCoords(info.x, info.y)
          if x and y then
            return mapID, x, y, title
          end
          break
        end
      end
    end
  end

  local taskMapID = NS.NormalizeMapID(C_TaskQuest.GetQuestZoneID and C_TaskQuest.GetQuestZoneID(questID))
  if taskMapID then
    local tasks = C_TaskQuest.GetQuestsOnMap and C_TaskQuest.GetQuestsOnMap(taskMapID)
    if tasks then
      for _, info in ipairs(tasks) do
        if info.questID == questID then
          x, y = NS.NormalizeCoords(info.x, info.y)
          if x and y then
            return taskMapID, x, y, title
          end
          break
        end
      end
    end
  end

  return nil
end

local function ResolveUserWaypoint(point)
  local mapID, x, y
  point = point or (C_Map.GetUserWaypoint and C_Map.GetUserWaypoint())

  if point then
    mapID = point.uiMapID or point.mapID
    x, y = NS.GetPointXY(point)
  end

  mapID = NS.NormalizeMapID(mapID)
  x, y = NS.NormalizeCoords(x, y)
  if mapID and x and y then
    return mapID, x, y, constants.USER_WAYPOINT_TITLE
  end

  local candidateMaps = {}
  if WorldMapFrame and WorldMapFrame:IsShown() and type(WorldMapFrame.GetMapID) == "function" then
    local worldMapID = WorldMapFrame:GetMapID()
    NS.AddCandidateMap(candidateMaps, NS.GetCursorMapID(worldMapID))
  end
  NS.AddCandidateMap(candidateMaps, NS.GetCurrentMapID())

  if C_Map.GetUserWaypointPositionForMap then
    for _, candidateMapID in ipairs(candidateMaps) do
      local position = C_Map.GetUserWaypointPositionForMap(candidateMapID)
      if position and type(position.GetXY) == "function" then
        x, y = NS.NormalizeCoords(position:GetXY())
        if x and y then
          return candidateMapID, x, y, constants.USER_WAYPOINT_TITLE
        end
      end
    end
  end

  return nil
end

local function FindAreaPOIMapID(poiID)
  local cachedMapID = state.areaPOIMapCache[poiID]
  if cachedMapID then
    local cachedInfo = C_AreaPoiInfo.GetAreaPOIInfo(cachedMapID, poiID)
    if cachedInfo then
      return cachedMapID, cachedInfo
    end
    state.areaPOIMapCache[poiID] = nil
  end

  for mapID = 1, 4000 do
    local info = C_AreaPoiInfo.GetAreaPOIInfo(mapID, poiID)
    if info then
      state.areaPOIMapCache[poiID] = mapID
      return mapID, info
    end
  end
end

local function ResolveAreaPOIWaypoint(poiID)
  poiID = tonumber(poiID)
  if not poiID or poiID <= 0 then
    return nil
  end

  local candidateMaps = {}
  if WorldMapFrame and WorldMapFrame:IsShown() and type(WorldMapFrame.GetMapID) == "function" then
    local worldMapID = WorldMapFrame:GetMapID()
    NS.AddCandidateMap(candidateMaps, NS.GetCursorMapID(worldMapID))
    NS.AddCandidateMap(candidateMaps, worldMapID)
  end
  NS.AddCandidateMap(candidateMaps, NS.GetCurrentMapID())

  for _, mapID in ipairs(candidateMaps) do
    local info = C_AreaPoiInfo.GetAreaPOIInfo(mapID, poiID)
    if info and info.position and type(info.position.GetXY) == "function" then
      local x, y = NS.NormalizeCoords(info.position:GetXY())
      if x and y then
        return mapID, x, y, info.name or ("POI " .. poiID)
      end
    end
  end

  local mapID, info = FindAreaPOIMapID(poiID)
  if info and info.position and type(info.position.GetXY) == "function" then
    local x, y = NS.NormalizeCoords(info.position:GetXY())
    mapID = NS.NormalizeMapID(mapID)
    if mapID and x and y then
      return mapID, x, y, info.name or ("POI " .. poiID)
    end
  end

  return nil
end

local function ResolveContentWaypoint(trackableType, trackableID)
  if not (C_ContentTracking and C_ContentTracking.GetBestMapForTrackable) then
    return nil
  end

  local result, mapID = C_ContentTracking.GetBestMapForTrackable(trackableType, trackableID)
  if Enum and Enum.ContentTrackingResult and result ~= Enum.ContentTrackingResult.Success then
    return nil
  end

  mapID = NS.NormalizeMapID(mapID)
  if not mapID then
    return nil
  end

  local title = C_ContentTracking.GetTitle and C_ContentTracking.GetTitle(trackableType, trackableID)
  if not title or title == "" then
    title = "Tracked content"
  end

  local info
  if C_ContentTracking.GetNextWaypointForTrackable then
    local _, waypointInfo = C_ContentTracking.GetNextWaypointForTrackable(trackableType, trackableID, mapID)
    info = waypointInfo
  end

  if not info and C_ContentTracking.GetTrackablesOnMap then
    local _, infos = C_ContentTracking.GetTrackablesOnMap(trackableType, mapID)
    if infos and #infos == 1 then
      info = infos[1]
    end
  end

  if not info then
    return nil
  end

  local x, y = NS.NormalizeCoords(info.x, info.y)
  if not (x and y) then
    return nil
  end

  return mapID, x, y, title
end

local function ClearAutoIfActive()
  if state.autoWaypointActive then
    NS.ClearAutoWaypoints()
  end
end

function NS.RouteCurrentSuperTracking()
  if not NS.IsAutoEnabled() then
    return false
  end

  if not C_SuperTrack then
    return false
  end

  local superType = C_SuperTrack.GetHighestPrioritySuperTrackingType and C_SuperTrack.GetHighestPrioritySuperTrackingType()

  if superType == enums.SUPERTRACK_TYPE.Quest then
    local questID = C_SuperTrack.GetSuperTrackedQuestID and C_SuperTrack.GetSuperTrackedQuestID() or 0
    if questID and questID > 0 then
      local mapID, x, y, title = ResolveQuestWaypoint(questID)
      if mapID and x and y then
        return NS.SetAutoWaypoint(mapID, x, y, title)
      end
    end
    ClearAutoIfActive()
    return false
  end

  if superType == enums.SUPERTRACK_TYPE.UserWaypoint then
    local mapID, x, y, title = ResolveUserWaypoint()
    if mapID and x and y then
      return NS.SetAutoWaypoint(mapID, x, y, title)
    end
    ClearAutoIfActive()
    return false
  end

  if superType == enums.SUPERTRACK_TYPE.Content then
    if C_SuperTrack.GetSuperTrackedContent then
      local trackableType, trackableID = C_SuperTrack.GetSuperTrackedContent()
      if trackableType and trackableID then
        local mapID, x, y, title = ResolveContentWaypoint(trackableType, trackableID)
        if mapID and x and y then
          return NS.SetAutoWaypoint(mapID, x, y, title)
        end
      end
    end
    ClearAutoIfActive()
    return false
  end

  if superType == enums.SUPERTRACK_TYPE.MapPin then
    if C_SuperTrack.GetSuperTrackedMapPin then
      local pinType, pinID = C_SuperTrack.GetSuperTrackedMapPin()
      if pinType and pinID then
        if pinType == enums.SUPERTRACK_MAP_PIN_TYPE.AreaPOI then
          local mapID, x, y, title = ResolveAreaPOIWaypoint(pinID)
          if mapID and x and y then
            return NS.SetAutoWaypoint(mapID, x, y, title)
          end
          ClearAutoIfActive()
          return false
        end

        -- Fallback for map pin types without exposed coordinate APIs.
        local mapID, x, y, title = ResolveUserWaypoint()
        if mapID and x and y then
          return NS.SetAutoWaypoint(mapID, x, y, title)
        end
      end
    end
    ClearAutoIfActive()
    return false
  end

  ClearAutoIfActive()
  return false
end

function NS.ScheduleAutoRefresh(delaySeconds)
  if state.autoRefreshQueued then
    return
  end

  state.autoRefreshQueued = true
  C_Timer.After(delaySeconds or 0, function()
    state.autoRefreshQueued = false
    if not NS.AreHooksSuppressed() then
      NS.RouteCurrentSuperTracking()
    end
  end)
end

function NS.InstallAutoHooks()
  if state.hooksInstalled then
    return
  end
  state.hooksInstalled = true

  if hooksecurefunc and C_SuperTrack then
    if type(C_SuperTrack.SetSuperTrackedQuestID) == "function" then
      hooksecurefunc(C_SuperTrack, "SetSuperTrackedQuestID", function()
        if not NS.AreHooksSuppressed() then
          NS.ScheduleAutoRefresh(0)
        end
      end)
    end

    if type(C_SuperTrack.SetSuperTrackedMapPin) == "function" then
      hooksecurefunc(C_SuperTrack, "SetSuperTrackedMapPin", function()
        if not NS.AreHooksSuppressed() then
          NS.ScheduleAutoRefresh(0)
        end
      end)
    end

    if type(C_SuperTrack.SetSuperTrackedContent) == "function" then
      hooksecurefunc(C_SuperTrack, "SetSuperTrackedContent", function()
        if not NS.AreHooksSuppressed() then
          NS.ScheduleAutoRefresh(0)
        end
      end)
    end

    if type(C_SuperTrack.SetSuperTrackedUserWaypoint) == "function" then
      hooksecurefunc(C_SuperTrack, "SetSuperTrackedUserWaypoint", function()
        if not NS.AreHooksSuppressed() then
          NS.ScheduleAutoRefresh(0)
        end
      end)
    end

    if type(C_SuperTrack.ClearAllSuperTracked) == "function" then
      hooksecurefunc(C_SuperTrack, "ClearAllSuperTracked", function()
        if not NS.AreHooksSuppressed() and state.autoWaypointActive then
          NS.ClearAutoWaypoints()
        end
      end)
    end

    if type(C_SuperTrack.ClearSuperTrackedMapPin) == "function" then
      hooksecurefunc(C_SuperTrack, "ClearSuperTrackedMapPin", function()
        if not NS.AreHooksSuppressed() then
          NS.ScheduleAutoRefresh(0)
        end
      end)
    end
  end

  if hooksecurefunc and C_Map then
    if type(C_Map.SetUserWaypoint) == "function" then
      hooksecurefunc(C_Map, "SetUserWaypoint", function(point)
        if NS.AreHooksSuppressed() or not NS.IsAutoEnabled() then
          return
        end
        local mapID, x, y, title = ResolveUserWaypoint(point)
        if mapID and x and y then
          NS.SetAutoWaypoint(mapID, x, y, title)
        else
          NS.ScheduleAutoRefresh(0)
        end
      end)
    end

    if type(C_Map.ClearUserWaypoint) == "function" then
      hooksecurefunc(C_Map, "ClearUserWaypoint", function()
        if not NS.AreHooksSuppressed() then
          NS.ScheduleAutoRefresh(0)
        end
      end)
    end
  end
end
