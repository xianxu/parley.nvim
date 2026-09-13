---
id: 000231
status: working
deps: []
github_issue:
created: 2026-09-10
updated: 2026-09-12
estimate_hours: 6.93
started: 2026-09-12T18:17:30-07:00
---

# Attach images to questions: paste from clipboard, send to every wire, render in preview

## Problem

Operator request, 2026-09-10. Chats are text-only. A question that needs a
screenshot — a UI bug, a plot, a photograph, a diagram — currently has to be
described in words, which is both lossy and the kind of work the model is good
at doing for you if it can see the thing.

Three parts, and they are independent enough to fail separately:

1. **Capture.** Paste an image from the system clipboard into the transcript,
   saved to disk with a unique name.
2. **Send.** Get it to the model. Every wire encodes images differently.
3. **Read.** The transcript is a markdown file the operator reads and previews;
   an attached image should render in `:MarkdownPreview`, not appear as a path.

Part 3 comes free if part 1 writes ordinary markdown, which is the argument for
doing so.

## Spec

### Operator decisions, 2026-09-10

| question | decision |
|---|---|
| keybinding | **`<M-v>`** — `v` for paste, free, joins the alt family |
| storage | **`<chat-root>/assets/<chat-timestamp>/`** — per chat, not flat; keyed by timestamp, no slug (2026-09-12) |
| lifetime | **images follow `chat_memory`** — dropped when their exchange is summarized |

**`<M-i>` was the request and is not available**: it is `branch_ref`
(`{ "<M-i>", "<M-S-CR>", "<C-g>i" }`), the fork chord in constant use. Noted
alternative: the operator observes that `chat_prune` (`<M-p>`) is "almost never"
used, so `<M-p>` — a better mnemonic still — is a one-line swap if wanted, at
the cost of rebinding or unbinding prune. Recorded rather than taken, because
`<M-v>` is free and displacing a shipped binding is a separate decision.

### Storage, and why per-chat

`<chat-root>/assets/<chat-timestamp>/2026-09-10.14-22-31.487.png` — e.g.
`assets/2026-09-10.14-20-03.112/2026-09-10.14-22-31.487.png` for the chat
`2026-09-10.14-20-03.112_ui-bug.md`.

The flat `<chat-root>/images/` the request described is simpler to write and
breaks on the operations parley already has: `:ParleyChatMove` moves a chat tree
between roots and cannot know which flat images belong to it, and tree export
has the same problem. That is #224's failure shape — a reference that resolves
until someone moves the thing it names. A per-chat subfolder moves with its
chat and leaves no orphan when a chat is deleted.

