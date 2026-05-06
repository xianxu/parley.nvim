---
id: 000120
status: working
deps: []
created: 2026-05-06
updated: 2026-05-06
---

# update to branching mode

`<C-g>i` insert a branch point at the current selection or cursor, so that we can for discussion into a side. 

Somewhat related, `<C-g>v` is designed for review: `<C-g>vi` will insert 🤖[] at cursor to allow human to feedback on a piece of text. it follows the convention of turn structure 🤖[]{}[]{}, alternating between human and machine.Both parley and ariadne (through /fix skill) supports such syntax. 

After using coding agent for a while, I think there are benefit of the linear transcript, but allowing easy reference to follow up question is useful, thus the following improved design.

## the design

In parley chat, we allow people to use 🤖[] style to add comment, and follow up a questions. for example, if agent replied: "this is a good use of AWS RedShift", if human doesn't know what a RedShift is, it can select AWS RedShift, and do a <C-g>d (for drill in), this would change the text to "this is a good use of 🤖{AWS RedShift}[|]", put cursor (|) between []. This roughly means that human have a question to ask about AWS RedShift. They can put any questions in [], e.g. "this is a good use of 🤖{AWS RedShift}[what's this? how is it related to iceberg]". Multi-line parsing should be supported inside [], though I suspect multi-line usage less common.

Then, when it comes to next turn `<C-g>g`, we need some update. We should translate all the remaining 🤖[] that needs machine attention, which is roughly 🤖[] line ending with [] (check previous definition and tell me), convert those as quotations and questions in the next submitted question, e.g.

```
> AWS RedShift
what's this? how is it related to iceberg
```
if there are already questions in the next turn, those are appending at the end, leaving exact one blank line between existing unsubmitted question from user and those gathered from inline questions.

After than, we should remove the markups back to its original form, so that transcript reads "this is a good use of AWS RedShift", with new turn having questions referring to AWS RedShift.

I want one additional key binding: `<C-g>r` (first remove <C-g>r and <C-g-R> binding, they are not useful), this would resolve 🤖{Text}[].. syntax to Text. 

## Done when

- `<C-g>q` (visual mode) wraps the selected text as `🤖{T}[|]` and drops the cursor inside the empty `[]` ready for typing.
- `<C-g>r` (normal mode) strips every `🤖{T}[..](..)*` marker in the chat buffer back to plain `T` ("resolve discussion chain"). Markers without a `{T}` body are untouched.
- On `<C-g>g`, all *ready* drill-in markers (last section is non-empty `[]`) are gathered in document order, formatted as quoted Q&A blocks, and appended to the next user turn (one blank line separating from any text the user already typed). The corresponding markers are stripped back to plain `T` in the buffer before the request is sent.
- Existing `<C-g>r` (`chat_toggle_raw_request`) and `<C-g>R` (`chat_toggle_raw_response`) chat keybindings are removed from the registry and their callback wiring; the `:ToggleRawRequest` / `:ToggleRawResponse` commands stay reachable.
- Multi-line text inside `[]` parses correctly end-to-end (drill-in → respond → blockquote).
- Tests cover the pure marker-conversion logic and the chat-respond integration.

## Spec

Inline drill-in markers in chat buffers reuse the existing `🤖{T}[q]{a}[q]...` syntax from the review skill, but with chat-side semantics: *ready* markers become quoted Q&A appended to the next user turn, then strip back to plain `T` so the transcript reads naturally.

### Reuse the existing parser

`lua/parley/skills/review/init.lua` already classifies markers:
- `marker.ready == true` ⇔ last section is non-empty `[]` ⇔ "needs machine attention" — exactly the criterion for drill-in conversion.
- `marker.pending == true` ⇔ last section is non-empty `{}` ⇔ agent asked, human owes reply (not relevant to chat-respond).

Drill-in must reuse `parse_markers`; do not fork it. Cross-tool consistency: parley + ariadne (`/fix` skill) share this syntax.

### Keybindings (chat scope, buffer-local)

| Key       | Mode | Action                                                                                                        |
|-----------|------|---------------------------------------------------------------------------------------------------------------|
| `<C-g>q`  | v    | Wrap selected text `T` as `🤖{T}[]` and place cursor inside `[]`, entering insert mode. Normal mode = no-op.  |
| `<C-g>r`  | n    | Resolve discussion chain: strip every `🤖{T}[..](..)*` marker buffer-wide to `T`. Markers without `{T}` left alone. Visual mode = no-op for now. |

### Removed bindings (chat scope)

- `chat_toggle_raw_request` (`<C-g>r`): registry entry deleted, callback wiring in `init.lua` removed.
- `chat_toggle_raw_response` (`<C-g>R`): same.

The `:ToggleRawRequest` and `:ToggleRawResponse` commands stay accessible. (User has a separate task planned to overhaul that area.)

### Chat-respond integration (`<C-g>g`)

Before message build:

