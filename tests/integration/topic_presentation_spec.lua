local parley=require('parley')
local root=vim.fn.tempname()..'-topic-presentation'
parley.setup({chat_dir=root,state_dir=root..'/state',providers={},api_keys={},
    default_agent='TopicFixture',agents={{name='Choose a model',disable=true},
        {name='TopicFixture',provider='anthropic',model={model='fixture'},system_prompt='Fixture',tools={}}}})
local Topics=require('parley.chat_respond')
local D=require('parley.document')
describe('topic presentation and collection',function()
    local old_query,old_timer,buf,request,tick,result,doc
    before_each(function()
        old_query,old_timer=parley.dispatcher.query,vim.uv.new_timer
        request,tick,result=nil,nil,nil
        buf=vim.api.nvim_create_buf(false,true)
        vim.api.nvim_buf_set_lines(buf,0,-1,false,{'# topic: ?','- file: fixture.md','---','','💬: q'})
        doc=D.attach(buf,{schedule=false});D.drain(doc,1000)
        vim.uv.new_timer=function()
            local closed=false
            return {start=function(_,_,_,cb)tick=cb end,stop=function()end,
                close=function()closed=true end,is_closing=function()return closed end}
        end
        parley.dispatcher.query=function(_,_,_,handler,complete,_,_,abort,_,failure)
            request={handler=handler,complete=complete,abort=abort,failure=failure}
        end
    end)
    after_each(function()
        if request then request.abort('fixture teardown') end
        parley.dispatcher.query,vim.uv.new_timer=old_query,old_timer
        if vim.api.nvim_buf_is_valid(buf) then vim.api.nvim_buf_delete(buf,{force=true}) end
    end)
    local function start(spinner)
        Topics.generate_topic({{role='user',content='q'}},'anthropic',{model='fixture'},
            function(topic,reason)result={topic=topic,reason=reason}end,spinner)
    end
    it('animates without changing buffer text or invalidating a delayed source guard',function()
        local guard=D.capture_user(doc,{operation='topic',regions={
            {first={row=0,col=0},last={row=0,col=10}}}})
        local before=vim.api.nvim_buf_get_changedtick(buf)
        start({buf=buf,find_line=function()return 0 end})
        tick()
        assert.is_true(vim.wait(200,function()
            for _,mark in ipairs(vim.api.nvim_buf_get_extmarks(buf,-1,0,-1,{details=true})) do
                if mark[4].virt_text and #mark[4].virt_text>0 then return true end
            end
            return false
        end,5))
        assert.equals(before,vim.api.nvim_buf_get_changedtick(buf))
        assert.equals('# topic: ?',vim.api.nvim_buf_get_lines(buf,0,1,false)[1])
        assert.is_not_nil(D.resolve_user(doc,guard))
        request.handler('topic','New topic');request.complete('topic')
        assert.is_true(vim.wait(200,function()return result~=nil end,5))
        assert.equals(0,#vim.api.nvim_buf_get_extmarks(buf,-1,0,-1,{}))
        assert.is_not_nil(D.resolve_user(doc,guard))
    end)
    it('collects fragmented first-line output without creating a scratch buffer',function()
        local before=#vim.api.nvim_list_bufs()
        start()
        assert.equals(before,#vim.api.nvim_list_bufs())
        request.handler('topic','  A ');request.handler('topic','topic.\nignored')
        request.complete('topic')
        assert.is_true(vim.wait(200,function()return result~=nil end,5))
        assert.equals('A topic',result.topic)
        request.handler('topic','late');request.complete('topic')
        assert.equals('A topic',result.topic)
    end)
    it('refuses an oversized first line and does not publish a truncated topic',function()
        start()
        request.handler('topic',string.rep('x',4096))
        request.handler('topic','overflow')
        request.complete('topic')
        assert.is_true(vim.wait(200,function()return result~=nil end,5))
        assert.is_nil(result.topic)
        assert.equals('topic too long',result.reason)
    end)
end)
