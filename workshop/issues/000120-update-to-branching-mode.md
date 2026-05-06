---
id: 000120
status: open
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

- [ ] Pure-function module (likely `lua/parley/drill_in.lua`): extract conversion + strip logic. Inputs: buffer lines + ready markers from `parse_markers`. Outputs: (a) list of `{quoted_text, question}` blocks, (b) lines with converted markers stripped to `{T}` body.
- [ ] Wire `<C-g>q` keybinding (visual mode only) in `keybinding_registry.lua` + chat-buffer setup. Selection → wrap as `🤖{<selection>}[]`, cursor inside `[]`, `startinsert`.
- [ ] Wire `<C-g>r` keybinding (normal mode only) in registry + chat-buffer setup. Resolves all `🤖{T}[..]..` markers buffer-wide to `T`.
- [ ] Remove `chat_toggle_raw_request` / `chat_toggle_raw_response` registry entries and their callback wiring in `init.lua`. Verify `:ToggleRawRequest` / `:ToggleRawResponse` commands still work.
- [ ] Hook drill-in gather/append/strip into chat-respond pipeline (`chat_respond.lua`) before message build.
- [ ] Tests: pure-function unit specs (single, multi, multi-line, mixed with non-`{T}` review markers, empty selection edge cases, blank-line separator logic). Integration spec for the chat-respond hook.
- [ ] Atlas: locate the canonical marker doc (likely under `atlas/skills/` or `atlas/chat/`) and document the dual-purpose nature of `🤖{T}[..]..` — review skill on non-chat markdown, drill-in on chat.
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

