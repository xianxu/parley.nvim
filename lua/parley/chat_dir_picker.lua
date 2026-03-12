-- Chat directory picker module for Parley.nvim
-- Provides a floating window UI for managing configured chat roots

local M = {}

local float_picker = require("parley.float_picker")

function M._build_items(plugin)
    local items = {}
    local dirs = plugin.get_chat_dirs()

    for index, dir in ipairs(dirs) do
        local is_primary = index == 1
        local display = string.format("%s %s", is_primary and "* primary" or "  extra  ", dir)
        table.insert(items, {
            dir = dir,
            display = display,
            is_primary = is_primary,
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
        title = "Parley Chat Roots  <C-n>: add  <C-d>: remove",
        items = items,
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

                        local normalized, err = plugin.add_chat_dir(dir, true)
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
                    close_fn()

                    vim.schedule(function()
                        vim.ui.input({
                            prompt = "Remove chat dir " .. item.dir .. "? [y/N] ",
                        }, function(input)
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
                                    M.chat_dir_picker(plugin, item.dir)
                                    return
                                end

                                plugin.logger.info("Removed chat dir: " .. item.dir)
                                vim.notify("Removed chat dir: " .. item.dir, vim.log.levels.INFO)
                                M.chat_dir_picker(plugin, next_dir or plugin.get_chat_dirs()[1])
                                return
                            end

                            M.chat_dir_picker(plugin, item.dir)
                        end)
                    end)
                end,
            },
        },
    })
end

return M
