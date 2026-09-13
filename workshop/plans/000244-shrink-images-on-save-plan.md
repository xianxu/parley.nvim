# Shrink images before saving (#244) Implementation Plan

> **For agentic workers:** Follow AGENTS.md §3. Use TDD for each task; the SDLC close owns the fresh-context boundary review.

**Goal:** Shrink eligible pasted and generated images through `assets.save`, retaining originals when conversion is unavailable, unsafe to attempt, ineffective, or invalid.

**Architecture:** Shared argv grammar; pure image policy and postcondition validation; one bounded external-tool seam; shared asset writer owns transformation. The paste notice reports the outcome.

**Tech stack:** Lua, Neovim `vim.system`, plenary, stateful Python fixture, platform image tools.

## Approved decisions and measured facts

Operator approved the original plan and its three refinements on 2026-09-13: JPEGs resize only above 1600 px, non-smaller output is silently retained, and the existing 10 MiB source cap precedes conversion. The original design is preserved in `000244-shrink-images-on-save-design-record.md`; this compact plan supersedes its implementation transcript.

Measured on macOS: sips upscales to its requested edge; missing input/output directory can exit zero without output; a 2880×1800 PNG converted in 90 ms; alpha is flattened. Therefore compute `min(1600, source long edge)`, validate actual output, and document transparency loss. Existing PNG/JPEG validators already parse dimensions; extend their return values rather than adding parsers.

## Core concepts

### Pure entities

| Name | Lives in | Status |
|------|----------|--------|
| `substitute`, `has_token`, `select` | `lua/parley/argv_recipe.lua` | new |
| `dimensions`, `human_size` | `lua/parley/assets.lua` | new |
| `strip_jpeg_metadata` | `lua/parley/assets.lua` | new |
| `jpeg_scan_end` | `lua/parley/assets.lua` | new |
| `png_ihdr`, `is_png`, `jpeg_sof`, `is_jpeg` | `lua/parley/assets.lua` | modified |
| `RECIPES`, `decide`, `argv_for`, `classify`, `outcome_suffix` | `lua/parley/image_shrink.lua` | new |
| `select`, `argv_for` | `lua/parley/clipboard_image.lua` | modified |
| `png_bytes` | `tests/helpers/png_gen.lua` | new |
| `normalize_payload` | `scripts/golden_fixture.lua` | new |

The argv helper serves clipboard and shrink recipes (ARCH-DRY). Path tokens are whole arguments. Numeric `{max}` may be embedded; validate and substitute that same grammar, including configured commands. Paths containing literal tokens remain unchanged. Clipboard messages and platform ordering stay compatible.

`dimensions(media_type, bytes)` returns PNG/JPEG width and height only after the existing whole-format structural validator succeeds; unsupported/malformed inputs return nil. `looks_like` retains its boolean contract.

`decide(size, width, height, media_type)` returns target edge or nil, with an optional reason for unsafe input. PNG eligibility is >300 KiB or >1600 px; JPEG eligibility is >1600 px. GIF/WebP are untouched. No upscaling. Before selecting/spawning any tool, reject conversion when either dimension exceeds 16384 or pixels exceed 32 million, retaining the original with a diagnostic. These conservative initial workload limits cover Retina desktop screenshots while refusing decompression amplification from huge declared dimensions.

`classify(code, stderr, output, input_size, tool, requested_edge)` accepts only exit zero, structurally valid JPEG, dimensions no larger than the requested edge, and strictly fewer bytes. Failure/timeout/missing/invalid/oversized-dimension output keeps the original with a tool-named note; non-smaller output keeps silently. `outcome_suffix` formats sizes or the retained-original note.

### Integration points

| Name | Lives in | Status | Wraps |
|------|----------|--------|-------|
| `run`, `default_deps` | `lua/parley/image_shrink.lua` | new | temp files, bounded subprocess |
| `resolve`, `configure`, `shrink` | `lua/parley/image_shrink.lua` | new | session recipe state |
| `save` | `lua/parley/assets.lua` | modified | shrink dependency then one asset write |
| `paste` | `lua/parley/paste_image.lua` | modified | outcome notification |
| `setup` | `lua/parley/init.lua` | modified | reset shrink configuration |

`assets.default_io.shrink` calls the shrink module lazily to avoid a require cycle. Injected asset IO may omit shrinking. `save` returns a fourth value for the outcome; paths/extensions describe the bytes actually saved. `config.assets.shrink=false` disables all probes and work; `shrink_cmd` replaces recipe selection. Priority: sips, magick, convert, ffmpeg, vipsthumbnail.

## Operating envelope and ownership

