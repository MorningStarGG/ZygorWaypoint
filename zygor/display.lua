local NS = _G.ZygorWaypointNS
local state = NS.State

local GetZygorPointer = NS.GetZygorPointer
local GetArrowFrame = NS.GetArrowFrame
local NormalizeWaypointTitle = NS.NormalizeWaypointTitle
local Signature = NS.Signature
local GetWaypointKind = NS.GetWaypointKind
local IsBlankText = NS.IsBlankText
local ReadWaypointCoords = NS.ReadWaypointCoords

---@class ZWPZygorDisplaySnapshot
---@field frameVisible boolean
---@field textVisible boolean
---@field title string|nil
---@field desc string|nil
---@field label string|nil
---@field specialMode string|nil
---@field waypoint table|nil
---@field kind string
---@field source string|nil
---@field map number|nil
---@field x number|nil
---@field y number|nil
---@field sig string|nil
---@field epoch number

---@class ZWPZygorDisplayTarget
---@field visible boolean
---@field title string|nil
---@field kind string
---@field source string|nil
---@field map number|nil
---@field x number|nil
---@field y number|nil
---@field sig string|nil

---@class ZWPZygorDisplayState
---@field snapshot ZWPZygorDisplaySnapshot
---@field target ZWPZygorDisplayTarget
---@field hooksInstalled boolean
---@field hookedArrowFrame table|nil
---@field syncQueued boolean

-- ============================================================
-- State initialization
-- ============================================================

state.zygorDisplay = state.zygorDisplay or {
    snapshot = {
        frameVisible = false,
        textVisible = false,
        title = nil,
        desc = nil,
        label = nil,
        specialMode = nil,
        waypoint = nil,
        kind = "none",
        source = nil,
        map = nil,
        x = nil,
        y = nil,
        sig = nil,
        epoch = 0,
    },
    target = {
        visible = false,
        title = nil,
        kind = "none",
        source = nil,
        map = nil,
        x = nil,
        y = nil,
        sig = nil,
    },
    hooksInstalled = false,
    hookedArrowFrame = nil,
    syncQueued = false,
}

local display = state.zygorDisplay
local snapshot = display.snapshot
local target = display.target
local HookArrowFrameWakeups

-- ============================================================
-- Internal helpers
-- ============================================================

local function normalizeText(value)
    return NormalizeWaypointTitle(value)
end

local _trimCacheInput1, _trimCacheResult1
local _trimCacheInput2, _trimCacheResult2

local function trimText(value)
    if value == nil then
        return
    end

    if value == _trimCacheInput1 then return _trimCacheResult1 end
    if value == _trimCacheInput2 then return _trimCacheResult2 end

    local raw = tostring(value)
    raw = raw:gsub("[\r\n]+", " ")
    raw = raw:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "")
    raw = raw:gsub("%s+", " "):gsub("^%s+", ""):gsub("%s+$", "")
    local text = raw ~= "" and raw or nil

    _trimCacheInput2 = _trimCacheInput1
    _trimCacheResult2 = _trimCacheResult1
    _trimCacheInput1 = value
    _trimCacheResult1 = text
    return text
end

local function IsTextBlank(value)
    return IsBlankText(value)
end

local function readFrameText(frameRegion)
    if not frameRegion or type(frameRegion.GetText) ~= "function" then
        return
    end

    local rawText = trimText(frameRegion:GetText())
    if not rawText then
        return
    end

    return normalizeText(rawText) or rawText
end

local function detectWaypointSource(pointer, arrowFrame, waypoint)
    if type(waypoint) ~= "table" or type(pointer) ~= "table" then
        return
    end

    if arrowFrame and arrowFrame.waypoint == waypoint then
        return "pointer.ArrowFrame.waypoint"
    end
    if pointer.arrow and pointer.arrow.waypoint == waypoint then
        return "pointer.arrow.waypoint"
    end
    if pointer.DestinationWaypoint == waypoint then
        return "pointer.DestinationWaypoint"
    end
    if pointer.waypoint == waypoint then
        return "pointer.waypoint"
    end
    if pointer.current_waypoint == waypoint then
        return "pointer.current_waypoint"
    end
    if type(pointer.waypoints) == "table" and pointer.waypoints[1] == waypoint then
        return "pointer.waypoints[1]"
    end
