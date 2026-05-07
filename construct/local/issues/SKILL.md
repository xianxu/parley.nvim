---
name: xx-issues
description: "Use when editing issues in workshop/issues/."
---

# Issues

Create and manage issues in `workshop/issues/` with consistent format.

## Usage

```
/xx-issues create <slug>
/xx-issues close <id>
```

Or invoked automatically when you are about to create an issue file.

## Issue File Format

Every issue file MUST follow this structure:

### Filename

`workshop/issues/NNNNNN-<slug>.md` — zero-padded 6-digit ID, kebab-case slug.

To determine the next ID, find the highest existing ID in `workshop/issues/` and `workshop/history/` and increment by 1.

### Template

```markdown
---
id: NNNNNN
status: open
deps: []
github_issue:
created: YYYY-MM-DD
updated: YYYY-MM-DD
estimate_hours:    # optional at create; required when status flips to working
actual_hours:      # required when status flips to done
---

# <Title>

## Problem

<What's wrong or what's needed>

## Spec

<Desired behavior, constraints, design decisions>

## Plan

- [ ] <step>

## Log

### YYYY-MM-DD — session summary
<one paragraph per major sitting (or milestone close): what was
attempted, what landed, what got deferred, in-flight design
decisions worth remembering. Replaces "you'd have to read
transcripts" with explicit handoff to future-you / future agent.>

### YYYY-MM-DD
<dated entries for individual decisions, discoveries, side-quests
that don't fit a session-summary block>

## Side quests
<optional; recommended for multi-day issues. One line per
unbudgeted-but-shipped piece of work — name + ~time + commit ref.
Example:

  - Makefile dev-unsign rule (~30 min) — `802c1bf`
  - OSC 8 hyperlinks on catalog URLs (~40 min) — `cb98234`

Pairs with the `side-quest:` commit verb (see ariadne AGENTS.md
§12). Lets retrospective + velocity calibration count effort that
otherwise dissolves into the diff.>
```

### Frontmatter Fields

| Field | Required | Values |
|-------|----------|--------|
| `id` | Yes | 6-digit zero-padded integer matching filename |
| `status` | Yes | `open`, `working`, `blocked`, `done`, `wontfix`, `punt` |
| `deps` | Yes | List of issue IDs this depends on, e.g. `[000005]` |
| `github_issue` | No | GitHub issue number if linked |
| `created` | Yes | ISO date |
| `updated` | Yes | ISO date |
| `estimate_hours` | When status≥working | Single integer (P50 of estimate range). Pulled from a `## Estimate` section if one exists; produced by the velocity skill or equivalent. Empty when an estimate hasn't been done yet (e.g., status=open). |
| `actual_hours` | When status=done | Required at close. Feel-time across the issue's commit window, including side-quests it triggered. Without this the velocity calibration loop cannot close — see ariadne AGENTS.md §4 + §5 closing checklist. |

### Required Sections

- **Problem** — what's wrong or needed (for bugs/features) or **Context** (for tasks)
- **Spec** — desired behavior, can start empty with `*(to be filled)*`
- **Plan** — checkable items, update as work progresses
- **Log** — dated entries tracking decisions, discoveries, progress. Use a `### YYYY-MM-DD — session summary` heading for major-sitting wrap-ups (one paragraph each); plain `### YYYY-MM-DD` for individual entries.

### Optional Sections

- **Estimate** — present when the issue was estimated. Carries the headline range, provenance string (which version-pair of the estimator produced it), and decomposition. See ariadne AGENTS.md §4 for the paired-versioned-files pattern.
- **Side quests** — recommended for multi-day issues that trigger unbudgeted work. One line per item: name + ~time + commit ref. Pairs with the `side-quest:` commit-verb convention (ariadne AGENTS.md §12).

## Process

### Creating an issue

1. Scan `workshop/issues/` and `workshop/history/` for the highest existing ID
2. Increment by 1 for the new ID
3. Create the file using the template above
4. Fill in Problem/Context section at minimum

