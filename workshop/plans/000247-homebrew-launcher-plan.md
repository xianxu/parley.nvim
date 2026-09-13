# Homebrew Launcher and Clean-Machine Acceptance Implementation Plan

> **For agentic workers:** Consult AGENTS.md Section 3; use superpowers-executing-plans for release/VM integration and bounded subagents for pure generation/tests. Steps use checkboxes.

**Goal:** `brew install xianxu/parley/parley`, then `parley`, opens the isolated chat app on a clean Mac and supports a real authenticated question with an image.

**Architecture:** This repo owns launcher, formula generation and acceptance scripts. The public tap contains the generated formula. The formula installs a versioned release and supplies that runtime to #246's single-file starter, so Homebrew and the running plugin agree on the version.

**Tech Stack:** Homebrew Ruby formula, macOS POSIX shell, Neovim/Lua, local git fixtures, Tart guest agent, existing fake proxy/release fixtures.

**State:** Design prepared for operator approval; implementation follows #246.

## Scope and decisions

Create `xianxu/homebrew-parley` as the public tap after the implementation is
reviewable. Its generated formula depends on Neovim plus #245's default Darwin
projection (ripgrep). CLIProxyAPI remains Parley-managed with first-use download;
ImageMagick/ffmpeg/vips/pandoc remain optional. No Homebrew command is run by the
application launcher or its runtime.

Install the complete released plugin/runtime under formula `libexec`, expose the
starter at `share/parley/config`, and install `bin/parley` with fixed formula paths.
The launcher sets `NVIM_APPNAME=parley` and `PARLEY_RUNTIME` to this installed
release. It uses standard XDG roots (defaults under HOME) and explicitly loads the
profile's init.lua. Forward arguments as argv, preserving spaces and exit status.
Callers' explicit Neovim commands are trusted inputs; ordinary launches never
source the separate nvim configuration. Refuse unsafe symlink targets before
writing the managed starter files.

The single editable init.lua is the upgrade unit. First launch atomically
publishes a complete file only if absent, using no-clobber creation. Subsequent
launches leave it untouched; a different packaged version is written atomically
as `init.lua.new`. Identical content does not rewrite files or repeat notices.
Only one generated candidate is kept. Initial publication races preserve the
winning complete file; interrupted staging is reclaimed without following links.
Do not merge Lua settings, maintain per-file migration history, or overwrite edits.

Formula creation is a pure projection of validated release metadata and the
registry package list. A release script obtains the immutable tagged archive,
checks its digest and renders the formula; publication updates only the named tap
file after checking repository identity and a clean worktree. A tag is never
moved, and no release is selected from a mutable main-branch URL. Existing tag
v2.1.0 predates packaging; publish and exercise a new reviewed release.

Alternatives considered: a core formula does not fit this project's independent
app release cadence; a shell installer adds a second package lifecycle. Keep the
personal tap and one source-owned generator (ARCH-DRY/PURPOSE).

## Core concepts

| Name | Lives in | Kind | Status |
|---|---|---|---|
| `render_formula`, `validate_release` | `packaging/formula.lua` | PURE | new |
| Default package projection | `lua/parley/deps.lua` | PURE | reused |

| Name | Lives in | Kind | Status | Wraps |
|---|---|---|---|---|
| `prepare_profile`, launcher entry | `packaging/launcher.lua`, `packaging/parley` | INTEGRATION | new | filesystem publication and exec of formula Neovim |
| Formula render CLI | `packaging/render-formula.lua` | INTEGRATION | new | environment metadata, pure renderer and formula file output |
| Live model selection | `tests/packaging/vm_chat.lua` | INTEGRATION | new | canonical model-provider axis and credential/catalog callbacks |
| Release/tap update command | `scripts/release-parley.sh` | INTEGRATION | new | tagged archives, sha256, Git and gh |
| Generated `Parley` formula | tap `Formula/parley.rb` | INTEGRATION | new | Homebrew install and formula test |
| VM acceptance command and guest checks | `scripts/test-parley-vm.sh`, `tests/packaging/vm_acceptance.lua` | INTEGRATION | new | disposable Tart VM, real brew/Neovim/provider |
| Guest proxy stop and profile removal | `tests/packaging/vm_stop.lua`, `tests/packaging/vm_uninstall.py` | INTEGRATION | new | identity-checked stop, Homebrew uninstall and bounded profile removal |
| Stateful launcher/release fixtures | `tests/fixtures/fake_packaging_*`, `tests/fixtures/fake_tart`, `tests/fixtures/run_packaging_vm.py`, `tests/packaging/` | INTEGRATION | new | recorded argv, local git/tap and archive state |

