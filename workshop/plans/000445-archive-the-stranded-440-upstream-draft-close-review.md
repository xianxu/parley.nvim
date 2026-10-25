# Boundary Review — parley.nvim#445 (whole-issue close)

| field | value |
|-------|-------|
| issue | 445 — Archive the stranded #440 upstream draft |
| repo | parley.nvim |
| issue file | workshop/issues/000445-archive-the-stranded-440-upstream-draft.md |
| boundary | whole-issue close |
| milestone | — |
| window | 354bb2a7a639306b0be17454e1b6c5df2790e29a..5b62dcac2dab846717bd9ae22be8dc5d6594f1c1 |
| command | sdlc close --issue 445 |
| reviewer | claude (anthropic; author anthropic) |
| isolation | fenced |
| timestamp | 2026-10-25T12:25:19-07:00 |
| verdict | not-run |

## Review



<!-- sdlc-review-usage [{"version":1,"intent":{"disposable_root":true,"id":"ce5110e6-b4a5-4411-977d-13f10e8d01ad","repository":"github.com/xianxu/parley.nvim","issue_id":"000445","recipe":"small-diff-review","round":1,"attempt":1,"agent":"claude","root":"/Volumes/TestScratch/review-checkouts/aaf2193eb62342ae","reviewed_head":"5b62dcac2dab846717bd9ae22be8dc5d6594f1c1","slot":"parley.nvim:1","requested_at":"2026-10-25T19:24:24.976938Z"},"phase":"finished","pid":91988,"started_at":"2026-10-25T19:24:25.109272Z","finished_at":"2026-10-25T19:24:47.618529Z","session_id":"62899547-2148-43ec-9884-eb0681b504d5","outcome":"returned"},{"version":1,"intent":{"disposable_root":true,"id":"013bfe09-67ae-4554-8d8b-32ccda874789","repository":"github.com/xianxu/parley.nvim","issue_id":"000445","recipe":"small-diff-review","round":1,"attempt":2,"agent":"claude","root":"/Volumes/TestScratch/review-checkouts/aaf2193eb62342ae","reviewed_head":"5b62dcac2dab846717bd9ae22be8dc5d6594f1c1","slot":"parley.nvim:1","requested_at":"2026-10-25T19:24:52.716497Z"},"phase":"finished","pid":2022,"started_at":"2026-10-25T19:24:52.853336Z","finished_at":"2026-10-25T19:25:16.807407Z","session_id":"138ca156-3d41-4251-94ef-fa36232d287a","outcome":"returned"}] -->

## Review preparation and protocol diagnostics

