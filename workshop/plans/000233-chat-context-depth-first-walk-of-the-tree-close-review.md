# Boundary Review — parley.nvim#233 (whole-issue close)

| field | value |
|-------|-------|
| issue | 233 — A question asked after an <M-i> branch cannot see that branch; build chat context by depth-first walk of the tree |
| repo | parley.nvim |
| issue file | workshop/issues/000233-chat-context-depth-first-walk-of-the-tree.md |
| boundary | whole-issue close |
| milestone | — |
| window | 111893e128e74350964044dbe9b8007a38099149..f2e1d5aaa40012ef930599bc1134ea5f3bd68c8b |
| command | sdlc close --issue 233 |
| reviewer | claude |
| isolation | fenced |
| timestamp | 2026-10-16T03:55:11-07:00 |
| verdict | FIX-THEN-SHIP |

## Review

Reviewing the diff now; checking how build_messages handles file/remote refs for exchanges from other files.

Running the new specs and a probe for the remote-reference case.

Old make; using a temp makefile include instead.

Probe confirms the remote-ref stub. Cleaning up and checking atlas changes.

```verdict
verdict: FIX-THEN-SHIP
confidence: medium
```

The core of #233 works. `chat_tree.path_up` and `chat_tree.linearize` follow the Spec: depth-first pre-order, cut at the submitted question, children of a regenerated exchange left out, a visited set and the depth cap. They are pure functions that take their IO as injected `load`/`resolve` callbacks, and the old second renderer (`build_ancestor_messages`) is gone, as rule 2 asks. I ran `chat_tree_spec` (11), `chat_tree_context_spec` (4), `build_messages_spec` (104) and `ancestor_chain_rename_spec` (6) inside the test harness. All pass.

Three gaps stop a plain SHIP:
- **Remote URLs from other files are never fetched.** Remote-reference resolution still only looks at the current file. Any `@@https://…@@` in an ancestor or aside goes out as a "not cached, refresh the question" error stub. I confirmed this with a probe.
- **Batch and visual-range submissions leak asides.** A batch leg, or a visual range, still sends the asides hanging off current-file exchanges it deliberately left out.
- **Single-file chats change too.** The memory window now counts back from the cut rather than from the end of the file. That changes requests for single-file chats, though the plan says "No change to how a file's own exchanges render."

### 1. Strengths
- `lua/parley/chat_tree.lua:56-102`: `linearize` is a small, readable recursion that matches the plan's pseudocode. Leaving out the children of a regenerated exchange simply falls out of the "emit, then return on cut" ordering.
- `path_up` keeps the reciprocal-link rule from #224: a parent that doesn't link back to the child ends the path. A branch is matched through the shared resolver, so the rename tests still pass after the port.
- `build_messages` decides what goes to the topic request by message identity (`current_messages`), not by counting. That is the right fix for interleaved files (`chat_respond.lua:796-804`, `:1031-1037`).
- Attachments carry their own `chat_path` per slot, so an image resolves against the file it lives in (`chat_respond.lua:874-875`, `:369-176`).
- The unit tests are genuinely pure (hand-built parses and a table-backed loader). The integration test uses real files and an unsaved buffer.

### 2. Critical findings
None.

### 3. Important findings
- **I1 (ARCH-PURPOSE): remote references in other files of the tree are never resolved.**
  - **Cause:** `resolve_remote_references` still runs over `input_parsed`/`input_index` only (`chat_respond.lua:1734`). `build_messages` now pins every file-reference exchange anywhere in the sequence (`:810`), and for an unresolved URL it falls through to `format_missing_remote_reference_cache_content` (`:854-855`).
  - **Probe:** parent `💬: look @@https://example.com/x@@`, child submits K1. The request contains a system message: `File: https://example.com/x\n[Error: Remote URL content is not cached. Refresh the question that introduced this URL to fetch it again.]`.
  - **Impact:** the model is told to refresh a question in a different file. Before this change, ancestors sent only the question text. `atlas/chat/lifecycle.md` now says "`@@` references in them are inlined as in their own file", which is false for URLs.
  - **Fix sketch:** run the remote resolution over the sequence. A foreign item can look up `get_chat_remote_reference_cache(item.file)` (cache only, no fetch), or be rendered without the stub. Add a regression test with a URL in a parent.
