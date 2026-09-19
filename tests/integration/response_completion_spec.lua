local ok,C=pcall(require,'parley.response_completion')
local D=require('parley.document')
local Fake=require('tests.helpers.fake_document_editor')
local serial=298000
local docs,buffers={},{}
local function setup(lines,native)
    serial=serial+1;local editor=Fake.new(lines);local doc
    editor.reads={calls=0,max_bytes=0,full=0}
    for _,name in ipairs({'lines','text'})do
        local read=editor.driver[name]
        editor.driver[name]=function(...)
            local args={...};local result=read(...)
            editor.reads.calls=editor.reads.calls+1
            editor.reads.max_bytes=math.max(editor.reads.max_bytes,#table.concat(result,'\n'))
            if name=='lines' and args[3]<0 then editor.reads.full=editor.reads.full+1 end
            return result
        end
    end
    if native then
        editor.buf=vim.api.nvim_create_buf(false,true);buffers[#buffers+1]=editor.buf
        vim.api.nvim_buf_set_lines(editor.buf,0,-1,false,lines)
        doc=D.attach(editor.buf,{schedule=false})
    else doc=D.attach(serial,{driver=editor.driver,schedule=false})end
    docs[#docs+1]=doc;assert.equals('idle',D.drain(doc,20000).status)
    local rows=D.query(doc,0,3);local generation=D.transition(doc,{kind='register_generation'}).generation
    local acquired=D.transition(doc,{kind='acquire',generation=generation,regions={{entity=rows[1].handle,
        first=rows[2].start_byte,last=rows[3].end_byte-1,revision=1,marker_revision=1,confirmed=true}}})
    assert.is_true(acquired.ok,acquired.reason)
    local ctx={epoch=D.snapshot(doc).epoch,generation=generation,entity=rows[1].handle,
        grant=acquired.grants[1],operation='finalize',cancelled=function()return false end}
    local function text()return native and vim.api.nvim_buf_get_lines(editor.buf,0,-1,false) or editor.lines end
    local function edit(row,col,value)
        if native then vim.api.nvim_buf_set_text(editor.buf,row,col,row,col,{value})else editor:edit(row,col,row,col,{value})end
    end
    return doc,editor,ctx,text,edit
end
local function start(doc,ctx,opts)
    assert.is_true(ok,tostring(C));local calls={}
    local op=assert(C.start(doc,ctx,function(status)calls[#calls+1]=status end,opts or {user_prefix='💬:',schedule=false}))
    return op,calls
end
local function drain(op)
    for _=1,20000 do local r=C.step(op);if r.status~='more'then return r end end
    error('completion did not settle')
end
describe('current indexed response completion',function()
    -- #261 M4 W18: the runner keeps no handle to a finalize, so a completion
    -- must settle on its own when its generation is cancelled mid-finalize.
    it('settles failed on its own when cancelled before it writes',function()
        local doc,_,ctx=setup({'💬: q','🤖: a','text'})
        local cancelled=false
        ctx.cancelled=function()return cancelled end
        local _,calls=start(doc,ctx,{user_prefix='💬:',schedule=true})
        cancelled=true
        assert.is_true(vim.wait(500,function()return #calls==1 end,5))
        assert.same({'failed'},calls)
    end)
    -- #261 M4 W13: a step that throws settles the finalize failed.
    it('settles its finalize failed when its step throws',function()
        local doc,_,ctx=setup({'💬: q','🤖: a','text'})
        ctx.cancelled=function()error('completion exploded')end
        local _,calls=start(doc,ctx,{user_prefix='💬:',schedule=true})
        assert.is_true(vim.wait(500,function()return #calls==1 end,5))
        assert.same({'failed'},calls)
    end)
    after_each(function()
        for _,d in ipairs(docs)do D.detach(d)end;docs={}
        for _,b in ipairs(buffers)do if vim.api.nvim_buf_is_valid(b)then vim.api.nvim_buf_delete(b,{force=true})end end;buffers={}
    end)
    for _,native in ipairs({false,true})do
        it('adds a prompt without deleting trailing blanks '..tostring(native),function()
            local doc,_,ctx,text=setup({'💬: q','🤖: a','answer','',''},native)
            local op,calls=start(doc,ctx);local result=drain(op);assert.equals('applied',result.status,vim.inspect(result))
            assert.same({'💬: q','🤖: a','answer','','💬:','','',''},text())
            assert.same({'applied'},calls);assert.is_false(C.cancel(op))
        end)
        it('preserves annotation and footer bytes '..tostring(native),function()
            local doc,_,ctx,text=setup({'💬: q','🤖: a','answer','🌿: child.md: note','🔒: mine','','[^1]: source'},native)
            local op,calls=start(doc,ctx);local result=drain(op);assert.equals('applied',result.status,vim.inspect(result))
            assert.same({'💬: q','🤖: a','answer','🌿: child.md: note','🔒: mine','','💬:','','','[^1]: source'},text())
            assert.same({'applied'},calls)
        end)
        it('skips a human next question added before finalization '..tostring(native),function()
            local doc,editor,ctx,text=setup({'💬: q','🤖: a','answer','',''},native)
            local op,calls=start(doc,ctx)
            if native then vim.api.nvim_buf_set_lines(editor.buf,4,5,false,{'💬: human','draft'})
            else editor:edit(4,0,4,0,{'💬: human','draft'})end
            local before=vim.deepcopy(text());assert.equals('skipped',drain(op).status)
            assert.same(before,text());assert.same({'applied'},calls)
        end)
    end
    it('recomputes the annotation insertion point after a disjoint edit',function()
        local doc,_,ctx,text,edit=setup({'💬: q','🤖: a','answer','🔒: mine'})
        local op=start(doc,ctx);edit(3,#'🔒: mine',' changed')
        local result=drain(op);assert.equals('applied',result.status,vim.inspect(result))
        assert.equals('🔒: mine changed',text()[4]);assert.equals('💬:',text()[6])
    end)
    it('does not report success after reload or repeated cancellation',function()
        local doc,editor,ctx,text=setup({'💬: q','🤖: a','answer'})
        local op,calls=start(doc,ctx);editor:reload({'💬: replaced'})
        assert.equals('cancelled',drain(op).status);C.cancel(op);C.cancel(op)
        assert.same({'failed'},calls);assert.same({'💬: replaced'},text())
    end)
    it('rejects a revoked target before writing',function()
        local doc,_,ctx,text=setup({'💬: q','🤖: a','answer'})
        local op,calls=start(doc,ctx);D.transition(doc,{kind='revoke',grant=ctx.grant})
        assert.equals('cancelled',drain(op).status)
        assert.same({'failed'},calls);assert.equals(3,#text())
    end)
    it('preserves an unmarked human suffix beyond the owned tip without adding a prompt',function()
        local doc,_,ctx,text=setup({'💬: q','🤖: a','answer','my next draft'})
        local op,calls=start(doc,ctx);assert.equals('skipped',drain(op).status)
        assert.same({'applied'},calls);assert.equals(4,#text())
    end)

    it('rechecks next-question evidence after repairing a long annotation line',function()
        local note='🔒: '..string.rep('x',70000)
        local doc,editor,ctx,text=setup({'💬: q','🤖: a','answer',note,''})
        local op,calls=start(doc,ctx)
        editor:edit(3,#note,3,#note,{' changed'})
        assert.equals('more',C.step(op).status)
        editor:edit(4,0,4,0,{'💬: human'})
        local before=vim.deepcopy(text())
        assert.equals('skipped',drain(op).status);assert.same(before,text())
        assert.same({'applied'},calls)
        local live=0
        for _,g in pairs(D.snapshot(doc).grants)do if g.status~='revoked'then live=live+1 end end
        assert.equals(1,live)
    end)
    it('skips an explicitly marked human draft',function()
        local doc,_,ctx,text=setup({'💬: q','🤖: a','answer','=== draft ===','human','=== end ==='})
        local op=start(doc,ctx);assert.equals('skipped',drain(op).status);assert.equals(6,#text())
    end)
    it('uses indexed summaries across thousands of preserved annotation rows',function()
        local lines={'💬: q','🤖: a','answer'}
        for _=1,2000 do lines[#lines+1]='🔒: protected' end
        local doc,editor,ctx=setup(lines)
        D.stats(doc,true);editor.reads.calls=0
        local target=D.completion(doc,ctx.entity,2)
        assert.equals('ready',target.status)
        local stats=D.stats(doc)
        assert.is_true(stats.nodes_visited<1000,vim.inspect(stats))
        assert.is_true(stats.entries_visited<1000,vim.inspect(stats))
        assert.equals(0,editor.reads.calls)
    end)
    it('finishes native scheduled bounded work and retires before notifying the host',function()
        local doc,_,ctx,text=setup({'💬: q','🤖: a','answer','🔒: '..string.rep('x',12000)},true)
        local op;local seen={}
        op=assert(C.start(doc,ctx,function(status)
            seen={status=status,state=C.snapshot(op).status,cancel=C.cancel(op)}
            error('host callback failed')
        end,{user_prefix='💬:',schedule=true}))
        assert.is_true(vim.wait(3000,function()return C.snapshot(op).status~='more'end,1))
        assert.same({status='applied',state='applied',cancel=false},seen)
        assert.equals('💬:',text()[6])
    end)

    for _,native in ipairs({false,true})do
    it('inserts before owned trailing blank rows without deleting them '..tostring(native),function()
        local doc,_,ctx,text=setup({'💬: q','🤖: a','answer','',''},native)
        local old=D.snapshot(doc).grants[ctx.grant]
        D.transition(doc,{kind='revoke',grant=ctx.grant})
        local last=D.query(doc,4,5)[1]
        ctx.grant=D.transition(doc,{kind='acquire',generation=ctx.generation,regions={{entity=ctx.entity,
            first=old.first,last=last.end_byte-1,revision=1,marker_revision=1,confirmed=true}}}).grants[1]
        local op,calls=start(doc,ctx);local result=drain(op)
        assert.equals('applied',result.status,vim.inspect(result))
        assert.same({'💬: q','🤖: a','answer','','💬:','','',''},text())
        assert.same({'applied'},calls)
    end)

    end

    for _,native in ipairs({false,true})do
    it('releases the inserted question before authority reconciles '..tostring(native),function()
        local doc,_,ctx=setup({'💬: q','🤖: a','answer'},native)
        local original=D.snapshot(doc).grants[ctx.grant].last
        local op=start(doc,ctx);assert.equals('applied',drain(op).status)
        assert.equals('idle',D.drain(doc,10000).status)
        local grant=D.snapshot(doc).grants[ctx.grant]
        assert.equals('valid',grant.status)
        assert.equals(original,grant.last)
        local prompt=D.query(doc,4,5)[1]
        assert.is_true(grant.last<prompt.start_byte)
    end)
    end
    it('rejects reentrant human source edits after the exact prompt receipt',function()
        local doc,editor,ctx=setup({'💬: q','🤖: a','answer'})
        local op,calls=start(doc,ctx)
        editor.after_delivery=function(fake)fake:edit(0,0,0,0,{'human '})end
        assert.equals('cancelled',drain(op).status)
        assert.same({'failed'},calls)
        assert.equals('revoked',D.snapshot(doc).grants[ctx.grant].status)
    end)
    it('reports reload during delivery as cancelled without replaying the prompt',function()
        local doc,editor,ctx,text=setup({'💬: q','🤖: a','answer'})
        local op,calls=start(doc,ctx)
        editor.after_delivery=function(fake)fake:reload({'💬: replacement'})end
        assert.equals('cancelled',drain(op).status)
        assert.same({'failed'},calls);assert.same({'💬: replacement'},text())
    end)

    it('refuses oversized and stale released-insertion requests without narrowing authority',function()
        local doc,_,ctx=setup({'💬: q','🤖: a','answer','',''})
        local before=D.snapshot(doc).grants[ctx.grant]
        local base={epoch=ctx.epoch,generation=ctx.generation,entity=ctx.entity,grant=ctx.grant,
            revision=before.revision,point=before.last,bytes='\n\n💬:\n',operation='completion'}
        for _,change in ipairs({{bytes=string.rep('x',4097)},{bytes=string.rep('\n',256)},
            {revision=before.revision+1},{point=before.last+1},{entity='forged'}})do
            local request=vim.tbl_extend('force',base,change)
            local cursor=D.insert_released_new(doc,request)
            assert.is_nil(cursor)
            assert.same(before,D.snapshot(doc).grants[ctx.grant])
        end
    end)

end)
