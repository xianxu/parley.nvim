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
---@param line string
---@return string
function M.strip_data_prefix(line)
    return (line:gsub("^data: ", ""))
end

return M
