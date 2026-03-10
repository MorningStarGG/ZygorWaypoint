# ZygorWaypoint

> A bridge addon that lets **Zygor Guides** and **TomTom** work together --- using **TomTom's Crazy Arrow for navigation** while **Zygor handles travel routing and pathfinding**.

![Version](https://img.shields.io/badge/version-2.0-blue) ![Game](https://img.shields.io/badge/World%20of%20Warcraft-Addon-orange) ![Requires](https://img.shields.io/badge/requires-Zygor%20Guides%20%2B%20TomTom-red)


------------------------------------------------------------------------

# Overview

**ZygorWaypoint v2.0** connects **Zygor Guides Viewer** and **TomTom** so they can share waypoint information.

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

For users who prefer the Zygor look, **Zygor's Starlight arrow skin can optionally be applied to TomTom's arrow**, preserving the Zygor visual style while keeping TomTom compatibility.

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

------------------------------------------------------------------------

## TomTom → Zygor Travel Routing

ZygorWaypoint can optionally (enabled by default) route **TomTom waypoints** through **Zygor's Travel System**.

When a waypoint is created through **TomTom** (either manually or by another addon) ZygorWaypoint sends that destination to Zygor so it can calculate the best route to reach it.

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

## Arrow Alignment

TomTom's arrow can optionally be aligned with Zygor's arrow text frame to create a cleaner combined interface.

------------------------------------------------------------------------

## Zygor Arrow Texture Hiding

ZygorWaypoint hides Zygor's arrow graphic while leaving Zygor's travel text visible.

This prevents duplicate arrows on screen while allowing **TomTom's Crazy Arrow** to handle navigation.

For users who prefer the Zygor look, the optional **Starlight skin** can be applied to TomTom's arrow so it visually matches the Zygor arrow style.

------------------------------------------------------------------------

# Slash Commands

Command root:

/zwp

Available commands:

-   `/zwp on` --- Enable the addon
-   `/zwp off` --- Disable the addon
-   `/zwp status` --- Show addon status
-   `/zwp debug` --- Toggle debug output
-   `/zwp options` --- Open addon options
-   `/zwp skin default|starlight` --- Change arrow appearance
-   `/zwp scale <0.60-2.00>` --- Adjust Starlight arrow scale
-   `/zwp routing on|off|toggle` --- Control TomTom → Zygor routing
-   `/zwp align on|off` --- Toggle arrow alignment
-   `/zwp override on|off` --- Override TomTom clear-distance behavior

------------------------------------------------------------------------

# Options Panel

ZygorWaypoint includes an in‑game options panel.

Location:

Game Menu → Options → AddOns → ZygorWaypoint

Available settings:

-   Override TomTom clear-distance on login
-   Align TomTom arrow to Zygor text
-   Route TomTom waypoints via Zygor travel
-   Enable Zygor Starlight arrow skin
-   Adjust TomTom arrow scale (Starlight only)

Use **Apply and Reload** to apply changes.

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

## 2.0.0

- Packaging:
  - dependencies are now hard-required: `TomTom`, `ZygorGuidesViewer`.
- Command root is still `/zwp`.
  - Subcommands: `on`, `off`, `status`, `debug`, `skin`, `scale`, `options`, `routing`, `align`, `override`.
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
