local ok,S=pcall(require,'parley.response_submission')
local D=require('parley.document')
local FakeEditor=require('tests.helpers.fake_document_editor')
local Fake=require('tests.helpers.fake_generation_runner')
local serial=108000
local docs,sessions={},{}
local function fixture()
    serial=serial+1
    local editor=FakeEditor.new({'💬: question','body','🤖: answer','text','💬: next','draft'})
    local doc=D.attach(serial,{driver=editor.driver,schedule=false});docs[#docs+1]=doc
    return doc,editor
end
local function spec()
    return {operation='respond',question={first={row=0,col=0},last={row=1,col=4}},
        output={first={row=1,col=4},last={row=3,col=4}},input={message='frozen'},schedule=false}
end
local function start(doc,value,fake)
    local session,reason=S.start(doc,value,fake.adapters)
    assert.is_not_nil(session,reason);sessions[#sessions+1]=session;return session
end
local function settle(session)
    for _=1,1000 do local result=S.step(session);if result.status~='more' then return result end end
    error('submission did not settle')
end
describe('response submission lifetime',function()
    after_each(function()
        if ok then for _,s in ipairs(sessions)do S.cancel(s);settle(s)end end
        for _,doc in ipairs(docs)do D.detach(doc)end
        docs,sessions={},{}
    end)
    it('provides the source-to-runner admission seam',function()assert.is_true(ok,tostring(S))end)
    if not ok then return end
    it('freezes input before waiting and owns output before preparation IO',function()
        local doc=fixture();local fake=Fake.new();local value=spec()
        local s=start(doc,value,fake);value.input.message='changed';assert.equals(0,#fake.preparations)
        settle(s);assert.equals(1,#fake.preparations)
        local ctx=fake.preparations[1].ctx
        assert.equals('frozen',ctx.input.message)
        assert.equals('valid',D.snapshot(doc).grants[ctx.grant].status)
        fake:prepare();settle(s);fake:output(1,'answer');fake:complete(1);settle(s)
        assert.equals('terminal',S.snapshot(s).status)
        assert.equals('success',S.snapshot(s).generation.outcome)
    end)
    it('cancels a deleted target before any IO and never selects the current cursor',function()
        local doc,editor=fixture();local fake=Fake.new();local s=start(doc,spec(),fake)
        editor:edit(0,0,1,4,{'replacement'})
        settle(s);assert.equals('cancelled',S.snapshot(s).status)
        assert.equals(0,#fake.preparations);assert.equals(0,D.user_guard_stats(doc).live)
    end)
    it('rejects duplicate authority before remote preparation and preserves the first writer',function()
        local doc=fixture();local first,second=Fake.new(),Fake.new()
        local a=start(doc,spec(),first);settle(a)
        local b=start(doc,spec(),second);settle(b)
        assert.equals('cancelled',S.snapshot(b).status);assert.equals(0,#second.preparations)
        first:prepare();settle(a);first:output(1,'kept');first:complete(1);settle(a)
        assert.equals('success',S.snapshot(a).generation.outcome)
    end)
    it('retains unresolved cancellation until the captured operation resolves',function()
        local doc=fixture();local fake=Fake.new();local s=start(doc,spec(),fake);settle(s)
        S.cancel(s,'stop');settle(s)
        assert.equals('stopping',S.snapshot(s).generation.phase)
        assert.equals(1,#fake.cancellations)
        fake.preparations[1].callbacks.prepared({message='late'})
        assert.equals(0,#fake.requests)
        fake.cancellations[1].resolved();settle(s)
        assert.equals('terminal',S.snapshot(s).status)
    end)
    it('runs scheduled admission without synchronous materialization or native cursor changes',function()
        local buf=vim.api.nvim_create_buf(false,true)
        vim.api.nvim_buf_set_lines(buf,0,-1,false,{'💬: question','body','🤖: answer','text','💬: next','draft'})
        local doc=D.attach(buf,{schedule=false});docs[#docs+1]=doc
        local value=spec();value.schedule=true
        local fake=Fake.new();local s=start(doc,value,fake)
        assert.equals(0,#fake.preparations)
        assert.is_true(vim.wait(2000,function()return #fake.preparations==1 end,1))
        fake:prepare()
        assert.is_true(vim.wait(2000,function()return #fake.requests==1 end,1))
        fake:output(1,' appended');fake:complete(1)
        assert.is_true(vim.wait(2000,function()return S.snapshot(s).status=='terminal'end,1))
        assert.equals('text appended',vim.api.nvim_buf_get_lines(buf,3,4,false)[1])
        vim.api.nvim_buf_delete(buf,{force=true})
    end)
    it('carries waiting-input edits into the first preparation without changing frozen bytes',function()
        local doc,editor=fixture();local fake=Fake.new();local s=start(doc,spec(),fake)
        editor:edit(5,5,5,5,{' changed'})
        settle(s)
        assert.is_true(fake.preparations[1].ctx.stale_input)
        assert.equals('frozen',fake.preparations[1].ctx.input.message)
    end)

    it('commits admitted output before provider-failure retirement without success finalization',function()
        local doc,editor=fixture();local fake=Fake.new();local s=start(doc,spec(),fake)
        settle(s);fake:prepare();settle(s)
        fake:output(1,' first');fake:output(1,' second')
        fake.requests[1].callbacks.failed('transport failed')
        fake.requests[1].callbacks.resolved()
        settle(s)
        assert.equals('text first second',editor.lines[4])
        assert.equals('provider_failed',S.snapshot(s).generation.outcome)
        assert.equals(0,S.snapshot(s).generation.discarded_bytes)
        assert.equals(0,#fake.finalizations)
    end)

end)
