# Directory Conventions

## Standard layout for ariadne-managed repos

```
repo/
├── AGENTS.md              # Constitution (workflow rules, design principles)
├── CLAUDE.md              # Entry point, references AGENTS.md
├── Makefile               # Vendored generic template (ariadne base.manifest)
├── Makefile.workflow      # Issue-based workflow + .openshell/.tart auto-includes
├── Makefile.local         # Repo-specific targets: UPSTREAM_* overrides,
│                          #   -include Makefile.nous chain (for nous consumers),
│                          #   anything not in the vendored base
├── scripts/               # Automation scripts supporting Makefile
├── .claude/
│   ├── settings.json      # Merged from settings.ariadne.json + settings.local.json
│   └── skills/            # Skill definitions (superpowers, fix, construct, local)
├── construct/
│   ├── local/             # Local-origin skill sources
│   └── scripts/           # Construct automation (sync-local-skills.sh)
├── .openshell/            # Sandbox (Linux container dev env, vendored)
├── .tart/                 # Tart-VM targets + helpers (macOS VM testing, vendored)
├── workshop/
│   ├── issues/            # Active work
│   ├── plans/             # Detailed designs
│   ├── history/           # Archived completed work
│   ├── vision/            # Thinking artifacts (pensive docs)
│   └── staging/           # Scratch space
├── atlas/                 # Sketch-level documentation
│   └── workflow/          # Documents this workflow system
└── ...                    # Repo-specific code
```

## Vendored vs. repo-specific

Files listed in ariadne's `construct/base.manifest` (`Makefile`,
`Makefile.workflow`, `.openshell/`, `.tart/`, `scripts/`, etc.) are
**owned by ariadne** — refreshing replaces them. Per-repo concerns go in
`Makefile.local`, `AGENTS.local.md`, `.claude/settings.local.json`,
none of which are touched by setup.sh.

A repo's "shape" is the vendored skeleton plus its `*.local.*` layer.
Anything that needs to live in a vendored file but is *only* meaningful
in one repo (e.g., `UPSTREAM_NAME := nous` for nous's self-refresh)
belongs in the local layer, not in the vendored copy.

## What each directory signals

- **workshop/**: "this is process, not product" — safe to ignore for code review
- **atlas/**: "this is the map, not the territory" — read for orientation, not specification
- **construct/**: "this manages the skill system" — meta-tooling
- **scripts/**: "this supports the Makefile" — automation glue
