#!/usr/bin/env python3
"""
Emit one segment's transcript as a human-readable chunk on stdout.

This is the "extract one chunk to send to an LLM" half of the UNIX kit for
introspect-extraction. It does not call any LLM; it just emits text. Pair with a
prompt file (e.g. construct/local/introspect/prompts/extract.md) and pipe both
into whichever model you prefer.

Usage:
  segment_text.py --cache-dir <run-dir> --segment <segment-id>
  segment_text.py --cache-dir <run-dir> --segment 84afbb05-...#s4
  segment_text.py --cache-dir <run-dir> --short 84afbb05#s4    # short prefix#segN form

Composition examples:
  # All-claude one-shot
  { cat .../prompts/extract.md; segment_text.py ... ; } | claude -p

  # claude with system flag
  segment_text.py ... | claude --system "$(cat .../prompts/extract.md)" -p

  # codex / gemini are similar — see prompts/README.md

Output format: light markdown markup. Each turn is delimited by
== <role> @ <ts> ==; tool uses appear as [tool: NAME ...] lines with one-line
input summaries; tool results appear as [result: ...] truncated to 600 chars.
The header has segment metadata for context.

Truncation: assistant text > 4000 chars is summarized down to first 1500 +
"… [N chars omitted] …" + last 500 chars. Tool results > 600 chars get a
similar truncation. This keeps a typical segment under ~30k tokens.
"""

from __future__ import annotations

import argparse
import json
import signal
import sys
from pathlib import Path
from typing import Any

# Quiet SIGPIPE handling — let "segment_text.py … | head" exit cleanly without
# Python printing a BrokenPipeError to stderr at interpreter shutdown.
try:
    signal.signal(signal.SIGPIPE, signal.SIG_DFL)
except (AttributeError, ValueError):
    pass  # Windows / non-main-thread

PROJECTS_ROOT = Path.home() / ".claude" / "projects"
ASSISTANT_TEXT_HEAD = 1500
ASSISTANT_TEXT_TAIL = 500
ASSISTANT_TEXT_MAX = 4000
TOOL_RESULT_MAX = 600
USER_TEXT_MAX = 6000  # user messages can be substantive, allow more


def truncate(text: str, max_len: int, head: int | None = None, tail: int | None = None) -> str:
    if len(text) <= max_len:
        return text
    if head is None:
        return text[: max_len - 30] + f" … [{len(text) - max_len + 30} chars omitted]"
    tail = tail if tail is not None else 0
    omitted = len(text) - head - tail
    return f"{text[:head]}\n… [{omitted} chars omitted] …\n{text[-tail:]}" if tail else text[:head] + f" … [{omitted} chars omitted]"


def extract_text_from_content(content: Any) -> str:
    if isinstance(content, str):
        return content
    if isinstance(content, list):
        parts = []
        for item in content:
            if not isinstance(item, dict):
                continue
            if item.get("type") == "text" and "text" in item:
                parts.append(item["text"])
        return "\n".join(parts)
    return ""


def extract_tool_uses(content: Any) -> list[dict[str, Any]]:
    if not isinstance(content, list):
        return []
    return [item for item in content if isinstance(item, dict) and item.get("type") == "tool_use"]


def summarize_tool_input(name: str, ipt: dict[str, Any]) -> str:
    if name in ("Edit", "Write", "Read"):
        fp = ipt.get("file_path", "")
        extras = []
        if "old_string" in ipt:
            extras.append(f"old≈{(ipt['old_string'] or '')[:60].strip()!r}")
        if "new_string" in ipt:
            extras.append(f"new≈{(ipt['new_string'] or '')[:60].strip()!r}")
        if "limit" in ipt:
            extras.append(f"limit={ipt['limit']}")
        if "offset" in ipt:
            extras.append(f"offset={ipt['offset']}")
        suffix = (" " + " ".join(extras)) if extras else ""
        return f"file_path={fp}{suffix}"
    if name == "Bash":
        cmd = (ipt.get("command") or "").replace("\n", " ⏎ ")
        return f"command={truncate(cmd, 240)!r}"
    if name == "Skill":
        return f"skill={ipt.get('skill', '')} args={ipt.get('args', '')!r}"
    if name == "Agent":
        return f"description={(ipt.get('description') or '')[:120]!r} type={ipt.get('subagent_type', 'general-purpose')}"
    if name == "Grep":
        return f"pattern={ipt.get('pattern', '')!r} path={ipt.get('path', '')}"
    keys = sorted(ipt.keys())[:4]
    return f"keys={keys}"


