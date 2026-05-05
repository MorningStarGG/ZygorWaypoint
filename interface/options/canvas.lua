local NS                     = _G.AzerothWaypointNS
local C                      = NS.Constants
NS.Internal.Interface        = NS.Internal.Interface or {}
NS.Internal.Interface.canvas = NS.Internal.Interface.canvas or {}
local M                      = NS.Internal.Interface.canvas
local FW                     = NS.Internal.Interface.Framework

-- WoW API globals (declared locally to satisfy the linter)
local CreateFrame            = _G.CreateFrame
local GameTooltip            = _G.GameTooltip
local ColorPickerFrame       = _G["ColorPickerFrame"] ---@type table
local UIParent               = _G.UIParent

-- The language server has no WoW Frame C API type stubs, so suppress the two
-- false-positive codes that fire on every Frame method call in this file.
---@diagnostic disable: need-check-nil, undefined-field

-- ============================================================
-- Layout constants
-- ============================================================

local ICON_PATH              = "Interface\\AddOns\\AzerothWaypoint\\media\\icon.png"
local MEDIA_HELP             = "Interface\\AddOns\\AzerothWaypoint\\media\\help\\"
local PANEL_W                = 950
local PANEL_H                = 586
local NAV_W                  = 225
local PREVIEW_W              = 350
local HEADER_H               = 46
local FOOTER_H               = 42
local NAV_BTN_H              = 26
local TOGGLE_H               = 34
local SLIDER_H               = 52
local DROPDOWN_H             = 50
local COLOR_H                = 50
local SECTION_H              = 28
local SPACER_H               = 6
local PAD                    = 16
local SCROLL_GUTTER          = 18

local PREVIEW_MAX_W          = PREVIEW_W - 16
local PREVIEW_MAX_H          = math.floor(PREVIEW_MAX_W * 0.625)

local COLOR_PANEL            = { 0.055, 0.040, 0.030, 0.88 }
local COLOR_LINE             = { 0.52, 0.35, 0.16, 0.55 }
local COLOR_GOLD             = { 1.00, 0.82, 0.00, 1.00 }
local COLOR_TEXT_DIM         = { 0.72, 0.66, 0.58, 1.00 }

local Data                   = M.Data or {}
local SECTION_DEFS           = Data.SECTION_DEFS or {}
local ZYGOR_SECTION          = Data.ZYGOR_SECTION or {}
local OPTION_PREVIEWS        = Data.OPTION_PREVIEWS or {}
local OPTION_VALUE_PREVIEWS  = Data.OPTION_VALUE_PREVIEWS or {}
local COLOR_VALUE_PREVIEWS   = Data.COLOR_OPTION_VALUE_PREVIEWS or {}
local PREVIEW_IMAGE_SIZES    = Data.PREVIEW_IMAGE_SIZES or {}
local OPTIONS                = Data.OPTIONS or {}
local SEARCH_FILTERS         = Data.SEARCH_FILTERS or {}

-- ============================================================
-- Runtime state  (rebuilt each time a section is rendered)
-- ============================================================

local activeKey              = "about"
local activeTab              = "modules"
local lastModuleKey          = "about"
local navButtons             = {}
local tabButtons             = {}
local scrollChild            = nil
local scrollFrame            = nil
local previewImage           = nil
local previewAnchor          = nil
local previewBorder          = nil
local previewBg              = nil
local previewLine            = nil
local previewDesc            = nil
local previewLogo            = nil
local searchBox              = nil
local searchFilterButton     = nil
local searchQuery            = ""
local searchScope            = "all"
local SelectSection          = nil
local cursorY                = 0
local sections               = nil -- filled in Create()
local lastPreviewImage       = nil
local lastPreviewDesc        = nil
local lastPreviewMeta        = nil

-- ============================================================
-- Helpers
-- ============================================================

local function GetOpts() return NS.Internal.Interface.options end

local function UnpackOptions(optionsFunc)
    local raw = optionsFunc()
    if type(raw) ~= "table" then return {} end
    local out = {}
    for _, item in ipairs(raw) do
        if type(item) == "table" then
            out[#out + 1] = {
                value = item.value,
                text = item.label or item.text or tostring(item.value),
                disabled = item.disabled == true,
                disabledReason = item.disabledReason or item.tooltip or item.desc,
            }
        end
    end
    return out
end

local function GetOptionText(optionsFunc, value)
    for _, opt in ipairs(UnpackOptions(optionsFunc)) do
        if opt.value == value then return opt.text end
    end
    return tostring(value)
end

local function GetPreviewNativeSize(imagePath, meta)
    if type(meta) == "table" then
        local w = meta.imageW or meta.w or meta.width
        local h = meta.imageH or meta.h or meta.height

        if type(meta.imageSize) == "table" then
            w = w or meta.imageSize.w or meta.imageSize.width
            h = h or meta.imageSize.h or meta.imageSize.height
        end

        if tonumber(w) and tonumber(h) then
            return tonumber(w), tonumber(h)
        end
    end

    local size = imagePath and PREVIEW_IMAGE_SIZES[imagePath]
    if type(size) == "table" then
        local w = size.imageW or size.w or size.width
        local h = size.imageH or size.h or size.height

        if tonumber(w) and tonumber(h) then
            return tonumber(w), tonumber(h)
        end
    end

    -- Fallback: WoW Texture paths do not reliably expose native image dimensions.
    -- Unknown images use the preview area's default ratio unless imageW/imageH are provided.
    return PREVIEW_MAX_W, PREVIEW_MAX_H
end

