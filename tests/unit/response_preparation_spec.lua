local P=require('parley.response_preparation')
local L=require('parley.response_layout')
local D=require('parley.document')
local Fake=require('tests.helpers.fake_document_editor')
local config={chat_branch_prefix='🌿:',chat_local_prefix='🔒:'}
local serial=240000
local docs={}
local buffers={}
local function setup(body,eof,native)
    local lines={'💬: q'};for _,line in ipairs(body) do lines[#lines+1]=line end
    if not eof then lines[#lines+1]='💬: next' end
    local fake=Fake.new(lines);serial=serial+1
    local doc
    if native then
        local buf=vim.api.nvim_create_buf(false,true);buffers[#buffers+1]=buf
        vim.api.nvim_buf_set_lines(buf,0,-1,false,lines)
        doc=D.attach(buf,{schedule=false});fake.buf=buf
    else doc=D.attach(serial,{driver=fake.driver,schedule=false})end
    docs[#docs+1]=doc
    assert.equals('idle',D.drain(doc,10000).status)
    local row=D.query(doc,0,1)[1]
    local layout=L.prepare({lines=body,first_row=1,first_byte=#lines[1]+1,header_lines={'🤖: agent'}},config)
    local spec=P.plan(layout,{at_eof=eof,bootstrap_newline=eof and #body==0})
    local generation=D.transition(doc,{kind='register_generation'}).generation
    local regions={}
    for _,gap in ipairs(spec.gaps) do regions[#regions+1]={entity=row.handle,first=gap.first_byte,
        last=gap.last_byte,revision=1,marker_revision=1,confirmed=true} end
    local acquired=D.transition(doc,{kind='acquire',generation=generation,regions=regions})
    assert.is_true(acquired.ok,acquired.reason)
    local extras={};for i=2,#acquired.grants do extras[#extras+1]=acquired.grants[i] end
    local ctx={epoch=D.snapshot(doc).epoch,generation=generation,grant=acquired.grants[1],
        entity=row.handle,operation='prepare',preparation_grants=extras,input={frozen=true},cancelled=function()return false end}
    return doc,fake,ctx,spec
end
local function drain(op)
    for _=1,10000 do local result=P.step(op);if result.status~='more' then return result end end
    error('preparation did not finish')
end

describe('finite response preparation',function()
    after_each(function()for _,doc in ipairs(docs)do D.detach(doc)end;docs={}
        for _,buf in ipairs(buffers)do if vim.api.nvim_buf_is_valid(buf)then vim.api.nvim_buf_delete(buf,{force=true})end end;buffers={}end)
    it('preserves raw annotations and revokes cleanup grants before publishing prepared input',function()
        local doc,fake,ctx,spec=setup({'','🤖: old','answer','🌿: child.md: child','old [🌿: λ](x.md) text','tail'},false)
        local calls={}
        local op=assert(P.start(doc,ctx,{prepared=function(input)
            assert.same({frozen=true},input)
            for _,id in ipairs(ctx.preparation_grants)do assert.equals('revoked',D.snapshot(doc).grants[id].status)end
            calls[#calls+1]='prepared'
        end,resolved=function()calls[#calls+1]='resolved'end},spec,{schedule=false}))
        assert.equals('applied',drain(op).status)
        assert.same({'💬: q','','🤖: agent','','🌿: child.md: child','[🌿: λ](x.md)','💬: next'},fake.lines)
        assert.same({'prepared','resolved'},calls)
        assert.is_not_equal('revoked',D.snapshot(doc).grants[ctx.grant].status)
        assert.equals('idle',D.drain(doc,10000).status)
    end)
    it('preserves every survivor if cancelled midway through a large deletion',function()
        local doc,fake,ctx,spec=setup({'',string.rep('x',14000),'🔒: mine','tail'},false)
        local resolved=0;local prepared=false
        local op=assert(P.start(doc,ctx,{prepared=function()prepared=true end,resolved=function()resolved=resolved+1 end},spec,{schedule=false}))
        P.step(op);P.step(op)
        assert.truthy(table.concat(fake.lines,'\n'):find('🔒: mine',1,true))
        assert.is_true(P.cancel(op));assert.is_false(P.cancel(op))
        assert.equals('cancelled',P.step(op).status);assert.equals(1,resolved);assert.is_false(prepared)
        for _,g in pairs(D.snapshot(doc).grants)do assert.equals('revoked',g.status)end
        assert.equals('idle',D.drain(doc,10000).status)
    end)
    for _,native in ipairs({false,true})do
        it('lets a human edit protected annotation bytes between cleanup gaps '..tostring(native),function()
            local doc,fake,ctx,spec=setup({'','old','🔒: mine','generated tail'},false,native)
            local op=assert(P.start(doc,ctx,{prepared=function()end,resolved=function()end},spec,{schedule=false}))
            P.step(op)
            local lines=native and vim.api.nvim_buf_get_lines(fake.buf,0,-1,false) or fake.lines
            local found
            for i,line in ipairs(lines)do if line=='🔒: mine'then found=i-1 end end
            assert.is_not_nil(found)
            if native then vim.api.nvim_buf_set_text(fake.buf,found,#'🔒: ',found,#'🔒: ',{'human '})
            else fake:edit(found,#'🔒: ',found,#'🔒: ',{'human '})end
            local outcome=drain(op)
            assert.equals('applied',outcome.status,outcome.reason)
            lines=native and vim.api.nvim_buf_get_lines(fake.buf,0,-1,false) or fake.lines
            assert.truthy(table.concat(lines,'\n'):find('🔒: human mine',1,true))
        end)
    end
    it('normalizes physical EOF without adding an extra final row',function()
        local doc,fake,ctx,spec=setup({'','🤖: old','answer'},true)
        local op=assert(P.start(doc,ctx,{prepared=function()end,resolved=function()end},spec,{schedule=false}))
        assert.equals('applied',drain(op).status)
        assert.same({'💬: q','','🤖: agent',''},fake.lines)
    end)
    it('bootstraps an unanswered EOF question without replacing its marker',function()
        local doc,fake,ctx,spec=setup({},true)
        local identity=ctx.entity
        local op=assert(P.start(doc,ctx,{prepared=function()end,resolved=function()end},spec,{schedule=false}))
        assert.equals('applied',drain(op).status)
        assert.same({'💬: q','','🤖: agent',''},fake.lines)
        assert.equals(identity,D.lookup(doc,identity).handle)
    end)
    it('reports a mutate-then-error once and resolves only after local work is retired',function()
        local doc,fake,ctx,spec=setup({'','answer','🔒: mine'},false)
        local failed,resolved,prepared=0,0,0
        local op=assert(P.start(doc,ctx,{failed=function()failed=failed+1 end,resolved=function()resolved=resolved+1 end,
            prepared=function()prepared=prepared+1 end},spec,{schedule=false}))
        fake.mutate_then_error=true
        local result=drain(op)
        assert.equals('error',result.status);assert.equals(1,failed);assert.equals(1,resolved);assert.equals(0,prepared)
        assert.truthy(table.concat(fake.lines,'\n'):find('🔒: mine',1,true))
        fake.mutate_then_error=false
        assert.equals('error',P.step(op).status);assert.equals(1,resolved)
    end)
    it('yields native timers between slices and preserves the real next question',function()
        local doc,fake,ctx,spec=setup({'',string.rep('x',24000),'🌿: child.md: child','tail'},false,true)
        local prepared=false;local observed
        local op=assert(P.start(doc,ctx,{prepared=function()prepared=true end,resolved=function()end},spec))
        vim.defer_fn(function()observed=prepared end,2)
        assert.is_true(vim.wait(2000,function()return observed~=nil end,1))
        assert.is_false(observed)
        assert.is_true(vim.wait(4000,function()return P.snapshot(op).status~='more'end,1))
        assert.equals('applied',P.snapshot(op).status)
        assert.same({'💬: q','','🤖: agent','','🌿: child.md: child','💬: next'},
            vim.api.nvim_buf_get_lines(fake.buf,0,-1,false))
    end)
    it('bootstraps the native final row and leaves its question identity live',function()
        local doc,fake,ctx,spec=setup({},true,true)
        local op=assert(P.start(doc,ctx,{prepared=function()end,resolved=function()end},spec,{schedule=false}))
        assert.equals('applied',drain(op).status)
        assert.same({'💬: q','','🤖: agent',''},vim.api.nvim_buf_get_lines(fake.buf,0,-1,false))
        assert.is_not_nil(D.lookup(doc,ctx.entity))
    end)
    it('refuses a pre-IO source edit before performing any preparation mutation',function()
        local doc,fake,ctx,spec=setup({'','answer'},false)
        fake:edit(2,0,2,6,{'human!'})
        local before=table.concat(fake.lines,'\n')
        local op=P.start(doc,ctx,{},spec,{schedule=false})
        assert.is_nil(op);assert.equals(before,table.concat(fake.lines,'\n'))
    end)
    it('retires scheduled work immediately on reload',function()
        local doc,fake,ctx,spec=setup({'','answer'},false)
        local resolved=0
        local op=assert(P.start(doc,ctx,{resolved=function()resolved=resolved+1 end},spec))
        fake:reload({'💬: replacement'})
        assert.equals('cancelled',P.snapshot(op).status);assert.equals(1,resolved)
        assert.same({'💬: replacement'},fake.lines)
    end)
end)
