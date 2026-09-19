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

local function state_dir_readers()
    local hits = {}
    for _, file in ipairs(require("tests.arch.arch_helper").worktree_files({ "lua/**/*.lua" })) do
        local handle = assert(io.open(file, "r"))
        local text = handle:read("*a"); handle:close()
        if text:find("state_dir", 1, true) then hits[#hits + 1] = file end
    end
    return hits
end

describe("arch: every state-directory reader is exercised corrupt", function()
    local hits = state_dir_readers()
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

    -- #261 M1 review BR-14: a write that reports whether it happened must be
    -- consumed by whatever tells the user it happened. A write called as a bare
    -- statement drops that report; each such site is declared, with why losing
    -- the result is harmless.
    it("consumes the result of every sidecar write, or says why not", function()
        -- Keyed by the exact call, so a new bare write in the same file is
        -- still caught. table_to_file warns on every failure itself.
        local DROPPED = {
            ["lua/parley/vault.lua"] = { ["helpers.table_to_file(V._state, state_file)"] =
                "the copilot bearer cache; a failed write re-fetches, and table_to_file has warned" },
            ["lua/parley/chat_respond.lua"] = { ["_parley.helpers.table_to_file(cache, M.remote_reference_cache_file())"] =
                "the remote-reference cache; a failed write re-fetches, and table_to_file has warned" },
        }
        local offenders = {}
        for _, file in ipairs(require("tests.arch.arch_helper").worktree_files({ "lua/**/*.lua" })) do
            for n, line in ipairs(vim.fn.readfile(file)) do
                local dropped = line:match("^%s*[%w_.]*table_to_file%(") or line:match("^%s*[%w_.]*table_to_file_atomic%(")
                    or line:match("^%s*[%w_.]*custom_prompts%.[%a_]+%(") and not line:match("custom_prompts%.load%(")
                        and not line:match("custom_prompts%.get%(") and not line:match("custom_prompts%.setup%(")
                local call = vim.trim(line)
                if dropped and not (DROPPED[file] and DROPPED[file][call]) then
                    offenders[#offenders + 1] = file .. ":" .. n
                end
            end
        end
        assert.same({}, offenders, "consume the write's result, or declare the site in DROPPED with why")
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
