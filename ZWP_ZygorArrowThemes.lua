local NS = _G.ZygorWaypointNS
local C = NS.Constants
local state = NS.State

state.theme = state.theme or {
    bridgeHooked = false,
    registered = false,
}

local themeState = state.theme

local ZYGOR_THEME_DEFS = {
    [C.SKIN_STARLIGHT] = {
        themeKey = C.THEME_STARLIGHT,
        displayName = "Zygor Starlight",
        skinDir = "Interface\\AddOns\\ZygorGuidesViewer\\Arrows\\Starlight\\",
        navWidth = 56,
        navHeight = 42,
        navDrop = 8,
        arrivalWidth = 50,
        arrivalHeight = 40,
        arrivalBounce = 15,
        arrivalDrop = 3,
        sprite = {
            spr_w = 102,
            spr_h = 68,
            img_w = 1024,
            img_h = 1024,
            spritecount = 150,
            mirror = true,
        },
    },
    [C.SKIN_STEALTH] = {
        themeKey = C.THEME_STEALTH,
        displayName = "Zygor Stealth",
        skinDir = "Interface\\AddOns\\ZygorGuidesViewer\\Arrows\\Stealth\\",
        navWidth = 56,
        navHeight = 42,
        navDrop = 8,
        arrivalWidth = 40,
        arrivalHeight = 40,
        arrivalBounce = 15,
        arrivalDrop = 0,
        precise = {
            range = 3,
            smooth = false,
            r = 0.4,
            g = 1.0,
            b = 0.3,
        },
        sprite = {
            spr_w = 102,
            spr_h = 68,
            img_w = 1024,
            img_h = 1024,
            spritecount = 150,
            mirror = false,
        },
    },
}

function NS.IsThemeKey(key)
    return key == C.THEME_STARLIGHT or key == C.THEME_STEALTH
end

local function GetThemeScale()
    if type(NS.GetArrowScale) == "function" then
        return NS.GetArrowScale()
    end
    return C.SCALE_DEFAULT
end

local function BuildZygorNavResolver(opts)
    local sprite = {}
    local inrow = math.floor(opts.img_w / opts.spr_w)
    local w = opts.spr_w / opts.img_w
    local h = opts.spr_h / opts.img_h

    for num = 1, opts.spritecount do
        local row = math.floor((num - 1) / inrow)
        local col = (num - 1) % inrow
        local x1, x2 = col * w, (col + 1) * w
        local y1, y2 = row * h, (row + 1) * h
        sprite[num] = { x1, x2, y1, y2 }
    end

    if opts.mirror then
        local count = #sprite
        for numextra = 1, count - 2 do
            local truenum = count - numextra
            local c = sprite[truenum]
            sprite[count + numextra] = { c[2], c[1], c[3], c[4] }
        end
    end

    local totalFrames = #sprite
    local step = 360 / totalFrames
    local byDegree = {}
    for deg = 0, 359 do
        local index = math.floor(deg / step) + 1
        byDegree[deg] = sprite[index]
    end

    local rad2deg = 180 / math.pi
    return function(angle)
        local deg = math.floor((angle or 0) * rad2deg + 0.5) % 360
        local c = byDegree[deg]
        return c[1], c[2], c[3], c[4]
    end
end

local function BuildSpecialTexCoord(col, row, cols, rows, padding)
    local padX = (padding or 0) / cols
    local padY = (padding or 0) / rows
    return
        ((col - 1) / cols) + padX,
        (col / cols) - padX,
        ((row - 1) / rows) + padY,
        (row / rows) - padY
end

local function GetDirectionColor(themeDef, angle)
    local r, g, b = 1, 1, 1

    if TomTom and TomTom.db and TomTom.db.profile and TomTom.db.profile.arrow and TomTom.ColorGradient then
        local profile = TomTom.db.profile.arrow
        local perc = math.abs((math.pi - math.abs(angle or 0)) / math.pi)

        local gr, gg, gb = unpack(profile.goodcolor or { 0, 1, 0 })
        local mr, mg, mb = unpack(profile.middlecolor or { 1, 1, 0 })
        local br, bg, bb = unpack(profile.badcolor or { 1, 0, 0 })
        r, g, b = TomTom:ColorGradient(perc, br, bg, bb, mr, mg, mb, gr, gg, gb)

        if perc > 0.98 and profile.exactcolor then
            r, g, b = unpack(profile.exactcolor)
        end
    end

    local precise = themeDef.precise
    if precise and precise.range then
        local deg = math.floor((angle or 0) * (180 / math.pi) + 0.5) % 360
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
                r = precise.r or r
                g = precise.g or g
                b = precise.b or b
            end
        end
    end

    return r, g, b
end

local function GetNavigationTexCoord(theme)
    if theme.lastNavTexCoord then
        return unpack(theme.lastNavTexCoord)
    end

    if not theme.navCoordResolver then
        return 0, 1, 0, 1
    end

    local angle = theme.lastAngle or 0
    local left, right, top, bottom = theme.navCoordResolver(angle)
    theme.lastNavTexCoord = { left, right, top, bottom }
    return left, right, top, bottom
