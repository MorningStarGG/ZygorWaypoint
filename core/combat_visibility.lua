local NS = _G.AzerothWaypointNS

local state = NS.State

state.combatVisibility = state.combatVisibility or {
    combatEventActive = false,
    tomTomVisibilityHost = nil,
    tomTomVisibilityDriver = false,
    tomTomOriginalParent = nil,
}

local guard = state.combatVisibility
local TOMTOM_SUPPRESSION_REASON = "combat"

local function IsInCombat()
    if guard.combatEventActive == true then
        return true
    end
    if type(InCombatLockdown) == "function" and InCombatLockdown() == true then
        return true
    end
    return type(UnitAffectingCombat) == "function" and UnitAffectingCombat("player") == true
end

local function IsCombatLockdownActive()
    return type(InCombatLockdown) == "function" and InCombatLockdown() == true
end

local function ShouldAvoidProtectedVisibilityCalls()
    return guard.combatEventActive == true or IsCombatLockdownActive()
end

local function ShouldHideTomTomNow()
    return IsInCombat()
        and type(NS.ShouldHideTomTomInCombat) == "function"
        and NS.ShouldHideTomTomInCombat() == true
end

local function ShouldHideWorldOverlayNow()
    return IsInCombat()
        and type(NS.ShouldHideWorldOverlayInCombat) == "function"
        and NS.ShouldHideWorldOverlayInCombat() == true
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

local function RestoreTomTomArrowParent()
    if ShouldAvoidProtectedVisibilityCalls() then
        return
    end

    local arrow = GetTomTomArrow()
    local host = guard.tomTomVisibilityHost
    if type(arrow) ~= "table" or type(host) ~= "table" then
        return
    end
    if type(arrow.GetParent) ~= "function" or type(arrow.SetParent) ~= "function" then
        return
    end
    if arrow:GetParent() ~= host then
        guard.tomTomOriginalParent = nil
        return
    end

    arrow:SetParent(guard.tomTomOriginalParent or UIParent)
    guard.tomTomOriginalParent = nil
end

local function EnsureTomTomVisibilityHost()
    local arrow = GetTomTomArrow()
    if type(arrow) ~= "table" then
        return nil
    end
    if ShouldAvoidProtectedVisibilityCalls() then
        return guard.tomTomVisibilityHost
    end
    if type(CreateFrame) ~= "function" or type(UIParent) ~= "table" then
        return nil
    end

    local host = guard.tomTomVisibilityHost
    if type(host) ~= "table" then
        host = CreateFrame("Frame", "AWP_TomTomCombatVisibilityHost", UIParent, "SecureHandlerStateTemplate")
        host:SetAllPoints(UIParent)
        host:Show()
        guard.tomTomVisibilityHost = host
    end

    if type(arrow.GetParent) == "function"
        and type(arrow.SetParent) == "function"
        and arrow:GetParent() ~= host
    then
        guard.tomTomOriginalParent = guard.tomTomOriginalParent or arrow:GetParent()
        arrow:SetParent(host)
    end

    return host
end

local function ApplyTomTomCombatStateDriver()
    if ShouldAvoidProtectedVisibilityCalls() then
        return
    end

    local host = EnsureTomTomVisibilityHost()
    if type(host) ~= "table"
        or type(RegisterStateDriver) ~= "function"
        or type(UnregisterStateDriver) ~= "function"
    then
        return
    end

    local wanted = type(NS.ShouldHideTomTomInCombat) == "function"
        and NS.ShouldHideTomTomInCombat() == true

    if wanted and not guard.tomTomVisibilityDriver then
        RegisterStateDriver(host, "visibility", "[combat] hide; show")
        guard.tomTomVisibilityDriver = true
    elseif not wanted and guard.tomTomVisibilityDriver then
        UnregisterStateDriver(host, "visibility")
        guard.tomTomVisibilityDriver = false
        host:Show()
        RestoreTomTomArrowParent()
    elseif not wanted then
        host:Show()
        RestoreTomTomArrowParent()
    end
end

local function ApplyTomTomGuard()
    ApplyTomTomCombatStateDriver()
    local hidden = ShouldHideTomTomNow()
    if type(NS.SuppressTomTomArrowDisplay) == "function" then
        NS.SuppressTomTomArrowDisplay(hidden, TOMTOM_SUPPRESSION_REASON)
    end
    if type(NS.ApplySpecialActionCombatVisibility) == "function" then
        NS.ApplySpecialActionCombatVisibility(hidden)
    end
end

function NS.IsTomTomCombatHidden()
    return ShouldHideTomTomNow()
end

function NS.IsWorldOverlayCombatHidden()
    return ShouldHideWorldOverlayNow()
end

function NS.SetCombatVisibilityEventActive(active)
    guard.combatEventActive = active and true or false
end

function NS.ApplyCombatVisibilityGuard()
    ApplyTomTomGuard()
    if type(NS.RefreshWorldOverlay) == "function" then
        NS.RefreshWorldOverlay()
    end
end
