local ok,D=pcall(require,'parley.document')
local Fake=require('tests.helpers.fake_document_editor')
local nextbuf=90000
local function attach(lines)
    nextbuf=nextbuf+1; local f=Fake.new(lines)
    local d=D.attach(nextbuf,{driver=f.driver,schedule=false})
    return d,f,nextbuf
end
local function settle(d)
    local result=D.drain(d,1000); assert.equals('idle',result.status)
end
describe('document coordinator',function()
    it('provides the coordinator',function() assert.is_true(ok) end)
    if not ok then return end
    it('attaches once, starts opaque, and repairs outside the callback',function()
        local d,f,b=attach({'💬: question','🤖: answer','body'})
        assert.equals(d,D.get(b)); assert.equals(d,D.attach(b))
        assert.is_true(D.query(d,0,1)[1].opaque)
        settle(d)
        assert.equals('user',D.query(d,0,1)[1].metadata.token.kind)
        assert.is_true(D.query(d,2,3)[1].metadata.confirmed)
        D.detach(d); assert.is_nil(D.get(b))
    end)
    it('preserves header identity through Enter and retires touched marker bytes',function()
        local d,f=attach({'💬: question','body'}); settle(d)
        local handle=D.query(d,0,1)[1].handle
        f:edit(0,#'💬: question',0,#'💬: question',{'','more'})
        assert.equals(handle,D.query(d,0,1)[1].handle)
        settle(d); assert.equals(3,D.size(d).rows)
        f:edit(0,0,0,#'💬:',{'💬:'})
        assert.is_not_equal(handle,D.query(d,0,1)[1].handle)
        settle(d); D.detach(d)
    end)
    it('handles edits inside huge opaque spans and canonical whole-buffer deletion',function()
        local lines={}; for i=1,500 do lines[i]='row' end
        local d,f=attach(lines)
        f:edit(250,1,250,2,{'XX'})
        assert.equals(500,D.size(d).rows); assert.equals(2001,D.size(d).bytes)
        f:set_lines(0,-1,{})
        assert.same({rows=1,bytes=1},D.size(d))
        settle(d); assert.equals('blank',D.query(d,0,1)[1].metadata.token.kind)
        D.detach(d)
    end)
    it('revokes authority immediately and invalidates reload and detach epochs',function()
        local d,f,b=attach({'🤖: answer','body'}); settle(d)
        local entity=D.query(d,0,1)[1].handle
        local gen=D.transition(d,{kind='register_generation'}).generation
        local acquired=D.transition(d,{kind='acquire',generation=gen,regions={{entity=entity,
            marker_revision=1,revision=1,first=0,last=D.size(d).bytes,confirmed=true}}})
        assert.is_true(acquired.ok)
        f:edit(1,1,1,2,{'X'})
        assert.equals('revoked',D.snapshot(d).grants[acquired.grants[1]].status)
        local epoch=D.snapshot(d).epoch
        f:reload({'💬: fresh'}); assert.is_not_equal(epoch,D.snapshot(d).epoch)
        settle(d); assert.same({},D.snapshot(d).grants)
        D.detach(d); assert.is_nil(D.get(b))
        assert.is_false(D.transition(d,{kind='register_generation'}).ok)
    end)
    it('publishes bounded change notifications and ignores stale scheduled work',function()
        local d,f=attach({'text'}); local events={}
        local off=D.subscribe(d,function(e) events[#events+1]=e.kind end)
        settle(d); f:edit(0,1,0,1,{'x'}); settle(d)
        assert.is_true(vim.tbl_contains(events,'edit')); assert.is_true(vim.tbl_contains(events,'repair'))
        off(); local n=#events; f:reload({'new'}); settle(d); assert.equals(n,#events)
        D.detach(d); assert.equals('detached',D.repair_step(d).status)
    end)
    it('applies only an owned patch and keeps a disjoint writer live',function()
        local d,f=attach({'🤖: first','one','🤖: second','two'}); settle(d)
        local gen=D.transition(d,{kind='register_generation'}).generation
        local rows=D.query(d,0,4)
        local acquired=D.transition(d,{kind='acquire',generation=gen,regions={
            {entity=rows[1].handle,marker_revision=1,revision=1,first=0,last=rows[2].end_byte-1,confirmed=true},
            {entity=rows[3].handle,marker_revision=1,revision=1,first=rows[3].start_byte,last=rows[4].end_byte-1,confirmed=true}}})
        assert.is_true(acquired.ok)
        local plan={epoch=D.snapshot(d).epoch,generation=gen,entity=rows[1].handle,grant=acquired.grants[1],
            patches={{start={row=1,col=1,byte=rows[2].start_byte+1},
                finish={row=1,col=2,byte=rows[2].start_byte+2},expected_old='n',text='XX'}}}
        assert.equals('applied',D.apply(d,plan).status)
        assert.equals('oXXe',f.lines[2])
        assert.equals('valid',D.snapshot(d).grants[acquired.grants[2]].status)
        D.detach(d)
    end)
    it('drops obsolete long-line read requests through edits and reload',function()
        local d,f=attach({string.rep('a',10000)})
        assert.equals('read',D.repair_step(d).status)
        f:reload({'short'}); settle(d)
        assert.equals(6,D.size(d).bytes)
        f:edit(0,0,0,0,{'x'}); settle(d)
        assert.equals(7,D.size(d).bytes); D.detach(d)
    end)
    it('observes real Neovim line replacement and canonical empty buffer',function()
        local b=vim.api.nvim_create_buf(false,true)
        vim.api.nvim_buf_set_lines(b,0,-1,false,{'💬: hi','body','tail'})
        local d=D.attach(b,{schedule=false}); settle(d)
        vim.api.nvim_buf_set_lines(b,1,2,false,{'one','two'})
        settle(d); assert.equals(4,D.size(d).rows)
        vim.api.nvim_buf_set_lines(b,0,-1,false,{})
        assert.same({rows=1,bytes=1},D.size(d)); settle(d)
        vim.api.nvim_buf_delete(b,{force=true}); assert.is_nil(D.get(b))
    end)
    it('keeps exact extents through seeded joins, splits, and replacements',function()
        local d,f=attach({'alpha','beta','gamma'}); settle(d)
        local seed=42
        local function random(n) seed=(seed*48271)%2147483647;return seed%n end
        for _=1,80 do
            local row=random(#f.lines); local col=random(#f.lines[row+1]+1)
            local er=math.min(row+random(2),#f.lines-1)
            local ec=er==row and col or random(#f.lines[er+1]+1)
            local added=random(2)==0 and {'x'} or {'','tail'}
            f:edit(row,col,er,ec,added)
            local bytes=0; for _,line in ipairs(f.lines) do bytes=bytes+#line+1 end
            assert.same({rows=#f.lines,bytes=bytes},D.size(d)); settle(d)
            local indexed=D.query(d,0,#f.lines)
            assert.equals(#f.lines,#indexed)
            for i,line in ipairs(f.lines) do assert.equals(#line+1,indexed[i].bytes) end
        end
        D.detach(d)
    end)
    it('leaves oversized callback payloads opaque without reading their text',function()
        nextbuf=nextbuf+1; local f=Fake.new({'body'}); local reads=0
        local original=f.driver.lines
        f.driver.lines=function(...) reads=reads+1;return original(...) end
        local d=D.attach(nextbuf,{driver=f.driver,schedule=false}); settle(d)
        local before=reads
        f:edit(0,2,0,2,{string.rep('x',100000)})
        assert.equals(before,reads); assert.is_true(D.query(d,0,1)[1].opaque)
        local result=D.repair_step(d); assert.equals('read',result.status)
        assert.equals(4096,result.request.max_bytes)
        D.detach(d)
    end)
    it('keeps native undo and redo extents after Enter and Backspace',function()
        local b=vim.api.nvim_create_buf(false,true); vim.api.nvim_set_current_buf(b)
        vim.api.nvim_buf_set_lines(b,0,-1,false,{'💬: q','🤖: a','answer','💬: next','draft'})
        local d=D.attach(b,{schedule=false}); settle(d)
        vim.cmd('let &undolevels = &undolevels')
        vim.api.nvim_buf_set_text(b,4,2,4,2,{'',''}); settle(d)
        vim.api.nvim_buf_set_text(b,4,2,5,0,{''}); settle(d)
        vim.cmd('undo'); settle(d)
        assert.equals(vim.api.nvim_buf_get_offset(b,vim.api.nvim_buf_line_count(b)),D.size(d).bytes)
        vim.cmd('redo'); settle(d)
        assert.equals(vim.api.nvim_buf_get_offset(b,vim.api.nvim_buf_line_count(b)),D.size(d).bytes)
        vim.api.nvim_buf_delete(b,{force=true})
    end)
    it('resolves an earlier answer after partial repair while later work remains',function()
        local d,f=attach({'💬: first','🤖: first','one','💬: later','🤖: later','two','tail'})
        settle(d); local rows=D.query(d,0,7)
        local gen=D.transition(d,{kind='register_generation'}).generation
        local r=D.transition(d,{kind='acquire',generation=gen,regions={{entity=rows[2].handle,
            marker_revision=1,revision=1,first=rows[2].start_byte,last=rows[3].end_byte-1,confirmed=true}}})
        assert.is_true(r.ok)
        assert.is_false(D.transition(d,{kind='acquire',generation=gen,regions={{entity=rows[2].handle,
            marker_revision=1,revision=1,first=rows[5].start_byte,last=rows[6].end_byte-1,confirmed=true}}}).ok)
        f:edit(5,0,5,3,{'💬: changed'})
        local resumed=false
        for _=1,100 do
            local result=D.repair_step(d)
            if D.snapshot(d).grants[r.grants[1]].status=='valid' then
                assert.is_not_equal('idle',result.status); resumed=true; break
            end
        end
        assert.is_true(resumed); D.detach(d)
    end)
end)
