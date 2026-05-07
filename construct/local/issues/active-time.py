#!/usr/bin/env python3
"""Estimate user-active time across Claude Code transcripts.

Walks every .jsonl session file in one or more transcript dirs,
extracts timestamps of user-typed messages (type=="user" with a
real `timestamp` field, optionally also assistant timestamps via
--include-assistant), and computes "active time" via gap
truncation: between two consecutive engagement events, count the
gap up to a configurable threshold (default 15 min). Gaps longer
than the threshold are assumed to be "stepped away" and capped.

Per-session output includes:
- session id (filename stem)
- start/end of user activity in the session
- raw span (last - first)
- active span (sum of truncated gaps)
- user message count
- mention counts for any issues passed via --issue (used to
  attribute a session to a primary issue when multiple issues
  share a window).

Two output sections:
1. Per-session sum (over-counts when sessions run in parallel via
   pair / worktree workflow).
2. UNIFIED WALL-CLOCK active — merges all sessions' event timestamps
   into a single sorted timeline and applies gap truncation across
   the merged stream. This is the "real" wall-clock active number.

Usage:
    # totals only (no per-issue attribution)
    python3 active-time.py [--threshold-min 15] [--include-assistant] \\
        --dir ~/.claude/projects/-Users-xianxu-workspace-nous \\
        --dir ~/.claude/projects/-Users-xianxu-workspace-brain \\
        --since 2026-05-01 --until 2026-05-06

    # one issue (typical issue-close case)
    python3 active-time.py --issue 15 \\
        --dir ~/.claude/projects/-Users-xianxu-workspace-nous \\
        --since 2026-05-01 --until 2026-05-06

    # multiple issues sharing the same window
    python3 active-time.py --issue 13 --issue 14 --issue 15 ...

--since/--until accept either YYYY-MM-DD (treated as start/end of
day UTC) or full ISO 8601 (e.g. 2026-04-30T16:00Z) for tighter
windows.

Output: TSV to stdout. Pipe through `column -t` to align.
"""
from __future__ import annotations

import argparse
import json
import os
import re
from datetime import datetime
from pathlib import Path


def parse_iso(ts: str) -> datetime:
    # Handle trailing Z or +00:00 forms uniformly.
    if ts.endswith("Z"):
        ts = ts[:-1] + "+00:00"
    return datetime.fromisoformat(ts)


def session_active_time(path: Path, threshold_sec: int, issue_pat: re.Pattern | None,
                        issues: list[str], include_assistant: bool = False):
    """Return dict with session stats; None if no user msgs.

    include_assistant: also treat assistant message timestamps as
    engagement events. Useful when the user types sparsely but
    Claude is working continuously and the user is reading along —
    the threshold-truncation otherwise undercounts those stretches.

    issue_pat / issues: when issues is non-empty, count `#<N>`
    mentions per issue for attribution. When empty, skip.
    """
    user_times = []
    issue_mentions = {iss: 0 for iss in issues}
    total_user_chars = 0
    with path.open() as f:
        for line in f:
            line = line.strip()
            if not line:
                continue
            try:
                d = json.loads(line)
            except json.JSONDecodeError:
                continue
            t = d.get("type")
            ts = d.get("timestamp")
            if t == "user" and ts:
                # User-typed message OR tool result echoed as "user".
                # Filter to actual prompts: message.role=="user" + content
                # is a string (or list of strings/blocks where any is
                # plain text). Tool results show up with role="user"
                # but content type "tool_result" — exclude.
                msg = d.get("message", {})
                content = msg.get("content")
                if isinstance(content, str):
                    text = content
                elif isinstance(content, list):
                    text_parts = []
                    saw_tool_result = False
                    for blk in content:
                        if isinstance(blk, dict):
                            if blk.get("type") == "tool_result":
                                saw_tool_result = True
                            elif blk.get("type") == "text":
                                text_parts.append(blk.get("text", ""))
                            else:
                                # Other block types: skip
                                pass
                    if saw_tool_result and not text_parts:
                        continue  # pure tool result, not human typing
                    text = "\n".join(text_parts)
                else:
                    continue
                if not text.strip():
                    continue
                # Count issue mentions in user prompts.
                if issue_pat is not None:
                    for m in issue_pat.findall(text):
                        issue_mentions[m] += 1
                total_user_chars += len(text)
                try:
                    user_times.append(parse_iso(ts))
                except Exception:
                    continue
            elif t == "assistant" and ts:
                # Also count issue mentions in assistant text — gives
                # broader signal for attribution.
                if issue_pat is not None:
                    msg = d.get("message", {})
                    content = msg.get("content")
                    if isinstance(content, list):
                        for blk in content:
                            if isinstance(blk, dict) and blk.get("type") == "text":
                                for m in issue_pat.findall(blk.get("text", "")):
                                    issue_mentions[m] += 1
                if include_assistant:
                    try:
                        user_times.append(parse_iso(ts))
                    except Exception:
                        pass
    if not user_times:
        return None
    user_times.sort()
    raw_span = (user_times[-1] - user_times[0]).total_seconds()
    active_sec = 0.0
    for i in range(1, len(user_times)):
        gap = (user_times[i] - user_times[i - 1]).total_seconds()
        active_sec += min(gap, threshold_sec)
    # Add a small constant for the first message (assume ~30s of
    # writing it) so single-message sessions aren't 0.
    if len(user_times) >= 1:
        active_sec += 30
    return {
        "path": str(path),
        "start": user_times[0],
        "end": user_times[-1],
        "raw_span_sec": raw_span,
        "active_sec": active_sec,
        "user_msgs": len(user_times),
        "user_chars": total_user_chars,
        "mentions": issue_mentions,
        "user_ts": user_times,
    }


