# Fresh-clone installability implementation plan

> **For agentic workers:** Consult AGENTS.md Section 3 for execution strategy; use superpowers-executing-plans for the dependent runtime changes. Checkboxes are implementation tasks, with one whole-issue close review.

**Goal:** A standalone checkout or release archive loads Parley, creates a chat, and supports contributor tests without an ariadne checkout.

**Architecture:** Ship the generated issue vocabulary as versioned runtime data. Its CUE source stays upstream, with a maintainer regenerate-and-compare gate. Treat unavailable vocabulary as an explicit optional capability; preserve chat and read-only issue text while refusing lifecycle-dependent actions. Separate portable build targets from optional maintainer overlays.

**Tech stack:** Lua/Neovim, Plenary, POSIX shell, Make, existing vocabulary exporter.

## Scope and alternatives

Recommended: vendor the small derived JSON plus a content drift check, and remove eager failure from the optional issue subsystem. Requiring users to bootstrap ariadne would preserve today's coupling and fail the product goal. Shipping only the JSON is a useful happy-path fix but would leave corrupt installs fatal and the contributor Makefile unusable.

This fulfills #208 and unblocks the isolated starter profile. Provider defaults, consent, health presentation, Homebrew, and the starter itself remain in their existing packaging issues.

## Core concepts

### Pure entities

| Name | Lives in | Status | Contract |
|------|----------|--------|----------|
| `IssueVocabulary`, `from_table` | `lua/parley/issue_vocabulary.lua` | modified | Validate category arrays and lifecycle endpoints before deriving indexes; no invented statuses |

One vocabulary owns all lifecycle semantics (ARCH-DRY). Validate strings, dense arrays, disjoint categories, at least one open status, and known transition endpoints. Unknown extra JSON fields remain compatible with upstream evolution. Preserve existing first-transition ordering. The from_table strategy below verifies this pure boundary without IO mocks.

Without a model, parsing retains a supplied status and leaves a missing one absent. Classification supplies no fabricated active/open/terminal membership. Status cycling, defaults used for creation, and status completion are unavailable. Display can still show and sort raw records. Audit every `issue_vocabulary.default()`/`vocab()` consumer and indirect lifecycle helper caller. In particular, `issue_finder.lua`’s status-cycle action and the issue-buffer handler must check the result before concatenating or writing; unavailable data leaves status, updated timestamp, and all file bytes unchanged. Ensure none dereferences nil (ARCH-PURPOSE).

### Integration points

| Name | Lives in | Status | Wraps |
|------|----------|--------|-------|
| `default_status`, `parse_frontmatter`, status predicates, `cycle_status_value`, completion values, `topo_sort` | `lua/parley/issues.lua` | modified | Preserve raw text without vocabulary; lifecycle operations return an unavailable diagnostic |
| `materialize` / status ordering | `lua/parley/issue_finder_records.lua` | modified | Deterministic ID ordering when vocabulary unavailable; valid models retain category order |
| `materialize` | Same issue records shuffled while vocabulary is unavailable | Sorting every permutation yields the same deduplicated IDs; archived mtime ordering remains unchanged; ready-model controls retain category order |
| `load`, `default`, `reload` | `lua/parley/issue_vocabulary.lua` | modified/new | JSON read/decode and one tagged cache: unprobed, ready(model), unavailable(reason) |
| `get_cache`, `scan_issues`, `setup`, issue action handlers | `lua/parley/issues.lua`, `lua/parley/issue_finder.lua`, `lua/parley/init.lua` | modified | Optional capability wiring and user diagnostics |
| `run_sdlc_issue_new`, `build_spawn_argv` | `lua/parley/issues.lua` | modified | Existing async runner; retain PATH executable and interactive-shell alias/function support |
| Vendored vocabulary | `construct/generated/vocabulary/issue.json`, `.gitignore` | new | Release runtime data generated from upstream CUE |
| Vocabulary drift check | `scripts/check-vocabulary.sh`, `scripts/merge-checks.d/20-vocabulary.sh` | new | Export into scratch and compare content; never repair during a check |
| Portable build | `Makefile`, `Makefile.local`, `Makefile.parley`, `scripts/ci-setup.sh` | modified | Local tests plus explicit optional ariadne maintainer targets |
| Standalone smoke harness | `tests/integration/fresh_clone_spec.lua`, `scripts/check-fresh-clone.sh` | new | Real isolated Neovim and tracked-tree archive |

