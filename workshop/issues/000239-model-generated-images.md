---
id: 000239
status: open
deps: [000231]
github_issue:
created: 2026-09-12
updated: 2026-09-12
estimate_hours:
---

# Model-generated images: save to the chat images folder, link from the answer

## Problem

Operator request, 2026-09-12, while starting #231. #231 opens a fork in the
road: parley had been keeping the whole chat state inside the transcript, and
an image cannot reasonably be embedded in a markdown file, so #231 introduces a
per-chat sidecar folder for operator-pasted images. The same argument applies
to images the *model* produces. Today there is no path for one at all: a
model that can draw has nowhere to put the bytes, and a model that cannot draw
has no tool it could ask.

This is the other side of #231 — the transcript as index, the folder as the
bytes, one writer for both directions.

## Spec

### Two ways a model image arrives; native output is the one that matters

1. **Native image output — the deliverable.** Image-output models (Gemini
   image models return `inlineData` parts with a mime type and base64 bytes;
   OpenAI's image generation returns base64 output items; Anthropic has none)
   put the bytes **in the response stream**, interleaved with text. There is no
   tool call to hook: the model cannot hand megabytes of binary through
   tool-call arguments, and these models emit images as content parts. The
   sink is parley's response handler (`chat_respond.lua` + the per-wire stream
   decoder), which must recognise a non-text part, decode it, save it through
   #231's writer, and splice `![](images/<ts>/<file>.png)` into the streamed
   answer at that position. The operator's judgement (2026-09-12): this is the
   more valuable half — one model that reasons *and* draws in the same turn,
   with the picture landing in the transcript where it was said, beats a
   detour to a separate generation model.

2. **Tool-mediated generation — optional M2.** A client-side `generate_image`
   builtin that calls a configured image API, writes through the same writer,
   and returns the relative link as the `ToolResult`. It rides the existing
   tool loop with no wire change and gives drawing to models that cannot draw
   (Anthropic). Taken only if a text-only agent turns out to need it; it must
   not be the reason the native path ships late (`ARCH-PURPOSE`: the purpose
   is the picture in the answer, not a second provider integration).

Exact wire shapes — request flag and response part — are read from current
provider docs at implementation time (`shared/live-sources.md`), never
recalled. Gemini first: parley already has a googleai provider and Gemini is
the family where text and image output share one model.

### Request side: asking for images is a model capability, not a global flag

Gemini requires the request to declare image modality (a `generationConfig`
response-modalities field); a text model rejects it. So the flag hangs off
the **agent/model**, via the existing per-provider params path
(`provider_params.lua`), not off the wire globally. An agent that does not
declare it sends exactly today's payload — pinned by a spec, since a stray
field is a 400 on every text model.

### Stream side: a binary part in a text stream

The SSE decoder (`sse.lua` → provider chunk parsing) currently yields text
deltas. It must also yield an **image part** (`{mime, bytes}`) as a typed
value at the boundary (`ARCH-SECURE`: base64 from the network is untrusted;
decode, check the mime is one the writer accepts, bound the size, and degrade
visibly — a link to nothing is worse than a note saying the image was
dropped). Recognition and decoding are pure and unit-tested; only the save is
IO. A single image part may be large (an image can outweigh the whole
conversation — `ARCH-CONSTRAINTS`): it must not be re-rendered per keystroke
or copied per chunk; budget and bound behaviour go in the plan.

### One writer, shared with #231

#231 owns the folder (`<chat-root>/images/<chat-id>/`), the unique timestamp
filename, the relative-link form, and the ChatMove/tree-export carry. This
issue adds a second *caller* of that writer and must not grow a second
folder-naming or link-forming path (`ARCH-DRY`). Hence `deps: [000231]` —
the writer is #231's first deliverable and this issue's precondition.

### Answer-side images are attachments too, and follow the same window

