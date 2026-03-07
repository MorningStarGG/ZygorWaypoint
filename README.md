# ZygorWaypoint

> A lightweight waypoint bridge that routes Blizzard map targets and slash commands through Zygor's travel arrow — no TomTom required.

![Version](https://img.shields.io/badge/version-1.2-blue) ![Game](https://img.shields.io/badge/World%20of%20Warcraft-Addon-orange) ![Requires](https://img.shields.io/badge/requires-Zygor%20Guides-red)

---

## Overview

ZygorWaypoint seamlessly connects the World of Warcraft map and supertracking system to Zygor Guides' built-in travel arrow. Whether you're clicking a quest marker on the map, tracking a world quest, or typing a quick `/way` command, ZygorWaypoint feeds that destination directly into Zygor so you always have a route — without needing multiple addons.

---

## Features

### 🗺️ Slash Commands

Type waypoints directly — no settings UI.

| Command                               | Description                           |
| ------------------------------------- | ------------------------------------- |
| `/way <zone\|#mapID> <x> <y> [title]` | Set a waypoint by zone name or map ID |
| `/way <x> <y> [title]`                | Set a waypoint in your current zone   |
| `/clearway`                           | Clear the active waypoint             |

> Coordinates can be entered as **percentages** (e.g. `53.2 41.8`) or **normalized** values (`0.0–1.0`).

---

### 🔁 Auto-Routing

ZygorWaypoint watches Blizzard's supertracking system and automatically routes through Zygor whenever you interact with:

* **Quest & world quest POI targets**
* **User-placed waypoints** from the world map
* **Area POI map pins** *(when coordinates are available)*
* **Content-tracking targets** *(when coordinates are available)*

---

### ⚙️ Addon Control Commands

| Command                         | Description                                     |
| ------------------------------- | ----------------------------------------------- |
| `/zwp on \| off \| toggle`      | Enable or disable ZygorWaypoint                 |
| `/zwp clear`                    | Clear the active waypoint                       |
| `/zwp status`                   | Show addon, auto-routing, and 3D sync status   |
| `/zwp auto on \| off \| toggle` | Control automatic waypoint capture behavior     |
| `/zwp sync on \| off \| toggle` | Control Blizzard supertracking (3D diamond) sync |

> `auto off` only disables automatic capture from quest/content tracking. Manual `/way`, map clicks, and addon-set waypoints still route through Zygor.

---
### 🧩 Developer API

ZygorWaypoint exposes a global API for other addons to integrate with:

```lua
-- Set a waypoint programmatically
ZygorWaypoint.SetWaypoint(mapID, x, y, opts)

-- Clear active waypoints
ZygorWaypoint.ClearWaypoints([opts])

-- Check if the addon is loaded and ready
ZygorWaypoint.IsReady()
```

---

## Works With

ZygorWaypoint is designed to integrate with your existing addons. If an addon sends waypoints through TomTom or Blizzard's map system, ZygorWaypoint will intercept and route them through Zygor automatically.

### 🦴 RareScanner

When RareScanner detects a rare spawn and sends you to its location, ZygorWaypoint picks up that waypoint and routes it through Zygor's travel arrow — no manual coordinate entry needed.

### 📌 HandyNotes

HandyNotes and its many plugins (Dragonflight treasures, rares, profession nodes, etc.) output waypoints through TomTom-compatible commands. ZygorWaypoint intercepts these and routes them through Zygor instead, so clicking a HandyNotes pin sends you on your way immediately.

### 🌐 Wowhead Links & Macros

Wowhead coordinates shared in chat, macros, or via addons like **Wowhead Looter** typically use the standard `/way` format. ZygorWaypoint handles these natively, so pasting a Wowhead coordinate string into chat routes directly through Zygor.

### 🖱️ Map Click Routing

Clicking waypoints or POI pins directly on the Blizzard world map triggers Zygor's travel arrow automatically via the auto-routing system — no commands required.

### 🔌 Any TomTom-Compatible Addon

If an addon outputs waypoints using `/way` or TomTom's API, ZygorWaypoint acts as a transparent drop-in replacement. Common examples include:

* **Paste** — coordinate sharing from chat links
* **Carbonite** exports
* **DeadlyBossMods** / **BigWigs** world marker routing
* Guild or community coordinate macros

> If an addon you use isn't routing correctly through Zygor, open an issue and we'll look into it.

---

## ⚠️ Known Conflicts & Troubleshooting

Some addons intercept `/way` or implement their own "Virtual TomTom" system, which can prevent ZygorWaypoint from receiving waypoint commands.

### ElvUI WindTools

WindTools includes a **Waypoint Parse** feature (found under `ElvUI → WindTools → Maps → Super Tracker`) with a **Virtual TomTom** option and custom command list. If this is enabled, WindTools may intercept `/way` commands before ZygorWaypoint can process them.

**To fix:** In ElvUI WindTools, go to `Super Tracker → Waypoint Parse` and either:

* Disable **Enable** to turn off waypoint parsing entirely, or
* Disable **Virtual TomTom** specifically

### General Tips

* If `/way` commands aren't routing through Zygor, check for any addon that registers a "Virtual TomTom" or intercepts slash commands.
* Addons with their own waypoint arrow systems (e.g. Carbonite) may need their own waypoint features disabled to avoid conflicts.

> If you've identified another addon that conflicts, please open an issue so it can be documented here.

---

## Compatibility

* Acts as a **drop-in replacement for TomTom** for Zygor users via `/way`.
* Waypoints are routed through `Zygor Pointer:SetWaypoint()` with pathfinding enabled.
* Requires **Zygor Guides** to be installed and active.

---

## Project Structure

```
ZygorWaypoint/
├── ZW_Core.lua          # Core addon framework
├── ZW_DiamondSync.lua   # Blizzard supertracking / 3D diamond sync
├── ZW_Waypoint.lua      # Waypoint logic
├── ZW_AutoRouting.lua   # Blizzard supertracking integration
├── ZW_Commands.lua      # Slash command handling
├── ZW_API.lua           # Public API exposure
└── ZW_Init.lua          # Initialization
```

---

## Changelog

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

---

## Author

ZygorWaypoint was created and is maintained by **MorningStarGG**.

* 📺 **Twitch:** [twitch.tv/MorningStarGG](https://www.twitch.tv/MorningStarGG)
* 🎮 **Battletag:** `MorningStar#1136`

Feel free to stop by the stream — Community, CHAOS, Professionally trained idiot.

---

## Contributing

Found a bug or have a feature request? Open an issue or submit a pull request — contributions are welcome.

---

## License

*This addon is provided as-is under the GPL-3.0 [license](LICENSE). You are free to modify and distribute it according to your needs.*

---

**AI Disclaimer:** Parts of this was made with various AI tools to speed development time.