-- Metadata-only AVL rope. Coordinates are zero-based, half-open row ranges.
-- Bytes are caller-supplied additive sizes (including separators if desired).
-- An opaque span stores aggregate sizes, never one allocation per unread row.
local M = {}
local LEAF_SIZE = 128
local next_sequence = 0
local states = setmetatable({}, { __mode = "k" })

local function state(seq) return assert(states[seq], "invalid sequence") end
local function count(s, key, n) s.work[key] = (s.work[key] or 0) + (n or 1) end
local function copy(s, value, summary, remaining)
    remaining = remaining or { n = summary and 256 or 4096 }
    remaining.n = remaining.n - 1
    assert(remaining.n >= 0, "metadata/summary exceeds bounded schema")
    count(s, summary and "summary_values_copied" or "metadata_values_copied")
    if type(value) ~= "table" then
        assert(type(value) ~= "function" and type(value) ~= "userdata" and type(value) ~= "thread", "metadata must be values")
        return value
    end
    local out = {}
    for k, v in pairs(value) do
        assert(type(k) == "string" or type(k) == "number", "metadata keys must be scalar")
        out[k] = copy(s, v, summary, remaining)
    end
    return out
end
local function combine(s, a, b)
    if not s.combine then return nil end
    return copy(s, s.combine(copy(s, a, true), copy(s, b, true)), true)
end
local function combine_projection(s, a, b)
    if not s.combine_projection then return nil end
    return copy(s, s.combine_projection(copy(s,a,true), copy(s,b,true)), true)
end
local function same(s,a,b,summary)
    count(s,summary and "summary_values_compared" or "metadata_values_compared")
    if type(a)~=type(b) then return false end
    if type(a)~="table" then return a==b end
    for k,v in pairs(a) do if not same(s,v,b[k],summary) then return false end end
    for k in pairs(b) do if a[k]==nil then return false end end
    return true
end
-- Fixed-channel aggregates certify only the lexical predicates a query used.
local function channel_set(s,values)
    local out={}
    assert(type(values)=="table","channels must be a list or set")
    local size=0
    for k,v in pairs(values) do
        count(s,"channel_values_visited")
        local name=type(k)=="number" and v or k
        local enabled=type(k)=="number" or v==true
        assert(type(name)=="string" and s.channel_names[name],"unregistered fact channel")
        if enabled and not out[name] then size=size+1; out[name]=true end
        assert(size<=64,"channel registry exceeds bound")
    end
    return out
end
local function membership(s,metadata,opaque)
    if opaque or not s.channels then return {} end
    return channel_set(s,s.channels(copy(s,metadata)))
end
local function channel_add(s,target,source)
    for name,value in pairs(source or {}) do
        count(s,"channel_values_visited"); count(s,"channel_values_copied",3)
        local old=target[name]
        target[name]={count=(old and old.count or 0)+value.count,
            max_stamp=math.max(old and old.max_stamp or 0,value.max_stamp)}
    end
end
local function entry_channels(s,set,stamp)
    local out={}
    for name in pairs(set or {}) do
        count(s,"channel_values_visited"); count(s,"channel_values_copied",3)
        out[name]={count=1,max_stamp=stamp}
    end
    return out
end
local function combine_channels(s,a,b)
    local out={}; channel_add(s,out,a); channel_add(s,out,b); return out
end
local function height(n) return n and n.height or 0 end
local function root(n) if n then n.parent = nil end; return n end

local function leaf(s, entries)
    if #entries == 0 then return nil end
    count(s, "nodes_created"); count(s, "leaves_created")
    local n = { entries = entries, height = 1, rows = 0, bytes = 0, max_stamp = 0, max_syntax_stamp = 0, max_projection_stamp = 0, projection = s.empty_projection, channels = {}, opaque_rows = 0, opaque_max_stamp = 0, summary = s.empty }
    for _, e in ipairs(entries) do
        count(s, "entries_copied")
        e.leaf, e.local_row, e.local_byte = n, n.rows, n.bytes
        n.rows, n.bytes = n.rows + e.rows, n.bytes + e.bytes
        n.max_stamp = math.max(n.max_stamp, e.stamp)
        n.max_syntax_stamp = math.max(n.max_syntax_stamp, e.syntax_stamp)
        n.max_projection_stamp = math.max(n.max_projection_stamp, e.projection_stamp)
        n.projection = combine_projection(s,n.projection,e.projection)
        n.opaque = n.opaque or e.opaque
        n.opaque_rows=n.opaque_rows+(e.opaque and e.rows or 0)
        n.opaque_max_stamp=math.max(n.opaque_max_stamp,e.opaque and e.syntax_stamp or 0)
        channel_add(s,n.channels,e.channels)
        n.summary = combine(s, n.summary, e.summary)
    end
    return n