end

local function ApplyNavigationLayout(theme, button)
    local themeDef = theme.themeDef
    local scale = GetThemeScale()
    local navDrop = (themeDef.navDrop or 0) * scale

    button:SetHeight((themeDef.navHeight or 42) * scale)
    button:SetWidth((themeDef.navWidth or 56) * scale)

    local arrow = theme.arrowTexture
    if not arrow then return end

    arrow:ClearAllPoints()
    arrow:SetPoint("TOPLEFT", button, "TOPLEFT", 0, 0)
    arrow:SetPoint("BOTTOMRIGHT", button, "BOTTOMRIGHT", 0, -navDrop)
    arrow:SetTexture(theme.navTexture)
    arrow:SetTexCoord(GetNavigationTexCoord(theme))
    arrow:SetVertexColor(GetDirectionColor(themeDef, theme.lastAngle or 0))
    arrow:Show()

    if theme.specularTexture then
        local specular = theme.specularTexture
        specular:ClearAllPoints()
        specular:SetPoint("TOPLEFT", button, "TOPLEFT", 0, 0)
        specular:SetPoint("BOTTOMRIGHT", button, "BOTTOMRIGHT", 0, -navDrop)
        specular:SetTexture(theme.specularTexturePath)
        specular:SetTexCoord(GetNavigationTexCoord(theme))
        specular:SetVertexColor(1, 1, 1, 1)
        specular:SetAlpha(0.7)
        specular:Show()
    end
end

local function EnsureArrivalAnimation(theme)
    if theme.arrivalAnim then return end

    local arrow = theme.arrowTexture
    if not arrow then return end

    local anim = arrow:CreateAnimationGroup()
    anim:SetLooping("REPEAT")

    local up = anim:CreateAnimation("Translation")
    up:SetDuration(0.3)
    up:SetOrder(1)
    up:SetSmoothing("OUT")
    up:SetOffset(0, theme.themeDef.arrivalBounce or 15)

    local down = anim:CreateAnimation("Translation")
    down:SetDuration(0.3)
    down:SetOrder(2)
    down:SetSmoothing("IN")
    down:SetOffset(0, -(theme.themeDef.arrivalBounce or 15))

    theme.arrivalAnim = anim
    theme.arrivalAnimUp = up
    theme.arrivalAnimDown = down
end

local function UpdateArrivalAnimationScale(theme)
    if not theme.arrivalAnimUp or not theme.arrivalAnimDown then return end

    local bounce = (theme.themeDef.arrivalBounce or 15) * GetThemeScale()
    theme.arrivalAnimUp:SetOffset(0, bounce)
    theme.arrivalAnimDown:SetOffset(0, -bounce)
end

local function BuildTomTomZygorTheme(themeDef)
    local theme = {
        themeDef = themeDef,
        navTexture = themeDef.skinDir .. "arrow",
        specularTexturePath = themeDef.skinDir .. "arrow-specular",
        specialsTexture = themeDef.skinDir .. "specials",
        arrivalTexCoord = {
            BuildSpecialTexCoord(1, 1, 8, 2, 0),
        },
        arrival_throttle = 0.016,
        navigation_throttle = 0.016,
        elapsedNav = 0,
    }

    function theme:ApplyTheme(button)
        if not self.arrowTexture then
            self.arrowTexture = button:CreateTexture(nil, "OVERLAY")
        end

        if not self.specularTexture then
            self.specularTexture = button:CreateTexture(nil, "OVERLAY")
            if self.specularTexture.SetBlendMode then
                self.specularTexture:SetBlendMode("ADD")
            end
        end

        if not self.navCoordResolver then
            self.navCoordResolver = BuildZygorNavResolver(self.themeDef.sprite)
        end

        EnsureArrivalAnimation(self)
        UpdateArrivalAnimationScale(self)
        ApplyNavigationLayout(self, button)
    end

    function theme:RemoveTheme()
        if self.arrivalAnim then
            self.arrivalAnim:Stop()
        end
        if self.arrowTexture then
            self.arrowTexture:ClearAllPoints()
            self.arrowTexture:Hide()
        end
        if self.specularTexture then
            self.specularTexture:ClearAllPoints()
            self.specularTexture:Hide()
        end
    end

    function theme:SwitchToArrivalArrow(button)
        local scale = GetThemeScale()
        local arrow = self.arrowTexture
        if not arrow then return end

        arrow:ClearAllPoints()
        arrow:SetPoint("CENTER", button, "CENTER", 0, -((self.themeDef.arrivalDrop or 0) * scale))
        arrow:SetSize((self.themeDef.arrivalWidth or 40) * scale, (self.themeDef.arrivalHeight or 40) * scale)
        arrow:SetTexture(self.specialsTexture)
        arrow:SetTexCoord(unpack(self.arrivalTexCoord))
        arrow:SetVertexColor(1, 1, 1, 1)

        if self.specularTexture then
            self.specularTexture:Hide()
        end

        if self.arrivalAnim then
            UpdateArrivalAnimationScale(self)
            self.arrivalAnim:Stop()
            self.arrivalAnim:Play()
        end
    end

    function theme:ArrivalArrow_OnUpdate()
        -- Arrival movement is handled by the AnimationGroup created in ApplyTheme.
    end

    function theme:SwitchToNavigationArrow(button)
        if self.arrivalAnim then
            self.arrivalAnim:Stop()
        end

        local anchor = button or (self.arrowTexture and self.arrowTexture:GetParent())
        if not anchor then return end

        ApplyNavigationLayout(self, anchor)
    end

    function theme:NavigationArrow_OnUpdate(elapsed, angle)
        self.elapsedNav = self.elapsedNav + elapsed
        if self.elapsedNav < self.navigation_throttle then return end
        self.elapsedNav = 0

        local arrow = self.arrowTexture
        if not arrow then return end

        self.lastAngle = angle
        local left, right, top, bottom = self.navCoordResolver(angle)
        self.lastNavTexCoord = { left, right, top, bottom }
        arrow:SetTexture(self.navTexture)
        arrow:SetTexCoord(left, right, top, bottom)

        if self.specularTexture then
            self.specularTexture:SetTexture(self.specularTexturePath)
            self.specularTexture:SetTexCoord(left, right, top, bottom)
            self.specularTexture:SetVertexColor(1, 1, 1, 1)
            self.specularTexture:SetAlpha(0.7)
            self.specularTexture:Show()
        end

        local r, g, b = GetDirectionColor(self.themeDef, angle)
        arrow:SetVertexColor(r, g, b, 1)
    end

    return theme
