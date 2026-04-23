local NS = _G.ZygorWaypointNS
local M = NS.Internal.WorldOverlayNative

local overlay = M.overlay
local target = M.target
local derived = M.derived
local transition = M.transition
local CONFIG = M.Config

local Signature = NS.Signature
local NormalizeText = M.NormalizeText
local RefreshSettingsSnapshot = M.RefreshSettingsSnapshot
local InvalidateFrameCacheEntry = M.InvalidateFrameCacheEntry
local InvalidateFrameVisualsOnly = M.InvalidateFrameVisualsOnly
local ApplyOverlayAdornmentStyleToAll = M.ApplyOverlayAdornmentStyleToAll
local EnsureDriverRoot = M.EnsureDriverRoot
local EnsureOverlayHooks = M.EnsureOverlayHooks
local InvalidateQuestTypeDetailsCache = M.InvalidateQuestTypeDetailsCache
local InvalidateQuestSubtextCache = M.InvalidateQuestSubtextCache
local EnsureWaypointFrame = M.EnsureWaypointFrame
local EnsurePinpointFrame = M.EnsurePinpointFrame
local EnsureNavigatorFrame = M.EnsureNavigatorFrame
local HideAllFrames = M.HideAllFrames
local ResetFrameTextCaches = M.ResetFrameTextCaches
local ResetModeTransition = M.ResetModeTransition
local IsWaypointPinpointTransition = M.IsWaypointPinpointTransition
local StartModeTransition = M.StartModeTransition
local ClearNativeNavigationHost = M.ClearNativeNavigationHost
local ClearResolvedHostTarget = M.ClearResolvedHostTarget
local EnsureNativeNavigationHost = M.EnsureNativeNavigationHost
local RefreshResolvedHostTarget = M.RefreshResolvedHostTarget
local ResolveMode = M.ResolveMode
local RefreshNativeOverlayContent = M.RefreshNativeOverlayContent
local UpdateWaypointFrame = M.UpdateWaypointFrame
local UpdatePinpointFrame = M.UpdatePinpointFrame
local UpdateNavigatorFrame = M.UpdateNavigatorFrame
local RenderNativeOverlayVisuals = M.RenderNativeOverlayVisuals
local ApplySuperTrackedFrameVisibility = M.ApplySuperTrackedFrameVisibility
local ResetArrivalState = M.ResetArrivalState
local IsNativeSpecialTravelSuppressed = M.IsNativeSpecialTravelSuppressed

NS.InvalidateOverlaySettings = M.InvalidateOverlaySettings

local MODE_CONFIRM_WINDOW = {
    ["navigator->waypoint"] = 0.15,
    ["waypoint->navigator"] = 0.15,
    ["waypoint->pinpoint"] = 0.10,
    ["pinpoint->waypoint"] = 0.10,
}

local function EnsureActiveModeFrames(mode, prevMode)
    if transition.active then
        if transition.fromMode == "waypoint" or transition.toMode == "waypoint" then
            EnsureWaypointFrame()
        end
        if transition.fromMode == "pinpoint" or transition.toMode == "pinpoint" then
            EnsurePinpointFrame()
        end
    elseif mode == "waypoint" then
        EnsureWaypointFrame()
    elseif mode == "pinpoint" then
        EnsurePinpointFrame()
    end

    if mode == "navigator" or prevMode == "navigator" or overlay.navFadeState ~= "hidden" then
        EnsureNavigatorFrame()
    end
end

function NS.InitializeNativeWorldOverlay()
    -- Eagerly create all overlay frames at init time so SetPropagateMouseClicks
    -- and other protected methods are never called from inside a secure callback.
    M.EnsureFrames()
end

function NS.RefreshSuperTrackedFrameSuppression()
    if type(EnsureOverlayHooks) == "function" then
        EnsureOverlayHooks()
    end
    ApplySuperTrackedFrameVisibility()
end

function NS.InvalidateNativeOverlayQuestCaches(questID)
    if type(InvalidateQuestTypeDetailsCache) == "function" then
        InvalidateQuestTypeDetailsCache(questID)
    end
    if type(InvalidateQuestSubtextCache) == "function" then
        InvalidateQuestSubtextCache(questID)
    end

    overlay.contentDirty = true
    M.frameCacheDirty = true
    overlay.cachedIconSpec = nil
    overlay.cachedPinpointSubtext = nil
    overlay.lastContentRefresh = 0
    ResetFrameTextCaches()
end

