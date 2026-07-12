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

local types = require("parley.tools.types")

--------------------------------------------------------------------------------
-- Path resolution
--------------------------------------------------------------------------------

-- Resolve a configured read root to a canonical absolute path. Roots may be
-- absolute (`/x`), home-relative (`~/x`, `~` expanded), or relative to cwd
-- (`../`, `sub/dir`). Returns the realpath, the normalized path if it does not
-- resolve, or nil for an invalid root. (#140)
local function resolve_root(root, cwd)
    if type(root) ~= "string" or root == "" then
        return nil
    end
    if root:sub(1, 1) == "~" then
        root = vim.fn.expand(root)
    end
    local abs = root:sub(1, 1) == "/" and vim.fs.normalize(root)
        or vim.fs.normalize(cwd .. "/" .. root)
    return vim.loop.fs_realpath(abs) or abs
end

--- Resolve a possibly-relative path against cwd, normalize, resolve
--- symlinks via fs_realpath, and reject anything whose real path
--- escapes cwd (and every configured read root).
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
--- `allowed_roots` (read tools only, #140): extra roots a path may resolve
--- under, in addition to cwd. Each is resolved + symlink-canonicalized, so a
--- symlink escaping every root is still rejected. nil/empty → cwd-only.
---
--- Returns `abs_path` on success, or `(nil, err_msg)` on rejection.
---
--- @param path string
--- @param cwd string
--- @param allowed_roots string[]|nil  extra read roots (absolute/~/relative-to-cwd)
--- @return string|nil abs_path
--- @return string|nil err_msg
function M.resolve_path_in_cwd(path, cwd, allowed_roots)
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

    -- Allowed base dirs: cwd, plus any configured read roots (#140). A path is
    -- inside a base iff it equals the base OR starts with base + "/". String
    -- comparison is safe because both sides are canonical fs_realpath outputs.
    local bases = { real_cwd }
    for _, root in ipairs(allowed_roots or {}) do
        local r = resolve_root(root, cwd)
        if r then
            table.insert(bases, r)
        end
    end

    for _, base in ipairs(bases) do
        if real_path == base or real_path:sub(1, #base + 1) == base .. "/" then
            return real_path
        end
    end

    if allowed_roots then
        return nil, "path outside working directory and configured read roots: "
            .. path .. " (add a root to parley `tool_read_roots` to allow it)"
    end
    return nil, "path outside working directory: " .. path
end

function M.resolve_read_path(path, read_roots)
    if type(path) ~= "string" or path == "" then
        return nil, "path must be a non-empty string"
    end
    local roots = {}
    for _, root in ipairs(read_roots or {}) do
        local resolved = resolve_root(root, root)
        if resolved then roots[#roots + 1] = resolved end
    end
    local candidates = {}
    if path:sub(1, 1) == "/" then
        candidates[1] = path
    else
        for _, root in ipairs(roots) do candidates[#candidates + 1] = root .. "/" .. path end
    end
    for _, candidate in ipairs(candidates) do
        candidate = vim.fs.normalize(candidate)
        if vim.loop.fs_lstat(candidate) then
            local real = vim.loop.fs_realpath(candidate)
            if not real then
                return nil, "cannot resolve read path: " .. path
            end
            for _, root in ipairs(roots) do
                if real == root or real:sub(1, #root + 1) == root .. "/" then return real end
            end
            return nil, "read path resolves outside configured roots: " .. path
        end
    end
    return nil, "read path not found in configured roots: " .. path
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

-- #139: horizontal output pager. Window `content` to lines [offset, offset+limit)
-- (offset 1-indexed) and, when the window doesn't cover the whole output, append a
-- footer naming the true total + how to page/narrow. Pure. Returns the windowed
-- string (with footer) and the total line count.
M.PAGE_DEFAULT_LIMIT = 200
M.PAGE_MAX_LIMIT = 2000

function M.page_lines(content, offset, limit)
    content = content or ""
    local lines = vim.split(content, "\n", { plain = true })
    -- A trailing newline yields a spurious empty final element; drop it so the
    -- count matches the visible lines.
    if #lines > 1 and lines[#lines] == "" then
        table.remove(lines)
    end
    local total = #lines
    offset = math.max(1, math.floor(offset or 1))
    limit = math.max(1, math.floor(limit or M.PAGE_DEFAULT_LIMIT))

    if offset > total then
        return "... [no lines at offset " .. offset .. "; output has " .. total .. " line(s)]", total
    end

    local last = math.min(offset + limit - 1, total)
    local window = {}
    for i = offset, last do
        window[#window + 1] = lines[i]
    end
    local text = table.concat(window, "\n")

    local windowed = (offset > 1) or (last < total)
    if windowed then
        local note = (last < total)
            and (" — pass offset=" .. (last + 1) .. " for the next page, or narrow your query")
            or " — end of output"
        text = text .. "\n... [lines " .. offset .. "-" .. last .. " of " .. total .. note .. "]"
    end
    return text, total
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
    local policy = opts.root_policy
    if not policy and opts.cwd then
        policy = require("parley.neighborhood").policy_from_roots(opts.cwd, nil, opts.read_roots)
    end

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
    -- `path` string field. Read tools additionally honor configured
    -- `tool_read_roots` (#140); write tools stay cwd-confined.
    -- (M5 adds write-specific additional guards on top of this.)
    --
    -- `opts.cwd` is optional — the tool_loop passes it explicitly so
    -- the dispatcher does not need to know about vim.fn.getcwd() from
    -- pure test contexts. When absent, the check is skipped (caller
    -- accepts responsibility).
    -- Resolve path fields: tools may use `path` or `file_path`.
    -- Check both so the cwd-scope guard applies uniformly.
    local function roots_for_def()
        -- #140: read tools may also reach any configured `tool_read_roots`;
        -- write tools get nil → cwd-only. Gate on `~= "write"` (the canonical
        -- read-tool predicate `@readonly` uses): `kind` defaults to read when
        -- absent, so `== "read"` would wrongly confine an absent-kind tool.
        return (def.kind ~= "write") and (policy and policy.read_roots or {}) or nil
    end

    local path_fields = { "path", "file_path" }
    if policy and call.input and def.default_path and call.input.path == nil
        and call.input.file_path == nil and call.input.paths == nil then
        call.input.path = def.default_path
    end
    for _, field in ipairs(path_fields) do
        if policy and call.input and type(call.input[field]) == "string" then
            local roots = roots_for_def()
            local abs, scope_err
            if def.kind ~= "write" then
                abs, scope_err = M.resolve_read_path(call.input[field], roots)
            else
                abs, scope_err = M.resolve_path_in_cwd(call.input[field], policy.write_root)
            end
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
    if policy and call.input and type(call.input.paths) == "table" then
        local roots = roots_for_def()
        local resolved = {}
        for i, path in ipairs(call.input.paths) do
            if type(path) ~= "string" then
                return {
                    id = call.id,
                    name = call.name,
                    content = "paths must be an array of strings",
                    is_error = true,
                }
            end
            local abs, scope_err
            if def.kind ~= "write" then
                abs, scope_err = M.resolve_read_path(path, roots)
            else
                abs, scope_err = M.resolve_path_in_cwd(path, policy.write_root)
            end
            if not abs then
                return {
                    id = call.id,
                    name = call.name,
                    content = scope_err,
                    is_error = true,
                }
            end
            resolved[i] = abs
        end
        call.input.paths = resolved
    end

    -- #139: horizontal output pager. For tools that don't self-paginate, take
    -- offset/limit out of the input (the handler never sees them) and apply them
    -- to the handler's OUTPUT below. read_file self_paginates → it pages natively.
    local page = nil
    if types.is_pageable(def) then -- #139: non-write, non-self-paginating only
        local default_limit = opts.page_limit or M.PAGE_DEFAULT_LIMIT
        local in_limit = tonumber((call.input or {}).limit) or default_limit
        page = {
            offset = tonumber((call.input or {}).offset) or 1,
            limit = math.min(in_limit, M.PAGE_MAX_LIMIT),
        }
        if call.input then
            call.input.offset = nil
            call.input.limit = nil
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

    -- #139: window the output (pager) for non-self-paginating tools, then byte-cap
    -- as the backstop for pathological single lines. M5 will branch here on
    -- def.kind == "write" to use truncate_preserving_footer for write_file.
    if page and not result.is_error then
        result.content = (M.page_lines(result.content or "", page.offset, page.limit))
    end
    if opts.max_bytes then
        result.content = M.truncate(result.content or "", opts.max_bytes)
    end

    return result
end

return M