`load` stays strict for direct callers. `default` returns model or nil/reason and caches either outcome; `reload` re-reads on explicit setup so repairs can recover without restarting. Startup must not notify about optional issue data until an issue action needs it. The cache strategy below verifies recovery and retained outcomes (ARCH-ORDER).

The issue creation runner already handles process-start errors and exit codes. Preserve shell aliases; improve missing-command diagnostics at that existing seam instead of rejecting every non-PATH command. Vocabulary-dependent actions refuse before creating files. A portable fake executable stores issued requests and created issue files in a scratch folder; the runner strategy below checks the real shell route against that state. Real `sdlc` read-only help/discovery checks validate command availability behavior; don't create real issues in tests (ARCH-MOCK).

## Function-level test strategies

| Function / boundary | Adversarial input class | Mechanical guard |
|---|---|---|
| `from_table` | Mutate one structural invariant of a minimal valid model at a time: category membership/array shape or transition endpoint | Every mutant is rejected before indexing; valid models preserve derived membership and first-transition order without IO |
| `load` | Files whose bytes violate the read bound, JSON grammar, or model shape | Real scratch files fail explicitly; the valid control produces exactly the expected model, and no read borrows workspace data |
| `default`, `reload` | Filesystem changes between cache events | Drive unprobed→ready/unavailable and explicit reload transitions against scratch files; repeated default calls retain the cached outcome, reload observes the new bytes |
| Lifecycle helpers and callers | Absent model while raw issue text remains present | Table-driven helper checks plus each actual buffer/finder creation/cycle handler: compare bytes and timestamps before/after and require the unavailable diagnostic; enumerate direct and indirect callers with rg |
| `build_spawn_argv`, `run_sdlc_issue_new` | Command availability differs between PATH and the interactive shell | Filesystem-backed fake records argv and created files; exact quoted titles survive both routes, unavailable/failed routes return failure and leave the issue directory unchanged |
| Drift checker | Committed content changes without source-stamp changes | Same export command passes the control, fails the mutated copy, and never repairs either input |
| Standalone smoke | Hidden dependency available only outside the extracted product | Launch from the archive cwd under isolated HOME/XDG/runtimepath and assert load/setup/chat succeeds without external runtime data; missing-data variants additionally prove safe issue-action refusal |

`make check-sdlc-conformance` runs read-only real command help/discovery checks
on maintainer machines with sdlc, on each change to the runner seam and before
#208 closes. Missing sdlc is explicit pending in ordinary tests; invoking this
maintainer target without it fails with advice. Portable fake-backed tests run
on every normal suite invocation. CI does not install sdlc just for this check.

## Maintainer prerequisite: ariadne#225

The plan review established that weave has no supported local ownership override.
Use the smallest upstream fix: ariadne#225 makes the generic root Makefile a
portable **seed** with optional workflow inclusion and a sibling-overlay
fallback after bootstrap clones peers. It also fixes seed migration to unlink
destination symlinks before writes/chmod, including identical-content links;
old targets must remain unchanged. Parley keeps its existing product targets in
Makefile.local; the root is the generated upstream artifact, not a divergent
copy. The upstream manifest also owns the seeded CI workflow. ariadne#225 therefore
updates that generic shim to discover the bootstrapped runner and invoke an
optional executable repo-owned `scripts/ci-setup.sh` before checks. Parley's
hook owns its exporter prerequisites; do not locally fork the seeded workflow.
Repeated weave must preserve both the portable root and effective CI behavior.
This peer issue must ship before tasks 2 and 3. Its implementation needs its own
durable plan and gate; no peer code is included in this issue.

