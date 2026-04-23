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
- **Makefile system**: `Makefile.workflow`, `scripts/` — issue sync, pre-merge checks
- **Construct system**: `construct/scripts/`, `construct/local/` — skill management
- **Sandbox**: `.openshell/` — containerized dev environment (see below)
- **Directory scaffolds**: `workshop/`, `atlas/` — standard repo layout

## Repo-Specific Extensions

- `AGENTS.local.md` — repo-specific rules (merged with `AGENTS.md` via `make refresh`)
- `Makefile.local` — repo-specific make targets (included by `Makefile`)
- `.claude/settings.local.json` — repo-specific Claude Code settings (merged into `settings.json`)

These files are NOT overwritten by setup.sh.

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
