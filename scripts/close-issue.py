#!/usr/bin/env python3
# close-issue.py — perform AGENTS.md §5's mechanical closing steps.
#
# Modes:
#   milestone close: ISSUE=15 MILESTONE=M4 ACTUAL=2.5 [VERIFIED="..."]
#   issue close:     ISSUE=15 ACTUAL=7 [VERIFIED="..."]
#
# Reads inputs from env (set by Make recipe). Edits files in place.
# Does NOT commit — the agent commits, usually bundling the close with other work.
#
# Conventions assumed (see nous/AGENTS.md §5 + construct/datatype/project.md):
#   - Issue file at $WF_ISSUES_DIR/<padded-id>-*.md, YAML frontmatter with `status:`.
#   - Issue ## Plan items shaped like "- [ ] M4 — ..." (optional; project-tracked
#     issues live in a project file's ## tasks).
#   - Project file at $BRAIN_DIR/data/project/<slug>.md, found by grepping the
#     ref `[<repo>#<id>]` across all project files.
#   - Project task line shaped like "- [ ] title [<repo>#<id> M4]".
#   - Project detail block anchored as <a id="<repo>-<id>-<m-lower>"></a>,
#     fields **actual:** and **closed:** set on close.

import os
import re
import sys
import glob
import subprocess
from datetime import date, datetime, timedelta, timezone
from pathlib import Path
from typing import NoReturn

ISSUE     = os.environ.get('ISSUE', '').strip()
MILESTONE = os.environ.get('MILESTONE', '').strip()
ACTUAL    = os.environ.get('ACTUAL', '').strip()
VERIFIED  = os.environ.get('VERIFIED', '').strip()
BRAIN_DIR = (os.environ.get('BRAIN_DIR') or '../brain').strip()
WF_ISSUES_DIR = os.environ.get('WF_ISSUES_DIR', 'workshop/issues').strip()
DRY   = os.environ.get('DRY', '') == '1'
FORCE = os.environ.get('FORCE', '') == '1'

RED, GREEN, YELLOW, CYAN, RESET = '\033[1;31m', '\033[1;32m', '\033[1;33m', '\033[1;36m', '\033[0m'
def die(msg) -> NoReturn:  print(f"{RED}Error: {msg}{RESET}", file=sys.stderr); sys.exit(1)
def info(msg): print(f"{CYAN}==>{RESET} {msg}", file=sys.stderr)
def ok(msg):   print(f"  {GREEN}[ok]{RESET} {msg}", file=sys.stderr)
def warn(msg): print(f"  {YELLOW}[!]{RESET} {msg}", file=sys.stderr)

# ── Warmup: print procedure on first N invocations per shell session ─────────
# An agent that has never read the v3 procedure can guess ACTUAL=8 and slip
# through unchallenged. The warmup pattern surfaces the procedure in their
# transcript on the first 2 invocations from a given shell session, so by
# the third close they've seen the contract twice. After that, silent mode.
#
# Tracking key: process group ID. Stable across subshells of the same
# controlling shell; resets on new shell / new Claude Code session.

WARMUP_THRESHOLD = 2  # show explanation this many times per shell session


def warmup_state_path() -> Path:
    try:
        sess = os.getpgrp()
    except OSError:
        sess = 0
    return Path("/tmp") / f"close-issue-warmup-{sess}"


def warmup_count() -> int:
    p = warmup_state_path()
    try:
        return int(p.read_text().strip())
    except (FileNotFoundError, ValueError, OSError):
        return 0


def warmup_increment():
    p = warmup_state_path()
    try:
        p.write_text(str(warmup_count() + 1))
    except OSError:
        pass


