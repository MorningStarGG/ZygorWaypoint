local NS = _G.AzerothWaypointNS
NS.Internal = NS.Internal or {}
NS.Internal.QueueUI = NS.Internal.QueueUI or {}
local M = NS.Internal.QueueUI
local ui = M.ui

function M.CreateDetailPage(content)
    content.detailPage = CreateFrame("Frame", nil, content)
    M.SetContentPageBounds(content.detailPage, 44)
    content.detailPage:Hide()

    content.detailHeader = CreateFrame("Frame", nil, content.detailPage)
    content.detailHeader:SetPoint("TOPLEFT", content.detailPage, "TOPLEFT", 0, 0)
    content.detailHeader:SetPoint("TOPRIGHT", content.detailPage, "TOPRIGHT", 0, 0)
    content.detailHeader:SetHeight(86)

    content.detailIcon = content.detailHeader:CreateTexture(nil, "ARTWORK")
    content.detailIcon:SetSize(M.DETAIL_HEADER_ICON_SIZE, M.DETAIL_HEADER_ICON_SIZE)
    content.detailIcon:SetPoint("TOPLEFT", content.detailHeader, "TOPLEFT", 12, -36)
    content.detailIcon:Hide()

    content.detailHeadline = content.detailHeader:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
    content.detailHeadline:SetPoint("TOPLEFT", content.detailHeader, "TOPLEFT", 12, -34)
    content.detailHeadline:SetPoint("RIGHT", content.detailHeader, "RIGHT", -36, 0)
    content.detailHeadline:SetJustifyH("LEFT")
    content.detailHeadline:SetJustifyV("TOP")
    content.detailHeadline:SetTextColor(1.0, 0.82, 0.0)
    content.detailHeadline:SetWordWrap(true)
    content.detailHeadline:SetText("")

    content.detailSubline = content.detailHeader:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
    content.detailSubline:SetPoint("TOPLEFT", content.detailHeadline, "BOTTOMLEFT", 0, -4)
    content.detailSubline:SetPoint("RIGHT", content.detailHeader, "RIGHT", -12, 0)
    content.detailSubline:SetJustifyH("LEFT")
    content.detailSubline:SetJustifyV("TOP")
    content.detailSubline:SetWordWrap(true)
    content.detailSubline:SetText("")

    content.detailHint = content.detailHeader:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
    content.detailHint:SetPoint("TOPLEFT", content.detailSubline, "BOTTOMLEFT", 0, -4)
    content.detailHint:SetPoint("RIGHT", content.detailHeader, "RIGHT", -12, 0)
    content.detailHint:SetJustifyH("LEFT")
    content.detailHint:SetJustifyV("TOP")
    content.detailHint:SetTextColor(0.05, 0.82, 1.0)
    content.detailHint:SetWordWrap(true)
    content.detailHint:SetText("")

    content.routePanel = CreateFrame("Frame", nil, content.detailPage)
    content.routePanel:SetPoint("TOPLEFT", content.detailHeader, "BOTTOMLEFT", 0, -4)
    content.routePanel:SetPoint("TOPRIGHT", content.detailHeader, "BOTTOMRIGHT", 0, -4)

    content.detailBorder = CreateFrame("Frame", nil, content.routePanel, "QuestLogBorderFrameTemplate")
    content.detailBorder:SetAllPoints()

    content.summaryPanel = CreateFrame("Frame", nil, content.detailPage)
    content.summaryPanel:SetPoint("LEFT", content.detailPage, "LEFT", 0, 0)
    content.summaryPanel:SetPoint("RIGHT", content.detailPage, "RIGHT", 0, 0)
    content.summaryPanel:SetPoint("BOTTOM", content.detailPage, "BOTTOM", 0, 0)
    content.summaryPanel:SetHeight(88)

    content.routePanel:SetPoint("BOTTOMLEFT", content.summaryPanel, "TOPLEFT", 0, 8)
    content.routePanel:SetPoint("BOTTOMRIGHT", content.summaryPanel, "TOPRIGHT", 0, 8)

    content.summaryBorder = CreateFrame("Frame", nil, content.summaryPanel, "QuestLogBorderFrameTemplate")
    content.summaryBorder:SetAllPoints()

    content.detailMetaTitle = content.summaryPanel:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    content.detailMetaTitle:SetPoint("TOP", content.summaryPanel, "TOP", 0, -18)
    content.detailMetaTitle:SetText("Queue Info")

    content.detailMeta = content.summaryPanel:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    content.detailMeta:SetPoint("TOPLEFT", content.summaryPanel, "TOPLEFT", 14, -24)
    content.detailMeta:SetPoint("BOTTOMRIGHT", content.summaryPanel, "BOTTOMRIGHT", -14, 10)
    content.detailMeta:SetJustifyH("LEFT")
    content.detailMeta:SetJustifyV("TOP")
    content.detailMeta:SetWordWrap(true)
    content.detailMeta:SetText("")

    content.detailScroll = CreateFrame("ScrollFrame", nil, content.routePanel, "UIPanelScrollFrameTemplate")
    content.detailScroll:SetPoint("TOPLEFT", content.routePanel, "TOPLEFT", 8, -8)
    content.detailScroll:SetPoint("BOTTOMRIGHT", content.routePanel, "BOTTOMRIGHT", -18, 8)

    content.detailChild = CreateFrame("Frame", nil, content.detailScroll)
    content.detailChild:SetSize(1, 1)
    content.detailScroll:SetScrollChild(content.detailChild)
    content.detailRows = {}
    content.detailEmptyText = content.detailChild:CreateFontString(nil, "ARTWORK", "GameFontDisable")
    content.detailEmptyText:SetPoint("TOPLEFT", content.detailChild, "TOPLEFT", 8, -4)
    content.detailEmptyText:SetPoint("RIGHT", content.detailChild, "RIGHT", -8, 0)
    content.detailEmptyText:SetJustifyH("LEFT")
    content.detailEmptyText:SetJustifyV("TOP")
    content.detailEmptyText:SetText("")
    content.detailEmptyText:Hide()

    M.StyleLegacyScrollBar(content.detailScroll, content.routePanel)

    content.backButton = CreateFrame("Button", nil, content.detailPage, "UIPanelButtonTemplate")
    content.backButton:SetSize(80, 24)
    content.backButton:SetPoint("TOPLEFT", content.detailHeader, "TOPLEFT", 2, -2)
    content.backButton:SetText("Back")
    content.backButton:SetScript("OnClick", function()
        M.SetViewMode("list")
        M.Refresh()
    end)

    content.focusButton = CreateFrame("Button", nil, content.detailHeader)
    content.focusButton:SetSize(24, 24)
    content.focusButton:SetPoint("TOPRIGHT", content.detailHeader, "TOPRIGHT", -2, -2)

    content.focusButton.icon = content.focusButton:CreateTexture(nil, "ARTWORK")
    content.focusButton.icon:SetPoint("CENTER")
    content.focusButton.icon:SetAtlas("MonsterFriend", true)

    content.focusButton.hl = content.focusButton:CreateTexture(nil, "HIGHLIGHT")
    content.focusButton.hl:SetPoint("CENTER")
    content.focusButton.hl:SetAtlas("MonsterFriend", true)
    content.focusButton.hl:SetBlendMode("ADD")
    content.focusButton.hl:SetAlpha(0.35)
    content.focusButton:SetScript("OnClick", function()
        local snapshot = type(NS.GetQueuePanelSnapshot) == "function" and NS.GetQueuePanelSnapshot() or nil
        local selectedQueue = M.ResolveSelectedQueue(snapshot)
        M.FocusQueueFinalDestination(selectedQueue)
    end)
    content.focusButton:SetScript("OnEnter", function(self)
        if GameTooltip then
            GameTooltip:SetOwner(self, "ANCHOR_LEFT")
            GameTooltip:SetText("Show final destination", 1, 1, 1)
            GameTooltip:AddLine("Show the the destination on the map.", 0.8, 0.8, 0.8, true)
            GameTooltip:Show()
        end
    end)
    content.focusButton:SetScript("OnLeave", function()
        if GameTooltip then
            GameTooltip:Hide()
        end
    end)
