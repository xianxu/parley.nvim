-- comment/init.lua — attach 🤖 marker behavior to a buffer (#312).
--
-- Markers render in full (#386): nothing is concealed, so there is no cursor
-- snap. What stays is <CR> on a marker opening its thread, and the buffer's
-- conceallevel. Creates nothing durable: the map is buffer-local.

local M = {}

-- conceallevel by buffer kind (#386). A markdown buffer shows its text
-- literally, links included. A chat buffer keeps 2 for parley's own compact
-- view (inline branch links, model-header params); 2, not 3, which would drop
-- their replacement chars. Treesitter's markdown link conceal follows it.
local CONCEALLEVEL = { markdown = 0, chat = 2 }

--- @param buf number
--- @param kind "chat"|"markdown"
function M.attach(buf, kind)
    -- conceallevel is window-local, so re-applied on every attach (BufEnter).
    vim.opt_local.conceallevel = assert(CONCEALLEVEL[kind], "comment.attach: unknown buffer kind")
    if vim.b[buf].parley_comment_attached then return end
    vim.b[buf].parley_comment_attached = true
    -- <CR> on a marker opens its thread; elsewhere it stays native. Declared
    -- in keybinding_registry.native_overrides (a wrapped native key, like `*`)
    -- and, like every parley map, absent under default_keymaps = false.
    local parley = package.loaded["parley"]
    local keymaps_on = not (parley and parley.config and parley.config.default_keymaps == false)
    if keymaps_on then vim.keymap.set("n", "<CR>", function()
        if not require("parley.comment.float").open_thread(buf) then
            local keys = (vim.v.count > 0 and tostring(vim.v.count) or "") .. "<CR>"
            vim.api.nvim_feedkeys(vim.keycode(keys), "n", false)
        end
    end, { buffer = buf, desc = "Parley: open 🤖 comment thread (#312)" }) end
end

return M
