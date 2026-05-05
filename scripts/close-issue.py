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
from datetime import date
from pathlib import Path
from typing import NoReturn

ISSUE     = os.environ.get('ISSUE', '').strip()
MILESTONE = os.environ.get('MILESTONE', '').strip()
ACTUAL    = os.environ.get('ACTUAL', '').strip()
VERIFIED  = os.environ.get('VERIFIED', '').strip()
BRAIN_DIR = os.environ.get('BRAIN_DIR', '../brain').strip()
WF_ISSUES_DIR = os.environ.get('WF_ISSUES_DIR', 'workshop/issues').strip()
DRY   = os.environ.get('DRY', '') == '1'
FORCE = os.environ.get('FORCE', '') == '1'

RED, GREEN, YELLOW, CYAN, RESET = '\033[1;31m', '\033[1;32m', '\033[1;33m', '\033[1;36m', '\033[0m'
def die(msg) -> NoReturn:  print(f"{RED}Error: {msg}{RESET}", file=sys.stderr); sys.exit(1)
def info(msg): print(f"{CYAN}==>{RESET} {msg}", file=sys.stderr)
def ok(msg):   print(f"  {GREEN}[ok]{RESET} {msg}", file=sys.stderr)
def warn(msg): print(f"  {YELLOW}[!]{RESET} {msg}", file=sys.stderr)

# ── Validate inputs ──────────────────────────────────────────────────────────
if not ISSUE: die("ISSUE=<n> required")
if not ISSUE.isdigit(): die(f"ISSUE must be numeric, got '{ISSUE}'")
issue_id = ISSUE.zfill(6)
mode = 'milestone' if MILESTONE else 'issue'
if ACTUAL:
    try: float(ACTUAL)
    except ValueError: die(f"ACTUAL must be a number, got '{ACTUAL}'")
# §5 applies to both milestone and issue close — ACTUAL + VERIFIED required for both.
if not ACTUAL and not FORCE:
    die(f"ACTUAL=<hours> required for {mode} close (§5 step 3). "
        "Set FORCE=1 to skip — record reason in VERIFIED.")
if not VERIFIED and not FORCE:
    die(f'VERIFIED="<one-line evidence>" required for {mode} close (§5 step 1). '
        'Examples: "ran make test, all green" / "e2e flow X→Y verified manually" / '
        '"code-review subagent, all Important addressed in <sha>". '
        'Set FORCE=1 only if you genuinely have no behavior to verify.')
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
