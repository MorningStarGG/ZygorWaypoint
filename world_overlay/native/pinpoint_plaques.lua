local NS  = _G.ZygorWaypointNS
local C   = NS.Constants
local M   = NS.Internal.WorldOverlayNative
local ROOT_PATH = "Interface\\AddOns\\ZygorWaypoint\\media\\world-overlay\\"
local FALLBACK_PLAQUE_TYPE = C.WORLD_OVERLAY_PLAQUE_DEFAULT or "GlowingGems"

-- ============================================================
-- Plaque spec registry
--
-- Each entry is fully self-contained: its own BLP texture path,
-- its own per-side source corner pixel regions, and its own
-- display slice sizes. Adding a new plaque type is one new key.
-- No values are shared or inherited between types.
-- ============================================================

local PLAQUE_SPECS = {

    GlowingGems = {
        -- ── Texture ──────────────────────────────────────────────────────
        -- Each plaque owns its own .blp/.png file. The WoW engine resolves
        -- .blp with .png fallback automatically.
        texture = ROOT_PATH .. "waypoint\\GlowingGemsPlaque",
        texW    = 512,  -- source atlas width  (px)
        texH    = 256,  -- source atlas height (px)

        -- ── Source corner regions (pixels inside the BLP) ─────────────────
        -- How many source pixels belong to each corner region. Pixels between
        -- corners form the stretchable edge and center bands. All four sides
        -- are set independently to support asymmetric artwork (e.g. a thicker
        -- left border or flared bottom edge).
        srcCornerL = 96,    -- from left edge
        srcCornerR = 96,    -- from right edge
        srcCornerT = 72,    -- from top edge
        srcCornerB = 72,    -- from bottom edge

        -- ── Display slice sizes (screen pixels) ───────────────────────────
        -- How large each corner piece renders on screen. Corners use SetSize()
        -- with these values — they are ALWAYS fixed, NEVER stretch. Each side
        -- is independent; a plaque with a thicker bottom just has a larger sliceB.
        sliceL = 36,
        sliceT = 28,
        sliceR = 36,
        sliceB = 28,

        -- ── Initial panel frame sizing ────────────────────────────────────
        -- Starting dimensions. LayoutPinpointText in frames.lua can resize
        -- the panel dynamically once text content is known.
        minW        = 140,  -- minimum width
        baseH       = 72,   -- base height
        maxH        = 96,
        wrapW       = 196,
        maxW        = 224,
        heightRatio = 0.28,
    },

    HordePlaque = {
        texture = ROOT_PATH .. "waypoint\\HordePlaque",
        texW    = 512,
        texH    = 256,

        srcCornerL = 88,
        srcCornerR = 88,
        srcCornerT = 90,
        srcCornerB = 90,

        sliceL = 33,
        sliceT = 35,
        sliceR = 33,
        sliceB = 35,

        minW       = 160,
        baseH      = 90,
        maxH       = 110,
        wrapW      = 196,
        maxW       = 224,
        heightRatio = 0.28,
    },

    AlliancePlaque = {
        texture = ROOT_PATH .. "waypoint\\AlliancePlaque",
        texW    = 512,
        texH    = 256,

        srcCornerL = 112,
        srcCornerR = 112,
        srcCornerT = 74,
        srcCornerB = 74,

        sliceL = 42,
        sliceT = 30,
        sliceR = 42,
        sliceB = 30,

        minW       = 160,
        baseH      = 80,
        maxH       = 110,
        wrapW      = 196,
        maxW       = 244,
        heightRatio = 0.28,
    },

    Default = {
        texture = ROOT_PATH .. "waypoint\\BasicFantasyPlaque",
        texW    = 512,
        texH    = 256,

        srcCornerL = 80,
        srcCornerR = 80,
        srcCornerT = 60,
        srcCornerB = 60,

        sliceL = 30,
        sliceT = 24,
        sliceR = 30,
        sliceB = 24,

        minW        = 100,
        baseH       = 62,
        maxH        = 96,
        wrapW       = 196,
        maxW        = 224,
        heightRatio = 0.28,
    },

    ModernPlaque = {
        texture = ROOT_PATH .. "waypoint\\ModernPlaque",
        texW    = 512,
        texH    = 256,

        srcCornerL = 80,
        srcCornerR = 80,
        srcCornerT = 56,
        srcCornerB = 56,

        sliceL = 30,
        sliceT = 21,
        sliceR = 30,
        sliceB = 21,

        minW        = 100,
        baseH       = 68,
        maxH        = 96,
        wrapW       = 196,
        maxW        = 224,
        heightRatio = 0.28,
    },

    SteamPunkPlaque = {
        texture = ROOT_PATH .. "waypoint\\SteamPunkPlaque",
        texW    = 512,
        texH    = 256,

        srcCornerL = 112,
        srcCornerR = 112,
        srcCornerT = 88,
        srcCornerB = 88,

        sliceL = 42,
        sliceT = 34,
        sliceR = 42,
        sliceB = 34,

        minW        = 100,
        baseH       = 86,
        maxH        = 112,
        wrapW       = 196,
        maxW        = 234,  -- slightly more than some due to bulky sides
        heightRatio = 0.28,

        -- SteamPunk has visually heavier side assemblies than the other plaques,
        -- so its text host needs a larger horizontal inset than the global default.
        textInsetX   = 20,  -- default is 16
        textPaddingX = 28,  -- kept default here
    },
}

