# Boundary Review — parley.nvim#344 (whole-issue close)

| field | value |
|-------|-------|
| issue | 344 — help-parley omits the make goldens and make perf-finder targets |
| repo | parley.nvim |
| issue file | workshop/issues/000344-help-parley-omits-the-make-goldens-and-make-perf-finder-targets.md |
| boundary | whole-issue close |
| milestone | — |
| window | 5c41f37526c2df5e808282f3cbbe8f1cb51c51f4..b3ce489106e4353652201bb9cfaa3b396edb8b6e |
| command | sdlc close --issue 344 |
| reviewer | claude |
| isolation | fenced |
| timestamp | 2026-10-16T00:18:09-07:00 |
| verdict | SHIP |

## Review

Now I'll check that the targets exist, that the descriptions are accurate, and whether any other targets are missing from the help.

```verdict
verdict: SHIP
confidence: high
```

This is a two-line change and it does what the issue asks. `Makefile.parley:18` adds `make perf-finder` and `Makefile.parley:21` adds `make goldens` to the `help-parley` recipe. Running `make help-parley` at head prints both, each with a one-line description. Both targets exist (`Makefile.parley:236`, `:245`) and are already in `.PHONY`. Each description matches the comment above its target and the header of the script it runs (`tests/perf_chat_finder.lua`, `scripts/refresh_goldens.lua`). Nothing blocks SHIP.

1. **Strengths**
   - Each new line sits next to its sibling: `perf-finder` after `perf`, `goldens` after `fixtures`. Column alignment matches the existing entries.
   - The descriptions are accurate. "ChatFinder materializer performance" matches the benchmark header, and "golden payload fixtures" matches `tests/fixtures/golden_payloads/*.json`.
   - I compared every target in `Makefile` and `Makefile.parley` against the help list. The only targets still missing are `model-checker`, which is a backward-compatible alias, and `check-test-deps`, an internal dependency check. Leaving both out is reasonable, so the omission class is fully swept.

2. **Critical findings:** none.

3. **Important findings:** none.
   - Docs gate: these targets are not new user-facing surface. `TOOLING.md:8` and `atlas/infra/test_harness.md:78` already document them, so no README or atlas update is needed.

4. **Minor findings**
   - The help text is still a hand-maintained list, separate from the target definitions. That is how these two entries drifted out after #342 added the targets. Generating help from `## ` target comments would stop it recurring. This is advisory only and goes beyond this issue's scope.

5. **Test coverage notes:** no test covers the help text, and the issue Log says so. The Done-when clause has only one state to check (both lines listed), and I confirmed it by running `make help-parley` at head.

6. **Architectural notes**
   - ARCH-DRY: pass. No logic is duplicated; the change only adds help strings.
   - ARCH-PURE: pass. There is no logic to separate from IO.
   - ARCH-PURPOSE: pass. The issue's purpose is to list the two targets, and both are listed. No other public target is missing (see Strengths).

7. **Plan revision recommendations:** none. The plan's single checklist item matches the code.

```findings
findings:
  - id: new
    severity: Minor
    kind: defect
    family: help-text-hand-restated
    title: |
      help-parley target list is hand-maintained, separate from the target definitions
    detail: |
      This drift (targets added in 342 without help lines) can recur. Generating help from the comment above each target would make the target definitions the single source. Advisory only; the two-line fix is correct as shipped.
```

<!-- sdlc-review-usage [{"version":1,"intent":{"disposable_root":true,"id":"d7a9e65c-c95e-47ea-8ef7-4e2ede63c88d","repository":"github.com/xianxu/parley.nvim","issue_id":"000344","recipe":"small-diff-review","round":1,"attempt":1,"agent":"claude","root":"/Users/xianxu/Library/Caches/sdlc/review-checkouts/9a3603f238715332","reviewed_head":"b3ce489106e4353652201bb9cfaa3b396edb8b6e","slot":"parley.nvim:3","requested_at":"2026-10-16T07:17:13.183632Z"},"phase":"finished","pid":36732,"started_at":"2026-10-16T07:17:13.490887Z","finished_at":"2026-10-16T07:18:06.848572Z","session_id":"19e10694-99c4-43f0-a804-2c2e3657f639","outcome":"returned"}] -->