local function ApplyPreviewTexture(imagePath, nativeW, nativeH)
    if not previewImage or not previewAnchor or not previewBorder or not imagePath then return end

    previewImage:SetTexture(imagePath)

    nativeW = tonumber(nativeW) or PREVIEW_MAX_W
    nativeH = tonumber(nativeH) or PREVIEW_MAX_H

    if nativeW <= 0 or nativeH <= 0 then
        nativeW, nativeH = PREVIEW_MAX_W, PREVIEW_MAX_H
    end

    -- Fit inside the preview box, preserve the native image ratio,
    -- and do not upscale images smaller than the preview area.
    local scale = math.min(1, PREVIEW_MAX_W / nativeW, PREVIEW_MAX_H / nativeH)
    local displayW = math.max(1, math.floor(nativeW * scale + 0.5))
    local displayH = math.max(1, math.floor(nativeH * scale + 0.5))

    -- Border follows the actual displayed image size.
    previewBorder:ClearAllPoints()
    previewBorder:SetSize(displayW + 2, displayH + 2)
    previewBorder:SetPoint("CENTER", previewAnchor, "CENTER", 0, 0)

    previewImage:ClearAllPoints()
    previewImage:SetSize(displayW, displayH)
    previewImage:SetPoint("CENTER", previewBorder, "CENTER", 0, 0)
end

local function SetPreview(imagePath, desc, meta)
    if imagePath then
        lastPreviewImage = imagePath
        lastPreviewMeta = meta
    elseif meta then
        lastPreviewMeta = meta
    end

    if desc ~= nil then
        lastPreviewDesc = desc
    end

    if previewImage and imagePath then
        local nativeW, nativeH = GetPreviewNativeSize(imagePath, meta)
        ApplyPreviewTexture(imagePath, nativeW, nativeH)
    end

    if previewDesc then
        previewDesc:SetText(desc or "")
    end
end

local function RestoreSectionPreview()
    if previewImage and lastPreviewImage then
        local nativeW, nativeH = GetPreviewNativeSize(lastPreviewImage, lastPreviewMeta)
        ApplyPreviewTexture(lastPreviewImage, nativeW, nativeH)
    end

    if previewDesc then
        previewDesc:SetText(lastPreviewDesc or "")
    end
end

local function ShowHoverPreview(label)
    local preview = OPTION_PREVIEWS[label]
    if preview and previewImage then
        local nativeW, nativeH = GetPreviewNativeSize(preview.image, preview)
        ApplyPreviewTexture(preview.image, nativeW, nativeH)
        if previewDesc then previewDesc:SetText(preview.desc or "") end
    end
end

local function ApplyPreview(preview)
    if type(preview) ~= "table" or not previewImage then
        return false
    end

    if preview.image then
        local nativeW, nativeH = GetPreviewNativeSize(preview.image, preview)
        ApplyPreviewTexture(preview.image, nativeW, nativeH)
    end

    if previewDesc then
        previewDesc:SetText(preview.desc or "")
    end

    return true
end

local function ShowDropdownOptionPreview(label, value, text)
    local previewByValue = OPTION_VALUE_PREVIEWS[label]
    local preview = previewByValue and (previewByValue[value] or previewByValue[text]) or nil
    preview = preview or COLOR_VALUE_PREVIEWS[value] or COLOR_VALUE_PREVIEWS[text] or OPTION_PREVIEWS[label]

    if not ApplyPreview(preview) then
        ShowHoverPreview(label)
    end
end

local function ShowTip(owner, label, tooltip)
    ShowHoverPreview(label)
    if not tooltip then return end
    GameTooltip:SetOwner(owner, "ANCHOR_CURSOR_RIGHT")
    GameTooltip:SetText(label, 1, 1, 1, 1, true)
    GameTooltip:AddLine(tooltip, nil, nil, nil, true)
    GameTooltip:Show()
end

local function HideTip()
    GameTooltip:Hide()
    RestoreSectionPreview()
end

function M.RestoreSectionPreview()
    RestoreSectionPreview()
end

function M.ShowDropdownOptionPreview(label, value, text)
    ShowDropdownOptionPreview(label, value, text)
end

local ColorTexture = FW.ColorTexture

local function NormalizeSearchText(text)
    text = tostring(text or "")
    text = text:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "")
    text = text:gsub("^%s+", ""):gsub("%s+$", "")
    return text:lower()
end

local function EntryMatchesSearch(entry, query)
    if query == "" then return false end
    return NormalizeSearchText(entry.label):find(query, 1, true)
        or NormalizeSearchText(entry.desc):find(query, 1, true)
        or NormalizeSearchText(entry.sectionLabel):find(query, 1, true)
        or (entry.tags ~= nil and NormalizeSearchText(entry.tags):find(query, 1, true))
end

local function ShortVersion(version)
    version = tostring(version or "")
    local major, minor, patch = version:match("^(%d+)%.(%d+)%.(%d+)")
    if major and minor and patch == "0" then
        return major .. "." .. minor
    end
    return version
end

local function GetSettingMarker(label)
    for _, entry in ipairs(OPTIONS) do
        if entry.label == label and (entry.added or entry.updated or entry.note) then
            return entry
        end
    end
    return nil
end

local function IsCurrentVersion(version)
    if type(version) ~= "string" or version == "" then return false end
    if type(NS.CompareAddonVersions) == "function" then
        return NS.CompareAddonVersions(version, NS.VERSION) == 0
    end
    return version == NS.VERSION
end

local function IsVersionNewer(left, right)
    if type(left) ~= "string" or left == "" then return false end
    if type(right) ~= "string" or right == "" then return true end
    if type(NS.CompareAddonVersions) == "function" then
        return NS.CompareAddonVersions(left, right) > 0
    end
    return left > right
