-- The order a tool round's blocks are written in (#266). Pure and immutable:
-- every function returns a new record and never touches the one it is given.
--
-- A round of `count` calls is written as call 1, result 1, call 2, result 2, …
-- A call block needs nothing; a result needs its own outcome to have arrived.
-- So the transcript only ever grows at its tail, in declared order, however the
-- tools' outcomes race — an early outcome is held until everything before it is
-- written. Any outcome is writable (a failed call is written as an error
-- result), so only a call whose outcome never arrives holds the ones behind it.
local M={}
local function integer(n) return type(n)=='number' and n%1==0 end
local function item_at(seq)
    if seq.position>=2*seq.count then return nil end
    return {kind=seq.position%2==0 and 'call' or 'result',index=math.floor(seq.position/2)+1}
end
local function index_of(seq,index)
    assert(integer(index) and index>=1 and index<=seq.count,'invalid tool index')
    return index
end
local function with(seq,position,arrived)
    return {count=seq.count,position=position,arrived=arrived}
end

function M.new(count)
    assert(integer(count) and count>=1 and count<=32,'invalid tool round size')
    return {count=count,position=0,arrived={}}
end

--- The next block to write, or nil when the next one is a result whose outcome
--- has not arrived (or the round is fully written).
function M.next(seq)
    local item=item_at(seq)
    if item and item.kind=='result' and not seq.arrived[item.index] then return nil end
    return item
end

--- The index of the result the walk is blocked on — the next block is call
--- `index`'s result and its outcome has not arrived — or nil (#266 M3: Stop
--- cancels exactly that call and moves on).
function M.waiting(seq)
    local item=item_at(seq)
    if item and item.kind=='result' and not seq.arrived[item.index] then return item.index end
    return nil
end

--- Record that call `index`'s outcome arrived. Once its result is written the
--- outcome is final, so a later one (an unknown effect confirmed after the
--- fact) changes nothing.
function M.outcome(seq,index)
    index_of(seq,index)
    local arrived={};for i,v in pairs(seq.arrived) do arrived[i]=v end
    arrived[index]=true
    return with(seq,seq.position,arrived)
end

--- Record that `item` — which must be the one `next` offers — is written.
function M.written(seq,item)
    local expected=M.next(seq)
    assert(expected and type(item)=='table' and item.kind==expected.kind and item.index==expected.index,
        'tool block written out of order')
    return with(seq,seq.position+1,seq.arrived)
end

--- Is call `index`'s result already in the transcript?
function M.final(seq,index)
    return seq.position>=2*index_of(seq,index)
end

function M.complete(seq) return seq.position>=2*seq.count end
return M