Quoted values are diagnostic data, not review verdicts.
Protocol attempt 1
reason: "missing valid findings block"
output: "```verdict\nverdict: SHIP\nconfidence: high\n```\n\nThe change does what the Spec asks. Commit 40943bc8 is a pure rename (`R100`) of `workshop/plans/000440-…-plan.side/upstream-neovim-draft.md` to `workshop/history/plans/000440-…-plan.side/upstream-neovim-draft.md`. The blob is `019dc761539e225e0164bb94a882ef50545afbc6` both before and after, so the file is byte-identical. Both `## Done when` clauses check out:\n\n- **Only at the history path:** `git ls-tree` at head shows the draft only at the history path. No `000440` folder is left under `workshop/plans/`.\n- **The link resolves:** the archived issue links to `../plans/000440-…-plan.side/upstream-neovim-draft.md` at `workshop/history/issues/000440-a-predicate-wait-doing-child-rpc-never-times-out.md:78`. Relative to `workshop/history/issues/`, that path points to `workshop/history/plans/000440-…-plan.side/upstream-neovim-draft.md`, and the file now exists there.\n\nOutside the tracker paths, the diff contains only this rename. Nothing else was changed.\n\n1. **Strengths**\n   - The move is a pure git rename (`R100`) with an identical blob. This meets the byte-for-byte requirement and keeps the file's history easy to follow.\n   - The scope stays tight: the archived #440 issue was not edited, as the Spec required. Its existing relative link now resolves without any change.\n   - The source side folder is fully removed, so nothing is left behind in `workshop/plans/`.\n\n2. **Critical findings:** none.\n\n3. **Important findings:** none.\n\n4. **Minor findings:** none.\n\n5. **Test coverage notes:** This change moves a tracker document only and changes no runtime behavior, so no tests are needed. I checked both Done-when clauses directly with `git ls-tree` and by resolving the link path.\n\n6. **Architectural notes**\n   - **ARCH-DRY: pass.** Nothing is duplicated, and only one copy of the draft exists at head.\n   - **ARCH-PURE: pass.** No code changed.\n   - **ARCH-PURPOSE: pass.** The issue's whole purpose is archiving this one stranded file. The general fix to the archive step belongs to ariadne#623, which the issue cites.\n   - **ARCH-EVOLVE: pass.** No persisted format changed.\n\n7. **Plan revision recommendations:** none.\n\n```findings\n```"
Protocol attempt 2
reason: "missing valid findings block"
output: "```verdict\nverdict: SHIP\nconfidence: high\n```\n\nThis change moves one stranded file and touches nothing else, and both `## Done when` clauses hold at the head commit. Git reports the move as a pure rename (R100): `workshop/plans/000440-…-plan.side/upstream-neovim-draft.md` now lives at `workshop/history/plans/000440-…-plan.side/upstream-neovim-draft.md`. The file content (blob `019dc761539e225e0164bb94a882ef50545afbc6`) is the same at base and head, so the bytes were not changed. At head the file exists only at the history path, and the `workshop/plans/000440-…-plan.side/` folder is gone. The archived #440 issue links to it as `../plans/000440-…-plan.side/upstream-neovim-draft.md` (`workshop/history/issues/000440-a-predicate-wait-doing-child-rpc-never-times-out.md:78`). From `workshop/history/issues/` that link points to the new location, which exists. Nothing blocks SHIP.\n\n1. **Strengths**\n   - The move keeps the file byte-for-byte (R100, same blob at both paths), as the Spec requires.\n   - The scope stays as tight as the Spec says (\"Fix nothing else\"). Apart from the move, the range only touches the #445 issue file itself.\n   - Moving the file was the right fix: the archived #440 link starts resolving without anyone editing the archived issue.\n   - No other file in the tree still points at the old active path. The only mentions left are the #445 issue's own Problem and Spec text, which describe the move.\n\n2. **Critical findings:** none.\n\n3. **Important findings:** none.\n\n4. **Minor findings:** none.\n\n5. **Test coverage notes:** no executable behavior changed, so no regression test is needed. I checked both Done-when clauses directly: blob identity with `git ls-tree`, file location with `git diff -M --name-status` and the filesystem, and link resolution by tracing the relative path. The \"on main\" part can only be confirmed once this merges. At this head it holds.\n\n6. **Architectural notes**\n   - **ARCH-DRY: pass.** No logic was added.\n   - **ARCH-PURE: pass.** There is no code in the window.\n   - **ARCH-PURPOSE: pass.** The issue's whole purpose is this one stranded file, and it is fully done. The general fix to the archive step belongs to ariadne#623, which is a separate change.\n   - **ARCH-EVOLVE: pass.** No persisted format changed. This was a file move only.\n\n7. **Plan revision recommendations:** none. The plan still matches the code.\n\n```findings\n```"

truncated: false
retained-bytes: 0000004972

---

## Re-review — 2026-10-25T12:29:03-07:00 (SHIP)

| field | value |
|-------|-------|
| issue | 445 — Archive the stranded #440 upstream draft |
| repo | parley.nvim |
| issue file | workshop/issues/000445-archive-the-stranded-440-upstream-draft.md |
| boundary | whole-issue close |
| milestone | — |
| window | 354bb2a7a639306b0be17454e1b6c5df2790e29a..5b62dcac2dab846717bd9ae22be8dc5d6594f1c1 |
| command | sdlc close --issue 445 |
| reviewer | claude (anthropic; author anthropic) |
| isolation | fenced |
| timestamp | 2026-10-25T12:29:03-07:00 |
| verdict | SHIP |

## Review

```verdict
verdict: SHIP
confidence: high
```

This change moves one file and touches nothing else, and it does exactly what the Spec asks. The full-range name-status shows `R100`, a byte-for-byte rename from `workshop/plans/000440-…-plan.side/upstream-neovim-draft.md` to `workshop/history/plans/000440-…-plan.side/upstream-neovim-draft.md`. At head, the tree holds blob `019dc761539e225e0164bb94a882ef50545afbc6` only at the history path. Both Done-when clauses hold. The draft exists only at the history path with the stated blob. The archived #440 issue (`workshop/history/issues/000440-…md:78`) links to `../plans/000440-…-plan.side/upstream-neovim-draft.md`, which now resolves to `workshop/history/plans/…`. The issue changes nothing outside that move, and there is no executable code, test surface or user-facing docs surface involved. Nothing blocks SHIP.

1. **Strengths**
   - It is a pure rename (R100), so content and blob identity are kept exactly as the Spec required.
   - It doesn't rewrite the #440 link: moving the file to the path the archived link already targets fixes the reference without editing the archived issue.
   - I checked the class of the problem, not just this file. `workshop/plans/` has no other stranded `.side` folder, so this one file is the whole family. The fix for future cases is the cited ariadne#623.

2. **Critical findings:** none.

3. **Important findings:** none.

4. **Minor findings:** none. The `## Plan` section in the issue is empty, which is acceptable for the quick flow.

