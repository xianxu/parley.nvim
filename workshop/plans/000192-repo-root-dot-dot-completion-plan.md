# Repo-Root Relative Paths with Dot-Dot Completion — Implementation Plan (#192)

> **For agentic workers:** Consult AGENTS.md Section 3 (Subagent Strategy) to determine the appropriate execution approach: use superpowers-subagent-driven-development (if subagents are suitable per AGENTS.md) or superpowers-executing-plans to implement this plan. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Relative paths in chat tools and completion resolve from exactly one base (the neighborhood write root); `tool_read_roots` becomes a pure permission boundary; `../ariadne/…` completes and resolves in typed form; parley's cmp attach survives host BufEnter clobbering.

**Architecture:** Collapse the ordered-roots read resolver (#181) into the existing single-base resolver `resolve_path_in_cwd` (which already implements resolve-against-cwd + confinement-to-roots) plus an existence check — one resolution mechanism for reads and writes (ARCH-DRY). Completion globs the write root only and labels by *textual* prefix-strip (glob echoes `..` verbatim), then filters every candidate through the same resolver, preserving #181's completion-matches-enforcement invariant.

**Tech Stack:** Lua (nvim plugin), plenary busted tests (`make -f Makefile.parley test-spec SPEC=…`), nvim-cmp buffer-local source.

---

## Design context (read first)

Two concepts, currently conflated, get separated:

- **Resolution base** — what a relative path *means*. Exactly one: `policy.write_root` (repo root in repo mode). Like a process cwd.
- **Permission boundary** — where a resolved realpath may *land*: `policy.read_roots` (write root + `tool_read_roots`-derived, default `{'../'}` → workspace parent). Like a sandbox allowlist. **Permission only — never a base.**

Key verified facts (from the design session, brain chat 2026-07-16):

- `dispatcher.resolve_path_in_cwd(path, cwd, allowed_roots)` already implements the target semantics: lexical normalize against cwd (collapses `..`), fs_realpath, confine to cwd ∪ allowed_roots. Reads differ from writes only in (a) extra allowed roots, (b) the path must *exist* (no new-file leaf synthesis).
- `vim.fn.glob("<root>/../ariadne/wo*")` returns matches with the `..` **textually preserved** (`<root>/../ariadne/workshop`), so stripping `<root>/` textually yields labels in the user's typed form. The current labeler (`relative_to_root`) normalizes first (`vim.fn.resolve` collapses `..`), which is exactly what kills `..` labels today.
- `neighborhood.attach_completion` guards with `parley_completion_attached` + a `once=true` InsertEnter, so a host config that re-runs `cmp.setup.buffer` on every BufEnter (the operator's does) displaces parley's source after any buffer switch. `schedule_cmp_attach` already runs via `vim.schedule`, so re-firing it on BufEnter deterministically wins over synchronous host autocmds.

Known breakage (accepted, loud): the accidental workspace-root-relative spelling (`ariadne/…` from a brain chat) stops resolving; the resolver error names the path and the `tool_read_roots` knob. #181's ordered-precedence tests flip to the new semantics.

## Core concepts

### Pure entities (the conceptual core)

| Name | Lives in | Status |
|------|----------|--------|
| `resolve_read_path` | `lua/parley/tools/dispatcher.lua` | modified |
| `completion_candidates` | `lua/parley/neighborhood.lua` | modified |
| `format_tool_context` | `lua/parley/neighborhood.lua` | modified |
| `relative_to_root` | `lua/parley/neighborhood.lua` | deleted |
| `merge_completion_candidates` | `lua/parley/neighborhood.lua` | deleted |

- **`resolve_read_path(path, cwd, read_roots)`** — read-side path resolver. New signature (was `(path, read_roots)`); becomes a thin wrapper: `resolve_path_in_cwd(path, cwd, read_roots)` + existence requirement (`fs_realpath(abs)` must succeed — covers both missing files and dangling symlinks, which `resolve_path_in_cwd` would otherwise leaf-synthesize).
  - **Relationships:** called by `dispatcher.execute_call` (read-kind tools, `path`/`file_path`/`paths` fields) and `neighborhood.completion_candidates` (candidate filter). 1 policy : N calls.
  - **DRY rationale:** deletes the second, parallel resolution algorithm (#181's ordered-roots loop). One mechanism (`resolve_path_in_cwd`) now serves reads and writes; reads differ only by allowed roots + existence.
  - **Future extensions:** per-tool extra roots would widen `read_roots` construction, not this function.
- **`completion_candidates(policy, base)`** — pure enumerate-and-filter. New shape: single glob `write_root .. "/" .. base .. "*"`; label = textual strip of `write_root .. "/"` prefix (guaranteed by glob-pattern construction); append `/` for directories; keep only labels the resolver accepts; sort for determinism.
  - **DRY rationale:** deletes multi-root glob/merge machinery (`relative_to_root`, `merge_completion_candidates`) — net code removal.
  - **Future extensions:** hidden-file filtering, result caps.
- **`format_tool_context(policy)`** — reworded contract sent to the chat LLM: relative paths resolve from `<write_root>`; reads may traverse (e.g. `../sibling/…`) but must stay within the listed roots; writes stay under the write root.

### Integration points (where pure meets the world)

| Name | Lives in | Status | Wraps |
|------|----------|--------|-------|
| `attach_completion` / `attach_cmp_completion` | `lua/parley/neighborhood.lua` | modified | nvim-cmp buffer config + autocmds |

- **`attach_completion(buf)`** — one-time setup (policy snapshot, `completefunc`, cmp source registration) stays guarded by `parley_completion_attached`; the cmp *buffer-config* assertion (`schedule_cmp_attach`) re-fires on every `BufEnter`/`InsertEnter` (drop `once`), so last-writer-wins races with host configs resolve deterministically in parley's favor (the `vim.schedule` inside runs after synchronous host autocmds).
  - **Injected into:** nothing — it is the IO shell around the pure candidate functions.
  - **Test surface:** integration spec with a stubbed `package.loaded.cmp` (existing pattern in `tests/integration/neighborhood_completion_spec.lua`). NOTE: the existing "repeat attach does not re-setup" assertion (spec lines ~147-151) flips: repeated attach now MAY re-run `cmp.setup.buffer` (idempotent overwrite); `register_source` still exactly once.

No new external services; no fakes needed beyond the existing cmp stub.

## Chunk 1: read resolver → single base + confinement

### Task 1: rewrite `resolve_read_path` (TDD)

**Files:**
- Modify: `lua/parley/tools/dispatcher.lua` (`resolve_read_path`, ~lines 122-151; header comment lines ~10-11; call sites ~281, ~310)
- Test: `tests/unit/tools_dispatcher_spec.lua` (replace `describe("resolve_read_path ordered roots (#181)")`, ~lines 198-274)

- [ ] **Step 1: Rewrite the #181 describe block to the new contract** — `describe("resolve_read_path single base + confinement (#192)")`. Reuse the block's existing tmpdir fixtures/helpers. Cases:

```lua
-- setup sketch (mirror the existing block's tmp scaffolding):
--   cwd  = <tmp>/repo          (write root; contains atlas/index.md)
--   sib  = <tmp>/sibling       (peer repo; contains docs/note.md)
--   out  = <tmp>/outside       (escapes all roots; contains secret.md)
--   roots = { cwd, <tmp> }     (permission set: write root + workspace parent)

it("resolves a cwd-relative path", function()
    assert.equals(real(cwd .. "/atlas/index.md"),
        dispatcher.resolve_read_path("atlas/index.md", cwd, roots))
end)
it("resolves ../sibling traversal within a permitted root", function()
    assert.equals(real(sib .. "/docs/note.md"),
        dispatcher.resolve_read_path("../sibling/docs/note.md", cwd, roots))
end)
it("does NOT resolve against non-base permission roots", function()
    -- workspace-root-relative spelling (old #181 fallback) must fail:
    local path, err = dispatcher.resolve_read_path("sibling/docs/note.md", cwd, roots)
    assert.is_nil(path)
    assert.matches("sibling/docs/note.md", err)
end)
it("rejects traversal escaping every permitted root, naming the knob", function()
    local path, err = dispatcher.resolve_read_path("../../etc/hosts", cwd, { cwd })
    assert.is_nil(path)
    assert.matches("tool_read_roots", err)
end)
it("rejects missing reads instead of synthesizing a leaf", function() ... end)       -- keep, new signature
it("accepts absolute paths inside roots and rejects symlink escapes", function() ... end) -- keep, new signature
it("rejects a dangling symlink without crashing", function() ... end)                 -- keep, new signature
```

- [ ] **Step 2: Run to verify the new tests fail** — `make -f Makefile.parley test-spec SPEC=unit/tools_dispatcher` — expect failures in the new describe block only (wrong-arity call treats `cwd` as `read_roots`).

- [ ] **Step 3: Implement** — replace the body of `resolve_read_path`:

```lua
--- Read-side resolver (#192): resolve `path` against `cwd` (the neighborhood
--- write root — the single base), confine the realpath to cwd ∪ read_roots,
--- and require the target to exist (reads never synthesize a new-file leaf).
--- Delegates base+confinement to resolve_path_in_cwd — one mechanism for
--- reads and writes; reads differ only by extra roots + existence.
function M.resolve_read_path(path, cwd, read_roots)
    local abs, err = M.resolve_path_in_cwd(path, cwd, read_roots or {})
    if not abs then
        return nil, err
    end
    if not vim.loop.fs_realpath(abs) then
        return nil, "read path not found: " .. path
    end
    return abs
end
```

Notes: passing `read_roots or {}` (never nil) keeps the escape error naming the `tool_read_roots` knob. The `fs_realpath(abs)` check rejects both missing files (leaf-synthesized by `resolve_path_in_cwd`) and dangling symlinks. Update the header comment table (line ~10): "ordered read roots" → "read base + confinement".

- [ ] **Step 4: Update the two `execute_call` call sites** (~281, ~310): `M.resolve_read_path(call.input[field], policy.write_root, roots)` (and same for the `paths` loop). `roots_for_def()` is unchanged.

- [ ] **Step 5: Run the full dispatcher spec** — `make -f Makefile.parley test-spec SPEC=unit/tools_dispatcher` — expect PASS, including the untouched `resolve_path_in_cwd` blocks and the `execute_call` policy-enforcement test (~line 261).

- [ ] **Step 6: Commit** — `#192: resolve reads from the write root; read roots are permission-only` (body: supersedes #181 ordered-roots resolution; why single-base).

## Chunk 2: completion in typed form

### Task 2: rewrite `completion_candidates` (TDD)

**Files:**
- Modify: `lua/parley/neighborhood.lua` (`completion_candidates` ~202-223; delete `relative_to_root` ~171-184 and `merge_completion_candidates` ~190-200)
- Test: `tests/integration/neighborhood_completion_spec.lua`, `tests/unit/neighborhood_spec.lua`

- [ ] **Step 1: Write failing integration tests.** In the integration spec, add a sibling repo next to `repo` (`tmpdir .. "/sibling"` with `docs/note.md`) and cases:

```lua
it("completes ../sibling traversal in typed form", function()
    local policy = { write_root = repo, read_roots = { repo, tmpdir } }
    assert.same({ "../sibling/" }, neighborhood.completion_candidates(policy, "../sib"))
    assert.same({ "../sibling/docs/" }, neighborhood.completion_candidates(policy, "../sibling/d"))
end)
it("filters traversal escaping the permitted roots", function()
    local policy = { write_root = repo, read_roots = { repo } } -- tmpdir NOT permitted
    assert.same({}, neighborhood.completion_candidates(policy, "../sib"))
end)
it("no longer offers non-base root-relative candidates", function()
    local policy = { write_root = repo, read_roots = { repo, tmpdir } }
    assert.same({}, neighborhood.completion_candidates(policy, "sibling/"))
end)
```

The existing escape/dangling test (~line 100) keeps its assertions (`{}` both) — it now passes via write-root glob + resolver filter.

- [ ] **Step 2: Run to verify failure** — `make -f Makefile.parley test-spec SPEC=integration/neighborhood_completion` — the `../sib` cases fail (empty today).

- [ ] **Step 3: Implement** — replace `completion_candidates`; delete `relative_to_root` and `merge_completion_candidates`:

```lua
function M.completion_candidates(policy, base)
    if not policy or not policy.write_root then
        return {}
    end
    local root = policy.write_root
    local resolver = require("parley.tools.dispatcher").resolve_read_path
    local items = {}
    -- Glob echoes the pattern prefix verbatim (".." survives textually), so
    -- stripping "<root>/" yields labels in the exact form the user typed.
    for _, match in ipairs(vim.fn.glob(root .. "/" .. (base or "") .. "*", false, true)) do
        local label = match:sub(#root + 2)
        if label ~= "" then
            if vim.fn.isdirectory(match) == 1 then
                label = label .. "/"
            end
            if resolver(label:gsub("/$", ""), root, policy.read_roots) then
                items[#items + 1] = label
            end
        end
    end
    table.sort(items)
    return items
end
```

- [ ] **Step 4: Update the unit spec** — in `tests/unit/neighborhood_spec.lua`, delete the `merge_completion_candidates` test (~134-138). `build_policy`/`policy_for_path` tests are unchanged (read_roots still computed the same way — they just mean permission now).

- [ ] **Step 5: Run both specs** — `make -f Makefile.parley test-spec SPEC=integration/neighborhood_completion` and `SPEC=unit/neighborhood` — expect PASS.

- [ ] **Step 6: Commit** — `#192: complete dot-dot traversal in typed form from the write root`.

### Task 3: reword `format_tool_context` (TDD)

**Files:**
- Modify: `lua/parley/neighborhood.lua` (`format_tool_context` ~137-143)
- Test: `tests/unit/neighborhood_spec.lua` (~122-132)

- [ ] **Step 1: Update the unit test** to the new wording:

```lua
it("formats guidance from the policy", function()
    assert.equals(table.concat({
        "Relative paths resolve from: /repo/data",
        "Reads may traverse outside it (e.g. ../sibling/file) but must stay within:",
        "- /repo/data",
        "- /repo",
        "Relative writes resolve only from: /repo/data",
    }, "\n"), neighborhood.format_tool_context({
        write_root = "/repo/data",
        read_roots = { "/repo/data", "/repo" },
    }))
end)
```

- [ ] **Step 2: Run to verify failure**, **Step 3: implement the matching wording**, **Step 4: run to PASS** — `make -f Makefile.parley test-spec SPEC=unit/neighborhood`.
- [ ] **Step 5: Commit** — `#192: tool context states single-base + confinement contract`.

## Chunk 3: deterministic cmp attach

### Task 4: re-assert cmp buffer config on BufEnter (TDD)

**Files:**
- Modify: `lua/parley/neighborhood.lua` (`attach_completion` ~308-326)
- Test: `tests/integration/neighborhood_completion_spec.lua` (~114-156)

- [ ] **Step 1: Update + add integration tests** (stubbed cmp, existing pattern):
  - Flip the repeat-attach assertion (~147-151): after `neighborhood.attach_completion(buf)` + `vim.wait`, assert `register_count == 1` still, but drop/replace the `setup_count` equality — re-attach may re-run `cmp.setup.buffer`.
  - Add:

```lua
it("re-asserts the parley buffer config on BufEnter", function()
    -- ... stub cmp as in the previous test, prep chat, wait for first capture ...
    captured = nil
    vim.api.nvim_exec_autocmds("BufEnter", { buffer = buf })
    vim.wait(100, function() return captured ~= nil end)
    assert.is_not_nil(captured)  -- parley re-asserted after a host would have clobbered
    assert.same({ "parley_path", "buffer" },
        { captured.sources[1].name, captured.sources[2].name })
    assert.equals(1, register_count)
end)
```

- [ ] **Step 2: Run to verify the new test fails** (current InsertEnter autocmd is `once` and BufEnter isn't wired).
- [ ] **Step 3: Implement** — in `attach_completion`, replace the `once=true` InsertEnter autocmd with a persistent re-assert:

```lua
-- Re-assert the cmp buffer config on every entry: host configs that call
-- cmp.setup.buffer on BufEnter (e.g. a global markdown path-completion
-- autocmd) would otherwise displace the parley source after a buffer
-- switch. schedule_cmp_attach runs via vim.schedule, so it lands after
-- all synchronous autocmd handlers — parley deterministically wins.
vim.api.nvim_create_autocmd({ "BufEnter", "InsertEnter" }, {
    buffer = buf,
    callback = function()
        schedule_cmp_attach(buf)
    end,
})
```

The one-time parts (policy snapshot, `completefunc`, `parley_root_policy`, source registration guard) stay under the existing `parley_completion_attached` guard.

- [ ] **Step 4: Run the integration spec to PASS.**
- [ ] **Step 5: Commit** — `#192: re-assert cmp buffer config on BufEnter` (body: names the host-clobber race).

## Chunk 4: verification + closeout

### Task 5: full suite, live verification, atlas, log

- [ ] **Step 1: Full test run** — `make -f Makefile.parley test` — expect PASS (unit parallel + integration sequential). Fix any spec touching the old resolver signature that the greps below surface:
  - `grep -rn "resolve_read_path" lua/ tests/` — every call must pass `(path, cwd, roots)`.
  - `grep -rn "merge_completion_candidates\|relative_to_root" lua/ tests/` — zero hits.
- [ ] **Step 2: Live verification in the real brain chat** (the issue's motivating case): open `brain/workshop/parley/2026-07-16.16-38-57.920.md` in nvim, insert mode, type `../ariadne/` → expect ariadne entries offered as `../ariadne/<name>` and segment-continuation; switch to another buffer and back, retype → still parley completion (not host cmp-path). Then ask the chat "tell me about ../ariadne/" → the `ls` tool call must succeed. Record the observed results in `## Log`.
- [ ] **Step 3: Atlas** — update `atlas/infra/repo_mode.md` ("Reference neighborhood (#147)" section: ordered-roots + first-existing-match prose → single-base + confinement; completion = write-root glob, typed-form labels) and `atlas/providers/tool_use.md` (root-policy scope bullet, ~lines 63-66: same rewrite). Atlas holds current state only — replace the stale prose, don't append history.
- [ ] **Step 4: Issue bookkeeping** — tick `## Plan` boxes in the issue, append a `## Log` session entry, set `estimate_hours` already present (set before change-code).
- [ ] **Step 5: Close** — `sdlc close --issue 192 --verified '<test + live-verification evidence>'` (actual measured by the binary; boundary review auto-dispatched by close — fix Critical/Important before crossing).
