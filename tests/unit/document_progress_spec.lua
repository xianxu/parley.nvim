local Document=require('parley.document')
local Fake=require('tests.helpers.fake_document_editor')
local next_buffer=98000
local docs={}
local function attach(lines)
    next_buffer=next_buffer+1
    local fake=Fake.new(lines)
    local doc=Document.attach(next_buffer,{driver=fake.driver,schedule=false})
    docs[#docs+1]=doc
    return doc,fake
end
local function bounded_step(doc)
    local result=Document.repair_step(doc,{rows=1,bytes=4096,nodes=32768,entries=32768})
    assert.is_true((result.work.bytes_scanned or 0)<=4096)
    assert.is_true((result.work.nodes_visited or 0)<=32768)
    assert.is_true((result.work.entries_visited or 0)<=32768)
    return result
end

describe('same-document repair progress',function()
    after_each(function()
        for _,doc in ipairs(docs) do Document.detach(doc) end
        docs={}
    end)
    it('keeps an active answer scope progressing through repeated disjoint Enter and joins',function()
        local lines={'💬: question','draft','🤖: answer'}
        for _=1,40 do lines[#lines+1]='body' end
        lines[#lines+1]='💬: next'
        local doc,fake=attach(lines)
        local sections={}
        for _=1,1000 do
            local result=bounded_step(doc)
            for _,delta in ipairs(result.deltas or {}) do
                if delta.kind=='section' then sections[#sections+1]=delta.handle end
            end
            if #sections>0 then break end
        end
        assert.equals(1,#sections)
        local expected={}
        for _,span in ipairs(Document.query(doc,3,43)) do expected[#expected+1]=span.handle end
        assert.equals(expected[1],sections[1])
        local edited
        local off=Document.subscribe(doc,function(event)if event.kind=='edit' then edited=event end end)
        for i=2,#expected do
            if i%2==0 then fake:edit(1,2,1,2,{'',''})
            else fake:edit(1,2,2,0,{''}) end
            assert.is_true(edited.reused_suffix)
            local advanced=false
            for _=1,4 do
                local result=bounded_step(doc)
                for _,delta in ipairs(result.deltas or {}) do
                    if delta.kind=='section' then
                        assert.equals(expected[i],delta.handle)
                        advanced=true
                    end
                end
                if advanced then break end
            end
            assert.is_true(advanced,'disjoint newline edits restarted the active scope')
        end
        off()
    end)
    it('finishes a distant opaque row while inert edits arrive before every repair slice',function()
        local doc,fake=attach({'💬: question','draft','🤖: answer','body','💬: next'})
        assert.equals('idle',Document.drain(doc,1000).status)
        local long=string.rep('x',131072)
        fake:edit(3,0,3,4,{long})
        local bytes=0
        for i=1,1000 do
            fake:edit(1,0,1,1,{i%2==0 and 'd' or 'D'})
            local result=bounded_step(doc)
            bytes=bytes+(result.work.bytes_scanned or 0)
            if result.status=='idle' then
                assert.is_true(bytes>=#long)
                assert.is_true(Document.query(doc,3,4)[1].metadata.confirmed)
                return
            end
        end
        error('disjoint inert edits starved lexical repair; parsed bytes='..bytes)
    end)
    it('relocates unread lexical requests across repeated preceding row shifts',function()
        local doc,fake=attach({'💬: question','draft','🤖: answer','body','💬: next'})
        assert.equals('idle',Document.drain(doc,1000).status)
        local long=string.rep('z',73728)
        fake:edit(3,0,3,4,{long})
        local bytes=0
        for i=1,500 do
            if i%2==1 then fake:edit(1,2,1,2,{'',''}) else fake:edit(1,2,2,0,{''}) end
            local result=bounded_step(doc)
            bytes=bytes+(result.work.bytes_scanned or 0)
            if bytes>=#long then
                local row=i%2==1 and 4 or 3
                assert.equals(#long+1,Document.query(doc,row,row+1)[1].bytes)
                return
            end
        end
        error('relocated lexical request did not progress: '..bytes)
    end)
    it('rejects an overlapping unread intent and does no read below its navigation budget',function()
        local doc,fake=attach({'💬: question','draft','🤖: answer','body','💬: next'})
        assert.equals('idle',Document.drain(doc,1000).status)
        fake:edit(3,0,3,4,{string.rep('x',73728)})
        local requested=false
        for _=1,100 do if bounded_step(doc).status=='read' then requested=true;break end end
        assert.is_true(requested)
        local native=fake.driver.text;local reads=0
        fake.driver.text=function(...)reads=reads+1;return native(...)end
        local result=Document.repair_step(doc,{rows=1,bytes=128,nodes=1,entries=1})
        assert.equals('budget',result.status);assert.equals(0,reads)
        fake:edit(3,0,3,73728,{'replacement'})
        reads=0
        result=bounded_step(doc)
        assert.equals('stale',result.status);assert.equals(0,reads)
        assert.equals('idle',Document.drain(doc,1000).status)
        assert.equals(12,Document.query(doc,3,4)[1].bytes)
    end)

end)