def print_semantic_warmup():
    """Print the close-issue contract. Shown on the first WARMUP_THRESHOLD
    invocations per shell session, regardless of whether all params are
    present — so an agent that 'guesses through' still has the procedure
    in their transcript. After the threshold, silent."""
    n = warmup_count()
    if n >= WARMUP_THRESHOLD:
        return
    msg = []
    msg.append(f"{CYAN}── close-issue contract ── (warmup {n + 1}/{WARMUP_THRESHOLD}){RESET}")
    msg.append("")
    msg.append(f"  Closing an issue records two values that feed into velocity")
    msg.append(f"  calibration. Both must be earned, not guessed:")
    msg.append("")
    msg.append(f"  {CYAN}ACTUAL{RESET}   = focused dev-hours, derived via the v3 procedure.")
    msg.append(f"             Run active-time-v3.py over the issue's commit window")
    msg.append(f"             with --commit-weight 1.0; read the per-issue total.")
    msg.append(f"             See brain/data/life/42shots/velocity/baseline-v3.md.")
    msg.append(f"             Pass FORCE=1 only if you genuinely cannot run the script")
    msg.append(f"             (e.g., wontfix issue with no commits) — record the reason.")
    msg.append("")
    msg.append(f"  {CYAN}VERIFIED{RESET} = one-line evidence of behavior matching done-when.")
    msg.append(f"             'tests pass' beats 'code written'. See AGENTS.md §5.")
    msg.append("")
    msg.append(f"  This warmup auto-suppresses after {WARMUP_THRESHOLD} invocations per shell session.")
    msg.append("")
    print("\n".join(msg), file=sys.stderr)
    warmup_increment()


print_semantic_warmup()


# ── Validate inputs ──────────────────────────────────────────────────────────
if not ISSUE: die("ISSUE=<n> required")
if not ISSUE.isdigit(): die(f"ISSUE must be numeric, got '{ISSUE}'")
issue_id = ISSUE.zfill(6)
mode = 'milestone' if MILESTONE else 'issue'
if ACTUAL:
    try: float(ACTUAL)
    except ValueError: die(f"ACTUAL must be a number, got '{ACTUAL}'")


# Sanity cap for the commit window. No real issue spans more than ~1 month
# of focused work; if the earliest match is older, it's almost always a
# fork-upstream collision (forked repo's history reusing the same #N for
# a different historical issue) rather than legitimate ancient work.
WINDOW_CAP_DAYS = 31


def git_issue_commit_window(issue_num: str):
    """Return (first_iso, last_iso) for commits whose *subject* opens
    with #issue_num (optionally prefixed with 'close '), capped at
    WINDOW_CAP_DAYS in the past.

    Subject-anchored, not whole-message: forked-upstream history may
    contain commits referencing the same number in their *body*
    (e.g., 'docs: setup snippet (issue: #123)' from a 2-year-old
    upstream commit) but not the subject. Whole-message --grep would
    pull those in and stretch the window by years, which then bloats
    the auto-discovered peer-issue list.

    Returns (None, None) if no in-window subject anchor exists; the
    explainer falls through to its FORCE=1 path.
    """
    # Loose --grep first to narrow candidates; precise subject-anchor
    # check happens in Python below. Git's POSIX regex doesn't support
    # \b for word boundaries reliably across platforms, so we filter
    # subjects ourselves.
    try:
        out = subprocess.check_output(
            ["git", "log", f"--grep=#{issue_num}", "--reverse",
             "--pretty=%aI%x00%H%x00%s"],
            text=True, stderr=subprocess.DEVNULL).strip()
    except subprocess.CalledProcessError:
        return None, None
    if not out:
        return None, None
    subject_re = re.compile(rf"^(close\s+)?#{issue_num}(?!\d)")
    matches = []  # [(iso, sha)]
    for line in out.splitlines():
        parts = line.split("\x00", 2)
        if len(parts) != 3:
            continue
        iso, sha, subject = parts
        if subject_re.match(subject):
            matches.append((iso, sha))
    if not matches:
        return None, None
    cap_iso = (datetime.now(timezone.utc)
               - timedelta(days=WINDOW_CAP_DAYS)).isoformat(timespec='seconds')
    recent = [(iso, sha) for iso, sha in matches if iso >= cap_iso]
    if not recent:
        return None, None
    first_iso, first_sha = recent[0]
    last_iso = recent[-1][0]
    # v3 segments span [parent_commit_time, this_commit_time]. Use the
    # parent of the first match as window-start so the first segment
    # can extend backward and capture pre-commit work (typing,
    # thinking). Still bounded by the cap.
    try:
        parent_iso = subprocess.check_output(
            ["git", "log", "-1", "--pretty=%aI", f"{first_sha}^"],
            text=True, stderr=subprocess.DEVNULL).strip()
        if parent_iso and parent_iso >= cap_iso:
            return parent_iso, last_iso
    except subprocess.CalledProcessError:
        pass
    return first_iso, last_iso


