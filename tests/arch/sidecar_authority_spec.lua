-- Target transcript-is-the-whole-truth (#261): a sidecar under the profile
-- state directory became a precondition for regenerating an answer. Every
-- module that reads that directory must appear in tests/helpers/sidecars.lua,
-- whose every file sidecar_degrade_spec corrupts and then submits through — so
-- declaring a reader means proving its absence or corruption cannot block.
-- Modules that only define the path are listed here, with that reason.
local sidecars = require("tests.helpers.sidecars")

local PATH_ONLY = {
    ["lua/parley/config.lua"] = "defines the default path; reads nothing",
    ["lua/parley/starter_config.lua"] = "defines the starter path; reads nothing",
}

describe("arch: every state-directory reader is exercised corrupt", function()
    local hits = vim.fn.systemlist("git grep -l -e state_dir -- lua/")
    local readers = {}
    for _, sidecar in ipairs(sidecars) do readers[sidecar.reader] = true end

    it("finds the readers it claims to check", function()
        assert.equals(0, vim.v.shell_error)
        assert.is_true(#hits >= #sidecars, "the query found fewer files than the declared readers")
    end)

    it("declares every reader of the state directory", function()
        local undeclared = {}
        for _, file in ipairs(hits) do
            if not readers[file] and not PATH_ONLY[file] then undeclared[#undeclared + 1] = file end
        end
        assert.same({}, undeclared,
            "a new state_dir reader: add its sidecar to tests/helpers/sidecars.lua so sidecar_degrade_spec corrupts it")
    end)

    it("declares nothing that no longer reads it", function()
        local found, stale = {}, {}
        for _, file in ipairs(hits) do found[file] = true end
        for file in pairs(readers) do if not found[file] then stale[#stale + 1] = file end end
        for file in pairs(PATH_ONLY) do if not found[file] then stale[#stale + 1] = file end end
        table.sort(stale)
        assert.same({}, stale, "remove declarations for files that no longer read state_dir")
    end)
end)
