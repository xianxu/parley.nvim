# Boundary Review — parley.nvim#202 (whole-issue close)

| field | value |
|-------|-------|
| issue | 202 — make test is unreliable: specs traverse and mutate a shared .test-tmp |
| repo | parley.nvim |
| issue file | workshop/issues/000202-make-test-is-unreliable-specs-traverse-and-mutate-a-shared-test-tmp.md |
| boundary | whole-issue close |
| milestone | — |
| window | 8bb4d2c17bcae1f11058d9c1e8f11b871d0b1579..920a9fd8399e2647fc95b5dbd9e8471575b47e16 |
| command | sdlc close --issue 202 |
| reviewer | claude |
| timestamp | 2026-08-21T23:23:29-07:00 |
| verdict | FIX-THEN-SHIP |

## Review

I verified the work by running it, not by reading the commit message. Here's the review.

```verdict
verdict: FIX-THEN-SHIP
confidence: high
```

The redesign is the right one: the fix moved from N readers (the `find`/`grep`/`ack` traversers) to the single writer (the harness scratch root), which closes mechanism 1 for every present and future spec at one site, and the withdrawn arch fitness function is correctly justified in Non-goals. I independently confirmed the headline claims — `make test` exits 0 with 184 PASS/0 FAIL in 25s, and a `find`+`stat` snapshot of the working tree (1067 entries, mtime+size) is **byte-identical before and after a full run** — and I mutation-tested the readiness guard: deleting the empty-content check in `read_signal` turns 2 of the 6 new unit cases red, so that fix is genuinely pinned by a test rather than asserted by one. What holds SHIP back is a `rm -rf` in `test-clean-env` that word-splits on unquoted paths (reproduced: on a checkout path containing a space it targets a truncated path *outside* the repo), plus three gaps around what is and isn't pinned — the placement invariant that the whole issue rests on has no regression guard, the atomic-publish half of mechanism 2's fix has no test at all, and one consumer still hand-restates the pre-#202 scratch path.

## 1. Strengths

- **Root-cause relocation over per-spec patching** (`Makefile.parley:26-40`). The `## Revisions` entry names the pivot, the rejected alternatives land in Non-goals, and the reasoning that a lint would have failed three legitimate specs (including one whose subject *is* the cwd default) is correct — I confirmed `tools_builtin_grep_spec`/`ack_spec`/`find_spec` are untouched by the diff.
- **The determinism invariant is now directly checkable, and it checks out.** Verified independently, not taken from the Log.
- **The readiness tests are constructed, not raced** (`tests/unit/ready_port_spec.lua`). Six cases, all deterministic; mutation-verified as load-bearing. The `saw_path` distinction between "never appeared" and "appeared but never published a port" (`tests/helpers/ready_port.lua:53-57`) is what turns the old nil-concat crash into a named failure — and I confirmed luassert does surface the second argument, so `assert.is_not_nil(port, err)` at `chat_progress_process_spec.lua:50` really does print the reason.
- **The recursive-`$(MAKE)` ordering rationale is correct and non-obvious** (`Makefile.parley:51-60`): prerequisite order genuinely is not guaranteed under `-j`, and the previous form could have scheduled the wipe alongside a running suite.
- **Docs gate satisfied properly**: atlas entry + index link + traceability, and `scripts/spec_test_map.sh list-tests infra/test_harness` resolves both listed specs. README needs no change (it documents no test commands).

## 2. Critical findings

None.

## 3. Important findings

**(a) `Makefile.parley:223` — `rm -rf` word-splits on unquoted `$(LEGACY_TEST_DIRS)`.**
`@rm -rf "$(TEST_ENV_ROOT)" $(LEGACY_TEST_DIRS)` quotes the root but not the legacy list. Reproduced with a copy of the makefile in a directory named `space test`:

```
rm -rf ".../space test-4031105546" /private/tmp/.../parley-review/space test/.test-home ...
```