function NS.ClearNativeWorldOverlay()
    ClearNativeNavigationHost()
    ClearResolvedHostTarget()
    ResetModeTransition("hidden")
    target.active = false
    target.uid = nil
    target.mapID = nil
    target.x = nil
    target.y = nil
    target.title = nil
    target.source = nil
    target.kind = nil
    target.sig = nil
    target.contentSig = nil
    target.contentSnapshot = nil
    overlay.hovered = false
    derived.distance = nil
    derived.mode = "hidden"
    derived.clamped = false
    derived.navFrame = nil
    derived.anchorFrame = nil
    derived.anchorX = nil
    derived.anchorY = nil
    overlay.navigatorClampActive = false
    overlay.lastAnchorX = nil
    overlay.lastAnchorY = nil
    overlay.pendingMode = nil
    overlay.pendingModeSince = 0
    overlay.pendingModeSig = nil
    overlay.arrivalHideActive = false
    overlay.contentDirty = true
    M.frameCacheDirty = true
    overlay.lastContentRefresh = 0
    overlay.cachedIconSpec = nil
    overlay.cachedPinpointSubtext = nil
    overlay.contentSnapshot = nil
    overlay.navFadeAlpha = 0
    overlay.navFadeState = "hidden"
    overlay.updateElapsed = 0
    ResetFrameTextCaches()
    ResetArrivalState()
    if not overlay.root then
        return
    end
    HideAllFrames()
    if overlay.driver then
        overlay.driver:Hide()
    end
    overlay.root:Hide()
    ApplySuperTrackedFrameVisibility()
end

function NS.SyncNativeWorldOverlay(uid, mapID, x, y, title, source, kind, contentSnapshot)
    EnsureDriverRoot()
    ApplyOverlayAdornmentStyleToAll()
    local nextSig = uid ~= nil and type(mapID) == "number" and type(x) == "number" and type(y) == "number" and Signature(mapID, x, y) or nil
    local sigChanged = nextSig ~= target.sig
    local normalizedTitle = NormalizeText(title) or title
    local nextContentSig = type(contentSnapshot) == "table" and contentSnapshot.contentSig or nil
    local targetChanged = sigChanged
        or normalizedTitle ~= target.title
        or source ~= target.source
        or kind ~= target.kind
    local contentChanged = nextContentSig ~= target.contentSig
    if targetChanged then
        if sigChanged and nextSig ~= nil
            and type(overlay.lastSpecialTravelSig) == "string"
            and overlay.lastSpecialTravelSig ~= nextSig
        then
            -- Release old special-travel hysteresis when the overlay has already
            -- moved on to a different target.
            overlay.lastSpecialTravelAt = 0
            overlay.lastSpecialTravelSig = nil
        end
        ResetModeTransition(derived.mode)
        overlay.navigatorClampActive = false
        overlay.lastAnchorX = nil
        overlay.lastAnchorY = nil
        overlay.pendingMode = nil
        overlay.pendingModeSince = 0
        overlay.pendingModeSig = nil
        overlay.arrivalHideActive = false
        overlay.lastLogSig = nil
        overlay.lastLogMode = nil
        overlay.lastLogReason = nil
        overlay.contentDirty = true
        M.frameCacheDirty = true
        M.cachedDistance = nil
        M.cachedDistanceTime = 0
        if sigChanged then
            derived.mode = "hidden"
        end
        ResetFrameTextCaches()
    end
    if contentChanged then
        overlay.contentDirty = true
        M.frameCacheDirty = true
        ResetFrameTextCaches()
    end
    target.active = uid ~= nil and type(mapID) == "number" and type(x) == "number" and type(y) == "number"
    target.uid = uid
    target.mapID = mapID
    target.x = x
    target.y = y
    target.title = normalizedTitle
    target.source = source
    target.kind = kind
    target.sig = nextSig
    target.contentSig = nextContentSig
    target.contentSnapshot = contentSnapshot
    overlay.contentSnapshot = contentSnapshot
    if target.active then
        if sigChanged or overlay.resolvedHostTargetSig ~= target.sig then
            RefreshResolvedHostTarget(true)
        end
    else
        ClearResolvedHostTarget()
    end
    overlay.hovered = false
    overlay.updateElapsed = 0
    if overlay.driver then
        if target.active then
            overlay.driver:Show()
        else
            overlay.driver:Hide()
        end
    end
    if target.active and targetChanged and not IsNativeSpecialTravelSuppressed() then
        EnsureNativeNavigationHost()
    end
    NS.UpdateNativeWorldOverlay()
end

function NS.RefreshNativeWorldOverlay()
    if not target.active then
        NS.ClearNativeWorldOverlay()
        return
    end
    EnsureDriverRoot()
    ApplyOverlayAdornmentStyleToAll()
    overlay.updateElapsed = 0
    if overlay.driver and not overlay.driver:IsShown() then
        overlay.driver:Show()
    end
    overlay.contentDirty = true
    M.frameCacheDirty = true
    if not IsNativeSpecialTravelSuppressed() then
        EnsureNativeNavigationHost()
    end
    NS.UpdateNativeWorldOverlay()
end

