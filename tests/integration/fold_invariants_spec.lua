local tool_folds = require("parley.tool_folds")
local projection = require("parley.fold_projection")

-- #200: the two invariants, measured on real Neovim fold state over the in-repo
-- transcript corpus. A cold parse must never fold a question, and must always
-- fold a tool call / tool result / summary / thinking block at its own marker.
--
-- The oracle walks the PARSED MODEL, not the raw file text. A regex sweep would
-- assert `foldclosed(i) == i` for every 📎:-looking line, including one inside a
-- tool body — where it is content, correctly living inside the enclosing fold.
-- Only question line_starts and foldable block starts are subjects here.
-- Seam mirroring tool_folds' _model_provider / _observer pattern: the corpus
-- source is injectable, so this does not hard-depend on cwd or git-on-PATH.
local M_corpus_provider = function()
    return vim.fn.systemlist("git ls-files 'workshop/parley/*.md'")
end

describe("fold invariants over the repo transcript corpus", function()
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

    -- Tracked files only: a filesystem glob makes the suite's shape depend on
    -- the working tree (untracked drafts). A tracked file can still be deleted
    -- but unstaged, so drop what is not readable — and floor the count, so a
    -- wholesale disappearance fails loudly instead of shrinking the suite to
    -- nothing and reporting green.
    -- The real corpus carries zero tool blocks (measured: thinking 20,
    -- summary 20, question 46, text 38, agent_header 38, tool_use 0,
    -- tool_result 0), so on its own this harness cannot exercise the issue's
    -- headline 🔧:/📎: case at all. A tracked fixture supplies that shape.
    local corpus = { "tests/fixtures/fold_tool_transcript.md" }
    for _, path in ipairs(M_corpus_provider()) do
        if vim.fn.filereadable(path) == 1 then corpus[#corpus + 1] = path end
    end

    it("finds a corpus to check", function()
        assert.message(("only %d readable transcripts under workshop/parley/")
            :format(#corpus)).is_true(#corpus >= 8)
    end)

    for _, path in ipairs(corpus) do
        it("holds both invariants for " .. vim.fn.fnamemodify(path, ":t"), function()
            local lines = vim.fn.readfile(path)
            local chat_parser = require("parley.chat_parser")
            local header_end = chat_parser.find_header_end(lines)
            if not header_end then return end  -- not a chat transcript

            local buf = vim.api.nvim_create_buf(false, true)
            vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
            vim.api.nvim_win_set_buf(win, buf)
            vim.api.nvim_set_option_value("foldenable", true, { win = win })
            tool_folds.hydrate_window(buf, win)
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
            -- A parser/format change must not turn this file green-and-empty.
            assert.message(("%s asserted nothing — parse produced no subjects"):format(path))
                .is_true(checked > 0)
            vim.api.nvim_buf_delete(buf, { force = true })
        end)
    end
end)
