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
local function same(s,a,b,summary)
    count(s,summary and "summary_values_compared" or "metadata_values_compared")
    if type(a)~=type(b) then return false end
    if type(a)~="table" then return a==b end
    for k,v in pairs(a) do if not same(s,v,b[k],summary) then return false end end
    for k in pairs(b) do if a[k]==nil then return false end end
    return true
end
local function height(n) return n and n.height or 0 end
local function root(n) if n then n.parent = nil end; return n end

local function leaf(s, entries)
    if #entries == 0 then return nil end
    count(s, "nodes_created"); count(s, "leaves_created")
    local n = { entries = entries, height = 1, rows = 0, bytes = 0, max_stamp = 0, max_syntax_stamp = 0, summary = s.empty }
    for _, e in ipairs(entries) do
        count(s, "entries_copied")
        e.leaf, e.local_row, e.local_byte = n, n.rows, n.bytes
        n.rows, n.bytes = n.rows + e.rows, n.bytes + e.bytes
        n.max_stamp = math.max(n.max_stamp, e.stamp)
        n.max_syntax_stamp = math.max(n.max_syntax_stamp, e.syntax_stamp)
        n.opaque = n.opaque or e.opaque
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
        opaque = a.opaque or b.opaque, summary = combine(s,a.summary,b.summary) }
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
        metadata=copy(s,value.metadata), stamp=stamp, syntax_stamp=stamp, handle=s.prefix..s.next_handle }
    e.summary = s.summarize and not e.opaque and copy(s,s.summarize(copy(s,e.metadata)),true) or s.empty
    s.handles[e.handle] = e
    return e
