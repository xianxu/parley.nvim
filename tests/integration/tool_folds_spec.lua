local exchange_model = require("parley.exchange_model")
local tool_folds = require("parley.tool_folds")

describe("tool_folds incremental manual folds", function()
    local original_buf
    local buf
    local win

    before_each(function()
        original_buf = vim.api.nvim_get_current_buf()
        buf = vim.api.nvim_create_buf(false, true)
        win = vim.api.nvim_get_current_win()
        vim.api.nvim_win_set_buf(win, buf)
        vim.api.nvim_set_option_value("foldmethod", "manual", { win = win })
        vim.api.nvim_set_option_value("foldenable", true, { win = win })
        vim.api.nvim_buf_set_lines(buf, 0, -1, false, {
            "header", "", "💬: q", "", "🤖: a", "",
            "🧠: first", "thinking", "", "plain", "tail",
        })
    end)

    after_each(function()
        tool_folds._model_provider = nil
        tool_folds._observer = nil
        if vim.api.nvim_buf_is_valid(original_buf) then
            vim.api.nvim_win_set_buf(win, original_buf)
        end
        if vim.api.nvim_buf_is_valid(buf) then
            vim.api.nvim_buf_delete(buf, { force = true })
        end
    end)

    -- #200: identity may only be installed from a model parsed from the current
    -- buffer, so a hand-built model has to be declared as this buffer's truth.
    -- These fixtures are bare block layouts with no `---` frontmatter, so the
    -- default provider cannot parse them; the seam is what the module already
    -- offers for exactly this.
    local function truth(model)
        tool_folds._model_provider = function() return model end
        return model
    end

    local function model_with(kind, size)
        local model = exchange_model.new(1)
        model:add_exchange(1)
        model:add_block(1, "agent_header", 1)
        model:add_block(1, kind, size)
        return model
    end

    -- #200: with extmark identity the LAST exchange runs to the end of the
    -- buffer, rather than stopping at its last non-empty block. Trailing prose
    -- after the final block is part of that exchange's answer, so a manual fold
    -- there is inside the span and is cleared — the same ownership contract
    -- test :57 encodes, now applying to the tail of the buffer too.
    it("clears a user fold in the last exchange's trailing prose", function()
        vim.cmd("10,11fold")
        local model = truth(model_with("thinking", 2))
        tool_folds.reconcile_exchange(buf, win, model, 1)
        tool_folds.with_exchange_update(buf, model, 1, function()
            require("parley.buffer_edit").stream_replace_at_line(buf, 7, {
                "thinking", "inserted thinking",
            })
            model:grow_block(1, 3, 1)
        end)
        vim.cmd("normal! zM")

        assert.equals(7, vim.fn.foldclosed(7))
        assert.equals(9, vim.fn.foldclosedend(7))
        assert.equals(-1, vim.fn.foldclosed(11))
    end)

    it("builds initial folds from semantic model blocks and clears user folds in the span", function()
        vim.api.nvim_buf_set_lines(buf, 0, -1, false, {
            "---", "topic: folds", "file: folds.md", "---", "",
            "💬: q", "", "🤖: [A]", "", "🧠: think", "detail", "",
            "📝: summary", "", "🔧: read id=x", "```json", "{}", "```", "",
            "📎: read id=x", "```", "ok", "```", "", "plain one", "plain two",
        })
        vim.cmd("25,26fold")

        tool_folds.apply_folds(buf)
        vim.cmd("normal! zM")

        assert.equals(10, vim.fn.foldclosed(10))
        assert.equals(11, vim.fn.foldclosedend(10))
        assert.equals(13, vim.fn.foldclosed(13))
        assert.equals(15, vim.fn.foldclosed(15))
        assert.equals(18, vim.fn.foldclosedend(15))
        assert.equals(20, vim.fn.foldclosed(20))
        assert.equals(23, vim.fn.foldclosedend(20))
        -- #200: Parley owns every fold within an exchange span, so a manual
        -- fold over the exchange's trailing prose does not survive a reconcile.
        -- (Contrast the case above, whose fold sits outside every span.)
        assert.equals(-1, vim.fn.foldclosed(25))
    end)

    -- #200: the deleter only zd'd at DESIRED start rows, so a fold anywhere
    -- else in the exchange survived forever — that is what let a drifted fold
    -- anchor on a 💬: line and persist for the whole session.
    it("clears a stale fold anywhere in the exchange, not just at a projected start", function()
        vim.api.nvim_buf_set_lines(buf, 0, -1, false, {
            "header", "", "💬: q", "", "🤖: a", "",
            "📎: read_file", "```", "b", "```", "tail",
        })
        local model = exchange_model.new(1)
        model:add_exchange(1)
        model:add_block(1, "agent_header", 1)
        model:add_block(1, "tool_result", 4)
        truth(model)
        tool_folds.reconcile_exchange(buf, win, model, 1)

        -- The shape a drifted reconcile leaves behind: a fold no projected
        -- range starts on, covering the question.
        vim.api.nvim_win_call(win, function() vim.cmd("3,6fold") end)

        tool_folds.reconcile_exchange(buf, win, model, 1)
        vim.cmd("normal! zM")

        assert.equals(-1, vim.fn.foldclosed(3))   -- 💬: must not be folded
        assert.equals(7, vim.fn.foldclosed(7))    -- 📎: folded at its own start
        assert.equals(10, vim.fn.foldclosedend(7))
    end)

    -- #200 ROOT CAUSE: reconcile treated the projection as an append list, so a
    -- model that drifted from the buffer anchored a fold on a 💬: line and
    -- nothing ever removed it (hydrate_window latches per buf/win).
    it("never anchors a fold on a user question when the model has drifted", function()
        vim.api.nvim_buf_set_lines(buf, 0, -1, false, {
            "---", "topic: t", "file: f.md", "---", "",
            "💬: first", "", "🤖: [A]", "", "📎: read_file",
            "```", "b1", "b2", "```", "", "prose", "",
            "💬: second question", "", "🤖: [A]", "",
            "📎: grep", "```", "c1", "```",
        })
        tool_folds.hydrate_window(buf, win)

        -- A model built BEFORE a mutation that bypassed with_exchange_update.
        local chat_parser = require("parley.chat_parser")
        local lines = vim.api.nvim_buf_get_lines(buf, 0, -1, false)
        local model = exchange_model.from_parsed_chat(
            chat_parser.parse_chat(lines, 4, require("parley.config")))
        require("parley.buffer_edit").insert_lines_at(buf, 16, { "x1", "x2", "x3", "x4" })

        tool_folds.reconcile_exchange(buf, win, model, 2)
        vim.cmd("normal! zM")

        local after = vim.api.nvim_buf_get_lines(buf, 0, -1, false)
        for i, line in ipairs(after) do
            if line:match("^💬:") then
                assert.message(("question folded at row %d"):format(i))
                    .equals(-1, vim.fn.foldclosed(i))
            end
        end
        -- It healed rather than merely refusing: the real 📎: is folded.
        for i, line in ipairs(after) do
            if line:match("^📎: grep") then
                assert.message(("tool result not folded at row %d"):format(i))
                    .equals(i, vim.fn.foldclosed(i))
            end
        end
    end)

    it("does not throw when drift runs a projected range past the end of the buffer", function()
        local model = exchange_model.new(1)
        model:add_exchange(1)
        model:add_block(1, "agent_header", 1)
        model:add_block(1, "tool_result", 40)  -- far past EOF

        assert.has_no.errors(function()
            tool_folds.reconcile_exchange(buf, win, model, 1)
        end)
        -- Refusing means creating nothing, not merely not crashing.
        assert.is_false(tool_folds.reconcile_exchange(buf, win, model, 1))
        for row = 1, vim.api.nvim_buf_line_count(buf) do
            assert.message(("a fold was created at row %d despite refusal"):format(row))
                .equals(0, vim.fn.foldlevel(row))
        end
    end)

    -- #200 PQ-5: chat_respond wraps EVERY streamed chunk in
    -- with_exchange_update, so reconcile runs per chunk. Clearing the span must
    -- therefore scale with the number of folds present, not with the length of
    -- the exchange — otherwise a long tool body makes streaming quadratic.
    --
    -- Asserted on the clear loop's ITERATION COUNT, not wall-clock. A timing
    -- bound measures the machine as much as the algorithm, and flaked under
    -- suite load twice — once sending the author chasing contention as if it
    -- were a regression.
    it("clears an exchange span by walking folds, not rows", function()
        local function clear_iters(body_lines)
            local lines = { "header", "", "💬: q", "", "🤖: a", "", "🔧: read id=x" }
            for i = 1, body_lines do lines[#lines + 1] = "body " .. i end
            local probe = vim.api.nvim_create_buf(false, true)
            vim.api.nvim_buf_set_lines(probe, 0, -1, false, lines)
            vim.api.nvim_win_set_buf(win, probe)
            vim.api.nvim_set_option_value("foldmethod", "manual", { win = win })
            vim.api.nvim_set_option_value("foldenable", true, { win = win })

            local model = exchange_model.new(1)
            model:add_exchange(1)
            model:add_block(1, "agent_header", 1)
            model:add_block(1, "tool_use", body_lines + 1)
            truth(model)
            tool_folds.reconcile_exchange(probe, win, model, 1)
            tool_folds.reconcile_exchange(probe, win, model, 1)
            local iters = tool_folds._last_clear_iters

            vim.api.nvim_win_set_buf(win, buf)
            vim.api.nvim_buf_delete(probe, { force = true })
            return iters
        end

        local small = clear_iters(50)
        local large = clear_iters(800)  -- 16x the rows, still exactly one fold

        assert.is_not_nil(small)
        -- A row walk would put `large` near 800. Fold-to-fold navigation makes
        -- it a small constant, independent of span.
        assert.message(("50-row span took %s iterations, 800-row span %s")
            :format(tostring(small), tostring(large))).is_true(large <= small + 2)
    end)

    -- #200 C1: widening destruction (projected start rows -> whole span) without
    -- widening verification let a drifted reconcile delete a NEIGHBOUR's fold,
    -- which nothing recreates. Note exchange 1 has no foldable block, so range
    -- verification passes vacuously — the span check is what catches this.
    it("does not destroy a neighbouring exchange's fold when its own span drifted", function()
        local lines = { "---", "topic: t", "file: f.md", "---", "",
            "💬: first", "", "🤖: [A]" }
        for i = 1, 12 do lines[#lines + 1] = "prose " .. i end
        vim.list_extend(lines, { "", "💬: second", "", "🤖: [A]", "",
            "📎: grep", "```", "c1", "```" })
        vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
        tool_folds.hydrate_window(buf, win)

        local chat_parser = require("parley.chat_parser")
        local stale = exchange_model.from_parsed_chat(chat_parser.parse_chat(
            vim.api.nvim_buf_get_lines(buf, 0, -1, false), 4, require("parley.config")))

        vim.api.nvim_buf_set_lines(buf, 8, 18, false, {})  -- bypass with_exchange_update
        tool_folds.reconcile_exchange(buf, win, stale, 1)

        local row
        for i, line in ipairs(vim.api.nvim_buf_get_lines(buf, 0, -1, false)) do
            if line:match("^📎: grep") then row = i end
        end
        assert.message("the neighbouring tool fold was destroyed by a drifted span")
            .equals(row, vim.fn.foldclosed(row))
    end)

    it("reports which half of the model drifted when it refuses", function()
        local seen
        tool_folds._observer = function(e) if e.phase == "drift" then seen = e end end

        local model = exchange_model.new(1)
        model:add_exchange(1)
        model:add_block(1, "agent_header", 1)
        model:add_block(1, "tool_result", 40)  -- anchors nowhere; past EOF

        tool_folds.reconcile_exchange(buf, win, model, 1)
        tool_folds._observer = nil

        assert.is_not_nil(seen)
        assert.equals("ranges", seen.which)
        assert.equals(1, seen.failed_index)
    end)

    -- #200 C1 round 3: an interior-only span check is not enough. A stale span
    -- can land WHOLLY INSIDE a neighbour's answer — covering that neighbour's
    -- folds while containing no question at all — so the span must also be
    -- anchored on its own question (for every exchange after the first).
    it("does not destroy a later exchange's fold when its span slid into that answer", function()
        local lines = { "---", "topic: t", "file: f.md", "---", "",
            "💬: q1", "", "🤖: [A]" }
        for i = 1, 10 do lines[#lines + 1] = "prose1 " .. i end
        vim.list_extend(lines, { "", "💬: q2", "", "🤖: [A]" })
        for i = 1, 10 do lines[#lines + 1] = "prose2 " .. i end
        vim.list_extend(lines, { "", "💬: q3", "", "🤖: [A]",
            "📎: grep", "```", "c1", "```" })
        for i = 1, 20 do lines[#lines + 1] = "tail " .. i end
        vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
        tool_folds.hydrate_window(buf, win)

        local chat_parser = require("parley.chat_parser")
        local stale = exchange_model.from_parsed_chat(chat_parser.parse_chat(
            vim.api.nvim_buf_get_lines(buf, 0, -1, false), 4, require("parley.config")))

        vim.api.nvim_buf_set_lines(buf, 5, 20, false, {})  -- slide ex2's span into ex3
        tool_folds.reconcile_exchange(buf, win, stale, 2)

        local row
        for i, line in ipairs(vim.api.nvim_buf_get_lines(buf, 0, -1, false)) do
            if line:match("^📎: grep") then row = i end
        end
        assert.message("a later exchange's fold was destroyed by a slid span")
            .equals(row, vim.fn.foldclosed(row))
    end)

    -- #200 C1 round 4: positional checks alias — they cannot tell THIS
    -- exchange's rows from another exchange's. Identity comes from extmarks
    -- that travel with edits, so the cleared region is right even when the
    -- model's remembered rows are not.
    it("clears the rows an exchange actually owns after edits the model never saw", function()
        local anchors = require("parley.exchange_anchors")
        local lines = { "---", "topic: t", "file: f.md", "---", "" }
        for e = 1, 3 do
            vim.list_extend(lines, { "💬: q" .. e, "", "🤖: [A]",
                "📎: t" .. e, "```", "x", "```", "" })
        end
        vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
        tool_folds.hydrate_window(buf, win)

        local before = { anchors.span(buf, 2, 3) }
        vim.api.nvim_buf_set_lines(buf, 5, 5, false, { "INSERTED", "LINES", "ABOVE" })
        local after = { anchors.span(buf, 2, 3) }

        assert.message("identity did not follow the edit")
            .same({ before[1] + 3, before[2] + 3 }, after)

        -- Every tool marker still folds at its own row: nothing was cleared
        -- that belonged to a neighbour.
        vim.cmd("normal! zM")
        for i, line in ipairs(vim.api.nvim_buf_get_lines(buf, 0, -1, false)) do
            if line:match("^📎:") then
                assert.message(("tool marker at %d lost its fold"):format(i))
                    .equals(i, vim.fn.foldclosed(i))
            end
        end
    end)

    -- #200 round 5: identity that cannot survive a NEW exchange is inert.
    -- hydrate_window latches per buf/win, so without a reinstall point the
    -- anchor count disagrees with the model from the first appended exchange
    -- onward and identity declines for every exchange, permanently.
    it("reinstalls identity after the chat gains an exchange", function()
        local anchors = require("parley.exchange_anchors")
        local chat_parser = require("parley.chat_parser")
        local lines = { "---", "topic: t", "file: f.md", "---", "" }
        for e = 1, 2 do
            vim.list_extend(lines, { "💬: q" .. e, "", "🤖: [A]",
                "📎: t" .. e, "```", "x", "```", "" })
        end
        vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
        tool_folds.hydrate_window(buf, win)
        local before = { anchors.span(buf, 1, 2) }
        assert.is_not_nil(before[1])

        vim.api.nvim_buf_set_lines(buf, -1, -1, false,
            { "💬: q3", "", "🤖: [A]", "📎: t3", "```", "x", "```", "" })
        local grown = exchange_model.from_parsed_chat(chat_parser.parse_chat(
            vim.api.nvim_buf_get_lines(buf, 0, -1, false), 4, require("parley.config")))
        assert.equals(3, #grown.exchanges)
        -- Stale: three exchanges in the buffer, two anchors.
        assert.is_nil(anchors.span(buf, 1, 3))

        tool_folds.reconcile_exchange(buf, win, grown, 3)

        assert.message("identity stayed inert after the chat grew")
            .same(before, { anchors.span(buf, 1, 3) })
        vim.cmd("normal! zM")
        for i, line in ipairs(vim.api.nvim_buf_get_lines(buf, 0, -1, false)) do
            if line:match("^📎:") then
                assert.message(("tool marker at %d lost its fold"):format(i))
                    .equals(i, vim.fn.foldclosed(i))
            end
        end
    end)

    -- #200 round 6: identity must only be installed from a model produced from
    -- the CURRENT buffer. A prefix-stale model (the buffer gained a trailing
    -- exchange the model never saw) passes verify_starts trivially — its starts
    -- really are ascending questions — but installs too FEW anchors, so the
    -- last one owns to end-of-buffer and its clear swallows the exchanges after
    -- it. prepare_exchange_update is the destructive path here: it clears on
    -- identity alone and never checks ranges.
    it("does not install identity from a model that stops short of the buffer", function()
        local chat_parser = require("parley.chat_parser")
        local function parse()
            return exchange_model.from_parsed_chat(chat_parser.parse_chat(
                vim.api.nvim_buf_get_lines(buf, 0, -1, false), 4,
                require("parley.config")))
        end
        local lines = { "---", "topic: t", "file: f.md", "---", "" }
        for e = 1, 2 do
            vim.list_extend(lines, { "💬: q" .. e, "", "🤖: [A]",
                "📎: t" .. e, "```", "x", "```", "" })
        end
        vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
        tool_folds.hydrate_window(buf, win)
        local stale = parse()  -- knows two exchanges

        -- The chat grows and the tail is folded from a current parse.
        vim.api.nvim_buf_set_lines(buf, -1, -1, false,
            { "💬: q3", "", "🤖: [A]", "📎: t3", "```", "x", "```", "" })
        tool_folds.apply_folds(buf, win, parse)
        vim.cmd("normal! zM")
        local tail
        for i, line in ipairs(vim.api.nvim_buf_get_lines(buf, 0, -1, false)) do
            if line:match("^📎: t3") then tail = i end
        end
        assert.equals(tail, vim.fn.foldclosed(tail))

        -- Now drive the destructive path with the prefix-stale model.
        tool_folds.with_exchange_update(buf, stale, 2, function() end)
        vim.cmd("normal! zM")

        assert.message("a prefix-stale model's identity swallowed the trailing exchange")
            .equals(tail, vim.fn.foldclosed(tail))
    end)

    -- #200 round 7: pruning an old exchange and asking again keeps the exchange
    -- COUNT unchanged while re-indexing which exchange each anchor names. A
    -- count-only identity check hands back a shifted mapping and the clear
    -- lands on a neighbour. Ordinary parley usage, so this is the shape that
    -- matters most.
    it("survives pruning one exchange and adding another", function()
        local chat_parser = require("parley.chat_parser")
        local function parse()
            return exchange_model.from_parsed_chat(chat_parser.parse_chat(
                vim.api.nvim_buf_get_lines(buf, 0, -1, false), 4,
                require("parley.config")))
        end
        local lines = { "---", "topic: t", "file: f.md", "---", "" }
        for e = 1, 3 do
            vim.list_extend(lines, { "💬: q" .. e, "", "🤖: [A]",
                "📎: t" .. e, "```", "x", "```", "" })
        end
        vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
        tool_folds.hydrate_window(buf, win)

        -- Prune exchange 1 (8 lines) and ask a new question: count unchanged.
        vim.api.nvim_buf_set_lines(buf, 5, 13, false, {})
        vim.api.nvim_buf_set_lines(buf, -1, -1, false,
            { "💬: q4", "", "🤖: [A]", "📎: t4", "```", "x", "```", "" })

        local fresh = parse()
        assert.equals(3, #fresh.exchanges)
        tool_folds.with_exchange_update(buf, fresh, #fresh.exchanges, function() end)
        vim.cmd("normal! zM")

        for i, line in ipairs(vim.api.nvim_buf_get_lines(buf, 0, -1, false)) do
            if line:match("^📎:") then
                assert.message(("%s at %d lost its fold after prune+add")
                    :format(line, i)).equals(i, vim.fn.foldclosed(i))
            end
        end
    end)

    -- #200 round 8: verification and identity use different coordinate systems.
    -- model_fits proves a range matches the buffer's TEXT; identity proves which
    -- rows the exchange owns. Neither proves they describe the SAME exchange —
    -- so a stale model's ranges could verify against a *later* exchange's
    -- markers while identity cleared this one's rows.
    it("refuses when the ranges it would create lie outside the rows it owns", function()
        local chat_parser = require("parley.chat_parser")
        local function parse()
            return exchange_model.from_parsed_chat(chat_parser.parse_chat(
                vim.api.nvim_buf_get_lines(buf, 0, -1, false), 4,
                require("parley.config")))
        end
        local lines = { "---", "topic: t", "file: f.md", "---", "" }
        for e = 1, 3 do
            vim.list_extend(lines, { "💬: q" .. e, "", "🤖: [A]",
                "📎: t" .. e, "```", "x", "```", "" })
        end
        vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
        tool_folds.hydrate_window(buf, win)
        local stale = parse()

        -- Grow exchange 1's answer by exactly one exchange's height, so the
        -- stale ranges for exchange 3 land on exchange 2's markers.
        vim.api.nvim_buf_set_lines(buf, 12, 12, false,
            { "pad1", "pad2", "pad3", "pad4", "pad5", "pad6", "pad7", "pad8" })

        tool_folds.with_exchange_update(buf, stale, 3, function() end)
        vim.cmd("normal! zM")

        for i, line in ipairs(vim.api.nvim_buf_get_lines(buf, 0, -1, false)) do
            if line:match("^📎:") then
                assert.message(("%s at %d lost its fold"):format(line, i))
                    .equals(i, vim.fn.foldclosed(i))
            end
        end
    end)

    -- The ownership contract has two halves and only one was pinned: Parley owns
    -- every fold WITHIN an exchange span, and leaves folds outside every span
    -- alone. Without this, widening the clear again would pass the suite.
    it("leaves a fold outside every exchange span untouched", function()
        local chat_parser = require("parley.chat_parser")
        local lines = { "---", "topic: t", "file: f.md", "---", "" }
        for e = 1, 2 do
            vim.list_extend(lines, { "💬: q" .. e, "", "🤖: [A]",
                "📎: t" .. e, "```", "x", "```", "" })
        end
        -- Frontmatter sits above the first exchange, so it is owned by nobody.
        vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
        tool_folds.hydrate_window(buf, win)
        vim.api.nvim_win_call(win, function() vim.cmd("1,4fold") end)

        local model = exchange_model.from_parsed_chat(chat_parser.parse_chat(
            vim.api.nvim_buf_get_lines(buf, 0, -1, false), 4,
            require("parley.config")))
        for k in ipairs(model.exchanges) do
            tool_folds.reconcile_exchange(buf, win, model, k)
        end
        vim.cmd("normal! zM")

        assert.message("a fold above every exchange was cleared")
            .equals(1, vim.fn.foldclosed(1))
        assert.equals(4, vim.fn.foldclosedend(1))
    end)

    -- #200: the whole fold suite ran only with foldenable = true, which is how
    -- a clear that silently no-ops under `nofoldenable` shipped. With it off,
    -- zj does not navigate and zD does not delete. Reachable from a user's
    -- `set nofoldenable`, `zi`, or parley's own chat_toggle_tool_folds.
    it("clears a stale fold even when folding is disabled in the window", function()
        vim.api.nvim_buf_set_lines(buf, 0, -1, false, {
            "header", "", "💬: q", "", "🤖: a", "",
            "📎: read_file", "```", "b", "```", "tail",
        })
        local model = exchange_model.new(1)
        model:add_exchange(1)
        model:add_block(1, "agent_header", 1)
        model:add_block(1, "tool_result", 4)
        truth(model)
        tool_folds.reconcile_exchange(buf, win, model, 1)
        vim.api.nvim_win_call(win, function() vim.cmd("3,6fold") end)

        vim.api.nvim_set_option_value("foldenable", false, { win = win })
        tool_folds.reconcile_exchange(buf, win, model, 1)

        -- The operator's setting must survive untouched.
        assert.is_false(vim.api.nvim_get_option_value("foldenable", { win = win }))

        vim.api.nvim_set_option_value("foldenable", true, { win = win })
        vim.cmd("normal! zM")
        assert.message("a stale fold on the question survived a nofoldenable reconcile")
            .equals(-1, vim.fn.foldclosed(3))
        assert.equals(7, vim.fn.foldclosed(7))
    end)

    it("does not deepen fold nesting when reconciling with folding disabled", function()
        vim.api.nvim_buf_set_lines(buf, 0, -1, false, {
            "header", "", "💬: q", "", "🤖: a", "",
            "📎: read_file", "```", "b", "```", "tail",
        })
        local model = exchange_model.new(1)
        model:add_exchange(1)
        model:add_block(1, "agent_header", 1)
        model:add_block(1, "tool_result", 4)
        truth(model)

        vim.api.nvim_set_option_value("foldenable", false, { win = win })
        for _ = 1, 25 do tool_folds.reconcile_exchange(buf, win, model, 1) end
        vim.api.nvim_set_option_value("foldenable", true, { win = win })

        -- One level, not one per reconcile: chat_respond reconciles per streamed
        -- chunk, so nesting growth here would compound across a whole answer.
        assert.equals(1, vim.fn.foldlevel(7))
    end)

    -- BR-25: foldtext's fallback branch is what rendered "💬: q (4 lines)" and
    -- made #200 read as ordinary text. It should announce a fold Parley would
    -- never have created, and its marker branches should follow the configured
    -- prefixes rather than a hardcoded copy.
    it("labels a fold anchored on something Parley never folds", function()
        vim.api.nvim_buf_set_lines(buf, 0, -1, false, {
            "header", "", "💬: q", "", "🤖: a", "", "🔧: read id=x", "{}", "tail",
        })
        vim.api.nvim_set_option_value("foldmethod", "manual", { win = win })
        vim.api.nvim_win_call(win, function() vim.cmd("3,5fold") end)
        vim.cmd("normal! zM")
        vim.fn.setpos(".", { 0, 3, 1, 0 })

        local text = vim.api.nvim_win_call(win, function()
            vim.v.foldstart = 3
            return tool_folds.foldtext()
        end)
        assert.matches("unexpected fold", text)

        vim.api.nvim_win_call(win, function() vim.cmd("normal! zR") vim.cmd("7,8fold") end)
        local tool_text = vim.api.nvim_win_call(win, function()
            vim.v.foldstart = 7
            vim.v.foldend = 8
            return tool_folds.foldtext()
        end)
        assert.matches("read", tool_text)
        assert.is_nil(tool_text:match("unexpected"))
    end)

    -- BR-23: prepare's `identified` flag had no reader; a diagnostic nobody
    -- asserts is a diagnostic that can quietly stop being true.
    it("reports on the prepare event whether identity was established", function()
        local seen = {}
        tool_folds._observer = function(e)
            if e.phase == "prepare" then seen[#seen + 1] = e.identified end
        end
        vim.api.nvim_buf_set_lines(buf, 0, -1, false, {
            "---", "topic: t", "file: f.md", "---", "",
            "💬: q", "", "🤖: [A]", "📎: t", "```", "x", "```", "",
        })
        tool_folds.hydrate_window(buf, win)
        local chat_parser = require("parley.chat_parser")
        local model = exchange_model.from_parsed_chat(chat_parser.parse_chat(
            vim.api.nvim_buf_get_lines(buf, 0, -1, false), 4, require("parley.config")))

        tool_folds.prepare_exchange_update(buf, model, 1)
        assert.equals(true, seen[#seen])

        -- A model claiming an exchange count the anchors do not match cannot be
        -- identified, and prepare must say so rather than clear blindly.
        model:add_exchange(1)
        tool_folds.prepare_exchange_update(buf, model, 1)
        assert.equals(false, seen[#seen])
    end)

    it("falls back rather than trusting identity across a structural change", function()
        local anchors = require("parley.exchange_anchors")
        local lines = { "---", "topic: t", "file: f.md", "---", "" }
        for e = 1, 3 do
            vim.list_extend(lines, { "💬: q" .. e, "", "🤖: [A]",
                "📎: t" .. e, "```", "x", "```", "" })
        end
        vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
        tool_folds.hydrate_window(buf, win)

        -- A model claiming a different exchange count means anchor k and model
        -- index k may describe different exchanges — exactly the aliasing this
        -- guards. Identity must decline, not guess.
        assert.is_nil(anchors.span(buf, 2, 4))
    end)

    it("reconciles a changed exchange without leaving a blank-line ghost", function()
        local model = truth(model_with("thinking", 2))
        tool_folds.reconcile_exchange(buf, win, model, 1)
        vim.cmd("normal! zM")

        local windows = tool_folds.prepare_exchange_update(buf, model, 1)
        vim.api.nvim_buf_set_lines(buf, 6, 8, false, { "📝: summary" })
        model:replace_span(1, 3, 1, { { kind = "summary", size = 1 } })
        tool_folds.finalize_exchange_update(buf, windows, model, 1)
        vim.cmd("normal! zM")

        assert.equals(7, vim.fn.foldclosed(7))
        assert.equals(7, vim.fn.foldclosedend(7))
        assert.equals(-1, vim.fn.foldclosed(8))
        assert.equals(0, vim.fn.foldlevel(8))
    end)

    it("prepares and reconciles the changed exchange in every displayed window", function()
        local model = truth(model_with("thinking", 2))
        local second_win = vim.api.nvim_open_win(buf, false, {
            relative = "editor", row = 1, col = 1, width = 30, height = 8,
            style = "minimal",
        })
        vim.api.nvim_set_option_value("foldmethod", "manual", { win = second_win })
        vim.api.nvim_set_option_value("foldenable", true, { win = second_win })
        tool_folds.reconcile_exchange(buf, win, model, 1)
        tool_folds.reconcile_exchange(buf, second_win, model, 1)

        local windows = tool_folds.prepare_exchange_update(buf, model, 1)
        vim.api.nvim_buf_set_lines(buf, 6, 8, false, { "📝: summary" })
        model:replace_span(1, 3, 1, { { kind = "summary", size = 1 } })
        tool_folds.finalize_exchange_update(buf, windows, model, 1)

        for _, target in ipairs({ win, second_win }) do
            vim.api.nvim_win_call(target, function()
                vim.cmd("normal! zM")
                assert.equals(7, vim.fn.foldclosed(7))
                assert.equals(7, vim.fn.foldclosedend(7))
                assert.equals(0, vim.fn.foldlevel(8))
            end)
        end
        vim.api.nvim_win_close(second_win, true)
    end)

    it("restores from the current buffer model without masking a mutation error", function()
        local model = truth(model_with("thinking", 2))
        local recovered = model_with("summary", 1)
        tool_folds.reconcile_exchange(buf, win, model, 1)
        local previous_provider = tool_folds._model_provider
        tool_folds._model_provider = function() return recovered end

        local ok, err = pcall(function()
            tool_folds.with_exchange_update(buf, model, 1, function()
                vim.api.nvim_buf_set_lines(buf, 6, 8, false, { "📝: summary" })
                error("write exploded")
            end)
        end)
        tool_folds._model_provider = previous_provider

        assert.is_false(ok)
        assert.matches("write exploded", err)
        vim.cmd("normal! zM")
        assert.equals(7, vim.fn.foldclosed(7))
        assert.equals(7, vim.fn.foldclosedend(7))
        assert.equals(0, vim.fn.foldlevel(8))
    end)

    it("recovers after the model changed without masking the mutation error", function()
        local model = truth(model_with("thinking", 2))
        local recovered = model_with("summary", 1)
        tool_folds.reconcile_exchange(buf, win, model, 1)
        local previous_provider = tool_folds._model_provider
        tool_folds._model_provider = function() return recovered end

        local ok, err = pcall(function()
            tool_folds.with_exchange_update(buf, model, 1, function()
                vim.api.nvim_buf_set_lines(buf, 6, 8, false, { "📝: summary" })
                model:replace_span(1, 3, 1, { { kind = "summary", size = 1 } })
                error("post-model mutation exploded")
            end)
        end)
        tool_folds._model_provider = previous_provider

        assert.is_false(ok)
        assert.matches("post%-model mutation exploded", err)
        vim.cmd("normal! zM")
        assert.equals(7, vim.fn.foldclosed(7))
        assert.equals(7, vim.fn.foldclosedend(7))
        assert.equals(0, vim.fn.foldlevel(8))
    end)

    it("ignores scheduled hydration after its target buffer is deleted", function()
        local scheduled = {}
        local original_schedule = vim.schedule
        vim.schedule = function(callback) scheduled[#scheduled + 1] = callback end
        tool_folds.setup(buf)
        vim.schedule = original_schedule

        vim.api.nvim_buf_delete(buf, { force = true })
        assert.equals(1, #scheduled)
        assert.has_no.errors(scheduled[1])
    end)

    it("hydrates a window only once from one model provider", function()
        local calls = 0
        local model = truth(model_with("thinking", 2))
        local provider = function()
            calls = calls + 1
            return model
        end

        assert.is_true(tool_folds.hydrate_window(buf, win, provider))
        assert.is_false(tool_folds.hydrate_window(buf, win, provider))
        assert.equals(1, calls)
        vim.cmd("normal! zM")
        assert.equals(7, vim.fn.foldclosed(7))
        assert.equals(8, vim.fn.foldclosedend(7))
    end)

    it("replaces a persisted orphan fold with the exact initial projection", function()
        vim.api.nvim_buf_set_lines(buf, 6, 8, false, { "📝: summary", "" })
        vim.cmd("8,8fold")
        local model = truth(model_with("summary", 1))

        assert.is_true(tool_folds.hydrate_window(buf, win, function() return model end))
        vim.cmd("normal! zM")

        assert.equals(7, vim.fn.foldclosed(7))
        assert.equals(7, vim.fn.foldclosedend(7))
        assert.equals(0, vim.fn.foldlevel(8))
    end)

    it("does not duplicate live folds when scheduled hydration runs afterward", function()
        -- #200: the model must describe the buffer it folds — verification now
        -- refuses a projection whose anchors are not really there. Give the
        -- appended tool_use block a real 🔧: marker to anchor on.
        vim.api.nvim_buf_set_lines(buf, 0, -1, false, {
            "header", "", "💬: q", "", "🤖: a", "",
            "🧠: first", "thinking", "", "🔧: read id=x", "{}",
        })
        local model = truth(model_with("thinking", 2))
        tool_folds.with_exchange_update(buf, model, 1, function()
            model:add_block(1, "tool_use", 2)
        end)

        assert.is_true(tool_folds.hydrate_window(buf, win, function() return model end))
        local ranges = require("parley.fold_projection").desired_folds(model, 1)
        assert.equals(1, vim.fn.foldlevel(ranges[1].start_0 + 1))
        assert.equals(1, vim.fn.foldlevel(ranges[2].start_0 + 1))
        assert.equals(0, vim.fn.foldlevel(ranges[2].end_0 + 2))
    end)

    it("folds recorded item rows when sections and exchanges have no gap", function()
        vim.api.nvim_buf_set_lines(buf, 0, -1, false, {
            "---", "topic: gaps", "file: gaps.md", "---", "",
            "💬: first", "", "🤖:[A]", "", "answer", "📝: first summary",
            "💬: second", "", "🤖:[A]", "", "📝: second summary", "",
        })

        tool_folds.apply_folds(buf)
        vim.cmd("normal! zM")

        assert.equals(11, vim.fn.foldclosed(11))
        assert.equals(11, vim.fn.foldclosedend(11))
        assert.equals(16, vim.fn.foldclosed(16))
        assert.equals(16, vim.fn.foldclosedend(16))
        assert.equals(0, vim.fn.foldlevel(17))
    end)

    it("keeps exactly one fold level across consecutive tool-loop appends", function()
        local model = truth(model_with("thinking", 2))
        local second_win = vim.api.nvim_open_win(buf, false, {
            relative = "editor", row = 1, col = 1, width = 30, height = 8,
            style = "minimal",
        })
        vim.api.nvim_set_option_value("foldmethod", "manual", { win = second_win })
        local events = {}
        tool_folds._observer = function(event) events[#events + 1] = event end

        require("parley.tool_loop")._append_section_to_answer(buf, model, 1, {
            kind = "tool_use", name = "read_file", id = "call_1", input = { path = "x" },
        })
        local tool_use = require("parley.fold_projection").desired_folds(model, 1)[2]
        require("parley.tool_loop")._append_section_to_answer(buf, model, 1, {
            kind = "tool_result", name = "read_file", id = "call_1", content = "ok",
        })
        tool_folds._observer = nil

        local ranges = require("parley.fold_projection").desired_folds(model, 1)
        local tool_result = ranges[3]
        assert.equals(8, #events)
        for _, event in ipairs(events) do assert.equals(1, event.exchange_index) end
        for _, target in ipairs({ win, second_win }) do
            vim.api.nvim_win_call(target, function()
                vim.cmd("normal! zM")
                assert.equals(1, vim.fn.foldlevel(tool_use.start_0 + 1))
                assert.equals(1, vim.fn.foldlevel(tool_result.start_0 + 1))
                assert.equals(0, vim.fn.foldlevel(tool_result.end_0 + 2))
            end)
        end
        vim.api.nvim_win_close(second_win, true)
    end)
end)
