-- #264 M2: a local edit whose parser fast path fails its end-state comparison
-- must not re-parse from row 0. The uncertain range stays {restart, EOF}, but
-- its start is bounded below by the edit's answer header (or the edit row for a
-- question edit). The settled parse must equal a cold parse of the same text.
local D=require('parley.document')

describe('uncertainty extent after a local edit',function()
    local bufs={}
    after_each(function()
        for _,b in ipairs(bufs) do if vim.api.nvim_buf_is_valid(b) then vim.api.nvim_buf_delete(b,{force=true}) end end
        bufs={}
    end)
    local function attach(lines)
        local buf=vim.api.nvim_create_buf(false,true);bufs[#bufs+1]=buf
        vim.api.nvim_buf_set_lines(buf,0,-1,false,lines)
        local doc=D.attach(buf,{schedule=false})
        assert.equals('idle',D.drain(doc,100000).status)
        return buf,doc
    end
    -- Handle-free facts only: other semantic fields hold handles that differ
    -- between two buffers.
    local function facts(doc)
        local out={}
        for i,row in ipairs(D.query(doc,0,D.size(doc).rows)) do
            local m=row.metadata or {};local sem=m.semantic or {}
            out[i]={role=sem.role,section_kind=sem.section_kind,section_start=sem.section_start and true or false,
                confirmed=m.confirmed==true}
        end
        return out
    end
    local function folds(doc)
        local out,cursor={},nil
        for _=1,1000 do
            local page=D.folds(doc,0,D.size(doc).rows,{cursor=cursor})
            assert.equals('ready',page.status=='budget' and 'ready' or page.status)
            for _,r in ipairs(page.ranges or {}) do out[#out+1]={r.start_0,r.end_0} end
            if page.status~='budget' then break end
            cursor=page.cursor
        end
        return out
    end
    local function case(lines,delete_row,expected_first)
        local buf,doc=attach(lines)
        vim.api.nvim_buf_set_lines(buf,delete_row,delete_row+1,false,{})
        local range=D.uncertain_range(doc)
        if expected_first==nil then
            assert.is_nil(range)
        else
            assert.is_true(range==nil or range.first>=expected_first,
                ('uncertain from %s, want >= %d'):format(range and range.first,expected_first))
        end
        assert.equals('idle',D.drain(doc,100000).status)
        local _,cold=attach(vim.api.nvim_buf_get_lines(buf,0,-1,false))
        assert.same(facts(cold),facts(doc))
        assert.same(folds(cold),folds(doc))
    end

    it('a blank after a summary restarts at the answer header',function()
        case({'💬: q','🤖: a','body','📝: summary','','','💬: next',''},4,1)
    end)
    it('a blank after thinking restarts at the answer header',function()
        case({'💬: q','🤖: a','🧠: thought','reasoning','','','💬: next',''},4,1)
    end)
    it('a blank in a second exchange restarts at that exchange header',function()
        case({'💬: one','🤖: a','📝: first','','💬: two','🤖: b','body','📝: second','','','💬: ',''},8,5)
    end)
    it('a blank inside a question restarts at the edit',function()
        case({'💬: q','🤖: a','📝: summary','','💬: a longer question','','','more question text','🤖: b',''},5,5)
    end)
    it('a blank after a tool block stays local (control)',function()
        case({'💬: q','🤖: a','🔧: read id=1','```json','{}','```','📎: read id=1','```','ok','```','','','💬: ',''},10,nil)
    end)
end)
