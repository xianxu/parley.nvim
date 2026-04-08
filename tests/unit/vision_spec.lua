-- Unit tests for lua/parley/vision.lua pure functions
--
-- Tests parse_vision_yaml, name_to_id, full_id, resolve_ref,
-- validate_graph, export_csv, export_dot,
-- parse_time, time_to_months, quarters_between, parse_size_months, parse_capacity_weeks

local tmp_dir = "/tmp/parley-test-vision-" .. os.time()

-- Bootstrap parley (needed for vim.split dependency in parser)
local parley = require("parley")
parley.setup({
    chat_dir = tmp_dir,
    state_dir = tmp_dir .. "/state",
    providers = {},
    api_keys = {},
})

local vision = require("parley.vision")

--------------------------------------------------------------------------------
-- parse_vision_yaml
--------------------------------------------------------------------------------

describe("parse_vision_yaml", function()
    it("parses a single item", function()
        local text = [[
- project: Auth Service
  size: S
  need_by: Q3
  depends_on: []
]]
        local items = vision.parse_vision_yaml(text)
        assert.equals(1, #items)
        assert.equals("Auth Service", items[1].project)
        assert.equals("S", items[1].size)
        assert.equals("Q3", items[1].need_by)
        assert.same({}, items[1].depends_on)
    end)

    it("parses multiple items", function()
        local text = [[
- project: Auth Service
  size: S
  need_by: Q3
  depends_on: []

- project: Data Platform
  size: XL
  need_by: Q3-Q4
  depends_on: [auth]
]]
        local items = vision.parse_vision_yaml(text)
        assert.equals(2, #items)
        assert.equals("Auth Service", items[1].project)
        assert.equals("Data Platform", items[2].project)
        assert.same({"auth"}, items[2].depends_on)
    end)

    it("parses inline list with multiple items", function()
        local text = [[
- project: Self-Serve
  depends_on: [data-platform, auth]
]]
        local items = vision.parse_vision_yaml(text)
        assert.equals(1, #items)
        assert.same({"data-platform", "auth"}, items[1].depends_on)
    end)

    it("parses multiline list", function()
        local text = [[
- project: Self-Serve
  depends_on:
    - data-platform
    - auth
]]
        local items = vision.parse_vision_yaml(text)
        assert.equals(1, #items)
        assert.same({"data-platform", "auth"}, items[1].depends_on)
    end)

    it("parses empty multiline list (key with no value)", function()
        local text = [[
- project: Auth
  depends_on:
]]
        local items = vision.parse_vision_yaml(text)
        assert.equals(1, #items)
        assert.same({}, items[1].depends_on)
    end)

    it("skips comments", function()
        local text = [[
# This is a comment
- project: Auth Service
  # inline comment
  size: S
]]
        local items = vision.parse_vision_yaml(text)
        assert.equals(1, #items)
        assert.equals("Auth Service", items[1].project)
        assert.equals("S", items[1].size)
    end)

    it("skips trailing comment at end of file", function()
        local text = [[
- project: Auth Service
  size: S
# trailing comment at end of file
]]
        local items = vision.parse_vision_yaml(text)
        assert.equals(1, #items)
        assert.equals("Auth Service", items[1].project)
        assert.equals("S", items[1].size)
    end)

    it("handles empty input", function()
        local items = vision.parse_vision_yaml("")
        assert.same({}, items)
    end)

    it("handles blank lines between items", function()
        local text = [[
- project: A
  size: S


- project: B
  size: M
]]
        local items = vision.parse_vision_yaml(text)
        assert.equals(2, #items)
    end)

    it("records line numbers", function()
        local text = [[
- project: First
  size: S

- project: Second
  size: M
]]
        local items = vision.parse_vision_yaml(text)
        assert.equals(1, items[1]._line)
        assert.equals(4, items[2]._line)
    end)

    it("handles values with colons", function()
        local text = [[
- project: Auth Service
  need_by: Q3-Q4
]]
        local items = vision.parse_vision_yaml(text)
        assert.equals("Q3-Q4", items[1].need_by)
    end)

    it("multiline list followed by another key", function()
        local text = [[
- project: Auth
  depends_on:
    - data
    - mobile
  size: M
]]
        local items = vision.parse_vision_yaml(text)
        assert.equals(1, #items)
        assert.same({"data", "mobile"}, items[1].depends_on)
        assert.equals("M", items[1].size)
    end)
end)

--------------------------------------------------------------------------------
-- name_to_id
--------------------------------------------------------------------------------

describe("name_to_id", function()
    it("converts name to hyphenated id", function()
        assert.equals("data-platform", vision.name_to_id("Data Platform"))
    end)

    it("handles multiple words", function()
        assert.equals("auth-service-rewrite", vision.name_to_id("Auth Service Rewrite"))
    end)

    it("preserves version numbers", function()
        assert.equals("mobile-app-v2", vision.name_to_id("Mobile App v2"))
    end)

    it("preserves hyphens", function()
        assert.equals("self-serve-onboarding", vision.name_to_id("Self-Serve Onboarding"))
    end)

    it("handles empty string", function()
        assert.equals("", vision.name_to_id(""))
    end)

    it("handles nil", function()
        assert.equals("", vision.name_to_id(nil))
    end)
end)

--------------------------------------------------------------------------------
-- full_id
--------------------------------------------------------------------------------

describe("full_id", function()
    it("combines namespace and name", function()
        assert.equals("px:mobile-app", vision.full_id("px", "Mobile App"))
    end)

    it("works with multi-word names", function()
        assert.equals("sync:auth-service-rewrite", vision.full_id("sync", "Auth Service Rewrite"))
    end)
end)

--------------------------------------------------------------------------------
-- resolve_ref
--------------------------------------------------------------------------------

describe("resolve_ref", function()
    local all_ids = {
        "sync:auth-rewrite",
        "sync:data-platform",
        "px:mobile-app",
        "px:self-serve",
    }

    it("resolves bare prefix within local namespace", function()
        local resolved, err = vision.resolve_ref("auth", "sync", all_ids)
        assert.is_nil(err)
        assert.equals("sync:auth-rewrite", resolved)
    end)

    it("resolves namespaced prefix", function()
        local resolved, err = vision.resolve_ref("px:mobile", "", all_ids)
        assert.is_nil(err)
        assert.equals("px:mobile-app", resolved)
    end)

    it("resolves cross-namespace with bare prefix when no local match", function()
        local resolved, err = vision.resolve_ref("mobile", "sync", all_ids)
        assert.is_nil(err)
        assert.equals("px:mobile-app", resolved)
    end)

    it("errors on ambiguous prefix", function()
        local all = { "sync:service-a", "sync:service-b" }
        local resolved, err = vision.resolve_ref("service", "sync", all)
        assert.is_nil(resolved)
        assert.truthy(err:find("ambiguous"))
    end)

    it("errors on zero match", function()
        local resolved, err = vision.resolve_ref("nonexistent", "sync", all_ids)
        assert.is_nil(resolved)
        assert.truthy(err:find("matches no"))
    end)

    it("errors on empty reference", function()
        local resolved, err = vision.resolve_ref("", "sync", all_ids)
        assert.is_nil(resolved)
        assert.truthy(err:find("empty"))
    end)

    it("prefers local namespace over global", function()
        local resolved, err = vision.resolve_ref("data", "sync", all_ids)
        assert.is_nil(err)
        assert.equals("sync:data-platform", resolved)
    end)

    it("prefers exact match over prefix when names overlap", function()
        local all = { "sync:auth", "sync:auth-v2" }
        local resolved, err = vision.resolve_ref("auth", "sync", all)
        assert.is_nil(err)
        assert.equals("sync:auth", resolved)
    end)

    it("prefers exact match with namespaced ref", function()
        local all = { "sync:auth", "sync:auth-v2" }
        local resolved, err = vision.resolve_ref("sync:auth", "", all)
        assert.is_nil(err)
        assert.equals("sync:auth", resolved)
    end)

    it("resolves hyphenated refs naturally", function()
        local all = { "px:self-serve-onboarding" }
        local resolved, err = vision.resolve_ref("self-serve", "px", all)
        assert.is_nil(err)
        assert.equals("px:self-serve-onboarding", resolved)
    end)

    it("resolves namespaced hyphenated refs", function()
        local all = { "px:self-serve-onboarding" }
        local resolved, err = vision.resolve_ref("px:self-serve", "", all)
        assert.is_nil(err)
        assert.equals("px:self-serve-onboarding", resolved)
    end)

    it("resolves multi-prefix with ...", function()
        local all = { "sync:scope-deletion-in-onprem-within-a-quarter" }
        local resolved, err = vision.resolve_ref("scope ... onprem", "sync", all)
        assert.is_nil(err)
        assert.equals("sync:scope-deletion-in-onprem-within-a-quarter", resolved)
    end)

    it("multi-prefix first segment must match at start", function()
        local all = { "sync:scope-deletion-in-onprem-within-a-quarter" }
        local resolved, err = vision.resolve_ref("deletion ... onprem", "sync", all)
        assert.is_nil(resolved)
        assert.truthy(err:find("matches no"))
    end)

    it("multi-prefix errors on ambiguous match", function()
        local all = {
            "sync:scope-deletion-in-onprem-v1",
            "sync:scope-deletion-in-onprem-v2",
        }
        local resolved, err = vision.resolve_ref("scope ... onprem", "sync", all)
        assert.is_nil(resolved)
        assert.truthy(err:find("ambiguous"))
    end)

    it("multi-prefix resolves unique match across multiple segments", function()
        local all = {
            "sync:scope-deletion-in-onprem-within-a-quarter",
            "sync:scope-creation-in-cloud",
        }
        local resolved, err = vision.resolve_ref("scope ... onprem", "sync", all)
        assert.is_nil(err)
        assert.equals("sync:scope-deletion-in-onprem-within-a-quarter", resolved)
    end)

    it("multi-prefix tries local namespace first", function()
        local all = {
            "sync:scope-deletion-in-onprem",
            "px:scope-deletion-in-onprem",
        }
        local resolved, err = vision.resolve_ref("scope ... onprem", "sync", all)
        assert.is_nil(err)
        assert.equals("sync:scope-deletion-in-onprem", resolved)
    end)

    it("multi-prefix with explicit namespace", function()
        local all = {
            "px:some-secrete-project-1",
            "px:some-secrete-project",
        }
        local resolved, err = vision.resolve_ref("px:some ... 1", "sync", all)
        assert.is_nil(err)
        assert.equals("px:some-secrete-project-1", resolved)
    end)

    it("multi-prefix with explicit namespace doesn't fall back to global", function()
        local all = {
            "sync:scope-deletion-in-onprem",
        }
        local resolved, err = vision.resolve_ref("px:scope ... onprem", "", all)
        assert.is_nil(resolved)
        assert.truthy(err:find("matches no"))
    end)
end)

--------------------------------------------------------------------------------
-- validate_graph
--------------------------------------------------------------------------------

describe("validate_graph", function()
    it("validates a clean graph", function()
        local items = {
            { project = "Auth", _namespace = "sync", depends_on = {} },
            { project = "Data", _namespace = "sync", depends_on = { "auth" } },
        }
        local errors = vision.validate_graph(items)
        assert.same({}, errors)
    end)

    it("detects dangling references", function()
        local items = {
            { project = "Auth", _namespace = "sync", depends_on = { "nonexistent" } },
        }
        local errors = vision.validate_graph(items)
        assert.equals(1, #errors)
        assert.truthy(errors[1].text:find("matches no"))
    end)

    it("detects circular dependencies", function()
        local items = {
            { project = "A", _namespace = "ns", depends_on = { "b" } },
            { project = "B", _namespace = "ns", depends_on = { "a" } },
        }
        local errors = vision.validate_graph(items)
        local has_cycle = false
        for _, e in ipairs(errors) do
            if e.text:find("circular") then has_cycle = true end
        end
        assert.is_true(has_cycle)
    end)

    it("detects duplicate IDs", function()
        local items = {
            { project = "Auth", _namespace = "sync" },
            { project = "Auth", _namespace = "sync" },
        }
        local errors = vision.validate_graph(items)
        local has_dup = false
        for _, e in ipairs(errors) do
            if e.text:find("duplicate") then has_dup = true end
        end
        assert.is_true(has_dup)
    end)

    it("detects missing name", function()
        local items = {
            { _namespace = "sync", depends_on = {} },
        }
        local errors = vision.validate_graph(items)
        assert.equals(1, #errors)
        assert.truthy(errors[1].text:find("is not a project, person, or setting"))
    end)

    it("validates cross-namespace references", function()
        local items = {
            { project = "Auth", _namespace = "sync", depends_on = {} },
            { project = "Mobile", _namespace = "px", depends_on = { "sync:auth" } },
        }
        local errors = vision.validate_graph(items)
        assert.same({}, errors)
    end)

    it("detects need_by ordering violation", function()
        local items = {
            { project = "Auth", _namespace = "sync", need_by = "25Q4", depends_on = {} },
            { project = "Mobile", _namespace = "sync", need_by = "25Q1", depends_on = { "auth" } },
        }
        local errors = vision.validate_graph(items)
        assert.equals(1, #errors)
        assert.truthy(errors[1].text:find("needs by 25Q1"))
        assert.truthy(errors[1].text:find("needs by 25Q4"))
    end)

    it("allows valid need_by ordering", function()
        local items = {
            { project = "Auth", _namespace = "sync", need_by = "25Q1", depends_on = {} },
            { project = "Mobile", _namespace = "sync", need_by = "25Q4", depends_on = { "auth" } },
        }
        local errors = vision.validate_graph(items)
        assert.same({}, errors)
    end)

    it("skips need_by check when source has no need_by", function()
        local items = {
            { project = "Auth", _namespace = "sync", need_by = "25Q4", depends_on = {} },
            { project = "Mobile", _namespace = "sync", need_by = "", depends_on = { "auth" } },
        }
        local errors = vision.validate_graph(items)
        assert.same({}, errors)
    end)

    it("detects dependency with missing need_by when source has one", function()
        local items = {
            { project = "Auth", _namespace = "sync", need_by = "", depends_on = {} },
            { project = "Mobile", _namespace = "sync", need_by = "25Q1", depends_on = { "auth" } },
        }
        local errors = vision.validate_graph(items)
        assert.equals(1, #errors)
        assert.truthy(errors[1].text:find("no need_by"))
    end)

    it("skips person entries without error", function()
        local items = {
            { person = "Alice Chen", capacity = "11w", _namespace = "backend" },
            { project = "Auth", _namespace = "backend", depends_on = {} },
        }
        local errors = vision.validate_graph(items)
        assert.same({}, errors)
    end)

    it("validates person has name", function()
        local items = {
            { person = "", capacity = "11w", _namespace = "backend" },
        }
        local errors = vision.validate_graph(items)
        assert.equals(1, #errors)
        assert.truthy(errors[1].text:find("no name"))
    end)

    it("validates person capacity format", function()
        local items = {
            { person = "Alice", capacity = "bad", _namespace = "backend" },
        }
        local errors = vision.validate_graph(items)
        assert.equals(1, #errors)
        assert.truthy(errors[1].text:find("invalid capacity"))
    end)

    it("validates size format", function()
        local items = {
            { project = "Auth", _namespace = "sync", size = "XXL" },
        }
        local errors = vision.validate_graph(items)
        assert.equals(1, #errors)
        assert.truthy(errors[1].text:find("invalid size"))
    end)

    it("accepts valid month size", function()
        local items = {
            { project = "Auth", _namespace = "sync", size = "3m" },
        }
        local errors = vision.validate_graph(items)
        assert.same({}, errors)
    end)

    it("validates completion range", function()
        local items = {
            { project = "Auth", _namespace = "sync", completion = "150" },
        }
        local errors = vision.validate_graph(items)
        assert.equals(1, #errors)
        assert.truthy(errors[1].text:find("invalid completion"))
    end)

    it("validates start_by format YYQ[1-4]", function()
        local items = {
            { project = "Auth", _namespace = "sync", start_by = "Q3" },
        }
        local errors = vision.validate_graph(items)
        assert.equals(1, #errors)
        assert.truthy(errors[1].text:find("invalid start_by"))
    end)

    it("validates need_by format YYQ[1-4]", function()
        local items = {
            { project = "Auth", _namespace = "sync", need_by = "late Q4" },
        }
        local errors = vision.validate_graph(items)
        assert.equals(1, #errors)
        assert.truthy(errors[1].text:find("invalid need_by"))
    end)

    it("accepts valid quarter format", function()
        local items = {
            { project = "Auth", _namespace = "sync", start_by = "25Q2", need_by = "25Q4" },
        }
        local errors = vision.validate_graph(items)
        assert.same({}, errors)
    end)

    it("warns when need_by is lexically before start_by", function()
        local items = {
            { project = "Auth", _namespace = "sync", start_by = "25Q4", need_by = "25Q2" },
        }
        local errors = vision.validate_graph(items)
        assert.equals(1, #errors)
        assert.truthy(errors[1].text:find('need_by "25Q2" is before start_by "25Q4"'))
    end)

    it("accepts need_by equal to start_by", function()
        local items = {
            { project = "Auth", _namespace = "sync", start_by = "25Q3", need_by = "25Q3" },
        }
        local errors = vision.validate_graph(items)
        assert.same({}, errors)
    end)

    it("skips ordering check when either time field is empty", function()
        local items = {
            { project = "A", _namespace = "sync", start_by = "25Q4" },
            { project = "B", _namespace = "sync", need_by = "25Q1" },
        }
        local errors = vision.validate_graph(items)
        assert.same({}, errors)
    end)
end)

--------------------------------------------------------------------------------
-- export_csv
--------------------------------------------------------------------------------

describe("export_csv", function()
    it("exports header and rows", function()
        local items = {
            { project = "Auth", _namespace = "sync", size = "S",
              need_by = "Q3", depends_on = {} },
            { project = "Data", _namespace = "sync", size = "XL",
              need_by = "Q3-Q4", depends_on = { "auth" } },
        }
        local csv = vision.export_csv(items)
        local lines = vim.split(csv, "\n")
        assert.equals("namespace,project,size,need_by,depends_on", lines[1])
        assert.equals("sync,Auth,S,Q3,", lines[2])
        assert.equals("sync,Data,XL,Q3-Q4,auth", lines[3])
    end)

    it("escapes commas in values", function()
        local items = {
            { project = "A, B", _namespace = "ns", size = "", need_by = "",
              depends_on = {} },
        }
        local csv = vision.export_csv(items)
        local lines = vim.split(csv, "\n")
        assert.truthy(lines[2]:find('"A, B"'))
    end)

    it("handles multiple deps", function()
        local items = {
            { project = "X", _namespace = "ns", size = "", need_by = "",
              depends_on = { "a", "b", "c" } },
        }
        local csv = vision.export_csv(items)
        assert.truthy(csv:find("a; b; c"))
    end)
end)

--------------------------------------------------------------------------------
-- export_dot
--------------------------------------------------------------------------------

describe("export_dot", function()
    it("generates valid DOT", function()
        local items = {
            { project = "Auth", _namespace = "sync", size = "S",
              need_by = "25Q3", depends_on = {} },
            { project = "Data", _namespace = "sync", size = "XL",
              need_by = "25Q4", depends_on = { "auth" } },
        }
        local dot, errors = vision.export_dot(items)
        assert.is_nil(errors)
        assert.truthy(dot:find("digraph vision"))
        assert.truthy(dot:find('"sync:auth"'))
        assert.truthy(dot:find('"sync:data"'))
        assert.truthy(dot:find('"sync:auth" %-> "sync:data"'))
    end)

    it("maps size to node width with linear month scaling", function()
        -- XL=12m → width = 1.5 + 12*0.4 = 6.3
        local items = {
            { project = "Big", _namespace = "ns", size = "XL",
              need_by = "", depends_on = {} },
        }
        local dot = vision.export_dot(items)
        assert.truthy(dot:find("width=6.3"))
    end)

    it("maps month size to node width", function()
        -- 3m → width = 1.5 + 3*0.4 = 2.7
        local items = {
            { project = "Med", _namespace = "ns", size = "3m",
              need_by = "", depends_on = {} },
        }
        local dot = vision.export_dot(items)
        assert.truthy(dot:find("width=2.7"))
    end)

    it("maps namespace to color scheme via setting", function()
        local items = {
            { setting = true, color = "color2", _namespace = "ns" },
            { project = "Biz", _namespace = "ns", size = "M",
              need_by = "", depends_on = {} },
        }
        local dot = vision.export_dot(items)
        assert.truthy(dot:find("#ffe0b2"))  -- color2 base (orange)
    end)

    it("uses default color scheme when no setting", function()
        local items = {
            { project = "Auth", _namespace = "ns", size = "S",
              need_by = "", depends_on = {} },
        }
        local dot = vision.export_dot(items)
        assert.truthy(dot:find("#a0d8ef"))  -- color1 base (blue, default)
    end)

    it("returns errors for invalid graph", function()
        local items = {
            { project = "A", _namespace = "ns", depends_on = { "nonexistent" } },
        }
        local dot, errors = vision.export_dot(items)
        assert.is_nil(dot)
        assert.truthy(#errors > 0)
    end)

    it("filters subgraph by root", function()
        local items = {
            { project = "A", _namespace = "ns", size = "S",
              need_by = "", depends_on = {} },
            { project = "B", _namespace = "ns", size = "M",
              need_by = "", depends_on = { "a" } },
            { project = "C", _namespace = "ns", size = "L",
              need_by = "", depends_on = {} },
        }
        local dot = vision.export_dot(items, { root = "ns:b" })
        assert.truthy(dot:find('"ns:a"'))  -- ancestor of B
        assert.truthy(dot:find('"ns:b"'))  -- root
        assert.is_nil(dot:find('"ns:c"'))  -- unrelated, excluded
    end)

    it("shows completion in label", function()
        local items = {
            { project = "Auth", _namespace = "ns", size = "3m",
              need_by = "25Q3", completion = "33", depends_on = {} },
        }
        local dot = vision.export_dot(items)
        assert.truthy(dot:find("33%%"))
        assert.truthy(dot:find("3m"))
    end)

    it("uses striped fill for partial completion", function()
        local items = {
            { project = "Auth", _namespace = "ns", size = "3m",
              need_by = "25Q3", completion = "50", depends_on = {} },
        }
        local dot = vision.export_dot(items)
        assert.truthy(dot:find("striped"))
        assert.truthy(dot:find("#5b9bd5"))  -- default done color (color1)
        assert.truthy(dot:find("#a0d8ef"))  -- default base color (color1)
    end)

    it("uses solid fill for 0% completion", function()
        local items = {
            { project = "Auth", _namespace = "ns", size = "3m",
              need_by = "25Q3", depends_on = {} },
        }
        local dot = vision.export_dot(items)
        assert.truthy(dot:find("#a0d8ef"))  -- default base color (color1)
        assert.is_nil(dot:find("striped"))
    end)

    it("filters by quarter", function()
        local items = {
            { project = "Active", _namespace = "ns", size = "3m",
              start_by = "25Q3", need_by = "25Q3", depends_on = {} },
            { project = "Future", _namespace = "ns", size = "3m",
              start_by = "26Q1", need_by = "26Q2", depends_on = {} },
        }
        local dot = vision.export_dot(items, { quarter = "25Q3" })
        assert.truthy(dot:find('"ns:active"'))
        assert.is_nil(dot:find('"ns:future"'))
    end)

    it("skips person entries in DOT", function()
        local items = {
            { person = "Alice", capacity = "11w", _namespace = "ns" },
            { project = "Auth", _namespace = "ns", size = "S",
              need_by = "", depends_on = {} },
        }
        local dot = vision.export_dot(items)
        assert.truthy(dot:find('"ns:auth"'))
        assert.is_nil(dot:find("Alice"))
    end)

    it("renders background project with dashed style and bg color", function()
        local items = {
            { project = "~Future Thing", _namespace = "ns", size = "3m",
              need_by = "", depends_on = {} },
        }
        local dot = vision.export_dot(items)
        -- node should exist (~ stripped from display name, ID from stripped name)
        assert.truthy(dot:find("future%-thing") or dot:find("future.thing"))
        -- style must include dashed
        assert.truthy(dot:find("dashed"))
        -- bg color for default scheme (color1 blue) is #dff0f8
        assert.truthy(dot:find("#dff0f8"))
    end)
end)

--------------------------------------------------------------------------------
-- parse_time
--------------------------------------------------------------------------------

describe("parse_time", function()
    it("parses quarter format", function()
        local t = vision.parse_time("25Q3")
        assert.same({ year = 25, q = 3 }, t)
    end)

    it("parses month format", function()
        local t = vision.parse_time("25M11")
        assert.same({ year = 25, m = 11 }, t)
    end)

    it("returns nil for invalid quarter", function()
        assert.is_nil(vision.parse_time("25Q5"))
        assert.is_nil(vision.parse_time("25Q0"))
    end)

    it("returns nil for invalid month", function()
        assert.is_nil(vision.parse_time("25M0"))
        assert.is_nil(vision.parse_time("25M13"))
    end)

    it("returns nil for empty or garbage", function()
        assert.is_nil(vision.parse_time(""))
        assert.is_nil(vision.parse_time(nil))
        assert.is_nil(vision.parse_time("Q3"))
        assert.is_nil(vision.parse_time("foobar"))
    end)

    it("handles whitespace", function()
        local t = vision.parse_time("  25Q2  ")
        assert.same({ year = 25, q = 2 }, t)
    end)
end)

--------------------------------------------------------------------------------
-- time_to_months
--------------------------------------------------------------------------------

describe("time_to_months", function()
    it("converts quarter to absolute months", function()
        -- 25Q1 → 25*12 + 1 = 301
        assert.equals(301, vision.time_to_months({ year = 25, q = 1 }))
        -- 25Q2 → 25*12 + 4 = 304
        assert.equals(304, vision.time_to_months({ year = 25, q = 2 }))
        -- 25Q3 → 25*12 + 7 = 307
        assert.equals(307, vision.time_to_months({ year = 25, q = 3 }))
        -- 25Q4 → 25*12 + 10 = 310
        assert.equals(310, vision.time_to_months({ year = 25, q = 4 }))
    end)

    it("converts month to absolute months", function()
        -- 25M6 → 25*12 + 6 = 306
        assert.equals(306, vision.time_to_months({ year = 25, m = 6 }))
    end)

    it("returns nil for nil input", function()
        assert.is_nil(vision.time_to_months(nil))
    end)
end)

--------------------------------------------------------------------------------
-- quarters_between
--------------------------------------------------------------------------------

describe("quarters_between", function()
    it("same quarter returns 1", function()
        local t = vision.parse_time("25Q2")
        assert.equals(1, vision.quarters_between(t, t))
    end)

    it("adjacent quarters", function()
        local t1 = vision.parse_time("25Q2")
        local t2 = vision.parse_time("25Q3")
        assert.equals(2, vision.quarters_between(t1, t2))
    end)

    it("full year span", function()
        local t1 = vision.parse_time("25Q1")
        local t2 = vision.parse_time("25Q4")
        assert.equals(4, vision.quarters_between(t1, t2))
    end)

    it("cross-year span", function()
        local t1 = vision.parse_time("25Q3")
        local t2 = vision.parse_time("26Q2")
        assert.equals(4, vision.quarters_between(t1, t2))
    end)

    it("returns 0 when end before start", function()
        local t1 = vision.parse_time("25Q3")
        local t2 = vision.parse_time("25Q1")
        assert.equals(0, vision.quarters_between(t1, t2))
    end)

    it("returns nil for nil inputs", function()
        assert.is_nil(vision.quarters_between(nil, vision.parse_time("25Q1")))
        assert.is_nil(vision.quarters_between(vision.parse_time("25Q1"), nil))
    end)
end)

--------------------------------------------------------------------------------
-- parse_size_months
--------------------------------------------------------------------------------

describe("parse_size_months", function()
    it("parses month format", function()
        assert.equals(3, vision.parse_size_months("3m"))
        assert.equals(6, vision.parse_size_months("6m"))
        assert.equals(0.5, vision.parse_size_months("0.5m"))
    end)

    it("maps T-shirt sizes to months", function()
        assert.equals(1, vision.parse_size_months("S"))
        assert.equals(3, vision.parse_size_months("M"))
        assert.equals(6, vision.parse_size_months("L"))
        assert.equals(12, vision.parse_size_months("XL"))
    end)

    it("returns nil for invalid input", function()
        assert.is_nil(vision.parse_size_months(""))
        assert.is_nil(vision.parse_size_months(nil))
        assert.is_nil(vision.parse_size_months("0m"))
        assert.is_nil(vision.parse_size_months("foobar"))
    end)

    it("handles whitespace", function()
        assert.equals(3, vision.parse_size_months("  3m  "))
    end)
end)

--------------------------------------------------------------------------------
-- parse_capacity_weeks
--------------------------------------------------------------------------------

describe("parse_capacity_weeks", function()
    it("parses week format", function()
        assert.equals(11, vision.parse_capacity_weeks("11w"))
        assert.equals(10, vision.parse_capacity_weeks("10w"))
        assert.equals(5.5, vision.parse_capacity_weeks("5.5w"))
    end)

    it("returns nil for invalid input", function()
        assert.is_nil(vision.parse_capacity_weeks(""))
        assert.is_nil(vision.parse_capacity_weeks(nil))
        assert.is_nil(vision.parse_capacity_weeks("0w"))
        assert.is_nil(vision.parse_capacity_weeks("11m"))
        assert.is_nil(vision.parse_capacity_weeks("foobar"))
    end)

    it("handles whitespace", function()
        assert.equals(11, vision.parse_capacity_weeks("  11w  "))
    end)
end)

--------------------------------------------------------------------------------
-- quarterly_charge
--------------------------------------------------------------------------------

describe("quarterly_charge", function()
    local q2 = vision.parse_time("25Q2")
    local q3 = vision.parse_time("25Q3")
    local q4 = vision.parse_time("25Q4")
    local q1_26 = vision.parse_time("26Q1")

    it("charges remaining effort distributed across quarters", function()
        -- 6m project, 25Q2-25Q4, 0% complete, range=25Q3
        local proj = { size = "6m", start_by = "25Q2", need_by = "25Q4", completion = "0" }
        local charge = vision.quarterly_charge(proj, q3, q3)
        assert.is_true(charge > 0)
        assert.is_true(charge <= 6)
    end)

    it("returns 0 for 100% complete project", function()
        local proj = { size = "6m", start_by = "25Q2", need_by = "25Q4", completion = "100" }
        assert.equals(0, vision.quarterly_charge(proj, q3, q3))
    end)

    it("returns 0 when project starts after range", function()
        local proj = { size = "3m", start_by = "25Q4", need_by = "26Q1" }
        assert.equals(0, vision.quarterly_charge(proj, q2, q3))
    end)

    it("charges full remaining for overdue projects", function()
        -- need_by 25Q2, but range is 25Q3 — overdue
        local proj = { size = "6m", start_by = "25Q1", need_by = "25Q2", completion = "50" }
        local charge = vision.quarterly_charge(proj, q3, q3)
        assert.equals(3, charge)  -- 6 * (1 - 0.5) = 3
    end)

    it("accounts for completion reducing remaining", function()
        local proj = { size = "6m", start_by = "25Q2", need_by = "25Q4", completion = "33" }
        local charge = vision.quarterly_charge(proj, q2, q4)
        -- remaining = 6 * 0.67 = 4.02, full overlap → all charged
        assert.near(4.02, charge, 0.01)
    end)

    it("handles T-shirt sizes", function()
        local proj = { size = "M", start_by = "25Q3", need_by = "25Q3" }
        local charge = vision.quarterly_charge(proj, q3, q3)
        assert.equals(3, charge)  -- M=3m, 1 quarter, full overlap
    end)

    it("defaults missing start_by to range_start", function()
        local proj = { size = "3m", need_by = "25Q3" }
        local charge = vision.quarterly_charge(proj, q2, q3)
        assert.is_true(charge > 0)
    end)

    it("defaults missing need_by to range_end", function()
        local proj = { size = "3m", start_by = "25Q2" }
        local charge = vision.quarterly_charge(proj, q2, q3)
        assert.is_true(charge > 0)
    end)

    it("returns 0 for nil inputs", function()
        assert.equals(0, vision.quarterly_charge(nil, q2, q3))
        assert.equals(0, vision.quarterly_charge({}, q2, nil))
    end)
end)

--------------------------------------------------------------------------------
-- allocation_summary
--------------------------------------------------------------------------------

describe("allocation_summary", function()
    local q3 = vision.parse_time("25Q3")

    it("groups persons and projects by namespace", function()
        local items = {
            { person = "Alice", capacity = "11w", _namespace = "backend" },
            { person = "Bob", capacity = "10w", _namespace = "backend" },
            { project = "API Gateway", size = "3m", start_by = "25Q3", need_by = "25Q3",
              _namespace = "backend" },
        }
        local summary = vision.allocation_summary(items, q3, q3)
        assert.is_not_nil(summary.backend)
        assert.equals(21, summary.backend.capacity_weeks)
        assert.equals(2, #summary.backend.persons)
        assert.equals(1, #summary.backend.projects)
        assert.is_true(summary.backend.demand_weeks > 0)
    end)

    it("handles empty items", function()
        local summary = vision.allocation_summary({}, q3, q3)
        assert.same({}, summary)
    end)

    it("separates namespaces", function()
        local items = {
            { person = "Alice", capacity = "11w", _namespace = "backend" },
            { project = "Mobile App", size = "3m", start_by = "25Q3", need_by = "25Q3",
              _namespace = "frontend" },
        }
        local summary = vision.allocation_summary(items, q3, q3)
        assert.is_not_nil(summary.backend)
        assert.is_not_nil(summary.frontend)
        assert.equals(0, summary.backend.demand_weeks)
        assert.equals(0, summary.frontend.capacity_weeks)
    end)
end)

--------------------------------------------------------------------------------
-- overlay_files
--------------------------------------------------------------------------------

describe("overlay_files", function()
    it("returns base files when no current files", function()
        local base = { "/a/backend.yaml", "/a/frontend.yaml" }
        local result = vision.overlay_files(base, {})
        assert.same({ "/a/backend.yaml", "/a/frontend.yaml" }, result)
    end)

    it("returns current files when no base files", function()
        local current = { "/b/backend.yaml" }
        local result = vision.overlay_files({}, current)
        assert.same({ "/b/backend.yaml" }, result)
    end)

    it("current overrides base by filename", function()
        local base = { "/a/backend.yaml", "/a/frontend.yaml" }
        local current = { "/b/backend.yaml" }
        local result = vision.overlay_files(base, current)
        -- backend.yaml from current, frontend.yaml from base
        assert.equals(2, #result)
        assert.equals("/b/backend.yaml", result[1])
        assert.equals("/a/frontend.yaml", result[2])
    end)

    it("merges new files from current", function()
        local base = { "/a/backend.yaml" }
        local current = { "/b/mobile.yaml" }
        local result = vision.overlay_files(base, current)
        assert.equals(2, #result)
        assert.equals("/a/backend.yaml", result[1])
        assert.equals("/b/mobile.yaml", result[2])
    end)

    it("result is sorted by filename", function()
        local base = { "/a/z.yaml" }
        local current = { "/b/a.yaml" }
        local result = vision.overlay_files(base, current)
        assert.equals("/b/a.yaml", result[1])
        assert.equals("/a/z.yaml", result[2])
    end)

    it("handles nil inputs", function()
        assert.same({}, vision.overlay_files(nil, nil))
    end)
end)

--------------------------------------------------------------------------------
-- export_allocation_report
--------------------------------------------------------------------------------

describe("export_allocation_report", function()
    it("generates markdown report with capacity and demand", function()
        local items = {
            { person = "Alice Chen", capacity = "11w", _namespace = "backend" },
            { person = "Bob Park", capacity = "10w", _namespace = "backend" },
            { project = "API Gateway", size = "3m", start_by = "25Q3", need_by = "25Q3",
              _namespace = "backend" },
        }
        local report = vision.export_allocation_report(items, "25Q3")
        assert.truthy(report:find("## backend"))
        assert.truthy(report:find("| Alice Chen"))
        assert.truthy(report:find("| Bob Park"))
        assert.truthy(report:find("| API Gateway"))
        assert.truthy(report:find("%*%*Team capacity:"))
        assert.truthy(report:find("%*%*Project demand:"))
        assert.truthy(report:find("%*%*Balance:"))
    end)

    it("shows over-committed warning", function()
        local items = {
            { person = "Alice", capacity = "5w", _namespace = "team" },
            { project = "Big Project", size = "6m", start_by = "25Q3", need_by = "25Q3",
              _namespace = "team" },
        }
        local report = vision.export_allocation_report(items, "25Q3")
        assert.truthy(report:find("over%-committed"))
    end)

    it("returns empty string for nil inputs", function()
        assert.equals("", vision.export_allocation_report(nil, "25Q3"))
        assert.equals("", vision.export_allocation_report({}, nil))
    end)

    it("handles multiple namespaces", function()
        local items = {
            { person = "Alice", capacity = "11w", _namespace = "backend" },
            { person = "Bob", capacity = "10w", _namespace = "frontend" },
        }
        local report = vision.export_allocation_report(items, "25Q3")
        assert.truthy(report:find("## backend"))
        assert.truthy(report:find("## frontend"))
    end)

    it("shows projection column with shortfall warning", function()
        -- 5w capacity, 6m project = 26w demand → shortfall
        local items = {
            { person = "Alice", capacity = "5w", _namespace = "team" },
            { project = "Big", size = "6m", start_by = "25Q3", need_by = "25Q3",
              _namespace = "team" },
        }
        local report = vision.export_allocation_report(items, "25Q3")
        assert.truthy(report:find("Projection"))
    end)

    it("excludes background projects from demand and lists them separately", function()
        local items = {
            { person = "Alice", capacity = "11w", _namespace = "team" },
            { project = "Active Work", size = "3m", start_by = "25Q3", need_by = "25Q3",
              _namespace = "team" },
            { project = "~Future Thing", size = "6m", start_by = "25Q4", need_by = "25Q4",
              _namespace = "team" },
        }
        local report = vision.export_allocation_report(items, "25Q3")
        -- background project appears in bg section
        assert.truthy(report:find("Future Thing %[bg%]"))
        -- background project not in demand table
        assert.falsy(report:find("| Future Thing |"))
        -- demand only counts active work (3m × 1q = 3m ≈ 13w), not background
        assert.truthy(report:find("Balance: %+"))  -- should not be over-committed
    end)
end)

--------------------------------------------------------------------------------
-- project_projections
--------------------------------------------------------------------------------

describe("project_projections", function()
    it("fully funds project when capacity is sufficient", function()
        local items = {
            { person = "Alice", capacity = "20w", _namespace = "ns" },
            { project = "A", size = "3m", start_by = "25Q3", need_by = "25Q3",
              _namespace = "ns", depends_on = {} },
        }
        local proj = vision.project_projections(items, "25Q3")
        assert.is_not_nil(proj["ns:a"])
        assert.equals(0, proj["ns:a"].current)
        -- planned == achievable when fully funded
        assert.equals(proj["ns:a"].planned, proj["ns:a"].achievable)
        assert.is_true(proj["ns:a"].planned > 0)
    end)

    it("partially funds when capacity is insufficient", function()
        -- 3w capacity, 3m project (= ~13w) → partially funded
        local items = {
            { person = "Alice", capacity = "3w", _namespace = "ns" },
            { project = "A", size = "3m", start_by = "25Q3", need_by = "25Q3",
              _namespace = "ns", depends_on = {} },
        }
        local proj = vision.project_projections(items, "25Q3")
        assert.is_not_nil(proj["ns:a"])
        assert.is_true(proj["ns:a"].achievable < proj["ns:a"].planned)
        assert.is_true(proj["ns:a"].achievable > 0)
    end)

    it("respects dependency ordering", function()
        -- 15w capacity, two 3m projects (each ~13w). A has no deps, B depends on A.
        -- A should be fully funded, B gets remaining capacity (partial or none).
        local items = {
            { person = "Alice", capacity = "15w", _namespace = "ns" },
            { project = "A", size = "3m", start_by = "25Q3", need_by = "25Q3",
              _namespace = "ns", depends_on = {} },
            { project = "B", size = "3m", start_by = "25Q3", need_by = "25Q3",
              _namespace = "ns", depends_on = { "a" } },
        }
        local proj = vision.project_projections(items, "25Q3")
        -- A should be fully funded
        assert.equals(proj["ns:a"].planned, proj["ns:a"].achievable)
        -- B should be partially funded (only ~2w left after A's ~13w)
        assert.is_true(proj["ns:b"].achievable < proj["ns:b"].planned)
    end)

    it("accounts for existing completion", function()
        local items = {
            { person = "Alice", capacity = "20w", _namespace = "ns" },
            { project = "A", size = "6m", start_by = "25Q3", need_by = "25Q4",
              completion = "50", _namespace = "ns", depends_on = {} },
        }
        local proj = vision.project_projections(items, "25Q3")
        assert.equals(50, proj["ns:a"].current)
        assert.is_true(proj["ns:a"].planned > 50)
    end)

    it("returns empty on invalid inputs", function()
        assert.same({}, vision.project_projections(nil, "25Q3"))
        assert.same({}, vision.project_projections({}, nil))
    end)

    it("handles cross-namespace deps as ordering only", function()
        -- Two namespaces, each with their own capacity
        local items = {
            { person = "Alice", capacity = "20w", _namespace = "backend" },
            { person = "Bob", capacity = "20w", _namespace = "frontend" },
            { project = "API", size = "3m", start_by = "25Q3", need_by = "25Q3",
              _namespace = "backend", depends_on = {} },
            { project = "UI", size = "3m", start_by = "25Q3", need_by = "25Q3",
              _namespace = "frontend", depends_on = { "backend: api" } },
        }
        local proj = vision.project_projections(items, "25Q3")
        -- Both should be fully funded from their own namespace capacity
        assert.equals(proj["backend:api"].planned, proj["backend:api"].achievable)
        assert.equals(proj["frontend:ui"].planned, proj["frontend:ui"].achievable)
    end)

    it("prioritizes projects with ! in name", function()
        -- 15w capacity, two 3m projects (~13w each). B!! has higher priority.
        -- B!! should be fully funded, A gets remaining.
        local items = {
            { person = "Alice", capacity = "15w", _namespace = "ns" },
            { project = "A", size = "3m", start_by = "25Q3", need_by = "25Q3",
              _namespace = "ns", depends_on = {} },
            { project = "B!!", size = "3m", start_by = "25Q3", need_by = "25Q3",
              _namespace = "ns", depends_on = {} },
        }
        local proj = vision.project_projections(items, "25Q3")
        -- B!! should be fully funded (higher priority)
        assert.equals(proj["ns:b"].planned, proj["ns:b"].achievable)
        -- A should be partially funded
        assert.is_true(proj["ns:a"].achievable < proj["ns:a"].planned)
    end)

    it("propagates priority through deps", function()
        -- 15w capacity, A (no priority) → B!! (priority 2). A should get elevated.
        -- Both should be funded before C (no priority, no dep from B).
        local items = {
            { person = "Alice", capacity = "15w", _namespace = "ns" },
            { project = "A", size = "3m", start_by = "25Q3", need_by = "25Q3",
              _namespace = "ns", depends_on = {} },
            { project = "B!!", size = "3m", start_by = "25Q3", need_by = "25Q3",
              _namespace = "ns", depends_on = { "a" } },
            { project = "C", size = "3m", start_by = "25Q3", need_by = "25Q3",
              _namespace = "ns", depends_on = {} },
        }
        local proj = vision.project_projections(items, "25Q3")
        -- A gets elevated priority from B!!, so A is fully funded
        assert.equals(proj["ns:a"].planned, proj["ns:a"].achievable)
        -- B!! depends on A, also high priority, gets remaining ~2w (partial)
        -- C has no priority, gets nothing
        assert.is_true(proj["ns:c"].achievable <= proj["ns:c"].current or
                       proj["ns:c"].achievable < proj["ns:c"].planned)
    end)
end)

--------------------------------------------------------------------------------
-- parse_priority
--------------------------------------------------------------------------------

describe("parse_priority", function()
    it("strips trailing bangs", function()
        local name, prio = vision.parse_priority("EHR Sync!!")
        assert.equals("EHR Sync", name)
        assert.equals(2, prio)
    end)

    it("returns 0 for no bangs", function()
        local name, prio = vision.parse_priority("Auth Service")
        assert.equals("Auth Service", name)
        assert.equals(0, prio)
    end)

    it("handles single bang", function()
        local name, prio = vision.parse_priority("Urgent!")
        assert.equals("Urgent", name)
        assert.equals(1, prio)
    end)

    it("handles many bangs", function()
        local name, prio = vision.parse_priority("Critical!!!!")
        assert.equals("Critical", name)
        assert.equals(4, prio)
    end)

    it("handles nil and empty", function()
        local name, prio = vision.parse_priority(nil)
        assert.is_nil(name)
        assert.equals(0, prio)

        name, prio = vision.parse_priority("")
        assert.equals("", name)
        assert.equals(0, prio)
    end)

    it("does not affect name_to_id", function()
        assert.equals("ehr-sync", vision.name_to_id("EHR Sync!!"))
        assert.equals("auth", vision.name_to_id("Auth!"))
    end)

    it("strips leading ~ background marker", function()
        local name, prio = vision.parse_priority("~Foo Bar")
        assert.equals("Foo Bar", name)
        assert.equals(0, prio)
    end)

    it("strips ~ and bangs together", function()
        local name, prio = vision.parse_priority("~Foo Bar!")
        assert.equals("Foo Bar", name)
        assert.equals(1, prio)
    end)
end)

--------------------------------------------------------------------------------
-- is_background
--------------------------------------------------------------------------------

describe("is_background", function()
    it("returns true for ~ prefix", function()
        assert.is_true(vision.is_background("~Auth Service"))
    end)

    it("returns false for regular names", function()
        assert.is_false(vision.is_background("Auth Service"))
    end)

    it("returns false for nil", function()
        assert.is_false(vision.is_background(nil))
    end)

    it("returns false for empty string", function()
        assert.is_false(vision.is_background(""))
    end)

    it("returns false for bang-only names", function()
        assert.is_false(vision.is_background("Urgent!"))
    end)
end)
