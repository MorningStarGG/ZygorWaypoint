local NS = _G.AzerothWaypointNS
NS.Internal = NS.Internal or {}
NS.Internal.QueueUI = NS.Internal.QueueUI or {}
local M = NS.Internal.QueueUI
local ui = M.ui

local CreateQueueTabUI
local HideQueueTab
local ShowQueueTabContent
local ScheduleQueueTabPlacement
local AWPQueueTabMixin

function M.GetWorldMapFrame()
    return _G["QuestMapFrame"]
end

function M.GetMapCanvasFrame()
    return _G["WorldMapFrame"] or _G["QuestMapFrame"]
end

function M.EnsureWorldMapLoaded()
    if not M.GetWorldMapFrame()
        and type(C_AddOns) == "table"
        and type(C_AddOns.LoadAddOn) == "function"
    then
        pcall(C_AddOns.LoadAddOn, "Blizzard_WorldMap")
    end
    return M.GetWorldMapFrame()
end

function M.CenterMapCanvas()
    local mapFrame = M.GetMapCanvasFrame()
    local scrollContainer = mapFrame and mapFrame.ScrollContainer or nil
    if not scrollContainer
        or type(scrollContainer.SetNormalizedHorizontalScroll) ~= "function"
        or type(scrollContainer.SetNormalizedVerticalScroll) ~= "function"
    then
        return false
    end

    scrollContainer.targetScrollX = 0.5
    scrollContainer.targetScrollY = 0.5
    scrollContainer.currentScrollX = 0.5
    scrollContainer.currentScrollY = 0.5
    scrollContainer:SetNormalizedHorizontalScroll(0.5)
    scrollContainer:SetNormalizedVerticalScroll(0.5)
    return true
end

local function EnsureQueueTabMixin()
    if AWPQueueTabMixin then
        return AWPQueueTabMixin
    end
    local SidePanelTabButtonMixin = _G["SidePanelTabButtonMixin"]
    if type(SidePanelTabButtonMixin) ~= "table" then
        return nil
    end

    AWPQueueTabMixin = CreateFromMixins(SidePanelTabButtonMixin)

    function AWPQueueTabMixin:OnMouseDown(button)
        SidePanelTabButtonMixin.OnMouseDown(self, button)
    end

    function AWPQueueTabMixin:OnMouseUp(button, upInside)
        SidePanelTabButtonMixin.OnMouseUp(self, button, upInside)
        if button == "LeftButton" and upInside then
            ShowQueueTabContent()
        end
    end

    function AWPQueueTabMixin:OnEnter()
        SidePanelTabButtonMixin.OnEnter(self)
    end

    function AWPQueueTabMixin:SetChecked(checked)
        SidePanelTabButtonMixin.SetChecked(self, checked)
        if self.Icon then
            self.Icon:SetSize(24, 24)
            self.Icon:SetAlpha(checked and 1 or 0.55)
        end
    end

    return AWPQueueTabMixin
end

local function SetQueueTabChecked(checked)
    if ui.tab and type(ui.tab.SetChecked) == "function" then
        ui.tab:SetChecked(checked)
    end
end

local function BuildOfficialModeSet()
    local modes = {}
    if type(QuestLogDisplayMode) == "table" then
        for _, displayMode in pairs(QuestLogDisplayMode) do
            modes[displayMode] = true
        end
    end
    return modes
end

local function IsQuestMapSideTab(frame)
    return type(frame) == "table"
        and frame.displayMode ~= nil
        and frame.OnEnter ~= nil
        and type(frame.IsShown) == "function"
        and frame:IsShown()
end

HideQueueTab = function()
    ui.active = false
    if ui.content then
        ui.content:Hide()
    end
    SetQueueTabChecked(false)
end

