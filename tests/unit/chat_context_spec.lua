-- #263 close round 4, BR-15. The six migrated call sites all take the happy
-- path in every existing spec; nothing entered an error branch, and the
-- invariant that JUSTIFIES the two-phase split was asserted nowhere.
--
-- That invariant is the whole reason chat_context is not a single resolve():
-- chat_respond.respond_all runs its batch precondition BETWEEN the chat check
-- and the parse, so phase 1 must be reachable without phase 2 running. If a
-- later refactor collapses the phases, a header-less chat with an active batch
-- silently starts reporting the wrong error -- and no user-facing test would
-- notice.
local Ctx = require("parley.chat_context")

--- A fake `parley` so these stay unit tests: no buffer, no window, no config.
local function fake(opts)
    return {
        not_chat = function() return opts.not_chat_reason end,
        chat_parser = { find_header_end = function() return opts.header_end end },
        parse_chat = function(lines, header_end)
            opts.parsed_with = { lines = lines, header_end = header_end }
            return { exchanges = {}, marker = "parsed" }
        end,
    }
end

local scratch

local function scratch_buf(lines)
    scratch = vim.api.nvim_create_buf(false, true)
    vim.api.nvim_buf_set_lines(scratch, 0, -1, false, lines or { "a", "b", "c" })
    vim.api.nvim_set_current_buf(scratch)
    return scratch
end

describe("chat_context phases", function()
    after_each(function()
        if scratch and vim.api.nvim_buf_is_valid(scratch) then
            vim.api.nvim_buf_delete(scratch, { force = true })
        end
        scratch = nil
    end)

    it("phase 1 refuses a non-chat and names the reason", function()
        local buf = scratch_buf()
        local handle, reason = Ctx.chat_buffer({
            buf = buf, parley = fake({ not_chat_reason = "not timestamped" }),
        })
        assert.is_nil(handle)
        assert.equals("not timestamped", reason)
    end)

    it("phase 2 refuses a buffer with no header separator", function()
        local buf = scratch_buf()
        local parley = fake({ header_end = nil })
        local handle = Ctx.chat_buffer({ buf = buf, parley = parley })
        assert.is_truthy(handle)
        local ctx, why = Ctx.parse(handle, { parley = parley })
        assert.is_nil(ctx)
        assert.equals("no_header", why)
    end)

    -- THE invariant. Phase 1 must be usable on its own, because respond_all
    -- interleaves its batch check here. Collapsing the phases is what this
    -- catches.
    it("phase 1 runs WITHOUT parsing, so a caller can interleave between them", function()
        local buf = scratch_buf()
        local opts = { not_chat_reason = nil, header_end = 2 }
        local parley = fake(opts)
        local handle = Ctx.chat_buffer({ buf = buf, parley = parley })
        assert.is_truthy(handle)
        assert.is_nil(opts.parsed_with, "chat_buffer parsed the chat; the phases have collapsed")
        -- ...and phase 2, run later, is what parses.
        Ctx.parse(handle, { parley = parley })
        assert.is_truthy(opts.parsed_with, "parse did not parse")
    end)

    it("resolve reports WHICH gate refused, so callers can phrase each one", function()
        local buf = scratch_buf()
        local _, reason, kind = Ctx.resolve({
            buf = buf, parley = fake({ not_chat_reason = "under 5 lines" }),
        })
        assert.equals("under 5 lines", reason)
        assert.equals("not_chat", kind)

        local _, why, kind2 = Ctx.resolve({ buf = buf, parley = fake({ header_end = nil }) })
        assert.equals("no_header", why)
        assert.equals("no_header", kind2)
    end)

    it("a resolved context carries every field its callers consume", function()
        local buf = scratch_buf({ "---", "topic: t", "---", "body" })
        local ctx = Ctx.resolve({ buf = buf, parley = fake({ header_end = 3 }) })
        assert.is_truthy(ctx)
        for _, field in ipairs({ "buf", "win", "file_name", "lines", "header_end",
            "parsed_chat", "cursor_line" }) do
            assert.is_truthy(ctx[field] ~= nil, "ctx is missing " .. field)
        end
        assert.equals(3, ctx.header_end)
        assert.equals(4, #ctx.lines)
        assert.equals("parsed", ctx.parsed_chat.marker)
    end)
end)
