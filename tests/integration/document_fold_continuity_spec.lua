-- #264: a closed fold must stay closed across *every* step of fold repair, not
-- merely once repair settles. The settled-state oracle alone could not see the
-- flicker: fold repair used to delete every fold of an exchange in one turn and
-- recreate them in a later one.
local D=require('parley.document')
local F=require('parley.tool_folds')
local policy=require('parley.fold_projection')
local parser=require('parley.chat_parser')

describe('fold continuity across repair',function()
    local buf,doc,previous,events
    before_each(function()
        previous=vim.api.nvim_get_current_buf()
        buf=vim.api.nvim_create_buf(false,true)
        vim.api.nvim_set_current_buf(buf)
        vim.wo.foldmethod='manual';vim.wo.foldenable=true
        events={}
        F._observer=function(event) events[#events+1]=event end
    end)
    after_each(function()
        F._observer=nil
        if vim.api.nvim_buf_is_valid(buf) then vim.api.nvim_buf_delete(buf,{force=true}) end
        if vim.api.nvim_buf_is_valid(previous) then vim.api.nvim_set_current_buf(previous) end
    end)

    local function oracle()
        local lines=vim.api.nvim_buf_get_lines(buf,0,-1,false)
        local parsed=parser.parse_chat(lines,0,{})
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
    local function open(lines)
        vim.api.nvim_buf_set_lines(buf,0,-1,false,lines)
        doc=D.attach(buf,{schedule=false})
        assert.equals('idle',D.drain(doc,100000).status)
        F.setup(buf);assert.equals('idle',F.flush(buf))
        events={}
    end
    -- Steps repair to idle, asserting after every step that each watched row
    -- is inside a closed fold. Returns the reconcile totals for zero-touch checks.
    local function repair(watch)
        D.drain(doc,100000)
        for step=1,500 do
            local status=F.step(buf)
            for _,row in ipairs(watch) do
                assert.are_not.equals(-1,vim.fn.foldclosed(row),('row %d opened at step %d'):format(row,step))
            end
            if status=='idle' then break end
            if status=='pending' then D.drain(doc,100000) end
        end
    end
    local function totals()
        local removed,created=0,0
        for _,event in ipairs(events) do
            if event.phase=='reconcile' then
                assert.is_number(event.removed,'reconcile must report removed');assert.is_number(event.created)
                removed=removed+event.removed;created=created+event.created
            end
        end
        return removed,created
    end
    local function closed(rows) for _,row in ipairs(rows) do assert.equals(row,vim.fn.foldclosed(row),'precondition row '..row) end end
    local function keys(row,col,sequence)
        vim.api.nvim_win_set_cursor(0,{row,col})
        vim.api.nvim_feedkeys(vim.keycode(sequence),'xt',false)
    end

    -- Summary / thinking / tool pair followed by `blanks` blank rows, then a new question.
    local function with_blanks(head,blanks)
        local lines=vim.deepcopy(head)
        for _=1,blanks do lines[#lines+1]='' end
        lines[#lines+1]='💬: ';lines[#lines+1]=''
        return lines
    end
    local heads={
        summary={lines={'💬: first question','🤖: first answer','some body text','📝: a summary line'},watch={4}},
        thinking={lines={'💬: q','🤖: a','🧠: thought','reasoning body'},watch={3}},
        tool={lines={'💬: q','🤖: a','🔧: read id=1','```json','{}','```','📎: read id=1','```','ok','```'},watch={3,7}},
    }
    for _,kind in ipairs({'summary','thinking','tool'}) do
        for _,shape in ipairs({{1,1},{2,1},{2,2},{4,1},{4,3},{4,4}}) do
            local blanks,deleted=shape[1],shape[2]
            it(('%s: deleting %d of %d blank rows keeps it closed'):format(kind,deleted,blanks),function()
                local head=heads[kind]
                open(with_blanks(head.lines,blanks));closed(head.watch)
                local first=#head.lines
                vim.api.nvim_buf_set_lines(buf,first,first+deleted,false,{})
                repair(head.watch);oracle()
            end)
        end
    end

    it('an edit in a second exchange keeps folds of both exchanges closed',function()
        open({'💬: one','🤖: a','📝: first summary','','💬: two','🤖: b','📝: second summary','','','💬: ',''})
        closed({3,7})
        vim.api.nvim_buf_set_lines(buf,7,8,false,{})
        repair({3,7});oracle()
    end)

    describe('real keystroke joins under a summary',function()
        local lines={'💬: q','🤖: a','body','📝: summary line','','','💬: next',''}
        it('Backspace at column 0 of the blank below',function()
            open(lines);closed({4})
            keys(5,0,'i<BS><Esc>')
            repair({4});oracle()
            local removed=totals();assert.equals(0,removed)
        end)
        it('J on the summary row',function()
            open(lines);closed({4})
            keys(4,0,'J')
            repair({4})
            oracle()
            local removed=totals();assert.equals(0,removed)
        end)
        it('Delete at end of the summary row',function()
            open(lines);closed({4})
            keys(4,0,'A<Del><Esc>')
            repair({4})
            oracle()
            local removed=totals();assert.equals(0,removed)
        end)
    end)
    it('Backspace at column 0 of the blank below a thinking block',function()
        open({'💬: q','🤖: a','🧠: thought','reasoning','','','💬: next',''});closed({3})
        keys(5,0,'i<BS><Esc>')
        repair({3});oracle()
    end)

    describe('streaming appends below a closed tool pair',function()
        local head={'💬: q','🤖: a','🔧: read id=1','```json','{}','```','📎: read id=1','```','old result','```',''}
        local block={'🔧: read id=2','```json','{}','```','','📎: read id=2','```'}
        local body={};for i=1,40 do body[i]='line '..i end
        it('whole block in one write',function()
            open(head);closed({3,7})
            local all=vim.list_extend(vim.deepcopy(block),vim.deepcopy(body));vim.list_extend(all,{'```',''})
            vim.api.nvim_buf_set_lines(buf,-1,-1,false,all)
            repair({3,7});oracle()
            local removed,created=totals()
            assert.equals(0,removed);assert.equals(2,created)
        end)
        it('result split across two writes (closing fence in the second)',function()
            open(head);closed({3,7})
            vim.api.nvim_buf_set_lines(buf,-1,-1,false,vim.list_extend(vim.deepcopy(block),vim.list_slice(body,1,20)))
            repair({3,7})
            vim.api.nvim_buf_set_lines(buf,-1,-1,false,vim.list_extend(vim.list_slice(body,21,40),{'```',''}))
            repair({3,7});oracle()
            -- The block still being written is reshaped once when its closing
            -- fence arrives (#290 removes this by writing a block in one piece);
            -- every earlier fold stays untouched, which `repair` watched.
            local removed=totals();assert.is_true(removed<=1,'removed '..removed)
        end)
        it('one-line result',function()
            open(head);closed({3,7})
            vim.api.nvim_buf_set_lines(buf,-1,-1,false,{'🔧: read id=2','```json','{}','```','','📎: read id=2','```','ok','```',''})
            repair({3,7});oracle()
            local removed=totals();assert.equals(0,removed)
        end)
    end)
    it('thinking and summary appended below a closed summary',function()
        open({'💬: one','🤖: a','📝: first summary','','💬: two','🤖: b',''});closed({3})
        vim.api.nvim_buf_set_lines(buf,-1,-1,false,{'🧠: thinking','reasoning','','answer text','📝: second summary',''})
        repair({3});oracle()
        local removed=totals();assert.equals(0,removed)
    end)

    describe('ordinary human edits touch no fold',function()
        local lines={'💬: question text','🤖: a','🔧: read id=1','```json','{}','```','📎: read id=1','```','ok','```','📝: summary','','💬: next',''}
        it('typing a character in a question',function()
            open(lines);closed({3,7,11})
            keys(13,5,'ix<Esc>')
            repair({3,7,11});oracle()
            local removed,created=totals();assert.equals(0,removed);assert.equals(0,created)
        end)
        it('Enter inside a question',function()
            open(lines);closed({3,7,11})
            keys(13,5,'i<CR><Esc>')
            repair({3,7,11});oracle()
            local removed,created=totals();assert.equals(0,removed);assert.equals(0,created)
        end)
    end)

    describe('edges settle to the projection',function()
        local lines={'💬: q','🤖: a','📎: read id=1','```','one','two','```','','💬: next',''}
        it('deleting a tool result closing fence',function()
            open(lines)
            vim.api.nvim_buf_set_lines(buf,6,7,false,{})
            repair({});oracle()
        end)
        it('a net insertion inside a closed tool result',function()
            open(lines);closed({3})
            vim.api.nvim_buf_set_lines(buf,4,4,false,{'inserted'})
            repair({});oracle()
        end)
    end)
end)
