local records = require("parley.note_finder_records")
local failure_kind = require("parley.finder_scan").FAILURE_KIND

local function candidate(relative, overrides)
    local path = "/notes/" .. relative
    local value = {
        root = { path = "/notes", label = "main", is_primary = true },
        root_ordinal = 1,
        relative = relative,
        unresolved_absolute = path,
        resolved_absolute = path,
        identity = {
            key = path,
            source = { root_ordinal = 1, unresolved = path },
        },
        stat = { mtime = { sec = 100 } },
    }
    for key, item in pairs(overrides or {}) do
        value[key] = item
    end
    return value
end

describe("Note finder records", function()
    it("classifies dated notes and infers their directory date", function()
        local result = records.adapt(candidate("2026/02/W06/03-design.md"))

        assert.equals("record", result.kind)
        assert.is_nil(result.value.base_folder)
        assert.equals("2026/02/W06/03-design.md", result.value.relative)
        assert.equals(os.time({ year = 2026, month = 2, day = 3, hour = 23, min = 59, sec = 59 }),
            result.value.inferred_time)
    end)

    it("skips templates intentionally instead of reporting a failure", function()
        assert.same({ kind = "skip" }, records.adapt(candidate("templates/basic.md")))
    end)

    it("classifies first-level special folders for recency exemption", function()
        local result = records.adapt(candidate("K/evergreen.md"))

        assert.equals("K", result.value.base_folder)
        assert.is_nil(result.value.inferred_time)
    end)

    it("reuses unchanged cached classification and recomputes changed files", function()
        local cache = {
            ["/notes/cached.md"] = {
                mtime = 100,
                classification = { relative_path = "K/cached.md", base_folder = "K" },
                inferred_time = 42,
            },
        }
        local unchanged = candidate("K/cached.md", {
            identity = {
                key = "/notes/cached.md",
                source = { root_ordinal = 1, unresolved = "/notes/K/cached.md" },
            },
        })
        local changed = candidate("K/cached.md", {
            identity = unchanged.identity,
            stat = { mtime = { sec = 101 } },
        })

        assert.same({ kind = "ready", value = cache["/notes/cached.md"] },
            records.read_decision(cache, unchanged))
        assert.same({ kind = "none" }, records.read_decision(cache, changed))
    end)

    it("materializes special-folder exemptions and filters old dated notes", function()
        local old_special = records.adapt(candidate("K/evergreen.md", {
            stat = { mtime = { sec = 1 } },
        })).value
        local old_dated = records.adapt(candidate("2020/01/W01/01-old.md", {
            stat = { mtime = { sec = 2 } },
        })).value

        local entries = records.materialize({ old_dated, old_special }, {
            cutoff_time = os.time({ year = 2025, month = 1, day = 1, hour = 0 }),
        })

        assert.equals(1, #entries)
        assert.equals(old_special.path, entries[1].value)
        assert.truthy(entries[1].display:find("{K}", 1, true))
    end)

    it("renders non-primary labels and sorts by date, mtime, then path", function()
        local root = { path = "/peer", label = "peer", is_primary = false }
        local later_path = records.adapt(candidate("2026/02/W06/03-z.md", {
            root = root,
            root_ordinal = 2,
            unresolved_absolute = "/peer/2026/02/W06/03-z.md",
            resolved_absolute = "/peer/2026/02/W06/03-z.md",
            identity = {
                key = "/peer/z.md",
                source = { root_ordinal = 2, unresolved = "/peer/z.md" },
            },
            stat = { mtime = { sec = 20 } },
        })).value
        local earlier_path = records.adapt(candidate("2026/02/W06/03-a.md", {
            stat = { mtime = { sec = 10 } },
        })).value

        local entries = records.materialize({ earlier_path, later_path }, {})

        assert.equals(later_path.path, entries[1].value)
        assert.truthy(entries[1].ordinal:find("{peer}", 1, true))
    end)

    it("deduplicates overlapping roots by canonical identity", function()
        local first = records.adapt(candidate("K/first.md", {
            identity = {
                key = "/real/note.md",
                source = { root_ordinal = 1, unresolved = "/notes/K/first.md" },
            },
        })).value
        local overlap = records.adapt(candidate("K/overlap.md", {
            root_ordinal = 2,
            identity = {
                key = "/real/note.md",
                source = { root_ordinal = 2, unresolved = "/peer/K/overlap.md" },
            },
        })).value

        local entries = records.materialize({ overlap, first }, {})

        assert.equals(1, #entries)
        assert.equals(first.path, entries[1].value)
    end)

    it("uses the shared static failure kind for malformed candidates", function()
        local result = records.adapt(candidate("K/bad.md", { stat = {} }))

        assert.same({ kind = "failure", failure_kind = failure_kind.invalid_adapter_result }, result)
    end)
end)
