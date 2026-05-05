local NS = _G.AzerothWaypointNS

NS.ChangelogFormat = NS.ChangelogFormat or {}

local M = NS.ChangelogFormat

local COLOR_BOLD = "|cffffff99"
local COLOR_CODE = "|cff9bd5ff"
local COLOR_LINK = "|cff7fbfff"
local COLOR_LINK_URL = "|cffb8c7d9"
local COLOR_RESET = "|r"

local function EscapeText(text)
    return tostring(text or ""):gsub("|", "||")
end

local function AppendEscaped(out, text)
    out[#out + 1] = EscapeText(text)
end

function M.GetEntryParts(entry)
    if type(entry) == "table" then
        local level = tonumber(entry.level) or 1
        if level < 1 then level = 1 end
        return tostring(entry.text or ""), level
    end
    return tostring(entry or ""), 1
end

function M.Inline(text)
    text = tostring(text or "")

    local out = {}
    local i = 1
    local len = #text

    while i <= len do
        local two = text:sub(i, i + 1)
        local char = text:sub(i, i)

        if char == "`" then
            local closeAt = text:find("`", i + 1, true)
            if closeAt then
                out[#out + 1] = COLOR_CODE
                AppendEscaped(out, text:sub(i + 1, closeAt - 1))
                out[#out + 1] = COLOR_RESET
                i = closeAt + 1
            else
                AppendEscaped(out, char)
                i = i + 1
            end
        elseif two == "**" then
            local closeAt = text:find("**", i + 2, true)
            if closeAt then
                out[#out + 1] = COLOR_BOLD
                AppendEscaped(out, text:sub(i + 2, closeAt - 1))
                out[#out + 1] = COLOR_RESET
                i = closeAt + 2
            else
                AppendEscaped(out, char)
                i = i + 1
            end
        elseif char == "[" then
            local labelEnd = text:find("](", i + 1, true)
            local urlEnd = labelEnd and text:find(")", labelEnd + 2, true)
            if labelEnd and urlEnd then
                out[#out + 1] = COLOR_LINK
                AppendEscaped(out, text:sub(i + 1, labelEnd - 1))
                out[#out + 1] = COLOR_RESET
                out[#out + 1] = " ("
                out[#out + 1] = COLOR_LINK_URL
                AppendEscaped(out, text:sub(labelEnd + 2, urlEnd - 1))
                out[#out + 1] = COLOR_RESET
                out[#out + 1] = ")"
                i = urlEnd + 1
            else
                AppendEscaped(out, char)
                i = i + 1
            end
        else
            AppendEscaped(out, char)
            i = i + 1
        end
    end

    return table.concat(out)
end

function M.BulletPrefix(level)
    level = tonumber(level) or 1
    if level < 1 then level = 1 end
    return string.rep("  ", level - 1) .. "- "
end

function M.FormatReleaseText(data, limit)
    if type(data) ~= "table" or #data == 0 then
        return "No changelog data available."
    end

    local lines = {}
    local count = math.min(limit or 3, #data)

    for index = 1, count do
        local release = data[index]
        if index > 1 then
            lines[#lines + 1] = ""
        end

        lines[#lines + 1] = "|cffffd100Version " .. M.Inline(release.version or "?") .. COLOR_RESET

        for _, section in ipairs(release.sections or {}) do
            lines[#lines + 1] = ""
            lines[#lines + 1] = COLOR_BOLD .. M.Inline(section.title or "Untitled") .. COLOR_RESET

            for _, entry in ipairs(section.entries or {}) do
                local text, level = M.GetEntryParts(entry)
                lines[#lines + 1] = "  " .. M.BulletPrefix(level) .. M.Inline(text)
            end
        end
    end

    return table.concat(lines, "\n")
end
