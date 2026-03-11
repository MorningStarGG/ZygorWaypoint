# Changelog

## 2.1

- **Guide visibility handling**
  - Clears the active guide step waypoint when the Zygor guide frame is hidden.
  - TomTom Crazy Arrow and Zygor Travel System text remain active while the guide is hidden, but guide step goals are disabled.
  - Manual waypoints and Zygor travel routing continue to function normally while the guide is hidden.
  - Guide step waypoints refresh automatically when the guide becomes visible again or when a manual waypoint is completed or cleared.
  - Forces Zygor's `hidearrowwithguide` policy off so arrow visibility remains under ZygorWaypoint control.

- **Command / settings cleanup**
  - Removed obsolete `/zwp on` and `/zwp off` commands.
  - Legacy `enabled` values are automatically cleared from SavedVariables on load.

- **Options / UI**
  - Resolved Lua errors triggered when opening the options panel that caused `/zwp options` command to not open the settings panel.

- **Documentation**
  - Updated command and documentation text to match the current `/zwp` command set.

## 2.0

- Packaging:
  - dependencies are now hard-required: `TomTom`, `ZygorGuidesViewer`.
- Command contract changed to `/zwp` only.
  - Added bridge-focused subcommands: `on`, `off`, `status`, `debug`, `skin`, `scale`, `options`, `routing`, `align`, `override`.
- Bridge features:
  - Zygor waypoint extraction -> TomTom Crazy Arrow updates.
  - TomTom waypoint routing -> Zygor travel/pathing -> TomTom Crazy Arrow.
  - Zygor Starlight theme support for TomTom arrow.
  - Starlight-only visual arrow scale control without overwriting TomTom profile scale.
- UI/docs refresh:
  - Added AddOns options panel text and control wiring.
  - Rewrote README for v2.0 behavior and clean-break scope.

## Legacy

### v1.2

* Added `/zwp sync on | off | toggle` to control whether the Blizzard supertracked waypoint (3D diamond) mirrors the active Zygor arrow target
* `/zwp status` now reports sync state in addition to addon and auto-routing state

### v1.1

* Manual waypoints now function even when auto-routing is disabled (`/zwp auto off`) — useful for addons like SilverDragon (CTRL+Left-Click target popup)
* Improved map resolution logic by deferring to Zygor for lookup with smarter fallbacks for more reliable `/way <x> <y>` and `/way <zone\|#mapID> <x> <y>` handling
* Blizzard triangle map pins now automatically revert to the active Zygor guide step upon arrival and clean up the associated map pin
* User-placed pins (red dots) persist after arrival while still routing through Zygor’s travel arrow
* `/zwp clear` and `/clearway` now properly restore routing to the current Zygor guide step after clearing a manual waypoint

### v1.0b

* Fixed setting persistence so `/zwp auto off` now survives `/reload` and full client restart
* Simplified SavedVariables handling to use `ZygorWaypointDB`
* Removed redundant persistence scaffolding/events and cleaned up DB access flow

### v1.0a

* `/zwp status` command for quick addon and auto-routing state checks
* Addon enable/disable toggle via `/zwp on | off | toggle`
* Control command moved to `/zwp` (from `/zw`) to avoid slash conflicts with Zygor

### v1.0 - Initial Release

* Direct waypoint commands via `/way`
* `/clearway` and `/zwp clear` support
* Auto-routing from Blizzard map/quest supertracking
* `/zwp auto on | off | toggle` for auto-routing control
* Public API: `SetWaypoint`, `ClearWaypoints`, `IsReady`
