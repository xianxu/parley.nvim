local D=require('parley.document')
local docs,buffers={},{}
local function setup(lines,after_write)
    local buf=vim.api.nvim_create_buf(false,true);buffers[#buffers+1]=buf
    vim.api.nvim_buf_set_lines(buf,0,-1,false,lines)
    local native=vim.api.nvim_buf_set_text
    if after_write then vim.api.nvim_buf_set_text=function(...)
        native(...)
        if after_write then local callback=after_write;after_write=nil;callback(buf,native)end
    end end
    local success,doc=pcall(D.attach,buf,{schedule=false});vim.api.nvim_buf_set_text=native
    assert.is_true(success,tostring(doc));docs[#docs+1]=doc
    assert.equals('idle',D.drain(doc,10000).status)
    return doc,buf
end
local function capture(doc,row,kind)
    assert.is_function(D.capture_revision,'Document revision capture is required')
    local result=D.capture_revision(doc,D.query(doc,row,row+1)[1].handle,kind or 'question')
    assert.equals('ready',result.status,vim.inspect(result));return result.token
end
local function status(doc,token)
    assert.equals('idle',D.drain(doc,2000).status)
    return D.validate_revision(doc,token).status
end
local function output(doc,row,bytes,finite,interrupted)
    local span=D.query(doc,row,row+1)[1];local entity=D.exchange(doc,row).identity
    local generation=D.transition(doc,{kind='register_generation'}).generation
    local acquired=D.transition(doc,{kind='acquire',generation=generation,regions={{entity=entity,
        first=span.end_byte-1,last=span.end_byte-1,revision=1,marker_revision=1,confirmed=true}}})
    assert.is_true(acquired.ok,acquired.reason)
    local intent={epoch=D.snapshot(doc).epoch,generation=generation,entity=entity,
        grant=acquired.grants[1],revision=1,operation='answer',bytes=bytes}
    local cursor=finite and assert(D.replace_new(doc,intent))
    for _=1,1000 do
        local result=finite and D.replace_step(doc,cursor) or D.append(doc,intent)
        if result.status~='more' then
            if interrupted then return result
            elseif not finite then assert.equals(#bytes,result.accepted_bytes,vim.inspect(result))
            else assert.equals('applied',result.status,vim.inspect(result))end
            return
        end
    end
    error('output did not finish')
end
describe('captured exchange input revisions',function()
    after_each(function()
        for _,doc in ipairs(docs)do D.detach(doc)end;docs={}
        for _,buf in ipairs(buffers)do if vim.api.nvim_buf_is_valid(buf)then vim.api.nvim_buf_delete(buf,{force=true})end end
        buffers={}
    end)
    it('separates question evidence from changed answer context',function()
        local doc,buf=setup({'💬: first','🤖: before','','💬: next'})
        local question=capture(doc,0);local context=capture(doc,0,'context');local nextq=capture(doc,3)
        vim.api.nvim_buf_set_lines(buf,1,2,false,{'🤖: replacement','more'})
        assert.equals('valid',status(doc,question));assert.equals('conflict',status(doc,context))
        assert.equals('valid',status(doc,nextq))
    end)
    it('rejects equal-text ABA edits while preserving unrelated questions',function()
        local doc,buf=setup({'💬: q','body','','💬: next'})
        local question=capture(doc,0);local nextq=capture(doc,3)
        vim.api.nvim_buf_set_text(buf,1,0,1,4,{'edit'})
        vim.api.nvim_buf_set_text(buf,1,0,1,4,{'body'})
        assert.equals('conflict',status(doc,question));assert.equals('valid',status(doc,nextq))
    end)
    it('includes the question-owned preface and excludes the next one',function()
        local doc,buf=setup({'💬: first','🤖: answer','','@@note@@','💬: next'})
        local context=capture(doc,0,'context');local question=capture(doc,4)
        vim.api.nvim_buf_set_text(buf,3,6,3,6,{' changed'})
        assert.equals('valid',status(doc,context));assert.equals('conflict',status(doc,question))
    end)
    for _,finite in ipairs({false,true})do
        it('preserves question bytes under exact owned output at EOL '..tostring(finite),function()
            local doc=setup({'💬: q','question body'})
            local question=capture(doc,0);local context=capture(doc,0,'context')
            output(doc,1,'\n\n🤖: answer',finite)
            assert.equals('valid',status(doc,question));assert.equals('conflict',status(doc,context))
        end)
    end
    it('does not exempt an external answer insertion at the same question EOL',function()
        local doc,buf=setup({'💬: q','question body'})
        local question=capture(doc,0)
        vim.api.nvim_buf_set_text(buf,1,13,1,13,{'','','🤖: answer'})
        assert.equals('conflict',status(doc,question))
    end)
    for _,finite in ipairs({false,true})do
        it('preserves long question rows without rereading them during newline output '..tostring(finite),function()
            local doc,buf=setup({'💬: q',string.rep('x',70000)})
            local question=capture(doc,0)
            local Reader=require('parley.line_reader');local max_read,full=0,0
            local observer=Reader.set_observer(buf,function(event)
                max_read=math.max(max_read,event.bytes_read or 0);if event.full_buffer then full=full+1 end
            end)
            output(doc,1,'\n\n🤖: answer',finite)
            assert.equals('valid',status(doc,question))
            Reader.clear_observer(buf,observer)
            assert.is_true(max_read<=4096,tostring(max_read));assert.equals(0,full)
        end)
    end
    it('rejects changed semantic bounds even if all earlier question rows survive',function()
        local doc,buf=setup({'💬: q','body','tail'})
        local question=capture(doc,0)
        vim.api.nvim_buf_set_lines(buf,2,2,false,{'🤖: new boundary'})
        assert.equals('conflict',status(doc,question))
    end)
    it('retains more than 64 independent inputs without per-token mutation work',function()
        local lines={};for i=1,80 do lines[#lines+1]='💬: q'..i;lines[#lines+1]='body'end
        local doc,buf=setup(lines);local tokens={}
        for i=1,80 do tokens[i]=capture(doc,(i-1)*2)end
        vim.api.nvim_buf_set_text(buf,79,4,79,4,{' changed'})
        for i=1,80 do assert.equals(i==40 and 'conflict' or 'valid',status(doc,tokens[i]))end
    end)
    it('reports budget and semantic uncertainty without declaring conflict',function()
        local doc,buf=setup({'💬: q','body'})
        local question=capture(doc,0);local entity=D.query(doc,0,1)[1].handle
        assert.equals('budget',D.capture_revision(doc,entity,'question',{budget_nodes=0,budget_entries=0}).status)
        assert.equals('budget',D.validate_revision(doc,question,{budget_nodes=0,budget_entries=0}).status)
        vim.api.nvim_buf_set_text(buf,1,4,1,4,{string.rep('x',70000)})
        assert.equals('opaque',D.validate_revision(doc,question).status)
        assert.equals('conflict',status(doc,question))
    end)
    it('makes retained tokens obsolete after detach and allows document collection',function()
        local weak=setmetatable({},{__mode='v'});local retained
        local function fixture()
            local doc=setup({'💬: q','body'});weak[1]=doc;retained=capture(doc,0)
            D.detach(doc);assert.equals('obsolete',D.validate_revision(doc,retained).status)
        end
        fixture();docs={}
        collectgarbage('collect');collectgarbage('collect');collectgarbage('collect')
        assert.is_nil(weak[1]);assert.is_table(retained)
    end)
    it('makes tokens obsolete after native reload',function()
        local path=vim.fn.tempname();vim.fn.writefile({'💬: q','body'},path)
        local buf=vim.fn.bufadd(path);vim.fn.bufload(buf);buffers[#buffers+1]=buf
        local doc=D.attach(buf,{schedule=false});docs[#docs+1]=doc;D.drain(doc,2000)
        local question=capture(doc,0)
        vim.fn.writefile({'💬: q','body'},path)
        vim.api.nvim_buf_call(buf,function()vim.cmd('edit!')end);vim.fn.delete(path)
        assert.equals('obsolete',D.validate_revision(doc,question).status)
    end)
    it('uses only indexed metadata to capture and validate a large exchange',function()
        local lines={'💬: q'};for _=1,2000 do lines[#lines+1]='body'end
        local doc,buf=setup(lines);local entity=D.query(doc,0,1)[1].handle
        local Reader=require('parley.line_reader');local read=0
        local observer=Reader.set_observer(buf,function(event)read=read+(event.bytes_read or 0)end)
        local result=D.capture_revision(doc,entity,'question');assert.equals('ready',result.status)
        assert.is_true(result.work.nodes_visited<=4096);assert.is_true(result.work.entries_visited<=8192)
        local checked=D.validate_revision(doc,result.token);assert.equals('valid',checked.status)
        assert.is_true(checked.work.nodes_visited<=4096);assert.is_true(checked.work.entries_visited<=8192)
        local deferred=false
        for budget=700,1100 do
            local limited=D.capture_revision(doc,entity,'question',{budget_nodes=budget})
            if limited.status=='budget' then deferred=true end
            assert.is_true(limited.work.nodes_visited<=budget,vim.inspect(limited.work))
            assert.is_nil(limited.cursor,'deferred result must not retain an index cursor')
            if deferred and limited.status=='ready' then break end
        end
        assert.is_true(deferred)
        Reader.clear_observer(buf,observer);assert.equals(0,read)
    end)
    for _,finite in ipairs({false,true})do
        it('does not exempt human reentry after an owned insertion '..tostring(finite),function()
            local doc,buf=setup({'💬: q','body'},function(target,native)
                native(target,1,0,1,4,{'human'})
            end)
            local question=capture(doc,0)
            output(doc,1,'\n\n🤖: answer',finite,true)
            assert.equals('human',vim.api.nvim_buf_get_lines(buf,1,2,false)[1])
            assert.equals('conflict',status(doc,question))
        end)
    end
    it('rejects native undo/redo ABA after authenticated generated output',function()
        local doc,buf=setup({'💬: q','body'});vim.api.nvim_set_current_buf(buf)
        local question=capture(doc,0)
        vim.cmd('let &undolevels=&undolevels')
        output(doc,1,'\n\n🤖: answer',true)
        assert.equals('valid',status(doc,question))
        vim.cmd('undo');assert.equals('conflict',status(doc,question))
        vim.cmd('redo');assert.equals('conflict',status(doc,question))
    end)
    it('preserves whole-row insertion geometry on an empty tail row',function()
        local doc=setup({'💬: q',''})
        local question=capture(doc,0)
        output(doc,1,string.rep('\n',300)..'🤖: answer',true)
        assert.equals('valid',status(doc,question))
    end)
end)