def unified_active_time(sessions, threshold_sec, issues):
    """Wall-clock active time across all sessions.

    Per-session active-time double-counts when the user runs multiple
    Claude instances in parallel (worktree / pair workflow). To get
    real wall-clock active hours, take all user-message timestamps
    across every session, sort, and apply the same gap-truncation
    heuristic to the unified stream.

    Returns (active_sec, by_issue dict). When issues is empty,
    by_issue is an empty dict. When non-empty, attribution is
    mention-weighted on a per-event basis: each user message
    contributes its preceding-gap (truncated) to the issue with the
    most mentions in the session that produced it. Ties split.
    Events from sessions with no mentions land in "none".
    """
    events = []
    for i, s in enumerate(sessions):
        for ts in s["user_ts"]:
            events.append((ts, i))
    events.sort(key=lambda e: e[0])

    by_issue: dict[str, float] = {}
    if issues:
        by_issue = {iss: 0.0 for iss in issues}
        by_issue["none"] = 0.0
    if not events:
        return 0.0, by_issue

    active_sec = 30.0  # first message constant
    for n in range(1, len(events)):
        gap = (events[n][0] - events[n - 1][0]).total_seconds()
        gap = min(gap, threshold_sec)
        active_sec += gap
        if not issues:
            continue
        sess = sessions[events[n][1]]
        m = sess["mentions"]
        max_count = max(m.values()) if m else 0
        if max_count == 0:
            by_issue["none"] += gap
        else:
            top = [k for k, v in m.items() if v == max_count]
            for k in top:
                by_issue[k] += gap / len(top)
    return active_sec, by_issue


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--dir", action="append", required=True,
                    help="Transcript dir (repeatable)")
    ap.add_argument("--threshold-min", type=int, default=15)
    ap.add_argument("--include-assistant", action="store_true",
                    help="Also count assistant message timestamps as engagement events")
    ap.add_argument("--since", help="ISO date YYYY-MM-DD")
    ap.add_argument("--until", help="ISO date YYYY-MM-DD")
    ap.add_argument("--by-day", action="store_true",
                    help="Bucket sessions by start date")
    ap.add_argument("--issue", action="append", default=[],
                    help="Issue number to track (repeatable, e.g. --issue 15 --issue 16). "
                         "When provided, prints per-issue mention columns and "
                         "mention-weighted attribution. When empty, totals only.")
    args = ap.parse_args()

    threshold_sec = args.threshold_min * 60
    issues: list[str] = list(args.issue)
    issue_pat = (
        re.compile(r"#(" + "|".join(re.escape(i) for i in issues) + r")\b")
        if issues else None
    )
    # Accept either YYYY-MM-DD or full ISO; bare dates default to
    # start/end of day for since/until respectively.
    def expand(s, end):
        if s is None:
            return None
        if "T" in s:
            return parse_iso(s if "+" in s or s.endswith("Z") else s + "+00:00")
        return parse_iso(s + ("T23:59:59+00:00" if end else "T00:00:00+00:00"))
    since = expand(args.since, end=False)
    until = expand(args.until, end=True)

    sessions = []
    for d in args.dir:
        for path in sorted(Path(os.path.expanduser(d)).glob("*.jsonl")):
            stat = session_active_time(path, threshold_sec, issue_pat, issues,
                                       args.include_assistant)
            if stat is None:
                continue
            # Filter events to the requested window, not the session
            # span. Sessions can run for hours across a day boundary
            # while only a fraction of events fall in the window we
            # care about.
            if since or until:
                kept = [t for t in stat["user_ts"]
                        if (not since or t >= since) and (not until or t <= until)]
                if not kept:
                    continue
                stat["user_ts"] = kept
                stat["start"] = kept[0]
                stat["end"] = kept[-1]
                stat["user_msgs"] = len(kept)
                # Recompute active_sec for this filtered range.
                active = 30.0
                for n in range(1, len(kept)):
                    active += min((kept[n] - kept[n - 1]).total_seconds(), threshold_sec)
                stat["active_sec"] = active
                stat["raw_span_sec"] = (kept[-1] - kept[0]).total_seconds()
            stat["dir"] = d
            sessions.append(stat)
    sessions.sort(key=lambda s: s["start"])

    print("# active time analysis")
    print(f"# threshold: {args.threshold_min} min  •  sessions: {len(sessions)}")
    if since:
        print(f"# since: {since.isoformat()}")
    if until:
        print(f"# until: {until.isoformat()}")
    print()
    base_cols = "session_id\tdir\tstart_local\tactive_min\traw_min\tuser_msgs"
    issue_cols = "".join(f"\tmen_{iss}" for iss in issues)
    print(base_cols + issue_cols)
    total_active = 0.0
    by_day = {}
    by_issue: dict[str, float] = (
        {iss: 0.0 for iss in issues} | {"none": 0.0} if issues else {}
    )
    for s in sessions:
        sid = Path(s["path"]).stem[:8]
        start_local = s["start"].astimezone().strftime("%Y-%m-%d %H:%M")
        active_min = s["active_sec"] / 60
        raw_min = s["raw_span_sec"] / 60
        # Repo tag derived from the dir path's last segment, e.g.
        # `-Users-xianxu-workspace-nous` → `nous`.
        d_short = Path(s["dir"]).name.rsplit("-", 1)[-1] or s["dir"][-12:]
        m = s["mentions"]
        mention_cells = "".join(f"\t{m.get(iss, 0):3d}" for iss in issues)
        print(f"{sid}\t{d_short}\t{start_local}\t{active_min:6.1f}\t{raw_min:6.1f}\t{s['user_msgs']:4d}{mention_cells}")
        total_active += active_min

        if args.by_day:
            day = s["start"].astimezone().strftime("%Y-%m-%d")
            by_day[day] = by_day.get(day, 0) + active_min

        if not issues:
            continue
        # Crude attribution: assign session's active time to the
        # issue with the most mentions (ties → split evenly; zero
        # mentions → "none").
        max_count = max(m.values()) if m else 0
        if max_count == 0:
            by_issue["none"] += active_min
        else:
            top = [k for k, v in m.items() if v == max_count]
            for k in top:
                by_issue[k] += active_min / len(top)

    print()
    print(f"# total active (per-session sum, double-counts parallel sessions): {total_active:.1f} min  ({total_active/60:.1f} hr)")
    if args.by_day:
        print("\n# by day (per-session sum)")
        for day in sorted(by_day):
            print(f"  {day}: {by_day[day]:.1f} min  ({by_day[day]/60:.2f} hr)")
    if issues:
        print("\n# crude per-session attribution by issue mentions")
        for k in issues + ["none"]:
            v = by_issue[k]
            label = k if k != "none" else "unattributed"
            print(f"  #{label}: {v:.1f} min  ({v/60:.2f} hr)")

    # Unified wall-clock — merges all sessions' user-message
    # timestamps into a single timeline so parallel sessions
    # (worktree / pair workflow) don't double-count.
    unified_sec, unified_by_issue = unified_active_time(sessions, threshold_sec, issues)
    print()
    print(f"# UNIFIED WALL-CLOCK active (parallel sessions deduped): {unified_sec/60:.1f} min  ({unified_sec/3600:.2f} hr)")
    if issues:
        print("# unified attribution by mention-weighted gap assignment")
        for k in issues + ["none"]:
            v = unified_by_issue[k]
            label = k if k != "none" else "unattributed"
            print(f"  #{label}: {v/60:.1f} min  ({v/3600:.2f} hr)")


if __name__ == "__main__":
    main()