end

local function GetSettingMarkerStatus(label)
    local marker = GetSettingMarker(label)
    if not marker then return nil, nil, nil end

    local added = marker.added
    local updated = marker.updated
    if IsCurrentVersion(added) then
        return "new", marker, added
    end
    if IsCurrentVersion(updated) and IsVersionNewer(updated, added) then
        return "updated", marker, updated
    end
    return nil, marker, updated or added
end

local function GetSettingMarkerSummary(label)
    local status, marker, markerVersion = GetSettingMarkerStatus(label)
    if not marker then return nil end

    local version = ShortVersion(markerVersion or marker.added or "")
    local summary = nil
    if status == "new" then
        summary = version ~= "" and ("New in " .. version .. ".") or "New."
    elseif status == "updated" then
        summary = version ~= "" and ("Updated in " .. version .. ".") or "Updated."
    elseif marker.added then
        summary = "Added in " .. ShortVersion(marker.added) .. "."
    end

    if marker.note and (status == "new" or status == "updated") then
        return summary and (summary .. " " .. marker.note) or marker.note
    end
    return summary
end

local function GetSectionLabel(key)
    if key == "release" then return "Release Notes" end
    for _, sec in ipairs(sections or SECTION_DEFS) do
        if sec.key == key then return sec.label end
    end
    if key == ZYGOR_SECTION.key then return ZYGOR_SECTION.label end
    return tostring(key or "")
end

local function IsSectionAvailable(key)
    if key == "release" or key == "about" then return true end
    for _, sec in ipairs(sections or SECTION_DEFS) do
        if sec.key == key then return true end
    end
    return false
end

local function TextHas(text, ...)
    text = NormalizeSearchText(text)
    for index = 1, select("#", ...) do
        local needle = NormalizeSearchText(select(index, ...))
        if needle ~= "" and text:find(needle, 1, true) then
            return true
        end
    end
    return false
end

local function SearchScopeAllows(entry)
    if searchScope == "all" then return true end
    if not entry then return false end

    local key = entry.key
    local label = entry.label or ""
    local desc = entry.desc or ""
    local haystack = label .. " " .. desc

    if searchScope == "new" then
        local status = GetSettingMarkerStatus(label)
        return status == "new"
    elseif searchScope == "updated" then
        local status = GetSettingMarkerStatus(label)
        return status == "updated"
    elseif searchScope == "navigation" then
        return TextHas(haystack,
            "routing", "backend", "manual", "queue", "quest", "supertracked",
            "arrival", "clear", "waypoint clear", "auto-route")
    elseif searchScope == "visual" then
        return key == "overlay" or key == "waypoint" or key == "pinpoint" or key == "navigator"
            or TextHas(haystack, "arrow skin", "arrow scale", "overlay", "marker", "navigator", "special travel")
    elseif searchScope == "sizing" then
        return TextHas(label,
            "size", "scale", "opacity", "distance", "offset", "height",
            "show pinpoint at", "hide pinpoint at")
    elseif searchScope == "styles" then
        return TextHas(label,
                "skin", "style", "color", "context display", "diamond", "icons",
                "footer text", "text", "plaque", "animated parts", "chevrons", "navigator arrow")
            or TextHas(entry.tags or "", "color")
    elseif searchScope == "integrations" then
        return key == "tomtom" or key == "zygor"
            or TextHas(haystack, "tomtom", "zygor", "backend", "farstrider", "mapzeroth", "special travel")
    end

    return true
end

local function GetScrollContentWidth()
    if not scrollFrame then return 1 end
    local bodyFrame = scrollFrame:GetParent()
    local bodyWidth = bodyFrame and (bodyFrame:GetWidth() or 0) or 0
    if bodyWidth < 2 then
        bodyWidth = PANEL_W
    end

    local expectedWidth = bodyWidth - NAV_W - (activeKey == "release" and 0 or PREVIEW_W)
    local width = scrollFrame:GetWidth() or 0
    if width < 2 or width < expectedWidth - 2 or width > expectedWidth + 2 then
        width = expectedWidth
    end
    return math.max(1, math.floor(width - SCROLL_GUTTER))
end

local function SetPreviewColumnShown(shown)
    for _, widget in ipairs({ previewBg, previewLine, previewAnchor, previewBorder, previewImage, previewDesc, previewLogo }) do
        if widget and type(widget.SetShown) == "function" then
            widget:SetShown(shown)
        end
    end
end

local function UpdateContentLayoutForSection(key)
    if not scrollFrame then
        return
    end

    local bodyFrame = scrollFrame:GetParent()
    if not bodyFrame then
        return
    end

    local releaseLayout = key == "release"
    SetPreviewColumnShown(not releaseLayout)

    scrollFrame:ClearAllPoints()
    scrollFrame:SetPoint("TOPLEFT", bodyFrame, "TOPLEFT", NAV_W, 0)
    if releaseLayout then
        scrollFrame:SetPoint("BOTTOMRIGHT", bodyFrame, "BOTTOMRIGHT", 0, 0)
    else
        scrollFrame:SetPoint("BOTTOMRIGHT", bodyFrame, "BOTTOMRIGHT", -PREVIEW_W, 0)
    end
end

local function CreateDropdownButton(parent)
    local btn = FW.CreatePanelButton(parent)
    btn.label:ClearAllPoints()
    btn.label:SetPoint("LEFT", btn, "LEFT", 9, 0)
    btn.label:SetPoint("RIGHT", btn, "RIGHT", -28, 0)
    btn.label:SetJustifyH("LEFT")

    btn.arrow = btn:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    btn.arrow:SetPoint("RIGHT", btn, "RIGHT", -10, 0)
    btn.arrow:SetText("v")
    btn.arrow:SetTextColor(0.95, 0.75, 0.35, 1)

    return btn
