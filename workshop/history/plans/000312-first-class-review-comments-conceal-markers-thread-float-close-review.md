# Boundary Review — parley.nvim#312 (whole-issue close)

| field | value |
|-------|-------|
| issue | 312 — First-class review comments: conceal markers + thread float |
| repo | parley.nvim |
| issue file | workshop/issues/000312-first-class-review-comments-conceal-markers-thread-float.md |
| boundary | whole-issue close |
| milestone | — |
| window | 7d1eb92a1ddaa26ac701bf1f1a46881e61b495fa..03b245448ae147a6d8aba3ebf8e53f05dcbab5e1 |
| command | sdlc close --issue 312 |
| reviewer | claude |
| timestamp | 2026-10-10T11:23:55-07:00 |
| verdict | FIX-THEN-SHIP |

## Review

```verdict
verdict: FIX-THEN-SHIP
confidence: high
```

Four commits landed after M2 closed. They change the design in three ways: the last human turn stays visible inline, turn brackets are re-asserted over treesitter's shortcut-link conceal, and the thread float now reads like a parley chat (`💬: ` / `🤖: ` lines). The code matches the revised Spec table and the two new 2026-10-09/10 Revisions entries. The atlas and lessons were updated in the same range.

I ran all 10 touched spec files at HEAD `03b24544` and they pass: 262 tests, 0 failures. That covers the comment view/thread/codec units, the attach/float/render integration specs, the drill_in unit tests, and the arch and keybinding-agreement specs.

Nothing here blocks shipping. Seven prior Minor findings are still open, plus one new Minor: a headless probe showed the float's line grammar is not injective. A turn holding `<br>🤖: …` comes back from a save as two turns.

**Strengths**
- `view.lua:42-53` `lay_chain` gives one rule for every marker kind: collapse every turn except a last human one. The old special-cased `chain_hidden` is gone. The insert-mode `blocked_spans` (`view.lua:113-128`) now works out what is blocked from a sorted list of allowed insertion points, which replaces the per-kind branches.
- `thread.from_lines` re-parses the joined marker through the buffer's own `_parse_marker_sections` and refuses partial parses (`thread.lua:83-91`). That is the right way to validate text the user typed (ARCH-SECURE).
- `thread.roles` is now the single source for float roles. Both `to_lines` and `paint_roles` derive from it, which fixes BR-21.
- The bracket re-assertion has a matching regression test (`comment_render_spec` "keeps turn brackets visible over treesitter's link conceal"). The lesson about checking a rendered screen was added to `workshop/lessons.md`.
- Snapping is now gated on `conceallevel > 0` (`comment/init.lua:46`), with a test for conceallevel 0.

**Critical:** none.

**Important:** none.

**Minor**
- **New, family `escape-totality`, 2nd finding in the family.** The float's line grammar is not injective, and the codec escape (BR-17) is the first instance of the same gap. A `:w` silently restructures turns whose text contains the grammar's own delimiters. I confirmed these headlessly:

  | Before | After `:w` |
  |---|---|
  | `🤖[a<br>💬: b]` | `🤖[a][b]` |
  | `🤖<X>[q]{a<br>🤖: z}` | `🤖<X>[q]{a}{z}` |
  | `🤖[a<br>]` | `🤖[a]` |

  - **Rule:** every layout the codec or float encodes into must be injective, and the property test must draw turn text from the grammar's own delimiters: `<br>`, `\`, `]` / `}`, line-start `💬:` / `🤖:`, and a trailing `<br>`.
  - **Fix:** escape a continuation line that starts with a prefix, and escape `\` in the codec. Then extend the word list in the generator at `comment_thread_spec.lua:54`.
- **Still open from earlier rounds:** BR-11, BR-17, BR-18 and BR-22 (details in the dispositions below).

**Test coverage notes**
- The property test's word list has no prefix-led continuation lines and no trailing `<br>`. That is why the new finding wasn't caught.
- The bracket fix rests on priority 200 versus treesitter's 100. The spec checks the decoration entries; only the operator's pty check showed the actual screen. A `screenstring()`-based integration test would lock that in, as the new lesson suggests.

**Architecture**
- **ARCH-DRY:** passes. BR-21 is resolved; BR-18 stays open (Minor).
- **ARCH-PURE:** passes. `view` and `thread` are pure and unit-tested without IO.
- **ARCH-PURPOSE:** passes.
- **ARCH-MOCK:** not applicable. The diff adds no external binary or service.
- **ARCH-CONSTRAINTS:** passes. The per-row cost grows by O(sections), and the viewport-bound test still holds at 61 calls per frame.
- **ARCH-SECURE:** flagged by the new Minor. User-typed float text is validated, but the encoding back to the marker loses information.
- **ARCH-ORDER:** passes, except BR-22 is still open.
- **ARCH-FUNERAL:** passes. The float's augroup and extmark are removed on `WinClosed`, and the window-scoped `w:` variables die with the window.

**Plan revisions:** if the injectivity fix lands, the codec and float grammar need a Revisions entry, and so does the property-test generator (its file comment lists the alphabet it draws from).

```findings
dispose:
  - id: BR-9
    disposition: addressed
    note: |
      sync_concealcursor re-reads the base each time it starts forcing and writes only when entering or leaving nvic; comment_attach_spec "keeps a later change to the window's own value" pins it.
  - id: BR-10
    disposition: addressed
    note: |
      Overtaken by the smoke-test redesign: turns_hl paints turn ranges with ParleyReviewUser/Agent again (highlighter.lua:86-88), so the comments at :372 and :698 and atlas review.md:62 are accurate.
  - id: BR-11
    disposition: not-addressed
    note: |
      Partially narrowed by the visible reply, but before-🤖 and anchor-start are still two allowed insert points on one screen column (view.lua:117-118), and the choice is not documented.
  - id: BR-12
    disposition: addressed
    note: |
      Issue Spec line 55 and the M1 row (line 123) now say nvic on marker lines; the issue Revisions carries the BR-3 entry.
  - id: BR-17
    disposition: not-addressed
    note: |
      codec.lua is unchanged since M2; a backslash before a newline still decodes to a literal <br>.
  - id: BR-18
    disposition: not-addressed
    note: |
      comment/init.lua:75-77 still re-derives the default_keymaps gating instead of using native_map.
  - id: BR-21
    disposition: addressed
    note: |
      paint_roles now iterates thread.roles (float.lua:69), the same function to_lines returns; unit test "roles: continuation lines inherit, prefixes switch".
  - id: BR-22
    disposition: not-addressed
    note: |
      The WinClosed handler (float.lua:144-154) is unchanged; :q! with edits still overwrites the unnamed register and shows the warning.
findings:
  - id: new
    severity: Minor
    family: escape-totality
    title: |
      The float's line grammar is not injective; :w silently splits or truncates turns containing its delimiters
    detail: |
      2nd finding in escape-totality (BR-17 is the codec instance). Verified headless: 🤖[a<br>💬: b] becomes 🤖[a][b]; {a<br>🤖: z} becomes {a}{z}; [a<br>] becomes [a]. Rule: every layout the codec or float encodes into must be injective, and the round-trip property test must generate turn text from the grammar's own delimiters (<br>, backslash, ]/}, line-start 💬:/🤖:, trailing <br>). Fix it by escaping prefix-led continuation lines and backslashes, then extend the generator's word list at comment_thread_spec.lua:54.
```
