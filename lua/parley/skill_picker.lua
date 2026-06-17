-- skill_picker.lua — Skill picker UI: <C-g>s entry point.
--
-- Opens a float picker for selecting a skill and its arguments.
-- Multi-step: select skill → select arg1 → select arg2 → run.
-- Each step closes and reopens the picker with new items.
--
-- Skills come from the unified registry (parley.skills.current()); each chosen
-- skill runs through the skill_invoke driver — `review` via its marker-aware
-- run_via_invoke wrapper, every other skill as a single-shot exchange.

local M = {}

local _parley

M.setup = function(parley)
    _parley = parley
end

-- Route a chosen skill (a SkillManifest) to its driver. `review` keeps its
-- marker pre-check + resubmit loop (run_via_invoke); every other skill is a
-- single-shot skill_invoke exchange on the artifact buffer.
function M.run_skill(buf, manifest, args)
    if manifest.name == "review" then
        require("parley.skills.review").run_via_invoke(buf, args or {})
    else
        require("parley.skill_invoke").invoke(buf, manifest, args or {}, {})
    end
end

local function open_arg_picker(buf, skill, args, arg_index)
    _parley = _parley or require("parley")
    local float_picker = _parley.float_picker

    -- All args collected — run the skill
    if not skill.args or arg_index > #skill.args then
        M.run_skill(buf, skill, args)
        return
    end

    local arg_def = skill.args[arg_index]
    if not arg_def or not arg_def.complete then
        M.run_skill(buf, skill, args)
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
        recall_key = "parley.skill_arg_picker:" .. skill.name .. ":" .. arg_def.name,
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
    local float_picker = _parley.float_picker

    local skills = require("parley.skill_registry").current().all()
    table.sort(skills, function(a, b) return a.name < b.name end)
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
        recall_key = "parley.skill_picker",
        recall_id_fn = function(item) return item.value.name end,
        on_select = function(item)
            local skill = item.value
            vim.schedule(function()
                if not skill.args or #skill.args == 0 then
                    M.run_skill(buf, skill, {})
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
