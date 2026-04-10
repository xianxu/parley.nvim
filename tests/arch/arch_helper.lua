-- Architectural fitness functions for the parley codebase.
--
-- Architecture tests enforce code-layout invariants like "no
-- nvim_buf_set_lines outside buffer_edit.lua" and "pure files contain
-- no vim.api calls". They run as part of `make test` and fail with a
-- human-readable list of violations + the rule's rationale.
--
-- See docs/plans/000090-renderer-refactor.md sections 5 + 8 for the
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

return M
