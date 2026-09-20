-- Architectural fitness functions for the parley codebase.
--
-- Architecture tests enforce code-layout invariants like "no
-- nvim_buf_set_lines outside buffer_edit.lua" and "pure files contain
-- no vim.api calls". They run as part of `make test` and fail with a
-- human-readable list of violations + the rule's rationale.
--
-- See workshop/plans/000090-renderer-refactor.md sections 5 + 8 for the
-- design and the initial rule set.

local M = {}

local function read_lines(path)
    local f = io.open(path, "r")
    if not f then return nil end
    local lines = {}
    for line in f:lines() do
        table.insert(lines, line)
    end
    f:close()
    return lines
end

local function expand_scope(scope)
    if type(scope) == "string" then
        return vim.fn.glob(scope, false, true)
    end
    return scope or {}
end

--- Assert that `pattern` (literal string by default; Lua pattern when
--- `is_pattern = true`) appears ONLY in files listed in `allow_only_in`,
--- within the file set defined by `scope`.
---
--- @param opts table
---   - pattern (string): the literal substring or Lua pattern to search for
---   - is_pattern (boolean, optional): true to treat `pattern` as a Lua pattern
---   - scope (string|string[]): glob string or list of file paths to scan
---   - allow_only_in (string[]): files exempt from the rule. Empty list = pattern forbidden in all of scope.
---   - rationale (string): human-readable explanation, surfaced in failure output
---   - ignore_comments (boolean, optional): skip lines starting with `--` (default true)
function M.assert_pattern_scoping(opts)
    local pattern = opts.pattern
    local files = expand_scope(opts.scope)
    local allow = {}
    for _, p in ipairs(opts.allow_only_in or {}) do
        allow[p] = true
    end
    local ignore_comments = opts.ignore_comments ~= false  -- default true
    local plain = not opts.is_pattern  -- string.find plain mode unless is_pattern=true

    local violations = {}
    for _, file in ipairs(files) do
        if not allow[file] then
            local lines = read_lines(file)
            if lines then
                for i, line in ipairs(lines) do
                    local stripped = line:gsub("^%s+", "")
                    local is_comment = ignore_comments and stripped:sub(1, 2) == "--"
                    if not is_comment and string.find(line, pattern, 1, plain) then
                        table.insert(violations, string.format("    %s:%d: %s", file, i, line))
                    end
                end
            end
        end
    end

    if #violations > 0 then
        local msg = string.format(
            "\n\n  Rationale: %s\n\n  Violations (%d):\n%s\n\n  Allowed in: %s\n",
            opts.rationale or "(no rationale)",
            #violations,
            table.concat(violations, "\n"),
            table.concat(opts.allow_only_in or {}, ", ")
        )
        error(msg, 2)
    end
end

--- The working tree's files matching git pathspecs: tracked AND untracked,
--- minus ignored and deleted ones, sorted. A guard that lists files through the
--- git index (`git ls-files`, `git grep`) cannot see the file being written right
--- now — untracked is the normal state of new code during the loop that adds it
--- (#261 M1 review BR-6). Every file-set guard lists through here;
--- tests/unit/arch_helper_spec.lua fails an arch spec that lists any other way.
---@param pathspecs string[] # git pathspecs, e.g. { 'lua/**/*.lua' }
---@return string[]
function M.worktree_files(pathspecs)
    local specs = {}
    for _, spec in ipairs(pathspecs) do specs[#specs + 1] = vim.fn.shellescape(spec) end
    local out = vim.fn.systemlist("git ls-files --cached --others --exclude-standard -- "
        .. table.concat(specs, " "))
    assert(vim.v.shell_error == 0, "git ls-files failed")
    local files, seen = {}, {}
    for _, file in ipairs(out) do
        if not seen[file] and vim.fn.filereadable(file) == 1 then
            seen[file] = true; files[#files + 1] = file
        end
    end
    table.sort(files)
    return files
end

return M
