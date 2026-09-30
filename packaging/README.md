# Parley for macOS

Install with Homebrew, then open Parley:

```sh
brew install xianxu/parley/parley
parley
```

Homebrew installs the pinned editor plugins and Markdown Preview server with
the application. The bundled starter opens a welcome chat without dependency
downloads. Themes, completion and local Preview do not need external networking;
Homebrew installation, provider login, AI requests and personal plugin additions
are outside that offline scope. In
Parley, press Escape and type `:ParleyProxy connect`, then press Return. Choose your
provider and finish its account login in the browser. Follow the welcome chat
for choosing a model, sending a question, and pasting an image.

Parley keeps its editor configuration and chats separate from your existing
Neovim setup. The app and plugin share provider logins in `~/.cli-proxy-api`. `parley notes.md` opens a file. Settings live in
`~/.config/parley/init.lua` (or your configured XDG config directory).
See the [starter guide](starter-config/README.md) for shortcuts and recovery.

Run `:ParleyTheme` to preview packaged editor themes. Move through the picker
to preview Catppuccin Mocha (dark/colorful), Tokyo Night Storm (dark/subdued),
Catppuccin Latte (light/colorful), or Solarized Light (light/subdued). Press
Enter to keep a choice; Escape restores the opening theme. The committed choice
is restored on the next launch.

The picker also includes all OneDark styles (dark, darker, cool, deep, warm,
warmer, light) and all Nightfox variants (nightfox, dayfox, dawnfox, duskfox,
nordfox, terafox, carbonfox).

Editor dependency versions come from `lua/parley/editor_dependencies.lua` in the
released runtime. Homebrew upgrades replace that bundle with the app; do not use
`:Lazy update` or `:Lazy build` to change the packaged dependencies. Local plugin
users still manage their own dependencies.

## Updates and removal

```sh
brew update
brew upgrade parley
```

Your settings stay intact. When the packaged starter changes, launching Parley
places the complete new version beside your settings as `init.lua.new`. Compare
it with `init.lua` and adopt its bundle-loading setup while retaining personal
settings. This adoption is required for an older edited starter to gain offline
startup; simply upgrading the package does not rewrite your configuration.
Repeated launches keep one candidate and do not repeat the notice for unchanged
bytes. Old per-profile Lazy checkouts and unrelated plugins are left in place;
no migration silently deletes them. The new starter loads shipped dependencies
from the current Homebrew keg.

Before uninstalling, run `:ParleyProxy stop` inside Parley and close the app.
Then run `brew uninstall parley`. Homebrew removes the application; your chats
and account logins remain. To remove the app settings and chats too, first save
anything you want, then remove the four Parley directories listed in the
[profile guide](starter-config/README.md#profile-files-and-recovery). Shared
logins in `~/.cli-proxy-api` remain available to the plugin and other proxy clients;
they are not part of app-profile removal.

## Maintainer release

The source release contains the launcher, formula renderer, starter, CLI tool
registry and checksummed editor manifest. Release publication is a separate
maintainer action from implementing or testing packaging changes. After its
SDLC review and release authorization, create and push a new immutable `vMAJOR.MINOR.PATCH`
tag and GitHub release. Never move a published tag. From this source checkout:

```sh
scripts/release-parley.sh vMAJOR.MINOR.PATCH /path/to/homebrew-parley
```

Inspect `Formula/parley.rb` in that tap checkout, then publish the same bytes:

```sh
scripts/release-parley.sh vMAJOR.MINOR.PATCH /path/to/homebrew-parley --publish
```

The script checks both repository identities and matching local/remote tag
commits, downloads the tagged archive, hashes it, and uses that archive's own
renderer and dependency manifest. Before writing the tap, it runs the extracted
tag's `scripts/check-editor-bundle.sh`: assemble and verify a fresh bundle, then
launch the production starter under a macOS external-network deny policy while
allowing loopback Preview. This gate also runs on publication retries and fails
if network enforcement is unavailable. A failed check leaves the tap unchanged.
An identical successful retry creates no extra commit; publication can retry an
interrupted push. The tap must otherwise be clean.
The application never invokes Homebrew itself. CLIProxyAPI remains managed by
Parley; the formula installs Neovim and the default macOS tool projection.
Python 3.13 is a build-only dependency used to seal the checksummed editor
bundle; installed app startup does not invoke Python or download hooks.

Run the conformance gate directly from a checkout with
`scripts/check-editor-bundle.sh`. `PARLEY_EDITOR_ARCHIVES=/path/to/archives` uses
a complete local archive set instead of fetching artifacts. See
[dependency tooling](../TOOLING.md#editor-dependency-bundles) for provisioning,
verification and pin updates. Running the gate does not publish a release.

## Clean-machine acceptance

The maintainer harness requires Python 3 and Tart on an Apple Silicon Mac, a
cached pinned image, and at least 60 GiB free. It reserves one uniquely named
clone, disables Tart auto-pruning and host clipboard sharing, and never copies
host provider credentials. Each phase stores a redacted manifest in RUN_DIR:

```sh
scripts/test-parley-vm.sh boot /tmp/parley-acceptance-run
scripts/test-parley-vm.sh install /tmp/parley-acceptance-run
scripts/test-parley-vm.sh fake /tmp/parley-acceptance-run
scripts/test-parley-vm.sh upgrade /tmp/parley-acceptance-run
scripts/test-parley-vm.sh prepare-auth /tmp/parley-acceptance-run
# Complete :ParleyProxy connect in the guest.
scripts/test-parley-vm.sh check-live /tmp/parley-acceptance-run
scripts/test-parley-vm.sh uninstall /tmp/parley-acceptance-run
scripts/test-parley-vm.sh verify /tmp/parley-acceptance-run
```

For diagnosis, add `--keep-on-failure` to any phase. The manifest remembers it
for later phases. A failure then retains the owned VM and its reservation,
records a controlled phase/command/reason, and leaves detailed logs inside the
guest. Run `cleanup RUN_DIR` when finished. If a failed clone created no VM,
confirmed absence releases the reservation even in diagnosis mode.

Exit 75 means required acceptance is pending, including guest authentication;
it does not mean success. The live check sends a guest clipboard image through
the installed managed proxy and requires a completed nonempty response. The
upgrade check installs two local fixture versions, checks settings preservation
and the new candidate, then restores the public package. Removal checks the
proxy, all four profile roots and the unchanged decoy Neovim configuration.
Final verification requires all phase evidence and removes only the owned VM.
For an abandoned run, `scripts/test-parley-vm.sh cleanup RUN_DIR` removes that
clone after verifying its ownership reservation. It leaves other VMs intact.
