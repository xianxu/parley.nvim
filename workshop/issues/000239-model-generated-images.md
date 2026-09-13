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

### Two ways a model image arrives, and only one of them is a tool call

1. **Tool-mediated generation.** A client-side `generate_image` tool in
   parley's registry (`lua/parley/tools/builtin/`). The model calls it with a
   prompt (and optionally size/aspect); the handler calls a configured image
   API, writes the result into the chat's images folder through #231's writer,
   and returns the **relative markdown link** as the `ToolResult` content. The
   model then references it in its answer as `![](images/<ts>/<file>.png)`.
   This is the "local tool call to store, return a name" shape from the
   request, and it works with **every** text model — including Anthropic,
   which cannot emit images itself. It rides the existing tool loop
   (`tool_loop.lua`, `tools/dispatcher.lua`, per-wire tool protocols) with no
   protocol change: the call is JSON in, a path string out.

2. **Native image output.** Image-output models (Gemini image models return
   `inlineData` parts; OpenAI's Responses API returns image-generation call
   outputs as base64; Anthropic has none) put the bytes **in the response
   stream**. There is no tool call to hook: the model cannot hand megabytes of
   binary through tool-call arguments, and these models emit images as content
   parts, not as tool inputs. The sink is parley's response handler
   (`chat_respond.lua` + the per-wire stream decoder), which must recognise a
   non-text part, save it through the same writer, and splice a markdown link
   into the streamed answer at that position.

Shape 1 is cheap and universal; shape 2 is per-wire and depends on which
providers are routed. **Shape 1 is the deliverable; shape 2 is a second
milestone taken only if a native-image route is actually in use.** Exact
wire shapes are read from current provider docs at implementation time
(`shared/live-sources.md`), never recalled.

### One writer, shared with #231

#231 owns the folder (`<chat-root>/images/<chat-id>/`), the unique timestamp
filename, the relative-link form, and the ChatMove/tree-export carry. This
issue adds a second *caller* of that writer and must not grow a second
folder-naming or link-forming path (`ARCH-DRY`). Hence `deps: [000231]` —
the writer is #231's first deliverable and this issue's precondition.

### Answer-side images are not attachments and are not re-sent

- The parser treats an image link in a **question** block as an attachment
  (#231). An image link in an **answer** block is prose. No parser change.
- Nothing re-sends an answer image on later turns. Anthropic assistant turns
  cannot carry image blocks at all, and there is no reason to pay per-request
  for bytes the model produced itself; the link text it wrote is what goes
  back, and that is enough for it to know what it drew. If the operator wants
  the model to *see* a generated image again, that is #231's question-side
  path (paste it, or a later "reference by link" refinement — out of scope).
- The tool result in the transcript's tool fold is a path string, serialized
  by the existing `tools/serialize.lua`, so the record of "this image was
  generated from this prompt" is ordinary transcript.

### The image API is a second external seam

`generate_image` shells nothing but does hit the network: an image endpoint
under an existing provider key (Google or OpenAI image models; the provider
and model are agent/config-selected, not hardcoded). It is a seam that needs a
stateful fake (ARCH-MOCK): tests assert the tool writes the file and returns
the link against a fake that serves fixed bytes, and the failure modes are
real (no image provider configured, API error, content refusal, oversized
result). A missing configuration produces a diagnosis naming what to set, not
a stack trace.

## Done when

- A tool-enabled agent asked to draw something calls `generate_image`; a file
  lands in the chat's images folder with a #231-form name and the answer
  contains a relative link that renders in `:MarkdownPreview`.
- The tool's `ToolResult` is the relative link, asserted against a fake image
  provider serving fixed bytes; no real network in tests.
- The folder, filename, and link are produced by #231's writer — there is
  exactly one implementation of each, checked by the existing table↔code guard
  or an arch spec.
- A later turn's payload contains the answer's link text and **no** image
  block for it, on every wire.
- No image provider configured → the tool returns an `is_error` result naming
  the config key, and the model can relay that.
- `:ParleyChatMove` still carries generated images with the chat (inherited
  from #231's carry; asserted once more here because the caller differs).
- (M2, only if taken) A Gemini image-output response saves its `inlineData`
  part and splices a link at that position in the streamed answer.

## Plan

- [ ] Wait for #231's writer (`images.save(chat, bytes, ext) → relative link`)
      to land; confirm its signature is caller-agnostic
- [ ] `generate_image` builtin: schema (prompt, optional size/aspect), handler
      behind an image-provider seam with a stateful fake
- [ ] Provider selection for the image model (config/agent field; reuse
      existing keys), with a named-config diagnosis when absent
- [ ] Answer-side: assert no re-send on every wire; assert answer links are
      prose to the parser
- [ ] Atlas: `atlas/providers/tool_use.md` tool table + a line in the images
      doc #231 creates
- [ ] (M2, optional) native image parts in the stream decoder, Gemini first

## Log

### 2026-09-12

- Created from the operator's framing while claiming #231: "there's no
  reasonable way to embed images inside transcript, so we have a folder";
  model-generated images belong in the same folder, via a local tool call
  that stores and returns a name.
- Design note: the tool-call framing fits *tool-mediated generation* exactly
  and does not fit *native image output* (bytes arrive as stream parts, not
  tool args). Split accordingly; the tool is the deliverable.
