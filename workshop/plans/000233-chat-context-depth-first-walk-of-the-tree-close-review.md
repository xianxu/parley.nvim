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

---

## Re-review — 2026-10-16T04:03:54-07:00 (REWORK)

| field | value |
|-------|-------|
| issue | 233 — A question asked after an <M-i> branch cannot see that branch; build chat context by depth-first walk of the tree |
| repo | parley.nvim |
| issue file | workshop/issues/000233-chat-context-depth-first-walk-of-the-tree.md |
| boundary | whole-issue close |
| milestone | — |
| window | 111893e128e74350964044dbe9b8007a38099149..e2ea2bb56b53eba6c413c4c7fc9b90747be3cf5d |
| command | sdlc close --issue 233 |
| reviewer | claude |
| isolation | fenced |
| timestamp | 2026-10-16T04:03:54-07:00 |
| verdict | REWORK |

## Review

Verifying the claimed fixes; now checking the remote-reference cache keying and then running the tests.

Test runs produced no output; checking the raw output to see why.

Writing a small probe for a suspected path-keying regression in the BR-1 fix (symlinked chat dir).

Confirmed a regression. Now reverting each claimed fix in turn to confirm its regression test goes red.

```verdict
verdict: REWORK
confidence: high
```

All three Important findings from round 1 are fixed, and I confirmed each one by reverting it. With the BR-1, BR-2 or BR-3 change removed, `chat_tree_context_spec` goes red; with the head as committed, all 8 tests pass. These specs also pass at head: `chat_tree_spec` (11), `build_messages_spec` (104), `ancestor_chain_rename_spec` (6), `chat_respond_spec` (53) and `remote_references_spec` (11). One new problem blocks SHIP, and it comes from the BR-1 fix itself. `resolve_remote_references` now picks a cache by comparing paths: `item.file ~= chat_file` at `lua/parley/chat_respond.lua:1245`. `item.file` is the `vim.fn.resolve`d path, but `chat_file` is the buffer name, which is not resolved. When the chat dir sits behind a symlink, the current file's own earlier `@@url@@` references stop using their cache. They are fetched again on every submission, and if that fetch fails, the error text replaces the good cached content, both in the request and in the saved cache. I reproduced this with a probe spec against a symlinked chat dir. Before #233, the current file always read `chat_cache`.

**Strengths**
- `tree_sequence` (`chat_respond.lua:177-204`) is now the one source for the request's context. The walk runs once at the call site (`:1757-1760`), and both the remote fetches and `build_messages` read that same sequence. A walk failure goes through the existing `fail('request build failed: …')` path and is not swallowed.
- Anchor tagging in `linearize` (`chat_tree.lua:85`) is small and correct. Nested asides inherit the outermost anchor, so dropping an exchange drops its whole subtree.
- BR-3 keeps the single-file window exactly as before by appending the input's tail after the cut, and `idx <= exchange_idx` keeps the tail from being rendered.
- Each fix has a regression test that fails without it (checked by reverting each one).
- The plan's Core concepts table now lists status, including the deleted entities and the new `other_files` helper.

**Critical findings**
- `chat_respond.lua:1245`: the cache is chosen by comparing a resolved path with an unresolved one. With a symlinked `chat_dir`, earlier URLs in the current file are fetched again on every submit, and a failed fetch replaces good cached content (`chat_cache[url] = error`, saved). Ancestor caches have the same problem: they were written under the parent's buffer name, but lookups use the resolved path.
  - Reproduced: the probe returned `"File: … [Error: Remote URL fetch failed …]"` instead of `CACHED`, and the cache file ended up holding both the link key and the real-path key.
  - Fix sketch: use `item.current and chat_cache or …` for the current file. Make cache keys canonical in one place, for example `vim.fn.resolve(fnamemodify(f, ":p"))` inside `get_chat_remote_reference_cache`, and fall back to reading the legacy unresolved key.
  - Add a test that goes through a symlinked dir. The current BR-1 test hides the bug because `write_chat` returns `vim.fn.resolve(path)` (`chat_tree_context_spec.lua:17`).

