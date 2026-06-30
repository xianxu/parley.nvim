# Boundary Review — parley.nvim#116 (whole-issue close)

| field | value |
|-------|-------|
| issue | 116 — datatype-aware navigation and creation via descriptor |
| repo | parley.nvim |
| issue file | workshop/issues/000116-datatype-aware-navigation-and-creation-via-descriptor.md |
| boundary | whole-issue close |
| milestone | — |
| window | d88253495875b33126daac086c3c2ae41ec57fc0..HEAD |
| command | sdlc close --issue 116 |
| reviewer | claude |
| timestamp | 2026-06-30T15:49:19-07:00 |
| verdict | FIX-THEN-SHIP |

## Review

I have a complete picture. Tests for the four #116 specs pass cleanly (issues 100, vocab 10, registry 17, builder 11), lint is 0/0/237, the one failing suite test (`tools_builtin_find_spec`) is pre-existing parallel-execution flakiness in a file the window doesn't touch. One real defect surfaced: a duplicate `get_history_dir`.

VERDICT: FIX-THEN-SHIP (confidence: high)

```verdict
verdict: FIX-THEN-SHIP
confidence: high
```

The whole-issue close for #116 (M2 cue-sourced issue home + I-B structured-argv fix; M3 `sdlc issue new` delegation) is in good shape and the prior M3 I1 regression (cwd-anchoring) is genuinely fixed — creation now forwards git-root-anchored absolute `--issues-dir`/`--history-dir`, so the #142 location contract holds. The pure/IO split is exemplary, `create_issue` is cleanly removed with no orphaned callers, the four #116 specs are green and lint is clean. The one thing to fix before crossing: the M3 ARCH-DRY refactor added a new `resolve_against_git_root`-based `get_history_dir` but **left the pre-existing inline one in place**, so the new definition is dead code (shadowed) and the "one resolver" invariant the commit claims isn't actually achieved. Behavior is correct in the default config, so it's non-blocking — but it's a one-line cleanup that should land before "done."

## 1. Strengths

- **ARCH-PURE textbook split.** `parse_issue_new_output` (`issues.lua:342`), `build_spawn_argv` (`issues.lua:373`), `resolve_issues_dir` (`issues.lua:333`), and the `spec_to_command`→`render_command` pair (`registry.lua:154,179`) are all pure and unit-tested IO-free; `run_sdlc_issue_new` is thin IO over them with an **injectable runner** so tests never invoke real sdlc (`issues_spec.lua` `run_sdlc_issue_new` block). This is the pure-core/thin-shell shape the plan promised.
- **I-B root-cause fix is real, not a patch.** `split_glob` (`registry.lua:128`) turns each absolute locate glob into a positional search DIR + relative `-g` pattern; the integration test actually executes the rendered command against a temp fixture and asserts it lists the file (`discovery_builder_spec.lua` "the rendered command actually matches files under the absolute home") — verifying the previously-silently-empty search now matches.
- **I1 regression genuinely closed.** `cmd_issue_new` forwards `M.get_issues_dir()`/`M.get_history_dir()` as absolute dirs (`issues.lua:782-784`); `run_sdlc_issue_new` appends `--issues-dir`/`--history-dir` (`issues.lua:391-398`), and `--` terminates flag parsing (`issues.lua:409`) so leading-dash titles stay positional. Both fixes are unit-pinned (`issues_spec.lua` "forwards absolute …" / "appends -- …").
- **Single-source seed.** `init.lua:549` seeds `config.issues_dir` once from the cue home with correct precedence (override > cue > default), so all five readers derive from one value rather than per-reader rerouting. The `home()` loader is pcall-guarded for fresh-clone/pre-weave (`issue_vocabulary.lua:181`), and I confirmed the generated `issue.json` actually carries `discovery.home: "workshop/issues"`.
- **Clean, documented retention.** `render_issue_template`/`ISSUE_TEMPLATE`/`next_issue_id` correctly retained for `cmd_issue_decompose` (the only caller, `issues.lua:896`) with the incompatibility rationale spelled out (`issues.lua:666-673`).

## 2. Critical findings

None.

## 3. Important findings

**I1 — Duplicate `get_history_dir`: the new ARCH-DRY definition is dead code, the consolidation it claims isn't achieved. `issues.lua:485-487` (shadowed) vs `:506-517` (wins). (ARCH-DRY)**

The window added a new `M.get_history_dir` that routes through the shared `resolve_against_git_root` (`issues.lua:485`, comment at `:459-462`: *"ONE resolver so issues + history anchor identically (ARCH-DRY)"*), but the pre-existing inline `M.get_history_dir` (`issues.lua:506-517`, present in the base at the same logical spot) was **not deleted**. Lua last-assignment-wins means the old inline version is what actually runs; the new one at `:485` never executes. So:
- the new definition is **dead code**, and
- the stated invariant is false in letter — `get_issues_dir` uses `resolve_against_git_root` while the *winning* `get_history_dir` does its own inline git-root join, so there are still two resolvers.

