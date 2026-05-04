#!/usr/bin/env python3
"""
Read human-authored hint files and emit them as cluster-shaped JSON.

Hints live at ~/.claude/introspect/hints/<activity>/<slug>.md and act as
strong, single-shot signals — each hint becomes its own cluster, bypassing
the ≥2-segment threshold that gates extracted patterns from the LLM
clusterer.

File format (from issue#19 / M2 spec):

    ---
    activity: <one of: debugging exploration planning implementation brainstorming>
    created: <YYYY-MM-DD>
    ---

    ## Rule: <imperative title>

    <rule body — one or two paragraphs>

    **Why:** <optional rationale>

Output cluster shape (matches prompts/cluster.md output but with extra
provenance fields):

    {
      "activity": "<from frontmatter>",
      "name": "<imperative title>",
      "rule": "<body, with Why folded in if present>",
      "source": "hint",
      "hint_slug": "<filename stem>",
      "hint_created": "<YYYY-MM-DD>",
      "evidence": []
    }

The absence of a `source` field on extracted clusters is the discriminator —
no need to retro-tag them.

Usage:
  read_hints.py [--hints-dir DIR] [--activity ACT ...] [--out FILE]
  read_hints.py --merge-into clusters.json    # union with extracted clusters
"""

from __future__ import annotations

import argparse
import json
import re
import sys
from pathlib import Path
from typing import Any

DEFAULT_HINTS_DIR = Path("~/.claude/introspect/hints").expanduser()
VALID_ACTIVITIES = {
    "debugging",
    "exploration",
    "planning",
    "implementation",
    "brainstorming",
}

FRONTMATTER_RE = re.compile(r"^---\s*\n(.*?)\n---\s*\n", re.DOTALL)
RULE_HEADING_RE = re.compile(r"^##\s+Rule:\s*(.+?)\s*$", re.MULTILINE)
WHY_RE = re.compile(r"\*\*Why:\*\*\s*(.+?)\s*\Z", re.DOTALL)


def parse_frontmatter(text: str) -> tuple[dict[str, str], str]:
    """Return (frontmatter dict, body). Frontmatter is one-key-per-line, no nesting."""
    m = FRONTMATTER_RE.match(text)
    if not m:
        return {}, text
    fm: dict[str, str] = {}
    for line in m.group(1).splitlines():
        line = line.strip()
        if not line or line.startswith("#"):
            continue
        if ":" not in line:
            continue
        k, v = line.split(":", 1)
        fm[k.strip()] = v.strip()
    return fm, text[m.end():]


def parse_hint(path: Path) -> tuple[dict[str, Any] | None, str]:
    """Parse one hint file. Return (cluster_dict, error). cluster_dict is None on rejection."""
    try:
        raw = path.read_text()
    except OSError as e:
        return None, f"read failed: {e}"

    fm, body = parse_frontmatter(raw)
    activity = fm.get("activity", "").strip()
    if activity not in VALID_ACTIVITIES:
        return None, f"frontmatter activity '{activity}' not in {sorted(VALID_ACTIVITIES)}"

    created = fm.get("created", "").strip() or None

    rule_match = RULE_HEADING_RE.search(body)
    if not rule_match:
        return None, "no '## Rule: <title>' heading found"
    title = rule_match.group(1).strip()

    # Body is everything after the rule heading until **Why:** or EOF
    after_heading = body[rule_match.end():].strip()
    why_match = WHY_RE.search(after_heading)
    if why_match:
        rule_body = after_heading[:why_match.start()].strip()
        why = why_match.group(1).strip()
        # Fold Why into the rule string so downstream renderers don't need to
        # know the field exists. Match the cluster.md "include why when evidence
        # makes it clear" convention.
        rule_text = f"{rule_body}\n\nWhy: {why}" if rule_body else f"Why: {why}"
    else:
        rule_text = after_heading

    if not rule_text:
        return None, "rule body is empty"

    cluster = {
        "activity": activity,
        "name": title,
        "rule": rule_text,
        "source": "hint",
        "hint_slug": path.stem,
        "hint_created": created,
        "evidence": [],
    }
    return cluster, ""


