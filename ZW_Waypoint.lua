local NS = _G.ZygorWaypointNS
local state = NS.State
local constants = NS.Constants

function NS.ParseWayArgs(input)
  local zone, x, y, title

  zone, x, y, title = input:match("^(.-)%s+([%d%.]+)%s+([%d%.]+)%s*(.*)$")

  if not (tonumber(x) and tonumber(y)) then
    x, y, title = input:match("^([%d%.]+)%s+([%d%.]+)%s*(.*)$")
    if x and y then
      local currentMapID = NS.GetCurrentMapID()
      if currentMapID then
        local mapInfo = C_Map.GetMapInfo(currentMapID)
        zone = mapInfo and mapInfo.name or nil
      end
    end
  end

  if not zone then
    return nil, nil, nil, nil, "Usage: /way <zone|#mapID> <x> <y> [title] or /way <x> <y> [title]"
  end

  x, y = NS.NormalizeCoords(x, y)
  if not (x and y) then
    return nil, nil, nil, nil, "Coordinates must be 0..1 or 0..100."
  end

  local mapID
  local mapIDString = zone:match("^#(%d+)$")
  if mapIDString then
    mapID = NS.NormalizeMapID(tonumber(mapIDString))
    if not mapID then
      return nil, nil, nil, nil, "Invalid map ID #" .. mapIDString
    end
  else
    mapID = NS.GetMapIDByName(zone)
    if not mapID then
      return nil, nil, nil, nil, "Unknown zone: " .. zone
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

function NS.SetAutoWaypoint(mapID, x, y, title)
  if not NS.IsAutoEnabled() then
    return false
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