-- ============================================================
-- Internal helpers (module-local, not exported)
-- ============================================================

local function ConfigurePinpointTextureSampling(texture)
    if not texture then
        return
    end

    texture:SetTexelSnappingBias(0)
    texture:SetSnapToPixelGrid(false)
end

local function SetCompositeVertexColor(self, r, g, b, a)
    local textures = self and self.__zwpTextures or nil
    if type(textures) ~= "table" then
        return
    end

    for _, texture in ipairs(textures) do
        texture:SetVertexColor(r or 1, g or 1, b or 1, a or 1)
    end
end

-- Creates a single texture from an atlas, normalizing UVs against the
-- caller-supplied texW/texH so each plaque's own BLP dimensions are used.
local function CreateAtlasTexture(parent, texW, texH, atlasTexture, drawLayer, blendMode, srcL, srcR, srcT, srcB)
    local texture = parent:CreateTexture(nil, drawLayer)
    texture:SetTexture(atlasTexture)
    texture:SetTexCoord(
        srcL / texW,
        srcR / texW,
        srcT / texH,
        srcB / texH
    )
    ConfigurePinpointTextureSampling(texture)
    if blendMode then
        texture:SetBlendMode(blendMode)
    end
    return texture
end

-- Builds a 9-slice composite frame from spec geometry.
-- Corner source regions are derived independently per side, so
-- asymmetric BLP layouts (different left vs right corner widths) work correctly.
-- Corners use SetSize() — always fixed, never distorted.
-- Edges stretch along one axis via paired SetPoint anchors.
-- Center fills all remaining space via four SetPoint anchors.
-- If cornersOnly==true, only the four fixed corner pieces are created.
local function CreateCompositeLayer(parent, spec, drawLayer, blendMode, cornersOnly)
    local layer = CreateFrame("Frame", nil, parent)
    layer.__zwpTextures = {}
    layer.SetVertexColor = SetCompositeVertexColor

    local texW    = spec.texW
    local texH    = spec.texH
    local texture = spec.texture

    -- Source corner boundaries derived independently per side.
    local sourceL = spec.srcCornerL                  -- left corner ends here
    local sourceR = texW - spec.srcCornerR            -- right corner begins here
    local sourceT = spec.srcCornerT                  -- top corner ends here
    local sourceB = texH - spec.srcCornerB            -- bottom corner begins here

    local function addTexture(name, srcL, srcR, srcT, srcB)
        local tex = CreateAtlasTexture(layer, texW, texH, texture, drawLayer, blendMode, srcL, srcR, srcT, srcB)
        layer[name] = tex
        layer.__zwpTextures[#layer.__zwpTextures + 1] = tex
        return tex
    end

    -- ── Corners (FIXED size, single anchor, NEVER stretch) ────────────────

    local topLeft = addTexture("TopLeft", 0, sourceL, 0, sourceT)
    topLeft:SetSize(spec.sliceL, spec.sliceT)
    topLeft:SetPoint("TOPLEFT")

    local topRight = addTexture("TopRight", sourceR, texW, 0, sourceT)
    topRight:SetSize(spec.sliceR, spec.sliceT)
    topRight:SetPoint("TOPRIGHT")

    local bottomLeft = addTexture("BottomLeft", 0, sourceL, sourceB, texH)
    bottomLeft:SetSize(spec.sliceL, spec.sliceB)
    bottomLeft:SetPoint("BOTTOMLEFT")

    local bottomRight = addTexture("BottomRight", sourceR, texW, sourceB, texH)
    bottomRight:SetSize(spec.sliceR, spec.sliceB)
    bottomRight:SetPoint("BOTTOMRIGHT")

    if cornersOnly then
        return layer
    end

    -- ── Edges (stretch ONE axis, fixed on the other) ──────────────────────

    local top = addTexture("Top", sourceL, sourceR, 0, sourceT)
    top:SetPoint("TOPLEFT",  layer, "TOPLEFT",  spec.sliceL,  0)
    top:SetPoint("TOPRIGHT", layer, "TOPRIGHT", -spec.sliceR, 0)
    top:SetHeight(spec.sliceT)

    local bottom = addTexture("Bottom", sourceL, sourceR, sourceB, texH)
    bottom:SetPoint("BOTTOMLEFT",  layer, "BOTTOMLEFT",  spec.sliceL,  0)
    bottom:SetPoint("BOTTOMRIGHT", layer, "BOTTOMRIGHT", -spec.sliceR, 0)
    bottom:SetHeight(spec.sliceB)

    local left = addTexture("Left", 0, sourceL, sourceT, sourceB)
    left:SetPoint("TOPLEFT",    layer, "TOPLEFT",    0, -spec.sliceT)
    left:SetPoint("BOTTOMLEFT", layer, "BOTTOMLEFT", 0,  spec.sliceB)
    left:SetWidth(spec.sliceL)

    local right = addTexture("Right", sourceR, texW, sourceT, sourceB)
    right:SetPoint("TOPRIGHT",    layer, "TOPRIGHT",    0, -spec.sliceT)
    right:SetPoint("BOTTOMRIGHT", layer, "BOTTOMRIGHT", 0,  spec.sliceB)
    right:SetWidth(spec.sliceR)

    -- ── Center (fills all remaining space freely) ─────────────────────────

    local center = addTexture("Center", sourceL, sourceR, sourceT, sourceB)
    center:SetPoint("TOPLEFT",     layer, "TOPLEFT",     spec.sliceL,  -spec.sliceT)
    center:SetPoint("BOTTOMRIGHT", layer, "BOTTOMRIGHT", -spec.sliceR,  spec.sliceB)

    return layer
end

-- ============================================================
-- Public API
-- ============================================================

M.Plaques = {

    -- Creates and returns a 9-slice panel frame sized to spec.minW × spec.baseH.
    -- The panel has:
    --   panel.__zwpTextures       — all 9 texture pieces (for iterative tinting)
    --   panel.SetVertexColor      — tints all 9 pieces together
    --   panel.TopLeft/TopRight/BottomLeft/BottomRight/Top/Bottom/Left/Right/Center
    CreatePanel = function(parent, plaqueType)
        local resolvedPlaqueType = plaqueType or FALLBACK_PLAQUE_TYPE
        local spec  = PLAQUE_SPECS[resolvedPlaqueType] or PLAQUE_SPECS[FALLBACK_PLAQUE_TYPE] or PLAQUE_SPECS["GlowingGems"]
        local panel = CreateCompositeLayer(parent, spec, "BACKGROUND", nil, false)
        panel.__zwpPlaqueType = resolvedPlaqueType
        panel.__zwpPlaqueSpec = spec
        panel:SetSize(spec.minW, spec.baseH)
        return panel
    end,

    -- Updates an existing panel's textures, UVs, sizes, and anchor positions
    -- in-place to match a new plaque type. No new frames or textures are created;
    -- the existing named sub-texture objects (panel.TopLeft etc.) are modified.
    -- Call this instead of CreatePanel when swapping the plaque type at runtime.
    UpdatePanel = function(panel, plaqueType)
        if not panel then return end
        local resolvedPlaqueType = plaqueType or FALLBACK_PLAQUE_TYPE
        local spec    = PLAQUE_SPECS[resolvedPlaqueType] or PLAQUE_SPECS[FALLBACK_PLAQUE_TYPE] or PLAQUE_SPECS["GlowingGems"]
        panel.__zwpPlaqueType = resolvedPlaqueType
        panel.__zwpPlaqueSpec = spec
        local texW    = spec.texW
        local texH    = spec.texH
        local texture = spec.texture

        local sourceL = spec.srcCornerL
        local sourceR = texW - spec.srcCornerR
        local sourceT = spec.srcCornerT
        local sourceB = texH - spec.srcCornerB

        local function applyUV(tex, srcL, srcR, srcT, srcB)
            tex:SetTexture(texture)
            tex:SetTexCoord(srcL / texW, srcR / texW, srcT / texH, srcB / texH)
            ConfigurePinpointTextureSampling(tex)
        end

        -- Corners: update texture + UV + size; anchors are single-point (no ClearAllPoints needed)
        applyUV(panel.TopLeft,     0,       sourceL, 0,       sourceT)
        panel.TopLeft:SetSize(spec.sliceL, spec.sliceT)

        applyUV(panel.TopRight,    sourceR, texW,    0,       sourceT)
        panel.TopRight:SetSize(spec.sliceR, spec.sliceT)

        applyUV(panel.BottomLeft,  0,       sourceL, sourceB, texH)
        panel.BottomLeft:SetSize(spec.sliceL, spec.sliceB)

        applyUV(panel.BottomRight, sourceR, texW,    sourceB, texH)
        panel.BottomRight:SetSize(spec.sliceR, spec.sliceB)

        -- Edges: update texture + UV + size + paired anchors
        applyUV(panel.Top, sourceL, sourceR, 0, sourceT)
        panel.Top:ClearAllPoints()
        panel.Top:SetPoint("TOPLEFT",  panel, "TOPLEFT",  spec.sliceL,  0)
        panel.Top:SetPoint("TOPRIGHT", panel, "TOPRIGHT", -spec.sliceR, 0)
        panel.Top:SetHeight(spec.sliceT)

        applyUV(panel.Bottom, sourceL, sourceR, sourceB, texH)
        panel.Bottom:ClearAllPoints()
        panel.Bottom:SetPoint("BOTTOMLEFT",  panel, "BOTTOMLEFT",  spec.sliceL,  0)
        panel.Bottom:SetPoint("BOTTOMRIGHT", panel, "BOTTOMRIGHT", -spec.sliceR, 0)
        panel.Bottom:SetHeight(spec.sliceB)

        applyUV(panel.Left, 0, sourceL, sourceT, sourceB)
        panel.Left:ClearAllPoints()
        panel.Left:SetPoint("TOPLEFT",    panel, "TOPLEFT",    0, -spec.sliceT)
        panel.Left:SetPoint("BOTTOMLEFT", panel, "BOTTOMLEFT", 0,  spec.sliceB)
        panel.Left:SetWidth(spec.sliceL)

        applyUV(panel.Right, sourceR, texW, sourceT, sourceB)
        panel.Right:ClearAllPoints()
        panel.Right:SetPoint("TOPRIGHT",    panel, "TOPRIGHT",    0, -spec.sliceT)
        panel.Right:SetPoint("BOTTOMRIGHT", panel, "BOTTOMRIGHT", 0,  spec.sliceB)
        panel.Right:SetWidth(spec.sliceR)

        -- Center: update texture + UV + four-anchor fill
        applyUV(panel.Center, sourceL, sourceR, sourceT, sourceB)
        panel.Center:ClearAllPoints()
        panel.Center:SetPoint("TOPLEFT",     panel, "TOPLEFT",     spec.sliceL,  -spec.sliceT)
        panel.Center:SetPoint("BOTTOMRIGHT", panel, "BOTTOMRIGHT", -spec.sliceR,  spec.sliceB)

        -- Resize the panel frame itself to the new minimum dimensions
        panel:SetSize(spec.minW, spec.baseH)
    end,

    -- Returns the raw spec table for a plaque type.
    -- Used by plaque_animation.lua to read corner/slice geometry for gem
    -- display metric scaling without creating a circular dependency.
    GetSpec = function(plaqueType)
        return PLAQUE_SPECS[plaqueType] or PLAQUE_SPECS[FALLBACK_PLAQUE_TYPE] or PLAQUE_SPECS["GlowingGems"]
    end,
}
