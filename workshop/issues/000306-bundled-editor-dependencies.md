---
id: 000306
status: working
deps: []
github_issue:
created: 2026-09-30
updated: 2026-09-30
estimate_hours: 3.74
card_mirror: 'a282e27b4c801742d6a2dcbf203285b592141ac5' # card fields mirrored from issue-cards; edit via sdlc
started: 2026-09-30T10:27:48-07:00
flow: {kind: full, provenance: operator}
---

# Bundle tested editor dependencies for offline app startup

## Problem

The Homebrew app installs its editor dependencies on first launch through Lazy and a Markdown Preview download hook. Startup depends on GitHub availability, and reused local plugin caches can differ from declared pins. The operator wants a locally tested dependency set bundled with the app.

## Spec

One version-controlled manifest owns all shipped editor plugin identities, immutable commits, source archive checksums, and platform-specific Markdown Preview binary identities/checksums. Both `./parley_app` and Homebrew consume it. Homebrew installs these dependencies beneath its application directory; the packaged starter loads them as local Lazy specs, including Lazy itself, without cloning, fetching, or building on first launch. App-owned plugin updates travel with app upgrades. Personal plugins remain separately managed.

Local app startup verifies its managed dependency set against the same manifest after provisioning and before normal UI startup; existing mismatched caches fail with an actionable repair instruction rather than silently testing other versions. Release validation uses a fresh, locally assembled bundle from that manifest and exercises the production starter. Checksummed archives and binary payloads, not merely an editable lockfile, establish bundle identity. Editor launch, themes, completion, and local Markdown Preview must work without external networking once installed. AI calls, authentication, optional personal plugins and initial Homebrew downloads are outside that offline guarantee.

Preserve user configuration and chats. Existing copied starter files retain the current `.new` upgrade contract and need to adopt the new starter before gaining offline behavior. Source-only standalone startup retains a provisioned development fallback. Do not publish a release or tap changes as part of implementing this ticket.

## Done when

- Homebrew stages all shipped editor dependencies and the correct Markdown Preview executable from immutable checksummed inputs; no dependency install runs at first app launch.
- `./parley_app`, theme metadata, starter specs, formula projection and release checks derive dependency versions from the shared manifest.
- Fresh and reused local profiles verify dependency identity; wrong commits, modified tracked files, wrong binary bytes and incomplete bundles fail before claiming parity.
- Production startup with an empty user profile and blocked external networking supports themes, completion and a loopback Markdown Preview request, and leaves the installed bundle unchanged.
- Upgrade/config preservation and existing packaging tests pass; documentation states the guarantee and the old-profile migration requirement.

## Plan

- [x] Implement the shared dependency manifest, bundle assembly and production startup integration with regression coverage.
- [x] Verify real dependency parity and offline app behavior, update packaging documentation, then close through SDLC review.

## Estimate

Produced via `brain/data/life/42shots/velocity/estimate-logic-v3.1.md` against `baseline-v3.1.md`. Method A only; calibration flagged stale by SDLC. Primitives cover issue design, pure manifest, artifact integration, starter integration, consumer refactor, upstream conformance, docs and boundary review. Python stdlib covers archives, hashing and locking (library discount for the pure manifest/provisioning design); use thorough-spec design discount ×0.2, familiar stack ×1.0, v3.1 implementation scale ×0.4 and +15% design buffer. Base implementation picks are 0.2/0.8/1.5/1.5/0.5/0.45/0.2/0.5 hours respectively.

```estimate
model: estimate-logic-v3.1
familiarity: 1.0
item: issue-spec design=0.2 impl=0.08
item: greenfield-go-module design=0.125 impl=0.32
item: api-integration design=0.4 impl=0.6
item: lua-neovim design=0.4 impl=0.6
item: cross-cutting-refactor design=0.12 impl=0.2
item: real-api-discovery design=0 impl=0.18
item: atlas-docs design=0.02 impl=0.08
item: milestone-review design=0.02 impl=0.2
design-buffer: 0.15
total: 3.74
```

## Log

### 2026-09-30

Created and claimed from the operator's approved packaging direction. `sdlc start-plan` prepared the issue branch from published main, preserving local unpublished demo work. Current downloads include lazy.nvim bootstrap, the starter/theme plugin set and Markdown Preview's platform executable. Plan: `workshop/plans/000306-bundled-editor-dependencies-plan.md`.

Implementation gate passed after PQ-1/PQ-2 were resolved; estimate-quality INFO noted optimistic integration/harness allocation. The integration primitive includes archive verification, locks, recovery and their tests; the Lua integration primitive includes the production offline runner. Native descriptor inheritance was proved with Neovim 0.11.7 and a terminated launcher. Manifest/theme tests pass (6+7), assembler tests pass (15), launcher tests pass (13), formula/release tests pass (3+9), and starter bootstrap passes (16) after a red bundled-startup regression.

Real offline startup exposed Neovim 0.11's full-path bytecode-cache filename limit under long bundle paths. Bundled startup now disables that optional loader cache; standalone behavior is retained. Production starter cold/warm checks now pass themes, real buffer/Blink spelling and a loopback Preview HTTP request under external-network denial. The Preview probe must yield the editor event loop while HTTP is served because the server requests buffer state over RPC. Actual installed/local launcher conformance is being verified next; no release published.

Mapped suites now pass: infra/starter 195, ui/themes 122, infra/packaging 86; local launcher 13 and assembler 15 pass. The assembler suite and a real ARM bundle verification also pass under macOS Python 3.9.6. Full lint: zero warnings/errors in 686 files; changed smoke Lua and shell syntax checked separately. Upgrade regression inspects both synthetic release archives and proves the installed top-level bundle is excluded while the original payload and nested names remain intact.

Actual installed cold/warm and local-app launchers passed enforced external-network denial with full payload inventories unchanged. Whole smoke elapsed times (including themes/completion/Preview HTTP, not startup-only latency): 1.48s cold, 0.94s warm, 1.72s local. Native Apple Silicon executed Preview v0.0.10; Intel macOS/Linux archives, binary formats/checksums and formula selections were verified but their binaries were not executed here. ARM app inputs total 23,048,113 compressed bytes (11 source archives plus Preview). No actual Homebrew bottle installation or release publication is claimed.

Final enforced offline runner also passed the actual recording launcher with Screenkey active and the workspace confined to its temporary checkout. Full inventories were unchanged across all four runs; latest whole-smoke elapsed times were 1.61s cold, 0.98s warm, 1.88s local, 2.06s recording. Cached archives were supplied before network denial. Homebrew staging API compatibility was inspected against installed Brew source; both resource-stage directory behavior and named Preview installation match the actual tar layouts. Ready for the mandatory close review.

## Revisions

- 2026-09-30: Local launch now always selects the archive bundle, never an old Lazy Git cache. Full manifest/file/mode verification covers wrong source or binary payloads, missing files and unexpected files; the proposed separate HEAD/tracked-dirt check is superseded because legacy Git caches are not loaded or modified (ARCH-DRY).