local function PlaceQuestMapSideTabs()
    local questMapFrame = M.GetWorldMapFrame()
    if not questMapFrame or not questMapFrame:IsShown() then
        return
    end

    local officialModes = BuildOfficialModeSet()
    local officialTabs = {}
    local addonTabs = {}

    local children = { questMapFrame:GetChildren() }
    for index = 1, #children do
        local child = children[index]
        if IsQuestMapSideTab(child) then
            if officialModes[child.displayMode] then
                officialTabs[#officialTabs + 1] = child
            else
                addonTabs[#addonTabs + 1] = child
            end
        end
    end

    -- Clear all addon tab anchors before rebuilding the stack. Otherwise two
    -- addons can anchor to each other's stale positions during display-mode swaps.
    for index = 1, #addonTabs do
        addonTabs[index]:ClearAllPoints()
    end

    local placedTabs = officialTabs
    for index = 1, #addonTabs do
        local tab = addonTabs[index]
        local numShown = #placedTabs

        if numShown == 0 then
            tab:SetPoint("LEFT", questMapFrame, "RIGHT")
        else
            local row = numShown % ui.maxTabsPerColumn
            local relativePoint = "BOTTOMLEFT"
            local offsetY = -3
            local anchorTab = placedTabs[numShown]

            if row == 0 then
                anchorTab = placedTabs[numShown + 1 - ui.maxTabsPerColumn] or anchorTab
                relativePoint = "TOPRIGHT"
                offsetY = 0
            end

            tab:SetPoint("TOPLEFT", anchorTab, relativePoint, 0, offsetY)
        end

        placedTabs[#placedTabs + 1] = tab
    end
end

local function HookOtherCustomMapTabs()
    local questMapFrame = M.GetWorldMapFrame()
    if not questMapFrame then
        return
    end

    ui.hookedTabs = ui.hookedTabs or setmetatable({}, { __mode = "k" })
    local officialModes = BuildOfficialModeSet()
    local children = { questMapFrame:GetChildren() }
    for index = 1, #children do
        local child = children[index]
        if child ~= ui.tab
            and child.displayMode
            and not officialModes[child.displayMode]
            and type(child.SetChecked) == "function"
            and not ui.hookedTabs[child]
        then
            ui.hookedTabs[child] = true
            child:HookScript("OnMouseUp", function(self, button, upInside)
                if button == "LeftButton" and upInside then
                    HideQueueTab()
                end
            end)
            child:HookScript("OnShow", ScheduleQueueTabPlacement)
            child:HookScript("OnHide", ScheduleQueueTabPlacement)
        end
    end
end

ScheduleQueueTabPlacement = function()
    PlaceQuestMapSideTabs()
    if type(C_Timer) == "table" and type(C_Timer.After) == "function" then
        C_Timer.After(0, PlaceQuestMapSideTabs)
        C_Timer.After(0.05, PlaceQuestMapSideTabs)
        C_Timer.After(0.15, PlaceQuestMapSideTabs)
    end
end

local function UpdateHeader(selectedQueue, queueType, viewMode)
    if not ui.content then
        return
    end

    if viewMode == "detail" and type(selectedQueue) == "table" then
        ui.content.title:SetText(tostring(selectedQueue.label or "Queue"))
    else
        ui.content.title:SetText("Waypoint Queues")
    end
end

local function UpdateFooterState(selectedQueue, queueType, viewMode, activeManualQueueID)
    if not ui.content then
        return
    end

    local isDetail = viewMode == "detail" and type(selectedQueue) == "table"
    local canUse = (queueType == "manual" or queueType == "guide") and type(selectedQueue) == "table"
    local canClear = queueType == "manual" or queueType == "transient"
    local isActiveManualQueue = canUse and M.IsManualQueueActive(selectedQueue.id, {
        activeManualQueueID = activeManualQueueID,
    })
    local canUseAction = false
    if canUse and queueType == "manual" then
        if isActiveManualQueue then
            canUseAction = type(NS.StopUsingManualQueue) == "function"
        else
            canUseAction = type(NS.SetActiveManualQueue) == "function"
        end
    elseif canUse and queueType == "guide" then
        canUseAction = type(NS.ActivateGuideQueueByID) == "function"
    end

    ui.content.backButton:SetShown(isDetail)

    ui.content.useButton:SetShown(isDetail and canUse)
    ui.content.useButton:SetEnabled(canUseAction)
    ui.content.useButton:SetText(isActiveManualQueue and "Deactivate Queue" or "Activate Queue")

    ui.content.clearButton:SetShown(isDetail and canClear)
    ui.content.clearButton:SetEnabled(canClear)

    ui.content.toggleDetailsButton:SetShown(false)
    ui.content.toggleDetailsButton:SetEnabled(false)

    ui.content.importButton:SetShown(not isDetail)
    ui.content.importButton:SetEnabled(type(NS.OpenTomTomPasteWindow) == "function")

    ui.content.questsButton:SetShown(not isDetail)

    local footerHeight = M.ReflowFooterButtons(viewMode, selectedQueue, queueType)
    M.UpdateBulkDeleteButton(selectedQueue, queueType, viewMode)
    local bottomInset = footerHeight > 0 and (footerHeight + 20) or 12

    if isDetail then
        M.SetContentPageBounds(ui.content.detailPage, bottomInset)
    else
        M.SetContentPageBounds(ui.content.listPage, bottomInset)
    end
end

function M.Refresh()
    if not ui.content then
        return
    end

    local snapshot = type(NS.GetQueuePanelSnapshot) == "function" and NS.GetQueuePanelSnapshot() or nil
    M.PruneBulkSelections(snapshot)
    local rows = M.BuildQueueRows(snapshot or {})
    local selectedKey = type(NS.GetQueuePanelSelection) == "function" and NS.GetQueuePanelSelection() or nil
    local exactSelectedQueue = M.FindQueueByKey(snapshot, selectedKey)
    local viewMode = M.GetViewMode()

    if viewMode == "detail" and type(exactSelectedQueue) ~= "table" then
        viewMode = "list"
        M.SetViewMode(viewMode)
        if type(NS.SetQueuePanelSelection) == "function" then
            NS.SetQueuePanelSelection(nil)
        end
        selectedKey = nil
    end

    local selectedQueue, queueType = M.ResolveSelectedQueue(snapshot)
    if type(selectedQueue) == "table" and type(NS.SetQueuePanelSelection) == "function" then
        NS.SetQueuePanelSelection(selectedQueue.id)
        selectedKey = selectedQueue.id
    end

    if viewMode == "detail" and type(selectedQueue) ~= "table" then
        viewMode = "list"
        M.SetViewMode(viewMode)
    end

    UpdateHeader(selectedQueue, queueType, viewMode)
    UpdateFooterState(selectedQueue, queueType, viewMode, snapshot and snapshot.activeManualQueueID)

    ui.content.listPage:SetShown(viewMode == "list")
    ui.content.detailPage:SetShown(viewMode == "detail" and type(selectedQueue) == "table")

    M.RenderListPage(snapshot, rows, selectedKey)
    if viewMode == "detail" and type(selectedQueue) == "table" then
        M.RenderDetailPage(selectedQueue, queueType, M.BuildDetailRows(selectedQueue, queueType))
    else
        M.RenderDetailPage(nil, nil, nil)
    end
end

ShowQueueTabContent = function()
    local questMapFrame = M.EnsureWorldMapLoaded()
    if not ui.content or not questMapFrame then
        return false
    end

    if not ui.content:IsShown() then
        ui.settingDisplayMode = true
        if type(QuestLogDisplayMode) == "table" and QuestLogDisplayMode.Quests ~= nil then
            questMapFrame:SetDisplayMode(QuestLogDisplayMode.Quests)
        end
        questMapFrame:SetDisplayMode()
        ui.settingDisplayMode = nil
    end

    ui.active = true
    ui.content:Show()
    SetQueueTabChecked(true)
    M.Refresh()
    ScheduleQueueTabPlacement()
    return true
end

local function EnsureCallbacksRegistered()
    if ui.callbacksRegistered or type(EventRegistry) ~= "table" then
        return
    end
    ui.callbacksRegistered = true

    EventRegistry:RegisterCallback("WorldMapOnShow", function()
        if not ui.tab or not ui.content then
            CreateQueueTabUI()
        end
        HookOtherCustomMapTabs()
        ScheduleQueueTabPlacement()
        if ui.active then
            ShowQueueTabContent()
        else
            SetQueueTabChecked(false)
        end
    end, ui)

    EventRegistry:RegisterCallback("QuestLog.SetDisplayMode", function(_, displayMode)
        HookOtherCustomMapTabs()
        ScheduleQueueTabPlacement()
        if not ui.settingDisplayMode and displayMode ~= nil then
            HideQueueTab()
        end
    end, ui)
end

CreateQueueTabUI = function()
    local questMapFrame = M.EnsureWorldMapLoaded()
    if not questMapFrame or not questMapFrame.ContentsAnchor then
        return false
    end
    if ui.tab and ui.content then
        return true
    end

    EnsureCallbacksRegistered()
    HookOtherCustomMapTabs()
    if not ui.layoutHooksRegistered then
        ui.layoutHooksRegistered = true
        if type(questMapFrame.HookScript) == "function" then
            questMapFrame:HookScript("OnSizeChanged", ScheduleQueueTabPlacement)
        end
        if questMapFrame.ContentsAnchor and type(questMapFrame.ContentsAnchor.HookScript) == "function" then
            questMapFrame.ContentsAnchor:HookScript("OnSizeChanged", function()
                if ui.content and ui.content:IsShown() then
                    M.Refresh()
                end
                ScheduleQueueTabPlacement()
            end)
        end
    end

    if not ui.tab then
        local tabMixin = EnsureQueueTabMixin()
        if not tabMixin then
            return false
        end
        ui.tab = CreateFrame("Button", "AWPQuestMapQueueTab", questMapFrame, "LargeSideTabButtonTemplate")
        Mixin(ui.tab, tabMixin)
        ui.tab.displayMode = "AWP_QUEUE"
        ui.tab.tooltipText = "AzerothWaypoint Queues"
        ui.tab.activeAtlas = "islands-queue-prop-compass"
        ui.tab.inactiveAtlas = "islands-queue-prop-compass"
        ui.tab.useAtlasSize = false
        ui.tab:SetChecked(false)
        ui.tab:ClearAllPoints()
        ui.tab:SetPoint("LEFT", questMapFrame, "RIGHT")
        ui.tab:SetScript("OnMouseDown", ui.tab.OnMouseDown)
        ui.tab:SetScript("OnMouseUp", ui.tab.OnMouseUp)
        ui.tab:SetScript("OnEnter", ui.tab.OnEnter)
        ui.tab:SetScript("OnLeave", function(self)
            if GameTooltip and GameTooltip:IsOwned(self) then
                GameTooltip:Hide()
            end
        end)
        SetQueueTabChecked(false)
    end

    if ui.content then
        return true
    end

    local content = CreateFrame("Frame", "AWPQuestMapQueueContent", questMapFrame)
    content.displayMode = ui.tab.displayMode
    content:SetPoint("TOPLEFT", questMapFrame.ContentsAnchor, "TOPLEFT")
    content:SetPoint("BOTTOMRIGHT", questMapFrame.ContentsAnchor, "BOTTOMRIGHT")
    content:Hide()
    content:SetScript("OnShow", function()
        ui.active = true
        M.Refresh()
    end)
    content:SetScript("OnHide", function()
        local questMapFrame = M.GetWorldMapFrame()
        if questMapFrame and questMapFrame:IsShown() then
            ui.active = false
            SetQueueTabChecked(false)
        end
    end)
    ui.content = content

    content.bg = content:CreateTexture(nil, "BACKGROUND")
    content.bg:SetAtlas("QuestLog-main-background", true)
    content.bg:SetPoint("TOPLEFT")
    content.bg:SetPoint("BOTTOMRIGHT")

    content.border = CreateFrame("Frame", nil, content, "QuestLogBorderFrameTemplate")
    content.border:SetAllPoints()

    content.title = content:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
    content.title:SetPoint("TOP", content, "TOP", 0, -18)
    content.title:SetJustifyH("CENTER")
    content.title:SetText("Waypoint Queues")

    M.CreateListPage(content)
    M.CreateDetailPage(content)

    content.useButton = CreateFrame("Button", nil, content, "UIPanelButtonTemplate")
    content.useButton:SetSize(96, 24)
    content.useButton:SetText("Activate Queue")
    content.useButton:SetScript("OnClick", function()
        local key = type(NS.GetQueuePanelSelection) == "function" and NS.GetQueuePanelSelection() or nil
        M.ToggleQueueUseByKey(key)
    end)

    content.clearButton = CreateFrame("Button", nil, content, "UIPanelButtonTemplate")
    content.clearButton:SetSize(96, 24)
    content.clearButton:SetText("Clear")
    content.clearButton:SetScript("OnClick", function()
        local key = type(NS.GetQueuePanelSelection) == "function" and NS.GetQueuePanelSelection() or nil
        M.ClearQueueByKey(key)
    end)

    content.toggleDetailsButton = CreateFrame("Button", nil, content, "UIPanelButtonTemplate")
    content.toggleDetailsButton:SetSize(110, 24)
    content.toggleDetailsButton:SetText("Show Details")
    content.toggleDetailsButton:Hide()
    content.toggleDetailsButton:SetScript("OnClick", function()
        local key = type(NS.GetQueuePanelSelection) == "function" and NS.GetQueuePanelSelection() or nil
        M.ToggleQueueDetailsByKey(key)
    end)

    content.questsButton = CreateFrame("Button", nil, content, "UIPanelButtonTemplate")
    content.questsButton:SetSize(110, 24)
    content.questsButton:SetPoint("RIGHT", content, "BOTTOMRIGHT", -12, 12)
    content.questsButton:SetText("Quest Log")
    content.questsButton:SetScript("OnClick", function()
        local questMapFrame = M.EnsureWorldMapLoaded()
        if questMapFrame
            and type(QuestLogDisplayMode) == "table"
            and QuestLogDisplayMode.Quests ~= nil
        then
            questMapFrame:SetDisplayMode(QuestLogDisplayMode.Quests)
        else
            HideQueueTab()
        end
    end)

    content.importButton = CreateFrame("Button", nil, content, "UIPanelButtonTemplate")
    content.importButton:SetSize(96, 24)
    content.importButton:SetPoint("RIGHT", content.questsButton, "LEFT", -8, 0)
    content.importButton:SetText("Import")
    content.importButton:SetScript("OnClick", M.OpenImportWindow)
    content.importButton:SetScript("OnEnter", function(self)
        if GameTooltip then
            GameTooltip:SetOwner(self, "ANCHOR_TOP")
            GameTooltip:SetText("Import TomTom Waypoints", 1, 1, 1)
            GameTooltip:AddLine("Open TomTom's /ttpaste window.", 0.8, 0.8, 0.8, true)
            GameTooltip:Show()
        end
    end)
    content.importButton:SetScript("OnLeave", function()
        if GameTooltip then
            GameTooltip:Hide()
        end
    end)

    content.bulkDeleteButton = CreateFrame("Button", nil, content)
    content.bulkDeleteButton:SetSize(26, 26)
    content.bulkDeleteButton:Hide()
    content.bulkDeleteButton.icon = content.bulkDeleteButton:CreateTexture(nil, "ARTWORK")
    content.bulkDeleteButton.icon:SetPoint("CENTER")
    content.bulkDeleteButton.icon:SetSize(22, 22)
    content.bulkDeleteButton.icon:SetAtlas("common-icon-delete", false)
    content.bulkDeleteButton.glow = content.bulkDeleteButton:CreateTexture(nil, "OVERLAY")
    content.bulkDeleteButton.glow:SetPoint("CENTER")
    content.bulkDeleteButton.glow:SetSize(24, 24)
    content.bulkDeleteButton.glow:SetAtlas("common-icon-delete", false)
    content.bulkDeleteButton.glow:SetBlendMode("ADD")
    content.bulkDeleteButton.glow:SetAlpha(0.7)
    content.bulkDeleteButton.glow:Hide()
    content.bulkDeleteButton:SetScript("OnClick", function(self)
        if self.deleteMode == "items" then
            M.DeleteSelectedQueueItems(self.queueKey)
        else
            M.DeleteSelectedQueues()
        end
    end)
    content.bulkDeleteButton:SetScript("OnEnter", function(self)
        if self.glow then
            self.glow:Show()
        end
        if GameTooltip then
            GameTooltip:SetOwner(self, "ANCHOR_TOP")
            if self.deleteMode == "items" then
                GameTooltip:SetText("Remove selected destinations", 1, 1, 1)
                GameTooltip:AddLine(string.format("%d selected", tonumber(self.deleteCount) or 0), 0.8, 0.8, 0.8)
            else
                GameTooltip:SetText("Delete selected queues", 1, 1, 1)
                GameTooltip:AddLine(string.format("%d selected", tonumber(self.deleteCount) or 0), 0.8, 0.8, 0.8)
            end
            GameTooltip:Show()
        end
    end)
    content.bulkDeleteButton:SetScript("OnLeave", function(self)
        if self.glow then
            self.glow:Hide()
        end
        if GameTooltip then
            GameTooltip:Hide()
        end
    end)

    return true
end

local function OpenQueueInQuestMap()
    local questMapFrame = M.EnsureWorldMapLoaded()
    if not questMapFrame then
        return false
    end
    if not CreateQueueTabUI() then
        return false
    end

    local worldMap = _G["WorldMapFrame"]
    if not (worldMap and worldMap:IsShown()) then
        if type(ToggleWorldMap) == "function" then
            ToggleWorldMap()
        elseif worldMap then
            worldMap:Show()
        end
    end

    M.SetViewMode("list")

    local schedule = type(NS.After) == "function"
        and NS.After
        or function(_, callback)
            if type(callback) == "function" then
                callback()
            end
        end

    schedule(0, function()
        local frame = M.EnsureWorldMapLoaded()
        if not frame then
            return
        end
        ShowQueueTabContent()
    end)
    return true
end

function NS.RefreshQueuePanel()
    if ui.content and ui.content:IsShown() then
        M.Refresh()
    end
end

function NS.ShowQueuePanel()
    if OpenQueueInQuestMap() then
        return true
    end
    NS.Msg("Queue UI unavailable: World Map could not be opened.")
    return false
end

local initializer = CreateFrame("Frame")
initializer:RegisterEvent("PLAYER_LOGIN")
initializer:RegisterEvent("ADDON_LOADED")
initializer:SetScript("OnEvent", function(_, event, arg1)
    if event == "PLAYER_LOGIN" then
        EnsureCallbacksRegistered()
        if M.GetWorldMapFrame() then
            CreateQueueTabUI()
        end
        return
    end

    if arg1 == "Blizzard_WorldMap" then
        CreateQueueTabUI()
    end
end)
