# Boundary Review — parley.nvim#229 (whole-issue close)

| field | value |
|-------|-------|
| issue | 229 — Stream display chunks are discarded silently when the pending session invalidates |
| repo | parley.nvim |
| issue file | workshop/issues/000229-stream-display-chunks-are-discarded-silently-when-the-pending-session-invalidates.md |
| boundary | whole-issue close |
| milestone | — |
| window | 7762f5ed3250dcb14863617c89cbd3e5d81e0480..af12fe1db4fdeaea47cb9eefee7acd8058c82208 |
| command | sdlc close --issue 229 |
| reviewer | claude |
| isolation | checkout |
| timestamp | 2026-10-15T19:04:47-07:00 |
| verdict | SHIP |

## Review

Diff reviewed; now checking the tasker reader guard in context and running the focused specs.

Focused specs pass. Now reverting the tasker fix to confirm the regression test goes red.

Regression test goes red without the fix. Next: a mutation check that the integrity oracle catches a dropped delta.

Oracle catches a dropped delta. Checking the follow-up issue #341 exists and the EOF double-delivery path.

```verdict
verdict: SHIP
confidence: high
```

This boundary delivers what issue #229 set out to do. Measurement showed that the scheduled writer with four silent early returns (`D.create_handler`) had no production caller. It was removed with all its orphans, and nothing in code, tests or atlas still references them. The arch ban in `tests/arch/document_ownership_spec.lua:95` stays as a guard. The one live path that could keep streaming after dropping bytes, a reader that throws inside the tasker, now ends the attempt with `<stream> reader failed`. The issue's main Done-when condition, "the buffer answer equals `qt.response` under a busy loop", is now an assertion against the real transport. I checked both claims by mutation in this checkout:

- **Tasker fix:** with `lua/parley/tasker.lua` reverted to base, the new supervision test fails. Restored, it passes.
- **Integrity spec:** with a dispatcher mutation that skips the handler for the 50th delta while `qt.response` still accumulates, `stream_integrity_spec` fails.

Focused specs at head all pass: tasker_supervision, tasker_run, stream_integrity, stream_view, and the document_ownership and buffer_mutation arch specs. Nothing blocks SHIP; there are only Minor notes.

**1. Strengths**
- **Real oracle with independent ground truth.** `tests/integration/stream_integrity_spec.lua:25` rebuilds the expected text from the fake's formula. It asserts `response == expected` first, then `answer == response`. So it checks both transport completeness and what lands in the buffer, rather than comparing the client with itself. Deltas split lines and carry multibyte UTF-8 across boundaries (`tests/fixtures/fake_cliproxy` `stream_deltas`).
- **The interference is real.** Edits above the answer land on every streamed write, plus a 3 ms busy slice. A minimum of 10 edits is asserted, and every inserted line is checked to survive.
- **Removal instead of patching dead code.** Removing the dead writer also takes away the issue's second Done-when concern for good. The cleanup reached `stream_position`, `helper.undojoin`, `stream_replace_at_line`, the traceability rows and the PURE_FILES arch list.
- **#182 compatibility kept.** In `lua/parley/tasker.lua:611-620`, a failed reader skips later data but still receives EOF, so the existing contract still holds.
- **Red-first regression.** I confirmed it independently: it fails 1 of 30 at base.

**2. Critical findings:** none.

**3. Important findings:** none.

**4. Minor findings**
- **The "EOF delivered once" comment is wrong on the error path** (`tasker.lua:609-610`). When libuv reports `(err, nil)`, `deliver` calls `read(stream, reader, err, nil)`, and then `stdout_callback` calls `read(stream, reader, nil, nil)` again, so EOF is delivered twice. The double delivery existed before this change, but the new comment now states the opposite.
- **A throwing stderr reader now stops a healthy stdout stream.** That is broader than "lost answer bytes" requires; this policy choice should be noted in the atlas.
- **ARCH-ORDER:** reader failure is recorded in a closure-local `failed_readers` and `io_error`, not as an `event(record, …)` on the attempt's state model. This matches the existing retention-limit pattern, but it adds one more flag outside the transition set.
- **#341 can't be checked from here.** The Plan says the two silent-stall paths were filed as #341, but no `workshop/issues/000341*` exists in the pinned head or in any local ref.
- **Test hygiene:** `vault.add_secret("cliproxyapi", "testkey")` is not restored in `after_each`. The harness isolates HOME, so the risk is low.