1. Walk `parse_markers(buf_lines)`. Gather all `marker.ready` entries in document order (top → bottom).
2. For each gathered marker, extract:
   - `T` from the leading `{T}` section (skip markers without a `{T}` body — they're plain review markers, not drill-ins).
   - `Q` from the trailing non-empty `[]` section.
3. Format each as a markdown blockquote:
   ```
   > T
   Q
   ```
   Multi-line `T` becomes multiple `> ` lines; multi-line `Q` is preserved verbatim. One blank line separates consecutive gathered blocks.
4. Append to the next user-turn slot. If the user already typed text there, place exactly one blank line between their text and the first gathered block.
5. Strip every gathered marker in-place back to its `{T}` body — same operation as `<C-g>r` but scoped to the converted markers.

### Multi-line `[]` support

The current `find_matching_bracket` walks across newlines, so multi-line section content already parses. End-to-end test must cover the path: visual-select multi-line → drill-in → type multi-line question → chat-respond → expected blockquote + clean strip.

## Plan

- [x] Pure-function module `lua/parley/drill_in.lua`: `parse`, `gather_and_strip`, `resolve_all`, `format_block`, `format_blocks`, `wrap`, `append_blocks`. Multi-line bracket content supported (parser walks the joined buffer text rather than per line).
- [x] `<C-g>q` (visual mode only) wired in registry + `prep_chat`. Selection wraps as `🤖{T}[]`, cursor inside `[]`, `startinsert`. Multi-line selection works; uses `nvim_buf_set_lines` with reconstructed prefix/suffix to stay within the buffer-mutation arch policy.
- [x] `<C-g>r` (normal mode only) wired. Resolves every drill-in marker buffer-wide to plain T.
- [x] Removed `chat_toggle_raw_request` / `chat_toggle_raw_response` registry entries and global callback wiring. `:ToggleRawRequest` / `:ToggleRawResponse` commands stay reachable.
- [x] Drill-in pre-processing hooked into `chat_respond.respond` before message build, with two paths:
  - **Branch path** — cursor on a past exchange that contains ready drill-in markers: strip them in place, insert a new user turn (with `> T` / `Q` block) right after the exchange's answer, cap `end_index` at the inserted turn. Original Q/A preserved.
  - **End-append path** — cursor on unanswered last question or at end: gather all ready drill-ins buffer-wide, append blocks to the next user turn at end of buffer.
  Resubmit detection runs after branch detection: cursor on past exchange with no drill-ins → true resubmit (existing behavior). Buffer rewrite goes through `buffer_edit.replace_all_lines` (new helper).
- [x] 22 unit specs in `tests/unit/drill_in_spec.lua` (parse / gather_and_strip / resolve_all / format / wrap / append_blocks). 3 integration specs in `tests/integration/chat_respond_spec.lua` (gathers + strips on new turn / no quote block when no markers / preserves marker on resubmit). Full suite green.
- [x] Atlas: new `atlas/chat/drill_in.md` (marker shape, lifecycle, skipped paths, quote format, cross-tool consistency, key files, keybindings). Cross-reference added to `atlas/modes/review.md`. `atlas/index.md` updated.
- [ ] Manual smoke: drill-in on a real chat, send via `<C-g>g`, verify the expected blockquote-prefixed user turn and that markers strip cleanly. Manually verify `<C-g>r` resolves a discussion chain.

## Log

### 2026-05-06

Spec'd via brainstorming. Decisions:
- New key `<C-g>q` (not `<C-g>d`) to avoid collision with `chat_delete`.
- Normal-mode `<C-g>q` is a no-op; only visual mode acts.
- `<C-g>r` strips all `🤖{T}[..]..` markers in the buffer ("resolve discussion chain"), normal mode only.
- Existing `<C-g>r`/`<C-g>R` raw-mode toggles are unbound (registry + wiring deleted); commands remain. User has a follow-up task planned to overhaul raw-mode UX.
- Multi-line `[]` content must parse end-to-end.
- Multiple drill-ins are gathered in document order and resolved (stripped) once converted into the next turn.
- Status stays `open` — implementation deferred until #119 closes.

Implementation pass complete. Notes:

- Buffer-mutation arch test (#90) caught two of my early calls (`nvim_buf_set_text` in init.lua's drill-in handler, and `nvim_buf_set_lines` in chat_respond.lua). Resolved by (a) rewriting the visual handler to compute prefix/suffix and use `set_lines` from init.lua (already allow-listed), (b) adding `buffer_edit.replace_all_lines` and routing chat_respond's full-buffer rewrite through it.

- Resubmit detection in chat_respond was initially too coarse — treating any `cursor on question` as resubmit, which suppressed drill-in even when cursor sat on the last unanswered (next-turn) question. Refined to: resubmit only if the question has an answer or cursor is on an answer.

Manual smoke still pending.

### 2026-05-06 (revision)

User clarified: when `<C-g>g` fires on a past exchange that contains drill-in markers, the markers should be interpreted as a *follow-up question*, not a resubmit. The exchange's Q/A stays intact and a new user turn is inserted right after it.

Implemented as the "branch path" in `chat_respond.respond`. Detection runs before the resubmit decision. Original drill-in spec wording said "ready markers anywhere" → end-append; new wording is more nuanced and the branch path takes precedence when cursor is on a past exchange. The end-append path stays for the cursor-at-end case.

Added two integration specs covering the branch (cursor on past exchange with marker → new turn inserted, original answer preserved) and the negative case (cursor on past exchange WITHOUT marker → traditional resubmit still works).

