local NS = _G.AzerothWaypointNS
local C = NS.Constants
local M = NS.Internal.Interface.options

local CreateFrame = _G.CreateFrame
local UIParent    = _G.UIParent
local C_Timer     = _G.C_Timer

local standaloneCanvas = nil

-- ============================================================
-- Position save / restore  (stored in the addon DB)
-- ============================================================

local function SavePosition(frame)
    local db = type(NS.GetDB) == "function" and NS.GetDB()
    if not db then return end
    local point, _, relPoint, x, y = frame:GetPoint(1)
    if point then
        db.awpPanelPos = { point = point, relPoint = relPoint or "CENTER", x = x or 0, y = y or 0 }
    end
end

local function ApplyOrCenterPosition(frame)
    local db = type(NS.GetDB) == "function" and NS.GetDB()
    local pos = db and db.awpPanelPos
    frame:ClearAllPoints()
    if pos and pos.point then
        frame:SetPoint(pos.point, UIParent, pos.relPoint, pos.x, pos.y)
    else
        frame:SetPoint("CENTER", UIParent, "CENTER")
    end
end

-- ============================================================
-- Standalone canvas (lazy init)
-- ============================================================

local function GetOrCreateCanvas()
    if standaloneCanvas then return standaloneCanvas end

    NS.ApplyDBDefaults()
    local currentSkin = NS.GetSkinChoice()
    if currentSkin ~= C.SKIN_DEFAULT then
        M.rememberedCustomSkin = currentSkin
    end

    standaloneCanvas = NS.Internal.Interface.canvas.Create()

    -- Save position whenever the panel is hidden (close button or external)
    standaloneCanvas:HookScript("OnHide", function(self)
        SavePosition(self)
    end)

    return standaloneCanvas
end

-- ============================================================
-- Blizzard options entry (redirect only — opens our standalone)
-- ============================================================

function NS.RegisterOptionsPanel()
    if not (Settings and Settings.RegisterCanvasLayoutCategory and Settings.RegisterAddOnCategory) then
        return
    end

    local ICON_PATH = "Interface\\AddOns\\AzerothWaypoint\\media\\icon.png"

    local redirectFrame = CreateFrame("Frame", nil, UIParent)
    redirectFrame:SetSize(600, 400)
    -- Frames default to :IsShown() = true. Without this Hide(), redirectFrame
    -- sits "shown" under UIParent forever, and any code that hides+restores
    -- the UI (ElvUI AFK, cinematics, alt-z) will fire our OnShow on restore
    -- and reopen the standalone panel even if the user closed it.
    redirectFrame:Hide()

    local icon = redirectFrame:CreateTexture(nil, "ARTWORK")
    icon:SetSize(48, 48)
    icon:SetPoint("CENTER", redirectFrame, "CENTER", 0, 18)
    icon:SetTexture(ICON_PATH)

    local label = redirectFrame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    label:SetPoint("TOP", icon, "BOTTOM", 0, -10)
    label:SetText("AzerothWaypoint — opening in a separate window...")
    label:SetTextColor(0.85, 0.78, 0.65, 1)

    -- When Blizzard settings switches to this category, open the standalone
    -- and then close the Blizzard settings panel so only ours remains.
    redirectFrame:SetScript("OnShow", function()
        NS.OpenOptionsPanel()
        if C_Timer then
            C_Timer.After(0, function()
                -- Always hide ourselves so we don't linger as "shown" under
                -- UIParent — if we stay shown and the UI is hidden/restored
                -- (cinematics, loading screens) WoW re-fires OnShow and
                -- reopens the panel even after the user closed it.
                local wasVisible = redirectFrame:IsVisible()
                redirectFrame:Hide()
                -- Guard: if SettingsPanel already navigated away from our
                -- redirect frame (e.g. /tomtom opened TomTom's category),
                -- don't close it — that would swallow the other addon's panel.
                if not wasVisible then return end
                local sp = _G["SettingsPanel"]
                if sp then
                    if _G.HideUIPanel then
                        _G.HideUIPanel(sp)
                    elseif type(sp.Hide) == "function" then
                        sp:Hide()
                    end
                end
            end)
        end
    end)

    local category = Settings.RegisterCanvasLayoutCategory(redirectFrame, "AzerothWaypoint")
    Settings.RegisterAddOnCategory(category)
end

-- ============================================================
-- Open standalone panel  (/awp options + Blizzard entry)
-- ============================================================

function NS.OpenOptionsPanel()
    local frame = GetOrCreateCanvas()
    if not frame then return end

    if not frame:IsShown() then
        ApplyOrCenterPosition(frame)
        frame:Show()
    end

    frame:Raise()
end
