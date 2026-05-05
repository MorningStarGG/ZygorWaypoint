local NS = _G.AzerothWaypointNS
local state = NS.State

local registry = {}
local themeKeys = {}

local FALLBACK_TOMTOM_THEME = "modern"

-- Preset definitions: sprite layout + arrival mode + file naming for skinDir.
-- tomtom_classic / tomtom_modern: nav="nav", arrival="arrival" (frame-cycled animation)
-- zygor_mirror   / zygor_full:    nav="arrow", specular="arrow-specular", arrival="specials" (bounce)
-- single_image:                   nav="nav", arrival="arrival", specular="specular", arrivalSpecular="arrival_specular" (rotation + bounce)
local SKIN_PRESETS = {
    -- Single-image mode — one nav image rotated by angle + one arrival image bounced.
    -- No sprite sheet required. Image format: square PNG/TGA/BLP with the arrow drawn
    -- pointing UP (north) at angle 0, centered in the canvas with transparent padding
    -- around it so rotation doesn't clip the corners. Direction gradient tint is
    -- applied via SetVertexColor — set tint="none" if your image is already colored.
    -- Specular is opt-in: pass specular=true (uses skinDir.."specular") or set
    -- an explicit specularTexture path.
    single_image = {
        navWidth = 64,
        navHeight = 64,
        arrivalWidth = 48,
        arrivalHeight = 48,
        arrivalBounce = 12,
    },
    -- TomTom Classic style — 1024×1024 sheet, gradient tinted, frame-cycled arrival
    tomtom_classic = {
        navWidth = 56,
        navHeight = 42,
        sprite = { spr_w = 112, spr_h = 84, img_w = 1024, img_h = 1024, spritecount = 108, mirror = false },
        arrivalWidth = 56,
        arrivalHeight = 42,
        -- TomTom Classic applies direction-based vertex color (gradient tint, no tint="none").
        -- Arrival fps matches TomTom's own ~62fps frame advance rate.
        arrivalSprite = { spr_w = 106, spr_h = 140, img_w = 1024, img_h = 1024, spritecount = 54, fps = 60 },
        specialsTexture = false,
    },
    -- TomTom Modern style — 2304×3072 sheet, pre-colored RGBA, frame-cycled arrival
    tomtom_modern = {
        navWidth = 80,
        navHeight = 80,
        navDrop = 10, -- TomTom Modern: BOTTOMRIGHT is 10px below button frame (tail extension)
        sprite = { spr_w = 256, spr_h = 256, img_w = 2304, img_h = 3072, spritecount = 108, mirror = false },
        arrivalWidth = 80,
        arrivalHeight = 80,
        -- Modern sheets are pre-colored RGBA; arrival fps matches TomTom's ~62fps rate.
        arrivalSprite = { spr_w = 256, spr_h = 256, img_w = 2304, img_h = 3072, spritecount = 108, fps = 60 },
        specialsTexture = false,
        tint = "none",
    },
    -- Zygor Starlight style — mirrored sprite sheet, specular layer, bounce arrival
    zygor_mirror = {
        navWidth = 56,
        navHeight = 42,
        navDrop = 8,
        sprite = { spr_w = 102, spr_h = 68, img_w = 1024, img_h = 1024, spritecount = 150, mirror = true },
        arrivalWidth = 50,
        arrivalHeight = 40,
        arrivalBounce = 15,
        arrivalDrop = 3,
        arrivalGrid = { col = 1, row = 1, cols = 8, rows = 2, inset = 0 },
    },
    -- Zygor Stealth style — full 360 degree sprite sheet, no mirroring
    zygor_full = {
        navWidth = 56,
        navHeight = 42,
        navDrop = 8,
        sprite = { spr_w = 102, spr_h = 68, img_w = 1024, img_h = 1024, spritecount = 150, mirror = false },
        arrivalWidth = 40,
        arrivalHeight = 40,
        arrivalBounce = 15,
        arrivalGrid = { col = 1, row = 1, cols = 8, rows = 2, inset = 0 },
    },
}

local themeState = state.theme or {}
state.theme = themeState
themeState.arrowSuppressionReasons = themeState.arrowSuppressionReasons or {}

local DEFAULT_SUPPRESSION_REASON = "default"

local function HasArrowSuppressionReason()
    for _, enabled in pairs(themeState.arrowSuppressionReasons) do
        if enabled then
            return true
        end
    end
    return false
end

local function IsCombatLockdownActive()
    return type(InCombatLockdown) == "function" and InCombatLockdown() == true
end

local function NormalizeKey(key)
    if type(key) ~= "string" then return nil end
    key = key:lower():gsub("%s+", "_")
    if key == "" then return nil end
    return key
end

local function NormalizeThemeKey(key, skinKey)
    if type(key) == "string" and key ~= "" then return key end
    return "awp-" .. tostring(skinKey or ""):gsub("_", "-")
end

local function GetTomTom()
    if type(NS.GetTomTom) == "function" then
        return NS.GetTomTom()
    end
    return _G["TomTom"]
end

local function GetTomTomArrow()
    if type(NS.GetTomTomArrow) == "function" then
        return NS.GetTomTomArrow()
    end

    local tomtom = GetTomTom()
    return tomtom and tomtom.wayframe or nil
end

local function GetThemeScale()
    if type(NS.GetArrowScale) == "function" then
        return NS.GetArrowScale()
    end
    return 1
end

