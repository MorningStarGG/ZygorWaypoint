# Changelog

## 2.3b
- **Guide viewer compact mode**
  - Reworked the compact viewer implementation to stop replacing methods on the Zygor guide viewer frame.
  - Switched to a hook-and-restore approach that preserves our current hover behavior while avoiding LUA taint (somehow) issues discovered in Blizzard unit and nameplate code.

## 2.3a
- **Guide viewer compact mode**
  - Fixed a compact-mode restore issue where parts of Zygor's normal viewer border/background could remain suppressed after turning the feature back off.
  - Turning compact mode off now forces an immediate full guide viewer restore instead of requiring a `/reload` to get the normal guide viewer frame back.

- **Documentation**
  - Updated the README settings list to reflect the current options, including manual waypoint auto-clear and its configurable clear distance.
  - Adjusted wording to match the current UI label for TomTom waypoint routing through Zygor.

## 2.3
- **Guide viewer compact mode**
  - Added an option to show only the visible guide step rows, similar to the old "Mini Mode with Tooltip" Zygor previously offered.
  - Hovering over the Zygor guide viewer temporarily restores the full guide viewer until mouse is no longer over the guide viewer.

- **Manual waypoint arrival clearing**
  - Added an optional auto-clear feature for manual waypoints with a configurable arrival distance (yards).
  - When a manual destination auto-clears, the mirrored TomTom pin, Blizzard user waypoint, and supertracking state are also cleared.
  - Zygor travel routing is not affected, intermediate travel steps remain intact and auto-clear only applies to the final destination waypoint.

- **Options / UI**
  - Rebuilt the addon options panel using Blizzard's newer Settings layout.
  - Most options now apply without needing a UI reload. Settings that cannot update fully live will instead display a reload-recommended prompt.
  - Added slash commands for the new manual waypoint auto-clear and compact viewer features: `/zwp manualclear`, `/zwp cleardistance`, and `/zwp compact`.

- **Search fixes**
  - Refined vendor fallback handling so the repair fallback only triggers when a vendor search truly fails.
  - Chat feedback now reflects the fallback behavior more accurately.

## 2.2
- **Hidden guide / waypoint control**
  - Added runtime guards around Zygor's guide waypoint rebuild path so guide-step navigation text remain suppressed while the guide viewer is hidden. This fixes cases where guide steps could still attempt to take control when the viewer was hidden.
  - Manual destinations remain fully functional while the guide is hidden, using the Zygor navigation text and TomTom arrow as before.
  - Improved hidden-guide cleanup during login and reload, resulting in more reliable bridge-state resets.

- **Pin / waypoint cleanup**
  - Clearing the mirrored bridge waypoint now also clears the Blizzard user waypoint and supertracking state.
  - Duplicate TomTom pins at the active bridge coordinates are now removed before applying the mirrored waypoint, fixing cases where pins were not being removed properly when a waypoint was cleared.

- **Performance / memory**
  - Removed per-frame table allocations in the custom Zygor → TomTom skins by caching navigation texture coordinates in scalar fields.
  - Bridge sync updates are no longer triggered from Zygor's hot `UpdateFrame()` redraw path and instead rely on the bridge heartbeat for visible-guide refreshes.
  - Reduced repeated allocation churn during Zygor waypoint extraction and title cleanup.

- **Search commands**
  - Added `/zwp search` support for Zygor service lookups including vendor, auctioneer, banker, innkeeper, flightmaster, mailbox, repair, riding trainer, stable master, transmogrifier, and void storage.
  - Added profession trainer and profession workshop searches, along with `/zwp search help`.
  - Added friendly aliases such as `ah`, `auction`, `bank`, `inn`, `mog`, `tmog`, `store`, `repairs`, and `stables`.
  - Vendor searches now fall back to `Repair` if Zygor's vendor lookup fails to place a waypoint, including when the search originates from Zygor's menu. ZWP will tell you when this occurs.

- **Documentation**
  - Updated the README command list to include the new search commands.

## 2.1b
- **Arrow theme fixes**:
  - Fixed an intermittent issue where Starlight or Stealth could briefly show the full arrow sprite sheet during waypoint updates or theme refreshes.

## 2.1a
- **Zygor Arrow themes**:
  - Added Zygor Stealth TomTom skin alongside Starlight.
  - `/zwp skin` can now switch between `default`, `starlight`, and `stealth`.
  - The options panel can now switch between `starlight`, and `stealth`.
  - Zygor skin scale and alignment spacing now apply to both custom TomTom skins.
  - Specular fixes
  - Hidden-arrow cleanup now avoids calling Zygor's arrow hide path before it exists.

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
  - Dependencies are now hard-required: `TomTom`, `ZygorGuidesViewer`.
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
