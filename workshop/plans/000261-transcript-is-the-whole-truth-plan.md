# Transcript Is the Whole Truth Implementation Plan

> **For agentic workers:** Consult AGENTS.md Section 3 (Subagent Strategy) to determine the appropriate execution approach: use superpowers-subagent-driven-development (if subagents are suitable per AGENTS.md) or superpowers-executing-plans to implement this plan. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Nothing outside a chat's Markdown file can stop someone working on it:
the on-disk answer-recovery store is deleted, a regenerating exchange's previous
answer lives only as long as its generation (and feeds request context, #255),
everything a stopped generation started is killed for certain, and every refusal
on the submission path says what happened and what to do.

**Architecture:** Five milestones, each closing one way that state outside the
transcript blocks or confuses work on it. **M1** deletes the store and the
privacy machinery that existed only to hide it, and adds a guard that makes every
future reader of the profile state directory declare why its absence cannot
block. **M2** puts a `prev_answer` slot on the document coordinator, keyed by
exchange identity and valid only while the regenerating generation still holds
a grant there, and substitutes it into request context in the same chat and in
sub-chats. **M3** makes the kill certain: children lead their own process
group, Stop kills a generation's scope as groups under SIGTERM then SIGKILL, and
every other process gets a deadline. **M4** makes every wait a generation holds
settle, so the admission counters drain by construction. **M5** gives the
submission path one refusal vocabulary, with no silent return and no internal
token shown raw, and publishes the inventory.

**Tech Stack:** Lua (Neovim 0.11 plugin), plenary/busted specs under headless
Neovim (`make test`, `make test-spec SPEC=…`), libuv (`vim.uv`) for processes.

**Issue:** parley#261 (absorbs parley#255) · **Target:** `workshop/targets/transcript-is-the-whole-truth.md`

**Branch:** `sdlc change-code` names it `000261-…`. Keep that prefix:
`tests/arch/single_source_sweeps_spec.lua` scopes its table and traceability
guards by `^%d%d%d%d%d%d%-` and silently turns `pending` on any other name.

**Line numbers** are as of `ee0c5f6d` (main after #266). Every enumeration below
carries the query that produced it — **re-run the query before acting on the
table**; if it returns a row the table lacks, correct the table first.

---

## Core concepts

### Pure entities

| Name | Lives in | Status |
|------|----------|--------|
| `state` — `holds`: does a generation still hold a live grant on an entity | `lua/parley/document/state.lua` | modified |
| `previous_answer` — `capture`, `substitute`: the answer value a slot carries, and its substitution into a parsed chat | `lua/parley/previous_answer.lua` | new |
| `attempt` — process lifecycle gains the kill escalation (`escalate` effect, `deadline` event) | `lua/parley/attempt.lua` | modified |
| `refusal` — `describe`, `TOKENS`, `INTERNAL`, `PREFIX`: the submission path's one refusal vocabulary | `lua/parley/refusal.lua` | new |
| `answer_recovery` — on-disk snapshot store | `lua/parley/answer_recovery.lua` | deleted |
| `recovery_paths` — private-directory predicate | `lua/parley/recovery_paths.lua` | deleted |
| `traversal_policy` — private-path exclusion for tool commands | `lua/parley/tools/traversal_policy.lua` | deleted |

*Name cells lead with the module file, which the arch table sweep resolves; the
public functions this issue adds follow in backticks so the sweep's code→table
direction finds them.*

- **`State.holds(state, generation, entity)`** — true when `state.grants` has a
  grant with that generation and entity whose status is not `revoked`.
  `suspended` counts as held: the generation still owns the region and repair
  will re-prove it. It is the one predicate that says whether a `prev_answer`
  slot is still authoritative.
  - **Relationships:** reads `s.grants` (`state.lua:229-235` creates them with
    `generation` and `entity`); N grants : 1 generation.
  - **DRY rationale:** `chat_respond.lua:1556` and others read
    `D.snapshot(doc).grants[id].status`, which copies the whole state. This asks
    the question once, without a copy, on the state's owner.
  - **Tests:** `tests/unit/document_state_spec.lua`, no IO.
  - **ARCH-FUNERAL:** creates nothing.

- **`previous_answer`** — two pure functions.
  - `capture(exchange)` returns `{answer, summary, reasoning}`, deep-copied from
    a parsed exchange. `nil` when the exchange has no answer.
  - `substitute(parsed, entries, skip_index)` returns a copy of `parsed`. For
    each entry `{row, value}`, the exchange whose `question.line_start == row+1`
    (and whose index is not `skip_index`) gets `value.answer`, `value.summary` and
    `value.reasoning`. `answer.line_start` is rebased to that exchange's
    `question.line_end + 1`, because `build_messages` includes an answer only when
    `answer.line_start <= end_index` (`chat_respond.lua:920`). That and `:806`
    (question only) are the only line reads in the projection:
    `grep -n "line_start\|line_end" lua/parley/chat_respond.lua | awk -F: '$1>=732 && $1<=988'`.
    `build_ancestor_messages` reads content only.
  - **Relationships:** 1 value : 1 slot : 1 regenerating exchange.
  - **DRY rationale:** one substitution for both consumers — the same-chat input
    (`start_scoped_response`) and the ancestor chain (`collect_ancestor_chain`).
  - **Future extensions:** if a projection starts reading more line fields,
    `substitute` is the one place that rebases them.
  - **Tests:** `tests/unit/previous_answer_spec.lua`, no IO.
  - **ARCH-FUNERAL:** creates nothing; the value is held by the coordinator slot
    (integration points, below).

- **`attempt` (modified)** — the pure transport lifecycle gains the escalation
  step (M3). Specified in Chunk 3.

- **`refusal`** — pure: `(kind, token, detail) → message` for the submission
  path, where every message names what happened and the action that clears it.
  Specified in Chunk 4.

### Integration points

| Name | Lives in | Status | Wraps |
|------|----------|--------|-------|
| `init` — DocumentCoordinator: `set_previous_answer`, `previous_answers` | `lua/parley/document/init.lua` | modified | per-buffer slot table, cleared with the document |
| `chat_respond` — context capture and ancestor read | `lua/parley/chat_respond.lua` | modified | buffer lines, parent files |
| `helper` — `chat_lines`: a chat's current text, from its loaded buffer if any | `lua/parley/helper.lua` | modified | `nvim_list_bufs`, `readfile` |
| `tasker` — `scope_key`, `stop_scope`: group kill, escalation, deadlines, settling spawns | `lua/parley/tasker.lua` | modified | `uv.spawn`, `uv.kill`, libuv timers |
| `generation_runner` — `stats`; the `stopping` adapter; handle-less ops confirm | `lua/parley/generation_runner.lua` | modified | the runner's effect loop |
| `deferred_work` — `new(step, on_error)`: a failed step settles its owner | `lua/parley/deferred_work.lua` | modified | `vim.defer_fn` |
| `chat_recovery` / `response_recovery` — recovery IO and UI | `lua/parley/chat_recovery.lua`, `lua/parley/response_recovery.lua` | deleted | state dir, pickers |

- **DocumentCoordinator slot** — `s.previous = {}` on the per-document state
  (`document/init.lua:239`), keyed by entity:
  `{generation, value}`.
  - `set_previous_answer(doc, {epoch, entity, generation, value})` accepts only
    when the epoch is current and `State.holds` is true.
  - `previous_answers(doc)` returns `{ {row, value}, … }` for every slot that is
    still valid — `State.holds` true and `Structure.lookup` of the entity
    non-nil, `row = lookup.start_row` — and drops the rest as it goes.
  - Cleared: `finish_generation` for that generation (`M.transition`, after the
    state transition succeeds), and the whole table on reload and detach
    (`init.lua:214-233`).
  - **ARCH-FUNERAL:** at most one slot per live generation, and a document has at
    most 4 (`state.lua:205`). Each slot dies with its generation, and every slot
    dies with the document. Nothing touches disk.
  - **Injected into:** `previous_answer.substitute`, via its `entries`.
- **Context capture** (`chat_respond.lua`) — sets the slot at the top of
  `prepare_input`, before the gap write can delete a byte, and substitutes at
  `start_scoped_response`, in the same tick the command read the buffer (see
  the ARCH-ORDER note for why not in `build()`).
- **`helper.chat_lines(path)`** — returns `lines, buf` from the loaded buffer
  whose resolved absolute name equals `path`, else `readfile(path), nil`.
  It compares resolved names rather than calling `vim.fn.bufnr(path)`, because
  `bufnr` with a string is a file-pattern match and can return a buffer whose
  name only contains the path. It replaces the inline copy at
  `init.lua:3798-3800` (branch-link rewrite), and is used by the ancestor read.

### ARCH-ORDER — the slot's lifecycle

The slot is state held between events that come from outside
`start_scoped_response`: the regenerating generation's progress, a human edit,
reload, detach, and other generations capturing context. Its legal states are
two — **absent** and **held by generation G on entity E** — and its validity is
*derived*, not stored:

| Event | Slot | Why |
|---|---|---|
| G's `prepare_input` runs (answer still intact) | held | set before any gap byte is deleted |
| another request captures context | read | `previous_answers` → substitution |
| G writes its gap, then streams | held | the buffer holds a header or partial text; the slot holds the whole old answer |
| human edit revokes G's grant | read as absent | `State.holds` false; the partial answer is now the transcript's truth |
| G ends — success or failure | removed | `finish_generation`; "both are recorded on the transcript, and that's all" |
| edit deletes E's `💬:` marker | read as absent | `lookup` nil; never matched to another exchange |
| reload / detach | removed | the whole table |

**The event most likely to be mishandled:** a context capture that runs *after*
G ends but reads lines captured *before* it did. Substituting in `build()` would
do exactly that: `build()` runs after readiness and remote fetches
(`chat_respond.lua:1548-1604`), while the lines were read at command time
(`chat_context.lua:49-62`). By then G may have finished and cleared its slot,
leaving the frozen lines holding G's partial answer. So same-chat substitution
happens in `start_scoped_response`, in the tick the lines were read. Ancestors
are read in `build()` (`:1570-1573`), so they substitute there — lines and slots
from the same tick.

**Ordering source:** the scheduler (which deferred step runs first) and human
input. The tests pin it with the explicit `output`/`complete` controls of the
`chat_respond_spec` fixture, one assertion per row of the table.

### ARCH-CONSTRAINTS

- **Workload:** command-time context capture (the user pressed submit). The slot
  lookup is ≤ 4 `lookup` calls; substitution is a deep copy of ≤ 4 answers,
  bounded by the chat size already being copied (`chat_respond.lua:1397`).
- **Kill escalation (M3):** SIGTERM, then SIGKILL after a 2 s grace, then the
  existing 5 s observation window. The grace is an operator-level choice
  (Chunk 3); a stop that takes up to ~2 s to free its slot is not on a
  keystroke path.
- **Refusal messages (M4):** one `logger.warning` per refusal; no new IO.

### ARCH-SECURE

M1 *narrows* the tool surface: tools stop special-casing
`<state_dir>/answer-recovery`. That path held private answer snapshots; after M1
nothing writes there, and existing files are the user's to delete. The tool
resource policy (`root_policy`) still bounds what tools can reach, so the state
directory is reachable only if it is under an allowed root, as any other path.
M2 reads a parent chat from a loaded buffer: the same bytes the user sees, from
the same process, and no new trust boundary. M3 signals process groups Parley
created itself (`detach = true` makes each spawn a group leader), never an
arbitrary pgid. It kills `-pid` only while the attempt record holds that pid and
has not observed its exit, so the pid cannot have been recycled.

### ARCH-MOCK

- **Processes (M3):** the stateful fake is `tasker`'s runtime seam (`M._uv`,
  `record.runtime`). The fake gains a process-group model, where a group is a
  set of pids that each exit on a signal they do not ignore, and every pipe a
  group member holds closes only when all holders exit. A live conformance spec
  spawns a real `sh` that ignores TERM and leaves a grandchild holding stdout,
  then asserts that a real stop resolves it (Chunk 3).
- **Provider transport:** the `chat_respond_spec` dispatcher fixture
  (`tests/integration/chat_respond_spec.lua:66-90`) is the existing stateful
  double. M1, M2 and M4 reuse it.

---

## Chunk 1: M1 — delete the on-disk answer-recovery store

### Task 1.1: The #261 regression, red on main

**Files:**
- Modify: `tests/integration/chat_respond_spec.lua` — replace the two recovery
  tests at `:124-157`.

The fixture already exists in that `describe` (`:66-123`: `open`, `submit`,
`output`, `complete`, and a stateful dispatcher whose `stop_owner` aborts).

- [ ] **Step 1: Write the three failing tests.** Replace `'cleans recovery only
  after the chat deletion is confirmed'` and `'refuses answer replacement when
  recovery publication is unavailable'` with:

```lua
    -- #261: the reported blocker. Regenerate, edit the answer while it streams
    -- (the edit revokes the generation), then regenerate again. Before #261 the
    -- retained on-disk snapshot said "original" while the buffer held the
    -- partial answer, and every retry was refused — surviving quit and reopen.
    local function row_containing(needle)
        for index,line in ipairs(vim.api.nvim_buf_get_lines(buf,0,-1,false))do
            if line:find(needle,1,true) then return index end
        end
    end
    local function regenerate_then_revoke()
        open({'💬: question','','🤖: original','valuable answer',''})
        local first=submit()
        output(calls[1],'partial new text')
        wait_for(function()return buffer_contains(buf,'partial new text')end)
        -- Where the text lands relative to the answer header is the layout's
        -- business; the edit only has to fall inside the granted output.
        local row=assert(row_containing('partial new text'))
        vim.api.nvim_buf_set_text(buf,row-1,0,row-1,0,{'edited '})
        wait_for(function()return Respond.response_snapshot(first).status=='terminal'end)
        assert.equals('revoked',Respond.response_snapshot(first).generation.outcome)
    end
    it('regenerates after an edit revoked the previous regeneration (#261)',function()
        regenerate_then_revoke()
        vim.api.nvim_win_set_cursor(0,{5,0})
        submit()
        wait_for(function()return #calls==2 end)
    end)
    it('regenerates after a revoked regeneration and a reload (#261)',function()
        regenerate_then_revoke()
        local path=vim.api.nvim_buf_get_name(buf);files[#files+1]=path
        vim.cmd('silent write!');vim.cmd('edit!')
        vim.api.nvim_win_set_cursor(0,{5,0})
        submit()
        wait_for(function()return #calls==2 end)
    end)
    it('regenerates regardless of a legacy answer-recovery directory (#261)',function()
        local legacy=parley.config.state_dir..'/answer-recovery'
        vim.fn.mkdir(legacy,'p');vim.uv.fs_chmod(legacy,tonumber('755',8))
        vim.fn.writefile({'not json'},legacy..'/0.1.json')
        open({'💬: question','','🤖: original','valuable answer',''})
        submit()
        wait_for(function()return #calls==1 end)
        vim.fn.delete(legacy,'rf')
    end)
```

- [ ] **Step 2: Run them on main and confirm each fails for the reason it
  names.**

Run: `make test-spec SPEC=chat/lifecycle` (or `nvim --headless … PlenaryBustedFile tests/integration/chat_respond_spec.lua` per TOOLING.md)
Expected: all three FAIL. The first two time out on `#calls==2` with a
`Response not started: Answer recovery unavailable: retained recovery requires
inspection or explicit restore` warning. The third times out on `#calls==1`
(directory mode is not 0700). If any passes on main, the test does not reproduce
the report — stop and fix the test before going on (lessons: "a
characterization test needs its counterfactual run").

- [ ] **Step 3: Commit the red tests.**

```bash
git add tests/integration/chat_respond_spec.lua
git commit -m "#261 M1: the reported blocker, as three failing tests"
```

### Task 1.2: Delete the subsystem and its hooks

The removal map. Re-run before editing:

```bash
grep -rnE 'answer_recovery|chat_recovery|response_recovery|recovery_paths|answer-recovery|AnswerRecovery|AnswerRestore|fake_recovery_filesystem|private_directory|private_recovery|traversal_policy' lua tests atlas README.md
```

It must return only these rows. The unrelated #197 auth retry
(`cliproxy_recovery_e2e_spec.lua`, `recovery_timeout_ms`) does not match it.

| Site | Action |
|---|---|
| `lua/parley/answer_recovery.lua`, `chat_recovery.lua`, `response_recovery.lua`, `recovery_paths.lua` | delete |
| `lua/parley/init.lua:1600-1605` `M.cmd.AnswerRecovery`/`AnswerRestore` | delete (the registration loop at `:1317-1330` derives commands from `M.cmd`) |
| `lua/parley/init.lua:3694-3699` recovery cleanup in `delete_chat_file` | delete |
| `lua/parley/chat_respond.lua:1448` `local recovery` | delete |
| `chat_respond.lua:1535` `self.unproved` cancel branch, `:1551-1564` suspended-grant wait | delete — they exist only because the snapshot read the live answer (commit `bb620943`) |
| `chat_respond.lua:1582-1595` start/publish | delete |
| `chat_respond.lua:1673-1688` `finalize` | becomes `local completion=require('parley.response_completion').start(doc,ctx,done,{user_prefix=config.chat_user_prefix}); return {cancel=function(_,resolved) if completion then completion:cancel() end; if resolved then resolved() end end}` |
| `chat_respond.lua:1692`, `:1711` `Recovery.finish` | delete |
| `chat_respond.lua:1639` `state_dir = config.state_dir` | delete |
| `response_session.lua:92`, `response_tools.lua:111`, `tools/producer.lua:98`, `skill_invoke.lua:397` `state_dir=` | delete the field |

- [ ] **Step 1:** Delete the four modules and apply the table above.
- [ ] **Step 2:** `replacing_answer` (`chat_respond.lua:1402`) loses its uses at
  `:1556` and `:1582`. Keep it: M2 uses it. Until then, `luacheck` may flag it as
  unused; if so, add M2's `previous_answer.capture` call in this task rather than
  a suppression.
- [ ] **Step 3: Run the Task 1.1 tests.** Expected: all three PASS.
- [ ] **Step 4: Commit.**

```bash
git commit -am "#261 M1: delete the on-disk answer-recovery store

Regenerating an answer required a successful write to a private directory,
with no fallback. A retained snapshot that disagreed with the buffer refused
every retry, across quit and reopen. The target makes the file the only
authority; undo is the way back to a replaced answer.

Co-Authored-By: Claude Opus 5 (1M context) <noreply@anthropic.com>"
```

### Task 1.3: Delete the privacy carve-out from the tools layer

It existed only to hide the store from tools.

| Site | Action |
|---|---|
| `lua/parley/helper.lua:10-16` `private_recovery_path` and its uses at `:371`, `:433`, `:471` | delete (`:471` keeps its `isdirectory` filter) |
| `lua/parley/tools/dispatcher.lua:219` | delete the `private_directory` branch |
| `tools/dispatcher.lua:353-354` | delete (the only reader of `opts.state_dir` there) |
| `tools/dispatcher.lua:361` | drop the `private_directory` conjunct |
| `tools/dispatcher.lua:367` | drop `private_directory=` from `options` |
| `tools/dispatcher.lua:457` | delete the branch |
| `tools/async_builtin.lua:29` | drop `private_directory=` |
| `tools/async_builtin.lua:126-143` | remove `policy.apply`; run `command` / `plan.command` unchanged (the policy returned them unchanged when `private` was nil) |
| `tools/filesystem.lua:317-319, 332-333` | drop `spec.private_directory` validation and the `'private'` failure |
| `lua/parley/tools/traversal_policy.lua`, `tests/unit/tool_traversal_policy_spec.lua` | delete |

- [ ] **Step 1:** Apply the table.
- [ ] **Step 2: Remove the tests of the carve-out** (they assert a behaviour that
  no longer exists):
  - `tests/integration/tool_process_scope_spec.lua`: the `run()` helper at
    `:10-15` stops applying the policy; delete the cases at `:95-105`,
    `:122-133`, `:135-151`, `:153-162`, `:164-173`.
  - `tests/integration/async_builtin_spec.lua:101-120`.
  - `tests/integration/tool_dispatch_capture_spec.lua:95-105`.
  - `tests/unit/tool_process_scope_spec.lua:36-41`.
- [ ] **Step 3:** Delete `tests/integration/{answer_recovery,chat_recovery,response_recovery,recovery_paths}_spec.lua`
  and `tests/helpers/fake_recovery_filesystem.lua`.
- [ ] **Step 4:** `tests/integration/batch_lifecycle_spec.lua`: remove
  `:30` (reset of `chat_recovery.settle`), `:43-45` (comment), `:60`
  (`chat_recovery.list` assertion), and the three recovery cases `:65-86`,
  `:88-95`, `:97-116`. **Check each case's non-recovery assertions first:** if a
  case also pins batch behaviour (retry after failure/cancel), keep it with
  the recovery lines removed, rather than deleting it.
- [ ] **Step 5: Run the removal query from Task 1.2.** Expected: no output.
- [ ] **Step 6: Run the tool and batch specs.**

Run: `make test-spec SPEC=providers/tool_execution` and `make test-spec SPEC=chat/batch`
Expected: PASS.

- [ ] **Step 7: Commit** (`#261 M1: tools stop special-casing the recovery directory`).

### Task 1.4: Guard — a sidecar under the state directory declares why it cannot block

The failure this target exists to prevent was a sidecar becoming a
precondition. A rule in prose does not stop the next one (lessons, #263 round 4),
so the deliverable is an assertion.

**Files:**
- Create: `tests/arch/sidecar_authority_spec.lua`
- Modify: `atlas/traceability.yaml` (route the spec under `infra/…` next to the
  other arch specs — follow where `tests/arch/single_resolver_spec.lua` is routed)

- [ ] **Step 1: Verify each declaration's claim before writing it.** Read each
  reader and confirm what happens when its file is missing, corrupt, or
  unwritable. The expected answers, from the audit, are below; **correct any
  that the code contradicts, and if a reader can refuse a submission, stop and
  raise it** — that is a new instance of this issue's violation.

  Query: `git grep -n -e state_dir -- lua/`

- [ ] **Step 2: Write the spec.**

```lua
-- Target transcript-is-the-whole-truth (#261). The answer-recovery store was a
-- sidecar under the profile state directory that became a precondition for
-- regenerating an answer. This spec makes every reader of that directory say,
-- here, what its absence degrades to. A new reader fails until it is declared,
-- and declaring it means writing down why it cannot block a submission.
local DECLARED = {
    ["lua/parley/init.lua"] = "state.json (last chat, agent, toggles): missing or corrupt resets to defaults",
    ["lua/parley/vault.lua"] = "vault_state.json: missing re-reads the secret source",
    ["lua/parley/custom_prompts.lua"] = "custom_system_prompts.json: missing means no custom prompts",
    ["lua/parley/chat_respond.lua"] = "remote_reference_cache.json: a miss re-fetches the reference",
    ["lua/parley/config.lua"] = "defines the default path; reads nothing",
    ["lua/parley/starter_config.lua"] = "defines the starter path; reads nothing",
}

describe("arch: sidecars never gate the transcript", function()
    local hits = vim.fn.systemlist("git grep -l -e state_dir -- lua/")

    it("lists readers", function()
        assert.equals(0, vim.v.shell_error)
        assert.is_true(#hits > 0, "the query found nothing; it is not reading what it claims")
    end)

    it("declares every reader of the state directory", function()
        local undeclared = {}
        for _, file in ipairs(hits) do
            if not DECLARED[file] then undeclared[#undeclared + 1] = file end
        end
        assert.same({}, undeclared,
            "a new state_dir reader: declare it here with why its absence cannot block a submission")
    end)

    it("declares nothing that no longer reads it", function()
        local found, stale = {}, {}
        for _, file in ipairs(hits) do found[file] = true end
        for file in pairs(DECLARED) do
            if not found[file] then stale[#stale + 1] = file end
        end
        table.sort(stale)
        assert.same({}, stale, "remove declarations for files that no longer read state_dir")
    end)
end)
```

- [ ] **Step 3: Counterfactual.** Add `local _ = config.state_dir` to
  `lua/parley/chat_presentation.lua` (confirm it is clean first:
  `git diff --quiet -- lua/parley/chat_presentation.lua`), run the spec, and
  watch "declares every reader" fail. Then `git checkout -- lua/parley/chat_presentation.lua`.
- [ ] **Step 4: Run it.** Expected: PASS.
- [ ] **Step 5: Commit** (`#261 M1: a state_dir reader must declare why it cannot block`).

### Task 1.5: Documentation for M1

- [ ] Delete `atlas/chat/recovery.md`, and remove its entry from `atlas/index.md:19`.
- [ ] `atlas/traceability.yaml`: delete the `chat/recovery:` block (`:349-358`),
  `recovery_paths.lua` (`:809`), `traversal_policy.lua` (`:818`) and
  `tool_traversal_policy_spec.lua` (`:843`).
- [ ] `atlas/providers/tool_execution.md`: remove the private-directory text at
  `:11-12`, `:47`, `:142-147`, `:203-204`, `:237-241`. The section
  "## Bounds and private data" (`:120`) keeps its bounds content.
- [ ] `README.md:82-84`: remove the answer-recovery sentence. The way back to a
  replaced answer is `u` (native undo), and with `undofile` set, it survives
  reopening. Say that in the lifecycle page (next item), not in the README.
- [ ] `atlas/chat/lifecycle.md`: under the Response section, one paragraph:
  regenerating replaces the answer in the buffer, `u` restores it, and nothing is
  kept on disk.
- [ ] `tests/manual/chat-concurrency.md:61-73`: drop recovery items 3-5; rename the
  section "Batch".
- [ ] Target `workshop/targets/transcript-is-the-whole-truth.md`: append a
  `## Revisions` entry. The open question "What bounds the in-session memory
  that replaces durable recovery?" is answered: none is kept. The only held copy
  is `prev_answer`, whose lifetime is one generation (M2).
- [ ] Commit (`#261 M1: atlas — the recovery store is gone`).

### Task 1.6: M1 boundary

- [ ] `make test` — full suite green. Compare any failure against `main` before
  touching it (lessons: "N failures, one cause is a hypothesis").
- [ ] `make lint`.
- [ ] `sdlc milestone-close --issue 261 --milestone M1`, and fix
  Critical/Important findings before M2. Log the verdict in the issue's `## Log`.

---

## Chunk 2: M2 — `prev_answer` (#255)

### Task 2.1: `State.holds`

**Files:**
- Modify: `lua/parley/document/state.lua` (next to `M.turn`)
- Test: `tests/unit/document_state_spec.lua`

- [ ] **Step 1: Failing tests.**

```lua
    describe('holds',function()
        local function held()
            local s=State.new({epoch='e'})
            local g=State.transition(s,{kind='register_generation',input_snapshot={}}).generation
            local r=State.transition(s,{kind='acquire',generation=g,
                regions={{entity='E',first=0,last=4,marker_revision=1,revision=1,confirmed=true}}})
            return s,g,r.grants[1]
        end
        it('is true for a live grant of that generation on that entity',function()
            local s,g=held(); assert.is_true(State.holds(s,g,'E'))
        end)
        it('is false for another entity or generation',function()
            local s,g=held()
            assert.is_false(State.holds(s,g,'F')); assert.is_false(State.holds(s,g..'x','E'))
        end)
        it('is false once the grant is revoked',function()
            local s,g,gid=held(); State.transition(s,{kind='revoke',grant=gid})
            assert.is_false(State.holds(s,g,'E'))
        end)
        it('is false once the generation finished',function()
            local s,g=held(); State.transition(s,{kind='finish_generation',generation=g})
            assert.is_false(State.holds(s,g,'E'))
        end)
        it('stays true while the grant is suspended',function()
            local s,g,gid=held(); s.grants[gid].status='suspended'
            assert.is_true(State.holds(s,g,'E'))
        end)
    end)
```

  (Match `proof`'s required region fields to what `state.lua`'s `proof()`
  accepts; the snippet uses the shape `generation_runner.lua:583-586` builds.)

- [ ] **Step 2:** Run it: FAIL (`holds` is nil).
- [ ] **Step 3: Implement.**

```lua
--- Does `generation` still hold a live grant on `entity`? Suspended counts:
--- the region is still its own, pending re-proof. The one question a
--- `prev_answer` slot asks of authority (#261, #255).
function M.holds(s,generation,entity)
    for _,g in pairs(s.grants) do
        if g.generation==generation and g.entity==entity and g.status~='revoked' then return true end
    end
    return false
end
```

- [ ] **Step 4:** Run: PASS. **Step 5:** Commit (`#261 M2: State.holds`).

### Task 2.2: `previous_answer.capture` / `substitute`

**Files:**
- Create: `lua/parley/previous_answer.lua`
- Test: `tests/unit/previous_answer_spec.lua`
- Modify: `atlas/traceability.yaml` (route the spec under `chat/lifecycle`)

- [ ] **Step 1: Failing tests** — table-driven over a parsed chat built with the
  helpers in `tests/unit/build_messages_spec.lua:53-81` (`exchange()`,
  `parsed_chat()`; lift them to `tests/helpers/parsed_chat.lua` if a second spec
  needs them, not a copy):
  - an entry at Q1's row replaces Q1's answer, summary and reasoning, and leaves
    Q2 untouched;
  - `skip_index` is never substituted, even with a matching entry;
  - an entry whose row matches no question changes nothing;
  - the substituted `answer.line_start` equals `question.line_end + 1`, and with
    an `end_index` equal to that line, `build_messages` includes it (the one
    line read the projection makes);
  - the input `parsed` is not mutated (compare against a deep copy);
  - `capture` of an exchange without an answer returns `nil`; `capture` deep-copies
    (mutating the result leaves the source intact).
- [ ] **Step 2:** Run: FAIL.
- [ ] **Step 3: Implement.**

```lua
-- The previous answer of an exchange being regenerated (#261, #255), and its
-- substitution into a parsed chat for request context. Pure: the document
-- coordinator holds the value (`document/init.lua` set_previous_answer) and
-- decides whether it is still valid; this module only shapes and applies it.
local M={}

--- The value a slot carries: what request context reads of an exchange's answer.
function M.capture(exchange)
    if not exchange or not exchange.answer then return nil end
    return {answer=vim.deepcopy(exchange.answer),summary=vim.deepcopy(exchange.summary),
        reasoning=vim.deepcopy(exchange.reasoning)}
end

--- A copy of `parsed` in which each entry's exchange carries its previous answer.
--- `entries` are `{row=<0-based 💬: row>, value=<capture()>}`; `skip_index` is the
--- exchange being answered, whose own answer is never part of its input.
function M.substitute(parsed,entries,skip_index)
    if not entries or #entries==0 then return parsed end
    local by_line={}
    for _,entry in ipairs(entries) do by_line[entry.row+1]=entry.value end
    local out=vim.deepcopy(parsed)
    for index,exchange in ipairs(out.exchanges) do
        local value=exchange.question and by_line[exchange.question.line_start]
        if value and index~=skip_index then
            exchange.answer=vim.deepcopy(value.answer)
            -- build_messages includes an answer only when answer.line_start <=
            -- end_index (chat_respond.lua:920); the old answer's own line numbers
            -- belong to a transcript that no longer exists.
            exchange.answer.line_start=exchange.question.line_end+1
            exchange.summary=vim.deepcopy(value.summary)
            exchange.reasoning=vim.deepcopy(value.reasoning)
        end
    end
    return out
end

return M
```

- [ ] **Step 4:** Run: PASS. **Step 5:** Commit (`#261 M2: previous_answer capture and substitute`).

### Task 2.3: The coordinator slot

**Files:**
- Modify: `lua/parley/document/init.lua` — `s.previous={}` in `M.attach`
  (`:239`); reset in the reload branch (`:214-223`) and the detach branch
  (`:224-233`); in `M.transition` (`:312-338`), after a successful
  `finish_generation`, drop that generation's slots; add the two functions below.
- Test: `tests/integration/document_previous_answer_spec.lua` (setup as in
  `tests/integration/document_turn_wake_spec.lua:11-26`: `Fake.new`,
  `D.attach(nextbuf,{driver=…,schedule=false})`, `D.drain`, `register`).
- Modify: `atlas/traceability.yaml` (route under `chat/document`).

- [ ] **Step 1: Failing tests** — one per row of the ARCH-ORDER table that the
  coordinator owns:
  - set with a live grant → `previous_answers` returns `{row, value}` for the
    entity's `💬:` row;
  - set without a grant (never acquired, or stale epoch) → refused, nothing
    listed;
  - revoke the grant → nothing listed;
  - `finish_generation` → nothing listed, and the slot is gone from the table
    (not just filtered — assert via a second `set` for a new generation on the
    same entity succeeding with the new value);
  - an edit that deletes the `💬:` marker → nothing listed;
  - reload and detach → nothing listed;
  - two generations on two entities → both listed, each with its own value.
- [ ] **Step 2:** Run: FAIL.
- [ ] **Step 3: Implement.**

```lua
--- #261/#255: the answer a regeneration is replacing, kept beside the index
--- (which stores no transcript text) for request context only. Valid while the
--- regenerating generation holds a live grant on the exchange; see
--- previous_answers for the read-time check and the ARCH-ORDER table in
--- workshop/plans/000261-*-plan.md for the lifecycle.
function M.set_previous_answer(doc,spec)
    local s=state(doc)
    if s.dead or type(spec)~='table' or spec.epoch~=s.epoch or spec.value==nil
        or not State.holds(s.authority,spec.generation,spec.entity) then return false end
    s.previous[spec.entity]={generation=spec.generation,value=spec.value}
    return true
end
--- Every still-valid slot as `{row=<0-based 💬: row>, value=…}`; drops the rest.
function M.previous_answers(doc)
    local s=state(doc); local out={}
    if s.dead then return out end
    for entity,slot in pairs(s.previous) do
        local marker=State.holds(s.authority,slot.generation,entity) and Structure.lookup(s.structure,entity)
        if marker then out[#out+1]={row=marker.start_row,value=slot.value}
        else s.previous[entity]=nil end
    end
    return out
end
```

  In `M.transition`, after `local result=effects(…)`:

```lua
    if event.kind=='finish_generation' and result.ok then
        for entity,slot in pairs(s.previous) do
            if slot.generation==event.generation then s.previous[entity]=nil end
        end
    end
```

  (`Structure.lookup` is what `M.lookup` calls through `measured_query`; use
  `M.lookup(doc,entity)` if the measured path is required for budget
  accounting.)
- [ ] **Step 4:** Run: PASS. **Step 5:** Commit (`#261 M2: the coordinator's prev_answer slot`).

### Task 2.4: Set the slot and substitute it in the same chat

**Files:**
- Modify: `lua/parley/chat_respond.lua` `start_scoped_response` (`:1391-1722`)
- Test: `tests/integration/chat_respond_spec.lua` (the scoped-session `describe`)

- [ ] **Step 1: Failing tests** (the payload is recorded on `calls[i].payload`):
  - **before Q1 emits:** `open` with Q1 answered (`'old one'`), Q2 unanswered.
    Regenerate Q1 (cursor on Q1). Then put the cursor on Q2 and submit. Assert
    `calls[2].payload` contains `old one`.
  - **mid-stream:** as above, but `output(calls[1],'new partial')` and wait for it
    in the buffer before submitting Q2. Assert `calls[2].payload` contains
    `old one` and **not** `new partial`.
  - **after Q1 completes:** `complete(first,calls[1])` with output `'new one'`,
    then submit Q2. Assert it contains `new one`, not `old one`.
  - **after Q1 is revoked:** output `'new partial'`, edit it (revoke), then submit
    Q2. Assert it contains `edited new partial` — the transcript's truth.
  - **already captured:** submit Q2 mid-stream, then complete Q1. Assert
    `calls[2].payload` (captured before) still contains `old one`.
  - **two refreshes:** Q1 and Q2 both answered and both regenerating, Q3 asked.
    Assert Q3's payload holds both old answers in order.
  - **multi-slice gap:** an old answer over 8 KiB (more than two 4 KiB slices).
    Submit Q2 after the first `replace_step` but before the gap completes. Assert
    the payload holds the whole old answer. This is the truncation window the
    digest found (`replacement.lua:157-165`); drive it with a `schedule=false`
    step or by waiting on the buffer shrinking, whichever the fixture supports.
- [ ] **Step 2:** Run: FAIL (Q2 sees `new partial` / a header / a truncated answer).
- [ ] **Step 3: Implement.**
  1. Move `local doc = D.get(buf) or D.attach(…)` (`:1443`) above the
     `exchange.answer = nil` line (`:1432`).
  2. Right after it, substitute the other exchanges, in this tick:

```lua
    -- #261/#255: an earlier exchange still being regenerated contributes its
    -- previous answer, not the header or partial text now in the buffer. Done
    -- here, in the tick the command read the lines — build() runs later, after
    -- readiness and remote fetches, when that generation may have finished.
    local PrevAnswer = require('parley.previous_answer')
    parsed = PrevAnswer.substitute(parsed, D.previous_answers(doc), index)
    exchange = parsed.exchanges[index]
```

  3. Capture this exchange's own answer from the command-time parse (the grant
     guarantees these are the bytes the gap will remove):
     `local previous = replacing_answer and PrevAnswer.capture(frame.parsed.exchanges[index]) or nil`.
  4. At the top of `prepare_input(ctx, cb)`, before anything can write:

```lua
        if previous then
            D.set_previous_answer(doc, {epoch = ctx.epoch, entity = ctx.entity,
                generation = ctx.generation, value = previous})
        end
```

- [ ] **Step 4:** Run: PASS. **Counterfactual:** comment out the `substitute`
  line, confirm the mid-stream test fails, and restore it.
- [ ] **Step 5:** Commit (`#261 M2: a regenerating answer's predecessor feeds context`).

### Task 2.5: Ancestors from the live buffer

**Files:**
- Modify: `lua/parley/helper.lua` (add `chat_lines`), `lua/parley/init.lua:3798-3800`
  (consume it), `lua/parley/chat_respond.lua:176-221` (`collect_ancestor_chain`)
- Test: `tests/integration/chat_respond_spec.lua`, plus a unit case in
  `tests/unit/helper_spec.lua` (or the file that tests `helper.lua` — find it with
  `grep -rln "parley.helper" tests/unit`)

- [ ] **Step 1: Failing tests.**
  - `chat_lines`: a loaded buffer whose unsaved text differs from disk returns
    the buffer's lines and its number. An unloaded path returns disk and `nil`.
    A buffer whose name only *contains* the path is not matched.
  - **Sub-chat, parent regenerating:** parent P has Q1 (`'old one'`) and a
    branch link to child C. Regenerate P's Q1 and stream `'new partial'` (P
    stays loaded, and on disk still holds whatever autosave wrote). In C, ask a
    question. Assert C's payload contains `old one` and not `new partial`.
  - **Sub-chat, parent unsaved:** P loaded with an unsaved edit to Q1's answer,
    and no generation. Assert C's payload holds the edited text. The live buffer
    is the truth, not the disk.
- [ ] **Step 2:** Run: FAIL.
- [ ] **Step 3: Implement.**

```lua
--- A chat's current text: its loaded buffer if one is open under this exact
--- path, else the file. Compares resolved absolute names — `bufnr(path)` is a
--- file-pattern match and can return a buffer whose name merely contains it.
function _H.chat_lines(path)
    local want = vim.fn.resolve(vim.fn.fnamemodify(path, ':p'))
    for _, buf in ipairs(vim.api.nvim_list_bufs()) do
        if vim.api.nvim_buf_is_loaded(buf) then
            local name = vim.api.nvim_buf_get_name(buf)
            if name ~= '' and vim.fn.resolve(vim.fn.fnamemodify(name, ':p')) == want then
                return vim.api.nvim_buf_get_lines(buf, 0, -1, false), buf
            end
        end
    end
    return vim.fn.readfile(path), nil
end
```

  (Match helper.lua's export alias — it exports through `_H.`.)

  In `collect_ancestor_chain`, replace `local parent_lines = vim.fn.readfile(abs_parent)`
  with `local parent_lines, parent_buf = _parley.helpers.chat_lines(abs_parent)`,
  and after `parent_parsed` is built:

```lua
    local parent_doc = parent_buf and require('parley.document').get(parent_buf)
    if parent_doc then
        parent_parsed = require('parley.previous_answer').substitute(parent_parsed,
            require('parley.document').previous_answers(parent_doc), nil)
    end
```

  At `init.lua:3798-3800`, replace the inline live-buffer check with
  `local lines = M.helpers.chat_lines(new_path)`.
- [ ] **Step 4:** Run: PASS. **Counterfactual:** revert `chat_lines` to
  `readfile` only, and confirm the unsaved-parent test fails.
- [ ] **Step 5:** Commit (`#261 M2: ancestors read the parent's live buffer`).

### Task 2.6: Documentation for M2 and the #255 fold

- [ ] `atlas/chat/lifecycle.md` (Response section): a short "Previous answer
  while regenerating" paragraph. It covers the slot lifetime, same-chat and
  ancestor substitution, "any outcome ends it", and a pointer to the ARCH-ORDER
  table in this plan for the event list. State it once here; `ownership.md`
  links to it and does not restate it.
- [ ] `atlas/chat/document.md` "Ownership and data flow": one sentence that the
  coordinator holds `prev_answer` beside the index, which still stores no
  transcript text.
- [ ] `atlas/context/…`: find the page that documents ancestor context
  (`grep -rln "ancestor" atlas/`), and note that a loaded parent is read from
  its buffer.
- [ ] `atlas/traceability.yaml`: `lua/parley/previous_answer.lua` under
  `chat/lifecycle`.
- [ ] Commit (`#261 M2: atlas — prev_answer and live ancestors`).

### Task 2.7: M2 boundary

- [ ] `make test`, `make lint`.
- [ ] `sdlc milestone-close --issue 261 --milestone M2`; log the verdict.

---

## Chunk 3: M3 — processes die for certain

Operator: *"we need to have 100% confidence we can kill what we started"* and
*"regarding 'kernel hold', it's fine."* M3 makes the kill certain; M4 makes
every wait settle. Only together do the admission counters drain.

### What is broken today (verified 2026-09-18)

- **Children are not in their own process group.** `tasker.lua:475` passes
  `detach = true`, but luv's key is `detached` (`luvref.txt`, `uv.spawn`
  options). It was measured with a real spawn: under `detach` the child's pgid
  is nvim's; under `detached` it is its own pid. `cliproxy.lua:667` spells it
  correctly. **Consequence:** today `kill(-pid)` returns ESRCH, and signalling
  the child's pgid would signal nvim. The group kill must not ship before the
  key is fixed.
- **Stop is one SIGTERM to one pid.** `stop_matching` (`tasker.lua:263-289`)
  sends signal 15 to the positive pid. `reconcile_step` (`:202-221`) only probes
  with signal 0. There is no SIGKILL anywhere in `lua/`. After 5 s the record and
  its admission slot are retained forever (`:213-216`).
- **Resolution needs exit plus both EOFs** (`attempt.lua:10-16`). A grandchild
  holding a pipe (`sh -c` → `rg`) keeps a record unresolved after its parent
  exits (`tasker.lua:462-464`).
- **An ESRCH race raises.** `scoped_stop` (`:295-299`) raises "task transport
  stop failed" when a kill finds the process already gone. The callers, the
  provider cancel and the topic cancel, then skip their remaining cleanup.
- **19 spawns have no owner and no end.** `grep -rn "tasker\.run(nil" lua/parley`
  → `vault.lua:121,206`, and 17 in `oauth.lua`. None is ever signalled and none
  has a deadline, yet each counts against the process-wide total (32).
- **A refused spawn without `on_start_error` never calls back.** `tasker.run`
  calls `reject(message)`, which calls only `on_start_error`
  (`tasker.lua:379-386`).
- **The fake cannot see any of this.** `tests/helpers/fake_process.lua` ignores
  spawn options and has no group model, so `kill(-pid)` there is ESRCH.

### The model

- **A generation is a process scope.** Its key is `<epoch>:<generation>`. The
  provider (`response_provider.lua:102`) and the tool scheduler
  (`tools/producer.lua:120`) already build it, as two separate spellings; M3
  makes it one function, `tasker.scope_key(epoch, generation)`.
- **Stop kills a scope as groups.** SIGTERM to `-pid` for each live record in
  the scope; then, after a 2 s grace, SIGKILL to `-pid` for each one not yet
  exited. The existing observation window (5 s from the stop) stays. A record
  still unresolved at its end survived SIGKILL — a kernel hold — and stays
  counted, is logged with its pid, and is named by M5's refusal. The operator
  accepted this.
- **Every process has an end.** A run with a scope dies with it. A run without
  one (a shared helper: a vault secret, a token refresh, an OAuth call) gets a
  deadline — default 120 s — after which the tasker kills its group the same
  way. `tasker.run` refuses a spawn with neither.
- **Every run settles.** When `on_start_error` is absent, a refused spawn is
  delivered through the exit callback as `callback(nil, nil, nil, nil, reason)`.
  Existing callers test `code ~= 0`, which a nil code satisfies.
- **Neovim exit kills everything left.** Once children lead their own groups,
  they no longer share nvim's fate, so a `VimLeavePre` autocmd SIGKILLs every
  live group. The residual is **nvim itself crashing**: then the orphans run to
  their own end (a provider stream to its server's close, a tool to
  completion). No autocmd runs on a crash; this is stated here so it is not
  mistaken for a guarantee.

### ARCH-FUNERAL (M3)

Creates nothing durable. Each tasker record now names its end: its scope's stop,
its deadline, or `VimLeavePre`. A kernel-held record is the one that outlives
all three; it is bounded by the global process limits it still counts against.

### ARCH-ORDER — the attempt lifecycle

`attempt.lua` gains one event and one effect. The rest is unchanged.

| State | Event | Next | Effect |
|---|---|---|---|
| live | `stop_requested(now)` | stopping (`kill_due = now+2000`) | SIGTERM `-pid` (tasker) |
| stopping | `reconcile_tick(now ≥ kill_due)`, not exited | stopping (`escalated`) | **`escalate`** → SIGKILL `-pid`, once |
| stopping | `exit` + both EOFs | resolved | release slot |
| stopping | `reconcile_tick(now ≥ started+5000)` | unresolved-visible | log with pid, `on_unresolved` |
| live | `deadline(now)` (unscoped run) | as `stop_requested` | as above |

**Most likely to be mishandled:** a process that exits *between* the TERM and
the KILL, whose pid is then recycled. The escalation must fire only while the
record has not observed `exit` (`not state.exited`). The group was created by
this spawn, and its leader's exit has not been reaped, so the pgid cannot yet
be reused.

### Task 3.1: The fake models groups, and tasker's spawn key

**Files:**
- Modify: `tests/helpers/fake_process.lua`
- Modify: `lua/parley/tasker.lua:470-476`
- Test: `tests/unit/tasker_unit_spec.lua`

- [ ] **Step 1: Extend the fake** so it can tell right from wrong. Add these,
  and keep every existing option:
  - `spawn_opts.detached == true` puts the child in its own group
    (`pgid = pid`); otherwise `pgid = 0`, standing in for nvim's group.
  - `kill(-pgid, sig)` signals every process in that group. `kill(-0, …)` raises
    `"signalled nvim's own group"`, so a wrong group kill fails loudly.
  - Per process `ignores = {[15]=true}`. A non-ignored signal exits it.
  - `process:fork()` creates a grandchild in the same group that holds the same
    stdout/stderr. A pipe's EOF is delivered only when every holder has exited.
  - Unknown spawn option keys are recorded in `state.unknown_spawn_options`.
- [ ] **Step 2: Failing test** — `tasker.run` with the fake spawns with
  `detached=true` and records no unknown key.
- [ ] **Step 3:** Change `detach = true` to `detached = true`. Run: PASS.
- [ ] **Step 4:** Commit (`#261 M3: children lead their own process group`).

### Task 3.2: Escalation in the pure lifecycle

**Files:** `lua/parley/attempt.lua`; test `tests/unit/attempt_spec.lua`.

- [ ] **Step 1: Failing tests.**
  - `stop_requested` at t sets `kill_due = t+2000`.
  - `reconcile_tick` at t+1999: no `escalate` effect. At t+2000, when not exited:
    `escalate = true`, exactly once. A second tick at t+2100 gives none.
  - An exit at t+1000: no `escalate` at t+2000.
  - `unresolved` at t+5000 is unchanged.
  - The `deadline` event behaves as `stop_requested`.
- [ ] **Step 2:** Run: FAIL. **Step 3:** Implement the rows of the table above,
  returning `escalate` in the effects table next to `probe` and `unresolved`.
- [ ] **Step 4:** Run: PASS. **Step 5:** Commit (`#261 M3: the attempt lifecycle escalates`).

### Task 3.3: Group kill, scopes, deadlines, settling spawns

**Files:** `lua/parley/tasker.lua`; `lua/parley/response_provider.lua:102` and
`lua/parley/tools/producer.lua:120` (consume `scope_key`); tests
`tests/integration/tasker_supervision_spec.lua`, `tests/unit/tasker_unit_spec.lua`.

- [ ] **Step 1: Failing sequence tests** on the fake. Each asserts the record is
  gone and `tasker.stats().active` is back to its baseline.
  1. A process that ignores TERM → stop → no exit → at 2 s SIGKILL `-pid` →
     resolved.
  2. A parent exits on TERM but a forked grandchild holds stdout → the group
     TERM ends both → resolved (before the fix, only the parent died).
  3. The process exits between TERM and KILL → no SIGKILL is sent.
  4. The process is already gone when stop runs (ESRCH) → no raise; recorded as
     missing.
  5. `stop_scope(k)` signals every record whose `logical_generation == k`, and
     no other.
  6. An unscoped run with no `deadline_ms` gets the 120 s default; at the
     deadline it is killed like a stop.
  7. A run with neither a scope nor a deadline is refused. (After step 6's
     default this can only happen with `deadline_ms=false`: an explicit opt-out
     is refused.)
  8. A refused spawn with no `on_start_error` calls the exit callback once, with
     `(nil,nil,nil,nil,reason)`.
  9. A process that ignores KILL (the fake's kernel hold) → unresolved-visible at
     5 s, logged with its pid, and still counted.
- [ ] **Step 2:** Run: FAIL.
- [ ] **Step 3: Implement.**
  - `M.scope_key(epoch, generation)` returns `tostring(epoch)..':'..tostring(generation)`.
    Replace both spellings with it.
  - `stop_matching` sends to `-state.pid`. Treat ESRCH as the observation
    `missing`, not a failure. Keep the `accepted_signal` dedupe per signal.
  - `reconcile_step`: on the `escalate` effect, while `not state.exited`, send
    SIGKILL to `-state.pid`.
  - `M.stop_scope(key, signal)` is `scoped_stop` over
    `state.logical_generation == key`.
  - `M.run`: when there is no `opts.logical_generation` and no
    `opts.generation_id`, set `deadline_ms = opts.deadline_ms or 120000`, and
    start a deadline timer through `record.runtime.new_timer`. On fire it
    dispatches `deadline` and stops the record. Refuse `deadline_ms == false`
    when there is no scope.
  - `reject(message)`: if `on_start_error` is nil, schedule
    `callback(nil,nil,nil,nil,message)`.
  - Retire deadline timers with the record (`close_reconcile` sibling).
- [ ] **Step 4:** Run: PASS. **Counterfactual:** revert the `-pid` to `pid`, and
  confirm test 2 fails.
- [ ] **Step 5:** Commit (`#261 M3: stop kills a scope as groups, escalating to SIGKILL`).

### Task 3.4: Neovim exit kills what is left

- [ ] **Step 1:** In `tasker`'s setup path (find where `M._uv`/timers are
  initialized, or `init.lua` setup), register once:
  `vim.api.nvim_create_autocmd('VimLeavePre', {callback = function() tasker.stop(9) end})`.
  `M.stop` (`tasker.lua:290`) already matches every record. With `-pid` it
  kills each group.
- [ ] **Step 2: Test:** fire `VimLeavePre` with `nvim_exec_autocmds` on the fake
  → every live record's group got SIGKILL.
- [ ] **Step 3:** Commit (`#261 M3: leaving Neovim kills every live group`).

### Task 3.5: Live conformance — the fake's model matches a real kernel

**Files:** Create `tests/integration/process_group_conformance_spec.lua`, and
route it in `atlas/traceability.yaml` with the tasker specs.

- [ ] **Step 1: Write the spec** against real `sh`. Skip it with `pending()` when
  `vim.fn.executable('sh')==0`.
  - `tasker.run` spawns `sh -c 'ps -o pgid= -p $$'`. The reported pgid equals the
    spawn's pid. This checks the key directly.
  - It spawns `sh -c 'trap "" TERM; sleep 30 & wait'` (it ignores TERM, and a
    grandchild holds stdout), then `stop_owner`. The record resolves within 4 s,
    and `kill -0` on the grandchild's pid reports it gone.
- [ ] **Step 2:** Run on main, with the key still `detach`: the first case fails.
  Run on the branch: PASS.
- [ ] **Step 3:** Commit (`#261 M3: live conformance for process groups`).

### Task 3.6: Documentation for M3

- [ ] `atlas/providers/tool_execution.md` (the process bounds section) and
  `atlas/chat/lifecycle.md` (Stop): Stop kills a generation's process scope as
  groups, TERM then KILL after 2 s; unscoped helpers die at 120 s; leaving
  Neovim kills every group. State the two residuals here, once: a kernel hold,
  and an nvim crash.
- [ ] `tests/manual/chat-concurrency.md`: a manual item for Stop during a long
  tool (`find /`), then submitting again at once.
- [ ] Commit (`#261 M3: atlas — what Stop kills`).

### Task 3.7: M3 boundary

- [ ] `make test`, `make lint`; `sdlc milestone-close --issue 261 --milestone M3`.

---

## Chunk 4: M4 — every wait a generation holds settles

With M3, every *process* ends. M4 makes every *wait* end. The runner reaches
`terminal` only when every operation confirms (`generation.lua:153-158`), and
`active` drops only there (`generation_runner.lua:532`).

### The enumeration

Produced from `generation.lua`'s operation kinds and every leaf they wait on:
`grep -n "operation(s,effects\|start_children" lua/parley/generation.lua` for
the kinds, then each adapter's cancel path.

| # | Operation · leaf | Fails to confirm when | Fix |
|---|---|---|---|
| W1 | any op whose start threw | `op.handle` nil; `response_session.lua:231` returns false without `done` | runner: an op with no handle confirms at cancel — it holds nothing its scope kill did not reach |
| W2 | `prepare` · `operation:cancel` (`chat_respond.lua:1531-1536`) | resolves only via `build`/`ready` | resolve at once; `build`/`ready` already no-op when cancelled |
| W3 | `prepare` · readiness UI (`llm_readiness.lua:84-150`) | picker never calls back | covered by W2; a late `on_select` hits `validate_source` false |
| W4 | `prepare` · remote reference fetch (`oauth.fetch_content`, `chat_respond.lua:1185-1297`) | unowned curl; `tasker.run` refused → no callback; `fetch_content` throws → `pending` stuck | thread the scope into `fetch_content` → every `tasker.run` in its call tree; M3's settling spawn; pcall the call at `:1289-1292` and count down `pending` |
| W5 | `request` · pre-spawn (vault, `pre_query`) (`response_provider.lua:110-121`) | zero tasker match → waits for a callback | if `stop_owner` matched nothing, resolve at once; the late callback aborts via `transport_alive` (`dispatcher.lua:852,885`, covered by `response_provider_spec.lua:71-80`) |
| W6 | `request` · copilot `pre_query` (`vault.lua:159-219`) | `code~=0` (`:207-209`) and the early return (`:161-162`) never call back — a definite hang even without Stop | call back with the error on both paths |
| W7 | `request` · async continuation after `pre_query` (`dispatcher.lua:446-854`) | a throw → nothing aborts | pcall the continuation; on error `abort_before_start` |
| W8 | `request` · `recover_query` (`dispatcher.lua:794-828`) | no liveness check: a cancelled request can restart the daemon or prompt a login | check `transport_alive` before acting |
| W9 | `child` · `producer.start` threw | `producer_handle` nil → `producer.cancel(nil)` false (`producer.lua:168-169`) | W1 covers the op; the tool's processes die with the scope |
| W10 | `child` · refused first `child_outcome` (`response_tools.lua:73-75` vs `generation.lua:441-446`) | the adapter records an outcome the machine rejected; the later `resolved(nil)` is refused forever | reproduce with a test first; then the adapter records an outcome only when the machine accepted it |
| W11 | `continue_round` threw (`response_tools.lua:186-204`) | nil handle | W1 |
| W12 | `finalize` · `response_completion.start` returned nil (`chat_respond.lua:1678-1682`, after M1's rewrite) | `done` never called | `done('failed')` |
| W13 | `finalize`/`prepare` · a Deferred step threw (`deferred_work.lua:19`) | the work cancels itself; nothing settles its owner | `Deferred.new(step, on_error)`: the owner settles failed. Wire it in `response_completion`, `response_preparation` and `generation_runner` |
| W14 | runner start (`generation_runner.lua:605-615`) | `active` +1 before throwing calls; generation registered and grants held | increment last; on a throw after `register_generation`, `finish_generation` and rethrow |
| W15 | topic cancel (`response_topic.lua:47`) | a raise skips `Session.cancel` in `cancel_entry` (`chat_respond.lua:1313-1315`) | pcall it (with M3, `stop_owner` no longer raises on ESRCH; the pcall covers the rest) |
| W16 | `skill_invoke` `_in_flight[buf]` (`:23`, `:402`) | keyed by buffer number, which `:e!`/`:bd`+reopen reuse; released only on physical read resolution; `stop_owner` unguarded (`:161`) | release on the buffer's document detach/reload and on `BufUnload`; guard `stop_owner` |

**Scope kill on stop.** The runner calls an optional `adapters.stopping(ctx)`
once, when the machine first enters `stopping`. `response_session` implements it
as `tasker.stop_scope(tasker.scope_key(ctx.epoch, ctx.generation))`. So
every process of the generation is signalled, whichever operations threw.

### ARCH-ORDER — the invariant M4 defends

**Every generation that enters `stopping` reaches `terminal` within the kill
bound (≈2 s, plus the time for its effects to drain) unless a process is held
in the kernel.** And `Runner.stats().active` equals the number of generations
not yet terminal.

Test strategy: `tests/integration/generation_settles_spec.lua` (new, routed
under `chat/lifecycle`), one case per row W1–W16. Each arranges the leaf to
never call back (or to throw), triggers each stop cause that applies (Stop, a
revoking edit, `:e!`, `:bd`), and asserts `terminal` plus `active` back to its
baseline. The spec's `after_each` asserts `Runner.stats().active == 0` and
`tasker.stats().active == 0`, so any case that leaks fails the *next* case too,
and the leak cannot hide. Nondeterminism enters through timers and callback
order; the fake runtime's timers fire only when the test calls `timer:fire()`,
so each ordering is reproduced by the sequence of fires.

### Task 4.1: Runner — stats, the start leak, `stopping`, handle-less ops

**Files:** `lua/parley/generation_runner.lua`; test
`tests/integration/generation_settles_spec.lua`.

- [ ] **Step 1: Failing tests** for W1, W11 and W14, plus a `stats()` case.
- [ ] **Step 2: Implement.**
  - `M.stats()` returns `{active=active, staged=staged_total}`.
  - Move `active=active+1` after `dispatch(s,{type='start'})`. Wrap
    `:606-615` in a pcall. On error: `D.transition(doc,{kind='finish_generation',generation=generation})`,
    drop `runners[r]`, then rethrow.
  - In `cancel_operation` (`:470-490`): if `op.handle == nil`, dispatch
    `operation_resolved` at once and skip the adapter.
  - When `G.snapshot(s.machine).phase` first becomes `stopping` (check after
    each `dispatch`), call `pcall(s.adapters.stopping, ctx)` once.
- [ ] **Step 3:** Run: PASS. **Step 4:** Commit (`#261 M4: the runner settles operations it cannot cancel`).

### Task 4.2: Session, provider, preparation, completion

**Files:** `lua/parley/response_session.lua` (implement `stopping`; W2 through
the prepare branch), `lua/parley/response_provider.lua` (W5),
`lua/parley/chat_respond.lua` (W2, W12), `lua/parley/deferred_work.lua` and its
three owners (W13).

- [ ] **Step 1: Failing tests** for W2, W3, W5, W12 and W13.
- [ ] **Step 2: Implement** each fix in its table row. For W13, `on_error` is
  optional. With it, `work:request`'s error path calls `on_error(err)` instead
  of rethrowing. Without it, behaviour is unchanged.
- [ ] **Step 3:** Run: PASS. **Step 4:** Commit (`#261 M4: preparation, provider and completion settle on cancel`).

### Task 4.3: Helpers a generation calls — remote fetch, vault, dispatcher

**Files:** `lua/parley/oauth.lua` (`fetch_content` at `:2386` and every
`tasker.run` in its call tree: find them with
`grep -n "tasker.run" lua/parley/oauth.lua` and follow the calls from `:2386`),
`lua/parley/chat_respond.lua:1185-1297` (pass `scope`; pcall and count down),
`lua/parley/vault.lua:159-219` (W6), `lua/parley/dispatcher.lua` (W7, W8).

- [ ] **Step 1: Failing tests** for W4, W6, W7 and W8. For W4, a fake fetch that
  never exits: Stop → it is SIGTERM'd through the scope.
- [ ] **Step 2: Implement** the rows.
- [ ] **Step 3:** Run: PASS. **Step 4:** Commit (`#261 M4: helpers a generation starts share its scope or settle`).

### Task 4.4: Tools, topic, skills

**Files:** `lua/parley/response_tools.lua` (W10), `lua/parley/response_topic.lua`
and `chat_respond.lua:1313-1315` (W15), `lua/parley/skill_invoke.lua` (W16).

- [ ] **Step 1: Failing tests** for W9, W10 (reproduce the refused-outcome
  sequence first; if it cannot be reached through the machine's public events,
  record that in the Log and drop the row), W15 and W16. W16 includes `:bd`
  followed by reopening the same file, asserting the same buffer number is
  reused and a new skill run is not refused as "already running".
- [ ] **Step 2: Implement.** **Step 3:** Run: PASS.
- [ ] **Step 4:** Commit (`#261 M4: tools, topics and skills settle and follow the buffer`).

### Task 4.5: The reported shape, end to end

- [ ] **Test** in `tests/integration/chat_respond_spec.lua`: a provider whose
  curl ignores TERM (the fake). Submit, then Stop, then advance the fake timers
  2 s: `terminal`, and `Runner.stats().active` is back. Repeat 17 times in one
  buffer: the 17th submission is admitted. Before M3 and M4 it was refused with
  `process generation limit`.
- [ ] **Test:** the same with `:bd`, then reopening the file (same buffer
  number), then submit → admitted.
- [ ] Commit (`#261 M4: a stopped response never holds a slot`).

### Task 4.6: Documentation and boundary

- [ ] `atlas/chat/lifecycle.md` (Stop): one paragraph stating the invariant above
  and pointing at `generation_settles_spec.lua`. `ownership.md` links to it.
- [ ] `make test`, `make lint`; `sdlc milestone-close --issue 261 --milestone M4`.

---

## Chunk 5: M5 — one refusal vocabulary

### What is broken today (verified 2026-09-18; issue Log)

- **Silent returns.** The caller drops `nil, reason` at `chat_respond.lua:1400`
  (`no question selected`), `:1948`, `:1951`, `:1956` and `:1960`
  (`no questions selected`, the most common). The command loop
  (`init.lua:1317-1331`) discards every return value.
- **Silent non-success endings.** The single-response `terminal` handler reports
  only `failure_notice` and `overflow`. `revoked`, `uncertain`, `insert_failed`,
  `finalize_failed`, `round_capacity`, gap-write `prepare_failed` and
  `provider_failed` end with nothing.
- **Raw tokens.** `Response not started: overlap` and the like, over two channels
  (`:1691` `logger.warning`, and `:1542` `pcall(vim.notify)`, which shows the first
  line only and does not log). The same holds for `Response not resumed: …`
  (`:1387`), `Batch not started|resumed|paused: …` (`:1943`, `:1992`, `:1994`,
  `:2004`, `:2011`), and `Drill-in stopped: …` (`:1809`, `:1820`, `:1865`, `:1872`).
- **A false message.** `cmd_respond` (`chat_respond.lua:2020-2032`) says "Forcing
  response even if another process is running" and passes a 4th argument that
  `M.respond` never reads. `init.lua:4171` calls a
  `resubmit_questions_recursively` that no longer exists.
- **#265** owns `buffer_edit.replace_user_lines` refusals, which are not on
  these paths. It should consume this vocabulary; note that in #265's Log.

### The model

`lua/parley/refusal.lua` is pure, and producers keep their tokens, because
control flow reads some of them (`generation_runner.lua:275-276`, and others).
It owns the *words*:

```lua
-- The submission path's refusal vocabulary (#261). Every refusal a user can meet
-- submitting, resuming or batching says what happened and what clears it.
-- Producers keep their tokens — control flow reads several — and this module
-- owns the words. One entry per token; tests/unit/refusal_spec.lua checks each
-- names an action, and tests/arch/refusal_vocabulary_spec.lua checks every
-- token a producer can emit has an entry.
local M={}
M.PREFIX={start='Response not started',resume='Response not resumed',
    batch_start='Batch not started',batch_resume='Batch not resumed',
    batch_paused='Batch paused',ended='Response stopped',drill='Drill-in stopped'}
-- token → {what happened, what clears it}
M.TOKENS={
    overlap={'this answer is still being written by another response','wait for it, or :ParleyStop it'},
    ['generation limit']={'4 responses are already running in this chat','wait for one to finish, or :ParleyStop one'},
    ['process generation limit']={'16 responses are running across all chats','wait for one to finish'},
    ['process admission capacity']={'too many Parley processes are still running','wait for them; :ParleyToolOperations lists them'},
    ['unconfirmed entity']={'Parley is still reading this chat','try again in a moment'},
    ['target limit']={'4 responses in this chat are waiting for Parley to finish reading it','try again in a moment'},
    ['source changed']={'the question changed before the response started','submit again'},
    -- … one row per token in the enumeration below
}
-- Tokens that only a programming error produces; reported as such, and logged.
M.INTERNAL={['invalid submission']=true,--[[ … ]]}
function M.describe(kind,token,detail) --[[ returns "<PREFIX>: <what> — <action>." ]] end
return M
```

`:ParleyToolOperations` exists (`init.lua:1596`). Before using any other command
name in an action, confirm it with `grep -n "M.cmd.<Name>" lua/parley/init.lua`.

**Operator stop is not an error.** `operator stopped response` and
`batch cancelled` produce no warning, because the user asked for them.

**Token enumeration**, re-runnable:

```bash
grep -noE "reject\('[^']+'\)|return nil, ?'[^']+'|reason ?= ?'[^']+'|\{ok ?= ?false, ?reason ?= ?'[^']+'" \
  lua/parley/document/state.lua lua/parley/document/init.lua lua/parley/document/user_edits.lua \
  lua/parley/generation_runner.lua lua/parley/generation.lua lua/parley/response_submission.lua \
  lua/parley/response_target.lua lua/parley/batch.lua lua/parley/batch_response.lua \
  lua/parley/response_session.lua lua/parley/tasker.lua
```

Every literal it returns is either in `TOKENS` or in `INTERNAL`. The arch spec
runs this exact query (Task 5.2), so the table cannot drift from the producers.
The terminal outcomes (`revoked`, `uncertain`, `insert_failed`,
`finalize_failed`, `round_capacity`, `prepare_failed`, `provider_failed`,
`overflow`) are `TOKENS` entries under kind `ended`. `revoked` reads: "you
edited the answer while it was being written; the partial answer is kept —
submit again to regenerate". A kernel-held process (M3) is appended to
`process admission capacity` and `process generation limit` as detail: "still
running: pid 1234".

### Task 5.1: The vocabulary

**Files:** Create `lua/parley/refusal.lua` and `tests/unit/refusal_spec.lua`,
and route it under `chat/lifecycle`.

- [ ] **Step 1: Failing tests.**
  - Every `TOKENS` entry has a non-empty `what`. Its action matches `:Parley%u`
    or one of the closed set `submit again`, `try again in a moment`,
    `wait for`, `edit`.
  - `describe` for an `INTERNAL` token says it is unexpected and names the log.
  - `describe` for an unknown token does too, with the token shown.
  - `describe('ended','operator stopped response')` returns nil.
- [ ] **Step 2:** Run: FAIL. **Step 3:** Implement. Walk the enumeration query
  and write one row per literal. **Step 4:** PASS. **Step 5:** Commit.

### Task 5.2: Guards

**Files:** Create `tests/arch/refusal_vocabulary_spec.lua`.

- [ ] **Step 1:** Write two assertions.
  1. Run the enumeration query; every literal is a key of `TOKENS` or `INTERNAL`.
     Declare in the spec the handful of literals that are not refusals (e.g. a
     `reason='explicit revoke'` effect annotation), each with its reason.
  2. The `M.PREFIX` strings appear as string literals in no file under `lua/`
     except `refusal.lua`: `git grep -n -e "Response not started" …`.
- [ ] **Step 2: Counterfactual.** Add `return nil,'brand new token'` to a clean
  copy of `response_target.lua` and see (1) fail. Add
  `logger.warning('Response not started: x')` to `chat_presentation.lua` and see
  (2) fail. Restore both with `git checkout --`.
- [ ] **Step 3:** Commit (`#261 M5: guards — every refusal token has words`).

### Task 5.3: Route every refusal through it

- [ ] **Step 1: Failing integration tests** in `tests/integration/chat_respond_spec.lua`.
  Capture `vim.notify`, then:
  - One per silent return (the five sites) → exactly one WARN that contains the
    action.
  - One per terminal non-success outcome in single mode. Drive `revoked` by an
    edit, `provider_failed` by an injected failure, and the others by the
    fixture's controls where reachable. Assert exactly one notice.
  - `overlap`: regenerate twice at once → the second notice says
    `:ParleyStop`.
  - Stop → no WARN.
- [ ] **Step 2: Implement.**
  - Replace every site listed under "What is broken today" with
    `_parley.logger.warning(Refusal.describe(kind, token, detail))`.
  - Collapse the `:1542` channel into it, so both channels log.
  - Make each silent `return nil, reason` in `respond`/`respond_all` warn before
    returning.
  - In `terminal`, warn via `Refusal.describe('ended', result.outcome, result.failure)`
    when the outcome is not `success`. Keep `failure_notice` (provider HTTP
    detail) as the detail, and keep the overflow message by making `overflow`'s
    `TOKENS` entry call `chat_presentation.overflow_message`.
- [ ] **Step 3:** Delete the force-flag parsing and message in `cmd_respond`,
  and delete `init.lua:4171`. Run `grep -rn "resubmit_questions_recursively" lua tests`;
  it must print nothing but the header comment at `chat_respond.lua:3`, which
  gets fixed too.
- [ ] **Step 4:** Run: PASS. **Step 5:** Commit (`#261 M5: no silent refusal, no raw token`).

### Task 5.4: The inventory, the restart invariant, and the close

This is Done-when #1 and #6: the audit's inventory becomes a maintained atlas
page, not just a Log entry.

- [ ] **Create `atlas/chat/transcript_truth.md`** and link it from
  `atlas/index.md`.
  - **Restart invariant:** quitting and reopening a chat rebuilds every
    submission-relevant fact from the file. State nothing else survives, and
    why.
  - **The inventory:** a table of every state that can block submission or hold
    a generation, in the three Spec buckets. For each state, name its
    invalidation rule and the test that pins it:
    - document grants and turn: reload and detach;
    - `prev_answer`: generation end, revoke, reload;
    - runner `active`/`staged_total`: terminal, now certain;
    - tasker records: scope kill, deadline, `VimLeavePre`, kernel hold;
    - `responses`/`batches`: terminal, retire on detach;
    - `skill_invoke._in_flight`: detach;
    - `state_dir` sidecars: `sidecar_authority_spec`.
  - Each row points at code and tests, and states no rule the code owns (lessons:
    "state a code-derived rule once"). The Stop invariant links to
    `lifecycle.md`, and undo grouping to `ownership.md`.
- [ ] **Target** `transcript-is-the-whole-truth.md`: append a Revisions entry
  saying what #261 delivered and linking the page.
- [ ] **#255:** move it `open → working → codecomplete → done` through
  `sdlc issue set-status`, with a Log line pointing at #261's close, once #261's
  close gate passes.
- [ ] **#265:** a Log line saying its refusal words should come from
  `lua/parley/refusal.lua`.
- [ ] `make test`, `make lint`, and `make check-fresh-clone PLENARY=…` (per
  TOOLING.md).
- [ ] `sdlc milestone-close --issue 261 --milestone M5`, then `sdlc close --issue 261 --verified '<evidence>'`.
