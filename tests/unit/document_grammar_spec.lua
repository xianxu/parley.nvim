local grammar = require('parley.document.grammar')
local legacy = require('parley.highlight_structure')
local fence = require('parley.fence')
local patterns = legacy.patterns({})
local function token(line, fragment)
    local cursor = grammar.lex_start(patterns)
    local result
    local position = 1
    repeat
        local bytes = line:sub(position, position + (fragment or 7) - 1)
        local next_cursor, value, work = grammar.lex_step(cursor, bytes, position + #bytes > #line, { bytes = 3 })
        assert.is_true(work.bytes_scanned <= 3)
        cursor, result = next_cursor, value
        position = position + work.bytes_scanned
    until result
    return result
end
local function fact(value) return { value = value, certificate = { stamp = 'test' } } end
local function run(lines, extra)
    local state = grammar.initial()
    local rows = {}
    local section_state
    for i, line in ipairs(lines) do
        local t = token(line); t.provenance = i
        local facts = { header = fact(false), footer = fact(false), ordinary_close = fact(false),
            tool_body = fact(false), section_ordinary_close = fact(false), reasoning = fact(false), preface = fact(false) }
        for k,v in pairs((extra or {})[i] or {}) do facts[k] = fact(v) end
        local result = grammar.advance(state,t,facts)
        assert.is_nil(result.need)
        if result.semantic.answer_start then section_state=grammar.initial_sections()
        elseif result.semantic.role=='answer' and not result.semantic.preface then
            facts.section_tool_body=facts.tool_body
            local projected=grammar.advance_sections(section_state,t,facts)
            assert.is_nil(projected.need)
            result.semantic.section_kind=projected.section.kind
            section_state=projected.checkpoint
        else section_state=nil end
        rows[i], state = result, result.checkpoint
    end
    return rows, state
end

describe('document grammar', function()
    it('classifies fragmented lines like the independent legacy dialects', function()
        local lines = {'', ' ', 'hello', '💬: q', '🤖: a', '🔧: tool', '📎: result',
            '🧠: thinking', '  🧠:[END]  ', '📝: sum', '🌿: link', '🔒: note',
            '```lua', ' ````python ', '```   ', '```x`', '~~~', '=== x ===',
            '=== end === ', '===  ===', ' [^long identifier]: footnote ', '@@tag@@', ' --- '}
        for _,line in ipairs(lines) do
            local t = token(line, 5)
            assert.equals(legacy.classify(line,patterns).kind,t.kind,line)
            assert.equals(fence.open_len(line),t.ordinary_open_width,line)
            assert.equals(require('parley.question_tags').parse_tag(line) ~= nil,t.preface_tag,line)
        end
    end)
    it('keeps bounded lexer storage on an enormous unfinished label', function()
        local cursor = grammar.lex_start(patterns)
        cursor = grammar.lex_step(cursor,'=== ',false,{bytes=4})
        for _=1,1000 do cursor = grammar.lex_step(cursor,string.rep('x',100),false,{bytes=100}) end
        local _,t = grammar.lex_step(cursor,' ===',true,{bytes=4})
        assert.equals('draft_open',t.kind)
        assert.is_true(grammar.lexer_retained_bytes(cursor)<128)
    end)
    it('does not advance without explicit negative lookahead evidence', function()
        local t=token('💬: q'); t.provenance=1
        local state=grammar.initial()
        assert.equals('header',grammar.advance(state,t,{}).need.kind)
        assert.is_nil(state.role)
    end)
    it('keeps ordinary quoted question markers structural', function()
        local rows=run({'💬: q','🤖: a','```','💬: quoted','📎: quoted tool','```'},
            {[3]={ordinary_close=6}})
        assert.is_true(rows[4].semantic.exchange_start)
        assert.equals('text',rows[5].semantic.kind)
    end)
    it('uses complete tool bodies and reasoning END facts', function()
        local rows=run({'💬: q','🤖: a','📎: result','```','🧠: body','```','🧠: think','','more','🧠:[END]'},
            {[3]={tool_body={close=6}},[7]={reasoning=true}})
        assert.equals('text',rows[5].semantic.kind)
        assert.is_true(rows[9].render_before.in_reasoning)
        assert.equals('thinking',rows[9].semantic.section_kind)
    end)
    it('compares every lexical fact while ignoring payload identity and size', function()
        assert.is_true(grammar.same_token(token('word'),token('a longer word')))
        assert.is_false(grammar.same_token(token('```'),token(' ```')))
        assert.is_false(grammar.same_token(token('@@x@@'),token('ordinary')))
        local combined=grammar.combine(grammar.summary(token('```')),grammar.summary(token('💬: q')))
        assert.is_true(grammar.may_contain(combined,{kind='bare_close',width=3}))
        assert.is_false(grammar.may_contain(combined,{kind='bare_close',width=4}))
        assert.is_true(grammar.may_contain(combined,{kind='user'}))
        assert.are.same(grammar.summary(token('text')),grammar.combine(grammar.empty_summary(),grammar.summary(token('text'))))
    end)
    it('matches legacy row render states through malformed syntax and partitions', function()
        local lines={'💬: q','🤖: a','````lua','```','💬: new','🤖: a','🧠: think','','more','🧠:[END]','🔧: x','```','x','```','[^id]: note'}
        local rows=run(lines,{[1]={footer={start=15,content_start=15}},[7]={reasoning=true}})
        local expected=legacy.build(lines,patterns)
        for i,row in ipairs(rows) do assert.are.same(expected.state_before[i],row.render_before,'row '..i) end
    end)
    it('finishes legacy tool sections at annotation boundaries', function()
        local rows=run({'💬: q','🤖: a','📎: unclosed','body','🔒: note','plain'})
        assert.equals('tool_result',rows[4].semantic.section_kind)
        assert.equals('text',rows[5].semantic.section_kind)
        assert.equals('text',rows[6].semantic.section_kind)
    end)
    it('tracks header, footer cutoff, draft and preface without payload strings', function()
        local rows=run({'---','key: value','---','@@tag@@','💬: q','🤖: a','=== draft ===','text','=== end ===','---','','[^id]: value'},
            {[1]={header={finish=3},footer={start=12,content_start=10}},[4]={preface=true}})
        assert.is_true(rows[3].semantic.header)
        assert.is_true(rows[4].semantic.preface)
        assert.equals(4,rows[5].semantic.preface_origin)
        assert.is_true(rows[7].semantic.draft_start)
        assert.is_true(rows[9].semantic.draft_end)
        assert.is_true(rows[10].semantic.content_ended)
        assert.is_false(rows[10].semantic.footer)
        assert.is_true(rows[12].semantic.footer)
    end)

    it('matches seeded lexical mutations and custom prefixes independently', function()
        local seed=254
        local function random(n) seed=(seed*16807)%2147483647; return seed%n+1 end
        local atoms={' ','\t','`','~','===','@@','[',']','^',':','END','💬:','🤖:','🧠:','x'}
        for _=1,600 do
            local pieces={}
            for _=1,random(16) do pieces[#pieces+1]=atoms[random(#atoms)] end
            local line=table.concat(pieces)
            local t=token(line,random(7))
            assert.equals(legacy.classify(line,patterns).kind,t.kind,line)
            assert.equals(fence.open_len(line),t.ordinary_open_width,line)
            if t.bare_close_width then assert.is_true(fence.closes(line,t.bare_close_width),line) end
        end
        local custom=legacy.patterns({chat_user_prefix='USER>',chat_assistant_prefix={'BOT>'},
            chat_memory={enable=true,reasoning_prefix='THINK>',summary_prefix='SUM>'}})
        for _,line in ipairs({'USER> hi','BOT> hi',' THINK>[END] ','THINK> x','SUM> done'}) do
            local c=grammar.lex_start(custom)
            local _,t=grammar.lex_step(c,line,true,{bytes=#line})
            assert.equals(legacy.classify(line,custom).kind,t.kind)
        end
    end)
    it('matches independent exchange and answer parsing on dialect fixtures', function()
        local parser=require('parley.chat_parser')
        for _,case in ipairs(require('tests.fixtures.document_edits')) do
            local lines=case.lines
            local kinds={}; for i,line in ipairs(lines) do kinds[i]=legacy.classify(line,patterns).kind end
            local bodies=fence.scan(lines,function(_,i) return kinds[i]=='tool_use' or kinds[i]=='tool_result' end,
                function(_,i) return legacy.is_structural_kind(kinds[i]) end)
            local prefaces=require('parley.question_tags').associations(lines,{},0)
            local extra={}
            for i,line in ipairs(lines) do
                extra[i]={}
                local width=fence.open_len(line)
                if width then
                    for j=i+1,#lines do if fence.closes(lines[j],width) then extra[i].ordinary_close=j; break end end
                end
                if bodies[i] then extra[i].tool_body={close=bodies[i].close} end
                if kinds[i]=='reasoning' then
                    for j=i+1,#lines do
                        if kinds[j]=='reasoning_end' then extra[i].reasoning=true; break end
                        if legacy.is_structural_kind(kinds[j]) then break end
                    end
                end
                if prefaces[i+1] then extra[i].preface=true end
            end
            for i,line in ipairs(lines) do
                local width=fence.open_len(line)
                if width then
                    for j=i+1,#lines do
                        if kinds[j]=='user' or kinds[j]=='assistant' then break end
                        if fence.closes(lines[j],width) then extra[i].section_ordinary_close=j; break end
                    end
                end
            end
            local rows=run(lines,extra)
            local starts,answers={},{}
            for i,row in ipairs(rows) do
                if row.semantic.exchange_start then starts[#starts+1]=i end
                if row.semantic.answer_start then answers[#answers+1]=i end
            end
            assert.are.same(case.exchange_rows,starts,case.name)
            assert.are.same(case.answer_rows,answers,case.name)
            local parsed=parser.parse_chat(lines,0,{})
            local expected={}; for _,exchange in ipairs(parsed.exchanges) do expected[#expected+1]=exchange.question.line_start end
            assert.are.same(expected,starts,case.name)
            for _,exchange in ipairs(parsed.exchanges) do
                for _,section in ipairs(exchange.answer and exchange.answer.semantic_sections or {}) do
                    for row=section.line_start,section.line_end do
                        if not token(lines[row]).blank then
                            assert.equals(section.kind,rows[row].semantic.section_kind,case.name..' row '..row)
                        end
                    end
                end
            end
        end
    end)
    it('preserves the preface tilde dialect and incomplete synthetic exchange', function()
        local rows=run({'~~~','@@hidden@@','💬: q','@@shown@@','💬: next'},
            {[2]={preface=true},[4]={preface=true}})
        assert.is_nil(rows[2].semantic.preface)
        assert.equals(4,rows[5].semantic.preface_origin)
        local initial=run({'prose','🤖: alone'})
        assert.is_true(initial[2].semantic.synthetic)
        assert.is_true(initial[2].semantic.answer_start)
        assert.equals(1,initial[2].semantic.exchange)
    end)

    it('ends reasoning at a fenced tool marker without admitting a tool section', function()
        for _,marker in ipairs({'📎: x','🔧: x'}) do
            local rows=run({'💬: q','🤖: a','```','🧠: think',marker,'```'},
                {[3]={ordinary_close=6,section_ordinary_close=6}})
            assert.equals('thinking',rows[4].semantic.section_kind)
            assert.equals('text',rows[5].semantic.section_kind)
            assert.equals('text',rows[6].semantic.section_kind)
        end
    end)

    it('keeps section lookahead scoped and preserves the prior checkpoint on retry', function()
        local scope_end={id='answer-end'}
        local state=grammar.initial_sections({['end']=scope_end})
        local t=token('```'); t.provenance={id='open'}
        local result=grammar.advance_sections(state,t,{})
        assert.equals('section_ordinary_close',result.need.kind)
        assert.equals(scope_end,result.need.scope['end'])
        assert.equals('text',state.section)
        assert.is_nil(state.ordinary_close)
        assert.is_false(grammar.validate_certificate({},function() return false end))
        assert.is_false(grammar.validate_certificate({},nil))
        assert.is_true(grammar.validate_certificate({},function() return true end))
    end)

end)
