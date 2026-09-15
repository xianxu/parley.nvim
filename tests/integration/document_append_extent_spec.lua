local D=require('parley.document')
local Grammar=require('parley.document.grammar')
local Lex=require('parley.document.lexical')
local buffers={}
local function settle(doc)assert.equals('idle',D.drain(doc,10000).status)end

describe('owned blank-line append extent',function()
    after_each(function()
        for _,buf in ipairs(buffers)do if vim.api.nvim_buf_is_valid(buf)then vim.api.nvim_buf_delete(buf,{force=true})end end
        buffers={}
    end)
    for _,bytes in ipairs({'\n','text\n','🧠: thought\n','first\nsecond\n'})do
        it('retains the source tail row for '..vim.inspect(bytes),function()
            local buf=vim.api.nvim_create_buf(false,true);buffers[#buffers+1]=buf
            vim.api.nvim_buf_set_lines(buf,0,-1,false,{'💬: q','🤖: a',''})
            local doc=D.attach(buf,{schedule=false});settle(doc)
            local rows=D.query(doc,0,3)
            local generation=D.transition(doc,{kind='register_generation'}).generation
            local acquired=D.transition(doc,{kind='acquire',generation=generation,regions={{
                entity=rows[1].handle,first=rows[3].start_byte,last=rows[3].start_byte,
                revision=1,marker_revision=1,confirmed=true}}})
            assert.is_true(acquired.ok,acquired.reason)
            local edited;D.subscribe(doc,function(e)if e.kind=='edit'then edited=e end end)
            local result=D.append(doc,{epoch=D.snapshot(doc).epoch,generation=generation,
                grant=acquired.grants[1],entity=rows[1].handle,revision=1,operation='stream',bytes=bytes})
            assert.equals(#bytes,result.accepted_bytes)
            assert.is_false(edited.deferred_fragment,'known append tokens must not become speculative plain text')
            local known=D.query(doc,2,vim.api.nvim_buf_line_count(buf))
            for _,row in ipairs(known)do assert.is_false(row.opaque or false)end
            settle(doc)
            local lines=vim.api.nvim_buf_get_lines(buf,0,-1,false)
            rows=D.query(doc,0,#lines)
            for i,line in ipairs(lines)do
                local _,token=Grammar.lex_step(Grammar.lex_start(Lex.patterns({})),line,true,{bytes=65536})
                assert.is_true(Grammar.same_token(token,rows[i].metadata.token))
                assert.equals(#line+1,rows[i].bytes)
                assert.is_true(rows[i].metadata.confirmed)
            end
        end)
    end
    it('repairs only the active answer for a first thinking chunk in a 5000-row transcript',function()
        local lines={'# topic: locality','---'}
        for _=1,1249 do vim.list_extend(lines,{'💬: q','🤖: a','body',''})end
        vim.list_extend(lines,{'💬: current','🤖: current',''})
        local buf=vim.api.nvim_create_buf(false,true);buffers[#buffers+1]=buf
        vim.api.nvim_buf_set_lines(buf,0,-1,false,lines)
        local doc=D.attach(buf,{schedule=false});assert.equals('idle',D.drain(doc,50000,{rows=256,bytes=65536,nodes=32768,entries=65536}).status)
        local rows=D.query(doc,#lines-3,#lines)
        local generation=D.transition(doc,{kind='register_generation'}).generation
        local acquired=D.transition(doc,{kind='acquire',generation=generation,regions={{entity=rows[1].handle,
            first=rows[3].start_byte,last=rows[3].start_byte,revision=1,marker_revision=1,confirmed=true}}})
        assert.is_true(acquired.ok,acquired.reason)
        local reader=require('parley.line_reader');local processed=0
        local observer=reader.set_observer(buf,function(event)processed=processed+(event.structure_rows_processed or 0)end)
        local result=D.append(doc,{epoch=D.snapshot(doc).epoch,generation=generation,grant=acquired.grants[1],
            entity=rows[1].handle,revision=1,operation='stream',bytes='🧠: thought\n'})
        assert.equals(#'🧠: thought\n',result.accepted_bytes)
        local uncertain=D.uncertain_range(doc)
        assert.is_true(not uncertain or uncertain.first>=#lines-3,vim.inspect(uncertain))
        settle(doc);reader.clear_observer(buf,observer)
        assert.is_true(processed<=16,tostring(processed))
    end)
    it('prepares a new answer header without invalidating 5000 historical rows',function()
        local lines={'# topic: locality','- file: locality.md','---',''}
        for _=1,624 do
            vim.list_extend(lines,{'💬: q','','🤖: a','','🧠: thought','detail','','body'})
        end
        while #lines<4999 do lines[#lines+1]=''end
        lines[#lines+1]='💬: current'
        local buf=vim.api.nvim_create_buf(false,true);buffers[#buffers+1]=buf
        vim.api.nvim_buf_set_lines(buf,0,-1,false,lines)
        local doc=D.attach(buf,{schedule=false});assert.equals('idle',D.drain(doc,50000,{rows=256,bytes=65536,nodes=32768,entries=65536}).status)
        local question=D.query(doc,#lines-1,#lines)[1]
        local generation=D.transition(doc,{kind='register_generation'}).generation
        local acquired=D.transition(doc,{kind='acquire',generation=generation,regions={{entity=question.handle,
            first=question.end_byte-1,last=question.end_byte-1,revision=1,marker_revision=1,confirmed=true}}})
        assert.is_true(acquired.ok,acquired.reason)
        local intent={epoch=D.snapshot(doc).epoch,generation=generation,grant=acquired.grants[1],
            entity=question.handle,revision=1,operation='bootstrap',bytes='\n'}
        local result
        repeat result=D.append(doc,intent)until result.status~='more'
        assert.equals(1,result.accepted_bytes);settle(doc)
        intent.revision=D.snapshot(doc).grants[intent.grant].revision
        intent.operation='prepare';intent.first_offset=1;intent.bytes='🤖: [PerfFixture]\n\n'
        local cursor=assert(D.replace_new(doc,intent))
        local reader=require('parley.line_reader');local processed=0
        local observer=reader.set_observer(buf,function(event)processed=processed+(event.structure_rows_processed or 0)end)
        result=D.replace_step(doc,cursor)
        assert.equals('applied',result.status)
        local uncertain=D.uncertain_range(doc)
        assert.is_true(not uncertain or uncertain.first>=#lines-1,vim.inspect(uncertain))
        settle(doc);reader.clear_observer(buf,observer)
        assert.is_true(processed<=16,tostring(processed))
    end)
    for _,during_final in ipairs({false,true})do
        it('honors cancellation '..(during_final and 'inside the final receipt' or 'before the final receipt'),function()
            local buf=vim.api.nvim_create_buf(false,true);buffers[#buffers+1]=buf
            vim.api.nvim_buf_set_lines(buf,0,-1,false,{'💬: q','🤖: a',''})
            local doc=D.attach(buf,{schedule=false});settle(doc)
            local rows=D.query(doc,0,3)
            local generation=D.transition(doc,{kind='register_generation'}).generation
            local acquired=D.transition(doc,{kind='acquire',generation=generation,regions={{entity=rows[1].handle,
                first=rows[3].start_byte,last=rows[3].start_byte,revision=1,marker_revision=1,confirmed=true}}})
            local payload=during_final and 'new answer' or string.rep('x',4097)
            local cursor=assert(D.replace_new(doc,{epoch=D.snapshot(doc).epoch,generation=generation,
                grant=acquired.grants[1],entity=rows[1].handle,revision=1,operation='prepare',bytes=payload}))
            if during_final then
                D.subscribe(doc,function(event)if event.kind=='edit'then D.replace_cancel(doc,cursor)end end)
            end
            local result=D.replace_step(doc,cursor)
            if during_final then assert.equals('cancelled',result.status);assert.equals(#payload,result.accepted_bytes)
            else
                assert.equals('more',result.status);assert.equals(4096,result.accepted_bytes)
                D.replace_cancel(doc,cursor)
            end
            assert.equals(0,D.replace_step(doc,cursor).accepted_bytes)
            settle(doc)
            assert.equals(during_final and payload or payload:sub(1,4096),vim.api.nvim_buf_get_lines(buf,2,3,false)[1])
        end)
    end
end)
