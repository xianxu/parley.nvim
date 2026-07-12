# Repo-root Read-wide Completion for All Markdown Implementation Plan

> **For agentic workers:** Consult AGENTS.md Section 3 (Subagent Strategy) to determine the appropriate execution approach: use superpowers-subagent-driven-development (if subagents are suitable per AGENTS.md) or superpowers-executing-plans to implement this plan. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Let reads and file completion search repo-root paths from every repo-mode Markdown buffer while keeping writes confined to the artifact neighborhood.

**Architecture:** Extend `parley.neighborhood` with one ordered `RootPolicy` value containing a narrow `write_root` and widened `read_roots`; every caller consumes that policy rather than reconstructing roots. Keep filesystem probing in the dispatcher/completion adapters, while root derivation, ordering, de-duplication, and model guidance remain directly testable helpers.

**Tech Stack:** Lua, Neovim APIs, Plenary/Busted, nvim-cmp integration.

---

## Core Concepts

### Pure entities

| Name | Lives in | Status |
|------|----------|--------|
| `RootPolicy` | `lua/parley/neighborhood.lua` | new |
| `CompletionCandidates` | `lua/parley/neighborhood.lua` | new |

**RootPolicy** — immutable data `{ write_root, read_roots }` constructed from
already-canonical absolute roots by pure `build_policy(write_root, roots)`.

- **Relationships:** 1:1 with an artifact path at use time; 1:N from one policy to its ordered read roots. The write root is the existing `derive_for_path` result. Read roots are write root, repo root in repo mode, then configured `tool_read_roots`, canonicalized and de-duplicated first-wins.
- **DRY rationale:** `tool_loop`, `skill_invoke`, completion, and model context currently receive pieces of path policy separately. A shared value prevents enforcement and guidance from reconstructing different root sets (`ARCH-DRY`). Filesystem-dependent canonicalization stays in `policy_for_path`; the pure builder only orders and de-duplicates supplied strings (`ARCH-PURE`).
- **Future extensions:** A subtree marker can change policy construction later without changing dispatcher or completion consumers.

**CompletionCandidates** — ordered root-relative candidate labels merged from per-root filesystem results.

- **Relationships:** N:1 from per-root match lists to one de-duplicated display list; the earliest root owns a collision.
- **DRY rationale:** Both built-in completion and cmp configuration need the same ordering and collision rule.
- **Future extensions:** Candidate metadata can later expose the owning root or ranking without changing root derivation.

### Integration points

| Name | Lives in | Status | Wraps |
|------|----------|--------|-------|
| `ReadPathResolver` | `lua/parley/tools/dispatcher.lua` | modified | filesystem existence, realpath, and containment checks |
| `ArtifactRootPolicy` | `lua/parley/neighborhood.lua` | modified | path normalization, buffer name, live config, and chat-root discovery |
| `MarkdownCompletionAttach` | `lua/parley/neighborhood.lua`, `lua/parley/init.lua` | modified | Neovim completefunc/autocmds and nvim-cmp |
| `ToolPolicyWiring` | `lua/parley/tool_loop.lua`, `lua/parley/chat_respond.lua`, `lua/parley/skill_invoke.lua` | modified | chat and skill tool dispatch plus model payload |

**ReadPathResolver** — resolves relative reads by probing each ordered root and accepting the first existing, contained real path; absolute reads must lie within one root. Writes continue through `resolve_path_in_cwd`, including its missing-leaf behavior.

- **Injected into:** `dispatcher.execute_call` through `opts.root_policy`; tests use temporary directories and real symlinks rather than mocking filesystem calls.
- **Future extensions:** Additional read path shapes still enter through the dispatcher's single prelude.

**ArtifactRootPolicy** — thin adapter that canonicalizes configured roots and calls the pure policy builder; `policy_for_buf` adds live buffer/config discovery.

- **Injected into:** tool dispatch, completion attachment, and payload construction.
- **Future extensions:** Buffer-local policy invalidation if repo configuration becomes mutable while a buffer is open.

**MarkdownCompletionAttach** — stores the policy buffer-locally, installs one completefunc/InsertEnter hook, and registers one Parley cmp source backed by the shared candidate merger.

- **Injected into:** repo-mode `prep_md`; `prep_chat` retains the existing call
  for global chats and becomes an idempotent no-op after repo-mode `prep_md`.