def discover_window_issues(since_iso: str, until_iso: str, primary: str) -> list[str]:
    """Find every distinct issue number referenced in commit subjects within
    [since, until]. Always includes `primary` even if no commits match it.

    The active-time-v3 algorithm requires every anchored issue in the window
    to be passed via --issue; otherwise peer-issue-anchored segments fall
    into mention-fallback and inflate the closing issue's share. Auto-
    discovering from the window's commit subjects produces the right default
    set so the agent isn't manually grepping git log to assemble the command.
    """
    try:
        out = subprocess.check_output(
            ["git", "log", f"--since={since_iso}", f"--until={until_iso}",
             "--pretty=%s"], text=True, stderr=subprocess.DEVNULL).strip()
    except subprocess.CalledProcessError:
        return [primary]
    found = sorted({m for line in out.splitlines()
                    for m in re.findall(r"#(\d+)\b", line)},
                   key=int)
    if primary not in found:
        found.append(primary)
    return found


def explain_actual() -> NoReturn:
    repo_dir = Path.cwd().resolve()
    repo_slug = repo_dir.name
    transcript_slug_repo = f"-Users-xianxu-workspace-{repo_slug}"
    transcript_slug_brain = "-Users-xianxu-workspace-brain"
    first_ts, last_ts = git_issue_commit_window(ISSUE)
    msg = []
    msg.append(f"{RED}ACTUAL=<hours> required for {mode} close (§5 step 3).{RESET}")
    msg.append("")
    msg.append(f"  {CYAN}Semantic:{RESET}  focused dev-hours spent on this {mode} (#{ISSUE}).")
    msg.append(f"             Not wall-clock; not 'hours since I created the issue.'")
    msg.append(f"             Method: v3 commit-anchored segment-local attribution.")
    msg.append(f"             See brain/data/life/42shots/velocity/baseline-v3.md.")
    msg.append("")
    if first_ts and last_ts:
        window_issues = discover_window_issues(first_ts, last_ts, ISSUE)
        issue_flags = " ".join(f"--issue {n}" for n in window_issues)
        msg.append(f"  {CYAN}Compute via:{RESET}")
        msg.append(f"    python3 construct/local/issues/active-time-v3.py \\")
        msg.append(f"      --dir ~/.claude/projects/{transcript_slug_repo} \\")
        msg.append(f"      --dir ~/.claude/projects/{transcript_slug_brain} \\")
        msg.append(f"      --git-repo {repo_dir} \\")
        msg.append(f"      --since {first_ts} --until {last_ts} \\")
        msg.append(f"      {issue_flags} \\")
        msg.append(f"      --commit-weight 1.0 --threshold-min 15 --include-assistant")
        msg.append(f"")
        peers = [n for n in window_issues if n != ISSUE]
        if peers:
            msg.append(f"  Issues auto-discovered from #refs in window subjects: "
                       f"#{ISSUE} + peers #{', #'.join(peers)}.")
            msg.append(f"  Why all of them: v3 anchors segments by commit-subject issue ref;")
            msg.append(f"  unrecognized refs fall back to mention-fallback, inflating #{ISSUE} by 3-10x.")
            msg.append(f"  If a discovered peer looks unrelated to real work, drop its --issue flag.")
            msg.append(f"")
        msg.append(f"  The 'per-issue totals' line for #{ISSUE} in the output is your ACTUAL.")
        msg.append(f"  (Round to nearest 0.5; under 1 hr keep one decimal: 0.45 → 0.5.)")
    else:
        msg.append(f"  {YELLOW}No commits matching #{ISSUE} found — compute hours by judgment{RESET}")
        msg.append(f"  {YELLOW}or wait until commits land. Set FORCE=1 to bypass.{RESET}")
    msg.append("")
    extra = f' MILESTONE={MILESTONE}' if MILESTONE else ''
    msg.append(f"  {CYAN}Then re-run:{RESET}")
    msg.append(f"    make close-issue ISSUE={ISSUE}{extra} ACTUAL=<hours> VERIFIED='<evidence>'")
    msg.append("")
    msg.append(f"  Set FORCE=1 to bypass this prerequisite check (record reason in VERIFIED).")
    print("\n".join(msg), file=sys.stderr)
    sys.exit(1)


