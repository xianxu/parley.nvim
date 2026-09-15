local S=require('parley.document.sequence')
local REGION={kind='region_text'}
local function row(id)return {rows=1,bytes=5,metadata={id=id}}end
describe('internal text revision certificates',function()
    it('relocates unchanged source across replaced neighbors without weakening ordinary proofs',function()
        local seq=S.new({row(1),row(2),row(3)})
        local ordinary=S.range_certificate(seq,1,2);local region=S.range_certificate(seq,1,2,REGION)
        S.splice(seq,0,1,{row(4),row(5)})
        assert.is_false(S.validate_certificate(seq,ordinary))
        local valid,bounds=S.validate_certificate(seq,region,REGION)
        assert.is_true(valid);assert.equals(2,bounds.first_row)
        assert.is_false(S.validate_certificate(seq,ordinary,REGION))
        assert.is_false(S.validate_certificate(seq,region))
    end)
    it('rejects interior insertion, deletion and equal-byte replacement',function()
        for _,mode in ipairs({'insert','delete','replace'})do
            local seq=S.new({row(1),row(2),row(3)})
            local region=S.range_certificate(seq,0,3,REGION)
            S.splice(seq,1,mode=='insert' and 1 or 2,mode=='delete' and {} or {row(2)})
            assert.is_false(S.validate_certificate(seq,region,REGION))
        end
    end)
end)
