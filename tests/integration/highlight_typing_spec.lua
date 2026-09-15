-- Rendering consumes the shared document; text edits have one callback owner.
local highlighter=require('parley.highlighter')
local Document=require('parley.document')
local Reader=require('parley.line_reader')
local model=require('parley.highlight_structure')
local buf,doc
local config={}
local function open(lines,kind)
    buf=vim.api.nvim_create_buf(false,true)
    vim.api.nvim_buf_set_lines(buf,0,-1,false,lines)
    highlighter.setup({config=config,_parley_bufs={[buf]=kind or 'chat'}})
    doc=Document.attach(buf,{schedule=false})
    assert.equals(doc,highlighter.rebuild_structure(buf))
    assert.equals('idle',Document.drain(doc, 100000).status)
    return buf,doc
end
local function render(first,last,structure)
    return highlighter._compute_window_decorations(0,buf,first,last,nil,structure or doc)
end
local function oracle(first,last)
    local lines=vim.api.nvim_buf_get_lines(buf,0,-1,false)
    return render(first,last,model.build(lines,model.patterns(config)))
end
local function cleanup()
    if buf and vim.api.nvim_buf_is_valid(buf) then vim.api.nvim_buf_delete(buf,{force=true}) end
end

describe('shared-index highlighting during typing',function()
    after_each(cleanup)
    it('keeps the answer rendering stable while the human types the next question',function()
        open({'💬: q','🤖: answer','🧠: thought','🧠:[END]','answer prose','💬: next','draft'})
        local before=render(1,4)
        local handle=Document.query(doc,4,5)[1].handle
        for _,text in ipairs({'x','y','z'}) do
            local line=vim.api.nvim_buf_get_lines(buf,6,7,false)[1]
            vim.api.nvim_buf_set_text(buf,6,#line,6,#line,{text})
            local after=render(1,4)
            for row=1,4 do assert.same(before[row],after[row]) end
            assert.equals(handle,Document.query(doc,4,5)[1].handle)
        end
        assert.equals('idle',Document.drain(doc, 100000).status)
        assert.same(oracle(0,6),render(0,6))
    end)
    it('uses neutral styling when a surviving row loses its role context',function()
        open({'💬: q','body one','body two','body three'})
        local before=render(0,3)
        local old=Document.query(doc,2,3)[1].handle
        vim.api.nvim_buf_set_text(buf,0,0,0,#'💬: q',{'🤖: a'})
        local surviving=Document.query(doc,2,3,{presentation=true})[1]
        assert.equals(old,surviving.handle)
        assert.is_false(surviving.metadata.confirmed)
        assert.is_nil(surviving.metadata.semantic)
        assert.is_nil(surviving.metadata.render_before)
        for _,hl in ipairs(render(0,3)[2] or {}) do assert.is_not.equals('ParleyQuestion',hl.hl_group) end
        assert.equals('idle',Document.drain(doc, 100000).status)
        assert.same(oracle(0,3),render(0,3))
        assert.is_not.same(before[2],render(0,3)[2])
    end)
    it('does not transfer deleted-row presentation to new opaque rows',function()
        open({'💬: q','question prose','🤖: a','answer'})
        vim.api.nvim_buf_set_lines(buf,0,-1,false,{})
        local map=render(0,0)
        for _,hl in ipairs(map[0] or {}) do assert.is_not.equals('ParleyQuestion',hl.hl_group) end
        assert.equals(1,Document.size(doc).rows)
        assert.equals('idle',Document.drain(doc, 100000).status)
        assert.same(oracle(0,0),render(0,0))
    end)
    it('converges after Enter, Backspace, undo and redo without a legacy structural rebuild',function()
        open({'💬: q','🤖: a','answer','💬: next','draft'})
        vim.api.nvim_set_current_buf(buf)
        vim.cmd('let &undolevels = &undolevels')
        local build,replace=model.build,model.replace
        model.build=function() error('legacy full build used') end
        model.replace=function() error('legacy structure splice used') end
        local ok,err=pcall(function()
            vim.api.nvim_buf_set_text(buf,4,2,4,2,{'',''})
            assert.equals('idle',Document.drain(doc, 100000).status)
            render(0,5)
            vim.api.nvim_buf_set_text(buf,4,2,5,0,{''})
            assert.equals('idle',Document.drain(doc, 100000).status)
            vim.cmd('undo');assert.equals('idle',Document.drain(doc, 100000).status)
            vim.cmd('redo');assert.equals('idle',Document.drain(doc, 100000).status)
        end)
        model.build,model.replace=build,replace
        assert.is_true(ok,tostring(err))
        assert.same(oracle(0,5),render(0,5))
    end)
    it('removes draft backgrounds while their opener is unconfirmed',function()
        open({'# notes','=== draft ===','one','two','=== end ===','after'},'markdown')
        vim.api.nvim_buf_set_text(buf,1,0,1,#'=== draft ===',{'plain'})
        for _,hl in ipairs(render(0,5)[3] or {}) do assert.is_not.equals('ParleyDraftBlock',hl.hl_group) end
        assert.equals('idle',Document.drain(doc, 100000).status)
        assert.same(oracle(0,5),render(0,5))
    end)
    it('does not use invalidated reasoning, tool fence, or footer context',function()
        for _,fixture in ipairs({
            {lines={'💬: q','🤖: a','🧠: thought','body','🧠:[END]'},row=2,body=3,group='ParleyThinking'},
            {lines={'💬: q','🤖: a','🔧: tool','```','body','```'},row=2,body=4,group='ParleyThinking'},
            {lines={'💬: q','body','---','[^note]: definition','continuation'},row=3,body=4,group='ParleyFootnote'},
        }) do
            open(fixture.lines)
            vim.api.nvim_buf_set_lines(buf,fixture.row,fixture.row+1,false,{'plain'})
            local metadata=Document.query(doc,fixture.body,fixture.body+1,{presentation=true})[1].metadata
            assert.is_false(metadata.confirmed)
            assert.is_nil(metadata.render_before)
            assert.is_nil(metadata.after)
            assert.is_nil(metadata.presentation)
            for _,hl in ipairs(render(0,#fixture.lines-1)[fixture.body] or {}) do
                assert.is_not.equals(fixture.group,hl.hl_group)
            end
            cleanup()
        end
    end)
    it('reads at most64KiB even when a visible line is enormous',function()
        open({'💬: q',string.rep('x',100000),'tail'})
        local bytes=0
        Reader.set_observer(buf,function(event) bytes=bytes+(event.bytes_read or 0) end)
        render(0,2)
        assert.is_true(bytes<=65536)
        assert.is_true(bytes>0)
    end)
    it('has identical bounded viewport reads at1000 and5000 rows',function()
        local measured={}
        for _,count in ipairs({1000,5000}) do
            local lines={'💬: q'}
            for i=2,count do lines[i]='body' end
            open(lines)
            local events={}
            Reader.set_observer(buf,function(e) if e.operation~='work' then events[#events+1]=e end end)
            render(500,509)
            assert.equals(1,#events)
            assert.equals(30,events[1].lines_requested)
            assert.is_false(events[1].full_buffer)
            measured[#measured+1]=events[1].bytes_read
            cleanup()
        end
        assert.equals(measured[1],measured[2])
    end)
end)
