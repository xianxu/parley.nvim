# Bundled editor dependencies implementation plan

> **For agentic workers:** use superpowers-subagent-driven-development or superpowers-executing-plans; track completed steps here.

**Goal:** Ship the same pinned editor dependency set tested by `./parley_app`, with no first-launch dependency downloads in the Homebrew app.

**Architecture:** A pure dependency manifest drives plugin specs, verified local provisioning and Homebrew resources. A thin filesystem/process boundary assembles and verifies immutable bundles. The starter selects a supplied bundle or verified development cache, then uses Lazy only for configuration/loading of shipped plugins. Bundled directories are treated as immutable; mutable caches remain in user storage.

**Stack:** Lua/Neovim, lazy.nvim, Python standard library for artifact tooling, generated Homebrew Ruby resources, existing shell release runner.

## Concepts and integration points

| Pure entity | Path | Status |
|---|---|---|
| Editor dependency manifest and spec projection | `lua/parley/editor_dependencies.lua` | new |
| Theme choices referring to manifest plugin IDs | `lua/parley/theme.lua` | modified |
| Homebrew resource projection | `packaging/formula.lua` | modified |

Manifest records: stable name, repository, full commit, immutable archive URL and SHA-256; artifact records add OS/architecture, binary version, archive member, archive SHA-256 and extracted binary SHA-256. Preserve licenses in staged trees. Lazy is a manifest entry, not an independent bootstrap pin. Theme records reference IDs; no copied version fields. Shipped plugin inventory must be closed over required transitive dependencies. The audited app set contains 11 repositories; the recording profile adds manifest-declared Screenkey as a separate membership. Both use the same assembler. Optional recording-only extras do not silently become release dependencies.

| Integration | Path | Status | Wraps |
|---|---|---|---|
| Artifact assembly and verification | `scripts/editor-dependencies.py` | new | subprocess, HTTP, archives, filesystem |
| Runtime dependency selection/verification | `lua/parley/editor_bundle.lua` | new | filesystem, Git identity, binary identity |
| Starter and local launch | `packaging/starter-config/init.lua`, `parley_app` | modified | Lazy lifecycle and editor startup |
| Installed launch and release projection | `packaging/formula.lua`, `scripts/release-parley.sh` | modified | Homebrew resources and immutable release archive |
| Offline conformance runner | `scripts/check-editor-bundle.sh`, `tests/packaging/editor_bundle.lua` | new | real Neovim, local HTTP preview |

Use a local HTTP archive server and real fixture Git repositories as the stateful artifact double: bytes, request log, missing/corrupt responses, staged trees and published bundle directories persist across calls. No call-count-only download mocks. Real pinned upstream archives provide conformance evidence independently of fixtures (ARCH-MOCK).

## Operating envelope and lifecycle

- Network occurs only during explicit provisioning/build. Download calls have bounded timeout and size limits (initial proposal: 120 seconds and 100 MiB per artifact; validate against measured real sizes). No retries or downloads during bundled startup; missing/incompatible dependencies give a repair error (ARCH-CONSTRAINTS).
- Verify archive hashes before extracting; reject traversal, absolute paths and escaping links. Extract into an owned temporary directory and publish only a complete verified bundle. Never execute a downloaded install script to determine a binary version (ARCH-SECURE).
- Bundle receipt records manifest identity and artifact payload identities. Runtime validates structure/manifest identity; exhaustive payload hashing is done at assembly and release verification. Local Git caches verify exact HEAD and tracked dirt, with binary hashing where relevant; document the trust boundary rather than treating a receipt alone as proof.
- Installed bundles live as long as their Homebrew keg and are removed by normal uninstall/cleanup. One active development bundle plus owned temporary staging; interrupted staging is removed on failure/retry. Do not accumulate a new bundle on each launch (ARCH-RETENTION).
- Measure cold and warm startup locally and record results; optimize only verified bottlenecks. Startup verification must not trigger network or write into the keg. Architecture-specific binary tests cover both formula projections; execute the current host binary and report the other architecture as unexecuted unless a matching runner exists.
- Reuse `theme`, existing formula renderer and launcher config-preservation semantics (ARCH-DRY). Keep identity/projection pure and IO in the boundary (ARCH-PURE). Include all shipped plugins, Preview, local launch parity and old-profile migration in the delivery (ARCH-PURPOSE).

