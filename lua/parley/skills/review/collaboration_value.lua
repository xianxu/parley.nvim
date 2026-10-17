-- The collaboration-mode field's bounded YAML subset. PURE: no decoder process.
-- Supports scalar modes, block/flow mappings and heading-name sequences only.
local M = {}
local frontmatter = require("parley.frontmatter")
local function trim(s) return (s:gsub("^%s+", ""):gsub("%s+$", "")) end
local function fail(message) error(message, 0) end

-- Comments start only outside quotes and after separation whitespace.
local function uncomment(s)
    local i = 1
    while i <= #s do
        local c = s:sub(i, i)
        local previous = s:sub(1, i - 1):match("(%S)%s*$")
        if (c == '"' or c == "'") and (not previous or previous:match("[%[{,:%-]")) then
            local span = frontmatter.quoted_span(s:sub(i))
            if not span then fail("unclosed quoted value") end
            i = i + #span
        elseif c == "#" and (i == 1 or s:sub(i - 1, i - 1):match("%s")) then
            return trim(s:sub(1, i - 1))
        else i = i + 1 end
    end
    return trim(s)
end
local function utf8_char(n)
    if n > 0x10ffff or (n >= 0xd800 and n <= 0xdfff) then fail("invalid Unicode escape") end
    if n < 0x80 then return string.char(n) end
    if n < 0x800 then return string.char(0xc0 + math.floor(n / 64), 0x80 + n % 64) end
    if n < 0x10000 then return string.char(0xe0 + math.floor(n / 4096), 0x80 + math.floor(n / 64) % 64, 0x80 + n % 64) end
    return string.char(0xf0 + math.floor(n / 262144), 0x80 + math.floor(n / 4096) % 64, 0x80 + math.floor(n / 64) % 64, 0x80 + n % 64)
