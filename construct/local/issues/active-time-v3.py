#!/usr/bin/env python3
"""
active-time-v3.py — segment-anchored per-issue attribution.

Replaces active-time.py's session-wide mention-weighted attribution with
commit-anchored segment-local attribution. Why:

  In single-issue sessions (e.g., a charon-launch-push working day), the
  old session-wide mention-weighting works fine — most of the session is
  about the one issue.

  In multi-issue sessions (a project-portfolio session that closes #3
  and writes M2 of #4 and bootstraps the test infra in #11 and reviews
  #8 and runs the dry-run for #10), the mention-weighting redistributes
  whole-session active-minutes across every issue mentioned, *including
  issues whose only signal is "I mentioned its number 3 times in chat
  while talking about something else."* The result is wild over-
  attribution to peripheral issues.

The v3 method, single-threaded session by definition:

  1. Get the commits in the window with timestamps + issue refs.
  2. Define segments: events from one commit's time to the next form a
     segment. Segments are intrinsically scoped to whichever
     focused-work block produced the commit.
  3. For each segment:
     a. Compute active time (15-min gap-truncated) within segment bounds.
     b. Parse issue refs from the segment-ending commit message.
     c. Count #N mentions in transcript events within the segment only.
     d. Allocate active time:
        - commit-weight (default 0.5) * active / N_issues_in_commit → each
          issue named in the commit message.
        - (1 - commit-weight) * active * (mention_count / total_mentions)
          → each mentioned issue.
        - If the commit has no issue refs: full segment goes by mention
          count (commit signal is absent).

Edge cases:
  - Pre-first-commit prefix: attributed to first commit's issues using
    the same rule.
  - Post-last-commit suffix: same.
  - Parallel sessions (multiple transcript dirs): processed
    independently; results summed. Parallel-session dedup not yet
    implemented for v3 (rare in practice for the operator).

Usage:
  python3 active-time-v3.py \\
    --dir ~/.claude/projects/-Users-xianxu-workspace-nous \\
    --dir ~/.claude/projects/-Users-xianxu-workspace-brain \\
    --git-repo ~/workspace/nous \\
    --since 2026-05-07T16:54:00Z --until 2026-05-08T05:13:00Z \\
    --issue 8 --issue 10 --issue 11 \\
    --commit-weight 0.5 \\
    --threshold-min 15 --include-assistant
"""

import argparse
import json
import re
import subprocess
import sys
from datetime import datetime, timedelta
from pathlib import Path


def parse_iso(ts):
    if ts.endswith("Z"):
        ts = ts[:-1] + "+00:00"
    return datetime.fromisoformat(ts)


# --- transcripts ----------------------------------------------------------

def walk_session_events(jsonl_path, issue_pat, include_assistant):
    """Yield (timestamp, mention_counts_dict) for each event we care about
    in the session file. mention_counts is a dict {issue: count} for
    issues actually mentioned in this single event."""
    with open(jsonl_path) as f:
        for line in f:
            try:
                d = json.loads(line)
            except Exception:
                continue
            ts = d.get("timestamp")
            t = d.get("type")
            if not ts:
                continue
            mentions = {}
            text = ""
            if t == "user":
                msg = d.get("message", {})
                content = msg.get("content")
                if isinstance(content, str):
                    text = content
                elif isinstance(content, list):
                    saw_tool_result = False
                    parts = []
                    for blk in content:
                        if isinstance(blk, dict):
                            if blk.get("type") == "tool_result":
                                saw_tool_result = True
                            elif blk.get("type") == "text":
                                parts.append(blk.get("text", ""))
                            elif "content" in blk and isinstance(blk["content"], str):
                                parts.append(blk["content"])
                    if saw_tool_result and not parts:
                        continue  # pure tool result, not human typing
                    text = "\n".join(parts)
                else:
                    continue
                if not text.strip():
                    continue
            elif t == "assistant" and include_assistant:
                msg = d.get("message", {})
                content = msg.get("content")
                if isinstance(content, list):
                    parts = []
                    for blk in content:
                        if isinstance(blk, dict) and blk.get("type") == "text":
                            parts.append(blk.get("text", ""))
                    text = "\n".join(parts)
            else:
                continue

            if issue_pat is not None and text:
                for m in issue_pat.findall(text):
                    mentions[m] = mentions.get(m, 0) + 1

            try:
                yield (parse_iso(ts), mentions)
            except Exception:
                continue


def load_events(dirs, issue_pat, include_assistant, since, until):
    """Load all events across all session files, filtered to the time
    window. Returns a sorted list of (timestamp, mentions_dict)."""
    events = []
    for d in dirs:
        p = Path(d).expanduser()
        if not p.is_dir():
            continue
        for jsonl_file in p.glob("*.jsonl"):
            for ts, mentions in walk_session_events(jsonl_file, issue_pat, include_assistant):
                if since and ts < since:
                    continue
                if until and ts > until:
                    continue
                events.append((ts, mentions))
    events.sort(key=lambda e: e[0])
    return events


