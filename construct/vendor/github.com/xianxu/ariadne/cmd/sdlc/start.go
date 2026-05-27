// start.go — `sdlc start [--issue N | --name X]` subcommand.
//
// Ports the `worktree` Make target (Makefile.workflow ~lines 163-211).
// Creates a fresh git worktree on a new branch under
// ../worktree/<repo-dir-name>/<branch-name>/ and writes the path to .goto
// so the `g` shell alias can `cd` there.
//
// Name resolution priority (mirrors the Make target):
//  1. --name explicit          → use as-is
//  2. --issue N                → derive from workshop/issues/NNNNNN-*.md basename
//  3. auto-detect              → if exactly ONE untracked NNNNNN-*.md, use it;
//                                zero or multiple → error
//
// If a single untracked issue file is detected (modes 2 or 3), it is
// committed + pushed first so the branch starts from a tracked state.
// Commit message matches the shell target exactly.
package main

import (
	"fmt"
	"io"
	"os"
	"path/filepath"
	"regexp"
	"strings"

	"github.com/spf13/cobra"

	"github.com/xianxu/ariadne/cmd/sdlc/internal/gitx"
)

// startFlags holds the parsed flag values for the start subcommand.
type startFlags struct {
	Issue     int
	Name      string
	IssuesDir string
	DryRun    bool
}

// NewStartCmd returns the cobra command for `sdlc start`. Long is a
// placeholder; main.go overrides with helptext.MustGet("start").
func NewStartCmd() *cobra.Command {
	f := startFlags{}
	cmd := &cobra.Command{
		Use:           "start",
		Short:         "Create a new git worktree on a fresh branch (auto-detects from untracked issue file)",
		Long:          "Placeholder — replaced by helptext.MustGet(\"start\") in main.go.",
		Args:          cobra.NoArgs,
		SilenceErrors: true,
		RunE: func(cmd *cobra.Command, args []string) error {
			return runStart(cmd.OutOrStdout(), cmd.ErrOrStderr(), &f)
		},
	}
	cmd.Flags().IntVar(&f.Issue, "issue", 0, "ariadne workshop issue ID (derives name from issues/NNNNNN-*.md)")
	cmd.Flags().StringVar(&f.Name, "name", "", "explicit branch + worktree name")
	cmd.Flags().StringVar(&f.IssuesDir, "issues-dir", envOr("WF_ISSUES_DIR", "workshop/issues"), "directory holding issue files")
	cmd.Flags().BoolVar(&f.DryRun, "dry-run", false, "print would-be operations; do nothing")
	return cmd
}

// startRunner is the package-level runner instance for start (test seam).
// Type lives in runner.go; lockRunner / pushRunner / mergeRunner / prRunner
// share the same surface so a single capture/stub can drive any of them.
var startRunner gitRunner = execGitRunner{}

// runStart is the entry point for the cobra RunE.
func runStart(stdout, stderr io.Writer, f *startFlags) error {
	// 1. Resolve the branch/worktree name.
	name, untrackedFile, err := resolveStartName(f, startRunner)
	if err != nil {
		die(stderr, err.Error())
	}

	// 2. Resolve repo top-level so we know where ../worktree/ goes.
	repoTop, err := gitx.RepoTopLevel()
	if err != nil {
		die(stderr, fmt.Sprintf("git rev-parse --show-toplevel: %v", err))
	}
	repoDir := filepath.Base(repoTop)
	wtRoot := filepath.Join(filepath.Dir(repoTop), "worktree", repoDir)
	wtPath := filepath.Join(wtRoot, name)

	if f.DryRun {
		cinfo(stderr, "dry-run — no operations performed")
		if untrackedFile != "" {
			fmt.Fprintf(stdout, "Would commit + push: %s\n", untrackedFile)
		}
		fmt.Fprintf(stdout, "Would mkdir: %s\n", wtRoot)
		fmt.Fprintf(stdout, "Would: git worktree add -b %s %s HEAD\n", name, wtPath)
		fmt.Fprintf(stdout, "Would write .goto: %s\n", wtPath)
		return nil
	}

	// 3. If we auto-detected an untracked issue file, commit + push it
	//    before creating the worktree. The Make target swallows push
	//    failures with a warning; we do the same.
	if untrackedFile != "" {
		cinfo(stderr, fmt.Sprintf("Committing %s before creating worktree...", untrackedFile))
		if out, err := startRunner.Git("add", untrackedFile); err != nil {
			die(stderr, fmt.Sprintf("git add %s: %v\n%s", untrackedFile, err, out))
		}
		if out, err := startRunner.Git("commit", "-m", "committing issue file before creating worktree"); err != nil {
			die(stderr, fmt.Sprintf("git commit: %v\n%s", err, out))
		}
		if out, err := startRunner.Git("push"); err != nil {
			cwarn(stderr, fmt.Sprintf("push failed, continuing with worktree creation: %v\n%s", err, out))
		}
	}

	// 4. Create the worktree.
	if err := startRunner.MkdirAll(wtRoot); err != nil {
		die(stderr, fmt.Sprintf("mkdir %s: %v", wtRoot, err))
	}
	if out, err := startRunner.Git("worktree", "add", "-b", name, wtPath, "HEAD"); err != nil {
		die(stderr, fmt.Sprintf("git worktree add: %v\n%s", err, out))
	}
	cok(stderr, fmt.Sprintf("Worktree created at %s on branch %s", wtPath, name))

	// 5. Write .goto so the `g` shell alias works.
	gotoPath := filepath.Join(repoTop, ".goto")
	if err := startRunner.WriteFile(gotoPath, []byte(wtPath)); err != nil {
		cwarn(stderr, fmt.Sprintf(".goto write failed: %v", err))
	} else {
		cok(stderr, "Run: g (to cd into worktree)")
	}
	fmt.Fprintln(stdout, wtPath)
	return nil
}

