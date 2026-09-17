local D=require('parley.document')
local Fake=require('tests.helpers.fake_document_editor')
local Lex=require('parley.document.lexical')
local serial=99000
local docs={}
local function fixture(body)
    serial=serial+1
    local fake=Fake.new({'💬: q','draft','🤖: answer',body or ''})
    local doc=D.attach(serial,{driver=fake.driver,schedule=false})
    docs[#docs+1]=doc
    assert.equals('idle',D.drain(doc,1000).status)
    local entity=D.query(doc,2,3)[1].handle
    local generation=D.transition(doc,{kind='register_generation'}).generation
    local acquired=D.transition(doc,{kind='acquire',generation=generation,regions={{entity=entity,
        marker_revision=1,revision=1,first=D.query(doc,2,3)[1].start_byte,last=D.size(doc).bytes-1,confirmed=true}}})
    assert.is_true(acquired.ok)
    local grant=acquired.grants[1]
    -- #266 M1: write authority now includes the document's write turn.
    assert.is_true(D.transition(doc,{kind='request_turn',generation=generation}).ok)
    local function intent(bytes)
        return {epoch=D.snapshot(doc).epoch,generation=generation,grant=grant,entity=entity,
            revision=D.snapshot(doc).grants[grant].revision,operation='stream',bytes=bytes}
    end
    return doc,fake,intent,grant
end

describe('owned bounded append',function()
    after_each(function()for _,doc in ipairs(docs) do D.detach(doc) end;docs={}end)
    it('provides an intent-only append and reusable lexical snapshot',function()
        assert.is_function(D.append);assert.is_function(Lex.lex_token)
    end)
    if not D.append then return end
    it('appends a growing single line without reading or rewriting its prefix',function()
        local doc,fake,intent=fixture()
        local reads,patched,largest=0,0,0
        local text,set=fake.driver.text,fake.driver.set_text
        fake.driver.text=function(buf,sr,sc,er,ec)
            assert.equals(sr,er);reads=reads+ec-sc;largest=math.max(largest,ec-sc)
            return text(buf,sr,sc,er,ec)
        end
        fake.driver.set_text=function(buf,sr,sc,er,ec,lines)
            assert.equals(sr,er);assert.equals(sc,ec)
            patched=patched+#table.concat(lines,'\n');return set(buf,sr,sc,er,ec,lines)
        end
        for _=1,40 do
            local result=D.append(doc,intent(string.rep('x',4096)))
            assert.equals(4096,result.accepted_bytes)
            assert.is_true(result.work.lexer_retained_bytes<128)
            assert.equals(1,result.work.append_cursors)
            assert.is_true(result.status=='applied' or result.status=='suspended')
            assert.equals('idle',D.drain(doc,1000).status)
        end
        assert.equals(string.rep('x',163840),fake.lines[4])
        assert.equals(163840,patched);assert.is_true(reads<=patched+4096);assert.is_true(largest<=4096)
    end)
    it('bootstraps a preexisting tail in bounded slices and rejects stale requests',function()
        local doc,fake,intent=fixture(string.rep('a',9000))
        local request=intent('tail')
        local calls=0
        repeat
            local result=D.append(doc,request);calls=calls+1
            assert.is_true((result.work.bytes_scanned or 0)<=4096)
            if result.accepted_bytes>0 then break end
            assert.equals('more',result.status)
        until calls>10
        assert.equals(string.rep('a',9000)..'tail',fake.lines[4])
        assert.equals(4,calls)
        assert.equals(0,D.append(doc,request).accepted_bytes)
    end)
    it('snapshots lexical suffix changes without finalizing or mutating prior tokens',function()
        local cursor=Lex.lex_start()
        Lex.lex_step(cursor,'🧠:[END]',false,{bytes=4096})
        local prior=Lex.lex_token(cursor);assert.equals('reasoning_end',prior.kind)
        Lex.lex_step(cursor,' trailing',false,{bytes=4096})
        assert.equals('reasoning',Lex.lex_token(cursor).kind)
        assert.equals('reasoning_end',prior.kind)
    end)
    it('preserves split fences and newlines and accounts applied bytes before suspension',function()
        local doc,fake,intent=fixture()
        local suspended=false
        for _,bytes in ipairs({'``','`lua\n','code','\n```','\nplain'}) do
            local result=D.append(doc,intent(bytes))
            assert.equals(#bytes,result.accepted_bytes)
            suspended=suspended or result.status=='suspended'
            if result.status=='suspended' then
                local blocked=D.append(doc,intent('must wait'))
                assert.equals('suspended',blocked.status);assert.equals(0,blocked.accepted_bytes)
            end
            assert.equals('idle',D.drain(doc,1000).status)
        end
        assert.is_true(suspended)
        assert.same({'💬: q','draft','🤖: answer','```lua','code','```','plain'},fake.lines)
    end)
    it('keeps a tail cursor through disjoint human edits and immediately preceding child insertions',function()
        local doc,fake,intent,parent=fixture('body')
        local marker=D.query(doc,2,3)[1]
        -- Delegate an empty slot immediately before the answer's body row.
        local generation=intent('').generation
        local child=D.transition(doc,{kind='acquire',generation=generation,parent=parent,regions={{entity=marker.handle,
            marker_revision=1,revision=1,first=marker.end_byte,last=marker.end_byte,confirmed=true}}})
        assert.is_true(child.ok)
        assert.equals('refused',D.append(doc,intent('no parent write')).status)
        -- A separate leaf at the actual tail excludes the child's boundary.
        local tail=D.transition(doc,{kind='acquire',generation=generation,parent=parent,regions={{entity=marker.handle,
            marker_revision=1,revision=1,first=marker.end_byte+1,last=D.size(doc).bytes-1,confirmed=true}}})
        assert.is_true(tail.ok)
        local leaf=tail.grants[1]
        local function leaf_intent(bytes)
            local q=intent(bytes);q.grant=leaf;q.revision=D.snapshot(doc).grants[leaf].revision;return q
        end
        assert.equals('more',D.append(doc,leaf_intent('x')).status)
        assert.equals(1,D.append(doc,leaf_intent('x')).accepted_bytes)
        fake:edit(1,0,1,1,{'D'})
        local child_grant=D.snapshot(doc).grants[child.grants[1]]
        local pos=marker.end_byte
        local result=D.apply(doc,{epoch=D.snapshot(doc).epoch,generation=generation,operation='child',entity=marker.handle,
            grant=child_grant.id,revision=child_grant.revision,patches={{start={row=3,col=0,byte=pos},
                finish={row=3,col=0,byte=pos},expected_old='',text='child\n'}}})
        assert.is_true(#result.receipts>0)
        assert.equals('idle',D.drain(doc,1000).status)
        local appended=D.append(doc,leaf_intent('tail'))
        assert.equals(4,appended.accepted_bytes,'neighbor insertion must not force tail bootstrap')
        assert.equals('bodyxtail',fake.lines[5])
    end)
    it('rejects output edits and reload epochs without resurrecting cursors',function()
        local doc,fake,intent=fixture()
        local request=intent('first')
        assert.equals(5,D.append(doc,request).accepted_bytes);D.drain(doc,1000)
        fake:edit(3,0,3,1,{'F'})
        assert.equals(0,D.append(doc,intent('late')).accepted_bytes)
        fake:reload({'💬: fresh','🤖: fresh',''})
        assert.equals(0,D.append(doc,request).accepted_bytes)
        assert.same({'💬: fresh','🤖: fresh',''},fake.lines)
    end)
    it('reports an exact applied prefix even when native delivery raises afterwards',function()
        local doc,fake,intent=fixture('body')
        assert.equals('more',D.append(doc,intent('x')).status)
        fake.mutate_then_error=true
        local result=D.append(doc,intent('x'))
        assert.equals('error',result.status);assert.equals(1,result.accepted_bytes)
        assert.equals('bodyx',fake.lines[4])
        fake.mutate_then_error=false
    end)

    it('uses native zero-width insertion across a 64KiB row boundary',function()
        local buf=vim.api.nvim_create_buf(false,true)
        vim.api.nvim_buf_set_lines(buf,0,-1,false,{'🤖: native',''})
        local doc=D.attach(buf,{schedule=false});docs[#docs+1]=doc
        assert.equals('idle',D.drain(doc,1000).status)
        local entity=D.query(doc,0,1)[1].handle
        local generation=D.transition(doc,{kind='register_generation'}).generation
        local acquired=D.transition(doc,{kind='acquire',generation=generation,regions={{entity=entity,
            first=0,last=D.size(doc).bytes-1,marker_revision=1,revision=1,confirmed=true}}})
        assert.is_true(acquired.ok)
        for _=1,18 do
            local grant=D.snapshot(doc).grants[acquired.grants[1]]
            local result=D.append(doc,{epoch=D.snapshot(doc).epoch,generation=generation,entity=entity,
                grant=grant.id,revision=grant.revision,operation=7,bytes=string.rep('n',4096)})
            assert.equals(4096,result.accepted_bytes)
            assert.equals('idle',D.drain(doc,1000).status)
        end
        assert.equals(73728,#vim.api.nvim_buf_get_lines(buf,1,2,false)[1])
        vim.api.nvim_buf_delete(buf,{force=true})
    end)

    it('invalidates cursor state after an unexpected callback without replaying its accepted prefix',function()
        local doc,fake,intent=fixture('body')
        assert.equals('more',D.append(doc,intent('x')).status)
        fake.after_delivery=function(f)f:edit(1,0,1,1,{'D'})end
        local result=D.append(doc,intent('x'))
        assert.equals('interrupted',result.status);assert.equals(1,result.accepted_bytes)
        assert.equals('bodyx',fake.lines[4])
        local next_result=D.append(doc,intent('next'))
        assert.equals('more',next_result.status);assert.equals(0,next_result.accepted_bytes)
    end)
    it('refuses foreign identities and oversized chunks before reading or mutating',function()
        local doc,fake,intent=fixture('body')
        local reads=0;local text=fake.driver.text
        fake.driver.text=function(...)reads=reads+1;return text(...)end
        for _,field in ipairs({'epoch','generation','entity','revision'}) do
            local request=intent('x');request[field]='foreign'
            assert.equals(0,D.append(doc,request).accepted_bytes)
        end
        assert.equals('refused',D.append(doc,intent(string.rep('x',4097))).status)
        assert.equals('refused',D.append(doc,intent(string.rep('\n',256))).status)
        assert.equals(0,reads);assert.equals('body',fake.lines[4])
    end)

    it('releases retained cursor state when its generation finishes',function()
        local doc,_,intent=fixture()
        local result=D.append(doc,intent('x'));assert.equals(1,result.work.append_cursors)
        local request=intent('late')
        D.transition(doc,{kind='finish_generation',generation=request.generation})
        result=D.append(doc,request)
        assert.equals(0,result.accepted_bytes);assert.equals(0,result.work.append_cursors)
        assert.equals(0,result.work.lexer_retained_bytes)
    end)

end)
