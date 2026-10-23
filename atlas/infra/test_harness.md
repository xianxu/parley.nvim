# Test Harness

Contributor verification, not an application prerequisite. `make test` runs
Lua unit, integration and architecture specs with isolated profile data.
See `TOOLING.md` for dependencies, targeted tests and performance commands.

## Shape

- `make test` = `test-clean-env` -> `lint` -> `test-unit` -> `test-integration`,
  chained through recursive `$(MAKE)` so `make -j` cannot reorder the wipe into
  a running suite.
- `test-unit` and `test-integration` fan out with `xargs -P $(JOBS)` (default 8),
  one headless Neovim process per spec file; `RUN_SPEC` captures each file's
  output and appends failures to `$FAILED_LOG` for an authoritative summary.
- `tests/unit/` = pure logic, `tests/integration/` = full runtime,
  `tests/arch/` = fitness functions, `tests/helpers/` = shared spec helpers
  (not collected — the runners glob `*_spec.lua`).
- Golden payload comparisons use `scripts/golden_fixture.lua` to normalize
  ripgrep version tokens only in the two search-tool descriptions. Captures
  retain their real wire text; substantive descriptions, schemas, and messages
  still compare exactly (`tests/unit/golden_fixture_spec.lua`).

## Scratch placement is the determinism invariant

The harness hands every run its own `HOME`, `XDG_*`, and `TMPDIR` under

```
$TMPDIR/parley-test-env/<checkout>-<cksum-of-path>/{home,xdg,tmp}
```

keyed by checkout so worktrees don't share, overridable via `TEST_ENV_ROOT`.