end

function M.RenderDetailPage(selectedQueue, queueType, detailRows)
    if not ui.content then
        return
    end

    if type(selectedQueue) == "table" then
        local headline, subline, hint = M.BuildDetailHeaderTexts(selectedQueue)
        local hasFinalDestination = type(M.GetQueueFinalEntry(selectedQueue)) == "table"

        ui.content.detailHeadline:SetText(headline or "")
        ui.content.detailSubline:SetText(subline or "")
        ui.content.detailSubline:SetShown(type(subline) == "string" and subline ~= "")
        ui.content.detailHint:SetText(hint or "")
        ui.content.detailHint:SetShown(type(hint) == "string" and hint ~= "")

        local detailIconShown = M.ApplyQueueIcon(ui.content.detailIcon, M.GetQueueDetailHeaderIcon(selectedQueue, queueType), M.DETAIL_HEADER_ICON_SIZE)
        M.LayoutDetailHeaderIdentity(ui.content, detailIconShown)

        ui.content.focusButton:SetShown(hasFinalDestination)
        ui.content.focusButton:SetEnabled(hasFinalDestination)
        ui.content.detailMetaTitle:SetText("Queue Info")
        ui.content.detailMeta:SetText(M.BuildDetailMetaText(selectedQueue, queueType))
        detailRows = detailRows or M.BuildDetailRows(selectedQueue, queueType)
        local detailChildWidth = M.GetScrollContentWidth(ui.content.detailScroll, 160)
        ui.content.detailChild:SetWidth(detailChildWidth)
        local detailWidth = detailChildWidth
        local contentTop = 2

        local totalDetailHeight = 0
        local previousRow
        for index = 1, #detailRows do
            local row = ui.content.detailRows[index]
            if not row then
                row = CreateFrame("Button", nil, ui.content.detailChild)
                row:RegisterForClicks("LeftButtonUp", "RightButtonUp")
                row.bg = row:CreateTexture(nil, "BACKGROUND")
                row.bg:SetAllPoints()
                row.bg:SetColorTexture(0.18, 0.22, 0.3, 0)
                row.check = CreateFrame("CheckButton", nil, row, "UICheckButtonTemplate")
                row.check:SetSize(20, 20)
                row.check:SetPoint("LEFT", row, "LEFT", 2, 0)
                row.check:SetScript("OnClick", function(self)
                    local parent = self:GetParent()
                    M.SetQueueItemSelected(parent.queueKey, parent.queueDestinationIndex, self:GetChecked() == true)
                    M.Refresh()
                end)
                row.check:SetScript("OnEnter", function(self)
                    if GameTooltip then
                        GameTooltip:SetOwner(self, "ANCHOR_LEFT")
                        GameTooltip:SetText("Select destination", 1, 1, 1)
                        GameTooltip:AddLine("Select this destination for bulk removal.", 0.8, 0.8, 0.8, true)
                        GameTooltip:Show()
                    end
                end)
                row.check:SetScript("OnLeave", function()
                    if GameTooltip then
                        GameTooltip:Hide()
                    end
                end)
                row.check:Hide()
                row.title = row:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
                row.title:SetJustifyH("LEFT")
                row.title:SetJustifyV("TOP")
                row.detail = row:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
                row.detail:SetJustifyH("LEFT")
                row.detail:SetJustifyV("TOP")
                row.icon = row:CreateTexture(nil, "ARTWORK")
                row.icon:SetSize(18, 18)
                row.icon:SetPoint("LEFT", row, "LEFT", 7, 0)
                row.icon:Hide()
                row.toggleText = row:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
                row.toggleText:SetPoint("RIGHT", row, "RIGHT", -10, 0)
                row.toggleText:SetJustifyV("MIDDLE")
                row.toggleText:SetJustifyH("RIGHT")
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
                    M.RemoveQueueDestination(parent.queueKey, parent.queueDestinationIndex)
                end)
                row.deleteButton:SetScript("OnEnter", function(self)
                    self.glow:Show()
                    if GameTooltip then
                        GameTooltip:SetOwner(self, "ANCHOR_LEFT")
                        GameTooltip:SetText("Remove destination", 1, 1, 1)
                        GameTooltip:Show()
                    end
                end)
                row.deleteButton:SetScript("OnLeave", function(self)
                    self.glow:Hide()
                    if GameTooltip then
                        GameTooltip:Hide()
                    end
                end)
                row:SetHighlightTexture("Interface\\QuestFrame\\UI-QuestTitleHighlight")
                row:SetScript("OnClick", function(self, button)
                    if button == "RightButton" then
                        if self.selectableDestination then
                            M.ShowQueueDestinationContextMenu(self, self.rowTitle, self.queueKey, self.queueDestinationIndex, self.removableDestination)
                        end
                        return
                    end
                    if self.rowType == "section" then
                        M.SetDetailSectionCollapsed(self.queueKey, self.sectionKey, not self.collapsed)
                        M.Refresh()
                    elseif self.selectableDestination then
                        M.ActivateQueueDestination(self.queueKey, self.queueDestinationIndex)
                        M.Refresh()
                    end
                end)
                ui.content.detailRows[index] = row
            end

            local rowData = detailRows[index]
            row:ClearAllPoints()
            row:SetPoint("LEFT", ui.content.detailChild, "LEFT", 0, 0)
            row:SetPoint("RIGHT", ui.content.detailChild, "RIGHT", 0, 0)
            if previousRow then
                row:SetPoint("TOP", previousRow, "BOTTOM", 0, -2)
            else
                row:SetPoint("TOP", ui.content.detailChild, "TOP", 0, -contentTop)
            end

            row:Show()
            row.rowType = rowData.rowType
            row.queueKey = rowData.queueKey
            row.sectionKey = rowData.sectionKey
            row.collapsed = rowData.collapsed
            row.queueDestinationIndex = rowData.queueDestinationIndex
            row.selectableDestination = rowData.selectableDestination == true
            row.removableDestination = rowData.removableDestination == true
            row.rowTitle = rowData.title

            row.title:ClearAllPoints()
            row.detail:ClearAllPoints()

            if rowData.rowType == "section" then
                row.check:Hide()
                row.deleteButton:Hide()
                row.icon:Hide()
                row.bg:SetColorTexture(0.05, 0.05, 0.05, 0.82)
                row.toggleText:SetShown(true)
                row.toggleText:SetText(rowData.collapsed and "+" or "-")
                row.title:SetFontObject("GameFontNormal")
                row.title:SetTextColor(0.86, 0.86, 0.86)
                row.title:SetPoint("LEFT", row, "LEFT", 10, 0)
                row.title:SetPoint("RIGHT", row.toggleText, "LEFT", -8, 0)
                row.title:SetJustifyV("MIDDLE")
                row.title:SetText(string.format("%s (%d)", tostring(rowData.label), tonumber(rowData.count) or 0))
                row.detail:SetText("")
                row.detail:Hide()
                row:SetHeight(28)
            else
                local bulkSelectable = rowData.removableDestination == true
                    and type(rowData.queueKey) == "string"
                    and tonumber(rowData.queueDestinationIndex) ~= nil
                row.check:SetShown(bulkSelectable)
                row.check:SetEnabled(bulkSelectable)
                row.check:SetChecked(bulkSelectable and M.IsQueueItemSelected(rowData.queueKey, rowData.queueDestinationIndex) or false)
                row.bg:SetColorTexture(0.18, 0.22, 0.3, rowData.active and 0.24 or 0.08)
                row.toggleText:SetShown(false)
                row.deleteButton:SetShown(rowData.removableDestination == true)
                row.deleteButton:SetEnabled(rowData.removableDestination == true)
                row.title:SetFontObject(rowData.active and "GameFontNormal" or "GameFontHighlight")
                row.title:SetTextColor(rowData.active and 1 or 0.92, rowData.active and 0.82 or 0.92,
                    rowData.active and 0 or 0.92)
                row.detail:SetTextColor(0.76, 0.76, 0.76)
                local rightInset = rowData.removableDestination == true and 28 or 8
                local leftBase = bulkSelectable and 28 or 0
                row.icon:ClearAllPoints()
                row.icon:SetPoint("LEFT", row, "LEFT", leftBase + 7, 0)
                local leftInset = M.ApplyQueueIcon(row.icon, rowData.icon, 18) and (leftBase + 32) or (leftBase + 16)
                row.title:SetPoint("TOPLEFT", row, "TOPLEFT", leftInset, -4)
                row.title:SetPoint("RIGHT", row, "RIGHT", -rightInset, 0)
                row.detail:SetPoint("TOPLEFT", row.title, "BOTTOMLEFT", 0, -2)
                row.detail:SetPoint("RIGHT", row, "RIGHT", -rightInset, 0)
                row.title:SetWidth(detailWidth - leftInset - rightInset)
                row.detail:SetWidth(detailWidth - leftInset - rightInset)
                row.title:SetText(tostring(rowData.title or "Entry"))
                row.detail:SetText(tostring(rowData.detail or ""))
                row.detail:SetShown(rowData.detail ~= nil and rowData.detail ~= "")
                local height = row.title:GetStringHeight() + 10
                if row.detail:IsShown() then
                    height = height + row.detail:GetStringHeight() + 4
                end
                row:SetHeight(math.max(height, 30))
            end

            totalDetailHeight = totalDetailHeight + row:GetHeight() + 2
            previousRow = row
        end

        for index = #detailRows + 1, #ui.content.detailRows do
            ui.content.detailRows[index]:Hide()
        end

        ui.content.detailEmptyText:SetShown(#detailRows == 0)
        ui.content.detailEmptyText:SetWidth(detailWidth - 16)
        ui.content.detailEmptyText:SetText("No route details available.")

        ui.content.detailChild:SetHeight(math.max(totalDetailHeight, 1))
    else
        ui.content.detailHeadline:SetText("")
        ui.content.detailSubline:SetText("")
        ui.content.detailSubline:Hide()
        ui.content.detailHint:SetText("")
        ui.content.detailHint:Hide()
        ui.content.focusButton:Hide()
        ui.content.detailMetaTitle:SetText("")
        ui.content.detailMeta:SetText("")
        if ui.content.detailEmptyText then
            ui.content.detailEmptyText:Hide()
        end
        for index = 1, #ui.content.detailRows do
            ui.content.detailRows[index]:Hide()
        end
        ui.content.detailChild:SetHeight(1)
    end
end

