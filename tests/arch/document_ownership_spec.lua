-- #254: command-time chat_respond may inspect the current editor selection and
-- parse a frozen input snapshot. Once admitted, asynchronous work follows the
-- captured document/entity/grant; it cannot rediscover a target from the UI.
-- Native writer placement is separately enforced by buffer_mutation_spec.lua.
local arch=require('tests.arch.arch_helper')
local ASYNC={
    'lua/parley/response_provider.lua',
    'lua/parley/response_tools.lua',
    'lua/parley/response_session.lua',
    'lua/parley/generation_runner.lua',
    'lua/parley/response_submission.lua',
    'lua/parley/response_target.lua',
    'lua/parley/response_completion.lua',
    'lua/parley/response_preparation.lua',
}
local function forbid(scope,pattern,rationale,is_pattern)
    arch.assert_pattern_scoping({scope=scope,pattern=pattern,is_pattern=is_pattern,
        allow_only_in={},rationale=rationale})
end

describe('arch: captured document ownership',function()
    it('keeps generation decisions independent of editor state and IO',function()
        local scope={'lua/parley/generation.lua'}
        for _,global in ipairs({'vim','io','os'})do
            forbid(scope,'%f[%w_]'..global..'%s*[%.%[]',
                '#254: pure generation transitions describe effects; adapters execute editor, clock and IO work',true)
        end
        for _,dependency in ipairs({'parley.document','parley.buffer_edit','parley.dispatcher',
            'parley.tasker','parley.response_','parley.line_reader','parley.tools.dispatcher','parley.deferred_work'})do
            forbid(scope,dependency,'#254: the generation state machine cannot import its effect executors')
        end
        forbid(scope,"require%s*%(?%s*['\"]parley['\"]",
            '#254: the plugin entry point initializes editor and IO services',true)
        for _,dependency in ipairs({'luv','ffi','socket'})do
            forbid(scope,"require%s*%(?%s*['\"]"..dependency,
                '#254: process, filesystem and network effects belong outside pure generation decisions',true)
        end
    end)

    it('keeps tool and source-read lifecycle authority independent of effects',function()
        local scope={'lua/parley/tools/operation.lua','lua/parley/tools/filesystem_operation.lua',
            'lua/parley/skill_source_read.lua'}
        for _,global in ipairs({'vim','io','os'})do
            forbid(scope,'%f[%w_]'..global..'%s*[%.%[]',
                '#254: lifecycle transitions authorize effects; adapters own IO, clocks and handles',true)
        end
        for _,dependency in ipairs({'luv','ffi','socket','parley.tools.scheduler',
            'parley.tools.filesystem','parley.skill_invoke','parley.tasker'})do
            forbid(scope,dependency,'#254: pure lifecycle owners cannot import their effect executors')
        end
    end)

    it('keeps asynchronous targets independent of the current editor selection',function()
        for _,pattern in ipairs({'nvim_get_current_','nvim_set_current_',
            'nvim_win_get_cursor','nvim_win_set_cursor','vim.fn.line','vim.fn.col','vim.fn.getpos'})do
            forbid(ASYNC,pattern,
                '#254: asynchronous operations retain captured document identities; the human may move to another question or window')
        end
    end)

    it('requires asynchronous content writes to pass through document authority',function()
        for _,pattern in ipairs({'parley.buffer_edit','nvim_buf_set_lines','nvim_buf_set_text','vim.cmd','nvim_exec'})do
            forbid(ASYNC,pattern,
                '#254: native edits and command-time buffer helpers cannot bypass the captured grant and exact edit receipt')
        end
    end)

    it('keeps pending presentation out of content mutation and generation ownership',function()
        local scope={'lua/parley/chat_pending.lua','lua/parley/chat_presentation.lua'}
        for _,pattern in ipairs({'parley.buffer_edit','parley.generation_runner','parley.response_session',
            'nvim_buf_set_lines','nvim_buf_set_text','vim.cmd','nvim_exec'})do
            forbid(scope,pattern,
                '#254: pending UI owns extmarks and timers; its visibility cannot admit, delay or perform a content write')
        end
        for _,method in ipairs({'append','apply','apply_user','replace_new','replace_step',
            'insert_released_new','reserve_capacity','acquire'})do
            forbid(scope,'[%.:]'..method..'%s*%(',
                '#254: presentation may observe document lifetime, but cannot mint grants or mutate content',true)
        end
        -- Presentation has its own pure transition function. Guard document
        -- ownership commands, rather than banning every state transition.
        for _,event in ipairs({'register_generation','acquire','revoke','finish_generation','reserve_capacity'})do
            forbid(scope,"kind%s*=%s*['\"]"..event.."['\"]",
                '#254: pending UI cannot create or cancel document authority',true)
        end
    end)

    it('does not restore a second per-buffer lease or tool driver',function()
        for _,module in ipairs({'chat_lease','tool_loop'})do
            forbid('lua/parley/**/*.lua',"require%s*%(?%s*['\"]parley%."..module.."['\"]",
                '#254: Document grants and scoped generation sessions are the sole live writer authority',true)
        end
    end)
    it('does not restore positional streaming through the legacy dispatcher handler',function()
        forbid('lua/parley/**/*.lua','%.create_handler%s*%(',
            '#254: production streaming uses the position-free provider and captured document grants',true)
    end)

end)
