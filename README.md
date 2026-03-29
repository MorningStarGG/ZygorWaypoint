# ZygorWaypoint

> A bridge addon that lets **Zygor Guides** and **TomTom** work together --- using **TomTom's Crazy Arrow for navigation** while **Zygor handles travel routing and pathfinding**.

![Version](https://img.shields.io/badge/version-2.5a-blue) ![Game](https://img.shields.io/badge/World%20of%20Warcraft-Addon-orange) ![Requires](https://img.shields.io/badge/Requires-Zygor%20Guides%20and%20TomTom-red)


------------------------------------------------------------------------

# Overview

**ZygorWaypoint** connects **Zygor Guides Viewer** and **TomTom** so they can share waypoint information.

The goal is simple:

- **TomTom provides the navigation arrow**
- **Zygor provides the travel routing**

When a Zygor guide step changes, the destination is sent to **TomTom's Crazy Arrow** so navigation is displayed using TomTom's arrow instead of Zygor's.

When a waypoint is created in **TomTom** (manually or by another addon), ZygorWaypoint sends that waypoint to **Zygor's travel system** so Zygor can calculate the best route to reach the destination.

After the route is calculated, navigation still happens using **TomTom's Crazy Arrow**.

In short:

**TomTom shows the arrow — Zygor calculates the route.**

## How It Works

Zygor guide step → ZygorWaypoint → TomTom Crazy Arrow

TomTom waypoint  → ZygorWaypoint → Zygor Travel Routing → TomTom Crazy Arrow

### Why?

The goal is to maintain a **single navigation arrow** while remaining compatible with the broader WoW addon ecosystem and TomTom integrations.

------------------------------------------------------------------------

# Requirements

ZygorWaypoint requires:

-   **TomTom**
-   **Zygor Guides Viewer**

Both addons must be installed and enabled.

------------------------------------------------------------------------

# Features

## Zygor → TomTom Arrow Bridge

Zygor guide steps automatically update **TomTom's Crazy Arrow**.

This lets you follow Zygor guides while using TomTom's arrow instead of Zygor's arrow display.

ZygorWaypoint also manages arrow visibility independently from the guide frame:

- When the **Zygor guide frame is hidden**, the current guide-step waypoint is cleared.
- **TomTom's Crazy Arrow and Zygor Travel System routing remain active**, but guide step goals are not shown.
- Manual waypoints or TomTom-created waypoints continue to function normally.
- When the guide becomes visible again, guide step waypoints refresh automatically. If a manual waypoint or active travel route is in progress, the guide step waypoint will resume only after that destination/waypoint is completed or cleared.
- Zygor's internal `hidearrowwithguide` setting is overridden so arrow visibility stays under ZygorWaypoint control.

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

These settings determine how Zygor calculates routes (flight paths, portals, etc.).

You can adjust them in:

`Zygor Settings → Waypoint Arrow → Travel System`

After the route is calculated, navigation is still displayed using **TomTom's Crazy Arrow**.

The arrow you see is always **TomTom's arrow**—ZygorWaypoint simply uses Zygor to determine *how to get there*.

------------------------------------------------------------------------

## NPC/Object Search Commands

ZygorWaypoint can quickly route you to common NPCs and objects using `/zwp search`.

These searches rely on Zygor's **Find Nearest NPC/Object** feature and use **Zygor's Travel System** to determine the fastest route, while navigation is displayed using **TomTom's Crazy Arrow**.

Example:

`/zwp search vendor`

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

`/zwp search trainer <profession>`  
`/zwp search workshop <profession>`

Example:

`/zwp search trainer blacksmithing`

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

## Arrow Alignment

TomTom's arrow can optionally be aligned with Zygor's arrow text frame to create a cleaner combined interface.

------------------------------------------------------------------------

## Manual Waypoint Auto-Clear

ZygorWaypoint can optionally **automatically clear manual waypoints when you arrive at the destination**.

This helps keep navigation clean when using manual waypoints, such as those set by other addons like **Silver Dragon** or manually selected map locations.

When a manual waypoint auto-clears:

- The **TomTom pin** is removed
- The **Blizzard user waypoint** is cleared
- **Supertracking** is reset

Zygor's **travel routing system is not affected**.

If Zygor generated intermediate travel steps (flight paths, portals, etc.), those route legs remain intact. Auto-clear only applies to the **final destination waypoint**.

The arrival distance used for auto-clearing can be configured in the addon options.

------------------------------------------------------------------------

## Zygor Arrow Texture Hiding

ZygorWaypoint hides Zygor's arrow graphic while leaving Zygor's travel text visible.

This prevents duplicate arrows on screen while allowing **TomTom's Crazy Arrow** to handle navigation.

For users who prefer the Zygor look, optional **Starlight** and **Stealth** skins can be applied to TomTom's arrow so it visually matches Zygor's arrow styles.

------------------------------------------------------------------------

## Guide Viewer Compact Mode

ZygorWaypoint includes an optional **compact guide viewer mode** inspired by Zygor's older *Mini Mode with Tooltip*.

When enabled:

- Only the **currently visible guide step rows** remain on screen.
- The rest of the guide viewer is hidden to reduce UI clutter.

Hovering over the Zygor guide viewer temporarily restores the **full viewer interface**, allowing normal interaction with the guide.

Once the mouse leaves the guide viewer, the interface returns to compact mode.

------------------------------------------------------------------------

## Waypoint UI Compatibility

ZygorWaypoint includes built-in compatibility for **Waypoint UI**:

- Mirrored Zygor destinations are labeled correctly instead of appearing as generic `Map Pin` markers.
- Waypoint UI markers use improved non-empty Zygor text fallbacks (arrow title, waypoint title, current goal text, or step title).
- Waypoint coordinates are stabilized to prevent incorrectly named waypoints caused by Waypoint UI rounding differences.
- Temporary clears caused by UI transitions (such as cinematics or TomTom arrow resets) are automatically restored if the destination is still active.

This ensures consistent behavior between **TomTom**, **Zygor**, and **Waypoint UI**.

------------------------------------------------------------------------

# Slash Commands

Command root:

/zwp

Available commands:

-   `/zwp status` --- Show addon status
-   `/zwp debug` --- Toggle debug output
-   `/zwp diag` --- Monitor live scene and arrow state changes for troubleshooting
-   `/zwp options` --- Open addon options
-   `/zwp skin default|starlight|stealth` --- Change arrow appearance
-   `/zwp scale <0.60-2.00>` --- Adjust Zygor skin arrow scale
-   `/zwp routing on|off|toggle` --- Control TomTom → Zygor routing
-   `/zwp align on|off` --- Toggle arrow alignment
-   `/zwp override on|off` --- Override TomTom clear-distance behavior
-   `/zwp manualclear on|off|toggle` --- Toggle manual waypoint auto-clear on arrival
-   `/zwp cleardistance <5-100>` --- Set the manual waypoint auto-clear distance in yards
-   `/zwp compact on|off|toggle` --- Toggle compact guide viewer mode
-   `/zwp search vendor|auctioneer|banker|innkeeper|flightmaster|mailbox|repair|transmogrifier|void storage` --- Route to the nearest matching NPC/service
-   `/zwp search trainer <profession> | workshop <profession>` --- Route to the nearest profession trainer or workshop
-   `/zwp search help` --- List supported search targets

------------------------------------------------------------------------

# Options Panel

ZygorWaypoint includes an in‑game options panel.

Location:

Game Menu → Options → AddOns → ZygorWaypoint

Available settings:

-   Override TomTom clear-distance on login
-   Align TomTom arrow to Zygor text
-   Route TomTom waypoints via Zygor
-   Show only the visible guide step rows until mouseover
-   Enable a Zygor arrow skin for TomTom
-   Choose between Zygor Starlight and Stealth
-   Adjust TomTom arrow scale (Zygor skins only)
-   Auto-Clear Manual Waypoints on Arrival with adjustable distance
-   Manual Waypoint Clear Distance


Most settings apply immediately.

If a setting requires a reload to fully apply, the addon will display a **reload-recommended prompt**.

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

# Compatibility

ZygorWaypoint should work with any of the many addons that create TomTom waypoints.

Examples include:

-   HandyNotes
-   RareScanner
-   Silver Dragon
-   Paste
-   Coordinate sharing macros
-   Other TomTom‑compatible addons

If an addon creates a TomTom waypoint, ZygorWaypoint can route it through Zygor's travel system.

------------------------------------------------------------------------

# Changelog

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

See [CHANGELOG](CHANGELOG.md)

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