- **Future extensions:** Candidate metadata and ranking can widen inside the dedicated source without changing attachment.

**ToolPolicyWiring** — passes one policy to the dispatcher and formats model context from that same value.

- **Injected into:** `tool_loop.process_response`, `skill_invoke.invoke`, `_build_messages`, and `build_messages_from_model`.
- **Future extensions:** Structured provider metadata can replace prose without changing policy semantics.

## Chunk 1: Root Policy and Read Resolution

### Task 1: Derive the ordered root policy

**Files:**
- Modify: `lua/parley/neighborhood.lua`
- Test: `tests/unit/neighborhood_spec.lua`

- [ ] **Step 1: Write failing pure policy-builder tests**

Test only `build_policy(write_root, roots)`: write root is retained, root order is
stable, duplicate/blank roots are removed first-wins, and inputs are not mutated.

- [ ] **Step 2: Write failing filesystem-adapter tests**

Add `policy_for_path(path, config, chat_roots)` cases proving:

```lua
assert.same({
    write_root = "/repo/data/career",
    read_roots = { "/repo/data/career", "/repo", "/repo-sibling" },
}, neighborhood.policy_for_path(
    "/repo/data/career/note.md",
    { repo_root = "/repo", tool_read_roots = { "/repo", "../../../repo-sibling" } },
    {}
))
```

Also cover repo-backed artifacts (write root and repo root collapse to one),
non-repo mode, invalid paths, and absolute/`~`/relative configured roots.

- [ ] **Step 3: Run the focused spec and verify RED**

Run: `make test-spec SPEC=neighborhood`

Expected: non-zero exit with `attempt to call field 'build_policy' (a nil value)`
from the named policy test.

- [ ] **Step 4: Implement the pure policy builder**

Keep `derive_for_path` unchanged as the narrow source. Add a pure constructor:

```lua
function M.build_policy(write_root, ordered_roots)
    local seen, read_roots = {}, {}
    for _, root in ipairs(ordered_roots or {}) do
        if type(root) == "string" and root ~= "" and not seen[root] then
            seen[root] = true
            read_roots[#read_roots + 1] = root
        end
    end
    return { write_root = write_root, read_roots = read_roots }
end
```

Expected implementation is the `build_policy` function above only.

- [ ] **Step 5: Implement shared canonical policy construction**

Add `canonical_roots(write_root, repo_root, configured_roots) -> string[]`.
It emits candidates strictly as `write_root`, then `repo_root` when nonblank,
then configured roots in list order. Absolute roots normalize directly; `~/x`
expands before normalization; relative roots join to `write_root`. Each uses
`fs_realpath` when it exists and otherwise the normalized absolute path. The
helper returns canonical candidates without de-duplication; `build_policy`
performs the one pure first-wins fold.

Export `policy_from_roots(write_root, repo_root, configured_roots) -> RootPolicy`
as the only public canonicalization entry point; it calls private
`canonical_roots` and then `build_policy`. Both `policy_for_path` and the
temporary dispatcher adapter must call this API, so dispatcher never reaches a
private helper or duplicates root normalization.

- [ ] **Step 6: Implement the artifact adapter**

Add:

```lua
function M.policy_for_path(path, config, chat_roots)
    local write_root, err = M.derive_for_path(path, config, chat_roots)
    if not write_root then return nil, err end
    return M.policy_from_roots(write_root, config and config.repo_root,
        config and config.tool_read_roots)
end
```

Add `policy_for_buf(buf)` in a separate edit as the thin live-state wrapper and
keep `for_buf(buf)` returning only `write_root` until Chunk 2 migration.

- [ ] **Step 7: Run focused tests and verify GREEN**

Run: `make test-spec SPEC=neighborhood`

Expected: exit 0 with zero failed assertions in `tests/unit/neighborhood_spec.lua`.

- [ ] **Step 8: Commit the policy core**

```bash
git add lua/parley/neighborhood.lua tests/unit/neighborhood_spec.lua
git commit -m "#181: derive ordered neighborhood root policy"
```

### Task 2: Resolve read paths across ordered roots

**Files:**
- Modify: `lua/parley/tools/dispatcher.lua`
- Test: `tests/unit/tools_dispatcher_spec.lua`

- [ ] **Step 1: Write failing relative lookup and collision tests**

Add `resolve_read_path(path, read_roots)` tests for:

- a bare `atlas/index.md` absent under neighborhood but present under repo root;
- the same relative path under both roots (neighborhood wins);

- [ ] **Step 2: Write failing missing/absolute/symlink tests**

Add separate cases for missing relative reads, absolute reads inside/outside the
set, a symlink escaping every root, and a symlink resolving into another allowed
root.

- [ ] **Step 3: Run dispatcher tests and verify RED**

Run: `make test-spec SPEC=providers/tool_use`

Expected: non-zero exit with `attempt to call field 'resolve_read_path' (a nil value)`
from the new resolver test.

- [ ] **Step 4: Implement the read-only resolver**

Add `resolve_read_path(path, read_roots) -> abs_path|nil, err` beside
`resolve_path_in_cwd`. For relative input, loop roots in order, join and
`fs_realpath` each candidate, and return the first existing candidate whose real
path is contained by any canonical root. For absolute input, require
`fs_realpath(path)` and validate it against the full set. If no relative
candidate exists, return `nil, "read path not found in configured roots: " ..
path`. Preserve `resolve_path_in_cwd` unchanged for writes/new files.

- [ ] **Step 5: Add and test the legacy option adapter**

`policy_from_opts(opts)` must transform legacy `{ cwd, read_roots }` via
`neighborhood.policy_from_roots(cwd, nil, read_roots)`: cwd first,
each relative read root resolved against cwd, canonical first-wins order. Test
`cwd=/repo/data` plus `read_roots={"../", "/repo"}` yields one `/repo/data`
then one `/repo` and resolves `atlas/index.md` from `/repo`.

- [ ] **Step 6: Migrate scalar dispatcher fields**

Change `execute_call` to accept `opts.root_policy`. Route read `path` and
`file_path` through `resolve_read_path`; route write scalars through
`resolve_path_in_cwd(policy.write_root)`.

- [ ] **Step 7: Migrate arrays and defaults**

Route every read `paths` entry and injected `default_path` through
`resolve_read_path`. Add one focused test per shape. Delete the compatibility
adapter after all internal callers migrate in Chunk 2.

- [ ] **Step 8: Add dispatcher kind regressions**

Prove a read-kind tool and an absent-kind tool search the policy, while a
write-kind tool rejects the same repo-root candidate.

- [ ] **Step 9: Run dispatcher tests and verify GREEN**

Run: `make test-spec SPEC=providers/tool_use`

Expected: exit 0 with zero failed assertions in the mapped tool-use specs.

- [ ] **Step 10: Commit the resolver**

```bash
git add lua/parley/tools/dispatcher.lua tests/unit/tools_dispatcher_spec.lua
git commit -m "#181: resolve reads across ordered roots"
```

## Chunk 2: Tool Wiring and Shared Guidance

### Task 3: Pass one policy through chat and skill dispatch

**Files:**
- Modify: `lua/parley/tool_loop.lua`
- Modify: `lua/parley/chat_respond.lua`
- Modify: `lua/parley/skill_invoke.lua`
- Test: `tests/unit/tool_loop_spec.lua`
- Test: `tests/integration/skill_invoke_spec.lua`

- [ ] **Step 1: Write failing chat wiring tests**

Add `"uses one root policy for repo-relative reads and narrow writes"`: create a
repo-mode content buffer under `data/career/` where `atlas/index.md` exists only
at repo root. Save/restore every mutated config field in `before_each` /
`after_each`. Assert the read result contains the repo file; register a write
tool and assert its result contains `outside working directory` and no read-root
hint.

- [ ] **Step 2: Write failing skill wiring test**

Add `"reads repo-root paths while edits stay artifact-bound"`: invoke a
read-capable skill from a non-repo-artifact Markdown buffer and assert its tool
result contains the repo-root fixture text. Retain the exact assertion that
`propose_edits.file_path == artifact_path`.

- [ ] **Step 3: Run focused tests and verify RED**

Run: `make test-spec SPEC=providers/tool_use`

Run: `make test-spec SPEC=skills/skill-system`

Expected: both commands exit non-zero at the named new assertions because the
repo-root file is outside the current single cwd.

- [ ] **Step 4: Wire the shared policy**

Derive `policy_for_buf(buf)` once per response/invocation and migrate every seam:

- replace `agent_info.neighborhood_root` with `agent_info.root_policy` at the
  initial `chat_respond` assignment;
- pass that exact table through `_build_messages` options and
  `build_messages_from_model`;
