# The Construct — AI Substrate Management System

**Issue:** #000101
**Date:** 2026-04-12
**Status:** Draft

---

## Problem

AI-first hermetic repos depend on a substrate of markdown artifacts (skills, constitution files) that instruct AI behavior. These artifacts come from upstream sources (e.g., superpowers plugin) and get customized locally. When upstream updates, local customizations must be preserved. Textual merge of English documents produces plausible but potentially incoherent results — there's no compiler to catch semantic inconsistency.

## Core Insight

**Store the intent, not the patch. Re-apply intent onto each new upstream version.**

Rather than merging text, the Construct records *why* each local change was made, then re-applies those intents from scratch onto new upstream versions. The AI reads the whole new version and produces a coherent document, rather than splicing two versions together.

## What It Manages

- **Skills** — imported from upstream (e.g., superpowers) or created locally
- **Constitution files** — AGENTS.md, CLAUDE.md — local-origin for now, versioned and rollback-able but not rendered through source+intent pipeline unless an upstream template is adopted

## Key Concepts

### Sources
Frozen upstream snapshots, versioned. When upstream ships v5.1.0, we fetch and store it without modifying it. The source is the immutable input.

For Claude Code plugins (e.g., superpowers), upstream files are fetched from the local plugin cache at `~/.claude/plugins/cache/<marketplace>/<plugin>/<version>/`. The fetch script copies from there into `substrate/sources/`.

### Intents
The intent for a skill is a **conversation transcript** — the authoritative record of what behavioral changes were requested and why. This is the primary artifact, not a distilled spec.

**Why transcripts, not specs:** A distilled spec says "change section 3.2 line 42" — that breaks when upstream restructures. A transcript says "we wanted to stop the skill from opening a browser because we're terminal-only" — that intent survives any restructuring because it's about *behavior*, not *location*. The AI reading the transcript understands the *why* and can figure out the *where* in any version of the source.

**The authoring process:** `/construct adapt` is a conversation. You discuss what to change with the AI, iterate until the output is right, and the conversation itself gets saved as the intent. There is no separate "write the intent file" step — the conversation *is* the intent.

**Verify clauses** emerge naturally during the conversation ("make sure there's no mention of browser anywhere") and are captured within the transcript. A separate verify agent uses them to check rendered output.

Intents are specific to each target skill, not generic. "Spec" means different things in brainstorming vs. TDD — generic intents silently do the wrong thing. Duplication across intent files is acceptable; refactor when the pattern is clear, not before.

**Unification:** The same mechanism works for all cases:
- Adapting an upstream skill → transcript of conversation about what to change
- Creating a new skill from scratch → transcript describing what the skill should do (the intent *is* the generative spec)
- Evolving an existing skill → new conversation appended to the transcript

**Transcript growth:** As intents accumulate over months, transcripts may get long. When this happens, the natural escape is decomposing the skill into sub-skills (see Future Direction: Constitution Decomposition).

### Rendering
AI receives all source files for a skill + the intent file, and produces all output files for that skill as a unit. A separate verify agent (subagent with no prior context) checks the rendered output against the verify clauses. If verification fails, re-render with failure feedback. Max 3 attempts; after 3 failures, the render is abandoned, staging is cleared, the previous live version remains active, and the user is shown the last verification failure. The separation prevents confirmation bias.

### Versioning
Last 10 snapshots of all rendered output. Each version is a complete copy of the rendered state. Non-AI rollback script can revert to any version without AI involvement.

Version directories are named `NNNN` by default (e.g., `0001`, `0002`). Users may append a slug for annotation: `0002-broken`, `0003-pre-upstream-update`. Scripts match on the numeric prefix. Pruning happens at promotion time, always keeping the 10 most recent by numeric prefix. Annotations are cosmetic — they do not protect from pruning.

### Promotion
Rendering goes to staging. If the verify agent passes, staging is promoted: snapshot into versions, copy to live locations. No baking period — rollback cost is low enough to promote immediately.

### Rollback
Non-AI mechanism. A shell script reverts to any of the last 10 versions. When a version fails:
1. Revert immediately (non-AI)
2. Failed version stays in versions/ as evidence
3. Investigate root cause (upstream issue, bad intent, Construct bug)
4. Fix root cause, re-render → new version supersedes the failed one
5. Failed version eventually pruned when outside the 10-version window

## Directory Structure

