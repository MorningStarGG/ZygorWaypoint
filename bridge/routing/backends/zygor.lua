local NS = _G.AzerothWaypointNS

-- ============================================================
-- Zygor backend - LibRover planner adapter
-- ============================================================

local backend = {}
NS.RoutingBackend_Zygor = backend

backend.id = "zygor"

local PLAN_SERIAL = 0
local MOVEMENT_ADVANCE_YARDS = 55
local ROUTE_COORD_TOLERANCE = 0.00005
local OWN_LIBROVER_REPORT_SUPPRESS_SECONDS = 1.0
local PLAN_TIMEOUT_SECONDS = 3.0
local PLAN_RETRY_DELAY_SECONDS = 0.75
local PLAN_MAX_RETRIES = 2

local function TrimString(value)
    if type(value) ~= "string" then return nil end
    value = value:gsub("^%s+", ""):gsub("%s+$", "")
    if value == "" then return nil end
    return value
end

local function NormalizeToken(value)
    if type(value) ~= "string" then return nil end
    value = value:lower():gsub("^%s+", ""):gsub("%s+$", "")
    if value == "" then return nil end
    return value
end

local function GetZygor()
    return type(NS.ZGV) == "function" and NS.ZGV() or rawget(_G, "ZygorGuidesViewer") or rawget(_G, "ZGV")
end

local function GetLibRover()
    local Z = GetZygor()
    if type(Z) == "table" and type(Z.LibRover) == "table" then
        return Z.LibRover
    end
    if type(LibStub) == "function" then
        local ok, rover = pcall(LibStub, "LibRover-1.0")
        if ok and type(rover) == "table" then
            return rover
        end
    end
    return nil
end

local function GetTravelField(node, key)
    if type(node) ~= "table" then return nil end
    local value = node[key]
    if value == nil and type(node.link) == "table" then
        value = node.link[key]
    end
    return value
end

local function ResolveSpellName(spellID)
    if type(spellID) ~= "number" then return nil end
    if type(C_Spell) == "table" and type(C_Spell.GetSpellName) == "function" then
        return C_Spell.GetSpellName(spellID)
    end
    return nil
end

local function ResolveNodeCoords(node)
    if type(node) ~= "table" then
        return nil, nil, nil
    end
    local mapID = type(node.m) == "number" and node.m or type(node.mapID) == "number" and node.mapID or nil
    local x = type(node.x) == "number" and node.x or nil
    local y = type(node.y) == "number" and node.y or nil
    if type(mapID) ~= "number" or type(x) ~= "number" or type(y) ~= "number" then
        return nil, nil, nil
    end
    if x > 1 then x = x / 100 end
    if y > 1 then y = y / 100 end
    return mapID, x, y
end

local function IsSameRouteCoord(aMapID, aX, aY, bMapID, bX, bY)
    return type(aMapID) == "number"
        and type(aX) == "number"
        and type(aY) == "number"
        and type(bMapID) == "number"
        and type(bX) == "number"
        and type(bY) == "number"
        and aMapID == bMapID
        and math.abs(aX - bX) <= ROUTE_COORD_TOLERANCE
        and math.abs(aY - bY) <= ROUTE_COORD_TOLERANCE
end

local function ResolveRecordDestination(record)
    local target = type(record) == "table" and record.target or nil
    return target and target.mapID or record and record.mapID,
        target and target.x or record and record.x,
        target and target.y or record and record.y,
        target and target.title or record and record.title
end

local function ResolveNodeTitle(node, fallbackTitle)
    if type(node) == "table" and type(node.GetTextAsItinerary) == "function" then
        local ok, text = pcall(node.GetTextAsItinerary, node)
        if ok and TrimString(text) then
            return TrimString(text)
        end
    end
    return TrimString(type(node) == "table" and (node.maplabel or node.text or node.title or node.name) or nil)
        or TrimString(fallbackTitle)
        or "AWP Route"
end

local function BuildArrivalGate(node)
    if type(node) ~= "table" then
        return nil
    end

    local gate = {
        zone = TrimString(node.zone),
        realzone = TrimString(node.realzone),
        subzone = TrimString(node.subzone),
        minizone = TrimString(node.minizone),
        indoors = (node.indoors == true or node.indoors == 1) or nil,
    }
    if gate.zone or gate.realzone or gate.subzone or gate.minizone or gate.indoors then
        return gate
    end
    return nil
end

