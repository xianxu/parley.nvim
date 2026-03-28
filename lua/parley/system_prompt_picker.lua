-- System prompt picker module for Parley.nvim
-- Provides a floating window UI for selecting, editing, creating, renaming, and deleting system prompts

local M = {}

local float_picker = require("parley.float_picker")
local custom_prompts = require("parley.custom_prompts")

-- Build the sorted item list from a plugin state. Exposed for testing.
function M._build_items(plugin)
    local items = {}
    for _, prompt_name in ipairs(plugin._system_prompts) do
        local prompt = plugin.system_prompts[prompt_name]

        local description = prompt.system_prompt:gsub("\n", " "):gsub("%s+", " ")
        if #description > 80 then
            description = description:sub(1, 80) .. "..."
        end

        local source = custom_prompts.source(prompt_name, plugin._builtin_system_prompts or {})
        local source_tag = source == "builtin" and "" or " [" .. source .. "]"

        local is_current = prompt_name == plugin._state.system_prompt
        local display = (is_current and "✓ " or "  ") .. prompt_name .. source_tag .. " - " .. description

        table.insert(items, {
            name = prompt_name,
            display = display,
            is_current = is_current,
            source = source,
        })
    end

    -- Current prompt first, then alphabetical
    table.sort(items, function(a, b)
        if a.is_current then
            return true
        end
        if b.is_current then
            return false
        end
        return a.name < b.name
    end)

    return items
end

--- Refresh M.system_prompts and M._system_prompts after a custom prompt change.
local function refresh_prompts(plugin)
    -- Restore builtins, then overlay custom prompts
    plugin.system_prompts = vim.deepcopy(plugin._builtin_system_prompts or {})
    local user_prompts = custom_prompts.load()
    for name, prompt in pairs(user_prompts) do
        if type(prompt) == "table" and prompt.system_prompt then
            plugin.system_prompts[name] = prompt
        end
    end
    plugin._system_prompts = {}
    for name, _ in pairs(plugin.system_prompts) do
        table.insert(plugin._system_prompts, name)
    end
    table.sort(plugin._system_prompts)
end

--- Open a scratch buffer to edit a system prompt's text.
--- On save (via BufWriteCmd), persists to custom_system_prompts.json.
---@param plugin table  the main parley module
---@param prompt_name string  name of the prompt to edit
---@param on_done function|nil  callback after save
function M.edit_prompt(plugin, prompt_name, on_done)
    local prompt = plugin.system_prompts[prompt_name]
    if not prompt then
        vim.notify("System prompt not found: " .. prompt_name, vim.log.levels.WARN)
        return
    end

    local buf_name = "parley://system_prompt/" .. prompt_name

    -- Reuse existing buffer if it's still around, otherwise create new
    local buf = vim.fn.bufnr(buf_name)
    if buf ~= -1 and vim.api.nvim_buf_is_valid(buf) then
        -- Wipe the stale buffer so we start fresh
        vim.api.nvim_buf_delete(buf, { force = true })
    end

    buf = vim.api.nvim_create_buf(false, true)
    vim.api.nvim_buf_set_name(buf, buf_name)
    vim.bo[buf].buftype = "acwrite"
    vim.bo[buf].filetype = "markdown"
    vim.bo[buf].buflisted = true
    vim.bo[buf].modified = false

    -- Set initial content
    local lines = vim.split(prompt.system_prompt, "\n")
    vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
    vim.bo[buf].modified = false

    -- BufWriteCmd: save content back to custom prompts
    vim.api.nvim_create_autocmd("BufWriteCmd", {
        buffer = buf,
        callback = function()
            local content = table.concat(vim.api.nvim_buf_get_lines(buf, 0, -1, false), "\n")
            custom_prompts.set(prompt_name, { system_prompt = content })
            refresh_prompts(plugin)
            vim.bo[buf].modified = false
            plugin.logger.info("System prompt saved: " .. prompt_name)
            vim.notify("System prompt saved: " .. prompt_name, vim.log.levels.INFO)
            if on_done then
                on_done()
            end
        end,
    })

    vim.api.nvim_set_current_buf(buf)
end

