local arch = require("tests.arch.arch_helper")

local function source(path) return table.concat(vim.fn.readfile(path), "\n") end

local function bypasses(text)
    -- Raw history fields on an attachment, or on a copied snapshot, cannot be
    -- a second authority. Detect parallel assignments as well as simple ones.
    for statement in text:gmatch("[^\n]+") do
        statement = statement:gsub("[~=<>]=", " comparison ")
        local lhs = statement:match("^(.-)=[^=]") or ""
        for _, field in ipairs({ "baseline", "owned_lock", "acquire_token", "admission", "admission_message", "unconfirmed_edit" }) do
            if lhs:match("s%." .. field .. "%f[^%w_]")
                or lhs:match("admission%s*%([^)]*%)%." .. field .. "%f[^%w_]") then return true end
        end
    end
    local first = assert(text:find("dispatch_admission = function(", 1, true))
    local last = assert(text:find("\n-- Whole minutes", first, true))
    local outside = text:sub(1, first - 1) .. text:sub(last)
    return outside:find("%.operator_admission%.dispatch%s*%(") ~= nil
end

describe("arch: one operator admission history owner (#408)", function()
    it("detects raw history writes and transitions outside the dispatcher", function()
        local shell = "dispatch_admission = function()\nend\n-- Whole minutes\n"
        assert.is_false(bypasses(shell))
        for _, mutation in ipairs({ "s.baseline = nil", "s.owned_lock, s.baseline = nil, nil",
            "admission(s).acquire_token = nil", "s.operator_admission.dispatch({})" }) do
            assert.is_true(bypasses(shell .. mutation), mutation)
        end
    end)

    it("keeps history transitions in the dispatcher and the model independent of IO", function()
        assert.is_false(bypasses(source("lua/parley/session_sync.lua")))
        local model = source("lua/parley/operator_admission.lua")
        assert.is_nil(model:match("vim%."))
        assert.is_nil(model:match("require%s*%(%s*['\"]parley%."))
        for _, path in ipairs(arch.worktree_files({ "lua/**/*.lua" })) do
            if path ~= "lua/parley/session_sync.lua" then
                assert.is_nil(source(path):match("require%s*%(%s*['\"]parley%.operator_admission['\"]"), path)
            end
        end
    end)
end)