def explain_verified() -> NoReturn:
    msg = []
    msg.append(f"{RED}VERIFIED=\"<one-line evidence>\" required for {mode} close (§5 step 1).{RESET}")
    msg.append("")
    msg.append(f"  {CYAN}Semantic:{RESET}  one-line evidence the work meets the issue's done-when.")
    msg.append(f"             Behavior, not artifacts: 'tests pass' beats 'code written'.")
    msg.append("")
    msg.append(f"  {CYAN}Examples:{RESET}")
    msg.append(f"    VERIFIED='ran make test, all green'")
    msg.append(f"    VERIFIED='e2e flow X→Y verified manually'")
    msg.append(f"    VERIFIED='code-review subagent, all Important addressed in <sha>'")
    msg.append(f"    VERIFIED='ran make nous-test-bootstrap, ROUND-TRIP-OK in 2:34'")
    msg.append("")
    extra = f' MILESTONE={MILESTONE}' if MILESTONE else ''
    actual_arg = f' ACTUAL={ACTUAL}' if ACTUAL else ' ACTUAL=<hours>'
    msg.append(f"  {CYAN}Then re-run:{RESET}")
    msg.append(f"    make close-issue ISSUE={ISSUE}{extra}{actual_arg} VERIFIED='<evidence>'")
    msg.append("")
    msg.append(f"  Set FORCE=1 only if there's genuinely no behavior to verify.")
    print("\n".join(msg), file=sys.stderr)
    sys.exit(1)


# §5 applies to both milestone and issue close — ACTUAL + VERIFIED required for both.
if not ACTUAL and not FORCE:
    explain_actual()
if not VERIFIED and not FORCE:
    explain_verified()

TODAY = date.today().isoformat()

# ── Locate issue file ────────────────────────────────────────────────────────
candidates = sorted(glob.glob(f"{WF_ISSUES_DIR}/{issue_id}-*.md"))
if not candidates: die(f"no issue file matches {WF_ISSUES_DIR}/{issue_id}-*.md")
if len(candidates) > 1: die(f"multiple issue files match: {candidates}")
issue_path = Path(candidates[0])
issue_text = issue_path.read_text()

repo_name = Path(subprocess.check_output(['git', 'rev-parse', '--show-toplevel'], text=True).strip()).name

fm_match = re.match(r"^---\n(.*?)\n---\n(.*)$", issue_text, re.DOTALL)
if not fm_match: die(f"no YAML frontmatter in {issue_path}")
fm, body = fm_match.group(1), fm_match.group(2)

_status_m = re.search(r"^status:\s*(.*)$", fm, re.MULTILINE)
current_status = _status_m.group(1).strip() if _status_m else ''
if mode == 'issue' and current_status == 'done' and not FORCE:
    die(f"{repo_name}#{ISSUE} is already status: done — set FORCE=1 to re-run")

# ── Commit window + atlas check ──────────────────────────────────────────────
ref_subject = f"#{ISSUE}" + (f" {MILESTONE}" if MILESTONE else "")
git_log = subprocess.check_output(['git', 'log', '--reverse', '--format=%H %ci %s'], text=True).splitlines()
matching = [l for l in git_log if ref_subject in l]
first_sha = None
if matching:
    first_sha = matching[0].split(' ', 1)[0]
    info(f"commit window: {first_sha[:8]} → HEAD ({len(matching)} commit{'s' if len(matching)!=1 else ''} reference '{ref_subject}')")
else:
    warn(f"no commits reference '{ref_subject}' on this branch")

if first_sha:
    diff_files = subprocess.run(
        ['git', 'diff', '--name-only', f"{first_sha}^", 'HEAD'],
        capture_output=True, text=True
    ).stdout.strip().splitlines()
    atlas_changed = [f for f in diff_files if f.startswith('atlas/')]
    non_atlas = [f for f in diff_files if not f.startswith('atlas/')]
    if not atlas_changed and not FORCE:
        # Surface candidates so the agent can pick the right atlas file to update
        atlas_files = sorted(glob.glob('atlas/*.md'))
        from collections import Counter
        top_paths: Counter[str] = Counter()
        for f in non_atlas:
            parts = f.split('/', 2)
            top_paths['/'.join(parts[:2]) if len(parts) > 1 else parts[0]] += 1
        msg = [f"no atlas/ changes in {first_sha[:8]}..HEAD (§5 step 5)."]
        if atlas_files:
            msg.append("  Existing atlas files (pick the one matching new surface):")
            msg += [f"    {a}" for a in atlas_files]
        if top_paths:
            msg.append("  Code paths changed in this window:")
            msg += [f"    {p} ({c} file{'s' if c != 1 else ''})" for p, c in top_paths.most_common(10)]
        msg.append("  Update atlas where this work introduces architectural surface,")
        msg.append("  or set FORCE=1 with VERIFIED rationale (e.g., 'pure bugfix, no new surface').")
        die("\n".join(msg))

