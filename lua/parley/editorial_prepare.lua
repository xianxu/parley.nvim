-- The editor seam for additive editorial settings. Projection is read-only;
-- application is one provenance-authorized, undoable insertion, never a write.
local M = {}
local uv = vim.uv or vim.loop

local function canonical(path)
    if path == "" then return "" end
    local absolute = vim.fn.fnamemodify(path, ":p")
    return uv.fs_realpath(absolute) or ((uv.fs_realpath(vim.fs.dirname(absolute)) or vim.fs.dirname(absolute))
        .. "/" .. vim.fs.basename(absolute))
end

local function content_hash(lines)
    return vim.fn.sha256(vim.json.encode(lines))
end

local function identity(buf)
    if not vim.api.nvim_buf_is_valid(buf) or not vim.api.nvim_buf_is_loaded(buf) then return nil end
    return { buf = buf, path = canonical(vim.api.nvim_buf_get_name(buf)),
        changedtick = vim.api.nvim_buf_get_changedtick(buf) }
end

local function current(buf, projection, after)
    local observed = identity(buf)
    if not observed or observed.buf ~= projection.buf or observed.path ~= projection.path then
        return nil, "Document identity changed during front matter preparation"
    end
    local tick = projection.changedtick + (after and projection.changed and 1 or 0)
    if observed.changedtick ~= tick
        or content_hash(vim.api.nvim_buf_get_lines(buf, 0, -1, false))
            ~= (after and projection.after_hash or projection.before_hash) then
        return nil, "Document changed during front matter preparation"
    end
    return true
end

--- Capture a compact executable projection; full postimage/header data is
--- temporary so operation snapshots stay proportional to the insertion.
function M.project(buf)
    if buf == 0 then buf = vim.api.nvim_get_current_buf() end
    local before = identity(buf)
    if not before or before.path == "" then return nil, "Save the document first" end
    local lines = vim.api.nvim_buf_get_lines(buf, 0, -1, false)
    local dir = (vim.api.nvim_get_runtime_file("lua/parley/skills/review/modes", false) or {})[1]
    local modes = dir and require("parley.skills.review.mode").list(dir) or {}
    local result, err = require("parley.editorial_frontmatter").fill(lines, modes)
    if not result then return nil, err end
    -- A skipped convenience edit carries only its notice. Couch transport
    -- does not need guessed editorial settings; semantic consumers resolve
    -- separately before using a mode or instruction.
    local settings = result.settings or { warnings = { result.skip_reason } }
    local projection = { buf = buf, path = before.path, changedtick = before.changedtick,
        before_hash = content_hash(lines), after_hash = content_hash(result.lines),
        changed = result.changed, patch = result.patch, skip_reason = result.skip_reason, settings = {
            modes = settings.modes, instruction = settings.instruction,
            presentation = settings.presentation, warnings = settings.warnings,
        } }
    local fresh, fresh_error = current(buf, projection, false)
    if not fresh then return nil, fresh_error end
    return projection
end

--- Validate the same native buffer incarnation/preimage before applying once,
--- and prove exactly one native edit plus the projected postimage afterwards.
--- Changedtick also rejects edit/undo ABA and a same-byte native reload.
function M.apply(buf, projection, command)
    if buf == 0 then buf = vim.api.nvim_get_current_buf() end
    local fresh, err = current(buf, projection, false)
    if not fresh then return nil, err end
    if projection.changed then
        local patch = projection.patch
        if type(patch) ~= "table" then return nil, "Front matter preparation lacks its insertion" end
        local ok, reason = require("parley.buffer_edit").edit_user_lines(command or "submit", buf,
            patch.first, patch.last, patch.lines)
        if not ok then return nil, "Front matter preparation refused: " .. tostring(reason) end
    end
    fresh, err = current(buf, projection, true)
    if not fresh then return nil, err end
    return true, projection
end

--- Outside registered Couch submission, use the identical projection/edit seam.
--- The caller retains routing, save and visible outcomes.
function M.prepare(buf, command)
    local projection, err = M.project(buf)
    if not projection then return nil, err end
    local ok, apply_error = M.apply(buf, projection, command)
    if not ok then return nil, apply_error end
    return projection
end

return M
