local S=require('parley.document.sequence')
local G=require('parley.document.grammar')
local Semantic=require('parley.document.semantic')
local Dependencies=require('parley.document.dependencies')
local function fixture()
    local spans={}
    local lines={'# topic: admission','---'}
    for _=1,40 do vim.list_extend(lines,{'💬: q','🤖: a','🧠: thought','body'})end
    for _,line in ipairs(lines)do
        local _,token=G.lex_step(G.lex_start(),line,true,{bytes=#line})
        spans[#spans+1]={rows=1,bytes=#line+1,metadata={token=token}}
    end
    local seq=S.new(spans,{empty_summary=G.empty_summary(),channel_names=G.CHANNELS,
        channels=function(m)return G.channels(m.token)end,
        summarize=function(m)return G.summary(m.token)end,combine=G.combine})
    local worker=Semantic.new(seq)
    for _=1,1000 do
        if Semantic.step(worker,{rows=256,nodes=32768,entries=32768}).status=='idle'then return seq,worker end
    end
    error('fixture did not settle')
end

describe('splice dependency admission',function()
    for _,limit in ipairs({0,1200,4096,32768})do
        it('charges actual index work within '..limit..' nodes and entries',function()
            local seq,worker=fixture()
            local size=S.size(seq);local first=S.at(seq,0).handle
            S.stats(seq,true)
            local evidence=Semantic.before_splice(worker,size.rows,size.rows,
                {nodes=limit,entries=limit,channels={row=true,structural=true,nonblank=true}})
            local work=S.stats(seq)
            assert.equals(work.nodes_visited,evidence.work.nodes_visited)
            assert.equals(work.entries_visited,evidence.work.entries_visited)
            assert.is_true(work.nodes_visited<=limit,tostring(work.nodes_visited))
            assert.is_true(work.entries_visited<=limit,tostring(work.entries_visited))
            assert.is_true(evidence.work.dependency_nodes_visited<=256)
            assert.same(size,S.size(seq))
            assert.equals(first,S.at(seq,0).handle,'admission must not mutate text identity')
            if limit==0 then assert.is_true(evidence.budget_exhausted)end
        end)
    end
    it('does not publish a partial dependency removal when rank admission refuses',function()
        local index=Dependencies.new({rank=function(handle)return handle end})
        for i=1,30 do assert.equals('ok',index:add(i,i+1,{channels={'row','footnote'}}).status)end
        local roots=index.roots
        local ranks=0
        local result=index:remove_from(15,{budget=128,before_rank=function()
            ranks=ranks+1;return ranks<=3
        end})
        assert.equals('budget',result.status)
        assert.equals(roots,index.roots)
        assert.equals(29,index:restart_origin(30,30,{channels={'footnote'}}).origin)
    end)
end)
