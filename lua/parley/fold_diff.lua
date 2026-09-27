-- Pure diff of the native folds a window has against the folds the confirmed
-- projection wants (#264). Exact matches are left out entirely, so an unchanged
-- fold is never touched. Every changed fold is grouped with everything it
-- overlaps, and a group is applied in one slice (removals, then creations), so
-- no region is ever left unfolded between event-loop turns.
local M={}

-- existing: {{start_0=,end_0=,nested=},...} top-level native folds (disjoint).
-- desired:  {{start_0=,end_0=,identity=},...} projection ranges (disjoint).
-- Returns batches {{remove={existing...},create={desired...}},...} in row order.
-- A batch holds at most `limit` folds unless it is one connected region: a
-- region can't be split without leaving part of it unfolded between slices.
function M.diff(existing,desired,limit)
    limit=limit or math.huge
    local wanted={}
    for _,range in ipairs(desired) do wanted[range.start_0..':'..range.end_0]=range end
    local kept={}
    local changed={}
    for _,fold in ipairs(existing) do
        local key=fold.start_0..':'..fold.end_0
        if not fold.nested and wanted[key] and not kept[key] then kept[key]=true
        else changed[#changed+1]={fold=fold,remove=true} end
    end
    for _,range in ipairs(desired) do
        if not kept[range.start_0..':'..range.end_0] then changed[#changed+1]={fold=range,remove=false} end
    end
    table.sort(changed,function(a,b)
        if a.fold.start_0~=b.fold.start_0 then return a.fold.start_0<b.fold.start_0 end
        return a.remove and not b.remove
    end)
    -- Connected regions: a sweep over start-sorted intervals joins any interval
    -- that begins at or before the running end of the current region.
    local regions,region,reach={},nil,nil
    for _,entry in ipairs(changed) do
        if not region or entry.fold.start_0>reach then
            region={remove={},create={}};regions[#regions+1]=region;reach=entry.fold.end_0
        else reach=math.max(reach,entry.fold.end_0) end
        local list=entry.remove and region.remove or region.create
        list[#list+1]=entry.fold
    end
    local batches,batch,size={},nil,0
    for _,r in ipairs(regions) do
        local n=#r.remove+#r.create
        if not batch or size+n>limit then
            batch={remove={},create={}};batches[#batches+1]=batch;size=0
        end
        vim.list_extend(batch.remove,r.remove);vim.list_extend(batch.create,r.create)
        size=size+n
    end
    return batches
end

return M