- **I2 (ARCH-PURPOSE): batch and visual-range submissions leak asides of excluded exchanges.**
  - **Cause:** `tree_sequence` linearizes the full `parsed`. It then removes the current-file exchanges missing from `input_parsed`, but keeps every non-current item (`chat_respond.lua:183-191`).
  - **Batch case:** a leg whose `input_rows` excludes Q1 still sends Q1's `<M-i>` aside, cut off from the exchange it is about.
  - **Visual-range case:** `start_index` hides current-file rows, but asides anchored on those rows still go out.
  - **Test gap:** the `build_messages_spec` "visual range" test only covers a foreign item placed before the range. That case is right for ancestors and doesn't cover current-file asides.
  - **Fix sketch:** have `linearize` tag each subtree item with the current-file exchange it hangs off (or with "ancestor path"). Then drop subtrees whose anchor is filtered out.
- **I3: the memory window changed for every chat, not just trees.**
  - **Cause:** `total_exchanges` is now `#sequence`, and the sequence ends at the cut (`chat_respond.lua:791`). Before, it was `#parsed_chat.exchanges`, the whole file.
  - **Example:** a 10-exchange file with `max_full_exchanges=4`, resubmitting exchange 3. Before, exchanges 1-2 were summarized. Now `preserve_exchange` keeps 1-3 in full.
  - **Why it matters:** this contradicts the plan's "No change to how a file's own exchanges render", and no test covers it.
  - **Fix sketch:** either declare it in `## Revisions` (it is arguably more correct) and pin it with a test, or pass the old total.

### 4. Minor findings
- **ARCH-DRY:** the `tree_context` helper (walk the sequence, collect question and answer text of non-current items) is copy-pasted in `tests/integration/ancestor_chain_rename_spec.lua:43-55` and `tests/integration/chat_respond_spec.lua:413-418`.
- **ARCH-CONSTRAINTS:** every submission now reads and parses every file in the left subtree, synchronously, inside `build()`. The Log measures request size only, not latency. Nothing bounds the number of files read besides depth 20, so a very bushy tree can stall the UI.
- **Leftover name:** the `ancestor_chain_rename_spec` assertion message "expected exactly one ancestor" now sits on `#path == 2`. It is correct, but the name is left over from the old model.
- **ARCH-DRY / Spec rule 3:** `chat_tree` is a fourth tree walker until #349 lands. The TL's deferral is recorded in the plan's Revisions, so this is not counted as a finding.

### 5. Test coverage notes
- The pure linearizer is well covered: aside, left sibling, right-of-cut not read, regeneration, branch before the first question, cycle, unreadable branch, depth cap.
- Missing:
  - foreign `@@url@@` and `@@file@@` references (I1)
  - batch `input_rows` and visual range with an aside anchored on an excluded exchange (I2)
  - memory window on a mid-file resubmission (I3)
  - an end-to-end `start_scoped_response` request over a tree. All the tree tests stop at `_tree_sequence` or `_build_messages`, so the `tree_sequence` → `build_messages(cut)` wiring at `:1690-1696` is only exercised indirectly.

