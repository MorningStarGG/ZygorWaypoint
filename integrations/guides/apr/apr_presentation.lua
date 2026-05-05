local NS = _G.AzerothWaypointNS
if not NS.IsAPRLoaded() then return end

NS.Internal = NS.Internal or {}
NS.Internal.APRPresentation = NS.Internal.APRPresentation or {}

local M = NS.Internal.APRPresentation

local DEFAULT_ACTION_ORDER = {
    "ExitTutorial", "PickUp", "DropQuest", "Qpart", "QpartPart", "Treasure", "Group", "Done",
    "Scenario", "EnterInstance", "LeaveInstance", "EnterScenario", "DoScenario", "LeaveScenario",
    "SetHS", "UseHS", "UseDalaHS", "UseGarrisonHS", "UseItem", "UseSpell", "GetFP", "UseFlightPath",
    "TakePortal", "LearnProfession", "LootItems", "WarMode", "Grind", "Achievement", "RouteCompleted",
    "Waypoint", "DroppableQuest", "GossipOptionIDs", "Note",
}

local ACTION_ORDER_EXTRAS = {
    "SetHS", "Waypoint", "DroppableQuest", "GossipOptionIDs", "Button", "SpellButton",
}

local function TrimText(value)
    if type(value) ~= "string" then
        return nil
    end
    value = value:gsub("%s+", " "):gsub("^%s+", ""):gsub("%s+$", "")
    if value == "" then
        return nil
    end
    return value
end

local function NormalizeID(value)
    local id = tonumber(value)
    if id and id > 0 then
        return id
    end
end

local function NormalizeGenericTitle(value)
    value = TrimText(value)
    if not value then
        return nil
    end
    value = value:gsub("%%s", ""):gsub("%s*:%s*$", "")
    return TrimText(value)
end

local function SafeCall(fn, ...)
    if type(fn) ~= "function" then
        return nil
    end
    local ok, result = pcall(fn, ...)
    if ok then
        return result
    end
end

