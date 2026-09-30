# Boundary Review — parley.nvim#307 (whole-issue close)

| field | value |
|-------|-------|
| issue | 307 — Clean up local parley config; zero-config plugin defaults |
| repo | parley.nvim |
| issue file | workshop/issues/000307-zero-config-defaults.md |
| boundary | whole-issue close |
| milestone | — |
| window | 907ca76be8e0af28a27cad8a03e9b736bfc55d7a..30cf97f72fee702724c371ff4ee63d65a1035caa |
| command | sdlc close --issue 307 |
| reviewer | claude |
| timestamp | 2026-09-30T11:56:07-07:00 |
| verdict | FIX-THEN-SHIP |

## Review

```verdict
verdict: FIX-THEN-SHIP
confidence: medium
```

The change does what the issue set out to do. `api_keys` now layers over the defaults, and the opt-out for empty provider tables is pinned by a test. `repo_root` detection no longer depends on `chat_dir`. Detection now uses the same nearest-marker rule the starter uses, and the `PARLEY_REPO_MODE` knob moved into `setup`, so it has one owner. Nine tests in `tests/integration/zero_config_spec.lua` cover this, each in its own child Neovim with a cleared environment and its own XDG tree. None of that blocks shipping. Three things need follow-up:
- **One fact, two rules.** Setup's repo root now comes from the nearest `.parley` marker. The buffer-context check next to it still uses git root plus marker. Before this change, plugin users only ever got the git-root rule, so the two never disagreed for them.
- **Done-when clauses moved or pending.** The "README has a minimal-config section" clause was met in atlas instead. The operator-config clause is still waiting for the merge. Neither is recorded as a `## Revisions` entry.
- **Stale comment.** One comment in `config.lua` still describes git-root semantics.

## 1. Strengths
- `lua/parley/init.lua:591`: `vim.tbl_extend("force", M.config.api_keys or {}, opts.api_keys or {})` is the right fix at the root cause. `M.config` is a fresh `deepcopy(config)` at this point, so the defaults really are the base, and `false` falls through the existing `if api_key` check.
- `init.lua:603`: the `next(provider) ~= nil` guard was found by running the full suite, and it is pinned by the `keeps a provider disabled by an empty table` case, so a revert would fail that test.
- ARCH-DRY: the `PARLEY_REPO_MODE` check moved from `starter.lua` into `apply_repo_local`, and the starter's hand-written `detect_root` call is gone. The starter now reaches repo mode through `setup`'s own rule (`starter_project_spec` marker-only cases).
- The test harness opts out once, in `tests/minimal_init.vim:37`, instead of in every spec. It is also recorded as a lesson.
- The opt-out tests run both ways: `repo_root = false` and `PARLEY_REPO_MODE=0`. An explicit `repo_root` beating the env var is also tested.

## 2. Critical findings
None.

## 3. Important findings
- **ARCH-DRY / ARCH-PURPOSE: repo-root detection has two rules.**
  - `apply_repo_local` (`init.lua:767`) now picks the **nearest `.parley` marker**.
  - `detect_buffer_context` (`init.lua:1686-1692`) still uses `find_git_root(cwd)` and then checks for the marker there.
  - They disagree in two cases: a project with a marker but no Git repo, and a marker in a subdirectory of a git repo. In both, setup enters repo mode while the buffer context says `"other"`.
  - Other places still derive the root from git: `issues.lua:508,536`, `vision.lua:1552,1628,1662`, `markdown_finder.lua:315`, and the autocmds at `init.lua:1062,1088`. Where the marker isn't at the git root, they resolve paths against a different root than the one `config.repo_root` names.
  - This split already existed for the starter app. The diff extends it to every plugin user.
  - Fix sketch: `detect_buffer_context` should read `M.config.repo_root` (it is a string only when repo mode is active). The other sites should either use `config.repo_root` when it is set, or the atlas should state that issues and vision stay git-rooted.
  - At minimum, `atlas/infra/repo_mode.md` should drop or qualify "The standalone app and plugin setup share this rule".

## 4. Minor findings
- `lua/parley/config.lua:531-532`: the comments on `repo_chat_dir` and the next field still say "relative to git root". The root is now the nearest marked directory, so this is a stale doc claim.
- Done-when says "README has a minimal-config section". It was delivered in `atlas/infra/config.md#minimal-config`, and the README links only to `#install-as-a-neovim-plugin`, the parent section. That is a reasonable place, but the clause was changed without a Revisions entry. Consider linking the README straight to `#minimal-config`.
- The last Done-when clause (operator config trimmed and parity confirmed in daily use) is still unchecked, because the install waits for the merge. Closing with it open needs a Revisions note or an explicit carry-over.
- `tests/integration/zero_config_spec.lua:26`: `OPT_OUT_ENV` is a test-only env var that switches the shared `opt_out` probe. It works, but it would read more clearly as two literal probes.
- `atlas/infra/config.md` "Merge order": the added sentence makes that line much longer than the lines around it (prose wrap nit).

