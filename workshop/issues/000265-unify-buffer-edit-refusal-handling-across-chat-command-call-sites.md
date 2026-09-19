---
id: 000265
status: open
deps: []
github_issue:
created: 2026-09-16
updated: 2026-09-16
estimate_hours:
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

- Every chat command that can be invoked by a keystroke reports a
  `replace_user_lines` refusal as an unchanged buffer plus one readable
  warning; the call sites that deliberately raise are enumerated with reasons.
- An arch spec fails when a new call site bypasses the policy.
- A shared test helper can place a chat buffer under a live generation, and at
  least one command's refusal is proven against it rather than against a double.
- `#263`'s `tests/integration/new_question_spec.lua` refusal case is converted
  to that helper, and its "this is a double" comment removed.

## Plan

- [ ] Audit all 13 `replace_user_lines` call sites; classify raise vs report.
- [ ] Extract the shared generation fixture out of `chat_pending_spec`.
- [ ] Implement the single refusal policy + the arch spec that enforces it.
- [ ] Convert #263's refusal case to the real fixture.

## Log

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
