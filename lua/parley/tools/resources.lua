-- Pure process-wide resource admission. Canonicalization belongs to path policy;
-- this reducer only compares canonical keys and owns no IO or global registry.
local M={}
local function integer(n)return type(n)=='number' and n>0 and n<math.huge and n%1==0 end
local function ref(s)return type(s)=='string' and #s>0 and #s<=4096 end
local function copy(t)
    if type(t)~='table'then return t end
    local out={};for k,v in pairs(t)do out[k]=copy(v)end;return out
end
local function inside(parent,path)
    return parent=='/' or path==parent or path:sub(1,#parent+1)==parent..'/'
end
local function conflict(a,b)
    if a.scope=='global' or b.scope=='global'then return true end
    if a.mode=='read' and b.mode=='read'then return false end
    return a.path==b.path or a.scope=='subtree' and inside(a.path,b.path)
        or b.scope=='subtree' and inside(b.path,a.path)
end
local function overlaps(a,b)
    for _,x in ipairs(a.claims)do for _,y in ipairs(b.claims)do if conflict(x,y)then return true end end end
    return false
end
local function waiting_before(a,b)
    return a.document==b.document or a.generation==b.generation or overlaps(a,b)
end
local function path_valid(path)
    return ref(path) and path:sub(1,1)=='/' and not path:find('%z')
        and (path=='/' or path:sub(-1)~='/') and not path:find('//',1,true)
        and not (path..'/'):find('/./',1,true) and not (path..'/'):find('/../',1,true)
end
local function request(value,limits)
    if type(value)~='table' or getmetatable(value) or not ref(value.id)
        or not ref(value.document) or not ref(value.generation) or type(value.claims)~='table'
        or getmetatable(value.claims)then return nil end
    local count=0
    for k in pairs(value.claims)do
        if not integer(k)then return nil end;count=count+1
        if count>limits.max_claims then return nil end
    end
    local claims={}
    for i=1,count do
        local c=value.claims[i]
        if type(c)~='table' or getmetatable(c) or (c.mode~='read' and c.mode~='write')then return nil end
        if c.scope=='global'then
            if c.mode~='write' or c.path~=nil then return nil end
        elseif (c.scope~='file' and c.scope~='subtree') or not path_valid(c.path)then return nil end
        claims[i]={scope=c.scope,mode=c.mode,path=c.path}
    end
    return {id=value.id,document=value.document,generation=value.generation,claims=claims,status='queued'}
end
local function capacity(s,record)
    local running,document,generation=0,0,0
    for _,r in pairs(s.records)do if r.status~='queued'then
        running=running+1
        if r.document==record.document then document=document+1 end
        if r.generation==record.generation then generation=generation+1 end
    end end
    return running<s.limits.running and document<s.limits.per_document and generation<s.limits.per_generation
end
local function eligible(s,record,older)
    if not capacity(s,record)then return false end
    for _,r in pairs(s.records)do if r.status~='queued' and overlaps(record,r)then return false end end
    for _,id in ipairs(older)do if waiting_before(record,s.records[id])then return false end end
    return true
end
local function changed(s)
    local records,queue={},{}
    for k,v in pairs(s.records)do records[k]=v end
    for i,v in ipairs(s.queue)do queue[i]=v end
    return {limits=s.limits,records=records,queue=queue}
end
function M.new(opts)
    opts=opts or {}
    local function configured(key,default)if opts[key]~=nil then return opts[key]end;return default end
    local limits={running=configured('running',16),queued=configured('queued',128),
        per_document=configured('per_document',8),per_generation=configured('per_generation',4),
        queued_per_generation=configured('queued_per_generation',32),max_claims=configured('max_claims',32)}
    for _,n in pairs(limits)do assert(integer(n),'invalid resource limit')end
    return {limits=limits,records={},queue={}}
end
function M.admit(s,value)
    local record=request(value,s.limits);if not record then return s,{status='invalid'}end
    if s.records[record.id]then return s,{status='duplicate'}end
    local ready=eligible(s,record,s.queue)
    if not ready then
        local queued=0;for _,id in ipairs(s.queue)do if s.records[id].generation==record.generation then queued=queued+1 end end
        if #s.queue>=s.limits.queued or queued>=s.limits.queued_per_generation then return s,{status='capacity'}end
    end
    local next_state=changed(s);next_state.records[record.id]=record
    if ready then record.status='admitted' else next_state.queue[#next_state.queue+1]=record.id end
    return next_state,{status=record.status,id=record.id}
end
function M.pump(s)
    local next_state=changed(s);next_state.queue={};local admitted={}
    for _,id in ipairs(s.queue)do
        local record=next_state.records[id]
        if eligible(next_state,record,next_state.queue)then
            record=copy(record);record.status='admitted';next_state.records[id]=record;admitted[#admitted+1]=id
        else next_state.queue[#next_state.queue+1]=id end
    end
    return next_state,admitted
end
function M.unknown(s,id)
    local record=s.records[id]
    if not record then return s,{status='missing'}end
    if record.status=='queued'then return s,{status='queued'}end
    local next_state=changed(s);record=copy(record);record.status='unknown';next_state.records[id]=record
    return next_state,{status='unknown'}
end
function M.release(s,id,evidence)
    local record=s.records[id]
    if not record then return s,{status='missing'}end
    if record.status=='queued'then return s,{status='queued'}end
    if type(evidence)~='table' or evidence.effect~='known' or not ref(evidence.evidence_ref)then
        return s,{status='unresolved'}
    end
    local next_state=changed(s);next_state.records[id]=nil
    return next_state,{status='released'}
end
function M.cancel(s,id)
    local record=s.records[id]
    if not record then return s,{status='missing'}end
    if record.status~='queued'then return s,{status='running'}end
    local next_state=changed(s);next_state.records[id]=nil;next_state.queue={}
    for _,other in ipairs(s.queue)do if other~=id then next_state.queue[#next_state.queue+1]=other end end
    return next_state,{status='cancelled'}
end
function M.get(s,id)return copy(s.records[id])end
function M.stats(s)
    local out={running=0,queued=#s.queue,unknown=0}
    for _,r in pairs(s.records)do
        if r.status~='queued'then out.running=out.running+1 end
        if r.status=='unknown'then out.unknown=out.unknown+1 end
    end
    return out
end
return M
