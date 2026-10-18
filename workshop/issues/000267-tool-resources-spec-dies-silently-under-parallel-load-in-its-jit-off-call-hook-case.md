---
id: 000267
status: working
deps: []
github_issue:
created: 2026-09-18
updated: 2026-10-17
estimate_hours:
card_mirror: '55467888519e1841ad65599e2c7406c26608ea2f' # card fields mirrored from issue-cards; edit via sdlc
started: 2026-10-17T22:17:23-07:00
claimant:
    operator: Xian Xu
    machine: 4716879978a7b90f6b583da1716fd0e9
    machine_name: Xian’s MacBook Pro
    workspace: parley.nvim:1
    worktree: /Users/xianxu/workspace/worktree/parley.nvim-slot1/parley.nvim
    repository: github.com/xianxu/parley.nvim
flow: {kind: quick, provenance: inferred, spec: "e2389806", done: "1df0bf0a"}
---

# tool_resources_spec dies silently under parallel load in its JIT-off call-hook case

## Problem

`tests/unit/tool_resources_spec.lua` intermittently kills its Neovim process
under parallel load: exit code 1, no failing assertion, output ending right after
"reserves newly freed capacity for older runnable waiters" — i.e. inside the next
case, "bounds pump work for a full queue of maximum-width dependency chains",
which turns the JIT off (`jit.off(); jit.flush()`) and installs a per-call debug
hook around `R.pump`.

Because `make test` runs its phases in sequence, one abort in the unit phase
skips the whole integration phase. It did so twice in four full runs on the
#266 branch, leaving close evidence without integration results.

## Spec

Find why the process dies and make the case deterministic under load, without
weakening what it bounds (pump work over a full queue of maximum-width chains).

## Done when

- `tool_resources_spec` passes 64/64 under 16-way parallel stress.
- The bounded-work assertion still fails when `R.pump` goes super-linear.
- On stock 0.11, the full fold-batch corpus under sixteen-way load completes
  with global JIT enabled and no mcode-allocation abort storm in D.drain;
  unrelated code still compiles. Fixed runtimes and other platforms keep
  their compilation behavior.
- The implicated corpus and full suite pass on installed 0.11.7 and preferred
  0.12.5 without changing deadlines, corpus sizes or work-count assertions.
- The storage-reclamation child proves sequence code actually compiled, so
  scoped protection cannot make its active-JIT oracle vacuous.

## Plan

- [x] Reproduce, isolate the dying call, fix, stress.

## Log

### 2026-10-17 — final full verification green

The one unchanged-code retry c83da5529448660148145c8a4b3d874a completed
exit 0 in 3m37s on 18dac2ef (code/tests identical to b8b171a9). All 469 spec
files passed, including owned-move; lint and orphan censuses were clean.
The runner recorded sdlc-local/suite on 18dac2ef. Log:
.git/sdlc/local-checks/18dac2ef65ad445c3239bfde2efbf7a5c3bbaa87/suite.log,
sha256 81daf344f2a07d85d167267cd4ba4dbeee93c47d9dcbdf069b66dc6e497279da.
Together with the recorded manual stock-0.11 result below, both full runtime
passes are green. No second retry, deadline change or complexity relaxation.

### 2026-10-17 — first recorded 0.12 result and known #382 retry

Attempt 688bc1df2febd311acf4fd3bee7fe196 on b8b171a9 completed all phases:
468 PASS files, one error in agentic_document_owned_move_spec before_each
line 66, admitted.kind unavailable instead of registered for the case at line
480. Its 33 other cases passed. This is the existing #382 fake-registry setup
failure, not a stalled drain. Every #267-family file passed. Suite exit 2,
2m25s execution; log .git/sdlc/test-stats/failed/688bc1df2febd311acf4fd3bee7fe196.log,
sha256 3fcd052486401a5180e4d79924890c0340e588d71d37ec97e008ef0f74504156.

Taking tl-worker's one unchanged-code rerun for a tracked unrelated flake.
Retry attempt c83da5529448660148145c8a4b3d874a is live on pushed tip
18dac2ef65ad445c3239bfde2efbf7a5c3bbaa87, with the same code/tests as b8;
expected log .git/sdlc/test-stats/inflight/c83da5529448660148145c8a4b3d874a/run.log.
It remains queued (do not restart a healthy run). The prior stock-0.11 full
run is complete and green, so only this default-suite result is outstanding.
The binary refuses --rev b8 because the docs-only PR update moved origin's
branch tip; that refusal ran no suite. Push current docs and retry the tip,
whose production code and tests are identical to b8. If that rerun fails on
another unrelated flake, stop and ask the TL before any further rerun.

