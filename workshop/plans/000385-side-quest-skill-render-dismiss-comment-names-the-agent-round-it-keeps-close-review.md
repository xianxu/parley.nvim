# Boundary Review — parley.nvim#385 (whole-issue close)

| field | value |
|-------|-------|
| issue | 385 — side-quest: skill_render dismiss comment names the agent round it keeps |
| repo | parley.nvim |
| issue file | workshop/issues/000385-side-quest-skill-render-dismiss-comment-names-the-agent-round-it-keeps.md |
| boundary | whole-issue close |
| milestone | — |
| window | 7b2911d8b9df17b1ac27c83b87af7ffbabd85a2f..bf27b054c65b62a19fc8d50ac3b7c64e9bc8c44a |
| command | sdlc close --issue 385 |
| reviewer | claude |
| isolation | fenced |
| timestamp | 2026-10-18T07:09:43-07:00 |
| verdict | SHIP |

## Review

```verdict
verdict: SHIP
confidence: high
```

The diff only changes the `M.dismiss` doc comment in `lua/parley/skill_render.lua:82-86`, and the new comment matches the code. `M.dismiss` is an alias of `clear_decorations` (`skill_render.lua:87`). That function calls `replace_kind(buf, not_round, {})` (`:77`), which keeps round-kind diagnostics, and it clears the skill's highlight and footnote namespaces. The agent's round is cleared only through `edit_round` when a submit is confirmed (`edit_round.lua:116`, `session_sync.lua:858`). This matches the comment on `clear_decorations` (`:73-74`) and the namespace rule (`:53-57`). The one `## Done when` clause is met: the comment says dismiss clears the review skill's decorations and that the agent's round (#383) stays until the next confirmed submit. There is no behavior change, so no regression test is needed. Nothing blocks SHIP.

1. **Strengths**
   - The new comment uses the same wording as the existing `clear_decorations` comment ("is not the skill's", "confirmed submit"), so the codebase describes this one way (`skill_render.lua:73-74`, `:84-86`).
   - The scope is exactly what the Spec allows ("fix the comment only"), with no extra changes.

2. **Critical findings:** none.

3. **Important findings:** none.

4. **Minor findings**
   - In `skill_render.lua:84`, "cleared only at the next round start" means the review skill's round, but it sits right next to "The agent's round (#383)". The word "round" now means two different things in one comment. Writing "the next review-skill run" would remove the ambiguity. Other places in the window that use "round": `:82-86` only. The `clear_decorations` comment avoids the problem by saying "skill diagnostics".
   - The issue's `## Plan` section is an empty `- [ ]` checkbox. That's acceptable for a quick-flow comment fix, but the checklist claims nothing.

5. **Test coverage notes:** This is a comment-only change, so there's no runtime behavior to test. Existing behavior already backs the claim: `replace_kind` with the `not_round` predicate.

6. **Architectural notes**
   - ARCH-DRY: pass. The comment repeats the `clear_decorations` contract on purpose, for the alias, and it is consistent with it.
   - ARCH-PURE: pass. No code changed.
   - ARCH-PURPOSE: pass. I checked every doc comment in `skill_render.lua` that describes what gets cleared (`:53-57`, `:73-74`, `:82-86`). All three now say the agent's round is kept.

7. **Plan revision recommendations:** none.

```findings
findings:
  - id: new
    severity: Minor
    kind: defect
    family: overloaded-round-term
    title: |
      dismiss comment uses "round" for both the review-skill run and the agent's round
    detail: |
      skill_render.lua:84 says decorations are "cleared only at the next round start" (meaning the review-skill run), then at line 85 names "The agent's round (#383)". Consider "next review-skill run". This is the only instance in the window (lines 82-86).
```

<!-- sdlc-review-usage [{"version":1,"intent":{"disposable_root":true,"id":"87e07445-c2ad-4a1c-be37-025d37538f18","repository":"github.com/xianxu/parley.nvim","issue_id":"000385","recipe":"small-diff-review","round":1,"attempt":1,"agent":"claude","root":"/Users/xianxu/Library/Caches/sdlc/review-checkouts/2b96ee7afc6251c8","reviewed_head":"bf27b054c65b62a19fc8d50ac3b7c64e9bc8c44a","slot":"parley.nvim:3","requested_at":"2026-10-18T14:08:39.683095Z"},"phase":"finished","pid":83597,"started_at":"2026-10-18T14:08:39.775892Z","finished_at":"2026-10-18T14:09:13.502141Z","session_id":"0367157b-d926-4dca-a7b1-dc417e58e825","outcome":"returned"},{"version":1,"intent":{"disposable_root":true,"id":"02c1c6f3-9bf0-4934-8711-561457d847e3","repository":"github.com/xianxu/parley.nvim","issue_id":"000385","recipe":"small-diff-review","round":1,"attempt":2,"agent":"claude","root":"/Users/xianxu/Library/Caches/sdlc/review-checkouts/2b96ee7afc6251c8","reviewed_head":"bf27b054c65b62a19fc8d50ac3b7c64e9bc8c44a","slot":"parley.nvim:3","requested_at":"2026-10-18T14:09:14.11847Z"},"phase":"finished","pid":87689,"started_at":"2026-10-18T14:09:14.211906Z","finished_at":"2026-10-18T14:09:43.164992Z","session_id":"570597f9-0545-4127-be99-05d10ccaa262","outcome":"returned"}] -->

## Review preparation and protocol diagnostics

Quoted values are diagnostic data, not review verdicts.
Protocol attempt 1
reason: "missing valid findings block"
output: "```verdict\nverdict: SHIP\nconfidence: high\n```\n\nThis boundary only changes a comment: the five-line doc comment on `M.dismiss` in `lua/parley/skill_render.lua:82-87`. I checked the comment against the code, not the commit message. `M.dismiss` is an alias of `clear_decorations`. That function calls `replace_kind(buf, not_round, {})` (`skill_render.lua:76`), so it removes every diagnostic in the shared namespace except the agent's round, and clears both highlight namespaces. The agent's round is removed by `edit_round.clear(buf)`, which `session_sync.lua:858-859` calls only when the submit returns `obj.code == 0`, i.e. a confirmed submit. So the new wording is accurate, and it does what the single `## Done when` clause asks: it says dismiss clears the review skill's decorations, and that the agent's round (#383) stays until the next confirmed submit. There is no runtime change, so no regression test is needed. Nothing blocks SHIP.\n\n1. **Strengths**\n   - The new comment matches the wording of the existing `clear_decorations` comment at `skill_render.lua:73-74` and the `replace_kind` rule comment at `:53-57`. All three now describe the round's ownership the same way.\n   - It stays in scope: the change is a comment only, as the Spec requires, and nothing else changed.\n\n2. **Critical findings**: none.\n\n3. **Important findings**: none.\n\n4. **Minor findings**\n   - Two phrases in the comment are slightly loose:\n     - **\"cleared only at the next round start\"** (`:84`) is older text. \"Round\" there means the review skill's run, which now reads ambiguously next to \"the agent's round\" two lines below. It could say \"the next skill run start\" instead.\n     - **\"it clears on the next confirmed submit\"** (`:86-87`) leaves out two other paths that also clear the round: `edit_round.refresh` / `draw` when presentation is not `highlight` (`edit_round.lua:66-67, 88-89`), and a Couch reply that is `cleared` or `unavailable` (`edit_round.lua:111`). This is fine as written, because the comment never says \"only\" and the Spec asked for this exact wording. I'm not filing either point as a finding.\n   - I found no other comments in the window that need the same fix. The other `#383` mentions at `:22`, `:53-57` and `:73-74` are already correct.\n\n5. **Test coverage notes**: No tests are needed because only a comment changed. Existing behaviour tests for the round's ownership are evidence for what the comment describes. I did not run them, since this window doesn't change behaviour.\n\n6. **Architectural notes**\n   - **ARCH-DRY: pass.** No logic was added. `M.dismiss` stays an alias of `clear_decorations`, so there is still a single implementation.\n   - **ARCH-PURE: pass.** No code changed.\n   - **ARCH-PURPOSE: pass.** The Spec names one site whose wording had gone stale. The other comments in the same family (`:53-57`, `:73-74`) already say the round is kept, so the fix covers the whole class.\n\n7. **Plan revision recommendations**: none. The `## Plan` has one empty `- [ ]` item, which is normal for the quick flow.\n\n```findings\n```"

truncated: false
retained-bytes: 0000003314
