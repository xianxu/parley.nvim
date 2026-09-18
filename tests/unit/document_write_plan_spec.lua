-- Adversarial traces through the real coordinator and editor. Expected text is
-- computed from chosen actions, never from receipts or the grant reducer.
local D=require('parley.document')
local Fake=require('tests.helpers.fake_document_editor')
local nextbuf=98000
local fixtures={}
local function serialized(lines) return table.concat(lines,'\n')..'\n' end
local function rows(text) return vim.split(text:sub(1,-2),'\n',{plain=true}) end
local function offset(lines,row,col)
    local byte=col
    for i=1,row do byte=byte+#lines[i]+1 end
    return byte
end
local function patch(text,row,col,old_length,inserted)
    local lines=rows(text)
    local first=offset(lines,row,col)
    return {start={row=row,col=col,byte=first},finish={row=row,col=col+old_length,byte=first+old_length},
        expected_old=text:sub(first+1,first+old_length),text=inserted}
end
local function changed(text,p)
    assert.equals(p.expected_old,text:sub(p.start.byte+1,p.finish.byte))
    return text:sub(1,p.start.byte)..p.text..text:sub(p.finish.byte+1)
end
local function settle(c) assert.equals('idle',D.drain(c.doc,100000).status) end
local function actual(c)
    return serialized(c.fake and c.fake.lines or vim.api.nvim_buf_get_lines(c.buf,0,-1,false))
