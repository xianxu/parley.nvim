# Boundary Review — parley.nvim#350 (whole-issue close)

| field | value |
|-------|-------|
| issue | 350 — move_chat_tree's 🌿 rewrite pass looks unreachable since resolve_chat_path resolves by basename |
| repo | parley.nvim |
| issue file | workshop/issues/000350-move-chat-tree-s-rewrite-pass-looks-unreachable-since-resolve-chat-path-resolves-by-basename.md |
| boundary | whole-issue close |
| milestone | — |
| window | ec786c0c1e2f281ab88ac1e3acc4942b316c3abd..0ea8a86dadf6adbbc84a21d8c285677a449aa751 |
| command | sdlc close --issue 350 |
| reviewer | claude |
| isolation | checkout |
| timestamp | 2026-10-16T05:17:45-07:00 |
| verdict | SHIP |

## Review

Reviewing the #350 diff; now running the chat-move spec to verify the new tests.

Mutations confirmed all three claims; checkout restored. Checking the resolver and the disk-write path coverage.

```verdict
verdict: SHIP
confidence: high
```

The issue asked whether `move_chat_tree`'s 🌿 rewrite pass can still be reached. The answer is yes, and the evidence holds. The resolver (`lua/parley/init.lua:3578`) has three outcomes: an existing candidate, an existing timestamp-glob match, or the first candidate unchanged. Only the third can equal an old path, because by the time the pass runs every old file has already been moved away (`init.lua:3916-3935`). That leaves two shapes that reach the branch: a reference with an explicit directory to a child with no timestamp (condition 1), and `sub/<name>` resolved from the old root (condition 2). Each condition now has its own test, and the issue gap (#265, a rewrite refused in an open buffer) is closed with a real capacity hold rather than a mock. I ran `tests/integration/chat_move_spec.lua` at head: 17/17 pass. I also repeated the issue's mutation claims in the disposable checkout, then restored it and confirmed `git status` was clean:
- Replacing the branch condition with `if false` fails 3 tests.
- Keeping only condition 1 fails 1 test (the subdirectory case).
- Dropping the `ref_errors` collection fails 1 test (the refused-rewrite case).

Nothing blocks SHIP. The only findings are coverage gaps (Minor).

1. **Strengths**
   - The investigation's conclusion was mutation-checked and survives: each clause of `init.lua:3955` is needed by a distinct test (`chat_move_spec.lua:196`, `:222`).
   - The refused-rewrite test (`chat_move_spec.lua:246`) uses the real `user_edit_capacity` hold. It checks both the error text and that the move still completed: the child and the root both land in the target.
   - The comment at `init.lua:3938-3942` and the atlas `atlas/chat/lifecycle.md:126-132` both state exactly when the pass fires, so it is unlikely to be re-filed as dead code. Both agree with the resolver code.
   - Scope is tight: no production behaviour changed, only a comment, docs and tests.

2. **Critical:** none.

3. **Important:** none.

4. **Minor**
   - **Disk-write path not covered.** All three new tests rewrite through an open buffer. The disk-write branch (`if changed and not live then vim.fn.writefile(...)`, `init.lua:3971`) is never reached by them. Example of the gap: a moved, unopened child that holds an absolute reference to a grandchild with no timestamp.
   - **Atlas/comment examples not all pinned.** Only the absolute and `sub/` forms have tests; `~` and `../` are listed but untested. They are plausible under the same fallback logic.
   - **Duplicated test helper.** The "find the 🌿 line" helper appears twice in different forms (`chat_move_spec.lua:207-209` and `:236-239`). It could be one local helper.

5. **Test coverage notes:** Both conditions and the refused-rewrite report are pinned, and each test fails when its fix is reverted (verified above). The remaining gap is the disk-write rewrite path.

6. **Architecture**
   - **ARCH-DRY:** pass (only a small test-helper duplication; noted as Minor).
   - **ARCH-PURE:** pass. No new logic; the pass is existing IO-shell code inside `move_chat_tree`. A later refactor could pull "does this reference need rewriting?" out into a pure function.
   - **ARCH-PURPOSE:** pass. Both Done-when items are delivered: reachability is established by tests plus mutation, and the "if some does, a test drives it" branch is taken.
   - **ARCH-MOCK:** pass. Tests use a real filesystem in a temp env and the real capacity guard; no new external dependency.
   - **ARCH-CONSTRAINTS:** pass. No runtime change.
   - **ARCH-SECURE:** pass. Not applicable: the change introduces no new untrusted-input parsing and touches no secrets.
   - **ARCH-ORDER:** pass. Not applicable: no new state is carried between events. The refused-edit case is a single-shot outcome that is collected and reported.
   - **ARCH-FUNERAL:** pass. Not applicable: nothing durable is created; test files live under the per-spec temp roots.

7. **Plan revisions:** none. The plan's Outcome section matches the code and the measured mutations.

```findings
findings:
  - id: new
    severity: Minor
    kind: defect
    family: branch-output-untested
    title: |
      chat-move rewrite tests cover only the open-buffer path; the closed-file writefile branch is unpinned
    detail: |
      All three new specs rewrite through an open buffer, so the non-live write branch at init.lua:3971 is never reached by them. Add a case where a moved, unopened child holds an absolute reference to a grandchild with no timestamp, and assert the file on disk after the move.
  - id: new
    severity: Minor
    kind: defect
    family: doc-claim-untested
    title: |
      The ~ and ../ reference forms named in the atlas and code comment have no test
    detail: |
      lifecycle.md and init.lua:3938 list absolute, ~, ../ and sub/ as the shapes the rewrite fires for; only absolute and sub/ are pinned in chat_move_spec.
```

<!-- sdlc-review-usage [{"version":1,"intent":{"disposable_root":true,"id":"29502d70-c5ef-4d25-b95a-b17dbaf1a20f","repository":"github.com/xianxu/parley.nvim","issue_id":"000350","recipe":"milestone-review","round":1,"attempt":1,"agent":"claude","root":"/Users/xianxu/Library/Caches/sdlc/review-checkouts/4c10926903f58929","reviewed_head":"0ea8a86dadf6adbbc84a21d8c285677a449aa751","slot":"parley.nvim:4","requested_at":"2026-10-16T12:16:28.762426Z"},"phase":"finished","pid":32442,"started_at":"2026-10-16T12:16:29.004664Z","finished_at":"2026-10-16T12:17:43.256096Z","session_id":"258d1fab-9a9f-41ee-b126-97be4263151d","outcome":"returned"}] -->