local function GetSkinThemeKey(key, def)
    if not def then return nil end
    def.themeKey = NormalizeThemeKey(def.themeKey, key)
    themeKeys[def.themeKey] = key
    return def.themeKey
end

local function IsCustomSkinDef(def)
    if type(def) ~= "table" or def.key == "tomtom_default" then return false end
    if def.navTexture or def.arrivalTexture then return true end
    if def.skinDir or def.sprite then return true end
    return false
end

-- Merges a named preset into def and derives texture paths from skinDir.
-- Preset fields only fill in fields the caller did not explicitly set.
local function ExpandPreset(def)
    local preset = SKIN_PRESETS[def.preset]
    if not preset then return end

    for k, v in pairs(preset) do
        if def[k] == nil then
            if type(v) == "table" then
                local copy = {}
                for tk, tv in pairs(v) do copy[tk] = tv end
                def[k] = copy
            else
                def[k] = v
            end
        end
    end

    if not def.skinDir then return end
    local dir = def.skinDir
    local p = def.preset
    if p == "tomtom_classic" or p == "tomtom_modern" then
        def.navTexture     = def.navTexture or (dir .. "nav")
        def.arrivalTexture = def.arrivalTexture or (dir .. "arrival")
        -- specialsTexture=false (from preset) blocks GetSpecialsTexture from guessing skinDir.."specials"
    elseif p == "single_image" then
        def.navTexture     = def.navTexture or (dir .. "nav")
        def.arrivalTexture = def.arrivalTexture or (dir .. "arrival")
        -- Specular is opt-in: pass specular=true to derive from skinDir, or set explicit specularTexture.
        if def.specular == true and not def.specularTexture then
            def.specularTexture = dir .. "specular"
        end
        -- Arrival specular is separate from nav specular. It must match the arrival art/layout.
        -- Pass arrivalSpecular=true to derive skinDir.."arrival_specular", or set arrivalSpecularTexture explicitly.
        if def.arrivalSpecular == true and not def.arrivalSpecularTexture then
            def.arrivalSpecularTexture = dir .. "arrival_specular"
        end
    end
    -- zygor_mirror / zygor_full: GetNavTexture, GetSpecularTexture, GetSpecialsTexture
    -- resolve skinDir.."arrow", "arrow-specular", "specials" automatically.
end

function NS.RegisterArrowSkin(key, def)
    key = NormalizeKey(key)
    if not key or type(def) ~= "table" then return false end

    if def.preset then ExpandPreset(def) end
    def.key = key
    def.themeKey = NormalizeThemeKey(def.themeKey, key)
    registry[key] = def
    themeKeys[def.themeKey] = key
    return true
end

function NS.HasArrowSkin(key)
    key = NormalizeKey(key)
    return key ~= nil and registry[key] ~= nil
end

function NS.GetArrowSkin(key)
    key = NormalizeKey(key)
    return key and registry[key] or nil
end