# --- commits --------------------------------------------------------------

def load_commits(repo, since, until, issue_pat):
    """Run git log within window, return [(timestamp, message, [issues])]."""
    args = ["git", "-C", str(Path(repo).expanduser()), "log",
            "--pretty=format:%H%x09%aI%x09%s%x00%n", "--reverse"]
    if since:
        args.append(f"--since={since.isoformat()}")
    if until:
        args.append(f"--until={until.isoformat()}")
    out = subprocess.check_output(args, text=True)
    commits = []
    for entry in out.split("\x00\n"):
        entry = entry.strip()
        if not entry:
            continue
        parts = entry.split("\t", 2)
        if len(parts) < 3:
            continue
        sha, ts_iso, msg = parts
        try:
            ts = parse_iso(ts_iso)
        except Exception:
            continue
        issues = issue_pat.findall(msg) if issue_pat else []
        # Dedupe issue list while preserving order.
        seen = set()
        uniq = []
        for i in issues:
            if i not in seen:
                seen.add(i)
                uniq.append(i)
        commits.append((ts, sha[:7], msg, uniq))
    return commits


# --- attribution ----------------------------------------------------------

def active_minutes(times, threshold_min):
    """Sum of inter-event gaps capped at threshold. Same shape as the
    v2.1 active-time procedure. Returns minutes."""
    if not times:
        return 0.0
    times = sorted(times)
    cap = timedelta(minutes=threshold_min)
    total = timedelta(0)
    for a, b in zip(times[:-1], times[1:]):
        gap = b - a
        if gap <= cap:
            total += gap
        else:
            total += cap
    return total.total_seconds() / 60.0


