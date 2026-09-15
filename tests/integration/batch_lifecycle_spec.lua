local parley=require('parley')
local Respond=require('parley.chat_respond')
local D=require('parley.document')
local directory=vim.fn.tempname()..'-batch-lifecycle'
vim.fn.mkdir(directory,'p')
parley.setup({chat_dir=directory,state_dir=directory..'/state',providers={},api_keys={},
    default_agent='BatchFixture',agents={{name='Choose a model',disable=true},
        {name='BatchFixture',provider='openai',model={model='fixture'},system_prompt='Fixture',tools={}}}})
local function wait(predicate)assert.is_true(vim.wait(5000,predicate,1),'batch did not settle')end
describe('public batch membership lifetime',function()
    local buf,calls,old_query,old_stop
    before_each(function()
        calls={};old_query,old_stop=parley.dispatcher.query,parley.tasker.stop_owner
        parley.dispatcher.query=function(b,_,payload,output,complete,_,_,abort,_,failure,opts)
            local id='batch-lifecycle:'..tostring(#calls+1)
            calls[#calls+1]={id=id,buf=b,output=output,complete=complete,abort=abort,opts=opts,cancelled=0}
            parley.tasker.set_query(id,{buf=b,response='',raw_response='',tool_wire='openai'})
            return id
        end
        parley.tasker.stop_owner=function(owner)
            for _,call in ipairs(calls)do if call.opts.generation_id==owner then call.cancelled=call.cancelled+1 end end
        end
        buf=vim.api.nvim_create_buf(true,false);vim.api.nvim_set_current_buf(buf)
        vim.api.nvim_buf_set_name(buf,directory..'/2026-09-15.12-00-00.'..string.format('%03d',buf)..'_fixture.md')
        local lines={'# topic: Fixture','- file: fixture.md','---','','💬: question','','🤖: old','answer',''}
        vim.api.nvim_buf_set_lines(buf,0,-1,false,lines)
        vim.fn.writefile(lines,vim.api.nvim_buf_get_name(buf));vim.api.nvim_win_set_cursor(0,{5,0})
    end)
    after_each(function()
        Respond.cancel_responses(buf)
        for _,call in ipairs(calls)do call.abort('fixture cleanup')end
        if vim.api.nvim_buf_is_valid(buf)then vim.api.nvim_buf_delete(buf,{force=true})end
        parley.dispatcher.query,parley.tasker.stop_owner=old_query,old_stop
    end)
    for _,event in ipairs({'detach','reload'})do
        it('admits a fresh epoch after '..event..' while old physical cancellation remains unresolved',function()
            local old=Respond.respond_all();assert.is_not_nil(old);wait(function()return #calls==1 end)
            assert.is_nil(Respond.respond_all(),'same-epoch active membership must remain exclusive')
            if event=='detach' then D.detach(D.get(buf))else vim.api.nvim_buf_call(buf,function()vim.cmd('edit!')end)end
            assert.equals('paused',Respond.batch_snapshot(old).phase)
            assert.equals(0,Respond.batch_snapshot(old).completed)
            -- New-epoch membership is independent of the old answer's retained
            -- recovery record. A fresh unanswered question exercises admission
            -- without requesting another replacement of that unresolved answer.
            vim.api.nvim_buf_set_lines(buf,4,-1,false,{'💬: fresh question','',''})
            vim.api.nvim_win_set_cursor(0,{5,0})
            local next_batch=Respond.respond_all();assert.is_not_nil(next_batch)
            wait(function()return #calls==2 end)
            calls[1].abort('old physical cancellation complete')
            assert.is_nil(Respond.respond_all(),'old terminal callback must not clear newer membership')
            assert.equals(0,Respond.batch_snapshot(next_batch).completed)
        end)
    end
    it('allows a new batch after positive completion',function()
        local batch=Respond.respond_all();assert.is_not_nil(batch);wait(function()return #calls==1 end)
        calls[1].output(calls[1].id,'new answer');calls[1].complete(calls[1].id)
        wait(function()return Respond.batch_snapshot(batch).phase=='completed'end)
        vim.api.nvim_buf_call(buf,function()vim.cmd('silent write!')end)
        assert.equals(0,#require('parley.chat_recovery').list(buf),'successful saved replacement must clean snapshot')
        vim.api.nvim_win_set_cursor(0,{5,0})
        assert.is_not_nil(Respond.respond_all());wait(function()return #calls==2 end)
        assert.equals(1,Respond.batch_snapshot(batch).completed)
    end)
    for _,mode in ipairs({'single','batch'})do
        for _,outcome in ipairs({'failure','cancel'})do
            it('retains original across '..mode..' '..outcome..' retry',function()
                local first=mode=='single' and Respond.respond({args='',range=0}) or Respond.respond_all()
                assert.is_not_nil(first);wait(function()return #calls==1 end)
                calls[1].output(calls[1].id,'partial replacement')
                wait(function()return table.concat(vim.api.nvim_buf_get_lines(buf,0,-1,false),'\n'):find('partial replacement',1,true)~=nil end)
                if outcome=='cancel'then Respond.cancel_responses(buf)end
                calls[1].abort('fixture failure')
                wait(function()return mode=='batch' and Respond.batch_snapshot(first).phase=='paused' and not Respond.batch_snapshot(first).active
                    or mode=='single' and Respond.response_snapshot(first).generation.phase=='terminal' end)
                local C=require('parley.chat_recovery')
                local before=C.list(buf);assert.equals(1,#before)
                vim.api.nvim_win_set_cursor(0,{5,0})
                if mode=='batch'then assert.is_true(Respond.resume_batch({}).accepted)
                else assert.is_not_nil(Respond.respond({args='',range=0}))end
                wait(function()return #calls==2 end)
                local after=C.list(buf);assert.equals(1,#after);assert.equals(before[1].id,after[1].id)
                assert.is_truthy(C.inspect_record(after[1].id).bytes:find('🤖: old',1,true))
            end)
        end
    end

    it('settles single response replacement before confirmed save',function()
        local session=Respond.respond({args='',range=0});assert.is_not_nil(session)
        wait(function()return #calls==1 end)
        calls[1].output(calls[1].id,'new answer');calls[1].complete(calls[1].id)
        wait(function()return Respond.response_snapshot(session).generation.phase=='terminal'end)
        vim.api.nvim_buf_call(buf,function()vim.cmd('silent write!')end)
        assert.equals(0,#require('parley.chat_recovery').list(buf))
    end)

end)
