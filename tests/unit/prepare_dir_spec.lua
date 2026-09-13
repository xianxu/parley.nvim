local helper = require("parley.helper")

describe("directory preparation", function()
    local root, mkdir
    before_each(function()
        root = vim.fn.tempname()
        mkdir = vim.fn.mkdir
        mkdir(root, "p")
    end)
    after_each(function()
        vim.fn.mkdir = mkdir
        vim.fn.delete(root, "rf")
    end)

    it("accepts another creator winning during prepare_dir", function()
        local path = root .. "/shared/nested"
        vim.fn.mkdir = function(dir, flags)
            mkdir(dir, flags) -- a competing actor creates the real directory
            error("Vim:E739: Cannot create directory: file already exists")
        end
        assert.equals(vim.fn.resolve(path), helper.prepare_dir(path))
        assert.equals(1, vim.fn.isdirectory(path))
    end)

    it("checks the directory postcondition when mkdir silently fails", function()
        vim.fn.mkdir = function() return 0 end
        local path = root .. "/missing"
        assert.has_error(function() require("parley.fs").ensure_dir(path) end,
            "Cannot create directory: " .. path)
    end)

    it("keeps literal paths literal at the shared seam", function()
        local path = root .. "/$HOME `literal`"
        require("parley.fs").ensure_dir(path)
        require("parley.fs").ensure_dir(path)
        assert.equals(1, vim.fn.isdirectory(path))
    end)

    it("keeps prepare_dir path rejection at its existing boundary", function()
        assert.is_nil(helper.prepare_dir(root .. "/`literal`"))
        assert.equals(0, vim.fn.isdirectory(root .. "/`literal`"))
    end)

    it("centralizes every production mkdir in the filesystem seam", function()
        local sites = {}
        for _, file in ipairs(vim.fn.glob("lua/**/*.lua", false, true)) do
            local source = table.concat(vim.fn.readfile(file), "\n")
            if source:find("vim.fn.mkdir", 1, true) then
                table.insert(sites, file)
            end
        end
        assert.same({ "lua/parley/fs.lua" }, sites)
    end)

    it("creates nested directories and accepts repeated calls", function()
        local path = root .. "/nested/child"
        assert.equals(vim.fn.resolve(path), helper.prepare_dir(path))
        assert.equals(vim.fn.resolve(path), helper.prepare_dir(path))
    end)

    it("creates a private directory when a permission mode is supplied", function()
        local path = root .. '/private'
        require('parley.fs').ensure_dir(path, 448)
        assert.equals(448, vim.uv.fs_stat(path).mode % 512)
    end)

    it("rejects a file obstructing directory creation", function()
        local path = root .. "/file"
        vim.fn.writefile({ "keep" }, path)
        assert.has_error(function() helper.prepare_dir(path) end)
        assert.same({ "keep" }, vim.fn.readfile(path))
    end)

    it("preserves the original mkdir error when no directory exists", function()
        vim.fn.mkdir = function() error("permission denied", 0) end
        assert.has_error(function() helper.prepare_dir(root .. "/missing") end, "permission denied")
    end)
end)
