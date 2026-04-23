# Changelog

## 3.1

- **Blizzard supertracking and supertracked quest routing**
  - Added a new Blizzard supertracking takeover to the bridge that routes them through Zygor.
  - Added optional auto-routing setting in the options for newly watched Blizzard quests.
  - Added adoption and cleanup for explicit Blizzard map/user waypoints through the same manual routing flow.
  - Quest-backed manual destinations now refresh automatically when quest destinations move and clear when the quest is turned in, removed, untracked, or no longer resolves.

- **Quest-backed manual presentation**
  - Quest-backed manual destinations now carry quest metadata through bridge snapshotting, explicit removal handling, and follow-up routing.
  - Native overlay icons now resolve quest-aware presentation for quest-backed manual and route destinations instead of falling back to generic manual/travel glyphs.
  - Added quest objective / ready-to-turn-in subtext support for supertracked quests.
  - Added native overlay quest cache invalidation so quest icon and subtext changes react correctly to quest log updates.

- **New controls, settings, and help coverage**
  - Added `Auto-Route Tracked Quests` and `Auto-Clear Supertracked Quests on Arrival` settings.
  - Added `/zwp trackroute` and `/zwp questclear` commands plus status output coverage for both toggles.
  - Updated in-game help text for tracked quests, supertracked quest arrival clearing, and related manual clear behavior.
  - Corrected the Steampunk plaque preview asset reference in the help pages.

- **Overlay and Blizzard visual handling**
  - Improved SuperTrackedFrame suppression refresh behavior after login, user waypoint changes, and supertracking changes. This should resolve cases where the Blizzard supertracked diamond became visible.
  - Blizzard supertracked waypoints now integrate more cleanly with arrival auto-clear rules and explicit removal behavior.

- **Performance enhancements**
  - Reduced movement churn by skipping arrow description normalization when the main arrow title is already present.
  - Added route-bundle caching so route title, travel, and semantic resolution are reused while live route inputs stay stable.
  - Reused content-signature and cache-key buffers and added quest type / quest subtext caches to reduce table churn in hot paths.

## 3.0

- **Major addon rewrite**
  - Rebuilt ZygorWaypoint into a more modular system with clearer separation between core logic, bridge behavior, Zygor integration, world overlay systems, interface code, and documentation.
  - Reworked internal state handling for startup, database/version tracking, bridge state, overlay state, and resolver state.
  - Replaced older monolithic behavior with a more structured architecture that is easier to maintain, extend, and debug.

- **New native 3D world overlay system**
  - Added a fully native 3D in-world overlay system for active destinations.
  - Introduced three overlay presentation modes:
    - **Waypoint** for long-range in-world destination display
    - **Pinpoint** for close-range destination presentation
    - **Navigator** for off-screen directional guidance
  - Added smoother transition handling between overlay modes to reduce flicker near handoff thresholds.
  - Added explicit integration with Blizzard navigation frame lifecycle events.
  - Added shared overlay content snapshots so the bridge and overlay stay in sync on destination context.
  - ZygorWaypoint now includes its own native waypoint/overlay system and no longer depends on WaypointUI.
  - WaypointUI can still be used if you prefer it, but it is no longer recommended and is no longer officially supported by ZygorWaypoint.

- **Overlay customization and presentation**
  - Added extensive 3D overlay settings for:
    - enable/disable
    - fade on hover
    - context display mode
    - waypoint size, opacity, scaling limits, and vertical offset
    - beacon style and opacity
    - footer text behavior
    - pinpoint mode, size, opacity, and destination info display
    - navigator size, opacity, distance, and dynamic distance behavior
  - Added multiple pinpoint plaque styles:
    - **Default**
    - **Glowing Gems**
    - **Horde**
    - **Alliance**
    - **Modern**
    - **Steampunk**
  - Added color customization for overlay text, icons, beacon, plaque, animated elements, pinpoint chevrons, and navigator arrow.
  - Added overlay support for multiple icon/content families including guide, manual, corpse, travel, portal, taxi, inn, dungeon, raid, delve, and supported external waypoint sources.

- **Smarter bridge lifecycle and visibility handling**
  - Reworked the TomTom/Zygor bridge around explicit lifecycle and visibility states instead of simple visible/hidden behavior.
  - Hidden-guide handling now better distinguishes normal hidden state, manual/corpse override state, and cinematic state.
  - Added improved transition handling for:
    - login/startup
    - loading screens
    - cinematics and movies
    - death / ghost / alive transitions
    - guide show/hide changes
  - Added coalesced hook-driven tick scheduling and additional debounce/suppression logic to reduce stale fallback arrows and sync issues.
  - Added better tracking for deliberate manual removal versus transient waypoint state changes.

