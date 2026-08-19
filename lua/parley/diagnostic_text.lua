-- Pure display-row shaping for semantic diagnostic messages.
-- Neovim-specific width measurement is injected by the UI shell.

local M = {}

local function utf8_chars(text)
    return text:gmatch("[%z\1-\127\194-\244][\128-\191]*")
end

local function split_token(token, width, display_width)
    local fragments = {}
    local current = ""
    for char in utf8_chars(token) do
        local candidate = current .. char
        if current ~= "" and display_width(candidate) > width then
            fragments[#fragments + 1] = current
            current = char
        else
            current = candidate
        end
    end
    if current ~= "" then
        fragments[#fragments + 1] = current
    end
    return fragments
end

local function wrap_semantic_row(row, width, display_width)
    local rows = {}
    local current = ""
    local found_word = false

    for token in row:gmatch("%S+") do
        found_word = true
        local fragments = split_token(token, width, display_width)
        for index, fragment in ipairs(fragments) do
            local separator = index == 1 and current ~= "" and " " or ""
            local candidate = current .. separator .. fragment
            if current ~= "" and display_width(candidate) > width then
                rows[#rows + 1] = current
                current = fragment
            else
                current = candidate
            end
        end
    end

    if not found_word then
        return { "" }
    end
    rows[#rows + 1] = current
    return rows
end

--- Convert semantic text into rows bounded by a display-cell width.
--- Explicit newlines remain row boundaries; horizontal whitespace is rendered
--- as a single space. Width measurement is injected so this module stays pure.
--- @param text string|nil
--- @param width integer|nil
--- @param display_width fun(text:string):integer
--- @return string[]
function M.wrap_rows(text, width, display_width)
    assert(type(display_width) == "function", "display_width must be a function")
    width = math.max(2, math.floor(tonumber(width) or 2))

    local rows = {}
    for semantic_row in (tostring(text or "") .. "\n"):gmatch("(.-)\n") do
        local wrapped = wrap_semantic_row(semantic_row, width, display_width)
        for _, row in ipairs(wrapped) do
            rows[#rows + 1] = row
        end
    end
    return rows
end

return M
