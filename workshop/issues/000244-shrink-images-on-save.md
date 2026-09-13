---
id: 000244
status: open
deps: [000231]
github_issue:
created: 2026-09-13
updated: 2026-09-13
estimate_hours:
---

# Shrink pasted and generated images before saving: sips first, probe other tools, keep the original when none

## Problem

Operator, 2026-09-13, after #231 landed. A macOS screenshot is a 2–6 MB
Retina PNG. Pasted assets are write-once, so git stores each exactly once —
the cost is size, not churn — but a hundred screenshots a month at that size
is hundreds of MB a year in `workshop/parley/assets/`, and every re-send of a
retained image spends tokens on pixels the providers downscale anyway
(Anthropic resizes above ~1568 px on the long edge). Neovim has no image
codec and no CLI exists by default on both macOS and Linux, so this is a
per-platform recipe, like the clipboard read.

## Spec

- **Where:** the shared writer `assets.save` (so #239's generated images get
  it too), not the clipboard path. A new pure module owns the recipes and the
  policy; `save` calls it before writing.
- **Policy (tool-independent):** shrink only when it pays — the source is
  over 300 KB or over 1600 px on the long edge; otherwise keep the bytes
  untouched. Output JPEG, quality ~80, long edge capped at 1600 px, metadata
  stripped. The link's extension follows the output; the validator already
  accepts both. Never shrink a GIF/WebP source (animation/alpha); keep it.
- **Recipes as data, first executable wins, probed once per session:**
  1. `sips` (macOS, built in): `sips -s format jpeg -s formatOptions 80
     --resampleHeightWidthMax 1600 {in} --out {out}` — the operator's platform,
     zero installs.
  2. `magick` / `convert` (ImageMagick 7/6).
  3. `ffmpeg`.
  4. `vipsthumbnail`.
  5. **None found → keep the original bytes**, warn once per session naming
     what to install, and let the existing `MAX_BYTES` cap refuse anything
     over the limit. The feature never blocks on the tool.
  Each recipe is an argv with `{in}`/`{out}` tokens (whole-argument
  substitution, no shell string), the same seam and contract as
  `clipboard_image.RECIPES`; `config.assets.shrink_cmd` overrides it, and
  `config.assets.shrink = false` disables shrinking.
- **Outcome contract:** a recipe that exits non-zero, writes nothing, or
  writes bytes that fail `assets.looks_like` → keep the original and notify
  (the operator sees which tool misbehaved); the shrunk file replaces the
  original only after validation. Sizes before/after go in the paste notice
  (`pasted … (4.1 MB → 180 KB)`).
- **ARCH-MOCK:** a stateful fixture standing in for `sips` behind the same
  argv seam (success / non-zero / empty output / invalid output states);
  opt-in live conformance per real recipe on hosts that have the tool
  (`PARLEY_LIVE_SHRINK=1`), asserting dimensions via the tool's own probe
  (`sips -g pixelWidth`) and `looks_like`.
- Read the dimensions without a tool: PNG IHDR / JPEG SOF already parsed by
  `assets.looks_like`'s walkers — expose `assets.dimensions(bytes)` (pure)
  so the "over 1600 px" half of the policy needs no external call.

## Done when

- A 4 MB Retina PNG pasted with `<M-v>` lands as a JPEG under ~300 KB with
  the long edge ≤ 1600 px, the link's extension is `.jpg`, and the notice
  names both sizes.
- A 120 KB PNG is stored byte-identical (no tool run — asserted through the
  fixture's call log).
- With no recipe executable, the original is stored, one warning names what
  to install, and a second paste does not warn again.
- A recipe that returns garbage keeps the original and notifies.
- `assets.dimensions` reads PNG and JPEG dimensions purely; GIF/WebP sources
  are never shrunk.
- `PARLEY_LIVE_SHRINK=1` passes on this machine via `sips`.

## Plan

Test strategy: `dimensions` — table over the four fixtures + truncated
headers; policy (`should_shrink(size, dims, media_type)`) — decision table;
recipe `select`/`argv_for` — decision tables (same shape as
`clipboard_image`); the outcome contract — fixture-driven matrix through
`assets.save` (success / non-zero / empty / invalid → original kept,
notification named); live conformance opt-in.

- [ ] `assets.dimensions` (pure) + the shrink policy (pure)
- [ ] `image_shrink` module: recipes as data, `select`, `argv_for`, `run` seam
- [ ] `assets.save` calls the shrink step; extension follows the output; notice carries sizes
- [ ] Fixture `tests/fixtures/fake_sips` + the outcome matrix; live spec
- [ ] Atlas (`atlas/chat/attachments.md`) + README: the commit-vs-ignore note
      for `workshop/parley/assets/` (write-once binaries; `.gitignore` is a
      per-repo choice; LFS is a later switch on the fixed path)

## Log

### 2026-09-13