end
local function branch(s, a, b, staged)
    if not a then return root(b) end
    if not b then return root(a) end
    count(s, "nodes_created")
    local n = { left = a, right = b, height = math.max(a.height,b.height)+1,
        rows = a.rows+b.rows, bytes = a.bytes+b.bytes, max_stamp = math.max(a.max_stamp,b.max_stamp),
        max_syntax_stamp = math.max(a.max_syntax_stamp,b.max_syntax_stamp),
        max_projection_stamp = math.max(a.max_projection_stamp,b.max_projection_stamp),
        projection = combine_projection(s,a.projection,b.projection),
        opaque = a.opaque or b.opaque,
        opaque_rows=a.opaque_rows+b.opaque_rows,opaque_max_stamp=math.max(a.opaque_max_stamp,b.opaque_max_stamp),
        channels=combine_channels(s,a.channels,b.channels), summary = combine(s,a.summary,b.summary) }
    if not staged then a.parent, b.parent = n, n end
    return n
end
local function balance(s, n)
    if height(n.left) > height(n.right) + 1 then
        local a = n.left
        if height(a.left) >= height(a.right) then
            return branch(s,a.left,branch(s,a.right,n.right))
        end
        return branch(s,branch(s,a.left,a.right.left),branch(s,a.right.right,n.right))
    elseif height(n.right) > height(n.left) + 1 then
        local b = n.right
        if height(b.right) >= height(b.left) then
            return branch(s,branch(s,n.left,b.left),b.right)
        end
        return branch(s,branch(s,n.left,b.left.left),branch(s,b.left.right,b.right))
    end
    return n
end
local function join(s,a,b)
    if not a then return root(b) end
    if not b then return root(a) end
    count(s,"nodes_visited")
    if height(a) > height(b)+1 then return balance(s,branch(s,a.left,join(s,a.right,b))) end
    if height(b) > height(a)+1 then return balance(s,branch(s,join(s,a,b.left),b.right)) end
    return branch(s,a,b)
end
local function entry(s, value, stamp)
    assert(type(value.rows)=="number" and value.rows >= 1 and value.rows < math.huge and value.rows % 1 == 0, "rows must be positive integer")
    assert(type(value.bytes)=="number" and value.bytes >= 0 and value.bytes < math.huge and value.bytes % 1 == 0, "bytes must be finite nonnegative integer")
    assert(value.opaque or value.rows == 1, "confirmed entries represent one row")
    s.next_handle=s.next_handle+1
    local e = { rows=value.rows, bytes=value.bytes, opaque=value.opaque == true,
        metadata=copy(s,value.metadata), stamp=stamp, syntax_stamp=stamp, projection_stamp=stamp, handle=s.prefix..s.next_handle }
    e.summary = s.summarize and not e.opaque and copy(s,s.summarize(copy(s,e.metadata)),true) or s.empty
    e.projection = s.projection_summary and not e.opaque
        and copy(s,s.projection_summary(copy(s,e.metadata)),true) or s.empty_projection
    e.channel_set=membership(s,e.metadata,e.opaque)
    e.channels=entry_channels(s,e.channel_set,stamp)
    s.handles[e.handle] = e
    return e
end
-- Keep recursive workers at module scope. A per-operation recursive closure
-- can become a LuaJIT trace constant and retain its captured detached tree.
local function assemble(s,leaves,first,last)
    if first > last then return nil end
    if first == last then return leaves[first] end
    local mid = math.floor((first+last)/2)
    return branch(s,assemble(s,leaves,first,mid),assemble(s,leaves,mid+1,last))