end
local function build(s, values, stamp)
    local leaves, pending = {}, {}
    for _, v in ipairs(values) do
        pending[#pending+1] = entry(s,v,stamp)
        if #pending == LEAF_SIZE then leaves[#leaves+1] = leaf(s,pending); pending={} end
    end
    if #pending > 0 then leaves[#leaves+1] = leaf(s,pending) end
    local function assemble(first,last)
        if first > last then return nil end
        if first == last then return leaves[first] end
        local mid = math.floor((first+last)/2)
        return branch(s,assemble(first,mid),assemble(mid+1,last))
    end
    return assemble(1,#leaves)
end

function M.new(values, opts)
    opts = opts or {}
    assert((opts.summarize == nil) == (opts.combine == nil), "summarize and combine are paired")
    next_sequence=next_sequence+1
    local prefix="sequence:"..next_sequence..":"
    local seq, s = {}, { work={}, handles=setmetatable({}, {__mode="v"}), stamp=1,prefix=prefix,next_handle=0,
        summarize=opts.summarize, combine=opts.combine, eof=prefix.."eof", certificates=setmetatable({}, {__mode="k"}),
        cursors=setmetatable({}, {__mode="k"}) }
    states[seq] = s
    s.empty = copy(s,opts.empty_summary,true)
    s.root = root(build(s,values or {},s.stamp))
    return seq
end
function M.size(seq)
    local n = state(seq).root
    return { rows=n and n.rows or 0, bytes=n and n.bytes or 0 }
end
function M.eof(seq) return state(seq).eof end
function M.stats(seq, reset)
    local s, out = state(seq), {}
    for _, key in ipairs({"nodes_visited","entries_visited","entries_copied","nodes_created","leaves_created",
        "detached_subtrees","query_results","summary_values_copied","metadata_values_copied",
        "summary_values_compared","metadata_values_compared"}) do
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
function M.rank(seq,handle)
    local s=state(seq)
    if handle==s.eof then local z=M.size(seq); return {row=z.rows,byte=z.bytes,rows=0,bytes=0} end
    local e=s.handles[handle]
    if not e then return nil end
    local n,row,byte=e.leaf,e.local_row,e.local_byte
    count(s,"entries_visited")
    while n.parent do
        count(s,"nodes_visited")
        local p=n.parent
        if p.right==n then row,byte=row+p.left.rows,byte+p.left.bytes end
        n=p
    end
    count(s,"nodes_visited")
    if n~=s.root then return nil end
    return {row=row,byte=byte,rows=e.rows,bytes=e.bytes}
end
local function check_range(s,first,last)
    assert(type(first)=="number" and type(last)=="number" and first%1==0 and last%1==0
        and first>=0 and last>=first and last<=(s.root and s.root.rows or 0), "invalid row range")
end
function M.query(seq,first,last,opts)
    local s,out=state(seq),{}
    check_range(s,first,last)
    local limit=opts and opts.limit or math.huge
    local function walk(n,r,b)
        if not n or #out>=limit or r>=last or r+n.rows<=first then return end
        count(s,"nodes_visited")
        if n.entries then
            for _,e in ipairs(n.entries) do
                count(s,"entries_visited")
                if r>=last or #out>=limit then break end
                if r+e.rows>first then out[#out+1]=snapshot(s,e,r,b,math.max(first,r),math.min(last,r+e.rows)) end
                r,b=r+e.rows,b+e.bytes
            end
        else walk(n.left,r,b); walk(n.right,r+n.left.rows,b+n.left.bytes) end
    end
    if first<last then walk(s.root,0,0) end
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
    local transient={bytes=true,row=true,provenance=true}
    for k,v in pairs(a) do
        if not transient[k] and not same(s,v,b[k],false) then return false end
    end
    for k in pairs(b) do if not transient[k] and a[k]==nil then return false end end
    return true
end
local function update_many(seq,updates,projection,text_update)
    local s=state(seq)
    assert(type(updates)=="table" and #updates<=256,"metadata batch exceeds 256 entries")
    local prepared,affected,staged={},{},{}
    for _,update in ipairs(updates) do
        local handle=update.handle
        if not M.rank(seq,handle) or handle==s.eof then return false,"detached or foreign handle" end
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
        if text_update then
            prepared[handle].same_syntax=e.metadata and same_syntax_token(s,e.metadata.token,value.token)
                and same(s,e.summary,prepared[handle].summary,true) or false
        end
        if projection and (not e.metadata or not value or not e.metadata.token or not value.token
            or not same(s,e.metadata.token,value.token,false)
            or not same(s,e.summary,prepared[handle].summary,true)) then
            return false,"projection changes lexical token or indexed summary"
        end
        local n=e.leaf
        while n and not affected[n] do
            count(s,"nodes_visited"); affected[n]=true; n=n.parent
        end
    end
    if #updates==0 then return true end
    local stamp=s.stamp+(projection and 0 or 1)
    local function rebuild(n)
        if not affected[n] then return n end
        count(s,"nodes_visited")
        local out
        if n.entries then
            local entries={}
            for i,e in ipairs(n.entries) do
                local replacement=prepared[e.handle]
                entries[i]={rows=e.rows,bytes=e.bytes,opaque=e.opaque,handle=e.handle,
                    metadata=e.metadata,summary=e.summary,
                    stamp=replacement and not projection and stamp or e.stamp,
                    syntax_stamp=replacement and not projection and not replacement.same_syntax and stamp or e.syntax_stamp}
                if replacement then
                    entries[i].metadata,entries[i].summary=replacement.metadata,replacement.summary
                    entries[i].bytes=replacement.bytes
                end
            end
            out=leaf(s,entries)
        else out=branch(s,rebuild(n.left),rebuild(n.right),true) end
        staged[out]=true
        return out
    end
    local replacement=rebuild(s.root)
    local function install(n,parent)
        n.parent=parent
        if not staged[n] then return end
        count(s,"nodes_visited")
        if n.entries then
            for _,e in ipairs(n.entries) do count(s,"entries_visited"); s.handles[e.handle]=e end
        else install(n.left,n); install(n.right,n) end
    end
    install(replacement,nil)
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
local function aggregate(s,first,last,include_summary)
    local result={rows=0,bytes=0,max_stamp=0,max_syntax_stamp=0}
    if include_summary then result.summary=s.empty; result.opaque=false end
    local function add(value)
        result.rows=result.rows+value.rows; result.bytes=result.bytes+value.bytes
        result.max_stamp=math.max(result.max_stamp,value.max_stamp or value.stamp)
        result.max_syntax_stamp=math.max(result.max_syntax_stamp,value.max_syntax_stamp or value.syntax_stamp)
        if include_summary then
            result.summary=combine(s,result.summary,value.summary)
            result.opaque=result.opaque or value.opaque==true
        end
    end
    local function walk(n,r)
        if not n or r>=last or r+n.rows<=first then return true end
        count(s,"nodes_visited")
        if first<=r and r+n.rows<=last then
            add(n); return true
        end
        if n.entries then
            for _,e in ipairs(n.entries) do
                count(s,"entries_visited")
                if r<last and r+e.rows>first then
                    if r<first or r+e.rows>last then return false end
                    add(e)
                end
                r=r+e.rows
            end
            return true
        end
        return walk(n.left,r) and walk(n.right,r+n.left.rows)
    end
    if not walk(s.root,0) then return nil end
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
    assert(kind=="text" or kind=="syntax","unknown certificate kind")
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
function M.validate_certificate(seq,token,opts)
    local kind=opts and opts.kind or "text"
    assert(kind=="text" or kind=="syntax","unknown certificate kind")
    local s=state(seq)
    local c=s.certificates[token]
    if not c then return false,"foreign certificate" end
    if c.kind~=kind then return false,"certificate kind does not authorize this read" end
    local a,z=M.rank(seq,c.first),M.rank(seq,c.last)
    if not a or not z then return false,"detached endpoint" end
    local first,last=a.row+c.first_offset,z.row+c.last_offset
    if c.empty then last=first end
    local before=first>0 and locate(s,first-1) or nil
    local after=last<M.size(seq).rows and locate(s,last) or nil
    if (before and before.handle)~=c.before or (after and after.handle)~=c.after then return false,"changed edge" end
    local totals=aggregate(s,first,last)
    if not totals or totals.rows~=c.totals.rows then return false,"changed range" end
    if kind=="syntax" then
        if totals.max_syntax_stamp~=c.totals.max_syntax_stamp then return false,"changed syntax" end
    elseif totals.bytes~=c.totals.bytes or totals.max_stamp~=c.totals.max_stamp then
        return false,"changed range"
    end
    return true,{first_row=first,last_row=last,bytes=totals.bytes}
end

-- Generic summaries are conservative pruning hints. A false-positive summary
-- costs budget; an opaque entry always interrupts a first-match proof.
function M.find(seq,first,last,opts)
    local s=state(seq)
    opts=opts or {}
    local work={nodes_visited=0,entries_visited=0,summary_values_copied=0,metadata_values_copied=0}
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
    local function finish(result)
        local total=M.stats(seq)
        for key in pairs(work) do work[key]=(total[key] or 0)-(initial[key] or 0) end
        result.work=work
        return result
    end
    local certificate_kind=opts.certificate_kind or "text"
    assert(certificate_kind=="text" or certificate_kind=="syntax","unknown find certificate kind")
    local reverse=opts.reverse==true
    local range_first,range_last=first,last
    local cert
    if opts.cursor then
        local cursor=s.cursors[opts.cursor]
        if not cursor then return finish({status="stale"}) end
        local valid,range=M.validate_certificate(seq,cursor.certificate,{kind=certificate_kind})
        if not valid then return finish({status="stale"}) end
        range_first,range_last=range.first_row+cursor.first_offset,range.last_row-cursor.last_offset
        local next_pos=M.rank(seq,cursor.next)
        if not next_pos then return finish({status="stale"}) end
        first,last=range_first,range_last
        reverse=cursor.reverse
        if reverse then last=next_pos.row+cursor.offset else first=next_pos.row+cursor.offset end
        cert=cursor.certificate
    end
    check_range(s,first,last)
    local result,resume
    local function walk(n,r,b)
        if not n or r>=last or r+n.rows<=first or result then return end
        if work.nodes_visited>=node_limit-reserve_nodes then resume=reverse and math.min(last,r+n.rows) or math.max(first,r); result={status="budget"}; return end
        work.nodes_visited=work.nodes_visited+1; count(s,"nodes_visited")
        if not n.opaque and opts.may_match and not opts.may_match(copy(s,n.summary,true)) then return end
        if n.entries then
            local index=reverse and #n.entries or 1
            while index>=1 and index<=#n.entries do
                local e=n.entries[index]
                local er,eb=r+e.local_row,b+e.local_byte
                if work.entries_visited>=entry_limit-reserve_entries then
                    resume=reverse and math.min(last,er+e.rows) or math.max(first,er)
                    result={status="budget"}; return
                end
                work.entries_visited=work.entries_visited+1; count(s,"entries_visited")
                if er<last and er+e.rows>first then
                    if e.opaque or not opts.matches or opts.matches(copy(s,e.metadata)) then
                        result={status=e.opaque and "opaque" or "found",span=snapshot(s,e,er,eb,math.max(first,er),math.min(last,er+e.rows))}; return
                    end
                end
                index=index+(reverse and -1 or 1)
            end
        elseif reverse then walk(n.right,r+n.left.rows,b+n.left.bytes); walk(n.left,r,b)
        else walk(n.left,r,b); walk(n.right,r+n.left.rows,b+n.left.bytes) end
    end
    walk(s.root,0,0)
    result=result or {status="not_found"}
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
            cert=M.range_certificate(seq,cover_first,cover_last,{kind=certificate_kind})
        end
        local e,r=locate(s,reverse and resume-1 or resume)
        if cert and e then
            local token={}
            s.cursors[token]={certificate=cert,next=e.handle,offset=resume-r,reverse=reverse,
                first_offset=first_offset,last_offset=last_offset}
            result.cursor=token
        end
    end
    return finish(result)
end

return M
