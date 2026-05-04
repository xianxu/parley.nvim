#!/usr/bin/env python3
"""
Classify each session in sessions.json into one of six activity buckets.

Stage 2 of the /xx-introspect extract pipeline. Rule-based scoring on signals
already captured by normalize.py: slash commands, tool counts, file paths
written, first user message keywords. Confident classifications stand;
ambiguous ones are flagged for the orchestrating skill to disambiguate
via a single LLM call.

Activity buckets: code-review, brainstorming, planning, debugging,
implementation, exploration.

Sessions with assistant_message_count == 0 (or no real interaction) are
emitted with activity="skip" and a reason — not a classification failure.

Usage:
  classify.py --in <run-dir>/sessions.json --out <run-dir>/classified.json
"""

from __future__ import annotations

import argparse
import json
import sys
from collections import Counter
from dataclasses import dataclass
from pathlib import Path
from typing import Any, Callable

ACTIVITIES = (
    "code-review",
    "brainstorming",
    "planning",
    "debugging",
    "implementation",
    "exploration",
)

# Confidence thresholds.
MIN_TOP_SCORE = 5         # top activity must reach this absolute score
MIN_MARGIN = 3            # top must beat second by at least this much


@dataclass
class Rule:
    """One signal: matches against a session, awards `weight` to `activity` with `evidence`."""
    activity: str
    name: str
    weight: int
    match: Callable[[dict[str, Any]], bool]


def _kw(text: str | None, *patterns: str) -> bool:
    """Case-insensitive substring match against one of patterns."""
    if not text:
        return False
    t = text.lower()
    return any(p in t for p in patterns)


def _slash_in(slash_commands: list[str], *names: str) -> bool:
    """True if any of the listed slash commands was invoked. Names are matched
    by suffix so /superpowers-brainstorming and /brainstorm both hit on 'brainstorm'."""
    if not slash_commands:
        return False
    targets = {n.lstrip("/").lower() for n in names}
    for cmd in slash_commands:
        bare = cmd.lstrip("/").lower()
        if bare in targets:
            return True
        for t in targets:
            if bare.endswith(t):
                return True
    return False


def _path_under_plans(paths: list[str]) -> bool:
    return any("/plans/" in p for p in paths)


def _re_edit_ratio(s: dict[str, Any]) -> float:
    """Total Edit calls divided by distinct files edited. >3 suggests debugging."""
    edits = s.get("tool_calls_by_name", {}).get("Edit", 0)
    distinct = max(len(s.get("files_edited", [])), 1)
    return edits / distinct


# ── Rule definitions ─────────────────────────────────────────────────────────

