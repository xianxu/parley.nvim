-- log_emit.lua — Pure-function YAML/Markdown formatting for raw-mode logs.
--
-- Scope is intentionally narrow: emit only the shapes parley actually
-- produces (Anthropic-style request payloads + assembled responses,
-- exchange-level message lists). Not a general YAML 1.2 emitter.

local M = {}

local INDENT = "  "

-- Strings that need quoting under YAML 1.2 plain-scalar rules. We're
-- conservative: any string with leading/trailing whitespace, indicator
-- characters, control chars, or that could be parsed as a non-string
-- scalar gets quoted (or block-scalar'd if multiline).
local YAML_INDICATORS = {
    [":"] = true, ["#"] = true, ["&"] = true, ["*"] = true, ["!"] = true,
    ["|"] = true, [">"] = true, ["'"] = true, ['"'] = true, ["%"] = true,
    ["@"] = true, ["`"] = true, ["?"] = true, [","] = true,
    ["["] = true, ["]"] = true, ["{"] = true, ["}"] = true,
}

local YAML_RESERVED = {
    ["true"] = true, ["false"] = true, ["null"] = true,
    ["yes"] = true, ["no"] = true, ["on"] = true, ["off"] = true,
    ["~"] = true, [""] = true,
}

local function is_array(t)
    if type(t) ~= "table" then return false end
    if next(t) == nil then return false end
    local n = 0
    for _ in pairs(t) do n = n + 1 end
    for i = 1, n do
        if t[i] == nil then return false end
    end
    return true
end

local function needs_quoting(s)
    if YAML_RESERVED[s:lower()] then return true end
    if s:match("^[%s]") or s:match("[%s]$") then return true end
    if s:match("^[%-%?:]") then return true end
    if s:find("[%z\1-\31]") then return true end
    if s:match("^[+-]?%d+%.?%d*$") or s:match("^[+-]?%.%d+$") then return true end
    if s:match("^0x[%da-fA-F]+$") then return true end
    local first = s:sub(1, 1)
    if YAML_INDICATORS[first] then return true end
    if s:find(" #", 1, true) then return true end
    return false
end

local function quote_double(s)
    local escaped = s:gsub("\\", "\\\\"):gsub('"', '\\"')
    escaped = escaped:gsub("\n", "\\n"):gsub("\r", "\\r"):gsub("\t", "\\t")
    escaped = escaped:gsub("[%z\1-\8\11\12\14-\31]", function(c)
        return string.format("\\x%02x", string.byte(c))
    end)
    return '"' .. escaped .. '"'
end

local function emit_block_string(s, indent)
    local out = { "|" }
    local prefix = indent
    local body = s
    -- Strip a single trailing newline so block-literal default chomping
    -- (clip) reconstructs the original.
    if body:sub(-1) == "\n" then body = body:sub(1, -2) end
    for line in (body .. "\n"):gmatch("([^\n]*)\n") do
        if line == "" then
            table.insert(out, "")
        else
            table.insert(out, prefix .. line)
        end
    end
    return table.concat(out, "\n")
end

local function emit_scalar(v, indent_for_block)
    local t = type(v)
    if t == "nil" then return "null" end
    if t == "boolean" then return v and "true" or "false" end
    if t == "number" then
        if v == math.floor(v) and math.abs(v) < 1e15 then
            return tostring(math.floor(v))
        end
        return tostring(v)
    end
    if t == "string" then
        if v:find("\n", 1, true) then
            return emit_block_string(v, indent_for_block)
        end
        if needs_quoting(v) then return quote_double(v) end
        return v
    end
    return quote_double(vim.inspect(v))
end

-- Keys that should sort first in any mapping when present, before the
-- alphabetic remainder. Picked for readability of the shapes parley emits:
-- Anthropic content blocks lead with `type`; messages lead with `role`;
-- tool definitions lead with `name`.
local PRIORITY_KEYS = { "type", "role", "name" }

-- Collect key-value pairs in deterministic order.
local function collect_kvs(map, ordered_keys)
    local seen = {}
    local out = {}
    if ordered_keys then
        for _, k in ipairs(ordered_keys) do
            if map[k] ~= nil then
                table.insert(out, { key = k, value = map[k] })
                seen[k] = true
            end
        end
    else
        for _, k in ipairs(PRIORITY_KEYS) do
            if map[k] ~= nil and not seen[k] then
                table.insert(out, { key = k, value = map[k] })
                seen[k] = true
            end
        end
    end
    local rest = {}
    for k in pairs(map) do
        if type(k) == "string" and not seen[k] then table.insert(rest, k) end
    end
    table.sort(rest)
    for _, k in ipairs(rest) do
        table.insert(out, { key = k, value = map[k] })
    end
    return out
end

-- Forward
local emit_value

-- Render one "key: value" line. Returns the suffix to follow `key:`.
-- For inline scalars: " value". For block scalars / nested structures:
-- a multi-line string starting with the first content line.
-- The caller is responsible for emitting `key:` + the result.
local function render_kv_value(v, child_indent)
    if type(v) == "table" then
        if is_array(v) then
            if #v == 0 then return " []" end
            return "\n" .. emit_value(v, child_indent)
        else
            local kvs = collect_kvs(v)
            if #kvs == 0 then return " {}" end
            return "\n" .. emit_value(v, child_indent)
        end
    end
    if type(v) == "string" and v:find("\n", 1, true) then
        -- Block scalar: marker on this line, body indented under child_indent
        return " " .. emit_block_string(v, child_indent)
    end
    return " " .. emit_scalar(v, child_indent)
end

local function emit_mapping(map, indent, ordered_keys)
    local kvs = collect_kvs(map, ordered_keys)
    if #kvs == 0 then return "{}" end
    local out = {}
    for _, kv in ipairs(kvs) do
        local key_str = kv.key
        if needs_quoting(kv.key) then key_str = quote_double(kv.key) end
        local suffix = render_kv_value(kv.value, indent .. INDENT)
        table.insert(out, indent .. key_str .. ":" .. suffix)
    end
    return table.concat(out, "\n")
end

local function emit_array(arr, indent)
    if #arr == 0 then return "[]" end
    local out = {}
    -- After "- " comes 2 columns of additional indent for continuation.
    local item_indent = indent .. INDENT
    for _, item in ipairs(arr) do
        if type(item) == "table" and not is_array(item) then
            local kvs = collect_kvs(item)
            if #kvs == 0 then
                table.insert(out, indent .. "- {}")
            else
                local first = kvs[1]
                local first_key = first.key
                if needs_quoting(first_key) then first_key = quote_double(first_key) end
                local first_suffix = render_kv_value(first.value, item_indent)
                table.insert(out, indent .. "- " .. first_key .. ":" .. first_suffix)
                for i = 2, #kvs do
                    local kv = kvs[i]
                    local key_str = kv.key
                    if needs_quoting(key_str) then key_str = quote_double(key_str) end
                    local suffix = render_kv_value(kv.value, item_indent)
                    table.insert(out, item_indent .. key_str .. ":" .. suffix)
                end
            end
        elseif type(item) == "table" and is_array(item) then
            -- Nested array: place the inner `- ` block on the next line with
            -- one extra level of indent.
            if #item == 0 then
                table.insert(out, indent .. "- []")
            else
                local rendered = emit_array(item, item_indent)
                table.insert(out, indent .. "-\n" .. rendered)
            end
        else
            table.insert(out, indent .. "- " .. emit_scalar(item, item_indent))
        end
    end
    return table.concat(out, "\n")
end

emit_value = function(v, indent, _ctx)
    if type(v) == "table" then
        if is_array(v) then return emit_array(v, indent) end
        return emit_mapping(v, indent)
    end
    return emit_scalar(v, indent)
end

--- Emit a Lua value as YAML.
--- @param v any
--- @param ordered_keys string[]|nil  preferred key order at the top level
--- @return string
function M.emit_yaml(v, ordered_keys)
    if type(v) == "table" then
        if is_array(v) then return emit_array(v, "") end
        return emit_mapping(v, "", ordered_keys)
    end
    return emit_scalar(v, "")
end

--------------------------------------------------------------------------------
-- Markdown turn formatters
--------------------------------------------------------------------------------

local REQUEST_KEY_ORDER = {
    "model", "max_tokens", "stream", "system", "tools", "messages",
}

local RESPONSE_KEY_ORDER = {
    "stop_reason", "content", "usage",
}

--- Format one turn's raw-log entry.
--- @param opts table  { turn=int, ts=string, request=table, assembled=table|nil, sse_lines=string[]|nil }
--- @return string
function M.format_raw_turn(opts)
    local out = {}
    table.insert(out, string.format("## Turn %d — %s", opts.turn, opts.ts))
    table.insert(out, "")
    table.insert(out, "### Request payload (yaml)")
    table.insert(out, "")
    table.insert(out, "```yaml")
    table.insert(out, M.emit_yaml(opts.request or {}, REQUEST_KEY_ORDER))
    table.insert(out, "```")
    table.insert(out, "")
    if opts.assembled ~= nil then
        table.insert(out, "### Response (assembled, yaml)")
        table.insert(out, "")
        table.insert(out, "```yaml")
        table.insert(out, M.emit_yaml(opts.assembled, RESPONSE_KEY_ORDER))
        table.insert(out, "```")
        table.insert(out, "")
    end
    if opts.sse_lines and #opts.sse_lines > 0 then
        table.insert(out, "### Response (raw SSE)")
        table.insert(out, "")
        table.insert(out, "```")
        for _, line in ipairs(opts.sse_lines) do
            table.insert(out, line)
        end
        table.insert(out, "```")
        table.insert(out, "")
    end
    return table.concat(out, "\n")
end

--------------------------------------------------------------------------------
-- YAML parse (for the raw-input feature) — shells out to a tiny Python
-- helper using PyYAML. Test seam: override M._parse_yaml_impl in specs.
--------------------------------------------------------------------------------

local function script_path()
    local source = debug.getinfo(1, "S").source:sub(2)
    return source:gsub("/[^/]+$", "") .. "/../../scripts/yaml_to_json.py"
end

function M._parse_yaml_impl(yaml_str)
    local json_str = vim.fn.system({ "python3", script_path() }, yaml_str)
    if vim.v.shell_error ~= 0 then
        return nil, "yaml_to_json failed: " .. tostring(json_str)
    end
    local ok, decoded = pcall(vim.json.decode, json_str)
    if not ok then return nil, "yaml→json decode failed: " .. tostring(decoded) end
    return decoded, nil
end

--- Parse a YAML string into a Lua table. Returns (table, nil) on success,
--- (nil, err_string) on failure.
function M.parse_yaml(yaml_str)
    return M._parse_yaml_impl(yaml_str)
end

--- Format one turn's exchange-log entry. Each role + content is its own
--- subsection. Assistant content (incl. 🧠:/📝:/🔧:/📎: lines) is inlined
--- verbatim for string content; structured content blocks render as YAML.
--- @param opts table  { turn=int, ts=string, messages=table[] }
--- @return string
function M.format_exchange_turn(opts)
    local out = {}
    table.insert(out, string.format("## Turn %d — %s", opts.turn, opts.ts))
    table.insert(out, "")
    for _, msg in ipairs(opts.messages or {}) do
        local role = msg.role or "?"
        table.insert(out, "### " .. role)
        table.insert(out, "")
        local content = msg.content
        if type(content) == "string" then
            table.insert(out, content)
        elseif type(content) == "table" then
            table.insert(out, "```yaml")
            table.insert(out, M.emit_yaml(content))
            table.insert(out, "```")
        end
        table.insert(out, "")
    end
    return table.concat(out, "\n")
end

return M