end

local function CreateSearchBox(parent)
    local box = CreateFrame("EditBox", nil, parent)
    box:SetAutoFocus(false)
    box:SetFontObject(_G.GameFontHighlightSmall)
    box:SetTextInsets(24, 24, 0, 0)
    box:SetHeight(26)

    box.bg = box:CreateTexture(nil, "BACKGROUND")
    box.bg:SetAllPoints()
    ColorTexture(box.bg, { 0.025, 0.022, 0.020, 0.92 })

    box.border = box:CreateTexture(nil, "BORDER")
    box.border:SetAllPoints()
    ColorTexture(box.border, { 0.38, 0.27, 0.17, 0.62 })

    box.inset = box:CreateTexture(nil, "ARTWORK")
    box.inset:SetPoint("TOPLEFT", box, "TOPLEFT", 1, -1)
    box.inset:SetPoint("BOTTOMRIGHT", box, "BOTTOMRIGHT", -1, 1)
    ColorTexture(box.inset, { 0.012, 0.012, 0.012, 0.96 })

    box.icon = box:CreateTexture(nil, "OVERLAY")
    box.icon:SetSize(14, 14)
    box.icon:SetPoint("LEFT", box, "LEFT", 7, 0)
    box.icon:SetTexture("Interface\\Common\\UI-Searchbox-Icon")
    box.icon:SetVertexColor(0.55, 0.55, 0.55, 0.9)

    box.placeholder = box:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    box.placeholder:SetPoint("LEFT", box, "LEFT", 26, 0)
    box.placeholder:SetPoint("RIGHT", box, "RIGHT", -24, 0)
    box.placeholder:SetJustifyH("LEFT")
    box.placeholder:SetText(SEARCH or "Search")

    box.clear = CreateFrame("Button", nil, box)
    box.clear:SetSize(20, 20)
    box.clear:SetPoint("RIGHT", box, "RIGHT", -3, 0)
    box.clear:SetScript("OnClick", function(self)
        self:GetParent():SetText("")
        self:GetParent():SetFocus()
    end)
    box.clear.text = box.clear:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    box.clear.text:SetPoint("CENTER", box.clear, "CENTER", 0, 1)
    box.clear.text:SetText("x")
    box.clear:Hide()

    local function updateVisual(self)
        local hasText = self:GetText() ~= ""
        self.placeholder:SetShown(not hasText and not self:HasFocus())
        self.clear:SetShown(hasText)
        if self:HasFocus() then
            ColorTexture(self.inset, { 0.030, 0.026, 0.022, 0.98 })
            ColorTexture(self.border, { 0.86, 0.62, 0.30, 0.72 })
            self.icon:SetVertexColor(0.92, 0.82, 0.68, 1)
        else
            ColorTexture(self.inset, { 0.012, 0.012, 0.012, 0.96 })
            ColorTexture(self.border, { 0.38, 0.27, 0.17, 0.62 })
            self.icon:SetVertexColor(0.55, 0.55, 0.55, 0.9)
        end
    end

    box:SetScript("OnEditFocusGained", updateVisual)
    box:SetScript("OnEditFocusLost", updateVisual)
    box:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
    box:SetScript("OnEnterPressed", function(self) self:ClearFocus() end)
    box:SetScript("OnTextChanged", function(self)
        searchQuery = NormalizeSearchText(self:GetText())
        updateVisual(self)
        if searchQuery ~= "" or searchScope ~= "all" then
            SelectSection("search")
        elseif activeKey == "search" then
            SelectSection(lastModuleKey or "about")
        end
    end)

    return box
end

local function GetSearchFilterText()
    for _, option in ipairs(SEARCH_FILTERS) do
        if option.value == searchScope then
            return option.text
        end
    end
    return "All Settings"
end

local function GetSearchFilterDescription()
    for _, option in ipairs(SEARCH_FILTERS) do
        if option.value == searchScope then
            return option.desc
        end
    end
    return nil
end

local function CreateSearchFilterButton(parent)
    local btn = FW.CreatePanelButton(parent)
    btn:SetSize(30, 26)
    btn:SetDisplayText("")

    btn.iconTop = btn:CreateTexture(nil, "OVERLAY")
    btn.iconTop:SetSize(13, 2)
    btn.iconTop:SetPoint("CENTER", btn, "CENTER", 0, 5)

    btn.iconMid = btn:CreateTexture(nil, "OVERLAY")
    btn.iconMid:SetSize(9, 2)
    btn.iconMid:SetPoint("CENTER", btn, "CENTER", 0, 1)

    btn.iconStem = btn:CreateTexture(nil, "OVERLAY")
    btn.iconStem:SetSize(3, 7)
    btn.iconStem:SetPoint("TOP", btn.iconMid, "BOTTOM", 0, -1)

    local function SetFilterIconColor(self, alpha)
        local color = { 1.0, 0.72, 0.28, alpha or 1 }
        ColorTexture(self.iconTop, color)
        ColorTexture(self.iconMid, color)
        ColorTexture(self.iconStem, color)
    end
    SetFilterIconColor(btn, 0.92)

    btn:SetScript("OnEnter", function(self)
        ColorTexture(self.inset, { 0.090, 0.060, 0.030, 0.95 })
        SetFilterIconColor(self, 1)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText("Search Filter", 1, 1, 1, 1, true)
        GameTooltip:AddLine(GetSearchFilterText(), nil, nil, nil, true)
        GameTooltip:Show()
    end)
    btn:SetScript("OnLeave", function(self)
        ColorTexture(self.inset, { 0.020, 0.016, 0.014, 0.92 })
        SetFilterIconColor(self, 0.92)
        GameTooltip:Hide()
    end)
    btn:SetScript("OnClick", function(self)
        if not (M.Dropdown and M.Dropdown.Open) then return end
        M.Dropdown.Open(self, {
            label = "Search Filter",
            options = SEARCH_FILTERS,
            currentValue = searchScope,
            width = 178,
            onSelect = function(value)
                searchScope = value or "all"
                SelectSection("search")
            end,
        })
    end)

    return btn
