// Package project mutates brain-side project files (status ticks + detail
// blocks) for the sdlc binary. Ported from scripts/close-issue.py — same
// regex shapes so semantics match the Python source.
package project

import (
	"fmt"
	"os"
	"path/filepath"
	"regexp"
	"strings"
)

// FindByIssueRef finds the project file under
// `<brainDir>/data/project/*.md` that contains the marker
// `[<repoName>#<issueID>` (the open-bracket form matches both
// `[charon#13]` and `[charon#13 M2]`).
//
// Returns:
//   - one match → its absolute path, nil
//   - zero matches → "", nil (callers decide whether to warn)
//   - multiple matches → "", error (callers warn + skip; PROJECT= override
//     is not implemented, matching close-issue.py)
//   - hard filesystem error → "", error
func FindByIssueRef(brainDir, repoName, issueID string) (string, error) {
	glob := filepath.Join(brainDir, "data", "project", "*.md")
	files, err := filepath.Glob(glob)
	if err != nil {
		return "", fmt.Errorf("glob %s: %w", glob, err)
	}
	marker := "[" + repoName + "#" + issueID
	var hits []string
	for _, f := range files {
		data, rerr := os.ReadFile(f)
		if rerr != nil {
			// best-effort: ignore unreadable files (permission, broken
			// symlink, etc.); close-issue.py would propagate, but that's
			// because it uses Path.read_text() unconditionally — we keep
			// going since the worst case is "no project found" warning.
			continue
		}
		if strings.Contains(string(data), marker) {
			hits = append(hits, f)
		}
	}
	switch len(hits) {
	case 0:
		return "", nil
	case 1:
		return hits[0], nil
	default:
		return "", fmt.Errorf("multiple project files reference %s#%s: %v", repoName, issueID, hits)
	}
}

// TickMilestoneTaskRow ticks "- [ ] title [<repo>#<id> <milestone>]" (and
// the [.] [-] [~] in-progress/blocked/cancelled forms) to "- [x] ...".
// Returns the updated text and number of replacements.
//
// The character class `[ .\-~]` mirrors close-issue.py exactly (note the
// escaped hyphen).
func TickMilestoneTaskRow(text, repoName, issueID, milestone string) (string, int) {
	pat := regexp.MustCompile(
		`(?m)^(- )\[[ .\-~]\](.*?\[` +
			regexp.QuoteMeta(repoName) + `#` + regexp.QuoteMeta(issueID) +
			` ` + regexp.QuoteMeta(milestone) + `\])`,
	)
	n := len(pat.FindAllStringIndex(text, -1))
	if n == 0 {
		return text, 0
	}
	out := pat.ReplaceAllString(text, `${1}[x]${2}`)
	return out, n
}

// TickAllTaskRowsForIssue ticks every task row for this issue regardless of
// milestone tag: "- [ ] title [<repo>#<id>]" and "- [ ] title [<repo>#<id>
// M4]" both match. Used by issue-close to sweep up any leftover task lines.
//
// Mirrors close-issue.py's narrower character class `[ .]` (NOT including
// `[-~]`) for the issue-close path — that's intentional: cancelled/blocked
// task rows shouldn't be silently flipped to done at issue close.
func TickAllTaskRowsForIssue(text, repoName, issueID string) (string, int) {
	pat := regexp.MustCompile(
		`(?m)^(- )\[[ .]\](.*?\[` +
			regexp.QuoteMeta(repoName) + `#` + regexp.QuoteMeta(issueID) +
			`(?: [^\]]+)?\])`,
	)
	matches := pat.FindAllStringSubmatchIndex(text, -1)
	if len(matches) == 0 {
		return text, 0
	}
	out := pat.ReplaceAllString(text, `${1}[x]${2}`)
	return out, len(matches)
}

// Field is a (name, value) pair used by UpsertDetailBlockFields. Callers
// pass an ordered slice so the resulting on-disk layout is deterministic;
// close-issue.py applies "actual" then "closed" in that order, and we
// preserve it.
type Field struct {
	Name, Value string
}

// UpsertDetailBlockFields finds the detail block anchored by `<a
// id="anchor"></a>` followed by a `### ...` heading, then upserts each
// field (`**name:** value`) inside the block body, in the order the
// caller passed them.
//
// Field upsert semantics (matching close-issue.py's upsert_field):
//   - field present → replace its line in place
//   - field absent, `**est:**` present → insert immediately after **est:**
//     (keeps structured fields grouped at top of block)
//   - field absent, no `**est:**` → prepend a new line at block start
//
// Why the slice (vs map[string]string): Go's map iteration is
// non-deterministic, so passing two absent fields would produce different
// orderings across runs. The slice pins the order, matching Python's
// sequential `fm_set('actual', ...)` then `fm_set('closed', ...)` chain.
//
// Returns (newText, found). found=false means the anchor isn't in the file;
// caller should refuse-and-explain (skeleton-emitting path).
//
// Implementation note: close-issue.py uses a single regex with a positive
// lookahead `(?=\n<a id=|\n\[[a-z][a-z0-9 #-]+\]:|\Z)` to bound the body.
// Go's RE2 doesn't support lookahead, so we instead locate the header with
// a regex, then scan forward line-by-line to find the same boundary.
func UpsertDetailBlockFields(text, anchor string, fields []Field) (string, bool) {
	hdrRE := regexp.MustCompile(
		`(?m)<a id="` + regexp.QuoteMeta(anchor) + `"></a>\n### [^\n]*\n`,
	)
	hdrLoc := hdrRE.FindStringIndex(text)
	if hdrLoc == nil {
		return text, false
	}
	bodyStart := hdrLoc[1]
	bodyEnd := findDetailBlockEnd(text, bodyStart)
	body := text[bodyStart:bodyEnd]
	for _, fld := range fields {
		body = upsertField(body, fld.Name, fld.Value)
	}
	return text[:bodyStart] + body + text[bodyEnd:], true
}