**Important findings**
- None.

**Minor findings**
- `get_chat_remote_reference_cache` creates an empty `chats[file] = {}` entry for every item in the tree, even items with no URLs. These entries are saved on the next fetch, and nothing ever prunes `cache.chats` (ARCH-FUNERAL). A read-only lookup that doesn't create entries would fix this along with the Critical fix.
- If the BR-1 fix regresses, its test goes to the real network: reverting it produced an `HTTP 404 for https://example.com/...` (ARCH-MOCK). An unroutable host or an injected fetcher would avoid this.
- The "build the default sequence from `parsed_chat`" fallback appears twice, at `:793-799` and `:1235-1239` (ARCH-DRY, small).

**Test coverage notes**
- BR-1, BR-2 and BR-3 are each pinned by tests that fail when the fix is reverted.
- Nothing covers path identity: symlinked dirs, or a buffer name that differs from the resolved path.
- An inline aside link inside a *question* gets `after_exchange = k` from the parser. So it is anchored to the previous exchange rather than the one it sits in. This is existing parser behaviour, but the anchor logic now relies on it, and no test covers it.

**Architecture**
- **ARCH-DRY:** pass. The helper was consolidated; only the minor duplicate fallback above remains.
- **ARCH-PURE:** pass. `linearize` and `path_up` take injected `deps`; `io_deps` is the thin IO layer.
- **ARCH-PURPOSE:** pass on the shadow-sweep. I enumerated every consumer of the sequence (`build_messages`, `resolve_remote_references`, the topic input via `current_messages`), and each derives from it. The one defect is file identity, not derivation.
- **ARCH-MOCK:** flagged, minor (the network fallback in the test).
- **ARCH-CONSTRAINTS:** pass. Latency was measured (0.25 ms per KB; median 11–16 ms on a 58 KB tree) and is stated in the atlas.
- **ARCH-SECURE:** pass. Other files' caches and contents belong to the same user and go through the typed cache reader.
- **ARCH-ORDER:** pass. The sequence is captured once before the async fetches and then reused as a consistent snapshot.
- **ARCH-FUNERAL:** flagged, minor (the empty cache entries).

**Plan revision recommendations**
- After fixing, add a Revisions entry saying remote cache keys are canonical (resolved) paths, with a read fallback to the legacy key.

```findings
dispose:
  - id: BR-1
    disposition: addressed
    note: |
      resolve_remote_references walks the shared sequence with per-file caches; the chat_tree_context_spec test fails when the cache lookup is reverted. The new symlink regression is raised separately.
  - id: BR-2
    disposition: addressed
    note: |
      linearize tags anchors and tree_sequence filters on them; both drop tests fail when the filter and anchor_row are reverted.
  - id: BR-3
    disposition: addressed
    note: |
      The tail after the cut restores the single-file total; the mid-chat window test fails when the tail loop is removed.
  - id: BR-4
    disposition: addressed
    note: |
      tests/helpers/tree_context.lua other_files is used by both specs; no other copies are left in tests/.
  - id: BR-5
    disposition: addressed
    note: |
      Latency measured (0.25 ms/KB, median 11-16 ms on a 58 KB tree) and stated in atlas/chat/lifecycle.md.
findings:
  - id: new
    severity: Critical
    kind: defect
    family: canonical-file-identity
    title: |
      Remote cache lookup compares a resolved path with the unresolved buffer name, so symlinked chat dirs refetch and can overwrite cached URLs with errors
    detail: |
      chat_respond.lua:1245 picks the cache by item.file ~= chat_file. tree_sequence stores vim.fn.resolve'd paths, but chat_file is frame.file_name (the buffer name). Under a symlinked chat_dir, the current file's earlier @@url@@ references miss chat_cache and are fetched again on every submit. A failed fetch writes error text into resolved and into chat_cache (saved), replacing good content. A probe with a symlinked dir returned the error stub instead of CACHED; before #233 the current file always read chat_cache. Ancestor caches miss the same way. Fix: use chat_cache for item.current, canonicalize keys in get_chat_remote_reference_cache with a legacy-key read fallback, and add a symlinked-dir regression test (write_chat's resolve() hides it today).
  - id: new
    severity: Minor
    kind: defect
    family: operating-envelope-undeclared
    title: |
      Per-item cache lookup saves an empty chats entry for every tree file, with no pruning
    detail: |
      This is the 2nd finding in family operating-envelope-undeclared. The rule: a lookup must not write. get_chat_remote_reference_cache creates chats[key] = {} for every item in every tree, including items with no URLs, and the next save persists those entries. Give it a read-only variant for lookups (ARCH-FUNERAL).
```