end

local function AddSettingMarkerTag(parent, label)
    local status, marker, markerVersion = GetSettingMarkerStatus(label)
    if not status or not marker then return nil end

    local tag = parent:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    local version = ShortVersion(markerVersion or marker.added or "")
    if status == "updated" then
        tag:SetText(version ~= "" and ("UPDATED " .. version) or "UPDATED")
        tag:SetTextColor(0.42, 0.75, 1.00, 1)
    else
        tag:SetText(version ~= "" and ("NEW " .. version) or "NEW")
        tag:SetTextColor(1.00, 0.58, 0.18, 1)
    end
    return tag
end

-- ============================================================
-- Widget factories
-- ============================================================

M.Widgets = M.CreateWidgets({
    CreateFrame = CreateFrame,
    ColorPickerFrame = ColorPickerFrame,
    GameTooltip = GameTooltip,
    CreatePanelButton = FW.CreatePanelButton,
    CreateDropdownButton = CreateDropdownButton,
    GetOpts = GetOpts,
    GetOptionText = GetOptionText,
    UnpackOptions = UnpackOptions,
    ShowTip = ShowTip,
    HideTip = HideTip,
    ShowHoverPreview = ShowHoverPreview,
    ShowDropdownOptionPreview = ShowDropdownOptionPreview,
    RestoreSectionPreview = RestoreSectionPreview,
    AddSettingMarkerTag = AddSettingMarkerTag,
    RefreshActiveSection = function()
        if SelectSection then
            SelectSection(activeKey)
        end
    end,
    GetScrollChild = function() return scrollChild end,
    GetCursorY = function() return cursorY end,
    SetCursorY = function(value) cursorY = value or 0 end,
    PAD = PAD,
    SECTION_H = SECTION_H,
    SPACER_H = SPACER_H,
    TOGGLE_H = TOGGLE_H,
    SLIDER_H = SLIDER_H,
    DROPDOWN_H = DROPDOWN_H,
    COLOR_H = COLOR_H,
    COLOR_TEXT_DIM = COLOR_TEXT_DIM,
    COLOR_GOLD = COLOR_GOLD,
})
M.Renderers = M.Renderers or {}

local SectionHeader = M.Widgets.SectionHeader
local AddText = M.Widgets.AddText

local function AddSearchResult(entry)
    local y = cursorY
    local btn = CreateFrame("Button", nil, scrollChild)
    btn:SetHeight(54)
    btn:SetPoint("TOPLEFT", scrollChild, "TOPLEFT", PAD, -y)
    btn:SetPoint("TOPRIGHT", scrollChild, "TOPRIGHT", -PAD, -y)

    btn.bg = btn:CreateTexture(nil, "BACKGROUND")
    btn.bg:SetAllPoints()
    btn.bg:SetColorTexture(0.030, 0.024, 0.020, 0.64)

    btn.line = btn:CreateTexture(nil, "BORDER")
    btn.line:SetPoint("BOTTOMLEFT", btn, "BOTTOMLEFT", 0, 0)
    btn.line:SetPoint("BOTTOMRIGHT", btn, "BOTTOMRIGHT", 0, 0)
    btn.line:SetHeight(1)
    btn.line:SetColorTexture(1, 0.82, 0, 0.12)

    btn.title = btn:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    btn.title:SetPoint("TOPLEFT", btn, "TOPLEFT", 10, -7)
    btn.title:SetPoint("RIGHT", btn, "RIGHT", -96, 0)
    btn.title:SetJustifyH("LEFT")
    btn.title:SetText(entry.label)

    btn.section = btn:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    btn.section:SetPoint("TOPRIGHT", btn, "TOPRIGHT", -10, -8)
    btn.section:SetJustifyH("RIGHT")
    btn.section:SetText(entry.sectionLabel)

    local tag = AddSettingMarkerTag(btn, entry.label)
    if tag then tag:SetPoint("RIGHT", btn.section, "LEFT", -6, 0) end

    btn.desc = btn:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    btn.desc:SetPoint("TOPLEFT", btn.title, "BOTTOMLEFT", 0, -4)
    btn.desc:SetPoint("RIGHT", btn, "RIGHT", -10, 0)
    btn.desc:SetJustifyH("LEFT")
    btn.desc:SetTextColor(COLOR_TEXT_DIM[1], COLOR_TEXT_DIM[2], COLOR_TEXT_DIM[3], 0.9)
    local markerSummary = GetSettingMarkerSummary(entry.label)
    btn.desc:SetText(markerSummary and ((entry.desc or "") .. " " .. markerSummary) or (entry.desc or ""))

    btn:SetScript("OnEnter", function(self)
        self.bg:SetColorTexture(0.090, 0.060, 0.032, 0.76)
    end)
    btn:SetScript("OnLeave", function(self)
        self.bg:SetColorTexture(0.030, 0.024, 0.020, 0.64)
    end)
    btn:SetScript("OnClick", function()
        if searchBox then
            searchBox:SetText("")
            searchBox:ClearFocus()
        end
        SelectSection(entry.key)
    end)

    cursorY = y + 58