def attribute_segment(active_min, commit_issues, mention_counts, commit_weight):
    """Allocate active_min of a segment per the v3 rule. Returns
    {issue: minutes}."""
    out = {}
    if active_min <= 0:
        return out
    if commit_issues:
        per_commit = commit_weight * active_min / len(commit_issues)
        for iss in commit_issues:
            out[iss] = out.get(iss, 0.0) + per_commit
        transcript_share = (1 - commit_weight) * active_min
    else:
        # No commit signal → full segment goes by mention.
        transcript_share = active_min
    if mention_counts and transcript_share > 0:
        total = sum(mention_counts.values())
        if total > 0:
            for iss, n in mention_counts.items():
                out[iss] = out.get(iss, 0.0) + transcript_share * n / total
        else:
            # No mentions either; leave the transcript share unattributed.
            out["#unattributed"] = out.get("#unattributed", 0.0) + transcript_share
    elif transcript_share > 0:
        out["#unattributed"] = out.get("#unattributed", 0.0) + transcript_share
    return out


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--dir", action="append", default=[],
                    help="Transcript directory (~/.claude/projects/...). Repeatable.")
    ap.add_argument("--git-repo", required=True,
                    help="Repo to read commits from.")
    ap.add_argument("--since", help="ISO timestamp; events/commits before are skipped")
    ap.add_argument("--until", help="ISO timestamp; events/commits after are skipped")
    ap.add_argument("--issue", action="append", default=[],
                    help="Issue number to track (without #); repeatable.")
    ap.add_argument("--commit-weight", type=float, default=1.0,
                    help="Fraction of segment active time attributed by commit refs (default 1.0)")
    ap.add_argument("--prefix-commit-weight", type=float, default=None,
                    help="Commit-weight for the pre-first-commit prefix segment specifically. "
                         "Defaults to --commit-weight. Useful for long-prefix sessions where "
                         "early planning may not have been about the eventual first commit's "
                         "issue (try 0.5 to mix in mention signal).")
    ap.add_argument("--threshold-min", type=int, default=15,
                    help="Gap-truncation threshold in minutes (default 15)")
    ap.add_argument("--include-assistant", action="store_true",
                    help="Include assistant messages in the active-time stream")
    args = ap.parse_args()

    issues = [str(i) for i in args.issue]
    if not issues:
        print("--issue required (at least one)", file=sys.stderr)
        sys.exit(2)
    issue_pat = re.compile(r"#(" + "|".join(re.escape(i) for i in issues) + r")\b")

    since = parse_iso(args.since) if args.since else None
    until = parse_iso(args.until) if args.until else None

    events = load_events(args.dir, issue_pat, args.include_assistant, since, until)
    commits = load_commits(args.git_repo, since, until, issue_pat)

    prefix_weight = args.prefix_commit_weight if args.prefix_commit_weight is not None else args.commit_weight

    print(f"# v3 segment-anchored attribution")
    if prefix_weight != args.commit_weight:
        print(f"# commit-weight: {args.commit_weight} (prefix: {prefix_weight})  •  threshold: {args.threshold_min} min")
    else:
        print(f"# commit-weight: {args.commit_weight}  •  threshold: {args.threshold_min} min")
    print(f"# issues: {', '.join('#' + i for i in issues)}")
    print(f"# events in window: {len(events)}  •  commits in window: {len(commits)}")
    print()

    if not events:
        print("# no events in window", file=sys.stderr)
        sys.exit(0)
    if not commits:
        print("# no commits in window — falling back to whole-window mention attribution", file=sys.stderr)
        active = active_minutes([e[0] for e in events], args.threshold_min)
        mentions = {}
        for _, m in events:
            for iss, n in m.items():
                mentions[iss] = mentions.get(iss, 0) + n
        alloc = attribute_segment(active, [], mentions, args.commit_weight)
        for iss, mins in sorted(alloc.items()):
            print(f"  #{iss}: {mins/60:.2f} hr")
        return

    # Build segment boundaries: prefix segment (from start of events to
    # first commit), one segment per commit (events from prior commit
    # time to this commit time), suffix (events after last commit).
    boundaries = [events[0][0]] + [c[0] for c in commits] + [events[-1][0] + timedelta(seconds=1)]
    boundaries = sorted(set(boundaries))

    # Detect whether there's a real pre-first-commit prefix: only true if
    # the first event's timestamp is strictly before the first commit's.
    # (When user opens a session and immediately commits, there's no prefix.)
    has_prefix = events[0][0] < commits[0][0]

    # Walk segments. For each segment, find which commit "anchors" it
    # (the segment-ending commit; for suffix, treat as no commit).
    seg_results = []
    e_idx = 0
    for i in range(len(boundaries) - 1):
        seg_start, seg_end = boundaries[i], boundaries[i + 1]
        # Events whose timestamp ∈ [seg_start, seg_end)
        seg_events = []
        while e_idx < len(events) and events[e_idx][0] < seg_end:
            if events[e_idx][0] >= seg_start:
                seg_events.append(events[e_idx])
            e_idx += 1
        if not seg_events:
            continue
        active = active_minutes([e[0] for e in seg_events], args.threshold_min)

        # Anchor: commit at seg_end if any.
        anchor = next((c for c in commits if c[0] == seg_end), None)
        commit_issues = anchor[3] if anchor else []
        # If this is the suffix (no anchor), no commit signal → mention only.
        # If this is the prefix (no anchor at start, and seg_end == first commit),
        # actually anchor IS the first commit — handled above.

        mentions = {}
        for _, m in seg_events:
            for iss, n in m.items():
                mentions[iss] = mentions.get(iss, 0) + n

        # Use prefix_weight for the very first segment iff there's a real
        # pre-first-commit prefix; otherwise use the standard commit_weight.
        is_prefix = has_prefix and i == 0
        weight = prefix_weight if is_prefix else args.commit_weight
        alloc = attribute_segment(active, commit_issues, mentions, weight)
        seg_results.append({
            "seg_start": seg_start, "seg_end": seg_end,
            "active": active,
            "commit": anchor,
            "mentions": mentions,
            "alloc": alloc,
            "is_prefix": is_prefix,
        })

    # Per-segment table
    print(f"{'#':>3}  {'start':<19}  {'end':<19}  {'min':>5}  commit                       issues       mentions     alloc")
    total_active = 0.0
    totals = {}
    for n, sr in enumerate(seg_results, 1):
        total_active += sr["active"]
        for iss, mins in sr["alloc"].items():
            totals[iss] = totals.get(iss, 0.0) + mins
        cm = sr["commit"]
        if cm:
            commit_str = f"{cm[1]} {cm[2][:30]}"
            iss_str = ",".join("#" + i for i in cm[3])
        else:
            commit_str = "(no anchor)"
            iss_str = ""
        if sr.get("is_prefix"):
            commit_str = "[prefix] " + commit_str
        ment_str = ",".join(f"#{i}={c}" for i, c in sorted(sr["mentions"].items()))
        alloc_str = ",".join(f"#{i}={m:.1f}m" for i, m in sorted(sr["alloc"].items()))
        print(f"{n:>3}  {sr['seg_start'].astimezone().strftime('%Y-%m-%d %H:%M'):<19}  "
              f"{sr['seg_end'].astimezone().strftime('%Y-%m-%d %H:%M'):<19}  "
              f"{sr['active']:5.1f}  {commit_str:<30}  {iss_str:<11}  {ment_str:<22}  {alloc_str}")

    print()
    print(f"# total active in window: {total_active:.1f} min  ({total_active/60:.2f} hr)")
    print()
    print("# per-issue totals")
    for iss in sorted(totals.keys()):
        print(f"  #{iss}: {totals[iss]/60:.2f} hr  ({totals[iss]:.1f} min)")


if __name__ == "__main__":
    main()
