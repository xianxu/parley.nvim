local D=require('parley.document')
local G=require('parley.document.grammar')
local patterns=require('parley.document.lexical').patterns({})
local buffers={}
local corpus={'💬: q1','🤖: a1','💬: q2','🤖: a2','xxxxxxxx','yyyyyyyy','','body'}
local function keys(value)
    vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes(value,true,false,true),'nx',false)
end
local function parity(buf,doc,context)
    local result=D.drain(doc,2000)
    assert.equals('idle',result.status,context..' convergence '..vim.inspect(result))
    local lines=vim.api.nvim_buf_get_lines(buf,0,-1,false)
    local spans=D.query(doc,0,#lines)
    assert.equals(#lines,#spans,context..' rows')
    local bytes,starts=0,{}
    for i,line in ipairs(lines) do
        bytes=bytes+#line+1
        local expected=line:match('^💬:') and 'user' or line:match('^🤖:') and 'assistant'
            or line:match('^%s*$') and 'blank' or 'text'
        local span=spans[i]
        assert.is_false(span.opaque,context..' opaque row '..i)
        assert.is_true(span.metadata.confirmed,context..' unconfirmed row '..i)
        assert.equals(expected,span.metadata.token.kind,context..' flat lexical kind '..i)
        local _,token=G.lex_step(G.lex_start(patterns),line,true,{bytes=65536})
        assert.is_true(G.same_token(token,span.metadata.token),context..' descriptor row '..i)
        -- The corpus has only plain text and exact user/assistant markers.
        -- This flat oracle does not consult incremental state or projections.
        if expected=='user' then starts[#starts+1]=i-1 end
        assert.equals(#line+1,span.bytes,context..' row bytes '..i)
    end
    assert.equals(bytes,D.size(doc).bytes,context..' total bytes')
    for index,first in ipairs(starts) do
        local last=starts[index+1] or #lines
        for row=first,last-1 do
            local exchange=D.exchange(doc,row)
            assert.equals('ready',exchange.status,context..' exchange row '..row)
            assert.equals(first,exchange.first,context..' exchange first '..row)
            assert.equals(last,exchange.last,context..' exchange last '..row)
        end
    end
end
local function history(seed)
    local random=seed
    local function pick(n)random=(random*16807)%2147483647;return random%n end
    local buf=vim.api.nvim_create_buf(false,true);buffers[#buffers+1]=buf
    vim.api.nvim_set_current_buf(buf)
    vim.api.nvim_buf_set_lines(buf,0,-1,false,corpus)
    local doc=D.attach(buf,{schedule=false})
    parity(buf,doc,'seed '..seed..' initial')
    local trace={}
    for step=1,45 do
        local lines=vim.api.nvim_buf_get_lines(buf,0,-1,false)
        local row=pick(#lines);local operation=(step-1)%9
        local value=corpus[pick(#corpus)+1]
        trace[#trace+1]=string.format('%d:%d@%d=%q',step,operation,row,value)
        if operation==0 then
            vim.cmd('let &undolevels=&undolevels')
            vim.api.nvim_buf_set_lines(buf,row,row,false,{value})
        elseif operation==1 then
            vim.cmd('undojoin')
            vim.api.nvim_buf_set_lines(buf,row,row+1,false,{})
        elseif operation==2 then vim.cmd('undo')
        elseif operation==3 then vim.cmd('redo')
        elseif operation==4 then
            vim.cmd('undo')
            vim.api.nvim_win_set_cursor(0,{1,0});keys('ix<CR><BS><Esc>')
        elseif operation==5 then
            local col=#lines[row+1]
            vim.api.nvim_buf_set_text(buf,row,col,row,col,{'','tail'})
        elseif operation==6 then
            vim.cmd('let &undolevels=&undolevels')
            vim.api.nvim_buf_set_text(buf,row,0,row,#lines[row+1],{value})
            vim.cmd('undojoin')
            vim.api.nvim_buf_set_text(buf,row,0,row,#value,{value})
        elseif operation==7 then vim.cmd('undo')
        else vim.cmd('redo') end
        parity(buf,doc,'seed '..seed..' trace '..table.concat(trace,' | '))
    end
end
describe('seeded native document histories',function()
    after_each(function()
        keys('<Esc>')
        for _,buf in ipairs(buffers)do if vim.api.nvim_buf_is_valid(buf)then vim.api.nvim_buf_delete(buf,{force=true})end end
        buffers={}
    end)
    for _,seed in ipairs({1,17,254,4099}) do
        it('matches flat text and exchange oracles for seed '..seed,function()history(seed)end)
    end
end)