- pass it to `tool_loop.process_response` for recursive rounds;
- make `tool_loop` fallback call `policy_for_buf(bufnr)` only when no policy was
  injected;
- make `skill_invoke` pass its one derived policy to every dispatcher call;
- extend `respond`'s internal recursive options with `root_policy`; the initial
  call derives it once, and the `outcome == "recurse"` call passes the same table
  into the next `M.respond` invocation, which prefers the injected value over
  re-derivation;
- remove internal `{ cwd, read_roots }` construction and the temporary
  dispatcher compatibility adapter after grep confirms no internal caller.

- [ ] **Step 5: Run focused tests and verify GREEN**

Run: `make test-spec SPEC=providers/tool_use`

Run: `make test-spec SPEC=skills/skill-system`

Expected: both commands exit 0 with zero failed assertions.

- [ ] **Step 6: Commit tool wiring**

```bash
git add lua/parley/tool_loop.lua lua/parley/chat_respond.lua lua/parley/skill_invoke.lua tests/unit/tool_loop_spec.lua tests/integration/skill_invoke_spec.lua
git commit -m "#181: share root policy across tool entry points"
```

### Task 4: Derive model guidance from the policy

**Files:**
- Modify: `lua/parley/neighborhood.lua`
- Modify: `lua/parley/chat_respond.lua`
- Test: `tests/unit/neighborhood_spec.lua`
- Test: `tests/unit/build_messages_spec.lua`

- [ ] **Step 1: Write failing formatter tests**

Add a pure `format_tool_context(policy)` expectation for this exact block:

```text
Relative reads search these roots in order (first existing match wins):
- /repo/data/career
- /repo
Relative writes resolve only from: /repo/data/career
```

Add parse-model and live-model payload tests proving it appears once for
tool-enabled agents and never for agents without tools.

- [ ] **Step 2: Write the failing response-flow identity regression**

Inject one sentinel policy table, capture the policy passed to message building
and dispatch across the initial and recursive round, and assert reference
identity with that sentinel. Stub the recursive request boundary only; do not
recompute a value-equivalent policy in the test.

- [ ] **Step 3: Run focused tests and verify RED**

Run: `make test-spec SPEC=providers/tool_use`

Expected: non-zero exit at the exact-block assertion because the old singular
`Relative tool paths resolve from:` line remains; the seam test also sees no
`root_policy` passed to one or more consumers.

- [ ] **Step 4: Replace caller-local guidance construction**

Delete `chat_respond`'s root-string restatement. Have `append_neighborhood_context` consume `neighborhood.format_tool_context(policy)` and de-duplicate that exact rendered block. Both `_build_messages` and `build_messages_from_model` receive the same policy used by dispatch.

- [ ] **Step 5: Run focused tests and verify GREEN**

Run: `make test-spec SPEC=providers/tool_use`

Expected: exit 0 with zero failures, including both message-building paths and
the policy-identity seam test.

- [ ] **Step 6: Commit shared guidance**

```bash
git add lua/parley/neighborhood.lua lua/parley/chat_respond.lua tests/unit/neighborhood_spec.lua tests/unit/build_messages_spec.lua
git commit -m "#181: derive tool guidance from root policy"
```

## Chunk 3: All-Markdown Completion

### Task 5: Merge candidates across ordered roots

**Files:**
- Modify: `lua/parley/neighborhood.lua`
- Test: `tests/unit/neighborhood_spec.lua`
- Test: `tests/integration/neighborhood_completion_spec.lua`

- [ ] **Step 1: Write the failing pure merge tests**

Test `merge_completion_candidates(per_root)` with ordered lists whose labels
collide. Assert first-root ownership, one displayed label, stable root order,
directory trailing slashes, and sorting within each root.

- [ ] **Step 2: Run the unit RED test**

Run: `make test-spec SPEC=providers/tool_use`

Expected: non-zero exit with `attempt to call field
'merge_completion_candidates' (a nil value)` in the named unit test.

- [ ] **Step 3: Implement the pure merger**

Implement `merge_completion_candidates(per_root)` as a first-wins `seen[label]`
fold. It accepts already-enumerated `{ label, word, abbr, kind }` items, sorts
each root's list by `label`, and returns one ordered flat list without touching
Neovim or the filesystem.

- [ ] **Step 4: Write failing completefunc and cmp-source tests**

