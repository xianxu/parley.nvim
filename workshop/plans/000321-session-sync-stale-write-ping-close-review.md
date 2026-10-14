# Boundary Review — parley.nvim#321 (whole-issue close)

| field | value |
|-------|-------|
| issue | 321 — session-sync: ping once after 15 minutes without a write while deliveries remain owed (pair#530 companion) |
| repo | parley.nvim |
| issue file | workshop/issues/000321-session-sync-stale-write-ping.md |
| boundary | whole-issue close |
| milestone | — |
| window | 5a15ecabfe958cd8733d9e20de698acdf04460dd..92df9030c60175576c3b1e2e39e1682e1b7b9391 |
| command | sdlc close --issue 321 |
| reviewer | codex |
| isolation | fenced |
| timestamp | 2026-10-13T23:02:08-07:00 |
| verdict | REWORK |

## Review

```verdict
verdict: REWORK
confidence: high
```

The revised write-age behavior works for valid timestamps, including threshold boundaries, delivery changes, and asynchronous write/lock races. However, malformed timestamps can still trigger pings, violating the explicit unknown-status contract. Coverage, architecture, and documentation gaps also remain. The required vocabulary check could not complete in this checkout.

Done-when: current — its write-age, fallback, one-shot, override, and admission clauses still cover the revised LastWrite-only contract.

1. **Strengths**

   - Reuses the existing watcher and Couch seam without adding timers or queues.
   - Preserves the owed-band clock separately from ping admission.
   - Tests both query phases against both file writes and operator-lock acquisition.
   - The absent-write sentinel prevents delivery changes from rearming a ping.

2. **Critical findings**

   - `lua/parley/session_sync.lua:342`: invalid calendar timestamps are accepted as staleness evidence. With `LastWrite="2020-00-00T00:00:00Z"`, valid obligations, and a quiet owner, a direct execution produced one ping. Validate timestamps strictly through the shared parser and add regression tests.

3. **Important findings**

   - `lua/parley/session_sync.lua:341`: **ARCH-PURE** — baseline selection, generation identity, and threshold admission remain embedded in the asynchronous I/O callback. Extract a deterministic decision helper and test it directly.
   - `tests/integration/session_sync_spec.lua:552`: every default-boundary test clears the configured value. These tests exercise the runtime fallback and would pass if `config.lua` reverted to five minutes. Exercise the shipped configuration too.
   - `lua/parley/config.lua:487` and `construct/generated/vocabulary/issue.json:108`: documentation updates are incomplete. README has no update for the changed ping setting; atlas has no corresponding update for the added tracker `area`/`severity` fields and repository-enum metadata.

4. **Minor findings**

   None.

5. **Test coverage notes**

   - Targeted session-sync suite: **58 passed**.
   - Direct malformed-timestamp reproduction: **incorrect ping confirmed**.
   - `git diff --check`: passed.
   - Full `make test`: lint and unit stages passed; six integration/architecture files failed: `scratch_placement`, `packaging_boot`, `packaging_vm`, `starter_config`, `starter_project`, and `zero_config`. Failures concern scratch/profile isolation; the review environment places `TMPDIR` inside this repository. These are not attributed to this diff.
   - `make check-vocabulary`: failed because the exporter reported `no vocabulary noun "issue"`. Generated-output freshness remains unverified.
   - Orphan checking was unavailable because `ps` was unavailable. Test-created repository files were removed; the working tree is clean.

6. **Architectural notes**

   - **ARCH-DRY: pass** — existing query, timestamp, actor, and watcher machinery is reused.
   - **ARCH-PURE: flag** — the new admission policy needs separation from clock/filesystem/process operations.
   - **ARCH-PURPOSE: flag** — ordinary write-age behavior is delivered, but “invalid LastWrite remains unknown” is not fully enforced.
   - Both Core concepts entities exist at their stated paths and are modified. The table omits their required PURE/INTEGRATION classifications.

7. **Plan revision recommendations**

   Add a `## Revisions` entry naming the pure admission helper and integration owner, and classify both existing Core concepts rows. Record strict timestamp validation, shipped-default regression coverage, and the documentation updates as remaining work.

```findings
findings:
  - id: new
    severity: Critical
    family: invalid-time-must-remain-unknown
    title: |
      Invalid LastWrite timestamps can trigger stale-work pings
    detail: |
      lua/parley/session_sync.lua:342 trusts parse_time, whose implementation at lines 109–126 accepts invalid calendar dates, clock components, offsets, and malformed fractional syntax. A direct execution with LastWrite="2020-00-00T00:00:00Z", valid owed work, and a quiet owner sent one ping. The complete timestamp-consumer family in this probe is LastWrite at line 342, fallback Owed.At at line 332, and LastActivity at line 357. Validate through the shared parser and cover impossible dates, out-of-range times/offsets, and malformed fractions; the new test at tests/integration/session_sync_spec.lua:648 only checks "invalid".
  - id: new
    severity: Important
    family: admission-policy-pure-boundary
    title: |
      ARCH-PURE: separate ping admission policy from the query callback
    detail: |
      lua/parley/session_sync.lua:341–346 mixes baseline selection, generation identity, and threshold admission with configuration access, the clock, and lock-file reads; the related actor admission at lines 355–359 also combines policy and I/O. Extract deterministic decisions over supplied observations and retain queries, lock/mtime reads, state mutation, and sending in the shell. These are the two admission sites in this window. Test the policy without timers or subprocesses, and update the Core concepts table at workshop/issues/000321-session-sync-stale-write-ping.md:131 with PURE/INTEGRATION kinds.
  - id: new
    severity: Important
    family: shipped-default-regression-coverage
    title: |
      Boundary tests bypass the shipped fifteen-minute default
    detail: |
      tests/integration/session_sync_spec.lua:552 sets session_sync_ping_minutes=nil, while the outer fixture at line 84 sets it to five. Consequently the new boundary tests cover only session_sync.lua:344's fallback; reverting config.lua:487 to five would leave them green. The complete default family is the shipped configuration and the runtime fallback. Exercise the shipped value at 899 and 900 seconds, retaining separate fallback and explicit-override coverage.
  - id: new
    severity: Important
    family: changed-surface-documentation
    title: |
      README and atlas updates are missing for changed configuration and tracker surfaces
    detail: |
      README.md is unchanged despite the session_sync_ping_minutes default change at lua/parley/config.lua:487. The generated vocabulary also adds area/severity card fields and setters at construct/generated/vocabulary/issue.json:108–119, plus repository-enum metadata at line 25; the only atlas change covers session-sync. These fields affect existing vocabulary-driven tracker consumers, including lua/parley/issue_cards.lua:172 and :375. Enumerated documentation gaps are the ping configuration/default, area and severity tracker fields/setters, and .sdlc/vocabulary.json repository-enum convention. Add appropriate README guidance and update the tracker atlas documentation.
```
