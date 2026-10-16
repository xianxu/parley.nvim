---
id: 000265
status: working
deps: []
github_issue:
created: 2026-09-16
updated: 2026-10-16
estimate_hours:
card_mirror: 'aa9951b1b50e2061330b8beb5df4ddeef6e971ef' # card fields mirrored from issue-cards; edit via sdlc
started: 2026-10-16T04:02:56-07:00
claimant:
    operator: Xian Xu
    machine: 4716879978a7b90f6b583da1716fd0e9
    machine_name: MacBook Pro
    workspace: parley.nvim:4
    worktree: /Users/xianxu/workspace/worktree/parley.nvim-slot4/parley.nvim
    repository: github.com/xianxu/parley.nvim
flow: {kind: full, provenance: inferred}
---

# Unify buffer_edit refusal handling across chat command call sites

## Problem

`buffer_edit.replace_user_lines` **raises** on refusal — `error("User edit
unavailable: …")` when the capture fails and `error("User edit refused: …")`
when the apply does (`lua/parley/buffer_edit.lua:92`, `:94`). Thirteen call
sites invoke it. Twelve let that error surface to the user as a bare Lua
traceback; one — `M.cmd.NewQuestion`, added in #263 — wraps it in `pcall` and
logs a readable warning instead.

Surfaced by #263's boundary review, which judged the new behavior the better
one and the divergence a defect: *"The new one is the better UX; the siblings
now diverge from it."* #263 deliberately did not unify the other twelve, because
changing error semantics across features that issue does not otherwise touch,
at its close boundary, is a separable extension rather than the point.

A second, related gap from the same review: there is **no test that a live
generation produces the refusal**. #263's spec proves only that a command
catches and reports one, using a double at the `buffer_edit` seam. Two realer
approaches were measured and rejected there — a second overlapping user capture
is *allowed* (produces no refusal at all), and a detached document silently
re-attaches, because `capture_user` does `document.get(buf) or
document.attach(buf)`. Driving a real generation needs `chat_pending_spec`'s
`fake_runtime` / `fixture` / `start` helpers, which are file-local and not
exported.

## Spec

Two halves, and the second is what gives the first an oracle.

1. **One refusal policy, enforced.** Decide where the pcall lives — most likely
   inside a `buffer_edit` helper that returns `ok, reason` rather than at
   thirteen call sites — and make every chat command report a refusal the same
   way: buffer unchanged, one readable warning naming the command, no bare Lua
   error reaching the user. An arch spec should make a new call site that
   bypasses the policy fail, the way `tests/arch/buffer_mutation_spec.lua`
   already guards the mutation seam itself.
2. **Export a generation fixture.** Lift `chat_pending_spec`'s file-local
   helpers into a shared test helper so any spec can put a buffer under a live
   generation. Without it, every refusal test in the tree is a double, and the
   policy in (1) has no end-to-end oracle.

Audit the call sites first: some may *want* to raise (a programming error in
an internal caller is not the same as a user pressing a key during a stream).
The deliverable is one stated policy with the exceptions named, not a blanket
pcall.

## Done when

- Every chat command that can be invoked by a keystroke reports a refused user
  edit as an unchanged buffer plus one readable warning, worded by
  `buffer_edit.report_refusal`, never raised. That covers the `edit_user_lines`
  sites and the commands that capture and apply by hand (Define, Marker, Branch,
  PruneTopic, InsertChatReference, InterviewTimestamp, SpellCorrection,
  PasteImage). The list of call sites that deliberately raise is **empty**: the
  audit found none that should.
- An arch spec fails when a new call site bypasses the policy: a direct raw
  replace, a pcall around the edit API, an unnamed direct capture/apply caller,
  or a hand-worded refusal in a keystroke file.
