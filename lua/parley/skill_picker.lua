-- skill_picker.lua — Skill picker UI: <C-g>s entry point.
--
-- Opens a float picker for selecting a skill and its arguments.
-- Multi-step: select skill → select arg1 → select arg2 → run.
-- Each step closes and reopens the picker with new items.

local M = {}

local _parley

M.setup = function(parley)
    _parley = parley
end

local function open_arg_picker(buf, skill, args, arg_index)
    _parley = _parley or require("parley")
    local skill_runner = require("parley.skill_runner")
    local float_picker = _parley.float_picker

    -- All args collected — run the skill
    if not skill.args or arg_index > #skill.args then
        skill_runner.run(buf, skill, args)
        return
    end

    local arg_def = skill.args[arg_index]
    if not arg_def or not arg_def.complete then
        skill_runner.run(buf, skill, args)
        return
    end

    local values = arg_def.complete()
    local items = {}
    for _, v in ipairs(values) do
        table.insert(items, {
            display = v,
            search_text = v,
            value = v,
        })
    end

    local title = skill.name .. " [" .. (arg_def.description or arg_def.name) .. "]"

    float_picker.open({
        title = title,
        items = items,
        on_select = function(item)
            args[arg_def.name] = item.value
            -- Open next arg picker or run
            vim.schedule(function()
                open_arg_picker(buf, skill, args, arg_index + 1)
            end)
        end,
        on_cancel = function() end,
        anchor = "bottom",
    })
end

M.open = function()
    _parley = _parley or require("parley")
    local skill_runner = require("parley.skill_runner")
    local float_picker = _parley.float_picker

    local skills = skill_runner.list_skills()
    local buf = vim.api.nvim_get_current_buf()

    local items = {}
    for _, skill in ipairs(skills) do
        table.insert(items, {
            display = skill.name .. " — " .. skill.description,
            search_text = skill.name .. " " .. skill.description,
            value = skill,
        })
    end

    float_picker.open({
        title = "Skills",
        items = items,
        on_select = function(item)
            local skill = item.value
            vim.schedule(function()
                if not skill.args or #skill.args == 0 then
                    skill_runner.run(buf, skill, {})
                else
                    open_arg_picker(buf, skill, {}, 1)
                end
            end)
        end,
        on_cancel = function() end,
        anchor = "bottom",
    })
end

return M
