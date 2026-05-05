local NS = _G.AzerothWaypointNS

local UIStyle = NS.UIStyle or {}
NS.UIStyle = UIStyle

function UIStyle.SetColorTexture(texture, color)
    if texture and type(texture.SetColorTexture) == "function" and type(color) == "table" then
        texture:SetColorTexture(color[1] or 0, color[2] or 0, color[3] or 0, color[4] or 1)
    end
end

function UIStyle.AddSimpleBorder(parent)
    if not parent or parent._awpSimpleBorder then
        return
    end
    parent._awpSimpleBorder = true

    local function border(pointA, pointB, isHorizontal, r, g, b, a)
        local tex = parent:CreateTexture(nil, "BORDER")
        tex:SetPoint(pointA, parent, pointA, 0, 0)
        tex:SetPoint(pointB, parent, pointB, 0, 0)
        tex:SetColorTexture(r, g, b, a)
        if isHorizontal then
            tex:SetHeight(1)
        else
            tex:SetWidth(1)
        end
        return tex
    end

    border("TOPLEFT", "TOPRIGHT", true, 0.62, 0.45, 0.18, 0.78)
    border("BOTTOMLEFT", "BOTTOMRIGHT", true, 0.62, 0.45, 0.18, 0.70)
    border("TOPLEFT", "BOTTOMLEFT", false, 0.62, 0.45, 0.18, 0.70)
    border("TOPRIGHT", "BOTTOMRIGHT", false, 0.62, 0.45, 0.18, 0.70)
end

function UIStyle.CreatePanelButton(parent, text, onClick, width, height)
    local button = CreateFrame("Button", nil, parent)
    button:SetSize(width or 116, height or 28)

    button.bg = button:CreateTexture(nil, "BACKGROUND")
    button.bg:SetAllPoints()
    UIStyle.SetColorTexture(button.bg, { 0.045, 0.033, 0.025, 0.96 })

    button.border = button:CreateTexture(nil, "BORDER")
    button.border:SetAllPoints()
    UIStyle.SetColorTexture(button.border, { 0.62, 0.42, 0.18, 0.50 })

    button.inset = button:CreateTexture(nil, "ARTWORK")
    button.inset:SetPoint("TOPLEFT", button, "TOPLEFT", 1, -1)
    button.inset:SetPoint("BOTTOMRIGHT", button, "BOTTOMRIGHT", -1, 1)
    UIStyle.SetColorTexture(button.inset, { 0.018, 0.014, 0.012, 0.94 })

    button.label = button:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    button.label:SetPoint("LEFT", button, "LEFT", 8, 0)
    button.label:SetPoint("RIGHT", button, "RIGHT", -8, 0)
    button.label:SetJustifyH("CENTER")
    button.label:SetTextColor(1.0, 0.82, 0.0, 1)
    button.label:SetText(text or "")

    button:SetScript("OnEnter", function(self)
        UIStyle.SetColorTexture(self.inset, { 0.090, 0.060, 0.030, 0.96 })
        self.label:SetTextColor(1.0, 0.95, 0.35, 1)
    end)
    button:SetScript("OnLeave", function(self)
        UIStyle.SetColorTexture(self.inset, { 0.018, 0.014, 0.012, 0.94 })
        self.label:SetTextColor(1.0, 0.82, 0.0, 1)
    end)
    button:SetScript("OnMouseDown", function(self)
        UIStyle.SetColorTexture(self.inset, { 0.010, 0.008, 0.007, 0.98 })
        self.label:SetPoint("LEFT", self, "LEFT", 9, -1)
        self.label:SetPoint("RIGHT", self, "RIGHT", -7, -1)
    end)
    button:SetScript("OnMouseUp", function(self)
        self.label:SetPoint("LEFT", self, "LEFT", 8, 0)
        self.label:SetPoint("RIGHT", self, "RIGHT", -8, 0)
    end)
    button:SetScript("OnClick", onClick)

    return button
end
