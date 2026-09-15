-- #232: the chat outline has two builders — flat (`_build_picker_items`, a
-- buffer) and tree (`_build_tree_outline_items`, files) — and chats always use
-- the tree. The tree used to carry its own question-only line rule, so the
-- `@@…@@` annotations the flat rule knows never reached a chat outline. Both
-- now classify lines through `_is_outline_item`; this spec is the differential
-- oracle that keeps them from drifting apart again, plus direct classifier
-- assertions over the annotation delimiters.
local outline = require("parley.outline")

local tmp = vim.fn.tempname() .. "-parley-outline-parity"
vim.fn.mkdir(tmp, "p")
local parley = require("parley")
parley.setup({ chat_dir = tmp, state_dir = tmp .. "/state", providers = {}, api_keys = {} })
local cfg = parley.config

local ROOT = "2026-09-05.10-00-00.000_root.md"
local CHILD = "2026-09-05.10-00-01.000_child.md"

-- Every line class the shared rule knows, in one chat: question, annotation,
-- fenced content that must NOT become an item, a branch row, a trailing empty
-- prompt that both builders drop, and — outside chats only — a heading.
local root_lines = {
    "---", "topic: Root", "file: " .. ROOT, "---", "",
    "💬: first question",
    "some text",
    "@@plan for tomorrow@@",
    "🤖: an answer",
    "```lua",
    "@@fenced@@",
    "```",
    "## not an item in a chat",
    "🌿: " .. CHILD .. ": Child topic",
    "",
    "💬: second question",
    "more",
    "💬: ",
}
local child_lines = {
    "---", "topic: Child topic", "file: " .. CHILD, "---",
    "🌿: " .. ROOT .. ": Root",
    "",
    "💬: child question",
    "@@child note@@",
}

local function write_tree()
    vim.fn.writefile(root_lines, tmp .. "/" .. ROOT)
    vim.fn.writefile(child_lines, tmp .. "/" .. CHILD)
    return tmp .. "/" .. ROOT
end

local function flat_items(lines)
    local buf = vim.api.nvim_create_buf(false, true)
    vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
    local document=require('parley.document')
    document.drain(document.attach(buf,{schedule=false}),1000)
    local items, cursor = {}, nil
    repeat
        local page, result = outline._build_picker_items(buf, cfg, { is_chat = true, cursor=cursor })
        vim.list_extend(items,page); cursor=result and result.cursor
    until not cursor
    vim.api.nvim_buf_delete(buf, { force = true })
    return items
end