```
construct/                          # top-level, the repo's AI substrate workspace
  manifest.md                       # index of all managed artifacts + status
  sources/
    superpowers/
      v5.0.2/                       # frozen upstream snapshot
        skills/brainstorming/SKILL.md
        skills/brainstorming/visual-companion.md
        skills/debugging/SKILL.md
        skills/debugging/root-cause-tracing.md
        ...
      v5.1.0/                       # newer upstream version
        ...
  intents/
    superpowers/
      brainstorming.md              # conversation transcript (the intent)
      debugging.md
      tdd.md
    constitution/
      agents.md                     # evolution tracking for AGENTS.md
      claude.md                     # evolution tracking for CLAUDE.md
    local/
      my-custom-skill.md            # intents for locally-created skills
  staging/                          # render target before promotion (gitignored)
    skills/brainstorming/SKILL.md
    skills/debugging/SKILL.md
    constitution/AGENTS.md
    constitution/CLAUDE.md
  versions/
    0001/                           # snapshot of rendered state
      skills/brainstorming/SKILL.md
      skills/debugging/SKILL.md
      constitution/AGENTS.md
      constitution/CLAUDE.md
      manifest.md                   # what source + intents produced this
    0002/
    ...                             # last 10 kept, older pruned at promotion
  current                           # marker: which version is active (e.g., "0003")
  rollback.sh                       # non-AI emergency revert

.claude/
  skills/
    construct/SKILL.md              # the meta-skill itself
    brainstorming/SKILL.md          # rendered output (live)
    debugging/SKILL.md              # rendered output (live)
    my-local-skill/SKILL.md         # local-origin, no upstream
```

**`construct/` is a top-level directory**, on par with `atlas/` and `workshop/`. It's a first-class concept in the AI-first repo. The Construct skill at `.claude/skills/construct/SKILL.md` is the interface; `construct/` is the workspace.

**Privacy:** The construct directory and its methodology are proprietary. In public repos (like parley.nvim), `construct/` lives in a private repo (ariadne) and is symlinked in:
- `construct/` → `../ariadne/construct` (the workspace)
- `.claude/skills/construct` → `../../../ariadne/construct/skill` (the skill file)

Both symlinks are gitignored. A setup script (`scripts/setup-construct.sh`) creates them. `rollback.sh` must be invoked through the symlink so it resolves the correct target repo.

**Staging and versions use a flat mirrored structure:** `skills/<name>/...` and `constitution/<name>`. The Construct knows the mapping to live locations (`.claude/skills/` and repo root).

**Git tracking:** Sources and versions are committed (audit trail). Staging is gitignored (ephemeral).

### Claude Code Integration

Claude Code scans `.claude/skills/*/SKILL.md` one level deep. Everything in `substrate/` is invisible to Claude Code's skill discovery. The Construct manages the boundary: `substrate/` is its workspace, `.claude/skills/` is the published output.

### Local-Origin Skills