## 5. Test coverage notes
Each state-pair clause in Done-when is exercised on both sides:
- **Keyless defaults:** a user table keeps them, and `false` drops one.
- **Repo detection:** detected with `chat_dir` set, and opted out by both mechanisms.
- **Zero-config boot:** no `vim.notify` at WARN or above, no WARNING/ERROR lines in the log, and a chat is created under the default dir.
- **Missing key:** fails lazily and names the provider.

Gap: nothing tests the divergence in the Important finding. A test with a marker-only (no-Git) project, asserting that `_detect_buffer_context` returns `"repo"`, would fail today.

## 6. Architectural notes
- **ARCH-DRY:** flag. The repo root is computed two ways (see Important). The `PARLEY_REPO_MODE` consolidation passes.
- **ARCH-PURE:** pass. `repo_mode.detect_root` stays a small pure-ish helper, and the setup glue only calls it. The new tests are integration tests on purpose, running child processes with isolated environments.
- **ARCH-PURPOSE:** mostly pass. "No plugin logic in user config" holds for setup. The shadow-sweep turns up consumers still on the old git-root rule (Important finding).

## 7. Plan revision recommendations
- Add `## Revisions` (2026-09-30): the minimal-config section moved from README to `atlas/infra/config.md#minimal-config`, because the README is now a landing page (e02820c7).
- Add `## Revisions`: the operator-config install is deferred until after merge; parity was checked with a probe, not in daily use.

```findings
findings:
  - id: new
    severity: Important
    family: repo-root-single-source
    title: |
      Setup uses the nearest marker for the repo root; detect_buffer_context and issues/vision still use the git root
    detail: |
      apply_repo_local (init.lua:767) now uses repo_mode.detect_root. detect_buffer_context (init.lua:1686-1692) still uses find_git_root plus the marker, so a marker-only or subdirectory-marker project is repo mode in setup but "other" in buffer context. Other git-rooted consumers of the same fact: init.lua:1062,1088; issues.lua:508,536; vision.lua:1552,1628,1662; markdown_finder.lua:315. Make them read config.repo_root, or document the split; atlas/infra/repo_mode.md's "share this rule" overstates it.
  - id: new
    severity: Minor
    family: stale-doc-claim
    title: |
      config.lua repo_chat_dir/repo_note_dir comments still say "relative to git root"
    detail: |
      The root is now the nearest marked directory (config.lua:531-532).
  - id: new
    severity: Minor
    family: done-when-drift-unrecorded
    title: |
      Done-when README clause moved to atlas and operator-config clause deferred, with no Revisions entry
    detail: |
      The minimal-config section is in atlas/infra/config.md and the README links only the parent anchor; the last Plan item is still unchecked until after merge. Record both in a Revisions section.
```

---

## Re-review — 2026-09-30T12:04:50-07:00 (FIX-THEN-SHIP)

| field | value |
|-------|-------|
| issue | 307 — Clean up local parley config; zero-config plugin defaults |
| repo | parley.nvim |
| issue file | workshop/issues/000307-zero-config-defaults.md |
| boundary | whole-issue close |
| milestone | — |
| window | 907ca76be8e0af28a27cad8a03e9b736bfc55d7a..dc1d958ba2f3f39abc73f9ea9adb29cab070b245 |
| command | sdlc close --issue 307 |
| reviewer | claude |
| timestamp | 2026-09-30T12:04:50-07:00 |
| verdict | FIX-THEN-SHIP |

## Review

```verdict
verdict: FIX-THEN-SHIP
confidence: high
```

The branch does what the issue set out to do. `setup({})` boots with no keys and no warnings. User `api_keys` now merge over the defaults, so the keyless providers keep their local tokens and `false` removes one. An empty provider table still disables that provider. Repo detection now uses the nearest `.parley` marker and still runs when `chat_dir` is set; `repo_root = false` and `PARLEY_REPO_MODE=0` turn it off. The fix for last round's BR-1 is real: I copied head into a scratch directory and ran `zero_config_spec`, and all 9 cases passed. With the base version of `lua/parley/issues.lua` put back, the marker-only-project case fails. BR-2 and BR-3 are fixed too.

One small gap is left, and it belongs to a family already open on this issue. `detect_buffer_context` still works out the repo root by itself instead of reading the root that setup chose. The atlas also says it goes through `project_root()`, which it doesn't. It only affects the keybinding help overlay, so it doesn't block shipping.

