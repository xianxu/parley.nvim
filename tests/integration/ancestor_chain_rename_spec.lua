-- The #224 defect, at the level where it actually bites.
--
-- A fork writes its back-link the moment it is created (it must — a crash
-- otherwise orphans the child, #214 BR-19). The parent then earns a topic and
-- `ParleySlug` renames it, so the child's back-link names a file that no longer
-- exists under that name. Navigation survives, because `resolve_chat_path`
-- globs the timestamp; the ancestor walk does not, because it uses the naive
-- resolver — and the fork is submitted with NO parent context at all.
--
-- These assert on the MESSAGE LIST, not on the absence of the warning the
-- operator saw. The warning is the symptom; the missing context is the defect,
-- and a test that watches the warning would pass the moment someone silenced it.

local tmp_dir = vim.fn.tempname() .. "-parley-ancestor-rename"
local chat_dir = tmp_dir .. "/chats"
vim.fn.mkdir(chat_dir, "p")

local parley = require("parley")
parley.setup({
    chat_dir = chat_dir,
    state_dir = tmp_dir .. "/state",
    providers = {},
    api_keys = {},
})
local chat_respond = require("parley.chat_respond")

local function write_chat(basename, body)
    local path = chat_dir .. "/" .. basename
    local lines = {
        "---", "topic: T", "file: " .. basename, "model: m", "provider: openai", "---", "",
    }
    for _, l in ipairs(body) do lines[#lines + 1] = l end
    vim.fn.writefile(lines, path)
    return path
end

local function parse(path)
    local lines = vim.fn.readfile(path)
    local he = parley.chat_parser.find_header_end(lines)
    return parley.chat_parser.parse_chat(lines, he, parley.config)
end

local function contents(msgs)
    local out = {}
    for _, m in ipairs(msgs or {}) do out[#out + 1] = tostring(m.content or "") end
    return table.concat(out, "\n")
end

describe("ancestor chain across a parent slug rename (#224)", function()
    -- The parent is created bare and renamed once it earns a topic; the child's
    -- back-link still names the pre-rename file. This IS the on-disk state the
    -- operator reported.
    -- The child gets its OWN timestamp, as a real fork does. The first version
    -- of this helper appended "-child" to the parent's stamp, so both parsed to
    -- the same timestamp: the resolver matched the child as its own parent and
    -- the walk recursed to the depth cap. A fixture that shares an identity key
    -- tests the collision path, not the rename path.
    local function fork_with_renamed_parent(pstamp, cstamp)
        local pre = pstamp .. ".md"
        local post = pstamp .. "_light-lag.md"
        local kid_name = cstamp .. "_child.md"
        write_chat(post, {
            -- The 🤖: prefix LINE is not captured; only its continuation
            -- lines are (tests/unit/parse_chat_spec.lua:203). A fixture that
            -- puts the answer on the marker line asserts against an empty
            -- string and looks like a product bug.
            "💬: what is light lag?", "",
            "🤖:[A]", "the delay between an event and seeing it", "",
            "💬: and simultaneity?", "",
            "🤖:[A]", "there is no universal now", "",
            "🌿: " .. kid_name .. ": Child",
        })
        local kid = write_chat(kid_name, {
            "🌿: " .. pre .. ": Light lag",   -- names the PRE-rename parent
            "", "💬: child question", "", "🤖:[A]", "child answer",
        })
        return kid, post
    end

    it("carries the parent conversation into the fork's messages", function()
        local kid = fork_with_renamed_parent("2026-09-09.08-00-00.001", "2026-09-09.08-05-00.002")
        local msgs = chat_respond._collect_ancestor_messages(kid, parse(kid))
        local text = contents(msgs)

        assert.is_true(#msgs > 0, "the fork was submitted with NO parent context")
        assert.is_truthy(text:match("what is light lag"),
            "the parent's question is missing from the fork's context:\n" .. text)
        assert.is_truthy(text:match("delay between an event"),
            "the parent's answer is missing from the fork's context:\n" .. text)
    end)

    it("sets branch_after when the CHILD was renamed", function()
        -- The second site, same cause: the parent's branch line names the child,
        -- and matching it back uses the same resolver. A wrong answer here
        -- truncates the parent at exchange 0 even when the parent resolves.
        --
        -- The first version of this test wrote the parent's branch line as the
        -- child's ACTUAL on-disk name, so the naive resolver handled it fine and
        -- the test passed with the fix reverted (#224 BR-2). The child has to be
        -- renamed for this to assert anything: the parent's 🌿: line names the
        -- pre-slug basename, the child on disk carries the slug.
        local pstamp, cstamp = "2026-09-09.08-10-00.001", "2026-09-09.08-15-00.002"
        write_chat(pstamp .. "_parent.md", {
            "💬: p q1", "", "🤖:[A]", "p a1", "",
            "💬: p q2", "", "🤖:[A]", "p a2", "",
            "🌿: " .. cstamp .. ".md: Child",   -- names the child PRE-rename
        })
        local kid = write_chat(cstamp .. "_child-earned-a-topic.md", {
            "🌿: " .. pstamp .. "_parent.md: Parent",
            "", "💬: child q", "", "🤖:[A]", "child a",
        })
        local chain = chat_respond._collect_ancestor_chain(kid, parse(kid))

        assert.equals(1, #chain, "expected exactly one ancestor")
        assert.is_true(chain[1].branch_after > 0,
            "branch_after is " .. tostring(chain[1].branch_after)
            .. " — a renamed CHILD fails the parent-branch match, so the parent "
            .. "is truncated at exchange 0")
    end)

    it("resolves a reference that names a file outside the chat roots", function()
        -- #224 BR-1: glob-first resolution searched base_dir and the chat roots
        -- but NOT the reference's own directory, so an absolute reference lost
        -- to an unrelated same-timestamp file in a chat root — silently the
        -- wrong chat, which is this issue's failure mode from the other side.
        local archive = tmp_dir .. "/archive"
        vim.fn.mkdir(archive, "p")
        local stamp = "2026-09-09.09-00-00.001"
        local target = archive .. "/" .. stamp .. ".md"
        vim.fn.writefile({ "archived" }, target)
        write_chat(stamp .. "_unrelated-live-topic.md", { "💬: q", "", "🤖:[A]", "a" })

        local got = parley.resolve_chat_path(target, chat_dir)
        assert.equals(vim.fn.resolve(target), vim.fn.resolve(got),
            "resolved to a same-timestamp file elsewhere instead of the one named")
    end)

    it("the <M-t> tree reaches the parent when the parent was renamed", function()
        -- #224 BR-2: the Plan row claiming this was ticked with no behavioural
        -- test behind it — reverting all three outline.lua call sites failed
        -- only the arch guard. The Spec calls this site a VERIFIED live defect,
        -- so its fix needs a regression test, not a structural one.
        local pstamp, cstamp = "2026-09-09.14-00-00.001", "2026-09-09.14-05-00.002"
        write_chat(pstamp .. "_light-lag.md", {
            "💬: parent q", "", "🤖:[A]", "parent a", "",
            "🌿: " .. cstamp .. "_child.md: Child",
        })
        local kid = write_chat(cstamp .. "_child.md", {
            "🌿: " .. pstamp .. ".md: Light lag",   -- names the PRE-rename parent
            "", "💬: child q", "", "🤖:[A]", "child a",
        })

        -- `_find_tree_root`, not `_build_tree_outline_items`: the latter builds
        -- DOWNWARD from whatever path it is handed, so it can never see a
        -- broken parent lookup. Driving it is what let this claim ship
        -- unbacked in the first place.
        local outline = require("parley.outline")
        local root = outline._find_tree_root(kid, parley.config)

        assert.equals(vim.fn.resolve(chat_dir .. "/" .. pstamp .. "_light-lag.md"),
            vim.fn.resolve(root),
            "the tree root is the CHILD — a naive resolver bails on the "
            .. "unreadable pre-rename name and makes the child its own root")

        -- and the built tree from that root actually contains the parent
        local items = outline._build_tree_outline_items(root, parley.config)
        local rendered = {}
        for _, it in ipairs(items or {}) do rendered[#rendered + 1] = tostring(it.display or "") end
        local text = table.concat(rendered, "\n")
        assert.is_truthy(text:find("parent q", 1, true),
            "the parent's exchanges never appear in the tree:\n" .. text)
    end)

    it("still works when the parent was never renamed", function()
        -- The control. If this ever goes red, the fix broke the common case.
        local stamp, cstamp = "2026-09-09.08-20-00.001", "2026-09-09.08-25-00.002"
        write_chat(stamp .. ".md", {
            "💬: plain parent question", "", "🤖:[A]", "plain parent answer", "",
            "🌿: " .. cstamp .. "_child.md: Child",
        })
        local kid = write_chat(cstamp .. "_child.md", {
            "🌿: " .. stamp .. ".md: Parent", "", "💬: q", "", "🤖:[A]", "a",
        })
        local text = contents(chat_respond._collect_ancestor_messages(kid, parse(kid)))
        assert.is_truthy(text:match("plain parent question"), text)
    end)
end)
