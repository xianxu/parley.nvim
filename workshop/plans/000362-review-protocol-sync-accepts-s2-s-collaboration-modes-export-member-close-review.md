# Boundary Review — parley.nvim#362 (whole-issue close)

| field | value |
|-------|-------|
| issue | 362 — Review-protocol sync accepts S2's collaboration-modes export member |
| repo | parley.nvim |
| issue file | workshop/issues/000362-review-protocol-sync-accepts-s2-s-collaboration-modes-export-member.md |
| boundary | whole-issue close |
| milestone | — |
| window | 75c795b448fbe7fdd8c38785f2c7c64001ef91c4..70ec26d438345fa93d0519fb1a8d115e812245af |
| command | sdlc close --issue 362 |
| reviewer | codex |
| isolation | fenced |
| timestamp | 2026-10-16T18:12:54-07:00 |
| verdict | REWORK |

## Review

```verdict
verdict: REWORK
confidence: high
```

The export validator, snapshot generation, and ownership checks work as specified. All 16 Python tests and the mapped review suite passed; the packaged members match producer commit `1db0ec0` byte for byte, and its reconstructed source passes `--check`. Shipping is blocked by incompatible instructions in the composed local prompt and incomplete acceptance criteria.

Done-when: stale — the revision adds an absent-member CLI notice, but the acceptance clauses cover only exports containing the member.

```findings
findings:
  - id: new
    severity: Critical
    kind: defect
    family: prompt-adapter-capability-contract
    title: |
      The imported collaboration contract requires operations the local adapter cannot perform
    detail: |
      lua/parley/skills/review/collaboration-modes.md:72 requires every discussion question to create a side doc; discussion is now the default even without frontmatter (line 29). Thus an ordinary local 🤖[why?] request can no longer be answered consistently: local-adapter.md:10-16 permits only one propose_edits call, and lua/parley/skill_invoke.lua:567-569 forcibly binds that call to the submitted artifact. No available write operation can create the required side doc. Removing the marker and inserting its prescribed link would leave a nonexistent target; answering inline violates the new contract.
      The complete affected capability family in this window is discussion question/decision-note/nested side-doc creation (lines 72, 105-107, 155-157), chat answer creation and follow-up writes (128-138), cross-document approval folds (93, 202-218), and retry/relink/orphan discovery (205-222). Chat additionally requires a change baseline that local-adapter.md:18-20 explicitly lacks, while marker-free chat submissions are skipped by review/init.lua's existing precheck. These instructions are also embedded in generated SKILL.md. Reconcile the Parley-owned local compatibility policy with these capabilities, document the supported behavior, and add regression coverage for default questions and explicit collaboration/chat handling. ARCH-PURPOSE: successful concatenation does not establish a usable local contract.
  - id: new
    severity: Important
    kind: defect
    family: acceptance-contract-coverage
    title: |
      Done-when omits the newly required old-export notice
    detail: |
      workshop/issues/000362-review-protocol-sync-accepts-s2-s-collaboration-modes-export-member.md:33-36 only requires tests and synchronization for an export containing collaboration modes. The revision at lines 133-135 adds a required notice when the member is absent, implemented in scripts/sync-review-protocol.py:156-158. The entire uncovered acceptance family is old-v1 success plus the notice during normal sync and --check; tests/unit/review_protocol_export_test.py:296-305 already exercises both. Update Done-when to require those outcomes explicitly.
```

1. **Strengths**

   - Composition order is deterministic even when manifest members are reversed.
   - Real CLI tests cover digest corruption, read-only drift detection, stale outputs, symlink refusal, and preservation of the local adapter.
   - Snapshot provenance independently checks out against the producer pin. Both README and atlas were updated.

2. **Critical findings**

   - The local prompt introduces unsupported multi-document behavior. Resolve the adapter contract and test the affected modes before shipping.

3. **Important findings**

   - Update the issue’s acceptance clauses to include old-export compatibility and its notice in both CLI modes.

4. **Minor findings**

   - None.

5. **Test coverage notes**

   - Passed: 16 Python contract tests, `make test-spec SPEC=modes/review`, exact producer-source `--check`, and range `git diff --check`.
   - The mapped suite reported no surviving test processes.
   - Composition tests assert text presence and ordering; they do not establish that the imported instructions are executable through the local adapter.

