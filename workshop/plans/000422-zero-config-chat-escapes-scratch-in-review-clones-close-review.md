# Boundary Review — parley.nvim#422 (whole-issue close)

| field | value |
|-------|-------|
| issue | 422 — Zero-config chat escapes scratch in review clones |
| repo | parley.nvim |
| issue file | workshop/issues/000422-zero-config-chat-escapes-scratch-in-review-clones.md |
| boundary | whole-issue close |
| milestone | — |
| window | 091392db58ad91f7f937e2e977d496894beab962..50ed7eba83107880c5e83904deccbdc4129547b1 |
| command | sdlc close --issue 422 |
| reviewer | claude (anthropic; author anthropic) |
| isolation | checkout |
| timestamp | 2026-10-23T02:16:00-07:00 |
| verdict | SHIP |

## Review

Diff read; now running the guard specs with scratch placed outside the clone.

Unrelated failures come from reviewer confinement (no `ps`, git init refused). Checking marker semantics next.

```verdict
verdict: SHIP
confidence: high
```

This change does what the plan says. The new `scripts/test-placement.sh` runs as the first step of `PREP_TEST_ENV`, so every make target that prepares the test environment refuses a scratch root before anything is created. It refuses a root inside the checkout, or one where the root or any of its parent directories carries the `.parley` marker. `zero_config_spec` case 1 now fails with the actual cause (a marked parent of its cwd) instead of the vaguer "chat outside default dir". I ran `TMPDIR=<outside> make test-spec SPEC=infra/test_harness` at the pinned head. All five new guard tests pass, and `git status` stays clean. That run had three failing specs, none caused by this diff: the review confinement refused `git init` outside its directories, blocked one process spawn with EPERM, and has no `ps`. I found one Minor issue (below) and nothing that blocks shipping.

1. **Strengths**
   - `scripts/test-placement.sh:20-22` resolves the nearest existing parent with `pwd -P` before comparing, so a root that doesn't exist yet and symlinked temp dirs like `/tmp → /private/tmp` compare correctly. The spec covers both an existing and a not-yet-created root.
   - ARCH-DRY: the Makefile's `REPO_MARKER := .parley` is a second copy of `config.repo_marker`, but a test enforces that they match (`tests/arch/scratch_placement_spec.lua:213-216`). The same test checks that the guard is the opening step of `PREP_TEST_ENV`, so the wiring can't silently drift.
   - The "creates nothing in the tree" check (`scratch_placement_spec.lua:192`) covers the bug that actually happened: writing into the tree before anyone notices.
   - The zero_config precondition calls the product's own `repo_mode.detect_root` (`zero_config_spec.lua:43`) rather than copying its logic.
   - The fix is split correctly: the TMPDIR placement belongs to ariadne (#571), and the issue log records that this lands only after it.

2. **Critical:** none.

3. **Important:** none.

4. **Minor**
   - **Marker check is broader than the product's.** `scripts/test-placement.sh:32` treats the marker as present with `[ -e ]`, which also matches a `.parley` directory. The product's `detect_root` (`lua/parley/repo_mode.lua:8`) only counts a readable regular file (`filereadable`). So the plan and atlas claim that the guard and the spec "state the same rule" is not quite true: the guard would refuse a scratch root under a `.parley` *directory* that the product ignores.
     - The family in this window has one code site (`test-placement.sh:32`) and two doc claims that the rules match (plan Spec §1 and `atlas/infra/test_harness.md:60`).
     - Fix: use `[ -f "$dir/$marker" ] && [ -r "$dir/$marker" ]`, and add a test case with a `.parley` directory.

5. **Test coverage**
   - All Done-when clauses are covered:
     - The guard is tested in both states: refusing (marked tree, marker on the root itself, inside the checkout with no marker) and accepting (unmarked root, existing or not).
     - The chat-stays-in-scratch regression is the HOME-prefix assertion in `zero_config_spec.lua:49`.
     - The review-clone repro is recorded only as log evidence. That's acceptable for something that depends on the environment.
   - `test_run_lease.py` now copies the script into its disposable checkouts. Without that, its make runs would fail at `PREP_TEST_ENV` in a checkout missing the script.

6. **Architecture**
   - ARCH-DRY: pass. The one duplicated fact, the marker, is enforced by a test.
   - ARCH-PURE: pass. The guard is a small IO shell script tested directly, with no mocks.
   - ARCH-PURPOSE: pass. The root cause sits in ariadne and was routed there as #571. The parley side catches the problem early and fails with a clear message. The only consumer is `PREP_TEST_ENV`, which every relevant target uses.
   - ARCH-EVOLVE: not applicable. No persisted format changes.

7. **Plan revisions:** none needed. If the Minor fix is applied, the "same rule" claim becomes accurate. If it isn't, add a `## Revisions` note that the guard is deliberately broader (it refuses a file or a directory).

```findings
findings:
  - id: new
    severity: Minor
    kind: defect
    family: guard-rule-diverges-from-product-predicate
    title: |
      test-placement.sh treats any existing .parley (file or dir) as a marker; detect_root only counts a readable file
    detail: |
      scripts/test-placement.sh:32 uses [ -e ] while lua/parley/repo_mode.lua:8 uses filereadable, so the guard refuses scratch under a .parley directory the product ignores, contradicting the plan and atlas claim (atlas/infra/test_harness.md:60) that the two state the same rule. Use [ -f ] && [ -r ] and add a directory-marker case to tests/arch/scratch_placement_spec.lua.
```

<!-- sdlc-review-usage [{"version":1,"intent":{"disposable_root":true,"id":"83bc23b6-a3ec-4828-a2f1-7bf4f1081007","repository":"github.com/xianxu/parley.nvim","issue_id":"000422","recipe":"small-diff-review","round":1,"attempt":1,"agent":"claude","root":"/Volumes/TestScratch/review-checkouts/1486cb91ba8f4dd1","reviewed_head":"50ed7eba83107880c5e83904deccbdc4129547b1","slot":"parley.nvim:1","requested_at":"2026-10-23T09:12:02.00237Z"},"phase":"finished","pid":81740,"started_at":"2026-10-23T09:12:02.099614Z","finished_at":"2026-10-23T09:15:59.833907Z","session_id":"af374464-a5bf-4c28-a251-4541dd731a59","outcome":"returned"}] -->
