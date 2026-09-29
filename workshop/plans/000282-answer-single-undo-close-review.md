# Boundary Review — parley.nvim#282 (whole-issue close)

| field | value |
|-------|-------|
| issue | 282 — Make each answer one undo history entry |
| repo | parley.nvim |
| issue file | workshop/issues/000282-answer-single-undo.md |
| boundary | whole-issue close |
| milestone | — |
| window | a3c8f38df329673c1830b36489428a1913b6edc6..b213dcf583a7dec4e248e6c0d9a5fc94ffcd895b |
| command | sdlc close --issue 282 |
| reviewer | claude |
| timestamp | 2026-09-28T21:36:45-07:00 |
| verdict | FIX-THEN-SHIP |

## Review

```verdict
verdict: FIX-THEN-SHIP
confidence: medium
```

The fix is small and aimed at the right place. The editor already grouped one answer into a single undo block through its private receipt, and the diff removes the two things that were clearing that receipt without changing any text. First, a `:write` changes changedtick, so the editor now accepts the new tick on `BufWritePost` as long as the native undo sequence has not moved. Second, the receipt is now recorded as soon as the writer's own patch lands, before the post-write authority check. I traced the "keep the receipt for a fully-landed plan" rule, and it is safe. Any unexpected or nested edit goes through `observe`, which clears the receipt. If that edit arrives before the patch lands, the loop breaks before `landed` is set. A revoke is only set inside our own `observe`, and the receipt is recorded after that. Nothing here blocks the close. What remains is some missing coverage the Spec asks for, an atlas sentence that overstates the behaviour, and a small autocmd leak.

**Strengths**
- `lua/parley/document/editor.lua:271-283`: the receipt is recorded after the writer's own `observe` and before the revoke check. The final clear at line 296 still drops the receipt for a partial or refused plan and on error, so the existing partial-operation contract holds.
- The save watcher only adopts the new tick when `sequence` is unchanged; otherwise it drops the receipt. Together with `observe` clearing the receipt on any text event, format-on-save and user edits still land as separate undo entries.
- `tests/integration/answer_undo_spec.lua` drives real answers through `chat_respond` with the stateful fixture transport and counts `u`. That is real integration evidence, not mocks. The log also records mutation checks: removing the save watcher turns 4 save cases red, and removing the early receipt turns the tool-round case red.
- ARCH-DRY: `tool_use_sse` moved into `tests/helpers/respond_fixture.lua` instead of being copied into the new spec.
- The sweep-matcher fix for `function X:m` comes with a self-test case.

**Critical:** none.

**Important**
1. **Two cases the Spec names have no tests (ARCH-PURPOSE).** The Spec says "Cover answer replacement, errors, stop/cancel, reload and concurrent chats." Errors, cancel and reload between answers are covered. Answer replacement (regenerating an existing answer) and concurrent chats (two buffers streaming at once, each with its own editor and receipt) are not. The Done-when clause about reload is also only tested between answers, not with a reload in the middle of a stream.
2. **The two new editor rules are only tested end-to-end.** `tests/integration/document_edit_spec.lua:150-176` already tests `can_join_undo` directly against a real buffer. Adding cases there is cheap and would pin:
   - a plan whose after-phase validator revokes returns `stale` and `can_join_undo` is still true;
   - a partial plan (patch 2 of 2 refused) returns false;
   - `:write` keeps it true;
   - `:write` after an undo returns false.

   The integration spec depends on `vim.wait(20)` timing and was flaky once. The Plan row said "unit coverage … if it has one", and this harness is where it belongs.

**Minor**
- `atlas/chat/document.md:128-130` says the receipt "survives refusals and suspensions". The code at `editor.lua:296` clears it on any refused plan where `landed < #patches`, including a no-op refusal of the first patch. The claim is true only for suspensions that happen after a fully-landed plan. Sites in the same family:
  - that atlas sentence;
  - the commit subject of 348f5e92 ("keep the receipt across no-op refusals");
  - Plan item 2, which describes the intent correctly.
- `editor.lua:167`: the `BufWritePost` autocmd is created before `driver.attach`. If attach fails (`:176`), the autocmd leaks, and a retried `attach` adds a second one. Create the watch after a successful attach, or remove it on the failure path.
- The "two answers" test puts a user edit (the new `💬:` line) between the answers, so it does not show that two answers stay separate without an edit in between. Generation/grant separation is probably what guarantees it; a test with no edit between answers would pin that.

**Test coverage notes:** the 7 cases match the Plan's checklist item. The gaps are the Spec's answer-replacement and concurrent-chats cases, and direct editor-level tests of the retention rule and tick adoption.

**Architecture**
- **ARCH-DRY: pass.** The fixture was extracted and nothing is duplicated.
- **ARCH-PURE: pass.** The editor is the IO seam, and the retention decision is one predicate.
- **ARCH-PURPOSE: flag.** See Important #1.

**Plan revision recommendations:** add a `## Revisions` entry that:
- narrows the "keep the receipt across no-op refusals" wording to "fully-landed plans only";
- notes that answer replacement and concurrent chats are either tested or explicitly descoped;
- notes that no fake driver exists, so editor-level coverage goes in `document_edit_spec`.

```findings
findings:
  - id: new
    severity: Important
    family: spec-clause-untested
    title: |
      Spec cases answer replacement and concurrent chats (and mid-stream reload) have no regression test
    detail: |
      Spec says cover answer replacement, errors, stop/cancel, reload and concurrent chats. answer_undo_spec covers errors, cancel and reload between answers only. Missing cases are regenerating an existing answer, two buffers streaming at once, and a reload during a stream.
  - id: new
    severity: Important
    family: contract-pinned-only-end-to-end
    title: |
      Receipt retention (fully-landed stale plan) and BufWritePost tick adoption lack direct editor tests
    detail: |
      document_edit_spec.lua:150-176 already tests can_join_undo directly. Add cases for a revoked-after-last-patch plan (still joins), a partial plan (does not), a write (still joins) and a write after undo (does not). Today only the timing-based integration spec pins these rules.
  - id: new
    severity: Minor
    family: doc-claim-overstates-code
    title: |
      atlas says the receipt survives refusals, but editor.lua:296 clears it on any refused or partial plan
    detail: |
      Instances in this window are the atlas/chat/document.md sentence and the 348f5e92 commit subject. Code keeps the receipt only when every patch landed (suspension after the last patch).
  - id: new
    severity: Minor
    family: resource-leak-on-failed-setup
    title: |
      BufWritePost watch is created before driver.attach and leaks if attach fails
    detail: |
      editor.lua:167 creates the autocmd and :176 returns false without unwatching. A retried attach adds a duplicate. Move the watch after a successful attach.
  - id: new
    severity: Minor
    family: test-confounded-by-setup
    title: |
      two-answers test inserts a user edit between answers, so it does not isolate answer-to-answer separation
```
