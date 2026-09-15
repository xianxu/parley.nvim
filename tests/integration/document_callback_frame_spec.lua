local D=require('parley.document')
local Grammar=require('parley.document.grammar')
local buffers={}
local function settle(doc)assert.equals('idle',D.drain(doc,10000).status)end
local function parity(buf,doc)
    local lines=vim.api.nvim_buf_get_lines(buf,0,-1,false)
    local spans=D.query(doc,0,#lines)
    assert.equals(#lines,#spans)
    for i,line in ipairs(lines) do
        local _,token=Grammar.lex_step(Grammar.lex_start(require('parley.document.lexical').patterns({})),line,true,{bytes=65536})
        assert.equals(token.kind,spans[i].metadata.token.kind,'row '..i)
        assert.is_true(Grammar.same_token(token,spans[i].metadata.token),'descriptor row '..i)
        assert.equals(#line+1,spans[i].bytes)
        assert.is_true(spans[i].metadata.confirmed)
    end
end
describe('native callback source frames',function()
    after_each(function()for _,buf in ipairs(buffers)do if vim.api.nvim_buf_is_valid(buf)then vim.api.nvim_buf_delete(buf,{force=true})end end;buffers={}end)
    it('does not mistake equal-size final-frame text for an intermediate undo row',function()
        local buf=vim.api.nvim_create_buf(false,true);buffers[#buffers+1]=buf;vim.api.nvim_set_current_buf(buf)
        vim.api.nvim_buf_set_lines(buf,0,-1,false,{'💬: q1','🤖: a1','💬: q2','🤖: a2','💬: q3','🤖: a3'})
        local doc=D.attach(buf,{schedule=false});settle(doc)
        vim.cmd('let &undolevels=&undolevels')
        vim.api.nvim_buf_set_lines(buf,0,0,false,{'xxxxxxxx'})
        vim.cmd('undojoin');vim.api.nvim_buf_set_lines(buf,3,4,false,{})
        settle(doc);parity(buf,doc)
        vim.cmd('undo');settle(doc);parity(buf,doc)
        vim.cmd('redo');settle(doc);parity(buf,doc)
    end)
    it('rejects both equal-width grouped replacement frames through repeated undo and redo',function()
        local buf=vim.api.nvim_create_buf(false,true);buffers[#buffers+1]=buf;vim.api.nvim_set_current_buf(buf)
        vim.api.nvim_buf_set_lines(buf,0,-1,false,{'💬: q1','🤖: a1','💬: q2','🤖: a2'})
        local doc=D.attach(buf,{schedule=false});settle(doc)
        vim.cmd('let &undolevels=&undolevels')
        vim.api.nvim_buf_set_text(buf,0,0,0,4,{'🤖'})
        vim.cmd('undojoin');vim.api.nvim_buf_set_text(buf,2,0,2,4,{'🤖'})
        settle(doc);parity(buf,doc)
        for _=1,3 do
            vim.cmd('undo');settle(doc);parity(buf,doc)
            vim.cmd('redo');settle(doc);parity(buf,doc)
        end
    end)
    it('records the native line barrier before grouped undo byte delivery',function()
        local E=require('parley.document.editor')
        local buf=vim.api.nvim_create_buf(false,true);buffers[#buffers+1]=buf;vim.api.nvim_set_current_buf(buf)
        vim.api.nvim_buf_set_lines(buf,0,-1,false,{'one','two','three'})
        local events={}
        local editor=E.new(buf,{epoch=1,on_event=function(e)if e.kind=='edit'then events[#events+1]=e end end})
        editor:attach();vim.cmd('let &undolevels=&undolevels')
        vim.api.nvim_buf_set_lines(buf,0,0,false,{'new'})
        vim.cmd('undojoin');vim.api.nvim_buf_set_lines(buf,2,3,false,{})
        assert.is_true(events[1].source_frame);assert.is_true(events[2].source_frame)
        vim.cmd('undo')
        assert.is_false(events[3].source_frame);assert.is_false(events[4].source_frame)
        vim.cmd('redo')
        assert.is_false(events[5].source_frame);assert.is_false(events[6].source_frame)
        vim.api.nvim_buf_set_text(buf,0,0,0,0,{'x'})
        assert.is_true(events[7].source_frame)
    end)
    it('keeps native Insert Enter and Backspace on the bounded fragment path',function()
        local buf=vim.api.nvim_create_buf(false,true);buffers[#buffers+1]=buf;vim.api.nvim_set_current_buf(buf)
        vim.api.nvim_buf_set_lines(buf,0,-1,false,{'💬: q','draft','🤖: a','body'})
        local doc=D.attach(buf,{schedule=false});settle(doc)
        local events={};D.subscribe(doc,function(e)if e.kind=='edit'then events[#events+1]=e end end)
        vim.api.nvim_win_set_cursor(0,{2,2})
        local keys=vim.api.nvim_replace_termcodes('ix<CR><BS><Esc>',true,false,true)
        vim.api.nvim_feedkeys(keys,'nx',false)
        settle(doc);parity(buf,doc)
        assert.is_true(#events>=3,vim.inspect(events))
        for _,event in ipairs(events)do assert.is_true(event.reused_suffix or event.deferred_fragment,vim.inspect(event))end
    end)
    it('does not read callback text from an injected driver without frame evidence',function()
        local Fake=require('tests.helpers.fake_document_editor')
        local fake=Fake.new({'💬: q','body'});fake.driver.callback_frame=nil
        local reads=0;local lines=fake.driver.lines
        fake.driver.lines=function(...)reads=reads+1;return lines(...)end
        local doc=D.attach(-99000,{driver=fake.driver,schedule=false});settle(doc)
        local before=reads;fake:edit(1,1,1,1,{'x'})
        assert.equals(before,reads);assert.is_true(D.query(doc,1,2)[1].opaque)
        settle(doc);D.detach(doc)
    end)

    it('performs no native text reads while an undo batch delivers uncertain frames',function()
        local buf=vim.api.nvim_create_buf(false,true);buffers[#buffers+1]=buf;vim.api.nvim_set_current_buf(buf)
        vim.api.nvim_buf_set_lines(buf,0,-1,false,{'💬: q1','🤖: a1','💬: q2','🤖: a2'})
        local Reader=require('parley.line_reader');local original=Reader.for_buffer
        local reading,reads=false,0
        Reader.for_buffer=function(...)
            local reader=original(...)
            for _,method in ipairs({'lines','text','chunk'})do
                local fn=reader[method]
                reader[method]=function(self,...)if reading then reads=reads+1 end;return fn(self,...)end
            end
            return reader
        end
        local success,doc=pcall(D.attach,buf,{schedule=false});Reader.for_buffer=original
        assert.is_true(success);settle(doc)
        vim.cmd('let &undolevels=&undolevels')
        vim.api.nvim_buf_set_lines(buf,0,0,false,{'xxxxxxxx'})
        vim.cmd('undojoin');vim.api.nvim_buf_set_lines(buf,3,4,false,{})
        settle(doc);reading=true;vim.cmd('undo');reading=false
        assert.equals(0,reads);settle(doc);parity(buf,doc)
    end)

    it('restores frame admission after settled native Backspace line notifications',function()
        local buf=vim.api.nvim_create_buf(false,true);buffers[#buffers+1]=buf;vim.api.nvim_set_current_buf(buf)
        vim.api.nvim_buf_set_lines(buf,0,-1,false,{'💬: q','draft','🤖: a','body'})
        local doc=D.attach(buf,{schedule=false});settle(doc)
        vim.api.nvim_win_set_cursor(0,{2,2})
        vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes('i<CR><BS><Esc>',true,false,true),'nx',false)
        settle(doc)
        local yielded=false;vim.schedule(function()yielded=true end)
        assert.is_true(vim.wait(1000,function()return yielded end,1))
        local last;D.subscribe(doc,function(e)if e.kind=='edit'then last=e end end)
        vim.api.nvim_buf_set_text(buf,1,0,1,0,{'x'})
        assert.is_true(last.reused_suffix,vim.inspect(last))
        settle(doc);parity(buf,doc)
    end)

end)