- **Improved TomTom routing and external waypoint support**
  - Reworked startup routing so existing TomTom waypoints can be adopted after both addons finish loading.
  - Added retry handling for early startup cases where Zygor pointer objects are not ready yet.
  - Improved distinction between bridge-owned and external TomTom waypoints.
  - Added source-aware handling for external waypoint creators, including support paths for addons such as:
    - **SilverDragon**
    - **RareScanner**
  - Improved cleanup and follow-up routing behavior for external/manual routes.
  - Manual waypoints now preserve meaningful names instead of falling back to generic waypoint labels.

- **Queue routing for imported /ttpaste waypoints**
  - Added ordered queue support for multi-waypoint imports such as TomTom paste.
  - Added queue state tracking for:
    - queued entries
    - active vs suspended state
    - current active index
    - remaining entries
  - Added queue resume behavior so routing can continue from a later selected queued point instead of restarting the whole run.
  - Manual arrival clear behavior now respects queued routes so only the active queued target auto-clears and advances the queue.

- **Better Zygor extraction and target handling**
  - Reworked waypoint extraction so titles, ownership, source, coordinates, and route semantics are resolved more reliably from live Zygor state.
  - Improved distinction between:
    - guide-owned waypoints
    - manual waypoints
    - corpse waypoints
    - route-like waypoints
    - route proxies
    - pointer-only fallbacks
  - Added better handling for manual route proxy transitions so routed manual destinations do not briefly collapse into incorrect fallback state.
  - Added improved canonical target handling so guide route legs reflect the current guide goal more accurately.
  - Added stronger guide-step suppression checks so forced no-waypoint states remain authoritative.

- **Guide resolver overhaul**
  - Rebuilt the guide resolver as a more structured subsystem rather than a single opaque implementation.
  - Split resolver behavior into clearer responsibilities for facts, live context, scanning, presentation context, snapshot generation, resolution logic, and test cases.
  - Improved goal/title/subtext selection in complex guide situations, including multi-goal steps, detours, helper actions, and fallback cases.
  - Added better route-presentation gating so guide-owned route legs and non-guide targets are handled more cleanly.
  - Added internal resolver case coverage to protect parity and document approved behavior improvements.

- **Overlay icon and quest-type improvements**
  - Added rich quest-type handling for:
    - Normal Quests
    - Daily Quests
    - Weekly Quests
    - Important Quests
    - Campaign Quests
    - Legendary Quests
    - Artifact Quests
    - Calling Quests
    - Meta Quests
    - Recurring/Repeatable Quests
  - Quest families now also track available, incomplete, and complete states using combined Blizzard and Zygor data.
  - Improved travel and destination presentation for special route types such as portal, taxi, inn, dungeon, raid, and delve targets.

- **Arrow presentation improvements**
  - TomTom remains the primary arrow display surface.
  - Reworked the arrow presentation layer around the newer bridge behavior.
  - Preserved and expanded support for the custom Zygor-style TomTom skins:
    - **Starlight**
    - **Stealth**
  - Improved scale handling plus navigation/arrival layout behavior for the custom skins.
  - Added more consistent arrow alignment behavior when anchoring TomTom to Zygor text.
  - Added visual suppression handling for Zygor special travel icon states.
  - Added safer behavior around Zygor arrow visibility and combat-sensitive paths which should help prevent taint issues.

- **Guide viewer presentation improvements**
  - Compact guide mode has been further improved.
  - Added separate compact/background display modes for:
    - visible step rows only until mouseover
    - background fade mode
    - background + line color fade mode
  - Reworked viewer handling to be more robust and less fragile than the earlier compact-mode approach.

- **Search, help, diagnostics, and preview tools**
  - Expanded `/zwp search` support for:
    - common services
    - profession trainers
    - profession workshops
  - Vendor search now falls back to **Repair** when Zygor fails to produce a vendor route.
  - Added a richer in-game help system with pages for:
    - Overview
    - Arrow and Guide
    - World Overlay
    - Waypoint and Navigator
    - Pinpoint and Plaque
    - Customization
    - Commands
    - What’s New
  - Added or expanded command support for:
    - `/zwp help`
    - `/zwp changelog`
    - `/zwp options`
    - `/zwp skin`
    - `/zwp scale`
    - `/zwp routing`
    - `/zwp align`
    - `/zwp manualclear`
    - `/zwp cleardistance`
    - `/zwp compact`
    - `/zwp search`
    - `/zwp repair`
  - Kept support for multiple alias forms where applicable.
  - Added richer diagnostics and preview tooling for resolver output, overlay content/icon families, travel semantics, memory usage, churn/per-tick allocation pressure, plaque previews, and quest-type previews.