The parser treats an image link in a question block as an attachment (#231).
An image link in an **answer** block is an attachment of the answer, same
concept, same lifetime: it follows `chat_memory` and drops with its exchange,
the summary noting an image was there. The reason it must be re-sent while
recent: **iterating on an image** ("now make the sky bluer") requires the
prior image in the model-role turn — Gemini accepts that, and it is the
headline use of an image-output model. Per wire:

- a wire that accepts images in the assistant role (Gemini) re-sends the
  attachment in that role's shape;
- a wire that does not (Anthropic, and OpenAI chat completions unless the
  docs say otherwise) sends the link text only — the model knows it drew
  something, and cannot see it.

This is one attachment concept for both blocks, differing only in which role
carries it — not two mechanisms (`ARCH-DRY`). The cost tradeoff is #231's,
already taken by the operator.

### The image API is a second external seam (M2 only)

`generate_image` hits an image endpoint under an existing provider key. It
is a seam needing a stateful fake (ARCH-MOCK) with the real failure modes:
no provider configured, API error, content refusal, oversized result. For
M1, the seam is the one parley already has — the provider stream — and the
existing fake SSE server gains a fixture that emits an image part.

## Done when

- An agent on a Gemini image-output model, asked to draw, streams text and an
  image; the image lands in the chat's images folder with a #231-form name
  and the answer contains a relative link **at the position the part
  arrived**, rendering in `:MarkdownPreview`.
- The fake SSE server serves a fixture with an interleaved image part; the
  spec asserts file bytes, filename form, link position, and no real network.
- An agent without the image modality sends today's exact payload (pinned).
- A malformed or oversized image part produces a visible note in the answer
  and a diagnosis, not a dangling link or a stack trace.
- The folder, filename, and link come from #231's writer — exactly one
  implementation, checked by an arch spec.
- A follow-up turn re-sends a recent answer image in the model role on
  Gemini, sends link text only on Anthropic, and drops it once the exchange
  is summarised — asserted per wire against a payload.
- `:ParleyChatMove` still carries generated images with the chat.
- (M2, only if taken) `generate_image` returns the relative link against a
  fake image provider; no provider configured → `is_error` naming the key.

## Plan

- [ ] Wait for #231's writer (`images.save(chat, bytes, ext) → relative link`)
      to land; confirm its signature is caller-agnostic
- [ ] Read current Gemini docs: request modality flag + streamed image part
      shape; record both in `## Log` with the doc URL and date
- [ ] Request: per-agent/model image modality via `provider_params`, with a
      pinned no-change spec for agents that do not declare it
- [ ] Stream: typed image part out of the chunk decoder (pure), bounded and
      validated; save through the writer; splice the link at position
- [ ] Fake SSE fixture with an interleaved image part; end-to-end spec
- [ ] Answer-side attachments: parser marks them; `build_messages` re-sends in
      the model role where the wire accepts it, link text elsewhere; memory
      window drops them with the exchange
- [ ] Atlas: `atlas/providers/googleai.md` + the images doc #231 creates
- [ ] (M2, optional) `generate_image` builtin behind an image-provider seam
      with a stateful fake; `atlas/providers/tool_use.md` tool table

## Revisions

### 2026-09-12 — native output first

- **Reason:** operator, on reading the first draft: "we probably should
  support this first, instead calling to separate image generation model. I
  think that's more valuable."
- **Delta:** M1 and M2 swapped — native image parts in the stream are the
  deliverable, `generate_image` is the optional second milestone. Added the
  request-side modality flag, the typed image part at the stream boundary,
  and reversed the "never re-sent" rule: answer images are attachments that
  follow the memory window and are re-sent in the model role on wires that
  accept it, because iterating on an image is the point of an image-output
  model.

## Log

### 2026-09-12

- Created from the operator's framing while claiming #231: "there's no
  reasonable way to embed images inside transcript, so we have a folder";
  model-generated images belong in the same folder, via a local tool call
  that stores and returns a name.
- Design note: the tool-call framing fits *tool-mediated generation* exactly
  and does not fit *native image output* (bytes arrive as stream parts, not
  tool args). Split accordingly; the tool is the deliverable.
- Revised the same day: native output first (see `## Revisions`). Open
  question for the plan: how cliproxy routes a Gemini image model and
  whether image parts survive its openai-compat translation — if they do
  not, the native googleai route is the one to use for these agents.
