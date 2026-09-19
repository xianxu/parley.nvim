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
