-- Opt-in live check (#384): frontmatter typeahead against the REAL nvim-cmp in
-- your own Neovim config, the conformance side of the stub in
-- tests/integration/frontmatter_enum_popup_spec.lua. One menu must open
-- (cmp's), holding only the value; Vim's popup must stay closed.
--
--   nvim --headless -c "luafile scripts/check-frontmatter-cmp.lua" </dev/null
--
-- Exits 0 on pass, 1 on a mismatch, 2 when nvim-cmp isn't installed. This
-- checkout's lua/ goes first on the runtimepath, so the code under test is the
-- working tree's, not the installed plugin's.
local root = vim.fn.fnamemodify(debug.getinfo(1, "S").source:sub(2), ":p:h:h")
vim.opt.rtp:prepend(root)
-- Reload only the modules under test; the installed plugin's other modules
-- are already wired into this session and must stay as they are.
for _, name in ipairs({ "parley.frontmatter_enum", "parley.skills.review.collaboration" }) do
    package.loaded[name] = nil
end

local function finish(code, message)
    io.stdout:write(message .. "\n")
    vim.cmd((code == 0 and "qa!" or ("cquit " .. code)))
end

local ok, cmp = pcall(require, "cmp")
if not ok then return finish(2, "skip: nvim-cmp is not installed in this config") end

local dir = vim.fn.tempname()
vim.fn.mkdir(dir, "p")
local file = dir .. "/note.md"
vim.fn.writefile({ "---", "collaboration-mode: ", "---", "", "body discussion discussing dialog" }, file)
vim.o.swapfile = false
vim.cmd("edit " .. vim.fn.fnameescape(file))
require("parley.frontmatter_enum").attach(vim.api.nvim_get_current_buf())
vim.api.nvim_win_set_cursor(0, { 2, 0 })
vim.api.nvim_feedkeys("A", "n", false)
vim.defer_fn(function() vim.api.nvim_feedkeys("di", "n", false) end, 800)
vim.defer_fn(function()
    local labels = {}
    for _, entry in ipairs(cmp.get_entries() or {}) do labels[#labels + 1] = entry:get_completion_item().label end
    vim.fn.delete(dir, "rf")
    local got = ("pumvisible=%d cmp_menu=%s entries=%s"):format(vim.fn.pumvisible(),
        tostring(cmp.core.view:visible()), table.concat(labels, ","))
    if vim.fn.pumvisible() == 0 and cmp.core.view:visible() and #labels == 1 and labels[1] == "discussion" then
        finish(0, "pass: " .. got)
    else
        finish(1, "FAIL (want pumvisible=0 cmp_menu=true entries=discussion): " .. got)
    end
end, 2000)
