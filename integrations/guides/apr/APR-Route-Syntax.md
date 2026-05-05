# Azeroth Pilot Reloaded - Route and Step Options Reference

---

## Table of Contents

1. [Route Definition Options](#route-definition-options)
2. [Action / Progression Options](#action--progression-options)
3. [Navigation and Targeting](#navigation-and-targeting)
4. [Automation and Display](#automation-and-display)
5. [Filters and Conditions](#filters-and-conditions)
6. [Miscellaneous and Legacy](#miscellaneous-and-legacy)
7. [Example Route](#example-route)
8. [Example Step](#example-step)

---

## Route Definition Options

| Option | Description | Expected Syntax |
| --- | --- | --- |
| `label` | Display name shown in the route list. | `label = "Midnight - Speedrun"` |
| `expansion` | Expansion enum used to group the route in the UI. | `expansion = APR.EXPANSIONS.Midnight` |
| `category` | Route category enum. Common values are leveling, speedrun, campaign, etc. | `category = APR.CATEGORIES.Leveling` |
| `mapID` | Main map ID for the route. Used as route metadata and zone fallback. | `mapID = 2393` |
| `prefab` | Optional prefab defaults keyed by prefab type. | `prefab = { [APR.PREFAB_TYPES.Speedrun] = 20 }` |
| `conditions` | Route visibility / availability rules. Uses the same condition keys documented in [Filters and Conditions](#filters-and-conditions). | `conditions = { Level = 80, Faction = "Alliance" }` |
| `requiredRoute` | Route key or list of route keys that must be completed first. When the route is added to the custom path, unmet required routes are auto-added before it. | `requiredRoute = { "2432-Midnight-Intro" }` |
| `nextRoute` | Suggested follow-up route keys after completion. | `nextRoute = { "2395-The-War-of-Light-and-Shadow" }` |
| `parallelSteps` | List of conditional step groups injected into the active route when their conditions become true. Each group contains `conditions` and `steps`. | `parallelSteps = { { conditions = { BeLvl = 88 }, steps = { ... } } }` |
| `steps` | Main ordered list of route steps. | `steps = { { PickUp = { 86733 } }, ... }` |

Notes:

- `parallelSteps` groups are inserted at the player's current progression point when activated.
- If the player is currently inside a block of `InstanceQuest` steps, parallel groups are inserted after that block.
- `parallelSteps[].conditions` use the same keys as normal route / step conditions.

---

## Action / Progression Options

| Option | Description | Expected Syntax |
| --- | --- | --- |
| `ExitTutorial` | Exile's Reach specific step that auto-skips if the exit quest is no longer tracked. | `ExitTutorial = 59985` |
| `PickUp` | List of quest IDs to pick up. The step remains active until all quests are in the log. If using `PickUpDB`, keep a base `PickUp` field as well. | `PickUp = { 39688 }` |
| `PickUpDB` | Alternative quest IDs for the same pickup step (class / faction variants). Requires `PickUp`. | `PickUpDB = { 39688, 39694, 40255, 40256 }` |
| `DropQuest` | Quest obtained from a mob drop. Must be paired with a corresponding `DroppableQuest`. | `DropQuest = 48876` |
| `DroppableQuest` | Defines passive or active dropped-quest tracking. When used without `DropQuest`, it behaves like a filler hint. | `DroppableQuest = { Qid = 41234, MobId = 133713, Text = "Fel Marauder" }` |
| `Qpart` | Quest objectives to complete, mapped by quest ID and objective index. | `Qpart = { [12345] = { 1, 2 } }` |
| `QpartDB` | Alternative quest IDs for the same `Qpart` block. Requires `Qpart`. | `QpartDB = { 12345, 12346 }` |
| `QpartPart` | Splits a single objective into guided sub-parts. Commonly paired with `TrigText`. Supports fraction and percentage style progress markers. | `QpartPart = { [12345] = { 1 } }, TrigText = "1/3"` |
| `Fillers` | Optional side objectives that can progress during any step without blocking the route. | `Fillers = { [49529] = { 1 }, [49897] = { 1 } }` |
| `Done` | Quests to turn in. The step completes once all listed quests are handed in. If using `DoneDB`, keep a base `Done` field as well. | `Done = { 12345, 12400 }` |
| `DoneDB` | Alternative quest IDs counted as the same hand-in. Requires `Done`. | `DoneDB = { 12345, 54321 }` |
| `Treasure` | Treasure or vignette step. The addon tracks the treasure's anchor quest, with optional item details for the tooltip. | `Treasure = { questID = 89105, itemID = 238553 }` |
| `Group` | Marks an optional group quest and shows a popup (`questID`, `Number`). | `Group = { questID = 51384, Number = 3 }` |
| `GroupTask` | Associates the step with `WantedQuestList` to store the player's decision for a group quest. | `GroupTask = 51384` |
| `Achievement` | Tracks a specific achievement criterion. | `Achievement = { achievementID = 61576, criteriaIndex = 1 }` |
| `Scenario` | Fine-grained scenario objective tracking (`scenarioID`, `stepID`, `criteriaID`, etc.), optionally tied to a quest ID. | `Scenario = { criteriaID = 106007, criteriaIndex = 1, scenarioID = 3101, stepID = 15911, questID = 86820 }` |
| `EnterScenario` | Guides the player to a scenario entrance. | `EnterScenario = { questID = 86636, mapID = 2502 }` |
| `DoScenario` | Indicates that the player should complete the scenario. | `DoScenario = { questID = 86912, mapID = 2505 }` |
| `LeaveScenario` | Prompts to leave the scenario once objectives are done. | `LeaveScenario = { questID = 86912, mapID = 2505 }` |
| `EnterInstance` | Guides the player into an instance. | `EnterInstance = { questID = 12345, mapID = 2505 }` |
| `LeaveInstance` | Prompts to leave the instance once objectives are done. | `LeaveInstance = { questID = 12345, mapID = 2505 }` |
| `SetHS` | Step to set the Hearthstone. | `SetHS = 31732` |
| `UseHS` | Step to use the Hearthstone. | `UseHS = 31732` |
| `UseDalaHS` | Dalaran Hearthstone variant. | `UseDalaHS = 44184` |
| `UseGarrisonHS` | Garrison Hearthstone variant. | `UseGarrisonHS = 110560` |
| `UseItem` | Step requiring the use of a specific quest item. | `UseItem = { questID = 42008, itemID = 173430, itemSpellID = 254294 }` |
| `UseSpell` | Requires casting a specific spell tied to a quest. | `UseSpell = { questID = 42476, spellID = 193759 }` |
| `UseFlightPath` | Step for using a flight master. Validates once the flight is complete. | `UseFlightPath = 39580` |
| `GetFP` | Learn a flight path node. | `GetFP = 2395` |
| `LearnProfession` | Checks if a specific profession spell is learned. | `LearnProfession = 2259` |
| `LootItems` | Tracks required quest items in bags. Each entry can be bound to a quest ID. | `LootItems = { { questID = 86644, itemID = 244143, quantity = 1 } }` |
| `WarMode` | Instructs to enable War Mode through the related quest. | `WarMode = 60361` |
| `Grind` | Requires reaching a specific player level before proceeding. | `Grind = 60` |
| `LeaveQuest` | Abandons a single quest from the quest log. | `LeaveQuest = 38254` |
| `LeaveQuests` | Abandons multiple quests from the quest log. | `LeaveQuests = { 38254, 38257 }` |
| `VehicleExit` | Forces exiting a vehicle. | `VehicleExit = true` |
| `MountVehicle` | Automatically validates when a mount / boarding event is detected. | `MountVehicle = true` |
| `NpcDismount` | Automatically dismounts to talk to the targeted NPC. | `NpcDismount = 43733` |
| `ResetRoute` | Shows a confirmation popup that resets the active route back to step 1. | `ResetRoute = true` |
| `Emote` | Requires performing an emote on a target or at a step. | `Emote = "salute"` |
| `ChromiePick` | Selects a specific Chromie Time timeline by option ID. | `ChromiePick = 8` |
| `BuyMerchant` | Prompts the player to buy one or more items from a merchant. Can be used as a main or secondary action. | `BuyMerchant = { { itemID = 193890, quantity = 1, questID = 66680 } }` |
| `Note` | Informational step. Accepts a single string or an array of strings. Intended as a standalone note-only step; seen notes are remembered and can auto-skip on later resets / revisits. | `Note = { "Open the map", "Follow the bridge north" }` |
| `RouteCompleted` | Marks the route as finished and triggers route completion flow. Must stay as the last step. | `RouteCompleted = true` |

---

## Navigation and Targeting

| Option | Description | Expected Syntax |
| --- | --- | --- |
| `Coord` | World coordinates used by the arrow (`x`, `y` in WoW units). | `Coord = { x = 4298.4, y = -864.1 }` |
| `Coords` | Multiple coordinate variants for the same step. Typically paired with `Zones`; each entry should include its own `Zone`. | `Coords = { { Zone = 84, x = 797.7, y = -8624.9 }, { Zone = 85, x = -4436, y = 1590.3 } }` |
| `Zone` | Expected map ID for the step. | `Zone = 627` |
| `Zones` | Multiple valid map IDs for a single step. Also acts as a condition: the step is only considered valid when the player is in one of those maps. | `Zones = { 84, 85 }` |
| `Range` | Distance in yards from `Coord` to consider the location reached. | `Range = 45` |
| `ZoneStepTrigger` | Automatically validates the step when entering the specified radius. | `ZoneStepTrigger = { x = 4098.2, y = -712.4, Range = 25 }` |
| `Waypoint` | Quest-related waypoint displayed until completion. | `Waypoint = 44543` |
| `WaypointDB` | Alternative waypoint quests that allow skipping if already completed. Requires `Waypoint`. | `WaypointDB = { 44543, 44544 }` |
| `NonSkippableWaypoint` | Prevents the step from being skipped manually. | `NonSkippableWaypoint = true` |
| `SingleWaypointDisplayDistance` | Changes the arrow distance display so it only shows the distance to the next waypoint / coord instead of summing the whole remaining chain. | `SingleWaypointDisplayDistance = true` |
| `TakePortal` | Step requiring the player to use a portal. The step validates once the target zone is reached or the linked quest is already completed. | `TakePortal = { questID = 81888, ZoneId = 85 }` |
| `NodeID` | Flight path node ID used on `UseFlightPath` steps. | `NodeID = 1719` |
| `Name` | Optional custom name to override the taxi node name. | `Name = "Krasus' Landing"` |
| `Boat` | Indicates the player should take a boat instead of flying. Requires `UseFlightPath`. | `Boat = true` |
| `NoArrow` | Hides the navigation arrow for this step. | `NoArrow = true` |
| `NoAutoFlightMap` | Prevents automatic flight / gossip selection for this step. | `NoAutoFlightMap = true` |
| `InstanceQuest` | Marks the step as taking place inside an instance. | `InstanceQuest = true` |
| `IsAdventureMap` | Allows auto-accepting quests from the Adventure Map. | `IsAdventureMap = true` |
| `ETA` | Estimated AFK timer duration in seconds. | `ETA = 75` |
| `GossipETA` | Starts an AFK timer after gossip confirmation. | `GossipETA = 45` |
| `SpecialETAHide` | Hides the AFK timer even if `ETA` is set. | `SpecialETAHide = true` |

---

## Automation and Display

| Option | Description | Expected Syntax |
| --- | --- | --- |
| `Buffs` | List of buff spell IDs to recommend. | `Buffs = { { spellId = 311103, tooltipMessage = "FRESHLEAF_BUFF" } }` |
| `Button` | Associates items to use with objectives (`"QuestID-Objective"` -> `itemID`). Can also be used with non-objective steps by using only the quest ID as the key. | `Button = { ["30778-1"] = 81356 }` |
| `SpellButton` | Same idea as `Button`, but for spells (`"QuestID-Objective"` -> `spellID`). | `SpellButton = { ["49939-1"] = 294197 }` |
| `SpellTrigger` | Automatically completes the step when the given spell is cast. | `SpellTrigger = 306719` |
| `ExtraActionB` | Prompts use of the special extra action button. | `ExtraActionB = true` |
| `TrigText*` | Text fragments used as completion triggers (`TrigText`, `TrigText2`, etc.). | `TrigText = "Restore the console"` |
| `ExtraLineText*` | Additional helper lines displayed in the current step panel. Supports numbered variants such as `ExtraLineText2`, `ExtraLineText3`, etc. | `ExtraLineText = "Interact with the second console"` |
| `PreviewImages` | Displays one or more clickable image previews in the current step panel. Relative paths are resolved from `APR-Core/assets/`; full `Interface\\...` paths are also accepted. | `PreviewImages = { "routeHelper\\86644.jpg" }` |
| `Bloodlust` | Adds a reminder to use Heroism / Bloodlust. | `Bloodlust = true` |
| `InVehicle` | Indicates vehicle status (`1` = enter, `2` = stay in vehicle). | `InVehicle = 1` |
| `UseGlider` | Displays available gliders for controlled jumps. | `UseGlider = true` |
| `DenyNPC` | NPC ID whose gossip should be closed automatically. | `DenyNPC = 209914` |
| `RaidIcon` | NPC ID to mark with a raid icon. | `RaidIcon = 241743` |
| `GossipOptionIDs` | Automates gossip selection by specific option IDs. Use `main` for the first interaction and `secondary` for follow-up actions if needed. | `GossipOptionIDs = { 51901, 51902 }` |
| `Dontskipvid` | Prevents automatic skipping of cutscenes or videos. | `Dontskipvid = true` |

---

## Filters and Conditions

These keys can be used directly on steps, inside route-level `conditions`, or inside `parallelSteps[].conditions`.

| Option | Description | Expected Syntax |
| --- | --- | --- |
| `Faction` | Restricts to a faction (`"Alliance"` or `"Horde"`). | `Faction = "Horde"` |
| `Race` | Restricts to one or more races. | `Race = { "Orc", "Troll" }` |
| `Gender` | Restricts to a gender (`1` neutral, `2` male, `3` female). | `Gender = 3` |
| `Class` | Restricts to one or more classes. | `Class = { "HUNTER", "ROGUE" }` |
| `ClassNot` | Inverse class filter. Hides / disables the step or route for the listed class or classes. | `ClassNot = APR.Classes.Evoker` |
| `ClassSpec` | Restricts to a specialization ID. For routes, failing this condition makes the route disabled rather than hidden. | `ClassSpec = APR.Specs["Mage - Frost"]` |
| `Level` | Minimum player level required. | `Level = 80` |
| `MinLevel` | Explicit minimum level. | `MinLevel = 10` |
| `MaxLevel` | Maximum level allowed. | `MaxLevel = 69` |
| `BeLvl` | Exact effective level check. The player must be at least this level, but below the next whole level. | `BeLvl = 88` |
| `SkipForLvl` | Skips the step once the player's effective level is greater than or equal to the given value. | `SkipForLvl = 89.18` |
| `AlliedRace` | Restricts based on whether the character is an allied race. | `AlliedRace = true` |
| `Event` | Restricts to a specific APR event mode, such as Remix. | `Event = APR.EVENTS.Remix` |
| `HasAchievement` | Requires a specific achievement. | `HasAchievement = 12593` |
| `DontHaveAchievement` | Visible only if the achievement is missing. | `DontHaveAchievement = 9924` |
| `HasAura` | Requires a specific buff or aura. | `HasAura = 178207` |
| `DontHaveAura` | Requires the aura to be absent. | `DontHaveAura = 32182` |
| `HasSpell` | Requires the player to know a specific spell. | `HasSpell = 34090` |
| `IsQuestCompleted` | Requires a single quest to be completed. | `IsQuestCompleted = 35049` |
| `IsQuestUncompleted` | Requires a single quest to be incomplete. | `IsQuestUncompleted = 35049` |
| `IsOneOfQuestsCompleted` | Requires at least one quest in the list to be completed. | `IsOneOfQuestsCompleted = { 31588, 31589 }` |
| `IsOneOfQuestsUncompleted` | Requires at least one quest in the list to be incomplete. | `IsOneOfQuestsUncompleted = { 31588, 31589 }` |
| `IsOneOfQuestsCompletedOnAccount` | Account-wide variant of `IsOneOfQuestsCompleted`. | `IsOneOfQuestsCompletedOnAccount = { 49929, 49930 }` |
| `IsOneOfQuestsUncompletedOnAccount` | Account-wide variant of `IsOneOfQuestsUncompleted`. | `IsOneOfQuestsUncompletedOnAccount = { 49929, 49930 }` |
| `IsQuestsCompleted` | Requires all listed quests to be completed. | `IsQuestsCompleted = { 31821, 31822 }` |
| `IsQuestsUncompleted` | Requires at least one listed quest to still be incomplete. | `IsQuestsUncompleted = { 31821, 31822 }` |
| `IsQuestsCompletedOnAccount` | Account-wide variant of `IsQuestsCompleted`. | `IsQuestsCompletedOnAccount = { 49929, 49930 }` |
| `IsQuestsUncompletedOnAccount` | Account-wide variant of `IsQuestsUncompleted`. | `IsQuestsUncompletedOnAccount = { 49929, 49930 }` |
| `QuestLineSkip` | Prevents the optional group popup if a questline is intentionally skipped. | `QuestLineSkip = 51226` |
| `PickedLoa` | Specifies the chosen Loa in Zandalar (`1` = Bwonsamdi, `2` = Rezan). | `PickedLoa = 1` |
| `IsCampaignQuest` | Marks the step as part of a campaign. | `IsCampaignQuest = true` |

---

## Miscellaneous and Legacy

| Option | Description | Expected Syntax |
| --- | --- | --- |
| `ExtraLine` | Legacy field for displaying a static localized helper line. | `ExtraLine = 13544` |
| `Gossip` | Legacy field for automatically selecting a gossip option by index. | `Gossip = 2` |
| `_index` | Internal index auto-generated during route packaging. Do not edit manually. | `_index = 128` |

---

## Example Route

```lua
APR.RouteQuestStepList["2393-Midnight-Speedrun"] = {
    label = "Midnight - Speedrun",
    expansion = APR.EXPANSIONS.Midnight,
    category = APR.CATEGORIES.Leveling,
    mapID = 2393,
    conditions = { Level = 80 },
    requiredRoute = { "2432-Midnight-Intro" },
    nextRoute = { "2395-The-War-of-Light-and-Shadow" },
    parallelSteps = {
        {
            conditions = { BeLvl = 88 },
            steps = {
                {
                    Done = { 93384 },
                    Coord = { x = -4816.2, y = 8315.6 },
                    Zone = 2395,
                },
            },
        },
    },
    steps = {
        {
            PickUp = { 86733 },
            Coord = { x = -4614.4, y = 10085.4 },
            IsCampaignQuest = true,
            Zone = 2424,
        },
        {
            RouteCompleted = true,
        },
    },
}
```

---

## Example Step

```lua
{
    LootItems = {
        { questID = 86644, itemID = 244143, quantity = 1 },
    },
    Coord = { x = -4672.3, y = 7802.5 },
    Zone = 2395,
    SingleWaypointDisplayDistance = true,
    ExtraLineText = "Loot the first focus",
    PreviewImages = { "routeHelper\\86644.jpg" },
    _index = 101,
},
{
    Note = {
        "The second focus is hidden behind the broken arch.",
        "Click the preview image above if you need a visual reference.",
    },
    Coord = { x = -4661.8, y = 7791.9 },
    Zone = 2395,
    _index = 102,
},
{
    TakePortal = { questID = 81888, ZoneId = 85 },
    Coord = { x = -8908.1, y = 555.2 },
    Zone = 84,
    _index = 103,
}
```