- **ARCH-CONSTRAINTS / ARCH-SECURE:** User paste response path, typical target <200 ms from measured 90 ms, hard subprocess timeout 5 seconds. Source <=10 MiB; decode admission <=32 MP and <=16384 on either axis. Estimated ordinary decoder memory <=256 MiB at 8 bytes/pixel, with a 512 MiB planning allowance for codec overhead; this is a workload budget, not a claim of OS-enforced RSS containment. Installed binaries and configured commands are trusted executable code. No portable RSS sandbox is added.
- Bound subprocess file growth, rather than just reads: launch each recipe through constant `sh -c` text that sets `ulimit -f 10240` then `exec "$@"`. Arguments remain argv. POSIX 512-byte and common 1024-byte limit units both cap an individual output file at <=10 MiB. Failure to establish the limit fails the attempt. One input + one output <=20 MiB; output reads are capped at input size, stdout discarded. Tool internals may allocate private scratch; pixel admission and timeout bound expected work, not arbitrary writes by a malicious installed binary.
- **ARCH-PURE / ARCH-MOCK:** Policy/classification are pure. `run` receives file/exec dependencies; a filesystem-backed `tests/fixtures/fake_sips` runs through the same configured argv seam as real tools. Persist mode and call log; cover output and failure behavior plus timeout/file-limit enforcement. Conformance runs opt-in with `PARLEY_LIVE_SHRINK=1` on each available real recipe.
- **ARCH-ORDER:** One session resolution is unprobed, found(recipe), or missing(already warned). `configure` resets it; policy bypass leaves it untouched. Synchronous subprocess wait serializes conversion on Neovim's main loop; callers retain their existing paste ownership checks.
- **ARCH-FUNERAL:** Two unique temp paths per run; cleanup on successful, failed, throwing, and timed-out attempts. Abnormal process death leaves OS-owned temporary files. Saved asset lifetime stays owned by the chat.
- **ARCH-PURPOSE:** Every writer benefits through `assets.save`; acceptance validates the promised transformation, not merely command success.

## Plan

Each task uses red-green-refactor and a focused verification before commit. These are tasks, not separate milestone boundaries; one issue-close review.

- [x] Shared recipe grammar: `lua/parley/argv_recipe.lua`, delegation in `clipboard_image.lua`, unit specs. Test strategies: `substitute`/`argv_for` preserve arbitrary token-containing paths and input immutability; `select` uses decision tables over config grammar and executable order, retaining clipboard contract tests.
- [x] Dimensions and byte formatting: `assets.lua`, `tests/unit/assets_spec.lua`, `tests/helpers/png_gen.lua`. Test strategies: `dimensions` uses differential agreement with existing validator over valid images and malformed/truncated byte mutations; generator produces real CRC/zlib bytes for live decoding; `human_size` exercises unit/rounding boundaries.
- [x] Shrink policy and IO: `image_shrink.lua`, `tests/unit/image_shrink_spec.lua`, `tests/fixtures/fake_sips`. Test strategies: `decide` exercises policy and resource boundaries including small compressed inputs declaring enormous dimensions; `classify` verifies each postcondition independently using valid JPEGs that violate the requested edge; `resolve` checks transitions and reset; `run` uses a stateful file model for cleanup/fault injection plus executable fake for actual timeout and file-size limit behavior.
- [x] Wire save, setup, and paste: `assets.lua`, `init.lua`, `config.lua`, `paste_image.lua`, asset unit specs and `tests/integration/paste_image_spec.lua`. Test strategies: `save` proves source cap precedes work and resulting extension matches bytes; paste exercises end-to-end success/fallback/no-tool-once/disabled behavior through the configured fake and verifies user notice and persisted files.
- [x] Live conformance and documentation: `tests/integration/image_shrink_live_spec.lua`, `atlas/chat/attachments.md`, `atlas/traceability.yaml`, `README.md`. Test strategy: real available tools decode generated images, assert smaller valid JPEG and target dimensions, and no upscaling. Document alpha loss, limits, opt-outs, and per-repo commit-versus-ignore choice. Run focused specs, `make test` (includes lint), and opt-in live conformance; log evidence before `sdlc close`.

Focused command: `nvim -n --headless --noplugin -u tests/minimal_init.vim -c "PlenaryBustedFile <spec>" -c "qa!"`, using isolated HOME/XDG/TMPDIR and `NVIM_TEST_PLENARY` as documented in TOOLING.md.

## Non-goals

No historical asset migration, alpha preservation, new image codec library, package-manager execution, dependency registry (#245), generated-image producer (#239), or async UI redesign. The shared save seam supports the later producer.

## Revisions

### 2026-09-13T11:50:00-07:00 — plan gate round 1

Reason: PQ-1 through PQ-4 identified plan duplication, incomplete resource admission, missing output-dimension validation, and inconsistent numeric-token grammar. Delta: preserve the original artifact as a design record, replace executable-plan detail with contracts and test strategies; add 32 MP/16384 admission, subprocess file limit and explicit memory assumptions; validate output against requested edge; accept embedded numeric tokens while keeping paths whole. Operator's approved feature scope is unchanged.

### 2026-09-13 — baseline verification side quest

Reason: the pre-implementation full suite failed all 11 golden payload cases
solely because this machine upgraded ripgrep from 15.1.0 to 15.2.0. Delta:
`normalize_payload` deep-copies comparison inputs and normalizes only ripgrep
version tokens in the two search-tool descriptions, on both provider envelopes.
Its unit tests assert immutability and preservation of substantive descriptions,
schemas and messages. No production description or captured fixture is changed.

### 2026-09-13 — measured metadata preservation

Reason: a real `sips` probe retained a description sentinel through JPEG
conversion, contradicting the original metadata-stripping requirement.
Delta: reuse the JPEG record walk to strip metadata APP/COM records from
converter output before accepting it, preserving image coding and JFIF/Adobe
interpretation records. `strip_jpeg_metadata` is pure; its adversarial strategy
inserts metadata records into valid fixture bytes, checks removal without
changing dimensions/coding bytes, and rejects malformed/truncated records.
Engine tests verify the shared save result contains stripped bytes and reports
their final size. This fulfills the original requirement across tool recipes.
