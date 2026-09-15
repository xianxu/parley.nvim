local S=require('parley.document.structure')
local G=require('parley.document.grammar')
local patterns=require('parley.highlight_structure').patterns({})
local function span(text)
    local _,token=G.lex_step(G.lex_start(patterns),text,true,{bytes=65536})
    return {rows=1,bytes=#text+1,metadata={token=token}}
end
local function fixture()
    local doc=S.new({span('💬: question'),span('🤖: answer'),span('body'),span('tail'),span('suffix')},patterns)
    for _=1,100 do if S.repair_step(doc,nil,{rows=256,nodes=65536,entries=65536}).status=='idle' then return doc end end
    error('fixture did not converge')
end
local function begin(doc)
    return S.begin_deferred_fragment(doc,2,4,1,#'bodytail'+1,
        {rows=256,bytes=65536,nodes=65536,entries=65536})
end

describe('deferred native fragment validation',function()
    it('gates authority until final text preserves the untouched suffix',function()
        local doc=fixture()
        local suffix=S.at(doc,4)
        assert.equals('deferred',begin(doc).status)
        assert.is_false(S.lookup(doc,suffix.handle).metadata.confirmed)
        assert.equals('deferred',S.repair_step(doc).status)
        local result=S.finish_deferred_fragment(doc,{span('bodytail')})
        assert.is_true(result.reused_suffix)
        assert.equals('idle',S.repair_step(doc).status)
        assert.same(suffix.metadata,S.lookup(doc,suffix.handle).metadata)
        assert.equals(3,S.lookup(doc,suffix.handle).start_row)
    end)
    it('continues unrelated semantic work after a locally valid finalization',function()
        local doc=S.new({span('💬: question'),span('🤖: answer'),span('body'),span('tail'),
            span('suffix'),span('💬: next'),span('🤖: next answer'),span('unrepaired')},patterns)
        for _=1,100 do
            S.repair_step(doc,nil,{rows=1,nodes=65536,entries=65536})
            if S.at(doc,3).metadata.confirmed then break end
        end
        assert.is_true(S.at(doc,3).metadata.confirmed)
        assert.is_not_true(S.at(doc,7).metadata.confirmed)
        assert.equals('deferred',begin(doc).status)
        local result=S.finish_deferred_fragment(doc,{span('bodytail')})
        assert.is_true(result.reused_suffix)
        assert.equals('more',result.status)
        local last
        for _=1,100 do last=S.repair_step(doc,nil,{rows=1,nodes=65536,entries=65536});if last.status=='idle' then break end end
        assert.equals('idle',last.status)
        assert.is_true(S.at(doc,6).metadata.confirmed)
    end)
    it('rejects a structural marker even when final extent matches',function()
        local doc=fixture()
        local text='💬: next'
        assert.equals('deferred',S.begin_deferred_fragment(doc,2,4,1,#text+1,
            {rows=256,bytes=65536,nodes=65536,entries=65536}).status)
        local result=S.finish_deferred_fragment(doc,{span(text)})
        assert.is_not_true(result.reused_suffix)
        assert.is_nil(S.at(doc,2).metadata)
    end)
    it('cancels saved proof on intervening edits and reload',function()
        local doc=fixture()
        begin(doc)
        S.splice(doc,2,3,{span('human')})
        assert.has_error(function() S.finish_deferred_fragment(doc,{span('bodytail')}) end)
        for _=1,100 do if S.repair_step(doc,nil,{rows=256,nodes=65536,entries=65536}).status=='idle' then break end end
        assert.equals('text',S.at(doc,2).metadata.token.kind)
        doc=fixture();begin(doc)
        S.reload(doc,{span('human reload')})
        assert.has_error(function() S.finish_deferred_fragment(doc,{span('bodytail')}) end)
        assert.equals(#'human reload'+1,S.size(doc).bytes)
    end)
end)

describe('deferred callback coordination',function()
    local D=require('parley.document')
    local Fake=require('tests.helpers.fake_document_editor')
    local nextbuf=98000
    local function delayed_join(body)
        body=body or 'body'
        nextbuf=nextbuf+1
        local fake=Fake.new({'💬: question','🤖: answer',body,'tail','suffix'})
        local doc=D.attach(nextbuf,{driver=fake.driver,schedule=false})
        assert.equals('idle',D.drain(doc,1000).status)
        local old=vim.deepcopy(fake.lines)
        fake.before_delivery=function(f)
            local final=f.lines
            f.lines=old
            f.after_delivery=function(current) current.lines=final end
        end
        fake:edit(2,#body,3,0,{''})
        assert.is_false(D.query(doc,3,4)[1].metadata.confirmed)
        return doc,fake
    end
    it('materializes the final frame in bounded lexical and semantic steps',function()
        local doc,fake=delayed_join()
        assert.equals('more',D.repair_step(doc).status)
        local result=D.repair_step(doc)
        assert.equals('idle',result.status)
        assert.is_true(result.work.rows_processed<=2)
        assert.is_true((result.work.bytes_scanned or 0)<=65536)
        assert.equals('bodytail',fake.lines[3])
        assert.is_true(D.query(doc,3,4)[1].metadata.confirmed)
        D.detach(doc)
    end)
    it('streams a long joined row through the default byte budget',function()
        local doc,fake=delayed_join(string.rep('x',20000))
        local steps=0
        local result
        repeat
            result=D.repair_step(doc)
            steps=steps+1
            assert.is_true((result.work.bytes_scanned or 0)<=4096)
            assert.is_true((result.work.rows_processed or 0)<=1)
        until result.status=='idle' or steps>=20
        assert.equals('idle',result.status)
        assert.is_true(steps>=6)
        assert.equals(string.rep('x',20000)..'tail',fake.lines[3])
        D.detach(doc)
    end)
    it('honors tiny lexical and finalization budgets without consuming authority',function()
        local doc=delayed_join()
        local result=D.repair_step(doc,{bytes=0,rows=0,nodes=0,entries=0})
        assert.equals('budget',result.status)
        for _=1,8 do
            result=D.repair_step(doc,{bytes=1,rows=1,nodes=0,entries=0})
            assert.is_true((result.work.bytes_scanned or 0)<=1)
            assert.is_true((result.work.rows_processed or 0)<=1)
            assert.equals(0,result.work.nodes_visited)
        end
        result=D.repair_step(doc,{bytes=1,rows=1,nodes=0,entries=0})
        assert.equals('budget',result.status)
        assert.is_true(result.required.nodes>0)
        assert.is_false(D.query(doc,3,4)[1].metadata.confirmed)
        assert.equals('idle',D.repair_step(doc).status)
        D.detach(doc)
    end)
    it('cancels before rapid edits, inverse edits, and reload can reuse stale evidence',function()
        for _,action in ipairs({'human','inverse','reload'}) do
            local doc,fake=delayed_join()
            if action=='human' then fake:edit(2,0,2,0,{'💬: '})
            elseif action=='inverse' then fake:edit(2,4,2,4,{'',''})
            else fake:reload({'💬: replacement','new human text'}) end
            assert.equals('idle',D.drain(doc,1000).status)
            assert.equals(#fake.lines,D.size(doc).rows)
            if action=='human' then
                assert.equals('user',D.query(doc,2,3)[1].metadata.token.kind)
            elseif action=='inverse' then
                assert.same({'body','tail'},{fake.lines[3],fake.lines[4]})
            else assert.equals('user',D.query(doc,0,1)[1].metadata.token.kind) end
            D.detach(doc)
        end
    end)
end)
