module github.com/xianxu/parley.nvim-construct

go 1.26.3

require (
	github.com/inconshreveable/mousetrap v1.1.0 // indirect
	github.com/spf13/cobra v1.10.2 // indirect
	github.com/spf13/pflag v1.0.9 // indirect
	github.com/xianxu/ariadne v0.0.0-00010101000000-000000000000 // indirect
)

replace github.com/xianxu/ariadne => ../../ariadne

tool github.com/xianxu/ariadne/cmd/sdlc
