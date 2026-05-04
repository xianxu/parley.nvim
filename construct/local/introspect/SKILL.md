---
name: xx-introspect
description: Use when the user wants to extract reusable taste signals from past Claude Code sessions, author a strong human hint to seed a future extraction, or load a previously-extracted activity-typed introspect skill. Invoked as `/xx-introspect extract` (run the postmortem extraction pipeline), `/xx-introspect hint` (author/list/retire human hints), or `/xx-introspect load` (load introspect-<activity> matching the current session). Operates on `~/.claude/projects/*.jsonl` transcripts; all outputs land in user-global `~/.claude/introspect/`. See `workshop/issues/000018-...md` and `000019-...md` for full design context.
---

# xx-introspect — postmortem introspect extraction

Three subcommands:
- `/xx-introspect extract` — run the extraction pipeline against accumulated transcripts.
- `/xx-introspect hint` — author, list, or retire human-authored hints that act as strong, single-shot seeds in the next cluster pass.
- `/xx-introspect load` — detect the current session's activity and load the matching `introspect-<activity>` skill.

## Operating principle

**The orchestrating Claude (you, in the user's session) executes every command on the user's behalf and surfaces every model judgment to the user for approval before writing.** This skill is about extracting the user's taste — not Claude's. Don't run silent disambiguation, silent clustering, or silent file writes. Don't ask the user to copy-paste shell invocations either; you have the Bash tool, run them yourself.

The only steps that don't need user approval are deterministic, no-op-on-failure reads (normalize, classify, detect, view). Everything that involves judgment (3a disambiguation, 5 clustering, 6 drafting) or that writes user-facing artifacts (7 write-back) is a checkpoint where the user decides.

## Storage layout (all user-global)

```
~/.claude/skills/introspect-<activity>/SKILL.md  # produced output, loaded on demand
~/.claude/introspect-state.json                  # run history + processed-session pointers
~/.claude/introspect/cache/<run-id>/             # intermediate stages of one run
~/.claude/introspect/hints/<activity>/<slug>.md  # human-authored hints (issue#19)
~/.claude/introspect/versions/vN/                # post-run snapshots for diffing
~/.claude/settings.json                    # permission entries written here
```

## `/xx-introspect extract`

### 1. Scope picker

Ask the user which transcripts to read. Three options:

```
[1] current repo  → ~/.claude/projects/<repo-slug-of-cwd>/*.jsonl
[2] all projects  → ~/.claude/projects/*/*.jsonl
[3] select        → list project dirs, user picks subset
```

If `cwd` doesn't have a corresponding `~/.claude/projects/<slug>/` (slug = cwd path with `/` → `-`), `current repo` is unavailable and the user must pick from `all` or `select`.

For dogfood/testing, the user may pass an explicit slug: `/xx-introspect extract --project charon` (resolves to `-Users-xianxu-workspace-charon`).

### 2. Run normalize

```
python3 $REPO_ROOT/construct/local/introspect/scripts/normalize.py \
  --scope <choice> \
  [--project <slug>] \
  [--cwd "$PWD"]                   # only when --scope current; defaults to os.getcwd()
  [--since <last_run_at-from-state>] \
  --out ~/.claude/introspect/cache/<run-id>/
```

Outputs:
- `sessions.json` — one record per session: id, start, end, cwd, gitBranch, message counts, tool counts, slash commands invoked, files touched
- `run.json` — meta-record of the run (scope, projects, file/event counts, since filter)

A flat `events.jsonl` stream will be added in M2/M3 once detectors need to walk events outside of session aggregates. Until then the raw JSONL files remain the source of truth for downstream stages.

Run-id format: `YYYYMMDDTHHMMSS`.

### 3. Activity classify (LLM-direct, with user in the loop)

Postmortem runs are infrequent (weekly/biweekly), so we classify with model judgment rather than rules. The previous rule-based pass added precision overhead without enough recall to justify the maintenance — the rules under-classified by ~60% on the dogfood corpus and missed systematic categories like "user laying out a product vision is brainstorming" and "first-message-is-an-error-trace is debugging."

The orchestrating Claude classifies every session in `sessions.json` directly:

**Procedure:**
1. Load `sessions.json`. For each session record, gather: `first_user_message`, `slash_commands`, `tool_calls_by_name`, file write/edit/read counts, user/assistant message counts.
2. Skip rows where `assistant_message_count == 0` — emit `activity: "skip"`, `skip_reason: "no assistant messages"`. These are degenerate sessions.
3. For every remaining row, reason about the activity bucket. Legal values: `code-review`, `brainstorming`, `planning`, `debugging`, `implementation`, `exploration`, `out-of-scope` (personal/non-code), `ambiguous` (genuinely uncertain).
4. **Heuristic priority:**
   - First user message is the *primary* intent signal. A long session that started as "walk me through X" is exploration, even if 100 file edits happened later.
   - Slash commands like `/security-review`, `/review`, `/ultrareview` are strong code-review markers when they're the originating intent (not a sub-task within a longer session).
   - Error trace / failure message as the first user content → debugging.
   - "Let's create / brainstorm / what if we" + product or feature exposition → brainstorming.
   - "Work on issue#N" / "implement X" / "fix the bug in Y" → implementation.
   - "How do I X" / "tell me about X" / "check Y" → exploration.
   - Travel, personal life, non-code → out-of-scope.
   - When uncertain: leave as `ambiguous`. Precision over recall — `ambiguous` rows are filtered out of clustering downstream, which is the right outcome when we don't trust the bucket.
5. Present the proposed table to the user. One row per session: short id, project, first-user-message excerpt, proposed activity, one-line rationale.
6. Accept user overrides (accept-all, accept-with-edits, or per-row overrides).
7. Atomically write to `<run-dir>/classified.json`:
   - `confidence: "llm"` for rows accepted as-proposed
   - `confidence: "user"` for rows the user overrode
   - `confidence: null` for `skip` rows
8. **Skip downstream:** Stage 4+ filters `skip`, `out-of-scope`, and `ambiguous` rows. They don't contribute moments to any `introspect-<activity>` skill.

**`scripts/classify.py` (legacy):** the rule-based scorer is retained in the repo as a baseline reference but is no longer part of the canonical flow. It's fine to consult it for a quick sanity check, but don't rely on it for the classified.json that drives downstream stages.

### 4. Moment detection

```
python3 $REPO_ROOT/construct/local/introspect/scripts/detect.py \
  --cache-dir ~/.claude/introspect/cache/<run-id>/
```

Walks the raw JSONL for each non-skip session in `classified.json`, runs four detectors, emits `moments.jsonl` (one record per line) plus `moments-summary.json`.

**Detector types:**
- `redirect` — user negates/redirects after assistant action
- `endorsement` — user reacts positively to assistant action
- `edit-after-edit` — assistant re-edits same file ≥3 times within 5-turn window with no user message between (one moment per file with count, not per pair)
- `friction` — same tool gets ≥3 explicit errors (`is_error: true` or `Exit code N` + friction-keyword)

Two more detectors (`taste-fingerprint` requires git-diff correlation; `process-shape` requires cross-session aggregation) are deferred.

Each moment carries `{session_id, project_slug, activity, type, ts, weight, evidence}`. The `evidence` shape is type-specific.

### 5. Interactive cluster walkthrough (in-session, with the user)

This stage is a guided conversation. Do not write code that auto-clusters. The point of v1 is to build user-confirmed clusters by hand so we know what *should* group together before automating.

**Preconditions:**
1. Stage 3a has run. After 3a, rows have one of: a six-taxonomy activity, `out-of-scope`, `unknown`, `ambiguous`, or `skip`. **`ambiguous` is allowed to persist** — for any row where the user (or you reasoning on their behalf) couldn't confidently pick a bucket, leaving it ambiguous is correct. Precision over recall: clustering operates on signal we trust, not signal we hope.
2. `out-of-scope`, `unknown`, `ambiguous`, and `skip` rows are all filtered out before the cluster loop begins. Their moments are excluded from any `introspect-<activity>` skill draft.

**Iteration order: outer loop is activity, inner loop is type.**

Process each in-taxonomy activity in descending session-count order (most data first). Within each activity, walk type buckets in this order — highest taste signal first:

1. `redirect` — explicit user correction
2. `friction` — actionable tool/permission failures
3. `endorsement` with `weight=2` — tool-backed acceptance (skip `weight=1` text-only rows in v1)
4. `edit-after-edit` — only cluster if a recurring file/area pattern is visible

Skip `(activity, type)` buckets that have fewer than 3 moments OR fewer than 2 distinct sessions — see "Skip thresholds" below.

**Pagination loop:**

For each `(activity, type)` bucket with ≥3 moments:

```
python3 $REPO_ROOT/construct/local/introspect/scripts/view_moments.py \
  --cache-dir <run-dir> \
  --activity <activity> \
  --type <type> \
  --limit 12
```

Read the page. For each page, propose 1-3 candidate cluster names that group similar moments, citing moment IDs. Format:

```
Cluster proposal 1: "user pushes back when assistant assumes file structure without checking"
  evidence: [m_4c6e82bd4b, m_1bfd21350a, m_4b20568e3c]
  rule sketch: Before writing to a path, verify the file exists and the
    enclosing directory layout matches what the user expects.
```

Ask the user to: (a) accept, (b) merge with another proposal, (c) split off a moment, (d) discard. After each page, page forward (`--offset`) until the bucket is exhausted.

**Cross-bucket merging:** at the end of an activity (after walking all four types), ask the user whether any cross-type clusters within this activity should merge (e.g., a `redirect` cluster about "verify before writing" and a `friction` cluster about Bash permission failures might both signal "check before acting"). Merged clusters keep one combined `moment_ids` list and stay assigned to the current activity — there is no cross-activity merging in v1, since each activity will produce its own `introspect-<activity>` skill anyway.

**Persist clusters:** at end of each activity, write the accepted cluster set to `<run-dir>/clusters/<activity>.json`:

```json
{
  "activity": "implementation",
  "clusters": [
    {
      "id": "c_impl_1",
      "name": "...",
      "rule_sketch": "...",
      "moment_ids": ["m_4c6e82bd4b", "m_1bfd21350a", ...],
      "moment_count": 3,
      "session_count": 2
    }
  ]
}
```

**Skip thresholds:**
- Skip clusters with fewer than 3 moments OR fewer than 2 distinct sessions. Per plan: three independent corrections of the same shape = a rule candidate. Two from one session = within-session correction, not yet a recurring pattern.

**Hint-aware ordering (issue#19).** When reviewing the v1.1 `clusters.json` produced by `introspect-extract.sh`, hint-sourced clusters (`source: "hint"`) bypass the threshold check — each is its own pre-formed cluster the user already endorsed by authoring. Surface them to the user **first**, in this order:

1. **Hints flagged as retirement candidates** (`retirement_candidate: true`). Show the hint's rule alongside the `contradicting_evidence` excerpts. Three actions:
   - **Keep** — ignore the contradiction, hint stays.
   - **Edit** — open `~/.claude/introspect/hints/<activity>/<slug>.md`, let user revise, save.
   - **Retire** — delete the hint file (`rm ~/.claude/introspect/hints/<activity>/<slug>.md`).
   The retirement decision affects the hints/ directory directly, not just this run's clusters.json.
2. **Hints not flagged.** Display each, confirm the user still wants it rendered into the deployed SKILL.md (effectively always yes; this is a sanity check, not a real decision).
3. **Extracted clusters** (no `source` field) — proceed with the normal threshold/walk flow.

Hints are never treated as `ambiguous`. The user authored them explicitly; precision-over-recall doesn't apply.

### 6. Draft generation (in-session)

For each activity that has ≥1 accepted cluster, draft:

**`~/.claude/skills/introspect-<activity>/SKILL.md`** (only the draft — write-back is Stage 7):

```markdown
---
name: introspect-<activity>
description: Use when the current session is doing <activity> work — extracted from past sessions where the user redirected, endorsed, or struggled. Loaded by /xx-introspect load when activity is detected.
version: <N>
generated_from_run: <run-id>
generated_at: <iso-ts>
---

# Notes from past <activity> sessions

## Rule: <rule name from cluster>

<the rule, written as a directive to a future Claude. Include the *why*
when the cluster's evidence makes it clear.>

**Evidence:** `<moment-id>`, `<moment-id>`, ... (3 moments, 2 sessions)

## Rule: <next>
...
```

**Hint-sourced rules (issue#19).** For clusters with `source: "hint"`, render with **`Source:` human hint** in place of `**Evidence:**`. Optionally include the `hint_created` date. The full block:

```markdown
## Rule: <hint name>

<hint rule body>

**Source:** human hint (authored <hint_created>)
```

This makes hint-sourced rules distinguishable from extracted ones at a glance, and means a future pipeline run reading the deployed SKILL.md can tell which rules came from hints without consulting the cache. (See "Round-trip safety" below.)


**Permission additions** (one entry per friction cluster targeting the same tool/command):

```json
{
  "permissions": {
    "allow": [
      "Bash(gh pr view:*)",
      ...
    ]
  }
}
```

Each permission entry carries an inline comment-style note in the draft showing the friction count and example error, so the user can audit.

**Provenance file:** `<run-dir>/drafts/<activity>.evidence.json` (sibling, NOT inside the SKILL.md draft — two YAML frontmatters in one file is malformed). Schema:

```json
{
  "activity": "implementation",
  "rules": [
    {
      "rule_name": "...",
      "moment_ids": ["m_4c6e82bd4b", "m_1bfd21350a", ...],
      "moment_excerpts": [
        {"id": "m_4c6e82bd4b", "type": "redirect", "session": "74cf212a", "excerpt": "..."}
      ]
    }
  ]
}
```

The user can audit any rule back to its source moments before accepting in Stage 7.

### 7. Stage 7 (write-back) — M5

Not yet implemented. After drafts are generated, present diff-style and let the user accept/reject per cluster. Accepted drafts get atomic-write to `~/.claude/skills/introspect-<activity>/SKILL.md` and `~/.claude/settings.json`.

## `/xx-introspect hint`

Author, list, or retire **human hints** — strong, single-shot signals that the next cluster pass treats as their own pre-formed cluster (bypassing the ≥2-segment threshold that gates extracted patterns). Hints are stored as small markdown files under `~/.claude/introspect/hints/<activity>/<slug>.md`. They are *eligible for retirement*, not frozen: if a future run finds transcript evidence contradicting a hint, the user is prompted at review time to keep / edit / retire it. (See issue#19 for full semantics.)

### Modes

```
/xx-introspect hint <activity> "<rule>"      # authoring mode
/xx-introspect hint                          # authoring mode, infer activity
/xx-introspect hint --list [<activity>]      # list existing hints
/xx-introspect hint --retire <slug>          # delete a hint file
```

### Authoring mode

When the user invokes `/xx-introspect hint`, with or without args:

1. **Resolve activity.**
   - If `<activity>` was passed, validate it against the five-bucket taxonomy:
     `debugging`, `exploration`, `planning`, `implementation`, `brainstorming`.
     (Note: `code-review` is a classification bucket but does not have a deployed `introspect-code-review` skill yet, so hints there have no destination — reject for now.)
   - If not passed, infer from recent in-session context: what was the user just doing? When ambiguous, ask the user.
2. **Resolve the rule body.**
   - If a rule string was passed inline, use it as the seed.
   - Otherwise, ask the user for the rule in natural language. Echo back a tightened version for confirmation. The rule should be one or two sentences, written as a directive to a future Claude.
   - Probe gently for the *why* — past incident, strong preference, or just intuition. Optional but valuable for future-you when reviewing the hint at retirement time.
3. **Derive a slug.** Lowercase-hyphenated truncation of the rule's imperative title (≤ 6 words). On collision with an existing file in the activity's hints/ dir, append `-2`, `-3`, … until unique.
4. **Draft the file** in the format below, show it to the user for one-shot confirmation, then atomically write to `~/.claude/introspect/hints/<activity>/<slug>.md`. Don't prompt again after confirmation — one round-trip.

Hint file format:

```markdown
---
activity: <one of the five buckets>
created: <YYYY-MM-DD>
---

## Rule: <imperative title>

<rule body — one or two short paragraphs, directive voice, same shape as a
rendered cluster rule.>

**Why:** <optional rationale — past incident, strong preference, etc.>
```

### List mode

`/xx-introspect hint --list` walks `~/.claude/introspect/hints/` and prints, per activity:

- File slug
- Imperative title (from the `## Rule:` line)
- Created date

`--list <activity>` filters to one activity bucket.

This is a deterministic read; no LLM call, no user approval needed. Just tabulate and print.

### Retire mode

`/xx-introspect hint --retire <slug>` deletes the matching hint file. Behaviors:

- If the slug is unique across all activities, delete and confirm.
- If ambiguous (same slug under two activities), ask which.
- If unknown, list near-matches and ask.

Retirement is hard delete — no tombstone. Re-authoring with the same slug creates a new hint with a fresh `created` date.

The same retirement effect can be achieved during cluster review (Stage 5+) when a hint surfaces as a `retirement_candidate`; this CLI form is for proactive cleanup outside a pipeline run.

### Operating principle

Hint authoring is the only `xx-introspect` flow where the orchestrating Claude writes user-global state without a multi-step user-in-the-loop — because the user has already supplied the rule explicitly, and a one-round-trip confirm-and-write is the right friction level for "I have a hint to capture, capture it."

## `/xx-introspect load`

Not yet implemented (M6). Placeholder: report "load subcommand pending — once introspect-<activity> skills exist at ~/.claude/skills/, this will detect activity and Skill-invoke the right one."

## State file schema

`~/.claude/introspect-state.json`:

```json
{
  "schema_version": 1,
  "last_run_at": "2026-04-30T18:00:00Z",
  "processed_session_ids": ["uuid1", "uuid2"],
  "runs": [
    {
      "id": "20260430T180000",
      "ts": "2026-04-30T18:00:00Z",
      "scope": "charon",
      "session_count": 6,
      "version_pointer": null
    }
  ]
}
```

Initialize as `{"schema_version": 1, "last_run_at": null, "processed_session_ids": [], "runs": []}` if the file doesn't exist.

## Key rules

- All outputs land under `~/.claude/`. Never write to repo-local `.claude/skills/` from this skill.
- Never overwrite an existing `introspect-<activity>` skill without an explicit user accept.
- The `introspect/cache/<run-id>/` directory is keep-forever for now (small JSON). M7 versioning will introduce pruning.
- For the M1 implementation, only stage 1 (normalize) runs. Stages 2-7 should be scaffolded as TODOs in the skill body, not silently no-op.
