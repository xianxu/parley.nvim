# Boundary Review — parley.nvim#235 (whole-issue close)

| field | value |
|-------|-------|
| issue | 235 — One reader for the test-harness signal: file_tracker off g:parley_test_mode |
| repo | parley.nvim |
| issue file | workshop/issues/000235-one-reader-for-the-test-harness-signal-file-tracker-off-g-parley-test-mode.md |
| boundary | whole-issue close |
| milestone | — |
| window | a01db4c7dcee90fa87e98d2e2e4051cf886060f2..3128170e1f784d1e067f5c67ab5d7f07f6bc28a5 |
| command | sdlc close --issue 235 |
| reviewer | claude |
| isolation | checkout |
| timestamp | 2026-10-16T05:36:01-07:00 |
| verdict | SHIP |

## Review

Diff read; now running the touched specs.

The failures come from the review sandbox, which puts TMPDIR inside the checkout. Next I'm checking that the specs this diff touches pass.

Touched specs pass. I'll revert the `file_tracker` fix to confirm the new spec fails without it.

Confirmed: the spec fails without the fix. Now checking that the arch guard catches a planted reader.

Guard catches the planted reader. A few last checks: the stale plan item, the highlighter reference, and the other caller of the spell probe.

```verdict
verdict: SHIP
confidence: high
```

This change delivers what #235 set out to do. `test_isolation.active()` is now the only place that reads the harness signal. All four production readers go through it: `file_tracker`, both `cliproxy` sites and `issue_tracker`. The `g:parley_test_mode` workarounds are gone from `minimal_init.vim`, `chat_move_spec`, `spell_compatibility.lua`, `file_tracker_spec` and `sidecars.lua`. I checked both "seen red" claims myself in this checkout. With `file_tracker` reverted to its old `g:` reader, the new "never writes file_access.json under the harness" spec fails (15/1). With a planted `vim.g.parley_test_mode` reader in `lua/parley/helper.lua`, the new arch guard fails with its "ask require('parley.test_isolation').active()" message. `make test` was not fully green here. Seven specs failed, all for one environmental reason: the review sandbox puts `TMPDIR`, `$HOME` and XDG inside the checkout, which carries a `.parley` marker. The failures are in `scratch_placement_spec`, `zero_config_spec`, `starter_project_spec` and `starter_config_spec`, and each message names the in-repo scratch path or chat dir. None of them touches this diff. Every spec the diff touches passed. The only finding is a Minor plan-text drift.

1. **Strengths**
   - `lua/parley/test_isolation.lua:13`: the reader went into the existing harness-rules module, which already holds `inside`/`check`, instead of a new `harness.lua`. That is the right call under ARCH-DRY.
   - `tests/arch/single_source_sweeps_spec.lua:896-918`: the guard catches both spellings, skips comment-only lines, and pins the home reader's exact expression. Through `repo_files` it also refuses an empty file list, so it cannot pass while checking nothing.
   - `tests/unit/file_tracker_spec.lua:217`: the new spec first asserts that the signal is actually present, then checks the in-memory count and that no file was written. It goes red without the fix (verified above).
   - `cliproxy.lua:243`: one `isolation` local now serves both `active()` and `inside()`.
   - `scripts/check-spell-compatibility.sh:19,26` already exports `PARLEY_TEST_MODE=1`, so the spell probe behaves as it did before the `g:` line was removed. I checked this.

2. **Critical:** none.

3. **Important:** none.

4. **Minor**
   - The issue's Plan checklist still says `lua/parley/harness.lua`, but the code puts `active()` in `lua/parley/test_isolation.lua`. The Log records the change but the checklist was never updated. The `## Spec` paragraph also still names the highlighter's `new_default_deferral`, which no longer exists; the Plan's re-check notes this.

5. **Test coverage**
   - The "file_tracker writes no file_access.json under the harness" requirement is covered in both states:
     - **Signal on:** the new spec.
     - **Signal off:** the existing persistence cases, which clear `$PARLEY_TEST_MODE`.
   - `cliproxy_update_spec:59` already covers the off state for `releases_url`.
   - `M.init`'s guard (`file_tracker.lua:165`) has no direct test. It is the same predicate, so this is low risk.

6. **Architecture**
   - **ARCH-DRY: pass.** There is one predicate, and `file_tracker`'s `is_test_mode` is now only a thin alias for it.
   - **ARCH-PURE: pass.** `active()` is a single environment read at the boundary, and callers stay as they were.
   - **ARCH-PURPOSE: pass.** I enumerated every reader across the tree with grep. Outside `lua/` the remaining hits are only writers or test toggles: `minimal_init.vim`, the spell script, `test_local_app.py`, `file_tracker_spec`, `sidecars.lua` and `cliproxy_update_spec`. Inside `lua/`, the only other mentions are comment lines in `cliproxy.lua`. The guard enforces this instead of just documenting it.
   - **Docs:** the atlas paragraph in `atlas/infra/test_harness.md` was rewritten correctly. README needs no change because there is no new user-facing surface.

7. **Plan revisions**
   - Add a `## Revisions` entry saying the reader is `test_isolation.active()` in `lua/parley/test_isolation.lua` and not a new `harness.lua`, and update the first checklist item to match.
   - Note in `## Spec` that the highlighter consumer was dropped because `new_default_deferral` was removed.

```findings
findings:
  - id: new
    severity: Minor
    kind: defect
    family: plan-text-drifts-from-code
    title: |
      Plan checklist names lua/parley/harness.lua; the reader lives in test_isolation.lua
    detail: |
      Plan checklist item 1 claims `lua/parley/harness.lua` holds active(), but the code (and Core concepts table) put it in lua/parley/test_isolation.lua:13; only the Log records the deviation. Family instances in this window: (1) that checklist item; (2) the Spec paragraph still names the highlighter's new_default_deferral as a consumer, which no longer exists. Add a Revisions entry and amend both.
```

<!-- sdlc-review-usage [{"version":1,"intent":{"disposable_root":true,"id":"d164eefb-ae93-40b4-a02e-c7435de4b525","repository":"github.com/xianxu/parley.nvim","issue_id":"000235","recipe":"small-diff-review","round":1,"attempt":1,"agent":"claude","root":"/Users/xianxu/Library/Caches/sdlc/review-checkouts/661fdd6fe28dcefa","reviewed_head":"3128170e1f784d1e067f5c67ab5d7f07f6bc28a5","slot":"parley.nvim:4","requested_at":"2026-10-16T12:32:11.006468Z"},"phase":"finished","pid":58084,"started_at":"2026-10-16T12:32:11.147057Z","finished_at":"2026-10-16T12:35:58.877464Z","session_id":"9323e77e-45c9-442b-8075-1e15ee8bb9ec","outcome":"returned"}] -->
