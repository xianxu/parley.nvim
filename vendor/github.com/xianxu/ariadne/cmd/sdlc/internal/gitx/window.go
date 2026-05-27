// Package gitx wraps the small set of git invocations that the sdlc binary's
// checkpoint guards need: commit-window discovery (subject-anchored grep for
// #N references), peer-issue discovery, and changed-file listing.
//
// Ported from scripts/close-issue.py — semantics preserved including the
// 31-day cap and the "parent of first match" window-start trick.
package gitx

import (
	"errors"
	"fmt"
	"os"
	"os/exec"
	"regexp"
	"sort"
	"strconv"
	"strings"
	"time"
)

// run is the package-level command runner. Test code in this package
// (and downstream packages once we propagate the pattern) can override
// it to drive fixture-based scenarios without spawning real git
// processes. Production path defaults to exec.Command(...).Output().
//
// All new git callers in this package should use run; M3+ will migrate
// the legacy direct exec.Command calls below when those code paths are
// touched again.
var run = func(name string, args ...string) ([]byte, error) {
	return exec.Command(name, args...).Output()
}

// RunGit runs `git <args>` via the package-level `run` shim and returns
// the raw stdout bytes. Use this when you need the full output (newlines
// preserved) or need to distinguish empty-but-OK from error — Capture
// flattens both into "".
func RunGit(args ...string) ([]byte, error) {
	return run("git", args...)
}

// Capture runs `git <args>` and returns trimmed stdout. Empty string on
// any error (caller decides whether to refuse or degrade). Uses the
// package-level `run` shim so tests can override.
//
// Suitable for one-shot queries like `git rev-parse --show-toplevel`,
// `git branch --show-current`, `git worktree list --porcelain`. Not
// suitable for queries where you must distinguish "ran but empty" from
// "errored" — use run() directly for those.
func Capture(args ...string) string {
	out, err := run("git", args...)
	if err != nil {
		return ""
	}
	return strings.TrimSpace(string(out))
}

// DiffBase returns the git ref to compare against for "what's new on
// this branch." Mirrors scripts/lib.sh's git_diff_base():
//
//   1. If <repo-root>/COMPARE-SHA exists and points to a verified ref,
//      use that. Lets callers override the default for ad-hoc reviews.
//   2. If current branch is main, return origin/main (HEAD~10 fallback).
//   3. Otherwise (feature branch), return the merge-base of main and HEAD.
//
// Used by `sdlc judge` to determine the diff window for principle checks.
func DiffBase() string {
	root := Capture("rev-parse", "--show-toplevel")
	if root != "" {
		path := root + "/COMPARE-SHA"
		if data, err := os.ReadFile(path); err == nil {
			sha := strings.TrimSpace(strings.SplitN(string(data), "\n", 2)[0])
			if sha != "" && Capture("rev-parse", "--verify", sha) != "" {
				return sha
			}
		}
	}
	branch := Capture("branch", "--show-current")
	if branch == "main" {
		if ref := Capture("rev-parse", "origin/main"); ref != "" {
			return "origin/main"
		}
		return "HEAD~10"
	}
	if base := Capture("merge-base", "main", "HEAD"); base != "" {
		return base
	}
	return "HEAD~10"
}

// WindowCapDays is the sanity cap on how far back the commit window can
// reach. Anything older is almost certainly a fork-upstream collision
// (the forked repo's history reusing #N for a different historical issue),
// not legitimate ancient work.
const WindowCapDays = 31

// CommitWindow returns (firstSHA, firstISO, lastISO) for commits whose
// *subject* opens with `#issueNum` (optionally prefixed with "close "),
// capped at WindowCapDays in the past.
//
// firstISO is the *parent* of the first matching commit (the v3 segment-
// start trick: v3 segments span [parent_commit_time, this_commit_time], so
// using the parent lets the first segment extend backward and capture
// pre-commit work like typing and thinking). Falls back to the first
// match's own ISO if the parent lookup fails (initial-commit edge case) or
// the parent is outside the cap.
//
// Returns all-empty (no error) if no in-window subject anchor exists.
//
// Subject-anchored, not whole-message: forked-upstream history may contain
// commits referencing the same number in their *body* (e.g., "docs: setup
// snippet (issue: #123)" from a 2-year-old upstream commit) but not the
// subject. Whole-message --grep would pull those in and stretch the window
// by years.
func CommitWindow(issueNum string) (firstSHA, firstISO, lastISO string, err error) {
	// Loose --grep first to narrow candidates; precise subject-anchor
	// check happens below. Git's POSIX regex doesn't reliably support \b
	// for word boundaries across platforms, so we filter subjects in Go.
	cmd := exec.Command("git", "log",
		"--grep=#"+issueNum, "--reverse",
		"--pretty=%aI%x00%H%x00%s",
	)
	out, err := cmd.Output()
	if err != nil {
		// non-zero exit (e.g., not a git repo) → no window, no error
		// (matches close-issue.py's CalledProcessError swallow)
		return "", "", "", nil
	}
	text := strings.TrimRight(string(out), "\n")
	if text == "" {
		return "", "", "", nil
	}
	subjectRE := regexp.MustCompile(`^(close\s+)?#` + regexp.QuoteMeta(issueNum) + `($|[^0-9])`)
	type match struct{ iso, sha string }
	var matches []match
	for _, line := range strings.Split(text, "\n") {
		parts := strings.SplitN(line, "\x00", 3)
		if len(parts) != 3 {
			continue
		}
		iso, sha, subject := parts[0], parts[1], parts[2]
		if subjectRE.MatchString(subject) {
			matches = append(matches, match{iso, sha})
		}
	}
	if len(matches) == 0 {
		return "", "", "", nil
	}
	capISO := time.Now().UTC().
		Add(-time.Duration(WindowCapDays) * 24 * time.Hour).
		Format("2006-01-02T15:04:05-07:00")
	var recent []match
	for _, m := range matches {
		if m.iso >= capISO {
			recent = append(recent, m)
		}
	}
	if len(recent) == 0 {
		return "", "", "", nil
	}
	firstSHA = recent[0].sha
	firstISO = recent[0].iso
	lastISO = recent[len(recent)-1].iso

	// v3 segment-start: parent of first match (still bounded by cap).
	parentOut, perr := exec.Command(
		"git", "log", "-1", "--pretty=%aI", firstSHA+"^",
	).Output()
	if perr == nil {
		parentISO := strings.TrimSpace(string(parentOut))
		if parentISO != "" && parentISO >= capISO {
			return firstSHA, parentISO, lastISO, nil
		}
	}
	return firstSHA, firstISO, lastISO, nil
}

