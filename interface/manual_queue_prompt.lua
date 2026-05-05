local NS = _G.AzerothWaypointNS

local UIStyle = NS.UIStyle or {}
local manualQueuePrompt
local pendingChoiceCallback

local function HidePrompt()
    if manualQueuePrompt then
        manualQueuePrompt:Hide()
    end
    pendingChoiceCallback = nil
end

local function ApplyChoice(choice)
    local callback = pendingChoiceCallback
    HidePrompt()
    if type(callback) == "function" then
        callback(choice or "cancel")
    end
end

local function GetOrCreatePrompt()
    if manualQueuePrompt then
        return manualQueuePrompt
    end

    local frame = CreateFrame("Frame", "AWPManualQueuePrompt", UIParent)
    frame:SetSize(420, 168)
    frame:SetFrameStrata("FULLSCREEN_DIALOG")
    if type(frame.SetToplevel) == "function" then
        frame:SetToplevel(true)
    end
    frame:SetPoint("CENTER")
    frame:SetClampedToScreen(true)
    frame:SetMovable(true)
    frame:EnableMouse(true)
    frame:RegisterForDrag("LeftButton")
    frame:SetScript("OnDragStart", frame.StartMoving)
    frame:SetScript("OnDragStop", frame.StopMovingOrSizing)
    frame:Hide()

    frame.bg = frame:CreateTexture(nil, "BACKGROUND")
    frame.bg:SetAllPoints()
    UIStyle.SetColorTexture(frame.bg, { 0.025, 0.020, 0.016, 0.97 })
    UIStyle.AddSimpleBorder(frame)

    frame.titleBar = CreateFrame("Frame", nil, frame)
    frame.titleBar:SetPoint("TOPLEFT", frame, "TOPLEFT", 1, -1)
    frame.titleBar:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -1, -1)
    frame.titleBar:SetHeight(30)
    frame.titleBar:EnableMouse(true)
    frame.titleBar:RegisterForDrag("LeftButton")
    frame.titleBar:SetScript("OnDragStart", function() frame:StartMoving() end)
    frame.titleBar:SetScript("OnDragStop", function() frame:StopMovingOrSizing() end)

    frame.titleBg = frame.titleBar:CreateTexture(nil, "BACKGROUND")
    frame.titleBg:SetAllPoints()
    UIStyle.SetColorTexture(frame.titleBg, { 0.055, 0.040, 0.030, 0.96 })

    frame.titleSep = frame.titleBar:CreateTexture(nil, "ARTWORK")
    frame.titleSep:SetPoint("BOTTOMLEFT", frame.titleBar, "BOTTOMLEFT", 0, 0)
    frame.titleSep:SetPoint("BOTTOMRIGHT", frame.titleBar, "BOTTOMRIGHT", 0, 0)
    frame.titleSep:SetHeight(1)
    frame.titleSep:SetColorTexture(1.0, 0.82, 0.08, 0.45)

    frame.titleText = frame.titleBar:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    frame.titleText:SetPoint("CENTER", frame.titleBar, "CENTER", 0, 0)
    frame.titleText:SetTextColor(1.0, 0.82, 0.0, 1)
    frame.titleText:SetText("Manual Queue")

    frame.closeButton = CreateFrame("Button", nil, frame.titleBar)
    frame.closeButton:SetSize(28, 28)
    frame.closeButton:SetPoint("RIGHT", frame.titleBar, "RIGHT", -8, 0)
    frame.closeButton.bg = frame.closeButton:CreateTexture(nil, "BACKGROUND")
    frame.closeButton.bg:SetAllPoints()
    UIStyle.SetColorTexture(frame.closeButton.bg, { 0, 0, 0, 0 })
    frame.closeButton.label = frame.closeButton:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    frame.closeButton.label:SetPoint("CENTER", frame.closeButton, "CENTER", 0, 0)
    frame.closeButton.label:SetText("X")
    frame.closeButton.label:SetTextColor(0.72, 0.66, 0.58, 0.90)
    frame.closeButton:SetScript("OnClick", function()
        ApplyChoice("cancel")
    end)
    frame.closeButton:SetScript("OnEnter", function(self)
        self.label:SetTextColor(1.0, 0.82, 0.0, 1)
        UIStyle.SetColorTexture(self.bg, { 0.50, 0.15, 0.10, 0.35 })
        if GameTooltip then
            GameTooltip:SetOwner(self, "ANCHOR_LEFT")
            GameTooltip:SetText("Close", 1, 1, 1)
            GameTooltip:Show()
        end
    end)
    frame.closeButton:SetScript("OnLeave", function(self)
        self.label:SetTextColor(0.72, 0.66, 0.58, 0.90)
        UIStyle.SetColorTexture(self.bg, { 0, 0, 0, 0 })
        if GameTooltip then
            GameTooltip:Hide()
        end
    end)

    frame.body = frame:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
    frame.body:SetPoint("TOPLEFT", frame, "TOPLEFT", 18, -48)
    frame.body:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -18, -48)
    frame.body:SetJustifyH("CENTER")
    frame.body:SetJustifyV("TOP")
    frame.body:SetWordWrap(true)
    frame.body:SetTextColor(1, 1, 1, 1)
    frame.body:SetText("Choose how to add this manual destination:")

    frame.destinationText = frame:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    frame.destinationText:SetPoint("TOPLEFT", frame.body, "BOTTOMLEFT", 0, -4)
    frame.destinationText:SetPoint("TOPRIGHT", frame.body, "BOTTOMRIGHT", 0, -4)
    frame.destinationText:SetJustifyH("CENTER")
    frame.destinationText:SetTextColor(1.0, 0.82, 0.0, 1)
    frame.destinationText:SetText("")

    frame.footer = CreateFrame("Frame", nil, frame)
    frame.footer:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", 1, 1)
    frame.footer:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -1, 1)
    frame.footer:SetHeight(48)
    frame.footer.bg = frame.footer:CreateTexture(nil, "BACKGROUND")
    frame.footer.bg:SetAllPoints()
    UIStyle.SetColorTexture(frame.footer.bg, { 0.040, 0.030, 0.024, 0.96 })
    frame.footer.sep = frame.footer:CreateTexture(nil, "ARTWORK")
    frame.footer.sep:SetPoint("TOPLEFT", frame.footer, "TOPLEFT", 0, 0)
    frame.footer.sep:SetPoint("TOPRIGHT", frame.footer, "TOPRIGHT", 0, 0)
    frame.footer.sep:SetHeight(1)
    frame.footer.sep:SetColorTexture(0.52, 0.35, 0.16, 0.55)

    frame.createButton = UIStyle.CreatePanelButton(frame.footer, "New Queue", function()
        ApplyChoice("create")
    end)
    frame.createButton:SetPoint("LEFT", frame.footer, "LEFT", 18, 0)

    frame.replaceButton = UIStyle.CreatePanelButton(frame.footer, "Replace", function()
        ApplyChoice("replace")
    end)
    frame.replaceButton:SetPoint("CENTER", frame.footer, "CENTER", 0, 0)

    frame.appendButton = UIStyle.CreatePanelButton(frame.footer, "Append", function()
        ApplyChoice("append")
    end)
    frame.appendButton:SetPoint("RIGHT", frame.footer, "RIGHT", -18, 0)

    manualQueuePrompt = frame
    return frame
end

function NS.ShowManualQueuePlacementPrompt(request, onChoice)
    local frame = GetOrCreatePrompt()
    request = type(request) == "table" and request or {}
    pendingChoiceCallback = onChoice
    frame.body:SetText("Choose how to add this manual destination:")
    frame.destinationText:SetText(tostring(request.title or "Manual destination"))
    frame:Show()
    if type(frame.Raise) == "function" then
        frame:Raise()
    end
end

function NS.HideManualQueuePlacementPrompt()
    HidePrompt()
end
