# Boundary Review — parley.nvim#192 (whole-issue close)

| field | value |
|-------|-------|
| issue | 192 — repo-root relative paths with dot-dot completion |
| repo | parley.nvim |
| issue file | workshop/issues/000192-repo-root-relative-paths-with-dot-dot-completion.md |
| boundary | whole-issue close |
| milestone | — |
| window | 3e1a4c373b7b038fc221330fa029b31a2605ba40..HEAD |
| command | sdlc close --issue 192 |
| reviewer | claude |
| timestamp | 2026-07-16T18:12:37-07:00 |
| verdict | SHIP |

## Review

```verdict
verdict: SHIP
confidence: medium
```

**Summary.** The diff delivers exactly what #192's Spec commits to: `resolve_read_path` collapses the #181 ordered-roots resolver into a thin wrapper over `resolve_path_in_cwd` (single base = write root, `read_roots` demoted to a pure confinement set, up-front existence check that names the path as typed); `completion_candidates` globs the write root only with textual prefix-strip so `..` survives in typed form, filtered through the real resolver so completion offers exactly what reads accept; `format_tool_context` states the new contract; and the cmp buffer config re-asserts on BufEnter via `vim.schedule` (beating synchronous host clobbers) without re-registering the source. Both call sites in `execute_call` (single fields and the `paths` array) pass `policy.write_root`, and every producer of `root_policy` (`tool_loop`, `skill_invoke`, `chat_respond`, the `opts.cwd` fallback) routes through `policy_for_buf`/`policy_from_roots`, which guarantee a canonical `write_root` or a nil policy — no nil-cwd path into the new signature. All specs that pinned the old behavior (dispatcher, tool_loop, skill_invoke, build_messages, neighborhood) were flipped, and my greps confirm zero stale old-signature calls or old-contract wording in `lua/`, `tests/`, or `atlas/`. Both atlas files were reconciled in-range. One caveat on confidence: **the Bash tool is disabled at the harness level in this review session (EPERM on every command, sandboxed or not), so I could not independently execute the suite** — the Log's "161 specs PASS" is corroborated by line-level inspection of every changed spec against the implementation, but not by an independent run. Findings are all Minor; nothing blocks the boundary.

## 1. Strengths

- **Real consolidation, not a rename** (ARCH-DRY): `resolve_read_path` (dispatcher.lua:129-139) deletes an entire parallel resolution algorithm and delegates base+confinement to `resolve_path_in_cwd`; `relative_to_root` and `merge_completion_candidates` are gone with their tests. Net semantics got simpler *and* the code got smaller.
- **Error-message contract treated as API**: the plan's message table (per not-found flavor vs. confinement vs. bad input) is implemented exactly, and the up-front `fs_realpath(joined)` check (dispatcher.lua:135) is precisely what makes all three not-found flavors report the path *as typed* rather than leaking `resolve_path_in_cwd`'s "cannot resolve parent directory: <abs>" — the subtle case both plan reviews flagged, handled correctly.
- **Completion derives from enforcement**: `completion_candidates` (neighborhood.lua:195) filters every candidate through the actual `resolve_read_path`, preserving the #181 completion-matches-enforcement invariant under the new semantics — confirmed by the escape-filter and dangling-symlink tests asserting `{}` with no fallback.
- **Tests pin the breakage, not just the feature**: `tool_loop_spec.lua:281-288` asserts the bare `README.md` spelling now *fails* with the exact new error, in the same test that proves the traversal spelling succeeds and writes stay narrow — the loud-breakage commitment from the Spec is pinned, not just claimed.
- **Test-race hygiene**: the BufEnter re-assert test asserts `register_count` deltas with an in-test CAUTION about the module-local `cmp_registered` one-shot, and the corresponding lesson was recorded in `workshop/lessons.md` — the self-improvement loop actually ran.

## 2. Critical findings

None.

## 3. Important findings

None.

## 4. Minor findings

