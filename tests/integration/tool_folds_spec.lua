local D=require('parley.document')
local F=require('parley.tool_folds')
local policy=require('parley.fold_projection')
local parser=require('parley.chat_parser')

describe('tool folds from the shared document',function()
    local buf,doc,win,previous
    before_each(function()
        doc=nil
        previous=vim.api.nvim_get_current_buf()
        buf=vim.api.nvim_create_buf(false,true)
        vim.api.nvim_set_current_buf(buf)
        win=vim.api.nvim_get_current_win()
        vim.wo.foldmethod='manual';vim.wo.foldenable=true
    end)
    after_each(function()
        F._observer=nil
        if vim.api.nvim_buf_is_valid(buf) then vim.api.nvim_buf_delete(buf,{force=true}) end
        if vim.api.nvim_buf_is_valid(previous) then vim.api.nvim_set_current_buf(previous) end
    end)
    local function settle()
        assert.equals('idle',D.drain(doc,100000).status)
        assert.equals('idle',F.flush(buf))
    end
    local function open(lines,opts,before)
        vim.api.nvim_buf_set_lines(buf,0,-1,false,lines)
        doc=D.attach(buf,{schedule=false,patterns=opts and require('parley.highlight_structure').patterns(opts)})
        assert.equals('idle',D.drain(doc,100000).status)
        if before then before() end
        F.setup(buf);assert.equals('idle',F.flush(buf))
    end
    local function oracle(opts)
        local lines=vim.api.nvim_buf_get_lines(buf,0,-1,false)
        local parsed=parser.parse_chat(lines,0,opts or {})
        local expected={}
        for _,exchange in ipairs(parsed.exchanges) do
            for _,section in ipairs(exchange.answer and exchange.answer.semantic_sections or {}) do
                if policy.is_foldable(section.kind) then
                    for row=section.line_start,section.line_end do expected[row]=true end
                end
            end
        end
        for row=1,#lines do
            assert.equals(expected[row] and 1 or 0,vim.fn.foldlevel(row),'row '..row..' '..lines[row])
        end
    end
    it('replaces orphan and trailing user folds with exact auxiliary answer sections',function()
        open({'💬: q','🤖: a','🧠: thought','body','🧠:[END]','📝: summary',
            '🔧: read','```json','{}','```','📎: read','```','ok','```','plain','tail'},nil,function()
                vim.cmd('1,2fold');vim.cmd('15,16fold')
            end)
        oracle()
        assert.equals(3,vim.fn.foldclosed(3));assert.equals(5,vim.fn.foldclosedend(3))
    end)
    it('removes a stale fold away from any desired start after marker deletion',function()
        open({'💬: q','🤖: a','📎: read','```','result','```','tail'})
        vim.api.nvim_buf_set_lines(buf,2,3,false,{})
        assert.equals('pending',F.flush(buf))
        settle();oracle()
        assert.equals(0,vim.fn.foldlevel(3))
    end)
    it('does not fold a question or overrun EOF after partial boundary deletion',function()
        open({'💬: q','🤖: a','📎: read','```','result','```','💬: next','draft'})
        vim.api.nvim_buf_set_lines(buf,2,7,false,{'💬: new question'})
        settle();oracle()
        assert.equals(0,vim.fn.foldlevel(3))
    end)
    it('keeps the neighboring exchange fold open while rebuilding the changed exchange',function()
        open({'💬: first','🤖: a','🧠: first','body','🧠:[END]',
            '💬: second','🤖: b','🧠: second','body','🧠:[END]'})
        vim.cmd('8foldopen')
        vim.api.nvim_buf_set_lines(buf,2,3,false,{'plain replaced marker'})
        settle();oracle()
        assert.equals(-1,vim.fn.foldclosed(8));assert.equals(1,vim.fn.foldlevel(8))
    end)
    it('tracks surviving folds after earlier insertion and deletion',function()
        open({'💬: first','🤖: a','plain','💬: second','🤖: b','📎: result','```','ok','```'})
        vim.api.nvim_buf_set_lines(buf,2,2,false,{'extra','prose'})
        settle();oracle()
        assert.equals(8,vim.fn.foldclosed(8))
        vim.api.nvim_buf_set_lines(buf,2,4,false,{})
        settle();oracle()
        assert.equals(6,vim.fn.foldclosed(6))
    end)
    it('does not alias exchanges when pruning and adding keeps the count unchanged',function()
        open({'💬: first','🤖: a','📝: old','💬: second','🤖: b','📝: survivor'})
        local survivor=D.exchange(doc,4).identity
        vim.api.nvim_buf_set_lines(buf,0,3,false,{})
        vim.api.nvim_buf_set_lines(buf,-1,-1,false,{'💬: new','🤖: c','📝: added'})
        settle();oracle()
        assert.equals(survivor,D.exchange(doc,1).identity)
        assert.is_not.equals(survivor,D.exchange(doc,4).identity)
    end)
    it('preserves manual folds before every exchange span',function()
        open({'---','topic: t','file: f','---','','💬: q','🤖: a','📝: summary'},nil,function()
            vim.cmd('1,4fold')
        end)
        assert.equals(1,vim.fn.foldlevel(1))
        assert.equals(8,vim.fn.foldclosed(8))
    end)
    it('clears stale folds and avoids nesting with foldenable disabled',function()
        open({'💬: q','🤖: a','🧠: thought','body','🧠:[END]','tail'})
        vim.wo.foldenable=false
        for _=1,3 do F.apply_folds(buf,win);assert.equals('idle',F.flush(buf)) end
        assert.is_false(vim.wo.foldenable)
        vim.wo.foldenable=true;assert.equals(1,vim.fn.foldlevel(3));vim.wo.foldenable=false
        vim.api.nvim_buf_set_lines(buf,2,3,false,{'ordinary'})
        settle();assert.is_false(vim.wo.foldenable);vim.wo.foldenable=true;oracle()
    end)
    it('respects quoted tools and malformed fence recovery independently',function()
        for _,body in ipairs({
            {'```lua','📎: quoted','```','tail'},
            {'📎: incomplete','```','partial','📝: summary'},
            {'📎: empty','```','```','tail'},
            {'```','🧠: think','🔧: quoted','```','tail'},
        }) do
            local lines={'💬: q','🤖: a'};vim.list_extend(lines,body)
            if not doc then open(lines) else vim.api.nvim_buf_set_lines(buf,0,-1,false,lines);settle() end
            oracle()
        end
    end)
    it('supports configured tool markers and labels unexpected folds explicitly',function()
        local config=require('parley.config')
        local old=config.chat_tool_use_prefix
        config.chat_tool_use_prefix='TOOL:'
        local ok,err=pcall(function()
            open({'💬: q','🤖: a','TOOL: read','```','{}','```'},{chat_tool_use_prefix='TOOL:'})
            oracle({chat_tool_use_prefix='TOOL:'})
            vim.v.foldstart=3;vim.v.foldend=6
            assert.matches('read',F.foldtext())
            vim.v.foldstart=1;vim.v.foldend=2
            assert.matches('unexpected fold',F.foldtext())
        end)
        config.chat_tool_use_prefix=old;assert.is_true(ok,tostring(err))
    end)
    it('reconciles observed partial mutations without swallowing their error',function()
        open({'💬: q','🤖: a','🧠: thought','body','🧠:[END]'})
        local ok,err=pcall(F.with_exchange_update,buf,nil,nil,function()
            vim.api.nvim_buf_set_lines(buf,2,3,false,{'📝: changed'})
            error('partial mutation')
        end)
        assert.is_false(ok);assert.matches('partial mutation',err)
        settle();oracle()
    end)
    it('hydrates each window once and preserves independent open state',function()
        open({'💬: q','🤖: a','🧠: thought','body','🧠:[END]'})
        local second=vim.api.nvim_open_win(buf,false,{relative='editor',row=1,col=1,width=30,height=8,style='minimal'})
        F.hydrate_window(buf,second);F.flush(buf)
        vim.api.nvim_win_call(win,function() vim.cmd('3foldopen') end)
        assert.is_false(F.hydrate_window(buf,second))
        F.flush(buf)
        assert.equals(-1,vim.fn.foldclosed(3))
        assert.equals(3,vim.api.nvim_win_call(second,function() return vim.fn.foldclosed(3) end))
        vim.api.nvim_win_close(second,true)
    end)
    it('does no fold work for ordinary body edits and never grows nesting on tool appends',function()
        open({'💬: q','🤖: a','plain'})
        local events={};F._observer=function(e) events[#events+1]=e end
        vim.api.nvim_buf_set_text(buf,2,5,2,5,{' body'});F.flush(buf)
        assert.equals(0,#events)
        for _,marker in ipairs({'🔧: read','📎: read'}) do
            F.with_exchange_update(buf,nil,nil,function()
                vim.api.nvim_buf_set_lines(buf,-1,-1,false,{marker,'```','body','```'})
            end)
            settle();oracle()
        end
    end)
    it('keeps single-row summary folds exact when exchanges have no blank separator',function()
        open({'💬: first','🤖: a','📝: first','💬: second','🤖: b','📝: second',''})
        oracle();assert.equals(3,vim.fn.foldclosedend(3));assert.equals(6,vim.fn.foldclosedend(6))
        assert.equals(0,vim.fn.foldlevel(7))
    end)
    it('ignores queued hydration after its buffer is deleted',function()
        open({'💬: q','🤖: a','📝: summary'})
        F.apply_folds(buf,win)
        vim.api.nvim_buf_delete(buf,{force=true})
        vim.wait(20,function() return false end,1)
        assert.equals('idle',F.step(buf))
    end)
end)
