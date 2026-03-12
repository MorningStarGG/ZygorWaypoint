local NS = _G.ZygorWaypointNS
local state = NS.State

state.viewerChrome = state.viewerChrome or {
    frame = nil,
    compactApplied = false,
    lastMode = nil,
    managedFrames = nil,
    menuHosts = nil,
    hoverFrames = nil,
}

local viewer = state.viewerChrome

local function BuildFrameList(...)
    local list = {}
    for i = 1, select("#", ...) do
        local value = select(i, ...)
        if value then
            list[#list + 1] = value
        end
    end
    return list
end

local function GetViewerFrame()
    local Z = NS.ZGV()
    local frame = Z and Z.Frame
    if not Z or not frame or not frame.Border or not frame.Controls then
        return
    end

    if not frame.Controls.Scroll or not frame.Controls.StepContainer then
        return
    end

    return Z, frame
end

local function IsFrameMouseOver(frame)
    if not frame or not frame.IsShown or not frame:IsShown() then
        return false
    end

    if type(frame.IsMouseOver) == "function" then
        if frame:IsMouseOver() then
            return true
        end
    end

    if type(MouseIsOver) == "function" then
        if MouseIsOver(frame) then
            return true
        end
    end

    return false
end

local function CaptureBackdrop(border)
    if not border or type(border.GetBackdropColor) ~= "function" or type(border.GetBackdropBorderColor) ~= "function" then
        return
    end

    border._zwpDesiredBgR, border._zwpDesiredBgG, border._zwpDesiredBgB, border._zwpDesiredBgA = border:GetBackdropColor()
    border._zwpDesiredBorderR, border._zwpDesiredBorderG, border._zwpDesiredBorderB, border._zwpDesiredBorderA = border:GetBackdropBorderColor()
end

local function ApplyBackdropState(parent, border, compact)
    if not border or not border._zwpBackdropHooked then
        return
    end

    if viewer.frame ~= parent then
        return
    end

    border._zwpApplyingBackdrop = true
    if border._zwpDesiredBgR ~= nil then
        border:SetBackdropColor(
            border._zwpDesiredBgR,
            border._zwpDesiredBgG,
            border._zwpDesiredBgB,
            compact and 0 or border._zwpDesiredBgA
        )
    end
    if border._zwpDesiredBorderR ~= nil then
        border:SetBackdropBorderColor(
            border._zwpDesiredBorderR,
            border._zwpDesiredBorderG,
            border._zwpDesiredBorderB,
            compact and 0 or border._zwpDesiredBorderA
        )
    end
    border._zwpApplyingBackdrop = false
end

local function GuardBackdrop(parent, border)
    if not border or border._zwpBackdropHooked then
        return
    end

    if type(border.SetBackdropColor) ~= "function" or type(border.SetBackdropBorderColor) ~= "function" then
        return
    end

    CaptureBackdrop(border)

    hooksecurefunc(border, "SetBackdropColor", function(self, r, g, b, a)
        if self._zwpApplyingBackdrop then
            return
        end
        self._zwpDesiredBgR, self._zwpDesiredBgG, self._zwpDesiredBgB, self._zwpDesiredBgA = r, g, b, a
        if viewer.compactApplied and viewer.frame == parent then
            ApplyBackdropState(parent, self, true)
        end
    end)

    hooksecurefunc(border, "SetBackdropBorderColor", function(self, r, g, b, a)
        if self._zwpApplyingBackdrop then
            return
        end
        self._zwpDesiredBorderR, self._zwpDesiredBorderG, self._zwpDesiredBorderB, self._zwpDesiredBorderA = r, g, b, a
        if viewer.compactApplied and viewer.frame == parent then
            ApplyBackdropState(parent, self, true)
        end
    end)

    border._zwpBackdropHooked = true
end

local function CacheFrameCollections(frame)
    if viewer.frame == frame and viewer.managedFrames and viewer.menuHosts and viewer.hoverFrames then
        return
    end

    local controls = frame.Controls
    viewer.frame = frame
    viewer.managedFrames = BuildFrameList(
        frame.Border and frame.Border.Back or nil,
        controls.TitleBar,
        controls.MenuSettingsButton,
        controls.TabContainer,
        controls.Toolbar,
        controls.ProgressBar,
        controls.DefaultStateButton,
        controls.Scroll and controls.Scroll.Bar or nil,
        frame.ThinFlash
    )
    viewer.menuHosts = BuildFrameList(
        controls.MenuHostSettings,
        controls.MenuHostAdditional,
        controls.MenuHostGuides,
        controls.MenuHostNotifications,
        frame.Menu
    )
    viewer.hoverFrames = BuildFrameList(
        frame,
        frame.Border,
        controls.Scroll,
        controls.StepContainer
    )
end

local SyncManagedFrame

local function GuardManagedFrame(parent, managed)
    if not managed or managed._zwpCompactHooked then
        return
    end

    managed._zwpDesiredShown = managed:IsShown()
    if managed.GetAlpha and type(managed.SetAlpha) == "function" then
        managed._zwpDesiredAlpha = managed:GetAlpha()
    end

    if type(managed.Show) == "function" then
        hooksecurefunc(managed, "Show", function(self)
            if self._zwpApplyingCompact then
                return
            end
            self._zwpDesiredShown = true
            if viewer.compactApplied and viewer.frame == parent then
                SyncManagedFrame(self, true)
            end
        end)
    end

    if type(managed.Hide) == "function" then
        hooksecurefunc(managed, "Hide", function(self)
            if self._zwpApplyingCompact then
                return
            end
            self._zwpDesiredShown = false
        end)
    end

    if type(managed.SetShown) == "function" then
        hooksecurefunc(managed, "SetShown", function(self, shown)
            if self._zwpApplyingCompact then
                return
            end
            self._zwpDesiredShown = shown and true or false
            if viewer.compactApplied and viewer.frame == parent and shown then
                SyncManagedFrame(self, true)
            end
        end)
    end

    if type(managed.SetAlpha) == "function" then
        hooksecurefunc(managed, "SetAlpha", function(self, alpha)
            if self._zwpApplyingCompact then
                return
            end
            self._zwpDesiredAlpha = alpha
            if viewer.compactApplied and viewer.frame == parent then
                SyncManagedFrame(self, true)
            end
        end)
    end

    managed._zwpCompactHooked = true
end

SyncManagedFrame = function(managed, compact)
    if not managed or not managed._zwpCompactHooked then
        return
    end

    managed._zwpApplyingCompact = true

    if compact then
        if type(managed.SetAlpha) == "function" and managed._zwpDesiredAlpha ~= nil then
            managed:SetAlpha(0)
        end
        if type(managed.Hide) == "function" then
            managed:Hide()
        end
        managed._zwpApplyingCompact = false
        return
    end

    if managed._zwpDesiredShown == false then
        if type(managed.Hide) == "function" then
            managed:Hide()
        end
    else
        if type(managed.Show) == "function" then
            managed:Show()
        end
    end

    if type(managed.SetAlpha) == "function" and managed._zwpDesiredAlpha ~= nil then
        managed:SetAlpha(managed._zwpDesiredAlpha)
    end

    managed._zwpApplyingCompact = false
end

local function IsGuideMenuOpen(frame)
    CacheFrameCollections(frame)

    for _, host in ipairs(viewer.menuHosts) do
        if host and host.IsShown and host:IsShown() then
            return true
        end
    end

    for i = 1, 4 do
        local list = _G["DropDownForkList" .. i]
        if list and list.IsShown and list:IsShown() then
            local dropdown = list.dropdown
            for _, host in ipairs(viewer.menuHosts) do
                if dropdown and dropdown == host then
                    return true
                end
            end
        end
    end

    return false
end

local function IsGuideHovered(frame)
    if not frame or not frame.IsShown or not frame:IsShown() then
        return false
    end

    if IsGuideMenuOpen(frame) then
        return true
    end

    CacheFrameCollections(frame)
    for _, hoverFrame in ipairs(viewer.hoverFrames) do
        if IsFrameMouseOver(hoverFrame) then
            return true
        end
    end

    return false
end

local function HasVisibleStepRows(frame)
    if not frame or not frame.Controls or not frame.Controls.StepContainer then
        return false
    end

    if frame.specialstate ~= "normal" then
        return false
    end

    if not frame.Controls.StepContainer:IsShown() then
        return false
    end

    for _, stepframe in ipairs(frame.stepframes or {}) do
        if stepframe and stepframe.IsShown and stepframe:IsShown() then
            return true
        end
    end

    return false
end

local function ApplyCompactChrome(frame)
    if not frame or not frame.Border or not frame.Controls then
        return
    end

    GuardBackdrop(frame, frame.Border)
    ApplyBackdropState(frame, frame.Border, true)

    CacheFrameCollections(frame)
    for _, managed in ipairs(viewer.managedFrames) do
        SyncManagedFrame(managed, true)
    end

    viewer.compactApplied = true
end

local function RestoreFullChrome(frame)
    if not frame or not frame.Border or not frame.Controls then
        return
    end

    GuardBackdrop(frame, frame.Border)
    ApplyBackdropState(frame, frame.Border, false)

    CacheFrameCollections(frame)
    for _, managed in ipairs(viewer.managedFrames) do
        SyncManagedFrame(managed, false)
    end

    viewer.compactApplied = false
end

local function RefreshChromeState(frame)
    if not frame or not frame.IsShown or not frame:IsShown() then
        if viewer.compactApplied then
            RestoreFullChrome(frame)
        end
        viewer.lastMode = "hidden"
        return
    end

    local enabled = type(NS.IsGuideStepsOnlyHoverEnabled) == "function" and NS.IsGuideStepsOnlyHoverEnabled()
    local hasVisibleSteps = enabled and HasVisibleStepRows(frame)
    local mode

    if not hasVisibleSteps then
        mode = "full"
    else
        mode = IsGuideHovered(frame) and "full" or "compact"
    end

    if viewer.lastMode == mode then
        return
    end

    if mode == "compact" then
        ApplyCompactChrome(frame)
    else
        RestoreFullChrome(frame)
    end

    viewer.lastMode = mode
end

local function HookRefresh(frame, target)
    if not target or target._zwpChromeRefreshHooked then
        return
    end

    target:HookScript("OnShow", function()
        RefreshChromeState(frame)
    end)
    target:HookScript("OnHide", function()
        RefreshChromeState(frame)
    end)

    if target:HasScript("OnEnter") or target:IsMouseEnabled() then
        target:HookScript("OnEnter", function()
            RefreshChromeState(frame)
        end)
        target:HookScript("OnLeave", function()
            RefreshChromeState(frame)
        end)
    end

    target._zwpChromeRefreshHooked = true
end

local function HookStepFrames(frame)
    for _, stepframe in ipairs(frame.stepframes or {}) do
        HookRefresh(frame, stepframe)
    end
end

local function HookViewerFrame(Z, frame)
    if viewer.frame == frame and frame._zwpViewerChromeHooked then
        RefreshChromeState(frame)
        return
    end

    viewer.lastMode = nil
    CacheFrameCollections(frame)

    if frame._zwpViewerChromeHooked then
        RefreshChromeState(frame)
        return
    end

    for _, managed in ipairs(viewer.managedFrames) do
        GuardManagedFrame(frame, managed)
    end
    GuardBackdrop(frame, frame.Border)

    if type(frame.ApplySkin) == "function" then
        hooksecurefunc(frame, "ApplySkin", function()
            HookStepFrames(frame)
            RefreshChromeState(frame)
        end)
    end
    if type(frame.ShowSpecialState) == "function" then
        hooksecurefunc(frame, "ShowSpecialState", function()
            HookStepFrames(frame)
            RefreshChromeState(frame)
        end)
    end
    if type(frame.AlignFrame) == "function" then
        hooksecurefunc(frame, "AlignFrame", function()
            HookStepFrames(frame)
            RefreshChromeState(frame)
        end)
    end

    HookRefresh(frame, frame)
    HookRefresh(frame, frame.Border)
    HookRefresh(frame, frame.Controls.Scroll)
    HookRefresh(frame, frame.Controls.StepContainer)
    HookStepFrames(frame)

    for _, host in ipairs(viewer.menuHosts) do
        HookRefresh(frame, host)
    end

    frame:HookScript("OnSizeChanged", function()
        RefreshChromeState(frame)
    end)

    frame._zwpViewerChromeHooked = true
    RefreshChromeState(frame)
end

function NS.HookZygorViewerChromeMode()
    local Z, frame = GetViewerFrame()
    if Z and frame then
        HookViewerFrame(Z, frame)
    end
end

function NS.RefreshZygorViewerChromeMode()
    if viewer.frame then
        viewer.lastMode = nil
        if not NS.IsGuideStepsOnlyHoverEnabled or not NS.IsGuideStepsOnlyHoverEnabled() then
            RestoreFullChrome(viewer.frame)
            return
        end
        RefreshChromeState(viewer.frame)
    end
end