// issueRefRE matches "#<digits>" with a word boundary on the trailing side.
var issueRefRE = regexp.MustCompile(`#(\d+)\b`)

// DiscoverWindowIssues returns every distinct issue number referenced in
// commit subjects within [since, until]. `primary` is always included in
// the result, even if no commits match it.
//
// Why all of them: the active-time-v3 algorithm anchors segments by
// commit-subject issue ref; unrecognized refs fall into mention-fallback
// and inflate the closing issue's share by 3-10x.
func DiscoverWindowIssues(sinceISO, untilISO, primary string) ([]string, error) {
	cmd := exec.Command("git", "log",
		"--since="+sinceISO, "--until="+untilISO, "--pretty=%s",
	)
	out, err := cmd.Output()
	if err != nil {
		return []string{primary}, nil
	}
	text := strings.TrimRight(string(out), "\n")
	seen := map[string]struct{}{}
	for _, line := range strings.Split(text, "\n") {
		for _, m := range issueRefRE.FindAllStringSubmatch(line, -1) {
			seen[m[1]] = struct{}{}
		}
	}
	if _, ok := seen[primary]; !ok {
		seen[primary] = struct{}{}
	}
	keys := make([]string, 0, len(seen))
	for k := range seen {
		keys = append(keys, k)
	}
	sort.Slice(keys, func(i, j int) bool {
		ai, _ := strconv.Atoi(keys[i])
		aj, _ := strconv.Atoi(keys[j])
		return ai < aj
	})
	// close-issue.py: sorted set keyed by int, then primary appended if
	// not present. Our sort already gives the numerically-sorted set;
	// primary lands wherever its number sorts.
	return keys, nil
}

// DiffNames returns the list of file paths changed between sinceRef and
// untilRef (`git diff --name-only sinceRef untilRef`). Empty slice + nil
// error if there are no changes; non-nil error only on hard git failures.
func DiffNames(sinceRef, untilRef string) ([]string, error) {
	cmd := exec.Command("git", "diff", "--name-only", sinceRef, untilRef)
	out, err := cmd.Output()
	if err != nil {
		return nil, fmt.Errorf("git diff --name-only %s %s: %w", sinceRef, untilRef, err)
	}
	text := strings.TrimSpace(string(out))
	if text == "" {
		return nil, nil
	}
	return strings.Split(text, "\n"), nil
}

// LogEntry is one line of `git log --reverse --format=%H %ci %s`.
type LogEntry struct {
	SHA, Date, Subject string
}

// LogReverse returns the full commit log in reverse-chronological order
// (oldest first), one LogEntry per commit. Used by close-issue.py's
// "first commit referencing '#N M4'" scan.
func LogReverse() ([]LogEntry, error) {
	cmd := exec.Command("git", "log", "--reverse", "--format=%H %ci %s")
	out, err := cmd.Output()
	if err != nil {
		return nil, fmt.Errorf("git log: %w", err)
	}
	text := strings.TrimRight(string(out), "\n")
	if text == "" {
		return nil, nil
	}
	var entries []LogEntry
	for _, line := range strings.Split(text, "\n") {
		// Format: "<sha> <YYYY-MM-DD HH:MM:SS ±zzzz> <subject>"
		// SHA is 40 hex chars; date is fixed 25 chars; subject is the rest.
		// We split on the first space (sha), then need to peel off the date.
		if len(line) < 41 {
			continue
		}
		sha := line[:40]
		rest := line[41:]
		// Date is exactly 25 chars: "2006-01-02 15:04:05 -0700"
		if len(rest) < 26 {
			continue
		}
		date := rest[:25]
		subject := rest[26:]
		entries = append(entries, LogEntry{sha, date, subject})
	}
	return entries, nil
}

// RepoTopLevel returns the path of the git repo root (`git rev-parse
// --show-toplevel`).
func RepoTopLevel() (string, error) {
	out, err := exec.Command("git", "rev-parse", "--show-toplevel").Output()
	if err != nil {
		return "", fmt.Errorf("git rev-parse --show-toplevel: %w", err)
	}
	return strings.TrimSpace(string(out)), nil
}

// ErrNoMatches is returned by helpers when nothing matched (so callers can
// distinguish "ran fine, no result" from "git failed").
var ErrNoMatches = errors.New("no matches")
