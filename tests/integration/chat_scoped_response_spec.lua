local parley=require('parley')
local Respond=require('parley.chat_respond')
local D=require('parley.document')
local root=vim.fn.tempname()..'-scoped-response'
vim.fn.mkdir(root,'p')
parley.setup({chat_dir=root,state_dir=root..'/state',providers={},api_keys={},
    default_agent='ScopedFixture',agents={{name='Choose a model',disable=true},
        {name='ScopedFixture',provider='openai',model={model='fixture'},system_prompt='Fixture',tools={}}}})
local function wait(predicate)assert.is_true(vim.wait(5000,predicate,1),'response did not settle')end
local function text(buf)return table.concat(vim.api.nvim_buf_get_lines(buf,0,-1,false),'\n')end

describe('public scoped response command',function()
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
        parley.tasker.stop_owner=require('tests.helpers.respond_fixture').stop_owner(calls)
        buf=vim.api.nvim_create_buf(true,false)
        vim.api.nvim_buf_set_name(buf,root..string.format('/2026-09-15.12-%02d-%02d.%03d_fixture.md',
            math.floor(buf/60000)%60,math.floor(buf/1000)%60,buf%1000))
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
    it('runs two disjoint answers while the next question is edited',function()
        local a=submit('first');assert.is_not_nil(a)
        wait(function()return #calls==1 end)
        local b=submit('second');assert.is_not_nil(b)
        wait(function()return #calls==2 end)
        local count=vim.api.nvim_buf_line_count(buf)
        vim.api.nvim_buf_set_text(buf,count-1,5,count-1,5,{' edited'})
        calls[2].output(calls[2].id,'answer two');calls[1].output(calls[1].id,'answer one')
        calls[2].complete(calls[2].id);calls[1].complete(calls[1].id)
        wait(function()return Respond.response_snapshot(a).status=='terminal' and Respond.response_snapshot(b).status=='terminal'end)
        assert.equals('success',Respond.response_snapshot(a).generation.outcome)
        assert.equals('success',Respond.response_snapshot(b).generation.outcome)
        local result=text(buf)
        assert.is_truthy(result:find('answer one',1,true));assert.is_truthy(result:find('answer two',1,true))
        assert.is_truthy(result:find('draft edited',1,true))
        assert.is_nil(result:find('old one',1,true));assert.is_nil(result:find('old two',1,true))
        local _,questions=result:gsub('💬:','');assert.equals(3,questions)
    end)
    it('rejects a second writer to the same answer before provider IO',function()
        local a=submit('first');wait(function()return #calls==1 end)
        local b=submit('first');assert.is_not_nil(b)
        wait(function()return Respond.response_snapshot(b).status=='cancelled'end)
        assert.equals(1,#calls);assert.is_true(calls[1].running)
        calls[1].output(calls[1].id,'kept');calls[1].complete(calls[1].id)
        wait(function()return Respond.response_snapshot(a).status=='terminal'end)
        assert.equals('success',Respond.response_snapshot(a).generation.outcome)
        assert.is_truthy(text(buf):find('kept',1,true))
    end)
    it('admits the next captured question while a preceding answer continues streaming',function()
        local a=submit('first');wait(function()return #calls==1 end)
        local b=submit('second')
        calls[1].output(calls[1].id,'preceding output')
        wait(function()return #calls==2 or Respond.response_snapshot(b).status=='cancelled'end)
        assert.equals(2,#calls)
        calls[1].complete(calls[1].id);calls[2].complete(calls[2].id)
        wait(function()return Respond.response_snapshot(a).status=='terminal' and Respond.response_snapshot(b).status=='terminal'end)
    end)
    it('retires captured preparation after target deletion without dispatching late IO',function()
        local old=Respond.resolve_remote_references;local ready
        Respond.resolve_remote_references=function(_,callback)ready=callback end
        local session=submit('first')
        wait(function()return ready~=nil end)
        local doc=D.get(buf);assert.is_not_nil(doc)
        vim.api.nvim_buf_set_lines(buf,4,7,false,{})
        ready({});Respond.resolve_remote_references=old
        wait(function()return Respond.response_snapshot(session).status=='terminal'end)
        assert.equals(0,#calls)
    end)
    it('stops captured response owners without invoking global transport cancellation',function()
        local session=submit('first');wait(function()return #calls==1 end)
        local old=parley.tasker.stop;local global_stops=0
        parley.tasker.stop=function()global_stops=global_stops+1 end
        Respond.cmd_stop()
        parley.tasker.stop=old
        assert.equals(0,global_stops)
        wait(function()return Respond.response_snapshot(session).status=='terminal'end)
        assert.is_false(calls[1].running)
    end)
    -- #266 Task 1.7: an overflow is reported, not silent — and a held answer's
    -- report names the answer it was waiting for (generation_turn_spec).
    it('says why a response stopped at its staging budget',function()
        local notices={};local old_notify=vim.notify
        vim.notify=function(message,level)notices[#notices+1]={message=message,level=level}end
        local session=submit('first');wait(function()return #calls==1 end)
        calls[1].output(calls[1].id,string.rep('x',1048577))
        wait(function()return Respond.response_snapshot(session).status=='terminal'end)
        vim.notify=old_notify
        assert.equals('overflow',Respond.response_snapshot(session).generation.outcome)
        local found
        for _,n in ipairs(notices)do if n.message:find('staging budget',1,true)then found=n end end
        assert.is_not_nil(found,vim.inspect(notices))
        assert.equals(vim.log.levels.WARN,found.level)
    end)
    it('writes an automatic topic through its captured header after the answer completes',function()
        vim.api.nvim_buf_set_lines(buf,0,1,false,{'# topic: ?'})
        local session=submit('first');wait(function()return #calls==1 end)
        calls[1].output(calls[1].id,'answer');calls[1].complete(calls[1].id)
        wait(function()return #calls==2 end)
        calls[2].output(calls[2].id,'Scoped topic');calls[2].complete(calls[2].id)
        wait(function()return vim.api.nvim_buf_get_lines(buf,0,1,false)[1]=='# topic: Scoped topic'end)
        assert.equals('success',Respond.response_snapshot(session).generation.outcome)
    end)
end)
