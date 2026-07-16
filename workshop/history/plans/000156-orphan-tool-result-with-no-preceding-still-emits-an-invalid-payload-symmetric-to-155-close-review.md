# Boundary Review — parley.nvim#156 (whole-issue close)

| field | value |
|-------|-------|
| issue | 156 — orphan tool_result (📎: with no preceding 🔧:) still emits an invalid payload — symmetric to #155 |
| repo | parley.nvim |
| issue file | workshop/issues/000156-orphan-tool-result-with-no-preceding-still-emits-an-invalid-payload-symmetric-to-155.md |
| boundary | whole-issue close |
| milestone | — |
| window | b1a9009d7ff9f8759c9f367602ed6129c5691326..HEAD |
| command | sdlc close --issue 156 |
| reviewer | claude |
| timestamp | 2026-07-01T11:45:50-07:00 |
| verdict | SHIP |

## Review

All 6 new tests pass, the full emitter suite (51 tests) is green, lint is clean, and the lone `make test-unit` failure (`find` tool, command-substitution) passes in isolation — a parallel-run flake in a file this diff doesn't touch, not a #156 regression. I have everything I need.

```verdict
verdict: SHIP
confidence: high
```

The #156 diff cleanly completes the symmetric half of #155's tool_use↔tool_result invariant: `resolve_pending` now returns whether an id matched a still-pending `tool_use`, and the emitter drops the `tool_result` block on `false` (orphan or duplicate). This is exactly the design the plan committed to after plan-quality rejected the parallel `batch_ids` set — one source of batch-id state, no reset-timing trap, correct duplicate handling. Implementation matches Spec and Plan precisely; all three Done-when items are delivered; 6 new pure-emitter tests plus 45 pre-existing tests are green; lint clean; atlas updated. Nothing blocks SHIP.

**1. Strengths**
- **Maximally-DRY realization** (`chat_respond.lua:503-511`): reusing the existing `pending` loop to answer "matched?" instead of a second `batch_ids` set is the right call — it's the ARCH-DRY consolidation the plan-quality gate demanded, and it's *more* correct on duplicates (the first result drains `pending`, so the second is not-pending → dropped) than a never-drained parallel set would have been.
- **Reset-timing trap correctly avoided** (`chat_respond.lua:526-534`): `pending` is drained only in `flush_user` gated on `current_user` non-nil, so `[tu, text, tr]` keeps the match. I traced this by hand and the test at `build_messages_spec.lua:1547` pins it. Good defensive test choice.
- **Dangling + orphan composition is sound** (`chat_respond.lua:585-591`): dropping the orphan leaves `current_user` nil, so `flush_user` no-ops and the trailing `if #pending > 0` still synthesizes the dangling `tool_use`'s error result — verified against the test at `build_messages_spec.lua:1571`.
- **ARCH-PURE honored**: tests call `_emit_content_blocks_as_messages` directly with plain tables, zero IO; the buffer reads + `serialize.parse_call` stay in the `build_messages_from_model` normalization seam (`chat_respond.lua:393-407`). Both build paths route through the one emitter (lines 362, 786, 799) — ARCH-PURPOSE shadow-sweep: no hand-maintained restatement, both consumers derive.

**2. Critical findings** — none.

**3. Important findings** — none.

**4. Minor findings**
- **Drop doesn't fully escape the consecutive-same-role risk the Decision cited *against* degrade** (`chat_respond.lua:540-554`). The `## Decision` rejected degrade-to-text partly because "a separate user-text message risks consecutive same-role turns," but drop has the same residual in the `[text, orphan_tr, text]` shape: `flush_assistant` fires on the orphan block, then the trailing text opens a *second* assistant message → two consecutive `assistant` messages, with no Anthropic-side merge (the merge at `providers.lua:782` is Google-only). This is (a) a rare corruption shape, (b) **no worse than pre-#156** (which 400'd on the orphan there anyway), and (c) likely accepted by the current Anthropic API — so it's a note, not a blocker. Worth one sentence in the Decision acknowledging drop shares the same narrow residual, so the rationale isn't overstated.
- The comment at `chat_respond.lua:552-554` says "only the wire excludes it" — accurate, but the buffer-visibility claim is a UX assertion not exercised by any test; fine as documentation.

**5. Test coverage notes**
- Core coverage is strong: orphan-only, orphan-after-matched, orphan-interleaved, `[tu,text,tr]`, duplicate, and dangling+orphan all present and passing, all direct on the pure emitter.
- Gap (minor): the `[text, orphan, text]` consecutive-assistant shape from the finding above is untested — a test asserting the resulting message shape there would document the chosen behavior. Also untested: partial-parallel with an interleaved orphan (`[tu A, tu B, tr A, tr X]`), though it's covered compositionally by existing logic.
- Infra note (not a #156 issue): `tests/unit/tools_builtin_find_spec.lua` "treats command substitution text in name as data" **fails under parallel `make test-unit` but passes in isolation** — a pre-existing flake in a file this diff doesn't touch. Flag for a separate look; it is not a boundary regression.

**6. Architectural notes for upcoming work**
- With both halves landed, payload validity is now invariant-by-construction in the single emitter, and `repair_unmatched_tool_blocks` is demoted to a UX nicety (correctly stated in the atlas). Future work touching either build path should keep routing through `_emit_content_blocks_as_messages` rather than reintroducing inline interleaving — the one-emitter property is what makes both invariants hold.

**7. Plan revision recommendations**
- None required — the Plan checkboxes match the code exactly (`resolve_pending` returns matched?, 6 tests, atlas extended). Optional: a one-line `## Decision` addendum noting drop shares the same rare `[text, orphan, text]` consecutive-same-role residual it cited against degrade (per the Minor finding), so the stated rationale is fully faithful. Not blocking.