Create neighborhood-only, repo-only, and colliding files. Store one policy on
the test buffer and assert `completefunc(0, base)` returns the merged labels.
Instantiate the real Parley cmp source directly (without production
registration), call its `complete(params, callback)`, and assert the callback
receives the same merged labels and first-root collision result. If the test
must call `cmp.register_source`, retain its returned id and unregister/reset it
in teardown. This is a real source-contract test, not only a fake
`cmp.setup.buffer` shape check.

- [ ] **Step 5: Run the integration RED test**

Run: `make test-spec SPEC=providers/tool_use`

Expected: named test `completefunc and cmp source share ordered candidates`
fails because actual completefunc labels omit the repo-only fixture, and source
construction errors with missing `new_cmp_source`.

- [ ] **Step 6: Implement one shared enumerator and two thin adapters**

Replace `vim.b[buf].parley_neighborhood_root` with
`vim.b[buf].parley_root_policy` (migrate all tests/callers and delete the old
fallback in this step). Add `completion_candidates(policy, base)` to enumerate
each read root, convert matches to candidate items, and call the pure merger.
Make completefunc return those items' words. Implement `new_cmp_source()` whose
`complete` calls the same function and invokes the cmp callback, but do not
register it in production here; Task 6 owns registration. Do not create repeated
`path` source names.

- [ ] **Step 7: Run unit and integration GREEN tests**

Run: `make test-spec SPEC=providers/tool_use`

Expected: exit 0 with zero failed assertions in neighborhood and completion
specs.

- [ ] **Step 8: Commit multi-root completion**

```bash
git add lua/parley/neighborhood.lua tests/unit/neighborhood_spec.lua tests/integration/neighborhood_completion_spec.lua
git commit -m "#181: complete paths across read roots"
```

### Task 6: Attach completion once from `prep_md`

**Files:**
- Modify: `lua/parley/init.lua`
- Modify: `lua/parley/neighborhood.lua`
- Test: `tests/integration/neighborhood_completion_spec.lua`

- [ ] **Step 1: Write failing attachment lifecycle tests**

In fresh-buffer cases, reset/unregister the global test source and reset all
counters in `before_each`, then unregister/reset it again in `after_each` so no
test depends on order. Instrument scheduling,
`cmp.register_source`, and `cmp.setup.buffer`. The guard must be set before
scheduling or autocmd creation. Named test `prep_md attaches one completion
lifecycle` must observe after initial flush: global registration=1, buffer
setup=1, autocmd=1; repeated `prep_md`: unchanged 1/1/1. Named test `prep_chat
inherits one markdown attachment` uses a fresh chat buffer and must observe one
setup and one autocmd for that buffer while global registration stays 1. First
synthetic InsertEnter MUST raise that buffer's setup to exactly 2 and remove the
once-autocmd; second InsertEnter stays 2. Assert sources contain one
`parley_path` and one `buffer`. Add separate cases: ordinary non-repo Markdown
gets no policy, source, autocmd, or cmp setup; a global chat still gets its
existing own-folder policy and one attachment.

- [ ] **Step 2: Run completion tests and verify RED**

Run: `make test-spec SPEC=providers/tool_use`

Expected: `prep_md attaches one completion lifecycle` fails with attached/setup
actual 0 versus expected 1; `prep_chat inherits one markdown attachment` fails
with `cmp.register_source` actual 0 versus expected 1 because the old adapter
configures cmp-path directly.

- [ ] **Step 3: Move attachment to the shared Markdown preparation seam**

Set `vim.b[buf].parley_completion_attached = true` before side effects. In
`prep_md`, call `neighborhood.attach_completion(buf)` only when
`config.repo_root` is nonblank. Keep the `prep_chat` call so global chats retain
today's completion; in repo mode the buffer guard makes that second call a
no-op. Register `parley_path` once globally, configure the buffer once on the
initial scheduled attach, and retain one one-shot InsertEnter retry for lazy cmp
loading. Repeated preparation returns the existing policy without new side
effects.

- [ ] **Step 4: Run completion tests and verify GREEN**

Run: `make test-spec SPEC=providers/tool_use`

Expected: exit 0 with the concrete registration/setup/autocmd counts above,
global-chat compatibility, zero attachment counts for ordinary non-repo
Markdown, and zero failed assertions.

- [ ] **Step 5: Commit all-Markdown attachment**

