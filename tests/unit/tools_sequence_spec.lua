-- #266 M2: the order a tool round's (call, result) pairs are written in.
local loaded,Seq=pcall(require,'parley.tools.sequence')

describe('tool insertion sequence',function()
    it('provides the module',function() assert.is_true(loaded,tostring(Seq)) end)
    if not loaded then return end

    local function drain(seq)
        local items={}
        while true do
            local item=Seq.next(seq)
            if not item then return seq,items end
            items[#items+1]=item.kind..item.index
            seq=Seq.written(seq,item)
        end
    end

    it('offers the first call before any outcome arrives',function()
        assert.same({kind='call',index=1},Seq.next(Seq.new(2)))
    end)

    it('holds a result until its own outcome arrives, whatever arrives after it',function()
        local seq=Seq.new(2)
        seq=Seq.written(seq,Seq.next(seq))
        assert.is_nil(Seq.next(seq),'result 1 has not arrived')
        seq=Seq.outcome(seq,2)
        assert.is_nil(Seq.next(seq),'a later outcome cannot skip ahead of result 1')
    end)

    it('drains in declared order once the earlier outcome lands',function()
        local seq=Seq.outcome(Seq.new(3),3)
        seq=Seq.outcome(seq,2)
        local items;seq,items=drain(seq)
        assert.same({'call1'},items)
        seq=Seq.outcome(seq,1)
        seq,items=drain(seq)
        assert.same({'result1','call2','result2','call3','result3'},items)
        assert.is_true(Seq.complete(seq))
    end)

    it('is complete only when every call and every result is written',function()
        local seq=Seq.new(1)
        assert.is_false(Seq.complete(seq))
        seq=Seq.written(seq,Seq.next(seq))
        assert.is_false(Seq.complete(seq))
        seq=Seq.outcome(seq,1)
        seq=Seq.written(seq,Seq.next(seq))
        assert.is_true(Seq.complete(seq))
        assert.is_nil(Seq.next(seq))
    end)

    -- An outcome is final once its result is written: a later upgrade (an
    -- unknown effect confirmed after the fact) must not re-open a written slot.
    it('makes an outcome final once its result is written',function()
        local seq=Seq.outcome(Seq.new(2),1)
        assert.is_false(Seq.final(seq,1))
        seq=Seq.written(seq,Seq.next(seq))
        seq=Seq.written(seq,Seq.next(seq))
        assert.is_true(Seq.final(seq,1))
        assert.is_false(Seq.final(seq,2))
        local again=Seq.outcome(seq,1)
        assert.same(Seq.next(seq),Seq.next(again),'a repeated outcome changes nothing')
    end)

    -- #266 M3: Stop walks the round and cancels the call it is blocked on.
    it('names the result the walk is blocked on, and only that',function()
        local seq=Seq.new(2)
        assert.is_nil(Seq.waiting(seq),'a call block is never waited on')
        seq=Seq.written(seq,Seq.next(seq))
        assert.equals(1,Seq.waiting(seq))
        seq=Seq.outcome(seq,1)
        assert.is_nil(Seq.waiting(seq),'arrived: writable, not waited on')
        seq=Seq.written(seq,Seq.next(seq));seq=Seq.written(seq,Seq.next(seq))
        assert.equals(2,Seq.waiting(seq))
        seq=Seq.written(Seq.outcome(seq,2),{kind='result',index=2})
        assert.is_nil(Seq.waiting(seq),'complete')
    end)

    it('refuses to record an item that is not the next one',function()
        local seq=Seq.outcome(Seq.new(2),1)
        assert.has_error(function() Seq.written(seq,{kind='result',index=1}) end)
        assert.has_error(function() Seq.written(seq,{kind='call',index=2}) end)
    end)

    it('never mutates the record it is given',function()
        local seq=Seq.new(2)
        local before=vim.deepcopy(seq)
        Seq.outcome(seq,1);Seq.written(seq,Seq.next(seq))
        assert.same(before,seq)
    end)

    it('validates its bounds',function()
        for _,count in ipairs({0,33,1.5,'2'}) do
            assert.has_error(function() Seq.new(count) end,'invalid tool round size')
        end
        assert.has_error(function() Seq.outcome(Seq.new(2),3) end,'invalid tool index')
    end)
end)
