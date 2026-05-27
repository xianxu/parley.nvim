module github.com/xianxu/parley.nvim

go 1.26.3

// parley.nvim is a Lua/Neovim plugin — no Go code of its own. The go.mod
// here functions as the dependency-management manifest, declaring ariadne
// as the substrate upstream that construct/setup.sh walks. See
// ariadne/atlas/workflow/setup-and-replication.md for the convention.
//
// Declare ariadne as require + replace + tool so `go mod vendor` (run by
// construct/setup.sh in vendor mode) populates vendor/github.com/xianxu/
// ariadne/, letting `make sdlc-build` produce bin/sdlc locally without
// needing ariadne checked out next door at runtime. The tool directive
// (Go 1.24+) keeps the require alive through `go mod tidy` for lack of
// a code import.
require github.com/xianxu/ariadne v0.0.0-00010101000000-000000000000 // indirect

require (
	github.com/inconshreveable/mousetrap v1.1.0 // indirect
	github.com/spf13/cobra v1.10.2 // indirect
	github.com/spf13/pflag v1.0.9 // indirect
)

replace github.com/xianxu/ariadne => ../ariadne

tool github.com/xianxu/ariadne/cmd/sdlc
