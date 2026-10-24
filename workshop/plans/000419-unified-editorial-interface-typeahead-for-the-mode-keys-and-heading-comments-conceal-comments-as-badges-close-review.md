# Boundary Review — parley.nvim#419 (whole-issue close)

| field | value |
|-------|-------|
| issue | 419 — unified-editorial-interface: typeahead for the mode keys and heading comments; conceal comments as badges |
| repo | parley.nvim |
| issue file | workshop/issues/000419-unified-editorial-interface-typeahead-for-the-mode-keys-and-heading-comments-conceal-comments-as-badges.md |
| boundary | whole-issue close |
| milestone | — |
| window | d1bb4ba89c0466ae17c02520afdbbfd705ff0537..27c670ca388c57ef20614adfed96242b34d894c2 |
| command | sdlc close --issue 419 |
| reviewer | codex (openai; author openai) |
| isolation | fenced |
| timestamp | 2026-10-24T10:53:34-07:00 |
| verdict | REWORK |

## Review

```verdict
verdict: REWORK
confidence: high
```

The implementation substantially delivers the revised collaborative interface, and the mapped tests pass. Three findings block this boundary: legacy metadata can disable chat protection, monthly descendant updates can disappear from attention, and the brief loader contradicts its PURE classification.

1. **Strengths**

- Verified the packaged manifest and all 83 non-adapter members byte-for-byte against the pinned Ariadne commit.
- Local proposal admission checks complete marker classification before effects and binds writes to the captured source bytes.
- README and atlas updates describe the revised interface, local question limitation, monthly layout, and historical presentation compatibility.

2. **Critical findings**

```findings
findings:
  - id: new
    severity: Critical
    kind: defect
    family: legacy-evidence-preservation
    title: |
      Ignored legacy map values disable valid chat protection
    detail: |
      lua/parley/skills/review/collaboration_value.lua:122 rejects an entire map when an unrelated value fails the old decoder. With collaboration-mode: {chat: [Notes], default: false}, the pinned Go readFrontmatter retains Notes as chat and notices the retired default; Lua instead reports unread frontmatter and produces zero chat sections. A production validate_edits probe then ALLOWED rewriting “operator text” in a numbered Notes item, while the same proposal without default: false was rejected. Preserve recognized chat evidence when processing ignored map values, match the pinned notices, and add admission regressions covering default and unrelated map members. ARCH-PURPOSE, ARCH-SECURE.
  - id: new
    severity: Critical
    kind: defect
    family: attention-event-admission
    title: |
      Rewritten monthly descendants require their parent to remain in the finder
    detail: |
      lua/parley/attention.lua:204 applies state.entries[parent] to rewritten events as well as new discoveries. After a monthly child leaves the finder, a tracked same-root grandchild stops reporting subsequent agent writes even while the root remains tracked. A filesystem-backed probe with a valid parent relation, seen_at=1500 and mtime=2000 produced a rewritten event from attention_model.scan but {} from Attention.discover. Separate admission of new attachments from updates to established entries; preserve the model’s rewrite event without requiring the parent’s continued finder membership. Add a sequence regression covering parent removal followed by a descendant rewrite. ARCH-ORDER, ARCH-PURPOSE.
  - id: new
    severity: Critical
    kind: defect
    family: core-concept-purity
    title: |
      The brief loader contradicts its PURE Core concepts classification
    detail: |
      workshop/plans/000419-collaborative-chat-interface-plan.md:37 lists brief.list/load/context under Pure entities, but lua/parley/skills/review/brief.lua:23 and :70 read files through io.open. tests/unit/review_brief_spec.lua:20 creates and deletes mutable filesystem fixtures. This violates the boundary’s explicit PURE classification rule. Promote the loader to INTEGRATION and document its filesystem seam, or extract pure validation/assembly functions and keep reads in a thin adapter. Add a Revisions entry correcting the table and test strategy. ARCH-PURE.
```

3. **Important findings**

None.

4. **Minor findings**

None.

5. **Test coverage notes**

- `make test-spec SPEC=modes/review` and `SPEC=ui/attention_finder` passed on Neovim 0.12.5, with clean process censuses.
- Additional isolated probes on Neovim 0.11.7 reproduced both behavioral findings.
- Existing tests omit ignored map-value combinations and parent-removal/rewrite sequences.
- `git diff --check` passed. Repository files were unchanged.

6. **Architectural notes for upcoming work**

| Principle | Result |
|---|---|
| ARCH-DRY | Pass: shared policy and edit transformation are reused. |
| ARCH-PURE | **Flag:** brief loader classification contradicts IO behavior. |
| ARCH-PURPOSE | **Flag:** legacy protection and monthly attention have gaps. |
| ARCH-MOCK | Pass: existing provider and filesystem-backed Couch seams are reused. |
| ARCH-CONSTRAINTS | Pass: snapshot limits, viewport bounds, and growth controls are present. |
| ARCH-SECURE | **Flag:** discarded legacy evidence weakens operator-text protection. |
| ARCH-ORDER | **Flag:** attention loses established rewrite events after parent removal. |
| ARCH-FUNERAL | Pass: no new unbounded runtime artifact family identified. |
| ARCH-EVOLVE | Pass: historical projection preserves stored presentation semantics without introducing a rewriting codec. |

7. **Plan revision recommendations**

Add `## Revisions` entries that:

- Correct the brief loader’s classification and filesystem test strategy.
- Enumerate ignored legacy map values and require retained chat evidence plus exact notices.
- Distinguish new side-document discovery from established-entry rewrites, including parent removal from the finder.

<!-- sdlc-review-usage [{"version":1,"intent":{"disposable_root":true,"id":"606f5fc3-dd7f-4a21-a54c-773bff826083","repository":"github.com/xianxu/parley.nvim","issue_id":"000419","recipe":"milestone-review","round":1,"attempt":1,"agent":"codex","root":"/Volumes/TestScratch/review-checkouts/8be23f625f3c5a55","reviewed_head":"27c670ca388c57ef20614adfed96242b34d894c2","slot":"parley.nvim:3","requested_at":"2026-10-24T17:48:29.372022Z"},"phase":"finished","pid":28154,"started_at":"2026-10-24T17:48:29.514339Z","finished_at":"2026-10-24T17:53:23.814925Z","session_id":"01a16f07-4537-7913-a8d1-1d3f31d50d67","outcome":"returned"}] -->
