local NS = _G.ZygorWaypointNS
local state = NS.State
local constants = NS.Constants

function NS.ParseWayArgs(input)
  local zone, x, y, title
  local currentMapID

  zone, x, y, title = input:match("^(.-)%s+([%d%.]+)%s+([%d%.]+)%s*(.*)$")

  if not (tonumber(x) and tonumber(y)) then
    x, y, title = input:match("^([%d%.]+)%s+([%d%.]+)%s*(.*)$")
    if x and y then
      currentMapID = NS.GetCurrentMapID()
    end
  end

  if not zone and not currentMapID then
    return nil, nil, nil, nil, "Usage: /way <zone|#mapID> <x> <y> [title] or /way <x> <y> [title]"
  end

  x, y = NS.NormalizeCoords(x, y)
  if not (x and y) then
    return nil, nil, nil, nil, "Coordinates must be 0..1 or 0..100."
  end

  local mapID = currentMapID
  if not mapID then
    local mapIDString = zone:match("^#(%d+)$")
    if mapIDString then
      mapID = NS.ResolveCommandMapID(tonumber(mapIDString))
      if not mapID then
        return nil, nil, nil, nil, "Invalid map ID #" .. mapIDString
      end
    else
      mapID = NS.GetMapIDByName(zone)
      if not mapID then
        return nil, nil, nil, nil, "Unknown zone: " .. zone
      end
    end
  end

  if not title or title == "" then
    title = "ZygorWaypoint"
  end

  return mapID, x, y, title
end

function NS.ClearWaypoints(quiet)
  local pointer = NS.GetPointer()
  if not pointer then
    if not quiet then
      NS.Msg("Zygor Guide Viewer is not loaded.")
    end
    return false
  end

  if type(pointer.ClearWaypoints) == "function" then
    NS.BeginHookSuppression()
    pcall(pointer.ClearWaypoints, pointer)
    NS.EndHookSuppression()
  end

  if not quiet then
    NS.Msg("Waypoints cleared.")
  end

  return true
end

function NS.ClearAutoWaypoints()
  state.autoWaypointActive = false
  state.lastAutoSignature = nil

  local pointer = NS.GetPointer()
  if pointer and type(pointer.ClearWaypoints) == "function" then
    NS.BeginHookSuppression()
    pcall(pointer.ClearWaypoints, pointer, constants.AUTO_WAYPOINT_TYPE)
    NS.EndHookSuppression()
  end
end

function NS.SetWaypoint(mapID, x, y, opts)
  local quiet = type(opts) == "table" and opts.quiet
  local pointer = NS.GetPointer()
  if not pointer then
    if not quiet then
      NS.Msg("Zygor Guide Viewer is not loaded.")
    end
    return false
  end

  mapID = NS.NormalizeMapID(mapID)
  if not mapID then
    if not quiet then
      NS.Msg("Invalid map ID.")
    end
    return false
  end

  x, y = NS.NormalizeCoords(x, y)
  if not (x and y) then
    if not quiet then
      NS.Msg("Coordinates must be 0..1 or 0..100.")
    end
    return false
  end

  local title
  if type(opts) == "table" then
    title = opts.title
  else
    title = opts
  end

  local waydata = {
    title = title or "ZygorWaypoint",
    type = "manual",
    cleartype = true,
    icon = pointer.Icons and pointer.Icons.greendotbig or nil,
    onminimap = "always",
    overworld = true,
    showonedge = true,
    findpath = true,
  }

  if type(opts) == "table" then
    if opts.type ~= nil then waydata.type = opts.type end
    if opts.cleartype ~= nil then waydata.cleartype = opts.cleartype end
    if opts.icon ~= nil then waydata.icon = opts.icon end
    if opts.onminimap ~= nil then waydata.onminimap = opts.onminimap end
    if opts.overworld ~= nil then waydata.overworld = opts.overworld end
    if opts.showonedge ~= nil then waydata.showonedge = opts.showonedge end
    if opts.findpath ~= nil then waydata.findpath = opts.findpath end
    for key, value in pairs(opts) do
      if value ~= nil
        and key ~= "title"
        and key ~= "type"
        and key ~= "cleartype"
        and key ~= "icon"
        and key ~= "onminimap"
        and key ~= "overworld"
        and key ~= "showonedge"
        and key ~= "findpath"
        and key ~= "quiet"
        and key ~= "ignoreDisabled"
      then
        waydata[key] = value
      end
    end
  end

  NS.BeginHookSuppression()
  local ok, waypoint = pcall(pointer.SetWaypoint, pointer, mapID, x, y, waydata, true)
  NS.EndHookSuppression()
  if not ok then
    if not quiet then
      NS.Msg("Failed to set waypoint.")
    end
    return false
  end

  if waypoint and waydata.findpath and type(pointer.FindTravelPath) == "function" then
    NS.BeginHookSuppression()
    pcall(pointer.FindTravelPath, pointer, waypoint)
    NS.EndHookSuppression()
  end
  return true
