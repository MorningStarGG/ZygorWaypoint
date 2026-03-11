# ZygorWaypoint

> A bridge addon that lets **Zygor Guides** and **TomTom** work together --- using **TomTom's Crazy Arrow for navigation** while **Zygor handles travel routing and pathfinding**.

![Version](https://img.shields.io/badge/version-2.3-blue) ![Game](https://img.shields.io/badge/World%20of%20Warcraft-Addon-orange) ![Requires](https://img.shields.io/badge/Requires-Zygor%20Guides%20and%20TomTom-red)


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

Earlier versions of ZygorWaypoint (1.x) used **Zygor's arrow directly**. While this worked well for Zygor guides, many other addons expect **TomTom** to be present for waypoint navigation. Because of this, some addons would not recognize ZygorWaypoint as a valid navigation provider.

Version **2.0** changes this approach by using **TomTom as the visible navigation arrow**, ensuring maximum compatibility with addons that rely on TomTom waypoints.

ZygorWaypoint still leverages **Zygor's travel system** to calculate optimal routes, while TomTom handles the visual navigation arrow.

For users who prefer the Zygor look, **Zygor's Starlight or Stealth arrow skins can optionally be applied to TomTom's arrow**, preserving the Zygor visual style while keeping TomTom compatibility.

Version **2.0** is a full rewrite of the original ZygorWaypoint addon with a cleaner architecture and improved compatibility.

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

# Slash Commands

Command root:

/zwp

Available commands:

-   `/zwp status` --- Show addon status
-   `/zwp debug` --- Toggle debug output
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
-   Route TomTom waypoints via Zygor travel
-   Show only the visible guide step rows until mouseover
-   Enable a Zygor arrow skin for TomTom
-   Choose between Zygor Starlight and Stealth
-   Adjust TomTom arrow scale (Zygor skins only)

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

# Notes and Limitations

Version **2.0** intentionally removes several legacy systems from earlier ZygorWaypoint versions.

Removed features include:

- `/way` command replacement  
  This is a built-in **TomTom** command and is no longer necessary for ZygorWaypoint to provide.

- Blizzard supertracking capture  
  This feature caused reliability issues and was removed. TomTom already provides better compatibility with other addons that interact with waypoints.

- 3D diamond synchronization  
  Other addons provide better support for this functionality, including integrations such as **Waypoint UI's TomTom support**.

- Legacy waypoint interception systems  
  Waypoint handling is now fully managed through **TomTom's Crazy Arrow** together with **Zygor's travel system**.

These changes simplify the addon and allow ZygorWaypoint to focus entirely on its core purpose:  
**Bridging TomTom navigation with Zygor's travel routing for the purpose of having a single navigation system/arrow**

------------------------------------------------------------------------

# Changelog

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
  - Added retail-friendly aliases such as `ah`, `auction`, `bank`, `inn`, `mog`, `tmog`, `store`, `repairs`, and `stables`.
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
- Command root is still `/zwp`.
  - Subcommands: `status`, `debug`, `skin`, `scale`, `options`, `routing`, `align`, `override`.
- Bridge features:
  - Zygor waypoint extraction -> TomTom Crazy Arrow updates.
  - TomTom waypoint routing -> Zygor travel/pathing -> TomTom Crazy Arrow.
  - Zygor Starlight theme support for TomTom arrow.
  - Starlight-only visual arrow scale control without overwriting TomTom profile scale.
- UI/docs refresh:
  - Added AddOns options panel.
  - Rewrote README for v2.0 behavior and clean-break scope.

## Legacy 1.x

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
