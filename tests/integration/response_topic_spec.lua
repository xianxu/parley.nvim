local ok,Topic=pcall(require,'parley.response_topic')
local D=require('parley.document')
local Dispatcher=require('parley.dispatcher')
local Tasker=require('parley.tasker')
local Vault=require('parley.vault')
local Process=require('tests.helpers.fake_process')
local function status(p)
    for i,arg in ipairs(p.args)do if arg=='--write-out'then
        p:emit('stderr',p.args[i+1]:match('%%{stderr}(.-)%%{http_code}')..'200\n');return
    end end
end
local function emit(p,text)
    p:emit('stdout','data: '..vim.json.encode({choices={{delta={content=text}}}})..'\n\n')
end
local function spec()
    return {header={first={row=0,col=9},last={row=0,col=10}},
        parents={{first={row=4,col=0},last={row=4,col=#'💬: question'}},
            {first={row=5,col=0},last={row=5,col=#'🤖: answer'}}},
        input={provider='openai',model='fixture',payload={model='fixture',messages={}}},schedule=false}
end
local function pump(job)for _=1,200 do Topic.step(job)end end
describe('independent automatic topic ownership',function()
    local buf,doc,processes,old_secret,old_run,jobs
    before_each(function()
        buf=vim.api.nvim_create_buf(false,true)
        vim.api.nvim_buf_set_lines(buf,0,-1,false,{'# topic: ?','- model: test','---','','💬: question','🤖: answer','text','','💬: next'})
        doc=D.attach(buf,{schedule=false});jobs={}
        local runtime;runtime,processes=Process.new();Tasker._reset();Tasker._uv=runtime
        old_secret,old_run=Vault.get_secret,Vault.run_with_secret
        Vault.get_secret=function()return 'fixture-secret'end;Vault.run_with_secret=function(_,fn)fn()end
        Dispatcher.providers.openai={endpoint='http://127.0.0.1:9/fixture'}
        Dispatcher.query_dir=vim.fn.tempname()..'-queries';vim.fn.mkdir(Dispatcher.query_dir,'p')
    end)
    after_each(function()
        for _,p in pairs(processes.processes)do status(p);p:finish()end
        vim.wait(100,function()return #Tasker._handles==0 end,1)
        if ok then for _,job in ipairs(jobs)do Topic.cancel(job);pump(job)end end
        D.detach(doc);vim.api.nvim_buf_delete(buf,{force=true})
        Vault.get_secret,Vault.run_with_secret=old_secret,old_run;Tasker._reset();Tasker._uv=nil
    end)
    it('provides a captured automatic topic job',function()assert.is_true(ok,tostring(Topic))end)
    if not ok then return end
    local function start(doc,value,jobs)
        local job=assert(Topic.start(doc,value,{}));jobs[#jobs+1]=job;return job
    end
    it('writes only the final first line after positive process and pipe completion',function()
        local job=start(doc,spec(),jobs);pump(job)
        local p=processes.processes[4242];assert.is_not_nil(p)
        emit(p,' A topic.\nignored')
        assert.equals('# topic: ?',vim.api.nvim_buf_get_lines(buf,0,1,false)[1])
        vim.api.nvim_buf_set_text(buf,8,#'💬: next',8,#'💬: next',{' human'})
        status(p);p:exit();pump(job)
        assert.equals('# topic: ?',vim.api.nvim_buf_get_lines(buf,0,1,false)[1])
        p:emit('stdout',nil);p:emit('stderr',nil)
        vim.wait(100,function()return #Tasker._handles==0 end,1);pump(job)
        assert.equals('# topic: A topic',vim.api.nvim_buf_get_lines(buf,0,1,false)[1])
        assert.equals('applied',Topic.snapshot(job).status)
        assert.equals('💬: next human',vim.api.nvim_buf_get_lines(buf,8,9,false)[1])
        assert.equals(0,D.user_guard_stats(doc).live)
    end)
    it('cancels when the captured answer header is deleted and waits for cleanup',function()
        local job=start(doc,spec(),jobs);pump(job)
        vim.api.nvim_buf_set_lines(buf,5,6,false,{})
        pump(job);assert.equals('stopping',Topic.snapshot(job).status)
        assert.equals(1,#processes.signals)
        local p=processes.processes[4242];emit(p,'late topic');status(p);p:finish()
        vim.wait(100,function()return #Tasker._handles==0 end,1);pump(job)
        assert.equals('cancelled',Topic.snapshot(job).status)
        assert.equals('# topic: ?',vim.api.nvim_buf_get_lines(buf,0,1,false)[1])
    end)
    it('never reclaims a human topic even after an identical replacement',function()
        local job=start(doc,spec(),jobs)
        vim.api.nvim_buf_set_lines(buf,0,1,false,{'# topic: ?'})
        pump(job);assert.equals(0,processes.spawn_calls)
        assert.equals('cancelled',Topic.snapshot(job).status)
    end)
    it('refuses oversized topic text without writing partial bytes',function()
        local job=start(doc,spec(),jobs);pump(job)
        local p=processes.processes[4242];emit(p,string.rep('x',4097));pump(job)
        assert.equals('stopping',Topic.snapshot(job).status)
        status(p);p:finish();vim.wait(100,function()return #Tasker._handles==0 end,1);pump(job)
        assert.equals('failed',Topic.snapshot(job).status)
        assert.equals('# topic: ?',vim.api.nvim_buf_get_lines(buf,0,1,false)[1])
    end)
    it('survives normal originating generation completion',function()
        D.drain(doc,1000)
        local parent=D.transition(doc,{kind='register_generation'}).generation
        local job=start(doc,spec(),jobs);pump(job)
        D.transition(doc,{kind='finish_generation',generation=parent})
        local p=processes.processes[4242];emit(p,'independent');status(p);p:finish()
        vim.wait(100,function()return #Tasker._handles==0 end,1);pump(job)
        assert.equals('applied',Topic.snapshot(job).status)
        assert.equals('# topic: independent',vim.api.nvim_buf_get_lines(buf,0,1,false)[1])
    end)
    it('invalidates the old topic job on native reload even when disk bytes match',function()
        local file=vim.fn.tempname()..'.md'
        vim.fn.writefile(vim.api.nvim_buf_get_lines(buf,0,-1,false),file)
        vim.api.nvim_buf_set_name(buf,file);vim.bo[buf].buftype=''
        local job=start(doc,spec(),jobs);pump(job)
        vim.api.nvim_buf_call(buf,function()vim.cmd('edit!')end)
        pump(job);assert.equals('stopping',Topic.snapshot(job).status)
        local p=processes.processes[4242];emit(p,'old result');status(p);p:finish()
        vim.wait(100,function()return #Tasker._handles==0 end,1);pump(job)
        assert.equals('cancelled',Topic.snapshot(job).status)
        assert.equals('# topic: ?',vim.api.nvim_buf_get_lines(buf,0,1,false)[1])
        vim.fn.delete(file)
    end)
    it('builds a copied utility prompt containing only nonempty conversation text',function()
        local captured
        local messages={{role='system',content='persona'},
            {role='user',content={{type='text',text=' hello '},{type='tool_use',id='a'}}},
            {role='assistant',content='  '},{role='assistant',content=' answer ',cache_control={type='ephemeral'}}}
        local input=Topic.input(messages,'openai','fixture','short topic',{prepare_payload=function(value)
            captured=vim.deepcopy(value);return {messages=value}
        end})
        assert.same({{role='user',content='hello'},{role='assistant',content='answer'},
            {role='user',content='short topic'}},captured)
        input.payload.messages[1].content='changed'
        assert.equals(' hello ',messages[2].content[1].text)
    end)

    it('refuses a non-question-mark suffix before starting any provider IO',function()
        vim.api.nvim_buf_set_text(buf,0,9,0,10,{'x'})
        local job=assert(Topic.start(doc,spec(),{buf=buf}));jobs[#jobs+1]=job;pump(job)
        assert.equals(0,processes.spawn_calls)
        assert.equals('failed',Topic.snapshot(job).status)
        assert.equals('# topic: x',vim.api.nvim_buf_get_lines(buf,0,1,false)[1])
    end)

    it('revalidates after the bounded pre-IO reader callback edits the header',function()
        local Reader=require('parley.line_reader')
        local edited=false
        local observer=Reader.set_observer(buf,function(event)
            if not edited and event.operation=='text' and event.requested.start_row==0
                and event.requested.start_col==9 then
                edited=true
                assert.equals(10,event.requested.end_col)
                vim.api.nvim_buf_set_text(buf,0,9,0,10,{'mine'})
            end
        end)
        local job=assert(Topic.start(doc,spec(),{buf=buf}));jobs[#jobs+1]=job;pump(job)
        Reader.clear_observer(buf,observer)
        assert.is_true(edited);assert.equals(0,processes.spawn_calls)
        assert.equals('cancelled',Topic.snapshot(job).status)
        assert.equals('# topic: mine',vim.api.nvim_buf_get_lines(buf,0,1,false)[1])
    end)

end)
