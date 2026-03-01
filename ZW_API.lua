local NS = _G.ZygorWaypointNS
local API = NS.API

function API.IsReady()
  return NS.GetPointer() ~= nil
end

function API.SetWaypoint(...)
  local mapID, x, y, opts = ...
  if type(mapID) == "table" then
    mapID, x, y, opts = x, y, opts, select(5, ...)
  end

  if not NS.IsEnabled() and not (type(opts) == "table" and opts.ignoreDisabled) then
    return false
  end

  return NS.SetWaypoint(mapID, x, y, opts)
end

function API.ClearWaypoints(...)
  local opts = ...
  if type(opts) == "table" and opts == API then
    opts = select(2, ...)
  end

  local quiet = false
  if type(opts) == "table" then
    quiet = opts.quiet and true or false
  elseif type(opts) == "boolean" then
    quiet = opts
  end

  return NS.ClearWaypoints(quiet)
end