On a checkout at e.g. `~/my code/parley.nvim`, that expands to `rm -rf ~/my` plus relative paths — an unrecoverable delete outside the repo, in the target that now runs **first in every `make test`**. The previous version quoted all three paths, so this is new. Fix: `@rm -rf "$(TEST_ENV_ROOT)" "$(CURDIR)/.test-home" "$(CURDIR)/.test-xdg" "$(CURDIR)/.test-tmp"`. Narrow trigger, four-character fix — treat as blocking if any checkout path could contain whitespace.

**(b) The placement invariant has no regression guard.** Everything in this issue rests on `TEST_ENV_ROOT` being outside `$(CURDIR)`, and nothing goes red if someone repoints it back — the suite would simply resume flaking intermittently, which is the exact failure mode #202 exists to end. Non-goals correctly rejects a lint over *traversal roots* (false-positives on legitimate specs); it does not rule out a guard on the *writer*, which has no such problem:

```lua
-- tests/arch/scratch_placement_spec.lua
local cwd = vim.fn.getcwd()
local tmp = vim.fn.fnamemodify(vim.fn.tempname(), ":h:h")
assert.is_nil(tmp:find(cwd, 1, true), "harness TMPDIR must be outside the repo tree (#202): " .. tmp)
assert.is_nil(vim.o.directory:find(cwd, 1, true), "swap dir must be outside the repo tree (#202)")
```

Green today, red the moment the invariant regresses, and it inspects the churner rather than the traversers — consistent with the lesson the issue itself records (ARCH-PURPOSE).

**(c) `tests/fixtures/fake_sse_server:57` — the atomic-publish half of the fix is unpinned.** Done-when item 3 claims "the ready file is never observable in an incomplete state," but no test fails without `publish_ready`; the consumer guard would keep the suite green if the `os.replace` were reverted tomorrow. Log entry 2 already demonstrates the probe that catches it deterministically in the negative direction: spawn the fixture, spin on `stat` of the ready path, fail if it is ever observed zero-length. That reproduced the old bug on the first attempt and cannot false-positive against the fixed publisher.

**(d) `tests/perf/chat_typing.lua:352` — a consumer still hand-restates the pre-#202 scratch path.** `opts.output or os.getenv("PERF_OUTPUT") or ".test-tmp/perf/parley-chat-typing.json"` writes **into the repo tree** when the harness is invoked directly (only `make perf` sets `PERF_OUTPUT`). `TOOLING.md:47` now states the report goes to `$(TEST_TMP)/perf/...`, which is true only via `make`. This is the one surviving restatement in the shadow-sweep of scratch-location consumers (ARCH-PURPOSE / ARCH-DRY); derive it instead: `(vim.env.TMPDIR or "/tmp") .. "/parley-perf/parley-chat-typing.json"`.

## 4. Minor findings

- `TOOLING.md:47-48` — "see *Test scratch directories* below" points at a section that is **above** (line 13 vs 38).
- `Makefile.parley:37` — `TEST_ENV_ROOT ?=` is recursively expanded, so `printf | cksum | cut` forks on every expansion of `TEST_ENV`/`TEST_TMP`/`TEST_HOME` (several per make invocation). Hoist the key: `TEST_ENV_KEY := $(shell ...)` and reference it in the `?=`.
- The same ~8-line rationale paragraph is restated in four places (`Makefile.parley:26-35`, `tests/minimal_init.vim:19-22`, `TOOLING.md:25-33`, `atlas/infra/test_harness.md:27-36`) — four maintenance points for one fact (ARCH-DRY, prose). The code comments could point at the atlas entry.
- Worth one line in `atlas/infra/test_harness.md`: nvim's tempdir fallback chain ends at **cwd**. I hit it during review — with `$TMPDIR` set but unwritable, `vim.fn.tempname()` returned `/Users/xianxu/workspace/parley.nvim/nvim.xianxu/…`, i.e. scratch back in the repo. `PREP_TEST_ENV`'s `mkdir -p` aborts the run first under `make`, so the invariant holds there, but it depends on that mkdir failing loudly.
- `make test` now wipes `$(TEST_ENV_ROOT)` first, which destroys the documented default `PERF_OUTPUT` location; TOOLING.md doesn't mention it.
- Pre-existing, not from this diff: the repo root contains a stray directory literally named `.test-home XDG_DATA_HOME=` (from a past mis-quoted invocation). It is untracked, *not* gitignored, and invisible to `git status` only because it holds no files. The migration sweep in `test-clean-env` is the natural place to retire it.

