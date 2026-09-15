local p=require('parley')
local R=require('parley.chat_respond')
local OAuth=require('parley.oauth')
local root=vim.fn.tempname()..'-remote-preparation';vim.fn.mkdir(root,'p')
p.setup({chat_dir=root,state_dir=root..'/state',providers={},api_keys={},default_agent='RemoteFixture',
 agents={{name='Choose a model',disable=true},{name='RemoteFixture',provider='openai',model={model='fixture'},system_prompt='Fixture',tools={}}}})
local function wait(predicate)assert.is_true(vim.wait(3000,predicate,1),'remote preparation did not settle')end
local function snapshot(s)return R.response_snapshot(s)end
describe('remote preparation positive child completion',function()
    local buf,session,children,requests,saves,old_fetch,old_query,old_save
    before_each(function()
        children={};requests=0;saves=0
        old_fetch,old_query,old_save=OAuth.fetch_content,p.dispatcher.query,R.save_remote_reference_cache
        R.save_remote_reference_cache=function()saves=saves+1 end
        p.dispatcher.query=function()requests=requests+1 end
        buf=vim.api.nvim_create_buf(true,false);vim.api.nvim_set_current_buf(buf)
        vim.api.nvim_buf_set_name(buf,root..'/2026-09-15.12-00-00.001_'..buf..'.md')
        vim.api.nvim_buf_set_lines(buf,0,-1,false,{'# topic: Fixture','- file: fixture.md','---','',
            '💬: fetch @@https://example.com/a@@ @@https://example.com/b@@ @@https://example.com/c@@',
            '🤖: old','old answer','','💬: next','draft'})
        vim.api.nvim_win_set_cursor(0,{5,0})
    end)
    after_each(function()
        R.cancel_responses(buf)
        for _,child in ipairs(children)do child.done(nil,'fixture cleanup')end
        if session then wait(function()local s=snapshot(session);return s.status=='terminal' or s.status=='cancelled'end)end
        OAuth.fetch_content,p.dispatcher.query,R.save_remote_reference_cache=old_fetch,old_query,old_save
        vim.api.nvim_buf_delete(buf,{force=true});session=nil
    end)
    it('holds both a launched sibling and an unknown throwing launch until their positive callbacks arrive',function()
        OAuth.fetch_content=function(url,_,done)
            children[#children+1]={url=url,done=done}
            if #children==2 then error('launch outcome unknown')end
        end
        session=assert(R.respond({range=0}));wait(function()return #children==2 end)
        wait(function()return snapshot(session).generation.phase=='stopping' or snapshot(session).status=='terminal'end)
        assert.equals('stopping',snapshot(session).generation.phase)
        children[1].done('first result');children[1].done('duplicate result')
        vim.wait(50,function()return snapshot(session).status=='terminal'end,1)
        assert.equals('stopping',snapshot(session).generation.phase,'throw is not proof that second child never spawned')
        assert.equals(2,#children,'third URL must not start after a failed launch')
        children[2].done('late result after throw')
        wait(function()return snapshot(session).status=='terminal'end)
        assert.equals(0,requests);assert.equals(0,saves)
        children[2].done('duplicate');assert.equals(0,saves)
    end)
    it('does not publish remote cache results or start a provider after operator cancellation',function()
        OAuth.fetch_content=function(url,_,done)children[#children+1]={url=url,done=done}end
        session=assert(R.respond({range=0}));wait(function()return #children==3 end)
        R.cancel_responses(buf)
        wait(function()return snapshot(session).generation.phase=='stopping'end)
        children[1].done('cancelled first');children[1].done('duplicate')
        children[2].done('cancelled second')
        assert.equals('stopping',snapshot(session).generation.phase)
        children[3].done('cancelled third')
        wait(function()return snapshot(session).status=='terminal'end)
        assert.equals(0,requests);assert.equals(0,saves)
    end)
end)
