local NS = _G.ZygorWaypointNS

local function IsSyncConfiguredOn(db)
  return db.sync ~= false
end

local function HandleWayCommand(input)
  if not NS.IsEnabled() then
    NS.Msg("Disabled. Use /zwp on.")
    return
  end

  local mapID, x, y, title, err = NS.ParseWayArgs(input or "")
  if not mapID then
    NS.Msg(err)
    return
  end

  if NS.SetWaypoint(mapID, x, y, { title = title }) then
    local mapInfo = C_Map.GetMapInfo(mapID)
    local zoneName = mapInfo and mapInfo.name or ("Map #" .. mapID)
    NS.Msg(string.format("Waypoint set: %s (%.1f, %.1f)", zoneName, x * 100, y * 100))
  end
end

local function HandleRouteCommand(cmd)
  local db = NS.GetDB()

  cmd = (cmd or ""):match("^%s*(.-)%s*$")
  local action, arg = cmd:match("^(%S+)%s*(.-)$")
  action = (action or ""):lower()
  arg = (arg or ""):match("^%s*(.-)%s*$"):lower()

  if action == "on" then
    db.enabled = true
    if IsSyncConfiguredOn(db) then
      NS.EnsureDiamondSyncHooks()
      NS.SyncCurrentArrowToDiamond()
    end
    NS.Msg("Enabled")
    if db.auto then
      NS.ScheduleAutoRefresh(0)
    end
  elseif action == "off" then
    db.enabled = false
    NS.ClearAutoWaypoints()
    NS.ClearSyncedDiamondWaypoint("addon disabled")
    NS.Msg("Disabled")
  elseif action == "toggle" then
    db.enabled = not db.enabled
    NS.Msg(db.enabled and "Enabled" or "Disabled")
    if db.enabled then
      if IsSyncConfiguredOn(db) then
        NS.EnsureDiamondSyncHooks()
        NS.SyncCurrentArrowToDiamond()
      end
      if db.auto then
        NS.ScheduleAutoRefresh(0)
      end
    else
      NS.ClearAutoWaypoints()
      NS.ClearSyncedDiamondWaypoint("addon disabled")
    end
  elseif action == "clear" then
    NS.ClearWaypoints()
  elseif action == "auto" then
    if arg == "on" then
      db.auto = true
      NS.Msg("Auto routing enabled.")
      NS.ScheduleAutoRefresh(0)
    elseif arg == "off" then
      db.auto = false
      NS.ClearAutoWaypoints()
      NS.Msg("Auto routing disabled.")
    elseif arg == "toggle" then
      db.auto = not db.auto
      if db.auto then
        NS.Msg("Auto routing enabled.")
        NS.ScheduleAutoRefresh(0)
      else
        NS.ClearAutoWaypoints()
        NS.Msg("Auto routing disabled.")
      end
    else
      NS.Msg("Auto routing is " .. (db.auto and "enabled." or "disabled."))
      NS.Msg("Use: /zwp auto on | off | toggle")
    end
  elseif action == "sync" then
    if arg == "on" then
      db.sync = true
      if NS.IsEnabled() then
        NS.EnsureDiamondSyncHooks()
        NS.SyncCurrentArrowToDiamond()
      end
      NS.Msg("3D sync enabled.")
    elseif arg == "off" then
      db.sync = false
      NS.ClearSyncedDiamondWaypoint("sync disabled")
      NS.Msg("3D sync disabled.")
    elseif arg == "toggle" then
      db.sync = not IsSyncConfiguredOn(db)
      if IsSyncConfiguredOn(db) then
        if NS.IsEnabled() then
          NS.EnsureDiamondSyncHooks()
          NS.SyncCurrentArrowToDiamond()
        end
        NS.Msg("3D sync enabled.")
      else
        NS.ClearSyncedDiamondWaypoint("sync disabled")
        NS.Msg("3D sync disabled.")
      end
    else
      NS.Msg("3D sync is " .. (IsSyncConfiguredOn(db) and "enabled." or "disabled."))
      NS.Msg("Use: /zwp sync on | off | toggle")
    end
  elseif action == "status" then
    local syncState = IsSyncConfiguredOn(db) and "on" or "off"
    local syncReady = (NS.State and NS.State.diamondHooksInstalled) and "ready" or "waiting"
    NS.Msg(
      "Addon: "
        .. (db.enabled and "enabled" or "disabled")
        .. ", auto: "
        .. (db.auto and "on" or "off")
        .. ", sync: "
        .. syncState
        .. " ("
        .. syncReady
        .. ")"
    )
  else
    NS.Msg("/zwp on | off | toggle | clear | auto <on|off|toggle> | sync <on|off|toggle> | status")
  end
end

function NS.RegisterSlashCommands()
  if NS.State.slashRegistered then
    return
  end
  NS.State.slashRegistered = true

  SLASH_ZYGORWAYPOINT1 = "/zwp"
  SlashCmdList["ZYGORWAYPOINT"] = HandleRouteCommand

  SLASH_ZYGORWAYPOINTWAY1 = "/way"
  SlashCmdList["ZYGORWAYPOINTWAY"] = HandleWayCommand

  SLASH_ZYGORWAYPOINTCLEAR1 = "/clearway"
  SlashCmdList["ZYGORWAYPOINTCLEAR"] = function()
    NS.ClearWaypoints(false)
  end
end
