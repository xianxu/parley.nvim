-- #261 M2 review BR-26: `vim.fn.bufnr(name)` is a file-pattern match — it can
-- return a buffer whose name merely contains `name` (`chat.md` finds a loaded
-- `chat.md.bak`; `parley://system_prompt/foo` finds `…/foobar`, which the prompt
-- editor then force-deleted). Every lookup by name goes through
-- helper.buffer_for, which compares exact names; bufnr() with no argument, or
-- with '%' or '#', names no file and stays allowed.
--
-- The limit of this guard, stated so it is not mistaken for more: it checks by
-- spelling. It sees the first `vim.fn.bufnr(...)` on a line, when the call fits
-- on that line. The wider class — bufwinnr, bufwinid, bufname, getbufvar with a
-- name — cannot be checked statically, because their number-argument forms are
-- legitimate; those rely on review.
local arch = require("tests.arch.arch_helper")

describe("arch: buffers are looked up by exact name", function()
    it("uses helper.buffer_for, never vim.fn.bufnr(<name>)", function()
        local offenders = {}
        for _, file in ipairs(arch.worktree_files({ "lua/**/*.lua" })) do
            for n, line in ipairs(vim.fn.readfile(file)) do
                local arg = not line:match("^%s*%-%-") and line:match("vim%.fn%.bufnr%(([^)]*)%)")
                if arg and arg ~= "" and arg ~= "'%'" and arg ~= '"%"' and arg ~= "'#'" and arg ~= '"#"' then
                    offenders[#offenders + 1] = file .. ":" .. n
                end
            end
        end
        assert.same({}, offenders, "look the buffer up with helper.buffer_for(name)")
    end)
end)
