// runner.go — shared `gitRunner` interface + `execGitRunner` production
// implementation. Extracted in M5 once push/pr/merge made it the third
// (plus original two: start, lock) consumer of the same seam. Per M4
// review's "third-consumer candidate" note.
//
// The interface keeps the surface tiny: git commands (in-repo + in-other-
// worktree) plus the two filesystem mutations checkpoint verbs perform
// (MkdirAll + WriteFile). Tests substitute a capture/stub runner that
// records calls without executing them — see start_test.go's
// captureRunner and lock_test.go's lockRunnerStub for the pattern.
package main

import (
	"os"
	"os/exec"
)

// gitRunner indirects the git invocations + filesystem mutations done by
// checkpoint verbs. Production path uses execGitRunner. Tests substitute
// captureRunner (or lockRunnerStub) which records calls without executing.
//
// All git-touching verbs share the same runner type because they do
// similar work (git + file write) and benefit from the same test seam.
type gitRunner interface {
	Git(args ...string) ([]byte, error)
	GitInDir(dir string, args ...string) ([]byte, error)
	MkdirAll(path string) error
	WriteFile(path string, data []byte) error
}

// execGitRunner is the production implementation of gitRunner. Each
// method shells out to the real git binary (or stdlib filesystem call)
// and returns the same shape the interface promises.
type execGitRunner struct{}

func (execGitRunner) Git(args ...string) ([]byte, error) {
	return exec.Command("git", args...).CombinedOutput()
}

func (execGitRunner) GitInDir(dir string, args ...string) ([]byte, error) {
	cmd := exec.Command("git", args...)
	cmd.Dir = dir
	return cmd.CombinedOutput()
}

func (execGitRunner) MkdirAll(path string) error { return os.MkdirAll(path, 0o755) }

func (execGitRunner) WriteFile(path string, data []byte) error {
	return os.WriteFile(path, data, 0o644)
}