## 5. Test coverage notes

- Consumer-side fix: **verified load-bearing by mutation.** Removing the `if content == "" then return nil, true end` guard turns "does not accept a zero-byte file" and "returns the port when digits land after the file is created empty" red (4 pass / 2 fail).
- Publisher-side fix: **no test** — see 3(c).
- Placement fix: **no test** — see 3(b).
- `tests/unit/ready_port_spec.lua` does real filesystem IO and uses `vim.wait`/`vim.defer_fn` in a directory TOOLING.md describes as "pure logic, no Neovim APIs". 44 of 134 existing unit specs already do the same, so this is convention drift, not a new violation — not raised as a finding.
- ARCH-PURE (pass, with a nudge): `wait_for_port` fuses the pure predicate (is this string a TCP port?) with the polling IO. Four of the six cases — newline, garbage, out-of-range, empty — are pure string cases forced through the filesystem. Splitting `M.parse_port(content) -> port, err` out would let those four run with no IO and leave one genuinely time-dependent case.
- ARCH-MOCK (pass): the SSE fake sits behind the same HTTP boundary production uses; no new out-of-seam external calls. The Makefile's `cksum`/`cut` are build-time.

## 6. Architectural notes for upcoming work

- `tests/integration/openai_tool_loop_spec.lua:27` uses the *other* port-discovery pattern — `free_port()` binds, reads the port, closes, and hands the number to a fixture that binds it later. That's a TOCTOU window of the same family this issue just closed on the ready-file channel, and the atlas's "Fixture readiness" rules don't cover it. Worth a follow-up issue rather than scope creep here.
- The scratch root is keyed per checkout but not per *run*, so two concurrent `make test` invocations in the same checkout still share it (and the new pre-run wipe makes that sharper). Pre-existing shape; only matters if CI ever runs two suites against one working copy.

## 7. Plan revision recommendations

The plan matches the code — every `## Plan` item is delivered at the stated location, and the single-pass no-`Mx` shape is right. One conditional entry:

- If 3(c) is not addressed, add a `## Revisions` note stating that Done-when item 3 (atomic publish) is verified by inspection only, and that the observable-incomplete-state property is defended in practice by the consumer-side `wait_for_port` guard — so the claim is not read as test-backed.

