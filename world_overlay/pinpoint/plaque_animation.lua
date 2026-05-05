local NS              = _G.AzerothWaypointNS
local M               = NS.Internal.WorldOverlay
local Plaques         = M.Plaques -- available: pinpoint_plaques.lua loads first
local ROOT_PATH       = "Interface\\AddOns\\AzerothWaypoint\\media\\world-overlay\\"
local PLAQUE_PATH     = ROOT_PATH .. "plaques\\"

-- ============================================================
-- Animation spec registry
--
-- Each plaque type has a list of animation descriptors. Each descriptor
-- has a "type" key that maps to a builder function in ANIMATION_BUILDERS.
-- An absent entry or empty table means no animations for that plaque.
--
-- Adding a new animation type:
--   1. Write a builder function: BuildMyType(parent, panelFrame, animSpec, plaqueType, result)
--   2. Register it:  ANIMATION_BUILDERS["my_type"] = BuildMyType
--   3. Add a descriptor to any plaque's list: { type = "my_type", … }
-- No other files need to change.
-- ============================================================

local ANIMATION_SPECS = {

    GlowingGems = {
        {
            -- Type "corner_gems": four corner textures placed at each panel corner,
            -- with optional glow overlays that pulse via render.lua.
            -- Gem textures use their own BLP (may differ from the panel BLP in path
            -- and dimensions); UVs are normalized against animSpec.texW/texH.
            type    = "corner_gems",
            texture = PLAQUE_PATH .. "GlowingGemsPlaque_Gems",
            texW    = 512,
            texH    = 256,
            srcL    = 20,
            srcT    = 18,
            srcW    = 32,
            srcH    = 30,

            -- Glow overlay centered on each gem, rendered in ARTWORK layer with ADD blend.
            -- nil = no glow for this animation entry.
            -- Pulse parameters live with this plaque's animation spec so callers
            -- can resolve fallback pulse behaviour without consulting config.lua.
            glow    = {
                texture   = ROOT_PATH .. "Glow",
                size      = 12,
                speed     = math.pi,
                amplitude = 0.15,
                base      = 0.15,
            },
        },
        -- Future animation types for this plaque can be appended here:
        -- { type = "edge_shimmer", texture = "…", … },
        -- { type = "title_glow",   texture = "…", … },
    },

    HordePlaque = {
        {
            type    = "full_overlay",
            texture = PLAQUE_PATH .. "HordePlaqueAnimation",
            pulse   = {
                speed = 3.5,
                amplitude = 0.30,
                base = 0.82,
            },
        },
    },

    AlliancePlaque = {
        {
            type    = "full_overlay",
            texture = PLAQUE_PATH .. "AlliancePlaqueAnimation",
            pulse   = {
                speed = 3.5,
                amplitude = 0.30,
                base = 0.82,
            },
        },
    },

    SteamPunkPlaque = {
        {
            type    = "full_overlay",
            texture = PLAQUE_PATH .. "SteamPunkPlaqueAnimation",
            pulse   = {
                speed = 3.5,
                amplitude = 0.30,
                base = 0.82,
            },
        },
    },

    -- Plaques without animations simply have no entry (or an empty table):
    -- ["rounded"] = {},
}

-- ============================================================
-- Internal helpers (module-local, not exported)
-- Note: these small utilities are duplicated from pinpoint_plaques.lua
-- intentionally — each file is self-contained, avoiding a shared dependency
-- on a third utility module for three ~5-line functions.
-- ============================================================

local function ConfigurePinpointTextureSampling(texture)
    if not texture then
        return
    end

    texture:SetTexelSnappingBias(0)
    texture:SetSnapToPixelGrid(false)
end

local function SetCompositeVertexColor(self, r, g, b, a)
    local textures = self and self.__awpTextures or nil
    if type(textures) ~= "table" then
        return
    end

    for _, texture in ipairs(textures) do
        texture:SetVertexColor(r or 1, g or 1, b or 1, a or 1)
    end
end

-- Creates a single texture from an atlas, normalizing UVs against texW/texH.
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

-- ============================================================
-- Animation type builders
-- ============================================================