<!-- sdlc-review-usage [{"version":1,"intent":{"disposable_root":true,"id":"f71b39b0-22ed-41ef-befa-8b0f2d95315f","repository":"github.com/xianxu/parley.nvim","issue_id":"000233","recipe":"milestone-review","round":2,"attempt":1,"agent":"claude","root":"/Users/xianxu/Library/Caches/sdlc/review-checkouts/72f789953e7006da","reviewed_head":"e2ea2bb56b53eba6c413c4c7fc9b90747be3cf5d","slot":"parley.nvim:3","requested_at":"2026-10-16T11:00:39.190762Z"},"phase":"finished","pid":91668,"started_at":"2026-10-16T11:00:39.349994Z","finished_at":"2026-10-16T11:03:49.511299Z","session_id":"cd414908-5754-4bbd-97d1-aebd5540b856","outcome":"returned"}] -->

---

## Re-review — 2026-10-16T04:09:14-07:00 (FIX-THEN-SHIP)

| field | value |
|-------|-------|
| issue | 233 — A question asked after an <M-i> branch cannot see that branch; build chat context by depth-first walk of the tree |
| repo | parley.nvim |
| issue file | workshop/issues/000233-chat-context-depth-first-walk-of-the-tree.md |
| boundary | whole-issue close |
| milestone | — |
| window | 111893e128e74350964044dbe9b8007a38099149..a6f6a26ec797089da0e3196b11ecffa113474839 |
| command | sdlc close --issue 233 |
| reviewer | claude |
| isolation | fenced |
| timestamp | 2026-10-16T04:09:14-07:00 |
| verdict | FIX-THEN-SHIP |

## Review

The last commit is the round-2 fix. Let me look at it.

Running the round-2 regression spec now, then reverting the fix to confirm it goes red.

Tests pass at head. Now I'm reverting the round-2 fix in this disposable checkout to check the regressions fail without it.

```verdict
verdict: FIX-THEN-SHIP
confidence: medium
```

The round-2 commit (`a6f6a26e`) fixes both open findings, and both fixes have regression tests. I ran `make test-spec SPEC=chat/memory` at head: every file passed, including `chat_tree_context_spec` (10/10). I then reverted `chat_respond.lua` to the round-1 version (`e2ea2bb5`) in this disposable checkout. `chat_tree_context_spec` went to 8 passed, 2 failed, including the "looks up another file's cache without creating an entry" test. I restored the file afterwards. One new Important issue blocks a clean SHIP. When a URL from another file of the tree is not in that file's cache, the fetched content is written to the current file's cache. The lookup only ever reads the other file's cache. So that URL is fetched again on every submit, and the request waits for the fetch each time. This keeps happening for good once an ancestor's cache key is lost, for example when the ancestor file is renamed or the cache is pruned.

