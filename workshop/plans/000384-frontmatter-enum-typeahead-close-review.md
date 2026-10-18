# Boundary Review — parley.nvim#384 (whole-issue close)

| field | value |
|-------|-------|
| issue | 384 — Frontmatter typeahead for enum values (collaboration-mode first, generic registry) |
| repo | parley.nvim |
| issue file | workshop/issues/000384-frontmatter-enum-typeahead.md |
| boundary | whole-issue close |
| milestone | — |
| window | 48d7874c658aa3a0bc60f27cfb2216bcc2dc510c..2ebbd9e0c3dda31b52ba9d7df1a2c4a29af88f7e |
| command | sdlc close --issue 384 |
| reviewer | claude |
| isolation | fenced |
| timestamp | 2026-10-18T01:29:30-07:00 |
| verdict | FIX-THEN-SHIP |

## Review

Checking the vocabulary API, then running the specs.

Running the new specs headlessly.

```verdict
verdict: FIX-THEN-SHIP
confidence: medium
```

**Verdict: fix then ship.** The single registry works. `collaboration-mode` takes its values from `collaboration.modes`, so its typeahead and the resolver share one list. `status` now uses the same registry, and the dead `omnifunc` and `setup_issue_completion` are removed. With nvim-cmp the values come through a cmp source; without it, Vim's own popup opens. I ran `make test-spec SPEC=ui/frontmatter_typeahead` and both specs pass, 7 tests each. Two things should be fixed before shipping:
- **Symlinked paths:** the new `applies` check for `status` no longer resolves symlinks, which the deleted `init.lua` code did. Issue files opened through a symlinked path will lose `status:` completion.
- **Stale Spec and Plan:** they still describe an omnifunc fallback that doesn't exist. The Plan's Integration bullet doesn't mention the cmp source that was actually shipped.

### 1. Strengths
- `lua/parley/skills/review/collaboration.lua:7-9`: `M.modes` is the one list. Both `known` and the bad-mode message are built from it. `tests/unit/frontmatter_enum_spec.lua:49-58` checks that typeahead and the resolver agree.
- `M.context` and `M.candidates` are pure and tested without a buffer. The IO part (`at_cursor`, `attach`) is small (ARCH-PURE).
- The cmp design is careful. The source gets its own lower `group_index` and is unavailable outside a frontmatter value, so cmp's other sources behave as before. `cmp.complete()` runs only when the source has just been added. The Vim popup is still used when cmp is disabled for the buffer.
- Reading is capped at 500 lines per keystroke (`SCAN_LINES`), which is an explicit limit (ARCH-CONSTRAINTS).
- The atlas page, index entry, traceability mapping and issue-management cross-link are all added.

### 2. Critical findings
None.

### 3. Important findings
- **`status` completion no longer resolves symlinks** (`lua/parley/frontmatter_enum.lua:30-33`).
  - **What changed:** the deleted `init.lua` block called `vim.fn.resolve()` on both the issues dir and the file's directory. The new `applies` compares the raw `nvim_buf_get_name` against `get_issues_dir()`, which is built from `getcwd()`'s git root.
  - **Effect:** if the cwd or the file path goes through a symlink (`~/workspace` → elsewhere, or `/tmp` vs `/private/tmp` on macOS), issue files silently lose `status:` completion. No test covers this.
  - **Fix:** apply `vim.fn.resolve(vim.fn.fnamemodify(..., ":p"))` to both sides before the prefix check. Add an integration case that uses a symlinked dir.
- **Spec and Plan don't match the shipped mechanism** (ARCH-PURPOSE).
  - The Spec says typeahead is "available … through omnifunc as a fallback". No omnifunc exists.
  - The module header (`frontmatter_enum.lua:4`) says "attach wires them to omnifunc and nvim-cmp".
  - The Plan's Integration bullet says only the TextChangedI popup is used. The first Log entry says "no nvim-cmp source or omnifunc is added", and a later Log entry reverses that.
  - **Fix:** add a Revisions entry and correct the header comment.

### 4. Minor findings
- **ARCH-DRY / ARCH-FUNERAL:** `issues.complete_frontmatter_values` (`issues.lua:210`) has no production caller now; only tests use it. It repeats the prefix filter in `M.candidates`. Either delete it, moving its tests to the registry, or have the `status` declaration go through it.
- **Test isolation:** the unit spec declares `test-mode` and `test-scoped` in the module-global registry and never removes them, so later specs that check `M.keys()` will see them. There is no `undeclare`.
- **ARCH-MOCK:** the cmp path is tested only against a hand-written stub (`get_config().enabled`, `setup.buffer`, `register_source`). The real-config check was manual and is recorded only in the Log. A stub in this form will not notice changes to the cmp API.

