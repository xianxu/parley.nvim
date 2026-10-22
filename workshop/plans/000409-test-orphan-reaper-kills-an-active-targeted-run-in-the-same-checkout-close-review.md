# Boundary Review — parley.nvim#409 (whole-issue close)

| field | value |
|-------|-------|
| issue | 409 — Test orphan reaper kills an active targeted run in the same checkout |
| repo | parley.nvim |
| issue file | workshop/issues/000409-test-orphan-reaper-kills-an-active-targeted-run-in-the-same-checkout.md |
| boundary | whole-issue close |
| milestone | — |
| window | 4b8e61ed5f5b5b3ab969bc3df6314dac442e753c..aae4e70e14ac4b1eac5aa10da7bc94836e8bcb0a |
| command | sdlc close --issue 409 |
| reviewer | codex (openai; author openai) |
| isolation | fenced |
| timestamp | 2026-10-22T11:44:49-07:00 |
| verdict | REWORK |

## Review

```verdict
verdict: REWORK
confidence: high
```

The lease protects direct test invocations and preserves existing orphan cleanup, but prerequisite entry bypasses it. I reproduced an active harness being killed when launched through a Make alias. That leaves the issue’s ownership guarantee incomplete.

Done-when: current — the criteria still cover serialization, orphan cleanup, and verification; the revisions choose an allowed mechanism and change verification scheduling.

```findings
findings:
  - id: new
    severity: Critical
    kind: defect
    family: harness-entry-ownership
    title: |
      Protected targets bypass the lifetime lease when reached as prerequisites
    detail: |
      Makefile.parley:8 enables lease dispatch only when MAKECMDGOALS directly names a protected target. In a disposable checkout, adding `review-alias: test-spec` and invoking that alias started the gated harness without a lifetime lease; a second direct test-spec entered without waiting and SIGKILLed the first Neovim. Enforce ownership whenever a protected target executes, including prerequisite/default-goal entry, before scratch mutation through final census. Add a gated regression for this entry path. This violates ARCH-PURPOSE and ARCH-ORDER.
```

1. **Strengths**

   - One shared lease implementation serves Make and standalone live census calls.
   - Descriptor validation, stable lock-file identity, and kernel-managed release avoid PID-based ownership guesses.
   - Gated tests exercise cancellation, separate checkouts, recursive commands, and surviving descendants.
   - Atlas and TOOLING explain waiting, recovery, and rollout.

2. **Critical findings**

   - **[Makefile.parley:8](/Volumes/TestScratch/review-checkouts/fc89e8224a9f19b3/Makefile.parley:8):** prerequisite entry bypasses ownership, as detailed above. Move enforcement to protected-target execution and extend the coverage guard beyond target-name enumeration.

3. **Important findings**

   None.

4. **Minor findings**

   None.

5. **Test coverage notes**

   - All **27 direct Python tests passed**.
   - The new competing-run regression **failed against the pinned base**, confirming it detects the original defect.
   - Killing the lease-owning Make process in a real gated Make/Neovim chain retained the lease while the harness remained alive.
   - The mapped harness run passed except scratch-placement checks caused by review-provided `TMPDIR` residing inside the checkout. All **10 scratch-placement checks passed** when rerun with external scratch. Final censuses were clean.
   - The prerequisite-entry reproduction demonstrates missing regression coverage.
   - The recorded full-suite result remains independently unverified; the plan explicitly requires its pass before landing.

6. **Architectural notes**

   | Principle | Result |
   |---|---|
   | ARCH-DRY | Pass — shared lease owner. |
   | ARCH-PURE | Pass — new code is IO glue; selection remains pure. |
   | ARCH-PURPOSE | **Flag** — prerequisite entry retains the original failure class. |
   | ARCH-MOCK | Pass — recorded census seam and real process/lock conformance retained. |
   | ARCH-CONSTRAINTS | Pass — constant lease footprint and cancellable waiting. |
   | ARCH-SECURE | Pass — inode validation, no-follow opening, and argv execution. |
   | ARCH-ORDER | **Flag** — target execution can bypass ownership admission. |
   | ARCH-FUNERAL | Pass — fixed lock file ends with checkout removal; descriptors release ownership. |
   | ARCH-EVOLVE | Pass — no persisted application-format change. |

7. **Plan revision recommendations**

   Add a `## Revisions` entry specifying that ownership applies to protected targets reached directly, through prerequisites, or as default goals. Require controlled regressions for those entry paths and retain the existing lifetime and dry-run guarantees.

