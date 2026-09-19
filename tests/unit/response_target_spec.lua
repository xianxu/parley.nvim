local D=require('parley.document')
local Fake=require('tests.helpers.fake_document_editor')
local ok,T=pcall(require,'parley.response_target')
local serial=98200
local docs={}
local function fixture()
    serial=serial+1
    local fake=Fake.new({'lead','💬: question','body','🤖: answer','text','💬: next','draft'})
    local doc=D.attach(serial,{driver=fake.driver,schedule=false});docs[#docs+1]=doc
    return doc,fake
end
local function spec()
    return {operation='respond',question={first={row=1,col=0},last={row=2,col=4}},
        output={first={row=2,col=4},last={row=4,col=4}},input_ref='frozen-input',dependencies_ref='frozen-deps',schedule=false}
end
local function settle(target)
    for _=1,1000 do
        local r=T.step(target)
        if r.status~='waiting' then return r end
    end
    error('target did not settle')
end
describe('response target admission before IO',function()
    after_each(function()for _,doc in ipairs(docs)do D.detach(doc)end;docs={}end)
    it('provides the bounded target adapter',function()assert.is_true(ok,tostring(T))end)
    if not ok then return end
    -- #261 M4 W13: a step that throws cancels the target and says why, so the
    -- slot and the two user captures it holds are released.
    it('cancels itself when its step throws',function()
        local doc=fixture();local cancelled
        local value=spec();value.schedule=true
        local repair=D.repair_step
        D.repair_step=function()error('target exploded')end
        local ok_start,err=pcall(function()
            assert(T.start(doc,value,{cancelled=function(reason)cancelled=reason end}))
            assert(vim.wait(500,function()return cancelled~=nil end,5),'the target never settled')
        end)
        D.repair_step=repair
        assert(ok_start,err)
        assert.truthy(tostring(cancelled):find('target exploded',1,true))
        assert.equals(0,D.user_guard_stats(doc).live)
    end)
    it('captures immediately while opaque and calls readiness only after bounded confirmation',function()
        local doc,fake=fixture();local ready
        local target=assert(T.start(doc,spec(),{ready=function(value)ready=value end}))
        assert.is_nil(ready);assert.equals('waiting',T.snapshot(target).status)
        assert.equals(3,D.user_guard_stats(doc).live)
        local reads=0;local original=fake.driver.text
        fake.driver.text=function(...)reads=reads+1;return original(...)end
        local result=settle(target)
        assert.equals('ready',result.status);assert.is_table(ready)
        assert.equals(D.query(doc,1,2)[1].handle,ready.entity)
        assert.equals(5+#'💬: question'+1+4,ready.first)
        assert.equals('frozen-input',ready.input_ref);assert.is_false(ready.input_stale)
        assert.equals(0,D.user_guard_stats(doc).live);assert.is_true(reads>0 and reads<=#fake.lines+2)
    end)
    it('performs at most one bounded native read per step for a long selected question',function()
        local doc,fake=fixture();local body=string.rep('x',100000)
        fake:edit(2,0,2,4,{body})
        local value=spec();value.question.last.col=#body;value.output.first.col=#body
        local reads=0;local original=fake.driver.text
        fake.driver.text=function(...)
            reads=reads+1;local result=original(...)
            assert.is_true(#table.concat(result,'\n')<=4096)
            return result
        end
        local target=assert(T.start(doc,value,{}));assert.equals(0,reads)
        local result
        for _=1,200 do
            local before=reads;result=T.step(target);assert.is_true(reads-before<=1)
            assert.is_false(result.input_stale,'structural repair alone is not input edit evidence')
            if result.status~='waiting'then break end
        end
        assert.equals('ready',result.status);assert.is_true(reads>20)
    end)
    it('relocates a fixed selection without staling excluded prefix edits',function()
        local doc,fake=fixture();local ready
        local target=assert(T.start(doc,spec(),{ready=function(value)ready=value end}))
        fake:set_lines(0,0,{'prefix'})
        assert.equals('ready',settle(target).status)
        assert.equals(2,ready.question_row);assert.is_false(ready.input_stale)
        assert.equals(#'prefix'+1+5+#'💬: question'+1+4,ready.first)
        assert.equals(#'prefix'+1+5,ready.dependencies[1].first)
    end)
    it('cancels equal-byte source replacement and never admits after text restoration',function()
        local doc,fake=fixture();local calls=0
        local target=assert(T.start(doc,spec(),{ready=function()calls=calls+1 end}))
        fake:edit(2,0,2,4,{'body'})
        assert.equals('cancelled',T.snapshot(target).status)
        assert.is_true(T.snapshot(target).input_stale)
        assert.equals('cancelled',settle(target).status);assert.equals(0,calls)
        assert.equals(0,D.user_guard_stats(doc).live)
    end)
    it('rejects a changed marker role after upstream context changes without recapturing',function()
        local doc,fake=fixture();local target=assert(T.start(doc,spec(),{}))
        fake:set_lines(0,0,{'---'})
        fake:set_lines(#fake.lines,#fake.lines,{'---'})
        -- The original marker remains byte-identical but is now inside the header.
        local result=settle(target);assert.equals('cancelled',result.status)
    end)
    it('bounds pending targets and releases capacity on cancellation and detach',function()
        local doc=fixture();local targets={}
        for i=1,4 do local value=spec();value.operation='op'..i;targets[i]=assert(T.start(doc,value,{}))end
        local refused,reason=T.start(doc,spec(),{})
        assert.is_nil(refused);assert.equals('target limit',reason)
        assert.is_true(T.cancel(targets[1],'user'))
        targets[5]=assert(T.start(doc,spec(),{}));D.detach(doc)
        for _,target in ipairs(targets)do assert.equals('cancelled',T.snapshot(target).status)end
        assert.equals(0,D.user_guard_stats(doc).live)
    end)
    it('preserves unanswered insertion targets and never rereads a moved cursor',function()
        local doc=fixture();local value=spec()
        value.question={first={row=5,col=0},last={row=6,col=5}}
        value.output={first={row=6,col=5},last={row=6,col=5}}
        local ready;local target=assert(T.start(doc,value,{ready=function(v)ready=v end}))
        assert.equals('ready',settle(target).status);assert.equals(ready.first,ready.last)
        assert.equals(5,ready.question_row)
    end)
    it('cancels on reload and keeps terminal notifications idempotent',function()
        local doc,fake=fixture();local cancelled=0
        local target=assert(T.start(doc,spec(),{cancelled=function()cancelled=cancelled+1 end}))
        fake:reload({'💬: question','body','🤖: answer','text'})
        assert.equals('cancelled',T.snapshot(target).status)
        T.cancel(target);T.step(target);assert.equals(1,cancelled)
    end)
    it('tracks included prefix evidence while deferring structural repair',function()
        local doc,fake=fixture();local value=spec();value.input_prefix=true
        local ready;local target=assert(T.start(doc,value,{ready=function(v)ready=v end}))
        fake:edit(0,0,0,4,{'LEAD'});fake:edit(0,0,0,4,{'lead'})
        assert.is_true(T.snapshot(target).input_stale)
        assert.equals('waiting',T.snapshot(target).status)
        assert.equals('ready',settle(target).status);assert.is_true(ready.input_stale)
        assert.equals(0,ready.dependencies[1].first);assert.equals(0,D.user_guard_stats(doc).live)
    end)
    it('releases target guards if dependency capture exceeds bounded capacity',function()
        local doc=fixture();local occupied={}
        for i=1,62 do occupied[i]=assert(D.capture_user(doc,{operation='occupy'..i,
            regions={{first={row=6,col=0},last={row=6,col=1}}}}))end
        assert.equals(62,D.user_guard_stats(doc).live)
        local target,reason=T.start(doc,spec(),{})
        assert.is_nil(target);assert.equals('capacity',reason);assert.equals(62,D.user_guard_stats(doc).live)
        for _,guard in ipairs(occupied)do D.cancel_user(doc,guard)end
    end)

end)
