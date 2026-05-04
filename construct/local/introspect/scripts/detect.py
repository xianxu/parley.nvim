#!/usr/bin/env python3
"""
Stage 3: detect interesting moments in classified Claude Code sessions.

Reads classified.json + sessions.json from a run cache dir, walks the raw
JSONL transcripts in order per session, emits moments.jsonl — one record
per interesting moment found by one of four detectors:

  1. redirect       — user negates/redirects after an assistant action
  2. edit-after-edit — assistant edits same file twice within N=5 turns,
                      no user message between (the diff is the taste signal)
  3. endorsement    — user's first words after assistant action are positive
  4. friction       — tool_use error / permission denial; aggregates per
                      session by tool name when ≥3 denials

Detectors 5 (taste-fingerprint, needs git-diff correlation) and 6
(process-shape, cross-session aggregates) are deferred.

Sessions with activity ∈ {"skip"} are not processed.

Usage:
  detect.py --cache-dir <run-dir>
  # reads <run-dir>/sessions.json, classified.json
  # writes  <run-dir>/moments.jsonl + moments-summary.json
"""

from __future__ import annotations

import argparse
import hashlib
import json
import re
import sys
from collections import Counter, defaultdict
from dataclasses import dataclass, field
from pathlib import Path
from typing import Any, Iterable

PROJECTS_ROOT = Path.home() / ".claude" / "projects"
EDIT_AFTER_EDIT_WINDOW = 5    # max assistant turns between edits, no user turn between
EDIT_AFTER_EDIT_MIN_PAIRS = 2  # ≥2 rapid pairs (i.e. ≥3 rapid touches) per file → moment
FRICTION_MIN_DENIALS = 3       # ≥3 explicit errors per tool per session → moment

REDIRECT_LEADING = re.compile(
    r"^\s*("
    r"no[,.\s!]|no$"          # "no", "no,", "no!"
    r"|stop\b"
    r"|instead\b"
    r"|actually\b"
    r"|wait[,.\s]"
    r"|but no\b"
    r"|don'?t\b"
    r")",
    re.IGNORECASE,
)

ENDORSEMENT_LEADING = re.compile(
    r"^\s*("
    r"perfect\b|exactly\b|yes[,.\s!]|yes$"
    r"|good[,.\s!]|good$|great\b|nice\b|awesome\b"
    r"|love it\b|beautiful\b|excellent\b"
    r"|cool[,.\s!]|cool$"
    r")",
    re.IGNORECASE,
)

# Phrases inside a tool_result that signal a permission denial / friction.
FRICTION_HINTS = (
    "permission",
    "user denied",
    "operation not permitted",
    "is not allowed",
    "blocked",
    "sandbox",
)


@dataclass
class Moment:
    session_id: str
    project_slug: str
    activity: str
    type: str
    ts: str | None
    weight: int
    evidence: dict[str, Any] = field(default_factory=dict)

    def stable_id(self) -> str:
        """Short stable hash of moment-defining fields. Same inputs → same ID,
        so clusters can reference moments across re-runs.

        Activity is intentionally NOT in the hash: a session's activity can flip
        between runs (e.g., Stage 3a re-disambiguating) and we want existing
        cluster references to keep pointing at the same moment.
        """
        fp_parts = [self.session_id, self.type, self.ts or ""]
        if self.type == "edit-after-edit":
            fp_parts.append(self.evidence.get("file_path", ""))
        elif self.type == "friction":
            fp_parts.append(self.evidence.get("tool", ""))
        elif self.type in ("redirect", "endorsement"):
            # First 80 chars of the user message disambiguate intra-session repeats
            user_text = (
                self.evidence.get("user_redirect")
                or self.evidence.get("user_endorsement")
                or ""
            )
            fp_parts.append(user_text[:80])
        h = hashlib.sha1("|".join(fp_parts).encode("utf-8")).hexdigest()
        return f"m_{h[:10]}"

    def to_json(self) -> dict[str, Any]:
        return {
            "id": self.stable_id(),
            "session_id": self.session_id,
            "project_slug": self.project_slug,
            "activity": self.activity,
            "type": self.type,
            "ts": self.ts,
            "weight": self.weight,
            "evidence": self.evidence,
        }


