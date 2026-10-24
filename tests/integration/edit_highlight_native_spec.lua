-- Compare composed screen cells: named tint groups alone cannot see the
-- diagnostic underline layered above them (#428).
local Embedded = require("tests.helpers.embedded_nvim")
local arrival = require("tests.helpers.arrival")

describe("native edit highlight style", function()
    local child
    local function exec(code, ...) return child:exec(code, ...) end
    local function mode(keys, expected)
        child:input(keys)
        assert.is_true(vim.wait(arrival.MS, function()
            return child:request("nvim_get_mode").mode == expected
        end))
    end
    before_each(function()
        child = Embedded.start({ ui = { 90, 24 } })
        exec([[
            _G.before_global = vim.deepcopy(vim.diagnostic.config())
            _G.foreign = vim.api.nvim_create_namespace("other-plugin")
            vim.diagnostic.config({ underline = true, update_in_insert = true }, foreign)
            _G.before_foreign = vim.deepcopy(vim.diagnostic.config(nil, foreign))
            require("parley").setup({ repo_root = false, chat_dir = vim.fn.tempname(), state_dir = vim.fn.tempname(),
                providers = {}, api_keys = {} })
            vim.cmd("colorscheme default")
            vim.wo.number, vim.wo.relativenumber, vim.wo.cursorline = false, false, false
            vim.wo.signcolumn, vim.wo.foldcolumn, vim.wo.winbar = "yes", "0", ""
            _G.text = "changed text pair#844"
            vim.api.nvim_buf_set_lines(0, 0, -1, false, { text, "foreign diagnostic", "type here" })
            vim.api.nvim_win_set_cursor(0, { 3, 0 })
            _G.render = require("parley.skill_render")
            vim.diagnostic.set(foreign, 0, { { lnum = 1, col = 0, end_col = 7,
                message = "foreign", severity = vim.diagnostic.severity.ERROR } })
            vim.api.nvim_buf_set_extmark(0, vim.api.nvim_create_namespace("reference-control"), 0, 13,
                { end_col = #text, hl_group = "ParleyArtifactRef" })
            function _G.cell(row, col)
                vim.cmd("redraw!")
                local position = vim.fn.screenpos(0, row + 1, col + 1)
                local value = vim.api.nvim__inspect_cell(1, position.row - 1, position.col - 1)
                assert(value[1] ~= "", "sample must be on a drawn text cell")
                return value[2]
            end
        ]])
    end)
    after_each(function() if child then child:stop() end end)

    for _, case in ipairs({
        { writer = "round", kind = "add" }, { writer = "round", kind = "change" },
        { writer = "skill", kind = "add" }, { writer = "skill", kind = "change" },
        { writer = "footnote", kind = "add" },
        { writer = "round", kind = "change", custom = true },
        { writer = "round", kind = "change", custom = true, underline = true },
    }) do
        it("keeps " .. case.writer .. " " .. case.kind .. (case.underline and " custom underline" or case.custom and " custom" or " default")
            .. " attributes across native modes and diagnostic refreshes", function()
            exec([[
                local writer, kind, custom, underline = ...
                if custom then
                    vim.api.nvim_set_hl(0, "ParleyEditChange", { bg = 0x334455, bold = true, italic = true, underline = underline })
                end
                if writer == "round" then
                    render.publish_round(0, { { lnum = 0, col = 0, end_lnum = 0, end_col = #text,
                        message = "agent explanation", kind = kind } })
                    _G.refresh = function() render.rederive_round(0) end
                elseif writer == "skill" then
                    render.highlight_span(0, 0, 0, 0, #text, kind)
                    _G.refresh = function()
                        render.attach_diagnostics(0, { { pos = 1, explain = "skill explanation" } }, text)
                    end
                else
                    _G.refresh = function()
                        render.publish_footnotes(0, { { lnum = 0, col = 0, end_lnum = 0, end_col = #text,
                            term = "term", definition = "footnote explanation" } })
                    end
                end
                refresh()
            ]], case.writer, case.kind, case.custom or false, case.underline or false)
            local baseline = exec("return cell(0, 0)")
            local foreign_baseline = exec("return cell(1, 0)")
            assert.is_true(foreign_baseline.underline == true or foreign_baseline.undercurl == true)
            assert.is_not_nil(baseline.background, "the edit tint must remain visible")
            if case.custom then
                assert.equals(0x334455, baseline.background)
                assert.is_true(baseline.bold)
                assert.is_true(baseline.italic)
            end
            -- Compare first, so the regression catches the mode difference,
            -- rather than merely pinning an intended named group definition.
            for _, entry in ipairs({ { "i", "i" }, { "R", "R" }, { "v", "v" }, { "V", "V" } }) do
                mode(entry[1], entry[2])
                local effective = exec("refresh(); return cell(0, 0)")
                assert.same(baseline, effective, "refresh in mode " .. entry[2])
                assert.is_true(exec("return cell(0, 13).underline == true"), "reference underline survives")
                assert.same(foreign_baseline, exec("return cell(1, 0)"), "foreign diagnostic style survives")
                mode("<Esc>", "n")
                assert.same(baseline, exec("return cell(0, 0)"), "return to Normal")
            end
            if case.underline then assert.is_true(baseline.underline, "explicit custom style survives")
            else assert.falsy(baseline.underline, "explanations use tint, not a diagnostic underline") end
            local retained = exec([[
                local diagnostics = vim.diagnostic.get(0, { namespace = render.diag_namespace() })
                local ns = vim.diagnostic.get_namespace(render.diag_namespace())
                local signs = ns.user_data.sign_ns
                -- Setup registers a custom diagnostic handler, which Neovim
                -- adds to global options. Existing options must stay intact.
                local global_same, current = true, vim.diagnostic.config()
                for key, value in pairs(before_global) do
                    if not vim.deep_equal(value, current[key]) then global_same = false end
                end
                return { count = #diagnostics, message = diagnostics[1] and diagnostics[1].message,
                    signs = signs and #vim.api.nvim_buf_get_extmarks(0, signs, 0, -1, {}) or -1,
                    global = global_same,
                    foreign = vim.deep_equal(before_foreign, vim.diagnostic.config(nil, foreign)) }
            ]])
            assert.equals(1, retained.count)
            assert.is_not_nil(retained.message)
            assert.equals(1, retained.signs, vim.inspect(retained))
            assert.is_true(retained.global, "global diagnostic configuration")
            assert.is_true(retained.foreign, "foreign diagnostic configuration")
        end)
    end
end)
