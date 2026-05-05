local NS = _G.AzerothWaypointNS
local C = NS.Constants

NS.Internal.Interface = NS.Internal.Interface or {}
NS.Internal.Interface.options = NS.Internal.Interface.options or {}

local M = NS.Internal.Interface.options

local TWITCH_COPY_POPUP = "AWP_COPY_TWITCH_URL"
local RELOAD_RECOMMENDED_POPUP = "AWP_RELOAD_RECOMMENDED"
local WAYPOINT_UI_RECOMMEND_POPUP = "AWP_RECOMMEND_NATIVE_OVERLAY"
local WAYPOINT_UI_ADDON_NAME = "WaypointUI"
local ZYGOR_CONFLICT_POPUP = "AWP_ZYGOR_CONFLICT"
local ZYGOR_WAYPOINT_ADDON_NAME = "ZygorWaypoint"
local ZYGOR_ARROW_RECOMMEND_POPUP = "AWP_RECOMMEND_ZYGOR_ARROW"
local STARTUP_POPUP_RETRY_DELAY_SECONDS = 2
local STARTUP_POPUP_MAX_ATTEMPTS = 8

local GetTomTom = NS.GetTomTom

local DB_DEFAULTS = NS.Internal.DBDefaults or {}
local DEFAULTS = {}
for key, value in pairs(DB_DEFAULTS) do
    DEFAULTS[key] = value
end
DEFAULTS.useCustomSkin = true
DEFAULTS.customSkin = C.SKIN_STARLIGHT

M.DEFAULTS = DEFAULTS
M.rememberedCustomSkin = M.rememberedCustomSkin or DEFAULTS.customSkin

local function GetStaticPopupPreferredIndex()
    return _G["STATICPOPUP_NUMDIALOGS"] or 4
end

local STARTUP_NOTICE_POPUPS = {
    WAYPOINT_UI_RECOMMEND_POPUP,
    ZYGOR_CONFLICT_POPUP,
    ZYGOR_ARROW_RECOMMEND_POPUP,
}

local function IsStartupHelpVisible()
    local frame = _G["AWPHelpFrame"]
    return frame and type(frame.IsShown) == "function" and frame:IsShown() or false
end

local function IsStartupPopupVisible(ignorePopupName)
    for _, popupName in ipairs(STARTUP_NOTICE_POPUPS) do
        if popupName ~= ignorePopupName and StaticPopup_Visible(popupName) then
            return true
        end
    end
    return false
end

local function ShouldDeferStartupPopup(popupName)
    return IsStartupHelpVisible() or IsStartupPopupVisible(popupName)
end

local function RetryStartupPopup(fn, attempt)
    attempt = tonumber(attempt) or 1
    if attempt >= STARTUP_POPUP_MAX_ATTEMPTS then
        return false
    end
    if type(fn) ~= "function" then
        return false
    end

    local nextAttempt = attempt + 1
    if type(NS.After) == "function" then
        NS.After(STARTUP_POPUP_RETRY_DELAY_SECONDS, function()
            fn(nextAttempt)
        end)
        return true
    end
    if type(C_Timer) == "table" and type(C_Timer.After) == "function" then
        C_Timer.After(STARTUP_POPUP_RETRY_DELAY_SECONDS, function()
            fn(nextAttempt)
        end)
        return true
    end
    return false
end