# ── Event reading helpers ────────────────────────────────────────────────────

def extract_text(content: Any) -> str:
    """Flatten message.content into a plain-text string. str or list-of-blocks."""
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


def extract_tool_result_text(line: dict[str, Any]) -> str:
    """For user events that are tool results, pull out the result text."""
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


def assistant_text_and_tools(line: dict[str, Any]) -> tuple[str, list[dict[str, Any]]]:
    """Return (text, tool_uses) for an assistant event."""
    msg = line.get("message", {})
    text_parts: list[str] = []
    tool_uses: list[dict[str, Any]] = []
    if not isinstance(msg, dict):
        return "", []
    content = msg.get("content", [])
    if isinstance(content, list):
        for item in content:
            if not isinstance(item, dict):
                continue
            if item.get("type") == "text":
                text_parts.append(item.get("text", ""))
            elif item.get("type") == "tool_use":
                tool_uses.append(item)
    elif isinstance(content, str):
        text_parts.append(content)
    return "\n".join(text_parts), tool_uses


def load_segment_events(
    raw_session_id: str,
    project_slug: str,
    start_ts: str | None,
    end_ts: str | None,
) -> list[dict[str, Any]]:
    """Read all JSONL files in the project dir, collect events for this raw
    sessionId whose timestamps fall within [start_ts, end_ts] (inclusive),
    sort by timestamp. Used to load one segment's worth of events."""
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


# ── Detectors ────────────────────────────────────────────────────────────────

def detect_redirects_and_endorsements(
    events: list[dict[str, Any]], session_id: str, project_slug: str, activity: str
) -> Iterable[Moment]:
    """Walk events; when a user turn (non-tool-result) starts with a redirect
    or endorsement marker, emit a moment paired with the most recent assistant
    proposal/action."""
    last_assistant: dict[str, Any] | None = None
    for evt in events:
        et = evt.get("type")
        if et == "assistant":
            last_assistant = evt
            continue
        if et != "user":
            continue
        # Skip tool-result wrappers
        if evt.get("toolUseResult"):
            continue
        text = extract_text(evt.get("message", {}).get("content"))
        if not text or not text.strip():
            continue

        is_redirect = bool(REDIRECT_LEADING.match(text))
        is_endorse = bool(ENDORSEMENT_LEADING.match(text))
        if not (is_redirect or is_endorse):
            continue

        a_text, a_tools = ("", [])
        if last_assistant is not None:
            a_text, a_tools = assistant_text_and_tools(last_assistant)

        if is_redirect:
            yield Moment(
                session_id=session_id,
                project_slug=project_slug,
                activity=activity,
                type="redirect",
                ts=evt.get("timestamp"),
                weight=4,
                evidence={
                    "user_redirect": text[:600],
                    "assistant_text": a_text[:600],
                    "assistant_tool_uses": [
                        {"name": t.get("name"), "input_summary": _summarize_tool_input(t)}
                        for t in a_tools
                    ][:5],
                },
            )
        if is_endorse:
            # Endorsement of a non-trivial assistant action (had tools or non-empty text).
            # Weight tiered: tool-backed endorsements signal "the work was right";
            # text-only endorsements ("yes, go ahead") signal mere authorization
            # and are downweighted so clustering doesn't drown in them.
            if a_text.strip() or a_tools:
                weight = 2 if a_tools else 1
                yield Moment(
                    session_id=session_id,
                    project_slug=project_slug,
                    activity=activity,
                    type="endorsement",
                    ts=evt.get("timestamp"),
                    weight=weight,
                    evidence={
                        "user_endorsement": text[:300],
                        "assistant_text": a_text[:600],
                        "assistant_tool_uses": [
                            {"name": t.get("name"), "input_summary": _summarize_tool_input(t)}
                            for t in a_tools
                        ][:5],
                    },
                )


