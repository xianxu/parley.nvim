#!/usr/bin/env python3
"""
For each hint cluster in clusters.json, run a contradiction probe against
the run's same-activity patterns and annotate the cluster with
`retirement_candidate` + `contradicting_evidence` when a contradiction is found.

Designed to be cheap: one LLM call per hint, with same-activity patterns
only (so the prompt size scales with extracted-pattern density per activity,
not with total corpus size). Hints with no patterns in their activity bucket
get skipped — there is nothing to contradict against.

Pipeline placement: after read_hints.py --merge-into. The hint clusters
already exist in clusters.json; this script mutates them in-place.

Usage:
  hint_retire_check.py --cache-dir <run-dir> [--probe-cmd 'shell command']

The probe command receives the system prompt as $1 and reads the user
content (input JSON) on stdin. Default is the same `claude --print` form
used by introspect-extract.sh's CLUSTER_LLM. Override via --probe-cmd or
the PROBE_LLM env var to point at a cheaper model — this is exactly the
shape of work where Haiku/local models are appropriate.
"""

from __future__ import annotations

import argparse
import json
import os
import re
import subprocess
import sys
from pathlib import Path
from typing import Any

PROMPT_RELPATH = "../prompts/retirement_check.md"
DEFAULT_PROBE = 'claude --print --system-prompt "$1" --tools ""'
FENCE_RE = re.compile(r"^\s*```(?:json)?\s*\n(.*)\n```\s*$", re.DOTALL)


def strip_fences(text: str) -> str:
    m = FENCE_RE.match(text.strip())
    return m.group(1) if m else text


def find_prompt(script_dir: Path) -> Path:
    p = (script_dir / PROMPT_RELPATH).resolve()
    if not p.exists():
        print(f"error: prompt not found at {p}", file=sys.stderr)
        sys.exit(2)
    return p


def load_clusters(path: Path) -> dict[str, Any]:
    if not path.exists():
        print(f"error: clusters.json not found at {path}", file=sys.stderr)
        sys.exit(2)
    obj = json.loads(path.read_text())
    if not isinstance(obj, dict) or "clusters" not in obj:
        print(f"error: clusters.json malformed at {path}", file=sys.stderr)
        sys.exit(2)
    return obj


def load_patterns(path: Path) -> list[dict[str, Any]]:
    if not path.exists():
        return []
    obj = json.loads(path.read_text())
    if isinstance(obj, list):
        return obj
    print(f"warn: patterns.json at {path} is not a list, skipping", file=sys.stderr)
    return []


def patterns_for_activity(patterns: list[dict[str, Any]], activity: str) -> list[dict[str, Any]]:
    out = []
    for p in patterns:
        if p.get("activity") != activity:
            continue
        out.append({
            "segment_id": p.get("segment_id", ""),
            "ts": p.get("evidence_ts") or "",
            "summary": p.get("summary", ""),
            "excerpt": p.get("evidence_excerpt", ""),
        })
    return out


def call_probe(probe_cmd: str, system_prompt: str, user_payload: str) -> str | None:
    """Run probe_cmd with system prompt as $1, user payload on stdin. Return stdout text."""
    try:
        result = subprocess.run(
            ["bash", "-c", probe_cmd, "_", system_prompt],
            input=user_payload,
            capture_output=True,
            text=True,
            check=False,
        )
    except OSError as e:
        print(f"error: probe command failed to launch: {e}", file=sys.stderr)
        return None
    if result.returncode != 0:
        print(f"warn: probe returned exit {result.returncode}: {result.stderr.strip()[:300]}", file=sys.stderr)
        return None
    return result.stdout


def parse_probe_response(raw: str) -> dict[str, Any] | None:
    text = strip_fences(raw.strip())
    try:
        obj = json.loads(text)
    except json.JSONDecodeError as e:
        print(f"warn: probe response did not parse as JSON: {e}", file=sys.stderr)
        return None
    if not isinstance(obj, dict) or "contradicts" not in obj:
        print(f"warn: probe response missing 'contradicts' field", file=sys.stderr)
        return None
    return obj


def main() -> int:
    ap = argparse.ArgumentParser(
        description=__doc__,
        formatter_class=argparse.RawDescriptionHelpFormatter,
    )
    ap.add_argument("--cache-dir", required=True,
                    help="Run cache dir containing clusters.json and patterns.json.")
    ap.add_argument("--probe-cmd",
                    help="Probe LLM command (default: $PROBE_LLM env, falling back to claude --print).")
    args = ap.parse_args()

    cache = Path(args.cache_dir).expanduser()
    clusters_path = cache / "clusters.json"
    patterns_path = cache / "patterns.json"

    script_dir = Path(__file__).resolve().parent
    prompt_path = find_prompt(script_dir)
    system_prompt = prompt_path.read_text()

    probe_cmd = args.probe_cmd or os.environ.get("PROBE_LLM") or DEFAULT_PROBE

    obj = load_clusters(clusters_path)
    patterns = load_patterns(patterns_path)
    hint_clusters = [c for c in obj["clusters"] if c.get("source") == "hint"]

    if not hint_clusters:
        print("# hint_retire_check: no hint clusters in clusters.json, nothing to do", file=sys.stderr)
        return 0
    if not patterns:
        print("# hint_retire_check: patterns.json empty/missing, skipping (no evidence to contradict)", file=sys.stderr)
        return 0

    flagged = 0
    skipped = 0
    for hc in hint_clusters:
        activity = hc.get("activity", "")
        same_act = patterns_for_activity(patterns, activity)
        if not same_act:
            print(f"# hint {hc.get('hint_slug', '?')}: no patterns in activity '{activity}', skipping", file=sys.stderr)
            skipped += 1
            continue

        payload = {
            "rule": {"name": hc.get("name", ""), "rule": hc.get("rule", "")},
            "patterns": same_act,
        }
        print(f"# hint {hc.get('hint_slug', '?')}: probing against {len(same_act)} pattern(s)", file=sys.stderr)
        raw = call_probe(probe_cmd, system_prompt, json.dumps(payload))
        if raw is None:
            skipped += 1
            continue
        parsed = parse_probe_response(raw)
        if parsed is None:
            skipped += 1
            continue

        if parsed.get("contradicts"):
            evidence = parsed.get("evidence") or []
            hc["retirement_candidate"] = True
            hc["contradicting_evidence"] = evidence
            flagged += 1
            print(f"#   ⚠ flagged: {len(evidence)} contradicting moment(s)", file=sys.stderr)
        else:
            # Clear any stale retirement flag from a previous run.
            hc.pop("retirement_candidate", None)
            hc.pop("contradicting_evidence", None)

    tmp = clusters_path.with_suffix(clusters_path.suffix + ".tmp")
    tmp.write_text(json.dumps(obj, indent=2))
    tmp.replace(clusters_path)
    print(
        f"# hint_retire_check: hints={len(hint_clusters)} flagged={flagged} skipped={skipped}",
        file=sys.stderr,
    )
    return 0


if __name__ == "__main__":
    sys.exit(main())
