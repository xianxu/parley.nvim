local records = require("parley.chat_finder_records")
local failure_kind = require("parley.finder_scan").FAILURE_KIND

local function candidate(overrides)
    local value = {
        path = "/chats/2026-02-03-10-20-30-release.md",
        identity = {
            key = "/chats/release.md",
            source = { root_ordinal = 1, unresolved = "/chats/release.md" },
        },
        stat = { mtime = { sec = 100 } },
        root = { path = "/chats", label = "main", is_primary = true },
    }
    for key, item in pairs(overrides or {}) do
        value[key] = item
    end
    return value
end

describe("Chat finder records", function()
    it("adapts cached metadata without requiring header lines", function()
        local input = candidate({
            kind = "cached",
            metadata = { topic = "Cached topic", tags = { "roadmap", "launch" } },
        })

        local result = records.adapt(input)

        assert.equals("record", result.kind)
        assert.equals("Cached topic", result.value.topic)
        assert.same({ "roadmap", "launch" }, result.value.tags)
        assert.equals(100, result.value.mtime)
    end)

    it("parses topic and tags from already-read frontmatter lines", function()
        local input = candidate({
            kind = "lines",
            first_lines = {
                "---",
                "topic: Shipping notes",
                "tags: roadmap, launch internal",
                "---",
            },
        })

        local result = records.adapt(input)

        assert.equals("record", result.kind)
        assert.equals("Shipping notes", result.value.topic)
        assert.same({ "roadmap", "launch", "internal" }, result.value.tags)
    end)

    it("keeps the legacy dashed timestamp fast path and dotted-name mtime fallback", function()
        local dashed = records.adapt(candidate({
            kind = "cached",
            metadata = { topic = "Dashed", tags = {} },
        })).value
        local dotted = records.adapt(candidate({
            kind = "cached",
            path = "/chats/2026-02-03.10-20-30.123-dotted.md",
            stat = { mtime = { sec = 777 } },
            metadata = { topic = "Dotted", tags = {} },
        })).value

        assert.equals(os.time({ year = 2026, month = 2, day = 3, hour = 10, min = 20, sec = 30 }),
            dashed.timestamp)
        assert.equals(777, dotted.timestamp)
    end)

    it("materializes recency, root, tags, and deterministic timestamp/path ordering", function()
        local recent_secondary = records.adapt(candidate({
            kind = "cached",
            path = "/other/2026-02-03-10-20-30-z.md",
            identity = {
                key = "/other/z.md",
                source = { root_ordinal = 2, unresolved = "/other/z.md" },
            },
            root = { path = "/other", label = "secondary", is_primary = false },
            metadata = { topic = "Zed", tags = { "launch" } },
        })).value
        local recent_primary = records.adapt(candidate({
            kind = "cached",
            path = "/chats/2026-02-03-10-20-30-a.md",
            identity = {
                key = "/chats/a.md",
                source = { root_ordinal = 1, unresolved = "/chats/a.md" },
            },
            metadata = { topic = "Alpha", tags = {} },
        })).value
        local old = records.adapt(candidate({
            kind = "cached",
            path = "/chats/2020-01-01-00-00-00-old.md",
            identity = {
                key = "/chats/old.md",
                source = { root_ordinal = 1, unresolved = "/chats/old.md" },
            },
            metadata = { topic = "Old", tags = {} },
        })).value

        local entries = records.materialize({ recent_secondary, old, recent_primary }, {
            cutoff_time = os.time({ year = 2025, month = 1, day = 1, hour = 0 }),
        })

        assert.same({ recent_primary.path, recent_secondary.path },
            vim.tbl_map(function(entry) return entry.value end, entries))
        assert.matches("%{%}", entries[1].ordinal)
        assert.matches("%[%]", entries[1].ordinal)
        assert.truthy(entries[2].display:find("{secondary}", 1, true))
        assert.matches("%[launch%]", entries[2].display)
    end)

    it("deduplicates overlapping roots and symlink identities before materialization", function()
        local first = records.adapt(candidate({
            kind = "cached",
            path = "/primary/chat.md",
            identity = {
                key = "/real/chat.md",
                source = { root_ordinal = 1, unresolved = "/primary/chat.md" },
            },
            metadata = { topic = "Primary", tags = {} },
        })).value
        local overlap = records.adapt(candidate({
            kind = "cached",
            path = "/overlap/chat.md",
            identity = {
                key = "/real/chat.md",
                source = { root_ordinal = 2, unresolved = "/overlap/chat.md" },
            },
            metadata = { topic = "Overlap", tags = {} },
        })).value

        local entries = records.materialize({ overlap, first }, {})

        assert.equals(1, #entries)
        assert.equals("/primary/chat.md", entries[1].value)
    end)

    it("returns ready only for an unchanged canonical path and requests ten lines otherwise", function()
        local cached = { ["/real/chat.md"] = { mtime = 100, topic = "Cached", tags = {} } }
        local unchanged = candidate({ identity = { key = "/real/chat.md" } })
        local changed = candidate({
            identity = { key = "/real/chat.md" },
            stat = { mtime = { sec = 101 } },
        })

        assert.same({ kind = "ready", value = cached["/real/chat.md"] },
            records.read_decision(cached, unchanged))
        assert.same({ kind = "read", mode = { head_lines = 10 } },
            records.read_decision(cached, changed))
        assert.same({ kind = "read", mode = { head_lines = 10 } },
            records.read_decision({}, unchanged))
    end)

    it("uses the shared static failure kind for malformed adapter input", function()
        local result = records.adapt(candidate({ kind = "lines", first_lines = "not-lines" }))

        assert.same({ kind = "failure", failure_kind = failure_kind.invalid_adapter_result }, result)
    end)
end)
