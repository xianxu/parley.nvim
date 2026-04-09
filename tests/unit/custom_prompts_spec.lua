-- Unit tests for custom_prompts module (lua/parley/custom_prompts.lua)
-- and system_prompt_picker._build_items source display

local custom_prompts = require("parley.custom_prompts")
local helper = require("parley.helper")

describe("custom_prompts", function()
    local tmpdir

    before_each(function()
        local random_suffix = string.format("%x", math.random(0, 0xFFFFFF))
        tmpdir = (os.getenv("TMPDIR") or "/tmp") .. "/claude/parley-test-custom-prompts-" .. random_suffix
        vim.fn.mkdir(tmpdir, "p")
        custom_prompts.setup(helper, tmpdir)
    end)

    after_each(function()
        if tmpdir then
            vim.fn.delete(tmpdir, "rf")
        end
    end)

    describe("Group A: persistence", function()
        it("A1: load returns empty table when no file exists", function()
            local result = custom_prompts.load()
            assert.same({}, result)
        end)

        it("A2: set and load round-trip", function()
            custom_prompts.set("test", { system_prompt = "hello world" })
            local result = custom_prompts.load()
            assert.equals("hello world", result.test.system_prompt)
        end)

        it("A3: get returns single prompt", function()
            custom_prompts.set("foo", { system_prompt = "bar" })
            local prompt = custom_prompts.get("foo")
            assert.equals("bar", prompt.system_prompt)
        end)

        it("A4: get returns nil for missing prompt", function()
            assert.is_nil(custom_prompts.get("missing"))
        end)

        it("A5: remove deletes a prompt", function()
            custom_prompts.set("to_remove", { system_prompt = "bye" })
            assert.is_true(custom_prompts.remove("to_remove"))
            assert.is_nil(custom_prompts.get("to_remove"))
        end)

        it("A6: remove returns false for non-existent prompt", function()
            assert.is_false(custom_prompts.remove("nonexistent"))
        end)

        it("A7: rename moves prompt to new key", function()
            custom_prompts.set("old_name", { system_prompt = "content" })
            assert.is_true(custom_prompts.rename("old_name", "new_name"))
            assert.is_nil(custom_prompts.get("old_name"))
            assert.equals("content", custom_prompts.get("new_name").system_prompt)
        end)

        it("A8: rename fails if target exists", function()
            custom_prompts.set("a", { system_prompt = "a" })
            custom_prompts.set("b", { system_prompt = "b" })
            assert.is_false(custom_prompts.rename("a", "b"))
        end)

        it("A9: rename fails if source missing", function()
            assert.is_false(custom_prompts.rename("missing", "new"))
        end)

        it("A10: multiple prompts coexist", function()
            custom_prompts.set("p1", { system_prompt = "first" })
            custom_prompts.set("p2", { system_prompt = "second" })
            local all = custom_prompts.load()
            assert.equals("first", all.p1.system_prompt)
            assert.equals("second", all.p2.system_prompt)
        end)
    end)

    describe("Group B: source detection", function()
        local builtins = {
            default = { system_prompt = "builtin default" },
            creative = { system_prompt = "builtin creative" },
        }

        it("B1: pure builtin returns 'builtin'", function()
            assert.equals("builtin", custom_prompts.source("default", builtins))
        end)

        it("B2: custom override of builtin returns 'modified'", function()
            custom_prompts.set("default", { system_prompt = "user edited" })
            assert.equals("modified", custom_prompts.source("default", builtins))
        end)

        it("B3: purely custom prompt returns 'custom'", function()
            custom_prompts.set("my_prompt", { system_prompt = "my stuff" })
            assert.equals("custom", custom_prompts.source("my_prompt", builtins))
        end)

        it("B4: unknown name returns 'builtin' when not in custom or builtins", function()
            -- edge case: prompt in system_prompts but not in builtins and not in custom
            -- this shouldn't normally happen, but source() should handle it gracefully
            assert.equals("builtin", custom_prompts.source("unknown", builtins))
        end)
    end)
end)

describe("system_prompt_picker._build_items source tags", function()
    local picker = require("parley.system_prompt_picker")

    it("C1: shows source tags for custom and modified prompts", function()
        local tmpdir = (os.getenv("TMPDIR") or "/tmp") .. "/claude/parley-test-picker-items-" .. string.format("%x", math.random(0, 0xFFFFFF))
        vim.fn.mkdir(tmpdir, "p")
        custom_prompts.setup(helper, tmpdir)

        -- Set up a custom override and a purely custom prompt
        custom_prompts.set("default", { system_prompt = "user edited default" })
        custom_prompts.set("my_custom", { system_prompt = "custom prompt" })

        local plugin = {
            _system_prompts = { "default", "my_custom", "teacher" },
            system_prompts = {
                default = { system_prompt = "user edited default" },
                my_custom = { system_prompt = "custom prompt" },
                teacher = { system_prompt = "builtin teacher" },
            },
            _builtin_system_prompts = {
                default = { system_prompt = "original default" },
                teacher = { system_prompt = "builtin teacher" },
            },
            _state = { system_prompt = "teacher" },
        }

        local items = picker._build_items(plugin)

        -- Find items by name
        local by_name = {}
        for _, item in ipairs(items) do
            by_name[item.name] = item
        end

        assert.equals("modified", by_name["default"].source)
        assert.equals("custom", by_name["my_custom"].source)
        assert.equals("builtin", by_name["teacher"].source)

        -- Check display contains source tags
        assert.is_truthy(by_name["default"].display:find("%[modified%]"))
        assert.is_truthy(by_name["my_custom"].display:find("%[custom%]"))
        assert.is_falsy(by_name["teacher"].display:find("%[builtin%]"))

        vim.fn.delete(tmpdir, "rf")
    end)
end)