## Chunk 1: Manifest and consumers

### Task 1: Establish authoritative dependency records

Files: new `lua/parley/editor_dependencies.lua`, `tests/unit/editor_dependencies_spec.lua`; modify `lua/parley/theme.lua`, `packaging/starter-config/init.lua`, `tests/packaging/bootstrap_lazy.lua`, theme tests.

- [ ] Inventory the starter/theme dependency closure and current locally installed versions. Record source/binary checksums from actual immutable archives; preserve current tested pins unless an incompatibility is demonstrated.
- [ ] Red: unit tests reject duplicate names, non-full commit pins, unsafe paths/URLs, absent hashes and unsupported artifact platforms. Test defensive copies and stable sorted projection. Test every theme's plugin reference resolves.
- [ ] Green: expose deterministic manifest APIs (`plugins()`, `plugin(id)`, `artifact(platform)`, manifest identity serialization); no download or `vim.system` in this module. Move pins from theme/starter into it.
- [ ] Update starter/bootstrap fixtures to derive the authoritative set, while retaining explicit behavioral expectations for required features. Test additions cannot silently bypass manifest coverage.
- [ ] Run `make test-spec SPEC=infra/starter` plus focused theme/manifest tests, then commit the coherent manifest change.

### Task 2: Verified artifact assembly and local parity

Files: new `scripts/editor-dependencies.py`, `lua/parley/editor_bundle.lua`, `tests/packaging/test_editor_dependencies.py`, `tests/integration/editor_bundle_spec.lua`; modify `parley_app`.

- [ ] Red: serve fixture archives locally and assert rejection of wrong digest, truncated content, traversal/escaping links, incomplete manifest, wrong cached Git HEAD, tracked modifications and binary digest mismatch. Test failed staging cannot replace a good bundle and a retry succeeds.
- [ ] Green: consume the manifest exported by Neovim with `--headless -u NONE`, assemble a local bundle using exact source archives and platform artifact, and emit a deterministic receipt after full validation. Provision missing development dependencies explicitly, then verify before launch. Existing mismatches fail with a command that repairs only app-owned dependencies; never reset arbitrary user checkouts.
- [ ] Use argument arrays for subprocesses. Keep downloaded source metadata/licensing. Validate all paths before writes, keep staging outside the final bundle, clean only directories created by this operation.
- [ ] Verify reused plugin caches and archive bundles using their respective provenance, without requiring `.git` inside Homebrew resources. Export a machine-readable parity report for conformance tests.
- [ ] Run `python3 -m unittest discover -s tests/packaging -p 'test_editor_dependencies.py'` and focused bundle integration tests, then commit.

## Chunk 2: Packaging and offline execution

### Task 3: Package dependencies as Homebrew resources

Files: `packaging/formula.lua`, `packaging/render-formula.lua`, `scripts/release-parley.sh`, `tests/unit/packaging_formula_spec.lua`, `tests/integration/packaging_release_spec.lua`.

- [ ] Red: rendered formula contains exactly manifest resources with URLs/hashes, includes Lazy and all theme dependencies, selects Preview by host architecture and passes an explicit bundle directory to the launcher. Release fixture must derive its dependency metadata from the tagged archive, never the caller checkout.
- [ ] Green: stage plugin resources into `libexec` bundle paths; stage the Preview executable at the location its plugin expects. Use checksum-verified resources instead of running upstream download hooks. Generate receipt/metadata from the same manifest and preserve executable modes.
- [ ] Keep existing CLI tool dependencies in `parley.deps`; editor plugins have a separate lifecycle and should not duplicate that registry. Do not add a second list of plugin URLs/pins to Ruby.
- [ ] Verify formula syntax and architecture-specific projections with fixtures. A bottle includes the prepared bundle when built; creating/publishing new release tags or bottles is outside this implementation's authorized publication.
- [ ] Run `make test-spec SPEC=infra/packaging` (confirm traceability spec name first), then commit.

