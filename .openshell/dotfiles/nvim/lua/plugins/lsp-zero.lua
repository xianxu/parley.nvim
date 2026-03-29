return {
  {
    "VonHeikemen/lsp-zero.nvim",
    branch = "v3.x",
    dependencies = {
      "neovim/nvim-lspconfig",
      "williamboman/mason.nvim",
      "williamboman/mason-lspconfig.nvim",
    },
    config = function()
      local lsp = require("lsp-zero")

      lsp.on_attach(function(_, bufnr)
        local map = function(mode, lhs, rhs)
          vim.keymap.set(mode, lhs, rhs, { buffer = bufnr })
        end
        map("n", "gd", vim.lsp.buf.definition)
        map("n", "K", vim.lsp.buf.hover)
        map("n", "<leader>rn", vim.lsp.buf.rename)
      end)

      require("mason").setup()
      require("mason-lspconfig").setup({
        ensure_installed = { "pyright", "solargraph", "ts_ls" },
        handlers = {
          ts_ls = function()
            require("lspconfig").ts_ls.setup({
              settings = {
                typescript = {
                  inlayHints = {
                    includeInlayParameterNameHints = "all",
                    includeInlayFunctionParameterTypeHints = true,
                    includeInlayVariableTypeHints = true,
                    includeInlayPropertyDeclarationTypeHints = true,
                    includeInlayFunctionLikeReturnTypeHints = true,
                    includeInlayEnumMemberValueHints = true,
                  },
                },
                javascript = {
                  inlayHints = {
                    includeInlayParameterNameHints = "all",
                    includeInlayFunctionParameterTypeHints = true,
                    includeInlayVariableTypeHints = true,
                    includeInlayPropertyDeclarationTypeHints = true,
                    includeInlayFunctionLikeReturnTypeHints = true,
                    includeInlayEnumMemberValueHints = true,
                  },
                },
              },
            })
          end,
          pyright = function()
            local lspconfig = require("lspconfig")

            local root = vim.fs.dirname(vim.fs.find({ ".git", "pyrightconfig.json" }, { upward = true })[1])
            local project_venv = root .. "/.venv"
            local src_path = root .. "/src"

            lspconfig.pyright.setup({
              root_dir = root,
              settings = {
                python = {
                  venvPath = root,
                  venv = ".venv",
                  analysis = {
                    autoSearchPaths = true,
                    useLibraryCodeForTypes = true,
                    diagnosticMode = "workspace",
                    extraPaths = { src_path },
                  },
                },
              },
            })
          end,
          solargraph = function()
            require("lspconfig").solargraph.setup({})
          end,
        },
      })

      lsp.setup()
    end,
  },
}
