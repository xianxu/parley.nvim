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
