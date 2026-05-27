// Package helptext exposes //go:embed-backed help texts so cobra
// commands can populate their Long descriptions and the root --index
// flag can emit SKILL.md content.
//
// Convention: each subcommand gets one Markdown file here, named by the
// command's stem (close.md, state.md, ...). The root narrative lives in
// root.md; the SKILL.md template lives in index.md.
//
// Why embed instead of inline strings: the prose grows beyond one
// paragraph per command, and we regenerate SKILL.md from these files
// via sdlc --index. Having one Markdown source of truth keeps the CLI
// help and the on-disk SKILL.md in lockstep — they cannot drift,
// because they render from the same bytes.
package helptext

import (
	"embed"
	"fmt"
	"strings"
)

//go:embed *.md
var fs embed.FS

// Get returns the content of <name>.md with trailing whitespace
// trimmed to one terminating newline. Returns ok=false if absent.
func Get(name string) (string, bool) {
	b, err := fs.ReadFile(name + ".md")
	if err != nil {
		return "", false
	}
	return strings.TrimRight(string(b), "\n") + "\n", true
}

// MustGet returns the content of <name>.md, panicking if absent. Use
// for help texts that ship with the binary — a missing entry is a
// build-time bug, not a runtime condition.
func MustGet(name string) string {
	s, ok := Get(name)
	if !ok {
		panic(fmt.Sprintf("helptext: %s.md not embedded", name))
	}
	return s
}

// Names lists the available help-text stems (without the .md suffix),
// sorted. Used by --index to enumerate subcommand prose for the
// generated SKILL.md.
func Names() []string {
	entries, err := fs.ReadDir(".")
	if err != nil {
		return nil
	}
	var out []string
	for _, e := range entries {
		name := e.Name()
		if !strings.HasSuffix(name, ".md") {
			continue
		}
		out = append(out, strings.TrimSuffix(name, ".md"))
	}
	return out
}
