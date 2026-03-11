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

    border._zwpBgR, border._zwpBgG, border._zwpBgB, border._zwpBgA = border:GetBackdropColor()
    border._zwpBorderR, border._zwpBorderG, border._zwpBorderB, border._zwpBorderA = border:GetBackdropBorderColor()
end

local function GuardBackdrop(parent, border)
    if not border or border._zwpBackdropGuarded then
        return
    end

    if type(border.SetBackdropColor) ~= "function" or type(border.SetBackdropBorderColor) ~= "function" then
        return
    end

    border._zwpOrigSetBackdropColor = border.SetBackdropColor
    border._zwpOrigSetBackdropBorderColor = border.SetBackdropBorderColor
    CaptureBackdrop(border)

    border.SetBackdropColor = function(self, r, g, b, a, ...)
        self._zwpBgR, self._zwpBgG, self._zwpBgB, self._zwpBgA = r, g, b, a
        if viewer.compactApplied and viewer.frame == parent then
            return self._zwpOrigSetBackdropColor(self, r or 0, g or 0, b or 0, 0, ...)
        end
        return self._zwpOrigSetBackdropColor(self, r, g, b, a, ...)
    end

    border.SetBackdropBorderColor = function(self, r, g, b, a, ...)
        self._zwpBorderR, self._zwpBorderG, self._zwpBorderB, self._zwpBorderA = r, g, b, a
        if viewer.compactApplied and viewer.frame == parent then
            return self._zwpOrigSetBackdropBorderColor(self, r or 0, g or 0, b or 0, 0, ...)
        end
        return self._zwpOrigSetBackdropBorderColor(self, r, g, b, a, ...)
    end

    border._zwpBackdropGuarded = true
end

local function RestoreBackdrop(border)
    if not border or not border._zwpBackdropGuarded then
        return
    end

    if border._zwpBgR ~= nil then
        border._zwpOrigSetBackdropColor(border, border._zwpBgR, border._zwpBgG, border._zwpBgB, border._zwpBgA)
    end
    if border._zwpBorderR ~= nil then
        border._zwpOrigSetBackdropBorderColor(border, border._zwpBorderR, border._zwpBorderG, border._zwpBorderB, border._zwpBorderA)
    end
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

local function GuardManagedFrame(parent, managed)
    if not managed or managed._zwpCompactGuarded then
        return
    end

    managed._zwpOrigShow = managed.Show
    managed._zwpOrigHide = managed.Hide
    managed._zwpOrigSetShown = managed.SetShown
    managed._zwpOrigSetAlpha = managed.SetAlpha
    managed._zwpDesiredShown = managed:IsShown()
    if managed.GetAlpha and managed._zwpOrigSetAlpha then
        managed._zwpDesiredAlpha = managed:GetAlpha()
    end

    managed.Show = function(self, ...)
        self._zwpDesiredShown = true
        if viewer.compactApplied and viewer.frame == parent then
            if self._zwpOrigSetAlpha then
                self._zwpOrigSetAlpha(self, 0)
            end
            return self._zwpOrigHide(self)
        end
        return self._zwpOrigShow(self, ...)
    end

    managed.Hide = function(self, ...)
        self._zwpDesiredShown = false
        return self._zwpOrigHide(self, ...)
    end

    if managed._zwpOrigSetShown then
        managed.SetShown = function(self, shown, ...)
            self._zwpDesiredShown = shown and true or false
            if shown then
                if viewer.compactApplied and viewer.frame == parent then
                    if self._zwpOrigSetAlpha then
                        self._zwpOrigSetAlpha(self, 0)
                    end
                    return self._zwpOrigHide(self)
                end
                return self._zwpOrigShow(self, ...)
            end
            return self._zwpOrigHide(self, ...)
        end
    end

    if managed._zwpOrigSetAlpha then
        managed.SetAlpha = function(self, alpha, ...)
            self._zwpDesiredAlpha = alpha
            if viewer.compactApplied and viewer.frame == parent then
                return self._zwpOrigSetAlpha(self, 0, ...)
            end
            return self._zwpOrigSetAlpha(self, alpha, ...)
        end
    end

    managed._zwpCompactGuarded = true
end

local function SyncManagedFrame(managed, compact)
    if not managed or not managed._zwpCompactGuarded then
        return
    end

    if compact then
        if managed._zwpOrigSetAlpha then
            managed._zwpOrigSetAlpha(managed, 0)
        end
        managed._zwpOrigHide(managed)
        return
    end

    if managed._zwpDesiredShown == false then
        managed._zwpOrigHide(managed)
    else
        managed._zwpOrigShow(managed)
    end

    if managed._zwpOrigSetAlpha and managed._zwpDesiredAlpha ~= nil then
        managed._zwpOrigSetAlpha(managed, managed._zwpDesiredAlpha)
    end
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

    if not viewer.compactApplied then
        CaptureBackdrop(frame.Border)
    end
    GuardBackdrop(frame, frame.Border)

    frame.Border:SetBackdropColor(0, 0, 0, 0)
    frame.Border:SetBackdropBorderColor(0, 0, 0, 0)

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

    RestoreBackdrop(frame.Border)

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
        RefreshChromeState(viewer.frame)
    end
end