**5. Test coverage notes**
- The tasker test asserts the failure string and a single stop signal.
- No test checks end to end that `stdout reader failed` reaches the user as a visible generation outcome. That path relies on the existing failure-to-outcome mapping. A small dispatcher-level test (reader throws, then generation outcome is not `success`) would close it.
- The stream_view cursor-follow UI tests were deleted along with their writer; `helper.cursor_to_line` keeps a direct test.

**6. Architectural notes (each principle)**
- **ARCH-DRY: pass.** `expected_text` restates the fake's formula on purpose, as an independent oracle.
- **ARCH-PURE: pass.**
- **ARCH-PURPOSE: pass.** Both Done-when rows are delivered, and the stall paths are split out as a separate symptom.
- **ARCH-MOCK: pass.** The process-level stateful fake was extended behind the same HTTP seam that production uses.
- **ARCH-CONSTRAINTS: pass.**
- **ARCH-SECURE: pass.** It uses a test-only key in an isolated HOME.
- **ARCH-ORDER: minor note** (see above).
- **ARCH-FUNERAL: pass.** The fake process is reaped through `fixture_process.reap`, and nothing durable is created.

**Core concepts table:** all 7 rows match the diff (deleted, modified and new at the stated paths).

**Docs:** `atlas/chat/document.md` covers byte accounting. README needs no change because no user-facing surface was added.

**7. Plan revision recommendations**
- Optionally add a `## Revisions` note giving #341's location (repo and ref), so the "filed" claim can be checked from the issue branch.

```findings
findings:
  - id: new
    severity: Minor
    kind: defect
    family: comment-contract-drift
    title: |
      tasker read() comment claims EOF is delivered once, but the err path delivers it twice
    detail: |
      On (err, nil), deliver() calls read(stream, reader, err, nil), then the callback calls read(stream, reader, nil, nil) again (tasker.lua:629 and 644). This double delivery predates the change, but the new comment at tasker.lua:609-610 states the opposite. Fix the comment, or skip the second call when deliver already passed nil data.
  - id: new
    severity: Minor
    kind: defect
    family: attempt-state-outside-transition-model
    title: |
      Reader failure is tracked with closure flags (failed_readers, io_error), not an attempt event (ARCH-ORDER)
    detail: |
      This matches the existing retention-limit pattern, but it widens the set of flags kept outside the record's event model. Consider a reader_failed event. Also note in the atlas that a throwing stderr reader now stops an otherwise healthy stdout stream.
  - id: new
    severity: Minor
    kind: unverifiable
    family: plan-claim-evidence
    title: |
      Plan item "Filed #341 for the two silent-stall paths" cannot be verified in the pinned checkout
    detail: |
      Searching workshop/issues/ and git log --all for 000341 in the review checkout found nothing. Evidence that would answer it: the path or commit of #341 on main, or the tracker URL.
```

<!-- sdlc-review-usage [{"version":1,"intent":{"disposable_root":true,"id":"5c9dfbef-489b-43b1-94fd-2f2ada1c4f31","repository":"github.com/xianxu/parley.nvim","issue_id":"000229","recipe":"milestone-review","round":1,"attempt":1,"agent":"claude","root":"/Users/xianxu/Library/Caches/sdlc/review-checkouts/b596d96584e6aad6","reviewed_head":"af12fe1db4fdeaea47cb9eefee7acd8058c82208","slot":"parley.nvim:3","requested_at":"2026-10-16T02:03:00.323684Z"},"phase":"finished","pid":60996,"started_at":"2026-10-16T02:03:00.423781Z","finished_at":"2026-10-16T02:04:47.445939Z","session_id":"65ca19ee-0f47-484f-ab09-7ded2e13d806","outcome":"returned"}] -->