function NS.BuildSpecialActionFromZygorNode(node)
    if type(node) ~= "table" then return nil end

    local spell = GetTravelField(node, "spell")
    local item = GetTravelField(node, "item")
    local toy = GetTravelField(node, "toy")
    local arrivalToy = GetTravelField(node, "arrivaltoy")
    local initfunc = GetTravelField(node, "initfunc")
    local mode = NormalizeToken(GetTravelField(node, "mode"))
    local atlas = GetTravelField(node, "atlas")
    local actionTitle = TrimString(GetTravelField(node, "name")
        or GetTravelField(node, "label")
        or GetTravelField(node, "title")
        or node.maplabel)
        or ResolveNodeTitle(node)
    local destinationName = TrimString(GetTravelField(node, "destination") or GetTravelField(node, "destname") or node.maplabel)
    if type(destinationName) == "string" and destinationName:sub(1, 1) == "@" then
        destinationName = nil
    end

    local semanticKind, secureType, securePayload = nil, nil, nil
    if toy ~= nil or arrivalToy ~= nil then
        local toyPayload = type(toy) == "number" and toy
            or type(arrivalToy) == "number" and arrivalToy
            or item
        if toyPayload == nil or toyPayload == "" then
            return nil
        end
        semanticKind = mode == "hearth" and "hearth" or "toy"
        secureType, securePayload = "toy", toyPayload
    elseif item ~= nil or mode == "hearth" then
        semanticKind = mode == "hearth" and "hearth" or "item"
        secureType, securePayload = "item", item or 6948
    elseif spell ~= nil then
        semanticKind = type(mode) == "string" and mode:find("portal", 1, true) and "portal" or "spell"
        secureType = "spell"
        securePayload = type(spell) == "number" and (ResolveSpellName(spell) or tostring(spell)) or spell
    elseif type(initfunc) == "function" then
        semanticKind = "travel"
        secureType, securePayload = "function", initfunc
    end

    if not secureType or securePayload == nil or securePayload == "" then
        return nil
    end

    return {
        semanticKind = semanticKind,
        secureType = secureType,
        securePayload = securePayload,
        name = actionTitle,
        title = actionTitle,
        destinationName = destinationName,
        iconTexture = atlas,
        activationMode = "portable",
        activationCoords = nil,
        activationRadiusYards = 15,
        sourceBackend = "zygor",
    }
end

local function ClassifyNodeKind(node, specialAction, isDestination)
    if isDestination then
        return "destination"
    end
    if type(specialAction) == "table" and type(specialAction.semanticKind) == "string" then
        if specialAction.semanticKind == "hearth" then
            return "hearthstone"
        end
        return specialAction.semanticKind
    end

    local mode = NormalizeToken(GetTravelField(node, "mode"))
    local nodeType = NormalizeToken(type(node) == "table" and (node.type or node.subtype or node.linktype) or nil)
    if nodeType == "portal" or nodeType == "taxi" or nodeType == "ship" or nodeType == "zeppelin" then
        return nodeType
    end
    if mode == "hearth" then
        return "hearthstone"
    end
    if type(mode) == "string" and mode:find("portal", 1, true) then
        return "portal"
    end
    if type(mode) == "string" and (mode:find("taxi", 1, true) or mode:find("flightpath", 1, true)) then
        return "taxi"
    end
    if type(mode) == "string" and mode:find("fly", 1, true) then
        return "fly"
    end
    if nodeType == "border" or nodeType == "misc" then
        return "carrier"
    end
    return "walk"
end

local function RouteTravelTypeForKind(kind)
    if kind == "destination" then
        return nil
    end
    if kind == "hearthstone" then
        return "hearth"
    end
    if kind == "walk"
        or kind == "fly"
        or kind == "carrier"
        or kind == "ship"
        or kind == "zeppelin"
    then
        return "travel"
    end
    return kind
end

local function ResolveRouteTravelType(record, mapID, x, y, legKind, fallbackKind)
    local target = type(record) == "table" and record.target or nil
    local destinationMapID = target and target.mapID or record and record.mapID
    if type(NS.ResolveInstanceDestinationTravelType) == "function" then
        local travelType = NS.ResolveInstanceDestinationTravelType(destinationMapID, mapID, x, y, legKind)
        if type(travelType) == "string" then
            return travelType
        end
    end
    return RouteTravelTypeForKind(fallbackKind)
end