6. **Architectural notes**

   - **ARCH-DRY: pass.** Existing validator, renderer, and preflight mechanisms are reused.
   - **ARCH-PURE: pass.** Validation/rendering remain pure; filesystem work stays in the CLI shell.
   - **ARCH-PURPOSE: flag.** The export → snapshot → runtime prompt chain derives correctly, but its local consumer cannot fulfill the newly imported routing contract.
   - No Core concepts table requires reconciliation.

7. **Plan revision recommendations**

   - Add a `## Revisions` entry defining local behavior for default discussion, explicit collaboration, and chat, including unsupported operations and regression evidence.
   - Extend `## Done when` with successful old-v1 sync and `--check`, each emitting the absent-member notice.

<!-- sdlc-review-usage [{"version":1,"intent":{"disposable_root":true,"id":"a54f134a-81d2-436e-9624-04f06e3c31fa","repository":"github.com/xianxu/parley.nvim","issue_id":"000362","recipe":"small-diff-review","round":1,"attempt":1,"agent":"codex","root":"/Users/xianxu/Library/Caches/sdlc/review-checkouts/25a90caf93d724e6","reviewed_head":"70ec26d438345fa93d0519fb1a8d115e812245af","slot":"parley.nvim:1","requested_at":"2026-10-17T01:11:06.561409Z"},"phase":"finished","pid":44706,"started_at":"2026-10-17T01:11:06.669296Z","finished_at":"2026-10-17T01:12:51.667835Z","session_id":"01a14769-9fd0-79f0-82ca-8113e8801376","outcome":"returned"}] -->

---

## Re-review — 2026-10-16T19:28:13-07:00 (REWORK)

| field | value |
|-------|-------|
| issue | 362 — Review-protocol sync accepts S2's collaboration-modes export member |
| repo | parley.nvim |
| issue file | workshop/issues/000362-review-protocol-sync-accepts-s2-s-collaboration-modes-export-member.md |
| boundary | whole-issue close |
| milestone | — |
| window | 75c795b448fbe7fdd8c38785f2c7c64001ef91c4..5789ac0f26392fb45a8c9121f323b3ddbc980da5 |
| command | sdlc close --issue 362 |
| reviewer | codex |
| isolation | fenced |
| timestamp | 2026-10-16T19:28:13-07:00 |
| verdict | REWORK |

## Review

```verdict
verdict: REWORK
confidence: high
```

The export extension, composition order, documentation, and local edit guards are well covered. BR-2 is addressed. BR-1 remains blocking because some collaboration declarations silently become discussion, bypassing both chat admission and edit protection.

```findings
dispose:
  - id: BR-1
    disposition: not-addressed
    note: |
      The local-adapter override and reachable admission/proposal guards correct the original mismatch for recognized declarations; removing those fixes produces regression failures. However, collaboration_value.lua:128-173 recognizes only column-zero field lines. Frontmatter containing either `  collaboration-mode: chat` or `{collaboration-mode: chat}` returns no value and no error. Direct execution confirms resolve marks the body editable discussion and validate_edits permits replacing its text. Thus the promised chat protection remains incomplete. For family prompt-adapter-capability-contract, state and enforce the general rule: distinguish genuinely absent routing from unsupported or malformed declarations; decode supported representations and visibly refuse unsupported ones. Enumerate declaration representations and add parser, admission, and real-write regression coverage. ARCH-PURPOSE, ARCH-SECURE.
  - id: BR-2
    disposition: addressed
    note: |
      The pinned issue diff adds Done-when lines 37-39 requiring old-v1 sync and --check success, with a notice from each command. This matches scripts/sync-review-protocol.py:156-158 and test_old_v1_cli_reports_absent_collaboration_modes at tests/unit/review_protocol_export_test.py:296-305, which exercises both commands and passed. This is a prose-only acceptance correction.
```

1. **Strengths**

   - Export validation preserves strict role/path checks and applies digest verification to the new member.
   - Composition tests verify round → grammar → collaboration modes → selected review modes → local adapter, including standalone packaging.
   - The invocation-owned guard rejects protected, crossing, overlapping, and multiple-call proposals before effects.
   - README and atlas explain the approved local compatibility policy and its limitations.

