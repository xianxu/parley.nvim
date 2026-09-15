local S = require('parley.document.sequence')
local G = require('parley.document.grammar')
local Semantic = require('parley.document.semantic')
local P
local function fixture(lines)
    local values={}
    for i,line in ipairs(lines) do
        local _,token=G.lex_step(G.lex_start(),line,true,{bytes=#line})
        values[i]={rows=1,bytes=#line+1,metadata={token=token}}
    end
    local seq=S.new(values,{summarize=function(m)return G.summary(m.token)end,combine=G.combine,
        empty_summary=G.empty_summary(),channel_names=G.CHANNELS,channels=function(m)return G.channels(m.token)end,
        projection_summary=P.summary,combine_projection=P.combine,empty_projection=P.empty()})
    local worker=Semantic.new(seq)
    for _=1,#lines*3+20 do
        local result=Semantic.step(worker,{rows=256,nodes=32768,entries=32768})
        if result.status=='idle' then return seq end
    end
    error('fixture did not settle')
end
describe('indexed semantic projections',function()
    before_each(function()local ok,m=pcall(require,'parley.document.projection');assert.is_true(ok,tostring(m));P=m end)
    it('finds exchanges and bounded fold ranges with blank and exact fence endings',function()
        local lines={'💬: q','🤖: a','🧠: thought','body','','plain','🔧: read','````lua','```','````','tail','💬: next'}
        local seq=fixture(lines)
        local ex=P.exchange(seq,5)
        assert.equals('ready',ex.status)
        assert.equals(0,ex.first);assert.equals(11,ex.last)
        local result=P.folds(seq,ex.first,ex.last)
        local ranges={}
        for _=1,20 do
            for _,range in ipairs(result.ranges or {}) do ranges[#ranges+1]=range end
            if result.status=='ready' then break end
            assert.equals('budget',result.status)
            result=P.folds(seq,ex.first,ex.last,{cursor=result.cursor})
        end
        assert.equals('ready',result.status)
        assert.equals(2,#ranges)
        assert.equals('thinking',ranges[1].kind);assert.equals(2,ranges[1].start_0);assert.equals(3,ranges[1].end_0)
        assert.equals('tool_use',ranges[2].kind);assert.equals(6,ranges[2].start_0);assert.equals(9,ranges[2].end_0)
    end)
    it('paginates adjacent one-row summaries and invalidates paused projections',function()
        local lines={'💬: q','🤖: a','🧠: thought','body'}
        for _=1,12 do lines[#lines+1]='📝: summary' end
        local seq=fixture(lines)
        local result=P.folds(seq,0,#lines)
        assert.equals('budget',result.status)
        assert.equals(8,#result.ranges)
        assert.equals(3,result.ranges[1].end_0)
        local resumed=P.folds(seq,0,#lines,{cursor=result.cursor})
        assert.equals('ready',resumed.status)
        assert.equals(5,#resumed.ranges)
        local span=S.at(seq,6)
        span.metadata.semantic.section_kind='text'
        S.project_many(seq,{{handle=span.handle,metadata=span.metadata}})
        assert.equals('stale',P.folds(seq,0,#lines,{cursor=result.cursor}).status)
    end)
    it('prunes fifty thousand nonboundary rows and honors refused slice budgets',function()
        local values={}
        for i=1,50000 do values[i]={rows=1,bytes=2,metadata={token={kind='text'},confirmed=true,
            semantic={exchange_start=i==1}}} end
        local seq=S.new(values,{projection_summary=P.summary,combine_projection=P.combine,empty_projection=P.empty()})
        local result=P.exchange(seq,25000,{budget_nodes=1024,budget_entries=2048})
        assert.equals('ready',result.status)
        assert.equals(0,result.first);assert.equals(50000,result.last)
        assert.is_true(result.work.nodes_visited<=1024)
        assert.is_true(result.work.entries_visited<=2048)
        local refused=P.folds(seq,0,50000,{budget_nodes=1,budget_entries=1})
        assert.equals('budget',refused.status)
        assert.equals(0,refused.work.nodes_visited)
        assert.equals('ready',P.folds(seq,0,50000,{cursor=refused.cursor}).status)
    end)
    it('recognizes bounded heading prefixes and respects outline fence dialect',function()
        for _,case in ipairs({{'# title',1},{'## title',2},{'### title',3},{'#### title',false},
            {' # indented',false},{'#\ttab',false},{'##nospace',false}}) do
            local cursor=G.lex_start()
            local token
            for i=1,#case[1] do cursor,token=G.lex_step(cursor,case[1]:sub(i,i),i==#case[1],{bytes=1}) end
            assert.equals(case[2],token.heading_level or false)
        end
        local seq=fixture({'# visible','~~~','# hidden','~~~','## shown','💬: q','### chat heading'})
        assert.equals(0,P.find(seq,0,7,'outline').span.start_row)
        assert.equals(4,P.find(seq,1,7,'outline').span.start_row)
        assert.equals(5,P.find(seq,0,7,'outline_chat').span.start_row)
        assert.equals('not_found',P.find(seq,6,7,'outline_chat').status)
    end)
    it('keeps completed exchange evidence local after a disjoint projection update',function()
        local seq=fixture({'💬: first','a','b','c','💬: second','body','tail','💬: third','d'})
        local result=P.exchange(seq,5)
        assert.equals('ready',result.status)
        local span=S.at(seq,0);span.metadata.extra='unrelated projection'
        S.project_many(seq,{{handle=span.handle,metadata=span.metadata}})
        assert.is_true(P.validate(seq,result.certificate))
        span=S.at(seq,5);span.metadata.extra='inside projection'
        S.project_many(seq,{{handle=span.handle,metadata=span.metadata}})
        assert.is_false(P.validate(seq,result.certificate))
    end)
    it('refuses unknown metadata and indexes confirmed outline candidates',function()
        local seq=fixture({'💬: q','body','🌿: branch','@@tag@@','💬: next'})
        local item=P.find(seq,1,5,'outline')
        assert.equals('found',item.status);assert.equals(2,item.span.start_row)
        local span=S.at(seq,1);span.metadata.confirmed=false
        S.project_many(seq,{{handle=span.handle,metadata=span.metadata}})
        assert.equals('opaque',P.find(seq,1,5,'outline').status)
    end)
end)
