local NS = _G.ZygorWaypointNS
local C = NS.Constants
local M = NS.Internal.Interface.options
local DEFAULTS = M.DEFAULTS
local ShowReloadRecommendedPopup = M.ShowReloadRecommendedPopup
local RefreshViewerChromeMode = M.RefreshViewerChromeMode
local AddCheckbox = M.AddCheckbox
local AddSlider = M.AddSlider
local AddDropdown = M.AddDropdown

local function CreateGuideStepBackgroundHoverOptions()
    local container = Settings.CreateControlTextContainer()
    container:Add(C.GUIDE_STEP_BACKGROUND_MODE_BG, "Hide Step Backgrounds")
    container:Add(C.GUIDE_STEP_BACKGROUND_MODE_BG_GOAL, "Hide Step Backgrounds + Line Colors")
    container:Add(C.GUIDE_STEP_BACKGROUND_MODE_NONE, "Disabled")
    return container:GetData()
end

function M.AddGeneralOptions(category)
    AddCheckbox(
        category,
        "GUIDE_STEPS_ONLY_HOVER",
        "Show Only Guide Steps Until Mouseover",
        DEFAULTS.guideStepsOnlyHover,
        "Keeps the visible guide step rows on screen while fading out the rest of Zygor's guide frame until you mouse over it.",
        function()
            return NS.IsGuideStepsOnlyHoverEnabled()
        end,
        function(value)
            NS.SetGuideStepsOnlyHoverEnabled(value)
            RefreshViewerChromeMode()
        end
    )

    AddDropdown(
        category,
        "GUIDE_STEP_BACKGROUNDS_HOVER",
        "Hide Step Backgrounds Until Mouseover",
        DEFAULTS.guideStepBackgroundsHover,
        function()
            return NS.GetGuideStepBackgroundsHoverMode()
        end,
        function(value)
            NS.SetGuideStepBackgroundsHoverMode(value)
            RefreshViewerChromeMode()
        end,
        CreateGuideStepBackgroundHoverOptions,
        "Controls which guide step row backgrounds fade out while Show Only Guide Steps Until Mouseover is compacting the guide frame."
    )

    AddCheckbox(
        category,
        "ARROW_ALIGNMENT",
        "Align TomTom Arrow to Zygor Text",
        DEFAULTS.arrowAlignment,
        "When enabled, TomTom's Crazy Arrow anchors to Zygor's arrow frame position.",
        function()
            return NS.GetDB().arrowAlignment ~= false
        end,
        function(value)
            local db = NS.GetDB()
            local oldValue = db.arrowAlignment ~= false
            local newValue = value and true or false
            db.arrowAlignment = newValue
            if value then
                NS.AlignTomTomToZygor()
                NS.HookUnifiedArrowDrag()
            end
            if oldValue ~= newValue then
                ShowReloadRecommendedPopup("Align TomTom Arrow to Zygor Text")
            end
        end
    )

    AddCheckbox(
        category,
        "ZYGOR_ROUTING",
        "Route TomTom Waypoints via Zygor",
        DEFAULTS.zygorRouting,
        "When enabled, TomTom waypoints are routed through Zygor's travel system.",
        function()
            return NS.IsRoutingEnabled()
        end,
        function(value)
            local db = NS.GetDB()
            db.zygorRouting = value and true or false
        end
    )

    AddCheckbox(
        category,
        "MANUAL_QUEUE_AUTO_ROUTING",
        "Auto-Route Imported Manual Queue",
        DEFAULTS.manualQueueAutoRouting,
        "When enabled, imported waypoints from /ttpaste will queue them. Clearing the active queued waypoint advances to the next queued point with wrap-around. If you leave the queue then reselect a queued TomTom waypoint the queue will resume from that point.",
        function()
            return NS.IsManualQueueAutoRoutingEnabled()
        end,
        function(value)
            NS.SetManualQueueAutoRoutingEnabled(value)
        end
    )

    AddCheckbox(
        category,
        "MANUAL_AUTO_CLEAR",
        "Auto-Clear Manual Waypoints on Arrival",
        DEFAULTS.manualWaypointAutoClear,
        "When enabled, ZygorWaypoint clears the active manual destination when you enter the selected range. Imported queued waypoints (such as from /ttpaste) only auto-clear while they are the active queued waypoint. Nearest NPC searches are not auto-cleared.",
        function()
            return NS.IsManualWaypointAutoClearEnabled()
        end,
        function(value)
            NS.SetManualWaypointAutoClearEnabled(value)
        end
    )

    AddSlider(
        category,
        "MANUAL_CLEAR_DISTANCE",
        "Manual Waypoint Clear Distance",
        DEFAULTS.manualWaypointClearDistance,
        C.MANUAL_CLEAR_DISTANCE_MIN,
        C.MANUAL_CLEAR_DISTANCE_MAX,
        C.MANUAL_CLEAR_DISTANCE_STEP,
        function(value)
            return string.format("%d yd", NS.NormalizeManualWaypointClearDistance(value))
        end,
        "Clears the active waypoint when you arrive within this many yards. Imported queued waypoints (such as from /ttpaste) ignore this distance unless they are the active queued waypoint.",
        function()
            return NS.GetManualWaypointClearDistance()
        end,
        function(value)
            NS.SetManualWaypointClearDistance(value)
        end
    )

    AddCheckbox(
        category,
        "TRACKED_QUEST_AUTO_ROUTE",
        "Auto-Route Tracked Quests",
        DEFAULTS.trackedQuestAutoRoute,
        "When enabled, tracking a quest will set the quest as your current waypoint.",
        function()
            return NS.IsTrackedQuestAutoRouteEnabled()
        end,
        function(value)
            NS.SetTrackedQuestAutoRouteEnabled(value)
        end
    )

    AddCheckbox(
        category,
        "SUPERTRACKED_QUEST_AUTO_CLEAR",
        "Auto-Clear Supertracked Quests on Arrival",
        DEFAULTS.superTrackedQuestAutoClear,
        "When enabled, supertracked Blizzard quests — including tracked quests — use Auto-Clear Manual Waypoints on Arrival and the Manual Waypoint Clear Distance. When disabled, they ignore arrival distance, just like guide-driven quest routes. Blizzard quest routes still always clear when the quest is turned in, untracked, removed from the log, or no longer resolves.",
        function()
            return NS.IsSuperTrackedQuestAutoClearEnabled()
        end,
        function(value)
            NS.SetSuperTrackedQuestAutoClearEnabled(value)
        end
    )
end
