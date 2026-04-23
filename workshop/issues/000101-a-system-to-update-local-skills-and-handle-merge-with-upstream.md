---
id: 000101
status: done
deps: []
created: 2026-04-12
updated: 2026-04-12
---

# The Construct — AI Substrate Management System

A skill-based system to manage the AI substrate (skills, constitution files) of a hermetic repo. Import external skills, adapt them via semantic intent directives, version rendered output, and re-apply intents onto new upstream versions instead of text-merging.

Named after The Matrix's Construct — where you load up what you need and reshape it.

## Done when

- The Construct skill exists at `.claude/skills/construct/SKILL.md` and can be invoked
- Can import an upstream skill (e.g., superpowers/brainstorming), snapshot source, create intent file
- Can render: source + intents → rendered SKILL.md, verified by subagent
- Can upgrade: fetch new upstream version, re-render with existing intents, verify, promote
- Versioning works: last 10 snapshots, non-AI rollback via `rollback.sh`
- Mechanical scripts are tested and reliable
- Constitution files (AGENTS.md, CLAUDE.md) are versioned alongside skills

## Spec

**Core insight:** Store the intent, not the patch. Re-apply intent onto each new upstream version.

Textual merge of English documents produces plausible but potentially incoherent results. Instead, record *why* each local change was made (as what/why/verify directives), then have AI re-apply those intents from scratch onto new upstream versions.

**What it manages:**
- Skills (imported from upstream + local-origin)
- Constitution files (AGENTS.md, CLAUDE.md) — local-origin, versioned and rollback-able but not rendered through source+intent pipeline unless an upstream template is adopted

**Key concepts:**
- **Sources** — frozen upstream snapshots, versioned (fetched from `~/.claude/plugins/cache/` for Claude Code plugins)
- **Intents** — per-skill mutation directives with what/why/verify clauses. Specific to each target skill (not generic). Applied holistically (AI reads whole intent file as a unit). Must be internally consistent.
- **Rendering** — AI reads all source files + intent → produces all output files. Verify subagent (fresh context) checks against verify clauses. Max 3 attempts; on failure, abandon and keep previous version.
- **Versioning** — last 10 snapshots. Directories named `NNNN` or `NNNN-slug` (slug optional for annotation). Pruning at promotion time.
- **Promotion** — staging passes verification → becomes current. No baking period.
- **Rollback** — non-AI shell script, works without Construct being functional.

**Detailed design:** `workshop/plans/000101-construct-plan.md`

## Plan

- [x] Update design doc with review feedback (C1, C2, I1, I2, I4, I5, M3, M5 fixes)
- [x] Write `rollback.sh` — standalone non-AI revert script
- [x] Write the Construct SKILL.md — orchestrates all operations using standard tools
- [x] Bootstrap: import superpowers/brainstorming as first managed skill (source snapshotted, intent written, rendered to staging, verified)
- [x] Privacy setup — construct lives in ariadne, symlinked into parley via setup-construct.sh
- [ ] Promote brainstorming — verify diff, promote staging to v0001
- [ ] Verify rollback works
- [ ] Update atlas/

## Log

### 2026-04-12

- Brainstormed design with user
- Key decisions:
  - "Store intent, not patch" — semantic re-apply instead of text merge
  - Per-skill intents (not generic) — "spec" means different things in different skills
  - Hermetic repo model — skills vendored in, not referenced externally (aligns with Ariadne vision)
  - Versioning with last 10 snapshots + non-AI rollback for safety
  - Scripts for mechanical parts (tested, rigid), Construct skill for semantic parts (AI, flexible)
  - No baking period — promote on verify pass, rollback is cheap
  - Constitution files (AGENTS.md, CLAUDE.md) are local-origin for now, versioned but not rendered through intent pipeline
- Design written to `workshop/plans/000101-construct-plan.md`
- Spec review completed, findings addressed
- Note: bootstrapping in parley.nvim, will migrate to ariadne repo at cutover

### 2026-04-13

- Key design evolution:
  - Intents are conversation transcripts, not distilled specs — transcripts survive upstream restructuring because they describe behavior, not location
  - `/construct adjust` (renamed from adapt) + `/construct promote` (separate) — never auto-promote
  - `/construct diff` added — uses `git diff --no-index` for familiar output
  - Simplified to single script (rollback.sh) — all other operations are AI-driven using standard tools
  - `construct/` lives at repo top level (like atlas/), not under `.claude/`
  - Future direction: AGENTS.md → skill tree decomposition (no structural changes needed for v1)
- Privacy decision: construct lives in ariadne (private), symlinked into parley
  - `scripts/setup-construct.sh` creates symlinks
  - `.gitignore` excludes `construct` and `.claude/skills/construct`
- Implementation:
  - Wrote rollback.sh (in ariadne/construct/)
  - Wrote Construct SKILL.md (in ariadne/construct/skill/)
  - Imported superpowers/brainstorming v5.0.2 source
  - Wrote intent transcript for brainstorming adaptation
  - Rendered adapted brainstorming to staging
  - Verified by subagent: 9/9 pass (after fixing stale path in spec-document-reviewer-prompt.md)
  - Ready for promotion