One executable source owns profile publication and argv forwarding. Formula tests
and local acceptance invoke that same launcher. The formula generator consumes
`deps.packages({sysname='Darwin',manager='brew'},'default')` directly; a separately
parsed generated formula must equal that set plus Neovim, and must exclude managed
CLIProxyAPI. No hand-maintained second dependency list.

## Chunk 1: Package, publish and prove the app

- [x] Implement formula projection and launcher with atomic initial config/candidate publication; add stateful filesystem/argv tests and registry parity coverage to `make test`.
- [ ] Implement release/tap tooling using local git repositories and archive fixtures for deterministic retry/failure coverage; generate the exact reviewable formula and tap README locally.
- [ ] Add isolated VM acceptance and uninstall checks, document commands and artifact ownership in atlas/README, and update the project.
- [ ] Run local checks and SDLC close review. Publish the reviewed release/tap and run the actual clean-VM installation; fix/re-close on new code changes. Merge/archive only with the full acceptance evidence, then verify the public install command again.

## Function test strategies

| Function/surface | Adversarial class → mechanical guard |
|---|---|
| `validate_release`, `render_formula` | Malformed tag/digest and drifted package sets → pure rejection/property assertions plus independently parsed formula parity. |
| `prepare_profile` | Existing edits, interrupted writes, races, spaced paths and symlinks → real temporary filesystem/process tests assert no partial config and no overwritten user file. |
| Launcher exec | Shell metacharacters and nonzero child exits → stateful executable fixture records exact argv/environment and propagates status without shell reinterpretation. |
| Release/tap command | Existing tags, dirty/wrong tap and interrupted publication → real local git repos and stateful gh/archive fixture assert fail-closed, idempotent publication. |
| VM acceptance command | Boot/guest-agent failure and failed guest phases → fixture-owned VM state records cleanup and preserves other VMs; one real pinned-image run checks conformance. |
| Guest startup/login/chat | Empty profile, decoy nvim config and absent proxy → real installed launcher plus existing fake provider checks, followed by actual authenticated image response in the disposable guest. |

## Clean-machine acceptance

Use the cached Cirrus macOS Tahoe base image pinned by digest
`sha256:1b093499716409d29e8b5336844528e1cae375db97d2ad8e5aeff78cf0da201e`.
Clone it into a uniquely named project VM, verify its Homebrew/guest-agent state,
and install prerequisites only inside that clone. Do not reuse personal/test VMs
or alter the currently running tools-test VM. Start without host clipboard sharing.

Inside the guest: install the public formula; hash a decoy nvim profile; launch
Parley and inspect profile containment and welcome UI; trigger managed first-use
installation and provider login through its prompt; select an available live
model; send a real question with a clipboard image and assert a nonempty response.
Use a guest-only fake provider first to separate packaging failures from account
availability. The live phase must complete the shipped managed-proxy login → live model →
image-response route. An explicitly supplied VM keychain test service is usable
only if it authenticates that managed proxy; a direct keyed-provider send cannot
substitute for this acceptance. Otherwise the operator completes OAuth in the
guest. Never copy host credentials or print secret values.
The operator is being asked which route to use. Missing authorization leaves the
live phase pending, not a passing/skipped acceptance claim.