def load_hints(hints_dir: Path, activity_filter: list[str] | None) -> tuple[list[dict[str, Any]], int, int]:
    """Walk hints/<activity>/*.md and parse. Return (clusters, total, skipped)."""
    clusters: list[dict[str, Any]] = []
    total = 0
    skipped = 0
    if not hints_dir.is_dir():
        return clusters, total, skipped

    for activity_dir in sorted(hints_dir.iterdir()):
        if not activity_dir.is_dir():
            continue
        if activity_filter and activity_dir.name not in activity_filter:
            continue
        if activity_dir.name not in VALID_ACTIVITIES:
            # Unknown activity dir — skip silently; user may have left a stray folder.
            continue
        for hint_file in sorted(activity_dir.glob("*.md")):
            total += 1
            cluster, err = parse_hint(hint_file)
            if cluster is None:
                skipped += 1
                print(f"warn: {hint_file}: {err}", file=sys.stderr)
                continue
            # Cross-check: frontmatter activity must match parent dir.
            if cluster["activity"] != activity_dir.name:
                skipped += 1
                print(
                    f"warn: {hint_file}: frontmatter activity "
                    f"'{cluster['activity']}' != parent dir '{activity_dir.name}', skipping",
                    file=sys.stderr,
                )
                continue
            clusters.append(cluster)
    return clusters, total, skipped


def main() -> int:
    ap = argparse.ArgumentParser(
        description=__doc__,
        formatter_class=argparse.RawDescriptionHelpFormatter,
    )
    ap.add_argument(
        "--hints-dir",
        default=str(DEFAULT_HINTS_DIR),
        help=f"Directory containing per-activity hint subdirs (default: {DEFAULT_HINTS_DIR}).",
    )
    ap.add_argument(
        "--activity",
        action="append",
        default=[],
        choices=sorted(VALID_ACTIVITIES),
        help="Filter to specific activity. Repeat for multiple.",
    )
    ap.add_argument(
        "--out",
        help="Output path (default: stdout). Output is {\"clusters\": [...]}.",
    )
    ap.add_argument(
        "--merge-into",
        help="Path to an existing clusters.json. Union hint clusters with its "
             "'clusters' array and atomic-write back to the same path. "
             "Mutually exclusive with --out.",
    )
    args = ap.parse_args()

    if args.out and args.merge_into:
        print("error: --out and --merge-into are mutually exclusive", file=sys.stderr)
        return 2

    hints_dir = Path(args.hints_dir).expanduser()
    activity_filter = args.activity or None
    hint_clusters, total, skipped = load_hints(hints_dir, activity_filter)

    print(
        f"# read_hints: dir={hints_dir} hints={total} parsed={len(hint_clusters)} skipped={skipped}",
        file=sys.stderr,
    )

    if args.merge_into:
        target = Path(args.merge_into).expanduser()
        try:
            existing = json.loads(target.read_text())
        except FileNotFoundError:
            print(f"error: --merge-into target does not exist: {target}", file=sys.stderr)
            return 2
        except json.JSONDecodeError as e:
            print(f"error: --merge-into target is not valid JSON: {e}", file=sys.stderr)
            return 2
        if not isinstance(existing, dict) or "clusters" not in existing:
            print(f"error: --merge-into target lacks 'clusters' array", file=sys.stderr)
            return 2
        existing_clusters = existing.get("clusters") or []
        # Dedupe by hint_slug — re-runs against the same hints set should not
        # double-append. Extracted clusters have no hint_slug, so they pass through.
        existing_slugs = {
            c.get("hint_slug") for c in existing_clusters
            if c.get("source") == "hint" and c.get("hint_slug")
        }
        appended = 0
        for hc in hint_clusters:
            if hc["hint_slug"] in existing_slugs:
                continue
            existing_clusters.append(hc)
            appended += 1
        existing["clusters"] = existing_clusters
        tmp = target.with_suffix(target.suffix + ".tmp")
        tmp.write_text(json.dumps(existing, indent=2))
        tmp.replace(target)
        print(f"# read_hints: merged into {target} appended={appended}", file=sys.stderr)
        return 0

    payload = {"clusters": hint_clusters}
    text = json.dumps(payload, indent=2)
    if args.out:
        out = Path(args.out).expanduser()
        tmp = out.with_suffix(out.suffix + ".tmp")
        tmp.write_text(text)
        tmp.replace(out)
        print(f"# read_hints: wrote {out}", file=sys.stderr)
    else:
        sys.stdout.write(text)
        sys.stdout.write("\n")
    return 0


if __name__ == "__main__":
    sys.exit(main())
