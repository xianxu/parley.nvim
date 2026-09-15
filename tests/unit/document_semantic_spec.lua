local ok,Semantic=pcall(require,'parley.document.semantic')
local S=require('parley.document.sequence')
local G=require('parley.document.grammar')

local function span(line)
    local _,token=G.lex_step(G.lex_start(),line,true,{bytes=#line})
    return {rows=1,bytes=#line+1,metadata={token=token}}
end
local function sequence(lines)
    local entries={}; for i,line in ipairs(lines) do entries[i]=span(line) end
    return S.new(entries,{empty_summary=G.empty_summary(),
        summarize=function(m) return G.summary(m.token) end,combine=G.combine})
end
local function settle(worker,budget)
    for _=1,500 do
        local result=Semantic.step(worker,budget or {rows=7,nodes=32768,entries=32768})
        assert.is_true(result.work.rows_processed<=(budget and budget.rows or 7))
        if result.status=='idle' then return end
        assert.is_not_equal('opaque',result.status)
    end
    error('semantic worker did not settle')
end

describe('document semantic worker',function()
    it('provides the pure worker',function() assert.is_true(ok) end)
    if not ok then return end

    it('projects global roles and answer-scoped sections from independent fixtures',function()
        local parser=require('parley.chat_parser')
        for _,case in ipairs(require('tests.fixtures.document_edits')) do
            local seq=sequence(case.lines)
            local worker=Semantic.new(seq)
            settle(worker)
            local actual=S.query(seq,0,#case.lines)
            local starts={}
            for i,row in ipairs(actual) do
                assert.is_true(Semantic.is_confirmed(worker,row.handle),case.name..' row '..i)
                if row.metadata.semantic.exchange_start then starts[#starts+1]=i end
            end
            assert.same(case.exchange_rows,starts,case.name)
            local parsed=parser.parse_chat(case.lines,0,{})
            for _,exchange in ipairs(parsed.exchanges) do
                for _,section in ipairs(exchange.answer and exchange.answer.semantic_sections or {}) do
                    for row=section.line_start,section.line_end do
                        if not actual[row].metadata.token.blank then
                            assert.equals(section.kind,actual[row].metadata.semantic.section_kind,case.name..' row '..row)
                        end
                    end
                end
            end
        end
    end)

    it('reports opaque demand and resumes after bounded token materialization',function()
        local seq=sequence({'💬: q','🤖: a'})
        S.splice(seq,2,2,{{rows=100,bytes=500,opaque=true}})
        local worker=Semantic.new(seq)
        local result=Semantic.step(worker)
        assert.equals('opaque',result.status)
        assert.equals(2,result.row)
        local added={}; for i=1,100 do added[i]=span('text') end
        S.splice(seq,2,102,added)
        settle(worker)
        assert.equals('text',S.at(seq,101).metadata.semantic.section_kind)
    end)

    it('invalidates before edits and converges under explicit row and index budgets',function()
        local seq=sequence({'💬: q','🤖: a','plain','more','💬: next','🤖: b','tail'})
        local worker=Semantic.new(seq)
        settle(worker)
        local evidence=Semantic.before_splice(worker,2,3)
        assert.is_true(evidence.work.dependency_nodes_visited>0)
        -- Text-backed negative header/footer facts conservatively restart at0.
        assert.equals(0,evidence.restart_row)
        S.splice(seq,2,3,{span('🧠: reasoning')})
        Semantic.after_splice(worker,evidence,2,3)
        assert.is_false(Semantic.is_confirmed(worker,S.at(seq,6).handle))
        for _=1,100 do
            S.stats(seq,true)
            local result=Semantic.step(worker,{rows=1,nodes=32768,entries=32768})
            local work=S.stats(seq)
            assert.equals(work.nodes_visited,result.work.nodes_visited)
            assert.equals(work.entries_visited,result.work.entries_visited)
            assert.is_true(work.nodes_visited<=32768)
            assert.is_true(work.entries_visited<=32768)
            assert.is_true(result.work.rows_processed<=1)
            if result.status=='idle' then break end
        end
        assert.equals('thinking',S.at(seq,2).metadata.semantic.section_kind)
        assert.is_true(Semantic.is_confirmed(worker,S.at(seq,6).handle))
    end)

    it('never blocks an edit when dependency invalidation has no budget',function()
        local seq=sequence({'💬: q','🤖: a','text'})
        local worker=Semantic.new(seq)
        settle(worker)
        local evidence=Semantic.before_splice(worker,2,3,{nodes=0,entries=0})
        assert.is_true(evidence.budget_exhausted)
        S.splice(seq,2,3,{span('replacement')})
        Semantic.after_splice(worker,evidence,2,3)
        assert.is_false(Semantic.is_confirmed(worker,S.at(seq,2).handle))
        settle(worker)
        assert.is_true(Semantic.is_confirmed(worker,S.at(seq,2).handle))
    end)

    it('bounds adversarial lookahead, dependency maintenance and projection work per slice',function()
        local lines={'💬: q','🤖: a'}
        for i=1,160 do lines[#lines+1]=i%3==0 and '```unmatched' or 'ordinary prose' end
        local seq=sequence(lines)
        local worker=Semantic.new(seq)
        local done=false
        for _=1,500 do
            S.stats(seq,true)
            local result=Semantic.step(worker,{rows=3,nodes=8192,entries=16384})
            local actual=S.stats(seq)
            assert.equals(actual.nodes_visited,result.work.nodes_visited)
            assert.equals(actual.entries_visited,result.work.entries_visited)
            assert.is_true(actual.nodes_visited<=8192)
            assert.is_true(actual.entries_visited<=16384)
            assert.is_true(result.work.rows_processed<=3)
            assert.is_number(result.work.summary_values_copied)
            if result.status=='idle' then done=true; break end
        end
        assert.is_true(done)
        assert.is_true(Semantic.is_confirmed(worker,S.at(seq,#lines-1).handle))
    end)

    it('keeps borrowed provenance live across unrelated projection during repair',function()
        local lines={'💬: q','🤖: a'}
        for _=1,40 do lines[#lines+1]='ordinary' end
        local seq=sequence(lines)
        local worker=Semantic.new(seq)
        local first=Semantic.step(worker,{rows=1,nodes=8192,entries=16384})
        assert.equals(1,first.work.rows_processed)
        local previous=S.at(seq,0).handle
        local tail=S.at(seq,41)
        tail.metadata.decoration={local_only=true}
        assert.is_true(S.project_many(seq,{{handle=tail.handle,metadata=tail.metadata}}))
        settle(worker)
        assert.equals(previous,S.at(seq,0).handle)
        assert.is_true(Semantic.is_confirmed(worker,previous))
    end)

    it('returns budget without hidden work when an index slice is too small',function()
        local seq=sequence({'💬: q','🤖: a','body'})
        local worker=Semantic.new(seq)
        S.stats(seq,true)
        local result=Semantic.step(worker,{rows=1,nodes=1,entries=1})
        assert.equals('budget',result.status)
        assert.equals(0,result.work.rows_processed)
        assert.equals(0,S.stats(seq).nodes_visited)
        assert.equals(0,S.stats(seq).entries_visited)
        settle(worker)
    end)

    it('advances an active answer scope while disjoint syntax edits keep arriving',function()
        local lines={'💬: first','🤖: a'}
        for _=1,30 do lines[#lines+1]='body' end
        lines[#lines+1]='💬: second'; lines[#lines+1]='🤖: b'; lines[#lines+1]='tail'
        local seq=sequence(lines)
        local worker=Semantic.new(seq)
        local previous
        for _=1,100 do
            local result=Semantic.step(worker,{rows=1})
            if result.deltas[1] and result.deltas[1].kind=='section' then
                previous=S.rank(seq,result.deltas[1].handle).row; break
            end
        end
        assert.equals(2,previous)
        for i=1,12 do
            local evidence=Semantic.before_splice(worker,34,35)
            S.splice(seq,34,35,{span(i%2==0 and '🧠: later' or 'tail')})
            Semantic.after_splice(worker,evidence,34,35)
            local result=Semantic.step(worker,{rows=1})
            assert.equals('section',result.deltas[1] and result.deltas[1].kind)
            local current=S.rank(seq,result.deltas[1].handle).row
            assert.equals(previous+1,current)
            previous=current
            assert.is_false(Semantic.is_confirmed(worker,result.deltas[1].handle))
        end
        settle(worker)
        assert.is_true(Semantic.is_confirmed(worker,S.at(seq,20).handle))
    end)

    it('requires finite nonnegative integer budgets before performing work',function()
        local seq=sequence({'plain'})
        local worker=Semantic.new(seq)
        for _,key in ipairs({'rows','nodes','entries','budget_nodes','budget_entries'}) do
            for _,value in ipairs({math.huge,-1,0.5,0/0}) do
                S.stats(seq,true)
                assert.has_error(function() Semantic.step(worker,{[key]=value}) end)
                assert.equals(0,S.stats(seq).nodes_visited)
            end
        end
    end)
end)