-- Create a floating picker to select a system prompt
function M.system_prompt_picker(plugin)
    local items = M._build_items(plugin)
    local keybindings_key = (plugin.config.global_shortcut_keybindings or { shortcut = "<C-g>?" }).shortcut
    float_picker.open({
        title = "💬 System Prompts  <C-e>: edit  <C-n>: new  <C-d>: delete  <C-r>: rename",
        items = items,
        anchor = "top",
        on_select = function(item)
            plugin.refresh_state({ system_prompt = item.name })
            plugin.logger.info("System prompt set to: " .. item.name)
            vim.cmd("doautocmd User ParleySystemPromptChanged")
        end,
        mappings = {
            -- Edit selected prompt
            {
                key = "<C-e>",
                fn = function(item, close_fn)
                    if not item then
                        return
                    end
                    close_fn()
                    vim.schedule(function()
                        M.edit_prompt(plugin, item.name)
                    end)
                end,
            },
            -- Create new custom prompt
            {
                key = "<C-n>",
                fn = function(_, close_fn, context)
                    context.skip_focus_restore = true
                    context.suspend_for_external_ui()
                    vim.ui.input({ prompt = "New system prompt name: " }, function(name)
                        context.resume_after_external_ui()
                        if not name or name == "" then
                            context.focus_prompt()
                            return
                        end
                        if plugin.system_prompts[name] then
                            vim.notify("System prompt already exists: " .. name, vim.log.levels.WARN)
                            context.focus_prompt()
                            return
                        end
                        close_fn()
                        custom_prompts.set(name, { system_prompt = "" })
                        refresh_prompts(plugin)
                        vim.schedule(function()
                            M.edit_prompt(plugin, name)
                        end)
                    end)
                end,
            },
            -- Delete custom prompt / restore modified builtin
            {
                key = "<C-d>",
                fn = function(item, close_fn, context)
                    if not item then
                        return
                    end
                    local source = item.source
                    if source == "builtin" then
                        vim.notify("Cannot delete built-in prompt: " .. item.name, vim.log.levels.WARN)
                        return
                    end

                    local action = source == "modified" and "Restore to default" or "Delete"
                    context.skip_focus_restore = true
                    context.suspend_for_external_ui()
                    vim.ui.input({
                        prompt = action .. " '" .. item.name .. "'? (y/n): ",
                    }, function(answer)
                        context.resume_after_external_ui()
                        if answer ~= "y" then
                            context.focus_prompt()
                            return
                        end
                        custom_prompts.remove(item.name)
                        refresh_prompts(plugin)
                        -- If deleted prompt was active, fall back
                        if plugin._state.system_prompt == item.name and source == "custom" then
                            plugin.refresh_state({ system_prompt = "default" })
                        end
                        close_fn()
                        vim.schedule(function()
                            M.system_prompt_picker(plugin)
                        end)
                    end)
                end,
            },
            -- Rename custom prompt
            {
                key = "<C-r>",
                fn = function(item, close_fn, context)
                    if not item then
                        return
                    end
                    if item.source == "builtin" then
                        vim.notify("Cannot rename built-in prompt: " .. item.name, vim.log.levels.WARN)
                        return
                    end
                    context.skip_focus_restore = true
                    context.suspend_for_external_ui()
                    vim.ui.input({
                        prompt = "Rename '" .. item.name .. "' to: ",
                        default = item.name,
                    }, function(new_name)
                        context.resume_after_external_ui()
                        if not new_name or new_name == "" or new_name == item.name then
                            context.focus_prompt()
                            return
                        end
                        if plugin.system_prompts[new_name] then
                            vim.notify("Name already taken: " .. new_name, vim.log.levels.WARN)
                            context.focus_prompt()
                            return
                        end
                        local ok = custom_prompts.rename(item.name, new_name)
                        if ok then
                            refresh_prompts(plugin)
                            if plugin._state.system_prompt == item.name then
                                plugin.refresh_state({ system_prompt = new_name })
                            end
                            close_fn()
                            vim.schedule(function()
                                M.system_prompt_picker(plugin)
                            end)
                        else
                            vim.notify("Rename failed", vim.log.levels.ERROR)
                            context.focus_prompt()
                        end
                    end)
                end,
            },
            -- Keybindings help
            {
                key = keybindings_key,
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