- **Settings and UI overhaul**
  - Rebuilt the settings UI around Blizzard’s modern Settings API.
  - Expanded the addon settings into clearer top-level categories:
    - **ZygorWaypoint**
    - **TomTom Arrow**
    - **World Overlay**
    - **World Overlay > Waypoint**
    - **World Overlay > Pinpoint**
    - **World Overlay > Navigator**
  - Added an About card with direct links to Help and What’s New.

- **Upgrade, compatibility, and repair behavior**
  - Added addon version tracking so the addon can determine when to show What’s New and when legacy repair/migration behavior should run.
  - Added one-time legacy 2.x migration/auto-repair behavior for upgrades into 3.0.
  - Added character-scoped handling for WaypointUI recommendation prompts/version tracking as well as SavedVariable cleanup moving from 2.X.
  - The addon now ships its own overlay backend and is no longer limited by the previous WaypointUI compatibility layer.
  - `/zwp repair` now restores the core external settings ZygorWaypoint depends on, including fixing default Zygor and TomTom configuration values.
  - First login after upgrading from 2.X runs the legacy repair automatically.

- **Documentation and changelog delivery**
  - Added dedicated in-game help/changelog data rather than relying only on static README text.
  - Added richer What’s New / changelog presentation in-game.
  - Updated the documented addon surface to better reflect current slash commands, settings UI, help UI, routing behavior, and overlay behavior.

- **Known limitations**
  - Waypoint text now scales based on distance, but due to current Blizzard font-scaling limitations the transition may appear slightly sluggish or step-like instead of perfectly smooth.
  - This is a known limitation and is not fixable right now.

## 2.6

- **Waypoint UI compatibility / repair cleanup**
  - Refactored the Waypoint UI compatibility layer into clearer sections with shared state, named constants, and centralized utility helpers.
  - Added parent-map remapping for restore attempts on maps that cannot host Blizzard user waypoints, using world-position conversion to resolve a valid parent map.
  - Added unsupported-map gating so failed Waypoint UI repairs no longer repeatedly retry on maps where Blizzard navigation cannot render a valid marker.
  - Tightened repair timing so Waypoint UI only attempts session repair while TomTom’s Crazy Arrow is visible, preventing repeated restore attempts during cinematics or loading transitions.
  - Improved session-preservation checks so Blizzard’s destination-reached clear is only suppressed when the mirrored destination should remain visible under Waypoint UI’s own hide-distance user defined settings.

- **Bridge synchronization / stale waypoint handling**
  - Added `DestinationWaypoint` nil-extraction grace handling so fallback destination state survives short Zygor transition windows without lingering on stale arrows.
  - Reset the nil-grace state whenever extraction succeeds or the bridge state is cleared.
  - Tightened clearing rules so if Zygor no longer has a valid navigation title, stale fallback TomTom arrows are removed instead of remaining visible.
  - Improved death handling so TomTom stays synchronized with Zygor’s brief post-death arrow state, then clears in sync instead of disappearing too early or lingering. TomTom goes for a 3 count, King Kong Bundy demands a FIVE count. Ok bad joke, but in some cases Zygor nav text was ~2 seconds behind our death detection and removal of TomTom arrow.
  - Added immediate resync ticks on death, ghost transitions, and loading screens so bridge state recovers faster around zoning, cinematics, and corpse handling.

- **Guide waypoint extraction / title validity**
  - Added shared blank-text and signature helpers, and tightened extraction so guide-owned pointer sources must resolve to a valid non-empty title before being mirrored.
  - Corpse and pointer-only cases continue to use waypoint-owned titles, while normal guide mirrors now reject empty or stale title resolutions.
  - Added visible-guide title checks to better determine when Zygor has a valid active destination versus when fallback state should be dropped.

- **Shared utility cleanup**
  - Added a new `ZWP_Util.lua` module for shared helpers such as `GetTomTom`, `GetTomTomArrow`, `IsBlankText`, `GetPlayerMapID`, and `Signature`.
  - Updated TOC load order to ensure the shared utility module loads before dependent files.
  - Removed duplicated helper implementations across the TomTom bridge, Waypoint UI compatibility layer, arrow theme bridge, and settings UI.

## 2.5a

- **Mirrored title / fallback fixes**
  - Adjusted mirrored title priority so labels used by TomTom & Waypoint UI prefer the current Zygor navigation text before falling back to broader goal or step titles when building TomTom and Waypoint UI labels.
  - Mirrored waypoints will now refresh when the resolved title changes, in addition to when the destination coordinates change.
  - Adjusted the `pointer.waypoints[1]` fallback so stale or unrelated entries are ignored unless they belong to the current step/goal or are valid manual waypoints.

