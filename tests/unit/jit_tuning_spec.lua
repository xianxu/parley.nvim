local tuning = require("tests.helpers.jit_tuning")
local policy = require("parley.jit_tuning")

describe("jit tuning for arm64 macOS mcode placement (#294)", function()
    it("knows which LuaJIT builds carry the mcode placement fix", function()
        assert.is_true(policy.has_mcode_fix("LuaJIT 2.1.1788856981"))
        assert.is_true(policy.has_mcode_fix("LuaJIT 2.1." .. policy.MCODE_FIX))
        assert.is_false(policy.has_mcode_fix("LuaJIT 2.1." .. (policy.MCODE_FIX - 1)))
        assert.is_false(policy.has_mcode_fix("LuaJIT 2.1.1741730670")) -- Neovim 0.11.7
        assert.is_false(policy.has_mcode_fix("LuaJIT 2.1.0-beta3"))
        assert.is_false(policy.has_mcode_fix(nil))
    end)

    it("tunes only arm64 macOS with the fix, where a large area cannot thrash", function()
        assert.same(tuning.OPTIONS, tuning.options("LuaJIT 2.1.1788856981", "arm64", "OSX"))
        assert.is_nil(tuning.options("LuaJIT 2.1.1741730670", "arm64", "OSX"))
        assert.is_nil(tuning.options("LuaJIT 2.1.1788856981", "x64", "OSX"))
        assert.is_nil(tuning.options("LuaJIT 2.1.1788856981", "arm64", "Linux"))
    end)
end)


describe("allocator safety policy (#267)", function()
    local function runtime(version, arch, os)
        local state = { enabled = true, protected = {}, options = nil }
        local fake = { version = version, arch = arch or "arm64", os = os or "OSX" }
        fake.off = function(fn, recursive)
            if fn then state.protected[fn] = recursive else state.enabled = false end
        end
        fake.opt = { start = function(...) state.options = { ... } end }
        return fake, state
    end

    it("identifies old and unknown allocators only on arm64 macOS", function()
        assert.is_true(policy.requires_interpreter("LuaJIT 2.1.1741730670", "arm64", "OSX"))
        assert.is_true(policy.requires_interpreter(nil, "arm64", "OSX"))
        assert.is_false(policy.requires_interpreter("LuaJIT 2.1." .. policy.MCODE_FIX, "arm64", "OSX"))
        assert.is_false(policy.requires_interpreter("LuaJIT 2.1.1741730670", "x64", "OSX"))
        assert.is_false(policy.requires_interpreter("LuaJIT 2.1.1741730670", "arm64", "Linux"))
    end)

    it("protects only the supplied module and its nested functions", function()
        local fake, state = runtime("LuaJIT 2.1.1741730670")
        local chunk = function() return function() return 42 end end
        assert.is_true(policy.protect_chunk(chunk, fake))
        assert.is_true(state.enabled)
        assert.is_true(state.protected[chunk])
        assert.is_nil(state.options)
    end)

    it("rejects a missing chunk before it can disable the global engine", function()
        local fake, state = runtime("LuaJIT 2.1.1741730670")
        assert.has_error(function() policy.protect_chunk(nil, fake) end)
        assert.is_true(state.enabled)
    end)

    it("leaves fixed and other-platform editor compilation alone", function()
        for _, args in ipairs({ { "LuaJIT 2.1." .. policy.MCODE_FIX },
            { "LuaJIT 2.1.1741730670", "x64" },
            { "LuaJIT 2.1.1741730670", "arm64", "Linux" } }) do
            local fake, state = runtime(unpack(args))
            assert.is_false(policy.protect_chunk(function() end, fake))
            assert.is_true(state.enabled)
            assert.is_nil(next(state.protected))
        end
    end)

    it("disables only the isolated test VM on the unsafe allocator", function()
        local fake, state = runtime("LuaJIT 2.1.1741730670")
        assert.is_nil(tuning.apply(fake))
        assert.is_false(state.enabled)
        assert.is_nil(state.options)
    end)

    it("keeps the existing fixed-build harness tuning without enabling JIT", function()
        local fake, state = runtime("LuaJIT 2.1." .. policy.MCODE_FIX)
        state.enabled = false
        assert.same(tuning.OPTIONS, tuning.apply(fake))
        assert.same(tuning.OPTIONS, state.options)
        assert.is_false(state.enabled)
    end)
end)


describe("module-scoped compiler protection in a real VM", function()
    it("keeps unrelated JIT traces active while protecting the entire document pipeline", function()
        local source = [=[
            jit.on(); jit.flush(); jit.opt.start('hotloop=1', 'hotexit=1')
            local policy = require('parley.jit_tuning')
            -- Exercise the affected policy on every host, with the real compiler.
            policy.requires_interpreter = function() return true end
            local D = require('parley.document')
            local starts = { own = 0, foreign = 0 }
            local foreign_trace
            jit.attach(function(what, trace, fn)
                if what == 'stop' and trace == foreign_trace then starts.foreign = starts.foreign + 1 end
                if what ~= 'start' then return end
                local source = debug.getinfo(fn, 'S').source
                if source:find('/lua/parley/document/', 1, true) then starts.own = starts.own + 1 end
                if source == '@unrelated-plugin' then foreign_trace = trace end
            end, 'trace')
            local foreign = assert(loadstring('local sum=0; for i=1,10000 do sum=sum+i end; return sum', '@unrelated-plugin'))
            local sum = foreign()
            local buf = vim.api.nvim_create_buf(false, true)
            local lines = { '💬: question', '🤖: answer' }
            for i=1,1000 do lines[#lines+1] = 'ordinary body' end
            vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
            local doc = D.attach(buf, { schedule = false })
            local result = D.drain(doc, 10000, { rows=256, bytes=65536, nodes=65536, entries=65536 })
            D.detach(doc); vim.api.nvim_buf_delete(buf, { force = true })
            jit.attach(function() end, 'trace')
            print(vim.json.encode({ enabled = jit.status(), own = starts.own,
                foreign = starts.foreign, sum = sum, status = result.status }))
        ]=]
        local path = vim.fn.tempname() .. '.lua'
        vim.fn.writefile(vim.split(source, '\n', { plain = true }), path)
        local child = vim.system({ vim.v.progpath, '--headless', '--noplugin', '-u', 'NONE', '-i', 'NONE',
            '--cmd', 'set rtp^=' .. vim.fn.fnameescape(vim.fn.getcwd()),
            '-c', 'luafile ' .. vim.fn.fnameescape(path), '-c', 'qa!' }):wait(require('tests.helpers.arrival').MS)
        vim.fn.delete(path)
        assert.equals(0, child.code, child.stderr)
        local result = vim.json.decode((child.stdout .. child.stderr):match('({[^\n]+})'))
        assert.is_true(result.enabled)
        assert.equals(0, result.own)
        assert.is_true(result.foreign > 0)
        assert.equals(50005000, result.sum)
        assert.equals('idle', result.status)
    end)
end)