### Task 4: Make starter load the bundle without installing

Files: `packaging/starter-config/init.lua`, `lua/parley/editor_bundle.lua`, `tests/integration/starter_bootstrap_spec.lua`, `tests/packaging/test_local_app.py`, starter fixtures.

- [ ] Red: use a complete read-only fixture bundle and empty user profile; reject every attempted Git clone/download/build. Assert Lazy loads from bundle and every shipped plugin has a local `dir`; missing bundle members fail before Lazy startup. Existing standalone provisioning tests continue to pass.
- [ ] Green: select the supplied bundle explicitly; load bundled Lazy; map manifest entries to local plugin specs, preserving existing opts/config/keys and disabling shipped-plugin download/build/update paths. Disable automatic missing-plugin installation, package discovery, rocks and project-local specs in bundled mode. Plenary's test-only luassert rock must not trigger a download. Personal extras are explicit and outside the offline guarantee.
- [ ] Store Lazy state/lockfiles and plugin caches under user XDG paths. Confirm Preview serves without trying to write its installation directory; redirect mutable state if necessary. Keep Blink's Lua matcher to avoid a native build/download.
- [ ] Preserve existing edited config and publish `.new` through the current launcher; document adoption as required for old starter profiles. Check upgrading retains chats, settings and unrelated plugins and selects dependencies from the new keg.
- [ ] Run starter and local launcher tests, then commit.

### Task 5: Prove parity and offline operation using real artifacts

Files: `scripts/check-editor-bundle.sh`, `tests/packaging/editor_bundle.lua`; reuse `theme_compatibility.lua`, `completion_compatibility.lua`, `spell_compatibility.lua` and current packaging harnesses.

- [ ] Red/green: assemble the real manifest into a temporary bundle and compare the parity report with local-app records. Deliberately corrupt one version or payload and prove the verifier fails before the app proceeds.
- [ ] Launch the production starter from that bundle with empty HOME/XDG and read-only plugin trees. On macOS, run under a sandbox denying external networking while permitting loopback for Preview; fail clearly if enforcement is unavailable rather than report offline proof. Portable tests separately intercept attempted downloader commands.
- [ ] Verify theme switching, buffer/Blink spelling completion, Telescope startup, statusline and a real loopback Preview response. Hash the bundle before/after, assert no package writes and no dependency installation UI/processes. Do not send AI requests.
- [ ] Run fresh launch and relaunch, record elapsed times and artifact sizes. Demonstrate stale local cache detection. Validate both platform projections; execute real conformance on available host architecture.

### Task 6: Documentation and boundary review

Files: `README.md`, `TOOLING.md`, `packaging/README.md`, `packaging/starter-config/README.md`, relevant `atlas/infra/` docs, `atlas/traceability.yaml`, `atlas/index.md` if adding a page.

- [ ] Document the manifest ownership, pin update/verification commands, bundled mode versus development provisioning, old-profile `.new` adoption and offline scope. Replace first-launch download claims only where bundled startup applies.
- [ ] Add new tests to traceability; run mapped starter/packaging/theme checks, local launcher tests, real offline runner, lint and `git diff --check`.
- [ ] Update this plan and issue Log with exact results and limitations. Run `sdlc close --issue 306 --verified '<evidence>'` once all acceptance criteria pass; fix mandatory review findings before PR/merge. Do not publish a Homebrew release implicitly.

## Alternatives considered

Copying a preseeded Lazy cache into each profile would also avoid downloads, but duplicates plugin trees and requires more upgrade reconciliation. Removing Lazy entirely would replace established configuration/loading behavior unnecessarily. Direct local Lazy specs in an immutable bundle are the selected approach.

## Approval checkpoint

The operator approved the packaging direction and shared-pin contract. This is full-flow work; obtain approval of this concrete plan before `sdlc change-code` and implementation, per repository workflow.

## Revisions

- 2026-09-30: Dependency audit identified Lazy's implicit package/rock discovery as an additional network path. Explicitly disable it for bundles; include recording-only Screenkey in manifest membership without adding it to the shipped app.
