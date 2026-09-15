local ok,Semantic=pcall(require,'parley.document.semantic')
local S=require('parley.document.sequence')
local G=require('parley.document.grammar')

local function span(line)
    local _,token=G.lex_step(G.lex_start(),line,true,{bytes=#line})
    return {rows=1,bytes=#line+1,metadata={token=token}}
end
local function sequence(lines)
    local entries={}; for i,line in ipairs(lines) do entries[i]=span(line) end
    return S.new(entries,{empty_summary=G.empty_summary(),channel_names=G.CHANNELS,
        channels=G.channels and function(m) return G.channels(m.token) end or nil,
        summarize=function(m) return G.summary(m.token) end,combine=G.combine})
end
local function fragment(seq,worker,first,last,lines)
    local added={}; for i,line in ipairs(lines) do added[i]=span(line) end
    local evidence=Semantic.before_fragment(worker,first,last,added,{rows=256,bytes=65536,nodes=65536,entries=65536})
    S.splice(seq,first,last,added)
    return Semantic.after_fragment(worker,evidence,first,first+#added)
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
        -- Unclassified range edits conservatively query every fact channel.
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

    it('exposes the confirmed frontier without copying row metadata',function()
        local seq=sequence({'💬: q','🤖: a','body','💬: next','draft'})
        local worker=Semantic.new(seq)
        assert.equals(0,Semantic.confirmed_frontier(worker))
        Semantic.step(worker,{rows=3})
        assert.equals(3,Semantic.confirmed_frontier(worker))
        assert.is_false(S.at(seq,2).metadata.confirmed)
        Semantic.step(worker,{rows=1})
        assert.equals(4,Semantic.confirmed_frontier(worker))
        Semantic.step(worker,{rows=1})
        assert.equals(4,Semantic.confirmed_frontier(worker))
        assert.is_true(S.at(seq,2).metadata.confirmed)
        settle(worker)
        S.stats(seq,true)
        assert.equals(5,Semantic.confirmed_frontier(worker))
        assert.equals(0,S.stats(seq).metadata_values_copied)
        assert.equals('reused',fragment(seq,worker,4,5,{'draft first','draft second'}).status)
        assert.equals(6,Semantic.confirmed_frontier(worker))
        local evidence=Semantic.before_splice(worker,2,3)
        S.splice(seq,2,3,{span('🧠: changed')})
        Semantic.after_splice(worker,evidence,2,3)
        assert.equals(evidence.restart_row,Semantic.confirmed_frontier(worker))
    end)

    it('reuses confirmed question and answer suffixes after Enter and Backspace',function()
        for _,lines in ipairs({{'💬: q','question body','question tail'},
            {'💬: q','🤖: a','answer body','answer tail'}}) do
            local seq=sequence(lines)
            local worker=Semantic.new(seq); settle(worker)
            local row=#lines-2
            local suffix=S.at(seq,row+1).handle
            local old=S.at(seq,row).handle
            local source=S.range_certificate(seq,row,row+1)
            assert.equals('reused',fragment(seq,worker,row,row+1,{'body first','body second'}).status)
            assert.is_nil(S.rank(seq,old))
            assert.is_false(S.validate_certificate(seq,source))
            assert.equals(row+2,S.rank(seq,suffix).row)
            assert.is_true(Semantic.is_confirmed(worker,suffix))
            assert.equals('reused',fragment(seq,worker,row,row+2,{'joined body'}).status)
            assert.equals(row+1,S.rank(seq,suffix).row)
            assert.equals('idle',Semantic.step(worker).status)
        end
    end)

    it('compares full reasoning checkpoints and honors immediate adjacency',function()
        local seq=sequence({'💬: q','🤖: a','🧠: reason','body','tail'})
        local worker=Semantic.new(seq); settle(worker)
        assert.is_not_equal('reused',fragment(seq,worker,4,4,{''}).status)
        settle(worker)
        assert.equals('text',S.at(seq,5).metadata.semantic.section_kind)
        seq=sequence({'💬: q','🤖: a','🧠: reason','body','tail','🧠:[END]'})
        worker=Semantic.new(seq); settle(worker)
        assert.equals('reused',fragment(seq,worker,4,4,{''}).status)
        assert.equals('thinking',S.at(seq,5).metadata.semantic.section_kind)
        seq=sequence({'💬: q','🤖: a','🔧: tool','plain','tail'})
        worker=Semantic.new(seq); settle(worker)
        assert.is_not_equal('reused',fragment(seq,worker,3,3,{''}).status)
        settle(worker)
    end)

    it('supports question drafting at EOF while refusing marker and oversized changes',function()
        local seq=sequence({'💬: q','body'})
        local worker=Semantic.new(seq); settle(worker)
        assert.equals('reused',fragment(seq,worker,2,2,{'more'}).status)
        assert.is_true(Semantic.is_confirmed(worker,S.at(seq,2).handle))
        assert.is_not_equal('reused',fragment(seq,worker,1,2,{'---'}).status)
        settle(worker)
        local oversized={span(string.rep('x',65537))}
        local evidence=Semantic.before_fragment(worker,1,2,oversized)
        assert.equals('fallback',evidence.status)
    end)

    it('adds a first plain body row after a surviving question or answer marker at EOF',function()
        for _,lines in ipairs({{'💬: q'},{'💬: q','🤖: a'}}) do
            local seq=sequence(lines)
            local worker=Semantic.new(seq); settle(worker)
            local marker=S.at(seq,#lines-1).handle
            assert.equals('reused',fragment(seq,worker,#lines,#lines,{'new body'}).status)
            assert.equals(marker,S.at(seq,#lines-1).handle)
            assert.is_true(Semantic.is_confirmed(worker,S.at(seq,#lines).handle))
            if #lines==2 then assert.equals('text',S.at(seq,#lines).metadata.semantic.section_kind) end
        end
    end)

    it('keeps an active answer scope progressing across a question-body newline',function()
        local lines={'💬: q','draft','🤖: a'}
        for _=1,30 do lines[#lines+1]='body' end
        lines[#lines+1]='💬: next'
        local seq=sequence(lines)
        local worker=Semantic.new(seq)
        local expected
        for _=1,100 do
            local result=Semantic.step(worker,{rows=1})
            if result.deltas[1] and result.deltas[1].kind=='section' then
                expected=S.at(seq,S.rank(seq,result.deltas[1].handle).row+1).handle; break
            end
        end
        assert.is_not_nil(expected)
        assert.equals('reused',fragment(seq,worker,1,2,{'draft first','draft second'}).status)
        local result=Semantic.step(worker,{rows=1})
        assert.equals('section',result.deltas[1].kind)
        assert.equals(expected,result.deltas[1].handle)
        settle(worker)
    end)

    it('bounds Enter and Backspace independently of document row count',function()
        for _,size in ipairs({100,1000,10000,50000}) do
            local lines={'💬: q'}
            for i=2,size do lines[i]='body' end
            local seq=sequence(lines)
            local worker=Semantic.new(seq)
            local settled=false
            for _=1,size do
                if Semantic.step(worker,{rows=256}).status=='idle' then settled=true; break end
            end
            assert.is_true(settled)
            local row=math.floor(size/2)
            local suffix=S.at(seq,row+1)
            S.stats(seq,true)
            assert.equals('reused',fragment(seq,worker,row,row+1,{'first','second'}).status)
            local work=S.stats(seq)
            assert.is_true(work.nodes_visited<512,'nodes at '..size..': '..work.nodes_visited)
            assert.is_true(work.entries_copied<1024)
            assert.is_true(work.entries_visited<2048)
            assert.equals(suffix.handle,S.at(seq,row+2).handle)
            assert.same(suffix.metadata,S.at(seq,row+2).metadata)
            S.stats(seq,true)
            assert.equals('reused',fragment(seq,worker,row,row+2,{'joined'}).status)
            work=S.stats(seq)
            assert.is_true(work.nodes_visited<512)
            assert.is_true(work.entries_copied<1024)
            assert.is_true(work.entries_visited<2048)
            assert.equals('idle',Semantic.step(worker).status)
        end
    end)
end)
