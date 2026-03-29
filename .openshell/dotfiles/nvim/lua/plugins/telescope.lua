-- Telescope fuzzy finding (all the things)
return {
    {
        "nvim-telescope/telescope.nvim",
        branch = "0.1.x",
        dependencies = {
            "nvim-lua/plenary.nvim",
            -- Fuzzy Finder Algorithm which requires local dependencies to be built. Only load if `make` is available
            { "nvim-telescope/telescope-fzf-native.nvim", build = "make", cond = vim.fn.executable("make") == 1 },
        },
        config = function()
            require("telescope").setup({
                defaults = {
                    mappings = {
                        i = {
                            ["<C-u>"] = false,
                            ["<C-d>"] = false,
                        },
                    },
                    vimgrep_arguments = {
                        "rg",
                        "--color=never",
                        "--no-heading",
                        "--with-filename",
                        "--line-number",
                        "--column",
                        "--smart-case",
                    }
                },
                pickers = {
                    find_files = { previewer = false },
                    buffers = { previewer = false },
                    live_grep = { previewer = true },       -- <<< disable Grep Preview
                    grep_string = { previewer = true },     -- <<< disable Grep Preview
                    oldfiles = { previewer = false },
                },
                extensions = {
                    frecency = {
                        -- your other frecency settings...
                        show_scores = true,
                        ignore_patterns = { "*.git/*", "*/tmp/*", "*/.DS_Store" },
                        previewer = true,
                    },
                },
            })

            -- patch to skip unknown file type error
            local utils = require("telescope.previewers.utils")
            utils.highlighter = function(bufnr, ft)
                local ok = pcall(function()
                    vim.treesitter.language.get_lang(ft)
                    vim.treesitter.highlighter.new(bufnr, ft)
                end)
            if not ok then
                    vim.bo[bufnr].syntax = ft
                end
            end

            -- Enable telescope fzf native, if installed
            pcall(require("telescope").load_extension, "fzf")

            local map = require("helpers.keys").map
            map("n", "<leader>fr", require("telescope.builtin").oldfiles, "Recently opened")
            map("n", "<leader><space>", require("telescope.builtin").buffers, "Open buffers")
            map("n", "<leader>/", function()
                -- You can pass additional configuration to telescope to change theme, layout, etc.
                require("telescope.builtin").current_buffer_fuzzy_find(require("telescope.themes").get_dropdown({
                    winblend = 10,
                    previewer = false,
                }))
                end, "Search in current buffer")

            map("n", "<leader>sf", require("telescope.builtin").find_files, "Files")
            map("n", "<leader>sh", require("telescope.builtin").help_tags, "Help")
            map("n", "<leader>sw", require("telescope.builtin").grep_string, "Current word")
            map("n", "<leader>sg", require("telescope.builtin").live_grep, "Grep")
            map("n", "<leader>sd", require("telescope.builtin").diagnostics, "Diagnostics")

            map("n", "<C-p>", require("telescope.builtin").keymaps, "Search keymaps")
        end,
    },
}