end
local function check(c) assert.equals(c.expected,actual(c)) end
local function attach(lines,native)
    local c={expected=serialized(lines)}
    if native then
        c.buf=vim.api.nvim_create_buf(false,true)
        vim.api.nvim_buf_set_lines(c.buf,0,-1,false,lines)
        c.doc=D.attach(c.buf,{schedule=false})
    else
        nextbuf=nextbuf+1;c.buf=nextbuf;c.fake=Fake.new(lines)
        c.doc=D.attach(c.buf,{schedule=false,driver=c.fake.driver})
    end
    fixtures[#fixtures+1]=c;settle(c);return c
end
local function acquire(c,row,last_row,generation)
    local indexed=D.query(c.doc,row,last_row+1)
    generation=generation or D.transition(c.doc,{kind='register_generation'}).generation
    local result=D.transition(c.doc,{kind='acquire',generation=generation,
        regions={{entity=indexed[1].handle,marker_revision=1,revision=1,first=indexed[1].start_byte,
            last=indexed[#indexed].end_byte-1,confirmed=true}}})
    assert.is_true(result.ok,result.reason)
    return {generation=generation,grant=result.grants[1],entity=indexed[1].handle}
end
local function plan(c,writer,patches)
    local snapshot=D.snapshot(c.doc)
    return {epoch=snapshot.epoch,generation=writer.generation,operation='trace-write',grant=writer.grant,
        entity=writer.entity,revision=snapshot.grants[writer.grant].revision,patches=patches}
end
local function apply(c,p,status)
    local before=vim.deepcopy(p)
    local result=D.apply(c.doc,p)
    assert.same(before,p,'applying must not rewrite the planned patch or revision')
    assert.equals(status or 'applied',result.status,result.error)
    if result.status=='applied' then for _,edit in ipairs(p.patches) do c.expected=changed(c.expected,edit) end end
    check(c)
    return result
end
local function human(c,row,col,old_length,text)
    local edit=patch(c.expected,row,col,old_length,text)
    if c.fake then c.fake:edit(row,col,row,col+old_length,vim.split(text,'\n',{plain=true}))
    else vim.api.nvim_buf_set_text(c.buf,row,col,row,col+old_length,vim.split(text,'\n',{plain=true})) end
    c.expected=changed(c.expected,edit);check(c)
end
local function writers(native)
    local c=attach({'💬: first','🤖: first','same','💬: second','🤖: second','same','💬: next','draft'},native)
    return c,acquire(c,1,2),acquire(c,4,5)
end

describe('adversarial document write plans',function()
    after_each(function()
        for _,c in ipairs(fixtures) do
            D.detach(c.doc)
            if not c.fake and vim.api.nvim_buf_is_valid(c.buf) then vim.api.nvim_buf_delete(c.buf,{force=true}) end
        end
        fixtures={}
    end)
    for _,native in ipairs({false,true}) do
        it('keeps two writers independent while the human drafts the next question ('..(native and 'Neovim' or 'stateful fake')..')',function()
            local c,a,b=writers(native)
            local old_b=plan(c,b,{patch(c.expected,5,1,1,'B')})
            human(c,7,5,0,' human')
            apply(c,plan(c,a,{patch(c.expected,2,4,0,'A')}))
            assert.equals('valid',D.snapshot(c.doc).grants[b.grant].status)
            apply(c,old_b,'stale') -- A's growth moved B's absolute coordinates.
            apply(c,plan(c,b,{patch(c.expected,5,1,1,'B')}))
            assert.equals('valid',D.snapshot(c.doc).grants[a.grant].status)
            check(c)
        end)
    end
    it('requires fresh plans after disjoint human insertion moves both grants',function()
        local c,a,b=writers()
        local stale_a=plan(c,a,{patch(c.expected,2,1,1,'A')})
        local stale_b=plan(c,b,{patch(c.expected,5,1,1,'B')})
        human(c,0,#'💬: first',0,' more\nquestion continuation')
        settle(c)
        assert.equals('valid',D.snapshot(c.doc).grants[a.grant].status)
        assert.equals('valid',D.snapshot(c.doc).grants[b.grant].status)
        apply(c,stale_a,'stale');apply(c,stale_b,'stale')
        apply(c,plan(c,a,{patch(c.expected,3,1,1,'A')}))
        apply(c,plan(c,b,{patch(c.expected,6,1,1,'B')}))
    end)
    it('executes a fixed multipatch plan against successive exact revisions',function()
        local c,a=writers()
        local first=patch(c.expected,2,1,1,'XX')
        local second=patch(changed(c.expected,first),2,3,1,'YY')
        local p=plan(c,a,{first,second})
        local result=apply(c,p)
        assert.equals(2,#result.receipts)
        assert.equals(p.revision+2,D.snapshot(c.doc).grants[a.grant].revision)
        apply(c,p,'stale')
    end)
    it('rejects an identical-byte target in the other writer region',function()
        local c,a,b=writers()
        local wrong=plan(c,a,{patch(c.expected,5,1,1,'X')})
        assert.equals('a',wrong.patches[1].expected_old)
        apply(c,wrong,'stale')
        assert.equals('valid',D.snapshot(c.doc).grants[a.grant].status)
        apply(c,plan(c,b,{patch(c.expected,5,1,1,'B')}))
    end)
    it('stops a multipatch write after a nested human edit and never revives its grant',function()
        local c,a,b=writers()
        local first=patch(c.expected,2,1,1,'A')
        local second=patch(changed(c.expected,first),2,2,1,'Z')
        local p=plan(c,a,{first,second})
        local frozen=vim.deepcopy(p)
        c.expected=changed(c.expected,first)
        c.fake.after_delivery=function() human(c,2,2,1,'H') end
        local result=D.apply(c.doc,p)
        assert.equals('interrupted',result.status)
        assert.equals(2,#result.receipts)
        assert.same(frozen,p);check(c)
        assert.equals('revoked',D.snapshot(c.doc).grants[a.grant].status)
        settle(c)
        assert.equals('revoked',D.snapshot(c.doc).grants[a.grant].status)
        apply(c,plan(c,a,{patch(c.expected,2,1,1,'NO')}),'stale')
        apply(c,plan(c,b,{patch(c.expected,5,1,1,'B')}))
    end)
    it('rejects old plans after native undo and fake reload even when bytes return',function()
        local c,a=writers(true)
        vim.api.nvim_set_current_buf(c.buf)
        local p=plan(c,a,{patch(c.expected,2,1,1,'A')})
        local original=c.expected
        apply(c,p)
        vim.cmd('undo');c.expected=original;check(c);settle(c)
        assert.equals('revoked',D.snapshot(c.doc).grants[a.grant].status)
        apply(c,p,'stale')
        local f,b=writers()
        local old=plan(f,b,{patch(f.expected,2,1,1,'A')})
        f.fake:reload(rows(f.expected));settle(f)
        apply(f,old,'stale')
    end)
    it('preserves exact partial progress through writer failures and permits fresh disjoint plans',function()
        local c,a,b=writers()
        local first=patch(c.expected,2,1,1,'A')
        local second=patch(changed(c.expected,first),2,2,1,'Z')
        local p=plan(c,a,{first,second})
        local frozen=vim.deepcopy(p)
        c.fake.fail_before=true
        local failed=D.apply(c.doc,p)
        assert.equals('error',failed.status);assert.equals(0,#failed.receipts);check(c)
        c.fake.fail_before=false;c.fake.mutate_then_error=true
        local partial=D.apply(c.doc,p)
        c.fake.mutate_then_error=false
        c.expected=changed(c.expected,first)
        assert.equals('error',partial.status);assert.equals(1,#partial.receipts)
        assert.same(frozen,p);check(c)
        apply(c,p,'stale')
        apply(c,plan(c,b,{patch(c.expected,5,1,1,'B')}))
        apply(c,plan(c,a,{patch(c.expected,2,2,1,'fresh')}))
    end)

    it('matches an independent text oracle across seeded interleavings and replay attempts',function()
        local c,a,b=writers()
        local seed=254
        local function random(n) seed=(seed*48271)%2147483647;return seed%n end
        local saved={}
        for i=1,36 do
            local choice=random(4)
            if choice==0 then human(c,7,#rows(c.expected)[8],0,'h')
            elseif choice==1 and #saved>0 then apply(c,saved[random(#saved)+1],'stale')
            else
                local writer,row=a,2
                if choice==3 then writer,row=b,5 end
                local p=plan(c,writer,{patch(c.expected,row,#rows(c.expected)[row+1],0,tostring(i%10))})
                apply(c,p);saved[#saved+1]=p
            end
            assert.equals('valid',D.snapshot(c.doc).grants[a.grant].status)
            assert.equals('valid',D.snapshot(c.doc).grants[b.grant].status)
            check(c)
        end
    end)
end)