end
local function build(s, values, stamp)
    local leaves, pending = {}, {}
    for _, v in ipairs(values) do
        pending[#pending+1] = entry(s,v,stamp)
        if #pending == LEAF_SIZE then leaves[#leaves+1] = leaf(s,pending); pending={} end
    end
    if #pending > 0 then leaves[#leaves+1] = leaf(s,pending) end
    return assemble(s,leaves,1,#leaves)
end

function M.new(values, opts)
    opts = opts or {}
    assert((opts.summarize == nil) == (opts.combine == nil), "summarize and combine are paired")
    assert((opts.projection_summary==nil)==(opts.combine_projection==nil),"projection summary and combine are paired")
    next_sequence=next_sequence+1
    local prefix="sequence:"..next_sequence..":"
    local seq, s = {}, { work={}, handles=setmetatable({}, {__mode="v"}), stamp=1,prefix=prefix,next_handle=0,
        summarize=opts.summarize, combine=opts.combine, projection_summary=opts.projection_summary,
        combine_projection=opts.combine_projection, eof=prefix.."eof", certificates=setmetatable({}, {__mode="k"}),
        cursors=setmetatable({}, {__mode="k"}),bof=prefix.."bof",channels=opts.channels,channel_names={} }
    assert((opts.channels==nil)==(opts.channel_names==nil),"channel classifier and fixed registry are paired")
    local channel_count=0
    for k,v in pairs(opts.channel_names or {}) do
        local name=type(k)=="number" and v or k
        assert(type(name)=="string","channel names must be strings")
        if not s.channel_names[name] then s.channel_names[name]=true; channel_count=channel_count+1 end
        assert(channel_count<=64,"channel registry exceeds bound")
    end
    states[seq] = s
    s.empty = copy(s,opts.empty_summary,true)
    s.empty_projection = copy(s,opts.empty_projection,true)
    s.root = root(build(s,values or {},s.stamp))
    return seq
end
function M.size(seq)
    local n = state(seq).root
    return { rows=n and n.rows or 0, bytes=n and n.bytes or 0 }
end
function M.eof(seq) return state(seq).eof end
function M.bof(seq) return state(seq).bof end
function M.stats(seq, reset)
    local s, out = state(seq), {}
    for _, key in ipairs({"nodes_visited","entries_visited","entries_copied","nodes_created","leaves_created",
        "detached_subtrees","query_results","summary_values_copied","metadata_values_copied",
        "summary_values_compared","metadata_values_compared","channel_values_visited","channel_values_copied"}) do
        out[key] = s.work[key] or 0
    end
    if reset then s.work = {} end
    return out
end
-- Reserve one group per range certificate creation OR validation plus rank.
-- Compound callers can reserve two groups for resume and final publication.
function M.navigation_budget(seq,operations)
    operations=operations or 1
    assert(operations>=1 and operations<math.huge and operations%1==0,"invalid operation count")
    return {nodes=(12*height(state(seq).root)+16)*operations,entries=4*LEAF_SIZE*operations}
end
local function locate(s,row)
    local n, base_row, base_byte = s.root, 0, 0
    if not n or row < 0 or row >= n.rows then return nil end
    while not n.entries do
        count(s,"nodes_visited")
        if row < base_row+n.left.rows then n=n.left
        else base_row=base_row+n.left.rows; base_byte=base_byte+n.left.bytes; n=n.right end
    end
    count(s,"nodes_visited")
    local lo,hi=1,#n.entries
    while lo<=hi do
        count(s,"entries_visited")
        local mid=math.floor((lo+hi)/2)
        local e=n.entries[mid]
        if row<base_row+e.local_row then hi=mid-1
        elseif row>=base_row+e.local_row+e.rows then lo=mid+1
        else return e,base_row+e.local_row,base_byte+e.local_byte end
    end
end
local function snapshot(s,e,row,byte,first,last)
    first, last = first or row, last or row+e.rows
    count(s,"query_results")
    return { handle=e.handle, rows=last-first, bytes=(first==row and last==row+e.rows) and e.bytes or nil,
        start_row=first,end_row=last,start_byte=first==row and byte or nil,
        end_byte=last==row+e.rows and byte+e.bytes or nil,opaque=e.opaque,metadata=copy(s,e.metadata) }
end
function M.at(seq,row)
    local s=state(seq)
    local e,r,b=locate(s,row)
    if e then return snapshot(s,e,r,b),row-r end
end
-- Byte offsets are exact even inside an opaque span; its interior row is not.
function M.at_byte(seq,byte,budget)
    assert(type(byte)=="number" and byte>=0 and byte<math.huge and byte%1==0,"invalid byte offset")
    local nodes,entries=math.huge,math.huge
    if budget then
        for _,value in pairs(budget) do
            assert(type(value)=="number" and value>=0 and value<math.huge and value%1==0,"invalid byte budget")
        end
        nodes,entries=budget.nodes or math.huge,budget.entries or math.huge
    end
    local s=state(seq);local n,r,b=s.root,0,0
    if not n or byte>=n.bytes then return nil end
    while n do
        if nodes<1 then return nil,"budget" end
        nodes=nodes-1;count(s,"nodes_visited")
        if n.entries then
            local lo,hi=1,#n.entries
            while lo<=hi do
                if entries<1 then return nil,"budget" end
                entries=entries-1;count(s,"entries_visited")
                local mid=math.floor((lo+hi)/2);local e=n.entries[mid]
                if byte<b+e.local_byte then hi=mid-1
                elseif byte>=b+e.local_byte+e.bytes then lo=mid+1
                else return snapshot(s,e,r+e.local_row,b+e.local_byte),byte-b-e.local_byte end
            end
            return nil
        end
        if byte<b+n.left.bytes then n=n.left
        else r,b=r+n.left.rows,b+n.left.bytes;n=n.right end
    end
end

function M.rank(seq,handle,budget)
    local nodes,entries=math.huge,math.huge
    if budget then
        nodes,entries=budget.nodes or math.huge,budget.entries or math.huge
        for _,value in pairs(budget) do
            assert(type(value)=="number" and value>=0 and value<math.huge and value%1==0,"invalid rank budget")
        end
    end
    local s=state(seq)
    if handle==s.bof then return {row=0,byte=0,rows=0,bytes=0} end
    if handle==s.eof then local z=M.size(seq); return {row=z.rows,byte=z.bytes,rows=0,bytes=0} end
    local e=s.handles[handle]
    if not e then return nil end
    local n,row,byte=e.leaf,e.local_row,e.local_byte
    if entries<1 then return nil,"budget" end
    count(s,"entries_visited")
    while n.parent do
        if nodes<1 then return nil,"budget" end
        nodes=nodes-1
        count(s,"nodes_visited")
        local p=n.parent
        if p.right==n then row,byte=row+p.left.rows,byte+p.left.bytes end
        n=p
    end
    if nodes<1 then return nil,"budget" end
    count(s,"nodes_visited")
    if n~=s.root then return nil end
    return {row=row,byte=byte,rows=e.rows,bytes=e.bytes}
end
local function check_range(s,first,last)
    assert(type(first)=="number" and type(last)=="number" and first%1==0 and last%1==0
        and first>=0 and last>=first and last<=(s.root and s.root.rows or 0), "invalid row range")
end
local function query_walk(ctx,n,r,b)
    local s,out,limit,first,last=ctx.s,ctx.out,ctx.limit,ctx.first,ctx.last
    if not n or #out>=limit or r>=last or r+n.rows<=first then return end
    count(s,"nodes_visited")
    if n.entries then
        for _,e in ipairs(n.entries) do
            count(s,"entries_visited")
            if r>=last or #out>=limit then break end
            if r+e.rows>first then out[#out+1]=snapshot(s,e,r,b,math.max(first,r),math.min(last,r+e.rows)) end
            r,b=r+e.rows,b+e.bytes
        end
    else query_walk(ctx,n.left,r,b); query_walk(ctx,n.right,r+n.left.rows,b+n.left.bytes) end
end
function M.query(seq,first,last,opts)
    local s,out=state(seq),{}
    check_range(s,first,last)
    local limit=opts and opts.limit or math.huge
    if first<last then query_walk({s=s,out=out,limit=limit,first=first,last=last},s.root,0,0) end
    return out
end
local function boundary_byte(s,row,hint)
    if row==(s.root and s.root.rows or 0) then
        local b=s.root and s.root.bytes or 0
        assert(hint==nil or hint==b,"incorrect byte boundary"); return b
    end
    local e,r,b=locate(s,row)
    if r==row then assert(hint==nil or hint==b,"incorrect byte boundary"); return b end
    assert(e.opaque and hint and hint>=b and hint<=b+e.bytes,"opaque cut requires exact byte boundary")
    return hint
end
local function split(s,n,row,byte)
    if not n then return nil,nil end
    count(s,"nodes_visited")
    if row==0 then return nil,root(n) end
    if row==n.rows then return root(n),nil end
    if n.entries then
        local left,right,r,b={},{},0,0
        for _,e in ipairs(n.entries) do
            count(s,"entries_visited")
            if r+e.rows<=row then left[#left+1]=e
            elseif r>=row then right[#right+1]=e
            else
                left[#left+1]=entry(s,{rows=row-r,bytes=byte-b,opaque=true},s.stamp)
                right[#right+1]=entry(s,{rows=e.rows-(row-r),bytes=e.bytes-(byte-b),opaque=true},s.stamp)
            end
            r,b=r+e.rows,b+e.bytes
        end
        return leaf(s,left),leaf(s,right)
    end
    if row<n.left.rows then
        local a,b=split(s,n.left,row,byte)
        return root(a),root(join(s,b,n.right))
    elseif row==n.left.rows then return root(n.left),root(n.right)
    else
        local a,b=split(s,n.right,row-n.left.rows,byte-n.left.bytes)
        return root(join(s,n.left,a)),root(b)
    end
end
function M.splice(seq,first,last,values,opts)
    local s=state(seq)
    check_range(s,first,last)
    opts=opts or {}
    local start_byte=boundary_byte(s,first,opts.start_byte)
    local end_byte=boundary_byte(s,last,opts.end_byte)
    assert(end_byte>=start_byte,"byte endpoints reversed")
    s.stamp=s.stamp+1
    local inserted=build(s,values or {},s.stamp)
    local prefix,suffix=split(s,s.root,last,end_byte)
    local before,removed=split(s,prefix,first,start_byte)
    if removed then removed.parent=nil; count(s,"detached_subtrees") end
    s.root=root(join(s,join(s,before,inserted),suffix))
end
-- Prepare every value and affected path before publishing any of the batch.
-- Staged nodes do not change live parent links, even if a summary callback fails.
local function same_syntax_token(s,a,b)
    if type(a)~="table" or type(b)~="table" then return false end
    local transient={bytes=true,row=true,provenance=true,diagnostic_utc_candidate=true,diagnostic_reference_candidate=true}
    for k,v in pairs(a) do
        if not transient[k] and not same(s,v,b[k],false) then return false end
    end
    for k in pairs(b) do if not transient[k] and a[k]==nil then return false end end
    return true
end
local function same_projection_metadata(s,a,b)
    if type(a)~="table" or type(b)~="table" then return false end
    for key,value in pairs(a) do
        if key~="token" and not same(s,value,b[key],false) then return false end
    end
    for key in pairs(b) do if key~="token" and a[key]==nil then return false end end
    return true
end
local function update_rebuild(ctx,n)
    local s,affected,prepared,staged,stamp,projection=ctx.s,ctx.affected,ctx.prepared,ctx.staged,ctx.stamp,ctx.projection
    if not affected[n] then return n end
    count(s,"nodes_visited")
    local out
    if n.entries then
        local entries={}
        for i,e in ipairs(n.entries) do
            local replacement=prepared[e.handle]
            entries[i]={rows=e.rows,bytes=e.bytes,opaque=e.opaque,handle=e.handle,
                metadata=e.metadata,summary=e.summary,projection=e.projection,
                projection_stamp=replacement and not replacement.same_projection and stamp or e.projection_stamp,channel_set=e.channel_set,channels=e.channels,
                stamp=replacement and not projection and stamp or e.stamp,
                syntax_stamp=replacement and not projection and not replacement.same_syntax and stamp or e.syntax_stamp}
            if replacement then
                entries[i].metadata,entries[i].summary=replacement.metadata,replacement.summary
                entries[i].projection=replacement.projection
                entries[i].bytes=replacement.bytes
                entries[i].channel_set=replacement.channel_set
                entries[i].channels=entry_channels(s,replacement.channel_set,entries[i].syntax_stamp)
            end
        end
        out=leaf(s,entries)
    else out=branch(s,update_rebuild(ctx,n.left),update_rebuild(ctx,n.right),true) end
    staged[out]=true
    return out
end
local function update_install(ctx,n,parent)
    local s,staged=ctx.s,ctx.staged
    n.parent=parent
    if not staged[n] then return end
    count(s,"nodes_visited")
    if n.entries then
        for _,e in ipairs(n.entries) do count(s,"entries_visited"); s.handles[e.handle]=e end
    else update_install(ctx,n.left,n); update_install(ctx,n.right,n) end
end
local function update_many(seq,updates,projection,text_update)
    local s=state(seq)
    assert(type(updates)=="table" and #updates<=256,"metadata batch exceeds 256 entries")
    local prepared,affected,staged={},{},{}
    for _,update in ipairs(updates) do
        local handle=update.handle
        if not M.rank(seq,handle) or handle==s.eof or handle==s.bof then return false,"detached or foreign handle" end
        if prepared[handle] then return false,"duplicate handle" end
        local value=copy(s,update.metadata)
        local e=s.handles[handle]
        if text_update then
            if e.opaque or e.rows~=1 then return false,"text update requires a confirmed row" end
            assert(type(update.bytes)=="number" and update.bytes>=0 and update.bytes<math.huge
                and update.bytes%1==0,"bytes must be finite nonnegative integer")
            assert(type(value)=="table" and type(value.token)=="table"
                and type(value.token.kind)=="string","text update requires a lexical token")
        end
        prepared[handle]={metadata=value,summary=s.summarize and not e.opaque
            and copy(s,s.summarize(copy(s,value)),true) or s.empty,bytes=text_update and update.bytes or e.bytes}
        prepared[handle].projection=s.projection_summary and not e.opaque
            and copy(s,s.projection_summary(copy(s,value)),true) or s.empty_projection
        prepared[handle].channel_set=membership(s,value,e.opaque)
        if text_update then
            prepared[handle].same_syntax=e.metadata and same_syntax_token(s,e.metadata.token,value.token)
                and same(s,e.summary,prepared[handle].summary,true)
                and same(s,e.channel_set,prepared[handle].channel_set,true) or false
            prepared[handle].same_projection=prepared[handle].same_syntax
                and same_projection_metadata(s,e.metadata,value)
                and same(s,e.projection,prepared[handle].projection,true)
        end
        if projection and (not e.metadata or not value or not e.metadata.token or not value.token
            or not same(s,e.metadata.token,value.token,false)
            or not same(s,e.summary,prepared[handle].summary,true)
            or not same(s,e.channel_set,prepared[handle].channel_set,true)) then
            return false,"projection changes lexical token or indexed summary"
        end
        local n=e.leaf
        while n and not affected[n] do
            count(s,"nodes_visited"); affected[n]=true; n=n.parent
        end
    end
    if #updates==0 then return true end
    local stamp=s.stamp+1
    local context={s=s,affected=affected,prepared=prepared,staged=staged,stamp=stamp,projection=projection}
    local replacement=update_rebuild(context,s.root)
    update_install(context,replacement,nil)
    s.root,s.stamp=replacement,stamp
    if text_update then return true,{same_syntax_proven=prepared[updates[1].handle].same_syntax} end
    return true
end
function M.update_many(seq,updates) return update_many(seq,updates,false) end
-- Only derived metadata may change. Exact lexical token and caller summary
-- equality are checked before retaining the existing text/fact revision.
function M.project_many(seq,updates) return update_many(seq,updates,true) end
function M.update(seq,handle,metadata)
    return M.update_many(seq,{{handle=handle,metadata=metadata}})
end

-- Text updates keep row provenance while independently revoking text proofs.
-- Syntax proofs survive only exact lexical-descriptor AND summary equality.
function M.update_text(seq,handle,value)
    assert(type(value)=="table","text update requires bytes and metadata")
    return update_many(seq,{{handle=handle,bytes=value.bytes,metadata=value.metadata}},false,true)
end

-- Aggregate a range without enumerating covered entries. Partial opaque bytes
-- are unknowable and therefore cannot certify a range until materialized.
local function aggregate_add(ctx,value)
    local s,result,include_summary=ctx.s,ctx.result,ctx.include_summary
    result.rows=result.rows+value.rows; result.bytes=result.bytes+value.bytes
    result.max_stamp=math.max(result.max_stamp,value.max_stamp or value.stamp)
    result.max_syntax_stamp=math.max(result.max_syntax_stamp,value.max_syntax_stamp or value.syntax_stamp)
    result.max_projection_stamp=math.max(result.max_projection_stamp,value.max_projection_stamp or value.projection_stamp)
    if include_summary then
        result.summary=combine(s,result.summary,value.summary)
        result.opaque=result.opaque or value.opaque==true
    end
end
local function aggregate_walk(ctx,n,r)
    local s,first,last=ctx.s,ctx.first,ctx.last
    if not n or r>=last or r+n.rows<=first then return true end
    count(s,"nodes_visited")
    if first<=r and r+n.rows<=last then
        aggregate_add(ctx,n); return true
    end
    if n.entries then
        for _,e in ipairs(n.entries) do
            count(s,"entries_visited")
            if r<last and r+e.rows>first then
                if r<first or r+e.rows>last then return false end
                aggregate_add(ctx,e)
            end
            r=r+e.rows
        end
        return true
    end
    return aggregate_walk(ctx,n.left,r) and aggregate_walk(ctx,n.right,r+n.left.rows)
end
local function aggregate(s,first,last,include_summary)
    local result={rows=0,bytes=0,max_stamp=0,max_syntax_stamp=0,max_projection_stamp=0}
    if include_summary then result.summary=s.empty; result.opaque=false end
    if not aggregate_walk({s=s,result=result,include_summary=include_summary,first=first,last=last},s.root,0) then return nil end
    return result
end
function M.summary(seq,first,last)
    local s=state(seq)
    check_range(s,first,last)
    local result=aggregate(s,first,last,true)
    if not result then return nil,"partial opaque range" end
    result.summary=copy(s,result.summary,true)
    return result
end
function M.range_certificate(seq,first,last,opts)
    local kind=opts and opts.kind or "text"
    assert(kind=="text" or kind=="region_text" or kind=="syntax" or kind=="projection","unknown certificate kind")
    local s=state(seq)
    check_range(s,first,last)
    local totals=aggregate(s,first,last)
    if not totals then return nil,"partial opaque range" end
    local size=M.size(seq).rows
    local a,ar=locate(s,first)
    local z,zr=locate(s,last-1)
    local before=first>0 and locate(s,first-1) or nil
    local after=last<size and locate(s,last) or nil
    local c={kind=kind,totals=totals,first=a and a.handle or s.eof,first_offset=a and first-ar or 0,
        last=z and z.handle or s.eof,last_offset=z and last-zr or 0,
        before=before and before.handle,after=after and after.handle,empty=first==last}
    local token={}; s.certificates[token]=c
    return token
end
-- Selected channel totals over dynamic row bounds; opaque portions never
-- supply a negative fact merely because their lexical metadata is absent.
local function channel_include(ctx,value,opaque_rows,opaque_stamp)
    local s,out,selected=ctx.s,ctx.out,ctx.selected
    for name in pairs(selected) do
        count(s,"channel_values_visited")
        local v=value[name]
        if v then
            local dest=out.channels[name]
            dest.count=dest.count+v.count; dest.max_stamp=math.max(dest.max_stamp,v.max_stamp)
            count(s,"channel_values_copied",2)
        end
    end
    out.opaque_rows=out.opaque_rows+opaque_rows
    out.opaque_max_stamp=math.max(out.opaque_max_stamp,opaque_stamp)
end
local function channel_walk(ctx,n,row)
    local s,first,last=ctx.s,ctx.first,ctx.last
    if not n or row>=last or row+n.rows<=first then return end
    count(s,"nodes_visited")
    if first<=row and row+n.rows<=last then
        channel_include(ctx,n.channels,n.opaque_rows,n.opaque_max_stamp)
    elseif n.entries then
        for _,e in ipairs(n.entries) do
            count(s,"entries_visited")
            if row>=last then break end
            if row+e.rows>first then
                channel_include(ctx,e.channels,e.opaque and math.min(last,row+e.rows)-math.max(first,row) or 0,
                    e.opaque and e.syntax_stamp or 0)
            end
            row=row+e.rows
        end
    else channel_walk(ctx,n.left,row); channel_walk(ctx,n.right,row+n.left.rows) end
end
local function channel_aggregate(s,first,last,selected)
    local out={channels={},opaque_rows=0,opaque_max_stamp=0}
    for name in pairs(selected) do out.channels[name]={count=0,max_stamp=0} end
    channel_walk({s=s,out=out,selected=selected,first=first,last=last},s.root,0)
    return out
end
function M.channel_summary(seq,first,last,channels)
    local s=state(seq); check_range(s,first,last)
    return channel_aggregate(s,first,last,channel_set(s,channels))
end
local function fact_bounds(seq,c)
    local a,z=M.rank(seq,c.first),M.rank(seq,c.last)
    if not a or not z then return nil,"detached fact endpoint" end
    local last=z.row+(c.end_inclusive and z.rows or 0)
    if a.row>last then return nil,"reversed fact endpoints" end
    return {first_row=a.row,last_row=last}
end
function M.fact_certificate(seq,opts)
    local s=state(seq)
    assert(type(opts)=="table" and opts.first and opts.last,"fact requires stable endpoint handles")
    local c={kind="fact",first=opts.first,last=opts.last,end_inclusive=opts.end_inclusive==true,
        channels=channel_set(s,opts.channels),allow_opaque=opts.allow_opaque==true}
    local bounds,err=fact_bounds(seq,c); if not bounds then return nil,err end
    c.totals=channel_aggregate(s,bounds.first_row,bounds.last_row,c.channels)
    if c.totals.opaque_rows>0 and not c.allow_opaque then return nil,"opaque fact range" end
    local token={}; s.certificates[token]=c; return token
end
local function validate_fact(seq,c)
    local s=state(seq)
    local bounds,err=fact_bounds(seq,c); if not bounds then return false,err end
    local totals=channel_aggregate(s,bounds.first_row,bounds.last_row,c.channels)
    if not same(s,c.totals,totals,true) then return false,"changed fact channel" end
    if totals.opaque_rows>0 and not c.allow_opaque then return false,"opaque fact range" end
    bounds.opaque_rows=totals.opaque_rows
    return true,bounds
end
function M.validate_certificate(seq,token,opts)
    local kind=opts and opts.kind or "text"
    assert(kind=="text" or kind=="region_text" or kind=="syntax" or kind=="fact" or kind=="projection","unknown certificate kind")
    local s=state(seq)
    local c=s.certificates[token]
    if not c then return false,"foreign certificate" end
    if c.kind~=kind then return false,"certificate kind does not authorize this read" end
    if kind=="fact" then return validate_fact(seq,c) end
    local a,z=M.rank(seq,c.first),M.rank(seq,c.last)
    if not a or not z then return false,"detached endpoint" end
    local first,last=a.row+c.first_offset,z.row+c.last_offset
    if c.empty then last=first end
    local before=first>0 and locate(s,first-1) or nil
    local after=last<M.size(seq).rows and locate(s,last) or nil
    -- Region consumers separately recompute semantic bounds. Outside neighbors
    -- are not source bytes; all existing certificate kinds keep edge checks.
    if kind~="region_text" and ((before and before.handle)~=c.before or (after and after.handle)~=c.after) then
        return false,"changed edge"
    end
    local totals=aggregate(s,first,last)
    if not totals or totals.rows~=c.totals.rows then return false,"changed range" end
    if kind=="projection" then
        if totals.max_projection_stamp~=c.totals.max_projection_stamp then return false,"changed projection" end
    elseif kind=="syntax" then
        if totals.max_syntax_stamp~=c.totals.max_syntax_stamp then return false,"changed syntax" end
    elseif totals.bytes~=c.totals.bytes or totals.max_stamp~=c.totals.max_stamp then
        return false,"changed range"
    end
    return true,{first_row=first,last_row=last,bytes=totals.bytes}
end

-- Generic summaries are conservative pruning hints. A false-positive summary
-- costs budget; an opaque entry always interrupts a first-match proof.
local function find_walk(ctx,n,r,b)
    local s,first,last,reverse,opts,work=ctx.s,ctx.first,ctx.last,ctx.reverse,ctx.opts,ctx.work
    local node_limit,reserve_nodes,entry_limit,reserve_entries=ctx.node_limit,ctx.reserve_nodes,ctx.entry_limit,ctx.reserve_entries
    if not n or r>=last or r+n.rows<=first or ctx.result then return end
    if work.nodes_visited>=node_limit-reserve_nodes then ctx.resume=reverse and math.min(last,r+n.rows) or math.max(first,r); ctx.result={status="budget"}; return end
    work.nodes_visited=work.nodes_visited+1; count(s,"nodes_visited")
    if not n.opaque and opts.may_match and not opts.may_match(copy(s,opts.projection and n.projection or n.summary,true)) then return end
    if n.entries then
        local index=reverse and #n.entries or 1
        while index>=1 and index<=#n.entries do
            local e=n.entries[index]
            local er,eb=r+e.local_row,b+e.local_byte
            if work.entries_visited>=entry_limit-reserve_entries then
                ctx.resume=reverse and math.min(last,er+e.rows) or math.max(first,er)
                ctx.result={status="budget"}; return
            end
            work.entries_visited=work.entries_visited+1; count(s,"entries_visited")
            if er<last and er+e.rows>first then
                if e.opaque or not opts.matches or opts.matches(copy(s,e.metadata)) then
                    ctx.result={status=e.opaque and "opaque" or "found",span=snapshot(s,e,er,eb,math.max(first,er),math.min(last,er+e.rows))}; return
                end
            end
            index=index+(reverse and -1 or 1)
        end
    elseif reverse then find_walk(ctx,n.right,r+n.left.rows,b+n.left.bytes); find_walk(ctx,n.left,r,b)
    else find_walk(ctx,n.left,r,b); find_walk(ctx,n.right,r+n.left.rows,b+n.left.bytes) end
end
local function find_finish(seq,initial,work,result)
    local total=M.stats(seq)
    for key in pairs(work) do work[key]=(total[key] or 0)-(initial[key] or 0) end
    result.work=work
    return result
end
function M.find(seq,first,last,opts)
    local s=state(seq)
    opts=opts or {}
    local work={nodes_visited=0,entries_visited=0,summary_values_copied=0,metadata_values_copied=0,
        channel_values_visited=0,channel_values_copied=0}
    local initial=M.stats(seq)
    local node_limit,entry_limit=opts.max_nodes or 512,opts.max_entries or 1024
    assert(node_limit>0 and entry_limit>0 and node_limit<math.huge and entry_limit<math.huge,
        "find budgets must be finite positive")
    -- Certificate construction/validation and cursor positioning touch at most
    -- two leaf scans, six binary leaf seeks and ten ancestor paths. Reserve
    -- that work BEFORE traversal; insufficient budgets do zero navigation.
    local reserve=M.navigation_budget(seq)
    local reserve_nodes,reserve_entries=reserve.nodes,reserve.entries
    if node_limit<=reserve_nodes or entry_limit<=reserve_entries then
        return {status="budget",cursor=opts.cursor,required={max_nodes=reserve_nodes+1,max_entries=reserve_entries+1},work=work}
    end
    local certificate_kind=opts.certificate_kind or (opts.projection and "projection" or "text")
    assert(not opts.projection or certificate_kind=="projection","projection search requires projection proof")
    assert(not opts.projection or s.projection_summary,"projection summary is not configured")
    assert(certificate_kind=="text" or certificate_kind=="syntax" or certificate_kind=="fact" or certificate_kind=="projection","unknown find certificate kind")
    local reverse=opts.reverse==true
    local range_first,range_last=first,last
    local cert
    if opts.cursor then
        local cursor=s.cursors[opts.cursor]
        if not cursor then return find_finish(seq,initial,work,{status="stale"}) end
        local valid,range=M.validate_certificate(seq,cursor.certificate,{kind=certificate_kind})
        if not valid then return find_finish(seq,initial,work,{status="stale"}) end
        range_first,range_last=range.first_row+cursor.first_offset,range.last_row-cursor.last_offset
        local next_pos=M.rank(seq,cursor.next)
        if not next_pos and certificate_kind~="fact" then return find_finish(seq,initial,work,{status="stale"}) end
        first,last=range_first,range_last
        reverse=cursor.reverse
        if next_pos then
            if reverse then last=next_pos.row+cursor.offset else first=next_pos.row+cursor.offset end
        end
        cert=cursor.certificate
    end
    check_range(s,first,last)
    local context={s=s,first=first,last=last,reverse=reverse,opts=opts,work=work,
        node_limit=node_limit,reserve_nodes=reserve_nodes,entry_limit=entry_limit,reserve_entries=reserve_entries}
    find_walk(context,s.root,0,0)
    local result,resume=context.result or {status="not_found"},context.resume
    if result.status=="budget" then
        local first_offset,last_offset=0,0
        if opts.cursor then
            local old=s.cursors[opts.cursor]
            first_offset,last_offset=old.first_offset,old.last_offset
        elseif not cert then
            -- Cover opaque endpoint entries, while retaining the narrower
            -- query offsets. No unknown interior byte coordinate is invented.
            local a,ar=locate(s,range_first)
            local z,zr=locate(s,range_last-1)
            local cover_first=a and ar or range_first
            local cover_last=z and zr+z.rows or range_last
            first_offset,last_offset=range_first-cover_first,cover_last-range_last
            if certificate_kind=="fact" then
                assert(type(opts.fact)=="table","fact search requires stable bounds and channels")
                local spec={first=opts.fact.first,last=opts.fact.last,end_inclusive=opts.fact.end_inclusive,
                    channels=opts.fact.channels,allow_opaque=true}
                cert=M.fact_certificate(seq,spec)
                if cert then
                    local bounds=assert(fact_bounds(seq,spec))
                    assert(range_first>=bounds.first_row and range_last<=bounds.last_row,"search exceeds fact scope")
                    first_offset,last_offset=range_first-bounds.first_row,bounds.last_row-range_last
                end
            else cert=M.range_certificate(seq,cover_first,cover_last,{kind=certificate_kind}) end
        end
        local e,r=locate(s,reverse and resume-1 or resume)
        if cert and e then
            local token={}
            s.cursors[token]={certificate=cert,next=e.handle,offset=resume-r,reverse=reverse,
                first_offset=first_offset,last_offset=last_offset}
            result.cursor=token
        end
    end
    return find_finish(seq,initial,work,result)
end

return M
