local R=require('parley.tools.resources')
local function claim(path,mode,scope)return {path=path,mode=mode or 'write',scope=scope or 'file'}end
local function request(id,claims,owner)return {id=id,claims=claims,document=owner or 'd',generation=owner or 'g'}end
local function release(s,id)return R.release(s,id,{effect='known',evidence_ref='verified'})end
local function admitted(s,req)local next_state,result=R.admit(s,req);assert.equals('admitted',result.status);return next_state end

describe('pure tool resource admission',function()
    it('allows shared readers while serializing writes and subtree overlaps',function()
        local s=R.new();s=admitted(s,request('a',{claim('/a','read')}));s=admitted(s,request('b',{claim('/a','read')}))
        local status;s,status=R.admit(s,request('c',{claim('/a','write')}));assert.equals('queued',status.status)
        s=admitted(s,request('d',{claim('/ab','write')},'other'))
        s=release(s,'a');local ready;s,ready=R.pump(s);assert.same({},ready)
        s=release(s,'b');s,ready=R.pump(s);assert.same({'c'},ready)
        s,status=R.admit(s,request('e',{claim('/','read','subtree')}));assert.equals('queued',status.status)
    end)
    it('acquires all claims atomically and lets unrelated work pass a blocked waiter',function()
        local s=admitted(R.new(),request('a',{claim('/a')}))
        local result;s,result=R.admit(s,request('b',{claim('/a'),claim('/b')}));assert.equals('queued',result.status)
        assert.equals(1,R.stats(s).running)
        -- A younger overlapping request cannot jump ahead of the atomic waiter.
        s,result=R.admit(s,request('c',{claim('/b')}));assert.equals('queued',result.status)
        s=admitted(s,request('d',{claim('/disjoint')},'other'))
        s=release(s,'a');local ready;s,ready=R.pump(s);assert.same({'b'},ready)
        s=release(s,'b');s,ready=R.pump(s);assert.same({'c'},ready)
    end)
    it('treats global claims as exclusive and quarantines unknown effects',function()
        local s=admitted(R.new(),request('a',{claim('/a')}));s=R.unknown(s,'a')
        local before=s
        for _,e in ipairs({{}, {resolved=true},{process_exited=true},{effect='known'}})do
            local next_state,result=R.release(s,'a',e);assert.equals('unresolved',result.status);assert.same(before,next_state)
        end
        local next_state,result=R.cancel(s,'a');assert.equals('running',result.status);assert.same(s,next_state)
        s=admitted(s,request('free',{claim('/z')},'other'))
        s,result=R.admit(s,request('global',{{scope='global',mode='write'}}));assert.equals('queued',result.status)
        s,result=R.admit(s,request('later',{claim('/unrelated')},'third'));assert.equals('queued',result.status)
        s=release(s,'a');s=release(s,'free');local ready;s,ready=R.pump(s);assert.same({'global'},ready)
        s=release(s,'global');s,ready=R.pump(s);assert.same({'later'},ready)
    end)
    it('enforces owner and process bounds without evicting uncertainty',function()
        local s=R.new({running=2,queued=2,per_document=1,per_generation=1,queued_per_generation=1})
        s=admitted(s,request('a',{claim('/a')}));s=R.unknown(s,'a')
        local result;s,result=R.admit(s,request('b',{claim('/b')}));assert.equals('queued',result.status)
        local unchanged,full=R.admit(s,request('c',{claim('/c')}));assert.equals('capacity',full.status);assert.same(s,unchanged)
        s=admitted(s,request('d',{claim('/d')},'other'))
        s,result=R.admit(s,request('e',{claim('/e')},'third'));assert.equals('queued',result.status)
        unchanged,full=R.admit(s,request('f',{claim('/f')},'fourth'));assert.equals('capacity',full.status);assert.same(s,unchanged)
        assert.same({running=2,queued=2,unknown=1},R.stats(s))
        s=R.cancel(s,'b');s=release(s,'d');local ready;s,ready=R.pump(s);assert.same({'e'},ready)
    end)
    it('copies claims and rejects malformed paths, limits, and duplicate identities',function()
        local initial=R.new();local req=request('a',{claim('/a')});local s=admitted(initial,req)
        req.claims[1].path='/elsewhere';assert.equals('/a',R.get(s,'a').claims[1].path)
        local duplicate,result=R.admit(s,request('a',{claim('/b')}));assert.equals('duplicate',result.status);assert.same(s,duplicate)
        for _,path in ipairs({'relative','/a/../b','/a//b','/a/','/a/./b'})do
            local unchanged,bad=R.admit(s,request('bad',{claim(path)}));assert.equals('invalid',bad.status);assert.same(s,unchanged)
        end
        assert.has_error(function()R.new({queued=false})end)
        assert.has_error(function()R.new({running=0})end)
        assert.has_error(function()R.new({queued=math.huge})end)
        local view=R.get(s,'a');view.claims[1].path='/mutation';assert.equals('/a',R.get(s,'a').claims[1].path)
    end)
    it('matches an independent component-prefix oracle under generated admission histories',function()
        local function parts(path)local p={};for c in path:gmatch('[^/]+')do p[#p+1]=c end;return p end
        local function contains(a,b)
            local x,y=parts(a),parts(b);if #x>#y then return false end
            for i,v in ipairs(x)do if v~=y[i]then return false end end;return true
        end
        local function conflict(a,b)
            if a.scope=='global' or b.scope=='global'then return true end
            if a.mode=='read' and b.mode=='read'then return false end
            return a.path==b.path or a.scope=='subtree' and contains(a.path,b.path)
                or b.scope=='subtree' and contains(b.path,a.path)
        end
        local seed=9127
        local function rand(n)seed=(seed*48271)%2147483647;return seed%n+1 end
        for _=1,30 do
            local s=R.new({running=16,queued=128,per_document=16,per_generation=16,queued_per_generation=128})
            local active,queue,requests={},{},{}
            local function eligible(id,blocked)
                for _,other in ipairs(blocked)do for _,a in ipairs(requests[id])do for _,b in ipairs(requests[other])do
                    if conflict(a,b)then return false end
                end end end;return true
            end
            local function oracle_pump()
                local next_queue,added={},{}
                for _,id in ipairs(queue)do
                    if #active<16 and eligible(id,active) and eligible(id,next_queue)then active[#active+1]=id;added[#added+1]=id
                    else next_queue[#next_queue+1]=id end
                end
                queue=next_queue;return added
            end
            for n=1,60 do
                if #active>0 and rand(3)==1 then
                    local at=rand(#active);s=release(s,table.remove(active,at))
                    local expected=oracle_pump();local got;s,got=R.pump(s);assert.same(expected,got)
                else
                    local id=tostring(n);local claims={}
                    for _=1,rand(3)do claims[#claims+1]=claim(({'/a','/a/b','/ab','/z','/'})[rand(5)],
                        rand(2)==1 and 'read' or 'write',rand(2)==1 and 'file' or 'subtree')end
                    requests[id]=claims
                    local expected=#active<16 and eligible(id,active) and eligible(id,queue)
                    local result;s,result=R.admit(s,request(id,claims,id))
                    assert.equals(expected and 'admitted' or 'queued',result.status)
                    if expected then active[#active+1]=id else queue[#queue+1]=id end
                end
                assert.equals(#active,R.stats(s).running);assert.equals(#queue,R.stats(s).queued)
            end
        end
    end)
end)
