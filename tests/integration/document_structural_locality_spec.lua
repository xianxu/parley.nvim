local D=require('parley.document')
local buffers={}
local function fixture(lines)
    local buf=vim.api.nvim_create_buf(false,true);buffers[#buffers+1]=buf
    vim.api.nvim_buf_set_lines(buf,0,-1,false,lines)
    local doc=D.attach(buf,{schedule=false})
    assert.equals('idle',D.drain(doc,50000).status)
    return buf,doc
end
local function settle(doc)assert.equals('idle',D.drain(doc,50000).status)end
local function normalized(doc)
    local rows=D.query(doc,0,D.size(doc).rows)
    local identities={}
    for _,row in ipairs(rows)do identities[row.handle]=row.start_row end
    local function copy(value)
        if type(value)=='string' and identities[value]~=nil then return {row=identities[value]}end
        if type(value)=='string' and value:match('^sequence:')then return value:match(':(%a+)$') or value end
        if type(value)~='table'then return value end
        local out={};for k,v in pairs(value)do out[k]=copy(v)end;return out
    end
    local result={}
    for i,row in ipairs(rows)do
        assert.is_true(row.metadata.confirmed)
        result[i]={bytes=row.bytes}
        for _,field in ipairs({'token','semantic','before','after','render_before','section_before','section_after'})do
            result[i][field]=copy(row.metadata[field])
        end
    end
    return result
end
local function parity(buf,doc)
    settle(doc)
    local _,fresh=fixture(vim.api.nvim_buf_get_lines(buf,0,-1,false))
    assert.same(normalized(fresh),normalized(doc))
end

describe('structural edits retain unrelated dependency channels',function()
    after_each(function()
        for _,buf in ipairs(buffers)do if vim.api.nvim_buf_is_valid(buf)then vim.api.nvim_buf_delete(buf,{force=true})end end
        buffers={}
    end)
    it('keeps a new tail question local in a 1000-row transcript',function()
        local lines={'# topic: locality','---',''}
        for _=1,249 do vim.list_extend(lines,{'💬: q','🤖: a','body',''})end
        lines[#lines+1]=''
        local buf,doc=fixture(lines)
        local reader=require('parley.line_reader')
        local processed=0
        local observer=reader.set_observer(buf,function(event)
            processed=processed+(event.structure_rows_processed or 0)
        end)
        vim.api.nvim_buf_set_lines(buf,#lines-1,#lines,false,{'💬: next'})
        local uncertain=D.uncertain_range(doc)
        assert.is_true(not uncertain or uncertain.first>=#lines-8,vim.inspect(uncertain))
        settle(doc)
        reader.clear_observer(buf,observer)
        assert.is_true(processed<=16,tostring(processed))
        parity(buf,doc)
    end)
    local cases={
        {name='first footnote definition',base={'# topic: x','---','💬: q','🤖: a','body',''},first=5,last=6,new={'[^a]: definition'}},
        {name='last footnote definition removed',base={'# topic: x','---','💬: q','🤖: a','body','[^a]: definition'},first=5,last=6,new={''}},
        {name='first of multiple definitions removed',base={'# topic: x','---','💬: q','🤖: a','body','[^a]: a','[^b]: b'},first=5,last=6,new={''}},
        {name='last of multiple definitions inserted',base={'# topic: x','---','💬: q','🤖: a','body','[^a]: a',''},first=6,last=7,new={'[^b]: b'}},
        {name='header separator inserted',base={'# topic: x','plain','💬: q','🤖: a','body'},first=1,last=2,new={'---'}},
        {name='header separator removed',base={'# topic: x','---','💬: q','🤖: a','body'},first=1,last=2,new={'plain'}},
        {name='missing fence closer inserted',base={'💬: q','🤖: a','```lua','💬: hidden',''},first=4,last=5,new={'```'}},
        {name='fence closer removed',base={'💬: q','🤖: a','```lua','💬: hidden','```','💬: next'},first=4,last=5,new={''}},
        {name='fence opener inserted',base={'💬: q','🤖: a','plain','💬: hidden','```'},first=2,last=3,new={'```lua'}},
        {name='footer divider inserted',base={'💬: q','🤖: a','body','','[^a]: a'},first=3,last=4,new={'---'}},
    }
    for _,case in ipairs(cases)do
        it('matches a fresh parse when '..case.name,function()
            local buf,doc=fixture(case.base)
            vim.api.nvim_buf_set_lines(buf,case.first,case.last,false,case.new)
            parity(buf,doc)
        end)
    end
end)