# ── Edit issue file ──────────────────────────────────────────────────────────
new_fm, new_body = fm, body

if mode == 'milestone':
    # "- [ ] M4 — ..." → "- [x] M4 — ..."   (also from [.] blocked)
    pat = re.compile(rf"^(- )\[[ .]\]( {re.escape(MILESTONE)}\b)", re.MULTILINE)
    new_body, n = pat.subn(r"\1[x]\2", new_body)
    if n: ok(f"ticked {MILESTONE} in {issue_path.name} ## Plan")
    else: warn(f"no '- [ ] {MILESTONE}' in {issue_path.name} (project-tracked issue?)")

elif mode == 'issue':
    plan_match = re.search(r"^## Plan\s*\n(.*?)(?=^## |\Z)", new_body, re.MULTILINE | re.DOTALL)
    if plan_match:
        unchecked = re.findall(r"^- \[[ .]\] .*$", plan_match.group(1), re.MULTILINE)
        if unchecked and not FORCE:
            die(f"{issue_path.name} ## Plan has {len(unchecked)} unchecked item(s):\n  "
                + "\n  ".join(unchecked) + "\n  (set FORCE=1 to close anyway)")

    def fm_set(field, value):
        global new_fm
        if re.search(rf"^{field}:", new_fm, re.MULTILINE):
            new_fm = re.sub(rf"^{field}:.*$", f"{field}: {value}", new_fm, flags=re.MULTILINE)
        else:
            new_fm = new_fm.rstrip() + f"\n{field}: {value}"

    fm_set('status', 'done')
    if ACTUAL: fm_set('actual_hours', ACTUAL)
    fm_set('updated', TODAY)
    ok(f"flipped {issue_path.name} → status: done"
       + (f", actual_hours: {ACTUAL}" if ACTUAL else ""))

if VERIFIED:
    log_line = f"- {TODAY}: closed" + (f" {MILESTONE}" if MILESTONE else "") + f" — {VERIFIED}"
    if re.search(r"^## Log\s*$", new_body, re.MULTILINE):
        new_body = re.sub(r"(^## Log\s*\n)(\s*\n)?", rf"\1\n{log_line}\n", new_body, count=1, flags=re.MULTILINE)
    else:
        new_body = new_body.rstrip() + f"\n\n## Log\n\n{log_line}\n"
    ok("appended verification line to ## Log")

new_issue_text = f"---\n{new_fm}\n---\n{new_body}"

# ── Locate + edit project file ───────────────────────────────────────────────
project_edit = None
proj_glob = f"{BRAIN_DIR}/data/project/*.md"
ref_marker = f"[{repo_name}#{ISSUE}"  # matches "[charon#13]" and "[charon#13 M2]"
proj_files = [p for p in glob.glob(proj_glob) if ref_marker in Path(p).read_text()]

if not proj_files:
    warn(f"no project in {proj_glob} references {repo_name}#{ISSUE} — skipping project update")
elif len(proj_files) > 1:
    warn(f"multiple project files reference {repo_name}#{ISSUE}: {proj_files} — skipping (PROJECT= override not implemented)")