**1. Strengths**
- `M.project_root()` (`lua/parley/init.lua:98-104`) gives the root-finding rule one home. The issues, vision and export readers all use it, and there's a git-root fallback so issues still work in a Git repo with no marker.
- The `PARLEY_REPO_MODE` check moved out of `starter.lua` and into setup. There is now one opt-out switch, and the test harness sets it once in `tests/minimal_init.vim` instead of in every spec.
- The empty-table guard on provider-secret injection (`init.lua:611`) fixes a real regression that the merge introduced. The "keeps a provider disabled by an empty table" case pins it.
- Every case in `zero_config_spec` runs in a separate Neovim with a cleared environment and its own XDG directories, so the tests really start with no config.
- Every `## Done when` clause is tested in both directions: detection on and off (by argument and by environment variable), a key kept and a key dropped, and a missing key reported at first use rather than at startup.

**2. Critical findings:** none.

**3. Important findings:** none.

**4. Minor findings**
- **`detect_buffer_context` ignores the root setup chose (`init.lua:1693`).** This is the second finding in family `repo-root-single-source`, and it also repeats `stale-doc-claim`.
  - The function calls `repo_mode.detect_root(getcwd, marker)` again instead of reading `config.repo_root`.
  - Scenario 1: a user in a marked directory who opted out with `repo_root = false` or `PARLEY_REPO_MODE=0` still gets "repo" in the help overlay. The demo launcher hits this whenever a directory above the demo has a marker.
  - Scenario 2: an explicit `repo_root = "/elsewhere"` with cwd outside it gets "other".
  - `atlas/infra/repo_mode.md:12-13` says the "repo" buffer context goes through `parley.project_root()`. It doesn't.
  - **The rule:** repo mode is decided only by setup's `config.repo_root`, and nothing else re-derives it from cwd. The whole family:
    - `init.lua:1693` breaks the rule. It should be `type(M.config.repo_root) == "string" and M.config.repo_root ~= ""`.
    - `markdown_finder.lua:313-315` repeats `project_root()` inline. It behaves the same, but should just call `_parley.project_root()`.
  - Add an opt-out assertion (`_detect_buffer_context(0) ~= 'repo'`) to the `opt_out` probe in `zero_config_spec`.

**5. Test coverage notes**
- 9 of 9 cases pass at head.
- The BR-1 regression test fails without the fix; confirmed by putting back the base `issues.lua`. The issues assertion runs before the vision one, so reverting `vision.lua` on its own is caught only if the issues check still passes. That's acceptable.
- Nothing tests buffer context when repo mode is turned off (see the finding above).

**6. Architectural notes**
- **ARCH-DRY: flag (Minor).** `markdown_finder.lua:313-315` repeats `project_root()`, and `init.lua:1693` re-derives the root. Everything else passes.
- **ARCH-PURE: pass.** `project_root` is a small glue function over config and cwd. The detection rule itself stays pure in `repo_mode.detect_root`.
- **ARCH-PURPOSE: pass**, apart from the root-source sweep above. Every Done-when clause is met, and the two changed clauses are recorded in `## Revisions`.

**7. Plan revision recommendations**
- After the fix, add to the round-2 Revisions entry: "the 'repo' buffer context reads `config.repo_root` (not `repo_mode.detect_root`), and markdown_finder uses `project_root()`". The current Revisions line saying buffer context "uses `repo_mode.detect_root`" is accurate today, but it describes the split this finding asks to remove.

```findings
dispose:
  - id: BR-1
    disposition: addressed
    note: |
      issues/vision/autocmds/exports now use parley.project_root(); zero_config_spec marker-only case passes at head and fails with base issues.lua (verified in scratch). Residual buffer-context split raised as a new Minor in the same family.
  - id: BR-2
    disposition: addressed
    note: |
      config.lua:262,529-545 comments now say "relative to the repo root" and describe nearest-marker detection.
  - id: BR-3
    disposition: addressed
    note: |
      Issue has a Revisions section (2026-09-30 close review round 1) recording the README→atlas move and deferred operator-config install.
findings:
  - id: new
    severity: Minor
    family: repo-root-single-source
    title: |
      detect_buffer_context re-derives repo mode from cwd instead of config.repo_root; atlas claims it uses project_root()
    detail: |
      2nd finding in family repo-root-single-source (also stale-doc-claim). Rule: repo mode is decided only by setup's config.repo_root; nothing re-derives it from cwd. Instances: init.lua:1693 (repo_mode.detect_root; wrong under repo_root=false, PARLEY_REPO_MODE=0, or an explicit repo_root elsewhere; help overlay shows "repo" in opted-out demo) and markdown_finder.lua:313-315 (inline copy of project_root, behavior-equivalent). atlas/infra/repo_mode.md:12-13 says buffer context goes through project_root(), which is false. Fix: buffer context checks type(M.config.repo_root)=="string" and non-empty; markdown_finder calls _parley.project_root(); add a not-'repo' assertion to zero_config_spec's opt_out probe.
```