-- Normalize a builder's output to what the two builders must agree on: the
-- line and the class, and the display for everything but branch rows (the
-- tree renders a branch as its topic; the flat rule as the raw line — that
-- difference is the tree's own and is not under test here).
local function normalized(items)
    local out = {}
    for _, it in ipairs(items) do
        local kind = it.type or (it.value.child_path and "branch") or "?"
        out[#out + 1] = { lnum = it.value.lnum, type = kind, display = kind ~= "branch" and it.display or nil }
    end
    return out
end

describe("outline builders agree on which lines are items (#232)", function()
    after_each(function()
        vim.fn.delete(tmp .. "/" .. ROOT)
        vim.fn.delete(tmp .. "/" .. CHILD)
    end)

    it("the tree minus its root row equals the flat outline of the same chat", function()
        local root = write_tree()
        local tree = outline._build_tree_outline_items(root, cfg, {})  -- child collapsed
        assert.matches("^📋 Root", tree[1].display)
        table.remove(tree, 1)
        assert.same(normalized(flat_items(root_lines)), normalized(tree))
    end)

    it("an annotation is an item in the tree; fenced and heading lines and the empty prompt are not", function()
        local tree = outline._build_tree_outline_items(write_tree(), cfg, {})
        local by_lnum = {}
        for _, it in ipairs(tree) do by_lnum[it.value.lnum] = it end
        assert.is_not_nil(by_lnum[8], "the @@…@@ line is an item")
        assert.equals("annotation", by_lnum[8].type)
        assert.equals("  → plan for tomorrow", by_lnum[8].display, "an annotation sits at the question level")
        assert.is_nil(by_lnum[11], "@@fenced@@ inside a code block is not an item")
        assert.is_nil(by_lnum[13], "a heading is not an item in a chat")
        assert.is_nil(by_lnum[18], "the trailing empty prompt is dropped")
        assert.equals(4, #tree - 1, "first question, annotation, branch, second question — nothing else")
    end)

    it("a nested chat's annotation appears under its branch row, indented once, in its own file", function()
        local root = write_tree()
        local tree = outline._build_tree_outline_items(root, cfg, nil)  -- nil = expand all
        local branch_at, note
        for i, it in ipairs(tree) do
            if it.value.child_path then branch_at = i end
            if it.display:find("child note", 1, true) then note = { i = i, item = it } end
        end
        assert.is_not_nil(branch_at, "branch row present")
        assert.is_not_nil(note, "the child's annotation is in the tree")
        assert.is_true(note.i > branch_at, "…after its branch row")
        assert.equals("    → child note", note.item.display, "one level deeper than the root chat, level with the child's question")
        -- resolve(): the harness TMPDIR is a symlink (/tmp → /private/tmp, #202).
        assert.equals(vim.fn.resolve(tmp .. "/" .. CHILD), vim.fn.resolve(note.item.value.file))
        assert.equals(8, note.item.value.lnum)
        -- The child's upward parent link (its line 5) is not a row: branch rows
        -- come from the parser, and the parser files that line as parent_link.
        for _, it in ipairs(tree) do
            assert.is_false(vim.fn.resolve(it.value.file) == vim.fn.resolve(tmp .. "/" .. CHILD) and it.value.lnum == 5,
                "the child's parent link leaked into the tree as a branch row")
        end
    end)
end)

describe("annotation delimiters (#232)", function()
    local function classify(line)
        return outline._is_outline_item(nil, 1, cfg, {}, { line }, { is_chat = true })
    end

    it("strips both @@ delimiters from the display", function()
        local is_item, kind, display = classify("@@my note@@")
        assert.is_true(is_item)
        assert.equals("annotation", kind)
        assert.equals("  → my note", display)
    end)

    it("is an annotation only when the whole line is delimited", function()
        assert.is_false((classify("see @@inline@@ here")))
        assert.is_false((classify("@@unterminated")))
        assert.is_false((classify("@@@@")), "an empty annotation is not an item")
        assert.is_true((classify("@@a@@")))
    end)
end)

-- Tree-only contract: a source line can own several branch rows. Do not
-- normalize by line number here; that would hide the loss this test guards.
describe("outline preserves sibling branches (#241)", function()
    local dir
    before_each(function()
        dir = vim.fn.tempname()
        vim.fn.mkdir(dir, "p")
        dir = vim.uv.fs_realpath(dir)
    end)
    after_each(function() vim.fn.delete(dir, "rf") end)

    for _, same_line in ipairs({ true, false }) do
        for _, expansion in ipairs({ "none", "first", "second", "all" }) do
            it((same_line and "same-line inline" or "mixed standalone/inline") .. " branches, expanded " .. expansion, function()
                local names = { "2026-09-14.12-00-00.000_root.md",
                    "2026-09-14.12-00-01.000_first.md", "2026-09-14.12-00-02.000_second.md" }
                local paths = { dir .. "/" .. names[1], dir .. "/" .. names[2], dir .. "/" .. names[3] }
                local function write(index, body)
                    local lines = { "---", "topic: " .. index, "file: " .. names[index], "---" }
                    vim.list_extend(lines, body)
                    vim.fn.writefile(lines, paths[index])
                end
                local first = "[🌿: First](" .. names[2] .. ")"
                local second = "[🌿: Second](" .. names[3] .. ")"
                local body = { "💬: root question", "🤖: answer" }
                if same_line then
                    body[#body + 1] = "Compare " .. first .. " and " .. second .. "."
                else
                    vim.list_extend(body, { "🌿: " .. names[2] .. ": First", "Also " .. second })
                end
                write(1, body)
                for i = 2, 3 do
                    write(i, { "🌿: " .. names[1] .. ": Root", "💬: child " .. i, "@@note " .. i .. "@@" })
                end
                local expanded = {}
                if expansion == "first" then expanded[paths[2]] = true end
                if expansion == "second" then expanded[paths[3]] = true end
                if expansion == "all" then expanded = nil end
                local tree = outline._build_tree_outline_items(paths[1], cfg, expanded)
                local expected = { { file = paths[1], lnum = 1 }, { file = paths[1], lnum = 5 } }
                for i = 2, 3 do
                    expected[#expected + 1] = { file = paths[1], lnum = same_line and 7 or (i + 5),
                        child_path = paths[i], inline = (same_line or i == 3) and true or nil }
                    if not expanded or expanded[paths[i]] then
                        expected[#expected + 1] = { file = paths[i], lnum = 6 }
                        expected[#expected + 1] = { file = paths[i], lnum = 7 }
                    end
                end
                local actual = {}
                for _, item in ipairs(tree) do
                    local value=item.value
                    -- Provenance accompanies locations but does not change
                    -- sibling ordering or branch destinations.
                    actual[#actual + 1]={file=value.file,lnum=value.lnum,
                        child_path=value.child_path,inline=value.inline}
                end
                assert.same(expected, actual)
                local branches = {}
                for _, item in ipairs(tree) do
                    if item.value.child_path then branches[#branches + 1] = item.display end
                end
                assert.same({ (same_line and "    " or "  ") .. "🌿 First", "    🌿 Second" }, branches)
            end)
        end
    end
end)

describe("outline question prefaces (#240)", function()
    after_each(function() vim.fn.delete(tmp .. "/" .. ROOT) end)
    it("keeps flat and tree labels, anonymous hiding and strict adjacency aligned", function()
        local lines = { "---", "topic: Root", "file: " .. ROOT, "---",
            "@@polar@@", "💬: hidden wording", "🤖: answer", "text",
            "@@_@@", "💬: hidden question", "🤖: answer", "text",
            "@@standalone@@", "", "💬: visible", "@@last@@" }
        vim.fn.writefile(lines, tmp .. "/" .. ROOT)
        local tree = outline._build_tree_outline_items(tmp .. "/" .. ROOT, cfg, {})
        table.remove(tree, 1)
        local flat = flat_items(lines)
        assert.same(normalized(flat), normalized(tree))
        assert.equals(4, #tree)
        assert.equals("  polar", tree[1].display)
        assert.equals(6, tree[1].value.lnum)
        assert.equals(5, tree[1].value.tag_lnum)
        assert.equals("  → standalone", tree[2].display)
        assert.equals("  💬: visible", tree[3].display)
        assert.equals("  → last", tree[4].display)
    end)
    it("drops a tagged trailing empty prompt and keeps inline branches beside labelled questions", function()
        local lines = { "---", "topic: Root", "file: " .. ROOT, "---",
            "@@label@@", "💬: see [🌿: Child](" .. CHILD .. ")",
            "🤖: answer", "text", "@@empty@@", "💬: " }
        vim.fn.writefile(lines, tmp .. "/" .. ROOT)
        local tree = outline._build_tree_outline_items(tmp .. "/" .. ROOT, cfg, {})
        assert.equals(3, #tree)
        assert.equals("  label", tree[2].display)
        assert.equals("question", tree[2].type)
        assert.equals(6, tree[2].value.lnum)
        assert.equals(5, tree[2].value.tag_lnum)
        assert.equals("    🌿 Child", tree[3].display)
        assert.equals(6, tree[3].value.lnum)
    end)
end)