```findings
findings:
  - id: new
    severity: Important
    family: unquoted-path-expansion
    title: |
      test-clean-env rm -rf word-splits on unquoted LEGACY_TEST_DIRS, targeting paths outside the repo
    detail: |
      Makefile.parley:223 quotes "$(TEST_ENV_ROOT)" but not $(LEGACY_TEST_DIRS). Reproduced with a copy of
      the makefile under a directory named 'space test': the recipe expands to rm -rf on
      '<parent>/space' plus relative 'test/.test-home' words. On a checkout at '~/my code/parley.nvim'
      this deletes '~/my'. The pre-diff version quoted all three paths, and this target now runs first in
      every make test. Fix by quoting each: "$(CURDIR)/.test-home" "$(CURDIR)/.test-xdg" "$(CURDIR)/.test-tmp".
  - id: new
    severity: Important
    family: invariant-without-regression-guard
    title: |
      The scratch-placement invariant the whole issue rests on can be reverted with nothing going red
    detail: |
      Nothing fails if TEST_ENV_ROOT moves back inside $(CURDIR) (Makefile.parley:37) or if
      tests/minimal_init.vim:24 repoints directory into the tree; the suite would just resume flaking.
      Non-goals correctly rejects a lint over spec traversal roots, but a guard on the writer has no
      false-positive problem: a tests/arch spec asserting vim.fn.tempname() and vim.o.directory are not
      under vim.fn.getcwd() is green today and red on regression (ARCH-PURPOSE).
  - id: new
    severity: Important
    family: claim-without-failing-test
    title: |
      Done-when item 3 claims atomic port publishing, but no test fails without publish_ready
    detail: |
      tests/fixtures/fake_sse_server:57 adds staging-write plus os.replace, and atlas/infra/test_harness.md
      states it as a rule, yet reverting it leaves the suite green because the consumer guard absorbs it.
      Log entry 2 already describes a deterministic probe: spawn the fixture and spin on stat of the ready
      path, failing if it is ever observed zero-length. That reproduced the old bug on the first attempt and
      cannot false-positive against the fixed publisher.
  - id: new
    severity: Important
    family: stale-restatement-of-moved-source
    title: |
      tests/perf/chat_typing.lua still hand-restates the pre-202 in-repo scratch path
    detail: |
      chat_typing.lua:352 falls back to ".test-tmp/perf/parley-chat-typing.json", writing into the repo tree
      whenever start() runs without PERF_OUTPUT (only make perf sets it). TOOLING.md:47 now claims the report
      lands in $(TEST_TMP)/perf/, which is true only via make. This is the one surviving consumer that does
      not derive from the relocated source (ARCH-PURPOSE shadow-sweep, ARCH-DRY); derive it from
      vim.env.TMPDIR instead.
  - id: new
    severity: Minor
    family: stale-restatement-of-moved-source
    title: |
      TOOLING.md perf section says "see Test scratch directories below" but that section is above it
  - id: new
    severity: Minor
    family: makefile-expansion-cost
    title: |
      TEST_ENV_ROOT ?= is recursively expanded, so cksum forks on every expansion of TEST_ENV/TEST_TMP
    detail: |
      Makefile.parley:37. Hoist the key into a := variable (TEST_ENV_KEY := $(shell ...)) and reference it
      from the ?= default, so the subshell runs once per make invocation.
  - id: new
    severity: Minor
    family: rationale-duplicated-across-surfaces
    title: |
      The same scratch-placement rationale paragraph is restated in four files
    detail: |
      Makefile.parley:26-35, tests/minimal_init.vim:19-22, TOOLING.md:25-33 and
      atlas/infra/test_harness.md:27-36 each carry a near-identical version (ARCH-DRY, prose). The two code
      comments could point at the atlas entry instead of restating it.
  - id: new
    severity: Minor
    family: invariant-without-regression-guard
    title: |
      Atlas omits that nvim's tempdir fallback chain ends at cwd, so an unwritable TMPDIR puts scratch back in-tree
    detail: |
      Observed during review: with $TMPDIR set but unwritable, vim.fn.tempname() returned
      /Users/xianxu/workspace/parley.nvim/nvim.xianxu/... . PREP_TEST_ENV's mkdir -p aborts the run first
      under make, so the invariant holds there, but the dependency on that loud failure is worth one line in
      atlas/infra/test_harness.md.
  - id: new
    severity: Minor
    family: stale-restatement-of-moved-source
    title: |
      make test now wipes the documented default PERF_OUTPUT location, which TOOLING.md does not mention
```

---

## Re-review — 2026-08-21T23:50:30-07:00 (FIX-THEN-SHIP)

| field | value |
|-------|-------|
| issue | 202 — make test is unreliable: specs traverse and mutate a shared .test-tmp |
| repo | parley.nvim |
| issue file | workshop/issues/000202-make-test-is-unreliable-specs-traverse-and-mutate-a-shared-test-tmp.md |
| boundary | whole-issue close |
| milestone | — |
| window | 8bb4d2c17bcae1f11058d9c1e8f11b871d0b1579..e1329cd5faa0c3e8379f303472d1620077273023 |
| command | sdlc close --issue 202 |
| reviewer | claude |
| timestamp | 2026-08-21T23:50:30-07:00 |
| verdict | FIX-THEN-SHIP |

## Review

I ran the suite, mutation-tested each claimed fix, and swept the consumers. Here's the review.

```verdict
verdict: FIX-THEN-SHIP
confidence: high
```