def extract_tool_result_text(line: dict[str, Any]) -> str:
    msg = line.get("message", {})
    if not isinstance(msg, dict):
        return ""
    c = msg.get("content", "")
    if isinstance(c, str):
        return c
    if isinstance(c, list):
        parts = []
        for it in c:
            if not isinstance(it, dict):
                continue
            ct = it.get("content", "")
            if isinstance(ct, str):
                parts.append(ct)
            elif isinstance(ct, list):
                for sub in ct:
                    if isinstance(sub, dict) and sub.get("type") == "text":
                        parts.append(sub.get("text", ""))
        return "\n".join(parts)
    return ""


def load_session_index(cache_dir: Path) -> dict[str, dict[str, Any]]:
    sessions = json.loads((cache_dir / "sessions.json").read_text())
    return {s["session_id"]: s for s in sessions}


def resolve_segment_id(cache_dir: Path, raw: str) -> str | None:
    """Accept either full segment id (`<uuid>#s<N>`) or a short form
    (`<uuid8>#<N>`). Return the canonical full segment id if a match is found,
    None otherwise."""
    sessions = load_session_index(cache_dir)
    if raw in sessions:
        return raw
    if "#" in raw:
        prefix, seg = raw.split("#", 1)
        seg = seg.lstrip("s")
        wanted_suffix = f"#s{seg}"
        for sid in sessions:
            if sid.startswith(prefix) and sid.endswith(wanted_suffix):
                return sid
    return None


def load_segment_events(
    raw_session_id: str, project_slug: str, start_ts: str | None, end_ts: str | None
) -> list[dict[str, Any]]:
    proj_dir = PROJECTS_ROOT / project_slug
    events: list[dict[str, Any]] = []
    for jf in proj_dir.glob("*.jsonl"):
        try:
            with jf.open() as f:
                for raw in f:
                    raw = raw.strip()
                    if not raw:
                        continue
                    try:
                        line = json.loads(raw)
                    except json.JSONDecodeError:
                        continue
                    if line.get("sessionId") != raw_session_id:
                        continue
                    ts = line.get("timestamp")
                    if start_ts and ts and ts < start_ts:
                        continue
                    if end_ts and ts and ts > end_ts:
                        continue
                    events.append(line)
        except OSError:
            continue
    events.sort(key=lambda l: l.get("timestamp") or "")
    return events