```bash
git add lua/parley/init.lua lua/parley/neighborhood.lua tests/integration/neighborhood_completion_spec.lua
git commit -m "#181: attach neighborhood completion to markdown"
```

## Chunk 4: Documentation and Full Verification

### Task 7: Update the codebase map and traceability

**Files:**
- Modify: `atlas/infra/repo_mode.md`
- Modify: `atlas/providers/tool_use.md`
- Modify: `atlas/traceability.yaml`
- Modify: `workshop/issues/000181-repo-root-read-wide-completion-for-all-markdown.md`

- [ ] **Step 1: Update repo-mode behavior**

Replace the singular #147 neighborhood description with the `RootPolicy` split: neighborhood-first read search, repo-root widening in repo mode, configured roots after it, narrow writes, collision precedence, all-Markdown attachment, and unchanged non-repo behavior.

- [ ] **Step 2: Update tool-use behavior**

Document that dispatcher read tools (`path`, `file_path`, `paths`, `default_path`) probe ordered roots and require existing targets, while write tools retain cwd-confined missing-leaf handling. Name chat and skill entry points.

- [ ] **Step 3: Update traceability**

Under `providers/tool_use`, retain/add `lua/parley/neighborhood.lua`,
`lua/parley/tools/dispatcher.lua`, `lua/parley/tool_loop.lua`,
`lua/parley/chat_respond.lua`, `tests/unit/neighborhood_spec.lua`,
`tests/unit/tools_dispatcher_spec.lua`, `tests/unit/tool_loop_spec.lua`,
`tests/unit/build_messages_spec.lua`, and
`tests/integration/neighborhood_completion_spec.lua`. Under
`skills/skill-system`, retain/add `lua/parley/neighborhood.lua`,
`lua/parley/skill_invoke.lua`, and `tests/integration/skill_invoke_spec.lua`.

- [ ] **Step 4: Append the implementation log**

Append a dated `## Log` entry citing how the shared policy/merger satisfied
`ARCH-DRY`, how pure construction was separated from filesystem/UI adapters for
`ARCH-PURE`, and how the consumer shadow sweep fulfilled `ARCH-PURPOSE`. Do not
tick the issue summary plan until Task 8 verification passes.

- [ ] **Step 5: Run the shadow sweep**

Run:

```bash
rg -n "tool_read_roots|read_roots|resolve_path_in_cwd|parley_neighborhood_root|Relative tool paths resolve|attach_completion" lua tests atlas README.md
rg -n "execute_call\(|root_policy|policy_for_buf" lua/parley/tool_loop.lua lua/parley/chat_respond.lua lua/parley/skill_invoke.lua lua/parley/tools/dispatcher.lua
rg -n "path_fields|file_path|paths|default_path|kind ~= \"write\"" lua/parley/tools/dispatcher.lua tests/unit/tools_dispatcher_spec.lua
rg -n "cmp-path|parley_path|completefunc|prep_md|prep_chat" lua tests atlas README.md
```

Expected: every `execute_call` entry point passes `root_policy`; dispatcher tests
cover all four path shapes and both read/write predicates; there are no
`parley_neighborhood_root`, repeated cmp-path-root, old singular-guidance, or
chat-only attachment matches outside explicit historical/test-fixture text.
`write_file`, `edit_file`, and `propose_edits` remain `kind = "write"` and enter
only the narrow resolver.

- [ ] **Step 6: Commit docs and traceability**

```bash
git add atlas/infra/repo_mode.md atlas/providers/tool_use.md atlas/traceability.yaml workshop/issues/000181-repo-root-read-wide-completion-for-all-markdown.md
git commit -m "#181: map read-wide neighborhood behavior"
```

### Task 8: Verify the complete change

**Files:**
- Verify all files changed by Tasks 1–7

- [ ] **Step 1: Run focused tests**

Run:

```bash
make test-spec SPEC=providers/tool_use
make test-spec SPEC=skills/skill-system
```

Expected: both exit 0; output contains no `Failures`/`Errors`, including
`neighborhood_spec`, `tools_dispatcher_spec`, `tool_loop_spec`,
`build_messages_spec`, `neighborhood_completion_spec`, and `skill_invoke_spec`.

- [ ] **Step 2: Run lint**

Run: `make lint`

Expected: exit 0.

- [ ] **Step 3: Run the full suite**

Run: `make test`

