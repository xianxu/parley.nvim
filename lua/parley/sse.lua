--------------------------------------------------------------------------------
-- Shared SSE line-decoding primitives.
--
-- Every provider streams Server-Sent Events, and every consumer of those
-- streams needs the same two things: strip the `data: ` prefix off a line,
-- and decode JSON without letting a malformed chunk raise mid-stream.
--
-- These lived as file-locals in providers.lua until #198, when the tool
-- wire modules (lua/parley/tools/wire_*.lua) needed them too. Hoisted
-- rather than copied — three copies of a two-line helper is exactly the
-- duplication ARCH-DRY exists to prevent.
--
-- PURE: no IO, no Neovim state beyond vim.json.
--------------------------------------------------------------------------------

local M = {}

--- Decode a JSON string, returning nil instead of raising on malformed input.
--- SSE streams routinely carry partial or non-JSON lines; a raising decoder
--- would abort the whole response.
---@param str string
---@return table|nil
function M.safe_json_decode(str)
    local success, decoded = pcall(vim.json.decode, str)
    if success then
        return decoded
    end
    return nil
end

--- Strip the SSE `data: ` prefix from a line. Lines without the prefix are
--- returned unchanged.
---
--- Parenthesized so this returns ONE value: `gsub` also returns a
--- replacement count, and leaking it makes `f(strip_data_prefix(line))`
--- pass two arguments.
---@param line string
---@return string
function M.strip_data_prefix(line)
    return (line:gsub("^data: ", ""))
end

--- Read an optional string field out of decoded JSON.
---
--- `vim.json.decode` turns an explicit JSON `null` into `vim.NIL`, a userdata
--- that is **truthy in Lua**. So the natural-looking guard
---
---     if obj.name then state.name = obj.name end
---
--- accepts a null and overwrites a good value with userdata, which then
--- raises the moment anything concatenates it. Streaming wires emit explicit
--- nulls freely (OpenAI sends `"finish_reason":null` on every chunk), and a
--- continuation chunk may repeat a field as null that an earlier chunk set
--- properly — so this is reachable, not theoretical.
---
--- Use this at every optional-field read in a decoder: it collapses `nil`,
--- `vim.NIL`, and any non-string to `nil`, which is what callers mean.
---@param value any
---@return string|nil
function M.str(value)
    if type(value) == "string" then
        return value
    end
    return nil
end

return M
