-- Bounded lexical materialization of a metadata-only sequence. Readers remain
-- outside: responses belong to the coordinates of their matching request.
local sequence=require('parley.document.sequence')
local grammar=require('parley.document.grammar')
local M={}
local workers=setmetatable({},{__mode='k'})
local next_id=0
local function state(worker) return assert(workers[worker],'invalid lexer worker') end
local function delta(index,before)
    local out={}
    for k,v in pairs(sequence.stats(index)) do out[k]=v-(before[k] or 0) end
    return out
end
local function add(a,b) for k,v in pairs(b or {}) do a[k]=(a[k] or 0)+v end end
local function integer(n) return type(n)=='number' and n>=0 and n<math.huge and n%1==0 end

function M.new(index,patterns)
    local worker={}
    workers[worker]={index=index,patterns=patterns,pending_work={}}
    return worker
end

-- Demanding the same live row retains its in-progress long-line lexer.
function M.demand(worker,row)
    local s=state(worker)
    assert(integer(row) and row<sequence.size(s.index).rows,'invalid requested row')
    local before=sequence.stats(s.index)
    local item,offset=sequence.at(s.index,row)
    if s.job and s.job.handle==item.handle and s.job.offset==offset then
        add(s.pending_work,delta(s.index,before)); return
    end
    s.job=nil
    if item.opaque or not (item.metadata and item.metadata.token) then
        local certificate=assert(sequence.range_certificate(s.index,item.start_row,item.end_row))
        s.job={handle=item.handle,offset=offset,rows=item.rows,bytes=item.bytes,
            certificate=certificate,cursor=grammar.lex_start(s.patterns),col=0,metadata=item.metadata,
            opaque=item.opaque}
    end
    add(s.pending_work,delta(s.index,before))
end

function M.retained_bytes(worker)
    local job=state(worker).job
    return job and grammar.lexer_retained_bytes(job.cursor) or 0
end

function M.step(worker,input,budget)
    local s=state(worker)
    local before=sequence.stats(s.index)
    local work={bytes_scanned=0,rows_materialized=0}
    add(work,s.pending_work); s.pending_work={}
    local function finish(result)
        add(work,delta(s.index,before)); result.work=work; return result
    end
    local function stale(reason)
        s.job=nil; return finish({status='stale',reason=reason})
    end
    local job=s.job
    if not job then return finish({status=input and 'stale' or 'idle'}) end
    budget=budget or {}
    local byte_limit=math.min(budget.bytes or 65536,65536)
    local row_limit=math.min(budget.rows or 256,256)
    assert(integer(byte_limit) and integer(row_limit),'invalid lexer budget')
    if byte_limit==0 or row_limit==0 then return finish({status='more'}) end
    local valid=sequence.validate_certificate(s.index,job.certificate)
    if not valid then return stale('changed source span or adjacent boundary') end
    local rank=sequence.rank(s.index,job.handle)
    if not rank then return stale('detached source span') end
    if input then
        local request=job.request
        if not request or input.request_id~=request.request_id then return stale('mismatched read request') end
        assert(type(input.bytes)=='string' and #input.bytes<=request.max_bytes,'response exceeds requested bytes')
        assert(type(input.eol)=='boolean' and integer(input.start_byte),'read requires eol and exact row start')
        assert(#input.bytes>0 or input.eol,'empty read must finish the line')
        local relative=input.start_byte-request.anchor_byte
        assert(relative>=0 and relative<=job.bytes,'row start outside source span')
        if job.relative_start~=nil then
            assert(relative==job.relative_start,'row start changed across fragments')
        elseif job.offset==0 then assert(relative==0,'first row must start at span boundary') end
        job.relative_start=relative
        local token,step_work
        job.cursor,token,step_work=grammar.lex_step(job.cursor,input.bytes,input.eol,{bytes=byte_limit})
        work.bytes_scanned=step_work.bytes_scanned
        job.col=job.col+step_work.bytes_scanned
        job.request=nil
        if token then
            local separator=input.separator_bytes
            if separator==nil then separator=1 end
            assert(integer(separator),'invalid row separator byte count')
            local row_bytes=token.bytes+separator
            assert(relative+row_bytes<=job.bytes,'row extends beyond source span')
            if job.offset==job.rows-1 then
                assert(relative+row_bytes==job.bytes,'last row must end at span boundary')
            end
            local row=rank.row+job.offset
            if job.opaque then
                sequence.splice(s.index,row,row+1,{{rows=1,bytes=row_bytes,metadata={token=token}}},
                    {start_byte=rank.byte+relative,end_byte=rank.byte+relative+row_bytes})
            else
                assert(relative==0 and row_bytes==rank.bytes,'confirmed row extent changed')
                local metadata=job.metadata or {}
                metadata.token=token
                assert(sequence.update(s.index,job.handle,metadata))
            end
            local published=sequence.at(s.index,row)
            s.job=nil; work.rows_materialized=1
            return finish({status='more',published={row=row,handle=published.handle}})
        end
    end
    -- Every request has its own frame: a disjoint insertion may have moved the
    -- span since the previous fragment, without changing its relative offsets.
    if job.request and (job.request.row~=rank.row+job.offset or job.request.anchor_byte~=rank.byte) then
        job.request=nil
    end
    if not job.request then
        next_id=next_id+1
        job.request={request_id=next_id,row=rank.row+job.offset,col=job.col,
            max_bytes=byte_limit,anchor_byte=rank.byte}
    end
    local r=job.request
    return finish({status='read',request={request_id=r.request_id,row=r.row,col=r.col,max_bytes=r.max_bytes}})
end
return M