-- Computes display dimensions and offsets for gems scaled to match the
-- plaque's actual rendered corner size. This ensures gems align correctly
-- regardless of the source resolution in the gem BLP.
local function GetGemDisplayMetrics(plaqueSpec, animSpec)
    local scaleX  = plaqueSpec.sliceL / plaqueSpec.srcCornerL
    local scaleY  = plaqueSpec.sliceT / plaqueSpec.srcCornerT
    local width   = math.max(1, math.floor((animSpec.srcW * scaleX) + 0.5))
    local height  = math.max(1, math.floor((animSpec.srcH * scaleY) + 0.5))
    local offsetX = math.floor((animSpec.srcL * scaleX) + 0.5)
    local offsetY = math.floor((animSpec.srcT * scaleY) + 0.5)
    return width, height, offsetX, offsetY
end

-- Builds four corner gem textures and optional glow textures.
-- Replaces CreatePinpointGems plus the inline GlowTL/TR/BL/BR block
-- that was previously in EnsurePinpointFrame.
--
-- Fills result with:
--   result.Gems         — gems frame (has __awpTextures, SetVertexColor,
--                         .TopLeft/.TopRight/.BottomLeft/.BottomRight)
--   result.GlowTL/TR/BL/BR — glow textures (nil if animSpec.glow is nil)
local function BuildCornerGems(parent, panelFrame, animSpec, plaqueType, result)
    local plaqueSpec = Plaques.GetSpec(plaqueType)
    if not plaqueSpec then
        return
    end

    local gems = CreateFrame("Frame", nil, panelFrame)
    gems:SetAllPoints(panelFrame)
    gems.__awpTextures                    = {}
    gems.SetVertexColor                   = SetCompositeVertexColor

    local width, height, offsetX, offsetY = GetGemDisplayMetrics(plaqueSpec, animSpec)

    local texW                            = animSpec.texW
    local texH                            = animSpec.texH
    local texture                         = animSpec.texture
    local srcL                            = animSpec.srcL
    local srcT                            = animSpec.srcT
    local srcR                            = srcL + animSpec.srcW
    local srcB                            = srcT + animSpec.srcH

    local function addGem(name, uvL, uvR, uvT, uvB, point, px, py)
        local tex = CreateAtlasTexture(gems, texW, texH, texture, "BORDER", "ADD", uvL, uvR, uvT, uvB)
        tex:SetSize(width, height)
        tex:SetPoint(point, gems, point, px, py)
        gems[name] = tex
        gems.__awpTextures[#gems.__awpTextures + 1] = tex
    end

    -- TopLeft: source region as-is
    addGem("TopLeft", srcL, srcR, srcT, srcB, "TOPLEFT", offsetX, -offsetY)
    -- TopRight: source mirrored horizontally in the BLP
    addGem("TopRight", texW - srcR, texW - srcL, srcT, srcB, "TOPRIGHT", -offsetX, -offsetY)
    -- BottomLeft: source mirrored vertically in the BLP
    addGem("BottomLeft", srcL, srcR, texH - srcB, texH - srcT, "BOTTOMLEFT", offsetX, offsetY)
    -- BottomRight: source mirrored both axes in the BLP
    addGem("BottomRight", texW - srcR, texW - srcL, texH - srcB, texH - srcT, "BOTTOMRIGHT", -offsetX, offsetY)

    result.Gems = gems

    -- Glow overlays (optional — nil if this animation spec has no glow table)
    local glowSpec = animSpec.glow
    if not glowSpec then
        return
    end

    local glowSize    = glowSpec.size
    local glowTexture = glowSpec.texture

    local function addGlow(name, anchorGem)
        local glow = gems:CreateTexture(nil, "ARTWORK")
        glow:SetTexture(glowTexture)
        glow:SetSize(glowSize, glowSize)
        glow:SetBlendMode("ADD")
        glow:SetPoint("CENTER", anchorGem, "CENTER", 0, 0)
        gems[name] = glow
        return glow
    end

    gems.GlowTL = addGlow("GlowTL", gems.TopLeft)
    gems.GlowTR = addGlow("GlowTR", gems.TopRight)
    gems.GlowBL = addGlow("GlowBL", gems.BottomLeft)
    gems.GlowBR = addGlow("GlowBR", gems.BottomRight)

    -- Alias onto result so EnsurePinpointFrame can store them on pinpoint.*
    -- where render.lua expects them (render.lua guards with "if frame.GlowXX then").
    result.GlowTL = gems.GlowTL
    result.GlowTR = gems.GlowTR
    result.GlowBL = gems.GlowBL
    result.GlowBR = gems.GlowBR
end

-- Builds a 9-slice ADD-blend overlay that tracks the panel's geometry exactly.
-- Uses the plaque spec's corner regions and slice sizes so the overlay texture
-- (e.g. HordePlaqueAnimation with skull eyes) stays pixel-aligned with the
-- underlying 9-slice panel regardless of how the panel stretches.
-- The resulting composite frame supports SetVertexColor across all 9 pieces,
-- so render.lua can pulse the entire overlay with one call.
local function BuildFullOverlay(_, panelFrame, animSpec, plaqueType, result)
    local plaqueSpec = Plaques.GetSpec(plaqueType)
    if not plaqueSpec then return end

    local layer = CreateFrame("Frame", nil, panelFrame)
    layer:SetAllPoints(panelFrame)
    layer.__awpTextures  = {}
    layer.SetVertexColor = SetCompositeVertexColor

    local texW           = plaqueSpec.texW
    local texH           = plaqueSpec.texH
    local texture        = animSpec.texture

    local sourceL        = plaqueSpec.srcCornerL
    local sourceR        = texW - plaqueSpec.srcCornerR
    local sourceT        = plaqueSpec.srcCornerT
    local sourceB        = texH - plaqueSpec.srcCornerB

    local function addTex(name, sL, sR, sT, sB)
        local tex = CreateAtlasTexture(layer, texW, texH, texture, "ARTWORK", "ADD", sL, sR, sT, sB)
        layer[name] = tex
        layer.__awpTextures[#layer.__awpTextures + 1] = tex
        return tex
    end

    -- Corners (fixed size, single anchor)
    local tl = addTex("TopLeft", 0, sourceL, 0, sourceT)
    tl:SetSize(plaqueSpec.sliceL, plaqueSpec.sliceT); tl:SetPoint("TOPLEFT")

    local tr = addTex("TopRight", sourceR, texW, 0, sourceT)
    tr:SetSize(plaqueSpec.sliceR, plaqueSpec.sliceT); tr:SetPoint("TOPRIGHT")

    local bl = addTex("BottomLeft", 0, sourceL, sourceB, texH)
    bl:SetSize(plaqueSpec.sliceL, plaqueSpec.sliceB); bl:SetPoint("BOTTOMLEFT")

    local br = addTex("BottomRight", sourceR, texW, sourceB, texH)
    br:SetSize(plaqueSpec.sliceR, plaqueSpec.sliceB); br:SetPoint("BOTTOMRIGHT")

    -- Edges (stretch one axis)
    local top = addTex("Top", sourceL, sourceR, 0, sourceT)
    top:SetPoint("TOPLEFT", layer, "TOPLEFT", plaqueSpec.sliceL, 0)
    top:SetPoint("TOPRIGHT", layer, "TOPRIGHT", -plaqueSpec.sliceR, 0)
    top:SetHeight(plaqueSpec.sliceT)

    local bottom = addTex("Bottom", sourceL, sourceR, sourceB, texH)
    bottom:SetPoint("BOTTOMLEFT", layer, "BOTTOMLEFT", plaqueSpec.sliceL, 0)
    bottom:SetPoint("BOTTOMRIGHT", layer, "BOTTOMRIGHT", -plaqueSpec.sliceR, 0)
    bottom:SetHeight(plaqueSpec.sliceB)

    local left = addTex("Left", 0, sourceL, sourceT, sourceB)
    left:SetPoint("TOPLEFT", layer, "TOPLEFT", 0, -plaqueSpec.sliceT)
    left:SetPoint("BOTTOMLEFT", layer, "BOTTOMLEFT", 0, plaqueSpec.sliceB)
    left:SetWidth(plaqueSpec.sliceL)

    local right = addTex("Right", sourceR, texW, sourceT, sourceB)
    right:SetPoint("TOPRIGHT", layer, "TOPRIGHT", 0, -plaqueSpec.sliceT)
    right:SetPoint("BOTTOMRIGHT", layer, "BOTTOMRIGHT", 0, plaqueSpec.sliceB)
    right:SetWidth(plaqueSpec.sliceR)

    -- Center (fills remaining space)
    local center = addTex("Center", sourceL, sourceR, sourceT, sourceB)
    center:SetPoint("TOPLEFT", layer, "TOPLEFT", plaqueSpec.sliceL, -plaqueSpec.sliceT)
    center:SetPoint("BOTTOMRIGHT", layer, "BOTTOMRIGHT", -plaqueSpec.sliceR, plaqueSpec.sliceB)

    result.Overlay = layer
end

-- Type dispatch table
-- Maps animation type strings to their builder functions.
-- Register new types here when adding new animation systems.

local ANIMATION_BUILDERS = {
    corner_gems  = BuildCornerGems,
    full_overlay = BuildFullOverlay,
    -- future: edge_shimmer = BuildEdgeShimmer,
    -- future: title_glow   = BuildTitleGlow,
}

-- ============================================================
-- Public API
-- ============================================================

M.PlaqueAnimations = {

    -- Builds all animations defined for the given plaque type.
    -- Returns a result table containing any of:
    --   result.Gems             — gems frame (nil if no corner_gems spec)
    --   result.GlowTL/TR/BL/BR — glow textures (nil if no glow spec)
    -- Returns an empty table if the plaque type has no animation entry.
    -- render.lua already nil-guards all of these references.
    CreateAnimations = function(parent, panelFrame, plaqueType)
        local specs = ANIMATION_SPECS[plaqueType]
        if not specs then
            return {}
        end

        local result = {}
        for _, animSpec in ipairs(specs) do
            local builder = ANIMATION_BUILDERS[animSpec.type]
            if builder then
                builder(parent, panelFrame, animSpec, plaqueType, result)
            end
        end
        return result
    end,

    -- Updates an existing pinpoint frame's animations in-place for a new plaque type.
    -- Modifies gem textures, UVs, sizes, and positions without creating new frames.
    -- Creates the gems frame lazily if it doesn't exist yet (e.g. initial plaque had
    -- no gems, new plaque does). Hides gems/glows when the new plaque has no gem spec.
    --
    -- pinpointFrame must be the top-level pinpoint frame (has .Gems, .GlowTL, etc.)
    -- panelFrame is pinpointFrame.Panel (gems are anchored to it)
    -- Returns an updated result table (same shape as CreateAnimations).
    UpdateAnimations = function(pinpointFrame, panelFrame, plaqueType)
        local specs           = ANIMATION_SPECS[plaqueType]
        local result          = {
            Gems    = pinpointFrame.Gems,
            GlowTL  = pinpointFrame.GlowTL,
            GlowTR  = pinpointFrame.GlowTR,
            GlowBL  = pinpointFrame.GlowBL,
            GlowBR  = pinpointFrame.GlowBR,
            Overlay = pinpointFrame.Overlay,
        }

        -- Determine which animation types the new plaque uses
        local gemAnimSpec     = nil
        local overlayAnimSpec = nil
        if specs then
            for _, animSpec in ipairs(specs) do
                if animSpec.type == "corner_gems" then
                    gemAnimSpec = animSpec
                elseif animSpec.type == "full_overlay" then
                    overlayAnimSpec = animSpec
                end
            end
        end

        -- full_overlay
        -- The overlay is a 9-slice composite frame — hide/recreate on swap
        -- rather than updating individual textures in-place.
        if result.Overlay then result.Overlay:Hide() end
        result.Overlay = nil
        if overlayAnimSpec then
            BuildFullOverlay(nil, panelFrame, overlayAnimSpec, plaqueType, result)
        end

        -- corner_gems
        -- No gems in new plaque — hide existing gems and glows if present
        if not gemAnimSpec then
            if result.Gems then result.Gems:Hide() end
            if result.GlowTL then result.GlowTL:Hide() end
            if result.GlowTR then result.GlowTR:Hide() end
            if result.GlowBL then result.GlowBL:Hide() end
            if result.GlowBR then result.GlowBR:Hide() end
            result.Gems   = nil
            result.GlowTL = nil
            result.GlowTR = nil
            result.GlowBL = nil
            result.GlowBR = nil
            return result
        end

        local gemsFrame = pinpointFrame.Gems

        -- Gems frame doesn't exist yet (initial plaque had no gems) — create it fresh
        if not gemsFrame then
            BuildCornerGems(pinpointFrame, panelFrame, gemAnimSpec, plaqueType, result)
            return result
        end

        -- Gems frame exists — update textures, UVs, sizes, and positions in-place
        gemsFrame:Show()

        local plaqueSpec                      = Plaques.GetSpec(plaqueType)
        local width, height, offsetX, offsetY = GetGemDisplayMetrics(plaqueSpec, gemAnimSpec)
        local texW                            = gemAnimSpec.texW
        local texH                            = gemAnimSpec.texH
        local texture                         = gemAnimSpec.texture
        local srcL                            = gemAnimSpec.srcL
        local srcT                            = gemAnimSpec.srcT
        local srcR                            = srcL + gemAnimSpec.srcW
        local srcB                            = srcT + gemAnimSpec.srcH

        local function updateGem(gem, uvL, uvR, uvT, uvB, point, px, py)
            gem:SetTexture(texture)
            gem:SetTexCoord(uvL / texW, uvR / texW, uvT / texH, uvB / texH)
            ConfigurePinpointTextureSampling(gem)
            gem:SetSize(width, height)
            gem:ClearAllPoints()
            gem:SetPoint(point, gemsFrame, point, px, py)
            gem:Show()
        end

        updateGem(gemsFrame.TopLeft, srcL, srcR, srcT, srcB, "TOPLEFT", offsetX, -offsetY)
        updateGem(gemsFrame.TopRight, texW - srcR, texW - srcL, srcT, srcB, "TOPRIGHT", -offsetX, -offsetY)
        updateGem(gemsFrame.BottomLeft, srcL, srcR, texH - srcB, texH - srcT, "BOTTOMLEFT", offsetX, offsetY)
        updateGem(gemsFrame.BottomRight, texW - srcR, texW - srcL, texH - srcB, texH - srcT, "BOTTOMRIGHT", -offsetX,
        offsetY)

        result.Gems = gemsFrame

        -- Update or hide glow textures
        local glowSpec = gemAnimSpec.glow
        if glowSpec then
            local function updateGlow(glow, anchorGem)
                if glow then
                    glow:SetTexture(glowSpec.texture)
                    glow:SetSize(glowSpec.size, glowSpec.size)
                    glow:ClearAllPoints()
                    glow:SetPoint("CENTER", anchorGem, "CENTER", 0, 0)
                    glow:Show()
                end
            end
            updateGlow(pinpointFrame.GlowTL, gemsFrame.TopLeft)
            updateGlow(pinpointFrame.GlowTR, gemsFrame.TopRight)
            updateGlow(pinpointFrame.GlowBL, gemsFrame.BottomLeft)
            updateGlow(pinpointFrame.GlowBR, gemsFrame.BottomRight)
            result.GlowTL = pinpointFrame.GlowTL
            result.GlowTR = pinpointFrame.GlowTR
            result.GlowBL = pinpointFrame.GlowBL
            result.GlowBR = pinpointFrame.GlowBR
        else
            if pinpointFrame.GlowTL then pinpointFrame.GlowTL:Hide() end
            if pinpointFrame.GlowTR then pinpointFrame.GlowTR:Hide() end
            if pinpointFrame.GlowBL then pinpointFrame.GlowBL:Hide() end
            if pinpointFrame.GlowBR then pinpointFrame.GlowBR:Hide() end
            result.GlowTL = nil
            result.GlowTR = nil
            result.GlowBL = nil
            result.GlowBR = nil
        end

        return result
    end,

    -- Returns the raw animation spec list for a plaque type.
    -- Used by render.lua and diagnostics to resolve per-plaque pulse defaults.
    GetSpec = function(plaqueType)
        return ANIMATION_SPECS[plaqueType]
    end,
}
