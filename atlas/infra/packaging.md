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
`deps.packages` default Darwin projection, adding Neovim. CLIProxyAPI stays
Parley-managed. The tap is generated output; this source owns the contract.

Homebrew's environment wrapper fixes the Neovim executable, runtime and starter
paths. `packaging/parley` sets `NVIM_APPNAME=parley`, respects standard XDG roots,
prepares the profile through a config-free Neovim process, then execs the real
editor with exact caller argv and exit status. It never calls a package manager.

`packaging/launcher.lua` compares bounded regular files and serializes publication
through an owned `.launcher-initializer` directory. Complete initial settings are
published with a no-clobber hard link; upgrades atomically replace one
`init.lua.new` candidate without modifying user settings. Symlinks are refused.
An interrupted owner's lock requires explicit repair after closing all instances;
normal failures remove only owned staging. The starter then owns plugin bootstrap,
welcome creation and credentials; see [starter profile](starter.md).

## Maintainer release and acceptance

These scripts are release tooling, not app startup requirements.

`scripts/release-parley.sh` validates source/tap identities and immutable tag
agreement, hashes the tagged archive, and renders using that archive's registry.
Local generation precedes explicit publication. Identical retries are idempotent,
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
