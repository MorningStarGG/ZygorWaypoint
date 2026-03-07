local NS = _G.ZygorWaypointNS
local frame = NS.FRAME

frame:RegisterEvent("ADDON_LOADED")

frame:SetScript("OnEvent", function(_, event, ...)

  if event == "ADDON_LOADED" then
    local addonName = ...
    if addonName == NS.ADDON_NAME then
      NS.EnsureDBDefaults()
      NS.InstallAutoHooks()
      NS.EnsureDiamondSyncHooks()
      NS.RegisterSlashCommands()
      if NS.IsSyncEnabled() then
        NS.SyncCurrentArrowToDiamond()
      end

      frame:RegisterEvent("QUEST_WATCH_UPDATE")
      frame:RegisterEvent("QUEST_POI_UPDATE")
      frame:RegisterEvent("WAYPOINT_UPDATE")
      frame:RegisterEvent("ZONE_CHANGED_NEW_AREA")

      if NS.IsAutoEnabled() then
        NS.ScheduleAutoRefresh(0.2)
      end

      local db = NS.GetDB()
      NS.Msg("Loaded. Use /way. Auto routing: " .. (db.auto and "on" or "off") .. ".")
    end
    return
  end

  if not NS.IsAutoEnabled() or NS.AreHooksSuppressed() then
    return
  end

  if event == "QUEST_WATCH_UPDATE" then
    NS.ScheduleAutoRefresh(0.2)
  elseif event == "QUEST_POI_UPDATE" then
    NS.ScheduleAutoRefresh(0)
  elseif event == "WAYPOINT_UPDATE" then
    NS.ScheduleAutoRefresh(0)
  elseif event == "ZONE_CHANGED_NEW_AREA" then
    NS.ScheduleAutoRefresh(0.2)
  end
end)
