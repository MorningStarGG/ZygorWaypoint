local NS = _G.ZygorWaypointNS
local C = NS.Constants
local state = NS.State

state.theme = state.theme or {
    bridgeHooked = false,
    registered = false,
}

local themeState = state.theme

function NS.IsThemeKey(key)
    return key == C.THEME_STARLIGHT
end

local BASE_NAV_WIDTH = 56
local BASE_NAV_HEIGHT = 42
local BASE_ARRIVAL_SIZE = 40
local BASE_ARRIVAL_BOUNCE = 15
local BASE_NAV_DROP = 8
local BASE_ARRIVAL_DROP = 3

local function GetStarlightScale()
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

local function BuildTomTomStarlightTheme()
    local skinDir = "Interface\\AddOns\\ZygorGuidesViewer\\Arrows\\Starlight\\"
    local navTexture = skinDir .. "arrow"
    local specialsTexture = skinDir .. "specials"
    local hereL, hereR, hereT, hereB = 0, (1 / 8), 0, (1 / 2)

    local theme = {
        arrival_throttle = 0.016,
        navigation_throttle = 0.016,
    }

    local elapsedNav = 0

    function theme:ApplyTheme(button)
        local scale = GetStarlightScale()
        local navDrop = BASE_NAV_DROP * scale
        button:SetHeight(BASE_NAV_HEIGHT * scale)
        button:SetWidth(BASE_NAV_WIDTH * scale)

        if not self.arrowTexture then
            self.arrowTexture = button:CreateTexture(nil, "OVERLAY")
        end

        self.arrowTexture:ClearAllPoints()
        self.arrowTexture:SetPoint("TOPLEFT", button, "TOPLEFT", 0, 0)
        self.arrowTexture:SetPoint("BOTTOMRIGHT", button, "BOTTOMRIGHT", 0, -navDrop)
        self.arrowTexture:SetTexture(navTexture)
        self.arrowTexture:SetTexCoord(0, 1, 0, 1)
        self.arrowTexture:SetVertexColor(1, 1, 1, 1)
        self.arrowTexture:Show()

        if not self.navCoordResolver then
            self.navCoordResolver = BuildZygorNavResolver({
                spr_w = 102,
                spr_h = 68,
                img_w = 1024,
                img_h = 1024,
                spritecount = 150,
                mirror = true,
            })
        end

        if not self.arrivalAnim then
            local anim = self.arrowTexture:CreateAnimationGroup()
            anim:SetLooping("REPEAT")

            local up = anim:CreateAnimation("Translation")
            up:SetDuration(0.3)
            up:SetOrder(1)
            up:SetSmoothing("OUT")
            up:SetOffset(0, BASE_ARRIVAL_BOUNCE)

            local down = anim:CreateAnimation("Translation")
            down:SetDuration(0.3)
            down:SetOrder(2)
            down:SetSmoothing("IN")
            down:SetOffset(0, -BASE_ARRIVAL_BOUNCE)

            self.arrivalAnim = anim
            self.arrivalAnimUp = up
            self.arrivalAnimDown = down
        end

        if self.arrivalAnimUp and self.arrivalAnimDown then
            local bounce = BASE_ARRIVAL_BOUNCE * scale
            self.arrivalAnimUp:SetOffset(0, bounce)
            self.arrivalAnimDown:SetOffset(0, -bounce)
        end
    end

    function theme:RemoveTheme()
        if self.arrivalAnim then
            self.arrivalAnim:Stop()
        end
        if self.arrowTexture then
            self.arrowTexture:ClearAllPoints()
            self.arrowTexture:Hide()
        end
    end

    function theme:SwitchToArrivalArrow(button)
        local scale = GetStarlightScale()
        local arrow = self.arrowTexture
        if not arrow then return end

        arrow:ClearAllPoints()
        arrow:SetPoint("CENTER", button, "CENTER", 0, -(BASE_ARRIVAL_DROP * scale))
        arrow:SetSize(BASE_ARRIVAL_SIZE * scale, BASE_ARRIVAL_SIZE * scale)
        arrow:SetTexture(specialsTexture)
        arrow:SetTexCoord(hereL, hereR, hereT, hereB)
        arrow:SetVertexColor(1, 1, 1, 1)

        if self.arrivalAnim then
            self.arrivalAnim:Stop()
            self.arrivalAnim:Play()
        end
    end

    function theme:ArrivalArrow_OnUpdate()
        -- Arrival movement is handled by the AnimationGroup created in ApplyTheme.
    end

    function theme:SwitchToNavigationArrow(button)
        local scale = GetStarlightScale()
        local navDrop = BASE_NAV_DROP * scale
        local arrow = self.arrowTexture
        if not arrow then return end

        if self.arrivalAnim then
            self.arrivalAnim:Stop()
        end

        local anchor = button or arrow:GetParent()
        arrow:ClearAllPoints()
        arrow:SetPoint("TOPLEFT", anchor, "TOPLEFT", 0, 0)
        arrow:SetPoint("BOTTOMRIGHT", anchor, "BOTTOMRIGHT", 0, -navDrop)
        arrow:SetTexture(navTexture)
        arrow:SetTexCoord(0, 1, 0, 1)
        arrow:SetVertexColor(1, 1, 1, 1)
    end

    function theme:NavigationArrow_OnUpdate(elapsed, angle)
        elapsedNav = elapsedNav + elapsed
        if elapsedNav < self.navigation_throttle then return end
        elapsedNav = 0

        local arrow = self.arrowTexture
        if not arrow then return end

        local left, right, top, bottom = self.navCoordResolver(angle)
        arrow:SetTexture(navTexture)
        arrow:SetTexCoord(left, right, top, bottom)

        if TomTom and TomTom.db and TomTom.db.profile and TomTom.db.profile.arrow and TomTom.ColorGradient then
            local profile = TomTom.db.profile.arrow
            local perc = math.abs((math.pi - math.abs(angle or 0)) / math.pi)

            local gr, gg, gb = unpack(profile.goodcolor or { 0, 1, 0 })
            local mr, mg, mb = unpack(profile.middlecolor or { 1, 1, 0 })
            local br, bg, bb = unpack(profile.badcolor or { 1, 0, 0 })
            local r, g, b = TomTom:ColorGradient(perc, br, bg, bb, mr, mg, mb, gr, gg, gb)

            if perc > 0.98 and profile.exactcolor then
                r, g, b = unpack(profile.exactcolor)
            end
            arrow:SetVertexColor(r, g, b, 1)
        end
    end

    return theme
end

local function RegisterTomTomThemes()
    if themeState.registered then return true end
    if not TomTom or not TomTom.CrazyArrowThemeHandler then return false end

    local handler = TomTom.CrazyArrowThemeHandler
    if type(handler.RegisterCrazyArrowTheme) ~= "function" then return false end

    handler:RegisterCrazyArrowTheme(C.THEME_STARLIGHT, "Zygor Starlight", BuildTomTomStarlightTheme())
    themeState.registered = true
    return true
end

function NS.ApplyTomTomArrowSkin()
    if not TomTom or not TomTom.CrazyArrowThemeHandler then return end

    local wayframe = _G.TomTomCrazyArrow
    if not wayframe then return end

    local handler = TomTom.CrazyArrowThemeHandler
    local choice = NS.GetSkinChoice()

    if choice == C.SKIN_DEFAULT then
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
    if handler.themes and handler.themes[C.THEME_STARLIGHT] then
        handler:SetActiveTheme(wayframe, C.THEME_STARLIGHT, false)
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
