-- #266 M1: the turn must be observable, or a queued generation never wakes.
--
-- notify() fires only on edit/reload/detach/repair, and a runner's Deferred
-- re-arms only while step returns 'more' — so a generation parked waiting for the
-- turn emits nothing, its timer stops, and moving the turn elsewhere would leave
-- it asleep forever.
--
-- This spec asserts the NOTIFICATION, not the wake. At this point in the plan
-- nothing refuses a turnless write yet (that is Task 1.4) and nothing requests a
-- turn from the machine (Task 1.5), so a wake assertion would pass whether or not
-- the notify exists. The end-to-end wake lives in Task 1.6.
local ok,D=pcall(require,'parley.document')
local Fake=require('tests.helpers.fake_document_editor')

local nextbuf=93000
local function attach()
    nextbuf=nextbuf+1
    local f=Fake.new({'💬: question','🤖: answer','body'})
    local doc=D.attach(nextbuf,{driver=f.driver,schedule=false})
    assert.equals('idle',D.drain(doc,1000).status)
    return doc
end
local function register(doc)
    local r=D.transition(doc,{kind='register_generation',input_snapshot={text='frozen'}})
    assert.is_true(r.ok); return r.generation
end

describe('write turn notification',function()
    it('provides the coordinator',function() assert.is_true(ok) end)
    if not ok then return end

    it('admits the turn events at the coordinator seam',function()
        local doc=attach(); local g=register(doc)
        assert.is_true(D.transition(doc,{kind='request_turn',generation=g}).ok)
        assert.is_true(D.transition(doc,{kind='release_turn',generation=g}).ok)
        D.detach(doc)
    end)

    it('notifies subscribers when a request takes the turn',function()
        local doc=attach(); local g=register(doc)
        local seen={}
        local off=D.subscribe(doc,function(ev) if ev.kind=='turn' then seen[#seen+1]=ev end end)
        D.transition(doc,{kind='request_turn',generation=g})
        assert.equals(1,#seen,'no turn notification when the turn was taken')
        assert.equals(g,seen[1].turn)
        off(); D.detach(doc)
    end)

    -- The case a per-event notify list silently excludes. finish_generation is the
    -- most common release: generation_runner.lua:436 is its only terminal caller.
    it('notifies subscribers when finish_generation moves the turn',function()
        local doc=attach()
        local a,b=register(doc),register(doc)
        D.transition(doc,{kind='request_turn',generation=a})
        D.transition(doc,{kind='request_turn',generation=b})
        local seen={}
        local off=D.subscribe(doc,function(ev) if ev.kind=='turn' then seen[#seen+1]=ev end end)
        D.transition(doc,{kind='finish_generation',generation=a})
        assert.equals(1,#seen,'no turn notification when the holder finished')
        assert.equals(b,seen[1].turn,'the notification must carry the new holder')
        off(); D.detach(doc)
    end)

    it('does not notify when a transition leaves the turn unchanged',function()
        local doc=attach()
        local a,b=register(doc),register(doc)
        D.transition(doc,{kind='request_turn',generation=a})
        local seen={}
        local off=D.subscribe(doc,function(ev) if ev.kind=='turn' then seen[#seen+1]=ev end end)
        -- b requesting cannot preempt an eligible incumbent, so the value is stable.
        D.transition(doc,{kind='request_turn',generation=b})
        assert.equals(0,#seen,'a stable turn must not wake every subscriber')
        off(); D.detach(doc)
    end)

    -- This is the first notify ever fired from inside M.transition (every other
    -- site is in observe/repair_step), so a subscriber now re-enters the
    -- coordinator synchronously. Pin that it terminates and stays consistent.
    it('survives a subscriber that transitions from inside the turn callback',function()
        local doc=attach()
        local a,b=register(doc),register(doc)
        local depth,max_depth=0,0
        local off=D.subscribe(doc,function(ev)
            if ev.kind~='turn' then return end
            depth=depth+1; if depth>max_depth then max_depth=depth end
            if depth<4 then
                -- Re-entrant request from inside the notification. b is already
                -- eligible, so the value is stable and this must not recurse.
                D.transition(doc,{kind='request_turn',generation=b})
            end
            depth=depth-1
        end)
        D.transition(doc,{kind='request_turn',generation=a})
        assert.equals(1,max_depth,'a stable turn must not re-notify from its own callback')
        assert.equals(a,D.snapshot(doc).turn)
        off(); D.detach(doc)
    end)
end)
