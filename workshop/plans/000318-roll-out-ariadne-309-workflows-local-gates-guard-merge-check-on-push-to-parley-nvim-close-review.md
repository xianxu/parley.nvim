# Boundary Review — parley.nvim#318 (whole-issue close)

| field | value |
|-------|-------|
| issue | 318 — roll out ariadne#309 workflows (local-gates-guard, merge-check on push) to parley.nvim |
| repo | parley.nvim |
| issue file | workshop/issues/000318-roll-out-ariadne-309-workflows-local-gates-guard-merge-check-on-push-to-parley-nvim.md |
| boundary | whole-issue close |
| milestone | — |
| window | bdda2c760a16525373f718770dfeff7884faf0ee..3be5288d15e544449cc0501c4205dba15722b84d |
| command | sdlc close --issue 318 |
| reviewer | claude |
| isolation | fenced |
| timestamp | 2026-10-12T14:46:16-07:00 |
| verdict | SHIP |

## Review

Both workflow files are byte-identical to ariadne `origin/main`. I'm finishing the review now.

```verdict
verdict: SHIP
confidence: high
```

This is a seeded-file rollout, and it does what the issue asks. The two workflow files at head `3be5288d` match ariadne `origin/main` exactly. I checked this myself with `git -C ~/workspace/ariadne show origin/main:<path> | cmp - <(git show 3be5288d:<path>)`, and both files came back "identical". The latest ariadne commit touching these files is `719cf451`, the #309 round-2 fix. The window changes nothing outside `.github/workflows/`, and there is no parley-specific drift. Nothing blocks shipping.

1. **Strengths**
   - **Exact copy of the source.** Both files match byte for byte, which is what the Spec and Done-when require. There is no hand editing of ariadne's files.
   - **Safe guard design.** `.github/workflows/local-gates-guard.yml` uses `pull_request_target` but never checks out or runs PR code. PR values reach the script through `env:` and are checked before use (PR number numeric, head SHA hex). Its status starts as pending, and an EXIT trap turns any early exit into a failure. Labels are read live when the decision is made.
   - **Push handling and safer inputs.** `.github/workflows/merge-check.yml:45-63` adds push-to-main handling and skips cleanly when `before` is all zeros (a new branch). It also stops pasting `${{ }}` values straight into the script and passes them through `env:` instead, which removes a script-injection risk.
   - **No bootstrapping problem.** Because `pull_request_target` runs main's copy of the guard, this PR, which adds the guard, isn't blocked by it.

2. **Critical findings:** none.

3. **Important findings:** none.

4. **Minor findings**
   - `scripts/run-merge-checks.sh` isn't tracked in parley.nvim's tree. `merge-check.yml` calls it after `./bootstrap.sh`, as it did before this change, so I assume bootstrap generates it. The new push trigger depends on the same path. I didn't verify this, and it isn't a regression from this diff.

5. **Test coverage notes:** This change copies CI files, and the issue's own evidence is the byte-identity check, which I re-ran independently. The guard's behavior is tested in ariadne's #309 work, not here.

6. **Architectural notes**
   - **ARCH-DRY:** pass. The files come from a single source (ariadne) and are copied verbatim.
   - **ARCH-PURE:** N/A. The diff is CI YAML only.
   - **ARCH-PURPOSE:** pass. Both files from #309 have landed.
   - **ARCH-MOCK:** N/A here. The external dependencies (`gh api`, git) belong to ariadne's design.
   - **ARCH-CONSTRAINTS:** pass. The `concurrency` group with cancel-in-progress limits the guard to one run per PR.
   - **ARCH-SECURE:** pass. PR code is never run, inputs go through `env:` and are checked, and permissions are minimal (`statuses: write`).
   - **ARCH-ORDER:** pass. Stale-head and cancellation ordering are handled: if the head moved, the run exits without deciding, and an exit before a decision posts failure.
   - **ARCH-FUNERAL:** pass. Commit statuses are GitHub-managed and superseded per SHA. The `refs/remotes/pr/head` ref only exists on the throwaway runner.
   - **Atlas/README:** The guard's derivation doc lives in ariadne (`atlas/workflow/ci-merge-check.md`), and parley.nvim has no `atlas/workflow/` directory. That fits a consumer-repo rollout, so I'm not flagging it.

7. **Plan revision recommendations:** none. The plan still matches the code.

```findings
findings:
  - id: new
    severity: Minor
    family: ci-generated-entrypoint-untracked
    title: |
      merge-check.yml (incl. new push trigger) relies on scripts/run-merge-checks.sh, which is not tracked in parley.nvim
    detail: |
      I assume bootstrap.sh generates it, as before this diff. Not a regression; noting it so the push-to-main run is watched on its first firing.
```