**1. Strengths**
- `chat_cache_key` (`lua/parley/chat_respond.lua:257`) gives one key per file: `resolve(fnamemodify(:p))`. `get_chat_remote_reference_cache` moves an entry saved under the old raw name over to that key, so existing users' caches carry over.
- Picking the cache by `item.current == false` (`chat_respond.lua:1264`) uses the walk's own label instead of comparing path strings. That removes the class of bug behind BR-6, not just the one case it reported.
- The symlinked-dir test writes its file through a real `fs_symlink` and parses it by the link name. That avoids the `write_chat` → `resolve()` shortcut that hid BR-6 before.
- `chat_tree.lua` keeps its IO behind `deps` (`path_up` and `linearize` are pure), and `io_deps` is the thin layer that does the reading.

**2. Critical findings:** none.

**3. Important findings**
- **Fetched content for another file's URL is written where no lookup reads it** (`chat_respond.lua:1264` vs `:1338`). Lookups for other-file items read `peek(item.file)`. Every fetch result goes to `chat_cache[url]`, the current file's cache. A URL that misses in the other file's cache therefore misses on every submit and is fetched each time, adding network time to every request. There is also no test that submits twice. Fix sketch: in the lookup, fall back to the current file's cache (`peek(item.file)[url] or chat_cache[url]`). Or record which file each fetched URL belongs to and write into that file's cache. Add a test with a fake `oauth.fetch_content` that submits twice from a child whose parent cache misses, and checks the fetch runs once.
  - This is the **2nd finding in family `canonical-file-identity`**. The rule that covers BR-6 and this one: a remote reference's cache entry is read and written under one key, the key of the file that holds the reference. The fix should apply that rule to every read and write site in `resolve_remote_references`, not just this one.

**4. Minor findings**
- `peek_chat_remote_reference_cache`'s legacy fallback (`cache.chats[chat_file]`) never matches for other-file items. `item.file` is already resolved, so the fallback looks up the same key twice. Old entries saved under a symlinked name for an ancestor are never found.
- A failed fetch of an ancestor's URL saves an error stub in the current file's cache. Combined with the Important finding above, the current file's cache keeps growing with URLs that file never references.

**5. Test coverage notes**
- Both round-2 tests went red with the fix reverted, so the regression evidence for BR-6 and BR-7 is real.
- The second test is a real check: `write_chat` returns resolved paths, so the old code would have created `chats[root]` under exactly the key the test asserts is absent.
- No test covers repeated submits or a cache miss followed by a fetch for an other-file URL.

