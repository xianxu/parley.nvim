local tool_folds = require("parley.tool_folds")
local projection = require("parley.fold_projection")

-- #200: the two invariants, measured on real Neovim fold state over the in-repo
-- synthetic transcript corpus. A cold parse must never fold a question, and must always
-- fold a tool call / tool result / summary / thinking block at its own marker.
--
-- The oracle walks the PARSED MODEL, not the raw file text. A regex sweep would
-- assert `foldclosed(i) == i` for every 📎:-looking line, including one inside a
-- tool body — where it is content, correctly living inside the enclosing fold.
-- Only question line_starts and foldable block starts are subjects here.
-- #252: fixed synthetic inputs keep coverage independent of workshop cleanup,
-- Git availability, and personal conversation content.
describe("fold invariants over dedicated transcript fixtures", function()
    local original_buf, win

    before_each(function()
        original_buf = vim.api.nvim_get_current_buf()
        win = vim.api.nvim_get_current_win()
    end)

    after_each(function()
        if vim.api.nvim_buf_is_valid(original_buf) then
            vim.api.nvim_win_set_buf(win, original_buf)
        end
    end)

    local corpus = {
        "tests/fixtures/fold_tool_transcript.md",
        "tests/fixtures/fold_assistant_first.md",
        "tests/fixtures/fold_adversarial.md",
        "tests/fixtures/fold_marker_in_prose.md",
        "tests/fixtures/fold_multi_exchange.md",
    }

    it("has every dedicated fixture available", function()
        assert.equals(5, #corpus)
        for _, path in ipairs(corpus) do
            assert.equals(1, vim.fn.filereadable(path), "missing fixture: " .. path)
        end
    end)

    for _, path in ipairs(corpus) do
        it("holds both invariants for " .. vim.fn.fnamemodify(path, ":t"), function()
            local lines = vim.fn.readfile(path)
            local chat_parser = require("parley.chat_parser")
            local header_end = chat_parser.find_header_end(lines)
            assert.is_not_nil(header_end, "fixture must have a chat header: " .. path)

            local buf = vim.api.nvim_create_buf(false, true)
            vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
            vim.api.nvim_win_set_buf(win, buf)
            vim.api.nvim_set_option_value("foldenable", true, { win = win })
            tool_folds.hydrate_window(buf, win)
            local document = require("parley.document")
            assert.equals("idle", document.drain(document.get(buf)).status)
            assert.equals("idle", tool_folds.flush(buf))
            vim.api.nvim_win_call(win, function() vim.cmd("normal! zM") end)

            local model = require("parley.exchange_model").from_parsed_chat(
                chat_parser.parse_chat(lines, header_end, require("parley.config")))

            local checked = 0
            for k, exchange in ipairs(model.exchanges) do
                local q_row = model:exchange_start(k) + 1
                checked = checked + 1
                assert.message(("question folded at %s:%d"):format(path, q_row))
                    .equals(-1, vim.fn.foldclosed(q_row))

                for b, block in ipairs(exchange.blocks) do
                    -- Read the policy from its owner rather than restating it.
                    if block.size > 0 and projection.is_foldable(block.kind) then
                        local row = model:block_start(k, b) + 1
                        checked = checked + 1
                        assert.message(("%s block not folded at its own start, %s:%d")
                            :format(block.kind, path, row))
                            .equals(row, vim.fn.foldclosed(row))
                    end
                end
            end
            -- RAW-TEXT ORACLE. The model-derived checks above enumerate their
            -- subjects from the same parse the folder used, so a defect that
            -- makes the parser DROP an exchange hides itself: the lost question
            -- is never a subject and the file reports violations=0. That is how
            -- a folded question shipped past this harness (#200 BR-43).
            --
            -- Subject selection here deliberately uses NOTHING from the code
            -- under test — not fence.scan, not highlight_structure. A filter
            -- computed from the artifact exonerates exactly the rows that
            -- artifact got wrong, which is the same circularity in a new place
            -- (BR-54). This is a literal backtick-run tracker, independent by
            -- construction: it is allowed to be cruder than the real grammar,
            -- because being cruder only makes it check MORE rows.
            local depth, open_len = 0, nil
            for row, text in ipairs(lines) do
                local ticks = text:match("^(`+)")
                if depth == 0 and ticks and #ticks >= 3 then
                    depth, open_len = 1, #ticks
                elseif depth == 1 and ticks and #ticks == open_len
                    and text:match("^`+%s*$") then
                    depth, open_len = 0, nil
                elseif depth == 0 and text:match("^💬:") then
                    checked = checked + 1
                    assert.message(("raw sweep: question folded at %s:%d")
                        :format(path, row)).equals(-1, vim.fn.foldclosed(row))
                end
            end

            -- A parser/format change must not turn this file green-and-empty.
            assert.message(("%s asserted nothing — parse produced no subjects"):format(path))
                .is_true(checked > 0)
            vim.api.nvim_buf_delete(buf, { force = true })
        end)
    end
end)
