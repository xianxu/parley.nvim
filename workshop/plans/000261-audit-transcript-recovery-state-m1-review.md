# Boundary Review — parley.nvim#261 (milestone M1)

| field | value |
|-------|-------|
| issue | 261 — Audit transcript as the complete recovery state |
| repo | parley.nvim |
| issue file | workshop/issues/000261-audit-transcript-recovery-state.md |
| boundary | milestone M1 |
| milestone | M1 |
| window | ff5ed804a7d58499a2964235f9897db53f2c85d3..91f296b5a973aafd94308277902d31533b13a52d |
| command | sdlc milestone-close --issue 261 --milestone M1 |
| reviewer | claude |
| timestamp | 2026-09-19T00:15:18-07:00 |
| verdict | FIX-THEN-SHIP |

## Review

```verdict
verdict: FIX-THEN-SHIP
confidence: high
```

M1 delivers what it claims: the answer-recovery subsystem, its commands, its state-dir hook in `delete_chat_file`, and the tools privacy carve-out are all gone (the plan's removal query returns exactly its one expected hit — the legacy-directory test string), and the reported #261 blocker is pinned by real regression tests. I verified the counterfactual myself: applying the new `chat_respond_spec.lua` + `respond_fixture.lua` to base `ff5ed804` gives 4 failures with precisely the claimed refusals (three `retained recovery requires inspection or explicit restore`, one `recovery directory must be private (0700)`), while the characterization test passes on both sides. Reverting `file_to_table`'s guard reddens 8 degrade cases; reverting only the schema application reddens 4; reverting the three nested `conform` calls reddens 4 different ones — every piece of the fix is reachable and independently covered. `make lint` is clean; `make test JOBS=4` gives 371 PASS and one file (`perf_document_spec.lua`) killed at plenary's 50 s per-file deadline under load, which passes alone twice and is the pre-existing harness flake already recorded on #267. What keeps this from SHIP is three cheap defects the diff introduces on its own new surface: a read-time filter that permanently erases hand-edited custom prompts on the next write, a milestone guard that only sees tracked files, and an unbounded per-field warning storm on an unbounded sidecar.

## 1. Strengths

- **Regression evidence is real, and the red reasons match the report.** `tests/integration/chat_respond_spec.lua:126-182` reproduces the exact operator story (regenerate → edit mid-stream → retry, across further-edit / `:e!` / `:bd`+reopen / legacy directory) and the characterization test at `:158` correctly documents that the immediate retry already worked via the in-process cache — so deleting that cache is proven not to break it.
- **The sidecar list is a genuine single source.** `tests/helpers/sidecars.lua` drives both the behavioural spec and the census, and each entry carries its own `exercise` closure — so "declared" means "actually run corrupt", not "listed". That is the right shape for this guard.
- **`respond_fixture.lua` extraction is honest DRY**, not copy-paste: `chat_respond_spec.lua` and `sidecar_degrade_spec.lua` now share one stateful dispatcher double instead of two drifting copies (ARCH-DRY, ARCH-MOCK).
- **The `unproved` suspended-grant wait removal is justified.** `bb620943` (#266 M1) added it with no test and its own message says "Scoped to `replacing_answer`: that is the only path that reads the live answer" — deleting the reader legitimately deletes the wait. No dangling reference remains in `chat_respond.lua`.
- **Docs removal is complete**: no link survives to the deleted `atlas/chat/recovery.md`, no stale anchor to the renamed `## Bounds` heading, and `tests/manual/chat-concurrency.md:61-70` replaces the recovery drill with the #261 drill rather than just deleting it.

## 2. Critical findings

None.

## 3. Important findings

**I1 — `custom_prompts.load()` prunes the map that `set`/`remove`/`rename` write back, erasing hand-edited prompts from disk** (`lua/parley/custom_prompts.lua:35`; ARCH-SECURE)

`load()` now deletes any entry whose `system_prompt` is not a string. `M.set`, `M.remove` and `M.rename` (`:57,66,79`) all do `load()` → mutate → `save(all)`, so the pruned entries are written out of existence. I probed it on the branch:

```
input : {"good":{"system_prompt":"keep me"},"handedited":{"system_prompt":["line one","line two"]}}
cp.set("fresh", {system_prompt = "new"})
on disk: {"good":{"system_prompt":"keep me"},"fresh":{"system_prompt":"new"}}
```

`handedited` is gone permanently, and the only message the user saw was `Ignoring field system_prompt of …` — which never says a named prompt was deleted. Both consumers (`init.lua:918`, `system_prompt_picker.lua:52`) already guard `type(prompt)=="table" and prompt.system_prompt`, so the filtering buys only the string check; it should not cost the bytes. Fix sketch: filter in the *view* only — give `load()` a `raw` mode (or add `load_all()`) and have `set`/`remove`/`rename` start from the unfiltered table, keeping the type check at the two consumers. The same read-filter-then-persist shape exists for `state.json` (app-owned settings, where dropping is the intended degrade) and `remote_reference_cache.json` (a cache, where refetch is the degrade) — those are fine; the prompt file is the one holding user-authored text, so sweep the class but change only this site's behaviour.

**I2 — the M1 guard uses `git grep`, so an untracked new `state_dir` reader is invisible to it** (`tests/arch/sidecar_authority_spec.lua:15`; ARCH-PURPOSE)

The milestone's stated guard is "a `state_dir` reader declares why it cannot block". I added `lua/parley/zz_probe_reader.lua` returning `config.state_dir` and ran the census: **3/3 green**. After `git add -N` on the same file, "declares every reader of the state directory" fails as intended. So the guard only fires once the file is staged — i.e. never during the TDD loop that introduces the reader. The plan's own counterfactual (Step 6b: add `local _ = config.state_dir` to `chat_presentation.lua`) passed only because it edited an already-tracked file. Fix sketch: `git grep --untracked -l -e state_dir -- lua/`, or follow the precedent in `tests/arch/single_resolver_spec.lua:15` / `untrusted_path_spec.lua:32` and use `find lua -name '*.lua' | xargs grep -l`.

**I3 — `conform` warns once per dropped field, over collections with no size bound** (`lua/parley/helper.lua:690`, applied at `lua/parley/chat_respond.lua:268-271`; ARCH-CONSTRAINTS)

`logger.warning` (`lua/parley/logger.lua:89-101`) does a synchronous `io.open(file,"a")` + write **and** a scheduled `vim.notify` on every call. `load_remote_reference_cache` runs `conform` once over every cached chat and then once over every cached URL inside each chat. The audit in this very issue records that `remote_reference_cache.json` is path-keyed and never pruned, so that collection is unbounded. A file whose leaves are all the wrong type — the "written by an older/newer version" case ARCH-SECURE names — produces N log-file opens and N `vim.notify` calls on the first submission of the session, which in a real UI is a hit-enter prompt storm: a sidecar stopping someone from working on a chat, which is the exact class M1 exists to remove. Fix sketch: have `conform` collect dropped keys and emit **one** warning per call (`Ignoring 137 wrongly typed fields of <file> (chats, …)`), which also reads better for the 15-field `state.json` case.

## 4. Minor findings

- `tests/integration/sidecar_degrade_spec.lua` does not exercise the remote-reference cache on the *submission* path as Task 1.4 Step 3 specified (no remote reference in the fixture question, and `exercise` has already warmed `parley._remote_reference_cache` before `submits()` runs). `resolve_remote_references` is called unconditionally at `chat_respond.lua:1595`, so setting `parley._remote_reference_cache = nil` immediately before `submits()` would close it in one line. The deviation isn't in the issue's `## Log` deviation list.
- `tests/helpers/sidecars.lua:34` swaps `tasker.run` wholesale rather than driving the repo's stateful `fake_process` behind `tasker._uv` (ARCH-MOCK: a stateless function mock at a seam that already has a stateful fake). Also `vault.add_secret("copilot", …)` mutates module state and is never undone.
- `lua/parley/chat_respond.lua:1653`: the `{cancel = …}` handle returned by the `finalize` adapter has no consumer — `generation_runner.lua:502` does `local ok,err=pcall(s.adapters.finalize,…)` and only reads the second value on failure. Pre-existing shape faithfully carried by the plan's body, but M4's "every wait a generation holds settles" should either wire it or drop it.
- `tests/integration/sidecar_degrade_spec.lua:60` iterates `bodies` with `pairs`, so generated test order varies run to run; `ipairs` over a list of `{label, body}` would be stable.
- `tests/arch/sidecar_authority_spec.lua:20` asserts `vim.v.shell_error` inside an `it` body while the `systemlist` ran in the `describe` body; capture the code next to the call.
- `atlas/providers/tool_execution.md:12` is left as an orphaned short line and `:142`/`:200` were joined into long ones by the deletions; reflow those three paragraphs.

## 5. Test coverage notes

Coverage for this boundary is strong and I confirmed it by reverting rather than by reading. What is *not* covered: the custom-prompt write-back loss in I1 (no test observes the file after a `set`), and the untracked-reader hole in I2 (the plan's counterfactual only exercised a tracked file). Both fixes need a test that fails without them — for I1, a unit test asserting a malformed entry survives a `set`; for I2, the census counterfactual re-run against a genuinely new, unstaged file. I3 is a diagnostics-volume bound rather than a behaviour change; asserting `#warnings == 1` for a multi-field corrupt body is enough.

## 6. Architectural notes for upcoming work

- **ARCH-DRY** pass · **ARCH-PURE** pass (`conform` is pure bar its logger and has a direct unit test at `helper_io_spec.lua:262`; `file_to_table` is the thin IO shell) · **ARCH-ORDER** pass (M1 removes carried state — the on-disk store and the `unproved` subscription — and adds none) · **ARCH-PURPOSE** flagged (I2) · **ARCH-MOCK** flagged (Minor) · **ARCH-CONSTRAINTS** flagged (I3) · **ARCH-SECURE** flagged (I1; the parse-at-boundary half is correctly done, and the widened tool reach is a stated operator decision — note it was never a regression, since the old carve-out covered only `<state_dir>/answer-recovery`, leaving `vault_state.json`'s copilot bearer equally reachable before) · **ARCH-FUNERAL** tracked, not flagged: the legacy `<state_dir>/answer-recovery/` bytes now have no writer and no remover, and `delete_chat_file` no longer cleans them — that is PQ-3, already disposed at the plan gate into Task 5.4's inventory line. Confirm it actually lands there at M5.
- `conform` is shallow by design, and each of the four readers hand-writes its nested level. That is four places to update when a sidecar's shape changes. If a fifth nested reader appears in M2–M5, consider letting `schema` nest (`{chats = {["*"] = {["*"] = "string"}}}`) rather than adding a fifth call site.
- M4's admission-leak work will want the `finalize` handle question settled (Minor 3) before it audits W1–W16.

## 7. Plan revision recommendations

The plan still matches the code; the Core-concepts cross-check passes on every M1 row (`answer_recovery`, `recovery_paths`, `traversal_policy`, `chat_recovery`, `response_recovery` all absent from the tree; `helper` modified, and the row was correctly updated in `6db42dd4` to name `conform`; M2–M5 rows keep their `M<n> ·` prefix so the arch guard stays off). Two entries worth appending once the findings are disposed:

- **Task 1.4, Step 4** — record that the census must scan the working tree, not the git index, and why (an untracked reader is the normal state of a reader being written).
- **Task 1.4, Step 3** — record the executed deviation: the remote-reference case exercises the reader directly rather than through a question carrying a remote reference with a stubbed `oauth.fetch_content`.

```findings
findings:
  - id: new
    severity: Important
    family: read-filter-destroys-source
    title: |
      custom_prompts.load() prunes the map that set/remove/rename write back, erasing hand-edited prompts
    detail: |
      load() drops any entry whose system_prompt is not a string; set/remove/rename
      all do load() -> mutate -> save(all), so the dropped entry is written out of
      existence. Probed on the branch: a prompt with an array system_prompt vanishes
      from custom_system_prompts.json on the next set(), with no message naming it.
      Both consumers already guard type(prompt)=='table' and prompt.system_prompt, so
      filter the view, not the table that gets persisted.
  - id: new
    severity: Important
    family: guard-scans-index-not-worktree
    title: |
      The state_dir reader census greps the git index, so an untracked new reader escapes it
    detail: |
      tests/arch/sidecar_authority_spec.lua:15 uses `git grep -l -e state_dir -- lua/`.
      Adding lua/parley/zz_probe_reader.lua returning config.state_dir leaves the census
      3/3 green; only after `git add -N` does it fail. The guard therefore never fires
      during the loop that introduces a reader. The plan's own counterfactual passed only
      because it edited an already-tracked file. Use `git grep --untracked` or the
      find-based form already used by single_resolver_spec / untrusted_path_spec.
  - id: new
    severity: Important
    family: per-item-diagnostic-unbounded
    title: |
      conform emits one logger.warning per dropped field over the unbounded remote-reference cache
    detail: |
      logger.warning (logger.lua:89-101) opens and writes the log file synchronously and
      schedules a vim.notify on every call. chat_respond.lua:268-271 runs conform once per
      cached chat and once per cached URL, and the audit records that remote_reference_cache.json
      is never pruned. A file whose leaves are all wrongly typed yields N log opens and N
      notifications on the first submission of the session - a hit-enter storm from a sidecar,
      the class M1 exists to remove. Aggregate into one warning per conform call.
  - id: new
    severity: Minor
    family: plan-step-not-as-specified
    title: |
      The degrade spec does not exercise the remote-reference cache on the submission path
    detail: |
      Task 1.4 Step 3 called for a question carrying a remote reference with oauth.fetch_content
      stubbed. The spec's fixture question has none, and exercise() has already warmed
      parley._remote_reference_cache before submits() runs, so the submit-path arm of the read
      is never taken. resolve_remote_references is called unconditionally at chat_respond.lua:1595,
      so nil-ing the cache immediately before submits() closes it in one line. The deviation is
      not in the issue's Log.
  - id: new
    severity: Minor
    family: stateless-double-at-stateful-seam
    title: |
      The vault sidecar exercise replaces tasker.run wholesale instead of using the fake_process seam
    detail: |
      tests/helpers/sidecars.lua:34 swaps tasker.run for a callback-invoking stub rather than
      driving tests/helpers/fake_process.lua behind tasker._uv, so the real tasker path is not
      exercised (ARCH-MOCK). vault.add_secret("copilot", ...) also mutates module state that is
      never restored.
  - id: new
    severity: Minor
    family: returned-handle-has-no-consumer
    title: |
      The finalize adapter's returned cancel handle is discarded by the runner
    detail: |
      chat_respond.lua:1653 returns {cancel = ...}, but generation_runner.lua:502 does
      `local ok,err=pcall(s.adapters.finalize,ctx,complete)` and reads the second value only
      when ok is false. The cancel path it wires is unreachable; cancellation during finalization
      relies solely on response_completion's own D.subscribe and ctx.cancelled. Pre-existing shape
      carried by the plan's body - M4 should wire it or drop it.
  - id: new
    severity: Minor
    family: nondeterministic-test-generation
    title: |
      sidecar_degrade_spec generates its cases by iterating a keyed table with pairs
    detail: |
      tests/integration/sidecar_degrade_spec.lua:60 iterates `bodies` with pairs, so the order
      of generated tests varies between runs. A list of {label, body} pairs with ipairs is stable.
  - id: new
    severity: Minor
    family: assertion-detached-from-its-call
    title: |
      The census asserts vim.v.shell_error in an it body while the command ran in the describe body
    detail: |
      tests/arch/sidecar_authority_spec.lua:20 checks a global that any intervening shell call
      could have overwritten. Capture the exit code next to the systemlist call.
  - id: new
    severity: Minor
    family: docs-reflow-after-deletion
    title: |
      tool_execution.md left an orphaned short line and two over-joined lines after the carve-out removal
    detail: |
      atlas/providers/tool_execution.md:12 is a two-word orphan line; :142 and :200 were joined
      into long single lines by the deletions. Reflow those three paragraphs.
```

---

## Re-review — 2026-09-19T00:36:19-07:00 (REWORK)

| field | value |
|-------|-------|
| issue | 261 — Audit transcript as the complete recovery state |
| repo | parley.nvim |
| issue file | workshop/issues/000261-audit-transcript-recovery-state.md |
| boundary | milestone M1 |
| milestone | M1 |
| window | ff5ed804a7d58499a2964235f9897db53f2c85d3..55fe2cdef8d0c4c620ba1e0257d4ba527ef0bafc |
| command | sdlc milestone-close --issue 261 --milestone M1 |
| reviewer | claude |
| timestamp | 2026-09-19T00:36:19-07:00 |
| verdict | REWORK |

## Review

```verdict
verdict: REWORK
confidence: high
```

M1 delivers its purpose: the four recovery modules, the two commands, the tools privacy carve-out and the atlas page are gone (the plan's removal query now returns exactly one hit, the legacy-directory test); the #261 blocker is pinned by four independent regression tests that pass 31/31; every state-directory sidecar is parsed once at one boundary; and the census that guards the class is now genuinely effective — I planted an untracked `lua/parley/zz_probe_reader.lua` returning `config.state_dir` and it went red, the exact counterfactual that passed green last round (BR-6 confirmed fixed, not merely claimed). All twelve prior findings are disposed below, eleven of them `addressed` with verified evidence. What blocks SHIP is a regression this round's own BR-5 fix introduced: `custom_prompts.set` now returns `false` instead of raising, and the system-prompt editor's `BufWriteCmd` never reads that return — I reproduced it live, the buffer is marked unmodified (`bufhidden=wipe` then discards the text), the file is untouched, and the user is told **"System prompt saved"**. Before this diff the same path raised and the edit survived. That is the second finding in the `returned-handle-has-no-consumer` family, so the fix owed is the rule and its enumeration, not the one call site.

## 1. Strengths

- **`tests/integration/chat_respond_spec.lua:118-181`** — the reported blocker is reproduced four ways (further edit, reload, close-and-reopen, legacy directory on disk) rather than once, and the "immediately" case is explicitly labelled a characterization test. Ran green here: 31/31.
- **`tests/arch/arch_helper.lua:79-100` + `tests/unit/arch_helper_spec.lua:118-145`** — BR-6 was swept as a rule, not a site: six index-listing guards moved to `worktree_files`, and a unit test now fails any arch spec that reaches for `git ls-files` without `--others` or `git grep` without `--untracked`. Verified by planting an untracked reader (census failed with `*[1] = 'lua/parley/zz_probe_reader.lua'`).
- **One parse boundary, provably** — `grep -rn "json.decode" lua/` shows no unguarded decode of any state-directory file, and `grep -rl state_dir lua/` returns exactly the four declared readers plus the two `PATH_ONLY` entries, so `tests/arch/sidecar_authority_spec.lua` is not trivially satisfiable (ARCH-DRY).
- **`tests/unit/helper_io_spec.lua:270-280`** — BR-7's aggregation has a real oracle (300 bad leaves → exactly one warning naming the count), not a restatement of the implementation.
- **Docs gate is clean** — atlas page deleted, `atlas/index.md` entry removed, traceability block and three stale file entries removed, `README.md:82` sentence removed, `tests/manual/chat-concurrency.md` rewritten to the undo story, and the target's open question answered in a Revisions entry.

## 2. Critical findings

**C1 — `lua/parley/system_prompt_picker.lua:104`: the write refusal BR-5 introduced has no consumer, so an edited system prompt is discarded under a "saved" message.**

> **This is the 2nd finding in family `returned-handle-has-no-consumer`.** Earlier rounds fixed instances. Do NOT fix this instance — state the rule that covers all of them, and fix that.

Live reproduction (headless, this HEAD): open `edit_prompt(parley, 'mine')`, corrupt `custom_system_prompts.json` behind the editor (a crash mid-`table_to_file` does this — `helper.lua:572-582` is not atomic), type a new prompt, `:w` →

```
modified before write = true
modified after write  = false        <- bufhidden=wipe now discards the text
file on disk          = { not json
notify[1]: System prompt saved: mine
```

`custom_prompts.set` (`custom_prompts.lua:71-78`) returns `false`; `:104` ignores it, `:106` clears `modified`, `:107-108` claim success. Before this diff the same path *raised* from the unguarded `vim.json.decode`, so the write failed loudly and the text was preserved — this is a behavior regression, in the round whose commit subject is "writes keep authored data".

**The rule to fix, not the site:** *a call that reports whether an effect happened must have its outcome consumed by whatever tells the user it happened.* The enumeration this rule implies, for the surface this window touched:

| producer | outcome | consumer today |
|---|---|---|
| `custom_prompts.set` | `true/false` | `system_prompt_picker.lua:104` drops it; `:165` drops it (benign — `edit_prompt` re-checks) |
| `custom_prompts.remove` | `true/false` | `:197` drops it |
| `custom_prompts.rename` | `true/false` | `:237` reads it ✓ |
| `custom_prompts.save` → `helper.table_to_file` (`helper.lua:576-579`) | returns nothing on open failure | `set` returns `true` even when nothing was written — same false "saved" on an unwritable state dir |
| finalize adapter `{cancel=…}` | handle | `generation_runner.lua:502` discards it (BR-10, deferred to W18) |

Sweep that table in one round: give `table_to_file` a boolean, propagate it through `save`/`set`/`remove`, and make `:104` keep `modified = true` and report the refusal instead of success. Then pin it — a test that writes a corrupt prompts file, drives the `BufWriteCmd`, and asserts `modified` is still `true` and no "saved" message was emitted. Without that test the disposition is `not-addressed` by this review's own rule.

## 3. Important findings

**I1 — `lua/parley/custom_prompts.lua:30`: the parse is per call and the call is per item, so the picker emits one warning per prompt.**

> **This is the 2nd finding in family `per-item-diagnostic-unbounded`.** Earlier rounds fixed instances. Do NOT fix this instance — state the rule that covers all of them, and fix that.

BR-7 made `conform` warn once per *call*; `load()` re-reads and re-conforms the file on *every* call, and `system_prompt_picker.lua:20` calls `source()` → `get()` → `load()` once per prompt. Measured on this HEAD:

```
one wrongly typed entry : items=5  warnings_on_build=5
unreadable file         : items=5  warnings_on_build=10
```

Each warning opens/writes/closes the log file and schedules a `vim.notify` (`logger.lua:89-101`), so opening the system-prompt picker is a 5–10 notification storm that scales with the user's prompt count — the class M1 exists to remove, one level up from where BR-7 fixed it. The other three sidecars avoid this by memoizing (`chat_respond.lua:255`, `_parley._state`); `custom_prompts` alone re-reads.

**The rule:** *a diagnostic about a file's contents belongs to that file's parse, and a parse belongs to a user action — never to a loop iteration.* Fix it at that level (memoize the authored read per action, or hoist the read out of `_build_items`), and make it self-enforcing the way BR-6 was: `sidecar_degrade_spec` already drives each reader through `exercise()`, so count `logger.warning` calls there and assert ≤1 per file per exercise. That assertion catches every future member of the family, including this one.

**I2 — `lua/parley/vault.lua:215`: the token endpoint's body is decoded unguarded, forty lines below the read this diff just taught to parse at the boundary.**

`V._state.copilot_bearer = vim.json.decode(stdout)` then `.token` is indexed. `curl -s` exits 0 on an HTML proxy/captive-portal page or an empty body, so a non-JSON 200 raises inside the tasker callback and `callback()` — the continuation that resumes the provider request — is never reached. This is the only unguarded decode of external process output left in `lua/`: all nine siblings in `oauth.lua` (`:543, :866, :1616, :1665, :1691, :1814, :1857, :1943, :1985`) are `pcall`ed, so the consistent form already exists (ARCH-SECURE: an external API body is untrusted; ARCH-DRY: match the siblings). The diff hardened this function's *file* input (`:174-176`) and left its *network* input, which is what writes that file. W6 (`plan:1285`) names only the `code~=0` and early-return paths that skip the callback — the raise is a third path and the row does not have it. Cheap disposition: `pcall` the decode, call back with the error, and add the raise path to W6.

## 4. Minor findings

- **`tests/unit/helper_io_spec.lua:228`** — the F3b cases are generated by `for label, content in pairs({…})`, so test order and names vary between runs. **This is the 2nd finding in family `nondeterministic-test-generation`** (BR-11 fixed `sidecar_degrade_spec` this round; this file introduced a new one in the same commit). Don't just convert this site: state the rule — *generated `it(` cases iterate an ordered list, never a keyed table* — add it to `workshop/lessons.md` alongside this round's three entries, since the family now has two instances one commit apart and no guard. A mechanical guard is possible but fragile (a `pairs(` loop whose body contains `it(` is grep-able but noisy across ~5 pre-existing arch specs); the lesson entry plus the two conversions is the proportionate class fix.
- **`workshop/plans/000261-transcript-is-the-whole-truth-plan.md:277-598`** — every M1 step checkbox is still `- [ ]`, as is the `- [ ] M1` row in the issue's `## Plan`, although M1 is complete. The durable plan is the record of what landed (AGENTS.md §8); tick them at the close.
- `helper.conform` (`helper.lua:706`) mutates its argument *and* returns it, and `file_to_table:674` has to wrap the call in parentheses to drop the second return. For a helper M2–M5 will consume, `(tbl, dropped)` from a copy, or a documented mutate-only contract, is the steadier surface.

## 5. Test coverage notes

- Verified green on this HEAD, individually: `sidecar_degrade_spec` (14), `sidecar_authority_spec` (4), `arch_helper_spec` (9), `custom_prompts_spec` (17), `helper_io_spec` (39), `chat_respond_spec` (31), `single_source_sweeps_spec` (23), `superseded_comment_spec` (9), `tool_process_scope_spec` (15), `async_builtin_spec` (18), `tool_dispatch_capture_spec` (14), `batch_lifecycle_spec` (7), `tool_process_scope_spec` unit (7).
- BR-5's A2b/A2c are proper oracles: A2c asserts `set` returns `false` and the corrupt file is byte-identical afterwards, both of which the pre-fix `load()`-based write fails by construction.
- The coverage gap is C1: the *refusal* half of BR-5's fix has a unit test (`set` returns false) but no test of what the refusal does to the user — which is where the data loss is. A picker-level test is the one this diff needed.
- `sidecar_degrade_spec` asserts only "does not throw / reaches the provider". Adding the warning-count assertion (I1) turns it into the enforcement point for the diagnostics class too, at no extra fixture cost.

## 6. Architectural notes for upcoming work

- **ARCH-DRY — pass.** One parse boundary for four sidecars; six index-listing guards collapsed into `worktree_files`; the sidecar list is a single source for both the census and the behaviour spec.
- **ARCH-PURE — pass with a note.** `conform` is declared under Integration points, so embedding `logger.warning` in it is within its declared kind; but the transformation itself is pure and the tests must stub the logger to observe it. Returning `dropped` and letting `file_to_table` emit the single warning would make the "one warning per parse" property (I1) structural rather than conventional.
- **ARCH-PURPOSE — pass.** Shadow-sweep run: no consumer of the deleted store remains (removal query returns only the legacy test), and the census derives from the same table the degrade spec drives. The one deferred item (naming the legacy directory) is a genuine separable extension, not the point of the issue.
- **ARCH-MOCK — pass.** BR-9 fixed: the vault exercise now drives `fake_process` behind `tasker._uv` on a fresh module instance. Note for M3: that exercise leaves one unresolved fake record in the shared tasker for the rest of the file — harmless today, but M3/M4 will assert `stats().active`, so drain it when those assertions arrive.
- **ARCH-CONSTRAINTS — flag, see I1.** The per-item diagnostic is the only envelope breach in the window; `conform`'s recursion is bounded by schema depth (≤3), so hostile nesting cannot blow the stack, and the remote cache is conformed once per session.
- **ARCH-SECURE — flag, see I2.** Sidecar inputs are now typed at the boundary; the external body that feeds one of them is not. Also worth carrying forward: the census keys on the literal string `state_dir`, so a future reader that receives the path under another parameter name escapes it. All six current hits contain the literal, so there is no hole today — but M5's inventory page is the place to say that the census's reach is lexical.
- **ARCH-ORDER — pass.** M1 adds no state carried between events; the read result's three legal values (`{}` / table / `nil`) are enumerated in the doc comment at `custom_prompts.lua:39-42`. C1 is the reminder that a tri-state read is only as good as the branch that consumes it.
- **ARCH-FUNERAL — pass for this window.** Nothing durable is created; the legacy directory's end is named in Task 5.4 (BR-3). Keep an eye on the remote-reference cache: still unpruned, and now conformed on every load.

## 7. Plan revision recommendations

- **W6 (`plan:1285`)** — add the third non-calling path: `vim.json.decode(stdout)` at `vault.lua:215` raises inside the callback, so the continuation is skipped exactly as on `code~=0`. Today the row promises "call back with the error on both paths" and there are three.
- **Task 1.4 Step 2 (`plan:472-490`)** — the embedded body shows `file_to_table` with no `schema` parameter and no `conform`; the code has both. The Core-concepts row was corrected but the body was not. Either fold the schema into the body or, if the operator's "the code is authoritative" rule (Revisions, 2026-09-18) is meant to cover this, add one line to Task 1.4 saying so, so a reader of the task does not implement the superseded shape.
- **A `## Revisions` entry for M1's close** recording: (a) the degrade spec reads the remote cache cold rather than through a stubbed `oauth.fetch_content` (Step 3's stated method), and (b) the `custom_prompts` read/write split (`read_authored`) that Task 1.4 did not anticipate — the Core-concepts table gained the row, but no Revisions entry explains why the task grew a second modified module.

```findings
dispose:
  - id: BR-1
    disposition: addressed
    note: |
      W13 now names all ten Deferred owners with a scope reason each (verified: nine live owners plus the deleted chat_recovery:258); W16 corrected to response_topic.lua:80 from :154 with s.started at :59 — all three line references check out.
  - id: BR-2
    disposition: addressed
    note: |
      Task 3.3 now names tasker_run_spec.lua, its 43 option-less calls (grep -c confirms 43) and a re-grep that would also surface chat_async_tools_spec.
  - id: BR-3
    disposition: addressed
    note: |
      Task 5.4's inventory now names the legacy directory as safe to delete; the page it belongs to does not exist until M5, so deferring it there is the right home.
  - id: BR-4
    disposition: withdrawn
    note: |
      Operator decision recorded in the plan's Revisions with an explicit authority rule; the divergence it predicted has already appeared (Task 1.4's body lacks the schema arg) and that rule governs it — see the plan-revision recommendation rather than re-raising.
  - id: BR-5
    disposition: addressed
    note: |
      read_authored/load split plus A2b/A2c pin the file-preservation half; the writes/preserve declaration is enforced by the census. The refusal half it introduced is now C1.
  - id: BR-6
    disposition: addressed
    note: |
      Verified by counterfactual: an untracked lua/parley/zz_probe_reader.lua returning config.state_dir turns the census red, and arch_helper_spec fails any arch spec that lists through the index.
  - id: BR-7
    disposition: addressed
    note: |
      conform emits one warning per call with a count and a five-path sample; 300 bad leaves produce exactly one (helper_io_spec). The per-call-per-item level above it is I1.
  - id: BR-8
    disposition: addressed
    note: |
      submits() nils parley._remote_reference_cache immediately before the command, so resolve_remote_references reads the corrupt file on the submission path (get_chat_remote_reference_cache is unconditional at chat_respond.lua:1200).
  - id: BR-9
    disposition: addressed
    note: |
      The vault exercise drives tests/helpers/fake_process.lua behind tasker._uv on a fresh module instance, restoring both; nothing leaks into the shared vault module.
  - id: BR-10
    disposition: addressed
    note: |
      Carried into the plan as M4 row W18 with both options named and a cancellation-during-finalize test.
  - id: BR-11
    disposition: addressed
    note: |
      sidecar_degrade_spec builds a `cases` list and iterates it with ipairs. A new instance appeared elsewhere in the same commit — see the Minor.
  - id: BR-12
    disposition: addressed
    note: |
      The exit-code assertion moved next to its systemlist call inside arch_helper.worktree_files; the census now asserts a floor on the hit count instead.
  - id: BR-13
    disposition: addressed
    note: |
      atlas/providers/tool_execution.md:11-19, :142-147 and :194-209 are reflowed; no orphan or over-joined line remains in the touched paragraphs.
findings:
  - id: new
    severity: Critical
    family: returned-handle-has-no-consumer
    title: |
      custom_prompts.set's new false return is dropped by the prompt editor, which clears `modified` and reports "System prompt saved"
    detail: |
      2nd in this family — fix the rule, not the site: every call reporting whether an effect
      happened must be consumed by whatever tells the user it happened. Enumeration to sweep:
      helper.table_to_file (returns nothing on open failure), custom_prompts.save/set/remove,
      system_prompt_picker.lua:104 and :197, plus the W18 handle. Reproduced live: with an
      unreadable custom_system_prompts.json, :w on an edited prompt leaves the file untouched,
      sets modified=false (bufhidden=wipe then discards the text) and notifies "System prompt
      saved: mine". Before this diff the same path raised and the edit survived. Needs a
      picker-level regression test that fails without the fix.
  - id: new
    severity: Important
    family: per-item-diagnostic-unbounded
    title: |
      custom_prompts.load re-reads and re-conforms the file on every call, and the picker calls it once per prompt
    detail: |
      2nd in this family — BR-7 fixed the per-field warning; the call itself is per item.
      system_prompt_picker.lua:20 calls source() -> get() -> load() for every prompt. Measured on
      this HEAD: one wrongly typed entry gives 5 warnings per picker build, an unreadable file
      gives 10, scaling with the user's prompt count; each is a log-file open plus a vim.notify.
      The rule: a diagnostic about a file's contents belongs to that file's parse, and a parse
      belongs to a user action, never to a loop iteration. Enforce it where the family can be
      caught wholesale — count logger.warning calls per exercise in sidecar_degrade_spec and
      assert at most one per file.
  - id: new
    severity: Important
    family: untrusted-input-unparsed
    title: |
      vault.lua:215 decodes the copilot token endpoint's body without a pcall, in the function whose file read this diff just hardened
    detail: |
      curl -s exits 0 on an HTML proxy page or an empty body, so a non-JSON 200 raises inside the
      tasker callback and the continuation that resumes the provider request is never reached.
      It is the only unguarded decode of external process output left in lua/ — all nine siblings
      in oauth.lua are pcall'ed. W6 names the code~=0 and early-return paths that skip the
      callback but not this third one; either pcall it now and call back with the error, or add
      the raise path to W6.
  - id: new
    severity: Minor
    family: nondeterministic-test-generation
    title: |
      helper_io_spec.lua:228 generates its F3b cases by iterating a keyed table with pairs
    detail: |
      2nd in this family, introduced in the same commit that fixed BR-11's instance, and there is
      no guard to catch the next one. State the rule instead of converting only this site:
      generated `it(` cases iterate an ordered list, never a keyed table — add it to
      workshop/lessons.md beside this round's three entries. A mechanical guard is possible but
      noisy against roughly five pre-existing pairs-driven arch specs, so the lesson plus the two
      conversions is the proportionate class fix.
  - id: new
    severity: Minor
    family: plan-tracking-not-updated
    title: |
      Every M1 step in the durable plan is still unticked, as is the M1 row in the issue's Plan
    detail: |
      workshop/plans/000261-transcript-is-the-whole-truth-plan.md:277-598 and the issue's
      `- [ ] M1` row. The durable plan is the record of what landed (AGENTS.md section 8); with no
      box ticked a reader cannot tell M1 from M2 by looking at it.
```

---

## Re-review — 2026-09-19T00:50:01-07:00 (FIX-THEN-SHIP)

| field | value |
|-------|-------|
| issue | 261 — Audit transcript as the complete recovery state |
| repo | parley.nvim |
| issue file | workshop/issues/000261-audit-transcript-recovery-state.md |
| boundary | milestone M1 |
| milestone | M1 |
| window | ff5ed804a7d58499a2964235f9897db53f2c85d3..dd8122745bd377e74c07aeecdd0c2c91f18836c6 |
| command | sdlc milestone-close --issue 261 --milestone M1 |
| reviewer | claude |
| timestamp | 2026-09-19T00:50:01-07:00 |
| verdict | FIX-THEN-SHIP |

## Review

```verdict
verdict: FIX-THEN-SHIP
confidence: high
```

**Verdict: fix one Important finding, then ship.** Round 2 fixed all five open findings, and I checked each one against the code, not the commit message. The picker now uses the result of every write and keeps the edit when a save is refused. The P1 test fails when that fix is reverted in a scratch copy. The picker reads the prompt file once per build, and reverting that fix turns P3 and three degrade cases red. Every `vim.json.decode` in `lua/` is under `pcall`, and W6 now names the decode path. What stops a clean SHIP is the result the new picker check relies on: `table_to_file` returns `true` when the write fails at `close`. I reproduced this with a file-size limit (`ulimit -f 1`). `table_to_file` returned `true` and left 512 bytes of a 2.8 KB JSON file. On the same input, `table_to_file_atomic` returned `false, "close failed: File too large"`. So when the disk is full or a quota is hit, the picker still says "System prompt saved" and truncates the user's whole prompt file. That is the case round 2 set out to close. The fix is cheap: `table_to_file_atomic` already exists at `helper.lua:596`.

**1. Strengths**
- **Picker (BR-14):** `system_prompt_picker.lua:109,173,210,254` each use the write result. A refused save leaves `modified` set, so `bufhidden=wipe` cannot throw the edit away. P1 fails without the fix (scratch revert run).
- **One read per build (BR-15):** `source(name, builtins, loaded)` reads the file once. The warning bound sits in the generic `sidecar_degrade_spec` loop, so it covers every sidecar, not just this one.
- **Decode guard (BR-16):** `json_decode_spec` finds all 33 decodes guarded, and it has a floor so a broken pattern cannot pass empty. The W6 row in the plan now names the non-decoding token body.
- **Bare-write guard:** the guard against sidecar writes called as bare statements has the right shape: any unhandled write must be declared, with a reason.
- **BR-17 / BR-18:** F3b now iterates an ordered list, and the lesson is recorded. Chunk 1's steps are ticked. The issue's `- [ ] M1` row is ticked by `sdlc milestone-close` itself (its `--help`, step 1), so leaving it unticked is correct.

**2. Critical findings:** none.

**3. Important findings**
- **`helper.lua:577-589`** — `table_to_file` ignores the result of `file:close()`. With buffered output, a failed flush only shows up at close, so the function reports a write that did not land.
  - The file is opened with `"w"`, which empties it before the write, so the user's file ends up truncated.
  - Custom prompts: every authored prompt is lost, the user is told "saved", and every later `set` refuses because the file no longer parses.
  - Dispatcher: `curl` posts a truncated request body, which is the unexplained transport error the new abort was meant to prevent.
  - The `DROPPED` reasons in `sidecar_authority_spec.lua` say a failed write "has already warned". That is only true when `open` fails.
  - This is the **3rd finding in family `returned-handle-has-no-consumer`**; the rule is stated in the findings block below.
  - Fix: route sidecar writes through `table_to_file_atomic`, and retire or delegate `table_to_file`.

**4. Minor findings**
- **`vault.lua:218`** — the network response is checked only for `token`, while the file read at `:174` types both `token` and `expires_at`.
  - A non-numeric `expires_at` makes the comparison at `:180` raise on the next request.
  - Two schemas for one value; the fix is one shared schema (ARCH-DRY, ARCH-SECURE).
- **`dispatcher.lua:676-680`** — the new abort for a request body that was not written has no behavioural test.
- **`json_decode_spec.lua`** — the guard matches only `vim.json.decode`, not `vim.fn.json_decode` (`file_tracker.lua:47`).
- **`sidecar_authority_spec.lua:60`** — `DROPPED` is keyed by file, so a future bare write in `vault.lua` or `chat_respond.lua` would pass the guard silently.

**5. Test coverage notes.** Runs at HEAD in an isolated environment, all passing:

| Spec | Result |
|---|---|
| `custom_prompts_spec` | 20/20 |
| `helper_io_spec` | 40/40 |
| `sidecar_authority_spec` | 5/5 |
| `json_decode_spec` | 2/2 |
| `sidecar_degrade_spec` | 14/14 |
| `arch_helper_spec` | 9/9 |

- **Reverts in a scratch copy:**
  - Picker fix reverted: P1 fails.
  - BR-15 fix reverted: P3 fails, plus three degrade cases.
- **Gap:** F3d tests only a failed `open`. No test covers a failed flush at `close`, which is where buffered writes fail in practice.

**6. Architectural notes for upcoming work**

| Principle | Result |
|---|---|
| ARCH-DRY | **flag**: two JSON writers with different failure reports, and the user-authored file gets the weaker one; two bearer schemas |
| ARCH-PURE | pass |
| ARCH-PURPOSE | pass: the Done-when for deleting the store holds, and no references remain outside `workshop/` |
| ARCH-MOCK | pass: the vault exercise runs on `FakeProcess` |
| ARCH-CONSTRAINTS | pass: one read per user action |
| ARCH-SECURE | minor flag: `expires_at` |
| ARCH-ORDER | pass: a refused save leaves `modified` set, so `:q` refuses |
| ARCH-FUNERAL | pass: the query directory prune bounds leftover bodies; the atomic writer also cleans up its temporary file on failure |

- The other 17 places in `lua/` that open files for writing are outside the state-directory family; I recorded them rather than asking for a sweep in M1.

**7. Plan revision recommendations**
- Add a Revisions entry: "Sidecar writes go through `table_to_file_atomic`; its result is derived from encode, open, write, close and rename, and the original file survives a failed write. `table_to_file` is retired or delegates to it. The guard rejects non-atomic sidecar writes."

```findings
dispose:
  - id: BR-14
    disposition: addressed
    note: |
      picker.lua:109/173/210/254 consume set/remove/rename; P1 goes red when the fix is reverted in a scratch copy; bare-write guard present. The close-unchecked report gap is raised separately.
  - id: BR-15
    disposition: addressed
    note: |
      _build_items reads once via source(...,loaded); generic per-action bound in sidecar_degrade_spec; revert turns P3 plus 3 degrade cases red.
  - id: BR-16
    disposition: addressed
    note: |
      vault.lua:217 pcall plus type check; W6 names the non-decoding body path; json_decode_spec fails any unguarded vim.json.decode (33 found, all guarded).
  - id: BR-17
    disposition: addressed
    note: |
      helper_io_spec F3b iterates an ordered list; lesson recorded in workshop/lessons.md; no other pairs-driven it( generation in the window's specs.
  - id: BR-18
    disposition: addressed
    note: |
      Chunk 1 steps ticked in the durable plan; the issue's M1 row is ticked by sdlc milestone-close itself (its --help, step 1).
findings:
  - id: new
    severity: Important
    family: returned-handle-has-no-consumer
    title: |
      table_to_file drops file:close()'s result, so it reports true for a write that failed at flush and left the file truncated
    detail: |
      3rd in this family. Reproduced: under ulimit -f 1, table_to_file returned true and left 512 bytes of a 2.8 KB JSON file; table_to_file_atomic returned false with "close failed: File too large". The picker then says "System prompt saved" over a truncated custom_system_prompts.json, losing every authored prompt, and the dispatcher posts a truncated body. DROPPED's "has already warned" holds only for a failed open. Rule: a success result is derived from the last fallible step of the effect and consumed up to the user-visible claim; no fallible result is dropped on a path that reports success. Class fix: one JSON writer. table_to_file_atomic (helper.lua:596) already checks encode, open, write, close and rename and preserves the original file on failure. Move its 4 production callers (custom_prompts.save, dispatcher.query, vault, chat_respond) to it, retire table_to_file or make it delegate, and extend sidecar_authority_spec to reject non-atomic sidecar writes. Prevalence: 18 write-mode io.open sites in lua/; only this one is in the state-directory family.
  - id: new
    severity: Minor
    family: untrusted-input-unparsed
    title: |
      The copilot token response is typed on token only, while the file read of the same bearer also types expires_at
    detail: |
      2nd in this family. vault.lua:218 stores the fetched table in V._state, so a non-numeric expires_at raises at :180 on the next request. Rule: one schema per external value, applied at every boundary it crosses. Hoist { token = "string", expires_at = "number" } and apply it to both the file read and the network response.
  - id: new
    severity: Minor
    family: behavior-change-without-regression-test
    title: |
      The dispatcher's new abort for an unwritten request body has no behavioural test
    detail: |
      dispatcher.lua:676-680. Only the bare-write guard would notice a revert; nothing checks that the request stops and the user sees the reason.
  - id: new
    severity: Minor
    family: enumeration-claims-completeness
    title: |
      json_decode_spec matches only vim.json.decode, and the lesson says it fails any unguarded decode
    detail: |
      2nd in this family. vim.fn.json_decode (file_tracker.lua:47, currently guarded) escapes the pattern. Rule: a guard's pattern covers every API that does the job, not just the spelling the finding named.
```
