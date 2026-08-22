---
id: 000202
status: working
deps: []
github_issue:
created: 2026-08-20
updated: 2026-08-21
estimate_hours: 1.64
started: 2026-08-21T22:47:58-07:00
---

# make test is unreliable: specs traverse and mutate a shared .test-tmp

## Problem

`make test` fails intermittently on specs that have nothing to do with the
change under test, which makes every SDLC close gate noisier than it should be
and trains agents to dismiss real failures as flakes. Diagnosed during #200,
where it cost two false alarms before being investigated.

Two distinct mechanisms, both rooted in the harness sharing one scratch tree:

1. **`tests/unit/tools_builtin_find_spec.lua` traverses a directory the suite is
   writing.** `Makefile.parley:28` sets `TMPDIR=$(CURDIR)/.test-tmp`, and the
   spec runs the `find` tool over the repo root — which contains `.test-tmp`,
   populated by previous runs and actively mutated by the current one. `find`
   exits nonzero when the tree changes under its traversal, and the spec asserts
   `is_error == false`.

   Evidence: the spec passes 4/4 in isolation (repeatedly), passes under the
   suite's own `TEST_ENV`, and fails under the full suite. It reproduces with all
   #200 changes stashed, so it is not fold-related. `rm -rf .test-tmp .test-home
   .test-xdg` before `make test` gives exit 0.

2. **`tests/integration/chat_progress_process_spec.lua` intermittently gets no
   port.** It binds a local HTTP server; under full-suite contention the bind
   sometimes fails and the spec errors with `attempt to concatenate local 'port'
   (a nil value)`. Passes 7/7 in isolation.

Separately, under the agent sandbox `git_markdown_source_spec` and
`markdown_finder_async_spec` fail because `git init` cannot copy its template
hooks into the sandbox-redirected `TMPDIR`. That one is environmental rather
than a harness defect, but it compounds the same "is this real?" problem.

## Spec

- `make test` is deterministic from a dirty working tree: two consecutive runs
  with no source change produce the same result.
- No spec's assertions depend on the contents of a directory another spec may be
  writing during the same run.
- If a scratch dir must be shared, the harness cleans it before the run rather
  than leaving each spec to cope.

## Done when

- [x] The harness scratch trees (`TMPDIR`, `HOME`, `XDG_*`, nvim swap) live
      outside `$(CURDIR)`, so the repo tree is not written during a run.
- [x] A full `make test` mutates nothing inside the repo working tree
      (mtime/`git status` snapshot before vs after is identical).
- [x] The fake SSE server publishes its port atomically: the ready file is
      never observable in an incomplete state.
- [x] `start_server` waits for a *parseable* port and fails by name; a
      deterministic test drives the readiness predicate against an
      incomplete/absent/garbage signal, with no race to win.
- [x] `make test` cleans the scratch root before the run.
- [x] Ten consecutive `make test` runs on an unchanged tree all agree.

## Estimate

```estimate
model: estimate-logic-v3.1
familiarity: 1.0
item: cross-cutting-refactor  design=0.10 impl=0.23
item: lua-neovim              design=0.20 impl=0.36
item: atlas-docs              design=0.10 impl=0.06
item: milestone-review        design=0.00 impl=0.14
item: scope-pivot             design=0.25 impl=0.10
design-buffer: 0.15
total: 1.64
```

*Produced via `brain/data/life/42shots/velocity/estimate-logic-v3.1.md` against
`baseline-v3.1.md`. Method A only.* (`design-buffer: 0.15` is a rate, not hours
— the fence's fields do not sum to `total` without applying it.)

Derivation:

- **cross-cutting-refactor** — the scratch-root relocation across
  `Makefile.parley`, `tests/minimal_init.vim`, `.gitignore`, plus the
  determinism soak. v2 design pick 0.5 from the 0.2–1 range, then Step 3 ×0.2:
  the Plan already fixes the variable derivation, the collision key, the
  ordering of the wipe, and the legacy-dir retirement, so design here is
  reading, not deciding → 0.10. Impl is two parts: v2 pick 0.4 from 0.2–0.5
  ×0.40 per v3.1 → 0.16 for the edits, **plus 0.07 entered unscaled** for the
  ten-run soak and the before/after tree diff → 0.23. The soak is fixed
  wall-clock, not AI-paired typing, so v3.1's ×0.40 does not apply to it; it is
  priced from measurement, not from the table — a baseline `make test` on this
  tree ran **24.955s** (`make test  17.60s user 10.12s system 111% cpu 24.955
  total`), so ten runs ≈ 4.2 min ≈ 0.07h. The slug is an acknowledged proxy:
  v2's Known-limitations section says outright that tooling/make/shell
  automation has no primitive, and a `make -j` ordering bug is a different
  failure shape than a rename.
- **lua-neovim** — `tests/helpers/ready_port.lua`, `tests/unit/ready_port_spec.lua`
  with three deterministic cases, the `start_server` rewiring, and the fixture's
  `os.replace` publish: four artifacts across two languages. v2 design pick 1.0
  (low end of 1–3: one small seam with a signature already stated), ×0.2 → 0.20.
  v2 impl pick 0.9 — the midpoint of 0.5–1.5, not the low end, because case (b)
  has to construct an empty-then-written file race-free from inside headless
  nvim — ×0.40 → 0.36.
- **atlas-docs** — TOOLING.md's documented scratch paths plus the atlas entry.
  Design 0.10 undiscounted (nothing pre-resolves the wording); impl pick 0.15
  ×0.40 → 0.06.
- **milestone-review** — the one mandatory close review. Design 0.0; impl pick
  0.35 from 0.2–0.5, ×0.40 → 0.14.
- **scope-pivot** — the round-1 plan-quality gate and the `## Revisions` rewrite
  that moved the fix from the traversers to the churner and withdrew the arch
  fitness function. This is elapsed time inside the `sdlc actual` window
  (`started: 22:47:58`; round 1 at 22:54:56; round 2 after), so it is priced,
  not absorbed. v2 design pick 0.25 from 0.2–0.5, undiscounted — the revision
  *was* the design decision, so no spec-quality credit applies. v2 impl pick
  0.25 ×0.40 → 0.10.
