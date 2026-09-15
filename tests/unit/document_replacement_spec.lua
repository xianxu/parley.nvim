local loaded,Replacement=pcall(require,'parley.document.replacement')
local D=require('parley.document')
local Fake=require('tests.helpers.fake_document_editor')
local serial=190000
local docs={}
local function fixture(body)
    serial=serial+1
    local fake=Fake.new({'💬: q','',body or 'old answer','💬: next','tail'})
    local doc=D.attach(serial,{driver=fake.driver,schedule=false});docs[#docs+1]=doc
    assert.equals('idle',D.drain(doc,10000).status)
    local rows=D.query(doc,0,5)
    local gen=D.transition(doc,{kind='register_generation'}).generation
    local result=D.transition(doc,{kind='acquire',generation=gen,regions={{entity=rows[1].handle,
        first=rows[3].start_byte,last=rows[3].end_byte-1,revision=1,marker_revision=1,confirmed=true}}})
    assert.is_true(result.ok,result.reason)
    return doc,fake,{epoch=D.snapshot(doc).epoch,generation=gen,grant=result.grants[1],entity=rows[1].handle,
        revision=1,operation='replacement',bytes='new answer'}
end
local function finish(doc,cursor)
    for _=1,10000 do
        local result=D.replace_step(doc,cursor)
        if result.status=='applied' or result.status=='stale' or result.status=='error'then return result end
        D.repair_step(doc)
    end
    error('replacement did not finish')
end
describe('owned document replacement',function()
    after_each(function()for _,doc in ipairs(docs)do D.detach(doc)end;docs={}end)
    it('provides private replacement cursors',function()assert.is_true(loaded)end)
    it('replaces the owned body and preserves the next question',function()
        local doc,fake,intent=fixture()
        local cursor=assert(D.replace_new(doc,intent))
        assert.equals('applied',finish(doc,cursor).status)
        assert.same({'💬: q','','new answer','💬: next','tail'},fake.lines)
    end)
    it('bounds source reads across slow 70 KiB replacement slices',function()
        local doc,fake,intent=fixture(string.rep('界',24000))
        intent.bytes=string.rep('λ',36000)
        local read,maxread=0,0;local prior=fake.driver.text
        fake.driver.text=function(...)
            local rows=prior(...);local n=#table.concat(rows,'\n');read=read+n;maxread=math.max(maxread,n);return rows
        end
        local cursor=assert(D.replace_new(doc,intent));local removed,accepted=0,0
        for _=1,1000 do
            local result=D.replace_step(doc,cursor)
            removed=removed+result.removed_bytes;accepted=accepted+result.accepted_bytes
            if result.status=='applied' then break end
            assert.equals('more',result.status)
            fake:edit(4,0,4,1,{'z'})
            for _=1,8 do D.repair_step(doc) end
        end
        assert.equals(72000,removed);assert.equals(72000,accepted)
        assert.equals(intent.bytes,fake.lines[3]);assert.equals('💬: next',fake.lines[4])
        assert.is_true(maxread<=4096,tostring(maxread));assert.is_true(read<72000*5,tostring(read))
        assert.equals('idle',D.drain(doc,10000).status)
    end)
    it('reports mutation before an error once and never replays',function()
        local doc,fake,intent=fixture();local cursor=assert(D.replace_new(doc,intent))
        fake.mutate_then_error=true
        local r=D.replace_step(doc,cursor)
        assert.equals('error',r.status);assert.equals(10,r.removed_bytes)
        fake.mutate_then_error=false
        assert.equals(0,D.replace_step(doc,cursor).removed_bytes)
        assert.equals('',fake.lines[3])
    end)
    it('rejects equal-length human source replacement',function()
        local doc,fake,intent=fixture();local cursor=assert(D.replace_new(doc,intent))
        fake:edit(2,0,2,10,{'old answer'})
        assert.equals('stale',D.replace_step(doc,cursor).status)
    end)
    it('pauses for a disjoint footer change that affects incoming semantics',function()
        local doc,fake,intent=fixture();local cursor=assert(D.replace_new(doc,intent))
        fake:edit(4,0,4,4,{'[^x]: later'})
        assert.equals('suspended',D.replace_step(doc,cursor).status)
        assert.equals('idle',D.drain(doc,10000).status)
        assert.equals('applied',finish(doc,cursor).status)
    end)
    it('continues while an unrelated later exchange needs structural repair',function()
        local doc,fake,intent=fixture();local cursor=assert(D.replace_new(doc,intent))
        fake:edit(4,0,4,4,{'💬: later'})
        assert.equals('valid',D.snapshot(doc).grants[intent.grant].status)
        assert.equals('more',D.replace_step(doc,cursor).status)
        assert.equals('applied',finish(doc,cursor).status)
        assert.equals('💬: later',fake.lines[5])
    end)
    it('cancellation releases deferred source reads without confirming text',function()
        local doc,_,intent=fixture(string.rep('x',70000));local cursor=assert(D.replace_new(doc,intent))
        assert.equals('more',D.replace_step(doc,cursor).status)
        assert.is_false(D.query(doc,2,3)[1].metadata and D.query(doc,2,3)[1].metadata.confirmed or false)
        D.replace_cancel(doc,cursor)
        assert.equals('idle',D.drain(doc,10000).status)
        assert.equals('cancelled',D.replace_step(doc,cursor).status)
    end)
    it('narrows only the completed captured payload prefix',function()
        local doc,fake,intent=fixture();intent.bytes='answer\n💬: next draft';intent.retain_prefix=6
        local cursor=assert(D.replace_new(doc,intent))
        assert.equals('applied',finish(doc,cursor).status)
        local g=D.snapshot(doc).grants[intent.grant]
        assert.equals(6,g.last-g.first)
        assert.equals('💬: next draft',fake.lines[4])
    end)
    it('supports a protected prefix and refuses physical entity overlap',function()
        local doc,_,intent=fixture();intent.first_offset=1
        assert.equals('applied',finish(doc,assert(D.replace_new(doc,intent))).status)
        local doc2,_,bad=fixture();local grant=D.snapshot(doc2).grants[bad.grant]
        bad.first_offset=-1
        assert.is_nil(D.replace_new(doc2,bad));assert.is_true(grant.last>grant.first)
    end)
end)

describe('replacement lifetime',function()
    after_each(function()for _,doc in ipairs(docs)do D.detach(doc)end;docs={}end)
    it('relocates after a preceding disjoint row insertion',function()
        local doc,fake,intent=fixture();local cursor=assert(D.replace_new(doc,intent))
        fake:set_lines(0,0,{'preamble'})
        assert.equals('idle',D.drain(doc,10000).status)
        assert.equals('applied',finish(doc,cursor).status)
        assert.same({'preamble','💬: q','','new answer','💬: next','tail'},fake.lines)
    end)
    it('releases mutation deferral on revocation and reload',function()
        for _,reload in ipairs({false,true}) do
            local doc,fake,intent=fixture(string.rep('x',70000))
            local cursor=assert(D.replace_new(doc,intent));D.replace_step(doc,cursor)
            if reload then fake:reload({'💬: replaced'}) else D.transition(doc,{kind='revoke',grant=intent.grant}) end
            assert.equals('idle',D.drain(doc,10000).status)
            assert.equals('stale',D.replace_step(doc,cursor).status)
        end
    end)
    it('counts the last receipt when reload retires the cursor inside native apply',function()
        local doc,fake,intent=fixture();local cursor=assert(D.replace_new(doc,intent))
        fake.after_delivery=function()fake:reload({'💬: replacement'})end
        local r=D.replace_step(doc,cursor)
        assert.equals('stale',r.status);assert.equals(10,r.removed_bytes)
        assert.equals(0,D.replace_step(doc,cursor).removed_bytes)
    end)
    it('refuses stale revisions and UTF-8 interior offsets before mutation',function()
        local doc,_,intent=fixture('界body');intent.first_offset=1
        assert.is_nil(D.replace_new(doc,intent));intent.first_offset=0;intent.revision=2
        assert.is_nil(D.replace_new(doc,intent))
    end)
end)

describe('native replacement composition',function()
    local buf,doc
    after_each(function()
        if doc then D.detach(doc);doc=nil end
        if buf and vim.api.nvim_buf_is_valid(buf) then vim.api.nvim_buf_delete(buf,{force=true}) end
    end)
    local function open(lines)
        buf=vim.api.nvim_create_buf(false,true);vim.api.nvim_buf_set_lines(buf,0,-1,false,lines)
        doc=D.attach(buf,{schedule=false});assert.equals('idle',D.drain(doc,10000).status)
        local q=D.query(doc,0,1)[1];local gen=D.transition(doc,{kind='register_generation'}).generation
        local r=D.transition(doc,{kind='acquire',generation=gen,regions={{entity=q.handle,
            first=q.end_byte-1,last=D.size(doc).bytes-1,revision=1,marker_revision=1,confirmed=true}}})
        assert.is_true(r.ok,r.reason)
        return {epoch=D.snapshot(doc).epoch,generation=gen,grant=r.grants[1],entity=q.handle,
            operation='native replacement',revision=1,bytes='🤖: new answer',first_offset=1}
    end
    it('bootstraps an EOF question newline then replaces the fresh blank row',function()
        local intent=open({'💬: question'})
        local r
        repeat r=D.append(doc,{epoch=intent.epoch,generation=intent.generation,entity=intent.entity,
            grant=intent.grant,operation='bootstrap',revision=1,bytes='\n'}) until r.status~='more'
        assert.equals(1,r.accepted_bytes)
        assert.equals('idle',D.drain(doc,10000).status)
        intent.revision=D.snapshot(doc).grants[intent.grant].revision
        local cursor=assert(D.replace_new(doc,intent))
        assert.equals('applied',finish(doc,cursor).status)
        assert.equals('idle',D.drain(doc,10000).status)
        assert.same({'💬: question','🤖: new answer'},vim.api.nvim_buf_get_lines(buf,0,-1,false))
        assert.equals(intent.entity,D.query(doc,0,1)[1].handle)
    end)
    it('keeps the question newline outside physical regeneration patches',function()
        local intent=open({'💬: question','🤖: old answer','old body'})
        intent.first_offset=0
        assert.is_nil(D.replace_new(doc,intent))
        intent.first_offset=1
        assert.equals('applied',finish(doc,assert(D.replace_new(doc,intent))).status)
        assert.equals('idle',D.drain(doc,10000).status)
        assert.same({'💬: question','🤖: new answer'},vim.api.nvim_buf_get_lines(buf,0,-1,false))
        assert.equals(intent.entity,D.query(doc,0,1)[1].handle)
    end)
end)
