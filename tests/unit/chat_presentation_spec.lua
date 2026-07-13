local presentation = require("parley.chat_presentation")

local function initial(opts)
    opts = opts or {}
    opts.now_ms = opts.now_ms or 0
    opts.verbs = opts.verbs or { "brewing", "cooking", "dragon-slaying" }
    opts.verb_index = opts.verb_index or 1
    return presentation.initial(opts)
end

local function transition(state, event)
    local next_state, actions = presentation.transition(state, event)
    return next_state, actions
end

local function reveal(state, now_ms)
    return transition(state, { type = "reveal_due", now_ms = now_ms or 1000 })
end

describe("chat presentation controller", function()
    it("initializes one silent leg with deterministic deadlines and verb", function()
        local state = initial({ now_ms = 25, verbs = { "brewing", "cooking" }, verb_index = 2 })

        assert.are.same({
            phase = "waiting",
            verbs = { "brewing", "cooking" },
            verb_index = 2,
            verb = "cooking",
            reveal_at = 1025,
            minimum_at = 2025,
            verb_due_at = 15025,
            last_activity_at = 25,
            staged = {},
        }, state)
    end)

    it("releases visible content before reveal without ever showing", function()
        local state = initial()
        local released, actions = transition(state, {
            type = "content",
            now_ms = 999,
            qid = "q",
            chunk = "hello",
        })

        assert.are.equal("released", released.phase)
        assert.are.same({ { type = "emit_content", qid = "q", chunk = "hello" } }, actions)
        assert.are.equal("waiting", state.phase)
        assert.are.same({}, state.staged)
    end)

    it("releases meaningful progress before reveal without showing", function()
        local released, actions = transition(initial(), {
            type = "progress",
            now_ms = 500,
            message = "Reasoning: checking",
        })

        assert.are.equal("released", released.phase)
        assert.are.same({ { type = "render_status", message = "Reasoning: checking" } }, actions)
    end)

    it("reveals playful status and stages visible events in callback order", function()
        local waiting = initial()
        local showing, reveal_actions = reveal(waiting)
        local with_content, content_actions = transition(showing, {
            type = "content",
            now_ms = 1200,
            qid = "q",
            chunk = "hello",
        })
        local staged, progress_actions = transition(with_content, {
            type = "progress",
            now_ms = 1300,
            message = "Searching web... query",
        })

        assert.are.equal("showing", showing.phase)
        assert.are.same({ { type = "show_playful", verb = "brewing" } }, reveal_actions)
        assert.are.same({}, content_actions)
        assert.are.same({}, progress_actions)
        assert.are.same({
            { type = "content", qid = "q", chunk = "hello" },
            { type = "progress", message = "Searching web... query" },
        }, staged.staged)
        assert.are.same({}, showing.staged)
    end)

    it("starts the minimum-visible window when a delayed reveal is delivered", function()
        local showing = select(1, reveal(initial(), 1900))
        local staged, actions = transition(showing, {
            type = "content", now_ms = 2000, qid = "q", chunk = "wait",
        })

        assert.are.equal(2900, showing.minimum_at)
        assert.are.equal("showing", staged.phase)
        assert.are.same({}, actions)
    end)

    it("flushes staged output once at the minimum deadline", function()
        local showing = select(1, reveal(initial()))
        local staged = select(1, transition(showing, {
            type = "content", now_ms = 1200, qid = "q", chunk = "one",
        }))
        staged = select(1, transition(staged, {
            type = "progress", now_ms = 1300, message = "Reasoning: two",
        }))
        local released, actions = transition(staged, { type = "minimum_due", now_ms = 2000 })

        assert.are.equal("released", released.phase)
        assert.are.same({}, released.staged)
        assert.are.same({
            { type = "hide" },
            { type = "emit_content", qid = "q", chunk = "one" },
            { type = "render_status", message = "Reasoning: two" },
        }, actions)

        local still_released, later = transition(released, { type = "minimum_due", now_ms = 2000 })
        assert.are.equal("released", still_released.phase)
        assert.are.same({}, later)
    end)

    it("visible output arriving at or after minimum hides then flushes", function()
        local showing = select(1, reveal(initial()))
        local released, actions = transition(showing, {
            type = "content", now_ms = 2000, qid = "q", chunk = "now",
        })

        assert.are.equal("released", released.phase)
        assert.are.same({
            { type = "hide" },
            { type = "emit_content", qid = "q", chunk = "now" },
        }, actions)
    end)

    it("keeps showing after minimum when no visible event or completion exists", function()
        local showing = select(1, reveal(initial()))
        local unchanged, actions = transition(showing, { type = "minimum_due", now_ms = 2000 })

        assert.are.equal("showing", unchanged.phase)
        assert.are.same({}, actions)
    end)

    it("rotates to a non-current requested verb on activity and resets idle deadline", function()
        local showing = select(1, reveal(initial()))
        local rotated, actions = transition(showing, {
            type = "activity", now_ms = 1400, verb_index = 1,
        })

        assert.are.equal(2, rotated.verb_index)
        assert.are.equal("cooking", rotated.verb)
        assert.are.equal(1400, rotated.last_activity_at)
        assert.are.equal(16400, rotated.verb_due_at)
        assert.are.same({ { type = "show_playful", verb = "cooking" } }, actions)
    end)

    it("rotates on idle but spinner ticks never rotate the verb", function()
        local showing = select(1, reveal(initial()))
        local ticked, tick_actions = transition(showing, { type = "spinner_tick", now_ms = 1500 })
        local idled, idle_actions = transition(ticked, {
            type = "idle", now_ms = 15000, verb_index = 3,
        })

        assert.are.equal(showing.verb_index, ticked.verb_index)
        assert.are.equal(showing.verb_due_at, ticked.verb_due_at)
        assert.are.same({}, tick_actions)
        assert.are.equal(3, idled.verb_index)
        assert.are.equal("dragon-slaying", idled.verb)
        assert.are.equal(30000, idled.verb_due_at)
        assert.are.same({ { type = "show_playful", verb = "dragon-slaying" } }, idle_actions)
    end)

    it("ignores an idle callback made stale by later activity", function()
        local showing = select(1, reveal(initial()))
        local active = select(1, transition(showing, {
            type = "activity", now_ms = 14000, verb_index = 2,
        }))
        local unchanged, actions = transition(active, {
            type = "idle", now_ms = 15000, verb_index = 3,
        })

        assert.are.equal(2, unchanged.verb_index)
        assert.are.equal(29000, unchanged.verb_due_at)
        assert.are.same({}, actions)
    end)

    it("continues a tool-only completion immediately before reveal", function()
        local finished, actions = transition(initial(), {
            type = "complete", now_ms = 500, completion = "run-tool", tool_only = true,
        })

        assert.are.equal("finished", finished.phase)
        assert.are.same({ { type = "continue_completion", completion = "run-tool" } }, actions)
    end)

    it("defers a shown tool-only completion until minimum and hides first", function()
        local showing = select(1, reveal(initial()))
        local deferred, immediate = transition(showing, {
            type = "complete", now_ms = 1500, completion = "run-tool", tool_only = true,
        })
        local finished, actions = transition(deferred, { type = "minimum_due", now_ms = 2000 })

        assert.are.equal("showing", deferred.phase)
        assert.are.same({}, immediate)
        assert.are.equal("finished", finished.phase)
        assert.are.same({
            { type = "hide" },
            { type = "continue_completion", completion = "run-tool" },
        }, actions)
    end)

    it("flushes staged visible output before a deferred completion", function()
        local showing = select(1, reveal(initial()))
        local staged = select(1, transition(showing, {
            type = "content", now_ms = 1200, qid = "q", chunk = "partial",
        }))
        local deferred = select(1, transition(staged, {
            type = "complete", now_ms = 1300, completion = "finish",
        }))
        local finished, actions = transition(deferred, { type = "minimum_due", now_ms = 2000 })

        assert.are.equal("finished", finished.phase)
        assert.are.same({
            { type = "hide" },
            { type = "emit_content", qid = "q", chunk = "partial" },
            { type = "continue_completion", completion = "finish" },
        }, actions)
    end)

    it("honors minimum duration for an empty shown success", function()
        local showing = select(1, reveal(initial()))
        local deferred = select(1, transition(showing, {
            type = "complete", now_ms = 1100, completion = "empty",
        }))
        local finished, actions = transition(deferred, { type = "minimum_due", now_ms = 2000 })

        assert.are.equal("finished", finished.phase)
        assert.are.same({
            { type = "hide" },
            { type = "continue_completion", completion = "empty" },
        }, actions)
    end)

    it("provider failure with ownership bypasses minimum and preserves staged output", function()
        local showing = select(1, reveal(initial()))
        local staged = select(1, transition(showing, {
            type = "content", now_ms = 1200, qid = "q", chunk = "partial",
        }))
        local finished, actions = transition(staged, {
            type = "failure", now_ms = 1300, owns_transcript = true, error = "transport failed",
        })

        assert.are.equal("finished", finished.phase)
        assert.are.same({}, finished.staged)
        assert.are.same({
            { type = "hide" },
            { type = "emit_content", qid = "q", chunk = "partial" },
            { type = "surface_failure", error = "transport failed" },
        }, actions)
    end)

    for _, terminal_type in ipairs({ "cancel", "stale", "invalid" }) do
        it(terminal_type .. " hides and discards staged output", function()
            local showing = select(1, reveal(initial()))
            local staged = select(1, transition(showing, {
                type = "content", now_ms = 1200, qid = "q", chunk = "discard me",
            }))
            local finished, actions = transition(staged, { type = terminal_type, now_ms = 1300 })

            assert.are.equal("finished", finished.phase)
            assert.are.same({}, finished.staged)
            assert.are.same({ { type = "hide" } }, actions)
        end)
    end

    it("a failure without ownership discards staged output", function()
        local showing = select(1, reveal(initial()))
        local staged = select(1, transition(showing, {
            type = "content", now_ms = 1200, qid = "q", chunk = "discard me",
        }))
        local finished, actions = transition(staged, {
            type = "failure", now_ms = 1300, owns_transcript = false, error = "stale failure",
        })

        assert.are.equal("finished", finished.phase)
        assert.are.same({ { type = "hide" } }, actions)
    end)

    it("events after a terminal transition are no-ops", function()
        local finished = select(1, transition(initial(), {
            type = "complete", now_ms = 100, completion = "done",
        }))
        local later, actions = transition(finished, {
            type = "content", now_ms = 200, qid = "q", chunk = "late",
        })

        assert.are.equal(finished, later)
        assert.are.same({}, actions)
    end)

    it("same-deadline callback order decides reveal versus direct release exactly once", function()
        local waiting = initial()
        local direct, direct_actions = transition(waiting, {
            type = "content", now_ms = 1000, qid = "q", chunk = "first",
        })
        local direct_after_timer, timer_actions = transition(direct, {
            type = "reveal_due", now_ms = 1000,
        })

        assert.are.equal("released", direct_after_timer.phase)
        assert.are.same({ { type = "emit_content", qid = "q", chunk = "first" } }, direct_actions)
        assert.are.same({}, timer_actions)

        local shown, show_actions = transition(initial(), { type = "reveal_due", now_ms = 1000 })
        local staged, staged_actions = transition(shown, {
            type = "content", now_ms = 1000, qid = "q", chunk = "second",
        })
        assert.are.equal("showing", staged.phase)
        assert.are.same({ { type = "show_playful", verb = "brewing" } }, show_actions)
        assert.are.same({}, staged_actions)
    end)

    it("same-deadline callback order flushes once", function()
        local showing = select(1, reveal(initial()))
        local staged = select(1, transition(showing, {
            type = "content", now_ms = 1500, qid = "q", chunk = "one",
        }))
        local released, timer_actions = transition(staged, { type = "minimum_due", now_ms = 2000 })
        local after_visible, visible_actions = transition(released, {
            type = "content", now_ms = 2000, qid = "q", chunk = "two",
        })

        assert.are.same({
            { type = "hide" },
            { type = "emit_content", qid = "q", chunk = "one" },
        }, timer_actions)
        assert.are.same({ { type = "emit_content", qid = "q", chunk = "two" } }, visible_actions)
        assert.are.equal("released", after_visible.phase)

        local shown_again = select(1, reveal(initial()))
        local at_min, visible_first = transition(shown_again, {
            type = "content", now_ms = 2000, qid = "q", chunk = "first",
        })
        local after_timer, timer_second = transition(at_min, { type = "minimum_due", now_ms = 2000 })
        assert.are.same({
            { type = "hide" },
            { type = "emit_content", qid = "q", chunk = "first" },
        }, visible_first)
        assert.are.same({}, timer_second)
        assert.are.equal("released", after_timer.phase)
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
end)
