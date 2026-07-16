local async_file_source = require("parley.async_file_source")

local uv = vim.uv or vim.loop

local function write(path, lines)
    vim.fn.writefile(lines or { "content" }, path)
end

local function with_tree(callback)
    local root = vim.fn.tempname()
    vim.fn.mkdir(root .. "/docs", "p")
    vim.fn.mkdir(root .. "/outside", "p")
    write(root .. "/root.md")
    write(root .. "/docs/nested.md")
    write(root .. "/outside/hidden.md")
    assert(uv.fs_symlink(root .. "/outside", root .. "/linked.md"))

    local ok, error_value = pcall(callback, root)
    vim.fn.delete(root, "rf")
    if not ok then
        error(error_value)
    end
end

local function wait_for(predicate)
    assert(vim.wait(2000, predicate, 10), "timed out waiting for async file source")
end

describe("real asynchronous file source", function()
    it("yields to the event loop and traverses without following directory links", function()
        with_tree(function(root)
            local events = {}
            local completed = false
            local sentinel = false
            local source = async_file_source.new({ uv = uv })

            source:scan({
                roots = {
                    { path = root, optional = false },
                    { path = root .. "/missing", optional = true },
                },
                recurse = true,
                max_depth = 4,
                match = function(relative) return relative:match("%.md$") ~= nil end,
                read = "none",
                concurrency = 16,
            }, function(event)
                events[event.root_ordinal] = event
            end, function()
                completed = true
            end)
            vim.schedule(function() sentinel = true end)

            wait_for(function() return completed end)

            assert.is_true(sentinel)
            assert.equals("success", events[1].status)
            assert.same({ "docs/nested.md", "linked.md", "outside/hidden.md", "root.md" },
                vim.tbl_map(function(item) return item.relative end, events[1].candidates))
            assert.equals("skipped", events[2].status)
        end)
    end)

    it("isolates an injected root enumeration failure", function()
        with_tree(function(root)
            local failing_root = root .. "/broken"
            vim.fn.mkdir(failing_root, "p")
            local wrapped_uv = setmetatable({
                fs_scandir = function(path, callback)
                    if path == failing_root then
                        return vim.schedule(function() callback("EACCES: injected") end)
                    end
                    return uv.fs_scandir(path, callback)
                end,
            }, { __index = uv })
            local events = {}
            local completed = false

            async_file_source.new({ uv = wrapped_uv }):scan({
                roots = {
                    { path = root .. "/docs", optional = false },
                    { path = failing_root, optional = false },
                },
                recurse = true,
                max_depth = 2,
                match = function(relative) return relative:match("%.md$") ~= nil end,
                read = "none",
                concurrency = 16,
            }, function(event)
                events[event.root_ordinal] = event
            end, function()
                completed = true
            end)

            wait_for(function() return completed end)
            assert.equals("success", events[1].status)
            assert.equals("failed", events[2].status)
            assert.is_nil(events[2].candidates)
        end)
    end)

    it("suppresses terminal callbacks after immediate cancellation", function()
        with_tree(function(root)
            for index = 1, 100 do
                write(string.format("%s/docs/%03d.md", root, index))
            end
            local root_count = 0
            local complete_count = 0
            local handle = async_file_source.new({ uv = uv }):scan({
                roots = { { path = root, optional = false } },
                recurse = true,
                max_depth = 4,
                match = function(relative) return relative:match("%.md$") ~= nil end,
                read = "all",
                concurrency = 4,
            }, function()
                root_count = root_count + 1
            end, function()
                complete_count = complete_count + 1
            end)

            handle:cancel()
            vim.wait(200, function() return false end, 10)

            assert.is_true(handle:is_cancelled())
            assert.equals(0, root_count)
            assert.equals(0, complete_count)
        end)
    end)
end)
