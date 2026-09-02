-- Architectural fitness function for the `docs-insert-orphans-section` family.
--
-- Four close-gate findings (BR-71, BR-80, BR-105, and the instance BR-80's own
-- fix introduced) are one authoring failure: an agent rewrites a comment by
-- WRITING the new paragraph and forgetting to DELETE the old one. The file then
-- documents two states of the world, and the stale half is indistinguishable
-- from the live half to the next reader — which is how BR-105 shipped a comment
-- stating the alphabetical channel order that the same commit pair had just
-- replaced with preference order.
--
-- BR-80's stated remedy was "lint `---@param` blocks naming absent identifiers".
-- That is why the family recurred: five of the seven live instances were plain
-- `--` stacks, and four of those did not precede a function at all. The rule has
-- to be about the SHAPE of the prose, not where it sits.
--
-- WHAT THIS CATCHES, exactly — say it precisely, because a guard whose message
-- overstates its reach is its own finding family (`test-title-overstates-guard`,
-- 9 instances): two paragraphs in ONE contiguous comment run that share a
-- verbatim 6-word run. That is the signature of copy-then-edit, and it found six
-- live instances, four of them in files no reviewer had named.
--
-- WHAT IT DOES NOT CATCH: a restatement fully paraphrased. float_picker's
-- "Translate the caller's items-index into an identity here" above "Translated
-- to an identity and resolved below" shares no 6-gram and is invisible here. The
-- human half of the rule lives in workshop/lessons.md; this guard is the half a
-- machine can hold.
--
-- TWO LINTS, NOT ONE (BR-108). The prose lint below EXCLUDES annotation blocks,
-- because an `---@param` legitimately restates the sentence above it — and that
-- exclusion is a hole exactly where this family most often lands. Shipping it
-- alone created two new instances and left BR-80's own, all three invisible to
-- it by construction. So the second half lives here too: an annotation block
-- must document the function it precedes. It catches what the first cannot, and
-- the first catches the plain `--` stacks that made scoping to `---@param` the
-- wrong remedy in the first place. Complementary, not alternatives.

local MIN_SHARED_WORDS = 6

local function repo_files()
    local out = vim.fn.systemlist("git ls-files 'lua/**/*.lua' 'tests/**/*.lua' 'scripts/**/*.lua'")
    assert.equals(0, vim.v.shell_error, "git ls-files failed")
    return out
end

