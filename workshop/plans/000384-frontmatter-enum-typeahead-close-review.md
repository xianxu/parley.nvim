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

---

## Re-review — 2026-10-18T02:01:54-07:00 (SHIP)

| field | value |
|-------|-------|
| issue | 384 — Frontmatter typeahead for enum values (collaboration-mode first, generic registry) |
| repo | parley.nvim |
| issue file | workshop/issues/000384-frontmatter-enum-typeahead.md |
| boundary | whole-issue close |
| milestone | — |
| window | 48d7874c658aa3a0bc60f27cfb2216bcc2dc510c..9e3ea59d8048877d821f8b18a8af690530a5c02b |
| command | sdlc close --issue 384 |
| reviewer | claude |
| isolation | fenced |
| timestamp | 2026-10-18T02:01:54-07:00 |
| verdict | SHIP |

## Review

Inspected the diff; now running the specs to verify the claimed fixes.

Still running the affected specs (retrying without `timeout`, which macOS lacks).

Let me use the Makefile's own target instead.

Specs pass. Now reverting the BR-1 symlink fix to confirm its regression test goes red.

Checking an existing issue-file classifier in `init.lua` that the new `applies` may duplicate.

```verdict
verdict: SHIP
confidence: medium
```

All five findings from round 1 are fixed, and I checked each fix against the code or a test rather than the commit messages. Both specs that cover this feature pass (`make test-spec SPEC=ui/frontmatter_typeahead`: 7 integration and 9 unit). I also ran `issues_spec`, `issue_vocabulary_spec` and `issue_unavailable_spec`. For BR-1 I put the symlink fix back to its old form in the disposable checkout: the spec "matches an issue file reached through a symlinked workspace" then failed, and it passed again once I restored the file. The working tree is clean.

I raise two new findings, both Minor, so neither blocks SHIP. One is a repeat in the `stub-without-conformance` family, the other in `path-canonicalization-before-prefix-match`. For each I state the rule that covers the family, as the escalation asks. Confidence is medium for one reason: I did not run `scripts/check-frontmatter-cmp.lua`. It loads the operator's real Neovim config, and that is outside a read-only review sandbox. The claim that it "fails with the cmp branch removed" therefore rests on reading the script, not on a run.

**1. Strengths**
- **One list for the modes.** `collaboration.lua:7` exports `M.modes`, and the resolver's `known` set and its `bad_mode` message are both built from it. The unit spec checks this through the resolver itself: every mode resolves and `nope` fails. It does not just compare two copies of the list.
- **Clean pure core.** `context` and `candidates` (`frontmatter_enum.lua:58-78`) take lines and a path and do no IO. They are unit-tested with no buffer, and the declarations are scoped so tests don't leak.
- **Works with cmp.** `with_source` puts the parley source in its own first group, never replaces the buffer's sources, and is re-added when a host config resets them. The source reports itself unavailable outside the frontmatter, so cmp behaves as before everywhere else.
- **Dead code is gone.** `omnifunc`, `setup_issue_completion`, `complete_frontmatter_values` and `enumerable_values` are deleted. A grep finds no remaining references in `lua/`, `tests/`, `scripts/` or `atlas/`.
- **Typing stays bounded.** `SCAN_LINES` caps how much of the buffer is read on each keystroke (`frontmatter_enum.lua:81`).

**2. Critical findings:** none.

**3. Important findings:** none.

**4. Minor findings**
- **Live cmp check isn't a make target** (`stub-without-conformance`, 2nd). `scripts/check-frontmatter-cmp.lua` exists, but nothing in `Makefile.parley` or its help lists it. The repo's other conformance checks are all `make check-*-conformance` targets.
  - Rule: every stub of an external dependency gets its conformance check as a named `make check-*-conformance` target in the help list.
  - Fix: add a `check-frontmatter-cmp-conformance` target.
- **Second "is this an issue file?" check** (`path-canonicalization-before-prefix-match`, 2nd). The `status` declaration's `applies` (`frontmatter_enum.lua:197-211`) repeats the resolve-then-prefix logic that `detect_buffer_context` already has (`init.lua:~1662`).
  - Rule: whether a path lies inside a configured directory is decided in one place. That helper resolves symlinks on both sides and compares against `dir .. "/"`.
  - Prevalence: 16 `resolve(fnamemodify(...))` sites in `lua/`.
  - Fix for this issue: an `issues.is_issue_file(path)` that both callers use. The wider sweep is separate work.