- **Step 2.5 (library availability)** — n/a: no greenfield module and no novel
  stack. `os.replace` is stdlib and already the intended primitive.
- **Step 5 familiarity ×1.0** — familiar territory; both mechanisms were
  reproduced from first principles before the estimate was derived.
- **Step 6 buffer +15%** — the ×0.2 spec-quality discount was applied to the two
  primary primitives, so the v2.1 rule of thumb halves the buffer rather than
  double-counting plan thoroughness.

Recompute: (0.10+0.20+0.10+0.00+0.25) × 1.15 + (0.23+0.36+0.06+0.14+0.10) × 1.0
= 0.65 × 1.15 + 0.89 = 0.7475 + 0.89 = **1.64**

## Non-goals

- **Rewriting the `find`/`grep`/`ack` tool specs to use fixture trees.** They
  exercise the tools against the real repo tree on purpose, and one of them
  (`tools_builtin_grep_spec.lua`'s "defaults missing path to cwd") *cannot* be
  written any other way — its subject is the cwd default. Moving the scratch
  trees out makes repo traversal safe for all of them at once, which is why
  the traversal roots are left alone.
- **An arch fitness function banning repo-root traversal in specs.** It was in
  the first draft and is withdrawn: it would have failed the three legitimate
  specs above, and `arch_helper.assert_pattern_scoping` is a line-wise text
  grep that cannot see the case with no `path` key at all. The invariant is
  enforced by placement, not by a lint.
- **Test parallelism.** `JOBS=8` stays; the point is to make eight concurrent
  jobs safe, not to serialize them.
- **The sandbox `git init` failure as a harness change.** It is environmental
  (Log 4). It is expected to disappear as a side effect of the move, since
  `git init` succeeds under the real `$TMPDIR`; that is checked, not designed
  for.

## Plan

- [x] Reproduce each mechanism with a minimal case (Log 2026-08-21)
- [x] Move the scratch root out of the repo: `Makefile.parley` derives
      `TEST_ENV_ROOT` from the real `TMPDIR` (fallback `/tmp`), keyed by the
      checkout so worktrees cannot collide; `TEST_HOME`/`TEST_XDG`/`TEST_TMP`
      hang off it. Point `tests/minimal_init.vim`'s `directory` at `$TMPDIR`
      instead of `.test-tmp//`.
- [x] Retire the in-repo dirs: `test-clean-env` removes both the new root and
      the legacy `.test-*` dirs, so the migration completes itself for anyone
      who pulls; keep the `.gitignore` entries as a safety net for stale trees.
- [x] Have `make test` run `test-clean-env` first, ordered explicitly (recursive
      `$(MAKE)` calls, not prerequisites) so `make -j` cannot reorder the wipe
      into the middle of a run.
- [x] Publish the fake SSE server's port atomically: write to a sibling temp
      file, `os.replace` it onto the ready path.
- [x] Extract the readiness wait into `tests/helpers/ready_port.lua`
      (`wait_for_port(path, timeout_ms) -> port, err`) and have
      `chat_progress_process_spec.start_server` use it, so a missing or
      incomplete signal fails by name instead of nil-concatenating.
- [x] Unit-test that predicate deterministically in
      `tests/unit/ready_port_spec.lua`: (a) path never appears -> nil + a
      "timed out" error; (b) file created empty, digits written later ->
      returns the port, never a partial read; (c) non-numeric content -> nil +
      a named error. No race to win in any case.
- [x] Prove the repo tree is untouched: snapshot it before and after a full
      `make test` and diff.
- [x] Run the suite ten times to confirm determinism

## Revisions

### 2026-08-21 — adopt the placement fix, drop the fitness function

Reason: the round-1 plan-quality gate (PQ-1, PQ-5) showed the first draft was
treating a symptom. It scoped only `tools_builtin_find_spec`'s traversal, while
`tools_builtin_grep_spec` and `tools_builtin_ack_spec` have the same shape —
and the arch rule meant to defend the fix would have failed all three plus a
spec whose whole subject is the cwd default.

Delta: the fix moves from the *traversers* to the *churner*. The harness
scratch trees leave `$(CURDIR)`, which closes mechanism 1 for every present and
future spec at one site instead of per-spec forever, and incidentally clears the
Log-4 sandbox `git init` failure. The per-spec scoping and the arch fitness
function are both dropped (see Non-goals). Mechanism 2's fix is unchanged in
substance but gains a deterministic test for its readiness predicate (PQ-4), and
Done-when item 2 is restated to match the Log's refutation of the bind-retry
theory (PQ-3).

## Log

### 2026-08-20

Filed from #200's M1 boundary review, which noted the diagnosis would otherwise
be archived with that issue and lost. Full evidence in #200's `## Log` entries
for rounds 6 and 8.

### 2026-08-21

Reproduced both mechanisms; **mechanism 2's stated cause was wrong** and is
corrected here rather than in `## Problem` above (which records the original
#200 diagnosis as filed).

1. **`find` traversal race — confirmed as filed.** Churning
   `.test-tmp/churn/dN` (mkdir/touch/rm in a loop) while running
   `find . -name '$(echo PARLEY_SENTINEL_144)'` from the repo root reproduces
   on the first attempt: `error: ./.test-tmp/churn/d57: No such file or
   directory`, exit 1. Four subsequent runs exited 0 — matching the observed
   intermittency. Only the `command substitution text in name` case is exposed;
   the two rejection cases return before `vim.fn.system` runs.

2. **Port race is a readiness-signal race, NOT a bind failure.**
   `tests/fixtures/fake_sse_server` binds port 0 in the `Server(...)`
   constructor, so the bind has already succeeded before any readiness is
   published — it cannot be the failing step. The real window is inside
   `open(READY_FILE, "w")`: the file is created (and therefore
   `filereadable() == 1`) while still zero bytes, because the port digits are
   only flushed at context exit. Probe: spawn the fixture's write pattern, spin
   until the path is readable, stat it — `first-readable size: 0`, `final size:
   5`. `vim.fn.readfile()[1]` on the empty file is nil, `tonumber(nil)` is nil,
   and the next line concatenates it — exactly the reported `attempt to
   concatenate local 'port' (a nil value)`. Under eight parallel jobs a
   scheduler preemption inside that window is ordinary.

   Consequence for the fix: bounding or retrying the *bind* would have changed
   nothing. The fix is to make the readiness publish atomic.

3. **The scratch-dir clean is hygiene, not a fix for mechanism 1.** The tree is
   mutated *during* the run by the eight parallel jobs, so a pre-run clean only
   shrinks the window. Mechanism 1 is closed by scoping the traversal; the
   clean is kept because the Spec asks the harness to own scratch state rather
   than leaving each spec to cope.

4. **The `git init` sandbox failure is confirmed environmental.**
   `git -C /tmp/... init -q` exits 0; `git -C $REPO/.test-tmp/probe init -q`
   exits 128 with `cannot copy '.../templates/hooks/commit-msg.sample' ...
   Operation not permitted` — the agent sandbox denies the template copy into
   the repo tree. Not a harness defect and out of scope here; verification runs
   for this issue are executed outside the sandbox.

### 2026-08-21 (implementation)

Shipped the placement fix from the revised plan. What landed:

- `Makefile.parley` derives `TEST_ENV_ROOT` from the real `TMPDIR` (fallback
  `/tmp`), keyed by `<checkout-name>-<cksum of $(CURDIR)>` so worktrees cannot
  share a root; `TEST_HOME`/`TEST_XDG`/`TEST_TMP` hang off it. `cksum` over
  `shasum`/`sha256sum` for POSIX portability. `test` now chains
  `test-clean-env → lint → test-unit → test-integration` through recursive
  `$(MAKE)` rather than prerequisites, because prerequisite order only holds
  under serial make and `make -j test` could otherwise schedule the wipe into a
  running suite. `test-clean-env` removes the new root *and* the legacy in-repo
  `.test-*` dirs, so the migration completes itself on a dirty checkout.
- `tests/minimal_init.vim` points `directory` (swap) at `$TMPDIR` instead of
  `.test-tmp//`.
- `tests/fixtures/fake_sse_server` publishes its port through
  `open(staging) → flush → fsync → os.replace(staging, READY_FILE)`.
- `tests/helpers/ready_port.lua` waits for a *parseable* port and distinguishes
  "never appeared" from "appeared but never published a port";
  `chat_progress_process_spec.start_server` uses it and asserts with the error
  text, so a failure names itself instead of nil-concatenating.
- `tests/unit/ready_port_spec.lua` — six cases, all constructed rather than
  raced: absent path, zero-byte file, empty-then-filled, trailing newline,
  non-numeric, out-of-range. 6/6 pass.

Evidence:

- **Repo tree untouched by a run.** `find . -path ./.git -prune -o -print` with
  `stat` mtime+size, snapshotted before and after a full `make test`:
  **IDENTICAL, 1065 entries compared.** This is the invariant the whole fix
  rests on, and it is now directly checkable rather than inferred.
- **Ten consecutive `make test` runs: all exit 0.** Stronger than the exit
  codes — all ten produced the *same 184-spec PASS set*, byte-identical after
  sort.
- **The two previously-failing specs pass.** `git_markdown_source_spec` and
  `markdown_finder_async_spec` failed on `main` under the agent sandbox
  (`git init` exit 128, template-hook copy denied) and now pass, because the
  scratch root moved to `$TMPDIR`, where `git init` is permitted. Log 4
  predicted this as a side effect; confirmed, not designed for.
- Baseline for comparison: `make test` on `main` before the change failed with
  those two specs (exit 2).

Atlas: new `atlas/infra/test_harness.md` (harness shape + the scratch-placement
invariant + the two fixture-readiness rules), linked from `atlas/index.md` §7,
with an `infra/test_harness` traceability entry verified through
`scripts/spec_test_map.sh list-tests`.

Note on the estimate: the estimate-quality judge's F1 priced the ten-run soak at
0.33–0.67h from an untimed guess of 2–4 min/run. Measured, a full `make test` on
this tree is ~25s, so the soak is ~0.07h — that correction (with the measurement)
and F2's unpriced gate-round time are both folded into the revised block, which
went 1.06 → 1.64.

### 2026-08-21 (close review round 1 — 4 blocking, all fixed)

- **BR-1 (real bug I introduced).** `test-clean-env`'s `rm -rf` quoted
  `"$(TEST_ENV_ROOT)"` but not `$(LEGACY_TEST_DIRS)`, so a checkout under a path
  with a space would word-split into `rm -rf '<parent>/my'`. This target now runs
  first in *every* `make test`, so the blast radius was real. Each legacy path is
  quoted individually; verified by copying the makefile under a directory named
  `space test` and reading the expansion — all four paths come out as single
  quoted words.
- **BR-2.** The invariant the whole issue rests on had no guard: moving
  `TEST_ENV_ROOT` back inside `$(CURDIR)` would just resume flaking. The Non-goals
  rejection of a lint stands — but it was aimed at *spec traversal roots*, and a
  guard on the **writer** has no false-positive problem. Added
  `tests/arch/scratch_placement_spec.lua`: `vim.fn.tempname()`, `'directory'`,
  `$HOME`, `$XDG_*` must all resolve outside `getcwd()`. Proven both ways — 6/6
  green today, 6/6 red when run with the scratch pointed back into the repo.
- **BR-3.** Done-when claimed atomic publishing, but reverting `publish_ready`
  left the suite green because the consumer guard absorbed it. Rather than
  spin-stat and hope to win a microsecond window, the fixture takes a
  `PARLEY_PUBLISH_DELAY` hook that holds the window open, and
  `tests/integration/fixture_ready_publish_spec.lua` asserts the ready path is
  never observable incomplete **and** that the delay was honored — so the hook
  cannot be deleted to make the spec pass. Proven against both revert shapes:
  in-place write with the hook kept → 300+ observations of `size=0 content=""`;
  `publish_ready` deleted entirely → "was not honored".
- **BR-4.** `tests/perf/chat_typing.lua` still hardcoded
  `.test-tmp/perf/parley-chat-typing.json` as its fallback — the one surviving
  consumer not deriving from the relocated source, and it would have written
  into the repo tree whenever `start()` ran without `PERF_OUTPUT`. Now derived
  from `vim.env.TMPDIR`.
- Minors: TOOLING's "see below" pointer corrected (the section is above) and the
  scratch wipe's effect on a default-path perf report noted; `TEST_ENV_KEY`
  hoisted to `:=` so `cksum` forks once per make invocation instead of once per
  expansion; the duplicated rationale in `minimal_init.vim` and `Makefile.parley`
  reduced to pointers at the atlas entry; atlas now records that nvim's tempdir
  fallback chain ends at cwd, which is why the guard asserts produced paths
  rather than env vars.

Re-verified after the fixes: `make test` green at **186 specs**; ten consecutive
runs all exit 0 with the **same 186-spec PASS set**; repo working tree
**IDENTICAL** across all ten (1070 entries compared).
