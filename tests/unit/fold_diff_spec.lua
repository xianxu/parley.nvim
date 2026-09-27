local diff=require('parley.fold_diff').diff

local function E(a,b,nested) return {start_0=a,end_0=b,nested=nested} end
local function W(a,b) return {start_0=a,end_0=b,identity=a..'-'..b} end
local function key(f) return f.start_0..':'..f.end_0 end
local function overlaps(a,b) return a.start_0<=b.end_0 and b.start_0<=a.end_0 end

-- Simulates applying every batch to the existing folds.
local function apply(existing,batches)
    local set={}
    for _,f in ipairs(existing) do set[key(f)]=true end
    for _,batch in ipairs(batches) do
        for _,f in ipairs(batch.remove) do assert.is_true(set[key(f)],'removing absent '..key(f));set[key(f)]=nil end
        for _,f in ipairs(batch.create) do set[key(f)]=true end
    end
    return set
end

-- Seeded disjoint interval sets inside [0,60), optionally shifted copies of each other.
local function intervals(rng,count)
    local out,row={},rng(0,3)
    for _=1,count do
        local len=rng(0,4)
        if row+len>=60 then break end
        out[#out+1]={row,row+len};row=row+len+rng(1,4)
    end
    return out
end

describe('fold_diff',function()
    it('leaves identical sets untouched',function()
        assert.same({},diff({E(2,4),E(8,9)},{W(2,4),W(8,9)},64))
    end)
    it('reshapes a grown fold in one batch',function()
        local batches=diff({E(5,9)},{W(5,12)},64)
        assert.equals(1,#batches)
        assert.same({E(5,9)},batches[1].remove);assert.same({W(5,12)},batches[1].create)
    end)
    it('emits remove-only and create-only batches',function()
        assert.same({{remove={E(1,2)},create={}}},diff({E(1,2)},{},64))
        assert.same({{remove={},create={W(1,2)}}},diff({},{W(1,2)},64))
    end)
    it('keeps a changed fold with every desired fold it overlaps',function()
        local batches=diff({E(2,10)},{W(2,4),W(6,10)},64)
        assert.equals(1,#batches)
        assert.equals(1,#batches[1].remove);assert.equals(2,#batches[1].create)
    end)
    it('always recreates a nested group, even with a matching extent',function()
        local batches=diff({E(3,6,true)},{W(3,6)},64)
        assert.same({{remove={E(3,6,true)},create={W(3,6)}}},batches)
    end)
    it('packs independent changes by limit without splitting a region',function()
        local existing,desired={},{}
        for i=0,4 do existing[#existing+1]=E(i*10,i*10+2);desired[#desired+1]=W(i*10,i*10+3) end
        local batches=diff(existing,desired,4)
        assert.equals(3,#batches)
        assert.equals(4,#batches[1].remove+#batches[1].create)
        assert.equals(2,#batches[3].remove+#batches[3].create)
    end)
    it('never lists an unchanged fold between two changes',function()
        local batches=diff({E(0,1),E(5,6),E(10,11)},{W(0,2),W(5,6),W(10,12)},64)
        for _,batch in ipairs(batches) do
            for _,f in ipairs(batch.remove) do assert.are_not.equals('5:6',key(f)) end
            for _,f in ipairs(batch.create) do assert.are_not.equals('5:6',key(f)) end
        end
    end)
    it('property: batches turn existing into desired, touch no exact match, keep regions whole',function()
        for seed=1,200 do
            math.randomseed(seed)
            local rng=math.random
            local limit=rng(1,6)
            local existing,desired={},{}
            for _,iv in ipairs(intervals(rng,rng(0,12))) do existing[#existing+1]=E(iv[1],iv[2],rng()<0.1) end
            -- Desired shares some folds with existing, plus fresh ones.
            for _,f in ipairs(existing) do
                local roll=rng()
                if roll<0.5 then desired[#desired+1]=W(f.start_0,f.end_0)
                elseif roll<0.7 then desired[#desired+1]=W(f.start_0,f.end_0+rng(1,2)) end
            end
            table.sort(desired,function(a,b) return a.start_0<b.start_0 end)
            local disjoint={}
            for _,f in ipairs(desired) do
                if #disjoint==0 or f.start_0>disjoint[#disjoint].end_0 then disjoint[#disjoint+1]=f end
            end
            desired=disjoint
            local batches=diff(existing,desired,limit)
            local ctx='seed '..seed
            local got=apply(existing,batches)
            local want={};for _,f in ipairs(desired) do want[key(f)]=true end
            assert.same(want,got,ctx)
            local where={}
            for b,batch in ipairs(batches) do
                local n=#batch.remove+#batch.create
                for _,f in ipairs(batch.remove) do where[f]=b end
                for _,f in ipairs(batch.create) do where[f]=b end
                if n>limit then
                    -- Only a single connected region may exceed the limit.
                    local all=vim.list_extend(vim.deepcopy(batch.remove),batch.create)
                    table.sort(all,function(x,y) return x.start_0<y.start_0 end)
                    local reach=all[1].end_0
                    for i=2,#all do
                        assert.is_true(all[i].start_0<=reach,ctx..': oversize batch is not one region')
                        reach=math.max(reach,all[i].end_0)
                    end
                end
            end
            -- Exact, non-nested matches never appear in any batch.
            for _,f in ipairs(existing) do
                if not f.nested and want[key(f)] then assert.is_nil(where[f],ctx..': touched unchanged '..key(f)) end
            end
            -- Overlapping changed folds share a batch.
            local changed={}
            for f in pairs(where) do changed[#changed+1]=f end
            for i=1,#changed do for j=i+1,#changed do
                if overlaps(changed[i],changed[j]) then
                    assert.equals(where[changed[i]],where[changed[j]],ctx..': region split across batches')
                end
            end end
        end
    end)
end)
