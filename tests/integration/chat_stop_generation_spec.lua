local parley=require('parley')
local Respond=require('parley.chat_respond')
local D=require('parley.document')
local root=vim.fn.tempname()..'-scoped-response'
vim.fn.mkdir(root,'p')
parley.setup({chat_dir=root,state_dir=root..'/state',providers={},api_keys={},
    default_agent='ScopedFixture',agents={{name='Choose a model',disable=true},
        {name='ScopedFixture',provider='openai',model={model='fixture'},system_prompt='Fixture',tools={}}}})
local function wait(predicate)assert.is_true(vim.wait(5000,predicate,1),'response did not settle')end

describe('generation scoped Stop commands',function()
    local old_query,old_stop,buf,calls
    before_each(function()
        calls={};old_query,old_stop=parley.dispatcher.query,parley.tasker.stop_owner
        parley.dispatcher.query=function(b,_,payload,output,complete,_,_,abort,_,failure,opts)
            local id='scoped:'..tostring(#calls+1)
            local call={id=id,buf=b,payload=payload,output=output,complete=complete,abort=abort,
                failure=failure,opts=opts,running=true}
            calls[#calls+1]=call
            parley.tasker.set_query(id,{buf=b,response='',raw_response='',tool_wire='openai'})
            return id
        end
        parley.tasker.stop_owner=function(owner)
            for _,call in ipairs(calls)do if call.opts.generation_id==owner then
                call.running=false;vim.schedule(function()call.abort('cancelled')end)
            end end
        end
        buf=vim.api.nvim_create_buf(true,false)
        vim.api.nvim_buf_set_name(buf,root..'/2026-09-15.12-00-00.001_'..buf..'.md')
        vim.api.nvim_set_current_buf(buf)
        vim.api.nvim_buf_set_lines(buf,0,-1,false,{'# topic: Fixture','- file: fixture.md','---','',
            '💬: first','🤖: old','old one','','💬: second','🤖: old','old two','','💬: next','draft'})
    end)
    after_each(function()
        if Respond.cancel_responses then Respond.cancel_responses(buf)end
        for _,call in ipairs(calls)do call.abort('fixture cleanup')end
        if vim.api.nvim_buf_is_valid(buf)then vim.api.nvim_buf_delete(buf,{force=true})end
        parley.dispatcher.query,parley.tasker.stop_owner=old_query,old_stop
    end)
    local function submit(question)
        for i,line in ipairs(vim.api.nvim_buf_get_lines(buf,0,-1,false))do if line=='💬: '..question then
            vim.api.nvim_win_set_cursor(0,{i,0});break end end
        return Respond.respond({range=0})
    end
    it('targets only the generation under the cursor',function()
        local a=submit('first');wait(function()return #calls==1 end)
        local b=submit('second');wait(function()return #calls==2 end)
        Respond.cmd_stop()
        wait(function()return Respond.response_snapshot(b).status=='terminal'end)
        assert.is_true(calls[1].running)
        assert.is_false(calls[2].running)
        assert.equals('running',Respond.response_snapshot(a).status)
    end)
    it('captures picker identities across focus changes and ignores cancelled selection',function()
        local a=submit('first');wait(function()return #calls==1 end)
        local b=submit('second');wait(function()return #calls==2 end)
        vim.api.nvim_win_set_cursor(0,{1,0})
        local old_select=vim.ui.select;local items,choose
        vim.ui.select=function(values,_,callback)items,choose=values,callback end
        Respond.cmd_stop();vim.ui.select=old_select
        assert.equals(2,#items)
        choose(nil);assert.is_true(calls[1].running);assert.is_true(calls[2].running)
        local other=vim.api.nvim_create_buf(true,false);vim.api.nvim_set_current_buf(other)
        choose(items[1])
        wait(function()return Respond.response_snapshot(a).status=='terminal' or Respond.response_snapshot(b).status=='terminal'end)
        assert.is_true(calls[1].running~=calls[2].running)
        vim.api.nvim_set_current_buf(buf);vim.api.nvim_buf_delete(other,{force=true})
    end)
    it('ignores a stale picker after selected session retirement',function()
        local a=submit('first');wait(function()return #calls==1 end)
        vim.api.nvim_win_set_cursor(0,{1,0})
        local old_select=vim.ui.select;local items,choose
        vim.ui.select=function(values,_,callback)items,choose=values,callback end
        Respond.cmd_stop();vim.ui.select=old_select
        calls[1].output(calls[1].id,'done');calls[1].complete(calls[1].id)
        wait(function()return Respond.response_snapshot(a).status=='terminal'end)
        local b=submit('first');wait(function()return #calls==2 end)
        choose(items[1]);assert.is_true(calls[2].running)
        assert.equals('running',Respond.response_snapshot(b).status)
    end)
    it('explicitly stops the document without global transport cancellation',function()
        local a=submit('first');wait(function()return #calls==1 end)
        local b=submit('second');wait(function()return #calls==2 end)
        local old=parley.tasker.stop;local count=0
        parley.tasker.stop=function()count=count+1 end
        parley.cmd.StopDocument();parley.tasker.stop=old
        wait(function()return Respond.response_snapshot(a).status=='terminal' and Respond.response_snapshot(b).status=='terminal'end)
        assert.equals(0,count)
    end)
end)