Skills created in this repo (no upstream) live directly in `.claude/skills/` with no corresponding source or intent in `substrate/`. They are the source of truth. The versioning system still snapshots them (they're part of the rendered state), so rollback covers them too.

### Constitution Files

AGENTS.md and CLAUDE.md are local-origin. They are versioned and rollback-able through the snapshot system, but do not go through the source+intent→render pipeline. Intent files under `intents/constitution/` serve as evolution tracking (changelog of deliberate mutations with rationale), not render inputs. If an upstream template is adopted in the future, they can be promoted to fully managed artifacts.

## Intent File Format

Intent files are conversation transcripts — the record of human-AI dialogue that produced the adaptation. Example:

```markdown
# Intent: superpowers/brainstorming

## Conversation 1 (2026-04-12): Initial adaptation

User: We need to change where design docs get written. Our repo uses
workshop/plans/ as the execution space, not docs/superpowers/specs/.

AI: I'll change all references to the spec output path. The checklist step
"Write design doc" will point to workshop/plans/ and the doc commit path
will be updated accordingly.

User: Also remove the Visual Companion section entirely — we work in
terminal-only Neovim, no browser available.

AI: Removing the Visual Companion section, the "Offer visual companion"
checklist step, and all references to browser-based mockups.
The render-mockup.sh script will also be removed.

User: And add a step to update atlas/ entries after design approval.
That's mandatory per our AGENTS.md.

AI: Adding an atlas update step between "Write design doc" and
"Spec review loop" in the checklist.

### Verify
- No references to `docs/superpowers/specs/` in rendered output
- No mention of "Visual Companion", "browser", or "mockup"
- render-mockup.sh does not exist in rendered output
- Checklist includes atlas update step between "Write design doc" and "Spec review loop"
- All spec write instructions point to `workshop/plans/`
```

The verify clauses emerge from the conversation and are collected at the end. They are the acceptance criteria a separate agent checks after rendering.

### Manifest Format

Each version's `manifest.md` contains:

```markdown
# Version 0003 Manifest

Rendered: 2026-04-12T14:30:00Z

## Managed Skills

| Skill | Source | Source Version | Intent File | Verify Result |
|-------|--------|---------------|-------------|---------------|
| brainstorming | superpowers | v5.0.2 | intents/superpowers/brainstorming.md | pass |
| debugging | superpowers | v5.0.2 | intents/superpowers/debugging.md | pass |

## Constitution Files

| File | Tracked |
|------|---------|
| AGENTS.md | yes |
| CLAUDE.md | yes |

## Local-Origin Skills

| Skill |
|-------|
| construct |
| my-local-skill |
```

## Scripts

Only one standalone script exists. All other mechanical operations (fetch, place, swap, verify structure) are described as steps in the Construct SKILL.md and executed by the AI using standard tools (Read, Write, Bash, Glob). This keeps the system simple — one script to maintain, one skill file to evolve.

| Script | Purpose |
|--------|---------|
| `rollback.sh` | Emergency revert to any version. Standalone, no dependencies on Construct or AI. The only piece that must work when everything else is broken. |

## Construct Skill (Semantic, AI)

The Construct SKILL.md orchestrates the full workflow:

### Operations

**`/construct adjust <skill>`** — The primary authoring command. Starts a conversation to capture what the user wants to change. For imported skills, this adapts an existing skill. For new names (e.g., `/construct adjust new-skill`), this creates a new skill — bootstrapping the directory structure and capturing the generative conversation as the intent.

The flow:
1. Conversation with AI to understand the desired change (uses superpowers skills as needed)
2. AI renders the adjusted skill to staging
3. Show diff: staging vs. current live version (using `git diff --no-index`)
4. Extract verify clauses from the conversation
5. Dispatch verify subagent
6. User reviews diff and verify results — does NOT auto-promote

**`/construct promote <skill>`** — Promote the staged version of a skill to live. Takes a snapshot into versions, copies to `.claude/skills/`, updates manifest. Separate from adjust so the user has full control over when changes go live.

**`/construct import <source>`** — Fetch upstream, snapshot into sources, create skeleton intent file.

**`/construct upgrade <source>`** — Fetch new upstream version, re-render all skills from that source using existing intents, show diffs, verify. Does NOT auto-promote — user reviews and calls `/construct promote` for each skill.

**`/construct diff [<skill>] [<version-a>] [<version-b>]`** — Show diffs between any combination of: staging, current live, or any version number. Uses `git diff --no-index` for familiar output format. Examples:
- `/construct diff brainstorming` — staging vs. live
- `/construct diff brainstorming 0002 0003` — between two versions
- `/construct diff brainstorming 0002` — version 0002 vs. live

**`/construct status`** — Show manifest: what's managed, active version, source versions, what's in staging.

**`/construct rollback <version>`** — Revert to a previous version (calls rollback.sh).

### Render Flow (within `/construct adjust`)

```
1. Conversation with user to capture desired changes
2. Read all source files for the skill from substrate/sources/
3. Read existing intent transcript from substrate/intents/ (if any)
4. AI reads the transcript to understand behavioral intent, applies it to the
   source files, produces all rendered output files → writes to substrate/staging/
5. Show diff: git diff --no-index between live and staging
6. Extract verify clauses from conversation, append to transcript
7. Dispatch verify subagent:
   - Input: rendered output + verify clauses
   - Output: pass/fail with specifics
8. If fail → re-render with failure context → verify again (max 3 attempts)
9. If 3 failures → abandon, clear staging, keep previous version, show last failure
10. If pass → save conversation as intent transcript, staging is ready
11. User reviews diff and verify results
12. User calls /construct promote to go live (separate step)
```

The key property: because the AI reads the full transcript (behavioral intent) rather than a positional spec, rendering is robust to upstream restructuring. The AI understands *what* to change and *why*, and figures out *where* in the current source version.

### Self-Management

The Construct skill itself lives in `.claude/skills/construct/SKILL.md`. It is local-origin (no upstream) and versioned alongside everything else. If a Construct change bricks the system, `rollback.sh` restores the previous version of everything including the Construct itself.

## Failure Modes and Recovery

| Failure | Cause | Recovery |
|---------|-------|----------|
| Bad render | Intent unclear or conflicting | `rollback.sh NNNN`, fix intent, re-render |
| Upstream incompatible | Major upstream restructure | `rollback.sh NNNN`, review upstream changes, update intents |
| Construct bug | Skill itself has a defect | `rollback.sh NNNN` restores previous Construct + skills |
| Verify false positive | Verify clauses too loose | Rollback, tighten verify clauses, re-render |
| Verify false negative | Verify clauses too strict | Update verify clauses, re-render (no rollback needed) |
| Render exhaustion | 3 attempts all fail | Staging cleared, previous version stays active, user sees last failure |

## Future Direction: Constitution Decomposition

As the AI substrate grows, AGENTS.md becomes too monolithic — too large for context windows, too tangled for humans to reason about which parts apply when. The natural trajectory:

- **AGENTS.md today:** monolith covering workflow, task management, design principles, directory structure, verification, etc.
- **AGENTS.md future:** slim bootloader (identity, principles, directory structure) that points to contextual skills loaded on demand.

Each section becomes a skill: workflow-orchestration, task-management, code-quality, verification, atlas-maintenance, construct itself. These are importable, adaptable via intents, distributable individually.

This also solves distribution: instead of sharing a monolithic AGENTS.md template, you share individual skills. A new repo picks what it needs.

**No structural changes needed for v1.** The Construct already manages skills as units. Constitutional rules are just skills that happen to define repo-wide behavior rather than task-specific process. The model is ready for this decomposition when the time comes.

## Out of Scope (v1)

- Constitution decomposition (AGENTS.md → skill tree)
- MCP server management (future extension)
- Connector management (future extension)
- Multi-repo skill synchronization (future extension)
- Automatic upstream change detection (manual fetch for now)
