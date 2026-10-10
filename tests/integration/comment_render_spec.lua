-- #312: 🤖 markers render compactly through the decoration provider — the
-- chain is concealed, the anchor highlighted, a marker that doesn't close on
-- its line painted broken — in markdown and chat buffers, never inside fenced
-- code, and at a cost bounded by the viewport.
local highlighter = require("parley.highlighter")
local Document = require("parley.document")
local parley = require("parley")
local decoration = require("tests.helpers.decoration")
local scratch = vim.fn.tempname() .. "-comment-render"
parley.setup({ chat_dir = scratch, state_dir = scratch .. "/state", providers = {}, api_keys = {} })

local buf
local function setup(lines, kind)
    buf = vim.api.nvim_create_buf(false, true)
    vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
    parley._parley_bufs[buf] = kind or "markdown"
    highlighter.setup(parley)
    local doc = assert(highlighter.rebuild_structure(buf))
    assert.equals("idle", Document.drain(doc, 100000).status)
    return doc
end
local function render(first, last, doc)
    return highlighter._compute_window_decorations(0, buf, first, last, nil, doc)
end
local function find(entries, pred)
    local out = {}
    for _, e in ipairs(entries or {}) do if pred(e) then out[#out + 1] = e end end
    return out
end

describe("comment rendering (#312)", function()
    after_each(function()
        if buf and vim.api.nvim_buf_is_valid(buf) then vim.api.nvim_buf_delete(buf, { force = true }) end
    end)

    it("conceals a quoted chain and highlights the anchor in markdown", function()
        local line = "x 🤖<A>[c] y"
        local map = render(0, 0, setup({ line }))
        local quoted = find(map[0], function(e) return e.hl_group == "ParleyReviewQuoted" end)
        assert.equals(1, #quoted)
        assert.equals("A", line:sub(quoted[1].col_start + 1, quoted[1].col_end))
        local hidden = find(map[0], function(e) return e.conceal ~= nil end)
        assert.equals(2, #hidden)
        assert.equals("🤖<", line:sub(hidden[1].col_start + 1, hidden[1].col_end))
        assert.equals(">[c]", line:sub(hidden[2].col_start + 1, hidden[2].col_end))
        assert.same({}, find(map[0], function(e)
            return e.hl_group == "ParleyReviewUser" or e.hl_group == "ParleyReviewAgent"
        end))
    end)

    it("paints an unclosed marker broken, conceals nothing", function()
        local map = render(0, 0, setup({ "🤖[open" }))
        assert.equals(1, #find(map[0], function(e) return e.hl_group == "ParleyReviewBroken" end))
        assert.same({}, find(map[0], function(e) return e.conceal ~= nil end))
    end)

    it("leaves markers inside fenced code alone (markdown and chat)", function()
        for _, kind in ipairs({ "markdown", "chat" }) do
            local lines = kind == "chat" and { "💬: q", "```", "🤖[example]", "```" }
                or { "```", "🤖[example]", "```" }
            local row = #lines - 2
            local map = render(0, #lines - 1, setup(lines, kind))
            assert.same({}, find(map[row], function(e) return e.conceal ~= nil end), kind)
            vim.api.nvim_buf_delete(buf, { force = true })
        end
    end)

    it("conceals markers in chat answers too", function()
        local map = render(0, 2, setup({ "💬: q", "", "🤖: see 🤖[why]{because}" }, "chat"))
        assert.equals(2, #find(map[2], function(e) return e.conceal ~= nil end))
    end)

    -- Done-when evidence: re-render is viewport-bounded, never a whole-buffer
    -- reparse — the layout runs only for rows a frame draws (+ margin).
    it("re-render after a one-line edit stays viewport-bounded", function()
        local lines = {}
        for i = 1, 5000 do lines[i] = "line " .. i .. " 🤖<A>[c" .. i .. "]" end
        setup(lines)
        vim.api.nvim_set_current_buf(buf)
        local win = vim.api.nvim_get_current_win()
        local provider = decoration.capture_provider(parley)
        local view = require("parley.comment.view")
        local layout, calls = view.layout, 0
        view.layout = function(l) calls = calls + 1; return layout(l) end
        local ok, err = pcall(function()
            decoration.frame(provider, win, buf, 0, 40)
            local first = calls
            calls = 0
            vim.api.nvim_buf_set_lines(buf, 10, 11, false, { "edited 🤖[new]" })
            local drawn = decoration.frame(provider, win, buf, 0, 40)
            print(("#312 layout calls: first frame %d, after edit %d (buffer 5000 rows)"):format(first, calls))
            assert.is_true(first <= 41 + 20, "first frame: " .. first)
            assert.is_true(calls <= 41 + 20, "after edit: " .. calls)
            local concealed = false
            for _, d in ipairs(drawn) do
                if d.row == 10 and d.conceal == "…" then concealed = true end
            end
            assert.is_true(concealed, "edited row carries its new conceal")
        end)
        view.layout = layout
        assert.is_true(ok, tostring(err))
    end)
end)
