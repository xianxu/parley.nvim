local repository = vim.fn.getcwd()
describe('installed app boot acceptance', function()
    it('accepts the real starter command surface and isolated profile', function()
        local home = vim.fn.tempname()
        vim.fn.mkdir(home .. '/.config/nvim', 'p')
        vim.fn.mkdir(home .. '/.parley-acceptance', 'p')
        local decoy = home .. '/.config/nvim/init.lua'
        vim.fn.writefile({'error("decoy was sourced")'}, decoy)
        local hash = vim.system({'shasum', '-a', '256', decoy}, {text = true}):wait()
        assert.equals(0, hash.code)
        vim.fn.writefile(vim.split(vim.trim(hash.stdout), '\n'), home .. '/.parley-acceptance/decoy.sha')
        local script = home .. '/boot.lua'
        vim.fn.writefile({
            'vim.opt.runtimepath:prepend(' .. string.format('%q', repository) .. ')',
            'require("parley.starter").start()',
            'local ok,err=pcall(dofile,' .. string.format('%q', repository .. '/tests/packaging/vm_acceptance.lua') .. '); if not ok then print(err); vim.cmd("cquit 1") end',
            'vim.cmd("qa!")',
        }, script)
        local result = vim.system({'sh', repository .. '/packaging/parley', '--headless', '-n', '-i', 'NONE'},
            {text = true, clear_env = true, env = {HOME = home, PATH = vim.env.PATH,
                PARLEY_NVIM = vim.v.progpath, PARLEY_STARTER = script, PARLEY_RUNTIME = repository}}):wait(30000)
        vim.fn.delete(home, 'rf')
        assert.equals(0, result.code, result.stderr)
    end)
end)