**That root is outside `$(CURDIR)` on purpose (#202).** Eight parallel jobs
churn the scratch tmp dir all run long, while the `find`/`grep`/`ack` tool specs
traverse the repo to exercise the real tree — and `grep`'s "defaults missing
path to cwd" case cannot be written any other way. With scratch in `.test-tmp/`
those specs raced a directory vanishing mid-traversal, `find` exited nonzero,
and the suite read as randomly flaky. Placement enforces the invariant, so no
spec has to defend itself and no lint has to police traversal roots. `nvim`'s
`directory` (swap) follows `$TMPDIR` for the same reason
(`tests/minimal_init.vim`).

**Every spec child loads `tests/minimal_init.vim`.** `tests/helpers/spec_runner.lua`
passes it to its owned Plenary child, so what the init sets — `g:` variables included — reaches
the spec, and the harness-only guards it installs (a per-process
`$PARLEY_QUERY_DIR`, the watch for a refusal with no words) cover the whole
suite rather than the specs that remember to ask (#261 M5). Before that, children
started with no `-u` at all and only the environment carried over, which is why
the harness signal is an environment variable, `$PARLEY_TEST_MODE=1`, which every
child inherits however it starts. It has ONE reader, `test_isolation.active()`
(#235). `file_tracker` asks it, so the suite never writes the shared
`file_access.json`; so do `cliproxy`, which refuses data roots outside the
isolated env and honors a releases-URL override only in tests, and
`issue_tracker`, which never fetches a remote. `single_source_sweeps_spec`
refuses any other `lua/` reader, including the retired `g:parley_test_mode`. A
spec that needs the real behavior clears the variable for its case:
`file_tracker_spec` exercises real persistence, and `tests/helpers/sidecars.lua`
does one tracked open.

`scripts/test-placement.sh` checks the same rule first. It is the opening step of
`PREP_TEST_ENV`, so it runs once per make target, before anything is created. It
refuses when `TEST_ENV_ROOT` resolves inside the checkout, or when it or any
ancestor carries the `.parley` marker (#422). An inside-checkout `sdlc` review
put `TMPDIR` in the review clone. The zero-config spec then found the clone's
marker and wrote a chat into the clone's `workshop/parley`. In-process, the
spec-level guard would have reported the problem only after other specs had
already written into the tree. The guard also refuses a `TEST_ENV_ROOT/tmp`
longer than 189 bytes (#423). Neovim ignores a `$TMPDIR` that long, and
`tempname()` silently falls back to `/tmp/nvim.<user>`. The in-process spec pins
that limit against the running Neovim. It also asserts that `tempname()` lies
under `$TMPDIR`, which catches a fallback for any other reason.

`tests/arch/scratch_placement_spec.lua` is the in-process guard: it asserts
`vim.fn.tempname()`, `'directory'`, `$HOME`, and the `$XDG_*` dirs all resolve
outside `getcwd()`. It guards the *writer*, which — unlike a lint over spec
traversal roots — has no false-positive problem. It asserts the produced paths
rather than the env vars on purpose: nvim's tempdir fallback chain ends at the
cwd, so an unwritable `$TMPDIR` would silently put scratch back in-tree.
(`PREP_TEST_ENV`'s `mkdir -p` aborts a `make` run before that, but the guard
does not depend on that failure being loud.) It also scans every script and
test (#381) for a temp dir rooted at a fixed `/tmp`, through Python's `dir=` or
shell `mktemp`. Inside an agent sandbox `/tmp` is denied, so such a test fails
on every Neovim version. Temp dirs follow `$TMPDIR`; the `${TMPDIR:-/tmp}`
fallback is allowed.

**Specs never run against the operator's real state (#342).** `TEST_ENV`
exports `PARLEY_TEST_ENV_ROOT`, and `tests/minimal_init.vim` (loaded by the
parent and every spec child) first runs `parley.test_isolation.check()`. When
the marker is missing, or HOME or an XDG root resolves outside it, the init quits
with the reasons and the `make test-spec` to use, before plenary loads a spec or
any `-c` command runs. A direct `nvim -u tests/minimal_init.vim` with the real
environment once rewrote the operator's cliproxy catalog. Behind it, in test mode
(`PARLEY_TEST_MODE=1`), cliproxy's `data_root()` refuses a root outside the marked
one, so a spec that forgets `_set_data_dir` fails instead of writing elsewhere.
Scripts that run in test mode with their own roots declare them the same way
(`check-spell-compatibility.sh`). `make goldens` replaces the direct golden
refresh. Pinned by `test_isolation_spec` (unit and integration).

**Specs start from an allowlist environment, never the operator's (#365).**
Pinning HOME and XDG wasn't enough. A spec still inherited the slot's live
`COUCH_THREAD_SCOPE`/`TAG`, so any move or open without its own fake asked the
REAL `couch` registry, and could mutate it. Every nvim in `Makefile.parley` now
starts through `scripts/test-env.sh` (`TEST_RUN`), which keeps only a fixed list: PATH, the pinned roots, TMPDIR, the harness's own knobs,
locale, and `PARLEY_LIVE_*` opt-ins. `SHELL=/bin/sh` is set explicitly. It
removes every other name with `env -u NAME`, so a kept credential's value never
reaches an argument list. No `COUCH_*`, `PAIR_*`, terminal owner or credential
crosses, with three exceptions:
- Each live flag carries only its own check's names: `PARLEY_LIVE_CONFORMANCE`
  takes `CLIPROXYAPI_API_KEY`, and `PARLEY_LIVE_CLIPBOARD` takes the display.
- `PARLEY_LIVE_COUCH` takes the real thread, but only for
  `make check-couch-actors-live`, which runs `couch_spec` alone. `TEST_RUN`
  strips the flag for every other target, so an exported one never reaches the
  suite, `test-spec` or the rest. The real thread is the Couch names plus
  `PAIR_SESSION_NAME` and `PAIR_LAUNCH_NONCE`, the caller identity the CLI
  checks (#366). The CLI also refuses the isolated `XDG_DATA_HOME`, so the
  live call alone gets the operator's data home through
  `PARLEY_LIVE_COUCH_DATA_HOME`; the spec process stays isolated. When the
  call still fails, the case goes pending with the exit code and the first
  stderr line.
- `make fixtures` names its API keys in `PARLEY_TEST_ENV_PASS`.

The launcher also puts `tests/fixtures/sentinel-bin` first on PATH. A bare `couch` or `pair` that no
fake shadows records the call in the target's own `$(TEST_ENV_ROOT)/sentinel-<target>.log` and exits 97,
and every target fails afterwards on a non-empty log (`SENTINEL_CHECK`, beside
the orphan gate). That's the proof no spec reached the real CLI or its registry
socket. A spec that wants Couch installs a fake bin ahead of the sentinel.
Ordinary outside-pane Markdown discovery has one harness default: when Couch
resolves to the sentinel, the exact read-only registry lookup runs through the
existing persisted registry fake with a private empty store. Explicit spec fakes
win. The shared bootstrap installs this boundary in parent and embedded editors;
it changes neither PATH nor ambient registry variables. Direct CLI calls and
all other verbs still reach the sentinel.
Pinned by `test_isolation_spec`: `ambient()` is empty in a spec process, the
launcher's output is exactly the list, the sentinel refuses and logs, and no
Makefile nvim launch bypasses the launcher.

Corollary worth keeping: a full `make test` mutates nothing inside the repo
working tree. That is checkable — snapshot `find . -path ./.git -prune -o -print`
with mtimes before and after, and diff.

## Wiping the scratch

`make test` runs `test-clean-env` first, so every full run starts empty. Two
things follow from that recipe being destructive and running on every run:

`tests/arch/destructive_recipe_spec.lua` is the guard: it re-expands the recipe
with `make -n` (under a probe root containing a space, and from a copy under a
spaced checkout), splits the argument list the way `sh -c` would — a single
parse, so `set --` and never `eval set --` — and rejects any argument that is
not an absolute path the harness built. Green today; red on either historical
shape.

- **It deletes only the leaves `PREP_TEST_ENV` constructs** (`home`, `xdg`,
  `tmp`), never `$(TEST_ENV_ROOT)` verbatim — plus the pre-#202 in-repo
  `.test-*` dirs. The rule: a destructive recipe may only remove paths the
  harness itself built and can name literally, each quoted individually.
  `TEST_ENV_ROOT` is a documented override and command-line overrides propagate
  to the sub-make, so `rm -rf "$(TEST_ENV_ROOT)"` would have turned
  `make test TEST_ENV_ROOT=/some/where` into `rm -rf /some/where`. The quoting
  half of the rule is the same defect one step earlier: an unquoted path list
  word-splits, so a checkout under `~/my code/` deleted `~/my`.
- **One leased test command per checkout at a time.** A second command waits
  before scratch mutation and census, even with a distinct `TEST_ENV_ROOT`,
  because the process census sees the entire checkout. Use separate worktrees
  for concurrent suites. A per-run suffix was rejected: it makes the
  scratch path unpredictable (the perf report's default location derives from
  it) and leaves one directory per run with nothing to reap them.

## Fixture readiness

Spawned fixtures that bind port 0 publish the port through a file. Two rules,
because a reader cannot tell partial digits from complete ones:

- Publisher writes to a sibling path and renames onto the ready path
  (`tests/fixtures/fake_sse_server`). Existence must imply completeness.
- Consumer waits for a *parseable* port, never for mere existence
  (`tests/helpers/ready_port.lua`), so an incomplete signal is a named timeout
  instead of a nil concatenated into a URL.

Both halves are guarded. `tests/unit/ready_port_spec.lua` constructs the absent,
zero-byte, empty-then-filled, non-numeric, and out-of-range signals directly.
`tests/integration/fixture_ready_publish_spec.lua` holds the publish window open
via `PARLEY_PUBLISH_DELAY` and asserts the ready path is never observable
incomplete — and asserts the delay was honored, so the hook cannot be deleted to
make it pass. Neither has a race to win.

Fixtures given a fixed `--port` (picked by `ready_port.free_port`) are waited on
with `ready_port.wait_listening`, never a hand-rolled connect loop. A completed
connect is not proof of a listener (#360): the freed number goes back to the
kernel's ephemeral pool, a parallel spec's probe can take it as a source port,
and two crossing probes complete a TCP simultaneous open with nothing
listening. So `is_listening` confirms a connect with a LISTEN socket on the
port (`lsof`, bounded, run only after a connect succeeds). `ready_port_spec`
stages that false positive through the `_connect` seam.
A spec that only needs the fake up calls `ready_port.require_listening`, which
fails by name ("fake never came up on port N"). `wait_listening` is
`---@nodiscard`, and `tests/arch/nodiscard_spec.lua` refuses a dropped answer
(#361): one turned a dead fake into a missing login prompt, or a retry where
give_up was due.

## Process lifecycle

Every process a test creates has an owner and an end. The layers are placed at
the chokepoint for each process shape:

| failure or exit shape | owner and cleanup |
|---|---|
| normal spec exit or assertion failure | `tests/helpers/fixture_process.lua` registers every `uv.spawn` handle, reaps it at `VimLeavePre`, and supports marked per-case cleanup |
| killed or wedged harness Neovim | `tests/helpers/exit_with_parent.lua`, installed by `tests/minimal_init.vim`, exits when the parent is gone or when the process is reparented to init |
| fixture server or blocking fixture mode | `LoopbackHTTPServer` installs `tests/fixtures/fixture_watchdog.py` for server fixtures; non-server blocking modes call the same watchdog directly |
| detached real `cliproxyapi` | the fixture-process registry provides best-effort normal-exit cleanup; it has no parent-death watchdog because the binary is intentionally detached and shared |
| recorded embedded child, including after its caller exits | `tests/helpers/test_processes.lua` retains birth evidence; both runner and terminal census join exact PID/start incarnations |
| legacy harness/fixture process outside that registry | `scripts/reap-test-orphans.py` takes the checkout lease, reads its `ps` rows, excludes the invoking ancestry and non-harness editors, then reports and reaps persistent survivors |

The census uses `--ps-from` as a signal-free recorded-table seam in tests and
re-samples live `ps` output within a bounded grace period before accusing a
process. `pgrep -f` is not a substitute on macOS: it does not match the fixture
process shape this harness produces. New fixture servers inherit the watchdog
through `LoopbackHTTPServer`; new spec subprocesses inherit registry cleanup
through `fixture_process`.

The legacy process-table classifier requires a fixture in executable/script position, or an actual
headless Neovim using this checkout's harness init or Plenary spec invocation.
An editor or pager merely naming a fixture is excluded. Every live observation
is validated; malformed or unavailable resampling reports `BROKEN`, fails the
target, and sends no signals based on the stale snapshot. An initially unavailable
`ps` remains a visible skip for restricted environments.

Bare embedded editors (`--clean --embed --headless -i NONE`) have no checkout path in argv and cannot be recognized safely by that classifier. The retained registry is the independent check: `scripts/test-run-lease.py` allocates a private `parley-test-processes/run-*` context under the checkout’s own Git metadata directory and validated lease and reuses it for recursive make. `scripts/test-env.sh` passes this context explicitly; scratch cleanup never removes it. Linked worktrees keep mutation outside the source tree and use separate Git directories, preserving checkout concurrency. Archives without Git use `.test-processes/`; the census also reads that legacy path so an upgrade cannot hide unresolved evidence. A drained legacy container can retire after successful live reconciliation.

`spec_runner` reserves its own spec-child birth and installs `spec_jobs` for jobstart births. Clean embedded children explicitly install the same wrapper. A pending ticket is persisted **before** spawn; atomic publication adds native PID/start identity, while an interrupted birth remains unknown. The wrapper chains the supplied native on_exit once; a fast child already joined before publication can retire its pending ticket using that native exit proof. `test_process_model` is the pure observation policy, and `process_identity.observe` distinguishes explicit ESRCH from unavailable identity.

On every runner return, the shared registry reconciles recorded children, including detached jobs after an otherwise successful spec. It revalidates identity before exact-PID TERM/KILL and waits for absence or replacement of the original incarnation. A leak makes the spec fail even after successful cleanup; unresolved evidence persists. `scripts/test-process-census.lua` uses the same native Lua module from the Python terminal census, so caller death cannot erase ownership. No cwd, socket, command-substring or process-group inference authorizes this recorded-child cleanup. Snapshot mode observes without signals; positive verifier completion is required before a clean line.

Birth publication preserves unknown JSON member bytes, including numeric tokens that Lua cannot represent exactly. Run scopes reserve one of 64 canonical directories by atomic mkdir, so parallel runners cannot exceed the reader capacity. Empty rmdir releases a slot; explicit ENOENT from concurrent retirement permits continued reservation, while unreadable existing entries remain a refusal. A reused slot is occupied until its next confirmed retirement. Legacy random scopes remain census-readable; admission to a fresh run refuses unexpected leftovers visibly. Registry writers allow 4096 child records per spec (256 bytes each), at most 64 outstanding spec scopes per run and 256 retained run directories per checkout. Atomic publication can temporarily use a second bounded file per record; legacy job ledgers are read with a 1 MiB cap. Reaching a bound fails visibly rather than discarding evidence. Only proven-dead birth records retire; empty spec scopes retire after reconciliation, and prior empty run contexts retire at the next lease admission. Pending, corrupt, replaced, unreadable or foreign-writable evidence is retained for diagnosis. A matching known child may be retried through the same census; an unresolved pending birth requires inspection, since no exact child can be inferred.

The Neovim watchdog also removes its captured query directory using synchronous
libuv filesystem calls, which work in its timer callback. Cleanup unlinks
symlinks without following them and reports errors to stderr.

`Makefile.parley` runs the census before every harness target and after its
tests finish, including failed specs. Survivors make the target fail. All
parent Neovim commands use the physical checkout path in their init argument
so the census can identify them through symlinked working directories too.

`scripts/test-run-lease.py` is the shared IO owner of a checkout-wide `flock`.
Every protected public Make target wraps execution with the shared lease helper
and forwards to its `parley-test-body-*` recipe. This covers direct, prerequisite
and default-goal entry without inspecting requested goal names. Internal bodies
require a validated inherited descriptor as their first prerequisite; directly
invoking them unowned fails before scratch mutation. Make retains the lease
through the public target, recursive make and both census passes. A competing target
or manual live census waits and prints the original owner PID and checkout.
Make's `.NOTPARALLEL` also serializes multiple goals within a lease-owning make;
the per-spec fan-out continues to use `JOBS`.
Reentry validates an inherited descriptor against the physical checkout's
`.test-run.lock` inode; an environment flag or PID is not ownership evidence.
The fixed ignored lock file is never unlinked during use; checkout removal ends
its bounded lifetime. Kernel closure of the last descriptor releases the lease,
including on owner death, so there is no stale-lock deletion procedure. An
inheriting descendant may retain ownership after the printed PID has exited.
Different checkouts still run concurrently; a different scratch root alone does
not create a second census domain. Dry runs and recorded-table census tests have
no destructive effects and do not take a lease. See TOOLING for waiting and
rollout guidance. Gated real-make/census regressions run from
`tests/unit/test_run_lease.py` through the normal reaper spec.
The source guard checks repository-owned Makefiles for new unwrapped test or
harness recipes, with planted negative controls; the alias/default regressions
exercise the actual Make graph through real Neovim and census processes.

## Comment drift

`tests/arch/superseded_comment_spec.lua` fails on two paragraphs in ONE
contiguous comment run that share a verbatim six-word span — the signature of
rewriting a comment by writing the new paragraph and leaving the old one above
it. Four close-gate rounds on #205 each fixed the site a reviewer named; the rule
was only written on the fifth, and it immediately found six instances, four of
them in files (`chat_respond.lua`, `tool_folds.lua`, `skill_edits.lua`) no
reviewer had touched.

Two design choices are load-bearing:

- **An LSP annotation block is excluded.** `---@param col number # 0-indexed byte
  position` is MEANT to restate the prose that explained `col`; comparing the two
  registers measures nothing, and `spell.lua` was the detector's only false
  positive before the exclusion.
- **It catches verbatim overlap, not paraphrase.** `float_picker`'s "Translate
  the caller's items-index…" above "Translated to an identity…" shares no
  six-gram and is invisible to it. The guard's own docstring says so — a guard
  whose message overstates its reach is the finding family
  `test-title-overstates-guard`, which reached nine instances on the same issue.
  The paraphrase half lives in `workshop/lessons.md` as a human check.

The detector runs on the file's lines, and its three injection cases drive it on
synthetic input, so it is shown to fire AND to stay silent independently of what
the tree currently holds.

## Related

- [Linting](linting.md) — `make lint`, which `make test` runs first.
- `TOOLING.md` — the developer-facing command list and perf report.

## Standalone release acceptance

`PLENARY=/absolute/path/to/plenary.nvim` overrides the test dependency across
all child Neovim processes. `check-test-deps` checks it before test fan-out.
The root Makefile is a real upstream seed; optional workflow links and agent
infrastructure are restored by maintainer bootstrap, excluded from releases.

`scripts/check-fresh-clone.sh --runtime --worktree` snapshots tracked/staged
files using a private git index, rejects escaping/dangling links, and runs actual
load/setup/chat creation from the archive cwd with empty HOME/XDG/profile state.
It repeats with intact, missing, corrupt, and malformed vocabulary. Runtime
acceptance needs no Plenary and disallows unexpected subprocesses. `--full`
adds an independently extracted, indexed tree and runs `make test` there;
normal specs never recursively request that full mode. Every invocation owns
and cleans its scratch directory, including on failures. `--ref <commit>` pins
release acceptance instead of the current tracked working tree.

The vocabulary drift check exports current CUE data into scratch and compares
full JSON semantics, independent of formatting and source stamps. It never
repairs inputs. Portable tests use `fake_vocabulary` with file-backed export
results and recorded calls; CI provisions the real exporter/CUE through the
repo-owned setup hook and executes the same check. Runtime/data validation
remains independent of those maintainer tools.

### Concurrent directory creation

`tests/unit/prepare_dir_spec.lua` reproduces a competing directory creator at the mkdir boundary using real temporary directories. `lua/parley/fs.lua` owns the literal-path directory postcondition; helper path expansion remains in `helper.prepare_dir`. A source guard keeps all production directory creators on that seam. `fs.ensure_dir` creates one level at a time and accepts any level a competitor created first. `mkdir -p` raised E739 on a concurrently created intermediate (#347). `tests/integration/ensure_dir_race_spec.lua` races real nvim processes on shared intermediates.

### Large native fold conformance

`tests/helpers/spec_runner.lua` keeps a 50-second no-completed-case budget,
with a 180-second base for the existing large native fold/semantic corpora. The fold batches spec builds
a real 50,010-row document to exercise bounded native fold cleanup. The semantic corpus checks Enter/join scaling through 50,000 rows.
The two fold retirement specs (window preference restoration) cross `tool_folds.INTERACTIVE_ROWS` with a
small fixture instead, by lowering the field in their child (#401), so they run in seconds under the default budget. These index
bootstraps can exceed 50 seconds under parallel load. The override applies to the
exact repository files and is shared by mapped,
full-suite, and direct `PlenaryBustedFile` invocations.

### Driving a child nvim (#401)

A spec that drives an embedded nvim does it through `tests/helpers/embedded_nvim.lua`
(`start`, `exec`, `request`, `input`, `stop`). `start` puts the repository on the
child's runtimepath. Every request is bounded by `request_ms()`: half the spec's idle
budget, which `spec_runner` passes to the spec child, load-scaled, as `PARLEY_SPEC_IDLE_MS`.
A child that never answers is killed by pid, and the request fails naming its method,
before the runner's idle kill ends the spec with no cause. `tests/arch/embedded_rpc_spec.lua` refuses a raw `vim.rpcrequest` or
`--embed` spawn anywhere else.

### A spec's processes end with it (#402)

`spec_runner` starts each spec child as a process-group leader (`vim.system{detach = true}`), so the
child's `vim.system` and `uv.spawn` descendants share its group. Neovim starts every `jobstart` child in a
group of its own, so in spec children `tests/minimal_init.vim` installs `tests/helpers/spec_jobs.lua`,
which retains each job's PID/start birth record in the run-owned per-spec
directory (`PARLEY_SPEC_JOBS_DIR`). The independent reconciliation above also runs after ordinary completion. On the deadline, an unobserved exit, or the runner's own SIGTERM or
SIGINT, the runner sends TERM to the spec's group and to each recorded job's group, waits `GRACE_MS`, then
sends KILL; a spinning nvim never acts on TERM. The spec child and each job are signalled under one
identity guard: a pid whose start time no longer matches names another process and is skipped and logged.
A pid no process holds is still signalled, because its group can outlive it. The wrapper covers
`vim.fn.jobstart` only; `termopen`, Vimscript `jobstart()` and `nvim_call_function("jobstart")` bypass it,
and no spec uses them.

### Deadlines, load, and the Neovim under test (#294)

The runner distinguishes useful work from a stall (#337). A single startup
load sample formerly set a whole-file deadline; growing files were killed after
successful cases at 50–64s although identical code passed in 56–83s elsewhere.
`spec_deadline` now holds the pure transition policy. Its no-completed-case
budget is the base multiplied by the startup 1-minute load/CPU ratio, bounded
from 1x to 4x. An independent absolute ceiling is always base×4: 200s normally,
720s for the existing large corpora. Useful case completions can therefore pass
50s overall; no amount of progress can evade the absolute ceiling.

`spec_child` runs the real Plenary assertions and fixtures. Only after a full
case returns, including before_each/body/after_each, does it emit a monotonically
numbered frame for that invocation. `spec_progress` strips those frames while
preserving ordinary output; arbitrary stdout, foreign/duplicate/invalid frames
and an unfinished line cannot renew the watchdog. Incomplete line storage is
bounded at 64KiB. Bootstrap, a stuck case and final teardown remain covered by
the same idle budget. `spec_runner` owns the child and timer until observed
exit, sends TERM on expiry and escalates to KILL if needed, then reaps and
closes the timer. Normal assertion/exit results stay failures. A timeout names
`stalled` or `absolute-expired`, completed cases and both budgets. Existing
`PASS`/`===FAIL` lines still report whole-file wall time.

Deterministic virtual-clock tests exercise the exact policy (including late
frames, load bounds and terminal states). Native conformance uses isolated real
Plenary children for successful assertions, failed assertions, stalled bootstrap,
case/teardown and a progressing child that reaches the absolute cap; it checks
that timed-out PIDs are gone. Reason-specific probes inject ordinary and capped
load/CPU values through the runner; default invocations still sample the machine.
No test is retried, skipped or granted a new
path-specific timeout exception by this policy.

`make test` runs the nvim chosen by `scripts/test-nvim.sh`, put first on
`PATH` through `TEST_ENV` so spec children and `vim.fn.system` grandchildren
all use it. It prefers a LuaJIT with upstream 68354f4447 (2025-11): on arm64
macOS the OS ignores mcode placement hints, and older LuaJIT (Neovim 0.11.7
bundles one) can only flush and retry. That was #293's "random 15x"
slowdown: once 2.9M flushes for one 25s probe. `PARLEY_TEST_NVIM` overrides
the choice. `lua/parley/jit_tuning.lua` owns the version rule. Repaired test VMs keep
one 1MB mcode area (catastrophic on the old allocator, so gated). On arm64
macOS, old or unrecognized LuaJIT allocators run the isolated harness in
interpreter mode instead of repeatedly attempting failed mcode allocations.
The installed Neovim API is still tested; corpora, work-count assertions and
deadlines are unchanged. A deliberate active-JIT storage-reclamation child
opts out of this protection and asserts that sequence code actually compiled,
so that regression continues to test live trace retention.

In the editor, the same predicate protects only Parley's document, fold,
line-reader and resource-admission module chunks with `jit.off(chunk, true)`.
Nested private functions inherit the opt-out before compilation. It never
disables the VM globally or changes other plugins' compilation. The harness
and real editor share the allocator predicate, not the scope of the effect.
Fresh-child tests verify global JIT remains enabled, unrelated code compiles,
and the complete document pipeline does not start traces under protection.
`PARLEY_TEST_JITSTAT=1 make test` prints each spec process's LuaJIT VM states
and trace flushes (`tests/helpers/jit_watch.lua`), grandchildren included.

**Supported versions and the compat pass (#379).** Parley supports Neovim 0.11
or newer. `lua/parley/version_support.lua` owns that minimum, and `setup()` on
an older editor refuses with one message. Preferring 0.12 for speed must not
hide a break that only the operator's editor has. #373's binary SHA-256 hash
failed on 0.11 alone, with the 0.12 suite green. So `make test` ends with
`test-compat`: when the first `nvim` on PATH (`scripts/test-nvim.sh
--installed`) reports a different version from the preferred runtime, it reruns
`test-unit` and `test-integration` on it, and any failure fails `make test` and
the recorded suite. An installed editor below the minimum fails with
`version_support`'s refusal (`--supported`). It is skipped when the versions
match or no nvim is on PATH. Measured cost: about 160 s for 0.11.7 on arm64,
about the same as the preferred pass, in the same machine suite slot.

### Predicate waits take the arrival budget (#370, #374)

A positive wait returns the moment its outcome arrives, so its bound costs a
passing run nothing; a short literal only turns suite load into a flake. Every
`vim.wait(<literal>, <predicate>)` in `tests/unit` and `tests/integration` is
bounded by `tests/helpers/arrival.lua`'s `MS` (the product's Couch submit
deadline, `agentic_submit_timeout_ms`, read from config: 15 s) or a named product
deadline (a constant ending in `_MS`; session_sync_spec reads
`agentic_submit_timeout_ms` itself), or it says why not on the line that opens it:
`-- absence:` (the spec expects the predicate to stay false), `-- drain:`
(best-effort teardown), or `-- bound:` (the bound is the property under test). A
plain sleep (`vim.wait(N)` or a `return false` predicate) needs nothing.
`tests/arch/arrival_budget_spec.lua` reads the line that opens each wait,
whether it is asserted, bare, or assigned. It allows a bound only when it derives
from `arrival` or names an `_MS` deadline, so a literal behind a parameter or an
`ms or 3000` default is refused as well. It cannot follow a literal passed into a
helper's parameter from a call site. Code that a spec writes for a child Neovim
takes the budget by value, since the child has no `arrival` in scope. The cost:
a broken case now takes up to 15 s to report its first failed wait.

Behavioral fixtures that spawn a producer must separate its test arrival budget
from the product latency contract (#412). The native refusal/retry helper uses
`arrival.MS` only in its disposable child, then checks the completed admission
outcome after `InsertEnter` handlers return. Its failure includes the outcome,
elapsed time, mode, notification, runtime and load. Native timeout/refusal controls
and `couch_spec` retain the production 500 ms policy: a completed timeout remains
editable, whereas an explicit refusal blocks editing. Waiting for mode alone or
longer for `modifiable=false` cannot distinguish those outcomes.

### Waiting on work that converges (#293)

`tests/helpers/await.lua` `until_progress(predicate, progress, stall_ms, ceiling_ms)`
waits while a progress signal keeps changing and fails as `stalled` when it stops,
or at a per-wait ceiling (default 40s). The ceiling bounds one wait, not the
file: it lets a single stuck wait report before the runner’s no-completed-case
budget. The runner separately bounds total file runtime. Choose `stall_ms` no
tighter than the fixed budget being replaced. Use it where the wait is gated on bounded
repair work (e.g. a tool round's continuation waits for the document to repair
the written block): a fixed `vim.wait` budget cannot tell slow from stuck.
`tests/integration/repair_work_budget_spec.lua` guards that repair work with
deterministic counters (`Document.stats`), not wall time.
