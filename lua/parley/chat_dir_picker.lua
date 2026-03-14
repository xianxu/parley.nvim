-- Chat directory picker module for Parley.nvim
-- Provides a floating window UI for managing configured chat roots

local M = {}

local float_picker = require("parley.float_picker")

function M._build_items(plugin)
    local items = {}
    local roots = plugin.get_chat_roots()

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

function M.chat_dir_picker(plugin, initial_dir)
    local items = M._build_items(plugin)

    float_picker.open({
        title = "Parley Chat Roots  <C-n>: add  <C-r>: label  <C-d>: remove",
        items = items,
        anchor = "top",
        initial_index = item_index_by_dir(items, initial_dir) or 1,
        on_select = function()
        end,
        mappings = {
            {
                key = "<C-n>",
                fn = function(_, close_fn)
                    close_fn()
                    vim.schedule(function()
                        local dir = vim.fn.input({
                            prompt = "Add chat dir: ",
                            default = vim.fn.getcwd() .. "/",
                            completion = "dir",
                        })
                        vim.cmd("redraw")

                        if not dir or dir == "" then
                            M.chat_dir_picker(plugin, initial_dir)
                            return
                        end

                        local default_label = vim.fn.fnamemodify(vim.fn.resolve(vim.fn.expand(dir)), ":t")
                        vim.ui.input({
                            prompt = "Label for chat dir (optional): ",
                            default = default_label,
                        }, function(label)
                            local final_label = label
                            if final_label == nil or final_label == "" then
                                final_label = default_label
                            end

                            local normalized, err = plugin.add_chat_dir(dir, true, final_label)
                            if not normalized then
                                vim.notify("Failed to add chat dir: " .. err, vim.log.levels.WARN)
                                M.chat_dir_picker(plugin, initial_dir)
                                return
                            end

                            local added_dir = normalized[#normalized]
                            plugin.logger.info("Added chat dir: " .. added_dir)
                            vim.notify("Added chat dir: " .. added_dir, vim.log.levels.INFO)
                            M.chat_dir_picker(plugin, added_dir)
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
                        vim.notify("Use config to rename the primary chat directory label", vim.log.levels.WARN)
                        return
                    end

                    context.skip_focus_restore = true
                    context.suspend_for_external_ui()

                    vim.schedule(function()
                        vim.ui.input({
                            prompt = "Label for chat dir: ",
                            default = item.label or vim.fn.fnamemodify(item.dir, ":t"),
                        }, function(label)
                            context.resume_after_external_ui()
                            if label == nil then
                                context.focus_prompt()
                                return
                            end

                            local normalized, err = plugin.rename_chat_dir(item.dir, label, true)
                            if not normalized then
                                vim.notify("Failed to rename chat dir label: " .. err, vim.log.levels.WARN)
                                context.focus_prompt()
                                return
                            end

                            M.chat_dir_picker(plugin, item.dir)
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
                        vim.notify("Cannot remove the primary chat directory", vim.log.levels.WARN)
                        return
                    end

                    context.skip_focus_restore = true
                    context.suspend_for_external_ui()

                    vim.schedule(function()
                        vim.ui.input({
                            prompt = "Remove chat dir " .. item.dir .. "? [y/N] ",
                        }, function(input)
                            context.resume_after_external_ui()
                            local next_dir = nil
                            for _, dir in ipairs(plugin.get_chat_dirs()) do
                                if dir ~= item.dir then
                                    next_dir = dir
                                    break
                                end
                            end

                            if input and input:lower() == "y" then
                                local normalized, err = plugin.remove_chat_dir(item.dir, true)
                                if not normalized then
                                    vim.notify("Failed to remove chat dir: " .. err, vim.log.levels.WARN)
                                    context.focus_prompt()
                                    return
                                end

                                close_fn()
                                plugin.logger.info("Removed chat dir: " .. item.dir)
                                vim.notify("Removed chat dir: " .. item.dir, vim.log.levels.INFO)
                                M.chat_dir_picker(plugin, next_dir or plugin.get_chat_dirs()[1])
                                return
                            end

                            context.focus_prompt()
                        end)
                    end)
                end,
            },
        },
    })
end

return M
