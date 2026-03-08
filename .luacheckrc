std = "luajit"

files["lua/**/*.lua"] = {
    globals = {
        "vim",
    },
}

files["tests/**/*.lua"] = {
    globals = {
        "vim",
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