### 2026-10-17 — full stock-0.11 result

PARLEY_TEST_NVIM=/opt/homebrew/bin/nvim make -k test exited 0. Confirmed
/opt/homebrew/bin/nvim resolves to /opt/homebrew/opt/nvim-0.11/bin/nvim.
All 469 spec files passed, zero failure/deadline blocks, both orphan censuses
clean, lint 0 warnings/0 errors. The blocking fold-batches file passed in 35 s;
retirement/uncertainty passed in 31/32 s. Final scope and active-JIT storage
regressions passed (2 s / 3 s). Log /tmp/parley-267-full-011.log,
sha256 f1ec0ec6e8bdc1dceb664811d122009a80ee05df7250bc43b2fae97259bcd2ad.
Recorded default-0.12 suite has acquired its slot and is running; close remains
pending that result.

### 2026-10-17 — current verification checkpoint

Implementation code head: b8b171a9660a45fae9de215821f65b639d0bbea7;
later acceptance-fingerprint changes are docs-only. Draft PR #303:
https://github.com/xianxu/parley.nvim/pull/303 (server merge-check and both
local-gates checks passed). Fifteen targeted files on each runtime, 64/64
resource-admission stress per runtime, scoped global-JIT-enabled 0.11 drain
16/16 with zero allocation aborts/flushes, and lint are green.

Full verification is still pending behind the shared suite budget:
- Recorded default-0.12 suite, local-check attempt
  688bc1df2febd311acf4fd3bee7fe196, on b8b171a9;
  .git/sdlc/test-stats/inflight/688bc1df2febd311acf4fd3bee7fe196/run.log.
- Stock 0.11 full suite: PARLEY_TEST_NVIM=/opt/homebrew/bin/nvim make -k test;
  log /tmp/parley-267-full-011.log, from this checkout. Both runs remain live;
  preserve their queue places. Do not close before their results.

Completed diagnostic scratch roots were removed after preserving results and
representative raw logs/native sample in
/var/folders/07/b9wcwwld4_v2w9r3hk525bm80000gn/T/parley-267-evidence.onWZVi.
Its summary includes positive and intentional negative/setup-control runs, not
312 green runs. Keep this compact evidence through the review, then retire it;
the reproducible regressions and recorded full-suite evidence remain in Git
and sdlc. No production deadline, corpus or complexity oracle was changed.


### 2026-09-18

Found while closing parley#266 M2; not caused by it — the module and spec are
identical to `main`, and the same stress fails 2/16 at #266's M1 close commit
`f6ebfd83`.

- Alone: passes, ~1.1 s. Under 16 concurrent runs: 1–3 of 16 die (exit 1).
- **Ruled out: the hook's own `error()`.** The pump makes 1,139,718 calls,
  deterministically, against a 3,145,728 budget, so the error branch never runs.
  A copy with the error line removed fails at the same rate (3/16, 2/16).
- A copy containing *only* that case passed 16/16, so preceding cases' state
  (garbage, timers) plausibly matters — a GC finalizer or a scheduled callback
  running with the JIT off and the hook installed is the next thing to test.

### 2026-09-18 — a second spec with the same signature

Seen while closing parley#266 M4: `tests/unit/document_dependencies_spec.lua`
dies with exit 1 and no assertion, always partway through its "bounds dependency
and actual sequence navigation at fifty thousand origins" case. Alone it passes
in ~1 s. Under 16 concurrent runs it fails 8/64 at #266's M3 close `e48362ab` and
2/64 at M4 `3ff5ea46`, so it predates M4, and its module graph (`dependencies`,
`grammar`, `lexical`, `sequence`) shares nothing with `tools/resources`. It lost
the unit phase of two full `make test` runs, once at JOBS=4. A cause in
the harness or runtime, not in either module, now looks more likely than one
specific to the call-hook case.

### 2026-09-18 — a second spec in the same family (observed from #261 M1)

`tests/integration/perf_ownership_spec.lua` dies the same way: no output after
its first case, followed by a process exit.
- **Alone, it runs 18–50 s on both the base commit and the #261 branch.**
  Alternating A/B timings (base / branch, in seconds): 50.24 / 32.84,
  50.23 / 26.00, 25.74 / 26.10, with a load average around 3.2. The two base
  runs at 50.2 s died at the harness's ~50 s cap.