end

local function RenderSearchResults()
    local hasFilter = searchScope ~= "all"
    local header = hasFilter and GetSearchFilterText() or "Search Results"
    SectionHeader(header)

    local query = searchQuery or ""
    if query == "" and not hasFilter then
        AddText("Showing all searchable settings. Type in the search box or choose a focused filter.",
            "GameFontHighlightSmall", COLOR_TEXT_DIM, 0, 8)
    end

    local filterDesc = hasFilter and GetSearchFilterDescription() or nil
    if filterDesc then
        AddText(filterDesc, "GameFontHighlightSmall", COLOR_TEXT_DIM, 0, 8)
    end

    local count = 0
    for _, entry in ipairs(OPTIONS) do
        if IsSectionAvailable(entry.key) and SearchScopeAllows(entry) then
            entry.sectionLabel = GetSectionLabel(entry.key)
            if query == "" or EntryMatchesSearch(entry, query) then
                AddSearchResult(entry)
                count = count + 1
            end
        end
    end

    if count == 0 then
        AddText("No matching settings found.", "GameFontHighlight", COLOR_TEXT_DIM, 0, 8)
    end
end

local RENDER_FN = M.Renderers
RENDER_FN.search = RenderSearchResults

-- ============================================================
-- Section switching
-- ============================================================

local function UpdateTabButtons()
    for _, btn in ipairs(tabButtons) do
        if btn.tabKey == activeTab then
            ColorTexture(btn.inset, { 0.110, 0.070, 0.030, 0.98 })
            btn.label:SetTextColor(1, 0.82, 0, 1)
        else
            ColorTexture(btn.inset, { 0.020, 0.016, 0.014, 0.92 })
            btn.label:SetTextColor(0.82, 0.75, 0.66, 1)
        end
    end
end

function SelectSection(key)
    if M.Dropdown and M.Dropdown.Close then
        M.Dropdown.Close()
    end

    activeTab = (key == "release") and "release" or "modules"
    activeKey = key
    if key ~= "release" and key ~= "search" then
        lastModuleKey = key
    end
    UpdateTabButtons()
    UpdateContentLayoutForSection(key)

    for _, btn in ipairs(navButtons) do
        if btn.sectionKey == key then
            btn:LockHighlight()
            btn:SetNormalFontObject(_G.GameFontNormal)
            if btn.selectedTex then btn.selectedTex:Show() end
        else
            btn:UnlockHighlight()
            btn:SetNormalFontObject(_G.GameFontHighlightSmall)
            if btn.selectedTex then btn.selectedTex:Hide() end
        end
    end

    -- Detach old scroll child
    if scrollChild then
        scrollChild:Hide()
        scrollChild:SetParent(nil)
    end

    local newChild = CreateFrame("Frame", nil, scrollFrame)
    newChild:SetWidth(GetScrollContentWidth())
    scrollFrame:SetScrollChild(newChild)
    scrollChild = newChild
    cursorY = PAD
    if type(scrollFrame.SetVerticalScroll) == "function" then
        scrollFrame:SetVerticalScroll(0)
    end

    local renderFn = RENDER_FN[key]
    if renderFn then renderFn() end

    newChild:SetHeight(math.max(cursorY + PAD, scrollFrame:GetHeight()))

    -- Update preview image/text
    for _, sec in ipairs(sections or SECTION_DEFS) do
        if sec.key == key then
            SetPreview(sec.image, sec.desc, sec)
            return
        end
    end
    if key == ZYGOR_SECTION.key then
        SetPreview(ZYGOR_SECTION.image, ZYGOR_SECTION.desc, ZYGOR_SECTION)
    elseif key == "search" then
        SetPreview(MEDIA_HELP .. "AWPOptions.tga", "Search results open the matching options section.",
            { imageW = 1376, imageH = 768 })
    end
end

-- ============================================================
-- Panel creation
-- ============================================================