**5. Test coverage notes**
- **cmp stub.** It keeps state between calls (registered sources, buffer sources, a count of `complete` calls) and covers ordering: the source goes first, `complete` fires only on the first add, it is unavailable in the body, and the Vim popup is used when cmp is disabled.
- **Not covered.** No spec checks that `real()` handles a buffer whose file does not exist yet (a new file). The symlink spec happens to cover this, because `000001-x.md` is never created.

**6. Architectural notes**
- **ARCH-DRY:** flagged; see the second Minor finding. The mode list itself is single-source.
- **ARCH-PURE:** passes. The IO is limited to `at_cursor`, `active_cmp` and `ensure_cmp`.
- **ARCH-PURPOSE:** passes. Both consumers read their values from the module that enforces them, and `presentation` is correctly left to #383.
- **ARCH-MOCK:** passes, with the first Minor finding about wiring the live check into make.
- **ARCH-CONSTRAINTS:** passes. Each insert-mode keystroke in a markdown or chat buffer, plus each cmp `is_available` call, reads at most 500 lines. An optional speed-up: return early when the current line isn't a declared `key:` line, before reading the buffer.
- **ARCH-SECURE:** passes. The only inputs are buffer names and the vocabulary, and no secrets are involved.
- **ARCH-ORDER:** passes. The state is one module-level `registered` flag and one buffer flag set once; a host resetting the buffer's sources is handled by re-adding the source on each change.
- **ARCH-FUNERAL:** passes. The script deletes its temporary directory, and the buffer-level cmp sources disappear with the buffer.

**7. Plan revision recommendations:** none. The Plan, the Spec bullet, the Revisions entries and the atlas page all match the shipped mechanism.

```findings
dispose:
  - id: BR-1
    disposition: addressed
    note: |
      real() resolves both sides (frontmatter_enum.lua:31). Reverting it in the disposable checkout fails the symlinked-workspace spec, and restoring it passes.
  - id: BR-2
    disposition: addressed
    note: |
      The Spec bullet, the Plan Integration bullet (cmp source plus Vim fallback, no omnifunc), the Revisions entries and the header comment at frontmatter_enum.lua:4-5 all match the code.
  - id: BR-3
    disposition: addressed
    note: |
      complete_frontmatter_values and enumerable_values are deleted, a grep finds no remaining references, and their tests now go through status_values() and the registry.
  - id: BR-4
    disposition: addressed
    note: |
      M.undeclare was added, the unit spec's after_each tears down both test keys, and a spec checks keys() afterwards.
  - id: BR-5
    disposition: addressed
    note: |
      scripts/check-frontmatter-cmp.lua is a repeatable live check against the real cmp, documented in atlas. Not run here because it loads the operator's config; its make wiring is raised as a new Minor finding.
findings:
  - id: new
    severity: Minor
    kind: defect
    family: stub-without-conformance
    title: |
      Live cmp conformance script is not a make check-*-conformance target
    detail: |
      2nd in family. Rule: every stub of an external dependency gets its conformance check as a named make check-*-conformance target in the Makefile.parley help, as with the sdlc and couch checks. Add check-frontmatter-cmp-conformance running scripts/check-frontmatter-cmp.lua.
  - id: new
    severity: Minor
    kind: defect
    family: path-canonicalization-before-prefix-match
    title: |
      status applies() re-implements the issue-file check from init.lua detect_buffer_context
    detail: |
      2nd in family. Rule: whether a path is inside a configured directory is decided by one helper that resolves both sides and compares with a trailing separator. Prevalence: 16 resolve(fnamemodify) sites in lua/. For this issue, add issues.is_issue_file(path) and use it from frontmatter_enum.lua and from init.lua around line 1662.
```

<!-- sdlc-review-usage [{"version":1,"intent":{"disposable_root":true,"id":"a5341ddc-e057-462e-a48c-d01a6526bbec","repository":"github.com/xianxu/parley.nvim","issue_id":"000384","recipe":"milestone-review","round":2,"attempt":1,"agent":"claude","root":"/Users/xianxu/Library/Caches/sdlc/review-checkouts/d0542d1c0f803c5c","reviewed_head":"9e3ea59d8048877d821f8b18a8af690530a5c02b","slot":"parley.nvim:3","requested_at":"2026-10-18T08:59:06.585637Z"},"phase":"finished","pid":24601,"started_at":"2026-10-18T08:59:06.894225Z","finished_at":"2026-10-18T09:01:53.268347Z","session_id":"80ae0c69-c096-42f2-8e2f-ee655e3fa1d0","outcome":"returned"}] -->