end

function NS.StopArrivalCheck()
  if state.manualArrivalTicker then
    state.manualArrivalTicker:Cancel()
    state.manualArrivalTicker = nil
  end
end

function NS.ClearManualUserWaypoint()
  NS.StopArrivalCheck()
  state.manualWaypoint = nil
end

function NS.ResumeGuideWaypoint()
  local viewer = _G.ZygorGuidesViewer or _G.ZGV
  if not viewer then
    return
  end

  local pointer = viewer.Pointer
  if not pointer then
    return
  end

  -- Use ZGV's built-in static function: clears manual waypoints then restores guide
  if type(pointer.ClearWaypoint) == "function" then
    NS.BeginHookSuppression()
    pcall(pointer.ClearWaypoint)
    NS.EndHookSuppression()
    return
  end

  -- Fallback: clear manual type and rebuild guide waypoints
  if type(pointer.ClearWaypoints) == "function" then
    NS.BeginHookSuppression()
    pcall(pointer.ClearWaypoints, pointer, "manual")
    NS.EndHookSuppression()
  end
  if type(viewer.ShowWaypoints) == "function" then
    pcall(viewer.ShowWaypoints, viewer)
  end
end

function NS.CheckManualWaypointArrival()
  local wp = state.manualWaypoint
  if not wp then
    NS.StopArrivalCheck()
    return
  end

  local playerMapID = C_Map.GetBestMapForUnit("player")
  if not playerMapID then
    return
  end

  local playerPos = C_Map.GetPlayerMapPosition(playerMapID, "player")
  if not playerPos then
    return
  end

  local px, py = playerPos:GetXY()
  if not (px and py) then
    return
  end

  local ok1, _, playerWorld = pcall(C_Map.GetWorldPosFromMapPos, playerMapID, CreateVector2D(px, py))
  local ok2, _, wpWorld = pcall(C_Map.GetWorldPosFromMapPos, wp.mapID, CreateVector2D(wp.x, wp.y))

  if not (ok1 and ok2 and playerWorld and wpWorld) then
    return
  end

  local dx = playerWorld.x - wpWorld.x
  local dy = playerWorld.y - wpWorld.y
  local dist = math.sqrt(dx * dx + dy * dy)

  if dist <= constants.ARRIVAL_DISTANCE then
    NS.OnManualWaypointArrival()
  end
end

function NS.OnManualWaypointArrival()
  NS.ClearManualUserWaypoint()

  -- Clear the Blizzard user waypoint (map pin)
  NS.BeginHookSuppression()
  if C_Map.HasUserWaypoint and C_Map.HasUserWaypoint() then
    C_Map.ClearUserWaypoint()
  end
  NS.EndHookSuppression()

  -- Restore the Zygor guide waypoint
  NS.ResumeGuideWaypoint()

  NS.Msg("Arrived — waypoint cleared, resuming guide.")
end

function NS.SetManualUserWaypoint(mapID, x, y, title)
  -- Clear any existing auto waypoint
  if state.autoWaypointActive then
    NS.ClearAutoWaypoints()
  end

  local ok = NS.SetWaypoint(mapID, x, y, {
    title = title or constants.USER_WAYPOINT_TITLE,
    type = "manual",
    cleartype = true,
    findpath = true,
    quiet = true,
  })

  if ok then
    state.manualWaypoint = { mapID = mapID, x = x, y = y, title = title }
    NS.StopArrivalCheck()
    state.manualArrivalTicker = C_Timer.NewTicker(0.5, function()
      NS.CheckManualWaypointArrival()
    end)
  end

  return ok
end

function NS.SetAutoWaypoint(mapID, x, y, title)
  if not NS.IsAutoEnabled() then
    return false
  end

  -- Auto routing supersedes manual waypoint tracking
  if state.manualWaypoint then
    NS.ClearManualUserWaypoint()
  end

  local signature = string.format("%d:%.5f:%.5f:%s", mapID, x, y, title or "")
  if signature == state.lastAutoSignature then
    state.autoWaypointActive = true
    return true
  end

  local ok = NS.SetWaypoint(mapID, x, y, {
    title = title or "Tracked target",
    type = constants.AUTO_WAYPOINT_TYPE,
    cleartype = true,
    findpath = true,
    quiet = true,
  })

  if ok then
    state.lastAutoSignature = signature
    state.autoWaypointActive = true
  end

  return ok
end