local function CreateControlTextContainer()
    if Settings and type(Settings.CreateControlTextContainer) == "function" then
        return Settings.CreateControlTextContainer()
    end

    local data = {}
    return {
        Add = function(_, value, text)
            data[#data + 1] = { value = value, label = text, text = text }
        end,
        GetData = function()
            return data
        end,
    }
end

local function IsSelectableCustomSkin(key)
    return type(key) == "string"
        and key ~= C.SKIN_DEFAULT
        and key ~= "tomtom_default"
        and type(NS.HasArrowSkin) == "function"
        and NS.HasArrowSkin(key)
end

local function GetPreferredCustomSkin()
    if IsSelectableCustomSkin(M.rememberedCustomSkin) then
        return M.rememberedCustomSkin
    end
    if IsSelectableCustomSkin(DEFAULTS.customSkin) then
        return DEFAULTS.customSkin
    end
    if type(NS.GetRegisteredArrowSkins) == "function" then
        for _, key in ipairs(NS.GetRegisteredArrowSkins()) do
            if IsSelectableCustomSkin(key) then
                return key
            end
        end
    end

    return C.SKIN_DEFAULT
end

local function ShowCopyLinkPopup(url)
    if not StaticPopupDialogs[TWITCH_COPY_POPUP] then
        StaticPopupDialogs[TWITCH_COPY_POPUP] = {
            text = "Copy Twitch URL (Ctrl+C):",
            button1 = OKAY,
            hasEditBox = 1,
            editBoxWidth = 320,
            timeout = 0,
            whileDead = 1,
            hideOnEscape = 1,
            preferredIndex = GetStaticPopupPreferredIndex(),
            OnShow = function(self, data)
                local editBox = self.EditBox or self.editBox
                if not editBox then return end
                editBox:SetText(data or "")
                editBox:HighlightText()
                editBox:SetFocus()
            end,
            OnAccept = function(self)
                self:Hide()
            end,
            EditBoxOnEnterPressed = function(self)
                self:HighlightText()
            end,
            EditBoxOnEscapePressed = function(self)
                self:GetParent():Hide()
            end,
        }
    end

    StaticPopup_Show(TWITCH_COPY_POPUP, nil, nil, url)
end

local function ShowReloadRecommendedPopup(settingName)
    if not StaticPopupDialogs[RELOAD_RECOMMENDED_POPUP] then
        StaticPopupDialogs[RELOAD_RECOMMENDED_POPUP] = {
            text = "A reload is recommended after changing \"%s\".\n\nReload now?",
            button1 = RELOADUI or "Reload Now",
            button2 = "Not Now",
            timeout = 0,
            whileDead = 1,
            hideOnEscape = 1,
            preferredIndex = GetStaticPopupPreferredIndex(),
            OnAccept = function()
                ReloadUI()
            end,
        }
    end

    if StaticPopup_Visible(RELOAD_RECOMMENDED_POPUP) then
        return
    end

    StaticPopup_Show(RELOAD_RECOMMENDED_POPUP, settingName or "this setting")
end

local function IsWaypointUIRecommendationRelevant()
    if type(NS.IsWorldOverlayEnabled) ~= "function" or NS.IsWorldOverlayEnabled() ~= true then
        return false
    end

    return type(NS.IsAddonEnabledForCurrentCharacter) == "function"
        and NS.IsAddonEnabledForCurrentCharacter(WAYPOINT_UI_ADDON_NAME)
        or false
end

local function EnsureWaypointUIRecommendPopup()
    if StaticPopupDialogs[WAYPOINT_UI_RECOMMEND_POPUP] then
        return
    end

    StaticPopupDialogs[WAYPOINT_UI_RECOMMEND_POPUP] = {
        text = table.concat({
            "WaypointUI is enabled for this character.",
            "",
            "AzerothWaypoint's 3D overlay is already active, so you can compare both live right now.",
            "For the better recommended setup, disable WaypointUI for this character and reload.",
        }, "\n"),
        button1 = "Disable + Reload",
        button2 = "Keep Enabled",
        timeout = 0,
        whileDead = 1,
        hideOnEscape = 1,
        preferredIndex = GetStaticPopupPreferredIndex(),
        OnAccept = function()
            local ok = type(NS.DisableAddonForCurrentCharacter) == "function"
                and NS.DisableAddonForCurrentCharacter(WAYPOINT_UI_ADDON_NAME)
                or false
            if ok then
                if type(NS.MarkPendingOverviewReplayForCurrentCharacter) == "function" then
                    NS.MarkPendingOverviewReplayForCurrentCharacter()
                end
                ReloadUI()
            else
                NS.Msg("Unable to disable WaypointUI automatically. Disable it for this character in the AddOns list.")
            end
        end,
    }
end

function NS.MaybeShowWaypointUIRecommendationPopup(attempt)
    if not IsWaypointUIRecommendationRelevant() then
        return
    end
    if type(NS.GetWaypointUIPromptVersion) == "function" and NS.GetWaypointUIPromptVersion() == NS.VERSION then
        return
    end
    if StaticPopup_Visible(WAYPOINT_UI_RECOMMEND_POPUP) then
        return
    end
    if ShouldDeferStartupPopup(WAYPOINT_UI_RECOMMEND_POPUP) then
        RetryStartupPopup(NS.MaybeShowWaypointUIRecommendationPopup, attempt)
        return
    end

    EnsureWaypointUIRecommendPopup()
    local dialog = StaticPopup_Show(WAYPOINT_UI_RECOMMEND_POPUP)
    if dialog and type(NS.MarkWaypointUIPromptShown) == "function" then
        NS.MarkWaypointUIPromptShown()
    end
end

function NS.MaybeAnnounceWaypointUIRecommendation()
    if not IsWaypointUIRecommendationRelevant() then
        return
    end

    NS.Msg(
    "WaypointUI is still enabled. AWP's 3D overlay is already active so you can compare both live. Disable WaypointUI when you're ready for the better native setup.")
end

local function GetZygorProfile()
    local Z = type(NS.ZGV) == "function" and NS.ZGV() or rawget(_G, "ZygorGuidesViewer") or rawget(_G, "ZGV")
    local profile = Z and Z.db and Z.db.profile or nil
    if type(profile) ~= "table" then
        return Z, nil
    end
    return Z, profile
end

local function IsZygorArrowProfilePending()
    return type(NS.IsZygorLoaded) == "function"
        and NS.IsZygorLoaded()
        and select(2, GetZygorProfile()) == nil
end

local function IsZygorArrowRecommendationRelevant()
    local _, profile = GetZygorProfile()
    return type(profile) == "table" and profile.arrowshow ~= false or false
end

local function DisableZygorArrow()
    local Z, profile = GetZygorProfile()
    if type(profile) ~= "table" then
        return false, "Zygor profile is not ready yet."
    end
    if profile.arrowshow == false then
        return true
    end
    if type(InCombatLockdown) == "function" and InCombatLockdown() then
        return false, "Cannot change Zygor's arrow while in combat. Try again after combat ends."
    end

    if Z and type(Z.SetOption) == "function" then
        local ok = pcall(Z.SetOption, Z, "Navi", "arrowshow off")
        if ok and profile.arrowshow == false then
            return true
        end
    end

    profile.arrowshow = false
    local pointer = Z and Z.Pointer or nil
    if pointer and type(pointer.UpdateArrowVisibility) == "function" then
        pcall(pointer.UpdateArrowVisibility, pointer)
    end
    return profile.arrowshow == false
end

local function EnsureZygorArrowRecommendPopup()
    if StaticPopupDialogs[ZYGOR_ARROW_RECOMMEND_POPUP] then
        return
    end

    StaticPopupDialogs[ZYGOR_ARROW_RECOMMEND_POPUP] = {
        text = table.concat({
            "Zygor's Waypoint Arrow is enabled.",
            "",
            "AzerothWaypoint provides its own 3D overlay and route guidance. Running both arrows can be confusing.",
            "",
            "You can also change this manually in /zygor options > Waypoint Arrow > Enable Waypoint Arrow.",
        }, "\n"),
        button1 = "Turn Off Zygor Arrow",
        button2 = "Keep Enabled",
        timeout = 0,
        whileDead = 1,
        hideOnEscape = 1,
        preferredIndex = GetStaticPopupPreferredIndex(),
        OnAccept = function()
            local ok, reason = DisableZygorArrow()
            if ok then
                NS.Msg("Zygor Waypoint Arrow disabled.")
            else
                NS.Msg("Unable to disable Zygor Waypoint Arrow:", tostring(reason or "unknown error"))
            end
        end,
    }
end

function NS.MaybeAnnounceZygorArrowRecommendation(attempt)
    if IsZygorArrowProfilePending() then
        RetryStartupPopup(NS.MaybeAnnounceZygorArrowRecommendation, attempt)
        return
    end
    if not IsZygorArrowRecommendationRelevant() then
        return
    end

    NS.Msg("Zygor's Waypoint Arrow is enabled. To avoid duplicate arrows, open /zygor options > Waypoint Arrow and turn off Enable Waypoint Arrow.")
end

function NS.MaybeShowZygorArrowRecommendationPopup(attempt)
    if IsZygorArrowProfilePending() then
        RetryStartupPopup(NS.MaybeShowZygorArrowRecommendationPopup, attempt)
        return
    end
    if not IsZygorArrowRecommendationRelevant() then
        return
    end
    if type(NS.HasSeenZygorArrowPrompt) == "function" and NS.HasSeenZygorArrowPrompt() then
        return
    end
    if StaticPopup_Visible(ZYGOR_ARROW_RECOMMEND_POPUP) then
        return
    end
    if ShouldDeferStartupPopup(ZYGOR_ARROW_RECOMMEND_POPUP) then
        RetryStartupPopup(NS.MaybeShowZygorArrowRecommendationPopup, attempt)
        return
    end

    EnsureZygorArrowRecommendPopup()
    local dialog = StaticPopup_Show(ZYGOR_ARROW_RECOMMEND_POPUP)
    if dialog and type(NS.MarkZygorArrowPromptShown) == "function" then
        NS.MarkZygorArrowPromptShown()
    end
end

local function IsZygorWaypointConflictActive()
    return type(rawget(_G, "ZygorWaypointNS")) == "table"
        or (type(C_AddOns) == "table" and type(C_AddOns.IsAddOnLoaded) == "function"
            and C_AddOns.IsAddOnLoaded(ZYGOR_WAYPOINT_ADDON_NAME))
end

local function EnsureZygorConflictPopup()
    if StaticPopupDialogs[ZYGOR_CONFLICT_POPUP] then
        return
    end

    StaticPopupDialogs[ZYGOR_CONFLICT_POPUP] = {
        text = table.concat({
            "|cffff4040ZygorWaypoint conflict detected!|r",
            "",
            "The old 'ZygorWaypoint' addon is still installed and conflicts with AzerothWaypoint.",
            "",
            "Click 'Disable + Reload' to disable it.",
            "Afterwards, delete the ZygorWaypoint folder from Interface/AddOns to prevent future conflicts.",
        }, "\n"),
        button1 = "Disable + Reload",
        timeout = 0,
        whileDead = 1,
        hideOnEscape = 0,
        preferredIndex = GetStaticPopupPreferredIndex(),
        OnAccept = function()
            local ok = type(C_AddOns) == "table"
                and type(C_AddOns.DisableAddOn) == "function"
                and pcall(C_AddOns.DisableAddOn, ZYGOR_WAYPOINT_ADDON_NAME)
                or false
            if ok then
                ReloadUI()
            else
                NS.Msg("|cffff4040Unable to disable ZygorWaypoint automatically.|r Delete the ZygorWaypoint folder from Interface/AddOns to resolve the conflict.")
            end
        end,
    }
end

function NS.MaybeShowZygorWaypointConflictPopup()
    if not IsZygorWaypointConflictActive() then
        return
    end
    if StaticPopup_Visible(ZYGOR_CONFLICT_POPUP) then
        return
    end

    EnsureZygorConflictPopup()
    StaticPopup_Show(ZYGOR_CONFLICT_POPUP)
end

function NS.StartZygorWaypointConflictReminders()
    if not IsZygorWaypointConflictActive() then
        return
    end

    C_Timer.NewTicker(300, function()
        if not IsZygorWaypointConflictActive() then
            return
        end
        NS.Msg("|cffff4040WARNING:|r 'ZygorWaypoint' is still installed and conflicting with AzerothWaypoint. Disable and delete the ZygorWaypoint folder from Interface/AddOns.")
    end)
end

local function ApplySkinAndScale()
    local tomtom = GetTomTom()
    NS.ApplyTomTomScalePolicy()
    NS.HookTomTomThemeBridge()
    if tomtom and type(tomtom.ShowHideCrazyArrow) == "function" then
        tomtom:ShowHideCrazyArrow()
    end
    NS.ApplyTomTomArrowSkin()
    if type(NS.RefreshSpecialActionButtonPresentation) == "function" then
        NS.RefreshSpecialActionButtonPresentation()
    end
end

local function RefreshViewerChromeMode()
    if type(NS.IsZygorLoaded) == "function" and not NS.IsZygorLoaded() then
        return
    end
    if type(NS.HookZygorViewerChromeMode) == "function" then
        NS.HookZygorViewerChromeMode()
    end
    if type(NS.RefreshZygorViewerChromeMode) == "function" then
        NS.RefreshZygorViewerChromeMode()
    end
end

local function CreateSkinOptions()
    local container = CreateControlTextContainer()
    local added = false

    if type(NS.GetRegisteredArrowSkins) == "function" then
        for _, key in ipairs(NS.GetRegisteredArrowSkins()) do
            if IsSelectableCustomSkin(key) then
                local def = NS.GetArrowSkin(key)
                container:Add(key, def and def.displayName or key)
                added = true
            end
        end
    end

    if not added then
        container:Add(C.SKIN_DEFAULT, "TomTom Default")
    end

    return container:GetData()
end

local function CreateGuideStepBackgroundHoverOptions()
    local container = CreateControlTextContainer()
    container:Add(C.GUIDE_STEP_BACKGROUND_MODE_BG, "Hide Step Backgrounds")
    container:Add(C.GUIDE_STEP_BACKGROUND_MODE_BG_GOAL, "Hide Step Backgrounds + Line Colors")
    container:Add(C.GUIDE_STEP_BACKGROUND_MODE_NONE, "Disabled")
    return container:GetData()
end

local function CreateRoutingBackendOptions()
    local function getAddOnInfo(name)
        if type(name) ~= "string" or name == "" then
            return nil
        end

        if type(C_AddOns) == "table" and type(C_AddOns.GetAddOnInfo) == "function" then
            local ok, addonName, title, notes, loadable, reason = pcall(C_AddOns.GetAddOnInfo, name)
            if ok and title ~= nil then
                return {
                    installed = true,
                    name = addonName or name,
                    title = title,
                    loadable = loadable,
                    reason = reason,
                }
            end
        end

        local getAddOnInfo = rawget(_G, "GetAddOnInfo")
        if type(getAddOnInfo) == "function" then
            local ok, addonName, title, notes, loadable, reason = pcall(getAddOnInfo, name)
            if ok and title ~= nil then
                return {
                    installed = true,
                    name = addonName or name,
                    title = title,
                    loadable = loadable,
                    reason = reason,
                }
            end
        end

        return { installed = false }
    end

    local function isAddOnInstalled(name)
        local info = getAddOnInfo(name)
        return info and info.installed == true
    end

    local function isAddOnEnabled(name)
        if not isAddOnInstalled(name) then
            return false
        end
        if type(C_AddOns) == "table" and type(C_AddOns.GetAddOnEnableState) == "function" then
            local characterName = type(NS.GetCurrentCharacterName) == "function" and NS.GetCurrentCharacterName() or nil
            local ok, state = pcall(C_AddOns.GetAddOnEnableState, name, characterName)
            if ok then
                return (tonumber(state) or 0) > 0
            end
        end
        if type(NS.IsAddonEnabledForCurrentCharacter) == "function" then
            return NS.IsAddonEnabledForCurrentCharacter(name)
        end
        return type(NS.IsAddonLoaded) == "function" and NS.IsAddonLoaded(name) or false
    end

    local function isAddOnLoaded(name)
        return type(NS.IsAddonLoaded) == "function" and NS.IsAddonLoaded(name) or false
    end

    local function FormatDependencyStatus(names, singleSuffix, pluralText)
        if #names == 1 then
            return names[1] .. " " .. singleSuffix
        end
        return pluralText
    end

    local function getAddOnGroupStatus(addonNames)
        local total = #(addonNames or {})
        local installed = 0
        local enabled = 0
        local loaded = 0
        local missingNames = {}
        local disabledNames = {}
        local unloadedNames = {}

        for _, addonName in ipairs(addonNames or {}) do
            if isAddOnInstalled(addonName) then
                installed = installed + 1
                if isAddOnEnabled(addonName) then
                    enabled = enabled + 1
                else
                    disabledNames[#disabledNames + 1] = addonName
                end
                if isAddOnLoaded(addonName) then
                    loaded = loaded + 1
                else
                    unloadedNames[#unloadedNames + 1] = addonName
                end
            else
                missingNames[#missingNames + 1] = addonName
            end
        end

        if installed == 0 then
            return "not_installed", "not installed", missingNames
        end
        if installed < total then
            return "partly_installed", FormatDependencyStatus(missingNames, "missing", "missing dependencies"), missingNames
        end
        if enabled == 0 then
            return "disabled", "disabled", disabledNames
        end
        if enabled < total then
            return "partly_disabled", FormatDependencyStatus(disabledNames, "disabled", "dependencies disabled"), disabledNames
        end
        if loaded == 0 then
            return "not_loaded", "not loaded", unloadedNames
        end
        if loaded < total then
            return "partly_loaded", FormatDependencyStatus(unloadedNames, "not loaded", "dependencies not loaded"), unloadedNames
        end
        return "unavailable", "unavailable", {}
    end

    local function isBackendAvailable(backendName)
        local backend = NS[backendName]
        return type(backend) == "table"
            and type(backend.IsAvailable) == "function"
            and backend.IsAvailable()
    end

    local function makeBackendOption(value, text, backendName, addonNames, reasons)
        local available = backendName == nil or isBackendAvailable(backendName)
        if available then
            return { value = value, text = text }
        end

        local statusKey, statusText, dependencyNames = getAddOnGroupStatus(addonNames)
        reasons = reasons or {}
        local reason = reasons[statusKey]
        if type(reason) == "function" then
            reason = reason(dependencyNames or {})
        end
        return {
            value = value,
            text = string.format("%s (%s)", text, statusText),
            disabled = true,
            disabledReason = reason
                or reasons.unavailable
                or (text .. " is not available for routing right now."),
        }
    end

    return {
        makeBackendOption("direct", "TomTom Direct"),
        makeBackendOption("zygor", "Zygor", "RoutingBackend_Zygor", { "ZygorGuidesViewer" }, {
            not_installed = "Install Zygor Guides Viewer to use Zygor's LibRover routing.",
            disabled = "Enable Zygor Guides Viewer for this character to use Zygor's LibRover routing.",
            not_loaded = "Load Zygor Guides Viewer to use Zygor's LibRover routing.",
            unavailable = "Zygor Guides Viewer is installed but LibRover is not available right now.",
        }),
        makeBackendOption("farstrider", "FarstriderLib", "RoutingBackend_Farstrider",
            { "FarstriderLib", "FarstriderLibData" }, {
                not_installed = "Install FarstriderLib and FarstriderLibData to use Farstrider routing.",
                partly_installed = function(names)
                    return "Install missing Farstrider dependency: " .. table.concat(names, ", ") .. "."
                end,
                disabled = "Enable FarstriderLib and FarstriderLibData for this character to use Farstrider routing.",
                partly_disabled = function(names)
                    return "Enable Farstrider dependency for this character: " .. table.concat(names, ", ") .. "."
                end,
                not_loaded = "Load FarstriderLib and FarstriderLibData to use Farstrider routing.",
                partly_loaded = function(names)
                    return "Load Farstrider dependency: " .. table.concat(names, ", ") .. "."
                end,
                unavailable = "FarstriderLib and FarstriderLibData are loaded, but Farstrider's routing API is not available right now.",
            }),
        makeBackendOption("mapzeroth", "Mapzeroth", "RoutingBackend_Mapzeroth", { "Mapzeroth" }, {
            not_installed = "Install Mapzeroth to use Mapzeroth routing.",
            disabled = "Enable Mapzeroth for this character to use Mapzeroth routing.",
            not_loaded = "Load Mapzeroth to use Mapzeroth routing.",
            unavailable = "Mapzeroth is loaded but its routing API is not available right now.",
        }),
    }
end

local function CreateManualClickQueueModeOptions()
    local container = CreateControlTextContainer()
    local options = type(NS.GetManualClickQueueModeOptions) == "function" and NS.GetManualClickQueueModeOptions() or nil
    if type(options) == "table" then
        for index = 1, #options do
            local option = options[index]
            if type(option) == "table" and type(option.value) == "string" and type(option.label) == "string" then
                container:Add(option.value, option.label)
            end
        end
    end
    return container:GetData()
end

local function CreateWorldOverlayInfoOptions()
    local container = CreateControlTextContainer()
    container:Add(C.WORLD_OVERLAY_INFO_ALL, "All")
    container:Add(C.WORLD_OVERLAY_INFO_DISTANCE, "Distance")
    container:Add(C.WORLD_OVERLAY_INFO_ARRIVAL, "Arrival Time")
    container:Add(C.WORLD_OVERLAY_INFO_DESTINATION, "Destination Name")
    container:Add(C.WORLD_OVERLAY_INFO_NONE, "None")
    return container:GetData()
end

local function CreateWorldOverlayColorModeOptions()
    local container = CreateControlTextContainer()
    container:Add(C.WORLD_OVERLAY_COLOR_AUTO, "Auto")
    container:Add(C.WORLD_OVERLAY_COLOR_CUSTOM, "Custom")
    container:Add(C.WORLD_OVERLAY_COLOR_BLUE, "Blue")    
    container:Add(C.WORLD_OVERLAY_COLOR_CYAN, "Cyan")
    container:Add(C.WORLD_OVERLAY_COLOR_GOLD, "Gold")
    container:Add(C.WORLD_OVERLAY_COLOR_GRAY, "Gray")
    container:Add(C.WORLD_OVERLAY_COLOR_GREEN, "Green")
    container:Add(C.WORLD_OVERLAY_COLOR_PINK, "Pink")
    container:Add(C.WORLD_OVERLAY_COLOR_PURPLE, "Purple")
    container:Add(C.WORLD_OVERLAY_COLOR_RED, "Red")
    container:Add(C.WORLD_OVERLAY_COLOR_SILVER, "Silver")
    container:Add(C.WORLD_OVERLAY_COLOR_WHITE, "White")
    return container:GetData()
end

local function CreateWorldOverlayContextDisplayOptions()
    local container = CreateControlTextContainer()
    container:Add(C.WORLD_OVERLAY_CONTEXT_DISPLAY_DIAMOND_ICON, "Context Diamond + Icon")
    container:Add(C.WORLD_OVERLAY_CONTEXT_DISPLAY_ICON_ONLY, "Icon Only")
    container:Add(C.WORLD_OVERLAY_CONTEXT_DISPLAY_HIDDEN, "Hidden")
    return container:GetData()
end

local function CreateWorldOverlayBeaconStyleOptions()
    local container = CreateControlTextContainer()
    container:Add(C.WORLD_OVERLAY_BEACON_STYLE_BEACON, "Beacon")
    container:Add(C.WORLD_OVERLAY_BEACON_STYLE_BASE, "Base Only")
    container:Add(C.WORLD_OVERLAY_BEACON_STYLE_DISTANCE, "Distance Based")
    container:Add(C.WORLD_OVERLAY_BEACON_STYLE_OFF, "Off")
    return container:GetData()
end

local function CreateWorldOverlayWaypointModeOptions()
    local container = CreateControlTextContainer()
    container:Add(C.WORLD_OVERLAY_WAYPOINT_MODE_FULL, "Enabled")
    container:Add(C.WORLD_OVERLAY_WAYPOINT_MODE_DISABLED, "Disabled")
    return container:GetData()
end

local function CreateWorldOverlayPinpointModeOptions()
    local container = CreateControlTextContainer()
    container:Add(C.WORLD_OVERLAY_PINPOINT_MODE_FULL, "Full")
    container:Add(C.WORLD_OVERLAY_PINPOINT_MODE_NO_PLAQUE, "Plaque Off")
    container:Add(C.WORLD_OVERLAY_PINPOINT_MODE_DISABLED, "Disabled")
    return container:GetData()
end

local function CreateWorldOverlayPlaqueTypeOptions()
    local container = CreateControlTextContainer()
    container:Add(C.WORLD_OVERLAY_PLAQUE_DEFAULT, "Default")
    container:Add(C.WORLD_OVERLAY_PLAQUE_GLOWING_GEMS, "Glowing Gems")
    container:Add(C.WORLD_OVERLAY_PLAQUE_HORDE, "Horde")
    container:Add(C.WORLD_OVERLAY_PLAQUE_ALLIANCE, "Alliance")
    container:Add(C.WORLD_OVERLAY_PLAQUE_MODERN, "Modern")
    container:Add(C.WORLD_OVERLAY_PLAQUE_STEAMPUNK, "Steampunk")
    return container:GetData()
end

local function RefreshWorldOverlay()
    NS.RefreshWorldOverlay()
end

local function FormatWorldOverlayDistance(value)
    local yards = tonumber(value) or 0
    if NS.GetWorldOverlaySetting("worldOverlayUseMeters") then
        local meters = yards * 0.9144
        if meters >= 1000 then
            return string.format("%.1f km", meters / 1000)
        end
        return string.format("%d m", meters + 0.5)
    end

    return string.format("%d yd", yards + 0.5)
end

local function CopyColorTable(value, fallback)
    fallback = fallback or C.WORLD_OVERLAY_COLOR_PRESETS[C.WORLD_OVERLAY_COLOR_GOLD] or { r = 0.95, g = 0.84, b = 0.44 }
    if type(value) ~= "table" then
        return {
            r = fallback.r or 1,
            g = fallback.g or 1,
            b = fallback.b or 1,
        }
    end

    return {
        r = tonumber(value.r ~= nil and value.r or value[1]) or fallback.r or 1,
        g = tonumber(value.g ~= nil and value.g or value[2]) or fallback.g or 1,
        b = tonumber(value.b ~= nil and value.b or value[3]) or fallback.b or 1,
    }
end

M.GetPreferredCustomSkin = GetPreferredCustomSkin
M.ShowCopyLinkPopup = ShowCopyLinkPopup
M.ShowReloadRecommendedPopup = ShowReloadRecommendedPopup
M.ApplySkinAndScale = ApplySkinAndScale
M.RefreshViewerChromeMode = RefreshViewerChromeMode
M.CreateSkinOptions = CreateSkinOptions
M.CreateGuideStepBackgroundHoverOptions = CreateGuideStepBackgroundHoverOptions
M.CreateRoutingBackendOptions = CreateRoutingBackendOptions
M.CreateManualClickQueueModeOptions = CreateManualClickQueueModeOptions
M.CreateWorldOverlayInfoOptions = CreateWorldOverlayInfoOptions
M.CreateWorldOverlayColorModeOptions = CreateWorldOverlayColorModeOptions
M.CreateWorldOverlayContextDisplayOptions = CreateWorldOverlayContextDisplayOptions
M.CreateWorldOverlayBeaconStyleOptions = CreateWorldOverlayBeaconStyleOptions
M.CreateWorldOverlayPlaqueTypeOptions = CreateWorldOverlayPlaqueTypeOptions
M.CreateWorldOverlayWaypointModeOptions = CreateWorldOverlayWaypointModeOptions
M.CreateWorldOverlayPinpointModeOptions = CreateWorldOverlayPinpointModeOptions
M.RefreshWorldOverlay = RefreshWorldOverlay
M.FormatWorldOverlayDistance = FormatWorldOverlayDistance
M.CopyColorTable = CopyColorTable
