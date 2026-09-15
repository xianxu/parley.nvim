local highlighter=require('parley.highlighter')
local Document
local buf
local parley=require('parley')
local scratch=vim.fn.tempname()..'-renderer'
parley.setup({chat_dir=scratch,state_dir=scratch..'/state',providers={},api_keys={}})
local config=parley.config
local function setup(lines,kind)
    buf=vim.api.nvim_create_buf(false,true)
    vim.api.nvim_buf_set_lines(buf,0,-1,false,lines)
    parley._parley_bufs[buf]=kind or 'chat'
    highlighter.setup(parley)
    local doc=assert(highlighter.rebuild_structure(buf))
    assert.equals('idle',Document.drain(doc, 100000).status)
    return doc
end
local function render(first,last,structure)
    return highlighter._compute_window_decorations(0,buf,first,last,nil,structure)
end

describe('highlighter shared document rendering',function()
    before_each(function() Document=require('parley.document') end)
    after_each(function()
        if buf and vim.api.nvim_buf_is_valid(buf) then vim.api.nvim_buf_delete(buf,{force=true}) end
    end)
    it('renders the shared viewport identically to the independent legacy oracle',function()
        local lines={'💬: q','body','```lua','code','```','🤖: answer','🧠: think','','continued','🧠:[END]',
            '📎: result','```','output','```','💬: next','draft','', '[^a]: footer'}
        local doc=setup(lines)
        local legacy=require('parley.highlight_structure')
        local oracle=legacy.build(lines,legacy.patterns(config))
        assert.same(render(0,#lines-1,oracle),render(0,#lines-1,doc))
    end)
    it('shares one on_bytes owner across repeated renderer attachment',function()
        local attach=vim.api.nvim_buf_attach
        local bytes,lines,paired=0,0,0
        vim.api.nvim_buf_attach=function(buffer,send,opts)
            if opts.on_bytes then bytes=bytes+1 end
            if opts.on_lines then lines=lines+1 end
            if opts.on_bytes and opts.on_lines then paired=paired+1 end
            return attach(buffer,send,opts)
        end
        local ok,err=pcall(function()
            local doc=setup({'💬: q','body'})
            assert.equals(doc,highlighter.rebuild_structure(buf))
            highlighter.clear_structure(buf)
            assert.equals(doc,highlighter.rebuild_structure(buf))
            assert.equals(1,bytes)
            -- The same editor attachment uses on_lines only as a native-frame
            -- barrier; it is not a second structural observer or edit stream.
            assert.equals(1,lines)
            assert.equals(1,paired)
        end)
        vim.api.nvim_buf_attach=attach
        assert.is_true(ok,tostring(err))
    end)
    it('renders later visible questions when the first row exceeds the byte budget',function()
        local doc=setup({string.rep('x',100000),'💬: later','question body'})
        local bytes=0
        require('parley.line_reader').set_observer(buf,function(e) bytes=bytes+(e.bytes_read or 0) end)
        local map=render(0,2,doc)
        local found=false
        for _,hl in ipairs(map[2] or {}) do if hl.hl_group=='ParleyQuestion' then found=true end end
        assert.is_true(found)
        assert.is_true(bytes<=65536)
    end)
    it('progresses through a tall viewport without rereading every row in one redraw',function()
        local lines={'💬: q'}
        for i=2,800 do lines[i]='body' end
        setup(lines)
        vim.api.nvim_set_current_buf(buf)
        local win=vim.api.nvim_get_current_win()
        local decoration=require('tests.helpers.decoration')
        local provider=decoration.capture_provider(parley)
        local reader=require('parley.line_reader')
        local rows=0
        reader.set_observer(buf,function(e) rows=rows+(e.returned_lines or 0) end)
        local drawn
        for _=1,3 do
            rows=0
            drawn=decoration.frame(provider,win,buf,0,599)
            assert.is_true(rows<=256)
            vim.api.nvim_buf_set_text(buf,799,0,799,0,{'outside'})
        end
        assert.is_true(decoration.has(drawn,599,'ParleyQuestion'))
        assert.is_true(decoration.has(drawn,0,'ParleyQuestion'))
        vim.api.nvim_buf_set_lines(buf,599,600,false,{'🤖: replacement'})
        drawn=decoration.frame(provider,win,buf,0,599)
        assert.is_false(decoration.has(drawn,599,'ParleyQuestion'))
    end)
    it('reads a horizontally visible UTF8 segment and offsets its inline highlights',function()
        local line='💬: '..string.rep('α',40000)..' #254 end'
        local doc=setup({line,'body'})
        vim.api.nvim_set_current_buf(buf)
        local win=vim.api.nvim_get_current_win()
        vim.wo[win].wrap=false
        vim.api.nvim_win_set_cursor(win,{1,80006})
        vim.fn.winrestview({leftcol=40000,lnum=1,col=80006})
        local map=render(0,1,doc)
        local wanted=line:find('#254',1,true)-1
        local found,background=false,false
        for _,hl in ipairs(map[0]) do
            if hl.hl_group=='ParleyArtifactRef' and hl.col_start==wanted then found=true end
            if hl.hl_group=='ParleyQuestion' then background=true end
        end
        assert.is_true(found)
        assert.is_true(background)
        assert.equals(#line,map[0].line_length)
        vim.wo[win].wrap=true
    end)
    it('releases a closed window cache while its buffer remains visible elsewhere',function()
        setup({'💬: q','body'})
        vim.api.nvim_set_current_buf(buf)
        local second=vim.api.nvim_open_win(buf,false,{relative='editor',row=1,col=1,width=30,height=5})
        local decoration=require('tests.helpers.decoration')
        local provider=decoration.capture_provider(parley)
        assert.is_true(decoration.has(decoration.frame(provider,second,buf,0,1),1,'ParleyQuestion'))
        vim.api.nvim_win_close(second,true)
        local original=vim.api.nvim_buf_set_extmark
        local count=0
        vim.api.nvim_buf_set_extmark=function(...) count=count+1;return original(...) end
        local ok,err=pcall(provider.on_line,nil,second,buf,1)
        vim.api.nvim_buf_set_extmark=original
        assert.is_true(ok,tostring(err));assert.equals(0,count)
        assert.is_true(vim.api.nvim_buf_is_valid(buf))
    end)
end)
