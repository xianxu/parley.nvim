-- review skill — Edit document based on 🤖 review markers.
--
-- Marker grammar:  🤖<quoted>?([user]|{agent})*
--   <> = quoted body (optional, at most one, only as the first slot)
--   [] = human turns
--   {} = agent turns (any order after an optional <>)
--   Ready for agent = last section is [] (human spoke last)
--   Pending (quickfix) = last section is non-empty {} (agent asked, human hasn't replied)
--   See workshop/issues/000123-quoted-body-marker-syntax.md for the rationale.

local M = {}

local _parley

local function get_parley()
    if not _parley then _parley = require("parley") end
    return _parley
end

--------------------------------------------------------------------------------
-- Marker parsing (extracted from review.lua)
--------------------------------------------------------------------------------

-- Find the close that matches the `open` at `start`, tracking nesting depth.
--
-- `opts` (optional) enables bounded multi-line matching for parse_markers:
--   budget       — max number of newlines the scan may cross before giving up
--                  (returns nil). nil = unlimited (the historical behavior;
--                  used by single-line callers and drill_in, which passes
--                  already-multi-line text and relies on unbounded scanning).
--   is_excluded  — predicate (offset) -> bool. When true for a given byte
--                  offset, an `open`/`close` char there is ignored (does not
--                  affect depth). Used to skip brackets inside fenced code
--                  blocks / inline-code spans so a `}` in a code sample can't
--                  close a marker opened in prose. Newlines still count toward
--                  the budget regardless of exclusion.
local function find_matching_bracket(text, start, open, close, opts)
    opts = opts or {}
    local budget = opts.budget
    local is_excluded = opts.is_excluded
    local depth = 0
    local newlines = 0
    for i = start, #text do
        local ch = text:sub(i, i)
        if ch == "\n" then
            newlines = newlines + 1
            if budget and newlines > budget then
                return nil
            end
        elseif (ch == open or ch == close) and not (is_excluded and is_excluded(i)) then
            if ch == open then
                depth = depth + 1
            else
                depth = depth - 1
                if depth == 0 then
                    return i
                end
            end
        end
    end
    return nil
end

-- Parse a marker starting at `pos` (the byte offset of 🤖). Returns:
--   sections — list of `[user]` and `{agent}` sections (in document order)
--   cursor   — byte offset just past the last consumed bracket (one past end)
--   quoted   — optional `<...>` quoted-body section, only valid as the
--              first slot immediately after 🤖. Shape: { text, byte_start,
--              byte_end } (byte_end is the closing `>`). `nil` if absent.
--   strike   — optional `~...~` strikethrough section (deletion proposal).
--              Same shape as quoted; byte_end is the closing `~`. Mutually
--              exclusive with quoted — only one or neither is set.
--
-- See workshop/issues/000123-quoted-body-marker-syntax.md (quoted-body) and
-- 000124-review-convention-alignment.md (strikethrough family) for grammar.
--
-- `opts` (optional): { budget, is_excluded } forwarded to find_matching_bracket
-- to enable bounded multi-line matching of <>, [], {} sections. Omitting it (the
-- highlighter and drill_in callers) yields the historical single-text behavior.
-- The ~...~ strike branch is always single-line regardless of opts — tildes are
-- common in prose and a greedy multi-line `~` match would absorb arbitrary text.
local function parse_marker_sections(text, pos, byte_len, opts)
    local cursor = pos + (byte_len or 4)  -- 🤖=4 bytes
    local sections = {}
    local quoted = nil
    local strike = nil

    -- Optional leading <...> OR ~...~ (mutually exclusive, first slot only).
    if cursor <= #text then
        local ch = text:sub(cursor, cursor)
        if ch == "<" then
            local close = find_matching_bracket(text, cursor, "<", ">", opts)
            if close then
                quoted = {
                    text = text:sub(cursor + 1, close - 1),
                    byte_start = cursor,
                    byte_end = close,
                }
                cursor = close + 1
            end
            -- Unmatched `<`: fall through; the chain loop below will break.
        elseif ch == "~" then
            -- Tildes don't nest — find the next `~` literally.
            -- Bounded to the same line: tildes are common in prose
            -- (`~/path`, math `~`) and a multi-line greedy match would
            -- absorb arbitrary text. If the operator needs to mark a
            -- multi-line deletion, they can mark each line separately.
            local close = text:find("~", cursor + 1, true)
            local nl = text:find("\n", cursor + 1, true)
            if close and (not nl or close < nl) then
                strike = {
                    text = text:sub(cursor + 1, close - 1),
                    byte_start = cursor,
                    byte_end = close,
                }
                cursor = close + 1
            end
            -- Unmatched `~` (or `\n` before next `~`): fall through; the
            -- chain loop below will break.
        end
    end

    while cursor <= #text do
        local ch = text:sub(cursor, cursor)
        if ch == "[" then
            local close = find_matching_bracket(text, cursor, "[", "]", opts)
            if not close then break end
            table.insert(sections, {
                type = "user",
                text = text:sub(cursor + 1, close - 1),
                byte_start = cursor,
                byte_end = close,
            })
            cursor = close + 1
        elseif ch == "{" then
            local close = find_matching_bracket(text, cursor, "{", "}", opts)
            if not close then break end
            table.insert(sections, {
                type = "agent",
                text = text:sub(cursor + 1, close - 1),
                byte_start = cursor,
                byte_end = close,
            })
            cursor = close + 1
        else
            break
        end
    end

    return sections, cursor, quoted, strike
end

local function in_code_fence(fence_ranges, line_idx)
    for _, range in ipairs(fence_ranges) do
        if line_idx >= range[1] and line_idx <= range[2] then
            return true
        end
    end
    return false
end

local function compute_fence_ranges(lines)
    local ranges = {}
    local fence_start = nil
    for i, line in ipairs(lines) do
        if line:match("^```") then
            if fence_start then
                table.insert(ranges, { fence_start, i - 1 })
                fence_start = nil
            else
                fence_start = i - 1
            end
        end
    end
    if fence_start then
        table.insert(ranges, { fence_start, #lines - 1 })
    end
    return ranges
end

local MARKER_CHAR = "🤖"
local MARKER_BYTE_LEN = 4

-- Each <>/[]/{} section may span at most this many newlines before its
-- close-search gives up (the opener is then left unrecognized, as in the
-- historical single-line behavior). The budget is PER SECTION — the counter
-- resets at each opening bracket — so the relevant guarantee is the blast
-- radius of a single *stray* opener: a typo'd `🤖{` absorbs at most this many
-- lines, never the whole document. (A well-formed multi-section marker could
-- therefore span a few × this; that's not a runaway, just a long marker.)
-- Generous enough for multi-paragraph proposals (the motivating case spanned 2
-- lines); see workshop/issues/000125-bounded-multiline-markers.md.
local MULTILINE_LINE_BUDGET = 50

-- Returns list of {start, finish} byte ranges for inline code spans on a line.
-- Handles `` ` `` and ``` `` ``` delimiters.
local function inline_code_ranges(line)
    local ranges = {}
    local i = 1
    while i <= #line do
        -- Count consecutive backticks
        local bt_start = i
        while i <= #line and line:sub(i, i) == "`" do
            i = i + 1
        end
        local bt_len = i - bt_start
        if bt_len > 0 then
            -- Find matching closing backticks of same length
            local delimiter = string.rep("`", bt_len)
            local close = line:find(delimiter, i, true)
            if close then
                table.insert(ranges, { bt_start, close + bt_len - 1 })
                i = close + bt_len
            end
        else
            i = i + 1
        end
    end
    return ranges
end

-- Parse 🤖 markers over the whole buffer at once (not line-by-line), so a
-- marker's <>/[]/{} sections may span multiple lines (bounded by
-- MULTILINE_LINE_BUDGET). The buffer is joined into one `doc` string; byte
-- offsets map back to (line, col) via `line_starts`. Brackets inside fenced
-- code blocks / inline-code spans are excluded so they can't open or close a
-- marker. See workshop/issues/000125-bounded-multiline-markers.md.
M.parse_markers = function(lines)
    local fence_ranges = compute_fence_ranges(lines)
    local doc = table.concat(lines, "\n")

    -- 1-based byte offset where each line begins in `doc`.
    local line_starts = {}
    do
        local off = 1
        for i, line in ipairs(lines) do
            line_starts[i] = off
            off = off + #line + 1  -- +1 for the joining "\n"
        end
    end

    -- Map a 1-based doc offset to 0-based (line, col). Binary search over
    -- line_starts (sorted ascending).
    local function offset_to_pos(offset)
        local lo, hi = 1, #line_starts
        while lo < hi do
            local mid = math.floor((lo + hi) / 2) + 1
            if line_starts[mid] <= offset then
                lo = mid
            else
                hi = mid - 1
            end
        end
        return lo - 1, offset - line_starts[lo]  -- 0-based line, 0-based col
    end

    -- Excluded byte ranges (1-based, inclusive) in `doc`: whole fenced lines,
    -- plus inline-code spans on non-fenced lines. Sorted by start for early-out.
    local excluded = {}
    for i, line in ipairs(lines) do
        local base = line_starts[i]
        if in_code_fence(fence_ranges, i - 1) then
            table.insert(excluded, { base, base + #line })  -- whole line (+ its \n)
        else
            for _, r in ipairs(inline_code_ranges(line)) do
                table.insert(excluded, { base + r[1] - 1, base + r[2] - 1 })
            end
        end
    end
    local function is_excluded(offset)
        for _, r in ipairs(excluded) do
            if r[1] > offset then break end       -- sorted: no later range can match
            if offset <= r[2] then return true end
        end
        return false
    end

    local opts = { budget = MULTILINE_LINE_BUDGET, is_excluded = is_excluded }
    local markers = {}
    local search_start = 1
    while true do
        local pos = doc:find(MARKER_CHAR, search_start, true)
        if not pos then break end
        if is_excluded(pos) then
            search_start = pos + MARKER_BYTE_LEN
            goto continue
        end

        local sections, end_pos, quoted, strike = parse_marker_sections(doc, pos, MARKER_BYTE_LEN, opts)
        -- Normalize empty `~~` to nil so downstream doesn't have to
        -- special-case it. (Empty `<>` is preserved here for review
        -- semantics — see review_spec; drill_in.parse normalizes it
        -- on its own surface.)
        if strike and strike.text == "" then strike = nil end
        -- Recognize a marker iff it has at least one `[]`/`{}` section,
        -- a `<>` quoted body, or a `~...~` strike. Bare 🤖 with none
        -- of these is plain text.
        if #sections > 0 or quoted or strike then
            local last = sections[#sections]
            local line0, col0 = offset_to_pos(pos)
            -- Ready = last section is non-empty [] (human spoke last,
            -- agent should act). Strike markers are proposals, not
            -- questions — they never count as ready.
            local ready = (not strike) and last and last.type == "user" and last.text ~= "" or false
            -- Pending = last section is non-empty {} (agent asked, needs human reply)
            local pending = last and last.type == "agent" and last.text ~= "" or false
            table.insert(markers, {
                line = line0,
                col = col0,
                quoted = quoted,
                strike = strike,
                sections = sections,
                ready = ready,
                pending = pending,
                raw = doc:sub(pos, end_pos - 1),
            })
        end
        search_start = end_pos
        ::continue::
    end

    return markers
end

-- Expose for highlighter.lua backward compatibility
M._parse_marker_sections = parse_marker_sections

--------------------------------------------------------------------------------
-- Quickfix helpers
--------------------------------------------------------------------------------

local function marker_summary(marker)
    local last = marker.sections[#marker.sections]
    if not last then return marker.raw end
    if last.type == "agent" then
        return "🤖 Agent: " .. last.text
    else
        return "🤖 " .. last.text
    end
end

M.populate_quickfix = function(buf, markers, filter)
    local file_name = vim.api.nvim_buf_get_name(buf)
    local items = {}
    for _, marker in ipairs(markers) do
        local include = (filter ~= "pending") or (marker.pending)
        if include then
            table.insert(items, {
                filename = file_name,
                lnum = marker.line + 1,
                col = marker.col + 1,
                text = marker_summary(marker),
            })
        end
    end
    vim.fn.setqflist(items, "r")
    if #items > 0 then
        vim.cmd("copen")
    end
end

-- Scan all .md files under dir for pending (non-ready) markers.
-- Returns list of { filepath, marker } sorted by filepath then line.
M.scan_pending = function(dir)
    local results = {}
    local files = vim.fn.glob(dir .. "/**/*.md", false, true)
    -- also catch top-level .md files (** may not match depth-0 on all systems)
    for _, f in ipairs(vim.fn.glob(dir .. "/*.md", false, true)) do
        table.insert(files, f)
    end
    local seen = {}
    for _, filepath in ipairs(files) do
        filepath = vim.fn.resolve(filepath)
        if not seen[filepath] then
            seen[filepath] = true
            local ok, lines = pcall(vim.fn.readfile, filepath)
            if ok and lines then
                local markers = M.parse_markers(lines)
                for _, marker in ipairs(markers) do
                    if marker.pending then
                        table.insert(results, { filepath = filepath, marker = marker })
                    end
                end
            end
        end
    end
    return results
end

-- Open a float picker listing all pending review markers under cwd.
-- Only runs inside a parley-enabled repo (.parley marker file present at git root).
M.cmd_review_finder = function()
    local parley = get_parley()
    if not parley.config.repo_root then
        parley.logger.warning("Review finder: not in a parley-enabled repo")
        return
    end

    local cwd = vim.fn.getcwd()
    local pending = M.scan_pending(cwd)

    if #pending == 0 then
        parley.logger.info("Review finder: no pending markers found")
        return
    end

    -- Group by file, preserving first-occurrence order
    local file_order = {}
    local counts = {}
    for _, entry in ipairs(pending) do
        local fp = entry.filepath
        if not counts[fp] then
            counts[fp] = 0
            table.insert(file_order, fp)
        end
        counts[fp] = counts[fp] + 1
    end

    local items = {}
    for _, fp in ipairs(file_order) do
        local rel = vim.fn.fnamemodify(fp, ":~:.")
        local n = counts[fp]
        table.insert(items, {
            display = rel .. "  (" .. n .. ")",
            search_text = rel,
            value = fp,
        })
    end

    require("parley.float_picker").open({
        title = "Pending Review (" .. #items .. " files)",
        items = items,
        anchor = "top",
        on_select = function(item)
            vim.cmd("edit " .. vim.fn.fnameescape(item.value))
        end,
    })
end

--------------------------------------------------------------------------------
-- Skill definition
--------------------------------------------------------------------------------

-- Resolve the review skill's own modes/ dir via runtimepath (the provider also
-- injects ctx.skill_dir at invoke time; this is the fallback for the `complete`
-- arg picker, which runs outside a source(ctx) call).
local function modes_dir()
    return (vim.api.nvim_get_runtime_file("lua/parley/skills/review/modes", false) or {})[1]
end

M.skill = {
    name = "review",
    description = "Edit document based on review markers",

    -- The `mode` arg selects a review stage; values come from modes/*.md (#133).
    args = {
        {
            name = "mode",
            description = "review mode",
            complete = function()
                local dir = modes_dir()
                local names = {}
                for _, m in ipairs(dir and require("parley.skills.review.mode").list(dir) or {}) do
                    table.insert(names, m.name)
                end
                return names
            end,
        },
    },

    -- Compose the system body: base SKILL.md ⊕ the selected mode's brief ⊕ its
    -- flag directives ⊕ any free-form operator instruction. PURE given ctx
    -- (the provider injects ctx.skill_md + ctx.skill_dir). With no mode, returns
    -- the base SKILL.md unchanged — the legacy marker-only review. (#133)
    source = function(ctx)
        ctx = ctx or {}
        local mode = require("parley.skills.review.mode")
        local args = ctx.args or {}
        local parts = { ctx.skill_md or "" }
        if args.mode and args.mode ~= "" and ctx.skill_dir then
            local m = mode.load(ctx.skill_dir .. "/modes", args.mode)
            if m then
                table.insert(parts, "\n\n## Review mode: " .. m.name .. "\n" .. m.body)
                table.insert(parts, "\n\n" .. mode.directives(m))
            end
        end
        if args.instruction and args.instruction ~= "" then
            table.insert(parts, "\n\n## Operator instruction\n" .. args.instruction)
        end
        return table.concat(parts)
    end,

    -- Declarative manifest fields (#128). Runs through the skill_invoke driver
    -- (M3/M4); the marker pre-check + resubmit loop live in M.run_via_invoke
    -- (below), not in dead skill_runner pre_submit/post_apply hooks.
    scope = "global",
    activation = { manual = true, auto = true },
    tools = { "read_file" },
    elevated = { "propose_edits" }, -- write tool, granted only on manual invoke (#129)
    force_tool = "propose_edits", -- compel the batch-edit tool this turn (M3)
}

--------------------------------------------------------------------------------
-- Run via the M3 skill_invoke driver (the P2 path; supersedes skill_runner.run
-- for review). The marker pre-check (was M.skill.pre_submit) + resubmit loop
-- (was M.skill.post_apply) stay HERE (review-specific); only the LLM exchange
-- goes through the generic driver. The skill_invoke driver applies the
-- propose_edits batch + renders the explanations (batch-edit-with-explanations
-- UX preserved). resubmit_count bounds re-invocation at 3, like the v1 path.
--------------------------------------------------------------------------------

M.run_via_invoke = function(buf, args, resubmit_count)
    args = args or {}
    resubmit_count = resubmit_count or 0
    local parley = get_parley()
    local skill_render = require("parley.skill_render")

    -- Count markers the agent should ACT on (last section a non-empty []).
    local function count_ready(ms)
        local n = 0
        for _, m in ipairs(ms) do
            if m.ready then n = n + 1 end
        end
        return n
    end

    -- Pre-check. A MODE run always proceeds — whole-doc modes work with zero
    -- markers (the headline no-marker general review, #133). A legacy
    -- marker-only run (no mode) needs at least one READY `[]` marker: pending
    -- `{}` markers no longer BLOCK submission (they're skipped and re-surface via
    -- the on-save quickfix), but if they're the only markers and no mode is set
    -- there's nothing to process.
    local lines = vim.api.nvim_buf_get_lines(buf, 0, -1, false)
    local markers = M.parse_markers(lines)
    local has_mode = args.mode ~= nil and args.mode ~= ""
    local ready_count_before = count_ready(markers)
    if not has_mode then
        if #markers == 0 then
            skill_render.clear_decorations(buf)
            vim.fn.setqflist({}, "r")
            pcall(vim.cmd, "cclose")
            parley.logger.info("Review: complete — no markers found")
            return
        end
        if ready_count_before == 0 then
            M.populate_quickfix(buf, markers, "pending")
            parley.logger.info("Review: no ready markers — pending agent questions await your reply")
            return
        end
    end
    -- Proceeding: clear stale quickfix (pending markers re-surface on save).
    vim.fn.setqflist({}, "r")
    pcall(vim.cmd, "cclose")

    -- NB: skill_registry's get/names are plain-function fields → call with DOT,
    -- not colon (colon would pass the registry as the `name` arg).
    local manifest = parley.skills.current().get("review")
    if not manifest then
        parley.logger.error("Review: 'review' manifest not found in the skill registry")
        return
    end

    require("parley.skill_invoke").invoke(buf, manifest, args, {
        manual = true,
        on_done = function(result)
            if not result or not result.ok then
                return -- skill_invoke already surfaced the error
            end
            local new_lines = vim.api.nvim_buf_get_lines(buf, 0, -1, false)
            local remaining = M.parse_markers(new_lines)
            if #remaining == 0 then
                parley.logger.info("Review: all comments addressed")
                return
            end
            -- Resubmit ONLY when actionable (ready `[]`) work remains AND it
            -- shrank. A whole-doc mode round is one-shot — it may legitimately
            -- INSERT `{}` findings (fact-check), which is not "stuck"; a `{}`-only
            -- or non-shrinking remainder ends the round cleanly. Pending `{}`
            -- markers surface via the on-save quickfix, not here (#133). Bounded
            -- at 3 like the v1 path.
            local ready_remaining = count_ready(remaining)
            if ready_remaining > 0 and ready_remaining < ready_count_before and resubmit_count < 3 then
                parley.logger.info("Review: " .. ready_remaining .. " ready marker(s) remain, resubmitting...")
                M.run_via_invoke(buf, args, resubmit_count + 1)
            else
                parley.logger.info("Review: round complete")
            end
        end,
    })
end

--------------------------------------------------------------------------------
-- On-enter quickfix scan
--------------------------------------------------------------------------------

local _qf_scanned_bufs = {}

local function rescan_quickfix(buf)
    if not vim.api.nvim_buf_is_valid(buf) then return end
    local lines = vim.api.nvim_buf_get_lines(buf, 0, -1, false)
    local markers = M.parse_markers(lines)
    local pending = {}
    for _, marker in ipairs(markers) do
        if marker.pending then table.insert(pending, marker) end
    end
    if #pending > 0 then
        M.populate_quickfix(buf, pending, "pending")
    else
        vim.fn.setqflist({}, "r")
        pcall(vim.cmd, "cclose")
    end
end

-- Called once per buffer on first BufEnter. Populates quickfix and sets up
-- BufWritePost autocmd to rescan on save.
local function scan_on_enter(buf)
    if _qf_scanned_bufs[buf] then return end
    _qf_scanned_bufs[buf] = true

    vim.api.nvim_create_autocmd("BufWritePost", {
        buffer = buf,
        callback = function() rescan_quickfix(buf) end,
    })

    rescan_quickfix(buf)
end

--------------------------------------------------------------------------------
-- Keybindings (buffer-local, for markdown files)
--------------------------------------------------------------------------------

M.setup_keymaps = function(buf)
    local parley = get_parley()
    local cfg = parley.config
    local set_keymap = parley.helpers.set_keymap

    scan_on_enter(buf)

    -- Marker insertion lives in the shared `chat_drill_in` binding
    -- (<M-q> / <C-g>q) per the review-convention target — see
    -- `drill_in_callbacks` in lua/parley/init.lua and #124. The
    -- review-specific insertion shortcuts (<C-g>vi / <C-g>vr) were
    -- retired because they duplicated that path with divergent
    -- output shapes.

    -- <C-g>ve: run review
    local edit_cfg = cfg.review_shortcut_edit
    if edit_cfg then
        for _, mode in ipairs(edit_cfg.modes or {}) do
            set_keymap({ buf }, mode, edit_cfg.shortcut, function()
                M.run_via_invoke(buf, {})
            end, "Parley review: process markers")
        end
    end
end

return M