Expected: exit 0; this is the final green claim, not the focused specs alone.

- [ ] **Step 4: Check the complete changed-file set and diff**

Run:

```bash
git diff --check
git status --short
git diff --name-status origin/main...HEAD
git diff origin/main...HEAD
```

Expected: no whitespace errors; the unfiltered changed-file list includes the
#181 issue and durable plan plus intended `lua/`, `tests/`, and `atlas/` files
only. Pre-existing unrelated issue-file edits in the shared checkout remain
unstaged and absent from the branch diff.

- [ ] **Step 5: Update the verified issue record**

Only now tick all five `## Plan` rows in the issue and append the exact focused,
lint, full-suite, shadow-sweep, and diff evidence to the current dated log.

- [ ] **Step 6: Commit the verified issue record**

Run:

```bash
git add workshop/issues/000181-repo-root-read-wide-completion-for-all-markdown.md workshop/plans/000181-repo-root-read-wide-completion-for-all-markdown-plan.md
git commit -m "#181: complete verified implementation plan" -m "Record the passing focused and full verification only after every planned consumer, documentation update, and shadow sweep is complete." -m "Co-Authored-By: Codex <noreply@openai.com>"
```

Expected: commit succeeds and `git diff --cached --name-only` prints nothing.

- [ ] **Step 7: Close through SDLC**

Run `sdlc actual --issue 181`; copy its exact emitted `--actual N.NN` flag (the
value changes as work continues—do not reuse the planning-time measurement) into
the close command it prescribes:

```bash
sdlc close --issue 181 --actual <MEASURED_VALUE_EMITTED_BY_SDLC_ACTUAL> --verified 'make test-spec SPEC=providers/tool_use and SPEC=skills/skill-system passed; make lint and make test exited 0; root-policy consumer/path-shape/completion shadow sweeps found no stale parallel policy; git diff --check and unfiltered origin/main...HEAD review passed'
```

Use `--no-atlas` only if the atlas files truly required no update; this plan
expects atlas changes, so the normal atlas gate should pass. Fix all
Critical/Important findings from the binary-owned fresh-context boundary review,
rerun the affected focused/full verification and shadow sweeps, and retry close.
Successful close leaves the issue `codecomplete`; publishing performs `done`.

- [ ] **Step 8: Commit close artifacts and inspect handoff state**

After a final `SHIP` verdict, run:

```bash
git status --short
git diff --check
git add workshop/issues/000181-repo-root-read-wide-completion-for-all-markdown.md workshop/plans/000181-*
git commit -m "#181: close read-wide neighborhood completion" -m "Review-Verdict: SHIP" -m "Co-Authored-By: Codex <noreply@openai.com>"
git diff --check
sdlc state
```

Expected: the close commit contains only #181 issue/plan/review artifacts;
`sdlc state` reports #181 `codecomplete` with no workflow drift. Pre-existing
unrelated issue edits may remain unstaged in the shared checkout. Hand the
verified branch to the finishing-development workflow for `sdlc pr` / `sdlc
merge` rather than pushing manually.

## Revisions

### 2026-07-10 — plan-review feasibility and execution fixes

Reason: chunk reviews found repeated cmp-path sources infeasible, canonical path
derivation mislabeled as pure, implicit pipeline seams, vague attachment
idempotence, and non-executable verification placeholders.

Delta: replaced cmp-path with one Parley cmp source over the shared merger;
separated pure policy construction from filesystem adapters; enumerated every
chat/skill seam; specified attachment counts; and made verification, shadow
sweeps, close evidence, and post-close handling executable.

### 2026-07-11 — guard all-markdown attachment by repo mode

Reason: `change-code` review caught that moving attachment unconditionally into
`prep_md` would expand behavior outside the issue's stated repo-mode scope.

Delta: `prep_md` attaches only with `config.repo_root`; `prep_chat` retains the
global-chat path and relies on the idempotence guard in repo mode. Tests pin
both unchanged non-repo cases.

### 2026-07-11 — close-review completion of the test matrix

Reason: the first close review exposed global-chat widening and implicit rather
than explicit root canonicalization, both missed by the initial tests.

Delta: repo-root inclusion is artifact-scoped, policy roots are realpath-first,
and the integration/security matrix now covers global chats in repo mode,
ordinary repo/non-repo Markdown, repeat attachment, absolute reads, and symlink
escape behavior.
