# macOS package and launcher

Install with `brew install xianxu/parley/parley`, then run `parley`. To update,
run `brew update` and `brew upgrade parley`. Existing settings are preserved;
when the starter changes, the next launch writes an `init.lua.new` candidate
beside your editable settings for comparison. See the [package guide](../../packaging/README.md)
for removal and [starter recovery](../../packaging/starter-config/README.md#profile-files-and-recovery)
for profile paths and interrupted initialization. Removing the Homebrew package
does not delete chats or shared account logins.

## Runtime ownership

The public Homebrew tap installs an immutable released runtime under `libexec`
and exposes its starter under `share/parley/config`. `packaging/formula.lua`
renders the formula from validated tag/digest metadata and the released
`deps.packages` default Darwin projection, adding Neovim. The separate pure
`lua/parley/editor_dependencies.lua` manifest owns the editor plugin and Preview
archive identities. The formula derives checksummed resources from its `app`
membership, preserves source licenses, stages `libexec/editor-bundle/plugins`,
and seals the complete payload using Python 3.13 as a build-only dependency.
Markdown Preview is staged at its manifest-defined executable path without
running its download/build hook. macOS ARM/Intel and Linux Intel have artifact
projections; Linux ARM is refused. CLIProxyAPI stays
Parley-managed. The tap is generated output; this source owns the contract.

Homebrew's environment wrapper fixes the Neovim executable, runtime and starter
paths plus `PARLEY_EDITOR_BUNDLE` and `PARLEY_EDITOR_BUNDLE_INSTALLED=1`.
Installed startup validates structure and manifest identity while trusting the
package-manager-owned payload; build/release verification hashes all payload
files. User-writable local bundles require complete verification on each launch.
These are separate trust boundaries; a copied receipt alone is not proof.
`packaging/parley` sets `NVIM_APPNAME=parley`, respects standard XDG roots,
prepares the profile through a config-free Neovim process, then execs the real
editor with exact caller argv and exit status. It never calls a package manager.

`packaging/launcher.lua` compares bounded regular files and serializes publication
through an owned `.launcher-initializer` directory. Complete initial settings are
published with a no-clobber hard link; upgrades atomically replace one
`init.lua.new` candidate without modifying user settings. Symlinks are refused.
An interrupted owner's lock requires explicit repair after closing all instances;
normal failures remove only owned staging. The starter loads shipped Lazy and
plugin specs from the bundle, disabling missing-plugin installation, package/rock
discovery, project-local specs and shipped-plugin build hooks. Lazy state and
lockfiles remain under user XDG storage. The starter still owns welcome creation
and credentials; see [starter profile](starter.md).

Existing edited profiles must adopt `init.lua.new` bundle loading before gaining
the offline behavior. Old Lazy trees and unrelated personal plugins are retained.
App-owned dependencies update with the Homebrew keg. Standalone profiles without
a supplied bundle retain source bootstrap outside the packaged offline scope.

## Development bundle lifecycle

`parley_app` delegates to `scripts/editor-dependencies.py run`: the `app` profile
and the `recording` profile share manifest records, with Screenkey in recording
only. The boundary exports records through `scripts/export-editor-dependencies.lua`,
checks downloaded archive hashes before extraction and rejects unsafe members.
A complete payload receipt includes path, mode and hash inventory; missing,
changed and unexpected payload files invalidate reuse. Publication uses an owned
staging tree and atomic rename. Repair is explicit and limited to marked managed
roots; old user plugin caches are never reset implicitly.

Each manifest plugin also pins the archive-derived source inventory hash, so
regenerating a writable receipt cannot certify different source files or modes.
The separately pinned Preview binary is excluded from its plugin's source hash.
The `source-identity` tool computes this value from a checksum-verified archive.
Downloads run in bounded disposable workers: the parent enforces the whole
operation deadline, including slow headers and trickling bodies, and reaps a
timed-out worker before removing its partial archive.

An exclusive OS lock covers verification/publication/cleanup, then becomes a
shared lease inherited by the editor process. Competing writers wait at most
120 seconds. One selected bundle survives under the owned root; obsolete owned
bundles and interrupted staging are collected only with the exclusive lease.
Installed Homebrew kegs use package-manager ownership rather than this local
writer lifecycle. CLI commands and archive-cache naming are in
[dependency tooling](../../TOOLING.md#editor-dependency-bundles).

## Maintainer release and acceptance

These scripts are release tooling, not app startup requirements.

`scripts/release-parley.sh` validates source/tap identities and immutable tag
agreement, hashes the tagged archive, and renders using that archive's registry.
Before any formula/tap write, the extracted tag's `scripts/check-editor-bundle.sh`
assembles real manifest artifacts and runs production startup under macOS
external-network denial with loopback allowed for Preview. Unsupported enforcement
fails the gate. Retries must pass it again; caller-checkout manifests, runners and
unchecked caches cannot substitute for tagged-tree evidence.
Local validation/generation precedes explicit publication. Identical retries are idempotent,
including resuming a committed formula whose push failed.

`scripts/test-parley-vm.py` owns one pinned Tart clone and records phase evidence.
Guest probes cover boot containment, fake first-use/chat and real managed-proxy
login with a clipboard-image response. `scripts/test-parley-upgrade.sh` exercises
real Homebrew upgrade using two local fixture versions and restores the public
launcher. Final checks cover removal and the unchanged decoy nvim configuration;
missing OAuth remains pending. A persisted `--keep-on-failure` flag retains the
owned guest for diagnosis. Cleanup confirms inventory absence before releasing
ownership; deletion failure retains the reservation and original failure reason. Filesystem-backed fake Tart/brew and local Git
remotes test failures without mutating the developer's package installation.
Commands and ownership recovery are in [the package guide](../../packaging/README.md).


The offline guarantee covers bundled editor startup, themes, completion and local
Markdown Preview. Initial package/provisioning downloads, AI requests, provider
login and optional personal plugins remain outside it. Real offline evidence is
the conformance runner's successful assertions, not the formula projection tests.
New Lua manifest/runtime tests are mapped under `infra/packaging` and
`infra/starter`; Python artifact tests and the real Neovim bundle harness have
explicit commands in TOOLING.md.
