local D=require('parley.dispatcher')
describe('position-free stream output',function()
    it('provides the scoped output adapter',function()
        assert.equals('function',type(D.create_output_handler))
    end)
    if type(D.create_output_handler)~='function' then return end
    it('preserves bytes across every fragmentation including leading empty chunks',function()
        local source='\n\nhello 🧠: world\n```lua\nprint(1)\n```\n'
        local expected=source:gsub('^\n+','')
        for width=1,#source do
            local out={}
            local handler=D.create_output_handler(function(qid,text)
                assert.equals('attempt',qid);out[#out+1]=text;return true
            end)
            handler('attempt','')
            for first=1,#source,width do handler('attempt',source:sub(first,first+width-1)) end
            assert.equals(expected,table.concat(out))
        end
    end)
    it('never rewrites or re-emits an accumulated long line',function()
        local total,calls=0,0
        local chunk=string.rep('x',4096)
        local handler=D.create_output_handler(function(_,text)
            assert.equals(chunk,text);total=total+#text;calls=calls+1;return true
        end)
        for _=1,256 do assert.is_true(handler('a',chunk)) end
        assert.equals(1048576,total);assert.equals(256,calls)
    end)
    it('keeps independent streams isolated and retires rejected output',function()
        local a,b={},{}
        local first=D.create_output_handler(function(_,text) a[#a+1]=text;return false end)
        local second=D.create_output_handler(function(_,text) b[#b+1]=text;return true end)
        assert.is_false(first('a','old'))
        assert.is_false(first('a','late'))
        assert.is_true(second('b','new'))
        assert.same({'old'},a);assert.same({'new'},b)
    end)
    it('admits output synchronously before a following completion callback',function()
        local order={}
        local handler=D.create_output_handler(function() order[#order+1]='output';return true end)
        handler('a','hello');order[#order+1]='complete'
        assert.same({'output','complete'},order)
    end)
end)
