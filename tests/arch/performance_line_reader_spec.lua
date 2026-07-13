local arch = require("tests.arch.arch_helper")

describe("arch: performance-sensitive reads use LineReader", function()
    local scope = {
        "lua/parley/line_reader.lua",
        "lua/parley/highlighter.lua",
        "lua/parley/timezone_diagnostics.lua",
        "lua/parley/skill_render.lua",
        "lua/parley/spell.lua",
    }

    for _, primitive in ipairs({ "nvim_buf_get_lines", "nvim_buf_get_text", "vim.fn.getline", "nvim_get_current_line" }) do
        it("confines " .. primitive .. " to line_reader.lua", function()
            arch.assert_pattern_scoping({
                pattern = primitive,
                scope = scope,
                allow_only_in = { "lua/parley/line_reader.lua" },
                rationale = "#170: observable buffer reads flow through LineReader",
            })
        end)
    end
end)