end

local function GetThemeDefForSkin(skin)
    return ZYGOR_THEME_DEFS[skin]
end

local function RegisterTomTomThemes()
    if themeState.registered then return true end
    if not TomTom or not TomTom.CrazyArrowThemeHandler then return false end

    local handler = TomTom.CrazyArrowThemeHandler
    if type(handler.RegisterCrazyArrowTheme) ~= "function" then return false end

    for _, themeDef in pairs(ZYGOR_THEME_DEFS) do
        handler:RegisterCrazyArrowTheme(themeDef.themeKey, themeDef.displayName, BuildTomTomZygorTheme(themeDef))
    end

    themeState.registered = true
    return true
end

function NS.ApplyTomTomArrowSkin()
    if not TomTom or not TomTom.CrazyArrowThemeHandler then return end

    local wayframe = _G.TomTomCrazyArrow
    if not wayframe then return end

    local handler = TomTom.CrazyArrowThemeHandler
    local choice = NS.GetSkinChoice()
    local themeDef = GetThemeDefForSkin(choice)

    if not themeDef then
        local active = (handler.GetActiveTheme and handler:GetActiveTheme()) or handler.activeKey
        if NS.IsThemeKey(active) then
            local fallback = (TomTom.db and TomTom.db.profile and TomTom.db.profile.arrow and TomTom.db.profile.arrow.theme) or "modern"
            if NS.IsThemeKey(fallback) then
                fallback = "modern"
            end

            if handler.themes and not handler.themes[fallback] then
                if handler.themes.modern then
                    fallback = "modern"
                elseif handler.themes.classic then
                    fallback = "classic"
                else
                    fallback = next(handler.themes)
                end
            end

            if fallback and handler.themes and handler.themes[fallback] then
                handler:SetActiveTheme(wayframe, fallback, false)
            end
        end
        return
    end

    if not RegisterTomTomThemes() then return end
    if handler.themes and handler.themes[themeDef.themeKey] then
        local active = handler.active and handler.active.tbl
        local activeKey = (handler.GetActiveTheme and handler:GetActiveTheme()) or handler.activeKey
        if activeKey == themeDef.themeKey and active then
            active:ApplyTheme(wayframe)
            if active.arrowTexture and active.arrowTexture:GetTexture() == active.specialsTexture then
                active:SwitchToArrivalArrow(wayframe)
            else
                active:SwitchToNavigationArrow(wayframe)
            end
            return
        end

        handler:SetActiveTheme(wayframe, themeDef.themeKey, false)
    end
end

function NS.HookTomTomThemeBridge()
    if themeState.bridgeHooked then return end
    if not TomTom then return end

    themeState.bridgeHooked = true

    if type(TomTom.ShowHideCrazyArrow) == "function" then
        hooksecurefunc(TomTom, "ShowHideCrazyArrow", function()
            NS.After(0, NS.ApplyTomTomArrowSkin)
        end)
    end

    if type(TomTom.SetCrazyArrow) == "function" then
        hooksecurefunc(TomTom, "SetCrazyArrow", function()
            NS.After(0, NS.ApplyTomTomArrowSkin)
        end)
    end
end