function NS.UpdateNativeWorldOverlay()
    if not target.active then
        NS.ClearNativeWorldOverlay()
        return
    end
    EnsureDriverRoot()
    RefreshSettingsSnapshot()
    ApplyOverlayAdornmentStyleToAll()
    if M.frameCacheDirty then
        InvalidateFrameCacheEntry("waypoint")
        InvalidateFrameCacheEntry("pinpoint")
        InvalidateFrameCacheEntry("navigator")
        M.frameCacheDirty = false
    end
    local prevMode = derived.mode
    local rawMode = ResolveMode()
    local now = GetTime()
    local mode

    if overlay.pendingMode and overlay.pendingModeSig ~= target.sig then
        overlay.pendingMode = nil
        overlay.pendingModeSince = 0
        overlay.pendingModeSig = nil
    end

    if rawMode == prevMode then
        overlay.pendingMode = nil
        overlay.pendingModeSince = 0
        overlay.pendingModeSig = nil
        mode = rawMode
    elseif rawMode == "hidden" or prevMode == "hidden" then
        overlay.pendingMode = nil
        overlay.pendingModeSince = 0
        overlay.pendingModeSig = nil
        mode = rawMode
    elseif rawMode == overlay.pendingMode then
        local key = prevMode .. "->" .. rawMode
        local window = MODE_CONFIRM_WINDOW[key] or 0
        if window <= 0 or (now - (overlay.pendingModeSince or 0)) >= window then
            overlay.pendingMode = nil
            overlay.pendingModeSince = 0
            overlay.pendingModeSig = nil
            mode = rawMode
        else
            mode = prevMode
        end
    else
        overlay.pendingMode = rawMode
        overlay.pendingModeSince = now
        overlay.pendingModeSig = target.sig
        mode = prevMode
    end

    derived.mode = mode
    if mode ~= prevMode then
        local isNavWaypoint = (prevMode == "navigator" and mode == "waypoint")
            or (prevMode == "waypoint" and mode == "navigator")
        local isWaypointPinpoint = IsWaypointPinpointTransition(prevMode, mode)

        if isNavWaypoint then
            InvalidateFrameVisualsOnly("waypoint")
            InvalidateFrameVisualsOnly("navigator")
        elseif isWaypointPinpoint then
            InvalidateFrameVisualsOnly("waypoint")
            InvalidateFrameVisualsOnly("pinpoint")
        else
            InvalidateFrameCacheEntry("waypoint")
            InvalidateFrameCacheEntry("pinpoint")
            InvalidateFrameCacheEntry("navigator")
        end

        if isWaypointPinpoint then
            StartModeTransition(prevMode, mode)
        else
            ResetModeTransition(mode)
        end
    end
    if mode == "hidden" then
        ResetModeTransition("hidden")
        derived.navFrame = nil
        derived.anchorFrame = nil
        derived.anchorX = nil
        derived.anchorY = nil
        HideAllFrames()
        overlay.root:Hide()
        ApplySuperTrackedFrameVisibility()
        return
    end

    EnsureActiveModeFrames(mode, prevMode)

    RefreshNativeOverlayContent(false)
    local iconSpec = overlay.cachedIconSpec or CONFIG.ICON_SPECS.guide
    local pinpointSubtext = overlay.cachedPinpointSubtext
    if transition.active then
        if transition.fromMode == "waypoint" or transition.toMode == "waypoint" then
            UpdateWaypointFrame(iconSpec, target.title)
        end
        if transition.fromMode == "pinpoint" or transition.toMode == "pinpoint" then
            UpdatePinpointFrame(iconSpec, target.title, pinpointSubtext)
        end
        RenderNativeOverlayVisuals(0)
        ApplySuperTrackedFrameVisibility()
        return
    end

    if mode == "waypoint" then
        UpdateWaypointFrame(iconSpec, target.title)
        RenderNativeOverlayVisuals(0)
        ApplySuperTrackedFrameVisibility()
        return
    end

    if mode == "pinpoint" then
        UpdatePinpointFrame(iconSpec, target.title, pinpointSubtext)
        RenderNativeOverlayVisuals(0)
        ApplySuperTrackedFrameVisibility()
        return
    end

    if mode == "navigator" then
        UpdateNavigatorFrame(iconSpec)
        ResetModeTransition("navigator")
        RenderNativeOverlayVisuals(0)
        ApplySuperTrackedFrameVisibility()
        return
    end

    ApplySuperTrackedFrameVisibility()
end

function NS.UpdateNativeOverlayVisuals(elapsed)
    if not target.active and not transition.active then
        return
    end
    RefreshSettingsSnapshot()
    RenderNativeOverlayVisuals(elapsed or 0)
end

-- Swaps the pinpoint plaque in-place without creating or orphaning any frames.
-- Safe to call at runtime (e.g. from the options panel setter).
function NS.SwapNativePinpointPlaque(plaqueType)
    if M.SwapPinpointPlaqueType then
        M.SwapPinpointPlaqueType(plaqueType)
    end
end
