-- Unit tests for lua/parley/vision.lua pure functions
--
-- Tests parse_vision_yaml, name_to_id, full_id, resolve_ref,
-- validate_graph, export_csv, export_dot

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
  type: tech
  size: S
  need_by: Q3
  depends_on: []
]]
        local items = vision.parse_vision_yaml(text)
        assert.equals(1, #items)
        assert.equals("Auth Service", items[1].project)
        assert.equals("tech", items[1].type)
        assert.equals("S", items[1].size)
        assert.equals("Q3", items[1].need_by)
        assert.same({}, items[1].depends_on)
    end)

    it("parses multiple items", function()
        local text = [[
- project: Auth Service
  type: tech
  size: S
  need_by: Q3
  depends_on: []

- project: Data Platform
  type: tech
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
  type: tech
  # inline comment
  size: S
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
        assert.equals("px.mobile-app", vision.full_id("px", "Mobile App"))
    end)

    it("works with multi-word names", function()
        assert.equals("sync.auth-service-rewrite", vision.full_id("sync", "Auth Service Rewrite"))
    end)
end)

--------------------------------------------------------------------------------
-- resolve_ref
--------------------------------------------------------------------------------

describe("resolve_ref", function()
    local all_ids = {
        "sync.auth-rewrite",
        "sync.data-platform",
        "px.mobile-app",
        "px.self-serve",
    }

    it("resolves bare prefix within local namespace", function()
        local resolved, err = vision.resolve_ref("auth", "sync", all_ids)
        assert.is_nil(err)
        assert.equals("sync.auth-rewrite", resolved)
    end)

    it("resolves namespaced prefix", function()
        local resolved, err = vision.resolve_ref("px.mobile", "", all_ids)
        assert.is_nil(err)
        assert.equals("px.mobile-app", resolved)
    end)

    it("resolves cross-namespace with bare prefix when no local match", function()
        local resolved, err = vision.resolve_ref("mobile", "sync", all_ids)
        assert.is_nil(err)
        assert.equals("px.mobile-app", resolved)
    end)

    it("errors on ambiguous prefix", function()
        local all = { "sync.service-a", "sync.service-b" }
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
        assert.equals("sync.data-platform", resolved)
    end)

    it("prefers exact match over prefix when names overlap", function()
        local all = { "sync.auth", "sync.auth-v2" }
        local resolved, err = vision.resolve_ref("auth", "sync", all)
        assert.is_nil(err)
        assert.equals("sync.auth", resolved)
    end)

    it("prefers exact match with namespaced ref", function()
        local all = { "sync.auth", "sync.auth-v2" }
        local resolved, err = vision.resolve_ref("sync.auth", "", all)
        assert.is_nil(err)
        assert.equals("sync.auth", resolved)
    end)

    it("resolves hyphenated refs naturally", function()
        local all = { "px.self-serve-onboarding" }
        local resolved, err = vision.resolve_ref("self-serve", "px", all)
        assert.is_nil(err)
        assert.equals("px.self-serve-onboarding", resolved)
    end)

    it("resolves namespaced hyphenated refs", function()
        local all = { "px.self-serve-onboarding" }
        local resolved, err = vision.resolve_ref("px.self-serve", "", all)
        assert.is_nil(err)
        assert.equals("px.self-serve-onboarding", resolved)
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
        assert.truthy(errors[1].text:find("is not a project"))
    end)

    it("validates cross-namespace references", function()
        local items = {
            { project = "Auth", _namespace = "sync", depends_on = {} },
            { project = "Mobile", _namespace = "px", depends_on = { "sync.auth" } },
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
end)

--------------------------------------------------------------------------------
-- export_csv
--------------------------------------------------------------------------------

describe("export_csv", function()
    it("exports header and rows", function()
        local items = {
            { project = "Auth", _namespace = "sync", type = "tech", size = "S",
              need_by = "Q3", depends_on = {} },
            { project = "Data", _namespace = "sync", type = "tech", size = "XL",
              need_by = "Q3-Q4", depends_on = { "auth" } },
        }
        local csv = vision.export_csv(items)
        local lines = vim.split(csv, "\n")
        assert.equals("namespace,project,type,size,need_by,depends_on", lines[1])
        assert.equals("sync,Auth,tech,S,Q3,", lines[2])
        assert.equals("sync,Data,tech,XL,Q3-Q4,auth", lines[3])
    end)

    it("escapes commas in values", function()
        local items = {
            { project = "A, B", _namespace = "ns", type = "", size = "", need_by = "",
              depends_on = {} },
        }
        local csv = vision.export_csv(items)
        local lines = vim.split(csv, "\n")
        assert.truthy(lines[2]:find('"A, B"'))
    end)

    it("handles multiple deps", function()
        local items = {
            { project = "X", _namespace = "ns", type = "", size = "", need_by = "",
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
            { project = "Auth", _namespace = "sync", type = "tech", size = "S",
              need_by = "Q3", depends_on = {} },
            { project = "Data", _namespace = "sync", type = "tech", size = "XL",
              need_by = "Q3-Q4", depends_on = { "auth" } },
        }
        local dot, errors = vision.export_dot(items)
        assert.is_nil(errors)
        assert.truthy(dot:find("digraph vision"))
        assert.truthy(dot:find('"sync.auth"'))
        assert.truthy(dot:find('"sync.data"'))
        assert.truthy(dot:find('"sync.auth" %-> "sync.data"'))
    end)

    it("maps size to node width", function()
        local items = {
            { project = "Big", _namespace = "ns", type = "tech", size = "XL",
              need_by = "", depends_on = {} },
        }
        local dot = vision.export_dot(items)
        assert.truthy(dot:find("width=3.0"))
    end)

    it("maps type to color", function()
        local items = {
            { project = "Biz", _namespace = "ns", type = "business", size = "M",
              need_by = "", depends_on = {} },
        }
        local dot = vision.export_dot(items)
        assert.truthy(dot:find("#ffe0b2"))
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
            { project = "A", _namespace = "ns", type = "tech", size = "S",
              need_by = "", depends_on = {} },
            { project = "B", _namespace = "ns", type = "tech", size = "M",
              need_by = "", depends_on = { "a" } },
            { project = "C", _namespace = "ns", type = "tech", size = "L",
              need_by = "", depends_on = {} },
        }
        local dot = vision.export_dot(items, { root = "ns.b" })
        assert.truthy(dot:find('"ns.a"'))  -- ancestor of B
        assert.truthy(dot:find('"ns.b"'))  -- root
        assert.is_nil(dot:find('"ns.c"'))  -- unrelated, excluded
    end)
end)
