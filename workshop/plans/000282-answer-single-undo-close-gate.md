---
gate: boundary-review
issue: 282
id_prefix: BR
rounds:
    - "n": 1
      timestamp: "2026-09-28T21:36:46-07:00"
      agent: claude
      findings:
        - id: BR-1
          severity: Important
          title: Spec cases answer replacement and concurrent chats (and mid-stream reload) have no regression test
          detail: Spec says cover answer replacement, errors, stop/cancel, reload and concurrent chats. answer_undo_spec covers errors, cancel and reload between answers only. Missing cases are regenerating an existing answer, two buffers streaming at once, and a reload during a stream.
          family: spec-clause-untested
          round: 1
        - id: BR-2
          severity: Important
          title: Receipt retention (fully-landed stale plan) and BufWritePost tick adoption lack direct editor tests
          detail: document_edit_spec.lua:150-176 already tests can_join_undo directly. Add cases for a revoked-after-last-patch plan (still joins), a partial plan (does not), a write (still joins) and a write after undo (does not). Today only the timing-based integration spec pins these rules.
          family: contract-pinned-only-end-to-end
          round: 1
        - id: BR-3
          severity: Minor
          title: atlas says the receipt survives refusals, but editor.lua:296 clears it on any refused or partial plan
          detail: Instances in this window are the atlas/chat/document.md sentence and the 348f5e92 commit subject. Code keeps the receipt only when every patch landed (suspension after the last patch).
          family: doc-claim-overstates-code
          round: 1
        - id: BR-4
          severity: Minor
          title: BufWritePost watch is created before driver.attach and leaks if attach fails
          detail: editor.lua:167 creates the autocmd and :176 returns false without unwatching. A retried attach adds a duplicate. Move the watch after a successful attach.
          family: resource-leak-on-failed-setup
          round: 1
        - id: BR-5
          severity: Minor
          title: two-answers test inserts a user edit between answers, so it does not isolate answer-to-answer separation
          family: test-confounded-by-setup
          round: 1
      recipe: small-diff-review
      blocked: true
---

# Gate ledger — parley.nvim#282 (boundary-review)

Findings this gate raised, the stable ids the binary assigned them, and how
later rounds disposed of them. Generated — edit the gate, not this file.

## Round 1 — 2026-09-28T21:36:46-07:00 (claude) — BLOCKED

### Raised

- **BR-1** [Important] `spec-clause-untested` Spec cases answer replacement and concurrent chats (and mid-stream reload) have no regression test
  Spec says cover answer replacement, errors, stop/cancel, reload and concurrent chats. answer_undo_spec covers errors, cancel and reload between answers only. Missing cases are regenerating an existing answer, two buffers streaming at once, and a reload during a stream.
- **BR-2** [Important] `contract-pinned-only-end-to-end` Receipt retention (fully-landed stale plan) and BufWritePost tick adoption lack direct editor tests
  document_edit_spec.lua:150-176 already tests can_join_undo directly. Add cases for a revoked-after-last-patch plan (still joins), a partial plan (does not), a write (still joins) and a write after undo (does not). Today only the timing-based integration spec pins these rules.
- **BR-3** [Minor] `doc-claim-overstates-code` atlas says the receipt survives refusals, but editor.lua:296 clears it on any refused or partial plan
  Instances in this window are the atlas/chat/document.md sentence and the 348f5e92 commit subject. Code keeps the receipt only when every patch landed (suspension after the last patch).
- **BR-4** [Minor] `resource-leak-on-failed-setup` BufWritePost watch is created before driver.attach and leaks if attach fails
  editor.lua:167 creates the autocmd and :176 returns false without unwatching. A retried attach adds a duplicate. Move the watch after a successful attach.
- **BR-5** [Minor] `test-confounded-by-setup` two-answers test inserts a user edit between answers, so it does not isolate answer-to-answer separation

## Open findings

- **BR-1** [Important] `spec-clause-untested` Spec cases answer replacement and concurrent chats (and mid-stream reload) have no regression test
- **BR-2** [Important] `contract-pinned-only-end-to-end` Receipt retention (fully-landed stale plan) and BufWritePost tick adoption lack direct editor tests
- **BR-3** [Minor] `doc-claim-overstates-code` atlas says the receipt survives refusals, but editor.lua:296 clears it on any refused or partial plan
- **BR-4** [Minor] `resource-leak-on-failed-setup` BufWritePost watch is created before driver.attach and leaks if attach fails
- **BR-5** [Minor] `test-confounded-by-setup` two-answers test inserts a user edit between answers, so it does not isolate answer-to-answer separation