local function ResolveArrivalRadius(node, kind, specialAction)
    if type(node) == "table" and node.noskip == true then
        return 5
    end
    if type(node) == "table" and type(node.radius) == "number" then
        return node.radius
    end
    if kind == "walk" or kind == "fly" or (kind == "carrier" and type(specialAction) ~= "table") then
        return MOVEMENT_ADVANCE_YARDS
    end
    return 5
end

local function MakeCoords(mapID, x, y)
    if type(mapID) ~= "number" or type(x) ~= "number" or type(y) ~= "number" then
        return nil
    end
    return { mapID = mapID, x = x, y = y }
end

local function GetInitialSourceCoords()
    if type(NS.GetPlayerMapPosition) ~= "function" then
        return nil, nil, nil
    end
    return NS.GetPlayerMapPosition()
end

local function ShouldUseSourceCoordsForSpecialAction(routeLegKind, kind, specialAction, sourceMapID, sourceX, sourceY)
    if routeLegKind ~= "carrier" or type(specialAction) ~= "table" then
        return false
    end
    if type(sourceMapID) ~= "number" or type(sourceX) ~= "number" or type(sourceY) ~= "number" then
        return false
    end
    return kind ~= "walk" and kind ~= "fly"
end

local function MakeDestinationLeg(record, source)
    local mapID, x, y, title = ResolveRecordDestination(record)
    if type(mapID) ~= "number" or type(x) ~= "number" or type(y) ~= "number" then
        return nil
    end
    return {
        mapID = mapID,
        x = x,
        y = y,
        title = title,
        kind = "destination",
        routeLegKind = "destination",
        routeTravelType = ResolveRouteTravelType(record, mapID, x, y, "destination", "destination"),
        source = source or "zygor",
    }
end

