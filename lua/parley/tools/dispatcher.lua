-- Tool dispatcher — the DRY safety layer between tool_loop and
-- individual handler functions.
--
-- Handlers (lua/parley/tools/builtin/*.lua) are pure. They know
-- nothing about cwd-scope, symlink resolution, truncation, or
-- error wrapping. Every safety concern lives HERE so there's
-- exactly one place to audit and one place to fix.
--
-- At M2 this module exposes read-path helpers (resolve_path_in_cwd,
-- truncate, execute_call). Write-path concerns (dirty-buffer guard,
-- .parley-backup, gitignore auto-append, checktime-reload,
-- metadata-preserving truncation for write_file's pre-image footer)
-- land in M5 Task 5.1 / 5.2 / 5.3 / 5.6 and extend this same file.
--
-- SINGLE source for each invariant:
--   - cwd-scope + symlink safety: resolve_path_in_cwd
--   - result size cap:            truncate / truncate_preserving_footer (M5)
--   - pcall-guarded handler call: execute_call
--   - dirty-buffer guard:         check_dirty_buffer (M5)
--   - pre-image capture:          ensure_backup (M5)
--   - post-write reload:          _checktime_if_loaded (M5)

local M = {}

--------------------------------------------------------------------------------
-- Path resolution
--------------------------------------------------------------------------------

--- Resolve a possibly-relative path against cwd, normalize, resolve
--- symlinks via fs_realpath, and reject anything whose real path
--- escapes cwd.
---
--- Handles the three cases the tool loop needs:
---
---   1. Existing file inside cwd → returns canonical realpath
---   2. Existing file outside cwd (or symlink resolving outside) → rejected
---   3. NEW file (doesn't exist yet) inside cwd → returns
---      `realpath(parent) .. "/" .. basename`. This is what
---      write_file needs when creating a fresh file: the file
---      itself doesn't exist, but its parent dir does, and that
---      parent must be inside cwd.
---
--- Returns `abs_path` on success, or `(nil, err_msg)` on rejection.
---
--- @param path string
--- @param cwd string
--- @return string|nil abs_path
--- @return string|nil err_msg
function M.resolve_path_in_cwd(path, cwd)
    if type(path) ~= "string" or path == "" then
        return nil, "path must be a non-empty string"
    end

    -- Normalize the joined path lexically first, so "../" and "./"
    -- segments are collapsed before we hit the filesystem.
    local joined
    if path:sub(1, 1) == "/" then
        joined = vim.fs.normalize(path)
    else
        joined = vim.fs.normalize(cwd .. "/" .. path)
    end

    -- Resolve symlinks for the PATH we care about. If the path
    -- doesn't exist (new file creation), fall back to realpath-ing
    -- the parent directory and appending the basename.
    local real_path = vim.loop.fs_realpath(joined)
    if not real_path then
        local parent = vim.fs.dirname(joined)
        local real_parent = vim.loop.fs_realpath(parent)
        if not real_parent then
            return nil, "cannot resolve parent directory: " .. parent
        end
        real_path = real_parent .. "/" .. vim.fs.basename(joined)
    end

    -- Resolve the cwd too so the comparison is between two canonical
    -- absolute paths (handles symlinked /tmp → /private/tmp on macOS).
    local real_cwd = vim.loop.fs_realpath(cwd) or vim.fs.normalize(cwd)

    -- A path is inside cwd iff it equals cwd OR starts with cwd + "/".
    -- String comparison is safe because both sides are canonical
    -- absolute paths produced by fs_realpath.
    if real_path ~= real_cwd and not (real_path:sub(1, #real_cwd + 1) == real_cwd .. "/") then
        return nil, "path outside working directory: " .. path
    end

    return real_path
end

--------------------------------------------------------------------------------
-- Result truncation
--------------------------------------------------------------------------------

--- Byte-length truncation with a trailing marker.
---
--- Used by execute_call to cap the size of each ToolResult at
--- `opts.max_bytes` (default 100KB via the agent config). M5 will
--- add a metadata-preserving variant (truncate_preserving_footer)
--- that write_file uses to keep its `pre-image:` footer intact.
---
--- Pure. Handles nil content as empty string.
---
--- @param content string|nil
--- @param max_bytes number
--- @return string
function M.truncate(content, max_bytes)
    content = content or ""
    if #content <= max_bytes then return content end
    local omitted = #content - max_bytes
    return content:sub(1, max_bytes) .. string.format("\n... [truncated: %d bytes omitted]", omitted)
end

--------------------------------------------------------------------------------
-- Handler invocation
--------------------------------------------------------------------------------

--- Execute a ToolCall against the registered handler, with:
---   - registry lookup (is_error on unknown name)
---   - pcall around handler (is_error on raise)
---   - non-table return guard (is_error on misbehaving handler)
---   - id/name stamping on the returned result
---   - byte-length truncation when opts.max_bytes is set
---
--- The returned ToolResult is ALWAYS well-shaped even when things
--- go wrong — the tool loop driver can serialize it directly without
--- further checks.
---
--- M5 will add a write-path prelude to this function (cwd-scope,
--- dirty-buffer, backup, gitignore, checktime) branched on
--- `def.kind == "write"`. At M2 the shared prelude only handles
--- the cwd-scope check when `call.input.path` is present.
---
--- @param call ToolCall { id, name, input }
--- @param tools_registry table module exposing `get(name)` (parley.tools)
--- @param opts table|nil { max_bytes?: number, cwd?: string }
--- @return ToolResult
function M.execute_call(call, tools_registry, opts)
    opts = opts or {}

    local def = tools_registry.get(call.name)
    if not def then
        return {
            id = call.id,
            name = call.name,
            content = "Tool '" .. call.name .. "' is not available on this client. Please continue without it.",
            is_error = true,
        }
    end

    -- SHARED PRELUDE: cwd-scope check for any tool whose input has a
    -- `path` string field. Applies uniformly to read and write tools
    -- (M5 adds write-specific additional guards on top of this).
    --
    -- `opts.cwd` is optional — the tool_loop passes it explicitly so
    -- the dispatcher does not need to know about vim.fn.getcwd() from
    -- pure test contexts. When absent, the check is skipped (caller
    -- accepts responsibility).
    -- Resolve path fields: tools may use `path` or `file_path`.
    -- Check both so the cwd-scope guard applies uniformly.
    local path_fields = { "path", "file_path" }
    for _, field in ipairs(path_fields) do
        if opts.cwd and call.input and type(call.input[field]) == "string" then
            local abs, scope_err = M.resolve_path_in_cwd(call.input[field], opts.cwd)
            if not abs then
                return {
                    id = call.id,
                    name = call.name,
                    content = scope_err,
                    is_error = true,
                }
            end
            call.input[field] = abs
        end
    end

    -- HANDLER invocation, pcall-guarded. A raising handler becomes an
    -- error ToolResult rather than propagating the error up to the
    -- tool loop (which would leave an orphan 🔧: block and break the
    -- cancel-cleanup invariant).
    local ok, result = pcall(def.handler, call.input or {})
    if not ok then
        return {
            id = call.id,
            name = call.name,
            content = "handler error: " .. tostring(result),
            is_error = true,
        }
    end
    if type(result) ~= "table" then
        return {
            id = call.id,
            name = call.name,
            content = "handler returned non-table: " .. type(result),
            is_error = true,
        }
    end

    -- Stamp id and name so downstream serializers don't need to look
    -- back at the originating call. Handlers MAY omit these fields
    -- (see types.lua ToolResult contract note).
    result.id = call.id
    result.name = call.name

    -- Truncate result content to the configured cap. M5 will branch
    -- here on def.kind == "write" to use truncate_preserving_footer
    -- for the write_file pre-image metadata line.
    if opts.max_bytes then
        result.content = M.truncate(result.content or "", opts.max_bytes)
    end

    return result
end

return M
