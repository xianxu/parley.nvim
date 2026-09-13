-- lua/parley/paste_image.lua
--
-- The <M-v> flow (#231, decision 12): read the clipboard image through
-- clipboard_image, save it through assets (THE writer), insert the link on
-- its own line after the cursor line. Asynchronous and anchored: the cursor
-- line is captured as an extmark handle before the spawn, so typing meanwhile
-- cannot misplace the link; the editor never blocks. One paste per buffer at
-- a time; a closed buffer discards the image — no bytes without a transcript
-- line. The chat path is re-read at completion so a rename or move that
-- finished meanwhile is honoured. The cursor row comes from the CURRENT
-- window, which the key guarantees is showing `buf`. In insert mode the key
-- does NOT stopinsert (helper.set_keymap does not, unlike register_global):
-- the row is still the right one, and a stopinsert here would pull the cursor
-- left — leave it.
--
-- Every terminal path clears the in-flight mark, removes the temp file and
-- notifies (ARCH-FUNERAL); the whole completion runs under pcall so a Lua
-- error is a notification, never a stuck buffer (ARCH-ORDER).
--
-- deps = { config, notify(msg, level), runner? } — init.lua supplies the real
-- ones; specs pass a recording notify.

local assets = require("parley.assets")
local clipboard_image = require("parley.clipboard_image")
local buffer_edit = require("parley.buffer_edit")

local M = {}

-- buf → true while a read is in flight; cleared on every terminal path.
local inflight = {}

--- Paste the clipboard image into the chat shown in `buf`.
--- @param buf integer
--- @param deps table { config, notify, runner? }
function M.paste(buf, deps)
    local chat_path = vim.api.nvim_buf_get_name(buf)
    local folder, ferr = assets.folder_for(chat_path)
    if not folder then
        deps.notify("Parley: image paste needs a timestamp-named chat (" .. ferr .. ")", "warn")
        return
    end
    if inflight[buf] then
        deps.notify("Parley: a paste is already in progress for this buffer", "info")
        return
    end
    local cfg = deps.config.assets or {}
    local recipe, rerr = clipboard_image.select(cfg.clipboard_cmd, clipboard_image.host_env())
    if not recipe then
        deps.notify("Parley: " .. rerr, "warn")
        return
    end

    local row = vim.api.nvim_win_get_cursor(0)[1]
    local anchor = buffer_edit.make_handle(buf, row - 1)
    local tmp = vim.fn.tempname() .. ".png"
    inflight[buf] = true

    local function finish(msg, level)
        inflight[buf] = nil
        os.remove(tmp)
        buffer_edit.handle_invalidate(anchor) -- safe after the buffer is gone
        deps.notify(msg, level)
    end

    clipboard_image.read_png(recipe, tmp, function(status, msg)
        local ok, err = pcall(function()
            if status ~= "ok" then
                return finish("Parley: nothing pasted — " .. msg, status == "no_image" and "info" or "warn")
            end
            -- Validity BEFORE saving: a closed buffer leaves no transcript line
            -- to reference the bytes, so nothing is written.
            if not vim.api.nvim_buf_is_valid(buf) then
                return finish("Parley: nothing pasted — the buffer was closed before the clipboard answered", "info")
            end
            -- Bounded: a clipboard past the cap reads MAX_BYTES + 1 and save
            -- refuses it with too_big before touching disk.
            local bytes, read_err = assets.default_io.read(tmp, assets.MAX_BYTES + 1)
            if not bytes then
                return finish("Parley: nothing pasted — could not read the clipboard image: " .. tostring(read_err), "error")
            end
            -- The buffer's CURRENT name: a rename or move may have finished meanwhile.
            local rel, _, save_err = assets.save(vim.api.nvim_buf_get_name(buf), bytes, "png")
            if not rel then
                return finish("Parley: nothing pasted — " .. save_err, "error")
            end
            local line = buffer_edit.handle_line(anchor)
            buffer_edit.insert_lines_at(buf, line + 1, { assets.markdown_link(rel) })
            finish("Parley: pasted " .. rel, "info")
        end)
        if not ok then
            finish("Parley: paste failed: " .. tostring(err), "error")
        end
    end, deps.runner)
end

return M
