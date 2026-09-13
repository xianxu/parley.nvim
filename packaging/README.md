# Parley for macOS

Install with Homebrew, then open Parley:

```sh
brew install xianxu/parley/parley
parley
```

The first launch downloads the editor plugins and opens a welcome chat. In
Parley, press Escape and type `:ParleyConnect`, then press Return. Choose your
provider and finish its account login in the browser. Follow the welcome chat
for choosing a model, sending a question, and pasting an image.

Parley keeps its configuration, chats and login separate from your existing
Neovim setup. `parley notes.md` opens a file. Settings live in
`~/.config/parley/init.lua` (or your configured XDG config directory).
See the [starter guide](starter-config/README.md) for shortcuts and recovery.

## Updates and removal

```sh
brew update
brew upgrade parley
```

Your settings stay intact. When the packaged starter changes, launching Parley
places the complete new version beside your settings as `init.lua.new`. Compare
it with `init.lua` and copy any changes you want. Repeated launches keep one
candidate and do not repeat the notice for unchanged bytes.

Before uninstalling, run `:ParleyProxy stop` inside Parley and close the app.
Then run `brew uninstall parley`. Homebrew removes the application; your chats
and account login remain. To remove those too, first save anything you want,
then remove the four Parley directories listed in the
[profile guide](starter-config/README.md#profile-files-and-recovery).

## Maintainer release

The source release contains the launcher, formula renderer, starter and dependency
registry. After its SDLC review, create and push a new immutable `vMAJOR.MINOR.PATCH`
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
renderer and dependency registry. An identical retry creates no extra commit;
publication can retry an interrupted push. The tap must otherwise be clean.
The application never invokes Homebrew itself. CLIProxyAPI remains managed by
Parley; the formula installs Neovim and the default macOS tool projection.

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
# Complete :ParleyConnect in the guest.
scripts/test-parley-vm.sh check-live /tmp/parley-acceptance-run
scripts/test-parley-vm.sh uninstall /tmp/parley-acceptance-run
scripts/test-parley-vm.sh verify /tmp/parley-acceptance-run
```

Exit 75 means required acceptance is pending, including guest authentication;
it does not mean success. The live check sends a guest clipboard image through
the installed managed proxy and requires a completed nonempty response. The
upgrade check installs two local fixture versions, checks settings preservation
and the new candidate, then restores the public package. Removal checks the
proxy, all four profile roots and the unchanged decoy Neovim configuration.
Final verification requires all phase evidence and removes only the owned VM.
For an abandoned run, `scripts/test-parley-vm.sh cleanup RUN_DIR` removes that
clone after verifying its ownership reservation. It leaves other VMs intact.
