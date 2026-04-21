local NS = _G.ZygorWaypointNS
local state = NS.State
local M = NS.Internal.Interface.commands
local trim = M.trim
local IsAddonLoaded = NS.IsAddonLoaded

-- ============================================================
-- Formatting utilities
-- ============================================================

local function countTableEntries(tbl)
    if type(tbl) ~= "table" then
        return 0
    end

    local count = 0
    for _ in pairs(tbl) do
        count = count + 1
    end
    return count
end

local function formatMemoryKB(value)
    value = tonumber(value)
    if not value then
        return "n/a"
    end
    return string.format("%.1f KB", value)
end

local function formatPercent(numerator, denominator)
    numerator = tonumber(numerator)
    denominator = tonumber(denominator)
    if not numerator or not denominator or denominator <= 0 then
        return "n/a"
    end
    return string.format("%.1f%%", (numerator / denominator) * 100)
end

local function getTotalAddonMemoryKB()
    UpdateAddOnMemoryUsage()
    local total = 0
    local count = C_AddOns.GetNumAddOns()
    for index = 1, count do
        total = total + (tonumber(GetAddOnMemoryUsage(index)) or 0)
    end
    return total
end

local function getAddonMemoryKB(name)
    if type(name) ~= "string" or name == "" then
        return nil
    end
    UpdateAddOnMemoryUsage()
    return GetAddOnMemoryUsage(name)
end

-- ============================================================
-- Plaque test
-- ============================================================

local plaqueState = {
    active = false,
    width = 320,
    variant = "default",
}

local PLAQUE_WIDTH_MIN = 160
local PLAQUE_WIDTH_MAX = 512
local PLAQUE_VARIANTS = {
    default = {
        title = "Very Long Destination Name For Plaque Testing",
        subtext = "1234 yd  Secondary text",
    },
    short = {
        title = "Plaque Test",
        subtext = "123 yd",
    },
    wrap = {
        title = "A Much Longer Destination Name That Should Wrap! Let's see what it does!",
        subtext = "Second line wrap stress test, this is a very long line just because we can. Love you all!",
    },
}

local function clamp(value, minValue, maxValue)
    return math.max(minValue, math.min(maxValue, value))
end

local DEFAULT_PINPOINT_PANEL_SPEC = {
    wrapW = 176,
    maxW = 224,
}

local DEFAULT_GLOW_PULSE = {
    base = 0.15,
}

local function getDefaultPlaqueSpec(native)
    local plaques = native and native.Plaques or nil
    if plaques and plaques.GetSpec then
        return plaques.GetSpec(NS.Constants.WORLD_OVERLAY_PLAQUE_DEFAULT) or DEFAULT_PINPOINT_PANEL_SPEC
    end
    return DEFAULT_PINPOINT_PANEL_SPEC
end

local function getGlowingGemsGlowSpec(native)
    local animations = native and native.PlaqueAnimations or nil
    if animations and animations.GetSpec then
        local specs = animations.GetSpec(NS.Constants.WORLD_OVERLAY_PLAQUE_GLOWING_GEMS)
        if type(specs) == "table" then
            for _, spec in ipairs(specs) do
                if spec and spec.type == "corner_gems" and type(spec.glow) == "table" then
                    return spec.glow
                end
            end
        end
    end
    return DEFAULT_GLOW_PULSE
end

local function getDefaultPlaqueWidth(native)
    local spec = getDefaultPlaqueSpec(native)
    local width = tonumber(spec.wrapW) or nil
    if not width then
        width = tonumber(spec.maxW) or nil
    end
    return math.floor(clamp(width or 224, PLAQUE_WIDTH_MIN, PLAQUE_WIDTH_MAX) + 0.5)
end

local function showPlaqueUsage()
    NS.Msg("Usage: /zwp plaque [width] | /zwp plaque short [width] | /zwp plaque wrap [width] | /zwp plaque off")
    NS.Msg("Examples: /zwp plaque 224 | /zwp plaque wrap 224 | /zwp plaque off")
end

local function restorePlaqueTest()
    local nativeState = NS.State.worldOverlayNative

    plaqueState.active = false

    if not nativeState or not nativeState.target or not nativeState.target.active then
        NS.ClearNativeWorldOverlay()
        NS.Msg("[PLAQUE] Test mode disabled.")
        return
    end

    NS.RefreshNativeWorldOverlay()
    NS.Msg("[PLAQUE] Test mode disabled.")
end

local function showPlaqueTest(variant, width)
    local native = NS.Internal.WorldOverlayNative
    if not native then
        NS.Msg("[PLAQUE] Native overlay is unavailable.")
        return
    end

    local sample = PLAQUE_VARIANTS[variant] or PLAQUE_VARIANTS.default
    width = math.floor(clamp(width or getDefaultPlaqueWidth(native), PLAQUE_WIDTH_MIN, PLAQUE_WIDTH_MAX) + 0.5)

    native.EnsurePinpointFrame()
    native.RefreshSettingsSnapshot()
    native.ApplyOverlayAdornmentStyleToAll(true)

    local overlay = native.overlay
    local settings = native.settingsSnapshot or {}
    local frame = overlay and overlay.pinpoint
    if not frame then
        NS.Msg("[PLAQUE] Pinpoint frame is unavailable.")
        return
    end

    if overlay.driver then
        overlay.driver:Hide()
    end
    if overlay.root then
        overlay.root:Show()
    end
    native.ShowOnlyFrame(frame)

    frame:ClearAllPoints()
    frame:SetPoint("CENTER", UIParent, "CENTER", 0, 140)
    frame:SetScale(settings.worldOverlayPinpointSize or 1)
    frame:SetAlpha(1)

    local function restoreDefaultTextColor(fontString)
        local color = fontString and fontString.__zwpDefaultTextColor or nil
        if not fontString or not color then
            return
        end

        fontString:SetTextColor(color.r or 1, color.g or 1, color.b or 1, color.a or 1)
    end

    local iconSpec = native.Config and native.Config.ICON_SPECS and native.Config.ICON_SPECS.guide or nil
    local tint = iconSpec and iconSpec.tint or native.Config and native.Config.DEFAULT_TINT or nil
    tint = tint or { r = 1, g = 1, b = 1, a = 1 }
    local arrowTint = native.ResolveArrowColor and native.ResolveArrowColor(iconSpec) or tint
    local animatedTint = native.ResolveAnimatedColor and native.ResolveAnimatedColor(iconSpec) or arrowTint
    local panelTint = native.ResolvePlaqueColors and native.ResolvePlaqueColors(iconSpec) or tint
    local textTint = native.ResolvePinpointTextColor and native.ResolvePinpointTextColor() or nil

    if frame.Panel then
        frame.Panel:SetVertexColor(panelTint.r or 1, panelTint.g or 1, panelTint.b or 1, 0.95)
    end
    if frame.Gems then
        frame.Gems:SetVertexColor(animatedTint.r or 1, animatedTint.g or 1, animatedTint.b or 1, animatedTint.a or 1)
    end
    if frame.Arrow1 then
        frame.Arrow1:SetVertexColor(arrowTint.r or 1, arrowTint.g or 1, arrowTint.b or 1, 1)
    end
    if frame.Arrow2 then
        frame.Arrow2:SetVertexColor(arrowTint.r or 1, arrowTint.g or 1, arrowTint.b or 1, 0.9)
    end
    if frame.Arrow3 then
        frame.Arrow3:SetVertexColor(arrowTint.r or 1, arrowTint.g or 1, arrowTint.b or 1, 0.8)
    end
    if frame.ContextIcon then
        native.SetContextIconSpec(frame.ContextIcon, iconSpec)
        frame.ContextIcon:Show()
    end
    local pulseAlpha = getGlowingGemsGlowSpec(native).base or 0.15
    if frame.GlowTL then frame.GlowTL:SetVertexColor(animatedTint.r or 1, animatedTint.g or 1, animatedTint.b or 1, pulseAlpha) end
    if frame.GlowTR then frame.GlowTR:SetVertexColor(animatedTint.r or 1, animatedTint.g or 1, animatedTint.b or 1, pulseAlpha) end
    if frame.GlowBL then frame.GlowBL:SetVertexColor(animatedTint.r or 1, animatedTint.g or 1, animatedTint.b or 1, pulseAlpha) end
    if frame.GlowBR then frame.GlowBR:SetVertexColor(animatedTint.r or 1, animatedTint.g or 1, animatedTint.b or 1, pulseAlpha) end

    frame.Title:SetShown(true)
    frame.Subtext:SetShown(true)
    frame.Title:SetText(sample.title)
    frame.Subtext:SetText(sample.subtext)
    if textTint then
        frame.Title:SetTextColor(textTint.r or 1, textTint.g or 1, textTint.b or 1, textTint.a or 1)
        frame.Subtext:SetTextColor(textTint.r or 1, textTint.g or 1, textTint.b or 1, textTint.a or 1)
    else
        restoreDefaultTextColor(frame.Title)
        restoreDefaultTextColor(frame.Subtext)
    end
    frame.Panel:SetWidth(width)
    if frame.PanelHost then
        frame.PanelHost:SetWidth(width)
    end
    frame:SetWidth(width)
    native.LayoutPinpointText(frame, width)

    plaqueState.active = true
    plaqueState.width = width
    plaqueState.variant = variant

    NS.Msg(string.format(
        "[PLAQUE] %s test at %d px, scale %.2f. Panel height: %d",
        variant,
        width,
        frame:GetScale() or 1,
        frame.Panel:GetHeight() or 0
    ))
end

