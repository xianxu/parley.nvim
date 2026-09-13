---
id: 000244
status: working
deps: [000231]
github_issue:
created: 2026-09-13
updated: 2026-09-13
estimate_hours: 1.623
started: 2026-09-13T11:25:16-07:00
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

## Estimate

Produced via `brain/data/life/42shots/velocity/estimate-logic-v3.1.md`
against `baseline-v3.1.md`. Method A only; calibration currently flagged stale.
Derived after plan-quality round 2 passed. One focused Lua feature includes
policy, dimensions, IO, fixture and integration (base design 1.5h, impl 1.5h);
shared clipboard grammar is a cross-cutting refactor (0.4h / 0.4h); real-tool
conformance is discovery (0 / 0.45h); docs (0.1h / 0.1h) and one close review
(0.1h / 0.4h). Thorough-plan design discount 0.2, familiar-stack multiplier 1,
v3.1 implementation scale 0.4, design buffer 15%. Existing validators and
Neovim process IO are reused; no novel codec/library implementation.

```estimate
model: estimate-logic-v3.1
familiarity: 1.0
item: lua-neovim design=0.3 impl=0.6
item: cross-cutting-refactor design=0.08 impl=0.16
item: real-api-discovery design=0 impl=0.18
item: atlas-docs design=0.02 impl=0.04
item: milestone-review design=0.02 impl=0.16
design-buffer: 0.15
total: 1.623
```

## Plan

Test strategy: `dimensions` — table over the four fixtures + truncated
headers; policy (`should_shrink(size, dims, media_type)`) — decision table;
recipe `select`/`argv_for` — decision tables (same shape as
`clipboard_image`); the outcome contract — fixture-driven matrix through
`assets.save` (success / non-zero / empty / invalid → original kept,
notification named); live conformance opt-in.

- [x] `assets.dimensions` (pure) + the shrink policy (pure)
- [x] `image_shrink` module: recipes as data, `select`, `argv_for`, `run` seam
- [x] `assets.save` calls the shrink step; extension follows the output; notice carries sizes
- [x] Fixture `tests/fixtures/fake_sips` + the outcome matrix; live spec
- [x] Atlas (`atlas/chat/attachments.md`) + README: the commit-vs-ignore note
      for `workshop/parley/assets/` (write-once binaries; `.gitignore` is a
      per-repo choice; LFS is a later switch on the fixed path)

## Log

### 2026-09-13
Claimed; `sdlc start-plan` run. Durable plan: `workshop/plans/000244-shrink-images-on-save-plan.md`
(3 chunks, 8 tasks, TDD steps with code). Not yet through `sdlc change-code`
— the next agent should run it (plan-quality gate, then derive `estimate_hours`).

Measured on this host (macOS 26.6.2, sips-316) before designing:
- `sips --resampleHeightWidthMax 1600` UPSCALES an 800×500 PNG to 1600×1000 →
  the recipe carries a `{max}` token = min(1600, source long edge), computed
  from `assets.dimensions` (pure, from the headers `looks_like` already walks).
- Missing input, or a missing output directory → exit 0 and nothing written →
  "exit 0 + no output" is a kept-original outcome.
- Junk input → exit 13, `Error: Cannot extract image from file.`
- 2880×1800 PNG → 1600×1000 JPEG q80 in 90 ms → the step runs synchronously
  inside `assets.save`, bounded by a 5 s timeout (ARCH-CONSTRAINTS).
- Alpha is flattened; no ICC in the output. A high-entropy 393 KB PNG came
  back 360 KB → output must be strictly smaller or the original is kept.
- Under the agent sandbox sips cannot write its own scratch under
  `/var/folders/…/T` (exit 13): the live spec must run from a normal shell.

Spec refinements the plan proposes (operator confirms at change-code):
JPEG sources shrink only when over 1600 px (re-encoding for size alone is
generation loss); not-smaller output → keep silently; the 10 MB cap stays a
check on the source before the shrink.

Design (ARCH-DRY): a new `argv_recipe` module holds the token grammar and
config-wins selection that `clipboard_image` and `image_shrink` share;
`clipboard_image` delegates with its messages unchanged. ARCH-MOCK:
`tests/fixtures/fake_sips` (ok/fail/empty/garbage/slow + call log) through
`config.assets.shrink_cmd`; opt-in `PARLEY_LIVE_SHRINK=1` per recipe.
ARCH-ORDER: one tagged session field (`nil | {recipe} | {missing, warned}`),
reset by `configure` from `parley.setup`.

### 2026-09-13 — implementation resumed

Operator approved the plan and all three refinements. Today's project goal is
a usable installation under a separate Neovim app profile, with packaged
defaults based on the existing `~/.config/nvim` configuration.

Plan-quality round 1 requested a compact plan, decoder resource admission,
output-dimension validation, and consistent embedded `{max}` grammar. The
revised canonical plan addresses PQ-1 through PQ-4; the original design is
preserved as `workshop/plans/000244-shrink-images-on-save-design-record.md`.

### 2026-09-13 — implementation verification

All five tasks implemented. `make test` exits 0: 225 spec files passed;
luacheck reports 0 warnings/errors across 391 files. Focused asset suite 105
cases and paste integration 18 cases pass. Engine tests cover actual five-second
process timeout, OS-enforced output growth limit, cleanup faults, resource
admission, and metadata removal. Golden side quest has 7 regression guards.

`PARLEY_LIVE_SHRINK=1` passes for installed sips: 6,481,758-byte 1800×1200
PNG → 27,699-byte 1600×1066 JPEG in 54.1 ms; 400×300 stays 400×300 (no
upscale), 360,393 → 2,703 bytes in 17.0 ms. Independent sips probes confirm
dimensions and removal of a description sentinel that sips alone retained.
ImageMagick/convert/ffmpeg/libvips are absent and explicitly pending; the
conformance estimate covered sips on this host, not installing other codecs.

The metadata correction shares one JPEG record walk through all scans; tests
preserve escaped entropy bytes and restart markers and remove metadata even
between progressive scans. Initial metadata tests were red before the fix.
Operator's untracked chat work was snapshotted locally before boundary review.

## Revisions

### 2026-09-13T11:50:00-07:00 — approved refinements and gate corrections

Reason: operator approval and plan-quality findings. Delta: JPEG resize is
edge-driven only, non-smaller output keeps silently, source cap remains first.
Conversion is skipped above 32 million pixels or a 16384-pixel dimension;
the subprocess gets a file-size limit and output must meet its requested edge.
Paths remain whole-argument tokens; `{max}` may be embedded. The canonical
plan supersedes the original Spec where these refinements differ.

## Side quests

- Baseline golden-payload portability: all 11 cases failed before #244 code
  because ripgrep upgraded 15.1.0 → 15.2.0. Pinning only the version probe made
  all 11 pass. Shared comparison normalization now ignores that volatile
  version while preserving tool behavior text and payload content; 7 new
  guards and all 11 existing cases pass. No captured fixtures refreshed.

### 2026-09-13 — boundary review round 1 repairs

Reason: BR-1–BR-3 found truncated-output misclassification, hidden cleanup
failures, and an independent-probe gap on non-sips hosts. Delta: preserve
complete output within the 10 MiB bound through metadata stripping and size
comparison (ARCH-PURPOSE); attempt both removals and surface non-ENOENT
failures (ARCH-FUNERAL); independently probe every installed recipe with its
own tool or ffprobe/vipsheader companion (ARCH-MOCK). Regression tests cover
larger output, metadata-heavy output, failed/thrown cleanup, timeout context,
and probe dispatch without relying on sips.