// detailBoundaryRE matches the boundaries close-issue.py's lookahead used:
// `\n<a id=` or `\n[label]:` (markdown link-ref definitions at column 0).
// The leading `\n` is part of the match — caller treats the byte before
// the match as end-of-body, mirroring Python's lookahead semantics.
var detailBoundaryRE = regexp.MustCompile(
	`\n<a id=|\n\[[a-z][a-z0-9 #-]+\]:`,
)

// findDetailBlockEnd returns the index where the detail block body ends,
// given that the body starts at `from`. The end is either:
//   - the position of `\n` before the next `<a id=` anchor, or
//   - the position of `\n` before the next `[label]:` link-ref at column 0, or
//   - len(text) if neither is found.
func findDetailBlockEnd(text string, from int) int {
	loc := detailBoundaryRE.FindStringIndex(text[from:])
	if loc == nil {
		return len(text)
	}
	return from + loc[0]
}

// estLineRE matches the first `**est:**` line. Package-level so we
// don't recompile it on every upsertField call (callers may invoke per
// field, and multiple fields per close is the common case).
var estLineRE = regexp.MustCompile(`(?m)(^\*\*est:\*\*.*$)`)

// upsertField applies close-issue.py's three-tier upsert to one field.
// The present-line regex remains per-call because the field name is
// interpolated into the pattern; estLineRE is fixed and reused.
func upsertField(text, field, value string) string {
	line := "**" + field + ":** " + value
	presentRE := regexp.MustCompile(`(?m)^\*\*` + regexp.QuoteMeta(field) + `:\*\*.*$`)
	if presentRE.MatchString(text) {
		return presentRE.ReplaceAllString(text, line)
	}
	if estLineRE.MatchString(text) {
		// Insert after est line — only the first occurrence.
		replaced := false
		return estLineRE.ReplaceAllStringFunc(text, func(m string) string {
			if replaced {
				return m
			}
			replaced = true
			return m + "\n" + line
		})
	}
	return line + "\n" + text
}

// FindTaskTitle finds the just-ticked task row's title for the given
// (repo, issue, milestone) triple. Used for the skeleton-emitting
// explainer when no detail block exists. Returns "" if no ticked row is
// found.
func FindTaskTitle(text, repoName, issueID, milestone string) string {
	pat := regexp.MustCompile(
		`(?m)^- \[x\]\s*(.*?)\s*\[` +
			regexp.QuoteMeta(repoName) + `#` + regexp.QuoteMeta(issueID) +
			` ` + regexp.QuoteMeta(milestone) + `\]`,
	)
	m := pat.FindStringSubmatch(text)
	if m == nil {
		return ""
	}
	// Python's .strip(' —') trims spaces and em-dashes from both ends.
	return strings.Trim(m[1], " —")
}

// Skeleton renders the missing-detail-block skeleton that close-issue.py
// emits when refusing the close. Preserves the exact format (the prose is
// load-bearing for future calibration; agents read it).
//
// title, est may be empty — the caller fills in fallback labels.
type Skeleton struct {
	Anchor    string // e.g. "ariadne-31-m1"
	RefLabel  string // e.g. "ariadne#31 M1"
	Title     string
	Est       string
	Actual    string // already has "h" suffix e.g. "6.5h" (caller appends)
	ClosedISO string
}

// Render returns (skeleton, refDef).
func (s Skeleton) Render() (skeleton, refDef string) {
	title := s.Title
	if title == "" {
		title = "<title for milestone>"
	}
	est := s.Est
	if est == "" {
		est = "<copy from issue estimate_hours, or omit>"
	}
	skeleton = fmt.Sprintf(
		"<a id=\"%s\"></a>\n"+
			"### %s — %s\n"+
			"\n"+
			"**est:** %s\n"+
			"**actual:** %s\n"+
			"**closed:** %s\n"+
			"\n"+
			"<one paragraph: what shipped, what was surprising, decisions worth preserving>\n",
		s.Anchor, s.RefLabel, title, est, s.Actual, s.ClosedISO,
	)
	refDef = fmt.Sprintf("[%s]: #%s", s.RefLabel, s.Anchor)
	return
}

// AnchorFor returns the canonical detail-block anchor id for a
// (repo, issue, milestone) triple. Mirrors close-issue.py:
//
//	anchor = f"{repo_name}-{ISSUE}-{MILESTONE.lower().replace(' ', '-')}"
func AnchorFor(repoName, issueID, milestone string) string {
	return repoName + "-" + issueID + "-" + strings.ReplaceAll(strings.ToLower(milestone), " ", "-")
}