function M.Create()
    -- Build section list (add Zygor if loaded)
    sections = {}
    for _, s in ipairs(SECTION_DEFS) do sections[#sections + 1] = s end
    if type(NS.IsZygorLoaded) == "function" and NS.IsZygorLoaded() then
        sections[#sections + 1] = ZYGOR_SECTION
    end

    local settingsCanvas = CreateFrame("Frame", "AWPOptionsCanvas", UIParent)
    settingsCanvas:SetSize(PANEL_W, PANEL_H)
    settingsCanvas:SetMovable(true)
    settingsCanvas:SetClampedToScreen(true)
    settingsCanvas:SetFrameStrata("MEDIUM")
    settingsCanvas:SetToplevel(true)
    settingsCanvas:Hide()

    local canvas = settingsCanvas
    local versionStr = type(NS.GetAddonMetadataValue) == "function"
        and NS.GetAddonMetadataValue("Version", "") or ""
    local shell = FW.CreatePanelShell(settingsCanvas, {
        title = NS.ADDON_NAME,
        titleHeight = HEADER_H,
        footerHeight = FOOTER_H,
        titleColor = FW.COLORS.closeTextHover,
        versionText = versionStr ~= "" and ("v" .. versionStr) or nil,
        bodyTopOffset = -1,
        movable = true,
        dragTarget = settingsCanvas,
        closeButton = true,
        closeSize = 22,
        closeOffsetX = -8,
        closeBorder = true,
        closeBorderColor = { 0.52, 0.35, 0.16, 0 },
        onClose = function() settingsCanvas:Hide() end,
    })
    local footerFrame = shell.footerFrame
    local bodyFrame = shell.bodyFrame

    local bodyWash = bodyFrame:CreateTexture(nil, "BACKGROUND", nil, -3)
    bodyWash:SetTexture(MEDIA_HELP .. "MainShot.tga")
    bodyWash:SetAlpha(0.08)
    bodyWash:SetPoint("TOPLEFT", bodyFrame, "TOPLEFT", NAV_W, 0)
    bodyWash:SetPoint("BOTTOMRIGHT", bodyFrame, "BOTTOMRIGHT", -PREVIEW_W, 0)

    -- Left navigation sidebar
    local navBg = bodyFrame:CreateTexture(nil, "BACKGROUND")
    ColorTexture(navBg, COLOR_PANEL)
    navBg:SetPoint("TOPLEFT", bodyFrame, "TOPLEFT", 0, 0)
    navBg:SetPoint("BOTTOMLEFT", bodyFrame, "BOTTOMLEFT", 0, 0)
    navBg:SetWidth(NAV_W)

    local navLine = canvas:CreateTexture(nil, "ARTWORK")
    ColorTexture(navLine, COLOR_LINE)
    navLine:SetWidth(1)
    navLine:SetPoint("TOPRIGHT", navBg, "TOPRIGHT", 0, 0)
    navLine:SetPoint("BOTTOMRIGHT", navBg, "BOTTOMRIGHT", 0, 0)

    local navFrame = CreateFrame("Frame", nil, bodyFrame)
    navFrame:SetPoint("TOPLEFT", bodyFrame, "TOPLEFT", 0, 0)
    navFrame:SetPoint("BOTTOMLEFT", bodyFrame, "BOTTOMLEFT", 0, 0)
    navFrame:SetWidth(NAV_W)

    searchFilterButton = CreateSearchFilterButton(navFrame)
    searchFilterButton:SetPoint("TOPRIGHT", navFrame, "TOPRIGHT", -12, -10)

    searchBox = CreateSearchBox(navFrame)
    searchBox:SetSize(NAV_W - 62, 26)
    searchBox:SetPoint("TOPLEFT", navFrame, "TOPLEFT", 12, -10)
    searchBox:SetPoint("RIGHT", searchFilterButton, "LEFT", -8, 0)

    local navSearchLine = navFrame:CreateTexture(nil, "ARTWORK")
    ColorTexture(navSearchLine, { 1, 0.82, 0, 0.12 })
    navSearchLine:SetHeight(1)
    navSearchLine:SetPoint("TOPLEFT", navFrame, "TOPLEFT", 12, -46)
    navSearchLine:SetPoint("TOPRIGHT", navFrame, "TOPRIGHT", -12, -46)

    navButtons = {}
    local navY = 56
    for _, sec in ipairs(sections) do
        local btn = CreateFrame("Button", nil, navFrame)
        btn:SetHeight(NAV_BTN_H)
        local indent = sec.indent and 20 or 8
        btn:SetPoint("TOPLEFT", navFrame, "TOPLEFT", indent, -navY)
        btn:SetPoint("TOPRIGHT", navFrame, "TOPRIGHT", -4, -navY)
        btn:SetNormalFontObject(_G.GameFontHighlightSmall)
        btn:SetHighlightFontObject(_G.GameFontNormal)
        btn:SetText(sec.label)
        local fs = btn:GetFontString()
        if fs then
            fs:SetJustifyH("LEFT")
            fs:SetPoint("LEFT", btn, "LEFT", 4, 0)
        end

        local hlTex = btn:CreateTexture(nil, "BACKGROUND")
        hlTex:SetAllPoints()
        hlTex:SetColorTexture(1, 1, 1, 0.08)
        btn:SetHighlightTexture(hlTex)

        local selectedTex = btn:CreateTexture(nil, "BACKGROUND", nil, -1)
        selectedTex:SetAllPoints()
        selectedTex:SetColorTexture(1, 0.82, 0, 0.13)
        selectedTex:Hide()
        btn.selectedTex = selectedTex

        btn.sectionKey = sec.key
        btn:SetScript("OnClick", function() SelectSection(sec.key) end)
        navButtons[#navButtons + 1] = btn
        navY = navY + NAV_BTN_H + 2
    end

    -- Right preview panel
    previewBg = bodyFrame:CreateTexture(nil, "BACKGROUND")
    ColorTexture(previewBg, COLOR_PANEL)
    previewBg:SetPoint("TOPRIGHT", bodyFrame, "TOPRIGHT", 0, 0)
    previewBg:SetPoint("BOTTOMRIGHT", bodyFrame, "BOTTOMRIGHT", 0, 0)
    previewBg:SetWidth(PREVIEW_W)

    previewLine = canvas:CreateTexture(nil, "ARTWORK")
    ColorTexture(previewLine, COLOR_LINE)
    previewLine:SetWidth(1)
    previewLine:SetPoint("TOPLEFT", previewBg, "TOPLEFT", 0, 0)
    previewLine:SetPoint("BOTTOMLEFT", previewBg, "BOTTOMLEFT", 0, 0)

    -- Invisible fixed preview slot. Images are centered inside this.
    previewAnchor = CreateFrame("Frame", nil, bodyFrame)
    previewAnchor:SetSize(PREVIEW_MAX_W, PREVIEW_MAX_H)
    previewAnchor:SetPoint("TOP", bodyFrame, "TOPRIGHT", -(PREVIEW_W / 2), -12)

    -- Border frame follows the actual displayed image size.
    previewBorder = CreateFrame("Frame", nil, bodyFrame)
    previewBorder:SetSize(PREVIEW_MAX_W + 2, PREVIEW_MAX_H + 2)
    previewBorder:SetPoint("CENTER", previewAnchor, "CENTER", 0, 0)

    local previewTop = previewBorder:CreateTexture(nil, "BORDER")
    previewTop:SetPoint("TOPLEFT", previewBorder, "TOPLEFT", 0, 0)
    previewTop:SetPoint("TOPRIGHT", previewBorder, "TOPRIGHT", 0, 0)
    previewTop:SetHeight(1)
    ColorTexture(previewTop, { 0.55, 0.36, 0.18, 0.52 })

    local previewBottom = previewBorder:CreateTexture(nil, "BORDER")
    previewBottom:SetPoint("BOTTOMLEFT", previewBorder, "BOTTOMLEFT", 0, 0)
    previewBottom:SetPoint("BOTTOMRIGHT", previewBorder, "BOTTOMRIGHT", 0, 0)
    previewBottom:SetHeight(1)
    ColorTexture(previewBottom, { 0.55, 0.36, 0.18, 0.52 })

    local previewLeft = previewBorder:CreateTexture(nil, "BORDER")
    previewLeft:SetPoint("TOPLEFT", previewBorder, "TOPLEFT", 0, 0)
    previewLeft:SetPoint("BOTTOMLEFT", previewBorder, "BOTTOMLEFT", 0, 0)
    previewLeft:SetWidth(1)
    ColorTexture(previewLeft, { 0.55, 0.36, 0.18, 0.52 })

    local previewRight = previewBorder:CreateTexture(nil, "BORDER")
    previewRight:SetPoint("TOPRIGHT", previewBorder, "TOPRIGHT", 0, 0)
    previewRight:SetPoint("BOTTOMRIGHT", previewBorder, "BOTTOMRIGHT", 0, 0)
    previewRight:SetWidth(1)
    ColorTexture(previewRight, { 0.55, 0.36, 0.18, 0.52 })

    previewImage = bodyFrame:CreateTexture(nil, "ARTWORK")
    previewImage:SetSize(PREVIEW_MAX_W, PREVIEW_MAX_H)
    previewImage:SetPoint("CENTER", previewBorder, "CENTER", 0, 0)

    previewDesc = bodyFrame:CreateFontString(nil, "OVERLAY", "GameFontHighlightLarge")
    previewDesc:SetPoint("TOPLEFT", previewBorder, "BOTTOMLEFT", 0, -8)
    previewDesc:SetPoint("TOPRIGHT", previewBorder, "BOTTOMRIGHT", 0, -8)
    previewDesc:SetJustifyH("CENTER")
    previewDesc:SetJustifyV("TOP")
    previewDesc:SetWordWrap(true)

    previewLogo = bodyFrame:CreateTexture(nil, "OVERLAY")
    previewLogo:SetTexture(ICON_PATH)
    previewLogo:SetSize(228, 228)
    previewLogo:SetPoint("BOTTOM", bodyFrame, "BOTTOMRIGHT", -(PREVIEW_W / 2), 14)
    previewLogo:SetAlpha(0.65)

    -- Center scroll frame
    scrollFrame = CreateFrame("ScrollFrame", nil, bodyFrame, "UIPanelScrollFrameTemplate")
    scrollFrame:SetPoint("TOPLEFT", bodyFrame, "TOPLEFT", NAV_W, 0)
    scrollFrame:SetPoint("BOTTOMRIGHT", bodyFrame, "BOTTOMRIGHT", -PREVIEW_W, 0)
    FW.StyleScrollBar(scrollFrame, {
        anchorTo = scrollFrame,
        trackInsetTop = 6,
        trackInsetBottom = 6,
        topOffsetY = -9,
        bottomOffsetY = 9,
        offsetX = -6,
        width = 6,
    })

    tabButtons = {}
    local modulesTab = FW.CreatePanelButton(footerFrame)
    modulesTab:SetSize(112, 30)
    modulesTab:SetPoint("LEFT", footerFrame, "LEFT", 18, 0)
    modulesTab:SetDisplayText("Modules")
    modulesTab.tabKey = "modules"
    modulesTab:SetScript("OnClick", function()
        SelectSection(lastModuleKey or "about")
    end)
    modulesTab:HookScript("OnLeave", UpdateTabButtons)
    tabButtons[#tabButtons + 1] = modulesTab

    local releaseTab = FW.CreatePanelButton(footerFrame)
    releaseTab:SetSize(140, 30)
    releaseTab:SetPoint("LEFT", modulesTab, "RIGHT", 8, 0)
    releaseTab:SetDisplayText("Release Notes")
    releaseTab.tabKey = "release"
    releaseTab:SetScript("OnClick", function()
        SelectSection("release")
    end)
    releaseTab:HookScript("OnLeave", UpdateTabButtons)
    tabButtons[#tabButtons + 1] = releaseTab

    settingsCanvas:SetScript("OnShow", function()
        SelectSection(activeKey)
    end)
    settingsCanvas:SetScript("OnHide", function()
        HideTip()
        if searchBox and type(searchBox.ClearFocus) == "function" then
            searchBox:ClearFocus()
        end
        if M.Dropdown and M.Dropdown.Close then
            M.Dropdown.Close()
        end
    end)

    -- Register with WoW's Escape key system so Escape closes the panel,
    -- and so it doesn't block Escape for other frames when hidden.
    if _G.UISpecialFrames then
        table.insert(_G.UISpecialFrames, "AWPOptionsCanvas")
    end

    -- Seed with default section (sets scrollChild, previewImage, etc.)
    SelectSection(activeKey)

    return settingsCanvas
end
