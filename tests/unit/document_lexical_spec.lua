local lexical

describe('shared document lexical grammar',function()
    before_each(function() lexical=require('parley.document.lexical') end)
    it('preserves native and resumable marker precedence on golden lines',function()
        local cases={
            {'  [^id]: value','footnote'}, {'=== end === ','draft_end'},
            {'=== draft ===','draft_open'}, {' ````lua','fence'},
            {'  🧠:[END] ','reasoning_end'}, {'🧠: think','reasoning'},
            {'💬: question','user'}, {'🤖: answer','assistant'},
            {'🔒: private','local'}, {'🌿: branch','branch'},
            {'📝: summary','summary'}, {'🔧: call','tool_use'},
            {'📎: result','tool_result'}, {' \t','blank'}, {'~~~','text'},
        }
        local patterns=lexical.patterns({})
        for _,case in ipairs(cases) do
            assert.equals(case[2],lexical.classify(case[1],patterns).kind)
            local cursor=lexical.lex_start(patterns)
            local _,token=lexical.lex_step(cursor,case[1],true,{bytes=#case[1]})
            assert.equals(case[2],token.kind)
        end
    end)
    it('keeps ordinary and render fence contracts distinct',function()
        assert.equals(4,lexical.is_fence_delim(' ````lua'))
        assert.is_nil(lexical.ordinary_open_len(' ````lua'))
        assert.equals(4,lexical.ordinary_open_len('````json {"type":"x"}'))
        assert.is_false(lexical.ordinary_closes('`````',4))
        assert.is_true(lexical.ordinary_closes('````  ',4))
        local state={in_code=true,code_fence_len=4}
        lexical.advance(state,'c5',5)
        assert.is_false(state.in_code)
        assert.is_nil(lexical.ordinary_open_len('```a`b'))
    end)
    it('resets custom partitions while retaining the tilde memo dialect',function()
        local patterns=lexical.patterns({chat_user_prefix='USER>',chat_assistant_prefix={'BOT>'}})
        assert.are.same({true,true,false,false},lexical.code_block_memo({'~~~','text','USER> q','body'},patterns,true))
        local state={in_code=true,code_fence_len=3,in_tool=true}
        lexical.reset_partition(state,'u')
        assert.is_false(state.in_code)
        assert.is_false(state.in_tool)
    end)
    it('can mask plain Markdown fences without treating chat-looking samples as partitions',function()
        for _, config in ipairs({{}, {chat_user_prefix='USER>',chat_assistant_prefix={'BOT>'},
            chat_branch_prefix='BRANCH>',chat_local_prefix='PRIVATE>'}}) do
            local patterns=lexical.patterns(config)
            for _, field in ipairs({'user_prefix','assistant_prefix','branch_prefix','local_prefix'}) do
                local lines={'```',patterns[field]..' sample','2. sample','```','after'}
                assert.same({true,true,true,false,false},lexical.code_block_memo(lines,patterns,true,false))
                assert.same({true,false,false,true,true},lexical.code_block_memo(lines,patterns,true))
            end
        end
    end)
end)
