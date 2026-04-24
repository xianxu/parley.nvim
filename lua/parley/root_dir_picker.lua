-- parley.root_dir_picker — generic floating picker for managing root directories
-- Used by chat_dir_picker and note_dir_picker via parameterized calls.

local M = {}

local float_picker = require("parley.float_picker")
local root_dirs = require("parley.root_dirs")

function M.build_items(get_roots_fn)
    local items = {}
    local roots = get_roots_fn()

    for _, root in ipairs(roots) do
        local display = string.format(
            "%s [%s] %s",
            root.is_primary and "* primary" or "  extra  ",
            root.label,
            root.dir
        )
        table.insert(items, {
            dir = root.dir,
            label = root.label,
            display = display,
            is_primary = root.is_primary,
        })
    end

    return items
end

local function item_index_by_dir(items, dir)
    if not dir or dir == "" then
        return nil
    end

    local resolved = vim.fn.resolve(vim.fn.expand(dir)):gsub("/+$", "")
    for index, item in ipairs(items) do
        local candidate = vim.fn.resolve(vim.fn.expand(item.dir)):gsub("/+$", "")
        if candidate == resolved then
            return index
        end
    end

    return nil
end

--- Open a root directory picker.
--- @param opts table
---   plugin        — parley module reference
---   title         — picker title (e.g. "Parley Chat Roots")
---   domain        — human name for prompts (e.g. "chat", "note")
---   get_roots     — function() returning roots array
---   get_dirs      — function() returning dirs array
---   add_dir       — function(dir, persist, label)
---   remove_dir    — function(dir, persist)
---   rename_dir    — function(dir, label, persist)
---   base_dir_key  — config key for base dir protection (e.g. "base_chat_dir"); optional
---   reopen        — function(initial_dir) to reopen this picker
---   initial_dir   — dir to highlight initially; optional
function M.open(opts)
    local plugin = opts.plugin
    local items = M.build_items(opts.get_roots)

    float_picker.open({
        title = opts.title or (opts.domain .. " Roots  <C-n>: add  <C-r>: label  <C-d>: remove"),
        items = items,
        anchor = "top",
        initial_index = item_index_by_dir(items, opts.initial_dir) or 1,
        on_select = function()
        end,
        mappings = {
            {
                key = "<C-n>",
                fn = function(_, close_fn)
                    close_fn()
                    vim.schedule(function()
                        local dir = vim.fn.input({
                            prompt = "Add " .. opts.domain .. " dir: ",
                            default = vim.fn.getcwd() .. "/",
                            completion = "dir",
                        })
                        vim.cmd("redraw")

                        if not dir or dir == "" then
                            opts.reopen(opts.initial_dir)
                            return
                        end

                        local default_label = vim.fn.fnamemodify(vim.fn.resolve(vim.fn.expand(dir)), ":t")
                        vim.ui.input({
                            prompt = "Label for " .. opts.domain .. " dir (optional): ",
                            default = default_label,
                        }, function(label)
                            local final_label = label
                            if final_label == nil or final_label == "" then
                                final_label = default_label
                            end

                            local normalized, err = opts.add_dir(dir, true, final_label)
                            if not normalized then
                                vim.notify("Failed to add " .. opts.domain .. " dir: " .. err, vim.log.levels.WARN)
                                opts.reopen(opts.initial_dir)
                                return
                            end

                            local added_dir = normalized[#normalized]
                            plugin.logger.info("Added " .. opts.domain .. " dir: " .. added_dir)
                            vim.notify("Added " .. opts.domain .. " dir: " .. added_dir, vim.log.levels.INFO)
                            opts.reopen(added_dir)
                        end)
                    end)
                end,
            },
            {
                key = "<C-r>",
                fn = function(item, _, context)
                    if not item then
                        return
                    end

                    if item.is_primary then
                        vim.notify("Use config to rename the primary " .. opts.domain .. " directory label", vim.log.levels.WARN)
                        return
                    end

                    context.skip_focus_restore = true
                    context.suspend_for_external_ui()

                    vim.schedule(function()
                        vim.ui.input({
                            prompt = "Label for " .. opts.domain .. " dir: ",
                            default = item.label or vim.fn.fnamemodify(item.dir, ":t"),
                        }, function(label)
                            context.resume_after_external_ui()
                            if label == nil then
                                context.focus_prompt()
                                return
                            end

                            local normalized, err = opts.rename_dir(item.dir, label, true)
                            if not normalized then
                                vim.notify("Failed to rename " .. opts.domain .. " dir label: " .. err, vim.log.levels.WARN)
                                context.focus_prompt()
                                return
                            end

                            opts.reopen(item.dir)
                        end)
                    end)
                end,
            },
            {
                key = "<C-d>",
                fn = function(item, close_fn, context)
                    if not item then
                        return
                    end

                    if item.is_primary then
                        vim.notify("Cannot remove the primary " .. opts.domain .. " directory", vim.log.levels.WARN)
                        return
                    end
                    if opts.base_dir_key and plugin.config[opts.base_dir_key] then
                        local r_item = root_dirs.resolve_dir_key(item.dir)
                        local r_base = root_dirs.resolve_dir_key(plugin.config[opts.base_dir_key])
                        if r_item == r_base then
                            vim.notify("Cannot remove the base " .. opts.domain .. " directory", vim.log.levels.WARN)
                            return
                        end
                    end

                    context.skip_focus_restore = true
                    context.suspend_for_external_ui()

                    vim.schedule(function()
                        vim.ui.input({
                            prompt = "Remove " .. opts.domain .. " dir " .. item.dir .. "? [y/N] ",
                        }, function(input)
                            context.resume_after_external_ui()
                            local next_dir = nil
                            for _, dir in ipairs(opts.get_dirs()) do
                                if dir ~= item.dir then
                                    next_dir = dir
                                    break
                                end
                            end

                            if input and input:lower() == "y" then
                                local normalized, err = opts.remove_dir(item.dir, true)
                                if not normalized then
                                    vim.notify("Failed to remove " .. opts.domain .. " dir: " .. err, vim.log.levels.WARN)
                                    context.focus_prompt()
                                    return
                                end

                                close_fn()
                                plugin.logger.info("Removed " .. opts.domain .. " dir: " .. item.dir)
                                vim.notify("Removed " .. opts.domain .. " dir: " .. item.dir, vim.log.levels.INFO)
                                opts.reopen(next_dir or opts.get_dirs()[1])
                                return
                            end

                            context.focus_prompt()
                        end)
                    end)
                end,
            },
            {
                key = (plugin.config.global_shortcut_keybindings or { shortcut = "<C-g>?" }).shortcut,
                fn = function(_, _)
                    vim.schedule(function()
                        plugin.cmd.KeyBindings()
                    end)
                end,
            },
        },
    })
end

return M