Failure/risk scenario: behavior coincides today only because `config.history_dir` defaults to the relative `"workshop/history"` (`config.lua:524`), for which both implementations yield `git_root/workshop/history`. A future maintainer editing the visible new `:485` version (e.g. to change empty-config handling) will see no effect — a silent maintenance trap. They also diverge on empty config: new returns `nil`, old defaults to `"history"` → `git_root/history` (which would misdirect sdlc's NextID scan away from `workshop/history` and risk an ID collision with archived issues).

Fix (root cause, ARCH-DRY): delete the old inline definition (`issues.lua:506-517`) and keep the `resolve_against_git_root` one. Safe — `nil` history is already guarded at every consumer (`next_issue_id` `:546`, `scan_issues` `:623`, and `cmd_issue_new`'s `if opts.history_dir and opts.history_dir ~= ""` `:395`). This restores the genuine single-resolver the comment claims.

## 4. Minor findings

- **`parse_issue_new_output` "Created"-substring discriminator is fragile.** `issues.lua:352` excludes any line *containing* `"Created"` to skip sdlc's stderr decoration. A repo whose absolute path legitimately contains `Created` (e.g. `/Users/x/Created/...`) would cause the bare-path stdout line to be wrongly excluded → `nil`. Root-cause-clean alternative: keep stdout/stderr **separate** in the jobstart runner (`issues.lua:419-423` merges them via one `collect`) and take the last `.md` line from stdout only — no content heuristic needed.
- **`vim.uv` vs `vim.loop` inconsistency.** `start_cmdline_spinner` uses `vim.uv.new_timer()` (`issues.lua:747`) while the rest of the codebase — including the sibling `progress.lua:72` and `issues.lua`'s own scandir calls — uses `vim.loop`. `vim.uv` only exists on nvim ≥ 0.10; for consistency/portability use `vim.loop` (or `vim.uv or vim.loop`).
- **Spinner duplicates the progress timer loop (ARCH-DRY-adjacent).** `start_cmdline_spinner` (`issues.lua:744`) re-implements the 120ms timer→tick→repaint loop that `progress.start` (`progress.lua:65-76`) already owns, reusing only `progress.frame`. The render targets genuinely differ (echo-area vs float window), so this is borderline-acceptable, but note it ships a second progress mechanism rather than extending the established one.
- **`--deps`/`--slug` forward API has no production caller.** `run_sdlc_issue_new`'s `opts.deps`/`opts.slug` (`issues.lua:399-406`) are exercised only by tests; `cmd_issue_new` passes neither and the decompose flow wasn't migrated. Documented speculative generality — acceptable, but it ships unused.

## 5. Test coverage notes

- Pure seams are well covered: parser (merged-stream + spaced-absolute-path + error branches), argv forwarding (absolute dirs, `--`, `--deps`), `build_spawn_argv` (binary vs interactive-shell), `resolve_issues_dir` precedence, `home()` (relative string / absent / empty / raising-loader-caught), and the I-B structured split + real-rg integration.
- **Gap:** the I1 fix's actual IO path (`cmd_issue_new` → real `vim.fn.system`/jobstart → cwd-relative resolution → `:p` open from a subdir) is entirely faked; the "creates under git root when cwd ≠ repo root" behavior rests on the argv-forwarding unit tests + the operator live-test logged in the issue. Real sdlc creates+pushes, so an automated e2e is impractical — acceptable, but the e2e that would have *originally* caught I1 still doesn't exist.
- The duplicate `get_history_dir` (§3) is invisible to tests because both implementations coincide on the default config — a test asserting `get_history_dir()` resolves against git root would still pass against the wrong (old) function. No test change needed beyond removing the dup.

## 6. Architectural notes for upcoming work

- **ARCH-DRY: FLAG → §3.** Otherwise the diff single-sources well (issue creation → sdlc; issue home → cue seed; one `resolve_against_git_root` for issues). Removing the dead `get_history_dir` collapses the last duplicate resolver.
- **ARCH-PURE: PASS.** Exemplary; the injectable-runner pattern is the right seam for the next sdlc-delegated flow (the eventual decompose migration).
- **ARCH-PURPOSE: PASS (with tracked deferrals).** Shadow-sweep of issue-creation/home consumers: `cmd_issue_new` derives from sdlc ✓; `config.issues_dir` (all 5 readers) derives from cue ✓; `cmd_issue_decompose` still hand-maintains `ISSUE_TEMPLATE` ✗ — a genuinely separable secondary path, documented and tracked to ariadne#145, not the cheap-win evasion the principle targets. The original "descriptor in `type.md`" purpose was consciously superseded by the cue channel (better single source), documented in the issue revisions. The deferred faceted picker is #115. No undeclared scope creep; the re-scopes are all operator-accepted and logged.

## 7. Plan revision recommendations

- None required for accuracy — the plan and issue already reconcile the as-built scope (M3.4 fallback retaining `render_issue_template` is documented in both the `## Plan` row at `000116…md:96` and the 2026-06-30 plan revision; the M2/M3 re-scopes are in `## Revisions`). The Core-concepts/entity table (M1-era matcher kinds) still matches code.
- Optional: when fixing §3, add a one-line note to the plan's M3 / Log that `get_history_dir` was consolidated onto `resolve_against_git_root` (the dead-dup removal) so the "ONE resolver" claim in `issues.lua:459-462` is true in fact, not just intent.
