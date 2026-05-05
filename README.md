# AzerothWaypoint

> A TomTom-powered navigation bridge, route planner selector, manual waypoint queue, and 3D world overlay for World of Warcraft.

![Version](https://img.shields.io/badge/version-4.0.0b-blue)
![Game](https://img.shields.io/badge/World%20of%20Warcraft-Addon-orange)
![Required](https://img.shields.io/badge/Required-TomTom-red)
![Optional](https://img.shields.io/badge/Optional-Zygor%20%7C%20APR%20%7C%20WoWPro%20%7C%20Farstrider%20%7C%20Mapzeroth-lightgrey)
![License](https://img.shields.io/badge/license-GPL--3.0-green)

**Support development:** [Donate via PayPal](https://paypal.me/TheThinkCritic)

---

## ZygorWaypoint is now AzerothWaypoint

AzerothWaypoint is the renamed and expanded successor to ZygorWaypoint.

**TomTom is now the only required dependency.** Zygor Guides Viewer is still fully supported, but it is optional. AzerothWaypoint can also work with Azeroth Pilot Reloaded, WoWPro, FarstriderLib, Mapzeroth, Blizzard map and quest sources, imported TomTom waypoint lists, and supported external waypoint addons.

---

## Table of Contents

- [What AzerothWaypoint Does](#what-azerothwaypoint-does)
- [Quick Start](#quick-start)
- [How Navigation Works](#how-navigation-works)
- [Feature Highlights](#feature-highlights)
- [Supported Integrations](#supported-integrations)
- [What's New in 4.0.0](#whats-new-in-400)
- [Options](#options)
- [Slash Commands](#slash-commands)
- [Installation](#installation)
- [Upgrade Notes](#upgrade-notes)
- [Troubleshooting](#troubleshooting)
- [Known Notes](#known-notes)
- [Author](#author)
- [Contributing](#contributing)
- [License](#license)

---

## What AzerothWaypoint Does

AzerothWaypoint connects multiple waypoint sources to one controlled navigation flow.

It can route and present destinations from:

- TomTom waypoints
- guide steps from Zygor Guides Viewer, Azeroth Pilot Reloaded, and WoWPro
- Blizzard map clicks, quest pins, POIs, supertracked quests, and tracked quests
- imported `/ttpaste` waypoint batches
- supported external waypoint addons like SilverDragon and RareScanner

AzerothWaypoint then sends the active route to:

- TomTom's arrow
- AWP's native 3D world overlay
- the waypoint queue UI
- contextual icons, labels, colors, and travel action prompts

In short:

```text
TomTom shows the arrow.
AzerothWaypoint controls the route flow.
Optional integrations provide richer route planning and guide data.
```

---

## Quick Start

1. Install **TomTom** and **AzerothWaypoint**.
2. Optionally install **Zygor Guides Viewer**, **Azeroth Pilot Reloaded**, **WoWPro**, **FarstriderLib**, or **Mapzeroth**.
3. Open options:

```text
/awp options
```

4. Pick your routing backend under **General > Routing Backend**.

| Backend | Best For |
|---|---|
| **TomTom Direct** | Simple direct waypoint navigation. Always available. |
| **Farstrider** | Travel-aware routing with flights, portals, transports, items, spells, and travel nodes. |
| **Mapzeroth** | Mapzeroth travel routing with flights, portals, transports, items, spells, and travel nodes. |
| **Zygor** | Zygor users who want LibRover travel routing, travel actions, search data, and transport support. |

5. Open the waypoint queue UI from the world map side tab or with:

```text
/awp queue
```

6. Open help or release notes in-game:

```text
/awp help
/awp changelog
```

---

## How Navigation Works

AzerothWaypoint separates navigation into three layers:

| Layer | Meaning | Examples |
|---|---|---|
| **Source** | Where the destination came from | guide step, map click, quest POI, imported queue, external addon |
| **Backend** | How the route is planned | TomTom Direct, Farstrider, Mapzeroth, Zygor |
| **Carrier** | What presents the route | TomTom arrow, AWP 3D overlay, queue UI |

Example flows:

```text
Guide step -> guide provider -> route backend -> TomTom arrow + 3D overlay

Map click -> manual queue policy -> route backend -> TomTom arrow + 3D overlay

/ttpaste batch -> manual queue -> active queue item -> route backend -> TomTom arrow + 3D overlay

Quest POI -> Blizzard takeover -> quest-aware route -> TomTom arrow + 3D overlay
```

This separation lets manual queues, guide providers, transient addon routes, quest takeovers, and imported waypoint lists coexist without constantly deleting or overriding each other.

---

## Feature Highlights

### TomTom Arrow Bridge

TomTom remains the visible navigation arrow. AzerothWaypoint decides what destination owns the route, which backend should plan it, and what contextual presentation should appear around it.

AWP can:

- push guide, quest, POI, queue, and addon destinations into TomTom
- preserve normal TomTom behavior for direct waypoints
- suppress duplicate guide arrows where appropriate
- apply custom TomTom arrow skins
- show secure travel action buttons for route legs that require an item, spell, toy, hearthstone, portal, or similar action

### Selectable Routing Backends

AWP can route the same destination through different backends:

| Backend | Behavior |
|---|---|
| **TomTom Direct** | Single-leg direct fallback. Always available. |
| **Farstrider** | Uses FarstriderLib and FarstriderLibData when available. |
| **Mapzeroth** | Uses Mapzeroth when available. |
| **Zygor** | Uses Zygor and LibRover when Zygor is available. |

Unavailable backend selections fall back safely.

You can change backends in options or with:

```text
/awp backend direct
/awp backend farstrider
/awp backend mapzeroth
/awp backend zygor
```

### Guide Provider Support

AWP 4.0 is no longer limited to Zygor guide routing.

Supported guide providers:

- **Zygor Guides Viewer**
- **Azeroth Pilot Reloaded**
- **WoWPro**

Guide providers can publish:

- current guide target
- active step title
- subtext or objective progress
- quest metadata
- queue projection

Zygor still has the richest integration because it can also provide search data and a routing backend, but APR and WoWPro now receive much closer to Zygor-style actionable overlay text and queue presentation.

### Manual Waypoint Queues

Manual waypoints are no longer just throwaway TomTom points.

AWP supports:

- persistent manual queues
- imported `/ttpaste` queues
- destination queues for multi-click flows
- transient queues for short-lived external sources
- guide queues shown alongside manual queues
- activate/deactivate without deleting queues
- bulk queue deletion
- per-queue delete icons
- queue detail pages
- final destination focus on the world map

Manual Click Queue Behavior controls how map clicks are handled:

| Mode | Behavior |
|---|---|
| **Create New Queue** | Put the clicked destination in its own new queue. |
| **Replace Active** | Replace the currently active manual queue. |
| **Append** | Add the clicked destination to the current queue. |
| **Ask** | Prompt each time. |

### Blizzard Map and Quest Takeovers

AWP can adopt supported Blizzard navigation sources and route them through the active backend.

Supported Blizzard sources include:

- user waypoints
- quest POIs
- supertracked quests
- tracked quests
- area POIs
- vignettes
- taxi nodes
- gossip POIs
- dig sites
- housing plots

Quest-backed targets can preserve quest metadata, objective context, source labels, icons, and clear behavior where Blizzard exposes enough data.

### 3D World Overlay

AWP includes its own native 3D overlay. It does not require WaypointUI.

Overlay modes:

| Mode | Purpose |
|---|---|
| **Waypoint** | Long-range in-world destination marker. |
| **Pinpoint** | Close-range destination plaque and arrival marker. |
| **Navigator** | Off-screen directional arrow. |

The overlay is aware of:

- quest state
- quest type
- world quest type
- guide provider
- travel route type
- source addon
- manual queue metadata
- external transient sources
- services and profession searches

### Quest-Aware Icons and Text

AWP can present different icon families for:

- available quests
- incomplete quests
- completed quests
- world quests
- daily, weekly, campaign, legendary, artifact, calling, meta, repeatable, and important quests
- racing world quests
- dungeons, raids, delves, portals, taxis, inns, and other travel targets

Quest-backed targets can show objective progress once the quest is active.

### External Addon Waypoint Sources

AWP includes a source registry for addon-created waypoints.

Current source-aware integrations:

- **SilverDragon**
- **RareScanner**

These are handled as transient manual sources, so they can briefly take over navigation without destroying persistent manual queues.

AWP also includes controls for unknown addon waypoint adoption:

- enable or disable adoption
- review detected callers
- allowlist addon folder names
- blocklist addon folder names

### WorldQuestTab Integration

WorldQuestTab quest pin clicks can be adopted by AzerothWaypoint and routed through the active backend.

AWP captures:

- quest title
- quest ID
- map and coordinates
- source addon
- quest type and world quest metadata when Blizzard exposes it

### Special Travel Actions

Some route legs require using an item, spell, toy, hearthstone, portal, or similar travel action.

When the current route leg needs a special action, AWP can show a secure special travel button in place of normal arrow presentation.

### Arrow Skins

AWP includes an arrow skin system for TomTom.

Built-in AWP skins:

- AWP
- AWP Bomber
- AWP Modern
- Alliance
- Horde

Zygor skins, when Zygor is loaded:

- Starlight
- Stealth

### Zygor Viewer Polish

When Zygor is installed, AWP can:

- use compact guide presentation
- hide step backgrounds until mouseover
- hide step backgrounds and line colors until mouseover
- detect Zygor arrow conflict settings and offer a one-click disable prompt

### Search Routing

With Zygor installed, AWP can route to nearby services and profession targets:

```text
/awp search vendor
/awp search auctioneer
/awp search banker
/awp search mailbox
/awp search trainer blacksmithing
/awp search workshop engineering
```

Supported services include vendors, repair, auctioneers, bankers, barbers, flight masters, innkeepers, mailboxes, riding trainers, stable masters, transmogrifiers, void storage, profession trainers, and profession workshops.

---

## Supported Integrations

### Required

| Addon | Purpose |
|---|---|
| **TomTom** | Provides the primary navigation arrow and waypoint carrier. |

### Optional

AzerothWaypoint works without these addons, but enables additional behavior when they are installed.

| Addon | What AzerothWaypoint Uses It For |
|---|---|
| **Zygor Guides Viewer** | Guide targets, LibRover routing backend, search data, Zygor-style arrow skins, and compact guide options |
| **Azeroth Pilot Reloaded** | Guide step targets, guide text, objective context, and queue projection |
| **WoWPro** | Guide step targets, guide text, objective context, and queue projection |
| **FarstriderLib / FarstriderLibData** | Travel-aware route planning with flights, portals, transports, items, spells, and travel nodes |
| **Mapzeroth** | Travel-aware route planning with flights, portals, transports, items, spells, and travel nodes |
| **WorldQuestTab** | World quest click adoption with quest metadata |
| **SilverDragon** | Source-aware rare waypoint adoption |
| **RareScanner** | Source-aware rare waypoint adoption |

Other addons that create TomTom waypoints may also work through AzerothWaypoint's normal TomTom adoption flow.

---

## What's New in 4.0.0

Version 4.0.0 is a major release and rename from the old ZygorWaypoint identity to AzerothWaypoint.

### Big Picture

- Renamed the addon to **AzerothWaypoint**.
- TomTom is now the only required dependency.
- Zygor is optional instead of being the whole routing model.
- APR and WoWPro guide providers were added.
- Farstrider and Mapzeroth route backends were added.
- The old Zygor-only bridge was replaced with a modular route authority system that can choose between multiple sources, guide providers, queues, and route backends.

### Guide Integrations

- Added a guide provider dispatcher.
- Added APR provider support.
- Added WoWPro provider support.
- Enhanced Zygor parity through the existing Zygor resolver.
- Guide queues can remain visible even when another source is the active route.

### Routing and Queues

- Added selectable routing backends.
- Added persistent manual queues.
- Added guide queue projection.
- Added transient queues for short-lived addon sources.
- Added manual click queue behavior: create, replace, append, ask.
- Added queue list/detail UI, bulk delete, queue/destination delete icons, and queue context menus.

### World Overlay

- Reorganized world overlay code into core, assets, pinpoint, presentation, and runtime modules.
- Added and refined contextual icons, tints, quest states, travel types, and external source presentation.
- Added Auto color behavior with contextual hints.
- Added Gray color preset.
- Removed the old None color option because it duplicated White behavior.
- Fixed stale atlas/UV texture carryover when switching icon families.
- Moved overlay media assets into clearer folders.

### Arrow and Travel

- Added registered TomTom arrow skins.
- Added AWP, AWP Bomber, AWP Modern, Alliance, and Horde skins.
- Preserved Starlight and Stealth when Zygor is loaded.
- Added secure special travel button support.
- Added Special Travel Button Scale.

### Options and Help

- Rebuilt options into a custom canvas UI with search, filters, previews, release notes, and section images.
- Added new option sections: About, General, TomTom Arrow, World Overlay, Waypoint, Pinpoint, Navigator, and conditional Zygor.
- Added in-game help and release notes flow.
- Added detected addon caller controls, allowlist, and blocklist.

---

## Options

Open options with:

```text
/awp options
```

or:

```text
/awp config
```

You can also open options through:

```text
Game Menu -> Options -> AddOns -> AzerothWaypoint
```

Options are organized into these sections:

| Section | Controls |
|---|---|
| **About** | Addon summary, help access, release notes, author links |
| **General** | Routing, backend selection, manual queue behavior, quest routing, quest clearing, addon waypoint adoption |
| **TomTom Arrow** | Custom arrow skins, arrow scale, special travel button scale |
| **World Overlay** | 3D overlay enablement, hover fade, context display, shared icon and color behavior |
| **Waypoint** | Long-range marker mode, size, opacity, beacon, footer text, units, and colors |
| **Pinpoint** | Close-range marker, plaque style, destination info, arrows, coordinates, colors, and height |
| **Navigator** | Off-screen arrow size, opacity, distance, dynamic distance, and color |
| **Zygor** | Compact Zygor viewer presentation when Zygor is loaded |

### General Options

General navigation behavior includes:

- Enable Routing
- Routing Backend
- Manual Click Queue Behavior
- Auto-Clear Manual Waypoints on Arrival
- Manual Waypoint Clear Distance
- Auto-Route Tracked Quests
- Auto-Clear Untracked Quests
- Auto-Clear Supertracked Quests on Arrival
- Adopt Waypoints from Unknown Addons
- Detected Addon Callers
- Addon Allowlist
- Addon Blocklist

### TomTom Arrow Options

TomTom arrow controls include:

- Use Custom Arrow Skin
- Arrow Skin
- TomTom Arrow Scale
- Special Travel Button Scale

### World Overlay Options

Shared 3D overlay controls include:

- Enable 3D World Overlay
- Fade on Hover
- Context Display
- Context Diamond color
- Icon color

### Waypoint Options

Long-range marker controls include:

- Waypoint Mode
- Waypoint Size
- Waypoint Min Size
- Waypoint Max Size
- Waypoint Opacity
- Waypoint Vertical Offset
- Beacon Style
- Beacon Base Distance
- Beacon Opacity
- Base Vertical Offset
- Yards/meters display
- Footer Text Mode
- Footer Text Size
- Footer Text Opacity
- Waypoint Text Color
- Beacon Color

### Pinpoint Options

Close-range destination controls include:

- Pinpoint Mode
- Show Pinpoint At
- Hide Pinpoint At
- Pinpoint Size
- Pinpoint Opacity
- Plaque Style
- Animate Plaque Effects
- Show Destination Info
- Show Extended Info
- Show Coordinate Fallback
- Show Pinpoint Arrows
- Base Pinpoint Height
- Camera Pinpoint Height
- Title color
- Subtext color
- Plaque color
- Animated part color
- Chevron color

Plaque styles:

- Default
- Glowing Gems
- Horde
- Alliance
- Modern
- Steampunk

### Navigator Options

Off-screen marker controls include:

- Enable Navigator
- Navigator Size
- Navigator Opacity
- Navigator Distance
- Navigator Dynamic Distance
- Navigator Arrow color

### Zygor Options

Shown only when Zygor is loaded:

- Show Only Guide Steps Until Mouseover
- Hide Step Backgrounds Until Mouseover

---

## Slash Commands

Root command:

```text
/awp
```

### Common Commands

| Command | Description |
|---|---|
| `/awp status` | Show addon status, routing backend, key toggles, and version. |
| `/awp options` | Open options. |
| `/awp config` | Open options. |
| `/awp help` | Open in-game help. |
| `/awp changelog` | Open What's New. |
| `/awp routing on\|off\|toggle` | Enable or disable route ownership. |
| `/awp backend direct\|zygor\|mapzeroth\|farstrider` | Choose routing backend. |
| `/awp queue` | Open the waypoint queue panel. |
| `/awp manualclear on\|off\|toggle` | Toggle manual waypoint auto-clear. |
| `/awp cleardistance <5-100>` | Set manual waypoint clear distance. |
| `/awp trackroute on\|off\|toggle` | Toggle auto-routing for newly tracked quests. |
| `/awp untrackclear on\|off\|toggle` | Toggle clearing queue items when quests are untracked. |
| `/awp questclear on\|off\|toggle` | Toggle arrival clear for supertracked quest routes. |
| `/awp addontakeover on\|off\|toggle\|status` | Control unknown addon waypoint adoption. |
| `/awp compact on\|off\|toggle` | Toggle Zygor compact viewer mode. |
| `/awp skin <skin>` | Set TomTom arrow skin. |
| `/awp scale <0.60-2.00>` | Set custom arrow skin scale. |
| `/awp search <type>` | Route to a service or profession target. |
| `/awp repair` | Repair TomTom/Zygor settings AWP depends on. |

### Queue Commands

```text
/awp queue
/awp queue list
/awp queue use <id|index>
/awp queue clear [id|index]
/awp queue remove <id|index> <item>
/awp queue move <id|index> <from> <to>
/awp queue import
```

Queue aliases:

- `queues`
- `queue open`
- `queue show`
- `queue ls`
- `queue rm`
- `queue paste`
- `queue ttpaste`

### Search Commands

Search commands require Zygor to be installed and enabled.

```text
/awp search vendor
/awp search repair
/awp search auctioneer
/awp search mailbox
/awp search trainer alchemy
/awp search workshop blacksmithing
```

Common aliases:

- `ah`
- `auction`
- `bank`
- `inn`
- `mail`
- `mog`
- `tmog`
- `store`
- `stables`

---

## Installation

1. Download AzerothWaypoint.
2. Place the folder here:

```text
World of Warcraft/_retail_/Interface/AddOns/AzerothWaypoint/
```

3. If you previously used ZygorWaypoint, delete the old folder:

```text
World of Warcraft/_retail_/Interface/AddOns/ZygorWaypoint/
```

4. Install and enable **TomTom**.
5. Enable any optional supported addons you want to use.
6. Restart the game or run:

```text
/reload
```

7. Open options:

```text
/awp options
```

---

## Upgrade Notes

### From ZygorWaypoint or pre-4.0 development builds

Old ZygorWaypoint settings are not migrated. This was intentional for the v4 rename and development reset.

If the old `ZygorWaypoint` addon folder is still installed, remove or disable it to avoid conflicts.

### WaypointUI

AWP now ships its own 3D world overlay. WaypointUI is not required.

If you still use WaypointUI, AWP may remind you that its native overlay is the recommended setup.

---

## Troubleshooting

### The arrow is missing

Try:

```text
/awp status
/awp repair
/reload
```

Also check that TomTom is installed and enabled.

### Zygor's arrow is still showing

Open Zygor settings:

```text
/zygor options
```

Then go to:

```text
Waypoint Arrow -> Enable Waypoint Arrow
```

Turn it off. AWP may offer a one-click prompt when it detects this conflict.

### A guide addon appears in the queue but is not controlling navigation

That can be normal.

Guide queues can remain visible even when a manual queue, transient route, or another provider currently owns the active route.

Activate the queue from the queue panel or use the guide addon normally to make it the active provider again.

### Imported waypoints are not forming a queue

Check:

- `/awp queue`
- `/awp status`

### Unknown addon waypoints are being ignored

Check:

- **General > Adopt Waypoints from Unknown Addons**
- **Detected Addon Callers**
- **Addon Allowlist**
- **Addon Blocklist**

### Quest text or objective progress is stale

Quest data can lag behind Blizzard API updates.

Try opening the quest log, changing tracking, or waiting for the next quest update event.

---

## Known Notes

- Some Blizzard quest/objective data is not immediately available at login or right after a quest state changes.
- Some guide addons expose richer metadata than others. AWP uses addon data first where reliable, then falls back to Blizzard APIs.
- The overlay's dynamic text sizing is limited by Blizzard font behavior and may not animate perfectly smoothly.
- Farstrider (needs FarstriderLibData), Mapzeroth, and Zygor routing depend on their addon being installed and enabled.

---

## Author

AzerothWaypoint is created and maintained by **MorningStarGG**.

- Twitch: [twitch.tv/MorningStarGG](https://www.twitch.tv/MorningStarGG)
- BattleTag: `MorningStar#1136`
- PayPal: [Donate via PayPal](https://paypal.me/TheThinkCritic)

---

## Contributing

Found a bug or have a feature request? Open an issue or submit a pull request. Contributions are welcome.

Good reports include:

- what you clicked or routed
- which guide addon was active
- current routing backend
- `/awp status`
- `/awp waytype`
- `/awp stepdebug` when guide routing is involved
- any Lua error stack

---

## License

*This addon is provided as-is under the GPL-3.0 [license](LICENSE). You are free to modify and distribute it according to your needs.*

---

**AI Disclaimer:** Parts of this was made with various AI tools to speed development time.
