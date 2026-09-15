local A=require('parley.tools.wire_anthropic')
local O=require('parley.tools.wire_openai')
local function stream(events)local lines={};for _,e in ipairs(events)do lines[#lines+1]='data: '..vim.json.encode(e)end;return table.concat(lines,'\n')end
local function start(i,id)return {type='content_block_start',index=i,content_block={type='tool_use',id=id,name=id,input={}}}end
local function stop(i)return {type='content_block_stop',index=i}end
local function delta(i,text)return {type='content_block_delta',index=i,delta={type='input_json_delta',partial_json=text}}end
local function chunk(i,id,text)return {choices={{delta={tool_calls={{index=i,id=id,['function']={name=id,arguments=text}}}}}}}end
local function ids(calls)local out={};for _,c in ipairs(calls)do out[#out+1]=c.id end;return out end
describe('provider declared tool ordering',function()
    it('orders Anthropic sparse blocks independently of starts and stops',function()
        local calls=A.decode_tool_calls_from_stream(stream({start(9,'nine'),start(2,'two'),delta(9,'{"n":'),delta(2,'{"n":2}'),delta(9,'9}'),stop(9),stop(2)}))
        assert.same({'two','nine'},ids(calls));assert.same({n=9},calls[2].input)
    end)
    it('orders OpenAI sparse indexes independently of fragment arrival',function()
        local calls=O.decode_tool_calls_from_stream(stream({chunk(9,'nine','{"n":'),chunk(2,'two','{"n":2}'),chunk(9,nil,'9}')}))
        assert.same({'two','nine'},ids(calls));assert.same({n=9},calls[2].input)
    end)
    it('rejects invalid indexes without aliasing index zero',function()
        for _,index in ipairs({-1,0.5,'0',vim.NIL})do
            assert.same({},A.decode_tool_calls_from_stream(stream({start(index,'bad'),stop(index)})))
            assert.same({},O.decode_tool_calls_from_stream(stream({chunk(index,'bad','{}')})))
        end
        assert.same({},A.decode_tool_calls_from_stream(stream({start(nil,'bad'),stop(nil)})))
        assert.same({},O.decode_tool_calls_from_stream(stream({chunk(nil,'bad','{}')})))
        assert.same({},O.decode_tool_calls_from_stream('data: {"choices":[{"delta":{"tool_calls":[null,2,"bad"]}}]}'))
    end)
    it('does not reset Anthropic arguments or duplicate completed blocks',function()
        local calls=A.decode_tool_calls_from_stream(stream({start(0,'a'),delta(0,'{"x":'),start(0,'a'),delta(0,'1}'),stop(0),stop(0)}))
        assert.equals(1,#calls);assert.same({x=1},calls[1].input)
    end)
    it('rejects conflicting declarations rather than changing tool identity',function()
        assert.same({},A.decode_tool_calls_from_stream(stream({start(0,'a'),start(0,'b'),stop(0)})))
        assert.same({},A.decode_tool_calls_from_stream(stream({start(0,'a'),stop(0),start(0,'b'),stop(0)})))
        assert.same({},O.decode_tool_calls_from_stream(stream({chunk(0,'a',''),chunk(0,'b','{}')})))
    end)
    it('keeps declaration order across all three-call start and completion permutations',function()
        local permutations={{0,2,7},{0,7,2},{2,0,7},{2,7,0},{7,0,2},{7,2,0}}
        for _,arrival in ipairs(permutations)do for _,completion in ipairs(permutations)do
            local anthropic,openai={},{}
            for _,index in ipairs(arrival)do
                anthropic[#anthropic+1]=start(index,tostring(index))
                openai[#openai+1]=chunk(index,tostring(index),'')
            end
            for _,index in ipairs(completion)do
                anthropic[#anthropic+1]=delta(index,'{}');anthropic[#anthropic+1]=stop(index)
                openai[#openai+1]=chunk(index,nil,'{}')
            end
            assert.same({'0','2','7'},ids(A.decode_tool_calls_from_stream(stream(anthropic))))
            assert.same({'0','2','7'},ids(O.decode_tool_calls_from_stream(stream(openai))))
        end end
    end)

end)
