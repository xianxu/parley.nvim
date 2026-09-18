local presentation=require('parley.chat_presentation')
local function initial()return presentation.initial({now_ms=0,verbs={'Brewing','Cooking'},verb_index=1})end
describe('presentation-only pending reducer',function()
    it('reveals playful UI after its deadline and rotates on activity',function()
        local s=initial();local next_s,actions=presentation.transition(s,{type='reveal_due',now_ms=999})
        assert.equals(s,next_s);assert.same({},actions)
        s,actions=presentation.transition(s,{type='reveal_due',now_ms=1000})
        assert.equals('showing',s.phase);assert.equals('show_playful',actions[1].type)
        s,actions=presentation.transition(s,{type='activity',now_ms=1100,verb_index=2})
        assert.equals('Cooking',actions[1].verb)
    end)
    it('never delays written bytes or completion for minimum spinner display',function()
        local s=presentation.transition(initial(),{type='reveal_due',now_ms=1000})
        local written,actions=presentation.transition(s,{type='written',now_ms=1001})
        assert.equals('released',written.phase);assert.same({{type='hide'}},actions)
        local done,effects=presentation.transition(s,{type='complete',now_ms=1001})
        assert.equals('finished',done.phase);assert.same({{type='hide'}},effects)
        assert.is_nil(done.pending_completion);assert.is_nil(done.staged_tail)
    end)
    it('renders meaningful progress immediately and ignores content payload events',function()
        local s=presentation.transition(initial(),{type='reveal_due',now_ms=1000})
        local next_s,actions=presentation.transition(s,{type='progress',now_ms=1001,message='Searching'})
        assert.equals('released',next_s.phase);assert.equals('render_status',actions[2].type)
        local unchanged,effects=presentation.transition(next_s,{type='content',now_ms=1002,chunk='not owned'})
        assert.equals(next_s,unchanged);assert.same({},effects);assert.is_nil(unchanged.staged_tail)
    end)
    it('makes all terminal UI events idempotent without callback effects',function()
        for _,kind in ipairs({'complete','cancel','stale','invalid','failure'})do
            local s,actions=presentation.transition(initial(),{type=kind,now_ms=0,completion=function()error('IO')end})
            assert.equals('finished',s.phase);assert.same({{type='hide'}},actions)
            local same,effects=presentation.transition(s,{type='progress',now_ms=1,message='late'})
            assert.equals(s,same);assert.same({},effects)
        end
    end)
    it('bounds accumulated display detail independently of provider output size',function()
        local state={}
        for _=1,100 do state=presentation.progress_message(state,{kind='reasoning',text=string.rep('x',1000)})end
        assert.is_true(#state.text<=4096)
    end)
end)
describe("progress_message", function()
    it("accumulates and compacts reasoning detail fragments", function()
        local state, first = presentation.progress_message({}, {
            phase = "reasoning", kind = "reasoning", block_type = "thinking",
            message = "Reasoning...", text = "  Think\n",
        })
        local continued, second = presentation.progress_message(state, {
            phase = "reasoning", kind = "reasoning", block_type = "thinking",
            message = "Reasoning...", text = "  carefully  ",
        })

        assert.are.equal("Reasoning: Think ", first)
        assert.are.equal("Reasoning: Think carefully ", second)
        assert.are.equal("  Think\n  carefully  ", continued.text)
    end)

    it("uses the provider message or fallback for tool detail", function()
        local state, with_base = presentation.progress_message({}, {
            phase = "tooling", kind = "tool_update", tool = "web_search",
            block_type = "tool_calls_delta", message = "Searching web...", text = "parley",
        })
        local _, fallback = presentation.progress_message(state, {
            phase = "tooling", kind = "tool_update", tool = "read",
            block_type = "tool_calls_delta", text = "README",
        })

        assert.are.equal("Searching web... parley", with_base)
        assert.are.equal("Working... README", fallback)
    end)

    it("resets accumulation when the detail key changes", function()
        local state = select(1, presentation.progress_message({}, {
            phase = "tooling", kind = "tool_update", tool = "web_search",
            block_type = "input", message = "Searching web...", text = "first",
        }))
        local changed, message = presentation.progress_message(state, {
            phase = "tooling", kind = "tool_update", tool = "web_search",
            block_type = "result", message = "Searching web...", text = "second",
        })

        assert.are.equal("second", changed.text)
        assert.are.equal("Searching web... second", message)
    end)

    it("clears detail state when an event has no detail", function()
        local state = select(1, presentation.progress_message({}, {
            phase = "reasoning", kind = "reasoning", text = "thinking",
        }))
        local cleared, message = presentation.progress_message(state, { message = "Done" })

        assert.are.same({}, cleared)
        assert.are.equal("Done", message)
    end)

    -- #266: a generation held behind the write turn names what it waits for and
    -- why, so a stalled holder never reads as a frozen editor.
    it('names the answer holding the write turn and what it is doing',function()
        local message=presentation.waiting_message(12,'executing_tools')
        assert.truthy(message:find('line 12',1,true))
        assert.truthy(message:find('running tools',1,true))
        assert.truthy(message:find(':ParleyStop',1,true))
        for phase,why in pairs({preparing='preparing',requesting='streaming',draining='finishing',
            finalizing='finishing',flushing='stopping',stopping='stopping'}) do
            assert.truthy(presentation.waiting_message(3,phase):find(why,1,true),phase)
        end
        assert.truthy(presentation.waiting_message(nil,nil):find('another answer',1,true))
    end)
    -- #266 M2: a round's blocks land one at a time, so the tools still running
    -- are counted here rather than seen in the transcript.
    it('counts a round\'s tools as they finish, then names a wait on cleanup',function()
        assert.truthy(presentation.tools_message({total=3,finished=1,settled=1}):find('Running tools: 1 of 3 finished',1,true))
        assert.truthy(presentation.tools_message({total=3,finished=3,settled=1}):find('Tools finished; waiting for 2 to clean up',1,true))
    end)
    -- The rule behind the stall-visibility findings: every note shown while an
    -- answer waits names what ends the wait. Walks every such note.
    it('names an escape in every note an answer shows while it waits',function()
        local notes={
            presentation.tools_message({total=2,finished=0,settled=0}),
            presentation.tools_message({total=2,finished=2,settled=1}),
            presentation.flushing_message(3),presentation.flushing_message(nil),
        }
        for _,phase in ipairs({'preparing','requesting','executing_tools','draining','finalizing','flushing','stopping'}) do
            notes[#notes+1]=presentation.waiting_message(4,phase)
        end
        for _,note in ipairs(notes) do assert.truthy(note:find(':ParleyStop',1,true),note) end
    end)
    -- #266 M3: a Stop during a tool round writes the round out first.
    it('says a stopped answer is writing its tool results, and after whom',function()
        assert.truthy(presentation.flushing_message(4):find('Stopped; writing its tool results after the answer to line 4',1,true))
        assert.truthy(presentation.flushing_message(nil):find('a second :ParleyStop drops the rest',1,true))
    end)
    it('says why a response stopped at its staging budget, naming the answer it waited behind',function()
        local held=presentation.overflow_message(7)
        assert.truthy(held:find('staging budget',1,true));assert.truthy(held:find('line 7',1,true))
        assert.is_nil(presentation.overflow_message(nil):find('waiting',1,true),'not held: no holder to name')
    end)
end)