else:
    proj_path = Path(proj_files[0])
    pt = proj_path.read_text()
    new_pt = pt

    if mode == 'milestone':
        # Tick "- [ ] title [<repo>#<id> M4]" (any state except already [x])
        task_pat = re.compile(
            rf"^(- )\[[ .\-~]\](.*?\[{re.escape(repo_name)}#{ISSUE} {re.escape(MILESTONE)}\])",
            re.MULTILINE
        )
        new_pt, n = task_pat.subn(r"\1[x]\2", new_pt)
        if n: ok(f"ticked [{repo_name}#{ISSUE} {MILESTONE}] in {proj_path.name}")
        else: warn(f"no task line for [{repo_name}#{ISSUE} {MILESTONE}] in {proj_path.name}")

        # Update detail block <a id="<repo>-<id>-<m-lower>">
        anchor = f"{repo_name}-{ISSUE}-{MILESTONE.lower().replace(' ', '-')}"
        block_re = re.compile(
            rf'(<a id="{re.escape(anchor)}"></a>\n### [^\n]*\n)((?:.*\n)*?)(?=\n<a id=|\n\[[a-z][a-z0-9 #-]+\]:|\Z)',
            re.MULTILINE
        )
        m = block_re.search(new_pt)
        if not m and not FORCE:
            # Pull the just-ticked task title and issue's estimate to scaffold the block
            task_title_m = re.search(
                rf"^- \[x\]\s*(.*?)\s*\[{re.escape(repo_name)}#{ISSUE} {re.escape(MILESTONE)}\]",
                new_pt, re.MULTILINE
            )
            title = task_title_m.group(1).strip(' —') if task_title_m else f"<title for {MILESTONE}>"
            est_m = re.search(r"^estimate_hours:\s*(.*)$", fm, re.MULTILINE)
            est_str = est_m.group(1).strip() if est_m else "<copy from issue estimate_hours, or omit>"
            ref_label = f"{repo_name}#{ISSUE} {MILESTONE}"
            skeleton = (
                f'<a id="{anchor}"></a>\n'
                f"### {ref_label} — {title}\n"
                f"\n"
                f"**est:** {est_str}\n"
                f"**actual:** {ACTUAL}h\n"
                f"**closed:** {TODAY}\n"
                f"\n"
                f"<one paragraph: what shipped, what was surprising, decisions worth preserving>\n"
            )
            ref_def = f"[{ref_label}]: #{anchor}"
            die(
                f'no detail block <a id="{anchor}"> in {proj_path.name} (§5 step 4).\n'
                f"  Author one before closing — the prose paragraph is load-bearing\n"
                f"  for future calibration. Insert this skeleton inside ## details:\n\n"
                f"{skeleton}\n"
                f"  And add this reference definition at the file bottom:\n"
                f"    {ref_def}\n\n"
                f"  Then re-run. (FORCE=1 if it's a track-only milestone with nothing worth recording.)"
            )
        if m:
            def upsert_field(text, field, value):
                line = f"**{field}:** {value}"
                if re.search(rf"^\*\*{field}:\*\*", text, re.MULTILINE):
                    return re.sub(rf"^\*\*{field}:\*\*.*$", line, text, flags=re.MULTILINE)
                if re.search(r"^\*\*est:\*\*", text, re.MULTILINE):
                    # Insert after est line (keeps structured fields grouped at top of block)
                    return re.sub(r"(^\*\*est:\*\*.*$)", rf"\1\n{line}", text, count=1, flags=re.MULTILINE)
                return line + "\n" + text

            block = m.group(2)
            if ACTUAL: block = upsert_field(block, 'actual', f"{ACTUAL}h")
            block = upsert_field(block, 'closed', TODAY)
            new_pt = new_pt[:m.start(2)] + block + new_pt[m.end(2):]
            ok(f"updated detail block <a id=\"{anchor}\"> in {proj_path.name}")

    elif mode == 'issue':
        # Tick all remaining task rows for this issue (any milestone)
        task_pat = re.compile(
            rf"^(- )\[[ .]\](.*?\[{re.escape(repo_name)}#{ISSUE}(?: [^\]]+)?\])",
            re.MULTILINE
        )
        leftover = task_pat.findall(new_pt)
        new_pt, n = task_pat.subn(r"\1[x]\2", new_pt)
        if n: ok(f"ticked {n} remaining task line(s) for {repo_name}#{ISSUE} in {proj_path.name}")
        if leftover and len(leftover) > 1:
            warn(f"multiple {repo_name}#{ISSUE} task rows ticked at once — confirm individual milestones were genuinely closed (§5 step 1)")

    if new_pt != pt:
        project_edit = (proj_path, new_pt)

# ── Write ───────────────────────────────────────────────────────────────────
if DRY:
    info("DRY=1 — no files written")
    print(f"Would update: {issue_path}")
    if project_edit: print(f"Would update: {project_edit[0]}")
    sys.exit(0)

if new_issue_text != issue_text:
    issue_path.write_text(new_issue_text)
if project_edit:
    project_edit[0].write_text(project_edit[1])

ok("done — review with `git diff`, then commit")