5. **Test coverage notes:** No executable behavior changed, so no regression test is needed. I verified the result with `git ls-tree` at head (blob and path) and by resolving the relative link from the archived #440 issue.

6. **Architectural notes**
   - ARCH-DRY: pass. Nothing is duplicated; the file exists at only one path.
   - ARCH-PURE: pass. No code is involved.
   - ARCH-PURPOSE: pass. The issue's whole purpose, archiving the stranded draft so the link resolves, is delivered, and no other stranded instances remain.
   - ARCH-EVOLVE: pass. No persisted format changed.

7. **Plan revision recommendations:** none.

```findings
findings: []
```

<!-- sdlc-review-usage [{"version":1,"intent":{"disposable_root":true,"id":"32167f2f-298d-4c34-933f-db8db893ce04","repository":"github.com/xianxu/parley.nvim","issue_id":"000445","recipe":"small-diff-review","round":1,"attempt":1,"agent":"claude","root":"/Volumes/TestScratch/review-checkouts/93a57e8cab32fa21","reviewed_head":"5b62dcac2dab846717bd9ae22be8dc5d6594f1c1","slot":"parley.nvim:1","requested_at":"2026-10-25T19:28:04.009277Z"},"phase":"finished","pid":75222,"started_at":"2026-10-25T19:28:04.143455Z","finished_at":"2026-10-25T19:28:30.116018Z","session_id":"d76436d1-a067-4665-89a4-a4db245a0b1b","outcome":"returned"},{"version":1,"intent":{"disposable_root":true,"id":"bbf58ff0-6396-433c-8c3a-1ddcbb23d8b4","repository":"github.com/xianxu/parley.nvim","issue_id":"000445","recipe":"small-diff-review","round":1,"attempt":2,"agent":"claude","root":"/Volumes/TestScratch/review-checkouts/93a57e8cab32fa21","reviewed_head":"5b62dcac2dab846717bd9ae22be8dc5d6594f1c1","slot":"parley.nvim:1","requested_at":"2026-10-25T19:28:35.738031Z"},"phase":"finished","pid":85822,"started_at":"2026-10-25T19:28:35.869708Z","finished_at":"2026-10-25T19:29:00.541175Z","session_id":"59367028-8ef3-4a2b-9917-321596bf0840","outcome":"returned"}] -->

## Review preparation and protocol diagnostics

Quoted values are diagnostic data, not review verdicts.
Protocol attempt 1
reason: "missing valid findings block"
output: "```verdict\nverdict: SHIP\nconfidence: high\n```\n\nThis change moves one file, and it does what the issue asked. `git diff -M` shows the draft as `R100`, a 100%-similarity rename. It went from `workshop/plans/000440-…-plan.side/upstream-neovim-draft.md` to `workshop/history/plans/000440-…-plan.side/upstream-neovim-draft.md`. At the head commit the history-path blob is `019dc761539e225e0164bb94a882ef50545afbc6`, which matches the Spec. The archived #440 issue (`workshop/history/issues/000440-…md:78`) links to `../plans/000440-…-plan.side/upstream-neovim-draft.md`. That link resolves to the new history path, which now exists. No copy remains under the active `workshop/plans/`. `git grep` finds no other reference to the old `workshop/plans/000440` path. The issue file itself changed only in claim/flow frontmatter. The Plan and Log sections are still empty, which is normal at this point in the quick flow. Nothing blocks SHIP.\n\n1. **Strengths**\n   - The move is byte-for-byte: `R100`, and the blob hash matches the Spec exactly.\n   - The scope stays inside the Spec. Only the one file moved, and the #440 issue was not edited, because its relative link already resolves.\n   - No copy of the file is left behind at the active path.\n\n2. **Critical findings:** none.\n\n3. **Important findings:** none.\n\n4. **Minor findings:** none.\n\n5. **Test coverage notes:** Nothing executable changed, so no test is needed. Both Done-when clauses were checked directly:\n   - **Blob only at the history path:** confirmed with `git ls-tree -r`.\n   - **Link resolves:** confirmed by resolving the relative path from `workshop/history/issues/` and finding the file there.\n\n6. **Architectural notes**\n   - **ARCH-DRY: pass.** No logic was added, so nothing is duplicated.\n   - **ARCH-PURE: pass.** There is no code.\n   - **ARCH-PURPOSE: pass.** The fix to the archive step for future cases is properly left to ariadne#623. This item's purpose was to archive the one stranded file, and it does that completely.\n   - **ARCH-EVOLVE: pass.** No persisted format changed. The issue frontmatter only gained fields the sdlc tool already writes (`started`, `claimant`, `flow`).\n   - No atlas or README update is needed, because nothing user-facing changed.\n\n7. **Plan revision recommendations:** none.\n\n```findings\n```"

truncated: false
retained-bytes: 0000002552