### 6. Architectural notes
- **ARCH-DRY:** pass, apart from the test-helper duplication and the deferred walker (#349).
- **ARCH-PURE:** pass. `path_up` and `linearize` take injected `load`/`resolve`, and `vim.fn.fnamemodify` is only string handling. `io_deps` is the thin shell.
- **ARCH-PURPOSE:** flag (I1, I2). The shadow-sweep found per-request passes that still read the current file, not the sequence. Remote resolution is one. The batch and range filters apply to current items but not to subtrees anchored on them.
- **ARCH-MOCK:** N/A. No external binary or service; file IO goes through the injected seam, with a table-backed fake in the tests.
- **ARCH-CONSTRAINTS:** Minor flag (above).
- **ARCH-SECURE:** pass, with a note. Branch links can resolve outside the chat roots (the #224 test). `@@file@@` references in foreign chats are now read and sent to the provider. The files are the user's own, but the blast radius is wider than before and the plan did not state it.
- **ARCH-ORDER:** pass. No state is held across events. The current file is snapshotted when the command runs, while other files are read at `build()` time. A child answer still streaming at that moment will be sent partial, which matches how ancestors already behaved.
- **ARCH-FUNERAL:** pass. Nothing durable is created; every value lives only for the request.

### 7. Plan revision recommendations
- Add a Revisions entry for I3: the memory window now counts back from the cut position in the sequence, which also affects mid-file resubmission of single-file chats. Alternatively, remove "No change to how a file's own exchanges render" from `## Not doing`.
- After I1 is fixed, adjust the "One renderer" bullet to say how remote `@@` references in other files of the tree are sourced (that file's cache, or omitted).

```findings
findings:
  - id: new
    severity: Important
    kind: defect
    family: sequence-consumers-derive-from-tree
    title: |
      Remote @@url@@ references in other files of the tree are never resolved; the request carries a "not cached, refresh the question" error stub
    detail: |
      resolve_remote_references still runs over input_parsed/input_index only (chat_respond.lua:1734), while build_messages pins every file-ref exchange in the sequence (:810) and falls through to format_missing_remote_reference_cache_content (:854). A probe with a parent `@@https://example.com/x@@` produced that system message in the child's request, which contradicts atlas lifecycle "inlined as in their own file". Fix: resolve per item.file (cache lookup) or omit the stub, and add a regression test.
  - id: new
    severity: Important
    kind: defect
    family: sequence-consumers-derive-from-tree
    title: |
      Batch-leg input_rows and the visual range drop current-file exchanges but keep the asides anchored on them
    detail: |
      tree_sequence linearizes the full parsed file and filters only current items against input_parsed (chat_respond.lua:183-191); non-current subtree items always pass, and build_messages exempts them from start_index. A batch leg that excludes Q1 still sends Q1's aside, cut off from the exchange it is about. Tag subtree items with their anchoring exchange in linearize and drop those whose anchor is filtered out; add a test.
  - id: new
    severity: Important
    kind: defect
    family: undeclared-behavior-change
    title: |
      Memory window now counts back from the cut, not the end of the file, which changes single-file mid-chat resubmits
    detail: |
      total_exchanges became #sequence, and the sequence ends at the cut (chat_respond.lua:791); before, it was #parsed_chat.exchanges. Resubmitting exchange 3 of 10 with max_full_exchanges=4 now keeps exchanges 1-2 in full where they used to be summarized. The plan says "No change to how a file's own exchanges render", and no test covers this. Declare it in Revisions with a test, or restore the old total.
  - id: new
    severity: Minor
    kind: defect
    family: test-helper-duplication
    title: |
      tree_context sequence-to-text helper is copy-pasted in two integration specs
    detail: |
      ancestor_chain_rename_spec.lua:43-55 and chat_respond_spec.lua:413-418 hold the same loop over non-current items; move it to a shared test helper.
  - id: new
    severity: Minor
    kind: defect
    family: operating-envelope-undeclared
    title: |
      Every submission synchronously reads and parses the whole left subtree, with no latency envelope or measurement
    detail: |
      Only request size was measured. The number of files read is bounded only by depth 20 per path, not by tree width, and the parsing runs inside build() on the UI loop.
```

<!-- sdlc-review-usage [{"version":1,"intent":{"disposable_root":true,"id":"e44a0aa6-9f57-4bca-a58b-cf3e2f0a73dc","repository":"github.com/xianxu/parley.nvim","issue_id":"000233","recipe":"milestone-review","round":1,"attempt":1,"agent":"claude","root":"/Users/xianxu/Library/Caches/sdlc/review-checkouts/65150ce05fcfb88c","reviewed_head":"f2e1d5aaa40012ef930599bc1134ea5f3bd68c8b","slot":"parley.nvim:3","requested_at":"2026-10-16T10:51:43.842652Z"},"phase":"finished","pid":21282,"started_at":"2026-10-16T10:51:44.237447Z","finished_at":"2026-10-16T10:55:09.959142Z","session_id":"6611dd7f-dec9-40a8-a9b5-77abc6f0d4dd","outcome":"returned"}] -->
