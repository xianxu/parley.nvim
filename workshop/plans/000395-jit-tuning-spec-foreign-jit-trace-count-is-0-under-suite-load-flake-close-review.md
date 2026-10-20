# Boundary Review — parley.nvim#395 (whole-issue close)

| field | value |
|-------|-------|
| issue | 395 — jit_tuning_spec foreign JIT trace count is 0 under suite load (flake) |
| repo | parley.nvim |
| issue file | workshop/issues/000395-jit-tuning-spec-foreign-jit-trace-count-is-0-under-suite-load-flake.md |
| boundary | whole-issue close |
| milestone | — |
| window | 877d904c4a29b424734a845e2a863edaba152deb..f674d4f0ac1eae1be97f5ff3fdb72fac3ea50a66 |
| command | sdlc close --issue 395 |
| reviewer | claude (anthropic; author anthropic) |
| isolation | checkout |
| timestamp | 2026-10-19T19:52:14-07:00 |
| verdict | SHIP |

## Review

Reviewing the single test-file diff; checking the sibling JIT-trace helpers and then running the spec.

Running the spec on the installed nvim 0.11.7 now.

```verdict
verdict: SHIP
confidence: high
```

This window changes one file, `tests/unit/jit_tuning_spec.lua`, and the change does what the issue asks. The old test kept a single `foreign_trace` slot, and any abort, flush or start from another source cleared it. Now every foreign trace id goes into a set, and each foreign abort's reason is read from `jit.vmdef.traceerr`. The assertions are split three ways: `own == 0` starts, `foreign > 0` starts, and `foreign_stops > 0`. That last one is waived only when every foreign abort is the #294 error `failed to allocate mcode memory`. Every assertion now carries a message with the counts and up to five abort reasons.

I ran `make test-spec SPEC=infra/test_harness` on the installed nvim 0.11.7 (LuaJIT 2.1.1741730670). All 9 cases in `jit_tuning_spec` passed. The run did have 8 failures, all in `tests/arch/scratch_placement_spec.lua`. They come from the review checkout sitting under `/Volumes/TestScratch`, so they are unrelated to this change. I checked that `traceerr[27]` on that LuaJIT is exactly `failed to allocate mcode memory`, so the waiver's string comparison matches. Nothing blocks shipping; there are three Minor notes.

1. **Strengths**
   - `jit_tuning_spec.lua:100-115`: tracking ids in a set, clearing them on `stop`/`abort` and resetting the set on `flush` fixes the single-slot problem. A start from another source can no longer hide a later foreign stop.
   - The abort reason is decoded the same way LuaJIT's own `jit/dump.lua` does it (`traceerr[otr]` formatted with `oex`). An unknown code falls back to `tostring(otr)`, so decoding can't crash the child.
   - The waiver is narrow. It needs at least one abort, and every abort must be the mcode error. `own == 0` and `foreign > 0` starts are still asserted in every case, so a global or per-chunk `jit.off` still fails the test.
   - When an assertion fails, the message includes the counts and abort reasons (`seen`), so the next flake can be diagnosed from the log alone.

2. **Critical findings:** none.

3. **Important findings:** none.

4. **Minor findings**
   - **No fixture enters the waiver branch.** The `unplaceable` waiver at `jit_tuning_spec.lua:145-149` only runs when the system is under load on an older LuaJIT. If the matched string drifted, the old flake would come back; the test would not start passing wrongly. The family in this window is just this one predicate.
   - **Same exposure in a sibling test.** `tests/unit/document_sequence_spec.lua:697` asserts `result.compiled > 0` in a child VM on the installed LuaJIT. It has no allowance for the mcode-allocation abort, so it can flake the same way under load on 0.11.7. It is out of this issue's scope; it is the only other instance in the tree.
   - **Done-when evidence is a proxy.** The "passes under a loaded full suite" clause is backed by a 120-way parallel stress of the child script, not by a recorded loaded full-suite run. That is a reasonable stand-in, but the claim is not directly measured.

5. **Test coverage notes:** The red checks in the Log are sound by construction:
   - `jit.off(foreign, true)` stops any foreign start, so `foreign > 0` fails.
   - Removing the forced `requires_interpreter` lets the document pipeline compile, so `own > 0`.

   The `hit mcode limit (retrying)` error (`traceerr[29]`) is retried before LuaJIT fires its abort event, so it should never reach the abort list and break the waiver.

6. **Architectural notes**
   - **ARCH-DRY: pass.** The code that spawns the child VM and attaches the trace hook is repeated between this spec and `document_sequence_spec.lua:656-695`. That repetition predates this window. If a third JIT-in-child test appears, move it into a helper under `tests/helpers/`.
   - **ARCH-PURE: pass.** The change is test-only and adds no business logic.
   - **ARCH-PURPOSE: pass.** The issue's purpose (no flake from a single trace failing to complete, with the policy still proven) is fully delivered. The sibling test above is a separate site, not a deferred part of this issue.
   - **ARCH-EVOLVE: pass.** No persisted format is touched. The child's JSON output is internal to the test.
   - **Docs gate:** no new user-facing or architectural surface, so no atlas or README update is needed.

7. **Plan revision recommendations:** none. The plan's checklist matches the code.

```findings
findings:
  - id: new
    severity: Minor
    kind: defect
    family: jit-trace-oracle-ignores-mcode-defect
    title: |
      Sibling child-VM oracle document_sequence_spec.lua:697 asserts compiled > 0 with no mcode-allocation exemption
    detail: |
      Same flake class as this issue: on the installed LuaJIT 0.11.7 under load, every trace can abort with
      'failed to allocate mcode memory', so compiled stays 0. It is the only other instance in the tree.
      Consider the same id-set tracking plus #294 abort classification there.
  - id: new
    severity: Minor
    kind: defect
    family: exemption-branch-without-fixture
    title: |
      The unplaceable (#294) exemption predicate at jit_tuning_spec.lua:145-149 is reached only under real load
    detail: |
      No deterministic fixture exercises the exemption. If the text drifts, the failure is safe (the flake returns,
      the test does not wrongly pass), but the classification is unpinned. It is the only such predicate in this window.
  - id: new
    severity: Minor
    kind: defect
    family: done-when-evidence-proxy
    title: |
      The Done-when clause about a loaded full suite is evidenced by a 120-way child-script stress, not a full-suite run
    detail: |
      The Log records stress runs and isolated make test-spec runs on both runtimes. No loaded full-suite pass is
      recorded. Acceptable as a proxy; noted for the close record.
```

<!-- sdlc-review-usage [{"version":1,"intent":{"disposable_root":true,"id":"b4f8644a-331b-49da-993d-554c8cee2ac9","repository":"github.com/xianxu/parley.nvim","issue_id":"000395","recipe":"small-diff-review","round":1,"attempt":1,"agent":"claude","root":"/Volumes/TestScratch/review-checkouts/6297bbbcdb7ffa4d","reviewed_head":"f674d4f0ac1eae1be97f5ff3fdb72fac3ea50a66","slot":"parley.nvim:3","requested_at":"2026-10-20T02:46:10.635475Z"},"phase":"finished","pid":44164,"started_at":"2026-10-20T02:46:10.868561Z","finished_at":"2026-10-20T02:52:14.106756Z","session_id":"a1f06a1e-a2ea-4725-acc1-06a957d2bcee","outcome":"returned"}] -->
