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
-- error is a notification, never a stuck buffer (ARCH-ORDER). A launch
-- failure (missing executable) is a terminal path too: clipboard_image
-- settles it as `failed` rather than raising out of the spawn.
--
-- No bytes without a transcript line, in BOTH directions (C3): insertion
-- prerequisites (a valid, modifiable buffer) are checked BEFORE save, and if
-- the insert itself still fails after the save, the asset is rolled back —
-- the file removed, and the assets/<ts> and assets/ folders removed when this
-- paste created them and they are now empty (vim.fn.delete(…, "d") refuses a
-- non-empty dir, so a folder that already held assets is never touched).
--
-- deps = { config, notify(msg, level), runner? } — init.lua supplies the real
-- ones; specs pass a recording notify.

local assets = require("parley.assets")
local clipboard_image = require("parley.clipboard_image")
local buffer_edit = require("parley.buffer_edit")

local M = {}

-- buf → true while a read is in flight; cleared on every terminal path.
local inflight = {}

-- The folders `assets.save` would create for `folder` (assets/<ts> and its
-- assets/ parent) that do NOT exist yet, innermost first — what a rollback
-- may remove. nil folder (not a chat path any more) → nothing; save will
-- refuse it anyway.
local function folders_created_by(folder)
    local out = {}
    if not folder then
        return out
    end
    for _, dir in ipairs({ folder, vim.fs.dirname(folder) }) do
        if vim.fn.isdirectory(dir) ~= 1 then
            out[#out + 1] = dir
        end
    end
    return out
end

-- Undo a save whose link never landed: remove the file, then each folder this
-- paste created — "d" only removes an EMPTY directory, so a folder that
-- gained another asset meanwhile stays.
local function rollback(abs, created)
    os.remove(abs)
    for _, dir in ipairs(created) do
        vim.fn.delete(dir, "d")
    end
end

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
            -- Insertion prerequisites BEFORE saving: a closed or read-only
            -- buffer leaves no transcript line to reference the bytes, so
            -- nothing is written.
            if not vim.api.nvim_buf_is_valid(buf) then
                return finish("Parley: nothing pasted — the buffer was closed before the clipboard answered", "info")
            end
            if not vim.bo[buf].modifiable then
                return finish("Parley: nothing pasted — the buffer is not modifiable", "warn")
            end
            -- Bounded: a clipboard past the cap reads MAX_BYTES + 1 and save
            -- refuses it with too_big before touching disk.
            local bytes, read_err = assets.default_io.read(tmp, assets.MAX_BYTES + 1)
            if not bytes then
                return finish("Parley: nothing pasted — could not read the clipboard image: " .. tostring(read_err), "error")
            end
            -- The buffer's CURRENT name: a rename or move may have finished meanwhile.
            local chat_now = vim.api.nvim_buf_get_name(buf)
            local created = folders_created_by(assets.folder_for(chat_now))
            local rel, abs, save_err = assets.save(chat_now, bytes, "png")
            if not rel then
                return finish("Parley: nothing pasted — " .. save_err, "error")
            end
            local iok, ierr = pcall(function()
                local line = buffer_edit.handle_line(anchor)
                buffer_edit.insert_lines_at(buf, line + 1, { assets.markdown_link(rel) })
            end)
            if not iok then
                rollback(abs, created)
                return finish("Parley: nothing pasted — could not insert the link: " .. tostring(ierr), "error")
            end
            finish("Parley: pasted " .. rel, "info")
        end)
        if not ok then
            finish("Parley: paste failed: " .. tostring(err), "error")
        end
    end, deps.runner)
end

return M
