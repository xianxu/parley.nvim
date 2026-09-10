---
id: 000231
status: open
deps: []
github_issue:
created: 2026-09-10
updated: 2026-09-10
estimate_hours:
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
| storage | **`<chat-root>/images/<chat-basename>/`** — per chat, not flat |
| lifetime | **images follow `chat_memory`** — dropped when their exchange is summarized |

**`<M-i>` was the request and is not available**: it is `branch_ref`
(`{ "<M-i>", "<M-S-CR>", "<C-g>i" }`), the fork chord in constant use. Noted
alternative: the operator observes that `chat_prune` (`<M-p>`) is "almost never"
used, so `<M-p>` — a better mnemonic still — is a one-line swap if wanted, at
the cost of rebinding or unbinding prune. Recorded rather than taken, because
`<M-v>` is free and displacing a shipped binding is a separate decision.

### Storage, and why per-chat

`<chat-root>/images/<chat-basename>/2026-09-10.14-22-31.487.png`.

The flat `<chat-root>/images/` the request described is simpler to write and
breaks on the operations parley already has: `:ParleyChatMove` moves a chat tree
between roots and cannot know which flat images belong to it, and tree export
has the same problem. That is #224's failure shape — a reference that resolves
until someone moves the thing it names. A per-chat subfolder moves with its
chat and leaves no orphan when a chat is deleted.

**Consequence to design for:** the chat basename contains the slug, and slugs
change (#224). An images folder named after the basename is a second thing that
must be renamed when `ParleySlug` fires. Two candidate answers — name the folder
by the **timestamp prefix only** (stable, never renamed), or rename it alongside
the chat. The timestamp-prefix form is preferred for exactly the reason #224
established: the timestamp is the identity and the slug is decoration.

### Transcript representation

Ordinary markdown: `![](images/<ts>/2026-09-10.14-22-31.487.png)`, relative to
the chat file. This is not a cosmetic choice — it is what makes part 3 free,
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

## Plan

- [ ] Decide the folder-name form (timestamp prefix vs full basename) and
      record it — it determines whether ParleySlug has a second thing to rename
- [ ] Clipboard read behind a seam, with a fake: image present / text present /
      no binary / unsupported format
- [ ] Write + insert: unique name, per-chat folder, relative link at the cursor
- [ ] Parser: an image link in a question block is an attachment
- [ ] `build_messages`: emit per wire, shapes read from current provider docs
- [ ] Memory window: attachments drop with their summarized exchange, and the
      summary records that an image was present
- [ ] ChatMove + tree export carry the images folder
- [ ] Keybinding through the registry (`<M-v>`, `parley_buffer` scope), with the
      collision guard covering it

## Log

### 2026-09-10
