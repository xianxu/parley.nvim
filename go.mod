module github.com/xianxu/parley.nvim

go 1.22

// parley.nvim is a Lua/Neovim plugin — no Go code of its own. The go.mod
// here functions as the dependency-management manifest, declaring ariadne
// as the substrate upstream that construct/setup.sh walks. See
// ariadne/atlas/workflow/setup-and-replication.md for the convention.
replace github.com/xianxu/ariadne => ../ariadne
