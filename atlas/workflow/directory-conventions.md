# Directory Conventions

## Standard layout for ariadne-managed repos

```
repo/
├── AGENTS.md              # Constitution (workflow rules, design principles)
├── CLAUDE.md              # Entry point, references AGENTS.md
├── Makefile               # Repo-specific targets + includes Makefile.workflow
├── Makefile.workflow       # Issue-based workflow targets (from ariadne)
├── scripts/               # Automation scripts supporting Makefile
├── .claude/
│   ├── settings.json      # Merged from settings.ariadne.json + settings.local.json
│   └── skills/            # Skill definitions (superpowers, fix, construct, local)
├── construct/
│   ├── local/             # Local-origin skill sources
│   └── scripts/           # Construct automation (sync-local-skills.sh)
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

## What each directory signals

- **workshop/**: "this is process, not product" — safe to ignore for code review
- **atlas/**: "this is the map, not the territory" — read for orientation, not specification
- **construct/**: "this manages the skill system" — meta-tooling
- **scripts/**: "this supports the Makefile" — automation glue