**6. Architectural notes**
- ARCH-DRY: pass.
- ARCH-PURE: pass. The tree walk is pure behind its deps.
- ARCH-PURPOSE: pass for the round's scope.
- ARCH-MOCK: pass. Fetching goes through the `oauth.fetch_content` seam, which the suggested test can fake.
- ARCH-CONSTRAINTS: flag. A repeated fetch on the submit path (the Important finding).
- ARCH-SECURE: pass. The cache is typed when read (#261).
- ARCH-ORDER: pass. No new state is carried between events.
- ARCH-FUNERAL: BR-7 is fixed (lookups no longer write), but the Minor growth noted above remains.

**7. Plan revision recommendations**
- The Core concepts row for `resolve_remote_references` says it reads "each file's own cache". Add a Revisions entry saying which file's cache a fetch result goes into, so that reads and writes agree.

```findings
dispose:
  - id: BR-6
    disposition: addressed
    note: |
      chat_cache_key canonicalizes with a legacy-key move, item.current picks the cache; the symlinked-dir regression test is red with chat_respond.lua reverted to e2ea2bb5 (8 passed, 2 failed) and green at head.
  - id: BR-7
    disposition: addressed
    note: |
      peek_chat_remote_reference_cache is read-only; the "without creating an entry" test fails with the fix reverted and passes at head.
findings:
  - id: new
    severity: Important
    kind: defect
    family: canonical-file-identity
    title: |
      A fetched remote reference from another tree file is written to the current file's cache, which no lookup reads, so it is fetched on every submit
    detail: |
      resolve_remote_references looks up other-file items in peek(item.file) (chat_respond.lua:1264) but writes every fetch result into chat_cache (line 1338). A URL that misses in an ancestor's cache, for example after a rename or prune, is fetched again on every submit. This is the 2nd finding in this family. The rule: a reference's cache entry is read and written under the key of the file that holds it. Apply it to every read and write site, and add a two-submit test with a fake oauth.fetch_content that checks the fetch runs once.
  - id: new
    severity: Minor
    kind: defect
    family: operating-envelope-undeclared
    title: |
      Failed or fetched ancestor URLs pile up in the current file's cache, and the peek legacy fallback never matches
    detail: |
      Error stubs and content for URLs the current file never references are saved under its key. The peek fallback looks up the already-resolved item.file again, so old entries saved under a symlinked name for an ancestor are never found.
```

<!-- sdlc-review-usage [{"version":1,"intent":{"disposable_root":true,"id":"b95b1f8a-32be-4070-a097-46653a7f6c90","repository":"github.com/xianxu/parley.nvim","issue_id":"000233","recipe":"milestone-review","round":3,"attempt":1,"agent":"claude","root":"/Users/xianxu/Library/Caches/sdlc/review-checkouts/89f8b93c6b22efba","reviewed_head":"a6f6a26ec797089da0e3196b11ecffa113474839","slot":"parley.nvim:3","requested_at":"2026-10-16T11:06:38.046538Z"},"phase":"finished","pid":57070,"started_at":"2026-10-16T11:06:38.247333Z","finished_at":"2026-10-16T11:09:06.615845Z","session_id":"aac05daf-6913-4597-b797-7a06e3b5cb5c","outcome":"returned"}] -->

---

## Re-review — 2026-10-16T04:16:45-07:00 (SHIP)

| field | value |
|-------|-------|
| issue | 233 — A question asked after an <M-i> branch cannot see that branch; build chat context by depth-first walk of the tree |
| repo | parley.nvim |
| issue file | workshop/issues/000233-chat-context-depth-first-walk-of-the-tree.md |
| boundary | whole-issue close |
| milestone | — |
| window | 111893e128e74350964044dbe9b8007a38099149..73d62dcd0172cadfa810791c9cffb937ad75db57 |
| command | sdlc close --issue 233 |
| reviewer | claude |
| isolation | fenced |
| timestamp | 2026-10-16T04:16:45-07:00 |
| verdict | SHIP |

## Review

Checking the BR-8 fix; next I'll run the regression test with and without the fix.

Lifecycle tests pass. Now running the tree-context spec directly, then reverting the fix to confirm the test catches it.

Green. Now reverting the write-site fix to confirm the new test goes red.

BR-8 confirmed: the test fails without the fix. Running lint as a last check.

```verdict
verdict: SHIP
confidence: high
```

This round fixes BR-8 and BR-9 correctly, and the fix is tested. `resolve_remote_references` now records which file holds each queued URL (`holder[url]`, `lua/parley/chat_respond.lua:1244-1251`). Each fetch result is written under that file's key (`:1342-1343`). Lookups for other files still go through the read-only `peek_chat_remote_reference_cache`. The new two-submit test (`tests/integration/chat_tree_context_spec.lua:181-212`) replaces `fetch_content` with a fake and checks that the fetch runs exactly once and that nothing is saved under the child's key. I reverted only the write-site line back to `local into = chat_cache`, and that test went red: "caches an ancestor's fetched reference under the ancestor, once" failed. With the fix restored, every spec mapped to `chat/memory` and `chat/lifecycle` passes, and luacheck reports 0 warnings and 0 errors. No new blocking issues.

1. **Strengths**
   - The rule from BR-8 is applied at all three sites: the lookup (`:1267-1268`), the queue (`:1276`, `:1282`) and the write (`:1342`). That covers the whole class, not just the instance the finding named (ARCH-PURPOSE).
   - The test checks both halves of the rule: the fetch count (the read side) and the child's cache staying empty (the write side). It drives the production function with an injected fake fetch.
   - `peek_chat_remote_reference_cache` is now a single line that creates no entry (`:274-276`). It drops the legacy fallback that BR-9 showed could never match.
   - `workshop/lessons.md` records the general rule (a cache shared across files has one key per file, and a reference is read and written under its holder's key), not just the incident.

2. **Critical:** none.

3. **Important:** none.

4. **Minor**
   - `queue_fetch` removes duplicates by URL, and the first holder wins. If an ancestor misses its cache for URL `u` and the submitted exchange also references `u`, the fresh fetch is saved only under the ancestor. If that link later breaks, the current file fetches `u` once more. This is benign and not worth a new finding.
   - Old cache entries saved under an ancestor's symlinked raw name are no longer reachable for lookups of other files. They are only moved to the canonical key when that file itself is submitted. It is a cache, so the cost is at most one refetch.

5. **Test coverage notes:** The BR-8 regression test is reachable and fails without the fix. BR-9's write-side behaviour is pinned by the same test's assertion that the child's cache stays empty. Removing the peek fallback simplifies the lookup and changes no other behaviour, so it needs no test of its own.

6. **Architecture**
   - **ARCH-DRY: pass.** The cache keying is one helper, `chat_cache_key`, shared by `get` and `peek`.
   - **ARCH-PURE: pass.** `chat_tree.linearize` is pure; the walk's file reads stay in `io_deps`/`load`.
   - **ARCH-PURPOSE: pass.** Every read and write site of the remote cache follows the holder-key rule.
   - **ARCH-MOCK: pass.** OAuth is replaced at the `fetch_content` seam, which production calls through as well.
   - **ARCH-CONSTRAINTS: pass.** Settled in earlier rounds (BR-5); unchanged this round.
   - **ARCH-SECURE: pass.** The cache file is still parsed with the #261 typed schema.
   - **ARCH-ORDER: pass.** No new state crosses events; the fetch completion path is unchanged apart from where it writes.
   - **ARCH-FUNERAL: pass.** Entries are created only on a real write, and ancestor URLs no longer pile up under the current file. The cache file's lack of pruning is older than this issue.

7. **Plan revision recommendations:** none. The Core concepts rows for `resolve_remote_references` ("reading each file's own cache") and `peek_chat_remote_reference_cache` match the code.

```findings
dispose:
  - id: BR-8
    disposition: addressed
    note: |
      holder[url] routes each fetch to its holder's key (chat_respond.lua:1342); reverting that line makes the new two-submit test in chat_tree_context_spec fail, and restoring it makes it pass.
  - id: BR-9
    disposition: addressed
    note: |
      Ancestor URLs (content or error stubs) now save under the ancestor's key, and the test asserts the child's cache stays empty; the dead peek fallback is removed (chat_respond.lua:274-276).
```

<!-- sdlc-review-usage [{"version":1,"intent":{"disposable_root":true,"id":"842e104a-bc79-4d78-b86b-3b835b8171a8","repository":"github.com/xianxu/parley.nvim","issue_id":"000233","recipe":"milestone-review","round":4,"attempt":1,"agent":"claude","root":"/Users/xianxu/Library/Caches/sdlc/review-checkouts/e4d339d87510afbd","reviewed_head":"73d62dcd0172cadfa810791c9cffb937ad75db57","slot":"parley.nvim:3","requested_at":"2026-10-16T11:11:19.749458Z"},"phase":"finished","pid":88766,"started_at":"2026-10-16T11:11:19.885818Z","finished_at":"2026-10-16T11:16:45.222782Z","session_id":"5594be4e-ab01-4efe-a4c4-166784bb2c2a","outcome":"returned"}] -->