2. **Critical findings**

   **BR-1 — routing declarations can bypass chat protection.** At `lua/parley/skills/review/collaboration_value.lua:128`, field recognition excludes indented root keys and root-flow mappings. Line 173 treats these as absence; `collaboration.lua:23` then defaults to discussion.

   Reproduced with:

   ```markdown
   ---
     collaboration-mode: chat
   ---
   secret 🤖[why?]
   ```

   `resolve` reports editable discussion, and `validate_edits` permits `secret` → `CHANGED`. The root-flow declaration produces the same result. Recognize these forms or refuse them visibly; default only when routing is genuinely absent. Cover the declaration-recognition class across parser, admission, and tool effects.

3. **Important findings**

   None beyond the maintained BR-1 blocker.

4. **Minor findings**

   None.

5. **Test coverage notes**

   - Python export contracts: **16 passed**.
   - `make test-spec SPEC=modes/review`: **passed**; process census clean.
   - Invocation integration: **49 passed** in a disposable pinned-head checkout.
   - Removing the proposal guard caused **4 failures**; restoring pre-fix admission caused **4 failures**. The disposable checkout was removed.
   - Existing tests omit the declaration-recognition bypass above.
   - `git diff --check` passed. The full suite was not independently rerun.

6. **Architectural notes for upcoming work**

   - **ARCH-DRY — pass:** one routing result supplies admission, notices, filtering, and permission.
   - **ARCH-PURE — pass:** routing/value logic and tests are pure; IO remains in callers.
   - **ARCH-PURPOSE — flag:** BR-1 leaves the chat-protection contract incomplete.
   - **ARCH-MOCK — pass:** integration tests exercise existing provider/tool seams and scratch files.
   - **ARCH-CONSTRAINTS — pass:** no new concurrency or external dependency; existing tool limits remain.
   - **ARCH-SECURE — flag:** unrecognized routing input becomes permissive fabricated default state.
   - **ARCH-ORDER — pass:** proposal rejection precedes effects; the single-batch restriction has regression evidence.
   - **ARCH-FUNERAL — pass:** generated output is replaced in place; no new accumulating runtime artifact family.

7. **Plan revision recommendations**

   Add a `## Revisions` entry defining “absent versus unsupported routing,” enumerating declaration forms and required regression coverage. Reopen the completed parser/admission verification items until that rule holds. Add explicit PURE/INTEGRATION kinds to the Core concepts tables; the listed entities otherwise exist at their stated paths.

<!-- sdlc-review-usage [{"version":1,"intent":{"disposable_root":true,"id":"4adbe885-05fc-4eea-906b-65301257cfb7","repository":"github.com/xianxu/parley.nvim","issue_id":"000362","recipe":"milestone-review","round":2,"attempt":1,"agent":"codex","root":"/Users/xianxu/Library/Caches/sdlc/review-checkouts/7f95cbb77a770a55","reviewed_head":"5789ac0f26392fb45a8c9121f323b3ddbc980da5","slot":"parley.nvim:1","requested_at":"2026-10-17T02:26:03.487465Z"},"phase":"finished","pid":34637,"started_at":"2026-10-17T02:26:03.592884Z","finished_at":"2026-10-17T02:28:12.455932Z","session_id":"01a147ae-3e2c-77b3-8503-bec981baaf24","outcome":"returned"}] -->

---

## Re-review — 2026-10-16T20:25:34-07:00 (REWORK)

| field | value |
|-------|-------|
| issue | 362 — Review-protocol sync accepts S2's collaboration-modes export member |
| repo | parley.nvim |
| issue file | workshop/issues/000362-review-protocol-sync-accepts-s2-s-collaboration-modes-export-member.md |
| boundary | whole-issue close |
| milestone | — |
| window | 75c795b448fbe7fdd8c38785f2c7c64001ef91c4..21b756db6e71597fed48ada97c69c5e301f4058d |
| command | sdlc close --issue 362 |
| reviewer | codex |
| isolation | fenced |
| timestamp | 2026-10-16T20:25:34-07:00 |
| verdict | REWORK |

## Review

```verdict
verdict: REWORK
confidence: high
```

