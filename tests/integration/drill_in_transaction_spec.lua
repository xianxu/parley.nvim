-- Native reentry between edit receipts must stop a composed user command.
-- Partial owned edits may remain; newer human text must never be overwritten,
-- and an interrupted gather must not admit provider IO from partial source.
local parley=require('parley')
local Respond=require('parley.chat_respond')
local root=vim.fn.tempname()..'-drill-transaction'
vim.fn.mkdir(root,'p')
parley.setup({chat_dir=root,state_dir=root..'/state',providers={},api_keys={},
    default_agent='DrillFixture',agents={{name='Choose a model',disable=true},
        {name='DrillFixture',provider='openai',model={model='fixture'},system_prompt='Fixture',tools={}}}})

describe('drill-in user transaction interruption',function()
    local buf,original_set_text,original_set_lines,original_query,calls,injected
    before_each(function()
        calls={};injected=false
        original_set_text=vim.api.nvim_buf_set_text;original_set_lines=vim.api.nvim_buf_set_lines
        original_query=parley.dispatcher.query
        parley.dispatcher.query=function(_,_,_,_,_,_,_,abort)
            calls[#calls+1]={abort=abort};return 'drill-fixture'
        end
        buf=vim.api.nvim_create_buf(true,false)
        vim.api.nvim_buf_set_name(buf,root..'/2026-09-15.12-00-00.001_'..buf..'.md')
        vim.api.nvim_set_current_buf(buf)
    end)
    after_each(function()
        vim.api.nvim_buf_set_text=original_set_text;vim.api.nvim_buf_set_lines=original_set_lines
        Respond.cancel_responses(buf)
        for _,call in ipairs(calls)do if call.abort then call.abort('fixture cleanup')end end
        if vim.api.nvim_buf_is_valid(buf)then vim.api.nvim_buf_delete(buf,{force=true})end
        parley.dispatcher.query=original_query
    end)
    for _,mode in ipairs({'branch','end'})do
        it('preserves newer source and refuses follow-up admission for '..mode..' gather',function()
            local lines={'# topic: Fixture','- file: fixture.md','---','',
                '💬: first 🤖<one>[explain one]','','🤖: old','answer 🤖<two>[explain two]','',
                '💬: next','draft'}
            vim.api.nvim_buf_set_lines(buf,0,-1,false,lines)
            vim.api.nvim_win_set_cursor(0,{mode=='branch' and 5 or #lines,0})
            local human='💬: human replacement '..string.rep('x',100)
            local function intercept(write)
                return function(target,...)
                    write(target,...)
                    if target==buf and not injected then
                        injected=true
                        original_set_lines(buf,4,5,false,{human})
                    end
                end
            end
            local Document=require('parley.document')
            local old=Document.get(buf);if old then Document.detach(old)end
            vim.api.nvim_buf_set_text=intercept(original_set_text)
            vim.api.nvim_buf_set_lines=intercept(original_set_lines)
            Document.attach(buf)
            Respond.respond({range=0})
            vim.api.nvim_buf_set_text=original_set_text;vim.api.nvim_buf_set_lines=original_set_lines
            assert.is_true(injected,'the fixture must deliver a native edit during mutation')
            assert.equals(human,vim.api.nvim_buf_get_lines(buf,4,5,false)[1])
            vim.wait(500,function()return #calls>0 end,1)
            assert.equals(0,#calls,'interrupted source must not become a provider request')
        end)
    end
end)
