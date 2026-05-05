local NS = _G.AzerothWaypointNS
NS.Internal = NS.Internal or {}
NS.Internal.QueueUI = NS.Internal.QueueUI or {}
local M = NS.Internal.QueueUI
local ui = M.ui

function M.CreateListPage(content)
    content.listPage = CreateFrame("Frame", nil, content)
    M.SetContentPageBounds(content.listPage, 44)

    content.listBorder = CreateFrame("Frame", nil, content.listPage, "QuestLogBorderFrameTemplate")
    content.listBorder:SetAllPoints()

    content.listScroll = CreateFrame("ScrollFrame", nil, content.listPage, "UIPanelScrollFrameTemplate")
    content.listScroll:SetPoint("TOPLEFT", content.listPage, "TOPLEFT", 8, -8)
    content.listScroll:SetPoint("BOTTOMRIGHT", content.listPage, "BOTTOMRIGHT", -18, 8)

    content.listChild = CreateFrame("Frame", nil, content.listScroll)
    content.listChild:SetSize(1, 1)
    content.listScroll:SetScrollChild(content.listChild)
    content.rows = {}

    content.emptyText = content.listChild:CreateFontString(nil, "ARTWORK", "GameFontDisable")
    content.emptyText:SetPoint("TOPLEFT", content.listChild, "TOPLEFT", 4, 0)
    content.emptyText:SetPoint("RIGHT", content.listChild, "RIGHT", -4, 0)
    content.emptyText:SetJustifyH("LEFT")
    content.emptyText:SetText("")

    M.StyleLegacyScrollBar(content.listScroll, content.listPage)
end