Exercise edited init.lua across a formula upgrade, inspect its intact bytes and
complete `.new` candidate, then confirm the decoy nvim profile is unchanged.
Stop the profile's managed proxy using the existing identity-checked command
before uninstalling. `brew uninstall parley` removes package files; removal of
ALL four owned profile roots removes user config/data/state/cache. Confirm no
owned proxy remains. Cleanup deletes only this run's VM and temporary artifacts.

## Operating envelope and lifecycle

One additional VM (there is already one running), one active package install,
no fan-out. Bound boot/readiness to 180 seconds, each package/bootstrap phase to
15 minutes and a model response to 120 seconds; record phase failures explicitly.
First-run network/disk work is expected; later launcher preparation performs only
small file comparisons and exec (measure its overhead separately from Neovim).
Refuse insufficient free disk before cloning; the base has a 50 GB virtual disk
and local clone allocation must be observed, not assumed (ARCH-CONSTRAINTS).

One `.new` candidate and bounded owned staging per profile; reap orphan staging
on subsequent launches and trap normal failures. The disposable VM is stopped and
removed on success/failure, except an explicitly retained diagnosis run. Redacted
acceptance reports are attached to the issue/release; no credential-bearing
console dump. Git tags/releases and tap history are intentional durable release
records, one entry per published version (ARCH-FUNERAL/SECURE).

## Revisions

### 2026-09-13 — approved dependency policy and complete profile lifecycle

Operator requested #246 then #247. #245's approved default projection supersedes
all-advisory parity. Removal includes state and cache as well as config/data;
this corrects the original two-directory shorthand. The starter has one editable
init.lua so upgrades can publish an atomic candidate without a config merge.
The clean-VM live phase remains required. Exact plan approval is pending.