RULES: list[Rule] = [
    # code-review
    Rule("code-review", "slash:/review|/security-review|/ultrareview", 10,
         lambda s: _slash_in(s.get("slash_commands", []), "review", "security-review", "ultrareview")),
    Rule("code-review", "agent-spawn first-msg: 'you are a [X] reviewer'", 8,
         lambda s: _kw(s.get("first_user_message"),
                       "you are a code reviewer", "you are a security reviewer",
                       "you are a documentation reviewer", "you are a reviewer",
                       "review the following diff", "review the diff")),
    Rule("code-review", "first-msg keyword: review/audit/PR", 3,
         lambda s: _kw(s.get("first_user_message"), "audit ", "feedback on", "look at this pr", "code review", "review the pr")),
    Rule("code-review", "read-dominant, few writes", 2,
         lambda s: (
             s.get("tool_calls_by_name", {}).get("Read", 0) >= 5
             and (len(s.get("files_written", [])) + len(s.get("files_edited", []))) <= 2
         )),

    # brainstorming
    Rule("brainstorming", "slash:/brainstorm or superpowers-brainstorming", 10,
         lambda s: _slash_in(s.get("slash_commands", []), "brainstorm", "brainstorming", "superpowers-brainstorming")),
    Rule("brainstorming", "first-msg keyword: brainstorm/think/idea", 4,
         lambda s: _kw(s.get("first_user_message"),
                       "brainstorm", "let's think", "what if we",
                       "i'm thinking", "i was thinking", "thoughts on")),
    Rule("brainstorming", "talk-heavy, no file work", 3,
         lambda s: (
             (len(s.get("files_written", [])) + len(s.get("files_edited", []))) == 0
             and s.get("user_message_count", 0) >= 3
             and s.get("tool_call_count", 0) <= max(s.get("user_message_count", 0) * 2, 5)
         )),

    # planning
    Rule("planning", "slash:/plan or writing-plans/executing-plans", 10,
         lambda s: _slash_in(s.get("slash_commands", []), "plan", "writing-plans", "executing-plans",
                             "superpowers-writing-plans", "superpowers-executing-plans")),
    Rule("planning", "wrote into workshop/plans/", 5,
         lambda s: _path_under_plans(s.get("files_written", []) + s.get("files_edited", []))),
    Rule("planning", "first-msg keyword: plan/design/spec/approach", 3,
         lambda s: _kw(s.get("first_user_message"), "plan ", "design doc", "let's plan", "approach for", "write a plan", "spec for")),
    Rule("planning", "TaskCreate dominant", 2,
         lambda s: (
             s.get("tool_calls_by_name", {}).get("TaskCreate", 0) >= 5
             and s.get("tool_calls_by_name", {}).get("TaskCreate", 0)
             >= s.get("tool_calls_by_name", {}).get("Edit", 0) // 4
         )),

    # debugging
    Rule("debugging", "slash:/debug or systematic-debugging", 10,
         lambda s: _slash_in(s.get("slash_commands", []), "debug", "systematic-debugging", "superpowers-systematic-debugging")),
    Rule("debugging", "first-msg keyword: bug/error/broken/failing", 3,
         lambda s: _kw(s.get("first_user_message"), "bug", "broken", "doesn't work", "fails", "failing", "error:", "investigate why", "why is")),
    Rule("debugging", "high re-edit ratio (>3 edits per file)", 3,
         lambda s: _re_edit_ratio(s) > 3 and s.get("tool_calls_by_name", {}).get("Edit", 0) >= 10),

    # implementation
    Rule("implementation", "first-msg keyword: implement/build/add", 4,
         lambda s: _kw(s.get("first_user_message"), "implement", "let's build", "let's work on", "start working on", "write the ", "fix the ", "make it ")),
    Rule("implementation", "first-msg work-on-issue pattern", 4,
         lambda s: _kw(s.get("first_user_message"), "work on issue", "issue#", "issue #", "work on workshop")),
    Rule("implementation", "many file writes/edits (≥5)", 2,
         lambda s: (len(s.get("files_written", [])) + len(s.get("files_edited", []))) >= 5),
    Rule("implementation", "edit-heavy (Edit > Read)", 1,
         lambda s: (
             s.get("tool_calls_by_name", {}).get("Edit", 0)
             > s.get("tool_calls_by_name", {}).get("Read", 0)
             and s.get("tool_calls_by_name", {}).get("Edit", 0) >= 5
         )),
    Rule("implementation", "substantial work (≥50 tool calls)", 1,
         lambda s: s.get("tool_call_count", 0) >= 50),

    # exploration
    # NOTE: this keyword set is broad on purpose — many user openers are Q&A-shaped.
    # The weight (4) is balanced against brainstorming(4) and implementation(4)
    # so structural rules (no-writes, Q&A shape) decide the tie. If you raise
    # this weight, retune brainstorming and implementation in lockstep or
    # exploration will start winning over them on talk-heavy sessions.
    Rule("exploration", "first-msg keyword: explain/walk me through/look at", 4,
         lambda s: _kw(s.get("first_user_message"),
                       "walk me through", "explain", "tell me about", "what is ", "what does",
                       "how does", "look at this", "reading ", "take a look",
                       "how do i", "how to ", "tell me how", "can you read", "can you access",
                       "check last", "check recent", "show me", "what's the", "what are the",
                       "where did i", "where do i", "where is ", "find all my", "find my",
                       "what are ", "i wonder", "i remember")),
    Rule("exploration", "Q&A short session shape", 3,
         lambda s: (
             s.get("user_message_count", 0) <= 25
             and len(s.get("files_written", [])) == 0
             and len(s.get("files_edited", [])) <= 1
             and s.get("tool_call_count", 0) < 50
             and s.get("assistant_message_count", 0) >= 3
         )),
    Rule("exploration", "read-dominant, no writes", 2,
         lambda s: (
             s.get("tool_calls_by_name", {}).get("Read", 0) >= 3
             and len(s.get("files_written", [])) == 0
             and len(s.get("files_edited", [])) == 0
         )),
    Rule("exploration", "research tools used (WebSearch/WebFetch/ToolSearch)", 1,
         lambda s: any(s.get("tool_calls_by_name", {}).get(t, 0) > 0
                       for t in ("WebSearch", "WebFetch", "ToolSearch"))),
]