local function AddUnique(list, seen, value)
    local id = NormalizeID(value)
    if id and not seen[id] then
        seen[id] = true
        list[#list + 1] = id
    end
    return id
end

local function GetStepString(APR, step)
    if type(APR) ~= "table" or type(APR.GetStepString) ~= "function" then
        return nil, nil
    end
    local ok, text, key = pcall(APR.GetStepString, APR, step)
    if ok then
        return TrimText(text), key
    end
end

local function BuildActionOrder(APR)
    local order = {}
    local seen = {}

    local function add(key)
        if type(key) == "string" and key ~= "Note" and not seen[key] then
            seen[key] = true
            order[#order + 1] = key
        end
    end

    local main = type(APR) == "table" and type(APR.mainStepOptions) == "table" and APR.mainStepOptions or DEFAULT_ACTION_ORDER
    for index = 1, #main do
        add(main[index])
    end

    local secondary = type(APR) == "table" and type(APR.secondaryStepOptions) == "table" and APR.secondaryStepOptions or nil
    if type(secondary) == "table" then
        for index = 1, #secondary do
            add(secondary[index])
        end
    end

    for index = 1, #ACTION_ORDER_EXTRAS do
        add(ACTION_ORDER_EXTRAS[index])
    end

    if not seen.Note then
        order[#order + 1] = "Note"
    end
    return order
end

local function DetectStepKey(APR, step, fallbackKey)
    if type(step) ~= "table" then
        return fallbackKey
    end
    local order = BuildActionOrder(APR)
    for index = 1, #order do
        local key = order[index]
        if step[key] ~= nil then
            if key ~= "Note" then
                return key
            end
        end
    end
    if step.Note ~= nil then
        return "Note"
    end
    return fallbackKey
end

local function GetArrayQuestIDs(value)
    local ids = {}
    local seen = {}
    if type(value) == "table" then
        for index = 1, #value do
            AddUnique(ids, seen, value[index])
        end
    else
        AddUnique(ids, seen, value)
    end
    return ids
end

local function GetMapQuestIDs(value)
    local ids = {}
    local seen = {}
    if type(value) == "table" then
        for key in pairs(value) do
            AddUnique(ids, seen, key)
        end
    end
    table.sort(ids)
    return ids
end

local function GetNestedQuestID(value)
    if type(value) == "table" then
        return NormalizeID(value.questID or value.Qid)
    end
    return NormalizeID(value)
end

local function IsQuestCompleted(questID)
    questID = NormalizeID(questID)
    if not questID or type(C_QuestLog) ~= "table" or type(C_QuestLog.IsQuestFlaggedCompleted) ~= "function" then
        return false
    end
    local ok, completed = pcall(C_QuestLog.IsQuestFlaggedCompleted, questID)
    return ok and completed == true
end

local function IsQuestActive(APR, questID)
    questID = NormalizeID(questID)
    if not questID then
        return false
    end
    if type(APR) == "table" and type(APR.ActiveQuests) == "table" and APR.ActiveQuests[questID] ~= nil then
        return true
    end
    if type(C_QuestLog) == "table" and type(C_QuestLog.IsOnQuest) == "function" then
        local ok, active = pcall(C_QuestLog.IsOnQuest, questID)
        if ok then
            return active == true
        end
    end
    return false
end

local function ResolveQuestTitle(questID)
    if type(NS.ResolveQuestTitle) ~= "function" then
        return nil
    end
    return NS.ResolveQuestTitle(questID)
end

local function QuotedQuestTitle(action, questTitle)
    questTitle = TrimText(questTitle)
    if not questTitle then
        return nil
    end
    return action .. " '" .. questTitle .. "'"
end

local function SelectActionableQuest(APR, ids, action)
    local fallbackID
    local fallbackTitle
    for index = 1, #ids do
        local questID = ids[index]
        local completed = IsQuestCompleted(questID)
        local active = IsQuestActive(APR, questID)
        local actionable = false
        if action == "pickup" then
            actionable = not active and not completed
        elseif action == "done" then
            actionable = active and not completed
        else
            actionable = not completed
        end

        local title = ResolveQuestTitle(questID)
        if actionable and title then
            return questID, title
        end
        if actionable and not fallbackID then
            fallbackID = questID
            fallbackTitle = title
        end
    end

    if fallbackID then
        return fallbackID, fallbackTitle
    end

    for index = 1, #ids do
        local questID = ids[index]
        if not IsQuestCompleted(questID) then
            return questID, ResolveQuestTitle(questID)
        end
    end

    local firstID = ids[1]
    return firstID, firstID and ResolveQuestTitle(firstID) or nil
end

local function BuildPickupTitle(APR, step)
    local ids = GetArrayQuestIDs(step.PickUpDB or step.PickUp)
    local questID, questTitle = SelectActionableQuest(APR, ids, "pickup")
    local title = QuotedQuestTitle("Accept", questTitle)
    if title then
        return title, "pickupQuestTitle", questID, ids
    end
    return "Accept quests", "pickupFallback", questID or ids[1], ids
end

local function BuildDoneTitle(APR, step)
    local ids = GetArrayQuestIDs(step.DoneDB or step.Done)
    local questID, questTitle = SelectActionableQuest(APR, ids, "done")
    local title = QuotedQuestTitle("Turn in", questTitle)
    if title then
        return title, "doneQuestTitle", questID, ids
    end
    return "Turn in quests", "doneFallback", questID or ids[1], ids
end

local function NormalizeObjectiveList(value)
    local list = {}
    if type(value) == "table" then
        for _, objectiveIndex in pairs(value) do
            local id = NormalizeID(objectiveIndex)
            if id then
                list[#list + 1] = id
            end
        end
    else
        local id = NormalizeID(value)
        if id then
            list[#list + 1] = id
        end
    end
    table.sort(list)
    return list
end

local function FirstObjectiveList(value)
    if type(value) ~= "table" then
        return nil
    end
    return value[1] or value["1"] or select(2, next(value))
end

local function SelectQpartDBQuest(APR, qpartDB)
    local ids = GetArrayQuestIDs(qpartDB)
    for index = 1, #ids do
        local questID = ids[index]
        if IsQuestCompleted(questID) or IsQuestActive(APR, questID) then
            return questID, ids
        end
    end
    for index = 1, #ids do
        local questID = ids[index]
        if ResolveQuestTitle(questID) then
            return questID, ids
        end
    end
    return ids[1], ids
end

local function GetQpartEntries(APR, step, field)
    local entries = {}
    local ids = {}
    local seen = {}
    local qpart = type(step) == "table" and step[field] or nil
    if type(qpart) ~= "table" then
        return entries, ids
    end

    if field == "Qpart" and type(step.QpartDB) == "table" then
        local questID, dbIDs = SelectQpartDBQuest(APR, step.QpartDB)
        for index = 1, #dbIDs do
            AddUnique(ids, seen, dbIDs[index])
        end
        local objectives = NormalizeObjectiveList(FirstObjectiveList(qpart))
        if questID then
            for index = 1, #objectives do
                entries[#entries + 1] = { questID = questID, objectiveIndex = objectives[index] }
            end
        end
        return entries, ids
    end

    for rawQuestID, objectives in pairs(qpart) do
        local questID = AddUnique(ids, seen, rawQuestID)
        if questID then
            local objectiveList = NormalizeObjectiveList(objectives)
            for index = 1, #objectiveList do
                entries[#entries + 1] = { questID = questID, objectiveIndex = objectiveList[index] }
            end
        end
    end

    table.sort(entries, function(a, b)
        if a.questID == b.questID then
            return (a.objectiveIndex or 0) < (b.objectiveIndex or 0)
        end
        return (a.questID or 0) < (b.questID or 0)
    end)
    return entries, ids
end

local function IsObjectiveComplete(APR, questID, objectiveIndex)
    if IsQuestCompleted(questID) then
        return true
    end
    local active = type(APR) == "table" and type(APR.ActiveQuests) == "table" and APR.ActiveQuests[questID] or nil
    local objective = active and type(active.objectives) == "table" and active.objectives[objectiveIndex] or nil
    local completeStatus = type(APR) == "table" and type(APR.QUEST_STATUS) == "table" and APR.QUEST_STATUS.COMPLETE or "COMPLETE"
    return type(objective) == "table" and objective.status == completeStatus
end

local function ResolveAPRProgressText(APR, questID, objectiveIndex)
    if type(APR) ~= "table" or type(APR.GetQuestTextForProgressBar) ~= "function" then
        return nil
    end
    return TrimText(SafeCall(function()
        return APR:GetQuestTextForProgressBar(questID, objectiveIndex)
    end))
end

local function ResolveAPRActiveObjectiveText(APR, questID, objectiveIndex)
    local questData = type(APR) == "table" and type(APR.ActiveQuests) == "table" and APR.ActiveQuests[questID] or nil
    local objective = questData and type(questData.objectives) == "table" and questData.objectives[objectiveIndex] or nil
    return type(objective) == "table" and TrimText(objective.text) or nil
end

local function ResolveObjectiveTitle(APR, questID, objectiveIndex, genericTitle)
    local text = ResolveAPRProgressText(APR, questID, objectiveIndex)
    if text then
        return text, "aprProgressText"
    end

    text = ResolveAPRActiveObjectiveText(APR, questID, objectiveIndex)
    if text then
        return text, "aprActiveObjective"
    end

    if type(NS.ResolveQuestObjectiveText) == "function" then
        text = NS.ResolveQuestObjectiveText(questID, objectiveIndex)
        if text then
            return text, "blizzardObjective"
        end
    end

    local questTitle = ResolveQuestTitle(questID)
    text = QuotedQuestTitle("Complete", questTitle)
    if text then
        return text, "questTitleFallback"
    end

    return NormalizeGenericTitle(genericTitle) or "APR step", "aprGenericFallback"
end

local function BuildQpartTitle(APR, step, field, genericTitle)
    local entries, ids = GetQpartEntries(APR, step, field)
    local fallbackEntry = entries[1]
    for index = 1, #entries do
        local entry = entries[index]
        if not IsObjectiveComplete(APR, entry.questID, entry.objectiveIndex) then
            local title, source = ResolveObjectiveTitle(APR, entry.questID, entry.objectiveIndex, genericTitle)
            return title, source, entry.questID, ids
        end
    end

    if fallbackEntry then
        local title, source = ResolveObjectiveTitle(APR, fallbackEntry.questID, fallbackEntry.objectiveIndex, genericTitle)
        return title, source, fallbackEntry.questID, ids
    end

    return NormalizeGenericTitle(genericTitle) or "APR step", "aprGenericFallback", ids[1], ids
end

local function ResolveItemName(itemID)
    itemID = NormalizeID(itemID)
    if itemID and type(C_Item) == "table" and type(C_Item.GetItemInfo) == "function" then
        return TrimText(SafeCall(C_Item.GetItemInfo, itemID))
    end
end

local function ResolveSpellName(spellID)
    spellID = NormalizeID(spellID)
    if not spellID or type(C_Spell) ~= "table" or type(C_Spell.GetSpellInfo) ~= "function" then
        return nil
    end
    local info = SafeCall(C_Spell.GetSpellInfo, spellID)
    if type(info) == "table" then
        return TrimText(info.name)
    end
    return TrimText(info)
end

local function FormatGenericNameTitle(genericTitle, name, fallback)
    name = TrimText(name)
    local rawTitle = TrimText(genericTitle)
    if rawTitle and name and rawTitle:find("%%s", 1, true) then
        local ok, formatted = pcall(string.format, rawTitle, name)
        if ok then
            return TrimText(formatted)
        end
    end
    genericTitle = NormalizeGenericTitle(rawTitle)
    if genericTitle and name then
        return genericTitle .. " " .. name
    end
    return genericTitle or fallback
end

local function BuildUseItemTitle(step, genericTitle)
    local data = type(step.UseItem) == "table" and step.UseItem or nil
    local questID = data and NormalizeID(data.questID) or nil
    local title = FormatGenericNameTitle(genericTitle, ResolveItemName(data and data.itemID), "Use item")
    return title, "useItem", questID, questID and { questID } or {}
end

local function BuildUseSpellTitle(step, genericTitle)
    local data = type(step.UseSpell) == "table" and step.UseSpell or nil
    local questID = data and NormalizeID(data.questID) or nil
    local title = FormatGenericNameTitle(genericTitle, ResolveSpellName(data and data.spellID), "Use spell")
    return title, "useSpell", questID, questID and { questID } or {}
end

local function ResolveNoteTitle(APR, step)
    local note = type(step) == "table" and step.Note or nil
    if note == nil then
        return nil
    end
    if type(note) == "table" then
        note = note[1]
    end
    if type(APR) == "table" and type(APR.ResolveStepText) == "function" then
        local text = TrimText(SafeCall(function()
            local resolved = APR:ResolveStepText(note)
            return resolved
        end))
        if text then
            return text, "note"
        end
    end
    return TrimText(note), "note"
end

local function ParseButtonQuestIDs(step)
    local ids = {}
    local seen = {}
    for _, field in ipairs({ "Button", "SpellButton" }) do
        local value = type(step) == "table" and step[field] or nil
        if type(value) == "table" then
            for key in pairs(value) do
                local questID = type(key) == "string" and key:match("^(%d+)%-?%d*$") or key
                AddUnique(ids, seen, questID)
            end
        end
    end
    return ids
end

local function ExtractQuestIDsForStep(APR, step, stepKey)
    if type(step) ~= "table" then
        return {}
    end
    if stepKey == "PickUp" then
        return GetArrayQuestIDs(step.PickUpDB or step.PickUp)
    elseif stepKey == "Done" then
        return GetArrayQuestIDs(step.DoneDB or step.Done)
    elseif stepKey == "Qpart" then
        local _, ids = GetQpartEntries(APR, step, "Qpart")
        return ids
    elseif stepKey == "QpartPart" then
        local _, ids = GetQpartEntries(APR, step, "QpartPart")
        return ids
    end

    local ids = {}
    local seen = {}
    for _, field in ipairs({ "DropQuest", "ExitTutorial", "SetHS", "UseHS", "UseDalaHS", "UseGarrisonHS", "UseFlightPath", "WarMode", "Waypoint" }) do
        AddUnique(ids, seen, step[field])
    end
    for _, field in ipairs({ "Treasure", "TakePortal", "UseItem", "UseSpell", "EnterScenario", "DoScenario", "LeaveScenario", "EnterInstance", "LeaveInstance", "Scenario", "Group", "DroppableQuest" }) do
        AddUnique(ids, seen, GetNestedQuestID(step[field]))
    end

    local buttonIDs = ParseButtonQuestIDs(step)
    for index = 1, #buttonIDs do
        AddUnique(ids, seen, buttonIDs[index])
    end
    return ids
end

local function ResolveStepText(APR, value)
    if value == nil or type(APR) ~= "table" or type(APR.ResolveStepText) ~= "function" then
        return nil
    end
    local text = SafeCall(function()
        local resolved = APR:ResolveStepText(value)
        return resolved
    end)
    text = TrimText(text)
    if text and text ~= tostring(value) then
        return text
    end
    return text and type(value) == "string" and text or nil
end

local function BuildSubtext(APR, step)
    if type(step) ~= "table" then
        return nil, nil
    end

    local lines = {}
    local extra = {}
    for key, value in pairs(step) do
        if type(key) == "string" and key:match("^ExtraLineText%d*$") then
            extra[#extra + 1] = { key = key, value = value }
        end
    end
    table.sort(extra, function(a, b) return a.key < b.key end)

    for index = 1, #extra do
        local text = ResolveStepText(APR, extra[index].value)
        if text then
            lines[#lines + 1] = text
        end
    end

    local legacy = ResolveStepText(APR, step.ExtraLine)
    if legacy then
        lines[#lines + 1] = legacy
    end

    if #lines == 0 then
        return nil, nil
    end
    return table.concat(lines, "\n"), "aprExtraLineText"
end

function M.ResolveStep(APR, step)
    if type(step) ~= "table" then
        return {
            title = "APR step",
            rawTitle = "APR step",
            questIDs = {},
            titleSource = "missingStep",
        }
    end

    local genericTitle, genericKey = GetStepString(APR, step)
    local stepKey = DetectStepKey(APR, step, genericKey)
    local title, titleSource, primaryQuestID, questIDs

    if stepKey == "PickUp" then
        title, titleSource, primaryQuestID, questIDs = BuildPickupTitle(APR, step)
    elseif stepKey == "Done" then
        title, titleSource, primaryQuestID, questIDs = BuildDoneTitle(APR, step)
    elseif stepKey == "Qpart" then
        title, titleSource, primaryQuestID, questIDs = BuildQpartTitle(APR, step, "Qpart", genericTitle)
    elseif stepKey == "QpartPart" then
        title, titleSource, primaryQuestID, questIDs = BuildQpartTitle(APR, step, "QpartPart", genericTitle)
    elseif stepKey == "UseItem" then
        title, titleSource, primaryQuestID, questIDs = BuildUseItemTitle(step, genericTitle)
    elseif stepKey == "UseSpell" then
        title, titleSource, primaryQuestID, questIDs = BuildUseSpellTitle(step, genericTitle)
    elseif stepKey == "Note" then
        title, titleSource = ResolveNoteTitle(APR, step)
        questIDs = {}
    else
        questIDs = ExtractQuestIDsForStep(APR, step, stepKey)
        primaryQuestID = questIDs[1]
        title = NormalizeGenericTitle(genericTitle) or "APR step"
        titleSource = genericTitle and "aprGeneric" or "fallback"
    end

    title = TrimText(title) or NormalizeGenericTitle(genericTitle) or "APR step"
    questIDs = questIDs or {}
    if #questIDs == 0 then
        questIDs = ExtractQuestIDsForStep(APR, step, stepKey)
    end
    primaryQuestID = NormalizeID(primaryQuestID) or questIDs[1]

    local subtext, subtextSource = BuildSubtext(APR, step)
    return {
        title = title,
        rawTitle = title,
        subtext = subtext,
        stepKey = stepKey,
        questIDs = questIDs,
        primaryQuestID = primaryQuestID,
        titleSource = titleSource or "fallback",
        subtextSource = subtextSource,
    }
end