<!-- sdlc-review-usage [{"version":1,"intent":{"disposable_root":true,"id":"6b22dcb8-6eb5-429b-bc56-6050b3e7e02f","repository":"github.com/xianxu/parley.nvim","issue_id":"000409","recipe":"milestone-review","round":1,"attempt":1,"agent":"codex","root":"/Volumes/TestScratch/review-checkouts/fc89e8224a9f19b3","reviewed_head":"aae4e70e14ac4b1eac5aa10da7bc94836e8bcb0a","slot":"parley.nvim:3","requested_at":"2026-10-22T18:41:07.471911Z"},"phase":"finished","pid":37820,"started_at":"2026-10-22T18:41:08.04492Z","finished_at":"2026-10-22T18:44:47.576653Z","session_id":"01a164ea-c127-7993-9a3a-47d2ae48f9d4","outcome":"returned"}] -->

---

## Re-review — 2026-10-22T12:03:26-07:00 (SHIP)

| field | value |
|-------|-------|
| issue | 409 — Test orphan reaper kills an active targeted run in the same checkout |
| repo | parley.nvim |
| issue file | workshop/issues/000409-test-orphan-reaper-kills-an-active-targeted-run-in-the-same-checkout.md |
| boundary | whole-issue close |
| milestone | — |
| window | 4b8e61ed5f5b5b3ab969bc3df6314dac442e753c..92168f8e0df941de0c7ca17ea201071d3a9ace00 |
| command | sdlc close --issue 409 |
| reviewer | codex (openai; author openai) |
| isolation | fenced |
| timestamp | 2026-10-22T12:03:26-07:00 |
| verdict | SHIP |

## Review

```verdict
verdict: SHIP
confidence: high
```

The pinned implementation satisfies the ownership contract and fixes BR-1 across direct, prerequisite-chain, and default-goal entry. No new blocking findings. The recorded full-suite pass and green CI remain separate landing requirements; this review does not claim those results.

```findings
dispose:
  - id: BR-1
    disposition: addressed
    note: |
      Makefile.parley:14-19 unconditionally wraps protected targets and guards internal bodies before effects. Alias-chain and default-goal regressions pass at the pinned head; both fail with “second run entered instead of waiting” when the prior Makefile and lease helper are restored together in a disposable checkout, removed after testing.
```

1. **Strengths**

   - One target registry supplies public wrappers and guarded internal bodies.
   - Make and standalone live census share the lease implementation.
   - Gated process tests verify waiting before scratch mutation, cancellation, descendant lifetime, independent checkouts, and retained orphan cleanup.
   - Atlas and TOOLING document ownership, recovery, dry runs, and rollout.

2. **Critical findings**

   None.

3. **Important findings**

   None.

4. **Minor findings**

   None.

5. **Test coverage notes**

   - All **32 direct Python tests passed**.
   - BR-1’s alias/default regressions failed against the prior implementation, confirming meaningful regression coverage.
   - The mapped `infra/test_harness` run passed except scratch-placement assertions caused by review-provided `TMPDIR` residing inside the checkout. All **10 scratch-placement checks passed** with external scratch.
   - Both final censuses were clean.
   - Lint passed: **0 warnings/errors across 822 files**.
   - `git diff --check` passed; tracked files remain unchanged.

6. **Architectural notes for upcoming work**

   | Principle | Assessment |
   |---|---|
   | ARCH-DRY | Pass — shared helper and target registry. |
   | ARCH-PURE | Pass — lease code remains IO glue; process selection remains pure. |
   | ARCH-PURPOSE | Pass — admission now covers protected-target execution across entry paths. |
   | ARCH-MOCK | Pass — recorded process observations and gated real-process conformance exercise the production seams. |
   | ARCH-CONSTRAINTS | Pass — constant lease footprint, cancellable waiting, existing bounded test fan-out. |
   | ARCH-SECURE | Pass — descriptor/inode validation, no-follow creation, argv execution, explicit refusal. |
   | ARCH-ORDER | Pass — admission precedes effects; tests control competing runs and owner/descendant exit ordering. |
   | ARCH-FUNERAL | Pass — descriptors release ownership; the fixed lock file ends with checkout removal. |
   | ARCH-EVOLVE | Pass — no persisted application-format change. |

   The Core concepts table matches the changed entities and their integration classification. Atlas covers the new architectural surface. No new public command, flag, or configuration invocation requires a README addition.

7. **Plan revision recommendations**

   None. Existing revisions describe the target-execution correction and prerequisite ordering accurately.

<!-- sdlc-review-usage [{"version":1,"intent":{"disposable_root":true,"id":"9ad775b5-0ddd-4b48-9cd6-70c299346c00","repository":"github.com/xianxu/parley.nvim","issue_id":"000409","recipe":"milestone-review","round":2,"attempt":1,"agent":"codex","root":"/Volumes/TestScratch/review-checkouts/c1e036218a27396a","reviewed_head":"92168f8e0df941de0c7ca17ea201071d3a9ace00","slot":"parley.nvim:3","requested_at":"2026-10-22T18:59:51.215648Z"},"phase":"finished","pid":15402,"started_at":"2026-10-22T18:59:51.433233Z","finished_at":"2026-10-22T19:03:26.024036Z","session_id":"01a164fb-e3f9-7b30-8d84-b17e0e5331de","outcome":"returned"}] -->
