-- Fancier statusline
return {
	"nvim-lualine/lualine.nvim",
	config = function()
		local colorscheme = require("helpers.colorscheme")
		local lualine_theme = colorscheme == "default" and "auto" or colorscheme
		require("lualine").setup({
			options = {
				icons_enabled = true,
				theme = lualine_theme,
				component_separators = "|",
				section_separators = "",
			},
			sections = {
				lualine_c = {
					{ 
						'filename',
						path = 1, 
						fmt = function(str)
							local parts = {}
							for part in string.gmatch(str, "[^/]+") do
								table.insert(parts, part)
							end
							local n = #parts
							if n >= 2 then
								return ".../" .. parts[n-1] .. "/" .. parts[n]
							else
								return str
							end
						end,
					},  -- shows relative file path
					{
						function()
							local cwd = vim.fn.getcwd()
							local home = vim.env.HOME
							if cwd:sub(1, #home) == home then
								cwd = "~" .. cwd:sub(#home + 1)
							end
							return " " .. cwd
						end
					},
				},
			},
		})
	end,
}