- **Under `make test` it died twice, at JOBS=8 and JOBS=4.**
- **`tests/unit/document_dependencies_spec.lua` also died silently once** at
  JOBS=8. It passes alone.

So the family is not specific to the JIT-off hook in `tool_resources_spec`: any
spec near the per-file cap dies silently under load. The Done-when should cover
the cap, not only the one case.

### 2026-09-19 — two more silent deaths under JOBS=4 (from #261 M1 round 3)

`tests/integration/document_fold_batches_spec.lua` stopped after 4 of its 5
cases, and `document_fold_uncertainty_retirement_spec.lua` stopped before its
first. Alone, both pass (5/5 and 1/1). #261's diff touches no fold code. That
makes five specs in this family.
- 2026-09-19 (from #261 M1 close): `perf_chat_typing_spec` died silently after
  4 of 16 cases under JOBS=4, and passes alone (16/16, 22.5 s).
  `perf_ownership_spec` died again in the same run. That makes six specs in
  the family, and a different one dies on each full run.
- 2026-09-19 (#261 M2): `highlight_typing_spec` died silently after 4 cases under JOBS=4; passes alone 8/8 — a seventh spec.

### 2026-09-19 — one member of the family explained (parley#261 M5)

`dispatcher_query_spec`'s parallel-load flake was not a silent death. It was a
shared directory. The spec wrote request bodies into `stdpath('cache')`, which
all specs in one `make test` run share, and a parallel spec removed the file
("rename failed: No such file"). parley#261 gave it its own `tempname()`
directory and added a guard against writes to the shared cache
(`single_source_sweeps_spec`).

Two members still die silently after many passing cases, and both also die on
a clean HEAD:
- `response_tools_spec`: 2 of 17 runs on the #261 tree, and on the 2nd run of a
  clean HEAD worktree, after 72 cases;
- `perf_ownership_spec`, `perf_document_spec`, `perf_chat_typing_spec` and
  `document_append_extent_spec`: under load only.

Shared writable state is worth ruling out for each one before looking at the JIT.
- The native-fold specs belong to the family too. `document_fold_retirement_spec`
  died on the 2nd run on #261's base tree (91f296b5). `document_fold_batches_spec`
  hung there after 4 of its 5 cases. `document_fold_uncertainty_retirement_spec`
  dies under load only. None of them touches #261's code.


## Revisions

### 2026-10-17 — reopened investigation for #379's stock 0.11 compatibility pass

The original call-hook attribution was only a last-output location, not a proven
cause. The current blocking sample is main's failed suite
`c2a80924993e69f8b0acfab8f82b0969`: fold-batches passes on 0.12, then the
installed 0.11.7 stalls after four cases (235 s total, 213625 ms idle).
Investigate the stall itself; keep case-progress deadlines and bounded-work
assertions unchanged. Cover stock 0.11.7 and preferred 0.12.5 under parallel
load, including the original tool-resources case.

Investigation evidence (before implementation):

- Claimed from an unowned open card; start-plan based on main `6e571cf4`.
- Sixteen parallel fold-batches workers with **private HOME/XDG/TMPDIR per
  process**, existing JITSTAT enabled: 0.11 passes 16/16 in 33.24–96.23 s;
  0.12 passes 16/16 in 34.67–37.89 s. This reproduces the unstable 0.11
  slowdown, not yet the original deadline failure. Example 0.11 worker:
  9,125 trace-cache flushes, 71% sampled JIT-compiler time; the corresponding
  0.12 worker has 3 flushes, 2% compiler time.
- A disposable spec copy wraps document attach/drain and fold setup/flush.
  Slow workers spend the long interval inside the fifth fixture's D.drain,
  **before F.setup**, and record 4,274 / 4,528 JIT aborts with reason 27,
  `failed to allocate mcode memory`. Native sample confirms trace recording,
  assembly, mcode allocation and exception-unwind work rather than a blocked
  native fold call. This matches the pre-fix allocator described by #294 and
  upstream LuaJIT commit 68354f4447.
- Runtime identities: 0.11.7 has LuaJIT 2.1.1741730670; 0.12.5 has
  LuaJIT 2.1.1788856981; both arm64 OSX. The existing harness tunes only the
  repaired runtime and currently leaves the old allocator enabled.
- Interpreter-only disposable 0.11 copies pass 4/4 under concurrent stress,
  with 1 explicit startup flush and 0% JIT compiler samples. Their 70–77 s
  wall times overlap a separate sixteen-worker batch, so they are a mechanism
  check, not an apples-to-apples speed comparison.
- Unprofiled 0.11 stress remains in flight; collect it before finalizing the
  diagnosis. Temporary scripts/logs are in TMPDIR/parley-267-* and /tmp;
  preserve the results here, then remove scratch trees once no worker needs them.

Proposed quick-flow implementation plan — **awaiting TL approval**:

- [ ] Finish the unprofiled baseline and matched control on both runtimes;
  distinguish allocator churn from any remaining algorithmic or teardown stall.
  Reproduce the original tool-resources case at 16-way load as well.
- [ ] Extend the existing pure runtime policy in tests/helpers/jit_tuning.lua:
  on arm64 macOS LuaJIT builds older than the known allocator repair, run the
  compatibility harness in interpreter mode; repaired builds retain the existing
  large-mcode tuning, other platforms retain their current behavior. Apply this
  once through the existing minimal_init entry point, before specs load. Do not
  change production startup, choose another Neovim API version, disable a case,
  shrink a corpus, relax a work bound, or raise a deadline.
- [ ] Add policy matrix and actual-child startup regressions, including threshold
  versions and non-arm64/non-macOS cases. Verify the original pump call-count
  oracle still rejects superlinear work. Its existing jit.status restore already
  preserves an interpreter-only entry state. Keep profiling independent of the
  policy so JITSTAT remains an observation, not a mitigation.
- [ ] Repeat the implicated corpus (fold-batches, dependency navigation, fold
  retirement/uncertainty, typing/ownership and original tool-resources) on both
  versions, then require original tool-resources 64/64 at sixteen-way load and
  fold-batches stress on both versions. Run the complete recorded suite with
  the installed-version compatibility pass, review, and land.
- [ ] Update the harness atlas with the runtime envelope and the reason the
  compatibility pass does not exercise an allocator known to livelock.

Design constraints / alternatives:

ARCH-DRY/PURE: the existing version threshold and apply function own the policy;
no second runtime detector or per-spec workaround. ARCH-PURPOSE: sweep the whole
load-sensitive corpus, preserve structural work oracles, and keep actual Neovim
0.11 API coverage. A runtime-policy fake records JIT settings/enabled state while
real-child tests check the integration (ARCH-MOCK). ARCH-CONSTRAINTS: this is
batch-only harness initialization, O(1) in corpus size, with no new keystroke,
save or production process cost. Corpus growth is still defended by counted
work, independent of JIT speed. No pending state, recovery menu or durable
runtime artifact is introduced: each process chooses its policy once and ends
with its existing supervisor (ARCH-STATE/ARCH-FUNERAL). Test outcomes remain
pass/fail/stalled with the same existing action and deadlines.

The alternatives are rebuilding and distributing 0.11 against repaired LuaJIT
(which would stop testing the operator's installed binary), or a dynamic
trace-abort fallback (extra per-trace state and callback ordering). Prefer the
small explicit runtime policy if the matched controls confirm the mechanism.
This is a proposal, not permission to hide an unexplained residual stall.


### 2026-10-17 — TL approval extends the allocator safeguard to the editor

The TL approved the plan and required the real editor to use the same unsafe-
allocator rule. Inspection finds no production JIT safeguard: only the harness
has jit_tuning today. Promote that policy into lua/parley/jit_tuning.lua and
call protect() at the beginning of parley initialization, before its other
imports, plus from the harness apply(). Production protect() disables only
old/unknown arm64 OSX JIT allocators; harness apply() additionally retains its
existing options on repaired builds. This avoids adding unrelated large-mcode
settings to the editor while keeping the allocator safety rule single-sourced
(ARCH-DRY). Update script runtime detection and all existing consumers; remove
the test-only owner. A build without JIT is a no-op.

The VM-wide JIT state is a startup decision, not an asynchronous lifecycle.
Unsafe allocator => interpreter, editor/test operation continues; repaired or
other platform => preserve the operator's enabled state. The operator action
remains ordinary editing; no retry or recovery menu. Disabling the VM affects
all Lua in that editor, so the unchanged complexity and timing regressions,
and installed-version suite, must verify the cost. No global jit.on is added.
The deliberate active-JIT reclamation child keeps JIT enabled to preserve its
oracle; watch it separately. Existing tool_resources restores only its entry
jit.status(), so it already preserves interpreter startup.

Baseline completed: unprofiled 0.11 fold-batches 64/64 passes at sixteen-way
load, 37.07–185.65 s. The exact failed-suite deadline event remains unreproduced;
the compiler/allocator churn and multi-minute no-case-progress interval are
reproduced. Do not describe those green samples as timeout failures.


### 2026-10-17 — preserve the operator VM's global JIT state

TL correction supersedes the preceding production protect() proposal: never
call global jit.off() from Parley. Production opt-in uses
jit.off(module_chunk, true), before nested functions execute. The shared helper
accepts the caller's own chunk explicitly. No package loader/searcher patch,
global require wrapper, or traversal into foreign plugin functions.

Enumerate the measured pipeline: document/*.lua (including lazily loaded
semantic/facts modules), line_reader, tool_folds, fold_native, fold_projection,
fold_diff, fence, and tools/resources. These module chunks opt in at their
start. The helper shares the version predicate with the harness, whose
apply() may still disable its test VM globally. Fixed builds and other
platforms keep their existing compilation behavior.

Prove the scope with a fresh global-JIT-enabled child: the protected chunk's
nested functions do not compile, an unrelated hot function still compiles,
and jit.status() remains enabled. Stress D.drain with JIT globally enabled,
measure mcode aborts/flushes, and compare the full fifth-case corpus. If scoped
protection fails to remove the abort storm, stop and report to the TL for an
operator decision; do not broaden to a global production setting. Explicit
active-JIT storage tests keep their compilation oracle, including any necessary
fixture-local exemption confined to that independent child.


Implementation boundary refinement: keep global VM effects in the existing
**test-only** jit_tuning adapter; the production module exports only the pure
version predicate and chunk-scoped protection. It has no global-off entry
point. The helper's caller requires a non-nil function before any effect, so a
bad chunk cannot accidentally become a global jit.off call. One shared version
rule still serves script selection, harness behavior and scoped editor guards.

Scoped control: 0.11 16/16 passes in 58.74–62.33 s with global_jit=true,
mcode_aborts=0, flushes=0 after the heavy drain; fixed 0.12 control 16/16 in
32.40–37.68 s. The first disposable-copy control incorrectly inherited the
50 s generic budget instead of this corpus's 180 s path-specific budget;
its 16 deadline exits are diagnostic setup errors, not a production failure
or accepted evidence. Repeated with the original corpus budget, all passed.
No shipped deadline was changed. Independent active-JIT storage oracle first
failed its new compiled-sequence assertion as expected under protection;
the intentionally unprotected child then passed 36/36 sequence cases on 0.11.


### 2026-10-17 — pre-suite validation

- Red/green: five new policy cases failed against the previous helper; scoped
  real-VM regression observed 155403 document trace starts before chunk guards
  and zero after. Nil chunk refused before any global JIT effect (red/green).
- Real fresh-child scope regression passes on 0.11 and 0.12: global enabled,
  completed unrelated-plugin trace, zero protected document trace starts,
  successful drain. Active-JIT storage child now explicitly asserts completed
  sequence traces; observed the assertion fail under protection, then pass with
  its fixture-only opt-out.
- Fifteen targeted spec files pass on each runtime (30/30): policy, sequence,
  resource admission, dependencies, fold batches/retirement/uncertainty,
  ownership/document/chat typing/highlight performance, and tight reference,
  move-plan, collaboration/value parser CPU bounds. No sentinel hits.
- Original tool_resources stress: 64/64 at sixteen-way concurrency on each
  runtime (128/128 runs). A disposable superlinear pump mutation (queue pairs
  x both claim widths) fails specifically at the unchanged bounded call budget;
  no assertion or workload was relaxed.
- make lint: 0 warnings / 0 errors across 788 files; git diff --check clean.
- Next: full stock-0.11 suite and recorded default-0.12 suite on the pushed
  implementation head, then the binary's close review and landing.


The fresh-child foreign-trace observer also clears its identity on abort/flush
and replaces it at every new trace start, so reuse of an aborted trace ID
cannot count another function as the unrelated compiled function. The queued
recorded run was cancelled through local-check cancel before it took a suite
slot and is restarted on this final test observer. The manual 0.11 suite is
still queued and will read the same final checkout when admitted.


Done-when clarification records the approved scope and measured runtime
contract explicitly alongside the original two oracles; no original acceptance
condition was removed. Full suite code head is b8b171a9. Both complete suites
are queued behind the machine-wide budget; no test deadline was adjusted.