--- Normalize a paragraph to comparable words. Punctuation that carries meaning
--- in this codebase's comments (`%s`, `*=`, backticks) is KEPT, so two
--- paragraphs quoting the same pattern still match.
local function words(text)
    local out = {}
    for w in text:lower():gsub("[^%w_%%%.%*=`%s]", " "):gmatch("%S+") do
        out[#out + 1] = w
    end
    return out
end

--- Contiguous runs of comment-only lines, as { line = <1-indexed>, text = {...} }.
local function comment_runs(lines)
    local runs, cur, start = {}, nil, nil
    for i, raw in ipairs(lines) do
        local s = raw:match("^%s*(.-)%s*$")
        if s:sub(1, 2) == "--" then
            if not cur then cur, start = {}, i end
            cur[#cur + 1] = s:gsub("^%-+", ""):match("^%s*(.-)%s*$")
        elseif cur then
            runs[#runs + 1] = { line = start, text = cur }
            cur, start = nil, nil
        end
    end
    if cur then runs[#runs + 1] = { line = start, text = cur } end
    return runs
end

--- Split a run into paragraphs: a blank comment line, or a line opening a new
--- sentence right after the previous one closed. The second rule matters because
--- the superseded half is usually stacked with no blank line between.
local function paragraphs(run)
    local paras, cur = {}, {}
    for idx, t in ipairs(run) do
        if t == "" then
            if #cur > 0 then paras[#paras + 1] = cur end
            cur = {}
        else
            local prev = idx > 1 and run[idx - 1] or ""
            local closed = prev:match("[%.%!%?]$") ~= nil
            local opens = t:match("^%u") ~= nil
            if #cur > 0 and closed and opens then
                paras[#paras + 1] = cur
                cur = {}
            end
            cur[#cur + 1] = t
        end
    end
    if #cur > 0 then paras[#paras + 1] = cur end
    return paras
end

--- An LSP annotation block is a DIFFERENT REGISTER from the prose above it and
--- is MEANT to restate it: `--- @param col number # 0-indexed byte position`
--- legitimately echoes the sentence that explained `col`. spell.lua:21 is
--- exactly that shape and was the guard's only false positive before this
--- exclusion; comparing annotation against prose measures nothing.
local function is_annotation(para)
    for _, line in ipairs(para) do
        if line:sub(1, 1) == "@" then return true end
    end
    return false
end

local function shared_run(a, b, n)
    if #a < n or #b < n then return nil end
    local seen = {}
    for i = 1, #a - n + 1 do
        seen[table.concat(a, " ", i, i + n - 1)] = true
    end
    for i = 1, #b - n + 1 do
        local gram = table.concat(b, " ", i, i + n - 1)
        if seen[gram] then return gram end
    end
    return nil
end

--- The whole detector over one file's lines. Exposed so the injection tests can
--- drive it on synthetic input instead of asserting against the tree — a guard
--- asserted only against the tree cannot be shown to fire at all.
local function superseded_paragraphs(lines)
    local found = {}
    for _, run in ipairs(comment_runs(lines)) do
        local prose = {}
        for _, para in ipairs(paragraphs(run.text)) do
            if not is_annotation(para) then
                prose[#prose + 1] = words(table.concat(para, " "))
            end
        end
        for a = 1, #prose do
            for b = a + 1, #prose do
                local gram = shared_run(prose[a], prose[b], MIN_SHARED_WORDS)
                if gram then
                    found[#found + 1] = { line = run.line, gram = gram }
                end
            end
        end
    end
    return found
end


--- Does an `---@param` block document the function it precedes?
---
--- Two failure shapes, both from hoisting code between a docstring and its
--- function: the block is ORPHANED (it names parameters the following signature
--- does not take) or SEVERED (a blank line divides them, so no tooling ties them
--- together at all).
---
--- `_name` in a signature is luacheck's mark for a deliberately unused argument
--- and the docstring names it without the underscore. That is convention, not
--- drift, so the underscore is stripped before comparing.
local function annotation_drift(lines)
    local found = {}
    local i = 1
    while i <= #lines do
        if lines[i]:match("^%s*%-%-%-") then
            local start = i
            local params = {}
            while i <= #lines and lines[i]:match("^%s*%-%-%-") do
                local name = lines[i]:match("^%s*%-%-%-%s*@param%s+([%w_.]+)")
                if name then params[#params + 1] = name:gsub("%..*", "") end
                i = i + 1
            end
            if #params > 0 then
                local j, blanks = i, 0
                while j <= #lines and lines[j]:match("^%s*$") do
                    blanks = blanks + 1
                    j = j + 1
                end
                local sig = lines[j] and (lines[j]:match("^%s*local function [%w_.:]*%(([^)]*)%)")
                    or lines[j]:match("^%s*function [%w_.:]*%(([^)]*)%)")
                    or lines[j]:match("^%s*local [%w_.]+%s*=%s*function%s*%(([^)]*)%)")
                    or lines[j]:match("^%s*[%w_.]+%s*=%s*function%s*%(([^)]*)%)"))
                if sig then
                    local actual = {}
                    for a in sig:gmatch("[^,]+") do
                        actual[(a:match("^%s*(.-)%s*$"):gsub("^_", ""))] = true
                    end
                    if blanks > 0 then
                        found[#found + 1] = { line = j, why =
                            ("a blank line separates the @param block from %s"):format(
                                vim.trim(lines[j]):sub(1, 48)) }
                    end
                    for _, name in ipairs(params) do
                        if not actual[(name:gsub("^_", ""))] then
                            found[#found + 1] = { line = start, why =
                                ("@param %s, but the signature is (%s)"):format(name, vim.trim(sig)) }
                        end
                    end
                end
            end
        else
            i = i + 1
        end
    end
    return found
end

describe("arch: a rewritten comment deletes the paragraph it replaces", function()
    it("fires on a stacked restatement (planted false negative)", function()
        local planted = {
            "-- The failure body's providers field IS the channel, so prefer it",
            "-- and fall back to the alias block.",
            "-- The failure body's providers field IS the channel when present, so",
            "-- it wins; the catalog narrows the rest.",
            "local x = 1",
        }
        local hits = superseded_paragraphs(planted)
        assert.equals(1, #hits,
            "the guard did not fire on two paragraphs sharing a verbatim opening")
    end)

    it("stays silent when an annotation restates its own prose (planted false positive)", function()
        -- The direction BR-106 says an agreement check must be asserted in: a
        -- shape that SHOULD pass. Without this case the guard could be tightened
        -- to "any repeated phrase" and still look correct.
        local planted = {
            "--- `col` is the 0 indexed byte position of the cursor, counting",
            "--- bytes to the left of the insertion point.",
            "---@param col number # 0 indexed byte position of the cursor",
            "function M.word_at_cursor(line, col) end",
        }
        assert.equals(0, #superseded_paragraphs(planted),
            "an @param block echoing its own prose is not a superseded paragraph")
    end)

    it("stays silent on two paragraphs that merely share a topic", function()
        local planted = {
            "-- Reads are sequential because they share one-shot repair state.",
            "-- Two is enough in practice: the native channel is read first.",
            "local y = 2",
        }
        assert.equals(0, #superseded_paragraphs(planted))
    end)


    it("fires on an @param the signature does not take (planted false negative)", function()
        local planted = {
            "---@param update table | nil # table with options",
            "local function adopt_agent(agent)",
        }
        assert.equals(1, #annotation_drift(planted))
    end)

    it("fires on a blank line severing the block from its function", function()
        local planted = {
            "---@param model table # a parsed catalog row",
            "",
            "M.register_live_agent = function(model)",
        }
        assert.equals(1, #annotation_drift(planted))
    end)

    it("accepts an underscore-marked unused argument (planted false positive)", function()
        -- `_account` is luacheck's mark for a deliberately unused parameter and
        -- the docstring names it without the underscore. Six real sites in this
        -- tree have that shape; flagging them would make the guard noise.
        local planted = {
            "---@param provider string",
            "---@param account string",
            "function M.forget(provider, _account)",
        }
        assert.equals(0, #annotation_drift(planted))
    end)

    it("accepts a block that documents its own function", function()
        local planted = {
            "---@param channels string[]",
            "---@param cb fun(health: table)",
            "function M.credential_health_across(channels, choose, cb)",
        }
        assert.equals(0, #annotation_drift(planted))
    end)

    it("every @param block in the tree documents the function it precedes", function()
        local offenders = {}
        for _, path in ipairs(repo_files()) do
            local fd = io.open(path, "r")
            if fd then
                local lines = {}
                for line in fd:lines() do lines[#lines + 1] = line end
                fd:close()
                for _, hit in ipairs(annotation_drift(lines)) do
                    offenders[#offenders + 1] = ("%s:%d — %s"):format(path, hit.line, hit.why)
                end
            end
        end
        assert.equals(0, #offenders,
            "an annotation block was separated from the function it documents — "
            .. "usually by hoisting code between them:\n  "
            .. table.concat(offenders, "\n  "))
    end)

    it("no comment run in the tree stacks a paragraph on its replacement", function()
        local offenders = {}
        for _, path in ipairs(repo_files()) do
            local fd = io.open(path, "r")
            if fd then
                local lines = {}
                for line in fd:lines() do lines[#lines + 1] = line end
                fd:close()
                for _, hit in ipairs(superseded_paragraphs(lines)) do
                    offenders[#offenders + 1] =
                        ("%s:%d — two paragraphs share \"%s\""):format(path, hit.line, hit.gram)
                end
            end
        end
        assert.equals(0, #offenders,
            "a rewritten comment left its predecessor in place; delete the stale "
            .. "paragraph rather than stacking the new one on it:\n  "
            .. table.concat(offenders, "\n  "))
    end)
end)
