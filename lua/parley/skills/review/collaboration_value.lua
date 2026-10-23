-- The collaboration-mode field's bounded YAML subset. PURE: no decoder process.
-- Supports scalar modes, block/flow mappings and heading-name sequences only.
local M = {}
local frontmatter = require("parley.frontmatter")
local function trim(s)
    local first, last = 1, #s
    while first <= last and s:sub(first, first):match("%s") do first = first + 1 end
    while last >= first and s:sub(last, last):match("%s") do last = last - 1 end
    return s:sub(first, last)
end
local function fail(message) error(message, 0) end

-- Comments start only outside quotes and after separation whitespace.
local function uncomment(s)
    local i, previous = 1, nil
    while i <= #s do
        local c = s:sub(i, i)
        if (c == '"' or c == "'") and (not previous or previous:match("[%[{,:%-]")) then
            local span = frontmatter.quoted_span(s, i)
            if not span then fail("unclosed quoted value") end
            i = i + #span
            previous = c
        elseif c == "#" and (i == 1 or s:sub(i - 1, i - 1):match("%s")) then
            return trim(s:sub(1, i - 1))
        else
            if not c:match("%s") then previous = c end
            i = i + 1
        end
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
            local span = frontmatter.quoted_span(text, i)
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

-- Recognize root block keys before deciding the routing declaration is absent.
-- Unknown root representations must not turn an actual chat declaration into
-- the discussion default. Values of unrelated fields remain outside our scope.
local function field_line(line)
    local key, rest
    if line:sub(1, 1) == '"' or line:sub(1, 1) == "'" then
        local span = frontmatter.quoted_span(line)
        if not span then fail("unclosed root mapping key") end
        key, rest = unquote(span), line:sub(#span + 1)
    else
        key, rest = line:match("^(.-)(:%s.*)$")
        if not key then key, rest = line:match("^(.-)(:)$") end
        key = key and trim(key)
        if not key or key == "" or key:match("^[%[%]{}&*!|>%%@`?,:%-]") then
            fail("unsupported root shape; expected a block mapping with string keys")
        end
    end
    local value = rest and rest:match("^%s*:%s*(.*)$")
    if value == nil then fail("unsupported root mapping key") end
    if key == "<<" then fail("root merge keys are unsupported") end
    return key, value
end

local function flow_balance(text, stack)
    local i, previous = 1, nil
    while i <= #text do
        local c = text:sub(i, i)
        if (c == '\"' or c == "'") and (not previous or previous:match("[%[{,:%-]")) then
            local span = frontmatter.quoted_span(text, i)
            if not span then fail("multiline quoted flow scalars are unsupported") end
            i = i + #span
            previous = c
        else
            if c == "[" or c == "{" then stack[#stack + 1] = c
            elseif c == "]" or c == "}" then
                local expected = c == "]" and "[" or "{"
                if stack[#stack] ~= expected then fail("mismatched flow delimiters") end
                stack[#stack] = nil
            end
            if not c:match('%s') then previous = c end
            i = i + 1
        end
    end
end

local function root_fields(lines, close)
    local entries, current, base, stack = {}, nil, nil, {}
    for row = 2, close - 1 do
        local line = lines[row]
        local prefix = line:match("^(%s*)") or ""
        if prefix:find("\t", 1, true) then fail("tabs in root indentation are unsupported") end
        local literal = current and base and #prefix > base and current.value:match('^[|>]')
        local content = literal and trim(line) or uncomment(line)
        if content ~= "" then
            local indent = #prefix
            base = base or indent
            if indent < base then fail("inconsistent root mapping indentation") end
            if #stack > 0 then
                current.children[#current.children + 1] = { indent = indent - base, text = content }
                flow_balance(content, stack)
            elseif indent == base then
                local key, value = field_line(content)
                local _, raw = field_line(trim(line))
                current = { key = key, value = value, raw = raw, row = row, children = {} }
                entries[#entries + 1] = current
                if value:match("^[%[{]") then flow_balance(value, stack) end
            else
                -- Nested mappings belong only to a block collection, not to
                -- an unrelated scalar followed by a misindented declaration.
                if current.value ~= "" and not current.value:match("^[|>]")
                    and (content:find(":%s") or content:match(":$") or content:match("^%-%s")) then
                    fail("nested collection under a scalar root value")
                end
                current.children[#current.children + 1] = { indent = indent - base, text = content }
            end
        end
    end
    if #stack > 0 then fail("unclosed flow value in root mapping") end
    return entries
end

--- Shared root mapping scan for additive editorial fill. Unknown values stay
--- opaque; callers inspect only the fields they own. The original lines are
--- never rewritten. Limits cover interactive metadata, not the document body.
function M.header(lines)
    if lines[1] ~= "---" then return { entries = {}, fields = {}, scanned = 0 } end
    local close, size = nil, #lines[1] + 1
    for row = 2, #lines do
        size = size + #lines[row] + 1
        if row > 8192 or size > 1024 * 1024 then
            return nil, "frontmatter exceeds 8192 lines or 1 MiB; shorten the header before submitting"
        end
        if lines[row] == "---" then close = row; break end
    end
    if not close then return nil, "frontmatter is not closed" end
    local ok, entries = pcall(root_fields, lines, close)
    if not ok then return nil, "frontmatter: " .. tostring(entries) end
    local fields = {}
    for _, entry in ipairs(entries) do
        local key = entry.key:lower()
        fields[key] = fields[key] or {}
        fields[key][#fields[key] + 1] = entry
    end
    return { close = close, entries = entries, fields = fields, scanned = close - 1, bytes = size }
end

--- A known scalar from the root scanner. Legacy process-instruction retains
--- its historical plain-text reading (including an unquoted #).
function M.scalar(entry, legacy)
    if #entry.children > 0 then return nil, "expected one scalar value" end
    local text = trim(legacy and entry.raw or entry.value)
    if text == "" then return "" end
    local span = frontmatter.quoted_span(text)
    if span then
        local tail = trim(text:sub(#span + 1))
        if tail ~= "" and tail:sub(1, 1) ~= "#" then return nil, "unexpected text after quoted scalar" end
        local ok, value = pcall(unquote, span)
        if not ok then return nil, tostring(value) end
        return value
    end
    if legacy then return text end
    local ok, value = pcall(decode, text)
    if not ok or type(value) ~= "string" then return nil, "expected a scalar string" end
    return value
end

local function parse(lines)
    if lines[1] ~= "---" then return nil end
    local fm = frontmatter.parse(lines)
    if not fm then fail("frontmatter is not closed") end
    local field
    for _, entry in ipairs(root_fields(lines, fm.close)) do
        if entry.key:lower() == "collaboration-mode" then
            if field then fail("duplicate collaboration-mode field") end
            field = entry
        end
    end
    if not field then return nil end
    local values = { { indent = 0, text = field.value } }
    for _, child in ipairs(field.children) do values[#values + 1] = child end
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
            local continuation = { value }
            while index <= #values and values[index].indent > indent do
                continuation[#continuation + 1] = values[index].text
                index = index + 1
            end
            value = table.concat(continuation, " ")
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
