#!/usr/bin/env python3
"""
Aggregate per-segment LLM extraction outputs into one JSON array suitable
for the clustering pass.

Reads per-segment extraction JSON files from <patterns-dir>, decorates each
pattern with `id`, `segment_id`, and `activity`, and emits the combined
array on stdout (or to --out).

Robustness:
- Strips ```json ... ``` markdown fences if the model wrapped its output.
- Skips files that don't parse as JSON, with a stderr warning.
- Skips patterns missing required fields, with a stderr warning.
- Filename convention: patterns/<segment-id-with-/-and-#-replaced-by-_>.json.
  We recover the segment id by reading sessions.json and matching by stem.

Stable pattern IDs hash (segment_id + summary[:80] + evidence_ts) so re-runs
of the same upstream call produce the same id and downstream cluster evidence
references survive iteration.

Usage:
  aggregate_patterns.py --cache-dir <run-dir> --patterns-dir <run-dir>/patterns
  aggregate_patterns.py --cache-dir <run-dir> --patterns-dir ... --out file
"""

from __future__ import annotations

import argparse
import hashlib
import json
import re
import sys
from pathlib import Path
from typing import Any

FENCE_RE = re.compile(r"^\s*```(?:json)?\s*\n(.*)\n```\s*$", re.DOTALL)


def strip_fences(text: str) -> str:
    """If model wrapped output in a ```json … ``` fence, peel it."""
    m = FENCE_RE.match(text)
    return m.group(1) if m else text


def parse_extraction(raw: str) -> list[dict[str, Any]] | None:
    """Parse one segment's extraction output. Expected shape:
    {"patterns": [...]} per prompts/extract.md. Tolerates ```json fences and
    whitespace. Returns None if unparseable."""
    text = strip_fences(raw.strip())
    if not text:
        return []
    try:
        obj = json.loads(text)
    except json.JSONDecodeError:
        return None
    if isinstance(obj, dict) and "patterns" in obj and isinstance(obj["patterns"], list):
        return obj["patterns"]
    if isinstance(obj, list):
        return obj
    return None


def filename_to_segment(stem: str, sessions_by_id: dict[str, dict[str, Any]]) -> str | None:
    """patterns/<segment_id with / and # replaced by _>.json → segment_id."""
    candidate = stem.replace("_", "#", 1)  # restore # before s<N>
    if candidate in sessions_by_id:
        return candidate
    # Multiple replacements may have happened; do a slow scan.
    for sid in sessions_by_id:
        if sid.replace("/", "_").replace("#", "_") == stem:
            return sid
    return None


def stable_pattern_id(segment_id: str, summary: str, ts: str | None) -> str:
    fp = "|".join([segment_id, (summary or "")[:80], ts or ""])
    return "p_" + hashlib.sha1(fp.encode("utf-8")).hexdigest()[:10]


def validate_pattern(p: Any) -> tuple[dict[str, Any] | None, str]:
    """Return (cleaned_pattern, error). cleaned_pattern is None on rejection."""
    if not isinstance(p, dict):
        return None, "not an object"
    summary = p.get("summary")
    excerpt = p.get("evidence_excerpt")
    if not isinstance(summary, str) or not summary.strip():
        return None, "missing or empty summary"
    if not isinstance(excerpt, str) or not excerpt.strip():
        return None, "missing or empty evidence_excerpt"
    cleaned = {
        "summary": summary.strip(),
        "shape": p.get("shape", "other"),
        "rationale": (p.get("rationale") or "").strip(),
        "evidence_excerpt": excerpt.strip(),
        "evidence_ts": (p.get("evidence_ts") or "").strip() or None,
    }
    return cleaned, ""


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--cache-dir", required=True, help="Run cache dir (for sessions.json and classified.json).")
    ap.add_argument("--patterns-dir", required=True,
                    help="Directory containing per-segment extraction JSON files.")
    ap.add_argument("--out", help="Output path (default: stdout).")
    ap.add_argument("--quiet", action="store_true", help="Suppress per-file warnings.")
    args = ap.parse_args()

    cache = Path(args.cache_dir).expanduser()
    pdir = Path(args.patterns_dir).expanduser()
    if not cache.is_dir():
        print(f"error: cache dir not found: {cache}", file=sys.stderr)
        return 2
    if not pdir.is_dir():
        print(f"error: patterns dir not found: {pdir}", file=sys.stderr)
        return 2

    sessions = json.loads((cache / "sessions.json").read_text())
    sessions_by_id = {s["session_id"]: s for s in sessions}
    classified_path = cache / "classified.json"
    activity_by_id: dict[str, str] = {}
    if classified_path.exists():
        for c in json.loads(classified_path.read_text()):
            activity_by_id[c["session_id"]] = c.get("activity", "?")

    files = sorted(pdir.glob("*.json"))
    out_patterns: list[dict[str, Any]] = []
    seen_ids: set[str] = set()
    files_total = len(files)
    files_skipped = 0
    patterns_skipped = 0

    for f in files:
        sid = filename_to_segment(f.stem, sessions_by_id)
        if not sid:
            files_skipped += 1
            if not args.quiet:
                print(f"warn: {f.name} doesn't map to any segment id, skipping", file=sys.stderr)
            continue
        try:
            raw = f.read_text()
        except OSError as e:
            files_skipped += 1
            if not args.quiet:
                print(f"warn: read failed for {f.name}: {e}", file=sys.stderr)
            continue
        parsed = parse_extraction(raw)
        if parsed is None:
            files_skipped += 1
            if not args.quiet:
                print(f"warn: {f.name} did not parse as JSON, skipping", file=sys.stderr)
            continue
        activity = activity_by_id.get(sid, "?")
        for p in parsed:
            cleaned, err = validate_pattern(p)
            if cleaned is None:
                patterns_skipped += 1
                if not args.quiet:
                    print(f"warn: {f.name} pattern rejected: {err}", file=sys.stderr)
                continue
            pid = stable_pattern_id(sid, cleaned["summary"], cleaned["evidence_ts"])
            # Dedupe within run.
            if pid in seen_ids:
                continue
            seen_ids.add(pid)
            out_patterns.append({
                "id": pid,
                "segment_id": sid,
                "activity": activity,
                **cleaned,
            })

    summary = {
        "files_total": files_total,
        "files_skipped": files_skipped,
        "patterns_total": len(out_patterns),
        "patterns_skipped": patterns_skipped,
    }
    print(
        f"# aggregate: files={files_total} skipped={files_skipped} "
        f"patterns={len(out_patterns)} pat_skipped={patterns_skipped}",
        file=sys.stderr,
    )

    payload = json.dumps(out_patterns, indent=2)
    if args.out:
        Path(args.out).expanduser().write_text(payload)
        print(f"# wrote {args.out}", file=sys.stderr)
    else:
        sys.stdout.write(payload)
        sys.stdout.write("\n")

    # Sidecar summary file alongside --out
    if args.out:
        side = Path(args.out).expanduser().with_suffix(".summary.json")
        side.write_text(json.dumps(summary, indent=2))
    return 0


if __name__ == "__main__":
    sys.exit(main())
