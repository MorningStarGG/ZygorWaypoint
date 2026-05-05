# Changelog

## 4.0.0b
- **Routing and combat visibility**
  - Added Hide During Combat with options for Disabled, TomTom + Travel Button, World Overlay, and Both.
  - TomTom combat hiding uses a secure visibility wrapper so the TomTom arrow and special travel button can be hidden during combat without protected-frame errors.
  - Added player control lost/gained route refresh handling so taxi and flightpath start/end events replan the active route and recompute the TomTom carrier.

- **Compatibility fixes**
  - Added a WorldQuestTab click fallback for bonus objectives and other non-world-quest entries that have valid quest coordinates but do not emit Blizzard waypoint or supertrack signals.
  - Added transparency, transparent, alpha, and visibility tags to the opacity options so searching transparency will find the opacity controls.
  - Prevented transient external waypoint sources such as RareScanner and SilverDragon from opening the manual queue placement prompt.
  - Renamed addon waypoint adoption list internals and wording to Allowlist/Blocklist.

## 4.0.0a

- **Compatibility fixes**
  - Fixed the native world overlay failing to load when Zygor Guides Viewer is disabled or unavailable.
  - Removed an accidental hard dependency on Zygor guide-resolver helpers from the shared world overlay presentation layer.
  - Added safe fallback helpers for overlay text normalization, coordinate subtext, guide-goal visibility, quest IDs, goal coordinates, and goal actions.
  - Guarded Zygor canonical-goal handling so APR, WoWPro, manual routing, queues, and non-Zygor routing backends can initialize normally without Zygor.

## 4.0.0

- **AzerothWaypoint rename and v4 reset**
  - AzerothWaypoint replaces ZygorWaypoint across the addon TOC, namespace, media paths, help text, settings text, chat output, and `/awp` command surface.
  - Legacy v1/v2/v3 SavedVariables migration/repair paths were removed. `ApplyDBDefaults` now fills and normalizes the new database shape instead of carrying old upgrade logic.
  - Startup detects an old `ZygorWaypoint` addon still loaded/installed and warns about the conflict. `StartZygorWaypointConflictReminders` repeats a reminder until the old addon is disabled/removed.
  - TomTom is the only required dependency. Zygor Guides Viewer, APR, WoWPro, Mapzeroth, FarstriderLib, FarstriderLibData, and WorldQuestTab are optional integrations.

- **Startup prompts and first-run guidance**
  - Added a Zygor arrow conflict prompt: when Zygor's own Waypoint Arrow is enabled, AWP offers a one-click "Turn Off Zygor Arrow" action or a decline option.
  - The Zygor arrow prompt is delayed at startup so it does not collide with other startup popups.

- **Guide provider system**
  - Replaced the old Zygor-only guide path with a guide provider dispatcher.
  - Added built-in providers for:
    - Zygor Guides Viewer.
    - Azeroth Pilot Reloaded.
    - WoWPro.
  - Providers register label, icon, tint, size, visibility, extraction, activation token, hooks, and debug behavior through the provider API.
  - Guide provider state is tracked separately per provider, with active-provider persistence and passive guide queue projection.
  - Explicit guide activation can switch the active guide provider while manual/transient route authority remains higher priority.
  - Guide queues can exist for providers that are visible but not currently controlling the active route.
  - Provider and presentation files are loaded from the TOC, but provider-specific code exits early when the source addon is not loaded/enabled.

- **Zygor integration**
  - Preserved Zygor parity including:
    - Zygor guide resolver.
    - Canonical target extraction.
    - LibRover-backed routing backend.
    - Zygor POI takeover.
    - Compact viewer chrome.
    - Starlight and Stealth arrow themes.
  - Moved Zygor POI support out of `bridge/takeovers/tomtom_bridge_zygor_poi_takeover.lua` into `integrations/guides/zygor/zygor_poi.lua`.
  - Zygor provider code now participates in the same provider arbitration system as APR and WoWPro.
  - Zygor guide presentation continues to use the existing resolver, facts, live context, presentation context, snapshots, cases, scans, and resolution modules.

