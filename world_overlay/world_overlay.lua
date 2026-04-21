local NS = _G.ZygorWaypointNS
local C = NS.Constants
local state = NS.State

---@class ZWPWorldOverlayState
---@field backend string
---@field uid table|nil
---@field mapID number|nil
---@field x number|nil
---@field y number|nil
---@field title string|nil
---@field source string|nil
---@field kind string|nil
---@field contentSnapshot table|nil

-- ============================================================
-- State initialization
-- ============================================================

state.worldOverlay = state.worldOverlay or {
    backend = C.WORLD_OVERLAY_BACKEND_NONE,
    uid = nil,
    mapID = nil,
    x = nil,
    y = nil,
    title = nil,
    source = nil,
    kind = nil,
    contentSnapshot = nil,
}

local overlay = state.worldOverlay

-- ============================================================
-- Internal helpers
-- ============================================================

local function ResolveBackend()
    if not NS.IsWorldOverlayEnabled() then
        return C.WORLD_OVERLAY_BACKEND_NONE
    end

    return C.WORLD_OVERLAY_BACKEND_NATIVE
end

local function ClearNativeBackend()
    NS.ClearNativeWorldOverlay()
end

local function ApplyCurrentTarget()
    local backend = ResolveBackend()
    if overlay.backend ~= backend then
        if overlay.backend == C.WORLD_OVERLAY_BACKEND_NATIVE then
            ClearNativeBackend()
        end
        overlay.backend = backend
    end

    if backend == C.WORLD_OVERLAY_BACKEND_NONE then
        ClearNativeBackend()
        return
    end

    if not (overlay.uid and overlay.mapID and overlay.x and overlay.y) then
        if backend == C.WORLD_OVERLAY_BACKEND_NATIVE then
            ClearNativeBackend()
        end
        return
    end

    if backend == C.WORLD_OVERLAY_BACKEND_NATIVE then
        NS.InitializeNativeWorldOverlay()
        NS.SyncNativeWorldOverlay(
            overlay.uid,
            overlay.mapID,
            overlay.x,
            overlay.y,
            overlay.title,
            overlay.source,
            overlay.kind,
            overlay.contentSnapshot
        )
    end
end

-- ============================================================
-- Public API
-- ============================================================

function NS.GetWorldOverlayBackend()
    return ResolveBackend()
end

function NS.InitializeWorldOverlay()
    overlay.backend = ResolveBackend()
    if overlay.backend == C.WORLD_OVERLAY_BACKEND_NATIVE then
        NS.InitializeNativeWorldOverlay()
    else
        ClearNativeBackend()
    end
end

function NS.RefreshWorldOverlay()
    local churn = NS.State.churn
    if churn.active then
        churn.refreshWorldOverlay = churn.refreshWorldOverlay + 1
    end
    ApplyCurrentTarget()
end

function NS.SyncWorldOverlay(uid, mapID, x, y, title, source, kind, contentSnapshot)
    overlay.uid = uid
    overlay.mapID = mapID
    overlay.x = x
    overlay.y = y
    overlay.title = title
    overlay.source = source
    overlay.kind = kind
    overlay.contentSnapshot = contentSnapshot
    ApplyCurrentTarget()
end

function NS.ClearWorldOverlay()
    overlay.uid = nil
    overlay.mapID = nil
    overlay.x = nil
    overlay.y = nil
    overlay.title = nil
    overlay.source = nil
    overlay.kind = nil
    overlay.contentSnapshot = nil
    ApplyCurrentTarget()
end
