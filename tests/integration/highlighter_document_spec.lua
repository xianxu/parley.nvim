local highlighter=require('parley.highlighter')
local Document
local buf
local config={}
local function setup(lines,kind)
    buf=vim.api.nvim_create_buf(false,true)
    vim.api.nvim_buf_set_lines(buf,0,-1,false,lines)
    highlighter.setup({config=config,_parley_bufs={[buf]=kind or 'chat'}})
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
        local bytes,lines=0,0
        vim.api.nvim_buf_attach=function(buffer,send,opts)
            if opts.on_bytes then bytes=bytes+1 end
            if opts.on_lines then lines=lines+1 end
            return attach(buffer,send,opts)
        end
        local ok,err=pcall(function()
            local doc=setup({'💬: q','body'})
            assert.equals(doc,highlighter.rebuild_structure(buf))
            highlighter.clear_structure(buf)
            assert.equals(doc,highlighter.rebuild_structure(buf))
            assert.equals(1,bytes)
            assert.equals(0,lines)
        end)
        vim.api.nvim_buf_attach=attach
        assert.is_true(ok,tostring(err))
    end)
end)