local function handlePlaque(arg)
    arg = trim(arg)

    if arg == "" then
        showPlaqueTest("default")
        return
    end

    local first, rest = arg:match("^(%S+)%s*(.-)$")
    first = (first or ""):lower()
    rest = trim(rest)

    if first == "off" or first == "hide" or first == "stop" then
        restorePlaqueTest()
        return
    end

    if first == "help" then
        showPlaqueUsage()
        return
    end

    local variant = "default"
    local widthText = arg
    if PLAQUE_VARIANTS[first] then
        variant = first
        widthText = rest
    end

    local width
    if widthText ~= "" then
        width = tonumber(widthText)
        if not width then
            NS.Msg("[PLAQUE] Width must be a number.")
            showPlaqueUsage()
            return
        end
    end

    showPlaqueTest(variant, width)
end

-- ============================================================
-- Waytype debug
-- ============================================================

local waytypeState = {
    active = false,
    key = nil,
}

local WAYTYPE_STATUS_ALIASES = {
    available = "Available",
    incomplete = "Incomplete",
    active = "Incomplete",
    complete = "Complete",
    completed = "Complete",
    ready = "Complete",
}

local function splitWords(text)
    local words = {}
    for word in string.gmatch(text or "", "%S+") do
        words[#words + 1] = word:lower()
    end
    return words
end

local function normalizeWaytypeToken(text)
    text = trim(text or ""):lower()
    text = text:gsub("[%s%-%_]+", "")
    return text
end

local function makeWaytypeLabel(key)
    local text = tostring(key or "")
    text = text:gsub("[%-%_]+", " ")
    text = text:gsub("(%l)(%u)", "%1 %2")
    text = text:gsub("(%u)(%u%l)", "%1 %2")
    text = trim(text:gsub("%s+", " "))
    if text == "" then
        return "-"
    end

    local parts = {}
    for word in text:gmatch("%S+") do
        parts[#parts + 1] = word:sub(1, 1):upper() .. word:sub(2)
    end
    return table.concat(parts, " ")
end

local function getWaytypeQuestTypeDefs(native)
    return native and native.Config and native.Config.QUEST_ICON_TYPE_DEFS or nil
end

local function getWaytypeQuestTypeMap(native)
    local defs = getWaytypeQuestTypeDefs(native)
    local map = {}
    local keys = {}

    if type(defs) == "table" then
        for typeKey in pairs(defs) do
            map[normalizeWaytypeToken(typeKey)] = typeKey
            keys[#keys + 1] = typeKey
        end
    end

    if type(defs) == "table" and type(defs.Default) == "table" then
        map.quest = "Default"
        map.default = "Default"
    end

    table.sort(keys)
    return map, keys
end

local function getWaytypeGenericIconMap(native)
    local map = {}
    local keys = {}
    local iconSpecs = native and native.Config and native.Config.ICON_SPECS or nil

    if type(iconSpecs) == "table" then
        for key in pairs(iconSpecs) do
            map[normalizeWaytypeToken(key)] = key
            keys[#keys + 1] = key
        end
    end

    table.sort(keys)
    return map, keys
end

local function restoreDefaultTextColor(fontString)
    local color = fontString and fontString.__zwpDefaultTextColor or nil
    if not fontString or not color then
        return
    end

    fontString:SetTextColor(color.r or 1, color.g or 1, color.b or 1, color.a or 1)
end

local function formatWaytypeColor(color)
    if type(color) ~= "table" then
        return "n/a"
    end

    return string.format("(%.2f, %.2f, %.2f, %.2f)", color.r or 1, color.g or 1, color.b or 1, color.a or 1)
end

local function formatWaytypeTexture(iconSpec)
    if type(iconSpec) ~= "table" then
        return "-"
    end
    if type(iconSpec.atlas) == "string" and iconSpec.atlas ~= "" then
        return "atlas=" .. iconSpec.atlas
    end
    if iconSpec.texture ~= nil then
        return "texture=" .. tostring(iconSpec.texture)
    end
    return "-"
end

local function formatWaytypeIconSource(iconSpec)
    if type(iconSpec) ~= "table" then
        return "-"
    end

    local sourceMode = tostring(iconSpec.sourceMode or "-")
    local familyMode = tostring(iconSpec.familyMode or "-")
    return sourceMode .. "/" .. familyMode
end

local function formatWaytypeIconSize(iconSpec)
    if type(iconSpec) ~= "table" then
        return "-"
    end

    return tostring(iconSpec.iconSize or "default")
end

local function formatWaytypeQuestLabel(statusPrefix, typeKey)
    local questLabel = (typeKey == "Default") and "Quest" or (tostring(typeKey) .. " Quest")
    if type(statusPrefix) == "string" and statusPrefix ~= "" then
        return statusPrefix .. " " .. questLabel
    end
    return questLabel
end

local function showWaytypeUsage()
    local native = NS.Internal.WorldOverlayNative
    local _, genericKeys = getWaytypeGenericIconMap(native)
    local _, questTypeKeys = getWaytypeQuestTypeMap(native)

    NS.Msg("Usage: /zwp waytype")
    NS.Msg("       /zwp waytype <generic-key>")
    if #genericKeys > 0 then
        NS.Msg("       generic keys: " .. table.concat(genericKeys, ", "))
    end
    NS.Msg("       /zwp waytype <available|incomplete|complete> <quest-type>")
    if #questTypeKeys > 0 then
        NS.Msg("       quest types: " .. table.concat(questTypeKeys, ", "))
    end
    NS.Msg("       /zwp waytype quest <questID> | /zwp waytype off")
end

local function restoreWaytypePreview()
    local nativeState = NS.State.worldOverlayNative

    waytypeState.active = false
    waytypeState.key = nil

    if not nativeState or not nativeState.target or not nativeState.target.active then
        NS.ClearNativeWorldOverlay()
        NS.Msg("[WAYTYPE] Preview disabled.")
        return
    end

    NS.RefreshNativeWorldOverlay()
    NS.Msg("[WAYTYPE] Preview disabled.")
end

local function getGenericWaytypeIconSpec(native, key)
    if not native then
        return nil
    end

    if key == "hearth" or key == "inn" or key == "taxi" or key == "portal" or key == "travel" or key == "manual" then
        if native.ResolveTravelIconSpec then
            local travelSpec = native.ResolveTravelIconSpec(key)
            if travelSpec then
                return travelSpec
            end
        end
    end

    return native.Config and native.Config.ICON_SPECS and native.Config.ICON_SPECS[key] or nil
end

local function showWaytypePreview(info)
    local native = NS.Internal.WorldOverlayNative
    if not native then
        NS.Msg("[WAYTYPE] Native overlay is unavailable.")
        return
    end
    if type(info) ~= "table" or type(info.iconSpec) ~= "table" then
        NS.Msg("[WAYTYPE] Preview data is unavailable.")
        return
    end

    local iconSpec = info.iconSpec

    native.EnsurePinpointFrame()
    native.RefreshSettingsSnapshot()
    native.ApplyOverlayAdornmentStyleToAll(true)

    local overlay = native.overlay
    local settings = native.settingsSnapshot or {}
    local frame = overlay and overlay.pinpoint
    if not frame then
        NS.Msg("[WAYTYPE] Pinpoint frame is unavailable.")
        return
    end

    if overlay.driver then
        overlay.driver:Hide()
    end
    if overlay.root then
        overlay.root:Show()
    end
    native.ShowOnlyFrame(frame)

    frame:ClearAllPoints()
    frame:SetPoint("CENTER", UIParent, "CENTER", 0, 140)
    frame:SetScale(settings.worldOverlayPinpointSize or 1)
    frame:SetAlpha(1)

    local tint = iconSpec.tint or native.Config and native.Config.DEFAULT_TINT or nil
    tint = tint or { r = 1, g = 1, b = 1, a = 1 }
    local arrowTint = native.ResolveArrowColor and native.ResolveArrowColor(iconSpec) or tint
    local animatedTint = native.ResolveAnimatedColor and native.ResolveAnimatedColor(iconSpec) or arrowTint
    local panelTint = native.ResolvePlaqueColors and native.ResolvePlaqueColors(iconSpec) or tint
    local titleTint = native.ResolvePinpointTitleColor and native.ResolvePinpointTitleColor() or nil
    local subtextTint = native.ResolvePinpointSubtextColor and native.ResolvePinpointSubtextColor() or nil

    if frame.Panel then
        frame.Panel:SetVertexColor(panelTint.r or 1, panelTint.g or 1, panelTint.b or 1, 0.95)
    end
    if frame.Gems then
        frame.Gems:SetVertexColor(animatedTint.r or 1, animatedTint.g or 1, animatedTint.b or 1, animatedTint.a or 1)
    end
    if frame.Arrow1 then
        frame.Arrow1:SetVertexColor(arrowTint.r or 1, arrowTint.g or 1, arrowTint.b or 1, 1)
    end
    if frame.Arrow2 then
        frame.Arrow2:SetVertexColor(arrowTint.r or 1, arrowTint.g or 1, arrowTint.b or 1, 0.9)
    end
    if frame.Arrow3 then
        frame.Arrow3:SetVertexColor(arrowTint.r or 1, arrowTint.g or 1, arrowTint.b or 1, 0.8)
    end
    if frame.ContextIcon then
        native.SetContextIconSpec(frame.ContextIcon, iconSpec)
        frame.ContextIcon:Show()
    end

    local pulseAlpha = getGlowingGemsGlowSpec(native).base or 0.15
    if frame.GlowTL then frame.GlowTL:SetVertexColor(animatedTint.r or 1, animatedTint.g or 1, animatedTint.b or 1, pulseAlpha) end
    if frame.GlowTR then frame.GlowTR:SetVertexColor(animatedTint.r or 1, animatedTint.g or 1, animatedTint.b or 1, pulseAlpha) end
    if frame.GlowBL then frame.GlowBL:SetVertexColor(animatedTint.r or 1, animatedTint.g or 1, animatedTint.b or 1, pulseAlpha) end
    if frame.GlowBR then frame.GlowBR:SetVertexColor(animatedTint.r or 1, animatedTint.g or 1, animatedTint.b or 1, pulseAlpha) end

    local title = type(info.previewTitle) == "string" and info.previewTitle or (type(info.label) == "string" and info.label or "Waytype Preview")
    local subtext = type(info.previewSubtext) == "string" and info.previewSubtext or ""
    frame.Title:SetShown(title ~= "")
    frame.Subtext:SetShown(subtext ~= "")
    frame.Title:SetText(title)
    frame.Subtext:SetText(subtext)

    if titleTint then
        frame.Title:SetTextColor(titleTint.r or 1, titleTint.g or 1, titleTint.b or 1, titleTint.a or 1)
    else
        restoreDefaultTextColor(frame.Title)
    end
    if subtextTint then
        frame.Subtext:SetTextColor(subtextTint.r or 1, subtextTint.g or 1, subtextTint.b or 1, subtextTint.a or 1)
    else
        restoreDefaultTextColor(frame.Subtext)
    end

    local width = getDefaultPlaqueWidth(native)
    frame.Panel:SetWidth(width)
    if frame.PanelHost then
        frame.PanelHost:SetWidth(width)
    end
    frame:SetWidth(width)
    native.LayoutPinpointText(frame, width)

    plaqueState.active = false
    waytypeState.active = true
    waytypeState.key = iconSpec.key or info.label or "preview"
end

local function buildWaytypeInfoFromState(native, targetState)
    if not native or type(targetState) ~= "table" then
        return nil
    end

    local contentSnapshot = type(targetState.contentSnapshot) == "table" and targetState.contentSnapshot or nil
    local iconSpec = native.ResolveIconSpec and native.ResolveIconSpec(
        targetState.kind,
        targetState.source,
        targetState.title,
        contentSnapshot,
        targetState.mapID,
        targetState.x,
        targetState.y
    ) or nil

    local hintedQuestID = contentSnapshot
        and type(contentSnapshot.iconHintQuestID) == "number"
        and contentSnapshot.iconHintQuestID > 0
        and contentSnapshot.iconHintQuestID
        or nil

    local questDetails = hintedQuestID and native.ResolveQuestTypeDetails and native.ResolveQuestTypeDetails(hintedQuestID) or nil

    return {
        backend = NS.GetWorldOverlayBackend(),
        mode = state.worldOverlayNative and state.worldOverlayNative.derived and state.worldOverlayNative.derived.mode or nil,
        kind = targetState.kind,
        source = targetState.source,
        sourceAddon = contentSnapshot and contentSnapshot.sourceAddon or nil,
        title = targetState.title,
        mapID = targetState.mapID,
        x = targetState.x,
        y = targetState.y,
        iconSpec = iconSpec,
        contentSnapshot = contentSnapshot,
        hintedQuestID = hintedQuestID,
        questDetails = questDetails,
    }
end

local function emitWaytypeInfo(info)
    if type(info) ~= "table" then
        NS.Msg("[WAYTYPE] No active world overlay target. Use /zwp waytype help for preview syntax.")
        return
    end

    local iconSpec = info.iconSpec
    local contentSnapshot = info.contentSnapshot

    NS.Msg(string.format(
        "[WAYTYPE] backend=%s mode=%s kind=%s source=%s sourceAddon=%s title=%s",
        tostring(info.backend or "-"),
        tostring(info.mode or "-"),
        tostring(info.kind or "-"),
        tostring(info.source or "-"),
        tostring(info.sourceAddon or "-"),
        tostring(info.title or "-")
    ))

    NS.Msg(string.format(
        "[WAYTYPE] map=%s x=%s y=%s icon=%s source=%s size=%s tint=%s rgba=%s recolor=%s %s",
        tostring(info.mapID or "-"),
        tostring(info.x or "-"),
        tostring(info.y or "-"),
        tostring(iconSpec and iconSpec.key or "-"),
        formatWaytypeIconSource(iconSpec),
        formatWaytypeIconSize(iconSpec),
        tostring(iconSpec and iconSpec.tintKey or "-"),
        formatWaytypeColor(iconSpec and iconSpec.tint or nil),
        tostring(iconSpec and iconSpec.recolor == true),
        formatWaytypeTexture(iconSpec)
    ))

    if type(contentSnapshot) == "table" then
        NS.Msg(string.format(
            "[WAYTYPE] snapshot sourceAddon=%s hint=%s hintQuestID=%s guideRoute=%s liveTravel=%s semanticKind=%s semanticQuestID=%s mirrorTitle=%s",
            tostring(contentSnapshot.sourceAddon or "-"),
            tostring(contentSnapshot.iconHintKind or "-"),
            tostring(info.hintedQuestID or "-"),
            tostring(contentSnapshot.guideRoutePresentation == true),
            tostring(contentSnapshot.liveTravelType or "-"),
            tostring(contentSnapshot.semanticKind or "-"),
            tostring(contentSnapshot.semanticQuestID or "-"),
            tostring(contentSnapshot.mirrorTitle or "-")
        ))

        if contentSnapshot.routeLegKind or contentSnapshot.routeTravelType then
            NS.Msg(string.format(
                "[WAYTYPE] routeLeg=%s goalMap=%s routeType=%s",
                tostring(contentSnapshot.routeLegKind or "-"),
                tostring(contentSnapshot.routeGoalMapID or "-"),
                tostring(contentSnapshot.routeTravelType or "-")
            ))
        end
    end

    local questDetails = info.questDetails
    if type(questDetails) == "table" then
        NS.Msg(string.format(
            "[WAYTYPE] questID=%s type=%s status=%s typeSource=%s subtype=%s classification=%s questTagID=%s questTag=%s questType=%s active=%s ready=%s repeatable=%s",
            tostring(questDetails.questID or "-"),
            tostring(questDetails.typeKey or "-"),
            tostring(questDetails.statusPrefix or "-"),
            tostring(questDetails.typeSource or "-"),
            tostring(questDetails.subtype or "-"),
            tostring(questDetails.classificationName or questDetails.classification or "-"),
            tostring(questDetails.questTagID or "-"),
            tostring(questDetails.questTagName or "-"),
            tostring(questDetails.questTypeName or questDetails.questType or "-"),
            tostring(questDetails.isActive == true),
            tostring(questDetails.isCompleted == true),
            tostring(questDetails.isRepeatable == true)
        ))
    elseif type(iconSpec) == "table" and (iconSpec.typeKey or iconSpec.statusPrefix) then
        NS.Msg(string.format(
            "[WAYTYPE] questType=%s status=%s source=%s",
            tostring(iconSpec.typeKey or "-"),
            tostring(iconSpec.statusPrefix or "-"),
            formatWaytypeIconSource(iconSpec)
        ))
    end
end

local function getCurrentWaytypeInfo()
    local native = NS.Internal.WorldOverlayNative
    if not native then
        return nil
    end

    local worldOverlay = state.worldOverlay
    if type(worldOverlay) == "table"
        and worldOverlay.uid ~= nil
        and type(worldOverlay.kind) == "string"
        and type(worldOverlay.mapID) == "number"
        and type(worldOverlay.x) == "number"
        and type(worldOverlay.y) == "number"
    then
        return buildWaytypeInfoFromState(native, worldOverlay)
    end

    local nativeState = state.worldOverlayNative
    local nativeTarget = nativeState and nativeState.target or nil
    if type(nativeTarget) == "table" and nativeTarget.active then
        return buildWaytypeInfoFromState(native, nativeTarget)
    end

    return nil
end

local function buildQuestWaytypePreview(native, typeKey, statusPrefix, questID)
    local iconSpec = native and native.BuildQuestIconSpec and native.BuildQuestIconSpec(typeKey, statusPrefix) or nil
    if type(iconSpec) ~= "table" then
        return nil, "Unable to build a quest icon preview for that type."
    end

    local label = formatWaytypeQuestLabel(statusPrefix, typeKey)
    local previewSubtext = string.format(
        "icon=%s  source=%s  size=%s  tint=%s",
        tostring(iconSpec.key or "-"),
        formatWaytypeIconSource(iconSpec),
        formatWaytypeIconSize(iconSpec),
        tostring(iconSpec.tintKey or "-")
    )
    if type(questID) == "number" then
        previewSubtext = string.format("questID=%d  %s", questID, previewSubtext)
    end

    local info = {
        backend = "preview",
        mode = "preview",
        kind = "preview",
        source = "debug",
        title = label,
        iconSpec = iconSpec,
        previewTitle = label,
        previewSubtext = previewSubtext,
        label = label,
    }

    if type(questID) == "number" and native.ResolveQuestTypeDetails then
        info.questDetails = native.ResolveQuestTypeDetails(questID)
    else
        info.questDetails = {
            questID = questID,
            typeKey = typeKey,
            statusPrefix = statusPrefix,
        }
    end

    return info
end

local function buildGenericWaytypePreview(native, key)
    local iconSpec = getGenericWaytypeIconSpec(native, key)
    if type(iconSpec) ~= "table" then
        return nil, "Unable to build that native icon preview."
    end

    local label = makeWaytypeLabel(key)
    return {
        backend = "preview",
        mode = "preview",
        kind = key,
        source = "debug",
        title = label,
        iconSpec = iconSpec,
        previewTitle = label .. " Preview",
        previewSubtext = string.format("icon=%s  tint=%s", tostring(iconSpec.key or "-"), tostring(iconSpec.tintKey or "-")),
        label = label,
    }
end

local function resolveWaytypePreviewInfo(arg)
    local native = NS.Internal.WorldOverlayNative
    if not native then
        return nil, "Native overlay is unavailable."
    end

    local genericIconMap = getWaytypeGenericIconMap(native)
    local questTypeMap = getWaytypeQuestTypeMap(native)
    local words = splitWords(arg)
    if #words == 0 then
        return nil, "Missing waytype preview target."
    end

    local firstWord = normalizeWaytypeToken(words[1])
    if firstWord == "quest" then
        local questID = tonumber(words[2] or "")
        if not questID then
            return nil, "Usage: /zwp waytype quest <questID>"
        end
        local questDetails = native.ResolveQuestTypeDetails and native.ResolveQuestTypeDetails(questID) or nil
        local typeKey = questDetails and questDetails.typeKey or "Default"
        local statusPrefix = questDetails and questDetails.statusPrefix or "Available"
        return buildQuestWaytypePreview(native, typeKey, statusPrefix, questID)
    end

    local normalizedArg = normalizeWaytypeToken(arg)
    local genericKey = genericIconMap[normalizedArg]
    if genericKey then
        return buildGenericWaytypePreview(native, genericKey)
    end

    local typeKey = questTypeMap[normalizedArg]
    if typeKey then
        return buildQuestWaytypePreview(native, typeKey, "Incomplete")
    end

    local firstStatus = WAYTYPE_STATUS_ALIASES[firstWord]
    if firstStatus then
        if #words == 1 then
            return buildQuestWaytypePreview(native, "Default", firstStatus)
        end

        local remainderTypeKey = questTypeMap[normalizeWaytypeToken(table.concat(words, " ", 2))]
        if remainderTypeKey then
            return buildQuestWaytypePreview(native, remainderTypeKey, firstStatus)
        end
    end

    if #words > 1 then
        local lastStatus = WAYTYPE_STATUS_ALIASES[normalizeWaytypeToken(words[#words])]
        if lastStatus then
            local leadingTypeKey = questTypeMap[normalizeWaytypeToken(table.concat(words, " ", 1, #words - 1))]
            if leadingTypeKey then
                return buildQuestWaytypePreview(native, leadingTypeKey, lastStatus)
            end
        end
    end

    return nil, "Unknown waytype preview. Use /zwp waytype help."
end

local function handleWaytype(arg)
    arg = trim(arg)

    if arg == "" then
        emitWaytypeInfo(getCurrentWaytypeInfo())
        return
    end

    local normalized = arg:lower()
    if normalized == "help" then
        showWaytypeUsage()
        return
    end

    if normalized == "off" or normalized == "hide" or normalized == "stop" then
        restoreWaytypePreview()
        return
    end

    local info, err = resolveWaytypePreviewInfo(arg)
    if not info then
        NS.Msg("[WAYTYPE] " .. tostring(err))
        showWaytypeUsage()
        return
    end

    emitWaytypeInfo(info)
    showWaytypePreview(info)
    NS.Msg(string.format(
        "[WAYTYPE] Previewing %s. Use /zwp waytype off to restore the live native overlay.",
        tostring(info.label or info.iconSpec and info.iconSpec.key or "preview")
    ))
end

-- ============================================================
-- Bridge diag monitor
-- ============================================================

local diagState = {
    active = false,
    frame = nil,
    elapsed = 0,
    last = nil,
}

local function diagSnapshot()
    local Z = NS.ZGV()
    local P = Z and Z.Pointer
    local af = P and P.ArrowFrame
    local tom = _G["TomTomCrazyArrow"]
    local b = state.bridge
    local won = NS.State.worldOverlayNative
    local wod = won.derived

    local ic = InCinematic()
    local ics = IsInCinematicScene()
    local uip = UIParent:IsShown()
    local zfv = Z and Z.Frame and Z.Frame:IsVisible() or false
    local afv = af and af:IsShown() or false
    local tmv = tom and tom:IsShown() or false
    local ca = b.cinematicActive and true or false
    local gvs = b.guideVisibilityState or "nil"
    local wob = NS.GetWorldOverlayBackend()
    local wom = wod.mode or "nil"
    local wor = won.root and won.root:IsShown() or false
    local wof = wod.navFrame and wod.navFrame:IsShown() or false
    local wouw = type(C_Map.HasUserWaypoint) == "function" and C_Map.HasUserWaypoint() or false
    local wostu = type(C_SuperTrack.IsSuperTrackingUserWaypoint) == "function" and C_SuperTrack.IsSuperTrackingUserWaypoint() or false

    return string.format(
        "IC:%s ICS:%s UIP:%s ZF:%s AF:%s TT:%s CA:%s GVS:%s WO:%s WM:%s WR:%s WNF:%s UW:%s STU:%s",
        tostring(ic), tostring(ics), tostring(uip),
        tostring(zfv), tostring(afv), tostring(tmv),
        tostring(ca), gvs, tostring(wob), tostring(wom),
        tostring(wor), tostring(wof), tostring(wouw), tostring(wostu)
    )
end

local function diagTick()
    local snap = diagSnapshot()
    if snap ~= diagState.last then
        diagState.last = snap
        NS.Msg("[DIAG] " .. snap)
    end
end

local function formatNodeValue(value)
    local valueType = type(value)
    if value == nil then
        return "-"
    end
    if valueType == "boolean" then
        return value and "true" or "false"
    end
    if valueType == "number" then
        return tostring(value)
    end
    if valueType == "string" then
        if value == "" then
            return '""'
        end
        return value
    end
    if valueType == "function" then
        return "fn"
    end
    if valueType == "table" then
        return "tbl"
    end
    return valueType
end

local function getWaypointTravelNode(waypoint)
    if type(waypoint) ~= "table" then
        return
    end

    if type(waypoint.pathnode) == "table" then
        return waypoint.pathnode, "pathnode"
    end

    local surrogate = waypoint.surrogate_for
    if type(surrogate) == "table" and type(surrogate.pathnode) == "table" then
        return surrogate.pathnode, "surrogate.pathnode"
    end

    local sourceWaypoint = waypoint.pathnode and waypoint.pathnode.waypoint
    if type(sourceWaypoint) == "table" and type(sourceWaypoint.pathnode) == "table" then
        return sourceWaypoint.pathnode, "pathnode.waypoint.pathnode"
    end
end

local function getTravelField(node, key)
    if type(node) ~= "table" then
        return
    end

    if node[key] ~= nil then
        return node[key], "node." .. key
    end

    local link = node.link
    if type(link) == "table" and link[key] ~= nil then
        return link[key], "node.link." .. key
    end
end

local function getWaypointTravelDescriptorForDiag(waypoint, label)
    if type(waypoint) ~= "table" or type(NS.GetWaypointTravelDescriptorFields) ~= "function" then
        return nil
    end

    return NS.GetWaypointTravelDescriptorFields(
        waypoint,
        label,
        waypoint.arrowtitle or waypoint.title
    )
end

local function describeWaypoint(label, waypoint)
    if type(waypoint) ~= "table" then
        return label .. "=nil"
    end

    local mapID = waypoint.map or waypoint.mapid or waypoint.mapID or waypoint.m or "-"
    local x = waypoint.x or waypoint.mapx or waypoint.wx or "-"
    local y = waypoint.y or waypoint.mapy or waypoint.wy or "-"
    local node, nodeSource = getWaypointTravelNode(waypoint)
    local spell, spellSource = getTravelField(node, "spell")
    local item, itemSource = getTravelField(node, "item")
    local toy, toySource = getTravelField(node, "toy")
    local initfunc, initfuncSource = getTravelField(node, "initfunc")
    local arrivaltoy, arrivaltoySource = getTravelField(node, "arrivaltoy")
    local atlas, atlasSource = getTravelField(node, "atlas")
    local linkMode, linkModeSource = getTravelField(node, "mode")
    local template, templateSource = getTravelField(node, "template")
    local nodeType = node and (node.subtype ~= nil and node.subtype or node.type) or nil
    local nodeContext = node and (node.a_b__c_d ~= nil and node.a_b__c_d or node.a_b) or nil
    local nextType = node and type(node.next) == "table"
        and (node.next.subtype ~= nil and node.next.subtype or node.next.type)
        or nil
    local travelType, travelConfidence, travelExplicit, travelSourceKind =
        getWaypointTravelDescriptorForDiag(waypoint, label)

    local special = NS.IsZygorSpecialTravelIconWaypoint(waypoint)

    return string.format(
        "%s{type=%s map=%s x=%s y=%s title=%s arrow=%s special=%s node=%s nodetype=%s template=%s@%s ctx=%s nexttype=%s spell=%s@%s item=%s@%s toy=%s@%s init=%s@%s arrivaltoy=%s@%s atlas=%s@%s mode=%s@%s travel=%s@%s/%s explicit=%s surrogate=%s}",
        label,
        tostring(waypoint.type or "-"),
        tostring(mapID),
        tostring(x),
        tostring(y),
        tostring(waypoint.title or "-"),
        tostring(waypoint.arrowtitle or "-"),
        tostring(special),
        tostring(nodeSource or "-"),
        formatNodeValue(nodeType),
        formatNodeValue(template),
        tostring(templateSource or "-"),
        formatNodeValue(nodeContext),
        formatNodeValue(nextType),
        formatNodeValue(spell),
        tostring(spellSource or "-"),
        formatNodeValue(item),
        tostring(itemSource or "-"),
        formatNodeValue(toy),
        tostring(toySource or "-"),
        formatNodeValue(initfunc),
        tostring(initfuncSource or "-"),
        formatNodeValue(arrivaltoy),
        tostring(arrivaltoySource or "-"),
        formatNodeValue(atlas),
        tostring(atlasSource or "-"),
        formatNodeValue(linkMode),
        tostring(linkModeSource or "-"),
        formatNodeValue(travelType),
        formatNodeValue(travelSourceKind),
        formatNodeValue(travelConfidence),
        tostring(travelExplicit == true),
        tostring(type(waypoint.surrogate_for) == "table")
    )
end

-- ============================================================
-- Travel diag monitor
-- ============================================================

local travelDiagState = {
    active = false,
    frame = nil,
    elapsed = 0,
}

local function travelDiagSnapshot()
    local Z = NS.ZGV()
    local P = Z and Z.Pointer
    local bridge = state.bridge

    if not P then
        return "P=nil"
    end

    local parts = {
        "Suppressed=" .. tostring(bridge and bridge.tomtomArrowVisualSuppressed or false),
        "CurrentSpecial=" .. tostring(NS.IsCurrentZygorSpecialTravelIconActive()),
        describeWaypoint("AF", P.ArrowFrame and P.ArrowFrame.waypoint),
        describeWaypoint("AR", P.arrow and P.arrow.waypoint),
        describeWaypoint("DW", P.DestinationWaypoint),
        describeWaypoint("WP", P.waypoint),
        describeWaypoint("CW", P.current_waypoint),
        describeWaypoint("W1", type(P.waypoints) == "table" and P.waypoints[1] or nil),
    }

    return table.concat(parts, " || ")
end

-- 21 fields: type, map, xi, yi, title, arrowtitle, surrogate, travelMode,
-- spell, item, toy, initfunc, arrivaltoy, atlas, nodeType, template,
-- context, nextType, descriptorType, descriptorConfidence, descriptorSource.
local function writeFP(entry, waypointType, mapID, xi, yi, title, arrowTitle, surrogate,
        travelMode, spell, item, toy, initfunc, arrivalToy, atlas,
        nodeType, template, context, nextType, descriptorType, descriptorConfidence, descriptorSource)
    entry[1] = waypointType
    entry[2] = mapID
    entry[3] = xi
    entry[4] = yi
    entry[5] = title
    entry[6] = arrowTitle
    entry[7] = surrogate
    entry[8] = travelMode
    entry[9] = spell
    entry[10] = item
    entry[11] = toy
    entry[12] = initfunc
    entry[13] = arrivalToy
    entry[14] = atlas
    entry[15] = nodeType
    entry[16] = template
    entry[17] = context
    entry[18] = nextType
    entry[19] = descriptorType
    entry[20] = descriptorConfidence
    entry[21] = descriptorSource
end

local function matchFP(entry, waypointType, mapID, xi, yi, title, arrowTitle, surrogate,
        travelMode, spell, item, toy, initfunc, arrivalToy, atlas,
        nodeType, template, context, nextType, descriptorType, descriptorConfidence, descriptorSource)
    return entry[1] == waypointType
        and entry[2] == mapID
        and entry[3] == xi
        and entry[4] == yi
        and entry[5] == title
        and entry[6] == arrowTitle
        and entry[7] == surrogate
        and entry[8] == travelMode
        and entry[9] == spell
        and entry[10] == item
        and entry[11] == toy
        and entry[12] == initfunc
        and entry[13] == arrivalToy
        and entry[14] == atlas
        and entry[15] == nodeType
        and entry[16] == template
        and entry[17] == context
        and entry[18] == nextType
        and entry[19] == descriptorType
        and entry[20] == descriptorConfidence
        and entry[21] == descriptorSource
end

local function getWaypointFP(waypoint)
    if type(waypoint) ~= "table" then
        return nil, nil, nil, nil, nil, nil, false, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil
    end

    local x = tonumber(waypoint.x or waypoint.mapx or waypoint.wx)
    local y = tonumber(waypoint.y or waypoint.mapy or waypoint.wy)
    local node = getWaypointTravelNode(waypoint)
    local link = node and type(node.link) == "table" and node.link or nil
    local descriptorType, descriptorConfidence, _, descriptorSource =
        getWaypointTravelDescriptorForDiag(waypoint, "fp")

    return
        waypoint.type,
        waypoint.map or waypoint.mapid or waypoint.mapID or waypoint.m,
        x and math.floor(x * 1000 + 0.5) or nil,
        y and math.floor(y * 1000 + 0.5) or nil,
        waypoint.title,
        waypoint.arrowtitle,
        type(waypoint.surrogate_for) == "table",
        node and (node.mode ~= nil and node.mode or (link and link.mode)) or nil,
        node and (node.spell ~= nil and node.spell or (link and link.spell)) or nil,
        node and (node.item ~= nil and node.item or (link and link.item)) or nil,
        node and (node.toy ~= nil and node.toy or (link and link.toy)) or nil,
        node and (node.initfunc ~= nil and node.initfunc or (link and link.initfunc)) or nil,
        node and (node.arrivaltoy ~= nil and node.arrivaltoy or (link and link.arrivaltoy)) or nil,
        node and (node.atlas ~= nil and node.atlas or (link and link.atlas)) or nil,
        node and (node.subtype ~= nil and node.subtype or node.type) or nil,
        node and (node.template ~= nil and node.template or (link and link.template)) or nil,
        node and (node.a_b__c_d ~= nil and node.a_b__c_d or node.a_b) or nil,
        node and type(node.next) == "table" and (node.next.subtype ~= nil and node.next.subtype or node.next.type) or nil,
        descriptorType,
        descriptorConfidence,
        descriptorSource
end

local function commitFingerprint(diagState)
    local Z = NS.ZGV()
    local P = Z and Z.Pointer
    local bridge = state.bridge

    diagState.cfSupp = bridge and bridge.tomtomArrowVisualSuppressed or false
    diagState.cfSpec = NS.IsCurrentZygorSpecialTravelIconActive()
    writeFP(diagState.cfAF, getWaypointFP(P and P.ArrowFrame and P.ArrowFrame.waypoint))
    writeFP(diagState.cfAR, getWaypointFP(P and P.arrow and P.arrow.waypoint))
    writeFP(diagState.cfDW, getWaypointFP(P and P.DestinationWaypoint))
    writeFP(diagState.cfWP, getWaypointFP(P and P.waypoint))
    writeFP(diagState.cfCW, getWaypointFP(P and P.current_waypoint))
    writeFP(diagState.cfW1, getWaypointFP(P and type(P.waypoints) == "table" and P.waypoints[1] or nil))
end

local function travelDiagTick()
    local Z = NS.ZGV()
    local P = Z and Z.Pointer
    local diagState = travelDiagState
    local bridge = state.bridge
    local suppressed = bridge and bridge.tomtomArrowVisualSuppressed or false
    local currentSpecial = NS.IsCurrentZygorSpecialTravelIconActive()

    local afType, afMap, afXi, afYi, afTitle, afArrow, afSurrogate, afMode, afSpell, afItem, afToy, afInit, afArrivalToy, afAtlas, afNodeType, afTemplate, afContext, afNextType, afDescriptorType, afDescriptorConfidence, afDescriptorSource =
        getWaypointFP(P and P.ArrowFrame and P.ArrowFrame.waypoint)
    local arType, arMap, arXi, arYi, arTitle, arArrow, arSurrogate, arMode, arSpell, arItem, arToy, arInit, arArrivalToy, arAtlas, arNodeType, arTemplate, arContext, arNextType, arDescriptorType, arDescriptorConfidence, arDescriptorSource =
        getWaypointFP(P and P.arrow and P.arrow.waypoint)
    local dwType, dwMap, dwXi, dwYi, dwTitle, dwArrow, dwSurrogate, dwMode, dwSpell, dwItem, dwToy, dwInit, dwArrivalToy, dwAtlas, dwNodeType, dwTemplate, dwContext, dwNextType, dwDescriptorType, dwDescriptorConfidence, dwDescriptorSource =
        getWaypointFP(P and P.DestinationWaypoint)
    local wpType, wpMap, wpXi, wpYi, wpTitle, wpArrow, wpSurrogate, wpMode, wpSpell, wpItem, wpToy, wpInit, wpArrivalToy, wpAtlas, wpNodeType, wpTemplate, wpContext, wpNextType, wpDescriptorType, wpDescriptorConfidence, wpDescriptorSource =
        getWaypointFP(P and P.waypoint)
    local cwType, cwMap, cwXi, cwYi, cwTitle, cwArrow, cwSurrogate, cwMode, cwSpell, cwItem, cwToy, cwInit, cwArrivalToy, cwAtlas, cwNodeType, cwTemplate, cwContext, cwNextType, cwDescriptorType, cwDescriptorConfidence, cwDescriptorSource =
        getWaypointFP(P and P.current_waypoint)
    local w1Type, w1Map, w1Xi, w1Yi, w1Title, w1Arrow, w1Surrogate, w1Mode, w1Spell, w1Item, w1Toy, w1Init, w1ArrivalToy, w1Atlas, w1NodeType, w1Template, w1Context, w1NextType, w1DescriptorType, w1DescriptorConfidence, w1DescriptorSource =
        getWaypointFP(P and type(P.waypoints) == "table" and P.waypoints[1] or nil)

    local confirmedMatch = suppressed == diagState.cfSupp
        and currentSpecial == diagState.cfSpec
        and matchFP(diagState.cfAF, afType, afMap, afXi, afYi, afTitle, afArrow, afSurrogate, afMode, afSpell, afItem, afToy, afInit, afArrivalToy, afAtlas, afNodeType, afTemplate, afContext, afNextType, afDescriptorType, afDescriptorConfidence, afDescriptorSource)
        and matchFP(diagState.cfAR, arType, arMap, arXi, arYi, arTitle, arArrow, arSurrogate, arMode, arSpell, arItem, arToy, arInit, arArrivalToy, arAtlas, arNodeType, arTemplate, arContext, arNextType, arDescriptorType, arDescriptorConfidence, arDescriptorSource)
        and matchFP(diagState.cfDW, dwType, dwMap, dwXi, dwYi, dwTitle, dwArrow, dwSurrogate, dwMode, dwSpell, dwItem, dwToy, dwInit, dwArrivalToy, dwAtlas, dwNodeType, dwTemplate, dwContext, dwNextType, dwDescriptorType, dwDescriptorConfidence, dwDescriptorSource)
        and matchFP(diagState.cfWP, wpType, wpMap, wpXi, wpYi, wpTitle, wpArrow, wpSurrogate, wpMode, wpSpell, wpItem, wpToy, wpInit, wpArrivalToy, wpAtlas, wpNodeType, wpTemplate, wpContext, wpNextType, wpDescriptorType, wpDescriptorConfidence, wpDescriptorSource)
        and matchFP(diagState.cfCW, cwType, cwMap, cwXi, cwYi, cwTitle, cwArrow, cwSurrogate, cwMode, cwSpell, cwItem, cwToy, cwInit, cwArrivalToy, cwAtlas, cwNodeType, cwTemplate, cwContext, cwNextType, cwDescriptorType, cwDescriptorConfidence, cwDescriptorSource)
        and matchFP(diagState.cfW1, w1Type, w1Map, w1Xi, w1Yi, w1Title, w1Arrow, w1Surrogate, w1Mode, w1Spell, w1Item, w1Toy, w1Init, w1ArrivalToy, w1Atlas, w1NodeType, w1Template, w1Context, w1NextType, w1DescriptorType, w1DescriptorConfidence, w1DescriptorSource)

    if confirmedMatch then
        diagState.pendingCount = 0
        return
    end

    local pendingMatch = suppressed == diagState.pdSupp
        and currentSpecial == diagState.pdSpec
        and matchFP(diagState.pdAF, afType, afMap, afXi, afYi, afTitle, afArrow, afSurrogate, afMode, afSpell, afItem, afToy, afInit, afArrivalToy, afAtlas, afNodeType, afTemplate, afContext, afNextType, afDescriptorType, afDescriptorConfidence, afDescriptorSource)
        and matchFP(diagState.pdAR, arType, arMap, arXi, arYi, arTitle, arArrow, arSurrogate, arMode, arSpell, arItem, arToy, arInit, arArrivalToy, arAtlas, arNodeType, arTemplate, arContext, arNextType, arDescriptorType, arDescriptorConfidence, arDescriptorSource)
        and matchFP(diagState.pdDW, dwType, dwMap, dwXi, dwYi, dwTitle, dwArrow, dwSurrogate, dwMode, dwSpell, dwItem, dwToy, dwInit, dwArrivalToy, dwAtlas, dwNodeType, dwTemplate, dwContext, dwNextType, dwDescriptorType, dwDescriptorConfidence, dwDescriptorSource)
        and matchFP(diagState.pdWP, wpType, wpMap, wpXi, wpYi, wpTitle, wpArrow, wpSurrogate, wpMode, wpSpell, wpItem, wpToy, wpInit, wpArrivalToy, wpAtlas, wpNodeType, wpTemplate, wpContext, wpNextType, wpDescriptorType, wpDescriptorConfidence, wpDescriptorSource)
        and matchFP(diagState.pdCW, cwType, cwMap, cwXi, cwYi, cwTitle, cwArrow, cwSurrogate, cwMode, cwSpell, cwItem, cwToy, cwInit, cwArrivalToy, cwAtlas, cwNodeType, cwTemplate, cwContext, cwNextType, cwDescriptorType, cwDescriptorConfidence, cwDescriptorSource)
        and matchFP(diagState.pdW1, w1Type, w1Map, w1Xi, w1Yi, w1Title, w1Arrow, w1Surrogate, w1Mode, w1Spell, w1Item, w1Toy, w1Init, w1ArrivalToy, w1Atlas, w1NodeType, w1Template, w1Context, w1NextType, w1DescriptorType, w1DescriptorConfidence, w1DescriptorSource)

    if pendingMatch then
        diagState.pendingCount = (diagState.pendingCount or 0) + 1
        if diagState.pendingCount < 2 then
            return
        end
    else
        diagState.pdSupp = suppressed
        diagState.pdSpec = currentSpecial
        writeFP(diagState.pdAF, afType, afMap, afXi, afYi, afTitle, afArrow, afSurrogate, afMode, afSpell, afItem, afToy, afInit, afArrivalToy, afAtlas, afNodeType, afTemplate, afContext, afNextType, afDescriptorType, afDescriptorConfidence, afDescriptorSource)
        writeFP(diagState.pdAR, arType, arMap, arXi, arYi, arTitle, arArrow, arSurrogate, arMode, arSpell, arItem, arToy, arInit, arArrivalToy, arAtlas, arNodeType, arTemplate, arContext, arNextType, arDescriptorType, arDescriptorConfidence, arDescriptorSource)
        writeFP(diagState.pdDW, dwType, dwMap, dwXi, dwYi, dwTitle, dwArrow, dwSurrogate, dwMode, dwSpell, dwItem, dwToy, dwInit, dwArrivalToy, dwAtlas, dwNodeType, dwTemplate, dwContext, dwNextType, dwDescriptorType, dwDescriptorConfidence, dwDescriptorSource)
        writeFP(diagState.pdWP, wpType, wpMap, wpXi, wpYi, wpTitle, wpArrow, wpSurrogate, wpMode, wpSpell, wpItem, wpToy, wpInit, wpArrivalToy, wpAtlas, wpNodeType, wpTemplate, wpContext, wpNextType, wpDescriptorType, wpDescriptorConfidence, wpDescriptorSource)
        writeFP(diagState.pdCW, cwType, cwMap, cwXi, cwYi, cwTitle, cwArrow, cwSurrogate, cwMode, cwSpell, cwItem, cwToy, cwInit, cwArrivalToy, cwAtlas, cwNodeType, cwTemplate, cwContext, cwNextType, cwDescriptorType, cwDescriptorConfidence, cwDescriptorSource)
        writeFP(diagState.pdW1, w1Type, w1Map, w1Xi, w1Yi, w1Title, w1Arrow, w1Surrogate, w1Mode, w1Spell, w1Item, w1Toy, w1Init, w1ArrivalToy, w1Atlas, w1NodeType, w1Template, w1Context, w1NextType, w1DescriptorType, w1DescriptorConfidence, w1DescriptorSource)
        diagState.pendingCount = 1
        return
    end

    diagState.cfSupp = suppressed
    diagState.cfSpec = currentSpecial
    writeFP(diagState.cfAF, afType, afMap, afXi, afYi, afTitle, afArrow, afSurrogate, afMode, afSpell, afItem, afToy, afInit, afArrivalToy, afAtlas, afNodeType, afTemplate, afContext, afNextType, afDescriptorType, afDescriptorConfidence, afDescriptorSource)
    writeFP(diagState.cfAR, arType, arMap, arXi, arYi, arTitle, arArrow, arSurrogate, arMode, arSpell, arItem, arToy, arInit, arArrivalToy, arAtlas, arNodeType, arTemplate, arContext, arNextType, arDescriptorType, arDescriptorConfidence, arDescriptorSource)
    writeFP(diagState.cfDW, dwType, dwMap, dwXi, dwYi, dwTitle, dwArrow, dwSurrogate, dwMode, dwSpell, dwItem, dwToy, dwInit, dwArrivalToy, dwAtlas, dwNodeType, dwTemplate, dwContext, dwNextType, dwDescriptorType, dwDescriptorConfidence, dwDescriptorSource)
    writeFP(diagState.cfWP, wpType, wpMap, wpXi, wpYi, wpTitle, wpArrow, wpSurrogate, wpMode, wpSpell, wpItem, wpToy, wpInit, wpArrivalToy, wpAtlas, wpNodeType, wpTemplate, wpContext, wpNextType, wpDescriptorType, wpDescriptorConfidence, wpDescriptorSource)
    writeFP(diagState.cfCW, cwType, cwMap, cwXi, cwYi, cwTitle, cwArrow, cwSurrogate, cwMode, cwSpell, cwItem, cwToy, cwInit, cwArrivalToy, cwAtlas, cwNodeType, cwTemplate, cwContext, cwNextType, cwDescriptorType, cwDescriptorConfidence, cwDescriptorSource)
    writeFP(diagState.cfW1, w1Type, w1Map, w1Xi, w1Yi, w1Title, w1Arrow, w1Surrogate, w1Mode, w1Spell, w1Item, w1Toy, w1Init, w1ArrivalToy, w1Atlas, w1NodeType, w1Template, w1Context, w1NextType, w1DescriptorType, w1DescriptorConfidence, w1DescriptorSource)
    diagState.pendingCount = 0

    NS.Msg("[TRAVELDIAG] " .. travelDiagSnapshot())
end

local function handleTravelDiag()
    if travelDiagState.active then
        travelDiagState.active = false
        if travelDiagState.frame then
            travelDiagState.frame:SetScript("OnUpdate", nil)
        end
        NS.Msg("[TRAVELDIAG] Monitor stopped. Final state:")
        NS.Msg("[TRAVELDIAG] " .. travelDiagSnapshot())
        return
    end

    travelDiagState.active = true
    travelDiagState.elapsed = 0
    travelDiagState.pendingCount = 0
    travelDiagState.cfSupp = nil
    travelDiagState.cfSpec = nil
    travelDiagState.pdSupp = nil
    travelDiagState.pdSpec = nil
    travelDiagState.cfAF = travelDiagState.cfAF or {}
    travelDiagState.cfAR = travelDiagState.cfAR or {}
    travelDiagState.cfDW = travelDiagState.cfDW or {}
    travelDiagState.cfWP = travelDiagState.cfWP or {}
    travelDiagState.cfCW = travelDiagState.cfCW or {}
    travelDiagState.cfW1 = travelDiagState.cfW1 or {}
    travelDiagState.pdAF = travelDiagState.pdAF or {}
    travelDiagState.pdAR = travelDiagState.pdAR or {}
    travelDiagState.pdDW = travelDiagState.pdDW or {}
    travelDiagState.pdWP = travelDiagState.pdWP or {}
    travelDiagState.pdCW = travelDiagState.pdCW or {}
    travelDiagState.pdW1 = travelDiagState.pdW1 or {}

    if not travelDiagState.frame then
        travelDiagState.frame = CreateFrame("Frame")
    end

    travelDiagState.frame:SetScript("OnUpdate", function(_, dt)
        travelDiagState.elapsed = travelDiagState.elapsed + dt
        if travelDiagState.elapsed < 0.2 then return end
        travelDiagState.elapsed = 0
        travelDiagTick()
    end)

    NS.Msg("[TRAVELDIAG] Monitor started. Tracking waypoint travel semantics (poll 0.2s).")
    NS.Msg("[TRAVELDIAG] Fields: source waypoint, coords, titles, detected travel node source, node type/template/context/next type, spell/item/toy/init/arrivaltoy/atlas/mode, resolved descriptor, surrogate, suppression state.")
    NS.Msg("[TRAVELDIAG] " .. travelDiagSnapshot())
    commitFingerprint(travelDiagState)
end

local function handleDiag()
    if diagState.active then
        diagState.active = false
        if diagState.frame then
            diagState.frame:SetScript("OnUpdate", nil)
        end
        NS.Msg("[DIAG] Monitor stopped. Final state:")
        NS.Msg("[DIAG] " .. diagSnapshot())
        return
    end

    diagState.active = true
    diagState.last = nil
    diagState.elapsed = 0

    if not diagState.frame then
        diagState.frame = CreateFrame("Frame")
    end

    diagState.frame:SetScript("OnUpdate", function(_, dt)
        diagState.elapsed = diagState.elapsed + dt
        if diagState.elapsed < 0.3 then return end
        diagState.elapsed = 0
        diagTick()
    end)

    NS.Msg("[DIAG] Monitor started. Tracking state changes (poll 0.3s):")
    NS.Msg("[DIAG] IC=InCinematic ICS=IsInCinematicScene UIP=UIParent ZF=ZygorFrame AF=Arrow TT=TomTom CA=cinematicActive GVS=guideVisibilityState WO=worldOverlay WM=nativeMode WR=nativeRoot WNF=nativeNavFrame UW=userWaypoint STU=superTrackedUser")
    diagTick()
end

-- ============================================================
-- Memory report
-- ============================================================

local function handleMem()
    local backend = NS.GetWorldOverlayBackend()
    local won = NS.State.worldOverlayNative
    local wo = NS.State.worldOverlay
    local native = NS.Internal.WorldOverlayNative
    local bridge = NS.State.bridge

    local addonName = NS.ADDON_NAME
    local addonMem = getAddonMemoryKB(addonName)
    local tomtomMem = getAddonMemoryKB("TomTom")
    local zygorMem = getAddonMemoryKB("ZygorGuidesViewer")
    local waypointUIMem = getAddonMemoryKB("WaypointUI")
    local totalMem = getTotalAddonMemoryKB()
    local waypointUIEnabled = type(NS.IsAddonEnabledForCurrentCharacter) == "function"
        and NS.IsAddonEnabledForCurrentCharacter("WaypointUI")
        or false

    local questIconCacheCount = native and countTableEntries(native.questIconCache) or 0
    local fontStringCacheCount = native and countTableEntries(native.fontStringTextCache) or 0

    NS.Msg("[MEM] AddOn memory snapshot")
    NS.Msg(
        "[MEM] TotalAddOns:", formatMemoryKB(totalMem),
        addonName .. ":", formatMemoryKB(addonMem), "(" .. formatPercent(addonMem, totalMem) .. ")"
    )
    NS.Msg(
        "[MEM] TomTom:", formatMemoryKB(tomtomMem), "(" .. formatPercent(tomtomMem, totalMem) .. ")",
        "ZygorGuidesViewer:", formatMemoryKB(zygorMem), "(" .. formatPercent(zygorMem, totalMem) .. ")"
    )
    NS.Msg(
        "[MEM] WaypointUI:", formatMemoryKB(waypointUIMem), "(" .. formatPercent(waypointUIMem, totalMem) .. ")",
        "Loaded=" .. tostring(IsAddonLoaded("WaypointUI")),
        "EnabledForChar=" .. tostring(waypointUIEnabled)
    )

    NS.Msg(
        "[MEM] Backend:", tostring(backend),
        "OverlayBackendState:", tostring(wo and wo.backend or "nil"),
        "NativeTarget:", tostring(won and won.target and won.target.active or false)
    )

    NS.Msg(
        "[MEM] NativeFrames:",
        "driver=" .. tostring(won and won.driver ~= nil or false),
        "root=" .. tostring(won and won.root ~= nil or false),
        "waypoint=" .. tostring(won and won.waypoint ~= nil or false),
        "pinpoint=" .. tostring(won and won.pinpoint ~= nil or false),
        "navigator=" .. tostring(won and won.navigator ~= nil or false),
        "cachedNavFrame=" .. tostring(won and won.cachedNavFrame ~= nil or false)
    )

    NS.Msg(
        "[MEM] NativeCaches:",
        "questIconCache=" .. tostring(questIconCacheCount),
        "fontStringTextCache=" .. tostring(fontStringCacheCount),
        "contentDirty=" .. tostring(won and won.contentDirty or false),
        "navFadeState=" .. tostring(won and won.navFadeState or "nil")
    )

    NS.Msg(
        "[MEM] Diagnostics:",
        "diag=" .. tostring(diagState.active),
        "traveldiag=" .. tostring(travelDiagState.active),
        "bridgeHeartbeat=" .. tostring(bridge and bridge.heartbeatFrame ~= nil or false)
    )
end

-- ============================================================
-- Step debug
-- ============================================================

local function formatBridgeCoords(mapID, x, y)
    if type(mapID) ~= "number" or type(x) ~= "number" or type(y) ~= "number" then
        return "nil"
    end

    return string.format("%s@%.4f,%.4f", tostring(mapID), x, y)
end

local function sanitizeStepDebugLine(value)
    value = tostring(value)
    return (value:gsub("[%c]", function(char)
        if char == "\r" or char == "\n" or char == "\t" then
            return " "
        end
        return string.format("\\x%02X", string.byte(char))
    end))
end

local function handleStepDebug()
    NS.TickUpdate()

    local bridge = state.bridge
    local lastAppliedKind = type(bridge) == "table" and bridge.lastAppliedKind or nil
    if type(lastAppliedKind) == "string" and lastAppliedKind ~= "" and lastAppliedKind ~= "guide" then
        local lastAppliedSource = type(bridge) == "table" and bridge.lastAppliedSource or nil
        local lastTitle = type(bridge) == "table" and bridge.lastTitle or nil
        local lastAppliedMapID = type(bridge) == "table" and bridge.lastAppliedMapID or nil
        local lastAppliedX = type(bridge) == "table" and bridge.lastAppliedX or nil
        local lastAppliedY = type(bridge) == "table" and bridge.lastAppliedY or nil
        local guideRoutePresentation = type(bridge) == "table"
            and bridge.lastAppliedGuideRoutePresentation == true
        NS.Msg("[STEPDEBUG] " .. table.concat({
            "currentTargetKind=" .. tostring(lastAppliedKind),
            "source=" .. tostring(lastAppliedSource),
            "title=" .. tostring(lastTitle),
            "coords=" .. formatBridgeCoords(lastAppliedMapID, lastAppliedX, lastAppliedY),
            guideRoutePresentation and "resolver=guide-route-presentation" or "resolver=bypassed",
            guideRoutePresentation and "reason=guide-owned-route-leg" or "reason=non-guide-target",
        }, " "))
        -- Only warn about a stale snapshot when the resolver was truly bypassed.
        -- When guide route presentation is active the snapshot IS current.
        if not guideRoutePresentation then
            NS.Msg("[STEPDEBUG] Last guide resolver snapshot follows and may be stale for the current target.")
        end
    end

    if type(NS.GetGuideResolverDebugLines) ~= "function" then
        NS.Msg("[STEPDEBUG] Guide resolver is unavailable.")
        return
    end

    local lines = NS.GetGuideResolverDebugLines()
    if type(lines) ~= "table" or #lines == 0 then
        NS.Msg("[STEPDEBUG] No resolver snapshot available.")
        return
    end

    for _, line in ipairs(lines) do
        NS.Msg("[STEPDEBUG] " .. sanitizeStepDebugLine(line))
    end
end

-- ============================================================
-- Resolver cases
-- ============================================================

local function formatResolverCaseValue(value)
    return sanitizeStepDebugLine(tostring(value))
end

local function printResolverCaseResult(result)
    NS.Msg("[RESOLVERCASES] " .. table.concat({
        result.pass and "PASS" or "FAIL",
        tostring(result.id),
        "title=" .. formatResolverCaseValue(result.title),
        "subtext=" .. formatResolverCaseValue(result.subtext),
        "reason=" .. formatResolverCaseValue(result.debugReason),
        "subtextReason=" .. formatResolverCaseValue(result.subtextReason),
        "legacyReason=" .. formatResolverCaseValue(result.legacyDebugReason),
        "legacySubtextReason=" .. formatResolverCaseValue(result.legacySubtextReason),
        "clusterKind=" .. formatResolverCaseValue(result.clusterKind),
        "routeAllowed=" .. formatResolverCaseValue(result.routePresentationAllowed),
    }, " "))
end

local function handleResolverCases(rest)
    local resolver = NS.Internal and NS.Internal.GuideResolver or nil
    if type(resolver) ~= "table"
        or type(resolver.RunAllCases) ~= "function"
        or type(resolver.RunCase) ~= "function"
    then
        NS.Msg("[RESOLVERCASES] Guide resolver case runner is unavailable.")
        return
    end

    local arg = trim(rest)
    if arg == "" then
        arg = "all"
    end

    if arg:lower() == "all" then
        local summary = resolver.RunAllCases()
        local results = type(summary) == "table" and summary.results or nil
        if type(results) ~= "table" then
            NS.Msg("[RESOLVERCASES] No resolver case results were returned.")
            return
        end

        for _, result in ipairs(results) do
            printResolverCaseResult(result)
        end

        NS.Msg("[RESOLVERCASES] " .. table.concat({
            "summary",
            "total=" .. tostring(summary.total),
            "passed=" .. tostring(summary.passed),
            "failed=" .. tostring(summary.failed),
        }, " "))

        if tonumber(summary.failed) and summary.failed > 0 then
            for _, result in ipairs(results) do
                if not result.pass then
                    NS.Msg("[RESOLVERCASES] failure " .. tostring(result.id))
                    if type(result.error) == "string" and result.error ~= "" then
                        NS.Msg("[RESOLVERCASES] error=" .. formatResolverCaseValue(result.error))
                    end
                    for _, mismatch in ipairs(result.mismatches or {}) do
                        NS.Msg("[RESOLVERCASES] mismatch=" .. formatResolverCaseValue(mismatch))
                    end
                end
            end
        end
        return
    end

    local result = resolver.RunCase(arg)
    if type(result) ~= "table" then
        NS.Msg("[RESOLVERCASES] Unknown case id: " .. tostring(arg))
        return
    end

    printResolverCaseResult(result)
    NS.Msg("[RESOLVERCASES] " .. table.concat({
        "detail",
        "category=" .. formatResolverCaseValue(result.category),
        "classification=" .. formatResolverCaseValue(result.classification),
    }, " "))

    if type(result.error) == "string" and result.error ~= "" then
        NS.Msg("[RESOLVERCASES] error=" .. formatResolverCaseValue(result.error))
    end

    if type(result.snapshot) == "table" then
        NS.Msg("[RESOLVERCASES] " .. table.concat({
            "snapshot",
            "contentSig=" .. formatResolverCaseValue(result.snapshot.contentSig),
            "headerGoal=" .. formatResolverCaseValue(result.snapshot.headerGoalNum),
            "matchedLiveGoal=" .. formatResolverCaseValue(result.snapshot.matchedLiveGoalNum),
            "semanticKind=" .. formatResolverCaseValue(result.snapshot.semanticKind),
            "semanticTravelType=" .. formatResolverCaseValue(result.snapshot.semanticTravelType),
            "semanticQuestID=" .. formatResolverCaseValue(result.snapshot.semanticQuestID),
        }, " "))
    end

    for _, mismatch in ipairs(result.mismatches or {}) do
        NS.Msg("[RESOLVERCASES] mismatch=" .. formatResolverCaseValue(mismatch))
    end
end

-- ============================================================
-- Churn sampler
-- ============================================================

local CHURN_COUNTER_KEYS = {
    "tickUpdate",
    "tickFromHook",
    "tickFromHeartbeat",
    "tickFromOther",
    "resolveHit",
    "resolveMiss",
    "buildFacts",
    "invalidateFacts",
    "invalidateDialog",
    "driverUpdate",
    "driverUpdateHidden",
    "driverVisuals",
    "nativeWorldOverlayUpdate",
    "extractWaypoint",
    "extractManual",
    "ensureHost",
    "resolveSettableTarget",
    "trySetHost",
    "setUserWaypointCall",
    "hostNotReady",
    "hostThrottled",
    "refreshWorldOverlay",
    "userWaypointUpdatedEvent",
    "samples",
}

local churnSampleFrame = nil

local function resetChurnCounters(churn)
    for _, key in ipairs(CHURN_COUNTER_KEYS) do
        churn[key] = 0
    end
end

local function formatRate(count, seconds)
    if type(count) ~= "number" or type(seconds) ~= "number" or seconds <= 0 then
        return "0/s"
    end
    return string.format("%d (%.1f/s)", count, count / seconds)
end

local function handleChurn(rest)
    local churn = state.churn
    if type(churn) ~= "table" then
        NS.Msg("[CHURN] State unavailable.")
        return
    end

    if churn.active then
        churn.active = false
        if churnSampleFrame then
            churnSampleFrame:SetScript("OnUpdate", nil)
        end
        NS.Msg("[CHURN] Sampling cancelled.")
        return
    end

    local duration = tonumber(rest)
    if not duration or duration <= 0 then
        duration = 5
    end
    if duration > 60 then
        duration = 60
    end

    local addonName = NS.ADDON_NAME
    local startMem = getAddonMemoryKB(addonName) or 0

    resetChurnCounters(churn)
    churn.startedAt = GetTime()
    churn.duration = duration
    churn.startMem = startMem
    churn.peakMemKB = startMem
    churn.active = true

    if not churnSampleFrame then
        churnSampleFrame = CreateFrame("Frame")
    end

    local sampleElapsed = 0
    local SAMPLE_INTERVAL = 0.25
    churnSampleFrame:SetScript("OnUpdate", function(_, dt)
        if not churn.active then
            return
        end
        sampleElapsed = sampleElapsed + dt
        if sampleElapsed < SAMPLE_INTERVAL then
            return
        end
        sampleElapsed = 0
        local mem = getAddonMemoryKB(addonName) or 0
        if mem > (churn.peakMemKB or 0) then
            churn.peakMemKB = mem
        end
        churn.samples = (churn.samples or 0) + 1
    end)

    NS.Msg(string.format("[CHURN] Sampling for %ds. Stand still, don't touch anything.", duration))

    NS.After(duration, function()
        if not churn.active then
            return
        end
        churn.active = false
        if churnSampleFrame then
            churnSampleFrame:SetScript("OnUpdate", nil)
        end

        local grossMem = getAddonMemoryKB(addonName) or 0
        if grossMem > (churn.peakMemKB or 0) then
            churn.peakMemKB = grossMem
        end
        collectgarbage("collect")
        local endMem = getAddonMemoryKB(addonName) or 0

        local actualSeconds = math.max(0.01, GetTime() - churn.startedAt)
        local churnKB = math.max(0, (churn.peakMemKB or grossMem) - (churn.startMem or 0))
        local churnRate = churnKB / actualSeconds
        local liveDelta = (endMem or 0) - (churn.startMem or 0)

        NS.Msg(string.format("[CHURN] Results over %.1fs (%d samples):",
            actualSeconds, churn.samples or 0))
        NS.Msg(string.format("[CHURN] Mem: start=%s peak=%s end(pre-GC)=%s end(post-GC)=%s",
            formatMemoryKB(churn.startMem),
            formatMemoryKB(churn.peakMemKB),
            formatMemoryKB(grossMem),
            formatMemoryKB(endMem)))
        NS.Msg(string.format("[CHURN] Churn=%.1f KB  rate=%.1f KB/s  live leak=%.1f KB",
            churnKB, churnRate, liveDelta))
        NS.Msg(string.format("[CHURN] TickUpdate total=%s  hook=%s  heartbeat=%s",
            formatRate(churn.tickUpdate, actualSeconds),
            formatRate(churn.tickFromHook, actualSeconds),
            formatRate(churn.tickFromHeartbeat, actualSeconds)))
        NS.Msg(string.format("[CHURN] Resolver hit=%s  miss=%s  buildFacts=%s  invFacts=%s  invDialog=%s",
            formatRate(churn.resolveHit, actualSeconds),
            formatRate(churn.resolveMiss, actualSeconds),
            formatRate(churn.buildFacts, actualSeconds),
            formatRate(churn.invalidateFacts, actualSeconds),
            formatRate(churn.invalidateDialog, actualSeconds)))
        NS.Msg(string.format("[CHURN] Extract waypoint=%s  manual=%s",
            formatRate(churn.extractWaypoint, actualSeconds),
            formatRate(churn.extractManual, actualSeconds)))
        NS.Msg(string.format("[CHURN] Driver total=%s  hidden=%s  visuals=%s  worldOverlayUpdate=%s",
            formatRate(churn.driverUpdate, actualSeconds),
            formatRate(churn.driverUpdateHidden, actualSeconds),
            formatRate(churn.driverVisuals, actualSeconds),
            formatRate(churn.nativeWorldOverlayUpdate, actualSeconds)))
        NS.Msg(string.format("[CHURN] Host ensure=%s  notReady=%s  throttled=%s  resolveSettable=%s",
            formatRate(churn.ensureHost, actualSeconds),
            formatRate(churn.hostNotReady, actualSeconds),
            formatRate(churn.hostThrottled, actualSeconds),
            formatRate(churn.resolveSettableTarget, actualSeconds)))
        NS.Msg(string.format("[CHURN] Host trySet=%s  setUserWaypoint=%s  USER_WAYPOINT_UPDATED=%s  refreshWorldOverlay=%s",
            formatRate(churn.trySetHost, actualSeconds),
            formatRate(churn.setUserWaypointCall, actualSeconds),
            formatRate(churn.userWaypointUpdatedEvent, actualSeconds),
            formatRate(churn.refreshWorldOverlay, actualSeconds)))
    end)
end

M.handleDiag = handleDiag
M.handleMem = handleMem
M.handlePlaque = handlePlaque
M.handleWaytype = handleWaytype
M.handleTravelDiag = handleTravelDiag
M.handleStepDebug = handleStepDebug
M.handleResolverCases = handleResolverCases
M.handleChurn = handleChurn