The export support, local compatibility policy, and chat protection are implemented and regression-tested. BR-1 is addressed. One new Important finding blocks close: quadratic frontmatter scanning stalls the editor synchronously.

```findings
dispose:
  - id: BR-1
    disposition: addressed
    note: |
      local-adapter.md:10-18 overrides incompatible imported operations; admission and invocation-owned proposal validation enforce chat protection. All 64 invocation tests pass at head. Restoring the pre-correction parser in a disposable copy produces 12 regression failures.
  - id: BR-2
    disposition: addressed
    note: |
      Issue Done when lines 37-39 explicitly require old-v1 sync and --check notices. test_old_v1_cli_reports_absent_collaboration_modes verifies both commands; all 16 Python contract tests pass.
findings:
  - id: new
    severity: Important
    kind: defect
    family: synchronous-input-work-bounds
    title: |
      Frontmatter comment scanning causes quadratic editor stalls
    detail: |
      ARCH-CONSTRAINTS: lua/parley/skills/review/collaboration_value.lua:13 copies and searches the entire preceding prefix for every character, even in unrelated metadata. Parsing {'---', 'notes: '..string.rep('a', n), '---', 'body'} under LuaJIT took 0.279/1.110/4.471 seconds for 5/10/20 KB. review_send.lua:66 and review/init.lua:590 call this synchronously, so a submission can repeat several seconds of editor blocking before generation. Track the preceding non-whitespace character incrementally, inspect sibling scanners for repeated-prefix work, and add representative scaling coverage.
```

Done-when: current — it covers export compatibility and notices, local in-place answers, immutable chat sections, and routing validation.

1. **Strengths**
   - Export composition fixes the member order independently of manifest order; digest, corruption, stale-output, and symlink cases have coverage.
   - The local adapter explicitly reconciles the canonical protocol with single-artifact capabilities.
   - Chat protection runs before tool effects and rejects crossing spans, overlapping edits, and multiple proposal batches.
   - README and atlas document the new behavior and limitations.

2. **Critical findings**

   None.

3. **Important findings**

   The synchronous parser stall above. Replace the repeated prefix search with incremental scanner state.

4. **Minor findings**

   None.

5. **Test coverage notes**

   Passed all 16 Python export tests, mapped `modes/review` tests, 64 real invocation tests, and range whitespace checks. Restoring the earlier parser produced 12 invocation failures. The disposable copy was removed. Functional coverage is strong; input-scale coverage is missing.

6. **Architectural notes**

   - **ARCH-DRY — pass:** routing is shared across admission, resubmission, and permission checks.
   - **ARCH-PURE — pass:** listed pure entities exist and have direct tests without IO.
   - **ARCH-PURPOSE — pass:** packaged composition and local capability reconciliation are delivered.
   - **ARCH-MOCK — pass:** injected provider responses exercise the production tool/filesystem path.
   - **ARCH-CONSTRAINTS — flag:** measured quadratic work blocks the interactive submission path.
   - **ARCH-SECURE — pass:** unsupported declarations refuse visibly; snapshot permission checks precede writes.
   - **ARCH-ORDER — pass:** the correction adds no persistent event state; proposal batches are constrained before effects.
   - **ARCH-FUNERAL — pass:** generated package files are replaced in place; routing creates no durable runtime artifacts.

7. **Plan revision recommendations**

   Add a `## Revisions` entry defining linear frontmatter scanning, representative input sizes, and scaling verification for synchronous local review admission.

<!-- sdlc-review-usage [{"version":1,"intent":{"disposable_root":true,"id":"9de6d1e1-4936-452a-8312-88f6fca44412","repository":"github.com/xianxu/parley.nvim","issue_id":"000362","recipe":"milestone-review","round":3,"attempt":1,"agent":"codex","root":"/Users/xianxu/Library/Caches/sdlc/review-checkouts/f07e4555abd9f3f6","reviewed_head":"21b756db6e71597fed48ada97c69c5e301f4058d","slot":"parley.nvim:1","requested_at":"2026-10-17T03:22:45.42142Z"},"phase":"finished","pid":45565,"started_at":"2026-10-17T03:22:45.543142Z","finished_at":"2026-10-17T03:25:32.506179Z","session_id":"01a147e2-26a9-7b02-899e-185422223da4","outcome":"returned"}] -->