Parley's `scripts/ci-setup.sh` uses the CI host Go with `GOTOOLCHAIN=auto`
and the bootstrapped ariadne go.mod to select its declared Go version, installs
CUE v0.16.1 (the locally verified exporter version), builds `./cmd/vocabulary`
in that peer, and exposes both binaries via GITHUB_PATH before the check step.
The drift check runs from Parley's root. Merely cloning the peer is insufficient. Verify
a clean isolated runner succeeds before deliberately altering the JSON and
checking that the same command fails; ordinary public tests require neither
Go nor CUE.

## Operating boundaries

- Runtime vocabulary is a small local file, read once per setup/cache generation; no network, code generation, or child process on plugin load. Reject oversized input before JSON decoding with a conservative 1 MiB cap (current artifact is roughly 5 KiB). A bad artifact disables only the dependent capability (ARCH-CONSTRAINTS, ARCH-SECURE).
- Tests use isolated HOME/XDG/TMPDIR and a controlled runtime path; they cannot see the user's profile, sibling-generated data, or credentials. No provider request is required to prove chat construction.
- Archive/export scratch belongs to each invocation and is removed on success or failure, with failures reported. Vendored JSON is one bounded file replaced only by regeneration; ignored maintainer links remain operator-owned and are not deleted (ARCH-FUNERAL).

## Tasks

- [ ] **Runtime data and degradation.** Implement the from_table/load/cache/lifecycle/materialize strategies in `tests/unit/issue_vocabulary_spec.lua`, `tests/unit/issues_spec.lua`, and finder tests, first observing red. Vendor the actual exporter output; expose only the required JSON through the existing generated-directory ignore. Implement capability handling across the enumerated consumers, then run all vocabulary/issue/finder specs and the chat lifecycle smoke tests. Keep the CUE lifecycle unchanged.
- [ ] **Enforced derivation.** Implement regeneration into a temporary directory and semantic content comparison, including categories, transitions, and discovery. A source hash alone is insufficient. With ariadne absent, regular contributor tests validate the shipped artifact; the explicit maintainer drift command fails with setup advice. Wire the drift command into merge checks where CI bootstraps ariadne. Tests modify a scratch committed artifact and must go red even with an unchanged source stamp; restore and prove green. Use the real exporter for conformance, with a scratch fixture exporter for portable mutation tests.
- [ ] **Portable development tree.** After ariadne#225 ships, replace the root link with its portable seeded Makefile; Makefile.local includes Makefile.parley exactly once. Verify help/local targets without peers, and initial bootstrap plus repeated weave from a scratch consumer with every maintainer link absent. Assert the root stays a real file and upstream bytes/modes do not change; keep maintainer targets through the new sibling-overlay fallback. Make `PLENARY` overridable and actually feed it into `NVIM_TEST_PLENARY`; fail early with dependency advice if missing. Untrack the 28 enumerated escaping links while retaining local files and ignoring their exact paths; replace root Makefile rather than ignoring it. Consume ariadne#225’s updated seeded CI shim and keep Parley setup in scripts/ci-setup.sh, so removing the tracked runner link does not break CI or get undone by weave. Verify the maintainer bootstrap path still restores its optional tools. Document prerequisites in `TOOLING.md`.
- [ ] **Standalone acceptance.** Archive the tracked candidate tree into scratch outside the workspace with no `.git` or sibling. Run real Neovim require/setup/new-chat with network-triggering settings disabled, once with intact vocabulary and again with missing/corrupt/malformed variants. Assert issue mutations fail clearly and chat still works. Validate no tracked symlink escapes the archive; include a deliberate escaping-link fixture that the guard rejects. The recursive full-suite acceptance runs in a second extracted tree initialized as a temporary git repo (arch tests require git); do not recursively invoke it from the normal spec. Supply Plenary explicitly from a declared dependency location, never hardcode the operator path. Run `make test` there and in the development checkout.
- [ ] **Documentation and close.** Update `atlas/issues/issue-management.md`, `atlas/infra/test_harness.md`, `atlas/index.md` if a page is added, `atlas/traceability.yaml`, and issue/project logs with the independent-install contract and exact commands/evidence. Run diff/lint checks and `sdlc close --issue 208 --verified '<evidence>'`; fix its findings before `sdlc pr` and `sdlc merge --yes`.