local function TranslatePathToLegs(path, record, fallbackTitle)
    local legs = {}
    local destinationMapID, destinationX, destinationY = ResolveRecordDestination(record)
    local hasDestinationLeg = false
    local sourceMapID, sourceX, sourceY = GetInitialSourceCoords()
    local sourceIsPlayer = type(sourceMapID) == "number"
    if type(path) == "table" then
        for index = 1, #path do
            local node = path[index]
            if type(node) == "table" then
                local mapID, x, y = ResolveNodeCoords(node)
                if mapID and node.player == true then
                    sourceMapID, sourceX, sourceY = mapID, x, y
                    sourceIsPlayer = true
                elseif mapID then
                    local isDestination = node.type == "end"
                        or IsSameRouteCoord(mapID, x, y, destinationMapID, destinationX, destinationY)
                    local specialAction = NS.BuildSpecialActionFromZygorNode(node)
                    local kind = ClassifyNodeKind(node, specialAction, isDestination)
                    local routeLegKind = isDestination and "destination" or "carrier"
                    local legMapID, legX, legY = mapID, x, y
                    if ShouldUseSourceCoordsForSpecialAction(routeLegKind, kind, specialAction, sourceMapID, sourceX, sourceY) then
                        legMapID, legX, legY = sourceMapID, sourceX, sourceY
                        if sourceIsPlayer then
                            specialAction.activationMode = "portable"
                            specialAction.activationCoords = nil
                        else
                            specialAction.activationMode = "location"
                            specialAction.activationCoords = MakeCoords(sourceMapID, sourceX, sourceY)
                        end
                    end
                    hasDestinationLeg = hasDestinationLeg or isDestination
                    legs[#legs + 1] = {
                        mapID = legMapID,
                        x = legX,
                        y = legY,
                        title = ResolveNodeTitle(node, fallbackTitle),
                        kind = kind,
                        routeLegKind = routeLegKind,
                        source = "zygor",
                        routeTravelType = ResolveRouteTravelType(record, legMapID, legX, legY, routeLegKind, kind),
                        arrivalRadius = ResolveArrivalRadius(node, kind, specialAction),
                        activationCoords = type(specialAction) == "table" and specialAction.activationCoords or nil,
                        arrivalGate = BuildArrivalGate(node),
                        specialAction = specialAction,
                    }
                    sourceMapID, sourceX, sourceY = mapID, x, y
                    sourceIsPlayer = false
                end
            end
        end
    end
    if #legs > 0 and not hasDestinationLeg then
        local destination = MakeDestinationLeg(record, "zygor")
        if destination then
            legs[#legs + 1] = destination
        end
    end
    if #legs == 0 then
        local fallback = MakeDestinationLeg(record, "zygor")
        if fallback then
            legs[1] = fallback
        end
    end
    return legs
end

local function AcceptPlan(record, legs, reason, serial)
    if type(NS.AcceptBackendPlan) == "function" then
        return NS.AcceptBackendPlan(record, "zygor", legs, reason, serial)
    end
    record.backend = "zygor"
    record.legs = legs
    record.currentLegIndex = nil
    record.currentLeg = nil
    record.specialAction = nil
    record.replanReason = reason
    return true
end

local function SetFallbackRoute(record, reason, serial)
    local leg = MakeDestinationLeg(record, "zygor")
    if not leg then
        return
    end
    AcceptPlan(record, { leg }, reason or "zygor_fallback", serial)
end

local function SuppressOwnLibRoverReport(record)
    if type(record) ~= "table" then
        return
    end
    local now = type(GetTime) == "function" and GetTime() or 0
    record._zygorSuppressLibRoverReportedUntil = now + OWN_LIBROVER_REPORT_SUPPRESS_SECONDS
end

local function FormatPlanCoord(value)
    return type(value) == "number" and string.format("%.5f", value) or "-"
end

local function BuildPendingTargetSignature(mapID, x, y, title, meta)
    local direct = type(meta) == "table" and meta.direct == true or false
    return table.concat({
        tostring(mapID or "-"),
        FormatPlanCoord(x),
        FormatPlanCoord(y),
        tostring(title or "-"),
        tostring(direct),
    }, "|")
end

local function HasAcceptedPlan(record)
    return type(record) == "table"
        and type(record.legs) == "table"
        and #record.legs > 0
end

local function CopyPlanMeta(meta)
    local copy = {}
    if type(meta) == "table" then
        for key, value in pairs(meta) do
            copy[key] = value
        end
    end
    return copy
end

local function IsResetPlan(meta)
    return type(meta) == "table" and meta.routeInvalidated == true
end

local function GetRetryCount(meta)
    if type(meta) ~= "table" then
        return 0
    end
    return tonumber(meta._zygorRetryCount) or 0
end

local function ClearPendingPlan(record)
    if type(record) ~= "table" then
        return
    end
    record._corePlanning = nil
    record._coreRoutePending = nil
    record._zygorPendingTargetSignature = nil
end

function backend.IsAvailable()
    return type(NS.IsZygorLoaded) == "function"
        and NS.IsZygorLoaded() == true
        and type(GetLibRover()) == "table"
end

function backend.PlanRoute(record, mapID, x, y, title, meta)
    if type(record) ~= "table" or type(mapID) ~= "number" or type(x) ~= "number" or type(y) ~= "number" then
        return
    end

    local pendingTargetSignature = BuildPendingTargetSignature(mapID, x, y, title, meta)
    local resetRequested = IsResetPlan(meta)
    if record._coreRoutePending == true
        and record._zygorPendingTargetSignature == pendingTargetSignature
        and not resetRequested
    then
        return
    end

    PLAN_SERIAL = PLAN_SERIAL + 1
    local serial = PLAN_SERIAL
    local hadAcceptedPlan = HasAcceptedPlan(record)
    record._zygorPlanSerial = serial
    record._zygorTimedOutSerial = nil
    record._zygorPendingTargetSignature = pendingTargetSignature
    record.backend = "zygor"
    record._corePlanning = true
    record._coreRoutePending = true
    record.replanReason = "zygor_planning"

    if not hadAcceptedPlan then
        SetFallbackRoute(record, "zygor_planning_fallback", serial)
        record._corePlanning = true
        record._coreRoutePending = true
    end

    local rover = GetLibRover()
    if type(rover) ~= "table" or type(rover.QueueFindPath) ~= "function" then
        ClearPendingPlan(record)
        if not hadAcceptedPlan or resetRequested then
            SetFallbackRoute(record, "zygor_no_librover", serial)
        end
        return
    end

    local function scheduleRetry(failureReason)
        if type(record) ~= "table" or record._zygorPlanSerial ~= serial then
            return false
        end
        if not resetRequested then
            return false
        end

        local retryCount = GetRetryCount(meta)
        if retryCount >= PLAN_MAX_RETRIES then
            return false
        end

        local retryMeta = CopyPlanMeta(meta)
        retryMeta._zygorRetryCount = retryCount + 1
        retryMeta._zygorRetryReason = failureReason
        record._zygorPlanRetryCount = retryMeta._zygorRetryCount
        record._zygorLastPlanRetryReason = failureReason
        record._zygorLastPlanRetryAt = type(GetTime) == "function" and GetTime() or nil

        NS.After(PLAN_RETRY_DELAY_SECONDS, function()
            if type(record) ~= "table" or record._zygorPlanSerial ~= serial then
                return
            end
            backend.PlanRoute(record, mapID, x, y, title, retryMeta)
        end)
        return true
    end

    local function finishWithoutPlan(reason)
        ClearPendingPlan(record)
        local retrying = scheduleRetry(reason)
        if not hadAcceptedPlan or resetRequested then
            local fallbackReason = reason
            if retrying then
                fallbackReason = tostring(reason or "zygor_plan_retry") .. "_fallback"
            elseif reason == "zygor_plan_timeout" then
                fallbackReason = "zygor_plan_timeout_fallback"
            end
            record._coreRouteOutcomeHint = retrying and "planning" or nil
            SetFallbackRoute(record, fallbackReason, serial)
            record._coreRouteOutcomeHint = nil
        end
        if type(NS.RecomputeCarrier) == "function" then
            NS.RecomputeCarrier()
        end
    end

    NS.After(PLAN_TIMEOUT_SECONDS, function()
        if type(record) ~= "table"
            or record._zygorPlanSerial ~= serial
            or record._coreRoutePending ~= true
        then
            return
        end

        record._zygorTimedOutSerial = serial
        record._zygorLastPlanTimeoutAt = type(GetTime) == "function" and GetTime() or nil
        record._zygorLastPlanTimeoutReason = meta and meta.replanReason or record._coreLastRefreshReason
        finishWithoutPlan("zygor_plan_timeout")
    end)

    local function handler(status, path)
        if type(record) ~= "table"
            or record._zygorPlanSerial ~= serial
            or record._zygorTimedOutSerial == serial
        then
            return
        end
        if status == "progress" then
            return
        end
        ClearPendingPlan(record)
        SuppressOwnLibRoverReport(record)
        if status == "success" and type(path) == "table" then
            record._zygorPlanRetryCount = nil
            record._zygorLastPlanRetryReason = nil
            record._zygorLastPlanRetryAt = nil
            record._zygorLastPlanTimeoutAt = nil
            record._zygorLastPlanTimeoutReason = nil
            local legs = TranslatePathToLegs(path, record, title)
            AcceptPlan(record, legs, "zygor_librover_success", serial)
        elseif status == "arrival" then
            finishWithoutPlan("zygor_librover_arrival")
            return
        else
            local failureReason = "zygor_librover_" .. tostring(status or "failure")
            finishWithoutPlan(failureReason)
            return
        end
        if type(NS.RecomputeCarrier) == "function" then
            NS.RecomputeCarrier()
        end
    end

    local direct = type(meta) == "table" and meta.direct == true or false
    local ok = pcall(rover.QueueFindPath, rover, 0, 0, 0, mapID, x, y, handler, {
        title = title,
        direct = direct,
        awpSerial = serial,
    }, true, true)
    if not ok then
        finishWithoutPlan("zygor_queue_failed")
    end
end

function backend.PollCurrentLeg(record)
    if type(NS.PollNeutralRouteLeg) == "function" then
        return NS.PollNeutralRouteLeg(record, "zygor_poll")
    end
    return false
end


function backend.Clear(record)
    if type(record) ~= "table" then
        return
    end
    record._zygorPlanSerial = nil
    record._zygorPendingTargetSignature = nil
    record._zygorTimedOutSerial = nil
    record._zygorSuppressLibRoverReportedUntil = nil
    record._zygorPlanRetryCount = nil
    record._zygorLastPlanRetryReason = nil
    record._zygorLastPlanRetryAt = nil
    record._zygorLastPlanTimeoutAt = nil
    record._zygorLastPlanTimeoutReason = nil
    record._corePlanning = nil
    record._coreRoutePending = nil
    record.planFingerprint = nil
    record.lastPlanSkippedAt = nil
    record.lastPlanSkipReason = nil
    record.lastPlanSkipStatus = nil
    record.lastPlanSkippedFingerprint = nil
    record.routeOutcome = nil
    record.routeOutcomeReason = nil
    record.routeOutcomeAt = nil
    record.legs = nil
    record.currentLegIndex = nil
    record.currentLeg = nil
    record.specialAction = nil
    record.replanReason = nil
end
