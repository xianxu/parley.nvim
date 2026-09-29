# Boundary Review — parley.nvim#302 (whole-issue close)

| field | value |
|-------|-------|
| issue | 302 — Auto-pair double-at markers while typing |
| repo | parley.nvim |
| issue file | workshop/issues/000302-pair-at-markers.md |
| boundary | whole-issue close |
| milestone | — |
| window | 4539950f811407dc477b5064b043631cea2b760c..6c54dae7412a816b1f17257a6bd09abfce91a723 |
| command | sdlc close --issue 302 |
| reviewer | codex |
| timestamp | 2026-09-29T11:47:18-07:00 |
| verdict | REWORK |

## Review

```verdict
verdict: REWORK
confidence: high
```

The pinned range delivers the main pairing behavior with a small pure helper and meaningful typing tests. However, adjacent pairs fail to auto-close. The committed suite also lacks the promised Blink coexistence regression, and generated help contradicts the changed context behavior. Repository files were unchanged.

1. **Strengths**

   - Production mapping tests verify cursor placement, closer skipping, undo/redo, dot-repeat, user mappings, disabled defaults, and buffer scope.
   - Registry-based starter opt-in preserves the app’s restricted shortcut policy.
   - Context projection retains original transcript text and tests fenced literals, tool payloads, ancestor messages, and topic requests.
   - README and atlas updates cover the new user-facing and architectural surfaces.

2. **Critical findings**

   - **Adjacent pairs do not auto-close** — [at_pair.lua:10](/private/tmp/parley-302-worktree/lua/parley/at_pair.lua:10). In a prepared chat, typing `i@@one@@@@two<Esc>` produces `@@one@@@@two`, instead of `@@one@@@@two@@`. The suffix check rejects the second opener because the preceding closer and first opening character form a run of three at signs. Recognize an unpaired trailing `@` after completed delimiters; add pure and production-typing regressions, including closer skipping and undo. **ARCH-PURPOSE**.

3. **Important findings**

   - **Blink coexistence has no committed regression** — [completion_compatibility.lua:15](/private/tmp/parley-302-worktree/tests/packaging/completion_compatibility.lua:15). This test configures Blink but never prepares a Parley chat or types paired markers. Conversely, the pairing integration test uses starter options without Blink. The `/tmp/parley-302-blink-smoke.lua` mentioned in the issue exists, but is outside the pinned repository. Commit a test exercising actual starter options, pairing, skipping, completion acceptance, and subsequent pairing together. **ARCH-PURPOSE**.
   - **Generated help describes superseded context behavior** — [keybinding_registry.lua:1325](/private/tmp/parley-302-worktree/lua/parley/keybinding_registry.lua:1325). Help says anonymous tags affect “the outline only” and attached tags “prefix the question in AI context,” although this range excludes local tags. Update both statements and sweep current user-facing explanations for the old contract. **ARCH-PURPOSE**.

4. **Minor findings**

   None requiring action.

5. **Test coverage notes**

   All **19 selected spec files passed**, including the complete `ui/keybindings` mapping, architecture sweep, and additional context/outline/topic specs. The adjacent-pair defect was reproduced separately through production remappable typing. The existing multiple-pair test separates pairs with prose and therefore misses it.

   No prior findings require disposition. `git diff --check` reports trailing whitespace in the archived #300 review document.

6. **Architectural notes for upcoming work**

   - **ARCH-DRY — pass:** registry ownership and shared context classification avoid parallel implementations.
   - **ARCH-PURE — pass:** `at_pair.keys` has no IO; editor access stays in the callback. Listed core entities exist at their stated paths.
   - **ARCH-PURPOSE — flag:** adjacent pairing, committed coexistence coverage, and help consistency remain incomplete.
   - **ARCH-MOCK — pass:** pairing introduces no external service dependency; no new direct external-call bypass found.
   - **ARCH-CONSTRAINTS — pass:** pairing examines only the current line, with no chat-wide scan or concurrency.
   - **ARCH-SECURE — pass:** arbitrary line text is handled without command interpolation or credential access.
   - **ARCH-ORDER — pass:** pairing carries no authoritative state between events; each callback derives its decision from current editor contents.
   - **ARCH-FUNERAL — pass:** pairing creates no durable artifacts or background work.

7. **Plan revision recommendations**

   Add a `## Revisions` entry covering adjacent delimiter runs and the required regression matrix. Record the committed Blink coexistence test path once added, and include generated help in the documentation sweep.

```findings
findings:
  - id: new
    severity: Critical
    family: pairing-delimiter-boundaries
    title: |
      Adjacent marker pairs fail to generate the second closing pair
    detail: |
      lua/parley/at_pair.lua:10 rejects an opener following an existing closer. Production typing i@@one@@@@two<Esc> produces @@one@@@@two instead of @@one@@@@two@@. Recognize the unpaired trailing at sign and add pure and mapped-typing regressions covering adjacent pairs, skipping, and undo. ARCH-PURPOSE.
  - id: new
    severity: Important
    family: acceptance-path-regression-coverage
    title: |
      Promised Blink and pairing coexistence lacks a committed regression
    detail: |
      tests/packaging/completion_compatibility.lua:15 initializes Blink without preparing Parley chat mappings, while tests/integration/at_pair_spec.lua:86 tests starter pairing without Blink. Commit the combined production-options typing and completion test currently represented only by a temporary smoke script. ARCH-PURPOSE.
  - id: new
    severity: Important
    family: user-help-contract-consistency
    title: |
      Generated help still claims local tags enter AI context
    detail: |
      lua/parley/keybinding_registry.lua:1325-1326 describes outline-only hiding and attached tags prefixing AI context, contradicting this range's projection behavior and updated README. Correct both statements and sweep current user-facing descriptions for the superseded contract. ARCH-PURPOSE.
```
