-- Architecture tests for buffer mutation boundaries.
--
-- See docs/plans/000090-renderer-refactor.md sections 5 + 8.
--
-- The `nvim_buf_set_lines` baseline allow list starts wide (every file
-- currently calling it on `main`) and tightens through Phases 2 and 3
-- of the refactor. After Phase 3 the only allowed file will be
-- `lua/parley/buffer_edit.lua`.

local arch = require("tests.arch.arch_helper")

describe("arch: buffer mutation boundary", function()
    it("nvim_buf_set_lines callers (baseline)", function()
        arch.assert_pattern_scoping({
            pattern = "nvim_buf_set_lines",
            scope = "lua/parley/**/*.lua",
            allow_only_in = {
                -- ============================================================
                -- Chat buffer rendering pipeline — narrowed through #90 phases.
                -- After Phase 3, ONLY buffer_edit.lua remains in this group.
                -- ============================================================
                "lua/parley/buffer_edit.lua",   -- THE intended home (added Phase 1)
                -- chat_respond.lua removed in Phase 2 (all sites migrated)
                "lua/parley/dispatcher.lua",     -- removed in Phase 3
                "lua/parley/tool_loop.lua",      -- removed in Phase 3

                -- ============================================================
                -- Picker UIs and orthogonal helpers — deferred to a follow-up.
                -- These files create their own scratch buffers for picker UIs
                -- and have nothing to do with the chat buffer rendering bug
                -- that motivated #90. Migrating them through buffer_edit is
                -- desirable for consistency but is YAGNI for this issue.
                -- ============================================================
                "lua/parley/chat_finder.lua",
                "lua/parley/config.lua",
                "lua/parley/exchange_clipboard.lua",
                "lua/parley/float_picker.lua",
                "lua/parley/highlighter.lua",
                "lua/parley/init.lua",
                "lua/parley/issues.lua",
                "lua/parley/system_prompt_picker.lua",
                "lua/parley/vision.lua",
            },
            rationale = "#90: buffer mutation must flow through buffer_edit.lua (baseline scope; tightens through phases)",
        })
    end)

    it("nvim_buf_set_text callers", function()
        arch.assert_pattern_scoping({
            pattern = "nvim_buf_set_text",
            scope = "lua/parley/**/*.lua",
            allow_only_in = {},
            rationale = "#90: nvim_buf_set_text must only be used via buffer_edit.lua",
        })
    end)
end)

describe("arch: pure files have no nvim state interaction", function()
    local PURE_FILES = {
        "lua/parley/tools/types.lua",
        "lua/parley/tools/serialize.lua",
        "lua/parley/tools/init.lua",
    }
    for _, forbidden in ipairs({ "vim%.api%.", "vim%.cmd", "vim%.schedule", "vim%.defer_fn" }) do
        it("pure files: no " .. forbidden, function()
            arch.assert_pattern_scoping({
                pattern = forbidden,
                is_pattern = true,
                scope = PURE_FILES,
                allow_only_in = {},
                rationale = "designated pure data transforms; no nvim state interaction",
            })
        end)
    end
end)
