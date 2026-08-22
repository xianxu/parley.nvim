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
-- Single point of definition for where the real corpus comes from. Not an
-- injection seam — nothing outside this file can replace it — but it keeps the
-- git dependency in one place, and the tracked fixtures below are listed
-- explicitly so they do not depend on git or cwd at all.
local function corpus_provider()
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
    -- fold_assistant_first.md pins #200 C1 round 2: chat_parser fabricates a
    -- question block when an answer has no preceding 💬: (chat_parser.lua:623),
    -- so exchange_start lands on a blank line. Requiring a question anchor
    -- there refused such transcripts permanently. Every other corpus file and
    -- fixture starts with 💬:, so nothing else covers this shape.
    local corpus = {
        "tests/fixtures/fold_tool_transcript.md",
        "tests/fixtures/fold_assistant_first.md",
        -- M2's adversarial shapes: structural markers inside tool bodies, a
        -- shorter fence nested in a longer one, and a summary marker that is
        -- content. The real corpus contains none of these (the audit found 0),
        -- so without this fixture nothing exercises the M2 defects.
        "tests/fixtures/fold_adversarial.md",
        -- BR-43's shape: a marker quoted inside an ordinary fenced block. The
        -- adversarial fixture covers nesting but none of the shapes that
        -- actually broke, so this one carries the raw-text oracle's teeth.
        "tests/fixtures/fold_marker_in_prose.md",
    }
    for _, path in ipairs(corpus_provider()) do
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
            -- RAW-TEXT ORACLE. The model-derived checks above enumerate their
            -- subjects from the same parse the folder used, so a defect that
            -- makes the parser DROP an exchange hides itself: the lost
            -- question is simply never a subject, and the file reports
            -- violations=0. That is exactly how #200 M2 shipped a folded
            -- question (BR-43) past this harness. This sweep reads the buffer
            -- text instead, so it sees questions the parser lost.
            --
            -- A `💬:` at column 0 that is NOT inside a fenced body must never
            -- be folded, whatever the parse thinks.
            local body_rows = require("parley.fence").scan(lines, function(l)
                local k = require("parley.highlight_structure")
                    .classify(l, require("parley.highlight_structure").patterns(
                        require("parley.config"))).kind
                return k == "tool_use" or k == "tool_result"
            end)
            for row, text in ipairs(lines) do
                if text:match("^💬:") and not body_rows[row] then
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
