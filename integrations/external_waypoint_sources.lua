local NS = _G.AzerothWaypointNS

NS.Internal = NS.Internal or {}

local registry = NS.Internal.ExternalWaypointSources or {
    byKey = {},
    order = {},
}
NS.Internal.ExternalWaypointSources = registry

local function TrimString(value)
    if type(value) ~= "string" then
        return nil
    end
    value = value:gsub("^%s+", ""):gsub("%s+$", "")
    if value == "" then
        return nil
    end
    return value
end

local function NormalizeNeedle(value)
    value = TrimString(value)
    if not value then
        return nil
    end
    return value:gsub("/", "\\"):lower()
end

local function NormalizeKey(value)
    value = NormalizeNeedle(value)
    if not value or value:find("\\", 1, true) then
        return nil
    end
    return value
end

local function CopyStringList(list)
    local out = {}
    if type(list) ~= "table" then
        return out
    end
    for index = 1, #list do
        local value = NormalizeNeedle(list[index])
        if value then
            out[#out + 1] = value
        end
    end
    return out
end

function NS.RegisterExternalWaypointSource(key, spec)
    key = NormalizeKey(key)
    if not key or type(spec) ~= "table" then
        return false
    end

    if registry.byKey[key] == nil then
        registry.order[#registry.order + 1] = key
    end

    registry.byKey[key] = {
        key = key,
        displayName = TrimString(spec.displayName) or key,
        transient = spec.transient == true,
        iconKey = TrimString(spec.iconKey) or key,
        stackMatches = CopyStringList(spec.stackMatches),
        aliases = CopyStringList(spec.aliases),
    }
    return true
end

function NS.NormalizeExternalWaypointSource(value)
    local normalized = NormalizeNeedle(value)
    if not normalized then
        return nil
    end

    for index = 1, #registry.order do
        local key = registry.order[index]
        local source = registry.byKey[key]
        if source then
            if normalized == key or normalized == NormalizeNeedle(source.displayName) then
                return key
            end

            local aliases = source.aliases
            for aliasIndex = 1, #aliases do
                if normalized == aliases[aliasIndex] then
                    return key
                end
            end

            local stackMatches = source.stackMatches
            for matchIndex = 1, #stackMatches do
                if normalized:find(stackMatches[matchIndex], 1, true) then
                    return key
                end
            end
        end
    end
end

function NS.GetExternalWaypointSourceInfo(sourceAddon)
    local key = NS.NormalizeExternalWaypointSource(sourceAddon)
    return key and registry.byKey[key] or nil
end

function NS.IsTransientExternalWaypointSource(sourceAddon)
    local source = NS.GetExternalWaypointSourceInfo(sourceAddon)
    return type(source) == "table" and source.transient == true or false
end