function M.RenderListPage(snapshot, rows, selectedKey)
    if not ui.content then
        return
    end

    rows = rows or {}
    local queueCount = M.CountQueues(rows)
    local listWidth = M.GetScrollContentWidth(ui.content.listScroll, 1)
    ui.content.listChild:SetWidth(listWidth)

    ui.content.emptyText:SetShown(queueCount == 0)
    ui.content.emptyText:SetText(queueCount == 0 and "No queues available." or "")

    for index = 1, #rows do
        local row = ui.content.rows[index]
        if not row then
            row = CreateFrame("Button", nil, ui.content.listChild)
            row:SetHeight(ui.rowHeight)
            row:RegisterForClicks("LeftButtonUp", "RightButtonUp")
            row:SetHighlightTexture("Interface\\QuestFrame\\UI-QuestTitleHighlight")
            row.bg = row:CreateTexture(nil, "BACKGROUND")
            row.bg:SetAllPoints()
            row.bg:SetColorTexture(0.18, 0.22, 0.3, 0)
            row.check = CreateFrame("CheckButton", nil, row, "UICheckButtonTemplate")
            row.check:SetSize(20, 20)
            row.check:SetPoint("LEFT", row, "LEFT", 2, 0)
            row.check:SetScript("OnClick", function(self)
                local parent = self:GetParent()
                M.SetQueueSelected(parent.queueKey, self:GetChecked() == true)
                M.Refresh()
            end)
            row.check:SetScript("OnEnter", function(self)
                if GameTooltip then
                    GameTooltip:SetOwner(self, "ANCHOR_LEFT")
                    GameTooltip:SetText("Select queue", 1, 1, 1)
                    GameTooltip:AddLine("Select this queue for bulk deletion.", 0.8, 0.8, 0.8, true)
                    GameTooltip:Show()
                end
            end)
            row.check:SetScript("OnLeave", function()
                if GameTooltip then
                    GameTooltip:Hide()
                end
            end)
            row.check:Hide()
            row.deleteButton = CreateFrame("Button", nil, row)
            row.deleteButton:SetSize(18, 18)
            row.deleteButton:SetPoint("RIGHT", row, "RIGHT", -4, 0)
            row.deleteButton:RegisterForClicks("LeftButtonUp")
            row.deleteButton.icon = row.deleteButton:CreateTexture(nil, "ARTWORK")
            row.deleteButton.icon:SetPoint("CENTER")
            row.deleteButton.icon:SetSize(18, 18)
            row.deleteButton.icon:SetAtlas("common-icon-delete", false)
            row.deleteButton.glow = row.deleteButton:CreateTexture(nil, "OVERLAY")
            row.deleteButton.glow:SetPoint("CENTER")
            row.deleteButton.glow:SetSize(18, 18)
            row.deleteButton.glow:SetAtlas("common-icon-delete", false)
            row.deleteButton.glow:SetBlendMode("ADD")
            row.deleteButton.glow:SetAlpha(0.7)
            row.deleteButton.glow:Hide()
            row.deleteButton:SetScript("OnClick", function(self)
                local parent = self:GetParent()
                M.ClearQueueByKey(parent.queueKey)
            end)
            row.deleteButton:SetScript("OnEnter", function(self)
                self.glow:Show()
                if GameTooltip then
                    GameTooltip:SetOwner(self, "ANCHOR_LEFT")
                    GameTooltip:SetText("Delete queue", 1, 1, 1)
                    GameTooltip:Show()
                end
            end)
            row.deleteButton:SetScript("OnLeave", function(self)
                self.glow:Hide()
                if GameTooltip then
                    GameTooltip:Hide()
                end
            end)
            row.deleteButton:Hide()
            row.icon = row:CreateTexture(nil, "ARTWORK")
            row.icon:SetSize(14, 14)
            row.icon:SetPoint("LEFT", row, "LEFT", 8, 0)
            row.icon:Hide()
            row.text = row:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
            row.text:SetPoint("LEFT", row, "LEFT", 10, 0)
            row.text:SetPoint("RIGHT", row, "RIGHT", -26, 0)
            row.text:SetJustifyH("LEFT")
            row.toggleText = row:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
            row.toggleText:SetPoint("RIGHT", row, "RIGHT", -10, 0)
            row.toggleText:SetJustifyH("RIGHT")
            row:SetScript("OnClick", function(self, button)
                if button == "RightButton" then
                    if self.rowType == "queue" then
                        M.ShowQueueRowContextMenu(self, self.queue, self.queueType, self.queueKey)
                    end
                    return
                end

                if self.rowType == "section" then
                    M.SetSectionCollapsed(self.sectionKey, not self.collapsed)
                else
                    M.SelectQueue(self.queueKey)
                    M.SetViewMode("detail")
                end
                M.Refresh()
            end)
            ui.content.rows[index] = row
            row:SetPoint("LEFT", ui.content.listChild, "LEFT", 0, 0)
            row:SetPoint("RIGHT", ui.content.listChild, "RIGHT", 0, 0)
            if index == 1 then
                row:SetPoint("TOP", ui.content.listChild, "TOP", 0, 0)
            else
                row:SetPoint("TOP", ui.content.rows[index - 1], "BOTTOM", 0, -2)
            end
        end

        local rowData = rows[index]
        row:Show()
        row.rowType = rowData.rowType
        row.queueKey = rowData.key
        row.queueType = rowData.queueType
        row.queue = rowData.queue
        row.sectionKey = rowData.sectionKey
        row.collapsed = rowData.collapsed

        if rowData.rowType == "section" then
            row.check:Hide()
            row.deleteButton:Hide()
            row.bg:SetColorTexture(0.05, 0.05, 0.05, 0.82)
            row.text:SetFontObject("GameFontNormal")
            row.text:SetTextColor(0.86, 0.86, 0.86)
            row.toggleText:SetShown(true)
            row.toggleText:SetText(rowData.collapsed and "+" or "-")
            row.text:SetText(string.format("%s (%d)", tostring(rowData.label), tonumber(rowData.count) or 0))
            if row.icon then row.icon:Hide() end
            row.text:ClearAllPoints()
            row.text:SetPoint("LEFT", row, "LEFT", 10, 0)
            row.text:SetPoint("RIGHT", row, "RIGHT", -26, 0)
        else
            local bulkSelectable = M.IsQueueBulkSelectable(rowData.queueType) and type(rowData.key) == "string"
            row.check:SetShown(bulkSelectable)
            row.check:SetChecked(bulkSelectable and M.IsQueueSelected(rowData.key) or false)
            row.check:SetEnabled(bulkSelectable)
            row.deleteButton:SetShown(bulkSelectable)
            row.deleteButton:SetEnabled(bulkSelectable)

            row.bg:SetColorTexture(0.18, 0.22, 0.3, rowData.key == selectedKey and 0.24 or 0.08)
            row.text:SetFontObject("GameFontHighlight")
            row.text:SetTextColor(rowData.key == selectedKey and 1 or 0.92, rowData.key == selectedKey and 0.82 or 0.92,
                rowData.key == selectedKey and 0 or 0.92)
            row.toggleText:SetShown(false)
            row.text:SetText(tostring(rowData.label or rowData.key or "Queue"))
            local contentLeft = bulkSelectable and 30 or 8
            row.icon:ClearAllPoints()
            row.icon:SetPoint("LEFT", row, "LEFT", contentLeft, 0)
            if M.ApplyQueueIcon(row.icon, rowData.icon, 14) then
                row.text:ClearAllPoints()
                row.text:SetPoint("LEFT", row, "LEFT", contentLeft + 18, 0)
                row.text:SetPoint("RIGHT", row, "RIGHT", bulkSelectable and -28 or -26, 0)
            else
                row.text:ClearAllPoints()
                row.text:SetPoint("LEFT", row, "LEFT", bulkSelectable and 30 or 10, 0)
                row.text:SetPoint("RIGHT", row, "RIGHT", bulkSelectable and -28 or -26, 0)
            end
        end
    end

    for index = #rows + 1, #ui.content.rows do
        ui.content.rows[index]:Hide()
    end

    local totalHeight = #rows > 0 and (#rows * (ui.rowHeight + 2)) or 1
    ui.content.listChild:SetHeight(totalHeight)

end

