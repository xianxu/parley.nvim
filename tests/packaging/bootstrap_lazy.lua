return {
    setup = function(spec, opts)
        if vim.env.BOOTSTRAP_HOLD then
            vim.fn.writefile({ 'ready' }, vim.env.BOOTSTRAP_HOLD .. '.ready')
            assert(vim.wait(10000, function()
                return vim.fn.filereadable(vim.env.BOOTSTRAP_HOLD .. '.release') == 1
            end, 10))
        end
        assert(vim.o.wrap and vim.o.linebreak and vim.o.breakindent)
        assert(vim.o.termguicolors)
        assert(vim.g.mapleader == ' ')
        assert(opts.checker.enabled == false)
        assert(spec[1].commit == '4ed07bc0c6083cdd547c63f5c245e02c068b0c45')
        assert(spec[2].commit == '74b06c6c75e4eeb3108ec01852001636d85a932b')
        assert(spec[3].commit == 'a0bbec21143c7bc5f8bb02e0005fa0b982edc026')
        local runtime
        for _, plugin in ipairs(spec) do
            if plugin.dir then runtime = plugin.dir end
        end
        package.preload['parley.starter'] = function()
            return { start = function()
                vim.fn.writefile({ vim.json.encode({ runtime = runtime, lockfile = opts.lockfile }) },
                    vim.env.BOOTSTRAP_RESULT)
            end }
        end
    end,
}