- A shared test helper (`tests/helpers/user_edit_capacity.lua`) puts a chat
  buffer under a REAL refusal (the document's user-guard slots held full), and
  command refusals are proven against it rather than against a double. A live
  generation was measured not to refuse user edits, so it is not the oracle (see
  ## Revisions).
- `#263`'s `tests/integration/new_question_spec.lua` refusal case is converted
  to that helper, and its "this is a double" comment removed.

## Core concepts

| Entity | Status | Where | What |
|---|---|---|---|
| `edit_user_lines` | added | lua/parley/buffer_edit.lua | The one way a chat command edits the user's chat: `(command, buf, first, last, lines, opts)` returns `true`, or `false, reason`. A refusal leaves the buffer unchanged and is reported once, naming the command (`opts.quiet`: debug only). Never raises. |
| `report_refusal` | added | lua/parley/buffer_edit.lua | `(command, reason, err, opts)`: the one place a user-edit refusal is worded and logged; `edit_user_lines` and every hand-capturing keystroke command call it (#265 close BR-2). |
| `_replace_user_lines` | added | lua/parley/buffer_edit.lua | The raw capture-and-apply replace, private and non-raising: returns the apply result, or `nil` and the refusal token. Replaces the raising public replace. |
| `edit` | added | lua/parley/refusal.lua | `refusal.edit(command, reason)`: the warning words, `"<command> — Edit not made: <what>; <action>"` (`PREFIX.edit`). |
| `hold` | added | tests/helpers/user_edit_capacity.lua | Fills the editor's 64 real user-guard slots, so the next capture is refused with `capacity`; returns `{ release }`. |

## Plan

Audit, 2026-10-16:
- There are 17 call sites, not 13 (14 in init.lua, comment/float.lua:43, review_send.lua:156 and :258). Every one is reached from a keymap, a command or an autocmd, and none should raise. The only programming-error guards (NewQuestion's `assert(plan.row)`, starter's asserts) are already separate.
- Five sites can leave partial state when the edit refuses:
  - `_slug_rename_chat`: the file is renamed on disk, but the `file:` header is not updated.
  - `move_chat_tree`: files move, and the reference rewrite stops mid-loop.
  - `ChatReview`: the review chat is created, but no back-reference is added.
  - `ChatPrune`: the child file is written, and the parent is left unchanged.
  - `ExchangeCut`: the clipboard holds a cut that did not happen.

Measured, 2026-10-16 (scratch probe, `tests/helpers/respond_fixture` driving a real `chat_respond` generation with a fake transport): **a live generation does NOT make `replace_user_lines` refuse.** Edits inside the streaming answer, on the question row, on the draft row, and over the whole buffer all applied. A capture refuses only on `refused` (editor mid-operation or inside an on_lines callback), `capacity` (the 64 user-guard slots are all live), `detached`, or a bad range or anchor. An apply refuses on `stale`, `refused`, `interrupted`, `busy` or `chunkneeded`. So Done-when 3–4 cannot be met as written (see ## Revisions). The reachable, real refusal is `capacity`: a spec holding 64 real user captures through `buffer_edit.capture_user`. That is the document's own seam, not a double.

- [x] One policy in `buffer_edit`: `M.edit_user_lines(command, buf, first, last, lines, opts)` returns `true` or `false, reason`. On refusal it leaves the buffer unchanged and logs ONE warning that names the command, worded by `refusal.lua` (a new `PREFIX.edit`, plus rows for the unkeyed capture reasons). `opts.quiet` logs at debug instead, for the CursorHold read-repair and the CompleteDone requote, which are cosmetic and retried. `replace_user_lines` becomes module-private.
- [x] Convert all 17 sites. The 5 partial-state sites are reordered so that a refusal changes nothing, or reported honestly where it cannot:
  - `_slug_rename_chat`: edit the header first; rename only once it applied.
  - `move_chat_tree`: continue past a refused rewrite, collect the failures like `asset_errors`, and return `nil, err` with the count.
  - `ChatReview`: report "review chat created; back-reference not added".
  - `ChatPrune`: edit the parent before writing the child.
  - `ExchangeCut`: publish the clipboard only after the cut applied.
- [x] Arch spec: no `replace_user_lines(` outside `buffer_edit.lua`, and no raw `pcall` around the edit API in `lua/`.
- [x] Shared test helper `tests/helpers/user_edit_capacity.lua`: `hold(buf)` fills the real guard slots, and `release()` frees them. Tests:
  - the policy unit (refusal: ok=false, buffer unchanged, one warning naming the command);
  - each partial-state site under a held capacity (nothing changes, or the honest report);
  - NewQuestion's refusal case converted from the double to the helper, with its "this is a double" comment removed.
- [x] Doc-block placement check before close (lessons, #345).

## Log



- 2026-10-16: closed — Full suite green on 517b3bb2 (sdlc-local/suite). Round-2 fixes: BR-1 the editor-error passthrough pinned by a real oracle (a non-modifiable buffer gives status error; the warning carries Neovim text; mutation of the passthrough fails it). BR-5 ChatPrune pcalls the child write (writefile raises E482) and rolls back on a raise or -1; the test raises E482 as Neovim does; mutation (no pcall) fails it. BR-6 Done-when bullets rewritten to the built policy. Round-1 and earlier evidence holds: one policy via edit_user_lines and report_refusal across all keystroke edit sites, the arch spec over the whole direct-caller class, partial-state reorders tested under a real capacity refusal.; review verdict: SHIP
- 2026-10-16: flow upgraded quick → full — 221 added lines in code files (limit 100); an earlier round of this close already ran the full review
### 2026-09-16

Filed from #263's boundary review (`workshop/plans/000263-quick-key-insert-chat-prefix-close-review.md`,
minor findings "inconsistent-refusal-ux" and "stubbed-verdict-not-seam").

### 2026-09-19 — refusal words now have one home (parley#261 M5)

parley#261 M5 added `lua/parley/refusal.lua`, which holds the words for every
submit and generation refusal: what happened, and what to do. Chat commands
speak through `chat_respond`'s `refuse`. `tests/arch/refusal_vocabulary_spec.lua`
fails on a producer reason that has no words, including reasons built at run
time. When this issue settles its `replace_user_lines` policy, the readable
warning should take its words from there too: add rows for `User edit
unavailable` and `User edit refused`, rather than a second phrasebook. Its
`capacity`, `stale` and `refused` rows already cover the document's user-edit
guard.

## Revisions

- 2026-10-16: Done-when 3–4 revised by measurement. A live generation does not refuse user edits (probe above), so "prove a refusal against a buffer under a live generation" has no oracle. Revised: a shared helper puts a chat buffer under a REAL refusal (`capacity`, held through the document's own capture API), and NewQuestion's refusal case is proven against it rather than against a double. Done-when 1 is unchanged; the audit found no site that should raise, so the enumerated exception list is empty and that is stated.

### 2026-10-16 (parley.nvim:4)

- Built as planned. `move_chat_tree`'s reference rewrite turned out to be unreachable by a fixture. After a tree move, `resolve_chat_path` resolves every reference to the file's NEW place: by basename, with an exact hit at the new path winning, even for an absolute old path. So `ref_abs == old_abs` never holds (traced). The site is converted for uniformity (quiet, aggregated into the returned error) but has no test. The possibly dead pass is filed as #350, unclaimed for the TL.
- Tests:
  - The policy unit: applies; refuses without raising with the buffer unchanged and one warning naming the command; quiet means debug only; works again after release.
  - NewQuestion and DeleteEntity: converted from stubs to the real capacity hold.
  - The partial-state cases: ExchangeCut (buffer unchanged, no duplicate on paste), ChatPrune (no child file), slug rename (old name and header kept), ChatReview (honest warning, source unchanged).
  - The arch spec: no direct raw replace; no pcall around the edit API; no raised refusal. The selection guard expects at least 17 policy sites.
- Mutation:
  - The clipboard published before the cut fails ExchangeCut.
  - The child written before the parent fails ChatPrune.
  - Renaming despite a refused header fails the slug case.
  - A planted direct `_replace_user_lines` call fails the arch spec.
- Doc-block placement: every `---` block this branch added or touched sits directly on its definition (a diff-scoped scan found none detached).
- The new specs are routed in atlas/traceability.yaml next to refusal_vocabulary_spec. The atlas `document.md` states the policy and its quiet sites; `entity_delete.md`'s "during generation" claim is corrected.
- Close round 1 (FIX-THEN-SHIP):
  - BR-1: `_replace_user_lines` now returns the editor's error text, and `refusal.edit(command, reason, err)` carries it as the warning's detail. `error` (the editor failing mid-apply) has words of its own. Unit case: the warning reads "<command> — Edit not made: the edit failed while it was being applied; … — <editor error>".
  - BR-2: fixed as a class, not just the named sites.
    - `buffer_edit.report_refusal(command, reason, err, opts)` is the one place the refusal is worded. The keystroke commands that capture by hand now call it: Define (capture and apply), Marker (capture, stale, apply), Branch (capture and apply), PruneTopic, InsertChatReference (two init.lua sites that logged the raw reason, and chat_finder's insert, whose apply refusal was silent), InterviewTimestamp (capture, plus its silent apply), SpellCorrection (no longer raises), and PasteImage (its own lead-in, then refusal's words with the editor error).
    - The arch spec now names every direct capture/apply caller file with its reason (11, including two the review did not list: highlighter.lua's background topic refresh and response_topic.lua's generator guards), and rejects hand-worded refusals in the keystroke files. Mutation: re-wording the interview refusal by hand fails it.
  - Minors:
    - ChatReview gives ONE warning: a quiet edit, then one message that leads with the refusal.
    - A refused header restore after a failed rename is reported.
    - ChatPrune restores the parent if the child file cannot be written (test).
  - Measurement slip on my side: a zsh `for f in $LIST` loop ran once over the whole list (no word splitting) and printed every spec as failing; re-run with a read loop. This is the same zsh trap as in #340.
- 2026-10-16, close round 2 (BR-6): Done-when bullets 1 and 3 were rewritten in place to describe what was built: the hand-capture commands under the policy, the empty list of raising sites, and the capacity helper instead of the measured-impossible live generation. The earlier revision note above records why.
- Close round 2 fixes:
  - BR-1: the editor-error passthrough is pinned by a REAL oracle. A buffer that is not modifiable makes the apply return `error`, with Neovim's "not 'modifiable'" text in the warning. This replaces the earlier stub at the private seam. Mutation: dropping `result.error` fails it.
  - BR-5: ChatPrune `pcall`s the child write, because `vim.fn.writefile` RAISES E482 on a missing directory or a denied write and returns -1 otherwise; both roll the parent back. The test raises E482 as Neovim does. Mutation: an unprotected write fails it. The reviewer's sweep found it was the only edit-first site in the diff with IO that can raise.
  - BR-6: the Done-when rewrite, as above.