- **APR integration**
  - Added APR provider support under `integrations/guides/apr/`.
  - Extracts active step, route coordinates, title, visibility, activation token, and guide queue projection.
  - APR coordinates are treated as APR world-space coordinates, not 0-100 map percentages.
  - Added `apr_presentation.lua` for actionable APR overlay titles:
    - `Accept 'Quest Name'`
    - `Turn in 'Quest Name'`
    - exact objective text for progress steps when available.
  - Multi-quest pickup/turn-in steps select one actionable quest title at a time instead of cramming multiple quest names into one title.
  - APR helper text uses `ExtraLineText`, `ExtraLineText2`, and APR text/locale resolution helpers.
  - Quest-backed APR steps set quest semantics and quest icon hints only when a real quest ID is found.
  - Added APR debug output for action key, quest IDs, primary quest ID, title source, subtext source, final title, final subtext, and coordinates.
  - Added `integrations/guides/apr/APR-Route-Syntax.md` as local implementation reference material.

- **WoWPro integration**
  - Added WoWPro provider support under `integrations/guides/wowpro/`.
  - Extracts active step index, guide ID, map ID, coordinate strings, visibility, and queue projection.
  - WoWPro coordinates are parsed as 0-100 percentages and converted to AWP's 0-1 coordinate format.
  - Multi-coordinate WoWPro steps choose the final destination target used by WoWPro's own routing logic.
  - Added `wowpro_presentation.lua` for actionable WoWPro overlay titles:
    - accept steps.
    - turn-in steps.
    - completion/progress steps.
    - note/instruction steps.
    - travel, use, and loot actions.
  - Completion steps can use the WoWPro note as title while objective progress becomes subtext, such as `1/6 Blackrock Worg slain`.
  - Quest progress subtext prefers WoWPro objective data and falls back to shared Blizzard quest helpers.
  - WoWPro TomTom and `C_Map.SetUserWaypoint` signals are handled as guide provider input, not generic manual queue adoption.
  - Added WoWPro debug output for action, raw step, note, QO data, quest IDs, primary quest ID, title/subtext sources, final title, and final subtext.
  - Added `integrations/guides/wowpro/WoWPro-Syntax.md` as local implementation reference material.

- **Routing backends**
  - Routing is now planned by selectable backends instead of being tied directly to one guide addon.
  - Added four routing backends:
    - TomTom Direct: always-available single-leg fallback.
    - Farstrider: FarstriderLib/FarstriderLibData routing with portals, boats, zeppelins, items, spells, and availability invalidation.
    - Mapzeroth: Mapzeroth graph routing with travel nodes and instance entrance support.
    - Zygor: LibRover-backed routing for Zygor users.
    - TomTom Direct: always-available single-leg fallback. PURE TomTom, no pathfinding.
  - First-run backend priority is Zygor > Farstrider > Mapzeroth > TomTom Direct.
  - Invalid or unavailable backend selections fall back to Direct.
  - The backend dropdown exposes backend availability and disabled/missing states.
  - Route signatures include guide provider/source details so identical coordinates from different providers do not merge into the wrong authority state.
  - Added backend-specific fallback handling for missing planners, no-path results, empty plans, timeout fallbacks, and direct fallback legs.

- **Routing engine rewrite**
  - Replaced the old monolithic bridge sync model with modular `bridge/routing/` files.
  - Added explicit routing layers:
    - Authority: current manual/guide ownership and persisted manual route state.
    - Identity: normalized metadata for manual routes, map pins, quests, area POIs, vignettes, taxis, dig sites, housing plots, Zygor POIs, and external callers.
    - Backend: pluggable route planning.
    - Carrier: TomTom Arrow synchronization.
    - Presentation: shared title, subtext, icon hint, semantic kind, and route leg display data.
  - Persistent active-route source now survives reload/login when possible.
  - Route environment tracking captures zone, real zone, subzone, minimap zone, indoor state, and route gate matching.
  - The v3 TickUpdate heartbeat is no longer the primary route driver; v4 routing reacts through explicit evaluator and invalidation paths. Cleaner and more efficient.
  - Improved TomTom carrier synchronization, external clear detection, route invalidation, and guide visibility hooks.

