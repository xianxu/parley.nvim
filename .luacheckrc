std = "luajit"
max_line_length = false

files["lua/**/*.lua"] = {
    globals = {
        "vim",
    },
}

files["tests/**/*.lua"] = {
    globals = {
        "vim",
    },
    ignore = {
        "211", -- unused variables in test scaffolding
        "212", -- unused callback arguments in mocks
        "231", -- helper captures for assertions in future edits
        "311", -- setup values intentionally reassigned in scenarios
        "431", -- local shadowing inside nested test scopes
    },
    read_globals = {
        "describe",
        "it",
        "before_each",
        "after_each",
        "setup",
        "teardown",
        "pending",
        "assert",
        "spy",
        "stub",
        "match",
    },
}