Sources: [Homebrew Formula Cookbook](https://docs.brew.sh/Formula-Cookbook),
[Tart guest agent](https://tart.run/blog/2025/06/01/bridging-the-gaps-with-the-tart-guest-agent/).

### 2026-09-13T14:43:00-07:00 — fresh review corrections

Clarify that live acceptance authenticates the shipped managed proxy, never a
substitute direct provider. Reconcile the issue dependency metadata with the
operator’s spine. Classify launcher publication with its filesystem integration.

### 2026-09-13T14:46:00-07:00 — plan review accepted

Fresh-context review approved after dependency and live-authentication corrections.
Operator implementation approval remains pending.

### 2026-09-13T15:24:00-07:00 — implementation approved

Operator said “continue” after the concrete plans were presented for approval.
Proceed through #246 then #247; no further plan approval is required.

### 2026-09-13 — verified preflight and execution contracts

#246 merged as PR #180 and released v2.2.0. The packaging release will use a new
immutable tag after review. Formula rendering runs through headless Neovim
(`-u NONE -i NONE`) against the selected release tree, loading that tree’s registry;
no standalone Lua interpreter becomes a runtime dependency. Its pure input is
{tag, sha256}; output is the complete formula string. Release tooling takes a tag
and tap checkout path, validates remote identity and tag commit, fetches the tagged
archive, computes its SHA256, and uses that archive’s renderer/registry. Generation
is local by default; an explicit publish mode commits/pushes the exact generated
formula only after clean tap identity checks. Retry is a no-op for identical bytes;
conflicting immutable tags are errors, never moved (ARCH-DRY/ORDER).

Launcher staging is inside an atomically acquired profile publication directory
with owner PID, bounded waiting and no automatic lock stealing. As in #246,
dead/malformed ownership reports the precise path and requires closing all app
instances before explicit cleanup. Normal failures clean only owned staging;
first init uses no-clobber publication, candidate replacement uses atomic rename,
and the lock serializes candidate comparison/notice/publication. This supersedes
unconditional orphan reaping: a later launch never deletes another’s active work.
Tests exercise actual competing and killed publishers, including explicit recovery.

Tart 2.32.1, Homebrew 6.0.22 and Neovim 0.11.7 are installed; the exact OCI digest
is cached, and 122 GiB is free. Set TART_NO_AUTO_PRUNE=1 for clone to preserve other
images. Require at least 60 GiB free before cloning and report observed allocation.
The VM is the only additional instance; tools-test remains untouched. Verify guest
agent and brew inside the clone. Upgrade acceptance uses two controlled, distinct
local package versions built from the reviewed release fixture, with different
starter bytes, then restores the public formula for final live acceptance. This
exercises real brew upgrade without publishing a meaningless extra public release.
Guest OAuth authentication remains pending operator input; it is not waived.

### 2026-09-13 — portable atomic publication shell

The POSIX launcher uses the already-required installed Neovim in a profile-free
headless preparation process, then execs the interactive invocation. File
publication lives in `packaging/launcher.lua`, using libuv atomic link/rename;
this avoids platform-specific shell mv directory/symlink behavior and adds no
runtime dependency. Neovim argument forwarding stays in one shell entry. The
formula supplies fixed PARLEY_NVIM/PARLEY_RUNTIME/PARLEY_STARTER paths with
Homebrew write_env_script. Measure the extra preparation startup overhead.
The VM shell entry delegates host orchestration to `scripts/test-parley-vm.py`;
Python is a maintainer harness dependency only, never a launcher dependency.

### 2026-09-13 — acceptance implementation map

The VM integration consists of `scripts/test-parley-vm.py` (owned clone and
phase evidence), `tests/packaging/vm_acceptance.lua` (installed boot isolation),
`vm_chat.lua` and `vm_chat_probe.lua` (fake/managed live image chat). Controlled
upgrade is `scripts/test-parley-upgrade.sh`, exercising guest Homebrew with two
fixture versions and restoring the public launcher even after failure. All are
INTEGRATION surfaces; filesystem-backed fake Tart and fake brew cover failures,
and the retained real guest provides conformance. Final verify requires each
phase's measured evidence before deleting the owned VM and reporting success.

### 2026-09-13 — architectural guard scope correction

The first full suite found the symbol guard searched only lua/scripts/tests,
so it could not see real functions in the new packaging tree. Include packaging
in both definition and added-export scans, and replace the provisional
run_acceptance name with the implemented command surface. Map all five new
specs to infra/packaging. These are guard/map corrections, not waived checks.

### 2026-09-13 — boundary review installed-layout corrections

BR-1: Homebrew installs the starter by moving it from libexec to the formula
prefix's `share/parley/config/init.lua`. The upgrade harness must read that
installed location, then reconstruct the source archive before rendering fixture
versions. Its filesystem-backed fake must perform the same move, so an accidental
source-layout assumption fails before real publication (ARCH-MOCK/PURPOSE).
BR-2: Ruby syntax validation runs in release integration coverage. The pure
renderer unit tests contain only input/output and registry-parity assertions.

### 2026-09-13 — deterministic VM capacity seam

BR-3 integration-environment-isolation: the orchestrator's main entry accepts a
disk-usage callable defaulting to the real filesystem probe. The test-only Python
runner injects a fixed capacity; no application or production CLI environment
variable can waive the disk guard. Cover both adequate capacity and 59 GiB refusal
before Tart/clone, including reservation release (ARCH-MOCK/CONSTRAINTS).

### 2026-09-13 — final review dispositions before release

The alternate SDLC reviewer independently passed every packaging test including
loopback and returned FIX-THEN-SHIP. Bundle its fixes and close metadata into one
commit, as the gate directs; no repeat close is needed for those fixes. BR-4/5
cover absent-VM cleanup, faithful Tart error codes and explicit retained diagnosis.
BR-7 discovers models on cliproxy_config.providers(), distinct from login aliases;
its regression covers a healthy Codex account with no models followed by Google.
BR-8 consolidates rendering and upload helpers. BR-6 keeps the project task and
public/live acceptance unchecked until the complete VM manifest; local
codecomplete is not final acceptance or authorization to archive prematurely.
