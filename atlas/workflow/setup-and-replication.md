# Setup & Replication

`construct/setup.sh` is the unified base-layer-replication mechanism. One
canonical script lives in ariadne and gets vendored down to every derivative
via `construct/base.manifest`. Same source-of-truth file at every layer.

Design rationale: `workshop/issues/000032`.

## What it does

For a target repo, walks each transitive upstream layer's
`construct/base.manifest` in topological order (ancestors first), applying
the manifest's `symlink` / `copy` / `merge` / `scaffold` / `touch` actions.
Then runs post-processing: creates `Makefile` + `Makefile.local` if absent,
applies `.gitignore` entries, syncs local-skill symlinks, records mode.

The "walk N manifests" generalizes today's depth-specific scripts:
- ariadne at depth 0: no ancestors, self-refresh just runs skill sync.
- nous at depth 1 (post-migration): walks ariadne's manifest, applies into nous.
- baby brain at depth 2: walks ariadne's, then nous's, then its own
  contributions (if any).

## Ancestor discovery — go.mod is the authoritative manifest

**Every ariadne-style derivative declares its upstream(s) in its own `go.mod`
via `replace` directives.** This is the convention regardless of whether the
derivative is itself a Go project — a pure-Lua plugin like parley.nvim still
writes a 3-line `go.mod` purely to declare its substrate ancestor:

```
module github.com/xianxu/parley.nvim

go 1.22

replace github.com/xianxu/ariadne => ../ariadne
```

The `go.mod` here is functioning as the **dependency-management manifest**,
not as a "this is a Go project" declaration. It explicitly records what the
repo consumes and where to find it. Transitive chains (baby brain → nous →
ariadne) just need the immediate `replace`; setup.sh's recursive walker
follows each upstream's own `go.mod` to discover the rest.

### Why go.mod (and not a separate `.upstreams` file)

- **It's already the convention** in any repo that has Go code at all.
  Post-ariadne#31 every ariadne-style repo will gain Go code eventually
  (sdlc binary, project-specific tooling); deferring the convention until
  Go arrives means churn later. Better to write the 3-line go.mod up-front
  and have one consistent dependency mechanism across the whole layer
  chain.
- **Transitive resolution is free.** setup.sh's recursive replace-walk uses
  `go.mod`'s own grammar; no parallel parser to maintain.
- **Versioning evolves naturally.** When ariadne (or any upstream) goes
  public, the same `replace` line becomes `require <module> <version>` for
  pin-mode — no migration of the dependency mechanism itself.
- **Explicit in-tree record.** Anyone reading the derivative can see in
  `go.mod` exactly which upstreams it consumes. The pre-#32 model
  communicated this only by invocation path (`../ariadne/construct/setup.sh`)
  with no on-disk evidence.

### Three discovery sources, in priority order

When setup.sh runs, ancestor candidates are collected from:

1. **Recursive `replace` walk** starting at target's `go.mod`. Each replaced
   path's own `go.mod` is then probed for further replaces. BFS through the
   chain, reversed to topological order (deepest = foundation first).
2. **`go list -m -f '{{.Dir}}' all`** — picks up modules referenced by real
   Go-import code (require lines that survive `go mod tidy`). Added to
   ancestors not already discovered.
3. **Script's own resolved upstream** — last-resort fallback when no `go.mod`
   exists at all. Preserved for first-time bootstrap (running
   `../ariadne/construct/setup.sh` from a brand-new directory) and for
   genuinely-old consumers that haven't yet written `go.mod`. **Not the
   recommended steady state** — derivatives should write `go.mod` after
   first adoption.

Candidates are filtered to dirs that ship `construct/base.manifest` and
deduped. Target's own manifest is walked separately after ancestors.

## Three operating modes (orthogonal to depth)

Recorded in `.ariadne-mode` (legacy filename, kept for backward compat):

| Mode | Manifest entries become | Use case |
|---|---|---|
| `symlink` (default) | symlinks into the upstream | Sibling-checkout development; trunk-follow |
| `vendor` | copies in target tree | Pinned snapshot; offline / hermetic builds |

Switch with `--symlink` / `--vendor` flags. Mode change requires confirmation
(`--yes` to skip).

Note: the `symlink` mode here is orthogonal to Go's `replace` directive.
Go's replace controls where Go *imports* resolve to; `symlink` here controls
how non-code text files are vendored from the upstream's resolved location.
Both can use the same upstream path.

## Adopting a fresh derivative

The recommended pattern at every layer — Go-using or not — writes a
`go.mod` upfront so the upstream is explicitly declared:

```bash
cd /path/to/new-derivative
git init

# Minimal go.mod — declares the upstream relationship regardless of
# whether this derivative has its own Go code.
cat > go.mod <<EOF
module github.com/<owner>/<derivative>

go 1.22

replace github.com/xianxu/ariadne => ../ariadne
EOF

../ariadne/construct/setup.sh --yes
```

After this:
- `AGENTS.md`, `Makefile.workflow`, scripts, etc. are linked into the derivative.
- `Makefile`, `Makefile.local`, `AGENTS.local.md` are created if absent.
- `.ariadne-mode` records `symlink` (or `vendor` if `--vendor` was passed).
- `construct/setup.sh` itself is linked, so the derivative can self-refresh.
- The derivative's `go.mod` declares ariadne as its upstream — future
  refreshes use this explicit record instead of falling back to script-
  upstream inference.

### Skipping go.mod for first-time bootstrap

The fallback path (no go.mod → script's resolved upstream) makes it possible
to run setup without writing `go.mod` first. This is fine for the very first
invocation when you don't know the module path yet. But the recommended
workflow is to write `go.mod` either before or immediately after — having
an explicit on-disk record of what your repo consumes is worth the three
lines.

### Subsequent updates

`make refresh` re-runs setup.sh against the upstream location Go resolves.
Bumping a pinned version = editing the `require` line. Switching to
trunk-follow on a sibling = changing the `replace` RHS to `../<upstream>`.
All upstream-relationship changes happen in `go.mod`; setup.sh just acts on
what it finds there.

## Per-binary build opt-out

`Makefile.workflow build:` scans `cmd/*/main.go` and builds each. Some binaries
shouldn't be auto-built (e.g., the nous binary is distributed signed +
notarized — overwriting `bin/nous` with an unsigned local build invalidates
macOS keychain ACL grants and notification capabilities).

Opt out per-binary by dropping a sentinel:

    cmd/<name>/.skip-make-build

Contents are free-form prose explaining the rationale (future operators read
it). Each opted-out binary owns its sentinel; the base layer doesn't carry
derivative-specific name lists.

## Generated artifacts (not vendored)

Artifacts that are *functions of code shipping through Go modules* (e.g.,
`construct/local/sdlc/SKILL.md` from `sdlc --index`) are NOT shipped via
`base.manifest`. They regenerate at the consumer via the binary's
install/refresh path. The version of the binary determines the version of
every derived artifact automatically — no text-vs-code lockstep drift
possible.

## Related

- `construct/base.manifest` — what ariadne contributes (action + path
  pairs).
- `construct/setup.sh` — this script.
- `workshop/issues/000032` — design rationale, three operating modes,
  migration plan.
- `atlas/workflow/base-layer.md` — adopting ariadne's base layer (this
  document supersedes parts of it; cross-reference as the system stabilizes).