- `neighborhood.lua:189` — the typed `base` is interpolated raw into `vim.fn.glob()`, so glob-magic characters in the token (`[`, `?`, `{`) alter matching. Pre-existing (the old per-root code did the same), not a #192 regression; note for a future hardening pass.
- `neighborhood.lua:300` — the "parley deterministically wins" comment holds only against *synchronous* host autocmds; a host config that itself defers via `vim.schedule` from a later-registered autocmd would still win. The motivating case (synchronous `cmp.setup.buffer` on BufEnter) is covered; worth remembering if the nondeterminism ever reappears.
- `dispatcher.lua:133-134` duplicates the absolute-vs-relative join expression from `resolve_path_in_cwd:74-79` (ARCH-DRY, residual). Justified by the error-naming rationale, but a tiny shared `join_lexical(path, cwd)` would remove the last copy.
- Cosmetic staleness: `tests/unit/neighborhood_spec.lua:90` — the describe title "orders neighborhood, repo, and configured roots first-wins" still speaks the ordered-roots vocabulary; the test itself (root *construction* order/dedup) remains valid, only the framing is pre-#192.
- Harmless TOCTOU: a file deleted between `resolve_read_path`'s existence check and `resolve_path_in_cwd`'s realpath would leaf-synthesize an abs path for a now-missing file; the tool then errors on open. Not worth code.

## 5. Test coverage notes

- The new dispatcher block covers every row of the plan's error-message table: cwd-relative success, traversal success, non-base rejection (with the exact typed-path message), confinement escape naming the `tool_read_roots` knob (correctly targeting an *existing* file so the right branch fires), missing read, absolute-inside + symlink escape, dangling symlink. Completion covers typed-form `..`, segment continuation, escape filtering, non-base filtering, and BufEnter re-assert with register-delta discipline. The `paths`-array error path is updated at `tools_dispatcher_spec.lua:578`.
- Small gap (non-blocking): no direct test of an *absolute existing* path outside all roots through `resolve_read_path` — that branch is exercised only via the relative symlink escape; confinement of absolutes is otherwise covered by the #140 `resolve_path_in_cwd` block it delegates to.
- I could not execute the suite (Bash disabled in this session, harness-level EPERM even for `echo`). Assertions were verified line-by-line against the implementation instead; the close runner should confirm one green `make -f Makefile.parley test` on the close commit.

## 6. Architectural notes (ARCH markers, explicit)

- **ARCH-DRY — pass.** The diff is a textbook consolidation: one resolution mechanism (`resolve_path_in_cwd`) now serves reads and writes, reads differing only by extra roots + existence; the completion merge machinery is deleted outright. Residual join-expression duplication noted above (Minor).
- **ARCH-PURE — pass, with a classification note.** No business logic moved into IO handlers; the resolvers are the thin fs seam by nature, and completion's labeling logic is a few lines around the glob. However, the plan's Core-concepts table lists `resolve_read_path` and `completion_candidates` under "Pure entities" while both inherently touch the filesystem (`fs_realpath`, `glob`, `isdirectory`) and their tests create real tmpdir fixtures. This does not meet the Critical bar (no mocks are needed; the tests are direct and deterministic; there is no hidden pure core to extract — the function *is* fs resolution), but the label is drifted — see plan revision below.
- **ARCH-PURPOSE — pass.** Shadow-sweep of the single-base contract's consumers: dispatcher `path`/`file_path` fields ✓, `paths` array ✓, completion (derives via the actual resolver, not a restatement) ✓, LLM guidance (`format_tool_context`, reworded + pinned by test) ✓, atlas (`infra/repo_mode.md`, `providers/tool_use.md`, both rewritten in-range) ✓, and the accepted breakage is loud with the path named in the error. Nothing that is the point of the issue was deferred as follow-up. The known-consistent quirk (`../../blogs/` completing because the symlink target lands inside the permitted root) is enforcement-derived, not a hole, and is recorded in the Log.

## 7. Plan revision recommendations

- **Tick or annotate Chunk 4 / Task 5 steps 1–4** in `workshop/plans/000192-repo-root-dot-dot-completion-plan.md:313-319`: they remain `- [ ]` while the issue's `## Plan` marks Task 5 `[x]` and the Log records the full-suite run, live brain/ariadne verification, and the atlas sweep as done. The work is delivered; the plan artifact just doesn't say so. Step 5 (close) legitimately stays open until the gate.
- **Add a `## Revisions` entry reclassifying the Core-concepts table**: `resolve_read_path` and `completion_candidates` are filesystem-boundary entities (tested directly against real tmpdirs), not PURE-by-definition — either rename the section ("conceptual core" is already the honest hedge) or move them to the integration table so the table stops claiming a kind the code doesn't have (ARCH-PURE).