// ── name resolution ──────────────────────────────────────────────────────────

// resolveStartName implements the name-resolution priority:
//
//  1. --name       → use as-is, no untracked detection
//  2. --issue N    → look up workshop/issues/NNNNNN-*.md, derive name
//                    from basename. Also returns it as untrackedFile
//                    *only if* git reports it as untracked.
//  3. neither      → scan untracked files in issues-dir; if exactly one
//                    NNNNNN-*.md, use that. Multiple/zero → error.
//
// Returns (name, untrackedFile, err). untrackedFile is the path that
// should be committed before the worktree is created; empty if no
// commit is needed (e.g. --name was given, or the --issue file is
// already tracked).
func resolveStartName(f *startFlags, r gitRunner) (name, untrackedFile string, err error) {
	if f.Name != "" && f.Issue > 0 {
		return "", "", fmt.Errorf("--name and --issue are mutually exclusive")
	}

	// Mode 1: explicit name.
	if f.Name != "" {
		return f.Name, "", nil
	}

	// Modes 2 & 3 need the untracked list.
	untracked, err := listUntrackedIssues(f.IssuesDir, r)
	if err != nil {
		return "", "", err
	}

	if f.Issue > 0 {
		id := fmt.Sprintf("%06d", f.Issue)
		matches, _ := filepath.Glob(filepath.Join(f.IssuesDir, id+"-*.md"))
		if len(matches) == 0 {
			return "", "", fmt.Errorf("no issue file matches %s/%s-*.md", f.IssuesDir, id)
		}
		if len(matches) > 1 {
			return "", "", fmt.Errorf("multiple issue files match %s/%s-*.md: %v", f.IssuesDir, id, matches)
		}
		// Verify the match is a readable regular file — glob can return
		// dangling symlinks or stat-failing entries that would error at
		// git-add time with a confusing message. Matches the shell's
		// `[ -f "$$issues" ]` check (review M4 I4).
		if info, err := os.Stat(matches[0]); err != nil || !info.Mode().IsRegular() {
			return "", "", fmt.Errorf("issue file %s exists in glob but is not a readable regular file", matches[0])
		}
		base := strings.TrimSuffix(filepath.Base(matches[0]), ".md")
		// Was it in the untracked list? If yes, return for commit.
		for _, u := range untracked {
			if filepath.Base(u) == filepath.Base(matches[0]) {
				return base, matches[0], nil
			}
		}
		return base, "", nil
	}

	// Mode 3: auto-detect single untracked.
	switch len(untracked) {
	case 0:
		return "", "", fmt.Errorf("no untracked issue file found in %s; pass --name or --issue", f.IssuesDir)
	case 1:
		base := strings.TrimSuffix(filepath.Base(untracked[0]), ".md")
		return base, untracked[0], nil
	default:
		return "", "", fmt.Errorf("multiple untracked issue files found:\n  %s\npass --name or --issue to disambiguate",
			strings.Join(untracked, "\n  "))
	}
}

// listUntrackedIssues returns paths to NNNNNN-<slug>.md files reported
// as untracked by `git ls-files --others --exclude-standard`. Filters
// to the issuesDir prefix + 6-digit prefix shape. Empty slice + nil
// error if none.
func listUntrackedIssues(issuesDir string, r gitRunner) ([]string, error) {
	out, err := r.Git("ls-files", "--others", "--exclude-standard", "--", issuesDir+"/")
	if err != nil {
		return nil, fmt.Errorf("git ls-files: %v\n%s", err, out)
	}
	text := strings.TrimSpace(string(out))
	if text == "" {
		return nil, nil
	}
	var matches []string
	for _, line := range strings.Split(text, "\n") {
		base := filepath.Base(line)
		if issueIDRE.MatchString(base) {
			matches = append(matches, line)
		}
	}
	return matches, nil
}

// issueIDRE matches NNNNNN-<slug>.md filenames (6-digit prefix, dash,
// any slug, .md). Mirrors state.go's issueFilenameRE but defined locally
// to keep the start/lock surface independent.
var issueIDRE = regexp.MustCompile(`^\d{6}-.*\.md$`)