**Decided 2026-09-12 — timestamp prefix, no slug, folder named `assets/`.**
The chat basename contains the slug, and slugs change (#224); a folder named
after the basename would be a second thing `ParleySlug` must rename. The
operator's reasoning: slugs exist for human consumption, and humans reach an
asset *through the transcript* (the index document), so the folder never needs
a slug to remind anyone of anything. The timestamp is the identity; the slug is
decoration — #224's lesson applied. `assets/`, not `images/`, because the same
sidecar will hold whatever else cannot live in markdown (#239's model-generated
images first; other binary kinds later) — one folder, one rule, one writer.

### Transcript representation

Ordinary markdown: `![](assets/<chat-ts>/2026-09-10.14-22-31.487.png)`, relative
to the chat file. This is not a cosmetic choice — it is what makes part 3 free,
keeps the file readable in any editor, and means an operator can delete or
reorder an attachment with normal editing.

The parser must learn that an image link inside a question block is an
**attachment**, not prose. Everything else about the exchange model stays as it
is.

### Sending: three wires, three shapes

Anthropic takes a content block with a base64 (or Files API) source; OpenAI and
Gemini use different shapes again. **The exact shapes are to be read from each
provider's current docs during implementation, not recalled** — this is the
`shared/live-sources.md` rule, and getting an image envelope wrong fails at
runtime with a 400 rather than at lint.

`build_messages` already turns exchanges into wire messages, so the attachment
becomes another thing it emits, per wire, beside text.

### Lifetime: images follow the memory window

An image re-sent on every turn is the most expensive thing in a transcript — a
screenshot can outweigh the entire conversation, and the cost recurs per
request. `chat_memory` already replaces old exchanges with `📝:` summaries;
attachments in a summarized exchange are dropped with it.

**Consequence:** a follow-up question about an image works while the exchange is
recent, and stops working once it ages out. The summary line should say an image
was present, so the model is not left inferring it from context that no longer
exists. (This is the operator's decision, taken with the cost tradeoff stated.)

### The clipboard is an external dependency

Reading an image from the system clipboard is platform-specific and shells out —
`pngpaste`/`osascript` on macOS, `wl-paste`/`xclip` on Linux. That is a seam
needing a stateful fake (ARCH-MOCK): tests must not depend on a real clipboard,
and the failure modes are real (binary missing, clipboard holds text, clipboard
holds an unsupported format).

## Done when

- `<M-v>` in a chat buffer with an image on the clipboard writes the file and
  inserts a markdown image link at the cursor; with **text** on the clipboard it
  declines with a message and writes nothing.
- The file lands under the per-chat folder with a unique timestamp name; two
  pastes in the same second do not collide.
- The question reaches each wire with the image in that wire's own shape —
  asserted per wire against a payload, not by hoping one shape works everywhere.
- The image renders in `:MarkdownPreview` (it is ordinary markdown, so this is
  an assertion about the link being relative and correct, not about the plugin).
- An image in a summarized exchange is NOT re-sent, and the summary says one was
  there.
- `:ParleyChatMove` moves a chat's images with it and the links still resolve —
  the #224 lesson applied to a second kind of reference.
- A missing clipboard binary produces a diagnosis naming what to install, not a
  stack trace.

## Estimate

```estimate
model: estimate-logic-v3.1
familiarity: 1.0
item: issue-spec design=1.0 impl=0.08
item: lua-neovim design=0.2 impl=0.5
item: lua-neovim design=0.2 impl=0.6
item: lua-neovim design=0.2 impl=0.6
item: lua-neovim design=0.2 impl=0.3
item: lua-neovim design=0.2 impl=0.5
item: lua-neovim design=0.2 impl=0.3
item: real-api-discovery design=0.0 impl=0.18
item: real-api-discovery design=0.0 impl=0.18
item: real-api-discovery design=0.0 impl=0.18
item: atlas-docs design=0.1 impl=0.05
item: atlas-docs design=0.1 impl=0.05
item: milestone-review design=0.1 impl=0.14
item: milestone-review design=0.1 impl=0.14
item: milestone-review design=0.0 impl=0.14
design-buffer: 0.15
total: 6.93
```

*Produced via `brain/data/life/42shots/velocity/estimate-logic-v3.1.md` against
`baseline-v3.1.md`. Method A only.* `sdlc estimate-source` flags that doc as
stale (#127), so the per-primitive hours are provisional.

How each item was picked, from the v2 table's ranges: design ×0.2 where the
plan resolves the decisions (v2 Step 3 — the plan carries every contract and
strategy), `impl=` at 40% of the v2/v2.1 range (v3.1), design buffer 0.15
because the ×0.2 discount applies across the code primitives (v2.1 halves the
buffer then). Familiarity 1.0: the parser, both builders, the wires, the
movers/deleters and the exporter were read end to end during planning.

- `issue-spec` — the spec predates the claim, but inside the window are the
  durable plan, five fresh-eyes plan reviews over two rounds and four
  plan-quality rounds: the middle of 0.5–1.5, undiscounted.
- `lua-neovim` ×6, one per focused module or seam, impl in the scaled
  0.2–0.6 range by size: `assets` pure + checked IO (0.5); clipboard recipes +
  paste flow + key + fixture (0.6); parser + both builders + retention +
  budget + send guard + log elision (0.6); the three wire shapes (0.3); both
  movers + five deleters + sweep + prompts (0.5); export placeholder + copy
  (0.3).
- `real-api-discovery` ×3 — the M1 gate sends a real image through each wire
  family (anthropic, openai, googleai/cliproxy); 0.3–0.6 ×0.4.
- `atlas-docs` ×2 — the attachments doc at M1, the M2 lines and one-liners.
- `milestone-review` ×3 — M1, M2 and the close boundary (the estimate-quality
  judge caught the omitted M2 close; its design side is 0 because M2 has no
  design left, only the review).
- The live clipboard spec (Task 12) is inside the clipboard/paste item; the
  verification effort of each `lua-neovim` item (fakes, failure matrices,
  differential specs) is inside its impl hours — v3.1 impl hours are
  ship-wall-clock, tests included.

## Plan

Durable plan: `workshop/plans/000231-chat-image-attachments-plan.md` (contracts
and per-function test strategies; two review boundaries).

- [x] M1 — Decide the folder-name form: `assets/<chat-timestamp>/`, no slug
- [ ] M1 — `assets`: layout, grammar, budget, content, checked IO (Tasks 1–2)
- [ ] M1 — `clipboard_image`: recipes as data, one classify rule, seam (Task 3)
- [ ] M1 — `<M-v>`: fixture, paste flow, key in both buffer scopes (Task 4)
- [ ] M1 — parser: an image link in a question block is an attachment (Task 5)
- [ ] M1 — both builders: one retention rule, one budget, send guard, elided logs (Task 6)
- [ ] M1 — three wires, three shapes (Task 7)
- [ ] M1 — gate: atlas, traceability, full suite, manual paste + per-wire send (Task 8)
- [ ] M2 — both movers carry the folder; all five deleters remove it; prompts name it (Task 9)
- [ ] M2 — tree export copies the folder and renders `<img>` (Task 10)
- [ ] M2 — docs: memory, format, providers, export, keybindings, README (Task 11)
- [ ] M2 — live clipboard conformance (opt-in), close (Task 12)

## Log

### 2026-09-10

### 2026-09-12

- Claimed; `sdlc start-plan` run. Operator framing on claim: #231 is a fork
  in the road — the transcript stops being the whole chat state and gains a
  bytes-only sidecar folder. The model-side counterpart (generated images
  saved to the same folder via a client-side tool that returns the link) is
  **#239**, `deps: [000231]`; its precondition is this issue's writer
  (`images.save(chat, bytes, ext) → relative link`), so that writer must be
  caller-agnostic — not coupled to the clipboard or to the question block.
- Operator confirmed Plan step 1 and sharpened it: the sidecar is an **asset**
  folder, `assets/<chat-timestamp>/`, no slug — slugs are for humans, and humans
  reach assets through the transcript. Same folder serves #239. Ticked.
- Durable plan written: `workshop/plans/000231-chat-image-attachments-plan.md`
  (two milestones, four execution chunks). Two fresh-eyes review rounds
  (five reviewers) folded in; a third verification pass was cut off by the
  session rate limit and its two open checks were verified by hand. Findings
  that changed the design, worth remembering: (a) chat deletion has FIVE
  sites, not one — one `delete_chat_file` door + an arch sweep; (b) the
  send-time debug log and raw-mode logs would have written the base64 per
  turn — `elide_image_data` at all three sinks; (c) an early `<img>` in the
  HTML exporter is mangled by the italic rule — the file's placeholder
  mechanism instead; (d) the paste must check the buffer BEFORE saving, or a
  closed buffer orphans bytes. Wire shapes read live from the three
  providers' docs today (Anthropic `image`/base64, OpenAI `image_url` data
  URL, Gemini `inlineData`). Awaiting plan approval → `sdlc change-code`.
