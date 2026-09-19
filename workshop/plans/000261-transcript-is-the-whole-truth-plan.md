# Transcript Is the Whole Truth Implementation Plan

> **For agentic workers:** Consult AGENTS.md Section 3 (Subagent Strategy) to determine the appropriate execution approach: use superpowers-subagent-driven-development (if subagents are suitable per AGENTS.md) or superpowers-executing-plans to implement this plan. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Nothing outside a chat's Markdown file can stop someone working on it.
- The on-disk answer-recovery store is deleted, and every remaining sidecar
  degrades instead of throwing.
- A regenerating exchange's previous answer lives only as long as its
  generation, and feeds request context (#255).
- Everything a stopped generation started is killed for certain, and every
  wait it holds settles.
- Every refusal on the submission path says what happened and what to do.

**Architecture:** Five milestones. Each closes one way that state outside the
transcript blocks or confuses work on it.
- **M1** deletes the store, and the privacy machinery that existed only to hide
  it. The remaining sidecars (`state.json`, the remote-reference cache, the
  vault and custom-prompt files) can no longer throw. A spec that corrupts each
  one and then submits enforces that.
- **M2** puts a `prev_answer` slot on the document coordinator. The slot is
  keyed by exchange identity, and is valid only while the regenerating
  generation holds a grant there. It feeds request context in the same chat
  and in sub-chats. M2 also stops generated writes from marking other
  generations' input stale.
- **M3** makes the kill certain:
  - A generation's processes lead their own process group, and die with the
    generation's scope under SIGTERM, then SIGKILL.
  - Every other process declares a deadline.
  - A kill Parley caused is reported as a failure, never as exit 0.
- **M4** makes every wait a generation holds settle, so the admission counters
  drain by construction.
- **M5** gives the submission path one refusal vocabulary, and publishes the
  inventory.

**Tech Stack:** Lua (Neovim 0.11 plugin), plenary/busted specs under headless
Neovim (`make test`, `make test-spec SPEC=…`), libuv (`vim.uv`) for processes.

**Issue:** parley#261 (absorbs parley#255) · **Target:** `workshop/targets/transcript-is-the-whole-truth.md`

**Branch:** `sdlc change-code` names it `000261-…`. Keep that prefix:
`tests/arch/single_source_sweeps_spec.lua` scopes its guards by
`^%d%d%d%d%d%d%-`, and silently turns them `pending` on any other name.

**Line numbers** are as of `ee0c5f6d` (main after #266). Every enumeration below
carries the query that produced it. **Re-run the query before acting on the
table.** If it returns a row the table lacks, correct the table first.

**Plan tables and the arch guard.** `single_source_sweeps_spec.lua:256-336`
checks every table row that *starts* with a backtick. Each backticked
identifier in such a row must be defined in the tree; in a `deleted` row, it
must *not* be. So:
- Core-concepts rows for a later milestone start with `M<n> ·`, which exempts
  them from the check. **That milestone's first task removes the prefix**, which
  turns the check on for its rows.
- Removal and enumeration tables inside tasks never start a row with a backtick.
- Commit hashes and Neovim API names are never backticked in a table row.

---

## Core concepts

### Pure entities

| Name | Lives in | Status |
|------|----------|--------|
| `answer_recovery` — the on-disk snapshot store | `lua/parley/answer_recovery.lua` | deleted |
| `recovery_paths` — the private-directory predicate | `lua/parley/recovery_paths.lua` | deleted |
| `traversal_policy` — private-path exclusion for tool commands | `lua/parley/tools/traversal_policy.lua` | deleted |
| `state` — `holds`: does a generation still hold a live grant on an entity | `lua/parley/document/state.lua` | modified |
| `previous_answer` — `capture`, `substitute` | `lua/parley/previous_answer.lua` | new |
| `attempt` — `open_stop_window`: TERM, then the escalate effect at +2 s, for a stop whose cause is stop, deadline or leave; `kill_cause` | `lua/parley/attempt.lua` | modified |
| M5 · `refusal` — `describe`, `TOKENS`, `INTERNAL`, `PREFIX` | `lua/parley/refusal.lua` | new |

- **`State.holds(handle, generation, entity)`** (M2) is true when the
  document's state has a grant with that generation and entity whose status is
  not `revoked`. `suspended` counts: the generation still owns the region,
  pending re-proof. State handles are opaque (`state.lua:5,62`), so it reads
  through the module's own `state(handle)` accessor.
  - **DRY rationale:** today, callers copy the whole state to ask this
    (`D.snapshot(doc).grants[...]`). `holds` asks it once, on the owner, without
    a copy.
  - **Tests:** `tests/unit/document_state_spec.lua`, no IO.
- **`previous_answer`** (M2) is pure.
  - `capture(exchange)` returns `{answer, summary, reasoning}`, deep-copied from
    a parsed exchange. The answer includes `content_blocks`, so tool blocks
    survive. It returns `nil` when there is no answer.
  - `substitute(parsed, entries, skip_index)` returns `parsed` unchanged when
    `entries` is empty. Otherwise it returns a copy in which each entry's
    exchange carries the entry's answer, summary and reasoning. An entry's
    exchange is the one whose `question.line_start == row+1`, and it is never
    `skip_index`. The copy rebases `answer.line_start` to
    `question.line_end+1`.
  - Why only `answer.line_start`: `build_messages` reads only `answer.line_start`
    (`chat_respond.lua:920`) and `question.line_start` (`:806`), per
    `grep -n "line_start\|line_end" lua/parley/chat_respond.lua | awk -F: '$1>=732 && $1<=988'`.
    `build_ancestor_messages` reads content only.
  - **DRY rationale:** one substitution serves both consumers, same-chat input
    and the ancestor chain.
  - **Tests:** `tests/unit/previous_answer_spec.lua`, no IO.
- **`attempt`** (M3) is specified in Chunk 3's lifecycle table.
- **`refusal`** (M5) is specified in Chunk 5.

### Integration points

| Name | Lives in | Status | Wraps |
|------|----------|--------|-------|
| `chat_recovery` and `response_recovery` — recovery IO, pickers, guards | `lua/parley/chat_recovery.lua`, `lua/parley/response_recovery.lua` | deleted | state dir, pickers |
| `helper` — `file_to_table` made total, with an optional per-reader schema; `conform` drops wrongly typed fields; `table_to_file` is the atomic writer; `remove_stale_temps` sweeps its crash leftovers at setup | `lua/parley/helper.lua` | modified | JSON sidecar files |
| `file_tracker` — `file_path`: `file_access.json` is a profile sidecar, read with a schema and written through the one writer | `lua/parley/file_tracker.lua` | modified | the file access history |
| `custom_prompts` — `read_authored`: the file as the user wrote it, for writes; `load` is the filtered view; `source` accepts a preloaded view so a loop reads once; writes report whether they happened | `lua/parley/custom_prompts.lua` | modified | the user's custom prompt file |
| `init` — `set_previous_answer`, `previous_answers`, `_previous_count` | `lua/parley/document/init.lua` | modified | per-document slot table |
| `helper` — `chat_lines`: a chat's current text, from its loaded buffer if any; `buffer_for`: the buffer named exactly `name` | `lua/parley/helper.lua` | modified | loaded buffers, readfile |
| `tasker` — `scope_key`, `is_scoped`, `stop_scope`, `held`, `leave`, `deadline` (the per-kind table), `exit_reason` | `lua/parley/tasker.lua` | modified | spawn, kill, timers |
| `oauth` — `_token_body_summary`: what a token endpoint's body may show in a log, its OAuth error only; the content tree takes the requesting generation's scope and spawns through `content_run`: `fetch_content`, `_fetch_public_content`, `_try_saved_accounts`, `_try_account_fetch`, `_fetch_google_api_once`, `_fetch_dropbox_api_once`, `_fetch_microsoft_api_once`, `_run_dropbox_metadata_request`, `_run_dropbox_file_request`, `_run_microsoft_metadata_request`, `_run_microsoft_content_request`, `_convert_office_to_text` | `lua/parley/oauth.lua` | modified | the OAuth token endpoint; remote content |
| `vault` — `refresh_copilot_bearer` calls back on every path, success or its error callback | `lua/parley/vault.lua` | modified | the Copilot token endpoint |
| `generation_runner` — `stats`; the `stopping` adapter; `fault` | `lua/parley/generation_runner.lua` | modified | the runner's effect loop |
| `deferred_work` — `new`, now taking an error callback | `lua/parley/deferred_work.lua` | modified | timer turns |

- **`helper.file_to_table`** (M1) runs `pcall(vim.json.decode)` and requires a
  table. Otherwise it logs a warning naming the file and saying it was ignored,
  and returns `nil`. Its four callers already fall back with `or {}`
  (`init.lua:1454`, `vault.lua:172`, `chat_respond.lua:262`,
  `custom_prompts.lua:30`). Every JSON sidecar reader goes through it, so this
  one fix covers the whole class (ARCH-DRY).
- **DocumentCoordinator slot** (M2): `s.previous = {}` on the per-document state
  (`document/init.lua:239`), keyed by entity, holding `{generation, value}`.
  - `set_previous_answer(doc, {epoch, entity, generation, value})` accepts only
    when the epoch is current and `State.holds` is true.
  - `previous_answers(doc)` returns `{ {row, generation, value}, … }` for every
    slot that is still valid, and deletes the rest. A slot is valid while its
    generation still `holds` its entity and the entity still resolves. The
    lookup uses `M.lookup`, the measured path, because its budget accounting is
    the reason to prefer it.
  - Cleared: by that generation's `finish_generation`, and as a whole table on
    reload and detach (`init.lua:214-233`).
  - `_previous_count(doc)` is a test seam that returns the raw table size, so a
    test can prove a slot was *removed*, not merely filtered.
  - **ARCH-FUNERAL:** there is at most one slot per live generation, so at most
    4 per document (`state.lua:205`). Each slot dies with its generation, all of
    them die with the document, and nothing touches disk.
- **`helper.chat_lines(path)`** (M2) returns `lines, buf`, looked up in this
  order:
  1. the loaded buffer whose resolved absolute name equals the resolved `path`;
  2. otherwise the file (`readfile`, with `nil` for the buffer);
  3. otherwise `nil`, when neither exists.

  It compares resolved names rather than calling `bufnr(path)`, which is a
  file-pattern match. Consumers: the ancestor read, and `init.lua:3798-3800`.

### ARCH-ORDER — the `prev_answer` slot

The slot holds state between events that come from outside
`start_scoped_response`:
- the regenerating generation G's progress;
- human edits;
- reload and detach;
- other generations capturing context.

The slot has two states: **absent**, and **held by G on entity E**. Its
validity is derived when it is read, not stored.

| Event | Slot | Why |
|---|---|---|
| G's `prepare_input` runs (answer intact) | held | it is set before any gap byte is deleted |
| another request captures context | read | substitution |
| G writes its gap (4 KiB slices), then streams | held | the buffer shows a truncated old answer, a header, or partial text; the slot holds the whole old answer |
| G's grant is suspended (structural uncertainty) | held | still G's region, pending re-proof |
| G is paused on stale input | held | G has not ended and its answer is partial; the old answer stays the valid context until Stop or resume ends G |
| a human edit revokes G's grant | read as absent | `holds` is false; the partial answer is now the transcript's truth |
| G′ regenerates E after G was revoked | replaced by G′ | set overwrites; G's later `finish_generation` removes only slots whose generation is G |
| G ends, in success or failure | removed | "both are recorded on the transcript, and that's all" |
| an edit deletes E's `💬:` marker | read as absent | `lookup` is nil, so it is never matched to another exchange |
| reload or detach | removed | the whole table |

**Consumer side: staleness.** G's writes land inside other generations' input
ranges (the prefix dependency, `response_target.lua:36-41,59-62`). Today
`state.lua:272-284` marks those generations stale ("other owners … stay stale").
Under #255 that is wrong for both kinds of request:
- a request captured *with* G's previous answer consumed the answer that stays
  valid until G ends;
- so did a request captured *before* G started.

#255 also says an already captured request is unaffected by G's later
completion.

**Decision:** a generated write moves dependency ranges but never marks them
stale. A generated write is one with an owner grant (`event.owner_grant`,
`state.lua:252-258`) that belongs to another generation. Human edits still mark
ranges stale. This reverses the "other owners" clause written for #254. Task 2.5
pins both halves.

**The event most likely to be mishandled** is a context capture whose lines
were read *before* G ended, but whose projection runs *after*.
- `build()` runs after readiness and remote fetches (`chat_respond.lua:1548-1604`),
  while the lines were read at command time (`chat_context.lua:49-62`).
- So same-chat substitution happens in `start_scoped_response`, in the same tick
  the lines were read.
- Ancestors are read in `build()` (`:1570-1573`), so they substitute there.
- Task 2.4 has a test that holds `build()` until G has finished.

**Ordering source:** the scheduler and human input. Tests drive the ordering
with the explicit `output`/`complete` controls of the `chat_respond_spec`
fixture. They also stub `resolve_remote_references` so it hands back its `build`
continuation, and the test calls it later.

### ARCH-CONSTRAINTS

- **Context capture** runs at command time and makes at most 4 slot lookups.
  `substitute` copies the parsed chat only when a slot exists: one more copy of
  what `chat_respond.lua:1397` already copies.
- **Kill:** SIGTERM, then SIGKILL 2 s later if the process is still unresolved,
  then the existing 5 s observation window. Operator-approved; not on a
  keystroke path.
- **Deadlines for processes nobody stops** (operator-approved, 2026-09-18):

  | Kind | Deadline | Basis | Call sites (`grep -rn "tasker\.run(nil" lua/parley` + dispatcher streams without transport opts) |
  |---|---|---|---|
  | a human may be answering a prompt | 600 s | keychain dialogs, pinentry-mac, biometric unlock | vault.lua:121 (secret command); oauth.lua:831, 838 (keychain write), 859 (read), 903 (delete) |
  | one HTTP call | 120 s | a single request/response | vault.lua:206 (copilot token); oauth.lua:936 (refresh), 1007 (auth-code exchange); the content-fetch tree when called outside a generation |
  | local conversion | 60 s | pandoc/textutil on one document | oauth.lua:1330, 1338 when outside a generation |
  | background LLM stream with no owner | 900 s | long reasoning output | memory_prefs.lua:255; chat_respond.lua:1147 (generate_topic, from init.lua:4422) |

  Exceeding a deadline kills the process (TERM, then KILL 2 s later). Its
  callback sees a failure: `io_error = 'killed: deadline'`.
- **Refusal messages:** one `logger.warning` per refusal; no new IO.

### ARCH-SECURE

- **M1 narrows the tool surface.** Tools stop special-casing
  `<state_dir>/answer-recovery`.
  - **Exposure, stated:** the existing snapshot files stay on disk (operator
    decision). They become reachable by tools *if* the state directory lies
    under a configured tool root.
  - By default it does not: the state directory is
    `stdpath('data')/parley/persisted` (`config.lua:203`), while tools reach the
    chat roots and the working tree.
- **M1 treats every sidecar as untrusted input** across a version boundary. It
  is parsed once, at `file_to_table`. A non-table or undecodable file becomes
  `nil` with a warning: never a thrown error, never a fabricated value.
- **M3 signals only process groups Parley created.** Scoped runs use
  `detached=true`, which makes the child a group leader.
  - POSIX does not reuse a process-group id while any member lives, so
    `kill(-pid)` while the record is unresolved reaches only our group.
  - Residual, stated: every member of a group exits, its EOF has not been
    observed yet, and its id is then reused. The window is one event-loop turn.
- **`detached` also calls `setsid()`**, so the child leaves Neovim's terminal
  session. Operator decision:
  - Only **scoped** runs are detached: provider, tools, per-request fetches and
    skill processes. None of them is interactive.
  - Shared helpers (vault secret command, keychain, OAuth token calls) stay
    attached, so a terminal prompt still works. They are killed by pid at their
    deadline.
  - Consequence: a grandchild of a user-configured secret command can outlive
    it.

### ARCH-MOCK

- **Processes:** the stateful fake is `tests/helpers/fake_process.lua`, behind
  tasker's runtime seam (`M._uv`). M3 extends it with groups, signal handling
  and pipe holders (Task 3.1). The live conformance check,
  `tests/integration/process_group_conformance_spec.lua`, runs real `sh` on
  every `make test`.
- **Provider transport:**
  - M1, M2 and M5 use the `chat_respond_spec` dispatcher double
    (`tests/integration/chat_respond_spec.lua:66-90`).
  - M4 needs a real `tasker` record in the loop, so it uses the fake-runtime
    harness of `tests/integration/dispatcher_ownership_spec.lua`.

---

## Chunk 1: M1 — no sidecar under the state directory can block

### Task 1.1: The #261 blocker, red on main

**Files:** Modify `tests/integration/chat_respond_spec.lua`, replacing the two
recovery tests at `:124-157`. The fixture is already in that `describe`
(`:66-123`: `open`, `submit`, `output`, `complete`, and a stateful dispatcher
double).

- [x] **Step 1: Write the tests.**

```lua
    -- #261: the reported blocker. Regenerate, edit the answer while it streams
    -- (the edit revokes the generation), then regenerate again. Before #261 the
    -- retained on-disk snapshot said "original" while the buffer held the
    -- partial answer; once the in-process retry cache was invalidated (a second
    -- edit, a reload, a reopen) every retry was refused.
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
        return row
    end
    local function submit_again()
        vim.api.nvim_win_set_cursor(0,{5,0})
        Respond.respond({range=0})
        wait_for(function()return #calls==2 end)
    end
    -- Characterization: passes on main through the in-process retry cache
    -- (chat_recovery.lua:131-135). Kept because deleting that cache must not
    -- break the immediate retry.
    it('regenerates immediately after a revoked regeneration',function()
        regenerate_then_revoke(); submit_again()
    end)
    it('regenerates after a revoked regeneration and a further edit (#261)',function()
        local row=regenerate_then_revoke()
        vim.api.nvim_buf_set_text(buf,row-1,0,row-1,0,{'again '})
        submit_again()
    end)
    it('regenerates after a revoked regeneration and a reload (#261)',function()
        regenerate_then_revoke()
        local path=vim.api.nvim_buf_get_name(buf);files[#files+1]=path
        vim.cmd('silent write!');vim.cmd('edit!')
        submit_again()
    end)
    it('regenerates after a revoked regeneration, closing and reopening the chat (#261)',function()
        regenerate_then_revoke()
        local path=vim.api.nvim_buf_get_name(buf);files[#files+1]=path
        vim.cmd('silent write!')
        vim.api.nvim_buf_delete(buf,{force=true})
        vim.cmd('edit '..vim.fn.fnameescape(path));buf=vim.api.nvim_get_current_buf()
        submit_again()
    end)
    it('regenerates regardless of a legacy answer-recovery directory (#261)',function()
        local legacy=parley.config.state_dir..'/answer-recovery'
        vim.fn.mkdir(legacy,'p');vim.uv.fs_chmod(legacy,tonumber('755',8))
        vim.fn.writefile({'not json'},legacy..'/0.1.json')
        local ok,err=pcall(function()
            open({'💬: question','','🤖: original','valuable answer',''})
            submit()
        end)
        vim.fn.delete(legacy,'rf')
        assert(ok,err)
    end)
```

- [x] **Step 2: Run on main, and confirm each red test fails for its named reason.**

Run: `make test-spec SPEC=chat/lifecycle`
Expected:
- "immediately" passes: it is the characterization test.
- "Further edit", "reload" and "reopen" time out on `#calls==2`. Each logs the
  warning `Response not started: Answer recovery unavailable: retained recovery
  requires inspection or explicit restore`.
- "Legacy directory" fails inside `submit()` (`#calls>0` never holds), with
  `… must be private (0700)`.

If a red case passes, it does not reproduce the report. Fix the test before
going on.

- [x] **Step 3: Commit** (`#261 M1: the reported blocker, as failing tests`).

### Task 1.2: Delete the subsystem and its hooks

Removal map. Re-run before editing:

```bash
grep -rnE 'answer_recovery|chat_recovery|response_recovery|recovery_paths|answer-recovery|AnswerRecovery|AnswerRestore|fake_recovery_filesystem|private_directory|private_recovery|traversal_policy' lua tests atlas README.md
```

The #197 auth retry (`cliproxy_recovery_e2e_spec.lua`, `recovery_timeout_ms`)
does not match.

| Site | Action |
|---|---|
| lua/parley/answer_recovery.lua, chat_recovery.lua, response_recovery.lua, recovery_paths.lua | delete |
| init.lua:1600-1605, the AnswerRecovery and AnswerRestore commands | delete (the loop at `:1317-1330` derives commands from `M.cmd`) |
| init.lua:3694-3699, recovery cleanup in delete_chat_file | delete |
| chat_respond.lua:1402 replacing_answer, :1448 recovery local | delete (M2 re-adds `replacing_answer` where it needs it) |
| chat_respond.lua:1535 the unproved cancel branch, :1551-1564 the suspended-grant wait | delete: they exist only because the snapshot read the live answer |
| chat_respond.lua:1582-1595 start and publish | delete |
| chat_respond.lua:1673-1689 finalize | becomes the plain completion below; `capture_topic_parent(ctx)` and `start_topic()` stay first |
| chat_respond.lua:1692, :1711 recovery finish | delete |
| chat_respond.lua:1639 state_dir, response_session.lua:92, response_tools.lua:111, tools/producer.lua:98, skill_invoke.lua:397 | delete the field |

```lua
        finalize = function(ctx, done)
            capture_topic_parent(ctx)
            start_topic()
            local completion = require('parley.response_completion').start(doc, ctx, done,
                {user_prefix = config.chat_user_prefix})
            return {cancel = function(_, resolved)
                if completion then completion:cancel() end
                if resolved then resolved() end
            end}
        end,
```

- [x] **Step 1:** Apply the table.
- [x] **Step 2:** Run the Task 1.1 tests. Expected: all PASS.
- [x] **Step 3: Commit** (`#261 M1: delete the on-disk answer-recovery store`).
  The body gives the why: a retained snapshot that disagreed with the buffer
  refused every retry, even across reopen; undo is the way back to a replaced
  answer.

### Task 1.3: Delete the privacy carve-out from the tools layer

| Site | Action |
|---|---|
| helper.lua:10-16 the private-path predicate; its uses at :371, :433, :471 | delete; `:471` keeps its directory filter |
| tools/dispatcher.lua:219 | delete the private-directory branch |
| tools/dispatcher.lua:353-354 | delete (the only reader of `opts.state_dir` there) |
| tools/dispatcher.lua:361 | drop the private-directory conjunct |
| tools/dispatcher.lua:367 | drop the private-directory option |
| tools/dispatcher.lua:457 | delete the branch |
| tools/async_builtin.lua:29 | drop the private-directory field |
| tools/async_builtin.lua:126-143 | remove the policy call; run `command` / `plan.command` as given (the policy returned them unchanged when no private path was set) |
| tools/filesystem.lua:317-319, 332-333 | drop the private-directory validation and its failure |
| tools/traversal_policy.lua, tests/unit/tool_traversal_policy_spec.lua | delete |

- [x] **Step 1:** Apply the table.
- [x] **Step 2: Tests of the carve-out.** In each case below, delete what
  asserts the private exclusion. **Keep what pins other behaviour**, with the
  exclusion assertions removed.
  - `tests/integration/tool_process_scope_spec.lua`:
    - The `run()` helper (`:10-15`) stops applying the policy.
    - Delete `:95-105`, `:135-151` and `:153-162`.
    - **Keep** `:122-133` (broad globs with `--hidden --no-ignore`) and
      `:164-173` (the chat-history glob), minus their private assertions.
  - Same rule for `tests/integration/async_builtin_spec.lua:101-120`,
    `tests/integration/tool_dispatch_capture_spec.lua:95-105` and
    `tests/unit/tool_process_scope_spec.lua:36-41`.
- [x] **Step 3:** Delete `tests/integration/{answer_recovery,chat_recovery,response_recovery,recovery_paths}_spec.lua`
  and `tests/helpers/fake_recovery_filesystem.lua`.
- [x] **Step 4:** In `tests/integration/batch_lifecycle_spec.lua`:
  - remove `:30`, `:43-45` and `:60`;
  - in the three recovery cases (`:65-86`, `:88-95`, `:97-116`), remove the
    recovery lines but keep any batch assertions (retry after failure or cancel,
    early-save ordering).
- [x] **Step 5:** `make test-spec SPEC=providers/tool_execution` and
  `make test-spec SPEC=chat/batch`: PASS.
- [x] **Step 6: Commit** (`#261 M1: tools stop special-casing the recovery directory`).

### Task 1.4: Sidecars degrade, never throw — and a spec proves it for each

The audit's bucket (a) claimed every other sidecar degrades. The review showed
two do not. All four JSON readers go through `helper.file_to_table`
(`helper.lua:655-669`), which calls `vim.json.decode` without a pcall. Two
consequences:
- **A corrupt `state.json` throws** from `setup()`, and from every `:Parley*`
  command, because the command wrapper calls `refresh_state()` first
  (`init.lua:1320-1323`, `:1454`).
- **A corrupt `remote_reference_cache.json` throws** inside
  `resolve_remote_references` (`chat_respond.lua:1197` → `:262`). Every
  submission in every chat is then refused.

**Files:**
- Modify: `lua/parley/helper.lua` (`file_to_table`)
- Test: `tests/unit/helper_spec.lua`
- Create: `tests/helpers/sidecars.lua` (the shared sidecar list);
  `tests/integration/sidecar_degrade_spec.lua` (behaviour);
  `tests/arch/sidecar_authority_spec.lua` (the reader census). Route both specs
  under `chat/lifecycle` in `atlas/traceability.yaml`.

- [x] **Step 1: Failing unit tests.** Call `file_to_table` on:
  - invalid JSON;
  - JSON that is not an object (`[1]`, `"x"`, `3`);
  - an empty file;
  - a missing file.

  Each returns `nil` and does not throw. On invalid content it warns once,
  naming the file.
- [x] **Step 2: Implement.**

```lua
--- A JSON sidecar as a table, or nil. Never throws: every sidecar under the
--- state directory is input from another process, version or crash, and none may
--- stop someone working on a chat (#261). A file that is not a JSON object is
--- ignored with a warning naming it.
_H.file_to_table = function(file_path)
    -- (existing open/read/empty handling unchanged)
    local ok, tbl = pcall(vim.json.decode, content)
    if not ok or type(tbl) ~= "table" then
        logger.warning("Ignoring unreadable state file " .. file_path .. ": "
            .. (ok and "not a JSON object" or tostring(tbl)))
        return nil
    end
    return tbl
end
```

- [x] **Step 3: The behavioural spec**, driven by one table that the census
  shares:

```lua
-- tests/helpers/sidecars.lua — the one list of sidecars under the state
-- directory, with the module that reads each. The census spec checks the
-- readers; the behaviour spec corrupts every file listed and submits.
return {
    { reader = "lua/parley/init.lua",           file = "state.json" },
    { reader = "lua/parley/vault.lua",          file = "vault_state.json" },
    { reader = "lua/parley/custom_prompts.lua", file = "custom_system_prompts.json" },
    { reader = "lua/parley/chat_respond.lua",   file = "remote_reference_cache.json" },
}
```

  `sidecar_degrade_spec.lua` uses the `chat_respond_spec` dispatcher double.
  Lift its `before_each`/`open`/`submit` into `tests/helpers/respond_fixture.lua`
  and have both specs use that helper, rather than copying it. The spec covers:
  - **every sidecar, with both `'{'` and `'[1]'`:** write it, run the command
    path (`vim.cmd('ParleyChatRespond')`, which calls `refresh_state()`), and
    assert the provider was called;
  - **the remote-reference cache:** use a question with a remote reference, and
    stub `oauth.fetch_content` to return content;
  - **an unwritable state directory** (`chmod 500`, restored in a `finally`):
    submission still reaches the provider.
- [x] **Step 4: The census spec.**

```lua
-- Target transcript-is-the-whole-truth (#261): a sidecar under the state
-- directory became a precondition for regenerating an answer. Every module that
-- reads that directory must appear in tests/helpers/sidecars.lua, whose every
-- file sidecar_degrade_spec corrupts and then submits through. Modules that
-- only define the path are listed here with that reason.
local sidecars = require("tests.helpers.sidecars")
local PATH_ONLY = {
    ["lua/parley/config.lua"] = "defines the default path; reads nothing",
    ["lua/parley/starter_config.lua"] = "defines the starter path; reads nothing",
}
describe("arch: every state-directory reader is exercised corrupt", function()
    local hits = vim.fn.systemlist("git grep -l -e state_dir -- lua/")
    local readers = {}
    for _, s in ipairs(sidecars) do readers[s.reader] = true end
    it("lists readers", function()
        assert.equals(0, vim.v.shell_error)
        assert.is_true(#hits > 0, "the query found nothing; it is not reading what it claims")
    end)
    it("declares every reader", function()
        local undeclared = {}
        for _, file in ipairs(hits) do
            if not readers[file] and not PATH_ONLY[file] then undeclared[#undeclared + 1] = file end
        end
        assert.same({}, undeclared,
            "a new state_dir reader: add its sidecar to tests/helpers/sidecars.lua so sidecar_degrade_spec corrupts it")
    end)
    it("declares nothing that no longer reads it", function()
        local found, stale = {}, {}
        for _, file in ipairs(hits) do found[file] = true end
        for file in pairs(readers) do if not found[file] then stale[#stale + 1] = file end end
        for file in pairs(PATH_ONLY) do if not found[file] then stale[#stale + 1] = file end end
        table.sort(stale)
        assert.same({}, stale)
    end)
end)
```

- [x] **Step 5: Run.** Before Step 2's fix, the `state.json` and remote-cache
  cases fail (they throw). After it, all PASS.
- [x] **Step 6: Counterfactuals.** Edit, run, then restore with
  `git checkout -- <file>` (`git stash` is banned; see lessons).
  - (a) Revert `file_to_table` to the unguarded decode: the degrade spec goes
    red.
  - (b) Add `local _ = config.state_dir` to a clean
    `lua/parley/chat_presentation.lua`: the census goes red.
- [x] **Step 7: Commit** (`#261 M1: sidecars degrade — every reader is exercised corrupt`).

### Task 1.5: Documentation for M1

- [x] Delete `atlas/chat/recovery.md` and its `atlas/index.md:19` entry.
- [x] In `atlas/traceability.yaml`, delete the `chat/recovery:` block
  (`:349-358`), and the entries for `recovery_paths.lua` (`:809`),
  `traversal_policy.lua` (`:818`) and `tool_traversal_policy_spec.lua` (`:843`).
- [x] In `atlas/providers/tool_execution.md`, delete only the sentences about
  the private/recovery subtree: `:11-12`, `:47`, `:203-204`, `:237-241`, and the
  private-subtree sentences within `:142-147`. Read that paragraph first; the
  rest of it stays.
- [x] `README.md:82-84`: remove the answer-recovery sentence.
- [x] `atlas/chat/lifecycle.md` (Response), a short paragraph saying:
  - regenerating replaces the answer in the buffer;
  - the previous text is reachable through native undo;
  - nothing is kept on disk.

  How generated writes group into undo steps is stated once, in
  [ownership.md "Undo grouping"](ownership.md). Link to it; do not restate it.
- [x] `tests/manual/chat-concurrency.md:61-73`: drop recovery items 3-5; the
  section becomes "Batch".
- [x] Target: append a Revisions entry answering the open question "What bounds
  the in-session memory that replaces durable recovery?". The answer: none is
  kept. The only held copy is `prev_answer`, whose lifetime is one generation
  (M2).
- [x] **Removal query, final:** re-run Task 1.2's query. Expected: exactly one
  hit, the string `answer-recovery` in the Task 1.1 legacy test.
- [x] Commit (`#261 M1: atlas — the recovery store is gone`).

### Task 1.6: M1 boundary

- [x] `make test`, `make lint`. Compare any failure against `main` before
  touching it (lessons: "N failures, one cause is a hypothesis").
- [ ] `sdlc milestone-close --issue 261 --milestone M1`. Fix Critical and
  Important findings, sweeping each finding's whole class (lessons, memory).
  Log the verdict.

---

## Chunk 2: M2 — `prev_answer` (#255)

**First step of M2:** remove the `M2 · ` prefix from the Core-concepts rows
marked M2.

### Task 2.1: `State.holds`

**Files:** `lua/parley/document/state.lua` (next to `M.turn`); test
`tests/unit/document_state_spec.lua`.

- [x] **Step 1: Failing tests.**

```lua
    describe('holds',function()
        local function held()
            local h=State.new({epoch='e'})
            local g=State.transition(h,{kind='register_generation',input_snapshot={}}).generation
            local r=State.transition(h,{kind='acquire',generation=g,
                regions={{entity='E',first=0,last=4,marker_revision=1,revision=1,confirmed=true}}})
            assert.is_true(r.ok,r.reason)
            return h,g,r.grants[1]
        end
        it('is true for a live grant of that generation on that entity',function()
            local h,g=held(); assert.is_true(State.holds(h,g,'E'))
        end)
        it('is false for another entity or generation',function()
            local h,g=held()
            assert.is_false(State.holds(h,g,'F')); assert.is_false(State.holds(h,g+1,'E'))
        end)
        it('is false once the grant is revoked',function()
            local h,g,gid=held(); State.transition(h,{kind='revoke',grant=gid})
            assert.is_false(State.holds(h,g,'E'))
        end)
        it('is false once the generation finished',function()
            local h,g=held(); State.transition(h,{kind='finish_generation',generation=g})
            assert.is_false(State.holds(h,g,'E'))
        end)
        it('stays true while the grant is suspended',function()
            local h,g=held()
            State.transition(h,{kind='uncertain',first=0,last=4})
            assert.equals('suspended',State.snapshot(h).grants[1].status)
            assert.is_true(State.holds(h,g,'E'))
        end)
    end)
```

  Match the region fields to what `state.lua`'s `proof()` requires. The shape
  above is the one `generation_runner.lua:583-586` builds.
- [x] **Step 2:** FAIL. **Step 3: Implement.**

```lua
--- Does `generation` still hold a live grant on `entity`? Suspended counts: the
--- region is still its own, pending re-proof. The one question a prev_answer
--- slot asks of authority (#261, #255).
function M.holds(doc,generation,entity)
    for _,g in pairs(state(doc).grants) do
        if g.generation==generation and g.entity==entity and g.status~='revoked' then return true end
    end
    return false
end
```

- [x] **Step 4:** PASS. **Step 5:** Commit (`#261 M2: State.holds`).

### Task 2.2: `previous_answer.capture` / `substitute`

**Files:**
- Create `lua/parley/previous_answer.lua` and `tests/unit/previous_answer_spec.lua`.
- Lift `exchange()`/`parsed_chat()` from `tests/unit/build_messages_spec.lua:53-81`
  into `tests/helpers/parsed_chat.lua`, and give `exchange()` a `line_start`
  parameter. Today every exchange gets `10`, so "Q2 untouched" cannot be
  expressed.
- Route the spec under `chat/lifecycle`, and add `previous_answer.lua` to
  `chat/lifecycle`'s code list.

- [x] **Step 1: Failing tests.**
  - An entry at Q1's row replaces Q1's answer, summary and reasoning. Q2 is
    unchanged (deep-equal to the input's Q2).
  - `skip_index` is never substituted, even with a matching entry.
  - An entry whose row matches no question changes nothing.
  - Empty `entries` returns the same table (`rawequal`), not a copy.
  - The substituted `answer.line_start == question.line_end + 1`, and
    `build_messages` with `end_index` equal to that line includes it.
  - **Structured answer (#255):** an old answer whose `content_blocks` hold a
    `tool_use` and a `tool_result`. `capture` keeps them, and `build_messages`
    over the substituted chat emits the `tool_use`/`tool_result` messages.
  - The input `parsed` is not mutated. `capture` of an exchange without an answer
    is `nil`. Mutating a `capture` result leaves the source intact.
- [x] **Step 2:** FAIL. **Step 3: Implement.**

```lua
-- The previous answer of an exchange being regenerated (#261, #255), and its
-- substitution into a parsed chat for request context. Pure: the document
-- coordinator holds the value and decides whether it is still valid
-- (document/init.lua previous_answers); this module shapes and applies it.
local M={}

--- What request context reads of an exchange's answer.
function M.capture(exchange)
    if not exchange or not exchange.answer then return nil end
    return {answer=vim.deepcopy(exchange.answer),summary=vim.deepcopy(exchange.summary),
        reasoning=vim.deepcopy(exchange.reasoning)}
end

--- `parsed` with each entry's exchange carrying its previous answer. `entries`
--- are `{row=<0-based 💬: row>, value=<capture()>}`; `skip_index` is the exchange
--- being answered, whose own answer is never part of its input.
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

- [x] **Step 4:** PASS. **Step 5:** Commit (`#261 M2: previous_answer capture and substitute`).

### Task 2.3: The coordinator slot

**Files:** `lua/parley/document/init.lua`:
- `s.previous={}` in `M.attach` (`:239`);
- `s.previous={}` in the reload (`:214-223`) and detach (`:224-233`) branches;
- in `M.transition` (`:312-338`), after a successful `finish_generation`,
  remove that generation's slots;
- add the three functions below.

**Test:** `tests/integration/document_previous_answer_spec.lua`, routed under
`chat/document`. Set it up as in `tests/integration/document_turn_wake_spec.lua:11-26`
(`Fake.new`, `D.attach(nextbuf,{driver=…,schedule=false})`, `D.drain`).

- [x] **Step 1: Failing tests**, one per coordinator-owned row of the ARCH-ORDER
  table:
  - Set with a live grant: listed as `{row, generation, value}` for E's `💬:`
    row.
  - Set with no grant, or with a stale epoch: refused, nothing listed.
  - Revoke: nothing listed, **and** `_previous_count` drops to 0.
  - `finish_generation`: `_previous_count` is 0.
  - G is revoked, then G′ sets a slot on the same E, then G finishes: G′'s slot
    is still listed.
  - An edit deleting E's `💬:` marker: nothing listed.
  - Reload or detach: `_previous_count` is 0.
  - Two generations on two entities: both listed, each with its own value.
- [x] **Step 2:** FAIL. **Step 3: Implement.**

```lua
--- #261/#255: the answer a regeneration is replacing, kept beside the index
--- (which stores no transcript text), for request context only. Valid while the
--- regenerating generation holds a live grant on the exchange. Lifecycle:
--- workshop/plans/000261-transcript-is-the-whole-truth-plan.md, ARCH-ORDER.
function M.set_previous_answer(doc,spec)
    local s=state(doc)
    if s.dead or type(spec)~='table' or spec.epoch~=s.epoch or spec.value==nil
        or not State.holds(s.authority,spec.generation,spec.entity) then return false end
    s.previous[spec.entity]={generation=spec.generation,value=spec.value}
    return true
end
--- Every still-valid slot as `{row=<0-based 💬: row>, generation, value}`;
--- removes the rest.
function M.previous_answers(doc)
    local s=state(doc); local out={}
    if s.dead then return out end
    for entity,slot in pairs(s.previous) do
        local marker=State.holds(s.authority,slot.generation,entity) and M.lookup(doc,entity)
        if marker then out[#out+1]={row=marker.start_row,generation=slot.generation,value=slot.value}
        else s.previous[entity]=nil end
    end
    return out
end
--- Test seam: the raw slot count, so a test can prove removal, not filtering.
function M._previous_count(doc)
    local s=state(doc); local n=0
    for _ in pairs(s.previous or {}) do n=n+1 end
    return n
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

  Revocation has no coordinator hook, so `previous_answers` removes a revoked
  slot lazily. The revoke test therefore calls `previous_answers` before it
  asserts `_previous_count`.
- [x] **Step 4:** PASS. **Step 5:** Commit (`#261 M2: the coordinator's prev_answer slot`).

### Task 2.4: Set the slot; substitute it in the same chat

**Files:** `lua/parley/chat_respond.lua`, `start_scoped_response` (`:1391-1722`).
Test: `tests/integration/chat_respond_spec.lua`, in the scoped-session
`describe`; the payload is on `calls[i].payload`.

- [x] **Step 1: Tests.**
  - *Characterization (passes on main, because the gap is written only just
    before the first write):* regenerate Q1 (answered `old one`), then submit Q2
    before Q1 emits. Q2's payload contains `old one`.
  - **Mid-stream:** `output(calls[1],'new partial')`, wait for it to appear in
    the buffer, then submit Q2. The payload contains `old one`, not
    `new partial`.
  - **After Q1 completes** with `new one`: Q2's payload contains `new one`, not
    `old one`.
  - **After Q1 is revoked** (edit its partial): Q2's payload contains the edited
    partial, which is the transcript's truth.
  - **Already captured:** submit Q2 mid-stream, then complete Q1.
    `calls[2].payload` still contains `old one`.
  - **Capture, then late build** (the event most likely to be mishandled):
    1. Stub `Respond.resolve_remote_references` so it keeps its `build`
       continuation instead of calling it.
    2. Submit Q2 mid-stream. Q2's question carries a remote reference, so the
       stub is reached.
    3. Complete Q1.
    4. Call the kept `build`.

    Q2's payload contains `old one`, and neither the header nor `new partial`.
  - **Raw-request mode:** with a live slot, Q2 carries a typed raw payload
    (`question.raw_payload`, set by `build_messages` at `:831`). The payload
    sent is the raw one. The same holds in a batch leg (`frame.input_rows`).
- [x] **Step 2:** The non-characterization tests FAIL.
- [x] **Step 3: Implement.**
  1. Move `local doc = D.get(buf) or D.attach(…)` (`:1443`) above the
     `exchange.answer = nil` line (`:1432`).
  2. Right after it, in this same tick:

```lua
    -- #261/#255: an earlier exchange still being regenerated contributes its
    -- previous answer, not the header or partial text now in the buffer. Here,
    -- in the tick the command read the lines — build() runs later, after
    -- readiness and remote fetches, when that generation may have ended.
    local PrevAnswer = require('parley.previous_answer')
    parsed = PrevAnswer.substitute(parsed, D.previous_answers(doc), index)
    exchange = parsed.exchanges[index]
    question = exchange.question
    local previous = exchange.answer and PrevAnswer.capture(frame.parsed.exchanges[index]) or nil
```

     `frame.parsed` is the command-time parse, and the grant guarantees its
     answer is exactly the bytes the gap will remove. `question` is re-bound
     because it pointed into the old table.
  3. At `:1575`, read the raw payload from the input the request was built
     from. This also fixes the batch-leg copy:
     `final_payload = input_parsed.exchanges[input_index].question.raw_payload or …`.
  4. At the top of `prepare_input(ctx, cb)`:

```lua
        if previous then
            D.set_previous_answer(doc, {epoch = ctx.epoch, entity = ctx.entity,
                generation = ctx.generation, value = previous})
        end
```

- [x] **Step 4:** PASS. **Counterfactual:** move the `substitute` call into
  `build()`; the capture-then-late-build test fails. Restore.
- [x] **Step 5:** Commit (`#261 M2: a regenerating answer's predecessor feeds context`).

### Task 2.5: Generated writes never make another generation's input stale

**Files:** `lua/parley/document/state.lua:272-284`. Tests:
`tests/unit/document_state_spec.lua`, and one integration case in
`tests/integration/chat_respond_spec.lua`.

- [x] **Step 1: Failing tests.**
  - Unit: generation A has a prefix dependency.
    - Generation B's granted write (an `observed_edit` whose `owner_grant` is
      B's grant) lands inside A's range: A is **not** stale, and A's range moved
      by the insertion.
    - A human edit (no `owner_grant`) lands inside A's range: A **is** stale, as
      before.
  - Integration: Q1 is regenerating and streaming, and Q2 is submitted with a
    tool call. Q2's tool round continues without a stale-input pause.
- [x] **Step 2:** FAIL. **Step 3: Implement.** In the dependency loop, when
  `owner` is non-nil and `owner.generation ~= gen.id`, call `move(dep,event)`
  without marking stale. Replace the comment's "other owners" clause with the
  #255 rationale (see ARCH-ORDER, Consumer side).
- [x] **Step 4:** PASS. Run `make test-spec SPEC=chat/document`, and the
  `generation_input_affinity_spec` and `generation_turn_spec` suites. Any test
  that asserts another owner's write marks input stale is **asserting the
  reversed rule**: update it, and say so in the commit body.
- [x] **Step 5:** Commit (`#261 M2: only human edits make captured input stale`).

### Task 2.6: Ancestors from the live buffer

**Files:**
- `lua/parley/helper.lua` (`chat_lines`), `lua/parley/init.lua:3798-3800`, and
  `lua/parley/chat_respond.lua:176-221` (`collect_ancestor_chain`).
- Tests: `tests/unit/helper_spec.lua`, `tests/integration/chat_respond_spec.lua`,
  and a loaded-buffer case in the spec that covers `init.lua:3798`. Find it with
  `grep -rln "3798\|branch.*rename\|chat_move" tests/integration`; the reviewer
  names `chat_move_spec`.

- [x] **Step 1: Failing tests.**
  - `chat_lines`:
    - A loaded buffer whose unsaved text differs from disk returns the buffer's
      lines and its number.
    - An unloaded path returns the disk contents and `nil`.
    - A buffer whose name only *contains* the path is not matched.
    - A loaded buffer that was never saved (no file) returns its lines.
  - **Sub-chat, parent regenerating:** parent P has Q1 answered `old one`, and a
    branch link to child C.
    1. Regenerate P's Q1 and stream `new partial`.
    2. `:write` P, so disk holds the partial (the fixture has no autosave).
    3. In C, ask a question.

    C's payload contains `old one`, not `new partial`.
  - **Sub-chat, parent unsaved:** P is loaded with an unsaved edit to Q1's
    answer, and no generation is running. C's payload holds the edited text.
  - The branch-link rewrite at `init.lua:3798`, with the target loaded: the
    buffer is rewritten, and the file is not written under it.
- [x] **Step 2:** FAIL. **Step 3: Implement.**

```lua
--- A chat's current text: its loaded buffer if one is open under this path,
--- else the file. Compares resolved absolute names — bufnr(path) is a
--- file-pattern match and can return a buffer whose name merely contains it.
--- Returns nil when neither exists.
_H.chat_lines = function(path)
    local want = vim.fn.resolve(vim.fn.fnamemodify(path, ":p"))
    for _, buf in ipairs(vim.api.nvim_list_bufs()) do
        if vim.api.nvim_buf_is_loaded(buf) then
            local name = vim.api.nvim_buf_get_name(buf)
            if name ~= "" and vim.fn.resolve(vim.fn.fnamemodify(name, ":p")) == want then
                return vim.api.nvim_buf_get_lines(buf, 0, -1, false), buf
            end
        end
    end
    if vim.fn.filereadable(path) == 1 then return vim.fn.readfile(path), nil end
    return nil
end
```

  In `collect_ancestor_chain`, replace the `filereadable` check and `readfile`
  (`:193-198`) with
  `local parent_lines, parent_buf = _parley.helpers.chat_lines(abs_parent)`.
  When it returns nil, warn and return `{}`. After `parent_parsed` is built:

```lua
    local parent_doc = parent_buf and require('parley.document').get(parent_buf)
    if parent_doc then
        parent_parsed = require('parley.previous_answer').substitute(parent_parsed,
            require('parley.document').previous_answers(parent_doc), nil)
    end
```

  At `init.lua:3798-3800`, use
  `local lines, live_buf = M.helpers.chat_lines(new_path); local live = live_buf ~= nil`.
  `live_buf` and `live` are still used at `:3815` and `:3824`.
- [x] **Step 4:** PASS. **Counterfactual:** make `chat_lines` read the file
  only; the unsaved-parent test fails. Restore.
- [x] **Step 5:** Commit (`#261 M2: ancestors read the parent's live buffer`).

### Task 2.7: Documentation, and M2's boundary

- [x] `atlas/chat/lifecycle.md` (Response): a "Previous answer while
  regenerating" paragraph covering:
  - the slot's lifetime;
  - same-chat and ancestor substitution;
  - "any outcome ends it";
  - only human edits make captured input stale.

  Link this plan's ARCH-ORDER table for the event list. `ownership.md` links
  here and does not restate it.
- [x] `atlas/chat/document.md` "Ownership and data flow": the coordinator holds
  `prev_answer` beside the index, which still stores no transcript text.
- [x] The atlas page that documents ancestor context (`grep -rln "ancestor" atlas/`):
  a loaded parent is read from its buffer.
- [ ] `make test`, `make lint`; `sdlc milestone-close --issue 261 --milestone M2`;
  log the verdict.

---

## Chunk 3: M3 — processes die for certain

**First step of M3:** remove the `M3 · ` prefix from the Core-concepts rows
marked M3.

Operator decisions for this milestone:
- *"we need to have 100% confidence we can kill what we started"*;
- *"regarding 'kernel hold', it's fine"*;
- process groups for generation-owned processes only;
- deadlines per kind.

### What is broken today (verified 2026-09-18)

- **Children share Neovim's process group.** `tasker.lua:475` passes
  `detach = true`, but luv's key is `detached` (luvref.txt, `uv.spawn`).
  Measured: under `detach` the child's pgid is nvim's; under `detached` it is
  the child's own pid. (`cliproxy.lua:667` spells it correctly.)
- **Stop sends one SIGTERM to one pid, and only while the parent has not
  exited** (`stop_matching`, `tasker.lua:263-289`, with the `not state.exited`
  guard at `:271`).
  - `reconcile_step` (`:202-221`) probes with signal 0 and never escalates.
  - There is no SIGKILL anywhere in `lua/`.
  - After 5 s, the record and its admission slot are kept forever
    (`:213-216`).
- **A parent that exited while a grandchild holds the pipe is never signalled.**
  `tasker.lua:462-464` records the exit, and `:271` then skips the record.
- **A late Stop never escalates.** `reconcile_started` is set once, by the first
  stop *or exit* (`attempt.lua:27-29`). After `unresolved_visible`, the ticks
  stop (`attempt.lua:31-32`, `tasker.lua:187`).
- **An ESRCH race raises** (`scoped_stop`, `:295-299`), which skips the rest of
  the caller's cleanup (provider cancel, topic cancel).
- **A kill looks like success.** luv reports `code=0 signal=15` for a killed
  child.
  - Callbacks that test only `code` would treat a partial body as success:
    vault.lua:124; oauth.lua:1331, 1339, 1404, 1611, 1660, 1686; and the
    pass-throughs at 1007, 1777, 1795, 1910, 1927.
  - Worst case: `load_account_store` would cache an *empty* account store
    (oauth.lua:859-864), and the next save would erase the keychain's other
    accounts.
- **20 processes have no owner and no end:** the 18 `tasker.run(nil, …)` sites,
  plus 2 dispatcher streams without transport opts (see the ARCH-CONSTRAINTS
  table).
- **A refused spawn without `on_start_error` never calls back**
  (`reject`, `tasker.lua:379-386`).
- **The fake cannot see any of this.** `tests/helpers/fake_process.lua` ignores
  spawn options and has no groups.

### The model

- **Scope = generation.**
  - The key is `<epoch>:<generation>`. Today it is built in two spellings
    (`response_provider.lua:102`, `tools/producer.lua:120`); M3 makes it one
    function, `tasker.scope_key`.
  - A run carrying `logical_generation` is **scoped**. It is spawned
    `detached=true`, killed as a group (`-pid`), and stopped with its scope.
  - A run without one is **unscoped**. It stays attached to Neovim's session, is
    killed by pid, and **must** declare `deadline_ms`; tasker refuses it
    otherwise.
- **Stop escalates while the record is unresolved**, not merely while the
  parent is alive.
  - TERM now; KILL at `kill_due = stop + 2000` if the record is still
    unresolved.
  - Repeated stops, and a deadline after a stop, leave `kill_due` unchanged.
  - The reconcile tick is clamped, so KILL lands at 2 s rather than at the next
    back-off tick.
- **A kill Parley caused is a failure to its callback.** The exit callback gets
  `code = nil` and `io_error = 'killed: <cause>'`, where the cause is `stop`,
  `deadline` or `leave`. Every unscoped callback is swept to treat
  `code == nil or code ~= 0 or io_error` as failure.
- **Every run settles.** A refused spawn with no `on_start_error` delivers
  `callback(nil, nil, nil, nil, reason)`, through `call_safely`.
- **Neovim exit.** `tasker.leave()` stops every live record with SIGKILL.
  `init.lua` `M.setup` registers it on `VimLeavePre`, next to
  `M.setup_buf_handler()` (`:1333`).
  - **Residual:** Neovim itself crashing. Then no autocmd runs, and orphans run
    to their own end.

### ARCH-ORDER — the attempt lifecycle

| State | Event | Next | Effect |
|---|---|---|---|
| live | `stop_requested(now)` | stopping; `kill_due = now+2000` (only if unset) | SIGTERM (group or pid) |
| live | `deadline(now)` | as `stop_requested`, cause `deadline` | as above |
| exited, EOF missing | `stop_requested(now)` | stopping; `kill_due` as above | SIGTERM to the **group** (scoped): the grandchild case |
| stopping | `stop_requested` / `deadline` again | unchanged (`kill_due` kept) | none |
| stopping | `reconcile_tick(now ≥ kill_due)`, unresolved | stopping, `escalated` | **`escalate`**: SIGKILL, once |
| stopping | exit + both EOFs | resolved | release slot; `io_error='killed: <cause>'` if we signalled it |
| stopping | `reconcile_tick(now ≥ stop+5000)` | unresolved-visible | log with pid; `on_unresolved`; listed by `tasker.held()` |
| unresolved-visible | `stop_requested` | stopping again (new window) | TERM, and KILL at +2 s |

**Most likely to be mishandled:** a late Stop on a record whose window was
opened by its *exit* (the grandchild case). The table's third and last rows
exist for it, and Task 3.2 tests it.

### Task 3.1: The fake models groups; spawn uses `detached` for scoped runs

**Files:** `tests/helpers/fake_process.lua`; `lua/parley/tasker.lua:470-476`;
test `tests/unit/tasker_unit_spec.lua`.

- [x] **Step 1: Extend the fake.** Keep every existing option and behaviour,
  and add:
  - **Groups.** `spawn_opts.detached == true` sets `pgid = pid`; otherwise
    `pgid = 0`, standing for Neovim's group.
  - **Group signals.** `kill(-pgid, sig)` signals every live member, and records
    one `{pid=member, signal=sig, group=true}` entry **per member**. The eight
    existing `.signals` assertions (`grep -rn "\.signals" tests`) check the
    leader's positive pid, so they keep passing.
  - **Ignored signals.** Each process takes `ignores = {[15]=true}` (and `[9]`
    for a kernel hold). A signal it does not ignore exits it.
  - **Grandchildren.** `process:fork()` creates a grandchild in the same group
    that holds the same pipes. With the opt-in `pipes_follow_holders = true`,
    EOF is delivered only once every holder has exited. It defaults to off,
    because today `exit()` does not EOF (`fake_process.lua:36-45`).
  - **Spawn options.** `state.spawn_options` records each spawn's options.
- [x] **Step 2: Failing tests:** a scoped `tasker.run` spawns with
  `detached=true`; an unscoped one spawns without it.
- [x] **Step 3: Implement:** set `detached = opts.logical_generation ~= nil` in
  the spawn options, and store `state.group = detached`. PASS.
- [x] **Step 4:** Commit (`#261 M3: a generation's processes lead their own group`).

### Task 3.2: Escalation in the pure lifecycle

**Files:** `lua/parley/attempt.lua`; test `tests/unit/attempt_spec.lua`.

- [x] **Step 1: Failing tests**, one per table row, plus:
  - KILL is due at exactly `stop+2000` (the reconcile tick is clamped to
    `kill_due`);
  - an exit at `+1000` with both EOFs: no `escalate`;
  - an exit at `+100` without EOF (the grandchild case), then `stop_requested`
    at `+3000`: the window reopens, and `escalate` fires at `+5000`;
  - a second `stop_requested` at `+1500` does not move `kill_due`.
- [x] **Step 2:** FAIL. **Step 3: Implement** the table:
  - the `kill_due`, `escalated` and `stop_cause` fields, and the `deadline`
    event;
  - the tick clamp: `reconcile_due = math.min(reconcile_due, kill_due)` while
    not escalated;
  - a `stop_requested` after `unresolved_visible` opens a new window.

  Return `escalate` next to `probe` and `unresolved`.
- [x] **Step 4:** PASS. **Step 5:** Commit (`#261 M3: the attempt lifecycle escalates`).

### Task 3.3: Group kill, scopes, deadlines, settling spawns, kill reporting

**Files:** `lua/parley/tasker.lua`; `lua/parley/response_provider.lua:102` and
`lua/parley/tools/producer.lua:120` (both consume `scope_key`). Tests:
`tests/integration/tasker_supervision_spec.lua`, `tests/unit/tasker_unit_spec.lua`,
and `tests/integration/tasker_run_spec.lua`. That last spec calls `tasker.run`
43 times with no opts (`grep -c "tasker.run(" tests/integration/tasker_run_spec.lua`),
so every call is unscoped and has no deadline. Once the refusal lands, each one
needs `{deadline_ms = …}`. Sweep them in this task, and re-run the grep for any
other spec that calls `tasker.run` directly: `grep -rln "tasker.run(" tests`.

- [x] **Step 1: Failing sequence tests** on the fake. Each ends with the record
  gone (or held, where stated) and `tasker.stats().active` back at its baseline.
  1. A scoped process ignores TERM. Stop → SIGKILL to the group at 2 s →
     resolved.
  2. A scoped parent exits on TERM while a forked grandchild holds stdout. The
     group TERM ends both → resolved.
  3. A scoped parent has already exited while a grandchild holds the pipe.
     Stop → group TERM → resolved.
  4. The process exits between TERM and KILL: no SIGKILL is sent.
  5. The process is gone before stop (ESRCH): no raise; observed as `missing`.
  6. `stop_scope(k)` signals exactly the records with `logical_generation == k`.
  7. An unscoped run with `deadline_ms` is killed by pid at the deadline. Its
     callback gets `code=nil, io_error='killed: deadline'`.
  8. An unscoped run without `deadline_ms` is refused, and its callback is
     delivered with the reason.
  9. A refused spawn with no `on_start_error` calls the exit callback once, with
     `(nil,nil,nil,nil,reason)`. A throwing callback is contained.
  10. A scoped kill by stop: the callback gets `code=nil, io_error='killed: stop'`.
  11. A process that ignores KILL goes unresolved-visible at 5 s. It is logged
      with its pid, listed by `tasker.held()` as `{pid, kind, since, scope}`,
      and still counted.
- [x] **Step 2:** FAIL. **Step 3: Implement.**
  - `M.scope_key(epoch, generation)` returns
    `tostring(epoch)..':'..tostring(generation)`. Replace both spellings with it.
  - `stop_matching`:
    - match unresolved records, not "not exited" ones;
    - target `state.group and -state.pid or state.pid`;
    - treat ESRCH as the observation `missing`, not a failure;
    - dedupe per signal, as today.
  - `reconcile_step`: on `escalate`, send SIGKILL to the same target while the
    record is unresolved.
  - Add `M.stop_scope(key, signal)`, `M.held()`, and `M.leave()`. `leave` stops
    all with signal 9 and cause `leave`.
  - `M.run`: refuse an unscoped run without `deadline_ms`. Arm a deadline timer
    (`record.runtime.new_timer`), retired together with the record.
  - `reject`: without `on_start_error`, schedule
    `callback(nil,nil,nil,nil,message)` through `call_safely`.
  - On exit after a signal Parley sent, pass `code=nil` and
    `io_error='killed: '..cause`.
- [x] **Step 4:** PASS. **Counterfactual:** target `state.pid` instead of the
  group; tests 2 and 3 fail. Restore.
- [x] **Step 5:** Commit (`#261 M3: stop kills a scope as groups, escalating to SIGKILL`).

### Task 3.4: Every unscoped run declares its end; callbacks read kills as failure

**Files:** `lua/parley/vault.lua`, `lua/parley/oauth.lua`,
`lua/parley/memory_prefs.lua:255`, `lua/parley/chat_respond.lua:1147`
(`generate_topic`), and the dispatcher's `transport_opts` path
(`dispatcher.lua:853`).

- [x] **Step 1:** Re-run the census:
  `grep -rn "tasker\.run(nil" lua/parley` and
  `grep -rn "dispatcher.query(" lua/parley | grep -v "^lua/parley/dispatcher.lua"`.
  The results must match the ARCH-CONSTRAINTS table; if they don't, correct the
  table first.
- [x] **Step 2: Failing tests**, one per kind:
  - a killed keychain read does **not** cache an empty account store
    (`load_account_store`, oauth.lua:859-864);
  - a killed copilot-token curl reports failure without throwing (today
    vault.lua:208 formats the code with `%d`);
  - a killed content fetch is not cached as content
    (chat_respond.lua:1279-1280).
- [x] **Step 3: Implement.**
  - Pass `deadline_ms` per the table at every site, using
    `transport_opts.deadline_ms` for the two streams.
  - Sweep each callback in the census so that
    `code == nil or code ~= 0 or io_error` counts as failure, and a failure never
    writes a cache or a store.
- [x] **Step 4:** PASS. **Step 5:** Commit (`#261 M3: every process Parley starts names its end`).

### Task 3.5: Leaving Neovim kills what is left

- [x] In `init.lua` `M.setup`, next to `M.setup_buf_handler()` (`:1333`):
  `vim.api.nvim_create_autocmd('VimLeavePre', {group = …, callback = function() require('parley.tasker').leave() end})`.
- [x] **Test** `tasker.leave()` directly on the fake, not through a global
  `VimLeavePre` (`starter.lua:120` also listens). Every live record got SIGKILL:
  scoped records by group, unscoped ones by pid.
- [x] Commit (`#261 M3: leaving Neovim kills every live process`).

### Task 3.6: Live conformance

**Files:** Create `tests/integration/process_group_conformance_spec.lua`, and
route it with the tasker specs in `atlas/traceability.yaml`. It runs on every
`make test`, and is `pending()` when `sh` is not executable.

- [x] A scoped `tasker.run` of `sh -c 'kill -0 -$$ && echo leader'` prints
  `leader`, which shows the process leads its own group. It avoids `ps`, which
  some sandboxes block.
- [x] A scoped run of `sh -c 'trap "" TERM; sleep 30 & wait'` ignores TERM, and
  its grandchild holds stdout. Then `stop_scope`: the record resolves within
  4 s, and `kill -0` of the grandchild's pid fails.
- [x] The same, through `tools/process_bootstrap` (the real tool spawn path).
- [x] On main (key `detach`), the first case fails; on the branch, PASS.
- [x] Commit (`#261 M3: live conformance for process groups`).

### Task 3.7: Documentation, and M3's boundary

- [x] `atlas/providers/tool_execution.md` (process bounds) and
  `atlas/chat/lifecycle.md` (Stop). Cover:
  - scoped vs unscoped runs;
  - TERM, then KILL at 2 s;
  - deadlines by kind (link the ARCH-CONSTRAINTS table);
  - kills reported as failures;
  - `VimLeavePre`.

  State the residuals once: a kernel hold; a grandchild of a user-configured
  secret command; Neovim crashing.
- [x] The `atlas/infra` page for the vault/secret command: a
  terminal-prompting secret command still works (unscoped runs stay attached),
  and it is killed at 600 s.
- [x] `tests/manual/chat-concurrency.md`: Stop during a long tool (`find /`),
  then submit again at once.
- [ ] `make test`, `make lint`; `sdlc milestone-close --issue 261 --milestone M3`.

---

## Chunk 4: M4 — every wait a generation holds settles

**First step of M4:** remove the `M4 · ` prefix from the Core-concepts rows
marked M4.

The runner reaches `terminal` only when every operation confirms
(`generation.lua:153-158`), and `active` drops only there
(`generation_runner.lua:532`).

### The enumeration

Queries:
- the runner's waits: `grep -n "operation(s,effects\|start_children" lua/parley/generation.lua`,
  then each adapter's cancel path;
- the `Deferred` class: `grep -rn "Deferred.new\|deferred_work').new" lua/parley`;
- other document generations: `grep -rn "register_generation" lua/parley`.

| # | Wait | Fails to confirm when | Fix |
|---|---|---|---|
| W1 | any op whose start threw | handle nil; `response_session.lua:231` returns false, no `done` | runner: at cancel, an op with no handle confirms. Use `operation_supervised` for a `child`: `operation_resolved` is refused for a child without an outcome (`generation.lua:441-446`), while supervised is accepted in stopping/flushing (`:437`). Use `operation_resolved` otherwise |
| W2 | prepare · `operation:cancel` (`chat_respond.lua:1531-1536`) | resolves only via `build`/`ready` | resolve at once; `build`/`ready` already no-op when cancelled |
| W3 | prepare · readiness UI (`llm_readiness.lua:84-150`) | picker never calls back | W2; a late `on_select` fails `validate_source` |
| W4 | prepare · remote content fetch (`chat_respond.lua:1185-1297`) | unowned curl; refused spawn → no callback; `fetch_content` throws → `pending` stuck | pass `logical_generation = scope_key(ctx.epoch, ctx.generation)` to `fetch_content`, and through its **content** tree only: public, Google, Dropbox, Microsoft and office conversion (not keychain or refresh, which are shared). Pcall the call at `:1289-1292`. On a throw, mark that child `done`; that is safe now because the scope kill ends anything it started (update the comment at `:1287-1288`) |
| W5 | request · pre-spawn (`response_provider.lua:110-121`) | zero tasker match → waits | if `stop_owner` matched nothing, resolve at once. A late callback aborts via `transport_alive` (`dispatcher.lua:852,885`; covered by `response_provider_spec.lua:71-80`) |
| W6 | request · copilot `pre_query` (`vault.lua:159-219`) | `code~=0` (`:207-209`), the early return (`:161-162`), and a token body that does not decode never call back (the decode itself was a raise until M1 review BR-16 guarded it) | call back with the error on all three paths |
| W7 | request · async continuation (`dispatcher.lua:446-854`) | a throw → nothing aborts | pcall it; on error, `abort_before_start` |
| W8 | request · `recover_query` (`dispatcher.lua:794-828`) | no liveness check | check `transport_alive` before acting |
| W9 | child · `producer.start` threw | `producer.cancel(nil)` false | W1; its processes die with the scope |
| W10 | child · refused first `child_outcome` (`response_tools.lua:73-75`) | the adapter records an outcome the machine rejected; the later `resolved(nil)` is refused | reproduce it first. Then the adapter records an outcome only once the machine accepts it. If the case can't be reached through public events, log that and drop the row |
| W11 | `continue_round` threw | nil handle | W1 |
| W12 | finalize · `response_completion.start` returned nil | `done` never called | `done('failed')` |
| W13 | a `Deferred` step threw (`deferred_work.lua:19`) | the work cancels itself; its owner never settles | `Deferred.new(step, on_error)`. The query returns ten owners. The five that hold a generation, a target slot or a turn settle failed: `response_completion` (`:91`), `response_preparation` (`:146`), `response_topic` (`:106`), `response_target` (`:110`), and the runner (`:609`, via `fault` below). Out of scope, because none holds admission, a grant or a turn: `document/init.lua:67` (the repair pump, which self-heals on the next `schedule(doc)`), `diagnostic_refresh.lua:216`, `tool_folds.lua:468` and `outline.lua:289` (presentation pumps). `chat_recovery.lua:258` is deleted in M1 |
| W14 | runner start (`generation_runner.lua:605-615`) | `active` +1 before throwing calls; generation registered, grants held, subscriber and timer live | increment last. On a throw after `register_generation`: `s.off()`, `s.work:close()`, `finish_generation`, drop `runners[r]`, and **return `nil, reason`** (the caller handles it, `response_submission.lua:62-63`) |
| W15 | topic cancel (`response_topic.lua:47`) | a raise skips `Session.cancel` (`chat_respond.lua:1313-1315`) | pcall it |
| W16 | topic generation · `s.provider.request` threw (`response_topic.lua:80`, reached from `:154`; `s.started=true` at `:59`) | `s.started` set, `s.handle` nil; `stop()` (`:45-50`) takes neither branch, so it stays stopping forever, holding a `generation limit` slot and two user captures | `stop()` finishes directly when there is no handle |
| W17 | `skill_invoke._in_flight[buf]` (`:23`, `:402`) | keyed by buffer number, which `:e!` and `:bd`+reopen reuse; released only when the physical read resolves; `stop_owner` unguarded (`:161`) | release on the document's detach/reload and on `BufUnload`; pcall `stop_owner` |
| W18 | finalize · the adapter's returned `{cancel=…}` handle (`chat_respond.lua` finalize) | `generation_runner.lua:502` discards it, so cancellation mid-finalize relies only on `response_completion`'s own subscription and `ctx.cancelled` (M1 review, Minor) | the runner keeps the handle and calls its `cancel` on stop, or the adapter stops returning one — decide with W12, and test cancellation during finalize |

**Runner fault and the scope kill.** Two runner additions close what the table
cannot.
- **`fault(s, err)`** is the runner's `on_error`. It kills the scope, then runs
  the terminal cleanup with outcome `fault`. This is the one way a runner reaches
  `terminal` with operations still outstanding, and it is used only when the
  runner's own step threw.
- **The scope kill runs once.** It fires on whichever comes first — the machine
  entering `stopping`, or `terminal` — before `s.adapters={}`
  (`generation_runner.lua:535`).
  - It checks `G.phase(s.machine)` (`generation.lua:244-246`), not `G.snapshot`
    (lessons: no snapshot before an O(1) check on a hot path).
  - Both entry points are needed: a generation can go stopping → terminal in
    one dispatch, and a successful one never enters `stopping`.
  - The adapter is `adapters.stopping(ctx)`. `response_session` implements it as
    `tasker.stop_scope(tasker.scope_key(ctx.epoch, ctx.generation))`.

### ARCH-ORDER — the invariant M4 defends

**Every generation that enters `stopping` reaches `terminal` within the kill
bound (2 s, plus draining its effects), unless a process is held in the kernel.
`Runner.stats().active` equals the number of generations not yet terminal.**

Test strategy: a new spec, `tests/integration/generation_settles_spec.lua`,
routed under `chat/lifecycle`.
- It is built on the fake-runtime harness of
  `tests/integration/dispatcher_ownership_spec.lua`, so real tasker records are
  in the loop.
- One case per row, W1–W17. Each case:
  1. arranges for the leaf never to call back (or to throw);
  2. triggers each stop cause that applies (Stop, a revoking edit, `:e!`,
     `:bd`);
  3. asserts `terminal`.
- `after_each` asserts `Runner.stats().active == 0` and
  `tasker.stats().active == 0`, so a leak also fails the *next* case.
- Fake timers fire only on `timer:fire()`, so each ordering is reproduced by the
  sequence of fires.

### Task 4.1: Runner — `stats`, W14, W1/W11, `fault`, the scope kill

**Files:** `lua/parley/generation_runner.lua`, `lua/parley/deferred_work.lua`;
test `tests/integration/generation_settles_spec.lua`.

- [x] **Step 1: Failing tests** for:
  - W1, W11 and W14;
  - `fault` (a step that throws);
  - the scope kill on stopping, and on a direct terminal;
  - `stats()`.
- [x] **Step 2: Implement** per the table and the "Runner fault" paragraph.
  `Deferred.new(step, on_error)`: with `on_error`, the error path calls it
  instead of rethrowing; without it, behaviour is unchanged.
- [x] **Step 3:** PASS. **Step 4:** Commit (`#261 M4: the runner settles what it cannot cancel`).

### Task 4.2: Session, provider, preparation, completion, topic, target

**Files:**
- `lua/parley/response_session.lua`: `stopping`, and W2's prepare branch;
- `lua/parley/response_provider.lua`: W5;
- `lua/parley/chat_respond.lua`: W2, W12;
- `lua/parley/response_topic.lua`: W13, W15, W16;
- `lua/parley/response_target.lua`, `lua/parley/response_completion.lua` and
  `lua/parley/response_preparation.lua`: W13.

- [x] **Step 1: Failing tests** for W2, W3, W5, W12, W13 (each owner), W15 and W16.
- [x] **Step 2: Implement** per the table. **Step 3:** PASS.
- [x] **Step 4:** Commit (`#261 M4: preparation, provider, completion and topics settle on cancel`).

### Task 4.3: Helpers a generation calls

**Files:** `lua/parley/oauth.lua` (`fetch_content` at `:2386`, and its content
tree), `lua/parley/chat_respond.lua:1185-1297`, `lua/parley/vault.lua:159-219`,
`lua/parley/dispatcher.lua`.

- [x] **Step 1: Failing tests** for:
  - W4: a fetch that never exits. Stop → its group is signalled through the
    scope.
  - W6, W7 and W8.
- [x] **Step 2: Implement.** **Step 3:** PASS.
- [x] **Step 4:** Commit (`#261 M4: helpers a generation starts share its scope or settle`).

### Task 4.4: Tools and skills

**Files:** `lua/parley/response_tools.lua` (W10), `lua/parley/skill_invoke.lua` (W17).

- [x] **Step 1: Failing tests** for W9, W10 (reproduce it first) and W17. The
  W17 test runs `:bd`, reopens the same file (asserting the buffer number is
  reused), then runs a skill: it is not refused as "already running".
- [x] **Step 2: Implement.** **Step 3:** PASS.
- [x] **Step 4:** Commit (`#261 M4: tools and skills settle and follow the buffer`).

### Task 4.5: The reported shape, end to end

In `tests/integration/generation_settles_spec.lua`, on the fake runtime, with a
provider curl that ignores TERM:

- [x] Submit, Stop, and fire the fake timers past 2 s → `terminal`, and `active`
  is back at its baseline. Repeat 5 times in one buffer: the 5th submission is
  admitted. Before M3/M4 it is refused with `generation limit` (`state.lua:205`).
- [x] Repeat 17 times across `:e!` reloads: the 17th is admitted. Before M3/M4
  it is refused with `process generation limit` (`generation_runner.lua:574`).
- [x] `:bd`, reopen the same file (same buffer number), submit → admitted.
- [x] Commit (`#261 M4: a stopped response never holds a slot`).

### Task 4.6: Documentation, and M4's boundary

- [ ] `atlas/chat/lifecycle.md` (Stop): the invariant above, pointing at
  `generation_settles_spec.lua`. `ownership.md` links to it.
- [ ] `make test`, `make lint`; `sdlc milestone-close --issue 261 --milestone M4`.

---

## Chunk 5: M5 — one refusal vocabulary, and the inventory

**First step of M5:** remove the `M5 · ` prefix from the Core-concepts rows
marked M5.

### What is broken today (verified 2026-09-18)

- **Silent returns: the caller drops `nil, reason`** at
  `chat_respond.lua:1400` (`no question selected`), `:1948`, `:1951`, `:1956`
  and `:1960` (`no questions selected`, the most common). The command loop
  (`init.lua:1317-1331`) discards every return value.
- **Silent non-success endings.** The single-response `terminal` handler reports
  only `failure_notice` and `overflow`.
- **Raw tokens, over two channels:** `:1691` uses `logger.warning`; `:1542` uses
  `pcall(vim.notify)`, which shows only the first line and does not log. Raw
  tokens also appear in:
  - `Response not resumed` (`:1387`);
  - `Batch not started|resumed|paused` (`:1943`, `:1992`, `:1994`, `:2004`,
    `:2011`);
  - `Drill-in stopped` (`:1809`, `:1820`, `:1865`, `:1872`).
- **False messages.**
  - `cmd_respond` (`:2020-2032`) says "Forcing response even if another process
    is running", and passes a 4th argument that `M.respond` never reads.
  - `init.lua:4171` calls a `resubmit_questions_recursively` that no longer
    exists.
- **Provider failures surface as a raw `failure` string** under outcome
  `provider_failed` (`response_session.lua:133,135,170,179`;
  `response_provider.lua:70,83,104`).
- **A user Stop** ends as outcome `cancelled`, with failure `operator stopped
  response`. Other paths also end `cancelled` (`generation_runner.lua:282,440`),
  and those should warn.
- **#265** owns the `buffer_edit.replace_user_lines` refusals, which are not on
  these paths. It should consume this vocabulary.

### The model

`lua/parley/refusal.lua` is pure. Producers keep their tokens, because control
flow reads several of them (`generation_runner.lua:275-276` and others); this
module owns the words.

- **`PREFIX`:** `start` "Response not started", `resume` "Response not
  resumed", `batch_start`, `batch_resume`, `batch_paused`, `ended` "Response
  stopped", `drill` "Drill-in stopped".
- **`TOKENS[token] = {what, action}`:** one row per refusal a user can meet.
  Keys are the literal strings producers emit; for example, tasker's is
  `'task start rejected: process admission capacity'` (`tasker.lua:399`).
- **`INTERNAL[token] = true`:** a token reachable only through a programming
  error. `describe` says it is unexpected, and names the log file.
- **`describe(kind, outcome, failure, detail)`** returns the message, or `nil`
  for the user's own Stop. The lookup order is:
  1. the `failure` string, so provider failures and `operator stopped response`
     resolve by their specific reason;
  2. the outcome;
  3. "unexpected".
- **Kill and hold detail** (Done-when: "names the pid"). For `generation limit`,
  `process generation limit` and the tasker capacity token, `describe` appends
  "still running after Stop: pid …", taken from `tasker.held()` when it is
  non-empty.
- **Revocation by cause.**
  - The runner records why a generation lost its grant, as `s.cause`:
    - `edit`: a grant revoked with `'output edit'` or `'identity'`;
    - `reload`: an epoch change;
    - `detach`: `attached=false` (`generation_runner.lua:98-100`).
  - It puts the cause on the terminal snapshot. The messages for `revoked`:
    - `edit`: "you edited the answer while it was being written; the partial
      answer is kept — submit again to regenerate";
    - `reload`: "the chat was reloaded while the answer was being written;
      submit again";
    - `detach`: no warning, since the user closed the chat.
- **Actions name only what exists.** When a row is written, check every command
  its action names with `grep -n "M.cmd.<Name>" lua/parley/init.lua`.
  `:ParleyToolOperations` lists tool operations only (`tool_operations.lua:5-6`),
  so no action points at it for provider or held processes.

### Task 5.1: The vocabulary

**Files:** Create `lua/parley/refusal.lua` and `tests/unit/refusal_spec.lua`
(routed under `chat/lifecycle`).

- [ ] **Step 1: Failing tests.**
  - Every `TOKENS` entry has a non-empty `what`, and an `action` that matches
    `:Parley%u` or one of `submit again`, `try again in a moment`, `wait for`,
    `edit`.
  - `describe` resolves `failure` before `outcome`.
  - `describe('ended','cancelled','operator stopped response')` is `nil`, while
    `describe('ended','cancelled',nil)` is a warning.
  - `revoked` gives the text for each cause, and `detach` gives `nil`.
  - An `INTERNAL` token and an unknown token both say "unexpected" and show the
    token.
  - With `tasker.held()` stubbed non-empty, the three capacity tokens carry the
    pid.
- [ ] **Step 2:** FAIL. **Step 3:** Implement: one `TOKENS` or `INTERNAL` row per
  literal the Task 5.2 scan finds. **Step 4:** PASS. **Step 5:** Commit.

### Task 5.2: The guard — every producer literal has words

**Files:** Create `tests/arch/refusal_vocabulary_spec.lua`.

The scan is written in Lua rather than as a shell grep, so its forms are exact
and testable.

- **Files:** `lua/parley/document/state.lua`, `document/init.lua`,
  `document/user_edits.lua`, `generation_runner.lua`, `generation.lua`,
  `response_submission.lua`, `response_target.lua`, `response_session.lua`,
  `response_provider.lua`, `batch.lua`, `batch_response.lua`, `tasker.lua`,
  `dispatcher.lua`, `chat_respond.lua`.
- **Forms** (single or double quotes): `reject(<lit>)`, `return nil, <lit>`,
  `reason = <lit>`, `{ok = false, reason = <lit>`, `failed(<lit>)`,
  `fail(<lit>)`, `retire(s, <status>, <lit>)`, `start_error(<lit>)`, and
  tasker's `reject(<lit>)`.

- [ ] **Step 1: Write the spec** with three assertions:
  1. The scan finds at least 100 literals. The floor means a broken pattern
     cannot pass vacuously; the 2026-09-18 count was about 150.
  2. Every literal is a key of `TOKENS` or `INTERNAL`, or of a `NOT_REFUSAL`
     table in the spec. Each `NOT_REFUSAL` entry states its reason (for example,
     an effect annotation such as `'explicit revoke'`).
  3. The `PREFIX` strings appear as literals in no file under `lua/` except
     `refusal.lua`.
- [ ] **Step 2: Counterfactuals.**
  - Add `return nil,'brand new token'` to a clean `response_target.lua`:
    assertion 2 fails.
  - Add `logger.warning('Response not started: x')` to `chat_presentation.lua`:
    assertion 3 fails.

  Restore both with `git checkout --`.
- [ ] **Step 3:** Commit (`#261 M5: every refusal token has words`).

### Task 5.3: Route every refusal through it

- [ ] **Step 1: Failing integration tests** in
  `tests/integration/chat_respond_spec.lua`, capturing `vim.notify`:
  - each of the five silent returns → exactly one WARN, containing its action;
  - each terminal non-success outcome in single mode that the fixture can drive
    → exactly one notice, with the cause-specific text. These are `revoked` (by
    edit, and by `:e!`), `provider_failed` (by an injected failure) and
    `prepare_failed`;
  - `overlap` (regenerate twice at once) → the notice names `:ParleyStop`;
  - a user Stop → no WARN;
  - a kernel-held process (a fake that ignores KILL) → the `generation limit`
    refusal names its pid.
- [ ] **Step 2: Implement.**
  - Replace every site under "What is broken today" with
    `_parley.logger.warning(Refusal.describe(kind, outcome, failure, detail))`.
  - Collapse the `:1542` channel into it.
  - Make each silent return warn before returning.
  - In `terminal`, warn for every non-success outcome. Keep `failure_notice`
    (the provider's HTTP detail) as `detail`, and keep the overflow text via
    `chat_presentation.overflow_message` in `overflow`'s row.
- [ ] **Step 3:** Delete the force-flag parsing and its message in
  `cmd_respond`, delete `init.lua:4171`, and fix the header comment at
  `chat_respond.lua:3`. Then `grep -rn "resubmit_questions_recursively" lua tests`
  prints nothing.
- [ ] **Step 4:** PASS. **Step 5:** Commit (`#261 M5: no silent refusal, no raw token`).

### Task 5.4: The inventory, the restart invariant, the close

This covers Done-when #1 and #6: the audit's inventory becomes a maintained
atlas page.

- [ ] **Create `atlas/chat/transcript_truth.md`**, linked from `atlas/index.md`,
  with two sections:
  - **Restart invariant:** quitting and reopening a chat rebuilds every
    submission-relevant fact from the file. Nothing else survives; say why.
  - **Inventory:** every state that can block submission or hold a generation,
    sorted into the Spec's three buckets. Each entry gives its invalidation rule
    and the test that pins it:
    - document grants and turn;
    - `prev_answer`;
    - runner `active` and `staged_total`;
    - tasker records: scope kill, deadline, `leave`, and kernel hold via
      `held()`;
    - `response_target` pending slots;
    - topic jobs;
    - `responses` and `batches`;
    - `skill_invoke._in_flight`;
    - the sidecars (`sidecar_degrade_spec`).
    - the legacy `<state_dir>/answer-recovery/` directory: nothing reads or
      writes it after M1, and it is safe to delete. This is its one mention,
      and it closes the directory's lifecycle (ARCH-FUNERAL) without
      migrating it.

    Each row points at code and tests, and states no rule the code owns. The
    Stop invariant links to `lifecycle.md`, and undo grouping to `ownership.md`.
- [ ] Target: a Revisions entry recording what #261 delivered, linking the page.
- [ ] **#255:** after #261's close gate passes, move it through
  `working → codecomplete → done` with `sdlc issue set-status`, and add a Log
  line pointing at #261.
- [ ] **#265:** a Log line saying its refusal words come from
  `lua/parley/refusal.lua`.
- [ ] `make test`, `make lint`, `make check-fresh-clone PLENARY=…` (TOOLING.md).
- [ ] `sdlc milestone-close --issue 261 --milestone M5`, then
  `sdlc close --issue 261 --verified '<evidence>'`.

---

## Revisions

### 2026-09-18 — plan review round 1 (two fresh-context reviewers) and two operator decisions

**Reason.** Both reviewers returned *Issues Found*, backed by running the
proposed tests on main and probing the code. The operator decided the two
questions the review raised.

**Operator decisions.**
- Own process groups for **generation-owned** processes only, so
  terminal-prompting secret commands keep working.
- Deadlines **per kind**: 600 s prompt-capable, 120 s one HTTP call, 60 s
  conversion, 900 s background stream.

**Delta, by finding:**

- **M1.**
  - Task 1.1's first test passes on main (through the in-process retry cache).
    It is now a labelled characterization test, and the verified-red "further
    edit" and "close and reopen" variants were added.
  - The legacy-directory test now cleans up in every case, and its failure point
    is stated.
  - Task 1.4 is rewritten. Two sidecars *throw* today: `state.json` (via
    `refresh_state`) and the remote-reference cache (via
    `resolve_remote_references`). So `file_to_table` becomes total, and a
    behaviour spec corrupts every declared sidecar and then submits. The census
    spec shares that one list.
  - The removal query's "no output" check moved to the end of Task 1.5, with its
    one expected hit.
  - Tool tests that also pin non-recovery behaviour are kept.
  - Atlas text links undo grouping instead of restating it.
- **Plan-wide.** The arch table guard would have failed on future-milestone
  symbols and on removal-table rows. Now:
  - rows for later milestones carry an `M<n> ·` prefix until their milestone
    starts;
  - task tables never start a row with a backtick;
  - commit hashes and Neovim API names are not backticked in rows.
- **M2.**
  - `State.holds` reads through the opaque-handle accessor, and its test
    suspends the grant through an `uncertain` transition.
  - Substitution re-binds `question`, and the raw-payload read moves to the
    input copy, which also fixes the batch-leg copy.
  - `init.lua:3798` keeps `live_buf` and `live`.
  - Added tests:
    - capture-then-late-build, the event the plan named as most likely to be
      mishandled;
    - a structured answer (#255);
    - a `_previous_count` seam, to prove removal rather than filtering;
    - the revoke → G′ → finish ordering;
    - a parent `:write` in the sub-chat test.
  - The multi-slice test is dropped: by construction, the slot is set before any
    gap byte.
  - ARCH-ORDER gains the suspended, paused and G′ rows. It also gains a
    consumer-side decision: generated writes stop marking other generations'
    input stale (Task 2.5), which the #255 Done-when requires.
- **M3.**
  - `detached` implies `setsid`, so it is used for scoped runs only (operator
    decision).
  - Escalation:
    - it is gated on *unresolved*, not *not exited*, and reopens for a late
      Stop;
    - duplicate stops do not move `kill_due`;
    - the tick is clamped so KILL lands at 2 s.
  - A kill Parley caused reaches its callback as `code=nil` plus `io_error`, and
    every unscoped callback is swept (the keychain empty-store hazard).
  - The census is 18 sites plus 2 streams, each with a deadline and its basis
    (ARCH-CONSTRAINTS).
  - The fake:
    - records a signal per group member, so existing assertions hold;
    - makes pipe-holder EOF opt-in.
  - Conformance uses `kill -0 -$$` instead of `ps`, and also runs through
    `process_bootstrap`.
  - `VimLeavePre`'s registration site is named, and the test calls
    `tasker.leave()` directly.
- **M4.**
  - W1 uses `operation_supervised` for children.
  - The scope kill runs once, on the first of stopping and terminal, and reads
    `G.phase` rather than a snapshot.
  - W14 cleans up the subscriber and timer, and returns `nil, reason`.
  - Added W16 (a topic generation with a nil handle), and added every `Deferred`
    owner to W13.
  - The runner's `fault` defines "settles failed".
  - W4 scopes only the content tree.
  - Task 4.5 moved to the fake-runtime harness, with the correct "before"
    refusals: `generation limit` at the 5th, and `process generation limit`
    across reloads.
- **M5.**
  - The token scan is written in Lua, covers 14 files and every producer form,
    and has a floor.
  - Keys are the producers' literal strings.
  - `describe` resolves `failure` before `outcome`.
  - A user Stop is silent, but other `cancelled` paths warn.
  - The pid comes from `tasker.held()`, and also covers `generation limit`.
  - The `revoked` text depends on its cause.
  - No action names `:ParleyToolOperations` for non-tool processes.
  - The inventory lists `response_target` slots and topic jobs.

### 2026-09-18 — plan-quality gate, round 1 (no blocking findings)

**Reason.** `sdlc change-code` accepted the plan. It recorded four Minor
findings for the close review.

**Delta.**
- W13 now says which of the query's ten `Deferred` owners are in scope, and
  why the other five are not. W16's line reference is corrected to
  `response_topic.lua:80`.
- Task 3.3 includes the sweep of `tasker_run_spec.lua`'s 43 option-less
  `tasker.run` calls, which the new deadline refusal would turn red.
- Task 5.4's inventory names the legacy directory as safe to delete, which
  closes its lifecycle.
- Not changed: *plan-restates-the-diff*. The embedded bodies stay as written.
  Where a body and the code disagree, the code and its tests are
  authoritative.

### 2026-09-19 — M1 boundary review round 2 (REWORK) — dispositions

**Reason.** Round 2 found a Critical introduced by round 1's own fix, and two
repeat families. The gate said "fix rules, not instances".

**Delta.**
- **BR-14 (`returned-handle-has-no-consumer`, Critical).** The picker ignored
  `set`'s new `false` and announced a save that had not happened.
  - `table_to_file` now reports whether it wrote, and `save`/`set`/`remove`/
    `rename` pass that on.
  - The picker says "saved" only on success; a refused save keeps the buffer
    modified. The dispatcher aborts a request whose body was not written.
  - Guard: `sidecar_authority_spec` fails a sidecar write called as a bare
    statement, unless it is declared with a reason. The two cache writes are
    declared.
  - The finalize handle stays W18.
- **BR-15 (`per-item-diagnostic-unbounded`, second in the family).** The
  picker's build now reads the prompt file once, via `source(name, builtins,
  loaded)`.
  - Guard: `sidecar_degrade_spec` counts the warnings naming a sidecar during
    one user action, and asserts at most one. The custom-prompt exercise is
    that loop.
- **BR-16 (`untrusted-input-unparsed`).** `vault.lua`'s token decode is under
  `pcall`, and the token is typed at the boundary. W6 gains that path.
  - Guard: `tests/arch/json_decode_spec.lua` fails any unguarded
    `vim.json.decode` in `lua/`. It finds 33, with a floor of 30.
- **Minors.**
  - `helper_io_spec` F3b generates its cases from an ordered list.
  - Chunk 1's steps are ticked.
- **Counterfactuals.** Reverting each fix turns its guard red: decode (1),
  write result (1), warning bound (3), picker P1 and P3.

### 2026-09-19 — M1 boundary review round 3 (FIX-THEN-SHIP) — one JSON writer

**Reason.** BR-19 was the third finding in the `returned-handle-has-no-consumer`
family. `table_to_file` dropped the result of `file:close()`, where buffered
writes actually fail, so it reported success over a truncated file.

**Delta.**
- **Sidecar writes go through `table_to_file_atomic`.** Its result is derived
  from encode, open, write, close and rename, and the original file survives a
  failure. `table_to_file` now delegates to it and warns on failure, so there is
  one JSON writer, not two with different failure reports.
- **Tests.**
  - F3e simulates a close that fails with "File too large": the result is a
    failure, the original is intact, and no temporary file is left.
  - F3f is the test that goes red when the old writer is restored: it proves
    `table_to_file` delegates. F3e pins the atomic writer itself. *(Corrected
    in round 4: this entry first named F3e as the delegation test.)*
  - R1 shows the dispatcher aborts, with its reason, before curl starts when the
    body was not written.
  - Reverting either fix turns its test red.
- **Minors.**
  - One `BEARER_SCHEMA` applies at both boundaries the copilot bearer crosses.
  - `json_decode_spec` covers `vim.fn.json_decode` as well.
  - `DROPPED` is keyed by the exact call, not the file.

### 2026-09-19 — M1 boundary review round 4 (FIX-THEN-SHIP, finalized) — the writer's collateral and the census's scope

**Reason.** Round 4 finalized M1 with FIX-THEN-SHIP and three Minor findings,
fixed before the close commit per the #174 protocol.

**Delta.**
- **Routing every JSON write through the rename-based writer changed three
  behaviours.** Each was checked against the callers:
  - A symlinked sidecar was replaced by a regular file. The writer now resolves
    an existing destination with `fs_realpath` and writes beside the real
    target, so the link survives (F3g).
  - The file's mode was reset. The writer now copies the existing mode onto the
    temporary file before the rename, so a 0600 bearer cache stays 0600 (F3h).
  - A crash between write and rename left `*.tmp-*` files that nothing removed.
    `helper.remove_stale_temps` runs at setup for the state directory and the
    query directory, and on the tracker's first load for `file_access.json`'s
    directory. Each is swept before the process writes there (F3i).
- **The census covers the profile, not one spelling.** It selects modules that
  name the state directory *or* `stdpath('data')`, the property that defines
  the class.
  - `file_access.json`, which escaped the census and raised on opening a chat
    when an entry had the wrong type, is now in `tests/helpers/sidecars.lua`.
    It is read with a schema and written through the one writer.
  - `starter.lua` and `cliproxy.lua` are declared with reasons: first-run setup,
    and the proxy's derived artifacts.
- **BR-20 is addressed.** V1 drives a token response with a string
  `expires_at` through the stateful process fake and proves the next request
  fetches again. Removing the response `conform` turns V1 red.
- **Counterfactuals.** Reverting each fix turns its test red: vault V1;
  file_access (2 degrade cases); writer (F3g, F3h).

### 2026-09-19 — M2 boundary review (FIX-THEN-SHIP) — the lookup primitive, and a test that could not be written as planned

**Reason.** The review found two blocking families.
- `enumeration-claims-completeness`, fourth in the family: `bufnr(path)`'s
  partial match was fixed at 1 of 5 sites. The `chat_lines` consumer list had
  no query.
- `plan-step-not-as-specified`, second: Task 2.6's loaded-target move test
  was missing, and the Log said "as planned".

**Delta.**
- **`helper.buffer_for(name, loaded_only)` is the one exact-name lookup.**
  File paths are compared resolved; `parley://` names are compared as written.
  - `chat_lines`, `init.lua` (child topic after a prune, twice), `outline.lua`
    and `system_prompt_picker.lua` use it.
  - Query: `grep -rn "vim.fn.bufnr(" lua/parley | grep -v "vim.fn.bufnr()"`.
  - Guard: `tests/arch/buffer_lookup_spec.lua`.
  - Regression: P4, where opening prompt `foo` from another window no longer
    force-deletes `foobar`'s unsaved editor. It goes red with the old lookup.
- **Task 2.6's loaded-target bullet is withdrawn as specified.** The
  `move_chat_tree` rewrite branch did not fire in any configuration tried:
  timestamped references resolve by glob to the moved file since #224, and a
  stable-named tree produced no rewrite. Filed as parley#270. What remains is a
  characterization: a tree move leaves a loaded chat's unsaved text and its
  file alone.
- **Task 2.2 did not lift `parsed_chat` into a shared helper.** The pure tests
  use literals, and the `build_messages` checks live beside that spec's
  fixtures.
- **Task 2.6's sub-chat tests use the `_collect_ancestor_messages` seam**
  rather than submitting in the child.
- **Minors.**
  - `lifecycle.md` states the broader staleness rule: every generated write,
    and why an earlier capture is final.
  - A two-entry `substitute` test covers several exchanges regenerating at once.
  - The late-build stub is restored under `pcall`.

### 2026-09-19 — M2 review round 2: the tree-move stand-in withdrawn

**Reason.** BR-30: the stand-in test for Task 2.6's loaded-target bullet
passed only because its chat was a scratch buffer.

**Delta.** The stand-in is deleted and the bullet is withdrawn outright. The
real behaviour, a loaded chat's tree move aborting with ENOENT after a save
triggers a slug rename, is recorded on parley#270. The buffer-lookup guard
documents that it checks by spelling.

### 2026-09-19 — M2 review round 3: the exemption's boundary, and the did-it-happen rule by annotation

**Delta.**
- **BR-32.** The staleness exemption is safe only because a write outside its
  grant, or through a revoked grant, has no owner. Two unit cases pin that the
  reader stays stale in both. Computing the exemption from the raw owner turns
  both red.
- **The `returned-handle-has-no-consumer` family is fixed as a rule.**
  - Did-it-happen functions carry `---@nodiscard`: `table_to_file`,
    `table_to_file_atomic`, `custom_prompts.save/set/remove/rename`, and
    `D.set_previous_answer`.
  - `tests/arch/nodiscard_spec.lua` fails any bare-statement call to them
    unless it is declared with a count and a reason. It replaces the
    name-listed check in `sidecar_authority_spec`.
  - `set_previous_answer`'s false is declared: the generation has already lost
    its grant, and the transcript is then the right context.
- **Deferrals land in contracts.** parley#270's `## Done when` now carries the
  file-backed fixture obligation.
- **Recorded, not fixed.** `buffer_for`'s private path key is another copy of
  the `resolve(fnamemodify(x, ':p'))` idiom, which has about ten copies in
  `lua/`. Extracting one `canonical_path` is a sweep beyond #261's surface.
  The close review will see it recorded.

### 2026-09-19 — M2 closed (review round 4, FIX-THEN-SHIP): the guard's own edges

**Delta, bundled into the close commit (#174).**
- `nodiscard_spec` reads every statement head on a line: its start, and what
  follows `then`, `do`, `else` or `;`. It also catches a bare `pcall` or
  `xpcall` of a marked member.
- Its header lists the forms it cannot see: re-aliasing by assignment, `:`
  calls, a call split across lines, and other higher-order wrappers.
- `DROPPED` must match the calls it excuses exactly, so a declaration cannot
  outlive its call.
- Counterfactuals: the two planted forms, and the stale entry, are all caught.

### 2026-09-19 — M3 Tasks 3.1–3.3, as built

**Delta.**
- **Deadlines land in 3.3, not 3.4.** The refusal of an unscoped run without
  `deadline_ms` would otherwise make the 3.3 commit refuse every vault, OAuth,
  topic and memory-preference spawn. So 3.3 also passes `tasker.deadline.<kind>`
  at all 18 `tasker.run(nil, …)` sites, and gives both streams
  (`generate_topic`, `memory_prefs`) `transport_opts = {deadline_ms = …stream}`.
  The per-kind values are one table, `tasker.deadline` (ARCH-DRY). 3.4 keeps the
  callback sweep and its tests.
- **"Scoped" means `logical_generation` or `generation_id` is present**, since
  `state.logical_generation` defaults to the generation id.
- **No `deadline` event.** A deadline is `stop_requested` with
  `cause = 'deadline'`. One event opens every stop window, whatever its cause:
  `stop`, `deadline` or `leave`. `stop_requested` also reports `opened`, so a
  repeated stop inside one window sends nothing new unless its signal differs.
- **What counts as a kill.** `kill_cause` names the cause when any signal Parley
  sent was accepted while the attempt was unresolved. That includes a group
  signal that reached only a grandchild after the parent exited, because the
  output may then be cut. An attempt whose group had already gone (ESRCH) is
  not a kill, and neither is one that ended on its own.
- **A resolved attempt closes its window** (`reconcile_due = nil`), so no late
  tick can escalate it.
- **Test sweep.**
  - `tasker_run_spec` routes its calls through one local `run` that adds
    `deadline_ms`.
  - The pid-result test now uses an unscoped attempt: a scoped one is signalled
    by group.
  - The `dispatcher.query` callers in `query_cache_spec` and
    `cliproxy_recovery_e2e_spec` pass `{deadline_ms = 60000}`.
  - The `async_builtin_spec` contexts carry `logical_generation`, as the
    scheduler always does.
- **Counterfactual.** When the target is the pid rather than the group, 8 of the
  12 new sequence tests fail, including 2 and 3.

### 2026-09-19 — M3 Task 3.4, as built: one rule at the source

**Delta.**
- **`code` is nil whenever `io_error` is set.** It no longer means only "killed":
  a pipe error or an overflow now reads the same way. So every callback that
  tests `code ~= 0` or `code == 0` already counts cut output as a failure. The
  sweep is that one rule in `tasker`, not `or io_error` added at 16 sites
  (ARCH-DRY). The census is unchanged: 18 `tasker.run(nil, …)` sites and 2
  streams.
- **Two callbacks needed more than the rule.**
  - `load_account_store`: a read that did not finish returns an *unread* store
    (a weak-keyed set). It is not cached, and `save_account_store` refuses to
    write it over the keychain. A non-zero exit is still the keychain's
    answer, "no entry": cached and saveable.
  - The vault copilot fetch formatted `code` with `%d`, and now uses `%s`
    (the nil code threw).
- **Content fetch.** A killed fetch becomes a transport error, never the body,
  even when its output carried the whole write-out trailer. The counterfactual,
  passing luv's `code=0`, turns that test red. A transport error is still
  cached as that URL's error text: this is the existing per-question snapshot
  rule (`remote_references_spec`), and the transcript's earlier exchange was
  answered with it.
- **Tests:** `tests/integration/unscoped_kill_spec.lua`, which uses the real
  tasker over the process fake, plus a pipe-error case in
  `tasker_supervision_spec`.

### 2026-09-19 — M3 Task 3.6, as built

**Delta.** The third conformance case, "through `tools/process_bootstrap`", runs
the real `find` builtin through `async_builtin` with a captured path authority
on `/`, which is the manual "Stop during `find /`". It asserts that the attempt
is scoped, that `stop_scope` settles the tool within 4 s, and that its pid is
gone. With main's `detach = true` restored, all three cases fail.

### 2026-09-19 — M3 boundary review round 1 (FIX-THEN-SHIP): dispositions

**Delta.**
- **BR-38, renderers of a changed value.** `tasker.exit_reason(code, signal,
  io_error)` is the one way to print how a run ended.
  - It is used by every tasker exit callback that renders an outcome:
    - the remote-content fetch (`oauth.lua`), whose transcript text now reads
      "(killed: deadline) … Resubmit the question to fetch it again.";
    - the auth-code exchange warning;
    - the vault copilot error;
    - the dispatcher's transport-discard reason.
  - The dispatcher's structured failure diagnostic already printed `io_error`
    beside the code, and stays as it is (allowed once).
  - `tests/arch/spawn_seam_spec.lua` fails on any raw `tostring(…code)` in a
    module that hands callbacks to tasker. `unscoped_kill_spec` asserts that
    the rendered text names `killed: deadline` and contains no "nil".
- **BR-39, statements of the Stop contract.** Found by running the
  superseded-claim sweep over `README.md`, `atlas/`, `docs/`, `tests/manual/`
  and code comments for "still running", "claims", "does not release" and
  "Stop".
  - The one stale statement was `README.md`, "the process supervisor keeps
    tools that are still running". It now reads: a stopped tool's process is
    ended, TERM then KILL at 2 s, and its claims are held until it has ended.
  - The other statements say that claims are held until the process ends,
    which is still true: `tool_execution.md` (the supervisor paragraph),
    `tool_use.md` (the Stop table), `ownership.md` and `lifecycle.md`.
- **BR-40, "every process".** Fixed by scoping the wording and adding a guard,
  not by moving 18 files' spawns into tasker, which is beyond #261's surface.
  - The atlas section now covers processes "started through `tasker.run`".
  - A new "Processes outside tasker" part points at the guard's list:
    `tests/arch/spawn_seam_spec.lua` names each out-of-seam spawn with how it
    ends, as an exact count per file. A new spawn fails the guard, and so does
    a listed spawn that no longer exists (the dead-entry check).
  - The same file also forbids a numeric `deadline_ms` literal in `lua/`.
- **Minors.**
  - `generate_topic` merges `transport_opts`, adding the stream deadline only
    when the run is unscoped (`tasker.is_scoped`, one definition of scoped)
    and no deadline is set.
  - The fake's group kill honours the leader's scripted `signal_result`, and
    both paths share one `scripted()` helper. `state.signals` lists only
    accepted signals. The failed-signal-retry test runs on both paths again.
  - `target()` never returns a pid ≤ 0.
  - The deadline timer closes as it fires, so a held record keeps no handle.
  - `attempt` has one `open_probe_window`.
  - `unscoped_kill_spec` is routed to `infra/vault` as well.
- **Census method, corrected (review §7).** Task 3.4's command
  `grep "dispatcher.query("` misses `pcall(dispatcher.query, …)`
  (`response_provider.lua`) and the `llm.query` alias (`skill_invoke.lua`).
  Both are scoped, so the "18 sites + 2 streams" conclusion held by luck, not
  by method. The enumeration is safe because tasker refuses an unscoped run
  without a deadline at runtime; the grep was only a cross-check.
- **For M4 (W16).** `generate_topic` now merges its options (above). The review
  also noted that `scoped_stop` drops `cause`, so every scoped stop reads
  `killed: stop`. M5's refusal vocabulary, where a user Stop is silent but other
  cancellations warn, will need `cause` threaded through
  `stop_scope`/`stop_owner`/`stop_attempt`. That belongs to M5.

### 2026-09-19 — M3 boundary review round 2 (FIX-THEN-SHIP): dispositions

**Delta.** Round 1's three Importants were disposed as addressed; two new ones
and three untested Minors came back.
- **BR-45, the value's other seam.** The dispatcher now renders the transport's
  end once, into `failure.exit` (`tasker.exit_reason`), and no longer exports
  `code` or `signal` at all — so a consumer cannot render the nil code.
  - `chat_respond._failure_notice` reads `failure.exit`, and no longer shows the
    partial body as if it were a diagnosis when the transport itself failed.
  - `response_provider.failure_reason` reads it too, instead of reporting
    "(HTTP unknown)" for a killed stream.
  - The guard is anchored on the value: no module may read `failure.code`,
    `failure.signal` or `failure.io_error`, and the header lists the forms the
    matchers cannot see.
  - Tests: `failure_notice_spec` (a kill names its cause and hides the partial
    body), `response_provider_spec` (a killed stream's reported reason),
    `dispatcher_query_spec` I9 (the table carries `exit`, not `code`). Each red
    on revert.
- **BR-46, the enumeration's reasons.** `spawn_seam_spec` now derives each
  out-of-seam spawn's class from its call form — `sync`, `bounded`,
  `delegated`, `open` — and declares counts per class per file. Free text is
  required only for `open`, and refused when there is none.
  - `bounded` covers a declared argv helper (`api_argv`), and the test asserts
    that helper's own body carries the bound.
  - `delegated` covers cliproxy's `run(argv, cb)` wrapper, and the test asserts
    every call site passes a bounded argv.
  - The two wrong entries are gone: `git_markdown_source` is `git ls-files`
    cancelled by one SIGTERM with no timer, and cliproxy's unbounded calls are
    the 9 synchronous ones.
- **The three untested Minors now have tests** (BR-41 merge, BR-43 pid 0,
  BR-44 the held record's timer), each verified red on revert. The fake gained
  one seam, `spawn_pid`, for BR-43.
- **One guard caught another.** `arch_helper_spec`'s meta-guard flagged the word
  `git ls-files` inside the new spec's prose. The reason now names the command's
  real flags, which is both more precise and outside the meta-guard's pattern.
- **Recorded, not fixed.** The reviewer's two M4/M5 notes stand: a derived
  `phase` tag on `attempt`, and threading `cause` through `scoped_stop` so a
  reload-caused kill differs from a user Stop. Both belong to M4/M5, and the
  earlier Revisions entry already records the second.

### 2026-09-19 — M3 boundary review round 3 (FIX-THEN-SHIP, finalized at the round cap): dispositions

The close finalized at the gate's round cap. Round 3 disposed round 2's five
findings as addressed, and raised one Critical, two Importants and four
Minors, fixed below and bundled into the close commit (#174: no re-run).
- **Critical — the vault log line** (Task 3.4). Round 1 fixed a `%d`-on-nil
  throw by rewriting the Copilot failure log to include stderr. The request ran
  `curl -v`, whose stderr carries `authorization: token <secret>`, and the
  base's `string.format` had silently dropped that argument, so the leak was
  new. The class, swept:
  - `-v` removed; neither output is logged for that request.
  - A failed secret command shows its bounded stderr, never its stdout, which
    is the secret.
  - The token exchange logs its OAuth `error`/`error_description` through
    `_token_body_summary`, never the body.
  - A guard forbids a verbose or traced argv anywhere in `lua/`.
  - Three regression tests plant the secret where each process puts it. Each
    fails against the pre-fix code.
- **Important — the exit value's non-rendering consumers** (Task 3.4). The
  census covered the 18 unscoped `tasker.run(nil, …)` sites, but never the
  scoped callbacks, and the defect was there: `async_builtin` overwrote an
  inherited `io_error`, so an early Stop of a shell tool read "scoped process
  bootstrap failed".
  - It now writes `io_error = io_error or …`.
  - A guard forbids an overwrite in any module where tasker's callbacks land.
  - The live conformance case asserts the tool's result is `killed: stop`: red
    3/3 on revert.
- **Important — `scope_key`'s producers** (Task 3.3). "One function" held for
  the two spellings named here and missed `skill_invoke`'s hand-built
  `skill:<buf>:<gen>`.
  - It is now `tasker.scope_key("skill:"..buf, gen)`, the same string from the
    one function.
  - A census guard classifies every production `logical_generation`
    assignment as built with scope_key, forwarded from one, or a failure. It
    is red on the old line.
  - The atlas now says that a chat generation's scope kill (M4 Task 4.1) does
    not reach a skill's processes. **M4 must keep that in mind when wiring the
    kill:** a skill stops its own.
- **Minors.**
  - `failure.io_error` is retired from the dispatcher's table, which already
    carries it inside `exit`, so the field and its guard entry agree.
  - The conformance spec pins the exemption's negative live: an unscoped run
    leads no group (red when everything is detached). `gone()` means ESRCH.
  - The atlas's out-of-seam summary follows the guard's derived classes.
  - `join_code` records the invariant that keeps a nil code from reaching it.
- **Also, from the review's M4/M5 notes.** The README's custom-tool paragraph
  says a custom `execute_async` forwards `context.logical_generation` to
  `context.tasker.run`, or is refused.

### 2026-09-19 — M4 Task 4.1, as built

**Delta.**
- **W1's condition is "the start threw", not "no handle".** An adapter may
  return nothing and still be cancellable through `cancel_operation`: the
  supervisor-transfer sequence in `generation_sequences_spec` does exactly
  that, and keying on a nil handle skipped its supervisor. The runner marks
  `op.start_threw` and confirms only those at cancel.
- **A tool whose start threw** gets outcome `unknown` from `cb.failed` and is
  resolved at once, since nothing was started, so the round goes on.
- **`fault`** shares the terminal cleanup with the machine's own terminal
  (`finish`) and the once-guarded scope kill (`kill_scope`).
  `Deferred.new(step, on_error)` calls `on_error` instead of rethrowing from a
  timer callback.
- **The scope kill** runs in `dispatch`, on the first accepted transition into
  `stopping` or `terminal`, through `adapters.stopping(ctx)`. The session's
  implementation lands in Task 4.2.
- **Tests:** `tests/integration/generation_settles_spec.lua` (9 cases). Each of
  four targeted mutations — the thrown-start resolve, the child resolve, the
  fault handler, the scope kill — turns it red.

### 2026-09-19 — M4 Task 4.2, as built

**Delta.**
- **The session's `stopping` hook** calls
  `tasker.stop_scope(tasker.scope_key(ctx.epoch, ctx.generation))`. The test
  signals a process in the scope that no adapter tracks, and turns red without
  the hook.
- **W2 changes a pinned contract.** `chat_remote_preparation_spec` asserted that
  a preparation holds until every content fetch calls back ("a throw is not
  proof the child never spawned"). Cancel now resolves at once. Anything a
  fetch spawned dies with the scope kill, once Task 4.3 puts fetches in the
  scope; until that commit, an orphaned fetch ends at its 120 s deadline. Both
  cases are rewritten: Stop, or a launch that throws, ends the generation, and
  late results publish nothing.
- **W3** is covered by W2 plus the existing `validate_source` check; its test
  is a readiness picker that never answers.
- **W5 changes two pinned contracts** in `response_provider_spec`: a cancel
  during `pre_query` or during recovery resolves at once. The late callback
  spawns nothing and resolves nothing twice.
- **W12/W18.** A refused completion start is `done('failed')`. The finalize
  adapter no longer returns a handle the runner discarded: completion settles
  itself on `ctx.cancelled`, pinned by a completion-level test.
- **W13.** All four owners pass an error callback to `Deferred.new`. Each test
  makes the owner's own step throw, and turns red on revert.
- **W15.** Batch and topic cancels are guarded, so the session's cancel always
  runs; the topic cancel in the terminal handler too.
- **W16.** A topic started without a handle retires in `stop()`, and a throwing
  provider cancel retires it failed.

### 2026-09-19 — M4 Task 4.3, as built

**Delta.**
- **W4.** The scope is one explicit trailing argument, `scope`, threaded through
  the content tree: public fetch, Google, Dropbox, Microsoft and office
  conversion. The provider definitions' `fetch_with_access_token` carry it too.
  Each content spawn takes `content_run(scope, kind)`, which is scoped when
  there is a scope and keeps its kind's deadline either way. Keychain, refresh
  and the auth-code exchange stay unscoped (shared).
  - `chat_respond` passes `tasker.scope_key(ctx.epoch, ctx.generation)`.
  - A fetch launch that throws now marks its child done.
  - The producer census declares oauth's forwarded `scope` parameter, with an
    exact count.
- **W6.** `refresh_copilot_bearer(callback, on_error)` reports all three failure
  paths, and Copilot's `pre_query` forwards the dispatcher's error callback,
  which it had dropped.
- **W7.** `start_query` guards `query`; a setup throw aborts the request.
- **W8.** A recovery runs only while `transport_alive`. A stopped owner gets the
  failure, which it ignores.
- Each test turns red on revert: W4 (oauth and chat_respond), W6, W7, W8.

### 2026-09-19 — M4 Task 4.4, as built: W10 dropped, W9 covered by W1

**Delta.**
- **W9** needs nothing of its own. A tool whose `producer.start` threw is
  Task 4.1's thrown-start path: its outcome is `unknown` and it resolves at
  once. Its processes are in the generation's scope, so the scope kill ends
  them. `generation_settles_spec` "a tool whose start threw" covers it.
- **W10 is dropped, as the plan allows.** Reproducing it: the machine refuses a
  tool's *first* `child_outcome` only for a child that is:
  - not found or not started: the tool layer has no record of such a child;
  - already supervised: supervision itself sets the outcome to `unknown` and
    removes the runner's operation, so the tool layer's later `resolved`
    returns false with nothing held;
  - already final: that needs an existing outcome.

  None of these holds a generation, so no public sequence reaches the case. The
  supervised path is pinned by `generation_sequences_spec`'s
  supervisor-transfer cases.
- **W17.** The run's guard is freed on `BufUnload` of its buffer, which `:e!`
  fires as well as `:bd` (measured; an autoread reload does not). The
  run is cancelled with `buffer unloaded` and no `done`, and `_gen` keeps a
  stranded read's late callback off a newer run. `stop_owner` is guarded.
  - The existing "invalid scheduled completion" test now ends at the unload,
    with the same properties: no read, no done.
  - The new tests strand a read, then `:bd` + reopen or `:e!`; they assert the
    buffer number is reused and a new run is admitted. All three are red on
    revert.