def render_segment(segment: dict[str, Any], events: list[dict[str, Any]]) -> str:
    out: list[str] = []
    sid = segment["session_id"]
    activity = segment.get("activity") or "?"
    proj = segment["project_slug"]
    proj_short = proj.split("-")[-1] if "-" in proj else proj
    pos = ""
    if segment.get("segment_count", 1) > 1:
        pos = f" (segment {segment.get('segment_index')} of {segment.get('segment_count')})"
    dur_min = ""
    if segment.get("duration_seconds"):
        dur_min = f" [{int(segment['duration_seconds']/60)} min]"

    out.append(f"# transcript segment {sid}{pos}{dur_min}")
    out.append(f"# project: {proj_short}")
    out.append(f"# activity: {activity}")
    if segment.get("cwd"):
        out.append(f"# cwd: {segment['cwd']}")
    if segment.get("git_branch"):
        out.append(f"# git_branch: {segment['git_branch']}")
    out.append(
        f"# shape: u={segment.get('user_message_count')} a={segment.get('assistant_message_count')} "
        f"tools={segment.get('tool_call_count')} "
        f"writes={len(segment.get('files_written', []))} "
        f"edits={len(segment.get('files_edited', []))}"
    )
    away = segment.get("closing_away_summary")
    if away:
        out.append("# closing-recap (Claude Code's away_summary):")
        for line in away.splitlines():
            out.append(f"#   {line}")
    out.append("")

    # Walk events in order
    for evt in events:
        et = evt.get("type")
        ts = evt.get("timestamp", "")
        if et == "user":
            tur = evt.get("toolUseResult")
            if tur:
                rt = extract_tool_result_text(evt)
                is_err = isinstance(tur, dict) and tur.get("is_error")
                # Skip empty / no-output results unless they were errors.
                if not rt.strip() and not is_err:
                    continue
                rt = truncate(rt, TOOL_RESULT_MAX)
                err_marker = " ERROR" if is_err else ""
                out.append(f"[tool_result @ {ts}{err_marker}]")
                if rt.strip():
                    for ln in rt.splitlines():
                        out.append(f"  {ln}")
                else:
                    out.append("  (empty)")
                out.append("")
            else:
                # actual user prose
                text = extract_text_from_content(evt.get("message", {}).get("content"))
                text = truncate(text, USER_TEXT_MAX)
                if text.strip():
                    out.append(f"== user @ {ts} ==")
                    out.append(text)
                    out.append("")
        elif et == "assistant":
            msg = evt.get("message", {})
            if not isinstance(msg, dict):
                continue
            content = msg.get("content", [])
            text = extract_text_from_content(content)
            tools = extract_tool_uses(content)
            text_trunc = truncate(text, ASSISTANT_TEXT_MAX, head=ASSISTANT_TEXT_HEAD, tail=ASSISTANT_TEXT_TAIL)
            if text_trunc.strip() or tools:
                out.append(f"== assistant @ {ts} ==")
                if text_trunc.strip():
                    out.append(text_trunc)
                for tu in tools:
                    name = tu.get("name", "?")
                    summary = summarize_tool_input(name, tu.get("input") or {})
                    out.append(f"[tool: {name} {summary}]")
                out.append("")
        elif et == "system" and evt.get("subtype") == "away_summary":
            content = evt.get("content")
            if isinstance(content, str):
                out.append(f"[away_summary @ {ts}]")
                for line in content.splitlines():
                    out.append(f"  {line}")
                out.append("")
        # Skip permission-mode, file-history-snapshot, attachment, ai-title, etc.

    return "\n".join(out).rstrip() + "\n"


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--cache-dir", required=True, help="Run cache dir from /xx-introspect extract.")
    ap.add_argument("--segment", help="Full segment id (<uuid>#s<N>) or short form (<uuid8>#<N>).")
    ap.add_argument("--list", action="store_true",
                    help="List all segment ids in the cache instead of rendering one. "
                         "Pipe through grep/head as needed.")
    ap.add_argument("--activity", action="append", default=[],
                    help="With --list: filter to segments whose activity matches one of these.")
    args = ap.parse_args()

    cache = Path(args.cache_dir).expanduser()
    if not cache.is_dir():
        print(f"error: cache dir not found: {cache}", file=sys.stderr)
        return 2
    if not (cache / "sessions.json").exists():
        print(f"error: sessions.json missing in {cache}", file=sys.stderr)
        return 2

    if args.list:
        sessions = json.loads((cache / "sessions.json").read_text())
        # join classified.json activity if present
        classified_path = cache / "classified.json"
        activity_by_id: dict[str, str] = {}
        if classified_path.exists():
            for c in json.loads(classified_path.read_text()):
                activity_by_id[c["session_id"]] = c.get("activity", "?")
        for s in sessions:
            sid = s["session_id"]
            act = activity_by_id.get(sid, "?")
            if args.activity and act not in args.activity:
                continue
            print(f"{sid}\t{act}")
        return 0

    if not args.segment:
        ap.error("--segment is required (or use --list).")

    canonical = resolve_segment_id(cache, args.segment)
    if not canonical:
        print(f"error: segment '{args.segment}' not found in {cache}/sessions.json", file=sys.stderr)
        return 2

    sessions = load_session_index(cache)
    segment = sessions[canonical]
    # Add activity from classified.json if present
    classified_path = cache / "classified.json"
    if classified_path.exists():
        for c in json.loads(classified_path.read_text()):
            if c["session_id"] == canonical:
                segment["activity"] = c.get("activity", "?")
                break

    raw_sid = segment.get("raw_session_id") or canonical
    events = load_segment_events(
        raw_sid, segment["project_slug"], segment.get("start_ts"), segment.get("end_ts")
    )
    sys.stdout.write(render_segment(segment, events))
    return 0


if __name__ == "__main__":
    sys.exit(main())