- **Special travel actions**
  - Added route legs for items, spells, toys, hearthstones, and similar travel actions.
  - Added a secure special travel button that replaces the arrow when the current route leg requires a clickable action.
  - Added combat-safe secure attribute handling.
  - Added route replan suppression while a special action is being prepared or clicked.
  - Added Special Travel Button Scale in the TomTom Arrow options section.
  - Added special travel button preview metadata and help media.

- **Manual queues**
  - Added queue modules under `bridge/routing/queues/` for state, items, routing, policy, projection, and snapshots.
  - Added persistent manual queues with stable queue IDs, labels, active item index, item metadata, and route restoration.
  - Added destination queues for multi-destination manual-click flows.
  - Added route queues for single route-like entries.
  - Added transient queues for short-lived external sources such as SilverDragon, RareScanner, and gossip-style (such as guard directions) transient destinations.
  - Added guide-projected queues so active guide destinations appear in the queue panel even when another source controls the route.
  - Manual queues stay listed when guide routing is active.
  - Guide queues stay listed when a manual queue is active.
  - `StopUsingManualQueue` lets a queue stop controlling the active route without deleting that queue.
  - Queue follow-up advances to the next queued destination after clear/arrival.
  - Imported `/ttpaste` and similar multi-waypoint batches are always stored and routed as ordered AWP queues.

- **Queue UI**
  - Added a waypoint queue side tab on the world map.
  - Added queue list view, detail view, summary panel, scrollable rows, and queue sections.
  - Queue sections include transient queues, manual queues, and user guide queues.
  - Added queue activation, queue deactivation, queue clearing, destination activation, destination removal, final-destination focus, import support, and quest-log switching.
  - Added per-row delete icons
  - Added checkbox multi-select for queues and destinations.
  - Added bulk delete icons inside the panel/detail borders.
  - Added context menus for queue rows and destination rows.
  - Guide queues are read-only.
  - Added `/awp queue` commands for panel/open/show, list/ls, use, clear, remove/rm, move, import/paste/ttpaste, and help.

- **Manual click queue prompt**
  - Added Manual Click Queue Behavior with Create New Queue, Replace Active, Append, and Ask.
  - Default mode is `replace`.
  - Unknown/invalid saved mode values normalize to `create`.
  - Ask mode opens a prompt so each manual destination can be placed as a new queue, replacement, or appended to the existing queue.
  - Ask mode is integrated with user waypoint and map pin takeover flows.
  - Added help/preview/search metadata for the prompt and behavior values.

- **Blizzard, TomTom, and addon takeovers**
  - Expanded takeover coverage for:
    - User waypoints.
    - Quests and supertracked quests.
    - Area POIs.
    - Vignettes.
    - Taxi destinations.
    - Gossip POIs.
    - Dig sites.
    - Housing plots.
  - Added shared Blizzard takeover core handling for map pin changed/cleared behavior and adoption retries.
  - Added quest-backed manual metadata for quest ID, quest state, quest type, world quest type, source addon, semantic kind, and icon hints.
  - Improved presentation for available, incomplete, complete, repeatable, world quest, dungeon, raid, delve, racing, and travel targets.
  - Improved tracked, untracked, supertracked, removed, and turned-in quest cleanup behavior for both active routes and queue items.
  - Added unknown addon waypoint adoption controls with a toggle, allowlist, blocklist, recent caller list, and chat commands.

- **WorldQuestTab integration**
  - Added `integrations/worldquesttab_takeover.lua`.
  - WorldQuestTab quest pin clicks now route through the v4 routing pipeline.
  - Captures title, quest ID, map, coordinates, source addon, and quest context from WorldQuestTab where available.
  - Falls back to Blizzard quest APIs when WorldQuestTab data is not ready.

- **External waypoint source registry**
  - Added `integrations/external_waypoint_sources.lua`.
  - Added metadata descriptors for SilverDragon and RareScanner.
  - Centralized external source normalization, display names, transient behavior, stack/path matching, and icon keys.
  - Replaced scattered SilverDragon/RareScanner checks in routing, queues, presentation, and world overlay content with registry helpers.
  - Persisted source keys remain lowercase.

