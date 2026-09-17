-- Pure write-turn decision (#266 M1). One generation may mutate a document at a
-- time; eligibility order is admission order, which state.lua's monotone integer
-- id() already encodes, so ordinary `<` is the comparison.
local ok,W=pcall(require,'parley.document.write_turn')

describe('write turn',function()
    it('provides the module',function()assert.is_true(ok)end)
    if not ok then return end

    it('grants the turn to the lowest eligible generation id',function()
        assert.equals(2,W.holder({[5]={eligible=true},[2]={eligible=true}},nil))
    end)

    it('keeps an existing holder while it stays eligible',function()
        assert.equals(5,W.holder({[5]={eligible=true},[2]={eligible=true}},5))
    end)

    it('reassigns when the holder stops being eligible',function()
        assert.equals(2,W.holder({[5]={eligible=false},[2]={eligible=true}},5))
    end)

    it('reassigns when the holder is gone',function()
        assert.equals(2,W.holder({[2]={eligible=true}},5))
    end)

    it('returns nil when nothing is eligible',function()
        assert.is_nil(W.holder({[2]={eligible=false}},nil))
        assert.is_nil(W.holder({},5))
    end)

    -- Guards the defect three plan revisions carried: ids were assumed to be
    -- 'g'..serial, so a string compare would have put g10 before g9. state.lua:6-7
    -- returns a bare integer.
    it('orders numerically, not lexically',function()
        assert.equals(9,W.holder({[10]={eligible=true},[9]={eligible=true}},nil))
    end)

    it('does not mutate the table it is given',function()
        local generations={[5]={eligible=true},[2]={eligible=true}}
        W.holder(generations,5)
        assert.same({[5]={eligible=true},[2]={eligible=true}},generations)
    end)
end)
