-- Read-repair, on its one trigger (#224).
--
-- Repair used to live inside `resolve_chat_path`, so navigating rewrote files
-- you might not have open. Under prefix identity a slug-stale reference
-- resolves correctly forever, which makes repair cosmetic — and the operator
-- chose a single explicit trigger: the cursor entering the link.
--
-- Every guard gets its own arm, because "it didn't rewrite" is satisfied by a
-- guard firing for the WRONG reason just as well as the right one.

local tmp_dir = vim.fn.tempname() .. "-parley-read-repair"
local chat_dir = tmp_dir .. "/chats"
vim.fn.mkdir(chat_dir, "p")

local parley = require("parley")
parley.setup({
    chat_dir = chat_dir,
    state_dir = tmp_dir .. "/state",
    providers = {},
    api_keys = {},
})

local function write_chat(basename, body)
    local lines = {
        "---", "topic: T", "file: " .. basename, "model: m", "provider: openai", "---", "",
    }
    for _, l in ipairs(body or {}) do lines[#lines + 1] = l end
    vim.fn.writefile(lines, chat_dir .. "/" .. basename)
    return chat_dir .. "/" .. basename
end

-- Open `path`, put the cursor on the line matching `needle`, return buf + lnum.
local function open_at(path, needle)
    vim.cmd("silent! %bwipeout!")
    vim.cmd("edit " .. vim.fn.fnameescape(path))
    local buf = vim.api.nvim_get_current_buf()
    for i, l in ipairs(vim.api.nvim_buf_get_lines(buf, 0, -1, false)) do
        if l:find(needle, 1, true) then
            vim.api.nvim_win_set_cursor(0, { i, 0 })
            return buf, i
        end
    end
    error("fixture line not found: " .. needle)
end

local function line_at(buf, lnum)
    return vim.api.nvim_buf_get_lines(buf, lnum - 1, lnum, false)[1]
end

local function modified(buf)
    return vim.api.nvim_get_option_value("modified", { buf = buf })
end

local counter = 0
-- A child whose back-link names the parent's PRE-rename filename.
local function stale_pair()
    counter = counter + 1
    local pstamp = ("2026-09-09.10-%02d-00.001"):format(counter)
    local cstamp = ("2026-09-09.11-%02d-00.002"):format(counter)
    write_chat(pstamp .. "_earned-a-topic.md", { "💬: q", "", "🤖:[A]", "a" })
    local kid = write_chat(cstamp .. "_child.md", {
        "🌿: " .. pstamp .. ".md: Parent",
        "", "💬: child q", "", "🤖:[A]", "child a",
    })
    return kid, pstamp
end

describe("read-repair on cursor entry", function()
    it("rewrites a stale reference in the BUFFER", function()
        local kid, pstamp = stale_pair()
        local buf, lnum = open_at(kid, "🌿:")

        assert.is_true(parley.repair_reference_at_cursor(buf, lnum))
        assert.is_truthy(line_at(buf, lnum):find(pstamp .. "_earned-a-topic.md", 1, true),
            "reference not repaired: " .. line_at(buf, lnum))
        assert.is_true(modified(buf), "a repair should be an undoable buffer edit")
    end)

    it("does not write the file behind your back", function()
        -- The property that motivated moving the trigger: repair edits the
        -- buffer you are looking at, never a file on disk.
        local kid = stale_pair()
        local before = table.concat(vim.fn.readfile(kid), "\n")
        local buf, lnum = open_at(kid, "🌿:")
        parley.repair_reference_at_cursor(buf, lnum)

        assert.equals(before, table.concat(vim.fn.readfile(kid), "\n"),
            "the file on disk changed; repair must be a buffer edit")
    end)

    it("is a no-op on a current reference, and leaves `modified` untouched", function()
        local stamp = "2026-09-09.12-00-00.001"
        write_chat(stamp .. "_parent.md", { "💬: q", "", "🤖:[A]", "a" })
        local kid = write_chat("2026-09-09.12-05-00.002_child.md", {
            "🌿: " .. stamp .. "_parent.md: Parent", "", "💬: q", "", "🤖:[A]", "a",
        })
        local buf, lnum = open_at(kid, "🌿:")
        local before = line_at(buf, lnum)

        assert.is_false(parley.repair_reference_at_cursor(buf, lnum))
        assert.equals(before, line_at(buf, lnum))
        assert.is_false(modified(buf), "a no-op must not dirty the buffer")
    end)

    it("does nothing on a line with no reference", function()
        local kid = stale_pair()
        local buf, lnum = open_at(kid, "child q")
        assert.is_false(parley.repair_reference_at_cursor(buf, lnum))
        assert.is_false(modified(buf))
    end)

    it("repairs an inline [🌿:…](file) link too", function()
        local pstamp = "2026-09-09.13-00-00.001"
        write_chat(pstamp .. "_topic.md", { "💬: q", "", "🤖:[A]", "a" })
        local kid = write_chat("2026-09-09.13-05-00.002_child.md", {
            "💬: q", "", "🤖:[A]", "see [🌿:that](" .. pstamp .. ".md) above",
        })
        local buf, lnum = open_at(kid, "[🌿:that]")

        assert.is_true(parley.repair_reference_at_cursor(buf, lnum))
        assert.is_truthy(line_at(buf, lnum):find(pstamp .. "_topic.md", 1, true),
            "inline link not repaired: " .. line_at(buf, lnum))
    end)

    it("skips a buffer that is not a chat file", function()
        local md = tmp_dir .. "/plain.md"
        vim.fn.writefile({ "# Doc", "", "🌿: 2026-01-01.00-00-00.001.md: X" }, md)
        local buf, lnum = open_at(md, "🌿:")
        assert.is_false(parley.repair_reference_at_cursor(buf, lnum))
        assert.is_false(modified(buf))
    end)

    it("skips while the buffer is busy", function()
        -- A streaming response is a concurrent writer, and chat_lease
        -- invalidates on concurrent mutation. It IGNORES rather than queues —
        -- the next CursorHold retries for free.
        local kid = stale_pair()
        local buf, lnum = open_at(kid, "🌿:")
        local before = line_at(buf, lnum)

        local real = parley.tasker.is_busy
        parley.tasker.is_busy = function() return true end
        local repaired = parley.repair_reference_at_cursor(buf, lnum)
        parley.tasker.is_busy = real

        assert.is_false(repaired)
        assert.equals(before, line_at(buf, lnum))
        -- and it retries once the buffer is free, rather than having consumed
        -- its one chance
        assert.is_true(parley.repair_reference_at_cursor(buf, lnum))
    end)

    it("the resolver itself performs no repair", function()
        -- Resolution is a READ. This is the property the trigger move bought.
        local kid, pstamp = stale_pair()
        local before = table.concat(vim.fn.readfile(kid), "\n")
        local resolved = parley.resolve_chat_path(pstamp .. ".md", chat_dir)
        vim.wait(60, function() return false end)   -- outlive any vim.schedule

        assert.is_truthy(resolved:find("_earned-a-topic.md", 1, true), resolved)
        assert.equals(before, table.concat(vim.fn.readfile(kid), "\n"),
            "resolve_chat_path rewrote the referring file")
    end)
end)
