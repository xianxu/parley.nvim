-- Topic input contains the current file conversation, while the main request
-- keeps its complete system prefix followed by ancestor context.
local parley=require('parley')
local Respond=require('parley.chat_respond')
local root=vim.fn.tempname()..'-branch-topic'
vim.fn.mkdir(root,'p')
parley.setup({chat_dir=root,state_dir=root..'/state',providers={},api_keys={},parley_help=false,
    default_agent='TopicNormal',agents={{name='Choose a model',disable=true},
        {name='TopicNormal',provider='openai',model={model='fixture'},system_prompt='NORMAL POLICY',tools={}},
        {name='TopicSynthetic',provider='openai',model={model='fixture'},system_prompt='SYNTHETIC POLICY',
            synthetic_system_prompt=true,synthetic_system_prompt_ack='SYNTHETIC ACK',tools={}},
        {name='TopicEmpty',provider='openai',model={model='fixture'},system_prompt='',tools={}}}})
local function wait(predicate)assert.is_true(vim.wait(5000,predicate,1),'topic flow did not settle')end

describe('branch topic input boundaries',function()
    local buf,calls,old_query,old_stop,parent,child
    before_each(function()
        calls={};old_query,old_stop=parley.dispatcher.query,parley.tasker.stop_owner
        parley.dispatcher.query=function(b,_,payload,output,complete,_,_,abort,_,failure,opts)
            local id='branch-topic:'..#calls
            calls[#calls+1]={id=id,payload=vim.deepcopy(payload),output=output,complete=complete,abort=abort,
                failure=failure,opts=opts}
            parley.tasker.set_query(id,{buf=b,response='',raw_response='',tool_wire='openai'})
            return id
        end
        parley.tasker.stop_owner=function(owner)
            for _,call in ipairs(calls)do if call.opts.generation_id==owner then call.abort('cancelled')end end
        end
        buf=vim.api.nvim_create_buf(true,false)
        local parent_name='2026-09-15.12-00-00.001_parent-'..buf..'.md'
        local child_name='2026-09-15.12-00-00.002_child-'..buf..'.md'
        parent,child=root..'/'..parent_name,root..'/'..child_name
        vim.fn.writefile({'# topic: Parent','- file: parent.md','---','',
            '💬: ANCESTOR QUESTION','','🤖: parent','ANCESTOR ANSWER','','🌿: '..child_name..': Child'},parent)
        local lines={'# topic: ?','- file: child.md','---','',
            '🌿: '..parent_name..': Parent','💬: CURRENT QUESTION',''}
        vim.fn.writefile(lines,child)
        vim.api.nvim_buf_set_name(buf,child);vim.api.nvim_set_current_buf(buf)
        vim.api.nvim_buf_set_lines(buf,0,-1,false,lines);vim.api.nvim_win_set_cursor(0,{6,0})
    end)
    after_each(function()
        Respond.cancel_responses(buf)
        for _,call in ipairs(calls)do call.abort('fixture cleanup')end
        if vim.api.nvim_buf_is_valid(buf)then vim.api.nvim_buf_delete(buf,{force=true})end
        parley.dispatcher.query,parley.tasker.stop_owner=old_query,old_stop
        vim.fn.delete(parent);vim.fn.delete(child)
    end)
    for _,case in ipairs({{name='TopicNormal',leading={'NORMAL POLICY'}},
        {name='TopicSynthetic',leading={'SYNTHETIC POLICY','SYNTHETIC ACK'}},
        {name='TopicEmpty',leading={}}})do
        it('keeps the main prefix contiguous for '..case.name,function()
            parley._state.agent=case.name;parley._state.system_prompt='fixture-agent-prompt'
            Respond.respond({range=0});wait(function()return #calls==1 end)
            local messages=calls[1].payload.messages
            for i,value in ipairs(case.leading)do assert.equals(value,messages[i].content)end
            assert.equals('ANCESTOR QUESTION',messages[#case.leading+1].content)
            assert.equals('ANCESTOR ANSWER',messages[#case.leading+2].content)
            assert.equals('CURRENT QUESTION',messages[#case.leading+3].content)
        end)
        it('excludes system and ancestor context from the topic for '..case.name,function()
            parley._state.agent=case.name;parley._state.system_prompt='fixture-agent-prompt'
            Respond.respond({range=0});wait(function()return #calls==1 end)
            local call=calls[1]
            parley.tasker.get_query(call.id).response='CURRENT ANSWER'
            call.output(call.id,'CURRENT ANSWER')
            wait(function()return table.concat(vim.api.nvim_buf_get_lines(buf,0,-1,false),'\n'):find('CURRENT ANSWER',1,true)~=nil end)
            call.complete(call.id);wait(function()return #calls==2 end)
            local text=vim.inspect(calls[2].payload.messages)
            assert.truthy(text:find('CURRENT QUESTION',1,true));assert.truthy(text:find('CURRENT ANSWER',1,true))
            assert.is_nil(text:find('ANCESTOR',1,true));assert.is_nil(text:find('POLICY',1,true))
            assert.is_nil(text:find('SYNTHETIC ACK',1,true))
        end)
    end
end)