All nine round-1 findings are genuinely addressed, and I confirmed the two substantive ones by reverting them in a scratch copy rather than trusting the commit message: `tests/arch/scratch_placement_spec.lua` goes 6/6 green → 6/6 red when `TEST_ENV_ROOT` is moved back under `$(CURDIR)` and `directory` repointed into the tree, and `tests/integration/fixture_ready_publish_spec.lua` goes red against *both* revert shapes of the publisher (non-atomic write with the hook kept → 466 observations of `size=0 content=""`; `publish_ready` deleted entirely → "port appeared after 44ms; PARLEY_PUBLISH_DELAY=300ms was not honored"). Independently: `make test` exits 0 at 186 PASS in 25.4s, and a `find`+`stat` mtime/size snapshot of the working tree (1071 entries) is byte-identical before and after. What holds SHIP back is a second blast-radius defect in the same one-line `test-clean-env` recipe BR-1 came from — `make test TEST_ENV_ROOT=/some/where`, the override TOOLING.md now advertises, `rm -rf`s that directory wholesale on every run.

## 1. Strengths

- **Both halves of the readiness contract are now pinned by tests that fail without the fix.** BR-3's `PARLEY_PUBLISH_DELAY` approach is better than the spin-stat probe I'd have expected: it holds the window open deterministically *and* asserts the delay was honored (`fixture_ready_publish_spec.lua:75-78`), so the hook can't be deleted to make the spec green. I verified that second assertion is what catches the delete-the-whole-function revert. The consumer half is load-bearing too — dropping the `content == ""` guard in `ready_port.lua:33` turns 2 of 6 unit cases red.
- **The placement guard inspects the writer, not the traversers** (`tests/arch/scratch_placement_spec.lua`). Asserting the *produced* paths (`vim.fn.tempname()`, `'directory'`) rather than the env vars is the right call and the atlas explains why (nvim's tempdir fallback chain ends at cwd). Verified red under the revert.
- **The shadow-sweep is clean.** Every live consumer of the scratch location now derives: `PERF_OUTPUT ?= $(TEST_TMP)/...` (Makefile), `directory` from `$TMPDIR` (minimal_init), and `chat_typing.lua:355-358` from `vim.env.TMPDIR` — which I evaluated directly (`TMPDIR=/tmp/claude-501/xyz/` → `/tmp/claude-501/xyz/perf/parley-chat-typing.json`, trailing slash handled). The only surviving `.test-*` strings are the `.gitignore` safety net, the legacy-cleanup list, and historical prose.
- **BR-1's fix verified at the expansion, not the source:** `make -n test-clean-env` emits four separately-quoted words.
- **Docs gate satisfied properly:** atlas entry + `atlas/index.md` link + traceability, and `scripts/spec_test_map.sh list-tests infra/test_harness` resolves all four specs, each of which exists. README correctly untouched (it documents no test commands).

## 2. Critical findings

None.

## 3. Important findings

**`Makefile.parley:224` — the auto-run wipe deletes a caller-supplied root wholesale.**

> **This is the 2nd defect in `test-clean-env`'s `rm -rf` blast radius** (BR-1, `unquoted-path-expansion`, was the first). Per the repeat protocol: do not fix this instance in isolation — state and fix the rule.

`TOOLING.md:22-23` tells the reader to `make test TEST_ENV_ROOT=/some/where`, and `test-clean-env` now runs first in every `make test` with `rm -rf "$(TEST_ENV_ROOT)"`. Command-line overrides propagate to the recursive sub-make. Verified with a probe directory containing `IMPORTANT.txt`:

```
$ make -n test TEST_ENV_ROOT=/tmp/claude-501/rootprobe
make --no-print-directory test-clean-env
rm -rf "/tmp/claude-501/rootprobe" "…/.test-home" "…/.test-xdg" "…/.test-tmp"
```

So `make test TEST_ENV_ROOT=/tmp` erases `/tmp`, and `TEST_ENV_ROOT=$HOME/scratch` erases that. The rule covering both this and BR-1: **`test-clean-env` may only delete paths the harness itself constructs and can name literally — never a caller-supplied path used verbatim, and every path individually quoted.** Concretely, remove the three leaves it creates instead of the root: `@rm -rf "$(TEST_HOME)" "$(TEST_XDG)" "$(TEST_TMP)" $(LEGACY_TEST_DIRS)`. Same effect for the default root (those are the only three children `PREP_TEST_ENV` makes), bounded blast radius under any override, and it makes a future quoting slip non-catastrophic. If wiping the root itself is wanted, always append `$(TEST_ENV_KEY)` to the override so a user-supplied path is treated as a *parent*, and say so in TOOLING.md.

## 4. Minor findings

- **Concurrent `make test` in one checkout is now destructive, not just interfering.** Reproduced: with `make test-unit` running, a second `make test-clean-env` deleted most of the live scratch tree and exited 1 (`rm: …/tmp: Directory not empty`). Run A happened to survive; run B aborted at step 1. Pre-#202 the root was shared but never auto-wiped, so this hazard is new. Loud rather than silent, hence Minor — a per-run suffix or a lock would close it.
- **`fixture_ready_publish_spec.lua:34-40` copy-pastes the env-building + spawn scaffolding from `chat_progress_process_spec.lua:33-38`** (`vim.fn.environ()` fold + `PYTHONDONTWRITEBYTECODE=1` + `uv.spawn` + close-on-exit). `tests/helpers/` now exists and is the obvious home for a `spawn_fixture(mode, ready_file)` (ARCH-DRY).
- Pre-existing, not from this diff: the repo root holds an empty untracked `nvim.xianxu/` directory (mtime 23:40 — the artifact of round 1's unwritable-`$TMPDIR` probe). Invisible to `git status` only because it's empty, and not gitignored. Same class as the `.test-home XDG_DATA_HOME=` stray the last round noted.
- `TOOLING.md:21` — "Print the resolved path with `make -n test-clean-env`" works, but hands the reader an `rm -rf` line to read the path out of. An `@echo $(TEST_ENV_ROOT)` target would be a kinder affordance.

## 5. Test coverage notes

- Mutation-verified load-bearing: the placement guard (6/6 red on revert), the atomic publisher (red on both revert shapes), the consumer empty-file guard (2/6 red on revert). That is the whole of what Done-when items 1, 3 and 4 claim.
- Done-when item 2 (repo tree untouched) independently confirmed at 1071 entries identical across a full run. Item 6 (ten consecutive agreeing runs) I did not re-run — I confirmed one green run of 186; the Log's ten-run evidence stands unchallenged but unverified by me.
- `chat_typing.lua`'s new default has no test, and `make perf` always sets `PERF_OUTPUT`, so the fallback branch is exercised only when `start()` is called directly. I verified the expression by evaluating it rather than by a spec. Not worth a guard on its own — but if you want one, extracting a pure `default_output(tmpdir)` would make it a one-line unit case (see ARCH-PURE below).
- `tests/unit/ready_port_spec.lua` does real filesystem IO in a directory TOOLING describes as "pure logic, no Neovim APIs". Consistent with existing drift across the unit suite; noted, not raised.

## 6. Architectural notes for upcoming work

- **ARCH-DRY** — flag (Minor, §4): the spawn scaffolding duplication. Otherwise pass; the scratch location is single-sourced and the four-way rationale restatement was correctly reduced to two pointers plus two audiences (TOOLING = developer-facing, atlas = map).
- **ARCH-PURE** — pass, with a nudge: `wait_for_port` fuses the pure predicate (*is this string a TCP port?*) with the polling IO, so four of six unit cases — newline, garbage, out-of-range, empty — are pure string cases forced through the filesystem. Splitting out `M.parse_port(content) -> port, err` would leave exactly one genuinely time-dependent case, and would give `chat_typing`'s default-path derivation a pure seam too.
- **ARCH-PURPOSE** — pass: the diff delivers the purpose rather than the easy subset. The redesign moved the fix from N readers to one writer, and the two "follow-up"-shaped gaps round 1 identified (an unguarded invariant, an untested publisher) were both closed in-window rather than deferred.
- **ARCH-MOCK** — pass: the SSE fake sits behind the same HTTP boundary production uses; `PARLEY_PUBLISH_DELAY` is a fake-only observability hook whose effect is itself asserted, so it can't rot silently. No new out-of-seam external calls; `cksum`/`cut` are build-time.
- Carry-forward for a separate issue (unchanged from round 1, still true): `tests/integration/openai_tool_loop_spec.lua:27`'s `free_port()` — bind, read, close, hand the number to a fixture that binds it later — is the same TOCTOU family this issue just closed on the ready-file channel, and the atlas's "Fixture readiness" rules don't cover it.

## 7. Plan revision recommendations

None. Every `## Plan` item is delivered at its stated location, the single-pass no-`Mx` shape is right, and the `## Revisions` entry accurately records the pivot. Round 1's conditional recommendation (a note that Done-when item 3 was inspection-only) is moot — item 3 is now test-backed.

```findings
dispose:
  - id: BR-1
    disposition: addressed
    note: |
      Verified at the expansion: make -n test-clean-env emits four separately-quoted words.
  - id: BR-2
    disposition: addressed
    note: |
      tests/arch/scratch_placement_spec.lua verified 6/6 green at HEAD, 6/6 red with scratch repointed into the repo.
  - id: BR-3
    disposition: addressed
    note: |
      fixture_ready_publish_spec verified red on both revert shapes; the honored-delay assertion catches hook deletion.
  - id: BR-4
    disposition: addressed
    note: |
      Derivation from vim.env.TMPDIR evaluated directly and correct; shadow-sweep finds no other live restatement.
  - id: BR-5
    disposition: addressed
    note: |
      TOOLING.md:47 now reads "see Test Scratch Directories above".
  - id: BR-6
    disposition: addressed
    note: |
      TEST_ENV_KEY hoisted to := at Makefile.parley:35.
  - id: BR-7
    disposition: addressed
    note: |
      Makefile.parley:26-28 and minimal_init.vim:19-21 now point at the atlas entry instead of restating it.
  - id: BR-8
    disposition: addressed
    note: |
      atlas/infra/test_harness.md records the cwd fallback and why the guard asserts produced paths.
  - id: BR-9
    disposition: addressed
    note: |
      TOOLING.md now warns that make test wipes the scratch root and a default-path perf report with it.
findings:
  - id: new
    severity: Important
    family: unbounded-destructive-wipe
    title: |
      make test rm -rf's a caller-supplied TEST_ENV_ROOT wholesale, and TOOLING.md advertises that override
    detail: |
      Second blast-radius defect in the same one-line recipe as BR-1, so fix the rule, not the instance.
      Makefile.parley:224 wipes "$(TEST_ENV_ROOT)" verbatim, test-clean-env now runs first in every make
      test, and command-line overrides propagate to the sub-make. Verified with make -n test
      TEST_ENV_ROOT=/tmp/claude-501/rootprobe, which expands to rm -rf on that whole directory; TOOLING.md:22
      tells readers to pass TEST_ENV_ROOT=/some/where. Rule - test-clean-env may only delete paths the harness
      itself constructs and can name literally, never a caller-supplied path used verbatim, and each quoted.
      Concretely, remove the three leaves PREP_TEST_ENV creates instead of the root - rm -rf "$(TEST_HOME)"
      "$(TEST_XDG)" "$(TEST_TMP)" $(LEGACY_TEST_DIRS) - or always append $(TEST_ENV_KEY) to the override.
  - id: new
    severity: Minor
    family: shared-scratch-across-concurrent-runs
    title: |
      The new pre-run wipe makes a second concurrent make test in the same checkout destructive
    detail: |
      Reproduced - with make test-unit in flight, make test-clean-env deleted most of the live scratch tree
      and exited 1 with "rm - .../tmp - Directory not empty"; the running suite survived by luck. Pre-202 the
      root was shared but never auto-wiped, so the hazard is new. Fails loudly rather than silently, hence
      Minor; a per-run suffix or a lock file would close it.
  - id: new
    severity: Minor
    family: copy-pasted-spec-scaffolding
    title: |
      fixture_ready_publish_spec copy-pastes the env-building and spawn scaffolding from chat_progress_process_spec
    detail: |
      fixture_ready_publish_spec.lua:34-40 duplicates the vim.fn.environ() fold, PYTHONDONTWRITEBYTECODE=1,
      uv.spawn and close-on-exit block from chat_progress_process_spec.lua:33-38 (ARCH-DRY). tests/helpers/
      now exists and is the natural home for a spawn_fixture(mode, ready_file) shared by both.
```
