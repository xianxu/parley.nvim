-- #347: real processes racing to create one deep path. Each creator shares
-- every intermediate with the others, which is what two nvims starting at once
-- (or parallel spec files sharing a scratch dir) do. Before #347, Vim's mkdir -p
-- raised E739 on an intermediate a competitor created first: 8 of 180 failed.
local ROOT = vim.fn.getcwd()

describe("fs.ensure_dir under concurrent creators", function()
    local root

    before_each(function()
        root = vim.fn.tempname()
        vim.fn.mkdir(root, "p")
    end)

    after_each(function()
        vim.fn.delete(root, "rf")
    end)

    it("succeeds for every creator when they race on shared intermediates", function()
        local script = root .. "/create.lua"
        vim.fn.writefile({
            "vim.opt.rtp:prepend(" .. vim.inspect(ROOT) .. ")",
            "local ok, err = pcall(require('parley.fs').ensure_dir, arg[1])",
            "if not ok then io.stderr:write(tostring(err)) os.exit(1) end",
        }, script)
        local failures = {}
        for round = 1, 20 do
            local base = root .. "/r" .. round .. "/a/b/c/d/e/f/g/h/"
            local procs = {}
            for k = 1, 6 do
                procs[k] = vim.system({ vim.v.progpath, "--headless", "--clean", "-l", script, base .. "leaf" .. k },
                    { text = true })
            end
            for k, proc in ipairs(procs) do
                local res = proc:wait(20000)
                if res.code ~= 0 or vim.fn.isdirectory(base .. "leaf" .. k) ~= 1 then
                    failures[#failures + 1] = ("round %d creator %d: %s"):format(round, k, res.stderr or "")
                end
            end
        end
        assert.same({}, failures)
    end)
end)