- **World overlay architecture**
  - Renamed the internal namespace to `NS.Internal.WorldOverlay`.
  - Split the former `world_overlay/native/` folder into:
    - `world_overlay/core/`
    - `world_overlay/assets/`
    - `world_overlay/pinpoint/`
    - `world_overlay/presentation/`
    - `world_overlay/runtime/`
  - Split API, config, state, icons, quest types, colors, content, frames, host, render, plaques, and plaque animation into focused modules.
  - Moved shared textures from `media/world-overlay/waypoint/` to `media/world-overlay/`.
  - Moved plaque textures into `media/world-overlay/plaques/`.

- **World overlay presentation**
  - Moved icon specs and quest type handling into `world_overlay/assets/`.
  - Moved color and content presentation into `world_overlay/presentation/`.
  - Fixed atlas/texture carryover by resetting texture coordinates before applying atlas icons in `world_overlay/presentation/content.lua`.
  - Added Gray as a neutral preset.
  - Waypoint footer text defaults to Gray, while Auto uses contextual icon/spec tint.
  - Removed the old None color option because it because it was identical to White which we already offered.
  - Color dropdown options are alphabetized (excluding Custom) and include Auto, Custom, Blue,  Cyan, Gold, Gray, Green, Pink, Purple, Red, Silver, and White.
  - Added shared Auto dropdown preview text explaining contextual target hints.
  - Added icon/tint support for gossip services, external sources, quest families, world quests, racing quests, dungeons, raids, delves, portals, taxis, inns, route legs, and travel actions.
  - Available quest POIs no longer show in-progress objective subtext before the quest is accepted.
  - Quest objective text refresh now uses shared quest helpers and cache invalidation.

- **Pinpoint, waypoint, and navigator**
  - Moved plaque assets into the plaque media folder.
  - Added help media for overlay base/fade, navigator, small navigator, pinpoint, pinpoint off, pinpoint plaque off, and all footer modes.
  - Improved display state cleanup around waypoint, pinpoint, navigator, arrival, and hidden transitions.

- **TomTom arrow skins**
  - Added a TomTom arrow skin framework system in `core/arrowskins.lua`.
  - Added AWP, AWP Bomber, AWP Modern, Alliance, and Horde skins.
  - Each new skin ships nav, arrival, and specular assets as appropriate.
  - Kept Starlight and Stealth Zygor mirror skins when Zygor is loaded.
  - Added skin preset support for single-image custom arrows, TomTom classic/modern layouts, and Zygor mirror/full sprite layouts.
  - Added per-skin options previews.
  - Fixed preview key collisions for skins with spaces/custom IDs.
  - Preserved the last selected custom skin when toggling Use Custom Arrow Skin off and on.

- **Options UI**
  - Replaced the old options panel with a custom options panel under `interface/options/`.
  - Added About, General, TomTom Arrow, World Overlay, Waypoint, Pinpoint, Navigator, and conditional Zygor sections.
  - Added option search, filters, release notes, preview pane, dropdown value previews, and reusable widgets.
  - Added image previews for option sections, arrow skins, Zygor compact/background modes, manual queue prompts, overlay enable/fade states, context display variants, waypoint/beacon/footer modes, pinpoint modes, plaque styles, navigator, and special travel button scale.
  - Added search metadata for settings/sub-options that were rendered in `canvas_sections.lua` but not discoverable from `Data.OPTIONS`.
  - Added Detected Addon Callers UI with allow/deny controls.
  - The options window remembers its on-screen position.
  - Added a new Zygor arrow conflict prompt.

- **Help, screenshots, and documentation**
  - Refreshed help pages for Overview, Arrow and Guide, World Overlay, Waypoint and Navigator, Pinpoint and Plaque, Customization, Commands, and What's New.
  - Added help screenshots for AWP arrow skins, Zygor arrow/guide modes, manual queue prompts, queue UI list/detail views, Blizzard POI and SilverDragon adoption, options panels, overlay base/fade states, context display variants, waypoint/beacon/footer modes, navigator, pinpoint modes, plaque styles, and special travel buttons.
  - Replaced old ZWP option media with AWP option and options-general media.