function NS.GetRegisteredArrowSkins()
    local keys = {}
    for key in pairs(registry) do
        keys[#keys + 1] = key
    end
    table.sort(keys, function(a, b)
        if a == "tomtom_default" then return true end
        if b == "tomtom_default" then return false end
        local ad = registry[a]
        local bd = registry[b]
        local al = ad and ad.displayName or a
        local bl = bd and bd.displayName or b
        return tostring(al) < tostring(bl)
    end)
    return keys
end

function NS.IsRegisteredArrowThemeKey(key)
    return key ~= nil and themeKeys[key] ~= nil
end

function NS.IsThemeKey(key)
    return NS.IsRegisteredArrowThemeKey(key)
end

local function GetNavTexture(def)
    if def.navTexture then return def.navTexture end
    if def.skinDir then return def.skinDir .. "arrow" end
    return nil
end

local function GetSpecularTexture(def)
    if def.specularTexture == false then return nil end
    if def.specularTexture then return def.specularTexture end
    if def.skinDir and def.sprite then return def.skinDir .. "arrow-specular" end
    return nil
end

local function GetArrivalSpecularTexture(def)
    if def.arrivalSpecularTexture == false then return nil end
    if def.arrivalSpecularTexture then return def.arrivalSpecularTexture end
    if def.arrivalSpecular == true and def.skinDir then return def.skinDir .. "arrival_specular" end
    return nil
end

local function GetSpecialsTexture(def)
    if def.specialsTexture == false then return nil end
    if def.specialsTexture then return def.specialsTexture end
    if def.skinDir and def.sprite then return def.skinDir .. "specials" end
    return nil
end

local function GetArrivalTexture(def)
    if def.arrivalTexture then return def.arrivalTexture end
    return GetSpecialsTexture(def) or GetNavTexture(def)
end

local function BuildSpriteResolver(sprite)
    if type(sprite) ~= "table" then return nil end

    local sprW = sprite.spr_w or sprite.width
    local sprH = sprite.spr_h or sprite.height
    local imgW = sprite.img_w or sprite.sheetWidth
    local imgH = sprite.img_h or sprite.sheetHeight
    local spriteCount = sprite.spritecount or sprite.count
    if not sprW or not sprH or not imgW or not imgH or not spriteCount or spriteCount <= 0 then return nil end

    local cols = math.max(1, math.floor(imgW / sprW))
    local maxAngle = math.pi * 2
    local mirror = sprite.mirror and true or false

    return function(angle)
        angle = tonumber(angle) or 0
        angle = angle % maxAngle

        local index
        local hflip = false

        if mirror then
            local halfAngle = math.pi
            local normalized = angle
            if normalized > halfAngle then
                normalized = maxAngle - normalized
                hflip = true
            end
            local factor = normalized / halfAngle
            index = math.floor(factor * (spriteCount - 1) + 0.5)
        else
            local factor = angle / maxAngle
            index = math.floor(factor * spriteCount + 0.5) % spriteCount
        end

        local col = index % cols
        local row = math.floor(index / cols)
        local left = (col * sprW) / imgW
        local right = ((col + 1) * sprW) / imgW
        local top = (row * sprH) / imgH
        local bottom = ((row + 1) * sprH) / imgH

        if hflip then
            left, right = right, left
        end

        return left, right, top, bottom
    end
end

-- Maps a frame index (0-based, advances over time) to UV coords in a sprite sheet.
-- Used for TomTom-style arrival animation.
local function BuildArrivalFrameResolver(arrivalSprite)
    if type(arrivalSprite) ~= "table" then return nil end
    local sprW = arrivalSprite.spr_w
    local sprH = arrivalSprite.spr_h
    local imgW = arrivalSprite.img_w
    local imgH = arrivalSprite.img_h
    local count = arrivalSprite.spritecount
    if not sprW or not sprH or not imgW or not imgH or not count or count <= 0 then return nil end
    local cols = math.max(1, math.floor(imgW / sprW))
    return function(frame)
        local index = frame % count
        local col = index % cols
        local row = math.floor(index / cols)
        return (col * sprW) / imgW, ((col + 1) * sprW) / imgW,
            (row * sprH) / imgH, ((row + 1) * sprH) / imgH
    end
end

-- Merges a named preset into def and derives texture paths from skinDir.

local function BuildGridTexCoord(col, row, cols, rows, inset)
    col = tonumber(col) or 1
    row = tonumber(row) or 1
    cols = tonumber(cols) or 1
    rows = tonumber(rows) or 1
    inset = tonumber(inset) or 0

    local cellW = 1 / cols
    local cellH = 1 / rows
    local left = (col - 1) * cellW + inset
    local right = col * cellW - inset
    local top = (row - 1) * cellH + inset
    local bottom = row * cellH - inset
    return left, right, top, bottom
end

local function ApplyTexCoord(texture, coords)
    if type(coords) == "table" then
        texture:SetTexCoord(coords[1] or 0, coords[2] or 1, coords[3] or 0, coords[4] or 1)
    else
        texture:SetTexCoord(0, 1, 0, 1)
    end
end

local function GetDirectionColor(def, angle)
    if def.tint == "none" then return 1, 1, 1 end
    if type(def.tint) == "table" then
        return def.tint.r or 1, def.tint.g or 1, def.tint.b or 1
    end

    local tomtom = GetTomTom()
    local r, g, b = 1, 1, 1

    if tomtom and tomtom.db and tomtom.db.profile and tomtom.db.profile.arrow
        and type(tomtom.ColorGradient) == "function"
    then
        local arrow = tomtom.db.profile.arrow
        local perc = math.abs((math.pi - math.abs(tonumber(angle) or 0)) / math.pi)
        local gr, gg, gb = unpack(arrow.goodcolor or { 0, 1, 0 })
        local mr, mg, mb = unpack(arrow.middlecolor or { 1, 1, 0 })
        local br, bg, bb = unpack(arrow.badcolor or { 1, 0, 0 })
        r, g, b = tomtom:ColorGradient(perc, br, bg, bb, mr, mg, mb, gr, gg, gb)
        if perc > 0.98 and arrow.exactcolor then
            r, g, b = unpack(arrow.exactcolor)
        end
    end

    local precise = def.precise
    if precise and precise.range then
        local wayframe = GetTomTomArrow()
        local distance = wayframe and wayframe.distance
        local deg = math.floor(math.abs(tonumber(angle) or 0) * (180 / math.pi) + 0.5) % 360
        local factor = 0
        if deg < precise.range then
            factor = 1 - (deg / precise.range)
        elseif deg > 360 - precise.range then
            factor = 1 - ((360 - deg) / precise.range)
        end
        if factor > 0 then
            if precise.smooth then
                r = r + ((precise.r or r) - r) * factor
                g = g + ((precise.g or g) - g) * factor
                b = b + ((precise.b or b) - b) * factor
            else
                r, g, b = precise.r or r, precise.g or g, precise.b or b
            end
        end
        -- Override entirely when at distance-zero if distance check requested
        local d0 = tonumber(distance)
        if d0 and d0 <= 0 then
            r, g, b = precise.r or r, precise.g or g, precise.b or b
        end
    end

    return r, g, b
end

local function GetArrivalColor(def)
    if type(def) ~= "table" then return 1, 1, 1 end
    if def.arrivalTint == "none" then return 1, 1, 1 end
    if type(def.arrivalTint) == "table" then
        return def.arrivalTint.r or 1, def.arrivalTint.g or 1, def.arrivalTint.b or 1
    end

    return 1, 1, 1
end

local function SetTextureBlendMode(texture, blendMode)
    if texture and type(texture.SetBlendMode) == "function" then
        texture:SetBlendMode(blendMode or "ADD")
    end
end

local function SetTextureDrawLayer(texture, layer, sublevel)
    if texture and type(texture.SetDrawLayer) == "function" then
        texture:SetDrawLayer(layer, sublevel)
    end
end

local function EnsureThemeTextures(theme, button)
    if not button or not theme then return end

    if not theme.arrowTexture then
        theme.arrowTexture = button:CreateTexture(nil, "OVERLAY")
    end
    SetTextureDrawLayer(theme.arrowTexture, "OVERLAY", 0)

    if theme.specularTexturePath then
        if not theme.specularTexture then
            theme.specularTexture = button:CreateTexture(nil, "OVERLAY")
        end
        SetTextureDrawLayer(theme.specularTexture, "OVERLAY", 1)
        SetTextureBlendMode(theme.specularTexture, (theme.def and theme.def.specularBlend) or "ADD")
    end

    if theme.arrivalSpecularTexturePath then
        if not theme.arrivalSpecularTexture then
            theme.arrivalSpecularTexture = button:CreateTexture(nil, "OVERLAY")
        end
        SetTextureDrawLayer(theme.arrivalSpecularTexture, "OVERLAY", 1)
        SetTextureBlendMode(theme.arrivalSpecularTexture, (theme.def and theme.def.arrivalSpecularBlend) or "ADD")
    end
end

local function UpdateArrivalAnimationScale(theme)
    if not theme then return end
    local bounce = (theme.arrivalBounce or 0) * GetThemeScale() *
        ((theme.def and (theme.def.arrivalBaseScale or theme.def.baseScale)) or 1)

    if theme.arrivalAnimUp and theme.arrivalAnimDown then
        theme.arrivalAnimUp:SetOffset(0, bounce)
        theme.arrivalAnimDown:SetOffset(0, -bounce)
    end

    if theme.arrivalSpecularAnimUp and theme.arrivalSpecularAnimDown then
        theme.arrivalSpecularAnimUp:SetOffset(0, bounce)
        theme.arrivalSpecularAnimDown:SetOffset(0, -bounce)
    end
end

local function CreateArrivalBounceAnimation(region)
    if not region then return nil end

    local group = region:CreateAnimationGroup()
    group:SetLooping("REPEAT")

    local up = group:CreateAnimation("Translation")
    up:SetDuration(0.3)
    up:SetOrder(1)
    up:SetSmoothing("OUT")

    local down = group:CreateAnimation("Translation")
    down:SetDuration(0.3)
    down:SetOrder(2)
    down:SetSmoothing("IN")

    return group, up, down
end

local function EnsureArrivalAnimation(theme, arrow, arrivalSpecular)
    if not theme or not arrow then return end

    if not theme.arrivalAnimationGroup then
        local group, up, down = CreateArrivalBounceAnimation(arrow)
        theme.arrivalAnimUp = up
        theme.arrivalAnimDown = down
        theme.arrivalAnimationGroup = group
    end

    -- Texture animations do not move other textures anchored to them in WoW.
    -- Keep the specular on the same arrival path by giving it an identical bounce
    -- group, driven/stopped/started together with the arrival arrow.
    arrivalSpecular = arrivalSpecular or theme.arrivalSpecularTexture
    if arrivalSpecular and not theme.arrivalSpecularAnimationGroup then
        local group, up, down = CreateArrivalBounceAnimation(arrivalSpecular)
        theme.arrivalSpecularAnimUp = up
        theme.arrivalSpecularAnimDown = down
        theme.arrivalSpecularAnimationGroup = group
    end

    UpdateArrivalAnimationScale(theme)
end

local function StopArrivalAnimations(theme)
    if not theme then return end
    if theme.arrivalAnimationGroup then theme.arrivalAnimationGroup:Stop() end
    if theme.arrivalSpecularAnimationGroup then theme.arrivalSpecularAnimationGroup:Stop() end
end

local function PlayArrivalAnimations(theme)
    if not theme then return end
    if theme.arrivalAnimationGroup and not theme.arrivalAnimationGroup:IsPlaying() then
        theme.arrivalAnimationGroup:Play()
    end
    if theme.arrivalSpecularAnimationGroup and not theme.arrivalSpecularAnimationGroup:IsPlaying() then
        theme.arrivalSpecularAnimationGroup:Play()
    end
end

local function HideThemeTexture(texture)
    if not texture then return end
    texture:Hide()
end

local function SetThemeTextureShown(texture, shown)
    if not texture then return end
    if type(texture.SetShown) == "function" then
        texture:SetShown(shown and true or false)
    elseif shown and type(texture.Show) == "function" then
        texture:Show()
    elseif not shown and type(texture.Hide) == "function" then
        texture:Hide()
    end
end

local function GetArrivalTexCoord(theme, frame)
    if not theme or not theme.def then return 0, 1, 0, 1 end
    local def = theme.def

    if def.arrivalTexCoord then
        local c = def.arrivalTexCoord
        return c[1] or 0, c[2] or 1, c[3] or 0, c[4] or 1
    elseif theme.arrivalFrameResolver then
        return theme.arrivalFrameResolver(frame or 0)
    elseif theme.arrivalTexture == theme.specialsTexture and def.arrivalGrid ~= false then
        local grid = def.arrivalGrid or { col = 1, row = 1, cols = 8, rows = 2, inset = 0 }
        return BuildGridTexCoord(grid.col, grid.row, grid.cols, grid.rows, grid.inset)
    end

    return 0, 1, 0, 1
end

local function ApplyArrivalTexCoord(theme, frame)
    local l, r, t, b = GetArrivalTexCoord(theme, frame)

    if theme.arrowTexture then
        theme.arrowTexture:SetTexCoord(l, r, t, b)
    end

    if theme.arrivalSpecularTexture then
        theme.arrivalSpecularTexture:SetTexCoord(l, r, t, b)
    end

    return l, r, t, b
end

local function ApplyNavigationLayout(theme, button)
    if not button or not theme then return end
    local def = theme.def
    local scale = GetThemeScale() * ((def and def.baseScale) or 1)
    EnsureThemeTextures(theme, button)

    button:SetWidth((def.navWidth or 56) * scale)
    button:SetHeight((def.navHeight or 42) * scale)

    local arrow = theme.arrowTexture
    arrow:ClearAllPoints()
    arrow:SetPoint("TOPLEFT", button, "TOPLEFT", 0, 0)
    arrow:SetPoint("BOTTOMRIGHT", button, "BOTTOMRIGHT", 0, -((def.navDrop or 0) * scale))
    arrow:SetTexture(theme.navTexture)

    if theme.spriteResolver then
        arrow:SetTexCoord(theme.spriteResolver(theme.lastAngle or 0))
        if type(arrow.SetRotation) == "function" then
            arrow:SetRotation(0)
        end
    else
        arrow:SetTexCoord(0, 1, 0, 1)
        if type(arrow.SetRotation) == "function" then
            arrow:SetRotation((theme.lastAngle or 0) + (def.rotationOffset or 0))
        end
    end

    local r, g, b = GetDirectionColor(def, theme.lastAngle or 0)
    arrow:SetVertexColor(r, g, b, 1)

    if themeState.arrowSuppressed then
        arrow:Hide()
    else
        arrow:Show()
    end

    HideThemeTexture(theme.arrivalSpecularTexture)

    local specular = theme.specularTexture
    if specular then
        specular:ClearAllPoints()
        specular:SetAllPoints(arrow)
        specular:SetTexture(theme.specularTexturePath)
        if theme.spriteResolver then
            specular:SetTexCoord(theme.spriteResolver(theme.lastAngle or 0))
            if type(specular.SetRotation) == "function" then
                specular:SetRotation(0)
            end
        else
            specular:SetTexCoord(0, 1, 0, 1)
            if type(specular.SetRotation) == "function" then
                specular:SetRotation((theme.lastAngle or 0) + (def.rotationOffset or 0))
            end
        end
        specular:SetVertexColor(1, 1, 1, 1)
        specular:SetAlpha(def.specularAlpha or 0.7)
        if themeState.arrowSuppressed then
            specular:Hide()
        else
            specular:Show()
        end
    end

    StopArrivalAnimations(theme)
end

local function ApplyArrivalLayout(theme, button)
    if not button or not theme then return end
    local def = theme.def
    local scale = GetThemeScale() * ((def and (def.arrivalBaseScale or def.baseScale)) or 1)
    EnsureThemeTextures(theme, button)

    button:SetWidth((def.navWidth or 56) * scale)
    button:SetHeight((def.navHeight or 42) * scale)

    local arrow = theme.arrowTexture
    local aw = (def.arrivalWidth or def.navWidth or 48) * scale
    local ah = (def.arrivalHeight or def.navHeight or 48) * scale
    arrow:ClearAllPoints()
    arrow:SetSize(aw, ah)
    arrow:SetPoint("CENTER", button, "CENTER", 0, -((def.arrivalDrop or 0) * scale))
    arrow:SetTexture(theme.arrivalTexture)
    ApplyArrivalTexCoord(theme, 0)

    if type(arrow.SetRotation) == "function" then
        arrow:SetRotation(0)
    end

    local ar, ag, ab = GetArrivalColor(def)
    arrow:SetVertexColor(ar, ag, ab, 1)
    if themeState.arrowSuppressed then
        arrow:Hide()
    else
        arrow:Show()
    end

    HideThemeTexture(theme.specularTexture)

    local arrivalSpecular = theme.arrivalSpecularTexture
    if arrivalSpecular then
        arrivalSpecular:ClearAllPoints()
        arrivalSpecular:SetAllPoints(arrow)
        arrivalSpecular:SetTexture(theme.arrivalSpecularTexturePath)
        ApplyArrivalTexCoord(theme, 0)
        if type(arrivalSpecular.SetRotation) == "function" then
            arrivalSpecular:SetRotation(0)
        end
        arrivalSpecular:SetVertexColor(1, 1, 1, 1)
        arrivalSpecular:SetAlpha(def.arrivalSpecularAlpha or def.specularAlpha or 0.7)
        if themeState.arrowSuppressed then
            arrivalSpecular:Hide()
        else
            arrivalSpecular:Show()
        end
    end

    theme.arrivalBounce = def.arrivalBounce or 0
    if not theme.arrivalFrameResolver then
        EnsureArrivalAnimation(theme, arrow, arrivalSpecular)
        if not themeState.arrowSuppressed then
            PlayArrivalAnimations(theme)
        end
    end
end

local function BuildRegisteredTomTomTheme(key, def)
    local navTexture = GetNavTexture(def)
    if not navTexture then return nil end

    local theme = {
        key = key,
        def = def,
        navTexture = navTexture,
        specularTexturePath = GetSpecularTexture(def),
        arrivalSpecularTexturePath = GetArrivalSpecularTexture(def),
        specialsTexture = GetSpecialsTexture(def),
        arrivalTexture = GetArrivalTexture(def) or navTexture,
        spriteResolver = BuildSpriteResolver(def.sprite),
        arrivalFrameResolver = BuildArrivalFrameResolver(def.arrivalSprite),
        arrivalFPS = (def.arrivalSprite and def.arrivalSprite.fps) or 20,
        arrivalElapsed = 0,
        arrivalFrame = 0,
        navElapsed = 0,
        lastAngle = 0,
    }

    function theme:ApplyTheme()
        local button = GetTomTomArrow()
        if button then
            ApplyNavigationLayout(self, button)
        end
    end

    function theme:RemoveTheme()
        StopArrivalAnimations(self)
        HideThemeTexture(self.arrowTexture)
        HideThemeTexture(self.specularTexture)
        HideThemeTexture(self.arrivalSpecularTexture)
    end

    function theme:SwitchToArrivalArrow()
        self.isArrivalMode = true
        themeState.tomtomArrivalMode = true
        local button = GetTomTomArrow()
        if button then
            ApplyArrivalLayout(self, button)
        end
        if self.arrivalFrameResolver then
            self.arrivalFrame = 0
            self.arrivalElapsed = 0
            StopArrivalAnimations(self)
        end
    end

    function theme:ArrivalArrow_OnUpdate(elapsed)
        if themeState.arrowSuppressed then
            HideThemeTexture(self.arrowTexture)
            HideThemeTexture(self.specularTexture)
            HideThemeTexture(self.arrivalSpecularTexture)
            StopArrivalAnimations(self)
            return
        end
        HideThemeTexture(self.specularTexture)
        if self.arrivalFrameResolver then
            self.arrivalElapsed = self.arrivalElapsed + (tonumber(elapsed) or 0)
            local frameDuration = 1 / (self.arrivalFPS > 0 and self.arrivalFPS or 20)
            if self.arrivalElapsed >= frameDuration then
                local steps = math.floor(self.arrivalElapsed / frameDuration)
                self.arrivalElapsed = self.arrivalElapsed - steps * frameDuration
                self.arrivalFrame = self.arrivalFrame + steps
                ApplyArrivalTexCoord(self, self.arrivalFrame)
            end
            if self.arrowTexture then self.arrowTexture:Show() end
            if self.arrivalSpecularTexture then self.arrivalSpecularTexture:Show() end
            return
        end
        if self.arrowTexture then
            self.arrowTexture:Show()
            if self.arrivalSpecularTexture then self.arrivalSpecularTexture:Show() end
            PlayArrivalAnimations(self)
        end
    end

    function theme:SwitchToNavigationArrow()
        self.isArrivalMode = false
        themeState.tomtomArrivalMode = false
        local button = GetTomTomArrow()
        if button then
            ApplyNavigationLayout(self, button)
        end
    end

    function theme:NavigationArrow_OnUpdate(elapsed, angle)
        self.navElapsed = self.navElapsed + (tonumber(elapsed) or 0)
        if self.navElapsed < 0.016 then return end
        self.navElapsed = 0

        self.lastAngle = tonumber(angle) or 0
        local button = GetTomTomArrow()
        if not button then return end
        EnsureThemeTextures(self, button)

        if themeState.arrowSuppressed then
            HideThemeTexture(self.arrowTexture)
            HideThemeTexture(self.specularTexture)
            HideThemeTexture(self.arrivalSpecularTexture)
            return
        end

        local arrow = self.arrowTexture
        HideThemeTexture(self.arrivalSpecularTexture)
        local l, r, t, b
        local rotation

        if self.spriteResolver then
            -- Sprite-sheet mode: pick the frame for this angle, only update on change
            l, r, t, b = self.spriteResolver(self.lastAngle)
            if l ~= self.lastNavL or r ~= self.lastNavR
                or t ~= self.lastNavT or b ~= self.lastNavB
            then
                self.lastNavL, self.lastNavR = l, r
                self.lastNavT, self.lastNavB = t, b
                arrow:SetTexture(self.navTexture)
                arrow:SetTexCoord(l, r, t, b)
                if type(arrow.SetRotation) == "function" then
                    arrow:SetRotation(0)
                end
            end
        else
            -- Rotation mode (single image): texture + texcoord set once in
            -- ApplyNavigationLayout; just update rotation each tick.
            rotation = self.lastAngle + (def.rotationOffset or 0)
            if type(arrow.SetRotation) == "function" then
                arrow:SetRotation(rotation)
            end
        end

        local cr, cg, cb = GetDirectionColor(def, self.lastAngle)
        arrow:SetVertexColor(cr, cg, cb, 1)
        if not arrow:IsShown() then arrow:Show() end

        local specular = self.specularTexture
        if specular then
            if self.spriteResolver and l then
                specular:SetTexture(self.specularTexturePath)
                specular:SetTexCoord(l, r, t, b)
                if type(specular.SetRotation) == "function" then
                    specular:SetRotation(0)
                end
            elseif rotation and type(specular.SetRotation) == "function" then
                -- Rotation mode: specular rotates with the arrow
                specular:SetRotation(rotation)
            end
            specular:SetVertexColor(1, 1, 1, 1)
            specular:SetAlpha(def.specularAlpha or 0.7)
            if not specular:IsShown() then specular:Show() end
        end
    end

    return theme
end

local function RegisterTomTomThemes()
    local tomtom = GetTomTom()
    local handler = tomtom and tomtom.CrazyArrowThemeHandler
    if not handler or type(handler.RegisterCrazyArrowTheme) ~= "function" then return false end

    for key, def in pairs(registry) do
        if IsCustomSkinDef(def) then
            local themeKey = GetSkinThemeKey(key, def)
            if themeKey and not (handler.themes and handler.themes[themeKey]) then
                local theme = BuildRegisteredTomTomTheme(key, def)
                if theme then
                    handler:RegisterCrazyArrowTheme(themeKey, def.displayName or key, theme)
                end
            end
        end
    end

    return true
end

local function RevertToTomTomTheme(handler, wayframe)
    local active = handler and ((handler.GetActiveTheme and handler:GetActiveTheme()) or handler.activeKey)
    if not NS.IsThemeKey(active) then return end

    local profileTheme
    local tomtom = GetTomTom()
    if tomtom and tomtom.db and tomtom.db.profile and type(tomtom.db.profile.arrow) == "table" then
        profileTheme = tomtom.db.profile.arrow.theme
    end
    if NS.IsThemeKey(profileTheme) then
        profileTheme = nil
    end

    local fallback = profileTheme or FALLBACK_TOMTOM_THEME
    if fallback and handler.themes and handler.themes[fallback] and type(handler.SetActiveTheme) == "function" then
        handler:SetActiveTheme(wayframe, fallback, false)
    end
end

function NS.ApplyTomTomArrowSkin()
    local tomtom = GetTomTom()
    local wayframe = GetTomTomArrow()
    local handler = tomtom and tomtom.CrazyArrowThemeHandler
    if not handler or not wayframe or type(handler.SetActiveTheme) ~= "function" then return end

    local choice = NS.GetSkinChoice and NS.GetSkinChoice() or "default"
    local def = NS.GetArrowSkin(choice)
    if not IsCustomSkinDef(def) then
        RevertToTomTomTheme(handler, wayframe)
        return
    end

    if not RegisterTomTomThemes() then return end

    local themeKey = GetSkinThemeKey(choice, def)
    if themeKey and handler.themes and handler.themes[themeKey] then
        local active = handler.active and handler.active.tbl
        local activeKey = (handler.GetActiveTheme and handler:GetActiveTheme()) or handler.activeKey
        if activeKey == themeKey and active then
            local arrivalMode = themeState.tomtomArrivalMode == true
            if arrivalMode then
                active:SwitchToArrivalArrow(wayframe)
            else
                active:SwitchToNavigationArrow(wayframe)
            end
            return
        end

        local prevTheme = handler.active and handler.active.tbl
        local prevAngle = prevTheme and type(prevTheme.lastAngle) == "number" and prevTheme.lastAngle or nil
        local prevArrivalMode
        if prevTheme and prevTheme.isArrivalMode ~= nil then
            prevArrivalMode = prevTheme.isArrivalMode == true
        else
            prevArrivalMode = themeState.tomtomArrivalMode == true
        end

        handler:SetActiveTheme(wayframe, themeKey, prevArrivalMode)

        -- Seed the new theme with the outgoing angle so it doesn't snap to 0
        -- and wait for player movement before correcting.
        local newTheme = handler.active and handler.active.tbl
        if prevAngle then
            if newTheme and type(newTheme.lastAngle) == "number" then
                newTheme.lastAngle = prevAngle
                if not prevArrivalMode then
                    local button = GetTomTomArrow()
                    if button then ApplyNavigationLayout(newTheme, button) end
                end
            end
        end
    end
end

function NS.HookTomTomThemeBridge()
    local tomtom = GetTomTom()
    if not tomtom or themeState.hookedTomTom then return end
    themeState.hookedTomTom = true
    local handler = tomtom.CrazyArrowThemeHandler

    local function ApplyAfterTomTomUpdate()
        if type(NS.After) == "function" then
            NS.After(0, NS.ApplyTomTomArrowSkin)
        else
            NS.ApplyTomTomArrowSkin()
        end
    end

    if type(tomtom.ShowHideCrazyArrow) == "function" and _G.hooksecurefunc then
        _G.hooksecurefunc(tomtom, "ShowHideCrazyArrow", function()
            ApplyAfterTomTomUpdate()
        end)
    end

    if type(tomtom.SetCrazyArrow) == "function" and _G.hooksecurefunc then
        _G.hooksecurefunc(tomtom, "SetCrazyArrow", function()
            ApplyAfterTomTomUpdate()
        end)
    end

    if handler and _G.hooksecurefunc then
        if type(handler.SwitchToArrivalArrow) == "function" then
            _G.hooksecurefunc(handler, "SwitchToArrivalArrow", function()
                themeState.tomtomArrivalMode = true
            end)
        end
        if type(handler.SwitchToNavigationArrow) == "function" then
            _G.hooksecurefunc(handler, "SwitchToNavigationArrow", function()
                themeState.tomtomArrivalMode = false
            end)
        end
    end
end

function NS.SuppressTomTomArrowDisplay(suppressed, reason)
    reason = type(reason) == "string" and reason ~= "" and reason or DEFAULT_SUPPRESSION_REASON
    if suppressed then
        themeState.arrowSuppressionReasons[reason] = true
    else
        themeState.arrowSuppressionReasons[reason] = nil
    end

    local flag = HasArrowSuppressionReason()
    if themeState.arrowSuppressed == flag then return end
    themeState.arrowSuppressed = flag

    local arrow = GetTomTomArrow()
    local tomtom = GetTomTom()
    local handler = tomtom and tomtom.CrazyArrowThemeHandler
    local active = handler and ((handler.GetActiveTheme and handler:GetActiveTheme()) or handler.activeKey)
    local activeTheme = handler and handler.active and handler.active.tbl
        or (active and handler and handler.themes and handler.themes[active] and handler.themes[active].tbl)

    if arrow and NS.IsThemeKey(active) and activeTheme then
        SetThemeTextureShown(activeTheme.arrowTexture, not flag)
        SetThemeTextureShown(activeTheme.specularTexture, not flag)
        SetThemeTextureShown(activeTheme.arrivalSpecularTexture, not flag)
        if not flag then
            NS.ApplyTomTomArrowSkin()
        end
        return
    end

    if IsCombatLockdownActive()
        or (type(NS.IsTomTomCombatHidden) == "function" and NS.IsTomTomCombatHidden() == true)
    then
        return
    end

    if arrow and flag and type(arrow.Hide) == "function" then
        arrow:Hide()
    elseif tomtom and type(tomtom.ShowHideCrazyArrow) == "function" then
        tomtom:ShowHideCrazyArrow()
    end
end

function NS.IsTomTomArrowDisplaySuppressed(reason)
    if type(reason) == "string" and reason ~= "" then
        return themeState.arrowSuppressionReasons[reason] == true
    end
    return themeState.arrowSuppressed == true
end

function NS.ApplyTomTomArrowDefaults()
    if type(NS.ApplyTomTomScalePolicy) == "function" then
        NS.ApplyTomTomScalePolicy()
    end
    NS.HookTomTomThemeBridge()
    NS.ApplyTomTomArrowSkin()
end

NS.ApplyRegisteredArrowSkin = NS.ApplyTomTomArrowSkin
NS.HookRegisteredArrowSkinBridge = NS.HookTomTomThemeBridge
NS.SuppressRegisteredArrowDisplay = NS.SuppressTomTomArrowDisplay
NS.ApplyRegisteredArrowDefaults = NS.ApplyTomTomArrowDefaults

NS.RegisterArrowSkin("awp_stock", {
    displayName     = "AWP",
    preset          = "single_image",
    skinDir         = "Interface\\AddOns\\AzerothWaypoint\\media\\arrows\\awp_stock\\",
    arrivalTint     = { r = 0.15, g = 1.0, b = 0.15 }, -- Leave out or "none" to use stock arrival arrow
    specular        = true,                            -- opt in; expects skinDir.."specular"
    arrivalSpecular = false,                           -- opt in; expects skinDir.."arrival_specular"
    baseScale       = 0.8,
    navDrop         = -5,
})
NS.RegisterArrowSkin("awp_bomber", {
    displayName     = "AWP Bomber",
    preset          = "single_image",
    skinDir         = "Interface\\AddOns\\AzerothWaypoint\\media\\arrows\\awp_bomber\\",
    arrivalTint     = { r = 0.15, g = 1.0, b = 0.15 }, -- Leave out or "none" to use stock arrival arrow
    specular        = true,                            -- opt in; expects skinDir.."specular"
    arrivalSpecular = true,                            -- opt in; expects skinDir.."arrival_specular"
    baseScale       = 0.8,
    navDrop         = -5,
})
NS.RegisterArrowSkin("awp_modern", {
    displayName      = "AWP Modern",
    preset           = "single_image",
    skinDir          = "Interface\\AddOns\\AzerothWaypoint\\media\\arrows\\awp_modern\\",
    arrivalTint      = { r = 0.15, g = 1.0, b = 0.15 }, -- Leave out or "none" to use stock arrival arrow
    specular         = true,                            -- opt in; expects skinDir.."specular"
    arrivalSpecular  = false,                           -- opt in; expects skinDir.."arrival_specular"
    baseScale        = 0.8,                             -- applies to both nav and arrival
    arrivalBaseScale = 1,                               -- arrival only — overrides baseScale for arrival
    navDrop          = -12,
})
NS.RegisterArrowSkin("awp_horde", {
    displayName     = "Horde",
    preset          = "single_image",
    skinDir         = "Interface\\AddOns\\AzerothWaypoint\\media\\arrows\\awp_horde\\",
    specularAlpha   = 1,       -- opacity, default 0.7
    specularBlend   = "BLEND", -- blend mode, default "ADD"
    arrivalTint     = "none",  -- Leave out or "none" to use stock arrival arrow
    specular        = true,    -- opt in; expects skinDir.."specular"
    arrivalSpecular = false,   -- opt in; expects skinDir.."arrival_specular"
    navDrop         = -5,
})
NS.RegisterArrowSkin("awp_alliance", {
    displayName     = "Alliance",
    preset          = "single_image",
    skinDir         = "Interface\\AddOns\\AzerothWaypoint\\media\\arrows\\awp_alliance\\",
    specularAlpha   = 1,       -- opacity, default 0.7
    specularBlend   = "BLEND", -- blend mode, default "ADD"
    arrivalTint     = "none",  -- Leave out or "none" to use stock arrival arrow
    specular        = true,    -- opt in; expects skinDir.."specular"
    arrivalSpecular = false,   -- opt in; expects skinDir.."arrival_specular"
    navDrop         = -12,     -- adjusts gap between arrow and navigation text
})
