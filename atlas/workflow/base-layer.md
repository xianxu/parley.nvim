# Ariadne Base Layer

Ariadne provides a portable base layer — constitution, workflow, sandbox, skills — that consuming repos adopt via `construct/setup.sh`.

## Adopting the Base Layer

### Prerequisites
- Clone ariadne as a sibling directory: `../ariadne` relative to your repo
- Or use `--vendor` mode for repos that can't depend on ariadne as a peer

### Setup

```bash
cd /path/to/your-repo
../ariadne/construct/setup.sh          # symlink mode (default)
../ariadne/construct/setup.sh --vendor # vendor mode (copies files)
```

Re-run to refresh after ariadne updates. Mode is recorded in `.ariadne-mode`.

### Modes

| Mode | How | When |
|---|---|---|
| **Symlink** | Files in your repo are symlinks into `../ariadne/` | Default. Requires ariadne as sibling clone. Updates automatically. |
| **Vendor** | Files are copied from ariadne into your repo | For public repos or CI without ariadne peer. Re-run setup.sh to refresh. |

## What Gets Installed

Defined in `construct/base.manifest` (in ariadne):

- **Constitution**: `AGENTS.md`, `CLAUDE.md` — shared development rules
- **Settings**: `.claude/settings.json` — merged from `.ariadne` and `.local` layers
- **Skills**: `.claude/skills/xx-*` — local-origin skills (superpowers are per-repo via `/construct adapt`)
- **Makefile system**:
  - `Makefile` — generic root template (REPO_NAME, workflow + local include, help chain). Identical across consumers; per-repo concerns belong in `Makefile.local`.
  - `Makefile.workflow` — issue lifecycle targets + auto-includes of `.openshell/Makefile` and `.tart/Makefile`.
  - `scripts/` — issue-sync, pre-merge-checks, close-issue.py, lib.sh
- **Construct system**: `construct/scripts/`, `construct/local/`, `construct/datatype/` — skill + datatype management
- **Sandbox** (`.openshell/`) — Linux container dev environment (see below)
- **Tart VMs** (`.tart/`) — `make tart` (headless + bind-mount `$(CURDIR)` at `/Volumes/My Shared Files/$(REPO_NAME)`) and `make tart-gui` (same but display via macOS Screen Sharing.app via `--vnc`; tart's built-in UI is broken on Tahoe as of 2026-05) for macOS VM testing (Apple Silicon only); helpers under `.tart/scripts/`. Override `RUN_FLAGS=` for a no-mount boot. `make help-tart` for the full surface.
- **Directory scaffolds**: `workshop/`, `atlas/` — standard repo layout

## Repo-Specific Extensions

These files are **not** overwritten by setup.sh and own everything
that doesn't generalize across consumers:

- `AGENTS.local.md` — repo-specific rules (merged with `AGENTS.md`)
- `Makefile.local` — repo-specific make targets and overrides:
  - `UPSTREAM_NAME` / `UPSTREAM_REFRESH` for re-export layers (nous has its own `setup.sh` that re-vendors ariadne, so its `Makefile.local` points refresh through that path)
  - `-include Makefile.nous` chain for repos that consume the nous layer (brain, brain.legacy*)
  - Any genuinely one-of-a-kind target the repo needs
- `.claude/settings.local.json` — repo-specific Claude Code settings (merged into `settings.json`)
- `.openshell/.bootstrap/`, `.openshell/.base-image-digest` — runtime artifacts (gitignored)

If you find yourself wanting to edit a vendored file directly, the
right move is almost always to (a) generalize the change and push it
into ariadne, or (b) override it in the `.local` layer. Direct edits
get clobbered on the next `make refresh`.

## Pushing Updates to All Consumers

Ariadne maintainers can propagate base-layer changes in one shot:

```bash
cd /path/to/ariadne
make refresh-recursive
```

This iterates every peer repo in the parent directory and runs
`make refresh` in each one that has a `Makefile.workflow` (the universal
"uses the ariadne base layer" signal — catches direct consumers via
`.ariadne-mode`, indirect ones via `.nous-mode`, and re-export layers
like nous itself). Failures are collected into a final summary; partial
progress is better than aborting on the first hiccup.

Defined in `ariadne/Makefile.local` — ariadne-only, not vendored
(consumers don't push to their own peers).

## Sandbox (.openshell/)

The sandbox is an OpenShell containerized dev environment. Base layer provides the full infrastructure.

### Path Resolution Convention

**Critical design rule**: all scripts in `.openshell/` resolve runtime paths to the **local repo**, not to ariadne.

- `.openshell/` is a real directory in every repo (created by setup.sh)
- Its contents (sandbox.sh, overlay/, dotfiles/, etc.) are symlinks to ariadne (symlink mode) or copies (vendor mode)
- `sandbox.sh` derives paths from `$0` (how it was invoked), not from where the script physically lives
- `REPO_DIR` = consuming repo root (from `dirname "$0"/..`)
- `SCRIPT_DIR` = `$REPO_DIR/.openshell` (always local)

### Runtime Artifacts (local per-repo, gitignored)

| Path | Created by | Purpose |
|---|---|---|
| `.openshell/.bootstrap/` | `make sandbox` (bootstrap.sh) | Pre-downloaded dependencies (nvim, zellij, lua, etc.) |
| `.openshell/.bootstrap/.done` | bootstrap.sh | Marker to skip re-downloading |
| `.openshell/.base-image-digest` | sandbox.sh | Tracks container base image version |

These are **not** in `base.manifest` — they're created at runtime by `make sandbox` and are local to each repo.

### Bootstrap Trampoline

The `.bootstrap/` cache is a small pre-download trampoline to avoid slow package manager installs inside the sandbox. `bootstrap.sh` downloads on the host (fast, no proxy), mutagen syncs to `/tmp/bootstrap/` in the sandbox, then `post-install.sh` installs from there.

### Sandbox Commands

```bash
make sandbox        # build (if needed) + connect
make sandbox-clean  # re-sync config, reconnect with fresh shell
make sandbox-nuke   # destroy everything including bootstrap cache
```