## 2.5

- **Waypoint UI compatibility**
  - Added a dedicated compatibility layer to keep TomTom-mirrored Zygor destinations labeled correctly in Waypoint UI.
  - Stabilized mirrored waypoint coordinates for Waypoint UI’s one-decimal tracking, fixing generic `Map Pin` labels caused by rounding-boundary coordinates.
  - Added handling for Blizzard’s destination-reached supertracking clear so Waypoint UI no longer drops early ensuring the mirrored waypoint remains visible under its own user configured hide-distance settings.
  - Added a fallback session restore path so temporary Waypoint UI clears (from TomTom arrow hides or scene transitions) correctly rebuild the marker and title when the mirrored waypoint is still active.

- **Guide waypoint extraction / suppression**
  - Reworked title extraction so mirrored TomTom and Waypoint UI destinations use improved non-empty Zygor text fallbacks (arrow title, waypoint title, current goal text, and step title).
  - Guide steps flagged with `|noway` / `force_noway` are now treated as authoritative waypoint suppression, preventing fallback to stale pointer data or unrelated step coordinates.
  - Visible guide steps with suppressed or missing coordinates now clear the mirrored TomTom arrow instead of lingering on stale destinations.

- **Startup / combat safety**
  - Deferred Zygor-specific bridge activity until `PLAYER_LOGIN`, and blocked bridge ticks before login to avoid interacting with Zygor during its startup coroutine window.
  - Guarded forced Zygor arrow visibility refreshes during combat to prevent protected `Button:Show()` / `UpdateArrowVisibility()` taint errors during manual waypoint handoff.

- **Diagnostics**
  - Expanded `/zwp debug` with user waypoint and supertracking trace hooks (`ClearAllSuperTracked`, `SetUserWaypoint`, `ClearUserWaypoint`, `SUPER_TRACKING_CHANGED`, `USER_WAYPOINT_UPDATED`) to make Blizzard, Waypoint UI, and TomTom interaction issues easier to diagnose.

## 2.4a
- **Globals & Linting cleanup**
  - Cleaned up LUA warnings across the bridge, routing, commands, UI, and custom arrow theme files by replacing direct global lookups with safer `_G[...]` accessors and small local helpers.
  - Added a targeted diagnostic suppression for the valid `HereBeDragons:GetPlayerZonePosition(true)` method call, which some editors incorrectly flag because of LUA method-call syntax.
  - Adjusted a few local variable shapes in the custom arrow theme bridge so editor type inference no longer reports false-positive cast warnings.

## 2.4
- **Scene / cinematic handling**
  - Added bridge handling for cinematic cutscenes and other UI-hidden states (including Vista Points) so waypoint state is preserved. Detection prioritizes event-driven cinematics, then falls back to full UI-hidden states, with clean resynchronization afterward.
  - Manual destinations now restore correctly after cinematic or scene transitions.

- **Guide / mirror synchronization**
  - When Zygor has no extractable coordinates for a guide step, the mirrored TomTom arrow now clears instead of lingering on a stale waypoint.
  - Improved post-cinematic recovery so bridge state and TomTom interaction behavior are restored reliably after the UI returns.

- **Arrow theme fixes**
  - Fixed an issue with Zygor Starlight/Stealth skins where steps could leave the arrow visually stuck instead of switching cleanly between navigation and arrival states.
  - Arrow themes now track navigation and arrival states explicitly instead of inferring them from textures after reapplication.

- **Diagnostics**
  - Added `/zwp diag` to monitor live scene and arrow state changes for troubleshooting cinematic, Vista Point, and UI presentation issues.

- **Documentation**
  - Removed duplicated historical version notes and cleaned up the README.

## 2.3c
- **TomTom / Zygor startup synchronization**
  - Deferred TomTom → Zygor routing until Zygor's pointer arrow frame is fully initialized, preventing startup LUA errors when other addons create TomTom waypoints early during login or `/reload`.
  - Added a startup adoption pass so existing TomTom waypoints can be picked up by Zygor once both addons finish loading, including cases where the guide viewer starts hidden.

- **Waypoint clear synchronization**
  - Improved timing when Zygor clears waypoints so the mirrored TomTom arrow updates on the next frame instead of waiting for the bridge heartbeat.
  - Clearing the mirrored TomTom waypoint now also clears the linked Zygor manual destination, including the lingering Zygor navigation text and manual pin during TomTom reset/remove actions.

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