For each implementation task: run the new failing regression first, implement the smallest contract-preserving change, rerun the focused tests, then commit that coherent slice. Use `make test-spec SPEC=<matching-spec>` or the isolated Plenary runner; full verification is `make test` plus `scripts/check-fresh-clone.sh` and the maintainer drift check. Do not accept green tests that borrowed generated files from this checkout.

## Approval and estimate

Prepared for operator review; no #208 implementation has started. Derive estimate only after approval and `sdlc change-code` plan-quality acceptance.

## Revisions

### 2026-09-13 — deployment-goal investigation

Reason: #244 shipped and today's goal requires a usable separate app profile. Delta from the original issue sketch: preserve shell-function support, define explicit unavailable vocabulary semantics rather than guessing statuses, compare generated contents rather than only stamps, expose the actual Plenary override, and repair CI's reference to an untracked maintainer link. These are necessary to deliver the existing fresh-clone acceptance.

### 2026-09-13 — fresh-eyes plan review repairs

Reason: review found an indirect status-writing caller, absent CI exporter
prerequisites, and weave overwriting the proposed real root. Delta: include
issue_finder's cycle handler and unchanged-file assertions; explicitly provision
Go/CUE/exporter in CI; track the narrowly scoped portable-seed prerequisite as
ariadne#225. The main runtime work remains local to Parley.

### 2026-09-13 — CI ownership review

Reason: the upstream manifest also seeds the generic CI workflow. Delta:
ariadne#225 owns its runner fallback and optional setup-hook invocation;
Parley owns only scripts/ci-setup.sh and its drift check. Re-weave tests cover
both root Makefile and effective CI behavior, avoiding a downstream fork of
an upstream-owned file.

### 2026-09-13 — plan-quality gate round 1

Reason: PQ-1 requested named-function strategies instead of repeated test case
inventories; PQ-2 requested an execution trigger for live runner conformance.
Delta: name each risky function’s adversarial input class and mechanical guard,
and make read-only command conformance a maintainer target required at this
close and whenever the runner seam changes. Isolated archive reproduction
confirmed that launch cwd must also be isolated to avoid borrowing vocabulary.
Operator-approved scope is unchanged.

### 2026-09-13 — runtime implementation discoveries

Reason: isolated reproduction borrowed cwd data, and real shell-route testing
showed the quoted command name suppressed aliases. Delta: resolve vocabulary
only from this plugin’s module root; share `default_status` across parsers and
templates; leave only safe command identifiers bare for shell alias expansion,
with every argument quoted. The fake verified literal injection-like titles
through executable, function, and alias routes; unavailable-command diagnostics
include setup advice. These repairs fulfill the approved boundaries.

### 2026-09-13 — cache-generation and scan sweep

Reason: a missing-status disk scan still fabricated open, and cached defaults
could survive a vocabulary reload. Delta: scanners share default_status;
get_cache clears parsed records when the model identity changes. Direct
next-runnable and status-write helpers also refuse unavailable data. Display
uses a question-mark label for absent status without altering stored values.
These adapters read the model cache and are classified as integration; only
the validated model and its calculations are pure. Added red→green regressions
for the scan and ready→unavailable cache transition.