### Updating an issue

- Set `updated` date in frontmatter when making changes
- Mark plan items complete as work finishes
- Add dated log entries for significant progress or decisions
- Update `status` field to reflect current state

### Closing an issue

Run the **closing checklist** from ariadne AGENTS.md §5 in one sweep — partial closure causes status drift across artifact layers. Specific to this skill:

- Set `status` to `done` (or `wontfix`/`punt`)
- Update the `updated` date
- **Record `actual_hours: <N>` in the frontmatter.** REQUIRED at `done`. Feel-time across the issue's commit window, including side-quests the issue triggered. Without this the velocity calibration loop cannot close. (`wontfix`/`punt` issues don't need this — there's no work to record.) See **Determining `actual_hours`** below.
- Add a final `### YYYY-MM-DD — session summary` entry to the `## Log` if the closing session covered more than the last commit's worth of work.
- If a `## Side quests` section exists, double-check it's complete — grep `git log --grep "side-quest:" <commit-range>` to confirm.
- Do NOT move the file to `workshop/history/` — that happens during periodic cleanup, not at close.

If the issue is part of a multi-issue project (see `construct/datatype/project.md`), also update the parent project file: tick the corresponding task, fill in the detail block's `**actual:** <N>` and `**closed:** <date>`. The project file is the portfolio view; if it lags the issue, the operator can't see real status when they reopen the project days later.

#### Determining `actual_hours`

For issues finished in a single session, eyeball the session's start/end and subtract idle gaps. For issues spanning multiple sessions — common, since chat history is scattered across one `.jsonl` per session and possibly across multiple repos' transcript dirs — follow this procedure. **Start with git, then cross-check with the current session's transcript.**

1. **Anchor the commit window from git.** The issue's first and last commits frame it. Issue numbers appear at the start of subjects (`#15 M2: ...`):
   ```sh
   git log --all --grep "^#<N>" --pretty=format:"%ai %s" --reverse
   ```
   First line's timestamp = window start; last line's = end. Pad both ends by ~30 min (work happens before commits land; cleanup after). Side-quest commits (`side-quest:` prefix) made during the issue's life count too — `git log --grep "^#<N>\|side-quest:" --since=<start> --until=<end>` gives a sanity-check union.
2. **Identify which transcript dirs to scan.** A session that worked on the issue lives under `~/.claude/projects/-Users-xianxu-workspace-<repo>/`. Always include the repo where the issue lives. Include `brain` if cross-cutting state was touched. Include any peer repo whose tree was edited in the commit window (`git log --name-only ...` will reveal it).
3. **Run `active-time.py` against the window.** It ships alongside this SKILL.md:
   ```sh
   python3 ~/workspace/ariadne/construct/local/issues/active-time.py \
       --dir ~/.claude/projects/-Users-xianxu-workspace-<repo> \
       --dir ~/.claude/projects/-Users-xianxu-workspace-brain \
       --since <start-date> --until <end-date> \
       --issue <N>
   ```
   Use the **UNIFIED WALL-CLOCK** number (per-session sum double-counts when sessions ran in parallel — worktree/pair workflow). When multiple issues shared the window, pass each as `--issue` and read the mention-weighted attribution. Round to integer hours.
4. **Side-validation: inspect the current session.** The closing session's transcript (`~/.claude/projects/-Users-xianxu-workspace-<repo>/<this-session>.jsonl`) is the easiest to spot-check. Look at the first user message that mentioned the issue and the last user message before close — the wall-clock span (minus obvious idle gaps) should roughly match the script's contribution from this session. If they disagree by more than ~30%, investigate before recording: the regex may have missed a session that referred to the issue obliquely, or the commit window was wrong.

## Rules

- Always use the YAML frontmatter — it enables tooling and search
- Keep slugs short and descriptive (3-5 words)
- Use `deps` to express blocking relationships between issues
- Log section is append-only — don't edit past entries