- **Commands and aliases**
  - Added `/awp backend direct|zygor|mapzeroth|farstrider`.
  - Added `/awp queue ...` with `panel`, `open`, `show`, `list`, `ls`, `use`, `clear`, `remove`, `rm`, `move`, `import`, `paste`, `ttpaste`, and `help`.
  - Added `/awp untrackclear` and `/awp untrackedclear`.
  - Added `/awp addontakeover`, `/awp unknownaddons`, and `/awp addonwaypoints`.
  - Added/expanded diagnostics:
    - `/awp routedump` / `/awp routecheck`
    - `/awp routeenv` / `/awp routenv` / `/awp envroute`
    - `/awp traveldiag` / `/awp tdiag`
    - `/awp churn`
    - `/awp churnmem` / `/awp churnphases`
    - `/awp resolvercases` / `/awp resolvercase`
    - `/awp stepdebug`
    - `/awp waytype`
    - `/awp plaque` / `/awp pinpoint`
  - Added/kept aliases:
    - `/awp options` / `/awp config`
    - `/awp manualclear` / `/awp autoclear`
    - `/awp trackroute` / `/awp trackedroute`
    - `/awp questclear` / `/awp superquestclear`
    - `/awp compact` / `/awp guidechrome` / `/awp guidehover`
    - `/awp help` / `/awp tour`
    - `/awp changelog` / `/awp whatsnew` / `/awp whatnew` / `/awp new`
  - Existing status, debug, diag, mem, skin, scale, routing, cleardistance, search, and repair commands continue under `/awp`.

- **Diagnostics**
  - Expanded `/awp waytype` for live overlay target inspection and preview targets.
  - Added source-aware waytype output for guide provider, quest hints, source addon, icon source, atlas/texture, tint, route leg, quest type, and quest status.
  - Expanded route diagnostics with active source, backend, selected backend, carrier source, carrier kind, route legs, route outcome, current special action, and route environment.
  - Expanded churn diagnostics with resolver hits/misses, manual metadata lookup, route plan accept/skip counts, backend invalidations, driver updates, world overlay updates, host sync, and optional phase memory.
  - Expanded guide diagnostics for Zygor, APR, and WoWPro provider-specific output.

- **Quest text and presentation helpers**
  - Added `core/quest_text.lua`.
  - Added shared quest helpers for:
    - quest titles.
    - exact indexed objective text.
    - first unfinished objective or ready-to-turn-in text.
  - Updated world overlay content to reuse shared quest helpers while preserving cache behavior.
  - Shared quest text helpers are now used by takeovers and guide presentation layers instead of duplicating Blizzard quest API calls.
  - Quest cache invalidation now reacts to quest accepted, removed, turned in, completed, progress, gossip, and quest log update flows.

- **Search and repair**
  - Preserved `/awp search` support for services, profession trainers, profession workshops, vendor fallback, repair fallback, and aliases but only functions when Zygor is installed and enabled.
  - Updated command/help text for the renamed addon and v4 routing backend behavior.
  - Kept `/awp repair` for current TomTom/Zygor external setting repair where relevant.
  - Removed old pre-v4 SavedVariables migration behavior from repair/default application.

- **Stability and polish**
  - Improved reload/login behavior so the last controlling source is restored where possible.
  - Fixed untrack-clear behavior so queue items are not removed when the setting is disabled.
  - Added external clear detection and queue preservation for manual, transient, and guide-backed routes.
  - Reduced icon flicker/stale state when switching between addon POIs, gossip POIs, quest pins, atlas icons, texture icons, and route icons.
  - Improved TomTom Arrow suppression for WoWPro and other guide-provider signals to reduce protected-function taint risk.
  - Added guards so APR, WoWPro, and Zygor can retake route authority after another provider was active.
  - Improved title/subtext mirroring so provider presentation flows through the carrier and overlay consistently.