def is_degenerate(s: dict[str, Any]) -> str | None:
    """Return a skip reason if the session is too thin to classify, else None."""
    if s.get("assistant_message_count", 0) == 0:
        return "no assistant messages"
    return None


def classify_one(s: dict[str, Any]) -> dict[str, Any]:
    skip = is_degenerate(s)
    if skip:
        return {
            "session_id": s["session_id"],
            "activity": "skip",
            "confidence": None,
            "scores": {a: 0 for a in ACTIVITIES},
            "evidence": [],
            "skip_reason": skip,
        }

    scores: dict[str, int] = {a: 0 for a in ACTIVITIES}
    evidence: dict[str, list[str]] = {a: [] for a in ACTIVITIES}
    for rule in RULES:
        try:
            if rule.match(s):
                scores[rule.activity] += rule.weight
                evidence[rule.activity].append(f"+{rule.weight} {rule.name}")
        except Exception as e:
            evidence[rule.activity].append(f"!error in {rule.name}: {e}")

    ranked = sorted(scores.items(), key=lambda kv: kv[1], reverse=True)
    top, top_score = ranked[0]
    second_score = ranked[1][1]

    confident = top_score >= MIN_TOP_SCORE and (top_score - second_score) >= MIN_MARGIN
    activity = top if confident else "ambiguous"
    return {
        "session_id": s["session_id"],
        "activity": activity,
        "confidence": "high" if confident else "low",
        "scores": scores,
        "evidence": {a: evs for a, evs in evidence.items() if evs},
        "top_two": [{"activity": ranked[0][0], "score": ranked[0][1]},
                    {"activity": ranked[1][0], "score": ranked[1][1]}],
    }


def main() -> int:
    ap = argparse.ArgumentParser(description="Classify Claude Code sessions by activity.")
    ap.add_argument("--in", dest="inp", required=True, help="Path to sessions.json from normalize.py.")
    ap.add_argument("--out", required=True, help="Output path for classified.json.")
    args = ap.parse_args()

    sessions = json.loads(Path(args.inp).read_text())
    classified = [classify_one(s) for s in sessions]

    out_path = Path(args.out)
    out_path.parent.mkdir(parents=True, exist_ok=True)
    out_path.write_text(json.dumps(classified, indent=2))

    # Summary to stderr
    dist = Counter(c["activity"] for c in classified)
    conf = Counter(c["confidence"] for c in classified)
    print(f"classified {len(classified)} sessions", file=sys.stderr)
    print(f"  distribution: {dict(dist)}", file=sys.stderr)
    print(f"  confidence: {dict(conf)}", file=sys.stderr)
    print(json.dumps({"total": len(classified), "distribution": dict(dist), "confidence": dict(conf)}, indent=2))
    return 0


if __name__ == "__main__":
    sys.exit(main())
