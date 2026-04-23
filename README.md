# ZygorWaypoint

> A navigation bridge and 3D world overlay for **Zygor Guides Viewer** and **TomTom** — using **TomTom's Crazy Arrow for navigation** while **Zygor handles travel routing and pathfinding**.

![Version](https://img.shields.io/badge/version-3.1c-blue) ![Game](https://img.shields.io/badge/World%20of%20Warcraft-Addon-orange) ![Requires](https://img.shields.io/badge/Requires-Zygor%20Guides%20and%20TomTom-red)


------------------------------------------------------------------------

# Overview

**ZygorWaypoint** connects **Zygor Guides Viewer** and **TomTom** so they behave like a single navigation system.

- **TomTom provides the arrow**
- **Zygor provides the travel routing**
- **ZygorWaypoint keeps guide destinations, manual waypoints, and presentation in sync**
- **ZygorWaypoint adds a native in-world overlay above your target**

When a **Zygor** guide step changes, ZygorWaypoint mirrors that destination to **TomTom's Crazy Arrow**.

When a waypoint is created in **TomTom** — by you or by another addon — ZygorWaypoint can send that destination through **Zygor's Travel System** so Zygor can calculate the best route using flight paths, portals, hearthstones, teleports, and more.

In short:

**TomTom shows the arrow — Zygor calculates the route.**

## How It Works

```text
Zygor guide step  -> ZygorWaypoint -> TomTom Crazy Arrow
                                    -> Native World Overlay

TomTom waypoint   -> ZygorWaypoint -> Zygor Travel Routing -> TomTom Crazy Arrow
                                                            -> Native World Overlay
```

---

### Why?

ZygorWaypoint is built for players who want a cleaner, more unified navigation setup.

- Use **TomTom's Crazy Arrow** while following Zygor guides
- Route **TomTom waypoints through Zygor's travel system**
- See a **3D in-world marker** directly above your destination
- Keep **guide steps, manual waypoints, routing, and overlay presentation** working together
- Add quality-of-life tools like **search commands**, **manual queue routing**, **auto-clear**, **compact guide mode**, and **in-game help** 

ZWP does all of this while remaining compatible with the broader WoW addon ecosystem and TomTom integrations.

------------------------------------------------------------------------

# Requirements

ZygorWaypoint requires:

-   **TomTom**
-   **Zygor Guides Viewer**

Both addons must be installed and enabled.

## WaypointUI

`3.0` is built around ZygorWaypoint's own 3D overlay system.

**WaypointUI can still be used if you want**, but it is no longer the recommended setup and is no longer officially supported by ZygorWaypoint.

------------------------------------------------------------------------

# 3.0 Highlights

- **Major addon rewrite** Rebuilt ZygorWaypoint into a more modular system with clearer separation between core logic, bridge behavior, Zygor integration, world overlay systems, interface code, and documentation.
- **3D World Overlay** with in-world waypoint, pinpoint, and navigator presentation and **replaces** our former Waypoint UI compatibility layer
- **Quest-aware and destination-aware overlay icons**
- **Improved TomTom waypoint routing through Zygor** for a more unified travel flow
- **Waypoint queue routing** for imported `/ttpaste` runs
- **Improved hidden-guide, cinematic, death, loading, and startup handling**
- **Manual waypoints now preserve meaningful names**
- **In-game help & Changelog**
- **Modernized settings layout** with dedicated overlay categories

------------------------------------------------------------------------

# Features

## Zygor -> TomTom Arrow Bridge

Zygor guide steps automatically update **TomTom's Crazy Arrow**.

This lets you follow Zygor guides while using TomTom's arrow instead of Zygor's built-in arrow display.

ZygorWaypoint also manages guide and arrow behavior more cleanly:

- When the **guide frame is hidden**, guide step destinations stop taking over the arrow
- **TomTom navigation and Zygor travel routing remain active**
- **Manual waypoints** continue to work while the guide is hidden
- When the guide becomes visible again, guide-step navigation resumes when appropriate. If a manual waypoint or active travel route is in progress, the guide step navigation will resume only after that destination/waypoint is completed or cleared.
- Zygor's arrow graphic is hidden while keeping Zygor's travel text visible

------------------------------------------------------------------------

## TomTom → Zygor Travel Routing

ZygorWaypoint can optionally (enabled by default) route **TomTom waypoints** through **Zygor's Travel System**.

When a waypoint is created through **TomTom** (either manually or by another addon), ZygorWaypoint sends that destination to Zygor so it can calculate the best route to reach it.

Zygor's travel system may include:

- Flight paths
- Portals
- Teleports
- Spells
- Hearthstones
- Manual flying/travel

Travel behavior is controlled by **Zygor's Travel System settings**.

Travel behavior (flight paths, portals, etc.) is controlled by Zygor and you can adjust them in:

`Zygor Settings → Waypoint Arrow → Travel System`

------------------------------------------------------------------------

## 3D World Overlay

`3.0` adds a full native in-world overlay that renders directly above your destination.

It automatically switches between three presentation modes:

- **Waypoint** for long-range in-world destination display
- **Pinpoint** for close-range destination display
- **Navigator** for off-screen directional guidance

The overlay is destination-aware and can present different icon families for:

- guide targets
- manual waypoints
- corpse markers
- travel targets such as flightpaths, portals, inns, dungeons, raids, and delves
- supported addon waypoint sources such as **SilverDragon** and **RareScanner**
- quest types and quest states
- search results such as services and profession targets

You can customize the overlay with options for:

- size and opacity
- fade on hover
- context display style
- beacon style
- pinpoint plaque style
- navigator behavior
- color presets and custom colors
- displayed text and destination info

## Pinpoint Plaque Styles

The close-range pinpoint display supports six plaque styles:

- **Default**
- **Glowing Gems**
- **Horde**
- **Alliance**
- **Modern**
- **Steampunk**

More are on the way, if you have any you'd like to see let me know and we'll see what can be done!

------------------------------------------------------------------------

## Manual Waypoint Auto-Clear

ZygorWaypoint can automatically clear manual waypoints when you arrive at the destination.

When a manual waypoint auto-clears:

- the **TomTom pin** is removed
- the **Blizzard user waypoint** is cleared
- **supertracking** is reset

The arrival distance is configurable.

------------------------------------------------------------------------

## Manual Waypoint Queue

ZygorWaypoint can queue imported manual waypoint runs for sequential routing.

This is especially useful with **/ttpaste**

With **Manual Queue Auto-Routing** enabled:

- imported waypoints are queued in order
- the first target is routed immediately
- clearing or arriving at the active queue target (when `Manual Waypoint Auto-Clear is enabled`) will advance the queue
- routing continues until the queue is finished. Skipped waypoints will wrap around and remain in the queue until all queued waypoints have been cleared

------------------------------------------------------------------------

## Blizzard Supertracking and Tracked Quests

ZygorWaypoint can also work with Blizzard’s built-in quest and waypoint supertracking.

When enabled:

- a **supertracked Blizzard quest** now becomes a manual Zygor-routed destination
- a newly **tracked quest** can be auto-routed without needing to be supertracked first
- explicit **Blizzard map/user waypoints** can be adopted through the same routing flow

Supertracked Blizzard quests behave more like guide-driven waypoints.

Regular Blizzard supertracked waypoints behave like Zygor-routed manual waypoints.

### Available Controls

- **Auto-Route Tracked Quests** automatically routes newly watched Blizzard quests
- **Auto-Clear Supertracked Quests on Arrival** makes supertracked quest routes use the same arrival-clear distance as manual waypoints

If supertracked quest auto-clear is disabled, those routes behave more like guide-driven quest routes and do not clear just because you entered the manual arrival radius.

Supertracked quests still clear when the quest is:

- turned in
- untracked
- removed from the quest log
- no longer resolvable to a destination

Relevant slash commands:

- `/zwp trackroute on|off|toggle`
- `/zwp questclear on|off|toggle`

------------------------------------------------------------------------

## Arrow Appearance and Alignment

ZygorWaypoint uses **TomTom** as the arrow, but for users who prefer the Zygor look it also supports Zygor's arrow skins:

- **Starlight** and **Stealth** skins can be applied to TomTom's arrow so it visually matches Zygor's guide
- arrow scale control for the Zygor skins
- ZygorWaypoint hides Zygor's arrow graphic while leaving Zygor's travel text visible.
- optional alignment of TomTom's arrow with Zygor's travel text

This gives you a cleaner combined interface without showing duplicate arrows.

------------------------------------------------------------------------

## Guide Viewer Compact Mode

ZygorWaypoint includes an optional compact guide presentation mode.

When enabled:

- only the visible guide step rows remain shown
- the rest of the viewer stays reduced to cut clutter
- hovering over the guide temporarily restores the full view
- optional background fade modes can reduce visual noise further

------------------------------------------------------------------------

## In-Game Help and What's New

ZygorWaypoint now includes a built-in help and changelog system.

`Game Menu -> Options -> AddOns -> ZygorWaypoint`

Click on either `Help` or `What's New`

This makes it easier to learn the addon without relying only on the README.

------------------------------------------------------------------------

# Options Panel

Location:

`Game Menu -> Options -> AddOns -> ZygorWaypoint`

The `3.0` settings are organized into clearer categories:

- **ZygorWaypoint**
- **TomTom Arrow**
- **World Overlay**
- **World Overlay > Waypoint**
- **World Overlay > Pinpoint**
- **World Overlay > Navigator**

## General

General settings cover things like:

- TomTom -> Zygor routing
- arrow alignment
- compact guide presentation
- guide background fade behavior
- tracked quest auto-routing
- supertracked quest arrival auto-clear
- manual queue auto-routing
- manual waypoint auto-clear and clear distance

## TomTom Arrow

Arrow settings cover:

- enabling a Zygor-style skin for TomTom
- choosing **Starlight** or **Stealth**
- adjusting arrow scale

## World Overlay

Overlay settings cover:

- enable / disable
- hover fade
- context display behavior
- waypoint presentation
- pinpoint presentation
- navigator presentation
- overlay color customization
- plaque style and close-range display behavior

Settings apply immediately without requiring a reload.

-----------------------------------------------------------------------

# Slash Commands

Root command:

`/zwp`

## Main Commands

| Command | Description |
|---------|-------------|
| `/zwp status` | Show addon status and key settings |
| `/zwp options` | Open addon options |
| `/zwp help` | Open the in-game help guide |
| `/zwp changelog` | View recent changes in-game |
| `/zwp routing on\|off\|toggle` | Control TomTom -> Zygor routing |
| `/zwp align on\|off` | Toggle arrow alignment |
| `/zwp manualclear on\|off\|toggle` | Toggle auto-clear for manual waypoints |
| `/zwp cleardistance <5-100>` | Set the manual waypoint auto-clear distance |
| `/zwp trackroute on\|off\|toggle` | Toggle auto-routing for newly tracked Blizzard quests |
| `/zwp questclear on\|off\|toggle` | Toggle arrival auto-clear for supertracked Blizzard quest routes |
| `/zwp compact on\|off\|toggle` | Toggle compact guide mode |
| `/zwp search <type>` | Route to a supported search target |
| `/zwp skin default\|starlight\|stealth` | Change arrow appearance |
| `/zwp scale <0.60-2.00>` | Adjust custom arrow skin scale |
| `/zwp repair` | Restore expected external settings |

------------------------------------------------------------------------

## NPC/Object Search Commands

ZygorWaypoint can quickly route you to common NPCs and objects using `/zwp search`.

Example:

```text
/zwp search vendor
```

Supported services include:

- vendor
- barber
- auctioneer
- banker
- innkeeper
- flightmaster
- mailbox
- repair
- transmogrifier
- void storage
- stable master
- riding trainer

Profession helpers are also available:

```text
/zwp search trainer blacksmithing
/zwp search workshop engineering
```

Several common aliases are also supported:

- `ah`
- `auction`
- `bank`
- `inn`
- `mog`
- `tmog`
- `store`
- `repairs`
- `stables`

If a vendor search fails to locate a vendor NPC, ZygorWaypoint will automatically fall back to searching for a nearby **Repair NPC**.

------------------------------------------------------------------------

# Installation

1.  Download the addon
2.  Place the **ZygorWaypoint** folder into:

`World of Warcraft/_retail_/Interface/AddOns/`

3.  Enable the following addons:

-   TomTom
-   Zygor Guides Viewer
-   ZygorWaypoint

------------------------------------------------------------------------

# Compatibility and Upgrade Notes

ZygorWaypoint should work with any of the many addons that create TomTom waypoints.

Known source-aware handling includes:

- **SilverDragon**
- **RareScanner**

Other TomTom-based waypoint sources should still work through normal routing behavior.

Examples include:

-   HandyNotes
-   Paste
-   Coordinate sharing macros
-   Other TomTom‑compatible addons

If an addon creates a TomTom waypoint, ZygorWaypoint can route it through Zygor's travel system.

-----------------------------------------------------------------------

## Upgrading from 2.x

`3.0` is a major update.

Important changes:

- the addon now uses its own 3D overlay system
- the old WaypointUI compatibility layer is gone
- legacy `2.x` installs can trigger a one-time repair / migration path
- version tracking and more settings cleanup now happen automatically
- `/zwp repair` restores the external settings ZygorWaypoint expects

------------------------------------------------------------------------

# Notes and Limitations

- **Manual waypoints now preserve meaningful names** instead of falling back to generic waypoint labels.
- **WaypointUI can still be used**, but `3.0` is built around ZygorWaypoint's own 3D overlay and WaypointUI is no longer officially supported by this addon.
- **Waypoint text can scale by distance**, but because of current Blizzard font-scaling limitations the transition may appear slightly step-like or less smooth than intended. This is a known limitation for now. In usage it shouldn't have much of any affect and was an acceptable tradeoff to make things nicer overall

------------------------------------------------------------------------

# Changelog

## 3.1c

- **`Auto-Route Tracked Quests` setting fixes**
  - Auto-routing from quest tracking/watching is fully suppressed while the Zygor guide is visible, regardless of the Auto-Route setting.
  - Explicitly clicking a quest POI button routes and tracks the quest even when the guide is visible, since that is a deliberate navigation action and is considered a manual waypoint.
  - Explicitly-clicked quest destinations continue to receive destination/progress updates while the guide is visible.
  - When the guide is hidden, auto-tracking works normally per the Auto-Route setting.

## 3.1b

- **Quest takeover reliability**
  - Quest takeover destinations that are initially unresolved now retry, fixing cases where quest data wasn't ready at the moment of supertracking or watch.
  - Pending adoption retries are cancelled immediately when the supertracked quest changes, is cleared, or the watch is removed, preventing stale routes from firing.

- **World overlay fixes**
  - World overlay is now suppressed on maps that do not support user waypoints via C_Map.CanSetUserWaypointOnMap. TomTom and Zygor navigation continue working normally on those maps when supported.

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

For older versions including the 2.X and 1.X versions see the full [CHANGELOG](CHANGELOG.md)

------------------------------------------------------------------------

## Author

ZygorWaypoint was created and is maintained by **MorningStarGG**.

* 📺 **Twitch:** [twitch.tv/MorningStarGG](https://www.twitch.tv/MorningStarGG)
* 🎮 **Battletag:** `MorningStar#1136`

Feel free to stop by the stream — Community, CHAOS, Professionally trained idiot.

------------------------------------------------------------------------

## Contributing

Found a bug or have a feature request? Open an issue or submit a pull request — contributions are welcome.

------------------------------------------------------------------------

## License

*This addon is provided as-is under the GPL-3.0 [license](LICENSE). You are free to modify and distribute it according to your needs.*

------------------------------------------------------------------------

**AI Disclaimer:** Parts of this was made with various AI tools to speed development time.