### 5. Test coverage notes
- The pure context and candidate logic is well covered: inside and outside frontmatter, undeclared keys, missing closing `---`, not at the top, prefix filtering and `applies`.
- The integration spec covers the Vim popup path, attaching only once, the markdown setup hook, and the cmp stub paths.
- Gaps:
  - the symlink path case from the first Important finding;
  - attachment through `prep_chat` (only `setup_markdown_keymaps` is checked);
  - mixed-case keys, e.g. `Collaboration-Mode:`.

### 6. Architectural notes
Each principle checked:
- **ARCH-DRY:** passes for the main design. The orphaned helper above is the one gap.
- **ARCH-PURE:** passes.
- **ARCH-PURPOSE:** passes. Every consumer of the modes list reads `M.modes`. The Spec drift is a documentation problem, not a missing consumer.
- **ARCH-MOCK:** flagged as Minor (stub only).
- **ARCH-CONSTRAINTS:** passes. Work per keystroke is capped at 500 lines and the frontmatter parse stops at the closing `---`.
- **ARCH-SECURE:** N/A. The only input is buffer text the user is editing, and no secrets are involved.
- **ARCH-ORDER:** passes. The only state is the module flag `registered` and the buffer flag `b:parley_frontmatter_enum`. Both are set once and never reset, and re-adding cmp sources is idempotent through `with_source`.
- **ARCH-FUNERAL:** nothing durable is created. The autocmd and the cmp buffer source go away with the buffer.

For #383, `presentation` can join with one `M.declare`, as the Spec intends.

### 7. Plan revision recommendations
- Add "## Revisions — 2026-10-18: Integration is a TextChangedI popup through `helper.complete_noselect` when cmp is absent or disabled, and a `parley_frontmatter` cmp source (own lower group, re-added on change) when cmp is active. The Spec's omnifunc fallback is dropped because the Vim popup covers the no-cmp case." Then update the Integration checkbox to match.

```findings
findings:
  - id: new
    severity: Important
    kind: defect
    family: path-canonicalization-before-prefix-match
    title: |
      status applies() dropped the symlink resolution the deleted init.lua typeahead did
    detail: |
      frontmatter_enum.lua:30-33 compares the raw buffer name to get_issues_dir() (built from getcwd's git root) without vim.fn.resolve; the removed init.lua block resolved both sides. In a symlinked workspace, issue files silently lose status completion. Resolve both paths and add a symlinked-dir integration case.
  - id: new
    severity: Important
    kind: defect
    family: plan-spec-drift-from-shipped-mechanism
    title: |
      Spec promises an omnifunc fallback and the Plan's Integration bullet omits the cmp source that shipped
    detail: |
      No omnifunc exists. The frontmatter_enum.lua:4 header claims one, and the Plan bullet and first Log entry say no cmp source is added, which a later Log entry reverses. Add a Revisions entry describing the cmp source plus Vim-popup fallback, and fix the header comment.
  - id: new
    severity: Minor
    kind: defect
    family: orphaned-duplicate-helper
    title: |
      issues.complete_frontmatter_values has no production caller and repeats the candidates prefix filter
    detail: |
      issues.lua:210 is now used only by tests. Delete it and move its tests onto the registry, or have the status declaration go through it (ARCH-DRY, ARCH-FUNERAL).
  - id: new
    severity: Minor
    kind: defect
    family: test-global-state-leak
    title: |
      Unit spec declares test-mode/test-scoped into the global registry with no teardown
    detail: |
      M.keys() permanently includes the test keys for any later spec in the same process; there is no undeclare.
  - id: new
    severity: Minor
    kind: defect
    family: stub-without-conformance
    title: |
      cmp path is covered only by a hand-written stub of the nvim-cmp API
    detail: |
      get_config().enabled, setup.buffer and register_source semantics are assumed. The real-config check was manual and recorded only in the Log (ARCH-MOCK).
```

<!-- sdlc-review-usage [{"version":1,"intent":{"disposable_root":true,"id":"4c9dc90a-9f65-4ec5-8633-55c052871ee9","repository":"github.com/xianxu/parley.nvim","issue_id":"000384","recipe":"milestone-review","round":1,"attempt":1,"agent":"claude","root":"/Users/xianxu/Library/Caches/sdlc/review-checkouts/3df66a58c64a6a70","reviewed_head":"2ebbd9e0c3dda31b52ba9d7df1a2c4a29af88f7e","slot":"parley.nvim:3","requested_at":"2026-10-18T08:27:45.733548Z"},"phase":"finished","pid":42690,"started_at":"2026-10-18T08:27:45.829522Z","finished_at":"2026-10-18T08:29:27.695015Z","session_id":"a7f497bb-5ccd-4a61-acfe-6ad8487a5e3f","outcome":"returned"}] -->
