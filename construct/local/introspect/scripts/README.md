# introspect-extract: UNIX kit

Composable building blocks for postmortem taste-extraction over Claude Code transcripts. No build-time LLM coupling — every step emits text on stdout, and you choose which model to send it to.

## Pipeline

```
~/.claude/projects/*.jsonl
        │
        ▼  normalize.py
sessions.json (one row per segment)
        │
        ▼  classify.py (legacy rule pass) OR LLM-direct via skill body
classified.json (segment → activity)
        │
        ▼  segment_text.py + prompts/extract.md
patterns per segment (JSON)
        │
        ▼  prompts/cluster.md
clusters per activity (JSON)
        │
        ▼  draft generator (skill body)
~/.claude/skills/introspect-<activity>/SKILL.md
```

Stages 3.5 (per-segment extraction) and 4 (clustering) are the *new* primary primitive in v1.1, replacing the heuristic detectors in `detect.py`. `detect.py` and `view_moments.py` are retained as reference baselines.

## The three prompts

- **`prompts/extract.md`** — system prompt for per-segment extraction. The LLM reads one segment and emits 0–N candidate patterns as JSON.
- **`prompts/cluster.md`** — system prompt for cross-segment clustering. The LLM reads many candidate patterns and groups them into rules.
- **`prompts/retirement_check.md`** — system prompt for the per-hint contradiction probe (issue#19). The LLM gets `{rule, patterns}` and emits `{contradicts, evidence}`.

All three are plain markdown files. Read them, edit them, replace them. They're not load-bearing in any code path — only the skill body and the user reach for them.

## The chunk extractor

`segment_text.py` emits one segment's transcript as human-readable text on stdout. It does not call any LLM.

```
# render one segment
segment_text.py --cache-dir <run-dir> --segment 84afbb05#4

# list all segments (id <TAB> activity, one per line)
segment_text.py --cache-dir <run-dir> --list

# list filtered to one activity
segment_text.py --cache-dir <run-dir> --list --activity implementation

# short or full segment id both accepted
segment_text.py --cache-dir <run-dir> --segment 84afbb05-...#s4   # full
segment_text.py --cache-dir <run-dir> --segment 84afbb05#4         # short
```

Output format: light markdown — `== role @ ts ==` turn delimiters, `[tool: NAME ...]` tool-use lines, `[tool_result ...]` truncated results, with header carrying activity / cwd / branch / shape / closing-recap.

Long assistant text is summarized (first 1500 + last 500 chars). Tool results are capped at 600 chars. A typical 30-minute segment renders to 5–30k tokens.

## Composition examples

### Claude Code CLI

```bash
RUN=~/.claude/introspect/cache/<run-id>
SEG=84afbb05#4

# pipe both system prompt and chunk in one shot (--print = headless)
{
  cat ~/workspace/ariadne/construct/local/introspect/prompts/extract.md
  echo
  echo "---TRANSCRIPT BELOW---"
  echo
  segment_text.py --cache-dir "$RUN" --segment "$SEG"
} | claude --print
```

Or with the `--system` flag (Claude Code & Claude API both accept this shape):

```bash
segment_text.py --cache-dir "$RUN" --segment "$SEG" \
  | claude --print --system "$(cat ~/workspace/ariadne/construct/local/introspect/prompts/extract.md)"
```

### Anthropic API directly (curl)

```bash
SYSTEM=$(cat ~/workspace/ariadne/construct/local/introspect/prompts/extract.md)
TRANSCRIPT=$(segment_text.py --cache-dir "$RUN" --segment "$SEG")

curl https://api.anthropic.com/v1/messages \
  -H "x-api-key: $ANTHROPIC_API_KEY" \
  -H "anthropic-version: 2023-06-01" \
  -H "content-type: application/json" \
  -d "$(jq -n --arg sys "$SYSTEM" --arg user "$TRANSCRIPT" '{
    model: "claude-opus-4-7",
    max_tokens: 4096,
    system: $sys,
    messages: [{role: "user", content: $user}]
  }')"
```

### OpenAI / Codex CLI

```bash
SYSTEM=$(cat ~/workspace/ariadne/construct/local/introspect/prompts/extract.md)
TRANSCRIPT=$(segment_text.py --cache-dir "$RUN" --segment "$SEG")

# codex CLI
codex --system "$SYSTEM" --json <<< "$TRANSCRIPT"

# or the API directly
curl https://api.openai.com/v1/chat/completions \
  -H "Authorization: Bearer $OPENAI_API_KEY" \
  -H "content-type: application/json" \
  -d "$(jq -n --arg sys "$SYSTEM" --arg user "$TRANSCRIPT" '{
    model: "gpt-5",
    messages: [
      {role: "system", content: $sys},
      {role: "user", content: $user}
    ],
    response_format: {type: "json_object"}
  }')"
```

### Gemini CLI

```bash
SYSTEM=$(cat ~/workspace/ariadne/construct/local/introspect/prompts/extract.md)
TRANSCRIPT=$(segment_text.py --cache-dir "$RUN" --segment "$SEG")

gemini --system-instruction "$SYSTEM" "$TRANSCRIPT"
```

### Local model (ollama, via your own oneshot tool)

If you have a local-model wrapper that takes a system prompt + user content, it's the same pattern:

```bash
oneshot --system "$(cat .../prompts/extract.md)" --model gemma4:e4b \
  < <(segment_text.py --cache-dir "$RUN" --segment "$SEG")
```

## Aggregating across many segments

There are two ways to aggregate per-segment outputs into a single pattern array.

### Option A — `aggregate_patterns.py` (preferred)

Run the extractor against many segments, save each LLM output to `<run-dir>/patterns/<seg-id>.json`, then:

```bash
python3 aggregate_patterns.py \
  --cache-dir "$RUN" \
  --patterns-dir "$RUN/patterns" \
  --out "$RUN/patterns.json"
```

The aggregator:
- Strips ` ```json … ``` ` markdown fences if the model wrapped its output.
- Skips files that don't parse, with a stderr warning. (Re-run the model on those.)
- Skips patterns missing required fields (`summary`, `evidence_excerpt`).
- Adds a stable `id` to each pattern (`p_<10-hex>` hash of segment + summary + ts).
- Decorates each pattern with `segment_id` and `activity` from `classified.json`.
- Emits one combined JSON array, ready to feed to `prompts/cluster.md`.
- Writes a sidecar `<out>.summary.json` with file/pattern counts.

Filename convention: `<seg-id-with-#-and-/-replaced-by-_>.json`.

### Option B — pure jq one-liner

```bash
RUN=~/.claude/introspect/cache/<run-id>
PATTERNS=/tmp/patterns.jsonl

> "$PATTERNS"
segment_text.py --cache-dir "$RUN" --list --activity implementation \
  | cut -f1 | while read sid; do
      out=$(
        segment_text.py --cache-dir "$RUN" --segment "$sid" |
        claude --print --system "$(cat .../prompts/extract.md)"
      )
      jq -c --arg sid "$sid" --arg act "implementation" \
        '.patterns[] | . + {segment_id: $sid, activity: $act}' <<< "$out" \
        >> "$PATTERNS"
    done

jq -s '.' "$PATTERNS" \
  | claude --print --system "$(cat .../prompts/cluster.md)" \
  > /tmp/clusters.json
```

Less robust than Option A (no fence stripping, no field validation, no stable ids) but useful if you want a one-screen recipe.

## Full pipeline: `introspect-extract.sh`

For the all-the-way-through happy path, the controller chains it:

```bash
introspect-extract.sh <run-dir> [--activity NAME ...] [--limit N] [--force]
```

What it does:
1. Lists target segments (filtered by `--activity` if given; defaults to all six in-taxonomy activities).
2. For each, renders with `segment_text.py` and pipes to the configured extract LLM. Caches the output to `<run-dir>/patterns/<seg-id>.json` so re-runs skip already-processed segments.
3. Runs `aggregate_patterns.py` to build `<run-dir>/patterns.json`.
4. Pipes the aggregated array to the configured cluster LLM. Saves to `<run-dir>/clusters.json`.
5. Unions human hints from `~/.claude/introspect/hints/` via `read_hints.py --merge-into` (issue#19). Each hint becomes its own singleton cluster tagged `source: "hint"`.
6. Runs `hint_retire_check.py` to probe each hint against same-activity patterns; flagged hints get `retirement_candidate: true` + `contradicting_evidence`.

Default model: `claude --print --system "$1"`. Override via env vars at invocation time:

```bash
# OpenAI / codex
EXTRACT_LLM='codex --json --system "$1"' \
CLUSTER_LLM='codex --json --system "$1"' \
  introspect-extract.sh ~/.claude/introspect/cache/<run-id>

# Gemini
EXTRACT_LLM='gemini --system-instruction "$1"' \
CLUSTER_LLM='gemini --system-instruction "$1"' \
  introspect-extract.sh ~/.claude/introspect/cache/<run-id>

# Local model via your own wrapper
EXTRACT_LLM='oneshot.sh gemma4:e4b "$1"' \
  introspect-extract.sh ~/.claude/introspect/cache/<run-id> --activity debugging --limit 5

# Use a cheap model for the retirement probe (one call per hint, no need for big-model power)
PROBE_LLM='claude --print --system-prompt "$1" --tools "" --model haiku' \
  introspect-extract.sh ~/.claude/introspect/cache/<run-id>
```

The env-var contract: each is a full shell command that takes the system prompt as `$1` and reads user content from stdin. The controller passes them to `bash -c`. Three knobs:
- `EXTRACT_LLM` — per-segment pattern extraction (high volume, big model OK).
- `CLUSTER_LLM` — cross-segment clustering (one call per run, big model worth it).
- `PROBE_LLM` — hint retirement check (one call per hint, **cheap model fine**).

Cancel-safe: per-segment outputs are written individually. Ctrl-C, then re-run, and it picks up where it left off. Use `--force` to re-extract everything.

Cheap dogfood: `--limit 3` lets you sanity-check end-to-end against a couple segments before paying for the full corpus.

## Why this shape

- **Text in, text out.** Composable with grep, jq, head, tail, parallel, anything else.
- **Model-agnostic.** Swap the model by changing one word in your shell line.
- **No hidden state.** Cache dir + prompt file + segment id is the entire input.
- **Reviewable.** `segment_text.py` output is human-readable; you can scan a chunk before sending to confirm what the LLM will see.
- **Cheap to iterate on the prompt.** Tweak `prompts/extract.md`, re-run, diff outputs.

## Backstory: v1.0 → v1.1 pivot

The v1.0 design used four heuristic detectors (redirect / endorsement / edit-after-edit / friction) plus rule-based clustering. Dogfood on a 2-week corpus produced 181 moments and **0 clusters** — the heuristics were too narrow for the corpus density. v1.1 swaps that primary primitive for LLM-direct extraction. See `workshop/plans/000018-...-plan.md` revision header for the full reasoning.

`detect.py`, `view_moments.py`, and `classify.py` are kept as baselines for inspection / debugging / future-comparison, but they're no longer load-bearing in the canonical flow.