end

local function ResetDisplayTarget()
    local changed = target.visible or target.title ~= nil or target.map ~= nil or target.x ~= nil or target.y ~= nil
        or target.source ~= nil or target.sig ~= nil or target.kind ~= "none"
    target.visible = false
    target.title = nil
    target.kind = "none"
    target.source = nil
    target.map = nil
    target.x = nil
    target.y = nil
    target.sig = nil
    return changed
end

local function UpdateDisplayTarget(textVisible, label, mapID, x, y, kind, source, sig)
    if not textVisible or IsTextBlank(label) then
        return ResetDisplayTarget()
    end

    local hasCoords = type(mapID) == "number" and type(x) == "number" and type(y) == "number"
    local nextVisible = hasCoords or target.visible
    local nextTitle = label
    local nextKind = hasCoords and (kind or "guide") or target.kind
    local nextSource = hasCoords and source or target.source
    local nextMap = hasCoords and mapID or target.map
    local nextX = hasCoords and x or target.x
    local nextY = hasCoords and y or target.y
    local nextSig = hasCoords and sig or target.sig

    if IsTextBlank(nextTitle) then
        nextTitle = target.title
    end

    if not (nextVisible and nextTitle and nextMap and nextX and nextY and nextSource and nextKind and nextSig) then
        return ResetDisplayTarget()
    end

    local changed = target.visible ~= true
        or target.title ~= nextTitle
        or target.kind ~= nextKind
        or target.source ~= nextSource
        or target.map ~= nextMap
        or target.x ~= nextX
        or target.y ~= nextY
        or target.sig ~= nextSig

    target.visible = true
    target.title = nextTitle
    target.kind = nextKind
    target.source = nextSource
    target.map = nextMap
    target.x = nextX
    target.y = nextY
    target.sig = nextSig
    return changed
end

-- ============================================================
-- Display sync
-- ============================================================

function NS.SyncZygorDisplayState()
    local _, pointer, arrowFrame = GetArrowFrame()
    if not pointer then
        _, pointer = GetZygorPointer()
        arrowFrame = pointer and pointer.ArrowFrame or nil
    end

    if arrowFrame and display.hookedArrowFrame ~= arrowFrame then
        HookArrowFrameWakeups(arrowFrame)
    end

    local frameVisible = arrowFrame and type(arrowFrame.IsShown) == "function" and arrowFrame:IsShown() or false
    local visibleArrowFrame = frameVisible and arrowFrame or nil
    local title = visibleArrowFrame and readFrameText(visibleArrowFrame.title) or nil
    -- Zygor's desc text can change every movement tick (distance/time) while the
    -- title stays semantically stable. Avoid normalizing desc unless it is actually
    -- needed as the visible label fallback.
    local desc = (visibleArrowFrame and not title) and readFrameText(visibleArrowFrame.desc) or nil
    local label = title or desc
    local textVisible = frameVisible and not IsTextBlank(label)
    local specialMode = visibleArrowFrame and visibleArrowFrame.specialmode or nil
    local waypoint = visibleArrowFrame and visibleArrowFrame.waypoint or nil
    local source = detectWaypointSource(pointer, arrowFrame, waypoint)
    local kind = GetWaypointKind(waypoint, source) or "none"
    local mapID, x, y = ReadWaypointCoords(waypoint)
    local sig = (mapID and x and y) and Signature(mapID, x, y) or nil

    local snapshotChanged = snapshot.frameVisible ~= frameVisible
        or snapshot.textVisible ~= textVisible
        or snapshot.title ~= title
        or snapshot.desc ~= desc
        or snapshot.label ~= label
        or snapshot.specialMode ~= specialMode
        or snapshot.waypoint ~= waypoint
        or snapshot.kind ~= kind
        or snapshot.source ~= source
        or snapshot.map ~= mapID
        or snapshot.x ~= x
        or snapshot.y ~= y
        or snapshot.sig ~= sig

    if snapshotChanged then
        snapshot.epoch = snapshot.epoch + 1
    end

    snapshot.frameVisible = frameVisible
    snapshot.textVisible = textVisible
    snapshot.title = title
    snapshot.desc = desc
    snapshot.label = label
    snapshot.specialMode = specialMode
    snapshot.waypoint = waypoint
    snapshot.kind = kind or "none"
    snapshot.source = source
    snapshot.map = mapID
    snapshot.x = x
    snapshot.y = y
    snapshot.sig = sig

    local targetChanged = UpdateDisplayTarget(textVisible, label, mapID, x, y, kind, source, sig)
    return snapshotChanged or targetChanged, targetChanged
