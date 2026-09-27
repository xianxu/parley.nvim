# Boundary Review — parley.nvim#284 (whole-issue close)

| field | value |
|-------|-------|
| issue | 284 — Add private note prefix shortcut |
| repo | parley.nvim |
| issue file | workshop/issues/000284-private-note-prefix-shortcut.md |
| boundary | whole-issue close |
| milestone | — |
| window | c231e52d3bfaab13eaec73983c1aa20ae2a4f8e3..f77163e9b3dbd997c3c4a66041a7f6ba9b72e347 |
| command | sdlc close --issue 284 |
| reviewer | codex |
| timestamp | 2026-09-26T20:25:12-07:00 |
| verdict | REWORK |

## Review

```verdict
verdict: REWORK
confidence: high
```

The private-note shortcut satisfies #284’s functional contract: registry-based bindings cover chat and Markdown, custom prefixes work, and prune retains `<C-g>b`. Two documentation defects in the pinned range need correction. The broader test slice also did not complete successfully, so its claimed green result remains unverified.

1. **Strengths**

   - Shared registry and callbacks keep chat/Markdown bindings and help consistent.
   - Real Normal/Insert keystroke tests verify custom prefixes, adjacent-text preservation, and cursor placement.
   - Launcher ownership and concurrency protections passed all eight packaging tests.

2. **Critical findings**

   None confirmed.

3. **Important findings**

   - **README omits the new shortcut and migration.** [config.lua:414](/Users/xianxu/workspace/parley.nvim/lua/parley/config.lua:414) changes prune’s default and introduces `chat_shortcut_private_note`, but [README.md:55](/Users/xianxu/workspace/parley.nvim/README.md:55) documents neither. Add Option+p’s behavior, supported modes, configuration key, and prune’s `<C-g>b` binding.
   - **Packaged tutorial links to an absent file.** [basics.md:106](/Users/xianxu/workspace/parley.nvim/packaging/tutorials/basics.md:106) introduces a branch link whose target is absent from the pinned tree. [starter.lua:127](/Users/xianxu/workspace/parley.nvim/lua/parley/starter.lua:127) seeds only the three tutorial files. Following this link on a fresh installation cannot open the example. Restore plain question text, or package and seed the target. **ARCH-PURPOSE**.

4. **Minor findings**

   None.

5. **Test coverage notes**

   - Private-note integration: **3 passed**.
   - Keybinding unit tests: **80 passed**; mapping agreement: **33 passed**; architecture sweep: **25 passed**.
   - Packaging launcher: **8 passed**.
   - `make test-spec SPEC=ui/keybindings` exited **2 on both runs**. The branch-child suite stopped without a completion summary; other suites continued. No definitive cause was established. Full captured output: [review log](/tmp/parley-284-review-tests.log).
   - Process-survivor checks were unavailable because `ps` was inaccessible.

6. **Architectural notes**

   - **ARCH-DRY — pass:** bindings and help reuse the registry.
   - **ARCH-PURE — pass:** shortcut logic is a small editor-boundary operation.
   - **ARCH-PURPOSE — flag:** the packaged tutorial’s navigable example lacks its destination.
   - **ARCH-MOCK — pass:** launcher tests exercise controlled executable boundaries; no new external dependency in #284.
   - **ARCH-CONSTRAINTS — pass:** shortcut work is one local insertion, without scans or external calls.
   - **ARCH-SECURE — pass:** no new credential handling; launcher tests use isolated profiles.
   - **ARCH-ORDER — pass:** shortcut introduces no asynchronous state; launcher ordering has controlled tests.
   - **ARCH-FUNERAL — pass:** shortcut adds ordinary transcript content, without a new artifact family.

7. **Plan revision recommendations**

   No design revision needed for #284. Reconcile its verification log with the unsuccessful broader test runs before closing.

```findings
findings:
  - id: new
    severity: Important
    family: user-surface-documentation
    title: |
      README omits Option+p and the prune binding migration
    detail: |
      lua/parley/config.lua:414-419 changes shipped bindings and adds chat_shortcut_private_note, but README.md does not describe them. Document private-note insertion, Normal/Insert support, the configuration key, and prune's retained Ctrl+g b binding.
  - id: new
    severity: Important
    family: packaged-reference-integrity
    title: |
      The shipped Basics tutorial references an unpackaged branch
    detail: |
      packaging/tutorials/basics.md:106 links to a file absent from the pinned tree, and lua/parley/starter.lua:127 seeds only the three tutorials. Restore plain text or package and seed the destination so fresh installations can follow the example. ARCH-PURPOSE.
```