end
local escapes = { ['"'] = '"', ["\\"] = "\\", ["/"] = "/", n = "\n", r = "\r", t = "\t", b = "\b", f = "\f", [" "] = " " }
local function unquote(span)
    if span:sub(1, 1) == "'" then return frontmatter.unquote(span) end
    local out, i = {}, 2
    while i < #span do
        local c = span:sub(i, i)
        if c == "\\" then
            local e = span:sub(i + 1, i + 1)
            local width = ({ x = 2, u = 4, U = 8 })[e]
            if width then
                local hex = span:sub(i + 2, i + 1 + width)
                if #hex ~= width or hex:find("[^%da-fA-F]") then fail("invalid Unicode escape") end
                out[#out + 1] = utf8_char(tonumber(hex, 16))
                i = i + width + 2
            else
                if not escapes[e] then fail("unsupported quoted escape: \\" .. e) end
                out[#out + 1] = escapes[e]
                i = i + 2
            end
        else out[#out + 1], i = c, i + 1 end
    end
    return table.concat(out)
end

local function decode(text, block_scalar)
    local i = 1
    local function skip() local _, last = text:find("^%s*", i); i = (last or i - 1) + 1 end
    local function scalar(key, whole)
        skip()
        local c = text:sub(i, i)
        if c == '"' or c == "'" then
            local span = frontmatter.quoted_span(text:sub(i))
            if not span then fail("unclosed quoted value") end
            i = i + #span
            return unquote(span)
        end
        local start = i
        while i <= #text do
            c = text:sub(i, i)
            if (not whole and (c == "," or c == "]" or c == "}")) or (key and c == ":") then break end
            if (not whole or i == start) and (c == "[" or c == "{") then fail("nested or malformed value") end
            i = i + 1
        end
        local value = trim(text:sub(start, i - 1))
        if value == "" or value:match("^[&*!|>%%@`?%-]") or value:find(":%s")
            or value:match("^%d") or value:match("^[+.]%d")
            or ({ null = true, ["~"] = true, ["true"] = true, ["false"] = true, yes = true, no = true, on = true, off = true })[value:lower()] then
            fail("expected a string; unsupported YAML value: " .. value)
        end
        return value
    end
    local function list()
        skip()
        if text:sub(i, i) ~= "[" then fail("heading names must be a list") end
        i = i + 1
        local result = {}
        skip()
        while text:sub(i, i) ~= "]" do
            result[#result + 1] = scalar(false)
            skip()
            local c = text:sub(i, i)
            if c == "]" then break end
            if c ~= "," then fail("expected ',' or ']' in heading list") end
            i = i + 1
            skip()
        end
        i = i + 1
        return result
    end
    skip()
    local result
    if text:sub(i, i) == "{" then
        result = {}
        i = i + 1
        skip()
        while text:sub(i, i) ~= "}" do
            local key = scalar(true)
            skip()
            if text:sub(i, i) ~= ":" then fail("expected ':' after mapping key") end
            if result[key] ~= nil then fail("duplicate mapping key: " .. key) end
            i = i + 1
            skip()
            result[key] = key == "default" and scalar(false) or list()
            skip()
            local c = text:sub(i, i)
            if c == "}" then break end
            if c ~= "," then fail("expected ',' or '}' in mapping") end
            i = i + 1
            skip()
        end
        i = i + 1
    else result = scalar(false, block_scalar) end
    skip()
    if i <= #text then fail("unexpected content after value") end
    return result
end

local function field_line(line)
    local key, value = line:match("^([%w_][%w_-]*)%s*:%s*(.*)$")
    if not key then key, value = line:match('^"([%w_-]+)"%s*:%s*(.*)$') end
    if not key then key, value = line:match("^'([%w_-]+)'%s*:%s*(.*)$") end
    return key, value
end

local function parse(lines)
    local fm = frontmatter.parse(lines)
    if not fm then
        if lines[1] == "---" then
            for _, line in ipairs(lines) do
                if field_line(line) == "collaboration-mode" then fail("frontmatter is not closed") end
            end
        end
        return nil
    end
    local field, values = nil, {}
    for row = 2, fm.close - 1 do
        local line = lines[row]
        local key, value = field_line(line)
        if key then
            if key == "collaboration-mode" then
                if field then fail("duplicate collaboration-mode field") end
                field = row
                values[#values + 1] = { indent = 0, text = uncomment(value) }
            elseif field then break end
        elseif field then
            if line:find("\t") then fail("tabs are unsupported in collaboration-mode") end
            local content = uncomment(line)
            if content ~= "" then
                local indent = #(line:match("^(%s*)") or "")
                if indent == 0 and not (values[1].text:sub(1, 1) == "{" and content:match("^}")) then
                    fail("expected an indented collaboration-mode value")
                end
                values[#values + 1] = { indent = indent, text = content }
            end
        end
    end
    -- A following top-level field cannot hide a later duplicate.
    local seen = 0
    for row = 2, fm.close - 1 do
        if field_line(lines[row]) == "collaboration-mode" then seen = seen + 1 end
    end
    if seen > 1 then fail("duplicate collaboration-mode field") end
    if not field then return nil end
    if values[1].text ~= "" then
        if #values > 1 and values[1].text:sub(1, 1) ~= "{" then fail("unexpected continuation of scalar value") end
        local joined = {}
        for _, value in ipairs(values) do joined[#joined + 1] = value.text end
        return decode(table.concat(joined, " "))
    end
    if #values == 1 then fail("collaboration-mode requires a value") end
    local parts, index, indent = {}, 2, values[2].indent
    while index <= #values do
        local item = values[index]
        if item.indent ~= indent then fail("inconsistent mapping indentation") end
        local key, value = item.text:match("^([^:]+):%s*(.*)$")
        if not key then fail("expected a collaboration-mode mapping") end
        index = index + 1
        if value == "" then
            local names, sequence_indent = {}, nil
            while index <= #values and values[index].indent > indent do
                local child = values[index]
                sequence_indent = sequence_indent or child.indent
                if child.indent ~= sequence_indent then fail("inconsistent sequence indentation") end
                local name = child.text:match("^%-%s+(.+)$")
                if not name then fail("expected a heading-name sequence item") end
                names[#names + 1] = frontmatter.quote(decode(name, true))
                index = index + 1
            end
            if #names == 0 then fail("heading names require a list") end
            value = "[" .. table.concat(names, ",") .. "]"
        elseif value:sub(1, 1) == "[" then
            while index <= #values and values[index].indent > indent do
                value = value .. " " .. values[index].text
                index = index + 1
            end
        end
        parts[#parts + 1] = key .. ":" .. value
    end
    return decode("{" .. table.concat(parts, ",") .. "}")
end

--- Decode only collaboration-mode from a Markdown snapshot.
--- @return string|table|nil value
--- @return string|nil error
function M.parse(lines)
    local ok, result = pcall(parse, lines)
    if not ok then return nil, "collaboration-mode: " .. tostring(result) end
    return result, nil
end
return M