end

function NS.GetZygorDisplayState()
    return display
end

local function RunQueuedBridgeSync()
    display.syncQueued = false

    local snapshotChanged, targetChanged = NS.SyncZygorDisplayState()
    if (snapshotChanged or targetChanged) and type(NS.TickUpdate) == "function" then
        NS.TickUpdate()
    end
end

local function TriggerBridgeSync()
    if display.syncQueued then
        return
    end

    display.syncQueued = true
    NS.After(0, RunQueuedBridgeSync)
end

-- ============================================================
-- Hook setup
-- ============================================================

HookArrowFrameWakeups = function(arrowFrame)
    if not arrowFrame or display.hookedArrowFrame == arrowFrame then
        return
    end

    if type(arrowFrame.HookScript) == "function" then
        arrowFrame:HookScript("OnShow", TriggerBridgeSync)
        arrowFrame:HookScript("OnHide", TriggerBridgeSync)
    end

    display.hookedArrowFrame = arrowFrame
end

function NS.HookZygorDisplayState()
    local _, pointer, arrowFrame = GetArrowFrame()
    if not pointer then
        return
    end

    if not display.hooksInstalled then
        if type(pointer.ShowArrow) == "function" then
            hooksecurefunc(pointer, "ShowArrow", TriggerBridgeSync)
        end
        if type(pointer.HideArrow) == "function" then
            hooksecurefunc(pointer, "HideArrow", TriggerBridgeSync)
        end
        if type(pointer.ClearWaypoints) == "function" then
            hooksecurefunc(pointer, "ClearWaypoints", TriggerBridgeSync)
        end
        if type(pointer.SetCorpseArrow) == "function" then
            hooksecurefunc(pointer, "SetCorpseArrow", TriggerBridgeSync)
        end
        if type(pointer.FindTravelPath) == "function" then
            hooksecurefunc(pointer, "FindTravelPath", TriggerBridgeSync)
        end
        if type(pointer.UpdateArrowVisibility) == "function" then
            hooksecurefunc(pointer, "UpdateArrowVisibility", TriggerBridgeSync)
        end
        if type(pointer.UpdatePointer) == "function" then
            hooksecurefunc(pointer, "UpdatePointer", TriggerBridgeSync)
        end
        if type(pointer.SetWaypoint) == "function" then
            hooksecurefunc(pointer, "SetWaypoint", TriggerBridgeSync)
        end
        if type(pointer.SetArrowSkin) == "function" then
            hooksecurefunc(pointer, "SetArrowSkin", function()
                display.hookedArrowFrame = nil
                NS.After(0, NS.HookZygorDisplayState)
                NS.After(0, TriggerBridgeSync)
            end)
        end

        display.hooksInstalled = true
    end

    HookArrowFrameWakeups(arrowFrame)
    NS.SyncZygorDisplayState()
end

function NS.IsZygorDisplayTextVisible()
    return snapshot.textVisible == true
end
