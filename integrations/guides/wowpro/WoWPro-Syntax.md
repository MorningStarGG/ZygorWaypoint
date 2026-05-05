With the WoW-Pro Recorder, you don't really need to know the syntax (the language the guide files are written in) unless you really want to. However, taking a look at this syntax can help you understand how the addon works and can help you do a better job of writing and designing guides for the addon.

Remember, if you have any specific questions about the addon's syntax, feel free to ask in our Discord chat.

* * *

# <a name="Table_of_Contents">Table of Contents</a>

* * *

1.  [Overview](#overview)
    *   [Opening a File to Edit](#opening)
    *   [Anatomy of a Guide File](#anatomy)
    *   [Guide Registration Functions](#registration)
    *   [The Guide Code](#code)
2.  [Step Types](#color)
    *   [A – Quest Accept](#accept)
    *   [b – Boat/Zeppelin](#run)
    *   [B – Buy](#notetype)
    *   [C – Quest action](#complete)
    *   [f – Get Flight Point](#getfp)
    *   [F – Fly](#run)
    *   [h – Set Hearth](#sethearth)
    *   [H – Use Hearth](#run)
    *   [K – Kill](#notetype)
    *   [l - Loot](#notetype)
    *   [L - Level](#notetype)
    *   [N - Note](#notetype)
    *   [P – Portal](#run)
    *   [r – Repair/Restock](#repair)
    *   [R – Run](#run)
    *   [t – Quest Turn-in (suppressible)](#supressturnin)
    *   [T – Quest Turn-in](#turnin)
    *   [U – Use](#notetype)
    *   [; - Comment](#commentstep)
    *   [$ - Treasure](#treaurestep)
    *   [* - Trash Item](#trash)
3.  [Tags](#spells)
    *   [|ACH| – Achievement](#achievement)
    *   [|ACTIVE| – QID is in quest log test](#active)
    *   [|AVAILABLE| – QID can be picked up test](#available)
    *   [|BUFF| – Unit Buff test](#buff)
    *   [|BUILDING| – Building Detector](#building)
    *   [|C| – Class test/filter](#classrace)
    *   [|CC| – Coordinate Auto-complete](#waycomplete)
    *   [|CHAT| – Chat icon](#chat)
    *   [|CN| – Coordinate No Auto-complete](#waycomplete)
    *   [|CS| – Coordinate Auto-complete in Sequence](#waycomplete)
    *   [|DFREN| - Dragonflight Renown Level](#dfren)   
    *   [|FACTION| – This tag specifies the faction for which the step is intended](#faction) 
    *   [|FLY| – Skip travel step](#fly)
    *   [|H| - Hand icon](#noncombat)
    *   [|I| - Inspection icon](#noncombat)
    *   [|ITEM| - Shows item picture and a mouseover note at the beginning of the step note](#item)
    *   [|IZ| - Current zone test](#inzone)  
    *   [|L| – Loot item](#loot)
    *   [|LEAD| – QID Breadcrumb Quest availability test](#lead)
    *   [|LVL| – Level test](#level)
    *   [|N| – Step note](#note)
    *   [|NA| – Prevent Automation](#notauto)
    *   [|NC| – Non-Combat icon](#noncombat)
    *   [|NOCACHE| – Not Cached](#nocache)
    *   [|M| – Map coordinates](#coord)
    *   [|MID| - Mission ID](#mid)
    *   [|O| – Optional](#optional)
    *   [|P| – Profession](#profession)
    *   [|PET| – Pet Detector](#pet)
    *   [|PRE| – Prerequisite QID test](#pre)
    *   [|QG| – Quest Gossip](#questgossip)
    *   [|QID| – Quest ID](#qid)
    *   [|QO| – Quest Objective](#questobjective)
    *   [|R| – Race test/filter](#classrace)
    *   [|RANK| – Rank setting test](#rank)
    *   [|RECIPE| – Recipe](#recipe)
    *   [|REP| – Reputation](#reputation)
    *   [|S| – Sticky](#sticky)
    *   [|S!US| – Permanent Sticky](#nounsticky)
    *   [|SPELL| – Spell](#spell)
    *   [|T| – Target](#target)
    *   [|TAXI| - Flight path test](#taxi)
    *   [|TZ| – Target Zone/Subzone test](#tzone)
    *   [|U| – Use](#use)
    *   [|US| – Unsticky](#sticky)
    *   [|V| – Enter Vehicle](#vehicle)
    *   [|Z| – Zone](#zone)
4.  [Comments](#comments)

* * *

## <a name="Overview">Overview</a>

* * *

To start with, I suggest working with a guide that has already been coded, rather than trying to start from scratch.

### <a name="opening">Opening a File to Edit</a>

I highly recommend the free program [Notepad++](http://notepad-plus.sourceforge.net/uk/site.htm), as do most addon authors - it's very powerful yet simple for beginners, with a very user-friendly interface.

[[Back to top]](#top)

### <a name="anatomy">Anatomy of a Guide File</a>

<pre class="bb-code-block">local guide = WoWPro:RegisterGuide("LudoExpDaS","Achievements","Darkshore","Ludovicus", "Neutral")
WoWPro:GuideLevels(guide,20,90)
WoWPro:GuideIcon(guide,"ACH",844)
WoWPro:GuideSteps(guide, function()
return [[

INSERT GUIDE CODE HERE

]]
end)</pre>

In the example, where I say "INSERT GUIDE CODE HERE", you'll see many lines of code. We'll talk about those in a minute. For now, we're going to talk about the guide registration functions.

[[Back to top]](#top)

### <a name="registration">Guide Registration Function</a>

The guide registration functions are what tells the addon the overall information about the guide. It contains several important parts, as follows:

1.  The function
	The actual name of the function we are calling: WoWPro:RegisterGuide

2.  The Guide ID

    *   The first few letters of the author’s name (Ludo for Ludovicus in this case)
    *   The first few letters of the guide zone or type (Exp for Explore in this case and DaS for Darkshore)
    *   For leveling guides, the level range in double digits (0112 for 01-12 for example) is appended.

3.  Guide Type
	The next section, “LudoExpDaS” in the example, is the Guide ID (or GID). This was implemented as a means to give guides a unique ID since zones and authors and level ranges separately might overlap. The GID consists of:
    *   achievements
    *   leveling
    *   professions
    *   dailies
    *   worldevents

4.  The zone
	Pretty self explanatory. “Darkshore” in the example. This does not have to be a valid zone, but if it is not, a|Z| (zone) tag must be used on every line of the guide. It controls which map will be used for mapping (which can be overwritten with a |Z| tag), and also what name the guide have in the menu (ESC>Addons>WoW-Pro>Guide List) as well as the name showing at the top of the active guide pane. A better way of changing the guide name is to use the code WoWPro:GuideName(guide, 'name here') discussed below.

    NOTE1: You can provide more information about the guide after a "-" or a "(". For example, a valid zone entry would be Scarlet Enclave (Death Knight) or Durotar - Valley of Trials.

5.  The author
	Again pretty simple. “Ludovicus” in the example.

6.  Faction
	The faction the guide is intended for. Can be Horde, Alliance, or Neutral.

7.  The return value
	The guide object is returned, which you can now feed into some additional functions to more fully describe the guide.

[[Back to top]](#top)

### <a name="description">Guide Registration Functions Descriptions</a>

*   __WoWPro:GuideLevels(guide, start_level, end_level, mean_level)__\
	This is Optional.\
	The starting, ending and average level for the quests in the guide. It is not what level you will end up at by doing the guide, it is the required level to get the quests even if you have XP locked down.\
	The start_level controls when a guide will be offered to the user. The mean level sets the "color" of the guide to indicate difficulty. The end_level controls a warning to XP locked users that not all quests in the guide can be completed.\
        This should not be used in the same guide as WoWPro:GuideUseMapLevels.

*   __WoWPro:GuideUseMapLevels(guide, mapID)__\
	This is Optional.\
        Set the starting, ending and average levels for the quests in the guide based on the level range for the supplied map.\
        This will automatically adjust for Chromie Time and Adventure mode but is only checked on a full guide reload.\
        This should not be used in the same guide as WoWPro:GuideLevels.

*   __WoWPro:GuideIcon(guide, icon_type, icon_reference)__\
	The icon to associate with the guide. With an icon_type of "ACH", the icon_reference is the achievment number (like the "Did ## quests in Tanaris").\
	With an icon_type of "PRO", the icon_reference is a profession number.\
	With an icon_type of "ICON", the icon_reference is an icon path.\
	For Achievement guides, setting the correct icon_reference is doubly important, as it also sets the guide name, class and subclass from the game functions.

*   __WoWPro:GuideClassSpecific(guide, class)__\
	Tells the system that this guide is restricted to a particular class. Used for the "DeathKnight" only starting zone.

*   __WoWPro:GuideRaceSpecific(guide, race)__\
	Tells the system that this guide is restricted to a particular race. Used for the "Goblin" or "Worgen" starting zones.

*   __WoWPro:GuideProximitySort(guide)__\
	Tells the system to sort the steps in order of proximity every time you complete a step.

*   __WoWPro:GuideNextGuide(guide,nextGID)__\
	Tells the system which guide to offer as the next guide. For a neutral guide you can use two GIDs separated by a "|" for each faction (Alliance first).

*   __WoWPro:GuideName(guide, name)__\
	If you want the guide name to be something other than the zone as defined in the guide registration parameters. This is the name that will be at the top of the guide pane and show in the list of guides.

*   __WoWPro:GuideNickname(guide, name)__\
	A nickname for the GuideID so you can call GuideNextGuide or calls to the guide in the code by a friendly readable name.

*   __WoWPro:GuideSort(guide, num)__\
	When mean_level is equal you can specify this override to declare the order guides are sorted in the guidelist menu.

*   __WoWPro:GuideSteps(guide, ...__\
	Register the function which returns the big "[[ ... ]]" quoted string of all the guide steps.

*   __Fancy things:__\
	But this is really LUA code we are running, so we can do fancy things here. Look at this!

    <pre class="bb-code-block">WoWPro:GuideIcon(guide,"Icon",
        WoWPro:GuidePickGender(
            "Interface\\Icons\\Achievement_Character_Dwarf_Male",
            "Interface\\Icons\\Achievement_Character_Dwarf_Female"))
    </pre>

    This picks an icon for the Dwarf starting zone depending on the gender!
*   __WoWPro:GuideQuestTriggers(guide, 33333,33334,33335)__\
	If you want a guide to autoload when a quest is accepted. Particulaly useful for holiday and other special occasion guides. The numbers are the QID's of the quests that you want to trigger the guide loading. The user will receive a dialog box giving them the options of Switch, Not Switch Now, or Not Switch Ever (for this quest).

*   __WoWPro:GuideAutoSwitch(guide)__\
	Use Auto Switch if you want a guide to autoload when any quest from the guide is accepted. You can put the |NA| tag in to make a particular quest not cause a guide to switch. (such as for a dungeon or raid quest that the user is not likely to be completing immediately). The user will receive a dialog box giving them the options of Switch, Not Switch Now, or Not Switch Ever (for this quest).

[[Back to top]](#top)

### <a name="code">The Guide Code</a>

Finally, to the meat of the guide. Each line of code represents one step in the guide. You can have blank lines if you like to help break up the big block of code, but make sure they are COMPLETELY blank. A single space on an otherwise blank line can cause the guide to not load!

For each line, You have several fields of import. The first is the step type, represented by a single case-sensitive character at the front of the line followed by a space. Step types tell the addon what icon to display, and can also tell the addon how to auto-complete the step.

Right after the step type, you'll see the step text. For quests, this will be the quest name. For location-based steps (run to, fly to, hearth to, etc) this will be the zone or sub-zone name. For other steps, it can vary.

After the step text come the tags, and this is where most of the "coding" comes into play. Some tags are required, some are not. These tags help the addon know how to handle the step, whether to display a note, where to map the coordinates, and more.

[[Back to top]](#top)

* * *

## <a name="color">Step Types</a>

* * *

### <a name="accept">A – Quest Accept</a>
Use this every time you direct the player to accept a step.

Example:

<pre class="bb-code-block">A Wanted: Dreadtalon |QID|12091|N|From the Wanted Poster just outside the door.|
</pre>

Auto-Completion:
* When a quest of the specified QID newly appears in the user's quest log.

[[Back to top]](#top)

### <a name="complete">C – Quest Complete</a>
Use this when the player is completing a quest (or part of a quest)
Example:

<pre class="bb-code-block">C Blood Oath of the Horde |QID|11983|N|Talk to the Taunka'le Refugees.|
</pre>

Auto-Completion:
* When the quest of the specified QID is marked (complete) in the user's quest log.
Icon Modifications (Crossed sword replacement):

*   Use a <a name="chat">|CHAT|</a> tag to give it a chat icon.
*   Use a |H| tag to mark a step as something that needs picked up, giving it a hand icon.
*   Use a |I| tag to mark a step as something that needs inspected or examined, giving it a spy glass icon.
*   Use a |NC| tag to mark the step as non-combat, giving it a cog icon.
*   Use a |QO| tag to make the step complete based on one (or more) specific quest objective(s) rather than all of them.
	+ You can also use|QO| to track each requirement of an objective count.
	+ For example:
		- if you have a quest the requires you to destroy 3 towers that are always in the same position you can you use |QO|1<1| for the first, |QO|1<2 | for the 2nd and |QO|1<3| for the last.  
If it shows you have 0/3 towers destroyed, you are saying, with |1<1| if Objective 1 is less than 1 (which is 0, and your progress is 0/3), likewise the final |1<3| you are saying if Objective 1 is less than 3 (your progress is 2/3 towers destroyed).
	+ You can also track the status of a % done progress bar. 
		- For example, |QO|1<42| will complete a step once it reaches 42%.
*   Use a |V| tag to mark the step as an "enter vehicle" with a green curved arrow icon.

[[Back to top]](#top)

### <a name="turnin">T – Quest Turn-in</a>

### <a name="supressturnin">t – Quest Turn-in (suppressible)</a>

Use this every time you direct the player to turn in a step. FYI Be aware, abandoning the quest will also cause T steps to autocomplete, if that happens you need to manually un-check.

Example:

<pre class="bb-code-block">T The Flesh-Bound Tome |QID|12057|N|Back at Agmar's Hammer.|
t Test Your Strength|QID|29433|M|48.06,67.05|N|To Kerri Hicks.|
</pre>

Auto-Completion:
*	When the quest of the specified QID disappears from the user's quest log or after viewing the completion page for the quest.

Skipping:
*	For a "T" step, if the completion criteria for the quest have not been met, the step will not be skipped. So use a C step if you need it done.
*	For a "t" step, if the completion criteria for the quest have not been met, the step will be skipped. When it is completed, the "t" will step magically reappear.

[[Back to top]](#top)

### <a name="run">R – Run ; F – Fly ; b – Boat/Zeppelin ; H – Hearth ; P - Portal</a>

These steps are all really variations on the same type – a location change.

Hearth steps will automatically provide a use button with the hearthstone on it.

Example:

<pre class="bb-code-block">H Warsong Hold |QID|11686|U|6948|
</pre>

Auto-Completion:
*	When the subzone or zone name matches the specified one.

Modifications:

*   Use a |CC| tag to make the step complete when the user reaches a coordinate, rather than a zone name.
*   Use a |CS| tag to make the step complete when the user passes through a series of coordinates, rather than based on the zone name.
*   also see [|TZ| alternate subzone name](#tzone)

[[Back to top]](#top)

### <a name="sethearth">h – Set Hearth</a>

Instructs the user to set their hearthstone. Make sure to spell the town’s name exactly correctly, or it won’t auto complete correctly.

Example:

<pre class="bb-code-block">h Warsong Hold |QID|11598|N|At the innkeeper.|
</pre>

Auto-Completion:
*	Auto-completes on the message “TOWNNAME is now your home.” TOWNNAME is the name of the subzone showing on your minimap when you are standing at this location, sometimes this is the name of the inn or something else more specific than the actual town name
*	A QID filter (ACTIVE/AVAILABLE/etc.) should be used with it to limit the scope of the step to that section of the guide.

[[Back to top]](#top)

### <a name="getfp">f – Get Flight Point</a>

Instructs the user to get the flightpath. While convention suggests you use the subzone name as the step text, it's not required.

Example:

<pre class="bb-code-block">f Moa'ki Harbor|QID|11585|Z|Dragonblight|
</pre>

Auto-Completion:
*	Auto-completes on the UI message "New flight point discovered". Does not require or use a subzone name.

[[Back to top]](#top)

### <a name="notetype">K – Kill ; U – Use ; B – Buy ; l - Loot ; L - Level ; N - Note</a>

None of these steps auto-complete on their own. They all behave exactly the same, and you should supply a tag to help them auto-complete if at all possible. Avoid the N type step as much as possible since it doesn't give the user any visual cue on what to do.

Use steps **must** include a |U| tag to tell it what the item being used is.

Example:

<pre class="bb-code-block">K Fjord Crows |QID|11227|L|33238 5|N|Until you have 5 Crow meat.|
</pre>

Auto-Completion:

*	IMPORTANT: This step has no auto-completion on it's own! You'll need to supply a tag to do that. Commonly used tags include |L| and |QO|. The above example uses a |L| tag. You can also effectively auto-complete with the use of an |ACTIVE| or |AVAILABLE| tag followed by a QID, note: -QID means when the quest is NOT active. For Note, Fly, or Run steps, using an ACTIVE tag instead of the QID will make sure that step is only active when that quest is active. Similarly, using an AVAILABLE when those steps lead you to an Accept step will complete them once the quest gets in your quest log. The only tricky thing is when an Run or Portal step is part of a quest and it involves a loading screen. Sometimes if you are lucky there is a QO tag that you may be able to use to auto-complete the step or using the zone name as the step name to complete on that basis.

[[Back to top]](#top)

### <a name="repair">r - Repair</a>

This step will auto-complete when the player opens the vendor window from a NPC that can repair.

Example:

<pre class="bb-code-block">
r Sell Junk|ACTIVE|179|M|30.06,71.52|N|Sell your junk to Adlin Pridedrift.|
</pre>

[[Back to top]](#top)

### <a name="commentstep">; - Comment Step</a>

Use this to put a comment into the guide. Since the guide lines are in a LUA bracket quote pair, you can not use a LUA double hyphen (--) to comment out a line.

Example:

<pre class="bb-code-block">; Begin Class specific training quests for Level 3
A Steady Shot|QID|14007|M|60.26,77.54|N|From Bamm Megabomb.|Z|Kezan|C|Hunter|
</pre>

When the parser encounters a comment step, it records the line, but does nothing with it. Empty lines or lines of just whitespace are discarded. Use of comments by guide writers is encouraged, particularly when you do something clever or complicated. A ; after a step also starts a comment, but is discarded by the parser. Hence, the first type of comment is visible when viewing the guide step in game if debug mode is enabled, but the second is not.

[[Back to top]](#top)

### <a name="treaurestep">$ - Treasure Step</a>

Use this to register a quest tagged treasure in the game. Many treasures in the game have a flag quest behind them that is completed upon looting the treasure.

Example:

<pre class="bb-code-block">$ Gurun|QID|34839|M|47.00,55.20|Z|Frostfire Ridge|ITEM|111955|N|And [money=120.00]|
</pre>

A QID is required for this type of step. The primary item should be indicated in the ITEM tag. Any secondary rewards should be in the note.

[[Back to top]](#top)

### <a name="trash">* - Trash Step</a>

Use this to delete an item in your inventory. It requires a U tag. If the item is in your inventory, you will be prompted to get rid of the item. The step will auto complete if you delete the item or cancel the delete or if you never had the item in the first place.

Example:

<pre class="bb-code-block">* Bauble Dump|QID|6608|U|6529|N|If you got a Bauble, trash it.|
</pre>

[[Back to top]](#top)

* * *

## <a name="Tags">Tags</a>

* * *

### <a name="qid">|QID|####| – Quest ID</a>

QID, ACTIVE or AVAILABLE tag is REQUIRED for every step.

Even on a step that has nothing to do with any quest (e.g. Hearth steps) it is still important to have one of these 3 tags there as well. Use the ID of a quest which, if completed, means the user no longer needs to complete that step. You can have more than one QID here, separated by either _&_ for AND, or _^_ for OR.

Example:

<pre class="bb-code-block">A Wanted: Dreadtalon |QID|12091|N|From the Wanted Poster just outside the door.|
</pre>

Auto-Completion:
*	Regardless of what other tags the step has, if the addon detects that the QID quest has been turned in, this step will complete.

[[Back to top]](#top)

### <a name="active">|ACTIVE|####| – Active Quest ID</a>

This tag will skip the step if the given quest is not active. I.e. you need to be on this quest, but not have completed it. This ID can be prepended with "-" sign to mean not active. You can have more than one QID here, separated by either _&_ for AND, or _^_ for OR.

Example:

<pre class="bb-code-block">A The Grand Melee|QID|13761|ACTIVE|13717|M|76.40,19.00|N|From Airae Starseeker.|
</pre>

[[Back to top]](#top)

### <a name="available">|AVAILABLE|####| – Available Quest ID</a>

This tag will skip the step if the given quest is not available. I.e. you need to not be on the quest or have completed it. You can have more than one QID here, separated by either _&_ for AND, or _^_ for OR.

Example:

<pre class="bb-code-block">R Go here for Grand Melee|AVAILABLE|13717|M|76.40,18.00;76.40,19.00|N|Take this path|
</pre>

[[Back to top]](#top)

### <a name="questgossip">|QG|Some text| – Quest Gossip</a>

This is used for quests where the NPC will ask you a question and then you need to supply an answer. In the Timeless Isle, for example, Senior Historian Evelyna has a trivia quiz. Here is am excerpt from the quiz

Example:

<pre class="bb-code-block">A A Timeless Question|QID|33211|M|65,50.6|N|From Senior Historian Evelyna, daily.|
; This first C step "catches" until you GOSSIP with Evelyna and then goes away when it does not match the gossip
C A Timeless Question|QID|33211|QG|Senior Historian Evelyna|N|Chat with Evelyna to get your question.  The question will change each time you chat with her, but we have a cheat sheet.|
C A Timeless Question|QID|33211|QG|assault on Icecrown|N|Mord'rethar|
C A Timeless Question|QID|33211|QG|bloodied crown|N|King Terenas Menethil II|
C A Timeless Question|QID|33211|QG|Broken|N|Nobundo|
...
T A Timeless Question|QID|33211|M|65,50.6|N|To Senior Historian Evelyna.|
</pre>

When you are interacting with an NPC between the GOSSIP_OPEN/_CLOSED states, the addon samples the text and matches it against the text in the QG tag. The match is case insensitive. If it matches, the step is not skipped, if it does not match, the step is skipped. If we are not interacting with an NPC between the GOSSIP_OPEN/_CLOSED states, then the tag has no effect.

Auto-Completion:

[[Back to top]](#top)

### <a name="questobjective">|QO|#| – Quest Objective</a>

This is used for quests where you won’t be completing all objectives at the same time or when the objective locations are very specific and static.

Please note that the addon is smart enough to know that when you use a QO tag, you want it to behave like a QO step, NOT a C step – so you can still use the C step type to get the nice icon for users to see. The quest tracker will only track the correct quest objective, and the step will auto-complete when that objective is complete. Remember also that you can change the step text to be something other than the quest name and it won't hurt anything!

You can also list multiple quest objectives in one step, and the step will complete when all of them are complete. Just separate them with a semicolon ";".

You must use a number instead of text. The number is the ordinal of the quest of objective. The addon will use the localized text to display the goal so people playing on non-English game clients will have a better idea of what to do. (Older guides for older content may use text instead of the ordinal number, but as Blizzard has changed how they display quest objectives, this usage should be discontinued.)

Example:

<pre class="bb-code-block">C Watchtower Burned|QID|11285|QO|2|U|33472|N|Use torch on Winterskorn Watchtower.|
C Bridge Burned|QID|11285|QO|3|U|33472|N|Use torch on Winterskorn Bridge.|
C Dwelling Burned |QID|11285|QO|1|U|33472|N|Use torch on Winterskorn Dwelling.|
C Barracks Burned |QID|11285|QO|4|U|33472|N|Use torch on Winterskorn Barracks.|
</pre>

You can also use|QO| to track each requirement of an objective count. For example if you have a quest the requires you to destroy 3 towers that are always in the same position you can you use |QO|1<1| for the first, |QO|1<2 | for the 2nd and |QO|1<3| for the last. If it shows you have 0/3 towers detstroyed you are saying, with |1<1| if Objective 1 is less than 1 (which is 0, and your progress is 0/3), likewise the final |1<3| you are saying if Objective 1 is less than 3 (your progress is 2/3 towers destroyed).

Example:

<pre class="bb-code-block">C Bursting the Bubble|QID|62225|M|60.85,63.39|Z|Icecrown|QO|1<1|N|Pick up a plague barrel and toss it in the cauldron.|
C Bursting the Bubble|QID|62225|M|61.55,63.96|Z|Icecrown|QO|1<2|N|Pick up a plague barrel and toss it in the cauldron.|
C Bursting the Bubble|QID|62225|M|62.25,63.37|Z|Icecrown|QO|1<3|N|Pick up a plague barrel and toss it in the cauldron.|
</pre>

You can also track the status of a % done progress bar, for example:

<pre class="bb-code-block">
C Tat Big Meanie|QID|84144|QO|2=25|M|62.1,51.7|Z|71; Tanaris|N|Redhair|EAB|
C Tat Big Meanie|QID|84144|QO|2=50|M|62.0,51.5|Z|71; Tanaris|N|Historic Tales|EAB|
C Tat Big Meanie|QID|84144|QO|2=75|M|64.0,51.7|Z|71; Tanaris|N|Ratts|EAB|
C Tat Big Meanie|QID|84144|QO|2=100|M|63.6,47.9|Z|71; Tanaris|N|Strange Torch|EAB|
</pre>

Auto-Completion:
*	Auto-completes when the addon detects the the QO # or the exact QO text in the QID quest's leaderboard in the user's quest log. Spelling and capitalization is very crucial here! (As mentioned above, quest text only works with older content)
[[Back to top]](#top)

### <a name="optional">|O| – Optional</a>

This tag makes the step optional and will only show if the player has the quest in their quest log.

Use this on an Accept step with a [[|U| tag]](#use) and it will only show if the player has the item in their bags, useful for quests that come from items.

Use this on a Use step with a [[|U| tag]](#use) and it will **only** show if you have _looted enough items_ as indicated by the [[|L|xxxx #| tag]](#loot) that you need to include.

You can also use the [[|PRE| tag]](#pre) with it to only display the objective if the quest with the QID listed in the |PRE| tag has been completed.

[[Back to top]](#top)

### <a name="pre">|PRE|####| – Prerequisite</a>

This is used in quest skipping logic, so please use it for every quest that has a prerequisite, optional or not! You only need to use this on Accept steps, the guide will extrapolate from there.

You don’t need to include previous steps in the chain with this tag, just the most recent. However, you CAN include multiple prerequisites by using either _&_ for AND, or _^_ for OR. between each the quest IDs. Use one or the other, don't mix. An ampersand indicates that all of the quests have to be completed for this step to activate. A caret indicates that any of the quests can be completed for this step to activate.

[[Back to top]](#top)

### <a name="loot">|L|####| – Loot</a>

Used when you need to make sure the player has a specific item or amount of an item in their bags. Add the quantity after the item number with a space in between. If you only need one of an item, you do not need to specify a quantity.

Multiple items can be listed as long as you use a "**;**" to separate them. The quantity can be added as you would normally.

Using this on a C step will change the step icon to the loot icon and will auto-complete the step when the amount of specific item is in their bags. 

Note that in some cases when you loot an item, it may not appear in your bags.
If so, you need to use the a [[QO tag]](#questobjective) instead.

[[Back to top]](#top)

### <a name="use">|U|####| – Use</a>

This will create a button for the item specified so you don’t have to dig through your bags to find it.

[[Hearth steps]](#run) will automatically provide a use button for the hearthstone and do not need the tag.

[[Back to top]](#top)

### <a name="classrace">|C|Priest,Mage,…| – Class |R|Orc,Troll,…| – Race</a>

These will only show the step if you are playing the specified class/race. Use commas to separate entries to list more than one race or class.

[[Back to top]](#top)

### <a name="note">|N|…| – Note</a>

A general note for the step to add additional information. Please try to limit these to one or two sentences.

[[Back to top]](#top)

### <a name="coord">|M|55.55,55.55| – Mapping</a>

List coordinates here. You can list multiple coordinates by separating them with semicolons ";". Make sure you list coordinates for every step! The addon CAN get coordinates from the in-game quest blobs, but we'd rather have our own coordinates listed.

If you have more than one coordinate, you need to specify one of the |CS|CC|CN| tags.

[[Back to top]](#top)

### <a name="zone">|Z|Zone Name| – Zone</a>

Use this tag if the step goes outside the zone for the guide. IMPORTANT – if you don’t use this tag and the coordinates are not in the guide’s title zone, they will show up WRONG.

_/wp where_ - tells you where you are according to the addon.

also see [|TZ| alternate subzone name](#tzone)

[[Back to top]](#top)

### <a name="sticky">|S| – Sticky |US| – Un-Sticky</a>

These are for do-as-you-go steps. Use |S| on the do as you go message. Use |US| on a step with the same name when you want to have the user actually complete the step.

Example:

<pre class="bb-code-block">C Galgar's Cactus|QID|4402|N|Loot Cactus Apples from Cacti|S|
C Vile Familiars|QID|792|N|Kill the Vile Familiars in the north.|M|44.7,57.7|
C Galgar's Cactus|QID|4402|N|Loot Cactus Apples from Cacti|US|M|44.7,57.7|
</pre>

In this example, the user is instructed to pick up cactus apples while killing vile familiars. Once they kill all the familiars they need, the stickied cactus apple step becomes a normal step.

Auto-Completion:
*	|S| tagged steps auto-complete when the corresponding |US| type step becomes active, so only one will be active at a time.

[[Back to top]](#top)

### <a name="nounsticky">|S!US| - Sticky without corresponding unsticky</a>

Use this tag when you want something to stay sticky indefinitely until completed, such as find a group for the Elite kills or collecting the tortollan scrolls that will take several hours to find.

Auto-Completion:
* |S!US| tagged steps auto-complete when the corresponding quest (or quest objective) is completed.

[[Back to top]](#top)

### <a name="item">|ITEM|######| – Item - followed by item number</a>

Use this tag to show an item related to the step. The icon (which can be moused over for details) and the item name will be prepended to the note text. (i.e. placed in front of the text that follows the |N|) Usually this would be the drop from the rare mob or treasure. This is a link, not a clickable "use" item. (for Use items use the |U| tag)

When using this tag, a corresponding [L tag](#loot) **MUST** be used.

When used on a C step with an L tag, it will prepend the note text with 'Kill and loot ' followed by the rest of the note. Using one of the 'icon' tags (CHAT, NC, etc) will negate this behavior.

When using this tag, a corresponding L tag MUST be used.
 
[[Back to top]](#top)

### <a name="inzone">|IZ|Zone| – IZ - followed by zone name</a>

Use this tag as a suppression tool when you want to show/hide a step based on their current location. It works with both zone and subzone names.
For example, this tag can be used with floating stickies ([S!US](#nounsticky)) or C steps where the mobs are only found in a particular Zone or Sub-zone.

If you wish to have more than one location, use '^' to separate them. Adding a '-' will flip the logic and only show as long as they are **not** there. 

Keep in mind when using multiple locations, if any of one them are true, the step will show.
In this example, _|IZ|Boulderslide Cavern^Boulderslide Ravine|_, if either one of them are true, the step will be shown.

[[Back to top]](#top)

### <a name="faction">|FACTION| – faction</a>

Use this tag in Neutral guides when you want to restrict a step to a specific faction. |FACTION|Horde] will only show that Step to Horde Players and |FACTION|Alliance] will only show for Alliance players.

[[Back to top]](#top)

### <a name="level">|LVL| – Level</a>

Use this tag to denote a step that requires a particular level. There is also a step type, L, to denote a step that completes once the user levels up.

Auto-Completion:
*	For L steps, completes when the user reaches the specified level.
Step-Enabling:
*	For non-L steps, enable the step if the user is at least the specified level.
Alternate usage - Step - hiding:
* prepend the level with a minus "-" sign to cause the step to not display if the user is over the specified level. (|LVL|-109|)

[[Back to top]](#top)

### <a name="lead">|LEAD| – Lead In Quest</a>

Use for lead in or breadcrumb type quests, followed by the QID for the quest it leads to. This step will be checked off if the user has already completed the quest it leads up to or has the quest it leads up to active in their log.

Auto-Completion:

*	Completes when the user completes the specified QID quest (sort of like a second QID).

[[Back to top]](#top)

### <a name="target">|T| – Target</a>

Follow by the name of the mob or NPC you want the user to be able to target.
You can get Fancy and do an emote after the target as shown here.

<pre class="bb-code-block">C A Blade Fit For A Champion|QID|13673|M|60.4,52.0|Z|Grizzly Hills|T|Lake Frog,kiss|U|44986|L|44981|N|Kiss frogs till you get a princess.  Then ask for the blade.|
</pre>

[[Back to top]](#top)

### <a name="profession">|P| – Profession</a>

Two arguments are required: the name of the profession and its "number". There are three optional arguments that follow:

*	|P|Alchemy;171;0|
	+ The required form, with the name, profession number and expansion. If the toon has at least 1 in Alchemy, the step will activate.

*	|P|Blacksmithing;164;0+42|
	+ This adds the profession level, which now has a modifier for expansion (required-see below for table of values) and defaults the level to 1 for that expansion. A "*" can be used to mean max level for the expansion. If the toon has at least 42 (>=) in Blacksmithing, this step will activate.

*	|P|Enchanting;333;0+42;true|
	+ This sets the profession flip flag. A true/non-zero value flips the sense of the profession level test. I.e. the toon would need less than 42 in Enchanting for this step to activate.

*	|P|Engineering;202;0+*;false;150|
	+ This sets the profession max skill level. This defaults to 0. It will active the step if the current max profession level the toon could get without re-training is less than the argument. So this would require the toon to have Engineering(200).

The allowed values for the profession names and numbers are:

*	Alchemy;171
*	Blacksmithing;164
*	Enchanting;333
*	Engineering;202
*	Herbalism;182
*	Inscription;773
*	Jewelcrafting;755
*	Leatherworking;165
*	Mining;186
*	Skinning;393
*	Tailoring;197
*	Archaeology;794
*	Cooking;185
*	First Aid;129
*	Fishing;356

The allowed values for the Expansion variable are

*	0 Classic - Max 300
*	1 BC - Max 75
*	2 WotLK - Max 75
*	3 Cata - Max 75
*	4 MoP - Max 75
*	5 WoD - Max 100
*	6 Legion - Max 100
*	7 BFA - Max 175
*	8 SL - Max 175
*	9 DF - Max 100

In addition, if the step is an "A" step and you do not have the profession, the step and QID are marked as skipped.
If this is an "M" step, any racial modifiers will be subtracted from the profession level and the max skill level.

[[Back to top]](#top)

### <a name="waycomplete">|CC| – Coordinate Auto-complete |CS| – Coordinate Auto-complete in Sequence |CN| – No Coordinate Auto-complete</a>

Use either CC or CS in order to auto-complete an r/R/N step when the coordinate (or set of coordinates), given in the |M| tag, is reached. If you are using a set of coordinates, the |CS| tag will make the step auto-complete only when the player follows the coordinates in sequence, from the first to last (final) coordinate, and the |CC| tag will make it auto-complete when the player reaches the final coordinate, regardless of the previous ones.

The |CN| tag is used to indicate that a set of coordinates are just markers on the map and NO auto-complete should be done.

If a set of coordinates is used in the |M| tag, one of these three tags is required or an error message will be issued.

Auto-Completion of r/R/N steps:
*	Completes when the user reaches the specified coordinate or series of coordinates.

Other step types will present the waypoints, but will not auto-complete when the last one is reached. Some other completion method must be used.

[[Back to top]](#top)

### <a name="rank">|RANK| – Rank</a>
This tag should be used as much as possible from now on, and denotes how important a quest is. 1 is the most important and will NEVER be skipped. 3 is the least important. Vital quest chains with great XP and item rewards should be marked 1. Things that are neutral in rewards but which are convenient to do should be a 2. Things that take you out of your way and aren’t particularly rewarding should be marked a 3. Anything unmarked will be considered a 1. In general, a character with heirlooms and RAF should be able to get through the guide on a setting of 1, while a character with none of these bonuses and who doesn’t do instances or have rested would need a setting of 2. 3 is more for completionists trying to get as many quests done as possible.

The only other note to this: If you use a rank tag, you must make sure all quests following that one in a chain must have the same rank or higher. We don’t want the user to be instructed to pick up a quest that he or she has not done the prerequisites for.

More specific descriptions:

|RANK|1|
*	You don’t need to use it, it’s implied if no rank is listed. Never skipped no matter what setting. Use for quest chains that lead to the “final” quest in the zone. I’m not sure how the high level zones go, but for the mid level ones there is usually one quest that yields very high quality rewards and “finishes” the story for that zone. All quests leading up to and including this kind of a quest should be rank 1.

|RANK|2|
*	These steps are only skipped by people on the lowest completion setting. Use this for quest chains that don’t lead to the “final” quest – though NOT if there are a ton of quest chains like this. I would say as a general guideline, between 1/4 and 1/3 quests should have this tag.

|RANK|3|
*	Really out of the way or annoying quests with little return. I haven’t been using it too often. Something the typical user would NOT want to do, something only completionists would want to do.

|RANK|-1|
*	Denotes a step you only want to show when a guide is being run on RANK 1. Typical usage is for R steps when you skip content that rank 2 or 3 walks you through.

[[Back to top]](#top)

### <a name="noncombat">|NC| – Non-Combat; |H| - Hand:  |I| Inspect</a>
Used with the C step, |H| changes the step icon to a hand
Used with the C step, |I| changes the step icon to a spyglass
Used with the C step, |NC| changes the step icon to a cog
All of these are to give a visual clue that the user needs to click on something (rather than kill something) to complete it.  We try to match the icon used by blizzard when doing the action, with |NC| (cog) being the default.

[[Back to top]](#top)

### <a name="notauto">|NA| – Not Automatic</a>

If a guide is marked as an auto-switching guide using WoWPro:GuideAutoSwitch(guide), this tag is used to make this particular quest as not triggering an auto-switch. This is used for things like dungeon quests or other quests that are going to hang around in your quest log for a long time and could result in many irritating offers to switch guides.

[[Back to top]](#top)

### <a name="chat">|CHAT| – Chat</a>

Used with the C step, this changes the icon to the Gossip icon, so you know you need to talk to someone.

[[Back to top]](#top)

### <a name="vehicle">|V| – Use vehicle</a>

Used with the C step, this changes the icon to the Mount Vehicle icon, so you know you need to click on the unit to mount a vehicle

[[Back to top]](#top)

### <a name="reputation">|REP| – Reputation</a>

Takes a set of two required arguments and up to two optional ones. Lets take an example:

|REP|Operation: Shieldwall;1376|

* This is the minimally acceptable form. The first argument is the name of the faction and the second is the faction number. You can get faction numbers off of [WowHead](http://www.wowhead.com/faction=1376). Yeah, the number is all you really need, but then the guide would be unreadable. Besides, Blizzard has changed the names of factions in past patches, but preserved the faction numbers, so we feel safer in using the numbers. The third argument defaults to neutral-exalted and the fourth to 0. Explanations for them follow. This form enables the step if the reputation with "Operation: Shieldwall" is neutral through exalted.

|REP|Operation: Shieldwall;1376;friendly|

*	The third argument is a reputation or friendship range.
	+	Reputations are: hated, hostile, unfriendly, neutral, friendly, honored, revered, exalted
	+	Friendships are: stranger, acquaintance, buddy, friend, good friend, best friend

*	Reputations are used with factions, like the [Scryers](http://www.wowhead.com/faction=934) or [Tillers](http://www.wowhead.com/faction=1272). Friendships were introduced in 5.1 for your status with individual NPC's like [Gina Mudclaw](http://www.wowhead.com/faction=1281).
*	A reputation range is separated by a '-' like neutral-exalted. If only one element is present, like the example, it is doubled up and interpreted as friendly-friendly and means that the step is enabled only when friendly with the faction. Do not mix reputation keywords and friendship keywords or evil things will result.

A reputation range is separated by a '-' like neutral-exalted. If only one element is present, like the example, it is doubled up and interpreted as friendly-friendly and means that the step is enabled only when friendly with the faction. Do not mix reputation keywords and friendship keywords or evil things will result.

|REP|Operation: Shieldwall;1376;friendly;950|

*	The last argument is either the reputation level or the reputation bonus detector. In the example, it specifies that you need to be friendly and at least 950 points into friendly. It will not activate for any higher levels of reputation. You use this for quests that appear at specific reputation levels instead of reputation boundries. We may in the future choose to obey the upper reputation limit as well.

|REP|Operation: Shieldwall;1376;revered;nobonus|

*	The last argument is the reputation bonus detector. In the example, it specifies that you need to be revered and not have purchased and used the "Grand Commendation of Operation: Shieldwall". This can be used in guides to prompt the user to buy the commendation at the right rep level. The last argument could also be "bonus" to detect that you have the bonus, but we did that for completeness rather than utility.

[[Back to top]](#top)

### <a name="dfren">|DFREN| - Dragonflight Renown

This is used to limit a step from being active based on the character's renown level with the major dragonflight factions.

|DFREN|text name;id #;##|
the ID #s are
*	Dragonscale;2507 -- predominately found in Waking Shore
*	Maruuk;2503 -- predominately found in Ohn'ahran Plains
*	Tuskarr;2511 -- predominately found in Azure Span
*	Voldrakken;2510 -- predominately found in in Thaldraszus

The last parameter is level of renown required, with + number being ">=" and negative number to be "<".

DFREN|maruuk;2503;-14| shows if you your maruuk is under renown 14

DFREN|maruuk;2503;14| shows if you your maruuk is at or over 14

[[Back to top]](#top)

### <a name="achievement">|ACH| – Achievement</a>

Takes a set of one required arguments and two optional ones. Lets take a few examples:

|ACH|6031|
*	This is the minimally acceptable form. The first argument is the number of the achievement, [6031](http://www.wowhead.com/achievement=6031), which you can look up in wowhead. In this form, the step completes if the whole achievement is complete.

|ACH|6031;2|

*	This is the second form. The first argument is the number of the achievement, [6031](http://www.wowhead.com/achievement=6031), which you can look up in wowhead. The second, specifies the step in the achievement, in this case "firing off the fireworks in Orgrimmar". In this form, the step completes if the portion of the achievement is complete.

|ACH|6031;2;true|

*	This is the third form. The first argument is the number of the achievement, [6031](http://www.wowhead.com/achievement=6031), which you can look up in wowhead. The second, specifies the step in the achievement, in this case "firing off the fireworks in Orgrimmar". The third augment is the "flip" argument. In this form, the step completes if the portion of the achievement is not complete.

|ACH|6031;;true|

*	This is the fourth form. The first argument is the number of the achievement, [6031](http://www.wowhead.com/achievement=6031), which you can look up in wowhead. The second is set to nil, so it is equivalent to the first case. The third augment is the "flip" argument. In this form, the step completes if the whole achievement is not complete.

|ACH|6031;;;true|

*	This is the fifth form. The first argument is the number of the achievement, [6031](http://www.wowhead.com/achievement=6031), which you can look up in wowhead. The second is the step in the achievement, which can be nil if you want to refer to the entire achievment. The third augment is the "flip" argument. In this form, the step completes if the whole achievement is not complete. The forth argument is only applicable when you want to test for account wide achievements that won't necessarily have been completed on that particular toon.

[[Back to top]](#top)

### <a name="buff">|BUFF| – Unit Buff</a>

[Sayge's Dark Fortune of Strength](http://www.wowhead.com/spell=23735)

Buffs, those things that appear at the top, like Sayge's Dark Fortune of Strength, can be detected by this tag and cause the step to complete. Multiple buffs can be specified with the usual '^' or '&' delimited list. Example:

<pre class="bb-code-block">N Sayge's Dark Fortunes|M|52.94,75.94|BUFF|23735^23736^23737^23738^23766^23767^23768^23769|N|Sayge offers different 2 hour buffs.  Pick one and elect to get a written fortune for a chance at a quest item! We pre-select based on your class.|
</pre>

IMPORTANT: Starting with 12.0.0 this tag will not be able to complete steps when inside an instance!

[[Back to top]](#top)

### <a name="pet">|PET| – Pet Detect</a>

The PET tag takes one, two or three arguments, depending on what you are up to. The second and third arguments default to 3;false if not specified.

|PET|6031|
*	In the one argument form, this tests to see if less than 3 of the indicated pet. The creature IDs are not well documented. As far as I know, the only place to get them are in the Blizzard web API or by using the WoW-Pro debug log, which lists the IDs for all the pets you have.

|PET|6031;1|
*	In the two argument form, this tests to see if less than 1 of the indicated pet.

|PET|6031;1;true|
*	In the three argument form, this tests to see if you have >= 1 of the indicated pet. A true value flips the sense of the test.

### <a name="PET1_PET2_PET3__Pet_Selection">|PET1| |PET2| |PET3| – Pet Selection</a>

The PET1, PET2 and PET3 tags takes up to four perimeters to select a pet that meets the given criteria.

|PET1|Anubisath Idol;68659;|
*	This will select the given pet, where the ID number corresponds to the NPC number.

|PET1|Anubisath Idol;68659;1+2+1|
*	The third argument indicates what abilities to put into which slots, 1 means select the first ability in that slot, 2 the second. 1+2+1 means select the first, second and first abilities in the first, second and third columns.

|PET1|Leveling;;;|
*	This will select a pet for levelling

|PET1|Leveling;;;H>200C|
*	This will select a pet for levelling that meets the selected attributes, in this case select a pet with more than 200 health with Critter attributes.

The allowed values for the attributes are:

*   Health
*   Power
*   Speed
*   Family

The first letter of each pet type is the modifier

*   1 - Humanoid
*   2 - Dragonkin
*   3 - Flying
*   4 - Undead
*   5 - Critter
*   6 - Magic
*   7 - Elemental
*   8 - Beast
*   9 - Aquatic
*   10 - Mechanical

[[Back to top]](#top)

### <a name="building">|BUILDING| – Building Detect</a>
The BUILDING tag takes two or more arguments, depending on what you are up to. The first argument is ignored and is used for documentation and second and following arguments are building numbers. You can find a list of building numbers for WoD at [http://wod.wowhead.com/buildings](http://wod.wowhead.com/buildings) . If you have none of the buildings specified, then the step is skipped. As a special bonus, if the step does not have a |M| tag, one for the building location will be added. The addon uses the building locations on your Garrison map, so it won't be perfect, but it is pretty good.

|BUILDING|Lumberyard;40|
*	In the two argument form, this tests to see if you have the indicated building. In this case, a level 1 Lumberyard.

|BUILDING|Lumberyards;40;41|
*	In the three argument form, this tests to see if you have either a level 1 or level 2 lumberyard.

|BUILDING|TownHall;2|
*	In this form, it tests your Town Hall level. In this case, it checks that the Town Hall (Garrison) level is exactly 2. Only one level can be tested for. Note that this form does NOT set the |M| tag.

|BUILDING|TownHallOnly|
*	In this form, this tests to see if you have built no buildings. No other arguments are paid attention to!

[[Back to top]](#top)

### <a name="recipe">|RECIPE| – Recipe Detect</a>

The RECIPE tag is used with tradeskills to detect if you have a recipe in your profession "book".

Usage:
B Recipe: Koi-Scented Stormray|M|71.61,48.87|P|Cooking;185|RECIPE|201503|L|133819|N|From Markus Hjolbruk.|

This detects if you have the recipe (Koi Scented Stormray Spell ID: 201503) and if not to buy it. You should include the profession tag with skill level required. The number in the |L| tag is the item id of the recipe (133819) you buy and then click to learn it.

[[Back to top]](#top)

### <a name="fly">|FLY|XXX|</a>

This tag allows a step to not be enabled (displayed) if the character can fly in the referenced content. This is useful for when run steps involve complicated maneuvers that can be avoided by flying above the obstruction.

*	Available parameters are based on the expansion name
	+   BFA - Zandalar and Kul Tiras
	+   LEGION - Broken Isles
	+   WOD - Draenor
	+   OLD - Everything that did not require a "Pathfinder" achievement
	+   BC - Classic TBC flying
	+   WOTLK - Classic Cold Weather Flying

[[Back to top]](#top)

### <a name="TAXI">|TAXI|flightpath name| - flight path detection </a>

a step with |TAXI|flightpath name| will only show if you have the flightpath specified. When you open the flightpath UI at a flightmaster, and hover over the flightpaths, the names have to match there.

A negative sign before the name i.e. |TAXI|-flightpath name| will negate the step if you don't have the flightpath.

This is implicit in f/F steps, and would primarily be used in R steps to give directions on how to get to a flightpath for someone who didn't have it, 

[[Back to top]](#top)
### <a name="tzone">|TZ|Subzone Name| – minimap subzone</a>

Use this tag if the name for completion of a R, b, H, F step is for some reason other than what the step text is. Especially useful for you want a step to complete if they fly to a spot where the name at the flight master is NOT the same name as the minimap when they arrive, so you can have completion whether they fly from a flight path or travel there some other way.

also see [R Run, etc](#run)

[[Back to top]](#top)
### <a name="spell">|SPELL|Spell NickName;Spell ID#; Flip| – detects spells in character's spellbook</a>
Use this tag to detect if a character has learned a spell or skill.

*   Spell NickName: The name of the spell, for humans. Not used by the addon. (required)
*   Spell ID#: the Spell ID, as available on Wowhead. (required)
*   Flip: An optional boolean to flip the detection. Defaults to false (do not flip).

Auto-completes if the spell is already known or if is learned.
Warning: not all spells are detectable by this method. Blizzard is not consistent!
This tests for Spells you can put on a button, essentially.

[[Back to top]](#top)
### <a name="nocache">|NOCACHE| - detects if a step is completed by QID vs checked off</a>
The NOCACHE tag is used for guides to not assume a quest is compete when reloaded.   I need to add code use the right check for A and T steps to use NOCACHE to control the query for quest completion and not to record as completed unless the API says it is completed.

[[Back to top]](#top)
### <a name="mid">|MID| - detects if mission has been started at the user's mission table</a>
The MID tag is used to detect if a Mission has been started, so the step can complete before the mission completes. 

[[Back to top]](#top)