def _summarize_tool_input(tool_use: dict[str, Any]) -> str:
    """One-line summary of a tool_use input — file_path, command head, etc."""
    name = tool_use.get("name", "")
    ipt = tool_use.get("input") or {}
    if not isinstance(ipt, dict):
        return ""
    if name in ("Edit", "Write", "Read"):
        return f"file_path={ipt.get('file_path', '')}"
    if name == "Bash":
        cmd = ipt.get("command", "")
        return f"command={cmd[:120]}"
    if name == "Skill":
        return f"skill={ipt.get('skill', '')}"
    if name == "Agent":
        return f"description={ipt.get('description', '')[:80]}"
    keys = sorted(ipt.keys())[:3]
    return f"keys={keys}"


def detect_edit_after_edit(
    events: list[dict[str, Any]], session_id: str, project_slug: str, activity: str
) -> Iterable[Moment]:
    """Per (session, file): count how many times the same file was re-touched
    by the assistant within EDIT_AFTER_EDIT_WINDOW turns with no user message
    between. Emit one moment per file when count ≥ 2 — high counts are weak
    taste signal on their own (lots of editing is normal), but a tight cluster
    on a small file is a hint worth surfacing.

    The earlier per-pair emission produced ~10× the noise without proportional
    signal; downstream clustering would drown."""
    last_op_by_file: dict[str, dict[str, Any]] = {}
    user_turn_since: dict[str, bool] = defaultdict(bool)
    assistant_turn_count_since: dict[str, int] = defaultdict(int)
    pair_count: Counter = Counter()
    first_pair_ts: dict[str, str | None] = {}

    for evt in events:
        et = evt.get("type")
        if et == "user" and not evt.get("toolUseResult"):
            text = extract_text(evt.get("message", {}).get("content"))
            if text.strip():
                for fp in list(last_op_by_file.keys()):
                    user_turn_since[fp] = True
            continue
        if et != "assistant":
            continue
        _, tools = assistant_text_and_tools(evt)
        for fp_key in list(last_op_by_file.keys()):
            assistant_turn_count_since[fp_key] += 1
        for tu in tools:
            name = tu.get("name", "")
            if name not in ("Edit", "Write"):
                continue
            ipt = tu.get("input") or {}
            fp = ipt.get("file_path", "")
            if not fp:
                continue
            prev = last_op_by_file.get(fp)
            if prev is not None:
                turns_between = assistant_turn_count_since[fp]
                no_user = not user_turn_since[fp]
                if no_user and turns_between <= EDIT_AFTER_EDIT_WINDOW:
                    pair_count[fp] += 1
                    first_pair_ts.setdefault(fp, evt.get("timestamp"))
            last_op_by_file[fp] = tu
            user_turn_since[fp] = False
            assistant_turn_count_since[fp] = 0

    for fp, count in pair_count.items():
        if count < EDIT_AFTER_EDIT_MIN_PAIRS:
            # Single re-edit pair (just two consecutive touches) is too common
            # to be useful taste signal — every edit-then-test-then-edit cycle
            # would fire. Require ≥2 rapid pairs (i.e. ≥3 rapid touches) before
            # a file-level cluster looks like flailing or iteration intensity.
            continue
        yield Moment(
            session_id=session_id,
            project_slug=project_slug,
            activity=activity,
            type="edit-after-edit",
            ts=first_pair_ts.get(fp),
            weight=min(2 + count // 2, 6),
            evidence={
                "file_path": fp,
                "rapid_re_edit_count": count,
            },
        )


def detect_friction(
    events: list[dict[str, Any]], session_id: str, project_slug: str, activity: str
) -> Iterable[Moment]:
    """Aggregate tool errors / permission denials per tool name. Emit one
    moment per tool that crossed the threshold (≥3 denials).

    Detection rule: require explicit error signal. One of:
      (a) toolUseResult.is_error == True
      (b) result text starts with /Exit code [1-9]/ AND mentions a friction hint
      (c) result text starts with "Error:" / "error:" / "ERROR:"
    Without one of those, FRICTION_HINTS in result text alone is a false positive
    (file contents and command outputs routinely contain those words).
    """
    tool_name_by_id: dict[str, str] = {}
    for evt in events:
        if evt.get("type") != "assistant":
            continue
        _, tools = assistant_text_and_tools(evt)
        for tu in tools:
            tid = tu.get("id")
            if tid:
                tool_name_by_id[tid] = tu.get("name", "?")

    denials_by_tool: dict[str, int] = Counter()
    samples: dict[str, str] = {}
    for evt in events:
        if evt.get("type") != "user":
            continue
        tur = evt.get("toolUseResult")
        if not tur:
            continue
        rt = extract_tool_result_text(evt)
        if not rt:
            continue
        rt_low = rt.lower()
        head = rt[:200].lower()
        is_err_flag = isinstance(tur, dict) and bool(tur.get("is_error"))
        starts_with_error = head.lstrip().startswith(("error:", "exit code"))
        has_friction_hint = any(h in rt_low for h in FRICTION_HINTS)
        # Explicit-error gate.
        if not is_err_flag and not (starts_with_error and has_friction_hint):
            continue

        msg = evt.get("message", {})
        tu_id: str | None = None
        if isinstance(msg, dict):
            c = msg.get("content")
            if isinstance(c, list):
                for it in c:
                    if isinstance(it, dict) and it.get("tool_use_id"):
                        tu_id = it["tool_use_id"]
                        break
        tool = tool_name_by_id.get(tu_id, "?") if tu_id else "?"
        # Skip the unknown bucket: schema drift or partial events can park real
        # errors here without a useful tool label, and emitting "tool=? error
        # happened 5 times" is actionably useless. If this fires often it's a
        # bug, not a moment.
        if tool == "?":
            continue
        denials_by_tool[tool] += 1
        if tool not in samples:
            samples[tool] = rt[:300]

    for tool, count in denials_by_tool.items():
        if count < FRICTION_MIN_DENIALS:
            continue
        yield Moment(
            session_id=session_id,
            project_slug=project_slug,
            activity=activity,
            type="friction",
            ts=None,
            weight=min(count, 10),
            evidence={
                "tool": tool,
                "denial_count": count,
                "sample_error": samples.get(tool, ""),
            },
        )


# ── Driver ───────────────────────────────────────────────────────────────────

def run_all_detectors(
    events: list[dict[str, Any]], session_id: str, project_slug: str, activity: str
) -> list[Moment]:
    out: list[Moment] = []
    out.extend(detect_redirects_and_endorsements(events, session_id, project_slug, activity))
    out.extend(detect_edit_after_edit(events, session_id, project_slug, activity))
    out.extend(detect_friction(events, session_id, project_slug, activity))
    return out


def main() -> int:
    ap = argparse.ArgumentParser(description="Detect moments in classified Claude Code sessions.")
    ap.add_argument("--cache-dir", required=True, help="Run cache dir produced by normalize+classify.")
    args = ap.parse_args()

    cache = Path(args.cache_dir).expanduser()
    sessions = json.loads((cache / "sessions.json").read_text())
    classified = json.loads((cache / "classified.json").read_text())

    sessions_by_id = {s["session_id"]: s for s in sessions}

    moments_path = cache / "moments.jsonl"
    summary_by_session: dict[str, Counter] = {}
    total = 0
    skipped = 0
    with moments_path.open("w") as out:
        for c in classified:
            sid = c["session_id"]
            activity = c["activity"]
            if activity == "skip":
                skipped += 1
                continue
            sess = sessions_by_id.get(sid)
            if sess is None:
                skipped += 1
                continue
            project_slug = sess["project_slug"]
            # Segments: load events bounded by the segment's time range and
            # filtered to its raw sessionId. Older sessions.json (pre-segment)
            # may not have raw_session_id; fall back to session_id then.
            raw_sid = sess.get("raw_session_id") or sid
            events = load_segment_events(
                raw_sid, project_slug, sess.get("start_ts"), sess.get("end_ts")
            )
            moments = run_all_detectors(events, sid, project_slug, activity)
            counts: Counter = Counter()
            for m in moments:
                out.write(json.dumps(m.to_json()) + "\n")
                counts[m.type] += 1
                total += 1
            summary_by_session[sid] = counts

    summary = {
        "total_moments": total,
        "sessions_processed": len(classified) - skipped,
        "sessions_skipped": skipped,
        "by_type": dict(Counter(t for s in summary_by_session.values() for t in s.elements())),
    }
    (cache / "moments-summary.json").write_text(json.dumps(summary, indent=2))
    print(json.dumps(summary, indent=2))
    return 0


if __name__ == "__main__":
    sys.exit(main())
