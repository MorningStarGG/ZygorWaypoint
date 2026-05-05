local NS = _G.AzerothWaypointNS
local state = NS.State

-- ============================================================
-- state.routing — neutral routing state (shared with all backends)
-- ============================================================
--
-- Initialized here because special_actions.lua loads early relative to
-- the rest of bridge/*. The lightweight state-read accessors live in
-- core/util.lua so consumers (notably world_overlay/runtime/host.lua)
-- can bind them as file-local upvalues at load time without ordering
-- against bridge/*.

state.routing = state.routing or {
    manualAuthority      = nil,    -- {mapID,x,y,title,sig,identity,meta,backend,createdAt,legs,currentLeg,specialAction}
    guideRouteState      = nil,    -- {target = {mapID,x,y,title,kind="guide_goal"}, suppressed=false, legs, currentLeg, specialAction}
    carrierState         = nil,    -- {mapID,x,y,title,sig,source="manual"|"guide",uid}
    manualQueues         = nil,    -- {order={},byID={},activeQueueID=nil,nextID=1}
    guideQueue           = nil,    -- {id="guide",kind="route",sourceType="guide",projection={...}}
    transientQueueStack  = nil,    -- { {id,kind="route",sourceType="transient_source",items={...},projection={...}} }
    queueUIState         = nil,    -- {selectedKey=nil,detailsByKey={}}
    publishedQueueState  = nil,    -- {queueKey=nil,signature=nil,uidByEntryKey={}}
    specialActionState   = nil,    -- see Special Action Schema in PLAN
    presentationState    = nil,    -- {carrierTitle,carrierStatus,overlayTitle,overlaySubtext,iconHint}
    specialActionPresented = false,
    specialActionPresentedSig = nil,

    cinematicActive      = false,
    pendingSpecialAction = nil,    -- queued when in combat, applied on PLAYER_REGEN_ENABLED
    specialActionCasting       = false,  -- true while a click→cast is in flight; freezes route replans
    specialActionCastSeq       = 0,      -- monotonic seq, scopes safety-timer callbacks to a single click
    specialActionCastGUID      = nil,    -- castGUID captured at UNIT_SPELLCAST_START, scopes cast-end matching
    specialActionCastStartSeen = false,  -- true once UNIT_SPELLCAST_START fired for the current freeze
    lastPushedOverlaySig = nil,
    lastPushedCarrierUID = nil,

    selectedBackend      = nil,    -- "zygor" | "farstrider" | "mapzeroth" | "direct" (resolved at boot)
}

-- ============================================================
-- Secure-action button (persistent SecureActionButtonTemplate)
-- ============================================================
--
-- One persistent secure frame, created lazily at first use. Never
-- reparented, never has protected attributes mutated in combat. When
-- specialActionState changes during combat, attribute application is
-- queued and replayed on PLAYER_REGEN_ENABLED.

local SECURE_PAYLOAD_ATTR = {
    spell = "spell",
    item  = "item",
    toy   = "toy",
    macro = "macrotext",
}

local secureButton = nil
local secureButtonIcon = nil
local secureButtonBackdrop = nil
local secureButtonHighlight = nil
local secureButtonLabel = nil
local activeSecureAttributeKeys = {}
local tomTomArrowStatusSuppressed = false
local tomTomStatusSuppressionHooked = false

local QUESTION_MARK_TEXTURE = "Interface\\Icons\\INV_Misc_QuestionMark"
local ACTION_BUTTON_BASE_SIZE = 56
local ACTION_BUTTON_MIN_SIZE = 40
local TOMTOM_STATUS_FIELDS = { "status", "tta", "eta" }

-- ============================================================
-- Special-action cast-freeze
-- ============================================================
--
-- Route replans are frozen for the duration of a special-action cast so a
-- transient side-effect of starting the cast (e.g. SPELL_UPDATE_COOLDOWN
-- firing as the GCD/cooldown begins, LibRover/Mapzeroth re-reporting
-- travel options) doesn't make the planner switch to an alternative leg
-- mid-cast.
--
-- The freeze is engaged synchronously by a PostClick hook on the secure
-- button — this fires before any of the resulting events (SPELL_UPDATE_*,
-- UNIT_SPELLCAST_*), which avoids the race where a cooldown-driven replan
-- runs before the cast even begins. Cast-end events (matched by castGUID
-- captured at UNIT_SPELLCAST_START) release it. Two safety timers cover
-- the no-op-click case (item on cooldown, OOR — no UNIT_SPELLCAST_START
-- arrives) and the stuck-cast case (events somehow don't resolve).

local CAST_NO_START_TIMEOUT_SECONDS = 2.0
local CAST_MAX_DURATION_SECONDS     = 30.0

local function ScheduleAfter(delay, fn)
    if type(NS.After) == "function" then
        NS.After(delay, fn)
    elseif type(C_Timer) == "table" and type(C_Timer.After) == "function" then
        C_Timer.After(delay, fn)
    end
end

local function ReleaseSpecialActionCastFreeze(reason)
    local routing = state.routing
    if not routing.specialActionCasting then return end
    routing.specialActionCasting = false
    routing.specialActionCastGUID = nil
    routing.specialActionCastStartSeen = false
    if type(NS.ScheduleActiveRouteRefresh) == "function" then
        NS.ScheduleActiveRouteRefresh(reason or "post_cast")
    end
end

local function EngageSpecialActionCastFreeze()
    local routing = state.routing
    routing.specialActionCasting = true
    routing.specialActionCastGUID = nil
    routing.specialActionCastStartSeen = false
    routing.specialActionCastSeq = (routing.specialActionCastSeq or 0) + 1
    local seq = routing.specialActionCastSeq

    -- No-cast safety: PostClick fired but no UNIT_SPELLCAST_START arrived
    -- within the window — treat the click as a no-op (OOC, OOR, on CD).
    ScheduleAfter(CAST_NO_START_TIMEOUT_SECONDS, function()
        local r = state.routing
        if r.specialActionCastSeq == seq
            and r.specialActionCasting
            and not r.specialActionCastStartSeen
        then
            ReleaseSpecialActionCastFreeze("no_cast_started")
        end
    end)

    -- Max-duration safety: cast events somehow never resolved. Shouldn't
    -- happen in practice, but better to thaw than to permanently lock.
    ScheduleAfter(CAST_MAX_DURATION_SECONDS, function()
        local r = state.routing
        if r.specialActionCastSeq == seq and r.specialActionCasting then
            ReleaseSpecialActionCastFreeze("cast_timeout")
        end
    end)
end

local function ResolveSpellTexture(spellIdentifier)
    local spellAPI = type(C_Spell) == "table" and C_Spell or nil
    local getSpellTexture = spellAPI and rawget(spellAPI, "GetSpellTexture") or nil
    if type(getSpellTexture) == "function" then
        local texture = getSpellTexture(spellIdentifier)
        if texture then
            return texture
        end
    end
    local legacyGetSpellTexture = rawget(_G, "GetSpellTexture")
    if type(legacyGetSpellTexture) == "function" then
        return legacyGetSpellTexture(spellIdentifier)
    end
    return nil
end

local function ResolveToyName(toy)
    if type(toy) == "string" and toy ~= "" then
        return toy
    end
    local toyID = tonumber(toy)
    if not toyID then
        return nil
    end
    if type(C_ToyBox) == "table" and type(C_ToyBox.GetToyInfo) == "function" then
        local _, toyName = C_ToyBox.GetToyInfo(toyID)
        if type(toyName) == "string" and toyName ~= "" then
            return toyName
        end
    end
    if type(C_Item) == "table" and type(C_Item.GetItemNameByID) == "function" then
        local itemName = C_Item.GetItemNameByID(toyID)
        if type(itemName) == "string" and itemName ~= "" then
            return itemName
        end
    end
    local getItemInfo = rawget(_G, "GetItemInfo")
    if type(getItemInfo) == "function" then
        local itemName = getItemInfo(toyID)
        if type(itemName) == "string" and itemName ~= "" then
            return itemName
        end
    end
    return nil
end

local function GetTomTomArrowFrame()
    return type(NS.GetTomTomArrow) == "function" and NS.GetTomTomArrow() or nil
end

local function GetOrCreateSecureButton()
    if secureButton then return secureButton end
    secureButton = CreateFrame("Button", "AWP_SpecialActionButton", UIParent, "SecureActionButtonTemplate")
    secureButton:SetSize(ACTION_BUTTON_BASE_SIZE, ACTION_BUTTON_BASE_SIZE)
    secureButton:Hide()
    secureButton:RegisterForClicks("LeftButtonUp", "LeftButtonDown")
    secureButton:SetFrameStrata("MEDIUM")
    secureButtonBackdrop = secureButton:CreateTexture(nil, "BACKGROUND")
    secureButtonBackdrop:SetAllPoints()
    secureButtonIcon = secureButton:CreateTexture(nil, "ARTWORK")
    secureButtonIcon:SetPoint("TOPLEFT", secureButton, "TOPLEFT", 2, -2)
    secureButtonIcon:SetPoint("BOTTOMRIGHT", secureButton, "BOTTOMRIGHT", -2, 2)
    secureButtonHighlight = secureButton:CreateTexture(nil, "HIGHLIGHT")
    secureButtonHighlight:SetTexture("Interface\\Buttons\\ButtonHilight-Square")
    secureButtonHighlight:SetBlendMode("ADD")
    secureButtonHighlight:SetPoint("TOPLEFT", secureButton, "TOPLEFT", 1, -1)
    secureButtonHighlight:SetPoint("BOTTOMRIGHT", secureButton, "BOTTOMRIGHT", -1, 1)
    secureButton:SetHighlightTexture(secureButtonHighlight)
    secureButtonLabel = secureButton:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    secureButtonLabel:SetPoint("TOP", secureButton, "BOTTOM", 0, -2)
    secureButtonLabel:SetWidth(180)
    secureButtonLabel:SetJustifyH("CENTER")
    secureButtonLabel:SetText("")
    secureButtonLabel:Hide()

    -- PostClick fires synchronously after the secure click handler — this is
    -- before SPELL_UPDATE_COOLDOWN / UNIT_SPELLCAST_START events for the
    -- triggered cast, which is exactly what we need to win the race against
    -- the backend's cooldown-driven replan.
    secureButton:HookScript("OnClick", function(_, button, _)
        if button == "LeftButton" and state.routing.specialActionPresented == true then
            EngageSpecialActionCastFreeze()
        end
    end)

    -- Right-click delegates to the TomTom arrow frame's OnClick handler so the
    -- native TomTom context menu appears (Clear waypoint, Lock arrow, etc.).
    -- OnMouseUp fires regardless of RegisterForClicks, so no secure handler runs.
    secureButton:HookScript("OnMouseUp", function(_, button)
        if button == "RightButton" then
            local arrowFrame = GetTomTomArrowFrame()
            if arrowFrame then
                local script = arrowFrame:GetScript("OnClick")
                if type(script) == "function" then
                    script(arrowFrame, "RightButton", false)
                end
            end
        end
    end)

    return secureButton
end

function NS.GetSpecialActionButton()
    return GetOrCreateSecureButton()
end

local function GetDisplayMode()
    local db = type(NS.GetDB) == "function" and NS.GetDB() or nil
    local mode = db and db.specialTravelDisplayMode or nil
    if mode == "companion_icon" then
        return mode
    end
    return "replace_arrow"
end

local function GetTomTomArrowProfile()
    local tomtom = _G["TomTom"]
    return tomtom and tomtom.db and tomtom.db.profile and tomtom.db.profile.arrow or nil
end

local function ResetSpecialActionPresentation()
    state.routing.specialActionPresented = false
    state.routing.specialActionPresentedSig = nil
end

local function RestoreTomTomArrowVisuals()
    if type(NS.SuppressTomTomArrowDisplay) == "function" then
        NS.SuppressTomTomArrowDisplay(false)
    end
end

local function ApplyTomTomArrowStatusSuppression()
    local frame = GetTomTomArrowFrame()
    if type(frame) ~= "table" then
        return
    end

    local shown = not tomTomArrowStatusSuppressed
    for _, key in ipairs(TOMTOM_STATUS_FIELDS) do
        local region = frame[key]
        if type(region) == "table" and type(region.SetShown) == "function" then
            region:SetShown(shown)
        end
    end
end

local function HookTomTomStatusSuppression()
    if tomTomStatusSuppressionHooked then
        return
    end
    local tomtom = type(NS.GetTomTom) == "function" and NS.GetTomTom() or nil
    if type(tomtom) ~= "table" or type(tomtom.ShowHideCrazyArrow) ~= "function" then
        return
    end
    tomTomStatusSuppressionHooked = true
    hooksecurefunc(tomtom, "ShowHideCrazyArrow", function()
        if tomTomArrowStatusSuppressed then
            ScheduleAfter(0, ApplyTomTomArrowStatusSuppression)
        end
    end)
end

local function SetTomTomArrowStatusVisible(visible)
    tomTomArrowStatusSuppressed = not visible
    HookTomTomStatusSuppression()
    ApplyTomTomArrowStatusSuppression()
end

local function HideSpecialActionVisuals()
    ResetSpecialActionPresentation()
    RestoreTomTomArrowVisuals()
    SetTomTomArrowStatusVisible(true)
    if secureButtonLabel then
        secureButtonLabel:SetText("")
        secureButtonLabel:Hide()
    end
    if secureButton and not InCombatLockdown() then
        secureButton:Hide()
    end
end

local function ClearSecureActionAttributes()
    local btn = secureButton
    if btn and not InCombatLockdown() then
        for key in pairs(activeSecureAttributeKeys) do
            btn:SetAttribute(key, nil)
            activeSecureAttributeKeys[key] = nil
        end
        btn:SetAttribute("type", nil)
        btn:SetAttribute("spell", nil)
        btn:SetAttribute("item", nil)
        btn:SetAttribute("toy", nil)
        btn:SetAttribute("macrotext", nil)
        btn:SetAttribute("unit", nil)
    end
end

local function IsAtlasLike(texture)
    return type(texture) == "string" and texture ~= "" and texture:find("[\\/]") == nil
end

local function ResolveActionTexture(action)
    if type(action) ~= "table" then
        return QUESTION_MARK_TEXTURE, false
    end

    if type(action.iconTexture) == "string" and action.iconTexture ~= "" then
        return action.iconTexture, IsAtlasLike(action.iconTexture)
    end

    if action.secureType == "spell"
        and (type(action.securePayload) == "string" or type(action.securePayload) == "number")
    then
        local texture = ResolveSpellTexture(action.securePayload)
        if texture then
            return texture, false
        end
    end

    local itemID = nil
    if action.secureType == "item" or action.secureType == "toy" then
        itemID = tonumber(action.securePayload)
    end
    if itemID and type(C_Item) == "table" and type(C_Item.GetItemIconByID) == "function" then
        local texture = C_Item.GetItemIconByID(itemID)
        if texture then
            return texture, false
        end
    end

    return QUESTION_MARK_TEXTURE, false
end

local function ResolveActionText(action)
    if type(action) ~= "table" then
        return nil
    end
    return action.name or action.title or action.destinationName
end

local function ResolveDisplayTitle(action)
    local presentation = state.routing and state.routing.presentationState or nil
    if type(presentation) == "table" and type(presentation.carrierTitle) == "string" and presentation.carrierTitle ~= "" then
        return presentation.carrierTitle
    end
    return ResolveActionText(action)
end

local function EnsureTomTomTitleVisible()
    local frame = GetTomTomArrowFrame()
    local title = type(frame) == "table" and frame.title or nil
    if type(frame) ~= "table" or (type(frame.IsShown) == "function" and not frame:IsShown()) then
        return false
    end
    if type(title) ~= "table" then
        return false
    end
    local text = type(title.GetText) == "function" and title:GetText() or nil
    if type(text) ~= "string" or text == "" then
        return false
    end
    if type(title.SetShown) == "function" then
        title:SetShown(true)
    elseif type(title.Show) == "function" then
        title:Show()
    end
    if type(title.IsVisible) == "function" and not title:IsVisible() then
        return false
    end
    return true
end

local function SetSpecialActionLabel(action, visible)
    if not secureButtonLabel then
        return
    end
    if not visible then
        secureButtonLabel:SetText("")
        secureButtonLabel:Hide()
        return
    end
    local label = ResolveDisplayTitle(action)
    if type(label) == "string" and label ~= "" then
        secureButtonLabel:SetText(label)
        secureButtonLabel:Show()
    else
        secureButtonLabel:SetText("")
        secureButtonLabel:Hide()
    end
end

local function ApplyActionIconVisual(action)
    local btn = GetOrCreateSecureButton()
    local texture, useAtlas = ResolveActionTexture(action)
    if secureButtonIcon then
        if useAtlas and type(secureButtonIcon.SetAtlas) == "function" then
            secureButtonIcon:SetTexture(nil)
            secureButtonIcon:SetAtlas(texture, true)
        else
            secureButtonIcon:SetTexture(texture)
        end
    end
    btn:SetAlpha(1)
end

local function ApplyActionButtonScale(btn, anchorFrame)
    if type(btn) ~= "table" or type(anchorFrame) ~= "table" then
        return
    end
    local size = math.max(ACTION_BUTTON_BASE_SIZE, ACTION_BUTTON_MIN_SIZE)
    btn:SetSize(size, size)

    local parentScale = type(UIParent) == "table" and UIParent.GetEffectiveScale and UIParent:GetEffectiveScale() or 1
    local anchorScale = anchorFrame.GetEffectiveScale and anchorFrame:GetEffectiveScale() or parentScale
    local buttonScale = type(NS.GetSpecialTravelButtonScale) == "function" and NS.GetSpecialTravelButtonScale() or 1
    if type(parentScale) == "number" and parentScale > 0 and type(anchorScale) == "number" and anchorScale > 0 then
        btn:SetScale((anchorScale / parentScale) * buttonScale)
    end
end

local function ApplyActionLabelLayout(anchorFrame)
    if not secureButtonLabel then
        return
    end
    local title = type(anchorFrame) == "table" and anchorFrame.title or nil
    if type(title) == "table" and type(title.GetFontObject) == "function" then
        local fontObject = title:GetFontObject()
        if fontObject then
            secureButtonLabel:SetFontObject(fontObject)
        end
    end
    local profile = GetTomTomArrowProfile()
    local width = type(profile) == "table" and tonumber(profile.title_width) or nil
    local height = type(profile) == "table" and tonumber(profile.title_height) or nil
    local scale = type(profile) == "table" and tonumber(profile.title_scale) or nil
    secureButtonLabel:SetWidth(width or 180)
    if height and height > 0 then
        secureButtonLabel:SetHeight(height)
    end
    secureButtonLabel:SetScale(scale and scale > 0 and scale or 1)
end

local function AnchorActionButton(mode)
    local btn = GetOrCreateSecureButton()
    local arrowFrame = GetTomTomArrowFrame()
    if not arrowFrame then
        btn:Hide()
        return false
    end

    btn:ClearAllPoints()
    btn:SetParent(UIParent)
    ApplyActionButtonScale(btn, arrowFrame)
    ApplyActionLabelLayout(arrowFrame)
    btn:SetFrameLevel((arrowFrame:GetFrameLevel() or 1) + 10)
    if mode == "companion_icon" then
        btn:SetPoint("LEFT", arrowFrame, "RIGHT", 10, 0)
    else
        btn:SetPoint("BOTTOM", arrowFrame, "BOTTOM", 0, 0)
    end
    return true
end

local function SetTomTomArrowVisible(visible)
    if type(NS.SuppressTomTomArrowDisplay) == "function" then
        NS.SuppressTomTomArrowDisplay(not visible)
    end
    SetTomTomArrowStatusVisible(visible)
end

local function IsActionInActivationRange(action)
    if type(action) ~= "table" then
        return false
    end
    local activationMode = action.activationMode
    if activationMode == "portable" then
        return true
    end
    local coords = action.activationCoords
    if type(coords) ~= "table" then
        return activationMode ~= "location"
    end
    if type(coords.mapID) ~= "number" or type(coords.x) ~= "number" or type(coords.y) ~= "number" then
        return activationMode ~= "location"
    end
    if type(NS.GetPlayerWaypointDistance) ~= "function" then
        return false
    end
    local distance = NS.GetPlayerWaypointDistance(coords.mapID, coords.x, coords.y)
    local radius = type(action.activationRadiusYards) == "number" and action.activationRadiusYards or 15
    return type(distance) == "number" and distance <= radius
end

local function ShowSecureActionVisuals(action)
    HideSpecialActionVisuals()
    if type(action) ~= "table" then
        return
    end
    if not IsActionInActivationRange(action) then
        return
    end

    local mode = GetDisplayMode()
    if not AnchorActionButton(mode) then
        return
    end
    local btn = GetOrCreateSecureButton()
    ApplyActionIconVisual(action)
    SetTomTomArrowVisible(mode ~= "replace_arrow")
    SetSpecialActionLabel(action, mode ~= "replace_arrow" or not EnsureTomTomTitleVisible())
    btn:Show()
    state.routing.specialActionPresented = true
    state.routing.specialActionPresentedSig = action.sig
end

function NS.RefreshSpecialActionButtonPresentation()
    local action = state.routing and state.routing.specialActionState or nil
    if state.routing.specialActionPresented == true and type(action) == "table" then
        ShowSecureActionVisuals(action)
    end
end

-- Show + activate. Caller has already armed secure attributes out of combat.
function NS.SpecialActionShowActive(action)
    ShowSecureActionVisuals(action)
end

-- Clear secure attributes when safe. No-op if currently in combat.
function NS.DisarmSpecialActionButton()
    state.routing.pendingSpecialAction = nil
    ReleaseSpecialActionCastFreeze("disarm")
    ClearSecureActionAttributes()
    HideSpecialActionVisuals()
end

local function ApplyFunctionActionAttributes(btn, action)
    if type(btn) ~= "table" or type(action) ~= "table" or type(action.securePayload) ~= "function" then
        return false
    end
    local ok, attributes = pcall(action.securePayload)
    if not ok then
        if type(NS.Log) == "function" then
            NS.Log("Special action initfunc failed", tostring(attributes))
        end
        return false
    end
    if type(attributes) ~= "table" then
        if type(NS.Log) == "function" then
            NS.Log("Special action initfunc returned non-table", tostring(attributes))
        end
        return false
    end
    ClearSecureActionAttributes()
    for key, value in pairs(attributes) do
        btn:SetAttribute(key, value)
        activeSecureAttributeKeys[key] = true
    end
    return true
end

-- Apply a specialAction record. Combat-safe: defers protected attribute
-- writes when InCombatLockdown(). Non-secure route legs are ignored so
-- taxi/gossip/talk remain normal arrow targets.
function NS.ApplySpecialAction(action)
    if not action or not IsActionInActivationRange(action) then
        NS.DisarmSpecialActionButton()
        return
    end

    local isFunctionAction = action.secureType == "function" and type(action.securePayload) == "function"
    local payloadAttr = SECURE_PAYLOAD_ATTR[action.secureType]
    if not isFunctionAction and (not payloadAttr or action.securePayload == nil or action.securePayload == "") then
        -- Defensive: secureType outside spell/item/toy/macro — treat as non-actionable.
        NS.DisarmSpecialActionButton()
        return
    end

    if InCombatLockdown() then
        state.routing.pendingSpecialAction = action
        if state.routing.specialActionPresented == true
            and state.routing.specialActionPresentedSig == action.sig
        then
            return
        end
        HideSpecialActionVisuals()
        return
    end

    local btn = GetOrCreateSecureButton()
    if isFunctionAction then
        if not ApplyFunctionActionAttributes(btn, action) then
            NS.DisarmSpecialActionButton()
            return
        end
        NS.SpecialActionShowActive(action)
        return
    end

    ClearSecureActionAttributes()

    -- Items: SecureCmdItemParse treats a bare numeric "item" attribute as a
    -- bag *slot*, which then crashes inside SecureTemplates' equippability
    -- check. Route itemIDs through a /use macro instead — works regardless
    -- of item caching, link availability, or bag location.
    if action.secureType == "item" then
        local itemID = tonumber(action.securePayload)
        if itemID then
            btn:SetAttribute("type", "macro")
            btn:SetAttribute("macrotext", "/use item:" .. itemID)
        else
            btn:SetAttribute("type", "item")
            btn:SetAttribute("item", tostring(action.securePayload))
        end
    elseif action.secureType == "toy" then
        local toyName = ResolveToyName(action.securePayload)
        if not toyName then
            if type(NS.Log) == "function" then
                NS.Log("Special action toy name unavailable", tostring(action.securePayload))
            end
            NS.DisarmSpecialActionButton()
            return
        end
        btn:SetAttribute("type", "toy")
        btn:SetAttribute("toy", toyName)
    else
        btn:SetAttribute("type", action.secureType)
        btn:SetAttribute(payloadAttr, action.securePayload)
    end
    if type(action.secureUnit) == "string" and action.secureUnit ~= "" then
        btn:SetAttribute("unit", action.secureUnit)
    end
    -- Do NOT touch the cast-freeze here. ApplySpecialAction is called
    -- from RecomputeCarrier on every backend-invalidation event (e.g.
    -- SPELL_UPDATE_COOLDOWN fired by the cast itself going on cooldown).
    -- Releasing the freeze here would cancel the very lock that PostClick
    -- just engaged and reopen the gate, causing the planner to swap the
    -- hearthstone leg for an alternative mid-cast. The freeze is owned
    -- by PostClick (engage) and the cast-end / safety-timer paths (release).
    NS.SpecialActionShowActive(action)
end

-- ============================================================
-- Combat re-arm + special-action cast tracking
-- ============================================================
--
-- The freeze itself is engaged by the PostClick hook on the secure button
-- (see GetOrCreateSecureButton). These events only handle release: we
-- capture castGUID at UNIT_SPELLCAST_START so a cast-end event releases
-- the freeze only for the cast that actually started after our click,
-- not for an unrelated /failed/ from a spell the player tries to queue
-- mid-cast.

local CAST_END_EVENTS = {
    UNIT_SPELLCAST_STOP          = true,
    UNIT_SPELLCAST_CHANNEL_STOP  = true,
    UNIT_SPELLCAST_SUCCEEDED     = true,
    UNIT_SPELLCAST_INTERRUPTED   = true,
    UNIT_SPELLCAST_FAILED        = true,
    UNIT_SPELLCAST_FAILED_QUIET  = true,
}

local combatFrame = CreateFrame("Frame")
combatFrame:RegisterEvent("PLAYER_REGEN_ENABLED")
combatFrame:RegisterUnitEvent("UNIT_SPELLCAST_START", "player")
combatFrame:RegisterUnitEvent("UNIT_SPELLCAST_CHANNEL_START", "player")
combatFrame:RegisterUnitEvent("UNIT_SPELLCAST_STOP", "player")
combatFrame:RegisterUnitEvent("UNIT_SPELLCAST_CHANNEL_STOP", "player")
combatFrame:RegisterUnitEvent("UNIT_SPELLCAST_SUCCEEDED", "player")
combatFrame:RegisterUnitEvent("UNIT_SPELLCAST_INTERRUPTED", "player")
combatFrame:RegisterUnitEvent("UNIT_SPELLCAST_FAILED", "player")
combatFrame:RegisterUnitEvent("UNIT_SPELLCAST_FAILED_QUIET", "player")
combatFrame:SetScript("OnEvent", function(_, event, unit, castGUID)
    if event == "PLAYER_REGEN_ENABLED" then
        local pending = state.routing.pendingSpecialAction
        if pending then
            state.routing.pendingSpecialAction = nil
            NS.ApplySpecialAction(pending)
        end
        if state.routing.pendingCarrierRecompute then
            state.routing.pendingCarrierRecompute = nil
            if type(NS.RecomputeCarrier) == "function" then
                NS.RecomputeCarrier()
            end
        end
        return
    end

    if unit ~= "player" then return end
    local routing = state.routing
    if not routing.specialActionCasting then return end

    if event == "UNIT_SPELLCAST_START" or event == "UNIT_SPELLCAST_CHANNEL_START" then
        -- Capture the castGUID of the cast that started after our PostClick.
        -- Cast-end events scope to this GUID so unrelated /failed/ events
        -- the player triggers (e.g. attempting another spell mid-cast)
        -- don't release the freeze prematurely.
        routing.specialActionCastStartSeen = true
        routing.specialActionCastGUID = castGUID
        return
    end

    if CAST_END_EVENTS[event] then
        local cachedGUID = routing.specialActionCastGUID
        -- cachedGUID == nil handles instant casts where SUCCEEDED fires
        -- without a preceding START (e.g. an instant teleport spell or toy).
        if cachedGUID == nil or cachedGUID == castGUID then
            ReleaseSpecialActionCastFreeze("post_cast")
        end
    end
end)
