-- Target transcript-is-the-whole-truth (#261): a sidecar under the profile
-- state directory became a precondition for regenerating an answer. Every
-- module that reads that directory must appear in tests/helpers/sidecars.lua,
-- whose every file sidecar_degrade_spec corrupts and then submits through — so
-- declaring a reader means proving its absence or corruption cannot block.
-- Modules that only define the path are listed here, with that reason.
local sidecars = require("tests.helpers.sidecars")

-- Modules that name a profile location but hold no sidecar a chat action reads
-- back, each with why.
local PATH_ONLY = {
    ["lua/parley/config.lua"] = "defines the default paths; reads nothing",
    ["lua/parley/starter_config.lua"] = "defines the starter paths; reads nothing",
    ["lua/parley/starter.lua"] = "the starter profile's first-run setup at startup: creates the data and state roots, migrates auth; not on the chat path",
    ["lua/parley/cliproxy.lua"] = "the managed proxy's derived artifacts (rendered config, binary, model catalog cache), not transcript sidecars; every decode is guarded (json_decode_spec)",
}

-- The class is files persisted in the profile and read back: select by where
-- they live — the state directory or stdpath('data') — not by one spelling
-- (#261 M1 review round 4: file_access.json lives under stdpath('data') and
-- escaped a census that searched only for "state_dir").
local function profile_readers()
    local hits = {}
    for _, file in ipairs(require("tests.arch.arch_helper").worktree_files({ "lua/**/*.lua" })) do
        local handle = assert(io.open(file, "r"))
        local text = handle:read("*a"); handle:close()
        if text:find("state_dir", 1, true) or text:find('stdpath("data")', 1, true)
            or text:find("stdpath('data')", 1, true) then
            hits[#hits + 1] = file
        end
    end
    return hits
end

describe("arch: every state-directory reader is exercised corrupt", function()
    local hits = profile_readers()
    local readers = {}
    for _, sidecar in ipairs(sidecars) do readers[sidecar.reader] = true end

    it("finds the readers it claims to check", function()
        assert.is_true(#hits >= #sidecars, "the scan found fewer files than the declared readers")
    end)

    it("declares every reader of the state directory", function()
        local undeclared = {}
        for _, file in ipairs(hits) do
            if not readers[file] and not PATH_ONLY[file] then undeclared[#undeclared + 1] = file end
        end
        assert.same({}, undeclared,
            "a new state_dir reader: add its sidecar to tests/helpers/sidecars.lua so sidecar_degrade_spec corrupts it")
    end)

    -- #261 M1 review BR-5: a read that filters must not be persisted over a
    -- file the user wrote. Each sidecar says which kind it is.
    it("says what each sidecar's writes do with fields its read drops", function()
        local undeclared = {}
        for _, sidecar in ipairs(sidecars) do
            local rewrites = sidecar.writes == "rewrite" and type(sidecar.why) == "string"
            local preserves = sidecar.writes == "preserve" and type(sidecar.preserve) == "function"
            if not (rewrites or preserves) then undeclared[#undeclared + 1] = sidecar.file end
        end
        assert.same({}, undeclared,
            "declare writes = 'rewrite' with a why, or writes = 'preserve' with a preserve check")
    end)

    -- Consuming a write's result is checked for every ---@nodiscard function by
    -- tests/arch/nodiscard_spec.lua, which selects by that annotation.

    it("declares nothing that no longer reads it", function()
        local found, stale = {}, {}
        for _, file in ipairs(hits) do found[file] = true end
        for file in pairs(readers) do if not found[file] then stale[#stale + 1] = file end end
        for file in pairs(PATH_ONLY) do if not found[file] then stale[#stale + 1] = file end end
        table.sort(stale)
        assert.same({}, stale, "remove declarations for files that no longer read state_dir")
    end)
end)
