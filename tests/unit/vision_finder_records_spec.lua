local finder_scan = require("parley.finder_scan")
local vision = require("parley.vision")
local records = require("parley.vision_finder_records")

local function identity(key, root_ordinal)
    return {
        key = key,
        source = { root_ordinal = root_ordinal or 1, unresolved = key },
    }
end

local function candidate(overrides)
    local value = {
        path = "/repo/workshop/vision/platform.yaml",
        name = "platform.yaml",
        lines = {
            "- project: Auth Service!!",
            "  size: M",
            "  depends_on: [data]",
            "- person: Ada",
            "  capacity: 11w",
            "- project: Data Platform",
            "  need_by: 26Q4",
        },
        repo_name = "parley.nvim",
        identity = identity("/repo/workshop/vision/platform.yaml"),
    }
    for key, item in pairs(overrides or {}) do
        value[key] = item
    end
    return value
end

describe("Vision finder records", function()
    it("adapts one YAML file into a metadata-rich initiative bundle through the shared parser", function()
        local input = candidate()
        local result = records.adapt(input)
        local parsed = vision.parse_vision_yaml(input.lines)

        assert.equals("record", result.kind)
        assert.equals(input.identity, result.value.identity)
        assert.same({
            path = input.path,
            name = input.name,
            namespace = "platform",
            repo_name = "parley.nvim",
        }, result.value.source)
        assert.equals(#parsed, #result.value.initiatives)
        assert.equals("Auth Service!!", result.value.initiatives[1].project)
        assert.equals("platform", result.value.initiatives[1]._namespace)
        assert.equals(input.path, result.value.initiatives[1]._file)
        assert.equals(1, result.value.initiatives[1]._line)
        assert.equals("parley.nvim", result.value.initiatives[1]._repo_name)
    end)

    it("intentionally skips non-YAML files", function()
        assert.same({ kind = "skip" }, records.adapt(candidate({ name = "README.md" })))
    end)

    it("returns a registered static failure for malformed adapter input", function()
        local result = records.adapt(candidate({ lines = { "ok", false } }))
        assert.equals("failure", result.kind)
        assert.is_true(finder_scan.is_failure_kind(result.failure_kind))
    end)

    it("does not mutate its input", function()
        local input = candidate()
        local before = vim.deepcopy(input)
        records.adapt(input)
        assert.same(before, input)
    end)

    it("deduplicates file bundles before flattening all projects in parser order", function()
        local primary = records.adapt(candidate()).value
        local duplicate = records.adapt(candidate({
            path = "/alias/platform.yaml",
            identity = identity("/repo/workshop/vision/platform.yaml", 2),
            lines = { "- project: Wrong duplicate" },
        })).value
        local earlier = records.adapt(candidate({
            path = "/repo/workshop/vision/alpha.yaml",
            name = "alpha.yaml",
            identity = identity("/repo/workshop/vision/alpha.yaml"),
            repo_name = nil,
            lines = { "- project: Alpha" },
        })).value

        local items = records.materialize_records({ primary, duplicate, earlier })

        assert.same({ "Alpha", "Auth Service", "Data Platform" },
            vim.tbl_map(function(item) return item.project end, items))
        assert.same({ 1, 1, 6 }, vim.tbl_map(function(item) return item.line end, items))
        assert.equals(3, #items)
        assert.equals("Auth Service", vision.parse_priority(items[2].project))
    end)

    it("uses collision-safe length-prefixed file identity plus parser ordinal keys", function()
        local bundle = records.adapt(candidate()).value
        local items = records.materialize_records({ bundle })

        assert.equals(
            tostring(#bundle.identity.key) .. ":" .. bundle.identity.key .. ":1",
            items[1].key
        )
        assert.equals(
            tostring(#bundle.identity.key) .. ":" .. bundle.identity.key .. ":3",
            items[2].key
        )
    end)

    it("keeps adapter exceptions contained by the shared batcher", function()
        local results = {}
        finder_scan.new_batcher({
            item_budget = 25,
            time_budget_ms = 5,
            now = function() return 0 end,
            schedule = function(callback) callback() end,
        }):run({ candidate() }, function()
            error("bad yaml adapter")
        end, function(result)
            results[#results + 1] = result
        end, function() end)

        assert.equals("failure", results[1].kind)
        assert.equals(finder_scan.FAILURE_KIND.adapter_exception, results[1].failure_kind)
    end)
end)
