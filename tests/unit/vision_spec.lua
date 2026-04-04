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
- name: Auth Service
  type: tech
  size: S
  quarter: Q3
  depends_on: []
]]
        local items = vision.parse_vision_yaml(text)
        assert.equals(1, #items)
        assert.equals("Auth Service", items[1].name)
        assert.equals("tech", items[1].type)
        assert.equals("S", items[1].size)
        assert.equals("Q3", items[1].quarter)
        assert.same({}, items[1].depends_on)
    end)

    it("parses multiple items", function()
        local text = [[
- name: Auth Service
  type: tech
  size: S
  quarter: Q3
  depends_on: []

- name: Data Platform
  type: tech
  size: XL
  quarter: Q3-Q4
  depends_on: [auth]
]]
        local items = vision.parse_vision_yaml(text)
        assert.equals(2, #items)
        assert.equals("Auth Service", items[1].name)
        assert.equals("Data Platform", items[2].name)
        assert.same({"auth"}, items[2].depends_on)
    end)

    it("parses inline list with multiple items", function()
        local text = [[
- name: Self-Serve
  depends_on: [data_platform, auth]
]]
        local items = vision.parse_vision_yaml(text)
        assert.equals(1, #items)
        assert.same({"data_platform", "auth"}, items[1].depends_on)
    end)

    it("skips comments", function()
        local text = [[
# This is a comment
- name: Auth Service
  type: tech
  # inline comment
  size: S
]]
        local items = vision.parse_vision_yaml(text)
        assert.equals(1, #items)
        assert.equals("Auth Service", items[1].name)
        assert.equals("S", items[1].size)
    end)

    it("handles empty input", function()
        local items = vision.parse_vision_yaml("")
        assert.same({}, items)
    end)

    it("handles blank lines between items", function()
        local text = [[
- name: A
  size: S


- name: B
  size: M
]]
        local items = vision.parse_vision_yaml(text)
        assert.equals(2, #items)
    end)

    it("records line numbers", function()
        local text = [[
- name: First
  size: S

- name: Second
  size: M
]]
        local items = vision.parse_vision_yaml(text)
        assert.equals(1, items[1]._line)
        assert.equals(4, items[2]._line)
    end)

    it("handles values with colons", function()
        local text = [[
- name: Auth Service
  quarter: Q3-Q4
]]
        local items = vision.parse_vision_yaml(text)
        assert.equals("Q3-Q4", items[1].quarter)
    end)
end)

--------------------------------------------------------------------------------
-- name_to_id
--------------------------------------------------------------------------------

describe("name_to_id", function()
    it("converts name to snake_case", function()
        assert.equals("data_platform", vision.name_to_id("Data Platform"))
    end)

    it("handles multiple words", function()
        assert.equals("auth_service_rewrite", vision.name_to_id("Auth Service Rewrite"))
    end)

    it("strips special characters", function()
        assert.equals("mobile_app_v2", vision.name_to_id("Mobile App v2"))
    end)

    it("handles hyphens as non-alpha", function()
        assert.equals("selfserve_onboarding", vision.name_to_id("Self-Serve Onboarding"))
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
        assert.equals("px.mobile_app", vision.full_id("px", "Mobile App"))
    end)

    it("works with multi-word names", function()
        assert.equals("sync.auth_service_rewrite", vision.full_id("sync", "Auth Service Rewrite"))
    end)
end)

--------------------------------------------------------------------------------
-- resolve_ref
--------------------------------------------------------------------------------

describe("resolve_ref", function()
    local all_ids = {
        "sync.auth_rewrite",
        "sync.data_platform",
        "px.mobile_app",
        "px.self_serve",
    }

    it("resolves bare prefix within local namespace", function()
        local resolved, err = vision.resolve_ref("auth", "sync", all_ids)
        assert.is_nil(err)
        assert.equals("sync.auth_rewrite", resolved)
    end)

    it("resolves namespaced prefix", function()
        local resolved, err = vision.resolve_ref("px.mobile", "", all_ids)
        assert.is_nil(err)
        assert.equals("px.mobile_app", resolved)
    end)

    it("resolves cross-namespace with bare prefix when no local match", function()
        local resolved, err = vision.resolve_ref("mobile", "sync", all_ids)
        assert.is_nil(err)
        assert.equals("px.mobile_app", resolved)
    end)

    it("errors on ambiguous prefix", function()
        -- "s" matches both sync.* items when resolving locally in sync
        local all = { "sync.service_a", "sync.service_b" }
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
        -- If "data" exists locally, don't look global
        local resolved, err = vision.resolve_ref("data", "sync", all_ids)
        assert.is_nil(err)
        assert.equals("sync.data_platform", resolved)
    end)
end)

--------------------------------------------------------------------------------
-- validate_graph
--------------------------------------------------------------------------------

describe("validate_graph", function()
    it("validates a clean graph", function()
        local items = {
            { name = "Auth", _namespace = "sync", depends_on = {} },
            { name = "Data", _namespace = "sync", depends_on = { "auth" } },
        }
        local errors = vision.validate_graph(items)
        assert.same({}, errors)
    end)

    it("detects dangling references", function()
        local items = {
            { name = "Auth", _namespace = "sync", depends_on = { "nonexistent" } },
        }
        local errors = vision.validate_graph(items)
        assert.equals(1, #errors)
        assert.truthy(errors[1]:find("matches no"))
    end)

    it("detects circular dependencies", function()
        local items = {
            { name = "A", _namespace = "ns", depends_on = { "b" } },
            { name = "B", _namespace = "ns", depends_on = { "a" } },
        }
        local errors = vision.validate_graph(items)
        -- Should have at least one circular dependency error
        local has_cycle = false
        for _, e in ipairs(errors) do
            if e:find("circular") then has_cycle = true end
        end
        assert.is_true(has_cycle)
    end)

    it("detects duplicate IDs", function()
        local items = {
            { name = "Auth", _namespace = "sync" },
            { name = "Auth", _namespace = "sync" },
        }
        local errors = vision.validate_graph(items)
        local has_dup = false
        for _, e in ipairs(errors) do
            if e:find("duplicate") then has_dup = true end
        end
        assert.is_true(has_dup)
    end)

    it("detects missing name", function()
        local items = {
            { _namespace = "sync", depends_on = {} },
        }
        local errors = vision.validate_graph(items)
        assert.equals(1, #errors)
        assert.truthy(errors[1]:find("no name"))
    end)

    it("validates cross-namespace references", function()
        local items = {
            { name = "Auth", _namespace = "sync", depends_on = {} },
            { name = "Mobile", _namespace = "px", depends_on = { "sync.auth" } },
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
            { name = "Auth", _namespace = "sync", type = "tech", size = "S",
              quarter = "Q3", depends_on = {} },
            { name = "Data", _namespace = "sync", type = "tech", size = "XL",
              quarter = "Q3-Q4", depends_on = { "auth" } },
        }
        local csv = vision.export_csv(items)
        local lines = vim.split(csv, "\n")
        assert.equals("namespace,name,type,size,quarter,depends_on", lines[1])
        assert.equals("sync,Auth,tech,S,Q3,", lines[2])
        assert.equals("sync,Data,tech,XL,Q3-Q4,auth", lines[3])
    end)

    it("escapes commas in values", function()
        local items = {
            { name = "A, B", _namespace = "ns", type = "", size = "", quarter = "",
              depends_on = {} },
        }
        local csv = vision.export_csv(items)
        local lines = vim.split(csv, "\n")
        assert.truthy(lines[2]:find('"A, B"'))
    end)

    it("handles multiple deps", function()
        local items = {
            { name = "X", _namespace = "ns", type = "", size = "", quarter = "",
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
            { name = "Auth", _namespace = "sync", type = "tech", size = "S",
              quarter = "Q3", depends_on = {} },
            { name = "Data", _namespace = "sync", type = "tech", size = "XL",
              quarter = "Q3-Q4", depends_on = { "auth" } },
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
            { name = "Big", _namespace = "ns", type = "tech", size = "XL",
              quarter = "", depends_on = {} },
        }
        local dot = vision.export_dot(items)
        assert.truthy(dot:find("width=3.0"))
    end)

    it("maps type to color", function()
        local items = {
            { name = "Biz", _namespace = "ns", type = "business", size = "M",
              quarter = "", depends_on = {} },
        }
        local dot = vision.export_dot(items)
        assert.truthy(dot:find("#ffe0b2"))
    end)

    it("returns errors for invalid graph", function()
        local items = {
            { name = "A", _namespace = "ns", depends_on = { "nonexistent" } },
        }
        local dot, errors = vision.export_dot(items)
        assert.is_nil(dot)
        assert.truthy(#errors > 0)
    end)

    it("filters subgraph by root", function()
        local items = {
            { name = "A", _namespace = "ns", type = "tech", size = "S",
              quarter = "", depends_on = {} },
            { name = "B", _namespace = "ns", type = "tech", size = "M",
              quarter = "", depends_on = { "a" } },
            { name = "C", _namespace = "ns", type = "tech", size = "L",
              quarter = "", depends_on = {} },
        }
        local dot = vision.export_dot(items, { root = "ns.b" })
        assert.truthy(dot:find('"ns.a"'))  -- ancestor of B
        assert.truthy(dot:find('"ns.b"'))  -- root
        assert.is_nil(dot:find('"ns.c"'))  -- unrelated, excluded
    end)
end)
